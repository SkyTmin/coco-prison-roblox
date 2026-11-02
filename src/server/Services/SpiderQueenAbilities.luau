--!strict
-- Source-backed fang/web/add names; original vulnerable encounter mechanics.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local Cast = require(script.Parent.BossCast)
local Physics = require(script.Parent.BossPhysics)
local CollisionGroups = require(script.Parent.CollisionGroups)
local Needs = require(script.Parent.NeedsService)
local Shared = ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local Definition = require(Shared.Models.spider_queen) :: any
local Prepared = BlockRig.prepare(Definition)
local API = {}
local encounters: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local SILK, WARNING = Color3.fromRGB(173, 171, 151), Color3.fromRGB(134, 102, 63)
local NAMES = { "webattack", "fangattack", "broodcall" }
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
		folder.Name, folder.Parent = "SpiderQueenEncounter", workspace
		e = { root = b.root, folder = folder, spiders = {}, zones = {} }
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
local function overlap(at: Vector3, size: Vector3, ray: RaycastParams): boolean
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
	margin: number
): Vector3?
	if
		((target - b.root.Position) * FLAT).Magnitude > range
		or ((target - b.spawn.Position) * FLAT).Magnitude > b.arenaRadius - margin
	then
		return nil
	end
	local ray = Cast.Params(b, e, hooks)
	local hit = workspace:Raycast(target + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), ray)
	if not hit or hit.Normal.Y < 0.55 then
		return nil
	end
	local at = hit.Position + Vector3.new(0, 0.1, 0)
	local floor = Cast.FloorAt(b, b.root.Position, ray)
	if
		math.abs(at.Y - floor.Y) > 4
		or workspace:Raycast(b.root.Position, target - b.root.Position, ray)
		or workspace:Raycast(floor + Vector3.new(0, 0.6, 0), at - floor, ray)
		or overlap(at + Vector3.new(0, 1.2, 0), Vector3.new(1.2, 2, 1.2), ray)
	then
		return nil
	end
	return at
end
local function socket(b: any, clip: string, t: number, name: string): Vector3
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
			* BlockRig.sample(Prepared.clips[clip], j.name, t)
		if j.name == name then
			return worlds[j.name].Position
		end
	end
	return origin.Position
end
local function sight(b: any, e: any, hooks: any, f: any, from: Vector3): boolean
	return f.root.Parent ~= nil
		and f.humanoid.Health > 0
		and workspace:Raycast(from, f.root.Position - from, Cast.Params(b, e, hooks)) == nil
