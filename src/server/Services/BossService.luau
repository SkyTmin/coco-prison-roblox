--!strict
-- Bosses on their arenas (BossSpawn part, attribute BossId; scripts/build-quarry.luau). First boss: the
-- Базальтовый страж of the Каменоломня [вики BOSS-CARDS]: «клинок из лавы» and «шипы из земли», no damage
-- gets through during its attack animations [клиент]. Numbers in Config.bosses (fight) — [решение],
-- damage almost zero because the quarry is a level-3 location [владелец 22.10].
--   * respawns respawnSeconds after it dies (20 min [владелец]); the first spawn comes firstSpawnSeconds
--     after the server starts;
--   * fights the players standing in its arena; with nobody to fight for leashSeconds it walks back
--     and heals fully (the damage list is cleared);
--   * the kill bank (money max of the boss card, 350 $ [меню]) is split by damage share, the last hit
--     gets ×(1 + lastHitBonus); players below minDamageShare or no longer in the location get nothing
--     [клиент: «кого нет на локации — ничего»];
--   * state for the HUD bar lives in ReplicatedStorage.Bosses.<id> attributes (works with streaming);
--   * [владелец 22.10: «босс должен жить независимо от игроков»] a server shuts down when its last player
--     leaves, so the boss's life (health, the respawn time, who dealt how much) is kept in MemoryStore
--     (hash map BossState) every few seconds; a new server picks it up: the same wounded boss, or the
--     respawn timer that is already running. One record per boss for the whole game: with several
--     servers the last writer wins (fine while the game runs one server).

local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local BookService = require(script.Parent.BookService)
local CombatService = require(script.Parent.CombatService)
local HurtService = require(script.Parent.HurtService)
local ProfileService = require(script.Parent.ProfileService)
local ChatService = require(script.Parent.ChatService) -- announcements in the chat (этап 3)
local GangService = require(script.Parent.GangService)
local InventoryService = require(script.Parent.InventoryService)
local CollisionGroups = require(script.Parent.CollisionGroups)
local SplinterAbilities = require(script.Parent.SplinterAbilities)
local BlockRig = require(Shared.BlockRig)
local Models = Shared:WaitForChild("Models")

local BossService = {}
local started = false
local BASALT = Color3.fromRGB(52, 52, 58)
local LAVA = Color3.fromRGB(255, 110, 30)
local TELEGRAPH = Color3.fromRGB(255, 40, 30)

type Fight = {
	splinter: any?,
	meleeDamage: number,
	meleeRange: number,
	meleeCooldown: number,
	walkSpeed: number,
	leashSeconds: number,
	abilityCooldown: number,
	phase2At: number,
	phase2CooldownScale: number,
	firstSpawnSeconds: number,
	lavaBlade: { telegraph: number, length: number, width: number, speed: number, damage: number },
	earthSpikes: {
		telegraph: number,
		radius: number,
		damage: number,
		perTarget: number,
		perTargetPhase2: number,
	},
	charge: {
		telegraph: number,
		speed: number,
		maxDistance: number,
		width: number,
		damage: number,
		stunPillar: number,
		stunWall: number,
		stunDamageMultiplier: number,
	},
}
type Boss = {
	id: string,
	card: any,
	fight: Fight,
	spawn: BasePart,
	arenaRadius: number,
	state: Configuration,
	model: Model?,
	humanoid: Humanoid?,
	root: BasePart?,
	motors: { [string]: Motor6D },
	damageBy: { [number]: number },
	busyUntil: number, -- casting: no other action, and invulnerable
	nextMeleeAt: number,
	nextAbilityAt: number,
	lastTargetAt: number,
	walkPhase: number,
	stuckFor: number,
	nextAbility: number,
	stunnedUntil: number, -- after ramming a pillar or the wall: open to ×stunDamageMultiplier damage
	dirty: boolean, -- changed since the last MemoryStore save
}
-- what MemoryStore keeps per boss
type Saved = { hp: number?, respawnAt: number?, damageBy: { [string]: number }? }

local bosses: { [string]: Boss } = {}

-- per-boss colours of the abilities (fight.palette {telegraph, blade, spikes, glow} = {r, g, b}); the
-- Базальтовый страж keeps its lava, Зомбарь has green pus and earth
local function paletteColor(boss: Boss, key: string, default: Color3): Color3
	local palette = (boss.fight :: any).palette
	local c = palette and palette[key]
	return if typeof(c) == "table" then Color3.fromRGB(c[1], c[2], c[3]) else default
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function bossName(boss: Boss, player: Player): string
	local locale = Strings.localeOf(player)
	return if locale == "ru" or not boss.card.nameEn then boss.card.name else boss.card.nameEn
end

local function playersInLocation(boss: Boss): { Player }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = ProfileService.Get(player)
		if profile and profile.location == boss.card.locationId then
			table.insert(list, player)
		end
	end
	return list
end

-- alive players standing in the arena (a little slack around the wall)
local function fighters(boss: Boss): { { player: Player, root: BasePart, humanoid: Humanoid } }
	local list = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if root and root:IsA("BasePart") and humanoid and humanoid.Health > 0 then
			local flat = (root.Position - boss.spawn.Position) * Vector3.new(1, 0, 1)
			if
				flat.Magnitude <= boss.arenaRadius + 6
				and math.abs(root.Position.Y - boss.spawn.Position.Y) < 20
			then
				table.insert(list, { player = player, root = root, humanoid = humanoid })
			end
		end
	end
	return list
end

-- ---------------------------------------------------------------- the model: a basalt golem
local function block(
	model: Model,
	name: string,
	size: Vector3,
	color: Color3,
	material: Enum.Material
): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material
	p.CanCollide = false
	p.Massless = true
	p.CastShadow = true
	p.Parent = model
	return p
end

local function motor(
	boss: Boss,
	name: string,
	part0: BasePart,
	part1: BasePart,
	c0: CFrame,
	c1: CFrame
): Motor6D
	local m = Instance.new("Motor6D")
	m.Name = name
	m.Part0, m.Part1 = part0, part1
	m.C0, m.C1 = c0, c1
	m.Parent = part0
	m:SetAttribute("BaseC0", c0)
	boss.motors[name] = m
	return m
end

local function seam(model: Model, parent: BasePart, size: Vector3, offset: CFrame)
	local s = block(model, "LavaSeam", size, LAVA, Enum.Material.Neon)
	local weld = Instance.new("WeldConstraint")
	s.CFrame = parent.CFrame * offset
	weld.Part0, weld.Part1 = parent, s
	weld.Parent = s
end

-- ---------------------------------------------------------------- the model from a template
-- ServerStorage.BossTemplates.<template> holds a static mesh golem split into Head / Torso / LeftArm /
-- RightArm / LeftLeg / RightLeg (child models or parts; "_geom" suffixes and spaces are ignored).
-- It is scaled, each limb is welded to an invisible bone at its joint (shoulder, hip, neck) and the
-- bones hang on Motor6Ds named like the procedural rig, so BossAnimator turns the limbs at the joints.
local LIMBS = { "head", "torso", "leftarm", "rightarm", "leftleg", "rightleg" }
local function limbKey(name: string): string
	return (string.gsub(string.gsub(string.lower(name), "[%s_]", ""), "geom$", ""))
