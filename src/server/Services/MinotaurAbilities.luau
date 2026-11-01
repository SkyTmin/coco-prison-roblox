--!strict
-- Original gameplay for the audited Minotaur clips; numeric hit geometry lives in design-decisions.
-- Each cast owns a token and effect folder. Death/replacement cancels every delayed hit and movement.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local BlockRig = require(ReplicatedStorage.Shared.BlockRig)
local Definition = require(ReplicatedStorage.Shared.Models.minotaur) :: any
local Prepared = BlockRig.prepare(Definition)
local MinotaurAbilities = {}
local sessions: { [any]: any } = {}
local bindings: { [any]: { any } } = {}
local AMBER = Color3.fromRGB(205, 126, 52)
local FLAT = Vector3.new(1, 0, 1)

-- The existing mountain arena has decorative chains reaching its centre. Release those
-- at the pull-apart pose, so they never remain visibly attached to an empty point in combat.
function MinotaurAbilities.Bindings(boss: any, sleeping: boolean)
	local list = bindings[boss]
	if not list then
		list = {}
		local arena = boss.spawn.Parent
		if arena then
			for _, p in ipairs(arena:GetDescendants()) do
				if p:IsA("BasePart") and p.Name == "ChainLink" then
					table.insert(list, { part = p, cf = p.CFrame, transparency = p.Transparency })
				end
			end
		end
		bindings[boss] = list
	end
	for _, link in ipairs(list) do
		if link.tween then
			link.tween:Cancel()
		end
		if link.part.Parent then
			if sleeping then
				link.part.CFrame, link.part.Transparency = link.cf, link.transparency
			else
				link.tween = TweenService:Create(
					link.part,
					TweenInfo.new(0.65, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
					{ CFrame = link.cf - Vector3.new(0, 1.5, 0), Transparency = 1 }
				)
				link.tween:Play()
			end
		end
	end
end

local function alive(boss: any, s: any): boolean
	return sessions[boss] == s
		and boss.root == s.root
		and s.root.Parent ~= nil
		and boss.humanoid ~= nil
		and boss.humanoid.Health > 0
end

function MinotaurAbilities.Clear(boss: any)
	local s = sessions[boss]
	sessions[boss] = nil
	if s then
		s.folder:Destroy()
		if boss.root == s.root and s.root.Parent and boss.humanoid and boss.humanoid.Health > 0 then
			boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = s.speed, s.rotate
			s.root.Anchored = s.anchored
		end
	end
end

local function begin(boss: any): any
	MinotaurAbilities.Clear(boss)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "MinotaurCast", workspace
	folder:SetAttribute("Origin", boss.root.Position)
	local s = {
		root = boss.root,
		folder = folder,
		speed = boss.humanoid.WalkSpeed,
		rotate = boss.humanoid.AutoRotate,
		anchored = boss.root.Anchored,
	}
	sessions[boss] = s
	boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = 0, false
	boss.root.Anchored = true
	return s
end

local function finishAfter(boss: any, s: any, seconds: number)
	task.delay(seconds, function()
		if sessions[boss] == s then
			MinotaurAbilities.Clear(boss)
		end
	end)
end

local function params(boss: any, s: any, hooks: any): RaycastParams
	local list = { boss.model, s.folder }
	-- A player entering the arena during windup is a damage target, never a charge-stunning wall.
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, f in ipairs(hooks.fighters(boss)) do
		if f.player.Character then
			table.insert(list, f.player.Character)
		end
	end
	local p = RaycastParams.new()
	p.FilterType, p.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, list
	p.RespectCanCollide, p.IgnoreWater = true, true
	return p
end

local function face(root: BasePart, target: Vector3)
	local d = (target - root.Position) * FLAT
	if d.Magnitude > 0.01 then
		root.CFrame = CFrame.lookAt(root.Position, root.Position + d)
	end
end

local function ground(boss: any, at: Vector3, ray: RaycastParams): Vector3
	local hit = workspace:Raycast(at + Vector3.new(0, 8, 0), Vector3.new(0, -28, 0), ray)
	return if hit
		then hit.Position + Vector3.new(0, 0.1, 0)
		else Vector3.new(at.X, boss.spawn.Position.Y + boss.spawn.Size.Y / 2 + 0.1, at.Z)
end

local function part(s: any, name: string, size: Vector3, cf: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame, p.Color = name, size, cf, color
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Material, p.Parent = Enum.Material.SmoothPlastic, s.folder
	return p
end

local function mark(s: any, hooks: any, at: Vector3, radius: number): BasePart
	local p =
		hooks.telegraph(Vector3.new(radius * 2, 0.15, radius * 2), CFrame.new(at), true, AMBER)
	p.Parent = s.folder
	return p
end

local function visible(f: any, from: Vector3, ray: RaycastParams): boolean
	return f.root.Parent ~= nil
		and f.humanoid.Health > 0
		and workspace:Raycast(from, f.root.Position - from, ray) == nil
end

local function area(
	boss: any,
	hooks: any,
	at: Vector3,
	radius: number,
	damage: number,
	ray: RaycastParams
)
	for _, f in ipairs(hooks.fighters(boss)) do
		local d = f.root.Position - at
		if
			math.abs(d.Y) < 7
			and (d * FLAT).Magnitude <= radius
			and visible(f, at + Vector3.new(0, 2, 0), ray)
		then
			hooks.hurt(boss, f, damage, at)
		end
	end
end

local function dust(s: any, at: Vector3, radius: number)
	local ring = part(
		s,
		"MinotaurImpact",
		Vector3.new(0.1, 1, 1),
		CFrame.new(at) * CFrame.Angles(0, 0, math.pi / 2),
		AMBER
	)
	ring.Shape, ring.Transparency = Enum.PartType.Cylinder, 0.5
	TweenService:Create(
		ring,
		TweenInfo.new(0.32),
		{ Size = Vector3.new(0.1, radius * 2, radius * 2), Transparency = 1 }
	):Play()
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color, emitter.Rate = ColorSequence.new(Color3.fromRGB(118, 92, 65)), 0
	emitter.Lifetime, emitter.Speed = NumberRange.new(0.25, 0.5), NumberRange.new(2, 5)
	emitter.Size, emitter.Transparency = NumberSequence.new(0.45, 1), NumberSequence.new(0.45, 1)
	emitter.SpreadAngle, emitter.Parent = Vector2.new(180, 180), ring
	emitter:Emit(8)
	Debris:AddItem(ring, 0.65)
end

local function arc(boss: any, s: any, hooks: any, radius: number, angle: number, damage: number)
	local ray = params(boss, s, hooks)
	local from, forward = s.root.Position, s.root.CFrame.LookVector
	for _, f in ipairs(hooks.fighters(boss)) do
		local d = (f.root.Position - from) * FLAT
		if
			d.Magnitude <= radius
			and math.abs(f.root.Position.Y - from.Y) < 6
			and (d.Magnitude < 0.01 or d.Unit:Dot(forward) >= math.cos(math.rad(angle)))
			and visible(f, from, ray)
		then
			hooks.hurt(boss, f, damage, from)
		end
	end
end

function MinotaurAbilities.Sleep(boss: any)
	begin(boss)
	MinotaurAbilities.Bindings(boss, true)
	boss.model:SetAttribute("Sleeping", true)
end

function MinotaurAbilities.Wake(boss: any, hooks: any)
	local s = begin(boss)
	local duration = boss.fight.minotaur.awakening
	boss.model:SetAttribute("Sleeping", false)
	boss.busyUntil = os.clock() + duration
	boss.nextAbilityAt = boss.busyUntil + boss.fight.abilityCooldown
	hooks.shield(boss, duration)
	hooks.act(boss, "awakening", duration)
	task.delay(142 / 30, function()
		if alive(boss, s) then
			MinotaurAbilities.Bindings(boss, false)
		end
	end)
	finishAfter(boss, s, duration)
end

function MinotaurAbilities.Melee(boss: any, target: Vector3, hooks: any)
	local s = begin(boss)
	face(s.root, target)
	boss.busyUntil = os.clock() + boss.fight.meleeDuration
	hooks.act(boss, "melee", boss.fight.meleeDuration)
	finishAfter(boss, s, boss.fight.meleeDuration)
	task.delay(boss.fight.meleeHitAt, function()
		if alive(boss, s) then
			arc(boss, s, hooks, boss.fight.meleeRange, 60, boss.fight.meleeDamage)
		end
	end)
end

local function stomp(boss: any, s: any, cfg: any, hooks: any)
	local ray = params(boss, s, hooks)
	local target = s.root.Position + s.root.CFrame.LookVector * cfg.forward
	local wall = workspace:Raycast(s.root.Position, target - s.root.Position, ray)
	if wall then
		target = s.root.Position
	end
	local at = ground(boss, target, ray)
	local m = mark(s, hooks, at, cfg.radius)
	task.wait(cfg.release)
	m:Destroy()
	if not alive(boss, s) then
		return
	end
	dust(s, at, cfg.radius)
	area(boss, hooks, at, cfg.radius, cfg.damage, ray)
end

-- Sample exactly the exported wrist animation. Server sockets and the client's hands agree.
local function heldClod(boss: any, t: number): Vector3
	local rootJoint = boss.model:FindFirstChild("J_root")
	local motor = rootJoint and rootJoint:FindFirstChild("root")
	local origin = if motor and motor:IsA("Motor6D")
		then boss.root.CFrame * motor.C0
		else boss.root.CFrame * CFrame.new(0, -4.5, 0)
	local worlds: { [string]: CFrame } = {}
	local pivots: { [string]: Vector3 } = {}
	local clip = Prepared.clips.throws_the_ground
	for _, j in ipairs(Definition.joints) do
		local pivot = Vector3.new(j.pivot[1], j.pivot[2], j.pivot[3])
		pivots[j.name] = pivot
		local base = if j.parent then pivot - pivots[j.parent] else pivot
		worlds[j.name] = (if j.parent then worlds[j.parent] else origin)
			* CFrame.new(base)
			* BlockRig.sample(clip, j.name, t)
	end
	return (worlds.handL.Position + worlds.handR.Position) / 2
end

local function throwGround(boss: any, s: any, cfg: any, target: Vector3, hooks: any)
	local ray = params(boss, s, hooks)
	local delta = (target - s.root.Position) * FLAT
	local length = math.min(cfg.range, delta.Magnitude)
	local dir = if delta.Magnitude > 0.01 then delta.Unit else s.root.CFrame.LookVector
	local obstruction = workspace:Raycast(s.root.Position, dir * length, ray)
	if obstruction then
		length = math.max(0, obstruction.Distance - 2)
	end
	local at = ground(boss, s.root.Position + dir * length, ray)
	local m = mark(s, hooks, at, cfg.radius)
	local started = os.clock()
	task.wait(cfg.pickup)
	if not alive(boss, s) then
		return
	end
	local clod = part(
		s,
		"MinotaurClod",
		Vector3.new(2.15, 1.4, 1.8),
		CFrame.new(heldClod(boss, cfg.pickup)),
		Color3.fromRGB(106, 76, 48)
	)
	local roots = {}
	for i = 1, 4 do
		local p = part(
			s,
			"ClodRoot",
			Vector3.new(0.16, 0.16, 1.3),
			clod.CFrame,
			Color3.fromRGB(54, 43, 28)
		)
		table.insert(roots, {
			p = p,
			cf = CFrame.new((i - 2.5) * 0.48, -0.9, 0.1) * CFrame.Angles(0, i * 0.6, -0.3),
		})
	end
	local function move(cf: CFrame)
		clod.CFrame = cf
		for _, r in ipairs(roots) do
			r.p.CFrame = cf * r.cf
		end
	end
	while alive(boss, s) and os.clock() - started < cfg.release do
		move(CFrame.new(heldClod(boss, os.clock() - started)))
		RunService.Heartbeat:Wait()
	end
	if not alive(boss, s) then
		return
	end
	local from = heldClod(boss, cfg.release)
	-- A close wall can intersect the release socket before the flight begins.
	local launchWall = workspace:Spherecast(s.root.Position, 1, from - s.root.Position, ray)
	local impactAt: Vector3? = nil
	if launchWall then
		impactAt = ground(boss, launchWall.Position + launchWall.Normal * 1.05, ray)
	else
		local beginFlight, previous = os.clock(), from
		while alive(boss, s) do
			local u = math.min(1, (os.clock() - beginFlight) / cfg.flight)
			local nextPosition = from:Lerp(at + Vector3.new(0, 1, 0), u)
				+ Vector3.new(0, 4 * 4 * u * (1 - u), 0)
			local d = nextPosition - previous
			local wall = if d.Magnitude > 0.0001
				then workspace:Spherecast(previous, 0.95, d, ray)
				else nil
			if wall then
				impactAt = ground(boss, wall.Position + wall.Normal * 1.05, ray)
				break
			end
			move(CFrame.new(nextPosition) * CFrame.Angles(u * 4, u * 2, 0))
			previous = nextPosition
			if u >= 1 then
				impactAt = at
				break
			end
			RunService.Heartbeat:Wait()
		end
	end
	m:Destroy()
	clod:Destroy()
	for _, r in ipairs(roots) do
		r.p:Destroy()
	end
	if alive(boss, s) and impactAt then
		dust(s, impactAt, cfg.radius)
		area(boss, hooks, impactAt, cfg.radius, cfg.damage, ray)
	end
end

local function segmentDistance(point: Vector3, a: Vector3, b: Vector3): number
	local ab = (b - a) * FLAT
	local d = (point - a) * FLAT
	local t = if ab.Magnitude > 0.001 then math.clamp(d:Dot(ab) / ab:Dot(ab), 0, 1) else 0
	return (d - ab * t).Magnitude
end

local function rush(boss: any, s: any, cfg: any, hooks: any)
	local ray = params(boss, s, hooks)
	-- Shapecasts miss initial overlaps. Also check the starting volume when a new
	-- obstacle appears around the moving boss between frames (WorldRoot API contract).
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances =
		ray.FilterType, ray.FilterDescendantsInstances
	overlap.RespectCanCollide, overlap.MaxParts = true, 1
	local function occupied(at: Vector3): boolean
		return #workspace:GetPartBoundsInBox(
				CFrame.new(at),
				Vector3.new(3.9, 3.9, 3.9),
				overlap
			) > 0
	end
	local start, dir = s.root.Position, s.root.CFrame.LookVector * FLAT
	dir = dir.Unit
	local offset = (start - boss.spawn.Position) * FLAT
	local radius = math.max(1, boss.arenaRadius - 4)
	local b = offset:Dot(dir)
	local limit =
		math.max(0, -b + math.sqrt(math.max(0, b * b + radius * radius - offset:Dot(offset))))
	local distance = math.min(cfg.maxDistance, limit)
	local inside = occupied(start)
	if inside then
		distance = 0
	end
	local wall = workspace:Spherecast(start, 2, dir * math.max(0.001, distance), ray)
	if wall then
		distance = math.max(0, wall.Distance - 0.2)
	end
	local from = ground(boss, start, ray)
	local strip = hooks.telegraph(
		Vector3.new(cfg.radius * 2, 0.15, math.max(1, distance)),
		CFrame.lookAt(from + dir * distance / 2, from + dir * (distance / 2 + 1)),
		false,
		AMBER
	)
	strip.Parent = s.folder
	task.wait(cfg.release)
	strip:Destroy()
	if not alive(boss, s) then
		return
	end
	local t0, previous, hit = os.clock(), start, {}
	local collided = false
	while alive(boss, s) do
		if occupied(previous) then
			collided = true
			break
		end
		local along = math.min(distance, (os.clock() - t0) * cfg.speed)
		local nextPosition = start + dir * along
		local delta = nextPosition - previous
		local obstacle = if delta.Magnitude > 0.0001
			then workspace:Spherecast(previous, 2, delta, ray)
			else nil
		if obstacle then
			nextPosition = previous + delta.Unit * math.max(0, obstacle.Distance - 0.2)
			collided = true
		end
		s.root.CFrame = CFrame.lookAt(nextPosition, nextPosition + dir)
		s.root.AssemblyLinearVelocity = Vector3.zero
		for _, f in ipairs(hooks.fighters(boss)) do
			if
				not hit[f.player]
				and math.abs(f.root.Position.Y - nextPosition.Y) < 5
				and segmentDistance(f.root.Position, previous, nextPosition) <= cfg.radius
				and visible(f, nextPosition, ray)
			then
				hit[f.player] = true
				hooks.hurt(boss, f, cfg.damage, start)
			end
		end
		previous = nextPosition
		if collided or along >= distance then
			break
		end
		RunService.Heartbeat:Wait()
	end
	if not alive(boss, s) then
		return
	end
	if collided or inside or wall or limit < cfg.maxDistance then
		local seconds = boss.fight.minotaur.stunDuration
		boss.stunnedUntil, boss.busyUntil = os.clock() + seconds, os.clock() + seconds
		boss.model:SetAttribute("Shielded", false)
		hooks.act(boss, "stun", seconds)
		dust(s, ground(boss, s.root.Position, ray), 3)
		-- A new token prevents the original rush timeout from ending the stun early.
		sessions[boss] = nil
		local stunned = table.clone(s)
		sessions[boss] = stunned
		finishAfter(boss, stunned, seconds)
	else
		finishAfter(boss, s, math.max(0.1, cfg.duration - cfg.release - (os.clock() - t0)))
	end
end

function MinotaurAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	_phase2: boolean,
	hooks: any
)
	local name = ({ "impact", "double_attack", "throws_the_ground", "minotaur_rush" })[index]
	local cfg = boss.fight.minotaur[name]
	local s = begin(boss)
	face(s.root, target)
	boss.busyUntil = os.clock() + cfg.duration
	boss.state:SetAttribute("Telegraph", cfg.release or cfg.hits[1])
	hooks.shield(boss, cfg.duration)
	hooks.act(boss, name, cfg.duration)
	if name ~= "minotaur_rush" then
		finishAfter(boss, s, cfg.duration)
	end
	task.spawn(function()
		if name == "impact" then
			stomp(boss, s, cfg, hooks)
		elseif name == "double_attack" then
			local last = 0
			for _, at in ipairs(cfg.hits) do
				task.wait(at - last)
				if not alive(boss, s) then
					return
				end
				arc(boss, s, hooks, cfg.range, cfg.halfAngle, cfg.damage)
				last = at
			end
		elseif name == "throws_the_ground" then
			throwGround(boss, s, cfg, target, hooks)
		else
			rush(boss, s, cfg, hooks)
		end
	end)
end

return MinotaurAbilities
