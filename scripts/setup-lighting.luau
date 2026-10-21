--!nocheck
-- Applies the code-kept lighting (src/server/Services/LightingService.luau) in Edit mode, so Studio shows
-- what players get. Run via scripts/studio-loader.luau after a sync.
local service = game:GetService("ServerScriptService"):FindFirstChild("LightingService", true)
if not service then
	return "LightingService not synced"
end
require(service).Apply()
return "lighting applied"
