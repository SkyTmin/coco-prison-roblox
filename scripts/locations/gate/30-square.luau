--!nocheck
-- ================================================================ gate: the square — the golden road, the pylons, the banners, the pit, the fountains, the south tip
-- The SQUARE part (zoneOf == "square": the main island except |x| <= 130 with z < -66), after the concept
-- (assets/concepts/gate/concept-v2.webp), strictly mirror-symmetric in x (only the buyer's corner breaks it: a
-- mirrored prop that would touch the stall is skipped, never moved):
--   * the golden ROAD x -12..12, z -70..-2 and the south axis x -12..12, z 142..174 (a hole 8 studs round the
--     arrival): a gold floor under 1-block tiles of yellow glass, a pearl kerb either side, all flush and walkable;
--   * torch pylons at x ±18, z -12 → -60 every 12, shrinking toward the gate (7 → 5 blocks): a 2×2 pearl base, a
--     1×1 white shaft with teal bands and a gold sun banner facing the road, a gold capital, a fire;
--   * the 12 tribe banners on gold poles with gold finials in a row behind the pylons (x ±27, z -14 → -61, six a
--     side), white glyphs; twelve smaller banners on the posts of the pit balustrade's south side (facing the
--     arrival); two white braziers (±26, 151) flanking the way from the arrival to the pit;
--   * round the pit a sandstone kerb and a low balustrade of pearl posts with gold caps, cut-sandstone rails and
--     dark wood fence bays, 1 block outside the rim (x ±74, z -4 and 144), open at the four ladder shafts (N x
--     -12..12, S x -16..16, W/E z 56..84); lanterns on white posts at its corners and openings;
--   * fountains: stepped blue-glass cascades in white basins with gold rims at (±114, 98) (moved from (±104, 70):
--     the walk to the bridge A runs z 52..68) and two smaller ones at (±108, 0), cypresses round them;
--   * the square: gold-barred cage pylons, cypresses in white planters, benches, white-and-gold flower planters,
--     lanterns on white posts, torch pylon rows along both edges of the walks to the bridges A, chests and barrels
--     behind the buyer's stall;
--   * the south tip: a flush pearl-and-gold viewing platform at the end of the axis, a tall torch pylon on each
--     side and a closed pearl-and-gold balustrade along the rim.
-- Noon: at most 14 PointLights (S.lights).
local sq = folder("Square")
local startCount = count
local F = {
	road = folder("GoldenRoad", sq),
	pylons = folder("TorchPylons", sq),
	banners = folder("TribeBanners", sq),
	pit = folder("PitBalustrade", sq),
	lanterns = folder("LanternPosts", sq),
	fountains = folder("Fountains", sq),
	garden = folder("Garden", sq),
	props = folder("Props", sq),
	tip = folder("SouthTip", sq),
}
local COL = {
	white = Color3.fromRGB(252, 252, 248),
	iron = Color3.fromRGB(45, 45, 50),
	fire = Color3.fromRGB(255, 140, 40),
	fireCore = Color3.fromRGB(255, 224, 110),
	fireLight = Color3.fromRGB(255, 180, 100),
	grass = Color3.fromRGB(214, 236, 196), -- a light tint over px_grass_top
	stem = Color3.fromRGB(96, 150, 72),
	chest = Color3.fromRGB(196, 146, 96),
	spray = Color3.fromRGB(225, 240, 255),
}
local S = { lights = 14, skipped = {} } -- the PointLights this part may still add; refused props

-- ================================================================ footprints
-- HARD keep-outs hold for every claimed prop; SOFT ones (the walkway ring round the pit) are skipped by opt.edge
local HARD = {
	{ -78, -8, 78, 148 }, -- the pit, its rim and the balustrade
	{ -44, 156, -24, 180 }, -- the buyer's stall, its crate and barrel
	{ -24, 156, -14, 176 }, -- the customers' side of the counter
	STAIR,
	SIDE_STAIRS[1],
	SIDE_STAIRS[2],
}
for _, w in ipairs(WALKS) do
	table.insert(HARD, w)
end
local SOFT = {
	{ 78, -26, 98, 148 }, -- a 5-block walkway round the pit (east, west, north)
	{ -98, -26, -78, 148 },
	{ -78, -26, 78, -8 },
}
local claims = {}
-- a rect {x0, z0, x1, z1} must lie on the main island (pad 8) in the square zone, off the keep-outs, the arrival
-- (r 20) and everything claimed before; opt.force only records it, opt.quiet does not report a refusal
local function claim(name, x0, z0, x1, z1, opt)
	opt = opt or {}
	if not opt.force then
		local function refuse()
			if not opt.quiet then
				table.insert(S.skipped, name)
			end
			return false
		end
		for _, p in ipairs({
			{ x0, z0 },
			{ x1, z0 },
			{ x0, z1 },
			{ x1, z1 },
			{ (x0 + x1) / 2, (z0 + z1) / 2 },
		}) do
			if isleOf(p[1], p[2], 8) ~= "main" or zoneOf(p[1], p[2]) ~= "square" then
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
		if math.sqrt((nx - SPAWN.x) ^ 2 + (nz - SPAWN.z) ^ 2) < 20 then
			return refuse()
		end
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
-- a block fire of size s standing at local (x, y, z): an orange Neon block, a yellow core and flames; lit while the
-- light budget lasts
local function flame(x, y, z, s, lit, parent)
	local outer = decor(
		part(
			"Fire",
			Vector3.new(s, 0.7 * s, s),
			at(x, y + 0.35 * s, z),
			COL.fire,
			Enum.Material.Neon,
			parent
		)
	)
	decor(
		part(
			"FireCore",
			Vector3.new(0.5 * s, 1.1 * s, 0.5 * s),
			at(x, y + 0.55 * s, z),
			COL.fireCore,
			Enum.Material.Neon,
			parent
		)
	)
	emitter(outer, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(235, 90, 20)),
		LightEmission = 0.9,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.55 * s),
			NumberSequenceKeypoint.new(1, 0.1 * s),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.25),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 12,
		Speed = NumberRange.new(2, 3.5),
		SpreadAngle = Vector2.new(10, 10),
		RotSpeed = NumberRange.new(-40, 40),
		EmissionDirection = Enum.NormalId.Top,
	})
	if lit and S.lights > 0 then
		S.lights -= 1
		light(outer, 34, 1.5, COL.fireLight)
	end
	return outer
