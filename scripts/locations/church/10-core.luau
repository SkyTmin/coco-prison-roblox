-- ================================================================ church: the islands, the ground, the mine, arrival
local core = folder("Core")

-- the ground of a cell: the paved square (smooth white stone with stone brick patches and a darker border), stone
-- bricks under the cathedral and the tower (the church part lays the nave floor on its plinth), grass with moss and
-- dirt patches round the graves elsewhere
local function groundTop(x, z)
	local n = n2(x, z, 3.3, 0.05)
	if inPitArea(x, z) then
		return "px_stone_bricks", GREY_STONE, 0
	end
	if inChurch(x, z, 8) or inTower(x, z, 8) or inRect(x, z, STEPS) then
		return "px_white_stone_bricks", WHITE_STONE, 0
	end
	if onPath(x, z) then
		local edge = not onPath(x, z, -8)
		if edge then
			return "px_stone_bricks", GREY_STONE, 0
		end
		return if n > 0.3 then "px_stone_bricks" else "px_smooth_stone", WHITE_STONE, 0
	end
	if n > 0.36 then
		return "px_mossy_cobblestone", nil, 0
	end
	if n < -0.38 then
		return "px_dirt", nil, 0
	end
	return "px_grass_top", GRASS, 0
end
-- the islands hang as tall blocks of white stone (16-stud steps), ragged near the rim
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local rr, deep
	if isle == "main" then
		rr = math.sqrt(((x - ISLAND.x) / ISLAND.rx) ^ 2 + ((z - ISLAND.z) / ISLAND.rz) ^ 2)
		deep = 150
	else
		local c = if isle == "west" then WEST_ISLE else EAST_ISLE
		rr = math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r
		deep = 56
	end
	rr = math.clamp(rr, 0, 1)
	local d = 16 + (1 - rr) ^ 1.2 * deep
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -312,
	x1 = 312,
	z0 = -248,
	z1 = 232,
	cell = 8,
	shape = function(x, z)
		return isleOf(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_stone",
	rockTopTint = Color3.fromRGB(226, 226, 228),
	rockLow = "px_stone",
	rockLowTint = Color3.fromRGB(198, 200, 208),
}, core)
task.wait()

-- ================================================================ the mine of clay in the square
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_red_brick",
	rim = "px_stone_bricks",
	rimTint = GREY_STONE,
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_white_stone_bricks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, -math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = BANNER_BLUE,
		colB = Color3.fromRGB(240, 240, 236),
		goods = { "px_smooth_stone", "px_smooth_stone", "px_smooth_stone" },
		sign = "Скупка",
	}, arrive)
	buyer(
		cf * CFrame.new(0, 3, 1.4),
		{ shirt = Color3.fromRGB(40, 60, 130), pants = Color3.fromRGB(60, 60, 70) },
		arrive
	)
	crate(BUYER.x - 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x + 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x + 14, SPAWN.z + 8, "Церковь", math.pi, arrive)
end

-- ================================================================ the void net, the edge walls (noon: no lighting volume)
do
	local net = part("VoidCatch", Vector3.new(900, 10, 800), at(0, -260, -8), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	-- one box round the whole cluster: the gaps between the islands are open sky (a fall goes back to the arrival)
	edgeWalls(
		{ { 0, -262, 648, 4 }, { 0, 246, 648, 4 }, { -326, -8, 4, 512 }, { 326, -8, 4, 512 } },
		core
	)
end
print(("[build-church] core: island runs %d"):format(islandRuns))
