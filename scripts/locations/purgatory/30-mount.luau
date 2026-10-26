--!nocheck
-- ================================================================ purgatory: the MOUNTAIN — terraces L3..L6 and the summit
-- The MOUNT part (zoneOf == "mount": d < 138 from PEAK outside the bay):
--   ring stairs   16 wide at the east (x = +r), west (x = -r) and north (z = -80 - r) crossing of the rings 138, 110,
--                 84, 50 where both terraces are on the island: 4 steps rising 8 from the lower terrace to the upper,
--                 the flight on the lower cell right against the edge (found by scanning cellY), sandstone cheek walls
--                 stepping down, a lantern post on the top landing
--   edges         every terrace edge of the zone (a drop of 8, or the island rim): a cut sandstone kerb 1 block high
--                 with gaps, open at the stairs and at MAIN_UP; the same kerb along the top of the bay wall (open
--                 x -56..56 where the zigzag lands and MAIN_UP starts); sandstone fences on some straight runs; stepped
--                 overhangs (decor) under some edges
--   terraces      L5 (y 40): the band of braziers and soul braziers round the summit's foot, between them cypresses,
--                 obelisks with red banners, benches with pots, soul queues, an hourglass, an arch niche with a soul
--                 altar; L4 (y 32): the same mix with the second hourglass; L3 (y 24): cypresses, queues, benches,
--                 braziers, pots — all against the inner wall, a walkway of ≥ 3 blocks kept along the outer side
--   SUMMIT        L6 (y 48, d < 50): a red / white checkered floor laid flush, a walkway x -12..12 from MAIN_UP (z -34)
--                 to the dais; the dais x -20..20, z -112..-88 (6 high) with three steps (z -88..-76) and a gate; on it
--                 the great angel (0, -102), ~12 blocks tall, wings 8 blocks each side, a gold halo and hair, hands
--                 folded, facing south; 4 obelisks, soul braziers, cypresses, rows of kneeling souls, an arch over the
--                 east stair top and a ruined arch over the west one
local mountF = folder("Mountain")
local startCount = count
local lightsLeft = 25 -- PointLights this part may add
local WHITE = Color3.fromRGB(248, 246, 240)
local GLASS = Color3.fromRGB(215, 235, 240)
local CORNERS4 = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
local DAIS_Y = SUMMIT_Y + 6 -- the angel's dais
local ANGEL = { x = 0, z = -102 }
-- rects { x0, z0, x1, z1 } the props keep off: the zigzag top and MAIN_UP foot on L5, the summit walkway, the dais
local RES = { { -60, -36, 60, -6 }, { -14, -96, 14, -28 }, { -22, -114, 22, -74 } }
-- rects the kerbs and overhangs leave open: MAIN_UP's arrival on the summit, the zigzag's landing on the bay wall top
-- (x -52..52 at z -10, MAIN_UP's foot inside it); the ring stairs add theirs
local NOKERB = { { -14, -44, 14, -24 }, { -56, -20, 56, -4 } }
local EDGE = {} -- the terrace edge cells ("cx:cz"), never built on
local placed = {} -- { x, z, r } props already standing
local built = { stairs = {}, hourglass = 0, braziers = 0, souls = 0 }

local function inAny(list, x, z, pad)
	for _, r in ipairs(list) do
		if inRect(x, z, r, pad) then
			return true
		end
	end
	return false
end
local function cellKey(x, z)
	local s = CELL.size
	return (CELL.x0 + math.floor((x - CELL.x0) / s) * s + s / 2)
		.. ":"
		.. (CELL.z0 + math.floor((z - CELL.z0) / s) * s + s / 2)
end
local function lit(p, range, bright, color)
	if lightsLeft > 0 then
		lightsLeft -= 1
		light(p, range, bright, color)
	end
end
-- a textured part in a frame cf by size and local centre
local function lp(cf, name, sx, sy, sz, x, y, z, variant, tint, parent)
	local p = part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end

-- ================================================================ block props
-- a translucent soul: a blocky human, standing or kneeling, looking from (x, z) toward (tx, tz)
local function soulFigure(x, y, z, tx, tz, kneel, parent)
	local cf = CFrame.lookAt(V(x, y, z), V(tx, y, tz))
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
	end
	if kneel then
		sp("SoulLegs", 2, 1, 2.6, 0, 0.5, 0.5)
		sp("SoulBody", 2, 2.4, 1, 0, 2.2, 0)
		sp("SoulHands", 1.6, 0.8, 1, 0, 2.6, -1)
		sp("SoulHead", 1.6, 1.6, 1.6, 0, 4.2, 0)
	else
		sp("SoulLegs", 2, 2.8, 1, 0, 1.4, 0)
		sp("SoulBody", 2, 2.4, 1, 0, 4, 0)
		sp("SoulArm", 0.8, 2.4, 0.9, -1.4, 4, 0)
		sp("SoulArm", 0.8, 2.4, 0.9, 1.4, 4, 0)
		sp("SoulHead", 1.6, 1.6, 1.6, 0, 6, 0)
	end
	built.souls += 1
end
-- a brazier: a stone brick pedestal, a campfire of crossed logs, a flame of fire or blue soul fire
local function brazier(x, y, z, soul, parent, wantLight)
	local f = folder(if soul then "SoulBrazier" else "Brazier", parent)
	cube("BrazierBase", x, y + 1.5, z, 4, 3, 4, "px_stone_bricks", nil, f)
	cube("BrazierRim", x, y + 3.4, z, 4.4, 0.8, 4.4, "px_smooth_stone", nil, f)
	decor(
		cube(
			"BrazierBed",
			x,
			y + 3.95,
			z,
			3.4,
			0.3,
			3.4,
			if soul then "px_soul_soil" else "px_coal_block",
			nil,
			f
		)
	)
	for _, yaw in ipairs({ math.pi / 4, -math.pi / 4 }) do
		local log = part(
			"BrazierLog",
			Vector3.new(3.6, 0.8, 1),
			at(x, y + 4.4, z) * CFrame.Angles(0, yaw, 0),
			nil,
			nil,
			f
		)
		textured(decor(log), "px_dark_oak_log")
	end
	local col = if soul then SOUL_FIRE else FIRE
	local flame = decor(
		part(
			"Flame",
			Vector3.new(2, 2, 2),
			at(x, y + 5.6, z) * CFrame.Angles(0, math.pi / 4, 0),
			col,
			Enum.Material.Neon,
			f
		)
	)
	flame.Transparency = 0.15
	flame.CastShadow = false
	local tip = decor(
		part(
			"FlameTip",
			Vector3.new(1, 1.4, 1),
			at(x, y + 7.2, z),
			col:Lerp(Color3.new(1, 1, 1), 0.35),
			Enum.Material.Neon,
			f
		)
	)
	tip.Transparency = 0.2
	tip.CastShadow = false
	if wantLight then
		lit(flame, 24, 1.3, col)
	end
	built.braziers += 1
	return f
end
-- an obelisk: a stepped base, a cut sandstone shaft 6 blocks tall with a red banner on each face, a gold tip
local function obelisk(x, y, z, parent)
	local f = folder("Obelisk", parent)
	cube("ObeliskBase", x, y + 2, z, 12, 4, 12, "px_cut_sandstone", SAND_PALE, f)
	cube("ObeliskPlinth", x, y + 5, z, 10, 2, 10, "px_sandstone", SAND_PALE, f)
	cube("ObeliskShaft", x, y + 18, z, 8, 24, 8, "px_cut_sandstone", SAND_PALE, f)
	cube("ObeliskCap", x, y + 31, z, 6, 2, 6, "px_sandstone", SAND_PALE, f)
	cube("ObeliskSpire", x, y + 34, z, 4, 4, 4, "px_cut_sandstone", SAND_PALE, f)
	cube("ObeliskTip", x, y + 37, z, 2, 2, 2, "px_gold_block", nil, f)
	for k = 0, 3 do
		banner(
			at(x, y + 18, z) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, 4.15),
			BANNER_RED,
			f,
			GOLD,
			4,
			14
		)
	end
	return f
