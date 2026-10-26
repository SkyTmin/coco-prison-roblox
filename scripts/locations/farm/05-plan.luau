-- ================================================================ farm: the plan shared by every part
local ISLAND_H = 224
local L1_Y, MOUND_Y = 16, 28
local PIT = { x = 0, z = 24, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 108 }
local BUYER = { x = 32, z = 110 }
local RING_IN = { -72, -48, 72, 96 } -- the pit area (pit + rim)
local RING_OUT = { -92, -68, 92, 116 } -- the outer edge of the ring path
local PATHS = { -- { x0, z0, x1, z1 } dirt paths on L0 besides the ring
	{ -10, 116, 10, 224 }, -- south
	{ -224, 16, -92, 32 }, -- west
	{ 92, 16, 132, 32 }, -- east → the barn yard
}
local STAIRS = {
	main = { x0 = -10, x1 = 10, z0 = -64, z1 = -80 },
	east = { x0 = 80, x1 = 96, z0 = -64, z1 = -80 },
	west = { x0 = -180, x1 = -164, z0 = -64, z1 = -80 },
	mound = { x0 = 88, x1 = 104, z0 = -124, z1 = -132 },
}
local MOUND = { x = 96, z = -168, r = 36 }
local BARN_YARD = { 132, -48, 208, 40 }
local FARMHOUSE = { 120, 64, 196, 132 }
local SILO = { x = 156, z = -150 }
local ARENA = { x = -92, z = -136, r = 52 }
local ENT = { x = -92, z = -200 }
-- crop beds on L0 (x0, z0, x1, z1): each is planted in stripes 5 blocks wide (the fields part)
local FIELDS = {
	{ -208, -60, -100, 8 },
	{ -208, 40, -100, 112 },
	{ -208, 124, -20, 204 },
	{ 20, 124, 112, 204 },
	{ 100, -60, 116, 8 },
	{ 100, 40, 116, 112 },
}

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inBox(x, z, b, pad)
	pad = pad or 0
	return x >= b.x0 - pad and x <= b.x1 + pad and z >= math.min(b.z0, b.z1) - pad and z <= math.max(b.z0, b.z1) + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function onPath(x, z, pad)
	pad = pad or 0
	if inRect(x, z, RING_OUT, pad) and not inRect(x, z, RING_IN, -pad) then
		return true
	end
	for _, p in ipairs(PATHS) do
		if inRect(x, z, p, pad) then
			return true
		end
	end
	return false
end
local function inField(x, z, pad)
	for _, f in ipairs(FIELDS) do
		if inRect(x, z, f, -(pad or 0)) then
			return true
		end
	end
	return false
end
local function onIsland(x, z, pad)
	pad = pad or 0
	local ax, az = math.abs(x), math.abs(z)
	local lim = ISLAND_H - pad + n2(x, z, 4.4, 0.03) * 9
	local r = 48
	if ax > lim or az > lim then
		return false
	end
	if ax > lim - r and az > lim - r then
		return (ax - (lim - r)) ^ 2 + (az - (lim - r)) ^ 2 <= r * r
	end
	return true
end
local function inStairCorridor(x, z)
	for _, s in pairs(STAIRS) do
		if inBox(x, z, s, 8) then
			return true
		end
	end
	return false
end
local function inArena(x, z, pad)
	return (x - ARENA.x) ^ 2 + (z - ARENA.z) ^ 2 <= (ARENA.r + (pad or 0)) ^ 2
end
-- the ground height: L0 0, the hill L1 north of z -80 (ragged except at the stairs and the arena), the mound
local function groundY(x, z)
	local j = 0
	if not inStairCorridor(x, z) and not inArena(x, z, 8) then
		j = math.floor(n2(x, z, 6.6, 0.025) * 2 + 0.5) * 8
	end
	if z >= -80 + j then
		return 0
	end
	if (x - MOUND.x) ^ 2 + (z - MOUND.z) ^ 2 <= MOUND.r * MOUND.r then
		return MOUND_Y
	end
	return L1_Y
end
-- the part that owns a point: "fields", "farmstead" or "grove"
local function zoneOf(x, z)
	if inStairCorridor(x, z) and z >= -88 then
		return "grove"
	end
	if groundY(x, z) == 0 then
		return if x >= 116 then "farmstead" else "fields"
	end
	return if x >= -24 then "farmstead" else "grove"
end
-- free ground for props: on the island, off the paths, the pit, the stairs, the arena and the arrival
local function freeGround(x, z, pad)
	pad = pad or 0
	return onIsland(x, z, 10 + pad)
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and not inStairCorridor(x, z)
		and not inArena(x, z, 6 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: a warm golden summer afternoon
local GRASS = Color3.fromRGB(140, 196, 90)
local PATH_DIRT = Color3.fromRGB(176, 140, 100)
local FARMLAND = Color3.fromRGB(110, 78, 54)
local WHEAT = Color3.fromRGB(230, 200, 100)
local BARN_RED = Color3.fromRGB(176, 52, 44)
local FENCE_WOOD = Color3.fromRGB(150, 110, 70)
local PUMPKIN = Color3.fromRGB(236, 140, 40)
local STONE = Color3.fromRGB(150, 150, 150)
