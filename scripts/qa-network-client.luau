--!nocheck
-- Temporary StarterPlayerScripts LocalScript for StudioTestService's coco-network-v1 session.
local STS = game:GetService("StudioTestService")
if
	not game.RunService:IsStudio()
	or (not script:GetAttribute("Solo") and STS:GetTestArgs() ~= "coco-network-v1")
then
	return
end
local p = game.Players.LocalPlayer
local Shared = game.ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared:WaitForChild("MineNet"))
local R = require(Shared.Remotes)
local folder = game.ReplicatedStorage:WaitForChild("QANetwork")
local rpc = folder:WaitForChild("RPC")
local ready = folder:WaitForChild("Ready")
local client = p.PlayerScripts:WaitForChild("Client")
p:WaitForChild("ClientDebug")
local Motion = require(client.Motion)
local packets, ids, largestPacket, confirmations = 0, {}, 0, {}
local watched, removedAt = {}, {}
local moving, observing
local motion = { delays = {}, errors = {} }
local attackAt = 0
R.unreliable(Net.REMOTE).OnClientEvent:Connect(function(packet)
	packets += 1
	largestPacket = math.max(largestPacket, buffer.len(packet))
	for _, id in Net.decode(packet, workspace:GetServerTimeNow()) or {} do
		ids[tostring(id)] = true
	end
end)
R.event("HitConfirm").OnClientEvent:Connect(function(model, amount, critical, result)
	table.insert(
		confirmations,
		{ amount = amount, result = result, seconds = os.clock() - attackAt }
	)
end)
local function watch(part)
	watched[part.Name] = part
	part.AncestryChanged:Connect(function(_, parent)
		if not parent then
			removedAt[part.Name] = workspace:GetServerTimeNow()
		end
	end)
end
rpc.OnClientInvoke = function(op, a, b)
	if op == "creative" then
		if not p:GetAttribute("Creative") then
			R.event("Creative"):FireServer("toggle")
		end
		return true
	elseif op == "watch" then
		local f = workspace:WaitForChild("QANetworkBlocks")
		for _, name in a do
			watch(assert(f:WaitForChild(name, 8), name))
		end
		return true
	elseif op == "watchBulk" then
		local f = workspace:WaitForChild("QANetworkBlocks")
		local deadline = os.clock() + 12
		repeat
			local count = 0
			for _, part in f:GetChildren() do
				if part.Name:sub(1, 4) == "Bulk" then
					if not watched[part.Name] then
						watch(part)
					end
					count += 1
				end
			end
			if count >= a then
				return count
			end
			task.wait(0.1)
		until os.clock() > deadline
		error("Bulk parts did not stream")
	elseif op == "state" then
		local f = workspace:FindFirstChild("QANetworkBlocks")
		local alive = {}
		for name, part in watched do
			alive[name] = part.Parent ~= nil
		end
		return {
			alive = alive,
			removedAt = removedAt,
			packets = packets,
			largestPacket = largestPacket,
			ids = ids,
			lateExists = f and f:FindFirstChild("Late") ~= nil,
			motion = motion,
			hits = confirmations,
		}
	elseif op == "dig" then
		local part = a
		task.delay(math.max(0, b - workspace:GetServerTimeNow()), function()
			R.event("DigStart"):FireServer(part, part.Position + Vector3.new(0, part.Size.Y / 2, 0))
		end)
		return true
	elseif op == "move" then
		local base, start = a, b
		moving = game.RunService.Heartbeat:Connect(function()
			local t = workspace:GetServerTimeNow() - start
			local root = p.Character.HumanoidRootPart
			root.CFrame = CFrame.new(base + Vector3.new(math.sin(t * 1.3) * 8, 0, 0))
			root.AssemblyLinearVelocity = Vector3.zero
		end)
		return true
	elseif op == "observe" then
		local other = game.Players:GetPlayerByUserId(a)
		local path = b
		observing = game.RunService.RenderStepped:Connect(function()
			local at = Motion.viewTime(other.Character)
			if at then
				table.insert(motion.delays, workspace:GetServerTimeNow() - at)
				local t = workspace:GetServerTimeNow() - path.start
				if t > 0.5 then
					local expected = path.base.X + math.sin(t * 1.3) * 8
					table.insert(
						motion.errors,
						math.abs(other.Character.HumanoidRootPart.Position.X - expected)
					)
				end
			end
		end)
		return true
	elseif op == "finishObserve" then
		if observing then
			observing:Disconnect()
			observing = nil
		end
		return true
	elseif op == "stop" then
		if moving then
			moving:Disconnect()
			moving = nil
		end
		return p.Character.HumanoidRootPart.Position
	elseif op == "stopError" then
		local other = game.Players:GetPlayerByUserId(a)
		return math.abs(other.Character.HumanoidRootPart.Position.X - b.X)
	elseif op == "hit" then
		local target = game.Players:GetPlayerByUserId(a).Character
		R.event("SelectSlot"):FireServer(1)
		task.wait(0.8)
		attackAt = os.clock()
		R.event("Attack"):FireServer(
			(target.HumanoidRootPart.Position - p.Character.Head.Position).Unit,
			false,
			target,
			Motion.viewTime(target)
		)
		return true
	end
end
ready:FireServer()
print("[QANetwork] client ready " .. p.Name)
