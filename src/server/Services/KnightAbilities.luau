--!strict
-- Audited knight action names; original motion, geometry and damage. No defensive immunity [owner 02.11].
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local KnightAbilities = {}
local casts: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local COLOR = Color3.fromRGB(150, 68, 59)
local NAMES = {
	"berserkerleap",
	"strikeoffury1",
	"relentlesswhirlwindspin",
	"bloodboundbarrier",
	"dash",
	"strikeoffury2",
	"viciousstrike",
}

local function alive(boss: any, s: any): boolean
	return casts[boss] == s
		and boss.root == s.root
		and s.root.Parent ~= nil
		and boss.humanoid.Health > 0
end
local function finish(boss: any, s: any)
	if casts[boss] ~= s then
		return
	end
	casts[boss] = nil
	s.folder:Destroy()
	if boss.root == s.root and s.root.Parent and boss.humanoid.Health > 0 then
		boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate, s.root.Anchored =
			s.speed, s.rotate, s.anchored
	end
end
function KnightAbilities.Clear(boss: any)
	if casts[boss] then
		finish(boss, casts[boss])
	end
end
local function begin(
	boss: any,
	name: string,
	duration: number,
	release: number,
	target: Vector3?,
	hooks: any,
	special: boolean
): any
	KnightAbilities.Clear(boss)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "KnightCast", workspace
	local s = {
		root = boss.root,
		folder = folder,
		speed = boss.humanoid.WalkSpeed,
		rotate = boss.humanoid.AutoRotate,
		anchored = boss.root.Anchored,
	}
	casts[boss] = s
	if target then
		local delta = (target - s.root.Position) * FLAT
		if delta.Magnitude > 0.01 then
			s.root.CFrame = CFrame.lookAt(s.root.Position, s.root.Position + delta)
		end
	end
	boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate, s.root.Anchored = 0, false, true
	boss.busyUntil = os.clock() + duration
	if special then
		boss.nextAbilityAt =
			math.max(boss.nextAbilityAt or 0, boss.busyUntil + boss.fight.knight.recovery)
	end
	boss.state:SetAttribute("Telegraph", release)
	boss.model:SetAttribute("Shielded", false)
	hooks.act(boss, name, duration)
	return s
