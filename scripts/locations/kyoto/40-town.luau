--!nocheck
-- ================================================================ kyoto: the lower town (the square, the shops, the lower town, cherry trees, the rim)
-- The TOWN zone (zoneOf == "town": L0 z ≥ -8 outside the temple zone), as in the concept (assets/concepts/kyoto/
-- concept-v2.webp, top panels): the cobbled square round the pink mine with small dark-wood shop houses, stone lanterns
-- and cherry trees everywhere, petals on the ground, grey island cliffs with pink and green leaf curtains.
--   pit fence   dark wood rails between stone posts: W x -100, E x 52, S z 164 (one block outside the pit area), N z 21.6
--               (on the north rim band, so the way along it to the main stair foot stays 3 blocks wide); open at the
--               four ladder shafts: x -36..-12 (N, S) and z 76..100 (W, E), each opening flanked by two stone lanterns
--   shops       12 machiya (two storeys, open shop front, noren, counter, goods): the west row (fronts on x -120 facing
--               east, z 52..164), the south-west row (fronts on z 180 facing north, x -94..-46), one south-east of the
--               buyer (x 26..42), the east row across the main way (fronts on x 76 facing west, z 76..148)
--   lanes       the main way north x 48..76 (z -8..200), the west lane x -120..-100, the south lane z 164..180, the
--               arrival (r 16), the buyer and the zone sign stay clear; gravel paths: P1 the square → the west stair
--               foot (z 34..42, x -178..-120, then north to z 28), P2 north-south x -150..-144 (z 42..140), the shrine
--               approach z 68..72, the east path z 96..104 (x 76..150)
--   lower town  the shrine (hall x -198..-174, z 58..82 facing east; torii at x -164; fox statues at x -170), a well,
--               a vegetable plot, two cottages on P2, three in the east lowland (a thatched one, a tiled one, a kura),
--               carts and hay, stone lanterns along the paths
--   trees       ~40 cherry trees on free town ground (stepped pink crowns, petal carpets), a few designated in the square
--   rim         a low stone kerb along the south and west edge with gaps at three view points (benches at the south
--               one), leaf curtains hanging 0.6 stud off the cliff face, small trees leaning over the edge; bamboo
--               clumps under the west cliff
local town = folder("Town")
local startCount = count
local TF = {
	fence = folder("PitFence", town),
	shops = folder("ShopHouses", town),
	lower = folder("LowerTown", town),
	shrine = folder("Shrine", town),
	paths = folder("Paths", town),
	trees = folder("CherryTrees", town),
	rim = folder("Rim", town),
	bamboo = folder("Bamboo", town),
	life = folder("Townsfolk", town),
}
local ST = {
	shops = 0,
	houses = 0,
	trees = 0,
	npcs = 0,
	lights = 0,
	skipped = 0,
	bamboo = 0,
	kerb = 0,
	curtains = 0,
}
local TC = {
	indigo = Color3.fromRGB(46, 58, 116),
	white = Color3.fromRGB(240, 238, 232),
	ridge = Color3.fromRGB(38, 36, 42),
	glow = Color3.fromRGB(255, 196, 120),
	gravel = Color3.fromRGB(184, 180, 170),
	thatch = Color3.fromRGB(200, 170, 112),
	tea = Color3.fromRGB(96, 150, 70),
	matcha = Color3.fromRGB(150, 196, 110),
	crate = Color3.fromRGB(215, 175, 120),
	barrel = Color3.fromRGB(150, 110, 80),
	bamboo = Color3.fromRGB(160, 214, 110),
	bambooDark = Color3.fromRGB(120, 176, 84),
	leafGreen = Color3.fromRGB(120, 170, 90),
	foxStone = Color3.fromRGB(196, 194, 188),
	crop = Color3.fromRGB(110, 170, 70),
	cabbage = Color3.fromRGB(170, 210, 130),
	carrot = Color3.fromRGB(230, 130, 40),
	water = Color3.fromRGB(70, 130, 170),
	skins = {
		Color3.fromRGB(234, 200, 170),
		Color3.fromRGB(220, 180, 150),
		Color3.fromRGB(200, 160, 124),
	},
}

-- ================================================================ helpers
local U = {}
-- a textured box in a frame cf (a world CFrame) by two local corners
function U.lbox(name, cf, x0, y0, z0, x1, y1, z1, variant, tint, parent, isDecor)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(
		name,
		size,
		cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		tint,
		nil,
		parent
	)
	if variant then
		textured(p, variant, tint)
	end
	if isDecor then
		decor(p)
	end
	return p
end
-- a frame on the ground at local (x, z) whose −Z (the front) looks along (fx, fz); the body lies toward +Z
function U.faceCF(x, z, fx, fz, y)
	local p = V(x, y or 0, z)
	return CFrame.lookAt(p, p + Vector3.new(fx, 0, fz))
end
-- the floor-local coordinates of a point given in a frame
function U.loc(cf, x, y, z)
	local p = (cf * CFrame.new(x, y, z)).Position
	return p.X - BX, p.Y - BY, p.Z - BZ
end
-- a warm point light while the budget lasts (≤ 24 in this part)
function U.glow(p, range, bright)
	if ST.lights >= 24 then
		return nil
	end
	ST.lights += 1
	return light(p, range or 26, bright or 1.2, TC.glow)
end
function U.petals(x0, z0, x1, z1, deep, f)
	decor(
		box(
			"Petals",
			x0,
			0.04,
			z0,
			x1,
			0.34,
			z1,
			"px_white_wool",
			if deep then SAKURA_DEEP else SAKURA,
			f
		)
	)
end
function U.gravel(x0, z0, x1, z1)
	decor(box("GravelPath", x0, 0, z0, x1, 0.12, z1, "px_gravel", TC.gravel, TF.paths))
end
-- the rectangle of a building whose front centre is (x, z) facing (fx, fz): w across, d back, ef in front
function U.rect(x, z, fx, fz, w, d, ef)
	ef = ef or 0
	local ax, az = x + fx * ef, z + fz * ef
	local bx, bz = x - fx * d, z - fz * d
	if fx ~= 0 then
		return math.min(ax, bx), z - w / 2, math.max(ax, bx), z + w / 2
	end
	return x - w / 2, math.min(az, bz), x + w / 2, math.max(az, bz)
end

-- ================================================================ footprints: lanes, keep-outs, buildings
-- kinds: "lane" (walk ways: nothing stands on them), "keep" (the arrival, the buyer, the sign), "solid" (a building
-- or a prop on the ground), "roof" (eaves overhead: trees keep their crowns off them)
local CL = { list = {} }
function CL.add(x0, z0, x1, z1, kind)
	table.insert(
		CL.list,
		{ math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1), kind }
	)
end
function CL.hit(x0, z0, x1, z1, kinds)
	for _, c in ipairs(CL.list) do
		if
			(not kinds or kinds[c[5]])
			and x0 < c[3] - 0.01
			and x1 > c[1] + 0.01
			and z0 < c[4] - 0.01
			and z1 > c[2] + 0.01
		then
			return true
		end
	end
	return false
end
-- every 4 studs of the rectangle: L0 town ground on the island (pad 10), off the pit, the stairs and the pond
function CL.ground(x0, z0, x1, z1)
	local nx, nz = math.max(1, math.ceil((x1 - x0) / 4)), math.max(1, math.ceil((z1 - z0) / 4))
	for i = 0, nx do
		for j = 0, nz do
			local x = x0 + (x1 - x0) * i / nx
			local z = z0 + (z1 - z0) * j / nz
			if
				not onIsland(x, z, 10)
				or groundY(x, z) ~= 0
				or zoneOf(x, z) ~= "town"
				or inPitArea(x, z, 2)
				or inStairCorridor(x, z)
				or inPond(x, z, 4)
			then
				return false
			end
		end
	end
	return true
end
function CL.take(x0, z0, x1, z1, kind)
	if x1 < x0 then
		x0, x1 = x1, x0
	end
	if z1 < z0 then
		z0, z1 = z1, z0
	end
	if CL.hit(x0, z0, x1, z1) or not CL.ground(x0, z0, x1, z1) then
		ST.skipped += 1
		return false
	end
	CL.add(x0, z0, x1, z1, kind or "solid")
	return true
