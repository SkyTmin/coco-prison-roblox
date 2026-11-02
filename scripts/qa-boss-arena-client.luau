--!nocheck
-- Observe the actual streamed arena bosses. No local surrogate rigs.
-- Set workspace.QAArenaCamera=true only for a presentation view; false uses the normal camera.
assert(game.RunService:IsStudio() and game.RunService:IsClient())
local player = game.Players.LocalPlayer
local reports, tracked = {}, {}
local camera = workspace.CurrentCamera
local kind, cf = camera.CameraType, camera.CFrame
local cameraWasOverridden = false
local lastId
local connection = game.RunService.RenderStepped:Connect(function(dt)
	local id = workspace:GetAttribute("QALiveBossId")
	if not id then
		return
	end
	local r = reports[id]
	if not r then
		r = {
			renderFrames = 0,
			framesOver100ms = 0,
			actions = {},
			movingJoints = {},
			deathFrames = 0,
			deathsMovingJoints = {},
			modelsSeen = 0,
			maxCopies = 0,
		}
		reports[id] = r
	end
	r.renderFrames += 1
	if dt > 0.1 then
		r.framesOver100ms += 1
	end
	local copies = 0
	for _, v in workspace:GetChildren() do
		if v.Name == "Boss_" .. id then
			copies += 1
		end
	end
	r.maxCopies = math.max(r.maxCopies, copies)
	local m = workspace:FindFirstChild("Boss_" .. id)
	if m and m.PrimaryPart then
		local row = tracked[m]
		if not row then
			row = { motors = {}, last = {} }
			for _, v in m:GetDescendants() do
				if v:IsA("Motor6D") then
					row.motors[v.Name] = v
				end
			end
			tracked[m] = row
			r.modelsSeen += 1
		end
		local action = m:GetAttribute("Action") or "idle"
		r.actions[action] = true
		if action == "death" then
			r.deathFrames += 1
		end
		for name, motor in row.motors do
			local before = row.last[name]
			if before then
				local delta = before:ToObjectSpace(motor.Transform)
				local _, angle = delta:ToAxisAngle()
				if delta.Position.Magnitude > 0.001 or math.abs(angle) > 0.002 then
					r.movingJoints[name] = true
					if action == "death" then
						r.deathsMovingJoints[name] = true
					end
				end
			end
			row.last[name] = motor.Transform
		end
		if workspace:GetAttribute("QAArenaCamera") then
			cameraWasOverridden = true
			camera.CameraType = Enum.CameraType.Scriptable
			local target = m.PrimaryPart.Position + Vector3.new(0, 1, 0)
			camera.CFrame = CFrame.lookAt(target + Vector3.new(20, 11, 27), target)
		elseif cameraWasOverridden then
			cameraWasOverridden = false
			camera.CameraType = kind
		end
	end
	if lastId ~= id or r.renderFrames % 30 == 0 then
		lastId = id
		player:SetAttribute("QAArenaClientReports", game.HttpService:JSONEncode(reports))
	end
end)
script.Destroying:Connect(function()
	connection:Disconnect()
	player:SetAttribute("QAArenaClientReports", game.HttpService:JSONEncode(reports))
	camera.CameraType, camera.CFrame = kind, cf
end)