end

local function rigFromTemplate(boss: Boss, template: Model): Model?
	local model = template:Clone()
	local scale = tonumber((boss.fight :: any).scale) or 1
	if scale ~= 1 then
		model:ScaleTo(model:GetScale() * scale)
	end
	local groups: { [string]: { BasePart } } = {}
	for _, child in ipairs(model:GetChildren()) do
		local key = limbKey(child.Name)
		if table.find(LIMBS, key) then
			groups[key] = groups[key] or {}
			if child:IsA("BasePart") then
				table.insert(groups[key], child)
			end
			for _, d in ipairs(child:GetDescendants()) do
				if d:IsA("BasePart") then
					table.insert(groups[key], d)
				end
			end
		end
	end
	for _, key in ipairs(LIMBS) do
		if not groups[key] or #groups[key] == 0 then
			warn("[BossService] template " .. template.Name .. " has no " .. key)
			model:Destroy()
			return nil
		end
	end
	local function box(key: string): (Vector3, Vector3)
		local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
		for _, part in ipairs(groups[key]) do
			local half = part.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = part.CFrame:PointToWorldSpace(half * Vector3.new(sx, sy, sz))
						lo, hi = lo:Min(corner), hi:Max(corner)
					end
				end
			end
		end
		return (lo + hi) / 2, hi - lo
	end
	-- stand it on the spawn: feet on the floor, torso over the spawn point
	local lowest = math.huge
	for _, key in ipairs({ "leftleg", "rightleg" }) do
		local c, sz = box(key)
		lowest = math.min(lowest, c.Y - sz.Y / 2)
	end
	local torsoC = box("torso")
	local ground = boss.spawn.Position.Y + boss.spawn.Size.Y / 2
	model:PivotTo(
		model:GetPivot()
			+ Vector3.new(
				boss.spawn.Position.X - torsoC.X,
				ground - lowest,
				boss.spawn.Position.Z - torsoC.Z
			)
	)
	local torsoS
	torsoC, torsoS = box("torso")
	local function bone(name: string, at: Vector3): BasePart
		local b = Instance.new("Part")
		b.Name = name
		b.Size = Vector3.one * 0.4
		b.Transparency = 1
		b.CanCollide = false
		b.CanQuery = false
		b.CanTouch = false
		b.Massless = true
		b.CFrame = CFrame.new(at)
		b.Parent = model
		return b
	end
	local function joint(key: string, where: string): Vector3
		local c, sz = box(key)
		if where == "top" then
			return Vector3.new(c.X, c.Y + sz.Y / 2 - sz.Y * 0.12, c.Z) -- the shoulder / hip, a bit inside the top
		end
		return Vector3.new(c.X, c.Y - sz.Y / 2, c.Z) -- the neck, at the bottom of the head
	end
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(torsoS.X * 0.7, torsoS.Y * 0.8, torsoS.Z * 0.7)
	root.CFrame = CFrame.new(torsoC)
	root.Transparency = 1
	root.CanCollide = true
	root.Parent = model
	local bones: { [string]: BasePart } = {
		torso = bone("Torso", torsoC),
		head = bone("Head", joint("head", "bottom")),
		leftarm = bone("LeftArm", joint("leftarm", "top")),
		rightarm = bone("RightArm", joint("rightarm", "top")),
		leftleg = bone("LeftLeg", joint("leftleg", "top")),
		rightleg = bone("RightLeg", joint("rightleg", "top")),
	}
	local welded: { [BasePart]: boolean } = { [root] = true }
	for _, b in pairs(bones) do
		welded[b] = true
	end
	for key, parts in pairs(groups) do
		for _, part in ipairs(parts) do
			part.Anchored = false
			part.CanCollide = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = bones[key], part
			weld.Parent = part
			welded[part] = true
		end
	end
	for _, d in ipairs(model:GetDescendants()) do -- anything outside the six groups rides on the torso
		if d:IsA("BasePart") and not welded[d] then
			d.Anchored = false
			d.CanCollide = false
			d.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0, weld.Part1 = bones.torso, d
			weld.Parent = d
		end
	end
	local function motor6(name: string, part0: BasePart, part1: BasePart)
		local m = Instance.new("Motor6D")
		m.Name = name
		m.Part0, m.Part1 = part0, part1
		m.C0 = part0.CFrame:ToObjectSpace(part1.CFrame)
		m.C1 = CFrame.new()
		m.Parent = part0
		m:SetAttribute("BaseC0", m.C0)
		boss.motors[name] = m
	end
	motor6("Torso", root, bones.torso)
	motor6("Neck", bones.torso, bones.head)
	motor6("LeftShoulder", bones.torso, bones.leftarm)
	motor6("RightShoulder", bones.torso, bones.rightarm)
	motor6("LeftHip", bones.torso, bones.leftleg)
	motor6("RightHip", bones.torso, bones.rightleg)
	local glow = Instance.new("PointLight") -- lava glow from the chest
	glow.Range = 16
	glow.Brightness = 1.4
	glow.Color = paletteColor(boss, "glow", LAVA)
	glow.Parent = bones.torso
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = math.max(0.5, (torsoC.Y - root.Size.Y / 2) - ground)
	humanoid.MaxHealth = boss.card.hp
	humanoid.Health = boss.card.hp
	humanoid.WalkSpeed = boss.fight.walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 55 -- clears a 4-stud block when it gets stuck on one
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	model.Name = "Boss_" .. boss.id
	model:SetAttribute("BossId", boss.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.PrimaryPart = root
	CollectionService:AddTag(model, "Boss")
	CollisionGroups.mob(model) -- players walk through bosses; only the hits push
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	return model
end

-- A boss made in Blender like the rat [владелец 22.10: «босс в каменоломне по этой же логике, точь в точь»]:
-- fight.model names Shared.Models.<id> (assets/models/<id>): BlockRig boxes on Motor6D joints, the lava cracks
-- Neon, posed by BossAnimator from the Blender clips (model attribute BlockModel). The physics stay an invisible
-- root box over the hips with an R6 humanoid floating it; the model's ground origin sits under it.
local BLOCK_ROOT_HEIGHT = 4.5
local function buildBlock(boss: Boss, def: any): Model
	local fight = boss.fight :: any
	local model = Instance.new("Model")
	local top = boss.spawn.CFrame * CFrame.new(0, boss.spawn.Size.Y / 2, 0)
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(4, 5, 3)
	root.Transparency = 1
	root.CanCollide = true
	root.CFrame = top * CFrame.new(0, BLOCK_ROOT_HEIGHT, 0)
	root.Parent = model
	BlockRig.build(
		def,
		model,
		root,
		root.CFrame * CFrame.new(0, -BLOCK_ROOT_HEIGHT, 0),
		fight.texture
	)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") then
			boss.motors[d.Name] = d -- the crumble on death takes them apart
		end
	end
	if fight.glowBrightness ~= 0 then
		local glow = Instance.new("PointLight") -- lava bosses only; Splinter uses matte fur
		glow.Range = 16
		glow.Brightness = fight.glowBrightness or 1.4
		glow.Color = paletteColor(boss, "glow", LAVA)
		glow.Parent = model:FindFirstChild("J_body") or root
	end
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = BLOCK_ROOT_HEIGHT - root.Size.Y / 2
	humanoid.MaxHealth = boss.card.hp
	humanoid.Health = boss.card.hp
	humanoid.WalkSpeed = boss.fight.walkSpeed
	humanoid.UseJumpPower = true
	humanoid.JumpPower = 55 -- clears a 4-stud block when it gets stuck on one
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	model.Name = "Boss_" .. boss.id
	model:SetAttribute("BossId", boss.id)
	model:SetAttribute("BlockModel", fight.model)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.PrimaryPart = root
	CollectionService:AddTag(model, "Boss")
	CollisionGroups.mob(model) -- players walk through bosses; only the hits push
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	return model
end

local function buildModel(boss: Boss): Model
	local blockDef = (boss.fight :: any).model and Models:FindFirstChild((boss.fight :: any).model)
	if blockDef and blockDef:IsA("ModuleScript") then
		return buildBlock(boss, require(blockDef) :: any)
	end
	local templates = ServerStorage:FindFirstChild("BossTemplates")
	local template = templates and templates:FindFirstChild((boss.fight :: any).template or boss.id)
	if template and template:IsA("Model") then
		local rigged = rigFromTemplate(boss, template)
		if rigged then
			return rigged
		end
	end
	-- fallback: the procedural block golem (no template in the place)
	local model = Instance.new("Model")
	model.Name = "Boss_" .. boss.id
	model:SetAttribute("BossId", boss.id)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local origin = boss.spawn.CFrame * CFrame.new(0, 8 - boss.spawn.Size.Y / 2, 0)
	local root =
		block(model, "HumanoidRootPart", Vector3.new(6, 6, 4), BASALT, Enum.Material.Basalt)
	root.Transparency = 1
	root.CanCollide = true
	root.Massless = false
	root.CFrame = origin
	local torso = block(model, "Torso", Vector3.new(6.4, 6, 4.4), BASALT, Enum.Material.Basalt)
	local head = block(model, "Head", Vector3.new(4, 3.6, 3.8), BASALT, Enum.Material.Basalt)
	local armL = block(model, "LeftArm", Vector3.new(2.6, 7, 2.6), BASALT, Enum.Material.Basalt)
	local armR = block(model, "RightArm", Vector3.new(2.6, 7, 2.6), BASALT, Enum.Material.Basalt)
	local legL = block(model, "LeftLeg", Vector3.new(2.6, 5, 2.6), BASALT, Enum.Material.Basalt)
	local legR = block(model, "RightLeg", Vector3.new(2.6, 5, 2.6), BASALT, Enum.Material.Basalt)
	motor(boss, "Torso", root, torso, CFrame.new(), CFrame.new())
	motor(boss, "Neck", torso, head, CFrame.new(0, 4.8, 0), CFrame.new())
	motor(boss, "LeftShoulder", torso, armL, CFrame.new(-4.6, 2.2, 0), CFrame.new(0, 3, 0))
	motor(boss, "RightShoulder", torso, armR, CFrame.new(4.6, 2.2, 0), CFrame.new(0, 3, 0))
	motor(boss, "LeftHip", torso, legL, CFrame.new(-1.7, -3, 0), CFrame.new(0, 2.5, 0))
	motor(boss, "RightHip", torso, legR, CFrame.new(1.7, -3, 0), CFrame.new(0, 2.5, 0))
	-- place the parts once so the welded details below sit right
	torso.CFrame = root.CFrame
	head.CFrame = torso.CFrame * CFrame.new(0, 4.8, 0)
	armL.CFrame = torso.CFrame * CFrame.new(-4.6, -0.8, 0)
	armR.CFrame = torso.CFrame * CFrame.new(4.6, -0.8, 0)
	legL.CFrame = torso.CFrame * CFrame.new(-1.7, -5.5, 0)
	legR.CFrame = torso.CFrame * CFrame.new(1.7, -5.5, 0)
	-- lava seams, glowing eyes, shoulder rocks
	seam(
		model,
		torso,
		Vector3.new(0.5, 5.2, 4.5),
		CFrame.new(-1.2, 0, 0) * CFrame.Angles(0, 0, 0.3)
	)
	seam(model, torso, Vector3.new(6.5, 0.5, 4.5), CFrame.new(0, -1.6, 0))
	seam(model, armR, Vector3.new(2.7, 0.4, 2.7), CFrame.new(0, -1.5, 0))
	seam(model, armL, Vector3.new(2.7, 0.4, 2.7), CFrame.new(0, 0.8, 0))
	for _, x in ipairs({ -0.9, 0.9 }) do
		local eye = block(
			model,
			"Eye",
			Vector3.new(0.9, 0.5, 0.2),
			Color3.fromRGB(255, 200, 60),
			Enum.Material.Neon
		)
		eye.CFrame = head.CFrame * CFrame.new(x, 0.3, -1.95)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = head, eye
		weld.Parent = eye
	end
	for _, arm in ipairs({ armL, armR }) do
		local rock = block(
			model,
			"ShoulderRock",
			Vector3.new(3.4, 2, 3.4),
			Color3.fromRGB(70, 66, 70),
			Enum.Material.Basalt
		)
		rock.CFrame = arm.CFrame * CFrame.new(0, 3.2, 0) * CFrame.Angles(0, 0.4, 0.15)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = arm, rock
		weld.Parent = rock
	end
	local glow = Instance.new("PointLight")
	glow.Range = 18
	glow.Brightness = 1.5
	glow.Color = LAVA
	glow.Parent = torso
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.HipHeight = 5
	humanoid.MaxHealth = boss.card.hp
	humanoid.Health = boss.card.hp
	humanoid.WalkSpeed = boss.fight.walkSpeed
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.Parent = model
	model.PrimaryPart = root
	CollectionService:AddTag(model, "Boss")
	CollisionGroups.mob(model) -- players walk through bosses; only the hits push
	model.Parent = workspace
	root:SetNetworkOwner(nil)
	return model
end

-- ---------------------------------------------------------------- state for the HUD
local function publish(boss: Boss)
	local humanoid = boss.humanoid
	local alive = humanoid ~= nil and humanoid.Health > 0
	boss.state:SetAttribute("Alive", alive)
	boss.state:SetAttribute("Health", if humanoid then math.max(0, humanoid.Health) else 0)
	boss.state:SetAttribute("MaxHealth", boss.card.hp)
	boss.state:SetAttribute(
		"Invulnerable",
		os.clock() < boss.busyUntil and os.clock() >= boss.stunnedUntil
	)
	boss.state:SetAttribute("Stunned", os.clock() < boss.stunnedUntil)
	boss.dirty = true
end

-- ---------------------------------------------------------------- the boss outlives its server (MemoryStore)
local SAVE_EVERY = 3
local storeOk, store = pcall(function()
	return MemoryStoreService:GetHashMap("BossState")
end)

local function snapshot(boss: Boss): Saved
	local humanoid = boss.humanoid
	local damageBy = {}
	for userId, dealt in pairs(boss.damageBy) do
		damageBy[tostring(userId)] = dealt
	end
	local respawnAt = boss.state:GetAttribute("RespawnAt")
	return {
		hp = if humanoid and humanoid.Health > 0 then humanoid.Health else nil,
		respawnAt = if typeof(respawnAt) == "number" then respawnAt else 0,
		damageBy = damageBy,
	}
end

local function save(boss: Boss)
	boss.dirty = false
	if not storeOk then
		return
	end
	local data = snapshot(boss)
	-- kept a little longer than one respawn cycle; a record older than that means nothing
	local ok, err = pcall(function()
		store:SetAsync(boss.id, data, boss.card.respawnSeconds + 600)
	end)
	if not ok then
		warn("[BossService] save failed", boss.id, err)
	end
end

local function load(id: string): Saved?
	if not storeOk then
		return nil
	end
	local ok, data = pcall(function()
		return store:GetAsync(id)
	end)
	if not ok then
		warn("[BossService] load failed", id, data)
		return nil
	end
	return if typeof(data) == "table" then data else nil
end

-- ---------------------------------------------------------------- casting helpers
local function setInvulnerable(boss: Boss, seconds: number)
	boss.busyUntil = math.max(boss.busyUntil, os.clock() + seconds)
	local model = boss.model
	if not model then
		return
	end
	-- only the attribute (CombatService refuses damage while it is set): a ForceField in a ~3000-part block
	-- model froze the server for ~600 ms each time a skill started [владелец 22.10: «очень сильно логает»].
	-- No Highlight: it also outlined the invisible root box; BossAnimator pulses the lava instead.
	model:SetAttribute("Shielded", true)
	task.delay(seconds, function()
		if
			(os.clock() >= boss.busyUntil - 0.01 or os.clock() < boss.stunnedUntil)
			and boss.model == model
		then
			model:SetAttribute("Shielded", false)
			publish(boss)
		end
	end)
	publish(boss)
end

-- What the golem is doing, for the clients' animator (BossAnimator): Action + when it started (server
-- time) + how long it lasts. The clients pose the joints locally every frame — smooth, no traffic.
local function act(boss: Boss, action: string, seconds: number)
	local model = boss.model
	if model then
		model:SetAttribute("Action", action)
		model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		model:SetAttribute("ActionLen", seconds)
	end