end
do
	CL.add(SPAWN.x - 16, SPAWN.z - 16, SPAWN.x + 16, SPAWN.z + 16, "keep")
	CL.add(-4, 172, 20, 200, "keep") -- the buyer's stall, barrel and crate
	CL.add(-42, 186, -34, 194, "keep") -- the zone sign
	CL.add(48, -8, 76, 200, "lane") -- the main way north to the main stair foot
	CL.add(-120, 0, -100, 180, "lane") -- the west lane between the shops and the pit fence
	CL.add(-120, 164, 72, 180, "lane") -- the south lane
	CL.add(-100, 12, 20, 21, "lane") -- along the north fence
	CL.add(-178, 34, -120, 42, "lane") -- P1 to the west stair
	CL.add(-178, 26, -166, 34, "lane")
	CL.add(-150, 42, -144, 140, "lane") -- P2
	CL.add(-176, 68, -150, 72, "lane") -- the shrine approach
	CL.add(76, 92, 150, 108, "lane") -- the east path
end

-- ================================================================ block props
local P = { posts = {} }
-- a stone lantern (tōrō, the concept close-up): base, pillar, tray, a fire box of four posts round a paper (or lit)
-- core, a wide cap with raised tips, a top block and a finial; ≈ 12.7 studs tall, a 1-block footprint
function P.stoneLantern(x, z, f, lit)
	cube("LanternBase", x, 0.75, z, 4, 1.5, 4, "px_stone_bricks", STONE, f)
	cube("LanternPillar", x, 3.5, z, 2.4, 4, 2.4, "px_smooth_stone", STONE, f)
	cube("LanternTray", x, 6, z, 4.4, 1, 4.4, "px_stone_bricks", STONE, f)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		cube(
			"LanternFrame",
			x + s[1] * 1.6,
			8,
			z + s[2] * 1.6,
			0.9,
			3,
			0.9,
			"px_smooth_stone",
			STONE,
			f
		)
		decor(
			cube(
				"LanternTip",
				x + s[1] * 2.3,
				10.9,
				z + s[2] * 2.3,
				1,
				0.8,
				1,
				"px_smooth_stone",
				STONE,
				f
			)
		)
	end
	local core = decor(cube("LanternLight", x, 8, z, 2.4, 2.4, 2.4, "px_white_wool", PAPER, f))
	if lit then
		core.Material = Enum.Material.Neon
		core.MaterialVariant = ""
		core.Color = TC.glow
		U.glow(core, 28, 1.3)
	end
	cube("LanternRoof", x, 10, z, 5.6, 1, 5.6, "px_stone_bricks", STONE, f)
	cube("LanternTop", x, 11, z, 3, 1, 3, "px_smooth_stone", STONE, f)
	decor(cube("LanternFinial", x, 12.1, z, 1.2, 1.2, 1.2, "px_smooth_stone", STONE, f))
end
-- a fence run (increasing x or z): stone posts every 3–4 blocks, two dark wood rails, a baluster in each span
function P.fenceRun(ax, az, bx, bz, f)
	local len = math.abs(bx - ax) + math.abs(bz - az)
	local n = math.max(1, math.floor(len / 14 + 0.5))
	local alongX = bx ~= ax
	for i = 0, n do
		local px, pz = ax + (bx - ax) * i / n, az + (bz - az) * i / n
		local key = ("%.1f:%.1f"):format(px, pz)
		if not P.posts[key] then
			P.posts[key] = true
			cube("FencePost", px, 2.3, pz, 2, 4.6, 2, "px_stone_bricks", STONE, f)
			cube("FenceCap", px, 4.9, pz, 2.8, 0.6, 2.8, "px_smooth_stone", STONE, f)
		end
	end
	for i = 1, n do
		local x0, z0 = ax + (bx - ax) * (i - 1) / n, az + (bz - az) * (i - 1) / n
		local x1, z1 = ax + (bx - ax) * i / n, az + (bz - az) * i / n
		for _, h in ipairs({ 1.6, 3.4 }) do
			if alongX then
				box(
					"FenceRail",
					x0 + 1,
					h - 0.4,
					z0 - 0.4,
					x1 - 1,
					h + 0.4,
					z0 + 0.4,
					"px_dark_oak_planks",
					nil,
					f
				)
			else
				box(
					"FenceRail",
					x0 - 0.4,
					h - 0.4,
					z0 + 1,
					x0 + 0.4,
					h + 0.4,
					z1 - 1,
					"px_dark_oak_planks",
					nil,
					f
				)
			end
		end
		cube(
			"FenceBaluster",
			(x0 + x1) / 2,
			2,
			(z0 + z1) / 2,
			1,
			4,
			1,
			"px_dark_oak_planks",
			nil,
			f
		)
	end
end
-- a stone fox (kitsune) on a plinth with a red bib, facing (fx, fz)
function P.fox(x, z, fx, fz, f)
	local cf = U.faceCF(x, z, fx, fz)
	local L, S, C = U.lbox, "px_smooth_stone", TC.foxStone
	L("FoxPlinth", cf, -2.4, 0, -2.4, 2.4, 3, 2.4, "px_stone_bricks", STONE, f)
	L("FoxPlinthTop", cf, -2.8, 3, -2.8, 2.8, 3.6, 2.8, S, STONE, f)
	L("FoxBody", cf, -1.4, 3.6, -0.6, 1.4, 6.4, 2.4, S, C, f)
	L("FoxChest", cf, -1.1, 3.6, -1.6, 1.1, 7.8, 0.2, S, C, f)
	L("FoxHead", cf, -1.3, 7.8, -2, 1.3, 10, 0.4, S, C, f)
	L("FoxSnout", cf, -0.6, 8, -3.2, 0.6, 9, -2, S, C, f, true)
	for _, sx in ipairs({ -1, 1 }) do
		L("FoxEar", cf, sx * 0.4, 10, -1.2, sx * 1.3, 11.4, -0.4, S, C, f, true)
	end
	L("FoxTail", cf, -0.6, 4, 2.4, 0.6, 9.4, 3.4, S, C, f, true)
	L("FoxBib", cf, -1.3, 6.6, -1.9, 1.3, 7.8, -1.6, "px_white_wool", TORII_RED, f, true)
	L("FoxBib", cf, -0.7, 5.8, -1.85, 0.7, 6.6, -1.6, "px_white_wool", TORII_RED, f, true)
end
-- a torii over a path running along (fx, fz) at (cx, cz): posts span apart, kasagi at height h
function P.torii(cx, cz, fx, fz, span, h, f)
	local cf = U.faceCF(cx, cz, fx, fz)
	local L, RED, hs = U.lbox, TORII_RED, span / 2
	for _, sx in ipairs({ -1, 1 }) do
		L("ToriiPost", cf, sx * hs - 1, 1.6, -1, sx * hs + 1, h, 1, "px_white_wool", RED, f)
		L(
			"ToriiFoot",
			cf,
			sx * hs - 1.3,
			0,
			-1.3,
			sx * hs + 1.3,
			1.6,
			1.3,
			"px_smooth_stone",
			ROOF_DARK,
			f
		)
		L(
			"KasagiTip",
			cf,
			sx * (hs + 4),
			h + 2,
			-1.4,
			sx * (hs + 2.6),
			h + 2.8,
			1.4,
			"px_dark_oak_planks",
			ROOF_DARK,
			f,
			true
		)
	end
	L("Nuki", cf, -hs - 2, h - 4, -0.6, hs + 2, h - 3, 0.6, "px_white_wool", RED, f)
	L("ToriiStrut", cf, -0.8, h - 3, -0.5, 0.8, h, 0.5, "px_white_wool", RED, f)
	L("Kasagi", cf, -hs - 3, h, -1.2, hs + 3, h + 1.2, 1.2, "px_white_wool", RED, f)
	L(
		"KasagiTop",
		cf,
		-hs - 4,
		h + 1.2,
		-1.4,
		hs + 4,
		h + 2,
		1.4,
		"px_dark_oak_planks",
		ROOF_DARK,
		f
	)
end
function P.hay(x, z, f, n)
	local spots = { { 0, 0, 0 }, { 4, 0, 0 }, { 0, 0, 4 }, { 2, 4, 2 } }
	for i = 1, math.min(n or 3, 4) do
		local s = spots[i]
		cube("Hay", x + s[1], s[2] + 2, z + s[3], B, B, B, "px_hay", nil, f)
	end
