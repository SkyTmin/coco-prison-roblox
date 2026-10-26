--!nocheck
-- ================================================================ paradise: the plaza round the pit, the south axis, the peristyles, the birches, the golden streams
-- The PLAZA part (zoneOf == "plaza": the main island outside roseDist 124), after the concept
-- (assets/concepts/paradise/concept-v2.webp: the top-right view and the small panels), mirror-symmetric in x (only the
-- buyer's corner breaks it: a mirrored prop that would touch the stall is skipped):
--   * round the pit a white balustrade 1 block outside the rim (x ±74, z 50 and 198): white posts with gold caps,
--     quartz rails and balusters, every third bay a white planter with a red flower bush; open at the ladder shafts
--     (N x -12..12, S x -18..18 widened for the arrival, W/E z 112..136) and at the walks SW/SE (z 168..184);
--     lanterns on white posts at the corners and beside each opening;
--   * the south axis x -10..10: white paving from the balustrade to the arrival, candles on white posts beside it,
--     then the white viewing platform x -24..24 from z 218 to the rim with a gold cross inlay, a closed balustrade
--     along the rim and two white columns (±22) with gold sun banners and lanterns on top;
--   * two marble peristyles x ±(106..134), z 60..156 (columns every 2 blocks at x ±108 and ±132, architraves, cross
--     beams, hanging vines, lanterns between the columns, benches inside, gold-glass inlays), open at both ends;
--   * 21 white birches (birch trunks, stepped white wool crowns) on white planters with red flowers, some with a
--     hanging lantern;
--   * two golden rivulets x ±(119..152), z -64..-60 from the golden river to white archways (±162, -62) with vines
--     and a gold-glass waterfall over a white basin;
--   * four angels with raised wings on pillars (±168, -112) and (±150, 146); bird-of-paradise banners, lanterns on
--     white posts, candles and end rods along the edges of the walks W/E, NW/NE and SW/SE (never on them).
-- Kept clear: the pit, its rim and openings, the arrival r 20, the buyer's stall with its crate and barrel, the zone
-- sign, the WALKS and the bridge heads, a 5-block walkway round the balustrade. At most 18 PointLights (S.lights).
local plazaF = folder("Plaza")
local startCount = count
local F = {
	pit = folder("PitBalustrade", plazaF),
	south = folder("SouthAxis", plazaF),
	peristyles = folder("Peristyles", plazaF),
	birches = folder("Birches", plazaF),
	streams = folder("GoldenStreams", plazaF),
	angels = folder("Angels", plazaF),
	walks = folder("WalkEdges", plazaF),
	garden = folder("Garden", plazaF),
}
local COL = {
	iron = Color3.fromRGB(45, 45, 50),
	ironCap = Color3.fromRGB(40, 40, 45),
	rod = Color3.fromRGB(255, 250, 236),
	flame = Color3.fromRGB(255, 206, 110),
}
local S = { lights = 18, skipped = {} } -- the PointLights this part may still add; refused props

-- ================================================================ footprints
-- HARD keep-outs hold for every claimed prop; SOFT ones (the walkway ring round the balustrade) are skipped by
-- opt.edge (the furniture along the walks)
local HARD = {
	{ -78, 46, 78, 202 }, -- the pit, its rim and the balustrade
	{ -44, 205, -26, 230 }, -- the buyer's stall, its crate and barrel
	{ -26, 208, -21, 224 }, -- the customers' side of the counter
	{ 8, 218, 20, 226 }, -- the zone sign
	{ -24, 196, 24, 244 }, -- the south axis and the viewing platform
}
for _, w in ipairs(WALKS) do
	table.insert(HARD, { w[1] - 2, w[2] - 2, w[3] + 2, w[4] + 2 })
end
for _, b in ipairs(BRIDGES) do
	table.insert(HARD, { b[1] - 12, b[2] - 12, b[3] + 12, b[4] + 12 })
end
local SOFT = {
	{ 76, 46, 98, 200 }, -- 5 blocks east and west of the balustrade
	{ -98, 46, -76, 200 },
	{ -98, 30, 98, 46 }, -- north of it, up to the rose
}
local claims = {}
-- a rect must lie on the main island (pad 8) in the plaza zone, off the keep-outs, the arrival (r 20) and everything
-- claimed before; opt.edge skips SOFT, opt.spawnR changes the arrival radius
local function claim(name, ax, az, bx, bz, opt)
	opt = opt or {}
	local x0, x1 = math.min(ax, bx), math.max(ax, bx)
	local z0, z1 = math.min(az, bz), math.max(az, bz)
	local function refuse()
		table.insert(
			S.skipped,
			("%s@%d,%d"):format(name, math.floor((x0 + x1) / 2), math.floor((z0 + z1) / 2))
		)
		return false
	end
	for _, p in ipairs({
		{ x0, z0 },
		{ x1, z0 },
		{ x0, z1 },
		{ x1, z1 },
		{ (x0 + x1) / 2, (z0 + z1) / 2 },
	}) do
		if isleOf(p[1], p[2], 8) ~= "main" or zoneOf(p[1], p[2]) ~= "plaza" then
			return refuse()
		end
	end
	local function hits(list)
		for _, k in ipairs(list) do
			if x0 < k[3] and x1 > k[1] and z0 < k[4] and z1 > k[2] then
				return true
			end
		end
		return false
	end
	if hits(HARD) or hits(claims) or (not opt.edge and hits(SOFT)) then
		return refuse()
	end
	local nx, nz = math.clamp(SPAWN.x, x0, x1), math.clamp(SPAWN.z, z0, z1)
	if math.sqrt((nx - SPAWN.x) ^ 2 + (nz - SPAWN.z) ^ 2) < (opt.spawnR or 20) then
		return refuse()
	end
	table.insert(claims, { x0, z0, x1, z1 })
	return true
end

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
-- a Minecraft lantern scaled by s at a world pos (its bottom at pos.Y - 0.745 s), on a chain up to hangTop (world
-- y); lit while the budget lasts
local function lamp(pos, s, lit, parent, hangTop)
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
	local core = bit("LanternGlow", 0.9, 1, 0.9, 0, 0, 0, LIGHT, Enum.Material.Neon)
	core.Transparency = 0.1
	bit("LanternCap", 0.7, 0.35, 0.7, 0, 0.9, 0, COL.ironCap)
	local top = pos.Y + 1.07 * s
	if hangTop and hangTop > top + 0.1 then
		decor(
			part(
				"Chain",
				Vector3.new(0.3, hangTop - top, 0.3),
				CFrame.new(pos.X, (hangTop + top) / 2, pos.Z),
				COL.iron,
				Enum.Material.Metal,
				parent
			)
		)
	end
	if lit and S.lights > 0 then
		S.lights -= 1
		light(core, 34, 1.3, LIGHT)
	end
	return core
end
-- a red flower bush: a hedge block s wide with n scarlet flowers on top (decor)
local function bush(x, y, z, s, n, parent)
	textured(
		decor(part("Bush", Vector3.new(s, s * 0.8, s), at(x, y + s * 0.4, z), nil, nil, parent)),
		"px_hedge",
		LEAF
	)
	local spots = { { -0.25, 0.22 }, { 0.25, -0.2 }, { 0.08, 0.3 } }
	for i = 1, math.min(n, #spots) do
		local o = spots[i]
		local p = part(
			"Flower",
			Vector3.new(1.2, 1.2, 1.2),
			at(x + o[1] * s, y + s * 0.8 + 0.3, z + o[2] * s),
			nil,
			nil,
			parent
		)
		textured(decor(p), "px_white_wool", SCARLET)
	end
end
-- a lantern on a white post (a quartz foot, a white post, a gold cap, a standing lantern)
local function lanternPost(x, z, lit, parent)
	local f = folder("LanternPost", parent)
	box("PostFoot", x - 2, 0, z - 2, x + 2, 1.2, z + 2, "px_white_stone_bricks", QUARTZ, f)
	box("Post", x - 1, 1.2, z - 1, x + 1, 9, z + 1, "px_smooth_stone", WHITE, f)
	box("PostCap", x - 1.5, 9, z - 1.5, x + 1.5, 9.8, z + 1.5, "px_gold_block", GOLD, f)
	lamp(V(x, 10.8, z), 1.3, lit, f)
	return f
end
-- three candles on a white post with a gold dish
local function candle(x, z, parent)
	local f = folder("CandlePost", parent)
	box("CandlePost", x - 1, 0, z - 1, x + 1, 4, z + 1, "px_smooth_stone", QUARTZ, f)
	decor(box("CandleDish", x - 1.4, 4, z - 1.4, x + 1.4, 4.4, z + 1.4, "px_gold_block", GOLD, f))
	for _, c in ipairs({ { -0.5, -0.4, 1.7 }, { 0.55, -0.3, 1.1 }, { 0, 0.55, 1.4 } }) do
		local h = c[3]
		textured(
			decor(
				part(
					"Candle",
					Vector3.new(0.7, h, 0.7),
					at(x + c[1], 4.4 + h / 2, z + c[2]),
					nil,
					nil,
					f
				)
			),
			"px_white_wool",
			SNOW
		)
		local flame = decor(
			part(
				"CandleFlame",
				Vector3.new(0.3, 0.5, 0.3),
				at(x + c[1], 4.4 + h + 0.3, z + c[2]),
				COL.flame,
				Enum.Material.Neon,
				f
			)
		)
		flame.CastShadow = false
	end
	return f
end
-- an end rod: a thin white Neon rod on a white base
local function endRod(x, z, parent)
	local f = folder("EndRod", parent)
	box("EndRodBase", x - 1.2, 0, z - 1.2, x + 1.2, 1.2, z + 1.2, "px_smooth_stone", QUARTZ, f)
	local rod = decor(
		part("EndRod", Vector3.new(0.5, 8, 0.5), at(x, 5.2, z), COL.rod, Enum.Material.Neon, f)
	)
	rod.CastShadow = false
	decor(
		part(
			"EndRodTip",
			Vector3.new(0.9, 0.5, 0.9),
			at(x, 9.45, z),
			COL.rod,
			Enum.Material.Neon,
			f
		)
	)
	return f
end
-- a white banner with a gold sun and gold hems; cf = the cloth centre, the cloth in the frame's XY plane
local function sunBanner(cf, w, h, parent)
	lc(cf, "BannerRod", w + 0.6, 0.4, 0.4, 0, h / 2 + 0.2, 0, GOLD, Enum.Material.Metal, parent)
	textured(lc(cf, "Banner", w, h, 0.2, 0, 0, 0, nil, nil, parent), "px_white_wool", SNOW)
	local sy = h * 0.12
	local function g(name, sx, sy2, x, y)
		textured(lc(cf, name, sx, sy2, 0.3, x, y, 0, nil, nil, parent), "px_gold_block", GOLD)
	end
	g("BannerSun", w * 0.4, w * 0.4, 0, sy)
	g("BannerRay", w * 0.82, w * 0.12, 0, sy)
	g("BannerRay", w * 0.12, w * 0.82, 0, sy)
	g("BannerHem", w, 0.4, 0, -h / 2 + 0.2)
	g("BannerHem", 0.3, h, -w / 2 + 0.15, 0)
	g("BannerHem", 0.3, h, w / 2 - 0.15, 0)
end
-- a balustrade run from a to b (a < b) along x (or z) at c: a quartz kerb and rail, posts by node(x, z) about every 8
-- studs, quartz balusters in the bays; when planters, every third bay (counted by |mid| so mirrored runs match) is a
-- white planter with a red flower bush
local function balRun(f, alongX, a, b, c, node, planters)
	local function span(name, lo, hi, y0, y1, half, variant, tint)
		if alongX then
			return box(name, lo, y0, c - half, hi, y1, c + half, variant, tint, f)
		end
		return box(name, c - half, y0, lo, c + half, y1, hi, variant, tint, f)
	end
	span("BalustradeKerb", a, b, 0, 1, 1.4, "px_white_stone_bricks", QUARTZ)
	span("BalustradeRail", a, b, 3.2, 4, 0.9, "px_smooth_stone", QUARTZ)
	local n = math.max(1, math.floor((b - a) / 8 + 0.5))
	local step = (b - a) / n
	local prev = nil
	for i = 0, n do
		local t = if i == n then b else a + step * i
		if alongX then
			node(t, c)
		else
			node(c, t)
		end
		if prev then
			local gap = t - prev - 4
			local mid = (t + prev) / 2
			if planters and gap >= 3 and math.floor(math.abs(mid) / step) % 3 == 1 then
				span("BayPlanter", prev + 2, t - 2, 1, 3, 1.4, "px_smooth_stone", WHITE)
				local bx, bz = if alongX then mid else c, if alongX then c else mid
				bush(bx, 3, bz, math.min(gap, 3), 2, f)
			elseif gap > 0.5 then
				local nb = math.max(1, math.floor(gap / 2))
				for j = 1, nb do
					local m = prev + 2 + gap * (j - 0.5) / nb
					decor(
						span("Baluster", m - 0.5, m + 0.5, 1, 3.2, 0.5, "px_smooth_stone", QUARTZ)
					)
				end
			end
		end
		prev = t
	end
end
-- a white birch on a stepped white planter with red flowers; R = { puffs = {{ox, y, oz}}, lantern = oz | nil },
-- offsets in studs, ox mirrored by sx
local function birch(x, z, h, sx, R, parent)
	if not claim("Birch", x - 6.5, z - 6.5, x + 6.5, z + 6.5) then
		return
	end
	local f = folder("Birch", parent)
	box(
		"PlanterBase",
		x - 6.5,
		0,
		z - 6.5,
		x + 6.5,
		1.6,
		z + 6.5,
		"px_white_stone_bricks",
		QUARTZ,
		f
	)
	box("Planter", x - 5.5, 1.6, z - 5.5, x + 5.5, 3.2, z + 5.5, "px_smooth_stone", WHITE, f)
	decor(box("PlanterSoil", x - 4.9, 3.2, z - 4.9, x + 4.9, 3.5, z + 4.9, "px_hedge", LEAF, f))
	local top = 3.5 + h * B
	box("BirchTrunk", x - 2, 3.5, z - 2, x + 2, top, z + 2, "px_birch_log", BIRCH, f)
	for _, o in ipairs({ { -3.6, -3.6, 2 }, { 3.6, -3.6, 2 }, { -3.6, 3.6, 2 }, { 3.6, 3.6, 2 } }) do
		bush(x + o[1], 3.5, z + o[2], 2.4, o[3], f)
	end
	for _, o in ipairs({ { 0, -3.9 }, { 0, 3.9 }, { -3.9, 0 }, { 3.9, 0 } }) do
		local p =
			part("Flower", Vector3.new(1.2, 1.2, 1.2), at(x + o[1], 4.1, z + o[2]), nil, nil, f)
		textured(decor(p), "px_white_wool", SCARLET)
	end
	-- the stepped crown of white wool (3, 5, 4, 3, 1 blocks wide) and a few loose puffs
	for i, l in ipairs({ { -6, -2, 3 }, { -2, 2, 5 }, { 2, 6, 4 }, { 6, 10, 3 }, { 10, 13, 1 } }) do
		local r = l[3] * B / 2
		box(
			"Crown",
			x - r,
			top + l[1],
			z - r,
			x + r,
			top + l[2],
			z + r,
			"px_white_wool",
			if i % 2 == 0 then SNOW else CLOUD,
			f
		)
	end
	for _, p in ipairs(R.puffs) do
		local px, pz = x + sx * p[1], z + p[3]
		box(
			"CrownPuff",
			px - 2,
			top + p[2] - 2,
			pz - 2,
			px + 2,
			top + p[2] + 2,
			pz + 2,
			"px_white_wool",
			SNOW,
			f
		)
	end
	if R.lantern then
		local p = V(x + sx * 7, top - 7, z + R.lantern)
		lamp(p, 1.2, false, f, BY + top - 2)
	end
end
-- an angel with raised wings on a white pillar at (x, z), looking along (dx, dz)
local function angel(x, z, dx, dz, parent)
	if not claim("Angel", x - 6, z - 6, x + 6, z + 6) then
		return
	end
	local f = folder("Angel", parent)
	local cf = fr(x, z, dx, dz)
	local function g(name, x0, y0, z0, x1, y1, z1, variant, tint)
		return decor(lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, f))
	end
	lb(cf, "PillarFoot", -6, 0, -6, 6, 1.2, 6, "px_white_stone_bricks", QUARTZ, f)
	lb(cf, "PillarBase", -5, 1.2, -5, 5, 4, 5, "px_smooth_stone", WHITE, f)
	lb(cf, "Pillar", -4, 4, -4, 4, 16, 4, "px_white_stone_bricks", QUARTZ, f)
	g("PillarBand", -4.3, 9.6, -4.3, 4.3, 10.4, 4.3, "px_gold_block", GOLD)
	lb(cf, "PillarCap", -5, 16, -5, 5, 17.4, 5, "px_smooth_stone", WHITE, f)
	g("PillarCapGold", -5.2, 17.4, -5.2, 5.2, 18, 5.2, "px_gold_block", GOLD)
	-- the figure: a white robe with a gold belt, praying hands, a gold halo
	g("RobeHem", -3.6, 18, -3, 3.6, 20, 3, "px_white_wool", SNOW)
	g("Robe", -3, 20, -2.4, 3, 28, 2.4, "px_white_wool", SNOW)
	g("Belt", -3.2, 25.6, -2.6, 3.2, 26.4, 2.6, "px_gold_block", GOLD)
	g("Torso", -2.8, 28, -2, 2.8, 32, 2, "px_white_wool", CLOUD)
	g("Head", -1.8, 32, -1.8, 1.8, 35.6, 1.8, "px_smooth_stone", CALCITE)
	g("Hair", -2, 34.8, -2, 2, 36, 2, "px_white_stone_bricks", QUARTZ)
	g("HairBack", -2, 32.6, 1.2, 2, 34.8, 2, "px_white_stone_bricks", QUARTZ)
	for _, s in ipairs({ -1, 1 }) do
		g("Sleeve", s * 2.8, 27, -2, s * 3.8, 31.6, 1.4, "px_white_wool", SNOW)
		g("Forearm", s * 3.6, 28.2, -3.6, s * 1, 29.6, -2, "px_white_wool", SNOW)
	end
	g("Hands", -1, 28.4, -3.8, 1, 30.8, -2.2, "px_smooth_stone", CALCITE)
	for _, hb in ipairs({
		{ -2.4, -2.4, 2.4, -1.8 },
		{ -2.4, 1.8, 2.4, 2.4 },
		{ -2.4, -1.8, -1.8, 1.8 },
		{ 1.8, -1.8, 2.4, 1.8 },
	}) do
		g("Halo", hb[1], 37, hb[2], hb[3], 37.6, hb[4], "px_gold_block", GOLD)
	end
	-- the wings raised high in a V: stepped columns rising outward behind the shoulders, feathers behind
	for _, s in ipairs({ -1, 1 }) do
		for i = 1, 6 do
			local xa, xb = s * (1.4 + (i - 1) * 2.2), s * (1.4 + i * 2.2)
			local y0, y1 = 24 + 2 * i, 33 + 3.4 * i
			g("Wing", xa, y0, 2, xb, y1, 3.4, "px_white_wool", SNOW)
			g("WingFeathers", xa, y0 + 2, 3.4, xb, y1 - 1.4, 4.2, "px_smooth_stone", QUARTZ)
		end
		g("WingTip", s * 12.4, 53.4, 2, s * 14.6, 56, 3.4, "px_white_wool", SNOW)
	end
end
-- a bird-of-paradise banner on a white pole at (x, z), the cloth facing (dx, dz); sx mirrors the bird
local function birdBanner(x, z, dx, dz, sx, parent)
	-- the claim is the 4×4 base (Studio 26.10: a 5×5 claim at z ±12 reached 0.5 stud into the walk keep-out, all 8 skipped)
	if not claim("BirdBanner", x - 2, z - 2, x + 2, z + 2, { edge = true }) then
		return
	end
	local f = folder("BirdBanner", parent)
	local cf = fr(x, z, dx, dz)
	lb(cf, "BannerBase", -2, 0, -2, 2, 1.2, 2, "px_smooth_stone", WHITE, f)
	lb(cf, "BannerPole", -0.5, 1.2, -0.5, 0.5, 17, 0.5, "px_smooth_stone", QUARTZ, f)
	decor(lb(cf, "BannerFinial", -0.9, 17, -0.9, 0.9, 18.6, 0.9, "px_gold_block", GOLD, f))
	decor(lb(cf, "BannerBar", -3, 15.6, -1.1, 3, 16.2, -0.5, "px_gold_block", GOLD, f))
	decor(lb(cf, "Banner", -2.6, 5.6, -1, 2.6, 15.6, -0.7, "px_white_wool", SNOW, f))
	-- the bird (a scarlet body, gold wings, crest, beak and long plumes) through both faces of the cloth
	local function m(name, x0, y0, x1, y1, variant, tint)
		decor(lb(cf, name, sx * x0, y0, -1.15, sx * x1, y1, -0.55, variant, tint, f))
	end
	m("BirdBody", -0.6, 10.4, 0.8, 12.2, "px_white_wool", SCARLET)
	m("BirdHead", 0.6, 12, 1.6, 13, "px_white_wool", SCARLET)
	m("BirdBeak", 1.6, 12.3, 2.2, 12.7, "px_gold_block", GOLD)
	m("BirdCrest", 0.7, 13, 1.3, 13.8, "px_gold_block", GOLD)
	m("BirdWing", -1.6, 11.4, 0.4, 12.6, "px_gold_block", GOLD)
	m("BirdWingTip", -2, 12.4, -0.8, 13.4, "px_gold_block", GOLD)
	m("BirdPlume", -0.4, 6.8, 0, 10.4, "px_gold_block", GOLD)
	m("BirdPlume", -1.2, 7.6, -0.8, 10.6, "px_gold_block", GOLD)
	m("BirdPlume", 0.4, 7.2, 0.8, 10.4, "px_white_wool", SCARLET)
	m("BannerHem", -2.6, 5.6, 2.6, 6.2, "px_gold_block", GOLD)
	m("BannerHem", -2.6, 15, 2.6, 15.6, "px_gold_block", GOLD)
end
-- a white planter (2×1 blocks) with red flower bushes
local function flowerPlanter(x, z, alongX, parent)
	local ex, ez = if alongX then 4 else 2, if alongX then 2 else 4
	if not claim("Planter", x - ex, z - ez, x + ex, z + ez) then
		return
	end
	local f = folder("FlowerPlanter", parent)
	box("Planter", x - ex, 0, z - ez, x + ex, 2.4, z + ez, "px_smooth_stone", WHITE, f)
	box(
		"PlanterLip",
		x - ex - 0.3,
		2.4,
		z - ez - 0.3,
		x + ex + 0.3,
		2.9,
		z + ez + 0.3,
		"px_white_stone_bricks",
		QUARTZ,
		f
	)
	for _, t in ipairs({ -2, 2 }) do
		bush(if alongX then x + t else x, 2.9, if alongX then z else z + t, 3, 3, f)
	end
end

-- ================================================================ 1. the balustrade round the pit, its lantern posts
do
	local f = F.pit
	local built = {}
	-- lantern posts: key -> lit; the corners, beside each ladder opening and the walks SW/SE
	local lanterns = {}
	for _, s in ipairs({ -1, 1 }) do
		lanterns[(s * 14) .. ",50"] = true
		lanterns[(s * 20) .. ",198"] = true
		lanterns[(s * 74) .. ",110"] = true
		lanterns[(s * 74) .. ",138"] = true
		lanterns[(s * 74) .. ",50"] = false
		lanterns[(s * 74) .. ",198"] = false
		lanterns[(s * 74) .. ",166"] = false
		lanterns[(s * 74) .. ",186"] = false
	end
	local function node(x, z)
		local key = x .. "," .. z
		if built[key] then
			return
		end
		built[key] = true
		box("BalustradePost", x - 2, 0, z - 2, x + 2, 4, z + 2, "px_smooth_stone", WHITE, f)
		box("BalustradeCap", x - 2.3, 4, z - 2.3, x + 2.3, 4.6, z + 2.3, "px_gold_block", GOLD, f)
		local lit = lanterns[key]
		if lit ~= nil then
			box("LanternPost", x - 1, 4.6, z - 1, x + 1, 10, z + 1, "px_smooth_stone", WHITE, f)
			box(
				"LanternPostCap",
				x - 1.4,
				10,
				z - 1.4,
				x + 1.4,
				10.8,
				z + 1.4,
				"px_gold_block",
				GOLD,
				f
			)
			lamp(V(x, 11.85, z), 1.4, lit, f)
		end
	end
	local runs = {
		{ true, -74, -14, 50 }, -- north, open x -12..12 (the ladder and the walk to the rose)
		{ true, 14, 74, 50 },
		{ true, -74, -20, 198 }, -- south, open x -18..18 (widened: the arrival stays 20+ studs away)
		{ true, 20, 74, 198 },
	}
	for _, s in ipairs({ -1, 1 }) do
		-- west and east: open z 112..136 (the ladder) and z 168..184 (the walks SW/SE)
		table.insert(runs, { false, 50, 110, s * 74 })
		table.insert(runs, { false, 138, 166, s * 74 })
		table.insert(runs, { false, 186, 198, s * 74 })
	end
	for _, r in ipairs(runs) do
		balRun(f, r[1], r[2], r[3], r[4], node, true)
	end
end
task.wait()

-- ================================================================ 2. the south axis: paving, candles, the viewing platform
do
	local f = F.south
	-- the z of the south rim at column x (solid ground, pad 8)
	local function rimZ(x)
		for z = 244, 200, -1 do
			if isleOf(x - 2, z, 8) == "main" and isleOf(x + 2, z, 8) == "main" then
				return z
			end
		end
		return 200
	end
	local rz = 244
	for x = -24, 24, 4 do
		rz = math.min(rz, rimZ(x))
	end
	rz = math.floor(rz)
	local Z0 = 218 -- where the platform starts, 4 studs south of the arrival pad
	-- white paving x -10..10 from the balustrade to the platform, a hole round the arrival pad, gold kerbs
	local pave =
		{ { -10, 200, 10, 211 }, { -10, 211, -3, 217 }, { 3, 211, 10, 217 }, { -10, 217, 10, Z0 } }
	for _, p in ipairs(pave) do
		box("AxisPaving", p[1], 0, p[2], p[3], 0.15, p[4], "px_smooth_stone", SNOW, f)
	end
	for _, s in ipairs({ -1, 1 }) do
		decor(box("AxisKerb", s * 9.2, 0.15, 200, s * 10, 0.25, Z0, "px_gold_block", GOLD, f))
	end
	-- candles on white posts beside the paving (outside the walk), north of the arrival
	for _, z in ipairs({ 203, 209 }) do
		for _, s in ipairs({ -1, 1 }) do
			candle(s * 13, z, f) -- clear of the stall's customers (x < -21) and the sign (z > 218)
		end
	end
	if rz - Z0 >= 4 then
		-- the platform x -24..24 to the rim: snow and calcite stripes, gold edges, a gold lip at its front
		for k = 0, 11 do
			local x0 = -24 + 4 * k
			local edge = k == 0 or k == 11
			box(
				"TipFloor",
				x0,
				0,
				Z0,
				x0 + 4,
				0.35,
				rz,
				if edge then "px_gold_block" else "px_smooth_stone",
				if edge then GOLD elseif k % 2 == 0 then SNOW else CALCITE,
				f
			)
		end
		decor(box("TipFloorEdge", -24, 0.35, Z0, 24, 0.45, Z0 + 1, "px_gold_block", GOLD, f))
	end
	-- the gold cross inlay on the axis south of the arrival (north of it when the rim is too close)
	local c0, c1 = Z0 + 1.5, rz - 5
	if c1 - c0 < 6 then
		c0, c1 = 200.5, 210
	end
	local yb = if c0 > Z0 then 0.35 else 0.15
	decor(box("CrossInlay", -1.2, yb, c0, 1.2, yb + 0.1, c1, "px_gold_block", GOLD, f))
	local cm = c0 + (c1 - c0) * 0.36
	decor(box("CrossInlay", -6, yb, cm - 1.2, 6, yb + 0.1, cm + 1.2, "px_gold_block", GOLD, f))
	-- the closed balustrade along the rim between the two columns
	if rz - Z0 >= 4 then
		balRun(f, true, -20, 20, rz - 2, function(x, z)
			if math.abs(x) < 19 then
				box(
					"BalustradePost",
					x - 2,
					0.35,
					z - 2,
					x + 2,
					4,
					z + 2,
					"px_smooth_stone",
					WHITE,
					f
				)
				box(
					"BalustradeCap",
					x - 2.3,
					4,
					z - 2.3,
					x + 2.3,
					4.6,
					z + 2.3,
					"px_gold_block",
					GOLD,
					f
				)
			end
		end, false)
	end
	-- two white columns with gold sun banners (toward the arrival) and lanterns on top
	local cz = math.max(rz - 2, Z0 + 2)
	for _, s in ipairs({ -1, 1 }) do
		local x = s * 22
		box(
			"TipColumnFoot",
			x - 2.7,
			0,
			cz - 2.7,
			x + 2.7,
			1.6,
			cz + 2.7,
			"px_white_stone_bricks",
			QUARTZ,
			f
		)
		box("TipColumn", x - 2, 1.6, cz - 2, x + 2, 22, cz + 2, "px_smooth_stone", WHITE, f)
		decor(
			box(
				"TipColumnBand",
				x - 2.2,
				12,
				cz - 2.2,
				x + 2.2,
				12.8,
				cz + 2.2,
				"px_gold_block",
				GOLD,
				f
			)
		)
		box(
			"TipColumnCap",
			x - 2.7,
			22,
			cz - 2.7,
			x + 2.7,
			23.4,
			cz + 2.7,
			"px_white_stone_bricks",
			QUARTZ,
			f
		)
		decor(
			box(
				"TipColumnCapGold",
				x - 2.2,
				23.4,
				cz - 2.2,
				x + 2.2,
				24,
				cz + 2.2,
				"px_gold_block",
				GOLD,
				f
			)
		)
		lamp(V(x, 25.2, cz), 1.6, true, f)
		sunBanner(at(x, 15.4, cz - 2.3), 3.2, 8, f)
	end
	print(("[build-paradise] plaza: south rim at z %d"):format(rz))
end
task.wait()

-- ================================================================ 3. the marble peristyles east and west of the pit
do
	local XI, XO, Z0, Z1 = 108, 132, 64, 152 -- column rows (abs x) and the first and last column z
	-- the vines drawn once and mirrored: per cross beam two { x, len, w }; per row face { z, len }
	local beamVines, faceVines = {}, { {}, {} }
	for i = 1, 12 do
		beamVines[i] = {
			{ 110 + rng:NextInteger(0, 3) * 2, rng:NextInteger(3, 9), pick({ 1.6, 2.4 }) },
			{ 122 + rng:NextInteger(0, 3) * 2, rng:NextInteger(3, 9), pick({ 1.6, 2.4 }) },
		}
	end
	for r = 1, 2 do
		for j = 1, 7 do
			faceVines[r][j] = { 62 + j * 12 + rng:NextInteger(-3, 3), rng:NextInteger(4, 10) }
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		if claim("Peristyle", sx * 104, 58, sx * 136, 158) then
			local f = folder("Peristyle", F.peristyles)
			local function m(name, x0, y0, z0, x1, y1, z1, variant, tint, isDecor)
				local p = box(name, sx * x0, y0, z0, sx * x1, y1, z1, variant, tint, f)
				if isDecor then
					decor(p)
				end
				return p
			end
			-- the floor: a calcite slab with gold-glass inlays down the middle
			m("PeristyleFloor", 106, 0, 60, 134, 0.15, 156, "px_smooth_stone", CALCITE)
			for _, z in ipairs({ 68, 84, 100, 116, 132, 148 }) do
				m("InlayGold", 118, 0.15, z - 2, 122, 0.22, z + 2, "px_gold_block", GOLD, true)
				local g = part(
					"InlayGlass",
					Vector3.new(3.6, 0.12, 3.6),
					at(sx * 120, 0.28, z),
					GOLD_GLASS,
					Enum.Material.Glass,
					f
				)
				g.Transparency = 0.35
				decor(g)
			end
			-- the columns, the architraves with a gold string course, the cross beams and two purlins
			for _, r in ipairs({ XI, XO }) do
				for z = Z0, Z1, 8 do
					m(
						"ColumnBase",
						r - 2.6,
						0.15,
						z - 2.6,
						r + 2.6,
						1.2,
						z + 2.6,
						"px_white_stone_bricks",
						QUARTZ
					)
					m("Column", r - 2, 1.2, z - 2, r + 2, 15, z + 2, "px_smooth_stone", WHITE)
					m(
						"ColumnCapital",
						r - 2.6,
						15,
						z - 2.6,
						r + 2.6,
						16,
						z + 2.6,
						"px_white_stone_bricks",
						QUARTZ
					)
				end
				m(
					"Architrave",
					r - 2.6,
					16,
					Z0 - 2.6,
					r + 2.6,
					19.6,
					Z1 + 2.6,
					"px_smooth_stone",
					QUARTZ
				)
				m(
					"StringCourse",
					r - 2.8,
					18.6,
					Z0 - 2.8,
					r + 2.8,
					19.2,
					Z1 + 2.8,
					"px_gold_block",
					GOLD,
					true
				)
			end
			for i, z in ipairs({ 64, 72, 80, 88, 96, 104, 112, 120, 128, 136, 144, 152 }) do
				m(
					"CrossBeam",
					XI - 3.4,
					19.6,
					z - 1.4,
					XO + 3.4,
					22,
					z + 1.4,
					"px_white_stone_bricks",
					QUARTZ
				)
				for _, v in ipairs(beamVines[i]) do
					m(
						"Vine",
						v[1] - v[3] / 2,
						19.6 - v[2],
						z - 0.2,
						v[1] + v[3] / 2,
						19.6,
						z + 0.2,
						"px_hedge",
						LEAF,
						true
					)
				end
			end
			for _, px in ipairs({ 116, 124 }) do
				m("Purlin", px - 1, 22, Z0 - 3, px + 1, 23.4, Z1 + 3, "px_smooth_stone", WHITE)
			end
			-- vines on the outer faces of both architraves
			for r, row in ipairs({ { XI - 3, XI - 2.6 }, { XO + 2.6, XO + 3 } }) do
				for _, v in ipairs(faceVines[r]) do
					m(
						"Vine",
						row[1],
						19.6 - v[2],
						v[1] - 1,
						row[2],
						19.6,
						v[1] + 1,
						"px_hedge",
						LEAF,
						true
					)
				end
			end
			-- lanterns hanging from the architraves between the columns
			for _, l in ipairs({
				{ XI, 68 },
				{ XI, 92 },
				{ XI, 116, true },
				{ XI, 140 },
				{ XO, 76 },
				{ XO, 124 },
			}) do
				lamp(V(sx * l[1], 12.6, l[2]), 1.3, l[3] == true, f, BY + 16)
			end
			-- benches inside along the outer row, facing the pit
			for _, z in ipairs({ 84, 108, 132 }) do
				local cf = fr(sx * 127, z, -sx, 0)
				for _, s in ipairs({ -1, 1 }) do
					lb(
						cf,
						"BenchLeg",
						s * 4.6 - 0.8,
						0.15,
						-1.2,
						s * 4.6 + 0.8,
						1.6,
						1.2,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
				end
				lb(cf, "BenchSeat", -5.8, 1.6, -1.4, 5.8, 2.4, 1.4, "px_smooth_stone", WHITE, f)
				lb(cf, "BenchBack", -5.8, 2.4, 0.8, 5.8, 4.6, 1.4, "px_smooth_stone", WHITE, f)
				decor(
					lb(cf, "BenchBackGold", -5.8, 4.6, 0.8, 5.8, 5, 1.4, "px_gold_block", GOLD, f)
				)
			end
			-- red flower bushes at the ends of the outer row
			for _, z in ipairs({ Z0 - 6, Z1 + 6 }) do
				bush(sx * XO, 0, z, 3, 3, f)
			end
		end
	end
end
task.wait()

-- ================================================================ 4. the golden streams and their archways
do
	for _, sx in ipairs({ -1, 1 }) do
		local f = folder("GoldenStream", F.streams)
		local function m(name, x0, y0, z0, x1, y1, z1, variant, tint, isDecor)
			local p = box(name, sx * x0, y0, z0, sx * x1, y1, z1, variant, tint, f)
			if isDecor then
				decor(p)
			end
			return p
		end
		local okStream = claim("Stream", sx * 124, -67, sx * 145, -57)
		local okArch = claim("GoldArch", sx * 145, -76, sx * 167, -48)
		if okStream and okArch then
			-- the rivulet: gold water under yellow glass tiles from the golden river (x 120) into the basin, flush
			m("StreamGold", 119, 0, -64, 152, 0.15, -60, "px_gold_block", GOLD)
			for x0 = 120, 148, 4 do
				local g = part(
					"StreamGlass",
					Vector3.new(B - 0.2, 0.2, B - 0.2),
					at(sx * (x0 + 2), 0.25, -62),
					GOLD_GLASS,
					Enum.Material.Glass,
					f
				)
				g.Transparency = 0.35
				g.CastShadow = false
			end
			for _, z in ipairs({ -66, -60 }) do
				m("StreamKerb", 124, 0, z, 150, 0.3, z + 2, "px_white_stone_bricks", QUARTZ)
			end
			-- the white basin with a gold lip, gold water inside
			for _, w in ipairs({
				{ 150, -72, 152, -64 },
				{ 150, -60, 152, -52 },
				{ 164, -72, 166, -52 },
				{ 152, -72, 164, -70 },
				{ 152, -54, 164, -52 },
			}) do
				m("BasinWall", w[1], 0, w[2], w[3], 2.4, w[4], "px_smooth_stone", WHITE)
				m("BasinLip", w[1], 2.4, w[2], w[3], 2.8, w[4], "px_gold_block", GOLD, true)
			end
			m("BasinFloor", 152, 0, -70, 164, 0.15, -54, "px_gold_block", GOLD)
			local water = part(
				"BasinWater",
				Vector3.new(12, 1.7, 16),
				at(sx * 158, 1, -62),
				GOLD_WATER,
				Enum.Material.Glass,
				f
			)
			water.Transparency = 0.3
			water.CastShadow = false
			decor(water)
			-- the archway over the back of the basin: two pillars, a lintel, a stepped crown with a gold keystone
			for _, z in ipairs({ -70, -54 }) do
				m("ArchPlinth", 159.4, 0, z - 2.6, 164.6, 3.4, z + 2.6, "px_smooth_stone", WHITE)
				m("ArchPillar", 160, 3.4, z - 2, 164, 20.6, z + 2, "px_white_stone_bricks", QUARTZ)
				m("ArchCapital", 159.4, 20.6, z - 2.6, 164.6, 22, z + 2.6, "px_smooth_stone", WHITE)
			end
			m("ArchLintel", 159.6, 22, -73, 164.4, 26, -51, "px_smooth_stone", WHITE)
			m("ArchCrown", 160, 26, -69, 164, 28.4, -55, "px_white_stone_bricks", QUARTZ)
			m("ArchTop", 160, 28.4, -65, 164, 31, -59, "px_smooth_stone", WHITE)
			m("ArchKeystone", 159.2, 23, -63.4, 159.8, 25.4, -60.6, "px_gold_block", GOLD, true)
			m("ArchFinial", 161.2, 31, -63.2, 162.8, 33, -60.8, "px_gold_block", GOLD, true)
			-- the gold spout and the gold-glass waterfall falling through the arch into the basin
			m("Spout", 159, 21, -64, 162.6, 22, -60, "px_gold_block", GOLD, true)
			local fall = part(
				"Waterfall",
				Vector3.new(1.2, 19.2, 3.2),
				at(sx * 161.2, 11.4, -62),
				GOLD_GLASS,
				Enum.Material.Glass,
				f
			)
			fall.Transparency = 0.3
			fall.CastShadow = false
			decor(fall)
			local splash = part(
				"Splash",
				Vector3.new(6, 0.6, 7),
				at(sx * 160.6, 2, -62),
				GOLD_GLASS,
				Enum.Material.Glass,
				f
			)
			splash.Transparency = 0.5
			splash.CastShadow = false
			decor(splash)
			-- vines hanging from the lintel on both faces and climbing the pillars
			for _, v in ipairs({ { -71.6, 7 }, { -67.4, 10 }, { -56.6, 6 }, { -52.4, 9 } }) do
				m(
					"Vine",
					159.1,
					22 - v[2],
					v[1] - 1.2,
					159.5,
					22,
					v[1] + 1.2,
					"px_hedge",
					LEAF,
					true
				)
				m(
					"Vine",
					164.5,
					22 - v[2] + 2,
					v[1] - 1,
					164.9,
					22,
					v[1] + 1,
					"px_hedge",
					LEAF,
					true
				)
			end
			m("Vine", 160.4, 3.4, -73, 162.4, 16, -72.6, "px_hedge", LEAF, true)
			m("Vine", 161.6, 6, -51.4, 163.6, 21, -51, "px_hedge", LEAF, true)
			-- lanterns on brackets at the front of the pillars, red flower bushes by the basin
			for _, l in ipairs({ { -70, true }, { -54, false } }) do
				m(
					"LanternArm",
					156.4,
					20.2,
					l[1] - 0.5,
					159.4,
					21,
					l[1] + 0.5,
					"px_gold_block",
					GOLD,
					true
				)
				lamp(V(sx * 157, 17.6, l[1]), 1.3, l[2], f, BY + 20.2)
			end
			for _, z in ipairs({ -74, -50 }) do
				bush(sx * 148, 0, z, 3, 3, f)
			end
		end
	end
end
task.wait()

-- ================================================================ 5. the angels, the birches, the planters
do
	for _, a in ipairs({ { 168, -112, -1, 0 }, { 150, 146, -0.9, 0.45 } }) do
		for _, sx in ipairs({ -1, 1 }) do
			angel(sx * a[1], a[2], sx * a[3], a[4], F.angels)
		end
	end
	-- { x, z, trunk blocks, hanging lantern, eastOnly } (east-side spots; each is built at x and -x)
	local BIRCHES = {
		{ 120, 36, 5 },
		{ 156, 36, 6, true },
		{ 192, 36, 4 },
		{ 168, 76, 6 },
		{ 176, 116, 5, true },
		{ 140, -36, 5 },
		{ 184, -36, 6, true },
		{ 196, -84, 4 },
		{ 136, -110, 7, true },
		{ 150, -146, 5 },
		{ 40, 210, 5, true, true }, -- the mirror of the buyer's corner: east only
	}
	for _, b in ipairs(BIRCHES) do
		local R = { puffs = {} }
		for k = 1, 4 do
			local o = (rng:NextInteger(0, 1) * 2 - 1) * 12
			local t = rng:NextInteger(-2, 2) * 4
			local yl = rng:NextInteger(0, 1) * 4
			if yl > 0 then
				o = o * 10 / 12
			end
			table.insert(R.puffs, if k % 2 == 1 then { o, yl, t } else { t, yl, o })
		end
		if b[4] then
			R.lantern = rng:NextInteger(-1, 1) * 4
		end
		for _, sx in ipairs(if b[5] then { 1 } else { -1, 1 }) do
			birch(sx * b[1], b[2], b[3], sx, R, F.birches)
		end
	end
	for _, p in ipairs({
		{ 108, 24, true },
		{ 136, -74, true },
		{ 136, -50, true },
		{ 150, 60, false },
		{ 60, 214, false },
	}) do
		for _, sx in ipairs({ -1, 1 }) do
			flowerPlanter(sx * p[1], p[2], p[3], F.garden)
		end
	end
end
task.wait()

-- ================================================================ 6. the walk edges: lanterns, candles, banners, end rods
do
	-- { x, z, kind, lit, banner dz } (east-side spots; each is built at x and -x)
	local EDGE = {
		{ 112, -12, "lantern" },
		{ 112, 12, "lantern" },
		{ 128, -12, "bird", false, 1 },
		{ 128, 12, "bird", false, -1 },
		{ 136, -12, "candle" },
		{ 136, 12, "candle" },
		{ 144, -12, "rod" },
		{ 144, 12, "rod" },
		{ 160, -12, "lantern" },
		{ 160, 12, "lantern", true },
		{ 176, -12, "rod" },
		{ 176, 12, "rod" },
		{ 184, -12, "candle" },
		{ 184, 12, "candle" },
		{ 192, -12, "bird", false, 1 },
		{ 192, 12, "bird", false, -1 },
		{ 208, -12, "rod" },
		{ 208, 12, "rod" },
		{ 100, -164, "candle" }, -- the walks NW/NE
		{ 116, -164, "lantern" },
		{ 132, -164, "rod" },
		{ 100, -188, "rod" },
		{ 116, -188, "lantern" },
		{ 100, 164, "rod" }, -- the walks SW/SE
		{ 116, 164, "lantern", true },
		{ 132, 164, "candle" },
		{ 100, 188, "lantern" },
		{ 116, 188, "rod" },
	}
	local f = F.walks
	for _, e in ipairs(EDGE) do
		for _, sx in ipairs({ -1, 1 }) do
			local x, z, kind = sx * e[1], e[2], e[3]
			if kind == "bird" then
				birdBanner(x, z, 0, e[5], sx, f)
			else
				local r = if kind == "lantern" then 2 elseif kind == "candle" then 1.4 else 1.2
				if claim(kind, x - r, z - r, x + r, z + r, { edge = true }) then
					if kind == "lantern" then
						lanternPost(x, z, e[4] == true, f)
					elseif kind == "candle" then
						candle(x, z, f)
					else
						endRod(x, z, f)
					end
				end
			end
		end
	end
end

print(
	("[build-paradise] plaza: %d parts, %d lights%s"):format(
		count - startCount,
		18 - S.lights,
		if #S.skipped > 0 then ", skipped " .. table.concat(S.skipped, " ") else ""
	)
)
