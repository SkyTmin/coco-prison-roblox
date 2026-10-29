--!strict
-- Original gameplay for the five Splinter clips listed in RESOURCEPACK-BOSSES.md.
-- The audit gives names/durations, not damage or mechanics: those are decisions in Config.bosses.
-- Every cast owns a boss-generation token; death cancels delayed hits, projectiles and temporary adds.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local BlockRig = require(ReplicatedStorage.Shared.BlockRig)
local CollisionGroups = require(script.Parent.CollisionGroups)

local SplinterAbilities = {}
local GREEN = Color3.fromRGB(113, 163, 63)
local sessions: { [any]: any } = {}

function SplinterAbilities.Clear(boss: any)
	local session = sessions[boss]
	if session then
		sessions[boss] = nil
		session.folder:Destroy()
	end
end

local function sessionFor(boss: any): any
	local session = sessions[boss]
	if session and session.model == boss.model then
		return session
	end
	SplinterAbilities.Clear(boss)
	local folder = Instance.new("Folder")
	folder.Name = "SplinterEffects"
	folder.Parent = workspace
	session = { model = boss.model, root = boss.root, folder = folder, spiders = {} }
	sessions[boss] = session
	return session
end

local function alive(boss: any, session: any): boolean
	return sessions[boss] == session
		and boss.model == session.model
		and session.model.Parent ~= nil
		and boss.humanoid ~= nil
		and boss.humanoid.Health > 0
end

local function part(session: any, name: string, size: Vector3, color: Color3, cf: CFrame): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color, p.CFrame = name, size, color, cf
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.Material = Enum.Material.SmoothPlastic
	p.Parent = session.folder
	Debris:AddItem(p, 20)
	return p
end

