--!nocheck
-- ================================================================ church: the yard (the YARD part)
-- Everything of the concept outside the cathedral and the square (assets/concepts/church/concept-v2.webp):
-- 1. Two graveyards (|x| 112..~190 on the main island, north and south of the WALKS): an inner stone brick wall
--    with iron fence sections facing the square (a gate onto the square at z 52..68), walls with iron fences along
--    both sides of each walk and a gate in each (u 132..148) opening onto a 4-block gravel main lane; cross lanes at
--    z -80..-64 and 52..68; rows of plots (8 × 12 studs: stone crosses — some mossy, leaning or broken —, stepped
--    headstones, stone chest tombs with candles, cypresses, lantern posts, flowers); at the lane ends a mausoleum
--    (white stone, pointed door, stepped slate roof: west in the north, east in the south) and a monument cross.
-- 2. Arched stone bridges over BRIDGES: the gap measured from core's cells, a 6-block deck (top y 0.1) overlapping
--    both islands, low parapets over the gap only (4 blocks clear between), a stepped arch, a lantern at each end.
-- 3. The islets: a ruined chapel on WEST_ISLE (broken walls, a pointed window with glass remnants, a fallen slate
--    roof, an altar with candles; the walkway enters through the breach), a stone arch with a cross on a stepped
--    rise on EAST_ISLE with graves round it; cypresses and flowers on both.
-- 4. Three waterfalls (west, east, south-west): a spring basin, a flush stream to the rim, a 40-block column of
--    water, white wool foam and a slow mist at its foot.
-- 5. Under every island: white stone stalactites (core's cells and rockDepth), vines and moss on the rim faces.
-- 6. Floating islets round the cluster (graves, lanterns, cypresses, broken arches, benches), clear of the islands,
--    the bridge corridors, the falls, the cloud path and the cathedral.
-- 7. Blocky white wool clouds: a layer under the islands, a few round the edges, a stepping cloud path off the
--    south-east rim. Everything floating is decor.
local yard = folder("Yard")
local c0 = count
local C = 8 -- core's cell
local lights = 0
local MAX_LIGHTS = 18
local PALE = Color3.fromRGB(226, 226, 228) -- core's rockTopTint
local ROCK_LOW_T = Color3.fromRGB(198, 200, 208) -- core's rockLowTint
local SLATE_T = Color3.fromRGB(175, 185, 220) -- a light slate-blue tint over px_blackstone_bricks
local IRON = Color3.fromRGB(96, 98, 108)
local FLOWERS = {
	Color3.fromRGB(245, 245, 240),
	Color3.fromRGB(250, 215, 70),
	Color3.fromRGB(110, 140, 235),
	Color3.fromRGB(235, 120, 160),
	Color3.fromRGB(200, 150, 235),
}
local STONES = { -- grave stone: variant, tint
	{ "px_stone_bricks", GREY_STONE },
	{ "px_white_stone_bricks", WHITE_STONE },
	{ "px_smooth_stone", WHITE_STONE },
	{ "px_mossy_stone_bricks", nil },
	{ "px_stone_bricks", nil },
}

-- the island cell (core's 8-stud grid over x -312..312, z -248..232) holding a point: its island and centre
local function cellLand(x, z)
	if x < -312 or x >= 312 or z < -248 or z >= 232 then
		return nil
	end
	local cx = -312 + C * math.floor((x + 312) / C) + C / 2
	local cz = -248 + C * math.floor((z + 248) / C) + C / 2
	return isleOf(cx, cz), cx, cz
end
-- core's rockDepth (10-core is wrapped in its own do … end, so it is replicated here)
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local rr, deep
	if isle == "main" then
		rr = math.sqrt(((x - ISLAND.x) / ISLAND.rx) ^ 2 + ((z - ISLAND.z) / ISLAND.rz) ^ 2)
		deep = 150
	else
		local c = if isle == "west" then WEST_ISLE else EAST_ISLE
		rr = math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r
		deep = 56
	end
	rr = math.clamp(rr, 0, 1)
	local d = 16 + (1 - rr) ^ 1.2 * deep
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
local function pc(name, size, cf, variant, tint, parent)
	return textured(part(name, size, cf, nil, nil, parent), variant, tint)
end
-- boxes in a local frame: { name, x0, y0, z0, x1, y1, z1, variant, tint } relative to `pivot`
local function piece(list, pivot, f, dec)
	for _, e in ipairs(list) do
		local size =
			Vector3.new(math.abs(e[5] - e[2]), math.abs(e[6] - e[3]), math.abs(e[7] - e[4]))
		local cf = pivot * CFrame.new((e[2] + e[5]) / 2, (e[3] + e[6]) / 2, (e[4] + e[7]) / 2)
		local p = pc(e[1], size, cf, e[8], e[9], f)
		if dec then
			decor(p)
		end
	end
end
-- is the rectangle on `isle` ground (core's cells, `pad` studs in from the rim)?
local function landRect(isle, x0, z0, x1, z1, pad)
	local ax, bx = math.min(x0, x1) + 0.5, math.max(x0, x1) - 0.5
	local az, bz = math.min(z0, z1) + 0.5, math.max(z0, z1) - 0.5
	for i = 0, 2 do
		for j = 0, 2 do
			local x, z = ax + (bx - ax) * i / 2, az + (bz - az) * j / 2
			if cellLand(x, z) ~= isle or isleOf(x, z, pad or 0) ~= isle then
				return false
			end
		end
	end
	return true
end
-- the taken ground: { x0, z0, x1, z1 }
local RES = {}
local function reserve(x0, z0, x1, z1)
	table.insert(RES, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) })
end
local function isFree(x0, z0, x1, z1, pad)
	pad = pad or 0
	local ax0, ax1 = math.min(x0, x1) - pad, math.max(x0, x1) + pad
	local az0, az1 = math.min(z0, z1) - pad, math.max(z0, z1) + pad
	for _, r in ipairs(RES) do
		if ax1 > r[1] and ax0 < r[3] and az1 > r[2] and az0 < r[4] then
			return false
		end
	end
	return true
end
-- a flush path (gravel, cobbles) along one axis, laid block by block where `isle` has ground, runs merged
local function pave(isle, alongZ, a0, a1, w0, w1, v, t, f)
	local lo, hi = math.min(a0, a1), math.max(a0, a1)
	local wl, wh = math.min(w0, w1), math.max(w0, w1)
	local runA = nil
	local function flush(aEnd)
		if runA and aEnd > runA then
			if alongZ then
				decor(box("Path", wl, -0.25, runA, wh, 0.05, aEnd, v, t, f))
			else
				decor(box("Path", runA, -0.25, wl, aEnd, 0.05, wh, v, t, f))
			end
		end
		runA = nil
	end
	local a = lo
	while a < hi - 0.01 do
		local ae = math.min(a + B, hi)
		local ok = true
		for _, w in ipairs({ wl + 1, wh - 1 }) do
			local x, z = w, (a + ae) / 2
			if not alongZ then
				x, z = z, w
			end
			if cellLand(x, z) ~= isle or isleOf(x, z, 1) ~= isle then
				ok = false
			end
		end
		if ok then
			runA = runA or a
		else
			flush(a)
		end
		a = ae
	end
	flush(hi)
end
-- a lantern standing on the surface y (local): lit = the kit lantern with its light (while the budget lasts),
-- else a dark iron cage round a dim glass core
local function lamp(x, y, z, f, lit)
	if lit and lights < MAX_LIGHTS then
		lights += 1
		decor(lantern(V(x, y + 0.75, z), f))
		return true
	end
	local iron = Color3.fromRGB(45, 45, 50)
	decor(
		part(
			"Lantern",
			Vector3.new(1.3, 0.25, 1.3),
			at(x, y + 0.13, z),
			iron,
			Enum.Material.Metal,
			f
		)
	)
	local g = decor(
		part(
			"LanternGlass",
			Vector3.new(0.9, 1, 0.9),
			at(x, y + 0.75, z),
			Color3.fromRGB(215, 190, 140),
			Enum.Material.Glass,
			f
		)
	)
	g.Transparency = 0.25
	decor(
		part(
			"LanternTop",
			Vector3.new(1.3, 0.4, 1.3),
			at(x, y + 1.45, z),
			iron,
			Enum.Material.Metal,
			f
		)
	)
	return false
end
-- a stone pillar (2 blocks) with a cap and a lantern on top
local function pillarLamp(x, z, f, lit, y0, dec)
	y0 = y0 or 0
	local p =
		box("LampPillar", x - 2, y0, z - 2, x + 2, y0 + 8, z + 2, "px_stone_bricks", GREY_STONE, f)
	if dec then
		decor(p)
	end
	decor(
		box(
			"LampCap",
			x - 2.5,
			y0 + 8,
			z - 2.5,
			x + 2.5,
			y0 + 9,
			z + 2.5,
			"px_smooth_stone",
			WHITE_STONE,
			f
		)
	)
	return lamp(x, y0 + 9, z, f, lit)
end
local function candle(x, y, z, f, h)
	h = h or 1.2
	decor(
		box(
			"Candle",
			x - 0.3,
			y,
			z - 0.3,
			x + 0.3,
			y + h,
			z + 0.3,
			"px_white_wool",
			Color3.fromRGB(245, 240, 225),
			f
		)
	)
	local fl = decor(
		part(
			"CandleFlame",
			Vector3.new(0.25, 0.45, 0.25),
			at(x, y + h + 0.22, z),
			Color3.fromRGB(255, 200, 90),
			Enum.Material.Neon,
			f
		)
	)
	fl.CastShadow = false
end
-- a cypress: a log core, a 3×3-block hedge column, a plus-shaped upper part and a 1-block tip (leaves decor)
local function cypress(x, z, h, f, y0, dec)
	y0 = y0 or 0
	local cf = folder("Cypress", f)
	local tint = if rng:NextNumber() < 0.5 then CYPRESS else Color3.fromRGB(186, 212, 176)
	local top = y0 + h
	local mid = y0 + B + math.floor((h - 2 * B) * 0.5 / B + 0.5) * B
	local trunk =
		box("CypressTrunk", x - 2, y0, z - 2, x + 2, top - B, z + 2, "px_oak_log", nil, cf)
	if dec then
		decor(trunk)
	end
	decor(box("CypressLeaves", x - 6, y0 + B, z - 6, x + 6, mid, z + 6, "px_hedge", tint, cf))
	decor(box("CypressLeaves", x - 6, mid, z - 2, x + 6, top - B, z + 2, "px_hedge", tint, cf))
	decor(box("CypressLeaves", x - 2, mid, z - 6, x + 2, top - B, z + 6, "px_hedge", tint, cf))
	decor(box("CypressTip", x - 2, top - B, z - 2, x + 2, top, z + 2, "px_hedge", tint, cf))
end
local function flower(x, z, f, y0)
	y0 = y0 or 0
	decor(box("FlowerStem", x - 0.2, y0, z - 0.2, x + 0.2, y0 + 1.4, z + 0.2, "px_hedge", nil, f))
	decor(
		box(
			"Flower",
			x - 0.6,
			y0 + 1.2,
			z - 0.6,
			x + 0.6,
			y0 + 2.1,
			z + 0.6,
			"px_white_wool",
			pick(FLOWERS),
			f
		)
	)
end
local function flowers(x, z, f, n, y0)
	y0 = y0 or 0
	for _ = 1, n do
		flower(x + rng:NextInteger(-3, 3), z + rng:NextInteger(-3, 3), f, y0)
	end
	if rng:NextNumber() < 0.5 then
		local t = Color3.fromRGB(200, 225, 180)
		decor(box("GrassTuft", x - 1.5, y0, z - 1.5, x + 1.5, y0 + 1.5, z + 1.5, "px_hedge", t, f))
	end
end
-- a stone cross (1-block post, a crossbar `arm` studs each side of the centre: 6 = 3 blocks, 4 in the plots) on
-- the marker block centred (mx, mz); some lean, some are broken with the top lying on the grave (toward dir);
-- returns "cross" or "broken"
local function crossMark(mx, mz, f, dir, y0, dec, arm)
	y0 = y0 or 0
	arm = arm or 6
	local st = pick(STONES)
	local h = pick({ 10, 12, 12, 14 })
	local pivot = at(mx, y0, mz)
	local r = rng:NextNumber()
	if r < 0.2 then
		local a = math.rad(rng:NextNumber(6, 14)) * (if rng:NextNumber() < 0.5 then -1 else 1)
		pivot = pivot
			* (if rng:NextNumber() < 0.5 then CFrame.Angles(a, 0, 0) else CFrame.Angles(0, 0, a))
	end
	if r > 0.88 then
		piece(
			{ { "CrossStump", -2, -1, -2, 2, rng:NextInteger(1, 2) * B, 2, st[1], st[2] } },
			pivot,
			f,
			dec
		)
		local lie = at(mx + rng:NextNumber(-1.5, 1.5), y0, mz + dir * 7)
			* CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0)
		piece({
			{ "CrossFallen", -2, -0.6, -5, 2, 3.4, 5, st[1], st[2] },
			{ "CrossFallen", -arm, -0.6, -3, arm, 3.4, 1, st[1], st[2] },
		}, lie, f, true)
		return "broken"
	end
	piece({
		{ "CrossPost", -2, -1, -2, 2, h, 2, st[1], st[2] },
		{ "CrossArm", -arm, h - 8, -2, arm, h - 4, 2, st[1], st[2] },
	}, pivot, f, dec)
	return "cross"
