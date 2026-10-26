--!nocheck
-- ================================================================ inside_out: the dead town (the main island)
-- The Upside Down copy of a small American suburb round the mine square, in blocks:
--   square   an oak fence ring 1 block outside the pit rim (stone-brick pillars every 4 blocks; open at the four
--            ladder shafts), six lamp posts, benches, crates, barrels, two dead trees, the overturned car (86, -94)
--   streets  yellow dashed centre lines on every street and round the ring road, potholes and heaved slabs
--   houses   22 two-storey clapboard houses in DISTRICTS (two designs: front-gable with a half porch, side-gable with
--            a full porch and dormers; garages on some), every one choked by crimson vines
--   church   the white church in NE (164, -26 → -90), a stepped steeple with a dark spire and a cross, a rift door
--   wall     the alphabet wall in NNW (x -24..-20, z -172..-144, facing the north street) under Christmas lights
--   props    telephone poles with sagging wires, street lamps (two broken), the school bus (119, 36), two wrecked
--            cars, a bicycle by a picket fence (-33, -133), mailboxes, hydrants, a town sign, cocoons, rift doors
--   growth   vine bushes, crimson carpets and ash piles on every free bit of town ground (seeded rng)
local town = folder("Town")
local startCount = count
local C = {
	trim = Color3.fromRGB(232, 228, 220),
	glass = Color3.fromRGB(86, 76, 92),
	roof = Color3.fromRGB(112, 114, 134), -- dark slate
	roofBrown = Color3.fromRGB(128, 96, 92),
	found = Color3.fromRGB(150, 140, 140),
	stone = Color3.fromRGB(150, 146, 146),
	oak = Color3.fromRGB(200, 164, 112),
	bark = Color3.fromRGB(120, 100, 96),
	deck = Color3.fromRGB(150, 120, 100),
	door = Color3.fromRGB(150, 104, 84),
	metal = Color3.fromRGB(150, 150, 156),
	tyre = Color3.fromRGB(70, 66, 72),
	wire = Color3.fromRGB(24, 22, 26),
	cap = Color3.fromRGB(90, 84, 88),
	drive = Color3.fromRGB(120, 116, 118),
	mail = Color3.fromRGB(120, 130, 150),
	can = Color3.fromRGB(120, 126, 124),
	bus = Color3.fromRGB(240, 178, 40),
	church = Color3.fromRGB(236, 232, 224),
	pale = Color3.fromRGB(196, 170, 150),
	-- clapboard walls (variant, tint): pale green, blue-grey, cream, red-brown, cream wool, grey, green-grey, rose
	walls = {
		{ "px_white_wool", Color3.fromRGB(150, 172, 150) },
		{ "px_white_wool", Color3.fromRGB(140, 152, 174) },
		{ "px_planks", Color3.fromRGB(250, 238, 212) },
		{ "px_spruce_planks", Color3.fromRGB(206, 132, 118) },
		{ "px_white_wool", Color3.fromRGB(214, 204, 176) },
		{ "px_spruce_planks", Color3.fromRGB(172, 182, 192) },
		{ "px_dark_oak_planks", Color3.fromRGB(196, 206, 190) },
		{ "px_white_wool", Color3.fromRGB(178, 136, 126) },
	},
}
local ROOF = "px_roof_tiles"
local FACE_YAW = { N = 0, S = math.pi, E = -math.pi / 2, W = math.pi / 2 } -- the house front (local -Z) faces this way

-- a textured box in a frame cf (a world CFrame) by two local corners; variant nil = a plain part in colour tint
local function lb(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(name, size, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a small plain decor part in a frame cf by size and local centre
local function lc(cf, name, sx, sy, sz, x, y, z, color, material, parent)
	return decor(part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, material, parent))
end

-- occupied ground (local x0, z0, x1, z1): lots, the church, vehicles, poles — the random growth keeps off it
local occ = {
	{ -16, -204, 16, -176 }, -- the north street end (the sky road)
	{ -16, 176, 16, 204 }, -- the south street end (the arena bridge)
	{ -144, 168, -96, 204 }, -- the SW street end (the islet bridge)
	{ 96, 168, 144, 204 }, -- the SE street end
	{ -19, 88, -9, 96 }, -- the zone sign at the arrival (core)
}
local function addOcc(x0, z0, x1, z1)
	table.insert(occ, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) })
end
local function isFree(x, z, r)
	for _, o in ipairs(occ) do
		if x > o[1] - r and x < o[3] + r and z > o[2] - r and z < o[4] + r then
			return false
		end
	end
	return true
end
-- the first free spot at (x, z) shifted along (ux, uz): props slide along the kerb past mailboxes and lots
local function freeSpot(x, z, r, ux, uz)
	for _, o in ipairs({ 0, 6, -6, 12, -12, 18, -18 }) do
		local px, pz = x + ux * o, z + uz * o
		if isFree(px, pz, r) then
			return px, pz
		end
	end
	return nil
end

-- a window on a wall plane: axis "z" = the wall is the plane z = plane (a runs along x), axis "x" = the plane
-- x = plane (a runs along z); sgn = the outward side; white frame, dark pane
local function win(cf, axis, plane, sgn, a, y0, w, h, f, frameTint)
	local ft = frameTint or C.trim
	if axis == "z" then
		decor(lb(cf, "WinFrame", a - w / 2 - 0.6, y0 - 0.6, plane, a + w / 2 + 0.6, y0 + h + 0.6, plane + sgn * 0.25, "px_white_wool", ft, f))
		decor(lb(cf, "Window", a - w / 2, y0, plane, a + w / 2, y0 + h, plane + sgn * 0.4, "px_blackstone", C.glass, f))
	else
		decor(lb(cf, "WinFrame", plane, y0 - 0.6, a - w / 2 - 0.6, plane + sgn * 0.25, y0 + h + 0.6, a + w / 2 + 0.6, "px_white_wool", ft, f))
		decor(lb(cf, "Window", plane, y0, a - w / 2, plane + sgn * 0.4, y0 + h, a + w / 2, "px_blackstone", C.glass, f))
	end
end
-- a white picket fence in a frame: axis "x" runs along x at z = c (axis "z": along z at x = c), from a0 to a1
local function picket(cf, axis, c, a0, a1, f)
	local function seg(name, s0, s1, y0, y1, t0, t1)
		if axis == "x" then
			return lb(cf, name, s0, y0, c + t0, s1, y1, c + t1, "px_white_wool", C.trim, f)
		end
		return lb(cf, name, c + t0, y0, s0, c + t1, y1, s1, "px_white_wool", C.trim, f)
	end
	decor(seg("PicketRail", a0, a1, 1, 1.5, -0.35, 0.35))
	decor(seg("PicketRail", a0, a1, 2.4, 2.9, -0.35, 0.35))
	local n = math.max(1, math.floor(math.abs(a1 - a0) / 2.5))
	for i = 0, n do
		local s = a0 + (a1 - a0) * i / n
		seg("Picket", s - 0.4, s + 0.4, 0, 3.6, -0.2, 0.2)
	end
end
-- a rift door: a glowing red tear in a wall inside a frame of crimson growth; cf = the bottom centre on the wall
-- face, local -Z out of the wall
local function rift(cf, f)
	local r = folder("RiftDoor", f)
	decor(lb(cf, "RiftFrame", -4.5, 0, -0.8, -2.5, 13, 0, "px_nether_wart", VINE_DARK, r))
	decor(lb(cf, "RiftFrame", 2.5, 0, -0.8, 4.5, 12, 0, "px_nether_wart", VINE_RED, r))
	decor(lb(cf, "RiftFrame", -3, 12, -0.8, 3.5, 14.5, 0, "px_nether_wart", VINE_DARK, r))
	decor(lb(cf, "RiftFrame", -3, 0, -0.8, 3, 0.8, 0, "px_nether_wart", VINE_RED, r))
	-- the tear: narrow at the ends, widest in the middle
	for i, s in ipairs({ { 0.8, 2.5, 1.2 }, { 2.5, 5, 2 }, { 5, 8, 2.5 }, { 8, 10.5, 1.8 }, { 10.5, 12, 1 } }) do
		local v = if i == 3 then "px_shroomlight" else "px_magma"
		decor(lb(cf, "RiftGlow", -s[3], s[1], -0.5, s[3], s[2], 0.1, v, Color3.fromRGB(255, 96, 80), r))
	end
	local core = lc(cf, "RiftCore", 0.6, 8.4, 0.2, 0.3, 6.2, -0.6, GLOW_RED, Enum.Material.Neon, r)
	lc(cf, "RiftCore", 0.4, 4, 0.2, -0.9, 4.6, -0.6, GLOW_RED, Enum.Material.Neon, r)
	light(core, 22, 2.2, GLOW_RED)
	emitter(core, {
		Rate = 3,
		Lifetime = NumberRange.new(2, 3),
		Speed = NumberRange.new(0.6, 1.4),
		SpreadAngle = Vector2.new(40, 40),
		EmissionDirection = Enum.NormalId.Front,
		Size = NumberSequence.new(0.2),
		Color = ColorSequence.new(GLOW_RED),
		LightEmission = 1,
	})
	decor(lb(cf, "RiftVine", 3.4, 5, -1.3, 5, 15, -0.6, "px_nether_wart", VINE_RED, r))
	return r
