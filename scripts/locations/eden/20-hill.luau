--!nocheck
-- ================================================================ eden: the HILL part (d < 100 from (0, -60))
-- The ring bridges (pink cherry planks), the hill stairs (S1, S2, west, east), the Tree of Life with its buttress
-- roots, branches, the pink crown, hanging vines / wisteria and the serpent, the summit plaza with the tiered
-- fountain, L1 (leaf arches, ruins, cherry and apple trees, flower beds, the giant mushroom meadow, the gazebo) and
-- the bank (reeds, lily pads, a dock). Every height step is measured from the 8-stud cells 10-core built.
local hillF = folder("Hill")
local HX, HZ = HILL.x, HILL.z
local c0 = count

-- the ground height of the 8-stud cell holding (x, z), exactly as 10-core built it
local function cellY(x, z)
	local cx = math.floor((x + 232) / 8) * 8 - 232 + 4
	local cz = math.floor((z + 232) / 8) * 8 - 232 + 4
	return groundY(cx, cz)
end
-- true when the rectangle (x ± hx, z ± hz) stands on cells of height y
local function fits(x, z, hx, hz, y)
	for _, c in ipairs({ { 0, 0 }, { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		if cellY(x + c[1] * hx, z + c[2] * hz) ~= y then
			return false
		end
	end
	return true
end
-- a point on a circle round the hill centre; angle in degrees (0 east, 90 south)
local function polar(a, r)
	local t = math.rad(a)
	return HX + r * math.cos(t), HZ + r * math.sin(t)
end
-- a block relative to a frame (decor when asked)
local function rel(parent, cf, name, sx, sy, sz, ox, oy, oz, variant, tint, isDecor)
	local p = part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	if isDecor then
		decor(p)
	end
	return p
end

-- a Minecraft lantern (world position); only `lit` ones get a PointLight, at most 25 in the hill part
local LIT = { n = 0, max = 25 }
local function lamp(pos, parent, hangTop, lit)
	local iron = Color3.fromRGB(45, 45, 50)
	local m = Enum.Material.Metal
	decor(
		part(
			"Lantern",
			Vector3.new(1.3, 0.25, 1.3),
			CFrame.new(pos - Vector3.new(0, 0.62, 0)),
			iron,
			m,
			parent
		)
	)
	decor(
		part(
			"LanternTop",
			Vector3.new(1.3, 0.25, 1.3),
			CFrame.new(pos + Vector3.new(0, 0.62, 0)),
			iron,
			m,
			parent
		)
	)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local o = Vector3.new(c[1] * 0.55, 0, c[2] * 0.55)
		decor(part("LanternBar", Vector3.new(0.2, 1, 0.2), CFrame.new(pos + o), iron, m, parent))
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
			iron,
			m,
			parent
		)
	)
	if hangTop and hangTop > pos.Y + 1 then
		local len = hangTop - pos.Y - 0.9
		decor(
			part(
				"Chain",
				Vector3.new(0.25, len, 0.25),
				CFrame.new(pos.X, pos.Y + 0.9 + len / 2, pos.Z),
				iron,
				m,
				parent
			)
		)
	end
	if lit and LIT.n < LIT.max then
		LIT.n += 1
		light(core, 30, 1.2, LANTERN_GLOW)
	end
end

local FLOWERS = {
	Color3.fromRGB(235, 60, 60), -- red
	Color3.fromRGB(250, 215, 60), -- yellow
	Color3.fromRGB(248, 248, 240), -- white
	Color3.fromRGB(245, 150, 200), -- pink
	Color3.fromRGB(170, 110, 225), -- purple
	Color3.fromRGB(95, 145, 235), -- blue
	Color3.fromRGB(245, 150, 50), -- orange
}
-- a small flower head (decor), standing on y
local function bloom(x, y, z, color, parent, s)
	s = s or 1.3
	return decor(cube("Flower", x, y + s / 2, z, s, s, s, "px_white_wool", color, parent))
end
-- thin flush slabs over 4-stud cells: one box per run along x where flag(cx, cz) holds
local function slabRuns(x0, x1, z0, z1, y0, y1, flag, name, variant, tint, parent)
	for z = z0, z1 - 4, 4 do
		local start
		for x = x0, x1, 4 do
			local on = x < x1 and flag(x + 2, z + 2)
			if on and not start then
				start = x
			elseif not on and start then
				local p = decor(box(name, start, y0, z, x, y1, z + 4, variant, tint, parent))
				p.CastShadow = false
				start = nil
			end
		end
	end
end

-- a sparse voxel grid merged greedily (x, then z, then y) into boxes: the trunk, the branches and the crown
local G = {}
do
	local OFF, SPAN = 512, 1024
	local function key(i, j, k)
		return ((j + OFF) * SPAN + (k + OFF)) * SPAN + (i + OFF)
	end
	function G.new(c)
		return { c = c, cells = {} }
	end
	function G.set(g, i, j, k, v)
		g.cells[key(i, j, k)] = v
	end
	function G.get(g, i, j, k)
		return g.cells[key(i, j, k)]
	end
	-- kinds[v] = { name, variant, tint, decor, shadow }; returns the number of boxes
	function G.emit(g, kinds, parent)
		local cells, c = g.cells, g.c
		local keys = {}
		for kk in pairs(cells) do
			table.insert(keys, kk)
		end
		table.sort(keys)
		local done = {}
		local n = 0
		for _, k0 in ipairs(keys) do
			if not done[k0] then
				local v = cells[k0]
				local i = k0 % SPAN - OFF
				local rest = math.floor(k0 / SPAN)
				local k = rest % SPAN - OFF
				local j = math.floor(rest / SPAN) - OFF
				local function free(kk)
					return cells[kk] == v and not done[kk]
				end
				local i1 = i
				while free(key(i1 + 1, j, k)) do
					i1 += 1
				end
				local k1 = k
				while true do
					local ok = true
					for ii = i, i1 do
						if not free(key(ii, j, k1 + 1)) then
							ok = false
							break
						end
					end
					if not ok then
						break
					end
					k1 += 1
				end
				local j1 = j
				while true do
					local ok = true
					for kz = k, k1 do
						for ii = i, i1 do
							if not free(key(ii, j1 + 1, kz)) then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
					end
					if not ok then
						break
					end
					j1 += 1
				end
				for jj = j, j1 do
					for kz = k, k1 do
						for ii = i, i1 do
							done[key(ii, jj, kz)] = true
						end
					end
				end
				local kind = kinds[v]
				local p = box(
					kind.name,
					i * c,
					j * c,
					k * c,
					(i1 + 1) * c,
					(j1 + 1) * c,
					(k1 + 1) * c,
					kind.variant,
					kind.tint,
					parent
				)
				if kind.decor then
					decor(p)
				end
				if kind.shadow == false then
					p.CastShadow = false
				end
				n += 1
				if n % 250 == 0 then
					task.wait()
				end
			end
		end
		return n
	end
end

-- ================================================================ 1. the ring bridges (measured from the river cells)
do
	local bf0 = folder("Bridges", hillF)
	-- the z extent of the river cells under the deck footprint
	local function riverSpan(x0, x1, z0, z1)
		local a, b = math.huge, -math.huge
		for x = x0 + 1, x1 - 1, 2 do
			for z = z0, z1 do
				if cellY(x, z) == RIVER_BED then
					local lo = math.floor((z + 232) / 8) * 8 - 232
					a = math.min(a, lo)
					b = math.max(b, lo + 8)
				end
			end
		end
		return a, b
	end
	-- a deck running along z: flat landings on both banks (top y 0.1), a stepped hump (0.6 a step) over the water,
	-- cherry rails from railA to railB, tall end posts with lanterns (litA / litB: lit at that end)
	local function bridge(name, x0, x1, z0, z1, railA, railB, litA, litB)
		local bf = folder(name, bf0)
		local rz0, rz1 = riverSpan(x0, x1, z0, z1)
		rz0, rz1 = math.max(rz0, z0 + 2), math.min(rz1, z1 - 2)
		local segs = { { z0, rz0 } }
		local n = math.max(1, math.floor((rz1 - rz0) / 4 + 0.5))
		for s = 1, n do
			table.insert(segs, { rz0 + (s - 1) * (rz1 - rz0) / n, rz0 + s * (rz1 - rz0) / n })
		end
		table.insert(segs, { rz1, z1 })
		local m = #segs
		for idx, s in ipairs(segs) do
			s.top = 0.1 + 0.6 * math.min(idx - 1, m - idx, 3)
			box("Deck", x0, s.top - 1, s[1], x1, s.top, s[2], "px_cherry_planks", nil, bf)
			if idx > 1 and idx < m then
				box(
					"DeckBeam",
					x0 - 0.4,
					s.top - 2.4,
					s[1],
					x0 + 1.2,
					s.top - 0.6,
					s[2],
					"px_cherry_log",
					nil,
					bf
				)
				box(
					"DeckBeam",
					x1 - 1.2,
					s.top - 2.4,
					s[1],
					x1 + 0.4,
					s.top - 0.6,
					s[2],
					"px_cherry_log",
					nil,
					bf
				)
			end
		end
		local function topAt(z)
			local t = 0.1
			for _, s in ipairs(segs) do
				if z >= s[1] - 0.01 and z <= s[2] + 0.01 then
					t = math.max(t, s.top)
				end
			end
			return t
		end
		-- stone piers at the water's edges
		for _, zz in ipairs({ rz0, rz1 }) do
			for _, xx in ipairs({ x0 + 2, x1 - 2 }) do
				box(
					"Pier",
					xx - 2,
					RIVER_BED,
					zz - 2,
					xx + 2,
					topAt(zz) - 1,
					zz + 2,
					"px_mossy_stone_bricks",
					nil,
					bf
				)
			end
		end
		-- rails: two cherry rails per segment (stepping with the deck), posts every ~4 studs
		for _, xx in ipairs({ x0 + 0.6, x1 - 0.6 }) do
			for _, s in ipairs(segs) do
				local a, b = math.max(s[1], railA), math.min(s[2], railB)
				if b - a > 0.5 then
					for _, h in ipairs({ 1.3, 2.7 }) do
						box(
							"Rail",
							xx - 0.25,
							s.top + h - 0.3,
							a,
							xx + 0.25,
							s.top + h + 0.3,
							b,
							"px_cherry_planks",
							nil,
							bf
						)
					end
				end
			end
			local np = math.max(1, math.floor((railB - railA) / 4 + 0.5))
			for q = 0, np do
				local z = railA + (railB - railA) * q / np
				local base = topAt(z)
				local endPost = q == 0 or q == np
				local h = if endPost then 5 else 3.4
				local w = if endPost then 1.4 else 1
				box(
					"RailPost",
					xx - w / 2,
					base,
					z - w / 2,
					xx + w / 2,
					base + h,
					z + w / 2,
					"px_cherry_log",
					nil,
					bf
				)
				if endPost then
					lamp(
						V(xx, base + h + 0.75, z),
						bf,
						nil,
						(q == 0 and litA) or (q == np and litB)
					)
				end
			end
		end
		return rz0, rz1
	end
	local a, b = bridge(
		"BridgeSouth",
		BRIDGE_S[1],
		BRIDGE_S[3],
		BRIDGE_S[2],
		BRIDGE_S[4],
		22,
		BRIDGE_S[4],
		false,
		true
	)
	print(("[build-eden] hill: south bridge over the river z %d..%d"):format(a, b))
	-- the north-west and north-east crossings where the ring runs diagonally: rectangular decks along z
	a, b = bridge("BridgeNW", -70, -58, -140, -100, -140, -100, true, false)
	print(("[build-eden] hill: NW bridge over the river z %d..%d"):format(a, b))
	bridge("BridgeNE", 58, 70, -140, -100, -140, -100, true, false)
end
task.wait()

-- ================================================================ 2. the hill stairs (placed where the cells step)
do
	local sf = folder("Stairs", hillF)
	local STEP, CHEEK = "px_stone_bricks", "px_mossy_stone_bricks"
	-- the first cell boundary where the ground reaches `level`, walking from `from` toward `to` along an axis
	local function edge(ax, fixed, from, to, level)
		local dir = if to > from then 1 else -1
		for t = from, to, dir do
			local y = if ax == "z" then cellY(fixed, t) else cellY(t, fixed)
			if y and y >= level then
				local lo = math.floor((t + 232) / 8) * 8 - 232
				return if dir > 0 then lo else lo + 8
			end
		end
		return to
	end
	local e1 = edge("z", 0, 40, -40, 8) -- S1: the L1 edge south of the hill
	local e2 = edge("z", 0, e1 - 2, -60, 16) -- S2: the summit edge
	local eW = edge("x", HZ, -110, -30, 8)
	local eE = edge("x", HZ, 110, 30, 8)
	print(
		("[build-eden] hill: stairs edges S1 z %d, S2 z %d, W x %d, E x %d"):format(e1, e2, eW, eE)
	)
	local function pot(x, y, z)
		decor(cube("FlowerPot", x, y + 0.6, z, 1.6, 1.2, 1.6, "px_terracotta", nil, sf))
		decor(cube("PotLeaves", x, y + 1.6, z, 1.4, 0.8, 1.4, "px_hedge", LEAF, sf))
		bloom(x, y + 2, z, pick(FLOWERS), sf, 1)
	end
	-- a stepped cheek wall beside a flight: `ax` is the axis the flight runs along, c0..c1 the wall's cross span
	local function cheek(ax, c0, c1, a0, a1, y0, rise, base, litBottom, litTop)
		local run = math.abs(a1 - a0)
		local dir = if a1 > a0 then 1 else -1
		local nseg = math.max(1, math.floor(run / 4 + 0.5))
		local seg = run / nseg
		local cc = (c0 + c1) / 2
		for q = 0, nseg - 1 do
			local top = math.ceil((y0 + rise * (q + 1) / nseg + 2) / 2) * 2
			local s0, s1 = a0 + dir * q * seg, a0 + dir * (q + 1) * seg
			local lo, hi = math.min(s0, s1), math.max(s0, s1)
			local mid = (s0 + s1) / 2
			if ax == "z" then
				box("CheekWall", c0, base, lo, c1, top, hi, CHEEK, nil, sf)
			else
				box("CheekWall", lo, base, c0, hi, top, c1, CHEEK, nil, sf)
			end
			local px, pz = if ax == "z" then cc else mid, if ax == "z" then mid else cc
			if q == 0 or q == nseg - 1 then
				-- a lantern on the end blocks of the wall
				local lx, lz = px, pz
				local lit = (q == 0 and litBottom) or (q == nseg - 1 and litTop)
				lamp(V(lx, top + 0.75, lz), sf, nil, lit)
			else
				pot(px, top, pz)
			end
		end
	end
	-- S1: from the bridge landing up onto L1 (20 wide like the bridge)
	stairs("S1", 0, e1 + 12, e1, 0, 8, 20, STEP, sf)
	cheek("z", 10, 14, e1 + 12, e1, 0, 8, -1, true, false)
	cheek("z", -14, -10, e1 + 12, e1, 0, 8, -1, true, false)
	-- S2: from L1 onto the summit (16 wide)
	stairs("S2", 0, e2 + 12, e2, 8, 8, 16, STEP, sf)
	cheek("z", 8, 12, e2 + 12, e2, 8, 8, 7, false, true)
	cheek("z", -12, -8, e2 + 12, e2, 8, 8, 7, false, true)
	-- the side stairs from the bank onto L1, running along x (the bank is one cell wide here)
	stairs("StairsW", HZ, eW - 10, eW, 0, 8, 16, STEP, sf, "x")
	box("StairFooting", eW - 10, RIVER_BED, HZ - 8, eW - 6, -2.4, HZ + 8, CHEEK, nil, sf)
	cheek("x", HZ - 12, HZ - 8, eW - 10, eW, 0, 8, RIVER_BED, true, false)
	cheek("x", HZ + 8, HZ + 12, eW - 10, eW, 0, 8, RIVER_BED, false, false)
	stairs("StairsE", HZ, eE + 10, eE, 0, 8, 16, STEP, sf, "x")
	box("StairFooting", eE + 6, RIVER_BED, HZ - 8, eE + 10, -2.4, HZ + 8, CHEEK, nil, sf)
	cheek("x", HZ - 12, HZ - 8, eE + 10, eE, 0, 8, RIVER_BED, true, false)
	cheek("x", HZ + 8, HZ + 12, eE + 10, eE, 0, 8, RIVER_BED, false, false)
	-- coarse dirt paths: S1 top → S2 foot, the side stairs' tops → the L1 ring path
	local DIRT = "px_dirt"
	decor(box("Path", -8, 8, e2 + 12, 8, 8.1, e1, DIRT, PATH, sf)).CastShadow = false
	decor(box("Path", eW, 8, HZ - 6, eW + 18, 8.1, HZ + 6, DIRT, PATH, sf)).CastShadow = false
	decor(box("Path", eE - 18, 8, HZ - 6, eE, 8.1, HZ + 6, DIRT, PATH, sf)).CastShadow = false
end
task.wait()

-- ================================================================ 3. the Tree of Life, its crown, vines and the serpent
do
	local tf = folder("TreeOfLife", hillF)
	local function trunkR(y)
		if y < 20 then
			return 13.5
		elseif y < 28 then
			return 12.5
		end
		return 12 - 3 * math.clamp((y - 28) / 52, 0, 1)
	end
	local tg = G.new(4)
	local function bark(x, y, z)
		return if math.noise(x * 0.07, y * 0.045, z * 0.07 + 3.3) > 0.28 then "cherry" else "dark"
	end
	-- the trunk: stepped rings of 4-stud blocks, y 16..80, a little uneven
	for j = 4, 19 do
		local yc = j * 4 + 2
		for k = -15 - 5, -15 + 4 do
			for i = -5, 4 do
				local x, z = i * 4 + 2, k * 4 + 2
				local dx, dz = x - HX, z - HZ
				local d = math.sqrt(dx * dx + dz * dz)
				local r = trunkR(yc) + 1.6 * math.noise(math.atan2(dz, dx) * 1.3, yc * 0.035, 7.7)
				if d <= r then
					G.set(tg, i, j, k, if d > r - 4 then bark(x, yc, z) else "dark")
				end
			end
		end
	end
	-- buttress roots: 1–2 blocks high, none toward the south (the S2 landing, the fountain, the plaza)
	for _, a in ipairs({ 0, 35, 145, 180, 215, 250, 290, 325 }) do
		local len = rng:NextNumber(20, 24.5)
		local ux, uz = math.cos(math.rad(a)), math.sin(math.rad(a))
		for k = -15 - 8, -15 + 7 do
			for i = -8, 7 do
				local dx, dz = i * 4 + 2 - HX, k * 4 + 2 - HZ
				local along = dx * ux + dz * uz
				local perp = math.abs(-dx * uz + dz * ux)
				if along > 8 and along <= len and perp < 3 then
					if not G.get(tg, i, 4, k) then
						G.set(tg, i, 4, k, "root")
					end
					if along <= len - 7 and not G.get(tg, i, 5, k) then
						G.set(tg, i, 5, k, "root")
					end
				end
			end
		end
	end
	-- the branches: stepped log beams out and up into the crown
	local function limb(p0, p1, r0, r1)
		local len = (p1 - p0).Magnitude
		for t = 0, len, 1.5 do
			local p = p0:Lerp(p1, t / len)
			local rr = r0 + (r1 - r0) * t / len
			for j = math.floor((p.Y - rr) / 4), math.floor((p.Y + rr) / 4) do
				for k = math.floor((p.Z - rr) / 4), math.floor((p.Z + rr) / 4) do
					for i = math.floor((p.X - rr) / 4), math.floor((p.X + rr) / 4) do
						local cx, cy, cz = i * 4 + 2, j * 4 + 2, k * 4 + 2
						if
							(cx - p.X) ^ 2 + (cy - p.Y) ^ 2 + (cz - p.Z) ^ 2 <= rr * rr
							and not G.get(tg, i, j, k)
						then
							G.set(tg, i, j, k, bark(cx, cy, cz))
						end
					end
				end
			end
		end
	end
	local function P(a, r, y)
		local x, z = polar(a, r)
		return Vector3.new(x, y, z)
	end
	-- { angle, base y, mid r, mid y, tip r, tip y, thickness }; the serpent's head rests on the first
	local BR = {
		{ 60, 54, 30, 66, 60, 82, 6.5 },
		{ 105, 68, 32, 78, 64, 92, 6 },
		{ 150, 62, 30, 72, 62, 86, 6.5 },
		{ 195, 66, 34, 76, 66, 90, 6 },
		{ 240, 63, 30, 72, 60, 86, 6.5 },
		{ 285, 70, 34, 80, 66, 96, 6 },
		{ 330, 66, 30, 76, 62, 90, 6 },
		{ 15, 68, 32, 80, 64, 94, 6 },
	}
	local tips = {}
	for _, b in ipairs(BR) do
		local p0, p1, p2 = P(b[1], 4, b[2]), P(b[1] + 8, b[3], b[4]), P(b[1] + 14, b[5], b[6])
		limb(p0, p1, b[7], b[7] * 0.75)
		limb(p1, p2, b[7] * 0.75, 3)
		table.insert(tips, p2)
	end
	for _, a in ipairs({ 30, 150, 270 }) do
		limb(P(a, 4, 72), P(a + 10, 22, 104), 6, 3.5)
	end
	-- the top of the first branch where the serpent's head lies
	local SER_A = BR[1][1]
	local hx, hz = polar(SER_A, 19)
	local headTop = 66
	do
		local hi, hk = math.floor(hx / 4), math.floor(hz / 4)
		for j = 30, 10, -1 do
			if G.get(tg, hi, j, hk) then
				headTop = j * 4 + 4
				break
			end
		end
	end
	local tn = G.emit(tg, {
		dark = { name = "Trunk", variant = "px_dark_oak_log" },
		cherry = { name = "Bark", variant = "px_cherry_log" },
		root = { name = "Root", variant = "px_dark_oak_log" },
	}, tf)
	task.wait()

	-- the crown: 8-stud leaf cells in patches of cherry blossom, pink wool and a little green, y 72..~120, r ≤ 80
	local crownF = folder("Crown", tf)
	local cg = G.new(8)
	local function leafKey(x, y, z)
		if math.noise(x * 0.035, y * 0.05, z * 0.035 + 17.7) > 0.3 then
			return "hedge"
		elseif math.noise(x * 0.04, y * 0.05, z * 0.04 + 5.1) < -0.12 then
			return "wool"
		end
		return "blossom"
	end
	local function blob(cx, cy, cz, rx, ry, rz)
		for j = math.max(9, math.floor((cy - ry) / 8)), math.floor((cy + ry) / 8) do
			for k = math.floor((cz - rz) / 8), math.floor((cz + rz) / 8) do
				for i = math.floor((cx - rx) / 8), math.floor((cx + rx) / 8) do
					local x, y, z = i * 8 + 4, j * 8 + 4, k * 8 + 4
					local e = ((x - cx) / rx) ^ 2 + ((y - cy) / ry) ^ 2 + ((z - cz) / rz) ^ 2
					if
						e <= 1 + 0.4 * math.noise(x * 0.07, y * 0.07, z * 0.07 + 9.1)
						and (x - HX) ^ 2 + (z - HZ) ^ 2 <= 80 * 80
					then
						G.set(cg, i, j, k, leafKey(x, y, z))
					end
				end
			end
		end
	end
	blob(HX, 100, HZ, 48, 13, 48) -- the dome
	for k = 0, 8 do -- the ring of cushions
		local x, z = polar(k * 40 + rng:NextNumber(-10, 10), rng:NextNumber(36, 48))
		local rx = rng:NextNumber(18, 23)
		blob(
			x,
			rng:NextNumber(88, 98),
			z,
			rx,
			rng:NextNumber(10, 13),
			rx * rng:NextNumber(0.85, 1.15)
		)
	end
	for _, t in ipairs(tips) do -- over every branch tip
		blob(t.X, t.Y + 5, t.Z, 15, 9, 15)
	end
	for k = 0, 11 do -- the ragged outer fringe
		local x, z = polar(k * 30 + 15 + rng:NextNumber(-8, 8), rng:NextNumber(62, 70))
		blob(x, rng:NextNumber(78, 90), z, rng:NextNumber(10, 14), 7, rng:NextNumber(10, 14))
	end
	for _ = 1, 6 do -- tufts on top
		local x, z = polar(rng:NextNumber(0, 360), rng:NextNumber(0, 34))
		blob(x, rng:NextNumber(108, 114), z, rng:NextNumber(10, 14), 7, rng:NextNumber(10, 14))
	end
	local KINDS = {
		blossom = {
			name = "Blossom",
			variant = "px_cherry_leaves",
			tint = BLOSSOM,
			decor = true,
			shadow = false,
		},
		wool = {
			name = "PinkWool",
			variant = "px_white_wool",
			tint = PINK_WOOL,
			decor = true,
			shadow = false,
		},
		hedge = { name = "Leaves", variant = "px_hedge", tint = LEAF, decor = true }, -- the green patches cast the shade
	}
	local cn = G.emit(cg, KINDS, crownF)
	task.wait()

	-- the columns of the crown: 4-stud tufts on top and drips below (a ragged silhouette), vines and wisteria
	local vf = folder("Vines", tf)
	local KEYS = { "blossom", "blossom", "wool", "hedge" }
	local vines, vineLit = 0, 0
	for k = -18, 2 do
		for i = -10, 10 do
			local jb, jt
			for j = 9, 16 do
				if G.get(cg, i, j, k) then
					jb = jb or j
					jt = j
				end
			end
			if jb then
				local x, z = i * 8 + 4, k * 8 + 4
				local d = math.sqrt((x - HX) ^ 2 + (z - HZ) ^ 2)
				if rng:NextNumber() < 0.3 then
					local kd = KINDS[pick(KEYS)]
					local ox, oz = rng:NextInteger(0, 1) * 4 - 2, rng:NextInteger(0, 1) * 4 - 2
					local p = cube(
						"Tuft",
						x + ox,
						(jt + 1) * 8 + 2,
						z + oz,
						4,
						4,
						4,
						kd.variant,
						kd.tint,
						crownF
					)
					decor(p).CastShadow = false
				end
				if rng:NextNumber() < 0.2 then
					local kd = KINDS[pick(KEYS)]
					local ox, oz = rng:NextInteger(0, 1) * 4 - 2, rng:NextInteger(0, 1) * 4 - 2
					local p = cube(
						"Drip",
						x + ox,
						jb * 8 - 2,
						z + oz,
						4,
						4,
						4,
						kd.variant,
						kd.tint,
						crownF
					)
					decor(p).CastShadow = false
				end
				if d > 15 and rng:NextNumber() < 0.3 then
					local L = rng:NextInteger(2, 8) * 4
					local sx, sz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
					local top = jb * 8
					local roll = rng:NextNumber()
					local p
					if roll < 0.45 then
						p = cube(
							"Wisteria",
							sx,
							top - L / 2,
							sz,
							2,
							L,
							2,
							"px_wisteria_leaves",
							nil,
							vf
						)
					elseif roll < 0.85 then
						p = cube("Vine", sx, top - L / 2, sz, 1.2, L, 1.2, "px_hedge", LEAF, vf)
						vines += 1
						if vines % 6 == 0 then
							local lit = d < 36 and vineLit < 2
							if lit then
								vineLit += 1
							end
							lamp(V(sx, top - L - 1.2, sz), vf, nil, lit)
						end
					else
						L = math.min(L, 16)
						p = cube(
							"BlossomStrand",
							sx,
							top - L / 2,
							sz,
							2,
							L,
							2,
							"px_cherry_leaves",
							BLOSSOM,
							vf
						)
					end
					decor(p).CastShadow = false
				end
			end
		end
		if k % 4 == 0 then
			task.wait()
		end
	end

	-- the serpent: a blocky green snake coiled twice round the trunk (y 20 → 60), its head on the first branch
	local snake = folder("Serpent", tf)
	local BODY = Color3.fromRGB(150, 200, 120)
	local BELLY = Color3.fromRGB(90, 160, 70)
	local SPOT = Color3.fromRGB(95, 140, 75)
	local aEnd = math.rad(SER_A - 28)
	local aStart = aEnd - 4 * math.pi
	local pts = {}
	local N = 56
	for s = 0, N do
		local t = s / N
		local a = aStart + (aEnd - aStart) * t
		local y = 20 + 40 * t
		local R = trunkR(y) + 4.4
		table.insert(pts, Vector3.new(HX + R * math.cos(a), y, HZ + R * math.sin(a)))
	end
	-- the neck climbs onto the branch
	local nx, nz = polar(SER_A - 10, 15.5)
	table.insert(pts, Vector3.new(nx, (60 + headTop) / 2 + 1, nz))
	local headPos = Vector3.new(hx, headTop + 2, hz)
	table.insert(pts, headPos)
	for s = 1, #pts - 1 do
		local p, q = pts[s], pts[s + 1]
		local len = (q - p).Magnitude
		local cf = CFrame.lookAt(V(0, 0, 0) + (p + q) / 2, V(0, 0, 0) + q)
		local w = if s > #pts - 3 then 4 else 4.6 -- the neck is a little slimmer
		rel(snake, cf, "SerpentBody", w, 4.2, len + 1.2, 0, 0, 0, "px_hedge", BODY, true)
		rel(
			snake,
			cf,
			"SerpentBelly",
			w + 0.2,
			0.8,
			len + 1.2,
			0,
			-1.9,
			0,
			"px_white_wool",
			BELLY,
			true
		)
		if s % 3 == 0 then
			rel(snake, cf, "SerpentSpot", 2.4, 0.5, 2.4, 0, 2.2, 0, "px_hedge", SPOT, true)
		end
	end
	do
		local out = Vector3.new(math.cos(math.rad(SER_A)), 0, math.sin(math.rad(SER_A)))
		local wp = V(0, 0, 0) + headPos
		local cf = CFrame.lookAt(wp, wp + out)
		rel(snake, cf, "SerpentHead", 5.4, 3.6, 6, 0, 0, -1.5, "px_hedge", BODY, true)
		rel(snake, cf, "SerpentSnout", 4.2, 2.6, 3, 0, -0.4, -5.6, "px_hedge", BODY, true)
		rel(snake, cf, "SerpentJaw", 4.4, 0.8, 7.4, 0, -1.9, -3.2, "px_white_wool", BELLY, true)
		rel(snake, cf, "SerpentBrow", 5.6, 0.6, 4, 0, 2, -1.5, "px_hedge", SPOT, true)
		for _, sx in ipairs({ -1, 1 }) do
			rel(
				snake,
				cf,
				"SerpentEye",
				0.6,
				1.3,
				1.3,
				sx * 2.75,
				0.8,
				-3,
				nil,
				Color3.fromRGB(250, 215, 60),
				true
			)
			rel(
				snake,
				cf,
				"SerpentPupil",
				0.3,
				1,
				0.5,
				sx * 3.1,
				0.8,
				-3,
				nil,
				Color3.fromRGB(20, 20, 20),
				true
			)
		end
		local red = Color3.fromRGB(205, 30, 40)
		rel(snake, cf, "SerpentTongue", 0.5, 0.25, 3, 0, -1.2, -8.4, nil, red, true)
		for _, sx in ipairs({ -1, 1 }) do
			local fork = cf * CFrame.new(sx * 0.4, -1.2, -10.3) * CFrame.Angles(0, sx * 0.45, 0)
			decor(part("SerpentFork", Vector3.new(0.35, 0.25, 1.4), fork, red, nil, snake))
		end
	end
	print(("[build-eden] hill: tree boxes %d, crown boxes %d, vines %d"):format(tn, cn, vines))
end
task.wait()

-- ================================================================ 4. the summit plaza: coarse dirt and petals, the fountain
do
	local pf = folder("Summit", hillF)
	local Y = 16
	local FX, FZ = 0, -38
	local SB, MS = "px_stone_bricks", "px_mossy_stone_bricks"
	local function plaza(cx, cz)
		local d = math.sqrt((cx - HX) ^ 2 + (cz - HZ) ^ 2)
		return cellY(cx, cz) == Y
			and d > 11
			and d < 37
			and (cz > HZ - 4 or d < 22)
			and not (math.abs(cx - FX) < 6 and math.abs(cz - FZ) < 6)
	end
	slabRuns(-40, 40, -100, -20, Y, Y + 0.1, plaza, "PlazaDirt", "px_dirt", PATH, pf)
	slabRuns(-40, 40, -100, -20, Y + 0.1, Y + 0.18, function(cx, cz)
		return plaza(cx, cz) and math.noise(cx * 0.08, cz * 0.08, 4.4) > 0.25
	end, "Petals", "px_white_wool", PINK_WOOL, pf)
	task.wait()

	-- the tiered fountain of mossy stone bricks (water: no collision)
	local ff = folder("Fountain", pf)
	local function water(x0, y0, z0, x1, y1, z1)
		local w = decor(box("FountainWater", x0, y0, z0, x1, y1, z1, "px_water", WATER, ff))
		w.Transparency = 0.25
		w.CastShadow = false
		return w
	end
	box("BasinFloor", FX - 6, Y, FZ - 6, FX + 6, Y + 0.3, FZ + 6, SB, nil, ff)
	box("BasinRim", FX - 6, Y, FZ - 6, FX + 6, Y + 2.5, FZ - 4, MS, nil, ff)
	box("BasinRim", FX - 6, Y, FZ + 4, FX + 6, Y + 2.5, FZ + 6, MS, nil, ff)
	box("BasinRim", FX - 6, Y, FZ - 4, FX - 4, Y + 2.5, FZ + 4, MS, nil, ff)
	box("BasinRim", FX + 4, Y, FZ - 4, FX + 6, Y + 2.5, FZ + 4, MS, nil, ff)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local x, z = FX + c[1] * 5, FZ + c[2] * 5
		box("RimCap", x - 1, Y + 2.5, z - 1, x + 1, Y + 3.5, z + 1, SB, nil, ff)
	end
	water(FX - 4, Y + 0.3, FZ - 4, FX + 4, Y + 2.1, FZ + 4)
	box("FountainColumn", FX - 1.5, Y + 0.3, FZ - 1.5, FX + 1.5, Y + 11, FZ + 1.5, MS, nil, ff)
	-- the middle basin
	box("MidBasin", FX - 4, Y + 5.5, FZ - 4, FX + 4, Y + 6.5, FZ + 4, SB, nil, ff)
	box("MidRim", FX - 4, Y + 6.5, FZ - 4, FX + 4, Y + 7.6, FZ - 3.2, MS, nil, ff)
	box("MidRim", FX - 4, Y + 6.5, FZ + 3.2, FX + 4, Y + 7.6, FZ + 4, MS, nil, ff)
	box("MidRim", FX - 4, Y + 6.5, FZ - 3.2, FX - 3.2, Y + 7.6, FZ + 3.2, MS, nil, ff)
	box("MidRim", FX + 3.2, Y + 6.5, FZ - 3.2, FX + 4, Y + 7.6, FZ + 3.2, MS, nil, ff)
	water(FX - 3.2, Y + 6.5, FZ - 3.2, FX + 3.2, Y + 7.3, FZ + 3.2)
	-- falls from under the middle basin's lip into the lower one
	water(FX - 3, Y + 2.1, FZ - 4, FX + 3, Y + 5.5, FZ - 3.6)
	water(FX - 3, Y + 2.1, FZ + 3.6, FX + 3, Y + 5.5, FZ + 4)
	water(FX - 4, Y + 2.1, FZ - 3, FX - 3.6, Y + 5.5, FZ + 3)
	water(FX + 3.6, Y + 2.1, FZ - 3, FX + 4, Y + 5.5, FZ + 3)
	-- the top bowl, the spout and its small falls
	box("TopBowl", FX - 2.2, Y + 11, FZ - 2.2, FX + 2.2, Y + 12, FZ + 2.2, SB, nil, ff)
	water(FX - 0.8, Y + 12, FZ - 0.8, FX + 0.8, Y + 14.5, FZ + 0.8)
	water(FX - 0.8, Y + 7.3, FZ - 2.6, FX + 0.8, Y + 12.2, FZ - 2.3)
	water(FX - 0.8, Y + 7.3, FZ + 2.3, FX + 0.8, Y + 12.2, FZ + 2.6)
	water(FX - 2.6, Y + 7.3, FZ - 0.8, FX - 2.3, Y + 12.2, FZ + 0.8)
	water(FX + 2.3, Y + 7.3, FZ - 0.8, FX + 2.6, Y + 12.2, FZ + 0.8)

	-- stone-brick planters with flowers and a lantern
	local function planter(x, z, lit)
		box("Planter", x - 4, Y, z - 4, x + 4, Y + 3, z + 4, SB, nil, pf)
		decor(
			box(
				"PlanterSoil",
				x - 3.4,
				Y + 3,
				z - 3.4,
				x + 3.4,
				Y + 3.3,
				z + 3.4,
				"px_dirt",
				MUD,
				pf
			)
		)
		decor(box("PlanterBush", x - 3, Y + 3.3, z - 3, x + 1, Y + 5, z + 3, "px_hedge", LEAF, pf))
		for q = 1, 6 do
			bloom(
				x - 2.6 + (q - 1) % 3 * 1.6,
				Y + 5,
				z - 2 + math.floor((q - 1) / 3) * 3.2,
				pick(FLOWERS),
				pf,
				1.1
			)
		end
		box(
			"PlanterPost",
			x + 1.8,
			Y + 3.3,
			z - 0.6,
			x + 3,
			Y + 7.5,
			z + 0.6,
			"px_dark_oak_log",
			nil,
			pf
		)
		lamp(V(x + 2.4, Y + 8.3, z), pf, nil, lit)
	end
	local function bench(x, z, alongX)
		local hx, hz = if alongX then 4 else 1.3, if alongX then 1.3 else 4
		box(
			"BenchSeat",
			x - hx,
			Y + 1.6,
			z - hz,
			x + hx,
			Y + 2.2,
			z + hz,
			"px_dark_oak_planks",
			nil,
			pf
		)
		for _, s in ipairs({ -1, 1 }) do
			local lx, lz =
				if alongX then x + s * (hx - 0.8) else x, if alongX then z else z + s * (hz - 0.8)
			box("BenchLeg", lx - 0.8, Y, lz - 0.8, lx + 0.8, Y + 1.6, lz + 0.8, SB, nil, pf)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		local px, pz = s * 19, -36
		if fits(px, pz, 4, 4, Y) then
			planter(px, pz, true)
		end
		local qx, qz = polar(if s > 0 then 15 else 165, 31)
		qx, qz = math.floor(qx + 0.5), math.floor(qz + 0.5)
		if not fits(qx, qz, 4, 4, Y) then
			qx, qz = polar(if s > 0 then 15 else 165, 28)
		end
		planter(qx, qz, true)
		bench(s * 26, -44, false)
	end

	-- kneeling deer and a rabbit near the tree (decor)
	local FUR = Color3.fromRGB(240, 215, 190)
	local function deer(x, z, yaw)
		local cf = at(x, Y, z) * CFrame.Angles(0, yaw, 0)
		local f = folder("Deer", pf)
		rel(f, cf, "DeerBody", 3.6, 2.6, 6.4, 0, 1.3, 0, "px_brown_wool", FUR, true)
		for _, s in ipairs({ -1, 1 }) do
			rel(f, cf, "DeerLeg", 1, 0.8, 2.4, s * 1.3, 0.4, -3.8, "px_brown_wool", FUR, true)
			rel(f, cf, "DeerEar", 1.1, 0.6, 0.4, s * 1.5, 6.2, -3.4, "px_brown_wool", FUR, true)
			rel(
				f,
				cf,
				"DeerAntler",
				0.4,
				2.6,
				0.4,
				s * 0.7,
				7.6,
				-3.4,
				nil,
				Color3.fromRGB(120, 90, 60),
				true
			)
			rel(
				f,
				cf,
				"DeerTine",
				1.6,
				0.4,
				0.4,
				s * 1.3,
				8.2,
				-3.4,
				nil,
				Color3.fromRGB(120, 90, 60),
				true
			)
		end
		rel(f, cf, "DeerNeck", 1.6, 3, 1.6, 0, 3.4, -2.6, "px_brown_wool", FUR, true)
		rel(f, cf, "DeerHead", 2, 2, 3, 0, 5.2, -3.6, "px_brown_wool", FUR, true)
		rel(f, cf, "DeerMuzzle", 1.4, 1.2, 1, 0, 4.8, -5.4, nil, Color3.fromRGB(60, 45, 35), true)
		rel(f, cf, "DeerChest", 1.8, 1.6, 0.4, 0, 2.6, -3.3, "px_white_wool", nil, true)
		rel(f, cf, "DeerTail", 1, 1, 0.6, 0, 2.2, 3.4, "px_white_wool", nil, true)
	end
	local dx, dz = polar(200, 30)
	deer(dx, dz, math.rad(-30))
	dx, dz = polar(340, 30)
	deer(dx, dz, math.rad(200))
	do
		local rx, rz = polar(268, 30)
		local cf = at(rx, Y, rz) * CFrame.Angles(0, math.rad(40), 0)
		local f = folder("Rabbit", pf)
		rel(f, cf, "RabbitBody", 1.8, 1.6, 2.6, 0, 0.8, 0, "px_white_wool", nil, true)
		rel(f, cf, "RabbitHead", 1.4, 1.4, 1.4, 0, 1.8, -1.4, "px_white_wool", nil, true)
		for _, s in ipairs({ -1, 1 }) do
			rel(f, cf, "RabbitEar", 0.4, 1.4, 0.3, s * 0.4, 3.1, -1.4, "px_white_wool", nil, true)
		end
		rel(
			f,
			cf,
			"RabbitNose",
			0.4,
			0.3,
			0.2,
			0,
			1.8,
			-2.15,
			nil,
			Color3.fromRGB(240, 140, 160),
			true
		)
	end
end
task.wait()

-- ================================================================ 5. L1: the ring path, leaf arches, ruins, trees, beds,
-- the mushroom meadow, the gazebo; flowers at the foot of the summit wall
do
	local lf = folder("Gardens", hillF)
	local Y = 8
	-- a free spot on the L1 ring (outside the 4-block walkway r 42..58), trying a few radii
	local function onL1(a, hx, hz)
		for _, r in ipairs({ 65, 63, 61, 67, 59 }) do
			local x, z = polar(a, r)
			x, z = math.floor(x + 0.5), math.floor(z + 0.5)
			if fits(x, z, hx, hz, Y) then
				return x, z
			end
		end
		return nil
	end
	-- the ring path of coarse dirt (r 47..55) with petal patches
	local function ring(cx, cz)
		local d = math.sqrt((cx - HX) ^ 2 + (cz - HZ) ^ 2)
		return d >= 47 and d <= 55 and cellY(cx, cz) == Y and not (math.abs(cx) < 8 and cz > -14)
	end
	slabRuns(-72, 72, -132, 12, Y, Y + 0.1, ring, "RingPath", "px_dirt", PATH, lf)
	slabRuns(-72, 72, -132, 12, Y + 0.1, Y + 0.18, function(cx, cz)
		return ring(cx, cz) and math.noise(cx * 0.09, cz * 0.09, 6.6) > 0.32
	end, "Petals", "px_white_wool", PINK_WOOL, lf)
	task.wait()

	-- leaf arches with flowers, wisteria and lanterns over the paths
	local function leafArch(cx, y0, cz, alongX, span, h, lit)
		local af = folder("LeafArch", lf)
		local cf = at(cx, y0, cz)
			* (if alongX then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0))
		local px = span / 2 + 2
		for _, s in ipairs({ -1, 1 }) do
			rel(af, cf, "ArchBase", 4, 4, 4, s * px, 2, 0, "px_mossy_stone_bricks")
			rel(af, cf, "ArchPillar", 4, h - 4, 4, s * px, 4 + (h - 4) / 2, 0, "px_hedge", LEAF)
			rel(af, cf, "ArchCorner", 4, 4, 4, s * (px - 4), h - 2, 0, "px_hedge", LEAF)
		end
		rel(af, cf, "ArchBeam", span + 8, 4, 4, 0, h + 2, 0, "px_hedge", LEAF)
		rel(af, cf, "ArchCrown", span - 4, 4, 4.4, 0, h + 6, 0, "px_cherry_leaves", BLOSSOM, true)
		rel(
			af,
			cf,
			"ArchCrownTop",
			span - 12,
			2,
			3.6,
			0,
			h + 9,
			0,
			"px_white_wool",
			PINK_WOOL,
			true
		)
		for f = 1, 16 do
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			local ox, oy
			if f <= 9 then
				ox, oy = rng:NextNumber(-span / 2 - 3, span / 2 + 3), h + rng:NextNumber(0.6, 3.4)
			else
				ox, oy =
					(if rng:NextNumber() < 0.5 then -px else px) + rng:NextNumber(-1.4, 1.4),
					rng:NextNumber(5, h - 1)
			end
			rel(
				af,
				cf,
				"ArchFlower",
				1.4,
				1.4,
				0.8,
				ox,
				oy,
				side * 2.2,
				"px_white_wool",
				pick(FLOWERS),
				true
			)
		end
		for _, ox in ipairs({ -span / 2 + 1.5, -span / 6, span / 6, span / 2 - 1.5 }) do
			local L = rng:NextInteger(3, 7)
			local o = rng:NextNumber(-1, 1)
			rel(
				af,
				cf,
				"Wisteria",
				1.6,
				L,
				1.6,
				ox + o,
				h - L / 2,
				o * 1.2,
				"px_wisteria_leaves",
				nil,
				true
			)
		end
		for i, s in ipairs({ -1, 1 }) do
			local p = (cf * CFrame.new(s * span / 4, h - 3.2, 0)).Position
			lamp(p, af, p.Y + 3.2, lit and i == 1)
		end
	end
	leafArch(0, Y, 2, true, 24, 16, true) -- over the top of S1
	leafArch(0, 16, -28, true, 24, 14, true) -- over the top of S2 (the summit entrance)
	leafArch(-66, Y, HZ, false, 24, 16, true) -- over the top of the west stairs
	leafArch(66, Y, HZ, false, 24, 16, true) -- over the top of the east stairs
	leafArch(0, Y, -112, false, 24, 16, true) -- over the ring path in the north
	task.wait()

	-- mossy stone arch ruins
	local function ruin(cx, cz, alongX)
		local rf = folder("ArchRuin", lf)
		local cf = at(cx, Y, cz)
			* (if alongX then CFrame.identity else CFrame.Angles(0, math.pi / 2, 0))
		rel(rf, cf, "RuinPillar", 4, 16, 4, -6, 8, 0, "px_mossy_stone_bricks")
		rel(rf, cf, "RuinPillarTop", 4, 4, 4, -6, 18, 0, "px_mossy_cobblestone")
		rel(rf, cf, "RuinPillar", 4, 8, 4, 6, 4, 0, "px_mossy_stone_bricks")
		rel(rf, cf, "RuinPillarTop", 4, 2, 4, 6, 9, 0, "px_mossy_cobblestone")
		rel(rf, cf, "RuinLintel", 8, 4, 4, -2, 14, 0, "px_mossy_stone_bricks")
		rel(rf, cf, "RuinCorner", 4, 4, 4, -2, 10, 0, "px_mossy_cobblestone")
		rel(rf, cf, "RuinRubble", 4, 4, 4, 10, 2, 4, "px_mossy_cobblestone")
		rel(rf, cf, "RuinRubble", 2, 2, 2, 7, 1, -4, "px_stone_bricks")
		rel(rf, cf, "RuinRubble", 2, 2, 2, -10, 1, 3, "px_mossy_stone_bricks")
		rel(rf, cf, "RuinMoss", 4.4, 0.6, 4.4, -6, 20.3, 0, "px_hedge", LEAF, true)
		rel(rf, cf, "RuinVine", 1.2, 7, 1.2, -1, 10.5, 2.2, "px_hedge", LEAF, true)
		rel(rf, cf, "RuinVine", 1.2, 10, 1.2, -7.2, 13, 2.2, "px_hedge", LEAF, true)
		rel(rf, cf, "RuinVine", 1.2, 5, 1.2, 1.5, 13.5, -2.2, "px_wisteria_leaves", nil, true)
		for _ = 1, 3 do
			local p = (cf * CFrame.new(rng:NextNumber(-9, 9), 0, rng:NextNumber(-4, 4))).Position
			bloom(p.X - BX, Y, p.Z - BZ, pick(FLOWERS), rf, 1.1)
		end
	end
	do
		local x, z = onL1(120, 9, 3)
		if x then
			ruin(x, z, true)
		end
		x, z = onL1(335, 3, 9)
		if x then
			ruin(x, z, false)
		end
	end

	-- small pink cherry trees and apple trees with red apples
	local function smallTree(x, z, apple)
		local tf = folder(if apple then "AppleTree" else "CherryTree", lf)
		local h = rng:NextInteger(3, 4) * 4
		box(
			"TreeTrunk",
			x - 2,
			Y,
			z - 2,
			x + 2,
			Y + h,
			z + 2,
			if apple then "px_oak_log" else "px_cherry_log",
			nil,
			tf
		)
		local lv, lt =
			if apple then "px_hedge" else "px_cherry_leaves", if apple then LEAF else BLOSSOM
		local function leaves(x0, y0, z0, x1, y1, z1)
			decor(box("TreeLeaves", x0, y0, z0, x1, y1, z1, lv, lt, tf))
		end
		leaves(x - 10, Y + h - 4, z - 6, x + 10, Y + h + 4, z + 6)
		leaves(x - 6, Y + h - 4, z - 10, x + 6, Y + h + 4, z - 6)
		leaves(x - 6, Y + h - 4, z + 6, x + 6, Y + h + 4, z + 10)
		leaves(x - 6, Y + h + 4, z - 6, x + 6, Y + h + 8, z + 6)
		if apple then
			for _ = 1, 7 do
				local side = rng:NextInteger(1, 4)
				local u = rng:NextNumber(-5, 5)
				local ay = Y + h + rng:NextNumber(-3, 3)
				local ax, az = x + u, z + u
				if side == 1 then
					ax = x + 10.4
				elseif side == 2 then
					ax = x - 10.4
				elseif side == 3 then
					az = z + 10.4
				else
					az = z - 10.4
				end
				decor(cube("Apple", ax, ay, az, 1.6, 1.6, 1.6, "px_white_wool", APPLE, tf))
			end
		else
			for _ = 1, 3 do
				local ox, oz = rng:NextInteger(-2, 2) * 4, rng:NextInteger(-2, 2) * 4
				decor(
					cube(
						"PinkWool",
						x + ox,
						Y + h + rng:NextInteger(0, 1) * 4 + 2,
						z + oz,
						4.2,
						4.2,
						4.2,
						"px_white_wool",
						PINK_WOOL,
						tf
					)
				)
			end
			-- fallen petals round the foot
			slabRuns(x - 12, x + 12, z - 12, z + 12, Y + 0.12, Y + 0.2, function(cx, cz)
				return (cx - x) ^ 2 + (cz - z) ^ 2 < 90
					and cellY(cx, cz) == Y
					and math.noise(cx * 0.3, cz * 0.3, 8.8) > 0
			end, "Petals", "px_white_wool", PINK_WOOL, tf)
		end
	end
	for _, t in ipairs({
		{ 47, false },
		{ 60, true },
		{ 135, true },
		{ 148, false },
		{ 160, true },
		{ 258, false },
		{ 284, true },
		{ 310, false },
		{ 323, true },
	}) do
		local x, z = onL1(t[1], 2, 2)
		if x then
			smallTree(x, z, t[2])
		end
	end
	task.wait()

	-- flower beds in single-colour rows
	local function flowerBed(x, z, alongX, n, colors)
		local bf = folder("FlowerBed", lf)
		local len = n * 2.4
		local hx, hz = if alongX then len / 2 + 1 else 4.4, if alongX then 4.4 else len / 2 + 1
		decor(box("BedSoil", x - hx, Y, z - hz, x + hx, Y + 0.15, z + hz, "px_dirt", MUD, bf)).CastShadow =
			false
		for r, col in ipairs(colors) do
			local off = (r - (#colors + 1) / 2) * 2.6
			local bx, bz = if alongX then x else x + off, if alongX then z + off else z
			local sx, sz = if alongX then len else 1.4, if alongX then 1.4 else len
			decor(cube("BedLeaves", bx, Y + 0.6, bz, sx, 1.2, sz, "px_hedge", LEAF, bf))
			for q = 0, n - 1 do
				local u = -len / 2 + 1.2 + q * 2.4
				bloom(
					if alongX then bx + u else bx,
					Y + 1.2,
					if alongX then bz else bz + u,
					col,
					bf,
					1.2
				)
			end
		end
	end
	for _, b in ipairs({
		{ 18, false, { FLOWERS[1], FLOWERS[3], FLOWERS[2] } },
		{ 73, true, { FLOWERS[4], FLOWERS[3], FLOWERS[5] } },
		{ 106, true, { FLOWERS[2], FLOWERS[7], FLOWERS[1] } },
		{ 297, true, { FLOWERS[6], FLOWERS[3], FLOWERS[4] } },
	}) do
		local hx, hz = if b[2] then 7 else 4.4, if b[2] then 4.4 else 7
		local x, z = onL1(b[1], hx, hz)
		if x then
			flowerBed(x, z, b[2], 5, b[3])
		end
	end

	-- the meadow of giant umbrella mushrooms on the north-west of L1
	local mf = folder("MushroomMeadow", lf)
	local STEM = Color3.fromRGB(240, 236, 226)
	local GILL = Color3.fromRGB(235, 205, 180)
	local DOT = Color3.fromRGB(250, 248, 240)
	local function giantMushroom(x, z, hb, cb, thick)
		local h = hb * 4
		local w = if thick then 4 else 2
		box("MushroomStem", x - w, Y, z - w, x + w, Y + h, z + w, "px_white_wool", STEM, mf)
		local c = cb * 2
		decor(
			box(
				"MushroomGills",
				x - c + 2,
				Y + h - 1,
				z - c + 2,
				x + c - 2,
				Y + h,
				z + c - 2,
				"px_white_wool",
				GILL,
				mf
			)
		)
		box(
			"MushroomCap",
			x - c,
			Y + h,
			z - c,
			x + c,
			Y + h + 4,
			z + c,
			"px_white_wool",
			MUSHROOM,
			mf
		)
		if cb >= 4 then
			box(
				"MushroomCapTop",
				x - c + 4,
				Y + h + 4,
				z - c + 4,
				x + c - 4,
				Y + h + 7,
				z + c - 4,
				"px_white_wool",
				MUSHROOM,
				mf
			)
		end
		for _ = 1, 3 + cb do
			local u, v = rng:NextNumber(-c + 1.5, c - 1.5), rng:NextNumber(-c + 1.5, c - 1.5)
			local top = if cb >= 4
					and math.abs(u) < c - 4
					and math.abs(v) < c - 4
				then Y + h + 7
				else Y + h + 4
			decor(
				cube(
					"MushroomDot",
					x + u,
					top + 0.12,
					z + v,
					1.8,
					0.25,
					1.8,
					"px_white_wool",
					DOT,
					mf
				)
			).CastShadow =
				false
		end
	end
	local function smallMushroom(x, z)
		decor(cube("SmallStem", x, Y + 1, z, 1, 2, 1, "px_white_wool", STEM, mf))
		decor(cube("SmallCap", x, Y + 2.5, z, 3, 1.2, 3, "px_white_wool", MUSHROOM, mf))
	end
	local placed = 0
	for a = 200, 250, 7 do
		local hb = rng:NextInteger(3, 8)
		local thick = hb >= 6
		local w = if thick then 4 else 2
		local x, z = onL1(a + rng:NextNumber(-2, 2), w, w)
		if x then
			giantMushroom(x, z, hb, rng:NextInteger(3, 5), thick)
			placed += 1
			for _ = 1, 2 do
				local sx, sz = x + rng:NextNumber(-9, 9), z + rng:NextNumber(-9, 9)
				local d = math.sqrt((sx - HX) ^ 2 + (sz - HZ) ^ 2)
				if
					d > 59
					and cellY(sx, sz) == Y
					and (math.abs(sx - x) > w + 1.5 or math.abs(sz - z) > w + 1.5)
				then
					smallMushroom(sx, sz)
				end
			end
		end
	end

	-- the green-roofed gazebo
	do
		local gx, gz = onL1(30, 5, 5)
		if gx then
			local gf = folder("Gazebo", lf)
			box(
				"GazeboFloor",
				gx - 5,
				Y,
				gz - 5,
				gx + 5,
				Y + 0.6,
				gz + 5,
				"px_mossy_stone_bricks",
				nil,
				gf
			)
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
				local x, z = gx + c[1] * 4.3, gz + c[2] * 4.3
				box(
					"GazeboPost",
					x - 0.7,
					Y + 0.6,
					z - 0.7,
					x + 0.7,
					Y + 9.6,
					z + 0.7,
					"px_dark_oak_log",
					nil,
					gf
				)
				decor(
					box(
						"GazeboVine",
						x - 0.9,
						Y + 3,
						z - 0.9,
						x + 0.9,
						Y + 9,
						z + 0.9,
						"px_hedge",
						LEAF,
						gf
					)
				)
				bloom(x, Y + 0.6, z + c[2] * 1.4, pick(FLOWERS), gf, 1)
			end
			box(
				"GazeboBeam",
				gx - 5,
				Y + 9.6,
				gz - 5,
				gx + 5,
				Y + 10.6,
				gz - 4,
				"px_dark_oak_planks",
				nil,
				gf
			)
			box(
				"GazeboBeam",
				gx - 5,
				Y + 9.6,
				gz + 4,
				gx + 5,
				Y + 10.6,
				gz + 5,
				"px_dark_oak_planks",
				nil,
				gf
			)
			box(
				"GazeboBeam",
				gx - 5,
				Y + 9.6,
				gz - 4,
				gx - 4,
				Y + 10.6,
				gz + 4,
				"px_dark_oak_planks",
				nil,
				gf
			)
			box(
				"GazeboBeam",
				gx + 4,
				Y + 9.6,
				gz - 4,
				gx + 5,
				Y + 10.6,
				gz + 4,
				"px_dark_oak_planks",
				nil,
				gf
			)
			local hw = 7
			local y = Y + 10.6
			for _ = 1, 4 do
				box(
					"GazeboRoof",
					gx - hw,
					y,
					gz - hw,
					gx + hw,
					y + 1.5,
					gz + hw,
					"px_white_wool",
					ROOF_GREEN,
					gf
				)
				y += 1.5
				hw -= 1.8
			end
			box(
				"GazeboTip",
				gx - 0.6,
				y,
				gz - 0.6,
				gx + 0.6,
				y + 1.6,
				gz + 0.6,
				"px_dark_oak_planks",
				nil,
				gf
			)
			box(
				"GazeboBench",
				gx - 3.6,
				Y + 2,
				gz + 2.6,
				gx + 3.6,
				Y + 2.6,
				gz + 3.8,
				"px_dark_oak_planks",
				nil,
				gf
			)
			box(
				"GazeboBenchLeg",
				gx - 3.2,
				Y + 0.6,
				gz + 2.8,
				gx - 2.2,
				Y + 2,
				gz + 3.6,
				"px_stone_bricks",
				nil,
				gf
			)
			box(
				"GazeboBenchLeg",
				gx + 2.2,
				Y + 0.6,
				gz + 2.8,
				gx + 3.2,
				Y + 2,
				gz + 3.6,
				"px_stone_bricks",
				nil,
				gf
			)
			lamp(V(gx, Y + 7.4, gz), gf, BY + Y + 9.6, true)
		end
	end

	-- bushes with flowers at the foot of the summit wall (decor), off the S2 flight and the north arch
	for k = 0, 35 do
		local a = k * 10 + rng:NextNumber(-3, 3)
		if not (a > 66 and a < 114) and not (a > 262 and a < 278) then
			local x, z = polar(a, 41.6)
			if cellY(x, z) == Y then
				decor(cube("WallBush", x, Y + 1.25, z, 3, 2.5, 3, "px_hedge", LEAF, lf))
				bloom(
					x + rng:NextNumber(-0.8, 0.8),
					Y + 2.5,
					z + rng:NextNumber(-0.8, 0.8),
					pick(FLOWERS),
					lf,
					1.2
				)
			end
		end
	end
end
task.wait()

-- ================================================================ 6. the bank: reeds, lily pads on the river, a dock
do
	local kf = folder("Bank", hillF)
	local DOCK = { -94, -40, -74, -32 } -- x0, z0, x1, z1 (on the west bank, out over the ring)
	local function nearCrossing(x, z)
		return (math.abs(x) < 16 and z > 0 and z < 48) -- the south bridge and S1
			or (math.abs(x) > 52 and math.abs(x) < 76 and z > -146 and z < -94) -- the NW / NE bridges
			or (x > DOCK[1] - 4 and x < DOCK[3] + 4 and z > DOCK[2] - 4 and z < DOCK[4] + 4)
			or (math.abs(x) > 64 and z > HZ - 14 and z < HZ + 14) -- the side stairs
	end
	-- reeds along the water's edge
	local REED = Color3.fromRGB(110, 165, 70)
	local reeds = 0
	for a0 = 0, 355, 7 do
		local a = a0 + rng:NextNumber(-2, 2)
		for r = 81.5, 74, -1 do
			local x, z = polar(a, r)
			local ox, oz = polar(a, r + 4)
			if cellY(x, z) == 0 and cellY(ox, oz) == RIVER_BED and not nearCrossing(x, z) then
				for q = 1, 3 do
					local h = rng:NextNumber(3, 6)
					local rx, rz = x + rng:NextNumber(-1.5, 1.5), z + rng:NextNumber(-1.5, 1.5)
					decor(cube("Reed", rx, h / 2, rz, 0.5, h, 0.5, nil, REED, kf))
					if q == 1 then
						decor(
							cube(
								"Cattail",
								rx,
								h + 0.5,
								rz,
								0.8,
								1.4,
								0.8,
								nil,
								Color3.fromRGB(110, 75, 45),
								kf
							)
						)
					end
				end
				reeds += 1
				break
			end
		end
	end
	-- lily pads on the ring river
	local pads = 0
	for _ = 1, 70 do
		local x, z = polar(rng:NextNumber(0, 360), rng:NextNumber(84.5, 95.5))
		local d = math.sqrt((x - HX) ^ 2 + (z - HZ) ^ 2)
		if cellY(x, z) == RIVER_BED and d > 83 and d < 97 and not nearCrossing(x, z) then
			local s = if rng:NextNumber() < 0.5 then 2.6 else 3.4
			local p = decor(
				cube(
					"LilyPad",
					x,
					RIVER_TOP + 0.06,
					z,
					s,
					0.12,
					s,
					"px_hedge",
					Color3.fromRGB(200, 235, 170),
					kf
				)
			)
			p.CastShadow = false
			if rng:NextNumber() < 0.3 then
				local col = if rng:NextNumber() < 0.5 then FLOWERS[4] else FLOWERS[3]
				bloom(x + 0.4, RIVER_TOP + 0.12, z - 0.3, col, kf, 0.9)
			end
			pads += 1
		end
	end
	-- a small dock of planks on posts, a lantern at its end
	do
		local x0, z0, x1, z1 = DOCK[1], DOCK[2], DOCK[3], DOCK[4]
		box("Dock", x0, -0.6, z0, x1, 0.3, z1, "px_planks", nil, kf)
		for _, px in ipairs({ x0 + 0.8, x0 + 8 }) do
			for _, pz in ipairs({ z0 + 0.8, z1 - 0.8 }) do
				box(
					"DockPost",
					px - 0.6,
					RIVER_BED,
					pz - 0.6,
					px + 0.6,
					1.4,
					pz + 0.6,
					"px_oak_log",
					nil,
					kf
				)
			end
		end
		box(
			"DockLampPost",
			x0 + 0.2,
			0.3,
			z0 + 0.2,
			x0 + 1.4,
			6.5,
			z0 + 1.4,
			"px_dark_oak_log",
			nil,
			kf
		)
		box(
			"DockLampArm",
			x0 + 0.2,
			6.5,
			z0 + 0.2,
			x0 + 1.4,
			7.3,
			z0 + 3.4,
			"px_dark_oak_log",
			nil,
			kf
		)
		lamp(V(x0 + 0.8, 4.9, z0 + 2.8), kf, BY + 6.5, true)
		barrel(x1 - 6, 0.3, z1 - 2.4, kf)
		crate(x1 - 10, 0.3, z1 - 2.6, kf, 3)
	end
	print(("[build-eden] hill: reeds %d, lily pads %d"):format(reeds, pads))
end
print(("[build-eden] hill: %d parts, %d lights"):format(count - c0, LIT.n))
