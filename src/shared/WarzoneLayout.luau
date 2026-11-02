--!strict
-- Bounded, idempotent scenery repair for the existing Дворы map and its builder.
-- Runs before MineService: no generated ore, player or other location is touched.
local CollectionService = game:GetService("CollectionService")
local WarzoneLayout = {}
local REVISION = 1
type Rect = { number }
local SURFACES = {
	Grass = true,
	RoadNS = true,
	RoadEW = true,
	Sidewalk = true,
	Square = true,
	Driveway = true,
	DoorWalk = true,
	Path = true,
	PadRim = true,
}

local function bounds(part: BasePart): Rect
	local half = part.Size / 2
	local cf = part.CFrame
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local x = math.abs(r.X) * half.X + math.abs(u.X) * half.Y + math.abs(l.X) * half.Z
	local z = math.abs(r.Z) * half.X + math.abs(u.Z) * half.Y + math.abs(l.Z) * half.Z
	return { cf.X - x, cf.Z - z, cf.X + x, cf.Z + z }
end

local function overlaps(a: Rect, b: Rect): boolean
	return a[1] < b[3] - 0.01 and a[3] > b[1] + 0.01 and a[2] < b[4] - 0.01 and a[4] > b[2] + 0.01
end

local function subtract(rect: Rect, hole: Rect): { Rect }
	if not overlaps(rect, hole) then
		return { rect }
	end
	local x0, z0 = math.max(rect[1], hole[1]), math.max(rect[2], hole[2])
	local x1, z1 = math.min(rect[3], hole[3]), math.min(rect[4], hole[4])
	local out = {}
	for _, piece in ipairs({
		{ rect[1], rect[2], rect[3], z0 },
		{ rect[1], z1, rect[3], rect[4] },
		{ rect[1], z0, x0, z1 },
		{ x1, z0, rect[3], z1 },
	}) do
		if piece[3] - piece[1] > 0.01 and piece[4] - piece[2] > 0.01 then
			table.insert(out, piece)
		end
	end
	return out
end

local function marker(
	parent: Instance,
	name: string,
	size: Vector3,
	at: Vector3,
	color: Color3
): Part
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position = name, size, at
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow =
		true, false, false, false, false
	p.Material, p.Color = Enum.Material.SmoothPlastic, color
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

