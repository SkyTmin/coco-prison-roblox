--!nocheck
-- ================================================================ edge_gate: the grand stair, the arena, the gate, the towers
-- GATE part (zoneOf == "gate": z < -72, |x| < 120). The grand end stone stair climbs north over the void from the
-- main island (z -76, y 0) to the arena island (z -104, y 16): end stone brick steps on a stepped purpur underside,
-- purpur side walls with end rods. The arena (ARENA r 52, y 16) on the obsidian: flush glowing magenta runes — the soul
-- circle in the centre (a 2×2 core, a ring r 9.5..12.5, a compass star), a dashed inner ring r 22..25.5, the big ring
-- r 34..38 with 16 glyphs at r 39..47, a dim outer ring r 48..52 and blackstone cracks; four obsidian pillars on the
-- diagonals at r ≈ 31 (3×3 base, 2×2 shaft 6 blocks, 3×3 capital, a magenta crystal crown; base, shaft, band and
-- capital tagged Pillar). The rim: an end stone brick parapet ring r 54..58 with openings 6 blocks wide at E, S
-- (the stair landing) and W, and the north sector left to the gate; purpur posts with white candles; a reaper’s
-- scythe (decor) stuck in the floor just inside, west of the south opening. The gate (hero) at the north rim: a
-- pointed obsidian arch x -28..28, ~26 blocks tall (apex pinnacle tip at y ≈ 125), a purpur pillar / end stone brick inner frame, stepped
-- pinnacles and spikes, a shimmering violet portal film with specks, motes and a soft light, on a purpur plinth with
-- two steps; its z is fitted to the island ground (GATE z0 -240 is shifted south while the back corners would
-- overhang the void). Six obsidian towers with magenta crystal crowns and gold-edged magenta banners and four crystal
-- spires (black → magenta) stand on the rim, fitted inward until they sit on island ground.
-- Light only from crystals, end rods, candles and the portal: ≤ 25 PointLights.
local gate = folder("Gate")
local startCount = count
local GY = ARENA_ISLE.y -- 16
local WAX = Color3.fromRGB(238, 230, 208)
local FLAME = Color3.fromRGB(255, 196, 120)
local ROD = Color3.fromRGB(244, 240, 232)
local DIM = Color3.fromRGB(150, 40, 150)
local DEEP_MAGENTA = Color3.fromRGB(110, 30, 100)
local GOLD = Color3.fromRGB(255, 214, 110)
local OPEN_DEG = { 0, 90, 180 } -- the arena openings: angle from +X toward +Z (90 = south, the stair)
local OPEN_HALF = 12 -- half the clear width of an opening (6 blocks)

-- the PointLight budget of this part
local lights = 0
local function glow(p, range, brightness, color)
	if lights >= 25 then
		return nil
	end
	lights += 1
	return light(p, range, brightness, color)
end
-- a Neon box by two corners
local function neon(name, x0, y0, z0, x1, y1, z1, color, parent)
	local p = box(name, x0, y0, z0, x1, y1, z1, nil, color, parent)
	p.Material = Enum.Material.Neon
	return p
end
-- a decor part in a frame cf (local centre, size)
local function fbox(cf, name, sx, sy, sz, lx, ly, lz, variant, color, parent, material)
	local p =
		part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(lx, ly, lz), color, material, parent)
	if variant then
		textured(p, variant, color)
	end
	return decor(p)
