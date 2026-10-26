-- ================================================================ market: the island, the ground, the streets
local core = folder("Core")
-- carved out of the island (the crypt part builds what lives in these voids)
local VOIDS = {
	{ CRYPT.x, CRYPT.z, CRYPT.r + 8, CRYPT.floor - 4, -4, circle = true }, -- the crypt (its walls, floor, vault)
	{ SINK.x, SINK.z, SINK.r, CRYPT.floor - 8, 2, circle = true }, -- the sinkhole: open from the plaza to the crypt
	-- the cliff cave tunnel: from the mouth on the east cliff west into the crypt
	{ CRYPT.x + CRYPT.r - 4, ISLAND_R + 16, CAVE_MOUTH.z - 12, CAVE_MOUTH.z + 12, CRYPT.floor - 4, CRYPT.floor + CAVE_MOUTH.h + 4 },
	-- the smugglers' way: a shaft under the hatch, a corridor south… then east into the crypt's west side
	{ HATCH.x - 6, HATCH.x + 6, HATCH.z - 6, HATCH.z + 6, CRYPT.floor - 4, 2 },
	{ HATCH.x - 10, HATCH.x + 10, CRYPT.z - 8, HATCH.z + 6, CRYPT.floor - 4, CRYPT.floor + 24 },
	{ HATCH.x - 10, CRYPT.x - CRYPT.r + 12, CRYPT.z - 10, CRYPT.z + 10, CRYPT.floor - 4, CRYPT.floor + 24 },
}

-- the ground of a cell: streets cobbled, the plaza in stone bricks, the hero plaza cracked and mossy, the stall
-- quarters a mix of cobble, gravel and packed dirt, grass outside the wall
local function groundTop(x, z)
	local n = n2(x, z, 3.3, 0.06)
	if not insideWalls(x, z, -WALL_OUT + WALL_IN) then
		-- the rim outside the wall: grass with dirt patches and some gravel near the gates
		if n > 0.35 then
			return "px_dirt", Color3.fromRGB(190, 160, 130), 0
		end
		return "px_grass_top", Color3.fromRGB(150, 200, 120), 0
	end
	if inHero(x, z) then
		if n > 0.25 then
			return "px_mossy_stone_bricks", Color3.fromRGB(160, 165, 155), 0
		elseif n < -0.3 then
			return "px_cobblestone", Color3.fromRGB(140, 140, 136), 0
		end
		return "px_stone_bricks", Color3.fromRGB(150, 150, 148), 0
	end
	if inPlaza(x, z) then
		-- a two-tone checker of stone bricks round the pit (the square of the market)
		local cx, cz = math.floor(x / 16), math.floor(z / 16)
		return "px_stone_bricks", if (cx + cz) % 2 == 0 then Color3.fromRGB(176, 172, 165) else Color3.fromRGB(150, 147, 142), 0
	end
	if inStreet(x, z) then
		if n > 0.45 then
			return "px_gravel", Color3.fromRGB(185, 180, 172), 0
		end
		return "px_cobblestone", PATH_T, 0
	end
	-- the stall quarters
	if n > 0.3 then
		return "px_gravel", Color3.fromRGB(175, 170, 162), 0
	elseif n < -0.35 then
		return "px_dirt", Color3.fromRGB(175, 145, 115), 0
	end
	return "px_cobblestone", COBBLE_T, 0
end

-- rock depth under a cell: deep in the middle, thinner to the edge, jagged (stalactites); under the crypt deep enough
-- for its floor and a thick base
local function rockDepth(x, z)
	local d = math.max(math.abs(x), math.abs(z)) / ISLAND_R
	local base = 30 + (1 - d) * 90
	local jag = (n2(x, z, 9.7, 0.09) + 0.5) * 26 + n2(x, z, 4.2, 0.025) * 18
	local depth = math.max(12, base + jag)
	if (x - CRYPT.x) ^ 2 + (z - CRYPT.z) ^ 2 <= (CRYPT.r + 24) ^ 2 then
		depth = math.max(depth, -CRYPT.floor + 44 + jag * 0.5)
	end
	return depth
end

local _, islandRuns = island({
	x0 = -ISLAND_R - 16,
	x1 = ISLAND_R + 16,
	z0 = -ISLAND_R - 16,
	z1 = ISLAND_R + 16,
	cell = 8,
	shape = onIsland,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_stone",
	rockTopTint = STONE_T,
	rockLow = "px_cobblestone",
	rockLowTint = Color3.fromRGB(125, 122, 118),
	voids = VOIDS,
}, core)
task.wait()

