--!nocheck
-- ================================================================ eden: the north gardens, the bridges, the falls, under the island, the sky
-- My zone: zoneOf(x, z) == "north" (z ≤ -52 outside r 100 round the hill) + under the island + the sky.
-- 1. Pink cherry-plank arched bridges (deck 4 blocks wide, top y 0.1 on the banks, a hump of 0.8 a plank, fence
--    rails, a lantern post at each end) over the WEST river at x -158..-142, the EAST river at x 142..158 (decks along
--    z, the gap measured from core's cells) and the NORTH river at z -186..-170 (deck along x).
-- 2. The north-west and north-east gardens (mirrored round x 0): coarse dirt walks 4 blocks wide (x ∓158..∓142 from the
--    W/E bridges north to z -186, then z -186..-170 to the north bridge) under leaf arches, lamp posts; a green-roofed
--    gazebo at (∓112, -134); a pond with lily pads and jets (north-west), a beehive tree and a bamboo grove (north-east);
--    apple trees, pink cherry trees, flower beds in single-colour rows, trellises, mossy stone arch ruins, benches,
--    deer and rabbits; reeds on the banks, lily pads on the rivers, stepping stones over the W/E rivers at x ∓196.
-- 3. Waterfalls where the three rivers leave the island: a lip, a column of px_water 37 blocks down, widening, a white
--    wool foam cloud and a slow mist at the bottom; dense vines and flowers on the cliff beside them.
-- 4. Under the whole island: vines (px_hedge / wisteria / cherry leaves) down the rim faces and under the bottom,
--    stepped grey stone tips under the columns (core's rockDepth replicated), denser at the rim.
-- 5. Floating grassy islets with a tree / flower bed / beehive / deer / lantern; 6. blocky wool clouds.
local northF = folder("NorthGarden")
local startCount = count
local lit = 0 -- PointLights made by this part (≤ 20)
local ROCK_LOW = Color3.fromRGB(176, 176, 180) -- core's rockLowTint
local ROCK_TOP = Color3.fromRGB(150, 110, 80) -- core's rockTopTint
local FALL = Color3.fromRGB(120, 176, 236)
local CLOUD = Color3.fromRGB(250, 252, 255)
local FLOWERS = {
	Color3.fromRGB(206, 50, 46), -- red
	Color3.fromRGB(240, 206, 60), -- yellow
	Color3.fromRGB(86, 120, 220), -- blue
	Color3.fromRGB(240, 240, 236), -- white
	PINK_WOOL,
	Color3.fromRGB(232, 140, 50), -- orange
	Color3.fromRGB(150, 92, 200), -- purple
}
local claimed = {} -- { x0, z0, x1, z1 } taken on the island by this part
local DECKS = {} -- name → { x0, z0, x1, z1 } of the bridge decks
local FALLS = {} -- { alongX, dir, outer, v0, v1 } of the waterfalls
local CORR = {} -- { x0, x1, z0, z1, y0, y1 }: the floaters keep off (in front of the falls)
local tipLow = {} -- cell key → the lowest y hanging under that cell (for the clouds)

-- a hanging lantern at local (x, y, z) on a chain up to local hangTop; lit up to the light budget
local function lamp(x, y, z, parent, hangTop, dark)
	local f = folder("Lantern", parent)
	lantern(V(x, y, z), f, false, if hangTop then BY + hangTop else nil)
	if not dark then
		lit += 1
	end
	if dark or lit > 20 then
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("PointLight") then
				d:Destroy()
			end
		end
	end
	return f
end
-- core's rockDepth (10-core is wrapped in its own do … end): the column of a cell is the ground block (top - 4 .. top),
-- then rock down to top - 4 - depth
local function rockDepth(x, z)
	local e = math.clamp(((math.abs(x) / HALF) ^ 4 + (math.abs(z) / HALF) ^ 4) ^ 0.25, 0, 1)
	local d = 16 + (1 - e) ^ 1.2 * 140 + math.max(0, groundY(x, z) or 0)
	if e > 0.84 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 28
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
-- the centre of core's 8-stud cell holding v (cells -232 + 8k .. -224 + 8k)
local function cc(v)
	return math.floor((v + 232) / 8) * 8 - 228
end
local function claim(x0, z0, x1, z1)
	table.insert(claimed, { x0, z0, x1, z1 })
end
-- the rectangle is free: in the north zone well off the hill part, `inset` studs inside the island, off the rivers
-- and off what is claimed
local function okArea(x0, z0, x1, z1, inset)
	for _, r in ipairs(claimed) do
		if x1 > r[1] and x0 < r[3] and z1 > r[2] and z0 < r[4] then
			return false
		end
	end
	local nx, nz = math.max(1, math.ceil((x1 - x0) / 4)), math.max(1, math.ceil((z1 - z0) / 4))
	for i = 0, nx do
		for j = 0, nz do
			local x, z = x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz
			if
				zoneOf(x, z) ~= "north"
				or hillDist(x, z) < 108
				or not onIsland(x, z, inset or 10)
				or onRiver(x, z, 6)
			then
				return false
			end
		end
	end
	return true
end
-- a free w × d rectangle (studs) inside region r = { x0, z0, x1, z1 }: its corner, claimed; nil if none found
local function place(r, w, d, inset)
	for _ = 1, 80 do
		local x0 = snap(rng:NextNumber(r[1], math.max(r[1], r[3] - w)))
		local z0 = snap(rng:NextNumber(r[2], math.max(r[2], r[4] - d)))
		if okArea(x0, z0, x0 + w, z0 + d, inset) then
			claim(x0 - 2, z0 - 2, x0 + w + 2, z0 + d + 2)
			return x0, z0
		end
	end
	return nil
end
-- floating things are decor
local function finish(f, solid)
	if not solid then
		for _, d in ipairs(f:GetDescendants()) do
			if d:IsA("BasePart") then
				decor(d)
			end
		end
	end
	return f
end
-- one flower: a green stem and a coloured head (decor)
local function flower(x, y, z, parent, color)
	decor(
		box("FlowerStem", x - 0.2, y, z - 0.2, x + 0.2, y + 1.4, z + 0.2, "px_hedge", LEAF, parent)
	)
	decor(
		box(
			"Flower",
			x - 0.55,
			y + 1.2,
			z - 0.55,
			x + 0.55,
			y + 2.2,
			z + 0.55,
			"px_white_wool",
			color or pick(FLOWERS),
			parent
		)
	)
end
-- an apple tree: an oak trunk, a stepped crown of leaves (a cross, a layer, a top block) with red apples; returns the
-- folder and the crown bottom y
local function appleTree(x, z, parent, y0, solid, noApples)
	y0 = y0 or 0
	local f = folder("AppleTree", parent)
	local h = rng:NextInteger(3, 4) * B
	box("Trunk", x - 2, y0, z - 2, x + 2, y0 + h + 4, z + 2, "px_oak_log", nil, f)
	local c = y0 + h
	box("Crown", x - 10, c, z - 6, x + 10, c + 8, z + 6, "px_hedge", LEAF, f)
	box("Crown", x - 6, c, z - 10, x + 6, c + 8, z + 10, "px_hedge", LEAF, f)
	box("Crown", x - 6, c + 8, z - 6, x + 6, c + 12, z + 6, "px_hedge", LEAF, f)
	box("Crown", x - 2, c + 12, z - 2, x + 2, c + 16, z + 2, "px_hedge", LEAF, f)
	if not noApples then
		for _ = 1, 8 do
			local s = rng:NextInteger(1, 4)
			local a = rng:NextInteger(-3, 3) * 1.5
			local y = c + rng:NextInteger(1, 6) + 0.5
			local px, pz
			if s == 1 then
				px, pz = x + 10.4, z + a
			elseif s == 2 then
				px, pz = x - 10.4, z + a
			elseif s == 3 then
				px, pz = x + a, z + 10.4
			else
				px, pz = x + a, z - 10.4
			end
			decor(cube("Apple", px, y, pz, 1.8, 1.8, 1.8, "px_white_wool", APPLE, f))
		end
		-- one fallen in the grass
		decor(
			cube(
				"Apple",
				x + pick({ -7, 6 }),
				y0 + 0.9,
				z + pick({ -6, 7 }),
				1.8,
				1.8,
				1.8,
				"px_white_wool",
				APPLE,
				f
			)
		)
	end
	return finish(f, solid), c
end
-- a pink cherry tree: a cherry log trunk with a side branch, a wide flat crown of blossom, hanging drips, petals
local function cherryTree(x, z, parent, y0, solid)
	y0 = y0 or 0
	local f = folder("CherryTree", parent)
	local h = rng:NextInteger(3, 4) * B
	box("Trunk", x - 2, y0, z - 2, x + 2, y0 + h + 4, z + 2, "px_cherry_log", nil, f)
	local ox, oz = pick({ { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } })[1], 0
	if ox == 0 then
		oz = pick({ 4, -4 })
	end
	box(
		"Branch",
		x - 2 + ox,
		y0 + h - 2,
		z - 2 + oz,
		x + 2 + ox,
		y0 + h + 4,
		z + 2 + oz,
		"px_cherry_log",
		nil,
		f
	)
	local c = y0 + h + 4
	box("Blossom", x - 14, c, z - 10, x + 14, c + 6, z + 10, "px_cherry_leaves", BLOSSOM, f)
	box("Blossom", x - 10, c, z - 14, x + 10, c + 6, z + 14, "px_cherry_leaves", BLOSSOM, f)
	box(
		"Blossom",
		x - 8 + ox,
		c + 6,
		z - 8 + oz,
		x + 8 + ox,
		c + 10,
		z + 8 + oz,
		"px_cherry_leaves",
		BLOSSOM,
		f
	)
	for _ = 1, 5 do
		local len = rng:NextInteger(2, 4) * 2
		local px, pz
		if rng:NextNumber() < 0.5 then
			px, pz = x + pick({ -13, 11 }), z + rng:NextInteger(-4, 3) * 2
		else
			px, pz = x + rng:NextInteger(-4, 3) * 2, z + pick({ -13, 11 })
		end
		decor(
			box("BlossomDrip", px, c - len, pz, px + 2, c, pz + 2, "px_cherry_leaves", BLOSSOM, f)
		)
	end
	local petals = decor(
		box(
			"Petals",
			x - 8,
			y0 + 0.06,
			z - 8,
			x + 8,
			y0 + 0.14,
			z + 8,
			"px_cherry_leaves",
			BLOSSOM,
			f
		)
	)
	petals.Transparency = 0.35
	petals.CastShadow = false
	return finish(f, solid)
end
-- a flower bed: soil, then rows (one block wide) of a single colour each: leaves and a flower head on every block
local function flowerBed(x0, z0, w, d, parent, colors, y0)
	y0 = y0 or 0
	local f = folder("FlowerBed", parent)
	box(
		"BedSoil",
		x0,
		y0 - 0.3,
		z0,
		x0 + w * B,
		y0 + 0.3,
		z0 + d * B,
		"px_dirt",
		Color3.fromRGB(150, 120, 96),
		f
	)
	local alongX = w >= d
	local rows, len = if alongX then d else w, if alongX then w else d
	for r = 0, rows - 1 do
		local col = colors[r % #colors + 1]
		local a = r * B
		if alongX then
			decor(
				box(
					"BedLeaves",
					x0 + 0.6,
					y0 + 0.3,
					z0 + a + 0.8,
					x0 + w * B - 0.6,
					y0 + 1.3,
					z0 + a + 3.2,
					"px_hedge",
					LEAF,
					f
				)
			)
		else
			decor(
				box(
					"BedLeaves",
					x0 + a + 0.8,
					y0 + 0.3,
					z0 + 0.6,
					x0 + a + 3.2,
					y0 + 1.3,
					z0 + d * B - 0.6,
					"px_hedge",
					LEAF,
					f
				)
			)
		end
		for k = 0, len - 1 do
			local px = if alongX then x0 + k * B + 2 else x0 + a + 2
			local pz = if alongX then z0 + a + 2 else z0 + k * B + 2
			decor(cube("BedFlower", px, y0 + 1.8, pz, 1.6, 1.2, 1.6, "px_white_wool", col, f))
		end
	end
	return f
end
-- a blocky deer facing local -Z turned by yaw (the body solid on the island)
local function deer(x, z, yaw, parent, y0, solid)
	y0 = y0 or 0
	local f = folder("Deer", parent)
	local cf = at(x, y0, z) * CFrame.Angles(0, yaw, 0)
	local FUR, DARK, HORN =
		Color3.fromRGB(235, 205, 175), Color3.fromRGB(160, 130, 110), Color3.fromRGB(225, 200, 160)
	local function dp(name, sx, sy, sz, ox, oy, oz, v, t)
		local p = textured(
			part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), nil, nil, f),
			v,
			t
		)
		if name ~= "DeerBody" or not solid then
			decor(p)
		end
		return p
	end
	dp("DeerBody", 2.6, 2.8, 5.2, 0, 4.6, 0, "px_brown_wool", FUR)
	for _, l in ipairs({ { -0.8, -1.8 }, { 0.8, -1.8 }, { -0.8, 1.8 }, { 0.8, 1.8 } }) do
		dp("DeerLeg", 0.9, 3.4, 0.9, l[1], 1.7, l[2], "px_brown_wool", DARK)
	end
	dp("DeerNeck", 1.4, 2.6, 1.6, 0, 6.6, -2.3, "px_brown_wool", FUR)
	dp("DeerHead", 1.8, 1.8, 2.6, 0, 8.1, -3.1, "px_brown_wool", FUR)
	dp("DeerSnout", 1.2, 1, 1, 0, 7.7, -4.8, "px_brown_wool", DARK)
	dp("DeerChest", 1.6, 1.6, 0.3, 0, 5.2, -2.65, "px_white_wool", nil)
	dp("DeerTail", 0.8, 1, 0.4, 0, 5.4, 2.75, "px_white_wool", nil)
	for _, s in ipairs({ -1, 1 }) do
		dp("DeerEar", 0.8, 0.5, 0.5, s * 1.2, 8.7, -2.6, "px_brown_wool", FUR)
		dp("Antler", 0.4, 2.4, 0.4, s * 0.6, 10.2, -2.8, "px_planks", HORN)
		dp("Antler", 1.6, 0.4, 0.4, s * 1.2, 10.4, -2.8, "px_planks", HORN)
		dp("Antler", 0.4, 0.4, 1.6, s * 0.6, 11.2, -2.4, "px_planks", HORN)
	end
	return f
end
-- a rabbit (decor)
local function rabbit(x, z, yaw, parent, y0)
	y0 = y0 or 0
	local f = folder("Rabbit", parent)
	local cf = at(x, y0, z) * CFrame.Angles(0, yaw, 0)
	local v, t =
		pick({ { "px_white_wool", nil }, { "px_brown_wool", Color3.fromRGB(235, 210, 185) } })[1],
		nil
	if v == "px_brown_wool" then
		t = Color3.fromRGB(235, 210, 185)
	end
	local function rp(name, sx, sy, sz, ox, oy, oz)
		decor(
			textured(
				part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(ox, oy, oz), nil, nil, f),
				v,
				t
			)
		)
	end
	rp("RabbitBody", 1.4, 1.4, 2, 0, 0.7, 0)
	rp("RabbitHead", 1.2, 1.2, 1.2, 0, 1.6, -1)
	rp("RabbitEar", 0.3, 1.1, 0.5, -0.3, 2.7, -1)
	rp("RabbitEar", 0.3, 1.1, 0.5, 0.3, 2.7, -1)
	return f
