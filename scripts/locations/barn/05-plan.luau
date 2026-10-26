-- ================================================================ barn: the plan shared by every part
local ISLAND_R = 216
local PIT = { x = 0, z = 96, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 190 }
local BUYER = { x = 36, z = 192 }
local BARN = { x0 = -52, x1 = 52, z0 = -72, z1 = 4, tree = { x = 16, z = -32 } }
local ARENA = { x = 0, z = -140, r = 52 }
local GUARDIAN = { x = 0, z = -204 }
local RING_IN = { -72, 24, 72, 168 } -- the pit area (pit + rim)
local RING_OUT = { -92, 4, 92, 188 }
local PATHS = { -- { x0, z0, x1, z1 }
	{ -96, -84, -72, 4 }, -- round the barn, west
	{ 72, -84, 96, 4 }, -- round the barn, east
	{ -216, -24, -92, -8 }, -- west
	{ 92, -24, 216, -8 }, -- east
	{ -10, 188, 10, 216 }, -- the south stair
}
local ZONE_BARN = { -84, -80, 84, 4 }

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
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
local function inArena(x, z, pad)
	return (x - ARENA.x) ^ 2 + (z - ARENA.z) ^ 2 <= (ARENA.r + (pad or 0)) ^ 2
end
local function inBarn(x, z, pad)
	pad = pad or 0
	return x >= BARN.x0 - pad and x <= BARN.x1 + pad and z >= BARN.z0 - pad and z <= BARN.z1 + pad
end
local function onIsland(x, z, pad)
	-- a hexagon-ish outline: the radius swells toward six lobes and is ragged
	local a = math.atan2(z, x)
	local r = ISLAND_R + math.cos(a * 6 + 0.4) * 8 + n2(x, z, 4.4, 0.03) * 10 - (pad or 0)
	return x * x + z * z <= r * r
end
-- the part that owns a point: "barn", "yard" or "outskirts"
local function zoneOf(x, z)
	if inRect(x, z, ZONE_BARN) then
		return "barn"
	end
	if z < -80 then
		return "yard"
	end
	return "outskirts"
end
-- free ground for props: on the island, off the paths, the pit, the barn, the arena and the arrival
local function freeGround(x, z, pad)
	pad = pad or 0
	return onIsland(x, z, 10 + pad)
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and not inBarn(x, z, 4 + pad)
		and not inArena(x, z, 6 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: autumn dusk, orange pumpkin light
local WEEDS = Color3.fromRGB(150, 140, 80)
local PODZOL = Color3.fromRGB(120, 88, 60)
local PATH_DIRT = Color3.fromRGB(140, 104, 72)
local BARN_RED = Color3.fromRGB(150, 52, 44)
local OLD_WOOD = Color3.fromRGB(110, 86, 64)
local RUST = Color3.fromRGB(170, 90, 50)
local AUTUMN = Color3.fromRGB(214, 110, 40)
local AUTUMN_DEEP = Color3.fromRGB(170, 70, 30)
local PUMPKIN = Color3.fromRGB(236, 140, 40)
local CANDLE = Color3.fromRGB(255, 200, 120)
