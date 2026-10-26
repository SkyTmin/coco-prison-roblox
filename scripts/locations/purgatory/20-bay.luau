-- ================================================================ purgatory: the BAY (the zigzag stair, the relief wall, round the pit)
-- Zone: x -92..92 (cells -96..96), z ≥ -8 at y 0 (the cells of z -16..-8 are already the terrace) and MAIN_UP.
-- THE ZIGZAG (Bom Jesus), mirrored east/west in three bands of 12 against the bay wall (its face is at z -8):
--   R1 z 16..28: the low flights from x ±16 out to ±32, y 0 → 12 (the foot between them: x -12..12, the pool)
--   L1 x ±32..44, z 4..28 (y 12): the side landings with a fountain; the FLANKS x ±12..44, z -8..4 (y 12) with a relief
--   R2 z 4..16: the middle flights from x ±32 back in to ±12, y 12 → 24
--   C2 x -12..12, z 4..20 (y 24): the central landing with two basins; its front face carries the 7th relief
--   F3 x -6..6, z 12 → -8, y 24 → 40 between two stepped water channels (x ±6..10) onto the L5 terrace
--   MAIN_UP x -8..8 (kerbs to ±10), z -16 → -32, y 40 → 48: the summit plaza edge is z -32 for |x| ≤ 24
do
	local bayF = folder("Bay")
	local CUT, SANDV = "px_cut_sandstone", "px_sandstone"
	local RELIEF = Color3.fromRGB(206, 170, 120) -- the darker sandstone of the carved figures
	local GLASS = Color3.fromRGB(225, 240, 245)
	local ROPE = Color3.fromRGB(120, 95, 60)
	local partsAtStart = count
	local skipped = 0

	-- a box along a flight: `a` runs along `axis` ("x" or "z"), `c` across it
	local function abox(axis, name, a0, a1, c0, c1, y0, y1, var, tint, parent)
		if axis == "x" then
			return box(name, a0, y0, c0, a1, y1, c1, var, tint, parent)
		end
		return box(name, c0, y0, a0, c1, y1, a1, var, tint, parent)
	end
	-- water: our pixel water, translucent, no collision
	local function water(x0, y0, z0, x1, y1, z1, parent)
		local p = decor(box("Water", x0, y0, z0, x1, y1, z1, "px_water", WATER, parent))
		p.Transparency = 0.25
		p.CastShadow = false
		return p
	end
	-- a brazier: a stone brick block, a bowl (blackstone, soul soil for the blue fire), the flame blocks
	local function brazier(x, y, z, soul, lit, parent, noBase)
		local bf = folder(if soul then "SoulBrazier" else "Brazier", parent)
		local col = if soul then SOUL_FIRE else FIRE
		local top = y
		if not noBase then
			box("BrazierBase", x - 2, y, z - 2, x + 2, y + 3, z + 2, "px_stone_bricks", nil, bf)
			top = y + 3
		end
		box(
			"BrazierBowl",
			x - 2.4,
			top,
			z - 2.4,
			x + 2.4,
			top + 1.4,
			z + 2.4,
			if soul then "px_soul_soil" else "px_blackstone",
			nil,
			bf
		)
		local fl = decor(
			part(
				"BrazierFire",
				Vector3.new(3, 2.2, 3),
				at(x, top + 2.3, z),
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
				Vector3.new(1.6, 1.6, 1.6),
				at(x - 0.3, top + 3.9, z + 0.3),
				col,
				Enum.Material.Neon,
				bf
			)
		)
		tip.Transparency = 0.3
		tip.CastShadow = false
		if lit then
			light(fl, 30, 1.4, col)
			emitter(fl, {
				Rate = 6,
				Lifetime = NumberRange.new(0.4, 0.8),
				Speed = NumberRange.new(2, 3.5),
				Size = NumberSequence.new(1, 0.1),
				Color = ColorSequence.new(col),
				LightEmission = 1,
				SpreadAngle = Vector2.new(12, 12),
			})
		end
		return bf
	end
	-- a flight: kit stairs (cut sandstone) + a stepped sandstone fill under it (4-stud chunks, down to `base`) +
	-- balustrades `rails` = { {c0, c1, base}, ... } beside it, each chunk one step above the flight, posts and gaps in turn
	local function flight(name, axis, c, s0, s1, y0, rise, w, base, rails, parent)
		local f = folder(name, parent)
		stairs(name, c, s0, s1, y0, rise, w, CUT, f, if axis == "x" then "x" else nil)
		for _, p in ipairs(f:GetChildren()) do
			if p:IsA("Part") then
				p.Color = SAND_PALE
			end
		end
		local run = math.abs(s1 - s0)
		local dir = if s1 > s0 then 1 else -1
		local n = math.max(1, math.floor(run / 2))
		local stepD, r = run / n, rise / n
		local d0, j = 0, 0
		while d0 < run - 0.01 do
			local d1 = math.min(d0 + B, run)
			local lowTop = y0 + (math.floor(d0 / stepD + 1e-6) + 1) * r
			local highTop = y0 + math.ceil(d1 / stepD - 1e-6) * r
			local a0, a1 = s0 + dir * d0, s0 + dir * d1
			if lowTop - 0.5 > base + 0.2 then
				abox(
					axis,
					name .. "Fill",
					a0,
					a1,
					c - w / 2,
					c + w / 2,
					base,
					lowTop - 0.5,
					SANDV,
					SAND,
					f
				)
			end
			for _, rl in ipairs(rails or {}) do
				abox(
					axis,
					name .. "Rail",
					a0,
					a1,
					rl[1],
					rl[2],
					rl[3],
					highTop + (if j % 2 == 0 then 3 else 1.8),
					CUT,
					SAND,
					f
				)
			end
			d0, j = d1, j + 1
		end
		return f
	end
	-- a flat balustrade (posts and lower gaps in turn) along `axis` from a0 to a1 over a floor at floorY (the first
	-- post at a0, so mirrored rails match)
	local function flatRail(name, axis, a0, a1, c0, c1, base, floorY, parent)
		local dir = if a1 > a0 then 1 else -1
		local d, run, j = 0, math.abs(a1 - a0), 0
		while d < run - 0.01 do
			local e = math.min(d + B, run)
			local top = floorY + (if j % 2 == 0 then 3 else 1.8)
			abox(axis, name, a0 + dir * d, a0 + dir * e, c0, c1, base, top, CUT, SAND, parent)
			d, j = e, j + 1
		end
	end

	-- a soul: a pale translucent blocky figure (no collision); cf at its feet, looking along its -Z
	-- pose: "stand", "bow" (head down, waiting), "carry" (a block in the arms), "pull" (arms back), "kneel", "sit"
	local soulsF = folder("Souls", bayF)
	local function soul(cf, pose, parent)
		parent = parent or soulsF
		local function sp(name, sx, sy, sz, ox, oy, oz)
			local p = decor(
				part(
					name,
					Vector3.new(sx, sy, sz),
					cf * CFrame.new(ox, oy, oz),
					SOUL,
					Enum.Material.SmoothPlastic,
					parent
				)
			)
			p.Transparency = 0.5
			p.CastShadow = false
			return p
		end
		if pose == "sit" then
			sp("SoulThighs", 1.8, 0.9, 2, 0, 0.45, -0.9)
			sp("SoulShins", 1.8, 2.4, 0.9, 0, -1.1, -1.9)
			sp("SoulTorso", 2, 2.4, 1, 0, 2.1, 0.1)
			sp("SoulHead", 1.5, 1.5, 1.5, 0, 4.05, 0)
			sp("SoulArm", 0.7, 2, 0.7, -1.35, 1.9, -0.3)
			sp("SoulArm", 0.7, 2, 0.7, 1.35, 1.9, -0.3)
			return
		end
		if pose == "kneel" then
			sp("SoulThighs", 1.8, 1.4, 1, 0, 1.5, 0)
			sp("SoulShins", 1.8, 0.8, 2, 0, 0.4, 0.6)
			sp("SoulTorso", 2, 2.4, 1, 0, 3.4, -0.1)
			sp("SoulHead", 1.5, 1.5, 1.5, 0, 5.35, -0.3)
			sp("SoulArm", 0.7, 0.7, 2, -1.3, 3.2, -1.1)
			sp("SoulArm", 0.7, 0.7, 2, 1.3, 3.2, -1.1)
			return
		end
		sp("SoulLegs", 1.8, 2.6, 0.9, 0, 1.3, 0)
		sp("SoulTorso", 2, 2.4, 1, 0, 3.8, 0)
		sp(
			"SoulHead",
			1.5,
			1.5,
			1.5,
			0,
			if pose == "bow" then 5.55 else 5.75,
			if pose == "bow" then -0.35 else 0
		)
		if pose == "carry" then
			sp("SoulArm", 0.7, 0.7, 1.8, -1.3, 4.3, -0.9)
			sp("SoulArm", 0.7, 0.7, 1.8, 1.3, 4.3, -0.9)
			local blk = decor(
				part(
					"CarriedBlock",
					Vector3.new(2.4, 2.4, 2.4),
					cf * CFrame.new(0, 4.5, -2.1),
					nil,
					nil,
					parent
				)
			)
			textured(blk, CUT, SAND)
		elseif pose == "pull" then
			sp("SoulArm", 0.7, 0.7, 1.8, -1.3, 3.6, 0.9)
			sp("SoulArm", 0.7, 0.7, 1.8, 1.3, 3.6, 0.9)
		else
			sp("SoulArm", 0.7, 2.3, 0.7, -1.35, 3.75, 0)
			sp("SoulArm", 0.7, 2.3, 0.7, 1.35, 3.75, 0)
		end
	end
	local function sAt(x, y, z, yaw)
		return at(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	end
	-- props on the bay floor only where the core built y 0 and nothing else is
	local function okGround(x, z, pad)
		if cellY(x, z) == 0 and freeGround(x, z, pad) then
			return true
		end
		skipped += 1
		return false
	end

	-- ================================================================ 1. the zigzag stair with fountains
	do
		local zz = folder("Zigzag", bayF)
		-- C2, the central landing (y 24), its cornice and front balustrade
		box("CentralLanding", -12, 0, 4, 12, 24, 20, SANDV, SAND, zz)
		box("CentralCornice", -12.4, 22, 19.8, 12.4, 24.2, 20.6, CUT, SAND_PALE, zz)
		flatRail("FrontRail", "x", -8, 8, 18, 20, 23, 24, zz)
		-- the foot pool before C2 (fed by two spouts in its face)
		box("PoolFloor", -11, 0, 20, 11, 0.2, 24, CUT, SAND, zz)
		box("PoolRim", -12, 0, 24, 12, 1.6, 25, CUT, SAND_PALE, zz)
		water(-11, 0.2, 20.6, 11, 1.2, 24, zz)
		-- F3: the top flight between the channels, onto the L5 terrace
		flight("FlightTop", "z", 0, 12, -8, 24, 16, 12, 0, nil, zz)
		for _, s in ipairs({ -1, 1 }) do
			-- F1 (out, y 0 → 12) and F2 (back in, y 12 → 24); F2's stringer walls stand in F1's band and on the flank
			flight("FlightLow", "x", 22, s * 16, s * 32, 0, 12, 12, 0, { { 28, 30, 0 } }, zz)
			flight(
				"FlightMid",
				"x",
				10,
				s * 32,
				s * 12,
				12,
				12,
				12,
				0,
				{ { 16, 18, 0 }, { 2, 4, 0 } },
				zz
			)
			-- L1 (the side landing) and the flank in front of the wall, both y 12
			box("SideLanding", s * 32, 0, 4, s * 44, 12, 28, SANDV, SAND, zz)
			box("Flank", s * 12, 0, -8, s * 44, 12, 4, SANDV, SAND, zz)
			flatRail("LandingRail", "x", s * 32, s * 46, 28, 30, 0, 12, zz)
			flatRail("LandingRail", "z", -8, 28, s * 44, s * 46, 0, 12, zz)
			-- the fountain on L1: a basin, a column with a bowl and a spout of water
			do
				local fx, fz = s * 40, 16
				box("FountainRim", fx - 4, 12, fz - 4, fx + 4, 14, fz - 3, CUT, SAND_PALE, zz)
				box("FountainRim", fx - 4, 12, fz + 3, fx + 4, 14, fz + 4, CUT, SAND_PALE, zz)
				box("FountainRim", fx - 4, 12, fz - 3, fx - 3, 14, fz + 3, CUT, SAND_PALE, zz)
				box("FountainRim", fx + 3, 12, fz - 3, fx + 4, 14, fz + 3, CUT, SAND_PALE, zz)
				water(fx - 3, 12, fz - 3, fx + 3, 13.4, fz + 3, zz)
				box("FountainColumn", fx - 1, 12, fz - 1, fx + 1, 16, fz + 1, CUT, SAND, zz)
				box(
					"FountainBowl",
					fx - 1.8,
					16,
					fz - 1.8,
					fx + 1.8,
					17,
					fz + 1.8,
					CUT,
					SAND_PALE,
					zz
				)
				water(fx - 1.4, 16.6, fz - 1.4, fx + 1.4, 17.2, fz + 1.4, zz)
				water(fx - 2.2, 13.2, fz - 0.4, fx - 1.8, 16.8, fz + 0.4, zz)
				water(fx + 1.8, 13.2, fz - 0.4, fx + 2.2, 16.8, fz + 0.4, zz)
			end
			-- the water channel beside F3: two stepped strips with small falls, from a spout block at the wall down
			-- into a basin on C2
			local tops = { 32, 35.2 } -- the lower step top of F3 beside each channel chunk (z 4..0, z 0..-4)
			for c = 0, 1 do
				local za, zb = 4 - 4 * c, -4 * c
				local lt = tops[c + 1]
				box("ChannelBed", s * 6, 0, zb, s * 10, lt - 1.5, za, CUT, SAND, zz)
				water(s * 6.2, lt - 1.5, zb, s * 9.8, lt - 0.6, za, zz)
				local below = if c == 0 then 25.6 else tops[1] - 0.6
				water(s * 6.2, below, za - 0.4, s * 9.8, lt - 0.6, za + 0.3, zz)
			end
			box("ChannelSource", s * 6, 0, -8, s * 10, 44, -4, CUT, SAND, zz)
			decor(
				box(
					"SourceMask",
					s * 6.6,
					38.6,
					-4,
					s * 9.4,
					42.4,
					-3.4,
					"px_cut_red_sandstone",
					nil,
					zz
				)
			)
			box("SourceSpout", s * 7.2, 38, -4, s * 8.8, 38.8, -2.6, CUT, SAND_PALE, zz)
			water(s * 7.3, tops[2] - 0.6, -3.4, s * 8.7, 38.2, -2.7, zz)
			brazier(s * 8.4, 44, -6, true, true, zz, true)
			for _, rr in ipairs({ { 4, 0, 36.6 }, { 0, -4, 38.6 }, { -4, -8, 43 } }) do
				box("ChannelRail", s * 10, 0, rr[2], s * 12, rr[3], rr[1], CUT, SAND, zz)
			end
			-- the basin on C2 that the channel falls into, and the spout in C2's face down into the foot pool
			box("BasinRim", s * 6, 24, 7, s * 12, 26, 8, CUT, SAND_PALE, zz)
			box("BasinRim", s * 11, 24, 4, s * 12, 26, 7, CUT, SAND_PALE, zz)
			water(s * 6, 24, 4, s * 11, 25.6, 7, zz)
			box("PoolRim", s * 11, 0, 20, s * 12, 1.6, 24, CUT, SAND_PALE, zz)
			box("FaceSpout", s * 9, 17, 20, s * 11, 19, 21.6, CUT, SAND_PALE, zz)
			water(s * 9.4, 1, 21, s * 10.6, 17.4, 21.6, zz)
			-- braziers on the landing corners (fire and soul fire)
			brazier(s * 10, 24, 18, false, true, zz)
			brazier(s * 42, 12, 26, false, true, zz)
			brazier(s * 42, 12, 6, true, true, zz)
			brazier(s * 16, 12, -6, true, true, zz)
			brazier(s * 42, 12, -6, false, false, zz)
			-- decorated pots on L1 and the flank
			do
				local c = Color3.fromRGB(205, 120, 80)
				for _, pz in ipairs({ 26, -2 }) do
					local px = s * 38
					box(
						"Pot",
						px - 1.5,
						12,
						pz - 1.5,
						px + 1.5,
						15,
						pz + 1.5,
						"px_terracotta",
						c,
						zz
					)
					box(
						"PotRim",
						px - 1.2,
						15,
						pz - 1.2,
						px + 1.2,
						15.8,
						pz + 1.2,
						"px_terracotta",
						c,
						zz
					)
					decor(
						box(
							"PotBand",
							px - 1.55,
							13.2,
							pz - 1.55,
							px + 1.55,
							13.8,
							pz + 1.55,
							"px_terracotta",
							Color3.fromRGB(120, 60, 40),
							zz
						)
					)
				end
			end
			-- the obelisks with red banners flanking the foot
			do
				local ox, oz = s * 10, 30
				box(
					"ObeliskBase",
					ox - 2.4,
					0,
					oz - 2.4,
					ox + 2.4,
					4,
					oz + 2.4,
					"px_stone_bricks",
					nil,
					zz
				)
				box("ObeliskShaft", ox - 2, 4, oz - 2, ox + 2, 24, oz + 2, CUT, SAND_PALE, zz)
				box(
					"ObeliskTip",
					ox - 1.4,
					24,
					oz - 1.4,
					ox + 1.4,
					26,
					oz + 1.4,
					CUT,
					SAND_PALE,
					zz
				)
				box(
					"ObeliskGold",
					ox - 0.8,
					26,
					oz - 0.8,
					ox + 0.8,
					27.4,
					oz + 0.8,
					"px_gold_block",
					nil,
					zz
				)
				for _, d in ipairs({ -1, 1 }) do
					decor(
						box(
							"ObeliskBanner",
							ox - 1.4,
							8,
							oz + d * 2,
							ox + 1.4,
							20,
							oz + d * 2.2,
							"px_white_wool",
							BANNER_RED,
							zz
						)
					)
					decor(
						box(
							"ObeliskBanner",
							ox + d * 2,
							8,
							oz - 1.4,
							ox + d * 2.2,
							20,
							oz + 1.4,
							"px_white_wool",
							BANNER_RED,
							zz
						)
					)
					decor(
						box(
							"ObeliskMotif",
							ox - 0.6,
							15.6,
							oz + d * 2.2,
							ox + 0.6,
							16.8,
							oz + d * 2.3,
							"px_gold_block",
							nil,
							zz
						)
					)
				end
			end
			-- MAIN_UP's foot: braziers on the terrace either side of the walking line
			brazier(s * 8.4, 40, -10, false, true, zz)
			-- unlit lanterns on the balustrade posts (the glow without a light: the PointLight budget is small)
			for _, lp in ipairs({
				{ s * 11, 37.35, 2 },
				{ s * 34, 15.75, 29 },
				{ s * 18, 6.75, 29 },
			}) do
				local lf = folder("Lantern", zz)
				lantern(V(lp[1], lp[2], lp[3]), lf)
				for _, d in ipairs(lf:GetDescendants()) do
					if d:IsA("PointLight") then
						d:Destroy()
					end
				end
			end
			-- a red banner on the wall above each flank's soul brazier
			banner(at(s * 16, 29, -7.7), BANNER_RED, zz, GOLD, 3, 8)
		end
		-- MAIN_UP: one flight from the L5 terrace (y 40) to the summit plaza (y 48, its edge at z -32), with kerbs
		flight("MainUp", "z", 0, -16, -32, 40, 8, 16, 40, { { -10, -8, 40 }, { 8, 10, 40 } }, zz)
		-- a few souls on the way up, looking at the water
		soul(sAt(-2, 24, 16, 0.4), "stand")
		soul(sAt(3, 24, 15, -0.3), "bow")
		soul(sAt(34, 12, 22, -math.pi / 2), "stand")
		soul(sAt(-26, 12, -2, 0), "bow")
	end
	task.wait()

	-- ================================================================ 2. the relief wall: 7 slabs, one per sin
	do
		local rf = folder("Reliefs", bayF)
		local G, W, R, I = "px_gold_block", "px_white_wool", "px_white_wool", "px_iron_block"
		-- the figures in panel units: u -6..6 across the field, v 2..18 up; { u0, v0, u1, v1, proud, variant, tint }
		local LEGS = { { -2, 2.4, -0.3, 7.6 }, { 0.3, 2.4, 2, 7.6 } }
		local BODY = { { -2.2, 7.6, 2.2, 12.4 }, { -1.4, 12.6, 1.4, 15.4 } }
		local function with(list, extra)
			local out = table.clone(list)
			for _, e in ipairs(extra) do
				table.insert(out, e)
			end
			return out
		end
		local STD = with(LEGS, BODY)
		local ART = {
			-- pride: a robed figure with a cape, arms akimbo, a golden crown
			Pride = with(BODY, {
				{ -3.2, 4, 3.2, 12.4, 0.4, nil, Color3.fromRGB(190, 150, 100) },
				{ -2.6, 2.2, 2.6, 7.8 },
				{ -3.6, 9.6, -2.2, 12.2 },
				{ 2.2, 9.6, 3.6, 12.2 },
				{ -3.2, 8.6, -2.2, 9.6 },
				{ 2.2, 8.6, 3.2, 9.6 },
				{ -1.6, 15.4, 1.6, 16.2, 1.1, G },
				{ -1.6, 16.2, -1, 17, 1.1, G },
				{ -0.3, 16.2, 0.3, 17.2, 1.1, G },
				{ 1, 16.2, 1.6, 17, 1.1, G },
			}),
			-- envy: a figure reaching up toward a great green eye
			Envy = with(STD, {
				{ -3.4, 8, -2.2, 12.2 },
				{ 2.2, 10.4, 3.4, 12.2 },
				{ 2.6, 12.2, 3.6, 13.8 },
				{ 1.6, 14.4, 5.6, 16.2, 1, W, Color3.fromRGB(245, 240, 230) },
				{ 2.4, 16.2, 4.8, 16.8 },
				{ 2.4, 13.8, 4.8, 14.4 },
				{ 3, 14.6, 4.2, 16, 1.2, W, Color3.fromRGB(60, 150, 70) },
				{ 3.4, 15, 3.8, 15.6, 1.3, W, Color3.fromRGB(30, 40, 30) },
			}),
			-- wrath: a sword raised high
			Wrath = with(STD, {
				{ -3.4, 8, -2.2, 12.2 },
				{ 2.2, 11, 3.4, 15.6 },
				{ 2.5, 15.6, 3.1, 17.8, 1.1, I },
				{ 1.7, 15.2, 3.9, 15.6, 1.1, I },
				{ -2.6, 14.6, -1.4, 15.8 },
				{ 1.4, 14.6, 2.6, 15.8 },
			}),
			-- sloth: lying on a ledge, three blocks of sleep rising
			Sloth = {
				{ -6, 2, 6, 3, 1, CUT, SAND_PALE },
				{ -5.6, 3, -1, 4.6 },
				{ -1, 3, 3, 5.4 },
				{ 3, 3, 5.4, 5.8 },
				{ -0.6, 5.4, 2.4, 6.2 },
				{ 1, 8, 2, 9, 0.6 },
				{ 2.6, 10, 3.8, 11.2, 0.6 },
				{ 4.2, 12.4, 5.8, 14, 0.6 },
			},
			-- greed: a money bag in the arms, gold coins piled at the feet
			Greed = with(STD, {
				{ -3.4, 9, -2.2, 12.2 },
				{ 2.2, 9, 3.4, 12.2 },
				{ -1.8, 8.4, 1.8, 11, 1.2, "px_brown_wool" },
				{ -0.6, 11, 0.6, 11.6, 1.2, "px_brown_wool" },
				{ -5.4, 2, -2.6, 3.2, 1, G },
				{ -5, 3.2, -3, 4.2, 1, G },
				{ 2.6, 2, 5.4, 3.2, 1, G },
				{ 3, 3.2, 5, 4.2, 1, G },
				{ 4.4, 6, 5.2, 6.8, 1, G },
				{ -5.2, 7.2, -4.4, 8, 1, G },
			}),
			-- gluttony: a great belly, a golden goblet raised
			Gluttony = with(LEGS, {
				{ -3, 7.4, 3, 12.4 },
				{ -2.2, 8, 2.2, 11.2, 1.4 },
				{ -1.4, 12.6, 1.4, 15.4 },
				{ -4.2, 8, -3, 12 },
				{ 3, 10.4, 4.2, 13.6 },
				{ 3.3, 13.6, 5.1, 14, 1.1, G },
				{ 3.9, 14, 4.5, 14.8, 1.1, G },
				{ 3.2, 14.8, 5.2, 16.6, 1.1, G },
				{ 3.4, 16.2, 5, 16.7, 1.2, R, BANNER_RED },
			}),
			-- lust: a figure reaching for a red heart
			Lust = {
				{ -4.5, 2.4, -2.8, 7.6 },
				{ -2.2, 2.4, -0.5, 7.6 },
				{ -4.7, 7.6, -0.3, 12.4 },
				{ -3.9, 12.6, -1.1, 15.4 },
				{ -5.8, 8, -4.7, 12.2 },
				{ -0.3, 11, 1.6, 12 },
				{ 1.4, 12, 3.2, 13, 1.2, R, BANNER_RED },
				{ 3.8, 12, 5.6, 13, 1.2, R, BANNER_RED },
				{ 1, 11, 6, 12, 1.2, R, BANNER_RED },
				{ 1.6, 10, 5.4, 11, 1.2, R, BANNER_RED },
				{ 2.4, 9, 4.6, 10, 1.2, R, BANNER_RED },
				{ 3.1, 8.3, 3.9, 9, 1.2, R, BANNER_RED },
			},
		}
		local NAMES = {
			Pride = "Гордыня",
			Envy = "Зависть",
			Wrath = "Гнев",
			Sloth = "Уныние",
			Greed = "Алчность",
			Gluttony = "Чревоугодие",
			Lust = "Сладострастие",
		}
		-- a slab 4×5 blocks on a wall face at z = zf (it grows toward +Z), its bottom at y0, on a plinth below
		local function relief(cx, y0, zf, sin)
			local f = folder("Relief" .. sin, rf)
			local function rb(name, u0, v0, u1, v1, d0, d1, var, tint)
				return box(name, cx + u0, y0 + v0, zf + d0, cx + u1, y0 + v1, zf + d1, var, tint, f)
			end
			rb("ReliefPlinth", -9, -2, 9, 0, 0, 2.6, CUT, SAND)
			rb("ReliefPanel", -8, 0, 8, 20, 0, 1, SANDV, SAND_PALE)
			rb("ReliefFrame", -8, 0, -6, 20, 0, 2, CUT, SAND)
			rb("ReliefFrame", 6, 0, 8, 20, 0, 2, CUT, SAND)
			rb("ReliefFrame", -6, 0, 6, 2, 0, 2, CUT, SAND)
			rb("ReliefFrame", -6, 18, 6, 20, 0, 2, CUT, SAND)
			rb("ReliefCornice", -9, 20, 9, 21, 0, 2.6, CUT, SAND_PALE)
			for _, e in ipairs(ART[sin]) do
				decor(
					rb(
						"ReliefFigure",
						e[1],
						e[2],
						e[3],
						e[4],
						0.9,
						1 + (e[5] or 0.8),
						e[6] or SANDV,
						e[7] or (if e[6] then nil else RELIEF)
					)
				)
			end
			local plaque = decor(rb("ReliefPlaque", -4, 0.2, 4, 1.8, 1.9, 2.3, CUT, SAND_PALE))
			boardText(plaque, NAMES[sin], Color3.fromRGB(90, 60, 30), { Enum.NormalId.Back })
		end
		-- the outer wall (24..32 high) either side of the zigzag, the flanks of the zigzag, the face of C2
		relief(-82, 2, -8, "Pride")
		relief(-62, 2, -8, "Envy")
		relief(-28, 14, -8, "Wrath")
		relief(0, 2, 20, "Sloth")
		relief(28, 14, -8, "Greed")
		relief(62, 2, -8, "Gluttony")
		relief(82, 2, -8, "Lust")
		for _, s in ipairs({ -1, 1 }) do
			brazier(s * 72, 0, -2, s > 0, true, rf)
			brazier(s * 50, 0, -5, true, false, rf)
			brazier(s * 93.6, 0, -5, false, false, rf)
			-- red banners hanging on the wall between the slabs
			banner(at(s * 72, 16, -7.7), BANNER_RED, rf, GOLD, 3, 8)
			banner(at(s * 50, 18, -7.7), BANNER_RED, rf, GOLD, 4, 10)
		end
	end
	task.wait()

	-- ================================================================ 3. round the pit: the fence, the stones, the souls
	do
		local pf = folder("PitSurround", bayF)
		-- the fence 1 block outside the rim, open at the four ladder shafts (the south opening wider: the arrival)
		local fz0, fz1, fx = 36, 184, 74
		fence(-fx, fz0, -12, fz0, pf)
		fence(12, fz0, fx, fz0, pf)
		fence(-fx, fz1, -28, fz1, pf)
		fence(28, fz1, fx, fz1, pf)
		for _, s in ipairs({ -1, 1 }) do
			fence(s * fx, fz0, s * fx, 98, pf)
			fence(s * fx, 122, s * fx, fz1, pf)
		end
		-- blocks of chiseled sandstone lying about: whole, half-cut, notched, stacked
		local function pile(cx, cz, n)
			local spots = {
				{ -4, -4 },
				{ 0, -4 },
				{ 4, -4 },
				{ -4, 0 },
				{ 0, 0 },
				{ 4, 0 },
				{ -4, 4 },
				{ 0, 4 },
				{ 4, 4 },
			}
			for i = #spots, 2, -1 do
				local j = rng:NextInteger(1, i)
				spots[i], spots[j] = spots[j], spots[i]
			end
			for i = 1, math.min(n, #spots) do
				local x, z = cx + spots[i][1], cz + spots[i][2]
				if okGround(x, z, -2) then
					local kind = rng:NextInteger(1, 5)
					local var = if rng:NextNumber() < 0.75 then CUT else SANDV
					if kind == 1 then
						box("StoneHalf", x - 2, 0, z - 2, x + 2, 2, z + 2, var, SAND, pf)
					elseif kind == 2 then
						box("StoneNotched", x - 2, 0, z - 2, x + 2, 4, z, var, SAND, pf)
						box("StoneNotched", x - 2, 0, z, x + 2, 2, z + 2, var, SAND, pf)
					elseif kind == 3 then
						box("Stone", x - 2, 0, z - 2, x + 2, 4, z + 2, var, SAND, pf)
						box("Stone", x - 2, 4, z - 2, x + 2, 8, z + 2, CUT, SAND_PALE, pf)
					else
						box("Stone", x - 2, 0, z - 2, x + 2, 4, z + 2, var, SAND, pf)
					end
				end
			end
		end
		pile(-86, 44, 6)
		pile(-84, 140, 5)
		pile(84, 140, 5)
		pile(86, 82, 4)
		-- the west side: two souls chiseling at the pile, four carrying blocks up from the west ladder
		soul(sAt(-80, 0, 40, math.pi / 2), "kneel")
		soul(sAt(-80, 0, 49, math.pi / 2), "kneel")
		for k = 0, 3 do
			soul(sAt(-81 - (k % 2), 0, 62 + 8 * k, 0), "carry")
		end
		-- the east side: four souls carrying blocks south toward the arrival, one chiseling
		for k = 0, 3 do
			soul(sAt(81 + (k % 2), 0, 166 + 5.5 * k, math.pi), "carry")
		end
		soul(sAt(77, 0, 140, -math.pi / 2), "kneel")
		-- a sled with blocks, two souls pulling it north toward the derrick
		do
			local sx, sz = 86, 68
			if okGround(sx, sz, 0) then
				local sl = folder("Sled", pf)
				box(
					"SledRunner",
					sx - 3,
					0,
					sz - 6,
					sx - 2,
					0.8,
					sz + 6,
					"px_dark_oak_planks",
					nil,
					sl
				)
				box(
					"SledRunner",
					sx + 2,
					0,
					sz - 6,
					sx + 3,
					0.8,
					sz + 6,
					"px_dark_oak_planks",
					nil,
					sl
				)
				box(
					"SledCurl",
					sx - 3,
					0.8,
					sz - 6.8,
					sx + 3,
					1.6,
					sz - 6,
					"px_dark_oak_planks",
					nil,
					sl
				)
				box(
					"SledDeck",
					sx - 3,
					0.8,
					sz - 5,
					sx + 3,
					1.6,
					sz + 5,
					"px_spruce_planks",
					nil,
					sl
				)
				box("SledStone", sx - 2.8, 1.6, sz - 4.6, sx + 0.2, 4.6, sz - 1.6, CUT, SAND, sl)
				box("SledStone", sx - 0.2, 1.6, sz + 0.4, sx + 2.8, 4.6, sz + 3.4, CUT, SAND, sl)
				box("SledStone", sx - 2.6, 1.6, sz + 0.6, sx - 0.4, 3.8, sz + 4.6, SANDV, SAND, sl)
				box("SledStone", sx - 1, 4.6, sz + 0.6, sx + 2, 7.6, sz + 3.6, CUT, SAND_PALE, sl)
				for _, px in ipairs({ -2.5, 2.5 }) do
					soul(sAt(sx + px, 0, sz - 12, 0), "pull")
					decor(
						beam(
							"SledRope",
							V(sx + px * 0.8, 1.2, sz - 6.4),
							V(sx + px * 1.04, 3.6, sz - 11.2),
							0.25,
							ROPE,
							sl,
							Enum.Material.Fabric
						)
					)
				end
			end
		end
		-- a derrick of dark oak swinging a block over the pit, a soul at the winch
		do
			local dx, dz = 84, 42
			local df = folder("Derrick", pf)
			box("DerrickBase", dx - 4, 0, dz - 4, dx + 4, 2, dz + 4, CUT, SAND, df)
			box("DerrickMast", dx - 1, 2, dz - 1, dx + 1, 28, dz + 1, "px_dark_oak_log", nil, df)
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
				textured(
					beam(
						"DerrickBrace",
						V(dx + c[1] * 3.4, 2, dz + c[2] * 3.4),
						V(dx + c[1] * 0.6, 12, dz + c[2] * 0.6),
						0.9,
						nil,
						df
					),
					"px_dark_oak_planks"
				)
			end
			local tip = V(58, 25, 54)
			decor(
				textured(
					beam("DerrickBoom", V(dx, 21, dz), tip, 1.4, nil, df),
					"px_dark_oak_planks"
				)
			)
			decor(
				beam(
					"DerrickStay",
					V(dx, 28, dz),
					tip + Vector3.new(0, 0.6, 0),
					0.3,
					ROPE,
					df,
					Enum.Material.Fabric
				)
			)
			decor(
				beam(
					"DerrickGuy",
					V(dx, 27.6, dz),
					V(dx + 8, 0.5, dz - 12),
					0.3,
					ROPE,
					df,
					Enum.Material.Fabric
				)
			)
			box("GuyStake", dx + 7, 0, dz - 13, dx + 9, 1.2, dz - 11, "px_dark_oak_planks", nil, df)
			local ropeLen = tip.Y - BY - 8.2
			decor(
				part(
					"DerrickRope",
					Vector3.new(0.3, ropeLen, 0.3),
					CFrame.new(tip.X, tip.Y - ropeLen / 2, tip.Z),
					ROPE,
					Enum.Material.Fabric,
					df
				)
			)
			local hung = decor(part("HungBlock", Vector3.new(B, B, B), at(58, 6, 54), nil, nil, df))
			textured(hung, CUT, SAND)
			decor(
				part(
					"HungSling",
					Vector3.new(B + 0.2, 0.4, 0.6),
					at(58, 8.1, 54),
					ROPE,
					Enum.Material.Fabric,
					df
				)
			)
			crate(dx + 5, 0, dz + 7, df)
			soul(sAt(dx + 1, 0, dz + 8, -math.pi / 2), "pull")
		end
		-- braziers at the pit's north corners
		brazier(-84, 0, 32, false, true, pf)
		brazier(84, 0, 32, true, true, pf)
	end
	task.wait()

	-- ================================================================ 4. hourglasses, cypresses, bushes, pots, benches
	do
		local gf = folder("Garden", bayF)
		-- a giant hourglass (s = 1: 3×3 blocks, 6 high): dark oak plates and posts, glass bulbs, sand, gold caps
		local GLASS_L = {
			{ 2.6, 6, 8 },
			{ 6, 9, 6 },
			{ 9, 11, 4 },
			{ 11, 13, 2 },
			{ 13, 15, 4 },
			{ 15, 18, 6 },
			{ 18, 21.4, 8 },
		}
		local SAND_L = {
			{ 2.6, 5, 7.4 },
			{ 5, 7, 5.4 },
			{ 7, 8.2, 3.4 },
			{ 13, 15, 3.4 },
			{ 15, 16.4, 5.4 },
			{ 8.2, 13, 0.5 },
		}
		local function hourglass(x, z, s)
			local f = folder("Hourglass", gf)
			local function hb(name, w, y0, y1, var, tint)
				return box(
					name,
					x - w * s / 2,
					y0 * s,
					z - w * s / 2,
					x + w * s / 2,
					y1 * s,
					z + w * s / 2,
					var,
					tint,
					f
				)
			end
			hb("HourglassBase", 12, 0, 2, "px_dark_oak_planks")
			hb("HourglassRing", 8.4, 2, 2.6, "px_gold_block")
			hb("HourglassRing", 8.4, 21.4, 22, "px_gold_block")
			hb("HourglassTop", 12, 22, 24, "px_dark_oak_planks")
			hb("HourglassCap", 8, 24, 25.2, "px_gold_block")
			hb("HourglassKnob", 2.4, 25.2, 26.8, "px_gold_block")
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
				local px, pz = x + c[1] * 5 * s, z + c[2] * 5 * s
				box(
					"HourglassPost",
					px - s,
					2 * s,
					pz - s,
					px + s,
					22 * s,
					pz + s,
					"px_dark_oak_log",
					nil,
					f
				)
			end
			for _, l in ipairs(GLASS_L) do
				local g = hb("HourglassGlass", l[3], l[1], l[2])
				g.Material = Enum.Material.Glass
				g.Color = GLASS
				g.Transparency = 0.4
			end
			for _, l in ipairs(SAND_L) do
				decor(hb("HourglassSand", l[3], l[1], l[2], "px_sand", SAND))
			end
		end
		for _, h in ipairs({ { -84, 156, 1 }, { 84, 156, 1 }, { -54, 198, 0.5 } }) do
			if okGround(h[1], h[2], 6 * h[3]) then
				hourglass(h[1], h[2], h[3])
			else
				warn(
					("[build-purgatory] bay: no room for the hourglass at (%d, %d)"):format(
						h[1],
						h[2]
					)
				)
			end
		end
		-- cypresses: a narrow stepped column of hedge on a log, a few loose leaf blocks
		local function cypress(x, z, h)
			local f = folder("Cypress", gf)
			box("CypressTrunk", x - 2, 0, z - 2, x + 2, 4, z + 2, "px_oak_log", nil, f)
			box("CypressLeaves", x - 4, 3, z - 4, x + 4, h - 8, z + 4, "px_hedge", CYPRESS, f)
			box("CypressLeaves", x - 2, h - 8, z - 2, x + 2, h, z + 2, "px_hedge", CYPRESS, f)
			for k = 1, 3 do
				local sx = if rng:NextNumber() < 0.5 then -1 else 1
				local alongX = rng:NextNumber() < 0.5
				local y = 6
					+ rng:NextInteger(0, math.max(0, math.floor((h - 18) / 4))) * 4
					+ (k - 1) * 2
				local ox, oz = if alongX then sx * 4 else 0, if alongX then 0 else sx * 4
				decor(
					box(
						"CypressLeaf",
						x + ox - 2,
						y,
						z + oz - 2,
						x + ox + 2,
						y + 4,
						z + oz + 2,
						"px_hedge",
						CYPRESS,
						f
					)
				)
			end
		end
		for _, c in ipairs({
			{ -88, 22 },
			{ 88, 22 },
			{ -60, 26 },
			{ 60, 26 },
			{ -90, 92 },
			{ 90, 92 },
			{ -90, 128 },
			{ 90, 128 },
			{ -66, 192 },
			{ 66, 190 },
		}) do
			if okGround(c[1], c[2], 0) then
				cypress(c[1], c[2], 20 + rng:NextInteger(0, 2) * 4)
			end
		end
		-- dead orange bushes: a few twigs from one point
		local function deadBush(x, y, z)
			local base = V(x, y, z)
			local a0 = rng:NextNumber() * math.pi * 2
			for i = 1, 4 do
				local a = a0 + i * 1.57 + rng:NextNumber() * 0.6
				local len = 1.6 + rng:NextNumber() * 1.6
				local tip = base
					+ Vector3.new(math.cos(a) * len * 0.7, len, math.sin(a) * len * 0.7)
				decor(beam("DeadBush", base, tip, 0.4, DEAD_BUSH, gf, Enum.Material.Wood))
				local fork = tip
					+ Vector3.new(math.cos(a + 0.8) * 0.8, 0.9, math.sin(a + 0.8) * 0.8)
				decor(beam("DeadBush", tip, fork, 0.3, DEAD_BUSH, gf, Enum.Material.Wood))
			end
		end
		for _, b in ipairs({
			{ -78, 30 },
			{ 78, 30 },
			{ -92, 60 },
			{ 92, 62 },
			{ -80, 128 },
			{ 79, 126 },
			{ -92, 172 },
			{ 92, 172 },
			{ -58, 186 },
			{ 46, 188 },
			{ -70, 6 },
			{ 70, 6 },
			{ -54, 22 },
			{ 54, 22 },
		}) do
			if okGround(b[1], b[2], -2) then
				deadBush(b[1], 0, b[2])
			end
		end
		-- decorated pots (terracotta with a dark band; some hold a dead bush)
		local POT_C = {
			Color3.fromRGB(205, 120, 80),
			Color3.fromRGB(190, 100, 70),
			Color3.fromRGB(215, 150, 100),
		}
		for _, p in ipairs({
			{ -74, 14 },
			{ 74, 14 },
			{ -56, 4 },
			{ 56, 4 },
			{ -92, 80 },
			{ 92, 112 },
			{ -60, 200 },
			{ 30, 194 },
			{ -48, 190 },
		}) do
			local x, z = p[1], p[2]
			if okGround(x, z, -2) then
				local c = pick(POT_C)
				box("Pot", x - 1.5, 0, z - 1.5, x + 1.5, 3, z + 1.5, "px_terracotta", c, gf)
				box("PotNeck", x - 1, 3, z - 1, x + 1, 3.6, z + 1, "px_terracotta", c, gf)
				box("PotRim", x - 1.3, 3.6, z - 1.3, x + 1.3, 4, z + 1.3, "px_terracotta", c, gf)
				decor(
					box(
						"PotBand",
						x - 1.55,
						1.2,
						z - 1.55,
						x + 1.55,
						1.8,
						z + 1.55,
						"px_terracotta",
						Color3.fromRGB(120, 60, 40),
						gf
					)
				)
				if rng:NextNumber() < 0.5 then
					deadBush(x, 4, z)
				end
			end
		end
		-- benches for the waiting souls (dark oak), souls sitting on them
		local function bench(x, z, yaw, sitters)
			if not okGround(x, z, 0) then
				return
			end
			local f = folder("Bench", gf)
			local cf = sAt(x, 0, z, yaw)
			textured(
				part("BenchSeat", Vector3.new(8, 0.8, 3), cf * CFrame.new(0, 2.2, 0), nil, nil, f),
				"px_dark_oak_planks"
			)
			for _, sx in ipairs({ -3.2, 3.2 }) do
				textured(
					part(
						"BenchLeg",
						Vector3.new(1, 1.8, 2.6),
						cf * CFrame.new(sx, 0.9, 0),
						nil,
						nil,
						f
					),
					"px_dark_oak_planks"
				)
			end
			textured(
				part(
					"BenchBack",
					Vector3.new(8, 2.2, 0.6),
					cf * CFrame.new(0, 3.7, 1.3),
					nil,
					nil,
					f
				),
				"px_dark_oak_planks"
			)
			for i = 1, sitters do
				soul(
					cf * CFrame.new(-2.4 + (i - 1) * (4.8 / math.max(1, sitters - 1)), 2.6, -0.2),
					"sit"
				)
			end
		end
		bench(-64, 12, 0, 2) -- before the reliefs of pride and envy
		bench(64, 12, 0, 2) -- before gluttony and lust
		bench(40, 194, 0, 2) -- by the arrival, looking at the pit
		-- the queue of souls waiting at the foot of the zigzag (east of the foot, along the fence walk)
		for k = 0, 5 do
			soul(sAt(18 + 5 * k, 0, 32.5 + (k % 2) * 0.6, math.pi / 2), "bow")
		end
		soul(sAt(-20, 0, 32.5, -math.pi / 2), "bow")
		soul(sAt(-25, 0, 33, -math.pi / 2), "bow")
		-- a lantern pillar either side of the way from the arrival to the pit
		for _, s in ipairs({ -1, 1 }) do
			local x, z = s * 20, 190
			if okGround(x, z, 0) then
				local f = folder("LanternPillar", gf)
				box(
					"PillarBase",
					x - 2.4,
					0,
					z - 2.4,
					x + 2.4,
					2,
					z + 2.4,
					"px_stone_bricks",
					nil,
					f
				)
				box("PillarShaft", x - 2, 2, z - 2, x + 2, 14, z + 2, CUT, SAND_PALE, f)
				box("PillarCap", x - 2.6, 14, z - 2.6, x + 2.6, 15, z + 2.6, CUT, SAND, f)
				lantern(V(x, 15.9, z), f)
				banner(at(x, 8, z - 2.2), BANNER_RED, f, GOLD, 3, 7)
				banner(at(x, 8, z + 2.2), BANNER_RED, f, GOLD, 3, 7)
			end
		end
	end
	print(
		("[build-purgatory] bay: %d parts, %d props skipped"):format(count - partsAtStart, skipped)
	)
end