end
-- a hand cart with a load of hay, yaw about y
function P.cart(x, z, yaw, f)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local L, W = U.lbox, "px_spruce_planks"
	L("CartBed", cf, -4, 2.6, -2.4, 4, 3.4, 2.4, W, nil, f)
	for _, sz in ipairs({ -1, 1 }) do
		L("CartSide", cf, -4, 3.4, sz * 2.4, 4, 4.6, sz * 1.8, W, nil, f)
		L("CartWheel", cf, -1.8, 0, sz * 2.4, 1.8, 3.6, sz * 3, "px_dark_oak_planks", nil, f)
		L(
			"CartHub",
			cf,
			-0.5,
			1.3,
			sz * 3,
			0.5,
			2.3,
			sz * 3.3,
			"px_smooth_stone",
			ROOF_DARK,
			f,
			true
		)
		L(
			"CartShaft",
			cf,
			4,
			2.7,
			sz * 1.6 - 0.3,
			9,
			3.3,
			sz * 1.6 + 0.3,
			"px_dark_oak_planks",
			nil,
			f,
			true
		)
	end
	L("CartLoad", cf, -3.6, 3.4, -1.8, 0, 6.6, 1.8, "px_hay", nil, f, true)
	L("CartLoad", cf, 0, 3.4, -1.8, 3.4, 5.8, 1.8, "px_hay", nil, f, true)
end
-- a bench facing (fx, fz)
function P.bench(x, z, fx, fz, f)
	local cf = U.faceCF(x, z, fx, fz)
	local L = U.lbox
	for _, sx in ipairs({ -1, 1 }) do
		L("BenchLeg", cf, sx * 4, 0, -1.2, sx * 2.8, 1.8, 1.2, "px_stone_bricks", STONE, f)
	end
	L("BenchSeat", cf, -4.4, 1.8, -1.4, 4.4, 2.4, 1.4, "px_spruce_planks", nil, f)
	L("BenchBack", cf, -4.4, 2.4, 1, 4.4, 4.4, 1.5, "px_spruce_planks", nil, f)
end

-- ================================================================ the fence round the pit, the stone lanterns at the ladder openings
do
	local f = TF.fence
	local W, E, S, N = -100, 52, 164, 21.6
	P.fenceRun(W, N, -42, N, f)
	P.fenceRun(-6, N, E, N, f)
	P.fenceRun(W, S, -42, S, f)
	P.fenceRun(-6, S, E, S, f)
	P.fenceRun(W, N, W, 70, f)
	P.fenceRun(W, 106, W, S, f)
	P.fenceRun(E, N, E, 70, f)
	P.fenceRun(E, 106, E, S, f)
	-- two stone lanterns flank each ladder opening, the first of each pair lit
	for _, l in ipairs({
		{ -38, N, true },
		{ -10, N, false },
		{ -38, S, true },
		{ -10, S, false },
		{ W, 74, true },
		{ W, 102, false },
		{ E, 74, false },
		{ E, 102, true },
	}) do
		P.stoneLantern(l[1], l[2], f, l[3])
	end
	-- petals drifted into the outer corners of the fence
	for _, c in ipairs({ { W, N, -1, -1 }, { E, N, 1, -1 }, { W, S, -1, 1 }, { E, S, 1, 1 } }) do
		local x, z = c[1] + c[3] * 1.2, c[2] + c[4] * 1.2
		U.petals(
			math.min(x, x + c[3] * 8),
			math.min(z, z + c[4] * 6),
			math.max(x, x + c[3] * 8),
			math.max(z, z + c[4] * 6),
			false,
			f
		)
		U.petals(
			math.min(x, x + c[3] * 4),
			math.min(z, z + c[4] * 10),
			math.max(x, x + c[3] * 4),
			math.max(z, z + c[4] * 10),
			true,
			f
		)
	end
end
task.wait()

-- ================================================================ the shop houses (machiya) and the cottages
local H = {}
local KINDS = {
	sake = {
		sign = "Саке",
		goods = {
			{ "px_white_wool", PAPER },
			{ "px_spruce_planks", TC.barrel },
			{ "px_white_wool", TC.white },
		},
	},
	rice = { sign = "Рис", goods = { { "px_hay" }, { "px_white_wool", PAPER }, { "px_hay" } } },
	tea = {
		sign = "Чай",
		goods = {
			{ "px_hedge", TC.tea },
			{ "px_planks", TC.crate },
			{ "px_white_wool", TC.matcha },
		},
	},
	lantern = {
		sign = "Фонари",
		goods = { { "px_white_wool", TORII_RED }, { "px_white_wool", PAPER } },
	},
	sweets = {
		sign = "Сладости",
		goods = {
			{ "px_white_wool", SAKURA },
			{ "px_white_wool", TC.white },
			{ "px_white_wool", TC.matcha },
		},
	},
	cloth = {
		sign = "Ткани",
		goods = {
			{ "px_white_wool", TC.indigo },
			{ "px_white_wool", TORII_RED },
			{ "px_white_wool", SAKURA },
		},
	},
}
-- the stepped dark tile roof with the ridge along local x, raised tips at the eave corners and the ridge ends
function H.roof(cf, hw, d, y, f, rv, rt, tips, fo)
	local L = U.lbox
	-- the eave runs from z -fo (over the front) to d + 2; the ridge line is its middle
	local rc = (d + 2 - fo) / 2
	local half = (d + 2 + fo) / 2
	L("Roof", cf, -hw - 2, y, rc - half, hw + 2, y + 1.5, rc + half, rv, rt, f)
	L("Roof", cf, -hw - 1, y + 1.5, rc - half + 3, hw + 1, y + 3.5, rc + half - 3, rv, rt, f)
	L("Roof", cf, -hw, y + 3.5, rc - half + 6, hw, y + 5, rc + half - 6, rv, rt, f)
	L(
		"RoofRidge",
		cf,
		-hw - 1.5,
		y + 5,
		rc - 1,
		hw + 1.5,
		y + 6.4,
		rc + 1,
		if tips then rv else "px_dark_oak_planks",
		if tips then TC.ridge else nil,
		f
	)
	if tips then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local zz = rc + sz * half
				L(
					"RoofTip",
					cf,
					sx * (hw + 2),
					y + 1.5,
					zz,
					sx * (hw + 0.4),
					y + 2.9,
					zz - sz * 1.6,
					rv,
					rt,
					f,
					true
				)
			end
			L(
				"RidgeTip",
				cf,
				sx * (hw + 1.5),
				y + 6.4,
				rc - 0.8,
				sx * (hw + 0.1),
				y + 8,
				rc + 0.8,
				rv,
				TC.ridge,
				f,
				true
			)
		end
	end
