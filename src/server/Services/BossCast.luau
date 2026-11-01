--!strict
-- Shared cancellable action/movement primitives for authored bosses. No defensive immunity [owner 02.11].
local BossPhysics = require(script.Parent.BossPhysics)
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local BossCast = {}
local casts: { [any]: any } = {}
local FLAT = Vector3.new(1, 0, 1)
local COLOR = Color3.fromRGB(150, 68, 59)
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
		boss.humanoid.WalkSpeed, boss.humanoid.AutoRotate = s.speed, s.rotate
		BossPhysics.restore(s.root, s.anchored)
	end
end
function BossCast.Clear(boss: any)
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
	recovery: number?
): any
	BossCast.Clear(boss)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "BossCast", workspace
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
	if recovery and recovery > 0 then
		boss.nextAbilityAt = math.max(boss.nextAbilityAt or 0, boss.busyUntil + recovery)
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
local function mark(
	boss: any,
	s: any,
	hooks: any,
	p: Vector3,
	radius: number,
	color: Color3?
): BasePart
	local at = floorAt(boss, p, params(boss, s, hooks))
	local m = hooks.telegraph(
		Vector3.new(radius * 2, 0.12, radius * 2),
		CFrame.new(at),
		true,
		color or COLOR
	)
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
local function pulse(s: any, at: Vector3, radius: number, color: Color3?)
	-- Eight matte fragments, outside the boss model. No lights or changes to its rendered parts.
	for i = 1, 8 do
		local a = i * math.pi / 4
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local p = Instance.new("Part")
		p.Name, p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery =
			"BossImpact", true, false, false, false
		p.Size, p.Color, p.Material =
			Vector3.new(0.32, 0.22, 0.5), color or COLOR, Enum.Material.SmoothPlastic
		p.CFrame, p.Parent = CFrame.new(at + dir), s.folder
		Debris:AddItem(p, 0.5)
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
	if not root:IsDescendantOf(workspace) then
		return root.Position, true
	end
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
	-- Clamping to the arena must never turn a short dash into a cross-map cast.
	if delta.Magnitude > range then
		delta = delta.Unit * range
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
	moveEnd: number,
	onStep: ((Vector3, Vector3) -> ())?
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
			local previous = s.root.Position
			s.root.CFrame = CFrame.new(nextPoint) * rotation
			if onStep then
				onStep(previous, nextPoint)
			end
		end
		if u >= 1 then
			return true
		end
		RunService.Heartbeat:Wait()
	end
	return false
end

BossCast.Alive = alive
BossCast.Begin = begin
BossCast.Finish = finish
BossCast.Params = params
BossCast.FloorAt = floorAt
BossCast.Mark = mark
BossCast.Hit = hit
BossCast.Pulse = pulse
BossCast.WaitUntil = waitUntil
BossCast.EndAfter = endAfter
BossCast.Destination = destination
BossCast.Travel = travel
return BossCast
