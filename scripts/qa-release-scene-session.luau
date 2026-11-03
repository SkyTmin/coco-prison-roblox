--!nocheck
-- Edit-only bounded test lease: retain the exact cloud scenery in memory while STS clones a small arena.
-- Never save/publish while leased. The caller MUST Invoke("restore") in its finally path.
assert(game.RunService:IsStudio() and not game.RunService:IsRunning(), "Edit only")
assert(not game.ServerStorage:FindFirstChild("QAReleaseMapLease"), "Restore existing lease first")
local retained = ... or {}
local lease = Instance.new("BindableFunction")
lease.Name = "QAReleaseMapLease"
local parked = {}
for _, child in workspace:GetChildren() do
	if not child:IsA("Camera") and not child:IsA("Terrain") and not retained[child.Name] then
		table.insert(parked, child)
		child.Parent = nil
		task.wait()
	end
end
local arena = Instance.new("Model")
arena.Name = "QAReleaseStaging"
arena:SetAttribute("ReleaseQaTemporary", true)
local floor = Instance.new("Part")
floor.Name, floor.Size, floor.Position, floor.Anchored =
	"Floor", Vector3.new(150, 2, 150), Vector3.new(0, 199, 0), true
floor.Parent = arena
local spawn = Instance.new("SpawnLocation")
spawn.Name, spawn.Size, spawn.Position, spawn.Anchored =
	"Spawn", Vector3.new(6, 1, 6), Vector3.new(0, 200.5, 0), true
spawn.Neutral, spawn.Duration, spawn.Transparency, spawn.Parent = true, 0, 1, arena
arena.Parent = workspace
local names = {}
for _, child in parked do table.insert(names, child.Name) end
lease:SetAttribute("Names", game.HttpService:JSONEncode(names))
lease:SetAttribute("ParkedCount", #parked)
lease.OnInvoke = function(op)
	if op ~= "restore" then return #parked end
	local count = #parked
	for _, child in parked do child.Parent = workspace; task.wait() end
	table.clear(parked)
	if arena.Parent and arena:GetAttribute("ReleaseQaTemporary") then arena:Destroy() end
	lease:Destroy()
	return count
end
lease.Parent = game.ServerStorage
return string.format("Temporary QA arena; %d scenery roots retained until restore", #parked)
