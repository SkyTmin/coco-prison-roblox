--!strict
-- Existing cloud templates can predate the builder's matte-window correction.
local MatteWindows = {}
function MatteWindows.Apply(root: Instance?): number
	if not root then
		return 0
	end
	local changed = 0
	for _, part in root:GetDescendants() do
		if part:IsA("BasePart") and part.Material == Enum.Material.Neon then
			local name = string.lower(part.Name)
			if string.find(name, "window") or part.Name == "KioskGlass" then
				part.Material = Enum.Material.SmoothPlastic
				-- Matches build-gang-base/build-ghetto, idempotent because only Neon is converted.
				part.Color = part.Color:Lerp(Color3.fromRGB(70, 65, 55), 0.45)
				changed += 1
			end
		end
	end
	return changed
end
return MatteWindows
