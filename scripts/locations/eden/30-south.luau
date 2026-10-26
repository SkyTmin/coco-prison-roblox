--!nocheck
-- ================================================================ eden: the south garden (zone "south": z > -52 outside the hill)
-- The mine, the arrival and the gardens round them [concept: assets/concepts/eden/concept-v2.webp]:
--   pit fence     dark oak posts and rails 1 block outside the rim (x -114 / 34, z 54 / 202), open at the ladder shafts
--                 (x -52..-28 north and south, z 116..140 west) and wide on the east toward the arrival (z 100..156);
--                 lanterns on dark oak log stumps at the corners and the openings (the NE corner on the CROSS path
--                 keeps a plain post)
--   mushrooms     giant umbrella mushrooms (white stems, stepped terracotta caps with white dots): M1 (-92, 36),
--                 M3 (-132, 84), M4 (-128, 164), M5 (48, 190), M6 (72, 52), M8 (-132, 0); small clusters at (-68, 44),
--                 (-128, 100), (-108, 20)
--   leaf arches   three over the EAST path (z 60, 72, 84; legs x 34 / 58), two over the garden spine W2 (z 20, 140)
--   walks         coarse dirt, flush, 4 blocks: W1 x 56..196 z 88..104 (from the EAST path), W2 x 142..158
--                 z -40..184 (from the east bridge landing), W3 x 60..148 z 168..184, W4 x 84..100 z 104..168,
--                 W6 x -164..-114 z 120..136 (to the west opening),
--                 W7 x -158..-142 z -40..120 (from the west bridge landing to W6); the bridge landings x ±138..±162,
--                 z -52..-30 stay clear
--   south-east    gazebo G1 (126, -32) by the pond (x 104..132, z -16..12) with the pink cherry-plank bridge
--                 (x 96..142, z -6..6) and the bamboo grove (x 100..116, z -46..-26); gazebo G2 (120, 136) between
--                 flower beds; beds of single-colour rows; apple trees (66, 24), (100, 56), (128, 72), (168, 120),
--                 (164, 156); cherry trees (96, 28), (176, -28), (190, 40), (88, 194); the apiary (104..120, 80);
--                 trellises (164, 36 / 54 / 70); the mossy arch ruin (184, 76); deer, rabbits, benches, lamp posts
--   south-west    the orchard row (x -176, z -20..64), a cherry (-126, 40), the fenced vegetable patch (x -192..-160,
--                 z 84..116), the tool shed (-170, 150), flower beds; vines hanging over the west, south and east rim
local southF = folder("SouthGarden")
local startCount = count
local C = {
	red = Color3.fromRGB(220, 50, 50),
	yellow = Color3.fromRGB(245, 215, 60),
	white = Color3.fromRGB(246, 246, 240),
	purple = Color3.fromRGB(170, 100, 220),
	blue = Color3.fromRGB(90, 130, 235),
	orange = Color3.fromRGB(240, 140, 40),
	stem = Color3.fromRGB(242, 238, 228),
	gill = Color3.fromRGB(232, 210, 180),
	dot = Color3.fromRGB(252, 250, 244),
	honey = Color3.fromRGB(255, 214, 120),
	stripe = Color3.fromRGB(96, 64, 30),
	bee = Color3.fromRGB(245, 200, 40),
	black = Color3.fromRGB(28, 26, 24),
	wing = Color3.fromRGB(235, 245, 255),
	deer = Color3.fromRGB(172, 116, 72),
	deerDark = Color3.fromRGB(110, 76, 48),
	antler = Color3.fromRGB(205, 185, 150),
	cream = Color3.fromRGB(245, 236, 216),
	hare = Color3.fromRGB(190, 150, 112),
	soil = Color3.fromRGB(150, 110, 80),
	carrot = Color3.fromRGB(236, 128, 36),
	beet = Color3.fromRGB(150, 40, 72),
	wheat = Color3.fromRGB(238, 212, 112),
	cabbage = Color3.fromRGB(200, 235, 160),
	bamboo = Color3.fromRGB(170, 220, 120),
	bambooNode = Color3.fromRGB(120, 160, 70),
	lily = Color3.fromRGB(150, 210, 120),
	reed = Color3.fromRGB(130, 170, 80),
	iron = Color3.fromRGB(70, 70, 76),
	handle = Color3.fromRGB(140, 100, 62),
	window = Color3.fromRGB(40, 50, 60),
}
C.flowers = { C.red, C.yellow, C.white, C.purple, C.blue, PINK_WOOL }
C.archFlowers = { PINK_WOOL, C.white, C.purple, PINK_WOOL, C.yellow }
-- the part's state: lit lanterns (≤ 22 PointLights) and the footprints already used
local st = { lights = 0, cap = 22, taken = {} }

