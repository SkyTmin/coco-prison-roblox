--!strict
-- Geometry, never guessed world coordinates. Sources: the thirty build-<location> scripts.
-- Only exterior vertical walls are added; no invisible floor/roof can obstruct a mine or a jump.
local CollectionService = game:GetService("CollectionService")
local Config = require(script.Parent.Config)
local Bounds = {}
Bounds.ROOTS = {
	prison = "Prison",
	quarry = "Quarry",
	basement = "Basement",
	fraction_base = "FactionBase",
	mountain_foot = "MountainFoot",
	underworld = "Underworld",
	pyramid = "Pyramid",
	royal_garden = "RoyalGarden",
	sunken_lighthouse = "SunkenLighthouse",
	end_castle = "EndCastle",
	spider_lair = "SpiderLair",
	snowy_hand = "SnowyHand",
	market = "Market",
	leprechaun_valley = "LeprechaunValley",
	castle = "Castle",
	inside_out = "InsideOut",
	kyoto = "Kyoto",
	farm = "Farm",
	barn = "Barn",
	edge_gate = "EdgeGate",
	tree = "Tree",
	church = "Church",
	purgatory = "Purgatory",
	eden = "Eden",
	cherubim = "Cherubim",
	gate = "Gate",
	paradise = "Paradise",
	ghetto = "Ghetto",
	warzone = "Warzone",
	gang_base = "GangHouseTemplate", -- ServerStorage template; runtime copies have GangId.
}
Bounds.GUARD_NAME = "LocationSafety"
local DEPTH_MARGIN, TOP_MARGIN, THICKNESS = 12, 64, 2 -- [решение] clearance, not map coordinates
export type Region = {
	root: Instance,
	id: string,
	min: Vector3,
	max: Vector3,
	floor: number,
	privateMine: boolean?,
	showcase: boolean?,
	solids: number,
	repairedEdges: number?,
}

-- Two early builders shipped malformed side-wall Z literals (-150142 / -159159), confirmed in
-- the cloud map on 03.11. Repair only their exact four-wall, axis-aligned rectangle layout.
-- The correct centre comes from its intact north/south pair, never from a guessed map clamp.
function Bounds.RepairLegacyEdges(root: Instance): number
	if root.Name ~= "MountainFoot" and root.Name ~= "Pyramid" then
		return 0
	end
	local folder = root:FindFirstChild("Edge")
	if not folder then
		return 0
	end
	local across, sides = {}, {}
	local function near(a: number, b: number): boolean
		return math.abs(a - b) < 0.05
	end
	for _, part in ipairs(folder:GetChildren()) do
		if
			not part:IsA("BasePart")
			or part.Name ~= "EdgeWall"
			or not part.Anchored
			or not part.CanCollide
			or part.Transparency ~= 1
			or part.CFrame.RightVector:Dot(Vector3.xAxis) < 0.9999
			or part.CFrame.UpVector:Dot(Vector3.yAxis) < 0.9999
		then
			return 0
		end
		if near(part.Size.Z, 4) and part.Size.X > 4 then
			table.insert(across, part)
		elseif near(part.Size.X, 4) and part.Size.Z > 4 then
			table.insert(sides, part)
		else
			return 0
		end
	end
	if #across ~= 2 or #sides ~= 2 then
		return 0
	end
	local a, b, c, d = across[1], across[2], sides[1], sides[2]
	local centreX, centreZ = (c.Position.X + d.Position.X) / 2, (a.Position.Z + b.Position.Z) / 2
	local width, depth =
		math.abs(c.Position.X - d.Position.X), math.abs(a.Position.Z - b.Position.Z)
	if
		not (
			near(a.Position.X, centreX)
			and near(b.Position.X, centreX)
			and near(a.Size.X, width)
			and near(b.Size.X, width)
			and near(c.Size.Z, depth)
			and near(d.Size.Z, depth)
			and near(c.Position.Z, d.Position.Z)
			and near(a.Position.Y, b.Position.Y)
			and near(a.Position.Y, c.Position.Y)
			and near(a.Position.Y, d.Position.Y)
			and near(a.Size.Y, b.Size.Y)
			and near(a.Size.Y, c.Size.Y)
			and near(a.Size.Y, d.Size.Y)
		)
	then
		return 0
	end
	-- Leave valid rectangles and modest intentional edits alone. Both bad sides are far outside
	-- the span they demonstrably belong to; their X/Y/size/rotation and all scenery stay untouched.
	if math.abs(c.Position.Z - centreZ) <= depth then
		return 0
	end
	for _, part in ipairs(sides) do
		part.CFrame += Vector3.new(0, 0, centreZ - part.Position.Z)
	end
	return 2
