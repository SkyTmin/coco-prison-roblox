--!nocheck
-- ================================================================ barn: the outskirts (zoneOf == "outskirts")
-- The pit surroundings, the south, the west and the east of the old farm years later — overgrown and ruined:
--   pit fence   a crooked dark fence 2 studs outside the pit rim (x ±74, z 22 / 170), leaning posts, missing rails;
--               open at the four ladder shafts: x -12..12 on the north, x -20..20 on the south (the arrival side),
--               z 84..108 on the west and east; six chain lamp posts (the four corners and both ends of the south
--               opening), hay bales with candles and jack o'lanterns at the corners
--   south stair a plank landing on the island (x -10..10, z 196..edge) and steps going down over the rim into the
--               void (decor — how the farm folk came up), a hand rail, a hanging lantern, an old sign «Ферма»
--   west        the broken wind pump at (-150, -60) (a lattice tower 14 blocks high, a broken fan, a bent tail vane),
--               a collapsed shed at (-116, -56), the rusty tractor at (-128, 50), the wild pumpkin patch round
--               (-145, 104) with the burning scarecrow, an abandoned cart at (-112, 140), junk heaps, path lamps
--   east        the farmhouse ruin x 112..144, z -72..-40 (two walls, a chimney, a caved roof), the broken silo at
--               (150, 60), the well with a broken roof at (124, 30), the pigsty remains x 128..152, z 102..122,
--               candles on hay with a raven at (118, 150), pumpkins, crooked fences, a junk heap, path lamps
--   everywhere  autumn trees, bushes, tall weeds, ravens on posts; roots and grass hanging off the cliff, a broken
--               fence along parts of the island edge
local out = folder("Outskirts")
local startCount = count
local C = {
	carve = Color3.fromRGB(46, 26, 12),
	faceGlow = Color3.fromRGB(255, 190, 80),
	pumpkinLight = Color3.fromRGB(255, 160, 70),
	stem = Color3.fromRGB(96, 110, 44),
	chain = Color3.fromRGB(55, 55, 60),
	raven = Color3.fromRGB(26, 24, 30),
	ravenWing = Color3.fromRGB(38, 36, 46),
	beak = Color3.fromRGB(56, 52, 46),
	candle = Color3.fromRGB(240, 228, 200),
	stone = Color3.fromRGB(150, 146, 140),
	oldWood = Color3.fromRGB(190, 170, 150),
	tyre = Color3.fromRGB(70, 70, 74),
	iron = Color3.fromRGB(150, 146, 140),
	ironDark = Color3.fromRGB(100, 96, 92),
	rustLight = Color3.fromRGB(235, 200, 180), -- on px_terracotta: an orange rust; RUST gives the dark patches
	coarse = Color3.fromRGB(150, 118, 90),
	mud = Color3.fromRGB(96, 74, 56),
	vine = Color3.fromRGB(150, 190, 120),
	coat = Color3.fromRGB(150, 120, 96),
	hat = Color3.fromRGB(110, 90, 70),
	hole = Color3.fromRGB(28, 24, 22),
	water = Color3.fromRGB(30, 40, 46),
	-- autumn leaves: px_cherry_leaves (avg 224, 140, 172) tinted so the crown reads AUTUMN / AUTUMN_DEEP / amber
	leaves = { Color3.fromRGB(243, 200, 59), Color3.fromRGB(194, 127, 44), Color3.fromRGB(255, 255, 70) },
	weeds = { WEEDS, Color3.fromRGB(190, 170, 90), Color3.fromRGB(130, 150, 70), Color3.fromRGB(176, 140, 70) },
}

-- a textured box in a frame cf (a world CFrame) by two local corners
local function lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(name, size, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a plain decor bit in a frame cf by size and local centre
local function lc(cf, name, sx, sy, sz, x, y, z, color, parent)
	return decor(part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, nil, parent))
end
-- a frame at local (x, z) turned by yaw; its front is -Z (yaw 0 faces north, pi south, pi/2 west, -pi/2 east)
local function fr(x, z, yaw, y)
	return at(x, y or 0, z) * CFrame.Angles(0, yaw or 0, 0)
end

-- the spots big props took (trees, bushes and the rim fence keep off them)
local taken = {}
local function claim(x, z, r)
	table.insert(taken, { x, z, r })
end
local function isTaken(x, z, pad)
	for _, t in ipairs(taken) do
		if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < (t[3] + pad) ^ 2 then
			return true
		end
	end
	return false
end
-- the point and the corners of its pad square are all in this part's zone
local function inZone(x, z, pad)
	pad = pad or 0
	return zoneOf(x, z) == "outskirts"
		and zoneOf(x - pad, z - pad) == "outskirts"
		and zoneOf(x + pad, z - pad) == "outskirts"
		and zoneOf(x - pad, z + pad) == "outskirts"
		and zoneOf(x + pad, z + pad) == "outskirts"
end
local function ok(x, z, pad)
	pad = pad or 0
	return freeGround(x, z, pad) and inZone(x, z, pad) and not isTaken(x, z, pad)
end
-- the nearest free spot to (x, z) (rings of 4 studs out to 40), or nil with a warning for the evening check
local function near(x, z, pad, what)
	for rad = 0, 40, 4 do
		local n = if rad == 0 then 1 else 12
		for k = 0, n - 1 do
			local a = k / n * math.pi * 2
			local px, pz = math.floor(x + math.cos(a) * rad + 0.5), math.floor(z + math.sin(a) * rad + 0.5)
			if ok(px, pz, pad) then
				return px, pz
			end
		end
	end
	warn(("[build-barn] outskirts: no free ground for %s near (%d, %d)"):format(what, x, z))
	return nil
end
local function spot(x, z, pad, what)
	if not ok(x, z, pad) then
		warn(("[build-barn] outskirts: %s at (%d, %d) is not on free ground"):format(what, x, z))
	end
end
-- point lights of this part (≤ 25): the lanterns count themselves, glow() refuses past the budget
local lights = 0
local function glow(p, range, brightness, color)
	if lights >= 25 then
		return nil
	end
	lights += 1
	return light(p, range, brightness, color)
end

-- a pumpkin block (s studs) standing on y; mode nil, "carved" (a dark face on its -Z side) or "lit" (a glowing face
-- and a warm light)
local function pumpkin(x, y, z, parent, mode, yaw, s)
	s = s or B
	local cf = fr(x, z, yaw, y)
	local p = lb(cf, if mode then "JackOLantern" else "Pumpkin", -s / 2, 0, -s / 2, s / 2, s * 0.9, s / 2, "px_hay", PUMPKIN, parent)
	if s < B then
		decor(p)
	end
	lc(cf, "PumpkinStem", 0.7, 0.8, 0.7, 0, s * 0.9 + 0.4, 0, C.stem, parent)
	if mode then
		local u, hz = s / 4, -s / 2 - 0.04
		local col = if mode == "lit" then C.faceGlow else C.carve
		local bits = {
			lc(cf, "CarvedEye", u * 0.8, u * 0.7, 0.2, -u * 0.9, s * 0.62, hz, col, parent),
			lc(cf, "CarvedEye", u * 0.8, u * 0.7, 0.2, u * 0.9, s * 0.62, hz, col, parent),
			lc(cf, "CarvedMouth", u * 2.6, u * 0.55, 0.2, 0, s * 0.3, hz, col, parent),
		}
		if mode == "lit" then
			for _, b in ipairs(bits) do
				b.Material = Enum.Material.Neon
			end
			glow(p, 18, 1.4, C.pumpkinLight)
		end
	end
	return p
end
-- a chain of alternating links from a to b (world points)
local function chain(a, b, parent)
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 1.1))
	local up = if math.abs(d.Unit.Y) > 0.9 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0)
	local base = CFrame.lookAt(a, b, up)
	for k = 0, n - 1 do
		local s = if k % 2 == 0 then Vector3.new(0.6, 0.2, 1.3) else Vector3.new(0.2, 0.6, 1.3)
		decor(part("ChainLink", s, base * CFrame.new(0, 0, -(k + 0.5) * len / n), C.chain, Enum.Material.Metal, parent))
	end
end
-- a black raven of blocks perched on y, looking along -Z of yaw
local function raven(x, y, z, yaw, parent)
	local f = folder("Raven", parent)
	local cf = fr(x, z, yaw, y)
	lc(cf, "RavenBody", 1.6, 1.6, 2.4, 0, 1.3, 0.2, C.raven, f)
	lc(cf, "RavenHead", 1.2, 1.2, 1.2, 0, 2.4, -1.1, C.raven, f)
	lc(cf, "RavenBeak", 0.45, 0.4, 1, 0, 2.3, -2.1, C.beak, f)
	lc(cf, "RavenTail", 1, 0.4, 1.6, 0, 0.9, 2, C.raven, f)
	for _, s in ipairs({ -1, 1 }) do
		lc(cf, "RavenWing", 0.3, 1.2, 2, s * 0.95, 1.4, 0.3, C.ravenWing, f)
		lc(cf, "RavenLeg", 0.25, 0.5, 0.25, s * 0.4, 0.25, 0.2, C.beak, f)
	end
	return f
