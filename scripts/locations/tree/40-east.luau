--!nocheck
-- ================================================================ tree: the east, the rope bridges and the sky
-- 1. The rope bridge BRIDGE (x 116..164, z -2..10) between the central and the east island: a plank deck 3 blocks
--    wide, top y 0.1 on the land, sagging over the gap measured from core's 8-stud cells in half-stud steps;
--    stringers, log rail posts, handrails and rope lines; oak log posts with hanging lanterns at both ends. Two short
--    rope bridges run south to walkable islets off the central island (x 54..66) and the east island (x 234..246).
-- 2. The central island east of x 0 (outside the tree circle): flower beds along the EAST path and MAIN STREET,
--    bushes, small oak / azalea / flowering azalea trees, a beehive tree, a bench and lamp posts, mossy boulders, a
--    lookout on the south rim (x 8..32) with a basket lift: a plank basket on 4 chains under a log gantry.
-- 3. The east island EAST (230, 24): the walkway from the bridge landing (4 blocks, z -4..12) to x 246; a pond
--    (x 214..250, z 20..48: a water layer on a dark bed in a low mossy cobblestone rim) with lily pads, a dock and a
--    fishing spot; a stream east to the rim and a waterfall 36 blocks down the east edge into a foam cloud with
--    mist; a gardener's hut, a fenced kitchen garden with a scarecrow, small trees, flowers, bushes, lamp posts.
-- 4. Roots under every island (core's cells, from the bottom of each column; none within r 40 of the trunk):
--    2×2 → 1×1 blocks → 1-stud strips, 4..24 blocks, longest under the island centres; vines on the rim faces.
-- 5. Floating earth islets (stepped cones of dirt and stone, grass tops, roots, a tree / bush / birdhouse /
--    lantern) 24+ studs off every island, out of the bridge corridors and the crown.
-- 6. Blocky white wool clouds: a layer at y -120..-200 under the islands where the roots end, a few round the edges.
-- Everything floating is decor except the two bridged islets.
local eastF = folder("EastAndSky")
local startCount = count
local lit = 0 -- PointLights made by this part (≤ 20)
local ROCK_T = Color3.fromRGB(134, 96, 66) -- core's rockTopTint
local STONE_T = Color3.fromRGB(150, 146, 140) -- core's rockLowTint
local ROPE = Color3.fromRGB(122, 92, 60)
local WATER = Color3.fromRGB(70, 136, 214)
local FALL = Color3.fromRGB(120, 176, 236)
local DECKS = {} -- { x0, z0, x1, z1 } of every bridge deck (no vines, no floaters there)
local CORR = {} -- the ways floaters keep off: { x0, x1, z0, z1, y0, y1 }
local TAKEN = {} -- floaters placed: { x, z, half, y0, y1 }
local WF = {} -- the waterfall: x (the rim face), z0, z1

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
-- is the core cell holding (x, z) land?
local function cellLand(x, z)
	return isleOf(math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4) ~= nil
end
-- walking from `u` (on the land) by `dir` (±1) along x (alongX) or z: the cell boundary where the land ends for any
-- cell overlapping the band c0..c1 across; nil if it does not end within `limit` studs
local function landEnd(alongX, u, dir, c0, c1, limit)
	local cu = math.floor(u / 8) * 8 + 4
	for _ = 0, math.floor(limit / 8) do
		local v = math.floor(c0 / 8) * 8 + 4
		while v - 4 < c1 do
			local x, z = if alongX then cu else v, if alongX then v else cu
			if isleOf(x, z) == nil then
				return cu - dir * 4
			end
			v += 8
		end
		cu += dir * 8
	end
	return nil
end
-- core's rockDepth (10-core is wrapped in its own do … end): the column of a cell is ground y -4..0, then rock
-- down to y -4 - depth
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local c = if isle == "west" then WEST elseif isle == "central" then CENTRAL else EAST
	local deep = if isle == "central" then 150 elseif isle == "west" then 120 else 80
	local rr = math.clamp(math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r, 0, 1)
	local d = 12 + (1 - rr) ^ 1.25 * deep
	if rr > 0.8 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 24
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end

-- ================================================================ props on the islands (my zone only)
local claimed = {} -- { x0, z0, x1, z1 } taken on the islands by this part
-- the rectangle is free: in the east zone, `inset` studs inside an island, off the paths and off what is claimed
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
			if zoneOf(x, z) ~= "east" or isleOf(x, z, inset or 10) == nil or onPath(x, z, 2) then
				return false
			end
		end
	end
	return true
end
local function claim(x0, z0, x1, z1)
	table.insert(claimed, { x0, z0, x1, z1 })
end
-- a small tree: an oak log trunk 3..5 blocks and a stepped crown (a cross of leaves, a 3×3 layer, a top block) in
-- patches of oak / azalea / flowering azalea leaves; solid on an island, decor in the sky; returns the trunk height
local function smallTree(x, z, kind, parent, y0, solid)
	y0 = y0 or 0
	local f = folder("SmallTree", parent)
	local h = rng:NextInteger(3, 5) * B
	local baseV, baseT, patchV, patchT = "px_hedge", OAK_LEAF, "px_hedge", GRASS_DEEP
	if kind == "azalea" then
		baseV, baseT, patchV, patchT = "px_hedge", AZALEA, "px_cherry_leaves", BLOSSOM
	elseif kind == "blossom" then
		baseV, baseT, patchV, patchT = "px_cherry_leaves", BLOSSOM, "px_hedge", AZALEA
	end
	local function lb(name, xa, ya, za, xb, yb, zb, v, t)
		local p = box(name, x + xa, y0 + ya, z + za, x + xb, y0 + yb, z + zb, v, t, f)
		if not solid then
			decor(p)
		end
		return p
	end
	lb("Trunk", -2, 0, -2, 2, h, 2, "px_oak_log", nil)
	lb("Leaves", -10, h - 4, -6, 10, h, 6, baseV, baseT)
	lb("Leaves", -6, h - 4, -10, 6, h, -6, baseV, baseT)
	lb("Leaves", -6, h - 4, 6, 6, h, 10, baseV, baseT)
	lb("Leaves", -6, h, -6, 6, h + 4, 6, baseV, baseT)
	lb("Leaves", -2, h + 4, -2, 2, h + 8, 2, patchV, patchT)
	-- patches of the second leaf: on top of the cross arms, hanging under them, on the 3×3 layer
	local used = {}
	for _ = 1, rng:NextInteger(3, 5) do
		local r = rng:NextInteger(1, 3)
		local px = if rng:NextNumber() < 0.5 then -10 else 6
		local pz = pick({ -6, -2, 2 })
		local py = h
		if r == 2 then
			py = h - 8
		elseif r == 3 then
			px, pz, py = pick({ -6, 2 }), pick({ -6, 2 }), h + 4
		end
		if rng:NextNumber() < 0.5 and r ~= 3 then
			px, pz = pz, px -- on the z arms instead
		end
		local key = px .. ":" .. py .. ":" .. pz
		if not used[key] then
			used[key] = true
			lb("LeafPatch", px, py, pz, px + 4, py + 4, pz + 4, patchV, patchT)
		end
	end
	-- fallen leaves round the trunk
	for k = 1, rng:NextInteger(1, 2) do
		local ox, oz = rng:NextInteger(-3, 1) * 2, rng:NextInteger(-3, 1) * 2
		decor(
			box(
				"FallenLeaves",
				x + ox - 2,
				y0,
				z + oz - 2,
				x + ox + 4,
				y0 + 0.1 + k * 0.08,
				z + oz + 4,
				patchV,
				patchT,
				f
			)
		)
	end
	return h
end
-- a leaf bush of 1..2 blocks, now and then with a flowering block on top
local function bush(x, z, parent, y0, solid)
	y0 = y0 or 0
	local wide = rng:NextNumber() < 0.4
	local alongX = rng:NextNumber() < 0.5
	local ex, ez = if wide and alongX then 4 else 0, if wide and not alongX then 4 else 0
	local p = box(
		"Bush",
		x - 2,
		y0,
		z - 2,
		x + 2 + ex,
		y0 + B,
		z + 2 + ez,
		"px_hedge",
		pick({ OAK_LEAF, AZALEA, GRASS_DEEP }),
		parent
	)
	if not solid then
		decor(p)
	end
	if rng:NextNumber() < 0.35 then
		decor(
			box(
				"BushBloom",
				x - 1.5,
				y0 + B,
				z - 1.5,
				x + 1.5,
				y0 + B + 1.5,
				z + 1.5,
				"px_cherry_leaves",
				BLOSSOM,
				parent
			)
		)
	end
end
local FLOWERS = {
	Color3.fromRGB(206, 50, 46),
	Color3.fromRGB(240, 206, 60),
	Color3.fromRGB(86, 120, 220),
	Color3.fromRGB(240, 240, 236),
	BLOSSOM,
	Color3.fromRGB(232, 140, 50),
	Color3.fromRGB(150, 92, 200),
}
-- one flower: a green stem and a coloured head (decor)
local function flower(x, y, z, parent, color)
	decor(
		box("FlowerStem", x - 0.2, y, z - 0.2, x + 0.2, y + 1.4, z + 0.2, "px_hedge", GRASS, parent)
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
-- a mossy boulder: a stepped heap of mossy cobblestone and stone blocks
local function boulder(x, z, parent, y0, solid)
	y0 = y0 or 0
	local f = folder("Boulder", parent)
	local parts = {
		box("Boulder", x - 4, y0 - 1, z - 4, x + 4, y0 + B, z + 4, "px_mossy_cobblestone", nil, f),
	}
	local ox = x - 4 + rng:NextInteger(0, 1) * B
	table.insert(
		parts,
		box("Boulder", ox, y0 + B, z - 4, ox + B, y0 + 2 * B, z + 4, "px_stone", STONE_T, f)
	)
	if rng:NextNumber() < 0.6 then
		local sx = pick({ -8, 4 })
		local oz = z - 4 + rng:NextInteger(0, 1) * B
		table.insert(
			parts,
			box(
				"Boulder",
				x + sx,
				y0 - 1,
				oz,
				x + sx + B,
				y0 + B,
				oz + B,
				"px_mossy_stone_bricks",
				nil,
				f
			)
		)
	end
	decor(
		box(
			"Moss",
			x - 4.2,
			y0 + B - 0.6,
			z - 4.2,
			x + 4.2,
			y0 + B - 0.4,
			z + 4.2,
			"px_hedge",
			MOSS,
			f
		)
	)
	if not solid then
		for _, p in ipairs(parts) do
			decor(p)
		end
	end
end
-- a birdhouse on a post (x, y, z: the foot of the post)
local function birdhouse(x, y, z, parent, solid)
	local f = folder("Birdhouse", parent)
	local post =
		box("BirdPost", x - 0.5, y, z - 0.5, x + 0.5, y + 6, z + 0.5, "px_dark_oak_log", BARK, f)
	if not solid then
		decor(post)
	end
	decor(
		box(
			"Birdhouse",
			x - 1.6,
			y + 6,
			z - 1.6,
			x + 1.6,
			y + 9.2,
			z + 1.6,
			"px_planks",
			Color3.fromRGB(210, 172, 120),
			f
		)
	)
	decor(
		box(
			"BirdRoof",
			x - 2.1,
			y + 9.2,
			z - 2.1,
			x + 2.1,
			y + 9.9,
			z + 2.1,
			"px_dark_oak_planks",
			nil,
			f
		)
	)
	decor(
		box(
			"BirdRoof",
			x - 1.2,
			y + 9.9,
			z - 1.2,
			x + 1.2,
			y + 10.5,
			z + 1.2,
			"px_dark_oak_planks",
			nil,
			f
		)
	)
	decor(
		box(
			"BirdHole",
			x - 0.5,
			y + 7.3,
			z - 1.75,
			x + 0.5,
			y + 8.3,
			z - 1.6,
			nil,
			Color3.fromRGB(30, 24, 20),
			f
		)
	)
	decor(
		box(
			"BirdPerch",
			x - 0.15,
			y + 6.7,
			z - 2.5,
			x + 0.15,
			y + 6.9,
			z - 1.6,
			"px_dark_oak_planks",
			nil,
			f
		)
	)
end
-- a garden bench facing local -Z (yaw turns it), solid
local function bench(x, z, yaw, parent)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function bp(name, size, off, v)
		return textured(part(name, size, cf * off, nil, nil, parent), v)
	end
	bp("BenchSeat", Vector3.new(8, 0.6, 2.6), CFrame.new(0, 1.9, 0), "px_spruce_planks")
	bp("BenchLeg", Vector3.new(0.8, 1.6, 2.2), CFrame.new(-3.4, 0.8, 0), "px_dark_oak_planks")
	bp("BenchLeg", Vector3.new(0.8, 1.6, 2.2), CFrame.new(3.4, 0.8, 0), "px_dark_oak_planks")
	bp("BenchBack", Vector3.new(8, 2, 0.6), CFrame.new(0, 3.5, 1.2), "px_spruce_planks")
	bp("BenchArm", Vector3.new(0.6, 1.2, 2.6), CFrame.new(-4.1, 2.8, 0), "px_dark_oak_planks")
	bp("BenchArm", Vector3.new(0.6, 1.2, 2.6), CFrame.new(4.1, 2.8, 0), "px_dark_oak_planks")
end
-- a lamp post counted against the light budget
local function lampPostL(x, z, parent, yaw)
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
end

-- ================================================================ the rope bridge builder
-- along x (alongX) or z: the deck a0..a1 × c0..c1 (across), top y 0.1 on the land; over the gap g0..g1 it sags in
-- 4-stud planks by half-stud steps. Stringers, log rail posts, handrails from g0 - 8 to g1 + 8 (solid, outside the
-- deck), rope lines on the post tops from oak log posts at both ends; `lights` = "both" (lanterns at both ends) or
-- "far". landAt(x, z) tells where the end logs may stand.
local function ropeBridge(name, alongX, a0, a1, c0, c1, g0, g1, parent, landAt, lights)
	local f = folder(name, parent)
	local function bx(nm, u0, y0, v0, u1, y1, v1, variant, tint)
		if alongX then
			return box(nm, u0, y0, v0, u1, y1, v1, variant, tint, f)
		end
		return box(nm, v0, y0, u0, v1, y1, u1, variant, tint, f)
	end
	local function W(u, y, v)
		return if alongX then V(u, y, v) else V(v, y, u)
	end
	if g0 > a0 then
		bx("Deck", a0, -0.9, c0, g0, 0.1, c1, "px_spruce_planks")
	end
	if a1 > g1 then
		bx("Deck", g1, -0.9, c0, a1, 0.1, c1, "px_spruce_planks")
	end
	local n = math.max(1, math.floor((g1 - g0) / B + 0.5))
	local step = (g1 - g0) / n
	local sag = math.min(2.5, n * 0.25)
	local segs = { { g0 - 8, g0, 0.1, false } }
	for i = 1, n do
		local top = 0.1 - math.floor(math.sin((i - 0.5) / n * math.pi) * sag * 2 + 0.5) / 2
		table.insert(segs, { g0 + (i - 1) * step, g0 + i * step, top, true })
	end
	table.insert(segs, { g1, g1 + 8, 0.1, false })
	local ropeA, ropeB = {}, {}
	local function railPost(u, lo, hi)
		bx(
			"RailPost",
			u - 0.55,
			lo - 1.6,
			c0 - 1.15,
			u + 0.55,
			hi + 3.7,
			c0 - 0.05,
			"px_oak_log",
			BARK
		)
		bx(
			"RailPost",
			u - 0.55,
			lo - 1.6,
			c1 + 0.05,
			u + 0.55,
			hi + 3.7,
			c1 + 1.15,
			"px_oak_log",
			BARK
		)
		table.insert(ropeA, W(u, hi + 3.9, c0 - 0.6))
		table.insert(ropeB, W(u, hi + 3.9, c1 + 0.6))
	end
	for i, s in ipairs(segs) do
		local u0, u1, top = s[1], s[2], s[3]
		if s[4] then
			local alt = i % 2 == 0
			bx(
				"Plank",
				u0,
				top - 1,
				c0,
				u1,
				top,
				c1,
				if alt then "px_spruce_planks" else "px_planks",
				if alt then nil else Color3.fromRGB(205, 170, 120)
			)
			decor(
				bx(
					"Joist",
					(u0 + u1) / 2 - 0.6,
					top - 1.8,
					c0 - 1,
					(u0 + u1) / 2 + 0.6,
					top - 1,
					c1 + 1,
					"px_dark_oak_planks"
				)
			)
		end
		bx("Stringer", u0, top - 1.4, c0 - 1, u1, top + 0.3, c0, "px_dark_oak_planks")
		bx("Stringer", u0, top - 1.4, c1, u1, top + 0.3, c1 + 1, "px_dark_oak_planks")
		bx("Handrail", u0, top + 2.8, c0 - 1, u1, top + 3.4, c0, "px_spruce_planks")
		bx("Handrail", u0, top + 2.8, c1, u1, top + 3.4, c1 + 1, "px_spruce_planks")
		local prev = if i > 1 then segs[i - 1][3] else top
		railPost(u0, math.min(top, prev), math.max(top, prev))
	end
	railPost(segs[#segs][2], 0.1, 0.1)
	-- the oak log posts at both ends (moved onto the land if the first spot is over the edge), lanterns on arms
	local anchors = {}
	local function endPosts(uC, dir, withLights)
		for _, side in ipairs({ -1, 1 }) do
			local v0 = if side < 0 then c0 - 5 else c1 + 1
			local u, ok = uC, false
			for _ = 1, 3 do
				local x, z = if alongX then u else v0 + 2, if alongX then v0 + 2 else u
				if landAt(x, z) then
					ok = true
					break
				end
				u += dir * 8
			end
			if ok then
				bx("BridgeLog", u - 2, -1, v0, u + 2, 12, v0 + 4, "px_oak_log")
				bx(
					"BridgeLogCap",
					u - 2.4,
					12,
					v0 - 0.4,
					u + 2.4,
					13,
					v0 + 4.4,
					"px_dark_oak_planks"
				)
				anchors[side .. ":" .. dir] = W(u, 13, v0 + 2)
				if withLights then
					local va, vb =
						if side < 0 then v0 + 4 else v0 - 3.5, if side < 0 then v0 + 7.5 else v0
					decor(
						bx("LanternArm", u - 0.5, 10.4, va, u + 0.5, 11.4, vb, "px_dark_oak_planks")
					)
					local lv = if side < 0 then c0 + 1.8 else c1 - 1.8
					local lx, lz = if alongX then u else lv, if alongX then lv else u
					lamp(lx, 8.3, lz, f, 10.4)
				end
			end
		end
	end
	endPosts(g0 - 10, -1, lights == "both")
	endPosts(g1 + 10, 1, true)
	-- the rope lines: from a log top down over the post tops to the log top at the other end
	for _, side in ipairs({ -1, 1 }) do
		local pts = table.clone(if side < 0 then ropeA else ropeB)
		if anchors[side .. ":-1"] then
			table.insert(pts, 1, anchors[side .. ":-1"])
		end
		if anchors[side .. ":1"] then
			table.insert(pts, anchors[side .. ":1"])
		end
		for i = 2, #pts do
			decor(beam("Rope", pts[i - 1], pts[i], 0.35, ROPE, f, Enum.Material.Fabric))
		end
	end
	return f
end

-- an earth islet: a grass top w × d blocks, its top surface centre at (x, y, z), stepped layers of dirt then stone
-- shrinking downward, roots under the tip, vines on the sides; `walk` keeps the top solid. Returns the folder.
local function islet(x, y, z, w, d, parent, walk)
	local f = folder("Islet", parent)
	local hx, hz = w * B / 2, d * B / 2
	local top = box(
		"IsletTop",
		x - hx,
		y - B,
		z - hz,
		x + hx,
		y,
		z + hz,
		"px_grass_top",
		if rng:NextNumber() < 0.5 then GRASS else GRASS_DEEP,
		f
	)
	if not walk then
		decor(top)
	end
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
		local v, t = "px_dirt", ROCK_T
		if k > layers / 2 then
			v, t = "px_stone", STONE_T
		end
		decor(
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
		)
		yTop -= hgt
		ix0, ix1, iz0, iz1 = sx, sx + lw, sz, sz + ld
	end
	-- roots under the tip
	for _ = 1, rng:NextInteger(1, 3) do
		local rx = x - hx + (ix0 + rng:NextNumber(0.15, 0.85) * (ix1 - ix0)) * B
		local rz = z - hz + (iz0 + rng:NextNumber(0.15, 0.85) * (iz1 - iz0)) * B
		local len = rng:NextInteger(2, 6) * B
		decor(
			box(
				"IsletRoot",
				rx - 0.6,
				yTop - len,
				rz - 0.6,
				rx + 0.6,
				yTop + 1,
				rz + 0.6,
				"px_dark_oak_log",
				BARK_DARK,
				f
			)
		)
	end
	-- vines down the sides of the top
	for _ = 1, rng:NextInteger(1, 3) do
		local side = rng:NextInteger(1, 4)
		local len = rng:NextInteger(1, 3) * B
		local vt = pick({ OAK_LEAF, MOSS, AZALEA })
		if side <= 2 then
			local fx = if side == 1 then x - hx - 0.3 else x + hx + 0.3
			local a = z - hz + rng:NextInteger(0, d - 1) * B
			decor(
				box(
					"IsletVine",
					fx,
					y - 0.4 - len,
					a,
					fx + (if side == 1 then -0.8 else 0.8),
					y - 0.4,
					a + B,
					"px_hedge",
					vt,
					f
				)
			)
		else
			local fz = if side == 3 then z - hz - 0.3 else z + hz + 0.3
			local a = x - hx + rng:NextInteger(0, w - 1) * B
			decor(
				box(
					"IsletVine",
					a,
					y - 0.4 - len,
					fz,
					a + B,
					y - 0.4,
					fz + (if side == 3 then -0.8 else 0.8),
					"px_hedge",
					vt,
					f
				)
			)
		end
	end
	return f
end

-- ================================================================ 1. the rope bridges
do
	local bf = folder("Bridges", eastF)
	local c0, c1 = BRIDGE[2], BRIDGE[4]
	-- the gap between the islands, measured from core's cells under the deck
	local g0 = landEnd(true, 100, 1, c0, c1, 120) or 124
	local g1 = landEnd(true, 188, -1, c0, c1, 120) or 152
	local a0, a1 = math.min(BRIDGE[1], g0 - 12), math.max(BRIDGE[3], g1 + 12)
	ropeBridge("RopeBridge", true, a0, a1, c0, c1, g0, g1, bf, cellLand, "both")
	table.insert(DECKS, { a0, c0, a1, c1 })
	table.insert(CORR, { a0 - 16, a1 + 16, c0 - 16, c1 + 16, -20, 30 })
	claim(a0 - 2, c0 - 8, a1 + 2, c1 + 8)
	WF.landing = a1 -- the east island walkway starts here

	-- two short bridges south to walkable islets: the islet's north edge 26 studs past every island cell near it
	local function bridgedIslet(cx, zFrom, w, deco)
		local gz = landEnd(false, zFrom, 1, cx - 6, cx + 6, 160)
		if not gz then
			return
		end
		local half = w * B / 2
		local far = gz
		for x = cx - half - 24, cx + half + 24, 8 do
			for z = zFrom, zFrom + 160, 8 do
				if cellLand(x, z) then
					far = math.max(far, math.floor(z / 8) * 8 + 8)
				end
			end
		end
		local iz0 = math.ceil((far + 26) / B) * B
		local iz1 = iz0 + w * B
		if iz1 > 182 then
			return -- the edge wall of the floor runs at z 188
		end
		local f = folder("BridgedIslet", bf)
		local zc = (iz0 + iz1) / 2
		islet(cx, 0, zc, w, w, f, true)
		local rect = { cx - half, iz0, cx + half, iz1 }
		ropeBridge(
			"IsletBridge",
			false,
			gz - 12,
			iz0 + 12,
			cx - 6,
			cx + 6,
			gz,
			iz0,
			f,
			function(x, z)
				return cellLand(x, z) or inRect(x, z, rect, -2)
			end,
			"far"
		)
		table.insert(DECKS, { cx - 6, gz - 12, cx + 6, iz0 + 12 })
		table.insert(CORR, { cx - 22, cx + 22, gz - 28, iz0 + 28, -20, 30 })
		table.insert(TAKEN, { cx, zc, half, -80, 40 })
		claim(cx - 12, gz - 16, cx + 12, gz + 2)
		-- the islet top: a tree in the far corner, a lamp post, a bush and a bench or a birdhouse
		-- (the deck lands on x cx-6..cx+6, z iz0..iz0+12, its end logs at z iz0+8..iz0+12)
		smallTree(cx + 6, iz0 + 19, pick({ "oak", "azalea", "blossom" }), f, 0, true)
		lampPostL(cx - 8, iz0 + 19, f, math.pi)
		bush(cx - 2, iz0 + 20, f, 0, true)
		if deco == "bench" then
			bench(cx + 9.5, iz0 + 4, -math.pi / 2, f)
		else
			birdhouse(cx + 9.5, 0, iz0 + 4, f, true)
		end
		for _ = 1, 4 do
			flower(cx + rng:NextInteger(-2, 2) * 4 + 2, 0, iz0 + 14 + rng:NextInteger(0, 1) * 2, f)
		end
	end
	bridgedIslet(60, 40, 6, "bench") -- off the central island's south rim
	bridgedIslet(240, 60, 6, "birdhouse") -- off the east island's south rim
end
task.wait()

-- ================================================================ 2. the central island east of x 0
do
	local gf = folder("CentralGardens", eastF)
	-- the lookout on the south rim (x 8..32) and the basket lift: a log gantry over the edge, a plank basket on chains
	local rimMin = landEnd(false, 48, 1, 8, 32, 80)
	local lz0 = if rimMin then math.max(rimMin - 16, 50) else 0
	if rimMin and rimMin - lz0 >= 8 then
		local lf = folder("Lookout", gf)
		local rimMax = rimMin
		for _, cx in ipairs({ 12, 20, 28 }) do
			rimMax = math.max(rimMax, landEnd(false, 48, 1, cx, cx, 80) or rimMin)
		end
		box("LookoutDeck", 8, -0.2, lz0, 32, 0.3, rimMin, "px_spruce_planks", nil, lf)
		fence(8, rimMin - 1, 12, rimMin - 1, lf, 0.3)
		fence(28, rimMin - 1, 32, rimMin - 1, lf, 0.3)
		fence(8, lz0 + 2, 8, rimMin - 1, lf, 0.3)
		fence(32, lz0 + 2, 32, rimMin - 1, lf, 0.3)
		box("GantryPost", 12, 0.3, rimMin - 4, 16, 20, rimMin, "px_oak_log", nil, lf)
		box("GantryPost", 24, 0.3, rimMin - 4, 28, 20, rimMin, "px_oak_log", nil, lf)
		box("GantryBeam", 12, 20, rimMin - 4, 28, 24, rimMin, "px_oak_log", nil, lf)
		decor(box("GantryJib", 18, 20, rimMin, 22, 24, rimMax + 12, "px_oak_log", nil, lf))
		decor(box("GantryBrace", 18, 16, rimMin, 22, 20, rimMin + 4, "px_dark_oak_planks", nil, lf))
		local pz = rimMax + 8
		local iron = Color3.fromRGB(55, 55, 60)
		decor(part("Pulley", Vector3.new(2, 2, 2), at(20, 19, pz), iron, Enum.Material.Metal, lf))
		-- the basket: a plank floor and four low walls, 2×2 blocks, hanging beside the cliff
		local by = -8
		local bz0, bz1 = rimMax + 4, rimMax + 12
		decor(box("BasketFloor", 16, by, bz0, 24, by + 0.6, bz1, "px_spruce_planks", nil, lf))
		decor(
			box(
				"BasketWall",
				16,
				by + 0.6,
				bz0,
				24,
				by + 3.4,
				bz0 + 0.6,
				"px_planks",
				Color3.fromRGB(200, 160, 110),
				lf
			)
		)
		decor(
			box(
				"BasketWall",
				16,
				by + 0.6,
				bz1 - 0.6,
				24,
				by + 3.4,
				bz1,
				"px_planks",
				Color3.fromRGB(200, 160, 110),
				lf
			)
		)
		decor(
			box(
				"BasketWall",
				16,
				by + 0.6,
				bz0 + 0.6,
				16.6,
				by + 3.4,
				bz1 - 0.6,
				"px_planks",
				Color3.fromRGB(200, 160, 110),
				lf
			)
		)
		decor(
			box(
				"BasketWall",
				23.4,
				by + 0.6,
				bz0 + 0.6,
				24,
				by + 3.4,
				bz1 - 0.6,
				"px_planks",
				Color3.fromRGB(200, 160, 110),
				lf
			)
		)
		decor(
			box(
				"BasketRim",
				15.8,
				by + 3.4,
				bz0 - 0.2,
				24.2,
				by + 3.8,
				bz1 + 0.2,
				"px_dark_oak_planks",
				nil,
				lf
			)
		)
		decor(
			box(
				"BasketLoad",
				17.5,
				by + 0.6,
				bz0 + 1.5,
				20.5,
				by + 3.6,
				bz0 + 4.5,
				"px_white_wool",
				SAP,
				lf
			)
		)
		for _, c in ipairs({
			{ 16.4, bz0 + 0.4 },
			{ 23.6, bz0 + 0.4 },
			{ 16.4, bz1 - 0.4 },
			{ 23.6, bz1 - 0.4 },
		}) do
			decor(
				beam(
					"BasketChain",
					V(20, 18, pz),
					V(c[1], by + 3.8, c[2]),
					0.3,
					iron,
					lf,
					Enum.Material.Metal
				)
			)
		end
		-- the crank on a post and a coil of rope in a barrel
		decor(box("Crank", 10.6, 4, rimMin - 3, 12, 5.4, rimMin - 1, "px_dark_oak_planks", nil, lf))
		decor(
			box(
				"CrankHandle",
				9.6,
				3.2,
				rimMin - 2.4,
				10.6,
				6.2,
				rimMin - 1.6,
				"px_dark_oak_planks",
				nil,
				lf
			)
		)
		barrel(29, 0.3, math.max(rimMin - 10, lz0 + 3), lf, "px_hay")
		crate(11, 0.3, math.max(rimMin - 12, lz0 + 3), lf)
		lamp(20, 16.2, rimMin - 2, lf, 20)
		claim(4, lz0 - 2, 36, rimMax + 2)
		table.insert(CORR, { 4, 36, rimMin - 4, rimMax + 24, -30, 40 })
	end
	-- flower beds: a spruce frame with dark soil and flowers on a block grid
	local function flowerBed(x0, z0, x1, z1)
		local f = folder("FlowerBed", gf)
		box("BedFrame", x0, -0.2, z0, x1, 0.8, z1, "px_spruce_planks", nil, f)
		box(
			"BedSoil",
			x0 + 0.6,
			0.8,
			z0 + 0.6,
			x1 - 0.6,
			0.95,
			z1 - 0.6,
			"px_dirt",
			Color3.fromRGB(96, 70, 50),
			f
		)
		local col = pick(FLOWERS)
		for x = x0 + 2, x1 - 2, 4 do
			for z = z0 + 2, z1 - 2, 4 do
				if rng:NextNumber() < 0.85 then
					flower(x, 0.95, z, f, if rng:NextNumber() < 0.6 then col else nil)
				end
			end
		end
	end
	for _, r in ipairs({
		{ 76, 17, 88, 21 },
		{ 92, 17, 104, 21 },
		{ 106, 17, 114, 21 },
		{ 96, -14, 108, -10 },
		{ 4, 43, 16, 47 },
		{ 34, 43, 46, 47 },
	}) do
		if okArea(r[1], r[2], r[3], r[4], 6) then
			flowerBed(r[1], r[2], r[3], r[4])
			claim(r[1] - 1, r[2] - 1, r[3] + 1, r[4] + 1)
		end
	end
	-- a bench and lamp posts by MAIN STREET and the EAST path
	if okArea(20, 43, 30, 48, 6) then
		bench(25, 45.5, 0, gf)
		claim(20, 43, 30, 48)
	end
	for _, l in ipairs({ { 52, 45 }, { 86, 24 }, { 100, -18 } }) do
		if okArea(l[1] - 2, l[2] - 2, l[1] + 2, l[2] + 2, 6) then
			lampPostL(l[1], l[2], gf, if l[2] < 0 then math.pi else 0)
			claim(l[1] - 3, l[2] - 3, l[1] + 3, l[2] + 3)
		end
	end
	if okArea(110, -14, 114, -10, 6) then
		zoneSign(112, -12, "Восточный остров", 0, gf)
		claim(108, -14, 116, -10)
	end
	-- the beehive tree: an oak with a bee nest under its crown, two hives beside it and bees
	-- (Studio 26.10: the old spots sat on the rim and all failed; the free pocket is east of MAIN STREET, x 60..90)
	for _, c in ipairs({ { 64, 28 }, { 68, 42 }, { 100, 36 }, { 116, -58 }, { 20, 60 } }) do
		local x, z = c[1], c[2]
		if okArea(x - 6, z - 6, x + 14, z + 6, 12) then
			local h = smallTree(x, z, "oak", gf, 0, true)
			local nest = decor(
				box(
					"BeeNest",
					x + 6,
					h - 7.2,
					z - 1.6,
					x + 9.2,
					h - 4,
					z + 1.6,
					"px_hay",
					Color3.fromRGB(240, 204, 130),
					gf
				)
			)
			emitter(nest, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(250, 210, 60)),
				Size = NumberSequence.new(0.35),
				Lifetime = NumberRange.new(3, 5),
				Rate = 3,
				Speed = NumberRange.new(0.6, 1.6),
				SpreadAngle = Vector2.new(180, 180),
				LightInfluence = 1,
			})
			for k = 0, 1 do
				box(
					"Beehive",
					x + 8,
					0,
					z - 6 + k * 6,
					x + 12,
					B,
					z - 2 + k * 6,
					"px_planks",
					Color3.fromRGB(220, 180, 120),
					gf
				)
				decor(
					box(
						"BeehiveTop",
						x + 7.8,
						B,
						z - 6.2 + k * 6,
						x + 12.2,
						B + 0.6,
						z - 1.8 + k * 6,
						"px_hay",
						nil,
						gf
					)
				)
			end
			claim(x - 8, z - 8, x + 14, z + 8)
			break
		end
	end
	-- small trees (3..5)
	local trees = 0
	for _, c in ipairs({
		{ 84, 30, "blossom" },
		{ 112, -22, "azalea" },
		{ 84, 34, "oak" },
		{ 110, 28, "azalea" },
		{ 116, -30, "blossom" },
		{ 122, -46, "oak" },
		{ 8, 58, "azalea" },
		{ 44, 58, "blossom" },
		{ 72, 54, "oak" },
		{ 112, -72, "azalea" },
	}) do
		if trees < 5 and okArea(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6, 8) then
			smallTree(c[1], c[2], c[3], gf, 0, true)
			claim(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
			trees += 1
		end
	end
	-- mossy boulders
	local stones = 0
	for _, c in ipairs({ { 110, -58 }, { 94, 46 }, { 4, 64 }, { 126, -20 }, { 58, 62 } }) do
		if stones < 3 and okArea(c[1] - 9, c[2] - 5, c[1] + 9, c[2] + 5, 8) then
			boulder(c[1], c[2], gf, 0, true)
			claim(c[1] - 9, c[2] - 5, c[1] + 9, c[2] + 5)
			stones += 1
		end
	end
	-- bushes and flowers scattered
	local bushes, flowers = 0, 0
	for _ = 1, 160 do
		local x, z = snap(rng:NextNumber(0, 130)) + 2, snap(rng:NextNumber(-130, 76)) + 2
		if bushes < 14 and okArea(x - 3, z - 3, x + 7, z + 7, 8) then
			bush(x, z, gf, 0, true)
			claim(x - 3, z - 3, x + 7, z + 7)
			bushes += 1
		elseif flowers < 18 and okArea(x - 1, z - 1, x + 1, z + 1, 6) then
			flower(x, 0, z, gf)
			if rng:NextNumber() < 0.5 then
				flower(x + 2, 0, z + 1.5, gf)
			end
			flowers += 1
		end
	end
	task.wait()

	print(
		("[build-tree] east: central gardens %d trees, %d bushes, %d flowers"):format(
			trees,
			bushes,
			flowers
		)
	)
end
task.wait()

-- ================================================================ 3. the east island
do
	local ef = folder("EastIsland", eastF)
	-- the walkway from the bridge landing into the island (4 blocks), coarse dirt with plank patches
	local wx0 = WF.landing or 164
	box("Walkway", wx0, -0.2, -4, 246, 0.1, 12, "px_dirt", COARSE, ef)
	for _, p in ipairs({ { wx0 + 8, wx0 + 20 }, { 196, 204 }, { 226, 238 } }) do
		box("WalkPlanks", p[1], -0.2, -2, p[2], 0.16, 10, "px_planks", nil, ef)
	end
	claim(wx0 - 2, -6, 250, 14)

	-- the pond: a dark bed, a water layer and a low mossy cobblestone rim; the stream leaves through its east rim
	local PX0, PZ0, PX1, PZ1 = 214, 20, 250, 48
	box(
		"PondBed",
		PX0 + 4,
		-0.2,
		PZ0 + 4,
		PX1 - 4,
		0.15,
		PZ1 - 4,
		"px_dirt",
		Color3.fromRGB(84, 76, 70),
		ef
	)
	local water =
		decor(box("PondWater", PX0 + 4, 0.15, PZ0 + 4, PX1 - 4, 1, PZ1 - 4, "px_water", WATER, ef))
	water.Transparency = 0.25
	water.CastShadow = false
	-- the stream row: the core cell row (z 24..32 or 32..40) that reaches furthest east
	local sz0, ex = 24, nil
	for _, cz in ipairs({ 28, 36 }) do
		local e = landEnd(true, 250, 1, cz, cz, 120)
		if e and (not ex or e > ex) then
			sz0, ex = cz - 4, e
		end
	end
	local sz1 = sz0 + 8
	local RIM = "px_mossy_cobblestone"
	box("PondRim", PX0, -0.2, PZ0, PX1, 1.4, PZ0 + 4, RIM, nil, ef)
	box("PondRim", PX0, -0.2, PZ1 - 4, PX1, 1.4, PZ1, RIM, nil, ef)
	box("PondRim", PX0, -0.2, PZ0 + 4, PX0 + 4, 1.4, PZ1 - 4, RIM, nil, ef)
	if ex then
		if sz0 > PZ0 + 4 then
			box("PondRim", PX1 - 4, -0.2, PZ0 + 4, PX1, 1.4, sz0, RIM, nil, ef)
		end
		if sz1 < PZ1 - 4 then
			box("PondRim", PX1 - 4, -0.2, sz1, PX1, 1.4, PZ1 - 4, RIM, nil, ef)
		end
	else
		box("PondRim", PX1 - 4, -0.2, PZ0 + 4, PX1, 1.4, PZ1 - 4, RIM, nil, ef)
	end
	-- mossy stone bricks now and then in the rim
	for _ = 1, 5 do
		local x = PX0 + rng:NextInteger(1, 7) * 4
		local z = if rng:NextNumber() < 0.5 then PZ0 else PZ1 - 4
		box(
			"PondRimBrick",
			x,
			-0.2,
			z - 0.05,
			x + 4,
			1.45,
			z + 4.05,
			"px_mossy_stone_bricks",
			nil,
			ef
		)
	end
	-- lily pads, some in flower
	for _ = 1, 7 do
		local x, z = rng:NextNumber(PX0 + 6, PX1 - 8), rng:NextNumber(PZ0 + 6, PZ1 - 8)
		if not (x > 222 and x < 238 and z < 37) then
			decor(box("LilyPad", x, 1, z, x + 2.4, 1.14, z + 2.4, "px_hedge", GRASS_DEEP, ef))
			if rng:NextNumber() < 0.4 then
				decor(
					box(
						"LilyFlower",
						x + 0.8,
						1.14,
						z + 0.8,
						x + 1.6,
						1.8,
						z + 1.6,
						"px_white_wool",
						BLOSSOM,
						ef
					)
				)
			end
		end
	end
	-- the dock from the walkway side into the pond and the fishing spot at its end
	box("DockStep", 226, -0.2, 13, 234, 0.75, 16, "px_spruce_planks", nil, ef)
	box("Dock", 226, 0.7, 16, 234, 1.5, 36, "px_spruce_planks", nil, ef)
	for _, x in ipairs({ 226, 233 }) do
		decor(box("DockPile", x, 0.15, 35, x + 1, 3, 36, "px_oak_log", BARK, ef))
	end
	barrel(232, 1.5, 32, ef, "px_planks")
	crate(228, 1.5, 32.5, ef, 2)
	decor(
		beam(
			"FishingRod",
			V(228, 4.2, 33),
			V(228, 8.6, 41),
			0.3,
			Color3.fromRGB(110, 80, 50),
			ef,
			Enum.Material.Wood
		)
	)
	decor(
		box(
			"FishingLine",
			227.96,
			1.1,
			40.96,
			228.04,
			8.6,
			41.04,
			nil,
			Color3.fromRGB(235, 235, 235),
			ef
		)
	)
	decor(
		part(
			"Bobber",
			Vector3.new(0.6, 0.6, 0.6),
			at(228, 1.2, 41),
			Color3.fromRGB(200, 40, 40),
			nil,
			ef
		)
	)
	claim(PX0 - 2, PZ0 - 2, PX1 + 2, PZ1 + 2)
	claim(224, 12, 236, 38)

	-- the stream to the rim and the waterfall down the east edge
	if ex then
		local sf = folder("Stream", ef)
		box(
			"StreamBed",
			PX1 - 4,
			-0.2,
			sz0,
			ex,
			0.15,
			sz1,
			"px_dirt",
			Color3.fromRGB(84, 76, 70),
			sf
		)
		local sw = decor(box("StreamWater", PX1 - 4, 0.15, sz0, ex, 1, sz1, "px_water", WATER, sf))
		sw.Transparency = 0.25
		sw.CastShadow = false
		-- the banks stop where their own cell row ends
		local nb0 = landEnd(true, 250, 1, sz0 - 4, sz0 - 4, 120) or PX1
		local nb1 = landEnd(true, 250, 1, sz1 + 4, sz1 + 4, 120) or PX1
		if math.min(ex, nb0) > PX1 then
			box("StreamBank", PX1, -0.2, sz0 - 1, math.min(ex, nb0), 1.4, sz0, RIM, nil, sf)
		end
		if math.min(ex, nb1) > PX1 then
			box("StreamBank", PX1, -0.2, sz1, math.min(ex, nb1), 1.4, sz1 + 1, RIM, nil, sf)
		end
		claim(PX1 - 4, sz0 - 3, ex + 2, sz1 + 3)
		WF.x, WF.z0, WF.z1 = ex, sz0, sz1
		table.insert(CORR, { ex - 12, ex + 40, sz0 - 24, sz1 + 24, -190, 20 })

		local wf = folder("Waterfall", ef)
		local function fallBox(name, x0, y0, z0, x1, y1, z1, tr, variant, tint)
			local p =
				decor(box(name, x0, y0, z0, x1, y1, z1, variant or "px_water", tint or FALL, wf))
			p.Transparency = tr
			p.CastShadow = false
			return p
		end
		-- the lip rolling over the edge, then the column in 5 steps: a little further out, thicker and (below the
		-- island rock, y -60) wider going down; 36 blocks in all
		fallBox("FallLip", ex, -2, sz0, ex + 1.6, 1, sz1, 0.3)
		local mid = (sz0 + sz1) / 2
		local steps = {
			{ -2, -32, 0, 2, 0 },
			{ -32, -64, 0.6, 2.4, 0 },
			{ -64, -96, 1.2, 2.8, 1 },
			{ -96, -128, 1.8, 3.2, 2 },
			{ -128, -144, 2.4, 3.6, 3 },
		}
		for _, s in ipairs(steps) do
			local x0 = ex + s[3]
			local hw = 4 + s[5]
			fallBox("Waterfall", x0, s[2], mid - hw, x0 + s[4], s[1], mid + hw, 0.3)
			-- white streaks of foam on its face
			for _ = 1, 2 do
				local z = rng:NextNumber(mid - hw + 0.5, mid + hw - 1.5)
				local y1 = rng:NextNumber(s[2] + 6, s[1])
				fallBox(
					"FallStreak",
					x0 + s[4],
					y1 - rng:NextNumber(6, 16),
					z,
					x0 + s[4] + 0.15,
					y1,
					z + 1,
					0.45,
					"px_white_wool",
					CLOUD
				)
			end
		end
		-- the foam cloud at the bottom and a slow mist
		local fy = -146
		fallBox(
			"FallFoam",
			ex - 10,
			fy - 4,
			mid - 14,
			ex + 16,
			fy + 4,
			mid + 14,
			0.1,
			"px_white_wool",
			CLOUD
		)
		fallBox(
			"FallFoam",
			ex - 4,
			fy + 4,
			mid - 8,
			ex + 10,
			fy + 8,
			mid + 8,
			0.12,
			"px_white_wool",
			CLOUD
		)
		fallBox(
			"FallFoam",
			ex + 16,
			fy - 4,
			mid - 8,
			ex + 24,
			fy,
			mid + 6,
			0.12,
			"px_white_wool",
			CLOUD
		)
		fallBox(
			"FallFoam",
			ex - 18,
			fy - 8,
			mid - 6,
			ex - 6,
			fy - 4,
			mid + 10,
			0.12,
			"px_white_wool",
			CLOUD
		)
		local mist =
			decor(part("FallMist", Vector3.new(20, 2, 20), at(ex + 3, fy + 6, mid), nil, nil, wf))
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
			Lifetime = NumberRange.new(5, 8),
			Rate = 4,
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(60, 60),
			EmissionDirection = Enum.NormalId.Top,
			RotSpeed = NumberRange.new(-8, 8),
			LightInfluence = 0.8,
		})
		local spray =
			decor(part("FallSpray", Vector3.new(2, 1, 8), at(ex + 1.5, -3, mid), nil, nil, wf))
		spray.Transparency = 1
		spray.CastShadow = false
		emitter(spray, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(240, 246, 252)),
			Size = NumberSequence.new(2, 5),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(0.4, 0.75),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(2, 3),
			Rate = 3,
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Bottom,
			LightInfluence = 0.8,
		})
		-- vines on the cliff faces beside the fall
		for _, row in ipairs({ { sz0 - 8, nb0 }, { sz1, nb1 } }) do
			if row[2] > PX1 then
				for k = 0, 1 do
					local len = rng:NextInteger(2, 6) * B
					local a = row[1] + k * 4
					decor(
						box(
							"FallVine",
							row[2] + 0.3,
							-0.3 - len,
							a,
							row[2] + 1.3,
							-0.3,
							a + B,
							"px_hedge",
							pick({ OAK_LEAF, MOSS }),
							wf
						)
					)
				end
			end
		end
	end
	task.wait()

	-- the gardener's hut (5×5 blocks, the door on its south face toward the walkway)
	local function hut(x0, z0)
		local f = folder("GardenerHut", ef)
		local WALL, LOG = "px_spruce_planks", "px_oak_log"
		box("HutFloor", x0 + 4, -0.2, z0 + 4, x0 + 16, 0.2, z0 + 16, "px_planks", nil, f)
		for _, c in ipairs({ { 0, 0 }, { 16, 0 }, { 0, 16 }, { 16, 16 } }) do
			box("HutCorner", x0 + c[1], 0, z0 + c[2], x0 + c[1] + 4, 12, z0 + c[2] + 4, LOG, nil, f)
		end
		-- walls with a window (a, b: the wall's run; fixed: its 4-stud band across)
		local function wall(alongX, fixed, a, b, door)
			local function wb(u0, y0, u1, y1)
				if alongX then
					box("HutWall", u0, y0, fixed, u1, y1, fixed + 4, WALL, nil, f)
				else
					box("HutWall", fixed, y0, u0, fixed + 4, y1, u1, WALL, nil, f)
				end
			end
			local m0, m1 = a + 4, b - 4
			if door then
				wb(a, 0, m0, 12)
				wb(m1, 0, b, 12)
				wb(m0, 8, m1, 12)
			else
				wb(a, 0, b, 4)
				wb(a, 4, m0, 8)
				wb(m1, 4, b, 8)
				wb(a, 8, b, 12)
			end
		end
		wall(true, z0, x0 + 4, x0 + 16, false)
		wall(true, z0 + 16, x0 + 4, x0 + 16, true)
		wall(false, x0, z0 + 4, z0 + 16, false)
		wall(false, x0 + 16, z0 + 4, z0 + 16, false)
		-- the stepped roof and a chimney
		box("HutRoof", x0 - 4, 12, z0 - 4, x0 + 24, 16, z0 + 24, "px_dark_oak_planks", nil, f)
		box("HutRoof", x0, 16, z0, x0 + 20, 20, z0 + 20, "px_dark_oak_planks", nil, f)
		box("HutRoof", x0 + 4, 20, z0 + 4, x0 + 16, 24, z0 + 16, "px_dark_oak_planks", nil, f)
		box("HutRidge", x0 + 8, 24, z0 + 4, x0 + 12, 28, z0 + 16, "px_spruce_planks", nil, f)
		box("Chimney", x0 + 14, 16, z0 + 2, x0 + 18, 30, z0 + 6, "px_stone_bricks", nil, f)
		-- a flower box under the west window, a lantern by the door, the gardener's things inside
		decor(box("FlowerBox", x0 - 1.4, 2.6, z0 + 8, x0, 4, z0 + 12, "px_spruce_planks", nil, f))
		for k = 0, 1 do
			flower(x0 - 0.7, 4, z0 + 9 + k * 2, f)
		end
		lamp(x0 + 5, 9.4, z0 + 22, f, 12)
		crate(x0 + 6, 0.2, z0 + 6, f)
		barrel(x0 + 14, 0.2, z0 + 6, f, "px_dirt")
		box("Workbench", x0 + 12, 0.2, z0 + 12, x0 + 16, 4, z0 + 16, "px_planks", nil, f)
		decor(
			box(
				"WorkbenchTop",
				x0 + 11.8,
				4,
				z0 + 11.8,
				x0 + 16.2,
				4.4,
				z0 + 16.2,
				"px_spruce_planks",
				nil,
				f
			)
		)
		decor(
			box("Composter", x0 + 21, 0, z0 + 2, x0 + 25, 3.2, z0 + 6, "px_spruce_planks", nil, f)
		)
		decor(
			box(
				"Compost",
				x0 + 21.4,
				3.2,
				z0 + 2.4,
				x0 + 24.6,
				3.4,
				z0 + 5.6,
				"px_dirt",
				Color3.fromRGB(90, 66, 44),
				f
			)
		)
		claim(x0 - 6, z0 - 6, x0 + 26, z0 + 26)
	end
	for _, c in ipairs({ { 200, -26 }, { 180, -26 }, { 220, -26 } }) do
		if okArea(c[1] - 4, c[2] - 4, c[1] + 26, c[2] + 20, 6) then
			hut(c[1], c[2])
			if okArea(c[1] - 10, c[2] + 2, c[1] - 6, c[2] + 6, 6) then
				birdhouse(c[1] - 8, 0, c[2] + 4, ef, true)
			end
			break
		end
	end

	-- the fenced kitchen garden west of the pond: rows of crops, a gate toward the walkway, a scarecrow
	for _, g in ipairs({ { 176, 18, 208, 42 }, { 172, 26, 204, 50 } }) do
		local x0, z0, x1, z1 = g[1], g[2], g[3], g[4]
		if okArea(x0 - 1, z0 - 1, x1 + 1, z1 + 1, 8) then
			local f = folder("KitchenGarden", ef)
			fence(x0, z0, x0 + 12, z0, f)
			fence(x0 + 20, z0, x1, z0, f)
			fence(x1, z0, x1, z1, f)
			fence(x1, z1, x0, z1, f)
			fence(x0, z1, x0, z0, f)
			for r = 0, 2 do
				local rz = z0 + 3 + r * 7
				box(
					"Farmland",
					x0 + 2,
					-0.2,
					rz,
					x1 - 2,
					0.4,
					rz + 4,
					"px_dirt",
					Color3.fromRGB(100, 72, 50),
					f
				)
				local wheat = r == 1
				for x = x0 + 4, x1 - 4, 4 do
					if wheat then
						decor(
							box("Wheat", x - 1, 0.4, rz + 1, x + 1, 2.8, rz + 3, "px_hay", nil, f)
						)
					else
						decor(
							box(
								"Cabbage",
								x - 1,
								0.4,
								rz + 1,
								x + 1,
								1.8,
								rz + 3,
								"px_hedge",
								GRASS,
								f
							)
						)
					end
				end
			end
			-- the scarecrow between the rows
			local sx, sz = (x0 + x1) / 2, z0 + 8.5
			box(
				"ScarecrowPost",
				sx - 0.5,
				0,
				sz - 0.5,
				sx + 0.5,
				7,
				sz + 0.5,
				"px_dark_oak_log",
				BARK,
				f
			)
			decor(
				box(
					"ScarecrowArms",
					sx - 3.5,
					5,
					sz - 0.4,
					sx + 3.5,
					5.8,
					sz + 0.4,
					"px_dark_oak_planks",
					nil,
					f
				)
			)
			decor(
				box(
					"ScarecrowShirt",
					sx - 1.4,
					3.4,
					sz - 0.8,
					sx + 1.4,
					6.2,
					sz + 0.8,
					"px_white_wool",
					Color3.fromRGB(80, 110, 170),
					f
				)
			)
			decor(
				box(
					"ScarecrowHead",
					sx - 1.2,
					7,
					sz - 1.2,
					sx + 1.2,
					9.4,
					sz + 1.2,
					"px_hay",
					nil,
					f
				)
			)
			decor(
				box(
					"ScarecrowHat",
					sx - 1.8,
					9.4,
					sz - 1.8,
					sx + 1.8,
					9.9,
					sz + 1.8,
					"px_hay",
					Color3.fromRGB(180, 140, 80),
					f
				)
			)
			claim(x0 - 2, z0 - 2, x1 + 2, z1 + 2)
			break
		end
	end

	-- lamp posts along the walkway
	for _, l in ipairs({
		{ 184, -8, math.pi },
		{ 168, 16, 0 },
		{ 242, 16, 0 },
		{ 236, -8, math.pi },
	}) do
		if okArea(l[1] - 2, l[2] - 2, l[1] + 2, l[2] + 2, 6) and lit < 18 then
			lampPostL(l[1], l[2], ef, l[3])
			claim(l[1] - 3, l[2] - 3, l[1] + 3, l[2] + 3)
		end
	end
	-- a bench by the pond, small trees, boulders, bushes, flowers
	if okArea(206, 28, 211, 38, 6) then
		bench(208.5, 33, -math.pi / 2, ef)
		claim(205, 27, 212, 39)
	end
	local trees = 0
	for _, c in ipairs({
		{ 236, -32, "blossom" },
		{ 262, -18, "oak" },
		{ 282, 56, "azalea" },
		{ 200, 64, "oak" },
		{ 252, 72, "blossom" },
		{ 168, 42, "azalea" },
		{ 290, 4, "oak" },
		{ 220, 84, "azalea" },
	}) do
		if trees < 6 and okArea(c[1] - 6, c[2] - 6, c[1] + 6, c[2] + 6, 12) then
			smallTree(c[1], c[2], c[3], ef, 0, true)
			claim(c[1] - 8, c[2] - 8, c[1] + 8, c[2] + 8)
			trees += 1
		end
	end
	for _, c in ipairs({ { 272, 66 }, { 190, 76 }, { 280, -12 } }) do
		if okArea(c[1] - 9, c[2] - 5, c[1] + 9, c[2] + 5, 8) then
			boulder(c[1], c[2], ef, 0, true)
			claim(c[1] - 9, c[2] - 5, c[1] + 9, c[2] + 5)
		end
	end
	local bushes, flowers = 0, 0
	for _ = 1, 160 do
		local x, z = snap(rng:NextNumber(150, 310)) + 2, snap(rng:NextNumber(-56, 104)) + 2
		if bushes < 10 and okArea(x - 3, z - 3, x + 7, z + 7, 8) then
			bush(x, z, ef, 0, true)
			claim(x - 3, z - 3, x + 7, z + 7)
			bushes += 1
		elseif flowers < 22 and okArea(x - 1, z - 1, x + 1, z + 1, 6) then
			flower(x, 0, z, ef)
			if rng:NextNumber() < 0.6 then
				flower(x + 1.8, 0, z - 1.6, ef)
			end
			flowers += 1
		end
	end
	print(
		("[build-tree] east: island %d trees, %d bushes, %d flowers, waterfall %s"):format(
			trees,
			bushes,
			flowers,
			tostring(WF.x)
		)
	)
end
task.wait()

-- ================================================================ 4. roots under every island and vines on the rims
do
	local rf = folder("HangingRoots", eastF)
	local C = 8
	local rootParts, vineParts, roots = 0, 0, 0
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local LEAVES = { OAK_LEAF, MOSS, AZALEA, GRASS_DEEP }
	local FAT = { { "px_dirt", ROCK_T }, { "px_oak_log", BARK }, { "px_dark_oak_log", BARK } }
	local function nearDeck(cx, cz)
		for _, r in ipairs(DECKS) do
			if inRect(cx, cz, r, 12) then
				return true
			end
		end
		return false
	end
	for z = -152, 176 - C, C do
		for x = -296, 328 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			local isle = isleOf(cx, cz)
			if isle and (cx - TREE.x) ^ 2 + (cz - TREE.z) ^ 2 > 40 * 40 then
				local outX, outZ, rim = 0, 0, false
				for _, d in ipairs(DIRS) do
					if isleOf(cx + d[1] * C, cz + d[2] * C) == nil then
						rim = true
						outX += d[1]
						outZ += d[2]
						local underFall = WF.x and d[1] == 1 and cz > WF.z0 and cz < WF.z1
						if
							vineParts < 300
							and rng:NextNumber() < 0.3
							and not underFall
							and not nearDeck(cx, cz)
						then
							local face = if d[1] ~= 0 then cx + d[1] * 4 else cz + d[2] * 4
							local along0 = (if d[1] ~= 0 then cz else cx)
								- 4
								+ rng:NextInteger(0, 1) * B
							local s = d[1] + d[2]
							local o0, o1 = face + s * 0.4, face + s * 1.4
							local strands = if rng:NextNumber() < 0.3 then 2 else 1
							for k = 1, strands do
								local len = rng:NextInteger(1, 5) * B
								local v, t = "px_hedge", pick(LEAVES)
								if rng:NextNumber() < 0.12 then
									v, t = "px_cherry_leaves", BLOSSOM
								end
								local a = if k == 1
									then along0
									else (if along0
											> (if d[1] ~= 0 then cz else cx) - 4
										then along0 - B
										else along0 + B)
								if d[1] ~= 0 then
									decor(
										box("RimVine", o0, -0.3 - len, a, o1, -0.3, a + B, v, t, rf)
									)
								else
									decor(
										box("RimVine", a, -0.3 - len, o0, a + B, -0.3, o1, v, t, rf)
									)
								end
								vineParts += 1
							end
						end
					end
				end
				local nearFall = WF.x and cx > WF.x - 40 and cz > WF.z0 - 24 and cz < WF.z1 + 24
				if
					not nearFall
					and rootParts < 1050
					and rng:NextNumber() < (if rim then 0.4 else 1 / 6)
				then
					local c = if isle == "west"
						then WEST
						elseif isle == "central" then CENTRAL
						else EAST
					local rr = math.clamp(math.sqrt((cx - c.x) ^ 2 + (cz - c.z) ^ 2) / c.r, 0, 1)
					local bottom = -4 - rockDepth(cx, cz)
					local L = if rim
						then rng:NextInteger(4, 10)
						else math.clamp(
							math.floor(4 + (1 - rr) * 20 * rng:NextNumber(0.55, 1)),
							4,
							24
						)
					L = math.min(L, math.floor((bottom + 236) / B)) -- stay above the void net
					if L >= 3 then
						local y = bottom + 2
						local c0 = count
						local function down(sx, sz, s, blocks, v, t)
							local len = blocks * B + (if y > bottom then 2 else 0)
							decor(box("Root", sx, y - len, sz, sx + s, y, sz + s, v, t, rf))
							y -= len
						end
						local qx = if outX > 0
							then 1
							elseif outX < 0 then 0
							else rng:NextInteger(0, 1)
						local qz = if outZ > 0
							then 1
							elseif outZ < 0 then 0
							else rng:NextInteger(0, 1)
						local rest = L
						if not rim and L >= 10 then
							local a = math.max(2, math.floor(L * 0.3))
							local m = pick(FAT)
							down(x, z, 2 * B, a, m[1], m[2])
							rest -= a
						end
						local b = math.max(1, math.floor(rest * 0.55))
						down(
							x + qx * B,
							z + qz * B,
							B,
							b,
							pick({ "px_oak_log", "px_dark_oak_log" }),
							BARK
						)
						rest -= b
						if rest >= 1 then
							local sx = x + qx * B + pick({ 0.2, 2.6 })
							local sz = z + qz * B + pick({ 0.2, 2.6 })
							local s1 = math.max(
								1,
								rest - (if rest >= 3 and rng:NextNumber() < 0.5 then 1 else 0)
							)
							down(sx, sz, 1.2, s1, "px_dark_oak_log", BARK_DARK)
							if s1 < rest then
								-- a stepped jog at the end
								down(
									sx + (if sx > x + qx * B + 1 then -1.2 else 1.2),
									sz,
									1.2,
									rest - s1,
									"px_dark_oak_log",
									BARK_DARK
								)
							end
						end
						rootParts += count - c0
						roots += 1
					end
				end
			end
		end
		if z % 32 == 0 then
			task.wait()
		end
	end
	print(
		("[build-tree] east: roots %d (%d parts), rim vines %d"):format(roots, rootParts, vineParts)
	)
end
task.wait()

-- ================================================================ 5–6. floating islets and clouds
do
	local sky = folder("Sky", eastF)
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
	-- no island cell within `half` + 24 studs (horizontally) of (x, z)
	local function clearOfIslands(x, z, half)
		local e = half + 24
		local near = false
		for _, c in ipairs({ WEST, CENTRAL, EAST }) do
			if math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) < c.r + 12 + e * 1.42 then
				near = true
				break
			end
		end
		if not near then
			return true
		end
		local n = math.max(1, math.ceil(2 * e / 8))
		for i = 0, n do
			for j = 0, n do
				if isleOf(x - e + 2 * e * i / n, z - e + 2 * e * j / n) ~= nil then
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
			local x, z, y =
				rng:NextNumber(-420, 460), rng:NextNumber(-300, 320), rng:NextNumber(yMin, yMax)
			local ok = not blocked(x - half, x + half, z - half, z + half, y - down, y + up)
				and not (math.sqrt((x - TREE.x) ^ 2 + (z - TREE.z) ^ 2) < 100 + half and y + up > 40)
				and clearOfIslands(x, z, half)
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

	-- 5. the floating islets
	local fly = folder("FloatingIslets", sky)
	local c0 = count
	local islets, lamps = 2, 0 -- two bridged ones are built with the bridges
	local want = rng:NextInteger(16, 18)
	for i = 1, 40 do
		if islets - 2 >= want or count - c0 > 860 then
			break
		end
		local w, d = rng:NextInteger(2, 6), rng:NextInteger(2, 6)
		local half = math.max(w, d) * B / 2 + 2
		local treeOn = w * d >= 12 and rng:NextNumber() < 0.6
		local x, y, z = findSpot(half, 64, if treeOn then 30 else 14, -60, 80)
		if x then
			x, y, z = snap(x), math.floor(y), snap(z)
			local f = islet(x, y, z, w, d, fly, false)
			-- the props on the top (decor): a tree, or a bush, a birdhouse, a lantern post, flowers
			local hx, hz = w * B / 2, d * B / 2
			local px, pz =
				x - hx + rng:NextInteger(0, w - 1) * B + 2,
				z - hz + rng:NextInteger(0, d - 1) * B + 2
			if treeOn then
				smallTree(px, pz, pick({ "oak", "azalea", "blossom", "azalea" }), f, y, false)
			else
				local r = rng:NextInteger(1, 4)
				if r == 1 then
					bush(px, pz, f, y, false)
				elseif r == 2 then
					birdhouse(px, y, pz, f, false)
				elseif r == 3 then
					decor(
						box(
							"IsletLampPost",
							px - 0.5,
							y,
							pz - 0.5,
							px + 0.5,
							y + 7,
							pz + 0.5,
							"px_dark_oak_log",
							BARK,
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
							"px_dark_oak_planks",
							nil,
							f
						)
					)
					lamp(px, y + 4.6, pz + 2.4, f, y + 6.5, lamps >= 3)
					lamps += 1
				end
				for _ = 1, rng:NextInteger(1, 3) do
					flower(
						x - hx + rng:NextNumber(1, w * B - 1),
						y,
						z - hz + rng:NextNumber(1, d * B - 1),
						f
					)
				end
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
	-- the layer under the islands, where the roots end: always under the rock it covers
	for attempt = 1, 400 do
		if low >= 44 then
			break
		end
		local x, z
		if attempt % 3 == 0 then
			x, z = rng:NextNumber(-400, 440), rng:NextNumber(-280, 300)
		else
			x, z = rng:NextNumber(-300, 330), rng:NextNumber(-160, 180)
		end
		x, z = snap(x), snap(z)
		local w, d, th = rng:NextInteger(6, 20), rng:NextInteger(5, 14), rng:NextInteger(1, 3)
		local y = snap(rng:NextNumber(-200, -120))
		local hx, hz = w * B / 2 + 4, d * B / 2 + 4
		local floor0 = 0
		for px = x - hx, x + hx, 8 do
			for pz = z - hz, z + hz, 8 do
				if isleOf(px, pz) then
					floor0 = math.min(floor0, -4 - rockDepth(px, pz))
				end
			end
		end
		local h = (th + 1) * B
		if y + h > floor0 - 8 then
			y = floor0 - 8 - h
		end
		if y >= -232 and not blocked(x - hx, x + hx, z - hz, z + hz, y - B, y + h) then
			cloud(x, y, z, w, d, th)
			low += 1
		end
		if attempt % 50 == 0 then
			task.wait()
		end
	end
	-- a few round the edges of the cluster, off the islands and the islets
	for _ = 1, 30 do
		if edge >= 16 then
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
		("[build-tree] east: islets %d (%d parts), clouds %d low + %d round the edges"):format(
			islets,
			isletParts,
			low,
			edge
		)
	)
end
print(
	("[build-tree] east: %d parts in all, %d lights"):format(count - startCount, math.min(lit, 20))
)
