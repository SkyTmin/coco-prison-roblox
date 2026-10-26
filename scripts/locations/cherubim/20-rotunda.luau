--!nocheck
-- ================================================================ cherubim: the rotunda (the hero), its steps, the gallery = SUMMIT
-- Centre (0, -112). Angles below are degrees from south (+Z) toward east (+X): x = r·sin a, z = -112 + r·cos a.
-- The PLINTH: a stepped disc r 52 (white stone bricks y 0..6, a gold course y 6..8 = the floor), a lower step r 52..56
-- (y 0..4), cut out for the STEPS (x -20..20, z -68..-56: kit stairs y 0 → 8, quartz and gold, cheek walls x ±20..24
-- with gold lantern posts). The FORECOURT: trumpet angels on plinths at (±44, -62), gold planters at (±32, -60) and
-- (±58, -66); x -20..20 stays clear.
-- The DRUM: 14 white quartz piers (8 tangential × 6 radial, r 44..50) at a = 11.25 + 22.5·i, y 8..60, with gold bases,
-- capitals, panels; between them 9 tall gold-framed arched windows (warm glass, y 12..58, a gold transom at the
-- gallery level y 44..48). The south bay is the FACADE x -24..24, z -72..-68 with the PORTAL x -12..12, y 8..40
-- (stepped arch, gold frame, an observer eye above). The CORNICE: a gold ring r 42..52 at y 60..64, its top a ledge
-- (quartz rail r 49..52) with 6 PINNACLES at r 48 (a ±22.5, ±67.5, ±157.5, to y 93) and four six-winged CHERUBS at
-- r 50 on the diagonals (y 64..94). The DOME: 11 stepped gold rings y 64..108 (r 44 → 18, GOLD_DEEP ribs every 45°,
-- 16 small warm windows at y 72..80), hollow (its inner faces show), an oculus r 11; the LANTERN on top (gold ring y
-- 108..110, 8 quartz columns, a glowing core, a stepped gold roof to y 122, a finial to 126); the HALO: a ring of gold
-- blocks r 10..14 at y 128..130 with 12 white neon end rods (decor).
-- Two STAIR TURRETS east and west (x ±44..80, z -138..-104, walls to y 72, stepped gold caps to y 102): a door from
-- the rotunda floor at x ±44, z -116..-108 (y 8..20), inside a square spiral of 5 flights (rise 8 each, 8 wide) round
-- a core x ±60..68, z -126..-116 — SW corner (ground) → W lane → NW → N lane → NE → E lane → SE → S lane → SW → W lane →
-- NW landing at y 48 — then a door (z -134..-126, y 48..60) and a passage onto the gallery. Headroom ≥ 22 everywhere
-- on the flights (one full turn = 32 studs).
-- INSIDE: the gold course floor with white 2-block squares (r ≤ 40); 8 inner piers (8×8, y 8..28, gold panels) at
-- (±15, -88), (±26, -102), (±26, -124), (±20, -136) with praying angels (to y 43); the aisle x -10..10 from the portal
-- to the DAIS (three gold tiers x ±14 / ±11 / ±8, z -152..-132, y 8..14) with THE ARK (x -6..6, z -148..-140,
-- y 14..22, bands, poles, two kneeling cherubs on the lid, wings meeting over it), lantern posts and candles, two harps
-- at x ±19; a gold chandelier on a chain from the lantern (y 66..74) and 4 lanterns on chains at r 18.
-- The GALLERY (SUMMIT) y 48: a gold ring r 30..45 at y 44..48 (walkway ≥ 8 studs wide between the balustrade and the
-- piers), a gold balustrade r 30..33.5 (y 48..52), benches in four window bays, two lanterns on the balustrade.
local rot = folder("Rotunda")
local partsBefore = count
local nLights = 0
local CX, CZ, FY, GY = ROTUNDA.x, ROTUNDA.z, ROTUNDA.floor, SUMMIT.y
local SMOOTH, BRICK, GOLDV = "px_smooth_stone", "px_white_stone_bricks", "px_gold_block"
local GLASS_WARM = Color3.fromRGB(255, 222, 150)
local DEG = math.pi / 180

-- the stair turret footprints (both sides): cells whose centre falls here are left out of the rings
local function inTurret(x, z)
	return math.abs(x) > 44 and math.abs(x) < 80 and z > -140 and z < -104
end
-- a box in the local frame cf by two corners; decor unless `solid`
local function lp(name, cf, x0, y0, z0, x1, y1, z1, variant, tint, parent, solid)
	local p = part(
		name,
		Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0)),
		cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		tint,
		nil,
		parent
	)
	if variant then
		textured(p, variant, tint)
	end
	if not solid then
		decor(p)
	end
	return p
end
-- a box in the polar frame of angle a (degrees): tangential t0..t1, radial r0..r1 from the rotunda centre
local function rbox(name, a, r0, r1, t0, t1, y0, y1, variant, tint, parent, solid)
	return lp(
		name,
		at(CX, 0, CZ) * CFrame.Angles(0, a * DEG, 0),
		t0,
		y0,
		r0,
		t1,
		y1,
		r1,
		variant,
		tint,
		parent,
		solid
	)
end
local function glassy(p)
	p.Material = Enum.Material.Glass
	p.MaterialVariant = ""
	p.Color = GLASS_WARM
	p.Transparency = 0.3
	p.CastShadow = false
	return p