end
-- a cypress: a log core, a tall narrow column of hedge leaves, a narrower top, two leaf lumps (stepped)
local function cypress(x, y, z, parent)
	local f = folder("Cypress", parent)
	local h = rng:NextInteger(3, 5) * B
	cube("CypressTrunk", x, y + 3, z, 4, 6, 4, "px_oak_log", nil, f)
	cube("CypressLeaves", x, y + 4 + (8 + h) / 2, z, 8, 8 + h, 8, "px_hedge", CYPRESS, f)
	decor(cube("CypressTop", x, y + 16 + h, z, 4, 8, 4, "px_hedge", CYPRESS, f))
	local sides = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
	local first = rng:NextInteger(1, 4)
	for k = 0, 1 do
		local s = sides[(first + k * 2 - 1) % 4 + 1]
		decor(
			cube(
				"CypressLump",
				x + s[1] * 6,
				y + 10 + k * 4,
				z + s[2] * 6,
				4,
				8,
				4,
				"px_hedge",
				CYPRESS,
				f
			)
		)
	end
	return f
end
-- a dead orange bush: a tuft of bare twigs
local function deadBush(x, y, z, parent)
	local f = folder("DeadBush", parent)
	local base = at(x, y, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
	for i = 0, 3 do
		local cf = base
			* CFrame.Angles(0, i * math.pi / 2, 0)
			* CFrame.Angles(math.rad(30), 0, 0)
			* CFrame.new(0, 1.4, 0)
		decor(part("DeadTwig", Vector3.new(0.5, 2.8, 0.5), cf, DEAD_BUSH, Enum.Material.Wood, f))
	end
	decor(
		part(
			"DeadTwig",
			Vector3.new(0.5, 2.4, 0.5),
			base * CFrame.new(0, 1.2, 0),
			DEAD_BUSH,
			Enum.Material.Wood,
			f
		)
	)
	return f
end
-- a decorated pot (terracotta, a darker neck) with a dead bush or a little hedge
local function pot(x, y, z, parent, plant)
	local f = folder("Pot", parent)
	cube("PotBody", x, y + 1.6, z, 3.2, 3.2, 3.2, "px_terracotta", nil, f)
	cube("PotNeck", x, y + 3.6, z, 2.2, 0.8, 2.2, "px_terracotta", Color3.fromRGB(190, 150, 130), f)
	if plant == "bush" then
		deadBush(x, y + 4, z, f)
	elseif plant == "hedge" then
		decor(cube("PotPlant", x, y + 5, z, 2.4, 2.4, 2.4, "px_hedge", CYPRESS, f))
	end
	return f
end
-- a sandstone arch in frame cf (ground centre; local X across, the front faces -Z): pillars at ±half, a corbel step
-- inside each, a lintel with a gold keystone and a crown; red banners on the pillar fronts; ruined = the right half
-- broken (a short pillar, half a lintel, fallen blocks)
local function arch(cf, half, ht, parent, ruined)
	local f = folder(if ruined then "RuinedArch" else "Arch", parent)
	for _, sx in ipairs({ -1, 1 }) do
		local px = sx * half
		local broken = ruined and sx == 1
		local shaftH = if broken then ht - 10 else ht - 2
		lp(cf, "ArchBase", 6, 2, 6, px, 1, 0, "px_cut_sandstone", SAND_PALE, f)
		lp(cf, "ArchPillar", 4, shaftH, 4, px, 2 + shaftH / 2, 0, "px_sandstone", SAND, f)
		if not broken then
			lp(cf, "ArchCorbel", 4, 4, 4, px - sx * 4, ht - 2, 0, "px_cut_sandstone", SAND_PALE, f)
			banner(cf * CFrame.new(px, ht * 0.55, -2.15), BANNER_RED, f, GOLD, 4, ht * 0.45)
		end
	end
	if ruined then
		lp(cf, "ArchLintel", half + 4, 4, 4, -half / 2, ht + 2, 0, "px_cut_sandstone", SAND_PALE, f)
		lp(cf, "ArchFallen", 4, 4, 4, half + 5, 2, -4, "px_cut_sandstone", SAND_PALE, f).CFrame *= CFrame.Angles(
			0,
			0.4,
			0
		)
		lp(cf, "ArchFallen", 4, 4, 4, half + 2, 2, 6, "px_sandstone", SAND, f).CFrame *= CFrame.Angles(
			0,
			-0.3,
			0
		)
		decor(lp(cf, "ArchRubble", 4, 2, 4, half + 6, 5, -3, "px_sandstone", SAND, f))
	else
		lp(cf, "ArchLintel", 2 * half + 4, 4, 4, 0, ht + 2, 0, "px_cut_sandstone", SAND_PALE, f)
		lp(cf, "ArchCrown", 2 * half - 4, 4, 4, 0, ht + 6, 0, "px_sandstone", SAND_PALE, f)
		decor(lp(cf, "ArchKey", 4, 3.6, 4.4, 0, ht + 2, 0, "px_gold_block", nil, f))
	end
	return f
end
-- a giant hourglass: a dark oak frame (3×3 blocks, 6 tall), stepped glass bulbs, sand, gold caps
local function hourglass(x, y, z, parent)
	local f = folder("Hourglass", parent)
	cube("HourglassBase", x, y + 1, z, 12, 2, 12, "px_dark_oak_planks", nil, f)
	cube("HourglassTop", x, y + 23, z, 12, 2, 12, "px_dark_oak_planks", nil, f)
	for _, c in ipairs(CORNERS4) do
		cube(
			"HourglassPost",
			x + c[1] * 5,
			y + 12,
			z + c[2] * 5,
			2,
			20,
			2,
			"px_dark_oak_log",
			nil,
			f
		)
	end
	cube("HourglassCap", x, y + 2.5, z, 8, 1, 8, "px_gold_block", nil, f)
	cube("HourglassCap", x, y + 21.5, z, 8, 1, 8, "px_gold_block", nil, f)
	cube("HourglassFinial", x, y + 25, z, 4, 2, 4, "px_gold_block", nil, f)
	for _, g in ipairs({
		{ 8, 5, 5.5 },
		{ 6, 3, 9.5 },
		{ 2, 2, 12 },
		{ 6, 3, 14.5 },
		{ 8, 5, 18.5 },
	}) do
		local p = part(
			"HourglassGlass",
			Vector3.new(g[1], g[2], g[1]),
			at(x, y + g[3], z),
			GLASS,
			Enum.Material.Glass,
			f
		)
		p.Transparency = 0.4
		p.CastShadow = false
	end
	cube("HourglassSand", x, y + 5.05, z, 7, 3.9, 7, "px_sand", nil, f)
	decor(cube("HourglassSand", x, y + 7.75, z, 4, 1.5, 4, "px_sand", nil, f))
	decor(cube("HourglassSand", x, y + 17.25, z, 7, 2.5, 7, "px_sand", nil, f))
	decor(cube("HourglassStream", x, y + 12.25, z, 0.6, 7.5, 0.6, "px_sand", nil, f))
	return f
end
-- a bench of dark oak with a pot at each end and a red banner on a post behind (cf: -Z = the view)
local function bench(cf, parent)
	local f = folder("Bench", parent)
	lp(cf, "BenchSeat", 12, 1, 4, 0, 2.5, 0, "px_dark_oak_planks", nil, f)
	for _, sx in ipairs({ -1, 1 }) do
		lp(cf, "BenchLeg", 2, 2, 3, sx * 4.5, 1, 0, "px_dark_oak_log", nil, f)
		local p = (cf * CFrame.new(sx * 9, 0, 0)).Position
		pot(p.X - BX, p.Y - BY, p.Z - BZ, f, if sx < 0 then "hedge" else "bush")
	end
	lp(cf, "BannerPost", 1, 12, 1, 0, 6, 3, "px_dark_oak_planks", nil, f)
	banner(cf * CFrame.new(0, 8, 2.3), BANNER_RED, f, GOLD, 4, 6)
	return f
end

-- ================================================================ the fixed ring stairs (the mountain is climbable)
do
	local stairF = folder("RingStairs", mountF)
	for _, r in ipairs(STAIR_RINGS) do
		for _, d in ipairs({ { 1, 0, "East" }, { -1, 0, "West" }, { 0, -1, "North" } }) do
			local ux, uz = d[1], d[2]
			local sx, sz = -uz, ux -- across the flight
			local function pt(t, s)
				return PEAK.x + ux * t + sx * s, PEAK.z + uz * t + sz * s
			end
			local function cy(t, s)
				local x, z = pt(t, s)
				return cellY(x, z)
			end
			-- the edge: the distance t where both rows of the 16-wide flight step down by STEP_Y going outward
			local edge
			for t = r - 20, r + 20 do
				local yi, yo = cy(t - 0.5, -4), cy(t + 0.5, -4)
				if
					yi
					and yo
					and yi - yo == STEP_Y
					and cy(t - 0.5, 4) == yi
					and cy(t + 0.5, 4) == yo
				then
					edge = t
					break
				end
			end
			local ok = edge ~= nil
			local yl, yu
			if ok then
				yl, yu = cy(edge + 4, -4), cy(edge - 4, -4)
				-- the landing below (the flight's cell and one more), the top landing (two cells of the same ground)
				for _, s in ipairs({ -4, 4 }) do
					ok = ok and cy(edge + 4, s) == yl and cy(edge + 12, s) == yl
					ok = ok and cy(edge - 4, s) == yu and cy(edge - 12, s) == yu
				end
				local lx, lz = pt(edge + 12, 0)
				ok = ok and not inBay(lx, lz, 8)
			end
			if ok then
				local f = folder(("RingStair%d%s"):format(r, d[3]), stairF)
				local ex, ez = pt(edge, 0)
				if ux ~= 0 then
					stairs(
						"RingStair",
						PEAK.z,
						ex + ux * 8,
						ex,
						yl,
						STEP_Y,
						STAIR_W,
						"px_cut_sandstone",
						f,
						"x"
					)
				else
					stairs(
						"RingStair",
						PEAK.x,
						ez + uz * 8,
						ez,
						yl,
						STEP_Y,
						STAIR_W,
						"px_cut_sandstone",
						f
					)
				end
				local function boxTS(name, t0, t1, s0, s1, y0, y1, variant, tint)
					local xa, za = pt(t0, s0)
					local xb, zb = pt(t1, s1)
					return box(name, xa, y0, za, xb, y1, zb, variant, tint, f)
				end
				-- the cheek walls: a cap block over the top edge, a full wall beside the upper steps, a low one below
				for _, s in ipairs({ -1, 1 }) do
					boxTS(
						"StairCheek",
						edge - 4,
						edge + 4,
						s * 8,
						s * 12,
						yl,
						yu,
						"px_sandstone",
						SAND
					)
					boxTS(
						"StairCheekCap",
						edge - 4,
						edge + 4,
						s * 8,
						s * 12,
						yu,
						yu + B,
						"px_cut_sandstone",
						SAND_PALE
					)
					boxTS(
						"StairCheek",
						edge + 4,
						edge + 8,
						s * 8,
						s * 12,
						yl,
						yl + B,
						"px_sandstone",
						SAND
					)
				end
				-- a lantern post on the cap at the top landing
				local px, pz = pt(edge - 2, 10)
				textured(
					part("LanternPost", Vector3.new(1, 4, 1), at(px, yu + B + 2, pz), nil, nil, f),
					"px_dark_oak_planks"
				)
				lightsLeft -= 1
				lantern(V(px, yu + B + 4.75, pz), f)
				-- keep the props off both landings, open the kerb over the flight
				local function rect(t0, t1, s0, s1)
					local xa, za = pt(t0, s0)
					local xb, zb = pt(t1, s1)
					return { math.min(xa, xb), math.min(za, zb), math.max(xa, xb), math.max(za, zb) }
				end
				table.insert(RES, rect(edge - 16, edge + 20, -16, 16))
				table.insert(NOKERB, rect(edge - 8, edge + 8, -12, 12))
				table.insert(
					built.stairs,
					("%s r%d edge (%d, %d) y %d→%d"):format(d[3], r, ex, ez, yl, yu)
				)
			end
		end
	end
	print(
		("[build-purgatory] mount: ring stairs %d — %s"):format(
			#built.stairs,
			table.concat(built.stairs, "; ")
		)
	)
end
task.wait()

-- ================================================================ the terrace edges: kerbs, fences, overhangs
do
	local edgeF = folder("TerraceEdges", mountF)
	local D4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local units, unitList = {}, {}
	local lines, lineKeys = {}, {}
	local function addUnit(ux, uz, y)
		local k = ux .. ":" .. uz
		if not units[k] then
			units[k] = { x = ux, z = uz, y = y }
			table.insert(unitList, units[k])
		end
		return units[k]
	end
	for cz = CELL.z0 + 4, 60, 8 do
		for cx = -140, 140, 8 do
			local y = cellY(cx, cz)
			if y and zoneOf(cx, cz) == "mount" then
				for di, d in ipairs(D4) do
					local nx, nz = cx + d[1] * 8, cz + d[2] * 8
					local ny = cellY(nx, nz)
					local drop = ny == y - STEP_Y and zoneOf(nx, nz) ~= "bay"
					-- the top of the bay wall (a 24..40 drop to the bay floor): a kerb too, no fence or overhang
					local bayTop = ny == 0 and inBay(nx, nz) and y > 0
					if drop or bayTop or ny == nil then
						EDGE[cellKey(cx, cz)] = true
						local a, b
						if d[1] ~= 0 then
							local ux = if d[1] > 0 then cx else cx - 4
							a, b = addUnit(ux, cz - 4, y), addUnit(ux, cz, y)
						else
							local uz = if d[2] > 0 then cz else cz - 4
							a, b = addUnit(cx - 4, uz, y), addUnit(cx, uz, y)
						end
						if bayTop then -- no gaps over the deep drop
							a.solid, b.solid = true, true
						end
						local face = if d[1] ~= 0 then cx + d[1] * 4 else cz + d[2] * 4
						local key = di .. ":" .. face .. ":" .. y
						if not lines[key] then
							lines[key] = { d = d, face = face, y = y, cells = {} }
							table.insert(lineKeys, key)
						end
						table.insert(
							lines[key].cells,
							{ along = if d[1] ~= 0 then cz else cx, a = a, b = b, drop = drop }
						)
					end
				end
			end
		end
	end
	-- straight runs of edge cells along each face line
	local runs = {}
	for _, key in ipairs(lineKeys) do
		local L = lines[key]
		table.sort(L.cells, function(p, q)
			return p.along < q.along
		end)
		local cur
		for _, c in ipairs(L.cells) do
			if cur and c.along == cur.cells[#cur.cells].along + 8 and c.drop == cur.drop then
				table.insert(cur.cells, c)
			else
				cur = { d = L.d, face = L.face, y = L.y, drop = c.drop, cells = { c } }
				table.insert(runs, cur)
			end
		end
	end
	local nFence, nOver = 0, 0
	for _, run in ipairs(runs) do
		local d, F, y = run.d, run.face, run.y
		local a0, a1 = run.cells[1].along - 4, run.cells[#run.cells].along + 4
		-- a point on the face at `along`, `out` studs outward
		local function fp(along, out)
			if d[1] ~= 0 then
				return F + d[1] * out, along
			end
			return along, F + d[2] * out
		end
		local open = false
		for a = a0, a1, 4 do
			local x, z = fp(a, -2)
			if inAny(NOKERB, x, z, 2) then
				open = true
			end
		end
		local mx, mz = fp((a0 + a1) / 2, 0)
		local fenced = run.drop and not open and #run.cells >= 2 and n2(mx, mz, 5.5, 0.045) > 0.18
		for _, c in ipairs(run.cells) do
			for _, u in ipairs({ c.a, c.b }) do
				if fenced then
					u.fence = true
				else
					u.kerb = true
				end
			end
		end
		if fenced then
			-- shorten the fence where a kerb of the next face holds the corner unit
			local s0, s1 = a0 + 2, a1 - 2
			if run.cells[1].a.kerb or run.cells[1].b.kerb then
				s0 += 4
			end
			local last = run.cells[#run.cells]
			if last.a.kerb or last.b.kerb then
				s1 -= 4
			end
			if s1 > s0 then
				local ax, az = fp(s0, -2)
				local bx, bz = fp(s1, -2)
				fence(ax, az, bx, bz, edgeF, y, "px_sandstone")
				nFence += 1
			end
		end
		-- stepped overhangs under the edge (decor), z-facing ones 0.1 lower so corners never fight
		if run.drop and not open and n2(mx, mz, 8.8, 0.05) > 0.05 then
			local lo = if d[1] ~= 0 then 0 else 0.1
			local xa, za = fp(a0, 0)
			local xb, zb = fp(a1, 2)
			decor(
				box(
					"Overhang",
					xa,
					y - 2 - lo,
					za,
					xb,
					y - lo,
					zb,
					"px_cut_sandstone",
					SAND_PALE,
					edgeF
				)
			)
			xb, zb = fp(a1, 1)
			decor(
				box("Overhang", xa, y - 4 - lo, za, xb, y - 2 - lo, zb, "px_sandstone", SAND, edgeF)
			)
			nOver += 1
		end
	end
	-- the kerb: the marked units minus the openings and a gap every few blocks, merged into runs
	local K, final = {}, {}
	for _, u in ipairs(unitList) do
		local gap = not u.solid and ((u.x / 4) * 7 + (u.z / 4) * 11) % 9 == 0
		if u.kerb and not gap and not inAny(NOKERB, u.x + 2, u.z + 2) then
			K[u.x .. ":" .. u.z] = u
			table.insert(final, u)
		end
	end
	table.sort(final, function(p, q)
		if p.z ~= q.z then
			return p.z < q.z
		end
		return p.x < q.x
	end)
	local used, nKerb = {}, 0
	for _, u in ipairs(final) do
		if not used[u.x .. ":" .. u.z] then
			local function free(x, z)
				local k = x .. ":" .. z
				return K[k] ~= nil and not used[k] and K[k].y == u.y
			end
			local nx, nz = 1, 1
			while free(u.x + nx * 4, u.z) do
				nx += 1
			end
			while free(u.x, u.z + nz * 4) do
				nz += 1
			end
			if nx >= nz then
				nz = 1
			else
				nx = 1
			end
			for i = 0, nx - 1 do
				for j = 0, nz - 1 do
					used[(u.x + i * 4) .. ":" .. (u.z + j * 4)] = true
				end
			end
			box(
				"Kerb",
				u.x,
				u.y,
				u.z,
				u.x + nx * 4,
				u.y + B,
				u.z + nz * 4,
				"px_cut_sandstone",
				SAND_PALE,
				edgeF
			)
			nKerb += 1
		end
	end
	print(
		("[build-purgatory] mount: edges %d runs, kerb %d boxes, fences %d, overhangs %d"):format(
			#runs,
			nKerb,
			nFence,
			nOver
		)
	)
end
task.wait()

-- props: a free spot of half-size h on one terrace, off the stairs, the edges and other props, with a walkway of
-- `walk` studs kept on its outer side; returns the ground y
local function spot(x, z, h, walk)
	if zoneOf(x, z) ~= "mount" or inBay(x, z, h + 12) then
		return nil
	end
	if not freeGround(x, z, math.max(0, h - 4)) or inAny(RES, x, z, h + 1) then
		return nil
	end
	local y = cellY(x, z)
	if EDGE[cellKey(x, z)] then
		return nil
	end
	for _, c in ipairs(CORNERS4) do
		local qx, qz = x + c[1] * (h - 0.5), z + c[2] * (h - 0.5)
		if cellY(qx, qz) ~= y or EDGE[cellKey(qx, qz)] or zoneOf(qx, qz) ~= "mount" then
			return nil
		end
	end
	local d = peakDist(x, z)
	if d > 1 then
		local ox, oz = (x - PEAK.x) / d, (z - PEAK.z) / d
		for _, k in ipairs({ h + 4, h + walk }) do
			local qx, qz = x + ox * k, z + oz * k
			if cellY(qx, qz) ~= y or (k < h + walk and EDGE[cellKey(qx, qz)]) then
				return nil
			end
		end
	end
	for _, p in ipairs(placed) do
		if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < (h + p[3] + 2) ^ 2 then
			return nil
		end
	end
	return y
end
local function claim(x, z, r)
	table.insert(placed, { x, z, r })
end

-- ================================================================ the SUMMIT: floor, dais, gate, the great angel
do
	local summitF = folder("Summit", mountF)
	-- a flat summit spot: every corner on the plaza, off the edge cells
	local function flat(x, z, h)
		for _, c in ipairs({ { 0, 0 }, table.unpack(CORNERS4) }) do
			local qx, qz = x + c[1] * h, z + c[2] * h
			if cellY(qx, qz) ~= SUMMIT_Y or zoneOf(qx, qz) ~= "mount" or EDGE[cellKey(qx, qz)] then
				return false
			end
		end
		return true
	end
	-- the checkered floor laid flush: 1-block squares of red sandstone / cut sandstone, a cut sandstone walkway with
	-- red borders from MAIN_UP to the steps; equal neighbours along x merge
	do
		local f = folder("SummitFloor", summitF)
		local function blockAt(bx, bz)
			if cellY(bx, bz) ~= SUMMIT_Y or zoneOf(bx, bz) ~= "mount" then
				return nil
			end
			local ax = math.abs(bx)
			if (ax < 20 and bz > -112 and bz < -88) or (ax < 16 and bz > -88 and bz < -76) then
				return nil -- under the dais and the steps
			end
			if bz > -76 and ax < 8 then
				return "px_cut_sandstone"
			elseif bz > -76 and ax < 12 then
				return "px_cut_red_sandstone"
			end
			return if (math.floor(bx / 4) + math.floor(bz / 4)) % 2 == 0
				then "px_red_sandstone"
				else "px_cut_sandstone"
		end
		local n = 0
		for bz = -134, -26, 4 do
			local runX, runV
			local function flush(xEnd)
				if runX then
					box(
						"SummitFloor",
						runX,
						SUMMIT_Y,
						bz - 2,
						xEnd,
						SUMMIT_Y + 0.1,
						bz + 2,
						runV,
						nil,
						f
					)
					n += 1
				end
				runX = nil
			end
			for bx = -54, 54, 4 do
				local v = blockAt(bx, bz)
				if v ~= runV then
					flush(bx - 2)
					if v then
						runX = bx - 2
					end
					runV = v
				end
			end
			flush(56)
		end
		print(("[build-purgatory] mount: summit floor %d runs"):format(n))
	end
	task.wait()
	-- the dais with three steps and a gate
	do
		local f = folder("Dais", summitF)
		box("Dais", -20, SUMMIT_Y, -112, 20, DAIS_Y - 2, -88, "px_cut_sandstone", SAND_PALE, f)
		box("DaisCourse", -20, DAIS_Y - 2, -112, 20, DAIS_Y, -88, "px_smooth_stone", WHITE, f)
		box("DaisCarpet", -8, DAIS_Y, -94, 8, DAIS_Y + 0.1, -88, "px_cut_red_sandstone", nil, f)
		for i = 1, 3 do
			local z1 = -76 - (i - 1) * 4
			box(
				"DaisStep",
				-16,
				SUMMIT_Y,
				z1 - 4,
				16,
				SUMMIT_Y + i * 1.5,
				z1,
				"px_smooth_stone",
				WHITE,
				f
			)
		end
		local ramp = Instance.new("WedgePart")
		ramp.Name = "DaisRamp"
		ramp.Anchored = true
		ramp.Transparency = 1
		ramp.Size = Vector3.new(32, DAIS_Y - SUMMIT_Y, 12)
		ramp.CFrame = at(0, (SUMMIT_Y + DAIS_Y) / 2, -82) * CFrame.Angles(0, math.pi, 0)
		ramp.Parent = f
		-- the gate on the dais front: two pillars, a lintel with a gold block, a crest, red banners
		for _, sx in ipairs({ -1, 1 }) do
			box(
				"GatePillar",
				sx * 16,
				DAIS_Y,
				-92,
				sx * 20,
				DAIS_Y + 16,
				-88,
				"px_cut_sandstone",
				SAND_PALE,
				f
			)
			box(
				"GatePillarBase",
				sx * 15,
				DAIS_Y,
				-93,
				sx * 21,
				DAIS_Y + 2,
				-87,
				"px_sandstone",
				SAND_PALE,
				f
			)
			banner(at(sx * 18, DAIS_Y + 9, -86.85), BANNER_RED, f, GOLD, 4, 9)
		end
		box(
			"GateLintel",
			-21,
			DAIS_Y + 16,
			-93,
			21,
			DAIS_Y + 20,
			-87,
			"px_cut_sandstone",
			SAND_PALE,
			f
		)
		box("GateCrest", -10, DAIS_Y + 20, -92, 10, DAIS_Y + 23, -88, "px_sandstone", SAND_PALE, f)
		decor(
			box(
				"GateGold",
				-2,
				DAIS_Y + 16.2,
				-87.2,
				2,
				DAIS_Y + 19.8,
				-86.8,
				"px_gold_block",
				nil,
				f
			)
		)
		-- soul braziers flanking the angel on the dais
		for _, sx in ipairs({ -1, 1 }) do
			brazier(sx * 16, DAIS_Y, -100, true, f, true)
		end
	end
	task.wait()
	-- the great angel: robe stepping out at the base, folded hands, gold hair and halo, wide stepped wings
	do
		local f = folder("Angel", summitF)
		local AX, AZ, Y0 = ANGEL.x, ANGEL.z, DAIS_Y
		local P, S, G = "px_white_stone_bricks", "px_smooth_stone", "px_gold_block"
		local function bx(name, x0, y0, z0, x1, y1, z1, v, tint, isDecor)
			local p = box(name, AX + x0, Y0 + y0, AZ + z0, AX + x1, Y0 + y1, AZ + z1, v, tint, f)
			if isDecor then
				decor(p)
			end
			return p
		end
		bx("AngelPlinth", -12, 0, -8, 12, 3, 8, "px_cut_sandstone", SAND_PALE)
		bx("AngelTrim", -12.2, 2, -8.2, 12.2, 2.6, 8.2, G, nil, true)
		bx("AngelHem", -10, 3, -6, 10, 8, 6, P, nil)
		bx("AngelRobe", -8, 8, -5, 8, 22, 5, P, nil)
		bx("AngelFold", -3, 8, 5, 3, 20, 6, S, WHITE)
		bx("AngelTorso", -7, 22, -4, 7, 34, 4, P, nil)
		bx("AngelBelt", -8.3, 21, -5.3, 8.3, 23, 5.3, G, nil, true)
		for _, sx in ipairs({ -1, 1 }) do
			bx("AngelSleeve", sx * 7, 22, -4, sx * 11, 34, 4, P, nil)
			bx("AngelCuff", sx * 7, 20, -4.5, sx * 12, 24, 4.5, S, WHITE)
		end
		bx("AngelForearms", -7, 24, 4, 7, 28, 7, S, WHITE)
		bx("AngelHands", -2, 26, 5, 2, 33, 8, S, WHITE)
		bx("AngelShoulders", -11, 34, -4, 11, 36, 4, S, WHITE)
		bx("AngelNeck", -2, 36, -2, 2, 38, 2, S, WHITE)
		bx("AngelHead", -4, 38, -4, 4, 46, 4, S, WHITE)
		bx("AngelHair", -5, 31, -5, 5, 47, -1, G, nil)
		for _, sx in ipairs({ -1, 1 }) do
			bx("AngelHairSide", sx * 4, 36, -1, sx * 5.5, 46, 2, G, nil, true)
		end
		bx("AngelHairTop", -5, 46, -5, 5, 48, 3, G, nil)
		-- the halo: a ring of gold blocks behind the head (a 5×5 square without its corners)
		for i = -2, 2 do
			for j = -2, 2 do
				local ring = math.max(math.abs(i), math.abs(j)) == 2
					and not (math.abs(i) == 2 and math.abs(j) == 2)
				if ring then
					bx(
						"AngelHalo",
						i * 4 - 2,
						48 + j * 4 - 2,
						-6.5,
						i * 4 + 2,
						48 + j * 4 + 2,
						-5.5,
						G,
						nil,
						true
					)
				end
			end
		end
		-- the wings: 8 columns a side rising outward, each in three feather rows, hanging tips under every other
		local COLS = {
			{ 20, 38 },
			{ 18, 42 },
			{ 18, 46 },
			{ 20, 50 },
			{ 24, 54 },
			{ 30, 56 },
			{ 36, 58 },
			{ 42, 58 },
		}
		for _, sx in ipairs({ -1, 1 }) do
			for i, c in ipairs(COLS) do
				local xa, xb = sx * (6 + (i - 1) * 4), sx * (6 + i * 4)
				local lo, hi = c[1], c[2]
				local m1 = lo + math.floor((hi - lo) / 3 / 2 + 0.5) * 2
				local m2 = lo + math.floor((hi - lo) * 2 / 3 / 2 + 0.5) * 2
				bx("WingFeathers", xa, lo, -10, xb, m1, -7, P, nil)
				bx("WingFeathers", xa, m1, -10, xb, m2, -7, S, WHITE)
				bx("WingCoverts", xa, m2, -10, xb, hi, -7, P, nil)
				if i % 2 == 1 then
					local ia, ib = xa + sx * 0.5, xb - sx * 0.5
					bx("WingTip", ia, lo - 6, -9.5, ib, lo, -7.5, S, WHITE, true)
				end
			end
		end
	end
	task.wait()
	-- obelisks, soul braziers, cypresses, the arches over the side stairs, kneeling souls, dead bushes
	do
		local f = folder("SummitProps", summitF)
		-- nothing standing within r (+2) of (x, z)
		local function vacant(x, z, r)
			for _, p in ipairs(placed) do
				if (x - p[1]) ^ 2 + (z - p[2]) ^ 2 < (r + p[3] + 2) ^ 2 then
					return false
				end
			end
			return true
		end
		for _, sx in ipairs({ -1, 1 }) do
			for _, p in ipairs({ { 30, -104 }, { 22, -54 } }) do
				local x, z = sx * p[1], p[2]
				if flat(x, z, 5.5) then
					obelisk(x, SUMMIT_Y, z, f)
					claim(x, z, 6)
				end
			end
			for _, p in ipairs({ { 18, -42 }, { 14, -122 } }) do
				local x, z = sx * p[1], p[2]
				if flat(x, z, 1.5) and vacant(x, z, 2) and not inAny(NOKERB, x, z, 2) then
					brazier(x, SUMMIT_Y, z, true, f, p[2] > -60)
					claim(x, z, 2)
				end
			end
			for _, p in ipairs({ { 38, -100 }, { 34, -58 }, { 26, -118 }, { 40, -62 } }) do
				local x, z = sx * p[1], p[2]
				if
					flat(x, z, 3.5)
					and vacant(x, z, 4)
					and not inAny(RES, x, z, 4)
					and not inAny(NOKERB, x, z, 4)
				then
					cypress(x, SUMMIT_Y, z, f)
					claim(x, z, 4)
				end
			end
			-- the arch over the east stair top, the ruined one over the west
			local ax = sx * 36
			if flat(ax, -92, 2) and flat(ax, -68, 2) then
				arch(
					at(ax, SUMMIT_Y, -80) * CFrame.Angles(0, sx * math.pi / 2, 0),
					12,
					16,
					f,
					sx < 0
				)
			end
			-- rows of kneeling souls facing the angel, both sides of the walkway
			for _, z in ipairs({ -64, -70, -76 }) do
				for _, x in ipairs({ 18, 22, 26 }) do
					if flat(sx * x, z, 1.5) then
						soulFigure(sx * x, SUMMIT_Y + 0.1, z, ANGEL.x, ANGEL.z, true, f)
					end
				end
			end
		end
		local nb = 0
		for _ = 1, 40 do
			if nb >= 10 then
				break
			end
			local a, d = rng:NextNumber() * math.pi * 2, rng:NextNumber() * 44
			local x, z = PEAK.x + math.cos(a) * d, PEAK.z + math.sin(a) * d
			if flat(x, z, 1.5) and not inAny(RES, x, z, 3) and not inAny(NOKERB, x, z, 3) then
				if vacant(x, z, 2) then
					deadBush(x, SUMMIT_Y + 0.1, z, f)
					claim(x, z, 1)
					nb += 1
				end
			end
		end
	end
end
task.wait()

-- ================================================================ life on the terraces L5, L4, L3
do
	local lifeF = folder("Terraces", mountF)
	-- the arc a prop takes along the ring and its half size across it
	local SIZE = {
		fire = { 2, 4 },
		soul = { 2, 4 },
		cypress = { 4, 8 },
		obelisk = { 6, 12 },
		hourglass = { 6, 12 },
		queue = { 2, 30 },
		bench = { 3, 22 },
		arch = { 3, 22 },
		pots = { 3, 10 },
		bush = { 2, 4 },
	}
	local TERRACES = {
		{
			lvl = 5,
			rin = 50,
			items = {
				"fire",
				"cypress",
				"soul",
				"queue",
				"fire",
				"obelisk",
				"soul",
				"bench",
				"fire",
				"hourglass",
				"soul",
				"cypress",
				"fire",
				"arch",
				"soul",
				"queue",
				"fire",
				"pots",
				"soul",
				"obelisk",
			},
		},
		{
			lvl = 4,
			rin = 84,
			items = {
				"queue",
				"cypress",
				"fire",
				"obelisk",
				"bench",
				"soul",
				"cypress",
				"hourglass",
				"pots",
				"arch",
				"bush",
				"queue",
				"cypress",
				"soul",
				"obelisk",
				"bench",
				"fire",
				"cypress",
				"bush",
			},
		},
		{
			lvl = 3,
			rin = 110,
			items = {
				"cypress",
				"queue",
				"fire",
				"pots",
				"cypress",
				"bench",
				"soul",
				"bush",
				"cypress",
				"queue",
				"bush",
				"pots",
			},
		},
	}
	local counts = {}
	-- try one prop at angle a on terrace T; returns true when built
	local function tryItem(kind, a, T, yT)
		if kind == "hourglass" and built.hourglass >= 2 then
			return false
		end
		local h = SIZE[kind][1]
		local ca, sa = math.cos(a), math.sin(a)
		local tx, tz = -sa, ca -- along the ring
		for k = 0, 3 do
			local d = T.rin + h + 1 + k * 3
			local x, z = PEAK.x + ca * d, PEAK.z + sa * d
			local y = spot(x, z, h, 12)
			if y == yT then
				-- the frame facing outward (-Z looks away from the summit), local X along the ring
				local cf = CFrame.lookAt(V(x, y, z), V(x + ca, y, z + sa))
				if kind == "fire" or kind == "soul" then
					local soul = kind == "soul"
					brazier(x, y, z, soul, lifeF, built.braziers % 3 == 0)
					claim(x, z, h)
				elseif kind == "cypress" then
					cypress(x, y, z, lifeF)
					claim(x, z, h)
				elseif kind == "obelisk" then
					obelisk(x, y, z, lifeF)
					claim(x, z, h)
				elseif kind == "hourglass" then
					hourglass(x, y, z, lifeF)
					claim(x, z, h)
					built.hourglass += 1
				elseif kind == "bush" then
					deadBush(x, y, z, lifeF)
					claim(x, z, h)
				elseif kind == "pots" then
					local n = rng:NextInteger(2, 3)
					for i = 1, n do
						local o = (i - (n + 1) / 2) * 3.6
						pot(
							x + tx * o,
							y,
							z + tz * o,
							lifeF,
							if i == 2 then "bush" elseif i == 1 then "hedge" else nil
						)
					end
					claim(x, z, h + 2)
				elseif kind == "bench" or kind == "arch" then
					local ends = if kind == "bench" then 9 else 8
					if
						spot(x + tx * ends, z + tz * ends, h, 12) ~= y
						or spot(x - tx * ends, z - tz * ends, h, 12) ~= y
					then
						return false
					end
					if kind == "bench" then
						bench(cf, lifeF)
					else
						arch(cf, 8, 14, lifeF, false)
						brazier(x, y, z, true, lifeF, false)
					end
					claim(x, z, 11)
				elseif kind == "queue" then
					-- a row of souls along the ring, all facing the summit
					local n = rng:NextInteger(4, 8)
					local ok = {}
					for i = 1, n do
						local o = (i - (n + 1) / 2) * 4
						local qx, qz = x + tx * o, z + tz * o
						if spot(qx, qz, 2, 12) ~= y then
							break
						end
						table.insert(ok, { qx, qz })
					end
					if #ok < 4 then
						return false
					end
					for _, q in ipairs(ok) do
						soulFigure(q[1], y, q[2], PEAK.x, PEAK.z, false, lifeF)
						claim(q[1], q[2], 1.5)
					end
				end
				counts[kind] = (counts[kind] or 0) + 1
				return true
			end
		end
		return false
	end
	for _, T in ipairs(TERRACES) do
		local yT = T.lvl * STEP_Y
		local rm = T.rin + 8
		local circ = 2 * math.pi * rm
		local a0 = rng:NextNumber() * math.pi * 2
		local s, idx, misses = 0, 1, 0
		while s < circ do
			local kind = T.items[idx]
			if tryItem(kind, a0 + s / rm, T, yT) then
				s += SIZE[kind][2] + 6
				idx = idx % #T.items + 1
				misses = 0
			else
				s += 4
				misses += 1
				if misses > 8 then -- this one does not fit here: try the next kind
					idx = idx % #T.items + 1
					misses = 0
				end
			end
		end
		task.wait()
	end
	-- a few more dead bushes in the gaps
	for _, T in ipairs(TERRACES) do
		local n = 0
		for _ = 1, 60 do
			if n >= 8 then
				break
			end
			local a = rng:NextNumber() * math.pi * 2
			local d = T.rin + 3 + rng:NextNumber() * 6
			local x, z = PEAK.x + math.cos(a) * d, PEAK.z + math.sin(a) * d
			local y = spot(x, z, 2, 12)
			if y == T.lvl * STEP_Y then
				deadBush(x, y, z, lifeF)
				claim(x, z, 1)
				n += 1
			end
		end
	end
	local parts = {}
	for k, v in pairs(counts) do
		table.insert(parts, k .. " " .. v)
	end
	table.sort(parts)
	print(
		("[build-purgatory] mount: terraces — %s; hourglasses %d"):format(
			table.concat(parts, ", "),
			built.hourglass
		)
	)
end

print(
	("[build-purgatory] mount: %d parts, %d souls, %d braziers, lights left %d"):format(
		count - startCount,
		built.souls,
		built.braziers,
		lightsLeft
	)
)
