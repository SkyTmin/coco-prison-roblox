-- ================================================================ leprechaun valley: the plan shared by every part
local ISLAND_R = 224
local PIT = { x = 0, z = 60, size = 32, depth = 12 }
local PIT_HALF = PIT.size * B / 2 -- 64
local PLAZA_PAD = 24 -- the clover plaza round the pit rim
local SPAWN = { x = 0, z = 152 }
local BUYER = { x = 30, z = 156 }
local FORT = { x = 110, z = -100, arena = 52, moatIn = 60, moatOut = 72, bankOut = 88 }
local FORT_GATES = {
	{ name = "South", x = 110, z = -12, dir = Vector3.new(0, 0, 1) },
	{ name = "West", x = 22, z = -100, dir = Vector3.new(-1, 0, 0) },
	{ name = "East", x = 198, z = -100, dir = Vector3.new(1, 0, 0) },
}
local TREE = { x = 110, z = -150 }
local CAULDRON = { x = -112, z = -62, y = 16 }
local RAINBOW_FROM = { x = -196, z = -116 }
local WINDMILL = { x = -176, z = 120 }
local CAMP = { x0 = 120, x1 = 200, z0 = 10, z1 = 90 }
local FAIRY_RING = { x = 60, z = 170 }
local PATH_W = 20
local PATHS = {
	{ { 0, -12 }, { 0, -64 }, { 30, -100 } },
	{ { 72, -12 }, { 110, -6 } },
	{ { -76, 60 }, { -150, 60 }, { -130, -20 }, { -112, -40 } },
	{ { 76, 60 }, { 150, 40 }, { 196, -30 } },
	{ { 0, 132 }, { 0, 210 } }, -- the arrival south to the edge (the lookout over the clouds)
}
local RIVER_W = 16
local RIVER = { { 52, -100 }, { 10, -70 }, { -40, -30 }, { -100, 10 }, { -160, 24 }, { -232, 24 } }

local function polyDist(line, x, z)
	local best = math.huge
	for i = 1, #line - 1 do
		local d = segDist(x, z, line[i][1], line[i][2], line[i + 1][1], line[i + 1][2])
		if d < best then
			best = d
		end
	end
	return best
end
local function onPath(x, z, pad)
	pad = pad or 0
	for _, line in ipairs(PATHS) do
		if polyDist(line, x, z) <= PATH_W / 2 + pad then
			return true
		end
	end
	return false
end
local function inRiver(x, z, pad)
	return polyDist(RIVER, x, z) <= RIVER_W / 2 + (pad or 0)
end
local function fortDist(x, z)
	return math.sqrt((x - FORT.x) ^ 2 + (z - FORT.z) ^ 2)
end
local function inMoat(x, z)
	local d = fortDist(x, z)
	return d >= FORT.moatIn and d <= FORT.moatOut
end
local function inPlaza(x, z, pad)
	local e = PIT_HALF + 2 * B + PLAZA_PAD + (pad or 0)
	return math.abs(x - PIT.x) <= e and math.abs(z - PIT.z) <= e
end
local function onIsland(x, z)
	local r = ISLAND_R + n2(x, z, 2.7, 0.025) * 14 + n2(x, z, 5.1, 0.07) * 5
	return x * x + z * z <= r * r
end
-- the hills: flat valley floor (0) with terraced hills in the west and round the cauldron, a low ridge along the
-- north edge; paths, the plaza, the fort and the camp stay flat. Returns the top of the ground block (local y).
local function groundY(x, z)
	if inPlaza(x, z) or fortDist(x, z) <= FORT.bankOut + 6 or onPath(x, z, 2) then
		return 0
	end
	if x >= CAMP.x0 - 8 and x <= CAMP.x1 + 8 and z >= CAMP.z0 - 8 and z <= CAMP.z1 + 8 then
		return 0
	end
	local h = 0
	-- the west hills (burrows dug into them)
	if x < -96 then
		h = math.max(h, math.clamp((-96 - x) / 44, 0, 1) * 12 + math.max(0, n2(x, z, 1.9, 0.03)) * 8)
	end
	-- the cauldron hill
	local dc = math.sqrt((x - CAULDRON.x) ^ 2 + (z - CAULDRON.z) ^ 2)
	if dc < 52 then
		h = math.max(h, CAULDRON.y * math.clamp((52 - dc) / 34, 0, 1))
	end
	-- the north ridge
	if z < -150 and fortDist(x, z) > FORT.bankOut + 10 then
		h = math.max(h, math.clamp((-150 - z) / 40, 0, 1) * 10)
	end
	-- gentle bumps elsewhere
	h = math.max(h, math.max(0, n2(x, z, 8.3, 0.02) - 0.25) * 10)
	return math.floor(h / 4) * 4
end
-- stall-free decoration zone test (everything not reserved)
local function freeGround(x, z, pad)
	pad = pad or 0
	return onIsland(x, z)
		and not inPlaza(x, z, pad)
		and not onPath(x, z, pad)
		and not inRiver(x, z, pad)
		and fortDist(x, z) > FORT.bankOut + pad
		and math.sqrt(x * x + z * z) < ISLAND_R - 14
end

-- palette
local GRASS_T = Color3.fromRGB(150, 205, 110)
local GRASS_DARK_T = Color3.fromRGB(120, 180, 90)
local PATH_T = Color3.fromRGB(200, 175, 140)
local STONE_T = Color3.fromRGB(150, 150, 146)
local MOSS_T = Color3.fromRGB(150, 175, 130)
local WATER_C = Color3.fromRGB(80, 150, 220)
local GOLD_T = Color3.fromRGB(255, 220, 90)
local CLOVER_T = Color3.fromRGB(70, 160, 60)
local RAINBOW = {
	Color3.fromRGB(200, 40, 40),
	Color3.fromRGB(235, 130, 30),
	Color3.fromRGB(240, 210, 50),
	Color3.fromRGB(90, 190, 60),
	Color3.fromRGB(50, 120, 220),
	Color3.fromRGB(60, 60, 170),
	Color3.fromRGB(140, 60, 190),
}
local CONCRETE = {
	yellow = Color3.fromRGB(240, 200, 40),
	orange = Color3.fromRGB(235, 120, 30),
	lime = Color3.fromRGB(110, 190, 40),
	purple = Color3.fromRGB(130, 50, 180),
	red = Color3.fromRGB(180, 40, 40),
}