end
-- greedy rectangles over a 4-stud grid round the centre (cell centres at 4k + off, relative): kindFn(dx, dz) -> kind
-- or nil; equal runs of a row merge, then equal runs of consecutive rows; emit(kind, x0, x1, z0, z1) (relative)
local function cells(off, rMax, kindFn, emit)
	local n = math.ceil(rMax / 4) + 1
	local open = {}
	for b = -n, n + 1 do
		local runs = {}
		if b <= n then
			local dz = 4 * b + off
			local prev, start = nil, 0
			for a = -n, n + 1 do
				local k = if a <= n then kindFn(4 * a + off, dz) else nil
				if k ~= prev then
					if prev ~= nil then
						runs[start .. ":" .. a .. ":" .. tostring(prev)] = { start, a, prev }
					end
					prev, start = k, a
				end
			end
		end
		for key, r in pairs(open) do
			if not runs[key] then
				emit(
					r[3],
					4 * r[1] + off - 2,
					4 * r[2] + off - 2,
					4 * r[4] + off - 2,
					4 * b + off - 2
				)
				open[key] = nil
			end
		end
		for key, r in pairs(runs) do
			if not open[key] then
				open[key] = { r[1], r[2], r[3], b }
			end
		end
	end
end
-- a stepped ring rIn < d ≤ rOut of one texture between y0 and y1; skip(x, z) leaves cells out
local function ring(name, off, rIn, rOut, y0, y1, variant, tint, parent, skip, deco)
	cells(off, rOut, function(dx, dz)
		local d = math.sqrt(dx * dx + dz * dz)
		if d <= rIn or d > rOut or (skip and skip(CX + dx, CZ + dz)) then
			return nil
		end
		return "x"
	end, function(_, x0, x1, z0, z1)
		local p = box(name, CX + x0, y0, CZ + z0, CX + x1, y1, CZ + z1, variant, tint, parent)
		if deco then
			decor(p)
		end
	end)
end
-- a standing angel (decor), base at cf facing its -Z; 16 studs tall at s = 1; trumpet raised or hands in prayer
local function angel(cf, s, trumpet, parent)
	local f = folder(if trumpet then "TrumpetAngel" else "Angel", parent)
	local function q(name, x0, y0, z0, x1, y1, z1, variant, tint)
		return lp(name, cf, x0 * s, y0 * s, z0 * s, x1 * s, y1 * s, z1 * s, variant, tint, f)
	end
	q("AngelHem", -3, 0, -2.5, 3, 2, 2.5, GOLDV, GOLD_DEEP)
	q("AngelRobe", -2.5, 2, -2, 2.5, 7, 2, GOLDV, GOLD)
	q("AngelBody", -2, 7, -1.5, 2, 11, 1.5, GOLDV, GOLD)
	q("AngelHead", -1.5, 11, -1.5, 1.5, 14, 1.5, GOLDV, GOLD)
	q("AngelHair", -1.7, 12.6, -1.1, 1.7, 14.3, 1.7, GOLDV, HONEY)
	q("AngelHalo", -2, 15, -2, 2, 15.5, -1.5, GOLDV, GOLD)
	q("AngelHalo", -2, 15, 1.5, 2, 15.5, 2, GOLDV, GOLD)
	q("AngelHalo", -2, 15, -1.5, -1.5, 15.5, 1.5, GOLDV, GOLD)
	q("AngelHalo", 1.5, 15, -1.5, 2, 15.5, 1.5, GOLDV, GOLD)
	if trumpet then
		q("AngelArm", -2.7, 7.5, -0.8, -2, 10.8, 0.8, GOLDV, GOLD)
		q("AngelArm", 0.4, 10, -3.2, 1.6, 11, -1.5, GOLDV, GOLD)
		local base = cf * CFrame.new(0, 12.2 * s, -1.6 * s) * CFrame.Angles(math.rad(30), 0, 0)
		textured(
			decor(
				part(
					"Trumpet",
					Vector3.new(0.7, 0.7, 7) * s,
					base * CFrame.new(0, 0, -3.5 * s),
					nil,
					nil,
					f
				)
			),
			GOLDV,
			GOLD_DEEP
		)
		textured(
			decor(
				part(
					"TrumpetBell",
					Vector3.new(2.2, 2.2, 1.2) * s,
					base * CFrame.new(0, 0, -7.4 * s),
					nil,
					nil,
					f
				)
			),
			GOLDV,
			GOLD
		)
	else
		q("AngelArms", -2, 8, -3, 2, 9.5, -1.5, GOLDV, GOLD)
		q("AngelHands", -0.6, 9.5, -3, 0.6, 11, -2, GOLDV, GOLD_DEEP)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, w in ipairs({
			{ 1.5, 4, 5, 12 },
			{ 4, 6.5, 7, 14 },
			{ 6.5, 8.5, 9, 15.5 },
			{ 8.5, 10, 11, 16 },
		}) do
			q("AngelWing", sx * w[1], w[3], 1.5, sx * w[2], w[4], 3, SMOOTH, QUARTZ)
		end
	end
	return f
end
-- a six-winged cherub (decor, ~30 tall) on a gold pedestal, base at cf facing its -Z; the wings spread behind it
local function seraph(cf, parent)
	local f = folder("Cherub", parent)
	local function q(name, x0, y0, z0, x1, y1, z1, variant, tint)
		return lp(name, cf, x0, y0, z0, x1, y1, z1, variant, tint, f)
	end
	q("CherubPedestal", -3, 0, -3, 3, 4, 3, GOLDV, GOLD_DEEP)
	q("CherubBody", -2, 4, -2, 2, 16, 2, GOLDV, GOLD)
	q("CherubBelt", -2.3, 9, -2.3, 2.3, 10, 2.3, GOLDV, GOLD_DEEP)
	q("CherubHead", -2, 16, -2, 2, 20, 2, GOLDV, GOLD)
	q("CherubFace", -1.4, 17.4, -2.12, 1.4, 18.2, -2.02, nil, Color3.fromRGB(150, 100, 40))
	q("CherubHalo", -4, 21.5, -4, 4, 22.5, -3, GOLDV, GOLD)
	q("CherubHalo", -4, 21.5, 3, 4, 22.5, 4, GOLDV, GOLD)
	q("CherubHalo", -4, 21.5, -3, -3, 22.5, 3, GOLDV, GOLD)
	q("CherubHalo", 3, 21.5, -3, 4, 22.5, 3, GOLDV, GOLD)
	for _, sx in ipairs({ -1, 1 }) do
		for _, w in ipairs({ -- x0, x1, y0, y1, z0 (2 thick): the upper pair raised, the middle spread, the lower down
			{ 2, 5, 14, 20, 2 },
			{ 5, 7, 18, 25, 2 },
			{ 7, 9, 23, 30, 2 },
			{ 2, 6, 8, 14, 2.2 },
			{ 6, 9, 9, 15, 2.2 },
			{ 9, 11.5, 10, 15, 2.2 },
			{ 11.5, 13, 11, 14, 2.2 },
			{ 2, 5, 4, 12, 4.2 },
			{ 5, 7, 4, 9, 4.2 },
		}) do
			q("CherubWing", sx * w[1], w[3], w[5], sx * w[2], w[4], w[5] + 2, SMOOTH, QUARTZ)
		end
	end
	return f
