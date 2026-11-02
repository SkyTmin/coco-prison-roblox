--!nocheck
-- Live UndeadKing encounter, owner in Creative, no attacks/rewards; restores the character position.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local player = game.Players:GetPlayers()[1]
assert(player and player:GetAttribute("Creative") == true)
local character = player.Character
local returnTo = character:GetPivot()
local result = Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAUndeadKingLive", "running", game.ServerStorage
local boss = workspace.Boss_un_king
local root = boss.PrimaryPart
local initial = root.Position
local initialDesc = #boss:GetDescendants()
character:PivotTo(CFrame.lookAt(initial + Vector3.new(0, 1, -9), initial))
task.spawn(function()
	local samples, unanchored, failures, actions, trace = 0, 0, {}, {}, {}
	local minY,maxY=initial.Y,initial.Y
	local peaks={UndeadGhoul=0,UndeadSkull=0,UndeadSword=0}
	local ok, err = xpcall(function()
		local deadline = os.clock() + 90
		while os.clock() < deadline do
			task.wait(0.2)
			samples += 1
			local model = workspace:FindFirstChild("Boss_un_king")
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
			assert(model:GetAttribute("Shielded")~=true,"boss became immune")
			local counts={UndeadGhoul=0,UndeadSkull=0,UndeadSword=0}
			for _,e in workspace:GetChildren()do if e.Name=="UndeadKingEncounter"then
				for _,m in e:GetChildren()do
					if m:IsA("Model")and m.PrimaryPart and counts[m.Name] and(m.PrimaryPart.Position-initial).Magnitude<100 then
						local h=m:FindFirstChildOfClass("Humanoid")
						if not h or h.Health>0 then counts[m.Name]+=1 end
					end
				end
			end end
			assert(counts.UndeadGhoul<=4 and counts.UndeadSkull<=4,"summon cap exceeded")
			for k,n in counts do peaks[k]=math.max(peaks[k],n)end
			if not root.Anchored then
				unanchored += 1
				assert(root:GetNetworkOwner() == nil and not root:GetNetworkOwnershipAuto(), "client owns boss")
			end
		end
		assert(maxY-minY<2,"unexpected vertical drift")
        assert(unanchored > 20, "not enough physical movement samples")
		for _, action in {"skill3", "skill2", "swordcall", "skill1"} do
			assert(actions[action], "special not observed: " .. action)
		end
	end, debug.traceback)
	if player.Character == character and character.Parent then character:PivotTo(returnTo) end
	if not ok then table.insert(failures, err) end
	result.Value = game.HttpService:JSONEncode({status=if ok then "PASS" else "FAIL", samples=samples, unanchored=unanchored, actions=actions, failures=failures,trace=trace,minY=minY,maxY=maxY,summonPeaks=peaks})
end)
return "started 90-second live encounter"
