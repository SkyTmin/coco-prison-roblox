-- ================================================================ cherubim: the plan shared by every part
local ISLAND = { x = 0, z = 0, r = 184 }
local PIT = { x = 0, z = 60, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 152 }
local BUYER = { x = 34, z = 156 }
local ROTUNDA = { x = 0, z = -112, r = 44, floor = 8, gallery = 48, top = 120 }
local STEPS = { -20, -68, 20, -56 } -- the rotunda's south steps (y 0 → 8)
local SUMMIT = { x = 0, z = -112, y = 48 } -- the gallery under the dome
local WEST_ISLE = { x = -250, z = -20, r = 36 }
local EAST_ISLE = { x = 250, z = -20, r = 36 }
local BRIDGES = { { -218, -28, -178, -12 }, { 178, -28, 218, -12 } } -- { x0, z0, x1, z1 } decks at y 0 (the sky part)
local WALKS = { -- { x0, z0, x1, z1 } main walkways kept clear of props
	{ -12, -56, 12, -4 }, -- from the pit's north side to the rotunda steps
	{ -184, -28, -72, -12 }, -- west to the bridge
	{ 72, -28, 184, -12 }, -- east to the bridge
}
local ZONE_ROTUNDA = { -100, -200, 100, -56 }

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function inDisc(x, z, c, pad, j)
	local r = c.r + n2(x, z, 4.4, 0.04) * (j or 6) - (pad or 0)
	return (x - c.x) ^ 2 + (z - c.z) ^ 2 <= r * r
end
-- which island a point is on: "main", "west", "east" or nil (the sky)
local function isleOf(x, z, pad)
	if inDisc(x, z, ISLAND, pad, 9) then
		return "main"
	end
	if inDisc(x, z, WEST_ISLE, pad) then
		return "west"
	end
	if inDisc(x, z, EAST_ISLE, pad) then
		return "east"
	end
	return nil
end
local function groundY(x, z)
	return if isleOf(x, z) then 0 else nil
end
local function inRotunda(x, z, pad)
	return (x - ROTUNDA.x) ^ 2 + (z - ROTUNDA.z) ^ 2 <= (ROTUNDA.r + (pad or 0)) ^ 2
end
local function onPath(x, z, pad)
	for _, w in ipairs(WALKS) do
		if inRect(x, z, w, pad) then
			return true
		end
	end
	return inRect(x, z, STEPS, pad)
end
-- the part that owns a point: "rotunda", "plaza" or "sky"
local function zoneOf(x, z)
	if inRect(x, z, ZONE_ROTUNDA) then
		return "rotunda"
	end
	return if isleOf(x, z) == "main" then "plaza" else "sky"
end
-- free ground for props: on an island, off the walks, the pit, the rotunda, the arrival and the buyer
local function freeGround(x, z, pad)
	pad = pad or 0
	return isleOf(x, z, 10 + pad) ~= nil
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and not inRotunda(x, z, 8 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: the golden hour, dazzling white and gold (tints over already coloured textures stay light)
local GOLD = Color3.fromRGB(255, 236, 170) -- a tint over px_gold_block (keep it light)
local GOLD_DEEP = Color3.fromRGB(240, 200, 110)
local HONEY = Color3.fromRGB(236, 176, 60) -- honeycomb / raw gold look (over px_smooth_stone)
local QUARTZ = Color3.fromRGB(246, 242, 232) -- over px_smooth_stone / px_white_stone_bricks
local IRON = Color3.fromRGB(70, 70, 76) -- the observers' faces
local LIGHT = Color3.fromRGB(255, 226, 160) -- lanterns, froglights
local SNOW = Color3.fromRGB(246, 248, 252)
local CLOUD = Color3.fromRGB(252, 252, 255)
