--!nocheck
-- ================================================================ market: the bazaar (stalls, districts, street dressing, life)
-- Fills every stall zone (stallZone in 05-plan) with streets of stalls, as in the concept (assets/concepts/market/
-- concept-v2.webp): rows of striped-awning stalls (wool colours of the mine) facing the streets, the plaza and the
-- lanes. Lanes between facing rows are ≥ 4 blocks (PvP); the 5 streets and the plaza stay clear (edge props only).
-- Districts: FOOD ROW (south-east + south middle: melons, hay, the soup cauldron, tables, chicken cages), CRAFT &
-- CLOTH (south-west: wool bolts, dye barrels, cloth lines, the smithy), SMUGGLERS' ALLEY (north-west + the west strip:
-- dark awnings, contraband, the hatch under a counter, the card table, the lookout), TIMBER HOUSES (north middle:
-- two storeys, shops below, balconies above), the TAVERN (east middle) with its terrace and tea garden.
-- Every placement claims its footprint (take): it must lie in a stall zone, 8 studs inside the wall, off the
-- buyer / arch keep-outs and off everything placed before it.
local bazaar = folder("Bazaar")

local COL = {
	red = WOOL_RED,
	yellow = WOOL_YELLOW,
	lime = WOOL_LIME,
	white = WOOL_WHITE,
	grey = Color3.fromRGB(72, 72, 76),
	black = Color3.fromRGB(34, 34, 38),
	wine = Color3.fromRGB(112, 36, 40),
	blue = Color3.fromRGB(64, 96, 176),
	purple = Color3.fromRGB(122, 64, 150),
	cyan = Color3.fromRGB(60, 150, 160),
	orange = Color3.fromRGB(226, 128, 40),
	melon = Color3.fromRGB(104, 168, 56),
	melonDark = Color3.fromRGB(58, 110, 38),
	sack = Color3.fromRGB(205, 182, 140),
	sackTie = Color3.fromRGB(150, 120, 86),
	iron = Color3.fromRGB(60, 60, 66),
	ironDark = Color3.fromRGB(88, 88, 96),
	glass = Color3.fromRGB(36, 40, 50),
	paper = Color3.fromRGB(232, 222, 196),
	ember = Color3.fromRGB(255, 132, 40),
	soup = Color3.fromRGB(165, 120, 64),
	roofRed = Color3.fromRGB(176, 92, 70),
	roofBrown = Color3.fromRGB(130, 96, 70),
	roofDark = Color3.fromRGB(96, 96, 104),
	crate = Color3.fromRGB(215, 175, 120),
	prisoner = Color3.fromRGB(220, 120, 40),
	prisonerPants = Color3.fromRGB(70, 66, 62),
}
local WOOLS = { COL.red, COL.yellow, COL.lime, COL.white, COL.blue, COL.purple, COL.cyan, COL.orange }
local FLAGS = { COL.red, COL.yellow, COL.lime, COL.white }
local DARK_FLAGS = { COL.grey, COL.black, COL.wine }
local DF = {
	food = folder("FoodRow", bazaar),
	craft = folder("CraftAndCloth", bazaar),
	smug = folder("SmugglersAlley", bazaar),
	north = folder("TimberHouses", bazaar),
	east = folder("Tavern", bazaar),
	plaza = folder("PlazaRow", bazaar),
	street = folder("StreetDressing", bazaar),
	life = folder("Life", bazaar),
}
local STATS = { stalls = 0, houses = 0, npcs = 0, skipped = 0 }

-- ================================================================ footprints
local claims = {}
-- the buyer's stall with its barrel and crate, both posts of the welcome arch over the avenue; the guard booth
-- with its barrels and the crates by the south gate (20-walls)
local KEEP = { { -30, 96, 6, 132 }, { -62, 120, -50, 132 }, { -30, 156, -4, 180 }, { -78, 160, -62, 180 } }
local function free(x0, z0, x1, z1)
	if x1 < x0 then
		x0, x1 = x1, x0
	end
	if z1 < z0 then
		z0, z1 = z1, z0
	end
	local nx, nz = math.max(1, math.ceil((x1 - x0) / 4)), math.max(1, math.ceil((z1 - z0) / 4))
	for i = 0, nx do
		for j = 0, nz do
			local x = x0 + 0.5 + (x1 - x0 - 1) * i / nx
			local z = z0 + 0.5 + (z1 - z0 - 1) * j / nz
			if not stallZone(x, z) or math.abs(x) > 176 or math.abs(z) > 176 then
				return false
			end
			for _, k in ipairs(KEEP) do
				if x > k[1] and x < k[3] and z > k[2] and z < k[4] then
					return false
				end
			end
		end
	end
	for _, c in ipairs(claims) do
		if x0 < c[3] - 0.01 and x1 > c[1] + 0.01 and z0 < c[4] - 0.01 and z1 > c[2] + 0.01 then
			return false
		end
	end
	return true
end
local function take(x0, z0, x1, z1)
	if not free(x0, z0, x1, z1) then
		STATS.skipped += 1
		return false
	end
	table.insert(claims, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) })
	return true
end

-- a box by two corners in the frame `cf` (world CFrame); variant = px_* name or an Enum.Material
local function lbox(name, cf, x0, y0, z0, x1, y1, z1, variant, tint, parent, isDecor)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(name, size, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if type(variant) == "string" then
		textured(p, variant, tint)
	elseif variant then
		p.Material = variant
	end
	if isDecor then
		decor(p)
	end
	return p
end
-- a frame on the ground at local (x, z) whose −Z (the front of a stall / house / NPC) looks along (fx, fz)
local function faceCF(x, z, fx, fz, y)
	local p = V(x, y or 0, z)
	return CFrame.lookAt(p, p + Vector3.new(fx, 0, fz))
end

-- ================================================================ block props (concept close-ups)
local P = {}
function P.block(x, y, z, variant, tint, f, s)
	s = s or B
	return cube("Goods", x, y + s / 2, z, s, s, s, variant, tint, f)
end
-- a melon: a green wool block with a dark band round it
function P.melon(x, y, z, f)
	local m = P.block(x, y, z, "px_white_wool", COL.melon, f)
	m.Name = "Melon"
	lbox("MelonBand", m.CFrame, -2.05, -2.05, -0.7, 2.05, 2.05, 0.7, "px_white_wool", COL.melonDark, f, true)
	return m
end
function P.sack(x, z, f, y)
	y = y or 0
	cube("Sack", x, y + 1.5, z, 3, 3, 3, "px_brown_wool", COL.sack, f)
	decor(cube("SackTie", x, y + 3.4, z, 1.4, 0.8, 1.4, "px_brown_wool", COL.sackTie, f))
end
-- a dye barrel: the barrel with coloured water on top
function P.dye(x, z, col, f)
	barrel(x, 0, z, f)
	decor(cube("Dye", x, B + 0.15, z, 3.2, 0.3, 3.2, "px_water", col, f))
end
function P.lanternPost(x, z, f, h)
	h = h or 6
	cube("LanternPost", x, h / 2, z, 1, h, 1, "px_dark_oak_log", nil, f)
	decor(lantern(V(x, h + 0.75, z), f))
end
-- the concept's scales: a post on a stone block, a crossbar, two chains and two pans (beam along local z)
function P.scales(x, z, yaw, f)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	lbox("ScaleBase", cf, -2, 0, -2, 2, 1.6, 2, "px_stone_bricks", nil, f)
	lbox("ScalePost", cf, -0.6, 1.6, -0.6, 0.6, 9, 0.6, "px_dark_oak_log", nil, f)
	lbox("ScaleBeam", cf, -0.5, 9, -4.6, 0.5, 10, 4.6, "px_dark_oak_log", nil, f)
	for _, s in ipairs({ -1, 1 }) do
		lbox("ScaleChain", cf, -0.15, 5.3, s * 4 - 0.15, 0.15, 9, s * 4 + 0.15, Enum.Material.Metal, COL.iron, f, true)
		lbox("ScalePan", cf, -1.5, 4.8, s * 4 - 1.5, 1.5, 5.3, s * 4 + 1.5, "px_spruce_planks", nil, f, true)
	end
	lbox("ScaleGoods", cf, -0.8, 5.3, -4.8, 0.8, 6.9, -3.2, "px_gold_block", nil, f, true)
end
-- a hand cart: plank bed with low sides, square wheels, two handles, two blocks of goods
function P.cart(x, z, yaw, f)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	lbox("CartBed", cf, -2.4, 2, -4, 2.4, 3.2, 4, "px_spruce_planks", nil, f)
	for _, s in ipairs({ -1, 1 }) do
		lbox("CartSide", cf, s * 2.4, 3.2, -4, s * 1.9, 4.4, 4, "px_dark_oak_planks", nil, f)
		lbox("CartWheel", cf, s * 2.5, 0, -1.8, s * 3.3, 3.6, 1.8, "px_dark_oak_log", nil, f)
		lbox("CartHandle", cf, s * 1.6 - 0.4, 2.4, -8, s * 1.6 + 0.4, 3.2, -4, "px_dark_oak_planks", nil, f)
	end
	for _, lz in ipairs({ -2, 2 }) do
		local g = pick({ { "px_hay" }, { "px_white_wool", COL.melon }, { "px_white_wool", pick(WOOLS) }, { "px_oak_log" } })
		lbox("CartLoad", cf, -1.9, 3.2, lz - 1.9, 1.9, 7, lz + 1.9, g[1], g[2], f)
	end
end
-- a chicken (white block body, head, beak, wattle) sitting at `cf`
function P.chicken(cf, f)
	lbox("Chicken", cf, -0.8, 0, -0.9, 0.8, 1.5, 1.1, "px_white_wool", nil, f, true)
	lbox("ChickenHead", cf, -0.5, 1.1, -1.5, 0.5, 2.3, -0.6, "px_white_wool", nil, f, true)
	lbox("ChickenBeak", cf, -0.3, 1.6, -2, 0.3, 1.9, -1.5, "px_yellow_wool", COL.orange, f, true)
	lbox("ChickenWattle", cf, -0.2, 1.1, -1.7, 0.2, 1.6, -1.5, "px_white_wool", COL.red, f, true)
end
-- a cage of iron bars with a chicken (4 x 4 studs)
function P.cage(x, y, z, f)
	local cf = at(x, y, z)
	lbox("CageFloor", cf, -2, 0, -2, 2, 0.6, 2, "px_spruce_planks", nil, f)
	lbox("CageTop", cf, -2, 3.6, -2, 2, 4, 2, "px_spruce_planks", nil, f)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		lbox("CageBar", cf, c[1] * 1.8 - 0.2, 0.6, c[2] * 1.8 - 0.2, c[1] * 1.8 + 0.2, 3.6, c[2] * 1.8 + 0.2, Enum.Material.Metal, COL.iron, f)
	end
	for _, o in ipairs({ -0.6, 0.6 }) do
		for _, s in ipairs({ -1, 1 }) do
			lbox("CageBar", cf, o - 0.12, 0.6, s * 1.8 - 0.12, o + 0.12, 3.6, s * 1.8 + 0.12, Enum.Material.Metal, COL.iron, f)
			lbox("CageBar", cf, s * 1.8 - 0.12, 0.6, o - 0.12, s * 1.8 + 0.12, 3.6, o + 0.12, Enum.Material.Metal, COL.iron, f)
		end
	end
	P.chicken(cf * CFrame.new(0, 0.6, 0.2) * CFrame.Angles(0, rng:NextNumber() * 1.2 - 0.6, 0), f)
end
-- a table: big = plank top with two benches (8 x 10 studs), small = square top with two stools (4 x 9)
function P.table(x, z, yaw, f, small)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	if small then
		lbox("TableTop", cf, -2, 3.2, -2, 2, 4, 2, "px_spruce_planks", nil, f)
		lbox("TableLeg", cf, -0.6, 0, -0.6, 0.6, 3.2, 0.6, "px_dark_oak_log", nil, f)
		for _, s in ipairs({ -1, 1 }) do
			lbox("Stool", cf, -1, 0, s * 3.5 - 1, 1, 2, s * 3.5 + 1, "px_spruce_planks", nil, f)
		end
	else
		lbox("TableTop", cf, -4, 3.2, -2, 4, 4, 2, "px_spruce_planks", nil, f)
		for _, s in ipairs({ -1, 1 }) do
			lbox("TableLeg", cf, s * 3 - 0.6, 0, -0.6, s * 3 + 0.6, 3.2, 0.6, "px_dark_oak_log", nil, f)
			lbox("Bench", cf, -4, 0, s * 4 - 1, 4, 2, s * 4 + 1, "px_dark_oak_planks", nil, f)
		end
	end
	return cf
end
-- a cellar trapdoor pair flat on the ground in a cobble frame
function P.cellar(x, z, yaw, f)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw or 0, 0)
	lbox("CellarFrame", cf, -4.5, 0, -2.5, 4.5, 0.3, 2.5, "px_cobblestone", nil, f)
	for _, s in ipairs({ -1, 1 }) do
		lbox("CellarDoor", cf, s * 0.1, 0.3, -2, s * 4, 0.6, 2, "px_dark_oak_planks", nil, f)
		lbox("CellarStrap", cf, s * 0.5, 0.6, -0.3, s * 3.6, 0.75, 0.3, Enum.Material.Metal, COL.iron, f, true)
	end
