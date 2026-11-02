--!strict
-- Original three-phase Samurai / spirit encounter; source families, authored rules. Studio QA pending.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
-- Split the four nocked-arrow boxes BEFORE parenting the spirit into the world.
-- Reload/release only creates/destroys this tiny external prop, never edits the full rig.
local spiritDef = table.clone(require(Shared.Models.lover_spirit))
local nockDef = table.clone(spiritDef)
spiritDef.parts, nockDef.parts = {}, {}
local nockPivot = Vector3.zero
for _, joint in nockDef.joints do
	if joint.name == "arrow" then
		nockPivot = Vector3.new(table.unpack(joint.pivot))
	end
end
nockDef.joints =
	{ { name = "arrow", parent = nil, pivot = { nockPivot.X, nockPivot.Y, nockPivot.Z } } }
for _, raw in require(Shared.Models.lover_spirit).parts do
	local name = raw.joint
		or (if typeof(raw[1]) == "number" then spiritDef.jointNames[raw[1] + 1] else raw[1])
	table.insert(if name == "arrow" then nockDef.parts else spiritDef.parts, raw)
end
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local COLOR = Color3.fromRGB(178, 96, 83)
local SPECIALS = {
	"triplecut",
	"sweep",
	"thrust",
	"dashcut",
	"skycut",
	"stars",
	"sickle",
	"spears",
	"arrowcall",
}
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
		if e.spirit and e.spirit.die then
			e.spirit.die()
		end
		if b.humanoid and b.humanoid.Health <= 0 and e.spirit then
			Debris:AddItem(e.folder, b.fight.lovers.spirit.deathDuration)
		else
			e.folder:Destroy()
		end
	end
	Cast.Clear(b)
end
local function encounter(b: any): any
	local e = encounters[b]
	if not e or not living(b, e) then
		API.Clear(b)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "LoversEncounter", workspace
		e = {
			boss = b,
			root = b.root,
			folder = folder,
			projectiles = 0,
			combo = 0,
			nextSpirit = 0,
			phase = b.model:GetAttribute("LoversPhase") or 1,
		}
		encounters[b] = e
	end
	return e
end
local function actorAlive(b: any, e: any, actor: any): boolean
	return living(b, e) and actor.root:IsDescendantOf(workspace) and actor.humanoid.Health > 0
end
local function rayFor(actor: any, e: any, hooks: any): RaycastParams
	local ray = Cast.Params(actor, e, hooks)
	local ignore = ray.FilterDescendantsInstances
	if e.boss.model then
		table.insert(ignore, e.boss.model)
	end
	ray.FilterDescendantsInstances = ignore
	return ray
end
local function occupied(at: Vector3, size: Vector3, ray: RaycastParams): boolean
	local p = OverlapParams.new()
	p.FilterType, p.FilterDescendantsInstances, p.RespectCanCollide =
		ray.FilterType, ray.FilterDescendantsInstances, true
	return #workspace:GetPartBoundsInBox(CFrame.new(at), size, p) > 0
end
local function floor(
	actor: any,
	e: any,
	hooks: any,
	target: Vector3,
	range: number,
	margin: number
): Vector3?
	if
		((target - actor.root.Position) * FLAT).Magnitude > range
		or ((target - actor.spawn.Position) * FLAT).Magnitude > actor.arenaRadius - margin
	then
		return nil
	end
	local ray = rayFor(actor, e, hooks)
	local hit = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -24, 0), ray)
	local base =
		workspace:Raycast(actor.root.Position + Vector3.new(0, 3, 0), Vector3.new(0, -20, 0), ray)
	if
		not hit
		or not base
		or hit.Normal.Y < 0.55
		or math.abs(hit.Position.Y - base.Position.Y) > 2.5
	then
		return nil
	end
	local at = hit.Position + Vector3.new(0, 0.08, 0)
	if
		workspace:Raycast(actor.root.Position, target - actor.root.Position, ray)
		or workspace:Raycast(base.Position + Vector3.new(0, 0.6, 0), at - base.Position, ray)
		or occupied(at + Vector3.new(0, 1.3, 0), Vector3.new(1.4, 2.2, 1.4), ray)
	then
		return nil
	end
	return at
