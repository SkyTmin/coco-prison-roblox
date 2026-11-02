--!strict
-- Audited action names; original server-authoritative moon/meteor mechanics, always vulnerable.
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local Definition = require(Shared.Models.moth) :: any
local Prepared = BlockRig.prepare(Definition)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local PEARL, VIOLET = Color3.fromRGB(192, 192, 179), Color3.fromRGB(117, 108, 142)
local NAMES = { "shadowlight", "moonssight", "meteorrain", "midnight", "startshoot" }
local function living(b: any, e: any): boolean
	return encounters[b] == e
		and b.root == e.root
		and e.root:IsDescendantOf(workspace)
		and b.humanoid.Health > 0
end
local function land(b: any, e: any)
	local base = e.base
	e.base = nil
	if not base or not e.root:IsDescendantOf(workspace) then
		return
	end
	local root = e.root
	if b.humanoid and b.humanoid.Health <= 0 then
		local from = root.CFrame
		task.spawn(function()
			local start = os.clock()
			while root:IsDescendantOf(workspace) do
				local u = math.clamp((os.clock() - start) / 0.35, 0, 1)
				root.CFrame = from:Lerp(base, u * u * (3 - 2 * u))
				if u >= 1 then
					break
				end
				RunService.Heartbeat:Wait()
			end
		end)
	else
		root.CFrame = base
	end
end
function API.Clear(b: any)
	local e = encounters[b]
	encounters[b] = nil
	if e then
		land(b, e)
		e.folder:Destroy()
	end
	Cast.Clear(b)
end
local function encounter(b: any): any
	local e = encounters[b]
	if not e or not living(b, e) then
		API.Clear(b)
		local folder = Instance.new("Folder")
		folder.Name, folder.Parent = "MothEncounter", workspace
		e = { root = b.root, folder = folder }
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
	local p = part(e.folder, "MoonBolt", Vector3.new(0.55, 0.55, 1.2), CFrame.new(origin), VIOLET)
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
					"MidnightWave",
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
local function fly(b: any, e: any, s: any, target: Vector3, phase2: boolean, hooks: any, cfg: any)
	local base = s.root.CFrame
	local ray = Cast.Params(b, e, hooks)
	local box = base + Vector3.new(0, 1, 0)
	local size = Vector3.new(4.2, 9, 3)
	if
		not ground(b, e, hooks, base.Position, 1, 3)
		or overlap(box, size, ray)
		or workspace:Blockcast(box, size, Vector3.new(0, cfg.height, 0), ray)
	then
		Cast.Finish(b, s)
		return
	end
	e.base = base
	local count = if phase2 then cfg.phase2Count else cfg.count
	local total = cfg.duration + count * cfg.shotDuration + cfg.landDuration
	b.busyUntil = os.clock() + total
	b.nextAbilityAt = math.max(b.nextAbilityAt, b.busyUntil + b.fight.moth.recovery)
	local start, previousHP, damage = os.clock(), b.humanoid.Health, 0
	local function waitTo(seconds: number, height: (number) -> number): boolean
		while Cast.Alive(b, s) and living(b, e) and os.clock() < start + seconds do
			local hp = b.humanoid.Health
			damage += math.max(0, previousHP - hp)
			previousHP = hp
			if damage >= cfg.interruptDamage then
				land(b, e)
				Cast.Finish(b, s)
				local stunned =
					Cast.Begin(b, "stun", cfg.stunDuration, 0, nil, hooks, b.fight.moth.recovery)
				task.delay(cfg.stunDuration, function()
					Cast.Finish(b, stunned)
				end)
				return false
			end
			local y = height(os.clock() - start)
			-- A late ceiling/obstacle cancels the ascent instead of carrying the body through it.
			local desired = base + Vector3.new(0, y, 0)
			local step = desired.Position - s.root.Position
			if
				overlap(desired + Vector3.new(0, 1, 0), size, ray)
				or (
					step.Magnitude > 0.001
					and workspace:Blockcast(s.root.CFrame + Vector3.new(0, 1, 0), size, step, ray)
				)
			then
				land(b, e)
				Cast.Finish(b, s)
				return false
			end
			s.root.CFrame = desired
			RunService.Heartbeat:Wait()
		end
		return Cast.Alive(b, s) and living(b, e)
	end
	local function raised(t: number): number
		local u = math.clamp((t - 0.35) / 1, 0, 1)
		return cfg.height * u * u * (3 - 2 * u)
	end
	if not waitTo(cfg.duration, raised) then
		return
	end
	for i = 1, count do
		local at = ground(b, e, hooks, target, cfg.range, cfg.radius)
		if i > 1 then
			local fs = hooks.fighters(b)
			if fs[1] then
				at = ground(b, e, hooks, fs[1].root.Position, cfg.range, cfg.radius)
			end
		end
		hooks.act(b, "descendshot", cfg.shotDuration)
		if at then
			Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
		end
		local shotStart = cfg.duration + (i - 1) * cfg.shotDuration
		if not waitTo(shotStart + cfg.shotRelease, function()
			return cfg.height
		end) then
			return
		end
		if at then
			task.spawn(
				meteor,
				b,
				e,
				hooks,
				at,
				cfg,
				{},
				socket(b, "descendshot", cfg.shotRelease, "handR")
			)
		end
		if not waitTo(shotStart + cfg.shotDuration, function()
			return cfg.height
		end) then
			return
		end
	end
	hooks.act(b, "descendend", cfg.landDuration)
	local landAt = cfg.duration + count * cfg.shotDuration
	if
		not waitTo(total, function(t)
			local u = math.clamp((t - landAt) / cfg.landDuration, 0, 1)
			return cfg.height * (1 - u * u * (3 - 2 * u))
		end)
	then
		return
	end
	land(b, e)
	Cast.Finish(b, s)
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local d = b.fight.moth.spawnDuration
	local s = Cast.Begin(b, "spawn", d, 0, nil, hooks)
	task.delay(d, function()
		Cast.Finish(b, s)
	end)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	local e = encounter(b)
	land(b, e)
	b.mothMelee = (b.mothMelee or 0) % #b.fight.moth.melee + 1
	local cfg = b.fight.moth.melee[b.mothMelee]
	local s = Cast.Begin(b, cfg.name, cfg.duration, cfg.release, target, hooks)
	task.spawn(function()
		local t = os.clock()
		if Cast.WaitUntil(b, s, t, cfg.release) then
			Cast.Hit(b, s, hooks, s.root.Position, cfg, cfg.damage)
		end
		Cast.EndAfter(b, s, t, cfg.duration)
	end)