end
-- a stepped headstone (a base slab, the stone, a narrower top step), some leaning, some double width (not when
-- `narrow`, in the 2-block plots)
local function headstone(mx, mz, f, y0, dec, narrow)
	y0 = y0 or 0
	local st = pick(STONES)
	local pivot = at(mx, y0, mz)
	if rng:NextNumber() < 0.2 then
		pivot = pivot
			* CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), 0, math.rad(rng:NextNumber(-6, 6)))
	end
	local w = if not narrow and rng:NextNumber() < 0.25 then 5 else 3
	piece({
		{ "GraveBase", -w - 1, -1, -2, w + 1, 1.5, 2, "px_stone_bricks", GREY_STONE },
		{ "Headstone", -w, 1.5, -1, w, 6.5, 1, st[1], st[2] },
		{ "HeadstoneTop", -w + 1, 6.5, -1, w - 1, 8, 1, st[1], st[2] },
	}, pivot, f, dec)
end
-- a stone chest tomb (2 × 1 blocks) with a lid and candles
local function tomb(mx, mz, f, y0)
	y0 = y0 or 0
	local st = pick(STONES)
	box("Tomb", mx - 4, y0, mz - 2, mx + 4, y0 + 3.5, mz + 2, st[1], st[2], f)
	box(
		"TombLid",
		mx - 4.2,
		y0 + 3.5,
		mz - 2.5,
		mx + 4.2,
		y0 + 4.5,
		mz + 2.5,
		"px_smooth_stone",
		WHITE_STONE,
		f
	)
	if rng:NextNumber() < 0.65 then
		candle(mx - 3.3, y0 + 4.5, mz, f, 1.4)
		candle(mx + 3.3, y0 + 4.5, mz, f, 1)
	end
end
-- the grave mound behind a marker (2 blocks long toward dir), now and then a flower on it
local function mound(mx, mz, dir, f, y0)
	y0 = y0 or 0
	local r = rng:NextNumber()
	local v, t = "px_dirt", nil
	if r < 0.4 then
		v, t = "px_grass_top", GRASS
	elseif r < 0.6 then
		v = "px_mossy_cobblestone"
	end
	decor(box("GraveMound", mx - 2, y0, mz + dir * 2, mx + 2, y0 + 0.8, mz + dir * 10, v, t, f))
	if rng:NextNumber() < 0.35 then
		flower(mx + rng:NextNumber(-1, 1), mz + dir * rng:NextInteger(4, 8), f, y0 + 0.8)
	end
end
-- a free block-centred spot on `isle` within rmax of (cx, cz) for a square of half size `half`
local function spotOn(isle, cx, cz, rmax, half, pad)
	for _ = 1, 80 do
		local a, d = rng:NextNumber(0, math.pi * 2), rng:NextNumber(0, rmax)
		local x, z = snap(cx + math.cos(a) * d) + 2, snap(cz + math.sin(a) * d) + 2
		if
			landRect(isle, x - half, z - half, x + half, z + half, pad)
			and isFree(x - half, z - half, x + half, z + half, 0)
		then
			return x, z
		end
	end
	return nil
end
-- the waterfalls: a stream along a cell row (axis x: z row..row+8) or column (axis z: x row..row+8) from a spring
-- at `src` to the rim in direction dir; `face` (the rim) is measured from the cells below
local WF = {
	{ name = "WestFall", axis = "x", dir = -1, row = 32, src = -160 },
	{ name = "EastFall", axis = "x", dir = 1, row = -64, src = 160 },
	{ name = "SouthWestFall", axis = "z", dir = 1, row = -128, src = 124 },
}
local DECK = {} -- per side (-1 west, 1 east): { inner = u of the deck end on the main island, landing = x on the isle }
-- the walkable ways through the sky (x0, x1, z0, z1, y0, y1) nothing floating may touch
local CORRIDORS = {}
for _, b in ipairs(BRIDGES) do
	table.insert(CORRIDORS, { b[1] - 16, b[3] + 16, b[2] - 16, b[4] + 16, -20, 30 })
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
	-- nothing over the cathedral and the tower
	return y1 > 0 and x1 > -120 and x0 < 120 and z1 > -260 and z0 < -40
end
-- no island cell within `half` + `margin` studs (horizontally) of (x, z)
local function clearOfIslands(x, z, half, margin)
	local e = half + margin
	local n = math.max(1, math.ceil(2 * e / C))
	for i = 0, n do
		for j = 0, n do
			if cellLand(x - e + 2 * e * i / n, z - e + 2 * e * j / n) ~= nil then
				return false
			end
		end
	end
	return true
end
local taken = {} -- the floating islets: { x, z, half, y0, y1 }

-- the square, the church zone and the walks (with their walls) are not graveyard ground
reserve(-112, -260, 112, 240)
for _, w in ipairs(WALKS) do
	reserve(w[1], w[2] - 4, w[3], w[4] + 4)
end

