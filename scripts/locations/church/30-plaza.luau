--!nocheck
-- ================================================================ church: the square round the pit and the south edge
-- The PLAZA part (zoneOf == "plaza": |x| < 110, z ≥ -40), after the concept (assets/concepts/church/concept-v2.webp,
-- top-left and top-right): a fence of spruce posts and rails round the brick pit 1 block outside the rim (x ±74,
-- z -4 and 144), open at the four ladder shafts (N x -24..24 = the axis to the stair, S x -28..28 widened for the
-- arrival, W/E z 58..82), white stone lantern pillars with blue cross banners at its corners and beside each opening;
-- lantern pillars along the paving edges (x ±100, z -34); a pair of tall 2×2 pillars framing the axis at z -35;
-- low white stone planters with bushes, flowers and candles; benches; cypresses round the edges; a fountain with a
-- golden cross, a noticeboard and a viewpoint with a telescope in the south-east; a pilgrim's cart with crates,
-- barrels and chests behind the buyer's stall; a low white balustrade with gaps and lantern posts along the south rim;
-- two angel statues on plinths flanking the way from the arrival to the pit.
-- Kept clear: the pit and its fence ring, the arrival r 20 (the angels r 16+), the buyer's stall with its crate and
-- barrel, the zone sign, the axis x -24..24 z -48..-4, the walk mouths x ±96..±110 z -28..0, walkways ≥ 5 blocks.
local plazaF = folder("Square")
local startCount = count
local F = {
	fence = folder("PitFence", plazaF),
	pillars = folder("LanternPillars", plazaF),
	garden = folder("Planters", plazaF),
	trees = folder("Cypresses", plazaF),
	props = folder("Props", plazaF),
	south = folder("SouthEdge", plazaF),
}
local COL = {
	iron = Color3.fromRGB(45, 45, 50),
	ironCap = Color3.fromRGB(40, 40, 45),
	wax = Color3.fromRGB(240, 234, 214),
	flame = Color3.fromRGB(255, 190, 90),
	paper = Color3.fromRGB(236, 228, 204),
	paperOld = Color3.fromRGB(214, 196, 156),
	seal = Color3.fromRGB(170, 40, 40),
	bush = Color3.fromRGB(205, 228, 190), -- a light tint over px_hedge (already dark green)
	wood = Color3.fromRGB(110, 80, 50),
	white = Color3.fromRGB(246, 246, 242),
	statue = Color3.fromRGB(250, 250, 248),
	water = Color3.fromRGB(215, 232, 255),
	stream = Color3.fromRGB(150, 200, 240),
	soil = Color3.fromRGB(90, 66, 46),
	stem = Color3.fromRGB(70, 130, 50),
	book = Color3.fromRGB(46, 62, 140),
	brass = Color3.fromRGB(196, 160, 90),
	chest = Color3.fromRGB(196, 146, 96),
	pot = Color3.fromRGB(240, 220, 210),
	sack = Color3.fromRGB(205, 182, 140),
}
local FLOWERS = {
	Color3.fromRGB(200, 50, 50),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(70, 110, 210),
	Color3.fromRGB(245, 245, 245),
	Color3.fromRGB(235, 140, 180),
	Color3.fromRGB(160, 110, 210),
}
local LIGHTS = 16 -- PointLights this part may add (lit lanterns and two candle clusters)
local lightsLeft = LIGHTS
local skipped = {}

-- ================================================================ helpers
-- a frame at local (x, y, z) whose front (-Z) looks along (dx, dz)
local function fr(x, z, dx, dz, y)
	return at(x, y or 0, z) * CFrame.Angles(0, math.atan2(-dx, -dz), 0)
end
-- a textured box in a frame cf by two local corners
local function lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
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
	return p
end
-- a small plain decor piece in a frame cf by size and local centre
local function lc(cf, name, sx, sy, sz, x, y, z, color, material, parent)
	return decor(
		part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, material, parent)
	)
end

-- footprints: the keep-outs, then everything placed (a rect {x0, z0, x1, z1} must lie on the island, in the plaza
-- zone, off the keep-outs, the pit with its fence ring, the arrival and everything claimed before)
local claims = {
	{ -46, 157, -18, 182 }, -- the buyer's stall, its crate and barrel
	{ 9, 168, 19, 176 }, -- the zone sign
	{ -24, -48, 24, -4 }, -- the axis to the cathedral stair
	{ -110, -28, -96, 0 }, -- the walk mouths
	{ 96, -28, 110, 0 },
}
local function claim(name, x0, z0, x1, z1, opt)
	opt = opt or {}
	for _, p in ipairs({
		{ x0, z0 },
		{ x1, z0 },
		{ x0, z1 },
		{ x1, z1 },
		{ (x0 + x1) / 2, (z0 + z1) / 2 },
	}) do
		if isleOf(p[1], p[2], 10) == nil or zoneOf(p[1], p[2]) ~= "plaza" then
			table.insert(skipped, name)
			return false
		end
	end
	local ok = true
	for _, k in ipairs(claims) do
		if x0 < k[3] and x1 > k[1] and z0 < k[4] and z1 > k[2] then
			ok = false
			break
		end
	end
	if ok and not opt.pit and x0 < 76 and x1 > -76 and z0 < 146 and z1 > -6 then
		ok = false
	end
	local nx, nz = math.clamp(SPAWN.x, x0, x1), math.clamp(SPAWN.z, z0, z1)
	if ok and math.sqrt((nx - SPAWN.x) ^ 2 + (nz - SPAWN.z) ^ 2) < (opt.spawnR or 20) then
		ok = false
	end
	if not ok then
		table.insert(skipped, name)
		return false
	end
	table.insert(claims, { x0, z0, x1, z1 })
	return true
