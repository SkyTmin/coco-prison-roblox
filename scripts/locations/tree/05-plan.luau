-- ================================================================ tree: the plan shared by every part
local WEST = { x = -150, z = 30, r = 128 }
local CENTRAL = { x = 30, z = -30, r = 100 }
local EAST = { x = 230, z = 24, r = 80 }
local PIT = { x = -150, z = 30, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local SPAWN = { x = -56, z = 30 }
local BUYER = { x = -50, z = 50 }
local TREE = { x = 36, z = -48, r = 24, door = { x0 = 28, x1 = 44 } }
local TREE_ZONE_R = 72
local SUMMIT = { x = 36, z = -48, y = 140, r = 44 }
local RING = { inner = PIT_HALF + 2 * B, outer = PIT_HALF + 6 * B, round = 118 } -- the boardwalk round the pit
local PATHS = { -- { x0, z0, x1, z1 } at y 0
	{ -62, 20, 56, 40 }, -- MAIN STREET: the ring → under the tree
	{ 26, -24, 46, 20 }, -- the DOOR path into the trunk
	{ 46, -6, 120, 14 }, -- the EAST path → the rope bridge
}
local BRIDGE = { 116, -2, 164, 10 } -- the rope bridge to the east island (the east part builds it)

local function inRect(x, z, r, pad)
	pad = pad or 0
	return x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad
end
local function inPitArea(x, z, pad)
	local e = PIT_HALF + 2 * B + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
-- the boardwalk ring: a square band round the pit rim with its outer corners cut round
local function onRing(x, z, pad)
	pad = pad or 0
	local dx, dz = math.abs(x - PIT.x), math.abs(z - PIT.z)
	local c = math.max(dx, dz)
	return c > RING.inner - pad
		and c <= RING.outer + pad
		and math.sqrt(dx * dx + dz * dz) <= RING.round + pad
end
local function onPath(x, z, pad)
	pad = pad or 0
	if onRing(x, z, pad) then
		return true
	end
	for _, p in ipairs(PATHS) do
		if inRect(x, z, p, pad) then
			return true
		end
	end
	return false
end
local function inDisc(x, z, c, pad)
	local r = c.r + n2(x, z, 4.4, 0.04) * 9 - (pad or 0)
	return (x - c.x) ^ 2 + (z - c.z) ^ 2 <= r * r
end
-- which island a point is on: "west", "central", "east" or nil (the sky)
local function isleOf(x, z, pad)
	if inDisc(x, z, WEST, pad) then
		return "west"
	end
	if inDisc(x, z, CENTRAL, pad) then
		return "central"
	end
	if inDisc(x, z, EAST, pad) then
		return "east"
	end
	return nil
end
local function groundY(x, z)
	return if isleOf(x, z) then 0 else nil
end
local function inTreeZone(x, z, pad)
	return (x - TREE.x) ^ 2 + (z - TREE.z) ^ 2 <= (TREE_ZONE_R + (pad or 0)) ^ 2
end
local function inTrunk(x, z, pad)
	return (x - TREE.x) ^ 2 + (z - TREE.z) ^ 2 <= (TREE.r + (pad or 0)) ^ 2
end
-- the part that owns a point: "tree", "west" or "east"
local function zoneOf(x, z)
	if inTreeZone(x, z) then
		return "tree"
	end
	return if x < 0 then "west" else "east"
end
-- free ground for props: on an island, off the paths, the pit, the trunk and the arrival
local function freeGround(x, z, pad)
	pad = pad or 0
	return isleOf(x, z, 10 + pad) ~= nil
		and not onPath(x, z, 2 + pad)
		and not inPitArea(x, z, 4 + pad)
		and not inTrunk(x, z, 8 + pad)
		and math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) > 20 + pad
		and math.sqrt((x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2) > 14 + pad
end

-- palette: an early morning in the sky
local GRASS = Color3.fromRGB(150, 200, 100)
local GRASS_DEEP = Color3.fromRGB(120, 178, 84)
local COARSE = Color3.fromRGB(150, 108, 72) -- coarse dirt paths
local BARK = Color3.fromRGB(190, 150, 120) -- tints for the bark mix (over px_*_log, already brown: keep them light)
local BARK_DARK = Color3.fromRGB(140, 110, 90)
local OAK_LEAF = Color3.fromRGB(180, 215, 150) -- tints over px_hedge (already dark green): keep them light
local AZALEA = Color3.fromRGB(205, 230, 150)
local BLOSSOM = Color3.fromRGB(255, 205, 235) -- flowering azalea: a tint over px_cherry_leaves (already pink)
local MOSS = Color3.fromRGB(130, 170, 90)
local SAP = Color3.fromRGB(236, 238, 238) -- white concrete
local CLOUD = Color3.fromRGB(250, 252, 255)