-- the point and the corners of its pad square belong to this part
local function inZone(x, z, pad)
	pad = pad or 0
	for _, c in ipairs({ { 0, 0 }, { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		if zoneOf(x + c[1] * pad, z + c[2] * pad) ~= "south" then
			return false
		end
	end
	return true
end
local function take(x0, z0, x1, z1)
	table.insert(st.taken, { x0, z0, x1, z1 })
end
local function isTaken(x, z, pad)
	pad = pad or 0
	for _, t in ipairs(st.taken) do
		if x >= t[1] - pad and x <= t[3] + pad and z >= t[2] - pad and z <= t[4] + pad then
			return true
		end
	end
	return false
end
-- free ground for a solid prop of half-size pad (warns when `what` is given, so the evening check can look at it)
local function spot(x, z, pad, what)
	local ok = freeGround(x, z, pad) and inZone(x, z, pad + 2) and not isTaken(x, z, pad)
	if not ok and what then
		warn(("[build-eden] south: %s at (%g, %g) skipped"):format(what, x, z))
	end
	return ok
end
-- a rectangle whose corners and centre are free ground of this part
local function rectFree(x0, z0, x1, z1, what)
	for _, p in ipairs({
		{ x0, z0 },
		{ x1, z0 },
		{ x1, z1 },
		{ x0, z1 },
		{ (x0 + x1) / 2, (z0 + z1) / 2 },
	}) do
		if
			not freeGround(p[1], p[2], 0)
			or zoneOf(p[1], p[2]) ~= "south"
			or isTaken(p[1], p[2], 0)
		then
			if what then
				warn(
					("[build-eden] south: %s at (%g, %g) skipped"):format(
						what,
						(x0 + x1) / 2,
						(z0 + z1) / 2
					)
				)
			end
			return false
		end
	end
	return true
end
-- a kit lantern in its own folder; only `lit` ones keep their PointLight while the cap allows
local function lamp(pos, parent, hangTop, lit)
	local f = folder("Lantern", parent)
	lantern(pos, f, false, hangTop)
	if lit and st.lights < st.cap then
		st.lights += 1
	else
		local l = f:FindFirstChildWhichIsA("PointLight", true)
		if l then
			l:Destroy()
		end
	end
	return f
end
-- a frame at local (x, z) turned by yaw; its front is -Z (yaw 0 faces north, pi south, pi/2 west, -pi/2 east)
local function fr(x, z, yaw, y)
	return at(x, y or 0, z) * CFrame.Angles(0, yaw or 0, 0)
end
-- a textured box in a frame cf by two local corners
local function lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(
		name,
		size,
		cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		tint,
		nil,
		parent
	)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a small decor block of tinted white wool in a frame cf by size and local centre (animals, flowers)
local function lw(cf, name, sx, sy, sz, x, y, z, tint, parent)
	local p = decor(part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), nil, nil, parent))
	p.CastShadow = false
	return textured(p, "px_white_wool", tint)
end
-- a garden walk of coarse dirt, flush with the grass (0.06 above it), cut where the island ends
local function walk(x0, z0, x1, z1, parent)
	take(x0, z0, x1, z1)
	local alongX = (x1 - x0) >= (z1 - z0)
	local a0 = if alongX then x0 else z0
	local a1 = if alongX then x1 else z1
	local s
	local function ok(a)
		if alongX then
			return onIsland(a + 2, z0 + 2, 6) and onIsland(a + 2, z1 - 2, 6)
		end
		return onIsland(x0 + 2, a + 2, 6) and onIsland(x1 - 2, a + 2, 6)
	end
	local function flush(e)
		if s and e > s then
			if alongX then
				box("GardenWalk", s, -0.5, z0, e, 0.06, z1, "px_dirt", PATH, parent)
			else
				box("GardenWalk", x0, -0.5, s, x1, 0.06, e, "px_dirt", PATH, parent)
			end
		end
		s = nil
	end
	for a = a0, a1 - 4, 4 do
		if ok(a) then
			s = s or a
		else
			flush(a)
		end
	end
	flush(a1)
end
-- a giant umbrella mushroom: h blocks to the cap, stem s blocks wide (0 = a thin 2-stud stem), cap w blocks wide;
-- a stepped terracotta cap with a hanging rim and pale gills, white dots on top; caps below head height are decor
local function mushroom(x, z, h, s, w, parent)
	local f = folder("GiantMushroom", parent)
	local H = h * B
	local sw = if s > 0 then s * B else 2
	local stem = cube("MushroomStem", x, H / 2, z, sw, H, sw, "px_white_wool", C.stem, f)
	if s == 0 then
		decor(stem)
	end
	local hw = w * B / 2
	local solid = H - B >= 10
	local function capBox(name, x0, y0, z0, x1, y1, z1)
		local p = box(name, x0, y0, z0, x1, y1, z1, "px_terracotta", MUSHROOM, f)
		if not solid then
			decor(p)
		end
		return p
	end
	capBox("MushroomCap", x - hw, H, z - hw, x + hw, H + B, z + hw)
	local top = H + B
	if w >= 3 then
		capBox("MushroomCapTop", x - hw + B, H + B, z - hw + B, x + hw - B, H + 2 * B, z + hw - B)
		top = H + 2 * B
		if w >= 5 then
			capBox("MushroomRim", x - hw, H - B, z - hw, x + hw, H, z - hw + B)
			capBox("MushroomRim", x - hw, H - B, z + hw - B, x + hw, H, z + hw)
			capBox("MushroomRim", x - hw, H - B, z - hw + B, x - hw + B, H, z + hw - B)
			capBox("MushroomRim", x + hw - B, H - B, z - hw + B, x + hw, H, z + hw - B)
			decor(
				box(
					"MushroomGills",
					x - hw + B,
					H - 0.3,
					z - hw + B,
					x + hw - B,
					H,
					z + hw - B,
					nil,
					C.gill,
					f
				)
			)
		end
	end
	-- the white dots: on the top step and on the ledge round it
	for i = 1, w + 1 do
		local dx, dz, y
		if w >= 3 and i % 2 == 0 then
			local r = hw - B - 1.2
			dx, dz, y = rng:NextNumber(-r, r), rng:NextNumber(-r, r), top
		elseif w >= 3 then
			local along = rng:NextNumber(-hw + 1.2, hw - 1.2)
			local across = hw - B / 2
			local side = rng:NextInteger(1, 4)
			if side == 1 then
				dx, dz = along, -across
			elseif side == 2 then
				dx, dz = along, across
			elseif side == 3 then
				dx, dz = -across, along
			else
				dx, dz = across, along
			end
			y = H + B
		else
			local r = hw - 1.2
			dx, dz, y = rng:NextNumber(-r, r), rng:NextNumber(-r, r), top
		end
		local d = decor(
			part(
				"MushroomDot",
				Vector3.new(1.6, 0.24, 1.6),
				at(x + dx, y + 0.12, z + dz),
				C.dot,
				nil,
				f
			)
		)
		d.CastShadow = false
	end
	take(x - sw / 2 - 1, z - sw / 2 - 1, x + sw / 2 + 1, z + sw / 2 + 1)
	return f
end
-- an apple tree: an oak trunk, a blocky crown of hedge leaves (a full layer, a cross, a top), red apples
local function appleTree(x, z, h, parent)
	local f = folder("AppleTree", parent)
	cube("Trunk", x, (h + 4) / 2, z, B, h + 4, B, "px_oak_log", nil, f)
	local function leaf(cx, y0, cz, sx, sy, sz)
		return cube("Leaves", cx, y0 + sy / 2, cz, sx, sy, sz, "px_hedge", LEAF, f)
	end
	leaf(x, h - 2, z, 20, 4, 20)
	leaf(x, h + 2, z, 20, 4, 12)
	leaf(x, h + 2, z - 8, 12, 4, 4)
	leaf(x, h + 2, z + 8, 12, 4, 4)
	leaf(x, h + 6, z, 12, 4, 12)
	-- loose leaf blocks on the sides of the bottom layer
	for i = 1, 3 do
		local o = rng:NextInteger(-1, 1) * B
		local side = (i + rng:NextInteger(0, 3)) % 4
		local dx, dz = 12, o
		if side == 1 then
			dx, dz = -12, o
		elseif side == 2 then
			dx, dz = o, 12
		elseif side == 3 then
			dx, dz = o, -12
		end
		leaf(x + dx, h - 2, z + dz, B, B, B)
	end
	for i = 1, 8 do
		local t = rng:NextNumber(-7.5, 7.5)
		local y = h - 1.2 + rng:NextNumber(0, 2.4)
		local side = i % 4
		local ax, az = x + 10.5, z + t
		if side == 1 then
			ax, az = x - 10.5, z + t
		elseif side == 2 then
			ax, az = x + t, z + 10.5
		elseif side == 3 then
			ax, az = x + t, z - 10.5
		end
		if i > 6 then
			-- hanging under the crown
			ax, az, y = x + rng:NextNumber(-8, 8), z + rng:NextNumber(-8, 8), h - 2.7
		end
		local p = decor(part("Apple", Vector3.new(1.4, 1.4, 1.4), at(ax, y, az), APPLE, nil, f))
		p.CastShadow = false
	end
	local a = rng:NextNumber(0, math.pi * 2)
	decor(
		part(
			"FallenApple",
			Vector3.new(1.4, 1.4, 1.4),
			at(x + math.cos(a) * 6, 0.7, z + math.sin(a) * 6),
			APPLE,
			nil,
			f
		)
	)
	take(x - 3, z - 3, x + 3, z + 3)
	return f
end
-- a pink cherry tree: a cherry log with a bend, a wide blossom crown, hanging blossoms and petals on the grass
local function cherryTree(x, z, h, parent)
	local f = folder("CherryTree", parent)
	cube("Trunk", x, h / 2, z, B, h, B, "px_cherry_log", nil, f)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local d = dirs[rng:NextInteger(1, 4)]
	cube("Branch", x + d[1] * B, h - 2, z + d[2] * B, B, B, B, "px_cherry_log", nil, f)
	local function leaf(cx, y0, cz, sx, sy, sz, deco)
		local p = cube("Blossom", cx, y0 + sy / 2, cz, sx, sy, sz, "px_cherry_leaves", BLOSSOM, f)
		if deco then
			decor(p)
		end
		return p
	end
	leaf(x, h, z, 28, 4, 20)
	leaf(x, h, z - 12, 20, 4, 4)
	leaf(x, h, z + 12, 20, 4, 4)
	leaf(x + d[1] * 2, h + 4, z + d[2] * 2, 20, 4, 20)
	leaf(x, h + 8, z, 12, 4, 12)
	-- blossoms hanging under the crown edge
	for i = 1, 4 do
		local o = rng:NextInteger(-2, 2) * B
		local side = (i + rng:NextInteger(0, 1)) % 4
		local dx, dz = 12, o
		if side == 1 then
			dx, dz = -12, o
		elseif side == 2 then
			dx, dz = math.clamp(o, -8, 8), 12
		elseif side == 3 then
			dx, dz = math.clamp(o, -8, 8), -12
		end
		leaf(x + dx, h - rng:NextInteger(1, 2) * B, z + dz, B, rng:NextInteger(1, 2) * B, B, true)
	end
	-- fallen petals
	for _ = 1, 5 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(4, 13)
		local s = if rng:NextNumber() < 0.5 then 4 else 2
		local p = decor(
			part(
				"Petals",
				Vector3.new(s, 0.12, s),
				at(x + math.cos(a) * r, 0.06, z + math.sin(a) * r),
				nil,
				nil,
				f
			)
		)
		textured(p, "px_white_wool", PINK_WOOL)
		p.CastShadow = false
	end
	take(x - 3, z - 3, x + 3, z + 3)
	return f
end
-- a spruce bench; front (where you sit facing) is -Z of the frame
local function bench(x, z, yaw, parent)
	local cf = fr(x, z, yaw)
	local f = folder("Bench", parent)
	lb(cf, "BenchSeat", -4, 1.8, -1.2, 4, 2.4, 1.2, "px_spruce_planks", nil, f)
	lb(cf, "BenchLeg", -4, 0, -1.2, -3, 1.8, 1.2, "px_dark_oak_planks", nil, f)
	lb(cf, "BenchLeg", 3, 0, -1.2, 4, 1.8, 1.2, "px_dark_oak_planks", nil, f)
	lb(cf, "BenchBack", -4, 2.4, 0.8, 4, 4.8, 1.3, "px_spruce_planks", nil, f)
	take(x - 4, z - 4, x + 4, z + 4)
end
local function rabbit(x, z, yaw, col, parent)
	local cf = fr(x, z, yaw)
	local f = folder("Rabbit", parent)
	lw(cf, "RabbitBody", 1.6, 1.4, 2.2, 0, 0.7, 0.2, col, f)
	lw(cf, "RabbitHead", 1.2, 1.2, 1.2, 0, 1.5, -1.0, col, f)
	lw(cf, "RabbitEar", 0.35, 1.2, 0.3, -0.3, 2.6, -0.9, col, f)
	lw(cf, "RabbitEar", 0.35, 1.2, 0.3, 0.3, 2.6, -0.9, col, f)
	lw(cf, "RabbitTail", 0.6, 0.6, 0.5, 0, 1.0, 1.45, C.cream, f)
end
-- a blocky deer looking toward -Z of its frame; the body is solid, the rest decor
local function deer(x, z, yaw, parent)
	local cf = fr(x, z, yaw)
	local f = folder("Deer", parent)
	local body = part("DeerBody", Vector3.new(3, 3, 6.4), cf * CFrame.new(0, 5.5, 0.4), nil, nil, f)
	textured(body, "px_white_wool", C.deer)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			lw(cf, "DeerLeg", 0.9, 4, 0.9, sx * 1, 2, 0.4 + sz * 2.4, C.deerDark, f)
		end
	end
	lw(cf, "DeerBelly", 2.6, 0.4, 5, 0, 3.9, 0.4, C.cream, f)
	lw(cf, "DeerNeck", 1.5, 3, 1.5, 0, 7.8, -2.3, C.deer, f)
	lw(cf, "DeerHead", 2, 2, 2.8, 0, 9.6, -3.2, C.deer, f)
	lw(cf, "DeerMuzzle", 1.2, 1, 1, 0, 9.1, -5, C.deerDark, f)
	lw(cf, "DeerTail", 0.8, 0.8, 0.5, 0, 6.3, 3.75, C.cream, f)
	for _, s in ipairs({ -1, 1 }) do
		lw(cf, "DeerEar", 1, 0.5, 0.4, s * 1.3, 10.4, -2.4, C.deer, f)
		lw(cf, "Antler", 0.4, 2.4, 0.4, s * 0.7, 11.8, -2.8, C.antler, f)
		lw(cf, "Antler", 1.4, 0.4, 0.4, s * 1.2, 12.6, -2.8, C.antler, f)
		lw(cf, "Antler", 0.4, 1.4, 0.4, s * 1.8, 13.5, -2.8, C.antler, f)
	end
	take(x - 4, z - 4, x + 4, z + 4)
end
-- a flower bed of single-colour rows (rows run along `axis`, 4 studs apart), a low curb round it
local function bed(x0, z0, x1, z1, axis, colors, parent, curbV)
	if not rectFree(x0 - 1, z0 - 1, x1 + 1, z1 + 1, "flower bed") then
		return
	end
	local f = folder("FlowerBed", parent)
	take(x0 - 1, z0 - 1, x1 + 1, z1 + 1)
	curbV = curbV or "px_mossy_stone_bricks"
	decor(box("BedCurb", x0 - 1, 0, z0 - 1, x1 + 1, 0.8, z0, curbV, nil, f))
	decor(box("BedCurb", x0 - 1, 0, z1, x1 + 1, 0.8, z1 + 1, curbV, nil, f))
	decor(box("BedCurb", x0 - 1, 0, z0, x0, 0.8, z1, curbV, nil, f))
	decor(box("BedCurb", x1, 0, z0, x1 + 1, 0.8, z1, curbV, nil, f))
	local u0, u1, a0, a1 = z0, z1, x0, x1
	if axis == "z" then
		u0, u1, a0, a1 = x0, x1, z0, z1
	end
	local function rowBox(name, y0, y1, r0, r1, variant, tint)
		if axis == "x" then
			return decor(box(name, a0 + 0.5, y0, r0, a1 - 0.5, y1, r1, variant, tint, f))
		end
		return decor(box(name, r0, y0, a0 + 0.5, r1, y1, a1 - 0.5, variant, tint, f))
	end
	for k = 0, math.floor((u1 - u0) / 4) - 1 do
		local col = colors[k % #colors + 1]
		local r0 = u0 + k * 4 + 0.5
		local r1 = r0 + 3
		rowBox("BedLeaves", 0, 1.0, r0, r1, "px_hedge", LEAF)
		rowBox("BedFlowers", 1.0, 1.7, r0 + 0.3, r1 - 0.3, "px_white_wool", col)
		local a = a0 + 2 + (k % 2) * 3
		while a < a1 - 1.5 do
			local u = (r0 + r1) / 2 + rng:NextNumber(-0.6, 0.6)
			local p = decor(
				part(
					"Flower",
					Vector3.new(1.3, 1.3, 1.3),
					if axis == "x" then at(a, 2.15, u) else at(u, 2.15, a),
					nil,
					nil,
					f
				)
			)
			textured(p, "px_white_wool", col)
			p.CastShadow = false
			a += 6
		end
	end
end

-- ================================================================ keep-outs and the garden walks
do
	take(62, 106, 74, 118) -- the zone sign
	take(54, 138, 78, 162) -- the buyer's stall, its crate, barrel and lamp post
	take(-56, 36, -24, 54) -- the approach to the north opening of the fence
	take(-56, 202, -24, 222) -- the approach to the south opening
	take(138, -52, 162, -30) -- the landing of the north part's east river bridge
	take(-162, -52, -138, -30) -- the landing of the west river bridge
	local wf = folder("GardenWalks", southF)
	walk(56, 88, 196, 104, wf) -- W1 east from the EAST path
	walk(142, -40, 158, 184, wf) -- W2 the garden spine from the east bridge landing
	walk(60, 168, 148, 184, wf) -- W3 south of the buyer
	walk(84, 104, 100, 168, wf) -- W4 between W1 and W3
	walk(-164, 120, -114, 136, wf) -- W6 to the west opening of the fence
	walk(-158, -40, -142, 120, wf) -- W7 from the west bridge landing south to W6
end

-- ================================================================ the fence round the pit
do
	local f = folder("PitFence", southF)
	local R = PIT_HALF + 2 * B + 2 -- 74: one block outside the mossy rim
	local function world(side, u)
		if side == "N" then
			return PIT.x + u, PIT.z - R
		elseif side == "S" then
			return PIT.x + u, PIT.z + R
		elseif side == "W" then
			return PIT.x - R, PIT.z + u
		end
		return PIT.x + R, PIT.z + u
	end
	local function rails(ax, az, bx, bz)
		local a, b = V(ax, 0, az), V(bx, 0, bz)
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 8 + 0.5))
		for i = 0, n do
			local p = a:Lerp(b, i / n)
			if onIsland(p.X - BX, p.Z - BZ, 4) then
				textured(
					part(
						"FencePost",
						Vector3.new(1.6, 4.4, 1.6),
						CFrame.new(p + Vector3.new(0, 2.2, 0)),
						nil,
						nil,
						f
					),
					"px_dark_oak_log"
				)
			end
		end
		for _, h in ipairs({ 1.6, 3.4 }) do
			local rail = part(
				"FenceRail",
				Vector3.new(0.5, 0.7, len),
				CFrame.lookAt((a + b) / 2 + Vector3.new(0, h, 0), b + Vector3.new(0, h, 0)),
				nil,
				nil,
				f
			)
			textured(rail, "px_dark_oak_planks")
		end
	end
	local function stump(x, z)
		if onPath(x, z, 1.9) then
			-- the CROSS path passes the north-east corner: a plain post keeps the path clear
			textured(
				part("FencePost", Vector3.new(1.6, 4.4, 1.6), at(x, 2.2, z), nil, nil, f),
				"px_dark_oak_log"
			)
			return
		end
		cube("LanternStump", x, 2, z, B, B, B, "px_dark_oak_log", nil, f)
		lamp(V(x, 4.75, z), f, nil, true)
	end
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		stump(PIT.x + c[1] * R, PIT.z + c[2] * R)
	end
	-- each side: the opening (the ladder shaft ± 1 block; the east wide toward the arrival), its stumps, two runs
	for _, s in ipairs({ { "N", 12 }, { "S", 12 }, { "W", 12 }, { "E", 28 } }) do
		local side, o = s[1], s[2]
		local ax, az = world(side, -o - 2)
		local bx, bz = world(side, o + 2)
		stump(ax, az)
		stump(bx, bz)
		local p0x, p0z = world(side, -R + 2)
		local p1x, p1z = world(side, -o - 4)
		rails(p0x, p0z, p1x, p1z)
		local q0x, q0z = world(side, o + 4)
		local q1x, q1z = world(side, R - 2)
		rails(q0x, q0z, q1x, q1z)
	end