end
-- a two-storey shop house: front centre (x, z) facing (fx, fz), w across, d deep (studs); o = { kind, noren,
-- balcony, npc, look }
function H.machiya(x, z, fx, fz, w, d, o)
	local x0, z0, x1, z1 = U.rect(x, z, fx, fz, w, d)
	if not CL.take(x0, z0, x1, z1, "solid") then
		return nil
	end
	local r0, s0, r1, s1 = U.rect(x, z, fx, fz, w + 5, d + 2.5, 5)
	CL.add(r0, s0, r1, s1, "roof")
	local kind = KINDS[o.kind]
	local f = folder("Machiya_" .. o.kind, TF.shops)
	local cf = U.faceCF(x, z, fx, fz)
	local hw = w / 2
	local L, DW, DT, PV, RV =
		U.lbox, "px_dark_oak_planks", DARK_WOOD, "px_white_wool", "px_roof_tiles"
	-- the stone plinth is the shop floor
	L("Plinth", cf, -hw, 0, 0, hw, 1, d, "px_stone_bricks", STONE, f)
	-- the frame: corner posts through both storeys; side walls with a dark wainscot, paper above
	for _, sx in ipairs({ -1, 1 }) do
		for _, zz in ipairs({ 0, d - 2 }) do
			L("Post", cf, sx * hw, 1, zz, sx * (hw - 2), 16, zz + 2, DW, DT, f)
		end
		L("Wainscot", cf, sx * hw, 1, 2, sx * (hw - 1.6), 3.5, d - 2, DW, DT, f)
		L("WallLow", cf, sx * (hw - 0.2), 3.5, 2, sx * (hw - 1.6), 8.6, d - 2, PV, PAPER, f)
		L("WallUp", cf, sx * (hw - 0.2), 10, 2, sx * (hw - 1.6), 16, d - 2, PV, PAPER, f)
		L("Beam", cf, sx * hw, 8.6, 2, sx * (hw - 2), 10, d - 2, DW, DT, f)
	end
	L("Wainscot", cf, -hw + 2, 1, d - 1.6, hw - 2, 3.5, d, DW, DT, f)
	L("WallLow", cf, -hw + 2, 3.5, d - 1.6, hw - 2, 8.6, d - 0.2, PV, PAPER, f)
	L("WallUp", cf, -hw + 2, 10, d - 1.6, hw - 2, 16, d - 0.2, PV, PAPER, f)
	-- the beam ring between the storeys, the shop ceiling, the closed eave plate on top
	L("Beam", cf, -hw + 2, 8.6, 0, hw - 2, 10, 2, DW, DT, f)
	L("Beam", cf, -hw + 2, 8.6, d - 2, hw - 2, 10, d, DW, DT, f)
	L("Ceiling", cf, -hw + 2, 9, 2, hw - 2, 10, d - 2, DW, DT, f)
	L("Eave", cf, -hw, 16, 0, hw, 17, d, DW, DT, f)
	-- the upper front: paper behind a lattice of dark slats (mushiko windows), the name board above
	L("WallUp", cf, -hw + 2, 10, 0.4, hw - 2, 16, 1.8, PV, PAPER, f)
	local n = math.floor((w - 6) / 2) + 1
	for k = 0, n - 1 do
		local sx = -hw + 3.2 + k * (w - 6.4) / (n - 1)
		L("Slat", cf, sx - 0.35, 11, 0, sx + 0.35, 14.4, 0.4, DW, DT, f, true)
	end
	L("Sill", cf, -hw + 2.6, 10.6, -0.2, hw - 2.6, 11, 0.4, DW, DT, f, true)
	L("Lintel", cf, -hw + 2.6, 14.4, -0.2, hw - 2.6, 14.8, 0.4, DW, DT, f, true)
	local board =
		L("NameBoard", cf, -3.2, 14.9, -0.4, 3.2, 16, 0.4, "px_spruce_planks", nil, f, true)
	boardText(board, kind.sign, nil, { Enum.NormalId.Front })
	-- the main roof
	H.roof(cf, hw, d, 17, f, RV, ROOF_DARK, true, 2)
	-- over the shop front: a pent roof (hisashi) with raised tips, or a balcony on brackets
	if o.balcony then
		L("Balcony", cf, -hw, 9.6, -3.2, hw, 10.4, 0, DW, DT, f)
		L("BalconyRail", cf, -hw, 13, -3.2, hw, 13.6, -2.4, DW, DT, f)
		local np = math.floor(w / 4)
		for k = 0, np do
			local px = -hw + 0.4 + k * (w - 0.8) / np
			L("RailPost", cf, px - 0.4, 10.4, -3.2, px + 0.4, 13, -2.4, DW, DT, f, true)
		end
		for _, sx in ipairs({ -1, 1 }) do
			L("RailSide", cf, sx * hw, 10.4, -3.2, sx * (hw - 0.8), 13.6, 0, DW, DT, f)
			L(
				"Bracket",
				cf,
				sx * (hw - 1) - 0.5,
				8,
				-2.8,
				sx * (hw - 1) + 0.5,
				9.6,
				0,
				DW,
				DT,
				f,
				true
			)
		end
		L("RailCloth", cf, -hw / 2, 11.2, -3.45, hw / 2, 13.4, -3.2, PV, o.noren, f, true)
	else
		L("Hisashi", cf, -hw - 1, 9, -4, hw + 1, 10, -1.4, RV, ROOF_DARK, f)
		L("Hisashi", cf, -hw - 1, 10, -1.6, hw + 1, 11, 0.6, RV, ROOF_DARK, f)
		for _, sx in ipairs({ -1, 1 }) do
			L(
				"HisashiTip",
				cf,
				sx * (hw + 1),
				10,
				-4,
				sx * (hw - 0.4),
				11,
				-2.6,
				RV,
				ROOF_DARK,
				f,
				true
			)
		end
	end
	-- the noren curtain over the open front (split strips)
	local span = w - 4.8
	local nn = math.max(2, math.floor(span / 3.4))
	local sw = span / nn
	for k = 0, nn - 1 do
		local a = -hw + 2.4 + k * sw
		L("Noren", cf, a + 0.15, 5.4, -0.3, a + sw - 0.15, 8.6, 0, PV, o.noren, f, true)
	end
	-- paper lanterns at the front corners, the first one lit
	for i, sx in ipairs({ -1, 1 }) do
		local lx = sx * (hw - 2.6)
		local paper = L(
			"PaperLantern",
			cf,
			lx - 0.9,
			6.2,
			-2.1,
			lx + 0.9,
			8.4,
			-0.3,
			PV,
			if i == 1 then PAPER else TORII_RED,
			f,
			true
		)
		L("LanternCap", cf, lx - 0.6, 8.4, -1.8, lx + 0.6, 9, -0.6, DW, DT, f, true)
		L("LanternCap", cf, lx - 0.6, 5.8, -1.8, lx + 0.6, 6.2, -0.6, DW, DT, f, true)
		if i == 1 then
			U.glow(paper, 22, 1)
		end
	end
	-- the counter (the way in at the +x end), goods on it, a back shelf with more
	L("Counter", cf, -hw + 2, 1, 1.6, hw - 6, 3.8, 3.6, "px_spruce_planks", nil, f)
	L("CounterTop", cf, -hw + 1.8, 3.8, 1.4, hw - 5.8, 4.3, 3.8, DW, nil, f)
	local gx = -hw + 3.2
	while gx < hw - 7 do
		local g = pick(kind.goods)
		L("Goods", cf, gx - 0.9, 4.3, 1.7, gx + 0.9, 6.1, 3.5, g[1], g[2], f, true)
		gx += 2.4
	end
	L("Shelf", cf, -hw + 2, 5.2, d - 3.4, hw - 2, 5.7, d - 1.6, "px_spruce_planks", nil, f)
	for k = 0, 2 do
		local g = pick(kind.goods)
		L(
			"ShelfGoods",
			cf,
			-hw + 2.6 + k * 2.6,
			5.7,
			d - 3.2,
			-hw + 4.4 + k * 2.6,
			7.5,
			d - 1.8,
			g[1],
			g[2],
			f,
			true
		)
	end
	-- what each trade keeps on the floor
	if o.kind == "sake" then
		for _, lx in ipairs({ -hw + 4, hw - 4 }) do
			local bx, _, bz = U.loc(cf, lx, 0, d - 5.2)
			barrel(bx, 1, bz, f, "px_white_wool")
		end
	elseif o.kind == "rice" then
		for _, b in ipairs({ { -hw + 3.6, 1 }, { -hw + 3.6, 4 }, { hw - 3.6, 1 } }) do
			local bx, _, bz = U.loc(cf, b[1], 0, d - 5)
			cube("RiceBag", bx, b[2] + 1.5, bz, 3, 3, 3, "px_hay", nil, f)
			decor(cube("RiceTie", bx, b[2] + 3.2, bz, 1.4, 0.6, 1.4, "px_hay", TC.thatch, f))
		end
	elseif o.kind == "tea" then
		for _, lx in ipairs({ -hw + 3.6, hw - 3.6 }) do
			local bx, _, bz = U.loc(cf, lx, 0, d - 4)
			crate(bx, 1, bz, f, 3)
		end
	elseif o.kind == "lantern" then
		for i, lx in ipairs({ -hw + 3.5, hw - 3.5 }) do
			L(
				"HangingLantern",
				cf,
				lx - 0.9,
				6.2,
				d / 2,
				lx + 0.9,
				8.6,
				d / 2 + 1.8,
				PV,
				if i == 1 then TORII_RED else PAPER,
				f,
				true
			)
		end
	elseif o.kind == "sweets" then
		L("Tray", cf, hw - 5.6, 1, d - 5, hw - 2.4, 3.4, d - 2, "px_spruce_planks", nil, f)
		L("Mochi", cf, hw - 5.2, 3.4, d - 4.6, hw - 3.8, 4.6, d - 3.2, PV, SAKURA, f, true)
		L("Mochi", cf, hw - 4, 3.4, d - 3.6, hw - 2.8, 4.6, d - 2.4, PV, TC.white, f, true)
	elseif o.kind == "cloth" then
		for i, c in ipairs({ TC.indigo, TORII_RED, SAKURA }) do
			L("ClothBolt", cf, -hw + 2.4, i, d - 5.6, -hw + 5.8, i + 1, d - 3.2, PV, c, f)
		end
	end
	if o.npc then
		npc(
			"Shopkeeper",
			cf * CFrame.new(-1, 4, 5.2),
			{ shirt = o.look[1], pants = o.look[2], skin = pick(TC.skins) },
			TF.life
		)
		ST.npcs += 1
	end
	ST.shops += 1
	return cf
