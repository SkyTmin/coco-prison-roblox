--!strict
-- Audited attack families; original vulnerable knight/retainer encounter. Studio QA pending.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local Cast = require(script.Parent.BossCast)
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local COLOR = Color3.fromRGB(108, 121, 141)
local SPECIALS = { "fastcombo", "comboflyattack", "explosion", "ravencall" }
local RETAINER_ATTACKS = { "basicattack", "chargeattack", "fogcombo", "summonaxe", "spikesattack" }
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
		if e.retainer then
			Cast.Clear(e.retainer)
		end
		e.folder:Destroy()
	end
	Cast.Clear(b)
end
local function encounter(b: any): any
	local e = encounters[b]
	if not e or not living(b, e) then
		API.Clear(b)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "RavenKnightEncounter", workspace
		e = { root = b.root, folder = folder, birds = 0, axes = 0, combo = 0, nextRetainer = 0 }
		encounters[b] = e
	end
	return e
end
local function actorAlive(b: any, e: any, actor: any): boolean
	return living(b, e) and actor.root:IsDescendantOf(workspace) and actor.humanoid.Health > 0
end
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, COLOR
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Parent = Enum.Material.SmoothPlastic, parent
	return p
end
local function rayFor(actor: any, e: any, hooks: any): RaycastParams
	return Cast.Params(actor, e, hooks)
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
	root.CFrame, root.Parent = at * CFrame.new(0, if id == "crow_reaper" then 4.5 else 0, 0), m
	BlockRig.build(require(Shared.Models[id]), m, root, at, texture)
	if id ~= "crow_reaper" then
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
	local key = if id == "raven" then "birds" else "axes"
	local cap = if id == "raven" then b.fight.ravenKnight.ravencall.maxAlive else 1
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
		if id == "raven" then "flight" else "spin"
	)
	Debris:AddItem(m, cfg.range / cfg.speed + 1)
	local start, previous = os.clock(), from
	while actorAlive(b, e, actor) and m.Parent do
		local distance = math.min(cfg.range, (os.clock() - start) * cfg.speed)
		local point = from + dir * distance
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
		if distance >= cfg.range then
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
		Cast.Mark(actor, s, hooks, at, cfg.radius, COLOR)
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
		Cast.Hit(actor, s, hooks, actor.root.Position, cfg, cfg.damage, true)
		Cast.Pulse(
			e,
			Cast.FloorAt(actor, actor.root.Position, rayFor(actor, e, hooks)),
			cfg.radius,
			COLOR
		)
	end
