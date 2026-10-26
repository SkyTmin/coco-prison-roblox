-- ================================================================ edge_gate: the islands, the ground, the mine, arrival
local core = folder("Core")

-- the ground of a cell: end stone bricks on the paths and round the pit, obsidian under the arena (the gate part lays
-- the runes on it), end stone bricks round the gate, bare end stone with purpur-grey patches elsewhere
local function groundTop(x, z)
	local y = groundY(x, z)
	local n = n2(x, z, 3.5, 0.05)
	local isle = isleOf(x, z)
	if isle == "arena" then
		if inArena(x, z, 4) then
			return "px_obsidian", nil, y
		end
		return if n > 0.3 then "px_end_stone" else "px_end_stone_bricks", nil, y
	end
	if isle == "main" and (inPitArea(x, z) or onPath(x, z)) then
		return "px_end_stone_bricks", nil, 0
	end
	if n > 0.38 then
		return "px_end_stone", Color3.fromRGB(200, 190, 200), 0 -- a cold purple-grey patch
	end
	return "px_end_stone", nil, 0
end
-- every island hangs as a cone of end stone over purpur (the isles part hangs purpur stalactites under it)
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local rr, deep
	if isle == "main" then
		rr = math.sqrt(((x - MAIN.x) / MAIN.rx) ^ 2 + ((z - MAIN.z) / MAIN.rz) ^ 2)
		deep = 120
	else
		local c = if isle == "arena" then ARENA_ISLE elseif isle == "west" then WEST else EAST
		rr = math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r
		deep = if isle == "arena" then 96 else 64
	end
	rr = math.clamp(rr, 0, 1)
	local d = 12 + (1 - rr) ^ 1.3 * deep
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 20
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local _, islandRuns = island({
	x0 = -296,
	x1 = 280,
	z0 = -256,
	z1 = 240,
	cell = 8,
	shape = function(x, z)
		return isleOf(x, z) ~= nil
	end,
	top = groundTop,
	depth = rockDepth,
	rockTop = "px_end_stone",
	rockTopTint = Color3.fromRGB(214, 212, 180),
	rockLow = "px_purpur",
	rockLowTint = Color3.fromRGB(190, 160, 190),
}, core)
task.wait()

-- ================================================================ the mine on the main island
local mine = minePit({
	x = PIT.x,
	z = PIT.z,
	size = PIT.size,
	depth = PIT.depth,
	wall = "px_end_stone_bricks",
	wallTint = Color3.fromRGB(210, 206, 180),
	rim = "px_purpur",
	rimTint = PURPUR,
}, core)
local arrive = folder("Arrival", core)
arrival(SPAWN.x, SPAWN.z, PIT.x, PIT.z, arrive, "px_purpur")
do
	local cf = at(BUYER.x, 0, BUYER.z) * CFrame.Angles(0, math.pi / 2, 0)
	stall(cf, {
		w = 4 * B,
		d = 2 * B,
		colA = MAGENTA,
		colB = Color3.fromRGB(40, 32, 52),
		goods = { "px_purpur", "px_obsidian", "px_purpur" },
		sign = "Скупка",
	}, arrive)
	buyer(cf * CFrame.new(0, 3, 1.4), { shirt = Color3.fromRGB(60, 40, 90), pants = Color3.fromRGB(30, 26, 40) }, arrive)
	crate(BUYER.x + 4, 0, BUYER.z + 10, arrive)
	barrel(BUYER.x - 2, 0, BUYER.z + 10, arrive)
	zoneSign(SPAWN.x - 14, SPAWN.z + 8, "Врата края", math.pi, arrive)
end

-- ================================================================ the boss, the night, the void net, the edge walls
bossSpawn("reaper", ARENA.x, ARENA.y + 2, ARENA.z, ARENA.r - 8, core)
-- the End has no day: a quiet night over the void (the only lighting volume of this floor, as in Пустотная крепость)
lightingVolume("EndNight", -8, 60, -8, 640, 400, 560, {
	Ambient = Color3.fromRGB(140, 122, 160),
	Exposure = -0.05,
	Haze = 0.28,
	ClockTime = 0,
	Brightness = 1,
	AtmosphereColor = Color3.fromRGB(50, 32, 72),
	AtmosphereDecay = Color3.fromRGB(24, 14, 38),
}, core)
do
	local net = part("VoidCatch", Vector3.new(900, 10, 800), at(-8, -240, -8), nil, nil, core)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", LOC)
	CollectionService:AddTag(net, "VoidCatch")
	-- one box round the whole cluster: the gaps between the islands are open void (a fall goes back to the arrival)
	edgeWalls({ { -8, -268, 616, 4 }, { -8, 252, 616, 4 }, { -312, -8, 4, 520 }, { 296, -8, 4, 520 } }, core)
end
print(("[build-edge-gate] core: island runs %d"):format(islandRuns))
