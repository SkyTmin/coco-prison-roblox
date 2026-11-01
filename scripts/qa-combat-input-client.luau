--!nocheck
-- Studio Client, in a safe empty area. Exercises the running input handler, not a second require().
-- No inventory/profile mutations. Call after equipping the tool to inspect.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
local player = game.Players.LocalPlayer
local hook = player:WaitForChild("ClientDebug", 15)
local results = { checks = {} }
local function check(name, ok)
	table.insert(results.checks, { name = name, pass = ok })
	assert(ok, name)
end
hook:Invoke("close")
hook:Invoke("attackHeld", false)
hook:Invoke("holdDig", false)
local camera = workspace.CurrentCamera
local oldType, oldFrame = camera.CameraType, camera.CFrame
camera.CameraType = Enum.CameraType.Scriptable
local eye = player.Character.Head.Position
camera.CFrame = CFrame.lookAt(eye, eye + Vector3.new(0, 1, 0.1)) -- keep auto-dig off any mine block
task.wait(1.5)
local ok, err = pcall(function()
	hook:Invoke("attack")
	local first = hook:Invoke("attackState")
	local swing = hook:Invoke("swingState")
	results.firstPhase = swing.phase
	check("first press starts hand immediately", swing.phase ~= nil)
	task.wait(0.28)
	hook:Invoke("attack")
	swing = hook:Invoke("swingState")
	results.secondPhase = swing.phase
	check("second press starts hand without one-second pause", swing.phase ~= nil)
	local second = hook:Invoke("attackState")
	results.firstAttackAt, results.secondAttackAt = first.lastAt, second.lastAt
	local samples, restarts, lastPhase, longestIdle, idleAt = 0, 0, nil, 0, nil
	hook:Invoke("attackHeld", true)
	local start = os.clock()
	while os.clock() - start < 1.8 do
		game:GetService("RunService").Heartbeat:Wait()
		local phase = hook:Invoke("swingState").phase
		samples += 1
		if phase then
			if not lastPhase or phase < lastPhase then
				restarts += 1
			end
			if idleAt then
				longestIdle = math.max(longestIdle, os.clock() - idleAt)
				idleAt = nil
			end
		else
			idleAt = idleAt or os.clock()
		end
		lastPhase = phase
	end
	if idleAt then
		longestIdle = math.max(longestIdle, os.clock() - idleAt)
	end
	results.cycles, results.samples, results.longestIdle = restarts, samples, longestIdle
	check("holding repeats short cycles", restarts >= 4)
	check("holding has no long idle gap", longestIdle < 0.25)
	hook:Invoke("attackHeld", false)
	task.wait(1.1) -- finish the one permitted buffered damage request and its visual cycle
	check("release finishes and rests", hook:Invoke("swingState").phase == nil)
	hook:Invoke("open", "inventory")
	hook:Invoke("attack")
	check("menu consumes attack input", hook:Invoke("swingState").phase == nil)
end)
hook:Invoke("attackHeld", false)
hook:Invoke("close")
camera.CameraType, camera.CFrame = oldType, oldFrame
assert(ok, err)
return results
