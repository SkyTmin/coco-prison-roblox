--!strict
-- Ent King attack families; original vulnerable oak encounter. Studio QA pending.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local COLOR = Color3.fromRGB(125, 137, 79)
local NAMES = { "rise", "stomp", "leafstorm", "shout" }
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
		folder.Name, folder.Parent = "EntEncounter", workspace
		e = { root = b.root, folder = folder, adds = {}, combo = 0 }
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
local function actor(b: any, e: any, id: string, at: Vector3, cfg: any): (Model, Humanoid, BasePart)
	local m, root = Instance.new("Model"), Instance.new("Part")
	m.Name, m.ModelStreamingMode = id, Enum.ModelStreamingMode.Atomic
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.new(cfg.width, cfg.lift * 2, cfg.depth), 1, true
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, cfg.lift, 0)), m
	BlockRig.build(
		require(Shared.Models[id]),
		m,
		root,
		root.CFrame * CFrame.new(0, -cfg.lift, 0),
		b.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath, h.AutoRotate = false, false, true
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 0
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, m
	m.PrimaryPart = root
	m:SetAttribute("MobId", id)
	m:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	m:SetAttribute("Shielded", false)
	CollisionGroups.mob(m)
	m.Parent = e.folder
	CollectionService:AddTag(m, "Mob")
	return m, h, root
end
local function summon(b: any, e: any, hooks: any, id: string, at: Vector3, cfg: any)
	local m, h, root = actor(b, e, id, at, cfg)
	table.insert(e.adds, m)
	Debris:AddItem(m, cfg.spawnDuration + cfg.lifetime + cfg.deathDuration + 1)
	local dead = false
	local function die()
		if dead or not m.Parent then
			return
		end
		dead = true
		root.Anchored, h.WalkSpeed = true, 0
		root.CanCollide = false
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		if h.Health > 0 then
			h.Health = 0
		end
		Debris:AddItem(m, cfg.deathDuration)
	end
	h.Died:Once(die)
	task.spawn(function()
		task.wait(cfg.spawnDuration)
		if not living(b, e) or not m.Parent or h.Health <= 0 then
			die()
			return
		end
		Physics.restore(root, false)
		h.WalkSpeed = cfg.speed
		task.delay(cfg.lifetime, die)
		local expires, nextHit = os.clock() + cfg.lifetime, 0
		while living(b, e) and m.Parent and h.Health > 0 and os.clock() < expires do
			local chosen, distance = nil, math.huge
			for _, f in hooks.fighters(b) do
				local d = (f.root.Position - root.Position).Magnitude
				if f.root.Parent and f.humanoid.Health > 0 and d < distance then
					chosen, distance = f, d
				end
			end
			if
				not chosen
				or ((root.Position - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius
				or root.Position.Y < b.spawn.Position.Y - 20
			then
				break
			end
			local now = os.clock()
			if distance > cfg.reach * 0.85 then
				h:MoveTo(chosen.root.Position)
			else
				h:MoveTo(root.Position)
			end
			if distance <= cfg.reach and now >= nextHit then
				nextHit = now + cfg.cooldown
				Physics.face(root, chosen.root.Position)
				m:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				task.wait(cfg.hitAt)
				if
					living(b, e)
					and m.Parent
					and h.Health > 0
					and chosen.root.Parent
					and chosen.humanoid.Health > 0
					and (chosen.root.Position - root.Position).Magnitude <= cfg.reach
				then
					hit(b, e, hooks, chosen, cfg.damage, root.Position, {})
				end
			end
			task.wait(0.1)
		end
		die()
	end)
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
local function branch(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if not living(b, e) or not supported(b, e, hooks, at, cfg.radius) then
		return
	end
	local ray = Cast.Params(b, e, hooks)
	if workspace:Raycast(at, Vector3.new(0, 5, 0), ray) then
		return
	end
	prop(b, e.folder, "ent_branch", CFrame.new(at), "spawn", 1.6667)
	local deadline = os.clock() + cfg.rootHitAt
	while living(b, e) and os.clock() < deadline do
		RunService.Heartbeat:Wait()
	end
	if
		living(b, e)
		and supported(b, e, hooks, at, cfg.radius)
		and not workspace:Raycast(at, Vector3.new(0, 5, 0), ray)
	then
		impact(b, e, hooks, at, cfg, seen)
	end
end
local function twisted(
	b: any,
	e: any,
	s: any,
	hooks: any,
	target: Vector3,
	start: number,
	cfg: any,
	phase2: boolean
)
	local points = {}
	local count = if phase2 then cfg.phase2Count else cfg.count
	for i = 1, count do
		local offset = b.root.CFrame.RightVector * (i - (count + 1) / 2) * cfg.spacing
		local at = ground(b, e, hooks, target + offset, cfg.range, cfg.radius)
		if at then
			mark(b, s, hooks, at, cfg.radius)
			table.insert(points, at)
		end
	end
	if not Cast.WaitUntil(b, s, start, cfg.release) then
		return
	end
	local seen = {}
	for _, at in points do
		task.spawn(branch, b, e, hooks, at, cfg, seen)
	end
end
local function branchWave(b: any, e: any, s: any, hooks: any, start: number, cfg: any)
	local from = ground(b, e, hooks, b.root.Position, 1, cfg.radius)
	if not from then
		return
	end
	local dir = b.root.CFrame.LookVector * FLAT
	local points = {}
	for distance = cfg.spacing, cfg.range, cfg.spacing do
		local at = ground(
			b,
			e,
			hooks,
			from + dir * distance + Vector3.new(0, 2, 0),
			cfg.range + 1,
			cfg.radius
		)
		if not at then
			break
		end
		local marker = mark(b, e, hooks, at, cfg.radius)
		Debris:AddItem(marker, cfg.release + distance / cfg.speed + cfg.rootHitAt + 0.2)
		table.insert(points, { at = at, distance = distance, mark = marker })
	end
	if not Cast.WaitUntil(b, s, start, cfg.release) then
		for _, point in points do
			point.mark:Destroy()
		end
		return
	end
	task.spawn(function()
		local began = os.clock()
		local seen = {}
		local ray = Cast.Params(b, e, hooks)
		for _, point in points do
			while
				living(b, e) and os.clock() < began + (point.distance - cfg.spacing) / cfg.speed
			do
				RunService.Heartbeat:Wait()
			end
			if
				not living(b, e)
				or not supported(b, e, hooks, from, 1)
				or not supported(b, e, hooks, point.at, cfg.radius)
				or workspace:Raycast(from + Vector3.new(0, 0.6, 0), point.at - from, ray)
			then
				break
			end
			task.spawn(branch, b, e, hooks, point.at, cfg, seen)
		end
	end)
end
local function storm(b: any, e: any, s: any, hooks: any, start: number, cfg: any)
	local center = ground(b, e, hooks, b.root.Position, 1, cfg.radius)
	if not center then
		return
	end
	local safe = b.root.CFrame.RightVector * FLAT
	local initial = b.humanoid.Health
	task.spawn(function()
		while Cast.Alive(b, s) do
			if initial - b.humanoid.Health >= cfg.interruptDamage then
				Cast.Clear(b)
				local stagger = Cast.Begin(b, "stun", 1, 0, nil, hooks, b.fight.ent.recovery)
				task.delay(1, function()
					Cast.Finish(b, stagger)
				end)
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	for i = 1, 8 do
		local angle = i * math.pi / 4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if dir:Dot(safe) < math.cos(math.rad(cfg.safeHalfAngle)) then
			local at = ground(
				b,
				e,
				hooks,
				center + dir * (cfg.radius * 0.62) + Vector3.new(0, 2, 0),
				cfg.radius,
				2
			)
			if at then
				mark(b, s, hooks, at, 2)
				prop(b, s.folder, "ent_leaves", CFrame.new(at), "idle", cfg.duration)
			end
		end
	end
	for pulse = 1, cfg.pulses do
		if
			not Cast.WaitUntil(b, s, start, cfg.release + (pulse - 1) * cfg.interval)
			or not supported(b, e, hooks, center, cfg.radius)
		then
			break
		end
		local seen = {}
		for _, f in hooks.fighters(b) do
			local delta = (f.root.Position - center) * FLAT
			local distance = delta.Magnitude
			local floor = ground(b, e, hooks, f.root.Position, cfg.radius, 1, true)
			if
				distance >= cfg.innerRadius
				and distance <= cfg.radius
				and delta.Unit:Dot(safe) < math.cos(math.rad(cfg.safeHalfAngle))
				and floor
				and math.abs(floor.Y - center.Y) < 0.3
				and f.root.Position.Y - floor.Y < cfg.jumpHeight
			then
				hit(b, e, hooks, f, cfg.damage / cfg.pulses, center + Vector3.new(0, 1.5, 0), seen)
			end
		end
	end
end
local function minions(b: any, e: any, s: any, hooks: any, start: number, cfg: any, phase2: boolean)
	for i = 1, if phase2 then cfg.phase2Count else cfg.count do
		if not Cast.WaitUntil(b, s, start, cfg.release + (i - 1) * cfg.stagger) then
			break
		end
		local alive = {}
		for _, m in e.adds do
			local h = m:FindFirstChildOfClass("Humanoid")
			if m.Parent and h and h.Health > 0 then
				table.insert(alive, m)
			end
		end
		e.adds = alive
		if #alive >= cfg.maxAlive then
			break
		end
		local angle = (i - 1) * math.pi * 2 / 3
		local point = ground(
			b,
			e,
			hooks,
			b.root.Position + Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7),
			9,
			3
		)
		local c = cfg.minion
		if
			point
			and not occupied(
				point + Vector3.new(0, c.lift + 0.1, 0),
				Vector3.new(c.width + 0.2, c.lift * 2, c.depth + 0.2),
				Cast.Params(b, e, hooks)
			)
		then
			summon(b, e, hooks, "ent_minion", point, c)
		end
	end
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local duration = b.fight.ent.spawnDuration
	local s = Cast.Begin(b, "spawn", duration, 0, nil, hooks)
	task.spawn(Cast.EndAfter, b, s, os.clock(), duration)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	local e = encounter(b)
	e.combo = e.combo % 2 + 1
	local name = if e.combo == 1 then "rightpunch" else "leftpunch"
	local cfg = b.fight.ent[name]
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
	local cfg = b.fight.ent[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.ent.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "rise" then
			twisted(b, e, s, hooks, target, start, cfg, phase2)
		elseif name == "stomp" then
			branchWave(b, e, s, hooks, start, cfg)
		elseif name == "leafstorm" then
			storm(b, e, s, hooks, start, cfg)
		else
			minions(b, e, s, hooks, start, cfg, phase2)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