end
-- a Minecraft lantern scaled by s standing with its centre at a world pos; lit while the budget lasts
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
	local core = bit("LanternGlow", 0.9, 1, 0.9, 0, 0, 0, LIGHT, Enum.Material.Neon)
	core.Transparency = 0.1
	bit("LanternCap", 0.7, 0.35, 0.7, 0, 0.9, 0, COL.iron)
	if lit and S.lights > 0 then
		S.lights -= 1
		light(core, 32, 1.3, LIGHT)
	end
	return core
end
-- a gold banner with a white sun; cf = the cloth centre, the cloth in the frame's XY plane
local function sunBanner(cf, w, h, parent)
	textured(
		lc(cf, "BannerRod", w + 0.6, 0.4, 0.4, 0, h / 2 + 0.2, 0, nil, nil, parent),
		"px_gold_block",
		GOLD
	)
	textured(lc(cf, "Banner", w, h, 0.2, 0, 0, 0, nil, nil, parent), "px_yellow_wool")
	local sy = h * 0.1
	lc(cf, "BannerSun", w * 0.42, w * 0.42, 0.3, 0, sy, 0, COL.white, Enum.Material.Fabric, parent)
	lc(cf, "BannerRay", w * 0.8, w * 0.14, 0.26, 0, sy, 0, COL.white, Enum.Material.Fabric, parent)
	lc(cf, "BannerRay", w * 0.14, w * 0.8, 0.26, 0, sy, 0, COL.white, Enum.Material.Fabric, parent)
end
-- a lantern on a white post: a pearl block with a gold cap, a white post, a gold top, a standing lantern
local function lanternPost(x, z, lit, parent)
	local f = folder("LanternPost", parent)
	box("PostBase", x - 2, 0, z - 2, x + 2, B, z + 2, "px_white_stone_bricks", PEARL, f)
	box("PostBaseCap", x - 2.2, B, z - 2.2, x + 2.2, B + 0.6, z + 2.2, "px_gold_block", GOLD, f)
	box("Post", x - 1, B + 0.6, z - 1, x + 1, 9.6, z + 1, "px_smooth_stone", PEARL, f)
	box("PostTop", x - 1.4, 9.6, z - 1.4, x + 1.4, 10.2, z + 1.4, "px_gold_block", GOLD, f)
	lamp(V(x, 10.2 + 0.745 * 1.5, z), 1.5, lit, f)
	return f
end
-- a torch pylon nb blocks tall at (x, z): a 2×2 pearl base, a 1×1 white shaft with two teal bands, a gold capital,
-- a pearl cup with a fire; a gold sun banner on the shaft's face toward (dx, dz)
local function pylon(x, z, nb, lit, parent, dx, dz)
	local f = folder("TorchPylon", parent)
	local top = nb * B - B -- the shaft's top; the capital, the cup and the fire above it
	box("PylonBase", x - 4, 0, z - 4, x + 4, B, z + 4, "px_white_stone_bricks", PEARL, f)
	box("PylonBaseCap", x - 4.2, B, z - 4.2, x + 4.2, B + 0.6, z + 4.2, "px_gold_block", GOLD, f)
	box("PylonShaft", x - 2, B + 0.6, z - 2, x + 2, top, z + 2, "px_smooth_stone", PEARL, f)
	decor(
		box(
			"PylonBand",
			x - 2.3,
			B + 0.6,
			z - 2.3,
			x + 2.3,
			B + 2.2,
			z + 2.3,
			"px_prismarine",
			JASPER,
			f
		)
	)
	decor(
		box(
			"PylonBand",
			x - 2.3,
			top - 2.2,
			z - 2.3,
			x + 2.3,
			top - 0.6,
			z + 2.3,
			"px_prismarine",
			JASPER,
			f
		)
	)
	box("PylonCapital", x - 3, top, z - 3, x + 3, top + 2, z + 3, "px_gold_block", GOLD, f)
	box("PylonCup", x - 2, top + 2, z - 2, x + 2, top + 3, z + 2, "px_smooth_stone", CALCITE, f)
	flame(x, top + 3, z, 2.6, lit, f)
	if dx then
		local lo, hi = B + 2.2, top - 2.2
		local bh = hi - lo - 3
		if bh >= 3 then
			sunBanner(fr(x, z, dx, dz) * CFrame.new(0, (lo + hi) / 2 - 0.4, -2.25), 2.6, bh, f)
		end
	end
	return f
