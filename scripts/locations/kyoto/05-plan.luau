-- ================================================================ kyoto: the plan shared by every part
local ISLAND_R = 232
local L1_Y, L2_Y = 16, 32
local PIT = { x = -24, z = 88, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = -24, z = 182 }
local BUYER = { x = 8, z = 186 }
local SQUARE = { -120, -8, 72, 216 } -- x0, z0, x1, z1
local MAIN_STAIR = { x0 = 24, x1 = 44, zA0 = 12, zA1 = -8, zB0 = -40, zB1 = -72 }
local WEST_STAIR = { x0 = -180, x1 = -164, z0 = 24, z1 = -8 }
local ARENA_STAIR = { x0 = -96, x1 = -80, z0 = -40, z1 = -72 }
local TEMPLE = { x0 = 64, x1 = 176, z0 = -124, z1 = -76 }
local STAGE = { x0 = 72, x1 = 176, z0 = -72, z1 = -16, y = L2_Y }
local POND = { x = 124, z = 24, r = 36, bed = -8 }
local PAGODA = { x = 110, z = -160 }
local ARENA = { x = -88, z = -128, r = 56 }

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function inPond(x, z, pad)
	return (x - POND.x) ^ 2 + (z - POND.z) ^ 2 <= (POND.r + (pad or 0)) ^ 2
end
local function inArena(x, z, pad)
	return (x - ARENA.x) ^ 2 + (z - ARENA.z) ^ 2 <= (ARENA.r + (pad or 0)) ^ 2
end
local function onIsland(x, z, pad)
	return math.sqrt(x * x + z * z) <= ISLAND_R - (pad or 0) + n2(x, z, 4.4, 0.03) * 10
end
-- stair corridors keep the terrace edges straight (the flights land exactly)
local function inStairCorridor(x, z)
	return (x >= MAIN_STAIR.x0 - 8 and x <= MAIN_STAIR.x1 + 8 and z >= -80 and z <= 16)
		or (x >= WEST_STAIR.x0 - 8 and x <= WEST_STAIR.x1 + 8 and z >= -16 and z <= 32)
		or (x >= ARENA_STAIR.x0 - 8 and x <= ARENA_STAIR.x1 + 8 and z >= -80 and z <= -32)
end
-- the terrace of a point: 0, 1 or 2 (the area under the stage, east of x 56, stays on L0)
local function terrace(x, z)
	local j = 0
	if not inStairCorridor(x, z) then
		j = math.floor(n2(x, z, 6.6, 0.025) * 2 + 0.5) * 8
	end
	if z < -72 + j then
		return 2
	end
	if z < -8 + j and x < 56 then
		return 1
	end
	return 0
end
local function groundY(x, z)
	local t = terrace(x, z)
	if t == 0 and inPond(x, z) then
		return POND.bed
	end
	return if t == 2 then L2_Y elseif t == 1 then L1_Y else 0
end
-- the zone that owns a point (who builds there): "temple", "hill" or "town"
local function zoneOf(x, z)
	if (x >= 56 and z <= 64) or (x >= 20 and x <= 48 and z >= -76 and z <= 14) then
		return "temple"
	end
	if x < 56 and z < -8 then
		return "hill"
	end
	return "town"
end
-- free ground for trees and props in a zone: on the island, off the square paths, the pit, the stairs and the arrival
local function freeGround(x, z, pad)
	pad = pad or 0
	return onIsland(x, z, 10 + pad)
		and not inPitArea(x, z, 6 + pad)
		and not inStairCorridor(x, z)
		and not inPond(x, z, 4 + pad)
		and not inArena(x, z, 6 + pad)
		and not (x >= STAGE.x0 - pad and x <= STAGE.x1 + pad and z >= STAGE.z0 - pad and z <= STAGE.z1 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: spring Kyoto
local SAKURA = Color3.fromRGB(246, 170, 205)
local SAKURA_DEEP = Color3.fromRGB(226, 120, 170)
local TORII_RED = Color3.fromRGB(200, 40, 34)
local DARK_WOOD = Color3.fromRGB(70, 50, 40)
local ROOF_DARK = Color3.fromRGB(52, 50, 56)
local STONE = Color3.fromRGB(160, 158, 154)
local GRASS = Color3.fromRGB(150, 196, 110)
local WATER_C = Color3.fromRGB(80, 160, 200)
local PAPER = Color3.fromRGB(245, 236, 214)