end
-- two or three candles standing on y (one of them may light the spot)
local function candles(x, y, z, parent, lit)
	local offs = { { -0.9, -0.7 }, { 0.8, -0.2 }, { -0.1, 0.9 } }
	local first
	for i = 1, rng:NextInteger(2, 3) do
		local o = offs[i]
		local h = rng:NextNumber(0.9, 1.8)
		decor(cube("Candle", x + o[1], y + h / 2, z + o[2], 0.6, h, 0.6, "px_white_wool", C.candle, parent))
		local fl = decor(part("CandleFlame", Vector3.new(0.3, 0.5, 0.3), at(x + o[1], y + h + 0.3, z + o[2]), CANDLE, Enum.Material.Neon, parent))
		fl.CastShadow = false
		first = first or fl
	end
	if lit then
		glow(first, 14, 1.2, CANDLE)
	end
end
local function hayBale(x, y, z, parent, yaw)
	return lb(fr(x, z, yaw, y), "HayBale", -2, 0, -2, 2, 4, 2, "px_hay", nil, parent)
end
-- a stepped round wheel in the YZ plane of cf (thickness along X): two crossed boxes and a hub
local function wheel(cf, r, t, parent, solid, variant, tint)
	variant, tint = variant or "px_coal_block", tint or C.tyre
	local a = lb(cf, "Wheel", -t / 2, -r, -r * 0.55, t / 2, r, r * 0.55, variant, tint, parent)
	local b = lb(cf, "Wheel", -t / 2, -r * 0.55, -r, t / 2, r * 0.55, r, variant, tint, parent)
	decor(lb(cf, "WheelHub", -t / 2 - 0.15, -r * 0.35, -r * 0.35, t / 2 + 0.15, r * 0.35, r * 0.35, "px_iron_block", C.ironDark, parent))
	if not solid then
		decor(a)
		decor(b)
	end
end
-- a crooked dark fence from (ax, az) to (bx, bz): posts every ~opt.step studs (some leaning, some missing or fallen),
-- two rails between posts (some missing, some broken and hanging to the ground). opt: step, miss, lean, railMiss,
-- skipFirst (the first post belongs to the previous piece), check(x, z) (no post where it fails), variant
local function crookedFence(ax, az, bx, bz, parent, opt)
	opt = opt or {}
	local variant = opt.variant or WOOD_DARK
	local dx, dz = bx - ax, bz - az
	local len = math.sqrt(dx * dx + dz * dz)
	local n = math.max(1, math.floor(len / (opt.step or 6) + 0.5))
	local yaw = math.atan2(dx, dz)
	local posts = {}
	for i = 0, n do
		local px, pz = ax + dx * i / n, az + dz * i / n
		if opt.check and not opt.check(px, pz) then
			posts[i] = false
		elseif i == 0 and opt.skipFirst then
			posts[i] = fr(px, pz, yaw)
		elseif i > 0 and i < n and rng:NextNumber() < (opt.miss or 0.12) then
			posts[i] = false
			if rng:NextNumber() < 0.5 then -- the fallen post lies in the grass
				local fcf = at(px + rng:NextNumber(-1, 1), 0.6, pz + rng:NextNumber(-1, 1)) * CFrame.Angles(0, yaw + rng:NextNumber(-0.6, 0.6), math.pi / 2)
				textured(decor(part("FallenPost", Vector3.new(1.2, 3.6, 1.2), fcf, nil, nil, parent)), variant)
			end
		else
			local lean = rng:NextNumber(-0.05, 0.05)
			if rng:NextNumber() < (opt.lean or 0.3) then
				lean = rng:NextNumber(0.1, 0.26) * (if rng:NextNumber() < 0.5 then -1 else 1)
			end
			local h = 3.6 + rng:NextInteger(0, 2) * 0.4
			local cf = fr(px, pz, yaw) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, lean)
			posts[i] = cf
			textured(part("FencePost", Vector3.new(1.2, h, 1.2), cf * CFrame.new(0, h / 2, 0), nil, nil, parent), variant)
		end
	end
	local miss = opt.railMiss or 0.16
	for i = 0, n - 1 do
		local a, b = posts[i], posts[i + 1]
		if a and b then
			for _, hgt in ipairs({ 1.2, 2.6 }) do
				local r = rng:NextNumber()
				if r > miss then
					local pa = (a * CFrame.new(0, hgt, 0)).Position
					local pb = (b * CFrame.new(0, hgt, 0)).Position
					local broken = r < miss + 0.1
					if broken then
						pb = Vector3.new(pb.X, BY + 0.3, pb.Z)
					end
					local rail = part("FenceRail", Vector3.new(0.5, 0.7, (pb - pa).Magnitude), CFrame.lookAt((pa + pb) / 2, pb), nil, nil, parent)
					textured(rail, variant)
					if broken then
						decor(rail)
					end
				end
			end
		elseif a and not b and posts[i + 2] and rng:NextNumber() < 0.6 then
			-- one long rail still bridges the missing post
			local pa = (a * CFrame.new(0, 1.4, 0)).Position
			local pb = (posts[i + 2] * CFrame.new(0, 1.2, 0)).Position
			textured(part("FenceRail", Vector3.new(0.5, 0.7, (pb - pa).Magnitude), CFrame.lookAt((pa + pb) / 2, pb), nil, nil, parent), variant)
		end
	end
end
-- a tall lamp post with an arm, a chain and a lantern hanging over -Z of yaw (the concept's chain lamp)
local function chainLamp(x, z, yaw, parent, withRaven)
	local f = folder("ChainLamp", parent)
	local cf = fr(x, z, yaw)
	lb(cf, "LampFoot", -2, 0, -2, 2, 1.2, 2, "px_cobblestone", C.stone, f)
	lb(cf, "LampPost", -0.9, 1.2, -0.9, 0.9, 14, 0.9, "px_dark_oak_log", nil, f)
	decor(lb(cf, "LampArm", -0.7, 12.4, -5.4, 0.7, 13.8, 0.9, "px_dark_oak_log", nil, f))
	textured(decor(part("LampBrace", Vector3.new(0.9, 0.9, 3.4), cf * CFrame.new(0, 11.2, -1.95) * CFrame.Angles(math.rad(48), 0, 0), nil, nil, f)), WOOD_DARK)
	local top = (cf * CFrame.new(0, 12.4, -4.6)).Position
	local pos = (cf * CFrame.new(0, 7.6, -4.6)).Position
	chain(top, pos + Vector3.new(0, 1.1, 0), f)
	lantern(pos, f)
	lights += 1
	if withRaven then
		raven(x, 14, z, yaw + rng:NextNumber(-1.2, 1.2), f)
	end
	return f
end
-- a clump of tall weeds: thin crooked blades of grass, green-yellow
local function weeds(x, z, parent, n, hmax, y0)
	for _ = 1, n or 4 do
		local h = rng:NextNumber(2, hmax or 4.5)
		local px, pz = x + rng:NextNumber(-2.5, 2.5), z + rng:NextNumber(-2.5, 2.5)
		local cf = at(px, (y0 or 0) + h / 2, pz) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15))
		local p = textured(decor(part("Weed", Vector3.new(rng:NextNumber(1.2, 2), h, 0.25), cf, nil, nil, parent)), "px_grass_top", pick(C.weeds))
		p.CastShadow = false
	end
