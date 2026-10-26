--!nocheck
-- ================================================================ paradise: the sky (the islets, the bridges, the air)
-- Everything here is strictly mirror-symmetric in x: each piece is decided once (every rng draw outside the side
-- loop) and built for sx = -1 and sx = 1. The bundler wraps this file in its own do … end.
-- 1. THE BRIDGES over BRIDGES (W/E x ±228..±264 z -8..8; NW/NE and SW/SE x ±150..±200 at z ∓184..∓168): the gap is
--    measured from core's 8-stud cells along the deck's centre line and both edge lines, the deck runs 12+ studs onto
--    both islands' ground at every line; a white deck 4 blocks wide (top y 0.1) with a quartz runner, quartz
--    balustrades over each edge line's own gap only (posts with gold caps, open at the ends), a white column with a
--    lantern at both ends of each balustrade, a stepped white keel deepest under the middle.
-- 2. THE ISLETS W/E (±296, 0): a white domed gazebo 5×5 blocks at (±304, 0) (white columns, a stepped white dome
--    with gold ribs and a gold tip, a hanging lantern, a blue-glass fountain in a white basin inside), a quartz walk
--    from the landing (z -8..8), two benches, two lantern posts, white birches and red flower beds round it.
-- 3. THE ISLETS NW/NE (±226, -176): a tall white end-rod spire (≈ 12 blocks, a white Neon rod on top) on a stepped
--    dais at (±236, -176); SW/SE (±226, 176): a small domed gazebo 3×3 blocks at (±236, 176) with a lantern;
--    a birch, red flower beds and a bench on each; the bridge walk stays clear.
-- 4. Blue-glass waterfalls from small white spouts on rim cells (the outermost cell along a ray, the face = the cell
--    edge) down to 20 studs under the column bottom, a wool foam puff there: 5 mirrored pairs off the main island's
--    rim (rays at -84°, -62°, -24°, 24°, 68° from +x; none near the south axis, a walk or a bridge) and two on every
--    islet at ±40° from the direction away from the main island.
-- 5. White stalactites under every island (core's cells and rockDepth), sparse inside, denser on the rim, a few
--    gold tips; none under the bridges and the waterfall cells.
-- 6. Floating white islets (stepped cones) in mirrored pairs with a small gazebo, a birch, a fountain, an end-rod
--    spire or a waterfall: 24+ studs off every island, out of the bridge corridors, 30+ off the pillar of light.
-- 7. The shining cloud sea: a broken layer of white wool puffs (tops y -60..-100) under and round the islands (never
--    inside an island column), puffs round the rim (y -10..-40) and a few high puffs.
local sky = folder("Sky")
local c0 = count
local lights = 0 -- PointLights of this part (≤ 12, planned in pairs: 6 bridges, 2 gazebos W/E, 2 spires, 2 small gazebos)
local SIDES = { -1, 1 }

-- the island cell (core's 8-stud grid over x -352..352, z -248..248) holding a point: its island and centre
local function cellLand(x, z)
	if x < -352 or x >= 352 or z < -248 or z >= 248 then
		return nil
	end
	local cx = -352 + 8 * math.floor((x + 352) / 8) + 4
	local cz = -248 + 8 * math.floor((z + 248) / 8) + 4
	return isleOf(cx, cz), cx, cz
end
-- core's rockDepth (10-core is wrapped in its own do … end, so it is replicated here exactly)
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
-- a land cell's column: its top (groundY) and its bottom (top - ground block - rock, rounded like core's island())
local function colTop(cx, cz)
	return groundY(cx, cz) or 0
end
local function colBottom(cx, cz)
	return colTop(cx, cz) - B - math.floor(rockDepth(cx, cz) / B + 0.5) * B
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
local function glow(p, range, brightness, color)
	if lights < 12 then
		lights += 1
		light(p, range, brightness, color)
	end
end
-- the kit lantern (iron frame, glowing core) at local (x, y, z); only a lit one keeps its PointLight; hangTop
-- (local y) hangs it on a chain
local function lamp(x, y, z, parent, lit, hangTop)
	local f = folder("Lantern", parent)
	lantern(V(x, y, z), f, false, if hangTop then BY + hangTop else nil)
	local pl = f:FindFirstChildWhichIsA("PointLight", true)
	if pl then
		if lit and lights < 12 then
			lights += 1
		else
			pl:Destroy()
		end
	end
end
-- a white lantern post: a quartz foot, a white post, a gold plate and a lantern on top
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
		QUARTZ,
		parent
	)
	box("Post", x - 0.6, y + 1, z - 0.6, x + 0.6, y + 7, z + 0.6, "px_smooth_stone", WHITE, parent)
	dbox(
		"PostPlate",
		x - 0.9,
		y + 7,
		z - 0.9,
		x + 0.9,
		y + 7.4,
		z + 0.9,
		"px_gold_block",
		GOLD,
		parent
	)
	lamp(x, y + 8.15, z, parent, lit)
