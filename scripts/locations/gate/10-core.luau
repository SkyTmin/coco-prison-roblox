-- ================================================================ gate: the islands, the square, the mine, arrival
local core = folder("Core")

-- the ground of a cell: the parade square of sandstone in 2-block squares round the pit, pearl and calcite on the
-- terrace, a pearl brick band along the rim; the islets pearl
local function groundTop(x, z)
	local isle = isleOf(x, z)
	local cx, cz = math.floor(x / 8), math.floor(z / 8)
	local even = (cx + cz) % 2 == 0
	if isle ~= "main" then
		return "px_smooth_stone", if even then PEARL else CALCITE, 0
	end
	if onTerrace(x, z) then
		return "px_smooth_stone", if even then PEARL else CALCITE, TERRACE_Y
	end
	if inPitArea(x, z) then
		return "px_cut_sandstone", SAND, 0
	end
	if not onMain(x, z, 8) then
		return "px_white_stone_bricks", PEARL, 0 -- the rim band
	end
	return if even then "px_sandstone" else "px_cut_sandstone", SAND, 0
end
-- the islands hang as white stone bricks over pale stone (16-stud steps), ragged at the rim; the terrace's cliff
-- reaches the same bottom as the square round it
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local rr, deep
	if isle == "main" then
		rr = ((math.abs(x - ISLAND.x) / ISLAND.ax) ^ 3 + (math.abs(z - ISLAND.z) / ISLAND.az) ^ 3)
			^ (1 / 3)
		deep = 150
	else
		for _, s in ipairs(ISLES) do
			if s.name == isle then
				rr = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) / s.r
			end
		end
		deep = 56
	end
	rr = math.clamp(rr, 0, 1)
	local d = 16 + (1 - rr) ^ 1.15 * deep
	if rr > 0.82 then
		d += (n2(math.abs(x), z, 7.7, 0.09) + 0.5) * 28
	end
	d = math.max(8, math.floor(d / 16 + 0.5) * 16)
	return if onTerrace(x, z) then d + TERRACE_Y else d
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -288,
	x1 = 288,
	z0 = -240,
	z1 = 200,
	cell = 8,
	shape = function(x, z)
		return isleOf(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_white_stone_bricks",
	rockTopTint = PEARL,
	rockLow = "px_smooth_stone",
	rockLowTint = Color3.fromRGB(238, 236, 228),
}, core)
task.wait()

-- ================================================================ the parade square of smooth sandstone
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(226, 216, 190),
	rim = "px_cut_sandstone",
	rimTint = SAND,
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_cut_sandstone")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, -math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(245, 205, 60),
		colB = Color3.fromRGB(250, 248, 240),
		goods = { "px_sandstone", "px_gold_block", "px_cut_sandstone" },
		sign = "Скупка",
	}, arrive)
	buyer(
		cf * CFrame.new(0, 3, 1.4),
		{ shirt = Color3.fromRGB(250, 246, 236), pants = Color3.fromRGB(220, 180, 70) },
		arrive
	)
	crate(BUYER.x - 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x + 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x + 14, SPAWN.z + 8, "Врата", math.pi, arrive)
end

-- ================================================================ bright noon (no lighting volume), the void net, the edge walls
do
	local net = part("VoidCatch", Vector3.new(900, 10, 700), at(0, -260, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	edgeWalls(
		{ { 0, -254, 612, 4 }, { 0, 214, 612, 4 }, { -304, -20, 4, 468 }, { 304, -20, 4, 468 } },
		core
	)
end
print(("[build-gate] core: island runs %d, mine %s"):format(islandRuns, mine and mine.Name or "?"))
