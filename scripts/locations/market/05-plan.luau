-- ================================================================ market: the plan shared by every part
local ISLAND_R = 208 -- half size of the island square (rounded corners)
local WALL_IN, WALL_OUT = 184, 192 -- the wall ring, |x| or |z|
local PIT = { x = -40, z = 16, size = 32, depth = 12 } -- locations.json market.mine (decisions: 32×12×32)
local PIT_HALF = PIT.size * B / 2 -- 64: the hole is x -104..24, z -48..80
local PLAZA = { x0 = -136, x1 = 56, z0 = -80, z1 = 112 }
local SPAWN = { x = -40, z = 108 }
local BUYER = { x = -12, z = 110 }
local HERO = { x = 110, z = -110, r = 56 } -- the collapsed fountain square on top, the crypt under it
local CRYPT = { x = 110, z = -110, r = 56, floor = -48, vault = -8 }
local SINK = { x = 92, z = -96, r = 18 } -- the hole in the hero plaza, over the crypt's north-west part
local CAVE_MOUTH = { x = 208, y = -48, z = -110, w = 16, h = 20 } -- the cliff cave on the east side
local HATCH = { x = 40, z = -66 } -- the smugglers' hatch by the plaza (tunnel down to the crypt's west side)
local GATES = {
	south = { x = -40, z = WALL_IN, w = 20 }, -- the main gate on the south avenue → the dock
	north = { x = -40, z = -WALL_IN, w = 20 },
	west = { x = -WALL_IN, z = 16, w = 20 },
	east = { x = WALL_IN, z = 16, w = 12 }, -- the postern to the cliff stairs
}
-- streets (rectangles x0, z0, x1, z1), 5 blocks wide
local STREETS = {
	{ name = "SouthAvenue", -50, 112, -30, WALL_OUT },
	{ name = "NorthStreet", -50, -WALL_OUT, -30, -80 },
	{ name = "WestStreet", -WALL_OUT, 6, -136, 26 },
	{ name = "EastStreet", 56, 6, WALL_OUT, 26 },
	{ name = "CrossStreet", -WALL_IN, -120, 54, -100 },
}
local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inStreet(x, z, pad)
	for _, s in ipairs(STREETS) do
		if inRect(x, z, s, pad) then
			return true
		end
	end
	return false
end
local function inPlaza(x, z, pad)
	pad = pad or 0
	return x >= PLAZA.x0 - pad and x <= PLAZA.x1 + pad and z >= PLAZA.z0 - pad and z <= PLAZA.z1 + pad
end
local function inHero(x, z, pad)
	return (x - HERO.x) ^ 2 + (z - HERO.z) ^ 2 <= (HERO.r + (pad or 0)) ^ 2
end
local function insideWalls(x, z, pad)
	pad = pad or 0
	return math.abs(x) <= WALL_IN - pad and math.abs(z) <= WALL_IN - pad
end
-- where stall blocks may stand: inside the walls, off the streets, the plaza and the hero plaza
local function stallZone(x, z)
	return insideWalls(x, z, 4) and not inStreet(x, z, 2) and not inPlaza(x, z, 2) and not inHero(x, z, 6)
end
-- the island outline: a square with rounded corners and a ragged edge outside the wall
local function onIsland(x, z)
	local ax, az = math.abs(x), math.abs(z)
	local r = 44
	local ragged = n2(x, z, 7.1, 0.03) * 10
	local lim = ISLAND_R + ragged
	if ax > lim or az > lim then
		return false
	end
	if ax > lim - r and az > lim - r then
		return (ax - (lim - r)) ^ 2 + (az - (lim - r)) ^ 2 <= r * r
	end
	return true
end

-- palette (tints over our textures)
local STONE_T = Color3.fromRGB(150, 150, 150)
local COBBLE_T = Color3.fromRGB(165, 160, 152)
local PATH_T = Color3.fromRGB(190, 182, 168)
local WOOL_RED = Color3.fromRGB(196, 46, 40)
local WOOL_YELLOW = Color3.fromRGB(232, 196, 52)
local WOOL_LIME = Color3.fromRGB(120, 196, 52)
local WOOL_WHITE = Color3.fromRGB(240, 236, 228)
local BANNER_RED = Color3.fromRGB(170, 40, 36)
local BANNER_YELLOW = Color3.fromRGB(226, 182, 40)
local CRYPT_STONE = Color3.fromRGB(70, 74, 82)