end
-- a one-storey house of the lower town: thatched or tiled, with a front deck (engawa) and paper doors; o.kura = a
-- white storehouse with a dark door and a heavy tile roof
function H.cottage(x, z, fx, fz, w, d, o)
	local x0, z0, x1, z1 = U.rect(x, z, fx, fz, w, d, if o.kura then 0 else 3)
	if not CL.take(x0, z0, x1, z1, "solid") then
		return nil
	end
	local r0, s0, r1, s1 = U.rect(x, z, fx, fz, w + 5, d + 2.5, 4.5)
	CL.add(r0, s0, r1, s1, "roof")
	local f = folder(if o.kura then "Storehouse" else "Cottage", TF.lower)
	local cf = U.faceCF(x, z, fx, fz)
	local hw = w / 2
	local L, DW, DT, PV = U.lbox, "px_dark_oak_planks", DARK_WOOD, "px_white_wool"
	L("Plinth", cf, -hw, 0, 0, hw, 1, d, "px_cobblestone", STONE, f)
	if not o.kura then
		L("Engawa", cf, -hw + 1, 0, -3, hw - 1, 1, 0, DW, nil, f)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, zz in ipairs({ 0, d - 2 }) do
			L("Post", cf, sx * hw, 1, zz, sx * (hw - 2), 8.6, zz + 2, DW, DT, f)
		end
		L("Wainscot", cf, sx * hw, 1, 2, sx * (hw - 1.6), 3.5, d - 2, DW, DT, f)
		L("Wall", cf, sx * (hw - 0.2), 3.5, 2, sx * (hw - 1.6), 8.6, d - 2, PV, PAPER, f)
	end
	L("Wainscot", cf, -hw + 2, 1, d - 1.6, hw - 2, 3.5, d, DW, DT, f)
	L("Wall", cf, -hw + 2, 3.5, d - 1.6, hw - 2, 8.6, d - 0.2, PV, PAPER, f)
	if o.kura then
		for _, sx in ipairs({ -1, 1 }) do
			L("Wall", cf, sx * (hw - 2), 1, 0.2, sx * 2, 8.6, 1.6, PV, PAPER, f)
		end
		L("Door", cf, -2, 1, 0.4, 2, 7, 1.4, DW, DT, f)
		L("Wall", cf, -2, 7, 0.2, 2, 8.6, 1.6, PV, PAPER, f)
		L("Crest", cf, -1, 6.2, -0.1, 1, 8.2, 0.2, PV, TC.indigo, f, true)
	else
		for _, sx in ipairs({ -1, 1 }) do
			L("Shoji", cf, sx * (hw - 2), 1, 0.6, sx * 2, 7.4, 1.2, PV, PAPER, f)
			L(
				"ShojiBar",
				cf,
				sx * (hw / 2 + 1) - 0.3,
				1,
				0.4,
				sx * (hw / 2 + 1) + 0.3,
				7.4,
				0.6,
				DW,
				DT,
				f,
				true
			)
		end
		L("Lintel", cf, -hw + 2, 7.4, 0.2, hw - 2, 8.6, 1.6, DW, DT, f)
	end
	L("Eave", cf, -hw, 8.6, 0, hw, 9.6, d, DW, DT, f)
	if o.thatch then
		H.roof(cf, hw, d, 9.6, f, "px_hay", TC.thatch, false, 4)
	else
		H.roof(cf, hw, d, 9.6, f, "px_roof_tiles", ROOF_DARK, true, if o.kura then 2 else 4)
	end
	ST.houses += 1
	return cf
end
do
	local LOOK = {
		{ Color3.fromRGB(46, 58, 116), Color3.fromRGB(44, 40, 46) },
		{ Color3.fromRGB(150, 50, 46), Color3.fromRGB(60, 50, 44) },
		{ Color3.fromRGB(90, 120, 80), Color3.fromRGB(64, 54, 46) },
		{ Color3.fromRGB(120, 90, 130), Color3.fromRGB(46, 42, 50) },
		{ Color3.fromRGB(176, 140, 90), Color3.fromRGB(70, 56, 44) },
	}
	local RED, IND = TORII_RED, TC.indigo
	-- { front x, front z, face x, face z, width, depth, kind, noren, balcony, npc look }
	local SHOPS = {
		-- the west row: fronts on x -120 facing east over the west lane to the pit
		{ -120, 60, 1, 0, 16, 12, "tea", IND },
		{ -120, 84, 1, 0, 16, 12, "sake", RED, true, LOOK[1] },
		{ -120, 108, 1, 0, 16, 12, "cloth", IND },
		{ -120, 132, 1, 0, 16, 12, "sweets", RED, false, LOOK[4] },
		{ -120, 156, 1, 0, 16, 12, "rice", IND, true },
		-- the south-west row: fronts on z 180 facing north over the south lane
		{ -88, 180, 0, -1, 12, 12, "lantern", RED },
		{ -70, 180, 0, -1, 16, 12, "rice", IND, true, LOOK[3] },
		{ -52, 180, 0, -1, 12, 12, "sake", RED },
		-- south-east of the buyer
		{ 34, 180, 0, -1, 16, 12, "sweets", IND, true },
		-- the east row: fronts on x 76 facing west over the main way
		{ 76, 84, -1, 0, 16, 12, "tea", RED, false, LOOK[5] },
		{ 76, 116, -1, 0, 16, 12, "lantern", IND, true, LOOK[2] },
		{ 76, 140, -1, 0, 16, 12, "cloth", RED },
	}
	for _, s in ipairs(SHOPS) do
		H.machiya(
			s[1],
			s[2],
			s[3],
			s[4],
			s[5],
			s[6],
			{ kind = s[7], noren = s[8], balcony = s[9], npc = s[10] ~= nil, look = s[10] }
		)
	end
	task.wait()
	-- the lower town houses: two on P2 (west), three on the east path
	H.cottage(-154, 98, 1, 0, 12, 12, { thatch = true })
	H.cottage(-154, 120, 1, 0, 12, 12, {})
	H.cottage(120, 89, 0, 1, 16, 12, { thatch = true })
	H.cottage(140, 111, 0, -1, 16, 12, {})
	H.cottage(164, 108, 0, -1, 12, 12, { kura = true })
end
task.wait()

-- ================================================================ the lower town: paths, the shrine, the well, the plot, carts, lanterns
do
	-- gravel paths (flush runs)
	U.gravel(-178, 34, -120, 42)
	U.gravel(-178, 28, -166, 34)
	U.gravel(-150, 42, -144, 140)
	U.gravel(-176, 68, -150, 72)
	U.gravel(76, 96, 150, 104)
	-- stone lanterns along the paths (every other one lit)
	for i, l in ipairs({
		{ -128, 29 },
		{ -150, 29 },
		{ -154, 48 },
		{ -140, 84 },
		{ -140, 124 },
		{ 96, 90 },
	}) do
		if CL.take(l[1] - 2, l[2] - 2, l[1] + 2, l[2] + 2, "solid") then
			P.stoneLantern(l[1], l[2], TF.lower, i % 2 == 1)
		end
	end
