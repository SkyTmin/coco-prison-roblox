-- ================================================================ barn: the island, the ground, the mine, arrival
local core = folder("Core")

-- the ground of a cell: podzol/dirt paths, a trampled dirt barnyard (the arena), old planks inside the barn (the
-- barn part lays its floor), overgrown autumn weeds with podzol and coarse dirt patches everywhere else
local function groundTop(x, z)
	local n = n2(x, z, 3.3, 0.05)
	if inPitArea(x, z) then
		return "px_cobblestone", Color3.fromRGB(130, 126, 120), 0
	end
	if inBarn(x, z) then
		return "px_dirt", PODZOL, 0
	end
	if onPath(x, z) then
		return "px_dirt", if n > 0.25 then PODZOL else PATH_DIRT, 0
	end
	if inArena(x, z, 4) then
		return if n > 0.2 then "px_forest_floor" else "px_dirt", if n > 0.2 then nil else PODZOL, 0
	end
	if n > 0.32 then
		return "px_forest_floor", nil, 0
	end
	if n < -0.36 then
		return "px_dirt", PODZOL, 0
	end
	return "px_grass_top", WEEDS, 0
end
-- the island hangs as a terraced block of dirt and stone (16-stud steps), ragged near the rim
local function rockDepth(x, z)
	local rr = math.clamp(math.sqrt(x * x + z * z) / ISLAND_R, 0, 1)
	local d = 16 + (1 - rr) ^ 1.2 * 130
	if rr > 0.85 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 24
	end
	return math.max(12, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	x0 = -240,
	x1 = 240,
	z0 = -240,
	z1 = 240,
	cell = 8,
	shape = function(x, z)
		return onIsland(x, z)
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_dirt",
	rockTopTint = Color3.fromRGB(130, 100, 76),
	rockLow = "px_stone",
	rockLowTint = Color3.fromRGB(120, 120, 126),
}, core)
task.wait()

-- ================================================================ the mine in front of the barn
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(110, 100, 96),
	rim = "px_cobblestone",
	rimTint = Color3.fromRGB(130, 126, 120),
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_planks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(170, 40, 36),
		colB = Color3.fromRGB(226, 218, 200),
		goods = { "px_hay", "px_hay", "px_hay" },
		sign = "Скупка",
	}, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(110, 70, 40), pants = Color3.fromRGB(60, 54, 50) }, arrive)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	lampPost(BUYER.x - 10, BUYER.z - 8, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 8, "Амбар", math.pi, arrive)
end

-- ================================================================ the boss, the dusk, the void net, the edge walls
bossSpawn("forest_guardian", ARENA.x, 2, ARENA.z, ARENA.r - 8, core)
-- an autumn dusk with fog over the whole island (the only lighting volume of this floor); pumpkins give the light
lightingVolume("AutumnDusk", 0, 80, 0, 520, 360, 520, {
	Ambient = Color3.fromRGB(170, 132, 104),
	Exposure = -0.05,
	Haze = 0.38,
	ClockTime = 17.6,
	Brightness = 1.4,
	AtmosphereColor = Color3.fromRGB(214, 156, 108),
	AtmosphereDecay = Color3.fromRGB(110, 72, 60),
}, core)
do
	local net = part("VoidCatch", Vector3.new(800, 10, 800), at(0, -240, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	local E = ISLAND_R + 28
	edgeWalls({ { 0, -E, 2 * E, 4 }, { 0, E, 2 * E, 4 }, { -E, 0, 4, 2 * E }, { E, 0, 4, 2 * E } }, core)
end
print(("[build-barn] core: island runs %d"):format(islandRuns))
