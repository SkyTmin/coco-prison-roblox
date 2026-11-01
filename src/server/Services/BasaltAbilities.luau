--!strict
-- Original implementations of the audited sword_slash / sword_smash / sword_spike clips.
-- Names and durations are recovered facts; hit geometry and release times are project decisions.
local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local BasaltAbilities = {}
local sessions: { [any]: any } = {}
local AMBER = Color3.fromRGB(230, 116, 38)
local ROCK = Color3.fromRGB(62, 64, 70)

local function alive(boss: any, session: any): boolean
	return sessions[boss] == session
		and boss.root == session.root
		and session.root.Parent ~= nil
		and boss.humanoid ~= nil
		and boss.humanoid.Health > 0
end

function BasaltAbilities.Clear(boss: any)
	local old = sessions[boss]
	sessions[boss] = nil
	if old then
		old.folder:Destroy()
		if boss.humanoid and boss.humanoid.Health > 0 and boss.root == old.root then
			boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = old.speed, old.autoRotate
		end
	end
end

local function params(boss: any, session: any, hooks: any): RaycastParams
	local list = { boss.model, session.folder }
	for _, f in ipairs(hooks.fighters(boss)) do
		if f.player.Character then
			table.insert(list, f.player.Character)
		end
	end
	local p = RaycastParams.new()
	p.FilterType = Enum.RaycastFilterType.Exclude
	p.FilterDescendantsInstances = list
	p.RespectCanCollide = true
	p.IgnoreWater = true
	return p
end

local function ground(boss: any, at: Vector3, ray: RaycastParams): Vector3
	local hit = workspace:Raycast(at + Vector3.new(0, 8, 0), Vector3.new(0, -28, 0), ray)
	return if hit
		then hit.Position + Vector3.new(0, 0.12, 0)
		else Vector3.new(at.X, boss.spawn.Position.Y + boss.spawn.Size.Y / 2 + 0.12, at.Z)
end

local function part(session: any, name: string, size: Vector3, cf: CFrame, glow: boolean): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material = if glow then Enum.Material.Neon else Enum.Material.Basalt
	p.Color = if glow then AMBER else ROCK
	p.Parent = session.folder
	return p
end

local function canHit(f: any, at: Vector3, radius: number, ray: RaycastParams): boolean
	local delta = f.root.Position - at
	return f.humanoid.Health > 0
		and math.abs(delta.Y) <= 7
		and (delta * Vector3.new(1, 0, 1)).Magnitude <= radius
		and workspace:Raycast(at + Vector3.new(0, 2, 0), delta - Vector3.new(0, 2, 0), ray)
			== nil
end

local function mark(session: any, hooks: any, at: Vector3, radius: number): BasePart
	local m =
		hooks.telegraph(Vector3.new(radius * 2, 0.15, radius * 2), CFrame.new(at), true, AMBER)
	m.Parent = session.folder
	return m
end

local function impact(session: any, at: Vector3, radius: number)
	-- One expanding ring and a small ember burst; never recolour or dismantle the boss mesh.
	local ring = part(
		session,
		"BasaltImpact",
		Vector3.new(0.12, 1, 1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		true
	)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.4
	TweenService:Create(
		ring,
		TweenInfo.new(0.35),
		{ Size = Vector3.new(0.12, radius * 2, radius * 2), Transparency = 1 }
	):Play()
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(104, 92, 78))
	dust.Lifetime, dust.Speed = NumberRange.new(0.25, 0.5), NumberRange.new(2, 5)
	dust.Size = NumberSequence.new(0.6, 1.2)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Rate, dust.SpreadAngle = 0, Vector2.new(180, 180)
	dust.Parent = ring
	dust:Emit(10)
	Debris:AddItem(ring, 0.65)
end

local function slash(boss: any, s: any, cfg: any, hooks: any)
	local ray = params(boss, s, hooks)
	local from = ground(boss, s.root.Position, ray)
	local dir = s.root.CFrame.LookVector * Vector3.new(1, 0, 1)
	dir = dir.Unit
	local wall = workspace:Raycast(from + Vector3.new(0, 2, 0), dir * cfg.length, ray)
	local length = if wall then math.max(0, wall.Distance - 0.3) else cfg.length
	local strip = hooks.telegraph(
		Vector3.new(cfg.width, 0.15, math.max(1, length)),
		CFrame.lookAt(from + dir * length / 2, from + dir * (length / 2 + 1)),
		false,
		AMBER
	)
	strip.Parent = s.folder
	task.wait(cfg.release)
	strip:Destroy()
	if not alive(boss, s) then
		return
	end
	local wave = part(s, "BasaltSlash", Vector3.new(cfg.width, 2.4, 0.7), CFrame.new(from), true)
	wave.Transparency = 0.3
	local begun, previous, hit = os.clock(), 0, {}
	while alive(boss, s) do
		local along = math.min(length, (os.clock() - begun) * cfg.speed)
		local at = from + dir * along
		wave.CFrame = CFrame.lookAt(at + Vector3.new(0, 1.2, 0), at + dir + Vector3.new(0, 1.2, 0))
		for _, f in ipairs(hooks.fighters(boss)) do
			local delta = (f.root.Position - from) * Vector3.new(1, 0, 1)
			local distance = delta:Dot(dir)
			local closest = from + dir * math.clamp(distance, previous, along)
			if not hit[f.player] and canHit(f, closest, cfg.width / 2, ray) then
				hit[f.player] = true
				hooks.hurt(boss, f, cfg.damage, from)
			end
		end
		if along >= length then
			break
		end
		previous = along
		RunService.Heartbeat:Wait()
	end
	wave:Destroy()
