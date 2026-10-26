-- ================================================================ paradise: the plan shared by every part
local ISLAND = { x = 0, z = 0, r = 236 }
local ROSE = { x = 0, z = -84, river = 120, bank = 108, crown = 28, step = 4 }
local TIERS = { 108, 92, 76, 60, 44, 28 } -- tier k (1..6) lies inside TIERS[k] at y 4k; the crown (k 6) is the SUMMIT
local RIVER_BED, RIVER_TOP, GLASS_TOP = -4, -0.8, 0 -- one block deep, covered by yellow glass at y 0 (walkable)
local RAYS = 12 -- rays of steps from the river to the crown, ray 0 points south (to the pit)
local PIT = { x = 0, z = 124, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 214 }
local BUYER = { x = -36, z = 216 }
local SUMMIT = { x = 0, z = -84, y = 24 }
local ISLES = {
	{ name = "west", x = -296, z = 0, r = 40 },
	{ name = "east", x = 296, z = 0, r = 40 },
	{ name = "northWest", x = -226, z = -176, r = 32 },
	{ name = "northEast", x = 226, z = -176, r = 32 },
	{ name = "southWest", x = -226, z = 176, r = 32 },
	{ name = "southEast", x = 226, z = 176, r = 32 },
}
local BRIDGES =
	{ -- { x0, z0, x1, z1 } decks at y 0 (the sky part measures the real gap from the cells)
		{ -264, -8, -228, 8 },
		{ 228, -8, 264, 8 },
		{ -200, -184, -150, -168 },
		{ 150, -184, 200, -168 },
		{ -200, 168, -150, 184 },
		{ 150, 168, 200, 184 },
	}
local WALKS = { -- { x0, z0, x1, z1 } main walkways at y 0 kept clear of props
	{ -10, 196, 10, 236 }, -- the south axis from the pit to the arrival and the south edge
	{ -10, 36, 10, 52 }, -- from the pit's north side to the river and the south ray
	{ -236, -8, -84, 8 }, -- west to the bridge W
	{ 84, -8, 236, 8 },
	{ -160, -184, -76, -168 }, -- north-west to the bridge NW (from the river)
	{ 76, -184, 160, -168 },
	{ -160, 168, -72, 184 }, -- south-west to the bridge SW (from the pit area)
	{ 72, 168, 160, 184 },
}

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function roseDist(x, z)
	return math.sqrt((x - ROSE.x) ^ 2 + (z - ROSE.z) ^ 2)
end
-- the ray a point is nearest to (0..RAYS-1) and its sideways distance from that ray's centre line
local function rayOf(x, z)
	local a = math.atan2(x - ROSE.x, z - ROSE.z) -- 0 = south, +π/2 = east
	local step = 2 * math.pi / RAYS
	local k = math.floor(a / step + 0.5)
	local off = (a - k * step) * roseDist(x, z)
	return k % RAYS, math.abs(off)
end
-- which island a point is on: "main", an islet's name or nil (the sky); noise reads |x| (mirror-symmetric)
local function isleOf(x, z, pad)
	local r = ISLAND.r + n2(math.abs(x), z, 4.4, 0.04) * 9 - (pad or 0)
	if (x - ISLAND.x) ^ 2 + (z - ISLAND.z) ^ 2 <= r * r then
		return "main"
	end
	for _, s in ipairs(ISLES) do
		local rr = s.r + n2(math.abs(x), z, 5.1, 0.05) * 6 - (pad or 0)
		if (x - s.x) ^ 2 + (z - s.z) ^ 2 <= rr * rr then
			return s.name
		end
	end
	return nil
end
local function onRiver(x, z, pad)
	pad = pad or 0
	local d = roseDist(x, z)
	return d >= ROSE.bank - pad and d <= ROSE.river + pad
end
-- the tier of a point: 0 outside the rose (and on the river), 1..6 inside
local function tierOf(x, z)
	local d = roseDist(x, z)
	local k = 0
	for i, r in ipairs(TIERS) do
		if d < r then
			k = i
		end
	end
	return k
end
-- the ground height: the tiers y 4k, the river bed y -4 (under the glass at y 0), the plaza y 0
local function groundY(x, z)
	if not isleOf(x, z) then
		return nil
	end
	if onRiver(x, z) then
		return RIVER_BED
	end
	return tierOf(x, z) * ROSE.step
end
local function onPath(x, z, pad)
	for _, w in ipairs(WALKS) do
		if inRect(x, z, w, pad) then
			return true
		end
	end
	return false
end
-- the part that owns a point: "rose", "plaza" or "sky"
local function zoneOf(x, z)
	if isleOf(x, z) ~= "main" then
		return "sky"
	end
	return if roseDist(x, z) < ROSE.river + 4 then "rose" else "plaza"
end
-- free ground for props: on an island, off the walks, the river, the pit, the arrival and the buyer
local function freeGround(x, z, pad)
	pad = pad or 0
	return isleOf(x, z, 10 + pad) ~= nil
		and not onPath(x, z, 2 + pad)
		and not onRiver(x, z, 4 + pad)
		and not inPitArea(x, z, 4 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: almost monochrome white, gold accents, the scarlet heart (tints over coloured textures stay light)
local WHITE = Color3.fromRGB(250, 250, 248) -- over px_smooth_stone (white concrete)
local QUARTZ = Color3.fromRGB(246, 243, 236) -- over px_white_stone_bricks / px_smooth_stone
local CALCITE = Color3.fromRGB(232, 234, 230)
local SNOW = Color3.fromRGB(244, 248, 255)
local GOLD = Color3.fromRGB(255, 236, 170) -- a tint over px_gold_block (keep it light)
local GOLD_GLASS = Color3.fromRGB(255, 214, 90) -- the yellow glass over the golden river
local GOLD_WATER = Color3.fromRGB(240, 196, 70)
local SCARLET = Color3.fromRGB(205, 40, 40) -- red flowers, the heart
local PETAL = Color3.fromRGB(250, 190, 210)
local LEAF = Color3.fromRGB(170, 205, 150) -- a tint over px_hedge (vines, bushes)
local BIRCH = Color3.fromRGB(250, 250, 246) -- a light tint over px_birch_log
local WATER = Color3.fromRGB(110, 170, 240)
local LIGHT = Color3.fromRGB(255, 244, 214)
local CLOUD = Color3.fromRGB(252, 252, 255)
