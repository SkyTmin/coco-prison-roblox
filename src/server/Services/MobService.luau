--!strict
-- Mobs on MobSpawn points (scripts/build-fraction-base.luau: tag MobSpawn, attributes MobId, LocationId,
-- Wander). [владелец 22.10: «3 крысы по каждой тропинке и крысы вокруг круга босса; убили — появятся через
-- 2 минуты»]. One mob per point; numbers in Config.mobs (hp, damage, money [владелец]; the AI numbers
-- [решение]). A rat is a small blocky grey rodent: it wanders round its point, runs at the nearest player
-- within aggroRange, bites every attackCooldown (CombatService.ApplyDamage: armour counts), gives up past
-- leashRange from its point and goes home. The killer (LastHitBy, set by CombatService) gets the money if
-- the mob gives any (× the «Мобы» upgrade of the professions), stats[statKey] +1 and Мастер клинка xp +1
-- [вики: xp за убийства крыс, зомби, мышей]; cfg.drop falls on the ground with cfg.dropChance. A flying mob (cfg.flying:
-- the bat) is the same humanoid floated cfg.hipHeight above the floor; it changes course more often (cfg.wanderEvery),
-- its clips bob and swoop, and on death its root is anchored so only the death clip drops the body to the floor.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Skills = require(Shared.Skills)
local Strings = require(Shared.Strings)
local Sfx = require(Shared.Sfx)
local BlockRig = require(Shared.BlockRig)
local Models = Shared:WaitForChild("Models")
local ProfileService = require(script.Parent.ProfileService)
local ProfessionService = require(script.Parent.ProfessionService)
local CombatService = require(script.Parent.CombatService)
local BookService = require(script.Parent.BookService)
local ItemDropService = require(script.Parent.ItemDropService)
local GangService = require(script.Parent.GangService)
local CollisionGroups = require(script.Parent.CollisionGroups)

local MobService = {}
local started = false
local THINK = 0.25

type Mob = {
	id: string,
	cfg: any,
	spawn: BasePart,
	wander: number,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	target: Player?,
	nextBiteAt: number,
	nextWanderAt: number,
	staggerUntil: number, -- hit: stunned for a moment, the bite is cancelled
	windupAt: number?, -- the bite lands this long after the rat rears up (0 = not winding up)
}
local mobs: { Mob } = {}

-- Mobs from Blender (assets/models/<id>/<id>.py → Shared.Models.<cfg.model>: the rat after the Codex reference
-- picture, the zombie on vanilla proportions): BlockRig boxes on Motor6D joints, posed by the client
-- (MobAnimator). The physics stay a plain invisible root box (cfg.rootSize) with an R6 humanoid floating it
-- cfg.hipHeight above the ground; the model's ground origin sits cfg.modelOffset from the root centre.
local DEFAULT_ROOT = { 1.8, 1.2, 2.8 } -- the rat
local defs: { [string]: any } = {}
local function modelDef(name: string): any
	if not defs[name] then
		defs[name] = require(Models:WaitForChild(name)) :: any
	end
	return defs[name]
end

local function buildMob(id: string, at: CFrame, cfg: any): (Model, Humanoid, BasePart)
	local size = cfg.rootSize or DEFAULT_ROOT
	local offset = cfg.modelOffset or { 0, -1.2, 0.5 }
	local model = Instance.new("Model")
	model.Name = "Mob_" .. id
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(size[1], size[2], size[3])
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = at
	root.Parent = model
	local rig = modelDef(cfg.model or id)
	BlockRig.build(
		rig,
		model,
		root,
		at * CFrame.new(offset[1], offset[2], offset[3]),
		cfg.furTexture
	)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = cfg.hipHeight or 0.6
	humanoid.MaxHealth = cfg.hp
	humanoid.Health = cfg.hp
	humanoid.WalkSpeed = cfg.walkSpeed or 12
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.DisplayWhenDamaged
	humanoid.Parent = model
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model, humanoid, root
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local spawnMob: (mob: Mob) -> ()

