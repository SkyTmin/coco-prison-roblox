-- ================================================================ leprechaun valley: the island, the ground, water
local core = folder("Core")

-- the ground of a cell: grass hills, dirt paths, the plaza round the mine, the river and moat beds, the fort's banks
local function groundTop(x, z)
	local n = n2(x, z, 3.7, 0.05)
	-- the river and the moat: a bed one block down (water parts are laid on top below)
	if inRiver(x, z) and not inPlaza(x, z) then
		return "px_gravel", Color3.fromRGB(150, 145, 135), -4
	end
	local fd = fortDist(x, z)
	if fd >= FORT.moatIn and fd <= FORT.moatOut then
		-- the gates cross the moat on bridges (built by the fort part): the bed stays
		return "px_gravel", Color3.fromRGB(150, 145, 135), -4
	end
	if fd > FORT.moatOut and fd <= FORT.bankOut then
		-- the earth banks of the fairy fort: a double ring (8 high in the middle, 4 at the sides), cut at the gates
		for _, g in ipairs(FORT_GATES) do
			if math.sqrt((x - g.x) ^ 2 + (z - g.z) ^ 2) < 20 then
				return "px_dirt", PATH_T, 0
			end
		end
		local h = if fd > FORT.moatOut + 4 and fd < FORT.bankOut - 4 then 8 else 4
		return (if n > 0.2 then "px_mossy_cobblestone" else "px_grass_top"), (if n > 0.2 then MOSS_T else GRASS_DARK_T), h
	end
	if fd < FORT.moatIn then
		-- the arena: packed earth and moss in rings (the fort part lays its stone rings over it)
		return (if n > 0.1 then "px_forest_floor" else "px_dirt"), Color3.fromRGB(165, 140, 110), 0
	end
	if inPlaza(x, z) then
		return "px_stone_bricks", Color3.fromRGB(170, 168, 160), 0
	end
	if onPath(x, z) then
		if n > 0.4 then
			return "px_gravel", Color3.fromRGB(185, 178, 165), 0
		end
		return "px_dirt", PATH_T, 0
	end
	local y = groundY(x, z)
	if n > 0.45 then
		return "px_forest_floor", Color3.fromRGB(150, 160, 110), y
	end
	return "px_grass_top", if n < -0.3 then GRASS_DARK_T else GRASS_T, y
end
local function rockDepth(x, z)
	local d = math.sqrt(x * x + z * z) / ISLAND_R
	local jag = (n2(x, z, 6.1, 0.09) + 0.5) * 28 + n2(x, z, 2.2, 0.03) * 16
	return math.max(12, 26 + (1 - d) * 100 + jag)
end
local _, islandRuns = island({
	x0 = -ISLAND_R - 24,
	x1 = ISLAND_R + 24,
	z0 = -ISLAND_R - 24,
	z1 = ISLAND_R + 24,
	cell = 8,
	shape = onIsland,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_dirt",
	rockTopTint = Color3.fromRGB(150, 120, 95),
	rockLow = "px_stone",
	rockLowTint = STONE_T,
}, core)
task.wait()

-- ================================================================ water: the river and the moat (px_water, walk-through)
local water = folder("Water", core)
local function waterStrip(ax, az, bx, bz, w)
	local a, b = V(ax, -2.5, az), V(bx, -2.5, bz)
	local len = (b - a).Magnitude
	local p = part("River", Vector3.new(w, 3, len + w * 0.5), CFrame.lookAt((a + b) / 2, b), WATER_C, nil, water)
	textured(p, "px_water", WATER_C)
	p.Transparency = 0.25
	p.CanCollide = false
	p.CanQuery = false
	p.CastShadow = false
	return p
end
for i = 1, #RIVER - 1 do
	waterStrip(RIVER[i][1], RIVER[i][2], RIVER[i + 1][1], RIVER[i + 1][2], RIVER_W - 1)
