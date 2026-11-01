--!strict
-- Audited action names; original, cancellable mechanics. No clones, blocks or invulnerability.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Shared = ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local Definition = require(Shared.Models.illusionist) :: any
local Prepared = BlockRig.prepare(Definition)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local RED, CREAM = Color3.fromRGB(131, 53, 62), Color3.fromRGB(204, 195, 173)
local NAMES =
	{ "attackdagger", "attackcards", "attackbox", "summonrabbits", "phasecards", "regeneration" }
local function living(b: any, e: any): boolean
	return encounters[b] == e
		and b.root == e.root
		and e.root:IsDescendantOf(workspace)
		and b.humanoid.Health > 0
end
function API.Clear(b: any)
	Cast.Clear(b)
	local e = encounters[b]
	encounters[b] = nil
	if e then
		e.folder:Destroy()
	end
end
local function encounter(b: any): any
	local e = encounters[b]
	if not e or not living(b, e) then
		API.Clear(b)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "IllusionistEncounter", workspace
		e = { root = b.root, folder = folder, rabbits = {} }
		encounters[b] = e
	end
	return e
end
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Parent = Enum.Material.SmoothPlastic, parent
	return p
end
local function socket(b: any, clip: string, time: number, name: string): Vector3
	local joint = b.model:FindFirstChild("J_root")
	local motor = joint and joint:FindFirstChild("root")
	local origin = b.root.CFrame
		* (if motor and motor:IsA("Motor6D") then motor.C0 else CFrame.new(0, -4.5, 0))
	local worlds, pivots = {}, {}
	for _, j in Definition.joints do
		local pivot = Vector3.new(j.pivot[1], j.pivot[2], j.pivot[3])
		pivots[j.name] = pivot
		worlds[j.name] = (if j.parent then worlds[j.parent] else origin)
			* CFrame.new(if j.parent then pivot - pivots[j.parent] else pivot)
			* BlockRig.sample(Prepared.clips[clip], j.name, time)
		if j.name == name then
			return worlds[j.name].Position
		end
	end
	return origin.Position
end
local function overlap(at: Vector3, size: Vector3, ray: RaycastParams): boolean
	local p = OverlapParams.new()
	p.FilterType, p.FilterDescendantsInstances, p.RespectCanCollide =
		ray.FilterType, ray.FilterDescendantsInstances, true
	return #workspace:GetPartBoundsInBox(CFrame.new(at), size, p) > 0
end
local function safePoint(
	b: any,
	e: any,
	hooks: any,
	target: Vector3,
	range: number,
	margin: number
): Vector3?
	local ray = Cast.Params(b, e, hooks)
	local delta = (target - b.root.Position) * FLAT
	if
		delta.Magnitude > range
		or ((target - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - margin
	then
		return nil
	end
	local ground = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), ray)
	if not ground or ground.Normal.Y < 0.55 then
		return nil
	end
	local at = ground.Position + Vector3.new(0, 0.08, 0)
	local from = Cast.FloorAt(b, b.root.Position, ray) + Vector3.new(0, 0.6, 0)
	if
		math.abs(at.Y - from.Y) > 5
		or workspace:Raycast(b.root.Position, target - b.root.Position, ray)
		or workspace:Raycast(from, at + Vector3.new(0, 0.6, 0) - from, ray)
		or overlap(at + Vector3.new(0, 1.5, 0), Vector3.new(1.5, 2.5, 1.5), ray)
	then
		return nil
	end
	return at
end
local function hit(
	b: any,
	e: any,
	hooks: any,
	f: any,
	damage: number,
	from: Vector3,
	seen: any
): boolean
	if
		not living(b, e)
		or seen[f.humanoid]
		or not f.root.Parent
		or f.humanoid.Health <= 0
		or workspace:Raycast(from, f.root.Position - from, Cast.Params(b, e, hooks))
	then
		return false
	end
	if hooks.hurt(b, f, damage, from, 0.55, 0.1) ~= false then
		seen[f.humanoid] = true
		return true
	end
	return false
