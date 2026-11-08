--!nocheck
-- Temporary, read-only ReplicatedFirst startup observer. Does not delay loading.
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local report = { seen = false, rotating = false, samples = 0, finished = false, labels = {} }
local function observe(gui)
	if gui.Name ~= "ArrivalLoading" or report.seen then
		return
	end
	report.seen = true
	task.spawn(function()
		local firstRotation = nil
		for _ = 1, 300 do
			if not gui.Parent then
				break
			end
			local spinner = gui:FindFirstChild("LoadingSpinner", true)
			if spinner then
				report.samples += 1
				report.segments = #spinner:GetChildren()
				report.size = { spinner.AbsoluteSize.X, spinner.AbsoluteSize.Y }
				firstRotation = firstRotation or spinner.Rotation
				if math.abs(spinner.Rotation - firstRotation) > 1 then
					report.rotating = true
				end
				local panel = spinner.Parent
				local pos = spinner.AbsolutePosition - panel.AbsolutePosition
				report.bounded = pos.X >= 0
					and pos.Y >= 0
					and pos.X + spinner.AbsoluteSize.X <= panel.AbsoluteSize.X
					and pos.Y + spinner.AbsoluteSize.Y <= panel.AbsoluteSize.Y
			end
			local title = gui:FindFirstChild("Title", true)
			if title then
				report.labels[title.Text] = true
			end
			task.wait(0.1)
		end
		report.finished = not gui.Parent and player:GetAttribute("LoadingBlocked") == false
		player:SetAttribute(
			"QAStartupObservation",
			game:GetService("HttpService"):JSONEncode(report)
		)
		script:Destroy()
	end)
end
playerGui.ChildAdded:Connect(observe)
for _, gui in playerGui:GetChildren() do
	observe(gui)
end
