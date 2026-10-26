--!nocheck
-- ================================================================ paradise: the ROSE (the hero) — rays, petals, tiers, angels, crown
-- Rose centre (0, -84); angles are degrees from south (+Z) toward east (+X): x = r·sin a, z = -84 + r·cos a. The ground
-- is 10-core's 8-stud cells (edges on multiples of 8), tier k at y 4k, so every tier edge is a stepped cell circle.
-- RAYS (12, a = 30·k, ray 0 south): per riser one flight of 4 steps (rise 1, run 2; 8 long) on an invisible wedge, built
--   in the ray frame (rotated for the diagonal rays). The riser radius T_k on a ray is read from the cells: across the
--   flight width, the outermost point whose cell is tier ≥ k; the flight runs T_k + 8 → T_k (top flush with tier k),
--   and a rotated WALKWAY (y 4k + 0.02) covers tier k from T_k inward to the next flight's foot, filling the cell
--   notches, so every ray is one unbroken causeway from the river glass (y 0) to the crown (y 24). Measured: ray 0
--   (x -10..10, the GRAND STAIR, 20 wide) T = 108, 92, 76, 60, 44, 28; rays 3/9 T = 104 … 24; rays 1/5/7/11 T = 108.75,
--   96.75, 79, 61, 44, 32.25; rays 2/4/8/10 T = 113.25, 94.75, 79, 62.5, 48.5, 30.25 (walkways 3.75..10.5 long).
--   Rays 1..11 are 8 wide with white balustrade cheeks (s ±4..5) and gold-capped posts on risers 1..5; the grand stair
--   has gold-glass inlays, gold side strips and candles on white posts at x ±11.5 by every flight (lit lanterns at the
--   foot and on tier 4). Nothing stands on the river glass but the ray feet.
-- PETALS: along every tier edge a coping lip (0.75 thick, 1 stud over the edge each way, top y 4k + 0.25; quartz bricks
--   on concrete tiers, concrete on brick tiers) merged per straight cell-edge run, with a warm-white Neon strip
--   recessed under it (the tiers glow from inside, no PointLights); tiers 2 and 4 also get a flush gold ring strip
--   (2 wide, just inside the lip). Runs are cut 5.8 studs from every ray (13 from the grand stair).
-- TIERS: 4-stud squares next to a drop (outer third) carry thrones (white seats, gold backs and crowns) in rows of 3/3/2/2
--   facing the centre between the rays on tiers 2..5, candles on white posts and lantern posts; squares at the foot of
--   the next riser (inner third) carry red flower bushes and pink petals (more toward the crown); the middle squares of
--   every tier stay clear for the walk. Gold banners (sun / bird of paradise) on white poles flank every ray on tiers 1
--   and 3; white birches, one per sector on tier 1 (a = mid ± 9°, r 94).
-- ANGELS: 12 statues at r 101 on the sector mid-angles (15 + 30·j) on tier 1, facing outward: a 2-block pillar, a
--   6-block robed figure praying, a gold halo, wings raised in a stepped V up to y ≈ 47.
-- CROWN (SUMMIT, y 24, r < 28): 10 slender spires (3×3 shafts, gold rings and pinnacles, gold tips) at r 22 on the
--   mid-angles ±45..±165 (none beside the grand stair), heights 74 (south) → 110 (north), a gold sun banner on each and
--   a lantern facing the dais; the dais (r 8 quartz, r 6 gold, top y 26) and THE PILLAR OF LIGHT (Neon core of 3
--   rotated 8-stud boxes to y 700, a translucent 16-stud glow); 8 end rods at r 10.5; 4 candles; a gold cross inlay
--   (x -7..7, z -74..-58) before the grand stair head; ray heads end at r ≥ 24.5, between the spires (≈ 7 studs
--   apart at the plinths).
local roseF = folder("Rose")
local partsBefore = count
local SMOOTH, BRICK, GOLDV, WOOL =
	"px_smooth_stone", "px_white_stone_bricks", "px_gold_block", "px_white_wool"
local DEG = math.pi / 180
local FLAME = Color3.fromRGB(255, 212, 120)
local IRON = Color3.fromRGB(62, 58, 54)
local MAX_LIGHTS = 20
local stat = {
	lights = 0,
	flights = 0,
	walks = 0,
	lips = 0,
	thrones = 0,
	candles = 0,
	lanterns = 0,
	bushes = 0,
	petals = 0,
	banners = 0,
	birches = 0,
}
local claims = {} -- { x, z, r } spots taken by ray furniture, angels and birches (props keep off them)

-- the cell of 10-core holding a point (8-stud cells, edges on multiples of 8); the tier is read at the cell centre
local function cellC(v)
	return math.floor(v / 8) * 8 + 4
end
local function tierAt(x, z)
	return tierOf(cellC(x), cellC(z))
end
-- the walkable top at a point: the river glass, else the tier
local function topAt(x, z)
	local cx, cz = cellC(x), cellC(z)
	if onRiver(cx, cz) then
		return GLASS_TOP
	end
	return tierOf(cx, cz) * ROSE.step
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