end
-- a white candle (Minecraft style: a cream stick, a black wick, a small flame) standing at local (x, y, z)
local function candle(x, y, z, h, parent, lit)
	decor(
		part(
			"Candle",
			Vector3.new(0.9, h, 0.9),
			at(x, y + h / 2, z),
			WAX,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	decor(
		part(
			"Wick",
			Vector3.new(0.15, 0.3, 0.15),
			at(x, y + h + 0.15, z),
			Color3.fromRGB(30, 26, 26),
			nil,
			parent
		)
	)
	local f = decor(
		part(
			"Flame",
			Vector3.new(0.35, 0.6, 0.35),
			at(x, y + h + 0.55, z),
			FLAME,
			Enum.Material.Neon,
			parent
		)
	)
	if lit then
		glow(f, 22, 1.1, Color3.fromRGB(255, 226, 180))
	end
	return f
end
-- a little cluster of candles on a top surface at height y
local function candles(x, y, z, parent, lit)
	candle(x - 0.8, y, z - 0.6, 2.2, parent, lit)
	candle(x + 0.9, y, z + 0.2, 1.5, parent, false)
	if rng:NextNumber() < 0.6 then
		candle(x - 0.4, y, z + 1.1, 1.1, parent, false)
	end
end
-- an end rod standing on a surface at height y: a white base, a thin white rod, a glowing tip
local function endRod(x, y, z, parent, lit)
	decor(
		part(
			"EndRodBase",
			Vector3.new(1.4, 0.5, 1.4),
			at(x, y + 0.25, z),
			ROD,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	decor(
		part(
			"EndRod",
			Vector3.new(0.5, 3, 0.5),
			at(x, y + 2, z),
			ROD,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	local tip = decor(
		part(
			"EndRodTip",
			Vector3.new(0.7, 0.7, 0.7),
			at(x, y + 3.75, z),
			Color3.fromRGB(255, 250, 240),
			Enum.Material.Neon,
			parent
		)
	)
	if lit then
		glow(tip, 26, 1, Color3.fromRGB(240, 225, 255))
	end
	return tip
end
-- is there arena island ground under (x, z)? (the same 8-stud cell test the core builds the island with)
local function ground(x, z)
	return isleOf(math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4) == "arena"
end
-- the distance of (dx, dz) (from the arena centre) to the nearest opening axis, on the outward side of that axis
local function openingPerp(dx, dz)
	local best = math.huge
	for _, deg in ipairs(OPEN_DEG) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		if dx * ux + dz * uz > 0 then
			best = math.min(best, math.abs(-dx * uz + dz * ux))
		end
	end
	return best
end
-- footprints taken on the rim { x0, z0, x1, z1 } (the parapet and the posts keep out of them)
local taken = {}
local function isTaken(x, z, pad)
	for _, t in ipairs(taken) do
		if x > t[1] - pad and x < t[3] + pad and z > t[2] - pad and z < t[4] + pad then
			return true
		end
	end
	return false
end
-- a rim spot at angle deg (from +X toward +Z): radius r0 down to rMin until a footprint of half size h sits on
-- island ground; centres snapped to a block centre
local function rimSpot(deg, r0, rMin, h)
	local a = math.rad(deg)
	local bx, bz
	for r = r0, rMin, -1 do
		local x = ARENA.x + math.floor(math.cos(a) * r / B) * B + 2
		local z = ARENA.z + math.floor(math.sin(a) * r / B) * B + 2
		bx, bz = x, z
		local ok = true
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			if not ground(x + c[1] * (h - 0.5), z + c[2] * (h - 0.5)) then
				ok = false
				break
			end
		end
		if ok then
			return x, z, true
		end
	end
	return bx, bz, false
end
-- a stepped crystal cluster (Neon) on a dark socket, base at (x, y, z); s = scale
local function crystalCrown(x, y, z, s, parent, lit)
	box("CrystalSocket", x - 3, y, z - 3, x + 3, y + 1.5, z + 3, "px_obsidian", nil, parent)
	local yb = y + 1.5
	local core =
		decor(neon("Crystal", x - 1.5, yb, z - 1.5, x + 1.5, yb + 10 * s, z + 1.5, CRYSTAL, parent))
	decor(
		neon(
			"CrystalTip",
			x - 0.75,
			yb + 10 * s,
			z - 0.75,
			x + 0.75,
			yb + 10 * s + 3 * s,
			z + 0.75,
			CRYSTAL,
			parent
		)
	)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		if rng:NextNumber() < 0.85 then
			local h = rng:NextNumber(4, 7) * s
			local cx, cz = x + c[1] * 1.9, z + c[2] * 1.9
			decor(neon("CrystalShard", cx - 1, yb, cz - 1, cx + 1, yb + h, cz + 1, MAGENTA, parent))
			if rng:NextNumber() < 0.5 then
				decor(
					neon(
						"CrystalShardTip",
						cx - 0.5,
						yb + h,
						cz - 0.5,
						cx + 0.5,
						yb + h + 1.5 * s,
						cz + 0.5,
						CRYSTAL,
						parent
					)
				)
			end
		end
	end
	if lit then
		glow(core, 34, 1.4, CRYSTAL)
	end
	return core
end

-- where the gate stands: its back (GATE z0 = -240) moves south while the plinth's back edge would overhang the void
local gb = -230
for cand = GATE.z0, -230, 2 do
	local ok = true
	for _, x in ipairs({ -31.5, -23.5, -15.5, -7.5, 0.5, 8.5, 16.5, 24.5, 31.5 }) do
		if not ground(x, cand + 0.5) then
			ok = false
			break
		end
	end
	if ok then
		gb = cand
		break
	end
end

-- ================================================================ 1. the grand stair (z -76, y 0 → z -104, y 16)
do
	local stair = folder("GrandStair", gate)
	local x0, x1 = GRAND_STAIR.x0, GRAND_STAIR.x1
	local z0, z1 = GRAND_STAIR.z0, GRAND_STAIR.z1
	stairs("GrandStair", (x0 + x1) / 2, z0, z1, 0, GY, x1 - x0, "px_end_stone_bricks", stair)
	local function stairY(z)
		return GY * (z0 - z) / (z0 - z1)
	end
	-- the stepped purpur underside over the void (the main island ends at z -80): a body, a keel, a dangling heart
	local segs = { { -80, -83, -8 }, { -83, -90, -8 }, { -90, -97, -4 }, { -97, -104, 0 } }
	for i, s in ipairs(segs) do
		local top = stairY(s[1]) - 2
		box("StairUnderside", x0, s[3], s[2], x1, top, s[1], "px_purpur", PURPUR, stair)
		box("StairKeel", x0 + 4, s[3] - 4, s[2], x1 - 4, s[3], s[1], "px_purpur", PURPUR, stair)
		if i == 2 or i == 3 then
			box(
				"StairKeelTip",
				x0 + 8,
				s[3] - 8,
				s[2] + 1,
				x1 - 8,
				s[3] - 4,
				s[1] - 1,
				"px_purpur",
				Color3.fromRGB(190, 150, 190),
				stair
			)
		end
	end
	-- purpur side walls 1 block thick, rising 1 block per 7 studs (4 segments), end rods on top
	for k = 0, 3 do
		local za, zb = z0 - 7 * k, z0 - 7 * (k + 1)
		local bottom = if k == 0 then -8 else segs[k + 1][3]
		local top = B * (k + 1) + B
		for _, side in ipairs({ -1, 1 }) do
			local wx0, wx1 = if side < 0 then x0 - 4.4 else x1, if side < 0 then x0 else x1 + 4.4
			box("StairWall", wx0, bottom, zb, wx1, top, za, "px_purpur", PURPUR, stair)
			box(
				"StairWallCap",
				wx0 - 0.2,
				top,
				zb,
				wx1 + 0.2,
				top + 0.6,
				za,
				"px_end_stone_bricks",
				nil,
				stair
			)
			endRod((wx0 + wx1) / 2, top + 0.6, (za + zb) / 2, stair, k == 1)
		end
	end
	-- purpur end posts with end rods at the foot (on the main island edge) and at the landing (on the arena island)
	for _, side in ipairs({ -1, 1 }) do
		local px = side * 14.4
		cube("StairPost", px, 4, -74.4, 4.4, 8, 4.4, "px_purpur_pillar", nil, stair)
		endRod(px, 8, -74.4, stair, false)
		cube("StairPost", px, GY + 4, -106.4, 4.4, 8, 4.4, "px_purpur_pillar", nil, stair)
		endRod(px, GY + 8, -106.4, stair, false)
	end
end
task.wait()

-- ================================================================ 2. the arena: runes, pillars, the rim
do
	local arena = folder("Arena", gate)
	local CELLS = 13 -- cells of 4 studs each way from the centre (r 52)
	local PILLAR_C = 22 -- pillar centres at (±22, ±22) from the centre: r ≈ 31
	local function inPillarBase(dx, dz)
		return math.abs(math.abs(dx) - PILLAR_C) < 6 and math.abs(math.abs(dz) - PILLAR_C) < 6
	end
	local function inGateFoot(x, z)
		return x > -32 and x < 32 and z > gb and z < gb + 16
	end
	-- cracks: random walks of blackstone cells out from the soul circle
	local cracks = {}
	for _ = 1, 7 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = 13
		while r < 33 do
			local dx, dz = math.cos(a) * r, math.sin(a) * r
			cracks[math.floor(dx / B) .. "," .. math.floor(dz / B)] = true
			a += rng:NextNumber(-0.22, 0.22)
			r += rng:NextNumber(3, 4.5)
		end
	end
	-- the floor pattern of the cell centred at (dx, dz): "rune", "dim", "crack" or nil (the bare obsidian)
	local function rune(dx, dz, ix, iz)
		local rr = math.sqrt(dx * dx + dz * dz)
		if rr >= 52 or inPillarBase(dx, dz) then
			return nil
		end
		local ax, az = math.abs(dx), math.abs(dz)
		local th = math.atan2(dz, dx)
		-- the soul circle: a core, a ring, a compass star
		if rr < 3 or (rr >= 9.5 and rr < 12.5) then
			return "rune"
		end
		if rr >= 12.5 and rr < 20 and math.min(ax, az) < 3 then
			return "rune"
		end
		if rr >= 12.5 and rr < 17 and math.abs(ax - az) < 1 then
			return "rune"
		end
		-- the dashed inner ring
		if rr >= 22 and rr < 25.5 and math.floor((th + math.pi) / (math.pi / 24)) % 4 ~= 0 then
			return "dim"
		end
		-- the big ring and its 16 glyphs (between the pillars' diagonals)
		if rr >= 34 and rr < 38 then
			return "rune"
		end
		if rr >= 39 and rr < 47 then
			local step = math.pi / 8
			local k = math.floor((th - step / 2) / step + 0.5)
			local tc = k * step + step / 2
			local v = rr * math.sin(th - tc)
			local u = rr * math.cos(th - tc) - 43
			local g = k % 3
			if g == 0 and math.abs(v) < 3 and math.abs(u) < 4 then
				return "rune"
			elseif
				g == 1
				and ((math.abs(v) < 3 and math.abs(u) < 4) or (u > 0 and u < 4 and math.abs(v) < 7))
			then
				return "rune"
			elseif g == 2 then
				local m = math.abs(u) + math.abs(v)
				if m > 3 and m < 7 then
					return "rune"
				end
			end
		end
		if rr >= 48 then
			return "dim"
		end
		if cracks[ix .. "," .. iz] then
			return "crack"
		end
		return nil
	end
	-- lay the pattern flush (y 15.8 .. 16.1) in runs along x
	local runes = folder("Runes", arena)
	for iz = -CELLS, CELLS - 1 do
		local z0 = ARENA.z + iz * B
		local runX, runKey = nil, nil
		local function flush(xEnd)
			if runX then
				if runKey == "crack" then
					box(
						"Crack",
						runX,
						GY - 0.2,
						z0,
						xEnd,
						GY + 0.1,
						z0 + B,
						"px_blackstone",
						Color3.fromRGB(120, 105, 130),
						runes
					)
				else
					local p = neon(
						"Rune",
						runX,
						GY - 0.2,
						z0,
						xEnd,
						GY + 0.1,
						z0 + B,
						if runKey == "rune" then MAGENTA else DIM,
						runes
					)
					p.CastShadow = false
				end
			end
			runX = nil
		end
		for ix = -CELLS, CELLS - 1 do
			local x = ARENA.x + ix * B
			local key = nil
			if not inGateFoot(x + 2, z0 + 2) then
				key = rune(ix * B + 2, iz * B + 2, ix, iz)
			end
			if key ~= runKey then
				flush(x)
				if key then
					runX = x
				end
				runKey = key
			end
		end
		flush(ARENA.x + CELLS * B)
	end
	-- one magenta light over the soul circle
	glow(
		neon(
			"SoulCore",
			ARENA.x - 1,
			GY + 0.1,
			ARENA.z - 1,
			ARENA.x + 1,
			GY + 0.2,
			ARENA.z + 1,
			CRYSTAL,
			runes
		),
		40,
		1.2,
		MAGENTA
	)
	task.wait()

	-- four obsidian pillars on the diagonals (the boss charge stuns on them)
	for _, s in ipairs({ { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }) do
		local pf = folder("Pillar", arena)
		local px, pz = ARENA.x + s[1] * PILLAR_C, ARENA.z + s[2] * PILLAR_C
		pillarTag(
			box("PillarBase", px - 6, GY, pz - 6, px + 6, GY + B, pz + 6, "px_obsidian", nil, pf)
		)
		pillarTag(
			box(
				"PillarShaft",
				px - 4,
				GY + B,
				pz - 4,
				px + 4,
				GY + 7 * B,
				pz + 4,
				"px_obsidian",
				nil,
				pf
			)
		)
		pillarTag(
			box(
				"PillarBand",
				px - 4.3,
				GY + 3 * B,
				pz - 4.3,
				px + 4.3,
				GY + 3 * B + 1.2,
				pz + 4.3,
				"px_purpur",
				PURPUR,
				pf
			)
		)
		pillarTag(
			box(
				"PillarCapital",
				px - 6,
				GY + 7 * B,
				pz - 6,
				px + 6,
				GY + 8 * B,
				pz + 6,
				"px_obsidian",
				nil,
				pf
			)
		)
		-- glowing rune strips on the two faces toward the centre
		local fx, fz = px - s[1] * 4.15, pz - s[2] * 4.15
		decor(
			neon(
				"PillarRune",
				fx - 0.15,
				GY + B + 3,
				pz - 0.4,
				fx + 0.15,
				GY + 3 * B - 1,
				pz + 0.4,
				MAGENTA,
				pf
			)
		)
		decor(
			neon(
				"PillarRune",
				px - 0.4,
				GY + 3 * B + 3,
				fz - 0.15,
				px + 0.4,
				GY + 7 * B - 3,
				fz + 0.15,
				MAGENTA,
				pf
			)
		)
		crystalCrown(px, GY + 8 * B, pz, 0.8, pf, true)
	end
	task.wait()

	-- the scythe: a reaper’s scythe stuck in the floor inside the parapet, west of the south opening (decor)
	do
		local sf = folder("Scythe", arena)
		local sx, sz = -22, -122
		local cf = at(sx, GY, sz)
		local handle = Color3.fromRGB(70, 52, 48)
		for i = 0, 6 do
			fbox(
				cf,
				"ScytheHandle",
				1.3,
				3.6,
				1.3,
				i * 0.9,
				1.2 + i * 3.2,
				0,
				"px_dark_oak_planks",
				handle,
				sf
			)
		end
		fbox(
			cf,
			"ScytheCollar",
			2.2,
			1.8,
			2.2,
			5.6,
			22.4,
			0,
			"px_iron_block",
			Color3.fromRGB(110, 110, 120),
			sf
		)
		for k = 0, 8 do
			local t = k / 8
			local bx = 5.2 - 13 * t
			local by = 22.6 + 2.2 * math.sin(math.pi * t) - 5 * t * t
			local h = 2.4 - 1.5 * t
			fbox(
				cf,
				"ScytheBlade",
				2.2,
				h,
				0.5,
				bx,
				by,
				0,
				"px_iron_block",
				Color3.fromRGB(170, 172, 186),
				sf
			)
			fbox(
				cf,
				"ScytheEdge",
				2.2,
				0.4,
				0.6,
				bx,
				by - h / 2 - 0.1,
				0,
				nil,
				Color3.fromRGB(225, 225, 235),
				sf,
				Enum.Material.SmoothPlastic
			)
		end
		-- cracked ground round the blade's handle
		box(
			"ScytheCrack",
			sx - 4,
			GY - 0.2,
			sz - 2,
			sx + 4,
			GY + 0.16,
			sz + 2,
			"px_blackstone",
			Color3.fromRGB(150, 140, 150),
			sf
		)
	end
end
task.wait()

-- ================================================================ 3. the gate (hero) at the north rim
do
	local g = folder("TheGate", gate)
	local A, R = 12, 20 -- the opening half-width, the inner arch radius (centres at x = ±(R - A))
	local C = A - R
	local YF = GY + B -- the gate floor (the plinth top)
	local YS = YF + 44 -- the spring line of the arch
	local zw0, zw1 = gb + 2, gb + 10 -- the obsidian wall
	local zf0, zf1 = gb + 1, gb + 11 -- the inner frame and the pinnacle columns (proud of the wall)
	-- the foundation and the plinth, the steps up from the arena floor
	box(
		"GateFoundation",
		-32.5,
		GY - 3 * B,
		gb - 0.5,
		32.5,
		GY,
		gb + 12.5,
		"px_end_stone_bricks",
		nil,
		g
	)
	box(
		"GateFoundationLow",
		-24.5,
		GY - 7 * B,
		gb + 2,
		24.5,
		GY - 3 * B,
		gb + 10,
		"px_purpur",
		PURPUR,
		g
	)
	box("GatePlinth", -32, GY, gb, 32, YF, gb + 12, "px_purpur", PURPUR, g)
	stairs("GateStep", 0, gb + 16, gb + 12, GY, B, 32, "px_end_stone_bricks", g)
	-- the arch rows: inner (opening), frame and outer half-widths per 4-stud row above the spring line
	local function hw(rad, tm)
		if tm >= rad then
			return nil
		end
		local v = snap(C + math.sqrt(rad * rad - tm * tm))
		return if v > 0 then v else nil
	end
	local rows = {}
	for j = 0, 9 do
		local tm = 4 * j + 2
		local xo = hw(R + 16, tm)
		if not xo then
			break
		end
		rows[j] = { xi = hw(R, tm), xf = hw(R + 4, tm), xo = math.min(xo, 20) }
	end
	-- the piers: the purpur pillar frame, the obsidian pier, the pinnacle column (2×2) up to y 92
	for _, sd in ipairs({ -1, 1 }) do
		local function bx(name, a, y0, b, y1, z0, z1, variant, tint)
			return box(
				name,
				math.min(sd * a, sd * b),
				y0,
				z0,
				math.max(sd * a, sd * b),
				y1,
				z1,
				variant,
				tint,
				g
			)
		end
		bx("GateFrame", A, YF, A + 4, YS, zf0, zf1, "px_purpur_pillar", nil)
		bx("GateImpost", A - 1, YS - B, A + 5, YS, gb, gb + 12, "px_end_stone_bricks", nil)
		bx("GatePier", A + 4, YF, 20, YS, zw0, zw1, "px_obsidian", nil)
		bx("GateColumn", 20, YF, 28, YF + 72, zf0, zf1, "px_obsidian", nil)
		bx("GateColumnFoot", 19, YF, 29, YF + B, gb, gb + 12, "px_blackstone_bricks", nil)
		-- the column's stepped pinnacle with corner spikes and a magenta tip
		local cx, ytop = sd * 24, YF + 72
		box("GatePinnacle", cx - 3, ytop, gb + 3, cx + 3, ytop + B, gb + 9, "px_obsidian", nil, g)
		box(
			"GatePinnacle",
			cx - 2,
			ytop + B,
			gb + 4,
			cx + 2,
			ytop + 3 * B,
			gb + 8,
			"px_obsidian",
			nil,
			g
		)
		box(
			"GatePinnacle",
			cx - 1,
			ytop + 3 * B,
			gb + 5,
			cx + 1,
			ytop + 3 * B + 6,
			gb + 7,
			"px_obsidian",
			nil,
			g
		)
		decor(
			neon(
				"GatePinnacleTip",
				cx - 0.5,
				ytop + 3 * B + 6,
				gb + 5.5,
				cx + 0.5,
				ytop + 3 * B + 10,
				gb + 6.5,
				CRYSTAL,
				g
			)
		)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local sx, sz = cx + c[1] * 3, gb + 6 + c[2] * 4
			box("GateSpike", sx - 1, ytop, sz - 1, sx + 1, ytop + 5, sz + 1, "px_obsidian", nil, g)
			box(
				"GateSpikeTip",
				sx - 0.4,
				ytop + 5,
				sz - 0.4,
				sx + 0.4,
				ytop + 7,
				sz + 0.4,
				"px_obsidian",
				nil,
				g
			)
		end
		-- a magenta crystal set in the column's face, purpur end rod posts on the plinth corners
		decor(neon("GateColumnGem", cx - 1, YF + 52, zf1, cx + 1, YF + 56, zf1 + 0.6, MAGENTA, g))
		cube("GatePlinthPost", sd * 30.5, YF + 3, gb + 10, 3, 6, 3, "px_purpur_pillar", nil, g)
		endRod(sd * 30.5, YF + 6, gb + 10, g, false)
	end
	-- the arch above the spring line, row by row (frame voussoirs alternate purpur and end stone bricks)
	for j = 0, #rows do
		local r = rows[j]
		local y0, y1 = YS + 4 * j, YS + 4 * j + 4
		local fv = if j % 2 == 0 and j ~= 4 then "px_purpur" else "px_end_stone_bricks"
		if r.xf then
			if r.xi then
				box(
					"GateArchFrame",
					r.xi,
					y0,
					zf0,
					r.xf,
					y1,
					zf1,
					fv,
					if fv == "px_purpur" then PURPUR else nil,
					g
				)
				box(
					"GateArchFrame",
					-r.xf,
					y0,
					zf0,
					-r.xi,
					y1,
					zf1,
					fv,
					if fv == "px_purpur" then PURPUR else nil,
					g
				)
			else
				box("GateKeystone", -r.xf, y0, zf0, r.xf, y1, zf1, fv, nil, g)
			end
			if r.xo > r.xf then
				box("GateArch", r.xf, y0, zw0, r.xo, y1, zw1, "px_obsidian", nil, g)
				box("GateArch", -r.xo, y0, zw0, -r.xf, y1, zw1, "px_obsidian", nil, g)
			end
		else
			box("GateArch", -r.xo, y0, zw0, r.xo, y1, zw1, "px_obsidian", nil, g)
		end
		-- spikes on the step corners of the extrados
		local nxt = rows[j + 1]
		if j >= 5 and nxt and nxt.xo < r.xo then
			local sx = (r.xo + math.max(nxt.xo, r.xo - 8)) / 2
			for _, sd in ipairs({ -1, 1 }) do
				box(
					"GateSpike",
					sd * sx - 1.5,
					y1,
					gb + 4.5,
					sd * sx + 1.5,
					y1 + 4,
					gb + 7.5,
					"px_obsidian",
					nil,
					g
				)
				box(
					"GateSpikeTip",
					sd * sx - 0.6,
					y1 + 4,
					gb + 5.4,
					sd * sx + 0.6,
					y1 + 7,
					gb + 6.6,
					"px_obsidian",
					nil,
					g
				)
			end
		end
	end
	-- the crown pinnacle over the apex
	local yApex = YS + 4 * (#rows + 1)
	box("GateCrown", -4, yApex, zw0, 4, yApex + 2 * B, zw1, "px_obsidian", nil, g)
	box("GateCrown", -2, yApex + 2 * B, gb + 4, 2, yApex + 4 * B, gb + 8, "px_obsidian", nil, g)
	box("GateCrown", -1, yApex + 4 * B, gb + 5, 1, yApex + 4 * B + 6, gb + 7, "px_obsidian", nil, g)
	decor(
		neon(
			"GateCrownTip",
			-0.6,
			yApex + 4 * B + 6,
			gb + 5.4,
			0.6,
			yApex + 4 * B + 10,
			gb + 6.6,
			CRYSTAL,
			g
		)
	)
	-- the keystone gem
	glow(
		decor(neon("GateGem", -1.5, YS + 17, zf1, 1.5, YS + 20, zf1 + 0.8, CRYSTAL, g)),
		30,
		1.2,
		CRYSTAL
	)
	task.wait()

	-- the portal film: layered translucent violet sheets in the opening, a pixel nebula, specks, motes, a soft light
	local film = folder("PortalFilm", g)
	local rects = { { -A, YF, A, YS + 8 }, { -8, YS + 8, 8, YS + 16 } }
	for _, rc in ipairs(rects) do
		local back = box(
			"PortalBack",
			rc[1],
			rc[2],
			gb + 5.4,
			rc[3],
			rc[4],
			gb + 5.8,
			nil,
			Color3.fromRGB(16, 6, 28),
			film
		)
		back.Material = Enum.Material.Glass
		back.Transparency = 0.2
		back.CanQuery = false
		local mid = decor(
			neon("PortalVeil", rc[1], rc[2], gb + 6, rc[3], rc[4], gb + 6.2, VOID_VIOLET, film)
		)
		mid.Transparency = 0.35
		mid.CastShadow = false
		local front = decor(
			neon(
				"PortalVeil",
				rc[1],
				rc[2],
				gb + 6.9,
				rc[3],
				rc[4],
				gb + 7,
				Color3.fromRGB(40, 10, 70),
				film
			)
		)
		front.Transparency = 0.4
		front.CastShadow = false
		if rc[2] == YF then
			glow(mid, 40, 1.3, Color3.fromRGB(150, 70, 230))
			emitter(mid, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(
					Color3.fromRGB(190, 120, 255),
					Color3.fromRGB(240, 120, 230)
				),
				LightEmission = 1,
				Size = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 0.5),
					NumberSequenceKeypoint.new(1, 0),
				}),
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.2, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
				Lifetime = NumberRange.new(4, 7),
				Rate = 6,
				Speed = NumberRange.new(0.4, 1.4),
				SpreadAngle = Vector2.new(40, 40),
				EmissionDirection = Enum.NormalId.Back,
				RotSpeed = NumberRange.new(-30, 30),
			})
		else
			glow(mid, 30, 0.9, Color3.fromRGB(150, 70, 230))
		end
	end
	-- a pixel nebula in 4-stud cells (violet and magenta wisps), merged along x
	for y = YF, YS + 12, B do
		local half = if y < YS + 8 then A else 8
		local runX, runKey = nil, nil
		local function flush(xEnd)
			if runX then
				local p = decor(
					neon(
						"PortalWisp",
						runX,
						y,
						gb + 6.4,
						xEnd,
						y + B,
						gb + 6.6,
						if runKey == 1
							then Color3.fromRGB(110, 45, 180)
							else Color3.fromRGB(170, 60, 190),
						film
					)
				)
				p.Transparency = if runKey == 1 then 0.5 else 0.6
				p.CastShadow = false
			end
			runX = nil
		end
		for x = -half, half - B, B do
			local n = n2(x * 1.7, y * 1.3, 9.1, 0.06)
			local key = if n > 0.18 then 1 elseif n < -0.3 then 2 else nil
			if key ~= runKey then
				flush(x)
				if key then
					runX = x
				end
				runKey = key
			end
		end
		flush(half)
	end
	-- small light specks (the only place with tiny bits: stars in the film)
	for _ = 1, 44 do
		local y = rng:NextNumber(YF + 1, YS + 15)
		local half = if y < YS + 8 then A - 1 else 7
		local s = rng:NextNumber(0.25, 0.5)
		local sp = decor(
			part(
				"PortalSpeck",
				Vector3.new(s, s, 0.12),
				at(rng:NextNumber(-half, half), y, gb + 6.75),
				if rng:NextNumber() < 0.7 then Color3.fromRGB(245, 230, 255) else CRYSTAL,
				Enum.Material.Neon,
				film
			)
		)
		sp.CastShadow = false
	end
	-- a glowing threshold line
	decor(
		neon(
			"PortalThreshold",
			-A,
			YF,
			gb + 7.2,
			A,
			YF + 0.15,
			gb + 8,
			Color3.fromRGB(150, 70, 230),
			film
		)
	)
end
task.wait()

-- ================================================================ 4. towers, crystal spires, the parapet and the rim posts
do
	local rim = folder("Rim", gate)
	-- the gate and its steps are taken too
	table.insert(taken, { -33, gb - 1, 33, gb + 17 })
	-- an obsidian tower (3×3 → 2×2 blocks, H blocks tall) with a crystal crown and a gold-edged magenta banner
	local function tower(x, z, H)
		local tf = folder("Tower", rim)
		local h1 = math.floor(H * 0.6)
		local y1 = GY + h1 * B
		local yt = GY + H * B
		box("TowerBase", x - 6, GY, z - 6, x + 6, y1, z + 6, "px_obsidian", nil, tf)
		box("TowerCornice", x - 7, y1, z - 7, x + 7, y1 + 2, z + 7, "px_blackstone_bricks", nil, tf)
		box("TowerShaft", x - 4, y1 + 2, z - 4, x + 4, yt, z + 4, "px_obsidian", nil, tf)
		box("TowerCap", x - 5, yt, z - 5, x + 5, yt + 2, z + 5, "px_blackstone_bricks", nil, tf)
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			cube(
				"TowerMerlon",
				x + c[1] * 4,
				yt + 3.5,
				z + c[2] * 4,
				2,
				3,
				2,
				"px_obsidian",
				nil,
				tf
			)
		end
		crystalCrown(x, yt + 2, z, 1, tf, true)
		-- the face toward the arena: a banner on the base, a magenta slit on the shaft
		local ux, uz = ARENA.x - x, ARENA.z - z
		local nx, nz = 0, 0
		if math.abs(ux) > math.abs(uz) then
			nx = if ux > 0 then 1 else -1
		else
			nz = if uz > 0 then 1 else -1
		end
		local len = math.min(22, (y1 - GY) - 3)
		local by = y1 - 1 - len / 2
		local fp = V(x + nx * 6, by, z + nz * 6)
		local cf = CFrame.lookAt(fp, fp + Vector3.new(nx, 0, nz))
		fbox(cf, "Banner", 4.4, len, 0.3, 0, 0, -0.35, "px_white_wool", MAGENTA, tf)
		fbox(cf, "BannerEdge", 0.6, len, 0.4, -2.5, 0, -0.4, "px_gold_block", GOLD, tf)
		fbox(cf, "BannerEdge", 0.6, len, 0.4, 2.5, 0, -0.4, "px_gold_block", GOLD, tf)
		fbox(cf, "BannerRod", 6.2, 0.8, 0.8, 0, len / 2 + 0.4, -0.5, "px_gold_block", GOLD, tf)
		fbox(cf, "BannerHem", 5.6, 0.8, 0.45, 0, -len / 2 + 0.4, -0.42, "px_gold_block", GOLD, tf)
		local emblem =
			fbox(cf, "BannerEmblem", 2, 2, 0.5, 0, len / 2 - 5, -0.5, "px_gold_block", GOLD, tf)
		emblem.CFrame = emblem.CFrame * CFrame.Angles(0, 0, math.rad(45))
		fbox(cf, "BannerEmblemCore", 0.9, 0.9, 0.6, 0, len / 2 - 5, -0.55, "px_obsidian", nil, tf)
		local sp = V(x + nx * 4, (y1 + yt) / 2, z + nz * 4)
		local scf = CFrame.lookAt(sp, sp + Vector3.new(nx, 0, nz))
		fbox(scf, "TowerSlit", 1, 6, 0.3, 0, 0, -0.1, nil, MAGENTA, tf, Enum.Material.Neon)
		table.insert(taken, { x - 7, z - 7, x + 7, z + 7 })
	end
	-- a crystal spire: black columns at the base turning deep magenta, magenta, then a bright tip
	local function spire(x, z, lit)
		local sf = folder("CrystalSpire", rim)
		local function column(cx, cz, half, hBlocks)
			local hb = math.max(1, hBlocks - 3)
			local y1 = GY + hb * B
			box(
				"SpireBlack",
				cx - half,
				GY,
				cz - half,
				cx + half,
				y1,
				cz + half,
				"px_obsidian",
				nil,
				sf
			)
			local y2 = y1 + B
			decor(
				neon(
					"SpireDeep",
					cx - half,
					y1,
					cz - half,
					cx + half,
					y2,
					cz + half,
					DEEP_MAGENTA,
					sf
				)
			)
			local y3 = GY + hBlocks * B
			local mid = decor(
				neon(
					"SpireMagenta",
					cx - half,
					y2,
					cz - half,
					cx + half,
					y3,
					cz + half,
					MAGENTA,
					sf
				)
			)
			decor(
				neon(
					"SpireTip",
					cx - half / 2,
					y3,
					cz - half / 2,
					cx + half / 2,
					y3 + half * 1.5,
					cz + half / 2,
					CRYSTAL,
					sf
				)
			)
			return mid
		end
		local core = column(x, z, 4, rng:NextInteger(8, 10))
		if lit then
			glow(core, 30, 1.1, MAGENTA)
		end
		for _, o in ipairs({ { -6, -2 }, { 6, 2 }, { -2, 6 }, { 2, -6 } }) do
			if rng:NextNumber() < 0.8 then
				column(x + o[1], z + o[2], 2, rng:NextInteger(4, 6))
			end
		end
		table.insert(taken, { x - 8, z - 8, x + 8, z + 8 })
	end
	local placed = {}
	for _, t in ipairs({
		{ 232, 16 },
		{ 308, 16 },
		{ 42, 13 },
		{ 138, 13 },
		{ 64, 11 },
		{ 116, 11 },
	}) do
		local x, z, ok = rimSpot(t[1], 61, 58, 6)
		tower(x, z, t[2])
		table.insert(
			placed,
			("tower %d° (%d, %d)%s"):format(t[1], x, z, if ok then "" else " EDGE")
		)
	end
	task.wait()
	for i, deg in ipairs({ 340, 200, 20, 160 }) do
		local x, z, ok = rimSpot(deg, 62, 58, 7)
		if not isTaken(x, z, 7) then
			spire(x, z, i <= 2)
			table.insert(
				placed,
				("spire %d° (%d, %d)%s"):format(deg, x, z, if ok then "" else " EDGE")
			)
		end
	end
	task.wait()

	-- the parapet ring r 54..58: end stone bricks with a purpur coping, cut at the openings, the gate and the towers
	local CELLS = 15
	local wallCells = {}
	for iz = -CELLS, CELLS - 1 do
		local z0 = ARENA.z + iz * B
		local runX = nil
		local function flush(xEnd)
			if runX then
				box("Parapet", runX, GY, z0, xEnd, GY + B, z0 + B, "px_end_stone_bricks", nil, rim)
				box(
					"ParapetCoping",
					runX,
					GY + B,
					z0,
					xEnd,
					GY + B + 1,
					z0 + B,
					"px_purpur",
					PURPUR,
					rim
				)
			end
			runX = nil
		end
		for ix = -CELLS, CELLS - 1 do
			local dx, dz = ix * B + 2, iz * B + 2
			local rr = math.sqrt(dx * dx + dz * dz)
			local x, z = ARENA.x + dx, ARENA.z + dz
			if
				rr >= 54
				and rr < 58
				and openingPerp(dx, dz) >= OPEN_HALF
				and not isTaken(x, z, 1)
				and ground(x, z)
			then
				wallCells[ix .. "," .. iz] = true
				runX = runX or ARENA.x + ix * B
			else
				flush(ARENA.x + ix * B)
			end
		end
		flush(ARENA.x + CELLS * B)
	end
	-- tall purpur posts with candles flanking each opening (one lit candle per post)
	for _, deg in ipairs(OPEN_DEG) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		for _, sd in ipairs({ -1, 1 }) do
			local px = ARENA.x + math.floor((ux * 55 - uz * 14 * sd) / B) * B + 2
			local pz = ARENA.z + math.floor((uz * 55 + ux * 14 * sd) / B) * B + 2
			cube("OpeningPost", px, GY + 6, pz, 4.4, 12, 4.4, "px_purpur_pillar", nil, rim)
			cube("OpeningPostCap", px, GY + 12.5, pz, 5, 1, 5, "px_purpur", PURPUR, rim)
			candles(px, GY + 13, pz, rim, true)
		end
	end
	-- purpur posts with candles along the parapet every 15°
	local used = {}
	for k = 0, 23 do
		local a = math.rad(k * 15 + 7.5)
		local ix, iz = math.floor(math.cos(a) * 55.8 / B), math.floor(math.sin(a) * 55.8 / B)
		local key = ix .. "," .. iz
		local dx, dz = ix * B + 2, iz * B + 2
		if wallCells[key] and not used[key] and openingPerp(dx, dz) >= OPEN_HALF + 6 then
			used[key] = true
			local cx, cz = ARENA.x + dx, ARENA.z + dz
			cube("RimPost", cx, GY + 4, cz, 4.4, 8, 4.4, "px_purpur_pillar", nil, rim)
			cube("RimPostCap", cx, GY + 8.4, cz, 4.8, 0.8, 4.8, "px_purpur", PURPUR, rim)
			candles(cx, GY + 8.8, cz, rim, false)
		end
	end
	print(("[build-edge-gate] gate: back z %d; %s"):format(gb, table.concat(placed, ", ")))
end

print(("[build-edge-gate] gate part: %d parts, %d lights"):format(count - startCount, lights))
