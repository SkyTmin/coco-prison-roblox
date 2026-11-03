--!nocheck
-- Native server fixture using the actual production factory/groups. No player/profile mutation.
-- Read ServerStorage.QACameraBodyNative.Value after 15 seconds. Temporary geometry is removed.
assert(
	game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer(),
	"Studio server only"
)
local RunService = game:GetService("RunService")
local Services = game.ServerScriptService.Server.Services
local BlockBody = require(Services.BlockBody)
local Groups = require(Services.CollisionGroups)
local Swings = require(game.ReplicatedStorage.Shared.SwingAnimations)
local old = game.ServerStorage:FindFirstChild("QACameraBodyNative")
if old then
	assert(old.Value ~= "running", "fixture already running")
	old:Destroy()
end
local output = Instance.new("StringValue")
output.Name, output.Value, output.Parent = "QACameraBodyNative", "running", game.ServerStorage
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QA_CameraBodyNative", workspace
local owner = game.Players:GetPlayers()[1]
local origin = (owner and owner.Character and owner.Character:GetPivot().Position or Vector3.zero)
	+ Vector3.new(0, 70, 0)
local fixtures, checks = {}, {}
local connection
local function block(class, name, size, position)
	local p = Instance.new(class)
	p.Name, p.Size, p.Position, p.Anchored = name, size, position, true
	p.Parent = folder
	return p
end
local function make(kind, i)
	local base = origin + Vector3.new(18 * (i - 2), 0, 0)
	block("Part", "Floor", Vector3.new(14, 2, 28), base - Vector3.new(0, 1, 0))
	if kind == "wall" then
		block("Part", "Wall", Vector3.new(14, 14, 2), base + Vector3.new(0, 7, -9))
	elseif kind == "ceiling" or kind == "legacy_ceiling" then
		block("Part", "Ceiling", Vector3.new(14, 2, 28), base + Vector3.new(0, 7.2, 0))
	elseif kind == "ladder" then
		block("TrussPart", "Ladder", Vector3.new(2, 18, 2), base + Vector3.new(0, 9, -9))
	end
	local model = BlockBody.build("QA_" .. kind, kind ~= "legacy_ceiling")
	Groups.player(model)
	local root, humanoid = model.PrimaryPart, model:FindFirstChildOfClass("Humanoid")
	model:PivotTo(model:GetPivot() + base)
	humanoid.AutoRotate, humanoid.WalkSpeed = false, 16
	model.Parent = folder
	root:SetNetworkOwner(nil)
	local motors = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			motors[d.Name] = d
		end
	end
	local row = {
		kind = kind,
		frames = 0,
		initialY = root.Position.Y,
		initialZ = root.Position.Z,
		minZ = root.Position.Z,
		maxY = root.Position.Y,
		maxHeadTop = -math.huge,
		stateClimbing = false,
		stateJumping = false,
		jumpPower = humanoid.JumpPower,
		jumpHeight = humanoid.JumpHeight,
		useJumpPower = humanoid.UseJumpPower,
		movingMineStepMax = 0,
		stationaryMineStepMax = 0,
	}
	table.insert(fixtures, {
		base = base,
		kind = kind,
		model = model,
		root = root,
		humanoid = humanoid,
		motors = motors,
		row = row,
	})