-- ================================================================ the mine in the square
local mine = minePit({ x = PIT.x, z = PIT.z, size = PIT.size, depth = PIT.depth, wall = "px_stone_bricks", wallTint = Color3.fromRGB(150, 148, 144), rim = "px_stone_bricks", rimTint = Color3.fromRGB(110, 108, 104) }, core)
-- low fences at the pit corners (the ladder gaps in the middle of each side stay open) and a lantern post on each
do
	local e = PIT_HALF + 2 * B + 1 -- just outside the rim
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local cx, cz = PIT.x + s[1] * e, PIT.z + s[2] * e
		fence(cx, cz, cx - s[1] * 36, cz, mine)
		fence(cx, cz, cx, cz - s[2] * 36, mine)
		lampPost(cx + s[1] * 3, cz + s[2] * 3, mine)
	end
	-- a pickaxe rack and crates of dug wool by the north ladder (the work of the mine)
	crate(PIT.x - 22, 0, PIT.z - e - 5, mine)
	crate(PIT.x - 18, 0, PIT.z - e - 5, mine)
	crate(PIT.x - 20, B, PIT.z - e - 5, mine, B, 0.3)
	for i, col in ipairs({ WOOL_RED, WOOL_YELLOW, WOOL_LIME }) do
		textured(cube("WoolBale", PIT.x + 16 + i * 4.4, 2, PIT.z - e - 5, B, B, B, nil, nil, mine), "px_white_wool", col)
	end
end

-- ================================================================ the arrival and the buyer (by the mine [владелец])
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive)
do
	-- the buyer's stall faces the arrival (west); the buyer stands behind the counter
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, { w = 4 * B, d = 2 * B, colA = WOOL_RED, colB = WOOL_WHITE, goods = { "px_white_wool", "px_gold_block", "px_white_wool" }, sign = "Скупка" }, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(150, 40, 36), pants = Color3.fromRGB(60, 50, 44) }, arrive)
	-- scales and sacks by the buyer
	barrel(BUYER.x + 3, 0, BUYER.z + 9, arrive, "px_gold_block")
	crate(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	-- a welcome board over the avenue south of the arrival
	local archZ = SPAWN.z + 18
	for _, sx in ipairs({ -1, 1 }) do
		textured(part("ArchPost", Vector3.new(B, 16, B), at(SPAWN.x + sx * 12, 8, archZ), nil, nil, arrive), "px_dark_oak_log")
		banner(at(SPAWN.x + sx * 12, 10, archZ - 2.2), if sx < 0 then BANNER_RED else BANNER_YELLOW, arrive, WOOL_WHITE)
	end
	textured(part("ArchBeam", Vector3.new(28, B, B), at(SPAWN.x, 16 + B / 2, archZ), nil, nil, arrive), "px_dark_oak_log")
	local board = textured(part("ArchBoard", Vector3.new(16, 3.2, 0.5), at(SPAWN.x, 13.2, archZ - 2.3), nil, nil, arrive), WOOD)
	boardText(board, "РЫНОК", Color3.fromRGB(255, 214, 120))
	lantern(V(SPAWN.x - 7, 12.6, archZ - 1), arrive, false, 16)
	lantern(V(SPAWN.x + 7, 12.6, archZ - 1), arrive, false, 16)
end

-- ================================================================ the boss spawn (the crypt part builds the room)
bossSpawn("un_king", CRYPT.x, CRYPT.floor + 2, CRYPT.z, CRYPT.r - 8, core)

-- ================================================================ lighting, the void net, the edge walls
-- the crypt and both tunnels are dark (soul lanterns light them); the market above keeps the outdoor daylight
lightingVolume("CryptAir", 120, CRYPT.floor + 20, CRYPT.z, 200, 52, 160, {
	Ambient = Color3.fromRGB(60, 96, 104),
	Exposure = -0.1,
	Haze = 0.28,
	ClockTime = 0,
	Brightness = 0.4,
	AtmosphereColor = Color3.fromRGB(60, 120, 125),
	AtmosphereDecay = Color3.fromRGB(20, 44, 52),
}, core)
do
	local net = part("VoidCatch", Vector3.new(760, 10, 760), at(0, -200, 40), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	-- invisible walls a little outside the island, wider in the south (the dock) and the east (the cliff stairs)
	edgeWalls({
		{ 0, -232, 520, 4 },
		{ 0, 300, 520, 4 },
		{ -236, 34, 4, 532 },
		{ 244, 34, 4, 532 },
	}, core)
end
print(("[build-market] core: island runs %d"):format(islandRuns))