end

local function extents(part: BasePart): Vector3
	local cf, h = part.CFrame, part.Size / 2
	local x, y, z = cf.RightVector, cf.UpVector, cf.LookVector
	return Vector3.new(
		math.abs(x.X) * h.X + math.abs(y.X) * h.Y + math.abs(z.X) * h.Z,
		math.abs(x.Y) * h.X + math.abs(y.Y) * h.Y + math.abs(z.Y) * h.Z,
		math.abs(x.Z) * h.X + math.abs(y.Z) * h.Y + math.abs(z.Z) * h.Z
	)
end

function Bounds.Measure(root: Instance, id: string, exclude: Instance?): Region?
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	local edgeLo, edgeHi = Vector3.one * math.huge, -Vector3.one * math.huge
	local count = 0
	local function include(a: Vector3, b: Vector3)
		lo, hi = lo:Min(a), hi:Max(b)
	end
	for _, part in ipairs(root:GetDescendants()) do
		if not part:IsA("BasePart") or (exclude and part:IsDescendantOf(exclude)) then
			continue
		end
		local skip = false
		local ancestor: Instance? = part
		while ancestor and ancestor ~= root do
			if ancestor.Name == Bounds.GUARD_NAME or ancestor:FindFirstChildOfClass("Humanoid") then
				skip = true
				break
			end
			ancestor = ancestor.Parent
		end
		if skip or CollectionService:HasTag(part, "VoidCatch") then
			continue
		end
		if part.Name == "EdgeWall" then
			-- Existing walls also bound swimmable Terrain water. Preserve their horizontal footprint,
			-- but their arbitrary 400-stud height must not become the legal floor or roof.
			local half = extents(part)
			edgeLo, edgeHi = edgeLo:Min(part.Position - half), edgeHi:Max(part.Position + half)
			continue
		end
		if part.Anchored and part.CanCollide then
			local half = extents(part)
			include(part.Position - half, part.Position + half)
			count += 1
		end
		-- Mine blocks are generated in separate Workspace.Mine_* folders. Include their full legal depth
		-- even when empty/rebuilding or when the anchor itself is non-colliding.
		if CollectionService:HasTag(part, "MineAnchor") then
			local location = Config.location(id)
			local override = part:GetAttribute("Size")
			local rule = location
				and (if part:GetAttribute("MiniMine") then location.miniMine else location.mine)
			local size = if typeof(override) == "Vector3"
				then override
				elseif rule and rule.size then Vector3.new(table.unpack(rule.size))
				else nil
			if size then
				local top = part.Position + Vector3.new(0, part.Size.Y / 2, 0)
				include(
					top - Vector3.new(size.X * 2, size.Y * 4, size.Z * 2),
					top + Vector3.new(size.X * 2, 0, size.Z * 2)
				)
			end
		end
	end
	if count == 0 then
		return nil
	end
	lo = Vector3.new(math.min(lo.X, edgeLo.X), lo.Y, math.min(lo.Z, edgeLo.Z))
	hi = Vector3.new(math.max(hi.X, edgeHi.X), hi.Y, math.max(hi.Z, edgeHi.Z))
	return { root = root, id = id, min = lo, max = hi, floor = lo.Y - DEPTH_MARGIN, solids = count }
end

function Bounds.Contains(region: Region, position: Vector3, margin: number?): boolean
	local extra = margin or 0
	return position.X >= region.min.X - extra
		and position.X <= region.max.X + extra
		and position.Z >= region.min.Z - extra
		and position.Z <= region.max.Z + extra
		and position.Y >= region.floor
		and position.Y <= region.max.Y + TOP_MARGIN
end