end
-- a kneeling gold cherub of the ark (decor), base at cf facing its -Z; its wings reach 3.4 forward over the lid
local function kneeler(cf, parent)
	local f = folder("ArkCherub", parent)
	local function q(name, x0, y0, z0, x1, y1, z1, tint)
		return lp(name, cf, x0, y0, z0, x1, y1, z1, GOLDV, tint, f)
	end
	q("ArkCherubLegs", -1.5, 0, -0.5, 1.5, 1.5, 3, GOLD_DEEP)
	q("ArkCherubBody", -1.5, 1.5, 0, 1.5, 5.5, 2.5, GOLD)
	q("ArkCherubHead", -1.2, 5.3, -0.8, 1.2, 7.7, 1.6, GOLD)
	q("ArkCherubArms", -1.2, 3, -1.8, 1.2, 4, 0, GOLD)
	for _, sx in ipairs({ -1, 1 }) do
		q("ArkCherubWing", sx * 1.5, 4, 1, sx * 2.5, 8, 3, GOLD_DEEP)
		q("ArkCherubWing", sx * 1.2, 7.5, -1, sx * 2.6, 10, 1, GOLD_DEEP)
		q("ArkCherubWing", sx * 0.8, 9.5, -2.6, sx * 2.6, 11.5, -1, GOLD_DEEP)
		q("ArkCherubWing", sx * 0.6, 11, -3.4, sx * 2.4, 12.5, -2.6, GOLD_DEEP)
	end
	return f
end

-- ================================================================ the plinth, the steps, the forecourt
do
	local f = folder("Plinth", rot)
	cells(2, 56, function(dx, dz)
		local x, z = CX + dx, CZ + dz
		local d = math.sqrt(dx * dx + dz * dz)
		if d > 56 or inTurret(x, z) or (z > -68 and math.abs(x) < 24) or isleOf(x, z, 4) == nil then
			return nil
		end
		return if d <= 52 then "top" else "step"
	end, function(kind, x0, x1, z0, z1)
		if kind == "top" then
			box("Plinth", CX + x0, 0, CZ + z0, CX + x1, 6, CZ + z1, BRICK, QUARTZ, f)
			box("PlinthCourse", CX + x0, 6, CZ + z0, CX + x1, FY, CZ + z1, GOLDV, GOLD_DEEP, f)
		else
			box("PlinthStep", CX + x0, 0, CZ + z0, CX + x1, 4, CZ + z1, BRICK, QUARTZ, f)
		end
	end)
	-- the steps from the plaza (y 0, z -56) up to the portal (y 8, z -68), quartz and gold in turn
	local st = folder("Steps", f)
	stairs("RotSteps", 0, -56, -68, 0, FY, 40, SMOOTH, st)
	local i = 0
	for _, p in ipairs(st:GetChildren()) do
		if p.Name == "RotStepsStep" then
			i += 1
			if i % 2 == 0 then
				textured(p, GOLDV, GOLD)
			else
				textured(p, SMOOTH, QUARTZ)
			end
		end
	end
	box("StepsFill", -20, 0, -68, 20, 4, -62, BRICK, QUARTZ, st)
	for _, sx in ipairs({ -1, 1 }) do
		for _, c in ipairs({ { -68, -64, 8 }, { -64, -60, 6 }, { -60, -56, 4 } }) do
			box("StepCheek", sx * 20, 0, c[1], sx * 24, c[3], c[2], BRICK, QUARTZ, st)
			box("StepCheekCap", sx * 20, c[3], c[1], sx * 24, c[3] + 1, c[2], GOLDV, GOLD_DEEP, st)
		end
		-- a gold lantern post on the low end of each cheek
		box("LanternPost", sx * 21, 5, -59, sx * 23, 10, -57, GOLDV, GOLD, st)
		lantern(V(sx * 22, 10.85, -58), st)
		nLights += 1
	end
	-- the forecourt: trumpet angels on plinths facing the plaza, gold planters
	local fc = folder("Forecourt", f)
	for _, sx in ipairs({ -1, 1 }) do
		box("AngelPlinth", sx * 40, 0, -66, sx * 48, 6, -58, BRICK, QUARTZ, fc)
		box("AngelPlinthTop", sx * 39.5, 6, -66.5, sx * 48.5, 7, -57.5, GOLDV, GOLD_DEEP, fc)
		angel(at(sx * 44, 7, -62) * CFrame.Angles(0, math.pi, 0), 1.25, true, fc)
		for _, pl in ipairs({ { 32, -60 }, { 58, -66 } }) do
			local x, z = sx * pl[1], pl[2]
			box("Planter", x - 3, 0, z - 3, x + 3, 3, z + 3, GOLDV, GOLD_DEEP, fc)
			box("PlanterHedge", x - 2.5, 3, z - 2.5, x + 2.5, 5.5, z + 2.5, "px_hedge", nil, fc)
			for _, fl in ipairs({ { -1.2, 0.8, Color3.fromRGB(255, 232, 120) }, { 1, -1, QUARTZ } }) do
				decor(
					box(
						"Flower",
						x + fl[1] - 0.6,
						5.5,
						z + fl[2] - 0.6,
						x + fl[1] + 0.6,
						6.7,
						z + fl[2] + 0.6,
						"px_white_wool",
						fl[3],
						fc
					)
				)
			end
		end
	end