end
task.spawn(function()
	local ok, err = xpcall(function()
		for i, kind in { "wall", "ceiling", "ladder", "free_jump", "legacy_ceiling" } do
			make(kind, i)
		end
		local started = os.clock()
		connection = RunService.PreSimulation:Connect(function()
			local t = os.clock() - started
			for _, f in fixtures do
				local moving = t >= 2 and (f.kind == "ladder" or (f.kind == "wall" and t < 8))
				f.humanoid:Move(if moving then Vector3.new(0, 0, -1) else Vector3.zero, false)
				if
					(f.kind == "ceiling" or f.kind == "legacy_ceiling" or f.kind == "free_jump")
					and t >= 3
					and t < 10
					and t % 1 < 0.2
				then
					f.humanoid.Jump = true
				end
				for name, motor in f.motors do
					motor.Transform = if f.kind == "wall"
							and t >= 4
							and t < 11
						then (
							Swings.sample(Swings.animations.slam, name, t % 0.3 / 0.3)
							or CFrame.identity
						)
						else CFrame.identity
				end
			end
		end)
		while os.clock() - started < 14 do
			RunService.PostSimulation:Wait()
			local t = os.clock() - started
			for _, f in fixtures do
				local row, pos = f.row, f.root.Position
				row.frames += 1
				row.minZ, row.maxY = math.min(row.minZ, pos.Z), math.max(row.maxY, pos.Y)
				if t >= 2 and t < 3 then
					row.settledY = pos.Y
				end
				if t >= 3 then
					row.jumpMaxY = math.max(row.jumpMaxY or -math.huge, pos.Y)
				end
				local head = f.model:FindFirstChild("HeadCollision") or f.model.Head
				row.maxHeadTop = math.max(row.maxHeadTop, head.Position.Y + head.Size.Y / 2)
				row.stateClimbing = row.stateClimbing
					or f.humanoid:GetState() == Enum.HumanoidStateType.Climbing
				row.stateJumping = row.stateJumping
					or f.humanoid:GetState() == Enum.HumanoidStateType.Jumping
				if f.previous then
					local step = (pos - f.previous).Magnitude
					if t > 4.4 and t < 8 then
						row.movingMineStepMax = math.max(row.movingMineStepMax, step)
					end
					if t > 8.4 and t < 11 then
						row.stationaryMineStepMax = math.max(row.stationaryMineStepMax, step)
					end
				end
				f.previous = pos
			end
		end
		local function check(name, pass, detail)
			table.insert(checks, { name = name, pass = pass, detail = detail })
		end
		for _, f in fixtures do
			local r = f.row
			check(
				f.kind .. ": sampled and server simulated",
				r.frames > 30 and f.root:GetNetworkOwner() == nil
			)
			if f.kind ~= "legacy_ceiling" then
				check(
					f.kind .. ": visual torso filtered despite Humanoid CanCollide",
					f.model.UpperTorso.CollisionGroup == "PlayerVisuals"
				)
			end
			if f.kind == "wall" then
				local travel = r.initialZ - r.minZ
				check("walk reached solid wall", travel > 5 and travel < 7.6, travel)
				check(
					"mining against wall has no large frame impulses",
					r.movingMineStepMax < 0.06 and r.stationaryMineStepMax < 0.06,
					{ moving = r.movingMineStepMax, stationary = r.stationaryMineStepMax }
				)
			elseif f.kind == "free_jump" then
				local jumpRise = (r.jumpMaxY or -math.huge) - (r.settledY or math.huge)
				check("jump actually moved root after settling", jumpRise > 0.1, {
					rise = jumpRise,
					jumping = r.stateJumping,
					baseline = r.settledY,
				})
			elseif f.kind == "ceiling" or f.kind == "legacy_ceiling" then
				check(
					f.kind .. ": head stays below solid low ceiling",
					r.maxHeadTop <= f.base.Y + 6.3,
					r.maxHeadTop - f.base.Y
				)
			elseif f.kind == "ladder" then
				check(
					"native Truss climb reached",
					r.stateClimbing and r.maxY - r.initialY > 4,
					r.maxY - r.initialY
				)
			end
		end
		local current, legacy = fixtures[2].row, fixtures[5].row
		local currentRise = current.jumpMaxY - current.settledY
		local legacyRise = legacy.jumpMaxY - legacy.settledY
		check(
			"low ceiling jump restriction matches original body",
			math.abs(currentRise - legacyRise) < 0.15,
			{ current = currentRise, legacy = legacyRise }
		)
	end, debug.traceback)
	if connection then
		connection:Disconnect()
	end
	local rows = {}
	for _, f in fixtures do
		table.insert(rows, f.row)
	end
	folder:Destroy()
	local pass = ok
	for _, c in checks do
		if not c.pass then
			pass = false
		end
	end
	output.Value = game.HttpService:JSONEncode({
		status = if pass then "PASS" else "FAIL",
		checks = checks,
		rows = rows,
		error = if not ok then tostring(err) else nil,
		limitation = "server disposable rigs; live first-person camera and mobile not accepted by this fixture",
	})
end)
return "Started 14-second actual BlockBody server fixture; read ServerStorage.QACameraBodyNative.Value."
