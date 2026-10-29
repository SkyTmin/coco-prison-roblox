--!strict
-- Ladder contact shared by movement and fall damage. Query the nearby world so nested / streamed-in ladders
-- work on every location, without maintaining a list of map folders or scanning a whole map every frame.

local Ladders = {}

local REACH = 4 -- [решение] one block: the mine's permanently empty ladder shaft is one block deep
local TOP_SLACK = 0.2 -- [решение] catch as the feet cross the rim, before the root drops below it
Ladders.SLIDE_SPEED = 12 -- [решение] maximum controlled descent in studs/s (3 blocks/s)

local query = OverlapParams.new()
query.FilterType = Enum.RaycastFilterType.Exclude
query.RespectCanCollide = true

function Ladders.near(character: Model?): TrussPart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return nil
	end
	local position = root.Position
	local feet = position.Y - root.Size.Y / 2 - humanoid.HipHeight
	local head = position.Y + root.Size.Y / 2 + 2
	local centre = Vector3.new(position.X, (feet + head) / 2, position.Z)
	local size =
		Vector3.new(root.Size.X + REACH * 2, head - feet + TOP_SLACK * 2, root.Size.Z + REACH * 2)
	query.FilterDescendantsInstances = { character }
	local nearest: TrussPart? = nil
	local distance = REACH * REACH
	for _, part in ipairs(workspace:GetPartBoundsInBox(CFrame.new(centre), size, query)) do
		-- Horizontal scaffolding is not a ladder shaft. Do not grab above the rim or below the ladder.
		if part:IsA("TrussPart") and math.abs(part.CFrame.UpVector.Y) > 0.95 then
			local half = part.Size / 2
			if feet < part.Position.Y + half.Y + TOP_SLACK and head > part.Position.Y - half.Y then
				local point = part.CFrame:PointToObjectSpace(position)
				local dx = math.max(0, math.abs(point.X) - half.X)
				local dz = math.max(0, math.abs(point.Z) - half.Z)
				local d = dx * dx + dz * dz
				if d < distance then
					nearest, distance = part, d
				end
			end
		end
	end
	return nearest
end

return Ladders
