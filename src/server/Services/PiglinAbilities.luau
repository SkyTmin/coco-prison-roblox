--!strict
-- Original combat for the audited Piglin Glutton action names. All ranges/damage are our config.
-- Cast tokens cancel delayed work; the encounter owns surviving guards independently of each cast.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockRig = require(Shared.BlockRig)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Definition = require(Shared.Models.piglin_king) :: any
local Prepared = BlockRig.prepare(Definition)
local PiglinAbilities = {}
local casts: { [any]: any } = {}
local encounters: { [any]: any } = {}
local FLAT, GOLD = Vector3.new(1, 0, 1), Color3.fromRGB(195, 143, 58)
local NAMES =
	{ "footstomp", "upchuck", "summoningchant", "charge", "healing", "spinslam", "bodyslam" }

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
		s.root.Anchored = s.anchored
	end
end
function PiglinAbilities.Clear(boss: any)
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
		PiglinAbilities.Clear(boss)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "PiglinEncounter", workspace
		e = { root = boss.root, folder = folder, guards = {} }
		encounters[boss] = e
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "PiglinCast", e.folder
	local s = {
		encounter = e,
		root = boss.root,
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
	if name ~= "verticalatk" and name ~= "horizontalatk" then
		boss.nextAbilityAt =
			math.max(boss.nextAbilityAt or 0, boss.busyUntil + boss.fight.piglin.recovery)
	end
	boss.state:SetAttribute("Telegraph", cfg.release)
	-- The king remains damageable while acting, including the long heal / charge recovery.
	boss.model:SetAttribute("Shielded", false)
	hooks.act(boss, name, cfg.duration)
	task.delay(cfg.duration, function()
		finish(boss, s)
	end)
	return s
end
local function params(boss: any, s: any, hooks: any): RaycastParams
	local ignore = { boss.model, s.encounter.folder }
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
local function ground(boss: any, p: Vector3, ray: RaycastParams): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 8, 0), Vector3.new(0, -28, 0), ray)
	return if hit
		then hit.Position + Vector3.new(0, 0.1, 0)
		else Vector3.new(p.X, boss.spawn.Position.Y + boss.spawn.Size.Y / 2 + 0.1, p.Z)
