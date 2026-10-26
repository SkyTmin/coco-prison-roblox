--!nocheck
-- ================================================================ tree: THE TREE (the hero) — trunk, stair, summit, crown
-- The hollow trunk centre (36, -48): outer r ≈ 25–28 (a flared base and 8 root buttresses out to r ≈ 50–64), walls
-- 2 blocks of a bark mix (dark oak ≈ 60 %, oak ≈ 30 %, stripped wood ≈ 10 %, moss patches) from y 0 to the deck at
-- y 136, a stripped-wood column r 8 in the middle. The pointed arched door on the south face x 28..44 (4 blocks wide
-- to the spring at y 20, 2 blocks to the tip at y 28) in a stripped-wood frame, two lanterns, plank steps. Inside, a
-- 3-block spiral stair between the column (r 8) and the wall (r 20.5): 4 turns, 35 studs a turn (each quarter: a
-- 2-segment landing + 6 steps of 1.46 studs), 32 studs of headroom, windows in the bark every half turn, a lantern
-- on every landing; it comes up through a stone-rimmed hatch in the SUMMIT deck (top y 140, r ≈ 46): a mossy stone
-- circle, a ring of six ruined arches, planters, benches, lamp posts, a fence with two gaps to the rope bridges;
-- three upper limbs carry the crown roof. Five big branches leave the trunk at y 88..112: three carry plank platforms
-- (r 12) joined by rope bridges (deck → West, deck → North-east, West → North), two hold the basket lift, hanging
-- lanterns and a birdhouse. The crown: leaf cushions in 8-stud cells (oak, azalea, flowering azalea) y 120..200 out
-- to r ≈ 90, clear of the deck (≥ 3 blocks of air above it), the bridges and the platforms. Under the central island
-- the taproots hang 30–38 blocks lower. Every bark, deck and leaf mass is a voxel grid merged into runs (x), rows
-- (z) and stacked layers (y): one box per run.
local treeF = folder("TheTree")
local c0 = count
local CX, CZ, SY = TREE.x, TREE.z, SUMMIT.y
local RAD = math.pi / 180
local IRON = Color3.fromRGB(45, 45, 50)
local lit = 0 -- PointLights made by this part (≤ 30)

local STYLE = {
	dark = { "px_dark_oak_log", nil },
	oak = { "px_oak_log", BARK },
	strip = { "px_birch_log", Color3.fromRGB(222, 186, 138) }, -- stripped wood
	moss = { "px_hedge", MOSS },
	root = { "px_dark_oak_log", BARK_DARK },
	plank = { "px_planks", nil },
	spruce = { "px_spruce_planks", nil },
	dmoss = { "px_grass_top", MOSS },
	cob = { "px_mossy_cobblestone", nil },
	msb = { "px_mossy_stone_bricks", nil },
	oakL = { "px_hedge", OAK_LEAF },
	azaL = { "px_hedge", AZALEA },
	bloL = { "px_cherry_leaves", BLOSSOM },
}

-- ---------------------------------------------------------------- voxel grids: cells[j][k][i] = style key
local G = {}
function G.new(s)
	return { s = s, cells = {} }
end
function G.set(g, i, j, k, key)
	local L = g.cells[j]
	if not L then
		if key == nil then
			return
		end
		L = {}
		g.cells[j] = L
	end
	local R = L[k]
	if not R then
		if key == nil then
			return
		end
		R = {}
		L[k] = R
	end
	R[i] = key
end
function G.get(g, i, j, k)
	local L = g.cells[j]
	local R = L and L[k]
	return R and R[i]
end
function G.keys(t)
	local ks = {}
	for k in pairs(t) do
		table.insert(ks, k)
	end
	table.sort(ks)
	return ks
end
-- a log of `size` cells along a straight line (local studs); keyFn(x, y, z) → key or nil (skip the cell)
function G.line(g, a, b, size, keyFn)
	local dx, dy, dz = b[1] - a[1], b[2] - a[2], b[3] - a[3]
	local n = math.max(1, math.ceil(math.sqrt(dx * dx + dy * dy + dz * dz) / 2))
	local half = size * g.s / 2
	for t = 0, n do
		local f = t / n
		local x, y, z = a[1] + dx * f, a[2] + dy * f, a[3] + dz * f
		local i0 = math.floor((x - half) / g.s + 0.5)
		local j0 = math.floor((y - half) / g.s + 0.5)
		local k0 = math.floor((z - half) / g.s + 0.5)
		for j = j0, j0 + size - 1 do
			for k = k0, k0 + size - 1 do
				for i = i0, i0 + size - 1 do
					local key = keyFn(i * g.s + g.s / 2, j * g.s + g.s / 2, k * g.s + g.s / 2)
					if key then
						G.set(g, i, j, k, key)
					end
				end
			end
		end
	end
end
-- the grid → boxes: equal neighbours along x become runs, equal runs on following rows (z) rectangles (mergeZ),
-- equal rectangles on following layers (y) one box
function G.emit(g, name, parent, isDecor, mergeZ)
	local s = g.s
	local made = 0
	local function place(r)
		local st = STYLE[r.key]
		local p = box(
			name,
			r.i0 * s,
			r.j0 * s,
			r.k0 * s,
			(r.i1 + 1) * s,
			(r.j1 + 1) * s,
			(r.k1 + 1) * s,
			st[1],
			st[2],
			parent
		)
		if isDecor then
			decor(p)
		end
		made += 1
		if made % 250 == 0 then
			task.wait()
		end
	end
	local open, prevJ = {}, nil
	for _, j in ipairs(G.keys(g.cells)) do
		local L = g.cells[j]
		local rects = {}
		local active, prevK = {}, nil
		for _, k in ipairs(G.keys(L)) do
			local R = L[k]
			local is = G.keys(R)
			local nextActive = {}
			local idx = 1
			while idx <= #is do
				local i0 = is[idx]
				local key = R[i0]
				local i1 = i0
				while idx < #is and is[idx + 1] == i1 + 1 and R[is[idx + 1]] == key do
					idx += 1
					i1 = is[idx]
				end
				idx += 1
				local rk = i0 .. ":" .. i1 .. ":" .. key
				local r = if mergeZ and prevK == k - 1 then active[rk] else nil
				if r then
					r.k1 = k
				else
					r = { i0 = i0, i1 = i1, k0 = k, k1 = k, key = key }
					table.insert(rects, r)
				end
				nextActive[rk] = r
			end
			active, prevK = nextActive, k
		end
		local nextOpen = {}
		for _, r in ipairs(rects) do
			local rk = r.i0 .. ":" .. r.i1 .. ":" .. r.k0 .. ":" .. r.k1 .. ":" .. r.key
			local o = if prevJ == j - 1 then open[rk] else nil
			if o then
				o.j1 = j
				nextOpen[rk] = o
			else
				r.j0, r.j1 = j, j
				nextOpen[rk] = r
			end
		end
		for rk, o in pairs(open) do
			if nextOpen[rk] ~= o then
				place(o)
			end
		end
		open, prevJ = nextOpen, j
	end
	for _, o in pairs(open) do
		place(o)
	end
	return made
end

local wood = G.new(4) -- the trunk, the root buttresses, the beams, limbs and branches (solid)
local deck = G.new(4) -- the summit deck, its hatch rim and the platforms (solid)
local twigs = G.new(4) -- thin twigs (decor)
local roots = G.new(4) -- the taproots under the island (decor)
local leaves = G.new(8) -- the crown (decor)

