--!nocheck
-- ================================================================ cherubim: the plaza round the pit, the south edge, the causeway
-- The PLAZA part (zoneOf == "plaza": the main island outside the rotunda zone x -100..100, z < -56), after the concept
-- (assets/concepts/cherubim/concept-v2.webp, top-right and the small panels):
--   * a balustrade of quartz posts with gold caps, gold rails and balusters round the pit 1 block outside the rim
--     (x ±74, z -14 and 134), open at the four ladder shafts (N x -12..12 = the walk to the rotunda, S x -16..16
--     widened for the arrival, W/E z 48..72); gold lantern posts (dark wood, a gold arm, a gold banner with a white
--     sun) at its corners and beside each opening;
--   * eight trumpet angels on tall quartz plinths: (±24, 141) flanking the way from the arrival to the pit, (±104, 20)
--     and (±104, 100) on the east and west sides, (±48, -41) flanking the north walk;
--   * four harps of gold and quartz with iron-bar strings and a hanging lantern (±124, 32) and (±124, 88); golden
--     halos on quartz posts with end rods (±100, 42), (±100, 78), (±86, -44) and a big halo monument at (124, 60);
--     a quartz-and-gold fountain at (-124, 60) on the west axis; quartz benches, gold planters with white flowers;
--   * two small gold-domed pavilions in the north-west and north-east corners (±128, -84);
--   * gold lantern posts along the edges of the walks (±100, -32), (±124, -8), (±148, -32), (±18, -44);
--   * chests and gold blocks behind the buyer's stall, gold blocks scattered over the free plaza;
--   * the south edge: a stepped quartz-and-gold balustrade with gaps along the rim (|x| ≤ 58, open at the causeway),
--     and the golden stair-causeway x -10..10 down 2 blocks from the rim to a landing hanging over the void with an
--     arch and two lanterns (kept inside the edge walls, z ≤ 206).
-- Kept clear: the pit, its rim and the openings, the arrival r 20, the buyer's stall with its crate and barrel, the
-- zone sign, the WALKS and the bridge heads, the rotunda zone, a 5-block ring round the pit and the necks south-east /
-- south-west of it.
local plazaF = folder("Plaza")
local startCount = count
local F = {
	pit = folder("PitBalustrade", plazaF),
	lanterns = folder("LanternPosts", plazaF),
	statues = folder("TrumpetAngels", plazaF),
	harps = folder("Harps", plazaF),
	halos = folder("Halos", plazaF),
	garden = folder("Garden", plazaF),
	pavilions = folder("Pavilions", plazaF),
	props = folder("Props", plazaF),
	south = folder("SouthEdge", plazaF),
	causeway = folder("Causeway", plazaF),
}
local COL = {
	iron = Color3.fromRGB(45, 45, 50),
	ironCap = Color3.fromRGB(40, 40, 45),
	bars = Color3.fromRGB(172, 172, 180),
	white = Color3.fromRGB(250, 250, 246),
	stem = Color3.fromRGB(96, 150, 72),
	grass = Color3.fromRGB(214, 236, 196), -- a light tint over px_grass_top
	chest = Color3.fromRGB(196, 146, 96),
	water = Color3.fromRGB(212, 232, 255),
	stream = Color3.fromRGB(170, 210, 245),
	rod = Color3.fromRGB(255, 250, 236),
}
local LIGHTS = 22 -- PointLights this part may add
local lightsLeft = LIGHTS
local skipped = {}

-- ================================================================ footprints
-- HARD keep-outs hold for everything; SOFT ones (walkways round the pit, the necks) are ignored by the rim balustrade
local HARD = {
	{ 20, 146, 41, 170 }, -- the buyer's stall with the customers' side, its crate and barrel
	{ -20, 155, -8, 165 }, -- the zone sign
	{ -76, -16, 76, 136 }, -- the pit, its rim and the balustrade
}
for _, w in ipairs(WALKS) do
	table.insert(HARD, w)
end
local SOFT = {
	{ 76, -12, 96, 136 }, -- a 5-block walkway round the pit (east, west, north)
	{ -96, -12, -76, 136 },
	{ -76, -36, 76, -16 },
	{ 96, 46, 118, 74 }, -- the axes to the side openings
	{ -118, 46, -96, 74 },
	{ 50, 136, 110, 180 }, -- the narrow necks between the pit and the rim, south-east and south-west
	{ -110, 136, -50, 180 },
}
local claims = {}
-- a rect {x0, z0, x1, z1} must lie on the main island (pad 10) in the plaza zone, off the keep-outs, the arrival
-- (r 20) and everything claimed before; opt.edge skips SOFT, opt.quiet does not report a refusal
local function claim(name, x0, z0, x1, z1, opt)
	opt = opt or {}
	local function refuse()
		if not opt.quiet then
			table.insert(skipped, name)
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
		if isleOf(p[1], p[2], 10) ~= "main" or zoneOf(p[1], p[2]) ~= "plaza" then
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
-- a Minecraft lantern scaled by s at a world pos, on a chain up to hangTop (world y); lit while the budget lasts
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
	if lit and lightsLeft > 0 then
		lightsLeft -= 1
		light(core, 32, 1.3, LIGHT)
	end
	return core