end
-- a cocoon (2×3 blocks of crimson growth with a pale shape inside); cf = the bottom centre on the wall face,
-- local -Z out of the wall (or free hanging)
local function cocoon(cf, f)
	local c = folder("Cocoon", f)
	decor(lb(cf, "Cocoon", -4, 2, -4, 4, 10, 0, "px_nether_wart", VINE_DARK, c))
	decor(lb(cf, "Cocoon", -2.5, 0, -3.4, 2.5, 2, -0.3, "px_nether_wart", VINE_RED, c))
	decor(lb(cf, "Cocoon", -2.5, 10, -3.4, 2.5, 12.5, -0.3, "px_nether_wart", VINE_RED, c))
	decor(lb(cf, "CocoonBody", -1.6, 3.5, -4.3, 1.6, 9, -3.8, "px_white_wool", C.pale, c))
	decor(lb(cf, "CocoonStrand", -0.6, -5, -2.4, 0.6, 0, -1.2, "px_nether_wart", VINE_RED, c))
	decor(lb(cf, "CocoonStrand", 1.4, 12.5, -2.2, 2.4, 16, -1.2, "px_nether_wart", VINE_DARK, c))
	return c
end
-- a dead tree: a dark log trunk with three bare limbs (each turning up at the end), a few red vine blobs
local function deadTree(x, z, h, f, blobs)
	local t = folder("DeadTree", f)
	box("Trunk", x - 2, 0, z - 2, x + 2, h, z + 2, "px_dark_oak_log", C.bark, t)
	local dirs = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }
	local first = rng:NextInteger(1, 4)
	for i = 0, 2 do
		local d = dirs[(first + i - 1) % 4 + 1]
		local y = math.max(6, h - 3 - i * 4)
		local len = rng:NextInteger(1, 2) * 4
		local ex, ez = x + d[1] * (2 + len), z + d[2] * (2 + len)
		if d[1] ~= 0 then
			box("Branch", x + d[1] * 2, y, z - 1.5, ex, y + 3, z + 1.5, "px_dark_oak_log", C.bark, t)
		else
			box("Branch", x - 1.5, y, z + d[2] * 2, x + 1.5, y + 3, ez, "px_dark_oak_log", C.bark, t)
		end
		local up = rng:NextInteger(1, 2) * 4
		local cx, cz = ex - d[1] * 1.5, ez - d[2] * 1.5
		box("Branch", cx - 1.5, y + 3, cz - 1.5, cx + 1.5, y + 3 + up, cz + 1.5, "px_dark_oak_log", C.bark, t)
		if blobs and rng:NextNumber() < 0.6 then
			decor(box("TreeVine", cx - 2, y + 3 + up, cz - 2, cx + 2, y + 7 + up, cz + 2, "px_nether_wart", VINE_RED, t))
		end
	end
	decor(box("RootMoss", x - 6, 0, z - 6, x + 6, 0.3, z + 6, "px_crimson_nylium", nil, t))
	return t
end
-- the world (local) point of a lot-local point (lx along the front, lz back from the lot front)
local function toWorld(L, lx, lz)
	if L.face == "N" then
		return L.x + lx, L.z + lz
	elseif L.face == "S" then
		return L.x - lx, L.z - lz
	elseif L.face == "E" then
		return L.x - lz, L.z + lx
	end
	return L.x + lz, L.z - lx
end

