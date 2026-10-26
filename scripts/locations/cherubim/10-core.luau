-- ================================================================ cherubim: the islands, the plaza, the mine, arrival
local core = folder("Core")

-- the ground of a cell: the whole top paved — a checker of gold and white quartz in 2-block squares, a gold border
-- round the pit and along the rim, white stone bricks under the rotunda (the rotunda part lays its own floor)
local function groundTop(x, z)
	if inPitArea(x, z) then
		return "px_gold_block", GOLD_DEEP, 0
	end
	if inRotunda(x, z, 8) then
		return "px_white_stone_bricks", QUARTZ, 0
	end
	if isleOf(x, z, 8) == nil then
		return "px_gold_block", GOLD_DEEP, 0 -- the rim band
	end
	local cx, cz = math.floor(x / 8), math.floor(z / 8)
	if (cx + cz) % 2 == 0 then
		return "px_gold_block", GOLD, 0
	end
	return "px_smooth_stone", QUARTZ, 0
end
-- the islands hang as white stone over gold-veined stone (16-stud steps), ragged at the rim
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local c = if isle == "main" then ISLAND elseif isle == "west" then WEST_ISLE else EAST_ISLE
	local deep = if isle == "main" then 140 else 56
	local rr = math.clamp(math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r, 0, 1)
	local d = 16 + (1 - rr) ^ 1.15 * deep
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -296,
	x1 = 296,
	z0 = -200,
	z1 = 200,
	cell = 8,
	shape = function(x, z)
		return isleOf(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_white_stone_bricks",
	rockTopTint = QUARTZ,
	rockLow = "px_smooth_stone",
	rockLowTint = Color3.fromRGB(236, 226, 196),
}, core)
task.wait()

-- ================================================================ the cloud field of snow in the middle of the rings
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_stone_bricks",
	wallTint = Color3.fromRGB(150, 150, 156),
	rim = "px_smooth_stone",
	rimTint = QUARTZ,
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_gold_block")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(236, 190, 60),
		colB = Color3.fromRGB(250, 248, 240),
		goods = { "px_smooth_stone", "px_gold_block", "px_smooth_stone" },
		sign = "Скупка",
	}, arrive)
	buyer(
		cf * CFrame.new(0, 3, 1.4),
		{ shirt = Color3.fromRGB(240, 230, 200), pants = Color3.fromRGB(200, 160, 80) },
		arrive
	)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 8, "Херувимы", math.pi, arrive)
end

-- ================================================================ the golden hour, the void net, the edge walls
-- a warm low sun over the gold (the only lighting volume of this floor)
lightingVolume("GoldenHour", 0, 100, 0, 640, 440, 440, {
	Ambient = Color3.fromRGB(170, 150, 120),
	Exposure = 0.05,
	Haze = 0.15,
	ClockTime = 17.2,
	Brightness = 2.4,
	AtmosphereColor = Color3.fromRGB(250, 220, 170),
	AtmosphereDecay = Color3.fromRGB(200, 170, 140),
}, core)
do
	local net = part("VoidCatch", Vector3.new(900, 10, 700), at(0, -260, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	edgeWalls(
		{ { 0, -214, 632, 4 }, { 0, 214, 632, 4 }, { -314, 0, 4, 428 }, { 314, 0, 4, 428 } },
		core
	)
end
print(("[build-cherubim] core: island runs %d"):format(islandRuns))