local function rewardKiller(mob: Mob, humanoid: Humanoid)
	local by = humanoid:GetAttribute("LastHitBy")
	local player = if typeof(by) == "number" then Players:GetPlayerByUserId(by) else nil
	if not player or not ProfileService.Get(player) then
		return
	end
	local money = 0
	ProfileService.Mutate(player, function(p)
		local mult = (1 + p.professions.upgrades.mobs * Config.professions.upgrades.mobs)
			* Boosters.multiplier(p, "mobs")
		money = math.floor((mob.cfg.money or 0) * mult * Config.moneyScale + 0.5)
		p.coins += money
		if mob.cfg.statKey then
			-- stats[statKey] = «чистые» (one per kill: trainer, spawn top); statKey.."Total" counts with the
			-- «Мобы» upgrade, like blocksTotal with «Блоки» [сеть: rats / rats_clean; множитель — решение]
			-- Охотник: with its chance the kill counts as two [меню 26.10: «засчитает как двух в статистике»]
			-- + the gang perk Охотник (adds to the skill) [решение: +2 % за уровень]
			local kills = if math.random()
					< Skills.doubleKillChance(p) + GangService.perk(p, "hunter")
				then 2
				else 1
			p.stats[mob.cfg.statKey] = (p.stats[mob.cfg.statKey] or 0) + kills
			local total = mob.cfg.statKey .. "Total"
			p.stats[total] = (p.stats[total] or p.stats[mob.cfg.statKey] - kills) + mult * kills
		end
		ProfessionService.addXp(p, "blademaster", 1)
	end)
	GangService.progress(player, "mobKill", 1, mob.id) -- gang quests: «Убить моба X»
	if money > 0 then
		toast(
			player,
			"mob_killed",
			Strings.t("mob_" .. mob.id, Strings.localeOf(player)),
			Strings.money(money)
		)
	end
end

function spawnMob(mob: Mob)
	if mob.model or not mob.spawn:IsDescendantOf(workspace) then
		return
	end
	local size = mob.cfg.rootSize or DEFAULT_ROOT
	local lift = mob.spawn.Size.Y / 2 + (mob.cfg.hipHeight or 0.6) + size[2] / 2
	local model, humanoid, root =
		buildMob(mob.id, mob.spawn.CFrame * CFrame.new(0, lift, 0), mob.cfg)
	model:SetAttribute("MobId", mob.id)
	CollectionService:AddTag(model, "Mob")
	CollisionGroups.mob(model) -- no stepping onto rats, no pushing: only knockback moves them
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	mob.model, mob.humanoid, mob.root = model, humanoid, root
	mob.target, mob.nextBiteAt, mob.nextWanderAt = nil, 0, 0
	mob.staggerUntil, mob.windupAt = 0, nil
	-- [владелец 22.10: бой приятнее] a hit staggers the rat for a moment (it stops and its bite is cancelled)
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		if health < last - 0.01 and health > 0 then
			mob.staggerUntil = os.clock() + (mob.cfg.staggerSeconds or 0.4)
			mob.windupAt = nil
			humanoid:MoveTo(root.Position)
		end
		last = health
	end)
	humanoid.Died:Once(function()
		local death = mob.cfg.deathSound or { "rat_death", 0.7, 1 }
		Sfx.broadcast(death[1], root, death[2], death[3])
		rewardKiller(mob, humanoid)
		local lootAt = root.Position
		if mob.cfg.flying then
			root.Anchored = true -- the death clip drops the body, the root stays where it hovered
			lootAt -= Vector3.new(0, mob.cfg.hipHeight or 0, 0)
		end
		-- loot on the ground like in Minecraft [владелец 22.10: с крысы только плоть нежити, шанс 25 %]
		if mob.cfg.drop and math.random() < (mob.cfg.dropChance or 1) then
			ItemDropService.SpawnLoot({ id = mob.cfg.drop, count = 1 }, lootAt, true)
		end
		mob.model, mob.humanoid, mob.root, mob.target = nil, nil, nil, nil
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Color = p.Color:Lerp(Color3.fromRGB(150, 40, 40), 0.5)
			end
		end
		task.delay(1.5, function()
			model:Destroy()
		end)
		task.delay(mob.cfg.respawnSeconds or 120, spawnMob, mob)
	end)
end