-- ================================================================ the houses
-- A lot: front edge at local z 0 (on the street side), the porch z 0..8, the house body z 8..8+D, x ±W/2 (+2 for
-- the chimney and fences, +16 on the garage side). design 1: front-gable, half porch on the door side, a lawn on
-- the other; design 2: side-gable, full porch, a dormer, the chimney on the ridge. m mirrors the door side,
-- g = garage side (±1), rift / cocoon = the side wall that carries it, fence = a picket fence along that side.
local function house(L, idx)
	local W, D = L.w, L.d
	local hw, F, WT = W / 2, 8, 20
	local zb = F + D
	local g = L.g or 0
	local x0, x1 = -hw - 2, hw + 2
	if g < 0 then
		x0 = -hw - 16
	elseif g > 0 then
		x1 = hw + 16
	end
	-- the lot must sit on the island (12 studs off the rim) and off every street (4 studs)
	for i = 0, 8 do
		local t = i / 8
		for _, p in ipairs({ { x0 + (x1 - x0) * t, 0 }, { x0 + (x1 - x0) * t, zb + 2 }, { x0, (zb + 2) * t }, { x1, (zb + 2) * t } }) do
			local wx, wz = toWorld(L, p[1], p[2])
			if not onMain(wx, wz, 12) or onStreet(wx, wz, 4) then
				warn(("[build-inside-out] house %d skipped: lot off the island or on a street at (%d, %d)"):format(idx, wx, wz))
				return
			end
		end
	end
	do
		local ax, az = toWorld(L, x0, 0)
		local bx, bz = toWorld(L, x1, zb + 2)
		addOcc(ax, az, bx, bz)
	end
	local f = folder("House" .. idx, town)
	local cf = at(L.x, 0, L.z) * CFrame.Angles(0, FACE_YAW[L.face], 0)
	local wv, wt = C.walls[L.col][1], C.walls[L.col][2]
	local m = L.m or 1
	local roofT = if L.brown then C.roofBrown else C.roof
	local d1 = L.design == 1
	local dx = if d1 then -6 * m else 0
	local cs = if g ~= 0 then -g elseif L.rift then -L.rift else m -- the chimney side
	-- the body: a cobble foundation, one box of clapboard, white corner boards and a floor band
	lb(cf, "Foundation", -hw - 0.3, 0, F - 0.3, hw + 0.3, 2, zb + 0.3, "px_cobblestone", C.found, f)
	lb(cf, "Walls", -hw, 2, F, hw, WT, zb, wv, wt, f)
	for _, sx in ipairs({ -1, 1 }) do
		for _, zz in ipairs({ F, zb }) do
			decor(lb(cf, "CornerBoard", sx * hw - 0.7, 2, zz - 0.7, sx * hw + 0.7, WT, zz + 0.7, "px_white_wool", C.trim, f))
		end
	end
	decor(lb(cf, "Band", -hw, 11, F - 0.3, hw, 12, F, "px_white_wool", C.trim, f))
	-- the porch: a plank deck, white posts, a slate roof, railings either side of the walk to the door
	local px0, px1 = -hw + 1, hw - 1
	if d1 then
		px0, px1 = if m == 1 then -hw + 1 else -2, if m == 1 then 2 else hw - 1
	end
	lb(cf, "Porch", px0, 0, 0.5, px1, 1, F, "px_spruce_planks", C.deck, f)
	decor(lb(cf, "PorchRoof", px0 - 0.6, 11, 0, px1 + 0.6, 12, F, ROOF, roofT, f))
	local posts = { px0 + 0.6, px1 - 0.6 }
	if not d1 then
		table.insert(posts, -hw / 3)
		table.insert(posts, hw / 3)
	end
	for _, x in ipairs(posts) do
		lb(cf, "PorchPost", x - 0.6, 1, 0.6, x + 0.6, 11, 1.8, "px_white_wool", C.trim, f)
	end
	if dx - 3 > px0 + 1 then
		decor(lb(cf, "Railing", px0 + 1, 3, 0.8, dx - 3, 3.6, 1.6, "px_white_wool", C.trim, f))
	end
	if px1 - 1 > dx + 3 then
		decor(lb(cf, "Railing", dx + 3, 3, 0.8, px1 - 1, 3.6, 1.6, "px_white_wool", C.trim, f))
	end
	decor(lb(cf, "DoorFrame", dx - 2.7, 1, F - 0.25, dx + 2.7, 10.7, F, "px_white_wool", C.trim, f))
	lb(cf, "Door", dx - 2, 1, F - 0.45, dx + 2, 10, F, "px_dark_oak_planks", C.door, f)
	-- windows: front, sides (none behind the garage, none above the rift), back
	if d1 then
		win(cf, "z", F, -1, 6 * m, 4, 6, 6, f)
		win(cf, "z", F, -1, -6, 13.5, 4, 4.5, f)
		win(cf, "z", F, -1, 6, 13.5, 4, 4.5, f)
	else
		win(cf, "z", F, -1, -9, 4, 4, 6, f)
		win(cf, "z", F, -1, 9, 4, 4, 6, f)
		for _, a in ipairs({ -9, 0, 9 }) do
			win(cf, "z", F, -1, a, 13.5, 4, 4.5, f)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		local za = if d1 then F + D * 0.3 else F + D / 2
		if g ~= sx then
			win(cf, "x", sx * hw, sx, za, 4, 4, 6, f)
		end
		win(cf, "x", sx * hw, sx, za, 13.5, 4, 4.5, f)
		if d1 and L.rift ~= sx then
			win(cf, "x", sx * hw, sx, F + D * 0.7, 13.5, 4, 4.5, f)
		end
	end
	win(cf, "z", zb, 1, if d1 then -6 else -9, 13.5, 4, 4.5, f)
	win(cf, "z", zb, 1, if d1 then 6 else 9, 13.5, 4, 4.5, f)
	-- the roof: stepped slate layers one block up and one block in; the gable ends filled with clapboard
	local dorm = nil
	if d1 then
		for k = 0, 3 do
			local h = hw + 2 - 4 * k
			if h <= 0 then
				break
			end
			lb(cf, "Roof", -h, WT + 4 * k, F - 2, h, WT + 4 * k + 4, zb + 2, ROOF, roofT, f)
			if h - 4 > 0 then
				lb(cf, "Gable", -(h - 4), WT + 4 * k, F - 2.2, h - 4, WT + 4 * k + 4, zb + 2.2, wv, wt, f)
			end
		end
		win(cf, "z", F - 2.2, -1, 0, 24.6, 3, 3, f)
		local zc = F + D / 2
		lb(cf, "Chimney", cs * hw - 2, 0, zc - 2, cs * hw + 2, WT + 18, zc + 2, "px_red_brick", nil, f)
		decor(lb(cf, "ChimneyCap", cs * hw - 2.5, WT + 18, zc - 2.5, cs * hw + 2.5, WT + 19, zc + 2.5, "px_blackstone", C.cap, f))
	else
		local hd, zc = D / 2 + 2, F + D / 2
		for k = 0, 3 do
			local h = hd - 4 * k
			if h <= 0 then
				break
			end
			lb(cf, "Roof", -hw - 2, WT + 4 * k, zc - h, hw + 2, WT + 4 * k + 4, zc + h, ROOF, roofT, f)
			if h - 4 > 0 then
				lb(cf, "Gable", -hw - 2.2, WT + 4 * k, zc - (h - 4), hw + 2.2, WT + 4 * k + 4, zc + (h - 4), wv, wt, f)
			end
		end
		dorm = 0
		lb(cf, "Dormer", -4, WT + 4, F - 1, 4, WT + 10, F + 8, wv, wt, f)
		decor(lb(cf, "DormerRoof", -5, WT + 10, F - 2, 5, WT + 11, F + 9, ROOF, roofT, f))
		win(cf, "z", F - 1, -1, 0, WT + 5, 3, 3.5, f)
		local cx = cs * (hw - 6)
		lb(cf, "Chimney", cx - 2, WT + 8, zc - 2, cx + 2, WT + 22, zc + 2, "px_red_brick", nil, f)
		decor(lb(cf, "ChimneyCap", cx - 2.5, WT + 22, zc - 2.5, cx + 2.5, WT + 23, zc + 2.5, "px_blackstone", C.cap, f))
	end
	-- the garage (set back, flat slate roof, a white door, a grey drive to the lot front)
	if g ~= 0 then
		local a, b = math.min(g * hw, g * (hw + 16)), math.max(g * hw, g * (hw + 16))
		local gz0 = zb - 22
		lb(cf, "Garage", a, 0, gz0, b, 12, zb, wv, wt, f)
		decor(lb(cf, "GarageRoof", a - 0.8, 12, gz0 - 0.8, b + 0.8, 13, zb + 0.8, ROOF, roofT, f))
		lb(cf, "GarageDoor", a + 2, 0, gz0 - 0.3, b - 2, 9.5, gz0, "px_white_wool", C.trim, f)
		decor(lb(cf, "GarageSlat", a + 2, 3, gz0 - 0.45, b - 2, 3.4, gz0, nil, C.metal, f))
		decor(lb(cf, "GarageSlat", a + 2, 6.4, gz0 - 0.45, b - 2, 6.8, gz0, nil, C.metal, f))
		decor(lb(cf, "Driveway", a + 1, 0, 0, b - 1, 0.12, gz0 - 0.3, "px_smooth_stone", C.drive, f))
	end
	-- the lawn of a front-gable house: a red hedge under the window or a trash can
	if d1 and L.lawn == "hedge" then
		lb(cf, "Hedge", m * 3, 0, F - 3.5, m * (hw - 1), 3, F - 0.4, "px_nether_wart", VINE_DARK, f)
	elseif d1 and L.lawn == "trash" then
		local tx = m * (hw - 2.5)
		lb(cf, "TrashCan", tx - 1.2, 0, 1.8, tx + 1.2, 3.2, 4.2, "px_iron_block", C.can, f)
		decor(lb(cf, "TrashLid", tx - 1.4, 3.2, 1.6, tx + 1.4, 3.6, 4.4, "px_iron_block", C.cap, f))
	end
	if L.fence then
		picket(cf, "z", L.fence * (hw + 1.5), 0.5, F + 6, f)
	end
	-- the mailbox at the kerb
	do
		local mx = m * (hw - 1)
		lb(cf, "MailPost", mx - 0.4, 0, -2.4, mx + 0.4, 3.4, -1.6, "px_dark_oak_planks", nil, f)
		decor(lb(cf, "Mailbox", mx - 0.8, 3.4, -3.1, mx + 0.8, 4.8, -0.9, "px_iron_block", C.mail, f))
		local wx, wz = toWorld(L, mx, -2)
		addOcc(wx - 1.5, wz - 1.5, wx + 1.5, wz + 1.5)
	end
	-- overgrown: vine columns hanging from the eaves on the front and the sides, vine blobs on the roof steps,
	-- a vine curtain off the porch roof, crimson moss on it
	for _ = 1, rng:NextInteger(4, 6) do
		local tint = if rng:NextNumber() < 0.5 then VINE_RED else VINE_DARK
		local len = rng:NextInteger(2, 4) * 4
		local side = rng:NextInteger(0, 2)
		if side == 0 then
			local x = -hw + 2 + 4 * rng:NextInteger(0, W / 4 - 1)
			if math.abs(x - dx) >= 4.5 then
				local bot = WT - len
				if x > px0 - 2 and x < px1 + 2 then
					bot = math.max(bot, 12)
				end
				decor(lb(cf, "Vine", x - 2, bot, F - 0.7, x + 2, WT + 0.6, F - 0.05, "px_nether_wart", tint, f))
			end
		else
			local sx = if side == 1 then -1 else 1
			local z = F + 2 + 4 * rng:NextInteger(0, D / 4 - 1)
			local clash = g == sx
				or (d1 and sx == cs and math.abs(z - (F + D / 2)) < 4.5)
				or (L.rift == sx and math.abs(z - (zb - 5.5)) < 7)
				or (L.cocoon == sx and math.abs(z - (F + 4.6)) < 6.5)
			if not clash then
				decor(lb(cf, "Vine", sx * (hw + 0.05), math.max(2, WT - len - 4), z - 2, sx * (hw + 0.7), WT + 0.6, z + 2, "px_nether_wart", tint, f))
			end
		end
	end
	for _ = 1, rng:NextInteger(1, 2) do
		local k = rng:NextInteger(0, 1)
		local s = if rng:NextNumber() < 0.5 then -1 else 1
		local top = WT + 4 * k + 4
		local tint = if rng:NextNumber() < 0.5 then VINE_RED else VINE_DARK
		local x, z
		if d1 then
			x, z = s * (hw - 4 * k), F + 2 + 4 * rng:NextInteger(0, D / 4 - 1)
		else
			x, z = -hw + 2 + 4 * rng:NextInteger(0, W / 4 - 1), F + D / 2 + s * (D / 2 - 4 * k)
		end
		local hitsDormer = dorm and s < 0 and k == 0 and math.abs(x - dorm) < 7
		if not hitsDormer then
			decor(lb(cf, "RoofVine", x - 2, top, z - 2, x + 2, top + 4, z + 2, "px_nether_wart", tint, f))
		end
	end
	if rng:NextNumber() < 0.6 then
		local vx = if d1 then 0 else px0 + 2
		decor(lb(cf, "PorchVine", vx - 2, 6, -0.6, vx + 2, 12, 0, "px_nether_wart", VINE_RED, f))
	end
	if rng:NextNumber() < 0.5 then
		local a = math.min(px0 + 1, px1 - 9)
		decor(lb(cf, "PorchMoss", a, 12, 0.5, a + 8, 12.3, F - 0.5, "px_crimson_nylium", nil, f))
	end
	if L.rift then
		rift(cf * CFrame.new(L.rift * hw, 2, zb - 5.5) * CFrame.Angles(0, -L.rift * math.pi / 2, 0), f)
	end
	if L.cocoon then
		cocoon(cf * CFrame.new(L.cocoon * hw, 6, F + 4.6) * CFrame.Angles(0, -L.cocoon * math.pi / 2, 0), f)
	end
	return f