end
local function radial(b: any, e: any, hooks: any, at: Vector3, cfg: any)
	local seen = {}
	for _, f in hooks.fighters(b) do
		if
			((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
			and math.abs(f.root.Position.Y - at.Y) < 6
		then
			hit(b, e, hooks, f, cfg.damage, at + Vector3.new(0, 1.5, 0), seen)
		end
	end
end
local function projectile(
	b: any,
	e: any,
	hooks: any,
	origin: Vector3,
	direction: Vector3,
	cfg: any,
	card: boolean,
	seen: any
)
	local ray = Cast.Params(b, e, hooks)
	if
		not living(b, e)
		or workspace:Raycast(b.root.Position, origin - b.root.Position, ray)
		or overlap(origin, Vector3.one * 0.4, ray)
	then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "IllusionistProjectile", e.folder
	local blade = part(
		folder,
		if card then "Card" else "Dagger",
		if card then Vector3.new(0.7, 0.08, 1) else Vector3.new(0.22, 0.18, 1.5),
		CFrame.new(origin),
		CREAM
	)
	local inset = part(
		folder,
		"Accent",
		if card then Vector3.new(0.48, 0.09, 0.74) else Vector3.new(0.5, 0.2, 0.12),
		CFrame.new(origin),
		RED
	)
	local began, previous = os.clock(), origin
	while living(b, e) and folder.Parent do
		local elapsed = os.clock() - began
		local distance = math.min(cfg.range, elapsed * cfg.speed)
		local point = origin + direction * distance
		local step = point - previous
		local wall = if step.Magnitude > 0.001
			then workspace:Spherecast(previous, 0.22, step, ray)
			else nil
		local wallDistance = if wall then wall.Distance else step.Magnitude
		local chosen, nearest = nil, math.huge
		for _, f in hooks.fighters(b) do
			local u = if step.Magnitude > 0.001
				then math.clamp((f.root.Position - previous):Dot(step) / step:Dot(step), 0, 1)
				else 0
			local closest = previous + step * u
			local offset = f.root.Position - closest
			local along = step.Magnitude * u
			if
				not seen[f.humanoid]
				and f.humanoid.Health > 0
				and f.root.Parent
				and (offset * FLAT).Magnitude <= cfg.radius
				and math.abs(offset.Y) <= 2.6
				and along <= wallDistance
				and along < nearest
			then
				chosen, nearest = f, along
			end
		end
		if chosen and hit(b, e, hooks, chosen, cfg.damage, previous, seen) then
			break
		end
		if
			wall
			or overlap(point, Vector3.one * 0.4, ray)
			or ((point - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - 1
		then
			break
		end
		local cf = CFrame.lookAt(point, point + direction)
			* CFrame.Angles(0, 0, if card then elapsed * 15 else 0)
		blade.CFrame, inset.CFrame = cf, cf * CFrame.new(0, 0.05, if card then 0 else 0.48)
		if distance >= cfg.range then
			break
		end
		previous = point
		RunService.Heartbeat:Wait()
	end
	folder:Destroy()
end
local function rabbit(b: any, e: any, hooks: any, at: Vector3, cfg: any)
	local model = Instance.new("Model")
	model.Name = "IllusionistRabbit"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.new(1.2, 1.2, 1.5), 1, true
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, 0.9, 0)), model
	BlockRig.build(
		require(Shared.Models.illusionist_rabbit),
		model,
		root,
		root.CFrame * CFrame.new(0, -0.9, 0),
		b.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, cfg.speed, 0.3
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart, model.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	model:SetAttribute("MobId", "illusionist_rabbit")
	CollisionGroups.mob(model)
	model.Parent = e.folder
	CollectionService:AddTag(model, "Mob")
	Physics.restore(root, false)
	table.insert(e.rabbits, model)
	Debris:AddItem(model, cfg.lifetime + cfg.explosionDuration + 1)
	local stopped = false
	local function die()
		if stopped or not model.Parent then
			return
		end
		stopped = true
		h.WalkSpeed, root.Anchored = 0, true
		if h.Health > 0 then
			h.Health = 0
		end
		Debris:AddItem(model, 3.5)
	end
	h.Died:Once(die)
	task.spawn(function()
		local expires = os.clock() + cfg.lifetime
		while
			living(b, e)
			and model.Parent
			and root:IsDescendantOf(workspace)
			and h.Health > 0
			and os.clock() < expires
		do
			local nearest, distance = nil, math.huge
			for _, f in hooks.fighters(b) do
				local d = (f.root.Position - root.Position).Magnitude
				if f.humanoid.Health > 0 and d < distance then
					nearest, distance = f, d
				end
			end
			if
				not nearest
				or ((root.Position - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius
			then
				break
			end
			if
				distance <= cfg.triggerRadius
				and not workspace:Raycast(
					root.Position,
					nearest.root.Position - root.Position,
					Cast.Params(b, e, hooks)
				)
			then
				h.WalkSpeed, root.Anchored = 0, true
				model:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				local floor = Cast.FloorAt(b, root.Position, Cast.Params(b, e, hooks))
				local warning = Cast.Mark(b, e, hooks, floor, cfg.radius, RED)
				local release = os.clock() + cfg.fuse
				while living(b, e) and model.Parent and h.Health > 0 and os.clock() < release do
					RunService.Heartbeat:Wait()
				end
				warning:Destroy()
				if living(b, e) and model.Parent and h.Health > 0 then
					radial(b, e, hooks, floor, cfg)
					Cast.Pulse(e, floor, cfg.radius, RED)
				end
				break
			end
			h:MoveTo(nearest.root.Position)
			task.wait(0.15)
		end
		die()
	end)
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local duration = b.fight.illusionist.spawnDuration
	local s = Cast.Begin(b, "active", duration, 0, nil, hooks)
	task.delay(duration, function()
		Cast.Finish(b, s)
	end)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	encounter(b)
	b.illusionistMelee = (b.illusionistMelee or 0) % #b.fight.illusionist.melee + 1
	local cfg = b.fight.illusionist.melee[b.illusionistMelee]
	local s = Cast.Begin(b, cfg.name, cfg.duration, cfg.release, target, hooks)
	task.spawn(function()
		local start = os.clock()
		if Cast.WaitUntil(b, s, start, cfg.release) then
			Cast.Hit(b, s, hooks, s.root.Position, cfg, cfg.damage)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
function API.Cast(b: any, index: number, target: Vector3, phase2: boolean, hooks: any)
	local e = encounter(b)
	local name = NAMES[(index - 1) % #NAMES + 1]
	local cfg = b.fight.illusionist[name]
	local s =
		Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.illusionist.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "attackdagger" or name == "attackcards" then
			local card = name == "attackcards"
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local from = socket(b, name, cfg.release, if card then "handL" else "handR")
				local delta = target - from
				local direction = if delta.Magnitude > 0.01
					then delta.Unit
					else b.root.CFrame.LookVector
				local count = if card then (if phase2 then cfg.phase2Count else cfg.count) else 1
				local seen = {}
				for i = 1, count do
					local angle = if card
						then math.rad((i - (count + 1) / 2) * cfg.spreadDegrees)
						else 0
					local d = CFrame.Angles(0, angle, 0):VectorToWorldSpace(direction)
					task.spawn(projectile, b, e, hooks, from, d, cfg, card, seen)
				end
			end
		elseif name == "attackbox" then
			local at = safePoint(b, e, hooks, target, cfg.range, cfg.radius)
			if at then
				local warning = Cast.Mark(b, s, hooks, at, cfg.radius, RED)
				if
					Cast.WaitUntil(b, s, start, cfg.release)
					and safePoint(b, e, hooks, target, cfg.range, cfg.radius)
				then
					warning:Destroy()
					radial(b, e, hooks, at, cfg)
					for i = 0, 3 do
						local rotation = CFrame.Angles(0, i * math.pi / 2, 0)
						local cf = CFrame.new(at)
							* rotation
							* CFrame.new(0, 0.8, -cfg.radius * 0.65)
						local panel = part(
							e.folder,
							"MagicBoxPanel",
							Vector3.new(cfg.radius * 1.4, 1.6, 0.16),
							cf,
							RED
						)
						TweenService:Create(
							panel,
							TweenInfo.new(0.55),
							{ CFrame = cf * CFrame.Angles(-1.2, 0, 0), Transparency = 1 }
						):Play()
						Debris:AddItem(panel, 0.6)
					end
				end
			end
		elseif name == "summonrabbits" then
			local points = {}
			local count = if phase2 then cfg.phase2Count else cfg.count
			for i = 1, count do
				local angle = i * math.pi * 2 / count
				local at = safePoint(
					b,
					e,
					hooks,
					b.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.range,
					cfg.range + 0.1,
					3
				)
				if at then
					table.insert(points, at)
					Cast.Mark(b, s, hooks, at, 1, CREAM)
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local survivors = {}
				for _, model in e.rabbits do
					local h = model:FindFirstChildOfClass("Humanoid")
					if model.Parent and h and h.Health > 0 then
						table.insert(survivors, model)
					end
				end
				e.rabbits = survivors
				for _, at in points do
					if #e.rabbits >= cfg.maxAlive then
						break
					end
					if safePoint(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range + 0.1, 3) then
						rabbit(b, e, hooks, at, cfg)
					end
				end
			end
		elseif name == "phasecards" then
			local side = b.root.CFrame.RightVector * (if phase2 then -1 else 1)
			local goal =
				Cast.Destination(b, s, hooks, b.root.Position + side * cfg.range, cfg.range)
			if not safePoint(b, e, hooks, goal, cfg.range + 0.1, 3) then
				goal = b.root.Position
			end
			Cast.Mark(b, s, hooks, goal, 2, CREAM)
			if
				Cast.WaitUntil(b, s, start, cfg.release)
				and safePoint(b, e, hooks, goal, cfg.range + 0.1, 3)
			then
				Cast.Pulse(e, Cast.FloorAt(b, b.root.Position, Cast.Params(b, e, hooks)), 2, CREAM)
				Cast.Travel(b, s, hooks, goal, start, cfg.release, cfg.moveEnd)
			end
		else
			local damage, previous = 0, b.humanoid.Health
			local connection = b.humanoid.HealthChanged:Connect(function(health: number)
				damage += math.max(0, previous - health)
				previous = health
			end)
			s.folder.Destroying:Once(function()
				connection:Disconnect()
			end)
			local healed = 0
			while Cast.Alive(b, s) and os.clock() < start + cfg.duration do
				if damage >= cfg.interruptDamage then
					hooks.act(b, "hurt", 0.5)
					b.busyUntil = os.clock() + 0.5
					break
				end
				if #hooks.fighters(b) == 0 then
					break
				end
				if
					healed < cfg.ticks
					and os.clock() >= start + cfg.release + healed * cfg.interval
				then
					b.humanoid.Health = math.min(
						b.humanoid.MaxHealth,
						b.humanoid.Health + b.humanoid.MaxHealth * cfg.healFraction
					)
					previous = b.humanoid.Health
					healed += 1
					Cast.Pulse(
						e,
						Cast.FloorAt(b, b.root.Position, Cast.Params(b, e, hooks)),
						2,
						CREAM
					)
				end
				RunService.Heartbeat:Wait()
			end
			connection:Disconnect()
			Cast.Finish(b, s)
			return
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
