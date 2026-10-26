-- ================================================================ tree: the islands, the ground, the mine, arrival
local core = folder("Core")

-- the ground of a cell: a plank boardwalk round the pit, coarse dirt paths with plank patches, rooty forest floor
-- round the trunk (the tree part raises the roots on it), meadow grass with moss and forest floor patches elsewhere
local function groundTop(x, z)
	local n = n2(x, z, 3.3, 0.05)
	if inPitArea(x, z) then
		return "px_mossy_stone_bricks", nil, 0
	end
	if onRing(x, z) then
		return "px_planks", nil, 0
	end
	if onPath(x, z) then
		return if n > 0.3 then "px_planks" else "px_dirt", if n > 0.3 then nil else COARSE, 0
	end
	if inTrunk(x, z, 20) then
		return if n > 0 then "px_forest_floor" else "px_dirt", if n > 0 then nil else COARSE, 0
	end
	if n > 0.36 then
		return "px_forest_floor", nil, 0
	end
	if n < -0.34 then
		return "px_grass_top", MOSS, 0
	end
	return "px_grass_top", if n > 0.1 then GRASS_DEEP else GRASS, 0
end
-- every island hangs as a ball of earth over stone (16-stud steps), deepest under the tree, ragged near the rim
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local c = if isle == "west" then WEST elseif isle == "central" then CENTRAL else EAST
	local deep = if isle == "central" then 150 elseif isle == "west" then 120 else 80
	local rr = math.clamp(math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r, 0, 1)
	local d = 12 + (1 - rr) ^ 1.25 * deep
	if rr > 0.8 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 24
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -296,
	x1 = 328,
	z0 = -152,
	z1 = 176,
	cell = 8,
	shape = function(x, z)
		return isleOf(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_dirt",
	rockTopTint = Color3.fromRGB(134, 96, 66),
	rockLow = "px_stone",
	rockLowTint = Color3.fromRGB(150, 146, 140),
}, core)
task.wait()

-- ================================================================ the mine of white concrete on the west island
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(150, 148, 144),
	rim = "px_mossy_stone_bricks",
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_planks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(70, 140, 50),
		colB = Color3.fromRGB(236, 236, 226),
		goods = { "px_smooth_stone", "px_smooth_stone", "px_smooth_stone" },
		sign = "Скупка",
	}, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(70, 110, 50), pants = Color3.fromRGB(90, 70, 50) }, arrive)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	lampPost(BUYER.x - 10, BUYER.z - 6, arrive)
	zoneSign(SPAWN.x + 12, SPAWN.z - 16, "Древо", -math.pi / 2, arrive)
end

-- ================================================================ the morning, the void net, the edge walls
-- an early morning over the clouds (the only lighting volume of this floor): low warm sun, a light sky-blue haze
lightingVolume("SkyMorning", 16, 100, 12, 660, 520, 360, {
	Ambient = Color3.fromRGB(150, 150, 140),
	Exposure = 0.05,
	Haze = 0.12,
	ClockTime = 7.6,
	Brightness = 2.2,
	AtmosphereColor = Color3.fromRGB(196, 220, 240),
	AtmosphereDecay = Color3.fromRGB(150, 170, 200),
}, core)
do
	local net = part("VoidCatch", Vector3.new(900, 10, 700), at(16, -260, 12), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	-- one box round the whole cluster: the gaps between the islands are open sky (a fall goes back to the arrival)
	edgeWalls({ { 16, -166, 648, 4 }, { 16, 190, 648, 4 }, { -310, 12, 4, 360 }, { 342, 12, 4, 360 } }, core)
end
print(("[build-tree] core: island runs %d"):format(islandRuns))