end
local function part(folder: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Parent = Enum.Material.SmoothPlastic, folder
	return p
end
local function mark(s: any, hooks: any, at: Vector3, radius: number): BasePart
	local m = hooks.telegraph(Vector3.new(radius * 2, 0.15, radius * 2), CFrame.new(at), true, GOLD)
	m.Parent = s.folder
	return m
end
local function pulse(s: any, at: Vector3, radius: number)
	local p = part(
		s.folder,
		"PiglinImpact",
		Vector3.new(0.12, 1, 1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		GOLD
	)
	p.Shape, p.Transparency = Enum.PartType.Cylinder, 0.45
	TweenService:Create(
		p,
		TweenInfo.new(0.35),
		{ Size = Vector3.new(0.12, radius * 2, radius * 2), Transparency = 1 }
	):Play()
	Debris:AddItem(p, 0.4)
end
local function clearSight(f: any, from: Vector3, ray: RaycastParams): boolean
	return f.root.Parent ~= nil
		and f.humanoid.Health > 0
		and workspace:Raycast(from, f.root.Position - from, ray) == nil
end
local function area(
	boss: any,
	s: any,
	hooks: any,
	at: Vector3,
	radius: number,
	damage: number,
	angle: number?
)
	local ray = params(boss, s, hooks)
	for _, f in hooks.fighters(boss) do
		local d = (f.root.Position - at) * FLAT
		if
			math.abs(f.root.Position.Y - at.Y) < 7
			and d.Magnitude <= radius
			and (not angle or d.Magnitude < 0.01 or d.Unit:Dot(s.root.CFrame.LookVector) >= math.cos(
				math.rad(angle)
			))
			and clearSight(f, at + Vector3.new(0, 2, 0), ray)
		then
			hooks.hurt(boss, f, damage, at)
		end
	end
end
local function socket(boss: any, clip: string, t: number, name: string): CFrame
	local joint = boss.model:FindFirstChild("J_root")
	local motor = joint and joint:FindFirstChild("root")
	local origin = boss.root.CFrame
		* (if motor and motor:IsA("Motor6D") then motor.C0 else CFrame.new(0, -4.5, 0))
	local worlds, pivots = {}, {}
	for _, j in Definition.joints do
		local p = Vector3.new(j.pivot[1], j.pivot[2], j.pivot[3])
		pivots[j.name] = p
		local base = if j.parent then p - pivots[j.parent] else p
		worlds[j.name] = (if j.parent then worlds[j.parent] else origin)
			* CFrame.new(base)
			* BlockRig.sample(Prepared.clips[clip], j.name, t)
		if j.name == name then
			return worlds[j.name]
		end
	end
	return origin
end
local function impact(boss: any, s: any, cfg: any, hooks: any)
	local ray = params(boss, s, hooks)
	local forward = s.root.CFrame.LookVector * (cfg.forward or 0)
	local wall = if forward.Magnitude > 0.001
		then workspace:Raycast(s.root.Position, forward, ray)
		else nil
	local center = s.root.Position
		+ (if wall then forward.Unit * math.max(0, wall.Distance - 0.3) else forward)
	local at = ground(boss, center, ray)
	local warning = mark(s, hooks, at, cfg.radius)
	task.wait(cfg.release)
	warning:Destroy()
	if not alive(boss, s) then
		return
	end
	area(boss, s, hooks, at, cfg.radius, cfg.damage, cfg.halfAngle)
	pulse(s, at, cfg.radius)
end
local function distanceToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * FLAT
	local t = if ab:Dot(ab) > 0.0001
		then math.clamp(((p - a) * FLAT):Dot(ab) / ab:Dot(ab), 0, 1)
		else 0
	return ((p - a - ab * t) * FLAT).Magnitude
end
local function charge(boss: any, s: any, cfg: any, hooks: any)
	local start, dir = s.root.Position, s.root.CFrame.LookVector
	local ray = params(boss, s, hooks)
	local radial = (start - boss.spawn.Position) * FLAT
	local projection = radial:Dot(dir)
	local boundary = -projection
		+ math.sqrt(math.max(0, projection ^ 2 + (boss.arenaRadius - 5) ^ 2 - radial:Dot(radial)))
	local distance = math.min(cfg.maxDistance, math.max(0, boundary))
	local cast = workspace:Spherecast(start, 2, dir * distance, ray)
	if cast then
		distance = math.max(0, cast.Distance - 0.25)
	end
	local warning = hooks.telegraph(
		Vector3.new(cfg.radius * 2, 0.15, math.max(0.1, distance)),
		CFrame.lookAt(
			ground(boss, start + dir * distance / 2, ray),
			ground(boss, start + dir * distance, ray) + dir * 0.01
		),
		false,
		GOLD
	)
	warning.Parent = s.folder
	task.wait(cfg.release)
	warning:Destroy()
	if not alive(boss, s) then
		return
	end
	local began, previous, hit = os.clock(), start, {}
	local overlap = OverlapParams.new()
	overlap.FilterType = ray.FilterType
	overlap.FilterDescendantsInstances = ray.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	while alive(boss, s) do
		if
			#workspace:GetPartBoundsInBox(CFrame.new(previous), Vector3.new(3.8, 3.8, 3.8), overlap)
			> 0
		then
			break
		end
		local along = math.min(distance, (os.clock() - began) * cfg.speed)
		local nextPosition = start + dir * along
		local delta = nextPosition - previous
		local wall = if delta.Magnitude > 0.0001
			then workspace:Spherecast(previous, 2, delta, params(boss, s, hooks))
			else nil
		if wall then
			nextPosition = previous + dir * math.max(0, wall.Distance - 0.25)
		end
		s.root.CFrame = CFrame.lookAt(nextPosition, nextPosition + dir)
		s.root.AssemblyLinearVelocity = Vector3.zero
		for _, f in hooks.fighters(boss) do
			if
				not hit[f.player]
				and math.abs(f.root.Position.Y - nextPosition.Y) < 6
				and distanceToSegment(f.root.Position, previous, nextPosition) <= cfg.radius
				and clearSight(f, nextPosition, ray)
			then
				hit[f.player] = true
				hooks.hurt(boss, f, cfg.damage, start)
			end
		end
		previous = nextPosition
		if wall or along >= distance then
			break
		end
		RunService.Heartbeat:Wait()
	end
end
local function spit(boss: any, s: any, cfg: any, target: Vector3, hooks: any)
	local ray = params(boss, s, hooks)
	local delta = (target - s.root.Position) * FLAT
	local at = s.root.Position
		+ (if delta.Magnitude > 0.01 then delta.Unit else s.root.CFrame.LookVector)
			* math.min(cfg.range, delta.Magnitude)
	at = ground(boss, at, ray)
	local warning = mark(s, hooks, at, cfg.radius)
	task.wait(cfg.release)
	if not alive(boss, s) then
		return
	end
	local from = (socket(boss, "upchuck", cfg.release, "head") * CFrame.new(0, 0, -2)).Position
	local ball = part(
		s.folder,
		"PiglinSpit",
		Vector3.one * 0.7,
		CFrame.new(from),
		Color3.fromRGB(123, 150, 64)
	)
	local began, previous = os.clock(), from
	while alive(boss, s) do
		local u = math.clamp((os.clock() - began) / cfg.flight, 0, 1)
		local p = from:Lerp(at, u) + Vector3.new(0, 5 * 4 * u * (1 - u), 0)
		local hit = workspace:Raycast(previous, p - previous, ray)
		if hit then
			at = hit.Position
			break
		end
		ball.Position = p
		previous = p
		if u >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	ball:Destroy()
	warning:Destroy()
	if not alive(boss, s) then
		return
	end
	-- A short puddle: each tick contributes to the shared boss burst limit, walls block splash.
	local pool = part(
		s.folder,
		"PiglinPuddle",
		Vector3.new(0.1, cfg.radius * 2, cfg.radius * 2),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(102, 123, 54)
	)
	pool.Shape, pool.Transparency = Enum.PartType.Cylinder, 0.4
	for _ = 1, cfg.ticks do
		if not alive(boss, s) then
			return
		end
		area(boss, s, hooks, at, cfg.radius, cfg.damage / cfg.ticks)
		task.wait(cfg.tickInterval)
	end
	pool:Destroy()
end

local function guard(boss: any, s: any, at: Vector3, cfg: any, hooks: any)
	local e = s.encounter
	local model = Instance.new("Model")
	model.Name = "PiglinGuard"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "HumanoidRootPart", Vector3.new(1.8, 2.2, 1.5), 1
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, 1.8, 0)), model
	BlockRig.build(
		require(Shared.Models.piglin_guard),
		model,
		root,
		root.CFrame * CFrame.new(0, -1.8, 0),
		boss.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, cfg.speed, 0.7
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart = root
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("MobId", "piglin_guard")
	model:SetAttribute("BaseWalkSpeed", cfg.speed)
	CollisionGroups.mob(model)
	model.Parent = e.folder
	CollectionService:AddTag(model, "Mob")
	root:SetNetworkOwner(nil)
	table.insert(e.guards, model)
	Debris:AddItem(model, cfg.lifetime + 2.1)
	task.spawn(function()
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
			if away.Magnitude > boss.arenaRadius - 4 then
				goal = boss.spawn.Position + away.Unit * (boss.arenaRadius - 4)
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
					and clearSight(nearest, root.Position, params(boss, s, hooks))
				then
					hooks.hurt(boss, nearest, cfg.damage, root.Position)
				end
			end
			task.wait(0.15)
		end
		if model.Parent then
			if h.Health > 0 then
				h.Health = 0
			end
			h.WalkSpeed = 0
			root.Anchored = true
			task.delay(2, function()
				if model.Parent then
					model:Destroy()
				end
			end)
		end
	end)
end
local function summon(boss: any, s: any, cfg: any, phase2: boolean, hooks: any)
	local ray = params(boss, s, hooks)
	local marks, points = {}, {}
	local count = if phase2 then cfg.phase2Count else cfg.count
	for i = 1, count do
		local angle = i * 2 * math.pi / count
		local p = s.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 6
		if
			((p - boss.spawn.Position) * FLAT).Magnitude < boss.arenaRadius - 3
			and not workspace:Raycast(s.root.Position, p - s.root.Position, ray)
		then
			p = ground(boss, p, ray)
			table.insert(points, p)
			table.insert(marks, mark(s, hooks, p, 1.5))
		end
	end
	task.wait(cfg.release)
	for _, m in marks do
		m:Destroy()
	end
	if not alive(boss, s) then
		return
	end
	local survivors = {}
	for _, m in s.encounter.guards do
		local h = m:FindFirstChildOfClass("Humanoid")
		if m.Parent and h and h.Health > 0 then
			table.insert(survivors, m)
		end
	end
	s.encounter.guards = survivors
	for _, p in points do
		if #s.encounter.guards >= cfg.maxAlive then
			break
		end
		guard(boss, s, p, cfg, hooks)
	end
end
local function heal(boss: any, s: any, cfg: any, hooks: any)
	local initial = boss.humanoid.Health
	local started = os.clock()
	local food = part(
		s.folder,
		"PiglinGoldenFood",
		Vector3.new(0.6, 0.65, 0.55),
		CFrame.new(s.root.Position),
		GOLD
	)
	while alive(boss, s) do
		local t = os.clock() - started
		food.CFrame = socket(boss, "healing", t, "handR") * CFrame.new(0, 0, -0.35)
		if initial - boss.humanoid.Health >= boss.humanoid.MaxHealth * cfg.interruptFraction then
			food:Destroy()
			boss.busyUntil = os.clock() + 1.5
			hooks.act(boss, "hurt", 1.5)
			task.delay(1.5, function()
				finish(boss, s)
			end)
			return
		end
		if t >= cfg.release then
			break
		end
		RunService.Heartbeat:Wait()
	end
	food:Destroy()
	if alive(boss, s) then
		boss.humanoid.Health = math.min(
			boss.humanoid.MaxHealth,
			boss.humanoid.Health + boss.humanoid.MaxHealth * cfg.fraction
		)
	end
end
function PiglinAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	phase2: boolean,
	hooks: any
)
	local name = NAMES[index]
	local cfg = boss.fight.piglin[name]
	local s = begin(boss, name, cfg, target, hooks)
	task.spawn(function()
		if name == "charge" then
			charge(boss, s, cfg, hooks)
		elseif name == "upchuck" then
			spit(boss, s, cfg, target, hooks)
		elseif name == "summoningchant" then
			summon(boss, s, cfg, phase2, hooks)
		elseif name == "healing" then
			heal(boss, s, cfg, hooks)
		elseif name == "spinslam" then
			local at = ground(boss, s.root.Position, params(boss, s, hooks))
			local warning = mark(s, hooks, at, cfg.radius)
			task.wait(cfg.sweepAt)
			if not alive(boss, s) then
				return
			end
			area(boss, s, hooks, at, cfg.radius, cfg.sweepDamage)
			task.wait(cfg.release - cfg.sweepAt)
			warning:Destroy()
			if alive(boss, s) then
				area(boss, s, hooks, at, cfg.radius, cfg.damage)
				pulse(s, at, cfg.radius)
			end
		else
			impact(boss, s, cfg, hooks)
		end
	end)
end
function PiglinAbilities.Melee(boss: any, target: Vector3, hooks: any)
	local e = encounters[boss]
	local name = if e and e.lastMelee == "verticalatk" then "horizontalatk" else "verticalatk"
	local cfg = boss.fight.piglin[name]
	local s = begin(boss, name, cfg, target, hooks)
	s.encounter.lastMelee = name
	task.spawn(impact, boss, s, cfg, hooks)
end
function PiglinAbilities.Spawn(boss: any, hooks: any)
	begin(
		boss,
		"spawn",
		{ duration = boss.fight.piglin.spawnDuration, release = 0 },
		boss.root.Position + boss.root.CFrame.LookVector,
		hooks
	)
end
return PiglinAbilities