end

-- every lot fronts a street (checked: all corners onMain(…, 12), nothing within 4 studs of a street)
local LOTS = {
	-- NW: the west street and the ring road
	{ x = -182, z = -26, face = "S", design = 2, w = 28, d = 24, col = 1, m = 1, fence = -1, brown = true },
	{ x = -146, z = -26, face = "S", design = 1, w = 24, d = 28, col = 2, m = -1, lawn = "hedge" },
	{ x = -128, z = -96, face = "E", design = 1, w = 24, d = 28, col = 3, m = 1, lawn = "trash", fence = 1 },
	{ x = -128, z = -136, face = "E", design = 2, w = 28, d = 24, col = 4, m = -1, cocoon = 1 },
	-- NNW: the ring road (the alphabet wall next door; house 6 carries a rift on its side toward it)
	{ x = -88, z = -132, face = "S", design = 1, w = 24, d = 28, col = 5, m = 1, lawn = "hedge" },
	{ x = -56, z = -132, face = "S", design = 1, w = 24, d = 28, col = 6, m = -1, rift = -1, lawn = "trash" },
	-- NNE
	{ x = 34, z = -132, face = "S", design = 2, w = 28, d = 24, col = 7, m = 1, fence = 1, brown = true },
	{ x = 68, z = -132, face = "S", design = 1, w = 24, d = 28, col = 8, m = 1, g = -1 },
	-- NE (the church at 164, -26)
	{ x = 128, z = -112, face = "W", design = 2, w = 28, d = 24, col = 2, m = 1, rift = 1 },
	{ x = 128, z = -144, face = "W", design = 1, w = 20, d = 24, col = 3, m = -1, lawn = "hedge" },
	-- SW: the west street, the ring road and the SW street
	{ x = -182, z = 10, face = "N", design = 1, w = 24, d = 28, col = 4, m = -1, lawn = "trash", fence = -1 },
	{ x = -148, z = 10, face = "N", design = 2, w = 28, d = 24, col = 5, m = 1, brown = true },
	{ x = -132, z = 80, face = "E", design = 2, w = 28, d = 24, col = 6, m = 1, fence = -1 },
	{ x = -132, z = 122, face = "E", design = 1, w = 24, d = 28, col = 1, m = 1, rift = -1, lawn = "hedge" },
	-- SE: the east street, the ring road (the school bus parks by house 17)
	{ x = 182, z = 10, face = "N", design = 2, w = 28, d = 24, col = 7, m = -1 },
	{ x = 148, z = 10, face = "N", design = 1, w = 24, d = 28, col = 8, m = 1, lawn = "hedge" },
	{ x = 132, z = 84, face = "W", design = 1, w = 24, d = 28, col = 1, m = -1, g = 1 },
	{ x = 132, z = 124, face = "W", design = 2, w = 28, d = 24, col = 3, m = 1, cocoon = -1, brown = true },
	-- SSW / SSE: the ring road south
	{ x = -84, z = 128, face = "N", design = 2, w = 28, d = 24, col = 2, m = -1, fence = 1 },
	{ x = -44, z = 128, face = "N", design = 1, w = 24, d = 28, col = 5, m = 1, g = 1 },
	{ x = 52, z = 128, face = "N", design = 1, w = 24, d = 28, col = 6, m = -1, lawn = "trash" },
	{ x = 84, z = 128, face = "N", design = 2, w = 28, d = 24, col = 4, m = 1, brown = true },
}
for i, L in ipairs(LOTS) do
	house(L, i)
	if i % 6 == 0 then
		task.wait()
	end
end
task.wait()

-- ================================================================ the church (NE, facing the east street)
do
	local f = folder("Church", town)
	local cf = at(164, 0, -26) * CFrame.Angles(0, math.pi, 0)
	local WH, WT = "px_white_wool", C.church
	local DARK = Color3.fromRGB(70, 64, 74)
	addOcc(148, -92, 180, -24)
	lb(cf, "Step", -8, 0, 0, 8, 1, 3, "px_stone_bricks", C.found, f)
	lb(cf, "Step", -8, 0, 3, 8, 2, 6.2, "px_stone_bricks", C.found, f)
	lb(cf, "Foundation", -14.3, 0, 13.7, 14.3, 2, 62.3, "px_cobblestone", C.found, f)
	lb(cf, "TowerFoot", -6.3, 0, 5.7, 6.3, 2, 18.3, "px_cobblestone", C.found, f)
	lb(cf, "Nave", -14, 2, 14, 14, 22, 62, WH, WT, f)
	lb(cf, "Tower", -6, 2, 6, 6, 31, 18, WH, WT, f)
	-- the nave roof: stepped slate, the gable ends white
	for k = 0, 3 do
		local h = 16 - 4 * k
		lb(cf, "Roof", -h, 22 + 4 * k, 12, h, 26 + 4 * k, 64, ROOF, C.roof, f)
		if k < 3 then
			lb(cf, "Gable", -(h - 4), 22 + 4 * k, 11.8, h - 4, 26 + 4 * k, 64.2, WH, WT, f)
		end
	end
	-- the steeple: a band, the belfry with dark openings, a cornice, stepped stages, the dark spire and the cross
	decor(lb(cf, "TowerBand", -6.5, 31, 5.5, 6.5, 32, 18.5, "px_dark_oak_planks", nil, f))
	lb(cf, "Belfry", -6, 32, 6, 6, 40, 18, WH, WT, f)
	decor(lb(cf, "BelfryOpening", -2, 33, 5.6, 2, 39, 18.4, "px_blackstone", Color3.fromRGB(60, 50, 56), f))
	decor(lb(cf, "BelfryOpening", -6.4, 33, 10, 6.4, 39, 14, "px_blackstone", Color3.fromRGB(60, 50, 56), f))
	lb(cf, "Cornice", -7, 40, 5, 7, 41, 19, ROOF, C.roof, f)
	lb(cf, "Steeple", -5, 41, 7, 5, 45, 17, WH, WT, f)
	lb(cf, "Steeple", -4, 45, 8, 4, 50, 16, ROOF, C.roof, f)
	lb(cf, "Steeple", -3, 50, 9, 3, 56, 15, ROOF, C.roof, f)
	lb(cf, "Spire", -2, 56, 10, 2, 62, 14, "px_blackstone", DARK, f)
	lb(cf, "Spire", -1, 62, 11, 1, 68, 13, "px_blackstone", DARK, f)
	lc(cf, "Cross", 0.8, 7, 0.8, 0, 71.5, 12, Color3.fromRGB(40, 38, 44), Enum.Material.Metal, f)
	lc(cf, "Cross", 4, 0.8, 0.8, 0, 72.6, 12, Color3.fromRGB(40, 38, 44), Enum.Material.Metal, f)
	-- the doors and windows (dark frames on the white walls)
	decor(lb(cf, "DoorFrame", -4, 2, 5.7, 4, 14, 6, "px_dark_oak_planks", Color3.fromRGB(110, 86, 74), f))
	lb(cf, "Door", -3, 2, 5.45, 3, 12, 6, "px_dark_oak_planks", C.door, f)
	decor(lb(cf, "DoorArch", -2, 12, 5.45, 2, 13.4, 6, "px_dark_oak_planks", C.door, f))
	win(cf, "z", 6, -1, 0, 18, 4, 4, f, DARK)
	for _, s in ipairs({ -1, 1 }) do
		win(cf, "z", 14, -1, s * 10, 8, 4, 8, f, DARK)
		for _, z in ipairs({ 24, 34, 44, 54 }) do
			if not (s == 1 and z == 54) then
				win(cf, "x", s * 14, s, z, 6, 4, 10, f, DARK)
				decor(lb(cf, "WinPoint", s * 14, 16.6, z - 1, s * (14 + 0.4), 18, z + 1, "px_blackstone", C.glass, f))
			end
		end
	end
	-- the rift on the west wall (local +x), a cocoon on the back wall
	rift(cf * CFrame.new(14, 2, 54) * CFrame.Angles(0, -math.pi / 2, 0), f)
	cocoon(cf * CFrame.new(-6, 6, 62) * CFrame.Angles(0, math.pi, 0), f)
	-- vines: columns down the nave walls and the tower, blobs on the roof steps
	for _, v in ipairs({ { -1, 19, 12 }, { -1, 39, 16 }, { -1, 59, 8 }, { 1, 29, 14 }, { 1, 39, 10 }, { 1, 49, 16 } }) do
		local s = v[1]
		decor(lb(cf, "Vine", s * 14.05, 22.6 - v[3], v[2] - 2, s * 14.7, 22.6, v[2] + 2, "px_nether_wart", if v[3] > 12 then VINE_DARK else VINE_RED, f))
	end
	decor(lb(cf, "Vine", 2, 20, 5.3, 6, 31.5, 5.95, "px_nether_wart", VINE_RED, f))
	decor(lb(cf, "Vine", -6.7, 8, 8, -6.05, 31.5, 12, "px_nether_wart", VINE_DARK, f))
	for _, v in ipairs({ { -14, 26, 30 }, { 14, 26, 42 }, { -10, 30, 50 } }) do
		decor(lb(cf, "RoofVine", v[1] - 2, v[2], v[3] - 2, v[1] + 2, v[2] + 4, v[3] + 2, "px_nether_wart", VINE_RED, f))
	end
	decor(lb(cf, "Moss", -8, 0.05, -2, 8, 0.35, 0, "px_crimson_nylium", nil, f))
	light(lc(cf, "BelfryGlow", 1, 1, 1, 0, 35, 12, GLOW_RED, Enum.Material.Neon, f), 18, 1.2, GLOW_RED)