end

-- a Minecraft lantern scaled by s at world pos; lit = a PointLight while the budget lasts
local function lamp(pos, s, lit, parent)
	local function bit(name, sx, sy, sz, ox, oy, oz, color, material)
		return decor(
			part(
				name,
				Vector3.new(sx, sy, sz) * s,
				CFrame.new(pos + Vector3.new(ox, oy, oz) * s),
				color,
				material or Enum.Material.Metal,
				parent
			)
		)
	end
	bit("LanternBase", 1.3, 0.25, 1.3, 0, -0.62, 0, COL.iron)
	bit("LanternTop", 1.3, 0.25, 1.3, 0, 0.62, 0, COL.iron)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		bit("LanternBar", 0.2, 1, 0.2, c[1] * 0.55, 0, c[2] * 0.55, COL.iron)
	end
	local core = bit("LanternGlow", 0.9, 1, 0.9, 0, 0, 0, LANTERN_GLOW, Enum.Material.Neon)
	core.Transparency = 0.1
	bit("LanternCap", 0.7, 0.35, 0.7, 0, 0.9, 0, COL.ironCap)
	if lit and lightsLeft > 0 then
		lightsLeft -= 1
		light(core, 24 + 6 * s, 1.2, LANTERN_GLOW)
	end
	return core
end
-- a blue banner with a white cross; cf = the cloth centre, the cloth in the frame's XY plane
local function crossBanner(cf, w, h, parent)
	lc(cf, "BannerRod", w + 0.6, 0.4, 0.4, 0, h / 2 + 0.2, 0, COL.wood, Enum.Material.Wood, parent)
	lc(cf, "Banner", w, h, 0.2, 0, 0, 0, BANNER_BLUE, Enum.Material.Fabric, parent)
	lc(
		cf,
		"BannerCross",
		w * 0.2,
		h * 0.62,
		0.28,
		0,
		h * 0.04,
		0,
		COL.white,
		Enum.Material.Fabric,
		parent
	)
	lc(
		cf,
		"BannerCross",
		w * 0.62,
		h * 0.12,
		0.28,
		0,
		h * 0.17,
		0,
		COL.white,
		Enum.Material.Fabric,
		parent
	)
	lc(cf, "BannerHem", w, 0.35, 0.26, 0, -h / 2 + 0.175, 0, GOLD, Enum.Material.Fabric, parent)
