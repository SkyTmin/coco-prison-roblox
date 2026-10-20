--!nocheck
-- Edit-time step: creates one MaterialVariant per texture in MaterialService (runtime scripts lack
-- the capability to set BaseMaterial). Reads ReplicatedStorage.Shared.Config.textures. Run via
-- Studio MCP execute_luau in Edit mode after syncing scripts; idempotent.

local MaterialService = game:GetService("MaterialService")
local cfg = require(game:GetService("ReplicatedStorage").Shared.Config.textures)

local made, kept = 0, 0
for id, assetId in pairs(cfg.textures) do
	local name = "px_" .. id
	local variant = MaterialService:FindFirstChild(name)
	if not variant then
		variant = Instance.new("MaterialVariant")
		variant.Name = name
		variant.BaseMaterial = Enum.Material.Plastic
		variant.Parent = MaterialService
		made += 1
	else
		kept += 1
	end
	variant.ColorMap = assetId
	variant.StudsPerTile = cfg.studsPerTile or 4
end
return string.format("material variants: %d created, %d updated", made, kept)