end
-- a notice board on two posts with a titled head board, posters and a little roof; faces (fx, fz)
function P.notice(x, z, fx, fz, title, f)
	local cf = faceCF(x, z, fx, fz)
	for _, s in ipairs({ -1, 1 }) do
		lbox("NoticePost", cf, s * 3.6 - 0.5, 0, -0.5, s * 3.6 + 0.5, 8.4, 0.5, "px_dark_oak_log", nil, f)
	end
	lbox("NoticeBoard", cf, -3.1, 2.6, -0.3, 3.1, 6.6, 0.3, "px_spruce_planks", nil, f)
	local head = lbox("NoticeHead", cf, -4.2, 6.8, -0.4, 4.2, 8.4, 0.4, "px_dark_oak_planks", nil, f)
	boardText(head, title, Color3.fromRGB(255, 214, 120))
	for k = -1, 1 do
		local up = (k % 2) * 0.4
		lbox("Poster", cf, k * 2 - 0.8, 3 + up, -0.42, k * 2 + 0.8, 5.8 + up, -0.3, nil, COL.paper, f, true)
	end
	lbox("NoticeRoof", cf, -4.6, 8.4, -1, 4.6, 9, 1, "px_roof_tiles", COL.roofBrown, f)
end
-- a pickaxe (handle + iron head) centred at the world CFrame `cf`, the handle along its Y
function P.pickaxe(cf, f)
	lbox("PickHandle", cf, -0.25, -2.2, -0.25, 0.25, 2.2, 0.25, "px_spruce_planks", nil, f, true)
	lbox("PickHead", cf, -1.8, 1.7, -0.35, 1.8, 2.4, 0.35, "px_iron_block", nil, f, true)
end
-- the concept's hatch in a stall floor: frame, black hole, the open lid standing up, ladder tops
function P.hatch(cf, f)
	lbox("HatchFrame", cf, -2.3, 0, -2.3, 2.3, 0.2, 2.3, "px_dark_oak_planks", nil, f)
	lbox("HatchHole", cf, -1.8, 0, -1.8, 1.8, 0.25, 1.8, nil, Color3.fromRGB(8, 8, 10), f, true)
	lbox("HatchLid", cf, -2, 0.2, 2.3, 2, 4.2, 2.7, "px_dark_oak_planks", nil, f)
	for _, s in ipairs({ -1.2, 1.2 }) do
		lbox("HatchStrap", cf, s - 0.25, 0.6, 2.2, s + 0.25, 3.8, 2.3, Enum.Material.Metal, COL.iron, f, true)
		lbox("LadderTop", cf, s - 0.2, 0.2, -1.6, s + 0.2, 1.4, -1.2, "px_spruce_planks", nil, f, true)
	end
end
-- a stone planter with grass and a block tree (hedge leaves)
function P.planterTree(x, z, h, f)
	if not take(x - 4, z - 4, x + 4, z + 4) then
		return
	end
	box("Planter", x - 4, 0, z - 4, x + 4, 2, z + 4, "px_stone_bricks", Color3.fromRGB(150, 148, 144), f)
	box("PlanterSoil", x - 3.4, 2, z - 3.4, x + 3.4, 2.2, z + 3.4, "px_grass_top", nil, f)
	tree(x, z, h, f, "px_hedge", "px_oak_log", 2)
end
-- a washing / cloth line between two posts (local x, z), coloured wool cloths hanging from it
function P.clothLine(ax, az, bx, bz, f, h)
	h = h or 11
	for _, p in ipairs({ { ax, az }, { bx, bz } }) do
		cube("LinePost", p[1], h / 2, p[2], 1, h, 1, "px_dark_oak_log", nil, f)
	end
	local a, b = V(ax, h - 0.4, az), V(bx, h - 0.4, bz)
	decor(beam("ClothRope", a, b, 0.2, Color3.fromRGB(70, 60, 50), f, Enum.Material.Fabric))
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local n = math.floor(len / 5)
	for i = 1, n - 1 do
		local p = a + dir * (i * len / n) - Vector3.new(0, 2, 0)
		local size = Vector3.new(0.2, 3.4 + rng:NextInteger(0, 1) * 0.8, if rng:NextNumber() < 0.5 then 3.2 else 2.4)
		local cloth = decor(part("Cloth", size, CFrame.lookAt(p, p + dir), nil, nil, f))
		textured(cloth, "px_white_wool", pick(WOOLS))
		cloth.CastShadow = false
	end
end
-- a small pile claimed on the ground: kind = hay | melons | crates | sacks | barrels | wool | dye | coal
function P.pile(kind, x, z, f)
	if not take(x - 4, z - 2, x + 4, z + 2) then
		return
	end
	local a, b = x - 2, x + 2
	if kind == "hay" then
		P.block(a, 0, z, "px_hay", nil, f)
		P.block(b, 0, z, "px_hay", nil, f)
		P.block(a, B, z, "px_hay", nil, f)
	elseif kind == "melons" then
		P.melon(a, 0, z, f)
		P.melon(b, 0, z, f)
		P.melon(b, B, z, f)
	elseif kind == "crates" then
		crate(a, 0, z, f)
		crate(b, 0, z, f)
		crate(a, B, z, f, B, 0.2)
	elseif kind == "sacks" then
		P.sack(a, z, f)
		P.sack(b, z, f)
		P.sack(a, z, f, 3)
	elseif kind == "barrels" then
		barrel(a, 0, z, f, "px_oak_log_top")
		barrel(b, 0, z, f, pick({ "px_hay", "px_coal_block", "px_gold_block" }))
	elseif kind == "wool" then
		P.block(a, 0, z, "px_white_wool", pick(WOOLS), f)
		P.block(b, 0, z, "px_white_wool", pick(WOOLS), f)
		P.block(b, B, z, "px_white_wool", pick(WOOLS), f)
	elseif kind == "dye" then
		P.dye(a, z, pick(WOOLS), f)
		P.dye(b, z, pick(WOOLS), f)
	elseif kind == "coal" then
		P.block(a, 0, z, "px_coal_block", nil, f)
		P.block(b, 0, z, "px_obsidian", nil, f)
		decor(cube("Tarp", x, B + 0.3, z, 2 * B + 0.6, 0.6, B + 0.6, "px_gray_wool", COL.grey, f))
	end