end
-- weeds may grow anywhere in this zone off the walking surfaces (paths, the pit area, the arrival, the buyer)
local function weedOk(x, z)
	return onIsland(x, z, 6)
		and not onPath(x, z, 1)
		and not inPitArea(x, z, 2)
		and inZone(x, z, 0)
		and (x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2 > 18 ^ 2
		and (x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2 > 14 ^ 2
end
-- an autumn tree of blocks: kind "oak" (oak log, orange stepped crown), "dark" (dark oak, wider deeper crown),
-- "bare" (dark oak, crooked bare branches, a few last leaves); leaves on the ground under it
local function autumnTree(x, z, h, parent, kind)
	local f = folder("AutumnTree", parent)
	box("Trunk", x - 2, 0, z - 2, x + 2, h, z + 2, if kind == "oak" then "px_oak_log" else "px_dark_oak_log", nil, f)
	local rd = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
	box("Root", x + rd[1] * 4 - 2, 0, z + rd[2] * 4 - 2, x + rd[1] * 4 + 2, 2, z + rd[2] * 4 + 2, "px_dark_oak_log", nil, f)
	local main, alt = pick(C.leaves), pick(C.leaves)
	local fallen = decor(box("FallenLeaves", x - 8, 0, z - 8, x + 8, 0.15, z + 8, "px_cherry_leaves", alt, f))
	fallen.CastShadow = false
	if kind == "bare" then
		-- stepped crooked branches (2-stud blocks) and a few last leaf clumps
		for k, d in ipairs({ { 1, 0 }, { -1, 0.5 }, { 0.3, -1 }, { -0.4, 1 } }) do
			local y = h - 8 + k * 2
			local bx, bz = x + d[1] * 4, z + d[2] * 4
			decor(box("Branch", bx - 1, y, bz - 1, bx + 1, y + 4, bz + 1, "px_dark_oak_log", nil, f))
			local cx, cz = x + d[1] * 7, z + d[2] * 7
			decor(box("Branch", cx - 1, y + 3, cz - 1, cx + 1, y + 7, cz + 1, "px_dark_oak_log", nil, f))
			if k % 2 == 1 then
				decor(box("Leaves", cx - 2, y + 7, cz - 2, cx + 2, y + 9, cz + 2, "px_cherry_leaves", C.leaves[2], f))
			end
		end
		decor(box("Branch", x - 1, h, z - 1, x + 1, h + 5, z + 1, "px_dark_oak_log", nil, f))
		return f
	end
	local W = if kind == "dark" then 12 else 10
	decor(box("Leaves", x - W + 4, h - 8, z - W + 4, x + W - 4, h - 4, z + W - 4, "px_cherry_leaves", alt, f))
	decor(box("Leaves", x - W + 4, h - 4, z - W, x + W - 4, h, z + W, "px_cherry_leaves", main, f))
	decor(box("Leaves", x - W, h - 4, z - W + 4, x + W, h, z + W - 4, "px_cherry_leaves", main, f))
	decor(box("Leaves", x - W + 6, h, z - W + 2, x + W - 6, h + 4, z + W - 2, "px_cherry_leaves", main, f))
	decor(box("Leaves", x - W + 2, h, z - W + 6, x + W - 2, h + 4, z + W - 6, "px_cherry_leaves", main, f))
	decor(box("Leaves", x - 4, h + 4, z - 4, x + 4, h + 8, z + 4, "px_cherry_leaves", alt, f))
	-- loose blocks so the crown is not a perfect stack, one hanging below the edge
	for k = 1, 3 do
		local lx = x + rng:NextInteger(-2, 2) * 4
		local lz = z + (if k % 2 == 0 then -1 else 1) * (W + 2)
		local ly = h - 4 + rng:NextInteger(-1, 1) * 4
		if k == 3 then
			lx, lz = x + (W + 2) * (if rng:NextNumber() < 0.5 then -1 else 1), z + rng:NextInteger(-1, 1) * 4
		end
		decor(cube("Leaves", lx, ly + 2, lz, B, B, B, "px_cherry_leaves", pick(C.leaves), f))
	end
	return f
end
-- a low autumn bush (2×2 blocks and a top block): olive or rust-red
local function bush(x, z, parent)
	local red = rng:NextNumber() < 0.4
	local v, t = if red then "px_cherry_leaves" else "px_grass_top", if red then C.leaves[2] else Color3.fromRGB(200, 170, 90)
	box("Bush", x - 4, 0, z - 4, x + 4, 4, z + 4, v, t, parent)
	local ox, oz = rng:NextInteger(-1, 0) * 4, rng:NextInteger(-1, 0) * 4
	decor(box("Bush", x + ox, 4, z + oz, x + ox + 4, 7, z + oz + 4, v, t, parent))
end
-- a junk heap: a stepped coarse-dirt mound, barrels (one fallen), a wheel leaning on it, chains, planks, a pumpkin
local function junkHeap(x, z, parent, litPumpkin)
	local f = folder("JunkHeap", parent)
	box("JunkMound", x - 6, 0, z - 6, x + 6, 2, z + 6, "px_dirt", C.coarse, f)
	box("JunkMound", x - 4, 2, z - 5, x + 3, 4, z + 3, "px_dirt", C.coarse, f)
	box("JunkMound", x - 3, 4, z - 3, x + 1, 5, z + 1, "px_gravel", nil, f)
	barrel(x + 4, 0, z + 3.5, f)
	local lying = at(x - 7.5, 2, z + 2) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), math.pi / 2)
	textured(part("Barrel", Vector3.new(B, B, B), lying, nil, nil, f), "px_spruce_planks", Color3.fromRGB(150, 110, 80))
	for _, o in ipairs({ -1.4, 1.4 }) do
		decor(part("Hoop", Vector3.new(0.3, B + 0.1, B + 0.1), lying * CFrame.new(0, o, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 70, 75), Enum.Material.Metal, f))
	end
	wheel(at(x - 1, 3, z + 7.2) * CFrame.Angles(-0.25, math.pi / 2, 0), 2.8, 0.7, f, false)
	chain(V(x - 5.8, 2.2, z - 2), V(x + 0.5, 5.2, z - 1), f)
	chain(V(x + 0.5, 5.2, z - 1), V(x + 6.4, 0.8, z + 0.5), f)
	for _ = 1, 2 do
		local pcf = at(x + rng:NextNumber(-2, 2), 3.4, z + rng:NextNumber(-3, 1)) * CFrame.Angles(rng:NextNumber(0.3, 0.6), rng:NextNumber(0, math.pi), 0)
		textured(decor(part("Plank", Vector3.new(1, 0.4, 7), pcf, nil, nil, f)), "px_spruce_planks", C.oldWood)
	end
	pumpkin(x - 1.5, 5, z - 1, f, if litPumpkin then "lit" else "carved", rng:NextNumber(-0.8, 0.8))
	for _, o in ipairs({ { -6, -6 }, { 6, -5 }, { 5, 6 } }) do
		weeds(x + o[1], z + o[2], f, 3)
	end
	return f
end

-- ================================================================ 1. round the pit: the crooked fence, lamps, hay
do
	local f = folder("PitFence", out)
	local X, Z0, Z1 = 74, 22, 170
	for _, r in ipairs({
		{ -72, Z0, -12, Z0 }, -- north, open at the ladder shaft x -12..12
		{ 12, Z0, 72, Z0 },
		{ -72, Z1, -22, Z1 }, -- south, open x -20..20 (the arrival walks in here)
		{ 22, Z1, 72, Z1 },
		{ -X, 24, -X, 84 }, -- west, open z 84..108
		{ -X, 108, -X, 168 },
		{ X, 24, X, 84 }, -- east, open z 84..108
		{ X, 108, X, 168 },
	}) do
		crookedFence(r[1], r[2], r[3], r[4], f, { step = 6, miss = 0.1, railMiss = 0.18 })
	end
	-- the corners: a chain lamp on the fence corner, two hay bales outside it with a jack o'lantern and candles
	for i, c in ipairs({ { -X, Z0, -1, -1 }, { X, Z0, 1, -1 }, { -X, Z1, -1, 1 }, { X, Z1, 1, 1 } }) do
		local cx, cz, ox, oz = c[1], c[2], c[3], c[4]
		chainLamp(cx, cz, math.atan2(-ox, -oz), f, i == 2 or i == 3)
		hayBale(cx + ox * 6, 0, cz + oz * 4, f)
		hayBale(cx + ox * 6, 0, cz + oz * 8, f, 0.1)
		pumpkin(cx + ox * 6, 4, cz + oz * 4, f, "lit", math.atan2(-ox, -oz) + rng:NextNumber(-0.3, 0.3))
		candles(cx + ox * 6, 4, cz + oz * 8, f, false)
		pumpkin(cx + ox * 2.5, 0, cz + oz * 7, f, nil, rng:NextNumber(0, 1), 3)
	end
	-- both ends of the south opening: lamps over the arrival walk
	chainLamp(-20, Z1, math.pi, f)
	chainLamp(20, Z1, math.pi, f)
end
task.wait()