end
task.wait()

-- ================================================================ the drum: piers, windows, the facade with the portal
do
	local f = folder("Drum", rot)
	-- 14 piers (the two south ones give way to the facade)
	for i = 1, 14 do
		local a = 11.25 + 22.5 * i
		rbox("Pier", a, 44, 50, -4, 4, FY, 60, SMOOTH, QUARTZ, f, true)
		rbox("PierBase", a, 43.5, 50.5, -4.5, 4.5, FY, 10, GOLDV, GOLD_DEEP, f, true)
		rbox("PierCapital", a, 43.5, 50.5, -4.5, 4.5, 56, 60, GOLDV, GOLD_DEEP, f, true)
		rbox("PierBand", a, 49.6, 50.6, -4.2, 4.2, 44, 47.9, GOLDV, GOLD, f)
		rbox("PierStrip", a, 50, 50.4, -1, 1, 12, 44, GOLDV, GOLD, f)
		rbox("PierPanel", a, 43.6, 44, -2.5, 2.5, 14, 40, GOLDV, GOLD, f)
		rbox("PierPanel", a, 43.6, 44, -2, 2, 50, 56, GOLDV, GOLD, f)
	end
	-- tall arched windows in 9 bays (the others: the facade, the stair turrets)
	for _, k in ipairs({ 2, 3, 6, 7, 8, 9, 10, 13, 14 }) do
		local a = 22.5 * k
		rbox("WindowSill", a, 44, 48, -5.6, 5.6, FY, 12, BRICK, QUARTZ, f, true)
		for _, sx in ipairs({ -1, 1 }) do
			rbox("WindowJamb", a, 44.6, 47.6, sx * 4, sx * 5.6, 12, 54, GOLDV, GOLD, f, true)
			rbox("WindowHead", a, 44.6, 47.6, sx * 2, sx * 5.6, 54, 58, GOLDV, GOLD, f, true)
		end
		glassy(rbox("WindowGlass", a, 45.6, 46.6, -4, 4, 12, 44, nil, GLASS_WARM, f, true))
		-- the transom at the gallery level is walkable (it closes the gap between the gallery and the glass)
		rbox("WindowTransom", a, 44, 48.6, -5.6, 5.6, 44, 47.9, GOLDV, GOLD_DEEP, f, true)
		glassy(rbox("WindowGlass", a, 45.6, 46.6, -4, 4, 47.9, 54, nil, GLASS_WARM, f, true))
		glassy(rbox("WindowGlass", a, 45.6, 46.6, -2, 2, 54, 58, nil, GLASS_WARM, f, true))
		rbox("WindowTop", a, 44, 48, -5.6, 5.6, 58, 60, GOLDV, GOLD_DEEP, f, true)
	end
	-- the facade with the portal (x -12..12, y 8..40, a stepped arch)
	box("Facade", -24, FY, -72, -12, 48, -68, BRICK, QUARTZ, f)
	box("Facade", 12, FY, -72, 24, 48, -68, BRICK, QUARTZ, f)
	box("Facade", -12, 40, -72, 12, 48, -68, BRICK, QUARTZ, f)
	for _, sx in ipairs({ -1, 1 }) do
		box("FacadeArch", sx * 8, 32, -72, sx * 12, 40, -68, BRICK, QUARTZ, f)
		box("FacadeArch", sx * 4, 36, -72, sx * 8, 40, -68, BRICK, QUARTZ, f)
		-- the gold frame round the opening, the pilasters, wall lanterns
		for _, r in ipairs({
			{ 12, 14, 8, 32 },
			{ 8, 14, 32, 34 },
			{ 8, 10, 34, 36 },
			{ 4, 10, 36, 38 },
			{ 4, 6, 38, 40 },
		}) do
			decor(box("PortalFrame", sx * r[1], r[3], -68, sx * r[2], r[4], -67.6, GOLDV, GOLD, f))
		end
		decor(box("FacadePilaster", sx * 18, FY, -68, sx * 20, 60, -67.6, GOLDV, GOLD, f))
		decor(
			box("LanternBracket", sx * 15.6, 23.2, -68, sx * 16.4, 24, -66.7, GOLDV, GOLD_DEEP, f)
		)
		lantern(V(sx * 16, 22, -66.7), f)
		nLights += 1
	end
	decor(box("PortalFrame", -6, 40, -68, 6, 42, -67.6, GOLDV, GOLD, f))
	box("FacadeUpper", -24, 48, -70, 24, 60, -68, BRICK, QUARTZ, f)
	-- the observer: an iron eye in a gold ring over the portal
	decor(box("ObserverRing", -4, 56, -68, 4, 58, -66.5, GOLDV, GOLD, f))
	decor(box("ObserverRing", -4, 50, -68, 4, 52, -66.5, GOLDV, GOLD, f))
	decor(box("ObserverRing", -4, 52, -68, -2, 56, -66.5, GOLDV, GOLD, f))
	decor(box("ObserverRing", 2, 52, -68, 4, 56, -66.5, GOLDV, GOLD, f))
	local eye = decor(box("Observer", -2, 52, -68, 2, 56, -67, nil, IRON, f))
	eye.Material = Enum.Material.Metal
	decor(
		box(
			"ObserverEye",
			-1.2,
			53.6,
			-67.05,
			1.2,
			54.4,
			-66.95,
			nil,
			Color3.fromRGB(22, 22, 26),
			f
		)
	)
	decor(
		box(
			"ObserverPupil",
			-0.3,
			53.7,
			-67.1,
			0.3,
			54.3,
			-66.9,
			nil,
			Color3.fromRGB(200, 60, 40),
			f
		)
	)