end
task.wait()

-- ================================================================ street markings and broken asphalt
do
	local f = folder("StreetMarkings", town)
	local RING_C = { { -106, -114, 106, -114 }, { 106, -114, 106, 110 }, { 106, 110, -106, 110 }, { -106, 110, -106, -114 } }
	local segs = {}
	for _, s in ipairs(STREETS) do
		table.insert(segs, { s[1], s[2], s[3], s[4] })
	end
	for _, s in ipairs(RING_C) do
		table.insert(segs, s)
	end
	-- yellow dashes 8 long every 16 along every centre line (none near the rim)
	for _, s in ipairs(segs) do
		local ax, az, bx, bz = s[1], s[2], s[3], s[4]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		for i = 0, math.floor(len / 16) - 1 do
			local t0, t1 = (i * 16 + 4) / len, (i * 16 + 12) / len
			local x0, z0 = ax + (bx - ax) * t0, az + (bz - az) * t0
			local x1, z1 = ax + (bx - ax) * t1, az + (bz - az) * t1
			if onMain(x0, z0, 10) and onMain(x1, z1, 10) then
				local mid = V((x0 + x1) / 2, 0.075, (z0 + z1) / 2)
				local p = part("CentreLine", Vector3.new(0.8, 0.15, 8), CFrame.lookAt(mid, V(x1, 0.075, z1)), nil, nil, f)
				textured(decor(p), "px_yellow_wool", LINE_YELLOW)
			end
		end
	end
	-- heaved slabs, potholes and cracks off the centre lines
	for _ = 1, 22 do
		local s = pick(segs)
		local ax, az, bx, bz = s[1], s[2], s[3], s[4]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local t = rng:NextNumber(0.08, 0.92)
		local off = (if rng:NextNumber() < 0.5 then -1 else 1) * rng:NextNumber(4, 7)
		local x = ax + (bx - ax) * t - (bz - az) / len * off
		local z = az + (bz - az) * t + (bx - ax) / len * off
		if onMain(x, z, 14) and onStreet(x, z, -2) then
			local r = rng:NextNumber()
			local sx, sz = snap(x) + 2, snap(z) + 2
			if r < 0.4 then
				local p = part("BrokenAsphalt", Vector3.new(4, 1, 4), at(sx, 0.2, sz) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 1.5), rng:NextNumber(-0.25, 0.25)), nil, nil, f)
				textured(decor(p), "px_smooth_stone", ASPHALT)
			elseif r < 0.7 then
				decor(box("Pothole", sx - 2, -0.05, sz - 2, sx + 2, 0.07, sz + 2, "px_blackstone", Color3.fromRGB(60, 50, 56), f))
			else
				local p = part("Crack", Vector3.new(0.5, 0.08, rng:NextNumber(6, 12)), at(x, 0.04, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), nil, nil, f)
				textured(decor(p), "px_blackstone", Color3.fromRGB(40, 36, 40))
			end
		end
	end
end
task.wait()

-- ================================================================ the square round the mine
do
	local f = folder("Square", town)
	local E = 76
	-- the oak fence ring with stone-brick pillars; gaps at the four ladder shafts (4 blocks + 1 block margin)
	local function seg(ax, az, bx, bz, skipA, skipB)
		local alongX = az == bz
		local len = if alongX then math.abs(bx - ax) else math.abs(bz - az)
		for _, h in ipairs({ 1.4, 3 }) do
			if alongX then
				box("FenceRail", ax, h, az - 0.3, bx, h + 0.6, az + 0.3, "px_planks", C.oak, f)
			else
				box("FenceRail", ax - 0.3, h, az, ax + 0.3, h + 0.6, bz, "px_planks", C.oak, f)
			end
		end
		local n = math.floor(len / 8 + 0.5)
		for i = 0, n do
			local x, z = ax + (bx - ax) * i / n, az + (bz - az) * i / n
			if i % 2 == 0 then
				if not ((i == 0 and skipA) or (i == n and skipB)) then
					box("FencePillar", x - 2, 0, z - 2, x + 2, 6, z + 2, "px_stone_bricks", C.stone, f)
				end
			else
				box("FencePost", x - 0.6, 0, z - 0.6, x + 0.6, 4, z + 0.6, "px_planks", C.oak, f)
			end
		end
	end
	seg(-E, -84, -14, -84)
	seg(14, -84, E, -84)
	seg(-E, 68, -14, 68)
	seg(14, 68, E, 68)
	seg(-E, -84, -E, -22, true, false)
	seg(-E, 6, -E, 68, false, true)
	seg(E, -84, E, -22, true, false)
	seg(E, 6, E, 68, false, true)
	-- vine curtains hanging on the fence
	for _, v in ipairs({ { -50, -84, true }, { 38, -84, true }, { -E, -46, false }, { E, 30, false }, { -30, 68, true }, { E, -60, false } }) do
		if v[3] then
			decor(box("FenceVine", v[1] - 2, 0.6, v[2] - 0.7, v[1] + 2, 4, v[2] + 0.7, "px_nether_wart", VINE_RED, f))
		else
			decor(box("FenceVine", v[1] - 0.7, 0.6, v[2] - 2, v[1] + 0.7, 4, v[2] + 2, "px_nether_wart", VINE_DARK, f))
		end
	end
	-- lamp posts (warm lanterns)
	for _, l in ipairs({ { -86, -94, -math.pi / 2 }, { 56, -94, 0 }, { -86, 90, -math.pi / 2 }, { 86, 90, math.pi / 2 }, { -86, 14, -math.pi / 2 }, { 86, -30, math.pi / 2 } }) do
		lampPost(l[1], l[2], f, false, l[3])
		addOcc(l[1] - 3, l[2] - 3, l[1] + 3, l[2] + 3)
	end
	-- benches
	local function bench(x, z, alongX, back)
		local cf = at(x, 0, z) * CFrame.Angles(0, if alongX then 0 else math.pi / 2, 0)
		lb(cf, "BenchSeat", -4, 1.8, -1.2, 4, 2.4, 1.2, "px_spruce_planks", nil, f)
		lb(cf, "BenchBack", -4, 2.4, back * 1.2 - 0.25, 4, 4.6, back * 1.2 + 0.25, "px_spruce_planks", nil, f)
		for _, sx in ipairs({ -3.4, 3.4 }) do
			lb(cf, "BenchLeg", sx - 0.5, 0, -1.2, sx + 0.5, 1.8, 1.2, "px_dark_oak_planks", nil, f)
		end
		addOcc(x - 5, z - 5, x + 5, z + 5)
	end
	bench(-40, -97, true, -1)
	bench(36, -97, true, -1)
	bench(-88, 40, false, 1)
	bench(88, -56, false, 1)
	-- crates and barrels
	crate(-44, 0, 92, f)
	crate(-40, 0, 92, f, 4, 0.3)
	crate(-44, 4, 92, f, 3.4, 0.2)
	barrel(-36, 0, 93, f)
	barrel(62, 0, 92, f)
	crate(66, 0, 92, f, 4, 0.5)
	barrel(66, 0, 87, f, "px_nether_wart")
	crate(-88, 0, -74, f)
	barrel(-88, 0, -70, f)
	addOcc(-47, 89, -33, 96)
	addOcc(59, 84, 69, 95)
	addOcc(-91, -77, -85, -67)
	-- two dead trees (a cocoon hangs from the first)
	deadTree(-86, -56, 20, f, true)
	cocoon(at(-86, 3, -49) * CFrame.Angles(0, math.pi, 0), f)
	addOcc(-90, -60, -82, -52)
	deadTree(86, 36, 16, f, true)
	addOcc(82, 32, 90, 40)
	-- the overturned car in the north-east corner
	addOcc(78, -104, 94, -84)
	-- growth on the square: vine bushes, crimson carpets, ash, never on the ladder paths, the arrival or the stall
	local placed = 0
	for _ = 1, 400 do
		if placed >= 34 then
			break
		end
		local x, z = snap(rng:NextNumber(-92, 92)) + 2, snap(rng:NextNumber(-100, 96)) + 2
		local onPath = (math.abs(x) < 16 and (z > 50 or z < -78)) or (math.abs(z + 8) < 16 and math.abs(x) > 70)
		local nearSpawn = math.sqrt((x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2) < 16
		if not inPitArea(x, z, 8) and not onPath and not nearSpawn and not inRect(x, z, { 18, 70, 50, 98 }) and isFree(x, z, 4) then
			placed += 1
			local r = rng:NextNumber()
			if r < 0.3 then
				box("VineBush", x - 2, 0, z - 2, x + 2, 4, z + 2, "px_nether_wart", pick({ VINE_RED, VINE_DARK }), f)
			elseif r < 0.65 then
				local s = pick({ 4, 8 })
				decor(box("VineCarpet", x - s, 0, z - s / 2 - 2, x + s, 0.3, z + s / 2 + 2, "px_crimson_nylium", nil, f))
			else
				decor(box("Ash", x - 4, 0, z - 4, x + 4, 0.4, z + 4, "px_white_wool", ASH, f))
				if r > 0.85 then
					decor(box("Ash", x - 2, 0.4, z - 2, x + 2, 0.8, z + 2, "px_white_wool", ASH, f))
				end
			end
		end
	end
end
task.wait()

-- ================================================================ vehicles: the school bus, the overturned car, two wrecks
local function car(cf, paint, flipped, f)
	local c = folder(if flipped then "OverturnedCar" else "WreckedCar", f)
	local k = cf
	if flipped then
		k = cf * CFrame.new(0, 7.6, 0) * CFrame.Angles(0.06, 0, math.pi)
	end
	lb(k, "CarBody", -4, 1.4, -8, 4, 4.4, 8, "px_iron_block", paint, c)
	lb(k, "CarCabin", -3.6, 4.4, -3, 3.6, 7.4, 4.5, "px_iron_block", paint, c)
	decor(lb(k, "CarGlass", -3.8, 4.9, -2.6, 3.8, 7, 4.1, "px_blackstone", C.glass, c))
	decor(lb(k, "CarGlass", -3.1, 4.9, -3.2, 3.1, 7, 4.7, "px_blackstone", C.glass, c))
	decor(lb(k, "CarTrim", -4.2, 1.4, -8.4, 4.2, 2.4, 8.4, "px_iron_block", C.metal, c))
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -5, 5 }) do
			lb(k, "Wheel", sx * 3.6, 0, sz - 1.5, sx * 4.4, 3, sz + 1.5, "px_blackstone", C.tyre, c)
		end
		decor(lb(k, "Headlight", sx * 2.6 - 0.8, 2.8, -8.5, sx * 2.6 + 0.8, 3.6, -8.1, nil, Color3.fromRGB(210, 200, 170), c))
	end
	if not flipped then
		decor(lb(k, "CarMoss", -3, 7.4, -2, 1.5, 7.8, 3.5, "px_crimson_nylium", nil, c))
		decor(lb(k, "CarVine", 4, 2.5, -1, 4.6, 7.4, 3, "px_nether_wart", VINE_RED, c))
	else
		decor(lb(cf, "CarVine", 4.2, 0, -6, 8.2, 4, -2, "px_nether_wart", VINE_DARK, c))
		decor(lb(cf, "CarAsh", -9, 0, 2, -3, 0.4, 10, "px_white_wool", ASH, c))
	end
	return c