-- the spiral stair: segment s (0..127) of 11.25°, 8 a quarter turn: 2 landing segments, then 6 steps
local ST = {
	rIn = 8,
	rOut = 20.5,
	seg = 11.25 * RAD,
	a0 = 90 * RAD,
	n = 128,
	rise = SY / 96,
	clear = 18,
	wallTop = 33,
}
function ST.top(s)
	return (s // 8 * 6 + math.max(0, s % 8 - 1)) * ST.rise
end
function ST.angle(s)
	return ST.a0 + (s + 0.5) * ST.seg
end

-- the platforms (plank discs r 12, top y) and the rope bridges between them and the deck
local PLAT = {
	{ name = "WestPlatform", a = 210, r = 76, y = 136 },
	{ name = "NorthEastPlatform", a = 330, r = 76, y = 148 },
	{ name = "NorthPlatform", a = 255, r = 80, y = 124 },
}
local BRIDGES = {}
do
	for _, p in ipairs(PLAT) do
		p.x = snap(CX + p.r * math.cos(p.a * RAD))
		p.z = snap(CZ + p.r * math.sin(p.a * RAD))
	end
	for idx = 1, 2 do
		local p = PLAT[idx]
		local ax, az = CX + 41 * math.cos(p.a * RAD), CZ + 41 * math.sin(p.a * RAD)
		local dx, dz = p.x - ax, p.z - az
		local L = math.sqrt(dx * dx + dz * dz)
		table.insert(BRIDGES, {
			name = "Bridge" .. p.name,
			ax = ax,
			ay = SY,
			az = az,
			bx = p.x - dx / L * 9,
			by = p.y,
			bz = p.z - dz / L * 9,
			w = 12,
		})
	end
	local p1, p3 = PLAT[1], PLAT[3]
	local dx, dz = p3.x - p1.x, p3.z - p1.z
	local L = math.sqrt(dx * dx + dz * dz)
	table.insert(BRIDGES, {
		name = "BridgeWestNorth",
		ax = p1.x + dx / L * 9,
		ay = p1.y,
		az = p1.z + dz / L * 9,
		bx = p3.x - dx / L * 9,
		by = p3.y,
		bz = p3.z - dz / L * 9,
		w = 8,
	})
end
-- the big branches: leave the trunk at angle a (deg) and height y0, step out and up to a platform or a free tip
local BRANCH = {
	{ a = 214, y0 = 100, plat = PLAT[1] },
	{ a = 326, y0 = 112, plat = PLAT[2] },
	{ a = 262, y0 = 88, plat = PLAT[3] },
	{ a = 40, y0 = 92, r = 62, y1 = 110 }, -- the basket lift
	{ a = 125, y0 = 100, r = 58, y1 = 118 }, -- hanging lanterns and a birdhouse
}
local LIMBS = { 150, 230, 290 } -- the upper limbs from the deck into the crown roof
local TIPS = {} -- { x, y, z, r }: leaf cushions at twig ends

local H = {}
function H.adiff(a, b)
	return math.abs((a - b + 180) % 360 - 180)
end
-- the bark mix in patches: dark oak, oak (tinted), stripped wood, moss
function H.bark(x, y, z, mossAt)
	if math.noise(x * 0.07, y * 0.045, z * 0.07 + 41.7) > (mossAt or 0.42) then
		return "moss"
	end
	local n = math.noise(x * 0.045, y * 0.028, z * 0.045 + 7.3)
	if n > 0.34 then
		return "strip"
	elseif n > 0.06 then
		return "oak"
	end
	return "dark"
end
-- walkways a branch must not cross: the bridges, the platforms, the air over the deck
function H.walkBlocked(x, y, z)
	for _, b in ipairs(BRIDGES) do
		local dist, t = segDist(x, z, b.ax, b.az, b.bx, b.bz)
		local yb = b.ay + (b.by - b.ay) * t
		if dist < b.w / 2 + 3 and y > yb - 6 and y < yb + 10 then
			return true
		end
	end
	for _, p in ipairs(PLAT) do
		if (x - p.x) ^ 2 + (z - p.z) ^ 2 < 14 * 14 and y > p.y - 4 and y < p.y + 12 then
			return true
		end
	end
	return (x - CX) ^ 2 + (z - CZ) ^ 2 < 47 * 47 and y > SY - 4 and y < SY + 12
end
function H.branchKey(x, y, z)
	if H.walkBlocked(x, y, z) then
		return nil
	end
	return H.bark(x, y, z)
end
function H.deckKey(cx, cz, d)
	if d <= 20.5 then
		return if math.noise(cx * 0.11, cz * 0.11, 5.5) > 0.05 then "cob" else "msb"
	end
	if math.noise(cx * 0.07, cz * 0.07, 9.1) > 0.3 then
		return "dmoss"
	end
	return if math.noise(cx * 0.05, cz * 0.05, 2.2) > 0.1 then "spruce" else "plank"
end
-- the first wood cell along angle a (rad) at height y, marching r from rFrom to rTo
function H.surface(a, y, rFrom, rTo, step)
	local j = math.floor(y / 4)
	local ca, sa = math.cos(a), math.sin(a)
	for r = rFrom, rTo, step do
		if G.get(wood, math.floor((CX + r * ca) / 4), j, math.floor((CZ + r * sa) / 4)) then
			return r
		end
	end
	return nil
end
-- the bottom (dir -1) or top (dir 1) of the wood column through (x, y, z), nil if (x, y, z) is not in wood
function H.edgeY(x, y, z, dir)
	local i, j, k = math.floor(x / 4), math.floor(y / 4), math.floor(z / 4)
	if not G.get(wood, i, j, k) then
		return nil
	end
	while G.get(wood, i, j + dir, k) do
		j += dir
	end
	return if dir < 0 then j * 4 else (j + 1) * 4
end
-- a lantern (world pos, chain up to world y hangTop); lit = the kit lantern with its PointLight, else the same
-- iron frame with a glowing core and no light
function H.lamp(pos, parent, hangTop, isLit)
	if isLit then
		lit += 1
		return lantern(pos, parent, nil, hangTop)
	end
	local metal = Enum.Material.Metal
	decor(
		part(
			"Lantern",
			Vector3.new(1.3, 0.25, 1.3),
			CFrame.new(pos - Vector3.new(0, 0.62, 0)),
			IRON,
			metal,
			parent
		)
	)
	decor(
		part(
			"LanternTop",
			Vector3.new(1.3, 0.25, 1.3),
			CFrame.new(pos + Vector3.new(0, 0.62, 0)),
			IRON,
			metal,
			parent
		)
	)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		decor(
			part(
				"LanternBar",
				Vector3.new(0.2, 1, 0.2),
				CFrame.new(pos + Vector3.new(c[1] * 0.55, 0, c[2] * 0.55)),
				IRON,
				metal,
				parent
			)
		)
	end
	local core = decor(
		part(
			"LanternGlow",
			Vector3.new(0.9, 1, 0.9),
			CFrame.new(pos),
			LANTERN_GLOW,
			Enum.Material.Neon,
			parent
		)
	)
	core.Transparency = 0.1
	decor(
		part(
			"LanternCap",
			Vector3.new(0.7, 0.35, 0.7),
			CFrame.new(pos + Vector3.new(0, 0.9, 0)),
			Color3.fromRGB(40, 40, 45),
			metal,
			parent
		)
	)
	if hangTop and hangTop > pos.Y + 1 then
		decor(
			part(
				"Chain",
				Vector3.new(0.25, hangTop - pos.Y - 0.9, 0.25),
				CFrame.new(pos.X, (hangTop + pos.Y + 0.9) / 2, pos.Z),
				Color3.fromRGB(55, 55, 60),
				metal,
				parent
			)
		)
	end
	return core
end
-- a fence round an arc polygon (segs sides from angle a0, deg), skipping the sides a gap { a, half } (deg) meets
function H.fenceArc(cx, cz, r, y0, segs, a0, gaps, parent)
	for s = 0, segs - 1 do
		local a1, a2 = a0 + s * 360 / segs, a0 + (s + 1) * 360 / segs
		local skip = false
		for _, g in ipairs(gaps) do
			if H.adiff((a1 + a2) / 2, g.a) < 180 / segs + g.half then
				skip = true
			end
		end
		if not skip then
			fence(
				cx + r * math.cos(a1 * RAD),
				cz + r * math.sin(a1 * RAD),
				cx + r * math.cos(a2 * RAD),
				cz + r * math.sin(a2 * RAD),
				parent,
				y0
			)
		end
	end
end
-- a birdhouse: cf at its base centre, the hole facing -Z
function H.birdhouse(cf, parent)
	textured(
		decor(
			part("Birdhouse", Vector3.new(3, 3.4, 3), cf * CFrame.new(0, 1.7, 0), nil, nil, parent)
		),
		"px_spruce_planks"
	)
	textured(
		decor(
			part(
				"BirdhouseRoof",
				Vector3.new(4, 0.8, 4),
				cf * CFrame.new(0, 3.8, 0),
				nil,
				nil,
				parent
			)
		),
		"px_dark_oak_planks"
	)
	textured(
		decor(
			part(
				"BirdhouseRoof",
				Vector3.new(2.4, 0.8, 4),
				cf * CFrame.new(0, 4.6, 0),
				nil,
				nil,
				parent
			)
		),
		"px_dark_oak_planks"
	)
	decor(
		part(
			"BirdhouseHole",
			Vector3.new(1, 1, 0.2),
			cf * CFrame.new(0, 2.1, -1.55),
			Color3.fromRGB(25, 20, 15),
			nil,
			parent
		)
	)
	decor(
		part(
			"BirdhousePerch",
			Vector3.new(0.3, 0.3, 1),
			cf * CFrame.new(0, 1.2, -1.9),
			Color3.fromRGB(110, 80, 50),
			Enum.Material.Wood,
			parent
		)
	)
end
-- a bench: cf at its foot centre, the back toward +Z
function H.bench(cf, parent)
	textured(
		part("BenchSeat", Vector3.new(7, 0.6, 2.4), cf * CFrame.new(0, 1.9, 0), nil, nil, parent),
		"px_spruce_planks"
	)
	textured(
		part("BenchBack", Vector3.new(7, 1.6, 0.5), cf * CFrame.new(0, 3.2, 1.1), nil, nil, parent),
		"px_spruce_planks"
	)
	for _, sx in ipairs({ -3, 3 }) do
		textured(
			part(
				"BenchLeg",
				Vector3.new(0.8, 1.6, 2),
				cf * CFrame.new(sx, 0.8, 0),
				nil,
				nil,
				parent
			),
			"px_dark_oak_planks"
		)
	end
end
-- a small azalea bush (a hedge block with a flowering top)
function H.bush(cf, parent)
	textured(
		part("Azalea", Vector3.new(4, 4, 4), cf * CFrame.new(0, 2, 0), nil, nil, parent),
		"px_hedge",
		AZALEA
	)
	textured(
		decor(
			part(
				"AzaleaBloom",
				Vector3.new(2.6, 1.4, 2.6),
				cf * CFrame.new(0.4, 4.6, -0.3),
				nil,
				nil,
				parent
			)
		),
		"px_cherry_leaves",
		BLOSSOM
	)
end
-- a planter box 2 × 1 blocks (X along cf) with flowers or azalea bushes
function H.planter(cf, parent, bushy)
	textured(
		part("Planter", Vector3.new(8, 3, 4), cf * CFrame.new(0, 1.5, 0), nil, nil, parent),
		"px_spruce_planks"
	)
	textured(
		decor(
			part(
				"PlanterSoil",
				Vector3.new(7.2, 0.3, 3.2),
				cf * CFrame.new(0, 3.1, 0),
				nil,
				nil,
				parent
			)
		),
		"px_forest_floor"
	)
	if bushy then
		textured(
			part(
				"Azalea",
				Vector3.new(3.4, 3.4, 3.4),
				cf * CFrame.new(-1.9, 4.9, 0),
				nil,
				nil,
				parent
			),
			"px_hedge",
			AZALEA
		)
		textured(
			decor(
				part(
					"AzaleaBloom",
					Vector3.new(2.2, 1.2, 2.2),
					cf * CFrame.new(-1.7, 7.1, 0.2),
					nil,
					nil,
					parent
				)
			),
			"px_cherry_leaves",
			BLOSSOM
		)
		textured(
			part("Azalea", Vector3.new(3, 3, 3), cf * CFrame.new(2.1, 4.7, 0), nil, nil, parent),
			"px_hedge",
			OAK_LEAF
		)
	else
		local cols = {
			Color3.fromRGB(205, 50, 50),
			Color3.fromRGB(240, 200, 60),
			Color3.fromRGB(240, 240, 232),
			Color3.fromRGB(150, 90, 205),
		}
		for f = 1, 4 do
			local fz = if f % 2 == 0 then 0.7 else -0.7
			decor(
				part(
					"Flower",
					Vector3.new(0.9, 1.3, 0.9),
					cf * CFrame.new(-3 + (f - 1) * 2, 3.9, fz),
					cols[f],
					Enum.Material.SmoothPlastic,
					parent
				)
			)
		end
	end
end
-- a ruined arch of mossy stone at angle a (deg), radius r on the deck: two pillars 4 blocks apart across the
-- tangent, a lintel (or half of it and a fallen block)
function H.gate(a, r, hA, hB, broken, parent)
	local ca, sa = math.cos(a * RAD), math.sin(a * RAD)
	local c = V(CX + r * ca, SY, CZ + r * sa)
	local cf = CFrame.lookAt(c, c + Vector3.new(ca, 0, sa))
	for idx, side in ipairs({ -1, 1 }) do
		local h = if idx == 1 then hA else hB
		textured(
			part(
				"RuinBase",
				Vector3.new(5, 1, 5),
				cf * CFrame.new(side * 8, 0.5, 0),
				nil,
				nil,
				parent
			),
			"px_mossy_cobblestone"
		)
		pillarTag(
			textured(
				part(
					"RuinPillar",
					Vector3.new(4, h, 4),
					cf * CFrame.new(side * 8, h / 2, 0),
					nil,
					nil,
					parent
				),
				"px_mossy_stone_bricks"
			)
		)
		local vine = decor(
			part(
				"RuinVine",
				Vector3.new(1.4, h * 0.55, 0.3),
				cf * CFrame.new(side * 8 + 0.6, h * 0.7, -2.15),
				nil,
				nil,
				parent
			)
		)
		textured(vine, "px_hedge", MOSS)
	end
	if broken then
		textured(
			part(
				"RuinLintel",
				Vector3.new(12, 4, 4),
				cf * CFrame.new(-4, hA + 2, 0),
				nil,
				nil,
				parent
			),
			"px_mossy_cobblestone"
		)
		textured(
			part(
				"RuinRubble",
				Vector3.new(4, 4, 4),
				cf * CFrame.new(5, 2, -4) * CFrame.Angles(0, 0.4, 0),
				nil,
				nil,
				parent
			),
			"px_mossy_stone_bricks"
		)
	else
		textured(
			part(
				"RuinLintel",
				Vector3.new(20, 4, 4),
				cf * CFrame.new(0, hA + 2, 0),
				nil,
				nil,
				parent
			),
			"px_mossy_cobblestone"
		)
	end
end
-- a rope bridge from (ax, ay, az) to (bx, by, bz) (y = the plank tops at the ends): plank segments that sag a little,
-- fence posts every second segment with a wooden rail and a rope; no step higher than 2 studs
function H.bridge(b, parent)
	local f = folder(b.name, parent)
	local ax, ay, az, w = b.ax, b.ay, b.az, b.w
	local dx, dz = b.bx - ax, b.bz - az
	local L = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / L, dz / L
	local px, pz = -uz, ux
	local n = math.max(math.ceil(L / 4), math.ceil(math.abs(b.by - ay) / 1.3) + 2)
	local sag = math.min(2.5, L / 16)
	local function yAt(t)
		return ay + (b.by - ay) * t - sag * math.sin(math.pi * t) + 0.1
	end
	for i = 0, n - 1 do
		local t = (i + 0.5) / n
		local c = V(ax + dx * t, yAt(t) - 0.5, az + dz * t)
		local p = part(
			"BridgePlank",
			Vector3.new(w, 1, L / n + 0.2),
			CFrame.lookAt(c, c + Vector3.new(ux, 0, uz)),
			nil,
			nil,
			f
		)
		textured(p, if i % 2 == 0 then "px_spruce_planks" else "px_planks")
	end
	local idxs = {}
	for i = 0, n, 2 do
		table.insert(idxs, i)
	end
	if n % 2 == 1 then
		table.insert(idxs, n)
	end
	local rope = Color3.fromRGB(125, 98, 66)
	local prev = nil
	for m, i in ipairs(idxs) do
		local t = i / n
		local y = yAt(t)
		local posts = {}
		for _, side in ipairs({ -1, 1 }) do
			local x, z =
				ax + dx * t + px * side * (w / 2 - 0.5), az + dz * t + pz * side * (w / 2 - 0.5)
			textured(
				part("BridgePost", Vector3.new(1, 5.6, 1), at(x, y + 1.4, z), nil, nil, f),
				"px_dark_oak_planks"
			)
			posts[side] = V(x, y, z)
		end
		if prev then
			for _, side in ipairs({ -1, 1 }) do
				local p0, p1 = prev[side], posts[side]
				textured(
					beam(
						"BridgeRail",
						p0 + Vector3.new(0, 3.9, 0),
						p1 + Vector3.new(0, 3.9, 0),
						0.5,
						nil,
						f
					),
					"px_dark_oak_planks"
				)
				beam(
					"BridgeRope",
					p0 + Vector3.new(0, 2, 0),
					p1 + Vector3.new(0, 2, 0),
					0.3,
					rope,
					f,
					Enum.Material.Fabric
				)
			end
		end
		prev = posts
		if m == math.ceil(#idxs / 2) then
			H.lamp(posts[1] + Vector3.new(0, 4.95, 0), f, nil, false)
		end
	end
	return f
end

-- ================================================================ the trunk: bark rings, the column, the door, windows
do
	local FLARE = { 5, 3.5, 2, 1 }
	for j = 0, ST.wallTop do
		local y = j * 4 + 2
		local flare = FLARE[j + 1] or 0
		for k = -22, -4 do
			for i = -1, 18 do
				local cx, cz = i * 4 + 2, k * 4 + 2
				local dx, dz = cx - CX, cz - CZ
				local d = math.sqrt(dx * dx + dz * dz)
				if d <= 7 then
					G.set(wood, i, j, k, "strip") -- the stripped-wood column the stair winds round
				elseif d > ST.clear and d <= 36 then
					local a = math.atan2(dz, dx)
					local bump = math.noise(math.cos(a) * 1.7, math.sin(a) * 1.7, y * 0.022 + 3.1)
					local ro = 25 + math.max(0, bump + 0.45) * 2.6 + flare
					if d <= ro and not inRect(cx, cz, PATHS[2], 0) then
						G.set(wood, i, j, k, H.bark(cx, y, cz, if j < 6 then 0.26 else 0.42))
					end
				end
			end
		end
	end
	-- the door: a pointed arch, 4 blocks wide to y 20, 2 blocks to the tip at y 28, through the whole wall, framed
	-- by stripped logs on the outer two layers
	for j = 0, 8 do
		for k = -9, -5 do
			for i = 6, 11 do
				local cx, cz = i * 4 + 2, k * 4 + 2
				local open = (j <= 4 and cx > 28 and cx < 44) or (j <= 6 and cx > 32 and cx < 40)
				if open then
					G.set(wood, i, j, k, nil)
				elseif cz < -24 and cz > -32 then
					local frame = (j <= 6 and (cx == 26 or cx == 46))
						or ((j == 5 or j == 6) and (cx == 30 or cx == 42))
						or (j == 7 and cx > 28 and cx < 44)
						or (j == 8 and cx > 32 and cx < 40)
					if frame then
						G.set(wood, i, j, k, "strip")
					end
				end
			end
		end
	end
	-- windows every half turn of the stair: 2 blocks tall, the sill 10+ studs over the steps (no climbing out)
	for q = 1, 15, 2 do
		local s = q * 8 + 5
		local a = ST.angle(s)
		local sill = math.ceil((ST.top(s) + 10) / 4) * 4
		if sill + 8 <= ST.wallTop * 4 then
			local ca, sa = math.cos(a), math.sin(a)
			for r = 15, 36 do
				for off = -2.5, 2.5, 2.5 do
					local x, z = CX + r * ca - off * sa, CZ + r * sa + off * ca
					for j = sill / 4, sill / 4 + 1 do
						G.set(wood, math.floor(x / 4), j, math.floor(z / 4), nil)
					end
				end
			end
		end
	end
end

-- ================================================================ the root buttresses on the ground
do
	for _, a0 in ipairs({ 15, 40, 135, 165, 200, 240, 285, 330 }) do
		local rEnd = 50 + rng:NextInteger(0, 14)
		local wob = rng:NextNumber(0, 6)
		for r = 22, rEnd, 2 do
			local a = (a0 + 7 * math.sin(r / 11 + wob)) * RAD
			local x, z = CX + r * math.cos(a), CZ + r * math.sin(a)
			local w = if r < 30 then 3 elseif r < 44 then 2 else 1
			local h = if r < 28 then 3 elseif r < 46 then 2 else 1
			local i0 = math.floor((x - w * 2) / 4 + 0.5)
			local k0 = math.floor((z - w * 2) / 4 + 0.5)
			local ok = true
			for k = k0, k0 + w - 1 do
				for i = i0, i0 + w - 1 do
					local cx, cz = i * 4 + 2, k * 4 + 2
					if onPath(cx, cz, 2) or not isleOf(cx, cz, 6) or not inTreeZone(cx, cz, -6) then
						ok = false
					end
				end
			end
			if not ok then
				break
			end
			for k = k0, k0 + w - 1 do
				for i = i0, i0 + w - 1 do
					for j = 0, h - 1 do
						G.set(
							wood,
							i,
							j,
							k,
							H.bark(
								i * 4 + 2,
								j * 4 + 2,
								k * 4 + 2,
								if j == h - 1 then 0.22 else 0.42
							)
						)
					end
				end
			end
		end
	end
end

-- ================================================================ beams under the deck, the upper limbs, the branches
do
	local function barkFn(x, y, z)
		return H.bark(x, y, z)
	end
	local function pt(a, r, y)
		return { CX + r * math.cos(a * RAD), y, CZ + r * math.sin(a * RAD) }
	end
	-- 8 log beams 2 × 2 blocks radiate under the deck: up from the trunk, then flat to the rim
	for k = 0, 7 do
		local a = k * 45
		G.line(wood, pt(a, 20, 116), pt(a, 30, 132), 2, barkFn)
		G.line(wood, pt(a, 30, 132), pt(a, 44, 132), 2, barkFn)
	end
	-- the upper limbs rise from the trunk top through the deck into the crown roof
	for _, a in ipairs(LIMBS) do
		local p = { pt(a, 16, 144), pt(a, 24, 162), pt(a, 38, 180), pt(a, 50, 190) }
		for s = 1, 3 do
			G.line(wood, p[s], p[s + 1], 2, barkFn)
		end
		table.insert(TIPS, { p[4][1], p[4][2], p[4][3], 22 })
	end
	-- the big branches: 2 × 2 logs stepping out and up; a thin twig off each with a leaf cushion
	for _, b in ipairs(BRANCH) do
		local p1, p2 = pt(b.a, 20, b.y0), pt(b.a, 36, b.y0 + 12)
		local p3 = if b.plat then { b.plat.x, b.plat.y - 8, b.plat.z } else pt(b.a, b.r, b.y1)
		b.pts = { p1, p2, p3 }
		G.line(wood, p1, p2, 2, H.branchKey)
		G.line(wood, p2, p3, 2, H.branchKey)
		local tw = pt(b.a + 22, 54, b.y0 + 34)
		G.line(twigs, p2, tw, 1, H.branchKey)
		table.insert(TIPS, { tw[1], tw[2], tw[3], 15 })
		if not b.plat then
			local ca, sa = math.cos(b.a * RAD), math.sin(b.a * RAD)
			local te = { p3[1] + ca * 14, p3[2] + 10, p3[3] + sa * 14 }
			G.line(twigs, p3, te, 1, H.branchKey)
			table.insert(TIPS, { te[1], te[2], te[3], 18 })
		end
	end
end

-- ================================================================ the summit deck (top y 140), the hatch, the platforms
do
	local holes = {}
	local function angleDist(cx, cz)
		local dx, dz = cx - CX, cz - CZ
		return math.deg(math.atan2(dz, dx)), math.sqrt(dx * dx + dz * dz)
	end
	for k = -25, 0 do
		for i = -4, 21 do
			local cx, cz = i * 4 + 2, k * 4 + 2
			local a, d = angleDist(cx, cz)
			if d <= 46 + 1.5 * math.max(0, n2(cx, cz, 3.7, 0.08)) then
				-- the hatch over the last 135° of the stair (it comes up at the south, a = 90°)
				if d > 7 and d < 21.5 and a >= -45 and a < 90 then
					holes[i .. "," .. k] = true
				else
					G.set(deck, i, 34, k, H.deckKey(cx, cz, d))
				end
			end
		end
	end
	-- a stone rim one block high round the hatch, open where the stair comes out (a 75..135)
	for k = -25, 0 do
		for i = -4, 21 do
			local cx, cz = i * 4 + 2, k * 4 + 2
			local a, d = angleDist(cx, cz)
			if G.get(deck, i, 34, k) and d <= 25.5 and not (a >= 75 and a <= 135) then
				local near = false
				for dk = -1, 1 do
					for di = -1, 1 do
						if holes[(i + di) .. "," .. (k + dk)] then
							near = true
						end
					end
				end
				if near then
					G.set(deck, i, 35, k, if (i + k) % 3 == 0 then "cob" else "msb")
				end
			end
		end
	end
	-- the platforms: plank discs r 12, one block thick
	for _, p in ipairs(PLAT) do
		local j = p.y / 4 - 1
		for k = p.z / 4 - 4, p.z / 4 + 3 do
			for i = p.x / 4 - 4, p.x / 4 + 3 do
				local cx, cz = i * 4 + 2, k * 4 + 2
				if (cx - p.x) ^ 2 + (cz - p.z) ^ 2 <= 12.5 * 12.5 then
					local key = if n2(cx, cz, 6.6, 0.12) > 0.35
						then "dmoss"
						elseif k % 2 == 0 then "spruce"
						else "plank"
					G.set(deck, i, j, k, key)
				end
			end
		end
	end
	-- the limbs stand through the deck: no deck cell inside a wood cell
	for j, L in pairs(deck.cells) do
		for k, R in pairs(L) do
			for i in pairs(R) do
				if G.get(wood, i, j, k) then
					R[i] = nil
				end
			end
		end
	end
end

local woodN = G.emit(wood, "Bark", folder("Trunk", treeF), false, true)
task.wait()
local deckN = G.emit(deck, "Deck", folder("Decks", treeF), false, true)
G.emit(twigs, "Twig", folder("Twigs", treeF), true, false)
task.wait()

-- ================================================================ the spiral stair inside the trunk, the door
do
	local sf = folder("SpiralStair", treeF)
	local rMid = (ST.rIn + ST.rOut) / 2
	for s = 0, ST.n - 1 do
		local top = ST.top(s)
		if top > 0.5 then
			local a = ST.angle(s)
			local ca, sa = math.cos(a), math.sin(a)
			local tan = Vector3.new(-sa, 0, ca)
			local landing = s % 8 < 2
			-- two boxes across the width (inner, outer), each as long as the segment at its outer edge
			for half = 1, 2 do
				local r0 = if half == 1 then ST.rIn else rMid
				local r1 = if half == 1 then rMid else ST.rOut
				local rc = (r0 + r1) / 2
				local c = V(CX + rc * ca, top - 1.5, CZ + rc * sa)
				local size = Vector3.new(r1 - r0, 3, r1 * ST.seg * 1.06)
				local p = part(
					if landing then "StairLanding" else "StairStep",
					size,
					CFrame.lookAt(c, c + tan),
					nil,
					nil,
					sf
				)
				textured(p, if landing then "px_dark_oak_planks" else "px_spruce_planks")
			end
		end
	end
	-- a lantern on a bracket from the wall over every landing (every second one lit)
	for q = 0, 15 do
		local s = q * 8
		local a = ST.a0 + (s + 1) * ST.seg
		local y = ST.top(s) + 7
		local r = H.surface(a, y, 15, 26, 0.5)
		if r then
			local ca, sa = math.cos(a), math.sin(a)
			local arm = beam(
				"LampArm",
				V(CX + (r + 0.6) * ca, y + 1.7, CZ + (r + 0.6) * sa),
				V(CX + (r - 1.6) * ca, y + 1.7, CZ + (r - 1.6) * sa),
				0.7,
				nil,
				sf
			)
			textured(arm, "px_dark_oak_planks")
			H.lamp(V(CX + (r - 1.4) * ca, y, CZ + (r - 1.4) * sa), sf, BY + y + 1.4, q % 2 == 0)
		end
	end

	local df = folder("Door", treeF)
	box("DoorThreshold", 28, 0, -36, 44, 0.6, -24, "px_spruce_planks", nil, df)
	box("DoorStep", 26, 0, -24, 46, 0.45, -19, "px_planks", nil, df)
	box("DoorStep", 28, 0, -19, 44, 0.25, -14, "px_planks", nil, df)
	for _, x in ipairs({ 26, 46 }) do
		textured(
			part("DoorLampArm", Vector3.new(1, 1, 4), at(x, 15, -22.5), nil, nil, df),
			"px_dark_oak_planks"
		)
		H.lamp(V(x, 12.6, -21.2), df, BY + 14.5, true)
	end
end
task.wait()

-- ================================================================ the summit: fence, ruins, planters, lamps, benches
do
	local sf = folder("Summit", treeF)
	local function on(a, r)
		local ca, sa = math.cos(a * RAD), math.sin(a * RAD)
		local c = V(CX + r * ca, SY, CZ + r * sa)
		return CFrame.lookAt(c, c + Vector3.new(ca, 0, sa)) -- -Z outward, X along the tangent
	end
	H.fenceArc(CX, CZ, 42, SY, 24, 210, { { a = 210, half = 5 }, { a = 330, half = 5 } }, sf)
	-- the ring of ruined arches (the bridge exits pass through the two at 210° and 330°)
	for idx, a in ipairs({ 30, 90, 150, 210, 270, 330 }) do
		local broken = idx % 2 == 1
		H.gate(a, 31, 16, if broken then 8 else 16, broken, sf)
	end
	for idx, a in ipairs({ 0, 60, 120, 180, 240, 300 }) do
		H.planter(on(a, 34), sf, idx % 2 == 0)
		local ar = a * RAD
		lampPost(
			CX + 39.5 * math.cos(ar),
			CZ + 39.5 * math.sin(ar),
			sf,
			nil,
			math.atan2(math.cos(ar), math.sin(ar)),
			SY
		)
		lit += 1
	end
	-- benches by the fence looking out at the sky, behind the broken arches
	for _, a in ipairs({ 30, 150, 270 }) do
		H.bench(on(a, 40), sf)
	end
	for _, a in ipairs({ 140, 250, 300 }) do
		H.bush(on(a, 26), sf)
	end
	-- the banner signpost at the hatch exit
	do
		local cf = on(102, 25)
		textured(
			part("SignPole", Vector3.new(1, 11, 1), cf * CFrame.new(0, 5.5, 0), nil, nil, sf),
			"px_dark_oak_planks"
		)
		textured(
			part("SignArm", Vector3.new(5, 1, 1), cf * CFrame.new(2, 10.5, 0), nil, nil, sf),
			"px_dark_oak_planks"
		)
		banner(
			cf * CFrame.new(3, 6, 0),
			Color3.fromRGB(60, 132, 62),
			sf,
			Color3.fromRGB(236, 240, 226)
		)
		local board = textured(
			part("SignBoard", Vector3.new(6, 2, 0.4), cf * CFrame.new(-0.2, 4, -0.7), nil, nil, sf),
			"px_spruce_planks"
		)
		boardText(board, "Вершина")
	end
	-- lanterns on chains under the upper limbs, over the deck
	for _, a in ipairs(LIMBS) do
		local ca, sa = math.cos(a * RAD), math.sin(a * RAD)
		H.lamp(V(CX + 27 * ca, SY + 11, CZ + 27 * sa), sf, BY + SY + 21, true)
	end
end
task.wait()

-- ================================================================ the rope bridges, the platforms, life on the branches
do
	local bf = folder("Branches", treeF)
	for _, b in ipairs(BRIDGES) do
		H.bridge(b, bf)
	end
	for _, p in ipairs(PLAT) do
		local pf = folder(p.name, bf)
		local gaps = {}
		for _, b in ipairs(BRIDGES) do
			for _, e in ipairs({ { b.ax, b.az }, { b.bx, b.bz } }) do
				if (e[1] - p.x) ^ 2 + (e[2] - p.z) ^ 2 < 15 * 15 then
					local half = math.deg(math.asin(math.min(1, (b.w / 2 + 0.6) / 10.5)))
					table.insert(
						gaps,
						{ a = math.deg(math.atan2(e[2] - p.z, e[1] - p.x)), half = half }
					)
				end
			end
		end
		H.fenceArc(p.x, p.z, 10.5, p.y, 8, gaps[1].a, gaps, pf)
		-- props on the free side, away from the bridge gaps
		local spots = {}
		for _, off in ipairs({ 0, 60, -60, 100, -100, 140, -140 }) do
			local a = gaps[1].a + 180 + off
			local free = true
			for _, g in ipairs(gaps) do
				if H.adiff(a, g.a) < g.half + 32 then
					free = false
				end
			end
			if free then
				table.insert(spots, a * RAD)
			end
		end
		local function spot(n, r)
			local a = spots[n]
			if not a then
				return nil
			end
			return p.x + r * math.cos(a), p.z + r * math.sin(a), a
		end
		local x, z, a = spot(1, 6.5)
		if x then
			lampPost(x, z, pf, nil, math.atan2(-math.cos(a), -math.sin(a)), p.y)
			lit += 1
		end
		x, z, a = spot(2, 7)
		if x then
			-- a birdhouse on a post
			textured(
				part("BirdPost", Vector3.new(1, 6, 1), at(x, p.y + 3, z), nil, nil, pf),
				"px_dark_oak_planks"
			)
			H.birdhouse(at(x, p.y + 6, z) * CFrame.Angles(0, -a - math.pi / 2, 0), pf)
		end
		x, z, a = spot(3, 6.5)
		if x then
			if p.y == 148 then
				local c = V(x, p.y, z)
				H.bench(CFrame.lookAt(c, c + Vector3.new(math.cos(a), 0, math.sin(a))), pf)
			else
				barrel(x, p.y, z, pf)
				crate(x + math.cos(a + 1.6) * 4.2, p.y, z + math.sin(a + 1.6) * 4.2, pf, 3, a)
			end
		end
	end
	-- lanterns hanging on chains under the branches (the first of four branches lit)
	for idx, b in ipairs(BRANCH) do
		for n, f in ipairs({ 0.3, 0.82 }) do
			local p2, p3 = b.pts[2], b.pts[3]
			local x, y, z =
				p2[1] + (p3[1] - p2[1]) * f,
				p2[2] + (p3[2] - p2[2]) * f,
				p2[3] + (p3[3] - p2[3]) * f
			local bottom = H.edgeY(x, y, z, -1)
			if bottom then
				local drop = 5 + (idx + n) % 3 * 2
				H.lamp(V(x, bottom - drop, z), bf, BY + bottom + 0.5, n == 1 and idx ~= 3)
			end
		end
	end
	-- the basket lift: a plank basket on four chains under the south-east branch
	do
		local b = BRANCH[4]
		local p2, p3 = b.pts[2], b.pts[3]
		local x, y, z =
			p2[1] + (p3[1] - p2[1]) * 0.6,
			p2[2] + (p3[2] - p2[2]) * 0.6,
			p2[3] + (p3[3] - p2[3]) * 0.6
		local bottom = H.edgeY(x, y, z, -1)
		if bottom then
			local lf = folder("BasketLift", bf)
			local by = bottom - 24
			textured(
				decor(part("BasketFloor", Vector3.new(8, 0.6, 8), at(x, by + 0.3, z), nil, nil, lf)),
				"px_spruce_planks"
			)
			for _, w in ipairs({
				{ 0, -3.7, 8, 0.6 },
				{ 0, 3.7, 8, 0.6 },
				{ -3.7, 0, 0.6, 8 },
				{ 3.7, 0, 0.6, 8 },
			}) do
				textured(
					decor(
						part(
							"BasketWall",
							Vector3.new(w[3], 3.4, w[4]),
							at(x + w[1], by + 1.7, z + w[2]),
							nil,
							nil,
							lf
						)
					),
					"px_spruce_planks"
				)
			end
			decor(
				part(
					"BasketBand",
					Vector3.new(8.2, 0.4, 8.2),
					at(x, by + 3.2, z),
					Color3.fromRGB(70, 70, 75),
					Enum.Material.Metal,
					lf
				)
			)
			crate(x - 1.5, by + 0.6, z + 1, lf, 2.4, 0.3)
			local hook = V(x, bottom - 4, z)
			for _, c in ipairs({ { -3.6, -3.6 }, { 3.6, -3.6 }, { 3.6, 3.6 }, { -3.6, 3.6 } }) do
				decor(
					beam(
						"BasketChain",
						V(x + c[1], by + 3.4, z + c[2]),
						hook,
						0.25,
						Color3.fromRGB(55, 55, 60),
						lf,
						Enum.Material.Metal
					)
				)
			end
			decor(
				part(
					"BasketChain",
					Vector3.new(0.3, 4.4, 0.3),
					at(x, bottom - 1.8, z),
					Color3.fromRGB(55, 55, 60),
					Enum.Material.Metal,
					lf
				)
			)
			textured(
				decor(
					part(
						"BasketPulley",
						Vector3.new(1.4, 1.4, 1.4),
						at(x, bottom - 4, z),
						nil,
						nil,
						lf
					)
				),
				"px_dark_oak_planks"
			)
		end
	end
	-- a birdhouse on top of the south-west branch
	do
		local b = BRANCH[5]
		local p2, p3 = b.pts[2], b.pts[3]
		local x, y, z = (p2[1] + p3[1]) / 2, (p2[2] + p3[2]) / 2, (p2[3] + p3[3]) / 2
		local top = H.edgeY(x, y, z, 1)
		if top then
			H.birdhouse(at(x, top, z) * CFrame.Angles(0, -b.a * RAD - math.pi / 2, 0), bf)
		end
	end
end
task.wait()

-- ================================================================ on the bark: vines, bracket mushrooms, birdhouses
do
	local bk = folder("BarkLife", treeF)
	local vineTint = Color3.fromRGB(150, 196, 112) -- px_hedge is dark already: a light tint
	for _ = 1, 46 do
		local a = rng:NextNumber(0, 360)
		local y = rng:NextInteger(3, 33) * 4
		if not (H.adiff(a, 90) < 26 and y < 40) then
			local ar = a * RAD
			local r = H.surface(ar, y - 0.5, 40, 14, -1)
			if r then
				local len = rng:NextInteger(2, 6) * 2
				local out = Vector3.new(math.cos(ar), 0, math.sin(ar))
				local p = V(CX + (r + 0.9) * out.X, y - len / 2, CZ + (r + 0.9) * out.Z)
				local v = decor(
					part(
						"Vine",
						Vector3.new(1.2, len, 0.3),
						CFrame.lookAt(p, p + out),
						nil,
						nil,
						bk
					)
				)
				textured(v, "px_hedge", vineTint)
			end
		end
	end
	local red = Color3.fromRGB(196, 44, 38)
	local spotC = Color3.fromRGB(245, 242, 235)
	for _ = 1, 9 do
		local a = rng:NextNumber(0, 360)
		local y = rng:NextInteger(3, 30) * 4
		if H.adiff(a, 90) < 30 and y < 40 then
			a += 70
		end
		for _ = 1, rng:NextInteger(3, 5) do
			local am = (a + rng:NextNumber(-10, 10)) * RAD
			local ym = y + rng:NextInteger(-2, 3) * 3
			local r = H.surface(am, ym, 40, 14, -1)
			if r then
				local s = pick({ 3, 4, 4, 5 })
				local out = Vector3.new(math.cos(am), 0, math.sin(am))
				local c =
					V(CX + (r + 0.6 + s * 0.35) * out.X, ym, CZ + (r + 0.6 + s * 0.35) * out.Z)
				local cf = CFrame.lookAt(c, c + out)
				textured(
					decor(part("BracketMushroom", Vector3.new(s, 0.9, s * 0.8), cf, nil, nil, bk)),
					"px_white_wool",
					red
				)
				for _ = 1, 2 do
					local sp = cf
						* CFrame.new(
							rng:NextNumber(-s / 3, s / 3),
							0.5,
							rng:NextNumber(-s * 0.3, s * 0.2)
						)
					decor(
						part(
							"MushroomSpot",
							Vector3.new(0.7, 0.2, 0.7),
							sp,
							spotC,
							Enum.Material.SmoothPlastic,
							bk
						)
					)
				end
			end
		end
	end
	for _, h in ipairs({ { 150, 46 }, { 20, 74 }, { 280, 58 } }) do
		local ar = h[1] * RAD
		local r = H.surface(ar, h[2] - 1, 40, 14, -1)
		if r then
			local out = Vector3.new(math.cos(ar), 0, math.sin(ar))
			local a0 = V(CX + (r - 0.5) * out.X, h[2] - 0.5, CZ + (r - 0.5) * out.Z)
			local a1 = V(CX + (r + 3.2) * out.X, h[2] - 0.5, CZ + (r + 3.2) * out.Z)
			textured(beam("BirdArm", a0, a1, 1, nil, bk), "px_dark_oak_planks")
			local c = V(CX + (r + 2.6) * out.X, h[2], CZ + (r + 2.6) * out.Z)
			H.birdhouse(CFrame.lookAt(c, c + out), bk)
		end
	end
end
task.wait()

-- ================================================================ the crown: leaf cushions in patches
local leafN = 0
do
	local lf = folder("Crown", treeF)
	local function free(x, y, z)
		local d2 = (x - CX) ^ 2 + (z - CZ) ^ 2
		if y < 120 or d2 > 88 * 88 then
			return false -- the crown stays within y 120..200, r 88
		end
		if d2 < 50 * 50 and y < 154 then
			return false -- the air over the deck (and the trunk below it)
		end
		for _, p in ipairs(PLAT) do
			if (x - p.x) ^ 2 + (z - p.z) ^ 2 < 20 * 20 and y > p.y - 10 and y < p.y + 20 then
				return false
			end
		end
		for _, b in ipairs(BRIDGES) do
			local dist, t = segDist(x, z, b.ax, b.az, b.bx, b.bz)
			local yb = b.ay + (b.by - b.ay) * t
			if dist < b.w / 2 + 8 and y > yb - 10 and y < yb + 18 then
				return false
			end
		end
		return true
	end
	local function key(x, y, z)
		local n = math.noise(x * 0.018, y * 0.03, z * 0.018 + 21.3)
		if n > 0.17 then
			return "bloL"
		elseif n < -0.12 then
			return "azaL"
		end
		return "oakL"
	end
	local function blob(cx, cy, cz, rx, ry, rz)
		for j = math.floor((cy - ry) / 8), math.floor((cy + ry) / 8) do
			for k = math.floor((cz - rz) / 8), math.floor((cz + rz) / 8) do
				for i = math.floor((cx - rx) / 8), math.floor((cx + rx) / 8) do
					local x, y, z = i * 8 + 4, j * 8 + 4, k * 8 + 4
					local e = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 + ((z - cz) / rz) ^ 2
					if
						e <= 1 + 0.4 * math.noise(x * 0.06, y * 0.06, z * 0.06 + 13.7)
						and free(x, y, z)
					then
						G.set(leaves, i, j, k, key(x, y, z))
					end
				end
			end
		end
	end
	-- the roof over the summit, held by the three limbs
	blob(CX, 178, CZ, 44, 13, 44)
	for k = 0, 3 do
		local a = (45 + 90 * k + rng:NextNumber(-15, 15)) * RAD
		blob(
			CX + 40 * math.cos(a),
			168 + rng:NextInteger(0, 2) * 4,
			CZ + 40 * math.sin(a),
			26,
			11,
			26
		)
	end
	for _, t in ipairs(TIPS) do
		blob(t[1], t[2] + 4, t[3], t[4], 9, t[4])
	end
	-- the ragged ring of cushions round the summit
	for k = 0, 15 do
		local a = (k * 360 / 16 + rng:NextNumber(-8, 8)) * RAD
		local r = rng:NextNumber(52, 62)
		local rx = rng:NextNumber(16, 22)
		blob(
			CX + r * math.cos(a),
			rng:NextNumber(134, 164),
			CZ + r * math.sin(a),
			rx,
			rng:NextNumber(9, 13),
			rx * rng:NextNumber(0.8, 1.2)
		)
	end
	-- the outer fringe, the upper ring under the roof, low clumps under the ring and tufts on top
	for k = 0, 9 do
		local a = (k * 36 + 18 + rng:NextNumber(-10, 10)) * RAD
		local r = rng:NextNumber(66, 74)
		blob(
			CX + r * math.cos(a),
			rng:NextNumber(138, 158),
			CZ + r * math.sin(a),
			rng:NextNumber(12, 16),
			8,
			rng:NextNumber(12, 16)
		)
	end
	for k = 0, 7 do
		local a = (k * 45 + rng:NextNumber(-12, 12)) * RAD
		local r = rng:NextNumber(30, 48)
		local rx = rng:NextNumber(18, 24)
		blob(CX + r * math.cos(a), rng:NextNumber(176, 188), CZ + r * math.sin(a), rx, 9, rx)
	end
	for _ = 0, 5 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(50, 62)
		blob(
			CX + r * math.cos(a),
			rng:NextNumber(128, 134),
			CZ + r * math.sin(a),
			rng:NextNumber(12, 16),
			7,
			rng:NextNumber(12, 16)
		)
	end
	for _ = 0, 4 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(0, 30)
		blob(CX + r * math.cos(a), rng:NextNumber(192, 198), CZ + r * math.sin(a), 14, 6, 14)
	end
	-- leaf and vine strips hanging from the bottom of the leaf masses
	local cand = {}
	for _, j in ipairs(G.keys(leaves.cells)) do
		local L = leaves.cells[j]
		for _, k in ipairs(G.keys(L)) do
			for _, i in ipairs(G.keys(L[k])) do
				if not G.get(leaves, i, j - 1, k) then
					table.insert(cand, { i, j, k, L[k][i] })
				end
			end
		end
	end
	for _ = 1, math.min(80, #cand) do
		local c = cand[rng:NextInteger(1, #cand)]
		local x = c[1] * 8 + rng:NextInteger(0, 1) * 4 + 2
		local z = c[3] * 8 + rng:NextInteger(0, 1) * 4 + 2
		local top = c[2] * 8
		local len = rng:NextInteger(1, 4) * 4
		if (x - CX) ^ 2 + (z - CZ) ^ 2 < 50 * 50 then
			len = math.min(len, top - 154)
		end
		if len >= 4 and free(x, top - len, z) then
			local st = STYLE[c[4]]
			local size = if rng:NextNumber() < 0.5
				then Vector3.new(4, len, 0.6)
				else Vector3.new(0.6, len, 4)
			textured(
				decor(part("LeafStrip", size, at(x, top - len / 2, z), nil, nil, lf)),
				st[1],
				st[2]
			)
		end
	end
	leafN = G.emit(leaves, "Leaves", lf, true, true)
end
task.wait()

-- ================================================================ the taproots under the central island
do
	local rf = folder("Taproots", treeF)
	-- the bottom of the island column under (x, z): the core's rockDepth (8-stud cells, 16-stud steps)
	local function bottom(x, z)
		local cx, cz = math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4
		local rr =
			math.clamp(math.sqrt((cx - CENTRAL.x) ^ 2 + (cz - CENTRAL.z) ^ 2) / CENTRAL.r, 0, 1)
		local d = math.max(8, math.floor((12 + (1 - rr) ^ 1.25 * 150) / 16 + 0.5) * 16)
		return -4 - d
	end
	local function rootKey(x, y, z)
		return if math.noise(x * 0.05, y * 0.03, z * 0.05 + 3.3) > 0.1 then "oak" else "root"
	end
	for n = 1, 9 do
		local a = (n * 40 + rng:NextNumber(-12, 12)) * RAD
		local r0 = rng:NextNumber(6, 30)
		local px, pz = CX + r0 * math.cos(a), CZ + r0 * math.sin(a)
		local py = bottom(px, pz) + 8
		local len = rng:NextInteger(30, 38) * 4
		local steps = math.ceil((len + 8) / 12)
		for s = 1, steps do
			local f = s / steps
			local out = rng:NextNumber(0.5, 3.5)
			local nx = px + math.cos(a) * out + rng:NextNumber(-2, 2)
			local nz = pz + math.sin(a) * out + rng:NextNumber(-2, 2)
			local ny = py - 12
			if f <= 0.4 then
				G.line(roots, { px, py, pz }, { nx, ny, nz }, 2, rootKey)
			elseif f <= 0.72 then
				G.line(roots, { px, py, pz }, { nx, ny, nz }, 1, rootKey)
			else
				local th = 1 - (f - 0.72) * 1.4
				textured(
					decor(beam("RootTip", V(px, py, pz), V(nx, ny, nz), th, nil, rf)),
					"px_dark_oak_log",
					BARK_DARK
				)
			end
			px, py, pz = nx, ny, nz
		end
	end
	-- thin hanging roots from the bottom of the island round the trunk
	for _ = 1, 30 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(4, 46)
		local x, z = CX + r * math.cos(a), CZ + r * math.sin(a)
		if isleOf(x, z, 6) then
			local top = bottom(x, z) + 1
			local len = rng:NextInteger(3, 10) * 4
			textured(
				decor(
					part(
						"HangingRoot",
						Vector3.new(0.7, len, 0.7),
						at(x, top - len / 2, z),
						nil,
						nil,
						rf
					)
				),
				"px_dark_oak_log",
				BARK_DARK
			)
		end
	end
	G.emit(roots, "Taproot", rf, true, false)
end

print(
	("[build-tree] the tree: %d parts (bark %d, decks %d, leaves %d), %d lights"):format(
		count - c0,
		woodN,
		deckN,
		leafN,
		lit
	)
)
