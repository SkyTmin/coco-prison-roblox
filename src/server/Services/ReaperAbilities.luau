--!strict
-- Reaper: original scythe encounter, bounded soul bolts and vulnerable casts. Studio QA pending.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Physics = require(script.Parent.BossPhysics)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local COLOR = Color3.fromRGB(115, 155, 137)
local NAMES = { "soul1", "circleattack", "groundattack", "teleport", "explosion" }
local function living(b: any, e: any): boolean
	return encounters[b] == e
		and b.root == e.root
		and e.root:IsDescendantOf(workspace)
		and b.humanoid.Health > 0
end
function API.Clear(b: any)
	local e = encounters[b]
	encounters[b] = nil
	if e then
		e.folder:Destroy()
	end
	Cast.Clear(b)
end
local function encounter(b: any): any
	local e = encounters[b]
	if not e or not living(b, e) then
		API.Clear(b)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "ReaperEncounter", workspace
		e = { root = b.root, folder = folder, projectiles = 0, combo = 0 }
		encounters[b] = e
	end
	return e
end
local function mark(b: any, s: any, hooks: any, at: Vector3, radius: number): BasePart
	local warning = Cast.Mark(b, s, hooks, at, radius, COLOR)
	warning.Material = Enum.Material.SmoothPlastic
	return warning
end
local function occupied(at: Vector3, size: Vector3, ray: RaycastParams): boolean
	local p = OverlapParams.new()
	p.FilterType, p.FilterDescendantsInstances, p.RespectCanCollide =
		ray.FilterType, ray.FilterDescendantsInstances, true
	return #workspace:GetPartBoundsInBox(CFrame.new(at), size, p) > 0
end
local function ground(
	b: any,
	e: any,
	hooks: any,
	target: Vector3,
	range: number,
	margin: number,
	persistent: boolean?
): Vector3?
	if ((target - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - margin then
		return nil
	end
	if not persistent and ((target - b.root.Position) * FLAT).Magnitude > range then
		return nil
	end
	local ray = Cast.Params(b, e, hooks)
	local hit = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), ray)
	local base =
		workspace:Raycast(b.root.Position + Vector3.new(0, 4, 0), Vector3.new(0, -24, 0), ray)
	if
		not hit
		or not base
		or hit.Normal.Y < 0.55
		or math.abs(hit.Position.Y - base.Position.Y) > 3
	then
		return nil
	end
	local at = hit.Position + Vector3.new(0, 0.08, 0)
	if
		not persistent
		and (
			workspace:Raycast(b.root.Position, target - b.root.Position, ray)
			or workspace:Raycast(base.Position + Vector3.new(0, 0.6, 0), at - base.Position, ray)
		)
	then
		return nil
	end
	if occupied(at + Vector3.new(0, 1.1, 0), Vector3.new(1.2, 1.9, 1.2), ray) then
		return nil
	end
	return at
end
local function supported(b: any, e: any, hooks: any, at: Vector3, margin: number): boolean
	local current = ground(b, e, hooks, at + Vector3.new(0, 2, 0), 1, margin, true)
	return current ~= nil and math.abs(current.Y - at.Y) <= 0.3
end
local function hit(
	b: any,
	e: any,
	hooks: any,
	f: any,
	amount: number,
	at: Vector3,
	seen: any
): boolean
	if
		not living(b, e)
		or seen[f.humanoid]
		or not f.root.Parent
		or f.humanoid.Health <= 0
		or workspace:Raycast(at, f.root.Position - at, Cast.Params(b, e, hooks))
	then
		return false
	end
	if hooks.hurt(b, f, amount, at, 0.25, 0) == false then
		return false
	end
	seen[f.humanoid] = true
	return true
