--!nocheck
-- ================================================================ gate: the sky (the islets, the bridges, the air)
-- Everything here is strictly mirror-symmetric in x: each piece is decided once (all rng draws outside the side loop)
-- and built for sx = -1 and sx = 1. The bundler wraps this file in its own do … end.
-- 1. THE BRIDGES over BRIDGES (A: x ±156..±210, z 52..68; B: x ±152..±192, z -128..-112): the gap is measured
--    from core's 8-stud cells along the deck's centre line (and along each kerb line), the deck runs 16 studs onto
--    both islands; a cut sandstone deck 4 blocks wide (top y 0.1) with a sandstone runner, pearl kerbs over the gap
--    only with dark-oak fence rails (open at the ends), a white torch pylon at both ends of each kerb, a stepped
--    pearl keel deepest under the middle.
-- 2. THE ISLETS A (±240, 60): a gold-capped open pavilion 4×4 blocks at (±256, 60) (pearl columns, a gold-barred
--    upper storey round a glowstone core, a stepped gold roof with a fire), a blue-glass fountain cascade in a white
--    basin at (±240, 80), a sandstone runner from the landing to the pavilion (z 56..64), cypresses, two benches,
--    two white lantern posts; the walk z 52..68 stays clear.
-- 3. THE ISLETS B (±216, -120): a torch pylon monument at (±220, -120) (a pearl shaft 2×2 blocks, two teal bands,
--    a yellow sun banner on each face, a gold capital with a fire, ≈ 52 studs) on a stepped pearl dais
--    x ±208..±232, small torch pylons at the dais front, cypresses, two benches, two lantern posts behind it.
-- 4. Blue-glass waterfalls (stepped glass columns from a spout on a rim cell down the face to 12 studs under the
--    column bottom, a wool foam puff there): on the main island's rim along z 150, 116, 20, -24, -64 (facing ±x)
--    and at the north tip x ±88 (facing north), and two on each islet at ±40° from the outward direction.
-- 5. White stalactites under the islands (core's cells and rockDepth), sparse inside, denser on the rim, a few gold
--    tips; none under the bridges and the waterfall cells.
-- 6. Floating white islets (stepped cones) in mirrored pairs with a torch pylon, a gold cage pylon, a tiny fountain
--    or a cypress: 24+ studs off every island, out of the bridge corridors and the beacon's sky.
-- 7. The sea of clouds: a broken layer of white wool puffs (tops y -60..-90) under and round the islands (never
--    inside an island column), puffs round the rim (y -10..-40), a few high puffs and two cloud steps by each islet.
local sky = folder("Sky")
local c0 = count
local lights = 0 -- PointLights of this part (≤ 10, bright noon)
local STONE_LOW = Color3.fromRGB(238, 236, 228) -- core's rockLowTint
local FIRE = Color3.fromRGB(255, 150, 40)
local FIRE_CORE = Color3.fromRGB(255, 226, 110)
local SIDES = { -1, 1 }

-- the island cell (core's 8-stud grid over x -288..288, z -240..200) holding a point: its island and centre
local function cellLand(x, z)
	if x < -288 or x >= 288 or z < -240 or z >= 200 then
		return nil
	end
	local cx = -288 + 8 * math.floor((x + 288) / 8) + 4
	local cz = -240 + 8 * math.floor((z + 240) / 8) + 4
	return isleOf(cx, cz), cx, cz
end
-- core's rockDepth (10-core is wrapped in its own do … end, so it is replicated here exactly)
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
-- a land cell's column: its top (the terrace y 24, else 0) and its bottom (top - ground block - rock)
local function colTop(cx, cz)
	return if onTerrace(cx, cz) then TERRACE_Y else 0
end
local function colBottom(cx, cz)
	return colTop(cx, cz) - B - rockDepth(cx, cz)
end
local function dbox(name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	return decor(box(name, x0, y0, z0, x1, y1, z1, variant, tint, parent))
end
-- blue glass water by two corners (decor, no shadow)
local function glass(name, x0, y0, z0, x1, y1, z1, parent)
	local p = part(
		name,
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		WATER,
		Enum.Material.Glass,
		parent
	)
	p.Transparency = 0.35
	p.CastShadow = false
	return decor(p)
end
local function neon(name, x0, y0, z0, x1, y1, z1, color, parent)
	local p = part(
		name,
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		color,
		Enum.Material.Neon,
		parent
	)
	p.CastShadow = false
	return decor(p)
end
local function glow(p, range, brightness, color)
	if lights < 10 then
		lights += 1
		light(p, range, brightness, color)
	end
end
-- a torch pylon (the concept's panel): a white shaft, a teal band, a gold band, a white brazier with a fire;
-- s = scale (1 = a 1-block shaft, 16.5 studs tall); solid = the plinth and the shaft collide; returns the top y
local function torch(x, y, z, s, parent, solid, lit)
	local function sq(name, h, y0, y1, variant, tint)
		return box(
			name,
			x - h * s,
			y + y0 * s,
			z - h * s,
			x + h * s,
			y + y1 * s,
			z + h * s,
			variant,
			tint,
			parent
		)
	end
	local a = sq("PylonPlinth", 2.2, 0, 1, "px_white_stone_bricks", PEARL)
	local b = sq("PylonShaft", 1.8, 1, 9, "px_smooth_stone", PEARL)
	if not solid then
		decor(a)
		decor(b)
	end
	decor(sq("PylonBand", 2, 9, 10.5, "px_prismarine", JASPER))
	decor(sq("PylonGold", 2.2, 10.5, 11.5, "px_gold_block", GOLD))
	decor(sq("PylonBrazier", 2.2, 11.5, 12.5, "px_white_stone_bricks", PEARL))
	local f = neon(
		"Fire",
		x - 1.4 * s,
		y + 12.5 * s,
		z - 1.4 * s,
		x + 1.4 * s,
		y + 15 * s,
		z + 1.4 * s,
		FIRE,
		parent
	)
	neon(
		"FireCore",
		x - 0.7 * s,
		y + 15 * s,
		z - 0.7 * s,
		x + 0.7 * s,
		y + 16.5 * s,
		z + 0.7 * s,
		FIRE_CORE,
		parent
	)
	if lit then
		glow(f, 30, 1.2, FIRE)
	end
	return y + 16.5 * s
end
-- a cypress: a dark trunk, a hedge column 2×2 blocks h blocks tall, a 1×1 spire and tip
local function cypress(x, y, z, h, parent, solid)
	local t = box(
		"CypressTrunk",
		x - 1.5,
		y,
		z - 1.5,
		x + 1.5,
		y + 3,
		z + 1.5,
		"px_dark_oak_log",
		nil,
		parent
	)
	local c = box(
		"Cypress",
		x - 4,
		y + 3,
		z - 4,
		x + 4,
		y + 3 + h * B,
		z + 4,
		"px_hedge",
		CYPRESS,
		parent
	)
	if not solid then
		decor(t)
		decor(c)
	end
	local top = y + 3 + h * B
	dbox("CypressSpire", x - 2, top, z - 2, x + 2, top + 2 * B, z + 2, "px_hedge", CYPRESS, parent)
	dbox(
		"CypressTip",
		x - 1,
		top + 2 * B,
		z - 1,
		x + 1,
		top + 3 * B,
		z + 1,
		"px_hedge",
		CYPRESS,
		parent
	)
end
-- a white bench 2 blocks long (along x or z): two brick legs and a smooth seat
local function bench(x, y, z, alongX, parent)
	local lx, lz = if alongX then 3 else 0, if alongX then 0 else 3
	local hx, hz = if alongX then 1 else 1.5, if alongX then 1.5 else 1
	for _, k in ipairs({ -1, 1 }) do
		box(
			"BenchLeg",
			x + k * lx - hx,
			y,
			z + k * lz - hz,
			x + k * lx + hx,
			y + 2,
			z + k * lz + hz,
			"px_white_stone_bricks",
			PEARL,
			parent
		)
	end
	local sx, sz = if alongX then 4 else 1.5, if alongX then 1.5 else 4
	box(
		"BenchSeat",
		x - sx,
		y + 2,
		z - sz,
		x + sx,
		y + 2.8,
		z + sz,
		"px_smooth_stone",
		PEARL,
		parent
	)
end
-- a white lantern post: a brick foot, a pearl post, a glowstone lantern under a gold cap
local function whitePost(x, y, z, parent, lit)
	box(
		"PostFoot",
		x - 1.2,
		y,
		z - 1.2,
		x + 1.2,
		y + 1,
		z + 1.2,
		"px_white_stone_bricks",
		PEARL,
		parent
	)
	box("Post", x - 0.6, y + 1, z - 0.6, x + 0.6, y + 8, z + 0.6, "px_smooth_stone", PEARL, parent)
	local l = dbox(
		"PostLamp",
		x - 1,
		y + 8,
		z - 1,
		x + 1,
		y + 10,
		z + 1,
		"px_glowstone",
		Color3.new(1, 1, 1),
		parent
	)
	dbox(
		"PostCap",
		x - 1.3,
		y + 10,
		z - 1.3,
		x + 1.3,
		y + 10.6,
		z + 1.3,
		"px_gold_block",
		GOLD,
		parent
	)
	if lit then
		glow(l, 28, 1.1, LIGHT)
	end
end
-- a blue-glass fountain cascade: a white basin ring (outer 16·s, one block high) round a pool, a pier with a bowl,
-- glass falling from the bowl's four sides, a gold spout with a glass jet
local function fountain(x, y, z, s, parent, solid)
	local function q(name, x0, y0, z0, x1, y1, z1, variant, tint)
		local p = box(
			name,
			x + x0 * s,
			y + y0 * s,
			z + z0 * s,
			x + x1 * s,
			y + y1 * s,
			z + z1 * s,
			variant,
			tint,
			parent
		)
		return if solid then p else decor(p)
	end
	local function w(name, x0, y0, z0, x1, y1, z1)
		return glass(
			name,
			x + x0 * s,
			y + y0 * s,
			z + z0 * s,
			x + x1 * s,
			y + y1 * s,
			z + z1 * s,
			parent
		)
	end
	q("Basin", -8, 0, -8, 8, 4, -4, "px_smooth_stone", PEARL)
	q("Basin", -8, 0, 4, 8, 4, 8, "px_smooth_stone", PEARL)
	q("Basin", -8, 0, -4, -4, 4, 4, "px_smooth_stone", PEARL)
	q("Basin", 4, 0, -4, 8, 4, 4, "px_smooth_stone", PEARL)
	w("Pool", -4, 0, -4, 4, 3.4, 4)
	q("FountainPier", -2, 0, -2, 2, 10, 2, "px_white_stone_bricks", PEARL)
	q("FountainBowl", -3.5, 10, -3.5, 3.5, 12, 3.5, "px_smooth_stone", PEARL)
	w("BowlWater", -3, 12, -3, 3, 12.5, 3)
	w("Cascade", -2.5, 3.4, -4, 2.5, 12.4, -3.5)
	w("Cascade", -2.5, 3.4, 3.5, 2.5, 12.4, 4)
	w("Cascade", -4, 3.4, -2.5, -3.5, 12.4, 2.5)
	w("Cascade", 3.5, 3.4, -2.5, 4, 12.4, 2.5)
	decor(
		box(
			"FountainSpout",
			x - s,
			y + 12 * s,
			z - s,
			x + s,
			y + 15 * s,
			z + s,
			"px_gold_block",
			GOLD,
			parent
		)
	)
	w("FountainJet", -1.6, 15, -1.6, 1.6, 16.4, 1.6)
end
-- a gold cage pylon (the concept's panel): a brick foot, gold bars round a white core, a white slab, a stepped gold
-- cap and a fire; all decor
local function cagePylon(x, y, z, parent, lit)
	dbox("CageFoot", x - 3, y, z - 3, x + 3, y + 1.5, z + 3, "px_white_stone_bricks", PEARL, parent)
	dbox(
		"CageFloor",
		x - 2.6,
		y + 1.5,
		z - 2.6,
		x + 2.6,
		y + 2.5,
		z + 2.6,
		"px_smooth_stone",
		PEARL,
		parent
	)
	for _, c in ipairs({
		{ -2, -2 },
		{ 0, -2 },
		{ 2, -2 },
		{ 2, 0 },
		{ 2, 2 },
		{ 0, 2 },
		{ -2, 2 },
		{ -2, 0 },
	}) do
		dbox(
			"CageBar",
			x + c[1] - 0.4,
			y + 2.5,
			z + c[2] - 0.4,
			x + c[1] + 0.4,
			y + 9.5,
			z + c[2] + 0.4,
			"px_gold_block",
			GOLD,
			parent
		)
	end
	dbox(
		"CageCore",
		x - 1,
		y + 2.5,
		z - 1,
		x + 1,
		y + 9.5,
		z + 1,
		"px_white_stone_bricks",
		PEARL,
		parent
	)
	dbox(
		"CageTop",
		x - 2.8,
		y + 9.5,
		z - 2.8,
		x + 2.8,
		y + 10.5,
		z + 2.8,
		"px_smooth_stone",
		PEARL,
		parent
	)
	dbox(
		"CageRoof",
		x - 2.2,
		y + 10.5,
		z - 2.2,
		x + 2.2,
		y + 11.5,
		z + 2.2,
		"px_gold_block",
		GOLD,
		parent
	)
	dbox(
		"CageRoof",
		x - 1.4,
		y + 11.5,
		z - 1.4,
		x + 1.4,
		y + 12.5,
		z + 1.4,
		"px_gold_block",
		GOLD,
		parent
	)
	local f = neon("Fire", x - 1, y + 12.5, z - 1, x + 1, y + 14.5, z + 1, FIRE, parent)
	neon("FireCore", x - 0.5, y + 14.5, z - 0.5, x + 0.5, y + 15.5, z + 0.5, FIRE_CORE, parent)
	if lit then
		glow(f, 26, 1.1, FIRE)
	end
end
-- the walkable ways through the air: the bridge corridors x0, x1, z0, z1, y0, y1
local CORRIDORS = {}
for _, b in ipairs(BRIDGES) do
	table.insert(CORRIDORS, { b[1] - 16, b[3] + 16, b[2] - 16, b[4] + 16, -40, 30 })
end
local function inCorridor(x0, x1, z0, z1, y0, y1)
	for _, c in ipairs(CORRIDORS) do
		if
			x1 >= c[1]
			and x0 <= c[2]
			and z1 >= c[3]
			and z0 <= c[4]
			and y1 >= c[5]
			and y0 <= c[6]
		then
			return true
		end
	end
	return false
end
-- no island cell within half + pad studs (horizontally) of (x, z)
local function clearOfIslands(x, z, half, pad)
	if cellLand(x, z) ~= nil then
		return false
	end
	local e = half + pad
	local n = math.max(1, math.ceil(2 * e / 8))
	for i = 0, n do
		for j = 0, n do
			if cellLand(x - e + 2 * e * i / n, z - e + 2 * e * j / n) ~= nil then
				return false
			end
		end
	end
	return true
end
local taken = {} -- floating islets (west side): { x, z, half, y0, y1 }
local FALLS = {} -- waterfall spouts (east side, built with their mirrors): { cx, cz, fx, fz, width in blocks, isle }
local FALL_CELLS = {} -- "cx,cz" of every spout cell, both sides
local FALL_BOXES = {} -- the waterfalls' bounds, both sides: { x0, x1, z0, z1, y0, y1 }
local BRIDGE_END = {} -- A / B: the x of the east deck's end on its islet (the west one mirrors it)

-- ================================================================ the waterfall spouts (found first: props keep off)
do
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	-- the outermost cell of `isle` along a ray and the open face most along the ray
	local function rimCell(isle, ox, oz, dx, dz)
		local lx, lz
		for t = 0, 440, 2 do
			local i, cx, cz = cellLand(ox + dx * t, oz + dz * t)
			if i == isle then
				lx, lz = cx, cz
			end
		end
		if not lx then
			return nil
		end
		local best, bfx, bfz = 0, nil, nil
		for _, d in ipairs(DIRS) do
			local dot = d[1] * dx + d[2] * dz
			if dot > best and cellLand(lx + d[1] * 8, lz + d[2] * 8) == nil then
				best, bfx, bfz = dot, d[1], d[2]
			end
		end
		if not bfx then
			return nil
		end
		return lx, lz, bfx, bfz
	end
	local function add(isle, ox, oz, dx, dz, w)
		local cx, cz, fx, fz = rimCell(isle, ox, oz, dx, dz)
		if not cx or cx <= 0 then
			return
		end
		if isle == "main" and onPath(cx, cz, 4) then
			return
		end
		for _, b in ipairs(BRIDGES) do
			if inRect(cx, cz, b, 12) then
				return
			end
		end
		table.insert(FALLS, { cx, cz, fx, fz, w, isle })
		FALL_CELLS[cx .. "," .. cz] = true
		FALL_CELLS[-cx .. "," .. cz] = true
	end
	for _, z in ipairs({ 150, 116, 20, -24, -64 }) do
		add("main", 0, z, 1, 0, 2)
	end
	add("main", 88, -20, 0, -1, 2) -- the north tip
	for _, s in ipairs({ ISLES[2], ISLES[4] }) do
		for _, a in ipairs({ -40, 40 }) do
			add(s.name, s.x, s.z, math.cos(math.rad(a)), math.sin(math.rad(a)), 1)
		end
	end
end

-- ================================================================ 1. the bridges (the gap measured from the cells)
do
	local bf = folder("Bridges", sky)
	-- the longest run of open sky (core's cells) along z between lo - 24 and hi + 24, 1 stud at a time
	local function gapAlong(z, lo, hi)
		local ga, gb, best, runA = nil, nil, -1, nil
		for xs = lo - 24, hi + 24 do
			if cellLand(xs + 0.5, z) == nil then
				runA = runA or xs
				if xs + 1 - runA > best then
					best, ga, gb = xs + 1 - runA, runA, xs + 1
				end
			else
				runA = nil
			end
		end
		return ga, gb
	end
	for _, key in ipairs({ { 2, "A" }, { 4, "B" } }) do
		local b = BRIDGES[key[1]] -- the east one; the west one is its mirror
		local z0, z1 = b[2], b[4]
		local zm = (z0 + z1) / 2
		local lo, hi = b[1], b[3]
		local ga, gb = gapAlong(zm, lo, hi)
		if not ga then
			ga, gb = lo + 8, hi - 8
		end
		local xa, xb = math.min(lo, ga - 16), math.max(hi, gb + 16)
		BRIDGE_END[key[2]] = xb
		-- the kerbs: over each kerb line's own gap
		local kerbs = {}
		for _, kz in ipairs({ { z0 - B, z0 }, { z1, z1 + B } }) do
			local ka, kb = gapAlong((kz[1] + kz[2]) / 2, lo, hi)
			if not ka then
				ka, kb = ga, gb
			end
			table.insert(kerbs, { kz[1], kz[2], ka, kb })
		end
		-- the keel: deepest under the middle, a block at the island faces
		local under = 0.1 - B
		local nb = math.max(1, math.floor((gb - ga) / B + 0.5))
		local runs = {}
		for k = 0, nb - 1 do
			local t = (k + 0.5) / nb
			local dep = 1 + math.floor((1 - math.abs(2 * t - 1)) * 3 + 0.5)
			local last = runs[#runs]
			if last and last[3] == dep then
				last[2] = ga + (k + 1) * B
			else
				table.insert(runs, { ga + k * B, ga + (k + 1) * B, dep })
			end
		end
		runs[#runs][2] = gb
		print(
			("[build-gate] sky: bridge %s gap x %d..%d (%d studs), deck x %d..%d"):format(
				key[2],
				ga,
				gb,
				gb - ga,
				xa,
				xb
			)
		)
		for _, sx in ipairs(SIDES) do
			local f = folder((if sx < 0 then "West" else "East") .. "Bridge" .. key[2], bf)
			box("BridgeDeck", sx * xa, under, z0, sx * xb, 0.1, z1, "px_cut_sandstone", SAND, f)
			dbox(
				"BridgeRunner",
				sx * (ga - 8),
				0.1,
				zm - 2,
				sx * (gb + 8),
				0.16,
				zm + 2,
				"px_sandstone",
				SAND,
				f
			)
			for _, k in ipairs(kerbs) do
				local kzm = (k[1] + k[2]) / 2
				box(
					"BridgeKerb",
					sx * k[3],
					under,
					k[1],
					sx * k[4],
					1.1,
					k[2],
					"px_smooth_stone",
					PEARL,
					f
				)
				torch(sx * (k[3] + 2), 1.1, kzm, 1, f, true, false)
				torch(sx * (k[4] - 2), 1.1, kzm, 1, f, true, false)
				if k[4] - k[3] > 12 then
					fence(sx * (k[3] + 4), kzm, sx * (k[4] - 4), kzm, f, 1.1)
				end
			end
			for _, r in ipairs(runs) do
				if r[3] > 1 then
					dbox(
						"BridgeKeel",
						sx * r[1],
						under - (r[3] - 1) * B,
						z0 + 1,
						sx * r[2],
						under,
						z1 - 1,
						"px_white_stone_bricks",
						PEARL,
						f
					)
				end
				dbox(
					"BridgeKeel",
					sx * r[1],
					under - r[3] * B,
					z0 + 3,
					sx * r[2],
					under - (r[3] - 1) * B,
					z1 - 3,
					"px_smooth_stone",
					STONE_LOW,
					f
				)
			end
		end
	end
end
task.wait()

-- ================================================================ 2-3. the islets: the pavilions, the pylon monuments
do
	-- free ground for a prop of half-size `half` at (x, z) on `isle` (east coords): its corners on the islet's cells,
	-- off the keep-out rects and `gap` from the props already placed
	local function freeSpot(isle, x, z, half, keep, placed, gap)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 }, { 0, 0 } }) do
			if
				cellLand(x + c[1] * (half + 2), z + c[2] * (half + 2)) ~= isle
				or isleOf(x + c[1] * half, z + c[2] * half, 3) ~= isle
			then
				return false
			end
		end
		for _, r in ipairs(keep) do
			if inRect(x, z, r, half + 2) then
				return false
			end
		end
		for _, p in ipairs(placed) do
			if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < gap * gap then
				return false
			end
		end
		return true
	end
	-- n cypress spots (east coords) on islet s, drawn once for both sides
	local function cypressSpots(s, keep, n)
		for _, fl in ipairs(FALLS) do
			if fl[6] == s.name then
				table.insert(keep, { fl[1] - 8, fl[2] - 8, fl[1] + 8, fl[2] + 8 })
			end
		end
		local cands = {}
		for gx = -s.r, s.r, 4 do
			for gz = -s.r, s.r, 4 do
				table.insert(cands, { s.x + gx, s.z + gz })
			end
		end
		for i = #cands, 2, -1 do
			local j = rng:NextInteger(1, i)
			cands[i], cands[j] = cands[j], cands[i]
		end
		local out = {}
		for _, c in ipairs(cands) do
			if #out >= n then
				break
			end
			if freeSpot(s.name, c[1], c[2], 4, keep, out, 13) then
				table.insert(out, { c[1], c[2], rng:NextInteger(3, 5) })
			end
		end
		return out
	end

	-- true when the rect (east coords) lies on islet cells of `isle`
	local function onIsle(isle, x0, z0, x1, z1)
		for _, c in ipairs({ { x0, z0 }, { x1, z0 }, { x1, z1 }, { x0, z1 } }) do
			if cellLand(c[1], c[2]) ~= isle then
				return false
			end
		end
		return true
	end
	-- the islets A: the pavilion at (256, 60), the fountain at (240, 80) (east coords)
	local landA = BRIDGE_END.A or 216
	local treesA = cypressSpots(ISLES[2], {
		{ landA - 40, 48, 268, 72 }, -- the landing, the walk, the pavilion
		{ 230, 70, 250, 90 }, -- the fountain
		{ 234, 43, 246, 48 }, -- the north bench
		{ 210, 71, 222, 76 }, -- the south bench
		{ 226, 45, 230, 75 }, -- the lantern posts
	}, 8)
	local function pavilion(x, z, f)
		box("PavilionFloor", x - 9, 0, z - 9, x + 9, 0.2, z + 9, "px_gold_block", GOLD, f)
		box("PavilionFloor", x - 7, 0, z - 7, x + 7, 0.3, z + 7, "px_smooth_stone", PEARL, f)
		for _, cx in ipairs({ -6, 6 }) do
			for _, cz in ipairs({ -6, 6 }) do
				box(
					"PavilionColumn",
					x + cx - 2,
					0,
					z + cz - 2,
					x + cx + 2,
					12,
					z + cz + 2,
					"px_smooth_stone",
					PEARL,
					f
				)
				dbox(
					"PavilionCapital",
					x + cx - 2.5,
					10.8,
					z + cz - 2.5,
					x + cx + 2.5,
					12,
					z + cz + 2.5,
					"px_gold_block",
					GOLD,
					f
				)
			end
		end
		box("PavilionBeam", x - 9, 12, z - 9, x + 9, 13.5, z + 9, "px_smooth_stone", PEARL, f)
		dbox(
			"PavilionBand",
			x - 9.4,
			13.5,
			z - 9.4,
			x + 9.4,
			14.5,
			z + 9.4,
			"px_gold_block",
			GOLD,
			f
		)
		-- the gold-barred upper storey round a glowstone core
		for i = -2, 2 do
			for j = -2, 2 do
				if math.abs(i) == 2 or math.abs(j) == 2 then
					local bx, bz = x + i * 3.75, z + j * 3.75
					dbox(
						"CageBar",
						bx - 0.6,
						14.5,
						bz - 0.6,
						bx + 0.6,
						22.5,
						bz + 0.6,
						"px_gold_block",
						GOLD,
						f
					)
				end
			end
		end
		dbox(
			"CagePedestal",
			x - 2,
			14.5,
			z - 2,
			x + 2,
			16.5,
			z + 2,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		local core = dbox(
			"CageLight",
			x - 2,
			16.5,
			z - 2,
			x + 2,
			20.5,
			z + 2,
			"px_glowstone",
			Color3.new(1, 1, 1),
			f
		)
		glow(core, 34, 1.3, LIGHT)
		dbox(
			"CagePedestal",
			x - 2,
			20.5,
			z - 2,
			x + 2,
			22.5,
			z + 2,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		dbox("PavilionTop", x - 9, 22.5, z - 9, x + 9, 24, z + 9, "px_smooth_stone", PEARL, f)
		dbox("PavilionBand", x - 9.4, 24, z - 9.4, x + 9.4, 25, z + 9.4, "px_gold_block", GOLD, f)
		-- the stepped gold roof and the fire
		for k, h in ipairs({ 8, 6, 4, 2 }) do
			local y0 = 25 + (k - 1) * 2
			dbox("PavilionRoof", x - h, y0, z - h, x + h, y0 + 2, z + h, "px_gold_block", GOLD, f)
		end
		dbox(
			"PavilionBrazier",
			x - 2,
			33,
			z - 2,
			x + 2,
			34,
			z + 2,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		neon("Fire", x - 1.4, 34, z - 1.4, x + 1.4, 36.5, z + 1.4, FIRE, f)
		neon("FireCore", x - 0.7, 36.5, z - 0.7, x + 0.7, 38, z + 0.7, FIRE_CORE, f)
	end
	for _, sx in ipairs(SIDES) do
		local f = folder(if sx < 0 then "WestA" else "EastA", sky)
		pavilion(sx * 256, 60, f)
		fountain(sx * 240, 0, 80, 1, f, true)
		dbox("IsletWalk", sx * landA, 0, 56, sx * 247, 0.06, 64, "px_cut_sandstone", SAND, f)
		for _, bn in ipairs({ { 240, 45.5 }, { 216, 73.5 } }) do
			if onIsle("eastA", bn[1] - 4, bn[2] - 1.5, bn[1] + 4, bn[2] + 1.5) then
				bench(sx * bn[1], 0, bn[2], true, f)
			end
		end
		whitePost(sx * 228, 0, 47, f, true)
		whitePost(sx * 228, 0, 73, f, false)
		for _, t in ipairs(treesA) do
			cypress(sx * t[1], 0, t[2], t[3], f, true)
		end
	end
	task.wait()

	-- the islets B: the torch pylon monument at (220, -120) on its dais (east coords)
	local landB = BRIDGE_END.B or 200
	local treesB = cypressSpots(ISLES[4], {
		{ landB - 40, -136, 240, -104 }, -- the landing, the walk, the dais, the posts
		{ 212, -144, 228, -96 }, -- the benches
	}, 5)
	local function monument(x, z, f)
		box("Dais", x - 12, 0, z - 12, x + 12, 1.5, z + 12, "px_white_stone_bricks", PEARL, f)
		box("Dais", x - 9, 1.5, z - 9, x + 9, 3, z + 9, "px_smooth_stone", PEARL, f)
		box("PylonPlinth", x - 6, 3, z - 6, x + 6, 5, z + 6, "px_white_stone_bricks", PEARL, f)
		box("PylonShaft", x - 4, 5, z - 4, x + 4, 41, z + 4, "px_smooth_stone", PEARL, f)
		dbox("PylonBand", x - 4.4, 8, z - 4.4, x + 4.4, 10, z + 4.4, "px_prismarine", JASPER, f)
		dbox("PylonBand", x - 4.4, 33, z - 4.4, x + 4.4, 35, z + 4.4, "px_prismarine", JASPER, f)
		box("PylonCapital", x - 5.5, 41, z - 5.5, x + 5.5, 43, z + 5.5, "px_gold_block", GOLD, f)
		dbox(
			"PylonBrazier",
			x - 6,
			43,
			z - 6,
			x + 6,
			44.5,
			z + 6,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		local fire = neon("Fire", x - 3.5, 44.5, z - 3.5, x + 3.5, 49, z + 3.5, FIRE, f)
		neon("FireCore", x - 1.8, 49, z - 1.8, x + 1.8, 52, z + 1.8, FIRE_CORE, f)
		glow(fire, 40, 1.4, FIRE)
		-- a yellow banner with a white sun on each face
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local function fb(name, n0, n1, y0, y1, t0, t1, variant, tint)
				if d[1] ~= 0 then
					return dbox(
						name,
						x + d[1] * n0,
						y0,
						z + t0,
						x + d[1] * n1,
						y1,
						z + t1,
						variant,
						tint,
						f
					)
				end
				return dbox(
					name,
					x + t0,
					y0,
					z + d[2] * n0,
					x + t1,
					y1,
					z + d[2] * n1,
					variant,
					tint,
					f
				)
			end
			fb("BannerPole", 4, 5, 30, 31, -4, 4, "px_dark_oak_planks", nil)
			fb("Banner", 4, 4.4, 17, 30, -3, 3, "px_yellow_wool", GOLD)
			fb("BannerHem", 4, 4.5, 16, 17, -3, 3, "px_gold_block", GOLD)
			fb("BannerSunRay", 4.4, 4.6, 20.5, 27.5, -0.6, 0.6, "px_white_wool", PEARL)
			fb("BannerSunRay", 4.4, 4.6, 23.4, 24.6, -2.6, 2.6, "px_white_wool", PEARL)
			fb("BannerSun", 4.6, 4.9, 22.5, 25.5, -1.5, 1.5, "px_white_wool", PEARL)
		end
	end
	for _, sx in ipairs(SIDES) do
		local f = folder(if sx < 0 then "WestB" else "EastB", sky)
		monument(sx * 220, -120, f)
		torch(sx * 204, 0, -135, 0.75, f, true, false)
		torch(sx * 204, 0, -105, 0.75, f, true, false)
		dbox("IsletWalk", sx * landB, 0, -124, sx * 208, 0.06, -116, "px_cut_sandstone", SAND, f)
		for _, bz in ipairs({ -100.5, -139.5 }) do
			if onIsle("eastB", 216, bz - 1.5, 224, bz + 1.5) then
				bench(sx * 220, 0, bz, true, f)
			end
		end
		whitePost(sx * 236, 0, -110, f, true)
		whitePost(sx * 236, 0, -130, f, false)
		for _, t in ipairs(treesB) do
			cypress(sx * t[1], 0, t[2], t[3], f, true)
		end
	end
	print(("[build-gate] sky: islets A %d cypresses each, islets B %d"):format(#treesA, #treesB))
end
task.wait()

-- ================================================================ 4. the blue-glass waterfalls
do
	local wf = folder("Waterfalls", sky)
	for _, fl in ipairs(FALLS) do
		local cx0, cz, fx0, fz, wb = fl[1], fl[2], fl[3], fl[4], fl[5]
		local top = colTop(cx0, cz)
		local low = colBottom(cx0, cz) - 12
		local hw = wb * B / 2
		for _, sx in ipairs(SIDES) do
			local cx, fx = sx * cx0, sx * fx0
			-- the corners x0, z0, x1, z1 of a box by its offsets along the face normal (n, outward from the cell's
			-- face) and along the face (t, centred on the cell)
			local function nb(n0, n1, t0, t1)
				if fx ~= 0 then
					local e = cx + fx * 4
					return e + fx * n0, cz + t0, e + fx * n1, cz + t1
				end
				local e = cz + fz * 4
				return cx + t0, e + fz * n0, cx + t1, e + fz * n1
			end
			local f = folder("Waterfall", wf)
			local x0, z0, x1, z1 = nb(-5, 0.8, -hw - 1, hw + 1)
			dbox("FallSpout", x0, top, z0, x1, top + 1, z1, "px_white_stone_bricks", PEARL, f)
			x0, z0, x1, z1 = nb(-4, 0.8, -hw, hw)
			glass("FallPool", x0, top + 1, z0, x1, top + 1.5, z1, f)
			-- the stepped fall: segments 16–20 studs, each a little further out, every other one a stud narrower
			local y, seg = top + 1.5, 0
			while y > low + 0.5 do
				local yb = math.max(low, y - (if seg % 2 == 0 then 20 else 16))
				local n0 = 0.2 + math.min(seg, 4) * 0.7
				local h = hw - (seg % 2)
				x0, z0, x1, z1 = nb(n0, n0 + 2.4, -h, h)
				glass("Waterfall", x0, yb, z0, x1, y + 0.3, z1, f)
				y, seg = yb, seg + 1
			end
			x0, z0, x1, z1 = nb(-1, 7, -hw - 1, hw + 1)
			dbox("Foam", x0, low - 3, z0, x1, low + 1, z1, "px_white_wool", CLOUD, f).CastShadow =
				false
			table.insert(FALL_BOXES, {
				math.min(x0, x1),
				math.max(x0, x1),
				math.min(z0, z1),
				math.max(z0, z1),
				low - 3,
				top + 2,
			})
			x0, z0, x1, z1 = nb(0.5, 5.5, -hw, hw)
			dbox("Foam", x0, low + 1, z0, x1, low + 3, z1, "px_white_wool", CLOUD, f).CastShadow =
				false
		end
	end
	print(("[build-gate] sky: waterfalls %d"):format(#FALLS * 2))
end
task.wait()

-- ================================================================ 5. white stalactites under the islands
do
	local hang = folder("Stalactites", sky)
	local s0 = count
	local cols = 0
	local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local function skip(cx, cz)
		for _, b in ipairs(BRIDGES) do
			if inRect(cx, cz, b, 16) then
				return true
			end
		end
		return FALL_CELLS[cx .. "," .. cz] ~= nil
	end
	-- one column (west side, x0..x0 + s) and its mirror, s studs square from `top` down `len`, a gold tip when `tip`
	local function column(x0, z0, s, top, len, tip)
		local brick = rng:NextNumber() < 0.6
		local v, t =
			if brick then "px_white_stone_bricks" else "px_smooth_stone",
			if brick then PEARL else STONE_LOW
		for _, sx in ipairs(SIDES) do
			dbox("Stalactite", sx * x0, top - len, z0, sx * (x0 + s), top, z0 + s, v, t, hang)
			if tip then
				local ts = math.min(s, B)
				local tx, tz = x0 + (s - ts) / 2, z0 + (s - ts) / 2
				dbox(
					"StalactiteTip",
					sx * tx,
					top - len - B,
					tz,
					sx * (tx + ts),
					top - len,
					tz + ts,
					"px_gold_block",
					GOLD,
					hang
				)
			end
		end
		cols += 2
	end
	for z = -240, 192, 8 do
		for x = -288, -8, 8 do
			local cx, cz = x + 4, z + 4
			if cellLand(cx, cz) ~= nil and not skip(cx, cz) and count - s0 < 800 then
				local bottom = colBottom(cx, cz)
				local outX, outZ, rim = 0, 0, false
				for _, d in ipairs(DIRS4) do
					if cellLand(cx + d[1] * 8, cz + d[2] * 8) == nil then
						rim = true
						outX += d[1]
						outZ += d[2]
					end
				end
				if rng:NextNumber() < (if rim then 0.5 else 0.06) then
					if not rim then
						-- a fat 2×2 column and a 1×1 under one quarter of it
						local len = rng:NextInteger(3, 8) * B
						column(x, z, 2 * B, bottom + 2, len + 2, false)
						column(
							x + rng:NextInteger(0, 1) * B,
							z + rng:NextInteger(0, 1) * B,
							B,
							bottom - len,
							rng:NextInteger(1, 4) * B,
							rng:NextNumber() < 0.35
						)
					else
						-- a 1×1 column on the outer quarter of a rim cell, sometimes a shorter one beside it
						local qx = if outX > 0
							then 1
							elseif outX < 0 then 0
							else rng:NextInteger(0, 1)
						local qz = if outZ > 0
							then 1
							elseif outZ < 0 then 0
							else rng:NextInteger(0, 1)
						local len = rng:NextInteger(2, 10)
						if rng:NextNumber() < 0.08 then
							len = 12
						end
						column(
							x + qx * B,
							z + qz * B,
							B,
							bottom + 2,
							len * B + 2,
							rng:NextNumber() < 0.25
						)
						if len > 4 and rng:NextNumber() < 0.3 then
							local q2x, q2z = 1 - qx, qz
							if outX == 0 then
								q2x, q2z = qx, 1 - qz
							end
							column(
								x + q2x * B,
								z + q2z * B,
								B,
								bottom + 2,
								rng:NextInteger(1, len - 3) * B + 2,
								false
							)
						end
					end
				end
			end
		end
		if z % 64 == 0 then
			task.wait()
		end
	end
	print(("[build-gate] sky: stalactites %d, %d parts"):format(cols, count - s0))
end
task.wait()

-- ================================================================ 6. floating white islets (mirrored pairs)
do
	local fly = folder("FloatingIslets", sky)
	local f0 = count
	-- a spot on the west side: off the islands (24), out of the bridge corridors and the beacon's sky, apart
	local function findSpot(half, down, up)
		for attempt = 1, 600 do
			if attempt % 150 == 0 then
				task.wait()
			end
			local x, z = rng:NextNumber(-420, -half - 12), rng:NextNumber(-330, 330)
			local y = rng:NextNumber(-60, 80)
			local ok = not inCorridor(x - half, x + half, z - half, z + half, y - down, y + up)
				and not (z - half < -200 and math.abs(x) - half < 60)
				and clearOfIslands(x, z, half, 24)
			if ok then
				for _, t in ipairs(taken) do
					local dh = math.sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2)
					if dh < t[3] + half + 12 and y + up + 8 > t[4] and y - down - 8 < t[5] then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(taken, { x, z, half, y - down, y + up })
				return x, y, z
			end
		end
		return nil
	end
	local PROPS = { "pylon", "cage", "fountain", "cypress", "pylon", "cage", "cypress" }
	local made, lit = 0, 0
	for i, prop in ipairs(PROPS) do
		local w = if i <= 2 then rng:NextInteger(5, 6) else rng:NextInteger(3, 5)
		if prop == "fountain" then
			w = math.max(w, 4)
		end
		local d = math.clamp(w + rng:NextInteger(-1, 1), 3, 6)
		-- the stepped cone below the top: each layer a block narrower, 1–2 blocks high
		local layers = {}
		local cw, cd, down = w, d, B
		while cw > 1 or cd > 1 do
			cw, cd = math.max(1, cw - 1), math.max(1, cd - 1)
			local h = rng:NextInteger(1, 2)
			table.insert(layers, { cw, cd, h })
			down += h * B
		end
		down += 2 * B -- the tip
		local half = math.max(w, d) * B / 2
		local x, y, z = findSpot(half, down, 20)
		if x then
			x, y, z = snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2
			local hx, hz = w * B / 2, d * B / 2
			-- the layers' offsets, drawn once for both sides
			local rects = {}
			local ax, az, aw, ad, top = x - hx, z - hz, w, d, y - B
			for li, l in ipairs(layers) do
				local nx = ax + rng:NextInteger(0, aw - l[1]) * B
				local nz = az + rng:NextInteger(0, ad - l[2]) * B
				local brick = li % 2 == 1
				table.insert(
					rects,
					{ nx, top - l[3] * B, nz, nx + l[1] * B, top, nz + l[2] * B, brick }
				)
				ax, az, aw, ad, top = nx, nz, l[1], l[2], top - l[3] * B
			end
			local lightIt = (prop == "cage") and lit < 1
			if lightIt then
				lit += 1
			end
			for _, sx in ipairs(SIDES) do
				local f = folder("Islet", fly)
				local px = sx * x
				dbox(
					"IsletTop",
					sx * (x - hx),
					y - B,
					z - hz,
					sx * (x + hx),
					y,
					z + hz,
					"px_smooth_stone",
					PEARL,
					f
				)
				for _, r in ipairs(rects) do
					dbox(
						"IsletRock",
						sx * r[1],
						r[2],
						r[3],
						sx * r[4],
						r[5],
						r[6],
						if r[7] then "px_white_stone_bricks" else "px_smooth_stone",
						if r[7] then PEARL else STONE_LOW,
						f
					)
				end
				dbox(
					"IsletTip",
					sx * ax,
					top - 2 * B,
					az,
					sx * (ax + B),
					top,
					az + B,
					"px_white_stone_bricks",
					PEARL,
					f
				)
				if prop == "pylon" then
					torch(px, y, z, 1, f, false, false)
				elseif prop == "cage" then
					cagePylon(px, y, z, f, lightIt)
				elseif prop == "fountain" then
					fountain(px, y, z, 0.6, f, false)
				else
					cypress(px, y, z, 3, f, false)
				end
			end
			made += 2
		end
	end
	print(("[build-gate] sky: floating islets %d, %d parts"):format(made, count - f0))
end
task.wait()

-- ================================================================ 7. the sea of clouds (mirrored pairs)
do
	local cl = folder("Clouds", sky)
	local k0 = count
	local nLayer, nRim, nHigh, nSteps = 0, 0, 0, 0
	local placed = {} -- west-side clouds: { x0, x1, z0, z1, y0, y1 }
	local function cb(x0, y0, z0, x1, y1, z1)
		for _, sx in ipairs(SIDES) do
			dbox("Cloud", sx * x0, y0, z0, sx * x1, y1, z1, "px_white_wool", CLOUD, cl).CastShadow =
				false
		end
	end
	-- a flat puff: a base slab th blocks thick, one or two smaller slabs on it, sometimes one under it
	local function cloud(x, yb, z, w, d, th)
		local hx, hz = w * B / 2, d * B / 2
		cb(x - hx, yb, z - hz, x + hx, yb + th * B, z + hz)
		for _ = 1, rng:NextInteger(1, 2) do
			local pw = rng:NextInteger(math.max(2, w // 3), math.max(2, w - 2))
			local pd = rng:NextInteger(math.max(2, d // 3), math.max(2, d - 2))
			local ox = B * rng:NextInteger(0, math.max(0, w - pw)) - hx
			local oz = B * rng:NextInteger(0, math.max(0, d - pd)) - hz
			cb(x + ox, yb + th * B, z + oz, x + ox + pw * B, yb + th * B + B, z + oz + pd * B)
		end
		if w >= 8 and rng:NextNumber() < 0.5 then
			local pw, pd = math.max(2, w // 2), math.max(2, d // 2)
			local ox = B * rng:NextInteger(0, w - pw) - hx
			local oz = B * rng:NextInteger(0, d - pd) - hz
			cb(x + ox, yb - B, z + oz, x + ox + pw * B, yb, z + oz + pd * B)
		end
	end
	local function overlaps(x0, x1, z0, z1, y0, y1)
		for _, list in ipairs({ placed, FALL_BOXES }) do
			for _, p in ipairs(list) do
				if
					x1 + 10 > p[1]
					and x0 - 10 < p[2]
					and z1 + 10 > p[3]
					and z0 - 10 < p[4]
					and y1 + 6 > p[5]
					and y0 - 6 < p[6]
				then
					return true
				end
			end
		end
		for _, t in ipairs(taken) do
			local e = math.max(x1 - x0, z1 - z0) / 2
			local dh = math.sqrt(((x0 + x1) / 2 - t[1]) ^ 2 + ((z0 + z1) / 2 - t[2]) ^ 2)
			if dh < t[3] + e + 8 and y1 + 8 > t[4] and y0 - 8 < t[5] then
				return true
			end
		end
		return false
	end
	-- true when an island column over the rect reaches down to 4 studs over y1 (the cloud would sit inside it)
	local function columnsReach(x0, x1, z0, z1, y1)
		local nx, nz = math.max(1, math.ceil((x1 - x0) / 8)), math.max(1, math.ceil((z1 - z0) / 8))
		for i = 0, nx do
			for j = 0, nz do
				local isle, cx, cz = cellLand(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz)
				if isle and colBottom(cx, cz) <= y1 + 4 then
					return true
				end
			end
		end
		return false
	end
	-- a cloud whose top is at `top` (west side, wholly west of x -6) if it fits
	local function try(x, top, z, w, d, th)
		local hx, hz = w * B / 2, d * B / 2
		if x + hx > -6 then
			return false
		end
		local yb = top - (th + 1) * B
		local y0, y1 = yb - B, top
		if
			inCorridor(x - hx, x + hx, z - hz, z + hz, y0, y1)
			or overlaps(x - hx, x + hx, z - hz, z + hz, y0, y1)
			or columnsReach(x - hx, x + hx, z - hz, z + hz, y1)
		then
			return false
		end
		cloud(x, yb, z, w, d, th)
		table.insert(placed, { x - hx, x + hx, z - hz, z + hz, y0, y1 })
		return true
	end
	-- the broken layer under the islands: big puffs, tops y -60..-90
	for _ = 1, 20 do
		for attempt = 1, 60 do
			local w = rng:NextInteger(8, 22)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 4, 16)
			local th = rng:NextInteger(1, 2)
			local x = snap(rng:NextNumber(-400, -w * 2 - 6)) + (w % 2) * 2
			local z = snap(rng:NextNumber(-360, 360)) + (d % 2) * 2
			local top = snap(rng:NextNumber(-90, -60))
			if try(x, top, z, w, d, th) then
				nLayer += 2
				break
			end
			if attempt % 30 == 0 then
				task.wait()
			end
		end
	end
	task.wait()
	-- puffs round the main island just under its rim (tops y -10..-40), pushed out along rays until clear
	for i = 0, 7 do
		local a = math.rad(100 + i * 160 / 7 + rng:NextNumber(-6, 6))
		local w = rng:NextInteger(5, 9)
		local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 3, 7)
		local th = rng:NextInteger(1, 2)
		local top = snap(rng:NextNumber(-40, -10))
		for rr = 150, 260, 6 do
			local x = snap(math.cos(a) * rr * 0.85) + (w % 2) * 2
			local z = snap(ISLAND.z + math.sin(a) * rr) + (d % 2) * 2
			if clearOfIslands(x, z, math.max(w, d) * B / 2, 6) and try(x, top, z, w, d, th) then
				nRim += 2
				break
			end
		end
	end
	task.wait()
	-- a few high puffs, clear of the islands
	for _ = 1, 3 do
		for _ = 1, 60 do
			local w = rng:NextInteger(5, 10)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.4, 0.8)), 3, 7)
			local th = rng:NextInteger(1, 2)
			local x = snap(rng:NextNumber(-400, -w * 2 - 6)) + (w % 2) * 2
			local z = snap(rng:NextNumber(-340, 340)) + (d % 2) * 2
			local top = snap(rng:NextNumber(56, 130))
			if clearOfIslands(x, z, math.max(w, d) * B / 2, 24) and try(x, top, z, w, d, th) then
				nHigh += 2
				break
			end
		end
	end
	-- the cloud steps: two small flat stepping clouds off each islet, going down and away (west islets, mirrored)
	for _, st in ipairs({ { ISLES[1], -130 }, { ISLES[3], 130 } }) do
		local s, a = st[1], math.rad(st[2])
		local dx, dz = math.cos(a), math.sin(a)
		local dist = s.r + 8
		for k = 1, 2 do
			local x, z
			repeat
				x, z = snap(s.x + dx * dist) + 2, snap(s.z + dz * dist)
				dist += 4
			until clearOfIslands(x, z, 6, 2) or dist > s.r + 60
			local yb = -4 - k * 6
			if not inCorridor(x - 6, x + 6, z - 4, z + 4, yb, yb + B) then
				cb(x - 6, yb, z - 4, x + 6, yb + B, z + 4)
				table.insert(placed, { x - 6, x + 6, z - 4, z + 4, yb, yb + B })
				nSteps += 2
			end
			dist += 8
		end
	end
	print(
		("[build-gate] sky: clouds %d layer, %d rim, %d high, %d steps, %d parts"):format(
			nLayer,
			nRim,
			nHigh,
			nSteps,
			count - k0
		)
	)
end
print(("[build-gate] sky: %d parts, %d lights"):format(count - c0, lights))