end
task.wait()

-- ================================================================ the stair turrets (east and west) up to the gallery
for _, sx in ipairs({ 1, -1 }) do
	local T = folder(if sx > 0 then "StairTurretEast" else "StairTurretWest", rot)
	local function tb(name, x0, y0, z0, x1, y1, z1, variant, tint)
		return box(name, sx * x0, y0, z0, sx * x1, y1, z1, variant or BRICK, tint or QUARTZ, T)
	end
	tb("TurretBase", 44, 0, -140, 80, 6, -104)
	tb("TurretBaseCourse", 44, 6, -140, 80, FY, -104, GOLDV, GOLD_DEEP)
	-- the drum-side wall (with the filler to the drum piers): the ground door z -116..-108, the gallery door z -134..-126
	tb("TurretWall", 44, FY, -138, 52, 72, -134)
	tb("TurretWall", 44, FY, -134, 52, 44, -126)
	tb("TurretWall", 44, 60, -134, 52, 72, -126)
	tb("TurretWall", 44, FY, -126, 52, 72, -116)
	tb("TurretWall", 44, 20, -116, 52, 72, -108)
	tb("TurretWall", 44, FY, -108, 52, 72, -104)
	tb("TurretWall", 52, FY, -138, 76, 72, -134)
	tb("TurretWall", 52, FY, -108, 62, 72, -104)
	tb("TurretWall", 66, FY, -108, 76, 72, -104)
	tb("TurretWall", 62, FY, -108, 66, 20, -104)
	tb("TurretWall", 62, 36, -108, 66, 72, -104)
	tb("TurretWall", 76, FY, -138, 80, 72, -123)
	tb("TurretWall", 76, FY, -119, 80, 72, -104)
	tb("TurretWall", 76, FY, -123, 80, 24, -119)
	tb("TurretWall", 76, 40, -123, 80, 72, -119)
	glassy(tb("TurretGlass", 62, 20, -106.5, 66, 36, -105.5))
	glassy(tb("TurretGlass", 77.5, 24, -123, 78.5, 40, -119))
	tb("TurretCore", 60, FY, -126, 68, 72, -116)
	-- the bay between the drum piers at a = 112.5 under the gallery door, and the pocket beside the door
	rbox("BayWall", sx * 112.5, 44, 48, -5.6, 5.6, FY, 44, BRICK, QUARTZ, T, true)
	rbox("BayPanel", sx * 112.5, 43.6, 44, -3, 3, 14, 40, GOLDV, GOLD, T)
	tb("TurretWall", 38, GY, -138, 44, 60, -134)
	-- the passage from the top landing onto the gallery (a hair under the gallery top: no coplanar faces)
	tb("GalleryPassage", 38, 44.1, -134, 52, 47.95, -126, GOLDV, GOLD)
	-- a gold frame and a plaque round the ground door inside the rotunda
	decor(tb("DoorFrame", 43.6, FY, -117, 44, 20, -116, GOLDV, GOLD))
	decor(tb("DoorFrame", 43.6, FY, -108, 44, 20, -107, GOLDV, GOLD))
	decor(tb("DoorFrame", 43.6, 20, -117, 44, 21, -107, GOLDV, GOLD))
	local plaque = decor(tb("DoorPlaque", 43.6, 22, -114, 44, 24, -110, GOLDV, GOLD_DEEP))
	sign(plaque, "Галерея", 2, nil, 60)
	-- the spiral: five flights of 8 (rise 8) round the core, landings in the corners
	local fl = folder("GalleryStair", T)
	stairs("GalleryStair", sx * 56, -116, -126, FY, 8, 8, SMOOTH, fl)
	tb("StairLanding", 52, FY, -134, 60, 16, -126, GOLDV, GOLD)
	stairs("GalleryStair", -130, sx * 60, sx * 68, 16, 8, 8, SMOOTH, fl, "x")
	tb("StairLanding", 68, 20, -134, 76, 24, -126, GOLDV, GOLD)
	stairs("GalleryStair", sx * 72, -126, -116, 24, 8, 8, SMOOTH, fl)
	tb("StairLanding", 68, 28, -116, 76, 32, -108, GOLDV, GOLD)
	stairs("GalleryStair", -112, sx * 68, sx * 60, 32, 8, 8, SMOOTH, fl, "x")
	tb("StairLanding", 52, 36, -116, 60, 40, -108, GOLDV, GOLD)
	stairs("GalleryStair", sx * 56, -116, -126, 40, 8, 8, SMOOTH, fl)
	tb("StairLanding", 52, 44, -134, 60, GY, -126, GOLDV, GOLD)
	for _, p in ipairs(fl:GetChildren()) do
		if p.Name == "GalleryStairStep" then
			textured(p, SMOOTH, QUARTZ)
		end
	end
	decor(tb("LanternBracket", 59, 31.1, -121.4, 60, 31.9, -120.6, GOLDV, GOLD_DEEP))
	lantern(V(sx * 59.3, 30, -121), T)
	nLights += 1
	-- the roof, gold bands outside, a stepped gold cap with a finial
	tb("TurretRoof", 44, 72, -138, 80, 76, -104)
	for _, y in ipairs({ 44, 68 }) do
		decor(tb("TurretBand", 52, y, -138.4, 80.4, y + 2, -138, GOLDV, GOLD))
		decor(tb("TurretBand", 52, y, -104, 80.4, y + 2, -103.6, GOLDV, GOLD))
		decor(tb("TurretBand", 80, y, -138, 80.4, y + 2, -104, GOLDV, GOLD))
	end
	for _, c in ipairs({ { 16, 76 }, { 12, 80 }, { 8, 84 }, { 4, 88 }, { 2, 92 } }) do
		tb(
			"TurretCap",
			62 - c[1],
			c[2],
			-121 - c[1],
			62 + c[1],
			c[2] + 4,
			-121 + c[1],
			GOLDV,
			if c[1] % 8 == 0 then GOLD else GOLD_DEEP
		)
	end
	tb("TurretFinial", 61.4, 96, -121.6, 62.6, 102, -120.4, GOLDV, GOLD_DEEP)
	banner(at(sx * 70, 34, -103.5), Color3.fromRGB(250, 246, 234), T, Color3.fromRGB(236, 190, 60))
	task.wait()
