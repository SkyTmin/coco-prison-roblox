--!strict
-- Edit-mode targeted patch. Existing scenery/decorative lamps and ore are preserved.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Lighting = require(Shared.MineLighting)
local mines, lights = 0, 0
for _, anchor in game:GetService("CollectionService"):GetTagged("MineAnchor") do
	if anchor:IsA("BasePart") and anchor:IsDescendantOf(workspace) then
		local location = Config.location(anchor:GetAttribute("LocationId"))
		local override = anchor:GetAttribute("Size")
		local rule = location
			and (if anchor:GetAttribute("MiniMine") then location.miniMine else location.mine)
		local size = if typeof(override) == "Vector3"
			then { override.X, override.Y, override.Z }
			else rule and rule.size
		if size then
			lights += Lighting.Apply(anchor, size)
			mines += 1
		end
	end
end
return string.format("Mine lighting: %d anchors, %d soft fill lights", mines, lights)