end
-- a white brazier: 2×2 pearl blocks, a gold band and rim, coals and a big fire
local function brazier(x, z, parent)
	local f = folder("Brazier", parent)
	box("BrazierBlock", x - 4, 0, z - 4, x + 4, 2 * B, z + 4, "px_smooth_stone", PEARL, f)
	decor(
		box(
			"BrazierBand",
			x - 4.2,
			B - 0.4,
			z - 4.2,
			x + 4.2,
			B + 0.4,
			z + 4.2,
			"px_gold_block",
			GOLD,
			f
		)
	)
	box(
		"BrazierRim",
		x - 4.3,
		2 * B,
		z - 4.3,
		x + 4.3,
		2 * B + 0.6,
		z + 4.3,
		"px_gold_block",
		GOLD,
		f
	)
	box("BrazierCoal", x - 3, 2 * B + 0.6, z - 3, x + 3, 2 * B + 1, z + 3, "px_coal_block", nil, f)
	flame(x, 2 * B + 1, z, 4.6, false, f)
	return f
end
-- the twelve tribes' glyphs: white rects {x, y, w, h} in studs on a 4×10 cloth (centre 0, 0)
local GLYPHS = {
	{ { 0, 1.5, 1.6, 1.6 }, { 0, 1.5, 3, 0.5 }, { 0, 1.5, 0.5, 3 } }, -- a sun
	{ { 0, 1.2, 0.6, 3.6 }, { 0, 2, 2.4, 0.6 } }, -- a cross
	{ { 0, 1.5, 1.2, 1.2 }, { 0, 1.5, 2.6, 0.4 }, { 0, 1.5, 0.4, 2.6 } }, -- a star
	{ { 0, 0.4, 0.5, 2 }, { 0, 2, 2.4, 1.4 }, { 0, 3, 1.2, 0.8 } }, -- a tree
	{ { 0, 2.4, 2.8, 0.6 }, { 0, 1.2, 2.8, 0.6 }, { 0, 0, 2.8, 0.6 } }, -- three bars
	{ { -0.6, 1.5, 0.6, 2.6 }, { 0.2, 2.6, 1.2, 0.5 }, { 0.2, 0.4, 1.2, 0.5 } }, -- a crescent
	{ { -0.9, 2, 0.6, 1.4 }, { 0.9, 2, 0.6, 1.4 }, { 0, 1, 1.2, 0.6 } }, -- a chevron
	{ { 0, 1, 1.6, 2.4 }, { -0.6, 2.5, 0.5, 0.6 }, { 0.6, 2.5, 0.5, 0.6 } }, -- a tower
	{ { 0, 2.6, 2, 0.5 }, { 0, 0.4, 2, 0.5 }, { -0.9, 1.5, 0.5, 2.2 }, { 0.9, 1.5, 0.5, 2.2 } }, -- a ring
	{ { -0.9, 0.8, 0.8, 0.8 }, { 0, 1.6, 0.8, 0.8 }, { 0.9, 2.4, 0.8, 0.8 } }, -- steps
	{ { 0, 2.4, 1.4, 1.4 }, { 0, 0.8, 0.5, 2 }, { 0.5, 0.2, 0.6, 0.4 } }, -- a key
	{ { 0, 1.2, 0.4, 3 }, { 0, 2.8, 1.4, 0.6 }, { 0, 3.3, 0.6, 0.5 } }, -- a spear
}
-- a tribe banner (kit banner) on a gold pole with a gold finial at (x, z), the cloth toward +x (face 1) or -x (-1),
-- the pole top at H; the glyph and a stripe in white wool
local function tribeBanner(x, z, face, H, color, glyph, parent)
	local f = folder("TribeBanner", parent)
	box("BannerBase", x - 2, 0, z - 2, x + 2, B, z + 2, "px_white_stone_bricks", PEARL, f)
	box("BannerBaseCap", x - 2.2, B, z - 2.2, x + 2.2, B + 0.6, z + 2.2, "px_gold_block", GOLD, f)
	box("BannerStaff", x - 0.5, B + 0.6, z - 0.5, x + 0.5, H, z + 0.5, "px_gold_block", GOLD, f)
	box("BannerFinial", x - 0.9, H, z - 0.9, x + 0.9, H + 1.8, z + 0.9, "px_gold_block", GOLD, f)
	decor(
		box(
			"BannerTip",
			x - 0.4,
			H + 1.8,
			z - 0.4,
			x + 0.4,
			H + 2.8,
			z + 0.4,
			"px_gold_block",
			GOLD,
			f
		)
	)
	local w, h = B, 10
	local cf = at(x + face * 0.8, H - 1.2 - h / 2, z) * CFrame.Angles(0, math.pi / 2, 0)
	textured(banner(cf, color, f, nil, w, h), "px_white_wool", color)
	for _, c in ipairs(f:GetChildren()) do
		if c.Name == "BannerPole" then
			textured(c, "px_gold_block", GOLD)
		end
	end
	for _, r in ipairs(glyph) do
		textured(
			lc(cf, "BannerGlyph", r[3], r[4], 0.3, r[1], r[2], 0, nil, nil, f),
			"px_white_wool",
			COL.white
		)
	end
	textured(
		lc(cf, "BannerStripe", w, 0.6, 0.3, 0, -3.6, 0, nil, nil, f),
		"px_white_wool",
		COL.white
	)
	return f