end

-- the props in the 1-block gaps between stalls of a row (two block slots along the row's depth)
local function gapProp(kind, ga, line, axis, d, f)
	local function pt(o)
		if axis == "x" then
			return ga, line + o
		end
		return line + o, ga
	end
	local ax, az = pt(-d / 2 + 2)
	local bx, bz = pt(d / 2 - 2)
	if kind == "hay" then
		P.block(ax, 0, az, "px_hay", nil, f)
		P.block(ax, B, az, "px_hay", nil, f)
		P.block(bx, 0, bz, "px_hay", nil, f)
	elseif kind == "melons" then
		P.melon(ax, 0, az, f)
		P.melon(bx, 0, bz, f)
		P.melon(ax, B, az, f)
	elseif kind == "barrel" then
		barrel(ax, 0, az, f, pick({ "px_hay", "px_gold_block", "px_coal_block", "px_oak_log_top" }))
		crate(bx, 0, bz, f)
	elseif kind == "crates" then
		crate(ax, 0, az, f)
		crate(ax, B, az, f, B, rng:NextNumber() * 0.5 - 0.25)
		crate(bx, 0, bz, f)
	elseif kind == "sacks" then
		P.sack(ax, az, f)
		P.sack(bx, bz, f)
		P.sack(bx, bz, f, 3)
	elseif kind == "scales" then
		local cx, cz = pt(0)
		P.scales(cx, cz, if axis == "x" then 0 else math.pi / 2, f)
	elseif kind == "wool" then
		P.block(ax, 0, az, "px_white_wool", pick(WOOLS), f)
		P.block(ax, B, az, "px_white_wool", pick(WOOLS), f)
		P.block(bx, 0, bz, "px_white_wool", pick(WOOLS), f)
	elseif kind == "dye" then
		P.dye(ax, az, pick(WOOLS), f)
		P.dye(bx, bz, pick(WOOLS), f)
	elseif kind == "contraband" then
		crate(ax, 0, az, f)
		decor(cube("Tarp", ax, B + 0.3, az, B + 0.6, 0.6, B + 0.6, "px_gray_wool", COL.grey, f))
		P.block(bx, 0, bz, pick({ "px_obsidian", "px_coal_block", "px_gold_block" }), nil, f)
	elseif kind == "lantern" then
		local cx, cz = pt(0)
		P.lanternPost(cx, cz, f)
		P.sack(bx, bz, f)
	end
end

-- ================================================================ stall styles per district
local AW_MINE = { { COL.red, COL.white }, { COL.yellow, COL.white }, { COL.lime, COL.white } }
local ST = {
	food = {
		awnings = AW_MINE,
		widths = { 12, 16, 16, 20 },
		goods = { { "px_white_wool", COL.melon }, { "px_hay" }, { "px_hay" }, { "px_white_wool", COL.melon }, { "px_oak_log" }, { "px_white_wool", COL.orange } },
		bulk = { { "px_hay" }, { "px_white_wool", COL.melon } },
		signs = { "Еда" },
		signChance = 0.3,
		gap = 0.4,
		props = { "hay", "melons", "barrel", "sacks", "scales", "crates" },
		lanternChance = 0.2,
	},
	craft = {
		awnings = AW_MINE,
		widths = { 12, 16, 20 },
		goods = { { "px_white_wool", COL.red }, { "px_white_wool", COL.yellow }, { "px_white_wool", COL.lime }, { "px_white_wool", COL.blue }, { "px_iron_block" }, { "px_oak_log" } },
		bulk = { { "px_white_wool", COL.red }, { "px_white_wool", COL.yellow }, { "px_white_wool", COL.lime }, { "px_white_wool", COL.purple } },
		signs = { "Шерсть", "Ткани", "Инструменты" },
		signChance = 0.35,
		gap = 0.4,
		props = { "wool", "dye", "crates", "barrel", "scales", "dye" },
		lanternChance = 0.2,
	},
	smug = {
		awnings = { { COL.grey, COL.black }, { COL.black, COL.grey }, { COL.wine, COL.black } },
		widths = { 12, 12, 16 },
		goods = { { "px_obsidian" }, { "px_coal_block" }, { "px_gold_block" }, { "px_iron_block", COL.ironDark }, { "px_blackstone" } },
		bulk = { { "px_coal_block" }, { "px_obsidian" }, { "px_blackstone" } },
		signs = { "Контрабанда", "Ключи" },
		signChance = 0.25,
		gap = 0.3,
		props = { "contraband", "crates", "barrel", "lantern" },
		lanternChance = 0.35,
	},
	mixed = {
		awnings = AW_MINE,
		widths = { 12, 16, 20 },
		goods = { { "px_gold_block" }, { "px_iron_block" }, { "px_white_wool", COL.red }, { "px_hay" }, { "px_oak_log" }, { "px_white_wool", COL.melon } },
		bulk = { { "px_hay" }, { "px_white_wool", COL.yellow }, { "px_iron_block" } },
		signs = { "Ключи", "Инструменты", "Еда" },
		signChance = 0.3,
		gap = 0.35,
		props = { "crates", "barrel", "scales", "sacks" },
		lanternChance = 0.2,
	},
}

-- one stall: the kit stall (striped awning, counter, shelf, goods) + block displays inside, maybe a lantern;
-- hatch = the smugglers' stall with the trapdoor in its floor and a pickaxe by it
local function shop(cf, w, d, st, parent, hatch, lift)
	local aw = pick(st.awnings)
	local goods, tints = {}, {}
	for i = 1, (if w >= 16 then 4 else 3) do
		local g = pick(st.goods)
		goods[i], tints[i] = g[1], g[2]
	end
	local sgn = nil
	if not hatch and rng:NextNumber() < st.signChance then
		sgn = pick(st.signs)
	end
	local f = stall(cf, { w = w, d = d, colA = aw[1], colB = aw[2], goods = goods, sign = sgn }, parent)
	-- the kit draws white goods; tint the wool ones (Goods then ShelfGoods per item)
	local k = 0
	for _, p in ipairs(f:GetChildren()) do
		if p.Name == "Goods" or p.Name == "ShelfGoods" then
			k += 1
			local t = tints[math.floor((k - 1) / 2) + 1]
			if t then
				p.Color = t
			end
		end
	end
	-- neighbouring kit awnings overlap by a stud: every other stall lifts its awning so the two never z-fight
	if lift and lift > 0 then
		for _, p in ipairs(f:GetChildren()) do
			if p.Name == "Awning" or p.Name == "Valance" then
				p.CFrame += Vector3.new(0, lift, 0)
			end
		end
	end
	local side = 0
	if hatch then
		P.hatch(cf * CFrame.new(-w / 4, 0, -d / 2 + 6.5), f)
		P.pickaxe(cf * CFrame.new(-w / 4 + 3.6, 2.3, -d / 2 + 4.3) * CFrame.Angles(0.35, 0, 0.25), f)
	else
		-- full blocks of the stall's bulk goods inside, by the counter ends
		side = if rng:NextNumber() < 0.5 then -1 else 1
		local sides = if w >= 20 then { -1, 1 } else { side }
		for _, s in ipairs(sides) do
			local b = pick(st.bulk)
			local bx = s * (w / 2 - 3)
			lbox("Display", cf, bx - 2, 0, -d / 2 + 2.6, bx + 2, 4, -d / 2 + 6.6, b[1], b[2], f)
		end
	end
	if rng:NextNumber() < st.lanternChance then
		local pos = (cf * CFrame.new(w / 2 - 0.5, 5.8, -d / 2 - 0.3)).Position
		decor(lantern(pos, f, false, pos.Y + 1.4))
	end
	STATS.stalls += 1
	return f, side
end

-- a row of stalls along `axis` at the cross coordinate `line`, facing `face` (±1 along the other axis), over the
-- segments; widths 3–5 blocks, 1-block gaps with props or open passages between some stalls
local function row(r)
	local d = r.d or 8
	local st = r.st
	r.placed = {}
	local function fp(a0, a1)
		if r.axis == "x" then
			return a0, r.line - d / 2, a1, r.line + d / 2
		end
		return r.line - d / 2, a0, r.line + d / 2, a1
	end
	for _, s in ipairs(r.segs) do
		local pos = s[1]
		while s[2] - pos >= 12 do
			local w = pick(st.widths)
			while w > s[2] - pos do
				w -= 4
			end
			local x0, z0, x1, z1 = fp(pos, pos + w)
			if take(x0, z0, x1, z1) then
				local c = pos + w / 2
				local cf = if r.axis == "x" then faceCF(c, r.line, 0, r.face) else faceCF(r.line, c, r.face, 0)
				local hatch = r.hatch == #r.placed + 1
				local _, side = shop(cf, w, d, st, r.f, hatch, (#r.placed % 2) * 0.25)
				table.insert(r.placed, { cf = cf, w = w, d = d, side = side })
				pos += w
				local roll = rng:NextNumber()
				if s[2] - pos >= 16 and roll < st.gap + 0.12 then
					if roll < st.gap then
						local gx0, gz0, gx1, gz1 = fp(pos, pos + 4)
						if take(gx0, gz0, gx1, gz1) then
							gapProp(pick(st.props), pos + 2, r.line, r.axis, d, r.f)
						end
					end
					pos += 4 -- a prop slot, or an open passage through the row
				end
			else
				pos += 4
			end
		end
		-- the leftover at the segment's end: one more prop slot
		if s[2] - pos >= 4 then
			local gx0, gz0, gx1, gz1 = fp(pos, pos + 4)
			if take(gx0, gz0, gx1, gz1) then
				gapProp(pick(st.props), pos + 2, r.line, r.axis, d, r.f)
			end
		end
	end
end

-- THE ROWS (local studs; line = the row's centre line, d = depth). Lanes: F2|F3 z 38..54, F6|F7 z 130..146,
-- the N-S lane x 66..84; C1|C2 x -166..-146, C4|C5 z 130..146; S1|S2 z -146..-130, S4|S5 x -166..-146.
local ROWS = {
	-- FOOD ROW
	{ id = "F1", f = DF.food, st = ST.food, axis = "z", line = 62, face = -1, segs = { { 30, 110 } }, trader = 2 },
	{ id = "F2", f = DF.food, st = ST.food, axis = "x", line = 34, face = -1, segs = { { 82, 174 } } },
	{ id = "F3", f = DF.food, st = ST.food, axis = "x", line = 58, face = -1, segs = { { 84, 122 }, { 140, 174 } } },
	{ id = "F4", f = DF.food, st = ST.food, axis = "x", line = 66, face = 1, segs = { { 84, 122 }, { 140, 174 } } },
	{ id = "F5", f = DF.food, st = ST.food, axis = "x", line = 118, face = -1, segs = { { 6, 58 }, { 84, 174 } }, trader = 1, label = true },
	{ id = "F6", f = DF.food, st = ST.food, axis = "x", line = 126, face = 1, segs = { { 6, 58 }, { 84, 174 } } },
	{ id = "F7", f = DF.food, st = ST.food, axis = "x", line = 150, face = -1, segs = { { -26, 62 }, { 86, 174 } }, trader = 3 },
	-- CRAFT & CLOTH
	{ id = "C1", f = DF.craft, st = ST.craft, axis = "z", line = -142, face = 1, segs = { { 50, 110 } }, trader = 2 },
	{ id = "C2", f = DF.craft, st = ST.craft, axis = "z", line = -170, face = 1, segs = { { 50, 110 } } },
	{ id = "C3", f = DF.craft, st = ST.craft, axis = "x", line = 118, face = -1, segs = { { -146, -58 } }, trader = -1, label = true },
	{ id = "C4", f = DF.craft, st = ST.craft, axis = "x", line = 126, face = 1, segs = { { -146, -58 } } },
	{ id = "C5", f = DF.craft, st = ST.craft, axis = "x", line = 150, face = -1, segs = { { -174, -128 }, { -96, -56 } } },
	-- SMUGGLERS' ALLEY
	{ id = "S1", f = DF.smug, st = ST.smug, axis = "x", line = -126, face = 1, segs = { { -174, -56 } }, trader = 4 },
	{ id = "S2", f = DF.smug, st = ST.smug, axis = "x", line = -152, face = 1, d = 12, segs = { { -174, -56 } }, hatch = 3 },
	{ id = "S4", f = DF.smug, st = ST.smug, axis = "z", line = -142, face = -1, segs = { { -96, 2 } }, trader = 2 },
	{ id = "S5", f = DF.smug, st = ST.smug, axis = "z", line = -170, face = 1, segs = { { -96, 2 } } },
	-- the plaza's north edge (between the cross street and the plaza)
	{ id = "P1", f = DF.plaza, st = ST.mixed, axis = "x", line = -94, face = 1, segs = { { -134, -56 }, { -26, 46 } }, trader = -1, label = true },
	-- EAST MIDDLE (round the tavern)
	{ id = "E1", f = DF.east, st = ST.mixed, axis = "z", line = 62, face = -1, segs = { { -44, 2 } }, trader = 1 },
	{ id = "E2", f = DF.east, st = ST.food, axis = "x", line = 0, face = 1, segs = { { 70, 94 }, { 138, 174 } } },
}
local R = {}
for _, r in ipairs(ROWS) do
	R[r.id] = r
end

-- a two-storey half-timbered house (north middle): log frame, plank ground floor with an open shop front, white
-- upper storey with windows, a balcony over a striped awning, a stepped roof; front at frontZ facing `face` (±z)
local function house(cx, frontZ, w, d, face, o)
	local zb = frontZ - face * d
	if not take(cx - w / 2, math.min(frontZ, zb), cx + w / 2, math.max(frontZ, zb)) then
		return nil
	end
	local f = folder("TimberHouse", DF.north)
	local cf = faceCF(cx, frontZ, 0, face)
	local hw, LOG = w / 2, "px_dark_oak_log"
	-- the frame: log corner posts from the ground to the eaves
	for _, sx in ipairs({ -1, 1 }) do
		for _, zz in ipairs({ 0, d - 4 }) do
			lbox("TimberPost", cf, sx * hw, 0, zz, sx * (hw - 4), 20, zz + 4, LOG, nil, f)
		end
		lbox("WallLow", cf, sx * hw, 0, 4, sx * (hw - 4), 8, d - 4, o.low, o.lowTint, f)
		lbox("Beam", cf, sx * hw, 8, 4, sx * (hw - 4), 12, d - 4, LOG, nil, f)
		lbox("WallUp", cf, sx * hw, 12, 4, sx * (hw - 4), 20, d - 4, o.up, o.upTint, f)
	end
	lbox("WallLow", cf, -hw + 4, 0, d - 4, hw - 4, 8, d, o.low, o.lowTint, f)
	-- the beam ring at the first floor, the white upper storey, the ceiling of the shop
	for _, zz in ipairs({ 0, d - 4 }) do
		lbox("Beam", cf, -hw + 4, 8, zz, hw - 4, 12, zz + 4, LOG, nil, f)
		lbox("WallUp", cf, -hw + 4, 12, zz, hw - 4, 20, zz + 4, o.up, o.upTint, f)
	end
	lbox("Ceiling", cf, -hw + 4, 11, 4, hw - 4, 12, d - 4, "px_spruce_planks", nil, f)
	-- the upper front: windows with plank shutters, a log strip between two windows
	for _, wx in ipairs(if w >= 20 then { -3.5, 3.5 } else { 0 }) do
		lbox("Window", cf, wx - 1.3, 14, -0.15, wx + 1.3, 18, 0, nil, COL.glass, f, true)
		lbox("Shutter", cf, wx - 2.4, 14, -0.3, wx - 1.3, 18, 0, "px_spruce_planks", o.shutter, f, true)
		lbox("Shutter", cf, wx + 1.3, 14, -0.3, wx + 2.4, 18, 0, "px_spruce_planks", o.shutter, f, true)
	end
	if w >= 20 then
		lbox("TimberStrip", cf, -0.6, 12, -0.2, 0.6, 20, 0, LOG, nil, f, true)
	end
	-- the shop: a counter with a way in at one end, goods, a back shelf, the striped awning, a name board
	lbox("Counter", cf, -hw + 4, 0, 0.6, hw - 8, 3.4, 2.6, "px_spruce_planks", nil, f)
	lbox("CounterTop", cf, -hw + 4, 3.4, 0.3, hw - 8, 4, 2.9, "px_dark_oak_planks", nil, f)
	local gx = -hw + 5.2
	while gx < hw - 9 do
		local g = pick(o.goods)
		lbox("Goods", cf, gx - 0.9, 4, 0.7, gx + 0.9, 5.8, 2.5, g[1], g[2], f, true)
		gx += 2.4
	end
	lbox("Shelf", cf, -hw + 4, 5, d - 5.6, hw - 4, 5.5, d - 4, "px_spruce_planks", nil, f)
	for k = 0, 2 do
		local g = pick(o.goods)
		lbox("ShelfGoods", cf, -hw + 5 + k * 3, 5.5, d - 5.4, -hw + 6.6 + k * 3, 7.1, d - 4.2, g[1], g[2], f, true)
	end
	lbox("Crate", cf, -hw + 4.2, 0, d - 7.8, -hw + 8, 3.8, d - 4.2, "px_planks", COL.crate, f)
	awning(cf * CFrame.new(0, 6.8, -3.6), w, 3.6, o.aw[1], o.aw[2], f)
	local board = lbox("ShopBoard", cf, -4, 9.2, -0.35, 4, 11.4, -0.05, "px_spruce_planks", nil, f, true)
	boardText(board, o.sign, nil, { Enum.NormalId.Front })
	-- the balcony over the shop: plank floor on log brackets, rails, a flower box
	lbox("Balcony", cf, -hw, 12, -4, hw, 12.8, 0, "px_dark_oak_planks", nil, f)
	for _, sx in ipairs({ -1, 1 }) do
		lbox("Bracket", cf, sx * (hw - 2) - 0.6, 10.8, -3.4, sx * (hw - 2) + 0.6, 12, 0, LOG, nil, f, true)
		lbox("RailSide", cf, sx * hw, 12.8, -3.9, sx * (hw - 0.6), 15.8, 0, "px_dark_oak_planks", nil, f)
	end
	lbox("Rail", cf, -hw + 0.6, 15.2, -3.9, hw - 0.6, 15.8, -3.3, "px_dark_oak_planks", nil, f)
	for k = 1, w / 4 - 1 do
		local px = -hw + k * 4
		lbox("RailPost", cf, px - 0.4, 12.8, -3.9, px + 0.4, 15.2, -3.3, "px_dark_oak_planks", nil, f)
	end
	lbox("FlowerBox", cf, hw - 5, 12.8, -3.2, hw - 1, 14, -1.6, "px_spruce_planks", nil, f, true)
	lbox("Flowers", cf, hw - 4.7, 14, -3, hw - 1.3, 14.8, -1.8, "px_hedge", nil, f, true)
	lbox("Bloom", cf, hw - 4.4, 14.8, -2.8, hw - 3.4, 15.6, -2, "px_white_wool", COL.red, f, true)
	lbox("Bloom", cf, hw - 2.6, 14.8, -2.8, hw - 1.6, 15.6, -2, "px_yellow_wool", nil, f, true)
	if o.banner then
		banner(cf * CFrame.new(-hw + 2.5, 8.8, -4.3), o.banner, f, COL.white, 3, 6)
	end
	-- the stepped roof, the ridge along the front, overhanging all round; a chimney on some
	-- (the sides overhang only at a row's ends: o.ohA / o.ohB for local -x / +x, neighbours would overlap)
	local roofV = o.roofV or "px_roof_tiles"
	local ra, rb = -hw - (o.ohA or 0), hw + (o.ohB or 0)
	lbox("Roof", cf, ra, 20, -2, rb, 23, d + 2, roofV, o.roofT, f)
	lbox("Roof", cf, ra, 23, 2, rb, 26, d - 2, roofV, o.roofT, f)
	lbox("RoofRidge", cf, ra, 26, d / 2 - 1.5, rb, 28, d / 2 + 1.5, roofV, o.roofT, f)
	if o.chimney then
		lbox("Chimney", cf, hw - 6, 20, d - 6, hw - 2, 31, d - 2, "px_cobblestone", nil, f)
	end
	STATS.houses += 1
	return cf
end

local LOOKS = {
	prisoner = { COL.prisoner, COL.prisonerPants },
	traders = {
		{ Color3.fromRGB(120, 84, 56), Color3.fromRGB(64, 52, 44) },
		{ Color3.fromRGB(70, 120, 64), Color3.fromRGB(80, 64, 48) },
		{ Color3.fromRGB(60, 84, 140), Color3.fromRGB(70, 70, 76) },
		{ Color3.fromRGB(130, 44, 48), Color3.fromRGB(50, 44, 40) },
		{ Color3.fromRGB(104, 70, 130), Color3.fromRGB(40, 40, 46) },
		{ Color3.fromRGB(196, 160, 70), Color3.fromRGB(90, 70, 50) },
	},
	smuggler = { Color3.fromRGB(44, 44, 50), Color3.fromRGB(30, 30, 34) },
	skins = { Color3.fromRGB(220, 180, 150), Color3.fromRGB(196, 150, 112), Color3.fromRGB(150, 104, 72), Color3.fromRGB(234, 196, 168) },
}
-- an NPC (pure decoration: no tag); look = { shirt, pants }
local function person(name, cf, look, label)
	local opt = { shirt = look[1], pants = look[2], skin = pick(LOOKS.skins) }
	if label then
		opt.label = label
		opt.labelColor = Color3.fromRGB(255, 214, 120)
	end
	npc(name, cf, opt, DF.life)
	STATS.npcs += 1
end

-- ================================================================ buildings first (they claim their ground)
-- TIMBER HOUSES (north middle): row 1 faces the cross street, row 2 faces the lane z -150..-134 between them
local HOUSE_ROWS = {}
do
	local LOW = { "px_planks", "px_spruce_planks", "px_cobblestone", "px_stone_bricks" }
	local UP = { "px_white_stone_bricks", "px_white_stone_bricks", "px_planks" }
	local SIGNS = { "Ткани", "Ключи", "Инструменты", "Шерсть", "Еда", "Ткани", "Ключи", "Инструменты", "Еда" }
	local GOODS = { { "px_gold_block" }, { "px_iron_block" }, { "px_white_wool", COL.red }, { "px_white_wool", COL.yellow }, { "px_white_wool", COL.lime }, { "px_oak_log" } }
	local ROOFS = { { "px_roof_tiles", COL.roofRed }, { "px_roof_tiles", COL.roofBrown }, { "px_dark_oak_planks", nil }, { "px_roof_tiles", COL.roofDark } }
	-- { centre x, front z, width, the row's west end?, east end? } (all face +z: local -x is world east)
	local list = {
		{ -18, -122, 16, true, false },
		{ 0, -122, 20 },
		{ 18, -122, 16 },
		{ 36, -122, 20, false, true },
		{ -16, -150, 20, true, false },
		{ 2, -150, 16 },
		{ 20, -150, 20 },
		{ 38, -150, 16 },
		{ 54, -150, 16, false, true },
	}
	for i, h in ipairs(list) do
		local roof = ROOFS[(i - 1) % #ROOFS + 1]
		local cf = house(h[1], h[2], h[3], 12, 1, {
			low = LOW[(i - 1) % #LOW + 1],
			up = UP[(i - 1) % #UP + 1],
			shutter = if i % 2 == 0 then Color3.fromRGB(120, 150, 110) else nil,
			aw = AW_MINE[(i - 1) % 3 + 1],
			sign = SIGNS[i],
			goods = GOODS,
			roofV = roof[1],
			roofT = roof[2],
			chimney = i % 3 == 1,
			ohA = if h[5] then 1 else 0,
			ohB = if h[4] then 1 else 0,
			banner = if i % 3 == 0 then BANNER_RED elseif i % 4 == 2 then BANNER_YELLOW else nil,
		})
		if cf then
			table.insert(HOUSE_ROWS, { cf = cf, x = h[1], z = h[2], w = h[3] })
		end
	end
	-- bunting over the lane: from the row-2 balconies to the back eaves of row 1
	for _, h in ipairs(HOUSE_ROWS) do
		if h.z == -150 and h.x <= 46 then
			bunting(V(h.x - h.w / 2 + 1, 15.8, -146.2), V(h.x - h.w / 2 + 1, 18, -134.2), FLAGS, DF.north)
		end
	end
end

-- THE TAVERN (east middle): a timber hall with a door and windows to the terrace on the east street
do
	local f = DF.east
	local tx0, tz0, tx1, tz1 = 100, -44, 132, -20
	if take(tx0, tz0, tx1, tz1) then
		local LOG = "px_dark_oak_log"
		-- walls: a cobble plinth under white infill; the door (x 112..120) faces south
		for _, w in ipairs({
			{ tx0 + 4, tz0, tx1 - 4, tz0 + 4 },
			{ tx0, tz0 + 4, tx0 + 4, tz1 - 4 },
			{ tx1 - 4, tz0 + 4, tx1, tz1 - 4 },
			{ tx0 + 4, tz1 - 4, 108, tz1 },
			{ 124, tz1 - 4, tx1 - 4, tz1 },
		}) do
			box("TavernPlinth", w[1], 0, w[2], w[3], 4, w[4], "px_cobblestone", nil, f)
			box("TavernWall", w[1], 4, w[2], w[3], 12, w[4], "px_white_stone_bricks", nil, f)
		end
		box("TavernLintel", 112, 8, tz1 - 4, 120, 12, tz1, LOG, nil, f)
		-- log posts at the corners and beside the door
		for _, p in ipairs({ { tx0, tz0 }, { tx1 - 4, tz0 }, { tx0, tz1 - 4 }, { tx1 - 4, tz1 - 4 }, { 108, tz1 - 4 }, { 120, tz1 - 4 } }) do
			box("TavernPost", p[1], 0, p[2], p[1] + 4, 12, p[2] + 4, LOG, nil, f)
		end
		-- the eaves (also the ceiling) and the stepped roof, ridge along x
		box("TavernEaves", tx0 - 0.4, 12, tz0 - 0.4, tx1 + 0.4, 14, tz1 + 0.4, LOG, nil, f)
		for k = 0, 3 do
			box("TavernRoof", tx0 - 2, 14 + k * 3, tz0 - 2 + k * 4, tx1 + 2, 17 + k * 3, tz1 + 2 - k * 4, "px_roof_tiles", COL.roofRed, f)
		end
		box("TavernChimney", tx1 - 9, 14, tz0 + 1, tx1 - 5, 28, tz0 + 5, "px_cobblestone", nil, f)
		-- windows with shutters and flower boxes on the south front
		for _, wx in ipairs({ 106, 126 }) do
			decor(box("TavernWindow", wx - 1.2, 5, tz1, wx + 1.2, 9, tz1 + 0.15, nil, COL.glass, f))
			decor(box("Shutter", wx - 1.8, 5, tz1, wx - 1.2, 9, tz1 + 0.3, "px_spruce_planks", nil, f))
			decor(box("Shutter", wx + 1.2, 5, tz1, wx + 1.8, 9, tz1 + 0.3, "px_spruce_planks", nil, f))
			decor(box("FlowerBox", wx - 1.8, 4, tz1, wx + 1.8, 5, tz1 + 1.4, "px_spruce_planks", nil, f))
			decor(box("Flowers", wx - 1.5, 5, tz1 + 0.2, wx + 1.5, 5.8, tz1 + 1.2, "px_hedge", nil, f))
		end
		local sgn = decor(box("TavernSign", 110, 8.6, tz1 + 0.05, 122, 11.4, tz1 + 0.35, "px_spruce_planks", nil, f))
		boardText(sgn, "Таверна", Color3.fromRGB(255, 214, 120), { Enum.NormalId.Back })
		-- «Розыск» posters on the east wall
		local wanted = decor(box("WantedHead", tx1 + 0.05, 8, -36, tx1 + 0.4, 9.6, -28, "px_dark_oak_planks", nil, f))
		boardText(wanted, "РОЗЫСК", Color3.fromRGB(255, 214, 120), { Enum.NormalId.Right })
		for k = 0, 2 do
			decor(box("Poster", tx1 + 0.05, 4.6 + (k % 2) * 0.4, -35.6 + k * 2.6, tx1 + 0.2, 7.4 + (k % 2) * 0.4, -33.6 + k * 2.6, nil, COL.paper, f))
		end
		-- inside: plank floor, the bar with barrels behind it, two small tables, hanging lanterns
		box("TavernFloor", tx0 + 4, 0, tz0 + 4, tx1 - 4, 0.2, tz1 - 4, "px_dark_oak_planks", nil, f)
		box("Bar", 104, 0, -36, 122, 3.6, -33.6, "px_spruce_planks", nil, f)
		box("BarTop", 104, 3.6, -36.4, 122.4, 4.2, -33.2, "px_dark_oak_planks", nil, f)
		barrel(106, 0.2, -38, f, "px_oak_log_top")
		barrel(126, 0.2, -38, f)
		barrel(126, 4.2, -38, f)
		P.table(108, -29, 0, f, true)
		P.table(124, -29, 0, f, true)
		lantern(V(110, 9, -30), f, false, 12)
		lantern(V(122, 9, -30), f, false, 12)
		person("TavernKeeper", faceCF(115, -38, 0, 1, 3.2), LOOKS.traders[1])
	end
end

-- THE SMITHY (Кузня) in the gap of row C5: forge with a glowing mouth, chimney, anvil, quench trough, tool rack
do
	local f = folder("Smithy", DF.craft)
	if take(-126, 148, -98, 174) then
		local LOG = "px_dark_oak_log"
		box("SmithyFloor", -126, 0, 148, -98, 0.3, 174, "px_stone_bricks", Color3.fromRGB(140, 138, 134), f)
		box("SmithyWall", -126, 0.3, 170, -98, 12, 174, "px_blackstone_bricks", nil, f)
		box("SmithyWall", -126, 0.3, 156, -122, 12, 170, "px_cobblestone", nil, f)
		box("SmithyWall", -102, 0.3, 156, -98, 12, 170, "px_cobblestone", nil, f)
		box("SmithyPost", -126, 0.3, 148, -122, 12, 152, LOG, nil, f)
		box("SmithyPost", -102, 0.3, 148, -98, 12, 152, LOG, nil, f)
		box("SmithyBeam", -122, 8, 148, -102, 12, 152, LOG, nil, f)
		-- a lean-to roof stepping up toward the back
		box("SmithyRoof", -128, 12, 146, -96, 13, 176, "px_roof_tiles", COL.roofDark, f)
		box("SmithyRoof", -128, 13, 154, -96, 14, 176, "px_roof_tiles", COL.roofDark, f)
		box("SmithyRoof", -128, 14, 162, -96, 15, 176, "px_roof_tiles", COL.roofDark, f)
		-- the forge: blackstone with a glowing mouth, sparks, a chimney through the roof with smoke
		box("Forge", -122, 0.3, 162, -112, 6, 170, "px_blackstone", nil, f)
		local fire = decor(box("ForgeFire", -119.5, 1.4, 161.7, -114.5, 4, 162, nil, COL.ember, f))
		fire.Material = Enum.Material.Neon
		light(fire, 22, 1.6, COL.ember)
		emitter(fire, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 90, 20)),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Rate = 5,
			Lifetime = NumberRange.new(0.6, 1.2),
			Speed = NumberRange.new(3, 6),
			SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Front,
		})
		box("ForgeChimney", -120, 6, 164, -114, 26, 170, "px_blackstone_bricks", nil, f)
		local top = decor(cube("SmokeVent", -117, 26.5, 167, 4, 1, 4, nil, nil, f))
		top.Transparency = 1
		emitter(top, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(110, 106, 104)),
			Size = NumberSequence.new(2, 6),
			Transparency = NumberSequence.new(0.4, 1),
			Rate = 3,
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(10, 10),
		})
		P.block(-110, 0.3, 168, "px_coal_block", nil, f)
		-- the anvil (dark iron, three blocks high in steps)
		cube("AnvilBase", -110, 0.9, 158, 3, 1.2, 2.4, "px_iron_block", COL.ironDark, f)
		cube("AnvilWaist", -110, 2.1, 158, 1.6, 1.2, 1.4, "px_iron_block", COL.ironDark, f)
		cube("AnvilTop", -110, 3.3, 158, 4.4, 1.2, 2.2, "px_iron_block", COL.ironDark, f)
		-- the quench trough and the tool rack on the back wall
		box("Trough", -106, 0.3, 162, -102, 2.6, 170, "px_spruce_planks", nil, f)
		decor(box("TroughWater", -105.4, 2.6, 162.6, -102.6, 2.8, 169.4, "px_water", nil, f))
		decor(box("ToolRack", -110, 6, 169.4, -102, 6.6, 170, "px_spruce_planks", nil, f))
		P.pickaxe(at(-108, 8.6, 169.5) * CFrame.Angles(0, 0, 0.3), f)
		P.pickaxe(at(-104, 8.6, 169.5) * CFrame.Angles(0, 0, -0.3), f)
		local sgn = decor(box("SmithySign", -117, 8.6, 147.6, -107, 11.4, 147.9, "px_spruce_planks", nil, f))
		boardText(sgn, "Кузня", Color3.fromRGB(255, 214, 120), { Enum.NormalId.Front })
		person("Smith", faceCF(-106.5, 158, -1, 0, 3.3), { Color3.fromRGB(90, 70, 56), Color3.fromRGB(46, 40, 36) })
	end
end

-- THE LOOKOUT in the smugglers' yard: log legs, a railed deck, a roof, a ladder on the east face
do
	local f = folder("Lookout", DF.smug)
	local lx, lz = -164, -165
	if take(lx - 6, lz - 6, lx + 8, lz + 6) then
		local LOG = "px_dark_oak_log"
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			box("LookoutLeg", lx + c[1] * 4.8 - 1, 0, lz + c[2] * 4.8 - 1, lx + c[1] * 4.8 + 1, 24, lz + c[2] * 4.8 + 1, LOG, nil, f)
		end
		box("LookoutDeck", lx - 6, 15, lz - 6, lx + 6, 16, lz + 6, "px_dark_oak_planks", nil, f)
		box("LookoutRail", lx - 6, 16, lz - 6, lx + 6, 18.4, lz - 5.4, "px_spruce_planks", nil, f)
		box("LookoutRail", lx - 6, 16, lz + 5.4, lx + 6, 18.4, lz + 6, "px_spruce_planks", nil, f)
		box("LookoutRail", lx - 6, 16, lz - 5.4, lx - 5.4, 18.4, lz + 5.4, "px_spruce_planks", nil, f)
		box("LookoutRail", lx + 5.4, 16, lz - 5.4, lx + 6, 18.4, lz - 2, "px_spruce_planks", nil, f)
		box("LookoutRail", lx + 5.4, 16, lz + 2, lx + 6, 18.4, lz + 5.4, "px_spruce_planks", nil, f)
		box("LookoutRoof", lx - 7, 24, lz - 7, lx + 7, 25, lz + 7, "px_dark_oak_planks", nil, f)
		box("LookoutRoof", lx - 4, 25, lz - 4, lx + 4, 26, lz + 4, "px_dark_oak_planks", nil, f)
		lantern(V(lx, 21.5, lz), f, false, 24)
		-- the ladder: an invisible truss to climb, rails and the ladder texture to see
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Size = Vector3.new(2, 16, 2)
		truss.CFrame = at(lx + 7, 8, lz)
		truss.Anchored = true
		truss.Transparency = 1
		truss.Parent = f
		for _, s in ipairs({ -1, 1 }) do
			cube("LadderRail", lx + 6.3, 8.2, lz + s * 1.8, 0.4, 16.4, 0.4, "px_spruce_planks", nil, f)
		end
		local plate = decor(cube("LadderFace", lx + 6.2, 8, lz, 0.2, 16, 3.2, nil, nil, f))
		plate.Transparency = 1
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = Enum.NormalId.Right
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		else
			for k = 1, 7 do
				decor(cube("LadderRung", lx + 6.3, k * 2, lz, 0.3, 0.3, 3.6, "px_spruce_planks", nil, f))
			end
		end
		person("Lookout", faceCF(lx - 1, lz - 1, 1, 1, 16 + 3), LOOKS.smuggler)
	end
end

-- THE WELL in the west quarter (the little square between the west street and the cloth lane)
do
	local f = folder("WellSquare", DF.craft)
	local wx, wz = -157, 38
	if take(wx - 5, wz - 5, wx + 5, wz + 5) then
		box("WellWall", wx - 4, 0, wz - 4, wx + 4, 3, wz - 2, "px_cobblestone", nil, f)
		box("WellWall", wx - 4, 0, wz + 2, wx + 4, 3, wz + 4, "px_cobblestone", nil, f)
		box("WellWall", wx - 4, 0, wz - 2, wx - 2, 3, wz + 2, "px_cobblestone", nil, f)
		box("WellWall", wx + 2, 0, wz - 2, wx + 4, 3, wz + 2, "px_cobblestone", nil, f)
		box("WellWater", wx - 2, 0, wz - 2, wx + 2, 2, wz + 2, "px_water", nil, f)
		for _, s in ipairs({ -1, 1 }) do
			box("WellPost", wx + s * 3.4 - 0.6, 3, wz - 0.6, wx + s * 3.4 + 0.6, 9, wz + 0.6, "px_oak_log", nil, f)
		end
		box("WellRoof", wx - 5, 9, wz - 4, wx + 5, 10, wz + 4, "px_roof_tiles", COL.roofBrown, f)
		box("WellRoof", wx - 5, 10, wz - 2, wx + 5, 11, wz + 2, "px_roof_tiles", COL.roofBrown, f)
		decor(box("WellAxle", wx - 2.8, 7.2, wz - 0.3, wx + 2.8, 7.8, wz + 0.3, "px_spruce_planks", nil, f))
		decor(box("WellRope", wx - 0.1, 4.6, wz - 0.1, wx + 0.1, 7.2, wz + 0.1, nil, Color3.fromRGB(80, 66, 50), f))
		decor(cube("WellBucket", wx, 3.9, wz, 1.4, 1.4, 1.4, "px_iron_block", COL.ironDark, f))
	end
	if take(-176, 33, -168, 43) then
		P.notice(-172, 38, 1, 0, "РОЗЫСК", f)
	end
	P.pile("barrels", -143, 31, f)
	P.pile("dye", -143, 45, f)
end

-- ================================================================ the rows of stalls
for _, r in ipairs(ROWS) do
	row(r)
end
task.wait()

-- bunting across the lanes between facing rows (front post to front post, or to the back posts of a row whose
-- back is on the lane)
do
	local function postTops(s, back)
		local z = if back then s.d / 2 - 0.5 else -s.d / 2 + 0.5
		return {
			(s.cf * CFrame.new(s.w / 2 - 0.5, 8.6, z)).Position,
			(s.cf * CFrame.new(-s.w / 2 + 0.5, 8.6, z)).Position,
		}
	end
	for _, pr in ipairs({
		{ "F6", "F7", FLAGS },
		{ "F3", "F2", FLAGS, true },
		{ "C4", "C5", FLAGS },
		{ "S4", "S5", DARK_FLAGS },
		{ "S2", "S1", DARK_FLAGS, true },
	}) do
		local ra, rb = R[pr[1]], R[pr[2]]
		for i, a in ipairs(ra.placed) do
			if i % 2 == 1 then
				local pa = postTops(a, false)[1]
				local best, bestD = nil, 26
				for _, b in ipairs(rb.placed) do
					for _, pb in ipairs(postTops(b, pr[4])) do
						local dd = (pb - pa).Magnitude
						if dd < bestD then
							best, bestD = pb, dd
						end
					end
				end
				if best then
					bunting(pa, best, pr[3], ra.f)
				end
			end
		end
	end
end

-- the smugglers' hatch stall gets its man; the rows get their traders behind the counters
do
	local s = R.S2.placed[R.S2.hatch]
	if s then
		person("Smuggler", s.cf * CFrame.new(s.w / 4, 3, -s.d / 2 + 5), LOOKS.smuggler)
	end
	local n = 0
	for _, r in ipairs(ROWS) do
		if r.trader then
			local i = if r.trader < 0 then #r.placed + 1 + r.trader else r.trader
			local st = r.placed[i]
			if st then
				n += 1
				local look = if r.st == ST.smug then LOOKS.smuggler else LOOKS.traders[(n - 1) % #LOOKS.traders + 1]
				person("Trader", st.cf * CFrame.new(-st.side * 1.2, 3, -st.d / 2 + 4.4), look, if r.label then "Торговец" else nil)
			end
		end
	end
	-- a keeper in one of the timber shops
	local h = HOUSE_ROWS[6]
	if h then
		person("Shopkeeper", h.cf * CFrame.new(-1.5, 3, 3.4), LOOKS.traders[5])
	end
end

-- ================================================================ district dressing
-- FOOD ROW: the court between F4 and F5 (cauldron, tables, chicken cages), the back strip by the south wall
do
	local f = folder("FoodCourt", DF.food)
	-- the soup cauldron over a campfire hanging from a log frame (concept prop)
	local cx, cz = 130, 90
	if take(cx - 5, cz - 4, cx + 5, cz + 4) then
		box("FireRing", cx - 3, 0, cz - 3, cx + 3, 0.8, cz + 3, "px_cobblestone", nil, f)
		cube("FireLog", cx, 1.2, cz, 5, 1, 1.2, "px_oak_log", nil, f)
		cube("FireLog", cx, 1.2, cz, 1.2, 1, 5, "px_oak_log", nil, f)
		local ember = decor(cube("Embers", cx, 1.1, cz, 3, 0.6, 3, nil, COL.ember, f))
		ember.Material = Enum.Material.Neon
		light(ember, 20, 1.4, COL.ember)
		emitter(ember, {
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 80, 20)),
			LightEmission = 0.8,
			Size = NumberSequence.new(1.6, 0.4),
			Transparency = NumberSequence.new(0.2, 1),
			Rate = 14,
			Lifetime = NumberRange.new(0.5, 0.9),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(15, 15),
		})
		cube("Cauldron", cx, 3.9, cz, 4, 3.4, 4, "px_iron_block", COL.ironDark, f)
		for _, r in ipairs({ { 0, -1.8, 4, 0.4 }, { 0, 1.8, 4, 0.4 }, { -1.8, 0, 0.4, 3.2 }, { 1.8, 0, 0.4, 3.2 } }) do
			decor(cube("CauldronRim", cx + r[1], 5.9, cz + r[2], r[3], 0.6, r[4], "px_iron_block", COL.iron, f))
		end
		local soup = decor(cube("Soup", cx, 5.75, cz, 3.2, 0.3, 3.2, "px_water", COL.soup, f))
		emitter(soup, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(235, 235, 235)),
			Size = NumberSequence.new(1.5, 4),
			Transparency = NumberSequence.new(0.5, 1),
			Rate = 4,
			Lifetime = NumberRange.new(2, 3),
			Speed = NumberRange.new(1.5, 3),
			SpreadAngle = Vector2.new(10, 10),
		})
		for _, s in ipairs({ -1, 1 }) do
			cube("PotPost", cx + s * 4.5, 4.5, cz, 1, 9, 1, "px_dark_oak_log", nil, f)
		end
		cube("PotBar", cx, 9.5, cz, 10, 1, 1, "px_dark_oak_log", nil, f)
		decor(cube("PotChain", cx, 7.6, cz, 0.3, 2.8, 0.3, nil, COL.iron, f)).Material = Enum.Material.Metal
		person("Cook", faceCF(cx, cz - 5.5, 0, 1, 3), { Color3.fromRGB(236, 232, 222), Color3.fromRGB(70, 60, 54) })
	end
	P.pile("sacks", 142, 84, f)
	P.pile("barrels", 142, 96, f)
	-- tables with benches, food on some of them
	for _, t in ipairs({ { 100, 82 }, { 100, 100 }, { 114, 92 }, { 154, 82 }, { 154, 100 } }) do
		if take(t[1] - 4, t[2] - 5, t[1] + 4, t[2] + 5) then
			local cf = P.table(t[1], t[2], 0, f)
			if rng:NextNumber() < 0.6 then
				lbox("Dish", cf, -2.6, 4, -0.9, -0.8, 5.8, 0.9, "px_white_wool", COL.melon, f, true)
				lbox("Dish", cf, 1, 4, -0.8, 2.6, 4.8, 0.8, "px_hay", nil, f, true)
			end
		end
	end
	P.planterTree(88, 92, 12, f)
	-- chicken cages by the east edge, two stacked under one
	if take(170, 76, 174, 84) then
		P.cage(172, 0, 78, f)
		P.cage(172, 0, 82, f)
		P.cage(172, 4, 80, f)
	end
	if take(164, 104, 168, 108) then
		P.cage(166, 0, 106, f)
	end

	-- the back strip by the south wall: stores, carts, trees, a cellar
	local back = folder("FoodStores", DF.food)
	P.planterTree(20, 166, 12, back)
	P.planterTree(120, 166, 12, back)
	for _, p in ipairs({
		{ "hay", 6, 170 },
		{ "sacks", 6, 160 },
		{ "melons", 68, 170 },
		{ "crates", 36, 170 },
		{ "hay", 90, 170 },
		{ "barrels", 100, 160 },
		{ "melons", 140, 170 },
		{ "crates", 160, 162 },
		{ "sacks", 168, 172 },
	}) do
		P.pile(p[1], p[2], p[3], back)
	end
	if take(48, 158, 60, 174) then
		P.cart(54, 166, math.pi / 2, back)
	end
	if take(76, 160, 84, 174) then
		P.cellar(80, 166, math.pi / 2, back)
	end
	if take(60, 114, 70, 124) then
		P.notice(64, 119, -0.6, -1, "Торговля", DF.food)
	end
end

-- CRAFT & CLOTH: cloth lines over the lanes, the back strip with drying racks, dye barrels and wool bales
do
	local f = folder("ClothLines", DF.craft)
	P.clothLine(-151, 52, -151, 108, f)
	P.clothLine(-161, 52, -161, 108, f)
	P.clothLine(-170, 138, -118, 138, f)
	P.clothLine(-110, 138, -64, 138, f)
	P.clothLine(-172, 160, -132, 160, f, 10)
	P.clothLine(-92, 160, -60, 160, f, 10)
	P.planterTree(-170, 122, 12, f)
	for _, p in ipairs({
		{ "dye", -168, 170 },
		{ "wool", -156, 170 },
		{ "dye", -144, 170 },
		{ "wool", -134, 168 },
		{ "wool", -88, 170 },
		{ "dye", -84, 160 },
	}) do
		P.pile(p[1], p[2], p[3], f)
	end
end

-- SMUGGLERS' ALLEY: the yard behind row S2 (card table, contraband under tarps, a cellar), a few lanterns
do
	local f = folder("SmugglersYard", DF.smug)
	local tx, tz = -134, -167
	if take(tx - 3, tz - 7, tx + 3, tz + 7) then
		local cf = P.table(tx, tz, 0, f, true)
		lbox("CardTop", cf, -2.2, 4, -2.2, 2.2, 4.1, 2.2, nil, Color3.fromRGB(40, 90, 50), f, true)
		lbox("Pot", cf, -0.6, 4.1, -0.6, 0.6, 5.3, 0.6, "px_gold_block", nil, f, true)
		decor(lantern((cf * CFrame.new(1.4, 4.85, 1.4)).Position, f))
		person("CardPlayer", faceCF(tx, tz - 5.5, 0, 1, 3), LOOKS.prisoner)
		person("CardPlayer", faceCF(tx, tz + 5.5, 0, -1, 3), LOOKS.smuggler)
	end
	for _, p in ipairs({
		{ "coal", -116, -168 },
		{ "crates", -104, -172 },
		{ "barrels", -90, -164 },
		{ "coal", -78, -170 },
		{ "crates", -64, -164 },
	}) do
		P.pile(p[1], p[2], p[3], f)
	end
	if take(-152, -173, -142, -163) then
		P.cellar(-147, -168, 0, f)
	end
	-- dim lanterns at the mouth of the west alley
	for _, p in ipairs({ { -147, -98 }, { -165, 4 } }) do
		P.lanternPost(p[1], p[2], f, 7)
	end
end

-- NORTH YARD behind the timber houses and the corners round the hero plaza
do
	local f = folder("NorthYard", DF.north)
	P.pile("crates", -20, -170, f)
	P.pile("barrels", 50, -172, f)
	if take(4, -175, 16, -165) then
		P.cart(10, -170, math.pi / 2, f)
	end
	if take(26, -173, 36, -167) then
		P.cellar(31, -170, 0, f)
	end
	P.planterTree(166, -166, 12, f)
	P.pile("crates", 150, -172, f)
end

-- EAST MIDDLE: the terrace in front of the tavern, the tea garden, the yard behind the plaza stalls
do
	local f = folder("Terrace", DF.east)
	for _, t in ipairs({ { 104, -10 }, { 128, -10 } }) do
		if take(t[1] - 4, t[2] - 5, t[1] + 4, t[2] + 5) then
			local cf = P.table(t[1], t[2], 0, f)
			lbox("Mug", cf, -1.8, 4, -0.5, -0.8, 5.2, 0.5, "px_spruce_planks", nil, f, true)
		end
	end
	for _, p in ipairs({ { 97, -17 }, { 135, -17 }, { 97, 0 }, { 135, 0 } }) do
		if take(p[1] - 1, p[2] - 1, p[1] + 1, p[2] + 1) then
			P.lanternPost(p[1], p[2], f)
		end
	end
	-- the tea garden: low tables with wool cushions, a tree, lantern posts
	local tea = folder("TeaGarden", DF.east)
	P.planterTree(166, -36, 12, tea)
	for _, t in ipairs({ { 148, -34 }, { 148, -16 }, { 162, -16 } }) do
		if take(t[1] - 4, t[2] - 4, t[1] + 4, t[2] + 4) then
			local cf = at(t[1], 0, t[2])
			lbox("TeaTable", cf, -2, 1.6, -2, 2, 2.4, 2, "px_spruce_planks", nil, tea)
			lbox("TeaLeg", cf, -0.6, 0, -0.6, 0.6, 1.6, 0.6, "px_dark_oak_log", nil, tea)
			lbox("Teapot", cf, -0.6, 2.4, -0.6, 0.6, 3.6, 0.6, "px_terracotta", nil, tea, true)
			for i, o in ipairs({ { 0, -3.2 }, { 0, 3.2 }, { -3.2, 0 }, { 3.2, 0 } }) do
				lbox("Cushion", cf, o[1] - 1, 0, o[2] - 1, o[1] + 1, 0.8, o[2] + 1, "px_white_wool", if i % 2 == 0 then COL.red else COL.yellow, tea)
			end
		end
	end
	for _, p in ipairs({ { 141, -43 }, { 141, -9 }, { 173, -9 } }) do
		if take(p[1] - 1, p[2] - 1, p[1] + 1, p[2] + 1) then
			P.lanternPost(p[1], p[2], tea)
		end
	end
	-- the yard behind the plaza stalls (E1): a cart, scales, stores, a cellar door
	local yard = folder("EastYard", DF.east)
	if take(76, -42, 84, -26) then
		P.cart(80, -32, 0, yard)
	end
	if take(88, -20, 92, -8) then
		P.scales(90, -14, 0, yard)
	end
	P.pile("crates", 74, -12, yard)
	P.pile("hay", 92, -40, yard)
	if take(66, -26, 76, -20) then
		P.cellar(71, -23, 0, yard)
	end
end

-- life in the lanes: prisoners browsing the stalls
person("Prisoner", faceCF(24, 133, 0, -1, 3), LOOKS.prisoner)
person("Prisoner", faceCF(-104, -143, 0, -1, 3), LOOKS.prisoner)
person("Prisoner", faceCF(-162, 80, -1, 0, 3), LOOKS.prisoner)

-- ================================================================ street dressing
-- lamp posts every ~24 studs alternating sides of each street (the arm over the street), flag bunting zigzagging
-- between neighbouring lamps; lamps and bunting round the plaza's outer edge; carts and barrels on street edges
do
	local f = DF.street
	local function run(pts, flags)
		for i, p in ipairs(pts) do
			lampPost(p[1], p[2], f, false, math.atan2(-p[3], -p[4]))
			if i > 1 and flags then
				local q = pts[i - 1]
				bunting(V(q[1], 10.2, q[2]), V(p[1], 10.2, p[2]), flags, f)
			end
		end
	end
	-- the south avenue (x -50..-30) and the north street (x -50..-30, broken by the cross street)
	run({ { -48, 142, 1, 0 }, { -32, 162, -1, 0 } }, FLAGS)
	run({ { -48, -88, 1, 0 } })
	run({ { -32, -132, -1, 0 }, { -48, -152, 1, 0 }, { -32, -170, -1, 0 } }, DARK_FLAGS)
	-- the west and the east streets (z 6..26)
	run({ { -144, 8, 0, 1 }, { -166, 24, 0, -1 } }, FLAGS)
	run({ { 68, 24, 0, -1 }, { 92, 8, 0, 1 }, { 116, 24, 0, -1 }, { 140, 8, 0, 1 }, { 164, 24, 0, -1 } }, FLAGS)
	-- the cross street (z -120..-100), west and east of the north street
	run({ { -170, -102, 0, -1 }, { -146, -118, 0, 1 }, { -122, -102, 0, -1 }, { -98, -118, 0, 1 }, { -74, -102, 0, -1 } }, FLAGS)
	run({ { -22, -118, 0, 1 }, { 2, -102, 0, -1 }, { 26, -118, 0, 1 }, { 46, -102, 0, -1 } }, FLAGS)
	-- the plaza's outer edge (lamps 2 studs inside it, gaps at the street mouths, the arrival and the hatch)
	run({ { -134, -70, 1, 0 }, { -134, -38, 1, 0 } }, FLAGS)
	run({ { -134, 44, 1, 0 }, { -134, 76, 1, 0 } }, FLAGS)
	run({ { 54, -70, -1, 0 }, { 54, -38, -1, 0 } }, FLAGS)
	run({ { 54, 44, -1, 0 }, { 54, 76, -1, 0 }, { 54, 104, -1, 0 } }, FLAGS)
	run({ { -124, -78, 0, 1 }, { -92, -78, 0, 1 }, { -64, -78, 0, 1 } }, FLAGS)
	run({ { -14, -78, 0, 1 }, { 18, -78, 0, 1 } }, FLAGS)
	run({ { -124, 110, 0, -1 }, { -92, 110, 0, -1 }, { -64, 110, 0, -1 } }, FLAGS)
	run({ { 20, 110, 0, -1 }, { 44, 110, 0, -1 } })
	-- carts and barrels standing at the street edges (between the lamps)
	P.cart(-33, 152, 0, f)
	P.cart(-47, -142, math.pi, f)
	P.cart(104, 9.5, math.pi / 2, f)
	P.cart(-156, 22.5, -math.pi / 2, f)
	P.cart(-86, -116.5, math.pi / 2, f)
	for _, b in ipairs({ { -33, 172 }, { -47.5, 134 }, { 152, 23.5 }, { 128, 8.5 }, { -110, -102.5 }, { 14, -117.5 } }) do
		barrel(b[1], 0, b[2], f, pick({ "px_hay", "px_oak_log_top", "px_coal_block" }))
	end
end

print(("[build-market] bazaar: %d stalls, %d houses, %d npcs, %d placements skipped, %d parts so far"):format(STATS.stalls, STATS.houses, STATS.npcs, STATS.skipped, count))