function WarzoneLayout.apply(root: Instance): boolean
	assert(
		root.Name == "Warzone" and root:GetAttribute("LocationId") == "warzone",
		"Expected the Дворы scenery root"
	)
	if root:GetAttribute("MineLayoutRevision") == REVISION then
		return false
	end
	local anchors: { BasePart } = {}
	local ids = {}
	for _, anchor in ipairs(root:GetDescendants()) do
		if anchor:IsA("BasePart") and CollectionService:HasTag(anchor, "MineAnchor") then
			local id = anchor:GetAttribute("MineId")
			assert(
				typeof(id) == "string" and string.match(id, "^warzone_"),
				"Unexpected mine in Дворы"
			)
			assert(not ids[id], "Duplicate Дворы mine anchor: " .. id)
			ids[id] = true
			table.insert(anchors, anchor)
		end
	end
	assert(#anchors == 4, "Expected four Дворы mines before scenery repair")
	local center = Vector3.zero
	for _, anchor in ipairs(anchors) do
		center += anchor.Position / #anchors
	end
	local holes, protected = {}, {}
	local minTop = math.huge
	for _, anchor in ipairs(anchors) do
		local hole = bounds(anchor)
		local top = anchor.Position.Y + anchor.Size.Y / 2
		minTop = math.min(minTop, top)
		table.insert(holes, hole)
		table.insert(protected, { hole[1] - 4, hole[2] - 4, hole[3] + 4, hole[4] + 4 })
		local sx, sz =
			math.sign(anchor.Position.X - center.X), math.sign(anchor.Position.Z - center.Z)
		local point = string.sub(anchor:GetAttribute("MineId") :: string, 9)
		local yard = anchor.Parent :: Instance
		local beacon = yard:FindFirstChild("Beacon_" .. point)
		local base = beacon and beacon:FindFirstChild("BeaconBase")
		if beacon and beacon:IsA("Model") and base and base:IsA("BasePart") then
			-- Beside the mine: the approach from the street no longer ends at a solid beacon.
			local goal = Vector3.new(
				anchor.Position.X + sx * (anchor.Size.X / 2 + 11),
				base.Position.Y,
				anchor.Position.Z
			)
			local offset = goal - base.Position
			for _, piece in ipairs(beacon:GetDescendants()) do
				if piece:IsA("BasePart") then
					piece.CFrame += offset
				end
			end
			local b = bounds(base)
			table.insert(protected, { b[1] - 2, b[2] - 2, b[3] + 2, b[4] + 2 })
		end
		anchor.Transparency, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch =
			1, false, false, false
		-- Extend the existing cross-yard path to the open front of the pit.
		for _, path in ipairs(yard:GetChildren()) do
			if path:IsA("BasePart") and path.Name == "Path" and path.Size.X > path.Size.Z then
				local r = bounds(path)
				local edge = anchor.Position.X + sx * anchor.Size.X / 2
				if sx > 0 then
					r[3] = math.max(r[3], edge)
				else
					r[1] = math.min(r[1], edge)
				end
				path.Size = Vector3.new(r[3] - r[1], path.Size.Y, r[4] - r[2])
				path.Position = Vector3.new((r[1] + r[3]) / 2, path.Position.Y, (r[2] + r[4]) / 2)
			end
		end
		local approach = marker(
			yard,
			"Path",
			Vector3.new(8, 0.6, 6),
			Vector3.new(
				anchor.Position.X,
				top - 0.1,
				anchor.Position.Z - sz * (anchor.Size.Z / 2 + 5)
			),
			Color3.fromRGB(180, 178, 169)
		)
		approach.CanCollide = true
		approach.Material, approach.MaterialVariant = Enum.Material.Plastic, "px_stone_bricks"
		-- Matte checker border stays entirely OUTSIDE diggable cells and never catches the raycast.
		for side = -1, 1, 2 do
			for k = 0, 9 do
				local shade = if k % 2 == 0
					then Color3.fromRGB(225, 180, 50)
					else Color3.fromRGB(42, 42, 46)
				local along = -anchor.Size.X / 2 + (k + 0.5) * anchor.Size.X / 10
				marker(
					yard,
					"MineBorder",
					Vector3.new(anchor.Size.X / 10, 0.12, 0.55),
					Vector3.new(
						anchor.Position.X + along,
						top + 0.28,
						anchor.Position.Z + side * (anchor.Size.Z / 2 + 0.4)
					),
					shade
				)
				marker(
					yard,
					"MineBorder",
					Vector3.new(0.55, 0.12, anchor.Size.Z / 10),
					Vector3.new(
						anchor.Position.X + side * (anchor.Size.X / 2 + 0.4),
						top + 0.28,
						anchor.Position.Z + along
					),
					shade
				)
			end
		end
		local sign = marker(
			yard,
			"MineSign",
			Vector3.one,
			Vector3.new(
				anchor.Position.X - sx * (anchor.Size.X / 2 + 2),
				top + 5,
				anchor.Position.Z - sz * (anchor.Size.Z / 2 + 2)
			),
			Color3.new()
		)
		sign.Transparency = 1
		sign:SetAttribute("Point", point)
		CollectionService:AddTag(sign, "WarzoneMineSign")
	end
	-- Legacy trees are sibling Parts. Associate leaves with the nearest trunk before clearing a
	-- whole obstructing tree, so clipping a canopy cannot leave floating fragments.
	local trees: { [BasePart]: { BasePart } } = {}
	local leaves: { BasePart } = {}
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") then
			if part.Name == "Trunk" then
				trees[part] = { part }
			elseif part.Name == "Leaves" then
				table.insert(leaves, part)
			elseif part.Name == "Path" then
				table.insert(protected, bounds(part))
			end
		end
	end
	for _, leaf in ipairs(leaves) do
		local nearest, distance = nil, math.huge
		for trunk in pairs(trees) do
			local d = ((trunk.Position - leaf.Position) * Vector3.new(1, 0, 1)).Magnitude
			if d < distance and trunk.Parent == leaf.Parent then
				nearest, distance = trunk, d
			end
		end
		if nearest then
			table.insert(trees[nearest], leaf)
		end
	end
	for _, tree in pairs(trees) do
		local blocked = false
		for _, part in ipairs(tree) do
			for _, area in ipairs(protected) do
				if overlaps(bounds(part), area) then
					blocked = true
					break
				end
			end
			if blocked then
				break
			end
		end
		if blocked then
			for _, part in ipairs(tree) do
				part:Destroy()
			end
		end
	end
	-- Replace overlapping horizontal terrain layers with disjoint rectangles. This removes the
	-- near-coplanar grass/asphalt/path/rim faces instead of hiding them with still more overlays.
	local surfaces: { BasePart } = {}
	for _, part in ipairs(root:GetDescendants()) do
		if part:IsA("BasePart") and SURFACES[part.Name] and part.Position.Y < minTop + 1 then
			table.insert(surfaces, part)
		end
	end
	table.sort(surfaces, function(a, b)
		return a.Position.Y + a.Size.Y / 2 > b.Position.Y + b.Size.Y / 2
	end)
	local occupied: { Rect } = table.clone(holes)
	for _, part in ipairs(surfaces) do
		local pieces = { bounds(part) }
		for _, hole in ipairs(occupied) do
			local nextPieces = {}
			for _, piece in ipairs(pieces) do
				for _, remainder in ipairs(subtract(piece, hole)) do
					table.insert(nextPieces, remainder)
				end
			end
			pieces = nextPieces
		end
		for _, piece in ipairs(pieces) do
			local clone = part:Clone()
			clone.Size = Vector3.new(piece[3] - piece[1], part.Size.Y, piece[4] - piece[2])
			clone.CFrame =
				CFrame.new((piece[1] + piece[3]) / 2, part.Position.Y, (piece[2] + piece[4]) / 2)
			clone.Parent = part.Parent
			table.insert(occupied, piece)
		end
		part:Destroy()
	end
	root:SetAttribute("MineLayoutRevision", REVISION)
	return true
end

return WarzoneLayout