end
task.wait()

-- ================================================================ leaf arches with flowers over the paths
do
	local af = folder("LeafArches", southF)
	-- an arch across a north-south path centred at (cx, cz): legs `span` apart (mossy stone base, hedge leg), a
	-- stepped leafy top 12..20 studs up, flowers, wisteria hanging inside, maybe a lit lantern under the top
	local function arch(cx, cz, span, lit)
		local f = folder("LeafArch", af)
		local cf = fr(cx, cz, 0)
		local o = span / 2
		for _, s in ipairs({ -1, 1 }) do
			lb(cf, "ArchBase", s * o - 2, 0, -2, s * o + 2, 4, 2, "px_mossy_stone_bricks", nil, f)
			lb(cf, "ArchLeg", s * o - 2, 4, -2, s * o + 2, 12, 2, "px_hedge", LEAF, f)
			decor(lb(cf, "ArchStep", s * (o - 2), 8, -2, s * (o - 6), 12, 2, "px_hedge", LEAF, f))
			decor(
				lb(cf, "Wisteria", s * 3, 8.4, -1.2, s * 5, 12, 1.2, "px_wisteria_leaves", nil, f)
			)
			take(cx + s * o - 2, cz - 2, cx + s * o + 2, cz + 2)
		end
		lb(cf, "ArchTop", -o - 2, 12, -2, o + 2, 16, 2, "px_hedge", LEAF, f)
		decor(lb(cf, "ArchCrown", -o + 6, 16, -2, o - 6, 20, 2, "px_hedge", LEAF, f))
		for i = 1, 10 do
			local zf = if i % 2 == 0 then 2.05 else -2.05
			local x, y
			local r = rng:NextNumber()
			if r < 0.35 then
				x = (if i % 4 < 2 then -o else o) + rng:NextNumber(-1.4, 1.4)
				y = rng:NextNumber(5, 11)
			elseif r < 0.8 then
				x = rng:NextNumber(-o - 1, o + 1)
				y = rng:NextNumber(13, 15)
			else
				x = rng:NextNumber(-o + 7, o - 7)
				y = rng:NextNumber(17, 19)
			end
			local sz = rng:NextNumber(1.1, 1.6)
			lw(cf, "ArchFlower", sz, sz, sz, x, y, zf, pick(C.archFlowers), f)
		end
		if lit then
			lamp(
				(cf * CFrame.new(0, 9.5, 0)).Position,
				f,
				(cf * CFrame.new(0, 12, 0)).Position.Y,
				true
			)
		end
	end
	-- the arbour over the EAST path (x 36..56): legs x 34 / 58, the outer ones lit
	arch(46, 60, 24, true)
	arch(46, 72, 24, false)
	arch(46, 84, 24, true)
	-- two over the garden spine W2 (x 142..158)
	arch(150, 20, 24, false)
	arch(150, 140, 24, false)
