-- ================================================================ kyoto: the island, the terraces, the pond, the mine
local core = folder("Core")

-- the ground of a cell: cobbles on the square, a stone court round the temple, planks under the arena (the hill part
-- lays the wooden floor on it), a pebble bed in the pond, spring grass with petal-pink patches everywhere else
local function groundTop(x, z)
	local y = groundY(x, z)
	local n = n2(x, z, 3.3, 0.05)
	if y == POND.bed then
		return "px_gravel", Color3.fromRGB(150, 150, 140), y
	end
	if y == 0 and inRect(x, z, SQUARE) and onIsland(x, z, 12) then
		if inPitArea(x, z) then
			return "px_stone_bricks", STONE, 0
		end
		return if n > 0.25 then "px_cobblestone" else "px_stone_bricks", STONE, 0
	end
	if y == L2_Y and inRect(x, z, { TEMPLE.x0 - 16, TEMPLE.z0 - 56, TEMPLE.x1 + 8, TEMPLE.z1 + 4 }) then
		return "px_smooth_stone", STONE, y -- the temple court and the pagoda yard
	end
	if y == L2_Y and inArena(x, z, 4) then
		return "px_stone_bricks", STONE, y
	end
	if n > 0.36 then
		return "px_forest_floor", nil, y
	end
	if n < -0.38 then
		return "px_grass_top", Color3.fromRGB(235, 170, 196), y -- fallen petals over the grass
	end
	return "px_grass_top", GRASS, y
end
-- stone cliffs: the island hangs as a terraced block of stone, deepest under its middle (16-stud steps)
local function rockDepth(x, z)
	local rr = math.clamp(math.sqrt(x * x + z * z) / ISLAND_R, 0, 1)
	local d = 16 + (1 - rr) ^ 1.2 * 140 + groundY(x, z)
	if rr > 0.85 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 24
	end
	return math.max(12, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	x0 = -248,
	x1 = 248,
	z0 = -248,
	z1 = 248,
	cell = 8,
	shape = function(x, z)
		return onIsland(x, z)
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_stone",
	rockTopTint = Color3.fromRGB(150, 150, 150),
	rockLow = "px_stone",
	rockLowTint = Color3.fromRGB(116, 116, 120),
}, core)
task.wait()

-- ================================================================ the pond (px_water, walk-through) and the stage's footing
do
	local water = folder("Water", core)
	-- the water fills the pond bed in 8-stud strips that follow the circle (cells of the island grid)
	for z = POND.z - POND.r, POND.z + POND.r - 8, 8 do
		local x0, x1
		for x = POND.x - POND.r, POND.x + POND.r - 8, 8 do
			if groundY(x + 4, z + 4) == POND.bed then
				x0 = x0 or x
				x1 = x + 8
			end
		end
		if x0 then
			local p = box("Pond", x0, POND.bed, z, x1, -1, z + 8, "px_water", WATER_C, water)
			p.Transparency = 0.3
			p.CanCollide = false
			p.CanQuery = false
			p.CastShadow = false
		end
	end
end

-- ================================================================ the mine in the lower square
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(130, 128, 126),
	rim = "px_smooth_stone",
	rimTint = STONE,
}, core)
do
	-- petals drifted into the corners of the pit rim
	local e = PIT_HALF + B
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local cx, cz = PIT.x + s[1] * e, PIT.z + s[2] * e
		decor(box("Petals", cx - 3, 0.4, cz - 3, cx + 3, 0.6, cz + 3, "px_white_wool", SAKURA, mine))
	end
end
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_cherry_planks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = TORII_RED,
		colB = PAPER,
		goods = { "px_white_wool", "px_sea_lantern", "px_white_wool" },
		sign = "Скупка",
	}, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(60, 50, 90), pants = Color3.fromRGB(40, 36, 44) }, arrive)
	barrel(BUYER.x + 3, 0, BUYER.z + 10, arrive)
	crate(BUYER.x - 3, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 8, "Киото", math.pi, arrive)
end

-- ================================================================ the boss, the petals in the air, the void net, the edge walls
bossSpawn("the_lovers", ARENA.x, L2_Y + 2, ARENA.z, ARENA.r - 8, core)
do
	-- cherry petals drifting over the whole island (open day light: no lighting volume on this floor)
	for _, a in ipairs({ { 0, 0, 440, 440 } }) do
		local p = decor(part("PetalFall", Vector3.new(a[3], 1, a[4]), at(a[1], 70, a[2]), nil, nil, core))
		p.Transparency = 1
		emitter(p, {
			Rate = 30,
			Lifetime = NumberRange.new(10, 16),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Bottom,
			Size = NumberSequence.new(0.35),
			Color = ColorSequence.new(SAKURA),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(0.9, 0.1), NumberSequenceKeypoint.new(1, 1) }),
			RotSpeed = NumberRange.new(-90, 90),
			Rotation = NumberRange.new(0, 360),
		})
	end
	local net = part("VoidCatch", Vector3.new(800, 10, 800), at(0, -240, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	local E = ISLAND_R + 24
	edgeWalls({ { 0, -E, 2 * E, 4 }, { 0, E, 2 * E, 4 }, { -E, 0, 4, 2 * E }, { E, 0, 4, 2 * E } }, core)
end
print(("[build-kyoto] core: island runs %d"):format(islandRuns))