end
-- a beehive under a crown (x, y, z: the hive centre) with three bees round it (decor)
local function beehive(x, y, z, parent)
	local f = folder("Beehive", parent)
	decor(cube("Beehive", x, y, z, 3, 3.4, 3, "px_planks", Color3.fromRGB(240, 205, 120), f))
	decor(
		cube(
			"HiveBand",
			x,
			y + 0.6,
			z,
			3.15,
			0.6,
			3.15,
			"px_planks",
			Color3.fromRGB(205, 155, 80),
			f
		)
	)
	decor(cube("HiveDoor", x, y - 0.8, z - 1.55, 1, 0.8, 0.12, nil, Color3.fromRGB(40, 30, 20), f))
	for i = 1, 3 do
		local a = i * 2.1
		local bx, by, bz =
			x + math.cos(a) * 3.4, y + rng:NextNumber(-1.5, 1.5), z + math.sin(a) * 3.4
		decor(cube("Bee", bx, by, bz, 1.2, 1, 1.4, "px_yellow_wool", nil, f))
		decor(cube("BeeStripe", bx, by, bz, 1.25, 1.05, 0.4, nil, Color3.fromRGB(30, 26, 22), f))
		local wing =
			decor(cube("BeeWing", bx, by + 0.6, bz, 1.6, 0.12, 0.7, "px_white_wool", nil, f))
		wing.Transparency = 0.3
	end
	return f
end
-- a garden bench facing local -Z (yaw turns it); y0 the floor
local function bench(x, z, yaw, parent, y0)
	local cf = at(x, y0 or 0, z) * CFrame.Angles(0, yaw, 0)
	local function bp(name, size, off, v)
		return textured(part(name, size, cf * off, nil, nil, parent), v)
	end
	bp("BenchSeat", Vector3.new(8, 0.6, 2.6), CFrame.new(0, 1.9, 0), "px_spruce_planks")
	bp("BenchLeg", Vector3.new(0.8, 1.6, 2.2), CFrame.new(-3.4, 0.8, 0), "px_dark_oak_planks")
	bp("BenchLeg", Vector3.new(0.8, 1.6, 2.2), CFrame.new(3.4, 0.8, 0), "px_dark_oak_planks")
	bp("BenchBack", Vector3.new(8, 2, 0.6), CFrame.new(0, 3.5, 1.2), "px_spruce_planks")