end

-- ================================================================ the crown: the cornice, the ledge, pinnacles, cherubs
do
	local f = folder("Crown", rot)
	ring("Cornice", 2, 42, 52, 60, 64, GOLDV, GOLD_DEEP, f, inTurret)
	ring("LedgeRail", 2, 49, 52, 64, 66, SMOOTH, QUARTZ, f, inTurret)
	for _, a in ipairs({ 22.5, 67.5, 157.5, -22.5, -67.5, -157.5 }) do
		local x, z = CX + 48 * math.sin(a * DEG), CZ + 48 * math.cos(a * DEG)
		box("PinnacleBase", x - 4.5, 64, z - 4.5, x + 4.5, 66.5, z + 4.5, GOLDV, GOLD_DEEP, f)
		box("Pinnacle", x - 3.5, 66.5, z - 3.5, x + 3.5, 80, z + 3.5, SMOOTH, QUARTZ, f)
		decor(box("PinnacleInlay", x - 1.5, 69, z - 3.7, x + 1.5, 76, z + 3.7, GOLDV, GOLD, f))
		decor(box("PinnacleInlay", x - 3.7, 69, z - 1.5, x + 3.7, 76, z + 1.5, GOLDV, GOLD, f))
		box("PinnacleCap", x - 4.5, 80, z - 4.5, x + 4.5, 82, z + 4.5, GOLDV, GOLD_DEEP, f)
		box("PinnacleRoof", x - 3, 82, z - 3, x + 3, 86, z + 3, GOLDV, GOLD, f)
		box("PinnacleRoof", x - 1.5, 86, z - 1.5, x + 1.5, 89, z + 1.5, GOLDV, GOLD, f)
		box("PinnacleTip", x - 0.5, 89, z - 0.5, x + 0.5, 93, z + 0.5, GOLDV, GOLD_DEEP, f)
	end
	-- four six-winged cherubs on the diagonals, facing out
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		local x, z = CX + 50 * math.sin(a * DEG), CZ + 50 * math.cos(a * DEG)
		seraph(at(x, 64, z) * CFrame.Angles(0, (a + 180) * DEG, 0), f)
	end
end
task.wait()

-- ================================================================ the dome, the lantern, the halo
do
	local f = folder("Dome", rot)
	local function R(j)
		return if j > 10 then 0 else 44 * math.sqrt(1 - (4 * j / 44) ^ 2)
	end
	for j = 0, 10 do
		local y0, rOut = 64 + 4 * j, R(j)
		local rIn = if j == 10 then 11 else math.min(rOut, R(j + 1)) - 6.5
		cells(0, rOut, function(dx, dz)
			local d = math.sqrt(dx * dx + dz * dz)
			if d <= rIn or d > rOut then
				return nil
			end
			if dx == 0 or dz == 0 or math.abs(dx) == math.abs(dz) then
				return "rib"
			end
			if j == 2 or j == 3 then
				-- 16 small windows between the ribs and the bisectors (a = 11.25 + 22.5·k)
				local dev = math.abs((math.deg(math.atan2(dx, dz)) % 22.5) - 11.25)
				if d * math.sin(math.rad(dev)) < 2.2 then
					return "win"
				end
			end
			return "gold"
		end, function(kind, x0, x1, z0, z1)
			if kind == "win" then
				glassy(
					box(
						"DomeWindow",
						CX + x0,
						y0,
						CZ + z0,
						CX + x1,
						y0 + 4,
						CZ + z1,
						nil,
						GLASS_WARM,
						f
					)
				)
			else
				box(
					if kind == "rib" then "DomeRib" else "Dome",
					CX + x0,
					y0,
					CZ + z0,
					CX + x1,
					y0 + 4,
					CZ + z1,
					GOLDV,
					if kind == "rib" then GOLD_DEEP else GOLD,
					f
				)
			end
		end)
		task.wait()
	end
	-- the lantern: a gold ring over the oculus, 8 quartz columns round a glowing core, a stepped roof, a finial
	ring("LanternRing", 0, 5, 13, 108, 110, GOLDV, GOLD_DEEP, f)
	for k = 0, 7 do
		local a = 45 * k * DEG
		local x, z = CX + 9 * math.sin(a), CZ + 9 * math.cos(a)
		box("LanternColumn", x - 1, 110, z - 1, x + 1, 116, z + 1, SMOOTH, QUARTZ, f)
	end
	local core = decor(box("LanternCore", CX - 2, 111, CZ - 2, CX + 2, 115, CZ + 2, nil, LIGHT, f))
	core.Material = Enum.Material.Neon
	light(core, 60, 1.5, LIGHT)
	nLights += 1
	ring("LanternRoof", 0, -1, 11, 116, 118, GOLDV, GOLD, f)
	ring("LanternRoof", 0, -1, 7, 118, 120, GOLDV, GOLD_DEEP, f)
	ring("LanternRoof", 0, -1, 4, 120, 122, GOLDV, GOLD, f)
	box("LanternFinial", CX - 0.75, 122, CZ - 0.75, CX + 0.75, 126, CZ + 0.75, GOLDV, GOLD_DEEP, f)
	-- the halo of gold blocks with white end rods, floating above
	local halo = folder("Halo", f)
	ring("Halo", 0, 9.5, 14, 128, 130, GOLDV, GOLD, halo, nil, true)
	for k = 0, 11 do
		local a = 30 * k * DEG
		local x, z = CX + 12 * math.sin(a), CZ + 12 * math.cos(a)
		decor(
			box("EndRodBase", x - 0.6, 130, z - 0.6, x + 0.6, 130.6, z + 0.6, SMOOTH, QUARTZ, halo)
		)
		local rod = decor(
			box(
				"EndRod",
				x - 0.3,
				130.6,
				z - 0.3,
				x + 0.3,
				135,
				z + 0.3,
				nil,
				Color3.fromRGB(255, 252, 240),
				halo
			)
		)
		rod.Material = Enum.Material.Neon
		rod.CastShadow = false
	end