end
local function spike(b: any, e: any, actor: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if
		not actorAlive(b, e, actor)
		or not floor(actor, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius)
	then
		return
	end
	for i = 1, 5 do
		local angle = i * math.pi * 0.4
		local point = at + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.radius * 0.6
		local p = part(e.folder, "CrowSpike", Vector3.new(0.3, 0.1, 0.4), CFrame.new(point))
		TweenService:Create(p, TweenInfo.new(0.16), {
			Size = Vector3.new(0.3, 2.6, 0.4),
			CFrame = CFrame.new(point + Vector3.new(0, 1.3, 0)),
		}):Play()
		Debris:AddItem(p, 1.2)
	end
	for _, f in hooks.fighters(b) do
		if
			((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
			and math.abs(f.root.Position.Y - at.Y) <= 6
		then
			hit(b, e, actor, hooks, f, cfg.damage, at + Vector3.new(0, 1, 0), seen)
		end
	end
end
local function reaper(b: any, e: any, hooks: any, target: Vector3)
	local cfg = b.fight.ravenKnight.retainer
	if
		not living(b, e)
		or os.clock() < e.nextRetainer
		or (e.retainer and e.retainer.model.Parent)
	then
		return
	end
	local side = b.root.CFrame.RightVector
	local at = floor(b, e, hooks, b.root.Position + side * 6, 8, 4)
		or floor(b, e, hooks, b.root.Position - side * 6, 8, 4)
	if not at then
		return
	end
	if occupied(at + Vector3.new(0, 4.5, 0), Vector3.new(3.2, 8.6, 2.6), rayFor(b, e, hooks)) then
		return
	end
	e.nextRetainer = os.clock() + cfg.cooldown
	local m, root = rig("crow_reaper", e.folder, CFrame.new(at), b.fight.texture)
	root.Size, root.CanCollide, root.CanQuery = Vector3.new(2.8, 5, 2), true, true
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath, h.AutoRotate = false, false, true
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 2
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, m
	m:SetAttribute("MobId", "crow_reaper")
	m:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	m:SetAttribute("Shielded", false)
	CollisionGroups.mob(m)
	CollectionService:AddTag(m, "Mob")
	local a: any = {
		model = m,
		root = root,
		humanoid = h,
		state = m,
		spawn = b.spawn,
		arenaRadius = b.arenaRadius,
		fight = b.fight,
		busyUntil = 0,
		nextAbilityAt = 0,
	}
	e.retainer = a
	local ah = {
		act = function(actor: any, name: string, duration: number)
			actor.model:SetAttribute("Action", name)
			actor.model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
			actor.model:SetAttribute("ActionLen", duration)
		end,
		fighters = function()
			return hooks.fighters(b)
		end,
		hurt = function(
			_actor: any,
			f: any,
			damage: number,
			center: Vector3,
			horizontal: number,
			vertical: number
		)
			if actorAlive(b, e, a) then
				return hooks.hurt(b, f, damage, center, horizontal, vertical)
			end
			return false
		end,
		telegraph = hooks.telegraph,
	}
	local dead = false
	local function die()
		if dead then
			return
		end
		dead = true
		Cast.Clear(a)
		if m.Parent then
			root.Anchored, h.WalkSpeed = true, 0
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			if h.Health > 0 then
				h.Health = 0
			end
			Debris:AddItem(m, cfg.deathDuration)
		end
	end
	h.Died:Once(die)
	Debris:AddItem(m, cfg.spawnDuration + cfg.lifetime + cfg.deathDuration + 1)
	task.spawn(function()
		task.wait(cfg.spawnDuration)
		if not actorAlive(b, e, a) then
			die()
			return
		end
		Physics.restore(root, false)
		h.WalkSpeed = cfg.speed
		local expires, nextCast, index = os.clock() + cfg.lifetime, os.clock() + 0.5, 0
		while actorAlive(b, e, a) and os.clock() < expires do
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
				or root.Position.Y < b.spawn.Position.Y - 18
			then
				break
			end
			target = chosen.root.Position
			if os.clock() >= nextCast and distance <= cfg.castRange then
				index = index % #RETAINER_ATTACKS + 1
				local name = RETAINER_ATTACKS[index]
				local attack = cfg[name]
				local s = Cast.Begin(a, name, attack.duration, attack.release, target, ah)
				local start = os.clock()
				if name == "chargeattack" then
					dash(b, e, a, s, ah, target, start, attack)
				elseif name == "summonaxe" then
					local from = root.Position + root.CFrame.LookVector * 2 + Vector3.new(0, 1, 0)
					if Cast.WaitUntil(a, s, start, attack.release) then
						task.spawn(
							projectile,
							b,
							e,
							a,
							hooks,
							"crow_axe",
							from,
							target - from,
							attack,
							{}
						)
					end
				elseif name == "spikesattack" then
					local points = {}
					for i = -1, 1 do
						local point = floor(
							a,
							e,
							ah,
							target + root.CFrame.RightVector * i * 4,
							attack.range,
							attack.radius
						)
						if point then
							table.insert(points, point)
							Cast.Mark(a, s, ah, point, attack.radius, COLOR)
						end
					end
					if Cast.WaitUntil(a, s, start, attack.release) then
						local seen = {}
						for _, point in points do
							spike(b, e, a, hooks, point, attack, seen)
						end
					end
				else
					if name == "fogcombo" then
						-- Six low matte wisps; no opaque screen fog or global lighting changes.
						local center = Cast.FloorAt(a, root.Position, rayFor(a, e, ah))
						for i = 1, 6 do
							local angle = i * math.pi / 3
							local p = part(
								s.folder,
								"CrowFog",
								Vector3.new(1.1, 0.25, 0.6),
								CFrame.new(
									center
										+ Vector3.new(
											math.cos(angle) * 3,
											0.25,
											math.sin(angle) * 3
										)
								)
							)
							p.Transparency = 0.55
						end
					end
					melee(b, e, a, s, ah, start, attack)
				end
				Cast.EndAfter(a, s, start, attack.duration)
				nextCast = os.clock() + cfg.recovery
			elseif distance > 6 then
				h:MoveTo(target)
			else
				h:MoveTo(root.Position)
			end
			task.wait(0.15)
		end
		die()
	end)
end
function API.Spawn(b: any, hooks: any)
	local cfg = b.fight.ravenKnight
	local s = Cast.Begin(b, "spawn", cfg.spawnDuration, 0, nil, hooks)
	task.spawn(Cast.EndAfter, b, s, os.clock(), cfg.spawnDuration)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	local e = encounter(b)
	e.combo = e.combo % 2 + 1
	local name = if e.combo == 1 then "simplecombo" else "simplecombo2"
	local cfg = b.fight.ravenKnight.melee
	local s = Cast.Begin(b, name, cfg.duration, cfg.contacts[1], target, hooks)
	task.spawn(function()
		local start = os.clock()
		melee(b, e, b, s, hooks, start, cfg)
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
function API.Cast(b: any, index: number, target: Vector3, phase2: boolean, hooks: any)
	local e = encounter(b)
	local name = SPECIALS[(index - 1) % #SPECIALS + 1]
	local all = b.fight.ravenKnight
	local cfg = all[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, all.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "fastcombo" then
			melee(b, e, b, s, hooks, start, cfg)
		elseif name == "comboflyattack" then
			dash(b, e, b, s, hooks, target, start, cfg)
		elseif name == "explosion" then
			local at = floor(b, e, hooks, b.root.Position, 1, cfg.radius)
			if at then
				Cast.Mark(b, s, hooks, at, cfg.radius, COLOR)
				if
					Cast.WaitUntil(b, s, start, cfg.release)
					and floor(b, e, hooks, b.root.Position, 1, cfg.radius)
				then
					Cast.Hit(b, s, hooks, b.root.Position, cfg, cfg.damage, true)
					Cast.Pulse(e, at, cfg.radius, COLOR)
				end
			end
		else
			local from = b.root.Position + b.root.CFrame.LookVector * 2 + Vector3.new(0, 2.5, 0)
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local delta = target - from
				if delta.Magnitude > 0.01 then
					local count, seen = if phase2 then cfg.phase2Count else cfg.count, {}
					for i = 1, count do
						local dir =
							CFrame.Angles(0, math.rad((i - (count + 1) / 2) * cfg.spread), 0)
								:VectorToWorldSpace(delta.Unit)
						task.spawn(projectile, b, e, b, hooks, "raven", from, dir, cfg, seen)
					end
				end
				if phase2 then
					reaper(b, e, hooks, target)
				end
			end
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