end
-- a small tribe banner on a gold staff standing on a balustrade post at (x, z), the cloth to the south
local function postBanner(x, z, color, parent)
	local f = folder("PostBanner", parent)
	decor(
		box(
			"BannerStaff",
			x - 0.3,
			B + 0.6,
			z - 0.3,
			x + 0.3,
			13,
			z + 0.3,
			"px_gold_block",
			GOLD,
			f
		)
	)
	decor(
		box("BannerFinial", x - 0.6, 13, z - 0.6, x + 0.6, 14.2, z + 0.6, "px_gold_block", GOLD, f)
	)
	textured(banner(at(x, 10, z + 0.5), color, f, COL.white, 2.6, 4.4), "px_white_wool", color)
	for _, c in ipairs(f:GetChildren()) do
		if c.Name == "BannerPole" then
			textured(c, "px_gold_block", GOLD)
		end
	end
	return f
end
-- a gold-barred cage pylon: a pearl base, four gold bars round a hanging lantern, a pearl canopy with a teal band,
-- a gold cap with a fire
local function cagePylon(x, z, parent)
	if not claim("CagePylon", x - 4.3, z - 4.3, x + 4.3, z + 4.3) then
		return
	end
	local f = folder("CagePylon", parent)
	box("CageBase", x - 4, 0, z - 4, x + 4, B, z + 4, "px_white_stone_bricks", PEARL, f)
	box("CageBaseCap", x - 4.2, B, z - 4.2, x + 4.2, B + 0.6, z + 4.2, "px_gold_block", GOLD, f)
	box("CagePlinth", x - 2, B + 0.6, z - 2, x + 2, B + 1.6, z + 2, "px_smooth_stone", CALCITE, f)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local bx, bz = x + c[1] * 3.2, z + c[2] * 3.2
		box(
			"CageBar",
			bx - 0.6,
			B + 0.6,
			bz - 0.6,
			bx + 0.6,
			16.6,
			bz + 0.6,
			"px_gold_block",
			GOLD,
			f
		)
	end
	box("CageCanopy", x - 4, 16.6, z - 4, x + 4, 18.6, z + 4, "px_smooth_stone", PEARL, f)
	decor(
		box("CageBand", x - 4.2, 17.1, z - 4.2, x + 4.2, 18.1, z + 4.2, "px_prismarine", JASPER, f)
	)
	box("CageCap", x - 3, 18.6, z - 3, x + 3, 20.6, z + 3, "px_gold_block", GOLD, f)
	box("CageCup", x - 2, 20.6, z - 2, x + 2, 21.6, z + 2, "px_smooth_stone", CALCITE, f)
	flame(x, 21.6, z, 2.4, false, f)
	local s, ly = 1.6, 11.5
	lamp(V(x, ly, z), s, false, f)
	local top = ly + 1.07 * s
	decor(
		part(
			"Chain",
			Vector3.new(0.3, 16.6 - top, 0.3),
			at(x, (16.6 + top) / 2, z),
			COL.iron,
			Enum.Material.Metal,
			f
		)
	)
end
-- a cypress w blocks wide (2 or 3): a white planter with a gold rim, a dark log trunk, a stepped hedge column
local function cypress(x, z, w, tall, parent)
	local half = w * B / 2
	if not claim("Cypress", x - half - 0.2, z - half - 0.2, x + half + 0.2, z + half + 0.2) then
		return
	end
	local f = folder("Cypress", parent)
	box("Planter", x - half, 0, z - half, x + half, B, z + half, "px_white_stone_bricks", PEARL, f)
	box(
		"PlanterRim",
		x - half - 0.2,
		B,
		z - half - 0.2,
		x + half + 0.2,
		B + 0.6,
		z + half + 0.2,
		"px_gold_block",
		GOLD,
		f
	)
	box("Trunk", x - 2, B + 0.6, z - 2, x + 2, B + 3.6, z + 2, "px_dark_oak_log", nil, f)
	local y = B + 3.6
	local layers = if w >= 3
		then { { 3, 16 }, { 2, if tall then 12 else 8 }, { 1, 4 } }
		else { { 2, if tall then 20 else 16 }, { 1, 6 } }
	for _, l in ipairs(layers) do
		local hw = l[1] * B / 2
		box("Cypress", x - hw, y, z - hw, x + hw, y + l[2], z + hw, "px_hedge", CYPRESS, f)
		y += l[2]
	end
end
-- a bench of pearl ends, a cut-sandstone seat and a gold back, looking along (dx, dz)
local function bench(cx, cz, dx, dz, parent)
	local ex, ez = if dx ~= 0 then 1.6 else 6, if dx ~= 0 then 6 else 1.6
	if not claim("Bench", cx - ex, cz - ez, cx + ex, cz + ez) then
		return
	end
	local f = folder("Bench", parent)
	local cf = fr(cx, cz, dx, dz)
	for _, s in ipairs({ -1, 1 }) do
		lb(
			cf,
			"BenchEnd",
			math.min(s * 4, s * 6),
			0,
			-1.6,
			math.max(s * 4, s * 6),
			3.2,
			1.6,
			"px_white_stone_bricks",
			PEARL,
			f
		)
	end
	lb(cf, "BenchSeat", -4, 1.6, -1.4, 4, 2.4, 1.4, "px_cut_sandstone", SAND, f)
	lb(cf, "BenchBack", -4, 2.4, 0.8, 4, 4.6, 1.4, "px_gold_block", GOLD, f)