-- ================================================================ 2. the arched stone bridges (measured first)
do
	local bf = folder("Bridges", yard)
	for bi, b in ipairs(BRIDGES) do
		local s = if bi == 1 then -1 else 1
		local f = folder(if s < 0 then "WestBridge" else "EastBridge", bf)
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
		-- the deck: 6 blocks wide, 16 studs onto each island's ground
		local xa, xb = math.min(lo, ga - 16), math.max(hi, gb + 16)
		box(
			"BridgeDeck",
			xa,
			0.1 - B,
			z0 - 4,
			xb,
			0.1,
			z1 + 4,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		decor(
			box(
				"BridgeRunner",
				ga - 8,
				0.1,
				zm - 4,
				gb + 8,
				0.16,
				zm + 4,
				"px_smooth_stone",
				WHITE_STONE,
				f
			)
		)
		reserve(xa, z0 - 8, xb, z1 + 8)
		DECK[s] = { inner = if s < 0 then -xb else xa, landing = if s < 0 then xa else xb }
		-- the stepped arch under the gap: deep spandrels at the island faces, thin in the middle, a grey ring course
		local under = 0.1 - B
		local n = math.max(1, math.floor((gb - ga) / B + 0.5))
		local runs = {}
		for k = 0, n - 1 do
			local t = (k + 0.5) / n
			local dep = 1 + math.floor((2 * t - 1) ^ 2 * 7 + 0.5)
			local last = runs[#runs]
			if last and last[3] == dep then
				last[2] = ga + (k + 1) * B
			else
				table.insert(runs, { ga + k * B, ga + (k + 1) * B, dep })
			end
		end
		runs[1][1] -= B -- into the island faces
		runs[#runs][2] += B
		for _, r in ipairs(runs) do
			if r[3] > 1 then
				decor(
					box(
						"BridgeSpandrel",
						r[1],
						under - (r[3] - 1) * B,
						z0,
						r[2],
						under,
						z1,
						"px_white_stone_bricks",
						WHITE_STONE,
						f
					)
				)
			end
			decor(
				box(
					"BridgeArchRing",
					r[1],
					under - r[3] * B,
					z0,
					r[2],
					under - (r[3] - 1) * B,
					z1,
					"px_stone_bricks",
					GREY_STONE,
					f
				)
			)
		end
		-- low parapets over the gap only (open at the ends), 4 blocks clear between them
		for si, e in ipairs({ { z0 - 4, z0 }, { z1, z1 + 4 } }) do
			box("Parapet", ga, 0.1, e[1], gb, 4.1, e[2], "px_white_stone_bricks", WHITE_STONE, f)
			decor(
				box(
					"ParapetCoping",
					ga,
					4.1,
					e[1] - 0.3,
					gb,
					4.6,
					e[2] + 0.3,
					"px_smooth_stone",
					WHITE_STONE,
					f
				)
			)
			-- end pillars, a lantern at each end of the bridge (one lit per end)
			for gi, px in ipairs({ ga - B, gb }) do
				box(
					"BridgePillar",
					px,
					0.1,
					e[1],
					px + B,
					8.1,
					e[2],
					"px_stone_bricks",
					GREY_STONE,
					f
				)
				decor(
					box(
						"BridgePillarCap",
						px - 0.5,
						8.1,
						e[1] - 0.5,
						px + B + 0.5,
						9.1,
						e[2] + 0.5,
						"px_smooth_stone",
						WHITE_STONE,
						f
					)
				)
				lamp(px + 2, 9.1, (e[1] + e[2]) / 2, f, si == gi)
			end
		end
	end
end
task.wait()

-- the waterfalls' rims (measured now, built after the graveyards): reserve their streams, keep the sky clear
do
	for _, w in ipairs(WF) do
		local c = w.row + 4
		local base = if w.axis == "x" then -312 else -248
		local cs = base + C * math.floor((w.src - base) / C)
		for _ = 1, 40 do
			local isle = if w.axis == "x" then cellLand(cs + C / 2, c) else cellLand(c, cs + C / 2)
			if isle == nil then
				break
			end
			cs += w.dir * C
		end
		w.face = if w.dir > 0 then cs else cs + C
		local function wr(a0, a1, cA, cB)
			if w.axis == "x" then
				reserve(a0, cA, a1, cB)
			else
				reserve(cA, a0, cB, a1)
			end
		end
		wr(w.src - 8, w.src + 8, w.row - 4, w.row + 12)
		wr(w.src, w.face, w.row - 2, w.row + 10)
		local a0, a1 =
			math.min(w.face - w.dir * 4, w.face + w.dir * 16),
			math.max(w.face - w.dir * 4, w.face + w.dir * 16)
		if w.axis == "x" then
			table.insert(CORRIDORS, { a0, a1, w.row - 12, w.row + 20, -180, 10 })
		else
			table.insert(CORRIDORS, { w.row - 12, w.row + 20, a0, a1, -180, 10 })
		end
	end
end

-- ================================================================ 1. the two graveyards
do
	local litPlots = 0
	local graves = 0
	for _, s in ipairs({ -1, 1 }) do
		local f = folder(if s < 0 then "WestGraveyard" else "EastGraveyard", yard)
		local mausNorth = s < 0 -- the mausoleum: west in the north, east in the south; the monument opposite
		-- a box in u (= s · x) and z
		local function ub(name, u0, y0, z0, u1, y1, z1, v, t, dec)
			local p = box(name, s * u0, y0, z0, s * u1, y1, z1, v, t, f)
			if dec then
				decor(p)
			end
			return p
		end
		-- a wall box: alongZ → a is z and w is u; else a is u and w is z
		local function ws(alongZ, w0, w1, name, a0, a1, y0, y1, grow, v, t, dec)
			if alongZ then
				return ub(name, w0 - grow, y0, a0, w1 + grow, y1, a1, v, t, dec)
			end
			return ub(name, a0, y0, w0 - grow, a1, y1, w1 + grow, v, t, dec)
		end
		-- a wall line a0..a1 (blocks): a pillar every 5th block, between them full brick or a low wall with iron bars
		local function wall(alongZ, a0, a1, w0, w1, fenceRule)
			local blocks, k = {}, 0
			for a = a0, a1 - B, B do
				local x, z
				if alongZ then
					x, z = s * (w0 + w1) / 2, a + 2
				else
					x, z = s * (a + 2), (w0 + w1) / 2
				end
				local kind = "gap"
				if cellLand(x, z) == "main" and isleOf(x, z, 3) == "main" then
					kind = if k % 5 == 0
						then "pillar"
						elseif fenceRule(k // 5) then "fence"
						else "brick"
				end
				table.insert(blocks, { a, kind })
				k += 1
			end
			local i = 1
			while i <= #blocks do
				local kind, j = blocks[i][2], i
				if kind ~= "pillar" then
					while j < #blocks and blocks[j + 1][2] == kind do
						j += 1
					end
				end
				local ra, rb = blocks[i][1], blocks[j][1] + B
				if kind == "pillar" then
					ws(
						alongZ,
						w0,
						w1,
						"WallPillar",
						ra,
						rb,
						0,
						10,
						0,
						"px_stone_bricks",
						GREY_STONE
					)
					ws(
						alongZ,
						w0,
						w1,
						"PillarCap",
						ra - 0.5,
						rb + 0.5,
						10,
						11,
						0.5,
						"px_smooth_stone",
						WHITE_STONE,
						true
					)
				elseif kind == "brick" then
					local mossy = rng:NextNumber() < 0.35
					local v = if mossy then "px_mossy_stone_bricks" else "px_stone_bricks"
					ws(
						alongZ,
						w0,
						w1,
						"Wall",
						ra,
						rb,
						0,
						8,
						0,
						v,
						if mossy then nil else GREY_STONE
					)
					ws(
						alongZ,
						w0,
						w1,
						"WallCoping",
						ra,
						rb,
						8,
						8.6,
						0.3,
						"px_smooth_stone",
						WHITE_STONE,
						true
					)
				elseif kind == "fence" then
					ws(alongZ, w0, w1, "FenceBase", ra, rb, 0, 3, 0, "px_stone_bricks", GREY_STONE)
					ws(alongZ, w0, w1, "FenceRail", ra, rb, 8, 8.6, -1.6, "px_iron_block", IRON)
					local mid = (w0 + w1) / 2
					for bar = ra + 1, rb - 1, 2 do
						ws(
							alongZ,
							mid,
							mid,
							"IronBar",
							bar - 0.25,
							bar + 0.25,
							3,
							8,
							0.25,
							"px_iron_block",
							IRON
						)
					end
				end
				i = j + 1
			end
		end
		-- a gate g0..g1 in a wall line: tall white pillars with lanterns (one lit), an iron arch with a cross
		local function gate(alongZ, g0, g1, w0, w1)
			local mid = (w0 + w1) / 2
			for gi, pa in ipairs({ g0 - B, g1 }) do
				ws(
					alongZ,
					w0,
					w1,
					"GatePillar",
					pa,
					pa + B,
					0,
					13,
					0,
					"px_white_stone_bricks",
					WHITE_STONE
				)
				ws(
					alongZ,
					w0,
					w1,
					"GateCap",
					pa - 0.5,
					pa + B + 0.5,
					13,
					14,
					1,
					"px_smooth_stone",
					WHITE_STONE,
					true
				)
				if alongZ then
					lamp(s * mid, 14, pa + 2, f, gi == 1)
				else
					lamp(s * (pa + 2), 14, mid, f, gi == 1)
				end
			end
			local gm = (g0 + g1) / 2
			ws(alongZ, mid, mid, "GateArch", g0, g1, 11, 12, 0.4, "px_iron_block", IRON, true)
			ws(
				alongZ,
				mid,
				mid,
				"GateCross",
				gm - 0.5,
				gm + 0.5,
				12,
				16,
				0.4,
				"px_iron_block",
				IRON,
				true
			)
			ws(
				alongZ,
				mid,
				mid,
				"GateCross",
				gm - 1.5,
				gm + 1.5,
				14,
				15,
				0.4,
				"px_iron_block",
				IRON,
				true
			)
		end
		local inner = function(sec)
			return sec % 3 == 1
		end
		local always = function()
			return true
		end
		-- the inner wall facing the square (open over the walk), a gate onto the square in the south
		wall(true, -248, -28, 112, 116, inner)
		wall(true, 0, 48, 112, 116, inner)
		gate(true, 52, 68, 112, 116)
		wall(true, 72, 232, 112, 116, inner)
		-- iron fences along both sides of the walk, a gate in each onto the main lane, stopping short of the deck
		local uEnd = math.floor((DECK[s].inner - 6) / B) * B
		for _, wz in ipairs({ { -28, -24 }, { -4, 0 } }) do
			wall(false, 112, 128, wz[1], wz[2], always)
			gate(false, 132, 148, wz[1], wz[2])
			if uEnd > 152 then
				wall(false, 152, uEnd, wz[1], wz[2], always)
			end
		end
		task.wait()

		-- the lane end (u 124..156): the far face and the near face (toward the walk) of a feature `depth` deep
		local function laneEnd(isNorth, depth)
			if isNorth then
				for zf = -244, -100, B do
					if
						landRect("main", s * 124, zf - 4, s * 156, zf + depth + 4, 6)
						and isFree(s * 124, zf - 4, s * 156, zf + depth + 4, 0)
					then
						return zf, zf + depth
					end
				end
			else
				for zf = 228, 80, -B do
					if
						landRect("main", s * 124, zf - depth - 4, s * 156, zf + 4, 6)
						and isFree(s * 124, zf - depth - 4, s * 156, zf + 4, 0)
					then
						return zf, zf - depth
					end
				end
			end
			return nil
		end
		-- the mausoleum: white stone on a plinth, corner pilasters, a pointed door toward the walk, a stepped slate
		-- roof with a white gable and a cross, lanterns by the door
		local function mausoleum(isNorth)
			local zf, zn = laneEnd(isNorth, 20)
			if not zf then
				return nil
			end
			local m = folder("Mausoleum", f)
			local dz = if isNorth then 1 else -1
			local za, zb = math.min(zf, zn), math.max(zf, zn)
			local function mb(name, u0, y0, z0, u1, y1, z1, v, t, dec)
				local p = box(name, s * u0, y0, z0, s * u1, y1, z1, v, t, m)
				if dec then
					decor(p)
				end
			end
			mb("MausoleumPlinth", 128, 0, za - 2, 152, 1, zb + 2, "px_stone_bricks", GREY_STONE)
			mb("Mausoleum", 130, 1, za, 150, 13, zb, "px_white_stone_bricks", WHITE_STONE)
			for _, cu in ipairs({ 130, 146 }) do
				for _, cz in ipairs({ za, zb - B }) do
					mb(
						"MausoleumPilaster",
						cu - 0.5,
						1,
						cz - 0.5,
						cu + B + 0.5,
						15,
						cz + B + 0.5,
						"px_smooth_stone",
						WHITE_STONE
					)
				end
			end
			for _, r in ipairs({
				{ 128, 152, 13, 15 },
				{ 132, 148, 15, 17 },
				{ 136, 144, 17, 19 },
				{ 138, 142, 19, 20.5 },
			}) do
				mb("MausoleumRoof", r[1], r[3], za, r[2], r[4], zb, "px_blackstone_bricks", SLATE_T)
			end
			-- the white stepped gable over the door face and a cross on the ridge
			for _, g in ipairs({ { 132, 148, 13, 15 }, { 136, 144, 15, 17 }, { 138, 142, 17, 19 } }) do
				mb(
					"MausoleumGable",
					g[1],
					g[3],
					zn,
					g[2],
					g[4],
					zn + dz * 0.6,
					"px_white_stone_bricks",
					WHITE_STONE,
					true
				)
			end
			mb(
				"MausoleumCross",
				139,
				20.5,
				zn - dz * 3,
				141,
				27,
				zn - dz * 1,
				"px_smooth_stone",
				WHITE_STONE,
				true
			)
			mb(
				"MausoleumCross",
				136.5,
				23.5,
				zn - dz * 3,
				143.5,
				25,
				zn - dz * 1,
				"px_smooth_stone",
				WHITE_STONE,
				true
			)
			-- the pointed door in a white frame
			mb(
				"MausoleumDoorFrame",
				134,
				1,
				zn,
				146,
				12,
				zn + dz * 0.8,
				"px_smooth_stone",
				WHITE_STONE,
				true
			)
			local dark = Color3.fromRGB(120, 105, 95)
			for _, d in ipairs({
				{ 136, 144, 1, 9 },
				{ 137.5, 142.5, 9, 10.5 },
				{ 139, 141, 10.5, 11.5 },
			}) do
				mb(
					"MausoleumDoor",
					d[1],
					d[3],
					zn + dz * 0.8,
					d[2],
					d[4],
					zn + dz * 1.1,
					"px_dark_oak_planks",
					dark,
					true
				)
			end
			pillarLamp(s * 130, zn + dz * 6, m, true)
			pillarLamp(s * 150, zn + dz * 6, m, false)
			flowers(s * 132, zn + dz * 4, m, 3)
			flowers(s * 148, zn + dz * 4, m, 3)
			return za, zb, zn
		end
		-- the monument: a big white cross on a stepped plinth with candles
		local function monument(isNorth)
			local zf, zn = laneEnd(isNorth, 16)
			if not zf then
				return nil
			end
			local za, zb = math.min(zf, zn), math.max(zf, zn)
			local zc = (za + zb) / 2
			ub("MonumentStep", 132, 0, za, 148, 1.5, zb, "px_stone_bricks", GREY_STONE)
			ub(
				"MonumentPlinth",
				135,
				1.5,
				zc - 5,
				145,
				5,
				zc + 5,
				"px_white_stone_bricks",
				WHITE_STONE
			)
			ub(
				"MonumentPlinth",
				136.5,
				5,
				zc - 3.5,
				143.5,
				7,
				zc + 3.5,
				"px_smooth_stone",
				WHITE_STONE
			)
			ub("MonumentCross", 138, 7, zc - 2, 142, 27, zc + 2, "px_smooth_stone", WHITE_STONE)
			ub("MonumentCross", 132, 19, zc - 2, 148, 23, zc + 2, "px_smooth_stone", WHITE_STONE)
			for _, cu in ipairs({ 133.5, 146.5 }) do
				for _, cz in ipairs({ za + 1.5, zb - 1.5 }) do
					candle(s * cu, 1.5, cz, f, 1.4)
				end
			end
			flowers(s * 128, zc, f, 3)
			flowers(s * 152, zc, f, 3)
			return za, zb, zn
		end
		-- the main lane (u 132..148) from the walk gate to the feature at its end (or to the rim)
		for _, isNorth in ipairs({ true, false }) do
			local za, zb, zn
			if isNorth == mausNorth then
				za, zb, zn = mausoleum(isNorth)
			else
				za, zb, zn = monument(isNorth)
			end
			if za then
				reserve(s * 128, za - 8, s * 152, zb + 10)
			end
			local l0, l1
			if isNorth then
				l0, l1 = zn or -248, -24
			else
				l0, l1 = -4, zn or 232
			end
			pave("main", true, l0, l1, s * 132, s * 148, "px_gravel", nil, f)
			reserve(s * 132, l0, s * 148, l1)
		end
		-- the cross lanes, the south one through the inner gate
		-- (laid round the main lane so the gravel never doubles up)
		pave("main", false, s * 116, s * 132, -80, -64, "px_gravel", nil, f)
		pave("main", false, s * 148, s * 200, -80, -64, "px_gravel", nil, f)
		reserve(s * 116, -80, s * 200, -64)
		pave("main", false, s * 112, s * 132, 52, 68, "px_gravel", nil, f)
		pave("main", false, s * 148, s * 200, 52, 68, "px_gravel", nil, f)
		reserve(s * 112, 52, s * 200, 68)
		task.wait()

		-- the plots: 8 (u) × 12 (z), the marker on the block next to the walk side, the mound behind it; no two
		-- crossbars or tombs side by side, a cypress only after a gap and with a gap after it
		local nTomb, nCyp = 0, 0
		local function wide(kind)
			return kind == "cross" or kind == "broken" or kind == "tomb" or kind == "cypress"
		end
		for _, q in ipairs({ { -1, -32 }, { 1, 4 } }) do
			local dir = q[1]
			for k = 0, 20 do
				local zn = q[2] + dir * 12 * k
				local za, zb = math.min(zn, zn + dir * 12), math.max(zn, zn + dir * 12)
				if za < -248 or zb > 232 then
					break
				end
				local prev, skipNext = nil, false
				for _, u0 in ipairs({ 116, 124, 152, 160, 168, 176, 184 }) do
					local x0, x1 = s * u0, s * (u0 + 8)
					if landRect("main", x0, za, x1, zb, 2) and isFree(x0, za, x1, zb, 0) then
						reserve(x0, za, x1, zb)
						local mx, mz = s * (u0 + 4), zn + dir * 2
						local r = rng:NextNumber()
						local kind = nil
						if skipNext then
							skipNext = false
							if r < 0.6 then
								flowers(mx, mz + dir * 4, f, 2)
							end
						elseif r < 0.42 and not wide(prev) then
							kind = crossMark(mx, mz, f, dir, 0, false, 4)
						elseif r >= 0.72 and r < 0.8 and nTomb < 8 and not wide(prev) then
							tomb(mx, mz, f)
							nTomb += 1
							kind = "tomb"
						elseif
							r >= 0.8
							and r < 0.87
							and nCyp < 8
							and not wide(prev)
							and prev ~= "stone"
						then
							cypress(mx, mz + dir * 4, pick({ 20, 24, 28, 32 }), f)
							nCyp += 1
							kind = "cypress"
							skipNext = true
						elseif r >= 0.87 and r < 0.92 then
							if pillarLamp(mx, mz, f, litPlots < 2) then
								litPlots += 1
							end
							kind = "lamp"
						elseif r >= 0.92 then
							flowers(mx, mz + dir * 4, f, 3)
						else
							headstone(mx, mz, f, 0, false, true)
							kind = "stone"
						end
						if
							kind == "cross"
							or kind == "broken"
							or kind == "stone"
							or kind == "tomb"
						then
							mound(mx, mz, dir, f)
							graves += 1
						end
						prev = kind
					else
						prev, skipNext = nil, false
					end
				end
				if k % 3 == 2 then
					task.wait()
				end
			end
		end
		-- flowers in the gaps
		for _ = 1, 10 do
			local x, z = spotOn("main", s * 150, -14, 120, 2, 4)
			if x then
				flowers(x, z, f, rng:NextInteger(2, 4))
				reserve(x - 2, z - 2, x + 2, z + 2)
			end
		end
	end
	print(("[build-church] yard: graves %d, lit plot lanterns %d"):format(graves, litPlots))
end
task.wait()

-- ================================================================ 3. the islets: the ruined chapel and the arch
do
	-- WEST_ISLE: the walkway from the bridge into the chapel's breach
	local f = folder("WestIsle", yard)
	local land = DECK[-1].landing
	reserve(-266, -24, land + 4, -4)
	pave("west", false, -266, land, -22, -6, "px_cobblestone", nil, f)
	pave("west", true, -8, 6, -280, -268, "px_cobblestone", nil, f) -- before the door
	reserve(-288, -38, -260, -6)
	reserve(-282, -8, -266, 6)
	local ch = folder("RuinedChapel", f)
	local function rw(name, x0, y0, z0, x1, y1, z1, v, t)
		if landRect("west", x0, z0, x1, z1, 1) then
			return box(
				name,
				x0,
				y0,
				z0,
				x1,
				y1,
				z1,
				v or "px_white_stone_bricks",
				t or WHITE_STONE,
				ch
			)
		end
		return nil
	end
	-- a broken wall line: block heights `hs` (studs, 0 = gone), runs merged, only on the isle's ground
	local function ruin(alongZ, a0, a1, w0, w1, hs)
		local k, runA, runH = 0, nil, nil
		local function flush(aEnd)
			if runA and runH > 0 then
				local mossy = rng:NextNumber() < 0.3
				local v = if mossy then "px_mossy_stone_bricks" else "px_white_stone_bricks"
				local t = if mossy then nil else WHITE_STONE
				if alongZ then
					box("ChapelWall", w0, 0, runA, w1, runH, aEnd, v, t, ch)
				else
					box("ChapelWall", runA, 0, w0, aEnd, runH, w1, v, t, ch)
				end
			end
			runA = nil
		end
		for a = a0, a1 - B, B do
			k += 1
			local h = hs[k] or 0
			local x, z = (w0 + w1) / 2, a + 2
			if not alongZ then
				x, z = a + 2, (w0 + w1) / 2
			end
			if cellLand(x, z) ~= "west" or isleOf(x, z, 1) ~= "west" then
				h = 0
			end
			if h ~= runH then
				flush(a)
				runA, runH = a, h
			end
		end
		flush(a1)
	end
	ruin(true, -36, -8, -286, -282, { 16, 12, 12, 8, 12, 8, 4 }) -- the west wall
	ruin(true, -36, -8, -266, -262, { 16, 8, 4, 0, 0, 0, 0 }) -- the east wall: the breach toward the bridge
	-- the north wall with a pointed window, glass remnants and its stepped gable still standing
	rw("ChapelWall", -282, 0, -36, -278, 16, -32)
	rw("ChapelWall", -270, 0, -36, -266, 16, -32)
	rw("ChapelWall", -278, 0, -36, -270, 4, -32)
	rw("ChapelWall", -278, 10, -36, -276, 16, -32)
	rw("ChapelWall", -272, 10, -36, -270, 16, -32)
	rw("ChapelWall", -276, 13, -36, -272, 16, -32)
	rw("ChapelGable", -280, 16, -36, -268, 20, -32)
	rw("ChapelGable", -277, 20, -36, -271, 24, -32)
	if landRect("west", -278, -36, -270, -32, 1) then
		for _, g in ipairs({ { -278, -274, 4, 8, GLASS_BLUE }, { -274, -272, 4, 6, GLASS_CYAN } }) do
			local p = decor(
				part(
					"ChapelGlass",
					Vector3.new(g[2] - g[1], g[4] - g[3], 0.4),
					at((g[1] + g[2]) / 2, (g[3] + g[4]) / 2, -34),
					g[5],
					Enum.Material.Glass,
					ch
				)
			)
			p.Transparency = 0.25
		end
	end
	-- the south wall with the pointed door
	rw("ChapelWall", -282, 0, -12, -278, 12, -8)
	rw("ChapelWall", -270, 0, -12, -268, 12, -8)
	rw("ChapelWall", -268, 0, -12, -266, 6, -8, "px_mossy_stone_bricks", nil)
	rw("ChapelWall", -278, 8, -12, -276, 12, -8)
	rw("ChapelWall", -272, 8, -12, -270, 12, -8)
	rw("ChapelWall", -276, 10, -12, -272, 12, -8)
	-- the floor, the dais and the altar with candles and a little gold cross
	decor(box("ChapelFloor", -282, -0.2, -32, -266, 0.04, -12, "px_stone_bricks", GREY_STONE, ch))
	for _ = 1, 3 do
		local px, pz = -282 + B * rng:NextInteger(0, 3), -32 + B * rng:NextInteger(0, 4)
		decor(
			box("ChapelMoss", px, 0.04, pz, px + B, 0.08, pz + B, "px_mossy_cobblestone", nil, ch)
		)
	end
	box("ChapelDais", -282, 0, -32, -266, 1, -24, "px_stone_bricks", GREY_STONE, ch)
	box("Altar", -278, 1, -32, -270, 4, -28, "px_white_stone_bricks", WHITE_STONE, ch)
	box("AltarTop", -278.5, 4, -32.5, -269.5, 5, -27.5, "px_smooth_stone", WHITE_STONE, ch)
	for i, cx in ipairs({ -277, -275.5, -272.5, -271 }) do
		candle(cx, 5, -29.5, ch, if i % 2 == 0 then 1.6 else 1.1)
	end
	decor(box("AltarCross", -274.5, 5, -31.5, -273.5, 9.5, -30.5, "px_gold_block", GOLD, ch))
	decor(box("AltarCross", -276, 7.5, -31.5, -272, 8.5, -30.5, "px_gold_block", GOLD, ch))
	-- the fallen roof: a slate slab leaning on the west wall, slabs and beams on the floor, rubble at the breach
	pc(
		"FallenRoof",
		Vector3.new(16, 1.5, 12),
		at(-277, 6.5, -20) * CFrame.Angles(0, 0, math.rad(-38)),
		"px_blackstone_bricks",
		SLATE_T,
		ch
	)
	pc(
		"FallenRoof",
		Vector3.new(10, 1.5, 8),
		at(-273, 1, -15) * CFrame.Angles(math.rad(6), math.rad(20), math.rad(-5)),
		"px_blackstone_bricks",
		SLATE_T,
		ch
	)
	pc(
		"FallenRoof",
		Vector3.new(8, 1.5, 10),
		at(-278, 1.8, -26) * CFrame.Angles(0, -0.3, 0.12),
		"px_blackstone_bricks",
		SLATE_T,
		ch
	)
	pc(
		"FallenBeam",
		Vector3.new(2, 2, 20),
		at(-273, 4, -21) * CFrame.Angles(math.rad(-14), math.rad(25), 0),
		"px_dark_oak_log",
		nil,
		ch
	)
	pc(
		"FallenBeam",
		Vector3.new(2, 2, 14),
		at(-279, 1, -17) * CFrame.Angles(0, 1.2, 0.1),
		"px_dark_oak_log",
		nil,
		ch
	)
	for _, r in ipairs({
		{ -262, 1.4, -20, 4 },
		{ -259, 0.8, -14, 2 },
		{ -264, 1, -11, 3 },
		{ -258, 0.9, -24, 2 },
	}) do
		pc(
			"Rubble",
			Vector3.new(r[4], r[4], r[4]),
			at(r[1], r[2], r[3])
				* CFrame.Angles(
					rng:NextNumber(-0.4, 0.4),
					rng:NextNumber(0, 1.5),
					rng:NextNumber(-0.4, 0.4)
				),
			"px_white_stone_bricks",
			WHITE_STONE,
			ch
		)
	end
	for _, d in ipairs(ch:GetChildren()) do
		if d.Name == "FallenRoof" or d.Name == "FallenBeam" or d.Name == "Rubble" then
			decor(d)
		end
	end
	-- cypresses, two old graves, flowers
	for _ = 1, 2 do
		local x, z = spotOn("west", -266, -14, 28, 6, 2)
		if x then
			cypress(x, z, pick({ 20, 24, 28 }), f)
			reserve(x - 6, z - 6, x + 6, z + 6)
		end
	end
	for _ = 1, 2 do
		local x, z = spotOn("west", -266, -14, 26, 6, 2)
		if x then
			local dir = if z < -14 then -1 else 1
			if rng:NextNumber() < 0.5 then
				crossMark(x, z - dir * 4, f, dir)
			else
				headstone(x, z - dir * 4, f)
			end
			mound(x, z - dir * 4, dir, f)
			reserve(x - 6, z - 6, x + 6, z + 6)
		end
	end
	for _ = 1, 6 do
		local x, z = spotOn("west", -266, -14, 28, 2, 1)
		if x then
			flowers(x, z, f, 3)
			reserve(x - 2, z - 2, x + 2, z + 2)
		end
	end
end
task.wait()
do
	-- EAST_ISLE: the walkway up a stepped rise through a stone arch with a cross, graves round it
	local f = folder("EastIsle", yard)
	local land = DECK[1].landing
	reserve(land - 4, -24, 262, -4)
	pave("east", false, land, 260, -22, -6, "px_cobblestone", nil, f)
	local tiers = {
		{ 260, 288, -28, 0, 1, "px_grass_top", GRASS },
		{ 264, 284, -24, -4, 2, "px_mossy_cobblestone", nil },
		{ 268, 280, -22, -6, 3, "px_white_stone_bricks", WHITE_STONE },
	}
	for i, t in ipairs(tiers) do
		box("Rise", t[1], t[5] - (if i == 1 then 1.5 else 1), t[3], t[2], t[5], t[4], t[6], t[7], f)
	end
	reserve(258, -30, 290, 2)
	local ay = 3
	local ar = folder("CrossArch", f)
	box("ArchPillar", 272, ay, -22, 276, ay + 16, -18, "px_stone_bricks", GREY_STONE, ar)
	box("ArchPillar", 272, ay, -10, 276, ay + 16, -6, "px_stone_bricks", GREY_STONE, ar)
	box(
		"ArchCorbel",
		272,
		ay + 13,
		-18,
		276,
		ay + 16,
		-16,
		"px_white_stone_bricks",
		WHITE_STONE,
		ar
	)
	box(
		"ArchCorbel",
		272,
		ay + 13,
		-12,
		276,
		ay + 16,
		-10,
		"px_white_stone_bricks",
		WHITE_STONE,
		ar
	)
	box(
		"ArchLintel",
		271.5,
		ay + 16,
		-23,
		276.5,
		ay + 20,
		-5,
		"px_white_stone_bricks",
		WHITE_STONE,
		ar
	)
	box("ArchCrown", 272, ay + 20, -18, 276, ay + 24, -10, "px_white_stone_bricks", WHITE_STONE, ar)
	box("ArchCross", 272.5, ay + 24, -16, 275.5, ay + 37, -12, "px_smooth_stone", WHITE_STONE, ar)
	box("ArchCross", 272.5, ay + 29, -20, 275.5, ay + 33, -8, "px_smooth_stone", WHITE_STONE, ar)
	if lights < MAX_LIGHTS then
		lights += 1
		decor(lantern(V(274, ay + 11, -14), ar, false, BY + ay + 16))
	end
	-- graves round the rise, the mound away from it
	for _, sp in ipairs({
		{ 250, -36 },
		{ 262, -38 },
		{ 274, -38 },
		{ 286, -36 },
		{ 294, -14 },
		{ 290, 6 },
		{ 278, 10 },
		{ 266, 10 },
		{ 254, 8 },
		{ 296, -26 },
	}) do
		local x, z = sp[1], sp[2]
		local dir = if z < -14 then -1 else 1
		local za, zb = math.min(z - dir * 2, z + dir * 10), math.max(z - dir * 2, z + dir * 10)
		if landRect("east", x - 6, za, x + 6, zb, 2) and isFree(x - 6, za, x + 6, zb, 0) then
			if rng:NextNumber() < 0.55 then
				crossMark(x, z, f, dir)
			else
				headstone(x, z, f)
			end
			mound(x, z, dir, f)
			reserve(x - 6, za, x + 6, zb)
		end
	end
	for _ = 1, 2 do
		local x, z = spotOn("east", 268, -14, 28, 6, 2)
		if x then
			cypress(x, z, pick({ 20, 24, 28 }), f)
			reserve(x - 6, z - 6, x + 6, z + 6)
		end
	end
	for _ = 1, 6 do
		local x, z = spotOn("east", 268, -14, 28, 2, 1)
		if x then
			flowers(x, z, f, 3)
			reserve(x - 2, z - 2, x + 2, z + 2)
		end
	end
end
task.wait()

-- ================================================================ 4. the waterfalls
do
	local wfF = folder("Waterfalls", yard)
	for _, w in ipairs(WF) do
		local f = folder(w.name, wfF)
		local r, d, src, face = w.row, w.dir, w.src, w.face
		local function ab(name, a0, y0, a1, y1, cA, cB, v, t)
			if w.axis == "x" then
				return decor(box(name, a0, y0, cA, a1, y1, cB, v, t, f))
			end
			return decor(box(name, cA, y0, a0, cB, y1, a1, v, t, f))
		end
		local function wpt(a, y, c)
			return if w.axis == "x" then at(a, y, c) else at(c, y, a)
		end
		-- the spring: a low stone basin (open toward the stream) with a mossy spout pillar at the back
		ab("Basin", src - 6, 0, src + 6, 1, r - 2, r, "px_stone_bricks", GREY_STONE)
		ab("Basin", src - 6, 0, src + 6, 1, r + 8, r + 10, "px_stone_bricks", GREY_STONE)
		ab("Basin", src - d * 6, 0, src - d * 4, 1, r, r + 8, "px_stone_bricks", GREY_STONE)
		ab("Basin", src + d * 4, 0, src + d * 6, 1, r, r + 2, "px_stone_bricks", GREY_STONE)
		ab("Basin", src + d * 4, 0, src + d * 6, 1, r + 6, r + 8, "px_stone_bricks", GREY_STONE)
		ab("BasinWater", src - d * 4, -0.3, src + d * 4, 0.6, r, r + 8, "px_water", nil)
		ab(
			"SpoutPillar",
			src - d * 6,
			0,
			src - d * 2,
			8,
			r + 2,
			r + 6,
			"px_mossy_stone_bricks",
			nil
		)
		ab("Spout", src - d * 2, 0.6, src - d * 1.6, 6, r + 3, r + 5, "px_water", nil).Transparency =
			0.3
		-- the stream to the rim between mossy banks
		ab("Stream", src + d * 4, -0.3, face, 0.03, r + 2, r + 6, "px_water", nil)
		ab("StreamBank", src + d * 6, -0.25, face, 0.06, r, r + 2, "px_mossy_cobblestone", nil)
		ab("StreamBank", src + d * 6, -0.25, face, 0.06, r + 6, r + 8, "px_mossy_cobblestone", nil)
		-- the fall: a lip over the edge, a 40-block column, a wider veil lower down
		ab("FallLip", face - d * 1, -1.5, face + d * 2, 0.03, r + 1.5, r + 6.5, "px_water", nil)
		ab("Fall", face + d * 0.5, -160, face + d * 3, -1.5, r + 1.5, r + 6.5, "px_water", nil).Transparency =
			0.3
		ab("FallVeil", face + d * 1, -172, face + d * 4.5, -110, r + 0.5, r + 7.5, "px_water", nil).Transparency =
			0.35
		-- white wool foam at its foot and a slow mist
		local fa, fc = face + d * 3, r + 4
		for _, fo in ipairs({ { 8, -176, -170, 7 }, { 5, -170, -166, 4 }, { 11, -179, -175, 10 } }) do
			ab(
				"Foam",
				fa - fo[1],
				fo[2],
				fa + fo[1],
				fo[3],
				fc - fo[4],
				fc + fo[4],
				"px_white_wool",
				CLOUD
			).CastShadow =
				false
		end
		local mist = decor(part("FallMist", Vector3.new(12, 1, 12), wpt(fa, -168, fc), nil, nil, f))
		mist.Transparency = 1
		emitter(mist, {
			Rate = 3,
			Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(1, 2.5),
			SpreadAngle = Vector2.new(35, 35),
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 3),
				NumberSequenceKeypoint.new(1, 8),
			}),
			Color = ColorSequence.new(Color3.fromRGB(250, 252, 255)),
			LightEmission = 0.1,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.55),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end
end
task.wait()

-- ================================================================ 5. under the islands: stalactites, vines, moss
local stalactites = 0
do
	local hang = folder("UnderRock", yard)
	local cS = count
	local vines, moss = 0, 0
	local VINE_T = Color3.fromRGB(175, 210, 150)
	local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local function nearFall(x, z)
		for _, w in ipairs(WF) do
			local fx, fz = w.face, w.row + 4
			if w.axis == "z" then
				fx, fz = w.row + 4, w.face
			end
			if math.abs(x - fx) < 20 and math.abs(z - fz) < 20 then
				return true
			end
		end
		return false
	end
	local function nearBridge(x, z)
		for _, b in ipairs(BRIDGES) do
			if inRect(x, z, b, 14) then
				return true
			end
		end
		return false
	end
	local function column(x0, z0, sz, top, len)
		local r = rng:NextNumber()
		local v, t = "px_stone", PALE
		if r < 0.3 then
			t = ROCK_LOW_T
		elseif r < 0.55 then
			v, t = "px_smooth_stone", WHITE_STONE
		end
		decor(box("Stalactite", x0, top - len, z0, x0 + sz, top, z0 + sz, v, t, hang))
		stalactites += 1
	end
	for z = -248, 232 - C, C do
		for x = -312, 312 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			if isleOf(cx, cz) ~= nil and count - cS < 940 then
				local bottom = -B - rockDepth(cx, cz)
				local outX, outZ, rim = 0, 0, false
				for _, d in ipairs(DIRS4) do
					if isleOf(cx + d[1] * C, cz + d[2] * C) == nil then
						rim = true
						outX += d[1]
						outZ += d[2]
						local rr = rng:NextNumber()
						if rr < 0.12 and not nearFall(cx, cz) and not nearBridge(cx, cz) then
							local a = rng:NextInteger(0, 1) * B
							if rr < 0.07 then
								-- a vine hanging down the rim face
								local len = rng:NextInteger(2, 6) * B
								if d[1] ~= 0 then
									local fx = cx + d[1] * 4
									decor(
										box(
											"RimVine",
											fx + d[1] * 0.2,
											-0.4 - len,
											z + a,
											fx + d[1] * 0.8,
											-0.4,
											z + a + B,
											"px_hedge",
											VINE_T,
											hang
										)
									)
								else
									local fz = cz + d[2] * 4
									decor(
										box(
											"RimVine",
											x + a,
											-0.4 - len,
											fz + d[2] * 0.2,
											x + a + B,
											-0.4,
											fz + d[2] * 0.8,
											"px_hedge",
											VINE_T,
											hang
										)
									)
								end
								vines += 1
							else
								-- a mossy patch on the face just under the grass
								local h = rng:NextInteger(1, 2) * B
								if d[1] ~= 0 then
									local fx = cx + d[1] * 4
									decor(
										box(
											"RimMoss",
											fx,
											-0.5 - h,
											z + a,
											fx + d[1] * 0.6,
											-0.5,
											z + a + B,
											"px_mossy_cobblestone",
											nil,
											hang
										)
									)
								else
									local fz = cz + d[2] * 4
									decor(
										box(
											"RimMoss",
											x + a,
											-0.5 - h,
											fz,
											x + a + B,
											-0.5,
											fz + d[2] * 0.6,
											"px_mossy_cobblestone",
											nil,
											hang
										)
									)
								end
								moss += 1
							end
						end
					end
				end
				if rng:NextNumber() < (if rim then 0.6 else 0.2) then
					if not rim and rng:NextNumber() < 0.4 then
						-- a fat 2×2 column with a 1×1 tip under one quarter
						local len = rng:NextInteger(2, 7) * B
						column(x, z, 2 * B, bottom + 2, len + 2)
						if rng:NextNumber() < 0.7 then
							column(
								x + rng:NextInteger(0, 1) * B,
								z + rng:NextInteger(0, 1) * B,
								B,
								bottom - len,
								rng:NextInteger(1, 3) * B
							)
						end
					else
						-- 1×1 columns on the outer quarter of a rim cell
						local qx = if outX > 0
							then 1
							elseif outX < 0 then 0
							else rng:NextInteger(0, 1)
						local qz = if outZ > 0
							then 1
							elseif outZ < 0 then 0
							else rng:NextInteger(0, 1)
						local len = if rim then rng:NextInteger(3, 10) else rng:NextInteger(2, 6)
						column(x + qx * B, z + qz * B, B, bottom + 2, len * B + 2)
						if rim and len > 3 and rng:NextNumber() < 0.35 then
							local q2x, q2z = 1 - qx, qz
							if outX == 0 then
								q2x, q2z = qx, 1 - qz
							end
							column(
								x + q2x * B,
								z + q2z * B,
								B,
								bottom + 2,
								rng:NextInteger(1, len - 2) * B + 2
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
	print(
		("[build-church] yard: stalactites %d, vines %d, moss %d, %d parts"):format(
			stalactites,
			vines,
			moss,
			count - cS
		)
	)
end
task.wait()

-- ================================================================ 7a. the cloud path off the south-east rim (measured
-- before the islets so they keep clear of it)
do
	local cp = folder("CloudPath", yard)
	local dx, dz = 0.12, 0.99
	local m = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / m, dz / m
	local rx, rz = 118, 120
	for _ = 1, 100 do
		if cellLand(rx, rz) == nil then
			break
		end
		rx += dx * 2
		rz += dz * 2
	end
	local px, pz = -dz, dx
	local d = 6
	local x0, x1, z0, z1 = math.huge, -math.huge, math.huge, -math.huge
	for i = 1, 7 do
		local cx, cz, ok = 0, 0, false
		for _ = 1, 12 do
			cx = snap(rx + dx * d + px * math.sin(i * 1.3) * 8)
			cz = snap(rz + dz * d + pz * math.sin(i * 1.3) * 8)
			ok = clearOfIslands(cx, cz, 6, 0)
			if ok then
				break
			end
			d += 2
		end
		if ok then
			local y = -1 - (i - 1) * 3
			local p = decor(
				box(
					"PathCloud",
					cx - 6,
					y - B,
					cz - 6,
					cx + 6,
					y,
					cz + 6,
					"px_white_wool",
					CLOUD,
					cp
				)
			)
			p.CastShadow = false
			if i % 2 == 0 then
				local q = decor(
					box(
						"PathCloud",
						cx + 6,
						y - B,
						cz - 2,
						cx + 10,
						y - 1,
						cz + 6,
						"px_white_wool",
						CLOUD,
						cp
					)
				)
				q.CastShadow = false
			end
			x0, x1 = math.min(x0, cx - 10), math.max(x1, cx + 10)
			z0, z1 = math.min(z0, cz - 10), math.max(z1, cz + 10)
		end
		d += 13
	end
	if x0 < x1 then
		table.insert(CORRIDORS, { x0 - 12, x1 + 12, z0 - 12, z1 + 12, -40, 12 })
	end
end

-- ================================================================ 6. the floating islets
local islets = 0
do
	local fly = folder("FloatingIslets", yard)
	local cS = count
	local litFloat = 0
	local VINE_T = Color3.fromRGB(175, 210, 150)
	local function findSpot(half, down, up, yMin, yMax)
		for attempt = 1, 400 do
			if attempt % 100 == 0 then
				task.wait()
			end
			local x, z = rng:NextNumber(-420, 420), rng:NextNumber(-360, 340)
			local y = rng:NextNumber(yMin, yMax)
			local ok = not inCorridor(x - half, x + half, z - half, z + half, y - down, y + up)
				and clearOfIslands(x, z, half, 24)
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
	-- a broken arch: a tall and a short pillar, a lintel stub, a fallen block
	local function brokenArch(x, y, z, f)
		box(
			"ArchPillar",
			x - 6,
			y,
			z - 2,
			x - 2,
			y + 16,
			z + 2,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		box("ArchPillar", x + 2, y, z - 2, x + 6, y + 8, z + 2, "px_mossy_stone_bricks", nil, f)
		box(
			"ArchLintel",
			x - 6,
			y + 16,
			z - 2,
			x + 2,
			y + 20,
			z + 2,
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
		pc(
			"ArchFallen",
			Vector3.new(B, B, B),
			at(x + 3, y + 1.5, z + 5) * CFrame.Angles(0.3, 0.6, 0.2),
			"px_white_stone_bricks",
			WHITE_STONE,
			f
		)
	end
	local function bench(x, y, z, f)
		box("BenchLeg", x - 6, y, z - 2, x - 3, y + 2, z + 2, "px_stone_bricks", GREY_STONE, f)
		box("BenchLeg", x + 3, y, z - 2, x + 6, y + 2, z + 2, "px_stone_bricks", GREY_STONE, f)
		box(
			"BenchSeat",
			x - 7,
			y + 2,
			z - 2.5,
			x + 7,
			y + 3,
			z + 2.5,
			"px_smooth_stone",
			WHITE_STONE,
			f
		)
	end
	local function islet(x, y, z, w, d, L, kind)
		local f = folder("Islet", fly)
		local hx, hz = w * B / 2, d * B / 2
		box("IsletGrass", x - hx, y - B, z - hz, x + hx, y, z + hz, "px_grass_top", GRASS, f)
		-- a nub of ground on one edge
		if rng:NextNumber() < 0.5 and w >= 3 then
			local nz = if rng:NextNumber() < 0.5 then z - hz - B else z + hz
			local nx = x - hx + B * rng:NextInteger(0, w - 2)
			box("IsletGrass", nx, y - B, nz, nx + 2 * B, y, nz + B, "px_grass_top", GRASS, f)
			box("IsletRock", nx, y - 2 * B, nz, nx + 2 * B, y - B, nz + B, "px_dirt", nil, f)
		end
		local lh = if math.max(w, d) >= 6 then 2 * B else B
		local stepsX, stepsZ =
			math.max(0, math.floor((hx - 2) / B)), math.max(0, math.floor((hz - 2) / B))
		local top = y - B
		local sx, sz = hx, hz
		for i = 1, L do
			local v, t = "px_stone", PALE
			if i == 1 then
				v, t = "px_dirt", nil
			elseif rng:NextNumber() < 0.35 then
				v, t = "px_smooth_stone", WHITE_STONE
			elseif rng:NextNumber() < 0.3 then
				t = ROCK_LOW_T
			end
			sx = math.max(2, hx - B * math.floor((i - 1) * stepsX / math.max(1, L - 1) + 0.5))
			sz = math.max(2, hz - B * math.floor((i - 1) * stepsZ / math.max(1, L - 1) + 0.5))
			local h = if i == 1 then B else lh
			box("IsletRock", x - sx, top - h, z - sz, x + sx, top, z + sz, v, t, f)
			top -= h
		end
		-- the tip under one quarter of the last layer
		local tx = x - sx + B * rng:NextInteger(0, math.max(0, math.floor(sx * 2 / B) - 1))
		local tz = z - sz + B * rng:NextInteger(0, math.max(0, math.floor(sz * 2 / B) - 1))
		box(
			"IsletTip",
			tx,
			top - rng:NextInteger(1, 3) * B,
			tz,
			tx + B,
			top,
			tz + B,
			"px_stone",
			PALE,
			f
		)
		-- vines over an edge or two
		for _ = 1, rng:NextInteger(0, 2) do
			local len = rng:NextInteger(2, 4) * B
			local side = rng:NextInteger(1, 4)
			if side <= 2 then
				local fx = if side == 1 then x - hx - 0.6 else x + hx + 0.1
				local a = z - hz + B * rng:NextInteger(0, d - 1)
				box(
					"IsletVine",
					fx,
					y - 0.5 - len,
					a,
					fx + 0.5,
					y - 0.5,
					a + B,
					"px_hedge",
					VINE_T,
					f
				)
			else
				local fz = if side == 3 then z - hz - 0.6 else z + hz + 0.1
				local a = x - hx + B * rng:NextInteger(0, w - 1)
				box(
					"IsletVine",
					a,
					y - 0.5 - len,
					fz,
					a + B,
					y - 0.5,
					fz + 0.5,
					"px_hedge",
					VINE_T,
					f
				)
			end
		end
		-- the prop on top
		if kind == "grave" then
			if d >= 4 and w >= 3 then
				crossMark(x, z - 2, f, 1, y)
				mound(x, z - 2, 1, f, y)
			else
				headstone(x, z, f, y)
			end
		elseif kind == "graves" then
			headstone(x - 6, z - 2, f, y)
			crossMark(x + 5, z - 2, f, 1, y)
			mound(x + 5, z - 2, 1, f, y)
			candle(x - 9, y, z + 2, f, 1.3)
		elseif kind == "lantern" then
			if pillarLamp(x, z, f, litFloat < 3, y) then
				litFloat += 1
			end
		elseif kind == "cypress" then
			cypress(x, z, pick({ 16, 20, 24 }), f, y)
		elseif kind == "arch" then
			brokenArch(x, y, z, f)
		elseif kind == "bench" then
			bench(x, y, z, f)
		end
		if w >= 4 and rng:NextNumber() < 0.6 then
			flowers(x + (if rng:NextNumber() < 0.5 then -1 else 1) * (hx - 3), z + hz - 3, f, 2, y)
		end
		-- everything floating is decor
		for _, p in ipairs(f:GetDescendants()) do
			if p:IsA("BasePart") then
				decor(p)
			end
		end
	end
	local KINDS = { "grave", "lantern", "cypress", "arch", "bench", "graves", "grave", "cypress" }
	for i = 1, 30 do
		if islets >= 22 then
			break
		end
		local isBig = i <= 4
		local w = if isBig then rng:NextInteger(6, 8) else rng:NextInteger(2, 6)
		local d = math.clamp(w + rng:NextInteger(-1, 1), 2, 8)
		local L = math.clamp(math.floor(math.max(w, d) / 2) + rng:NextInteger(1, 2), 3, 6)
		local half = math.max(w, d) * B / 2 + B + 2
		local lh = if math.max(w, d) >= 6 then 2 * B else B
		local down = 2 * B + (L - 1) * lh + 3 * B
		local kind = KINDS[(i % #KINDS) + 1]
		if
			kind == "graves" and math.min(w, d) < 5
			or (kind == "arch" or kind == "bench") and math.min(w, d) < 4
		then
			kind = "grave"
		elseif kind == "cypress" and math.min(w, d) < 3 then
			kind = "lantern"
		end
		local up = if kind == "cypress" or kind == "arch" then 32 else 20
		local yMin, yMax = -60, 100
		if not isBig and rng:NextNumber() < 0.6 then
			yMin, yMax = -40, 40 -- most of them near the eye line of the islands
		end
		local x, y, z = findSpot(half, down, up, yMin, yMax)
		if x then
			islet(snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2, w, d, L, kind)
			islets += 1
		end
		if i % 5 == 0 then
			task.wait()
		end
	end
	print(("[build-church] yard: floating islets %d, %d parts"):format(islets, count - cS))
end
task.wait()

-- ================================================================ 7. the clouds: a layer under the islands, a few
-- round the edges
do
	local cl = folder("Clouds", yard)
	local cS = count
	local nLayer, nEdge = 0, 0
	local placed = {} -- { x0, x1, z0, z1, y0, y1 }
	local function cb(x0, y0, z0, x1, y1, z1)
		local p = decor(box("Cloud", x0, y0, z0, x1, y1, z1, "px_white_wool", CLOUD, cl))
		p.CastShadow = false
	end
	local function cloud(x, y, z, w, d, th)
		local hx, hz = w * B / 2, d * B / 2
		cb(x - hx, y, z - hz, x + hx, y + th * B, z + hz)
		for _ = 1, rng:NextInteger(1, 3) do
			local pw = rng:NextInteger(math.max(2, w // 3), math.max(2, w - 2))
			local pd = rng:NextInteger(math.max(2, d // 3), math.max(2, d - 2))
			local ox = B * rng:NextInteger(0, math.max(0, w - pw)) - hx
			local oz = B * rng:NextInteger(0, math.max(0, d - pd)) - hz
			cb(x + ox, y + th * B, z + oz, x + ox + pw * B, y + th * B + B, z + oz + pd * B)
		end
		if w >= 8 and rng:NextNumber() < 0.6 then
			local pw, pd = math.max(2, w // 2), math.max(2, d // 2)
			local ox = B * rng:NextInteger(0, w - pw) - hx
			local oz = B * rng:NextInteger(0, d - pd) - hz
			cb(x + ox, y - B, z + oz, x + ox + pw * B, y, z + oz + pd * B)
		end
	end
	local function overlaps(x0, x1, z0, z1, y0, y1)
		for _, p in ipairs(placed) do
			if
				x1 + 12 > p[1]
				and x0 - 12 < p[2]
				and z1 + 12 > p[3]
				and z0 - 12 < p[4]
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
	-- the highest top a cloud may have under the rock (and its stalactites) of the cells above it
	local function under(x0, x1, z0, z1)
		local lim = math.huge
		local nx, nz =
			math.max(1, math.ceil((x1 - x0) / 16)), math.max(1, math.ceil((z1 - z0) / 16))
		for i = 0, nx do
			for j = 0, nz do
				local isle, ccx, ccz = cellLand(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz)
				if isle then
					lim = math.min(lim, -B - rockDepth(ccx, ccz) - 10 * B - 8)
				end
			end
		end
		return lim
	end
	-- the layer under the islands, y -160..-240
	for _ = 1, 34 do
		for _ = 1, 40 do
			local w = rng:NextInteger(6, 24)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.5, 0.9)), 4, 18)
			local th = rng:NextInteger(1, 3)
			local x, z =
				snap(rng:NextNumber(-470, 470)) + (w % 2) * 2,
				snap(rng:NextNumber(-430, 410)) + (d % 2) * 2
			local y = snap(rng:NextNumber(-236, -168))
			local hx, hz = w * B / 2, d * B / 2
			local lim = under(x - hx, x + hx, z - hz, z + hz)
			if y + (th + 1) * B > lim then
				y = math.floor((lim - (th + 1) * B) / B) * B
			end
			if
				y - B >= -244
				and not overlaps(x - hx, x + hx, z - hz, z + hz, y - B, y + (th + 1) * B)
			then
				cloud(x, y, z, w, d, th)
				table.insert(placed, { x - hx, x + hx, z - hz, z + hz, y - B, y + (th + 1) * B })
				nLayer += 1
				break
			end
		end
	end
	task.wait()
	-- a few round the edges at the islands' height, clear of the islands and the corridors
	for _ = 1, 12 do
		for _ = 1, 60 do
			local w = rng:NextInteger(6, 16)
			local d = math.clamp(math.floor(w * rng:NextNumber(0.4, 0.8)), 3, 10)
			local th = rng:NextInteger(1, 2)
			local x, z =
				snap(rng:NextNumber(-470, 470)) + (w % 2) * 2,
				snap(rng:NextNumber(-430, 410)) + (d % 2) * 2
			local y = snap(rng:NextNumber(-40, 26))
			local hx, hz = w * B / 2, d * B / 2
			local y0, y1 = y - B, y + (th + 1) * B
			if
				clearOfIslands(x, z, math.max(hx, hz), 16)
				and not inCorridor(x - hx, x + hx, z - hz, z + hz, y0, y1)
				and not overlaps(x - hx, x + hx, z - hz, z + hz, y0, y1)
			then
				cloud(x, y, z, w, d, th)
				table.insert(placed, { x - hx, x + hx, z - hz, z + hz, y0, y1 })
				nEdge += 1
				break
			end
		end
	end
	print(
		("[build-church] yard: clouds %d under, %d at the edges, %d parts"):format(
			nLayer,
			nEdge,
			count - cS
		)
	)
end
print(("[build-church] yard: %d parts, %d lights"):format(count - c0, lights))
