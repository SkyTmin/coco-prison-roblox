--!strict
-- Audited forest spell families; original vulnerable channels and destructible ritual summons.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local Needs = require(script.Parent.NeedsService)
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local Definition = require(Shared.Models.forest_spirit) :: any
local Prepared = BlockRig.prepare(Definition)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local PEARL, VIOLET = Color3.fromRGB(104, 92, 69), Color3.fromRGB(151, 153, 76)
local NAMES = { "attack1", "attack2", "attack3", "attack4", "attack5", "attack6", "attack8" }
local function living(b: any, e: any): boolean
	return encounters[b] == e
		and b.root == e.root
		and e.root:IsDescendantOf(workspace)
		and b.humanoid.Health > 0
end
local function prune(list: { Model }): { Model }
	local alive = {}
	for _, m in list do
		local h = m:FindFirstChildOfClass("Humanoid")
		if m.Parent and h and h.Health > 0 then
			table.insert(alive, m)
		end
	end
	return alive
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
		folder.Name, folder.Parent = "ForestSpiritEncounter", workspace
		e = { root = b.root, folder = folder, adds = {} }
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
local function overlap(cf: CFrame, size: Vector3, ray: RaycastParams): boolean
	local p = OverlapParams.new()
	p.FilterType, p.FilterDescendantsInstances, p.RespectCanCollide =
		ray.FilterType, ray.FilterDescendantsInstances, true
	return #workspace:GetPartBoundsInBox(cf, size, p) > 0
