-- ================================================================ eden: the island, the rivers, the mine, arrival
local core = folder("Core")

-- the ground of a cell: muddy river beds, coarse dirt paths, mossy stone round the pit, meadow grass in patches of
-- moss and forest floor (the parts plant the flowers), the hill in deeper grass
local function groundTop(x, z)
	local y = groundY(x, z)
	local n = n2(x, z, 3.3, 0.05)
	if onRiver(x, z) then
		return "px_dirt", MUD, y
	end
	if inPitArea(x, z) then
		return "px_mossy_stone_bricks", nil, 0
	end
	if onPath(x, z) then
		return "px_dirt", PATH, y
	end
	if n > 0.36 then
		return "px_forest_floor", nil, y
	end
	if n < -0.34 then
		return "px_grass_top", MOSS, y
	end
	return "px_grass_top", if y > 0 or n > 0.1 then GRASS_DEEP else GRASS, y
end
-- the island hangs as a block of earth over grey stone (16-stud steps), deepest under the hill, ragged at the rim
local function rockDepth(x, z)
	local e = math.clamp(((math.abs(x) / HALF) ^ 4 + (math.abs(z) / HALF) ^ 4) ^ 0.25, 0, 1)
	local d = 16 + (1 - e) ^ 1.2 * 140 + math.max(0, groundY(x, z) or 0)
	if e > 0.84 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -232,
	x1 = 232,
	z0 = -232,
	z1 = 232,
	cell = 8,
	shape = function(x, z)
		return onIsland(x, z)
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_dirt",
	rockTopTint = Color3.fromRGB(150, 110, 80),
	rockLow = "px_stone",
	rockLowTint = Color3.fromRGB(176, 176, 180),
}, core)
task.wait()

-- ================================================================ the water of the rivers (no collision: wade on the bed)
do
	local wf = folder("Rivers", core)
	local runs = 0
	for z = -232, 224, 8 do
		local start
		local function flush(xEnd)
			if start then
				local w =
					box("River", start, RIVER_BED, z, xEnd, RIVER_TOP, z + 8, "px_water", WATER, wf)
				w.Transparency = 0.3
				w.CanCollide = false
				w.CastShadow = false
				runs += 1
				start = nil
			end
		end
		for x = -232, 224, 8 do
			local cx, cz = x + 4, z + 4
			if onIsland(cx, cz) and onRiver(cx, cz) then
				start = start or x
			else
				flush(x)
			end
		end
		flush(232)
	end
	print(("[build-eden] core: river runs %d"):format(runs))
end
task.wait()

-- ================================================================ the mine of brown mushroom blocks
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(150, 150, 152),
	rim = "px_mossy_stone_bricks",
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_planks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = ROOF_GREEN,
		colB = Color3.fromRGB(240, 240, 230),
		goods = { "px_terracotta", "px_terracotta", "px_terracotta" },
		sign = "Скупка",
	}, arrive)
	buyer(
		cf * CFrame.new(0, 3, 1.4),
		{ shirt = Color3.fromRGB(60, 120, 80), pants = Color3.fromRGB(110, 90, 60) },
		arrive
	)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	lampPost(BUYER.x - 10, BUYER.z - 6, arrive)
	zoneSign(SPAWN.x + 12, SPAWN.z - 16, "Эдем", -math.pi / 2, arrive)
end

-- ================================================================ the void net, the edge walls (noon: no lighting volume)
do
	local net = part("VoidCatch", Vector3.new(800, 10, 800), at(0, -260, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	local E = HALF + 24
	edgeWalls(
		{ { 0, -E, 2 * E, 4 }, { 0, E, 2 * E, 4 }, { -E, 0, 4, 2 * E }, { E, 0, 4, 2 * E } },
		core
	)
end
print(("[build-eden] core: island runs %d"):format(islandRuns))
