--!nocheck
-- Client fixture: no real player, profile, camera, movement or map mutation.
-- Three disposable local rigs near the owner compare animated body collisions with rigid
-- head/root collisions. Poll _G.CameraWallPhysicsQA. Free travel must prove local simulation works.
local RunService = game:GetService("RunService")
assert(RunService:IsClient(), "Run this in a Play client")
assert(not (_G.CameraWallPhysicsQA and _G.CameraWallPhysicsQA.running), "QA already running")
local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Body = require(Shared.Models.player)
local Swings = require(Shared.SwingAnimations)
local playerRoot = assert(game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart"))
local anchor = playerRoot.Position + Vector3.new(0, 45, 25)
local report =
	{ running = true, kind = "temporary client rigs; not live camera acceptance", results = {} }
_G.CameraWallPhysicsQA = report
local folder = Instance.new("Folder")
folder.Name = "QA_CameraWallPhysics"
folder.Parent = workspace
local fixtures = {}
local connection
local function part(name, size, cf, parent)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.CanTouch, p.CanQuery = false, false
	p.Parent = parent
	return p
end
local function vec(a)
	return Vector3.new(a[1], a[2], a[3])
end
local function make(mode, index)
	local base = anchor + Vector3.new((index - 2) * 16, 0, 0)
	local floor =
		part("Floor", Vector3.new(12, 2, 24), CFrame.new(base - Vector3.new(0, 1, 0)), folder)
	floor.Anchored = true
	local wall =
		part("Wall", Vector3.new(12, 14, 2), CFrame.new(base + Vector3.new(0, 7, -7)), folder)
	wall.Anchored = true -- front surface z = -6: more than five studs of free travel first
	-- Existing production groups only. Mobs never collide with Players, even when the
	-- Humanoid restores torso.CanCollide=true. Root/proxy stay Default and hit this fixture.
	floor.CollisionGroup, wall.CollisionGroup = "Players", "Players"
	local model = Instance.new("Model")
	model.Name = mode
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = Body.hipHeight * Body.px
	humanoid.AutoRotate = false
	humanoid.WalkSpeed = 16
	humanoid.Parent = model
	Instance.new("Animator").Parent = humanoid
	local parts, centres, joints = {}, {}, {}
	centres.HumanoidRootPart = vec(Body.root.pos) * Body.px
	local root = part(
		"HumanoidRootPart",
		Vector3.new(2, Body.root.size[2] * Body.px, 1),
		CFrame.new(base + centres.HumanoidRootPart),
		model
	)
	root.Transparency = 1
	parts.HumanoidRootPart = root
	model.PrimaryPart = root
	for name, data in Body.parts do
		centres[name] = vec(data.pos) * Body.px
		local p = part(name, vec(data.size) * Body.px, CFrame.new(base + centres[name]), model)
		p.CanCollide = mode == "animated"
			and (name == "Head" or name == "UpperTorso" or name == "LowerTorso")
		p.CollisionGroup = if mode == "animated" then "Default" else "Mobs"
		parts[name] = p
	end
	for _, data in Body.joints do
		local name, from, to, pivot = data[1], data[2], data[3], vec(data[4]) * Body.px
		local motor = Instance.new("Motor6D")
		motor.Name, motor.Part0, motor.Part1 = name, parts[from], parts[to]
		motor.C0, motor.C1 = CFrame.new(pivot - centres[from]), CFrame.new(pivot - centres[to])
		motor.Parent = parts[to]
		joints[name] = motor
	end
	if mode == "rigid_head" then
		local head = parts.Head
		local proxy = part("HeadCollision", head.Size, head.CFrame, model)
		proxy.Transparency, proxy.Massless = 1, true
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = root, proxy, proxy
	end
	model.Parent = folder
	local row =
		{ mode = mode, altitude = base.Y, phases = {}, rootInitial = tostring(root.Position) }
	table.insert(report.results, row)
	table.insert(
		fixtures,
		{ root = root, humanoid = humanoid, joints = joints, model = model, row = row }
	)
end
task.spawn(function()
	local ok, err = xpcall(function()
		for index, mode in { "animated", "rigid_head", "root_only" } do
			make(mode, index)
		end
		local started = os.clock()
		local currentPhase = "settle"
		connection = RunService.PreSimulation:Connect(function()
			local elapsed = os.clock() - started
			currentPhase = if elapsed < 2
				then "settle"
				elseif elapsed < 5 then "walk_into_wall"
				elseif elapsed < 9 then "walk_and_mine"
				elseif elapsed < 12 then "stationary_mine"
				else "stationary_idle"
			local moving = currentPhase == "walk_into_wall" or currentPhase == "walk_and_mine"
			local swinging = currentPhase == "walk_and_mine" or currentPhase == "stationary_mine"
			for _, f in fixtures do
				f.humanoid:Move(if moving then Vector3.new(0, 0, -1) else Vector3.zero, false)
				for name, motor in f.joints do
					motor.Transform = if swinging
						then (
							Swings.sample(Swings.animations.slam, name, (elapsed % 0.3) / 0.3)
							or CFrame.identity
						)
						else CFrame.identity
				end
			end
		end)
		while os.clock() - started < 15 do
			RunService.PostSimulation:Wait()
			for _, f in fixtures do
				local pos = f.root.Position
				local p = f.row.phases[currentPhase]
				if not p then
					p = {
						frames = 0,
						minY = pos.Y,
						maxY = pos.Y,
						minZ = pos.Z,
						maxZ = pos.Z,
						stepMax = 0,
						reverseSteps = 0,
						stateChanges = 0,
						vyMax = 0,
						previous = pos,
						state = f.humanoid:GetState().Name,
					}
					f.row.phases[currentPhase] = p
				end
				p.frames += 1
				p.minY, p.maxY = math.min(p.minY, pos.Y), math.max(p.maxY, pos.Y)
				p.minZ, p.maxZ = math.min(p.minZ, pos.Z), math.max(p.maxZ, pos.Z)
				local delta = pos - p.previous
				p.stepMax = math.max(p.stepMax, delta.Magnitude)
				if delta.Z > 0.01 then
					p.reverseSteps += 1
				end
				p.vyMax = math.max(p.vyMax, math.abs(f.root.AssemblyLinearVelocity.Y))
				local state = f.humanoid:GetState().Name
				if state ~= p.state then
					p.stateChanges += 1
				end
				p.state, p.previous = state, pos
			end
		end
		for _, f in fixtures do
			f.row.colliders = {}
			for _, p in f.model:GetChildren() do
				if p:IsA("BasePart") and p.CanCollide then
					table.insert(f.row.colliders, p.Name)
				end
			end
			for _, phase in f.row.phases do
				phase.yRange, phase.zRange = phase.maxY - phase.minY, phase.maxZ - phase.minZ
				phase.previous, phase.minY, phase.maxY, phase.minZ, phase.maxZ =
					nil, nil, nil, nil, nil
			end
			local travel = f.row.phases.walk_into_wall
			f.row.valid = travel ~= nil and travel.zRange > 2 and travel.frames >= 10
		end
	end, debug.traceback)
	if connection then
		connection:Disconnect()
	end
	folder:Destroy()
	report.running = false
	if not ok then
		report.error = tostring(err)
	end
	print("[CameraWallPhysicsQA] " .. game.HttpService:JSONEncode(report))
end)
return "Temporary local rig QA started; read _G.CameraWallPhysicsQA after 16 seconds. No live player changed."