end
local function ground(
	b: any,
	e: any,
	hooks: any,
	target: Vector3,
	range: number,
	margin: number
): Vector3?
	if
		((target - b.root.Position) * FLAT).Magnitude > range
		or ((target - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - margin
	then
		return nil
	end
	local ray = Cast.Params(b, e, hooks)
	local hit = workspace:Raycast(target + Vector3.new(0, 7, 0), Vector3.new(0, -25, 0), ray)
	if not hit or hit.Normal.Y < 0.55 then
		return nil
	end
	local at = hit.Position + Vector3.new(0, 0.1, 0)
	local floor = Cast.FloorAt(b, b.root.Position, ray)
	if
		math.abs(at.Y - floor.Y) > 4
		or workspace:Raycast(b.root.Position, target - b.root.Position, ray)
		or workspace:Raycast(floor + Vector3.new(0, 0.6, 0), at - floor, ray)
		or overlap(CFrame.new(at + Vector3.new(0, 1.2, 0)), Vector3.new(1.2, 2, 1.2), ray)
	then
		return nil
	end
	return at
end
local function socket(b: any, clip: string, t: number, name: string): Vector3
	local j = b.model:FindFirstChild("J_root")
	local m = j and j:FindFirstChild("root")
	local origin = b.root.CFrame * (if m and m:IsA("Motor6D") then m.C0 else CFrame.new(0, -4.5, 0))
	local worlds, pivots = {}, {}
	for _, v in Definition.joints do
		local p = Vector3.new(v.pivot[1], v.pivot[2], v.pivot[3])
		pivots[v.name] = p
		worlds[v.name] = (if v.parent then worlds[v.parent] else origin)
			* CFrame.new(if v.parent then p - pivots[v.parent] else p)
			* BlockRig.sample(Prepared.clips[clip], v.name, t)
		if v.name == name then
			return worlds[v.name].Position
		end
	end
	return origin.Position
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
	if hooks.hurt(b, f, amount, at, 0.3, 0) == false then
		return false
	end
	seen[f.humanoid] = true
	return true
end
local function impact(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if not living(b, e) then
		return
	end
	Cast.Pulse(e, at, cfg.radius, VIOLET)
	for _, f in hooks.fighters(b) do
		if
			((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
			and math.abs(f.root.Position.Y - at.Y) < 6
		then
			hit(b, e, hooks, f, cfg.damage, at + Vector3.new(0, 1, 0), seen)
		end
	end
end
local function bolt(b: any, e: any, hooks: any, origin: Vector3, dir: Vector3, cfg: any, seen: any)
	local ray = Cast.Params(b, e, hooks)
	if
		workspace:Raycast(b.root.Position, origin - b.root.Position, ray)
		or overlap(CFrame.new(origin), Vector3.one * 0.5, ray)
	then
		return
	end
	local p =
		part(e.folder, "SpiritArrow", Vector3.new(0.22, 0.22, 1.8), CFrame.new(origin), VIOLET)
	Debris:AddItem(p, cfg.range / cfg.speed + 1)
	local start, previous = os.clock(), origin
	while living(b, e) and p.Parent do
		local d = math.min(cfg.range, (os.clock() - start) * cfg.speed)
		local point = origin + dir * d
		local step = point - previous
		local wall = if step.Magnitude > 0.001
			then workspace:Spherecast(previous, 0.25, step, ray)
			else nil
		local nearest, chosen = math.huge, nil
		for _, f in hooks.fighters(b) do
			local u = if step.Magnitude > 0.001
				then math.clamp((f.root.Position - previous):Dot(step) / step:Dot(step), 0, 1)
				else 0
			local closest = previous + step * u
			local off = f.root.Position - closest
			local along = step.Magnitude * u
			if
				not seen[f.humanoid]
				and f.humanoid.Health > 0
				and f.root.Parent
				and off.Magnitude <= cfg.radius + 1
				and along < nearest
				and (not wall or along <= wall.Distance)
			then
				nearest, chosen = along, f
			end
		end
		if chosen and hit(b, e, hooks, chosen, cfg.damage, previous, seen) then
			break
		end
		if
			wall
			or overlap(CFrame.new(point), Vector3.one * 0.4, ray)
			or ((point - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - 1
		then
			break
		end
		p.CFrame = CFrame.lookAt(point, point + dir) * CFrame.Angles(0, 0, d * 0.8)
		if d >= cfg.range then
			break
		end
		previous = point
		RunService.Heartbeat:Wait()
	end
	p:Destroy()
end
local function ring(b: any, e: any, hooks: any, center: Vector3, right: Vector3, cfg: any)
	local pieces = {}
	local seen = {}
	local ray = Cast.Params(b, e, hooks)
	local gap = math.cos(math.rad(cfg.gapDegrees))
	for i = 0, 31 do
		local angle = i * math.pi / 16
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if dir:Dot(right) < gap then
			table.insert(pieces, {
				part = part(
					e.folder,
					"SeedWave",
					Vector3.new(0.3, 0.35, 1),
					CFrame.new(center),
					VIOLET
				),
				dir = dir,
			})
		end
	end
	local start, previous, nextScan = os.clock(), 0, 0
	while living(b, e) do
		local radius = math.min(cfg.radius, (os.clock() - start) * cfg.speed)
		local scan = os.clock() >= nextScan
		if scan then
			nextScan = os.clock() + 0.15
			if not ground(b, e, hooks, center + Vector3.new(0, 2, 0), 1, cfg.radius) then
				break
			end
		end
		for _, v in pieces do
			if scan then
				local wall =
					workspace:Raycast(center + Vector3.new(0, 0.35, 0), v.dir * cfg.radius, ray)
				v.limit = if wall then wall.Distance else cfg.radius
			end
			local at = center + v.dir * radius
			v.part.CFrame = CFrame.lookAt(at, at + v.dir)
			v.part.Size = Vector3.new(math.max(0.1, radius * math.pi / 16), 0.35, cfg.width)
			v.part.Transparency = if radius > v.limit then 1 else 0
		end
		for _, f in hooks.fighters(b) do
			local offset = f.root.Position - center
			local delta = offset * FLAT
			local d = delta.Magnitude
			if
				d >= previous - cfg.width / 2
				and d <= radius + cfg.width / 2
				and d > 0.01
				and delta.Unit:Dot(right) < gap
				and offset.Y >= -1
				and offset.Y <= cfg.jumpHeight
				and not workspace:Raycast(center + Vector3.new(0, 0.35, 0), delta, ray)
			then
				hit(b, e, hooks, f, cfg.damage, center + Vector3.new(0, 1.5, 0), seen)
			end
		end
		if radius >= cfg.radius then
			break
		end
		previous = radius
		RunService.Heartbeat:Wait()
	end
	for _, v in pieces do
		v.part:Destroy()
	end
end
local function slow(hooks: any, f: any, level: number, seconds: number)
	if hooks.snare then
		hooks.snare(f, level, seconds)
		return
	end
	local p = Players:GetPlayerFromCharacter(f.player.Character)
	if p and not p:GetAttribute("Creative") then
		Needs.GiveEffect(p, "slowness", level, seconds)
	end
end
local function roots(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any, spiky: boolean)
	if
		not living(b, e)
		or not ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius)
	then
		return
	end
	for i = 1, 6 do
		local a = i * math.pi / 3
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local height = if spiky then 2.7 else 1.2
		local center = at + dir * cfg.radius * 0.65
		local p = part(
			e.folder,
			if spiky then "ForestSpike" else "ForestRoot",
			Vector3.new(0.3, 0.15, 0.35),
			CFrame.new(center),
			PEARL
		)
		TweenService:Create(p, TweenInfo.new(0.14), {
			Size = Vector3.new(0.3, height, 0.35),
			CFrame = CFrame.new(center + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(dir.Z * 0.22, a, -dir.X * 0.22),
		}):Play()
		Debris:AddItem(p, 1.5)
		task.delay(0.7, function()
			if p.Parent then
				TweenService:Create(
					p,
					TweenInfo.new(0.65),
					{ CFrame = CFrame.new(center - Vector3.new(0, height, 0)), Transparency = 1 }
				):Play()
			end
		end)
	end
	for _, f in hooks.fighters(b) do
		if
			((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
			and math.abs(f.root.Position.Y - at.Y) < 6
		then
			if hit(b, e, hooks, f, cfg.damage, at + Vector3.new(0, 1, 0), seen) and not spiky then
				slow(hooks, f, cfg.slowLevel or 1, cfg.slowSeconds or 0.8)
			end
		end
	end
end
local function lightning(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if
		not living(b, e)
		or not ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius)
	then
		return
	end
	local ray = Cast.Params(b, e, hooks)
	local floor = at + Vector3.new(0, 0.2, 0)
	local ceiling = workspace:Raycast(floor, Vector3.new(0, cfg.height, 0), ray)
	local height = if ceiling then math.max(0, ceiling.Distance - 0.3) else cfg.height
	if height < 3 then
		return
	end
	local previous = floor + Vector3.new(0, height, 0)
	for i = 1, 6 do
		local nextPoint = floor
			+ Vector3.new(
				if i == 6 then 0 else math.sin(i * 2) * 0.7,
				height * (1 - i / 6),
				if i == 6 then 0 else math.cos(i * 2) * 0.6
			)
		local delta = nextPoint - previous
		if delta.Magnitude > 0.01 then
			local p = part(
				e.folder,
				"SpiritLightning",
				Vector3.new(0.18, 0.18, delta.Magnitude),
				CFrame.lookAt((previous + nextPoint) / 2, nextPoint),
				VIOLET
			)
			TweenService:Create(p, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			Debris:AddItem(p, 0.35)
		end
		previous = nextPoint
	end
	impact(b, e, hooks, at, cfg, seen)
end
local function actor(
	b: any,
	_e: any,
	parent: Instance,
	id: string,
	at: Vector3,
	cfg: any
): (Model, Humanoid, BasePart)
	local m = Instance.new("Model")
	m.Name = id
	local flying = cfg.kind == "flying"
	local lift = if flying then 0.8 else 1.6
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", if flying then Vector3.one * 1.3 else Vector3.new(1.2, 3.2, 1), 1, true
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, if flying then 3.5 else lift, 0)), m
	BlockRig.build(
		require(Shared.Models[id]),
		m,
		root,
		root.CFrame * CFrame.new(0, -lift, 0),
		b.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 0
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, m
	m.PrimaryPart, m.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	m:SetAttribute("MobId", id)
	m:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	CollisionGroups.mob(m)
	m.Parent = parent
	CollectionService:AddTag(m, "Mob")
	return m, h, root
end
local function summon(
	b: any,
	e: any,
	hooks: any,
	group: Instance,
	id: string,
	at: Vector3,
	cfg: any
)
	local m, h, root = actor(b, e, group, id, at, cfg)
	table.insert(e.adds, m)
	Debris:AddItem(m, cfg.spawnDuration + cfg.lifetime + cfg.deathDuration + 0.2)
	local stopped = false
	local function die()
		if stopped or not m.Parent then
			return
		end
		stopped = true
		root.Anchored, h.WalkSpeed = true, 0
		if h.Health > 0 then
			h.Health = 0
		end
		if cfg.kind == "flying" then
			local floor =
				workspace:Raycast(root.Position, Vector3.new(0, -20, 0), Cast.Params(b, e, hooks))
			if floor then
				local from, to =
					root.CFrame,
					CFrame.new(floor.Position + Vector3.new(0, 0.8, 0)) * root.CFrame.Rotation
				task.spawn(function()
					local start = os.clock()
					while living(b, e) and m.Parent do
						local u = math.clamp((os.clock() - start) / 1.2, 0, 1)
						root.CFrame = from:Lerp(to, u * u * (3 - 2 * u))
						if u >= 1 then
							break
						end
						RunService.Heartbeat:Wait()
					end
				end)
			end
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
		if cfg.kind ~= "flying" then
			Physics.restore(root, false)
			h.WalkSpeed = cfg.speed
		end
		local expires, nextHit, previousTime = os.clock() + cfg.lifetime, 0, os.clock()
		while living(b, e) and m.Parent and h.Health > 0 and os.clock() < expires do
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
			then
				break
			end
			local now = os.clock()
			local dt = math.min(0.15, now - previousTime)
			previousTime = now
			local goal = target.root.Position
			local away = (goal - b.spawn.Position) * FLAT
			if away.Magnitude > b.arenaRadius - 2 then
				goal = Vector3.new(b.spawn.Position.X, goal.Y, b.spawn.Position.Z)
					+ away.Unit * (b.arenaRadius - 2)
			end
			if distance > cfg.reach * 0.85 then
				if cfg.kind == "flying" then
					goal = Vector3.new(
						goal.X,
						math.clamp(goal.Y, b.spawn.Position.Y + 1, b.spawn.Position.Y + 8),
						goal.Z
					)
					local delta = goal - root.Position
					if delta.Magnitude > 0.01 then
						local step = delta.Unit * math.min(delta.Magnitude, cfg.speed * dt)
						local ray = Cast.Params(b, e, hooks)
						if
							overlap(CFrame.new(root.Position), Vector3.one * 1.2, ray)
							or workspace:Spherecast(root.Position, 0.65, step, ray)
						then
							break
						end
						local point = root.Position + step
						root.CFrame = CFrame.lookAt(point, point + delta.Unit)
					end
				else
					h:MoveTo(goal)
				end
			else
				h:MoveTo(root.Position)
			end
			if distance <= cfg.reach and now >= nextHit then
				nextHit = now + cfg.cooldown
				Physics.face(root, target.root.Position)
				local aim = target.root.Position
				local point = if cfg.kind == "ranged"
					then ground(b, e, hooks, aim, 34, cfg.radius)
					else nil
				local mark = if point then Cast.Mark(b, e, hooks, point, cfg.radius, PEARL) else nil
				m:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				task.wait(cfg.hitAt)
				if mark then
					mark:Destroy()
				end
				if living(b, e) and m.Parent and h.Health > 0 then
					if cfg.kind == "ranged" then
						if
							point
							and not workspace:Raycast(
								root.Position,
								point - root.Position,
								Cast.Params(b, e, hooks)
							)
						then
							roots(b, e, hooks, point, {
								range = 34,
								radius = cfg.radius,
								damage = cfg.damage,
								slowLevel = 1,
								slowSeconds = 0.8,
							}, {}, false)
						end
					elseif
						target.root.Parent
						and (target.root.Position - root.Position).Magnitude <= cfg.reach
						and not workspace:Raycast(
							root.Position,
							target.root.Position - root.Position,
							Cast.Params(b, e, hooks)
						)
					then
						hooks.hurt(b, target, cfg.damage, root.Position, 0.2, 0)
					end
				end
			end
			task.wait(0.1)
		end
		die()
	end)
end
local function interrupt(b: any, s: any, hooks: any)
	if not Cast.Alive(b, s) then
		return
	end
	Cast.Clear(b)
	local duration = b.fight.forestSpirit.cancelDuration
	local cancelled =
		Cast.Begin(b, "spawn_cancelled", duration, 0, nil, hooks, b.fight.forestSpirit.recovery)
	task.delay(duration, function()
		Cast.Finish(b, cancelled)
	end)
end
local function targets(
	b: any,
	e: any,
	hooks: any,
	target: Vector3,
	cfg: any,
	count: number
): { Vector3 }
	local points = {}
	for i = 1, count do
		local offset = if i == 1
			then Vector3.zero
			else b.root.CFrame.RightVector * (if i == 2 then 8 else -8)
		local at = ground(b, e, hooks, target + offset, cfg.range, cfg.radius)
		if at then
			table.insert(points, at)
		end
	end
	return points
end
local function ritual(b: any, e: any, s: any, hooks: any, start: number, phase2: boolean, cfg: any)
	local goal = s.root.Position + s.root.CFrame.RightVector * cfg.range
	local at = ground(b, e, hooks, goal, cfg.range + 0.1, 3)
	if not at then
		return
	end
	Cast.Mark(b, s, hooks, at, 2, PEARL)
	if
		not Cast.WaitUntil(b, s, start, cfg.release)
		or not ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range + 0.1, 3)
	then
		return
	end
	local group = Instance.new("Folder")
	group.Name, group.Parent = "ForestRitual", e.folder
	Debris:AddItem(group, 23)
	local totem, health =
		actor(b, e, group, "forest_totem", at, { hp = cfg.totemHp, kind = "totem" })
	local roster = { "forest_shaman", "forest_explorer", "forest_skull", "forest_explorer" }
	e.adds = prune(e.adds)
	local count = if phase2 then cfg.phase2Count else cfg.count
	for i = 1, count do
		if #e.adds >= cfg.maxAlive or not Cast.Alive(b, s) then
			break
		end
		local angle = i * math.pi * 2 / count
		local point = ground(
			b,
			e,
			hooks,
			s.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 5,
			5.1,
			2
		)
		if point then
			summon(b, e, hooks, group, roster[i], point, cfg.adds[roster[i]])
		end
	end
	local marked, interrupted = false, false
	while Cast.Alive(b, s) and os.clock() < start + cfg.blastAt do
		if not totem.Parent or health.Health <= 0 then
			interrupted = true
			break
		end
		if not marked and os.clock() >= start + cfg.blastAt - cfg.warning then
			marked = true
			Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
			totem:SetAttribute("MobWindup", workspace:GetServerTimeNow())
		end
		RunService.Heartbeat:Wait()
	end
	if interrupted then
		for _, m in group:GetChildren() do
			local h = m:FindFirstChildOfClass("Humanoid")
			if h then
				h.Health = 0
			end
		end
		interrupt(b, s, hooks)
	elseif Cast.Alive(b, s) and health.Health > 0 then
		local supported = ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range + 0.1, 3)
		if supported then
			impact(b, e, hooks, at, cfg, {})
		end
		health.Health = 0
	end
	if totem.Parent and health.Health > 0 then
		health.Health = 0
	end
	Debris:AddItem(totem, 2.4)
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local d = b.fight.forestSpirit.spawnDuration
	local s = Cast.Begin(b, "spawn", d, 0, nil, hooks)
	task.delay(d, function()
		Cast.Finish(b, s)
	end)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	encounter(b)
	local cfg = b.fight.forestSpirit.melee
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
	local cfg = b.fight.forestSpirit[name]
	local s =
		Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.forestSpirit.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "attack8" then
			ritual(b, e, s, hooks, start, phase2, cfg)
		elseif name == "attack3" then
			local from = socket(b, name, cfg.release, "handL")
			local delta = target - from
			if delta.Magnitude > 0.01 and Cast.WaitUntil(b, s, start, cfg.release) then
				local seen = {}
				local count = if phase2 then cfg.phase2Count else cfg.count
				for i = 1, count do
					local dir = CFrame.Angles(0, math.rad((i - (count + 1) / 2) * cfg.spread), 0)
						:VectorToWorldSpace(delta.Unit)
					task.spawn(bolt, b, e, hooks, from, dir, cfg, seen)
				end
			end
		elseif name == "attack5" then
			local center = ground(b, e, hooks, s.root.Position, 1, cfg.radius)
			if center then
				local right = s.root.CFrame.RightVector
				for i = 0, 15 do
					local a = i * math.pi / 8
					local d = Vector3.new(math.cos(a), 0, math.sin(a))
					if d:Dot(right) < math.cos(math.rad(cfg.gapDegrees)) then
						local p = part(
							s.folder,
							"SeedWaveWarning",
							Vector3.new(0.5, 0.1, 1.2),
							CFrame.lookAt(center + d * cfg.radius, center + d * (cfg.radius + 1)),
							VIOLET
						)
						p.Transparency = 0.4
					end
				end
				if Cast.WaitUntil(b, s, start, cfg.release) then
					task.spawn(ring, b, e, hooks, center, right, cfg)
				end
			end
		elseif name == "attack6" then
			local health = b.humanoid.Health
			task.spawn(function()
				while Cast.Alive(b, s) do
					if health - b.humanoid.Health >= cfg.interruptDamage then
						interrupt(b, s, hooks)
						break
					end
					RunService.Heartbeat:Wait()
				end
			end)
			for _, t in cfg.waves do
				if not Cast.WaitUntil(b, s, start, t - cfg.warning) then
					break
				end
				local list = hooks.fighters(b)
				local aim = if #list > 0 then list[1].root.Position else target
				local points =
					targets(b, e, hooks, aim, cfg, if phase2 then cfg.phase2Count else cfg.count)
				for _, at in points do
					Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
				end
				if not Cast.WaitUntil(b, s, start, t) then
					break
				end
				local seen = {}
				for _, at in points do
					lightning(b, e, hooks, at, cfg, seen)
				end
			end
		else
			local count = if phase2 then cfg.phase2Count else cfg.count
			local points = targets(b, e, hooks, target, cfg, count)
			for _, at in points do
				Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local seen = {}
				for i, at in points do
					if
						name == "attack2"
						and not Cast.WaitUntil(b, s, start, cfg.release + (i - 1) * cfg.stagger)
					then
						break
					end
					if name == "attack4" then
						lightning(b, e, hooks, at, cfg, seen)
					else
						roots(b, e, hooks, at, cfg, seen, name == "attack2")
					end
				end
				if name == "attack4" and Cast.Alive(b, s) then
					-- Second strike locks the same initial lane; leaving it avoids both contacts.
					for _, at in points do
						Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
					end
					if Cast.WaitUntil(b, s, start, cfg.secondRelease) then
						local secondSeen = {}
						for _, at in points do
							lightning(b, e, hooks, at, cfg, secondSeen)
						end
					end
				end
			end
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