end
-- a white bench 2 blocks long (along x or z): two quartz legs and a white seat
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
			QUARTZ,
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
		WHITE,
		parent
	)
end
-- a red flower bed: a quartz planter 2×1 blocks, a leafy top and three red flowers (sx mirrors the pattern)
local function flowerBed(x, y, z, alongX, parent, sx)
	local lx, lz = if alongX then 4 else 2, if alongX then 2 else 4
	box(
		"Planter",
		x - lx,
		y,
		z - lz,
		x + lx,
		y + 1.5,
		z + lz,
		"px_white_stone_bricks",
		QUARTZ,
		parent
	)
	dbox(
		"FlowerLeaves",
		x - lx + 0.5,
		y + 1.5,
		z - lz + 0.5,
		x + lx - 0.5,
		y + 2.5,
		z + lz - 0.5,
		"px_hedge",
		LEAF,
		parent
	)
	for k, t in ipairs({ -2.5, 0, 2.5 }) do
		local c = if k == 2 then -0.7 else 0.7
		local fx, fz = if alongX then t else c * sx, if alongX then c else t
		dbox(
			"Flower",
			x + fx - 0.8,
			y + 2.5,
			z + fz - 0.8,
			x + fx + 0.8,
			y + 3.9,
			z + fz + 0.8,
			"px_white_wool",
			SCARLET,
			parent
		)
	end
end
-- a white birch: a birch-log trunk 1 block wide, a stepped crown of white wool; spec = { h, loose = {{ox, oy, oz}} }
-- (drawn once with birchSpec, sx mirrors the loose blocks)
local function birchSpec(h)
	local loose = {}
	for _ = 1, 3 do
		local side = rng:NextInteger(1, 4)
		local a = rng:NextInteger(-1, 1) * 4
		local ox = if side == 1 then -10 elseif side == 2 then 10 else a
		local oz = if side == 3 then -10 elseif side == 4 then 10 else a
		table.insert(loose, { ox, rng:NextInteger(-1, 0), oz })
	end
	return { h = h, loose = loose }
end
local function birch(x, y, z, spec, parent, solid, sx)
	local h = spec.h
	local t = box(
		"BirchTrunk",
		x - 2,
		y,
		z - 2,
		x + 2,
		y + (h + 1) * B,
		z + 2,
		"px_birch_log",
		BIRCH,
		parent
	)
	if not solid then
		decor(t)
	end
	local c = y + (h - 1) * B
	dbox("BirchCrown", x - 8, c, z - 8, x + 8, c + 2 * B, z + 8, "px_white_wool", SNOW, parent)
	dbox(
		"BirchCrown",
		x - 6,
		c + 2 * B,
		z - 6,
		x + 6,
		c + 3 * B,
		z + 6,
		"px_white_wool",
		SNOW,
		parent
	)
	dbox(
		"BirchCrown",
		x - 2,
		c + 3 * B,
		z - 2,
		x + 2,
		c + 4 * B,
		z + 2,
		"px_white_wool",
		SNOW,
		parent
	)
	for _, l in ipairs(spec.loose) do
		local lx, ly, lz = x + sx * l[1], c + B + l[2] * B, z + l[3]
		dbox(
			"BirchCrown",
			lx - 2,
			ly,
			lz - 2,
			lx + 2,
			ly + B,
			lz + 2,
			"px_white_wool",
			SNOW,
			parent
		)
	end
end
-- a blue-glass fountain: a white basin ring (half `half`, 2.5 high) round a pool, a quartz pier `pierH` high with a
-- bowl, glass falling from the bowl's four sides, a gold spout with a glass jet
local function fountain(x, y, z, half, pierH, parent, solid)
	local function q(name, x0, y0, z0, x1, y1, z1, variant, tint)
		local p = box(name, x + x0, y + y0, z + z0, x + x1, y + y1, z + z1, variant, tint, parent)
		return if solid then p else decor(p)
	end
	local t, h = 1.5, half
	q("Basin", -h, 0, -h, h, 2.5, -h + t, "px_smooth_stone", WHITE)
	q("Basin", -h, 0, h - t, h, 2.5, h, "px_smooth_stone", WHITE)
	q("Basin", -h, 0, -h + t, -h + t, 2.5, h - t, "px_smooth_stone", WHITE)
	q("Basin", h - t, 0, -h + t, h, 2.5, h - t, "px_smooth_stone", WHITE)
	glass("Pool", x - h + t, y, z - h + t, x + h - t, y + 2.1, z + h - t, parent)
	q("FountainPier", -1.5, 0, -1.5, 1.5, pierH, 1.5, "px_white_stone_bricks", QUARTZ)
	local bw = math.min(3, h - t - 0.5)
	q("FountainBowl", -bw, pierH, -bw, bw, pierH + 1, bw, "px_smooth_stone", WHITE)
	glass(
		"BowlWater",
		x - bw + 0.5,
		y + pierH + 1,
		z - bw + 0.5,
		x + bw - 0.5,
		y + pierH + 1.4,
		z + bw - 0.5,
		parent
	)
	local cw = bw - 1
	glass("Cascade", x - cw, y + 2.1, z - bw, x + cw, y + pierH + 1.3, z - bw + 0.5, parent)
	glass("Cascade", x - cw, y + 2.1, z + bw - 0.5, x + cw, y + pierH + 1.3, z + bw, parent)
	glass("Cascade", x - bw, y + 2.1, z - cw, x - bw + 0.5, y + pierH + 1.3, z + cw, parent)
	glass("Cascade", x + bw - 0.5, y + 2.1, z - cw, x + bw, y + pierH + 1.3, z + cw, parent)
	dbox(
		"FountainSpout",
		x - 0.8,
		y + pierH + 1,
		z - 0.8,
		x + 0.8,
		y + pierH + 3,
		z + 0.8,
		"px_gold_block",
		GOLD,
		parent
	)
	glass("FountainJet", x - 1.1, y + pierH + 3, z - 1.1, x + 1.1, y + pierH + 4.2, z + 1.1, parent)
