-- ================================================================ gate: the plan shared by every part
local ISLAND = { x = 0, z = -20, ax = 170, az = 210 } -- a superellipse (power 3), mirror-symmetric in x
local PIT = { x = 0, z = 70, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 162 }
local BUYER = { x = -34, z = 166 }
local ROAD = { -12, -70, 12, -2 } -- the golden road (the square part)
local STAIR = { -20, -120, 20, -70 } -- the great stair y 0 → 24 (the gate part)
-- { x0, z0, x1, z1 } flights along the terrace front, from the outer end (y 0) in to y 24
local SIDE_STAIRS = {
	{ -112, -120, -64, -108 },
	{ 64, -120, 112, -108 },
}
local TERRACE_Y = 24
local TERRACE = { -120, -230, 120, -120 } -- the raised terrace (the core lifts its ground; its face is at z -120)
local GATE = { x = 0, z = -160, half = 24, wall = 112, top = 100 } -- the arch, the jasper wall x -112..112, z -164..-156
local SUMMIT = { x = 0, z = -140, y = TERRACE_Y } -- the top of the steps at the open gates
local BEAM = { x = 0, z = -196 }
local ANGELS = { { -48, -140 }, { 48, -140 } }
local ISLES = {
	{ name = "westA", x = -240, z = 60, r = 40 },
	{ name = "eastA", x = 240, z = 60, r = 40 },
	{ name = "westB", x = -216, z = -120, r = 32 },
	{ name = "eastB", x = 216, z = -120, r = 32 },
}
local BRIDGES =
	{ -- { x0, z0, x1, z1 } decks at y 0 (the sky part measures the real gap from the cells)
		{ -210, 52, -156, 68 },
		{ 156, 52, 210, 68 },
		{ -192, -128, -152, -112 },
		{ 152, -128, 192, -112 },
	}
local WALKS = { -- { x0, z0, x1, z1 } main walkways kept clear of props
	ROAD,
	{ -12, 134, 12, 190 }, -- the south axis from the arrival to the south tip
	{ -166, 52, -76, 68 }, -- west to the bridge A
	{ 76, 52, 166, 68 }, -- east to the bridge A
	{ -160, -128, -120, -112 }, -- west to the bridge B (round the terrace's foot)
	{ 120, -128, 160, -112 },
	{ -150, -112, -120, -70 }, -- along the terrace's foot from the square to the bridges B
	{ 120, -112, 150, -70 },
}

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
-- the main island: the noise reads |x| so both halves are mirror images
local function onMain(x, z, pad)
	local j = n2(math.abs(x), z, 4.4, 0.04) * 9 - (pad or 0)
	local ax, az = ISLAND.ax + j, ISLAND.az + j
	return (math.abs(x - ISLAND.x) / ax) ^ 3 + (math.abs(z - ISLAND.z) / az) ^ 3 <= 1
end
-- which island a point is on: "main", an islet's name or nil (the sky)
local function isleOf(x, z, pad)
	if onMain(x, z, pad) then
		return "main"
	end
	for _, s in ipairs(ISLES) do
		local r = s.r + n2(math.abs(x), z, 5.1, 0.05) * 6 - (pad or 0)
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 <= r * r then
			return s.name
		end
	end
	return nil
end
local function onTerrace(x, z, pad)
	return inRect(x, z, TERRACE, pad) and onMain(x, z)
end
-- the ground height: the terrace y 24, everything else y 0 (the stair is built by the gate part)
local function groundY(x, z)
	if not isleOf(x, z) then
		return nil
	end
	return if onTerrace(x, z) then TERRACE_Y else 0
end
local function onPath(x, z, pad)
	for _, w in ipairs(WALKS) do
		if inRect(x, z, w, pad) then
			return true
		end
	end
	for _, s in ipairs(SIDE_STAIRS) do
		if inRect(x, z, s, pad) then
			return true
		end
	end
	return inRect(x, z, STAIR, pad)
end
-- the part that owns a point: "gate", "square" or "sky"
local function zoneOf(x, z)
	if isleOf(x, z) ~= "main" then
		return "sky"
	end
	return if math.abs(x) <= 130 and z < -66 then "gate" else "square"
end
-- free ground for props: on an island, off the walks, the pit, the terrace edge, the arrival and the buyer
local function freeGround(x, z, pad)
	pad = pad or 0
	return isleOf(x, z, 10 + pad) ~= nil
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: bright white noon, pearl and gold (tints over already coloured textures stay light)
local PEARL = Color3.fromRGB(250, 248, 242) -- over px_smooth_stone / px_white_stone_bricks
local CALCITE = Color3.fromRGB(236, 238, 232)
local GOLD = Color3.fromRGB(255, 236, 170) -- a tint over px_gold_block (keep it light)
local GOLD_GLASS = Color3.fromRGB(255, 214, 90) -- yellow glass over the gold road
local JASPER = Color3.fromRGB(215, 240, 232) -- a tint over px_prismarine / px_dark_prismarine (already teal)
local SAND = Color3.fromRGB(250, 240, 214) -- over px_sandstone / px_cut_sandstone
local WATER = Color3.fromRGB(110, 170, 240)
local LIGHT = Color3.fromRGB(255, 240, 200)
local CYPRESS = Color3.fromRGB(170, 205, 150) -- a tint over px_hedge (already dark green)
local CLOUD = Color3.fromRGB(252, 252, 255)
local TRIBES = { -- the banners and the foundation stones: twelve colours
	Color3.fromRGB(200, 40, 40),
	Color3.fromRGB(240, 130, 30),
	Color3.fromRGB(245, 210, 50),
	Color3.fromRGB(120, 190, 50),
	Color3.fromRGB(40, 140, 70),
	Color3.fromRGB(40, 170, 180),
	Color3.fromRGB(60, 110, 210),
	Color3.fromRGB(40, 50, 150),
	Color3.fromRGB(130, 60, 190),
	Color3.fromRGB(200, 70, 170),
	Color3.fromRGB(240, 160, 190),
	Color3.fromRGB(140, 90, 50),
}
