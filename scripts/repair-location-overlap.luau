--!nocheck
-- Edit-only, idempotent translation of existing scenery. Preserves the cloud map and every tag/attribute.
-- Builders use the same Z=4000 lane so regeneration cannot recreate the overlap.
assert(not game:GetService("RunService"):IsRunning(), "stop Play before moving map locations")
local plans = {
	{root="Ghetto", id="ghetto", old=Vector3.new(11400,15000.6,206)},
	{root="Warzone", id="warzone", old=Vector3.new(14400,19500.75,18)},
}
local shift=Vector3.new(0,0,4000)
local report={}
for _,plan in plans do
	local root=workspace:FindFirstChild(plan.root)
	assert(root,"missing "..plan.root)
	local arrival
	for _,p in game.CollectionService:GetTagged("LocationSpawn") do
		if p:IsA("BasePart") and p:IsDescendantOf(root) and p:GetAttribute("LocationId")==plan.id then
			assert(not arrival,"ambiguous arrival "..plan.id);arrival=p
		end
	end
	assert(arrival,"missing arrival "..plan.id)
	local target=plan.old+shift
	if (arrival.Position-target).Magnitude<.1 then
		table.insert(report,plan.root.." already separated")
	else
		assert((arrival.Position-plan.old).Magnitude<.1,"unexpected map origin: "..plan.id)
		local parts,frames,pivots={},{},{}
		for i,d in root:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(parts,d);table.insert(frames,d.CFrame+shift)
			elseif d:IsA("Model") and not d.PrimaryPart then
				pivots[d]=d.WorldPivot+shift
			end
			if i%1000==0 then task.wait()end
		end
		for first=1,#parts,512 do
			local batch,goals={},{}
			for i=first,math.min(first+511,#parts) do table.insert(batch,parts[i]);table.insert(goals,frames[i])end
			workspace:BulkMoveTo(batch,goals,Enum.BulkMoveMode.FireCFrameChanged);task.wait()
		end
		for model,pivot in pivots do model.WorldPivot=pivot end
		for i,part in parts do assert((part.Position-frames[i].Position).Magnitude<.01,"incomplete move: "..part:GetFullName())end
		assert((arrival.Position-target).Magnitude<.1,"arrival failed to move")
		table.insert(report,plan.root..": moved "..#parts.." parts")
	end
end
return table.concat(report,"; ")