end
-- a white domed gazebo n×n blocks (5 or 3), open on every side: a quartz-edged floor, white columns on the corners
-- with gold capitals, a quartz roof slab with a gold band, a stepped white dome with gold ribs and a gold tip;
-- lamp = nil (none) / false (unlit) / true (lit) hangs a lantern under the roof; inner = a fountain inside
local function gazebo(x, y, z, n, f, solid, lampLit, inner)
	local function q(name, x0, y0, z0, x1, y1, z1, variant, tint)
		local p = box(name, x0, y0, z0, x1, y1, z1, variant, tint, f)
		return if solid then p else decor(p)
	end
	local h = n * B / 2
	q(
		"GazeboFloor",
		x - h - 1,
		y,
		z - h - 1,
		x + h + 1,
		y + 0.4,
		z + h + 1,
		"px_white_stone_bricks",
		QUARTZ
	)
	q(
		"GazeboFloor",
		x - h + 1,
		y,
		z - h + 1,
		x + h - 1,
		y + 0.5,
		z + h - 1,
		"px_smooth_stone",
		WHITE
	)
	local cs = if n >= 5 then 2 else 1
	local colH = if n >= 5 then 13 else 10
	for _, i in ipairs({ -1, 1 }) do
		for _, j in ipairs({ -1, 1 }) do
			local px, pz = x + i * (h - cs), z + j * (h - cs)
			q(
				"GazeboBase",
				px - cs - 0.5,
				y,
				pz - cs - 0.5,
				px + cs + 0.5,
				y + 1.2,
				pz + cs + 0.5,
				"px_white_stone_bricks",
				QUARTZ
			)
			q(
				"GazeboColumn",
				px - cs,
				y + 1.2,
				pz - cs,
				px + cs,
				y + colH - 1,
				pz + cs,
				"px_smooth_stone",
				WHITE
			)
			dbox(
				"GazeboCapital",
				px - cs - 0.4,
				y + colH - 1,
				pz - cs - 0.4,
				px + cs + 0.4,
				y + colH,
				pz + cs + 0.4,
				"px_gold_block",
				GOLD,
				f
			)
		end
	end
	q(
		"GazeboRoof",
		x - h - 0.5,
		y + colH,
		z - h - 0.5,
		x + h + 0.5,
		y + colH + 2,
		z + h + 0.5,
		"px_white_stone_bricks",
		QUARTZ
	)
	dbox(
		"GazeboBand",
		x - h - 0.9,
		y + colH + 2,
		z - h - 0.9,
		x + h + 0.9,
		y + colH + 2.8,
		z + h + 0.9,
		"px_gold_block",
		GOLD,
		f
	)
	-- the stepped dome: each layer 2 studs narrower, white concrete and quartz in turn, a gold rib on every face
	local yy, hs, li = y + colH + 2.8, h - 1, 0
	while hs >= 2.5 do
		local lh = if hs > 5 then 3 else 2.5
		local brick = li % 2 == 1
		dbox(
			"Dome",
			x - hs,
			yy,
			z - hs,
			x + hs,
			yy + lh,
			z + hs,
			if brick then "px_white_stone_bricks" else "px_smooth_stone",
			if brick then QUARTZ else WHITE,
			f
		)
		dbox(
			"DomeRib",
			x - 0.7,
			yy,
			z - hs - 0.3,
			x + 0.7,
			yy + lh,
			z - hs + 0.6,
			"px_gold_block",
			GOLD,
			f
		)
		dbox(
			"DomeRib",
			x - 0.7,
			yy,
			z + hs - 0.6,
			x + 0.7,
			yy + lh,
			z + hs + 0.3,
			"px_gold_block",
			GOLD,
			f
		)
		dbox(
			"DomeRib",
			x - hs - 0.3,
			yy,
			z - 0.7,
			x - hs + 0.6,
			yy + lh,
			z + 0.7,
			"px_gold_block",
			GOLD,
			f
		)
		dbox(
			"DomeRib",
			x + hs - 0.6,
			yy,
			z - 0.7,
			x + hs + 0.3,
			yy + lh,
			z + 0.7,
			"px_gold_block",
			GOLD,
			f
		)
		yy, hs, li = yy + lh, hs - 2, li + 1
	end
	dbox("DomeTip", x - 1.2, yy, z - 1.2, x + 1.2, yy + 2, z + 1.2, "px_gold_block", GOLD, f)
	dbox("DomeTip", x - 0.5, yy + 2, z - 0.5, x + 0.5, yy + 4.5, z + 0.5, "px_gold_block", GOLD, f)
	if lampLit ~= nil then
		lamp(x, y + colH - 3, z, f, lampLit, y + colH)
	end
	if inner then
		fountain(x, y + 0.5, z, 5, 4, f, solid)
	end
	return yy + 4.5
