--!nocheck
-- ================================================================ gate: the great stair, the terrace, the angels, the PEARLY GATES
-- GATE part (zoneOf == "gate": |x| ≤ 130, z < -66), strictly mirror-symmetric in x (every side built by a helper with
-- sx = -1 and 1; only the gatekeeper's lectern stands west of the axis).
--   STAIR        x -20..20, z -70 → -120, y 0 → 24: three kit flights (a gold runner x -8..8 between pearl flights
--                with a cut-sandstone band every 4th step), a stepped fill below, stepped pearl cheeks x ±20..±24 with
--                a gold coping, torch pylons on the cheeks at z -74 / -86 / -98 / -110 shrinking 6 → 5 → 5 → 4
--                blocks, the 12 tribe banners on gold poles at x ±25 (6 per side, z -74..-114)
--   SIDE_STAIRS  z -120..-108, from x ±112 (y 0) in to x ±64 (y 24): kit flights (axis "x"), a stepped white
--                balustrade with a gold coping on z -108..-106, a pearl pier x ±60..±64 at the top (a pylon on it)
--                and a pylon at the outer foot (x ±112..±116, z -108..-104)
--   FRONT        blue-glass cascades down the cliff face: x ±36..±54 over two white ledges into a white basin
--                (x ±30..±60, z -104..-86, water 2.5 deep), thin sheets at x ±113..±119 with a flush splash;
--                cypresses on the ground (±38, ±54 at z -78; ±80, ±96 at z -96)
--   TERRACE      y 24: a pearl parade x -16..16 (gold and calcite borders) from the stair head to the gates;
--                balustrades on z -122..-120 (x ±24..±64, ±88..±116; the side stair heads x ±64..±84 open),
--                pylons at x ±86 and ±118; fountains at (±88, -140); benches, planters with cypresses, lanterns;
--                the 12 foundation stones (2×2 blocks, gold frames) in the wall foot at x ±44 ±52 ±68 ±76 ±92 ±100
--   ANGELS       (±48, -140): plinth 4×4 blocks y 24..32, the figure y 32 → head top 80, halo y 84, wings to
--                y ≈ 102, a gold spear in the outer hand to y 114; facing south
--   WALL         x ±24..±104, z -164..-156, y 24..64 in stripes (pearl / prismarine / dark prismarine), merlons,
--                turret pillars at x ±36 ±60 ±84 (to y 78, gold caps), corner towers x ±104..±120 (to y 84, gold
--                stepped domes to y 102), fitted inward if the island is narrower
--   GATES        x -24..24, z -166..-154: a stepped pointed arch rasterised on a 2-stud grid (opening x -14..14,
--                y 24..78; frame to the apex y 100) in rings: gold edges, pearl, a teal-and-gold band, calcite, a dark
--                prismarine band; a glowing gem y 100..104 and a gold cross finial to y 116; clustered columns
--                x ±14..±23 in front; two pearl leaves (14 wide × 48 tall) hinged at (±14, -166) swung 76° north
--                (free edges at x ±10.6); a white veil of light in the opening; a gold threshold
--   LIGHT        z -164 → the north tip: glowing pale Neon slabs flush at y 24.1, cloud heaps on both sides, the
--                beacon at (0, -196) (iron 3×3, a glass shell, glowstone, a beam y 28 → 600 and a wider haze)
--   LECTERN      (-16, -144) facing the axis, an open book; the gatekeeper NPC at (-21, -144)
-- PointLights: the gem, the beacon and 10 pylon fires (≤ 14); fire emitters on 4 pylons.
local gateF = folder("Gates")
local SIDES = { -1, 1 }
local FLAME = Color3.fromRGB(255, 140, 40)
local FLAME_CORE = Color3.fromRGB(255, 214, 110)
local FACE = Color3.fromRGB(252, 242, 230) -- quartz skin
local lit = 0

-- a PointLight within the part budget (≤ 14)
local function glow(p, range, brightness, color)
	if lit >= 14 then
		return nil
	end
	lit += 1
	return light(p, range, brightness, color)
end
-- blue glass water: no collision, no shadow
local function water(name, x0, y0, z0, x1, y1, z1, parent)
	local p = box(name, x0, y0, z0, x1, y1, z1, nil, WATER, parent)
	p.Material = Enum.Material.Glass
	p.Transparency = 0.35
	p.CastShadow = false
	return decor(p)
end
local function neon(name, x0, y0, z0, x1, y1, z1, color, parent)
	local p = box(name, x0, y0, z0, x1, y1, z1, nil, color, parent)
	p.Material = Enum.Material.Neon
	p.CastShadow = false
	return p
end
-- a torch pylon of n blocks on a 1-block footprint centred at (x, z) from y0: a white brick plinth, a pearl shaft
-- with a gold sun banner on its south face, a teal band, a gold cap and a fire on top
local function pylon(x, y0, z, n, parent, lightIt, fx)
	local f = folder("Pylon", parent)
	local top = y0 + n * B
	box(
		"PylonPlinth",
		x - 2.4,
		y0,
		z - 2.4,
		x + 2.4,
		y0 + B,
		z + 2.4,
		"px_white_stone_bricks",
		PEARL,
		f
	)
	box("PylonShaft", x - 2, y0 + B, z - 2, x + 2, top - 2 * B, z + 2, "px_smooth_stone", PEARL, f)
	box(
		"PylonBand",
		x - 2.3,
		top - 2 * B,
		z - 2.3,
		x + 2.3,
		top - B,
		z + 2.3,
		"px_prismarine",
		JASPER,
		f
	)
	box("PylonCap", x - 2.7, top - B, z - 2.7, x + 2.7, top - 1, z + 2.7, "px_gold_block", GOLD, f)
	local by1 = top - 2 * B - 0.4
	local by0 = math.max(y0 + B + 0.4, by1 - 8)
	decor(
		box("PylonBanner", x - 1.5, by0, z + 2, x + 1.5, by1, z + 2.25, "px_yellow_wool", GOLD, f)
	)
	local my = (by0 + by1) / 2 + 0.4
	decor(
		box(
			"PylonSun",
			x - 0.7,
			my - 0.7,
			z + 2.25,
			x + 0.7,
			my + 0.7,
			z + 2.4,
			nil,
			Color3.new(1, 1, 1),
			f
		)
	)
	local fire =
		decor(neon("PylonFire", x - 1.5, top - 1, z - 1.5, x + 1.5, top + 1.4, z + 1.5, FLAME, f))
	decor(
		neon("PylonFlame", x - 0.7, top + 1.4, z - 0.7, x + 0.7, top + 2.8, z + 0.7, FLAME_CORE, f)
	)
	if lightIt then
		glow(fire, 28, 1.3, Color3.fromRGB(255, 200, 130))
	end
	if fx then
		emitter(fire, {
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new(FLAME_CORE, FLAME),
			LightEmission = 1,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1.8),
				NumberSequenceKeypoint.new(1, 0.3),
			}),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 12,
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(12, 12),
		})
	end
	return f