end
-- a white planter (2×1 blocks) with a gold lip and white and yellow flowers
local function flowerPlanter(cx, cz, alongX, parent)
	local ex, ez = if alongX then 4 else 2, if alongX then 2 else 4
	local x0, z0, x1, z1 = cx - ex, cz - ez, cx + ex, cz + ez
	if not claim("FlowerPlanter", x0, z0, x1, z1) then
		return
	end
	local f = folder("FlowerPlanter", parent)
	box("Planter", x0, 0, z0, x1, 3, z1, "px_white_stone_bricks", PEARL, f)
	box("PlanterLip", x0 - 0.3, 3, z0 - 0.3, x1 + 0.3, 3.4, z1 + 0.3, "px_gold_block", GOLD, f)
	box(
		"PlanterSoil",
		x0 + 0.6,
		3.4,
		z0 + 0.6,
		x1 - 0.6,
		3.6,
		z1 - 0.6,
		"px_grass_top",
		COL.grass,
		f
	)
	for i = 0, 3 do
		local t = -3 + i * 2
		local o = if i % 2 == 0 then -0.7 else 0.7
		local fx, fz = if alongX then cx + t else cx + o, if alongX then cz + o else cz + t
		local h = 1.4
		decor(
			part(
				"FlowerStem",
				Vector3.new(0.3, h, 0.3),
				at(fx, 3.6 + h / 2, fz),
				COL.stem,
				Enum.Material.SmoothPlastic,
				f
			)
		)
		textured(
			decor(part("Flower", Vector3.new(1, 1, 1), at(fx, 4.1 + h, fz), nil, nil, f)),
			if i % 2 == 0 then "px_white_wool" else "px_yellow_wool",
			if i % 2 == 0 then COL.white else nil
		)
	end
end
-- a chest on the ground at (x, z), its latch looking along (dx, dz)
local function chest(x, z, dx, dz, parent)
	if not claim("Chest", x - 2, z - 2, x + 2, z + 2) then
		return
	end
	local cf = fr(x, z, dx, dz)
	lb(cf, "Chest", -1.8, 0, -1.8, 1.8, 2.6, 1.8, "px_spruce_planks", COL.chest, parent)
	lb(cf, "ChestLid", -1.8, 2.6, -1.8, 1.8, 3.6, 1.8, "px_dark_oak_planks", nil, parent)
	textured(
		lc(cf, "ChestLatch", 0.7, 1, 0.3, 0, 2.6, -1.95, nil, nil, parent),
		"px_gold_block",
		GOLD
	)
end
-- a fountain at (cx, cz): a white basin (outer half-size `half`, walls 1 block) with gold rims and blue glass water
-- 1 block deep, a stepped cascade of tiers { {size, top}, ... } with water pools and glass curtains, a gold spout
local function fountain(cx, cz, half, tiers, parent)
	if
		not claim("Fountain", cx - half - 0.2, cz - half - 0.2, cx + half + 0.2, cz + half + 0.2)
	then
		return false
	end
	local f = folder("Fountain", parent)
	local x0, z0, x1, z1 = cx - half, cz - half, cx + half, cz + half
	local function glass(name, size, cf)
		local p = decor(part(name, size, cf, WATER, Enum.Material.Glass, f))
		p.Transparency = 0.35
		return p
	end
	for _, r in ipairs({
		{ x0, z0, x1, z0 + B },
		{ x0, z1 - B, x1, z1 },
		{ x0, z0 + B, x0 + B, z1 - B },
		{ x1 - B, z0 + B, x1, z1 - B },
	}) do
		box("BasinWall", r[1], 0, r[2], r[3], B, r[4], "px_white_stone_bricks", PEARL, f)
	end
	for _, r in ipairs({
		{ x0 - 0.2, z0 - 0.2, x1 + 0.2, z0 + B },
		{ x0 - 0.2, z1 - B, x1 + 0.2, z1 + 0.2 },
		{ x0 - 0.2, z0 + B, x0 + B, z1 - B },
		{ x1 - B, z0 + B, x1 + 0.2, z1 - B },
	}) do
		box("BasinRim", r[1], B, r[2], r[3], B + 0.6, r[4], "px_gold_block", GOLD, f)
	end
	local inner = 2 * (half - B)
	box("BasinFloor", x0 + B, 0, z0 + B, x1 - B, 0.2, z1 - B, "px_smooth_stone", CALCITE, f)
	glass("BasinWater", Vector3.new(inner, 3.2, inner), at(cx, 1.8, cz))
	local below = 3.4
	for _, t in ipairs(tiers) do
		local size, top = t[1], t[2]
		local h = size / 2
		box(
			"CascadeTier",
			cx - h,
			0,
			cz - h,
			cx + h,
			top - 0.6,
			cz + h,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		box(
			"CascadeRim",
			cx - h - 0.2,
			top - 0.6,
			cz - h - 0.2,
			cx + h + 0.2,
			top,
			cz + h + 0.2,
			"px_gold_block",
			GOLD,
			f
		)
		glass("CascadePool", Vector3.new(size - 1.2, 0.4, size - 1.2), at(cx, top + 0.2, cz))
		local fall = top + 0.4 - below
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local o = h + 0.45
			local sz = if d[1] ~= 0
				then Vector3.new(0.5, fall, size - 1.6)
				else Vector3.new(size - 1.6, fall, 0.5)
			glass("Cascade", sz, at(cx + d[1] * o, below + fall / 2, cz + d[2] * o))
		end
		below = top + 0.4
	end
	local top = tiers[#tiers][2]
	box(
		"FountainSpout",
		cx - 0.8,
		top,
		cz - 0.8,
		cx + 0.8,
		top + 1.6,
		cz + 0.8,
		"px_gold_block",
		GOLD,
		f
	)
	local jet = glass("FountainJet", Vector3.new(1.2, 3, 1.2), at(cx, top + 3.1, cz))
	emitter(jet, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(COL.spray),
		LightEmission = 0.3,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 0.15),
		}),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(0.7, 1),
		Rate = 18,
		Speed = NumberRange.new(7, 9),
		SpreadAngle = Vector2.new(18, 18),
		Acceleration = Vector3.new(0, -26, 0),
		EmissionDirection = Enum.NormalId.Top,
	})
	return true