function Bounds.Escaped(region: Region, position: Vector3): boolean
	-- A threshold cannot be skipped by a fast fall, unlike Touched/overlap with a thin net.
	return position.Y < region.floor
		or position.X < region.min.X - 6
		or position.X > region.max.X + 6
		or position.Z < region.min.Z - 6
		or position.Z > region.max.Z + 6
end

function Bounds.Apply(root: Instance, id: string, exclude: Instance?): Region?
	local repaired = Bounds.RepairLegacyEdges(root)
	local region = Bounds.Measure(root, id, exclude)
	if not region then
		return nil
	end
	region.repairedEdges = repaired
	local holder = root:FindFirstChild(Bounds.GUARD_NAME)
	if holder and not holder:IsA("Model") then
		return nil
	end
	if not holder then
		holder = Instance.new("Model")
		holder.Name = Bounds.GUARD_NAME
		holder.Parent = root
	end
	(holder :: Model).ModelStreamingMode = if root:GetAttribute("GangId")
			or root.Name == "GangHouseTemplate"
		then Enum.ModelStreamingMode.Atomic
		else Enum.ModelStreamingMode.Persistent
	local lo, hi = region.min, region.max
	local top, bottom = hi.Y + TOP_MARGIN, region.floor - 4
	local middle = (top + bottom) / 2
	local specs = {
		{
			"West",
			Vector3.new(THICKNESS, top - bottom, hi.Z - lo.Z + 2 * THICKNESS),
			Vector3.new(lo.X - THICKNESS / 2, middle, (lo.Z + hi.Z) / 2),
		},
		{
			"East",
			Vector3.new(THICKNESS, top - bottom, hi.Z - lo.Z + 2 * THICKNESS),
			Vector3.new(hi.X + THICKNESS / 2, middle, (lo.Z + hi.Z) / 2),
		},
		{
			"North",
			Vector3.new(hi.X - lo.X, top - bottom, THICKNESS),
			Vector3.new((lo.X + hi.X) / 2, middle, lo.Z - THICKNESS / 2),
		},
		{
			"South",
			Vector3.new(hi.X - lo.X, top - bottom, THICKNESS),
			Vector3.new((lo.X + hi.X) / 2, middle, hi.Z + THICKNESS / 2),
		},
	}
	for _, spec in ipairs(specs) do
		local wall = holder:FindFirstChild(spec[1])
		if not wall then
			wall = Instance.new("Part")
			wall.Name = spec[1]
			wall.Parent = holder
		end
		if wall:IsA("BasePart") then
			wall.Size, wall.CFrame = spec[2], CFrame.new(spec[3])
			wall.Anchored, wall.Transparency = true, 1
			wall.CanCollide, wall.CanQuery, wall.CanTouch = true, false, false
			wall.CastShadow = false
		end
	end
	return region
end

-- Main map and detached spaces have independent envelopes. In particular, Ghetto's rooms at Y-300
-- must not lower the public district's rescue plane or be enclosed together with another location.
function Bounds.ApplyWorld(world: Instance, storage: Instance?): { Region }
	local regions = {}
	for id, name in pairs(Bounds.ROOTS) do
		local root = if id == "gang_base"
			then storage and storage:FindFirstChild(name)
			else world:FindFirstChild(name)
		if root then
			local rooms = if id == "ghetto" then root:FindFirstChild("GangMineRooms") else nil
			local region = Bounds.Apply(root, id, rooms)
			if region then
				table.insert(regions, region)
			end
			if rooms then
				for _, room in ipairs(rooms:GetChildren()) do
					local private = Bounds.Apply(room, id)
					if private then
						private.privateMine = true
						table.insert(regions, private)
					end
				end
			end
		end
	end
	local showcase = world:FindFirstChild("Showcase")
	if showcase then
		local region = Bounds.Apply(showcase, "prison")
		if region then
			region.showcase = true
			table.insert(regions, region)
		end
	end
	for _, root in ipairs(world:GetChildren()) do
		if root:GetAttribute("GangId") ~= nil then
			local region = Bounds.Apply(root, "gang_base")
			if region then
				table.insert(regions, region)
			end
		end
	end
	return regions
end

return Bounds