end
-- a cypress: a dark oak trunk block, a tall hedge column w blocks wide, narrowing on top (h blocks in all)
local function cypress(x, y0, z, w, h, parent)
	local f = folder("Cypress", parent)
	box("CypressTrunk", x - 2, y0, z - 2, x + 2, y0 + B, z + 2, "px_dark_oak_log", nil, f)
	local hw = w * B / 2
	local body = y0 + B + (h - 3) * B
	box("CypressLeaves", x - hw, y0 + B, z - hw, x + hw, body, z + hw, "px_hedge", CYPRESS, f)
	if w >= 3 then
		box("CypressLeaves", x - 4, body, z - 4, x + 4, body + B, z + 4, "px_hedge", CYPRESS, f)
		box(
			"CypressTop",
			x - 2,
			body + B,
			z - 2,
			x + 2,
			body + 2 * B,
			z + 2,
			"px_hedge",
			CYPRESS,
			f
		)
	else
		box("CypressTop", x - 2, body, z - 2, x + 2, body + 2 * B, z + 2, "px_hedge", CYPRESS, f)
	end
	return f
end
-- a low balustrade along x on the terrace: a brick plinth, posts every 8 studs, a gold rail
local function balustrade(x0, x1, z0, z1, y0, parent)
	local a, b = math.min(x0, x1), math.max(x0, x1)
	box("BalPlinth", a, y0, z0, b, y0 + 1, z1, "px_white_stone_bricks", PEARL, parent)
	local n = math.max(1, math.floor((b - a) / 8 + 0.5))
	local zc = (z0 + z1) / 2
	for k = 0, n do
		local x = a + (b - a) * k / n
		x = math.clamp(x, a + 1.2, b - 1.2)
		box(
			"BalPost",
			x - 1.2,
			y0 + 1,
			zc - 1.2,
			x + 1.2,
			y0 + 3.4,
			zc + 1.2,
			"px_smooth_stone",
			PEARL,
			parent
		)
	end
	box("BalRail", a, y0 + 3.4, z0 - 0.2, b, y0 + 4.2, z1 + 0.2, "px_gold_block", GOLD, parent)
end

-- ================================================================ the great stair, its cheeks, pylons and the tribe banners
do
	local sf = folder("GreatStair", gateF)
	stairs("StairWest", -14, -70, -120, 0, TERRACE_Y, 12, "px_smooth_stone", sf)
	stairs("StairGold", 0, -70, -120, 0, TERRACE_Y, 16, "px_gold_block", sf)
	stairs("StairEast", 14, -70, -120, 0, TERRACE_Y, 12, "px_smooth_stone", sf)
	for _, p in ipairs(sf:GetChildren()) do
		if p.Name == "StairGoldStep" then
			p.Color = GOLD
		elseif p.Name == "StairWestStep" or p.Name == "StairEastStep" then
			local k = math.floor((-70 - (p.Position.Z - BZ)) / 2)
			if k % 4 == 3 then
				textured(p, "px_cut_sandstone", SAND)
			else
				p.Color = PEARL
			end
		end
	end
	local SEG = 50 / 6 -- six cheek segments, one block of rise each
	for i = 1, 5 do
		box(
			"StairFill",
			-20,
			0,
			-70 - SEG * i,
			20,
			4 * i,
			-70 - SEG * (i + 1),
			"px_smooth_stone",
			PEARL,
			sf
		)
	end
	local function cheekTop(z)
		local i = math.clamp(math.floor((-70 - z) / SEG), 0, 5)
		return 4 * (i + 1) + 4
	end
	local function side(sx)
		for i = 0, 5 do
			local top = 4 * (i + 1) + 4
			local za, zb = -70 - SEG * i, -70 - SEG * (i + 1)
			box("StairCheek", sx * 20, 0, za, sx * 24, top, zb, "px_white_stone_bricks", PEARL, sf)
			box(
				"CheekCoping",
				sx * 19.6,
				top,
				za,
				sx * 24.4,
				top + 1,
				zb,
				"px_gold_block",
				GOLD,
				sf
			)
		end
		-- forced perspective: the pylons shrink toward the gates
		for k, c in ipairs({ { -74, 6 }, { -86, 5 }, { -98, 5 }, { -110, 4 } }) do
			pylon(sx * 22, cheekTop(c[1]) + 1, c[1], c[2], sf, k == 1 or k == 3, k == 1)
		end
		-- the twelve tribes: six banners a side on gold poles, facing the road
		local bf = folder("TribeBanners", sf)
		for k = 1, 6 do
			local z = -74 - 8 * (k - 1)
			local sy = TERRACE_Y * (-70 - z) / 50
			local poleTop = sy + 20
			box(
				"BannerPoleGold",
				sx * 24.8,
				0,
				z - 0.4,
				sx * 25.6,
				poleTop + 0.6,
				z + 0.4,
				"px_gold_block",
				GOLD,
				bf
			)
			decor(
				box(
					"BannerKnob",
					sx * 24.6,
					poleTop + 0.6,
					z - 0.6,
					sx * 25.8,
					poleTop + 1.8,
					z + 0.6,
					"px_gold_block",
					GOLD,
					bf
				)
			)
			local color = TRIBES[if sx < 0 then k else 6 + k]
			banner(
				at(sx * 28, poleTop - 5.2, z + 0.6),
				color,
				bf,
				Color3.fromRGB(250, 250, 245),
				B,
				10
			)
		end
		for _, p in ipairs(bf:GetChildren()) do
			if p.Name == "BannerPole" then
				textured(p, "px_gold_block", GOLD)
			end
		end
	end
	for _, sx in ipairs(SIDES) do
		side(sx)
	end
end
task.wait()