end
local function web(b: any, e: any, hooks: any, at: Vector3, cfg: any, seen: any)
	if not living(b, e) then
		return
	end
	local zones = {}
	for _, zone in e.zones do
		if zone.Parent then
			table.insert(zones, zone)
		end
	end
	while #zones >= cfg.maxZones do
		table.remove(zones, 1):Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "QueenWeb", e.folder
	table.insert(zones, folder)
	e.zones = zones
	local beams = {}
	local function strand(a: Vector3, z: Vector3)
		local mid, length = (a + z) / 2, (z - a).Magnitude
		local cf = CFrame.lookAt(mid, z)
		local p = part(
			folder,
			"SilkStrand",
			Vector3.new(0.1, 0.07, length * 0.12),
			CFrame.new(at:Lerp(mid, 0.12)) * cf.Rotation,
			SILK
		)
		p.Transparency = 0.7
		TweenService:Create(
			p,
			TweenInfo.new(cfg.grow),
			{ CFrame = cf, Size = Vector3.new(0.1, 0.07, length), Transparency = 0.22 }
		):Play()
		table.insert(beams, p)
	end
	for i = 0, 7 do
		local angle, nextAngle = i * math.pi / 4, (i + 1) * math.pi / 4
		local a, z =
			Vector3.new(math.cos(angle), 0, math.sin(angle)),
			Vector3.new(math.cos(nextAngle), 0, math.sin(nextAngle))
		strand(at, at + a * cfg.radius)
		for _, scale in { 0.48, 0.94 } do
			strand(at + a * cfg.radius * scale, at + z * cfg.radius * scale)
		end
	end
	Debris:AddItem(folder, cfg.grow + cfg.lifetime + cfg.fade + 0.2)
	for _, f in hooks.fighters(b) do
		if
			not seen[f.humanoid]
			and ((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
			and math.abs(f.root.Position.Y - at.Y) < 6
			and sight(b, e, hooks, f, at + Vector3.new(0, 1.5, 0))
		then
			if hooks.hurt(b, f, cfg.damage, at, 0.3, 0) ~= false then
				seen[f.humanoid] = true
			end
		end
	end
	task.wait(cfg.grow)
	local ends = os.clock() + cfg.lifetime
	while living(b, e) and folder.Parent and os.clock() < ends do
		for _, f in hooks.fighters(b) do
			if
				((f.root.Position - at) * FLAT).Magnitude <= cfg.radius
				and math.abs(f.root.Position.Y - at.Y) < 5
				and sight(b, e, hooks, f, at + Vector3.new(0, 1.5, 0))
			then
				if hooks.snare then
					hooks.snare(f, cfg.slowLevel, cfg.slowSeconds)
				else
					local player = Players:GetPlayerFromCharacter(f.player.Character)
					if player and not player:GetAttribute("Creative") then
						Needs.GiveEffect(player, "slowness", cfg.slowLevel, cfg.slowSeconds)
					end
				end
			end
		end
		task.wait(0.25)
	end
	if folder.Parent then
		for _, p in beams do
			TweenService:Create(p, TweenInfo.new(cfg.fade), { Transparency = 1 }):Play()
		end
		Debris:AddItem(folder, cfg.fade)
	end
end
local function silkBall(b: any, e: any, hooks: any, target: Vector3, cfg: any, seen: any)
	local ray = Cast.Params(b, e, hooks)
	local from = socket(b, "webattack", cfg.release, "spinnerL")
	if
		workspace:Raycast(b.root.Position, from - b.root.Position, ray)
		or overlap(from, Vector3.one * 0.5, ray)
	then
		return
	end
	local to = target + Vector3.new(0, 0.4, 0)
	local p = part(e.folder, "SilkBall", Vector3.one * 0.65, CFrame.new(from), SILK)
	Debris:AddItem(p, cfg.flight + 0.1)
	local start, previous, arrived = os.clock(), from, false
	while living(b, e) and p.Parent do
		local u = math.clamp((os.clock() - start) / cfg.flight, 0, 1)
		local point = from:Lerp(to, u) + Vector3.new(0, cfg.arc * 4 * u * (1 - u), 0)
		local step = point - previous
		if
			(step.Magnitude > 0.001 and workspace:Spherecast(previous, 0.25, step, ray))
			or overlap(point, Vector3.one * 0.4, ray)
		then
			break
		end
		p.CFrame = CFrame.new(point) * CFrame.Angles(u * 8, u * 5, u * 7)
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
		and ground(b, e, hooks, target + Vector3.new(0, 2, 0), cfg.range + 1, cfg.radius)
	then
		task.spawn(web, b, e, hooks, target, cfg, seen)
	end
end
local function spider(b: any, e: any, hooks: any, at: Vector3, cfg: any)
	local model = Instance.new("Model")
	model.Name = "HuntsmanSpider"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency, root.Anchored =
		"HumanoidRootPart", Vector3.new(1.6, 1.8, 2), 1, true
	root.CFrame, root.Parent = CFrame.new(at + Vector3.new(0, 0.9, 0)), model
	BlockRig.build(
		require(Shared.Models.huntsman_spider),
		model,
		root,
		root.CFrame * CFrame.new(0, -0.9, 0),
		b.fight.texture
	)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = cfg.hp, cfg.hp, 0, 0
	h.DisplayDistanceType, h.Parent = Enum.HumanoidDisplayDistanceType.None, model
	model.PrimaryPart, model.ModelStreamingMode = root, Enum.ModelStreamingMode.Atomic
	model:SetAttribute("MobId", "huntsman_spider")
	model:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	CollisionGroups.mob(model)
	model.Parent = e.folder
	CollectionService:AddTag(model, "Mob")
	table.insert(e.spiders, model)
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
					and sight(b, e, hooks, target, root.Position)
				then
					hooks.hurt(b, target, cfg.damage, root.Position, 0.2, 0)
				end
			end
			task.wait(0.15)
		end
		die()
	end)
end
function API.Spawn(b: any, hooks: any)
	encounter(b)
	local duration = b.fight.spiderQueen.spawnDuration
	local s = Cast.Begin(b, "spawn", duration, 0, nil, hooks)
	task.delay(duration, function()
		Cast.Finish(b, s)
	end)
end
function API.Melee(b: any, target: Vector3, hooks: any)
	encounter(b)
	b.spiderMelee = (b.spiderMelee or 0) % #b.fight.spiderQueen.melee + 1
	local cfg = b.fight.spiderQueen.melee[b.spiderMelee]
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
	local cfg = b.fight.spiderQueen[name]
	local s =
		Cast.Begin(b, name, cfg.duration, cfg.release, target, hooks, b.fight.spiderQueen.recovery)
	task.spawn(function()
		local start = os.clock()
		if name == "fangattack" then
			local center = s.root.Position + s.root.CFrame.LookVector * 5
			Cast.Mark(b, s, hooks, center, 4, WARNING)
			if Cast.WaitUntil(b, s, start, cfg.release) then
				Cast.Hit(b, s, hooks, s.root.Position, cfg, cfg.damage)
				Cast.Pulse(e, Cast.FloorAt(b, center, Cast.Params(b, e, hooks)), 3, WARNING)
			end
		elseif name == "webattack" then
			local points, targets = {}, { target }
			if phase2 then
				for _, f in hooks.fighters(b) do
					if ((f.root.Position - target) * FLAT).Magnitude > cfg.radius * 2 then
						table.insert(targets, f.root.Position)
					end
					if #targets >= cfg.phase2Count then
						break
					end
				end
			end
			for _, goal in targets do
				local at = ground(b, e, hooks, goal, cfg.range, cfg.radius)
				if at then
					table.insert(points, at)
					Cast.Mark(b, s, hooks, at, cfg.radius, SILK)
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local seen = {}
				for _, at in points do
					if ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range, cfg.radius) then
						task.spawn(silkBall, b, e, hooks, at, cfg, seen)
					end
				end
			end
		else
			local count = if phase2 then cfg.phase2Count else cfg.count
			local points = {}
			for i = 1, count do
				local angle = i * math.pi * 2 / count
				local at = ground(
					b,
					e,
					hooks,
					s.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * cfg.range,
					cfg.range + 0.1,
					3
				)
				if at then
					table.insert(points, at)
					Cast.Mark(b, s, hooks, at, 1.7, WARNING)
				end
			end
			if Cast.WaitUntil(b, s, start, cfg.release) then
				local survivors = {}
				for _, m in e.spiders do
					local h = m:FindFirstChildOfClass("Humanoid")
					if m.Parent and h and h.Health > 0 then
						table.insert(survivors, m)
					end
				end
				e.spiders = survivors
				for _, at in points do
					if not Cast.Alive(b, s) or #e.spiders >= cfg.maxAlive then
						break
					end
					if ground(b, e, hooks, at + Vector3.new(0, 2, 0), cfg.range + 0.1, 3) then
						spider(b, e, hooks, at, cfg)
						task.wait()
					end
				end
			end
		end
		Cast.EndAfter(b, s, start, cfg.duration)
	end)
end
return API
