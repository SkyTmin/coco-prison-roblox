-- ================================================================ inside_out: the plan shared by every part
local MAIN = { rx = 220, rz = 200 }
local PIT = { x = 0, z = -8, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 84 }
local BUYER = { x = 32, z = 84 }
local SQUARE = { -96, -104, 96, 100 } -- x0, z0, x1, z1
local RING = { -116, -124, 116, 120 } -- the outer edge of the ring road (the square sits inside it)
local MANSION = { x = 0, z = -330, r = 68, y = 48 }
local ARENA = { x = 0, z = 320, r = 56, islandR = 76, y = -16 }
local ISLETS = { { x = -120, z = 262, r = 24, y = -8 }, { x = 120, z = 262, r = 24, y = -8 } }
-- street segments { ax, az, bx, bz, half-width } (asphalt; the ring road is RING minus SQUARE)
local STREETS = {
	{ -220, -8, -116, -8, 10 }, -- west
	{ 116, -8, 220, -8, 10 }, -- east
	{ 0, -200, 0, -124, 10 }, -- north (→ the sky road)
	{ 0, 120, 0, 200, 10 }, -- south (→ the arena bridge)
	{ -116, 120, -120, 190, 10 }, -- south-west (→ the west islet)
	{ 116, 120, 120, 190, 10 }, -- south-east (→ the east islet)
}
-- house districts (x0, z0, x1, z1): lots front the streets; keep 1 block off every street and the island edge
local DISTRICTS = {
	NW = { -200, -168, -128, -26 },
	SW = { -200, 10, -132, 150 },
	NE = { 128, -168, 200, -26 }, -- the church
	SE = { 132, 10, 200, 150 },
	NNW = { -104, -180, -16, -132 }, -- the alphabet wall
	NNE = { 16, -180, 104, -132 },
	SSW = { -104, 128, -16, 186 },
	SSE = { 16, 128, 104, 186 },
}

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function onStreet(x, z, pad)
	pad = pad or 0
	for _, s in ipairs(STREETS) do
		if segDist(x, z, s[1], s[2], s[3], s[4]) <= s[5] + pad then
			return true
		end
	end
	return inRect(x, z, RING, pad) and not inRect(x, z, SQUARE, -pad)
end
-- the main island's outline (a rounded square with a ragged edge); pad > 0 keeps away from the rim
local function onMain(x, z, pad)
	pad = pad or 0
	local jag = n2(x, z, 5.3, 0.035) * 0.08 + n2(x, z, 9.1, 0.12) * 0.03
	local v = (math.abs(x) / (MAIN.rx - pad)) ^ 4 + (math.abs(z) / (MAIN.rz - pad)) ^ 4
	return v <= 1 + jag
end
local function inDisc(x, z, c, r)
	return (x - c.x) ^ 2 + (z - c.z) ^ 2 <= r * r
end
-- the ground height of a cell (nil = void): the main island at 0, the mansion island, the arena island, the islets
local function groundY(x, z)
	if onMain(x, z) then
		return 0
	end
	local jag = n2(x, z, 2.2, 0.08) * 8
	if inDisc(x, z, MANSION, MANSION.r + jag) then
		return MANSION.y
	end
	if inDisc(x, z, ARENA, ARENA.islandR + jag * 0.5) then
		return ARENA.y
	end
	for _, s in ipairs(ISLETS) do
		if inDisc(x, z, s, s.r + jag * 0.5) then
			return s.y
		end
	end
	return nil
end
-- free town ground for props: on the main island, off the streets, the square, the pit and the path ends
local function freeTown(x, z, pad)
	pad = pad or 0
	return onMain(x, z, 8 + pad)
		and not onStreet(x, z, 4 + pad)
		and not inRect(x, z, SQUARE, pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
end

-- palette: the dead suburb under a red sky
-- (Studio 26.10: the square and the streets read as black under the red dusk — the cobbles and the asphalt lighter)
local ASPHALT = Color3.fromRGB(84, 82, 88)
local LINE_YELLOW = Color3.fromRGB(232, 190, 40)
local COBBLE = Color3.fromRGB(196, 192, 192)
local DEAD_GRASS = Color3.fromRGB(128, 104, 88)
local VINE_RED = Color3.fromRGB(150, 24, 30)
local VINE_DARK = Color3.fromRGB(96, 14, 22)
local ROCK_RED = Color3.fromRGB(120, 92, 92)
local ASH = Color3.fromRGB(214, 206, 204)
local GLOW_RED = Color3.fromRGB(255, 60, 40)