-- ================================================================ the side stairs along the terrace front
do
	local f = folder("SideStairs", gateF)
	for _, sx in ipairs(SIDES) do
		stairs(
			if sx < 0 then "SideStairWest" else "SideStairEast",
			-114,
			sx * 112,
			sx * 64,
			0,
			TERRACE_Y,
			12,
			"px_smooth_stone",
			f,
			"x"
		)
		for i = 0, 5 do
			local xa, xb = sx * (112 - 8 * i), sx * (112 - 8 * (i + 1))
			if i >= 1 then
				box("SideStairFill", xa, 0, -120, xb, 4 * i, -108, "px_smooth_stone", PEARL, f)
			end
			local top = 4 * (i + 1) + 4
			box("SideBalustrade", xa, 0, -108, xb, top, -106, "px_white_stone_bricks", PEARL, f)
			box("SideBalCoping", xa, top, -108.3, xb, top + 0.8, -105.7, "px_gold_block", GOLD, f)
		end
		-- the pier at the top closes the inner end; pylons at both ends
		box(
			"SidePier",
			sx * 60,
			0,
			-120,
			sx * 64,
			TERRACE_Y,
			-108,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		box(
			"SidePierCoping",
			sx * 59.6,
			TERRACE_Y - 1,
			-108.4,
			sx * 64,
			TERRACE_Y,
			-107.6,
			"px_gold_block",
			GOLD,
			f
		)
		pylon(sx * 62, TERRACE_Y, -110, 5, f, true, true)
		pylon(sx * 114, 0, -106, 5, f, true, false)
	end
	for _, p in ipairs(f:GetChildren()) do
		if p.Name:find("Step") then
			p.Color = PEARL
		end
	end
end
task.wait()

-- ================================================================ the terrace front: cascades, basins, cypresses
do
	local f = folder("Cascades", gateF)
	local function side(sx)
		-- the middle cascade: two white ledges stepping out from the cliff, blue glass falling over them
		box("CascadeLedge", sx * 30, 0, -120, sx * 60, 16, -112, "px_white_stone_bricks", PEARL, f)
		box("CascadeLedge", sx * 30, 0, -112, sx * 60, 8, -104, "px_white_stone_bricks", PEARL, f)
		box("LedgeTrim", sx * 30, 15.4, -112.4, sx * 36, 16.2, -111.8, "px_gold_block", GOLD, f)
		box("LedgeTrim", sx * 54, 15.4, -112.4, sx * 60, 16.2, -111.8, "px_gold_block", GOLD, f)
		box("LedgeTrim", sx * 30, 7.4, -104.4, sx * 36, 8.2, -103.8, "px_gold_block", GOLD, f)
		box("LedgeTrim", sx * 54, 7.4, -104.4, sx * 60, 8.2, -103.8, "px_gold_block", GOLD, f)
		water("CascadeSource", sx * 36, 24, -128, sx * 54, 24.3, -120, f)
		water("CascadeFall", sx * 36, 16, -120, sx * 54, 24.3, -116, f)
		water("CascadePool", sx * 36, 16, -116, sx * 54, 16.5, -112, f)
		water("CascadeFall", sx * 36, 8, -112, sx * 54, 16.5, -108, f)
		water("CascadePool", sx * 36, 8, -108, sx * 54, 8.5, -104, f)
		water("CascadeFall", sx * 36, 0, -104, sx * 54, 8.5, -100, f)
		-- the basin (the lower ledge is its back wall); water 2.5 studs deep
		box("BasinRim", sx * 30, 0, -88, sx * 60, 3, -86, "px_smooth_stone", PEARL, f)
		box("BasinRim", sx * 30, 0, -104, sx * 32, 3, -88, "px_smooth_stone", PEARL, f)
		box("BasinRim", sx * 58, 0, -104, sx * 60, 3, -88, "px_smooth_stone", PEARL, f)
		box("BasinCoping", sx * 29.6, 3, -88.4, sx * 60.4, 3.5, -85.6, "px_gold_block", GOLD, f)
		water("BasinWater", sx * 32, 0, -104, sx * 58, 2.5, -88, f)
		-- the corner sheets at the stair foot (flush, nothing to trip over)
		water("CornerSource", sx * 113, 24, -124, sx * 119, 24.3, -120, f)
		water("CornerFall", sx * 113, 12, -120, sx * 119, 24.3, -119, f)
		water("CornerFall", sx * 113, 0.2, -120, sx * 119, 12, -118.6, f)
		water("CornerSplash", sx * 112, 0.02, -118.6, sx * 120, 0.3, -115, f)
		-- cypresses on the ground before the cliff
		cypress(sx * 38, 0, -78, 2, 6, f)
		cypress(sx * 54, 0, -78, 2, 5, f)
		cypress(sx * 80, 0, -96, 3, 7, f)
		cypress(sx * 96, 0, -96, 2, 6, f)
	end
	for _, sx in ipairs(SIDES) do
		side(sx)
	end
end
task.wait()

-- ================================================================ the terrace: the parade, balustrades, pylons, fountains, furniture
do
	local f = folder("Terrace", gateF)
	local Y = TERRACE_Y
	box("Parade", -16, Y - 0.1, -154, 16, Y + 0.12, -120, "px_smooth_stone", PEARL, f)
	box("ParadeBand", -16, Y - 0.1, -137.5, 16, Y + 0.14, -136.5, "px_gold_block", GOLD, f)
	local lanterns = folder("Lanterns", f)
	local function side(sx)
		box(
			"ParadeGold",
			sx * 16,
			Y - 0.1,
			-154,
			sx * 17.5,
			Y + 0.14,
			-120,
			"px_gold_block",
			GOLD,
			f
		)
		box(
			"ParadeCalcite",
			sx * 17.5,
			Y - 0.1,
			-154,
			sx * 20,
			Y + 0.12,
			-120,
			"px_white_stone_bricks",
			CALCITE,
			f
		)
		-- the front edge: balustrades, the side stair head open (x ±64..±84), pylons
		balustrade(sx * 24, sx * 60, -122, -120, Y, f)
		balustrade(sx * 88, sx * 116, -122, -120, Y, f)
		pylon(sx * 86, Y, -122, 5, f, false, false)
		pylon(sx * 117.5, Y, -126, 5, f, true, false)
		-- the fountain: a white basin and a stepped blue-glass cascade on a pearl tower
		local fx, fz = sx * 88, -140
		box("FountainRim", fx - 8, Y, fz - 8, fx + 8, Y + 3, fz - 6, "px_smooth_stone", PEARL, f)
		box("FountainRim", fx - 8, Y, fz + 6, fx + 8, Y + 3, fz + 8, "px_smooth_stone", PEARL, f)
		box("FountainRim", fx - 8, Y, fz - 6, fx - 6, Y + 3, fz + 6, "px_smooth_stone", PEARL, f)
		box("FountainRim", fx + 6, Y, fz - 6, fx + 8, Y + 3, fz + 6, "px_smooth_stone", PEARL, f)
		box(
			"FountainCoping",
			fx - 8.3,
			Y + 3,
			fz - 8.3,
			fx + 8.3,
			Y + 3.5,
			fz + 8.3,
			"px_gold_block",
			GOLD,
			f
		)
		water("FountainWater", fx - 6, Y, fz - 6, fx + 6, Y + 2.5, fz + 6, f)
		for _, t in ipairs({ { 4, 0, 6 }, { 3, 6, 12 }, { 1.6, 12, 17 } }) do
			box(
				"FountainTier",
				fx - t[1],
				Y + t[2],
				fz - t[1],
				fx + t[1],
				Y + t[3],
				fz + t[1],
				"px_smooth_stone",
				PEARL,
				f
			)
			water(
				"FountainFall",
				fx - t[1] - 0.5,
				Y + t[2] + 1,
				fz - t[1] - 0.5,
				fx + t[1] + 0.5,
				Y + t[3],
				fz + t[1] + 0.5,
				f
			)
		end
		water("FountainSpout", fx - 2, Y + 17, fz - 2, fx + 2, Y + 20, fz + 2, f)
		-- planters with cypresses, a bench facing the fountain, lanterns on gold posts
		for _, c in ipairs({ { 102, -128, 2, 7 }, { 114, -142, 2, 6 } }) do
			local px, pz, hw = sx * c[1], c[2], c[3] * 2 + 2
			box(
				"Planter",
				px - hw,
				Y,
				pz - hw,
				px + hw,
				Y + 3,
				pz + hw,
				"px_white_stone_bricks",
				PEARL,
				f
			)
			box(
				"PlanterRim",
				px - hw - 0.3,
				Y + 3,
				pz - hw - 0.3,
				px + hw + 0.3,
				Y + 3.6,
				pz + hw + 0.3,
				"px_gold_block",
				GOLD,
				f
			)
			cypress(px, Y + 3.6 - B, pz, c[3], c[4], f)
		end
		box(
			"BenchSeat",
			sx * 100.5,
			Y + 2,
			-147,
			sx * 103.5,
			Y + 3,
			-137,
			"px_smooth_stone",
			CALCITE,
			f
		)
		box("BenchLeg", sx * 101, Y, -147, sx * 103, Y + 2, -145, "px_white_stone_bricks", PEARL, f)
		box("BenchLeg", sx * 101, Y, -139, sx * 103, Y + 2, -137, "px_white_stone_bricks", PEARL, f)
		box(
			"BenchBack",
			sx * 103.5,
			Y + 2,
			-147,
			sx * 104.5,
			Y + 6,
			-137,
			"px_smooth_stone",
			PEARL,
			f
		)
		for _, c in ipairs({ { 110, -128 }, { 78, -151 } }) do
			local lx, lz = sx * c[1], c[2]
			box(
				"LanternPlinth",
				lx - 2,
				Y,
				lz - 2,
				lx + 2,
				Y + 1,
				lz + 2,
				"px_white_stone_bricks",
				PEARL,
				lanterns
			)
			box(
				"LanternPost",
				lx - 0.5,
				Y + 1,
				lz - 0.5,
				lx + 0.5,
				Y + 8.2,
				lz + 0.5,
				"px_gold_block",
				GOLD,
				lanterns
			)
			lantern(V(lx, Y + 9, lz), lanterns)
		end
	end
	for _, sx in ipairs(SIDES) do
		side(sx)
	end
	-- noon: the lanterns stay unlit (the PointLight budget belongs to the pylons, the gem and the beacon)
	for _, d in ipairs(lanterns:GetDescendants()) do
		if d:IsA("PointLight") then
			d:Destroy()
		end
	end
end
task.wait()

-- ================================================================ the two guardian angels
do
	local function angel(sx)
		local cx, cz = ANGELS[if sx < 0 then 1 else 2][1], ANGELS[1][2]
		local af = folder(if sx < 0 then "AngelWest" else "AngelEast", gateF)
		-- lx: + = toward the outer side (sx); lz: + = south (the front)
		local function ab(name, lx0, y0, lz0, lx1, y1, lz1, variant, tint, solid)
			local p = box(
				name,
				cx + sx * lx0,
				y0,
				cz + lz0,
				cx + sx * lx1,
				y1,
				cz + lz1,
				variant,
				tint,
				af
			)
			if not solid then
				decor(p)
			end
			return p
		end
		-- the plinth (4×4 blocks, 2 high) with gold trim
		ab("PlinthBase", -8.5, 24, -8.5, 8.5, 25, 8.5, "px_gold_block", GOLD, true)
		ab("Plinth", -8, 25, -8, 8, 31, 8, "px_white_stone_bricks", PEARL, true)
		ab("PlinthCap", -8.5, 31, -8.5, 8.5, 32, 8.5, "px_gold_block", GOLD, true)
		-- the stepped robe widening to the hem, a gold belt
		ab("Robe", -8, 32, -6, 8, 40, 6, "px_white_wool", PEARL, true)
		ab("RobeHem", -8.3, 32, -6.3, 8.3, 33, 6.3, "px_gold_block", GOLD, true)
		ab("Robe", -7, 40, -5, 7, 48, 5, "px_white_wool", PEARL, true)
		ab("RobeTrim", -7.2, 40, -5.2, 7.2, 40.8, 5.2, "px_gold_block", GOLD)
		ab("Robe", -6, 48, -4, 6, 66, 4, "px_white_wool", PEARL, true)
		ab("RobeFold", -1, 33, 6, 1, 40, 6.4, "px_smooth_stone", CALCITE)
		ab("RobeFold", -1, 41, 5, 1, 48, 5.4, "px_smooth_stone", CALCITE)
		ab("Belt", -6.3, 55, -4.3, 6.3, 57, 4.3, "px_gold_block", GOLD)
		ab("BeltClasp", -1.2, 54.5, 4.3, 1.2, 57.5, 4.7, "px_gold_block", GOLD)
		ab("Stole", -3.5, 57, 4, -2, 66, 4.4, "px_gold_block", GOLD)
		ab("Stole", 2, 57, 4, 3.5, 66, 4.4, "px_gold_block", GOLD)
		ab("Shoulders", -8, 62, -4.5, 8, 68, 4.5, "px_white_wool", PEARL)
		-- the head: quartz face, gold hair, eyes
		ab("Neck", -2, 68, -2, 2, 70, 2, "px_smooth_stone", FACE)
		ab("Head", -4, 70, -4, 4, 78, 4, "px_smooth_stone", FACE)
		for _, e in ipairs({ -1, 1 }) do
			local x0, x1 = e * 1, e * 2.4
			ab(
				"Eye",
				math.min(x0, x1),
				73.6,
				4,
				math.max(x0, x1),
				74.8,
				4.2,
				nil,
				Color3.fromRGB(70, 110, 170)
			)
		end
		ab("HairBack", -4.6, 64, -4.7, 4.6, 79, -1, "px_gold_block", GOLD)
		ab("HairTop", -4.6, 78, -4.7, 4.6, 80, 4.4, "px_gold_block", GOLD)
		ab("HairSide", -4.7, 70, -4, -4, 78, 1, "px_gold_block", GOLD)
		ab("HairSide", 4, 70, -4, 4.7, 78, 1, "px_gold_block", GOLD)
		ab("HairFringe", -4, 77, 4, 4, 78, 4.4, "px_gold_block", GOLD)
		-- the halo: a gold ring above the head
		ab("Halo", -6, 84, 3, 6, 85.2, 5, "px_gold_block", GOLD)
		ab("Halo", -6, 84, -7, 6, 85.2, -5, "px_gold_block", GOLD)
		ab("Halo", -6, 84, -5, -4, 85.2, 3, "px_gold_block", GOLD)
		ab("Halo", 4, 84, -5, 6, 85.2, 3, "px_gold_block", GOLD)
		-- the outer arm holds the spear forward; the inner arm lies across the chest
		ab("ArmOuter", 6.5, 54, -2, 10.5, 67, 2, "px_white_wool", PEARL)
		ab("ForearmOuter", 6.5, 50, -2, 10.5, 54, 6.5, "px_white_wool", PEARL)
		ab("HandOuter", 6, 49.5, 6.5, 9, 54.5, 9, "px_smooth_stone", FACE)
		ab("ArmInner", -10.5, 56, -2, -6.5, 67, 2, "px_white_wool", PEARL)
		ab("ForearmInner", -10.5, 56, 4, 1, 60, 7.5, "px_white_wool", PEARL)
		ab("HandInner", 1, 56.2, 4.2, 4, 59.8, 7.3, "px_smooth_stone", FACE)
		-- the spear: a gold shaft from the plinth to y 104, a guard and a stepped blade to y 114
		ab("SpearShaft", 6.9, 32, 6.9, 8.1, 104, 8.1, "px_gold_block", GOLD)
		ab("SpearGuard", 5.5, 103, 6.9, 9.5, 104.4, 8.1, "px_gold_block", GOLD)
		ab("SpearBlade", 6.3, 104.4, 7, 8.7, 110, 8, "px_gold_block", GOLD)
		ab("SpearTip", 6.9, 110, 7.1, 8.1, 114, 7.9, "px_gold_block", GOLD)
		-- the wings: stepped rows (4 studs) spreading up, out and back from the shoulder blades; a back layer in
		-- alternating pearl / wool rows and a shorter covert layer in front
		local ROWS = {
			{ -12, 6, 12 },
			{ -8, 3, 14 },
			{ -4, 0, 15 },
			{ 0, 0, 16 },
			{ 4, 0, 17 },
			{ 8, 0, 18 },
			{ 12, 1, 18 },
			{ 16, 2, 18 },
			{ 20, 3, 18 },
			{ 24, 5, 18 },
			{ 28, 7, 18 },
			{ 32, 10, 17 },
			{ 36, 13, 16 },
		}
		for _, side in ipairs(SIDES) do
			local wcf = at(cx + side * 3, 62, cz - 4.5) * CFrame.Angles(0, side * math.rad(35), 0)
			for r, row in ipairs(ROWS) do
				local v, u0, u1 = row[1], row[2], row[3]
				local p = part(
					"Wing",
					Vector3.new(u1 - u0, B, 2.5),
					wcf * CFrame.new(side * (u0 + u1) / 2, v + 2, 0),
					nil,
					nil,
					af
				)
				if r % 2 == 0 then
					textured(p, "px_white_wool", CLOUD)
				else
					textured(p, "px_smooth_stone", PEARL)
				end
				decor(p)
				if v >= -4 and u1 - 5 > u0 then
					local c = part(
						"WingCovert",
						Vector3.new(u1 - 5 - u0, B, 1.6),
						wcf * CFrame.new(side * (u0 + u1 - 5) / 2, v + 2, 2),
						nil,
						nil,
						af
					)
					textured(decor(c), "px_smooth_stone", CALCITE)
				end
			end
			-- a gold edge on the top of the wing
			local e = part(
				"WingEdge",
				Vector3.new(4, 1, 2.8),
				wcf * CFrame.new(side * 14.5, 40.5, 0),
				nil,
				nil,
				af
			)
			textured(decor(e), "px_gold_block", GOLD)
		end
	end
	for _, sx in ipairs(SIDES) do
		angel(sx)
	end
end
task.wait()

-- ================================================================ the jasper wall, turret pillars, corner towers, foundation stones
do
	local f = folder("JasperWall", gateF)
	local BANDS = {
		{ 24, 32, "px_smooth_stone", PEARL },
		{ 32, 36, "px_prismarine", JASPER },
		{ 36, 44, "px_smooth_stone", PEARL },
		{ 44, 48, "px_dark_prismarine", JASPER },
		{ 48, 56, "px_smooth_stone", PEARL },
		{ 56, 60, "px_prismarine", JASPER },
		{ 60, 64, "px_white_stone_bricks", PEARL },
	}
	-- the corner tower sits where its whole footprint is on the terrace (x0 = its inner face)
	local towerX0 = GATE.wall - 8
	while towerX0 > 64 do
		local ok = true
		for _, c in ipairs({ { towerX0 + 15, -167 }, { towerX0 + 15, -153 }, { towerX0 + 1, -167 } }) do
			if not onTerrace(c[1], c[2]) then
				ok = false
			end
		end
		if ok then
			break
		end
		towerX0 -= 8
	end
	local function side(sx)
		for _, b in ipairs(BANDS) do
			box("WallBand", sx * GATE.half, b[1], -164, sx * towerX0, b[2], -156, b[3], b[4], f)
		end
		for _, c in ipairs({ 28, 44, 52, 68, 76, 92, 100 }) do
			if c + 2 <= towerX0 then
				box(
					"Merlon",
					sx * (c - 2),
					64,
					-163,
					sx * (c + 2),
					68,
					-157,
					"px_white_stone_bricks",
					PEARL,
					f
				)
			end
		end
		-- turret pillars
		for _, c in ipairs({ 36, 60, 84 }) do
			if c + 4 <= towerX0 then
				local x0, x1 = sx * (c - 4), sx * (c + 4)
				box("Turret", x0, 24, -165, x1, 72, -155, "px_smooth_stone", PEARL, f)
				box(
					"TurretBand",
					sx * (c - 4.3),
					32,
					-165.3,
					sx * (c + 4.3),
					36,
					-154.7,
					"px_prismarine",
					JASPER,
					f
				)
				box(
					"TurretBand",
					sx * (c - 4.3),
					56,
					-165.3,
					sx * (c + 4.3),
					60,
					-154.7,
					"px_dark_prismarine",
					JASPER,
					f
				)
				box(
					"TurretCap",
					sx * (c - 5),
					72,
					-166,
					sx * (c + 5),
					76,
					-154,
					"px_gold_block",
					GOLD,
					f
				)
				box(
					"TurretTop",
					sx * (c - 3),
					76,
					-163,
					sx * (c + 3),
					78,
					-157,
					"px_gold_block",
					GOLD,
					f
				)
			end
		end
		-- the twelve foundation stones in the wall foot (6 a side), each in a gold frame
		for k, c in ipairs({ 44, 52, 68, 76, 92, 100 }) do
			if c + 4 <= towerX0 then
				local color = TRIBES[if sx < 0 then k else 6 + k]
				box(
					"StoneFrame",
					sx * (c - 4),
					24,
					-157,
					sx * (c + 4),
					32,
					-155.4,
					"px_gold_block",
					GOLD,
					f
				)
				box(
					"FoundationStone",
					sx * (c - 3.3),
					24.7,
					-156,
					sx * (c + 3.3),
					31.3,
					-155,
					"px_smooth_stone",
					color,
					f
				)
			end
		end
		-- the corner tower: pearl with jasper bands, a corbelled crown and a stepped gold dome
		local tx0, tx1 = sx * towerX0, sx * (towerX0 + 16)
		local tc = sx * (towerX0 + 8)
		box("Tower", tx0, 24, -168, tx1, 80, -152, "px_smooth_stone", PEARL, f)
		for _, b in ipairs({
			{ 36, 40, "px_prismarine" },
			{ 56, 60, "px_dark_prismarine" },
			{ 72, 76, "px_prismarine" },
		}) do
			box(
				"TowerBand",
				sx * (towerX0 - 0.3),
				b[1],
				-168.3,
				sx * (towerX0 + 16.3),
				b[2],
				-151.7,
				b[3],
				JASPER,
				f
			)
		end
		box(
			"TowerCrown",
			sx * (towerX0 - 1),
			80,
			-169,
			sx * (towerX0 + 17),
			84,
			-151,
			"px_white_stone_bricks",
			PEARL,
			f
		)
		for k, h in ipairs({ 7, 5, 3, 1 }) do
			local y0 = 84 + (k - 1) * 4
			box(
				"TowerDome",
				tc - h,
				y0,
				-160 - h,
				tc + h,
				y0 + (if k == 4 then 6 else 4),
				-160 + h,
				"px_gold_block",
				GOLD,
				f
			)
		end
		for _, wy in ipairs({ { 44, 52 }, { 62, 70 } }) do
			local p = box(
				"TowerWindow",
				tc - 1,
				wy[1],
				-151.9,
				tc + 1,
				wy[2],
				-151.5,
				nil,
				Color3.fromRGB(70, 110, 130),
				f
			)
			p.Material = Enum.Material.Glass
		end
	end
	for _, sx in ipairs(SIDES) do
		side(sx)
	end
end
task.wait()

-- ================================================================ THE PEARLY GATES
do
	local gf = folder("PearlyGates", gateF)
	local Z0, Z1 = -166, -154
	-- the arch on a 2-stud grid: x cells -24..24, rows y 24..100
	local NX, NY = 24, 38
	local function openHalf(y)
		if y < 60 then
			return 14
		elseif y < 64 then
			return 12
		elseif y < 68 then
			return 10
		elseif y < 72 then
			return 8
		elseif y < 74 then
			return 6
		elseif y < 76 then
			return 4
		elseif y < 78 then
			return 2
		end
		return 0
	end
	local function outerHalf(y)
		if y < 76 then
			return 24
		elseif y < 80 then
			return 22
		elseif y < 84 then
			return 20
		elseif y < 88 then
			return 16
		elseif y < 92 then
			return 12
		elseif y < 96 then
			return 8
		elseif y < 100 then
			return 4
		end
		return 0
	end
	local kind = {} -- 0 outside, 1 the opening, 2 the frame
	local opens, outs = {}, {}
	for j = 0, NY - 1 do
		kind[j] = {}
		local cy = 25 + 2 * j
		for i = 0, NX - 1 do
			local ax = math.abs(-23 + 2 * i)
			local k = if ax < openHalf(cy) then 1 elseif ax < outerHalf(cy) then 2 else 0
			kind[j][i] = k
			if k == 1 then
				table.insert(opens, { i, j })
			elseif k == 0 then
				table.insert(outs, { i, j })
			end
		end
	end
	local function near(list, i, j)
		local best = math.huge
		for _, c in ipairs(list) do
			local d = math.max(math.abs(c[1] - i), math.abs(c[2] - j))
			if d < best then
				best = d
			end
		end
		return best
	end
	local MATS = {
		{ "px_gold_block", GOLD },
		{ "px_smooth_stone", PEARL },
		{ "px_white_stone_bricks", CALCITE },
		{ "px_prismarine", JASPER },
		{ "px_dark_prismarine", JASPER },
		{ "px_prismarine_bricks", JASPER },
	}
	local mat = {}
	for j = 0, NY - 1 do
		mat[j] = {}
		for i = 0, NX - 1 do
			if kind[j][i] == 2 then
				local dIn = near(opens, i, j)
				local dOut = math.min(near(outs, i, j), i + 1, NX - i, NY - j)
				local si = math.min(i, NX - 1 - i)
				local m
				if dOut == 1 or dIn == 1 then
					m = 1
				elseif dIn == 3 then
					m = if ((si + j) // 2) % 3 == 0 then 1 else 4
				elseif dIn == 6 then
					m = 5
				elseif dIn == 9 then
					m = 6
				elseif dIn % 2 == 0 then
					m = 2
				else
					m = 3
				end
				mat[j][i] = m
			end
		end
	end
	-- merge equal runs along x, then equal runs up the rows
	local active = {}
	local function emit(a, jEnd)
		local mm = MATS[a.m]
		box(
			"ArchStone",
			-24 + 2 * a.i0,
			24 + 2 * a.j0,
			Z0,
			-24 + 2 * (a.i1 + 1),
			24 + 2 * jEnd,
			Z1,
			mm[1],
			mm[2],
			gf
		)
	end
	for j = 0, NY do
		local segs = {}
		if j < NY then
			local i = 0
			while i < NX do
				if kind[j][i] == 2 then
					local m, i1 = mat[j][i], i
					while i1 + 1 < NX and kind[j][i1 + 1] == 2 and mat[j][i1 + 1] == m do
						i1 += 1
					end
					segs[i .. ":" .. i1 .. ":" .. m] = { i, i1, m }
					i = i1 + 1
				else
					i += 1
				end
			end
		end
		for key, a in pairs(active) do
			if not segs[key] then
				emit(a, j)
				active[key] = nil
			end
		end
		for key, s in pairs(segs) do
			if not active[key] then
				active[key] = { j0 = j, i0 = s[1], i1 = s[2], m = s[3] }
			end
		end
	end
	task.wait()
	-- the gem at the apex and the gold cross finial
	box("GemSetting", -3, 99.5, -163, 3, 100.5, -157, "px_gold_block", GOLD, gf)
	local gem = neon("Gem", -2, 100.5, -162, 2, 104.5, -158, Color3.fromRGB(200, 255, 250), gf)
	glow(gem, 48, 2, Color3.fromRGB(190, 250, 255))
	decor(box("Finial", -0.8, 104.5, -160.8, 0.8, 116, -159.2, "px_gold_block", GOLD, gf))
	decor(box("FinialArm", -3.2, 110, -160.8, 3.2, 111.6, -159.2, "px_gold_block", GOLD, gf))
	-- the veil of light in the opening and the gold threshold
	for _, r in ipairs({
		{ 24, 60, 14 },
		{ 60, 64, 12 },
		{ 64, 68, 10 },
		{ 68, 72, 8 },
		{ 72, 74, 6 },
		{ 74, 76, 4 },
		{ 76, 78, 2 },
	}) do
		local v = decor(
			neon("Veil", -r[3], r[1], -165.6, r[3], r[2], -165.2, Color3.fromRGB(255, 253, 240), gf)
		)
		v.Transparency = 0.5
	end
	box("Threshold", -14, TERRACE_Y - 0.2, Z0, 14, TERRACE_Y + 0.2, Z1, "px_gold_block", GOLD, gf)
	local function side(sx)
		-- the shoulder pinnacles of the arch
		box("ArchPinnacle", sx * 20, 76, -164, sx * 24, 86, -156, "px_smooth_stone", PEARL, gf)
		box(
			"PinnacleBand",
			sx * 19.7,
			80,
			-164.3,
			sx * 24.3,
			82,
			-155.7,
			"px_prismarine",
			JASPER,
			gf
		)
		decor(box("PinnacleTip", sx * 21, 86, -161, sx * 23, 90, -159, "px_gold_block", GOLD, gf))
		-- clustered columns before the jambs: a pier, a front shaft, gold rings and capitals, a pinnacle
		box("ColumnBase", sx * 14, 24, -154, sx * 23, 28, -147, "px_white_stone_bricks", PEARL, gf)
		box(
			"ColumnBaseTrim",
			sx * 14,
			27.4,
			-154,
			sx * 23.3,
			28.2,
			-146.7,
			"px_gold_block",
			GOLD,
			gf
		)
		box("ColumnPier", sx * 14, 28, -154, sx * 22, 60, -150, "px_smooth_stone", PEARL, gf)
		box(
			"ColumnShaft",
			sx * 16,
			28,
			-150,
			sx * 20,
			60,
			-147.5,
			"px_white_stone_bricks",
			CALCITE,
			gf
		)
		box("ColumnRing", sx * 14, 43, -154, sx * 22.3, 44.5, -147.2, "px_gold_block", GOLD, gf)
		box("Capital", sx * 14, 60, -155, sx * 23, 63, -146, "px_gold_block", GOLD, gf)
		box(
			"CapitalBand",
			sx * 14.5,
			63,
			-154.5,
			sx * 22.5,
			64,
			-146.5,
			"px_prismarine",
			JASPER,
			gf
		)
		box(
			"ColumnPinnacle",
			sx * 16.5,
			64,
			-153,
			sx * 20.5,
			72,
			-149,
			"px_smooth_stone",
			PEARL,
			gf
		)
		decor(box("ColumnTip", sx * 17.5, 72, -152, sx * 19.5, 75, -150, "px_gold_block", GOLD, gf))
		-- a gate leaf hinged at (sx·14, -166), swung 76° inward (north); the free edge at x ≈ sx·10.6
		local a = math.rad(76)
		local d = Vector3.new(-sx * math.cos(a), 0, -math.sin(a))
		local cf = CFrame.fromMatrix(V(sx * 14, TERRACE_Y, Z0), d, Vector3.yAxis)
		local zA, zB = math.min(0, sx * 2), math.max(0, sx * 2) -- the leaf lies on the outer side of the hinge line
		local function lp(name, x0, y0, x1, y1, z0, z1, variant, tint, solid)
			local p = part(
				name,
				Vector3.new(x1 - x0, y1 - y0, z1 - z0),
				cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
				tint,
				nil,
				gf
			)
			if variant then
				textured(p, variant, tint)
			end
			if not solid then
				decor(p)
			end
			return p
		end
		lp("LeafFoot", 0, 0, 14, 4, zA, zB, "px_smooth_stone", PEARL, true)
		lp("LeafPanel", 0, 4, 14, 24, zA, zB, "px_smooth_stone", PEARL)
		lp("LeafStile", 0, 24, 2, 48, zA, zB, "px_smooth_stone", PEARL)
		lp("LeafStile", 12, 24, 14, 48, zA, zB, "px_smooth_stone", PEARL)
		lp("LeafTopRail", 2, 44, 12, 48, zA, zB, "px_smooth_stone", PEARL)
		lp("LeafCrest", 4, 48, 10, 50, zA + 0.2, zB - 0.2, "px_gold_block", GOLD)
		lp("LeafMidRail", 2, 24, 12, 26, zA, zB, "px_gold_block", GOLD)
		for _, bx in ipairs({ 4, 7, 10 }) do
			lp("LeafBar", bx - 0.5, 26, bx + 0.5, 44, zA + 0.5, zB - 0.5, "px_iron_block", nil)
		end
		lp("LeafCrossBar", 2, 34.4, 12, 35.6, zA + 0.3, zB - 0.3, "px_gold_block", GOLD)
		for _, face in ipairs({ { zA - 0.25, zA }, { zB, zB + 0.25 } }) do
			local f0, f1 = face[1], face[2]
			lp("LeafInlay", 2, 4, 12, 5, f0, f1, "px_gold_block", GOLD)
			lp("LeafInlay", 2, 19, 12, 20, f0, f1, "px_gold_block", GOLD)
			lp("LeafInlay", 2, 5, 3, 19, f0, f1, "px_gold_block", GOLD)
			lp("LeafInlay", 11, 5, 12, 19, f0, f1, "px_gold_block", GOLD)
			lp("LeafBoss", 5.5, 10.5, 8.5, 13.5, f0, f1, "px_gold_block", GOLD)
		end
		lp("LeafHinge", -0.6, 6, 1, 9, zA - 0.3, zB + 0.3, "px_gold_block", GOLD)
		lp("LeafHinge", -0.6, 38, 1, 41, zA - 0.3, zB + 0.3, "px_gold_block", GOLD)
	end
	for _, sx in ipairs(SIDES) do
		side(sx)
	end
end
task.wait()

-- ================================================================ beyond the gates: the light, the clouds, the beacon
do
	local f = folder("TheLight", gateF)
	local Y = TERRACE_Y
	-- glowing slabs flush on the terrace cells north of the wall (rows of 8-stud cells, merged along x)
	local row = 0
	for zr = -160, -232, -8 do
		local za, zb = zr - 8, math.min(zr, -164)
		local zc = zr - 4
		row += 1
		local color = if row % 2 == 0
			then Color3.fromRGB(255, 238, 190)
			else Color3.fromRGB(255, 251, 238)
		local runStart = nil
		for xg = -128, 128, 8 do
			local inside = xg < 128 and onTerrace(xg + 4, zc)
			if inside and not runStart then
				runStart = xg
			elseif not inside and runStart then
				local p = neon("LightSlab", runStart, Y - 0.2, za, xg, Y + 0.1, zb, color, f)
				p.CastShadow = false
				runStart = nil
			end
		end
	end
	task.wait()
	-- cloud heaps along both sides (decor): positions drawn once and mirrored
	local heaps = {}
	for _ = 1, 9 do
		local s = rng:NextInteger(2, 4)
		local hx = 28 + rng:NextInteger(0, 22) * 4
		local hz = -174 - rng:NextInteger(0, 13) * 4
		local hw = s * 2
		if
			onTerrace(hx - hw, hz - hw)
			and onTerrace(hx + hw, hz - hw)
			and onTerrace(hx - hw, hz + hw)
			and onTerrace(hx + hw, hz + hw)
		then
			table.insert(heaps, { hx, hz, s, rng:NextInteger(-1, 1), rng:NextInteger(-1, 1) })
		end
	end
	for _, sx in ipairs(SIDES) do
		for _, h in ipairs(heaps) do
			local hx, hz, s = sx * h[1], h[2], h[3]
			for k = 0, s - 1 do
				local w = (s - k) * 2
				local ox, oz = sx * h[4] * k * 2, h[5] * k * 2
				local c = box(
					"Cloud",
					hx + ox - w,
					Y + k * B,
					hz + oz - w,
					hx + ox + w,
					Y + (k + 1) * B,
					hz + oz + w,
					"px_white_wool",
					CLOUD,
					f
				)
				decor(c).CastShadow = false
			end
			local puff = box(
				"CloudPuff",
				hx - s * 2 - 2,
				Y,
				hz - 2,
				hx - s * 2 + 2,
				Y + B,
				hz + 2,
				"px_white_wool",
				CLOUD,
				f
			)
			decor(puff).CastShadow = false
		end
	end
	task.wait()
	-- the beacon: an iron base, a glass shell round a glowstone core, the beam
	local bx, bz = BEAM.x, BEAM.z
	box("BeaconBase", bx - 6, Y, bz - 6, bx + 6, Y + 4, bz + 6, "px_iron_block", nil, f)
	box(
		"BeaconTrim",
		bx - 6.3,
		Y + 3.4,
		bz - 6.3,
		bx + 6.3,
		Y + 4.2,
		bz + 6.3,
		"px_gold_block",
		GOLD,
		f
	)
	local core =
		box("BeaconCore", bx - 2, Y + 4, bz - 2, bx + 2, Y + 8, bz + 2, "px_glowstone", nil, f)
	glow(core, 40, 1.6, LIGHT)
	local shell = box(
		"BeaconGlass",
		bx - 4,
		Y + 4,
		bz - 4,
		bx + 4,
		Y + 10,
		bz + 4,
		nil,
		Color3.fromRGB(200, 240, 255),
		f
	)
	shell.Material = Enum.Material.Glass
	shell.Transparency = 0.55
	shell.CastShadow = false
	local beam = decor(
		neon(
			"BeaconBeam",
			bx - 1.5,
			Y + 4,
			bz - 1.5,
			bx + 1.5,
			600,
			bz + 1.5,
			Color3.fromRGB(255, 248, 222),
			f
		)
	)
	beam.CastShadow = false
	local haze = decor(
		neon(
			"BeaconHaze",
			bx - 4,
			Y + 10,
			bz - 4,
			bx + 4,
			600,
			bz + 4,
			Color3.fromRGB(255, 240, 200),
			f
		)
	)
	haze.Transparency = 0.8
end
task.wait()

-- ================================================================ the gatekeeper's lectern (west of the axis, facing it)
do
	local f = folder("Lectern", gateF)
	local Y = TERRACE_Y
	local lx, lz = -16, -144
	box("LecternBase", lx - 3, Y, lz - 3, lx + 3, Y + 1, lz + 3, "px_white_stone_bricks", PEARL, f)
	box("LecternPost", lx - 2, Y + 1, lz - 2, lx + 2, Y + 5.5, lz + 2, "px_prismarine", JASPER, f)
	box(
		"LecternBand",
		lx - 2.3,
		Y + 1.6,
		lz - 2.3,
		lx + 2.3,
		Y + 2.4,
		lz + 2.3,
		"px_gold_block",
		GOLD,
		f
	)
	box("LecternEmblem", lx + 2, Y + 3, lz - 1, lx + 2.3, Y + 5, lz + 1, "px_gold_block", GOLD, f)
	-- the desk tilts up toward the axis, so the reader stands west of it
	local desk = part(
		"LecternDesk",
		Vector3.new(6, 1, 5),
		at(lx, Y + 6.2, lz) * CFrame.Angles(0, 0, math.rad(18)),
		nil,
		nil,
		f
	)
	textured(desk, "px_gold_block", GOLD)
	local dcf = desk.CFrame
	decor(
		part(
			"BookCover",
			Vector3.new(4, 0.3, 5.6),
			dcf * CFrame.new(0, 0.62, 0),
			Color3.fromRGB(150, 40, 40),
			Enum.Material.Fabric,
			f
		)
	)
	for _, s in ipairs({ -1, 1 }) do
		decor(
			part(
				"BookPage",
				Vector3.new(3.6, 0.5, 2.5),
				dcf * CFrame.new(0, 0.95, s * 1.35),
				Color3.fromRGB(250, 244, 226),
				Enum.Material.SmoothPlastic,
				f
			)
		)
	end
	decor(
		part(
			"BookSpine",
			Vector3.new(3.8, 0.4, 0.3),
			dcf * CFrame.new(0, 1.1, 0),
			GOLD,
			Enum.Material.Metal,
			f
		)
	)
	npc("Gatekeeper", CFrame.lookAt(V(lx - 5, Y + 3, lz), V(0, Y + 3, lz)), {
		skin = Color3.fromRGB(235, 205, 180),
		shirt = Color3.fromRGB(248, 246, 240),
		pants = Color3.fromRGB(236, 232, 220),
	}, f)
end
print(("[build-gate] gates: %d lights"):format(lit))