end

-- ================================================================ 1. the bridges over the rivers
do
	local bf = folder("Bridges", northF)
	-- the river bed across a deck band c0..c1 along u (x if alongX, else z) from the cells: g0, g1 (cell edges)
	local function gapOf(alongX, c0, c1, uFrom, uTo)
		local g0, g1
		for u = cc(uFrom), cc(uTo), 8 do
			for v = cc(c0), cc(c1 - 0.01), 8 do
				local x, z = if alongX then u else v, if alongX then v else u
				if onIsland(x, z) and groundY(x, z) == RIVER_BED then
					g0 = math.min(g0 or u - 4, u - 4)
					g1 = math.max(g1 or u + 4, u + 4)
				end
			end
		end
		return g0, g1
	end
	-- a pink arched bridge: the deck c0..c1 across, over the gap g0..g1 along u, 8 studs onto each bank
	local function bridge(name, alongX, c0, c1, uFrom, uTo)
		local g0, g1 = gapOf(alongX, c0, c1, uFrom, uTo)
		if not g0 then
			warn("[build-eden] north: no river under the " .. name .. " bridge")
			return
		end
		local f = folder(name .. "Bridge", bf)
		local a0, a1 = g0 - 8, g1 + 8
		local function bx(nm, u0, y0, v0, u1, y1, v1, variant, tint)
			if alongX then
				return box(nm, u0, y0, v0, u1, y1, v1, variant, tint, f)
			end
			return box(nm, v0, y0, u0, v1, y1, u1, variant, tint, f)
		end
		local n = math.floor((g1 - g0) / 4 + 0.5)
		local tops = {}
		local planks = math.floor((a1 - a0) / 4 + 0.5)
		for i = 0, planks - 1 do
			local j = i - 2
			tops[i] = if j >= 0 and j < n then 0.1 + 0.8 * math.min(j + 1, n - j) else 0.1
		end
		for i = 0, planks - 1 do
			local u0, top = a0 + i * 4, tops[i]
			bx("BridgeDeck", u0, top - 1, c0 - 1, u0 + 4, top, c1 + 1, "px_cherry_planks")
			if top > 0.2 then
				-- the stringers under the deck edges
				bx("BridgeBeam", u0, top - 2.2, c0 - 1, u0 + 4, top - 1, c0 + 1, "px_cherry_log")
				bx("BridgeBeam", u0, top - 2.2, c1 - 1, u0 + 4, top - 1, c1 + 1, "px_cherry_log")
			end
			-- the rails, one stepped piece a plank on each side, posts at the plank joints
			for _, v in ipairs({ c0 - 1, c1 }) do
				bx("BridgeRail", u0, top + 2.4, v, u0 + 4, top + 3.1, v + 1, "px_cherry_planks")
				if i > 0 then
					local pt = math.max(top, tops[i - 1])
					bx("BridgePost", u0 - 0.5, pt, v, u0 + 0.5, pt + 3.4, v + 1, "px_cherry_log")
				end
			end
		end
		-- the piers in the river at both banks
		for _, u in ipairs({ g0, g1 - 2 }) do
			for _, v in ipairs({ c0 - 1, c1 - 1 }) do
				bx("BridgePier", u, RIVER_BED, v, u + 2, 0, v + 2, "px_cherry_log")
			end
		end
		-- the end posts with lanterns (one lit at each end)
		for _, u in ipairs({ a0, a1 - 2 }) do
			for s, v in ipairs({ c0 - 2, c1 }) do
				bx("BridgeEndPost", u, -0.5, v, u + 2, 5, v + 2, "px_cherry_log")
				local px, pz = if alongX then u + 1 else v + 1, if alongX then v + 1 else u + 1
				lamp(px, 5.75, pz, f, nil, s == 2)
			end
		end
		local r = if alongX then { a0, c0 - 2, a1, c1 + 2 } else { c0 - 2, a0, c1 + 2, a1 }
		DECKS[name] = r
		claim(r[1] - 4, r[2] - 4, r[3] + 4, r[4] + 4)
		print(
			("[build-eden] north: %s bridge deck %d..%d over the gap %d..%d"):format(
				name,
				a0,
				a1,
				g0,
				g1
			)
		)
	end
	bridge("West", false, -158, -142, -100, -20)
	bridge("East", false, 142, 158, -100, -20)
	bridge("North", true, -186, -170, -40, 40)
end
task.wait()