end
task.wait()

-- ================================================================ giant umbrella mushrooms round the pit
do
	local mf = folder("Mushrooms", southF)
	-- { x, z, height blocks, stem blocks, cap blocks }
	for _, m in ipairs({
		{ -92, 36, 8, 2, 8 }, -- M1 north-west of the pit, beside the hill bank
		{ -132, 84, 7, 2, 8 }, -- M3 west of the fence
		{ -128, 164, 5, 1, 5 }, -- M4 south-west, over the flower bed
		{ 48, 190, 7, 2, 8 }, -- M5 south-east of the pit, behind the buyer
		{ 72, 52, 6, 1, 7 }, -- M6 by the EAST path arbour
		{ -132, 0, 5, 1, 5 }, -- M8 by the south-west flower beds
	}) do
		if spot(m[1], m[2], m[4] * 2 + 1, "giant mushroom") then
			mushroom(m[1], m[2], m[3], m[4], m[5], mf)
		end
	end
	-- small clusters: { centre x, z, { dx, dz, h, w } ... }
	for _, c in ipairs({
		{ -68, 44, { { 0, 0, 2, 3 }, { 8, 6, 1, 2 }, { -8, -6, 1, 2 } } },
		{ -128, 100, { { 0, 0, 2, 3 }, { 6, -8, 1, 2 }, { -7, 5, 1, 2 } } },
		{ -108, 20, { { 0, 0, 2, 3 }, { 8, -6, 1, 2 }, { -8, 6, 1, 2 } } },
	}) do
		for _, m in ipairs(c[3]) do
			local x, z = c[1] + m[1], c[2] + m[2]
			if spot(x, z, 1) then
				mushroom(x, z, m[3], 0, m[4], mf)
			end
		end
	end
end
task.wait()

