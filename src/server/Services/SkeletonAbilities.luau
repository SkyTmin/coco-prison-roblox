--!strict
-- Original Skeletron encounter: audited swipe/stomp/breath/roar names, authored geometry and timing.
local BossPhysics = require(script.Parent.BossPhysics)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockRig = require(Shared.BlockRig)
local CollisionGroups = require(script.Parent.CollisionGroups)
local NeedsService = require(script.Parent.NeedsService)
local Definition = require(Shared.Models.skeleton_king) :: any
local Prepared = BlockRig.prepare(Definition)
local SkeletonAbilities = {}
local casts: { [any]: any } = {}
local encounters: { [any]: any } = {}
local FLAT, BONE, POISON =
	Vector3.new(1, 0, 1), Color3.fromRGB(174, 147, 107), Color3.fromRGB(98, 126, 65)
local NAMES = { "sklrstomp", "sklpoisonbreath", "skllstomp", "sklroar" }

local function living(boss: any, e: any): boolean
	return encounters[boss] == e
		and boss.root == e.root
		and e.root.Parent ~= nil
		and boss.humanoid.Health > 0
end
local function alive(boss: any, s: any): boolean
	return casts[boss] == s and living(boss, s.encounter)
end
local function finish(boss: any, s: any)
	if casts[boss] ~= s then
		return
	end
	casts[boss] = nil
	s.folder:Destroy()
	if living(boss, s.encounter) then
		boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = s.speed, s.rotate
		BossPhysics.restore(s.root, s.anchored)
	end
end
function SkeletonAbilities.Clear(boss: any)
	if casts[boss] then
		finish(boss, casts[boss])
	end
	local e = encounters[boss]
	encounters[boss] = nil
	if e then
		e.folder:Destroy()
	end
end
local function begin(boss: any, name: string, cfg: any, target: Vector3, hooks: any): any
	if casts[boss] then
		finish(boss, casts[boss])
	end
	local e = encounters[boss]
	if not e or not living(boss, e) then
		SkeletonAbilities.Clear(boss)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "SkeletonEncounter", workspace
		e = { root = boss.root, folder = folder, minions = {} }
		encounters[boss] = e
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "SkeletonCast", e.folder
	local s = {
		root = boss.root,
		encounter = e,
		folder = folder,
		speed = boss.humanoid.WalkSpeed,
		rotate = boss.humanoid.AutoRotate,
		anchored = boss.root.Anchored,
	}
	casts[boss] = s
	local direction = (target - s.root.Position) * FLAT
	if direction.Magnitude > 0.01 then
		s.root.CFrame = CFrame.lookAt(s.root.Position, s.root.Position + direction)
	end
	boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate, s.root.Anchored = 0, false, true
	boss.busyUntil = os.clock() + cfg.duration
	if name ~= "atkrswipe" and name ~= "atklswipe" then
		boss.nextAbilityAt =
			math.max(boss.nextAbilityAt or 0, boss.busyUntil + boss.fight.skeleton.recovery)
	end
	boss.state:SetAttribute("Telegraph", cfg.release)
	boss.model:SetAttribute("Shielded", false)
	hooks.act(boss, name, cfg.duration)
	task.delay(cfg.duration, function()
		finish(boss, s)
	end)
	return s
end
local function params(boss: any, e: any, hooks: any): RaycastParams
	local ignore = { boss.model, e.folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, f in hooks.fighters(boss) do
		table.insert(ignore, f.player.Character)
	end
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, ignore
	ray.RespectCanCollide, ray.IgnoreWater = true, true
	return ray
end
local function floorAt(boss: any, p: Vector3, ray: RaycastParams): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 7, 0), Vector3.new(0, -24, 0), ray)
	return if hit
		then hit.Position + Vector3.new(0, 0.08, 0)
		else Vector3.new(p.X, boss.spawn.Position.Y + boss.spawn.Size.Y / 2 + 0.08, p.Z)