end
-- a gold banner with a white sun; cf = the cloth centre, the cloth in the frame's XY plane
local function sunBanner(cf, w, h, parent)
	lc(
		cf,
		"BannerRod",
		w + 0.6,
		0.4,
		0.4,
		0,
		h / 2 + 0.2,
		0,
		GOLD_DEEP,
		Enum.Material.Metal,
		parent
	)
	textured(lc(cf, "Banner", w, h, 0.2, 0, 0, 0, nil, nil, parent), "px_yellow_wool")
	local sy = h * 0.1
	lc(cf, "BannerSun", w * 0.42, w * 0.42, 0.3, 0, sy, 0, COL.white, Enum.Material.Fabric, parent)
	lc(cf, "BannerRay", w * 0.8, w * 0.14, 0.26, 0, sy, 0, COL.white, Enum.Material.Fabric, parent)
	lc(cf, "BannerRay", w * 0.14, w * 0.8, 0.26, 0, sy, 0, COL.white, Enum.Material.Fabric, parent)
	lc(cf, "BannerHem", w, 0.4, 0.26, 0, -h / 2 + 0.2, 0, COL.white, Enum.Material.Fabric, parent)
end
-- a gold lantern post: a quartz block with a gold cap, a dark wood post, a gold arm toward (dx, dz) with a hanging
-- lantern and a gold sun banner under the arm
local function goldPost(x, z, dx, dz, lit, parent)
	local f = folder("GoldLanternPost", parent)
	local cf = fr(x, z, dx, dz)
	lb(cf, "PostBase", -2, 0, -2, 2, 4, 2, "px_smooth_stone", QUARTZ, f)
	lb(cf, "PostBaseCap", -2.3, 4, -2.3, 2.3, 4.6, 2.3, "px_gold_block", GOLD, f)
	lb(cf, "Post", -0.6, 4.6, -0.6, 0.6, 16, 0.6, "px_dark_oak_log", nil, f)
	decor(lb(cf, "PostTop", -1, 16, -1, 1, 17.4, 1, "px_gold_block", GOLD, f))
	decor(lb(cf, "PostArm", -0.5, 14.6, -5.2, 0.5, 15.6, 0.6, "px_gold_block", GOLD, f))
	sunBanner(cf * CFrame.new(0, 11.2, -2.1) * CFrame.Angles(0, math.pi / 2, 0), 2.4, 6, f)
	local p = (cf * CFrame.new(0, 11.4, -4.4)).Position
	lamp(p, 1.3, lit, f, p.Y + 3.2)
	return f
end
-- a ring of gold (a halo) round (cx, cz) at y: outer half-size R, bar t, the corners stepped in when chamfer; thin
-- Neon end rods up from the corners and down from the middles of the sides
local function ring(cx, cz, y, R, t, chamfer, rodLen, parent)
	local h = 1.6
	local c = if chamfer then t else 0
	local function g(x0, z0, x1, z1)
		decor(
			box("Halo", cx + x0, y, cz + z0, cx + x1, y + h, cz + z1, "px_gold_block", GOLD, parent)
		)
	end
	g(-R + c, -R, R - c, -R + t)
	g(-R + c, R - t, R - c, R)
	g(-R, -R + t, -R + t, R - t)
	g(R - t, -R + t, R, R - t)
	local corner = R - t / 2
	if chamfer then
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local ax, az = sx * (R - t), sz * (R - t)
				g(
					math.min(ax, sx * (R - 2 * t)),
					math.min(az, sz * (R - 2 * t)),
					math.max(ax, sx * (R - 2 * t)),
					math.max(az, sz * (R - 2 * t))
				)
			end
		end
		corner = R - 1.5 * t
	end
	local function rod(x, z, y0)
		decor(
			part(
				"EndRod",
				Vector3.new(0.4, rodLen, 0.4),
				at(cx + x, y0 + rodLen / 2, cz + z),
				COL.rod,
				Enum.Material.Neon,
				parent
			)
		)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			rod(sx * corner, sz * corner, y + h)
		end
		rod(sx * (R - t / 2), 0, y - rodLen)
		rod(0, sx * (R - t / 2), y - rodLen)
	end
end