end
local function params(boss: any, s: any, hooks: any): RaycastParams
	local ignore = { boss.model, s.folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	if hooks.fighters then
		for _, f in hooks.fighters(boss) do
			table.insert(ignore, f.player.Character)
		end
	end
	local ray = RaycastParams.new()
	ray.FilterType, ray.FilterDescendantsInstances = Enum.RaycastFilterType.Exclude, ignore
	ray.RespectCanCollide, ray.IgnoreWater = true, true
	return ray
end
local function floorAt(boss: any, p: Vector3, ray: RaycastParams): Vector3
	local hit = workspace:Raycast(p + Vector3.new(0, 6, 0), Vector3.new(0, -20, 0), ray)
	return if hit
		then hit.Position + Vector3.new(0, 0.08, 0)
		else Vector3.new(p.X, boss.spawn.Position.Y + boss.spawn.Size.Y / 2 + 0.08, p.Z)
end
local function mark(boss: any, s: any, hooks: any, p: Vector3, radius: number): BasePart
	local at = floorAt(boss, p, params(boss, s, hooks))
	local m =
		hooks.telegraph(Vector3.new(radius * 2, 0.12, radius * 2), CFrame.new(at), true, COLOR)
	m.Parent = s.folder
	return m
end
local function hit(
	boss: any,
	s: any,
	hooks: any,
	center: Vector3,
	cfg: any,
	damage: number,
	omnidirectional: boolean?
)
	if not alive(boss, s) then
		return
	end
	local ray = params(boss, s, hooks)
	for _, f in hooks.fighters(boss) do
		local offset = f.root.Position - center
		local delta = offset * FLAT
		if
			f.root.Parent
			and f.humanoid.Health > 0
			and delta.Magnitude <= cfg.radius
			and math.abs(offset.Y) <= 7
			and (omnidirectional or delta.Magnitude < 0.01 or delta.Unit:Dot(
				s.root.CFrame.LookVector
			) >= math.cos(math.rad(cfg.halfAngle or 60)))
			and not workspace:Raycast(center, offset, ray)
		then
			hooks.hurt(boss, f, damage, center, 0.65, 0.25)
		end
	end
end
local function pulse(s: any, at: Vector3, radius: number)
	-- Eight matte fragments, outside the boss model. No lights or changes to its rendered parts.
	for i = 1, 8 do
		local a = i * math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery =
			"KnightImpact", true, false, false, false
		p.Size, p.Color, p.Material =
			Vector3.new(0.32, 0.22, 0.5), COLOR, Enum.Material.SmoothPlastic
		p.CFrame, p.Parent = CFrame.new(at + dir), s.folder
		TweenService:Create(p, TweenInfo.new(0.38), {
			CFrame = CFrame.new(at + dir * radius + Vector3.new(0, 0.5, 0))
				* CFrame.Angles(a, a, a),
			Transparency = 1,
		}):Play()
	end
end
local function waitUntil(boss: any, s: any, start: number, seconds: number): boolean
	while alive(boss, s) and os.clock() < start + seconds do
		RunService.Heartbeat:Wait()
	end
	return alive(boss, s)
end
local function endAfter(boss: any, s: any, start: number, duration: number)
	waitUntil(boss, s, start, duration)
	finish(boss, s)
end
local function destination(
	boss: any,
	s: any,
	hooks: any,
	desired: Vector3,
	range: number
): (Vector3, boolean)
	local root = s.root
	local delta = (desired - root.Position) * FLAT
	if delta.Magnitude > range then
		delta = delta.Unit * range
	end
	local goal = root.Position + delta
	local away = (goal - boss.spawn.Position) * FLAT
	if away.Magnitude > boss.arenaRadius - 3 then
		goal = Vector3.new(boss.spawn.Position.X, root.Position.Y, boss.spawn.Position.Z)
			+ away.Unit * (boss.arenaRadius - 3)
		delta = goal - root.Position
	end
	local ray = params(boss, s, hooks)
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances =
		ray.FilterType, ray.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	if #workspace:GetPartBoundsInBox(root.CFrame, Vector3.new(3.6, 4.2, 2.6), overlap) > 0 then
		return root.Position, true
	end
	local wall = if delta.Magnitude > 0.01
		then workspace:Blockcast(root.CFrame, Vector3.new(3.6, 4.2, 2.6), delta, ray)
		else nil
	-- Also cover shallow obstacles at foot height; Blockcast ignores initial overlaps.
	local low = floorAt(boss, root.Position, ray) + Vector3.new(0, 0.5, 0)
	local lowWall = if delta.Magnitude > 0.01 then workspace:Raycast(low, delta, ray) else nil
	local distance = delta.Magnitude
	if wall then
		distance = math.min(distance, math.max(0, wall.Distance - 0.3))
	end
	if lowWall then
		distance = math.min(distance, math.max(0, lowWall.Distance - 2))
	end
	return root.Position + (if delta.Magnitude > 0.01 then delta.Unit * distance else Vector3.zero),
		wall ~= nil or lowWall ~= nil
end
local function travel(
	boss: any,
	s: any,
	hooks: any,
	goal: Vector3,
	start: number,
	moveAt: number,
	moveEnd: number
): boolean
	if not waitUntil(boss, s, start, moveAt) then
		return false
	end
	local from, rotation = s.root.Position, s.root.CFrame.Rotation
	local delta = goal - from
	local ray = params(boss, s, hooks)
	local overlap = OverlapParams.new()
	overlap.FilterType, overlap.FilterDescendantsInstances =
		ray.FilterType, ray.FilterDescendantsInstances
	overlap.RespectCanCollide = true
	while alive(boss, s) do
		local u = math.clamp((os.clock() - start - moveAt) / math.max(0.01, moveEnd - moveAt), 0, 1)
		local nextPoint = from + delta * (u * u * (3 - 2 * u))
		local step = nextPoint - s.root.Position
		if step.Magnitude > 0.001 then
			local wall = workspace:Blockcast(s.root.CFrame, Vector3.new(3.6, 4.2, 2.6), step, ray)
			local low = floorAt(boss, s.root.Position, ray) + Vector3.new(0, 0.5, 0)
			if
				wall
				or workspace:Raycast(low, step, ray)
				or #workspace:GetPartBoundsInBox(
						CFrame.new(nextPoint) * rotation,
						Vector3.new(3.6, 4.2, 2.6),
						overlap
					)
					> 0
			then
				return false
			end
			s.root.CFrame = CFrame.new(nextPoint) * rotation
		end
		if u >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end
function KnightAbilities.Melee(boss: any, target: Vector3, hooks: any)
	boss.knightMelee = (boss.knightMelee or 0) % #boss.fight.knight.melee + 1
	local cfg = boss.fight.knight.melee[boss.knightMelee]
	local s = begin(boss, cfg.name, cfg.duration, cfg.release, target, hooks, false)
	task.spawn(function()
		local start = os.clock()
		if waitUntil(boss, s, start, cfg.release) then
			hit(boss, s, hooks, s.root.Position, cfg, cfg.damage)
		end
		endAfter(boss, s, start, cfg.duration)
	end)
