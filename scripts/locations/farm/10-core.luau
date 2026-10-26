-- ================================================================ farm: the island, the hill, the ground, the mine
local core = folder("Core")

-- the ground of a cell: dirt paths, dark farmland in the crop beds (the fields part plants them), a packed dirt
-- clearing for the arena, gravel in the barn yard, summer grass with flower and forest-floor patches elsewhere
local function groundTop(x, z)
	local y = groundY(x, z)
	local n = n2(x, z, 3.1, 0.05)
	if y == 0 then
		if inPitArea(x, z) then
			return "px_cobblestone", STONE, 0
		end
		if onPath(x, z) then
			return "px_dirt", PATH_DIRT, 0
		end
		if inField(x, z) then
			return "px_dirt", FARMLAND, 0
		end
		if inRect(x, z, BARN_YARD) then
			return if n > 0.2 then "px_gravel" else "px_dirt", if n > 0.2 then nil else PATH_DIRT, 0
		end
	end
	if y == L1_Y and inArena(x, z, 4) then
		return "px_dirt", if n > 0.25 then Color3.fromRGB(150, 116, 84) else PATH_DIRT, y
	end
	if y == L1_Y and x < -24 and n > 0.3 then
		return "px_forest_floor", nil, y -- the grove floor
	end
	return "px_grass_top", GRASS, y
end
-- grass cliffs over dirt and stone: the island hangs as a terraced block (16-stud steps)
local function rockDepth(x, z)
	local d = math.max(math.abs(x), math.abs(z)) / ISLAND_H
	local deep = 16 + (1 - math.clamp(d, 0, 1)) ^ 1.2 * 130 + groundY(x, z)
	if d > 0.85 then
		deep += (n2(x, z, 7.7, 0.09) + 0.5) * 24
	end
	return math.max(12, math.floor(deep / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
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
	rockTopTint = Color3.fromRGB(150, 116, 86),
	rockLow = "px_stone",
	rockLowTint = Color3.fromRGB(140, 140, 140),
}, core)
task.wait()

-- ================================================================ the mine in the middle of the fields
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(130, 130, 130),
	rim = "px_cobblestone",
	rimTint = STONE,
}, core)
do
	-- hay bales and baskets of the harvest at the pit corners
	local e = PIT_HALF + B
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 } }) do
		local cx, cz = PIT.x + s[1] * (e + 2), PIT.z + s[2] * (e + 2)
		cube("HayBale", cx, 2, cz, B, B, B, "px_hay", nil, mine)
		cube("HayBale", cx - s[1] * B, 2, cz, B, B, B, "px_hay", nil, mine)
		cube("HayBale", cx, 6, cz, B, B, B, "px_hay", nil, mine)
	end
end
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_planks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(240, 200, 50),
		colB = Color3.fromRGB(245, 240, 225),
		goods = { "px_melon", "px_hay", "px_melon" },
		sign = "Скупка",
	}, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(70, 110, 170), pants = Color3.fromRGB(90, 70, 50) }, arrive)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 8, "Ферма", math.pi, arrive)
end

-- ================================================================ the boss, the void net, the edge walls (open day light: no volume)
bossSpawn("ent", ARENA.x, L1_Y + 2, ARENA.z, ARENA.r - 8, core)
do
	local net = part("VoidCatch", Vector3.new(800, 10, 800), at(0, -240, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	local E = ISLAND_H + 24
	edgeWalls({ { 0, -E, 2 * E, 4 }, { 0, E, 2 * E, 4 }, { -E, 0, 4, 2 * E }, { E, 0, 4, 2 * E } }, core)
end
print(("[build-farm] core: island runs %d"):format(islandRuns))