-- a trumpet angel on a tall quartz plinth at (cx, cz) looking along (dx, dz): a gold robe with a white sash, quartz
-- face and hands, stepped white wings rising outward, a gold halo, a gold trumpet raised to the lips
local function angel(cx, cz, dx, dz, parent)
	if not claim("TrumpetAngel", cx - 4.6, cz - 4.6, cx + 4.6, cz + 4.6) then
		return
	end
	local f = folder("TrumpetAngel", parent)
	local cf = fr(cx, cz, dx, dz)
	lb(cf, "PlinthFoot", -5, 0, -5, 5, 1.2, 5, "px_gold_block", GOLD, f)
	lb(cf, "Plinth", -4, 1.2, -4, 4, 11, 4, "px_smooth_stone", QUARTZ, f)
	decor(lb(cf, "PlinthBand", -4.3, 6, -4.3, 4.3, 6.8, 4.3, "px_gold_block", GOLD, f))
	lb(cf, "PlinthCap", -4.6, 11, -4.6, 4.6, 12, 4.6, "px_gold_block", GOLD_DEEP, f)
	local function g(name, x0, y0, z0, x1, y1, z1, variant, tint)
		return decor(lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, f))
	end
	local function wp(x, y, z)
		return (cf * CFrame.new(x, y, z)).Position
	end
	g("RobeHem", -4, 12, -3, 4, 14, 3, "px_gold_block", GOLD)
	g("Robe", -3.5, 14, -2.5, 3.5, 22, 2.5, "px_gold_block", GOLD)
	g("RobeSash", -1, 12.2, -3.2, 1, 22, -2.4, "px_white_wool", QUARTZ)
	g("Belt", -3.7, 19, -2.7, 3.7, 20, 2.7, "px_smooth_stone", QUARTZ)
	g("Torso", -3, 22, -2, 3, 26, 2, "px_gold_block", GOLD)
	g("Head", -2, 26, -2, 2, 30, 2, "px_smooth_stone", QUARTZ)
	g("Hair", -2.3, 29.4, -2.3, 2.3, 30.8, 2.3, "px_gold_block", GOLD_DEEP)
	g("HairBack", -2.3, 26.6, 1.4, 2.3, 29.4, 2.3, "px_gold_block", GOLD_DEEP)
	for _, s in ipairs({ -1, 1 }) do
		lc(cf, "Eye", 0.6, 0.6, 0.1, s * 0.9, 28.2, -2.05, IRON, Enum.Material.SmoothPlastic, f)
	end
	for _, h in ipairs({
		{ 6, 0.8, 0, -2.6 },
		{ 6, 0.8, 0, 2.6 },
		{ 0.8, 4.4, -2.6, 0 },
		{ 0.8, 4.4, 2.6, 0 },
	}) do
		textured(
			lc(cf, "Halo", h[1], 0.6, h[2], h[3], 32.3, h[4], nil, nil, f),
			"px_gold_block",
			GOLD
		)
	end
	-- the left arm hangs, the right one holds the trumpet up
	g("Sleeve", -4.6, 19.4, -1.5, -3, 25.6, 1.5, "px_gold_block", GOLD)
	g("Hand", -4.4, 18, -1.1, -3.2, 19.4, 1.1, "px_smooth_stone", QUARTZ)
	g("Shoulder", 3, 23.4, -1.5, 4.6, 25.8, 1.5, "px_gold_block", GOLD)
	local mouth, bell = wp(0.6, 27.4, -2.2), wp(4.2, 31.6, -12)
	local hand = mouth:Lerp(bell, 0.42)
	textured(decor(beam("Arm", wp(3.8, 24.8, 0), hand, 1.6, GOLD, f)), "px_gold_block", GOLD)
	textured(
		decor(part("Hand", Vector3.new(1.5, 1.5, 1.5), CFrame.new(hand), QUARTZ, nil, f)),
		"px_smooth_stone",
		QUARTZ
	)
	textured(decor(beam("Trumpet", mouth, bell, 0.8, GOLD, f)), "px_gold_block", GOLD)
	local dir = (bell - mouth).Unit
	textured(
		decor(
			part(
				"TrumpetBell",
				Vector3.new(2.4, 2.4, 1.6),
				CFrame.lookAt(bell, bell + dir),
				GOLD,
				nil,
				f
			)
		),
		"px_gold_block",
		GOLD
	)
	textured(
		decor(
			part(
				"TrumpetFlare",
				Vector3.new(3.4, 3.4, 0.5),
				CFrame.lookAt(bell + dir * 1, bell + dir * 2),
				GOLD,
				nil,
				f
			)
		),
		"px_gold_block",
		GOLD_DEEP
	)
	-- stepped wings: columns rising outward behind the shoulders, a second layer of feathers behind
	for _, s in ipairs({ -1, 1 }) do
		for i = 1, 5 do
			local xa, xb = s * (1.6 + (i - 1) * 2.3), s * (1.6 + i * 2.3)
			local x0, x1 = math.min(xa, xb), math.max(xa, xb)
			local y0, y1 = 15 + 2.8 * i, 25 + 2.3 * i
			g("Wing", x0, y0, 2, x1, y1, 3.6, "px_smooth_stone", QUARTZ)
			g("WingFeathers", x0, y0 + 2, 3.6, x1, y1 - 1.5, 4.4, "px_white_stone_bricks", QUARTZ)
		end
	end
end
-- a harp at (cx, cz) facing (dx, dz): a gold base, a quartz fore-pillar with a gold crown, a gold neck stepping down
-- over iron-bar strings, a lantern hanging on a chain from the tip
local function harp(cx, cz, dx, dz, lit, parent)
	local ok = if dx ~= 0
		then claim("Harp", cx - 2.5, cz - 6.5, cx + 2.5, cz + 6.5)
		else claim("Harp", cx - 6.5, cz - 2.5, cx + 6.5, cz + 2.5)
	if not ok then
		return
	end
	local f = folder("Harp", parent)
	local cf = fr(cx, cz, dx, dz)
	lb(cf, "HarpPlinth", -6.4, 0, -2.4, 6.4, 1, 2.4, "px_smooth_stone", QUARTZ, f)
	lb(cf, "HarpBase", -6, 1, -2, 6, 3.4, 2, "px_gold_block", GOLD, f)
	lb(cf, "HarpPillar", -6, 3.4, -1.6, -2.8, 22, 1.6, "px_smooth_stone", QUARTZ, f)
	for _, y in ipairs({ 8, 15 }) do
		decor(lb(cf, "HarpBand", -6.3, y, -1.9, -2.5, y + 1, 1.9, "px_gold_block", GOLD, f))
	end
	lb(cf, "HarpCrown", -6.6, 22, -2, -2.2, 24.4, 2, "px_gold_block", GOLD_DEEP, f)
	decor(lb(cf, "HarpCrownTop", -5.4, 24.4, -1, -3.4, 26, 1, "px_gold_block", GOLD, f))
	for _, n in ipairs({
		{ -2.8, 1.6, 20.4, 23.4 },
		{ 1.6, 5.2, 18.8, 21.8 },
		{ 5.2, 8, 17, 20 },
		{ 8, 10, 15.6, 18.4 },
	}) do
		decor(lb(cf, "HarpNeck", n[1], n[3], -1.2, n[2], n[4], 1.2, "px_gold_block", GOLD, f))
	end
	for _, sx in ipairs({ -1.6, -0.2, 1.2, 2.6, 4, 5.4 }) do
		local top = if sx < 1.6 then 20.4 elseif sx < 5.2 then 18.8 else 17
		lc(
			cf,
			"HarpString",
			0.35,
			top - 3.4,
			0.35,
			sx,
			3.4 + (top - 3.4) / 2,
			0,
			COL.bars,
			Enum.Material.Metal,
			f
		)
	end
	local p = (cf * CFrame.new(9, 9.4, 0)).Position
	lamp(p, 1.3, lit, f, p.Y + 6.2)