-- ================================================================ the rays: the riser radii measured from the cells
-- RAY[k] = { a, ux, uz (outward), sx, sz (across), w, T[1..6] (riser k's outermost tier-k point), Tmin[1..6] }; the
-- east rays 0..6 are measured, 7..11 mirror 5..1 (ray 12 - k), so the rose stays mirror-symmetric in x
local RAY = {}
do
	for k = 0, RAYS - 1 do
		local a = k * 2 * math.pi / RAYS
		RAY[k] = {
			k = k,
			a = a,
			ux = math.sin(a),
			uz = math.cos(a),
			sx = math.cos(a),
			sz = -math.sin(a),
			w = if k == 0 then 20 else 8,
		}
	end
	for k = 0, RAYS / 2 do
		local R = RAY[k]
		R.T, R.Tmin = {}, {}
		for tier = 1, 6 do
			local mx, mn = -1, math.huge
			for i = 0, 32 do
				local s = -R.w / 2 + R.w * i / 32
				local e = 0
				for t = TIERS[tier] + 16, 0, -0.125 do
					if tierAt(R.ux * t + R.sx * s, ROSE.z + R.uz * t + R.sz * s) >= tier then
						e = t + 0.125
						break
					end
				end
				mx = math.max(mx, e)
				mn = math.min(mn, e)
			end
			R.T[tier] = math.ceil(mx * 4) / 4
			R.Tmin[tier] = mn
		end
	end
	for k = RAYS / 2 + 1, RAYS - 1 do
		RAY[k].T, RAY[k].Tmin = RAY[RAYS - k].T, RAY[RAYS - k].Tmin
	end
end
-- a CFrame in a ray's frame: t outward along the ray, s across (local +Z = outward, +X = across)
local function rcf(R, t, s, y)
	return at(R.ux * t + R.sx * s, y, ROSE.z + R.uz * t + R.sz * s) * CFrame.Angles(0, R.a, 0)
end
local function rbox(name, R, t0, t1, s0, s1, y0, y1, variant, tint, parent, solid)
	return lp(
		name,
		rcf(R, (t0 + t1) / 2, (s0 + s1) / 2, 0),
		s0 - (s0 + s1) / 2,
		y0,
		t0 - (t0 + t1) / 2,
		s1 - (s0 + s1) / 2,
		y1,
		t1 - (t0 + t1) / 2,
		variant,
		tint,
		parent,
		solid
	)
end
-- true when (x, z) keeps `pad` studs beside every ray's footprint (grand stair: padG)
local function clearOfRays(x, z, pad, padG)
	local dx, dz = x, z - ROSE.z
	for k = 0, RAYS - 1 do
		local R = RAY[k]
		local t = dx * R.ux + dz * R.uz
		if t > 14 and t < 128 then
			local s = math.abs(dx * R.sx + dz * R.sz)
			if s < R.w / 2 + (if k == 0 then padG else pad) then
				return false
			end
		end
	end
	return true
end
local function claimed(x, z, r)
	for _, c in ipairs(claims) do
		if (c.x - x) ^ 2 + (c.z - z) ^ 2 < (c.r + r) ^ 2 then
			return true
		end
	end
	return false
end

-- ================================================================ block props of the rose
-- a lantern (iron plates round a glowing core); lit only while the light budget lasts
local function lamp(pos, parent, lit)
	decor(
		part(
			"LanternBase",
			Vector3.new(1.3, 0.3, 1.3),
			CFrame.new(pos - Vector3.new(0, 0.65, 0)),
			IRON,
			Enum.Material.Metal,
			parent
		)
	)
	local glow = decor(
		part(
			"LanternGlow",
			Vector3.new(1, 1, 1),
			CFrame.new(pos),
			LANTERN_GLOW,
			Enum.Material.Neon,
			parent
		)
	)
	decor(
		part(
			"LanternTop",
			Vector3.new(1.3, 0.3, 1.3),
			CFrame.new(pos + Vector3.new(0, 0.65, 0)),
			IRON,
			Enum.Material.Metal,
			parent
		)
	)
	decor(
		part(
			"LanternCap",
			Vector3.new(0.6, 0.4, 0.6),
			CFrame.new(pos + Vector3.new(0, 1, 0)),
			IRON,
			Enum.Material.Metal,
			parent
		)
	)
	if lit and stat.lights < MAX_LIGHTS then
		light(glow, 34, 1.3, LANTERN_GLOW)
		stat.lights += 1
	end
	stat.lanterns += 1
	return glow
end
-- a candle on a white post (post 2×h×2, a wax candle, a small Neon flame)
local function candle(x, y, z, parent, h)
	h = h or 3
	cube("CandlePost", x, y + h / 2, z, 2, h, 2, SMOOTH, WHITE, parent)
	decor(cube("Candle", x, y + h + 0.7, z, 0.8, 1.4, 0.8, WOOL, SNOW, parent))
	local fl = decor(
		part(
			"CandleFlame",
			Vector3.new(0.45, 0.7, 0.45),
			at(x, y + h + 1.75, z),
			FLAME,
			Enum.Material.Neon,
			parent
		)
	)
	fl.CastShadow = false
	stat.candles += 1
end
-- a red flower bush: a hedge block with scarlet roses on the half away from (rx, rz) (the riser behind it)
local function bush(x, y, z, parent, rx, rz)
	cube("RoseBush", x, y + 1.5, z, 4, 3, 4, "px_hedge", LEAF, parent)
	local ox, oz = -rx * 0.9, -rz * 0.9
	local px, pz = rz, rx -- across
	for _, sgn in ipairs({ -1, 1 }) do
		decor(
			cube(
				"Rose",
				x + ox + px * sgn * 1.0,
				y + 3.5,
				z + oz + pz * sgn * 1.0,
				1.4,
				1.4,
				1.4,
				WOOL,
				SCARLET,
				parent
			)
		)
	end
	decor(cube("Rose", x - rx * 1.8, y + 2.1, z - rz * 1.8, 1.2, 1.2, 1.2, WOOL, SCARLET, parent))
	stat.bushes += 1
end
local function petals(x, y, z, parent, s)
	decor(cube("Petals", x, y + 0.08, z, s, 0.16, s, WOOL, PETAL, parent))
	stat.petals += 1
end
-- a white emblem on a banner cloth: cf = its centre (X across the cloth, Z through it); "sun" or "bird" (of paradise)
local function motif(cf, kind, parent)
	if kind == "sun" then
		lp("SunCore", cf, -0.7, -0.7, -0.2, 0.7, 0.7, 0.2, WOOL, SNOW, parent)
		lp("SunRay", cf, -0.2, -1.4, -0.18, 0.2, 1.4, 0.18, WOOL, SNOW, parent)
		lp("SunRay", cf, -1.4, -0.2, -0.18, 1.4, 0.2, 0.18, WOOL, SNOW, parent)
	else
		lp("BirdBody", cf, -0.35, -0.9, -0.2, 0.35, 0.8, 0.2, WOOL, SNOW, parent)
		for _, sgn in ipairs({ -1, 1 }) do
			lp(
				"BirdWing",
				cf * CFrame.new(sgn * 0.85, 0.45, 0) * CFrame.Angles(0, 0, sgn * 0.5),
				-0.75,
				-0.2,
				-0.18,
				0.75,
				0.2,
				0.18,
				WOOL,
				SNOW,
				parent
			)
		end
		lp("BirdTail", cf, -0.6, -1.5, -0.18, 0.6, -0.9, 0.18, GOLDV, GOLD, parent)
	end
end
-- a gold banner on a white pole: cf = the pole foot, the bar reaching along local +X, the cloth facing ±Z
local function poleBanner(cf, parent, kind)
	local h = 14
	lp("BannerPole", cf, -0.5, 0, -0.5, 0.5, h, 0.5, SMOOTH, WHITE, parent, true)
	lp("BannerKnob", cf, -0.7, h, -0.7, 0.7, h + 1.4, 0.7, GOLDV, GOLD, parent)
	lp("BannerBar", cf, 0.5, h - 1, -0.25, 4.6, h - 0.5, 0.25, GOLDV, GOLD, parent)
	lp("Banner", cf, 1, h - 8.5, -0.12, 4.2, h - 1, 0.12, "px_yellow_wool", GOLD, parent)
	motif(cf * CFrame.new(2.6, h - 4.6, 0), kind, parent)
	stat.banners += 1
end

-- ================================================================ the twelve rays of steps
do
	local raysF = folder("Rays", roseF)
	local GLASSY = GOLD_GLASS
	for k = 0, RAYS - 1 do
		local R = RAY[k]
		local f = folder(("Ray%02d"):format(k), raysF)
		local hw = R.w / 2
		local grand = k == 0
		for tier = 1, 6 do
			local T = R.T[tier]
			local yl, yu = (tier - 1) * ROSE.step, tier * ROSE.step
			local bottom = if tier == 1 then RIVER_BED else yl - B
			-- the flight: 4 steps from the lower tier (or the glass) up to tier `tier`, its top at T
			for i = 0, 3 do
				rbox(
					"RayStep",
					R,
					T + 8 - 2 * (i + 1),
					T + 8 - 2 * i,
					-hw,
					hw,
					bottom,
					yl + i + 1,
					BRICK,
					SNOW,
					f,
					true
				)
				if grand then
					local g = rbox(
						"GoldGlassInlay",
						R,
						T + 8 - 2 * (i + 1) + 0.3,
						T + 8 - 2 * i - 0.3,
						-2,
						2,
						yl + i + 1,
						yl + i + 1.08,
						nil,
						GLASSY,
						f
					)
					g.Material = Enum.Material.Glass
					g.Transparency = 0.15
				end
			end
			local ramp = Instance.new("WedgePart")
			ramp.Name = "RayRamp"
			ramp.Anchored = true
			ramp.Transparency = 1
			ramp.Size = Vector3.new(R.w, B, 8)
			ramp.CFrame = rcf(R, T + 4, 0, yl + 2) * CFrame.Angles(0, math.pi, 0) -- high end inward (toward the crown)
			ramp.Parent = f
			stat.flights += 1
			-- the walkway over tier `tier` from T inward to the next flight's foot (the crown: to r ≥ 24.5, clear of the spires)
			local inner = if tier < 6 then R.T[tier + 1] + 8 else math.max(R.Tmin[6] - 1, 24.5)
			if T - inner > 0.1 then
				rbox("RayWalk", R, inner, T, -hw, hw, yu - 2 * B, yu + 0.02, BRICK, SNOW, f, true)
				stat.walks += 1
				if grand then
					local g = rbox(
						"GoldGlassInlay",
						R,
						inner + 0.5,
						T - 0.5,
						-2,
						2,
						yu,
						yu + 0.1,
						nil,
						GLASSY,
						f
					)
					g.Material = Enum.Material.Glass
					g.Transparency = 0.15
					for _, sg in ipairs({ -1, 1 }) do
						rbox(
							"GoldStrip",
							R,
							inner,
							T,
							sg * 8.5,
							sg * 9.5,
							yu,
							yu + 0.08,
							GOLDV,
							GOLD,
							f
						)
					end
				else
					rbox(
						"GoldStrip",
						R,
						inner + 0.5,
						T - 0.5,
						-0.75,
						0.75,
						yu,
						yu + 0.08,
						GOLDV,
						GOLD,
						f
					)
				end
			end
			if grand then
				-- candles on white posts either side, at the flight's foot and on its top landing (lanterns lit at the
				-- river foot and on tier 4)
				for _, sg in ipairs({ -1, 1 }) do
					local spots = { { T + 9.5, tier == 1 } }
					if tier < 6 then
						table.insert(spots, { T - 1.5, tier == 4 })
					end
					for _, sp in ipairs(spots) do
						local x, z =
							R.ux * sp[1] + R.sx * sg * 11.5,
							ROSE.z + R.uz * sp[1] + R.sz * sg * 11.5
						local y = topAt(x, z)
						table.insert(claims, { x = x, z = z, r = 1.5 })
						if sp[2] then
							cube("LanternPost", x, y + 3, z, 2, 6, 2, BRICK, QUARTZ, f)
							cube("LanternPostCap", x, y + 6.2, z, 2.4, 0.4, 2.4, GOLDV, GOLD, f)
							lamp(V(x, y + 7.1, z), f, true)
						else
							candle(x, y, z, f)
						end
					end
				end
			elseif tier < 6 then
				-- white balustrade cheeks: a low wall by the lower steps, a full one by the upper, a gold-capped post
				for _, sg in ipairs({ -1, 1 }) do
					rbox(
						"Cheek",
						R,
						T + 4,
						T + 8,
						sg * hw,
						sg * (hw + 1),
						bottom,
						yl + 2.5,
						SMOOTH,
						WHITE,
						f,
						true
					)
					rbox(
						"Cheek",
						R,
						T,
						T + 4,
						sg * hw,
						sg * (hw + 1),
						bottom,
						yu + 1,
						SMOOTH,
						WHITE,
						f,
						true
					)
					rbox(
						"CheekPost",
						R,
						T - 1.4,
						T,
						sg * hw,
						sg * (hw + 1.4),
						yu - B,
						yu + 2,
						BRICK,
						QUARTZ,
						f,
						true
					)
					rbox(
						"CheekCap",
						R,
						T - 1.6,
						T + 0.2,
						sg * (hw - 0.1),
						sg * (hw + 1.6),
						yu + 2,
						yu + 2.4,
						GOLDV,
						GOLD,
						f
					)
				end
			end
		end
		-- gold banners on white poles flanking the ray on tiers 1 and 3 (by the foot of the next riser)
		for _, tier in ipairs({ 1, 3 }) do
			local t = R.T[tier + 1] + 2
			local s = if grand then 13.5 else 7
			for _, sg in ipairs({ -1, 1 }) do
				local x, z = R.ux * t + R.sx * sg * s, ROSE.z + R.uz * t + R.sz * sg * s
				table.insert(claims, { x = x, z = z, r = 1.5 })
				local cf = rcf(R, t, sg * s, topAt(x, z))
				if sg < 0 then
					cf *= CFrame.Angles(0, math.pi, 0)
				end
				poleBanner(cf, f, if k % 2 == 0 then "sun" else "bird")
			end
		end
		task.wait()
	end
end

-- ================================================================ the petals: lips, hidden light strips, gold rings
do
	local edgeF = folder("TierEdges", roseF)
	local D4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local lines, keys = {}, {}
	-- every cell face where a tier cell drops to a lower one (or to the river), as 4-stud units along its face line
	for cz = ROSE.z - 120, ROSE.z + 120, 8 do
		for cx = -116, 116, 8 do
			local k = tierOf(cx, cz)
			if k >= 1 then
				for di, d in ipairs(D4) do
					if tierOf(cx + d[1] * 8, cz + d[2] * 8) < k then
						local face = if d[1] ~= 0 then cx + d[1] * 4 else cz + d[2] * 4
						local key = di .. ":" .. face .. ":" .. k
						if not lines[key] then
							lines[key] = { d = d, face = face, k = k, units = {} }
							table.insert(keys, key)
						end
						local a0 = if d[1] ~= 0 then cz - 4 else cx - 4
						table.insert(lines[key].units, a0)
						table.insert(lines[key].units, a0 + 4)
					end
				end
			end
		end
	end
	-- a point on a face line: `along` the line, `c` studs outward from the face
	local function pointAt(L, along, c)
		local n = L.d[1] + L.d[2]
		if L.d[1] ~= 0 then
			return L.face + n * c, along
		end
		return along, L.face + n * c
	end
	local function lineBox(name, L, a0, a1, c0, c1, y0, y1, variant, tint)
		local n = L.d[1] + L.d[2]
		local q0, q1 = L.face + n * c0, L.face + n * c1
		if L.d[1] ~= 0 then
			return box(name, q0, y0, a0, q1, y1, a1, variant, tint, edgeF)
		end
		return box(name, a0, y0, q0, a1, y1, q1, variant, tint, edgeF)
	end
	-- lips stay off the ray flights, cheeks, posts and walkways
	local function nearRay(x, z, k)
		local dx, dz = x, z - ROSE.z
		for r = 0, RAYS - 1 do
			local R = RAY[r]
			local t = dx * R.ux + dz * R.uz
			local s = math.abs(dx * R.sx + dz * R.sz)
			local c = if r == 0 then (if k == 6 then 11 else 13) else (if k == 6 then 4.8 else 5.8)
			if t > 16 and s < c then
				return true
			end
		end
		return false
	end
	local function rectNear(L, a0, a1, c0, c1)
		for _, p in ipairs({ { a0, c0 }, { a0, c1 }, { a1, c0 }, { a1, c1 } }) do
			local x, z = pointAt(L, p[1], p[2])
			if nearRay(x, z, L.k) then
				return true
			end
		end
		return false
	end
	-- how the edge goes on past a run end: convex (turns inward), concave (turns outward) or straight (cut by a ray)
	local function endType(L, e, dirA)
		local xi, zi = pointAt(L, e + dirA * 2, -2)
		if tierAt(xi, zi) < L.k then
			return "convex"
		end
		local xo, zo = pointAt(L, e + dirA * 2, 2)
		if tierAt(xo, zo) >= L.k then
			return "concave"
		end
		return "straight"
	end
	local nRuns = 0
	for _, key in ipairs(keys) do
		local L = lines[key]
		table.sort(L.units)
		local runs, cur = {}, nil
		for _, u in ipairs(L.units) do
			if not rectNear(L, u - 1, u + 5, -1, 1) then
				if cur and u == cur[2] then
					cur[2] = u + 4
				else
					cur = { u, u + 4 }
					table.insert(runs, cur)
				end
			else
				cur = nil
			end
		end
		local yu = L.k * ROSE.step
		local brickTier = L.k % 2 == 0 and L.k < 6
		local lipV, lipT = if brickTier then SMOOTH else BRICK, if brickTier then WHITE else QUARTZ
		for _, run in ipairs(runs) do
			local lo, hi = endType(L, run[1], -1), endType(L, run[2], 1)
			lineBox(
				"PetalLip",
				L,
				run[1] - (if lo == "convex" then 1 else 0),
				run[2] + (if hi == "convex" then 1 else 0),
				-1,
				1,
				yu - 0.5,
				yu + 0.25,
				lipV,
				lipT
			)
			local glow = lineBox(
				"PetalGlow",
				L,
				run[1] - (if lo == "convex" then 0.3 else 0),
				run[2] + (if hi == "convex" then 0.3 else 0),
				0,
				0.3,
				yu - 0.85,
				yu - 0.5
			)
			glow.Material = Enum.Material.Neon
			glow.Color = LIGHT
			glow.CastShadow = false
			decor(glow)
			if L.k == 2 or L.k == 4 then
				local g0 = run[1]
					- (
						if lo == "concave" and not rectNear(L, run[1] - 3, run[1], -3, -1)
							then 3
							else 0
					)
				local g1 = run[2]
					+ (
						if hi == "concave" and not rectNear(L, run[2], run[2] + 3, -3, -1)
							then 3
							else 0
					)
				decor(lineBox("GoldRing", L, g0, g1, -3, -1, yu, yu + 0.06, GOLDV, GOLD))
			end
			nRuns += 1
			if nRuns % 150 == 0 then
				task.wait()
			end
		end
	end
	stat.lips = nRuns
end
task.wait()

-- ================================================================ the angel ring: 12 statues on tier 1, facing outward
do
	local angelF = folder("Angels", roseF)
	for j = 0, RAYS - 1 do
		local a = (15 + 30 * j) * DEG
		local x, z = 101 * math.sin(a), ROSE.z + 101 * math.cos(a)
		local y0 = topAt(x, z)
		table.insert(claims, { x = x, z = z, r = 6 })
		local cf = at(x, y0, z) * CFrame.Angles(0, a, 0) -- local +Z = outward (the face), +X = across
		local f = folder("Angel", angelF)
		-- the pillar (2 blocks)
		lp("AngelPlinth", cf, -4, 0, -4, 4, 1.5, 4, BRICK, QUARTZ, f, true)
		lp("AngelPillar", cf, -3, 1.5, -3, 3, 7, 3, SMOOTH, WHITE, f, true)
		lp("AngelPillarBand", cf, -3.1, 5.4, -3.1, 3.1, 6, 3.1, GOLDV, GOLD, f)
		lp("AngelPillarCap", cf, -3.6, 7, -3.6, 3.6, 8, 3.6, BRICK, QUARTZ, f, true)
		-- the robed figure (6 blocks), hands joined in prayer
		lp("AngelRobe", cf, -3, 8, -2.4, 3, 18, 2.4, SMOOTH, CALCITE, f, true)
		lp("AngelHem", cf, -3.1, 8, -2.5, 3.1, 8.6, 2.5, GOLDV, GOLD, f)
		lp("AngelTorso", cf, -2.4, 18, -1.8, 2.4, 26, 1.8, SMOOTH, CALCITE, f)
		for _, sx in ipairs({ -1, 1 }) do
			lp("AngelArm", cf, sx * 2.4, 19, -1.4, sx * 3.6, 26, 1.4, SMOOTH, CALCITE, f)
		end
		lp("AngelHands", cf, -1.2, 20, 1.8, 1.2, 21.8, 3, SMOOTH, SNOW, f)
		lp("AngelHead", cf, -1.8, 26, -1.8, 1.8, 29.8, 1.8, SMOOTH, SNOW, f)
		-- the gold halo over the head
		for _, sz in ipairs({ -1, 1 }) do
			lp("AngelHalo", cf, -2.6, 31, sz * 2, 2.6, 31.6, sz * 2.6, GOLDV, GOLD, f)
			lp("AngelHalo", cf, sz * 2, 31, -2, sz * 2.6, 31.6, 2, GOLDV, GOLD, f)
		end
		-- the wings raised in a stepped V (6 feather columns a side behind the back)
		for _, sx in ipairs({ -1, 1 }) do
			for i = 1, 6 do
				lp(
					"AngelWing",
					cf,
					sx * (2.4 + (i - 1) * 2.6),
					18 + i * 1.2,
					-3.2,
					sx * (2.4 + i * 2.6),
					24 + i * 3.2,
					-1.8,
					WOOL,
					if i % 2 == 0 then SNOW else CLOUD,
					f
				)
			end
		end
	end
end
task.wait()

-- ================================================================ on the tiers: thrones, candles, lanterns, flowers, birches
do
	local propF = folder("TierProps", roseF)
	local D4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	-- the 4-stud squares of the east half (x > 0) next to a drop (outer) or to the next riser (inner), per tier and sector;
	-- every prop is placed at (x, z) and mirrored to (-x, z)
	local lists = {}
	for k = 1, 5 do
		lists[k] = {}
		for j = 0, 5 do
			lists[k][j] = { outer = {}, inner = {} }
		end
	end
	for x = 2, 122, 4 do
		for z = ROSE.z - 122, ROSE.z + 122, 4 do
			local k = tierAt(x, z)
			if k >= 1 and k <= 5 and clearOfRays(x, z, 5.5, 6.5) and not claimed(x, z, 2.8) then
				local dx, dz = x, z - ROSE.z
				local dl = math.sqrt(dx * dx + dz * dz)
				local drop, up, best = nil, nil, -2
				for _, d in ipairs(D4) do
					local nk = tierAt(x + d[1] * 4, z + d[2] * 4)
					if nk < k then
						local dot = (d[1] * dx + d[2] * dz) / dl
						if dot > best then
							best, drop = dot, d
						end
					elseif nk > k then
						up = d
					end
				end
				local a = math.atan2(dx, dz) / DEG
				local j = math.clamp(math.floor(a / 30), 0, 5)
				local sq = { x = x, z = z, a = a, y = k * ROSE.step, drop = drop, up = up }
				if drop and not up then
					table.insert(lists[k][j].outer, sq)
				elseif up and not drop then
					table.insert(lists[k][j].inner, sq)
				end
			end
		end
	end
	local function farFrom(sq, list, gap)
		for _, p in ipairs(list) do
			if (p.x - sq.x) ^ 2 + (p.z - sq.z) ^ 2 < gap * gap then
				return false
			end
		end
		return true
	end
	local function sortedBy(list, key)
		local c = table.clone(list)
		table.sort(c, function(p, q)
			local kp, kq = key(p), key(q)
			if kp ~= kq then
				return kp < kq
			end
			if p.x ~= q.x then
				return p.x < q.x
			end
			return p.z < q.z
		end)
		return c
	end
	-- a white throne with a gold back and crown, facing (fx, fz); m = 1 or -1 (the mirrored copy)
	local function throne(sq, m)
		local fx, fz = -sq.drop[1] * m, -sq.drop[2]
		local cf = at(sq.x * m, sq.y, sq.z) * CFrame.Angles(0, math.atan2(-fx, -fz), 0) -- local -Z = the front
		lp("ThroneSeat", cf, -2, 0, -2, 2, 2, 1.4, BRICK, QUARTZ, propF, true)
		lp("ThroneCushion", cf, -1.6, 2, -1.8, 1.6, 2.3, 1.2, WOOL, SNOW, propF)
		lp("ThroneBack", cf, -2, 0, 1.4, 2, 6.5, 2.4, GOLDV, GOLD, propF, true)
		lp("ThroneCrest", cf, -1.2, 6.5, 1.4, 1.2, 7.5, 2.4, GOLDV, GOLD, propF)
		lp("ThroneCrown", cf, -0.4, 7.5, 1.6, 0.4, 8.7, 2.2, GOLDV, GOLD, propF)
		for _, sx in ipairs({ -1, 1 }) do
			lp("ThroneCrown", cf, sx * 0.8, 7.5, 1.6, sx * 1.4, 8.2, 2.2, GOLDV, GOLD, propF)
		end
		stat.thrones += 1
	end
	local function lanternPost(sq, m)
		local x = sq.x * m
		cube("LanternPost", x, sq.y + 2.5, sq.z, 1, 5, 1, SMOOTH, WHITE, propF)
		lamp(V(x, sq.y + 5.75, sq.z), propF, false)
	end
	local function birch(sq, m, h, loose)
		local x = sq.x * m
		local f = folder("Birch", propF)
		cube("BirchTrunk", x, sq.y + (h + 2) / 2, sq.z, B, h + 2, B, "px_birch_log", BIRCH, f)
		decor(cube("BirchCrown", x, sq.y + h + 1, sq.z, 12, 4, 12, WOOL, SNOW, f))
		decor(cube("BirchCrown", x, sq.y + h + 5, sq.z, 8, 4, 8, WOOL, CLOUD, f))
		decor(cube("BirchCrown", x, sq.y + h + 8, sq.z, 4, 2, 4, WOOL, SNOW, f))
		for _, l in ipairs(loose) do
			decor(
				cube(
					"BirchCrown",
					x + l[1] * m,
					sq.y + h + l[2],
					sq.z + l[3],
					B,
					B,
					B,
					WOOL,
					SNOW,
					f
				)
			)
		end
		stat.birches += 1
	end
	local THRONES = { 0, 3, 3, 2, 2 }
	for k = 1, 5 do
		for j = 0, 5 do
			local L = lists[k][j]
			local mid = 30 * j + 15
			local taken = {}
			-- the throne row facing the centre in the middle of the sector, a candle at each end
			if THRONES[k] > 0 then
				local order = sortedBy(L.outer, function(p)
					return math.abs(p.a - mid)
				end)
				local n = 0
				for _, sq in ipairs(order) do
					if n < THRONES[k] and farFrom(sq, taken, 7.9) then
						n += 1
						table.insert(taken, sq)
						throne(sq, 1)
						throne(sq, -1)
					end
				end
				local ends = 0
				for _, sq in ipairs(order) do
					if ends < 2 and farFrom(sq, taken, 7.9) then
						ends += 1
						table.insert(taken, sq)
						candle(sq.x, sq.y, sq.z, propF)
						candle(-sq.x, sq.y, sq.z, propF)
					end
				end
			end
			-- the rest of the outer row: candles and lantern posts in turn every ~12 studs
			local i = 0
			for _, sq in
				ipairs(sortedBy(L.outer, function(p)
					return p.a
				end))
			do
				if farFrom(sq, taken, 12) then
					i += 1
					table.insert(taken, sq)
					if i % 2 == 0 then
						lanternPost(sq, 1)
						lanternPost(sq, -1)
					else
						candle(sq.x, sq.y, sq.z, propF)
						candle(-sq.x, sq.y, sq.z, propF)
					end
				end
			end
			-- the inner row: one birch per sector on tier 1, red bushes, petals (thicker toward the crown)
			local inTaken = {}
			if k == 1 then
				local ta = (mid + (if j % 2 == 0 then 9 else -9)) * DEG
				local tx, tz = 94 * math.sin(ta), ROSE.z + 94 * math.cos(ta)
				local order = sortedBy(L.inner, function(p)
					return (p.x - tx) ^ 2 + (p.z - tz) ^ 2
				end)
				local sq = order[1]
				if sq then
					table.insert(inTaken, sq)
					local loose = {}
					for _ = 1, 3 do
						table.insert(loose, {
							rng:NextInteger(-1, 1) * B,
							rng:NextInteger(0, 2) * B,
							rng:NextInteger(-1, 1) * B,
						})
					end
					birch(sq, 1, 11, loose)
					birch(sq, -1, 11, loose)
				end
			end
			for _, sq in
				ipairs(sortedBy(L.inner, function(p)
					return p.a
				end))
			do
				if farFrom(sq, inTaken, 10) then
					table.insert(inTaken, sq)
					bush(sq.x, sq.y, sq.z, propF, sq.up[1], sq.up[2])
					bush(-sq.x, sq.y, sq.z, propF, -sq.up[1], sq.up[2])
				elseif farFrom(sq, inTaken, 3) and rng:NextNumber() < 0.15 + 0.12 * k then
					local s = rng:NextInteger(2, 4)
					petals(sq.x, sq.y, sq.z, propF, s)
					petals(-sq.x, sq.y, sq.z, propF, s)
				end
			end
		end
		task.wait()
	end
end

-- ================================================================ the crown (SUMMIT): spires, dais, the pillar of light
do
	local crownF = folder("Crown", roseF)
	local CX, CZ, CY = SUMMIT.x, SUMMIT.z, SUMMIT.y
	-- the dais: stepped discs of 2-stud rows (r 8 quartz top y 25, r 6 gold top y 26)
	local function disc(name, r, y0, y1, variant, tint)
		for zr = -r, r - 2, 2 do
			local zc = zr + 1
			local hw = math.floor(math.sqrt(math.max(0, r * r - zc * zc)) / 2 + 0.5) * 2
			if hw > 0 then
				box(name, CX - hw, y0, CZ + zr, CX + hw, y1, CZ + zr + 2, variant, tint, crownF)
			end
		end
	end
	disc("Dais", 8, CY - 1, CY + 1, BRICK, QUARTZ)
	disc("DaisTop", 6, CY + 1, CY + 2, GOLDV, GOLD)
	-- the pillar of light: a Neon core of three rotated 8-stud boxes and a translucent glow, up into the sky
	local y0, y1 = CY + 2, 700
	for i = 0, 2 do
		local p = decor(
			part(
				"LightPillar",
				Vector3.new(8, y1 - y0, 8),
				at(CX, (y0 + y1) / 2, CZ) * CFrame.Angles(0, i * 30 * DEG, 0),
				Color3.fromRGB(255, 253, 244),
				Enum.Material.Neon,
				crownF
			)
		)
		p.CastShadow = false
	end
	for i = 0, 1 do
		local p = decor(
			part(
				"LightGlow",
				Vector3.new(16, y1 - y0, 16),
				at(CX, (y0 + y1) / 2, CZ) * CFrame.Angles(0, (15 + i * 45) * DEG, 0),
				LIGHT,
				Enum.Material.Neon,
				crownF
			)
		)
		p.Transparency = 0.7
		p.CastShadow = false
	end
	for _, h in ipairs({ 5, 26 }) do
		local a =
			decor(part("PillarLight", Vector3.new(1, 1, 1), at(CX, CY + h, CZ), nil, nil, crownF))
		a.Transparency = 1
		light(a, 90, 3, LIGHT)
		stat.lights += 1
	end
	-- end rods round the dais, candles between them, the gold cross before the grand stair head
	for i = 0, 7 do
		local a = (22.5 + 45 * i) * DEG
		local x, z = CX + 10.5 * math.sin(a), CZ + 10.5 * math.cos(a)
		decor(cube("EndRodBase", x, CY + 0.25, z, 1.2, 0.5, 1.2, SMOOTH, SNOW, crownF))
		local rod = decor(
			part(
				"EndRod",
				Vector3.new(0.45, 7, 0.45),
				at(x, CY + 4, z),
				Color3.fromRGB(255, 255, 250),
				Enum.Material.Neon,
				crownF
			)
		)
		rod.CastShadow = false
	end
	for i = 0, 3 do
		local a = (45 + 90 * i) * DEG
		candle(CX + 13 * math.sin(a), CY, CZ + 13 * math.cos(a), crownF)
	end
	box("GoldCross", CX - 2, CY, CZ + 10, CX + 2, CY + 0.08, CZ + 26, GOLDV, GOLD, crownF)
	box("GoldCross", CX - 7, CY, CZ + 13, CX + 7, CY + 0.08, CZ + 17, GOLDV, GOLD, crownF)
	-- pink petals on the crown floor between the dais and the spires (off the cross and the ray heads)
	for x = 2, 18, 4 do
		for z = CZ - 18, CZ + 18, 4 do
			local d = roseDist(x, z)
			local onCross = x < 9 and z > CZ + 8
			if
				d > 12
				and d < 19
				and not onCross
				and clearOfRays(x, z, 1, 1)
				and rng:NextNumber() < 0.45
			then
				local s = rng:NextInteger(2, 4)
				petals(x, CY, z, crownF, s)
				petals(-x, CY, z, crownF, s)
			end
		end
	end
	-- the spires: 3×3 shafts in three stages with gold rings, pinnacles and tips, a gold sun banner outward, a lantern
	-- toward the dais
	local function spire(cf, H, lit)
		local h = H - CY
		local f = folder("Spire", crownF)
		local h1, h2, h3 = 2.6 + (h - 2.6) * 0.42, 2.6 + (h - 2.6) * 0.72, h - 7
		lp("SpirePlinth", cf, -1.8, -8, -1.8, 1.8, 2, 1.8, BRICK, QUARTZ, f, true)
		lp("SpireBand", cf, -1.9, 2, -1.9, 1.9, 2.6, 1.9, GOLDV, GOLD, f, true)
		lp("SpireShaft", cf, -1.5, 2.6, -1.5, 1.5, h1, 1.5, SMOOTH, WHITE, f, true)
		lp("SpireRing", cf, -1.8, h1, -1.8, 1.8, h1 + 0.6, 1.8, GOLDV, GOLD, f)
		lp("SpireShaft", cf, -1.5, h1 + 0.6, -1.5, 1.5, h2, 1.5, BRICK, QUARTZ, f)
		lp("SpireRing", cf, -1.8, h2, -1.8, 1.8, h2 + 0.6, 1.8, GOLDV, GOLD, f)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			lp(
				"SpirePinnacle",
				cf,
				c[1] * 1.1,
				h2 + 0.6,
				c[2] * 1.1,
				c[1] * 1.8,
				h2 + 3.6,
				c[2] * 1.8,
				GOLDV,
				GOLD,
				f
			)
		end
		lp("SpireShaft", cf, -1.1, h2 + 0.6, -1.1, 1.1, h3, 1.1, SMOOTH, WHITE, f)
		lp("SpireTip", cf, -0.8, h3, -0.8, 0.8, h3 + 3, 0.8, SMOOTH, SNOW, f)
		lp("SpireTip", cf, -0.5, h3 + 3, -0.5, 0.5, h3 + 5.5, 0.5, GOLDV, GOLD, f)
		lp("SpireTip", cf, -0.25, h3 + 5.5, -0.25, 0.25, h, 0.25, GOLDV, GOLD, f)
		local bTop = h1 - 1.5
		lp("SpireBannerBar", cf, -1.7, bTop, 1.5, 1.7, bTop + 0.5, 2.1, GOLDV, GOLD, f)
		lp("SpireBanner", cf, -1.3, bTop - 9, 1.6, 1.3, bTop, 1.9, "px_yellow_wool", GOLD, f)
		motif(cf * CFrame.new(0, bTop - 4, 1.75), "sun", f)
		lp("SpireBracket", cf, -0.25, 7, -2.9, 0.25, 7.4, -1.5, GOLDV, GOLD, f)
		lamp((cf * CFrame.new(0, 5.9, -2.6)).Position, f, lit)
	end
	local SPIRE_A = { 45, 75, 105, 135, 165 } -- the mid-angles off the grand stair, east; mirrored west
	local SPIRE_H = { 74, 84, 95, 104, 110 } -- tallest toward the north
	for i, adeg in ipairs(SPIRE_A) do
		for _, m in ipairs({ 1, -1 }) do
			local a = m * adeg * DEG
			spire(
				at(CX + 22 * math.sin(a), CY, CZ + 22 * math.cos(a)) * CFrame.Angles(0, a, 0),
				SPIRE_H[i],
				i % 2 == 1
			)
		end
	end
end

print(
	("[build-paradise] rose: %d parts, %d flights, %d walkways, %d lip runs, %d thrones, %d candles, %d lanterns, %d bushes, %d petals, %d banners, %d birches, %d lights; ray 1 T %s, ray 2 T %s"):format(
		count - partsBefore,
		stat.flights,
		stat.walks,
		stat.lips,
		stat.thrones,
		stat.candles,
		stat.lanterns,
		stat.bushes,
		stat.petals,
		stat.banners,
		stat.birches,
		stat.lights,
		table.concat(RAY[1].T, "/"),
		table.concat(RAY[2].T, "/")
	)
)
