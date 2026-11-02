--!nocheck
-- Local same-PC diagnostic; no profile/production behavior changes.
if not game.RunService:IsStudio() or game.StudioTestService:GetTestArgs() ~= "coco-latency-v1" then
	return
end
local p = game.Players.LocalPlayer
p:WaitForChild("ClientDebug")
local folder = game.ReplicatedStorage:WaitForChild("QALatency")
local rpc, ack = folder:WaitForChild("RPC"), folder:WaitForChild("Ack")
local frames, renderIntervals = {}, {}
game.RunService.RenderStepped:Connect(function(dt)
	table.insert(renderIntervals, dt * 1000)
end)
rpc.OnClientInvoke = function(op, names)
	if op == "watch" then
		local blocks = workspace:WaitForChild("QALatencyBlocks")
		for _, name in names do
			local part = assert(blocks:WaitForChild(name, 10), name)
			part.AncestryChanged:Connect(function(_, parent)
				if parent then
					return
				end
				local at = os.clock()
				ack:FireServer(
					name,
					DateTime.now().UnixTimestampMillis,
					workspace:GetServerTimeNow()
				)
				game.RunService.RenderStepped:Once(function()
					frames[name] = (os.clock() - at) * 1000
				end)
			end)
		end
		return true
	elseif op == "state" then
		return { frames = frames, renderIntervals = renderIntervals }
	end
end
ack:FireServer("ready")