end
-- a golden halo on a quartz post with end rods
local function haloPost(cx, cz, parent)
	if not claim("HaloPost", cx - 2.5, cz - 2.5, cx + 2.5, cz + 2.5) then
		return
	end
	local f = folder("HaloPost", parent)
	box("HaloFoot", cx - 2.5, 0, cz - 2.5, cx + 2.5, 1, cz + 2.5, "px_gold_block", GOLD, f)
	box("HaloPost", cx - 2, 1, cz - 2, cx + 2, 12, cz + 2, "px_smooth_stone", QUARTZ, f)
	box("HaloCap", cx - 2.4, 12, cz - 2.4, cx + 2.4, 13, cz + 2.4, "px_gold_block", GOLD, f)
	decor(
		box(
			"HaloStem",
			cx - 0.8,
			13,
			cz - 0.8,
			cx + 0.8,
			15,
			cz + 0.8,
			"px_gold_block",
			GOLD_DEEP,
			f
		)
	)
	decor(
		box("HaloOrb", cx - 1.2, 15, cz - 1.2, cx + 1.2, 17.4, cz + 1.2, "px_gold_block", GOLD, f)
	)
	ring(cx, cz, 18.6, 6, 2, false, 2.4, f)
end
-- a quartz bench 3 blocks long facing (dx, dz): gold ends, a quartz seat and back
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
			"px_gold_block",
			GOLD,
			f
		)
	end
	lb(cf, "BenchSeat", -4, 1.6, -1.4, 4, 2.4, 1.4, "px_smooth_stone", QUARTZ, f)
	lb(cf, "BenchBack", -4, 2.4, 0.8, 4, 4.6, 1.4, "px_smooth_stone", QUARTZ, f)
end
-- a gold planter (2×1 blocks) with a quartz lip and white flowers
local function planter(cx, cz, alongX, parent)
	local ex, ez = if alongX then 4 else 2, if alongX then 2 else 4
	local x0, z0, x1, z1 = cx - ex, cz - ez, cx + ex, cz + ez
	if not claim("Planter", x0, z0, x1, z1) then
		return
	end
	local f = folder("Planter", parent)
	box("Planter", x0, 0, z0, x1, 3, z1, "px_gold_block", GOLD, f)
	box("PlanterLip", x0 - 0.3, 3, z0 - 0.3, x1 + 0.3, 3.4, z1 + 0.3, "px_smooth_stone", QUARTZ, f)
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
		local h = 1.2 + rng:NextNumber() * 0.6
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
			"px_white_wool",
			COL.white
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
	lc(cf, "ChestLatch", 0.7, 1, 0.3, 0, 2.6, -1.95, GOLD_DEEP, Enum.Material.Metal, parent)
end
-- a stack of n gold blocks at (x, z)
local function goldStack(x, z, n, parent, opt)
	if not claim("GoldBlock", x - 2, z - 2, x + 2, z + 2, opt) then
		return false
	end
	for i = 1, n do
		cube("GoldBlock", x, (i - 0.5) * B, z, B, B, B, "px_gold_block", GOLD, parent)
	end
	return true
end

-- ================================================================ 1. the balustrade round the pit, its lantern posts
do
	local f = F.pit
	local built = {}
	-- lantern posts: key -> { arm dx, arm dz, lit }; the corners look outward, the others into their opening
	local lanterns = {}
	for _, s in ipairs({ -1, 1 }) do
		lanterns[(s * 74) .. ",-14"] = { s, 0, false }
		lanterns[(s * 74) .. ",134"] = { s, 0, false }
		lanterns[(s * 14) .. ",-14"] = { -s, 0, true }
		lanterns[(s * 18) .. ",134"] = { -s, 0, true }
		lanterns[(s * 74) .. ",46"] = { 0, 1, true }
		lanterns[(s * 74) .. ",74"] = { 0, -1, true }
	end
	local function node(x, z)
		local key = x .. "," .. z
		if built[key] then
			return
		end
		built[key] = true
		local L = lanterns[key]
		if L then
			goldPost(x, z, L[1], L[2], L[3], F.lanterns)
		else
			box("BalustradePost", x - 2, 0, z - 2, x + 2, 4, z + 2, "px_smooth_stone", QUARTZ, f)
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
	end
	local runs = {
		{ -74, -14, -14, -14 }, -- north, open x -12..12 (the ladder and the walk to the rotunda)
		{ 14, -14, 74, -14 },
		{ -74, 134, -18, 134 }, -- south, open x -16..16 (widened: the arrival stays 20+ studs away)
		{ 18, 134, 74, 134 },
		{ -74, -14, -74, 46 }, -- west, open z 48..72
		{ -74, 74, -74, 134 },
		{ 74, -14, 74, 46 }, -- east
		{ 74, 74, 74, 134 },
	}
	for _, r in ipairs(runs) do
		local alongX = r[2] == r[4]
		local a, b = if alongX then r[1] else r[2], if alongX then r[3] else r[4]
		local c = if alongX then r[2] else r[1]
		local function span(name, lo, hi, y0, y1, half, variant, tint, isDecor)
			local p = if alongX
				then box(name, lo, y0, c - half, hi, y1, c + half, variant, tint, f)
				else box(name, c - half, y0, lo, c + half, y1, hi, variant, tint, f)
			if isDecor then
				decor(p)
			end
			return p
		end
		span("BalustradeKerb", a, b, 0, 1, 1.2, "px_smooth_stone", QUARTZ)
		span("BalustradeRail", a, b, 3, 3.8, 0.8, "px_gold_block", GOLD)
		local n = math.max(1, math.floor((b - a) / 8 + 0.5))
		local prev = nil
		for i = 0, n do
			local t = a + (b - a) * i / n
			if alongX then
				node(t, c)
			else
				node(c, t)
			end
			if prev then
				local gap = t - prev - 4
				local nb = math.max(1, math.floor(gap / 2))
				for j = 1, nb do
					local m = prev + 2 + gap * (j - 0.5) / nb
					span("Baluster", m - 0.5, m + 0.5, 1, 3, 0.5, "px_gold_block", GOLD, true)
				end
			end
			prev = t
		end
	end
