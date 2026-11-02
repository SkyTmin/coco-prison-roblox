--!nocheck
-- Live Moth encounter, owner in Creative, no attacks/rewards; restores the character position.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local player = game.Players:GetPlayers()[1]
assert(player and player:GetAttribute("Creative") == true)
local character = player.Character
local returnTo = character:GetPivot()
local result = Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAMothLive", "running", game.ServerStorage
local boss = workspace.Boss_mole
local root = boss.PrimaryPart
local initial = root.Position
local initialDesc = #boss:GetDescendants()
character:PivotTo(CFrame.lookAt(initial + Vector3.new(0, 1, -9), initial))
task.spawn(function()
	local samples, unanchored, failures, actions, trace = 0, 0, {}, {}, {}
	local minY,maxY=initial.Y,initial.Y
	local ok, err = xpcall(function()
		local deadline = os.clock() + 90
		while os.clock() < deadline do
			task.wait(0.2)
			samples += 1
			local model = workspace:FindFirstChild("Boss_mole")
			assert(model == boss and root:IsDescendantOf(workspace), "boss assembly disappeared/rebuilt")
			table.insert(trace,{p={root.Position.X,root.Position.Y,root.Position.Z},v=root.AssemblyLinearVelocity.Y,state=boss.Humanoid:GetState().Name,action=boss:GetAttribute("Action"),anchored=root.Anchored,collide=root.CanCollide})
			if #trace>90 then table.remove(trace,1) end
			minY,maxY=math.min(minY,root.Position.Y),math.max(maxY,root.Position.Y)
			for _,value in {root.CFrame:GetComponents()} do assert(value==value and math.abs(value)<math.huge,"non-finite root transform") end
			assert(math.abs(root.Position.Y - initial.Y) < 15, "boss left arena vertical bounds "..tostring(root.Position))
			assert(#model:GetDescendants() == initialDesc, "boss lost rendered parts")
			local count = 0
			for _, child in workspace:GetChildren() do
				if child.Name == boss.Name then count += 1 end
			end
			assert(count == 1, "duplicate live boss")
			actions[model:GetAttribute("Action") or "none"] = true
			if not root.Anchored then
				unanchored += 1
				assert(root:GetNetworkOwner() == nil and not root:GetNetworkOwnershipAuto(), "client owns boss")
			end
		end
		assert(maxY-minY>3.8,"no actual flight lift")
        assert(unanchored > 20, "not enough physical movement samples")
		for _, action in {"shadowlight", "moonssight", "meteorrain", "midnight", "startshoot", "descendshot", "descendend"} do
			assert(actions[action], "special not observed: " .. action)
		end
	end, debug.traceback)
	if player.Character == character and character.Parent then character:PivotTo(returnTo) end
	if not ok then table.insert(failures, err) end
	result.Value = game.HttpService:JSONEncode({status=if ok then "PASS" else "FAIL", samples=samples, unanchored=unanchored, actions=actions, failures=failures,trace=trace,minY=minY,maxY=maxY})
end)
return "started 90-second live encounter"