end
-- a slender stepped white end-rod spire (≈ 12 blocks at s = 1): a quartz plinth, a white shaft with a gold band, a
-- quartz ledge, a snow-white upper shaft, a gold cap and a thin white Neon rod on top
local function spire(x, y, z, s, f, solid, lit)
	local function q(name, hw, y0, y1, variant, tint, deco)
		local p = box(
			name,
			x - hw * s,
			y + y0 * s,
			z - hw * s,
			x + hw * s,
			y + y1 * s,
			z + hw * s,
			variant,
			tint,
			f
		)
		return if solid and not deco then p else decor(p)
	end
	q("SpirePlinth", 6, 0, 4, "px_white_stone_bricks", QUARTZ)
	q("SpireShaft", 4, 4, 28, "px_smooth_stone", WHITE)
	q("SpireBand", 4.4, 15, 16.5, "px_gold_block", GOLD, true)
	q("SpireLedge", 5, 28, 30, "px_white_stone_bricks", QUARTZ)
	q("SpireShaft", 2, 30, 46, "px_smooth_stone", SNOW, true)
	q("SpireCap", 2.6, 46, 47.5, "px_gold_block", GOLD, true)
	q("SpireTop", 1.5, 47.5, 49.5, "px_white_stone_bricks", QUARTZ, true)
	local top = y + 49.5 * s
	dbox("RodBase", x - 0.9, top, z - 0.9, x + 0.9, top + 0.8, z + 0.9, "px_smooth_stone", WHITE, f)
	local rod = part(
		"EndRod",
		Vector3.new(0.7, 14 * s, 0.7),
		at(x, top + 0.8 + 7 * s, z),
		CLOUD,
		Enum.Material.Neon,
		f
	)
	rod.CastShadow = false
	decor(rod)
	if lit then
		glow(rod, 40, 1.3, LIGHT)
	end
	return top + 0.8 + 14 * s
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
-- 30+ studs (horizontally) between a thing of half-size `half` and the crown's pillar of light
local function offPillar(x, z, half)
	return math.sqrt((x - ROSE.x) ^ 2 + (z - ROSE.z) ^ 2) > 30 + half
end
local taken = {} -- floating islets (west side): { x, z, half, y0, y1 }
local FALLS = {} -- waterfall spouts (east side, built with their mirrors): { cx, cz, fx, fz, width, isle, inner }
local FALL_CELLS = {} -- "cx,cz" of every spout cell, both sides
local FALL_BOXES = {} -- the waterfalls' bounds, both sides: { x0, x1, z0, z1, y0, y1 }
local BRIDGE_END = {} -- the east bridges' deck end on their islet: { east = x, northEast = x, southEast = x }