end
task.wait()

-- ================================================================ 2. the south edge: a stepped balustrade along the rim
-- the z of the rim at column x (pad 10 from the ragged edge), nil if there is no island there
local function rimZ(x)
	for z = 230, 120, -1 do
		if isleOf(x - 2, z, 10) == "main" and isleOf(x + 2, z, 10) == "main" then
			return z
		end
	end
	return nil
end
do
	local f = F.south
	local cols = {}
	for k = 0, 29 do
		local zr = rimZ(-58 + 4 * k)
		cols[k] = if zr then math.floor(zr / B) * B else nil
	end
	for k = 0, 29 do
		local cx, zb = -58 + 4 * k, cols[k]
		local ax = math.abs(cx)
		local gap = ax <= 12 or ax == 26 or ax == 42 -- the causeway mouth and a few gaps
		if zb and zb > 140 and not gap then
			local zlo = zb - B
			for _, j in ipairs({ k - 1, k + 1 }) do
				if cols[j] and cols[j] > 140 then
					zlo = math.min(zlo, cols[j] - B)
				end
			end
			zlo = math.max(zlo, zb - 3 * B)
			if claim("RimBalustrade", cx - 2, zlo, cx + 2, zb, { edge = true }) then
				box("RimKerb", cx - 2, 0, zlo, cx + 2, 1.2, zb, "px_smooth_stone", QUARTZ, f)
				box(
					"RimRail",
					cx - 2,
					3,
					zlo + 0.6,
					cx + 2,
					3.8,
					zb - 0.6,
					"px_gold_block",
					GOLD,
					f
				)
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
				if ax == 14 or ax == 34 or ax == 54 then
					box("RimPost", cx - 2, 0, zb - B, cx + 2, 6, zb, "px_smooth_stone", QUARTZ, f)
					box(
						"RimPostCap",
						cx - 2.3,
						6,
						zb - B - 0.3,
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
							zb - 3,
							cx + 1,
							8.6,
							zb - 1,
							"px_gold_block",
							GOLD_DEEP,
							f
						)
					)
				end
			end
		end
	end
end
task.wait()