local function rayParams(boss: any, session: any, hooks: any): RaycastParams
	local exclude: { Instance } = { session.model, session.folder }
	for _, f in ipairs(hooks.fighters(boss)) do
		if f.player.Character then
			table.insert(exclude, f.player.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.RespectCanCollide = true
	return params
end

local function flat(v: Vector3): Vector3
	return v * Vector3.new(1, 0, 1)
end

local function direction(from: Vector3, target: Vector3, fallback: Vector3): Vector3
	local delta = flat(target - from)
	return if delta.Magnitude > 0.01 then delta.Unit else fallback
end

local function inArena(boss: any, target: Vector3): Vector3
	local delta = flat(target - boss.spawn.Position)
	local limit = math.max(1, boss.arenaRadius - 5)
	if delta.Magnitude > limit then
		return boss.spawn.Position + delta.Unit * limit
	end
	return target
end

local function ground(boss: any, target: Vector3, params: RaycastParams): Vector3
	local hit = workspace:Raycast(target + Vector3.new(0, 10, 0), Vector3.new(0, -35, 0), params)
	return if hit
		then hit.Position + Vector3.new(0, 0.12, 0)
		else Vector3.new(
			target.X,
			boss.spawn.Position.Y + boss.spawn.Size.Y / 2 + 0.12,
			target.Z
		)
end

local function nearSegment(point: Vector3, a: Vector3, b: Vector3): number
	local ab = b - a
	local t = if ab.Magnitude > 0.001 then math.clamp((point - a):Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (point - (a + ab * t)).Magnitude
end

local function face(root: BasePart, dir: Vector3)
	root.CFrame = CFrame.lookAt(root.Position, root.Position + dir)
end

local function swoop(boss: any, session: any, target: Vector3, hooks: any)
	local cfg = boss.fight.splinter.swoop
	local root = session.root
	local from = root.Position
	target = inArena(boss, target)
	local dir = direction(from, target, root.CFrame.LookVector)
	face(root, dir)
	local length = math.min(cfg.distance, flat(target - from).Magnitude)
	local params = rayParams(boss, session, hooks)
	local obstruction = workspace:Spherecast(from, 2, dir * math.max(length, 0.01), params)
	if obstruction then
		length = math.max(0, obstruction.Distance - 0.4)
	end
	local mark = hooks.telegraph(
		Vector3.new(cfg.radius * 2, 0.18, math.max(1, length)),
		CFrame.lookAt(
			ground(boss, from + dir * length / 2, params),
			ground(boss, from + dir * length / 2, params) + dir
		),
		false
	)
	mark.Parent = session.folder
	Debris:AddItem(mark, cfg.duration)
	task.wait(cfg.windup)
	mark:Destroy()
	if not alive(boss, session) then
		return
	end
	local anchored = root.Anchored
	root.Anchored = true
	local started, previous, hit = os.clock(), from, {}
	while alive(boss, session) do
		local alpha = math.min(1, (os.clock() - started) / cfg.travel)
		local nextPosition = from + dir * length * alpha
		local blocked =
			workspace:Spherecast(previous, 2, nextPosition - previous + dir * 0.001, params)
		if blocked then
			break
		end
		root.CFrame = CFrame.lookAt(nextPosition, nextPosition + dir)
		for _, f in ipairs(hooks.fighters(boss)) do
			if
				not hit[f.player]
				and nearSegment(f.root.Position, previous, nextPosition) <= cfg.radius
			then
				hit[f.player] = true
				hooks.hurt(boss, f, cfg.damage, from)
			end
		end
		previous = nextPosition
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if alive(boss, session) then
		root.Anchored = anchored
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function poison(
	boss: any,
	session: any,
	at: Vector3,
	cfg: any,
	hooks: any,
	params: RaycastParams
)
	if not alive(boss, session) then
		return
	end
	local pool = part(
		session,
		"SplinterPoison",
		Vector3.new(0.12, cfg.radius * 2, cfg.radius * 2),
		GREEN,
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2)
	)
	pool.Shape, pool.Transparency = Enum.PartType.Cylinder, 0.45
	for _ = 1, cfg.ticks do
		if not alive(boss, session) then
			break
		end
		for _, f in ipairs(hooks.fighters(boss)) do
			local delta = f.root.Position - at
			if
				flat(delta).Magnitude <= cfg.radius
				and math.abs(delta.Y) <= 6
				and not workspace:Raycast(
					at + Vector3.new(0, 0.5, 0),
					f.root.Position - at - Vector3.new(0, 0.5, 0),
					params
				)
			then
				hooks.hurt(boss, f, cfg.damage / cfg.ticks, at)
			end
		end
		task.wait(cfg.tickInterval)
	end
	pool:Destroy()
end

local function potion(boss: any, session: any, target: Vector3, hooks: any)
	local cfg = boss.fight.splinter.potion
	local root = session.root
	local params = rayParams(boss, session, hooks)
	local dir = direction(root.Position, target, root.CFrame.LookVector)
	face(root, dir)
	local landing = inArena(
		boss,
		root.Position + dir * math.min(cfg.range, flat(target - root.Position).Magnitude)
	)
	landing = ground(boss, landing, params)
	local mark = hooks.telegraph(
		Vector3.new(cfg.radius * 2, 0.18, cfg.radius * 2),
		CFrame.new(landing),
		true,
		GREEN
	)
	mark.Parent = session.folder
	Debris:AddItem(mark, cfg.duration)
	task.wait(cfg.release)
	if not alive(boss, session) then
		mark:Destroy()
		return
	end
	local from = root.Position + dir * 2 + Vector3.new(0, 2, 0)
	local launchWall = workspace:Raycast(root.Position, from - root.Position, params)
	if launchWall then
		mark:Destroy()
		poison(
			boss,
			session,
			ground(boss, launchWall.Position - dir * 0.5, params),
			cfg,
			hooks,
			params
		)
		return
	end
	local vial =
		part(session, "SplinterBottle", Vector3.new(0.6, 0.85, 0.6), GREEN, CFrame.new(from))
	local cork = part(
		session,
		"Cork",
		Vector3.new(0.3, 0.2, 0.3),
		Color3.fromRGB(159, 119, 66),
		CFrame.new(from)
	)
	local started, previous = os.clock(), from
	while alive(boss, session) do
		local alpha = math.min(1, (os.clock() - started) / (cfg.duration - cfg.release))
		local p = from:Lerp(landing, alpha) + Vector3.new(0, math.sin(alpha * math.pi) * 5, 0)
		local hit = workspace:Raycast(previous, p - previous, params)
		if hit then
			local back = if (p - previous).Magnitude > 0.01
				then (p - previous).Unit * 0.4
				else Vector3.zero
			landing = ground(boss, hit.Position - back, params)
			break
		end
		vial.CFrame = CFrame.new(p) * CFrame.Angles(alpha * math.pi * 2, 0, 0)
		cork.CFrame = vial.CFrame * CFrame.new(0, 0.5, 0)
		previous = p
		if alpha >= 1 then
			break
		end
		RunService.Heartbeat:Wait()
	end
	vial:Destroy()
	cork:Destroy()
	mark:Destroy()
	poison(boss, session, landing, cfg, hooks, params)
end

local function shoot(boss: any, session: any, target: Vector3, hooks: any)
	local cfg = boss.fight.splinter.shoot
	local root = session.root
	local dir = direction(root.Position, target, root.CFrame.LookVector)
	face(root, dir)
	local params = rayParams(boss, session, hooks)
	local from = root.Position + dir * 3.7 + Vector3.new(0, 0.65, 0)
	local delta = target - from
	local aim = if delta.Magnitude > 0.1 then delta.Unit else dir
	local floor = ground(boss, root.Position + dir * cfg.range / 2, params)
	local mark = hooks.telegraph(
		Vector3.new(cfg.radius * 2, 0.15, cfg.range),
		CFrame.lookAt(floor, floor + dir),
		false,
		GREEN
	)
	mark.Parent = session.folder
	Debris:AddItem(mark, cfg.duration)
	task.wait(cfg.release)
	mark:Destroy()
	if not alive(boss, session) then
		return
	end
	if workspace:Raycast(root.Position, from - root.Position, params) then
		return
	end
	local ball = part(session, "SplinterSpit", Vector3.new(1, 1, 1), GREEN, CFrame.new(from))
	local started, previous = os.clock(), from
	while alive(boss, session) do
		local distance = math.min(cfg.range, (os.clock() - started) * cfg.speed)
		local p = from + aim * distance
		local wall = workspace:Spherecast(previous, cfg.radius, p - previous + aim * 0.001, params)
		local to = if wall then wall.Position else p
		local closest, closestDistance = nil, math.huge
		for _, f in ipairs(hooks.fighters(boss)) do
			local d = (f.root.Position - previous).Magnitude
			if
				nearSegment(f.root.Position, previous, to) <= cfg.radius + 1.5
				and d < closestDistance
				and not workspace:Raycast(previous, f.root.Position - previous, params)
			then
				closest, closestDistance = f, d
			end
		end
		if closest then
			hooks.hurt(boss, closest, cfg.damage, from)
			break
		end
		if wall then
			break
		end
		ball.Position = p
		previous = p
		if distance >= cfg.range then
			break
		end
		RunService.Heartbeat:Wait()
	end
	ball:Destroy()
end

local function spider(boss: any, session: any, at: Vector3, cfg: any, hooks: any)
	local model = Instance.new("Model")
	model.Name = "SplinterSpider"
	local root = Instance.new("Part")
	root.Name, root.Size, root.Transparency = "HumanoidRootPart", Vector3.new(1.8, 1.2, 1.8), 1
	root.CFrame = CFrame.new(at + Vector3.new(0, 0.9, 0))
	root.Parent = model
	BlockRig.build(
		require(ReplicatedStorage.Shared.Models.splinter_spider),
		model,
		root,
		root.CFrame * CFrame.new(0, -0.9, 0),
		boss.fight.texture
	)
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R6
	humanoid.MaxHealth, humanoid.Health = cfg.hp, cfg.hp
	humanoid.WalkSpeed, humanoid.HipHeight = cfg.speed, 0.3
	humanoid.RequiresNeck, humanoid.BreakJointsOnDeath = false, false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.Parent = model
	model.PrimaryPart = root
	model:SetAttribute("MobId", "splinter_spider")
	model:SetAttribute("BaseWalkSpeed", cfg.speed)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	CollisionGroups.mob(model)
	model.Parent = session.folder
	CollectionService:AddTag(model, "Mob")
	root:SetNetworkOwner(nil)
	table.insert(session.spiders, model)
	Debris:AddItem(model, cfg.lifetime + 1)
	task.spawn(function()
		local untilAt, nextHit = os.clock() + cfg.lifetime, 0
		while
			alive(boss, session)
			and model.Parent
			and humanoid.Health > 0
			and os.clock() < untilAt
		do
			local best, bestDistance = nil, math.huge
			for _, f in ipairs(hooks.fighters(boss)) do
				local d = (f.root.Position - root.Position).Magnitude
				if d < bestDistance then
					best, bestDistance = f, d
				end
			end
			if not best then
				break
			end
			humanoid:MoveTo(inArena(boss, best.root.Position))
			if bestDistance < cfg.reach and os.clock() >= nextHit then
				nextHit = os.clock() + cfg.cooldown
				model:SetAttribute("MobWindup", workspace:GetServerTimeNow())
				task.wait(0.22)
				if
					alive(boss, session)
					and model.Parent
					and humanoid.Health > 0
					and best.humanoid.Health > 0
					and (best.root.Position - root.Position).Magnitude < cfg.reach
					and not workspace:Raycast(
						root.Position,
						best.root.Position - root.Position,
						rayParams(boss, session, hooks)
					)
				then
					hooks.hurt(boss, best, cfg.damage, root.Position)
				end
			end
			task.wait(0.15)
		end
		if model.Parent then
			model:Destroy()
		end
	end)
end

local function summon(boss: any, session: any, phase2: boolean, hooks: any)
	local cfg = boss.fight.splinter.summon
	local params = rayParams(boss, session, hooks)
	local points, marks = {}, {}
	for i = 1, (if phase2 then cfg.phase2Count else cfg.count) do
		local angle = i * math.pi * 2 / (if phase2 then cfg.phase2Count else cfg.count)
		local p = session.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 6
		if not workspace:Raycast(session.root.Position, p - session.root.Position, params) then
			p = ground(boss, inArena(boss, p), params)
			table.insert(points, p)
			local mark = hooks.telegraph(Vector3.new(3, 0.15, 3), CFrame.new(p), true, GREEN)
			mark.Parent = session.folder
			Debris:AddItem(mark, cfg.duration)
			table.insert(marks, mark)
		end
	end
	task.wait(cfg.release)
	for _, mark in ipairs(marks) do
		mark:Destroy()
	end
	if not alive(boss, session) then
		return
	end
	local living = {}
	for _, m in ipairs(session.spiders) do
		if m.Parent then
			table.insert(living, m)
		end
	end
	session.spiders = living
	for _, p in ipairs(points) do
		if #session.spiders >= cfg.maxAlive then
			break
		end
		spider(boss, session, p, cfg, hooks)
	end
end

function SplinterAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	phase2: boolean,
	hooks: any
)
	local session = sessionFor(boss)
	local name = ({ "swoop", "potion", "shoot", "summon" })[index]
	local cfg = boss.fight.splinter[name]
	boss.busyUntil = math.max(boss.busyUntil, os.clock() + cfg.duration)
	hooks.act(boss, name, cfg.duration)
	-- Keep the body still during windups. Swoop moves the anchored root itself; no shield during casts.
	local speed, autoRotate = boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate
	boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = 0, false
	task.delay(cfg.duration, function()
		if alive(boss, session) then
			boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = speed, autoRotate
		end
	end)
	task.spawn(function()
		if index == 1 then
			swoop(boss, session, target, hooks)
		elseif index == 2 then
			potion(boss, session, target, hooks)
		elseif index == 3 then
			shoot(boss, session, target, hooks)
		else
			summon(boss, session, phase2, hooks)
		end
	end)
end

return SplinterAbilities