end
task.wait()

-- ================================================================ inside: the floor, the piers with angels, the dais and the ark
do
	local f = folder("Interior", rot)
	-- white 2-block squares on the gold course (flush, decor)
	for i = -6, 5 do
		for j = -6, 5 do
			local x, z = CX + 8 * i + 4, CZ + 8 * j + 4
			local d = math.sqrt((x - CX) ^ 2 + (z - CZ) ^ 2)
			if (i + j) % 2 == 0 and d <= 40 and not (math.abs(x) < 16 and z < -130) then
				decor(box("FloorTile", x - 4, FY, z - 4, x + 4, FY + 0.1, z + 4, SMOOTH, QUARTZ, f))
			end
		end
	end
	-- 8 massive piers with gold panels and praying angels facing the aisle
	for _, p in ipairs({ { 15, -88 }, { 26, -102 }, { 26, -124 }, { 20, -136 } }) do
		for _, sx in ipairs({ -1, 1 }) do
			local x, z = sx * p[1], p[2]
			box("InnerPierBase", x - 5, FY, z - 5, x + 5, 10, z + 5, GOLDV, GOLD_DEEP, f)
			box("InnerPier", x - 4, 10, z - 4, x + 4, 26, z + 4, SMOOTH, QUARTZ, f)
			box("InnerPierCapital", x - 5, 26, z - 5, x + 5, 28, z + 5, GOLDV, GOLD_DEEP, f)
			decor(box("InnerPierPanel", x - 2, 13, z - 4.4, x + 2, 23, z - 4, GOLDV, GOLD, f))
			decor(box("InnerPierPanel", x - 2, 13, z + 4, x + 2, 23, z + 4.4, GOLDV, GOLD, f))
			decor(box("InnerPierPanel", x - 4.4, 13, z - 2, x - 4, 23, z + 2, GOLDV, GOLD, f))
			decor(box("InnerPierPanel", x + 4, 13, z - 2, x + 4.4, 23, z + 2, GOLDV, GOLD, f))
			angel(at(x, 28, z) * CFrame.Angles(0, sx * math.pi / 2, 0), 0.95, false, f)
		end
	end
	task.wait()
	-- the stepped dais and the ark
	local ark = folder("Ark", f)
	box("Dais", -14, FY, -152, 14, 10, -132, GOLDV, GOLD_DEEP, ark)
	box("Dais", -11, 10, -152, 11, 12, -135, SMOOTH, HONEY, ark)
	box("Dais", -8, 12, -152, 8, 14, -138, GOLDV, GOLD, ark)
	box("ArkChest", -6, 14, -148, 6, 21, -140, GOLDV, GOLD, ark)
	box("ArkLid", -6.5, 21, -148.5, 6.5, 22, -139.5, GOLDV, GOLD_DEEP, ark)
	for _, y in ipairs({ 15, 19 }) do
		decor(box("ArkBand", -6.2, y, -148.2, 6.2, y + 1, -139.8, GOLDV, GOLD_DEEP, ark))
	end
	decor(box("ArkPanel", -4, 16.5, -139.9, 4, 18.5, -139.7, SMOOTH, HONEY, ark))
	decor(box("ArkPanel", -4, 16.5, -148.3, 4, 18.5, -148.1, SMOOTH, HONEY, ark))
	for _, z in ipairs({ -139.6, -148.4 }) do
		decor(
			box(
				"ArkPole",
				-10,
				16.4,
				z,
				10,
				17.2,
				z + 0.8 * (if z < -144 then -1 else 1),
				GOLDV,
				GOLD_DEEP,
				ark
			)
		)
		for _, sx in ipairs({ -1, 1 }) do
			decor(box("ArkRing", sx * 4.5, 16, z - 0.6, sx * 5.5, 17.6, z + 0.6, GOLDV, GOLD, ark))
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		kneeler(at(sx * 3.5, 22, -144) * CFrame.Angles(0, sx * math.pi / 2, 0), ark)
		-- lantern posts at the front corners, candles on the top tier
		box("DaisLanternPost", sx * 11.5, 10, -134.5, sx * 13.5, 14, -132.5, GOLDV, GOLD, ark)
		lantern(V(sx * 12.5, 14.85, -133.5), ark)
		nLights += 1
		for _, z in ipairs({ -139, -150 }) do
			decor(
				box(
					"Candle",
					sx * 7 - 0.4,
					14,
					z - 0.4,
					sx * 7 + 0.4,
					16,
					z + 0.4,
					nil,
					Color3.fromRGB(246, 240, 222),
					ark
				)
			)
			local flame = decor(
				box(
					"CandleFlame",
					sx * 7 - 0.25,
					16,
					z - 0.25,
					sx * 7 + 0.25,
					16.7,
					z + 0.25,
					nil,
					LIGHT,
					ark
				)
			)
			flame.Material = Enum.Material.Neon
		end
		-- a harp of gold with iron strings beside the dais
		local h = folder("Harp", ark)
		local x = sx * 19
		box("HarpBase", x - 1.5, FY, -151, x + 1.5, 10, -141, GOLDV, GOLD_DEEP, h)
		box("HarpPillar", x - 1, 10, -143, x + 1, 24, -141, GOLDV, GOLD, h)
		box("HarpBody", x - 1.5, 10, -151, x + 1.5, 18, -148, SMOOTH, HONEY, h)
		box("HarpBody", x - 1, 18, -151, x + 1, 21, -149, SMOOTH, HONEY, h)
		box("HarpNeck", x - 1, 21, -151, x + 1, 23, -147, GOLDV, GOLD, h)
		box("HarpNeck", x - 1, 22, -147, x + 1, 24, -143, GOLDV, GOLD, h)
		for k = 0, 4 do
			local s = decor(
				part(
					"HarpString",
					Vector3.new(0.3, 12, 0.3),
					at(x, 16, -147 + 0.8 * k),
					IRON,
					Enum.Material.Metal,
					h
				)
			)
			s.CastShadow = false
		end
	end
	task.wait()
	-- the chandelier on a chain from the lantern, 4 lanterns on chains from the dome
	do
		local c = folder("Chandelier", f)
		local y = 66
		local hub = decor(
			box("ChandelierHub", CX - 2, y, CZ - 2, CX + 2, y + 4, CZ + 2, GOLDV, GOLD_DEEP, c)
		)
		for _, r in ipairs({
			{ -8, 8, -8, -6.5 },
			{ -8, 8, 6.5, 8 },
			{ -8, -6.5, -6.5, 6.5 },
			{ 6.5, 8, -6.5, 6.5 },
		}) do
			decor(
				box(
					"ChandelierRing",
					CX + r[1],
					y + 1,
					CZ + r[3],
					CX + r[2],
					y + 2.5,
					CZ + r[4],
					GOLDV,
					GOLD,
					c
				)
			)
		end
		decor(
			box(
				"ChandelierArm",
				CX - 6.5,
				y + 1.5,
				CZ - 0.5,
				CX + 6.5,
				y + 2.2,
				CZ + 0.5,
				GOLDV,
				GOLD,
				c
			)
		)
		decor(
			box(
				"ChandelierArm",
				CX - 0.5,
				y + 1.5,
				CZ - 6.5,
				CX + 0.5,
				y + 2.2,
				CZ + 6.5,
				GOLDV,
				GOLD,
				c
			)
		)
		for _, q in ipairs({
			{ -7.25, -7.25 },
			{ 7.25, -7.25 },
			{ -7.25, 7.25 },
			{ 7.25, 7.25 },
			{ 0, -7.25 },
			{ 0, 7.25 },
			{ -7.25, 0 },
			{ 7.25, 0 },
		}) do
			local x, z = CX + q[1], CZ + q[2]
			decor(
				box(
					"ChandelierCandle",
					x - 0.5,
					y + 2.5,
					z - 0.5,
					x + 0.5,
					y + 4.5,
					z + 0.5,
					nil,
					Color3.fromRGB(246, 240, 222),
					c
				)
			)
			local flame = decor(
				box(
					"ChandelierFlame",
					x - 0.3,
					y + 4.5,
					z - 0.3,
					x + 0.3,
					y + 5.3,
					z + 0.3,
					nil,
					LIGHT,
					c
				)
			)
			flame.Material = Enum.Material.Neon
		end
		decor(box("ChandelierPendant", CX - 1, y - 3, CZ - 1, CX + 1, y, CZ + 1, GOLDV, GOLD, c))
		decor(
			box(
				"ChandelierGlow",
				CX - 1.5,
				y - 6,
				CZ - 1.5,
				CX + 1.5,
				y - 3,
				CZ + 1.5,
				"px_glowstone",
				LIGHT,
				c
			)
		)
		local chain = decor(
			box(
				"Chain",
				CX - 0.25,
				y + 4,
				CZ - 0.25,
				CX + 0.25,
				111,
				CZ + 0.25,
				nil,
				Color3.fromRGB(55, 55, 60),
				c
			)
		)
		chain.Material = Enum.Material.Metal
		light(hub, 70, 2.2, LIGHT)
		nLights += 1
		for _, a in ipairs({ 45, 135, 225, 315 }) do
			lantern(V(CX + 18 * math.sin(a * DEG), 58, CZ + 18 * math.cos(a * DEG)), c, false, 96)
			nLights += 1
		end
	end
