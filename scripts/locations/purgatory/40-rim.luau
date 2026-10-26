--!nocheck
-- ================================================================ purgatory: the foot of the mountain (RIM part)
-- Zone: zoneOf(x, z) == "rim" (d ≥ 138 from PEAK outside the bay: the outer terraces L0 y 0, L1 y 8, L2 y 16),
-- under the island and the sky round it. Blocky: full 4-stud blocks, flat px_* textures, light only from the stair
-- lanterns, the arch lanterns and the braziers (≤ 20 PointLights).
-- 1. STAIRS between L0, L1 and L2 (16 wide, rising 8, kit `stairs` on an invisible ramp), found at build time by
--    scanning cellY across the edge (planStair): per side (east +x / west −x, mirrored)
--      A  L0→L1 at x ±112 (fallback ±120, ±128) climbing north across ring 200 at z ≈ 88: from the bay's south-east /
--         south-west corner (the bay floor is flush with L0 there) — a sandstone arch with red banners frames its foot
--      B  L0→L1 at z 16 (fallback 24, 8, 0) climbing toward the peak across ring 200 at x ≈ ±176
--      C  L1→L2 at x ±120 (fallback ±128, ±136) climbing north across ring 168 at z ≈ 40
--      D  L1→L2 at z -56 (fallback -64, -48, -72) climbing toward the peak across ring 168 at x ≈ ±168; on L2 the
--         walk goes on north to the fixed ring-138 stairs (x ±138, z -80, built by the mount part)
--    each: cut sandstone steps, a landing filled up to the upper terrace where the edge is ragged, stepped sandstone
--    cheek walls and a lantern post at the top.
-- 2. EDGES: cut sandstone kerbs (1 block, on the outer half of the upper cell) with gaps along the L1/L2 edges, some
--    dark oak fences, cut sandstone cornices under the edge (decor); a low red sandstone parapet with gaps along the
--    island's outer rim in places. Open at every stair and at the ring-138 landings.
-- 3. THE FOOT (freeGround only, ≥ 2 blocks of walkway along each terrace): cypresses, dead orange bushes, decorated
--    pots, benches with waiting souls, queues of souls, obelisks with red banners, fire and soul fire braziers, two
--    brazier altars, giant hourglasses, the souls' market (a red-and-white stall with pots and sandstone, no buyer),
--    scattered sandstone blocks.
-- 4. UNDER THE ISLAND: red sandstone stalactites with dark terracotta tips under the core's 8-stud columns (core's
--    rockDepth replicated), more at the rim; dark terracotta bands along the bottom of the cliff faces. decor().
-- 5. THE SKY: floating sandstone islets (stepped cones, props on top), 24+ studs off the island; sunset clouds under
--    the island and round it. Everything floating is decor.
local rimF = folder("Foot")
local R = { lights = 0, stairs = {}, taken = {}, c0 = count, placed = {} }
local PAL = {
	DARK = Color3.fromRGB(176, 140, 150), -- a tint over px_terracotta: the darker purple-brown bands
	GLASS = Color3.fromRGB(225, 240, 245),
	CLOUD = Color3.fromRGB(255, 214, 190),
	POT = Color3.fromRGB(236, 200, 180),
	WOOD = Color3.fromRGB(235, 225, 215),
}
local MAX_LIGHTS = 20

-- the core's rock depth under a cell (replicated from 10-core: it is local there)
local function rockDepth(x, z)
	local rr = math.clamp(math.sqrt((x - ISLAND.x) ^ 2 + (z - ISLAND.z) ^ 2) / ISLAND.r, 0, 1)
	local d = 20 + (1 - rr) ^ 1.2 * 150 + levelAt(x, z) * STEP_Y
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
-- the bottom of the island column under a point (nil off the island)
local function colBottom(x, z)
	local s = CELL.size
	local cx = CELL.x0 + math.floor((x - CELL.x0) / s) * s + s / 2
	local cz = CELL.z0 + math.floor((z - CELL.z0) / s) * s + s / 2
	local gy = groundY(cx, cz)
	if gy == nil then
		return nil
	end
	return gy - B - math.floor(rockDepth(cx, cz) / B + 0.5) * B
end
local function addLight(p, range, bright, color)
	if R.lights < MAX_LIGHTS then
		R.lights += 1
		light(p, range, bright, color)
	end
end
-- a kit lantern in its own folder; its light is dropped once the budget is spent
local function lamp(pos, f, soul, hangTop)
	local lf = folder("Lantern", f)
	lantern(pos, lf, soul, hangTop)
	if R.lights >= MAX_LIGHTS then
		for _, d in ipairs(lf:GetDescendants()) do
			if d:IsA("PointLight") then
				d:Destroy()
			end
		end
	else
		R.lights += 1
	end
	return lf
end
local function floatAll(f)
	for _, d in ipairs(f:GetDescendants()) do
		if d:IsA("BasePart") then
			decor(d)
		end
	end
end
local function nearStair(x, z, pad)
	for _, r in ipairs(R.stairs) do
		if x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad then
			return true
		end
	end
	return false
end
-- facing out from the mountain (a prop's front is its −Z), snapped to 90°
local function yawOut(x, z)
	local a = math.atan2(-(x - PEAK.x), -(z - PEAK.z))
	return math.floor(a / (math.pi / 2) + 0.5) * (math.pi / 2)
end

-- ================================================================ block props (y = the ground under them)
-- a waiting soul: a blocky translucent figure; cf at the feet (standing) or on the seat (sitting), facing −Z
local function soulFig(cf, f, sit)
	local sf = folder("Soul", f)
	local function sp(name, size, off)
		local p = decor(part(name, size, cf * off, SOUL, Enum.Material.SmoothPlastic, sf))
		p.Transparency = 0.5
		p.CastShadow = false
	end
	local base = 2.6
	if sit then
		sp("SoulThighs", Vector3.new(1.8, 0.9, 2.2), CFrame.new(0, 0.45, -0.8))
		sp("SoulShins", Vector3.new(1.8, 2.2, 0.9), CFrame.new(0, -1.1, -1.45))
		base = 0.9
	else
		sp("SoulLegs", Vector3.new(1.8, 2.6, 0.9), CFrame.new(0, 1.3, 0))
	end
	sp("SoulTorso", Vector3.new(2, 2.4, 1), CFrame.new(0, base + 1.2, 0))
	sp("SoulHead", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, base + 3.2, 0))
	for _, sx in ipairs({ -1.45, 1.45 }) do
		sp(
			"SoulArm",
			Vector3.new(0.85, 2.3, 0.9),
			CFrame.new(sx, base + 1.25, if sit then -0.2 else 0)
		)
	end
	return sf
