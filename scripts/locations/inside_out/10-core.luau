-- ================================================================ inside_out: the islands, the ground, the mine, arrival
local core = folder("Core")

-- the ground of a cell: grey cobbles on the square, asphalt streets (the town part paints the yellow lines), dead
-- lawns eaten by crimson vine carpets; the mansion island overgrown, the arena island dark stone (the arena part lays
-- its cracked pattern on it), the islets half vine, half stone
local function groundTop(x, z)
	local y = groundY(x, z)
	local n = n2(x, z, 3.7, 0.05)
	local m = n2(x, z, 8.1, 0.018)
	if y == 0 then
		if inPitArea(x, z) then
			return "px_stone_bricks", COBBLE, 0
		end
		if inRect(x, z, SQUARE) then
			return if n > 0.3 then "px_cobblestone" else "px_stone_bricks", COBBLE, 0
		end
		if onStreet(x, z) then
			return "px_smooth_stone", ASPHALT, 0
		end
		if m > 0.18 or n > 0.38 then
			return "px_crimson_nylium", nil, 0 -- the vine carpet creeps over the lawns
		end
		if n < -0.32 then
			return "px_dirt", Color3.fromRGB(120, 96, 88), 0
		end
		return "px_grass_top", DEAD_GRASS, 0
	end
	if y == MANSION.y then
		if math.abs(x - MANSION.x) <= 8 and z > MANSION.z + 20 then
			return "px_stone_bricks", COBBLE, y -- the drive up to the porch
		end
		return if n > 0.05 then "px_crimson_nylium" else "px_grass_top", if n > 0.05 then nil else DEAD_GRASS, y
	end
	if y == ARENA.y then
		return "px_blackstone", Color3.fromRGB(150, 140, 146), y
	end
	return if n > 0 then "px_crimson_nylium" else "px_cobblestone", if n > 0 then nil else COBBLE, y
end
-- every island hangs as an upside-down cone of dirt and dark rock: deepest under its middle, ragged below
local function rockDepth(x, z)
	local y = groundY(x, z)
	local jag = (n2(x, z, 7.7, 0.09) + 0.5) * 22 + n2(x, z, 3.1, 0.035) * 14
	local rr, deep
	if y == 0 then
		rr = ((math.abs(x) / MAIN.rx) ^ 4 + (math.abs(z) / MAIN.rz) ^ 4) ^ 0.25
		deep = 150
	elseif y == MANSION.y then
		rr, deep = math.sqrt((x - MANSION.x) ^ 2 + (z - MANSION.z) ^ 2) / MANSION.r, 96
	elseif y == ARENA.y then
		rr, deep = math.sqrt((x - ARENA.x) ^ 2 + (z - ARENA.z) ^ 2) / ARENA.islandR, 80
	else
		local s = if x < 0 then ISLETS[1] else ISLETS[2]
		rr, deep = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) / s.r, 36
	end
	rr = math.clamp(rr, 0, 1)
	-- terraced in 16-stud steps (blocky, and equal neighbours merge into one run); ragged only near the rim
	local d = 10 + (1 - rr) ^ 1.4 * deep
	if rr > 0.82 then
		d += jag
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	pit = PIT, -- the mine hole stays open
	x0 = -240,
	x1 = 240,
	z0 = -408,
	z1 = 408,
	cell = 8,
	shape = function(x, z)
		return groundY(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_dirt",
	rockTopTint = Color3.fromRGB(150, 108, 100),
	rockLow = "px_blackstone",
	rockLowTint = ROCK_RED,
}, core)
task.wait()

-- ================================================================ the mine in the town square
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_blackstone",
	wallTint = Color3.fromRGB(120, 114, 120),
	rim = "px_stone_bricks",
	rimTint = Color3.fromRGB(120, 116, 116),
}, core)
do
	-- vines creep over the rim and hang down the pit walls (not over the four ladder shafts in the middle of each side)
	local e = PIT_HALF + B
	for i = 1, 22 do
		local side = (i % 4) + 1
		local t = rng:NextNumber(-PIT_HALF + 4, PIT_HALF - 4)
		if math.abs(t) > 2 * B + 2 then
			local x, z = PIT.x + t, PIT.z + t
			if side == 1 then
				z = PIT.z - e
			elseif side == 2 then
				z = PIT.z + e
			elseif side == 3 then
				x = PIT.x - e
			else
				x = PIT.x + e
			end
			local len = rng:NextInteger(2, 6) * B
			local inward = if side == 1 then 1 elseif side == 2 then -1 else 0
			local inwardX = if side == 3 then 1 elseif side == 4 then -1 else 0
			local vx, vz = x + inwardX * (B + 0.6), z + inward * (B + 0.6)
			decor(box("PitVine", vx - 0.5, -len, vz - 0.5, vx + 0.5, 0.2, vz + 0.5, "px_nether_wart", VINE_DARK, mine))
		end
	end
end
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_stone_bricks")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = Color3.fromRGB(190, 30, 34),
		colB = Color3.fromRGB(236, 232, 226),
		goods = { "px_hedge", "px_nether_wart", "px_hedge" },
		sign = "Скупка",
	}, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(60, 64, 90), pants = Color3.fromRGB(70, 60, 50) }, arrive)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	crate(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x + 1, 0, BUYER.z - 10, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 8, "Изнанка", math.pi, arrive)
end

-- ================================================================ the boss, the light, the ash, the void net, the edge walls
bossSpawn("vecna", ARENA.x, ARENA.y + 2, ARENA.z, ARENA.r - 8, core)
-- a dark red dusk over the whole floor (the only lighting volume of this floor): red haze from below, readable
lightingVolume("UpsideDownAir", 0, 60, 0, 900, 640, 1120, {
	Ambient = Color3.fromRGB(150, 104, 104),
	Exposure = -0.15,
	Haze = 0.3,
	ClockTime = 18.4,
	Brightness = 1.3,
	AtmosphereColor = Color3.fromRGB(190, 70, 64),
	AtmosphereDecay = Color3.fromRGB(96, 24, 32),
}, core)
do
	-- ash drifting down over the town and the arena
	for _, a in ipairs({ { 0, 0, 440, 400 }, { 0, 320, 160, 160 }, { 0, -330, 140, 140 } }) do
		local p = decor(part("AshFall", Vector3.new(a[3], 1, a[4]), at(a[1], 90, a[2]), nil, nil, core))
		p.Transparency = 1
		emitter(p, {
			Rate = math.floor(a[3] * a[4] / 4000),
			Lifetime = NumberRange.new(14, 20),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(25, 25),
			EmissionDirection = Enum.NormalId.Bottom,
			Size = NumberSequence.new(0.25),
			Color = ColorSequence.new(ASH),
			LightEmission = 0.2,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.2), NumberSequenceKeypoint.new(0.9, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			RotSpeed = NumberRange.new(-40, 40),
			Rotation = NumberRange.new(0, 360),
		})
	end
end
do
	local net = part("VoidCatch", Vector3.new(1100, 10, 1300), at(0, -260, 0), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	-- one box round everything: the gaps between the islands are open void (a fall goes back to the arrival)
	local EX, EZ = 256, 424
	edgeWalls({ { 0, -EZ, 2 * EX, 4 }, { 0, EZ, 2 * EX, 4 }, { -EX, 0, 4, 2 * EZ }, { EX, 0, 4, 2 * EZ } }, core)
end
print(("[build-inside-out] core: island runs %d"):format(islandRuns))
