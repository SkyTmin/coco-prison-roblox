-- ================================================================ eden: the plan shared by every part
local HALF = 220 -- the rounded square island
local HILL = { x = 0, z = -60, bank = 82, river = 98, l1 = 72, l2 = 40, trunk = 12 }
local RIVER_BED, RIVER_TOP = -8, -1.5
local RIVERS = { -- { x0, z0, x1, z1 } straight rivers from the ring to the edges
	{ -240, -68, -90, -52 }, -- WEST
	{ 90, -68, 240, -52 }, -- EAST
	{ -8, -240, 8, -150 }, -- NORTH
}
local PIT = { x = -40, z = 128, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 56, z = 128 }
local BUYER = { x = 66, z = 150 }
local PATHS = { -- { x0, z0, x1, z1 } at y 0
	{ 36, 40, 56, 128 }, -- EAST: the arrival → north
	{ -10, 40, 56, 56 }, -- CROSS: under the ring to the south bridge
}
local BRIDGE_S = { -10, 18, 10, 44 } -- the main bridge over the ring (the hill part)
local STAIRS = { -- the hill stairs (the hill part): { x0, z0, x1, z1, y0 } running north, rise 8
	{ -10, 4, 10, 22, 0 }, -- S1 onto L1 (edge z ≈ 12)
	{ -10, -28, 10, -12, 8 }, -- S2 onto the summit (edge z ≈ -20)
}

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function hillDist(x, z)
	return math.sqrt((x - HILL.x) ^ 2 + (z - HILL.z) ^ 2)
end
local function onIsland(x, z, pad)
	local h = HALF + n2(x, z, 4.4, 0.04) * 9 - (pad or 0)
	return (math.abs(x) / h) ^ 4 + (math.abs(z) / h) ^ 4 <= 1
end
local function onRiver(x, z, pad)
	pad = pad or 0
	local d = hillDist(x, z)
	if d >= HILL.bank - pad and d <= HILL.river + pad then
		return true
	end
	for _, r in ipairs(RIVERS) do
		if inRect(x, z, r, pad) and hillDist(x, z) > HILL.bank then
			return true
		end
	end
	return false
end
local function onPath(x, z, pad)
	for _, p in ipairs(PATHS) do
		if inRect(x, z, p, pad) then
			return true
		end
	end
	if inRect(x, z, BRIDGE_S, pad) then
		return true
	end
	for _, s in ipairs(STAIRS) do
		if inRect(x, z, s, pad) then
			return true
		end
	end
	return false
end
-- the ground height: the hill steps (y 8, 16), the river beds (y -8), the garden y 0
local function groundY(x, z)
	if not onIsland(x, z) then
		return nil
	end
	if onRiver(x, z) then
		return RIVER_BED
	end
	local d = hillDist(x, z)
	if d < HILL.l2 then
		return 16
	end
	if d < HILL.l1 then
		return 8
	end
	return 0
end
-- the part that owns a point: "hill", "south" or "north"
local function zoneOf(x, z)
	if hillDist(x, z) < 100 then
		return "hill"
	end
	return if z > -52 then "south" else "north"
end
-- free ground for props: on the island, off the paths, the rivers, the pit, the arrival and the buyer
local function freeGround(x, z, pad)
	pad = pad or 0
	return onIsland(x, z, 10 + pad)
		and not onPath(x, z, 2 + pad)
		and not onRiver(x, z, 4 + pad)
		and not inPitArea(x, z, 4 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: a radiant spring noon (tints over already coloured textures stay light)
local GRASS = Color3.fromRGB(150, 210, 100)
local GRASS_DEEP = Color3.fromRGB(125, 190, 90)
local MOSS = Color3.fromRGB(140, 180, 90)
local PATH = Color3.fromRGB(196, 160, 120) -- coarse dirt with petals
local MUD = Color3.fromRGB(120, 96, 76) -- the river banks
local WATER = Color3.fromRGB(80, 150, 230)
local LEAF = Color3.fromRGB(180, 220, 150) -- a tint over px_hedge (already dark green)
local BLOSSOM = Color3.fromRGB(255, 215, 235) -- a tint over px_cherry_leaves (already pink)
local PINK_WOOL = Color3.fromRGB(244, 170, 200)
local APPLE = Color3.fromRGB(200, 30, 30)
local ROOF_GREEN = Color3.fromRGB(60, 120, 90)
local MUSHROOM = Color3.fromRGB(200, 150, 120) -- giant brown mushroom caps