-- ================================================================ the south-east garden: gazebos, the pond and its bridge, bamboo
do
	local gf = folder("Gazebos", southF)
	-- a gazebo: a mossy stone floor, stone plinths with dark oak posts, a stepped green roof, a hanging lantern, a
	-- bench inside, vines on two posts
	local function gazebo(cx, cz)
		if not rectFree(cx - 10, cz - 10, cx + 10, cz + 10, "gazebo") then
			return
		end
		local f = folder("Gazebo", gf)
		box(
			"GazeboFloor",
			cx - 9,
			-0.4,
			cz - 9,
			cx + 9,
			0.4,
			cz + 9,
			"px_mossy_stone_bricks",
			nil,
			f
		)
		for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local px, pz = cx + c[1] * 6, cz + c[2] * 6
			cube("GazeboPlinth", px, 2.4, pz, B, 4, B, "px_mossy_stone_bricks", nil, f)
			cube("GazeboPost", px, 8.2, pz, 2.4, 7.6, 2.4, "px_dark_oak_log", nil, f)
			if i % 2 == 1 then
				local vx = px + c[1] * 1.45
				decor(
					box(
						"GazeboVines",
						vx - 0.25,
						4.4,
						pz - 1,
						vx + 0.25,
						11.6,
						pz + 1,
						"px_hedge",
						LEAF,
						f
					)
				)
				local d = decor(
					part(
						"VineFlower",
						Vector3.new(1.1, 1.1, 1.1),
						at(vx, rng:NextNumber(6, 10), pz),
						nil,
						nil,
						f
					)
				)
				textured(d, "px_white_wool", PINK_WOOL)
			end
		end
		-- the beams under the roof between the posts
		decor(
			box(
				"GazeboBeam",
				cx - 7.2,
				11,
				cz - 6.6,
				cx + 7.2,
				12,
				cz - 5.4,
				"px_dark_oak_planks",
				nil,
				f
			)
		)
		decor(
			box(
				"GazeboBeam",
				cx - 7.2,
				11,
				cz + 5.4,
				cx + 7.2,
				12,
				cz + 6.6,
				"px_dark_oak_planks",
				nil,
				f
			)
		)
		decor(
			box(
				"GazeboBeam",
				cx - 6.6,
				11,
				cz - 5.4,
				cx - 5.4,
				12,
				cz + 5.4,
				"px_dark_oak_planks",
				nil,
				f
			)
		)
		decor(
			box(
				"GazeboBeam",
				cx + 5.4,
				11,
				cz - 5.4,
				cx + 6.6,
				12,
				cz + 5.4,
				"px_dark_oak_planks",
				nil,
				f
			)
		)
		-- the stepped roof
		box(
			"GazeboRoof",
			cx - 13,
			12,
			cz - 13,
			cx + 13,
			14,
			cz + 13,
			"px_spruce_planks",
			ROOF_GREEN,
			f
		)
		box("GazeboRoof", cx - 9, 14, cz - 9, cx + 9, 18, cz + 9, "px_spruce_planks", ROOF_GREEN, f)
		box("GazeboRoof", cx - 5, 18, cz - 5, cx + 5, 22, cz + 5, "px_spruce_planks", ROOF_GREEN, f)
		box("GazeboCap", cx - 2, 22, cz - 2, cx + 2, 24, cz + 2, "px_dark_oak_planks", nil, f)
		lamp(V(cx, 9, cz), f, BY + 12, true)
		bench(cx, cz + 3.5, 0, f)
		take(cx - 10, cz - 10, cx + 10, cz + 10)
	end
	gazebo(126, -32) -- G1 by the pond
	gazebo(120, 136) -- G2 among the flower beds
end
task.wait()

do
	local f = folder("Pond", southF)
	local X0, Z0, X1, Z1 = 104, -16, 132, 12 -- the water
	if rectFree(X0 - 4, Z0 - 4, X1 + 4, Z1 + 4, "pond") then
		-- the curb (1 block wide, 1 stud high), split where the bridge steps sit on it
		local CURB = "px_mossy_stone_bricks"
		box("PondCurb", X0 - 4, 0, Z0 - 4, X1 + 4, 1, Z0, CURB, nil, f)
		box("PondCurb", X0 - 4, 0, Z1, X1 + 4, 1, Z1 + 4, CURB, nil, f)
		box("PondCurb", X0 - 4, 0, Z0, X0, 1, -6, CURB, nil, f)
		box("PondCurb", X0 - 4, 0, 6, X0, 1, Z1, CURB, nil, f)
		box("PondCurb", X1, 0, Z0, X1 + 4, 1, -6, CURB, nil, f)
		box("PondCurb", X1, 0, 6, X1 + 4, 1, Z1, CURB, nil, f)
		decor(box("PondBed", X0, 0, Z0, X1, 0.08, Z1, "px_dirt", MUD, f))
		local w = decor(box("PondWater", X0, 0.08, Z0, X1, 0.8, Z1, "px_water", WATER, f))
		w.Transparency = 0.3
		w.CastShadow = false
		-- lily pads (some in flower) off the bridge
		for i = 1, 8 do
			local x = rng:NextNumber(X0 + 2, X1 - 2)
			local z = if i % 2 == 0
				then rng:NextNumber(Z0 + 2, -8.5)
				else rng:NextNumber(8.5, Z1 - 2)
			local p =
				decor(part("LilyPad", Vector3.new(2.6, 0.15, 2.6), at(x, 0.88, z), nil, nil, f))
			textured(p, "px_hedge", C.lily)
			p.CastShadow = false
			if i % 3 == 0 then
				decor(
					part("LilyFlower", Vector3.new(0.9, 0.9, 0.9), at(x, 1.4, z), PINK_WOOL, nil, f)
				)
			end
		end
		-- reeds with cattails in the corners
		for _, r in ipairs({
			{ X0 + 1.5, Z0 + 1.5 },
			{ X0 + 3, Z0 + 1.2 },
			{ X1 - 1.5, Z1 - 1.5 },
			{ X1 - 1.2, Z1 - 3.4 },
			{ X0 + 1.4, Z1 - 1.6 },
			{ X1 - 1.5, Z0 + 1.6 },
		}) do
			local h = rng:NextNumber(3, 5)
			textured(
				decor(part("Reed", Vector3.new(0.6, h, 0.6), at(r[1], h / 2, r[2]), nil, nil, f)),
				"px_hedge",
				C.reed
			)
			decor(
				part(
					"Cattail",
					Vector3.new(0.8, 1.2, 0.8),
					at(r[1], h + 0.4, r[2]),
					C.handle,
					nil,
					f
				)
			)
		end
		-- two little spouts
		for _, s in ipairs({ { 110, 8 }, { 126, -12 } }) do
			decor(
				box(
					"SpoutStone",
					s[1] - 1,
					0,
					s[2] - 1,
					s[1] + 1,
					1.2,
					s[2] + 1,
					"px_mossy_stone_bricks",
					nil,
					f
				)
			)
			local col =
				decor(part("Spout", Vector3.new(0.8, 3.2, 0.8), at(s[1], 2.8, s[2]), nil, nil, f))
			textured(col, "px_water", WATER)
			col.Transparency = 0.3
			local splash = decor(
				part(
					"Splash",
					Vector3.new(2.8, 0.3, 2.8),
					at(s[1], 0.95, s[2]),
					Color3.fromRGB(220, 240, 255),
					nil,
					f
				)
			)
			splash.Transparency = 0.4
		end
		-- the pink cherry-plank bridge: 1-stud steps up to a deck over the water, rails on the deck
		local BR = "px_cherry_planks"
		for _, s in ipairs({ { 96, 100, 1 }, { 100, 104, 2 }, { 132, 136, 2 }, { 136, 142, 1 } }) do
			box("BridgeStep", s[1], 0, -6, s[2], s[3], 6, BR, nil, f)
		end
		box("BridgeDeck", X0, 2.2, -6, X1, 3, 6, BR, nil, f)
		for _, x in ipairs({ 108, 128 }) do
			box("BridgePier", x - 1, 0, -6, x + 1, 2.2, 6, BR, nil, f)
		end
		for _, z in ipairs({ -5.5, 5.5 }) do
			for x = X0, X1, 7 do
				cube("BridgePost", x, 4.5, z, 1, 3, 1, "px_cherry_log", nil, f)
			end
			box("BridgeRail", X0, 5, z - 0.3, X1, 5.6, z + 0.3, BR, nil, f)
		end
		-- lanterns on cherry posts at both ends
		for _, p in ipairs({ { 96, -8.5 }, { 141, 8.5 } }) do
			cube("BridgeLampPost", p[1], 3, p[2], 2, 6, 2, "px_cherry_log", nil, f)
			lamp(V(p[1], 6.75, p[2]), f, nil, true)
		end
		take(X0 - 4, Z0 - 4, X1 + 4, Z1 + 4)
		take(94, -10, 142, 10)
	end
end