end
-- the z of the south rim at column x (pad from the ragged edge), nil if there is no island there
local function rimZ(x, pad)
	for z = 214, 140, -1 do
		if isleOf(x - 2, z, pad) == "main" and isleOf(x + 2, z, pad) == "main" then
			return z
		end
	end
	return nil
end

-- ================================================================ 1. the golden road and the south axis: gold under yellow glass
do
	local f = F.road
	local function tile(x0, z0, gold)
		if gold then
			box("RoadGold", x0, 0, z0, x0 + B, 0.15, z0 + B, "px_gold_block", GOLD, f)
		end
		local g = part(
			"RoadGlass",
			Vector3.new(B - 0.2, 0.2, B - 0.2),
			at(x0 + B / 2, 0.25, z0 + B / 2),
			GOLD_GLASS,
			Enum.Material.Glass,
			f
		)
		g.Transparency = 0.35
		return g
	end
	box("RoadGold", ROAD[1], 0, ROAD[2], ROAD[3], 0.15, ROAD[4], "px_gold_block", GOLD, f)
	for x0 = ROAD[1], ROAD[3] - B, B do
		for z0 = ROAD[2], ROAD[4] - B, B do
			tile(x0, z0, false)
		end
	end
	-- the south axis: tile by tile, leaving 8 studs round the arrival pad
	for x0 = -12, 8, B do
		for z0 = 142, 170, B do
			local nx, nz = math.clamp(SPAWN.x, x0, x0 + B), math.clamp(SPAWN.z, z0, z0 + B)
			if math.sqrt((nx - SPAWN.x) ^ 2 + (nz - SPAWN.z) ^ 2) >= 8 then
				tile(x0, z0, true)
			end
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		box("RoadKerb", s * 12, 0, ROAD[2], s * 16, 0.3, -6, "px_smooth_stone", PEARL, f)
		box("AxisKerb", s * 12, 0, 142, s * 16, 0.3, 174, "px_smooth_stone", PEARL, f)
	end
end
task.wait()

-- ================================================================ 2. the torch pylons and the tribe banners along the road, the braziers
do
	-- forced perspective: the pylons shrink toward the gate
	local heights = { 7, 7, 6, 6, 5 }
	for i, nb in ipairs(heights) do
		local z = -12 - (i - 1) * 12
		for _, s in ipairs({ -1, 1 }) do
			local x = s * 18
			claim("RoadPylon", x - 4.2, z - 4.2, x + 4.2, z + 4.2, { force = true })
			pylon(x, z, nb, i == 1 or i == 3, F.pylons, -s, 0)
		end
	end
	-- the twelve tribes in a row behind the pylons, west 1..6 and east 7..12 from the pit toward the gate
	for k = 1, 6 do
		local z = -14 - (k - 1) * 9.4
		local H = 26 - (k - 1) * 0.8
		for _, s in ipairs({ -1, 1 }) do
			local x = s * 27
			local t = if s < 0 then k else k + 6
			claim("TribeBanner", x - 2.2, z - 2.2, x + 2.2, z + 2.2, { force = true })
			tribeBanner(x, z, -s, H, TRIBES[t], GLYPHS[t], F.banners)
		end
	end
	-- two white braziers flanking the way from the arrival to the pit
	for _, s in ipairs({ -1, 1 }) do
		claim("Brazier", s * 26 - 4.3, 146.7, s * 26 + 4.3, 155.3, { force = true })
		brazier(s * 26, 151, F.pylons)
	end
end
task.wait()

