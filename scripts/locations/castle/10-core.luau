-- ================================================================ castle: the island, the ground, the mine, arrival
local core = folder("Core")

-- the ground of a cell: quartz paving in the bailey with soot-dark and grassy patches, a paler avenue, a smooth court
-- (the court part lays its ring pattern on it), dark grass and dirt outside the wall, stone on the gate terrace
local function groundTop(x, z)
	local n = n2(x, z, 2.9, 0.055)
	local m = n2(x, z, 6.3, 0.02)
	if not insideWalls(x, z, -(WALL_OUT - WALL_IN)) then
		if z > ISLAND_R - 4 and math.abs(x) <= 40 then
			return "px_stone_bricks", DEEP, 0 -- the gate terrace
		end
		if n > 0.3 then
			return "px_dirt", Color3.fromRGB(140, 120, 100), 0
		end
		return "px_grass_top", GRASS_DARK, 0
	end
	if inCourt(x, z) then
		return "px_smooth_stone", QUARTZ, 0
	end
	if inRect(x, z, AVENUE) then
		return "px_white_stone_bricks", QUARTZ_SHADE, 0
	end
	if inPitArea(x, z, 24) then
		return "px_white_stone_bricks", if n > 0.35 then DEEP else QUARTZ, 0
	end
	-- the bailey: quartz tiles; soot stains; overgrown patches where the gardens are
	if m > 0.25 and n > -0.1 then
		return "px_grass_top", GRASS_DARK, 0
	end
	if n > 0.42 then
		return "px_stone_bricks", DEEP, 0
	elseif n < -0.4 then
		return "px_smooth_stone", QUARTZ_SHADE, 0
	end
	return "px_white_stone_bricks", QUARTZ, 0
end
local function rockDepth(x, z)
	local d = math.max(math.abs(x), math.abs(z)) / ISLAND_R
	local jag = (n2(x, z, 7.7, 0.09) + 0.5) * 24 + n2(x, z, 3.1, 0.03) * 14
	if z > ISLAND_R - 4 then
		return 10 + jag * 0.3 -- the thin gate terrace
	end
	return math.max(12, 30 + (1 - d) * 96 + jag)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -ISLAND_R - 16,
	x1 = ISLAND_R + 16,
	z0 = -ISLAND_R - 16,
	z1 = ISLAND_R + 48,
	cell = 8,
	shape = onIsland,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_stone",
	rockTopTint = Color3.fromRGB(140, 140, 144),
	rockLow = "px_stone_bricks",
	rockLowTint = DEEP,
}, core)
task.wait()

-- ================================================================ the mine in the outer bailey (the palace square torn up)
local mine = minePit({ x = PIT.x, z = PIT.z, size = PIT.size, depth = PIT.depth, wall = "px_stone_bricks", wallTint = DEEP, rim = "px_white_stone_bricks", rimTint = QUARTZ_SHADE }, core)
do
	local e = PIT_HALF + 2 * B + 1
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local cx, cz = PIT.x + s[1] * e, PIT.z + s[2] * e
		-- quartz bollards with iron chains between them along the corners (the ladder gaps stay open)
		for k = 0, 4 do
			local bx, bz = cx - s[1] * k * 9, cz
			cube("Bollard", bx, 2, bz, 2, 4, 2, "px_white_stone_bricks", QUARTZ, mine)
			local bx2, bz2 = cx, cz - s[2] * k * 9
			cube("Bollard", bx2, 2, bz2, 2, 4, 2, "px_white_stone_bricks", QUARTZ, mine)
		end
		decor(beam("Chain", V(cx, 3.2, cz), V(cx - s[1] * 36, 3.2, cz), 0.3, SOOT, mine, Enum.Material.Metal))
		decor(beam("Chain", V(cx, 3.2, cz), V(cx, 3.2, cz - s[2] * 36), 0.3, SOOT, mine, Enum.Material.Metal))
		lampPost(cx + s[1] * 4, cz + s[2] * 4, mine)
	end
	-- quartz blocks stacked by the north ladder, ready to haul
	for i = 0, 3 do
		cube("QuartzStack", PIT.x - 10 + i * 4.4, 2, PIT.z - e - 6, B, B, B, "px_smooth_stone", QUARTZ, mine)
	end
	cube("QuartzStack", PIT.x - 6, 6, PIT.z - e - 6, B, B, B, "px_white_stone_bricks", QUARTZ, mine)
end
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_white_stone_bricks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, { w = 4 * B, d = 2 * B, colA = BANNER_BLACK, colB = WING_WHITE, goods = { "px_smooth_stone", "px_white_stone_bricks", "px_smooth_stone" }, sign = "Скупка" }, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(45, 45, 52), pants = Color3.fromRGB(70, 70, 78) }, arrive)
	barrel(BUYER.x + 3, 0, BUYER.z + 9, arrive)
	crate(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x + 14, SPAWN.z + 8, "Замок", math.pi, arrive)
end

-- ================================================================ the boss, the light, the void net, the edge walls
bossSpawn("raven_knight", COURT.x, 2, COURT.z, COURT.r - 8, core)
-- an overcast grey evening over the whole castle (the only lighting volume of this floor)
lightingVolume("OvercastAir", 0, 100, 20, 500, 260, 560, {
	Ambient = Color3.fromRGB(150, 150, 162),
	Exposure = -0.1,
	Haze = 0.22,
	ClockTime = 17.2,
	Brightness = 1.5,
	AtmosphereColor = Color3.fromRGB(170, 176, 192),
	AtmosphereDecay = Color3.fromRGB(105, 110, 128),
}, core)
do
	local net = part("VoidCatch", Vector3.new(760, 10, 760), at(0, -200, 20), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	local E = ISLAND_R + 24
	edgeWalls({ { 0, -E, 2 * E, 4 }, { 0, ISLAND_R + 56, 2 * E, 4 }, { -E, 20, 4, 2 * E + 72 }, { E, 20, 4, 2 * E + 72 } }, core)
end
print(("[build-castle] core: island runs %d"):format(islandRuns))
