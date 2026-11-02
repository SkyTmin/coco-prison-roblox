--!strict
-- Edit-mode targeted patch: preserve all existing scenery; repair private arrivals and add five bats.
local root = workspace:FindFirstChild("Ghetto")
assert(root, "Workspace.Ghetto is missing")
local result = require(game:GetService("ReplicatedStorage").Shared.GhettoLayout).apply(root)
local text = string.format(
	"Ghetto audit patch: %d private arrivals, %d new bat spawns",
	result.arrivals,
	result.batsCreated
)
print(text)
return text