-- ================================================================ 3. the golden stair-causeway down from the south rim
do
	local f = F.causeway
	-- the south edge of the island cells under the deck (cells are 8 studs, centres at 4 mod 8)
	local function edgeZ(x)
		local zc = 220
		while zc > 120 and isleOf(x, zc) ~= "main" do
			zc -= 8
		end
		return zc + 4
	end
	local zLo, zHi = math.huge, -math.huge
	for _, x in ipairs({ -12, -4, 4, 12 }) do
		local e = edgeZ(x)
		zLo, zHi = math.min(zLo, e), math.max(zHi, e)
	end
	local ZMAX = 206 -- the landing stays inside the edge walls (z 212)
	local avail = ZMAX - zHi
	local run, drop = 16, 8
	if avail < 32 then
		run = if avail >= 22 then 12 else 8
	end
	if avail - run < 8 then
		run, drop = 4, 4
	end
	local zA = zHi + run
	local zEnd = math.min(zA + 16, ZMAX)
	if zEnd - zA < 6 then
		table.insert(skipped, "Causeway")
	else
		table.insert(claims, { -16, 168, 16, 212 })
		local yL = 0.2 - drop
		-- the head: a gold deck with quartz edges over the rim (a hair above the paving, no z-fight)
		box("CausewayHead", -7, -4, 172, 7, 0.2, zHi, "px_gold_block", GOLD, f)
		box("CausewayHeadEdge", -10, -4, 172, -7, 0.2, zHi, "px_smooth_stone", QUARTZ, f)
		box("CausewayHeadEdge", 7, -4, 172, 10, 0.2, zHi, "px_smooth_stone", QUARTZ, f)
		local function parapet(x0, x1, y, za, zb)
			box("CausewayParapet", x0, y, za, x1, y + 3.2, zb, "px_smooth_stone", QUARTZ, f)
			box(
				"CausewayParapetCap",
				x0 - 0.2,
				y + 3.2,
				za,
				x1 + 0.2,
				y + 3.8,
				zb,
				"px_gold_block",
				GOLD,
				f
			)
		end
		for _, s in ipairs({ -1, 1 }) do
			parapet(math.min(s * 9, s * 10), math.max(s * 9, s * 10), 0.2, zLo - 4, zHi)
		end
		-- the stairs down (kit stairs: visible gold steps on an invisible ramp), a stepped parapet on each side
		stairs("Causeway", 0, zHi, zA, 0.2, -drop, 20, "px_gold_block", f)
		local steps = math.max(1, math.floor(run / 2))
		local stepD = run / steps
		for k = 0, steps - 1 do
			local top = 0.2 - (k + 1) * drop / steps
			for _, s in ipairs({ -1, 1 }) do
				parapet(
					math.min(s * 9, s * 10),
					math.max(s * 9, s * 10),
					top,
					zHi + k * stepD,
					zHi + (k + 1) * stepD
				)
			end
		end
		-- the landing, wider than the stairs, hanging over the void on a stepped quartz-and-gold cone
		box("CausewayLanding", -14, yL - 4, zA, 14, yL, zEnd, "px_gold_block", GOLD, f)
		box(
			"CausewayLandingInlay",
			-6,
			yL - 4,
			zA + 2,
			6,
			yL + 0.1,
			zEnd - 4,
			"px_smooth_stone",
			QUARTZ,
			f
		)
		local cone = {
			{ 12, 1, 4, "px_smooth_stone", QUARTZ },
			{ 8, 3, 4, "px_gold_block", GOLD_DEEP },
			{ 4, 5, 4, "px_smooth_stone", QUARTZ },
			{ 2, 6, 4, "px_gold_block", GOLD },
		}
		local y = yL - 4
		for _, c in ipairs(cone) do
			local za, zb = zA + c[2], zEnd - c[2]
			if zb - za >= 2 then
				box("CausewayCone", -c[1], y - c[3], za, c[1], y, zb, c[4], c[5], f)
				y -= c[3]
			end
		end
		for _, s in ipairs({ -1, 1 }) do
			parapet(math.min(s * 13, s * 14), math.max(s * 13, s * 14), yL, zA, zEnd - 4) -- the sides
			parapet(math.min(s * 10, s * 13), math.max(s * 10, s * 13), yL, zA, zA + 1) -- the back corners
		end
		-- the arch over the far edge: quartz piers, a stepped gold lintel, two lanterns hanging under it
		local za, zb = zEnd - 4, zEnd
		for _, s in ipairs({ -1, 1 }) do
			local x0, x1 = math.min(s * 10, s * 14), math.max(s * 10, s * 14)
			box(
				"ArchPierFoot",
				x0 - 0.3,
				yL,
				za - 0.3,
				x1 + 0.3,
				yL + 1.2,
				zb + 0.3,
				"px_gold_block",
				GOLD,
				f
			)
			box("ArchPier", x0, yL + 1.2, za, x1, yL + 16, zb, "px_white_stone_bricks", QUARTZ, f)
			box(
				"ArchCorbel",
				math.min(s * 8, s * 10),
				yL + 13,
				za,
				math.max(s * 8, s * 10),
				yL + 16,
				zb,
				"px_gold_block",
				GOLD,
				f
			)
		end
		box(
			"ArchLintel",
			-14.4,
			yL + 16,
			za - 0.2,
			14.4,
			yL + 20,
			zb + 0.2,
			"px_gold_block",
			GOLD,
			f
		)
		box("ArchStep", -10, yL + 20, za, 10, yL + 22, zb, "px_gold_block", GOLD_DEEP, f)
		box("ArchStep", -6, yL + 22, za, 6, yL + 24, zb, "px_gold_block", GOLD, f)
		decor(box("ArchKeystone", -2, yL + 24, za + 1, 2, yL + 27, zb - 1, "px_glowstone", nil, f))
		for _, s in ipairs({ -1, 1 }) do
			lamp(V(s * 5, yL + 11.6, (za + zb) / 2), 1.4, true, f, BY + yL + 16)
		end
		-- the railing between the piers: a quartz kerb, gold balusters, a gold rail
		box("ArchKerb", -10, yL, zb - 1.4, 10, yL + 1, zb, "px_smooth_stone", QUARTZ, f)
		box("ArchRail", -10, yL + 3, zb - 1.2, 10, yL + 3.8, zb - 0.2, "px_gold_block", GOLD, f)
		for x = -9, 9, 2 do
			decor(
				box(
					"ArchBaluster",
					x - 0.5,
					yL + 1,
					zb - 1.2,
					x + 0.5,
					yL + 3,
					zb - 0.2,
					"px_gold_block",
					GOLD,
					f
				)
			)
		end
	end
end
task.wait()

-- ================================================================ 4. the trumpet angels, the harps, the halos
do
	for _, s in ipairs({ -1, 1 }) do
		angel(s * 24, 141, 0, 1, F.statues) -- flanking the way from the arrival to the pit, greeting the arrivals
		angel(s * 104, 20, -s, 0, F.statues) -- the east and west sides, looking at the pit
		angel(s * 104, 100, -s, 0, F.statues)
		angel(s * 48, -41, 0, 1, F.statues) -- flanking the north walk
	end
	for _, s in ipairs({ -1, 1 }) do
		harp(s * 124, 32, -s, 0, true, F.harps)
		harp(s * 124, 88, -s, 0, false, F.harps)
		haloPost(s * 100, 42, F.halos) -- a pair framing the axis to each side opening
		haloPost(s * 100, 78, F.halos)
		haloPost(s * 86, -44, F.halos)
	end