end
task.wait()

-- ================================================================ the gallery (the SUMMIT) at y 48
do
	local f = folder("Gallery", rot)
	-- the walkway ring r 30..45 (it stops at the facade, z -72) and the balustrade on its inner edge
	ring("GalleryFloor", 2, 29.99, 45, 44, GY, GOLDV, GOLD, f, function(_, z)
		return z > -72
	end)
	ring("GalleryBalustrade", 2, 29.99, 33.5, GY, 51, GOLDV, GOLD_DEEP, f)
	ring("GalleryRail", 2, 29.99, 33.5, 51, 52, SMOOTH, QUARTZ, f)
	-- benches in four window bays
	for _, a in ipairs({ 45, 135, 225, 315 }) do
		rbox("GalleryBench", a, 40, 42.5, -3.5, 3.5, 49, 50, SMOOTH, QUARTZ, f, true)
		for _, sx in ipairs({ -1, 1 }) do
			rbox(
				"GalleryBenchLeg",
				a,
				40.4,
				42.1,
				sx * 2.4,
				sx * 3.3,
				GY,
				49,
				GOLDV,
				GOLD_DEEP,
				f,
				true
			)
		end
	end
	-- two lanterns on the balustrade, over the portal and over the ark
	for _, z in ipairs({ -82, -142 }) do
		lantern(V(CX, 52.85, z), f)
		nLights += 1
	end
end

print(("[build-cherubim] rotunda: %d parts, %d point lights"):format(count - partsBefore, nLights))