end
-- a cluster of n candles on a top at local (x, y, z); the first `lit` burn, `glow` gives the first flame a light
local function candles(x, y, z, n, lit, parent, glow, spread)
	spread = spread or 1.6
	for i = 1, n do
		local ox, oz = (rng:NextNumber() - 0.5) * spread, (rng:NextNumber() - 0.5) * spread
		local h = 0.8 + rng:NextNumber() * 1
		decor(
			part(
				"Candle",
				Vector3.new(0.5, h, 0.5),
				at(x + ox, y + h / 2, z + oz),
				COL.wax,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
		if i <= lit then
			local fl = decor(
				part(
					"CandleFlame",
					Vector3.new(0.24, 0.42, 0.24),
					at(x + ox, y + h + 0.21, z + oz),
					COL.flame,
					Enum.Material.Neon,
					parent
				)
			)
			if glow and i == 1 and lightsLeft > 0 then
				lightsLeft -= 1
				light(fl, 16, 1, COL.flame)
			end
		end
	end
end
-- a flower pot (terracotta) with a flower or a little bush, standing on local y
local function flowerPot(x, y, z, parent)
	textured(
		decor(part("FlowerPot", Vector3.new(1.4, 1.3, 1.4), at(x, y + 0.65, z), nil, nil, parent)),
		"px_terracotta",
		COL.pot
	)
	decor(
		part(
			"PotSoil",
			Vector3.new(1, 0.1, 1),
			at(x, y + 1.32, z),
			COL.soil,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	if rng:NextNumber() < 0.6 then
		decor(
			part(
				"FlowerStem",
				Vector3.new(0.25, 1.1, 0.25),
				at(x, y + 1.9, z),
				COL.stem,
				Enum.Material.SmoothPlastic,
				parent
			)
		)
		decor(
			part(
				"Flower",
				Vector3.new(0.8, 0.8, 0.8),
				at(x, y + 2.75, z),
				pick(FLOWERS),
				Enum.Material.SmoothPlastic,
				parent
			)
		)
	else
		textured(
			decor(part("PotBush", Vector3.new(1.3, 1.3, 1.3), at(x, y + 2, z), nil, nil, parent)),
			"px_hedge",
			COL.bush
		)
	end
end
-- a square lantern pillar of white stone: n blocks wide, h blocks tall, a smooth cap (2×2 pillars get a stepped
-- 1×1 plinth on the cap), a lantern on top, a blue cross banner on every face of faces ({dx, dz} axes)
local function pillar(cx, cz, n, h, faces, lit, parent)
	local f = folder("LanternPillar", parent)
	local w, top = n * B, h * B
	local hw = w / 2
	box(
		"PillarFoot",
		cx - hw - 0.5,
		0,
		cz - hw - 0.5,
		cx + hw + 0.5,
		1,
		cz + hw + 0.5,
		"px_stone_bricks",
		GREY_STONE,
		f
	)
	box(
		"Pillar",
		cx - hw,
		1,
		cz - hw,
		cx + hw,
		top,
		cz + hw,
		"px_white_stone_bricks",
		WHITE_STONE,
		f
	)
	box(
		"PillarCap",
		cx - hw - 0.5,
		top,
		cz - hw - 0.5,
		cx + hw + 0.5,
		top + 1,
		cz + hw + 0.5,
		"px_smooth_stone",
		WHITE_STONE,
		f
	)
	local ly = top + 1
	if n >= 2 then
		box(
			"PillarPlinth",
			cx - 2,
			ly,
			cz - 2,
			cx + 2,
			ly + B,
			cz + 2,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		box(
			"PillarCap",
			cx - 2.5,
			ly + B,
			cz - 2.5,
			cx + 2.5,
			ly + B + 1,
			cz + 2.5,
			"px_smooth_stone",
			WHITE_STONE,
			f
		)
		ly += B + 1
	end
	local s = if n >= 2 then 2 else 1.3
	lamp(V(cx, ly + 0.75 * s, cz), s, lit, f)
	local bw = w * 0.7
	local bh = math.min(top - 3, bw * 2.6)
	for _, d in ipairs(faces) do
		local cf =
			fr(cx + d[1] * (hw + 0.15), cz + d[2] * (hw + 0.15), d[1], d[2], top - 1 - bh / 2)
		crossBanner(cf, bw, bh, f)
	end
	return f, top + 1
end
-- a low white stone planter (x0..x1, z0..z1): a block of white stone bricks, a smooth lip, grass, bushes and flowers
-- along the middle, candle clusters on two corners of the lip
local function planter(x0, z0, x1, z1, parent)
	if not claim("Planter", x0, z0, x1, z1) then
		return nil
	end
	local f = folder("Planter", parent)
	box("PlanterWall", x0, 0, z0, x1, 3.4, z1, "px_white_stone_bricks", WHITE_STONE, f)
	box("PlanterSoil", x0 + 0.8, 3.4, z0 + 0.8, x1 - 0.8, 3.8, z1 - 0.8, "px_grass_top", GRASS, f)
	box("PlanterLip", x0, 3.4, z0, x1, 4, z0 + 0.8, "px_smooth_stone", WHITE_STONE, f)
	box("PlanterLip", x0, 3.4, z1 - 0.8, x1, 4, z1, "px_smooth_stone", WHITE_STONE, f)
	box("PlanterLip", x0, 3.4, z0 + 0.8, x0 + 0.8, 4, z1 - 0.8, "px_smooth_stone", WHITE_STONE, f)
	box("PlanterLip", x1 - 0.8, 3.4, z0 + 0.8, x1, 4, z1 - 0.8, "px_smooth_stone", WHITE_STONE, f)
	local alongX = (x1 - x0) >= (z1 - z0)
	local len = if alongX then x1 - x0 else z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local slots = math.floor(len / B)
	for i = 0, slots - 1 do
		local t = (if alongX then x0 else z0) + (i + 0.5) * (len / slots)
		local bx, bz = if alongX then t else cx, if alongX then cz else t
		local roll = rng:NextNumber()
		if roll < 0.55 then
			local hgt = if roll < 0.14 then 2 * B else B
			textured(
				decor(part("Bush", Vector3.new(B, hgt, B), at(bx, 3.8 + hgt / 2, bz), nil, nil, f)),
				"px_hedge",
				COL.bush
			)
		else
			for _, o in ipairs({ -1, 1 }) do
				local fx = bx + (if alongX then o * 1 else (rng:NextNumber() - 0.5) * 2)
				local fz = bz + (if alongX then (rng:NextNumber() - 0.5) * 2 else o * 1)
				decor(
					part(
						"FlowerStem",
						Vector3.new(0.25, 1.2, 0.25),
						at(fx, 4.4, fz),
						COL.stem,
						Enum.Material.SmoothPlastic,
						f
					)
				)
				decor(
					part(
						"Flower",
						Vector3.new(0.8, 0.8, 0.8),
						at(fx, 5.3, fz),
						pick(FLOWERS),
						Enum.Material.SmoothPlastic,
						f
					)
				)
			end
		end
	end
	local corners = {
		{ x0 + 0.45, z0 + 0.45 },
		{ x1 - 0.45, z1 - 0.45 },
		{ x1 - 0.45, z0 + 0.45 },
		{ x0 + 0.45, z1 - 0.45 },
	}
	for i = 1, 2 do
		local c = corners[rng:NextInteger(1, 2) * 2 - (i - 1)]
		candles(
			c[1],
			4,
			c[2],
			rng:NextInteger(2, 3),
			if rng:NextNumber() < 0.35 then 1 else 0,
			f,
			false,
			0.5
		)
	end
	return f
end
-- a cypress: a log core with a 2×2 column of leaves, a 1×1 top two blocks high and single blocks stuck to the sides
-- (a stepped silhouette); h = blocks up to the top of the crown
local function cypress(cx, cz, h, parent)
	if not claim("Cypress", cx - 4, cz - 4, cx + 4, cz + 4) then
		return
	end
	local f = folder("Cypress", parent)
	box("CypressLog", cx - 2, 0, cz - 2, cx + 2, (h - 2) * B, cz + 2, "px_dark_oak_log", nil, f)
	decor(
		box("CypressLeaves", cx - 4, B, cz - 4, cx + 4, (h - 2) * B, cz + 4, "px_hedge", CYPRESS, f)
	)
	decor(
		box(
			"CypressTop",
			cx - 2,
			(h - 2) * B,
			cz - 2,
			cx + 2,
			h * B,
			cz + 2,
			"px_hedge",
			CYPRESS,
			f
		)
	)
	local sides = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for i = 1, 3 do
		local d = sides[(rng:NextInteger(0, 3) + i) % 4 + 1]
		local off = if rng:NextNumber() < 0.5 then -2 else 2
		local y = rng:NextInteger(2, h - 3) * B
		local bx = cx + d[1] * 6 + (if d[1] == 0 then off else 0)
		local bz = cz + d[2] * 6 + (if d[2] == 0 then off else 0)
		decor(cube("CypressLeaves", bx, y + B / 2, bz, B, B, B, "px_hedge", CYPRESS, f))
	end
end
-- a bench (white stone legs, a spruce seat, a dark backrest) at (cx, cz), its front looking along (dx, dz);
-- returns the frame (nil when the place is taken)
local function bench(cx, cz, dx, dz, parent, pots)
	local len = 2 * B
	local ex, ez = if dx ~= 0 then 1.3 else len / 2, if dx ~= 0 then len / 2 else 1.3
	if not claim("Bench", cx - ex, cz - ez, cx + ex, cz + ez) then
		return nil
	end
	local f = folder("Bench", parent)
	local cf = fr(cx, cz, dx, dz)
	for _, s in ipairs({ -1, 1 }) do
		lb(
			cf,
			"BenchLeg",
			s * (len / 2 - 1.4),
			0,
			-1,
			s * (len / 2 - 0.2),
			1.6,
			1,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
	end
	lb(cf, "BenchSeat", -len / 2, 1.6, -1.2, len / 2, 2.2, 1.2, WOOD, nil, f)
	lb(cf, "BenchBack", -len / 2, 2.2, 0.8, len / 2, 4.2, 1.3, WOOD_DARK, nil, f)
	if pots then
		for _, s in ipairs({ -1, 1 }) do
			local p = (cf * CFrame.new(s * (len / 2 + 1.2), 0, 0)).Position
			flowerPot(p.X - BX, 0, p.Z - BZ, f)
		end
	end
	return cf, f
end
-- a chest (Minecraft-like) on the ground at (x, z), its latch looking along (dx, dz)
local function chest(x, z, dx, dz, parent)
	local cf = fr(x, z, dx, dz)
	lb(cf, "Chest", -1.8, 0, -1.8, 1.8, 2.5, 1.8, WOOD, COL.chest, parent)
	lb(cf, "ChestLid", -1.8, 2.5, -1.8, 1.8, 3.5, 1.8, WOOD_DARK, nil, parent)
	lc(cf, "ChestLatch", 0.6, 0.9, 0.3, 0, 2.5, -1.95, COL.iron, Enum.Material.Metal, parent)
end
-- a white stone angel on a plinth at (cx, cz) looking south: a stepped robe, hands folded in prayer, a golden halo,
-- stepped wings rising outward behind the shoulders; candles on the front corners of the plinth
local function angel(cx, cz, parent)
	local f = folder("AngelStatue", parent)
	local cf = fr(cx, cz, 0, 1)
	lb(cf, "PlinthFoot", -4.5, 0, -4.5, 4.5, 1, 4.5, "px_stone_bricks", GREY_STONE, f)
	lb(cf, "Plinth", -4, 1, -4, 4, 5, 4, "px_white_stone_bricks", WHITE_STONE, f)
	lb(cf, "PlinthCap", -4.5, 5, -4.5, 4.5, 6, 4.5, "px_smooth_stone", WHITE_STONE, f)
	local function fig(name, x0, y0, z0, x1, y1, z1)
		return decor(lb(cf, name, x0, y0, z0, x1, y1, z1, "px_smooth_stone", COL.statue, f))
	end
	lb(cf, "Robe", -2.2, 6, -1.8, 2.2, 7.2, 1.8, "px_smooth_stone", COL.statue, f)
	lb(cf, "Robe", -1.8, 7.2, -1.4, 1.8, 11, 1.4, "px_smooth_stone", COL.statue, f)
	fig("Body", -1.8, 11, -1.2, 1.8, 13.4, 1.2)
	fig("Head", -1.2, 13.4, -1.2, 1.2, 15.8, 1.2)
	fig("Sleeve", -2.6, 10.4, -1.4, -1.8, 13, 0.6)
	fig("Sleeve", 1.8, 10.4, -1.4, 2.6, 13, 0.6)
	fig("Hands", -0.7, 11.2, -2.4, 0.7, 13.2, -1.2)
	for _, h in ipairs({
		{ 3, 0.4, 0, -1.3 },
		{ 3, 0.4, 0, 1.3 },
		{ 0.4, 2.2, -1.3, 0 },
		{ 0.4, 2.2, 1.3, 0 },
	}) do
		lc(cf, "Halo", h[1], 0.3, h[2], h[3], 16.5, h[4], GOLD, Enum.Material.Metal, f)
	end
	for _, s in ipairs({ -1, 1 }) do
		fig("Wing", s * 1.2, 8, 1.2, s * 3.2, 14.2, 2.2)
		fig("Wing", s * 3.2, 9.2, 1.4, s * 4.8, 15.4, 2.3)
		fig("Wing", s * 4.8, 10.6, 1.6, s * 6.2, 16.2, 2.4)
		fig("Wing", s * 6.2, 12.4, 1.8, s * 7.2, 16.6, 2.5)
		fig("WingTip", s * 1.6, 6.4, 1.4, s * 3.2, 8, 2.1)
	end
	-- the frame is turned half round: local (x, z) is world (cx - x, cz - z)
	candles(cx - 3.3, 6, cz + 3.3, 3, 2, f, true, 1.2)
	candles(cx + 3.3, 6, cz + 3.3, 2, 0, f, false, 1.2)
end
-- a brass telescope on a wooden tripod at (x, z) looking along (dx, dz) and a little up
local function telescope(x, z, dx, dz, parent)
	local f = folder("Telescope", parent)
	local head = V(x, 4.2, z)
	for i = 0, 2 do
		local a = i * 2 * math.pi / 3 + 0.3
		decor(
			beam(
				"TelescopeLeg",
				head,
				V(x + math.cos(a) * 1.6, 0, z + math.sin(a) * 1.6),
				0.35,
				COL.wood,
				f,
				Enum.Material.Wood
			)
		)
	end
	local mid = head + Vector3.new(0, 0.6, 0)
	local cf = CFrame.lookAt(mid, mid + Vector3.new(dx, 0.45, dz).Unit)
	decor(part("TelescopeTube", Vector3.new(0.9, 0.9, 4.4), cf, COL.brass, Enum.Material.Metal, f))
	decor(
		part(
			"TelescopeLens",
			Vector3.new(1.3, 1.3, 0.8),
			cf * CFrame.new(0, 0, -2.4),
			COL.brass,
			Enum.Material.Metal,
			f
		)
	)
	decor(
		part(
			"TelescopeEye",
			Vector3.new(0.6, 0.6, 0.9),
			cf * CFrame.new(0, 0, 2.5),
			COL.iron,
			Enum.Material.Metal,
			f
		)
	)
	decor(
		part(
			"TelescopeMount",
			Vector3.new(0.8, 0.8, 0.8),
			CFrame.new(head + Vector3.new(0, 0.1, 0)),
			COL.iron,
			Enum.Material.Metal,
			f
		)
	)
end
-- the southmost z of the island at x (both edges of a 4-stud column 12 studs inside the ragged rim)
local function rimZ(x)
	for z = 236, 120, -1 do
		if isleOf(x - 2, z, 12) and isleOf(x + 2, z, 12) then
			return z
		end
	end
	return nil
end

-- ================================================================ 1. the fence round the pit, its lantern pillars
do
	local runs = {
		{ -72, -4, -29, -4 }, -- north, open x -24..24 (the axis to the stair)
		{ 29, -4, 72, -4 },
		{ -72, 144, -32, 144 }, -- south, open x -28..28 (wide: the arrival)
		{ 32, 144, 72, 144 },
		{ -74, -2, -74, 54 }, -- west, open z 58..82
		{ -74, 86, -74, 142 },
		{ 74, -2, 74, 54 }, -- east
		{ 74, 86, 74, 142 },
	}
	for _, r in ipairs(runs) do
		fence(r[1], r[2], r[3], r[4], F.fence, 0, "px_spruce_planks")
	end
	local posts = {}
	for _, s in ipairs({ -1, 1 }) do
		table.insert(posts, { s * 74, -4, { { s, 0 }, { 0, -1 } }, false, true }) -- the corners
		table.insert(posts, { s * 74, 144, { { s, 0 }, { 0, 1 } }, false, true })
		table.insert(posts, { s * 26.5, -4, { { 0, -1 } }, true }) -- beside the openings
		table.insert(posts, { s * 30, 144, { { 0, 1 } }, true })
		table.insert(posts, { s * 74, 56, { { s, 0 } }, true })
		table.insert(posts, { s * 74, 84, { { s, 0 } }, true })
	end
	for _, p in ipairs(posts) do
		if claim("FencePillar", p[1] - 2.5, p[2] - 2.5, p[1] + 2.5, p[2] + 2.5, { pit = true }) then
			local f, capY = pillar(p[1], p[2], 1, 2, p[3], p[4], F.fence)
			if p[5] then
				-- a few candles on the cap of the corner pillars, beside the lantern
				local ox = if p[1] > 0 then -1.5 else 1.5
				candles(p[1] + ox, capY, p[2] + 1.5, 2, if p[2] > 0 then 1 else 0, f, false, 0.6)
			end
		end
	end
end
task.wait()

-- ================================================================ 3a. the south edge: a balustrade with gaps and lantern posts
local cols = {} -- k -> the z of the outer face of the balustrade at column x = -106 + 4k
do
	local f = folder("Balustrade", F.south)
	for k = 0, 53 do
		local zr = rimZ(-106 + 4 * k)
		cols[k] = if zr then math.floor(zr / B) * B else nil
	end
	for k = 0, 53 do
		local cx, zb = -106 + 4 * k, cols[k]
		local gap = (k % 7 == 3 and math.abs(cx - 82) > 10) or math.abs(cx) < 8
		if zb and zb > 150 and not gap then
			-- reach down to the neighbours so the stepped line stays joined, at most 3 blocks deep
			local zlo = zb - B
			for _, j in ipairs({ k - 1, k + 1 }) do
				if cols[j] and cols[j] > 150 then
					zlo = math.min(zlo, cols[j] - B)
				end
			end
			zlo = math.max(zlo, zb - 3 * B)
			if claim("Balustrade", cx - 2, zlo, cx + 2, zb) then
				local post = k % 7 == 0
				local railTop = if post then zb - B else zb
				if railTop > zlo then
					box(
						"BalustradeBase",
						cx - 2,
						0,
						zlo,
						cx + 2,
						1.2,
						railTop,
						"px_white_stone_bricks",
						WHITE_STONE,
						f
					)
					box(
						"BalustradeRail",
						cx - 2,
						3,
						zlo,
						cx + 2,
						4,
						railTop,
						"px_smooth_stone",
						WHITE_STONE,
						f
					)
					for z = zlo + 2, railTop - 1, B do
						box(
							"Baluster",
							cx - 0.8,
							1.2,
							z - 0.8,
							cx + 0.8,
							3,
							z + 0.8,
							"px_smooth_stone",
							WHITE_STONE,
							f
						)
					end
				end
				if post then
					pillar(cx, zb - 2, 1, 1.5, { { 0, -1 } }, false, f)
				elseif rng:NextNumber() < 0.18 then
					flowerPot(cx, 4, zb - 2, f)
				end
			end
		end
	end
end
task.wait()

-- ================================================================ 2a. lantern pillars along the square, the axis pair
do
	for _, s in ipairs({ -1, 1 }) do
		-- the tall pair framing the axis to the cathedral stair (the stair foot at z -48 stays clear)
		if claim("AxisPillar", s * 30 - 4.5, -39.5, s * 30 + 4.5, -30.5) then
			local f = pillar(s * 30, -35, 2, 6, { { 0, 1 }, { 0, -1 }, { -s, 0 } }, true, F.pillars)
			candles(s * 30 - s * 1.5, 1, -30.75, 3, 1, f, false, 0.4)
			candles(s * 30 + s * 2.8, 1, -30.75, 2, 0, f, false, 0.4)
		end
		-- the north edge of the square
		if claim("EdgePillar", s * 96 - 2.5, -36.5, s * 96 + 2.5, -31.5) then
			pillar(s * 96, -34, 1, 3, { { 0, 1 } }, false, F.pillars)
		end
		-- the west and east edges of the paving, every ~32 studs, a pair flanking the cross path at z 58..82
		for _, z in ipairs({ 8, 40, 54, 86, 100, 132 }) do
			if claim("EdgePillar", s * 100 - 2.5, z - 2.5, s * 100 + 2.5, z + 2.5) then
				pillar(s * 100, z, 1, 3, { { -s, 0 } }, z == 54 or z == 86, F.pillars)
			end
		end
	end
end
task.wait()

-- ================================================================ 2b. planters, benches, cypresses
do
	for _, s in ipairs({ -1, 1 }) do
		local function xr(a, b) -- a mirrored x range
			return math.min(s * a, s * b), math.max(s * a, s * b)
		end
		-- the north band between the fence and the church zone
		local a0, a1 = xr(38, 58)
		planter(a0, -38, a1, -30, F.garden)
		local b0, b1 = xr(74, 90)
		planter(b0, -38, b1, -30, F.garden)
		bench(s * 48, -28.6, 0, 1, F.garden, true)
		bench(s * 82, -28.6, 0, 1, F.garden, true)
		-- the west and east edges of the paving
		local c0, c1 = xr(96, 104)
		planter(c0, 20, c1, 36, F.garden)
		planter(c0, 104, c1, 120, F.garden)
		local cf = bench(s * 100, 47, -s, 0, F.garden)
		bench(s * 100, 93, -s, 0, F.garden)
		if cf and s < 0 then
			-- a lost hymn book left open-face-down on the west bench
			local f = folder("HymnBook", F.props)
			local bcf = cf * CFrame.new(1.4, 2.42, 0) * CFrame.Angles(0, 0.45, 0)
			decor(
				part("HymnBook", Vector3.new(1.5, 0.45, 2), bcf, COL.book, Enum.Material.Fabric, f)
			)
			decor(
				part(
					"HymnPages",
					Vector3.new(1.3, 0.32, 1.85),
					bcf * CFrame.new(0.15, 0, 0),
					COL.paper,
					Enum.Material.SmoothPlastic,
					f
				)
			)
			decor(
				part(
					"HymnCross",
					Vector3.new(0.22, 0.05, 1.1),
					bcf * CFrame.new(0, 0.24, 0),
					GOLD,
					Enum.Material.Metal,
					f
				)
			)
			decor(
				part(
					"HymnCross",
					Vector3.new(0.7, 0.05, 0.22),
					bcf * CFrame.new(0, 0.24, -0.2),
					GOLD,
					Enum.Material.Metal,
					f
				)
			)
		end
		-- cypresses round the edges
		cypress(s * 100, 16, rng:NextInteger(6, 8), F.trees)
		cypress(s * 100, 124, rng:NextInteger(6, 8), F.trees)
		cypress(s * 66, -34, rng:NextInteger(7, 8), F.trees)
		cypress(s * 100, 142, rng:NextInteger(5, 7), F.trees)
	end
end
task.wait()

-- ================================================================ 3b. the angels, the fountain, the noticeboard, the viewpoint
do
	for _, s in ipairs({ -1, 1 }) do
		if claim("Angel", s * 21 - 4.5, 146.5, s * 21 + 4.5, 155.5, { spawnR = 16 }) then
			angel(s * 21, 151, F.south)
		end
	end
	-- a fountain with a golden cross in the south-east
	local cx, cz = 44, 170
	if claim("Fountain", cx - 6, cz - 6, cx + 6, cz + 6) then
		local f = folder("Fountain", F.props)
		box(
			"FountainRim",
			cx - 6,
			0,
			cz - 6,
			cx + 6,
			3,
			cz - 4,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		box(
			"FountainRim",
			cx - 6,
			0,
			cz + 4,
			cx + 6,
			3,
			cz + 6,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		box(
			"FountainRim",
			cx - 6,
			0,
			cz - 4,
			cx - 4,
			3,
			cz + 4,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		box(
			"FountainRim",
			cx + 4,
			0,
			cz - 4,
			cx + 6,
			3,
			cz + 4,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		local water = decor(
			box("FountainWater", cx - 4, 0, cz - 4, cx + 4, 2.3, cz + 4, "px_water", COL.water, f)
		)
		water.Transparency = 0.15
		box(
			"FountainColumn",
			cx - 2,
			0,
			cz - 2,
			cx + 2,
			6,
			cz + 2,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		box("FountainBowl", cx - 3, 6, cz - 3, cx + 3, 7, cz + 3, "px_smooth_stone", WHITE_STONE, f)
		decor(
			box(
				"FountainBowlWater",
				cx - 2.4,
				7,
				cz - 2.4,
				cx + 2.4,
				7.3,
				cz + 2.4,
				"px_water",
				COL.water,
				f
			)
		)
		box("FountainStem", cx - 1, 7, cz - 1, cx + 1, 9, cz + 1, "px_smooth_stone", WHITE_STONE, f)
		cube("FountainCross", cx, 11.2, cz, 1, 4.4, 1, "px_gold_block", nil, f)
		cube("FountainCross", cx, 12, cz, 3.2, 1, 1, "px_gold_block", nil, f)
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local st = decor(
				part(
					"FountainStream",
					Vector3.new(0.6, 4.7, 0.6),
					at(cx + d[1] * 3.2, 4.65, cz + d[2] * 3.2),
					COL.stream,
					Enum.Material.SmoothPlastic,
					f
				)
			)
			st.Transparency = 0.35
		end
		candles(cx - 5, 3, cz - 5, 3, 1, f, false, 0.9)
		candles(cx + 5, 3, cz + 5, 2, 0, f, false, 0.9)
		bench(54, 170, -1, 0, F.props)
	end
	-- a noticeboard facing the arrival
	local nx, nz = 62, 164
	if claim("Noticeboard", nx - 1, nz - 5, nx + 1, nz + 5) then
		local f = folder("Noticeboard", F.props)
		local cf = fr(nx, nz, -1, 0)
		for _, s in ipairs({ -1, 1 }) do
			lb(cf, "BoardPost", s * 4.5 - 0.5, 0, -0.5, s * 4.5 + 0.5, 8.5, 0.5, WOOD_DARK, nil, f)
		end
		lb(cf, "Board", -4, 2.5, -0.3, 4, 7.5, 0.3, WOOD, nil, f)
		lb(cf, "BoardRoof", -5.2, 8.5, -1.2, 5.2, 9.1, 1.2, WOOD_DARK, nil, f)
		local head = lb(cf, "BoardHeader", -3, 7.6, -0.5, 3, 8.4, -0.3, WOOD_LIGHT, nil, f)
		boardText(head, "Объявления", nil, { Enum.NormalId.Front })
		for i, p in ipairs({
			{ -2.6, 5.7, 1.6, 2 },
			{ -0.4, 4.7, 1.8, 2.4 },
			{ 2.2, 5.9, 1.6, 1.8 },
			{ 1.6, 3.6, 2, 1.4 },
			{ -2.8, 3.5, 1.4, 1.6 },
		}) do
			lc(
				cf,
				"Notice",
				p[3],
				p[4],
				0.1,
				p[1],
				p[2],
				-0.36,
				if i % 2 == 0 then COL.paperOld else COL.paper,
				Enum.Material.SmoothPlastic,
				f
			)
		end
		lc(
			cf,
			"NoticeSeal",
			0.45,
			0.45,
			0.12,
			-0.4,
			5.6,
			-0.42,
			COL.seal,
			Enum.Material.SmoothPlastic,
			f
		)
		flowerPot(nx - 1.5, 0, nz + 6.4, f)
	end
	-- the viewpoint on the south-east rim: a telescope at the balustrade, a bench behind it with flower pots
	local function rimAt(x)
		local k = math.floor((x + 106) / 4 + 0.5)
		local z = math.huge
		for j = k - 1, k + 1 do
			if cols[j] then
				z = math.min(z, cols[j])
			end
		end
		return if z < math.huge then z else nil
	end
	local tz = rimAt(90)
	if tz and claim("Telescope", 88, tz - 10, 92, tz - 6) then
		telescope(90, tz - 8, 0, 1, F.south)
	end
	local bz = rimAt(80)
	if bz then
		bench(80, bz - 8, 0, 1, F.south, true)
	end
	-- a quiet bench over the clouds in the south-west
	local wz = rimAt(-90)
	if wz then
		bench(-90, wz - 8, 0, 1, F.south, true)
	end
end
task.wait()

-- ================================================================ 2c. the pilgrim's cart behind the buyer's stall
do
	if claim("PilgrimCart", -74.5, 148, -48, 168) then
		local f = folder("PilgrimCart", F.props)
		box("CartBed", -68, 2.6, 156, -60, 3.4, 168, WOOD, nil, f)
		box("CartSide", -68, 3.4, 156, -67.4, 5.2, 168, WOOD_DARK, nil, f)
		box("CartSide", -60.6, 3.4, 156, -60, 5.2, 168, WOOD_DARK, nil, f)
		box("CartBack", -67.4, 3.4, 167.4, -60.6, 5.2, 168, WOOD_DARK, nil, f)
		box("CartFront", -67.4, 3.4, 156, -60.6, 4.6, 156.6, WOOD_DARK, nil, f)
		box("CartAxle", -69.4, 2, 161.6, -58.6, 2.6, 162.4, WOOD_DARK, nil, f)
		box("CartProp", -65, 0, 156.6, -63, 2.6, 157.6, WOOD_DARK, nil, f)
		for _, s in ipairs({ -1, 1 }) do
			local wc = at(-64 + s * 4.9, 2.4, 162)
			textured(
				decor(part("CartWheel", Vector3.new(0.6, 4.6, 4.6), wc, nil, nil, f)),
				WOOD_DARK
			)
			textured(
				decor(
					part(
						"CartWheel",
						Vector3.new(0.6, 4.6, 4.6),
						wc * CFrame.Angles(math.pi / 4, 0, 0),
						nil,
						nil,
						f
					)
				),
				WOOD_DARK
			)
			decor(
				part(
					"CartHub",
					Vector3.new(0.9, 1.2, 1.2),
					wc * CFrame.new(s * 0.2, 0, 0),
					COL.iron,
					Enum.Material.Metal,
					f
				)
			)
			decor(
				beam(
					"CartShaft",
					V(-64 + s * 3, 3, 156),
					V(-64 + s * 3, 0.4, 149.5),
					0.6,
					COL.wood,
					f,
					Enum.Material.Wood
				)
			)
		end
		crate(-65.6, 3.4, 164.6, f, 3.2)
		crate(-62.4, 3.4, 164.6, f, 3.2, 0.15)
		crate(-64, 6.6, 164.6, f, 2.6, -0.2)
		decor(
			part(
				"Sack",
				Vector3.new(2.6, 2.2, 2.6),
				at(-65.6, 4.5, 159.2),
				COL.sack,
				Enum.Material.Fabric,
				f
			)
		)
		decor(
			part(
				"Sack",
				Vector3.new(2.2, 1.8, 2.2),
				at(-62.6, 4.3, 158.6),
				COL.sack,
				Enum.Material.Fabric,
				f
			)
		)
		-- a pilgrim's pennant on a pole at the back corner
		decor(
			beam(
				"PennantPole",
				V(-60.6, 3.4, 167.4),
				V(-60.6, 13.5, 167.4),
				0.4,
				COL.wood,
				f,
				Enum.Material.Wood
			)
		)
		crossBanner(fr(-62, 167.4, 0, 1, 10.6), 2.4, 4.4, f)
		-- chests and barrels round it
		chest(-52, 159, 1, 0, f)
		chest(-52, 164.5, 1, 0, f)
		chest(-56, 154, 0, -1, f)
		barrel(-72, 0, 155, f)
		barrel(-72, 0, 159.5, f, "px_hay")
		barrel(-72, 4, 155, f)
		crate(-72, 0, 164.5, f, B, 0.2)
	end
end

print(
	("[build-church] square: %d parts, %d lights%s"):format(
		count - startCount,
		LIGHTS - lightsLeft,
		if #skipped > 0 then ", skipped " .. table.concat(skipped, " ") else ""
	)
)
