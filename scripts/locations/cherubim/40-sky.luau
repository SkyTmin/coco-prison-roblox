--!nocheck
-- ================================================================ cherubim: the sky (everything off the main island)
-- 1. THE RINGS («колесо в колесе»): three giant tilted golden hoops round the island, each a circle of 11-stud
--    rotated box segments (a gold band 2 blocks wide × 1 thick with honey patches, a deep-gold spine on the outer
--    face and stepped edge blocks on the inner face), observer eyes (a dark iron face with a light slit in a gold
--    frame) every 4th segment, on the outer and inner face in turn, and 10 lanterns on chains under each.
--      RingA  R 185, centre (0, 108, 0),   tilted 28° about x  (north end high, over the rotunda at y ≈ 192)
--      RingB  R 170, centre (0, 106, -40), tilted 30° about z  (west end low)
--      RingC  R 200, centre (0, 110, 10),  tilted 26° about the x = z diagonal
--    Lowest centre-line points ≈ y 21..22 (band corners ≥ y 16); no segment below y 156 comes within 56 studs
--    (horizontally) of the rotunda's dome centre (0, -112) (checked offline and printed at build time). All decor.
-- 2. The golden bridges over BRIDGES: the gap measured from core's cells along z -20, a gold deck z -32..-8 (top
--    y 0.1) 16 studs onto both islands, a quartz runner, quartz balustrades over the gap only (4 blocks clear
--    between them), a stepped quartz keel under it, gold lantern posts at both ends.
-- 3. The islets WEST_ISLE / EAST_ISLE: an open 5×5-block pavilion at the centre (quartz columns, a stepped gold dome,
--    a lantern turret, a gold halo above; a harp in the west one, a trumpet angel in the east one), quartz benches,
--    gold planters and lantern posts round it; the walk z -34..-6 from the landing to the pavilion stays clear.
-- 4. White quartz stalactites with gold tips under every island cell (core's 8-stud grid and rockDepth), denser on
--    the rim; none under the bridge ends and the south causeway.
-- 5. Floating quartz-and-gold islets (stepped cones) round the cluster with a trumpet angel, a halo on a post, a
--    harp, a lantern or a small gold dome on top: 24+ studs off every island, 17+ from every ring segment, out of
--    the bridge corridors and the south causeway.
-- 6. White wool clouds: a ring round the island just under the rim, a layer far under the islands, a few higher up.
local sky = folder("Sky")
local c0 = count
local OFF = Vector3.new(BX, BY, BZ)
local lights = 0
local ringPts = {} -- the rings' segment centres (local), for the islets and the clouds
local CREAM = Color3.fromRGB(236, 226, 196) -- core's rockLowTint
local SKIN = Color3.fromRGB(250, 228, 196)
local STRING = Color3.fromRGB(96, 96, 104)

-- the island cell (core's 8-stud grid over x -296..296, z -200..200) holding a point: its island and centre
local function cellLand(x, z)
	if x < -296 or x >= 296 or z < -200 or z >= 200 then
		return nil
	end
	local cx = -296 + 8 * math.floor((x + 296) / 8) + 4
	local cz = -200 + 8 * math.floor((z + 200) / 8) + 4
	return isleOf(cx, cz), cx, cz
end
-- core's rockDepth (10-core is wrapped in its own do … end, so it is replicated here); call it on a land cell
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local c = if isle == "main" then ISLAND elseif isle == "west" then WEST_ISLE else EAST_ISLE
	local deep = if isle == "main" then 140 else 56
	local rr = math.clamp(math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r, 0, 1)
	local d = 16 + (1 - rr) ^ 1.15 * deep
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
-- Rodrigues: v turned by t radians about the unit axis a (right-handed)
local function rotv(v, a, t)
	local c, s = math.cos(t), math.sin(t)
	return v * c + a:Cross(v) * s + a * a:Dot(v) * (1 - c)
end
-- an oriented textured box: pos local, X along `right`, Y along `up`; always decor
local function obox(name, pos, right, up, size, variant, tint, parent)
	local p = part(name, size, CFrame.fromMatrix(pos + OFF, right, up), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return decor(p)
end
-- a textured box in a frame cf (world)
local function sbox(name, cf, size, variant, tint, parent)
	local p = part(name, size, cf, tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a block lantern (iron base and cap round a glowstone core, s studs) at a world point; on a chain up to hangTop
-- (world y) when given; lit = a PointLight (at most 20 in this part)
local function lamp(pos, s, lit, parent, hangTop)
	local iron = Color3.fromRGB(48, 46, 44)
	decor(
		part(
			"LampBase",
			Vector3.new(1.3 * s, 0.3 * s, 1.3 * s),
			CFrame.new(pos - Vector3.new(0, 0.62 * s, 0)),
			iron,
			Enum.Material.Metal,
			parent
		)
	)
	local core = decor(
		sbox("LampGlow", CFrame.new(pos), Vector3.new(s, s, s), "px_glowstone", LIGHT, parent)
	)
	decor(
		part(
			"LampCap",
			Vector3.new(1.3 * s, 0.3 * s, 1.3 * s),
			CFrame.new(pos + Vector3.new(0, 0.62 * s, 0)),
			iron,
			Enum.Material.Metal,
			parent
		)
	)
	local top = pos.Y + 0.77 * s
	if hangTop and hangTop > top + 0.2 then
		decor(
			part(
				"Chain",
				Vector3.new(math.max(0.3, 0.22 * s), hangTop - top, math.max(0.3, 0.22 * s)),
				CFrame.new(pos.X, (hangTop + top) / 2, pos.Z),
				Color3.fromRGB(60, 58, 54),
				Enum.Material.Metal,
				parent
			)
		)
	end
	if lit and lights < 20 then
		lights += 1
		light(core, 34, 1.4, LIGHT)
	end
	return core
end
-- a flat gold halo (an octagon of 8 boxes) of radius r round a world point
local function halo(pos, r, parent, thick)
	thick = thick or 1
	local len = 2 * r * math.sin(math.pi / 8) + 0.4 * thick
	for i = 0, 7 do
		local a = i * math.pi / 4
		local c = pos + Vector3.new(math.cos(a), 0, math.sin(a)) * r * math.cos(math.pi / 8)
		decor(
			sbox(
				"Halo",
				CFrame.new(c) * CFrame.Angles(0, -a, 0),
				Vector3.new(thick, 0.8 * thick, len),
				"px_gold_block",
				GOLD,
				parent
			)
		)
	end
end
-- a trumpet angel on a pedestal: cf = the base centre on the ground (world), facing cf's look vector
local function angel(cf, parent, solid)
	local function d(p)
		return if solid then p else decor(p)
	end
	d(
		sbox(
			"AngelPedestal",
			cf * CFrame.new(0, 1, 0),
			Vector3.new(6, 2, 6),
			"px_smooth_stone",
			QUARTZ,
			parent
		)
	)
	d(
		sbox(
			"AngelRobe",
			cf * CFrame.new(0, 5, 0),
			Vector3.new(4, 6, 3),
			"px_white_wool",
			QUARTZ,
			parent
		)
	)
	decor(
		sbox(
			"AngelHem",
			cf * CFrame.new(0, 2.6, 0),
			Vector3.new(4.4, 1, 3.4),
			"px_gold_block",
			GOLD,
			parent
		)
	)
	decor(
		sbox(
			"AngelChest",
			cf * CFrame.new(0, 9.5, 0),
			Vector3.new(4, 3, 3),
			"px_gold_block",
			GOLD,
			parent
		)
	)
	decor(
		sbox(
			"AngelHead",
			cf * CFrame.new(0, 12.5, 0),
			Vector3.new(3, 3, 3),
			"px_smooth_stone",
			SKIN,
			parent
		)
	)
	decor(
		sbox(
			"AngelHair",
			cf * CFrame.new(0, 14.3, 0.2),
			Vector3.new(3.2, 1, 3.2),
			"px_gold_block",
			GOLD,
			parent
		)
	)
	for _, sd in ipairs({ -1, 1 }) do
		decor(
			sbox(
				"AngelWing",
				cf * CFrame.new(sd * 3, 9.5, 2.6) * CFrame.Angles(0, -sd * 0.5, 0),
				Vector3.new(1, 8, 6),
				"px_white_wool",
				QUARTZ,
				parent
			)
		)
		decor(
			sbox(
				"AngelWingTip",
				cf * CFrame.new(sd * 5, 13.5, 5.2) * CFrame.Angles(0, -sd * 0.5, 0),
				Vector3.new(1, 4, 4),
				"px_white_wool",
				QUARTZ,
				parent
			)
		)
	end
	decor(
		sbox(
			"AngelArm",
			cf * CFrame.new(1.4, 11.3, -2.2),
			Vector3.new(1.2, 1.2, 3.4),
			"px_white_wool",
			QUARTZ,
			parent
		)
	)
	local horn = cf * CFrame.new(0.4, 12.9, -4) * CFrame.Angles(0.3, 0, 0)
	decor(sbox("Trumpet", horn, Vector3.new(0.8, 0.8, 5.6), "px_gold_block", GOLD_DEEP, parent))
	decor(
		sbox(
			"TrumpetBell",
			horn * CFrame.new(0, 0, -3.1),
			Vector3.new(2.2, 2.2, 1),
			"px_gold_block",
			GOLD,
			parent
		)
	)
	for _, e in ipairs({
		{ 0, -1.8, 4, 0.6 },
		{ 0, 1.8, 4, 0.6 },
		{ -1.8, 0, 0.6, 4 },
		{ 1.8, 0, 0.6, 4 },
	}) do
		decor(
			sbox(
				"AngelHalo",
				cf * CFrame.new(e[1], 16.2, e[2]),
				Vector3.new(e[3], 0.5, e[4]),
				"px_gold_block",
				GOLD,
				parent
			)
		)
	end
end
-- a harp of gold and iron strings: cf = the base centre on the ground (world)
local function harp(cf, parent, solid)
	local base = sbox(
		"HarpBase",
		cf * CFrame.new(0, 1, 0),
		Vector3.new(8, 2, 3),
		"px_gold_block",
		GOLD_DEEP,
		parent
	)
	local pillar = sbox(
		"HarpPillar",
		cf * CFrame.new(-3, 8, 0),
		Vector3.new(2, 12, 2),
		"px_white_stone_bricks",
		QUARTZ,
		parent
	)
	if not solid then
		decor(base)
		decor(pillar)
	end
	-- the neck steps down from the pillar's top to the front
	local arms = { { -1, 13 }, { 1, 11.5 }, { 3, 10 } }
	for _, a in ipairs(arms) do
		decor(
			sbox(
				"HarpNeck",
				cf * CFrame.new(a[1], a[2], 0),
				Vector3.new(2, 2, 2),
				"px_gold_block",
				GOLD,
				parent
			)
		)
	end
	for i, x in ipairs({ -1.5, -0.5, 0.5, 1.5, 2.5, 3.5 }) do
		local topY = arms[math.clamp(math.floor((x + 2) / 2) + 1, 1, 3)][2] - 1
		local h = topY - 2
		decor(
			part(
				"HarpString",
				Vector3.new(0.3, h, 0.3),
				cf * CFrame.new(x, 2 + h / 2, if i % 2 == 0 then 0.3 else -0.3),
				STRING,
				Enum.Material.Metal,
				parent
			)
		)
	end
end
-- a gold lantern post: a quartz foot, a gold shaft, a lantern on top
local function goldLampPost(x, y, z, parent, lit)
	box("LampFoot", x - 1.2, y, z - 1.2, x + 1.2, y + 1, z + 1.2, "px_smooth_stone", QUARTZ, parent)
	box(
		"LampShaft",
		x - 0.6,
		y + 1,
		z - 0.6,
		x + 0.6,
		y + 8,
		z + 0.6,
		"px_gold_block",
		GOLD_DEEP,
		parent
	)
	lamp(V(x, y + 9.1, z), 1.6, lit, parent)
end
-- the walkable ways through the air: x0, x1, z0, z1, y0, y1
local CORRIDORS = { { -32, 32, 176, 320, -90, 30 } } -- the south causeway (the plaza part)
for _, b in ipairs(BRIDGES) do
	table.insert(CORRIDORS, { b[1] - 16, b[3] + 16, b[2] - 16, b[4] + 16, -40, 30 })
end
local function inCorridor(x0, x1, z0, z1, y0, y1)
	for _, c in ipairs(CORRIDORS) do
		if
			x1 >= c[1]
			and x0 <= c[2]
			and z1 >= c[3]
			and z0 <= c[4]
			and y1 >= c[5]
			and y0 <= c[6]
		then
			return true
		end
	end
	return false
end
-- no island cell within half + pad studs (horizontally) of (x, z)
local function clearOfIslands(x, z, half, pad)
	if cellLand(x, z) ~= nil then
		return false
	end
	local e = half + pad
	local n = math.max(1, math.ceil(2 * e / 8))
	for i = 0, n do
		for j = 0, n do
			if cellLand(x - e + 2 * e * i / n, z - e + 2 * e * j / n) ~= nil then
				return false
			end
		end
	end
	return true
end
-- the box x0..x1, y0..y1, z0..z1 stays `gap` studs off every ring segment centre
local function clearOfRings(x0, x1, y0, y1, z0, z1, gap)
	for _, p in ipairs(ringPts) do
		local dx = math.max(x0 - p.X, 0, p.X - x1)
		local dy = math.max(y0 - p.Y, 0, p.Y - y1)
		local dz = math.max(z0 - p.Z, 0, p.Z - z1)
		if dx * dx + dy * dy + dz * dz < gap * gap then
			return false
		end
	end
	return true
end
local taken = {} -- floating islets: { x, z, half, y0, y1 }

-- ================================================================ 1. the three golden rings
do
	local rf = folder("Rings", sky)
	local RINGS = {
		{ name = "RingA", R = 185, c = Vector3.new(0, 108, 0), tilt = 28, az = 0 },
		{ name = "RingB", R = 170, c = Vector3.new(0, 106, -40), tilt = 30, az = 90 },
		{ name = "RingC", R = 200, c = Vector3.new(0, 110, 10), tilt = 26, az = 45 },
	}
	local SEG = 11
	for ri, r in ipairs(RINGS) do
		local f = folder(r.name, rf)
		local rs = count
		local ax = Vector3.new(math.cos(math.rad(r.az)), 0, math.sin(math.rad(r.az)))
		local u = rotv(Vector3.xAxis, ax, math.rad(r.tilt))
		local v = rotv(Vector3.zAxis, ax, math.rad(r.tilt))
		local nrm = u:Cross(v).Unit
		local n = math.floor(2 * math.pi * r.R / SEG + 0.5)
		local L = 2 * r.R * math.sin(math.pi / n) + 0.8
		local low, clear = math.huge, math.huge
		local cands = {}
		local eyes = 0
		for k = 0, n - 1 do
			local th = (k + 0.5) / n * 2 * math.pi
			local rad = u * math.cos(th) + v * math.sin(th)
			local p = r.c + rad * r.R
			table.insert(ringPts, p)
			low = math.min(low, p.Y)
			if p.Y < 156 then
				clear = math.min(clear, math.sqrt((p.X - ROTUNDA.x) ^ 2 + (p.Z - ROTUNDA.z) ^ 2))
			end
			-- the band: gold, raw-gold honey patches where the noise says so
			local patch = n2(p.X + ri * 97, p.Z, 3.3 + ri, 0.03) > 0.28
			obox(
				"RingBand",
				p,
				nrm,
				rad,
				Vector3.new(8, 4, L),
				if patch then "px_smooth_stone" else "px_gold_block",
				if patch then HONEY else GOLD,
				f
			)
			-- the spine on the outer face
			obox(
				"RingSpine",
				p + rad * 2.6,
				nrm,
				rad,
				Vector3.new(4, 1.4, L),
				"px_gold_block",
				GOLD_DEEP,
				f
			)
			-- stepped edge blocks on the inner face, high and low edge in turn
			if k % 2 == 0 then
				local e = if k % 4 == 0 then 2.5 else -2.5
				obox(
					"RingStep",
					p - rad * 2.5 + nrm * e,
					nrm,
					rad,
					Vector3.new(3, 1.2, L * 0.6),
					if (k // 2) % 3 == 0 then "px_smooth_stone" else "px_gold_block",
					if (k // 2) % 3 == 0 then HONEY else GOLD_DEEP,
					f
				)
			end
			-- an observer eye every 4th segment, on the outer and the inner face in turn
			if k % 4 == 1 then
				eyes += 1
				local sd = if eyes % 2 == 0 then 1 else -1
				local face = rad * sd
				obox(
					"EyeFrame",
					p + face * 2.9,
					nrm,
					rad,
					Vector3.new(10, 1.8, 10),
					"px_gold_block",
					GOLD_DEEP,
					f
				)
				obox(
					"EyeFace",
					p + face * 3.95,
					nrm,
					rad,
					Vector3.new(7, 0.5, 7),
					"px_iron_block",
					IRON,
					f
				)
				obox(
					"EyeSlit",
					p + face * 4.2,
					nrm,
					rad,
					Vector3.new(1.6, 0.4, 5),
					"px_smooth_stone",
					Color3.fromRGB(214, 214, 220),
					f
				)
				obox(
					"EyePupil",
					p + face * 4.35,
					nrm,
					rad,
					Vector3.new(1.2, 0.4, 1.4),
					"px_iron_block",
					IRON,
					f
				)
			elseif p.Y >= 44 and p.Y <= 150 then
				table.insert(cands, { p = p, rad = rad })
			end
			if k % 40 == 39 then
				task.wait()
			end
		end
		-- 10 lanterns on chains from the band's lowest edge, 2 of them lit
		local hung = 0
		for i = 1, 10 do
			local cnd = cands[math.floor((i - 0.5) * #cands / 10) + 1]
			if cnd then
				local p = cnd.p
				local bottom = p.Y - (4 * math.abs(nrm.Y) + 2 * math.abs(cnd.rad.Y))
				local len = 5 + (i * 3) % 7
				lamp(V(p.X, bottom - len, p.Z), 2.2, i == 3 or i == 8, f, BY + bottom + 1)
				hung += 1
			end
		end
		print(
			("[build-cherubim] sky: %s R %d — lowest centre-line y %.1f, nearest to the dome below y 156: %.1f studs, %d eyes, %d lanterns, %d parts"):format(
				r.name,
				r.R,
				low,
				clear,
				eyes,
				hung,
				count - rs
			)
		)
		task.wait()
	end
end

-- ================================================================ 2. the golden bridges (the gap measured first)
local BRIDGE_ENDS = {} -- [1] west, [2] east: { landing = x of the deck end on the islet }
do
	local bf = folder("Bridges", sky)
	for bi, b in ipairs(BRIDGES) do
		local f = folder(if bi == 1 then "WestBridge" else "EastBridge", bf)
		local z0, z1 = b[2], b[4]
		local zm = (z0 + z1) / 2
		local lo, hi = math.min(b[1], b[3]), math.max(b[1], b[3])
		-- the gap: the longest run of open sky along the centre line (core's cells), 1 stud at a time
		local ga, gb, best, runA = nil, nil, -1, nil
		for xs = lo - 24, hi + 24 do
			if cellLand(xs + 0.5, zm) == nil then
				runA = runA or xs
				if xs + 1 - runA > best then
					best, ga, gb = xs + 1 - runA, runA, xs + 1
				end
			else
				runA = nil
			end
		end
		if not ga then
			ga, gb = lo + 8, hi - 8
		end
		local xa, xb = math.min(lo, ga - 16), math.max(hi, gb + 16)
		BRIDGE_ENDS[bi] = { landing = if bi == 1 then xa else xb, gap = { ga, gb } }
		-- the deck: 6 blocks (4 clear + a balustrade each side), gold, a quartz runner down the middle
		box("BridgeDeck", xa, 0.1 - B, z0 - 4, xb, 0.1, z1 + 4, "px_gold_block", GOLD, f)
		decor(
			box(
				"BridgeRunner",
				ga - 8,
				0.1,
				zm - 2,
				gb + 8,
				0.16,
				zm + 2,
				"px_smooth_stone",
				QUARTZ,
				f
			)
		)
		-- the stepped keel under the gap: deep at the island faces, thin in the middle, a gold course at the bottom
		local under = 0.1 - B
		local nb = math.max(1, math.floor((gb - ga) / B + 0.5))
		local runs = {}
		for k = 0, nb - 1 do
			local t = (k + 0.5) / nb
			local dep = 1 + math.floor((2 * t - 1) ^ 2 * 5 + 0.5)
			local last = runs[#runs]
			if last and last[3] == dep then
				last[2] = ga + (k + 1) * B
			else
				table.insert(runs, { ga + k * B, ga + (k + 1) * B, dep })
			end
		end
		runs[1][1] -= B
		runs[#runs][2] += B
		for _, r in ipairs(runs) do
			if r[3] > 1 then
				decor(
					box(
						"BridgeKeel",
						r[1],
						under - (r[3] - 1) * B,
						z0,
						r[2],
						under,
						z1,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
				)
			end
			decor(
				box(
					"BridgeKeelGold",
					r[1],
					under - r[3] * B,
					z0 + 2,
					r[2],
					under - (r[3] - 1) * B,
					z1 - 2,
					"px_gold_block",
					GOLD_DEEP,
					f
				)
			)
		end
		lamp(V((ga + gb) / 2, under - 2 * B - 4, zm), 1.8, false, f, BY + under - B)
		-- quartz balustrades over the gap only (open at the ends): a plinth, posts every 2 blocks, a gold rail
		for si, e in ipairs({ { z0 - 4, z0 }, { z1, z1 + 4 } }) do
			box("BalustradePlinth", ga, 0.1, e[1], gb, 1.1, e[2], "px_smooth_stone", QUARTZ, f)
			local np = math.max(1, math.floor((gb - ga) / (2 * B)))
			for k = 0, np do
				local px = ga + (gb - ga - B) * k / np
				box(
					"BalustradePost",
					px,
					1.1,
					e[1],
					px + B,
					4.1,
					e[2],
					"px_white_stone_bricks",
					QUARTZ,
					f
				)
			end
			box(
				"BalustradeRail",
				ga,
				4.1,
				e[1] - 0.3,
				gb,
				5.1,
				e[2] + 0.3,
				"px_gold_block",
				GOLD_DEEP,
				f
			)
			-- gold lantern posts at both ends, one lit per end
			for gi, px in ipairs({ ga - B, gb }) do
				box(
					"BridgePostFoot",
					px - 0.5,
					0.1,
					e[1] - 0.5,
					px + B + 0.5,
					1.1,
					e[2] + 0.5,
					"px_smooth_stone",
					QUARTZ,
					f
				)
				box("BridgePost", px, 1.1, e[1], px + B, 9.1, e[2], "px_gold_block", GOLD_DEEP, f)
				decor(
					box(
						"BridgePostCap",
						px - 0.5,
						9.1,
						e[1] - 0.5,
						px + B + 0.5,
						10.1,
						e[2] + 0.5,
						"px_smooth_stone",
						QUARTZ,
						f
					)
				)
				lamp(V(px + 2, 11.6, (e[1] + e[2]) / 2), 2, si == gi, f)
			end
		end
	end
end
task.wait()

-- ================================================================ 3. the islets: the pavilions, benches, planters
do
	local isf = folder("Islets", sky)
	for ii, isle in ipairs({ WEST_ISLE, EAST_ISLE }) do
		local name = if ii == 1 then "west" else "east"
		local tb = if ii == 1 then 1 else -1 -- toward the bridge (and the main island)
		local f = folder(if ii == 1 then "WestPavilion" else "EastPavilion", isf)
		local px, pz = isle.x, isle.z
		-- the plinth (a low slab, walkable) with a gold inlay
		box(
			"PavilionPlinth",
			px - 12,
			0,
			pz - 12,
			px + 12,
			0.6,
			pz + 12,
			"px_smooth_stone",
			QUARTZ,
			f
		)
		decor(
			box(
				"PavilionInlay",
				px - 6,
				0.6,
				pz - 6,
				px + 6,
				0.66,
				pz + 6,
				"px_gold_block",
				GOLD,
				f
			)
		)
		-- four quartz columns with gold bases and capitals (the pavilion is 5×5 blocks, open on every side)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local cx, cz = px + sx * 8, pz + sz * 8
				box(
					"ColumnBase",
					cx - 2.5,
					0.6,
					cz - 2.5,
					cx + 2.5,
					1.6,
					cz + 2.5,
					"px_gold_block",
					GOLD_DEEP,
					f
				)
				box(
					"Column",
					cx - 2,
					1.6,
					cz - 2,
					cx + 2,
					15.6,
					cz + 2,
					"px_white_stone_bricks",
					QUARTZ,
					f
				)
				box(
					"ColumnCap",
					cx - 2.5,
					15.6,
					cz - 2.5,
					cx + 2.5,
					16.6,
					cz + 2.5,
					"px_gold_block",
					GOLD_DEEP,
					f
				)
			end
		end
		-- the entablature, the ceiling, the cornice
		box(
			"Entablature",
			px - 10,
			16.6,
			pz - 10,
			px + 10,
			20.6,
			pz - 6,
			"px_gold_block",
			GOLD_DEEP,
			f
		)
		box(
			"Entablature",
			px - 10,
			16.6,
			pz + 6,
			px + 10,
			20.6,
			pz + 10,
			"px_gold_block",
			GOLD_DEEP,
			f
		)
		box(
			"Entablature",
			px - 10,
			16.6,
			pz - 6,
			px - 6,
			20.6,
			pz + 6,
			"px_gold_block",
			GOLD_DEEP,
			f
		)
		box(
			"Entablature",
			px + 6,
			16.6,
			pz - 6,
			px + 10,
			20.6,
			pz + 6,
			"px_gold_block",
			GOLD_DEEP,
			f
		)
		box("Ceiling", px - 6, 19.6, pz - 6, px + 6, 20.6, pz + 6, "px_smooth_stone", QUARTZ, f)
		box("Cornice", px - 11, 20.6, pz - 11, px + 11, 21.6, pz + 11, "px_smooth_stone", QUARTZ, f)
		-- the stepped gold dome
		box("Dome", px - 9, 21.6, pz - 9, px + 9, 25.6, pz + 9, "px_gold_block", GOLD, f)
		decor(
			box(
				"DomeBand",
				px - 9.3,
				24.6,
				pz - 9.3,
				px + 9.3,
				25.6,
				pz + 9.3,
				"px_smooth_stone",
				HONEY,
				f
			)
		)
		box("Dome", px - 7, 25.6, pz - 7, px + 7, 29.6, pz + 7, "px_gold_block", GOLD, f)
		box("Dome", px - 5, 29.6, pz - 5, px + 5, 33.6, pz + 5, "px_gold_block", GOLD_DEEP, f)
		-- the lantern turret: four gold posts round a glowstone core, a cap, a finial; a halo floats above
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				decor(
					box(
						"TurretPost",
						px + sx * 3 - 0.6,
						33.6,
						pz + sz * 3 - 0.6,
						px + sx * 3 + 0.6,
						38.6,
						pz + sz * 3 + 0.6,
						"px_gold_block",
						GOLD_DEEP,
						f
					)
				)
			end
		end
		local glow = decor(
			box(
				"TurretGlow",
				px - 1.5,
				34.1,
				pz - 1.5,
				px + 1.5,
				38.1,
				pz + 1.5,
				"px_glowstone",
				LIGHT,
				f
			)
		)
		if lights < 20 then
			lights += 1
			light(glow, 40, 1.4, LIGHT)
		end
		decor(
			box(
				"TurretCap",
				px - 3.6,
				38.6,
				pz - 3.6,
				px + 3.6,
				40.1,
				pz + 3.6,
				"px_gold_block",
				GOLD,
				f
			)
		)
		decor(
			box(
				"TurretFinial",
				px - 1,
				40.1,
				pz - 1,
				px + 1,
				43.1,
				pz + 1,
				"px_gold_block",
				GOLD_DEEP,
				f
			)
		)
		halo(V(px, 46.5, pz), 6, f, 1.2)
		-- inside: a harp (west) or a trumpet angel (east) facing the bridge, two lanterns from the ceiling
		local cf = at(px, 0.6, pz)
			* CFrame.Angles(0, if tb > 0 then -math.pi / 2 else math.pi / 2, 0)
		if ii == 1 then
			harp(cf, f, true)
		else
			angel(cf, f, true)
		end
		for k, sz in ipairs({ -1, 1 }) do
			local lp = V(px + tb * 5, 13.5, pz + sz * 4.5)
			lamp(lp, 1.6, k == 1, f, BY + 19.6)
		end
		-- round it: benches, gold planters, lantern posts; the walk (z pz ± 14 toward the bridge) stays clear
		local landing = BRIDGE_ENDS[ii].landing
		local wx0, wx1 = math.min(px, landing - tb * 8), math.max(px, landing - tb * 8)
		local function free(x, z, half)
			if isleOf(x, z, half + 4) ~= name then
				return false
			end
			if x + half >= wx0 and x - half <= wx1 and math.abs(z - pz) - half < 14 then
				return false
			end
			return math.abs(x - px) - half >= 14 or math.abs(z - pz) - half >= 14
		end
		for _, sz in ipairs({ -1, 1 }) do
			-- a quartz bench facing the pavilion
			local bx, bz = px, pz + sz * 24
			if free(bx, bz, 4) then
				box(
					"BenchSeat",
					bx - 4,
					1.8,
					bz - 1.5,
					bx + 4,
					3,
					bz + 1.5,
					"px_smooth_stone",
					QUARTZ,
					f
				)
				for _, lx in ipairs({ -3, 3 }) do
					box(
						"BenchLeg",
						bx + lx - 1,
						0,
						bz - 1.5,
						bx + lx + 1,
						1.8,
						bz + 1.5,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
				end
				box(
					"BenchBack",
					bx - 4,
					3,
					bz + sz * 1.5 - 0.5,
					bx + 4,
					5.4,
					bz + sz * 1.5 + 0.5,
					"px_smooth_stone",
					QUARTZ,
					f
				)
			end
		end
		for _, s in ipairs({ { -20, -20 }, { -20, 20 }, { 14, -22 }, { 14, 22 }, { -27, 0 } }) do
			-- a gold planter with a hedge and yellow flowers
			local x, z = px + tb * s[1], pz + s[2]
			if free(x, z, 2) then
				box("Planter", x - 2, 0, z - 2, x + 2, 3.6, z + 2, "px_gold_block", GOLD_DEEP, f)
				decor(
					box(
						"PlanterHedge",
						x - 1.7,
						3.6,
						z - 1.7,
						x + 1.7,
						4.4,
						z + 1.7,
						"px_hedge",
						nil,
						f
					)
				)
				decor(
					cube(
						"PlanterFlower",
						x + rng:NextInteger(-1, 1) * 0.6,
						5.1,
						z,
						1.4,
						1.4,
						1.4,
						"px_yellow_wool",
						nil,
						f
					)
				)
			end
		end
		for _, s in ipairs({ { 12, -17 }, { 12, 17 }, { -16, -18 }, { -16, 18 } }) do
			local x, z = px + tb * s[1], pz + s[2]
			if free(x, z, 1.5) then
				goldLampPost(x, 0, z, f, false)
			end
		end
	end
end
task.wait()

-- ================================================================ 4. quartz stalactites under every island
do
	local hang = folder("Stalactites", sky)
	local s0 = count
	local C = 8
	local cols = 0
	local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local function skip(cx, cz)
		if cx >= -32 and cx <= 32 and cz >= 160 then
			return true -- the south causeway
		end
		for _, b in ipairs(BRIDGES) do
			if inRect(cx, cz, b, 16) then
				return true
			end
		end
		return false
	end
	-- one column s studs square from `top` down `len`, a gold tip block under it when `tip`
	local function column(x0, z0, s, top, len, tip)
		local r = rng:NextNumber()
		local v = if r < 0.55 then "px_white_stone_bricks" else "px_smooth_stone"
		decor(box("Stalactite", x0, top - len, z0, x0 + s, top, z0 + s, v, QUARTZ, hang))
		if tip then
			local ts = math.min(s, B)
			local tx, tz = x0 + (s - ts) / 2, z0 + (s - ts) / 2
			decor(
				box(
					"StalactiteTip",
					tx,
					top - len - B,
					tz,
					tx + ts,
					top - len,
					tz + ts,
					"px_gold_block",
					GOLD_DEEP,
					hang
				)
			)
		end
		cols += 1
	end
	for z = -200, 200 - C, C do
		for x = -296, 296 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			if cellLand(cx, cz) ~= nil and not skip(cx, cz) and count - s0 < 820 then
				local bottom = -B - rockDepth(cx, cz)
				local outX, outZ, rim = 0, 0, false
				for _, d in ipairs(DIRS4) do
					if cellLand(cx + d[1] * C, cz + d[2] * C) == nil then
						rim = true
						outX += d[1]
						outZ += d[2]
					end
				end
				if rng:NextNumber() < (if rim then 0.58 else 0.075) then
					if not rim then
						-- a fat 2×2 column, a 1×1 under one quarter, a gold tip
						local len = rng:NextInteger(3, 7) * B
						column(x, z, 2 * B, bottom + 2, len + 2, false)
						column(
							x + rng:NextInteger(0, 1) * B,
							z + rng:NextInteger(0, 1) * B,
							B,
							bottom - len,
							rng:NextInteger(1, 4) * B,
							true
						)
					else
						-- a 1×1 column on the outer quarter of a rim cell, sometimes a shorter one beside it
						local qx = if outX > 0
							then 1
							elseif outX < 0 then 0
							else rng:NextInteger(0, 1)
						local qz = if outZ > 0
							then 1
							elseif outZ < 0 then 0
							else rng:NextInteger(0, 1)
						local len = rng:NextInteger(2, 10)
						column(x + qx * B, z + qz * B, B, bottom + 2, len * B + 2, true)
						if len > 4 and rng:NextNumber() < 0.3 then
							local q2x, q2z = 1 - qx, qz
							if outX == 0 then
								q2x, q2z = qx, 1 - qz
							end
							column(
								x + q2x * B,
								z + q2z * B,
								B,
								bottom + 2,
								rng:NextInteger(1, len - 3) * B + 2,
								true
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
	print(("[build-cherubim] sky: stalactites %d, %d parts"):format(cols, count - s0))
end
task.wait()

-- ================================================================ 5. floating quartz-and-gold islets
do
	local fly = folder("FloatingIslets", sky)
	local f0 = count
	local function findSpot(half, down, up, yMin, yMax)
		for attempt = 1, 500 do
			if attempt % 100 == 0 then
				task.wait()
			end
			local x, z = rng:NextNumber(-420, 420), rng:NextNumber(-360, 360)
			local y = rng:NextNumber(yMin, yMax)
			local ok = not inCorridor(x - half, x + half, z - half, z + half, y - down, y + up)
				and clearOfIslands(x, z, half, 24)
				and clearOfRings(x - half, x + half, y - down, y + up, z - half, z + half, 17)
			if ok then
				for _, t in ipairs(taken) do
					local dh = math.sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2)
					if dh < t[3] + half + 10 and y + up + 8 > t[4] and y - down - 8 < t[5] then
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
	-- a small gold dome on four quartz posts (3×3 blocks) with a lantern inside
	local function miniDome(x, y, z, f, lit)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				decor(
					box(
						"DomePost",
						x + sx * 4 - 2,
						y,
						z + sz * 4 - 2,
						x + sx * 4 + 2,
						y + 8,
						z + sz * 4 + 2,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
				)
			end
		end
		decor(
			box(
				"DomeRoof",
				x - 7,
				y + 8,
				z - 7,
				x + 7,
				y + 10,
				z + 7,
				"px_gold_block",
				GOLD_DEEP,
				f
			)
		)
		decor(box("Dome", x - 5, y + 10, z - 5, x + 5, y + 13, z + 5, "px_gold_block", GOLD, f))
		decor(box("Dome", x - 3, y + 13, z - 3, x + 3, y + 16, z + 3, "px_gold_block", GOLD, f))
		decor(
			box(
				"DomeFinial",
				x - 1,
				y + 16,
				z - 1,
				x + 1,
				y + 19,
				z + 1,
				"px_gold_block",
				GOLD_DEEP,
				f
			)
		)
		lamp(V(x, y + 4.5, z), 1.6, lit, f, BY + y + 8)
	end
	local PROPS = { "angel", "halo", "dome", "harp", "lantern", "angel", "dome", "halo" }
	local made, lit = 0, 0
	for i = 1, 15 do
		local big = i <= 3
		local w = if big then rng:NextInteger(6, 8) else rng:NextInteger(3, 5)
		local d = math.clamp(w + rng:NextInteger(-1, 1), 3, 8)
		-- the stepped cone below the top: each layer a block narrower, 1–2 blocks high
		local layers = {}
		local cw, cd, down = w, d, B
		while cw > 1 or cd > 1 do
			cw, cd = math.max(1, cw - 1 - (if big and cw > 4 then 1 else 0)), math.max(1, cd - 1)
			local h = rng:NextInteger(1, 2)
			table.insert(layers, { cw, cd, h })
			down += h * B
		end
		down += 2 * B -- the gold tip
		local prop = PROPS[(i - 1) % #PROPS + 1]
		if prop == "dome" and (w < 4 or d < 4) then
			prop = "lantern"
		end
		local half = math.max(w, d) * B / 2
		local x, y, z = findSpot(half, down, 26, -60, 120)
		if x then
			x, y, z = snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2
			local f = folder("Islet", fly)
			local hx, hz = w * B / 2, d * B / 2
			decor(
				box(
					"IsletTop",
					x - hx,
					y - B,
					z - hz,
					x + hx,
					y,
					z + hz,
					"px_smooth_stone",
					QUARTZ,
					f
				)
			)
			if w >= 4 and d >= 4 then
				decor(
					box(
						"IsletInlay",
						x - hx + B,
						y,
						z - hz + B,
						x + hx - B,
						y + 0.06,
						z + hz - B,
						"px_gold_block",
						GOLD,
						f
					)
				)
			end
			-- the layers, kept inside the one above
			local ax, az, aw, ad, top = x - hx, z - hz, w, d, y - B
			for li, l in ipairs(layers) do
				local nx = ax + rng:NextInteger(0, aw - l[1]) * B
				local nz = az + rng:NextInteger(0, ad - l[2]) * B
				local v, t = "px_white_stone_bricks", QUARTZ
				if li == 1 then
					v, t = "px_gold_block", GOLD_DEEP
				elseif li % 2 == 1 then
					v, t = "px_smooth_stone", CREAM
				end
				decor(
					box(
						"IsletRock",
						nx,
						top - l[3] * B,
						nz,
						nx + l[1] * B,
						top,
						nz + l[2] * B,
						v,
						t,
						f
					)
				)
				ax, az, aw, ad, top = nx, nz, l[1], l[2], top - l[3] * B
			end
			decor(
				box("IsletTip", ax, top - 2 * B, az, ax + B, top, az + B, "px_gold_block", GOLD, f)
			)
			-- the prop on top
			local yaw = rng:NextInteger(0, 3) * math.pi / 2
			local pcf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
			if prop == "angel" then
				angel(pcf, f, false)
			elseif prop == "harp" then
				harp(pcf, f, false)
			elseif prop == "halo" then
				decor(
					box(
						"HaloPost",
						x - 1,
						y,
						z - 1,
						x + 1,
						y + 8,
						z + 1,
						"px_white_stone_bricks",
						QUARTZ,
						f
					)
				)
				decor(
					box(
						"HaloPostCap",
						x - 1.5,
						y + 8,
						z - 1.5,
						x + 1.5,
						y + 9,
						z + 1.5,
						"px_gold_block",
						GOLD_DEEP,
						f
					)
				)
				halo(V(x, y + 13, z), 3.5, f, 0.9)
			elseif prop == "dome" then
				miniDome(x, y, z, f, lit < 2)
				lit += 1
			else
				decor(
					box(
						"LampFoot",
						x - 1.2,
						y,
						z - 1.2,
						x + 1.2,
						y + 1,
						z + 1.2,
						"px_smooth_stone",
						QUARTZ,
						f
					)
				)
				decor(
					box(
						"LampShaft",
						x - 0.6,
						y + 1,
						z - 0.6,
						x + 0.6,
						y + 8,
						z + 0.6,
						"px_gold_block",
						GOLD_DEEP,
						f
					)
				)
				lamp(V(x, y + 9.1, z), 1.6, lit < 2, f)
				lit += 1
			end
			made += 1
		end
	end
	print(("[build-cherubim] sky: floating islets %d, %d parts"):format(made, count - f0))
end
task.wait()

-- ================================================================ 6. the clouds
do
	local cl = folder("Clouds", sky)
	local k0 = count
	local nRing, nLayer, nHigh = 0, 0, 0
	local placed = {} -- { x0, x1, z0, z1, y0, y1 }
	local function cb(x0, y0, z0, x1, y1, z1)
		local p = decor(box("Cloud", x0, y0, z0, x1, y1, z1, "px_white_wool", CLOUD, cl))
		p.CastShadow = false
	end
	local function cloud(x, y, z, w, d, th)
		local hx, hz = w * B / 2, d * B / 2
		cb(x - hx, y, z - hz, x + hx, y + th * B, z + hz)
		for _ = 1, rng:NextInteger(1, 2) do
			local pw = rng:NextInteger(math.max(2, w // 3), math.max(2, w - 2))
			local pd = rng:NextInteger(math.max(2, d // 3), math.max(2, d - 2))
			local ox = B * rng:NextInteger(0, math.max(0, w - pw)) - hx
			local oz = B * rng:NextInteger(0, math.max(0, d - pd)) - hz
			cb(x + ox, y + th * B, z + oz, x + ox + pw * B, y + th * B + B, z + oz + pd * B)
		end
		if w >= 8 and rng:NextNumber() < 0.5 then
			local pw, pd = math.max(2, w // 2), math.max(2, d // 2)
			local ox = B * rng:NextInteger(0, w - pw) - hx
			local oz = B * rng:NextInteger(0, d - pd) - hz
			cb(x + ox, y - B, z + oz, x + ox + pw * B, y, z + oz + pd * B)
		end
	end
	local function overlaps(x0, x1, z0, z1, y0, y1)
		for _, p in ipairs(placed) do
			if
				x1 + 10 > p[1]
				and x0 - 10 < p[2]
				and z1 + 10 > p[3]
				and z0 - 10 < p[4]
				and y1 + 6 > p[5]
				and y0 - 6 < p[6]
			then
				return true
			end
		end
		for _, t in ipairs(taken) do
			local e = math.max(x1 - x0, z1 - z0) / 2
			local dh = math.sqrt(((x0 + x1) / 2 - t[1]) ^ 2 + ((z0 + z1) / 2 - t[2]) ^ 2)
			if dh < t[3] + e + 8 and y1 + 8 > t[4] and y0 - 8 < t[5] then
				return true
			end
		end
		return false
	end
	local function try(x, y, z, w, d, th)
		local hx, hz = w * B / 2, d * B / 2
		local y0, y1 = y - B, y + (th + 1) * B
		if
			inCorridor(x - hx, x + hx, z - hz, z + hz, y0, y1)
			or overlaps(x - hx, x + hx, z - hz, z + hz, y0, y1)
			or not clearOfRings(x - hx, x + hx, y0, y1, z - hz, z + hz, 12)
		then
			return false
		end
		cloud(x, y, z, w, d, th)
		table.insert(placed, { x - hx, x + hx, z - hz, z + hz, y0, y1 })
		return true
	end
	-- a ring of puffs round the main island just under its rim (y -10..-40), pushed out until clear of the cells
	for i = 0, 21 do
		local a = (i + rng:NextNumber(-0.3, 0.3)) / 22 * 2 * math.pi
		local w = rng:NextInteger(5, 10)
		local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 3, 8)
		local th = rng:NextInteger(1, 2)
		local y = snap(rng:NextNumber(-40, -14)) - (th + 1) * B + B
		y = math.max(y, -44)
		for rr = 190, 250, 6 do
			local x = snap(math.cos(a) * rr) + (w % 2) * 2
			local z = snap(math.sin(a) * rr) + (d % 2) * 2
			if clearOfIslands(x, z, math.max(w, d) * B / 2, 2) then
				if try(x, y, z, w, d, th) then
					nRing += 1
				end
				break
			end
		end
	end
	task.wait()
	-- the highest top a cloud may have under the rock (and the stalactites) of the cells above it
	local function under(x0, x1, z0, z1)
		local lim = math.huge
		local nx, nz =
			math.max(1, math.ceil((x1 - x0) / 16)), math.max(1, math.ceil((z1 - z0) / 16))
		for i = 0, nx do
			for j = 0, nz do
				local isle, ccx, ccz = cellLand(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz)
				if isle then
					lim = math.min(lim, -B - rockDepth(ccx, ccz) - 13 * B - 8)
				end
			end
		end
		return lim
	end
	-- the layer far under the islands, y -150..-236
	for _ = 1, 22 do
		for _ = 1, 40 do
			local w = rng:NextInteger(7, 22)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 4, 16)
			local th = rng:NextInteger(1, 3)
			local x, z =
				snap(rng:NextNumber(-440, 440)) + (w % 2) * 2,
				snap(rng:NextNumber(-380, 380)) + (d % 2) * 2
			local y = snap(rng:NextNumber(-232, -150))
			local hx, hz = w * B / 2, d * B / 2
			local lim = under(x - hx, x + hx, z - hz, z + hz)
			if y + (th + 1) * B > lim then
				y = math.floor((lim - (th + 1) * B) / B) * B
			end
			if y - B >= -244 and try(x, y, z, w, d, th) then
				nLayer += 1
				break
			end
		end
	end
	task.wait()
	-- a few higher up, clear of the islands, the rings and the islets
	for _ = 1, 8 do
		for _ = 1, 60 do
			local w = rng:NextInteger(5, 12)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.4, 0.8)), 3, 8)
			local th = rng:NextInteger(1, 2)
			local x, z =
				snap(rng:NextNumber(-420, 420)) + (w % 2) * 2,
				snap(rng:NextNumber(-360, 360)) + (d % 2) * 2
			local y = snap(rng:NextNumber(24, 140))
			if clearOfIslands(x, z, math.max(w, d) * B / 2, 24) and try(x, y, z, w, d, th) then
				nHigh += 1
				break
			end
		end
	end
	print(
		("[build-cherubim] sky: clouds %d round the rim, %d under, %d high, %d parts"):format(
			nRing,
			nLayer,
			nHigh,
			count - k0
		)
	)
end
print(("[build-cherubim] sky: %d parts, %d lights"):format(count - c0, lights))
