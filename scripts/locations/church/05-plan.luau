-- ================================================================ church: the plan shared by every part
local ISLAND = { x = 0, z = -10, rx = 190, rz = 222 } -- an ellipse
local PIT = { x = 0, z = 70, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = 0, z = 164 }
local BUYER = { x = -32, z = 168 }
local PLAZA = { -104, -44, 104, 196 } -- { x0, z0, x1, z1 } the paved square
local CHURCH = { x0 = -40, x1 = 40, z0 = -190, z1 = -70, floor = 8, portal = { -12, 12 } }
local STEPS = { -24, -70, 24, -48 } -- the wide stair from the portal down to the square
local TOWER = { x0 = 48, x1 = 76, z0 = -98, z1 = -70, top = 180 }
local SUMMIT = { x = 62, z = -84, y = 104 } -- the belfry floor with the bell
local WALKS = { -- { x0, z0, x1, z1 } paths from the square to the bridges
	{ -180, -24, -104, -4 },
	{ 104, -24, 180, -4 },
}
local WEST_ISLE = { x = -266, z = -14, r = 34 }
local EAST_ISLE = { x = 266, z = -14, r = 34 }
local BRIDGES = { { -236, -22, -176, -6 }, { 176, -22, 236, -6 } } -- arched stone bridges at y 0 (the yard part)
local ZONE_CHURCH = { -110, -260, 110, -40 }

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function onPlaza(x, z, pad)
	return inRect(x, z, PLAZA, pad) and not inPitArea(x, z)
end
local function onPath(x, z, pad)
	pad = pad or 0
	if onPlaza(x, z, pad) then
		return true
	end
	for _, w in ipairs(WALKS) do
		if inRect(x, z, w, pad) then
			return true
		end
	end
	return false
end
local function inChurch(x, z, pad)
	pad = pad or 0
	return x >= CHURCH.x0 - pad
		and x <= CHURCH.x1 + pad
		and z >= CHURCH.z0 - pad
		and z <= CHURCH.z1 + pad
end
local function inTower(x, z, pad)
	pad = pad or 0
	return x >= TOWER.x0 - pad
		and x <= TOWER.x1 + pad
		and z >= TOWER.z0 - pad
		and z <= TOWER.z1 + pad
end
local function inDisc(x, z, c, pad)
	local r = c.r + n2(x, z, 4.4, 0.04) * 6 - (pad or 0)
	return (x - c.x) ^ 2 + (z - c.z) ^ 2 <= r * r
end
-- which island a point is on: "main", "west", "east" or nil (the sky)
local function isleOf(x, z, pad)
	local j = n2(x, z, 4.4, 0.04) * 9 - (pad or 0)
	if ((x - ISLAND.x) / (ISLAND.rx + j)) ^ 2 + ((z - ISLAND.z) / (ISLAND.rz + j)) ^ 2 <= 1 then
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
-- the part that owns a point: "church", "plaza" or "yard"
local function zoneOf(x, z)
	if inRect(x, z, ZONE_CHURCH) then
		return "church"
	end
	if math.abs(x) < 110 and z >= -40 then
		return "plaza"
	end
	return "yard"
end
-- free ground for props: on an island, off the square and the walks, the pit, the church, the tower and the arrival
local function freeGround(x, z, pad)
	pad = pad or 0
	return isleOf(x, z, 10 + pad) ~= nil
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and not inChurch(x, z, 8 + pad)
		and not inTower(x, z, 8 + pad)
		and not inRect(x, z, STEPS, 4 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: noon over the clouds (tints over already coloured textures stay light)
local WHITE_STONE = Color3.fromRGB(238, 236, 230) -- calcite / diorite look over px_smooth_stone, px_white_stone_bricks
local GREY_STONE = Color3.fromRGB(196, 196, 200)
local SLATE = Color3.fromRGB(70, 80, 120) -- the roofs
local GLASS_BLUE = Color3.fromRGB(50, 100, 200)
local GLASS_CYAN = Color3.fromRGB(90, 180, 225)
local GLASS_WHITE = Color3.fromRGB(225, 235, 245)
local GOLD = Color3.fromRGB(232, 192, 80)
local BANNER_BLUE = Color3.fromRGB(40, 64, 160)
local GRASS = Color3.fromRGB(150, 200, 100)
local CYPRESS = Color3.fromRGB(170, 200, 160) -- a tint over px_hedge (already dark green)
local CLAY = Color3.fromRGB(160, 166, 180)
local CLOUD = Color3.fromRGB(250, 252, 255)
