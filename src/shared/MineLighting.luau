--!strict
-- Low-intensity fill inside the entire dig volume, including its deepest floor [решение].
-- Attachments add no collision/query geometry and survive regeneration of the ore grid.
local MineLighting = {}
local PREFIX = "MiningFill_"
local BLOCK, SPACING, RANGE = 4, 64, 60
local BRIGHTNESS = 0.4

function MineLighting.Apply(anchor: BasePart, size: { number }): number
	local extent = Vector3.new(size[1], size[2], size[3]) * BLOCK
	local counts = {
		math.clamp(math.ceil(extent.X / SPACING), 1, 4),
		math.clamp(math.ceil(extent.Y / SPACING), 1, 3),
		math.clamp(math.ceil(extent.Z / SPACING), 1, 4),
	}
	local wanted = {}
	local index = 0
	for x = 1, counts[1] do
		for y = 1, counts[2] do
			for z = 1, counts[3] do
				index += 1
				local name = PREFIX .. index
				wanted[name] = true
				local old = anchor:FindFirstChild(name)
				if old and not old:IsA("Attachment") then
					old:Destroy()
					old = nil
				end
				local attachment = (old or Instance.new("Attachment")) :: Attachment
				attachment.Name = name
				-- MineService's grid is world-axis aligned even when the anchor is rotated.
				local world = anchor.Position
					+ Vector3.new(
						((x - 0.5) / counts[1] - 0.5) * extent.X,
						anchor.Size.Y / 2 - (y - 0.5) / counts[2] * extent.Y,
						((z - 0.5) / counts[3] - 0.5) * extent.Z
					)
				attachment.CFrame = CFrame.new(anchor.CFrame:PointToObjectSpace(world))
				attachment.Parent = anchor
				local light = attachment:FindFirstChild("Fill")
				if light and not light:IsA("PointLight") then
					light:Destroy()
					light = nil
				end
				local fill = (light or Instance.new("PointLight")) :: PointLight
				fill.Name, fill.Range, fill.Brightness = "Fill", RANGE, BRIGHTNESS
				fill.Shadows = false
				fill.Color = Color3.fromRGB(235, 231, 218)
				fill.Enabled = true
				fill.Parent = attachment
			end
		end
	end
	for _, child in anchor:GetChildren() do
		if child.Name:sub(1, #PREFIX) == PREFIX and not wanted[child.Name] then
			child:Destroy()
		end
	end
	return index
end

return MineLighting
