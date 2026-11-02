--!strict
-- Audited necromancy names; original killable summons and readable, always-vulnerable casts.
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local Definition = require(Shared.Models.undead_king) :: any
local Prepared = BlockRig.prepare(Definition)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local PEARL, VIOLET = Color3.fromRGB(192, 192, 179), Color3.fromRGB(117, 108, 142)
local NAMES = { "skill3", "skill2", "swordcall", "skill1" }
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
		folder.Name, folder.Parent = "UndeadKingEncounter", workspace
		e = { root = b.root, folder = folder, ghouls = {}, skulls = {} }
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
local function meteor(
	b: any,
	e: any,
	hooks: any,
	at: Vector3,
	cfg: any,
	seen: any,
	origin: Vector3?
)
	if not living(b, e) then
		return
	end
	local ray = Cast.Params(b, e, hooks)
	local to = at + Vector3.new(0, 0.5, 0)
	local from = origin
	if not from then
		local ceiling = workspace:Raycast(to, Vector3.new(0, cfg.height, 0), ray)
		local height = if ceiling then math.max(0, ceiling.Distance - 0.7) else cfg.height
		if height < 3 then
			return
		end
		from = to + Vector3.new(0, height, 0)
	elseif workspace:Raycast(b.root.Position, from - b.root.Position, ray) then
		return
	end
	local startPoint = from :: Vector3
	if overlap(CFrame.new(startPoint), Vector3.one * 0.7, ray) then
		return
	end
	local p = part(e.folder, "SoulMeteor", Vector3.one * 0.8, CFrame.new(startPoint), PEARL)
	Debris:AddItem(p, cfg.flight + 1)
	local start, previous, arrived = os.clock(), startPoint, false
	while living(b, e) and p.Parent do
		local u = math.clamp((os.clock() - start) / cfg.flight, 0, 1)
		local point = startPoint:Lerp(to, u * u)
		local delta = point - previous
		if
			(delta.Magnitude > 0.001 and workspace:Spherecast(previous, 0.3, delta, ray))
			or overlap(CFrame.new(point), Vector3.one * 0.5, ray)
		then
			break
		end
		p.CFrame = CFrame.new(point) * CFrame.Angles(u * 6, u * 4, u * 9)
		if u >= 1 then
			arrived = true
			break
		end
		previous = point
		RunService.Heartbeat:Wait()
	end
	p:Destroy()
	if
		arrived
		and living(b, e)
		and ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range + 1, cfg.radius)
	then
		impact(b, e, hooks, at, cfg, seen)
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
		part(e.folder, "DarkMissile", Vector3.new(0.55, 0.55, 1.2), CFrame.new(origin), VIOLET)
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
local function ghoul(b: any, e: any, hooks: any, at: Vector3, cfg: any)
	local model = Instance.new("Model")
	model.Name = "UndeadGhoul"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.new(1.2, 3.2, 1), 1, true
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, 1.6, 0)), model
	BlockRig.build(
		require(Shared.Models.undead_ghoul),
		model,
		root,
		root.CFrame * CFrame.new(0, -1.6, 0),
		b.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 0
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart, model.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	model:SetAttribute("MobId", "undead_ghoul")
	model:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	CollisionGroups.mob(model)
	model.Parent = e.folder
	CollectionService:AddTag(model, "Mob")
	table.insert(e.ghouls, model)
	Debris:AddItem(model, cfg.spawnDuration + cfg.lifetime + 2.2)
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
		Debris:AddItem(model, 2)
	end
	h.Died:Once(die)
	task.spawn(function()
		task.wait(cfg.spawnDuration)
		if not living(b, e) or not model.Parent or h.Health <= 0 then
			die()
			return
		end
		Physics.restore(root, false)
		h.WalkSpeed = cfg.speed
		local expires, nextHit = os.clock() + cfg.lifetime, 0
		while
			living(b, e)
			and model.Parent
			and root:IsDescendantOf(workspace)
			and h.Health > 0
			and os.clock() < expires
		do
			local target, distance = nil, math.huge
			for _, f in hooks.fighters(b) do
				local d = (f.root.Position - root.Position).Magnitude
				if f.humanoid.Health > 0 and d < distance then
					target, distance = f, d
				end
			end
			if
				not target
				or ((root.Position - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius
			then
				break
			end
			local goal = target.root.Position
			local away = (goal - b.spawn.Position) * FLAT
			if away.Magnitude > b.arenaRadius - 3 then
				goal = Vector3.new(b.spawn.Position.X, goal.Y, b.spawn.Position.Z)
					+ away.Unit * (b.arenaRadius - 3)
			end
			h:MoveTo(goal)
			if distance <= cfg.reach and os.clock() >= nextHit then
				nextHit = os.clock() + cfg.cooldown
				Physics.face(root, target.root.Position)
				model:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				task.wait(cfg.hitAt)
				if
					living(b, e)
					and model.Parent
					and h.Health > 0
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
			task.wait(0.15)
		end
		die()
	end)
end
local function skull(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	local model = Instance.new("Model")
	model.Name = "UndeadSkull"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.one * 1.4, 1, true
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, 3.4, 0)), model
	BlockRig.build(
		require(Shared.Models.undead_skull),
		model,
		root,
		root.CFrame * CFrame.new(0, -0.8, 0),
		b.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath, h.AutoRotate = false, false, false
	h.MaxHealth, h.Health, h.WalkSpeed = cfg.hp, cfg.hp, 0
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart, model.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	model:SetAttribute("MobId", "undead_skull")
	CollisionGroups.mob(model)
	model.Parent = e.folder
	CollectionService:AddTag(model, "Mob")
	table.insert(e.skulls, model)
	Debris:AddItem(model, cfg.lifetime + cfg.fuse + 2.2)
	local stopped = false
	local function die()
		if stopped or not model.Parent then
			return
		end
		stopped = true
		if h.Health > 0 then
			h.Health = 0
		end
		local ray = Cast.Params(b, e, hooks)
		local floor = workspace:Raycast(root.Position, Vector3.new(0, -15, 0), ray)
		if floor then
			local from = root.CFrame
			local to = CFrame.new(floor.Position + Vector3.new(0, 0.8, 0)) * from.Rotation
			task.spawn(function()
				local start = os.clock()
				while living(b, e) and model.Parent do
					local u = math.clamp((os.clock() - start) / 1.2, 0, 1)
					root.CFrame = from:Lerp(to, u * u * (3 - 2 * u))
					if u >= 1 then
						break
					end
					RunService.Heartbeat:Wait()
				end
			end)
		end
		Debris:AddItem(model, 2)
	end
	h.Died:Once(die)
	task.spawn(function()
		local expires = os.clock() + cfg.lifetime
		local previousTime = os.clock()
		local ray = Cast.Params(b, e, hooks)
		while living(b, e) and model.Parent and h.Health > 0 and os.clock() < expires do
			local target, distance = nil, math.huge
			for _, f in hooks.fighters(b) do
				local d = (f.root.Position - root.Position).Magnitude
				if f.root.Parent and f.humanoid.Health > 0 and d < distance then
					target, distance = f, d
				end
			end
			if not target then
				break
			end
			local now = os.clock()
			local dt = math.min(0.1, now - previousTime)
			previousTime = now
			if distance <= cfg.trigger then
				local floor = ground(b, e, hooks, root.Position, 36, cfg.radius)
				if floor then
					model:SetAttribute("MobWindup", workspace:GetServerTimeNow())
					local mark = Cast.Mark(b, e, hooks, floor, cfg.radius, VIOLET)
					local armedAt = os.clock()
					while
						living(b, e)
						and model.Parent
						and h.Health > 0
						and os.clock() < armedAt + cfg.fuse
					do
						RunService.Heartbeat:Wait()
					end
					mark:Destroy()
					if
						living(b, e)
						and model.Parent
						and h.Health > 0
						and ground(b, e, hooks, floor + Vector3.new(0, 2, 0), 36, cfg.radius)
					then
						impact(b, e, hooks, floor, cfg, seen)
					end
				end
				break
			end
			local delta = target.root.Position - root.Position
			local step = delta.Unit * math.min(distance, cfg.speed * dt)
			local nextPoint = root.Position + step
			if
				((nextPoint - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - 2
				or overlap(CFrame.new(root.Position), Vector3.one * 1.2, ray)
				or (step.Magnitude > 0.001 and workspace:Spherecast(root.Position, 0.7, step, ray))
			then
				break
			end
			root.CFrame = CFrame.lookAt(nextPoint, nextPoint + delta.Unit)
			RunService.Heartbeat:Wait()
		end
		die()
	end)
end
local function sword(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	local ray = Cast.Params(b, e, hooks)
	if workspace:Raycast(at + Vector3.new(0, 0.2, 0), Vector3.new(0, cfg.clearance, 0), ray) then
		return
	end
	local model = Instance.new("Model")
	model.Name = "UndeadSword"
	local root = part(model, "PropRoot", Vector3.one, CFrame.new(at), PEARL)
	root.Transparency = 1
	BlockRig.build(require(Shared.Models.undead_sword), model, root, root.CFrame, b.fight.texture)
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanCollide, p.CanQuery, p.CanTouch = false, false, false
		end
	end
	model.PrimaryPart, model.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	model:SetAttribute("BlockModel", "undead_sword")
	model:SetAttribute("Action", "attack")
	model:SetAttribute("ActionAt", workspace:GetServerTimeNow())
	model:SetAttribute("ActionLen", cfg.lifetime)
	model.Parent = e.folder
	CollectionService:AddTag(model, "BossProp")
	local mark = Cast.Mark(b, e, hooks, at, cfg.radius, VIOLET)
	Debris:AddItem(mark, cfg.impactAt + 0.2)
	Debris:AddItem(model, cfg.lifetime)
	task.delay(cfg.impactAt, function()
		mark:Destroy()
		if
			living(b, e)
			and model.Parent
			and ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius)
			and not workspace:Raycast(
				at + Vector3.new(0, 0.2, 0),
				Vector3.new(0, cfg.clearance, 0),
				Cast.Params(b, e, hooks)
			)
		then
			impact(b, e, hooks, at, cfg, seen)
		end
	end)
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local d = b.fight.undeadKing.spawnDuration
	local s = Cast.Begin(b, "spawn", d, 0, nil, hooks)
	task.delay(d, function()
		Cast.Finish(b, s)
	end)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	encounter(b)
	b.undeadMelee = (b.undeadMelee or 0) % #b.fight.undeadKing.melee + 1
	local cfg = b.fight.undeadKing.melee[b.undeadMelee]
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
	local cfg = b.fight.undeadKing[name]
	local s =
		Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.undeadKing.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "skill3" then
			local from = socket(b, name, cfg.release, "handR")
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
		elseif name == "skill2" then
			local points = {}
			local count = if phase2 then cfg.phase2Count else cfg.count
			for i = 1, count do
				local offset = s.root.CFrame:VectorToWorldSpace(
					Vector3.new((i - (count + 1) / 2) * 3.5, 0, -4)
				)
				local at = ground(b, e, hooks, s.root.Position + offset, cfg.range, 2)
				if at then
					table.insert(points, at)
					Cast.Mark(b, s, hooks, at, 1.4, VIOLET)
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				e.skulls = prune(e.skulls)
				local seen = {}
				for _, at in points do
					if #e.skulls >= cfg.maxAlive then
						break
					end
					if ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, 2) then
						skull(b, e, hooks, at, cfg, seen)
					end
				end
			end
		else
			local points, summons = {}, {}
			local count = if phase2 then cfg.phase2Count else cfg.count
			for i = 1, count do
				local offset = if i == 1
					then Vector3.zero
					else s.root.CFrame.RightVector * (if i == 2 then 9 else -9)
				local at = ground(b, e, hooks, target + offset, cfg.range, cfg.radius)
				if at then
					table.insert(points, at)
					Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
				end
			end
			if name == "skill1" then
				local c = cfg.ghoul
				local total = if phase2 then c.phase2Count else c.count
				for i = 1, total do
					local a = i * math.pi * 2 / total
					local at = ground(
						b,
						e,
						hooks,
						s.root.Position + Vector3.new(math.cos(a), 0, math.sin(a)) * c.range,
						c.range + 0.1,
						2
					)
					if at then
						table.insert(summons, at)
						Cast.Mark(b, s, hooks, at, 1.3, PEARL)
					end
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local seen = {}
				for _, at in points do
					if ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius) then
						task.spawn(
							if name == "swordcall" then sword else meteor,
							b,
							e,
							hooks,
							at,
							cfg,
							seen
						)
					end
				end
				if name == "skill1" then
					e.ghouls = prune(e.ghouls)
					for _, at in summons do
						if not Cast.Alive(b, s) or #e.ghouls >= cfg.ghoul.maxAlive then
							break
						end
						if
							ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.ghoul.range + 0.1, 2)
						then
							ghoul(b, e, hooks, at, cfg.ghoul)
						end
					end
				end
			end
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
