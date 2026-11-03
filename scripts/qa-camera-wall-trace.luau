--!nocheck
-- Read-only gameplay trace. Start with menu closed in first person, press against a mine block,
-- then stand still and mine. Open menus and third person are counted as INVALID, never as a pass.
local RunService = game:GetService("RunService")
assert(RunService:IsClient(), "Client only")
local player = game.Players.LocalPlayer
assert(not (_G.CameraWallTraceQA and _G.CameraWallTraceQA.running), "Trace already running")
local result = {
	running = true,
	accepted = 0,
	skipped = {},
	rootStepMax = 0,
	cameraRelativeStepMax = 0,
	cameraAngleMax = 0,
	stableMouseAngleMax = 0,
	focusOffsetStepMax = 0,
	rows = {},
}
_G.CameraWallTraceQA = result
task.spawn(function()
	local previous
	local start = os.clock()
	while os.clock() - start < 10 do
		local dt = RunService.RenderStepped:Wait()
		local camera, character = workspace.CurrentCamera, player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local invalid = if not camera
				or not root
				or not humanoid
			then "missing_camera_or_character"
			elseif camera.CameraType ~= Enum.CameraType.Custom then "not_gameplay_camera"
			elseif player.CameraMode ~= Enum.CameraMode.LockFirstPerson then "not_first_person"
			elseif player:GetAttribute("LoadingBlocked") == true then "loading"
			elseif humanoid.Health <= 0 then "dead"
			else nil
		if invalid then
			result.skipped[invalid] = (result.skipped[invalid] or 0) + 1
			previous = nil
			continue
		end
		local row = {
			t = os.clock() - start,
			dt = dt,
			root = root.Position,
			relative = camera.CFrame.Position - root.Position,
			look = camera.CFrame.LookVector,
			focus = camera.Focus.Position - root.Position,
			mouse = game.UserInputService:GetMouseDelta(),
			velocity = root.AssemblyLinearVelocity,
			state = humanoid:GetState().Name,
			zoom = (camera.CFrame.Position - camera.Focus.Position).Magnitude,
		}
		if previous then
			local rootStep = (row.root - previous.root).Magnitude
			local relativeStep = (row.relative - previous.relative).Magnitude
			local angle = math.deg(math.acos(math.clamp(row.look:Dot(previous.look), -1, 1)))
			result.rootStepMax = math.max(result.rootStepMax, rootStep)
			result.cameraRelativeStepMax = math.max(result.cameraRelativeStepMax, relativeStep)
			result.cameraAngleMax = math.max(result.cameraAngleMax, angle)
			result.focusOffsetStepMax =
				math.max(result.focusOffsetStepMax, (row.focus - previous.focus).Magnitude)
			if row.mouse.Magnitude < 0.01 and previous.mouse.Magnitude < 0.01 then
				result.stableMouseAngleMax = math.max(result.stableMouseAngleMax, angle)
			end
			if relativeStep > 0.03 or rootStep > 0.08 or angle > 0.2 then
				if #result.rows < 80 then
					table.insert(
						result.rows,
						{
							t = row.t,
							dt = dt,
							rootStep = rootStep,
							relativeStep = relativeStep,
							angle = angle,
							state = row.state,
							velocity = tostring(row.velocity),
							root = tostring(row.root),
							relative = tostring(row.relative),
							focus = tostring(row.focus),
							mouse = tostring(row.mouse),
							zoom = row.zoom,
						}
					)
				end
			end
		end
		result.accepted += 1
		previous = row
	end
	result.running = false
	result.valid = result.accepted >= 30
	print("[CameraWallTraceQA] " .. game.HttpService:JSONEncode(result))
end)
return "Read-only 10 second first-person trace started; poll _G.CameraWallTraceQA."