end
function KnightAbilities.Spawn(boss: any, hooks: any)
	local duration = boss.fight.knight.spawnDuration
	local s = begin(boss, "startcombat", duration, 0, nil, hooks, false)
	task.delay(duration, function()
		finish(boss, s)
	end)
end
function KnightAbilities.Cast(
	boss: any,
	index: number,
	target: Vector3,
	_phase2: boolean,
	hooks: any
)
	local name = NAMES[(index - 1) % #NAMES + 1]
	local cfg = boss.fight.knight[name]
	local s = begin(boss, name, cfg.duration, cfg.release or cfg.moveAt, target, hooks, true)
	task.spawn(function()
		local start = os.clock()
		if name == "berserkerleap" then
			local goal = destination(boss, s, hooks, target, cfg.range)
			local warning = mark(boss, s, hooks, goal, cfg.radius)
			travel(boss, s, hooks, goal, start, cfg.moveAt, cfg.release)
			if waitUntil(boss, s, start, cfg.release) then
				warning:Destroy()
				local actual = floorAt(boss, s.root.Position, params(boss, s, hooks))
				pulse(s, actual, cfg.radius)
				hit(boss, s, hooks, s.root.Position, cfg, cfg.damage, true)
			end
		elseif name == "dash" then
			boss.knightDash = (boss.knightDash or 0) % 4 + 1
			local directions = {
				s.root.CFrame.LookVector,
				-s.root.CFrame.RightVector,
				s.root.CFrame.RightVector,
				-s.root.CFrame.LookVector,
			}
			local names = { "dashfront", "dashleft", "dashright", "dashback" }
			local duration = if boss.knightDash == 4 then cfg.backDuration else cfg.duration
			hooks.act(boss, names[boss.knightDash], duration)
			boss.busyUntil = start + duration
			local goal, wall = destination(
				boss,
				s,
				hooks,
				s.root.Position + directions[boss.knightDash] * cfg.range,
				cfg.range
			)
			local moved = travel(boss, s, hooks, goal, start, cfg.moveAt, cfg.moveEnd)
			if alive(boss, s) and (wall or not moved) then
				hooks.act(boss, "flinch", cfg.flinchDuration)
				boss.busyUntil = os.clock() + cfg.flinchDuration
				endAfter(boss, s, os.clock(), cfg.flinchDuration)
				return
			end
			endAfter(boss, s, start, duration)
			return
		elseif name == "bloodboundbarrier" then
			hooks.act(boss, "bloodboundbarrier", cfg.guardDuration)
			mark(boss, s, hooks, s.root.Position + s.root.CFrame.LookVector * 3, 3)
			if waitUntil(boss, s, start, cfg.guardDuration) then
				hooks.act(boss, "bulwarkinstinct", cfg.bashDuration)
			end
			if waitUntil(boss, s, start, cfg.release) then
				hit(boss, s, hooks, s.root.Position, cfg, cfg.damage)
			end
		elseif name == "viciousstrike" then
			local goal = destination(boss, s, hooks, target, cfg.range)
			local warning = mark(boss, s, hooks, goal, cfg.radius)
			if waitUntil(boss, s, start, cfg.release) then
				local ray = params(boss, s, hooks)
				local delta = goal - s.root.Position
				local low = floorAt(boss, s.root.Position, ray) + Vector3.new(0, 0.5, 0)
				if
					not workspace:Raycast(s.root.Position, delta, ray)
					and not workspace:Raycast(low, delta, ray)
				then
					pulse(s, warning.Position, cfg.radius)
					hit(boss, s, hooks, goal, cfg, cfg.damage, true)
				end
				warning:Destroy()
			end
		else
			mark(boss, s, hooks, s.root.Position, cfg.radius)
			for _, at in cfg.contacts do
				if not waitUntil(boss, s, start, at) then
					break
				end
				hit(
					boss,
					s,
					hooks,
					s.root.Position,
					cfg,
					cfg.damage / #cfg.contacts,
					name == "relentlesswhirlwindspin"
				)
			end
			if name == "relentlesswhirlwindspin" and waitUntil(boss, s, start, cfg.duration) then
				hooks.act(boss, "relentlesswhirlwindpierce", cfg.pierceDuration)
				boss.busyUntil = os.clock() + cfg.pierceDuration
				local pierce = os.clock()
				if waitUntil(boss, s, pierce, cfg.pierceAt) then
					hit(
						boss,
						s,
						hooks,
						s.root.Position,
						{ radius = 9, halfAngle = 30 },
						cfg.pierceDamage
					)
				end
				endAfter(boss, s, pierce, cfg.pierceDuration)
				return
			end
		end
		endAfter(boss, s, start, cfg.duration)
	end)
end
return KnightAbilities