-- ================================================================ 2. the north-west and north-east gardens
do
	local gf = folder("Gardens", northF)
	-- a coarse dirt walk (flush) along u from a0 to a1, across c0..c1; only where the island holds it
	local function walk(alongX, a0, a1, c0, c1, parent)
		local u0 = math.min(a0, a1)
		local u1 = math.max(a0, a1)
		local runStart
		local function flush(uEnd)
			if runStart and uEnd > runStart then
				if alongX then
					box("Walk", runStart, -0.3, c0, uEnd, 0.05, c1, "px_dirt", PATH, parent)
				else
					box("Walk", c0, -0.3, runStart, c1, 0.05, uEnd, "px_dirt", PATH, parent)
				end
			end
			runStart = nil
		end
		for u = u0, u1 - 4, 4 do
			local ok = true
			for _, v in ipairs({ c0, (c0 + c1) / 2, c1 }) do
				local x, z = if alongX then u + 2 else v, if alongX then v else u + 2
				if not onIsland(x, z, 4) or onRiver(x, z, 0) then
					ok = false
				end
			end
			if ok then
				runStart = runStart or u
			else
				flush(u)
			end
		end
		flush(u1)
		if alongX then
			claim(u0 - 4, c0 - 4, u1 + 4, c1 + 4)
		else
			claim(c0 - 4, u0 - 4, c1 + 4, u1 + 4)
		end
	end
	-- a leaf arch over a walk running along u (x if alongX) across c0..c1, at u
	local function leafArch(alongX, u, c0, c1, parent)
		local f = folder("LeafArch", parent)
		local function ab(name, u0, y0, v0, u1, y1, v1, v, t)
			if alongX then
				return box(name, u0, y0, v0, u1, y1, v1, v, t, f)
			end
			return box(name, v0, y0, u0, v1, y1, u1, v, t, f)
		end
		for _, s in ipairs({ { c0 - 4, c0 }, { c1, c1 + 4 } }) do
			ab("ArchBase", u - 2, -0.3, s[1], u + 2, 4, s[2], "px_mossy_stone_bricks")
			ab("ArchLeaves", u - 2, 4, s[1], u + 2, 16, s[2], "px_hedge", LEAF)
		end
		ab("ArchTop", u - 2, 16, c0 - 4, u + 2, 20, c1 + 4, "px_hedge", LEAF)
		ab("ArchCorner", u - 2, 12, c0, u + 2, 16, c0 + 4, "px_hedge", LEAF)
		ab("ArchCorner", u - 2, 12, c1 - 4, u + 2, 16, c1, "px_hedge", LEAF)
		decor(
			ab("ArchBloom", u - 2.4, 18, c0 + 2, u + 2.4, 20.8, c1 - 2, "px_cherry_leaves", BLOSSOM)
		)
		-- flowers on the faces of the legs, wisteria hanging from the corners
		for _ = 1, 6 do
			local side = pick({ -2.5, 2.5 })
			local v = pick({ c0 - 2, c1 + 2 }) + rng:NextNumber(-1.2, 1.2)
			local y = rng:NextNumber(5, 15)
			decor(
				ab(
					"ArchFlower",
					u + side - 0.7,
					y,
					v - 0.7,
					u + side + 0.7,
					y + 1.4,
					v + 0.7,
					"px_white_wool",
					pick({ PINK_WOOL, FLOWERS[7], FLOWERS[4], FLOWERS[2] })
				)
			)
		end
		for _, v in ipairs({ c0 + 0.5, c1 - 2 }) do
			local len = rng:NextInteger(2, 4) * 1.5
			decor(
				ab("ArchWisteria", u - 0.8, 12 - len, v, u + 0.8, 12, v + 1.5, "px_wisteria_leaves")
			)
		end
		return f
	end
	-- a green-roofed gazebo (5×5 blocks) on a mossy stone floor, lanterns under the roof, two benches
	local function gazebo(cx, cz, parent)
		local f = folder("Gazebo", parent)
		box(
			"GazeboFloor",
			cx - 10,
			-0.4,
			cz - 10,
			cx + 10,
			1,
			cz + 10,
			"px_mossy_stone_bricks",
			nil,
			f
		)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local px, pz = cx + sx * 8, cz + sz * 8
				box(
					"GazeboPlinth",
					px - 2,
					1,
					pz - 2,
					px + 2,
					5,
					pz + 2,
					"px_mossy_stone_bricks",
					nil,
					f
				)
				box("GazeboPost", px - 1, 5, pz - 1, px + 1, 13, pz + 1, "px_oak_log", nil, f)
				if rng:NextNumber() < 0.6 then
					local len = rng:NextInteger(4, 8)
					decor(
						box(
							"GazeboVine",
							px + sx * 1,
							13 - len,
							pz - 1,
							px + sx * 1.4,
							13,
							pz + 1,
							"px_hedge",
							LEAF,
							f
						)
					)
					flower(px + sx * 1.6, 13 - len - 1.5, pz, f, PINK_WOOL)
				end
			end
		end
		-- the eave beams and the stepped green roof
		box("GazeboBeam", cx - 9, 12, cz - 9, cx + 9, 13.4, cz - 7, "px_spruce_planks", nil, f)
		box("GazeboBeam", cx - 9, 12, cz + 7, cx + 9, 13.4, cz + 9, "px_spruce_planks", nil, f)
		box("GazeboBeam", cx - 9, 12, cz - 7, cx - 7, 13.4, cz + 7, "px_spruce_planks", nil, f)
		box("GazeboBeam", cx + 7, 12, cz - 7, cx + 9, 13.4, cz + 7, "px_spruce_planks", nil, f)
		box(
			"GazeboRoof",
			cx - 14,
			13.4,
			cz - 14,
			cx + 14,
			14.6,
			cz + 14,
			"px_spruce_planks",
			ROOF_GREEN,
			f
		)
		box(
			"GazeboRoof",
			cx - 11,
			14.6,
			cz - 11,
			cx + 11,
			16.6,
			cz + 11,
			"px_spruce_planks",
			ROOF_GREEN,
			f
		)
		box(
			"GazeboRoof",
			cx - 7,
			16.6,
			cz - 7,
			cx + 7,
			18.6,
			cz + 7,
			"px_spruce_planks",
			ROOF_GREEN,
			f
		)
		box(
			"GazeboRoof",
			cx - 3,
			18.6,
			cz - 3,
			cx + 3,
			20.6,
			cz + 3,
			"px_spruce_planks",
			ROOF_GREEN,
			f
		)
		box("GazeboTip", cx - 1, 20.6, cz - 1, cx + 1, 22.6, cz + 1, "px_oak_log", nil, f)
		lamp(cx - 6, 10, cz - 6, f, 13.4)
		lamp(cx + 6, 10, cz + 6, f, 13.4)
		bench(cx, cz + 5, 0, f, 1)
		bench(cx, cz - 5, math.pi, f, 1)
		return f
	end
	-- a pond (w × d studs) in a low mossy cobblestone rim: dark bed, a water layer, lily pads, two jets, reeds
	local function pond(x0, z0, w, d, parent)
		local f = folder("Pond", parent)
		local x1, z1 = x0 + w, z0 + d
		box(
			"PondBed",
			x0 + 2,
			-0.3,
			z0 + 2,
			x1 - 2,
			0.1,
			z1 - 2,
			"px_dirt",
			Color3.fromRGB(84, 76, 70),
			f
		)
		local water =
			decor(box("PondWater", x0 + 2, 0.1, z0 + 2, x1 - 2, 0.9, z1 - 2, "px_water", WATER, f))
		water.Transparency = 0.3
		water.CastShadow = false
		box("PondRim", x0, -0.3, z0, x1, 1.2, z0 + 2, "px_mossy_cobblestone", nil, f)
		box("PondRim", x0, -0.3, z1 - 2, x1, 1.2, z1, "px_mossy_cobblestone", nil, f)
		box("PondRim", x0, -0.3, z0 + 2, x0 + 2, 1.2, z1 - 2, "px_mossy_cobblestone", nil, f)
		box("PondRim", x1 - 2, -0.3, z0 + 2, x1, 1.2, z1 - 2, "px_mossy_cobblestone", nil, f)
		for _ = 1, 7 do
			local px, pz = rng:NextNumber(x0 + 4, x1 - 5), rng:NextNumber(z0 + 4, z1 - 5)
			decor(
				box(
					"LilyPad",
					px,
					0.92,
					pz,
					px + 2.4,
					1.04,
					pz + 2.4,
					"px_hedge",
					Color3.fromRGB(150, 210, 110),
					f
				)
			)
			if rng:NextNumber() < 0.35 then
				decor(
					cube(
						"LilyFlower",
						px + 1.2,
						1.4,
						pz + 1.2,
						0.9,
						0.8,
						0.9,
						"px_white_wool",
						PINK_WOOL,
						f
					)
				)
			end
		end
		for _, j in ipairs({ { x0 + w * 0.35, z0 + d * 0.5 }, { x0 + w * 0.65, z0 + d * 0.45 } }) do
			local jet = decor(
				box(
					"PondJet",
					j[1] - 0.5,
					0.9,
					j[2] - 0.5,
					j[1] + 0.5,
					4.4,
					j[2] + 0.5,
					"px_water",
					FALL,
					f
				)
			)
			jet.Transparency = 0.35
			local foam = decor(
				box(
					"PondFoam",
					j[1] - 0.9,
					4.2,
					j[2] - 0.9,
					j[1] + 0.9,
					4.8,
					j[2] + 0.9,
					"px_white_wool",
					CLOUD,
					f
				)
			)
			foam.Transparency = 0.3
		end
		for _, c in ipairs({ { x0 + 1, z0 + 1 }, { x1 - 1, z1 - 1 } }) do
			for k = 1, 3 do
				local px, pz = c[1] + rng:NextNumber(-0.8, 0.8), c[2] + rng:NextNumber(-0.8, 0.8)
				local h = 2.5 + k * 0.6
				decor(
					box(
						"Reed",
						px - 0.25,
						1.2,
						pz - 0.25,
						px + 0.25,
						1.2 + h,
						pz + 0.25,
						"px_hedge",
						GRASS,
						f
					)
				)
			end
		end
		return f
	end
	-- a mossy stone arch ruin: a tall pillar with a broken lintel, a short broken pillar, fallen blocks, vines
	local function archRuin(x, z, alongX, parent)
		local f = folder("ArchRuin", parent)
		local function rb(name, u0, y0, v0, u1, y1, v1, v, t)
			if alongX then
				return box(name, x + v0, y0, z + u0, x + v1, y1, z + u1, v, t, f)
			end
			return box(name, x + u0, y0, z + v0, x + u1, y1, z + v1, v, t, f)
		end
		rb("RuinPillar", -2, -0.3, -8, 2, 8, -4, "px_mossy_stone_bricks")
		rb("RuinPillar", -2, 8, -8, 2, 16, -4, "px_mossy_cobblestone")
		rb("RuinCap", -3, 16, -9, 3, 17.4, -3, "px_stone_bricks", ROCK_LOW)
		rb("RuinLintel", -2, 17.4, -8, 2, 21.4, 2, "px_mossy_stone_bricks")
		rb("RuinCorner", -2, 13.4, -4, 2, 17.4, 0, "px_mossy_stone_bricks")
		rb("RuinPillar", -2, -0.3, 4, 2, 6, 8, "px_mossy_stone_bricks")
		rb("RuinPillar", -2, 6, 4, 2, 10, 6, "px_mossy_cobblestone")
		rb("RuinFallen", 3, -0.3, 9, 7, 4, 13, "px_mossy_cobblestone")
		rb("RuinFallen", -7, -0.3, 6, -3, 2, 10, "px_mossy_stone_bricks")
		decor(rb("RuinMoss", -2.2, 21.2, -8.2, 2.2, 21.6, 2.2, "px_hedge", MOSS))
		decor(rb("RuinVine", -2.5, 9, -7.5, -2.1, 17.4, -5, "px_hedge", LEAF))
		decor(rb("RuinVine", 2.1, 12, -6, 2.5, 17.4, -4.5, "px_hedge", LEAF))
		decor(rb("RuinVine", -1.5, 12.6, -2, 1.5, 17.4, -0.6, "px_wisteria_leaves"))
		return f
	end
	-- a trellis (3 blocks wide) of spruce posts and slats with vines and flowers climbing it
	local function trellis(x, z, alongX, parent)
		local f = folder("Trellis", parent)
		local function tb(name, u0, y0, v0, u1, y1, v1, v, t)
			if alongX then
				return box(name, x + u0, y0, z + v0, x + u1, y1, z + v1, v, t, f)
			end
			return box(name, x + v0, y0, z + u0, x + v1, y1, z + u1, v, t, f)
		end
		tb("TrellisPost", -6.5, 0, -0.5, -5.5, 10, 0.5, "px_spruce_planks")
		tb("TrellisPost", 5.5, 0, -0.5, 6.5, 10, 0.5, "px_spruce_planks")
		tb("TrellisBeam", -7, 10, -0.6, 7, 11, 0.6, "px_spruce_planks")
		for _, y in ipairs({ 3.5, 7 }) do
			decor(tb("TrellisSlat", -5.5, y, -0.2, 5.5, y + 0.4, 0.2, "px_spruce_planks"))
		end
		for _, u in ipairs({ -3, 0, 3 }) do
			decor(tb("TrellisSlat", u - 0.2, 0, -0.2, u + 0.2, 10, 0.2, "px_spruce_planks"))
			local h = rng:NextNumber(4, 9.5)
			decor(tb("TrellisVine", u - 1.4, 0, 0.25, u + 1.4, h, 0.75, "px_hedge", LEAF))
			local fy = rng:NextNumber(2, h - 1)
			local col = pick({ PINK_WOOL, FLOWERS[7], FLOWERS[4] })
			decor(
				tb("TrellisFlower", u - 0.6, fy, 0.6, u + 0.6, fy + 1.2, 1.4, "px_white_wool", col)
			)
		end
		return f
	end
	-- a bamboo clump: tall thin stalks with leaf tufts (stalks solid)
	local function bamboo(x0, z0, w, d, parent)
		local f = folder("Bamboo", parent)
		for _ = 1, math.floor(w * d / 10) do
			local px, pz =
				x0 + rng:NextInteger(0, w / 2 - 1) * 2 + 0.5,
				z0 + rng:NextInteger(0, d / 2 - 1) * 2 + 0.5
			local h = rng:NextInteger(5, 11) * 2
			box(
				"BambooStalk",
				px,
				-0.3,
				pz,
				px + 1,
				h,
				pz + 1,
				"px_hedge",
				Color3.fromRGB(190, 235, 130),
				f
			)
			decor(
				box(
					"BambooLeaves",
					px - 1,
					h - 3,
					pz - 1,
					px + 2,
					h - 1.6,
					pz + 2,
					"px_hedge",
					LEAF,
					f
				)
			)
		end
		return f
	end
	local function lampPostL(x, z, yaw, parent)
		if not okArea(x - 2, z - 2, x + 2, z + 2, 6) then
			return
		end
		local f = folder("LampPost", parent)
		lampPost(x, z, f, false, yaw)
		lit += 1
		if lit > 20 then
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("PointLight") then
					d:Destroy()
				end
			end
		end
		claim(x - 3, z - 3, x + 3, z + 3)
	end

	local stats = { trees = 0, beds = 0 }
	local function garden(side)
		local name = if side < 0 then "NorthWest" else "NorthEast"
		local f = folder(name, gf)
		-- a region given in west coordinates, mirrored for the east
		local function R(x0, z0, x1, z1)
			if side < 0 then
				return { x0, z0, x1, z1 }
			end
			return { -x1, z0, -x0, z1 }
		end
		local A = R(-212, -200, -162, -76) -- west of the walk
		local Bq = R(-138, -168, -30, -76) -- between the walk and the hill
		local C = R(-150, -214, -12, -190) -- north of the cross walk
		local ALL = R(-214, -214, -12, -76)
		-- the walks: from the W/E bridge north, then across to the north bridge
		local deck = DECKS[if side < 0 then "West" else "East"]
		local nDeck = DECKS.North
		local wx0, wx1 = if side < 0 then -158 else 142, if side < 0 then -142 else 158
		local deckZ0 = if deck then deck[2] else -80
		walk(false, -186, deckZ0, wx0, wx1, f)
		local nEnd = if nDeck then (if side < 0 then nDeck[1] else nDeck[3]) else side * 16
		walk(true, if side < 0 then -158 else nEnd, if side < 0 then nEnd else 158, -186, -170, f)
		-- leaf arches over them, lamp posts beside them
		leafArch(false, -104, wx0, wx1, f)
		leafArch(false, -146, wx0, wx1, f)
		leafArch(true, side * 112, -186, -170, f)
		leafArch(true, side * 60, -186, -170, f)
		claim(wx0 - 6, -152, wx1 + 6, -98)
		lampPostL(side * 164, -126, if side < 0 then -math.pi / 2 else math.pi / 2, f)
		lampPostL(side * 86, -192, math.pi, f)
		-- the gazebo
		gazebo(side * 112, -134, f)
		claim(side * 112 - 16, -150, side * 112 + 16, -118)
		-- the pond (north-west) or the beehive tree and the bamboo grove (north-east)
		if side < 0 then
			local px, pz = place(A, 28, 28, 8)
			if px then
				pond(px, pz, 28, 28, f)
			end
			local bx, bz = place(ALL, 8, 8, 10)
			if bx then
				bamboo(bx, bz, 8, 8, f)
			end
		else
			local tx, tz = place(Bq, 20, 20, 10)
			if tx then
				local tf, c = appleTree(tx + 10, tz + 10, f, 0, true, true)
				beehive(tx + 18, c - 2, tz + 10, tf)
				stats.trees += 1
			end
			for _ = 1, 2 do
				local bx, bz = place(ALL, 12, 12, 10)
				if bx then
					bamboo(bx, bz, 12, 12, f)
				end
			end
		end
		-- apple and cherry trees
		local apples, cherries = if side < 0 then 2 else 3, if side < 0 then 3 else 2
		for _ = 1, apples do
			local tx, tz = place(pick({ A, Bq, ALL }), 20, 20, 10)
			if tx then
				appleTree(tx + 10, tz + 10, f, 0, true)
				stats.trees += 1
			end
		end
		for _ = 1, cherries do
			local tx, tz = place(pick({ A, Bq, ALL }), 24, 24, 10)
			if tx then
				cherryTree(tx + 12, tz + 12, f, 0, true)
				stats.trees += 1
			end
		end
		task.wait()
		-- flower beds in single-colour rows
		for i = 1, 5 do
			local w, d = rng:NextInteger(4, 6), rng:NextInteger(3, 4)
			if rng:NextNumber() < 0.4 then
				w, d = d, w
			end
			local reg = if i == 5 then C else pick({ A, Bq, ALL })
			local bx, bz = place(reg, w * B, d * B, 8)
			if bx then
				local c1 = rng:NextInteger(1, #FLOWERS)
				local c2 = (c1 + rng:NextInteger(1, #FLOWERS - 1) - 1) % #FLOWERS + 1
				local cols = { FLOWERS[c1], FLOWERS[c2] }
				if rng:NextNumber() < 0.4 then
					table.insert(cols, FLOWERS[(c2 + 2) % #FLOWERS + 1])
				end
				flowerBed(bx, bz, w, d, f, cols)
				stats.beds += 1
			end
		end
		-- trellises by the gazebo and the walks, a ruin, benches, animals
		for _ = 1, if side < 0 then 2 else 1 do
			local alongX = rng:NextNumber() < 0.5
			local tx, tz = place(Bq, if alongX then 16 else 4, if alongX then 4 else 16, 8)
			if tx then
				trellis(tx + (if alongX then 8 else 2), tz + (if alongX then 2 else 8), alongX, f)
			end
		end
		do
			local alongX = rng:NextNumber() < 0.5
			local rx, rz = place(pick({ A, Bq }), 28, 28, 10)
			if rx then
				archRuin(rx + 14, rz + 14, alongX, f)
			end
		end
		if okArea(side * 166 - 2, -164, side * 166 + 2, -156, 8) then
			bench(side * 166, -160, if side < 0 then -math.pi / 2 else math.pi / 2, f)
			claim(side * 166 - 3, -165, side * 166 + 3, -155)
		end
		do
			local bx, bz = place(C, 8, 4, 8)
			if bx then
				bench(bx + 4, bz + 2, math.pi, f)
			end
		end
		for _ = 1, if side < 0 then 1 else 2 do
			local dx, dz = place(pick({ A, Bq }), 8, 8, 10)
			if dx then
				deer(dx + 4, dz + 4, rng:NextNumber(0, 2 * math.pi), f, 0, true)
			end
		end
		for _ = 1, 3 do
			local rx, rz = place(ALL, 4, 4, 10)
			if rx then
				rabbit(rx + 2, rz + 2, rng:NextNumber(0, 2 * math.pi), f)
			end
		end
		-- loose flowers in the grass
		for _ = 1, 14 do
			local fx, fz = rng:NextNumber(ALL[1], ALL[3]), rng:NextNumber(ALL[2], ALL[4])
			if okArea(fx - 1, fz - 1, fx + 1, fz + 1, 10) then
				flower(fx, 0, fz, f)
			end
		end
	end
	garden(-1)
	task.wait()
	garden(1)
	task.wait()

	-- reeds on the banks, lily pads on the rivers (my zone), stepping stones over the W/E rivers
	local rf = folder("RiverSide", northF)
	local reeds, pads = 0, 0
	local function nearDeck(x, z)
		for _, r in pairs(DECKS) do
			if inRect(x, z, r, 6) then
				return true
			end
		end
		return false
	end
	for cz = -228, -52, 8 do
		for cx = -228, 228, 8 do
			if
				onIsland(cx, cz, 6)
				and zoneOf(cx, cz) == "north"
				and hillDist(cx, cz) > 106
				and not nearDeck(cx, cz)
			then
				local gy = groundY(cx, cz)
				if gy == 0 and reeds < 160 and rng:NextNumber() < 0.35 then
					for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
						local nx, nz = cx + d[1] * 8, cz + d[2] * 8
						if onIsland(nx, nz) and groundY(nx, nz) == RIVER_BED then
							-- a bank cell next to the river, off the walks and the props
							local free = true
							for _, r in ipairs(claimed) do
								if
									cx + 4 > r[1]
									and cx - 4 < r[3]
									and cz + 4 > r[2]
									and cz - 4 < r[4]
								then
									free = false
									break
								end
							end
							if free then
								local bx, bz = cx + d[1] * 2.6, cz + d[2] * 2.6
								for k = 1, 3 do
									local px = bx
										+ (
											if d[1] == 0
												then rng:NextNumber(-3, 3)
												else rng:NextNumber(-0.8, 0.8)
										)
									local pz = bz
										+ (
											if d[2] == 0
												then rng:NextNumber(-3, 3)
												else rng:NextNumber(-0.8, 0.8)
										)
									local h = rng:NextNumber(2.5, 4.5)
									decor(
										box(
											"Reed",
											px - 0.25,
											-0.2,
											pz - 0.25,
											px + 0.25,
											h,
											pz + 0.25,
											"px_hedge",
											GRASS,
											rf
										)
									)
									reeds += 1
									if k == 1 and rng:NextNumber() < 0.5 then
										decor(
											box(
												"Cattail",
												px - 0.4,
												h - 1.2,
												pz - 0.4,
												px + 0.4,
												h + 0.2,
												pz + 0.4,
												"px_brown_wool",
												nil,
												rf
											)
										)
										reeds += 1
									end
								end
							end
							break
						end
					end
				elseif gy == RIVER_BED and pads < 70 and rng:NextNumber() < 0.08 then
					local px, pz = cx + rng:NextNumber(-3, 0.6), cz + rng:NextNumber(-3, 0.6)
					decor(
						box(
							"LilyPad",
							px,
							RIVER_TOP + 0.02,
							pz,
							px + 2.4,
							RIVER_TOP + 0.14,
							pz + 2.4,
							"px_hedge",
							Color3.fromRGB(150, 210, 110),
							rf
						)
					)
					pads += 1
					if rng:NextNumber() < 0.3 then
						decor(
							cube(
								"LilyFlower",
								px + 1.2,
								RIVER_TOP + 0.5,
								pz + 1.2,
								0.9,
								0.8,
								0.9,
								"px_white_wool",
								PINK_WOOL,
								rf
							)
						)
						pads += 1
					end
				end
			end
		end
	end
	-- stepping stones over the west and east rivers
	for _, sx in ipairs({ -196, 196 }) do
		local g0, g1
		for z = cc(-90), cc(-30), 8 do
			if onIsland(sx, z) and groundY(sx, z) == RIVER_BED then
				g0 = math.min(g0 or z - 4, z - 4)
				g1 = math.max(g1 or z + 4, z + 4)
			end
		end
		if g0 and onIsland(sx, g0, 10) and onIsland(sx, g1, 10) then
			local mid = (g0 + g1) / 2
			for _, z0 in ipairs({ g0 + 4, mid - 2, g1 - 8 }) do
				box(
					"SteppingStone",
					sx - 2,
					RIVER_BED,
					z0,
					sx + 2,
					0.3,
					z0 + 4,
					"px_mossy_cobblestone",
					nil,
					rf
				)
				decor(
					box(
						"StoneMoss",
						sx - 2.1,
						0.3,
						z0 + rng:NextNumber(0, 2),
						sx + 2.1,
						0.4,
						z0 + 4,
						"px_hedge",
						MOSS,
						rf
					)
				)
			end
		end
	end
	print(
		("[build-eden] north: gardens %d trees, %d beds, %d reed parts, %d lily parts"):format(
			stats.trees,
			stats.beds,
			reeds,
			pads
		)
	)
end
task.wait()

-- ================================================================ 3. the waterfalls off the edges
do
	local ff = folder("Waterfalls", northF)
	-- alongX: the river runs along x (outward ±x), else along z; rows: the across cell centres scanned from v0..v1;
	-- start: an along cell centre on the river
	local function fall(name, alongX, dir, start, v0, v1)
		local function cell(u, v)
			if alongX then
				return u, v
			end
			return v, u
		end
		local faces, a0, a1 = {}, nil, nil
		for v = cc(v0), cc(v1), 8 do
			local x, z = cell(start, v)
			if onIsland(x, z) and groundY(x, z) == RIVER_BED then
				local u = start
				for _ = 1, 40 do
					local nx, nz = cell(u + dir * 8, v)
					if onIsland(nx, nz) and groundY(nx, nz) == RIVER_BED then
						u += dir * 8
					else
						break
					end
				end
				faces[v] = u + dir * 4
				a0 = math.min(a0 or v - 4, v - 4)
				a1 = math.max(a1 or v + 4, v + 4)
			end
		end
		if not a0 then
			warn("[build-eden] north: no river end for the " .. name .. " waterfall")
			return
		end
		local outer
		for _, fu in pairs(faces) do
			outer = if outer == nil
				then fu
				elseif dir < 0 then math.min(outer, fu)
				else math.max(outer, fu)
		end
		local f = folder(name .. "Waterfall", ff)
		local function fb(nm, ua, ya, va, ub, yb, vb, tr, variant, tint)
			local x0, z0 = cell(ua, va)
			local x1, z1 = cell(ub, vb)
			local p = decor(box(nm, x0, ya, z0, x1, yb, z1, variant or "px_water", tint or FALL, f))
			p.Transparency = tr
			p.CastShadow = false
			return p
		end
		-- the lip of every row rolling over the edge
		for v, fu in pairs(faces) do
			fb("FallLip", fu - dir * 2, -3.4, v - 4, outer + dir * 1.6, -0.6, v + 4, 0.3)
		end
		local mid, hw = (a0 + a1) / 2, (a1 - a0) / 2
		local steps = { -- { top, bottom, out, thick, widen }
			{ -1, -30, 0, 2, 0 },
			{ -30, -60, 0.6, 2.4, 1 },
			{ -60, -90, 1.2, 2.8, 2 },
			{ -90, -120, 1.8, 3.2, 3 },
			{ -120, -150, 2.4, 3.6, 4 },
		}
		for _, s in ipairs(steps) do
			local u0, u1 = outer + dir * s[3], outer + dir * (s[3] + s[4])
			local w = hw + s[5]
			fb("Waterfall", u0, s[2], mid - w, u1, s[1], mid + w, 0.3)
			for _ = 1, 2 do
				local v = rng:NextNumber(mid - w + 0.5, mid + w - 1.5)
				local y1 = rng:NextNumber(s[2] + 6, s[1])
				fb(
					"FallStreak",
					u1,
					y1 - rng:NextNumber(6, 16),
					v,
					u1 + dir * 0.15,
					y1,
					v + 1,
					0.45,
					"px_white_wool",
					CLOUD
				)
			end
		end
		-- the foam cloud at the bottom and a slow mist
		local fy, out = -152, outer + dir * 4
		fb(
			"FallFoam",
			out - dir * 10,
			fy - 4,
			mid - hw - 10,
			out + dir * 16,
			fy + 4,
			mid + hw + 10,
			0.1,
			"px_white_wool",
			CLOUD
		)
		fb(
			"FallFoam",
			out - dir * 4,
			fy + 4,
			mid - hw - 4,
			out + dir * 10,
			fy + 8,
			mid + hw + 4,
			0.12,
			"px_white_wool",
			CLOUD
		)
		fb(
			"FallFoam",
			out + dir * 16,
			fy - 4,
			mid - 8,
			out + dir * 24,
			fy,
			mid + 6,
			0.12,
			"px_white_wool",
			CLOUD
		)
		fb(
			"FallFoam",
			out - dir * 18,
			fy - 8,
			mid - hw,
			out - dir * 6,
			fy - 4,
			mid + 4,
			0.12,
			"px_white_wool",
			CLOUD
		)
		local mx, mz = cell(out + dir * 3, mid)
		local mist =
			decor(part("FallMist", Vector3.new(20, 2, 20), at(mx, fy + 6, mz), nil, nil, f))
		mist.Transparency = 1
		mist.CastShadow = false
		emitter(mist, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(245, 248, 252)),
			Size = NumberSequence.new(8, 16),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.6),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(6, 9),
			Rate = 3,
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(70, 70),
			Acceleration = Vector3.new(0, 0.6, 0),
			LightEmission = 0,
		})
		table.insert(FALLS, { alongX = alongX, dir = dir, outer = outer, v0 = a0, v1 = a1 })
		-- floaters keep out of the view in front of it
		local ua, ub = outer - dir * 12, outer + dir * 70
		local xa, za = cell(math.min(ua, ub), a0 - 30)
		local xb, zb = cell(math.max(ua, ub), a1 + 30)
		table.insert(
			CORR,
			{ math.min(xa, xb), math.max(xa, xb), math.min(za, zb), math.max(za, zb), -210, 30 }
		)
		print(("[build-eden] north: %s waterfall at %d, across %d..%d"):format(name, outer, a0, a1))
	end
	fall("West", true, -1, -100, -76, -44)
	fall("East", true, 1, 100, -76, -44)
	fall("North", false, -1, -156, -16, 16)
end
task.wait()

-- ================================================================ 4. under the island: vines and stone tips
do
	local uf = folder("UnderIsland", northF)
	local C = 8
	local vineParts, tipParts, hangParts, tips = 0, 0, 0, 0
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local VINES = { LEAF, LEAF, MOSS, GRASS_DEEP }
	-- the cell's face (dx, dz) is under a waterfall / right beside one
	local function fallNear(cx, cz, dx, dz, pad)
		for _, w in ipairs(FALLS) do
			local u, v = if w.alongX then cx else cz, if w.alongX then cz else cx
			local du = if w.alongX then dx else dz
			if
				math.abs(u - w.outer) < 20
				and v > w.v0 - pad
				and v < w.v1 + pad
				and (du == 0 or du == w.dir)
			then
				return true
			end
		end
		return false
	end
	local function vineKind()
		local r = rng:NextNumber()
		if r < 0.12 then
			return "px_wisteria_leaves", nil
		elseif r < 0.22 then
			return "px_cherry_leaves", BLOSSOM
		end
		return "px_hedge", pick(VINES)
	end
	for z = -232, 232 - C, C do
		for x = -232, 232 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			if onIsland(cx, cz) then
				local gy = groundY(cx, cz) or 0
				local rim = false
				for _, d in ipairs(DIRS) do
					if not onIsland(cx + d[1] * C, cz + d[2] * C) then
						rim = true
						local under = fallNear(cx, cz, d[1], d[2], 2)
						local beside = not under and fallNear(cx, cz, d[1], d[2], 34)
						if
							not under
							and vineParts < 470
							and rng:NextNumber() < (if beside then 0.95 else 0.42)
						then
							local face = if d[1] ~= 0 then cx + d[1] * 4 else cz + d[2] * 4
							local s = d[1] + d[2]
							local o0, o1 = face + s * 0.3, face + s * 1.3
							local strands = if beside or rng:NextNumber() < 0.3 then 2 else 1
							for k = 1, strands do
								local len = if rng:NextNumber() < 0.12
									then rng:NextInteger(9, 12) * B
									else rng:NextInteger(2, 8) * B
								local v, t = vineKind()
								local a = (if d[1] ~= 0 then cz else cx) - 4 + (k - 1) * B
								local y1 = gy - 0.3
								if d[1] ~= 0 then
									decor(box("RimVine", o0, y1 - len, a, o1, y1, a + B, v, t, uf))
								else
									decor(box("RimVine", a, y1 - len, o0, a + B, y1, o1, v, t, uf))
								end
								vineParts += 1
								if beside or rng:NextNumber() < 0.25 then
									local fu = (o0 + o1) / 2 + s * 0.4
									local fa = a + rng:NextNumber(1, 3)
									local fy = y1 - rng:NextNumber(2, len - 1)
									local col =
										pick({ PINK_WOOL, FLOWERS[7], FLOWERS[4], FLOWERS[2] })
									if d[1] ~= 0 then
										decor(
											cube(
												"VineFlower",
												fu,
												fy,
												fa,
												1.4,
												1.4,
												1.4,
												"px_white_wool",
												col,
												uf
											)
										)
									else
										decor(
											cube(
												"VineFlower",
												fa,
												fy,
												fu,
												1.4,
												1.4,
												1.4,
												"px_white_wool",
												col,
												uf
											)
										)
									end
									vineParts += 1
								end
							end
						end
					end
				end
				local bottom = gy - 4 - rockDepth(cx, cz)
				local key = cx * 10000 + cz
				local low = bottom
				-- grey stone tips: stepped 2×2 → 1×1 → half-block, denser at the rim
				if
					tipParts < 520
					and not fallNear(cx, cz, 0, 0, 10)
					and rng:NextNumber() < (if rim then 0.26 else 1 / 28)
				then
					local L = if rim then rng:NextInteger(2, 7) else rng:NextInteger(4, 12)
					L = math.min(L, math.floor((bottom + 236) / B))
					if L >= 2 then
						local y = bottom + 1
						local a = math.max(1, math.floor(L * 0.4))
						box(
							"RockTip",
							x,
							y - a * B - 1,
							z,
							x + 8,
							y,
							z + 8,
							"px_stone",
							ROCK_LOW,
							uf
						)
						y -= a * B + 1
						local qx, qz = x + rng:NextInteger(0, 1) * 4, z + rng:NextInteger(0, 1) * 4
						local b = math.max(1, math.floor((L - a) * 0.6))
						box(
							"RockTip",
							qx,
							y - b * B,
							qz,
							qx + 4,
							y,
							qz + 4,
							"px_stone",
							ROCK_LOW,
							uf
						)
						y -= b * B
						local rest = L - a - b
						tipParts += 2
						if rest >= 1 then
							local sx, sz = qx + pick({ 0, 2 }), qz + pick({ 0, 2 })
							box(
								"RockTip",
								sx,
								y - rest * B,
								sz,
								sx + 2,
								y,
								sz + 2,
								"px_cobblestone",
								ROCK_LOW,
								uf
							)
							y -= rest * B
							tipParts += 1
						end
						low = math.min(low, y)
						tips += 1
					end
				end
				-- a vine hanging under the bottom near the rim
				if
					hangParts < 110
					and rng:NextNumber() < (if rim then 0.14 else 0.012)
					and not fallNear(cx, cz, 0, 0, 10)
				then
					local len = rng:NextInteger(2, 8) * B
					len = math.min(len, bottom + 232)
					if len >= B then
						local v, t = vineKind()
						local px, pz = x + pick({ 0.6, 5.8 }), z + pick({ 0.6, 5.8 })
						decor(
							box(
								"HangingVine",
								px,
								bottom - len,
								pz,
								px + 1.6,
								bottom + 0.5,
								pz + 1.6,
								v,
								t,
								uf
							)
						)
						hangParts += 1
						low = math.min(low, bottom - len)
					end
				end
				tipLow[key] = low
			end
		end
		if z % 32 == 0 then
			task.wait()
		end
	end
	print(
		("[build-eden] north: under the island %d tips (%d parts), rim vines %d parts, hanging vines %d"):format(
			tips,
			tipParts,
			vineParts,
			hangParts
		)
	)
end
task.wait()

-- ================================================================ 5–6. floating islets and clouds
do
	local sky = folder("Sky", northF)
	local TAKEN = {}
	local function blocked(x0, x1, z0, z1, y0, y1)
		for _, c in ipairs(CORR) do
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
	-- no island ground within half + 24 studs (horizontally) of (x, z)
	local function clearOfIsland(x, z, half)
		local e = half + 24
		if math.abs(x) > HALF + 12 + e or math.abs(z) > HALF + 12 + e then
			return true
		end
		local n = math.max(1, math.ceil(2 * e / 8))
		for i = 0, n do
			for j = 0, n do
				if onIsland(x - e + 2 * e * i / n, z - e + 2 * e * j / n) then
					return false
				end
			end
		end
		return true
	end
	local function findSpot(half, down, up, yMin, yMax)
		for attempt = 1, 300 do
			if attempt % 60 == 0 then
				task.wait()
			end
			local x, z =
				rng:NextNumber(-380 + half, 380 - half), rng:NextNumber(-380 + half, 380 - half)
			local y = rng:NextNumber(yMin, yMax)
			local ok = not blocked(x - half, x + half, z - half, z + half, y - down, y + up)
				and not (hillDist(x, z) < 90 + half and y + up > 40)
				and clearOfIsland(x, z, half)
			if ok then
				for _, t in ipairs(TAKEN) do
					local dh = math.sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2)
					if dh < t[3] + half + 10 and y + up + 8 > t[4] and y - down - 8 < t[5] then
						ok = false
						break
					end
				end
			end
			if ok then
				table.insert(TAKEN, { x, z, half, y - down, y + up })
				return x, y, z
			end
		end
		return nil
	end
	-- a floating islet: a grass top, a stepped cone of dirt then stone under it, vines down the sides (decor)
	local function islet(x, y, z, w, d, parent)
		local f = folder("Islet", parent)
		local hx, hz = w * B / 2, d * B / 2
		box(
			"IsletTop",
			x - hx,
			y - B,
			z - hz,
			x + hx,
			y,
			z + hz,
			"px_grass_top",
			pick({ GRASS, GRASS_DEEP }),
			f
		)
		local layers = math.clamp(math.floor((w + d) / 3) + rng:NextInteger(0, 1), 2, 5)
		local yTop = y - B
		local ix0, ix1, iz0, iz1 = 0, w, 0, d
		for k = 1, layers do
			local f01 = 1 - k / (layers + 1)
			local lw = math.clamp(math.floor(w * f01 + 0.5), 1, ix1 - ix0)
			local ld = math.clamp(math.floor(d * f01 + 0.5), 1, iz1 - iz0)
			local sx = math.clamp(
				ix0 + math.floor((ix1 - ix0 - lw) / 2 + rng:NextNumber(-0.5, 0.99)),
				ix0,
				ix1 - lw
			)
			local sz = math.clamp(
				iz0 + math.floor((iz1 - iz0 - ld) / 2 + rng:NextNumber(-0.5, 0.99)),
				iz0,
				iz1 - ld
			)
			local hgt = if lw >= 3 and rng:NextNumber() < 0.5 then 2 * B else B
			local v, t = "px_dirt", ROCK_TOP
			if k > layers / 2 then
				v, t = "px_stone", ROCK_LOW
			end
			box(
				"IsletRock",
				x - hx + sx * B,
				yTop - hgt,
				z - hz + sz * B,
				x - hx + (sx + lw) * B,
				yTop,
				z - hz + (sz + ld) * B,
				v,
				t,
				f
			)
			yTop -= hgt
			ix0, ix1, iz0, iz1 = sx, sx + lw, sz, sz + ld
		end
		for _ = 1, rng:NextInteger(2, 4) do
			local side = rng:NextInteger(1, 4)
			local len = rng:NextInteger(1, 4) * B
			local vv, vt = "px_hedge", pick({ LEAF, MOSS })
			if rng:NextNumber() < 0.2 then
				vv, vt = "px_wisteria_leaves", nil
			end
			if side <= 2 then
				local fx = if side == 1 then x - hx - 0.3 else x + hx + 0.3
				local a = z - hz + rng:NextInteger(0, d - 1) * B
				box(
					"IsletVine",
					fx,
					y - 0.4 - len,
					a,
					fx + (if side == 1 then -0.8 else 0.8),
					y - 0.4,
					a + B,
					vv,
					vt,
					f
				)
			else
				local fz = if side == 3 then z - hz - 0.3 else z + hz + 0.3
				local a = x - hx + rng:NextInteger(0, w - 1) * B
				box(
					"IsletVine",
					a,
					y - 0.4 - len,
					fz,
					a + B,
					y - 0.4,
					fz + (if side == 3 then -0.8 else 0.8),
					vv,
					vt,
					f
				)
			end
		end
		return finish(f, false)
	end

	-- 5. the floating islets
	local fly = folder("FloatingIslets", sky)
	local c0 = count
	local islets, lamps = 0, 0
	local want = rng:NextInteger(16, 18)
	for i = 1, 50 do
		if islets >= want or count - c0 > 800 then
			break
		end
		local w, d = rng:NextInteger(3, 7), rng:NextInteger(3, 7)
		local half = math.max(w, d) * B / 2 + 2
		local big = w >= 4 and d >= 4
		local kind = if big then rng:NextInteger(1, 7) else rng:NextInteger(3, 7)
		local up = if kind <= 2 then 34 else 14
		local x, y, z = findSpot(math.max(half, if kind <= 2 then 16 else 0), 56, up, -60, 100 - up)
		if x then
			x, y, z = snap(x), math.floor(y), snap(z)
			if w % 2 == 1 then
				x += 2
			end
			if d % 2 == 1 then
				z += 2
			end
			local f = islet(x, y, z, w, d, fly)
			local hx, hz = w * B / 2, d * B / 2
			local px, pz =
				x - hx + rng:NextInteger(0, w - 1) * B + 2,
				z - hz + rng:NextInteger(0, d - 1) * B + 2
			if kind == 1 then
				cherryTree(x, z, f, y, false)
			elseif kind == 2 then
				appleTree(x, z, f, y, false)
			elseif kind == 3 then
				finish(
					flowerBed(
						x - hx + B / 2,
						z - hz + B / 2,
						math.max(1, w - 1),
						math.max(1, d - 1),
						f,
						{ pick(FLOWERS), pick(FLOWERS) },
						y
					),
					false
				)
			elseif kind == 4 then
				decor(
					box(
						"HivePost",
						px - 0.5,
						y,
						pz - 0.5,
						px + 0.5,
						y + 5,
						pz + 0.5,
						"px_oak_log",
						nil,
						f
					)
				)
				beehive(px, y + 6.7, pz, f)
			elseif kind == 5 then
				deer(x, z, rng:NextNumber(0, 2 * math.pi), f, y, false)
			elseif kind == 6 then
				decor(
					box(
						"IsletLampPost",
						px - 0.5,
						y,
						pz - 0.5,
						px + 0.5,
						y + 7,
						pz + 0.5,
						"px_oak_log",
						nil,
						f
					)
				)
				decor(
					box(
						"IsletLampArm",
						px - 0.5,
						y + 6.5,
						pz - 0.5,
						px + 0.5,
						y + 7.5,
						pz + 3,
						"px_spruce_planks",
						nil,
						f
					)
				)
				lamp(px, y + 4.6, pz + 2.4, f, y + 6.5, lamps >= 3)
				lamps += 1
			else
				rabbit(px, pz, rng:NextNumber(0, 2 * math.pi), f, y)
			end
			for _ = 1, rng:NextInteger(1, 3) do
				flower(
					x - hx + rng:NextNumber(1, w * B - 1),
					y,
					z - hz + rng:NextNumber(1, d * B - 1),
					f
				)
			end
			islets += 1
		end
		if i % 4 == 0 then
			task.wait()
		end
	end
	local isletParts = count - c0
	task.wait()

	-- 6. the clouds: flat stacked white wool slabs (a base, a smaller puff on top, a lobe under one side)
	local cf = folder("Clouds", sky)
	local function cloud(x, y, z, w, d, th)
		local hx, hz = w * B / 2, d * B / 2
		local tr = rng:NextNumber(0, 0.15)
		local function puff(x0, y0, z0, x1, y1, z1)
			local p = decor(box("Cloud", x0, y0, z0, x1, y1, z1, "px_white_wool", CLOUD, cf))
			p.Transparency = tr
			p.CastShadow = false
		end
		puff(x - hx, y, z - hz, x + hx, y + th * B, z + hz)
		local w2, d2 =
			math.max(2, w - rng:NextInteger(3, 6)), math.max(2, d - rng:NextInteger(2, 5))
		local ox, oz = rng:NextInteger(-1, 1) * B, rng:NextInteger(-1, 1) * B
		puff(
			x + ox - w2 * B / 2,
			y + th * B,
			z + oz - d2 * B / 2,
			x + ox + w2 * B / 2,
			y + (th + 1) * B,
			z + oz + d2 * B / 2
		)
		if w >= 8 then
			local lw = rng:NextInteger(3, math.floor(w / 2))
			local sx = if rng:NextNumber() < 0.5 then x - hx else x + hx - lw * B
			puff(sx, y - B, z - hz + B, sx + lw * B, y, z + hz - B)
		end
	end
	local low, edge = 0, 0
	-- the layer under the island (y -150..-230), always below what hangs under it
	for attempt = 1, 400 do
		if low >= 30 then
			break
		end
		local x, z
		if attempt % 3 == 0 then
			x, z = rng:NextNumber(-380, 380), rng:NextNumber(-380, 380)
		else
			x, z = rng:NextNumber(-250, 250), rng:NextNumber(-250, 250)
		end
		x, z = snap(x), snap(z)
		local w, d, th = rng:NextInteger(6, 20), rng:NextInteger(5, 14), rng:NextInteger(1, 2)
		local y = snap(rng:NextNumber(-230, -150))
		local hx, hz = w * B / 2 + 8, d * B / 2 + 8
		local floor0 = 0
		for px = cc(x - hx), cc(x + hx), 8 do
			for pz = cc(z - hz), cc(z + hz), 8 do
				local lowY = tipLow[px * 10000 + pz]
				if lowY then
					floor0 = math.min(floor0, lowY)
				end
			end
		end
		local h = (th + 1) * B
		if y + h > floor0 - 8 then
			y = floor0 - 8 - h
		end
		if y >= -234 and not blocked(x - hx, x + hx, z - hz, z + hz, y - B, y + h) then
			cloud(x, y, z, w, d, th)
			low += 1
		end
		if attempt % 50 == 0 then
			task.wait()
		end
	end
	-- a few round the island at y -40..40, off it and off the islets, out of the falls' view
	for _ = 1, 40 do
		if edge >= 10 then
			break
		end
		local w, d, th = rng:NextInteger(6, 16), rng:NextInteger(4, 10), rng:NextInteger(1, 2)
		local x, y, z = findSpot(math.max(w, d) * B / 2 + 4, B, (th + 1) * B, -40, 40)
		if x then
			cloud(snap(x), snap(y), snap(z), w, d, th)
			edge += 1
		end
	end
	print(
		("[build-eden] north: islets %d (%d parts), clouds %d low + %d round"):format(
			islets,
			isletParts,
			low,
			edge
		)
	)
end
print(
	("[build-eden] north: %d parts in all, %d lights"):format(count - startCount, math.min(lit, 20))
)
