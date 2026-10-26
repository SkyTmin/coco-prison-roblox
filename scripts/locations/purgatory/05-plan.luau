-- ================================================================ purgatory: the plan shared by every part
local ISLAND = { x = 0, z = 10, r = 220 }
local PEAK = { x = 0, z = -80 }
local RINGS = { 200, 168, 138, 110, 84, 50 } -- terrace edges round PEAK, outside → in; level L = rings inside
local STAIR_RINGS = { 138, 110, 84, 50 } -- the rings with fixed stairs (the outer two: the rim part places its own)
local STEP_Y = 8 -- each terrace is 2 blocks above the one below
local SUMMIT_Y = 6 * STEP_Y -- 48: the summit plaza (d < 50)
local BAY = { -92, -10, 92, 260 } -- { x0, z0, x1, z1 } cut down to y 0
local PIT = { x = 0, z = 110, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 204 }
local BUYER = { x = -34, z = 200 }
local ZIGZAG = { -52, -10, 52, 34 } -- the zigzag stair from the bay floor (y 0) to the L5 terrace (y 40)
local MAIN_UP = { -10, -34, 10, -10 } -- one flight on from y 40 to the summit (y 48; its edge is at z -30)
local STAIR_W = 16
local CELL = { x0 = -232, z0 = -224, size = 8 } -- the core's island grid

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function peakDist(x, z)
	return math.sqrt((x - PEAK.x) ^ 2 + (z - PEAK.z) ^ 2)
end
local function onIsland(x, z, pad)
	local r = ISLAND.r + n2(x, z, 4.4, 0.04) * 9 - (pad or 0)
	return (x - ISLAND.x) ^ 2 + (z - ISLAND.z) ^ 2 <= r * r
end
local function inBay(x, z, pad)
	return inRect(x, z, BAY, pad)
end
-- the terrace level of a point (0..6), exact (not snapped to the cells)
local function levelAt(x, z)
	if inBay(x, z) then
		return 0
	end
	local d, l = peakDist(x, z), 0
	for _, r in ipairs(RINGS) do
		if d < r then
			l += 1
		end
	end
	return l
end
local function groundY(x, z)
	if not onIsland(x, z) then
		return nil
	end
	return levelAt(x, z) * STEP_Y
end
-- the ground the core actually built at a point: the level of the 8-stud cell that contains it
local function cellY(x, z)
	local s = CELL.size
	local cx = CELL.x0 + math.floor((x - CELL.x0) / s) * s + s / 2
	local cz = CELL.z0 + math.floor((z - CELL.z0) / s) * s + s / 2
	return groundY(cx, cz)
end
-- the fixed ring stairs: 16 wide at the east, west and north crossing of the STAIR_RINGS that lie on the island
-- (from 12 studs outside the edge to 4 inside: the landing below, the flight, the top)
local function onRingStair(x, z, pad)
	pad = pad or 0
	local h = STAIR_W / 2 + pad
	for _, r in ipairs(STAIR_RINGS) do
		local lo, hi = r - 4 - pad, r + 12 + pad -- the cells round the edge and the landing below
		if
			math.abs(z - PEAK.z) <= h
			and ((x - PEAK.x >= lo and x - PEAK.x <= hi) or (PEAK.x - x >= lo and PEAK.x - x <= hi))
		then
			return true
		end
		if math.abs(x - PEAK.x) <= h and PEAK.z - z >= lo and PEAK.z - z <= hi then
			return true
		end
	end
	return false
end
local function onPath(x, z, pad)
	return inRect(x, z, ZIGZAG, pad) or inRect(x, z, MAIN_UP, pad) or onRingStair(x, z, pad)
end
-- the part that owns a point: "bay", "mount" or "rim"
local function zoneOf(x, z)
	if inBay(x, z) or inRect(x, z, MAIN_UP) then
		return "bay"
	end
	return if peakDist(x, z) < 138 then "mount" else "rim"
end
-- free ground for props: on the island, off the stairs, the pit, the arrival and the buyer, not on a terrace edge
local function freeGround(x, z, pad)
	pad = pad or 0
	if not onIsland(x, z, 10 + pad) or onPath(x, z, 2 + pad) or inPitArea(x, z, 4 + pad) then
		return false
	end
	if math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) <= 20 + pad then
		return false
	end
	if math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) <= 14 + pad then
		return false
	end
	-- the same terrace all round the footprint (not hanging over an edge)
	local y = cellY(x, z)
	local e = 4 + pad
	return cellY(x - e, z) == y
		and cellY(x + e, z) == y
		and cellY(x, z - e) == y
		and cellY(x, z + e) == y
end

-- palette: a hazy sunset (tints over already coloured textures stay light)
local RED_SAND = Color3.fromRGB(226, 150, 100) -- the foot
local SAND = Color3.fromRGB(240, 222, 170)
local SAND_PALE = Color3.fromRGB(250, 240, 210) -- the top
local BANNER_RED = Color3.fromRGB(170, 36, 40)
local GOLD = Color3.fromRGB(236, 196, 80)
local SOUL = Color3.fromRGB(235, 245, 255) -- translucent soul figures (Transparency ≈ 0.5)
local SOUL_FIRE = Color3.fromRGB(90, 220, 255)
local FIRE = Color3.fromRGB(255, 150, 50)
local CYPRESS = Color3.fromRGB(170, 200, 150) -- a tint over px_hedge (already dark green)
local DEAD_BUSH = Color3.fromRGB(200, 120, 50)
local WATER = Color3.fromRGB(90, 140, 220)