end
do
	local r = (FORT.moatIn + FORT.moatOut) / 2
	local seg = 28
	for k = 0, seg - 1 do
		local a0, a1 = k / seg * math.pi * 2, (k + 1) / seg * math.pi * 2
		waterStrip(FORT.x + math.cos(a0) * r, FORT.z + math.sin(a0) * r, FORT.x + math.cos(a1) * r, FORT.z + math.sin(a1) * r, FORT.moatOut - FORT.moatIn - 1)
	end
end

-- ================================================================ the mine, its plaza and the arrival on a clover
local mine = minePit({ x = PIT.x, z = PIT.z, size = PIT.size, depth = PIT.depth, wall = "px_stone_bricks", wallTint = Color3.fromRGB(150, 148, 142), rim = "px_mossy_stone_bricks", rimTint = MOSS_T }, core)
do
	local e = PIT_HALF + 2 * B + 1
	-- a wooden rail round the rim with gaps at the ladders, lanterns on stone posts at the corners
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local cx, cz = PIT.x + s[1] * e, PIT.z + s[2] * e
		fence(cx, cz, cx - s[1] * 40, cz, mine)
		fence(cx, cz, cx, cz - s[2] * 40, mine)
		cube("RimPost", cx + s[1] * 2, 2, cz + s[2] * 2, B, B, B, "px_mossy_cobblestone", MOSS_T, mine)
		lantern(V(cx + s[1] * 2, B + 0.75, cz + s[2] * 2), mine)
	end
	-- crates of dug concrete by the north ladder (the five colours of the справочник)
	local i = 0
	for _, col in pairs(CONCRETE) do
		i += 1
		cube("ConcreteCrate", PIT.x - 26 + i * 4.4, 2, PIT.z - e - 6, B, B, B, "px_smooth_stone", col, mine)
	end
end
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_mossy_stone_bricks")
do
	-- the arrival stands on a four-leaf clover mosaic laid in the plaza (green blocks flush with the floor)
	local leaves = {
		{ 0, -1 }, { 0, -2 }, { -1, -2 }, { 1, -2 }, { 0, -3 },
		{ 0, 1 }, { 0, 2 }, { -1, 2 }, { 1, 2 }, { 0, 3 },
		{ -1, 0 }, { -2, 0 }, { -2, -1 }, { -2, 1 }, { -3, 0 },
		{ 1, 0 }, { 2, 0 }, { 2, -1 }, { 2, 1 }, { 3, 0 },
	}
	for _, c in ipairs(leaves) do
		box("Clover", SPAWN.x + c[1] * B - B / 2, -0.2, SPAWN.z + c[2] * B - B / 2, SPAWN.x + c[1] * B + B / 2, 0.05, SPAWN.z + c[2] * B + B / 2, "px_grass_top", CLOVER_T, arrive)
	end
	box("CloverStem", SPAWN.x + B / 2, -0.2, SPAWN.z + 3.5 * B, SPAWN.x + 1.5 * B, 0.05, SPAWN.z + 5.5 * B, "px_grass_top", CLOVER_T, arrive)
	-- the buyer at a green-awning stall facing the arrival (west)
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, { w = 4 * B, d = 2 * B, colA = Color3.fromRGB(60, 140, 60), colB = Color3.fromRGB(240, 236, 228), goods = { "px_smooth_stone", "px_gold_block", "px_smooth_stone" }, sign = "Скупка" }, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(50, 120, 50), pants = Color3.fromRGB(70, 55, 40) }, arrive)
	barrel(BUYER.x + 3, 0, BUYER.z + 9, arrive, "px_gold_block")
	crate(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 6, "Лепреконовая долина", math.pi, arrive)
end

-- ================================================================ the boss, the void net, the edge walls
bossSpawn("forest_spirit", FORT.x, 2, FORT.z, FORT.arena - 8, core)
do
	local net = part("VoidCatch", Vector3.new(760, 10, 760), at(0, -220, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	local E = ISLAND_R + 26
	edgeWalls({ { 0, -E, 2 * E, 4 }, { 0, E, 2 * E, 4 }, { -E, 0, 4, 2 * E }, { E, 0, 4, 2 * E } }, core)
end
print(("[build-leprechaun-valley] core: island runs %d"):format(islandRuns))
