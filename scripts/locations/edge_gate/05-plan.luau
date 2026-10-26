-- ================================================================ edge_gate: the plan shared by every part
local MAIN = { x = 0, z = 74, rx = 160, rz = 150 } -- an ellipse
local ARENA_ISLE = { x = 0, z = -170, r = 78, y = 16 } -- room for the gate and the rim towers
local WEST = { x = -228, z = 40, r = 56 }
local EAST = { x = 210, z = -28, r = 56 }
local PIT = { x = 0, z = 72, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 166 }
local BUYER = { x = 34, z = 168 }
local ARENA = { x = 0, z = -170, r = 52, y = 16 }
local GATE = { x0 = -28, x1 = 28, z0 = -240, z1 = -226 }
local GRAND_STAIR = { x0 = -12, x1 = 12, z0 = -76, z1 = -104 }
local RING_IN = { -72, 0, 72, 144 } -- the pit area (pit + rim)
local RING_OUT = { -92, -20, 92, 188 }
local PATHS = { -- { x0, z0, x1, z1 } end stone brick paths on the main island
	{ -12, -76, 12, -20 }, -- north → the grand stair
	{ -136, 30, -92, 46 }, -- west → the west bridge
	{ 92, -36, 104, -20 }, -- east → the east bridge
}
local BRIDGES = { -- { x0, z0, x1, z1 } railless purpur bridges at y 0 (the main part builds them)
	{ -180, 30, -124, 46 }, -- main ↔ west island (long enough to land on both ragged edges)
	{ 84, -36, 170, -20 }, -- main ↔ east island
}

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
local function inDisc(x, z, c, pad)
	local r = c.r + n2(x, z, 4.4, 0.04) * 9 - (pad or 0)
	return (x - c.x) ^ 2 + (z - c.z) ^ 2 <= r * r
end
-- which island a point is on: "main", "arena", "west", "east" or nil (the void)
local function isleOf(x, z, pad)
	-- the grand stair crosses open void: the main island ends straight at z -80 and the arena island starts at z -104
	if math.abs(x) <= 16 then
		if z < -80 and z > -104 then
			return nil
		end
		if z >= -80 and z <= -60 then
			return "main"
		end
		if z <= -104 and z >= -120 then
			return "arena"
		end
	end
	local j = n2(x, z, 4.4, 0.04) * 9 - (pad or 0)
	if ((x - MAIN.x) / (MAIN.rx + j)) ^ 2 + ((z - MAIN.z) / (MAIN.rz + j)) ^ 2 <= 1 then
		return "main"
	end
	if inDisc(x, z, ARENA_ISLE, pad) then
		return "arena"
	end
	if inDisc(x, z, WEST, pad) then
		return "west"
	end
	if inDisc(x, z, EAST, pad) then
		return "east"
	end
	return nil
end
local function groundY(x, z)
	local i = isleOf(x, z)
	if i == nil then
		return nil
	end
	return if i == "arena" then ARENA_ISLE.y else 0
end
-- the part that owns a point: "gate", "main" or "isles"
local function zoneOf(x, z)
	if z < -72 and math.abs(x) < 120 then
		return "gate"
	end
	local i = isleOf(x, z)
	if i == "west" or i == "east" then
		return "isles"
	end
	if i == "main" then
		return "main"
	end
	for _, b in ipairs(BRIDGES) do
		if inRect(x, z, b) then
			return "main"
		end
	end
	return "isles"
end
-- free ground for props: on an island, off the paths, the pit, the arena, the stair and the arrival
local function freeGround(x, z, pad)
	pad = pad or 0
	return isleOf(x, z, 10 + pad) ~= nil
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and not inArena(x, z, 6 + pad)
		and not inRect(x, z, { GRAND_STAIR.x0, GRAND_STAIR.z1, GRAND_STAIR.x1, GRAND_STAIR.z0 }, 8 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: the End at night
local END_STONE = Color3.fromRGB(232, 232, 196)
local PURPUR = Color3.fromRGB(176, 130, 176)
local MAGENTA = Color3.fromRGB(200, 60, 190)
local OBSIDIAN = Color3.fromRGB(40, 30, 56)
local CRYSTAL = Color3.fromRGB(240, 90, 220)
local VOID_VIOLET = Color3.fromRGB(70, 20, 110)
local CHORUS = Color3.fromRGB(140, 90, 150)
