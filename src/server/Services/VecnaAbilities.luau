--!strict
-- Recovered tendril/flower/clock/portal families; original vulnerable encounter, Studio QA pending.
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
local COLOR = Color3.fromRGB(178, 94, 71)
local NAMES = { "attack2", "flower", "clockcast", "portalcast" }
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
		folder.Name, folder.Parent = "VecnaEncounter", workspace
		e = { root = b.root, folder = folder, adds = {} }
		encounters[b] = e
	end
	return e
end
local function part(parent: Instance, name: string, size: Vector3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, COLOR
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Parent = Enum.Material.SmoothPlastic, parent
	return p
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
local function lash(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if
		not living(b, e)
		or not ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius)
	then
		return
	end
	for i = 1, 4 do
		local a = i * math.pi / 2
		local point = at + Vector3.new(math.cos(a), 0, math.sin(a)) * cfg.radius * 0.55
		local p = part(e.folder, "TendrilLash", Vector3.new(0.24, 0.12, 0.24), CFrame.new(point))
		TweenService:Create(p, TweenInfo.new(0.14), {
			Size = Vector3.new(0.24, 2.5, 0.24),
			CFrame = CFrame.new(point + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0.16, a, 0.2),
		}):Play()
		Debris:AddItem(p, 0.9)
	end
	impact(b, e, hooks, at, cfg, seen)
end
local function wave(b: any, e: any, hooks: any, center: Vector3, right: Vector3, cfg: any)
	local pieces, seen = {}, {}
	local gap = math.cos(math.rad(cfg.gapDegrees))
	for i = 0, 23 do
		local a = i * math.pi / 12
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		if dir:Dot(right) < gap then
			table.insert(pieces, {
				dir = dir,
				part = part(e.folder, "TendrilWave", Vector3.new(0.4, 0.35, 1), CFrame.new(center)),
			})
		end
	end
	local start, previous, nextScan = os.clock(), 0, 0
	while living(b, e) do
		local radius = math.min(cfg.radius, (os.clock() - start) * cfg.speed)
		if os.clock() >= nextScan then
			nextScan = os.clock() + 0.15
			if not supported(b, e, hooks, center, cfg.radius) then
				break
			end
			for _, v in pieces do
				local wall = workspace:Raycast(
					center + Vector3.new(0, 0.35, 0),
					v.dir * cfg.radius,
					Cast.Params(b, e, hooks)
				)
				v.limit = if wall then wall.Distance else cfg.radius
			end
		end
		for _, v in pieces do
			local at = center + v.dir * radius
			v.part.CFrame, v.part.Size =
				CFrame.lookAt(at, at + v.dir),
				Vector3.new(math.max(0.1, radius * math.pi / 12), 0.35, cfg.width)
			v.part.Transparency = if radius > v.limit then 1 else 0
		end
		for _, f in hooks.fighters(b) do
			local offset = f.root.Position - center
			local delta = offset * FLAT
			local d = delta.Magnitude
			if
				d > 0.01
				and d >= previous - cfg.width / 2
				and d <= radius + cfg.width / 2
				and offset.Y >= -1
				and offset.Y <= cfg.jumpHeight
				and delta.Unit:Dot(right) < gap
				and not workspace:Raycast(
					center + Vector3.new(0, 0.35, 0),
					delta,
					Cast.Params(b, e, hooks)
				)
			then
				hit(b, e, hooks, f, cfg.damage, center + Vector3.new(0, 0.5, 0), seen)
			end
		end
		previous = radius
		if radius >= cfg.radius then
			break
		end
		RunService.Heartbeat:Wait()
	end
	for _, v in pieces do
		v.part:Destroy()
	end
end
local function actor(b: any, e: any, id: string, at: Vector3, cfg: any): (Model, Humanoid, BasePart)
	local m, root = Instance.new("Model"), Instance.new("Part")
	m.Name, m.ModelStreamingMode = id, Enum.ModelStreamingMode.Atomic
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.new(cfg.width, cfg.lift * 2, cfg.depth), 1, true
	root.CFrame, root.Parent =
		CFrame.new(at + Vector3.new(0, if cfg.flying then 3.5 else cfg.lift, 0)), m
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
		if cfg.flying then
			local ray = Cast.Params(b, e, hooks)
			local floorHit = workspace:Raycast(root.Position, Vector3.new(0, -20, 0), ray)
			if floorHit then
				local from = root.CFrame
				local to = CFrame.new(floorHit.Position + Vector3.new(0, cfg.lift, 0))
					* from.Rotation
				task.spawn(function()
					local start = os.clock()
					while living(b, e) and m.Parent do
						local u = math.clamp((os.clock() - start) / 0.9, 0, 1)
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
		if not cfg.flying then
			Physics.restore(root, false)
			h.WalkSpeed = cfg.speed
		end
		local expires, nextHit, previous = os.clock() + cfg.lifetime, 0, os.clock()
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
			local dt = math.min(0.15, now - previous)
			previous = now
			if distance > cfg.reach * 0.85 then
				if cfg.flying then
					local goal = Vector3.new(
						chosen.root.Position.X,
						math.clamp(
							chosen.root.Position.Y,
							b.spawn.Position.Y + 1,
							b.spawn.Position.Y + 7
						),
						chosen.root.Position.Z
					)
					local delta = goal - root.Position
					if delta.Magnitude > 0.01 then
						local step = delta.Unit * math.min(delta.Magnitude, cfg.speed * dt)
						local ray = Cast.Params(b, e, hooks)
						if
							occupied(root.Position, Vector3.one, ray)
							or workspace:Spherecast(root.Position, 0.6, step, ray)
						then
							break
						end
						root.CFrame =
							CFrame.lookAt(root.Position + step, root.Position + step + delta.Unit)
					end
				else
					h:MoveTo(chosen.root.Position)
				end
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
local function clock(b: any, e: any, hooks: any, at: Vector3, cfg: any)
	if e.clock and e.clock.Parent then
		return
	end
	local m, h, root = actor(b, e, "vecna_clock", at, cfg)
	e.clock = m
	local marker = mark(b, e, hooks, at, cfg.radius)
	Debris:AddItem(m, cfg.lifetime + cfg.deathDuration + 1)
	Debris:AddItem(marker, cfg.lifetime + 0.2)
	task.spawn(function()
		local expires = os.clock() + cfg.lifetime
		while living(b, e) and m.Parent and h.Health > 0 and os.clock() < expires do
			-- Destroying its support cancels the curse as well as destroying the clock.
			if not supported(b, e, hooks, at, cfg.radius) then
				break
			end
			task.wait(0.15)
		end
		if
			living(b, e)
			and m.Parent
			and h.Health > 0
			and os.clock() >= expires
			and supported(b, e, hooks, at, cfg.radius)
		then
			impact(b, e, hooks, at, cfg, {})
		end
		marker:Destroy()
		if m.Parent then
			root.Anchored = true
			root.CanCollide = false
			if h.Health > 0 then
				h.Health = 0
			end
			Debris:AddItem(m, cfg.deathDuration)
		end
	end)
end
local function portal(b: any, e: any, s: any, hooks: any, start: number, cfg: any, phase2: boolean)
	local at = ground(b, e, hooks, b.root.Position + b.root.CFrame.RightVector * 6, 8, 4)
	if not at then
		return
	end
	local ray = Cast.Params(b, e, hooks)
	if occupied(at + Vector3.new(0, 2.8, 0), Vector3.new(4.7, 5.4, 1.2), ray) then
		return
	end
	local m, root = Instance.new("Model"), Instance.new("Part")
	m.Name, m.ModelStreamingMode = "VecnaPortal", Enum.ModelStreamingMode.Atomic
	root.Name, root.Size, root.Transparency, root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch =
		"HumanoidRootPart", Vector3.one, 1, true, false, false, false
	root.CFrame, root.Parent = CFrame.new(at), m
	BlockRig.build(require(Shared.Models.vecna_portal), m, root, root.CFrame, b.fight.texture)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CanQuery = false
		end
	end
	m.PrimaryPart = root
	m:SetAttribute("BlockModel", "vecna_portal")
	m:SetAttribute("Action", "spawn")
	m:SetAttribute("ActionAt", workspace:GetServerTimeNow())
	m:SetAttribute("ActionLen", 1)
	m.Parent = s.folder
	CollectionService:AddTag(m, "BossProp")
	local closing = false
	local function closePortal()
		if closing or not m.Parent or not living(b, e) then
			return
		end
		closing = true
		m.Parent = e.folder
		m:SetAttribute("Action", "close")
		m:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		m:SetAttribute("ActionLen", 23 / 30)
		Debris:AddItem(m, 23 / 30)
	end
	local initial = b.humanoid.Health
	task.spawn(function()
		while Cast.Alive(b, s) and m.Parent do
			if initial - b.humanoid.Health >= cfg.interruptDamage then
				closePortal()
				Cast.Clear(b)
				local stopped = Cast.Begin(b, "stun", 1, 0, nil, hooks, b.fight.vecna.recovery)
				task.delay(1, function()
					Cast.Finish(b, stopped)
				end)
				break
			end
			RunService.Heartbeat:Wait()
		end
	end)
	local roster = { "vecna_stalker", "vecna_hound", "vecna_bat" }
	for i = 1, if phase2 then cfg.phase2Count else cfg.count do
		if not Cast.WaitUntil(b, s, start, cfg.release + (i - 1) * cfg.stagger) then
			break
		end
		if not ground(b, e, hooks, at + Vector3.new(0, 2, 0), 9, 4) then
			break
		end
		local alive = {}
		for _, old in e.adds do
			local h = old:FindFirstChildOfClass("Humanoid")
			if old.Parent and h and h.Health > 0 then
				table.insert(alive, old)
			end
		end
		e.adds = alive
		if #alive >= cfg.maxAlive then
			break
		end
		local id = roster[i]
		local actorCfg = cfg.adds[id]
		local point = ground(b, e, hooks, at + Vector3.new((i - 2) * 2.8, 2, -2), 13, 2)
		if
			point
			and not occupied(
				point + Vector3.new(0, actorCfg.lift + 0.1, 0),
				Vector3.new(actorCfg.width + 0.3, actorCfg.lift * 2, actorCfg.depth + 0.3),
				ray
			)
		then
			summon(b, e, hooks, id, point, actorCfg)
		end
	end
	if Cast.WaitUntil(b, s, start, cfg.duration - 23 / 30) then
		closePortal()
	end
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local duration = b.fight.vecna.spawnDuration
	local s = Cast.Begin(b, "spawn", duration, 0, nil, hooks)
	task.spawn(Cast.EndAfter, b, s, os.clock(), duration)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	encounter(b)
	local cfg = b.fight.vecna.melee
	local s = Cast.Begin(b, "attack1", cfg.duration, cfg.release, target, hooks)
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
	local cfg = b.fight.vecna[name]
	local s = Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.vecna.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "attack2" then
			local points = {}
			local count = if phase2 then cfg.phase2Count else cfg.count
			for i = 1, count do
				local point = ground(
					b,
					e,
					hooks,
					target + b.root.CFrame.RightVector * (i - (count + 1) / 2) * cfg.spacing,
					cfg.range,
					cfg.radius
				)
				if point then
					table.insert(points, point)
					mark(b, s, hooks, point, cfg.radius)
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local seen = {}
				for _, point in points do
					lash(b, e, hooks, point, cfg, seen)
				end
			end
		elseif name == "flower" then
			local center = ground(b, e, hooks, b.root.Position, 1, cfg.radius)
			local right = b.root.CFrame.RightVector
			if center then
				for i = 0, 15 do
					local a = i * math.pi / 8
					local dir = Vector3.new(math.cos(a), 0, math.sin(a))
					if dir:Dot(right) < math.cos(math.rad(cfg.gapDegrees)) then
						part(
							s.folder,
							"FlowerWarning",
							Vector3.new(0.7, 0.1, 1.2),
							CFrame.lookAt(
								center + dir * cfg.radius,
								center + dir * (cfg.radius + 1)
							)
						)
					end
				end
				if Cast.WaitUntil(b, s, start, cfg.release) then
					task.spawn(wave, b, e, hooks, center, right, cfg)
				end
			end
		elseif name == "clockcast" then
			local point = ground(b, e, hooks, target, cfg.range, cfg.radius)
			if
				point
				and not occupied(
					point + Vector3.new(0, 2.5, 0),
					Vector3.new(2, 4.8, 1.3),
					Cast.Params(b, e, hooks)
				)
			then
				mark(b, s, hooks, point, 1.3)
				if
					Cast.WaitUntil(b, s, start, cfg.release)
					and ground(b, e, hooks, point + Vector3.new(0, 2, 0), cfg.range, cfg.radius)
					and not occupied(
						point + Vector3.new(0, 2.5, 0),
						Vector3.new(2, 4.8, 1.3),
						Cast.Params(b, e, hooks)
					)
				then
					clock(b, e, hooks, point, cfg)
				end
			end
		else
			portal(b, e, s, hooks, start, cfg, phase2)
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
