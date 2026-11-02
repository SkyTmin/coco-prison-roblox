--!nocheck
-- Static map audit: different destination folders must not occupy the same world bounds.
local roots={}
for _,spawn in game.CollectionService:GetTagged("LocationSpawn") do
	if spawn:IsA("BasePart") and spawn:IsDescendantOf(workspace) then
		local root=spawn
		while root.Parent~=workspace do root=root.Parent end
		local id=spawn:GetAttribute("LocationId")
		if not roots[root]then roots[root]={id=id,min=Vector3.one*math.huge,max=-Vector3.one*math.huge}end
	end
end
local count,overlaps=0,{}
for root,b in roots do
	for i,p in root:GetDescendants() do
		if p:IsA("BasePart")then
			local x,y,z=p.CFrame.RightVector,p.CFrame.UpVector,p.CFrame.LookVector
			local h=p.Size/2
			local extent=Vector3.new(math.abs(x.X)*h.X+math.abs(y.X)*h.Y+math.abs(z.X)*h.Z,math.abs(x.Y)*h.X+math.abs(y.Y)*h.Y+math.abs(z.Y)*h.Z,math.abs(x.Z)*h.X+math.abs(y.Z)*h.Y+math.abs(z.Z)*h.Z)
			b.min=b.min:Min(p.Position-extent);b.max=b.max:Max(p.Position+extent)
		end
		if i%1000==0 then task.wait()end
	end
	count+=1
end
local entries={};for root,b in roots do table.insert(entries,{root=root,b=b})end
local pairsChecked=0
for i,a in entries do
	for j=i+1,#entries do
		local b=entries[j]
		if a.b.id~=b.b.id then
			pairsChecked+=1
			local lo=a.b.min:Max(b.b.min);local hi=a.b.max:Min(b.b.max)
			if hi.X>lo.X and hi.Y>lo.Y and hi.Z>lo.Z then table.insert(overlaps,a.root.Name.." / "..b.root.Name)end
		end
	end
end
return game.HttpService:JSONEncode({status=if #overlaps==0 then "PASS"else "FAIL",roots=count,pairsChecked=pairsChecked,overlaps=overlaps})
