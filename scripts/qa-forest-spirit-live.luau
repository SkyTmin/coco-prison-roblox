--!nocheck
-- Live ForestSpirit encounter, owner in Creative, no attacks/rewards; restores the character position.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local player = game.Players:GetPlayers()[1]
assert(player and player:GetAttribute("Creative") == true)
local character = player.Character
local returnTo = character:GetPivot()
local result = Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAForestSpiritLive", "running", game.ServerStorage
local boss = workspace.Boss_forest_spirit
local root = boss.PrimaryPart
local initial = root.Position
local initialDesc = #boss:GetDescendants()
character:PivotTo(CFrame.lookAt(initial + Vector3.new(0, 1, -24), initial))
task.spawn(function()
	local samples, unanchored, failures, actions, trace = 0, 0, {}, {}, {}
	local minY,maxY=initial.Y,initial.Y
	local peak,settled=nil,false
	local peaks={forest_shaman=0,forest_skull=0,forest_totem=0,forest_explorer=0}
	local ok, err = xpcall(function()
		local started = os.clock()
		local deadline = started + 90
		local waypoint = -1
		while os.clock() < deadline do
			task.wait(0.2)
			-- Exercise chase/ownership between casts. A stationary target in melee reach
			-- otherwise keeps the boss in consecutive anchored attack animations.
			local nextWaypoint = math.floor((os.clock()-started)/8)
			if nextWaypoint ~= waypoint and player.Character == character then
				waypoint = nextWaypoint
				local angle = waypoint*math.pi/2
				local target = initial + Vector3.new(math.sin(angle)*24,1,-math.cos(angle)*24)
				character:PivotTo(CFrame.lookAt(target,initial))
			end
			samples += 1
			local model = workspace:FindFirstChild("Boss_forest_spirit")
			assert(model == boss and root:IsDescendantOf(workspace), "boss assembly disappeared/rebuilt")
			table.insert(trace,{p={root.Position.X,root.Position.Y,root.Position.Z},v=root.AssemblyLinearVelocity.Y,state=boss.Humanoid:GetState().Name,action=boss:GetAttribute("Action"),anchored=root.Anchored,collide=root.CanCollide})
			if #trace>90 then table.remove(trace,1) end
			minY,maxY=math.min(minY,root.Position.Y),math.max(maxY,root.Position.Y)
			if root.Position.Y>=maxY then peak={y=root.Position.Y,state=boss.Humanoid:GetState().Name,action=boss:GetAttribute("Action"),anchored=root.Anchored}end
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
			local counts={forest_shaman=0,forest_skull=0,forest_totem=0,forest_explorer=0}
			for _,e in workspace:GetChildren()do if e.Name=="ForestSpiritEncounter"then
				for _,m in e:GetDescendants()do
					if m:IsA("Model")and m.PrimaryPart and counts[m.Name] and(m.PrimaryPart.Position-initial).Magnitude<100 then
						local h=m:FindFirstChildOfClass("Humanoid")
						if not h or h.Health>0 then counts[m.Name]+=1 end
					end
				end
			end end
			assert(counts.forest_shaman+counts.forest_skull+counts.forest_explorer<=4 and counts.forest_totem<=1,"summon cap exceeded")
			for k,n in counts do peaks[k]=math.max(peaks[k],n)end
			if not root.Anchored then
				unanchored += 1
				assert(root:GetNetworkOwner() == nil and not root:GetNetworkOwnershipAuto(), "client owns boss")
			end
		end
        assert(unanchored > 20, "not enough physical movement samples")
		for _, action in {"attack1","attack2","attack3","attack4","attack5","attack6","attack8"} do
			assert(actions[action], "special not observed: " .. action)
		end
		-- The shared obstacle AI legitimately jumps (55 JumpPower). Verify that it lands
		-- and releases ownership after the encounter instead of forbidding every jump.
		if player.Character==character then character:PivotTo(returnTo)end
		local settleDeadline=os.clock()+16
		repeat
			task.wait(.2)
			settled=not root.Anchored and math.abs(root.Position.Y-initial.Y)<2 and boss.Humanoid:GetState()==Enum.HumanoidStateType.Running
		until settled or os.clock()>settleDeadline
		assert(settled,"boss failed to return to a grounded physical state")
	end, debug.traceback)
	if player.Character == character and character.Parent then character:PivotTo(returnTo) end
	if not ok then table.insert(failures, err) end
	result.Value = game.HttpService:JSONEncode({status=if ok then "PASS" else "FAIL", samples=samples, unanchored=unanchored, actions=actions, failures=failures,trace=trace,minY=minY,maxY=maxY,summonPeaks=peaks,peak=peak,settled=settled})
end)
return "started 90-second live encounter"