end

local function telegraphPart(size: Vector3, cf: CFrame, round: boolean, color: Color3?): BasePart
	local p = Instance.new("Part")
	p.Name = "BossTelegraph"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color or TELEGRAPH
	p.Transparency = 0.55
	if round then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(0.2, size.X, size.Z)
		p.CFrame = cf * CFrame.Angles(0, 0, math.pi / 2)
	else
		p.Size = size
		p.CFrame = cf
	end
	p.Parent = workspace
	TweenService:Create(
		p,
		TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.3 }
	):Play()
	return p
end

local function hurt(
	boss: Boss,
	f: { player: Player, root: BasePart, humanoid: Humanoid },
	amount: number,
	from: Vector3
)
	CombatService.ApplyDamage(f.humanoid, amount, "boss", nil, boss.model)
	HurtService.Knockback(
		f.player.Character :: Model,
		(f.root.Position - from) * Vector3.new(1, 0, 1)
	)
	_ = boss
end

-- ---------------------------------------------------------------- abilities
-- «Клинок из лавы»: the boss raises its arm, a red strip marks the line to the target, then a wave of lava
-- runs along it; whoever is on the strip when the wave passes takes damage.
local function lavaBlade(boss: Boss, target: Vector3)
	local root = boss.root :: BasePart
	local cfg = boss.fight.lavaBlade
	local ground = boss.spawn.Position.Y + 0.6
	local from = Vector3.new(root.Position.X, ground, root.Position.Z)
	local flat = (target - from) * Vector3.new(1, 0, 1)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	setInvulnerable(boss, cfg.telegraph + cfg.length / cfg.speed + 0.3)
	act(boss, "blade", cfg.telegraph + cfg.length / cfg.speed + 0.3)
	boss.state:SetAttribute("Telegraph", cfg.telegraph)
	local strip = telegraphPart(
		Vector3.new(cfg.width, 0.2, cfg.length),
		CFrame.lookAt(from + dir * (cfg.length / 2), from + dir * cfg.length),
		false,
		paletteColor(boss, "telegraph", TELEGRAPH)
	)
	task.wait(cfg.telegraph)
	strip:Destroy()
	local wave = Instance.new("Part")
	wave.Name = "LavaBlade"
	wave.Anchored = true
	wave.CanCollide = false
	wave.CanQuery = false
	wave.CanTouch = false
	wave.Material = Enum.Material.Neon
	wave.Color = paletteColor(boss, "blade", LAVA)
	wave.Size = Vector3.new(cfg.width, 5, 1.5)
	wave.Parent = workspace
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 8
	fire.Color = wave.Color
	fire.SecondaryColor = wave.Color:Lerp(Color3.new(0, 0, 0), 0.4)
	fire.Parent = wave
	if boss.model then
		Sfx.broadcast("player_hurt", root, 0.5, 0.5)
	end
	local hit: { [Player]: boolean } = {}
	local t0 = os.clock()
	local duration = cfg.length / cfg.speed
	while os.clock() - t0 < duration do
		local along = (os.clock() - t0) * cfg.speed
		wave.CFrame = CFrame.lookAt(
			from + dir * along + Vector3.new(0, 2.5, 0),
			from + dir * (along + 1) + Vector3.new(0, 2.5, 0)
		)
		for _, f in ipairs(fighters(boss)) do
			local rel = (f.root.Position - from) * Vector3.new(1, 0, 1)
			local a = rel:Dot(dir)
			local lateral = (rel - dir * a).Magnitude
			if not hit[f.player] and math.abs(a - along) < 3 and lateral < cfg.width / 2 + 1 then
				hit[f.player] = true
				hurt(boss, f, cfg.damage, from)
			end
		end
		RunService.Heartbeat:Wait()
	end
	wave:Destroy()