-- ================================================================ the waterfall spouts (found first: props keep off)
do
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	-- the outermost cell of `isle` along a ray and its open face most along the ray
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
	local function add(isle, ox, oz, deg, w)
		-- nudge the ray a little when it lands on a walk, a bridge or an earlier spout
		for _, nudge in ipairs({ 0, 4, -4, 8, -8 }) do
			local a = math.rad(deg + nudge)
			local cx, cz, fx, fz = rimCell(isle, ox, oz, math.cos(a), math.sin(a))
			local ok = cx ~= nil and cx > 8 and not FALL_CELLS[cx .. "," .. cz]
			if
				ok
				and isle == "main"
				and (onPath(cx, cz, 6) or (math.abs(cx) < 28 and cz > 150))
			then
				ok = false
			end
			if ok then
				for _, b in ipairs(BRIDGES) do
					if inRect(cx, cz, b, 14) then
						ok = false
					end
				end
			end
			if ok then
				-- the spout reaches in from the face only where the ground is within 4 studs of the edge
				local inner = 5
				if isle == "main" then
					inner = 1
					for k = 4, 1, -1 do
						local px, pz = cx + fx * (4 - k), cz + fz * (4 - k)
						if isleOf(px, pz, 4) == nil then
							inner = k
							break
						end
					end
				end
				table.insert(FALLS, { cx, cz, fx, fz, w, isle, inner })
				FALL_CELLS[cx .. "," .. cz] = true
				FALL_CELLS[-cx .. "," .. cz] = true
				return
			end
		end
	end
	for _, deg in ipairs({ -84, -62, -24, 24, 68 }) do
		add("main", 0, 0, deg, 2)
	end
	for _, i in ipairs({ 2, 4, 6 }) do
		local s = ISLES[i]
		local out = math.deg(math.atan2(s.z - ISLAND.z, s.x - ISLAND.x))
		for _, a in ipairs({ -40, 40 }) do
			add(s.name, s.x, s.z, out + a, if i == 2 then 2 else 1)
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
	-- a white column with a gold cap and a lantern on top, standing on the ground at (x, z)
	local function endColumn(x, z, f, lit)
		box(
			"BridgeColumnBase",
			x - 2,
			0,
			z - 2,
			x + 2,
			1.5,
			z + 2,
			"px_white_stone_bricks",
			QUARTZ,
			f
		)
		box("BridgeColumn", x - 1.5, 1.5, z - 1.5, x + 1.5, 8, z + 1.5, "px_smooth_stone", WHITE, f)
		box("BridgeColumnCap", x - 2, 8, z - 2, x + 2, 9, z + 2, "px_gold_block", GOLD, f)
		lamp(x, 9.75, z, f, lit)
	end
	for _, key in ipairs({ { 2, "east" }, { 4, "northEast" }, { 6, "southEast" } }) do
		local b = BRIDGES[key[1]] -- the east one; the west one is its mirror
		local z0, z1 = b[2], b[4]
		local zm = (z0 + z1) / 2
		local lo, hi = b[1], b[3]
		local ga, gb = gapAlong(zm, lo, hi)
		if not ga then
			ga, gb = lo + 8, hi - 8
		end
		-- the deck reaches 12+ studs onto the ground along its centre line and both edge lines
		local ea, eb = ga, gb
		for _, ez in ipairs({ z0 + 0.5, z1 - 0.5 }) do
			local a, c = gapAlong(ez, lo, hi)
			if a then
				ea, eb = math.min(ea, a), math.max(eb, c)
			end
		end
		local xa, xb = math.min(lo, ea - 12), math.max(hi, eb + 12)
		BRIDGE_END[key[2]] = xb
		-- the balustrades: over each edge line's own gap, 2 studs wide outside the deck
		local kerbs = {}
		for _, kz in ipairs({ { z0 - 2, z0, z0 - 2 }, { z1, z1 + 2, z1 + 2 } }) do
			local ka, kb = gapAlong((kz[1] + kz[2]) / 2, lo, hi)
			if not ka then
				ka, kb = ga, gb
			end
			table.insert(kerbs, { kz[1], kz[2], ka, kb, kz[3] })
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
			("[build-paradise] sky: bridge %s gap x %d..%d (%d studs, edges %d..%d), deck x %d..%d"):format(
				key[2],
				ga,
				gb,
				gb - ga,
				ea,
				eb,
				xa,
				xb
			)
		)
		for _, sx in ipairs(SIDES) do
			local f = folder((if sx < 0 then "West" else "East") .. "Bridge_" .. key[2], bf)
			box("BridgeDeck", sx * xa, under, z0, sx * xb, 0.1, z1, "px_smooth_stone", WHITE, f)
			dbox(
				"BridgeRunner",
				sx * (ga - 8),
				0.1,
				zm - 4,
				sx * (gb + 8),
				0.16,
				zm + 4,
				"px_white_stone_bricks",
				QUARTZ,
				f
			)
			for ki, k in ipairs(kerbs) do
				local kzm = (k[1] + k[2]) / 2
				local ka, kb = k[3], k[4]
				box(
					"BalustradeKerb",
					sx * ka,
					under,
					k[1],
					sx * kb,
					1.1,
					k[2],
					"px_white_stone_bricks",
					QUARTZ,
					f
				)
				box(
					"BalustradeRail",
					sx * ka,
					3.6,
					k[1] + 0.2,
					sx * kb,
					4.4,
					k[2] - 0.2,
					"px_smooth_stone",
					WHITE,
					f
				)
				local np = math.max(1, math.floor((kb - ka) / 8 + 0.5))
				for i = 0, np do
					local px = ka + (kb - ka) * i / np
					box(
						"BalustradePost",
						sx * (px - 1),
						1.1,
						kzm - 1,
						sx * (px + 1),
						4.4,
						kzm + 1,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
					dbox(
						"BalustradeCap",
						sx * (px - 1.2),
						4.4,
						kzm - 1.2,
						sx * (px + 1.2),
						5,
						kzm + 1.2,
						"px_gold_block",
						GOLD,
						f
					)
					if i < np then
						local mx = ka + (kb - ka) * (i + 0.5) / np
						dbox(
							"Baluster",
							sx * (mx - 0.5),
							1.1,
							kzm - 0.5,
							sx * (mx + 0.5),
							3.6,
							kzm + 0.5,
							"px_smooth_stone",
							WHITE,
							f
						)
					end
				end
				-- the end columns on the ground just off the gap; the islet one of the first rail is lit
				endColumn(sx * (ka - 2), k[5], f, false)
				endColumn(sx * (kb + 2), k[5], f, ki == 1)
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
						QUARTZ,
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
					SNOW,
					f
				)
			end
		end
	end
