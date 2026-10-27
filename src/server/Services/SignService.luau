--!strict
-- Sign posts that cover the text [владелец 27.10: «у нас везде есть таблички … текст не всегда виден, рукоятка торчит и
-- закрывает надпись»]: the map builders stand a board on a post that runs on through the board (to its middle or
-- higher) and is thicker than it, so the post covers part of the text on both faces. At server start every board with
-- text (a SurfaceGui) gets the vertical posts that reach into it cut down to its bottom edge: the board then sits on
-- the post, like a Minecraft sign. The place file stays as it is; the fix runs on every start.
local SignService = {}

local POST_NAMES = { "Post", "Pole", "Stick", "Handle" }

-- lamps, railings and fences stand next to some signs; their poles are not the sign's
local NOT_POSTS = { "Lamp", "Lantern", "Balustrade", "Fence", "Rail" }

local function isPost(part: BasePart): boolean
	for _, word in ipairs(NOT_POSTS) do
		if string.find(part.Name, word) then
			return false
		end
	end
	for _, word in ipairs(POST_NAMES) do
		if string.find(part.Name, word) then
			return true
		end
	end
	return false
end

local function fixBoard(board: BasePart, fixed: { [BasePart]: boolean }): number
	local count = 0
	local up = board.CFrame.UpVector
	if math.abs(up.Y) < 0.9 then
		return 0 -- only upright boards
	end
	local bottom = board.Position.Y - board.Size.Y / 2
	local probe = OverlapParams.new()
	probe.FilterType = Enum.RaycastFilterType.Exclude
	probe.FilterDescendantsInstances = { board }
	for _, part in
		ipairs(
			workspace:GetPartBoundsInBox(board.CFrame, board.Size + Vector3.new(0.4, 0, 0.4), probe)
		)
	do
		if
			not fixed[part]
			and part.Anchored
			and isPost(part)
			and math.abs(part.CFrame.UpVector.Y) > 0.99
		then
			local top = part.Position.Y + part.Size.Y / 2
			local foot = part.Position.Y - part.Size.Y / 2
			-- a post under the board's face (not a pillar beside it) that stands below the board and pokes into it
			local rel = board.CFrame:PointToObjectSpace(part.Position)
			local wide = board.Size.X >= board.Size.Z -- the board's long side, the text runs along it
			local across = math.abs(if wide then rel.X else rel.Z)
			local half = (if wide then board.Size.X else board.Size.Z) / 2
			if across < half - 0.1 and foot < bottom and top > bottom + 0.05 then
				local height = bottom - foot
				local x, z = part.Position.X, part.Position.Z
				local _, yaw = part.CFrame:ToEulerAnglesYXZ()
				part.Size = Vector3.new(part.Size.X, height, part.Size.Z)
				part.CFrame = CFrame.new(x, foot + height / 2, z) * CFrame.Angles(0, yaw, 0)
				fixed[part] = true
				count += 1
			end
		end
	end
	return count
end

function SignService.Start()
	local fixed: { [BasePart]: boolean } = {}
	local count = 0
	for _, gui in ipairs(workspace:GetDescendants()) do
		local board = gui.Parent
		if gui:IsA("SurfaceGui") and board and board:IsA("BasePart") then
			count += fixBoard(board, fixed)
		end
	end
	if count > 0 then
		print(string.format("[SignService] %d sign posts cut below their boards", count))
	end
end

return SignService