do
	local f = folder("Bamboo", southF)
	for gx = 100, 112, 4 do
		for gz = -46, -30, 4 do
			if rng:NextNumber() < 0.75 then
				local x, z = gx + 2 + rng:NextNumber(-0.6, 0.6), gz + 2 + rng:NextNumber(-0.6, 0.6)
				if spot(x, z, 1) then
					local n = rng:NextInteger(4, 8)
					local h = n * B
					decor(cube("Bamboo", x, h / 2, z, 2, h, 2, "px_hedge", C.bamboo, f))
					decor(
						cube(
							"BambooNode",
							x,
							rng:NextInteger(1, n - 1) * B,
							z,
							2.3,
							0.4,
							2.3,
							nil,
							C.bambooNode,
							f
						)
					)
					decor(
						cube(
							"BambooLeaves",
							x + rng:NextNumber(-1.5, 1.5),
							h - 1,
							z + rng:NextNumber(-1.5, 1.5),
							3.2,
							1.6,
							3.2,
							"px_hedge",
							LEAF,
							f
						)
					)
				end
			end
		end
	end
	take(100, -46, 116, -26)
end
task.wait()

-- ================================================================ the south-east garden: beds, trees, bees, trellises, the ruin
do
	local f = folder("Garden", southF)
	local fl = C.flowers
	-- flower beds of single-colour rows
	bed(108, 20, 132, 44, "x", { C.red, C.yellow, C.white, C.purple, C.blue, PINK_WOOL }, f) -- Bed1 north of the pond
	bed(66, 66, 90, 84, "z", { C.yellow, C.red, C.white, C.purple, C.blue, C.yellow }, f) -- Bed2 under M6
	bed(170, -8, 198, 16, "x", { C.purple, C.white, C.blue, C.red, C.yellow, C.purple }, f) -- Bed3 east of W2
	bed(108, 108, 132, 124, "x", { C.red, C.white, C.red, C.yellow }, f) -- Bed4 north of G2
	bed(108, 150, 132, 166, "x", { C.blue, C.purple, C.white, PINK_WOOL }, f) -- Bed5 south of G2
	-- apple trees, cherry trees
	for _, t in ipairs({
		{ 66, 24, 12 },
		{ 100, 56, 13 },
		{ 128, 72, 12 },
		{ 168, 120, 13 },
		{ 164, 156, 12 },
	}) do
		if spot(t[1], t[2], 2, "apple tree") then
			appleTree(t[1], t[2], t[3], f)
		end
	end
	for _, t in ipairs({ { 96, 28, 14 }, { 176, -28, 14 }, { 190, 40, 13 }, { 88, 194, 13 } }) do
		if spot(t[1], t[2], 2, "cherry tree") then
			cherryTree(t[1], t[2], t[3], f)
		end
	end
	task.wait()
	-- the apiary: three honey hives on posts facing W1, bees round them
	do
		local function bee(pos, yaw, parent)
			local cf = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
			local p = decor(part("Bee", Vector3.new(0.9, 0.9, 1.3), cf, C.bee, nil, parent))
			p.CastShadow = false
			decor(
				part(
					"BeeStripe",
					Vector3.new(0.95, 0.95, 0.35),
					cf * CFrame.new(0, 0, 0.1),
					C.black,
					nil,
					parent
				)
			).CastShadow =
				false
			local w = decor(
				part(
					"BeeWings",
					Vector3.new(1.6, 0.1, 0.6),
					cf * CFrame.new(0, 0.5, -0.05),
					C.wing,
					nil,
					parent
				)
			)
			w.Transparency = 0.35
			w.CastShadow = false
		end
		for _, x in ipairs({ 104, 112, 120 }) do
			local z = 80
			if spot(x, z, 2, "beehive") then
				local hf = folder("Beehive", f)
				cube("HiveStand", x, 1.5, z, 1.6, 3, 1.6, "px_dark_oak_log", nil, hf)
				cube("Hive", x, 5, z, B, B, B, "px_hay", C.honey, hf)
				for _, y in ipairs({ 4.3, 5.7 }) do
					decor(cube("HiveStripe", x, y, z, B + 0.1, 0.45, B + 0.1, nil, C.stripe, hf))
				end
				decor(
					cube("HiveLid", x, 7.3, z, B + 0.6, 0.6, B + 0.6, "px_spruce_planks", nil, hf)
				)
				decor(cube("HiveDoor", x, 3.9, z + 2.05, 1.6, 0.6, 0.2, nil, C.black, hf))
				for _ = 1, 4 do
					local a = rng:NextNumber(0, math.pi * 2)
					local r = rng:NextNumber(2.8, 5.2)
					bee(
						V(x + math.cos(a) * r, rng:NextNumber(3.5, 8.5), z + math.sin(a) * r),
						rng:NextNumber(0, math.pi * 2),
						hf
					)
				end
				take(x - 3, z - 3, x + 3, z + 3)
			end
		end
	end
	-- trellises with vines and wisteria along the east side of W2
	for _, z in ipairs({ 36, 54, 70 }) do
		local x = 164
		if spot(x, z, 2, "trellis") then
			local tf = folder("Trellis", f)
			for _, s in ipairs({ -1, 1 }) do
				cube("TrellisPost", x, 6, z + s * 6, 1.2, 12, 1.2, "px_dark_oak_log", nil, tf)
			end
			for _, y in ipairs({ 3, 7, 11 }) do
				decor(
					box(
						"TrellisLath",
						x - 0.3,
						y - 0.3,
						z - 6,
						x + 0.3,
						y + 0.3,
						z + 6,
						"px_dark_oak_planks",
						nil,
						tf
					)
				)
			end
			box("TrellisVines", x - 0.5, 0, z - 5.4, x + 0.5, 8, z + 5.4, "px_hedge", LEAF, tf)
			decor(
				box("TrellisVines", x - 0.5, 8, z - 5.4, x + 0.5, 11.2, z + 1, "px_hedge", LEAF, tf)
			)
			decor(
				box(
					"Wisteria",
					x - 0.7,
					6,
					z + 1.5,
					x + 0.7,
					11,
					z + 4.5,
					"px_wisteria_leaves",
					nil,
					tf
				)
			)
			decor(
				box(
					"Wisteria",
					x - 0.7,
					3.6,
					z - 4.5,
					x + 0.7,
					8.4,
					z - 2,
					"px_wisteria_leaves",
					nil,
					tf
				)
			)
			for i = 1, 5 do
				local side = if i % 2 == 0 then 0.6 else -0.6
				local d = decor(
					part(
						"VineFlower",
						Vector3.new(1.1, 1.1, 1.1),
						at(x + side, rng:NextNumber(1.5, 9.5), z + rng:NextNumber(-4.5, 4.5)),
						nil,
						nil,
						tf
					)
				)
				textured(d, "px_white_wool", pick(fl))
			end
			take(x - 2, z - 7, x + 2, z + 7)
		end
	end
	-- the mossy stone arch ruin: a tall and a broken pillar, the lintel broken off mid-span, fallen blocks, vines
	do
		local cx, cz = 184, 76
		if rectFree(cx - 10, cz - 4, cx + 10, cz + 4, "ruin") then
			local rf = folder("Ruin", f)
			local MB, MC = "px_mossy_stone_bricks", "px_mossy_cobblestone"
			box("RuinPillar", cx - 10, 0, cz - 2, cx - 6, 12, cz + 2, MB, nil, rf)
			box("RuinPillar", cx - 10, 12, cz - 2, cx - 6, 20, cz + 2, MC, nil, rf)
			box("RuinPillar", cx + 6, 0, cz - 2, cx + 10, 8, cz + 2, MB, nil, rf)
			box("RuinPillar", cx + 6, 8, cz - 2, cx + 10, 12, cz + 2, MC, nil, rf)
			box("RuinLintel", cx - 10, 20, cz - 2, cx + 2, 24, cz + 2, MB, nil, rf)
			box("RuinStep", cx - 6, 16, cz - 2, cx - 2, 20, cz + 2, MB, nil, rf)
			box("RuinRubble", cx + 2, 0, cz + 4, cx + 6, 4, cz + 8, MC, nil, rf)
			box("RuinRubble", cx + 12, 0, cz - 6, cx + 16, 2, cz - 2, MB, nil, rf)
			box("RuinRubble", cx - 2, 0, cz - 8, cx + 2, 4, cz - 4, MB, nil, rf)
			box("RuinRubble", cx - 2, 4, cz - 8, cx, 6, cz - 6, MC, nil, rf)
			decor(
				box("RuinVines", cx - 1.8, 14, cz + 2, cx + 1.8, 20, cz + 2.5, "px_hedge", LEAF, rf)
			)
			decor(
				box(
					"RuinVines",
					cx - 10.5,
					6,
					cz - 1.8,
					cx - 10,
					20,
					cz + 1.8,
					"px_hedge",
					LEAF,
					rf
				)
			)
			decor(
				box("RuinVines", cx + 10, 2, cz - 1, cx + 10.5, 11, cz + 1.6, "px_hedge", LEAF, rf)
			)
			for i = 1, 4 do
				local d = decor(
					part(
						"RuinFlower",
						Vector3.new(1.2, 1.2, 1.2),
						at(
							cx - 10.3 + (i % 2) * 20.6,
							rng:NextNumber(4, 12),
							cz + rng:NextNumber(-1.5, 1.5)
						),
						nil,
						nil,
						rf
					)
				)
				textured(d, "px_white_wool", pick(C.archFlowers))
			end
			take(cx - 16, cz - 9, cx + 17, cz + 9)
		end
	end
	task.wait()
	-- lamp posts along the walks (their lanterns count toward the light cap)
	for _, l in ipairs({ { 162, 84, math.pi }, { 104, 112, math.pi / 2 }, { 68, 192, 0 } }) do
		if spot(l[1], l[2], 2, "lamp post") then
			local lf = folder("LampPost", f)
			lampPost(l[1], l[2], lf, false, l[3])
			if st.lights < st.cap then
				st.lights += 1
			else
				local pl = lf:FindFirstChildWhichIsA("PointLight", true)
				if pl then
					pl:Destroy()
				end
			end
			take(l[1] - 2, l[2] - 2, l[1] + 2, l[2] + 2)
		end
	end
	-- benches by the walks
	for _, b in ipairs({ { 110, 190, 0 }, { 180, 108, 0 }, { 164, 6, math.pi / 2 } }) do
		if spot(b[1], b[2], 3, "bench") then
			bench(b[1], b[2], b[3], f)
		end
	end
	-- deer and rabbits
	for _, d in ipairs({ { 172, 24, math.pi * 0.6 }, { 184, 134, -0.8 } }) do
		if spot(d[1], d[2], 3, "deer") then
			deer(d[1], d[2], d[3], f)
		end
	end
	for _, r in ipairs({ { 88, 46, 0.4 }, { 194, 64, 2.2 }, { 136, 196, -1.2 }, { 100, 140, 1.6 } }) do
		if spot(r[1], r[2], 1) then
			rabbit(r[1], r[2], r[3], if rng:NextNumber() < 0.5 then C.hare else C.white, f)
		end
	end
