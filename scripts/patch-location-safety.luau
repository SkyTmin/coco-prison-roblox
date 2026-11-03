--!strict
-- Edit-only, idempotent targeted patch. Keeps all scenery, ore, NPCs, spawns and metadata intact.
assert(
	not game:GetService("RunService"):IsRunning(),
	"Stop Play before patching location boundaries"
)
-- Edit's require cache survives source syncs. A short-lived sibling executes the current source.
local Shared = game:GetService("ReplicatedStorage").Shared
local fresh = Shared.LocationBounds:Clone()
fresh.Name, fresh.Parent = "LocationBounds_Patch", Shared
local ok, Bounds = pcall(require, fresh)
fresh:Destroy()
assert(ok, tostring(Bounds))
local regions = Bounds.ApplyWorld(workspace, game:GetService("ServerStorage"))
local report, covered = {}, {}
for _, region in ipairs(regions) do
	covered[region.id] = true
	table.insert(report, {
		location = region.id,
		root = region.root:GetFullName(),
		min = tostring(region.min),
		max = tostring(region.max),
		rescueY = region.floor,
		solids = region.solids,
		repairedEdges = region.repairedEdges,
	})
end
local missing = {}
for id in pairs(Bounds.ROOTS) do
	if not covered[id] then
		table.insert(missing, id)
	end
end
table.sort(missing)
return game:GetService("HttpService"):JSONEncode({
	regions = report,
	missing = missing,
	status = if #missing == 0 then "PASS" else "INCOMPLETE",
})