end

-- «Шипы из земли»: red circles appear under the players (three each in phase 2), then basalt spikes burst
-- out of them; whoever is still inside a circle takes damage and is thrown back.
local function earthSpikes(boss: Boss, phase2: boolean)
	local root = boss.root :: BasePart
	local cfg = boss.fight.earthSpikes
	local ground = boss.spawn.Position.Y + 0.6
	local spots: { Vector3 } = {}
	local random = Random.new()
	for _, f in ipairs(fighters(boss)) do
		local count = if phase2 then cfg.perTargetPhase2 else cfg.perTarget
		for k = 1, count do
			local offset = if k == 1
				then Vector3.zero
				else Vector3.new(random:NextNumber(-7, 7), 0, random:NextNumber(-7, 7))
			table.insert(spots, Vector3.new(f.root.Position.X, ground, f.root.Position.Z) + offset)
		end
	end
	if #spots == 0 then
		return
	end
	setInvulnerable(boss, cfg.telegraph + 0.6)
	act(boss, "spikes", cfg.telegraph + 0.6)
	boss.state:SetAttribute("Telegraph", cfg.telegraph)
	-- both fists slam the ground
	local marks = {}
	for _, at in ipairs(spots) do
		table.insert(
			marks,
			telegraphPart(
				Vector3.new(cfg.radius * 2, 0.2, cfg.radius * 2),
				CFrame.new(at),
				true,
				paletteColor(boss, "telegraph", TELEGRAPH)
			)
		)
	end
	task.wait(cfg.telegraph)
	for _, m in ipairs(marks) do
		m:Destroy()
	end
	Sfx.broadcast("player_fall", root, 0.9, 0.6)
	local spikes = {}
	for _, at in ipairs(spots) do
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			local r = if k == 0 then 0 else cfg.radius * 0.55
			local height = random:NextNumber(4, 7)
			local spike = Instance.new("Part")
			spike.Name = "EarthSpike"
			spike.Anchored = true
			spike.CanCollide = false
			spike.CanQuery = false
			spike.CanTouch = false
			spike.Material = Enum.Material.Basalt
			spike.Color = paletteColor(boss, "spikes", BASALT)
			spike.Size = Vector3.new(1.6, height, 1.6)
			local base = CFrame.new(at + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
				* CFrame.Angles(
					random:NextNumber(-0.25, 0.25),
					random:NextNumber(0, 6),
					random:NextNumber(-0.25, 0.25)
				)
			spike.CFrame = base * CFrame.new(0, -height / 2, 0)
			spike.Parent = workspace
			TweenService:Create(
				spike,
				TweenInfo.new(0.12, Enum.EasingStyle.Back),
				{ CFrame = base * CFrame.new(0, height / 2 - 0.4, 0) }
			):Play()
			table.insert(spikes, spike)
		end
		for _, f in ipairs(fighters(boss)) do
			local flat = (f.root.Position - at) * Vector3.new(1, 0, 1)
			if flat.Magnitude <= cfg.radius and not f.humanoid:GetAttribute("SpikedAt") then
				f.humanoid:SetAttribute("SpikedAt", os.clock()) -- one hit per burst even under overlapping circles
				hurt(boss, f, cfg.damage, at)
				task.delay(0.5, function()
					f.humanoid:SetAttribute("SpikedAt", nil)
				end)
			end
		end
	end
	task.wait(0.4)
	task.delay(1.2, function()
		for _, spike in ipairs(spikes) do
			TweenService:Create(spike, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			task.delay(0.45, function()
				spike:Destroy()
			end)
		end
	end)
end

-- «Таран» [coco-instruments: Минотавр]: a red strip marks the run, then the golem charges along it, hurting
-- whoever is in the way. If it rams a basalt pillar it is stunned for stunPillar s (the wall: stunWall s) and
-- takes ×stunDamageMultiplier damage meanwhile — lure it into a pillar.
local function charge(boss: Boss, target: Vector3)
	local root = boss.root :: BasePart
	local cfg = boss.fight.charge
	local flat = (target - root.Position) * Vector3.new(1, 0, 1)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else root.CFrame.LookVector
	local ground = boss.spawn.Position.Y + 0.6
	local from = Vector3.new(root.Position.X, ground, root.Position.Z)
	-- how far the run goes: up to maxDistance, shorter if a pillar or the arena wall is in the way
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	local arena = boss.spawn.Parent
	-- the arena folder plus every part tagged Pillar (the new floors build their pillars in their own part folders,
	-- scripts/locations/kit.luau pillarTag); a tagged part counts as a pillar whatever its name
	local include: { Instance } = if arena then { arena } else {}
	for _, p in ipairs(CollectionService:GetTagged("Pillar")) do
		table.insert(include, p)
	end
	params.FilterDescendantsInstances = include
	local hit = workspace:Raycast(root.Position, dir * cfg.maxDistance, params)
	local obstacle = if hit
			and (hit.Instance.Name:match("^Pillar") or hit.Instance:HasTag("Pillar"))
		then "pillar"
		elseif hit and hit.Instance.Name == "ArenaWall" then "wall"
		else nil
	local distance = if hit then math.max(0, hit.Distance - 4) else cfg.maxDistance
	-- never out of the arena even without a hit
	local endFlat = (from + dir * distance - boss.spawn.Position) * Vector3.new(1, 0, 1)
	if endFlat.Magnitude > boss.arenaRadius - 3 then
		distance = math.max(0, distance - (endFlat.Magnitude - (boss.arenaRadius - 3)))
		obstacle = obstacle or "wall"
	end
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
	setInvulnerable(boss, cfg.telegraph + distance / cfg.speed)
	act(boss, "charge", cfg.telegraph + distance / cfg.speed)
	boss.state:SetAttribute("Telegraph", cfg.telegraph)
	local strip = telegraphPart(
		Vector3.new(cfg.width, 0.2, math.max(distance, 1)),
		CFrame.lookAt(from + dir * (distance / 2), from + dir * distance),
		false,
		paletteColor(boss, "telegraph", TELEGRAPH)
	)
	task.wait(cfg.telegraph)
	strip:Destroy()
	local hitPlayers: { [Player]: boolean } = {}
	local start = root.Position
	root.Anchored = true -- the run is scripted: physics must not push back
	local t0 = os.clock()
	local duration = distance / cfg.speed
	while os.clock() - t0 < duration and boss.root == root do
		local along = (os.clock() - t0) * cfg.speed
		root.CFrame = CFrame.lookAt(start + dir * along, start + dir * (along + 1))
		root.AssemblyLinearVelocity = Vector3.zero
		for _, f in ipairs(fighters(boss)) do
			if
				not hitPlayers[f.player]
				and (f.root.Position - root.Position).Magnitude < cfg.width
			then
				hitPlayers[f.player] = true
				hurt(boss, f, cfg.damage, root.Position)
			end
		end
		RunService.Heartbeat:Wait()
	end
	root.Anchored = false
	if obstacle and boss.root == root then
		local seconds = if obstacle == "pillar" then cfg.stunPillar else cfg.stunWall
		boss.stunnedUntil = os.clock() + seconds
		boss.busyUntil = math.max(boss.busyUntil, boss.stunnedUntil)
		act(boss, "stunned", seconds)
		Sfx.broadcast("player_fall", root, 1, 0.5)
		-- dizzy: a spinning ring of sparks over the head, the golem slumps forward
		local model = boss.model
		local head = model and (model:FindFirstChild("Head") or model:FindFirstChild("J_head"))
		if head then
			local sparks = Instance.new("ParticleEmitter")
			sparks.Name = "Stunned"
			sparks.Rate = 25
			sparks.Lifetime = NumberRange.new(0.6)
			sparks.Speed = NumberRange.new(4)
			sparks.SpreadAngle = Vector2.new(180, 20)
			sparks.Color = ColorSequence.new(Color3.fromRGB(255, 240, 120))
			sparks.Size = NumberSequence.new(0.5)
			sparks.LightEmission = 1
			sparks.Parent = head
			task.delay(seconds, function()
				sparks:Destroy()
			end)
		end
		-- the shield of the charge is gone at once: the stun is the window to hit it
		if model then
			model:SetAttribute("Shielded", false)
		end
		publish(boss)
		task.delay(seconds, publish, boss)
	end
end

local function melee(boss: Boss, f: { player: Player, root: BasePart, humanoid: Humanoid })
	local root = boss.root :: BasePart
	local cfg = boss.fight.splinter
	local duration = if cfg then cfg.melee.duration else 0.9
	boss.busyUntil = math.max(boss.busyUntil, os.clock() + duration)
	act(boss, "melee", duration)
	task.wait(if cfg then cfg.melee.hitAt else 0.4)
	if
		boss.root == root
		and boss.humanoid
		and boss.humanoid.Health > 0
		and f.root.Parent
		and f.humanoid.Health > 0
		and (f.root.Position - root.Position).Magnitude <= boss.fight.meleeRange + 2
	then
		hurt(boss, f, boss.fight.meleeDamage, root.Position)
	end
	task.wait(0.3)
end

-- ---------------------------------------------------------------- life cycle
local spawnBoss: (boss: Boss, saved: Saved?) -> ()

-- [вики BOSS-CARDS: «Дроп — Древняя звезда, шанс 100 %», «За последний удар — Древний порошок / Лунная сталь /
-- Огненный осколок»] the items of a kill: stars to everyone with a reward share (the card's range), and to the last
-- hitter the powder (chance from the card's «1–N %», higher with a bigger damage share [решение]) and the shard of the
-- late bosses. Items that do not fit go to the storage [B] (p.stash).
local random = Random.new()
local LAST_HIT_SHARDS: { [string]: { string } } = {
	forest_spirit = { "moon_steel" }, -- Лесной дух
	ent = { "moon_steel" }, -- Грут
	the_lovers = { "fire_shard" }, -- Самурай
}
local function grant(p: any, id: string, count: number)
	local left = InventoryService.add(p, id, count)
	if left > 0 then
		local stash = table.clone(p.stash or {})
		local merged = false
		for _, entry in ipairs(stash) do
			if entry.id == id then
				entry.count += left
				merged = true
			end
		end
		if not merged then
			table.insert(stash, { id = id, count = left })
		end
		p.stash = stash
	end
end
local function killItems(boss: Boss, share: number, isLast: boolean): { [string]: number }
	local items: { [string]: number } = {}
	local stars = boss.card.ancientStars
	if typeof(stars) == "table" and #stars == 2 then
		items.ancient_star = random:NextInteger(stars[1], stars[2])
	end
	if isLast then
		local powder = boss.card.powderChance
		local q = typeof(powder) == "table" and powder.percentQualifier or nil
		if q and typeof(q.min) == "number" and typeof(q.max) == "number" then
			local chance = (q.min + (q.max - q.min) * math.clamp(share, 0, 1)) / 100
			if random:NextNumber() < chance then
				items.ancient_powder = 1
			end
		end
		for _, shard in ipairs(LAST_HIT_SHARDS[boss.card.id] or {}) do
			items[shard] = (items[shard] or 0) + 1
		end
	end
	return items
end

local function reward(boss: Boss, lastHit: number?)
	local total = 0
	for _, dealt in pairs(boss.damageBy) do
		total += dealt
	end
	local bank = (boss.card.money and boss.card.money[2] or 0) * Config.moneyScale
	local rules = Config.bosses.rewards
	local present = playersInLocation(boss)
	local payouts: { [number]: number } = {}
	local ranking = {}
	for userId, dealt in pairs(boss.damageBy) do
		table.insert(ranking, { userId = userId, dealt = dealt })
	end
	table.sort(ranking, function(a, b)
		return if a.dealt == b.dealt then a.userId < b.userId else a.dealt > b.dealt
	end)
	local top = {}
	for i = 1, math.min(3, #ranking) do
		local player = Players:GetPlayerByUserId(ranking[i].userId)
		table.insert(
			top,
			string.format(
				"%d. %s %d%%",
				i,
				if player then player.Name else "?",
				math.floor(ranking[i].dealt / math.max(total, 1) * 100 + 0.5)
			)
		)
	end
	for _, player in ipairs(present) do
		local dealt = boss.damageBy[player.UserId] or 0
		local share = if total > 0 then dealt / total else 0
		toast(player, "boss_killed", bossName(boss, player), table.concat(top, "  "))
		if share >= rules.minDamageShare then
			-- [меню] the card says «0–350 $»: a share of the bank, the last hit +20 %, never above the bank
			-- (a solo kill used to pay 350 × 1.2 = 420)
			-- the weapon books Общак (a bigger share of the bank) and Старатель (more stars) at 35 % of the damage
			local profile = ProfileService.Get(player)
			local bankMult, starMult = 1, 1
			if profile then
				bankMult, starMult = BookService.bossBonus(profile, share)
			end
			local amount = math.min(
				bank * bankMult,
				math.floor(
					bank
						* share
						* bankMult
						* (if lastHit == player.UserId then 1 + rules.lastHitBonus else 1)
				)
			)
			local items = killItems(boss, share, lastHit == player.UserId)
			if items.ancient_star and starMult > 1 then
				local stars = items.ancient_star * starMult
				items.ancient_star = math.floor(stars)
					+ (if random:NextNumber() < stars % 1 then 1 else 0)
			end
			ProfileService.Mutate(player, function(p)
				p.coins += amount
				payouts[player.UserId] = amount -- report the actual credit, including book / last-hit bonuses
				p.stats.bosses = (p.stats.bosses or 0) + 1
				for id, count in pairs(items) do
					grant(p, id, count)
				end
			end)
			toast(player, "boss_reward", Strings.money(amount), math.floor(share * 100 + 0.5))
			local locale = Strings.localeOf(player)
			for id, count in pairs(items) do
				toast(player, "boss_item", Strings.itemName(id, nil, locale), count)
			end
		elseif dealt > 0 then
			toast(player, "boss_no_reward", math.floor(rules.minDamageShare * 100))
		end
	end
	-- [владелец 29.10] every contributor, not only the podium: damage, share and actual money received.
	-- Resolve departed players' names outside the death handler; absent / ineligible players received zero.
	task.spawn(function()
		ChatService.announceWith(function(locale)
			local name = if locale == "ru" or not boss.card.nameEn
				then boss.card.name
				else boss.card.nameEn
			return Strings.t("chat_boss_killed", locale, name)
		end)
		for i, entry in ipairs(ranking) do
			local player = Players:GetPlayerByUserId(entry.userId)
			local name = if player then player.Name else tostring(entry.userId)
			if not player then
				local ok, found = pcall(Players.GetNameFromUserIdAsync, Players, entry.userId)
				if ok then
					name = found
				end
			end
			ChatService.announce(
				"chat_boss_payout",
				i,
				name,
				Strings.grouped(entry.dealt, 1),
				math.floor(entry.dealt / math.max(total, 1) * 100 + 0.5),
				Strings.grouped(
					(payouts[entry.userId] or 0) / Config.moneyScale,
					Config.money.displayDecimals
				)
			)
		end
	end)
end

local function died(boss: Boss)
	local model = boss.model
	local humanoid = boss.humanoid
	if not model or not humanoid then
		return
	end
	local lastHit = humanoid:GetAttribute("LastHitBy")
	reward(boss, if typeof(lastHit) == "number" then lastHit else nil)
	-- gang quests «Убить босса X ×N»: every gang that hit it counts the kill once
	local hitters = {}
	for userId in pairs(boss.damageBy) do
		table.insert(hitters, userId)
	end
	GangService.progressOnce(hitters, "bossKill", 1, boss.id)
	SplinterAbilities.Clear(boss)
	-- Set the action before clearing boss.model; clients keep the final pose until removal.
	if boss.fight.splinter then
		act(boss, "death", boss.fight.splinter.deathDuration)
	end
	boss.model, boss.humanoid, boss.root = nil, nil, nil
	table.clear(boss.damageBy)
	boss.state:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + boss.card.respawnSeconds)
	publish(boss)
	local root = model.PrimaryPart
	if boss.fight.splinter and root then
		root.Anchored = true
		root.CanCollide = false
		model:SetAttribute("Shielded", false)
		Debris:AddItem(model, boss.fight.splinter.deathDuration)
		task.delay(boss.card.respawnSeconds, function()
			spawnBoss(boss)
		end)
		return
	end
	if model:GetAttribute("BlockModel") and root then
		-- a Blender block model (thousands of voxel boxes) never changes its parts: breaking the joints, physics
		-- or a fade on every box rebuilt its render on every client (~0.6 s frozen frames [владелец 22.10:
		-- «очень сильно логает»]). It slumps (the stunned clip), topples forward over its feet into the ground
		-- as one piece, then vanishes in a puff of rot.
		act(boss, "stunned", 3)
		root.Anchored = true
		local start = root.CFrame
		local feet = start * CFrame.new(0, -BLOCK_ROOT_HEIGHT, 0)
		local fromFeet = feet:ToObjectSpace(start)
		task.spawn(function()
			local t0 = os.clock()
			while os.clock() - t0 < 1 and root.Parent do
				local k = TweenService:GetValue(
					os.clock() - t0,
					Enum.EasingStyle.Quad,
					Enum.EasingDirection.In
				)
				root.CFrame = feet
					* CFrame.Angles(math.rad(-80) * k, 0, 0)
					* CFrame.new(0, -1.5 * k, 0)
					* fromFeet
				RunService.Heartbeat:Wait()
			end
			Sfx.broadcast("player_fall", root, 1, 0.5)
		end)
		task.delay(2.2, function()
			local at = Instance.new("Part")
			at.Anchored, at.CanCollide, at.CanQuery, at.CanTouch = true, false, false, false
			at.Transparency = 1
			at.Size = Vector3.new(8, 2, 8)
			at.CFrame = CFrame.new(model:GetBoundingBox().Position)
			at.Parent = workspace
			Debris:AddItem(at, 2)
			local puff = Instance.new("ParticleEmitter")
			puff.Texture = "rbxasset://textures/particles/smoke_main.dds"
			puff.Shape = Enum.ParticleEmitterShape.Box
			puff.Rate = 0
			puff.Lifetime = NumberRange.new(0.8, 1.3)
			puff.Speed = NumberRange.new(2, 6)
			puff.SpreadAngle = Vector2.new(180, 180)
			puff.Size = NumberSequence.new(4, 7)
			puff.Transparency = NumberSequence.new(0.2, 1)
			puff.Color = ColorSequence.new(
				paletteColor(boss, "glow", LAVA):Lerp(Color3.fromRGB(70, 80, 60), 0.6)
			)
			puff.Parent = at
			puff:Emit(40)
			model:Destroy()
		end)
		task.delay(boss.card.respawnSeconds, function()
			spawnBoss(boss)
		end)
		return
	end
	-- it crumbles: joints go, the parts fall apart and fade
	for _, m in pairs(boss.motors) do
		m:Destroy()
	end
	table.clear(boss.motors)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = true
			p.Massless = false
			p.AssemblyLinearVelocity =
				Vector3.new(math.random(-12, 12), math.random(8, 18), math.random(-12, 12))
			TweenService:Create(p, TweenInfo.new(2.5), { Transparency = 1 }):Play()
		end
	end
	task.delay(3, function()
		model:Destroy()
	end)
	task.delay(boss.card.respawnSeconds, function()
		spawnBoss(boss)
	end)
end

function spawnBoss(boss: Boss, saved: Saved?)
	if boss.model then
		return
	end
	table.clear(boss.damageBy)
	boss.motors = {}
	local model = buildModel(boss)
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	-- a new server continues the fight of the old one: the wounds and everybody's share of the damage
	if saved and saved.hp and saved.hp > 0 then
		humanoid.Health = math.min(humanoid.MaxHealth, saved.hp)
		for userId, dealt in pairs(saved.damageBy or {}) do
			local n = tonumber(userId)
			if n and typeof(dealt) == "number" then
				boss.damageBy[n] = dealt
			end
		end
	end
	boss.model, boss.humanoid, boss.root = model, humanoid, model.PrimaryPart
	boss.busyUntil, boss.nextMeleeAt, boss.stunnedUntil = 0, 0, 0
	boss.nextAbilityAt = os.clock() + boss.fight.abilityCooldown
	boss.lastTargetAt = os.clock()
	local last = humanoid.Health
	local bonusing = false
	humanoid.HealthChanged:Connect(function(health)
		local delta = last - health
		last = health
		local by = humanoid:GetAttribute("LastHitBy")
		if delta > 0 and typeof(by) == "number" then
			boss.damageBy[by] = (boss.damageBy[by] or 0) + delta
			GangService.progressByUserId(by, "bossDamage", delta) -- gang quests: «Нанести N урона боссам»
			boss.lastTargetAt = os.clock()
			-- stunned after a ram: every hit lands ×stunDamageMultiplier (the extra counts for the hitter)
			if os.clock() < boss.stunnedUntil and not bonusing and health > 0 then
				bonusing = true
				humanoid.Health =
					math.max(0, health - delta * (boss.fight.charge.stunDamageMultiplier - 1))
				bonusing = false
			end
		end
		publish(boss)
	end)
	humanoid.Died:Once(function()
		died(boss)
	end)
	boss.state:SetAttribute("RespawnAt", 0)
	setInvulnerable(boss, 1.8)
	act(boss, "roar", 1.8)
	publish(boss)
	-- no spawn announcement to everyone [владелец 27.10: «выключи уведомление о появлении боссов. Их не должно быть»]:
	-- the arena's countdown board (BossHud) shows when a boss is up
end

local function think(boss: Boss)
	local root, humanoid = boss.root, boss.humanoid
	if not root or not humanoid or humanoid.Health <= 0 or os.clock() < boss.busyUntil then
		return
	end
	local list = fighters(boss)
	if #list == 0 then
		-- nobody to fight: walk home; after leashSeconds heal fully and forget the damage
		humanoid:MoveTo(boss.spawn.Position)
		if
			os.clock() - boss.lastTargetAt > boss.fight.leashSeconds
			and humanoid.Health < humanoid.MaxHealth
		then
			humanoid.Health = humanoid.MaxHealth
			table.clear(boss.damageBy)
			publish(boss)
		end
		return
	end
	boss.lastTargetAt = os.clock()
	table.sort(list, function(a, b)
		return (a.root.Position - root.Position).Magnitude
			< (b.root.Position - root.Position).Magnitude
	end)
	local target = list[1]
	local now = os.clock()
	local phase2 = humanoid.Health <= humanoid.MaxHealth * boss.fight.phase2At
	if now >= boss.nextAbilityAt then
		boss.nextAbilityAt = now
			+ boss.fight.abilityCooldown
				* (if phase2 then boss.fight.phase2CooldownScale else 1)
		boss.nextAbility = boss.nextAbility % (if boss.fight.splinter then 4 else 3) + 1
		humanoid:MoveTo(root.Position)
		if boss.fight.splinter then
			SplinterAbilities.Cast(boss, boss.nextAbility, target.root.Position, phase2, {
				act = act,
				hurt = hurt,
				fighters = fighters,
				telegraph = telegraphPart,
			})
		elseif boss.nextAbility == 1 then
			task.spawn(lavaBlade, boss, target.root.Position)
		elseif boss.nextAbility == 2 then
			task.spawn(earthSpikes, boss, phase2)
		else
			task.spawn(charge, boss, target.root.Position)
		end
		return
	end
	local distance = ((target.root.Position - root.Position) * Vector3.new(1, 0, 1)).Magnitude
	if distance <= boss.fight.meleeRange then
		humanoid:MoveTo(root.Position)
		root.CFrame = CFrame.lookAt(
			root.Position,
			Vector3.new(target.root.Position.X, root.Position.Y, target.root.Position.Z)
		)
		if now >= boss.nextMeleeAt then
			boss.nextMeleeAt = now + boss.fight.meleeCooldown
			task.spawn(melee, boss, target)
		end
	else
		-- chase, but never leave the arena
		local goal = target.root.Position
		local flat = (goal - boss.spawn.Position) * Vector3.new(1, 0, 1)
		if flat.Magnitude > boss.arenaRadius - 4 then
			goal = boss.spawn.Position + flat.Unit * (boss.arenaRadius - 4)
		end
		humanoid:MoveTo(goal)
		-- a block in the way: if it barely moves while chasing, it jumps over (a golem stepping up)
		local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
		if speed < 1.5 and distance > boss.fight.meleeRange + 2 then
			boss.stuckFor += 0.15
			if boss.stuckFor > 0.45 then
				boss.stuckFor = 0
				humanoid.Jump = true
				act(boss, "jump", 0.8)
			end
		else
			boss.stuckFor = 0
		end
	end
end

local function register(spawnPart: Instance)
	if not spawnPart:IsA("BasePart") then
		return
	end
	local id = spawnPart:GetAttribute("BossId")
	if typeof(id) ~= "string" or bosses[id] then
		return
	end
	local card
	for _, b in ipairs(Config.bosses.bosses) do
		if b.id == id then
			card = b
		end
	end
	if not card or not card.fight or not card.hp then
		warn("[BossService] no fight config for boss", id)
		return
	end
	local folder = ReplicatedStorage:FindFirstChild("Bosses")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Bosses"
		folder.Parent = ReplicatedStorage
	end
	local state = Instance.new("Configuration")
	state.Name = id
	state:SetAttribute("Name", card.name)
	state:SetAttribute("NameEn", card.nameEn or card.name)
	state:SetAttribute("LocationId", card.locationId or "")
	state:SetAttribute("Origin", spawnPart.Position)
	local arenaRadius = spawnPart:GetAttribute("ArenaRadius")
	-- the client shows the boss bar only near the arena (BossHud)
	state:SetAttribute("ArenaRadius", if typeof(arenaRadius) == "number" then arenaRadius else 40)
	state.Parent = folder
	local boss: Boss = {
		id = id,
		card = card,
		fight = card.fight,
		spawn = spawnPart,
		arenaRadius = if typeof(arenaRadius) == "number" then arenaRadius else 40,
		state = state,
		model = nil,
		humanoid = nil,
		root = nil,
		motors = {},
		damageBy = {},
		busyUntil = 0,
		nextMeleeAt = 0,
		nextAbilityAt = 0,
		lastTargetAt = 0,
		walkPhase = 0,
		stuckFor = 0,
		nextAbility = 0,
		stunnedUntil = 0,
		dirty = false,
	}
	bosses[id] = boss
	state:SetAttribute("RespawnAt", workspace:GetServerTimeNow() + card.fight.firstSpawnSeconds)
	publish(boss)
	boss.dirty = false -- nothing to save before the old record is read
	task.spawn(function()
		local saved = load(id)
		local now = workspace:GetServerTimeNow()
		if saved and typeof(saved.respawnAt) == "number" and saved.respawnAt > now then
			-- killed on another server: its respawn timer keeps running here
			state:SetAttribute("RespawnAt", saved.respawnAt)
			publish(boss)
			task.delay(saved.respawnAt - now, spawnBoss, boss)
		else
			task.delay(card.fight.firstSpawnSeconds, spawnBoss, boss, saved)
		end
	end)
end

function BossService.Start()
	if started then
		return
	end
	started = true
	for _, part in ipairs(CollectionService:GetTagged("BossSpawn")) do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal("BossSpawn"):Connect(register)
	local thinkAt = 0
	RunService.Heartbeat:Connect(function(dt)
		thinkAt += dt
		if thinkAt >= 0.15 then
			thinkAt = 0
			for _, boss in pairs(bosses) do
				think(boss)
			end
		end
	end)
	task.spawn(function()
		while true do
			task.wait(SAVE_EVERY)
			for _, boss in pairs(bosses) do
				if boss.dirty then
					task.spawn(save, boss)
				end
			end
		end
	end)
	game:BindToClose(function()
		for _, boss in pairs(bosses) do
			save(boss)
		end
	end)
	-- Studio-only QA hook: ServerStorage.BossDebug ("spawn" | "kill" | "state", bossId)
	if RunService:IsStudio() then
		local api = Instance.new("BindableFunction")
		api.Name = "BossDebug"
		api.OnInvoke = function(op: string, id: string): any
			local boss = bosses[id]
			if not boss then
				return "no boss " .. tostring(id)
			end
			if op == "spawn" then
				spawnBoss(boss)
			elseif op == "kill" and boss.humanoid then
				boss.humanoid.Health = 0
			end
			local h = boss.humanoid
			return string.format(
				"alive=%s hp=%s/%d busy=%.1f damageBy=%d",
				tostring(h ~= nil and h.Health > 0),
				if h then string.format("%.1f", h.Health) else "-",
				boss.card.hp,
				math.max(0, boss.busyUntil - os.clock()),
				#(function()
						local t = {}
						for k in pairs(boss.damageBy) do
							table.insert(t, k)
						end
						return t
					end)()
			)
		end
		api.Parent = game:GetService("ServerStorage")
	end
end

return BossService