end
-- a cypress: a dark oak log core under a narrow column of hedge blocks (decor leaves)
local function cypress(x, y, z, f, tall)
	local cf = folder("Cypress", f)
	textured(
		part("CypressTrunk", Vector3.new(B, 8, B), at(x, y + 4, z), nil, nil, cf),
		"px_dark_oak_log"
	)
	local h = (if tall then 4 else 3) * B
	decor(
		box("CypressLeaves", x - 6, y + 4, z - 6, x + 6, y + 4 + h, z + 6, "px_hedge", CYPRESS, cf)
	)
	local y1 = y + 4 + h
	decor(box("CypressLeaves", x - 6, y1, z - 2, x + 6, y1 + B, z + 2, "px_hedge", CYPRESS, cf))
	decor(box("CypressLeaves", x - 2, y1, z - 6, x + 2, y1 + B, z - 2, "px_hedge", CYPRESS, cf))
	decor(box("CypressLeaves", x - 2, y1, z + 2, x + 2, y1 + B, z + 6, "px_hedge", CYPRESS, cf))
	decor(
		box(
			"CypressTip",
			x - 2,
			y1 + B,
			z - 2,
			x + 2,
			y1 + B * (if tall then 3 else 2),
			z + 2,
			"px_hedge",
			CYPRESS,
			cf
		)
	)
	return cf
end
-- a dead orange bush: a block-sized fan of bare twigs
local function deadBush(x, y, z, f)
	local bf = folder("DeadBush", f)
	local a0 = rng:NextNumber(0, math.pi)
	for i = 1, 4 do
		local a = a0 + i * math.pi / 2 + rng:NextNumber(-0.35, 0.35)
		local r = rng:NextNumber(1.1, 1.8)
		local top = V(x + math.cos(a) * r, y + rng:NextNumber(2.4, 3.8), z + math.sin(a) * r)
		decor(beam("DeadBushTwig", V(x, y, z), top, 0.5, DEAD_BUSH, bf, Enum.Material.Wood))
	end
	decor(
		part(
			"DeadBushStub",
			Vector3.new(0.7, 1.6, 0.7),
			at(x, y + 0.8, z),
			DEAD_BUSH,
			Enum.Material.Wood,
			bf
		)
	)
	return bf
end
-- a decorated pot (terracotta with a pale band), sometimes with a plant
local function pot(x, y, z, f, plant)
	local pf = folder("Pot", f)
	cube("Pot", x, y + 1.6, z, 3.2, 3.2, 3.2, "px_terracotta", PAL.POT, pf)
	decor(cube("PotBand", x, y + 2.1, z, 3.4, 0.8, 3.4, "px_terracotta_pale", nil, pf))
	decor(cube("PotRim", x, y + 3.5, z, 2.4, 0.6, 2.4, "px_terracotta", PAL.POT, pf))
	if plant == 1 then
		decor(cube("PotPlant", x, y + 4.8, z, 2.4, 2, 2.4, "px_hedge", CYPRESS, pf))
	elseif plant == 2 then
		deadBush(x, y + 3.8, z, pf)
	end
	return pf
end
-- a brazier: a cut sandstone pedestal, a stone bowl and a blocky flame (fire or blue soul fire)
local function brazier(x, y, z, f, soul, lit)
	local bf = folder(if soul then "SoulBrazier" else "Brazier", f)
	local col = if soul then SOUL_FIRE else FIRE
	cube("BrazierBase", x, y + 2, z, B, B, B, "px_cut_sandstone", SAND, bf)
	cube(
		"BrazierBowl",
		x,
		y + B + 1,
		z,
		5,
		2,
		5,
		if soul then "px_soul_soil" else "px_blackstone",
		nil,
		bf
	)
	local fl = decor(
		part(
			"BrazierFire",
			Vector3.new(3, 2.4, 3),
			at(x, y + B + 3.2, z),
			col,
			Enum.Material.Neon,
			bf
		)
	)
	fl.Transparency = 0.15
	fl.CastShadow = false
	local tip = decor(
		part(
			"BrazierFlame",
			Vector3.new(1.5, 1.5, 1.5),
			at(x + 0.4, y + B + 5, z - 0.3),
			col,
			Enum.Material.Neon,
			bf
		)
	)
	tip.Transparency = 0.3
	tip.CastShadow = false
	if lit then
		addLight(fl, 28, 1.4, col)
	end
	return bf
