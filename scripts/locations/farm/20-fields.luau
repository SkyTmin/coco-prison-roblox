--!nocheck
-- ================================================================ farm: the fields (L0 west of x 116)
-- The patchwork of crop beds round the pit: each bed (BEDS, inside FIELDS) is planted in stripes 5 blocks wide —
-- golden wheat rows, low carrot and beet rows with orange / red tops at the root, rows of cabbage cubes, melon and
-- pumpkin blocks on vines — with water channels under spruce trapdoors between some stripes, an oak fence with a
-- 3-block gate toward the nearest path and a lamp post at one corner. Three yards are cut out of the fields:
--   YARD_W1  x -136..-100, z -60..8    the chicken coop with its fenced run, the sheep pen
--   YARD_W2  x -140..-100, z 40..112   the yellow-white produce stall at the west path entrance, the beehive tree, the
--                                      tool shed, compost bins, a haystack, the stone well with a roof at (-120, 102)
--   YARD_S   x 20..48, z 124..204      the pumpkin cart near the buyer, sacks, crates, a haystack, a wheelbarrow,
--                                      compost bins, an apple tree, a flower strip along the south path
-- Round the pit: an oak fence on the inner block of the ring path (x ±74, z -50 / 98), open at the ladder shafts and
-- in front of the arrival; six lamp posts on the ring's outer edge. Scarecrows in the wheat of beds 1 and 3. Hedges on
-- the west rim, between the fields and under the hill; a low stone wall along the south rim with gaps; benches at the
-- south viewpoint at the end of the south path; oak / apple trees on the edges.
local fields = folder("Fields")
local startCount = count
local C = {
	wheat = { WHEAT, Color3.fromRGB(238, 212, 112), Color3.fromRGB(214, 196, 96) },
	carrotTop = Color3.fromRGB(112, 200, 64),
	carrot = Color3.fromRGB(236, 128, 36),
	beetTop = Color3.fromRGB(72, 140, 60),
	beet = Color3.fromRGB(150, 40, 72),
	cabbage = { Color3.fromRGB(156, 214, 112), Color3.fromRGB(122, 192, 90) },
	leafDark = Color3.fromRGB(78, 136, 56),
	vine = Color3.fromRGB(70, 128, 48),
	stem = Color3.fromRGB(96, 110, 44),
	honey = Color3.fromRGB(232, 172, 52),
	iron = Color3.fromRGB(60, 60, 66),
	carve = Color3.fromRGB(46, 26, 12),
	sack = Color3.fromRGB(206, 176, 126),
	wool = Color3.fromRGB(240, 240, 236),
	face = Color3.fromRGB(70, 56, 48),
	comb = Color3.fromRGB(210, 40, 40),
	beak = Color3.fromRGB(240, 170, 40),
	flowers = {
		Color3.fromRGB(220, 50, 50),
		Color3.fromRGB(245, 215, 60),
		Color3.fromRGB(90, 120, 225),
		Color3.fromRGB(245, 245, 245),
		Color3.fromRGB(240, 140, 190),
		Color3.fromRGB(240, 140, 40),
	},
}

-- a textured box in a local frame cf (a world CFrame) by two corners
local function lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(name, size, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a small plain decor bit in a frame cf by size and local centre
local function lc(cf, name, sx, sy, sz, x, y, z, color, parent)
	return decor(part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, nil, parent))
end
-- a frame at local (x, z) turned by yaw; its front is -Z (yaw 0 faces north, pi south, pi/2 west, -pi/2 east)
local function fr(x, z, yaw, y)
	return at(x, y or 0, z) * CFrame.Angles(0, yaw or 0, 0)
end
-- crop ground: on the island (10 studs in), off the stairs, the paths and other zones
local function okCrop(x, z)
	return onIsland(x, z, 10) and not inStairCorridor(x, z) and not onPath(x, z, 1) and zoneOf(x, z) == "fields"
end
-- the runs of a line along `axis` ("x": points (a, c), "z": (c, a)) from a0 to a1, sampled every 4 studs, where ok
-- holds at every cross coordinate in cs: { {s, e}, ... }
local function runs(axis, a0, a1, cs, ok)
	local out, s = {}, nil
	local a = a0 + 2
	while a < a1 do
		local good = true
		for _, c in ipairs(cs) do
			local x, z = a, c
			if axis == "z" then
				x, z = c, a
			end
			if not ok(x, z) then
				good = false
				break
			end
		end
		if good then
			s = s or (a - 2)
		elseif s then
			table.insert(out, { s, a - 2 })
			s = nil
		end
		a += 4
	end
	if s then
		table.insert(out, { s, math.min(a - 2, a1) })
	end
	return out
end
-- a box in stripe coordinates: a along the stripe, u across it
local function sbox(name, axis, a0, a1, u0, u1, y0, y1, variant, tint, parent)
	if axis == "x" then
		return box(name, a0, y0, u0, a1, y1, u1, variant, tint, parent)
	end
	return box(name, u0, y0, a0, u1, y1, a1, variant, tint, parent)
end
local function scube(name, axis, a, u, y, sa, sy, su, variant, tint, parent)
	if axis == "x" then
		return cube(name, a, y, u, sa, sy, su, variant, tint, parent)
	end
	return cube(name, u, y, a, su, sy, sa, variant, tint, parent)
end
-- a free spot for a prop (warns when the plan check fails, so the evening check can look at it)
local function spot(x, z, pad, what)
	if not freeGround(x, z, pad) or zoneOf(x, z) ~= "fields" then
		warn(("[build-farm] fields: %s at (%d, %d) is not on free ground"):format(what, x, z))
	end