-- the nearest living player on the same location within range of the mob
local function nearestPlayer(mob: Mob, range: number): (Player?, BasePart?)
	local root = mob.root :: BasePart
	local best, bestRoot, bestDist = nil, nil, range
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local r = character and character:FindFirstChild("HumanoidRootPart")
		local h = character and character:FindFirstChildOfClass("Humanoid")
		if r and r:IsA("BasePart") and h and h.Health > 0 then
			local d = (r.Position - root.Position).Magnitude
			if d < bestDist then
				best, bestRoot, bestDist = player, r, d
			end
		end
	end
	return best, bestRoot
end

local function think(mob: Mob, now: number)
	local humanoid, root = mob.humanoid, mob.root
	if not humanoid or not root or humanoid.Health <= 0 then
		return
	end
	local home = mob.spawn.Position
	local fromHome = ((root.Position - home) * Vector3.new(1, 0, 1)).Magnitude
	if now < mob.staggerUntil then
		return -- staggered by a hit
	end
	if BookService.active(mob.model, "Dazed") > 0 then
		humanoid:MoveTo(root.Position) -- dazed by a book (Замешательство, Вихрь, Слепота)
		mob.windupAt = nil
		return
	end
	local player, targetRoot = nearestPlayer(mob, mob.cfg.aggroRange or 18)
	if player and targetRoot and fromHome < (mob.cfg.leashRange or 30) then
		local d = (targetRoot.Position - root.Position).Magnitude
		local reach = mob.cfg.attackRange or 4.5
		if mob.windupAt then
			-- the bite lands at the end of the wind-up if the player is still close (a step back dodges it)
			if now >= mob.windupAt then
				mob.windupAt = nil
				mob.nextBiteAt = now + (mob.cfg.attackCooldown or 1.2)
				local h = targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
				if h and d <= reach + 1 then
					CombatService.ApplyDamage(h, mob.cfg.damage or 2, "mob", nil, mob.model)
				end
			end
			return
		end
		if d <= reach then
			humanoid:MoveTo(root.Position)
			-- face the player (standing still, the humanoid does not turn by itself)
			local flat = Vector3.new(targetRoot.Position.X, root.Position.Y, targetRoot.Position.Z)
			if (flat - root.Position).Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(root.Position, flat)
			end
			if now >= mob.nextBiteAt then
				-- a readable bite: a squeak and a short rear-up (attribute MobWindup for the client), then the bite
				mob.windupAt = now + (mob.cfg.windupSeconds or 0.35)
				if mob.model then
					mob.model:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				end
				local windup = mob.cfg.windupSound or { "rat_hurt", 0.35, 1.5 }
				Sfx.broadcast(windup[1], root, windup[2], windup[3])
			end
		else
			humanoid:MoveTo(targetRoot.Position)
		end
		return
	end
	if fromHome > (mob.cfg.leashRange or 30) then
		humanoid:MoveTo(home)
	elseif now >= mob.nextWanderAt then
		local every = mob.cfg.wanderEvery or { 3, 7 }
		mob.nextWanderAt = now + every[1] + math.random() * (every[2] - every[1])
		local a, r = math.random() * math.pi * 2, math.random() * mob.wander
		humanoid:MoveTo(home + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
	end
end

local function register(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("MobId")
	local cfg = if typeof(id) == "string" then Config.mobs.mobs[id] else nil
	if not cfg or not Models:FindFirstChild(cfg.model or id) then -- a mob needs its Blender model
		return
	end
	for _, m in ipairs(mobs) do
		if m.spawn == part then
			return
		end
	end
	local wander = part:GetAttribute("Wander")
	local mob: Mob = {
		id = id :: string,
		cfg = cfg,
		spawn = part,
		wander = if typeof(wander) == "number" then wander else 8,
		model = nil,
		humanoid = nil,
		root = nil,
		target = nil,
		nextBiteAt = 0,
		staggerUntil = 0,
		windupAt = nil,
		nextWanderAt = 0,
	}
	table.insert(mobs, mob)
	spawnMob(mob)
end

function MobService.Start()
	if started then
		return
	end
	started = true
	for _, part in ipairs(CollectionService:GetTagged("MobSpawn")) do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal("MobSpawn"):Connect(register)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc < THINK then
			return
		end
		acc = 0
		local now = os.clock()
		for _, mob in ipairs(mobs) do
			think(mob, now)
		end
	end)
end

return MobService