end
do
	-- THE SHRINE: a red-posted hall on a stone platform facing east, a torii over the approach, two foxes, lanterns
	local f = TF.shrine
	if CL.take(-198, 58, -172, 82, "solid") then
		CL.add(-202, 54, -170, 86, "roof")
		CL.add(-172, 58, -156, 66, "solid")
		CL.add(-172, 74, -156, 82, "solid")
		local cf = U.faceCF(-174, 70, 1, 0)
		local L, DW, DT, PV, RV, RED =
			U.lbox, "px_dark_oak_planks", DARK_WOOD, "px_white_wool", "px_roof_tiles", TORII_RED
		L("ShrineBase", cf, -12, 0, 0, 12, 2, 24, "px_stone_bricks", STONE, f)
		L("ShrineStep", cf, -4, 0, -2, 4, 1, 0, "px_smooth_stone", STONE, f)
		L("ShrineFloor", cf, -9, 2, 2, 9, 2.4, 20, DW, nil, f)
		for _, sx in ipairs({ -1, 1 }) do
			for _, zz in ipairs({ 2, 18 }) do
				L("ShrinePost", cf, sx * 9 - 1, 2, zz, sx * 9 + 1, 10.6, zz + 2, PV, RED, f)
			end
			L("Wainscot", cf, sx * 9.8, 2.4, 4, sx * 8.4, 4.4, 18, DW, DT, f)
			L("Wall", cf, sx * 9.6, 4.4, 4, sx * 8.4, 10.6, 18, PV, PAPER, f)
			L("ShrineBeam", cf, sx * 10, 10.6, 2, sx * 8, 12, 20, PV, RED, f)
		end
		L("Sanctuary", cf, -8, 2.4, 18.6, 8, 10.6, 20, DW, DT, f)
		L("ShrineBeam", cf, -8, 10.6, 1.6, 8, 12, 3.4, PV, RED, f)
		L("ShrineBeam", cf, -8, 10.6, 18.6, 8, 12, 20.4, PV, RED, f)
		L("Eave", cf, -10, 12, 1.6, 10, 13, 20.4, DW, DT, f)
		-- inside: the altar with a gold mirror; at the front: the offering box, the bell rope, the straw rope with paper
		L("Altar", cf, -4, 2.4, 15, 4, 5.4, 18, DW, nil, f)
		L("Mirror", cf, -0.9, 5.4, 16.2, 0.9, 7.2, 16.8, "px_gold_block", nil, f, true)
		L("Saisen", cf, -3, 2.4, 3, 3, 5, 5.4, DW, DT, f)
		L("SaisenTop", cf, -3.2, 5, 2.8, 3.2, 5.4, 5.6, "px_spruce_planks", nil, f, true)
		L("BellRope", cf, -0.3, 5.4, 1.6, 0.3, 9.2, 2, PV, RED, f, true)
		L("Bell", cf, -0.9, 9, 1.2, 0.9, 10.4, 2.6, "px_gold_block", nil, f, true)
		L("Shimenawa", cf, -7, 9.2, 0.6, 7, 10.4, 1.6, "px_hay", nil, f, true)
		for _, sx in ipairs({ -4.5, 4.5 }) do
			L("Shide", cf, sx - 0.4, 7.4, 0.9, sx + 0.4, 9.2, 1.2, PV, TC.white, f, true)
		end
		-- the roof: wide, stepped, raised tips (ridge parallel to the front)
		L("Roof", cf, -13, 13, -4, 13, 14.5, 25, RV, ROOF_DARK, f)
		L("Roof", cf, -12, 14.5, -1, 12, 16.5, 22, RV, ROOF_DARK, f)
		L("Roof", cf, -11, 16.5, 3, 11, 18.5, 18, RV, ROOF_DARK, f)
		L("Roof", cf, -10, 18.5, 7, 10, 20, 14, RV, ROOF_DARK, f)
		L("RoofRidge", cf, -11.5, 20, 9, 11.5, 21.6, 12, RV, TC.ridge, f)
		for _, sx in ipairs({ -1, 1 }) do
			for _, zz in ipairs({ -4, 25 }) do
				L(
					"RoofTip",
					cf,
					sx * 13,
					14.5,
					zz,
					sx * 11.2,
					16.4,
					zz + (if zz < 0 then 1.8 else -1.8),
					RV,
					ROOF_DARK,
					f,
					true
				)
			end
			L("RidgeTip", cf, sx * 11.5, 21.6, 9.6, sx * 10, 23.4, 11.4, RV, TC.ridge, f, true)
			L("RedPlank", cf, sx * 13, 12.6, -4, sx * 12.4, 13, 25, PV, RED, f, true)
		end
		-- the approach: torii, foxes facing the visitors, two lit lanterns
		P.torii(-164, 70, 1, 0, 12, 13, f)
		P.fox(-170, 63, 1, 0, f)
		P.fox(-170, 77, 1, 0, f)
		P.stoneLantern(-158, 62, f, true)
		P.stoneLantern(-158, 78, f, true)
		U.petals(-168, 60, -158, 66, false, f)
		U.petals(-190, 82, -176, 88, true, f)
		npc(
			"Miko",
			U.faceCF(-178, 75, 1, 0, 5),
			{ shirt = TC.white, pants = TORII_RED, skin = TC.skins[1] },
			TF.life
		)
		ST.npcs += 1
	end
	-- the well by P1
	if CL.take(-172, 46, -160, 58, "solid") then
		local x, z, wf = -166, 52, TF.lower
		box("WellRim", x - 6, 0, z - 6, x + 6, 3, z - 2, "px_cobblestone", STONE, wf)
		box("WellRim", x - 6, 0, z + 2, x + 6, 3, z + 6, "px_cobblestone", STONE, wf)
		box("WellRim", x - 6, 0, z - 2, x - 2, 3, z + 2, "px_cobblestone", STONE, wf)
		box("WellRim", x + 2, 0, z - 2, x + 6, 3, z + 2, "px_cobblestone", STONE, wf)
		box("WellShaft", x - 2, 0, z - 2, x + 2, 1.2, z + 2, "px_mossy_cobblestone", nil, wf)
		local water =
			decor(box("WellWater", x - 2, 1.2, z - 2, x + 2, 1.4, z + 2, "px_water", TC.water, wf))
		water.Transparency = 0.2
		for _, sx in ipairs({ -1, 1 }) do
			box(
				"WellPost",
				x + sx * 5 - 0.5,
				3,
				z - 0.5,
				x + sx * 5 + 0.5,
				10,
				z + 0.5,
				"px_dark_oak_planks",
				nil,
				wf
			)
		end
		box("WellBeam", x - 4.5, 9.2, z - 0.4, x + 4.5, 10, z + 0.4, "px_dark_oak_planks", nil, wf)
		box("WellRoof", x - 6.5, 10, z - 3, x + 6.5, 11, z + 3, "px_roof_tiles", ROOF_DARK, wf)
		box("WellRoof", x - 5, 11, z - 1.5, x + 5, 12, z + 1.5, "px_roof_tiles", ROOF_DARK, wf)
		decor(box("WellRope", x - 0.15, 6.6, z - 0.15, x + 0.15, 9.2, z + 0.15, "px_hay", nil, wf))
		decor(
			box(
				"WellBucket",
				x - 0.8,
				5,
				z - 0.8,
				x + 0.8,
				6.6,
				z + 0.8,
				"px_spruce_planks",
				nil,
				wf
			)
		)
	end
	-- the vegetable plot west of the well: dark soil rows of greens, cabbages and carrots, a fence on the path side
	if CL.take(-200, 44, -182, 58, "solid") then
		local pf = folder("VegetablePlot", TF.lower)
		box("Soil", -200, 0, 44, -184, 0.4, 56, "px_dirt", nil, pf)
		for row = 0, 2 do
			local z = 46 + row * 4
			for col = 0, 3 do
				local x = -198 + col * 4
				local kind = (row + col) % 3
				if kind == 0 then
					decor(cube("Cabbage", x, 1.6, z, 2.6, 2.4, 2.6, "px_hedge", TC.cabbage, pf))
				elseif kind == 1 then
					decor(cube("Greens", x, 1.4, z, 2, 2, 2, "px_hedge", TC.crop, pf))
				else
					decor(cube("Carrot", x, 0.8, z, 1.2, 0.8, 1.2, "px_white_wool", TC.carrot, pf))
					decor(cube("CarrotTop", x, 1.8, z, 1.6, 1.2, 1.6, "px_hedge", TC.crop, pf))
				end
			end
		end
		fence(-200, 57, -184, 57, pf, 0, "px_spruce_planks")
	end
	-- carts and hay
	if CL.take(-190, 86, -178, 98, "solid") then
		P.cart(-184, 92, math.pi / 2 + 0.2, TF.lower)
	end
	if CL.take(-180, 102, -172, 110, "solid") then
		P.hay(-178, 104, TF.lower, 4)
	end
	if CL.take(98, 120, 112, 132, "solid") then
		P.cart(105, 126, 0.35, TF.lower)
	end
	if CL.take(114, 128, 122, 136, "solid") then
		P.hay(116, 130, TF.lower, 3)
	end
	if CL.take(150, 124, 158, 132, "solid") then
		P.hay(152, 126, TF.lower, 4)
	end
end
task.wait()