-- ================================================================ 2. the south stair down over the rim
do
	local f = folder("SouthStair", out)
	-- the south end of a column of 8-stud island cells (the core builds the ground in 8-stud cells)
	local function edgeZ(cx)
		local z = 184
		while z < 236 and onIsland(cx, z + 4) do
			z += 8
		end
		return z
	end
	local zS = 200
	for _, cx in ipairs({ -12, -4, 4, 12 }) do
		zS = math.max(zS, edgeZ(cx))
	end
	-- the landing: old planks on two dark beams, flush with the ground, on posts where it hangs over the edge
	box("StairLanding", -10, -1, 196, 10, 0.3, zS, "px_spruce_planks", C.oldWood, f)
	for _, s in ipairs({ -1, 1 }) do
		box("LandingBeam", s * 10 - 0.6, -1.6, 196, s * 10 + 0.6, 0.5, zS, "px_dark_oak_planks", nil, f)
		decor(box("LandingPost", s * 9 - 0.6, -12, zS - 1.2, s * 9 + 0.6, -1, zS, "px_dark_oak_log", nil, f))
	end
	-- the steps going down into the void: one missing, one sagging, the last broken off halfway
	for k = 1, 7 do
		local top = 0.3 - k * 3
		local z0 = zS + (k - 1) * 3
		if k ~= 5 then
			local p = decor(box("StairStep", -8, top - 0.8, z0, if k == 7 then 0 else 8, top, z0 + 3, "px_spruce_planks", C.oldWood, f))
			if k == 6 then
				p.CFrame *= CFrame.Angles(0.05, 0, 0.12)
			end
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		local n = if s == 1 then 7 else 5.5 -- the left stringer snapped
		decor(textured(beam("StairStringer", V(s * 8.6, 0, zS), V(s * 8.6, 0.3 - n * 3 - 1, zS + n * 3), 1.2, nil, f), WOOD_DARK))
	end
	-- the hand rail on the right, its last bit hanging; one leaning post on the left
	local railTop = {}
	for i, k in ipairs({ 1, 4 }) do
		local top = 0.3 - k * 3
		local zc = zS + (k - 0.5) * 3
		decor(box("RailPost", 8.1, top, zc - 0.5, 9.1, top + 4, zc + 0.5, WOOD_DARK, nil, f))
		railTop[i] = V(8.6, top + 3.8, zc)
	end
	decor(textured(beam("HandRail", railTop[1], railTop[2], 0.6, nil, f), WOOD_DARK))
	decor(textured(beam("HandRail", railTop[2], railTop[2] + Vector3.new(0, -5, 4), 0.6, nil, f), WOOD_DARK))
	textured(decor(part("RailPost", Vector3.new(1, 4, 1), at(-8.6, -4.7, zS + 4.5) * CFrame.Angles(0.35, 0, -0.2), nil, nil, f)), WOOD_DARK)
	-- the lantern on a pole at the head of the stair, hanging over the steps (thin decor: the arrival stays clear)
	do
		local lz = math.max(zS - 1, SPAWN.z + math.sqrt(400 - 9.4 ^ 2) + 0.2)
		decor(box("LanternPole", -9.9, 0.3, lz - 0.5, -8.9, 9, lz + 0.5, "px_dark_oak_log", nil, f))
		decor(box("LanternArm", -9.9, 8, lz - 0.5, -5.4, 9, lz + 0.5, "px_dark_oak_log", nil, f))
		local pos = V(-6, 5, lz)
		chain(V(-6, 8, lz), pos + Vector3.new(0, 1.1, 0), f)
		lantern(pos, f)
		lights += 1
	end
	-- the old sign on the right: a crooked board «Ферма» (the farm the folk came up from)
	do
		local sz = math.max(zS - 1.5, SPAWN.z + math.sqrt(400 - 9.4 ^ 2) + 0.2)
		decor(box("SignPost", 8.9, 0.3, sz - 0.5, 9.9, 6, sz + 0.5, "px_dark_oak_log", nil, f))
		local board = textured(decor(part("OldSign", Vector3.new(6, 2.2, 0.4), at(7.4, 5.2, sz - 0.7) * CFrame.Angles(0, 0.1, 0.14), nil, nil, f)), "px_spruce_planks", C.oldWood)
		boardText(board, "Ферма", Color3.fromRGB(230, 220, 200))
	end
end
task.wait()

-- ================================================================ 3. the west
local west = folder("West", out)
-- the broken wind pump off the west path: a dark lattice tower, a broken fan, a bent tail vane, a dry trough
do
	local f = folder("WindPump", west)
	local WX, WZ, H = -150, -60, 56
	spot(WX, WZ, 10, "the wind pump")
	claim(WX, WZ, 14)
	local legs = {}
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		box("PumpFoot", WX + s[1] * 8 - 2, 0, WZ + s[2] * 8 - 2, WX + s[1] * 8 + 2, 2, WZ + s[2] * 8 + 2, "px_cobblestone", C.stone, f)
		local a, b = V(WX + s[1] * 8, 2, WZ + s[2] * 8), V(WX + s[1] * 2.5, H, WZ + s[2] * 2.5)
		textured(beam("PumpLeg", a, b, 1.6, nil, f), "px_dark_oak_log")
		table.insert(legs, { a, b })
	end
	-- rings every 10 studs and one zigzag diagonal on each face between them (two pieces broke off)
	local prevT = 0
	for lvl = 1, 5 do
		local t = (lvl * 10 - 2) / (H - 2)
		for i = 1, 4 do
			local l1, l2 = legs[i], legs[i % 4 + 1]
			if not (lvl == 3 and i == 2) then
				decor(textured(beam("PumpBrace", l1[1]:Lerp(l1[2], t), l2[1]:Lerp(l2[2], t), 0.9, nil, f), WOOD_DARK))
			end
			if not (lvl == 4 and i == 3) then
				local from, to = l1[1]:Lerp(l1[2], prevT), l2[1]:Lerp(l2[2], t)
				if (lvl + i) % 2 == 0 then
					from, to = l2[1]:Lerp(l2[2], prevT), l1[1]:Lerp(l1[2], t)
				end
				decor(textured(beam("PumpBrace", from, to, 0.8, nil, f), WOOD_DARK))
			end
		end
		prevT = t
	end
	-- the platform (a corner plank gone), the rusty gearbox, the pump rod down the middle
	decor(box("PumpDeck", WX - 4, H, WZ - 4, WX + 4, H + 0.8, WZ + 1, "px_spruce_planks", C.oldWood, f))
	decor(box("PumpDeck", WX - 4, H, WZ + 1, WX + 1, H + 0.8, WZ + 4, "px_spruce_planks", C.oldWood, f))
	decor(box("PumpHead", WX - 1.5, H + 0.8, WZ - 3, WX + 1.5, H + 4, WZ + 3, "px_terracotta", C.rustLight, f))
	decor(box("PumpRod", WX - 0.25, 2, WZ - 0.25, WX + 0.25, H, WZ + 0.25, "px_iron_block", C.ironDark, f))
	-- the fan on the south side: a hub, three crooked blades (one hangs down, one snapped short), one blade gone
	local hub = at(WX, H + 2.6, WZ + 4.2) * CFrame.Angles(0, 0, 0.3)
	decor(lb(hub, "FanHub", -1.2, -1.2, -0.8, 1.2, 1.2, 0.8, "px_iron_block", C.ironDark, f))
	for _, bl in ipairs({ { 0.4, 11 }, { 2.2, 10 }, { 3.35, 4.5 } }) do
		local bcf = hub * CFrame.Angles(0, 0, bl[1]) * CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
		decor(lb(bcf, "FanSpar", -0.3, 1, -0.3, 0.3, bl[2] + 1, 0.3, "px_dark_oak_planks", nil, f))
		decor(lb(bcf, "FanBlade", 0.3, 2.5, -0.15, 2.8, bl[2] + 1, 0.15, "px_spruce_planks", C.oldWood, f))
	end
	-- the hanging blade: torn off the hub, dangling from a wire by one corner
	local hang = at(WX - 2.2, H - 5.6, WZ + 4.8) * CFrame.Angles(0.1, 0, 0.12)
	decor(lb(hang, "FanBlade", -1.25, -5, -0.15, 1.25, 5, 0.15, "px_spruce_planks", C.oldWood, f))
	decor(part("FanWire", Vector3.new(0.2, 3.2, 0.2), at(WX - 1.6, H + 0.6, WZ + 4.6), C.chain, Enum.Material.Metal, f))
	-- the tail vane: a boom to the north, the vane board bent down
	decor(textured(beam("TailBoom", V(WX, H + 2.6, WZ - 3), V(WX + 0.6, H + 2, WZ - 12), 0.8, nil, f), WOOD_DARK))
	textured(decor(part("TailVane", Vector3.new(0.3, 4.4, 6), at(WX + 0.7, H + 0.4, WZ - 13.5) * CFrame.Angles(0.5, 0.15, 0.1), nil, nil, f)), "px_spruce_planks", C.oldWood)
	-- the dry trough and a rusty pipe at its foot
	box("Trough", WX + 4, 0, WZ + 10, WX + 12, 2.4, WZ + 14, "px_spruce_planks", C.oldWood, f)
	decor(box("TroughDirt", WX + 4.6, 2.4, WZ + 10.6, WX + 11.4, 2.5, WZ + 13.4, "px_dirt", PODZOL, f))
	decor(box("PumpPipe", WX - 0.4, 0, WZ - 0.4, WX + 0.4, 6, WZ + 0.4, "px_iron_block", RUST, f))
	decor(box("PumpPipe", WX - 0.4, 5.2, WZ, WX + 0.4, 6, WZ + 11, "px_iron_block", RUST, f))
	weeds(WX + 6, WZ - 6, f, 4, 5)
	weeds(WX - 7, WZ + 5, f, 4, 5)
	weeds(WX + 14, WZ + 8, f, 3)