-- ================================================================ 3. the balustrade round the pit, its lantern posts, the small banners
do
	local f = F.pit
	local lamps = {} -- lantern posts: "x,z" -> lit
	for _, s in ipairs({ -1, 1 }) do
		lamps[(s * 74) .. ",-4"] = false
		lamps[(s * 74) .. ",144"] = false
		lamps[(s * 14) .. ",-4"] = true
		lamps[(s * 18) .. ",144"] = true
		lamps[(s * 74) .. ",54"] = true
		lamps[(s * 74) .. ",86"] = true
	end
	local built = {}
	local function node(x, z)
		local key = x .. "," .. z
		if built[key] then
			return
		end
		built[key] = true
		if lamps[key] ~= nil then
			lanternPost(x, z, lamps[key], F.lanterns)
		else
			box("BalustradePost", x - 2, 0, z - 2, x + 2, B, z + 2, "px_smooth_stone", PEARL, f)
			box(
				"BalustradeCap",
				x - 2.3,
				B,
				z - 2.3,
				x + 2.3,
				B + 0.6,
				z + 2.3,
				"px_gold_block",
				GOLD,
				f
			)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		-- each run from its corner inward, so the bays mirror; r[5] = the south run with the small banners
		for _, r in ipairs({
			{ s * 74, -4, s * 14, -4, false }, -- north, open x -12..12 (the ladder and the road)
			{ s * 74, 144, s * 18, 144, true }, -- south, open x -16..16 (widened for the arrival)
			{ s * 74, -4, s * 74, 54, false }, -- west / east, open z 56..84
			{ s * 74, 144, s * 74, 86, false },
		}) do
			local alongX = r[2] == r[4]
			local a, b = if alongX then r[1] else r[2], if alongX then r[3] else r[4]
			local c = if alongX then r[2] else r[1]
			local function span(name, lo, hi, y0, y1, half, variant, tint)
				if alongX then
					return box(name, lo, y0, c - half, hi, y1, c + half, variant, tint, f)
				end
				return box(name, c - half, y0, lo, c + half, y1, hi, variant, tint, f)
			end
			span("BalustradeKerb", math.min(a, b), math.max(a, b), 0, 1, 1.2, "px_sandstone", SAND)
			local n = math.max(1, math.floor(math.abs(b - a) / 8 + 0.5))
			local prev = nil
			for i = 0, n do
				local t = a + (b - a) * i / n
				if alongX then
					node(t, c)
				else
					node(c, t)
				end
				if r[5] and i > 0 and i < n then
					postBanner(t, c, TRIBES[if s < 0 then i else i + 6], f)
				end
				if prev then
					local lo, hi = math.min(prev, t) + 2, math.max(prev, t) - 2
					if i % 3 == 2 then
						-- a dark wood fence bay (like the concept's fences by the pit)
						span("FenceRail", lo, hi, 1.6, 2.2, 0.25, "px_dark_oak_planks")
						span("FenceRail", lo, hi, 2.8, 3.4, 0.25, "px_dark_oak_planks")
						local m = (lo + hi) / 2
						span("FencePost", m - 0.5, m + 0.5, 1, 3.8, 0.5, "px_dark_oak_planks")
					else
						span("BalustradeRail", lo, hi, 3, 3.8, 0.8, "px_cut_sandstone", SAND)
						local gap = hi - lo
						local nb = math.max(1, math.floor(gap / 2))
						for j = 1, nb do
							local m = lo + gap * (j - 0.5) / nb
							decor(
								span(
									"Baluster",
									m - 0.5,
									m + 0.5,
									1,
									3,
									0.5,
									"px_smooth_stone",
									PEARL
								)
							)
						end
					end
				end
				prev = t
			end
		end
	end
end
task.wait()

-- ================================================================ 4. the south tip: the viewing platform, its pylons, the rim balustrade
do
	local f = F.tip
	local cols, ends = {}, {}
	for k = 0, 22 do
		local zr = rimZ(-44 + 4 * k, 4)
		cols[k] = if zr then math.floor(zr) else nil
	end
	for k = 0, 22 do
		local cx, zb = -44 + 4 * k, cols[k]
		if zb and zb > 178 then
			-- stepped along the ragged rim; never nearer than z 180 (the stall, the pylons, the arrival)
			local zlo = zb - B
			for _, j in ipairs({ k - 1, k + 1 }) do
				if cols[j] and cols[j] > 178 then
					zlo = math.min(zlo, cols[j] - B)
				end
			end
			zlo = math.max(zlo, zb - 2 * B, math.min(180, zb - 2))
			ends[k] = zlo
			claim("RimBalustrade", cx - 2, zlo, cx + 2, zb, { force = true })
			box("RimKerb", cx - 2, 0, zlo, cx + 2, 1.2, zb, "px_smooth_stone", PEARL, f)
			box("RimRail", cx - 2, 3, zlo + 0.6, cx + 2, 3.8, zb - 0.6, "px_gold_block", GOLD, f)
			for z = zlo + 2, zb - 1, B do
				for _, o in ipairs({ -1, 1 }) do
					decor(
						box(
							"RimBaluster",
							cx + o - 0.5,
							1.2,
							z - 0.5,
							cx + o + 0.5,
							3,
							z + 0.5,
							"px_gold_block",
							GOLD,
							f
						)
					)
				end
			end
			local ax = math.abs(cx)
			if ax == 0 or ax == 12 or ax == 24 or ax == 36 or ax == 44 then
				box("RimPost", cx - 2, 0, zlo, cx + 2, 6, zb, "px_smooth_stone", PEARL, f)
				box(
					"RimPostCap",
					cx - 2.3,
					6,
					zlo - 0.3,
					cx + 2.3,
					6.6,
					zb + 0.3,
					"px_gold_block",
					GOLD,
					f
				)
				decor(
					box(
						"RimPostSun",
						cx - 1,
						6.6,
						(zlo + zb) / 2 - 1,
						cx + 1,
						8.6,
						(zlo + zb) / 2 + 1,
						"px_gold_block",
						GOLD,
						f
					)
				)
			end
		end
	end
	-- the flush platform x -22..22 from the end of the glass road to the balustrade: pearl and calcite, gold edges
	local far = 174
	for k = 6, 16 do
		local cx = -44 + 4 * k
		local zEnd = ends[k] or (cols[k] and cols[k] - B)
		if zEnd and zEnd > 175 then
			far = math.max(far, zEnd)
			local edge = math.abs(cx) == 20
			box(
				"TipFloor",
				cx - 2,
				0,
				174,
				cx + 2,
				0.35,
				zEnd,
				if edge then "px_gold_block" else "px_smooth_stone",
				if edge then GOLD elseif k % 2 == 0 then PEARL else CALCITE,
				f
			)
		end
	end
	box("TipFloorEdge", -18, 0.35, 174, 18, 0.45, 175, "px_gold_block", GOLD, f)
	local mz = (174 + far) / 2
	decor(box("TipSun", -2, 0.35, mz - 2, 2, 0.45, mz + 2, "px_gold_block", GOLD, f))
	decor(box("TipSunRay", -6, 0.35, mz - 0.6, 6, 0.42, mz + 0.6, "px_gold_block", GOLD, f))
	decor(box("TipSunRay", -0.6, 0.35, mz - 3.4, 0.6, 0.42, mz + 3.4, "px_gold_block", GOLD, f))
	-- a tall torch pylon on each side, as far south as the island allows
	local zp = 176
	while
		zp > 166 and not (isleOf(24, zp + 4.2, 8) == "main" and isleOf(32, zp + 4.2, 8) == "main")
	do
		zp -= 2
	end
	for _, s in ipairs({ -1, 1 }) do
		claim("TipPylon", s * 28 - 4.2, zp - 4.2, s * 28 + 4.2, zp + 4.2, { force = true })
		pylon(s * 28, zp, 9, true, F.pylons, -s, 0)
	end
end
task.wait()

-- ================================================================ 5. the fountains east and west of the pit
do
	for _, s in ipairs({ -1, 1 }) do
		fountain(s * 114, 98, 12, { { 12, 6 }, { 8, 10 }, { 4, 14 } }, F.fountains)
		fountain(s * 108, 0, 10, { { 8, 5.5 }, { 4, 9.5 } }, F.fountains)
	end
end
task.wait()

-- ================================================================ 6. the square: walk pylons, cage pylons, cypresses, benches, planters, lanterns
do
	local G = F.garden
	-- (east-side spots; each is built at x and -x)
	-- torch pylons along both edges of the walks to the bridges A, their banners toward the walk
	for _, px in ipairs({ 104, 124, 144 }) do
		for _, pz in ipairs({ 46, 74 }) do
			for _, s in ipairs({ -1, 1 }) do
				local x = s * px
				if claim("WalkPylon", x - 4.3, pz - 4.3, x + 4.3, pz + 4.3) then
					pylon(x, pz, 5, false, F.pylons, 0, if pz < 60 then 1 else -1)
				end
			end
		end
	end
	for _, p in ipairs({ { 56, -40 }, { 100, -40 }, { 146, 24 }, { 126, 136 }, { 60, 160 } }) do
		for _, s in ipairs({ -1, 1 }) do
			cagePylon(s * p[1], p[2], G)
		end
	end
	for _, p in ipairs({
		{ 78, -40, 2 },
		{ 122, -40, 2 },
		{ 56, -58, 2 },
		{ 100, -58, 2 },
		{ 130, 0, 3 }, -- round the small fountains
		{ 108, -22, 2 },
		{ 108, 22, 2 },
		{ 138, 92, 2 }, -- round the big fountains
		{ 138, 108, 2 },
		{ 114, 122, 3 },
		{ 88, 156, 2 }, -- south of the pit
		{ 44, 172, 2 },
	}) do
		local tall = rng:NextNumber() < 0.5
		for _, s in ipairs({ -1, 1 }) do
			cypress(s * p[1], p[2], p[3], tall, G)
		end
	end
	for _, b in ipairs({
		{ 36, -32, -1, 0 },
		{ 36, -52, -1, 0 },
		{ 114, 82, 0, 1 },
		{ 36, 160, -1, 0 },
	}) do
		for _, s in ipairs({ -1, 1 }) do
			bench(s * b[1], b[2], s * b[3], b[4], G)
		end
	end
	for _, p in ipairs({
		{ 36, -42, false },
		{ 78, -58, true },
		{ 122, -58, true },
		{ 60, 176, true },
	}) do
		for _, s in ipairs({ -1, 1 }) do
			flowerPlanter(s * p[1], p[2], p[3], G)
		end
	end
	for _, p in ipairs({ { 66, -30 }, { 130, 34 }, { 76, 168 }, { 142, 118 } }) do
		for _, s in ipairs({ -1, 1 }) do
			local x = s * p[1]
			if claim("LanternPost", x - 2.2, p[2] - 2.2, x + 2.2, p[2] + 2.2) then
				lanternPost(x, p[2], false, F.lanterns)
			end
		end
	end
end
task.wait()

-- ================================================================ 7. chests and barrels behind the buyer's stall (the only asymmetry)
do
	local f = F.props
	chest(-48, 160, 1, 0, f)
	chest(-48, 165, 1, 0, f)
	if claim("Barrel", -50, 168, -46, 172) then
		barrel(-48, 0, 170, f, "px_gold_block")
	end
	if claim("Barrel", -55, 158, -51, 162) then
		barrel(-53, 0, 160, f, "px_sandstone")
	end
	if claim("Crate", -55, 164, -51, 168) then
		crate(-53, 0, 166, f)
	end
end

print(
	("[build-gate] square: %d parts, %d lights%s"):format(
		count - startCount,
		14 - S.lights,
		if #S.skipped > 0 then ", skipped " .. table.concat(S.skipped, " ") else ""
	)
)