end
task.wait()

-- ================================================================ 5. the halo monument (east axis), the fountain (west axis)
do
	if claim("HaloMonument", 118, 54, 130, 66) then
		local f = folder("HaloMonument", F.halos)
		local cx, cz = 124, 60
		box(
			"MonumentFoot",
			cx - 6,
			0,
			cz - 6,
			cx + 6,
			1,
			cz + 6,
			"px_white_stone_bricks",
			QUARTZ,
			f
		)
		box("MonumentStep", cx - 5, 1, cz - 5, cx + 5, 2, cz + 5, "px_gold_block", GOLD, f)
		box("MonumentPost", cx - 4, 2, cz - 4, cx + 4, 18, cz + 4, "px_smooth_stone", QUARTZ, f)
		decor(
			box(
				"MonumentBand",
				cx - 4.3,
				9,
				cz - 4.3,
				cx + 4.3,
				10,
				cz + 4.3,
				"px_gold_block",
				GOLD,
				f
			)
		)
		box(
			"MonumentCap",
			cx - 4.6,
			18,
			cz - 4.6,
			cx + 4.6,
			19.4,
			cz + 4.6,
			"px_gold_block",
			GOLD_DEEP,
			f
		)
		decor(
			box("MonumentStem", cx - 1, 19.4, cz - 1, cx + 1, 22, cz + 1, "px_gold_block", GOLD, f)
		)
		decor(box("MonumentOrb", cx - 2, 22, cz - 2, cx + 2, 26, cz + 2, "px_glowstone", nil, f))
		ring(cx, cz, 28, 12, 2, true, 3, f)
	end
	if claim("Fountain", -130, 54, -118, 66) then
		local f = folder("Fountain", F.garden)
		local cx, cz = -124, 60
		box(
			"FountainFloor",
			cx - 6,
			0,
			cz - 6,
			cx + 6,
			0.6,
			cz + 6,
			"px_white_stone_bricks",
			QUARTZ,
			f
		)
		for _, w in ipairs({
			{ -6, -6, 6, -4.4 },
			{ -6, 4.4, 6, 6 },
			{ -6, -4.4, -4.4, 4.4 },
			{ 4.4, -4.4, 6, 4.4 },
		}) do
			box(
				"FountainWall",
				cx + w[1],
				0.6,
				cz + w[2],
				cx + w[3],
				2.4,
				cz + w[4],
				"px_smooth_stone",
				QUARTZ,
				f
			)
			box(
				"FountainRim",
				cx + w[1] - 0.2,
				2.4,
				cz + w[2] - 0.2,
				cx + w[3] + 0.2,
				3,
				cz + w[4] + 0.2,
				"px_gold_block",
				GOLD,
				f
			)
		end
		local water = decor(
			box(
				"FountainWater",
				cx - 4.4,
				0.6,
				cz - 4.4,
				cx + 4.4,
				1.9,
				cz + 4.4,
				"px_water",
				COL.water,
				f
			)
		)
		water.Transparency = 0.2
		box("FountainPier", cx - 2, 0.6, cz - 2, cx + 2, 4.6, cz + 2, "px_smooth_stone", QUARTZ, f)
		box("FountainColumn", cx - 1, 4.6, cz - 1, cx + 1, 8, cz + 1, "px_gold_block", GOLD, f)
		box("FountainBowl", cx - 3, 8, cz - 3, cx + 3, 9, cz + 3, "px_smooth_stone", QUARTZ, f)
		decor(
			box(
				"FountainBowlRim",
				cx - 3.2,
				9,
				cz - 3.2,
				cx + 3.2,
				9.4,
				cz + 3.2,
				"px_gold_block",
				GOLD,
				f
			)
		)
		decor(
			box("FountainCrown", cx - 1, 9.4, cz - 1, cx + 1, 11.4, cz + 1, "px_glowstone", nil, f)
		)
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local sx, sz = if d[1] ~= 0 then 0.4 else 1.6, if d[1] ~= 0 then 1.6 else 0.4
			local st = decor(
				part(
					"FountainStream",
					Vector3.new(sx, 7.1, sz),
					at(cx + d[1] * 3.4, 1.9 + 3.55, cz + d[2] * 3.4),
					COL.stream,
					Enum.Material.Glass,
					f
				)
			)
			st.Transparency = 0.45
			st.CastShadow = false
		end
	end
end
task.wait()

