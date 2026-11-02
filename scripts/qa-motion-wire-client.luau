--!nocheck
assert(game.RunService:IsStudio() and game.RunService:IsClient())
local p = game.Players.LocalPlayer
local signal = game.ReplicatedStorage:WaitForChild("QAMotionProbe")
local humanoid = p.Character.Humanoid
local moving = true
game.RunService:BindToRenderStep("QAMotionDrive", Enum.RenderPriority.Last.Value, function()
	humanoid:Move(if moving then Vector3.new(1, 0, 0) else Vector3.zero, false)
end)
task.wait(1.2)
moving = false
signal:FireServer("stop", workspace:GetServerTimeNow())
task.wait(1)
game.RunService:UnbindFromRenderStep("QAMotionDrive")
humanoid:Move(Vector3.zero)
-- Marker is an extra ignored argument to production Motion; only this QA listener reads it.
local remote = require(game.ReplicatedStorage.Shared.Remotes).unreliable("Motion")
local function burst(count, marker)
	local root = p.Character.HumanoidRootPart
	local base, stamp = root.Position, workspace:GetServerTimeNow()
	local look = root.CFrame.LookVector
	for i = 1, count do
		local offset = Vector3.new((i * 37 % 101) * 0.002, 0, (i * 17 % 103) * 0.002)
		remote:FireServer(base + offset, math.atan2(-look.X, -look.Z), stamp + i * 0.0001, marker)
	end
end
task.wait(0.17)
burst(5, "short")
task.wait(0.3)
burst(100, "flood")
task.wait(0.3)
signal:FireServer("done")