end
local function rig(id: string, parent: Instance, at: CFrame, texture: string): (Model, BasePart)
	local m, root = Instance.new("Model"), Instance.new("Part")
	m.Name, m.ModelStreamingMode = id, Enum.ModelStreamingMode.Atomic
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.one, 1, true
	root.CanCollide, root.CanQuery, root.CanTouch = false, false, false
	root.CFrame, root.Parent = at * CFrame.new(0, if id == "lover_spirit" then 3.6 else 0, 0), m
	BlockRig.build(
		if id == "lover_spirit" then spiritDef else require(Shared.Models[id]),
		m,
		root,
		at,
		texture
	)
	if id ~= "lover_spirit" then
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				p.CanQuery = false
			end
		end
	end
	m.PrimaryPart, m.Parent = root, parent
	return m, root
end
local function prop(
	id: string,
	e: any,
	at: CFrame,
	texture: string,
	clip: string
): (Model, BasePart)
	local m, root = rig(id, e.folder, at, texture)
	m:SetAttribute("BlockModel", id)
	m:SetAttribute("Action", clip)
	m:SetAttribute("ActionAt", workspace:GetServerTimeNow())
	m:SetAttribute("ActionLen", 20)
	CollectionService:AddTag(m, "BossProp")
	return m, root
end
local function hit(
	b: any,
	e: any,
	actor: any,
	hooks: any,
	f: any,
	amount: number,
	at: Vector3,
	seen: any
): boolean
	if
		not actorAlive(b, e, actor)
		or seen[f.humanoid]
		or not f.root.Parent
		or f.humanoid.Health <= 0
		or workspace:Raycast(at, f.root.Position - at, rayFor(actor, e, hooks))
	then
		return false
	end
	if hooks.hurt(b, f, amount, at, 0.3, 0) == false then
		return false
	end
	seen[f.humanoid] = true
	return true
end
local function projectile(
	b: any,
	e: any,
	actor: any,
	hooks: any,
	id: string,
	from: Vector3,
	dir: Vector3,
	cfg: any,
	seen: any
)
	local key, cap = "projectiles", 16
	local ray = rayFor(actor, e, hooks)
	if
		not actorAlive(b, e, actor)
		or e[key] >= cap
		or dir.Magnitude < 0.01
		or workspace:Raycast(actor.root.Position, from - actor.root.Position, ray)
		or occupied(from, Vector3.one, ray)
	then
		return
	end
	dir = dir.Unit
	e[key] += 1
	local m, root = prop(
		id,
		e,
		CFrame.lookAt(from, from + dir),
		b.fight.texture,
		if id == "lover_star" or id == "lover_sickle" then "spin" else "idle"
	)
	local travelRange = cfg.range * (if cfg.returning then 2 else 1)
	Debris:AddItem(m, travelRange / cfg.speed + 1)
	local start, previous = os.clock(), from
	while actorAlive(b, e, actor) and m.Parent do
		local distance = math.min(travelRange, (os.clock() - start) * cfg.speed)
		local progress = if distance > cfg.range then travelRange - distance else distance
		local point = from + dir * progress
		local step = point - previous
		local wall = if step.Magnitude > 0.001
			then workspace:Spherecast(previous, 0.55, step, ray)
			else nil
		local nearest, target = math.huge, nil
		for _, f in hooks.fighters(b) do
			local u = if step.Magnitude > 0.001
				then math.clamp((f.root.Position - previous):Dot(step) / step:Dot(step), 0, 1)
				else 0
			local d = step.Magnitude * u
			if
				not seen[f.humanoid]
				and f.root.Parent
				and f.humanoid.Health > 0
				and (f.root.Position - previous - step * u).Magnitude <= cfg.radius + 1
				and d < nearest
				and (not wall or d <= wall.Distance)
			then
				nearest, target = d, f
			end
		end
		if target and hit(b, e, actor, hooks, target, cfg.damage, previous, seen) then
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
		if distance >= travelRange then
			break
		end
		previous = point
		RunService.Heartbeat:Wait()
	end
	m:Destroy()
	e[key] = math.max(0, e[key] - 1)