end

local function smash(boss: any, s: any, cfg: any, hooks: any)
	local ray = params(boss, s, hooks)
	local dir = s.root.CFrame.LookVector
	local wall = workspace:Raycast(s.root.Position, dir * cfg.forward, ray)
	local reach = if wall then math.max(0, wall.Distance - 0.5) else cfg.forward
	local at = ground(boss, s.root.Position + dir * reach, ray)
	local circle = mark(s, hooks, at, cfg.radius)
	task.wait(cfg.release)
	circle:Destroy()
	if not alive(boss, s) then
		return
	end
	impact(s, at, cfg.radius)
	for _, f in ipairs(hooks.fighters(boss)) do
		if canHit(f, at, cfg.radius, ray) then
			hooks.hurt(boss, f, cfg.damage, at)
		end
	end
end

local function spike(boss: any, s: any, cfg: any, phase2: boolean, hooks: any)
	local ray = params(boss, s, hooks)
	local spots, marks = {}, {}
	for _, f in ipairs(hooks.fighters(boss)) do
		for k = 1, (if phase2 then cfg.perTargetPhase2 else cfg.perTarget) do
			if #spots >= cfg.maxSpots then
				break
			end
			local angle = k * math.pi * 2 / 3
			local offset = if k == 1
				then Vector3.zero
				else Vector3.new(math.cos(angle), 0, math.sin(angle)) * 5
			local at = ground(boss, f.root.Position + offset, ray)
			if
				not workspace:Raycast(
					s.root.Position,
					at + Vector3.new(0, 2, 0) - s.root.Position,
					ray
				)
			then
				table.insert(spots, at)
				table.insert(marks, mark(s, hooks, at, cfg.radius))
			end
		end
	end
	task.wait(cfg.release)
	for _, m in ipairs(marks) do
		m:Destroy()
	end
	if not alive(boss, s) then
		return
	end
	local hit = {}
	for _, at in ipairs(spots) do
		for k = 1, 3 do
			local offset = Vector3.new(math.cos(k * 2.1), 0, math.sin(k * 2.1)) * 1.2
			local p = part(
				s,
				"BasaltSpike",
				Vector3.new(0.9, 4 + k * 0.4, 0.9),
				CFrame.new(at + offset - Vector3.new(0, 3, 0)),
				false
			)
			TweenService:Create(
				p,
				TweenInfo.new(0.12, Enum.EasingStyle.Quad),
				{ CFrame = CFrame.new(at + offset + Vector3.new(0, p.Size.Y / 2, 0)) }
			):Play()
			Debris:AddItem(p, 0.9)
		end
		for _, f in ipairs(hooks.fighters(boss)) do
			if not hit[f.player] and canHit(f, at, cfg.radius, ray) then
				hit[f.player] = true
				hooks.hurt(boss, f, cfg.damage, at)
			end
		end
	end
end

function BasaltAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	phase2: boolean,
	hooks: any
)
	BasaltAbilities.Clear(boss)
	local name = ({ "sword_slash", "sword_smash", "sword_spike" })[index]
	local cfg = boss.fight.basalt[name]
	local root = boss.root
	local folder = Instance.new("Folder")
	folder.Name = "BasaltCast"
	folder.Parent = workspace
	local s = {
		root = root,
		folder = folder,
		speed = boss.humanoid.WalkSpeed,
		autoRotate = boss.humanoid.AutoRotate,
	}
	sessions[boss] = s
	local flat = (target - root.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
	end
	boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = 0, false
	boss.busyUntil = math.max(boss.busyUntil, os.clock() + cfg.duration)
	hooks.hold(boss, cfg.duration)
	hooks.act(boss, name, cfg.duration)
	boss.state:SetAttribute("Telegraph", cfg.release)
	task.delay(cfg.duration, function()
		if sessions[boss] == s then
			BasaltAbilities.Clear(boss)
		end
	end)
	task.spawn(function()
		if index == 1 then
			slash(boss, s, cfg, hooks)
		elseif index == 2 then
			smash(boss, s, cfg, hooks)
		else
			spike(boss, s, cfg, phase2, hooks)
		end
	end)
end

return BasaltAbilities
