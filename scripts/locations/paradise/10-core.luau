-- ================================================================ paradise: the islands, the tiers, the river, the mine, arrival
local core = folder("Core")

-- the ground of a cell: the tiers alternate white concrete and quartz, the crown calcite, the river bed gold, the plaza
-- a white checker of concrete and quartz bricks, a quartz band along the rim; the islets white
local function groundTop(x, z)
	local isle = isleOf(x, z)
	local cx, cz = math.floor(x / 8), math.floor(z / 8)
	local even = (cx + cz) % 2 == 0
	if isle ~= "main" then
		return "px_smooth_stone", if even then WHITE else SNOW, 0
	end
	if onRiver(x, z) then
		return "px_gold_block", GOLD, RIVER_BED
	end
	local k = tierOf(x, z)
	if k == 6 then
		return "px_smooth_stone", CALCITE, k * ROSE.step
	end
	if k > 0 then
		return if k % 2 == 1 then "px_smooth_stone" else "px_white_stone_bricks",
			if k % 2 == 1 then WHITE else QUARTZ,
			k * ROSE.step
	end
	if inPitArea(x, z) then
		return "px_white_stone_bricks", QUARTZ, 0
	end
	if isleOf(x, z, 8) == nil then
		return "px_white_stone_bricks", QUARTZ, 0 -- the rim band
	end
	return if even then "px_smooth_stone" else "px_white_stone_bricks",
		if even then WHITE else QUARTZ,
		0
end
-- the islands hang as white stone over snow-white stone (16-stud steps), ragged at the rim; a tier's column reaches
-- the same bottom as the plaza round it
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local rr, deep
	if isle == "main" then
		rr = math.sqrt((x - ISLAND.x) ^ 2 + (z - ISLAND.z) ^ 2) / ISLAND.r
		deep = 160
	else
		for _, s in ipairs(ISLES) do
			if s.name == isle then
				rr = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) / s.r
			end
		end
		deep = 60
	end
	rr = math.clamp(rr, 0, 1)
	local d = 16 + (1 - rr) ^ 1.15 * deep
	if rr > 0.82 then
		d += (n2(math.abs(x), z, 7.7, 0.09) + 0.5) * 28
	end
	d = math.max(8, math.floor(d / 16 + 0.5) * 16)
	return d + (groundY(x, z) or 0)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -352,
	x1 = 352,
	z0 = -248,
	z1 = 248,
	cell = 8,
	shape = function(x, z)
		return isleOf(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_white_stone_bricks",
	rockTopTint = QUARTZ,
	rockLow = "px_smooth_stone",
	rockLowTint = SNOW,
}, core)
task.wait()

-- ================================================================ the golden river under yellow glass (walked on)
do
	local riverF = folder("GoldenRiver", core)
	local runs = 0
	for z = -248, 240, 8 do
		local runStart = nil
		local function flush(xEnd)
			if runStart then
				local w = part(
					"RiverWater",
					Vector3.new(xEnd - runStart, RIVER_TOP - RIVER_BED, 8),
					at((runStart + xEnd) / 2, (RIVER_BED + RIVER_TOP) / 2, z + 4),
					GOLD_WATER,
					Enum.Material.Glass,
					riverF
				)
				w.Transparency = 0.25
				w.CanCollide = false
				w.CastShadow = false
				local g = part(
					"RiverGlass",
					Vector3.new(xEnd - runStart, 0.4, 8),
					at((runStart + xEnd) / 2, GLASS_TOP - 0.2, z + 4),
					GOLD_GLASS,
					Enum.Material.Glass,
					riverF
				)
				g.Transparency = 0.45
				g.CastShadow = false
				runs += 1
			end
			runStart = nil
		end
		for x = -352, 344, 8 do
			local cx, cz = x + 4, z + 4
			if isleOf(cx, cz) == "main" and onRiver(cx, cz) then
				runStart = runStart or x
			else
				flush(x)
			end
		end
		flush(352)
	end
	print(("[build-paradise] core: river runs %d"):format(runs))
end

-- ================================================================ the scarlet heart: the mine of red mushroom blocks
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_white_stone_bricks",
	wallTint = Color3.fromRGB(226, 224, 218),
	rim = "px_smooth_stone",
	rimTint = WHITE,
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_white_stone_bricks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, -math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(245, 205, 60),
		colB = Color3.fromRGB(252, 250, 244),
		goods = { "px_smooth_stone", "px_gold_block", "px_white_stone_bricks" },
		sign = "Скупка",
	}, arrive)
	buyer(
		cf * CFrame.new(0, 3, 1.4),
		{ shirt = Color3.fromRGB(252, 250, 244), pants = Color3.fromRGB(220, 180, 70) },
		arrive
	)
	crate(BUYER.x - 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x + 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x + 14, SPAWN.z + 8, "Рай", math.pi, arrive)
end

-- ================================================================ the brightest light, the void net, the edge walls
-- a pure white glow (the only lighting volume of this floor)
-- (Studio 26.10: at exposure 0.3, brightness 3 and a noon sun the white tiers burned into one spot and the scarlet
-- mine read pink — a lower morning sun gives the tiers shaded sides, the white stays the brightest of all floors)
lightingVolume("HeavenGlow", 0, 100, 0, 720, 520, 520, {
	Ambient = Color3.fromRGB(170, 170, 178),
	Exposure = -0.1,
	Haze = 0.6,
	ClockTime = 10.6,
	Brightness = 2.2,
	AtmosphereColor = Color3.fromRGB(250, 248, 240),
	AtmosphereDecay = Color3.fromRGB(235, 230, 220),
}, core)
do
	local net = part("VoidCatch", Vector3.new(1000, 10, 800), at(0, -280, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	edgeWalls(
		{ { 0, -262, 740, 4 }, { 0, 262, 740, 4 }, { -368, 0, 4, 524 }, { 368, 0, 4, 524 } },
		core
	)
end
print(
	("[build-paradise] core: island runs %d, mine %s"):format(islandRuns, mine and mine.Name or "?")
)