end
-- the collapsed shed next to it: a broken back wall, a low side wall, the roof slid to the ground
do
	local f = folder("CollapsedShed", west)
	local x0, z0, x1, z1 = -124, -64, -108, -48
	spot(-116, -56, 8, "the collapsed shed")
	claim(-116, -56, 12)
	box("ShedWall", x0, 0, z0, -114, 9, z0 + 2, "px_spruce_planks", C.oldWood, f)
	box("ShedWall", -114, 0, z0, x1, 5, z0 + 2, "px_spruce_planks", C.oldWood, f)
	box("ShedWall", x0, 0, z0 + 2, x0 + 2, 4, z1 - 6, "px_spruce_planks", C.oldWood, f)
	box("ShedPost", x0 - 0.4, 0, z0 - 0.4, x0 + 2.4, 10, z0 + 2.4, "px_dark_oak_log", nil, f)
	box("ShedPost", x1 - 2.4, 0, z0 - 0.4, x1 + 0.4, 6, z0 + 2.4, "px_dark_oak_log", nil, f)
	box("ShedPost", x1 - 2.4, 0, z1 - 2.4, x1 + 0.4, 3, z1 + 0.4, "px_dark_oak_log", nil, f)
	-- the roof: one slab from the back wall top down to the ground, a second one slipped beside it
	local a, b = V(-117, 9.5, z0 + 1), V(-117, 0.6, z1 - 1)
	textured(part("ShedRoof", Vector3.new(14, 0.8, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.4, 0), nil, nil, f), "px_dark_oak_planks")
	local c, d = V(-111, 4.6, z0 + 3), V(-106, 0.5, z1 + 2)
	textured(decor(part("ShedRoof", Vector3.new(6, 0.8, (d - c).Magnitude), CFrame.lookAt((c + d) / 2, d) * CFrame.Angles(0, 0, 0.3), nil, nil, f)), "px_dark_oak_planks")
	crate(-121, 0, -52, f, B, 0.4)
	for _ = 1, 3 do
		local pcf = at(-112 + rng:NextNumber(-3, 3), 0.25, -46 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		textured(decor(part("Plank", Vector3.new(1, 0.4, 6), pcf, nil, nil, f)), "px_spruce_planks", C.oldWood)
	end
	weeds(-122, -46, f, 4, 5)
	weeds(-106, -60, f, 3)
end
task.wait()
-- the rusty tractor: an orange-rust body, iron parts, big black wheels, one front wheel off, overgrown
do
	local f = folder("RustyTractor", west)
	local TX, TZ = -128, 50
	spot(TX, TZ, 8, "the tractor")
	claim(TX, TZ, 12)
	local base = fr(TX, TZ, 0.7)
	local cf = base * CFrame.Angles(0.03, 0, -0.06) -- sunk on the side of the lost wheel
	for _, s in ipairs({ -1, 1 }) do
		wheel(cf * CFrame.new(s * 5.2, 3.8, 3), 3.8, 2.2, f, true)
		lb(cf, "Fender", s * 3.4, 7.6, -0.8, s * 7.2, 8.4, 6.8, "px_terracotta", C.rustLight, f)
	end
	wheel(cf * CFrame.new(3.6, 2.2, -6.5), 2.2, 1.4, f, true)
	wheel(base * CFrame.new(-8.5, 0.7, -9) * CFrame.Angles(0, 0.4, math.pi / 2), 2.2, 1.4, f, true)
	lb(cf, "TractorFrame", -1.6, 1.2, -9, 1.6, 3, 4, "px_iron_block", C.ironDark, f)
	lb(cf, "TractorHood", -2.4, 3, -9, 2.4, 7, -1.5, "px_terracotta", C.rustLight, f)
	decor(lb(cf, "RustPatch", -2.5, 5.4, -7, 0.6, 7.1, -3, "px_terracotta", RUST, f))
	lb(cf, "TractorGrille", -2.2, 3.2, -9.6, 2.2, 6.8, -8.9, "px_iron_block", C.iron, f)
	lb(cf, "TractorBody", -3, 3, -1.5, 3, 5.6, 4.5, "px_terracotta", RUST, f)
	lb(cf, "TractorSeat", -1.4, 5.6, 1.6, 1.4, 6.6, 4, "px_brown_wool", C.hat, f)
	decor(lb(cf, "TractorSeatBack", -1.4, 6.6, 3.5, 1.4, 9, 4.1, "px_brown_wool", C.hat, f))
	decor(part("SteeringColumn", Vector3.new(0.4, 0.4, 3.4), cf * CFrame.new(0, 7.2, -0.2) * CFrame.Angles(math.rad(60), 0, 0), C.ironDark, Enum.Material.Metal, f))
	decor(part("SteeringWheel", Vector3.new(2.4, 0.3, 2.4), cf * CFrame.new(0, 8.6, 0.6) * CFrame.Angles(-0.5, 0, 0), C.tyre, nil, f))
	decor(lb(cf, "Exhaust", 0.8, 7, -7.4, 1.6, 11.6, -6.6, "px_iron_block", C.ironDark, f))
	decor(lb(cf, "ExhaustCap", 0.6, 11.6, -7.6, 1.8, 12.2, -6.4, "px_iron_block", RUST, f))
	-- overgrown: vines over the grille and down the side, moss on the hood, weeds through the wheels
	decor(lb(cf, "Vines", -2.4, 3.6, -9.95, 0.4, 7.2, -9.7, "px_hedge", C.vine, f))
	decor(lb(cf, "Vines", -2.7, 2.4, -7, -2.45, 7, -3.4, "px_hedge", C.vine, f))
	decor(lb(cf, "Moss", -2.5, 7, -5, 2.5, 7.3, -1.6, "px_grass_top", WEEDS, f))
	decor(lb(cf, "Moss", -3.1, 5.6, -1, 0, 5.9, 1.4, "px_grass_top", WEEDS, f))
	for _, o in ipairs({ { -6, 4 }, { 6, 2 }, { 2, -9 }, { -4, -7 }, { 0, 6 } }) do
		local p = (base * CFrame.new(o[1], 0, o[2])).Position
		weeds(p.X - BX, p.Z - BZ, f, 4, 5)
	end
end
-- the abandoned cart: tilted on its lost wheel, the shafts broken, its load gone to grass
do
	local f = folder("AbandonedCart", west)
	local KX, KZ = near(-112, 140, 7, "the cart")
	if KX then
		claim(KX, KZ, 9)
		local base = fr(KX, KZ, -0.9)
		local cf = base * CFrame.Angles(0, 0, 0.16)
		lb(cf, "CartBed", -3, 1.6, -5, 3, 2.4, 5, "px_dark_oak_planks", nil, f)
		lb(cf, "CartSide", 2.6, 2.4, -5, 3.4, 4.4, 5, "px_spruce_planks", C.oldWood, f)
		lb(cf, "CartSide", -3.4, 2.4, -5, -2.6, 4.4, 1, "px_spruce_planks", C.oldWood, f)
		lb(cf, "CartFront", -3, 2.4, -5.4, 3, 4.4, -4.6, "px_spruce_planks", C.oldWood, f)
		wheel(cf * CFrame.new(3.9, 2.4, 0.5), 2.6, 0.8, f, false, "px_dark_oak_planks", C.oldWood)
		wheel(base * CFrame.new(-6.8, 0.4, 2.5) * CFrame.Angles(0, 0.3, math.pi / 2), 2.6, 0.8, f, false, "px_dark_oak_planks", C.oldWood)
		for _, s in ipairs({ -1, 1 }) do
			local a = (cf * CFrame.new(s * 1.6, 2, -5)).Position
			local b = (base * CFrame.new(s * 1.6 + (if s < 0 then -1 else 0.5), 0.4, if s < 0 then -12 else -9)).Position
			decor(textured(beam("CartShaft", a, b, 0.6, nil, f), WOOD_DARK))
		end
		decor(lb(cf, "CartLoad", -2.6, 2.4, -4.4, 2.6, 4, 4.4, "px_grass_top", WEEDS, f))
		decor(lb(cf, "Vines", 3.45, 0.6, -3, 3.7, 4.4, 1.5, "px_hedge", C.vine, f))
		local top = (cf * CFrame.new(0, 4, 0)).Position
		weeds(top.X - BX, top.Z - BZ, f, 4, 3.5, top.Y - BY)
		weeds(KX + 5, KZ - 4, f, 3)
		weeds(KX - 4, KZ + 6, f, 3)
	end
end
-- junk heaps
do
	local f = folder("JunkHeaps", west)
	for i, j in ipairs({ { -170, 24 }, { -106, 162 } }) do
		local x, z = near(j[1], j[2], 7, "a junk heap")
		if x then
			claim(x, z, 9)
			junkHeap(x, z, f, i == 1)
		end
	end
end
task.wait()
-- the wild pumpkin patch with the burning scarecrow in the middle
do
	local f = folder("WildPumpkins", west)
	local PX, PZ, R = -145, 104, 20
	spot(PX, PZ, 6, "the scarecrow")
	local lit = 0
	for gx = PX - R, PX + R, 5 do
		for gz = PZ - R, PZ + R, 5 do
			local x, z = gx + rng:NextNumber(-1.5, 1.5), gz + rng:NextNumber(-1.5, 1.5)
			local d = math.sqrt((x - PX) ^ 2 + (z - PZ) ^ 2)
			if d <= R and d > 5 and ok(x, z, 1) then
				if rng:NextNumber() < 0.36 then
					local m, mode = rng:NextNumber(), nil
					if m < 0.14 and lit < 2 then
						mode, lit = "lit", lit + 1
					elseif m < 0.32 then
						mode = "carved"
					end
					-- faces turn east, to the ring path
					pumpkin(x, 0, z, f, mode, -math.pi / 2 + rng:NextNumber(-0.7, 0.7), if rng:NextNumber() < 0.5 then 3 else B)
					local vcf = at(x, 0.15, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.new(0, 0, 4)
					textured(decor(part("PumpkinVine", Vector3.new(0.8, 0.3, rng:NextNumber(4, 7)), vcf, nil, nil, f)), "px_hedge", C.vine)
				else
					weeds(x, z, f, 3, 5.5)
				end
			end
		end
	end
	claim(PX, PZ, R)
	-- the scarecrow: a tattered coat on a cross, a burning jack o'lantern head, chains from the arms, its hat fallen
	local s = folder("Scarecrow", f)
	local cf = fr(PX, PZ, -math.pi / 2)
	lb(cf, "ScarecrowPost", -0.7, 0, -0.7, 0.7, 9, 0.7, "px_dark_oak_log", nil, s)
	decor(lb(cf, "ScarecrowArm", -5.6, 6.6, -0.5, 5.6, 7.6, 0.5, "px_dark_oak_log", nil, s))
	lb(cf, "ScarecrowCoat", -1.9, 3.6, -1.1, 1.9, 8.4, 1.1, "px_brown_wool", C.coat, s)
	decor(lb(cf, "ScarecrowRag", -1.9, 2.4, -1.15, -0.5, 3.6, 1.15, "px_brown_wool", C.coat, s))
	decor(lb(cf, "ScarecrowRag", 0.6, 2.8, -1.15, 1.9, 3.6, 1.15, "px_brown_wool", C.coat, s))
	for _, sx in ipairs({ -1, 1 }) do
		decor(lb(cf, "ScarecrowSleeve", sx * 1.9, 6.2, -0.8, sx * 4.4, 8, 0.8, "px_brown_wool", C.coat, s))
		decor(lb(cf, "Straw", sx * 4.4, 6, -0.6, sx * 5.4, 8.2, 0.6, "px_hay", nil, s))
		local top = (cf * CFrame.new(sx * 5, 6.6, 0)).Position
		chain(top, top - Vector3.new(0, if sx < 0 then 4.4 else 3.3, 0), s)
	end
	chain((cf * CFrame.new(0.8, 5.4, -0.9)).Position, (cf * CFrame.new(2.8, 0.3, -2.6)).Position, s)
	local head = lb(cf, "BurningPumpkin", -1.8, 8.4, -1.8, 1.8, 11.8, 1.8, "px_hay", PUMPKIN, s)
	for _, b in ipairs({
		lc(cf, "CarvedEye", 0.8, 0.7, 0.2, -0.8, 10.7, -1.85, C.faceGlow, s),
		lc(cf, "CarvedEye", 0.8, 0.7, 0.2, 0.8, 10.7, -1.85, C.faceGlow, s),
		lc(cf, "CarvedMouth", 2.4, 0.6, 0.2, 0, 9.4, -1.85, C.faceGlow, s),
	}) do
		b.Material = Enum.Material.Neon
	end
	local src = decor(part("HeadFire", Vector3.new(2.4, 0.4, 2.4), cf * CFrame.new(0, 12, 0), nil, nil, s))
	src.Transparency = 1
	emitter(src, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 90), Color3.fromRGB(230, 70, 20)),
		LightEmission = 0.8,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(0.5, 0.9),
		Rate = 18,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(12, 12),
		Acceleration = Vector3.new(0, 2, 0),
	})
	glow(head, 22, 1.8, Color3.fromRGB(255, 140, 50))
	-- the hat lies in the weeds, a hay bale at the foot
	local hat = fr(PX - 3, PZ - 3, 0.6) * CFrame.Angles(0.25, 0, 0.1)
	decor(lb(hat, "HatBrim", -2.6, 0.2, -2.6, 2.6, 0.6, 2.6, "px_brown_wool", C.hat, s))
	decor(lb(hat, "HatCrown", -1.4, 0.6, -1.4, 1.4, 2.2, 1.4, "px_brown_wool", C.hat, s))
	hayBale(PX + 3.2, 0, PZ + 2, s, 0.3)
	weeds(PX - 2, PZ + 3, s, 3, 5)