end
do
	local f = folder("Vehicles", town)
	-- the yellow school bus at the kerb of the ring road east (one block on the asphalt: a 4-block lane stays)
	do
		local cf = at(119, 0, 36) * CFrame.Angles(0, 0, 0.03)
		local b = folder("SchoolBus", f)
		local Y = C.bus
		local BLACK = Color3.fromRGB(26, 24, 28)
		lb(cf, "BusBody", -6, 2, -14, 6, 12, 20, "px_yellow_wool", Y, b)
		lb(cf, "BusRoof", -5.4, 12, -13.4, 5.4, 13, 19.4, "px_yellow_wool", Y, b)
		lb(cf, "BusHood", -5, 2, -20, 5, 8, -14, "px_yellow_wool", Y, b)
		decor(lb(cf, "BusGrille", -3.5, 3, -20.3, 3.5, 7, -20, "px_iron_block", C.metal, b))
		lb(cf, "BusBumper", -5.5, 1.6, -20.8, 5.5, 3, -20, "px_blackstone", C.tyre, b)
		lb(cf, "BusBumper", -6, 1.6, 20, 6, 3, 20.6, "px_blackstone", C.tyre, b)
		decor(lb(cf, "BusWindows", -6.2, 7, -12, 6.2, 10.6, 18.5, "px_blackstone", C.glass, b))
		decor(lb(cf, "BusWindshield", -5.4, 7, -14.3, 5.4, 11, -13.9, "px_blackstone", C.glass, b))
		decor(lb(cf, "BusRearWindow", -4.6, 7, 19.9, 4.6, 10.6, 20.3, "px_blackstone", C.glass, b))
		for _, z in ipairs({ -6.5, -1, 4.5, 10, 15.5 }) do
			decor(lb(cf, "BusPost", -6.35, 7, z - 0.5, 6.35, 10.6, z + 0.5, "px_yellow_wool", Y, b))
		end
		decor(lb(cf, "BusStripe", -6.15, 5.6, -14, 6.15, 6.2, 20.1, nil, BLACK, b))
		decor(lb(cf, "BusStripe", -6.15, 3.8, -14, 6.15, 4.3, 20.1, nil, BLACK, b))
		decor(lb(cf, "BusDoor", 6, 3, -13, 6.35, 11, -9, "px_blackstone", C.glass, b))
		lc(cf, "StopArm", 0.25, 2.4, 2.4, -6.5, 8.8, -11, Color3.fromRGB(190, 30, 30), Enum.Material.SmoothPlastic, b)
		for _, sx in ipairs({ -1, 1 }) do
			for _, z in ipairs({ -15.5, 13 }) do
				lb(cf, "BusWheel", sx * 5.4, 0, z - 2, sx * 6.6, 4.4, z + 2, "px_blackstone", C.tyre, b)
			end
			decor(lb(cf, "BusLight", sx * 3.8 - 0.8, 5.5, -20.3, sx * 3.8 + 0.8, 7, -20, nil, Color3.fromRGB(220, 210, 170), b))
		end
		local plate = decor(lb(cf, "BusSign", -4.5, 11.2, -14.45, 4.5, 12.7, -14.15, "px_yellow_wool", Color3.fromRGB(220, 150, 30), b))
		boardText(plate, "ШКОЛЬНЫЙ АВТОБУС", Color3.fromRGB(20, 18, 18), { Enum.NormalId.Front })
		-- overgrown and ash-covered
		decor(lb(cf, "BusMoss", -4, 13, 2, 3, 13.4, 14, "px_crimson_nylium", nil, b))
		decor(lb(cf, "BusVine", 1, 13, -10, 5, 16, -6, "px_nether_wart", VINE_RED, b))
		decor(lb(cf, "BusVine", 6.05, 5, 4, 6.7, 13, 8, "px_nether_wart", VINE_DARK, b))
		decor(lb(cf, "BusAsh", -5, 13, -12, -1, 13.3, -4, "px_white_wool", ASH, b))
		addOcc(112, 14, 126, 58)
	end
	car(at(86, 0, -94) * CFrame.Angles(0, 0.3, 0), Color3.fromRGB(200, 196, 186), true, f)
	car(at(-176, 0, 3.5) * CFrame.Angles(0, math.pi / 2 + 0.05, 0), Color3.fromRGB(120, 150, 170), false, f)
	addOcc(-186, -2, -166, 9)
	car(at(48, 0, 121) * CFrame.Angles(0, math.pi / 2 - 0.06, 0), Color3.fromRGB(170, 70, 60), false, f)
	addOcc(38, 115, 58, 127)
end
task.wait()