-- ================================================================ bamboo clumps under the west cliff
do
	for _, cx in ipairs({ -204, -142, -92, -60 }) do
		for z0 = -16, 16, 2 do
			local x0, x1, z1 = cx - 6, cx + 6, z0 + 12
			if CL.ground(x0, z0, x1, z1) and not CL.hit(x0, z0, x1, z1) then
				CL.add(x0, z0, x1, z1, "solid")
				local f = folder("BambooClump", TF.bamboo)
				for i = 0, 2 do
					for j = 0, 2 do
						if rng:NextNumber() < 0.72 or (i == 1 and j == 0) then
							local x, z = x0 + 2 + i * 4, z0 + 2 + j * 4
							local h = rng:NextInteger(4, 7) * B
							local tint = if (i + j) % 2 == 0 then TC.bamboo else TC.bambooDark
							box("Bamboo", x - 2, 0, z - 2, x + 2, h, z + 2, "px_hedge", tint, f)
							decor(
								box(
									"BambooJoint",
									x - 2.1,
									h * 0.5 - 0.3,
									z - 2.1,
									x + 2.1,
									h * 0.5 + 0.3,
									z + 2.1,
									"px_hedge",
									TC.leafGreen,
									f
								)
							)
							if rng:NextNumber() < 0.5 then
								local dx, dz = pick({ -1, 1 }) * 4, pick({ -1, 1 }) * 4
								decor(
									box(
										"BambooLeaves",
										x + dx - 2,
										h - 4,
										z + dz - 2,
										x + dx + 2,
										h,
										z + dz + 2,
										"px_hedge",
										TC.leafGreen,
										f
									)
								)
							end
						end
					end
				end
				ST.bamboo += 1
				break
			end
		end
	end
end
task.wait()

-- ================================================================ cherry trees
local TREES = {}
-- a cherry tree: a log trunk (1×1 or 2×2 blocks) with a branch or two, a stepped crown (pink wool core, cherry-leaf
-- and deep-pink edge cubes, a few hanging), a petal carpet under it. o = { trunk, h, w, log }
function P.cherry(x, z, o)
	local f = folder("CherryTree", TF.trees)
	local tw, th, W = o.trunk * B, o.h * B, o.w
	local hs = W * B / 2
	box("Trunk", x - tw / 2, 0, z - tw / 2, x + tw / 2, th, z + tw / 2, o.log, nil, f)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	if o.trunk == 2 then
		local d = pick(dirs)
		local rx, rz = x + d[1] * (tw / 2 + 2), z + d[2] * (tw / 2 + 2)
		box("Root", rx - 2, 0, rz - 2, rx + 2, 2, rz + 2, o.log, nil, f)
	end
	-- branches: under a big crown one block just outside the underside (and one by the trunk lower down), under a
	-- small crown one block beside the trunk top
	for _ = 1, rng:NextInteger(1, 2) do
		local d = pick(dirs)
		local o1 = tw / 2 + 2
		if W >= 5 then
			local bx, bz = x + d[1] * (hs - 2), z + d[2] * (hs - 2)
			box("Branch", bx - 2, th - 4, bz - 2, bx + 2, th, bz + 2, o.log, nil, f)
			if th >= 12 then
				bx, bz = x + d[1] * o1, z + d[2] * o1
				box("Branch", bx - 2, th - 8, bz - 2, bx + 2, th - 4, bz + 2, o.log, nil, f)
			end
		else
			local bx, bz = x + d[1] * o1, z + d[2] * o1
			box("Branch", bx - 2, th - 4, bz - 2, bx + 2, th, bz + 2, o.log, nil, f)
		end
	end
	-- the crown: an underside, two crossed body slabs, a top (and a cap on big crowns)
	local cy = th - B
	local bodyH = if W >= 5 then 2 * B else B
	if W >= o.trunk + 3 then
		box(
			"Crown",
			x - hs + 4,
			cy,
			z - hs + 4,
			x + hs - 4,
			cy + B,
			z + hs - 4,
			"px_cherry_leaves",
			nil,
			f
		)
	end
	box(
		"Crown",
		x - hs,
		cy + B,
		z - hs + 4,
		x + hs,
		cy + B + bodyH,
		z + hs - 4,
		"px_white_wool",
		SAKURA,
		f
	)
	box(
		"Crown",
		x - hs + 4,
		cy + B,
		z - hs,
		x + hs - 4,
		cy + B + bodyH,
		z + hs,
		"px_white_wool",
		SAKURA,
		f
	)
	local ty = cy + B + bodyH
	box(
		"Crown",
		x - hs + 4,
		ty,
		z - hs + 4,
		x + hs - 4,
		ty + B,
		z + hs - 4,
		"px_white_wool",
		SAKURA,
		f
	)
	if W >= 6 then
		box(
			"Crown",
			x - hs + 8,
			ty + B,
			z - hs + 8,
			x + hs - 8,
			ty + 2 * B,
			z + hs - 8,
			"px_white_wool",
			SAKURA_DEEP,
			f
		)
	end
	-- edge cubes stuck on the sides and the top, a few hanging below
	for k = 1, W + 3 do
		local d = pick(dirs)
		local along = -hs + 2 + rng:NextInteger(1, math.max(1, W - 2)) * B
		local ex, ez = x + d[1] * (hs + 2) + d[2] * along, z + d[2] * (hs + 2) + d[1] * along
		local ey = cy + B + rng:NextInteger(0, bodyH / B - 1) * B
		if k > W + 1 then
			ex, ez, ey =
				x + d[1] * (hs - 6) + d[2] * snap(along * 0.5),
				z + d[2] * (hs - 6) + d[1] * snap(along * 0.5),
				ty + B
		end
		local deep = rng:NextNumber() < 0.3
		local c = cube(
			"Blossom",
			ex,
			ey + 2,
			ez,
			B,
			B,
			B,
			if deep then "px_white_wool" else "px_cherry_leaves",
			if deep then SAKURA_DEEP else nil,
			f
		)
		decor(c)
	end
	for _ = 1, if W >= 5 then 2 else 1 do
		local d = pick(dirs)
		local along = -hs + 2 + rng:NextInteger(1, math.max(1, W - 2)) * B
		local ex, ez = x + d[1] * (hs - 2) + d[2] * along, z + d[2] * (hs - 2) + d[1] * along
		decor(cube("BlossomHang", ex, cy + B - 2, ez, B, B, B, "px_cherry_leaves", nil, f))
	end
	-- the petal carpet
	local a, b = rng:NextInteger(-1, 1) * 2, rng:NextInteger(-1, 1) * 2
	U.petals(x - hs + 2 + a, z - hs + 4 + b, x + hs - 2 + a, z + hs - 4 + b, false, f)
	U.petals(
		x - hs / 2 - b,
		z - hs / 2 + a,
		x + hs / 2 - b,
		z + hs / 2 + a,
		rng:NextNumber() < 0.5,
		f
	)
	ST.trees += 1
end
do
	local PLAZA = { -120, -8, 76, 180 } -- the walk area between the shop fronts: trees only on designated spots
	local NOLANE = { solid = true, roof = true, keep = true }
	local CROWN = { solid = true, roof = true, keep = true }
	local function params(trunk, w)
		return {
			trunk = trunk,
			w = w,
			h = rng:NextInteger(2, 4) + (if w >= 6 then 1 else 0),
			log = pick({ "px_cherry_log", "px_cherry_log", "px_dark_oak_log" }),
		}
	end
	local function fits(x, z, o, designated)
		local hs = o.w * B / 2
		local tw = o.trunk * B / 2 + 2
		if zoneOf(x, z) ~= "town" or not freeGround(x, z, math.max(0, hs - 8)) then
			return false
		end
		if not designated and inRect(x, z, PLAZA) then
			return false
		end
		if
			not CL.ground(x - tw, z - tw, x + tw, z + tw)
			or CL.hit(x - tw, z - tw, x + tw, z + tw, if designated then NOLANE else nil)
		then
			return false
		end
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local cx, cz = x + s[1] * hs, z + s[2] * hs
			if
				not onIsland(cx, cz, 10)
				or groundY(cx, cz) ~= 0
				or zoneOf(cx, cz) ~= "town"
				or inPitArea(cx, cz, 0)
			then
				return false
			end
		end
		if CL.hit(x - hs, z - hs, x + hs, z + hs, CROWN) then
			return false
		end
		for _, t in ipairs(TREES) do
			if (t[1] - x) ^ 2 + (t[2] - z) ^ 2 < ((t[3] + hs) * 0.8) ^ 2 then
				return false
			end
		end
		return true
	end
	local function plant(x, z, o)
		local tw = o.trunk * B / 2
		CL.add(x - tw, z - tw, x + tw, z + tw, "solid")
		table.insert(TREES, { x, z, o.w * B / 2 })
		P.cherry(x, z, o)
	end
	-- designated spots in the square: the north strip under the cliff, the south-west corner, behind the south row
	for _, s in ipairs({ { -110, 8 }, { -78, 8 }, { -30, 8 }, { 2, 8 }, { -108, 174 }, { 52, 202 } }) do
		for _, w in ipairs({ 5, 3 }) do
			local o = params(1, w)
			if fits(s[1], s[2], o, true) then
				plant(s[1], s[2], o)
				break
			end
		end
	end
	-- the rest on free town ground (west and east lowlands, the rim)
	local tries = 0
	while ST.trees < 40 and tries < 3000 do
		tries += 1
		local trunk = if rng:NextNumber() < 0.3 then 2 else 1
		local w = if trunk == 2 then pick({ 4, 6, 6, 8 }) else pick({ 3, 5, 5, 7 })
		local x = math.floor(rng:NextNumber(-224, 216) / B) * B + (if trunk == 1 then 2 else 0)
		local z = math.floor(rng:NextNumber(-8, 224) / B) * B + (if trunk == 1 then 2 else 0)
		local o = params(trunk, w)
		if fits(x, z, o, false) then
			plant(x, z, o)
		end
		if tries % 400 == 0 then
			task.wait()
		end
	end