end
local function melee(b: any, e: any, actor: any, s: any, hooks: any, start: number, cfg: any)
	-- A combo is a total damage budget, split over separate visible contacts.
	for _, t in cfg.contacts do
		if not Cast.WaitUntil(actor, s, start, t) or not actorAlive(b, e, actor) then
			break
		end
		Cast.Hit(actor, s, hooks, actor.root.Position, cfg, cfg.damage / #cfg.contacts)
	end
end
local function dash(
	b: any,
	e: any,
	actor: any,
	s: any,
	hooks: any,
	target: Vector3,
	start: number,
	cfg: any
)
	local goal = Cast.Destination(actor, s, hooks, target, cfg.range)
	local from = actor.root.Position
	-- Keep the collision root grounded. The airborne body arc lives in the authored clip.
	local valid = true
	for i = 0, math.ceil((goal - from).Magnitude / 2) do
		local u = i / math.max(1, math.ceil((goal - from).Magnitude / 2))
		if not floor(actor, e, hooks, from:Lerp(goal, u), cfg.range + 1, 3) then
			valid = false
			break
		end
	end
	if not valid then
		goal = from
	end
	local at = floor(actor, e, hooks, goal, cfg.range + 1, cfg.radius)
	if at then
		local warning = Cast.Mark(actor, s, hooks, at, cfg.radius, COLOR)
		warning.Material = Enum.Material.SmoothPlastic
	end
	local moved = Cast.Travel(
		actor,
		s,
		hooks,
		goal,
		start,
		cfg.moveAt,
		cfg.release,
		function(previous: Vector3, point: Vector3)
			if not floor(actor, e, hooks, point, 1, 3) then
				actor.root.CFrame = CFrame.new(previous) * actor.root.CFrame.Rotation
				Cast.Finish(actor, s)
			end
		end
	)
	if
		moved
		and Cast.Alive(actor, s)
		and actorAlive(b, e, actor)
		and floor(actor, e, hooks, actor.root.Position, 1, cfg.radius)
	then
		Cast.Hit(actor, s, hooks, actor.root.Position, cfg, cfg.damage, cfg.omnidirectional == true)
		Cast.Pulse(
			e,
			Cast.FloorAt(actor, actor.root.Position, rayFor(actor, e, hooks)),
			cfg.radius,
			COLOR
		)
	end
end
local function loadArrow(actor: any, e: any, texture: string)
	if actor.nock then
		actor.nock:Destroy()
	end
	local joint = actor.model:FindFirstChild("J_arrow") :: BasePart?
	if not joint then
		return
	end
	local m, root = Instance.new("Model"), Instance.new("Part")
	m.Name, m.ModelStreamingMode = "LoverNockedArrow", Enum.ModelStreamingMode.Atomic
	root.Name, root.Size, root.Transparency = "Root", Vector3.one * 0.1, 1
	root.CanCollide, root.CanQuery, root.CanTouch, root.Massless = false, false, false, true
	root.CFrame, root.Parent = joint.CFrame, m
	BlockRig.build(nockDef, m, root, joint.CFrame * CFrame.new(-nockPivot), texture)
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") then
			p.CanQuery = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1, weld.Parent = joint, root, root
	m.PrimaryPart, m.Parent, actor.nock = root, e.folder, m
end
local function mark(actor: any, s: any, hooks: any, at: Vector3, radius: number)
	local warning = Cast.Mark(actor, s, hooks, at, radius, COLOR)
	warning.Material = Enum.Material.SmoothPlastic
end
local function volley(b: any, e: any, actor: any, hooks: any, target: Vector3, cfg: any, id: string)
	local from = actor.root.Position + Vector3.new(0, 1, 0)
	local delta = target - from
	if delta.Magnitude < 0.01 then
		delta = actor.root.CFrame.LookVector
	end
	local seen = {}
	for i = 1, cfg.count or 1 do
		local yaw = math.rad((i - ((cfg.count or 1) + 1) / 2) * (cfg.spread or 0))
		local dir = CFrame.Angles(0, yaw, 0):VectorToWorldSpace(delta.Unit)
		task.spawn(projectile, b, e, actor, hooks, id, from, dir, cfg, seen)
	end
end
local function rain(
	b: any,
	e: any,
	actor: any,
	s: any,
	hooks: any,
	target: Vector3,
	start: number,
	cfg: any
)
	local points = {}
	for i = 1, cfg.count do
		local point = floor(
			actor,
			e,
			hooks,
			target + actor.root.CFrame.RightVector * (i - (cfg.count + 1) / 2) * 3.5,
			cfg.range,
			3
		)
		if point then
			mark(actor, s, hooks, point, cfg.radius + 1)
			table.insert(points, point)
		end
	end
	if not Cast.WaitUntil(actor, s, start, cfg.release) then
		return
	end
	local seen = {}
	for _, point in points do
		if
			actorAlive(b, e, actor)
			and floor(actor, e, hooks, point + Vector3.new(0, 2, 0), cfg.range, 3)
		then
			local launch = point + Vector3.new(0, 14, 0)
			local ray = rayFor(actor, e, hooks)
			if not workspace:Raycast(point + Vector3.new(0, 1, 0), Vector3.new(0, 13, 0), ray) then
				task.spawn(
					projectile,
					b,
					e,
					actor,
					hooks,
					"lover_arrow",
					launch,
					-Vector3.yAxis,
					cfg,
					seen
				)
			end
		end
	end
end
local function spiritHooks(b: any, hooks: any): any
	return {
		fighters = function()
			return hooks.fighters(b)
		end,
		hurt = function(_, f, amount, at, strength, lift)
			return hooks.hurt(b, f, amount, at, strength, lift)
		end,
		telegraph = hooks.telegraph,
		act = function(actor, name, duration)
			actor.model:SetAttribute("Action", name)
			actor.model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
			actor.model:SetAttribute("ActionLen", duration)
		end,
	}
end
local function spiritSpell(
	b: any,
	e: any,
	actor: any,
	hooks: any,
	name: string,
	target: Vector3,
	cfg: any
)
	if not actorAlive(b, e, actor) then
		return
	end
	local own = spiritHooks(b, hooks)
	local s = Cast.Begin(actor, name, cfg.duration, cfg.release, target, own)
	local start = os.clock()
	loadArrow(actor, e, b.fight.texture)
	if name == "rain" then
		rain(b, e, actor, s, own, target, start, cfg)
	elseif Cast.WaitUntil(actor, s, start, cfg.release) and actorAlive(b, e, actor) then
		volley(
			b,
			e,
			actor,
			own,
			target,
			cfg,
			if name == "spear" then "lover_spear" else "lover_arrow"
		)
	end
	if Cast.Alive(actor, s) then
		if actor.nock then
			actor.nock:Destroy()
			actor.nock = nil
		end
	end
	local completed = Cast.WaitUntil(actor, s, start, cfg.duration)
	Cast.Finish(actor, s)
	if completed and actorAlive(b, e, actor) then
		actor.nextShotAt = os.clock()
			+ b.fight.lovers.spirit.recovery * (if e.phase == 3 then 0.75 else 1)
	end
end
local function maintainSpirit(b: any, e: any, hooks: any)
	if e.phase < 2 or os.clock() < e.nextSpirit or (e.spirit and actorAlive(b, e, e.spirit)) then
		return
	end
	local cfg = b.fight.lovers.spirit
	local at = floor(b, e, hooks, b.root.Position - b.root.CFrame.RightVector * 7, 9, 4)
	if
		not at
		or occupied(at + Vector3.new(0, 3.6, 0), Vector3.new(3.4, 7.0, 2.4), rayFor(b, e, hooks))
	then
		e.nextSpirit = os.clock() + 3
		return
	end
	local m, root = rig("lover_spirit", e.folder, CFrame.new(at), b.fight.texture)
	root.Size, root.CanCollide = Vector3.new(2.2, 7.0, 1.8), true
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath, h.AutoRotate = false, false, true
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 0
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, m
	local state = Instance.new("Folder")
	state.Name, state.Parent = "CastState", m
	local actor = {
		model = m,
		root = root,
		humanoid = h,
		spawn = b.spawn,
		arenaRadius = b.arenaRadius,
		state = state,
		busyUntil = 0,
	}
	e.spirit = actor
	m:SetAttribute("MobId", "lover_spirit")
	m:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	m:SetAttribute("Shielded", false)
	CollisionGroups.mob(m)
	CollectionService:AddTag(m, "Mob")
	Debris:AddItem(m, cfg.spawnDuration + cfg.lifetime + cfg.deathDuration + 1)
	local dead = false
	local function die()
		if dead or not m.Parent then
			return
		end
		dead = true
		Cast.Clear(actor)
		root.Anchored, root.CanCollide, h.WalkSpeed = true, false, 0
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		if h.Health > 0 then
			h.Health = 0
		end
		e.nextSpirit = math.max(e.nextSpirit, os.clock() + cfg.resummonDelay)
		Debris:AddItem(m, cfg.deathDuration)
		if actor.nock then
			Debris:AddItem(actor.nock, cfg.deathDuration)
		end
	end
	actor.die = die
	loadArrow(actor, e, b.fight.texture)
	h.Died:Once(die)
	task.spawn(function()
		task.wait(cfg.spawnDuration)
		if not actorAlive(b, e, actor) then
			die()
			return
		end
		Physics.restore(root, false)
		h.WalkSpeed = cfg.speed
		local expires, index = os.clock() + cfg.lifetime, 0
		task.delay(cfg.lifetime, die) -- Also cancels a cast that crosses the lifetime boundary.
		actor.nextShotAt = os.clock() + 0.5
		local names = { "bowshot", "fan", "spear", "rain" }
		while actorAlive(b, e, actor) and os.clock() < expires do
			local target, distance = nil, math.huge
			for _, f in hooks.fighters(b) do
				local d = (f.root.Position - root.Position).Magnitude
				if f.root.Parent and f.humanoid.Health > 0 and d < distance then
					target, distance = f, d
				end
			end
			if
				not target
				or ((root.Position - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius
				or root.Position.Y < b.spawn.Position.Y - 20
			then
				break
			end
			if os.clock() >= actor.busyUntil then
				if distance > 23 then
					h:MoveTo(target.root.Position)
				else
					h:MoveTo(root.Position)
				end
				if os.clock() >= actor.nextShotAt and distance < 36 then
					index = index % #names + 1
					local name = names[index]
					spiritSpell(b, e, actor, hooks, name, target.root.Position, cfg[name])
				end
			end
			task.wait(0.15)
		end
		die()
	end)
end
local function advance(b: any, e: any, hooks: any): boolean
	local cfg = b.fight.lovers
	local ratio = b.humanoid.Health / b.humanoid.MaxHealth
	local desired = if ratio <= cfg.phase3At then 3 elseif ratio <= b.fight.phase2At then 2 else 1
	if e.phase >= desired then
		return false
	end
	e.phase += 1
	b.model:SetAttribute("LoversPhase", e.phase)
	local stage = e.phase
	local duration = if stage == 2 then cfg.phase2Duration else cfg.phase3Duration
	local s = Cast.Begin(b, "phase" .. stage, duration, 0, nil, hooks, cfg.recovery)
	task.spawn(function()
		local start = os.clock()
		Cast.EndAfter(b, s, start, duration)
		if living(b, e) then
			maintainSpirit(b, e, hooks)
		end
	end)
	return true
end
function API.Spawn(b: any, hooks: any)
	b.model:SetAttribute("LoversPhase", 1)
	encounter(b)
	local duration = b.fight.lovers.spawnDuration
	local s = Cast.Begin(b, "spawn", duration, 0, nil, hooks)
	task.spawn(Cast.EndAfter, b, s, os.clock(), duration)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	local e = encounter(b)
	if advance(b, e, hooks) then
		return
	end
	maintainSpirit(b, e, hooks)
	e.combo = e.combo % 2 + 1
	local name = if e.combo == 1 then "drawcut" else "reversecut"
	local cfg = b.fight.lovers[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks)
	task.spawn(function()
		local start = os.clock()
		if Cast.WaitUntil(b, s, start, cfg.release) then
			Cast.Hit(b, s, hooks, b.root.Position, cfg, cfg.damage)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
function API.Cast(b: any, index: number, target: Vector3, _phase2: boolean, hooks: any)
	local e = encounter(b)
	if advance(b, e, hooks) then
		return
	end
	maintainSpirit(b, e, hooks)
	local name = SPECIALS[(index - 1) % #SPECIALS + 1]
	if e.phase == 1 and index > 6 then
		name = "stars"
	end
	if name == "arrowcall" and (not e.spirit or not actorAlive(b, e, e.spirit)) then
		name = "spears"
	end
	local cfg = b.fight.lovers[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.lovers.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "triplecut" then
			melee(b, e, b, s, hooks, start, cfg)
		elseif name == "sweep" then
			local at = floor(b, e, hooks, b.root.Position, 1, cfg.radius)
			if at then
				mark(b, s, hooks, at, cfg.radius)
			end
			if
				at
				and Cast.WaitUntil(b, s, start, cfg.release)
				and floor(b, e, hooks, b.root.Position, 1, cfg.radius)
			then
				Cast.Hit(b, s, hooks, b.root.Position, cfg, cfg.damage, true)
			end
		elseif name == "thrust" or name == "dashcut" or name == "skycut" then
			dash(b, e, b, s, hooks, target, start, cfg)
		elseif name == "arrowcall" then
			if
				Cast.WaitUntil(b, s, start, cfg.release)
				and e.spirit
				and actorAlive(b, e, e.spirit)
			then
				local rainCfg = table.clone(b.fight.lovers.spirit.rain)
				rainCfg.damage = cfg.damage
				task.spawn(spiritSpell, b, e, e.spirit, hooks, "rain", target, rainCfg)
			end
		elseif Cast.WaitUntil(b, s, start, cfg.release) then
			volley(
				b,
				e,
				b,
				hooks,
				target,
				cfg,
				if name == "stars"
					then "lover_star"
					elseif name == "sickle" then "lover_sickle"
					else "lover_spear"
			)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
