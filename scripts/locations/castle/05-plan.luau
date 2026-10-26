-- ================================================================ castle: the plan shared by every part
local ISLAND_R = 216
local WALL_IN, WALL_OUT = 184, 192
local WALL_H = 36 -- 9 blocks
local PIT = { x = -96, z = 64, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = -96, z = 156 }
local BUYER = { x = -64, z = 160 }
local GATE = { x = 0, w = 24 } -- the south gatehouse opening x -12..12
local AVENUE = { -12, 4, 12, WALL_IN } -- x0, z0, x1, z1
local COURT = { x = 56, z = -48, r = 52 }
local KEEP = { x0 = 0, x1 = 112, z0 = -184, z1 = -112 }
local TOWER = { x = 56, z = -150 } -- the White Tower
local CHAPEL = { x0 = 120, x1 = 176, z0 = 20, z1 = 110 }
local STABLES = { x0 = 30, x1 = 176, z0 = 116, z1 = 176 }
local HALL = { x0 = -176, x1 = -120, z0 = -96, z1 = -20 }
local GRAVES = { x0 = -176, x1 = -100, z0 = -176, z1 = -110 }

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inBox(x, z, b, pad)
	pad = pad or 0
	return x >= b.x0 - pad and x <= b.x1 + pad and z >= b.z0 - pad and z <= b.z1 + pad
end
local function inCourt(x, z, pad)
	return (x - COURT.x) ^ 2 + (z - COURT.z) ^ 2 <= (COURT.r + (pad or 0)) ^ 2
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function insideWalls(x, z, pad)
	pad = pad or 0
	return math.abs(x) <= WALL_IN - pad and math.abs(z) <= WALL_IN - pad
end
local function onIsland(x, z)
	local ax, az = math.abs(x), math.abs(z)
	local lim = ISLAND_R + n2(x, z, 4.4, 0.03) * 9
	local r = 40
	if ax > lim or az > lim then
		-- the gate terrace sticks out in the south
		return x >= -40 and x <= 40 and z > 0 and z <= ISLAND_R + 44
	end
	if ax > lim - r and az > lim - r then
		return (ax - (lim - r)) ^ 2 + (az - (lim - r)) ^ 2 <= r * r
	end
	return true
end
-- free bailey ground for gardens and props (not the avenue, the mine area, the court, the keep or districts)
local function freeBailey(x, z, pad)
	pad = pad or 0
	return insideWalls(x, z, 8 + pad)
		and not inRect(x, z, AVENUE, pad)
		and not inPitArea(x, z, 8 + pad)
		and not inCourt(x, z, 10 + pad)
		and not inBox(x, z, KEEP, pad)
		and not inBox(x, z, CHAPEL, pad)
		and not inBox(x, z, STABLES, pad)
		and not inBox(x, z, HALL, pad)
		and not inBox(x, z, GRAVES, pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
end

-- palette: white quartz and black soot
local QUARTZ = Color3.fromRGB(236, 233, 226)
local QUARTZ_SHADE = Color3.fromRGB(205, 202, 196)
local SOOT = Color3.fromRGB(40, 40, 46)
local SLATE = Color3.fromRGB(60, 62, 72)
local DEEP = Color3.fromRGB(86, 88, 96)
local GRASS_DARK = Color3.fromRGB(92, 128, 84)
local BANNER_BLACK = Color3.fromRGB(28, 28, 32)
local WING_WHITE = Color3.fromRGB(235, 235, 235)