end
local function impact(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if not living(b, e) then
		return
	end
	Cast.Pulse(e, at, cfg.radius, COLOR)
	for _, f in hooks.fighters(b) do
		if
			((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
			and math.abs(f.root.Position.Y - at.Y) < 6
		then
			hit(b, e, hooks, f, cfg.damage, at + Vector3.new(0, 1, 0), seen)
		end
	end
end
local function prop(
	b: any,
	parent: Instance,
	id: string,
	at: CFrame,
	clip: string,
	duration: number
): (Model, BasePart)
	local m, root = Instance.new("Model"), Instance.new("Part")
	m.Name, m.ModelStreamingMode = id, Enum.ModelStreamingMode.Atomic
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.one, 1, true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.CFrame, root.Parent = at, m
	BlockRig.build(require(Shared.Models[id]), m, root, at, b.fight.texture)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanQuery = false
		end
	end
	m.PrimaryPart = root
	m:SetAttribute("BlockModel", id)
	m:SetAttribute("Action", clip)
	m:SetAttribute("ActionAt", workspace:GetServerTimeNow())
	m:SetAttribute("ActionLen", duration)
	m.Parent = parent
	CollectionService:AddTag(m, "BossProp")
	Debris:AddItem(m, duration)
	return m, root
end
local function projectile(
	b: any,
	e: any,
	s: any,
	hooks: any,
	from: Vector3,
	direction: Vector3,
	cfg: any,
	amount: number
)
	local ray = Cast.Params(b, e, hooks)
	if
		not living(b, e)
		or s.interrupted
		or e.projectiles >= 16
		or direction.Magnitude < 0.01
		or workspace:Raycast(b.root.Position, from - b.root.Position, ray)
		or occupied(from, Vector3.one, ray)
	then
		return
	end
	local dir = direction.Unit
	e.projectiles += 1
	local m, root = prop(
		b,
		e.folder,
		"reaper_soul",
		CFrame.lookAt(from, from + dir),
		"flight",
		cfg.range / cfg.speed + 1
	)
	local start, previous = os.clock(), from
	while living(b, e) and not s.interrupted and m.Parent do
		local distance = math.min(cfg.range, (os.clock() - start) * cfg.speed)
		local point = from + dir * distance
		local step = point - previous
		local wall = if step.Magnitude > 0.001
			then workspace:Spherecast(previous, 0.5, step, ray)
			else nil
		local chosen, nearest = nil, math.huge
		for _, f in hooks.fighters(b) do
			local u = if step.Magnitude > 0.001
				then math.clamp((f.root.Position - previous):Dot(step) / step:Dot(step), 0, 1)
				else 0
			local along = step.Magnitude * u
			if
				f.root.Parent
				and f.humanoid.Health > 0
				and (f.root.Position - previous - step * u).Magnitude <= cfg.radius + 1
				and along < nearest
				and (not wall or along <= wall.Distance)
			then
				chosen, nearest = f, along
			end
		end
		if chosen and hit(b, e, hooks, chosen, amount, previous, {}) then
			break
		end
		if
			wall
			or occupied(point, Vector3.one, ray)
			or ((point - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - 1
		then
			break
		end
		root.CFrame = CFrame.lookAt(point, point + dir)
		if distance >= cfg.range then
			break
		end
		previous = point
		RunService.Heartbeat:Wait()
	end
	m:Destroy()
	e.projectiles = math.max(0, e.projectiles - 1)
end
local function souls(b: any, e: any, s: any, hooks: any, start: number, cfg: any, phase2: boolean)
	local initial = b.humanoid.Health
	task.spawn(function()
		while Cast.Alive(b, s) do
			if initial - b.humanoid.Health >= cfg.interruptDamage then
				s.interrupted = true
				Cast.Clear(b)
				local stagger = Cast.Begin(b, "stun", 1, 0, nil, hooks, b.fight.reaper.recovery)
				task.delay(1, function()
					Cast.Finish(b, stagger)
				end)
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	local at = ground(b, e, hooks, b.root.Position, 1, 1)
	if at then
		prop(b, s.folder, "reaper_circle", CFrame.new(at), "idle", cfg.duration)
	end
	local count = if phase2 then cfg.phase2Count else cfg.count
	for i = 1, count do
		if not Cast.WaitUntil(b, s, start, cfg.release + (i - 1) * cfg.interval) then
			break
		end
		local targets = hooks.fighters(b)
		table.sort(targets, function(a, c)
			return a.player.UserId < c.player.UserId
		end)
		if #targets == 0 then
			break
		end
		local chosen = targets[(i - 1) % #targets + 1]
		if chosen.root.Parent and chosen.humanoid.Health > 0 then
			local from = b.root.Position + b.root.CFrame.LookVector * 2 + Vector3.new(0, 1.5, 0)
			task.spawn(
				projectile,
				b,
				e,
				s,
				hooks,
				from,
				chosen.root.Position - from,
				cfg,
				cfg.damage / count
			)
		end
	end
end
local function circle(b: any, e: any, s: any, hooks: any, start: number, cfg: any)
	local at = ground(b, e, hooks, b.root.Position, 1, 1)
	if not at then
		return
	end
	mark(b, s, hooks, at, cfg.radius)
	if Cast.WaitUntil(b, s, start, cfg.release) and supported(b, e, hooks, at, 1) then
		Cast.Pulse(s, at, cfg.radius, COLOR)
		Cast.Hit(b, s, hooks, b.root.Position, cfg, cfg.damage, true)
	end
end
local function groundSlash(b: any, e: any, s: any, hooks: any, start: number, cfg: any)
	local origin = ground(b, e, hooks, b.root.Position, 1, 1)
	if not origin then
		return
	end
	local points = {}
	for distance = cfg.spacing, cfg.range, cfg.spacing do
		local at = ground(
			b,
			e,
			hooks,
			b.root.Position + b.root.CFrame.LookVector * distance,
			cfg.range + 1,
			cfg.radius
		)
		if not at then
			break
		end
		mark(b, s, hooks, at, cfg.radius)
		table.insert(points, at)
	end
	local seen = {}
	for i, at in points do
		if
			not Cast.WaitUntil(b, s, start, cfg.release + (i - 1) * cfg.interval)
			or not supported(b, e, hooks, origin, 1)
			or not ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range + 1, cfg.radius)
		then
			break
		end
		impact(b, e, hooks, at, cfg, seen)
	end
end
local function teleport(
	b: any,
	e: any,
	s: any,
	hooks: any,
	target: Vector3,
	start: number,
	cfg: any
)
	hooks.act(b, "teleportinto", cfg.intoDuration)
	local from = b.root.Position
	local oldFloor = ground(b, e, hooks, from, 1, 1)
	if not oldFloor then
		return
	end
	local goal, landing = nil, nil
	local ray = Cast.Params(b, e, hooks)
	for _, side in { 1, -1 } do
		local desired = target + b.root.CFrame.RightVector * cfg.flank * side
		local candidate = Cast.Destination(b, s, hooks, desired, cfg.range)
		local at = ground(b, e, hooks, candidate, cfg.range + 1, 3)
		local nearPlayer = false
		for _, f in hooks.fighters(b) do
			if ((f.root.Position - candidate) * FLAT).Magnitude < 4 then
				nearPlayer = true
			end
		end
		if
			at
			and not nearPlayer
			and (candidate - from).Magnitude > 3
			and not occupied(at + Vector3.new(0, 4.9, 0), Vector3.new(4, 9.6, 3.5), ray)
		then
			goal, landing = Vector3.new(candidate.X, at.Y + from.Y - oldFloor.Y, candidate.Z), at
			break
		end
	end
	if landing then
		mark(b, s, hooks, landing, 3)
		prop(b, s.folder, "reaper_circle", CFrame.new(landing), "idle", cfg.duration)
	end
	if not Cast.WaitUntil(b, s, start, cfg.intoDuration) then
		return
	end
	if
		goal
		and landing
		and supported(b, e, hooks, oldFloor, 1)
		and ground(b, e, hooks, landing + Vector3.new(0, 2, 0), cfg.range + 1, 3)
		and not occupied(landing + Vector3.new(0, 4.9, 0), Vector3.new(4, 9.6, 3.5), ray)
	then
		local close = false
		for _, f in hooks.fighters(b) do
			if ((f.root.Position - goal) * FLAT).Magnitude < 4 then
				close = true
			end
		end
		if not close then
			b.root.CFrame = CFrame.new(goal) * b.root.CFrame.Rotation
			b.root.AssemblyLinearVelocity, b.root.AssemblyAngularVelocity =
				Vector3.zero, Vector3.zero
			Physics.face(b.root, target)
		end
	end
	hooks.act(b, "teleportout", cfg.outDuration)
end
local function explosion(b: any, e: any, s: any, hooks: any, start: number, cfg: any)
	local at = ground(b, e, hooks, b.root.Position, 1, 1)
	if not at then
		return
	end
	local safe = -b.root.CFrame.RightVector * FLAT
	local limit = math.cos(math.rad(cfg.safeHalfAngle))
	for i = 0, 11 do
		local angle = i * math.pi / 6
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if dir:Dot(safe) < limit then
			local point = ground(
				b,
				e,
				hooks,
				at + dir * (cfg.radius * 0.62) + Vector3.new(0, 2, 0),
				cfg.radius,
				2
			)
			if point then
				mark(b, s, hooks, point, 2.4)
			end
		end
	end
	if not Cast.WaitUntil(b, s, start, cfg.release) or not supported(b, e, hooks, at, 1) then
		return
	end
	local seen = {}
	Cast.Pulse(s, at, cfg.radius, COLOR)
	for _, f in hooks.fighters(b) do
		local delta = (f.root.Position - at) * FLAT
		local floor = ground(b, e, hooks, f.root.Position, cfg.radius, 1, true)
		if
			delta.Magnitude >= cfg.innerRadius
			and delta.Magnitude <= cfg.radius
			and delta.Unit:Dot(safe) < limit
			and floor
			and math.abs(floor.Y - at.Y) < 0.3
			and f.root.Position.Y - floor.Y < cfg.jumpHeight
		then
			hit(b, e, hooks, f, cfg.damage, at + Vector3.new(0, 1.5, 0), seen)
		end
	end
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local duration = b.fight.reaper.spawnDuration
	local s = Cast.Begin(b, "spawn", duration, 0, nil, hooks)
	task.spawn(Cast.EndAfter, b, s, os.clock(), duration)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	local e = encounter(b)
	e.combo = e.combo % 2 + 1
	local name = if e.combo == 1 then "attack1" else "attack2"
	local cfg = b.fight.reaper[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks)
	task.spawn(function()
		local start = os.clock()
		if Cast.WaitUntil(b, s, start, cfg.release) then
			Cast.Hit(b, s, hooks, b.root.Position, cfg, cfg.damage)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
function API.Cast(b: any, index: number, target: Vector3, phase2: boolean, hooks: any)
	local e = encounter(b)
	local name = NAMES[(index - 1) % #NAMES + 1]
	local cfg = b.fight.reaper[name]
	local s = Cast.Begin(
		b,
		if name == "teleport" then "teleportinto" else name,
		cfg.duration,
		cfg.release,
		target,
		hooks,
		b.fight.reaper.recovery
	)
	task.spawn(function()
		local start = os.clock()
		if name == "soul1" then
			souls(b, e, s, hooks, start, cfg, phase2)
		elseif name == "circleattack" then
			circle(b, e, s, hooks, start, cfg)
		elseif name == "groundattack" then
			groundSlash(b, e, s, hooks, start, cfg)
		elseif name == "teleport" then
			teleport(b, e, s, hooks, target, start, cfg)
		else
			explosion(b, e, s, hooks, start, cfg)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
