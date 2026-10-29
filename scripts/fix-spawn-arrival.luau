--!strict
-- Move the first prison teleport spot to the big mine without rebuilding the map (Edit mode).
-- scripts/build-prison.luau carries the same fix for future builds.

local prison = assert(workspace:FindFirstChild("Prison"), "Prison is missing")
local arrival = assert(prison:FindFirstChild("LocationSpawn_spawn"), "Spawn arrival is missing")
local mine = assert(prison:FindFirstChild("LocationSpawn_mine"), "Big mine arrival is missing")
assert(arrival:IsA("BasePart") and mine:IsA("BasePart"), "Arrivals must be BaseParts")
assert(
	arrival:GetAttribute("LocationId") == "prison" and arrival:GetAttribute("Spot") == "spawn",
	"Unexpected spawn arrival attributes"
)
assert(
	mine:GetAttribute("LocationId") == "prison" and mine:GetAttribute("Spot") == "mine",
	"Unexpected big mine arrival attributes"
)

arrival.CFrame = mine.CFrame

return "Spawn teleport now arrives by the big mine: " .. tostring(arrival.Position)