-- ================================================================ the alphabet wall and the bicycle (NNW, by the north street)
do
	local f = folder("AlphabetWall", town)
	addOcc(-26, -178, -18, -138)
	box("Wall", -24, 0, -172, -20, 16, -144, "px_planks", Color3.fromRGB(226, 196, 150), f)
	box("WallPillar", -25, 0, -176, -19, 20, -172, "px_red_brick", nil, f)
	box("WallPillar", -25, 0, -144, -19, 20, -140, "px_red_brick", nil, f)
	box("WallCoping", -24.5, 16, -172, -19.5, 17.5, -144, "px_red_brick", nil, f)
	-- the hand-painted letters in three rows
	for i, row in ipairs({ "A B C D E F G H", "I J K L M N O P Q", "R S T U V W X Y Z" }) do
		local y = 17 - i * 4
		local board = decor(part("Letters", Vector3.new(24, 3.4, 0.1), CFrame.lookAt(V(-19.94, y, -158), V(-10, y, -158)), nil, nil, f))
		board.Transparency = 1
		boardText(board, row, Color3.fromRGB(34, 22, 18), { Enum.NormalId.Front })
	end
	-- the Christmas lights: coloured bulbs on a sagging black wire between the pillars (four of them light up)
	do
		local a, b = V(-18.8, 19.4, -174), V(-18.8, 19.4, -142)
		local cols = {
			Color3.fromRGB(255, 40, 40),
			Color3.fromRGB(60, 220, 70),
			Color3.fromRGB(60, 110, 255),
			Color3.fromRGB(255, 220, 50),
			Color3.fromRGB(255, 140, 30),
		}
		local n = 11
		local prev = a
		for i = 1, n do
			local t = i / n
			local p = a:Lerp(b, t) - Vector3.new(0, math.sin(t * math.pi) * 2, 0)
			decor(beam("LightWire", prev, p, 0.15, C.wire, f))
			if i < n then
				local col = cols[(i - 1) % #cols + 1]
				decor(part("Socket", Vector3.new(0.6, 0.5, 0.6), CFrame.new(p - Vector3.new(0, 0.35, 0)), C.wire, nil, f))
				local bulb = decor(part("Bulb", Vector3.new(1, 1.3, 1), CFrame.new(p - Vector3.new(0, 1.2, 0)), col, Enum.Material.Neon, f))
				if i % 3 == 1 then
					light(bulb, 12, 1.4, col)
				end
			end
			prev = p
		end
	end
	-- vines over the south pillar and the coping, crimson moss at the foot of the wall
	decor(box("WallVine", -19, 4, -176, -18.4, 20, -172, "px_nether_wart", VINE_DARK, f))
	decor(box("WallVine", -25, 20, -176, -19, 24, -172, "px_nether_wart", VINE_RED, f))
	decor(box("WallVine", -19.6, 9, -171, -19, 17.5, -168, "px_nether_wart", VINE_RED, f))
	decor(box("WallVine", -24.5, 17.5, -160, -19.5, 18.5, -150, "px_crimson_nylium", nil, f))
	decor(box("WallMoss", -20, 0, -176, -16, 0.3, -158, "px_crimson_nylium", nil, f))
	-- the yard between the wall and house 6: a picket fence along the ring road, the bicycle leaning on it
	picket(at(0, 0, 0), "x", -134, -42, -26, f)
	addOcc(-43, -136, -25, -131)
	do
		local cfB = at(-33, 0, -132.7) * CFrame.Angles(-0.2, 0, 0)
		local RED = Color3.fromRGB(196, 32, 34)
		local BLACK = Color3.fromRGB(28, 26, 30)
		local bk = folder("Bicycle", f)
		local function wp(x, y)
			return (cfB * CFrame.new(x, y, 0)).Position
		end
		for _, wx in ipairs({ -2.3, 2.3 }) do
			lc(cfB, "Tyre", 2.8, 0.35, 0.3, wx, 2.625, 0, BLACK, nil, bk)
			lc(cfB, "Tyre", 2.8, 0.35, 0.3, wx, 0.175, 0, BLACK, nil, bk)
			lc(cfB, "Tyre", 0.35, 2.8, 0.3, wx - 1.225, 1.4, 0, BLACK, nil, bk)
			lc(cfB, "Tyre", 0.35, 2.8, 0.3, wx + 1.225, 1.4, 0, BLACK, nil, bk)
			lc(cfB, "Hub", 0.5, 0.5, 0.4, wx, 1.4, 0, C.metal, Enum.Material.Metal, bk)
		end
		for _, s in ipairs({
			{ -2.3, 1.4, 0, 1.2 },
			{ -2.3, 1.4, -0.8, 3.3 },
			{ 0, 1.2, -0.8, 3.3 },
			{ -0.8, 3.3, 1.8, 3.4 },
			{ 0, 1.2, 1.8, 3.4 },
			{ 1.8, 3.4, 2.3, 1.4 },
			{ 1.8, 3.4, 1.9, 3.9 },
		}) do
			decor(beam("Frame", wp(s[1], s[2]), wp(s[3], s[4]), 0.3, RED, bk))
		end
		lc(cfB, "Handlebar", 0.3, 0.3, 1.8, 1.9, 3.95, 0, BLACK, nil, bk)
		lc(cfB, "Saddle", 1.1, 0.3, 0.6, -0.9, 3.5, 0, BLACK, nil, bk)
		lc(cfB, "Pedal", 0.8, 0.2, 0.4, 0.2, 0.8, 0.45, BLACK, nil, bk)
	end
	-- a dead tree in the yard
	deadTree(-34, -160, 18, f, true)
	addOcc(-38, -164, -30, -156)
end
task.wait()

-- ================================================================ telephone poles, street lamps, hydrants, the town sign
do
	local f = folder("StreetProps", town)
	-- a dead telephone pole: a stone foot, a dark log pole, two cross-arms across the street, vines hanging off
	-- them; returns the two wire anchors at the ends of the top arm
	local function telePole(x, z, alongX, h)
		local p = folder("TelephonePole", f)
		box("PoleFoot", x - 2.5, 0, z - 2.5, x + 2.5, 3, z + 2.5, "px_stone_bricks", C.stone, p)
		box("Pole", x - 2, 3, z - 2, x + 2, h, z + 2, "px_dark_oak_log", C.bark, p)
		local ux, uz = if alongX then 0 else 1, if alongX then 1 else 0
		local function arm(half, y0, y1)
			box("CrossArm", x - ux * half - uz * 1.2, y0, z - uz * half - ux * 1.2, x + ux * half + uz * 1.2, y1, z + uz * half + ux * 1.2, "px_dark_oak_planks", C.bark, p)
		end
		arm(9, h - 3, h - 0.6)
		arm(6, h - 8, h - 5.6)
		for _ = 1, rng:NextInteger(1, 2) do
			local o = pick({ -7, -5, 5, 7 })
			local len = rng:NextInteger(6, 12)
			local vx, vz = x + ux * o, z + uz * o
			decor(box("PoleVine", vx - 1, h - 3 - len, vz - 1, vx + 1, h - 3, vz + 1, "px_nether_wart", pick({ VINE_RED, VINE_DARK }), p))
		end
		if rng:NextNumber() < 0.35 then
			decor(box("Transformer", x - ux * 3.5 - 1.5, h - 13, z - uz * 3.5 - 1.5, x - ux * 3.5 + 1.5, h - 8, z - uz * 3.5 + 1.5, "px_iron_block", C.metal, p))
		end
		if rng:NextNumber() < 0.5 then
			decor(box("PoleVine", x - 2.6, 0, z - 2.6, x + 2.6, rng:NextInteger(5, 9), z - 2.05, "px_nether_wart", VINE_DARK, p))
		end
		return { V(x - ux * 8.4, h - 0.4, z - uz * 8.4), V(x + ux * 8.4, h - 0.4, z + uz * 8.4) }
	end
	local function wire(a, b)
		local mid = (a + b) / 2 - Vector3.new(0, 1.6, 0)
		decor(beam("Wire", a, mid, 0.2, C.wire, f))
		decor(beam("Wire", mid, b, 0.2, C.wire, f))
	end
	local LINES = {
		{ true, { -200, -22 }, { -170, -22 }, { -140, -22 } }, -- the west street, north side
		{ true, { 126, 6 }, { 164, 6 }, { 200, 6 } }, -- the east street, south side
		{ false, { -14, -140 }, { -14, -172 } }, -- the north street, west side
		{ false, { 14, 140 }, { 14, 172 } }, -- the south street, east side
		{ false, { -122, -110 }, { -122, -70 }, { -122, -40 } }, -- the ring road, outside
		{ false, { -122, 30 }, { -122, 70 }, { -122, 104 } },
		{ false, { 122, -110 }, { 122, -70 }, { 122, -40 } },
		{ false, { 122, 74 }, { 122, 104 } },
		{ true, { -82, -128 }, { -46, -128 } },
		{ true, { 44, -128 }, { 88, -128 } },
		{ true, { -96, 124 }, { -62, 124 }, { -24, 124 } },
		{ true, { 26, 124 }, { 74, 124 } },
	}
	local poleAt = {}
	for _, line in ipairs(LINES) do
		local alongX = line[1]
		local prev = nil
		for i = 2, #line do
			local x, z = freeSpot(line[i][1], line[i][2], 2.5, if alongX then 1 else 0, if alongX then 0 else 1)
			if x then
				local anchors = telePole(x, z, alongX, 24 + rng:NextInteger(0, 1) * 4)
				addOcc(x - 2.5, z - 2.5, x + 2.5, z + 2.5)
				table.insert(poleAt, { x, z, alongX })
				if prev then
					wire(prev[1], anchors[1])
					wire(prev[2], anchors[2])
				end
				prev = anchors
			else
				prev = nil
			end
		end
	end
	-- cocoons on two poles (on the side away from the street)
	for _, c in ipairs({ { -122, -70, -1 }, { 122, -40, 1 } }) do
		for _, p in ipairs(poleAt) do
			if math.abs(p[1] - c[1]) < 20 and math.abs(p[2] - c[2]) < 20 then
				cocoon(at(p[1] + c[3] * 2, 5, p[2]) * CFrame.Angles(0, -c[3] * math.pi / 2, 0), f)
				break
			end
		end
	end
	-- a lone pole leaning over, its wires torn and hanging
	do
		local cf = at(196, 0, 100) * CFrame.Angles(0.22, 0.4, 0.1)
		local p = folder("TelephonePole", f)
		box("PoleFoot", 193.5, 0, 97.5, 198.5, 3, 102.5, "px_stone_bricks", C.stone, p)
		lb(cf, "Pole", -2, 0, -2, 2, 24, 2, "px_dark_oak_log", C.bark, p)
		lb(cf, "CrossArm", -1.2, 21, -9, 1.2, 23.4, 9, "px_dark_oak_planks", C.bark, p)
		decor(lb(cf, "PoleVine", -1, 12, 6, 1, 21, 8, "px_nether_wart", VINE_RED, p))
		for _, s in ipairs({ -8.4, 8.4 }) do
			local top = (cf * CFrame.new(0, 23.6, s)).Position
			decor(beam("TornWire", top, Vector3.new(top.X - 4, BY + 0.2, top.Z + s * 0.6), 0.2, C.wire, p))
		end
		addOcc(192, 96, 200, 104)
	end
	task.wait()
	-- street lamps (two dead and leaning)
	for _, l in ipairs({
		{ 14, -156, math.pi / 2, 0, 1 },
		{ -13, 156, -math.pi / 2, 0, 1 },
		{ -150, 6, 0, 1, 0 },
		{ 150, -22, math.pi, 1, 0 },
		{ -122, -130, math.pi, 1, 0 },
		{ 122, 124, 0, 1, 0 },
	}) do
		local x, z = freeSpot(l[1], l[2], 2.5, l[4], l[5])
		if x then
			lampPost(x, z, f, false, l[3])
			addOcc(x - 2.5, z - 2.5, x + 2.5, z + 2.5)
		end
	end
	for _, l in ipairs({ { -196, 6, 0, 0.3 }, { 196, -22, math.pi, -0.26 } }) do
		local x, z = freeSpot(l[1], l[2], 3, 1, 0)
		if x then
			local cf = at(x, 0, z) * CFrame.Angles(0, l[3], 0)
			lb(cf, "LampBase", -2, 0, -2, 2, 1, 2, "px_stone_bricks", nil, f)
			local tcf = cf * CFrame.new(0, 1, 0) * CFrame.Angles(l[4], 0, l[4] * 0.4)
			lb(tcf, "LampPost", -0.5, 0, -0.5, 0.5, 9, 0.5, "px_dark_oak_planks", nil, f)
			lb(tcf, "LampArm", -0.5, 8.5, -3.2, 0.5, 9.5, 0.5, "px_dark_oak_planks", nil, f)
			lc(tcf, "DeadLantern", 1.3, 1.5, 1.3, 0, 6.6, -2.8, Color3.fromRGB(45, 45, 50), Enum.Material.Metal, f)
			decor(lb(tcf, "LampVine", -0.9, 1, -0.9, 0.9, 6, -0.55, "px_nether_wart", VINE_RED, f))
			addOcc(x - 2.5, z - 2.5, x + 2.5, z + 2.5)
		end
	end
	-- fire hydrants
	for _, h in ipairs({ { -126, 8 }, { 126, -24 }, { 18, 166 } }) do
		local x, z = freeSpot(h[1], h[2], 1.5, 1, 0)
		if x then
			box("Hydrant", x - 0.8, 0, z - 0.8, x + 0.8, 2.4, z + 0.8, "px_iron_block", Color3.fromRGB(196, 50, 40), f)
			decor(box("HydrantCap", x - 1, 2.4, z - 1, x + 1, 2.9, z + 1, "px_iron_block", Color3.fromRGB(150, 36, 30), f))
			decor(box("HydrantNozzle", x - 1.3, 1.2, z - 0.4, x + 1.3, 1.8, z + 0.4, "px_iron_block", Color3.fromRGB(150, 36, 30), f))
			addOcc(x - 1.5, z - 1.5, x + 1.5, z + 1.5)
		end
	end
	-- the town sign by the south street (a made-up town)
	do
		box("SignPost", 19.4, 0, 145, 20.6, 9, 146.2, "px_dark_oak_planks", nil, f)
		box("SignPost", 19.4, 0, 157.8, 20.6, 9, 159, "px_dark_oak_planks", nil, f)
		local board = part("TownSign", Vector3.new(16, 5, 0.6), CFrame.lookAt(V(20, 7.5, 152), V(10, 7.5, 152)), nil, nil, f)
		textured(board, "px_spruce_planks", Color3.fromRGB(140, 168, 146))
		boardText(board, "Добро пожаловать\nв Тихий Дол")
		decor(box("SignVine", 19.2, 3, 154, 20.8, 10.2, 157, "px_nether_wart", VINE_RED, f))
		addOcc(18, 143, 22, 161)
	end
end
task.wait()

-- ================================================================ dead trees round the town and the growth on free ground
do
	local f = folder("Overgrowth", town)
	for _, t in ipairs({
		{ -114, -150 },
		{ 114, -150 },
		{ 190, -48 },
		{ -200, -90 },
		{ -200, 80 },
		{ 200, 70 },
		{ 60, -178 },
		{ 26, 176 },
		{ -26, 176 },
		{ -196, -110 },
		{ 196, 150 },
	}) do
		local x, z = t[1], t[2]
		if freeTown(x, z, 6) and isFree(x, z, 8) then
			deadTree(x, z, rng:NextInteger(4, 6) * 4, f, true)
			addOcc(x - 4, z - 4, x + 4, z + 4)
		end
	end
	task.wait()
	-- vine bushes (1–2 blocks), crimson carpets and ash piles on every free bit of town ground
	local placed = 0
	for _ = 1, 2400 do
		if placed >= 190 then
			break
		end
		local x, z = snap(rng:NextNumber(-212, 212)) + 2, snap(rng:NextNumber(-192, 192)) + 2
		if freeTown(x, z, 2) and isFree(x, z, 3) then
			placed += 1
			local r = rng:NextNumber()
			local tint = if rng:NextNumber() < 0.5 then VINE_RED else VINE_DARK
			if r < 0.4 then
				box("VineBush", x - 2, 0, z - 2, x + 2, 4, z + 2, "px_nether_wart", tint, f)
				if rng:NextNumber() < 0.4 then
					box("VineBush", x - 2, 4, z - 2, x + 2, 8, z + 2, "px_nether_wart", VINE_RED, f)
				elseif rng:NextNumber() < 0.5 then
					local ox = pick({ -4, 4 })
					box("VineBush", x + ox - 2, 0, z - 2, x + ox + 2, 4, z + 2, "px_nether_wart", VINE_DARK, f)
				end
				addOcc(x - 6, z - 6, x + 6, z + 6)
			elseif r < 0.7 then
				local sx, sz = pick({ 4, 8 }), pick({ 4, 8 })
				decor(box("VineCarpet", x - sx - 2, 0, z - sz - 2, x + sx + 2, 0.3, z + sz + 2, "px_crimson_nylium", nil, f))
			else
				decor(box("Ash", x - 4, 0, z - 4, x + 4, 0.4, z + 4, "px_white_wool", ASH, f))
				if r > 0.88 then
					decor(box("Ash", x - 2, 0.4, z - 2, x + 2, 0.8, z + 2, "px_white_wool", ASH, f))
				end
			end
		end
	end
end
print(("[build-inside-out] town: %d parts"):format(count - startCount))
