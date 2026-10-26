-- ================================================================ purgatory: the island, the terraces, the mine, arrival
local core = folder("Core")

-- the ground of a cell: the terrace of its level (red sandstone at the foot → sandstone → cut sandstone at the top;
-- the mount part lays the summit's checkered floor), sand on the bay floor, cut sandstone round the pit
local function groundTop(x, z)
	local l = levelAt(x, z)
	local y = l * STEP_Y
	local n = n2(x, z, 3.3, 0.05)
	if inPitArea(x, z) then
		return "px_cut_sandstone", SAND, 0
	end
	if inBay(x, z) then
		return if n > 0.3 then "px_sandstone" else "px_sand", SAND, 0
	end
	if l <= 1 then
		return if n > 0.25 then "px_red_sand" else "px_red_sandstone", RED_SAND, y
	end
	if l <= 3 then
		return if n > 0.35 then "px_sand" else "px_sandstone", SAND, y
	end
	return if n > 0.35 then "px_sandstone" else "px_cut_sandstone", SAND_PALE, y
end
-- the island hangs as a block of sandstone over red rock (16-stud steps), deepest under the peak, ragged at the rim
local function rockDepth(x, z)
	local rr = math.clamp(math.sqrt((x - ISLAND.x) ^ 2 + (z - ISLAND.z) ^ 2) / ISLAND.r, 0, 1)
	local d = 20 + (1 - rr) ^ 1.2 * 150 + levelAt(x, z) * STEP_Y
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = CELL.x0,
	x1 = 232,
	z0 = CELL.z0,
	z1 = 240,
	cell = CELL.size,
	shape = function(x, z)
		return onIsland(x, z)
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_sandstone",
	rockTopTint = SAND,
	rockLow = "px_red_sandstone",
	rockLowTint = RED_SAND,
}, core)
task.wait()

-- ================================================================ the quarry of chiseled sandstone in the bay
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_cut_sandstone",
	wallTint = SAND,
	rim = "px_sandstone",
	rimTint = SAND_PALE,
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_cut_sandstone")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, -math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = BANNER_RED,
		colB = Color3.fromRGB(240, 236, 226),
		goods = { "px_cut_sandstone", "px_sandstone", "px_cut_sandstone" },
		sign = "Скупка",
	}, arrive)
	buyer(
		cf * CFrame.new(0, 3, 1.4),
		{ shirt = Color3.fromRGB(150, 60, 40), pants = Color3.fromRGB(110, 90, 70) },
		arrive
	)
	crate(BUYER.x - 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x + 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x + 14, SPAWN.z + 8, "Чистилище", math.pi, arrive)
end

-- ================================================================ the sunset, the void net, the edge walls
-- a hazy orange sunset over the mountain (the only lighting volume of this floor)
lightingVolume("PurgatorySunset", 0, 100, 8, 520, 440, 520, {
	Ambient = Color3.fromRGB(170, 130, 110),
	Exposure = 0,
	Haze = 0.34,
	ClockTime = 17.9,
	Brightness = 1.8,
	AtmosphereColor = Color3.fromRGB(240, 170, 120),
	AtmosphereDecay = Color3.fromRGB(150, 100, 130),
}, core)
do
	local net = part("VoidCatch", Vector3.new(800, 10, 800), at(0, -260, 8), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	edgeWalls(
		{ { 0, -238, 504, 4 }, { 0, 256, 504, 4 }, { -250, 8, 4, 500 }, { 250, 8, 4, 500 } },
		core
	)
end
print(("[build-purgatory] core: island runs %d"):format(islandRuns))