end
local function part(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Parent = Enum.Material.SmoothPlastic, folder
	return p
end
local function mark(s: any, hooks: any, p: Vector3, radius: number, color: Color3): BasePart
	local m = hooks.telegraph(Vector3.new(radius * 2, 0.12, radius * 2), CFrame.new(p), true, color)
	m.Parent = s.folder
	return m
end
local function sight(f: any, from: Vector3, ray: RaycastParams): boolean
	return f.root.Parent ~= nil
		and f.humanoid.Health > 0
		and workspace:Raycast(from, f.root.Position - from, ray) == nil
end
local function socket(boss: any, clip: string, t: number, name: string): CFrame
	local joint = boss.model:FindFirstChild("J_root")
	local motor = joint and joint:FindFirstChild("root")
	local origin = boss.root.CFrame
		* (if motor and motor:IsA("Motor6D") then motor.C0 else CFrame.new(0, -4.5, 0))
	local worlds, pivots = {}, {}
	for _, j in Definition.joints do
		local pivot = Vector3.new(j.pivot[1], j.pivot[2], j.pivot[3])
		pivots[j.name] = pivot
		worlds[j.name] = (if j.parent then worlds[j.parent] else origin)
			* CFrame.new(if j.parent then pivot - pivots[j.parent] else pivot)
			* BlockRig.sample(Prepared.clips[clip], j.name, t)
		if j.name == name then
			return worlds[j.name]
		end
	end
	return origin
end
local function safePoint(boss: any, e: any, hooks: any, target: Vector3, range: number): Vector3?
	local ray = params(boss, e, hooks)
	local d = (target - boss.root.Position) * FLAT
	if d.Magnitude > range then
		d = d.Unit * range
	end
	local point = boss.root.Position + d
	if ((point - boss.spawn.Position) * FLAT).Magnitude > boss.arenaRadius - 3 then
		return nil
	end
	local wall = if d.Magnitude > 0.01 then workspace:Raycast(boss.root.Position, d, ray) else nil
	if wall then
		return nil
	end
	point = floorAt(boss, point, ray)
	-- Ground effects cannot jump across a low wall hidden below the root-height ray.
	local from = floorAt(boss, boss.root.Position, ray) + Vector3.new(0, 0.6, 0)
	if workspace:Raycast(from, point + Vector3.new(0, 0.6, 0) - from, ray) then
		return nil
	end
	return point
end
local function snare(f: any, seconds: number, hooks: any)
	if hooks.snare then
		hooks.snare(f, seconds)
		return
	end
	local player = Players:GetPlayerFromCharacter(f.player.Character)
	if player then
		NeedsService.GiveEffect(player, "slowness", 6, seconds)
	end
end
local function trap(boss: any, e: any, at: Vector3, cfg: any, hooks: any)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "SkeletonTrap", e.folder
	-- Six joint-shaped fingers rise, curl in, then withdraw. Separate low-cost effect geometry.
	for i = 1, 6 do
		local angle = i * math.pi / 3
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local base = at + dir * cfg.radius * 0.8
		local stem = part(
			folder,
			"BoneFinger",
			Vector3.new(0.28, 1.7, 0.32),
			CFrame.lookAt(base - Vector3.new(0, 0.85, 0), at - Vector3.new(0, 0.85, 0)),
			BONE
		)
		local tip = part(
			folder,
			"BoneTip",
			Vector3.new(0.24, 0.65, 0.28),
			stem.CFrame * CFrame.new(0, 1.1, 0),
			BONE
		)
		local goal = CFrame.lookAt(base + Vector3.new(0, 0.8, 0), at + Vector3.new(0, 0.8, 0))
			* CFrame.Angles(-0.2, 0, 0)
		TweenService:Create(stem, TweenInfo.new(0.18), { CFrame = goal }):Play()
		TweenService:Create(
			tip,
			TweenInfo.new(0.27),
			{ CFrame = goal * CFrame.new(0, 0.95, -0.15) * CFrame.Angles(-0.65, 0, 0) }
		):Play()
		task.delay(cfg.lifetime - 0.3, function()
			if folder.Parent then
				for _, p in { stem, tip } do
					TweenService:Create(
						p,
						TweenInfo.new(0.28),
						{ CFrame = p.CFrame - Vector3.new(0, 2.4, 0), Transparency = 1 }
					):Play()
				end
			end
		end)
	end
	Debris:AddItem(folder, cfg.lifetime)
	task.spawn(function()
		for _ = 1, cfg.ticks do
			if not living(boss, e) or not folder.Parent then
				return
			end
			local ray = params(boss, e, hooks)
			for _, f in hooks.fighters(boss) do
				if
					math.abs(f.root.Position.Y - at.Y) < 5
					and ((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
					and sight(f, at + Vector3.new(0, 1, 0), ray)
				then
					if hooks.hurt(boss, f, cfg.damage / cfg.ticks, at, 0, 0) ~= false then
						snare(f, cfg.snareSeconds, hooks)
					end
				end
			end
			task.wait(cfg.tickInterval)
		end
	end)
end
local function stomp(boss: any, s: any, cfg: any, target: Vector3, phase2: boolean, hooks: any)
	local points, warnings = {}, {}
	local candidates = { target }
	if phase2 then
		for _, f in hooks.fighters(boss) do
			if
				#candidates < cfg.phase2Count
				and (f.root.Position - target).Magnitude > cfg.radius * 2
			then
				table.insert(candidates, f.root.Position)
			end
		end
	end
	for _, p in candidates do
		local at = safePoint(boss, s.encounter, hooks, p, cfg.range)
		if at then
			table.insert(points, at)
			table.insert(warnings, mark(s, hooks, at, cfg.radius, BONE))
		end
	end
	task.wait(cfg.release)
	if not alive(boss, s) then
		return
	end
	for _, m in warnings do
		m:Destroy()
	end
	for _, p in points do
		-- Repeat wall checks at release (including walls inserted during the telegraph).
		if safePoint(boss, s.encounter, hooks, p, cfg.range) then
			trap(boss, s.encounter, p, cfg, hooks)
		end
	end
end
local function breath(boss: any, s: any, cfg: any, target: Vector3, hooks: any)
	local at = safePoint(boss, s.encounter, hooks, target, cfg.range)
	if not at then
		return
	end
	local warning = mark(s, hooks, at, cfg.radius, POISON)
	task.wait(cfg.release)
	if not alive(boss, s) then
		return
	end
	warning:Destroy()
	local e = s.encounter
	local ray = params(boss, e, hooks)
	local origin = socket(boss, "sklpoisonbreath", cfg.release, "jaw").Position
	-- The mouth may extend beyond a close wall: never originate a cloud on its far side.
	if
		workspace:Raycast(s.root.Position, origin - s.root.Position, ray)
		or workspace:Raycast(origin, at + Vector3.new(0, 1, 0) - origin, ray)
	then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "SkeletonPoison", e.folder
	for i = 1, 5 do
		local p = part(folder, "Breath", Vector3.new(0.32, 0.32, 0.32), CFrame.new(origin), POISON)
		p.Transparency = 0.2
		TweenService:Create(p, TweenInfo.new(0.22 + i * 0.025), {
			Position = at + Vector3.new((i - 3) * 0.35, 1, 0),
			Size = Vector3.one * 0.65,
			Transparency = 1,
		}):Play()
		Debris:AddItem(p, 0.4)
	end
	task.wait(0.25)
	if not living(boss, e) or not folder.Parent then
		return
	end
	-- Collision is checked again on arrival, so a wall appearing during flight blocks the cloud.
	if workspace:Raycast(origin, at + Vector3.new(0, 1, 0) - origin, params(boss, e, hooks)) then
		folder:Destroy()
		return
	end
	local pool = part(
		folder,
		"PoisonArea",
		Vector3.new(0.08, cfg.radius * 2, cfg.radius * 2),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		POISON
	)
	pool.Shape, pool.Transparency = Enum.PartType.Cylinder, 0.72
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color, emitter.Rate, emitter.Lifetime =
		ColorSequence.new(POISON), 5, NumberRange.new(0.6, 1)
	emitter.Speed, emitter.Size, emitter.Transparency =
		NumberRange.new(0.5, 1.2),
		NumberSequence.new(1.5),
		NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.76), NumberSequenceKeypoint.new(1, 1) })
	emitter.LightEmission, emitter.Parent = 0, pool
	Debris:AddItem(folder, cfg.lifetime + 0.1)
	for _ = 1, cfg.ticks do
		if not living(boss, e) or not folder.Parent then
			return
		end
		ray = params(boss, e, hooks)
		for _, f in hooks.fighters(boss) do
			if
				math.abs(f.root.Position.Y - at.Y) < 5
				and ((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
				and sight(f, at + Vector3.new(0, 1, 0), ray)
			then
				hooks.hurt(boss, f, cfg.damage / cfg.ticks, at, 0.3, 0)
			end
		end
		task.wait(cfg.tickInterval)
	end
	folder:Destroy()
end
local function minion(boss: any, e: any, at: Vector3, cfg: any, hooks: any)
	local model = Instance.new("Model")
	model.Name = "SkeletonWarrior"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "HumanoidRootPart", Vector3.new(1.6, 2.2, 1.2), 1
	root.CFrame, root.Parent, root.Anchored = CFrame.new(at + Vector3.new(0, 1.8, 0)), model, true
	BlockRig.build(
		require(Shared.Models.skeleton_minion),
		model,
		root,
		root.CFrame * CFrame.new(0, -1.8, 0),
		boss.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 0.7
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart, model.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	model:SetAttribute("MobId", "skeleton_minion")
	model:SetAttribute("BaseWalkSpeed", cfg.speed)
	model:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	CollisionGroups.mob(model)
	model.Parent = e.folder
	CollectionService:AddTag(model, "Mob")
	table.insert(e.minions, model)
	Debris:AddItem(model, cfg.lifetime + cfg.spawnDuration + 2.6)
	task.spawn(function()
		task.wait(cfg.spawnDuration)
		if not living(boss, e) or not model.Parent then
			return
		end
		if h.Health > 0 then
			root.Anchored = false
			root:SetNetworkOwner(nil)
			h.WalkSpeed = cfg.speed
		end
		local expires, nextHit = os.clock() + cfg.lifetime, 0
		while living(boss, e) and model.Parent and h.Health > 0 and os.clock() < expires do
			local nearest, distance = nil, math.huge
			for _, f in hooks.fighters(boss) do
				local d = (f.root.Position - root.Position).Magnitude
				if d < distance then
					nearest, distance = f, d
				end
			end
			if not nearest then
				break
			end
			local goal = nearest.root.Position
			local away = (goal - boss.spawn.Position) * FLAT
			if away.Magnitude > boss.arenaRadius - 3 then
				goal = boss.spawn.Position + away.Unit * (boss.arenaRadius - 3)
			end
			h:MoveTo(goal)
			if distance < cfg.reach and os.clock() >= nextHit then
				nextHit = os.clock() + cfg.cooldown
				model:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				task.wait(cfg.hitAt)
				if
					living(boss, e)
					and model.Parent
					and h.Health > 0
					and nearest.root.Parent
					and (nearest.root.Position - root.Position).Magnitude < cfg.reach
					and sight(nearest, root.Position, params(boss, e, hooks))
				then
					hooks.hurt(boss, nearest, cfg.damage, root.Position, 0.5, 0.5)
				end
			end
			task.wait(0.15)
		end
		if model.Parent then
			h.Health = 0
			h.WalkSpeed = 0
			root.Anchored = true
			Debris:AddItem(model, 2.5)
		end
	end)
end
local function summon(boss: any, s: any, cfg: any, phase2: boolean, hooks: any)
	local points, warnings = {}, {}
	local count = if phase2 then cfg.phase2Count else cfg.count
	for i = 1, count do
		local angle = i * math.pi * 2 / count
		local at = safePoint(
			boss,
			s.encounter,
			hooks,
			s.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 6,
			cfg.range
		)
		if at then
			table.insert(points, at)
			table.insert(warnings, mark(s, hooks, at, 1.2, BONE))
		end
	end
	task.wait(cfg.release)
	if not alive(boss, s) then
		return
	end
	for _, m in warnings do
		m:Destroy()
	end
	local survivors = {}
	for _, m in s.encounter.minions do
		local h = m:FindFirstChildOfClass("Humanoid")
		if m.Parent and h and h.Health > 0 then
			table.insert(survivors, m)
		end
	end
	s.encounter.minions = survivors
	for _, at in points do
		if #s.encounter.minions >= cfg.maxAlive then
			break
		end
		if safePoint(boss, s.encounter, hooks, at, cfg.range) then
			minion(boss, s.encounter, at, cfg, hooks)
		end
	end
end
function SkeletonAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	phase2: boolean,
	hooks: any
)
	local name = NAMES[index]
	local cfg = boss.fight.skeleton[name]
	local s = begin(boss, name, cfg, target, hooks)
	task.spawn(function()
		if name == "sklroar" then
			summon(boss, s, cfg, phase2, hooks)
		elseif name == "sklpoisonbreath" then
			breath(boss, s, cfg, target, hooks)
		else
			stomp(boss, s, cfg, target, phase2, hooks)
		end
	end)
end
function SkeletonAbilities.Melee(boss: any, target: Vector3, hooks: any)
	local e = encounters[boss]
	local name = if e and e.lastMelee == "atkrswipe" then "atklswipe" else "atkrswipe"
	local cfg = boss.fight.skeleton[name]
	local s = begin(boss, name, cfg, target, hooks)
	s.encounter.lastMelee = name
	task.delay(cfg.release, function()
		if not alive(boss, s) then
			return
		end
		local ray = params(boss, s.encounter, hooks)
		for _, f in hooks.fighters(boss) do
			local d = (f.root.Position - s.root.Position) * FLAT
			if
				math.abs(f.root.Position.Y - s.root.Position.Y) < 6
				and d.Magnitude <= cfg.radius
				and (d.Magnitude < 0.01 or d.Unit:Dot(s.root.CFrame.LookVector) >= math.cos(
					math.rad(cfg.halfAngle)
				))
				and sight(f, s.root.Position, ray)
			then
				hooks.hurt(boss, f, cfg.damage, s.root.Position)
			end
		end
	end)
end
return SkeletonAbilities