end
function API.Cast(b: any, index: number, target: Vector3, phase2: boolean, hooks: any)
	local e = encounter(b)
	land(b, e)
	local name = NAMES[(index - 1) % #NAMES + 1]
	local cfg = b.fight.moth[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.moth.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "startshoot" then
			fly(b, e, s, target, phase2, hooks, cfg)
			return
		end
		if name == "shadowlight" then
			local from = socket(b, name, cfg.release, "handR")
			local delta = target - from
			if delta.Magnitude > 0.01 and Cast.WaitUntil(b, s, start, cfg.release) then
				local count = if phase2 then cfg.phase2Count else cfg.count
				local seen = {}
				for i = 1, count do
					local dir = CFrame.Angles(0, math.rad((i - (count + 1) / 2) * cfg.spread), 0)
						:VectorToWorldSpace(delta.Unit)
					task.spawn(bolt, b, e, hooks, from, dir, cfg, seen)
				end
			end
		elseif name == "moonssight" then
			local root = s.root
			local floor = ground(b, e, hooks, root.Position, 1, 2)
			if floor then
				local ray = Cast.Params(b, e, hooks)
				local from = floor + Vector3.new(0, 0.35, 0)
				local direction = root.CFrame.LookVector
				local wall = workspace:Raycast(from, direction * cfg.range, ray)
				local length = if wall then math.max(0, wall.Distance - 0.2) else cfg.range
				local cf = CFrame.lookAt(floor, floor + direction) * CFrame.new(0, 0, -length / 2)
				local mark = hooks.telegraph(
					Vector3.new(cfg.width, 0.12, math.max(0.1, length)),
					cf,
					false,
					VIOLET
				)
				mark.Parent = s.folder
				if Cast.WaitUntil(b, s, start, cfg.release) then
					local lateWall = workspace:Raycast(from, direction * length, ray)
					if lateWall then
						length = math.max(0, lateWall.Distance - 0.2)
						cf = CFrame.lookAt(floor, floor + direction) * CFrame.new(0, 0, -length / 2)
					end
					local seen = {}
					local beam = part(
						e.folder,
						"MoonSight",
						Vector3.new(cfg.width, 0.3, math.max(0.1, length)),
						cf + Vector3.new(0, 0.25, 0),
						PEARL
					)
					TweenService:Create(beam, TweenInfo.new(0.35), { Transparency = 1 }):Play()
					Debris:AddItem(beam, 0.4)
					for _, f in hooks.fighters(b) do
						local q = root.CFrame:PointToObjectSpace(f.root.Position)
						if
							-q.Z >= 0
							and -q.Z <= length
							and math.abs(q.X) <= cfg.width / 2
							and math.abs(q.Y) < 6
						then
							hit(b, e, hooks, f, cfg.damage, from, seen)
						end
					end
				end
			end
		elseif name == "meteorrain" then
			local points = {}
			local count = if phase2 then cfg.phase2Count else cfg.count
			for i = 1, count do
				local offset = if i == 1
					then Vector3.zero
					else Vector3.new(
						math.cos((i - 2) * math.pi / 2) * 6,
						0,
						math.sin((i - 2) * math.pi / 2) * 6
					)
				local at = ground(b, e, hooks, target + offset, cfg.range, cfg.radius)
				if at then
					table.insert(points, at)
					Cast.Mark(b, s, hooks, at, cfg.radius, VIOLET)
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local seen = {}
				for _, at in points do
					if ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius) then
						task.spawn(meteor, b, e, hooks, at, cfg, seen)
					end
				end
			end
		else
			local center = ground(b, e, hooks, s.root.Position, 1, cfg.radius)
			if center then
				local right = s.root.CFrame.RightVector
				for i = 0, 15 do
					local a = i * math.pi / 8
					local d = Vector3.new(math.cos(a), 0, math.sin(a))
					if d:Dot(right) < math.cos(math.rad(cfg.gapDegrees)) then
						local p = part(
							s.folder,
							"MidnightWarning",
							Vector3.new(0.5, 0.1, 1.4),
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
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