end
-- a brazier altar (the concept's panel): a stone brick block with fire, soul fires on the front corners
local function altar(x, y, z, yaw, f)
	local af = folder("BrazierAltar", f)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	textured(
		part("AltarStep", Vector3.new(16, B, 12), cf * CFrame.new(0, 2, 0), nil, nil, af),
		"px_stone_bricks"
	)
	textured(
		part("AltarBlock", Vector3.new(8, B, 8), cf * CFrame.new(0, 6, 1), nil, nil, af),
		"px_stone_bricks"
	)
	textured(
		part("AltarBowl", Vector3.new(6, 1.6, 6), cf * CFrame.new(0, 8.8, 1), nil, nil, af),
		"px_blackstone"
	)
	local fl = decor(
		part(
			"AltarFire",
			Vector3.new(4, 3.2, 4),
			cf * CFrame.new(0, 11.2, 1),
			FIRE,
			Enum.Material.Neon,
			af
		)
	)
	fl.Transparency = 0.15
	fl.CastShadow = false
	addLight(fl, 34, 1.6, FIRE)
	for _, sx in ipairs({ -6, 6 }) do
		textured(
			part(
				"AltarSoulBowl",
				Vector3.new(3, 1, 3),
				cf * CFrame.new(sx, B + 0.5, -4),
				nil,
				nil,
				af
			),
			"px_soul_soil"
		)
		local s = decor(
			part(
				"AltarSoulFire",
				Vector3.new(2.2, 2.2, 2.2),
				cf * CFrame.new(sx, B + 2.1, -4),
				SOUL_FIRE,
				Enum.Material.Neon,
				af
			)
		)
		s.Transparency = 0.2
		s.CastShadow = false
	end
	for _, sx in ipairs({ -7, 7 }) do
		local p = (cf * CFrame.new(sx, 0, 4)).Position
		deadBush(p.X - BX, y, p.Z - BZ, af)
	end
	return af
end
-- a giant hourglass: dark oak frame, two stepped glass bulbs, sand, gold caps; hw = half width, h = height
local function hourglass(x, y, z, f, hw, h)
	local hf = folder("Hourglass", f)
	box("HourglassBase", x - hw, y, z - hw, x + hw, y + 2, z + hw, "px_dark_oak_planks", nil, hf)
	box(
		"HourglassTop",
		x - hw,
		y + h - 2,
		z - hw,
		x + hw,
		y + h,
		z + hw,
		"px_dark_oak_planks",
		nil,
		hf
	)
	decor(
		box(
			"HourglassCap",
			x - hw + 1,
			y + 2,
			z - hw + 1,
			x + hw - 1,
			y + 2.6,
			z + hw - 1,
			"px_gold_block",
			nil,
			hf
		)
	)
	decor(
		box(
			"HourglassCap",
			x - hw + 1,
			y + h - 2.6,
			z - hw + 1,
			x + hw - 1,
			y + h - 2,
			z + hw - 1,
			"px_gold_block",
			nil,
			hf
		)
	)
	decor(
		box(
			"HourglassFinial",
			x - 1.5,
			y + h,
			z - 1.5,
			x + 1.5,
			y + h + 2,
			z + 1.5,
			"px_gold_block",
			nil,
			hf
		)
	)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local px, pz = x + sx * (hw - 1.1), z + sz * (hw - 1.1)
			box(
				"HourglassPost",
				px - 0.9,
				y + 2,
				pz - 0.9,
				px + 0.9,
				y + h - 2,
				pz + 0.9,
				"px_dark_oak_log",
				nil,
				hf
			)
		end
	end
	local g = hw - 2.6
	local y0, y1, mid = y + 2.6, y + h - 2.6, y + h / 2
	local q = (y1 - y0) / 2
	local function glass(name, half, ya, yb)
		local p =
			decor(box(name, x - half, ya, z - half, x + half, yb, z + half, nil, PAL.GLASS, hf))
		p.Material = Enum.Material.Glass
		p.Transparency = 0.4
		p.CastShadow = false
	end
	glass("HourglassBulb", g, y0, mid - q * 0.4)
	glass("HourglassBulb", g * 0.55, mid - q * 0.4, mid - 1)
	glass("HourglassNeck", 1.1, mid - 1, mid + 1)
	glass("HourglassBulb", g * 0.55, mid + 1, mid + q * 0.4)
	glass("HourglassBulb", g, mid + q * 0.4, y1)
	-- the sand: a pile below, the rest above the neck and the thin stream between
	local pileTop = y0 + q * 0.4
	decor(
		box(
			"HourglassSand",
			x - g + 0.3,
			y0,
			z - g + 0.3,
			x + g - 0.3,
			pileTop,
			z + g - 0.3,
			"px_sand",
			nil,
			hf
		)
	)
	decor(
		box(
			"HourglassSand",
			x - g * 0.4,
			pileTop,
			z - g * 0.4,
			x + g * 0.4,
			pileTop + 1.6,
			z + g * 0.4,
			"px_sand",
			nil,
			hf
		)
	)
	local a = g * 0.55 - 0.3
	decor(
		box("HourglassSand", x - a, mid + 1, z - a, x + a, mid + q * 0.4, z + a, "px_sand", nil, hf)
	)
	decor(
		box(
			"HourglassStream",
			x - 0.3,
			pileTop + 1.6,
			z - 0.3,
			x + 0.3,
			mid + 1,
			z + 0.3,
			"px_sand",
			nil,
			hf
		)
	)
	return hf
end
-- an obelisk with red banners on its faces
local function obelisk(x, y, z, f, nb)
	local of = folder("Obelisk", f)
	box("ObeliskBase", x - 6, y, z - 6, x + 6, y + B, z + 6, "px_cut_sandstone", SAND, of)
	box("ObeliskShaft", x - 4, y + B, z - 4, x + 4, y + 28, z + 4, "px_sandstone", SAND_PALE, of)
	box("ObeliskCollar", x - 5, y + 28, z - 5, x + 5, y + 30, z + 5, "px_cut_sandstone", SAND, of)
	box("ObeliskCap", x - 3, y + 30, z - 3, x + 3, y + 33, z + 3, "px_cut_sandstone", SAND_PALE, of)
	decor(
		box(
			"ObeliskTip",
			x - 1.2,
			y + 33,
			z - 1.2,
			x + 1.2,
			y + 35.4,
			z + 1.2,
			"px_gold_block",
			nil,
			of
		)
	)
	local faces = {
		CFrame.new(0, 0, -4.15),
		CFrame.new(0, 0, 4.15),
		CFrame.new(-4.15, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
		CFrame.new(4.15, 0, 0) * CFrame.Angles(0, math.pi / 2, 0),
	}
	for i = 1, nb or 2 do
		banner(at(x, y + 17, z) * faces[i], BANNER_RED, of, GOLD, B, 12)
	end
	return of
end
-- a bench (front −Z) with waiting souls on it and pots at the ends
local function bench(x, y, z, yaw, f, souls)
	local bf = folder("Bench", f)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	for _, sx in ipairs({ -3.4, 3.4 }) do
		textured(
			part("BenchLeg", Vector3.new(1.2, 2, 2.6), cf * CFrame.new(sx, 1, 0), nil, nil, bf),
			"px_dark_oak_planks"
		)
	end
	textured(
		part("BenchSeat", Vector3.new(8, 0.6, 3), cf * CFrame.new(0, 2.3, 0), nil, nil, bf),
		"px_spruce_planks",
		PAL.WOOD
	)
	textured(
		part("BenchBack", Vector3.new(8, 2, 0.6), cf * CFrame.new(0, 3.6, 1.2), nil, nil, bf),
		"px_spruce_planks",
		PAL.WOOD
	)
	local spots = { -2, 2 }
	for i = 1, souls or 0 do
		soulFig(cf * CFrame.new(spots[i], 2.6, -0.1), bf, true)
	end
	return bf, cf
end
-- a broken sandstone arch (a whole pillar, a snapped one, half a lintel, a red banner); alongX: the span axis
local function brokenArch(x, y, z, f, alongX)
	local af = folder("BrokenArch", f)
	local function ab(name, u0, y0, u1, y1, v, tint)
		if alongX then
			return box(name, x + u0, y + y0, z - 2, x + u1, y + y1, z + 2, v, tint, af)
		end
		return box(name, x - 2, y + y0, z + u0, x + 2, y + y1, z + u1, v, tint, af)
	end
	ab("ArchPillar", -8, 0, -4, 16, "px_cut_sandstone", SAND)
	ab("ArchPillar", 4, 0, 8, rng:NextInteger(1, 2) * B, "px_cut_sandstone", SAND)
	ab("ArchLintel", -8, 16, 0, 20, "px_sandstone", SAND)
	local bcf = if alongX
		then at(x - 6, y + 10, z - 2.15)
		else at(x - 2.15, y + 10, z - 6) * CFrame.Angles(0, math.pi / 2, 0)
	banner(bcf, BANNER_RED, af, GOLD)
	return af
end
-- free ground for a prop of the foot: rim zone, freeGround, off the stairs, apart from the other props
local function spotOk(x, z, pad, rad)
	if zoneOf(x, z) ~= "rim" or not freeGround(x, z, pad) or nearStair(x, z, 10 + pad) then
		return false
	end
	for _, t in ipairs(R.taken) do
		if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < (rad + t[3]) ^ 2 then
			return false
		end
	end
	return true
end

-- ================================================================ 1. the stairs between L0, L1 and L2
do
	local stairF = folder("Stairs", rimF)
	-- plan one stair across the edge of ring `ring` from level lowL: axis "x" (u = x, l = z) or "z" (u = z, l = x),
	-- climbing toward s (±1 along u), centred on the lateral line c (a multiple of 8: two cells wide). Scans the
	-- two cell strips from 24 studs outside the edge inward for the first upper cell; the stair's top meets the
	-- outermost edge, the deeper strip gets a landing filled up to the upper terrace.
	local function planStair(axis, s, c, lowL, ring)
		local lowY = lowL * STEP_Y
		local upY = lowY + STEP_Y
		local function XZ(u, l)
			if axis == "x" then
				return u, l
			end
			return l, u
		end
		local function Y(u, l)
			local x, z = XZ(u, l)
			return cellY(x, z)
		end
		local off = c - (if axis == "x" then PEAK.z else PEAK.x)
		if math.abs(off) >= ring then
			return nil
		end
		local ue = (if axis == "x" then PEAK.x else PEAK.z) - s * math.sqrt(ring * ring - off * off)
		local u0 = math.floor((ue - s * 24) / 8) * 8 + 4
		local e = {}
		for i, l in ipairs({ c - 4, c + 4 }) do
			local u = u0
			for k = 0, 8 do
				local cy = Y(u, l)
				if cy == upY then
					if k == 0 then
						return nil
					end
					e[i] = u - s * 4
					break
				elseif cy ~= lowY then
					return nil
				end
				u += s * 8
			end
			if not e[i] then
				return nil
			end
		end
		if math.abs(e[1] - e[2]) > 16 then
			return nil
		end
		local t = if s < 0 then math.max(e[1], e[2]) else math.min(e[1], e[2])
		local deep = if s < 0 then math.min(e[1], e[2]) else math.max(e[1], e[2])
		for _, du in ipairs({ 4, 12, 20, 26 }) do
			for _, l in ipairs({ c - 4, c + 4 }) do
				if Y(t - s * du, l) ~= lowY then
					return nil
				end
			end
			for _, l in ipairs({ c - 10, c + 10 }) do
				local x, z = XZ(t - s * du, l)
				if Y(t - s * du, l) == nil or not onIsland(x, z, 2) then
					return nil
				end
			end
		end
		for _, du in ipairs({ -4, 0, 8, 16, 24, 28 }) do
			for _, l in ipairs({ c - 12, c, c + 12 }) do
				local x, z = XZ(t - s * du, l)
				if zoneOf(x, z) ~= "rim" or onRingStair(x, z, 4) then
					return nil
				end
			end
		end
		for _, l in ipairs({ c - 12, c + 12 }) do
			local x, z = XZ(t - s * 28, l)
			if not onIsland(x, z, 4) then
				return nil
			end
		end
		local ax, az = XZ(t - s * 28, c - 12)
		local bx, bz = XZ(deep, c + 12)
		local rect = { math.min(ax, bx), math.min(az, bz), math.max(ax, bx), math.max(az, bz) }
		for _, r in ipairs(R.stairs) do
			if
				rect[1] <= r[3] + 8
				and rect[3] >= r[1] - 8
				and rect[2] <= r[4] + 8
				and rect[4] >= r[2] - 8
			then
				return nil
			end
		end
		return {
			axis = axis,
			s = s,
			c = c,
			t = t,
			e = e,
			lowY = lowY,
			upY = upY,
			rect = rect,
			XZ = XZ,
		}
	end
	local function buildStair(p, name, withArch)
		local f = folder("Stair" .. name, stairF)
		local s, c, t, lowY, upY, XZ = p.s, p.c, p.t, p.lowY, p.upY, p.XZ
		local function bx(nm, u0, y0, l0, u1, y1, l1, v, tint)
			local x0, z0 = XZ(u0, l0)
			local x1, z1 = XZ(u1, l1)
			return box(nm, x0, y0, z0, x1, y1, z1, v, tint, f)
		end
		stairs(name, c, t - s * 16, t, lowY, STEP_Y, STAIR_W, "px_cut_sandstone", f, p.axis)
		-- the landing filled up to the upper terrace in front of the deeper strip
		for i, l in ipairs({ c - 4, c + 4 }) do
			if p.e[i] ~= t then
				bx("StairLanding", t, lowY, l - 4, p.e[i], upY, l + 4, "px_cut_sandstone", SAND)
			end
		end
		-- stepped cheek walls (1 block wide, 4..8 studs above the steps) and a lantern post on the top end
		for _, sg in ipairs({ -1, 1 }) do
			local l0, l1 = c + sg * 8, c + sg * 12
			bx(
				"StairCheek",
				t - s * 16,
				lowY - B,
				l0,
				t - s * 8,
				lowY + 8,
				l1,
				"px_cut_sandstone",
				SAND
			)
			bx("StairCheek", t - s * 8, lowY - B, l0, t, lowY + 12, l1, "px_sandstone", SAND)
		end
		local px, pz = XZ(t - s * 2, c + 10)
		textured(
			part("LanternPost", Vector3.new(1, 3, 1), at(px, upY + 5.5, pz), nil, nil, f),
			"px_dark_oak_log"
		)
		lamp(V(px, upY + 7.8, pz), f)
		if withArch then
			-- a sandstone arch with red banners over the foot of the stair (the concept's small panel)
			local a0, a1 = t - s * 24, t - s * 28
			local ok = true
			for _, sg in ipairs({ -1, 1 }) do
				local x, z = XZ((a0 + a1) / 2, c + sg * 10)
				if cellY(x, z) ~= lowY then
					ok = false
				end
			end
			if ok then
				for _, sg in ipairs({ -1, 1 }) do
					bx(
						"ArchPillar",
						a0,
						lowY,
						c + sg * 8,
						a1,
						lowY + 16,
						c + sg * 12,
						"px_cut_sandstone",
						SAND
					)
					bx(
						"ArchCapital",
						a0 + s,
						lowY + 14,
						c + sg * 7,
						a1 - s,
						lowY + 16,
						c + sg * 13,
						"px_sandstone",
						SAND
					)
					for _, side in ipairs({ a0, a1 }) do
						local off = if side == a1 then -s * 0.15 else s * 0.15
						local x, z = XZ(side + off, c + sg * 10)
						local cf = at(x, lowY + 8, z)
						if p.axis == "x" then
							cf *= CFrame.Angles(0, math.pi / 2, 0)
						end
						banner(cf, BANNER_RED, f, GOLD)
					end
				end
				bx(
					"ArchLintel",
					a0,
					lowY + 16,
					c - 12,
					a1,
					lowY + 20,
					c + 12,
					"px_cut_sandstone",
					SAND
				)
				bx("ArchTop", a0, lowY + 20, c - 8, a1, lowY + 24, c + 8, "px_sandstone", SAND)
				bx(
					"ArchKey",
					a0,
					lowY + 24,
					c - 2,
					a1,
					lowY + 28,
					c + 2,
					"px_cut_sandstone",
					SAND_PALE
				)
				local lx, lz = XZ((a0 + a1) / 2, c)
				lamp(V(lx, lowY + 12.5, lz), f, false, lowY + 16)
			end
		end
		table.insert(R.stairs, p.rect)
		table.insert(R.placed, ("%s(%s %d,%d)"):format(name, p.axis, p.c, p.t))
	end
	-- the candidates per side (east = +1; the west mirrors x): name, axis, s (east), lateral lines (east), lowL,
	-- ring, arch at the foot
	local CAND = {
		{ "A", "z", -1, { 112, 120, 128 }, 0, 200, true },
		{ "B", "x", -1, { 16, 24, 8, 0 }, 0, 200, false },
		{ "C", "z", -1, { 120, 128, 136 }, 1, 168, false },
		{ "D", "x", -1, { -56, -64, -48, -72 }, 1, 168, false },
	}
	for _, side in ipairs({ 1, -1 }) do
		for _, cd in ipairs(CAND) do
			local axis = cd[2]
			local s = if axis == "x" then cd[3] * side else cd[3]
			local done = false
			for _, cc in ipairs(cd[4]) do
				local c = if axis == "z" then cc * side else cc
				local p = planStair(axis, s, c, cd[5], cd[6])
				if p then
					buildStair(p, cd[1] .. (if side > 0 then "E" else "W"), cd[7])
					done = true
					break
				end
			end
			if not done then
				warn(("[build-purgatory] rim: no place for stair %s side %d"):format(cd[1], side))
			end
		end
	end
	print(("[build-purgatory] rim: stairs %s"):format(table.concat(R.placed, " ")))
end
task.wait()

-- ================================================================ 2. terrace edges and the outer parapet
do
	local edgeF = folder("Edges", rimF)
	local C = CELL.size
	local DIRS = { { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } } -- sides 1 −x, 2 +x, 3 −z, 4 +z
	local kerbs, fences, cornices, parapets = 0, 0, 0, 0
	-- the kerb blocks on the outer quarters of a cell, merged: rows (along x) first, then columns
	local function quarters(cx, cz, y, q, v, tint)
		local used = { { false, false }, { false, false } }
		local x0, z0 = cx - 4, cz - 4
		for qz = 0, 1 do
			if q[1][qz + 1] and q[2][qz + 1] then
				box("Kerb", x0, y, z0 + qz * 4, x0 + 8, y + B, z0 + qz * 4 + 4, v, tint, edgeF)
				used[1][qz + 1], used[2][qz + 1] = true, true
				kerbs += 1
			end
		end
		for qx = 0, 1 do
			local a, b = q[qx + 1][1] and not used[qx + 1][1], q[qx + 1][2] and not used[qx + 1][2]
			if a and b then
				box("Kerb", x0 + qx * 4, y, z0, x0 + qx * 4 + 4, y + B, z0 + 8, v, tint, edgeF)
				kerbs += 1
			else
				for qz = 0, 1 do
					if (qz == 0 and a) or (qz == 1 and b) then
						box(
							"Kerb",
							x0 + qx * 4,
							y,
							z0 + qz * 4,
							x0 + qx * 4 + 4,
							y + B,
							z0 + qz * 4 + 4,
							v,
							tint,
							edgeF
						)
						kerbs += 1
					end
				end
			end
		end
	end
	local function markSide(q, side)
		if side == 1 then
			q[1][1], q[1][2] = true, true
		elseif side == 2 then
			q[2][1], q[2][2] = true, true
		elseif side == 3 then
			q[1][1], q[2][1] = true, true
		else
			q[1][2], q[2][2] = true, true
		end
	end
	for z = CELL.z0, 240 - C, C do
		for x = CELL.x0, 232 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			local y = cellY(cx, cz)
			if
				y
				and zoneOf(cx, cz) == "rim"
				and not nearStair(cx, cz, 8)
				and not onRingStair(cx, cz, 6)
			then
				local edgeSides, rimSides = {}, {}
				for i, d in ipairs(DIRS) do
					local nx, nz = cx + d[1] * C, cz + d[2] * C
					local ny = cellY(nx, nz)
					if ny == nil then
						table.insert(rimSides, i)
					elseif ny == y - STEP_Y and zoneOf(nx, nz) == "rim" then
						table.insert(edgeSides, i)
					end
				end
				local q = { { false, false }, { false, false } }
				local any, kerbV, kerbT = false, "px_cut_sandstone", SAND
				-- the terrace edge: kerb, fence or a gap (noise runs), a cornice under it
				if #edgeSides > 0 then
					local n = n2(cx, cz, 5.1, 0.035)
					local style = if n > 0.16 or rng:NextNumber() < 0.12
						then "gap"
						elseif n < -0.18 and #edgeSides == 1 then "fence"
						else "kerb"
					for _, side in ipairs(edgeSides) do
						if style == "kerb" then
							markSide(q, side)
							any = true
						elseif style == "fence" then
							local d = DIRS[side]
							local lx, lz = cx + d[1] * 3, cz + d[2] * 3
							if d[1] ~= 0 then
								fence(lx, cz - 3.4, lx, cz + 3.4, edgeF, y)
							else
								fence(cx - 3.4, lz, cx + 3.4, lz, edgeF, y)
							end
							fences += 1
						end
					end
					if #edgeSides == 1 and rng:NextNumber() < 0.6 then
						local d = DIRS[edgeSides[1]]
						if d[1] ~= 0 then
							local fx = cx + d[1] * 4
							decor(
								box(
									"Cornice",
									fx,
									y - 2,
									cz - 4,
									fx + d[1] * 1.5,
									y,
									cz + 4,
									"px_cut_sandstone",
									SAND,
									edgeF
								)
							)
						else
							local fz = cz + d[2] * 4
							decor(
								box(
									"Cornice",
									cx - 4,
									y - 2,
									fz,
									cx + 4,
									y,
									fz + d[2] * 1.5,
									"px_cut_sandstone",
									SAND,
									edgeF
								)
							)
						end
						cornices += 1
					end
				end
				-- the island's outer rim: a low parapet in places
				if #rimSides > 0 and n2(cx, cz, 9.3, 0.02) > -0.08 and rng:NextNumber() > 0.2 then
					for _, side in ipairs(rimSides) do
						markSide(q, side)
					end
					if not any and y <= STEP_Y then
						kerbV, kerbT = "px_cut_red_sandstone", RED_SAND
					end
					any = true
					parapets += 1
				end
				if any then
					quarters(cx, cz, y, q, kerbV, kerbT)
				end
			end
		end
		if z % 64 == 0 then
			task.wait()
		end
	end
	print(
		("[build-purgatory] rim: kerb blocks %d, fences %d, cornices %d, parapet cells %d"):format(
			kerbs,
			fences,
			cornices,
			parapets
		)
	)
end
task.wait()

-- ================================================================ 3. the foot: props on the free ground
do
	local footF = folder("Props", rimF)
	local c0 = count
	local made = {}
	local function sample(x0, x1, z0, z1)
		return math.floor(rng:NextNumber(x0, x1) / B) * B + 2,
			math.floor(rng:NextNumber(z0, z1) / B) * B + 2
	end
	-- n props of one kind: fn(x, y, z) on free spots (pad: the freeGround pad, rad: the spacing radius)
	local function scatter(kind, n, pad, rad, fn, area)
		area = area or { CELL.x0, 232, CELL.z0, 240 }
		local k = 0
		for i = 1, n * 60 do
			if k >= n then
				break
			end
			local x, z = sample(area[1], area[2], area[3], area[4])
			if spotOk(x, z, pad, rad) then
				fn(x, cellY(x, z), z)
				table.insert(R.taken, { x, z, rad })
				k += 1
			end
			if i % 200 == 0 then
				task.wait()
			end
		end
		made[kind] = k
	end
	-- the souls' market: a second red-and-white stall with pots and sandstone, no buyer, souls in front
	do
		local mf = folder("SoulsMarket", footF)
		local ok = false
		for _, area in ipairs({
			{ -210, -100, 60, 200 },
			{ 100, 210, 60, 200 },
			{ CELL.x0, 232, CELL.z0, 240 },
		}) do
			for _ = 1, 300 do
				local x, z = sample(area[1], area[2], area[3], area[4])
				if spotOk(x, z, 12, 18) then
					local y = cellY(x, z)
					local yaw = yawOut(x, z) + math.pi
					local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
					stall(cf, {
						w = 4 * B,
						d = 2 * B,
						colA = Color3.fromRGB(200, 45, 40),
						colB = Color3.fromRGB(240, 236, 226),
						goods = {
							"px_terracotta",
							"px_sandstone",
							"px_terracotta_pale",
							"px_cut_sandstone",
						},
					}, mf)
					local function rel(dx, dz)
						local p = (cf * CFrame.new(dx, 0, dz)).Position
						return p.X - BX, p.Z - BZ
					end
					local px, pz = rel(-10, 2)
					pot(px, y, pz, mf, 1)
					px, pz = rel(-10, -2)
					pot(px, y, pz, mf, 0)
					px, pz = rel(10, 0)
					barrel(px, y, pz, mf, "px_sand")
					px, pz = rel(10, 4.5)
					crate(px, y, pz, mf)
					px, pz = rel(-9, 6)
					box(
						"MarketBlock",
						px - 2,
						y,
						pz - 2,
						px + 2,
						y + B,
						pz + 2,
						"px_sandstone",
						SAND,
						mf
					)
					box(
						"MarketBlock",
						px - 2,
						y + B,
						pz - 2,
						px + 2,
						y + 2 * B,
						pz + 2,
						"px_cut_sandstone",
						SAND,
						mf
					)
					-- souls queueing at the counter (nobody behind it)
					for i, d in ipairs({ { 0, -8 }, { 1, -12 }, { -1, -16 } }) do
						soulFig(
							cf * CFrame.new(d[1] * 1.5, 0, d[2]) * CFrame.Angles(0, math.pi, 0),
							mf,
							false
						)
						if i == 3 then
							local p = (cf * CFrame.new(5, 0, -10)).Position
							pot(p.X - BX, y, p.Z - BZ, mf, 2)
						end
					end
					table.insert(R.taken, { x, z, 18 })
					ok = true
					break
				end
			end
			if ok then
				break
			end
		end
		made.market = if ok then 1 else 0
	end
	-- two brazier altars, the giant hourglasses, the obelisks
	scatter("altar", 2, 10, 12, function(x, y, z)
		altar(x, y, z, yawOut(x, z), footF)
	end)
	scatter("hourglass", 2, 12, 16, function(x, y, z)
		hourglass(x, y, z, footF, 8, 32)
	end)
	scatter("obelisk", 8, 8, 12, function(x, y, z)
		obelisk(x, y, z, footF, rng:NextInteger(2, 4))
	end)
	-- fire braziers in pairs along the terraces, a few soul braziers
	scatter("brazier", 10, 6, 10, function(x, y, z)
		brazier(x, y, z, footF, false, true)
	end)
	scatter("soulBrazier", 5, 6, 10, function(x, y, z)
		brazier(x, y, z, footF, true, true)
	end)
	-- benches with souls, pots at the ends, sometimes a banner pole behind
	scatter("bench", 9, 8, 10, function(x, y, z)
		local _, cf = bench(x, y, z, yawOut(x, z), footF, rng:NextInteger(0, 2))
		if rng:NextNumber() < 0.7 then
			local p = (cf * CFrame.new(6, 0, 0)).Position
			pot(p.X - BX, y, p.Z - BZ, footF, rng:NextInteger(0, 2))
		end
		if rng:NextNumber() < 0.4 then
			local p = (cf * CFrame.new(-6, 0, 0)).Position
			pot(p.X - BX, y, p.Z - BZ, footF, 1)
		end
		if rng:NextNumber() < 0.5 then
			textured(
				part(
					"BannerPost",
					Vector3.new(1, 12, 1),
					cf * CFrame.new(0, 6, 3.2),
					nil,
					nil,
					footF
				),
				"px_dark_oak_log"
			)
			banner(cf * CFrame.new(0, 7, 2.6), BANNER_RED, footF, GOLD)
		end
	end)
	-- queues of souls waiting, facing the mountain
	scatter("queue", 6, 8, 10, function(x, y, z)
		local yaw = yawOut(x, z) + math.pi
		local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
		for i = 0, rng:NextInteger(2, 3) do
			soulFig(cf * CFrame.new(rng:NextNumber(-0.4, 0.4), 0, -4 + i * 3), footF, false)
		end
	end)
	scatter("cypress", 34, 6, 7, function(x, y, z)
		cypress(x, y, z, footF, rng:NextNumber() < 0.4)
	end)
	scatter("bush", 30, 4, 4, function(x, y, z)
		deadBush(x, y, z, footF)
	end)
	scatter("pot", 18, 4, 4, function(x, y, z)
		pot(x, y, z, footF, rng:NextInteger(0, 2))
		if rng:NextNumber() < 0.5 then
			pot(x + 4, y, z + rng:NextInteger(-1, 1), footF, 0)
		end
	end)
	-- scattered sandstone blocks
	scatter("blocks", 22, 4, 5, function(x, y, z)
		local v = pick({ "px_sandstone", "px_cut_sandstone", "px_red_sandstone", "px_sandstone" })
		local t = if v == "px_red_sandstone" then RED_SAND else SAND
		box("LooseBlock", x - 2, y, z - 2, x + 2, y + B, z + 2, v, t, footF)
		if rng:NextNumber() < 0.45 then
			local o = pick({ { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } })
			local dx, dz = o[1], o[2]
			box("LooseBlock", x - 2 + dx, y, z - 2 + dz, x + 2 + dx, y + B, z + 2 + dz, v, t, footF)
			if rng:NextNumber() < 0.5 then
				box(
					"LooseBlock",
					x - 2,
					y + B,
					z - 2,
					x + 2,
					y + 2 * B,
					z + 2,
					"px_cut_sandstone",
					SAND,
					footF
				)
			end
		end
	end)
	local parts = {}
	for k, v in pairs(made) do
		table.insert(parts, k .. " " .. v)
	end
	table.sort(parts)
	print(
		("[build-purgatory] rim: foot %s; %d parts"):format(table.concat(parts, ", "), count - c0)
	)
end
task.wait()

-- ================================================================ 4. under the island: stalactites and cliff bands
do
	local hang = folder("Stalactites", rimF)
	local c0 = count
	local C = CELL.size
	local cols = 0
	local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	-- one hanging column s studs square, top at `top`, len long: red sandstone with a dark terracotta tip
	local function column(x0, z0, s, top, len)
		if len >= 3 * B then
			local dark = rng:NextInteger(1, 2) * B
			decor(
				box(
					"Stalactite",
					x0,
					top - len + dark,
					z0,
					x0 + s,
					top,
					z0 + s,
					"px_red_sandstone",
					RED_SAND,
					hang
				)
			)
			decor(
				box(
					"StalactiteTip",
					x0,
					top - len,
					z0,
					x0 + s,
					top - len + dark,
					z0 + s,
					"px_terracotta",
					PAL.DARK,
					hang
				)
			)
		else
			local dark = rng:NextNumber() < 0.4
			decor(
				box(
					"Stalactite",
					x0,
					top - len,
					z0,
					x0 + s,
					top,
					z0 + s,
					if dark then "px_terracotta" else "px_red_sandstone",
					if dark then PAL.DARK else RED_SAND,
					hang
				)
			)
		end
		cols += 1
	end
	for z = CELL.z0, 240 - C, C do
		for x = CELL.x0, 232 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			local gy = groundY(cx, cz)
			if gy ~= nil and count - c0 < 720 then
				local bottom = gy - B - math.floor(rockDepth(cx, cz) / B + 0.5) * B
				local outX, outZ, rim = 0, 0, false
				for _, d in ipairs(DIRS4) do
					if groundY(cx + d[1] * C, cz + d[2] * C) == nil then
						rim = true
						outX += d[1]
						outZ += d[2]
					end
				end
				if rng:NextNumber() < (if rim then 0.55 else 0.1) then
					if not rim and rng:NextNumber() < 0.45 then
						-- a fat 2×2 column with a 1×1 tip under one quarter
						local len = rng:NextInteger(2, 6) * B
						column(x, z, 2 * B, bottom + 2, len + 2)
						if rng:NextNumber() < 0.7 then
							column(
								x + rng:NextInteger(0, 1) * B,
								z + rng:NextInteger(0, 1) * B,
								B,
								bottom - len,
								rng:NextInteger(1, 4) * B
							)
						end
					else
						local qx = if outX > 0
							then 1
							elseif outX < 0 then 0
							else rng:NextInteger(0, 1)
						local qz = if outZ > 0
							then 1
							elseif outZ < 0 then 0
							else rng:NextInteger(0, 1)
						local len = if rim then rng:NextInteger(3, 12) else rng:NextInteger(2, 7)
						column(x + qx * B, z + qz * B, B, bottom + 2, len * B + 2)
						if rim and len > 4 and rng:NextNumber() < 0.35 then
							local q2x, q2z = 1 - qx, qz
							if outX == 0 then
								q2x, q2z = qx, 1 - qz
							end
							column(
								x + q2x * B,
								z + q2z * B,
								B,
								bottom + 2,
								rng:NextInteger(2, len - 2) * B + 2
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
	-- the darker band along the bottom of the cliff faces (rim columns), merged along straight runs
	local bands = 0
	local function bandPass(alongX)
		for a = (if alongX then CELL.z0 else CELL.x0), (if alongX then 240 else 232) - C, C do
			local ac = a + C / 2
			for _, sg in ipairs({ -1, 1 }) do
				local runStart, runBottom = nil, nil
				local function flush(endB)
					if runStart and runBottom then
						local face = ac + sg * 4
						if alongX then
							decor(
								box(
									"CliffBand",
									runStart,
									runBottom - 0.5,
									face - 0.5,
									endB,
									runBottom + 8,
									face + 0.5,
									"px_terracotta",
									PAL.DARK,
									hang
								)
							)
						else
							decor(
								box(
									"CliffBand",
									face - 0.5,
									runBottom - 0.5,
									runStart,
									face + 0.5,
									runBottom + 8,
									endB,
									"px_terracotta",
									PAL.DARK,
									hang
								)
							)
						end
						bands += 1
					end
					runStart = nil
				end
				local b0, b1 = (if alongX then CELL.x0 else CELL.z0), (if alongX then 232 else 240)
				for b = b0, b1 - C, C do
					local bc = b + C / 2
					local cx, cz, nx, nz
					if alongX then
						cx, cz, nx, nz = bc, ac, bc, ac + sg * C
					else
						cx, cz, nx, nz = ac, bc, ac + sg * C, bc
					end
					local gy = groundY(cx, cz)
					local bottom = nil
					if gy ~= nil and groundY(nx, nz) == nil then
						local d = math.floor(rockDepth(cx, cz) / B + 0.5) * B
						if d > 24 then
							bottom = gy - B - d
						end
					end
					if not (bottom and runStart and bottom == runBottom) then
						flush(b)
						if bottom then
							runStart, runBottom = b, bottom
						end
					end
				end
				flush(b1)
			end
		end
	end
	bandPass(true)
	task.wait()
	bandPass(false)
	print(
		("[build-purgatory] rim: stalactites %d, cliff bands %d, %d parts"):format(
			cols,
			bands,
			count - c0
		)
	)
end
task.wait()

-- ================================================================ 5. the sky: floating islets and sunset clouds
do
	local fly = folder("FloatingIslets", rimF)
	local c0 = count
	local taken = {} -- { x, z, half, y0, y1 }
	-- far enough from the island (24+ studs horizontally) and from the other islets
	local function findSpot(half, down, up, yMin, yMax)
		for attempt = 1, 400 do
			if attempt % 100 == 0 then
				task.wait()
			end
			local x, z = rng:NextNumber(-380, 380), rng:NextNumber(-360, 380)
			local y = rng:NextNumber(yMin, yMax)
			local dc = math.sqrt((x - ISLAND.x) ^ 2 + (z - ISLAND.z) ^ 2)
			local ok = dc > ISLAND.r + 9 + 24 + half * 1.42
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
	-- one islet: top w × d blocks, (x, y, z) = the centre of its top surface
	local function islet(x, y, z, w, d, layers)
		local cf = folder("Islet", fly)
		local hx, hz = w * B / 2, d * B / 2
		local red = rng:NextNumber() < 0.4
		box(
			"IsletTop",
			x - hx,
			y - B,
			z - hz,
			x + hx,
			y,
			z + hz,
			if red then "px_red_sand" else "px_sand",
			nil,
			cf
		)
		local function sideBox(name, side, a, len, top, v, t)
			local ax0, az0
			if side == 1 then
				ax0, az0 = x - hx, z - hz + a * B
			elseif side == 2 then
				ax0, az0 = x + hx - B, z - hz + a * B
			elseif side == 3 then
				ax0, az0 = x - hx + a * B, z - hz
			else
				ax0, az0 = x - hx + a * B, z + hz - B
			end
			box(name, ax0, top - len, az0, ax0 + B, top, az0 + B, v, t, cf)
		end
		-- a ragged nub on one top edge
		if rng:NextNumber() < 0.5 then
			local side = rng:NextInteger(1, 4)
			local along = if side <= 2 then d else w
			local a = rng:NextInteger(0, along - 1)
			local ox = if side == 1 then -B elseif side == 2 then B else 0
			local oz = if side == 3 then -B elseif side == 4 then B else 0
			local ax0, az0
			if side <= 2 then
				ax0, az0 = (if side == 1 then x - hx else x + hx - B) + ox, z - hz + a * B
			else
				ax0, az0 = x - hx + a * B, (if side == 3 then z - hz else z + hz - B) + oz
			end
			box(
				"IsletTop",
				ax0,
				y - B,
				az0,
				ax0 + B,
				y,
				az0 + B,
				if red then "px_red_sand" else "px_sand",
				nil,
				cf
			)
		end
		-- the stepped layers: sandstone above, red sandstone below, a dark terracotta tip
		local yTop, total = y - B, B
		local ix0, ix1, iz0, iz1 = 0, w, 0, d
		for k = 1, layers do
			local f01 = 1 - k / (layers + 1)
			local lw = math.min(math.max(1, math.floor(w * f01 + 0.5)), ix1 - ix0)
			local ld = math.min(math.max(1, math.floor(d * f01 + 0.5)), iz1 - iz0)
			local sx = math.clamp(
				ix0 + math.floor((ix1 - ix0 - lw) / 2 + rng:NextNumber(-0.5, 0.99)),
				ix0,
				ix1 - lw
			)
			local sz = math.clamp(
				iz0 + math.floor((iz1 - iz0 - ld) / 2 + rng:NextNumber(-0.5, 0.99)),
				iz0,
				iz1 - ld
			)
			local hgt = if w >= 5 and rng:NextNumber() < 0.5 then 2 * B else B
			local v, t = "px_sandstone", SAND
			if red or k > layers * 0.4 then
				v, t = "px_red_sandstone", RED_SAND
			end
			if k == layers and layers >= 3 then
				v, t = "px_terracotta", PAL.DARK
			end
			box(
				"IsletRock",
				x - hx + sx * B,
				yTop - hgt,
				z - hz + sz * B,
				x - hx + (sx + lw) * B,
				yTop,
				z - hz + (sz + ld) * B,
				v,
				t,
				cf
			)
			ix0, ix1, iz0, iz1 = sx, sx + lw, sz, sz + ld
			yTop -= hgt
			total += hgt
		end
		local tip = rng:NextInteger(1, 2) * B
		local px = ix0 + rng:NextInteger(0, ix1 - ix0 - 1)
		local pz = iz0 + rng:NextInteger(0, iz1 - iz0 - 1)
		box(
			"IsletTip",
			x - hx + px * B,
			yTop - tip,
			z - hz + pz * B,
			x - hx + (px + 1) * B,
			yTop,
			z - hz + (pz + 1) * B,
			"px_terracotta",
			PAL.DARK,
			cf
		)
		-- a fringe of short columns under the outer ring of the top
		for side = 1, 4 do
			local along = if side <= 2 then d else w
			local used = {}
			for _ = 1, math.clamp(math.floor(along / 3 + rng:NextNumber(0, 1.2)), 0, 2) do
				local a = rng:NextInteger(0, along - 1)
				if not used[a] then
					used[a] = true
					local len = rng:NextInteger(1, math.max(2, math.floor(total / B))) * B
					sideBox("IsletStalactite", side, a, len, y - B, "px_red_sandstone", RED_SAND)
				end
			end
		end
		-- a prop on top
		local bx = x - hx + (math.floor(w / 2) + 0.5) * B
		local bz = z - hz + (math.floor(d / 2) + 0.5) * B
		local r = rng:NextNumber()
		if math.min(w, d) >= 5 and r < 0.3 then
			brokenArch(bx, y, bz, cf, w >= d)
		elseif math.min(w, d) >= 5 and r < 0.5 then
			hourglass(bx, y, bz, cf, 6, 24)
		elseif r < 0.7 then
			cypress(bx, y, bz, cf, rng:NextNumber() < 0.3)
		elseif r < 0.85 then
			brazier(bx, y, bz, cf, rng:NextNumber() < 0.4, false)
			soulFig(at(bx + 4, y, bz) * CFrame.Angles(0, math.pi / 2, 0), cf, false)
		elseif math.min(w, d) >= 2 then
			soulFig(at(bx, y, bz) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0), cf, false)
			deadBush(bx - 3, y, bz + 2, cf)
		end
		floatAll(cf)
	end
	local made = 0
	for i = 1, 34 do
		if made >= 20 then
			break
		end
		local big = i <= 3
		local w = if big then rng:NextInteger(7, 9) else rng:NextInteger(2, 6)
		local d = math.clamp(w + rng:NextInteger(-1, 1), 2, 9)
		local layers = math.clamp(math.floor(math.max(w, d) / 2) + rng:NextInteger(1, 2), 2, 6)
		local half = math.max(w, d) * B / 2 + B
		local down = B * (layers * 2 + 3)
		local yMin, yMax = -60, 100
		if not big and rng:NextNumber() < 0.6 then
			yMin, yMax = -30, 50
		end
		local x, y, z = findSpot(half, down, 36, yMin, yMax)
		if x then
			islet(snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2, w, d, layers)
			made += 1
		end
		if i % 4 == 0 then
			task.wait()
		end
	end
	local isletParts = count - c0
	-- sunset clouds: flat stacked wool slabs under the island (clear of its rock) and a few round it
	local cloudF = folder("Clouds", rimF)
	local clouds = 0
	local function cloudBox(x0, y0, z0, x1, y1, z1)
		local p = decor(box("Cloud", x0, y0, z0, x1, y1, z1, "px_white_wool", PAL.CLOUD, cloudF))
		p.CastShadow = false
		p.Transparency = 0.15
	end
	local function clearUnder(x, z, sx, sz, yTop)
		for _, o in ipairs({
			{ 0, 0 },
			{ -1, -1 },
			{ 1, -1 },
			{ -1, 1 },
			{ 1, 1 },
			{ 0, -1 },
			{ 0, 1 },
			{ -1, 0 },
			{ 1, 0 },
		}) do
			local b = colBottom(x + o[1] * sx / 2, z + o[2] * sz / 2)
			if b and b < yTop + 12 then
				return false
			end
		end
		return true
	end
	local under0 = 0
	for i = 1, 70 do
		if clouds >= 10 then
			break
		end
		local under = under0 < 6 and i <= 50
		local x, z, y
		if under then
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(110, 230)
			x, z, y =
				ISLAND.x + math.cos(a) * r, ISLAND.z + math.sin(a) * r, rng:NextNumber(-160, -80)
		else
			local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(290, 380)
			x, z, y =
				ISLAND.x + math.cos(a) * r, ISLAND.z + math.sin(a) * r, rng:NextNumber(-70, 20)
		end
		x, z, y = snap(x), snap(z), snap(y)
		local sx, sz = rng:NextInteger(10, 18) * B, rng:NextInteger(6, 10) * B
		if not under or clearUnder(x, z, sx, sz, y + 12) then
			cloudBox(x - sx / 2, y, z - sz / 2, x + sx / 2, y + 2 * B, z + sz / 2)
			local ox, oz = rng:NextInteger(-2, 2) * B, rng:NextInteger(-1, 1) * B
			cloudBox(
				x - sx / 4 + ox,
				y + 2 * B,
				z - sz / 4 + oz,
				x + sx / 4 + ox,
				y + 3 * B,
				z + sz / 4 + oz
			)
			if rng:NextNumber() < 0.6 then
				local sgn = if rng:NextNumber() < 0.5 then -1 else 1
				cloudBox(
					x + sgn * sx / 2,
					y + B * 0.5,
					z - sz / 4,
					x + sgn * (sx / 2 + 4 * B),
					y + 1.5 * B,
					z + sz / 4
				)
			end
			clouds += 1
			if under then
				under0 += 1
			end
		end
	end
	print(
		("[build-purgatory] rim: islets %d (%d parts), clouds %d; rim total %d parts, %d lights"):format(
			made,
			isletParts,
			clouds,
			count - R.c0,
			R.lights
		)
	)
end