end
-- an oak / apple tree of blocks where the ground is free (the trunk off the rim, the paths and the pit)
local function tryTree(x, z, h, parent, apples)
	if
		not onIsland(x, z, 12)
		or onPath(x, z, 3)
		or inPitArea(x, z, 4)
		or inStairCorridor(x, z)
		or zoneOf(x, z) ~= "fields"
		or math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) < 24
	then
		return nil
	end
	local t = tree(x, z, h, parent, "px_hedge", "px_oak_log")
	if apples then
		for i = 1, 5 do
			local a = (i / 5) * math.pi * 2 + rng:NextNumber(0, 0.6)
			local r = 10.3
			local p = decor(part("Apple", Vector3.new(1.2, 1.2, 1.2), at(x + math.cos(a) * r, h + rng:NextInteger(-1, 1), z + math.sin(a) * r), Color3.fromRGB(200, 30, 30), nil, t))
			p.CastShadow = false
		end
	end
	return t
end

-- ================================================================ 1. the crop beds
do
	local crops = folder("CropBeds", fields)
	-- the beds: rect, the crop cycle offset, gates { side, centre } (12 studs wide), the lamp post { x, z, yaw }
	local BEDS = {
		{ -208, -60, -136, 8, off = 0, gates = { { "s", -172 } }, lamp = { -140, 12, math.pi } },
		{ -208, 40, -140, 112, off = 2, gates = { { "n", -172 }, { "e", 94 } }, lamp = { -144, 36, 0 } },
		{ -208, 124, -20, 204, off = 4, gates = { { "e", 164 }, { "n", -56 } }, lamp = { -16, 200, -math.pi / 2 } },
		{ 52, 124, 112, 204, off = 1, gates = { { "w", 164 }, { "n", 82 } }, lamp = { 50, 121, 0 } },
		{ 100, -60, 116, 8, off = 1, gates = { { "w", -26 } }, lamp = { 96, 4, math.pi / 2 } },
		{ 100, 40, 116, 112, off = 3, gates = { { "w", 76 } }, lamp = { 96, 108, math.pi / 2 } },
	}
	local CYCLE = { "wheat", "carrot", "cabbage", "melon", "wheat", "beet", "pumpkin" }
	local planted = { wheat = 0, carrot = 0, cabbage = 0, melon = 0, beet = 0, pumpkin = 0 }

	-- low rows (carrots, beets): a coloured root fringe under a green top, a few root specks
	local function lowRows(axis, a0, a1, u0, u1, parent, topTint, rootTint, h)
		local n = math.floor((u1 - u0) / 4)
		for k = 0, n - 1 do
			local r0 = u0 + k * 4 + 0.5
			local r1 = r0 + 3
			for _, s in ipairs(runs(axis, a0, a1, { r0, r1 }, okCrop)) do
				decor(sbox("CropRoots", axis, s[1], s[2], r0 - 0.2, r1 + 0.2, 0, 0.6, "px_hay", rootTint, parent))
				decor(sbox("CropLeaves", axis, s[1], s[2], r0 + 0.4, r1 - 0.4, 0.6, h, "px_hedge", topTint, parent))
				local a = s[1] + 4 + (k % 3) * 4
				while a < s[2] - 2 do
					local side = if (a // 4 + k) % 2 == 0 then r0 + 0.3 else r1 - 0.3
					decor(scube("CropSpeck", axis, a, side, 1.0, 1.2, 0.9, 1.2, nil, rootTint, parent))
					a += 12
				end
			end
		end
	end
	-- block rows (cabbages, melons, pumpkins): rows 6 studs apart across the stripe
	local function blockRowCentres(u0, u1)
		local w = u1 - u0
		local m = math.max(1, math.floor((w + 2) / 6))
		local first = u0 + (w - (m - 1) * 6) / 2
		local out = {}
		for k = 0, m - 1 do
			table.insert(out, first + k * 6)
		end
		return out
	end
	local function pumpkin(axis, a, u, parent)
		scube("Pumpkin", axis, a, u, 1.9, 3.8, 3.8, 3.8, "px_hay", PUMPKIN, parent)
		decor(scube("PumpkinStem", axis, a, u, 4.2, 0.7, 0.8, 0.7, nil, C.stem, parent))
	end
	local function vineRows(axis, a0, a1, u0, u1, parent, mode)
		for k, u in ipairs(blockRowCentres(u0, u1)) do
			for _, s in ipairs(runs(axis, a0, a1, { u - 2, u + 2 }, okCrop)) do
				decor(sbox("Vine", axis, s[1], s[2], u - 0.6, u + 0.6, 0, 0.5, "px_hedge", C.vine, parent))
				local a = s[1] + 2 + (k % 2) * 4
				while a <= s[2] - 2 do
					local r = rng:NextNumber()
					if r < 0.28 then
						decor(scube("VineLeaves", axis, a, u, 0.5, 2.6, 1, 2.6, "px_hedge", C.leafDark, parent))
					elseif mode == "pumpkin" or (mode == "mixed" and k % 2 == 0) or r > 0.92 then
						pumpkin(axis, a, u, parent)
					else
						scube("Melon", axis, a, u, 1.9, 3.8, 3.8, 3.8, "px_melon", nil, parent)
					end
					a += 8
				end
			end
		end
	end
	local PLANT = {
		wheat = function(axis, a0, a1, u0, u1, parent)
			local n = math.floor((u1 - u0) / 4)
			for k = 0, n - 1 do
				local r0 = u0 + k * 4 + 0.5
				local r1 = r0 + 3
				for _, s in ipairs(runs(axis, a0, a1, { r0, r1 }, okCrop)) do
					local p = s[1]
					while p < s[2] - 0.1 do
						local q = math.min(s[2], p + rng:NextInteger(3, 7) * 4)
						if s[2] - q < 8 then
							q = s[2]
						end
						local h = 2.8 + rng:NextInteger(0, 3) * 0.3
						decor(sbox("Wheat", axis, p, q, r0, r1, 0, h, "px_hay", pick(C.wheat), parent))
						p = q
					end
				end
			end
		end,
		carrot = function(axis, a0, a1, u0, u1, parent)
			lowRows(axis, a0, a1, u0, u1, parent, C.carrotTop, C.carrot, 2.2)
		end,
		beet = function(axis, a0, a1, u0, u1, parent)
			lowRows(axis, a0, a1, u0, u1, parent, C.beetTop, C.beet, 1.8)
		end,
		cabbage = function(axis, a0, a1, u0, u1, parent)
			for k, u in ipairs(blockRowCentres(u0, u1)) do
				for _, s in ipairs(runs(axis, a0, a1, { u - 2, u + 2 }, okCrop)) do
					decor(sbox("CabbageLeaves", axis, s[1], s[2], u - 2.2, u + 2.2, 0, 0.4, "px_hedge", C.leafDark, parent))
					local a = s[1] + 2 + (k % 2) * 3
					while a <= s[2] - 2 do
						decor(scube("Cabbage", axis, a, u, 1.9, 3.6, 3.2, 3.6, "px_hedge", pick(C.cabbage), parent))
						a += 6
					end
				end
			end
		end,
		melon = function(axis, a0, a1, u0, u1, parent)
			vineRows(axis, a0, a1, u0, u1, parent, "mixed")
		end,
		pumpkin = function(axis, a0, a1, u0, u1, parent)
			vineRows(axis, a0, a1, u0, u1, parent, "pumpkin")
		end,
	}
	-- a water channel 1 block wide, flush on the farmland, spruce trapdoors over it every 4 blocks
	local function channel(axis, a0, a1, u0, parent)
		for _, s in ipairs(runs(axis, a0, a1, { u0 + 0.5, u0 + 3.5 }, okCrop)) do
			local w = decor(sbox("WaterChannel", axis, s[1], s[2], u0 + 0.3, u0 + 3.7, 0.02, 0.14, "px_water", nil, parent))
			w.Transparency = 0.3
			w.CastShadow = false
			local a = s[1] + 6
			while a <= s[2] - 2 do
				scube("Trapdoor", axis, a, u0 + 2, 0.4, 3.8, 0.5, 3.8, "px_spruce_planks", nil, parent)
				a += 16
			end
		end
	end
	-- the oak fence round a bed: posts + 2 rails, gaps at the gates, clipped to the island
	local function okFence(x, z)
		return onIsland(x, z, 10) and not inStairCorridor(x, z) and not onPath(x, z, 1) and zoneOf(x, z) == "fields"
	end
	local function bedFence(b, parent)
		local X0, Z0, X1, Z1 = b[1] + 2, b[2] + 2, b[3] - 2, b[4] - 2
		local sides = {
			n = { "x", X0, X1, Z0 },
			s = { "x", X0, X1, Z1 },
			w = { "z", Z0, Z1, X0 },
			e = { "z", Z0, Z1, X1 },
		}
		for key, sd in pairs(sides) do
			local axis, a0, a1, c = sd[1], sd[2], sd[3], sd[4]
			-- the side minus its gates
			local parts = { { a0, a1 } }
			for _, g in ipairs(b.gates) do
				if g[1] == key then
					local nxt = {}
					for _, p in ipairs(parts) do
						if g[2] - 6 > p[1] then
							table.insert(nxt, { p[1], math.min(p[2], g[2] - 6) })
						end
						if g[2] + 6 < p[2] then
							table.insert(nxt, { math.max(p[1], g[2] + 6), p[2] })
						end
					end
					parts = nxt
					-- gate posts: a little taller, with a lantern-less cap
					for _, e in ipairs({ g[2] - 6, g[2] + 6 }) do
						local gx, gz = e, c
						if axis == "z" then
							gx, gz = c, e
						end
						if okFence(gx, gz) then
							cube("GatePost", gx, 2.2, gz, 1.4, 4.4, 1.4, "px_oak_log", nil, parent)
						end
					end
				end
			end
			for _, p in ipairs(parts) do
				for _, s in ipairs(runs(axis, p[1], p[2], { c }, okFence)) do
					if s[2] - s[1] >= 4 then
						if axis == "x" then
							fence(s[1], c, s[2], c, parent, 0, "px_planks")
						else
							fence(c, s[1], c, s[2], parent, 0, "px_planks")
						end
					end
				end
			end
		end
	end

	for i, b in ipairs(BEDS) do
		local bed = folder("Bed" .. i, crops)
		local ix0, iz0, ix1, iz1 = b[1] + 4, b[2] + 4, b[3] - 4, b[4] - 4
		local axis, a0, a1, c0, c1 = "x", ix0, ix1, iz0, iz1
		if ix1 - ix0 < iz1 - iz0 then
			axis, a0, a1, c0, c1 = "z", iz0, iz1, ix0, ix1
		end
		local pos, k = c0, 0
		while c1 - pos >= 8 do
			local w = math.min(20, c1 - pos)
			if c1 - pos - w > 0 and c1 - pos - w < 8 then
				w = c1 - pos
			end
			local crop = CYCLE[(b.off + k) % #CYCLE + 1]
			PLANT[crop](axis, a0, a1, pos, pos + w, bed)
			planted[crop] += 1
			pos += w
			k += 1
			if k % 2 == 1 and c1 - pos >= 12 then
				channel(axis, a0, a1, pos, bed)
				pos += 4
			end
		end
		bedFence(b, bed)
		lampPost(b.lamp[1], b.lamp[2], bed, false, b.lamp[3])
		task.wait()
	end
	print(
		("[build-farm] fields: beds %d, stripes wheat %d, carrot %d, beet %d, cabbage %d, melon %d, pumpkin %d"):format(
			#BEDS,
			planted.wheat,
			planted.carrot,
			planted.beet,
			planted.cabbage,
			planted.melon,
			planted.pumpkin
		)
	)
end
task.wait()

-- ================================================================ 2. round the pit: the fence and the lamp posts
do
	local ring = folder("PitFence", fields)
	-- on the inner block of the ring path, open at the ladder shafts and in front of the arrival
	for _, seg in ipairs({
		{ -74, -50, -12, -50 },
		{ 12, -50, 74, -50 },
		{ -74, 98, -20, 98 },
		{ 20, 98, 74, 98 },
		{ -74, -50, -74, 12 },
		{ -74, 36, -74, 98 },
		{ 74, -50, 74, 12 },
		{ 74, 36, 74, 98 },
	}) do
		fence(seg[1], seg[2], seg[3], seg[4], ring, 0, "px_planks")
	end
	for _, e in ipairs({ { -12, -50 }, { 12, -50 }, { -20, 98 }, { 20, 98 }, { -74, 12 }, { -74, 36 }, { 74, 12 }, { 74, 36 } }) do
		cube("FenceEndPost", e[1], 2.2, e[2], 1.4, 4.4, 1.4, "px_oak_log", nil, ring)
	end
	-- lamp posts on the ring's outer edge, the lanterns hanging over the path
	for _, l in ipairs({
		{ -90, -40, -math.pi / 2 },
		{ 90, -40, math.pi / 2 },
		{ -90, 76, -math.pi / 2 },
		{ 90, 76, math.pi / 2 },
		{ -56, 114, 0 },
		{ 56, 114, 0 },
	}) do
		lampPost(l[1], l[2], ring, false, l[3])
	end
end
task.wait()

-- ================================================================ 3. the yards: coop, sheep, stall, well, shed, cart
do
	local yards = folder("Yards", fields)

	local function sack(x, z, parent)
		cube("Sack", x, 1.4, z, 2.4, 2.8, 2.4, "px_brown_wool", C.sack, parent)
		decor(cube("SackTie", x, 3.1, z, 1.2, 0.6, 1.2, nil, Color3.fromRGB(120, 90, 60), parent))
	end
	local function haystack(x, z, parent)
		box("Haystack", x - 4, 0, z - 4, x + 4, 4, z + 4, "px_hay", nil, parent)
		cube("Haystack", x + (if rng:NextNumber() < 0.5 then -2 else 2), 6, z - 2, B, B, B, "px_hay", nil, parent)
	end
	local function compost(x, z, parent)
		cube("Composter", x, 2, z, B, B, B, "px_spruce_planks", Color3.fromRGB(160, 120, 86), parent)
		decor(cube("Compost", x, 3.95, z, 3, 0.2, 3, "px_dirt", FARMLAND, parent))
	end
	local function flower(x, z, col, parent)
		decor(cube("FlowerStem", x, 0.8, z, 0.4, 1.6, 0.4, nil, C.vine, parent))
		decor(cube("Flower", x, 2.1, z, 1.3, 1.3, 1.3, nil, col, parent))
	end
	local function chicken(x, z, yaw, parent)
		local cf = fr(x, z, yaw)
		lb(cf, "ChickenBody", -1, 0.9, -1.3, 1, 2.9, 1.3, "px_white_wool", nil, parent)
		lb(cf, "ChickenHead", -0.7, 2.4, -2.1, 0.7, 4.2, -0.9, "px_white_wool", nil, parent)
		lc(cf, "ChickenBeak", 0.7, 0.4, 0.6, 0, 3.4, -2.35, C.beak, parent)
		lc(cf, "ChickenComb", 0.4, 0.6, 0.8, 0, 4.5, -1.6, C.comb, parent)
		lc(cf, "ChickenWattle", 0.4, 0.6, 0.3, 0, 2.8, -2.2, C.comb, parent)
		for _, s in ipairs({ -0.5, 0.5 }) do
			lc(cf, "ChickenLeg", 0.3, 0.9, 0.3, s, 0.45, 0, C.beak, parent)
		end
	end
	local function sheep(x, z, yaw, parent)
		local cf = fr(x, z, yaw)
		lb(cf, "SheepBody", -1.8, 1.8, -2.6, 1.8, 5, 2.6, "px_white_wool", nil, parent)
		lb(cf, "SheepHead", -1.1, 3.4, -4.2, 1.1, 5.6, -2.4, nil, C.face, parent)
		lb(cf, "SheepWoolCap", -1.2, 5.2, -3.8, 1.2, 5.9, -2.4, "px_white_wool", nil, parent)
		for _, sx in ipairs({ -1.1, 1.1 }) do
			for _, sz in ipairs({ -1.8, 1.8 }) do
				lc(cf, "SheepLeg", 0.9, 1.8, 0.9, sx, 0.9, sz, C.face, parent)
			end
		end
	end
	local function scarecrow(x, z, yaw, parent)
		local f = folder("Scarecrow", parent)
		local cf = fr(x, z, yaw)
		lb(cf, "ScarecrowPost", -0.6, 0, -0.6, 0.6, 4.4, 0.6, "px_oak_log", nil, f)
		lb(cf, "ScarecrowBody", -1.8, 4, -1.2, 1.8, 8.4, 1.2, "px_hay", nil, f)
		lb(cf, "ScarecrowBelt", -1.9, 5.4, -1.3, 1.9, 6, 1.3, "px_brown_wool", nil, f)
		lb(cf, "ScarecrowArms", -5.2, 6.8, -0.5, 5.2, 7.6, 0.5, "px_oak_log", nil, f)
		for _, s in ipairs({ -1, 1 }) do
			lb(cf, "Straw", s * 5.2 - 0.6, 6.3, -0.7, s * 5.2 + 0.6, 8.1, 0.7, "px_hay", nil, f)
		end
		lb(cf, "PumpkinHead", -1.7, 8.4, -1.7, 1.7, 11.8, 1.7, "px_hay", PUMPKIN, f)
		-- the carved face: dark cut-outs on the front
		for _, s in ipairs({ -0.75, 0.75 }) do
			lc(cf, "CarvedEye", 0.8, 0.8, 0.2, s, 10.7, -1.75, C.carve, f)
		end
		lc(cf, "CarvedNose", 0.5, 0.4, 0.2, 0, 10, -1.75, C.carve, f)
		lc(cf, "CarvedMouth", 2.3, 0.6, 0.2, 0, 9.3, -1.75, C.carve, f)
		lb(cf, "StrawHatBrim", -2.4, 11.8, -2.4, 2.4, 12.2, 2.4, "px_hay", Color3.fromRGB(205, 175, 95), f)
		lb(cf, "StrawHat", -1.3, 12.2, -1.3, 1.3, 13.6, 1.3, "px_hay", Color3.fromRGB(205, 175, 95), f)
	end
	local function bench(x, z, yaw, parent)
		local cf = fr(x, z, yaw)
		for _, s in ipairs({ -1, 1 }) do
			lb(cf, "BenchLeg", s * 3.5 - 0.5, 0, -1.4, s * 3.5 + 0.5, 2, 1.4, "px_dark_oak_planks", nil, parent)
		end
		lb(cf, "BenchSeat", -4, 2, -1.4, 4, 2.7, 1.4, "px_spruce_planks", nil, parent)
		lb(cf, "BenchBack", -4, 2.7, 1, 4, 5, 1.6, "px_spruce_planks", nil, parent)
	end

	-- ---------------------------------------------------------------- YARD_W1: the chicken coop and the sheep pen
	do
		local coop = folder("ChickenCoop", yards)
		spot(-126, -50, 0, "coop")
		local logs, planks, roof = "px_oak_log", "px_spruce_planks", "px_dark_oak_planks"
		box("CoopWall", -134, 0, -56, -118, 8, -54, planks, nil, coop)
		box("CoopWall", -134, 0, -54, -132, 8, -46, planks, nil, coop)
		box("CoopWall", -120, 0, -54, -118, 8, -46, planks, nil, coop)
		for _, x in ipairs({ -133, -119 }) do
			box("CoopPost", x - 1, 0, -46, x + 1, 8, -44, logs, nil, coop)
		end
		box("CoopFrontLow", -132, 0, -46, -125, 2, -44, planks, nil, coop)
		box("CoopLintel", -132, 7, -46, -120, 8, -44, planks, nil, coop)
		for i = 0, 3 do
			decor(cube("CoopBar", -131 + i * 1.7, 4.5, -45, 0.4, 5, 0.4, nil, C.iron, coop))
		end
		decor(cube("CoopBarRail", -128.5, 4.5, -45, 7, 0.4, 0.4, nil, C.iron, coop))
		-- the hen door with a little plank ramp
		local ramp = wedge("CoopRamp", Vector3.new(3.6, 2, 4), at(-122.5, 1, -42) * CFrame.Angles(0, math.pi, 0), nil, nil, coop)
		textured(ramp, planks)
		cube("CoopNest", -129, 1.5, -51, 3, 3, 3, "px_hay", nil, coop)
		cube("CoopNest", -123, 1.5, -51, 3, 3, 3, "px_hay", nil, coop)
		box("CoopRoof", -136, 8, -58, -116, 9.2, -42, roof, nil, coop)
		box("CoopRoof", -134, 9.2, -55, -118, 10.4, -45, roof, nil, coop)
		box("CoopRoofRidge", -132, 10.4, -52, -120, 11.6, -48, roof, nil, coop)
		lantern(V(-126, 6.4, -42.6), coop, false, BY + 8)
		-- the fenced run in front of the coop, the gate east toward the ring path
		fence(-134, -44, -134, -22, coop, 0, "px_planks")
		fence(-134, -22, -106, -22, coop, 0, "px_planks")
		fence(-118, -44, -106, -44, coop, 0, "px_planks")
		fence(-106, -44, -106, -36, coop, 0, "px_planks")
		fence(-106, -28, -106, -22, coop, 0, "px_planks")
		cube("Trough", -110, 0.8, -26, 4, 1.6, 2, planks, nil, coop)
		decor(cube("Feed", -110, 1.65, -26, 3.4, 0.2, 1.4, "px_hay", nil, coop))
		for _, c in ipairs({ { -128, -38, 0.4 }, { -122, -30, 2.1 }, { -116, -36, -1.2 }, { -126, -27, 3.0 }, { -112, -40, 1.5 }, { -118, -26, -2.4 } }) do
			chicken(c[1], c[2], c[3], coop)
		end

		local pen = folder("SheepPen", yards)
		spot(-120, -6, 0, "sheep pen")
		fence(-134, -16, -106, -16, pen, 0, "px_planks")
		fence(-134, -16, -134, 4, pen, 0, "px_planks")
		fence(-134, 4, -106, 4, pen, 0, "px_planks")
		fence(-106, -16, -106, -10, pen, 0, "px_planks")
		fence(-106, -2, -106, 4, pen, 0, "px_planks")
		cube("HayBale", -130, 2, -12, B, B, B, "px_hay", nil, pen)
		cube("HayBale", -130, 2, -8, B, B, B, "px_hay", nil, pen)
		cube("WaterTrough", -112, 1, 0, 6, 2, 2.4, planks, nil, pen)
		local w = decor(cube("TroughWater", -112, 2.02, 0, 5.2, 0.1, 1.6, "px_water", nil, pen))
		w.Transparency = 0.3
		for _, s in ipairs({ { -125, -10, 0.6 }, { -118, -4, 2.4 }, { -126, 0, -1 }, { -114, -11, 1.7 }, { -120, -13, -2.6 } }) do
			sheep(s[1], s[2], s[3], pen)
		end
		haystack(-112, -54, yards)
		sack(-104, -48, yards)
		sack(-104, -45, yards)
	end
	task.wait()

	-- ---------------------------------------------------------------- YARD_W2: stall, beehive tree, shed, well
	do
		local yard = folder("WestYard", yards)
		-- the yellow-white produce stall at the west path entrance, the counter toward the path (north)
		spot(-120, 46, 0, "produce stall")
		local cf = fr(-120, 46, 0)
		stall(cf, {
			w = 3 * B,
			d = 2 * B,
			colA = Color3.fromRGB(240, 200, 50),
			colB = Color3.fromRGB(245, 240, 225),
			goods = { "px_melon", "px_hay", "px_melon" },
			sign = "Урожай",
		}, yard)
		for _, s in ipairs({ -1, 1 }) do
			local p = (cf * CFrame.new(s * 6.6, 6, -4.6)).Position
			lantern(p, yard, false, p.Y + 1.6)
		end
		crate(-109, 0, 44, yard)
		cube("Pumpkin", -109, 6, 44, 3.6, 3.6, 3.6, "px_hay", PUMPKIN, yard)
		cube("Pumpkin", -131, 1.8, 43, 3.6, 3.6, 3.6, "px_hay", PUMPKIN, yard)
		cube("Melon", -131, 1.8, 47, 3.6, 3.6, 3.6, "px_melon", nil, yard)
		sack(-110, 49, yard)

		-- the beehive tree: an oak with three hives on the trunk under the crown
		spot(-130, 72, 0, "beehive tree")
		local bt = tree(-130, 72, 14, yard, "px_hedge", "px_oak_log")
		for _, h in ipairs({ { 4, 0, -math.pi / 2 }, { -4, 0, math.pi / 2 }, { 0, 4, math.pi } }) do
			local hcf = fr(-130 + h[1], 72 + h[2], h[3], 6.2)
			lb(hcf, "Beehive", -1.9, -1.5, -1.9, 1.9, 1.5, 1.9, "px_hay", C.honey, bt)
			lc(hcf, "HiveEntrance", 1.4, 0.5, 0.2, 0, -0.4, -1.95, C.carve, bt)
		end

		-- the tool shed (door west), barrels and a crate by it
		spot(-110, 64, 0, "tool shed")
		local shed = folder("ToolShed", yard)
		local planks, logs, roof = "px_spruce_planks", "px_oak_log", "px_dark_oak_planks"
		box("ShedWall", -118, 0, 58, -102, 8, 60, planks, nil, shed)
		box("ShedWall", -118, 0, 68, -102, 8, 70, planks, nil, shed)
		box("ShedWall", -104, 0, 60, -102, 8, 68, planks, nil, shed)
		box("ShedWall", -118, 0, 60, -116, 8, 62, planks, nil, shed)
		box("ShedWall", -118, 0, 66, -116, 8, 68, planks, nil, shed)
		box("ShedLintel", -118, 6, 62, -116, 8, 66, planks, nil, shed)
		for _, c in ipairs({ { -118, 58 }, { -104, 58 }, { -118, 68 }, { -104, 68 } }) do
			box("ShedPost", c[1] - 0.1, 0, c[2] - 0.1, c[1] + 2.1, 8, c[2] + 2.1, logs, nil, shed)
		end
		decor(cube("ShedWindow", -110, 4.5, 70.05, 3, 2, 0.2, nil, Color3.fromRGB(40, 50, 64), shed))
		box("ShedRoof", -120, 8, 56, -100, 9.2, 72, roof, nil, shed)
		box("ShedRoof", -120, 9.2, 59, -100, 10.4, 69, roof, nil, shed)
		box("ShedRoofRidge", -120, 10.4, 62, -100, 11.6, 66, roof, nil, shed)
		cube("ShedBench", -106, 1.5, 64, 2, 3, 6, planks, nil, shed)
		barrel(-121, 0, 59, shed)
		barrel(-121, 0, 69, shed, "px_hay")
		crate(-107, 0, 75, shed)

		-- compost bins and a haystack
		compost(-108, 84, yard)
		compost(-104, 84, yard)
		haystack(-104, 92, yard)
		for i = 0, 5 do
			flower(-136 + i * 3, 80 + (i % 2) * 2, C.flowers[i % #C.flowers + 1], yard)
		end

		-- the stone well with a roof
		spot(-120, 102, 0, "well")
		local well = folder("Well", yard)
		local wx, wz = -120, 102
		local stone = "px_cobblestone"
		box("WellRim", wx - 6, 0, wz - 6, wx + 6, 4, wz - 2, stone, nil, well)
		box("WellRim", wx - 6, 0, wz + 2, wx + 6, 4, wz + 6, stone, nil, well)
		box("WellRim", wx - 6, 0, wz - 2, wx - 2, 4, wz + 2, stone, nil, well)
		box("WellRim", wx + 2, 0, wz - 2, wx + 6, 4, wz + 2, stone, nil, well)
		local water = decor(box("WellWater", wx - 2, 2.6, wz - 2, wx + 2, 2.8, wz + 2, "px_water", nil, well))
		water.Transparency = 0.2
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				box("WellPost", wx + sx * 5 - 0.6, 4, wz + sz * 5 - 0.6, wx + sx * 5 + 0.6, 11, wz + sz * 5 + 0.6, "px_dark_oak_planks", nil, well)
			end
		end
		box("WellCrank", wx - 5, 9, wz - 0.3, wx + 5, 9.6, wz + 0.3, "px_oak_log", nil, well)
		decor(cube("WellRope", wx, 7.9, wz, 0.25, 2.2, 0.25, nil, Color3.fromRGB(120, 100, 70), well))
		cube("WellBucket", wx, 6.1, wz, 1.4, 1.4, 1.4, "px_spruce_planks", nil, well)
		box("WellRoof", wx - 7, 11, wz - 7, wx + 7, 12.4, wz + 7, "px_cobblestone", nil, well)
		box("WellRoof", wx - 5, 12.4, wz - 5, wx + 5, 13.8, wz + 5, "px_stone_bricks", nil, well)
		box("WellRoof", wx - 3, 13.8, wz - 3, wx + 3, 15.2, wz + 3, "px_stone_bricks", nil, well)
		box("WellRoofTop", wx - 1, 15.2, wz - 1, wx + 1, 16.4, wz + 1, "px_cobblestone", nil, well)
		lantern(V(wx + 4, 9.2, wz + 4), well, false, BY + 11)
		cube("Pumpkin", wx + 9, 1.8, wz - 3, 3.6, 3.6, 3.6, "px_hay", PUMPKIN, yard)
		crate(wx + 9, 0, wz + 2, yard)
	end
	task.wait()

	-- ---------------------------------------------------------------- YARD_S: the pumpkin cart and the farm clutter
	do
		local yard = folder("SouthYard", yards)
		-- the pumpkin cart near the buyer (along z, the handles south)
		spot(34, 136, 0, "pumpkin cart")
		local cart = folder("PumpkinCart", yard)
		local cf = fr(34, 136, math.pi / 2)
		local wood, dark = "px_spruce_planks", "px_dark_oak_planks"
		lb(cf, "CartBed", -5, 2.6, -3, 5, 3.4, 3, wood, nil, cart)
		lb(cf, "CartSide", -5, 3.4, -3, 5, 4.8, -2.4, wood, nil, cart)
		lb(cf, "CartSide", -5, 3.4, 2.4, 5, 4.8, 3, wood, nil, cart)
		lb(cf, "CartEnd", -5, 3.4, -2.4, -4.4, 4.8, 2.4, wood, nil, cart)
		lb(cf, "CartEnd", 4.4, 3.4, -2.4, 5, 4.8, 2.4, wood, nil, cart)
		lc(cf, "CartAxle", 0.6, 0.6, 7.8, 1, 1.8, 0, C.iron, cart)
		for _, s in ipairs({ -1, 1 }) do
			lb(cf, "CartWheel", -0.8, 0, s * 3.6 - 0.4, 2.8, 3.6, s * 3.6 + 0.4, dark, nil, cart)
			lc(cf, "CartHub", 1, 1, 1.0, 1, 1.8, s * 4.1, C.iron, cart)
			lb(cf, "CartHandle", -9, 2.8, s * 2 - 0.3, -5, 3.4, s * 2 + 0.3, wood, nil, cart)
		end
		lb(cf, "CartLeg", -4.6, 0, -0.5, -3.8, 2.6, 0.5, dark, nil, cart)
		lb(cf, "CartPumpkin", -4.2, 3.4, -2.2, 0, 7.6, 2.2, "px_hay", PUMPKIN, cart)
		lb(cf, "CartMelon", 0.4, 3.4, -2, 4.2, 7.2, 1.8, "px_melon", nil, cart)
		lb(cf, "CartPumpkin", -1, 7.6, -1.4, 1.8, 10.4, 1.4, "px_hay", PUMPKIN, cart)
		sack(26, 130, yard)
		sack(26, 133, yard)
		sack(28.5, 131.5, yard)
		crate(42, 0, 130, yard)
		cube("Melon", 42, 6, 130, 3.6, 3.6, 3.6, "px_melon", nil, yard)
		crate(44, 0, 142, yard, nil, 0.3)
		haystack(38, 154, yard)
		-- a wheelbarrow with dirt
		do
			local wcf = fr(28, 164, 0.5)
			lb(wcf, "BarrowTub", -1.6, 1.6, -2.4, 1.6, 3.2, 2, wood, nil, yard)
			decor(lb(wcf, "BarrowDirt", -1.2, 3.1, -2, 1.2, 3.35, 1.6, "px_dirt", FARMLAND, yard))
			lb(wcf, "BarrowWheel", -0.4, 0, -3.6, 0.4, 2, -2, dark, nil, yard)
			for _, s in ipairs({ -1, 1 }) do
				lb(wcf, "BarrowHandle", s * 1.2 - 0.2, 2.6, 2, s * 1.2 + 0.2, 3, 5, wood, nil, yard)
				lb(wcf, "BarrowLeg", s * 1.2 - 0.2, 0, 1.4, s * 1.2 + 0.2, 1.6, 1.8, wood, nil, yard)
			end
		end
		tryTree(34, 182, 12, yard, true)
		compost(44, 196, yard)
		compost(40, 196, yard)
		sack(24, 198, yard)
		-- a flower strip along the south path (both sides)
		for z = 130, 190, 5 do
			if rng:NextNumber() < 0.75 then
				flower(15, z + rng:NextInteger(-1, 1), pick(C.flowers), yard)
			end
			if rng:NextNumber() < 0.6 then
				flower(-15, z + rng:NextInteger(-1, 1), pick(C.flowers), yard)
			end
		end
		-- the scarecrows in the wheat of beds 1 and 3, facing south
		scarecrow(-150, -46, math.pi, yard)
		scarecrow(-110, 138, math.pi, yard)
		-- the south viewpoint: benches at the end of the south path, looking out over the rim
		spot(15, 207, 0, "bench")
		bench(-15, 207, math.pi, yard)
		bench(15, 207, math.pi, yard)
		flower(-20, 206, C.flowers[1], yard)
		flower(20, 206, C.flowers[2], yard)
	end
end
task.wait()

-- ================================================================ 4. borders: hedges, the south wall, trees, haystacks
do
	local edge = folder("Borders", fields)
	local function okHedge(x, z)
		return onIsland(x, z, 10) and not onPath(x, z, 2) and not inStairCorridor(x, z) and zoneOf(x, z) == "fields"
	end
	-- a hedge row: one box per run, some 2-block bumps on it
	local function hedge(axis, a0, a1, c0, c1)
		for _, s in ipairs(runs(axis, a0, a1, { c0 + 0.2, c1 - 0.2 }, okHedge)) do
			if s[2] - s[1] >= 4 then
				if axis == "x" then
					box("Hedge", s[1], 0, c0, s[2], B, c1, "px_hedge", nil, edge)
				else
					box("Hedge", c0, 0, s[1], c1, B, s[2], "px_hedge", nil, edge)
				end
				local a = s[1] + 2
				while a < s[2] - 2 do
					if rng:NextNumber() < 0.3 then
						scube("HedgeBump", axis, a, (c0 + c1) / 2, B * 1.5, B, B, c1 - c0, "px_hedge", nil, edge)
					end
					a += 8
				end
			end
		end
	end
	hedge("z", -76, 204, -211, -208) -- the west rim
	hedge("x", -208, -182, 116, 120) -- between the west fields and the south-west bed
	hedge("x", -170, -156, 116, 120)
	hedge("x", -144, -100, 116, 120)
	hedge("x", -208, -100, -65, -62) -- under the hill
	task.wait()

	-- the low stone wall along the south rim, gaps at the viewpoint and the trees
	local GAPS = { { -20, 20 }, { -176, -164 }, { -116, -104 }, { -62, -50 }, { 64, 76 } }
	local function okWall(x, z)
		if not okHedge(x, z) or not onIsland(x, z + 4, 10) then
			return false
		end
		for _, g in ipairs(GAPS) do
			if x > g[1] and x < g[2] then
				return false
			end
		end
		return true
	end
	for _, s in ipairs(runs("x", -208, 112, { 205 }, okWall)) do
		if s[2] - s[1] >= 4 then
			local v = if rng:NextNumber() < 0.5 then "px_cobblestone" else "px_mossy_cobblestone"
			box("RimWall", s[1], 0, 205, s[2], 3, 208, v, nil, edge)
		end
	end
	for _, x in ipairs({ -170, -110, -56, 70 }) do
		tryTree(x, 207, 11, edge, x % 3 == 0)
	end
	-- trees between the fields and under the hill
	tryTree(-176, 118, 12, edge, true)
	tryTree(-150, 118, 11, edge, false)
	tryTree(-124, -70, 12, edge, false)
	tryTree(-200, -70, 11, edge, true)
	tryTree(-52, -74, 11, edge, false)
	tryTree(52, -74, 12, edge, true)
	-- haystacks and bushes on the free strips
	for _, h in ipairs({ { -36, -74 }, { 40, -75 } }) do
		if freeGround(h[1], h[2], 2) and zoneOf(h[1], h[2]) == "fields" then
			box("Haystack", h[1] - 4, 0, h[2] - 2, h[1] + 4, 4, h[2] + 2, "px_hay", nil, edge)
		end
	end
	for _, b in ipairs({ { -96, 40 }, { -96, 8 }, { 96, 36 }, { 96, 12 }, { -96, -60 }, { -24, 120 } }) do
		if freeGround(b[1], b[2], 0) and zoneOf(b[1], b[2]) == "fields" then
			cube("Bush", b[1], 2, b[2], B, B, B, "px_hedge", nil, edge)
		end
	end
end

print(("[build-farm] fields: %d parts"):format(count - startCount))