end
task.wait()

-- ================================================================ the south-west strip: orchard, vegetables, the tool shed
do
	local f = folder("SouthWest", southF)
	-- the orchard row and a cherry by the fence corner
	for _, z in ipairs({ -20, 8, 36, 64 }) do
		if spot(-176, z, 2, "orchard tree") then
			appleTree(-176, z, 12, f)
		end
	end
	if spot(-126, 40, 2, "cherry tree") then
		cherryTree(-126, 40, 13, f)
	end
	bed(
		-136,
		-40,
		-112,
		-16,
		"x",
		{ C.yellow, C.white, C.red, C.purple, C.blue, PINK_WOOL },
		f,
		"px_spruce_planks"
	) -- Bed6
	bed(
		-152,
		142,
		-128,
		158,
		"x",
		{ PINK_WOOL, C.white, C.purple, C.yellow },
		f,
		"px_spruce_planks"
	) -- Bed7
	task.wait()
	-- the vegetable patch x -192..-160, z 84..116: a spruce fence with a gate toward W6, crop rows, a scarecrow
	do
		local X0, Z0, X1, Z1 = -192, 84, -160, 116
		if rectFree(X0, Z0, X1, Z1, "vegetable patch") then
			local vf = folder("VegetablePatch", f)
			local FV = "px_spruce_planks"
			fence(X0, Z0, X1, Z0, vf, 0, FV)
			fence(X0, Z0, X0, Z1, vf, 0, FV)
			fence(X1, Z0, X1, Z1, vf, 0, FV)
			fence(X0, Z1, -180, Z1, vf, 0, FV)
			fence(-172, Z1, X1, Z1, vf, 0, FV)
			local CYCLE = { "cabbage", "carrot", "wheat", "wheat", "beet", "carrot", "cabbage" }
			for k = 0, 6 do
				local xc = X0 + 4 + k * 4
				local z0, z1 = Z0 + 2, Z1 - 2
				decor(box("Soil", xc - 1.7, -0.3, z0, xc + 1.7, 0.12, z1, "px_dirt", C.soil, vf))
				local crop = CYCLE[k + 1]
				if crop == "wheat" then
					decor(
						box(
							"Wheat",
							xc - 1.4,
							0.12,
							z0 + 0.4,
							xc + 1.4,
							3.2,
							z1 - 0.4,
							"px_hay",
							C.wheat,
							vf
						)
					)
				elseif crop == "cabbage" then
					decor(
						box(
							"CabbageLeaves",
							xc - 1.3,
							0.12,
							z0 + 0.4,
							xc + 1.3,
							1.0,
							z1 - 0.4,
							"px_hedge",
							LEAF,
							vf
						)
					)
					for z = z0 + 3, z1 - 2, 6 do
						decor(cube("Cabbage", xc, 1.6, z, 2.2, 2, 2.2, "px_hedge", C.cabbage, vf))
					end
				else
					local tint = if crop == "carrot" then C.carrot else C.beet
					decor(
						box(
							"CropLeaves",
							xc - 1,
							0.12,
							z0 + 0.4,
							xc + 1,
							1.3,
							z1 - 0.4,
							"px_hedge",
							LEAF,
							vf
						)
					)
					for z = z0 + 4, z1 - 3, 8 do
						decor(
							cube(
								"CropRoot",
								xc + (if (z // 8) % 2 == 0 then -1.1 else 1.1),
								0.5,
								z,
								0.9,
								0.9,
								0.9,
								nil,
								tint,
								vf
							)
						)
					end
				end
			end
			-- the scarecrow in the wheat
			local sx, sz = X0 + 16, Z0 + 16
			decor(cube("ScarecrowPole", sx, 3.5, sz, 0.6, 7, 0.6, "px_dark_oak_planks", nil, vf))
			decor(cube("ScarecrowArms", sx, 5.2, sz, 0.5, 0.5, 5, "px_dark_oak_planks", nil, vf))
			decor(
				cube(
					"ScarecrowCoat",
					sx,
					4.6,
					sz,
					1.2,
					2.2,
					2,
					"px_white_wool",
					Color3.fromRGB(110, 140, 200),
					vf
				)
			)
			decor(cube("ScarecrowHead", sx, 6.6, sz, 1.6, 1.6, 1.6, "px_hay", nil, vf))
			decor(cube("ScarecrowHat", sx, 7.6, sz, 2.4, 0.5, 2.4, "px_hay", C.stripe, vf))
			barrel(-188, 0, 121, vf)
			take(X0 - 1, Z0 - 1, X1 + 1, Z1 + 1)
			take(-191, 118, -185, 124)
		end
	end
	-- the tool shed: corner logs, plank walls, a door toward W6, a stepped dark oak roof, tools, a lantern
	do
		local cx, cz = -170, 150
		if rectFree(cx - 8, cz - 8, cx + 8, cz + 8, "tool shed") then
			local sf = folder("ToolShed", f)
			local W = "px_spruce_planks"
			box("ShedFloor", cx - 6, -0.5, cz - 6, cx + 6, 0.1, cz + 6, "px_planks", nil, sf)
			for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
				cube("ShedLog", cx + c[1] * 5, 6, cz + c[2] * 5, 2, 12, 2, "px_oak_log", nil, sf)
			end
			box("ShedWall", cx - 4, 0, cz + 5, cx + 4, 12, cz + 6, W, nil, sf)
			box("ShedWall", cx - 6, 0, cz - 4, cx - 5, 12, cz + 4, W, nil, sf)
			box("ShedWall", cx + 5, 0, cz - 4, cx + 6, 12, cz + 4, W, nil, sf)
			box("ShedWall", cx - 4, 0, cz - 6, cx - 2, 12, cz - 5, W, nil, sf)
			box("ShedWall", cx + 2, 0, cz - 6, cx + 4, 12, cz - 5, W, nil, sf)
			box("ShedLintel", cx - 2, 8, cz - 6, cx + 2, 12, cz - 5, W, nil, sf)
			decor(
				box("ShedWindow", cx - 6.1, 5, cz - 1.5, cx - 5.9, 8, cz + 1.5, nil, C.window, sf)
			)
			box("ShedRoof", cx - 8, 12, cz - 8, cx + 8, 14, cz + 8, "px_dark_oak_planks", nil, sf)
			box("ShedRoof", cx - 5, 14, cz - 8, cx + 5, 16, cz + 8, "px_dark_oak_planks", nil, sf)
			box("ShedRoof", cx - 2, 16, cz - 8, cx + 2, 18, cz + 8, "px_dark_oak_planks", nil, sf)
			cube("Workbench", cx + 2.5, 2, cz + 2.5, B, B, B, "px_planks", nil, sf)
			-- a hoe and a shovel leaning on the east wall
			for i, t in ipairs({ { 1.2, 0.3, 0.8 }, { 1.1, 1.3, 0.3 } }) do
				local tz = cz - 2 + i * 2.5
				local cf = at(cx + 6.8, 3, tz) * CFrame.Angles(0, 0, math.rad(-12))
				textured(
					decor(part("ToolHandle", Vector3.new(0.4, 6, 0.4), cf, nil, nil, sf)),
					"px_planks",
					C.handle
				)
				decor(
					part(
						"ToolHead",
						Vector3.new(t[1], t[2], t[3]),
						cf * CFrame.new(0, 3.1, 0),
						C.iron,
						Enum.Material.Metal,
						sf
					)
				)
			end
			barrel(cx + 9.5, 0, cz - 3, sf)
			crate(cx + 9.5, 0, cz + 2, sf)
			lamp(V(cx, 10, cz - 7.3), sf, BY + 12, true)
			take(cx - 8, cz - 8, cx + 12, cz + 8)
		end
	end
	if spot(-134, 114, 3, "bench") then
		bench(-134, 114, math.pi, f)
	end
	for _, r in ipairs({ { -166, 20, 1.1 }, { -166, 76, -0.6 }, { -196, 44, 2.5 } }) do
		if spot(r[1], r[2], 1) then
			rabbit(r[1], r[2], r[3], if rng:NextNumber() < 0.5 then C.hare else C.white, f)
		end
	end
end
task.wait()

-- ================================================================ vines and flowers hanging over the west, south and east rim
do
	local f = folder("RimVines", southF)
	local CELL = 8
	local function strip(x, z, alongX)
		local L = rng:NextInteger(1, 4) * B
		local size = if alongX then Vector3.new(B, L, 0.5) else Vector3.new(0.5, L, B)
		local p = decor(part("RimVine", size, at(x, -L / 2, z), nil, nil, f))
		if rng:NextNumber() < 0.2 then
			textured(p, "px_wisteria_leaves")
		else
			textured(p, "px_hedge", LEAF)
		end
		p.CastShadow = false
		if rng:NextNumber() < 0.45 then
			local y = -rng:NextNumber(1, L - 1)
			local d = decor(part("RimFlower", Vector3.new(1.2, 1.2, 1.2), at(x, y, z), nil, nil, f))
			textured(d, "px_white_wool", pick(C.flowers))
			d.CastShadow = false
		end
	end
	-- the island cells are 8 studs on a grid from -232: the first land cell of a row or column has its face open
	for z = -48, 224 - CELL, CELL do
		local cz = z + CELL / 2
		for x = -232, -96, CELL do
			if onIsland(x + CELL / 2, cz) then
				if rng:NextNumber() < 0.65 then
					strip(x - 0.3, cz + rng:NextNumber(-1.5, 1.5), false)
				end
				break
			end
		end
		for x = 224, 96, -CELL do
			if onIsland(x + CELL / 2, cz) then
				if rng:NextNumber() < 0.65 then
					strip(x + CELL + 0.3, cz + rng:NextNumber(-1.5, 1.5), false)
				end
				break
			end
		end
	end
	for x = -232, 224, CELL do
		local cx = x + CELL / 2
		for z = 224, 120, -CELL do
			if onIsland(cx, z + CELL / 2) then
				if rng:NextNumber() < 0.65 then
					strip(cx + rng:NextNumber(-1.5, 1.5), z + CELL + 0.3, true)
				end
				break
			end
		end
	end
end
task.wait()

-- ================================================================ bushes along the rim and flowers in the grass
do
	local f = folder("Bushes", southF)
	local n, tries = 0, 0
	while n < 46 and tries < 4000 do
		tries += 1
		local x, z = snap(rng:NextNumber(-216, 216)), snap(rng:NextNumber(-44, 216))
		if
			onIsland(x, z, 12)
			and not onIsland(x, z, 26)
			and zoneOf(x, z) == "south"
			and inZone(x, z, 4)
			and freeGround(x, z, 2)
			and not isTaken(x, z, 4)
		then
			local h = rng:NextInteger(1, 2)
			cube("Bush", x, h * B / 2, z, B, h * B, B, "px_hedge", LEAF, f)
			if rng:NextNumber() < 0.5 then
				local dx, dz = 0, 0
				if rng:NextNumber() < 0.5 then
					dx = if rng:NextNumber() < 0.5 then -B else B
				else
					dz = if rng:NextNumber() < 0.5 then -B else B
				end
				if onIsland(x + dx, z + dz, 12) then
					cube("Bush", x + dx, B / 2, z + dz, B, B, B, "px_hedge", LEAF, f)
				end
			end
			if rng:NextNumber() < 0.5 then
				local d = decor(
					part(
						"BushFlower",
						Vector3.new(1.4, 1.4, 1.4),
						at(x + rng:NextNumber(-1, 1), h * B + 0.5, z + rng:NextNumber(-1, 1)),
						nil,
						nil,
						f
					)
				)
				textured(d, "px_white_wool", pick(C.flowers))
				d.CastShadow = false
			end
			take(x - 6, z - 6, x + 6, z + 6)
			n += 1
		end
	end
end
do
	local f = folder("Flowers", southF)
	local n, tries = 0, 0
	while n < 380 and tries < 6000 do
		tries += 1
		local x, z = rng:NextNumber(-216, 216), rng:NextNumber(-48, 216)
		if zoneOf(x, z) == "south" and freeGround(x, z, 0) and not isTaken(x, z, 1) then
			local col = pick(C.flowers)
			for _ = 1, rng:NextInteger(1, 3) do
				local s = rng:NextNumber(0.9, 1.3)
				local p = decor(
					part(
						"Flower",
						Vector3.new(s, s, s),
						at(x + rng:NextNumber(-1.5, 1.5), s / 2, z + rng:NextNumber(-1.5, 1.5)),
						nil,
						nil,
						f
					)
				)
				textured(p, "px_white_wool", col)
				p.CastShadow = false
			end
			n += 1
		end
	end
end
print(("[build-eden] south: %d parts, %d lights"):format(count - startCount, st.lights))