end
task.wait()

-- ================================================================ 2-3. the islets: the gazebos, the spires
do
	-- true when the rect of half-sizes hx, hz at (x, z) (east coords) stands on `isle`'s cells (2 studs in from the
	-- edge) and off its waterfall spouts
	local function onIsle(isle, x, z, hx, hz)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local px, pz = x + c[1] * hx, z + c[2] * hz
			if cellLand(px, pz) ~= isle or isleOf(px, pz, 2) ~= isle then
				return false
			end
		end
		for _, fl in ipairs(FALLS) do
			if
				fl[6] == isle
				and math.abs(x - fl[1]) < hx + 10
				and math.abs(z - fl[2]) < hz + 10
			then
				return false
			end
		end
		return true
	end
	-- the birches { x, z } and flower beds { x, z, alongX } of an islet (east coords, fixed spots checked against
	-- the cells), drawn once for both sides
	local function islandProps(isle, treeSpots, bedSpots)
		local trees, beds = {}, {}
		for _, t in ipairs(treeSpots) do
			local spec = birchSpec(rng:NextInteger(4, 6))
			if onIsle(isle, t[1], t[2], 2, 2) then
				table.insert(trees, { t[1], t[2], spec })
			end
		end
		for _, b in ipairs(bedSpots) do
			if onIsle(isle, b[1], b[2], if b[3] then 4 else 2, if b[3] then 2 else 4) then
				table.insert(beds, b)
			end
		end
		return trees, beds
	end
	local function buildProps(trees, beds, sx, f)
		for _, t in ipairs(trees) do
			birch(sx * t[1], 0, t[2], t[3], f, true, sx)
		end
		for _, b in ipairs(beds) do
			flowerBed(sx * b[1], 0, b[2], b[3], f, sx)
		end
	end

	-- the islets W/E: the gazebo at (304, 0), the walk z -8..8 from the landing (east coords)
	local landE = BRIDGE_END.east or 268
	local treesE, bedsE = islandProps(
		"east",
		{ { 312, 28 }, { 312, -28 }, { 282, 27 }, { 282, -27 } },
		{
			{ 321, 0, false },
			{ 296, 24, true },
			{ 296, -24, true },
			{ 278, 12, true },
			{ 278, -12, true },
		}
	)
	for _, sx in ipairs(SIDES) do
		local f = folder(if sx < 0 then "IsletWest" else "IsletEast", sky)
		gazebo(sx * 304, 0, 0, 5, f, true, true, true)
		dbox(
			"IsletWalk",
			sx * (landE - 4),
			0,
			-8,
			sx * 293,
			0.06,
			8,
			"px_white_stone_bricks",
			QUARTZ,
			f
		)
		bench(sx * 304, 0, -16.5, true, f)
		bench(sx * 304, 0, 16.5, true, f)
		whitePost(sx * 289, 0, -12, f, false)
		whitePost(sx * 289, 0, 12, f, false)
		buildProps(treesE, bedsE, sx, f)
	end
	task.wait()

	-- the islets NW/NE: the end-rod spire on its stepped dais at (236, -176) (east coords)
	local treesNE, bedsNE = islandProps(
		"northEast",
		{ { 212, -160 } },
		{ { 236, -192, true }, { 216, -192, true }, { 224, -157, true } }
	)
	for _, sx in ipairs(SIDES) do
		local f = folder(if sx < 0 then "IsletNorthWest" else "IsletNorthEast", sky)
		local x = sx * 236
		box("Dais", x - 12, 0, -188, x + 12, 1.5, -164, "px_white_stone_bricks", QUARTZ, f)
		box("Dais", x - 9, 1.5, -185, x + 9, 3, -167, "px_smooth_stone", WHITE, f)
		spire(x, 3, -176, 1, f, true, true)
		bench(x, 0, -158.5, true, f)
		buildProps(treesNE, bedsNE, sx, f)
	end
	task.wait()

	-- the islets SW/SE: the small gazebo at (236, 176) with a lantern (east coords)
	local treesSE, bedsSE = islandProps(
		"southEast",
		{ { 226, 154 } },
		{ { 236, 160, true }, { 216, 160, true }, { 218, 192, true } }
	)
	for _, sx in ipairs(SIDES) do
		local f = folder(if sx < 0 then "IsletSouthWest" else "IsletSouthEast", sky)
		local x = sx * 236
		box("Dais", x - 9, 0, 167, x + 9, 0.3, 185, "px_white_stone_bricks", QUARTZ, f)
		gazebo(x, 0.3, 176, 3, f, true, true, false)
		bench(x, 0, 191.5, true, f)
		buildProps(treesSE, bedsSE, sx, f)
	end
	print(
		("[build-paradise] sky: islets W/E %d birches %d beds, NW/NE %d/%d, SW/SE %d/%d"):format(
			#treesE,
			#bedsE,
			#treesNE,
			#bedsNE,
			#treesSE,
			#bedsSE
		)
	)