end
task.wait()
-- the west path lamps (on its edges, the arms over the path)
do
	local f = folder("WestPathLamps", west)
	for i, l in ipairs({ { -112, -28, math.pi }, { -152, -4, 0 }, { -192, -28, math.pi } }) do
		spot(l[1], l[2], 0, "a west path lamp")
		claim(l[1], l[2], 4)
		chainLamp(l[1], l[2], l[3], f, i == 1)
	end
end
task.wait()

-- ================================================================ 4. the east
local east = folder("East", out)
-- the farmhouse ruin: the north and west walls standing, a chimney, the roof caved into the rooms
do
	local f = folder("FarmhouseRuin", east)
	local X0, X1, Z0, Z1 = 112, 144, -72, -40
	spot(128, -56, 16, "the farmhouse ruin")
	claim(128, -56, 26)
	local P, PT = "px_spruce_planks", C.oldWood
	box("RuinFloor", X0, 0, Z0, X1, 0.4, Z1, "px_planks", Color3.fromRGB(170, 150, 130), f)
	decor(box("RuinDirt", 120, 0.4, -52, 134, 0.5, -44, "px_dirt", PODZOL, f))
	-- the north wall with an empty window and the stump of the gable
	box("RuinWall", X0, 0.4, Z0, 124, 12, Z0 + 4, P, PT, f)
	box("RuinWall", 132, 0.4, Z0, X1, 12, Z0 + 4, P, PT, f)
	box("RuinWall", 124, 0.4, Z0, 132, 5, Z0 + 4, P, PT, f)
	box("RuinWall", 124, 9, Z0, 132, 12, Z0 + 4, P, PT, f)
	box("RuinGable", 116, 13, Z0, 132, 16, Z0 + 4, P, PT, f)
	box("RuinGable", 120, 16, Z0, 128, 20, Z0 + 4, P, PT, f)
	box("RuinRoofEdge", X0 - 1, 12, Z0 - 2, 132, 13, Z0 + 6, "px_dark_oak_planks", nil, f)
	-- the west wall, its window and its south end broken down in steps
	box("RuinWall", X0, 0.4, Z0 + 4, X0 + 4, 12, -60, P, PT, f)
	box("RuinWall", X0, 0.4, -60, X0 + 4, 5, -52, P, PT, f)
	box("RuinWall", X0, 9, -60, X0 + 4, 12, -56, P, PT, f)
	box("RuinWall", X0, 0.4, -52, X0 + 4, 8, -46, P, PT, f)
	box("RuinWall", X0, 0.4, -46, X0 + 4, 4, Z1, P, PT, f)
	-- the east and south walls are rubble
	box("RuinRubble", X1 - 4, 0.4, Z0 + 4, X1, 4, -60, P, PT, f)
	box("RuinRubble", X1 - 4, 0.4, -60, X1, 2, -54, "px_cobblestone", C.stone, f)
	box("RuinRubble", X0, 0.4, Z1 - 4, 124, 3, Z1, P, PT, f)
	box("RuinRubble", 136, 0.4, Z1 - 4, X1, 5, Z1, P, PT, f)
	-- log corner posts
	box("RuinCorner", X0 - 0.4, 0, Z0 - 0.4, X0 + 4.4, 12.4, Z0 + 4.4, "px_oak_log", nil, f)
	box("RuinCorner", X1 - 4.4, 0, Z0 - 0.4, X1 + 0.4, 12.4, Z0 + 4.4, "px_oak_log", nil, f)
	box("RuinCorner", X0 - 0.4, 0, Z1 - 4.4, X0 + 4.4, 8, Z1 + 0.4, "px_oak_log", nil, f)
	box("RuinCorner", X1 - 4.4, 0, Z1 - 4.4, X1 + 0.4, 3, Z1 + 0.4, "px_oak_log", nil, f)
	-- the chimney outside the north wall, its top broken
	box("Chimney", 136, 0, Z0 - 6, 142, 22, Z0, "px_cobblestone", C.stone, f)
	box("Chimney", 136, 22, Z0 - 6, 139, 25, Z0 - 3, "px_cobblestone", C.stone, f)
	decor(box("ChimneyHole", 139.2, 21.95, Z0 - 5, 141, 22.05, Z0 - 1, nil, C.hole, f))
	-- the caved roof: a big slab from the north wall top down to the floor, a smaller one in the south, rafters
	local a, b = V(128, 12, Z0 + 4), V(128, 1, -50)
	textured(part("CavedRoof", Vector3.new(22, 1, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.new(0, 0.5, 0), nil, nil, f), "px_dark_oak_planks")
	local c, d = V(122, 8, -47), V(134, 0.8, -43)
	textured(part("CavedRoof", Vector3.new(8, 1, (d - c).Magnitude), CFrame.lookAt((c + d) / 2, d) * CFrame.new(0, 0.5, 0), nil, nil, f), "px_dark_oak_planks")
	for _, r in ipairs({ { V(118, 12, Z0 + 3), V(121, 0.8, -46) }, { V(138, 12, Z0 + 3), V(142, 4.4, -56) }, { V(114, 12, -62), V(130, 0.8, -54) } }) do
		decor(textured(beam("Rafter", r[1], r[2], 1.2, nil, f), WOOD_DARK))
	end
	-- inside: a broken table, a jack o'lantern by the doorway, weeds through the floor, a bare tree in the corner
	box("TableLeg", 132, 0.4, -57, 133, 3, -56, WOOD_DARK, nil, f)
	textured(part("TableTop", Vector3.new(6, 0.6, 4), at(134, 2.4, -56) * CFrame.Angles(0, 0.2, 0.35), nil, nil, f), "px_spruce_planks", C.oldWood)
	pumpkin(130, 0.4, -43, f, "lit", math.pi + 0.3)
	candles(127, 0.4, -43.4, f, false)
	for _, w in ipairs({ { 118, -50 }, { 126, -64 }, { 138, -46 }, { 116, -44 } }) do
		weeds(w[1], w[2], f, 4, 5)
	end
	autumnTree(138, -64, 16, f, "bare")
	raven(X1 - 2, 12.4, Z0 + 2, -2.4, f)
end
task.wait()
-- the broken silo (decor, not a pillar): stone with red bands, the top broken open, vines, rubble at its foot
do
	local f = folder("BrokenSilo", east)
	local SX, SZ = 150, 60
	spot(SX, SZ, 12, "the silo")
	claim(SX, SZ, 16)
	local function oct(name, r, cut, y0, y1, variant, tint)
		box(name, SX - r + cut, y0, SZ - r, SX + r - cut, y1, SZ + r, variant, tint, f)
		box(name, SX - r, y0, SZ - r + cut, SX + r, y1, SZ + r - cut, variant, tint, f)
	end
	oct("SiloFoot", 11, 4.4, 0, 1.2, "px_cobblestone", C.stone)
	for _, band in ipairs({ { 0, 10, "px_stone_bricks", C.stone }, { 10, 14, "px_red_brick" }, { 14, 26, "px_stone_bricks", C.stone }, { 26, 30, "px_red_brick" }, { 30, 38, "px_stone_bricks", C.stone } }) do
		oct("SiloWall", 10, 4, band[1], band[2], band[3], band[4])
	end
	decor(box("SiloHollow", SX - 6, 37.95, SZ - 6, SX + 6, 38.1, SZ + 6, nil, C.hole, f))
	-- jagged remains of the top
	box("SiloShard", SX - 10, 38, SZ - 6, SX - 6, 46, SZ + 6, "px_stone_bricks", C.stone, f)
	box("SiloShard", SX - 6, 38, SZ + 6, SX + 2, 42, SZ + 10, "px_red_brick", nil, f)
	box("SiloShard", SX + 6, 38, SZ - 6, SX + 10, 41, SZ - 2, "px_stone_bricks", C.stone, f)
	box("SiloShard", SX - 6, 38, SZ - 10, SX - 2, 44, SZ - 6, "px_stone_bricks", C.stone, f)
	-- a hole broken through the south-east wall, a rusty iron strip, vines climbing it
	decor(box("SiloBreach", SX - 2, 17, SZ + 10.05, SX + 3, 24, SZ + 10.3, nil, C.hole, f))
	decor(box("SiloStrip", SX + 10.05, 2, SZ - 1, SX + 10.4, 34, SZ + 1, "px_iron_block", RUST, f))
	for _, v in ipairs({
		{ SX - 6, SZ + 10.6, SX - 2, SZ + 11, 16 },
		{ SX - 2, SZ + 10.6, SX + 2, SZ + 11, 9 },
		{ SX - 10.9, SZ - 4, SX - 10.5, SZ, 30 },
		{ SX - 10.9, SZ, SX - 10.5, SZ + 4, 20 },
		{ SX - 4, SZ - 10.9, SX, SZ - 10.5, 12 },
		{ SX + 10.5, SZ - 5, SX + 10.9, SZ - 1, 8 },
	}) do
		decor(box("Vines", v[1], 1.2, v[2], v[3], v[5], v[4], "px_hedge", C.vine, f))
	end
	for _, r in ipairs({ { SX + 13, SZ + 6, 0.3 }, { SX + 4, SZ + 14, 0.8 }, { SX - 13, SZ + 9, -0.4 } }) do
		lb(fr(r[1], r[2], r[3]), "SiloRubble", -2, 0, -2, 2, 4, 2, "px_cobblestone", C.stone, f)
	end
	weeds(SX + 12, SZ - 8, f, 4, 5)
	weeds(SX - 12, SZ - 4, f, 4, 5)
	weeds(SX + 2, SZ + 13, f, 3)
	pumpkin(SX + 9, 0, SZ + 13, f, "carved", math.pi + 0.4)
	pumpkin(SX + 14, 0, SZ + 11, f, nil, 0.3, 3)
end
-- the well with a broken roof
do
	local f = folder("Well", east)
	local WX, WZ = 124, 30
	spot(WX, WZ, 8, "the well")
	claim(WX, WZ, 11)
	box("WellWall", WX - 6, 0, WZ - 6, WX + 6, 4, WZ - 2, "px_mossy_cobblestone", nil, f)
	box("WellWall", WX - 6, 0, WZ + 2, WX + 6, 4, WZ + 6, "px_cobblestone", C.stone, f)
	box("WellWall", WX - 6, 0, WZ - 2, WX - 2, 4, WZ + 2, "px_cobblestone", C.stone, f)
	box("WellWall", WX + 2, 0, WZ - 2, WX + 6, 4, WZ + 2, "px_mossy_cobblestone", nil, f)
	decor(box("WellWater", WX - 2, 1.4, WZ - 2, WX + 2, 1.6, WZ + 2, nil, C.water, f))
	box("WellPost", WX - 4.6, 4, WZ - 0.6, WX - 3.4, 12, WZ + 0.6, "px_oak_log", nil, f)
	box("WellPost", WX + 3.4, 4, WZ - 0.6, WX + 4.6, 8.6, WZ + 0.6, "px_oak_log", nil, f)
	decor(textured(beam("WellBar", V(WX - 4, 11.4, WZ), V(WX + 4, 8.8, WZ), 0.8, nil, f), WOOD_DARK))
	decor(part("WellRope", Vector3.new(0.2, 3, 0.2), at(WX - 1, 8.9, WZ), Color3.fromRGB(150, 120, 80), Enum.Material.Fabric, f))
	decor(box("WellBucket", WX - 1.7, 6.2, WZ - 0.7, WX - 0.3, 7.6, WZ + 0.7, "px_iron_block", C.ironDark, f))
	-- one half of the roof still hangs on the tall post, the other half fell against the well
	textured(decor(part("WellRoof", Vector3.new(6, 0.6, 12), at(WX - 6.2, 10.4, WZ) * CFrame.Angles(0, 0, 0.6), nil, nil, f)), "px_dark_oak_planks")
	textured(part("WellRoof", Vector3.new(6, 0.6, 12), at(WX + 8.6, 2.6, WZ + 1) * CFrame.Angles(0, 0.15, 1.15), nil, nil, f), "px_dark_oak_planks")
	weeds(WX - 7, WZ + 7, f, 3)
	weeds(WX + 4, WZ - 8, f, 3)
end
task.wait()
-- the pigsty remains: a muddy pen in a crooked fence, a split trough, a lean-to with old straw
do
	local f = folder("Pigsty", east)
	local x0, z0, x1, z1 = 128, 102, 152, 122
	spot(140, 112, 12, "the pigsty")
	claim(140, 112, 18)
	decor(box("PigstyMud", x0, 0, z0, x1, 0.15, z1, "px_dirt", C.mud, f))
	crookedFence(x0, z0, x1, z0, f, { miss = 0.15, lean = 0.4 })
	crookedFence(x1, z0, x1, z1, f, { miss = 0.2, lean = 0.4, skipFirst = true })
	crookedFence(x1, z1, x0, z1, f, { miss = 0.5, lean = 0.5, railMiss = 0.4, skipFirst = true })
	crookedFence(x0, z1, x0, 116, f, { lean = 0.4, skipFirst = true })
	crookedFence(x0, 108, x0, z0, f, { lean = 0.4 })
	box("Trough", 132, 0, 105, 137, 2, 108, "px_spruce_planks", C.oldWood, f)
	textured(part("Trough", Vector3.new(4, 2, 3), at(139.5, 0.9, 106.6) * CFrame.Angles(0, 0.3, 0.25), nil, nil, f), "px_spruce_planks", C.oldWood)
	decor(box("TroughSlop", 132.6, 2, 105.6, 136.4, 2.1, 107.4, "px_dirt", C.mud, f))
	box("LeanToPost", 146.4, 0, 105, 147.4, 7, 106, WOOD_DARK, nil, f)
	box("LeanToPost", 150.6, 0, 105, 151.6, 7, 106, WOOD_DARK, nil, f)
	local a, b = V(149, 7.2, 104), V(149, 3.6, 112)
	textured(part("LeanToRoof", Vector3.new(7, 0.6, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, 0, 0.08), nil, nil, f), "px_dark_oak_planks")
	decor(box("OldStraw", 146.5, 0.15, 106.5, 151.5, 0.9, 111, "px_hay", nil, f))
	pumpkin(131, 0, 118, f, nil, 0.4, 3)
	pumpkin(156, 0, 117, f, "carved", -math.pi / 2)
	weeds(134, 120, f, 3)
	weeds(150, 120, f, 4, 5)
	weeds(126, 104, f, 3)
end
-- candles on hay with a raven on a fence post (the concept's small panel)
do
	local f = folder("CandleHay", east)
	local HX, HZ = 118, 150
	spot(HX, HZ, 8, "the candle hay")
	claim(HX, HZ, 10)
	hayBale(HX - 2, 0, HZ, f)
	hayBale(HX + 2, 0, HZ, f)
	hayBale(HX, 4, HZ, f, 0.15)
	hayBale(HX + 5, 0, HZ + 4.5, f, -0.2)
	candles(HX, 8, HZ, f, true)
	candles(HX + 5, 4, HZ + 4.5, f, false)
	candles(HX - 4.5, 0, HZ + 3, f, false)
	barrel(HX + 6, 0, HZ - 3, f)
	box("RavenPost", HX - 6.6, 0, HZ - 4.6, HX - 5.4, 7, HZ - 3.4, "px_dark_oak_log", nil, f)
	raven(HX - 6, 7, HZ - 4, 2.6, f)
	crookedFence(HX - 6, HZ - 4, HX - 18, HZ - 6, f, { skipFirst = true, miss = 0.3 })
	pumpkin(HX - 9, 0, HZ + 3, f, "carved", math.pi - 0.3)
	weeds(HX + 1, HZ + 6, f, 3)
	weeds(HX - 3, HZ - 6, f, 3)
end
task.wait()
-- more pumpkins, crooked fences, a junk heap and the east path lamps
do
	local f = folder("EastScatter", east)
	local modes = { "lit", "carved", false, false, "carved", false, false, "carved", false, false }
	for i, p in ipairs({ { 104, 64 }, { 168, 34 }, { 100, 124 }, { 160, 142 }, { 172, -36 }, { 106, 88 }, { 176, 86 }, { 140, 160 }, { 186, 60 }, { 102, 172 } }) do
		local x, z = near(p[1], p[2], 2, "an east pumpkin")
		if x then
			pumpkin(x, 0, z, f, modes[i], rng:NextNumber(0, math.pi * 2), if i % 3 == 0 then 3 else B)
			if i % 2 == 0 then
				pumpkin(x + 3.5, 0, z + 1.5, f, nil, rng:NextNumber(0, 3), 3)
			end
			weeds(x - 3, z + 2, f, 3)
		end
	end
	local function okFence(x, z)
		return freeGround(x, z, 0) and inZone(x, z, 1) and not isTaken(x, z, 1)
	end
	for _, l in ipairs({ { 100, 44, 128, 48 }, { 168, 92, 178, 116 }, { 100, 108, 100, 136 }, { 160, 6, 196, 2 }, { 156, -44, 160, -72 } }) do
		crookedFence(l[1], l[2], l[3], l[4], f, { check = okFence, miss = 0.25, lean = 0.45, railMiss = 0.3 })
	end
	local x, z = near(172, -44, 8, "the east junk heap")
	if x then
		claim(x, z, 9)
		junkHeap(x, z, f, false)
	end
	for i, l in ipairs({ { 112, -28, math.pi }, { 152, -4, 0 }, { 192, -28, math.pi } }) do
		spot(l[1], l[2], 0, "an east path lamp")
		claim(l[1], l[2], 4)
		chainLamp(l[1], l[2], l[3], f, i == 2)
	end
end
task.wait()

-- ================================================================ 5. everywhere: trees, bushes, weeds
do
	local f = folder("Trees", out)
	local n = 0
	for _ = 1, 800 do
		if n >= 32 then
			break
		end
		local x, z = rng:NextInteger(-52, 52) * 4, rng:NextInteger(-20, 52) * 4
		if ok(x, z, 8) then
			local r = rng:NextNumber()
			local kind = if r < 0.2 then "bare" elseif r < 0.6 then "oak" else "dark"
			autumnTree(x, z, rng:NextInteger(4, 6) * 4, f, kind)
			claim(x, z, 8)
			n += 1
			if n % 8 == 0 then
				task.wait()
			end
		end
	end
	print(("[build-barn] outskirts: %d trees"):format(n))
end
task.wait()
do
	local f = folder("Bushes", out)
	local n = 0
	for _ = 1, 400 do
		if n >= 26 then
			break
		end
		local x, z = rng:NextInteger(-52, 52) * 4, rng:NextInteger(-20, 52) * 4
		if ok(x, z, 3) then
			bush(x, z, f)
			claim(x, z, 5)
			n += 1
		end
	end
end
do
	local f = folder("Weeds", out)
	local n = 0
	for _ = 1, 900 do
		if n >= 130 then
			break
		end
		local x, z = rng:NextNumber(-210, 210), rng:NextNumber(-80, 210)
		if weedOk(x, z) then
			weeds(x, z, f, rng:NextInteger(3, 5), 5)
			n += 1
		end
	end
end
task.wait()

-- ================================================================ 6. the rim: hanging roots and grass, a broken edge fence
do
	local f = folder("RimRoots", out)
	for x = -240, 232, 8 do
		for z = -240, 232, 8 do
			local cx, cz = x + 4, z + 4
			if onIsland(cx, cz) and zoneOf(cx, cz) == "outskirts" and not (math.abs(cx) < 16 and cz > 180) then
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					if not onIsland(cx + d[1] * 8, cz + d[2] * 8) and rng:NextNumber() < 0.5 then
						-- the cell face is at ±4; the hanging bits stand 0.6 off it
						local fx, fz = cx + d[1] * 4.8, cz + d[2] * 4.8
						local alongX = d[1] == 0
						local w = rng:NextInteger(1, 2) * 4
						local lip = decor(part("HangingGrass", if alongX then Vector3.new(w, 2.4, 0.4) else Vector3.new(0.4, 2.4, w), at(fx, -1, fz), nil, nil, f))
						textured(lip, "px_grass_top", WEEDS)
						lip.CastShadow = false
						for _ = 1, rng:NextInteger(1, 2) do
							local o = rng:NextNumber(-3, 3)
							local len = rng:NextInteger(2, 5) * 2
							local rx, rz = fx + (if alongX then o else 0), fz + (if alongX then 0 else o)
							local root = decor(part("HangingRoot", Vector3.new(0.8, len, 0.8), at(rx, -2 - len / 2, rz) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12)), nil, nil, f))
							textured(root, "px_dark_oak_log")
						end
					end
				end
			end
		end
		if x % 64 == 0 then
			task.wait()
		end
	end
end
do
	local f = folder("EdgeFence", out)
	local pts = {}
	local function flush()
		for i = 1, #pts - 1 do
			crookedFence(pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2], f, { step = 5, skipFirst = i > 1, miss = 0.25, lean = 0.45, railMiss = 0.3 })
		end
		pts = {}
	end
	local N = 140
	for i = 0, N - 1 do
		local a = i / N * math.pi * 2
		local ca, sa = math.cos(a), math.sin(a)
		local r = 230
		while r > 120 and not onIsland(ca * r, sa * r, 14) do
			r -= 2
		end
		local x, z = ca * r, sa * r
		local good = r > 120
			and inZone(x, z, 3)
			and not onPath(x, z, 4)
			and not inPitArea(x, z, 6)
			and (x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2 > 24 ^ 2
			and (x - BUYER.x) ^ 2 + (z - BUYER.z) ^ 2 > 16 ^ 2
			and not (math.abs(x) < 16 and z > 180)
			and not isTaken(x, z, 3)
			and n2(x, z, 9.1, 0.015) > -0.05
		if good then
			table.insert(pts, { x, z })
		else
			flush()
		end
	end
	flush()
end

print(("[build-barn] outskirts: %d parts, %d point lights"):format(count - startCount, lights))
