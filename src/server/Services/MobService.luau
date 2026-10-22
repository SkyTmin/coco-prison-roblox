--!strict
-- Mobs on MobSpawn points (scripts/build-fraction-base.luau: tag MobSpawn, attributes MobId, LocationId,
-- Wander). [владелец 22.10: «3 крысы по каждой тропинке и крысы вокруг круга босса; убили — появятся через
-- 2 минуты»]. One mob per point; numbers in Config.mobs (hp, damage, money [владелец]; the AI numbers
-- [решение]). A rat is a small blocky grey rodent: it wanders round its point, runs at the nearest player
-- within aggroRange, bites every attackCooldown (CombatService.ApplyDamage: armour counts), gives up past
-- leashRange from its point and goes home. The killer (LastHitBy, set by CombatService) gets the money
-- (× the «Мобы» upgrade of the professions), stats[statKey] +1 and Мастер клинка xp +1 [вики: xp за
-- убийства крыс, зомби, мышей].

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local ProfessionService = require(script.Parent.ProfessionService)
local CombatService = require(script.Parent.CombatService)

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
}
local mobs: { Mob } = {}

local function weld(root: BasePart, part: BasePart)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = true
	part.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, part
	w.Parent = part
end

local function block(
	model: Model,
	name: string,
	size: Vector3,
	offset: CFrame,
	color: Color3,
	root: BasePart
)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = root.CFrame * offset
	p.Material = Enum.Material.SmoothPlastic
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	weld(root, p)
	return p
end

-- A blocky rat facing −Z: grey body and head, pink ears, nose, feet and a long tail, black eyes.
local function buildRat(at: CFrame, cfg: any): (Model, Humanoid, BasePart)
	local model = Instance.new("Model")
	model.Name = "Mob_rat"
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(1.8, 1.2, 2.8)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = at
	root.Parent = model
	local GREY, DARK = Color3.fromRGB(110, 106, 110), Color3.fromRGB(80, 76, 80)
	local PINK = Color3.fromRGB(235, 150, 160)
	block(model, "Body", Vector3.new(1.8, 1.2, 2.6), CFrame.new(0, 0, 0.2), GREY, root)
	block(model, "Back", Vector3.new(1.4, 0.3, 2), CFrame.new(0, 0.7, 0.3), DARK, root)
	block(model, "Head", Vector3.new(1.3, 1, 1.2), CFrame.new(0, 0.2, -1.6), GREY, root)
	block(model, "Snout", Vector3.new(0.7, 0.55, 0.6), CFrame.new(0, 0.05, -2.45), GREY, root)
	block(model, "Nose", Vector3.new(0.3, 0.25, 0.15), CFrame.new(0, 0.15, -2.8), PINK, root)
	for _, s in ipairs({ -1, 1 }) do
		block(
			model,
			"Ear",
			Vector3.new(0.5, 0.5, 0.15),
			CFrame.new(s * 0.55, 0.85, -1.4),
			PINK,
			root
		)
		block(
			model,
			"Eye",
			Vector3.new(0.2, 0.2, 0.1),
			CFrame.new(s * 0.35, 0.4, -2.22),
			Color3.fromRGB(20, 20, 20),
			root
		)
		for _, z in ipairs({ -0.7, 1.0 }) do
			block(
				model,
				"Foot",
				Vector3.new(0.35, 0.4, 0.45),
				CFrame.new(s * 0.7, -0.75, z),
				PINK,
				root
			)
		end
	end
	block(
		model,
		"Tail",
		Vector3.new(0.18, 0.18, 2.6),
		CFrame.new(0, -0.2, 2.6) * CFrame.Angles(0.25, 0, 0),
		PINK,
		root
	)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = 0.6
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
		local mult = 1 + p.professions.upgrades.mobs * Config.professions.upgrades.mobs
		money = math.floor((mob.cfg.money or 0) * mult * Config.moneyScale + 0.5)
		p.coins += money
		if mob.cfg.statKey then
			p.stats[mob.cfg.statKey] = (p.stats[mob.cfg.statKey] or 0) + 1
		end
		ProfessionService.addXp(p, "blademaster", 1)
	end)
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
	local model, humanoid, root =
		buildRat(mob.spawn.CFrame * CFrame.new(0, mob.spawn.Size.Y / 2 + 1.2, 0), mob.cfg)
	model:SetAttribute("MobId", mob.id)
	CollectionService:AddTag(model, "Mob")
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	mob.model, mob.humanoid, mob.root = model, humanoid, root
	mob.target, mob.nextBiteAt, mob.nextWanderAt = nil, 0, 0
	humanoid.Died:Once(function()
		rewardKiller(mob, humanoid)
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
	local player, targetRoot = nearestPlayer(mob, mob.cfg.aggroRange or 18)
	if player and targetRoot and fromHome < (mob.cfg.leashRange or 30) then
		local d = (targetRoot.Position - root.Position).Magnitude
		if d <= (mob.cfg.attackRange or 4.5) then
			humanoid:MoveTo(root.Position)
			if now >= mob.nextBiteAt then
				mob.nextBiteAt = now + (mob.cfg.attackCooldown or 1.2)
				local h = targetRoot.Parent and targetRoot.Parent:FindFirstChildOfClass("Humanoid")
				if h then
					CombatService.ApplyDamage(h, mob.cfg.damage or 2, "mob")
				end
			end
		else
			humanoid:MoveTo(targetRoot.Position)
		end
		return
	end
	if fromHome > (mob.cfg.leashRange or 30) then
		humanoid:MoveTo(home)
	elseif now >= mob.nextWanderAt then
		mob.nextWanderAt = now + math.random(3, 7)
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
	if not cfg or id ~= "rat" then -- only rats have a model so far
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