end
task.wait()

-- ================================================================ the rim: kerb, view points, benches, leaf curtains, leaning trees
do
	local f = TF.rim
	local VIEWS = { 100, 138, 166 } -- degrees from +X toward +Z (90 = south)
	-- the outermost radius along an angle where solid things may stand (onIsland pad 10)
	local function edgeR(deg)
		local a = math.rad(deg)
		local ca, sa = math.cos(a), math.sin(a)
		local r = 230
		while r > 180 and not onIsland(r * ca, r * sa, 10) do
			r -= 1
		end
		return r, ca, sa
	end
	local function nearView(deg, half)
		for _, v in ipairs(VIEWS) do
			if math.abs(deg - v) <= half then
				return true
			end
		end
		return false
	end
	-- benches at the south view point, looking out
	do
		local r, ca, sa = edgeR(VIEWS[1])
		local vx, vz = snap((r - 12) * ca), snap((r - 12) * sa)
		for _, dx in ipairs({ -6, 6 }) do
			if CL.take(vx + dx - 4.4, vz - 1.4, vx + dx + 4.4, vz + 1.6, "solid") then
				P.bench(vx + dx, vz, 0, 1, f)
			end
		end
		U.petals(vx - 10, vz + 3, vx + 2, vz + 8, false, f)
	end
	-- small trees leaning out over the edge (a solid foot on the island, the rest hangs over the cliff)
	for _, deg in ipairs({ 112, 128, 152, 176 }) do
		local r, ca, sa = edgeR(deg)
		local bx, bz = snap((r - 4) * ca) + 2, snap((r - 4) * sa) + 2
		if CL.take(bx - 2, bz - 2, bx + 2, bz + 2, "solid") then
			local tf = folder("LeaningTree", f)
			local log = pick({ "px_cherry_log", "px_dark_oak_log" })
			local ox, oz =
				(if math.abs(ca) > 0.5 then (if ca > 0 then 1 else -1) else 0),
				(if math.abs(sa) > 0.5 then (if sa > 0 then 1 else -1) else 0)
			box("Trunk", bx - 2, 0, bz - 2, bx + 2, 4, bz + 2, log, nil, tf)
			for k = 1, 3 do
				local x, z = bx + ox * k * 3, bz + oz * k * 3
				decor(box("Trunk", x - 2, k * 4, z - 2, x + 2, k * 4 + 4, z + 2, log, nil, tf))
			end
			local cx, cz, cy = bx + ox * 12, bz + oz * 12, 14
			decor(
				box(
					"Crown",
					cx - 8,
					cy,
					cz - 4,
					cx + 8,
					cy + 4,
					cz + 4,
					"px_white_wool",
					SAKURA,
					tf
				)
			)
			decor(
				box(
					"Crown",
					cx - 4,
					cy,
					cz - 8,
					cx + 4,
					cy + 4,
					cz + 8,
					"px_white_wool",
					SAKURA,
					tf
				)
			)
			decor(
				box(
					"Crown",
					cx - 4,
					cy + 4,
					cz - 4,
					cx + 4,
					cy + 8,
					cz + 4,
					"px_cherry_leaves",
					nil,
					tf
				)
			)
			decor(
				box(
					"CrownUnder",
					cx - 4,
					cy - 4,
					cz - 4,
					cx + 4,
					cy,
					cz + 4,
					"px_cherry_leaves",
					nil,
					tf
				)
			)
			decor(
				box(
					"CrownHang",
					cx + ox * 4 - 2,
					cy - 8,
					cz + oz * 4 - 2,
					cx + ox * 4 + 2,
					cy,
					cz + oz * 4 + 2,
					"px_cherry_leaves",
					nil,
					tf
				)
			)
			decor(
				cube(
					"Blossom",
					cx - oz * 10,
					cy + 2,
					cz - ox * 10,
					B,
					B,
					B,
					"px_white_wool",
					SAKURA_DEEP,
					tf
				)
			)
		end
	end
	-- the low kerb: 2-stud stone blocks on the 4-grid along the edge (merged along x), gaps at the view points
	local cells, rows = {}, {}
	for deg = 16, 186, 0.4 do
		if not nearView(deg, 3.5) then
			local r, ca, sa = edgeR(deg)
			local x = math.floor((r - 5) * ca / B) * B + 2
			local z = math.floor((r - 5) * sa / B) * B + 2
			local key = x .. ":" .. z
			if not cells[key] then
				cells[key] = true
				if
					onIsland(x, z, 10)
					and groundY(x, z) == 0
					and zoneOf(x, z) == "town"
					and not inStairCorridor(x, z)
					and not inPond(x, z, 4)
					and not CL.hit(x - 2, z - 2, x + 2, z + 2, { solid = true, keep = true })
				then
					rows[z] = rows[z] or {}
					table.insert(rows[z], x)
				end
			end
		end
	end
	for z, xs in pairs(rows) do
		table.sort(xs)
		local i = 1
		while i <= #xs do
			local j = i
			while j < #xs and xs[j + 1] == xs[j] + B do
				j += 1
			end
			box("Kerb", xs[i] - 2, 0, z - 2, xs[j] + 2, 2, z + 2, "px_stone_bricks", STONE, f)
			ST.kerb += 1
			i = j + 1
		end
	end
	task.wait()
	-- leaf curtains: on the outer face of the outermost island cells (8-stud grid from -248), 0.6 stud off the rock
	local LEAVES = {
		{ "px_cherry_leaves", nil },
		{ "px_white_wool", SAKURA },
		{ "px_hedge", TC.leafGreen },
		{ "px_cherry_leaves", nil },
	}
	local function curtain(x0, x1, z0, z1, alongX)
		local lv = pick(LEAVES)
		local h1 = rng:NextInteger(2, 4) * B
		local p = decor(box("LeafCurtain", x0, -h1, z0, x1, 0, z1, lv[1], lv[2], f))
		p.CastShadow = false
		if rng:NextNumber() < 0.6 then
			local h2 = h1 + rng:NextInteger(1, 3) * B
			local o = rng:NextInteger(0, 1) * 4
			local q
			if alongX then
				q = box("LeafCurtain", x0 + o, -h2, z0, x0 + o + 4, -h1, z1, lv[1], lv[2], f)
			else
				q = box("LeafCurtain", x0, -h2, z0 + o, x1, -h1, z0 + o + 4, lv[1], lv[2], f)
			end
			decor(q).CastShadow = false
		end
		ST.curtains += 1
	end
	-- the south face (columns along x)
	for x0 = -168, 64, 8 do
		local cx = x0 + 4
		for z0 = 240, 104, -8 do
			if onIsland(cx, z0 + 4) then
				local face = z0 + 8
				if
					groundY(cx, z0 + 4) == 0
					and zoneOf(cx, z0 + 4) == "town"
					and rng:NextNumber() < 0.55
				then
					curtain(x0, x0 + 8, face + 0.6, face + 1.6, true)
				end
				break
			end
		end
	end
	-- the west face (rows along z)
	for z0 = -8, 160, 8 do
		local cz = z0 + 4
		for x0 = -248, -96, 8 do
			if onIsland(x0 + 4, cz) then
				if
					groundY(x0 + 4, cz) == 0
					and zoneOf(x0 + 4, cz) == "town"
					and rng:NextNumber() < 0.55
				then
					curtain(x0 - 1.6, x0 - 0.6, z0, z0 + 8, false)
				end
				break
			end
		end
	end
end

print(
	("[build-kyoto] town: %d shops, %d houses, %d trees, %d bamboo, %d npcs, %d lights, %d kerb runs, %d curtains, %d skipped, %d parts"):format(
		ST.shops,
		ST.houses,
		ST.trees,
		ST.bamboo,
		ST.npcs,
		ST.lights,
		ST.kerb,
		ST.curtains,
		ST.skipped,
		count - startCount
	)
)