-- ================================================================ 6. the pavilions in the north-west and north-east corners
do
	for _, s in ipairs({ -1, 1 }) do
		local cx, cz = s * 128, -84
		if claim("Pavilion", cx - 7.5, cz - 7.5, cx + 7.5, cz + 7.5) then
			local f = folder("Pavilion", F.pavilions)
			local cf = fr(cx, cz, 0, 1) -- open to the south
			lb(cf, "PavilionStep", -7.5, 0, -7.5, 7.5, 0.6, 7.5, "px_gold_block", GOLD, f)
			lb(
				cf,
				"PavilionFloor",
				-6.5,
				0.6,
				-6.5,
				6.5,
				1.2,
				6.5,
				"px_white_stone_bricks",
				QUARTZ,
				f
			)
			for _, sx in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local x0, x1 = if sx < 0 then -6 else 2, if sx < 0 then -2 else 6
					local z0, z1 = if sz < 0 then -6 else 2, if sz < 0 then -2 else 6
					lb(
						cf,
						"ColumnBase",
						x0 - 0.3,
						1.2,
						z0 - 0.3,
						x1 + 0.3,
						2.2,
						z1 + 0.3,
						"px_gold_block",
						GOLD,
						f
					)
					lb(cf, "Column", x0, 2.2, z0, x1, 12, z1, "px_smooth_stone", QUARTZ, f)
					lb(
						cf,
						"Capital",
						x0 - 0.3,
						12,
						z0 - 0.3,
						x1 + 0.3,
						13,
						z1 + 0.3,
						"px_gold_block",
						GOLD,
						f
					)
				end
			end
			-- low parapets between the columns on the back and the sides, a seat inside
			for _, r in ipairs({ { -2, 4.8, 2, 6 }, { -6, -2, -4.8, 2 }, { 4.8, -2, 6, 2 } }) do
				lb(
					cf,
					"PavilionRail",
					r[1],
					1.2,
					r[2],
					r[3],
					3.4,
					r[4],
					"px_smooth_stone",
					QUARTZ,
					f
				)
				decor(
					lb(
						cf,
						"PavilionRailCap",
						r[1] - 0.2,
						3.4,
						r[2] - 0.2,
						r[3] + 0.2,
						3.9,
						r[4] + 0.2,
						"px_gold_block",
						GOLD,
						f
					)
				)
			end
			lb(cf, "PavilionSeat", -2, 1.2, 2.8, 2, 2.8, 4.8, "px_smooth_stone", QUARTZ, f)
			-- the entablature, a quartz band and the stepped gold dome with a glowing tip
			lb(cf, "Entablature", -7, 13, -7, 7, 15, 7, "px_gold_block", GOLD, f)
			decor(lb(cf, "Cornice", -7.4, 13.3, -7.4, 7.4, 14.1, 7.4, "px_smooth_stone", QUARTZ, f))
			lb(cf, "Dome", -6, 15, -6, 6, 18, 6, "px_gold_block", GOLD_DEEP, f)
			lb(cf, "Dome", -4.4, 18, -4.4, 4.4, 21, 4.4, "px_gold_block", GOLD, f)
			lb(cf, "Dome", -2.6, 21, -2.6, 2.6, 23.6, 2.6, "px_gold_block", GOLD_DEEP, f)
			lb(cf, "Dome", -1.2, 23.6, -1.2, 1.2, 26, 1.2, "px_gold_block", GOLD, f)
			decor(lb(cf, "Spire", -0.5, 26, -0.5, 0.5, 29, 0.5, "px_gold_block", GOLD, f))
			decor(lb(cf, "SpireTip", -0.9, 29, -0.9, 0.9, 30.8, 0.9, "px_glowstone", nil, f))
			for _, d in ipairs({ { 0, -6.1 }, { 0, 6.1 }, { -6.1, 0 }, { 6.1, 0 } }) do
				local wx, wz = if d[1] == 0 then 2.4 else 0.2, if d[1] == 0 then 0.2 else 2.4
				lc(
					cf,
					"DomeWindow",
					wx,
					1.8,
					wz,
					d[1],
					16.6,
					d[2],
					QUARTZ,
					Enum.Material.SmoothPlastic,
					f
				)
			end
			local p = (cf * CFrame.new(0, 9.4, 0)).Position
			lamp(p, 1.4, true, f, p.Y + 3.6)
			-- a gold planter beside it and a couple of gold blocks
			planter(cx - s * 16, cz, false, F.garden)
		end
	end
end
task.wait()

-- ================================================================ 7. lantern posts along the walks, benches, planters
do
	for _, s in ipairs({ -1, 1 }) do
		for _, p in ipairs({
			{ s * 100, -32, 0, 1, true },
			{ s * 124, -8, 0, -1, true },
			{ s * 148, -32, 0, 1, false },
			{ s * 18, -44, -s, 0, true },
		}) do
			if claim("WalkLantern", p[1] - 2.3, p[2] - 2.3, p[1] + 2.3, p[2] + 2.3) then
				goldPost(p[1], p[2], p[3], p[4], p[5], F.lanterns)
			end
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		bench(s * 30, -41, 0, 1, F.garden)
		bench(s * 60, -50, 0, 1, F.garden)
		bench(s * 142, 60, -s, 0, F.garden)
		planter(s * 104, -4, true, F.garden)
		planter(s * 148, -4, true, F.garden)
		planter(s * 124, -38, true, F.garden)
		planter(s * 66, -42, true, F.garden)
		planter(s * 104, 30, true, F.garden)
		planter(s * 104, 90, true, F.garden)
	end
end
task.wait()

-- ================================================================ 8. chests and gold behind the stall, gold blocks over the plaza
do
	local f = F.props
	chest(44, 150, 1, 0, f)
	chest(44, 155, 1, 0, f)
	goldStack(46, 145, 2, f)
	goldStack(44, 160, 1, f)
	local placed = 0
	for _ = 1, 80 do
		if placed >= 14 then
			break
		end
		local x = rng:NextInteger(-40, 39) * B + 2
		local z = rng:NextInteger(-14, 40) * B + 2
		if freeGround(x, z, 2) then
			local n = if rng:NextNumber() < 0.3 then 2 else 1
			if goldStack(x, z, n, f, { quiet = true }) then
				placed += 1
				if rng:NextNumber() < 0.4 then
					goldStack(x + pick({ -B, B }), z, 1, f, { quiet = true })
				end
			end
		end
	end
end

print(
	("[build-cherubim] plaza: %d parts, %d lights%s"):format(
		count - startCount,
		LIGHTS - lightsLeft,
		if #skipped > 0 then ", skipped " .. table.concat(skipped, " ") else ""
	)
)