end
task.wait()

-- ================================================================ 4. the blue-glass waterfalls
do
	local wf = folder("Waterfalls", sky)
	for _, fl in ipairs(FALLS) do
		local cx0, cz, fx0, fz, wb, inner = fl[1], fl[2], fl[3], fl[4], fl[5], fl[7]
		local top = colTop(cx0, cz)
		local low = colBottom(cx0, cz) - 20
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
			local x0, z0, x1, z1 = nb(-inner, 0.8, -hw - 1, hw + 1)
			dbox("FallSpout", x0, top, z0, x1, top + 1, z1, "px_white_stone_bricks", QUARTZ, f)
			x0, z0, x1, z1 = nb(-inner + 1, 0.8, -hw, hw)
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
	print(("[build-paradise] sky: waterfalls %d"):format(#FALLS * 2))
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
			if brick then QUARTZ else SNOW
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
	for z = -248, 240, 8 do
		for x = -352, -8, 8 do
			local cx, cz = x + 4, z + 4
			if cellLand(cx, cz) ~= nil and not skip(cx, cz) and count - s0 < 880 then
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
	print(("[build-paradise] sky: stalactites %d, %d parts"):format(cols, count - s0))
end
task.wait()

-- ================================================================ 6. floating white islets (mirrored pairs)
do
	local fly = folder("FloatingIslets", sky)
	local f0 = count
	-- a spot on the west side: off the islands (24), out of the bridge corridors, off the pillar of light, apart
	local function findSpot(half, down, up)
		for attempt = 1, 800 do
			if attempt % 200 == 0 then
				task.wait()
			end
			local x, z =
				rng:NextNumber(-460 + half, -half - 12), rng:NextNumber(-380 + half, 380 - half)
			local y = rng:NextNumber(-60, 100)
			local ok = not inCorridor(x - half, x + half, z - half, z + half, y - down, y + up)
				and offPillar(x, z, half)
				and clearOfIslands(x, z, half, 24)
			if ok then
				for _, t in ipairs(taken) do
					local dh = math.sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2)
					if dh < t[3] + half + 14 and y + up + 8 > t[4] and y - down - 8 < t[5] then
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
	local PROPS =
		{ "gazebo", "spire", "fountain", "birch", "waterfall", "gazebo", "birch", "spire" }
	local made = 0
	for _, prop in ipairs(PROPS) do
		local w = if prop == "gazebo" then rng:NextInteger(5, 6) else rng:NextInteger(3, 5)
		if prop == "fountain" or prop == "waterfall" then
			w = math.max(w, 4)
		end
		local d = math.clamp(w + rng:NextInteger(-1, 1), if prop == "gazebo" then 5 else 3, 6)
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
		local fallLen = if prop == "waterfall" then rng:NextInteger(6, 10) * B else 0
		local half = math.max(w, d) * B / 2
		local up = if prop == "spire" then 40 else 32
		local x, y, z =
			findSpot(half + (if fallLen > 0 then 6 else 0), math.max(down, fallLen + 8), up)
		if x then
			x, y, z = snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2
			local hx, hz = w * B / 2, d * B / 2
			-- the layers' offsets, drawn once for both sides
			local rects = {}
			local ax, az, aw, ad, top = x - hx, z - hz, w, d, y - B
			for li, l in ipairs(layers) do
				local nx = ax + rng:NextInteger(0, aw - l[1]) * B
				local nz = az + rng:NextInteger(0, ad - l[2]) * B
				table.insert(
					rects,
					{ nx, top - l[3] * B, nz, nx + l[1] * B, top, nz + l[2] * B, li % 2 == 1 }
				)
				ax, az, aw, ad, top = nx, nz, l[1], l[2], top - l[3] * B
			end
			local spec = birchSpec(rng:NextInteger(3, 4))
			local fz = z + rng:NextInteger(-1, 1) * (if d >= 4 then 4 else 0)
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
					WHITE,
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
						if r[7] then QUARTZ else SNOW,
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
					QUARTZ,
					f
				)
				if prop == "gazebo" then
					gazebo(px, y, z, 3, f, false, nil, false)
				elseif prop == "spire" then
					spire(px, y, z, 0.5, f, false, false)
				elseif prop == "fountain" then
					fountain(px, y, z, 6, 4, f, false)
				elseif prop == "birch" then
					birch(px, y, z, spec, f, false, sx)
					dbox(
						"Flower",
						px - sx * 6,
						y,
						z + 3,
						px - sx * 4.4,
						y + 1.4,
						z + 4.6,
						"px_white_wool",
						SCARLET,
						f
					)
					dbox(
						"Flower",
						px + sx * 4.4,
						y,
						z - 4.6,
						px + sx * 6,
						y + 1.4,
						z - 3,
						"px_white_wool",
						SCARLET,
						f
					)
				else
					-- a birch and a 1-block waterfall off the outer face (west on the west side)
					birch(px + sx * 2, y, z, spec, f, false, sx)
					local e = x - hx
					dbox(
						"FallSpout",
						sx * (e - 0.8),
						y,
						fz - 3,
						sx * (e + 4),
						y + 1,
						fz + 3,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
					glass("FallPool", sx * e, y + 1, fz - 2, sx * (e + 3), y + 1.5, fz + 2, f)
					local yy, seg = y + 1.5, 0
					while yy > y - fallLen + 0.5 do
						local yb = math.max(y - fallLen, yy - 16)
						local n0 = 0.2 + seg * 0.7
						glass(
							"Waterfall",
							sx * (e - n0 - 2.4),
							yb,
							fz - 2,
							sx * (e - n0),
							yy + 0.3,
							fz + 2,
							f
						)
						yy, seg = yb, seg + 1
					end
					dbox(
						"Foam",
						sx * (e - 6),
						y - fallLen - 2,
						fz - 3,
						sx * (e + 1),
						y - fallLen + 1,
						fz + 3,
						"px_white_wool",
						CLOUD,
						f
					).CastShadow =
						false
				end
			end
			made += 2
		end
	end
	print(("[build-paradise] sky: floating islets %d, %d parts"):format(made, count - f0))
end
task.wait()

-- ================================================================ 7. the shining cloud sea (mirrored pairs)
do
	local cl = folder("Clouds", sky)
	local k0 = count
	local nLayer, nRim, nHigh = 0, 0, 0
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
	-- the broken layer under and round the islands: big puffs, tops y -60..-100
	for _ = 1, 28 do
		for attempt = 1, 60 do
			local w = rng:NextInteger(8, 22)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 4, 16)
			local th = rng:NextInteger(1, 2)
			local x = snap(rng:NextNumber(-460 + w * 2, -w * 2 - 6)) + (w % 2) * 2
			local z = snap(rng:NextNumber(-400 + d * 2, 400 - d * 2)) + (d % 2) * 2
			local top = snap(rng:NextNumber(-100, -60))
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
		local a = math.rad(96 + i * 168 / 7 + rng:NextNumber(-6, 6))
		local w = rng:NextInteger(5, 9)
		local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 3, 7)
		local th = rng:NextInteger(1, 2)
		local top = snap(rng:NextNumber(-40, -10))
		for rr = 230, 330, 6 do
			local x = snap(math.cos(a) * rr) + (w % 2) * 2
			local z = snap(math.sin(a) * rr) + (d % 2) * 2
			if clearOfIslands(x, z, math.max(w, d) * B / 2, 6) and try(x, top, z, w, d, th) then
				nRim += 2
				break
			end
		end
	end
	task.wait()
	-- a few high puffs, clear of the islands and the pillar of light
	for _ = 1, 4 do
		for _ = 1, 60 do
			local w = rng:NextInteger(5, 10)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.4, 0.8)), 3, 7)
			local th = rng:NextInteger(1, 2)
			local x = snap(rng:NextNumber(-440, -w * 2 - 6)) + (w % 2) * 2
			local z = snap(rng:NextNumber(-360, 360)) + (d % 2) * 2
			local top = snap(rng:NextNumber(70, 140))
			local hh = math.max(w, d) * B / 2
			if
				clearOfIslands(x, z, hh, 24)
				and offPillar(x, z, hh)
				and try(x, top, z, w, d, th)
			then
				nHigh += 2
				break
			end
		end
	end
	print(
		("[build-paradise] sky: clouds %d layer, %d rim, %d high, %d parts"):format(
			nLayer,
			nRim,
			nHigh,
			count - k0
		)
	)
end
print(("[build-paradise] sky: %d parts, %d lights"):format(count - c0, lights))
