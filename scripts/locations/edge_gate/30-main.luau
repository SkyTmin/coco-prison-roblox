--!nocheck
-- ================================================================ edge_gate: the main island (the MAIN part)
-- The concept (assets/concepts/edge_gate/concept-v2.webp): a purpur fence with candles round the pit, end rods at its
-- corners; railless purpur bridges to the west and east islands; dark-wood huts with purpur trim, magenta banners and
-- lanterns, a shulker-box market with chests and barrels, a lore hut with the dragon egg by the north path; crystal
-- spires of black glass stepping up into magenta tips (a tall one by the west path); a purpur arch with a hanging
-- crystal over the east path; a ring of 10 obsidian pillars round a small plaza east of the pit; chorus bushes, end
-- stone boulders, purpur debris, end rods along the paths, candles. Every prop claims its footprint: in the MAIN zone,
-- 10 studs inside the island edge, off the paths, the pit area, the arrival, the buyer, the zone sign, the grand stair
-- corridor and the bridge decks, and off everything placed before it.
local mainF = folder("MainIsland")
local F = {
	fence = folder("PitFence", mainF),
	bridges = folder("Bridges", mainF),
	huts = folder("Huts", mainF),
	market = folder("ShulkerMarket", mainF),
	spires = folder("CrystalSpires", mainF),
	ring = folder("ObsidianRing", mainF),
	rods = folder("EndRods", mainF),
	nature = folder("ChorusAndStones", mainF),
}
local S = { lights = 0, skipped = 0, huts = 0, spires = 0, bushes = 0, rods = 0 }
local MAX_LIGHTS = 25
local COL = {
	glass = Color3.fromRGB(34, 28, 42),
	wax = Color3.fromRGB(240, 236, 226),
	flame = Color3.fromRGB(255, 214, 140),
	rod = Color3.fromRGB(236, 232, 240),
	rodTip = Color3.fromRGB(255, 240, 255),
	rodLight = Color3.fromRGB(235, 215, 255),
	shulkers = {
		Color3.new(1, 1, 1), -- purpur as drawn
		Color3.fromRGB(215, 180, 225),
		Color3.fromRGB(255, 160, 235), -- magenta
		Color3.fromRGB(120, 100, 135), -- dark
	},
	head = Color3.fromRGB(226, 222, 170),
	eye = Color3.fromRGB(30, 24, 36),
	chest = Color3.fromRGB(150, 105, 65),
	chestLid = Color3.fromRGB(125, 88, 55),
	iron = Color3.fromRGB(60, 60, 66),
	egg = Color3.fromRGB(18, 12, 26),
	speck = Color3.fromRGB(150, 60, 200),
	dark = Color3.fromRGB(40, 32, 52),
	roof = Color3.fromRGB(150, 130, 140),
	trim = Color3.fromRGB(200, 170, 205),
	stone = Color3.fromRGB(214, 212, 180),
	knob = Color3.fromRGB(255, 230, 255),
}
-- keep-outs besides the paths and the pit: the buyer's stall with its crate and barrel, the zone sign, the grand stair
-- corridor, both bridge decks
local KEEP = {
	{ 20, 154, 48, 182 },
	{ -22, 166, -6, 182 },
	{ -16, -84, 16, -60 },
	{ 84, -38, 170, -18 },
	{ -180, 28, -124, 48 },
}
local claims = {}

-- a box by two corners in the frame `cf` (world CFrame); look = px_* name or an Enum.Material
local function lbox(name, cf, x0, y0, z0, x1, y1, z1, look, tint, parent, isDecor)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(
		name,
		size,
		cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		tint,
		nil,
		parent
	)
	if type(look) == "string" then
		textured(p, look, tint)
	elseif look then
		p.Material = look
	end
	if isDecor then
		decor(p)
	end
	return p
end
-- a frame on the ground at local (x, z) whose −Z (the front) looks along (fx, fz)
local function faceCF(x, z, fx, fz, y)
	local p = V(x, y or 0, z)
	return CFrame.lookAt(p, p + Vector3.new(fx, 0, fz))
end
-- a point light, but never more than MAX_LIGHTS in this part
local function glow(p, range, brightness, color)
	if S.lights >= MAX_LIGHTS then
		return nil
	end
	S.lights += 1
	return light(p, range, brightness, color)
end

-- ================================================================ footprints
local function blocked(x, z, isPad)
	if zoneOf(x, z) ~= "main" or isleOf(x, z, isPad) ~= "main" then
		return true
	end
	if onPath(x, z, 2) or inPitArea(x, z, 4) then
		return true
	end
	if (x - SPAWN.x) ^ 2 + (z - SPAWN.z) ^ 2 <= 22 * 22 then
		return true
	end
	for _, k in ipairs(KEEP) do
		if inRect(x, z, k) then
			return true
		end
	end
	return false
end
local function clearArea(x0, z0, x1, z1, isPad)
	isPad = isPad or 10
	local nx, nz = math.max(1, math.ceil((x1 - x0) / 4)), math.max(1, math.ceil((z1 - z0) / 4))
	for i = 0, nx do
		for j = 0, nz do
			if blocked(x0 + (x1 - x0) * i / nx, z0 + (z1 - z0) * j / nz, isPad) then
				return false
			end
		end
	end
	for _, c in ipairs(claims) do
		if x0 < c[3] - 0.01 and x1 > c[1] + 0.01 and z0 < c[4] - 0.01 and z1 > c[2] + 0.01 then
			return false
		end
	end
	return true
end
local function take(x0, z0, x1, z1, isPad)
	if not clearArea(x0, z0, x1, z1, isPad) then
		return false
	end
	table.insert(claims, { x0, z0, x1, z1 })
	return true
end
-- claim a footprint (half sizes hx, hz) at (cx, cz) or a little nudge from it; returns the centre or nil
local NUDGE = {
	{ 0, 0 },
	{ 4, 0 },
	{ -4, 0 },
	{ 0, 4 },
	{ 0, -4 },
	{ 4, 4 },
	{ -4, -4 },
	{ 4, -4 },
	{ -4, 4 },
	{ 8, 0 },
	{ -8, 0 },
	{ 0, 8 },
	{ 0, -8 },
}
local function claimNear(cx, cz, hx, hz, isPad)
	for _, n in ipairs(NUDGE) do
		local x, z = cx + n[1], cz + n[2]
		if take(x - hx, z - hz, x + hx, z + hz, isPad) then
			return x, z
		end
	end
	S.skipped += 1
	return nil
end

-- ================================================================ block props (concept close-ups)
local P = {}
-- white candles (1–3) standing on y
function P.candles(x, y, z, f, n)
	local spots = { { 0, 0, 1.8 }, { 1.2, 0.7, 1.2 }, { -0.9, 1.1, 1.5 } }
	for i = 1, math.min(n or 1, 3) do
		local s = spots[i]
		decor(cube("Candle", x + s[1], y + s[3] / 2, z + s[2], 0.8, s[3], 0.8, nil, COL.wax, f))
		local fl = decor(
			cube(
				"CandleFlame",
				x + s[1],
				y + s[3] + 0.3,
				z + s[2],
				0.3,
				0.6,
				0.3,
				nil,
				COL.flame,
				f
			)
		)
		fl.Material = Enum.Material.Neon
	end
end
-- an end rod: a thin white rod on a small base with a glowing tip
function P.rod(x, y, z, f, lit, h)
	h = h or 5
	decor(cube("EndRodBase", x, y + 0.3, z, 1.6, 0.6, 1.6, nil, COL.rod, f))
	decor(cube("EndRod", x, y + 0.6 + h / 2, z, 0.6, h, 0.6, nil, COL.rod, f))
	local tip = decor(cube("EndRodTip", x, y + 0.6 + h + 0.4, z, 0.9, 0.8, 0.9, nil, COL.rodTip, f))
	tip.Material = Enum.Material.Neon
	if lit then
		glow(tip, 22, 0.9, COL.rodLight)
	end
	return tip
end
-- a chest on the ground frame cf (front = −Z)
function P.chest(cf, f)
	lbox("Chest", cf, -1.8, 0, -1.8, 1.8, 2.6, 1.8, "px_spruce_planks", COL.chest, f)
	lbox("ChestLid", cf, -1.9, 2.6, -1.9, 1.9, 3.6, 1.9, "px_spruce_planks", COL.chestLid, f)
	lbox(
		"ChestLatch",
		cf,
		-0.4,
		2.1,
		-2.05,
		0.4,
		3.1,
		-1.85,
		Enum.Material.Metal,
		COL.iron,
		f,
		true
	)
end
-- a shulker box (one block): a purpur shell with a lid line; an open one shows a pale head peeking out
function P.shulker(cf, tint, open, f)
	lbox("Shulker", cf, -2, 0, -2, 2, 2.6, 2, "px_purpur", tint, f)
	if open then
		lbox("ShulkerLid", cf, -2.1, 3.8, -2.1, 2.1, 5.2, 2.1, "px_purpur", tint, f, true)
		lbox(
			"ShulkerHead",
			cf,
			-1.2,
			2.6,
			-1.2,
			1.2,
			4.4,
			1.2,
			Enum.Material.SmoothPlastic,
			COL.head,
			f,
			true
		)
		for _, ex in ipairs({ -0.55, 0.55 }) do
			lbox(
				"ShulkerEye",
				cf,
				ex - 0.25,
				3,
				-1.3,
				ex + 0.25,
				3.5,
				-1.2,
				Enum.Material.SmoothPlastic,
				COL.eye,
				f,
				true
			)
		end
	else
		lbox("ShulkerLid", cf, -2.1, 2.6, -2.1, 2.1, 4, 2.1, "px_purpur", tint, f)
		lbox(
			"ShulkerSeam",
			cf,
			-2.15,
			2.5,
			-2.15,
			2.15,
			2.75,
			2.15,
			Enum.Material.SmoothPlastic,
			COL.dark,
			f,
			true
		)
	end
end
-- a stack of shulker boxes at local (x, z): `n` high, the top one open or not
function P.shulkers(x, z, n, openTop, f)
	local yaw = rng:NextInteger(0, 3) * math.pi / 2
	for k = 1, n do
		local cf = at(x, (k - 1) * B, z) * CFrame.Angles(0, yaw, 0)
		P.shulker(cf, pick(COL.shulkers), openTop and k == n, f)
	end
end
function P.glass(f, x0, y0, z0, x1, y1, z1)
	local p = box("BlackGlass", x0, y0, z0, x1, y1, z1, nil, COL.glass, f)
	p.Material = Enum.Material.Glass
	p.Reflectance = 0.05
	return p
end
function P.neon(f, x0, y0, z0, x1, y1, z1, col, isDecor)
	local p = box("Crystal", x0, y0, z0, x1, y1, z1, nil, col, f)
	p.Material = Enum.Material.Neon
	if isDecor then
		decor(p)
	end
	return p
end
-- a crystal spire of h blocks: a black glass skirt, a glass core into a magenta band and a crystal tip, satellite
-- columns round it (glass with a glowing block on top); opt: big, small, lit, banner = "S" | "E" | "W" | "N"
function P.spire(x, z, h, opt)
	local f = folder("CrystalSpire", F.spires)
	local y = 0
	if opt.big then
		P.glass(f, x - 10, 0, z - 10, x + 10, 4, z + 10)
		P.glass(f, x - 6, 4, z - 6, x + 6, 8, z + 6)
		y = 8
	elseif not opt.small then
		P.glass(f, x - 6, 0, z - 6, x + 6, 4, z + 6)
		y = 4
	end
	local cw = if opt.small then 2 else 4
	local top = h * B
	local glassTop = math.max(y + B, math.floor(h / 2) * B)
	P.glass(f, x - cw, y, z - cw, x + cw, glassTop, z + cw)
	P.neon(f, x - cw, glassTop, z - cw, x + cw, glassTop + B, z + cw, MAGENTA)
	local tip = P.neon(f, x - 2, glassTop + B, z - 2, x + 2, top, z + 2, CRYSTAL)
	P.neon(f, x - 1, top, z - 1, x + 1, top + 2, z + 1, CRYSTAL, true)
	if opt.lit then
		glow(tip, 30, 1.2, CRYSTAL)
	end
	-- satellite columns (tops never flush with the skirt)
	local sats = if opt.big
		then { { 8, -4 }, { -8, 4 }, { 4, 8 }, { -4, -8 }, { 8, 8 }, { -8, -8 } }
		elseif opt.small then { { 4, 0 }, { -2, 4 } }
		else { { 6, -2 }, { -6, 2 }, { 2, 6 }, { -2, -6 } }
	local minH = if opt.small then 2 else 3
	for _, s in ipairs(sats) do
		local hs = rng:NextInteger(minH, math.max(minH, math.floor(h * 0.6)))
		local sx, sz = x + s[1], z + s[2]
		P.glass(f, sx - 2, 0, sz - 2, sx + 2, (hs - 1) * B, sz + 2)
		P.neon(
			f,
			sx - 2,
			(hs - 1) * B,
			sz - 2,
			sx + 2,
			hs * B,
			sz + 2,
			if rng:NextNumber() < 0.5 then MAGENTA else CRYSTAL
		)
	end
	if opt.banner then
		local side = ({ S = { 0, 1 }, N = { 0, -1 }, E = { 1, 0 }, W = { -1, 0 } })[opt.banner]
		local d = cw + 0.3
		-- shifted half a core sideways, off the satellite column on that side
		local px, pz = if opt.big then 0 else -side[2] * 2, if opt.big then 0 else side[1] * 2
		local cf = at(x + side[1] * d + px, glassTop - 4, z + side[2] * d + pz)
			* CFrame.Angles(0, if side[1] ~= 0 then math.pi / 2 else 0, 0)
		banner(cf, MAGENTA, f, OBSIDIAN)
	end
	S.spires += 1
	return f
end
-- a chorus bush: a stalk of chorus blocks with one or two side branches and pale knobs on top
function P.chorus(x, z, f)
	local g = folder("ChorusBush", f)
	local hgt = rng:NextInteger(2, 4)
	box("ChorusStalk", x - 2, 0, z - 2, x + 2, hgt * B, z + 2, "px_chorus", nil, g)
	cube("ChorusKnob", x, hgt * B + 1.5, z, 3, 3, 3, "px_purpur", COL.knob, g)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local first = rng:NextInteger(1, 4)
	for k = 0, rng:NextInteger(0, 1) do
		local d = dirs[(first + k * 2 - 1) % 4 + 1] -- opposite sides
		local lvl = rng:NextInteger(1, math.max(1, hgt - 1))
		local up = rng:NextInteger(1, 2)
		local bx, bz = x + d[1] * B, z + d[2] * B
		box(
			"ChorusBranch",
			bx - 2,
			lvl * B - B,
			bz - 2,
			bx + 2,
			(lvl + up) * B,
			bz + 2,
			"px_chorus",
			nil,
			g
		)
		decor(
			cube(
				"ChorusKnob",
				bx,
				(lvl + up) * B + 1.2,
				bz,
				2.4,
				2.4,
				2.4,
				"px_purpur",
				COL.knob,
				g
			)
		)
	end
	-- the branch stands on a block of its own from lvl − 1, so it reads as a bent stalk
	return g
end
-- an end stone boulder: a sunk block with a smaller one on top and one leaning on its side
function P.boulder(x, z, f)
	local g = folder("Boulder", f)
	box("EndStone", x - 4, -1, z - 4, x + 4, 3, z + 4, "px_end_stone", COL.stone, g)
	local ox, oz = pick({ -2, 2 }), pick({ -2, 2 })
	box("EndStone", x + ox - 2, 3, z + oz - 2, x + ox + 2, 7, z + oz + 2, "px_end_stone", nil, g)
	local sx = pick({ -1, 1 })
	box("EndStone", x + sx * 4, -1, z - 2, x + sx * 8, 2, z + 2, "px_end_stone", COL.stone, g)
end
-- purpur debris: a fallen purpur block half sunk, sometimes a second one on it
function P.debris(x, z, f)
	box(
		"PurpurDebris",
		x - 2,
		-1.5,
		z - 2,
		x + 2,
		2.5,
		z + 2,
		pick({ "px_purpur", "px_purpur", "px_purpur_pillar" }),
		nil,
		f
	)
	if rng:NextNumber() < 0.35 then
		box("PurpurDebris", x - 2, 2.5, z - 2, x + 2, 4.5, z + 2, "px_purpur", COL.trim, f)
	end
end
-- a 2×2-block obsidian pillar hb blocks tall; broken = a jagged stub and a fallen block toward (rx, rz)
function P.pillar(x, z, hb, broken, crystal, rx, rz)
	local f = folder("ObsidianPillar", F.ring)
	local top = hb * B
	box("Obsidian", x - 4, -2, z - 4, x + 4, top, z + 4, "px_obsidian", nil, f)
	if broken then
		local sx, sz = pick({ -1, 1 }), pick({ -1, 1 })
		box(
			"ObsidianStub",
			x + math.min(0, sx * 4),
			top,
			z + math.min(0, sz * 4),
			x + math.max(0, sx * 4),
			top + B,
			z + math.max(0, sz * 4),
			"px_obsidian",
			nil,
			f
		)
		box("ObsidianRubble", rx - 2, -1.5, rz - 2, rx + 2, 2.5, rz + 2, "px_obsidian", nil, f)
	else
		box(
			"ObsidianCap",
			x - 3,
			top,
			z - 3,
			x + 3,
			top + 1,
			z + 3,
			"px_obsidian",
			Color3.fromRGB(190, 170, 210),
			f
		)
		if crystal then
			P.neon(f, x - 1.2, top + 1, z - 1.2, x + 1.2, top + 3.4, z + 1.2, CRYSTAL, true)
		end
	end
end
-- a dark-wood hut (front = the door, toward (fx, fz)): end stone base, dark oak log corners, dark oak plank walls,
-- a purpur trim band (also the ceiling), black glass windows in purpur frames, a stepped roof with a purpur cap, a
-- magenta banner and a lantern at the front, a chest and a barrel inside; returns the folder and the frame
function P.hut(cx, cz, fx, fz, opt)
	local w, d, dw = opt.w, opt.d, opt.door or B
	local hw, hd = w / 2, d / 2
	local WALL = 12
	local f = folder(opt.name or "Hut", F.huts)
	local cf = faceCF(cx, cz, fx, fz)
	lbox("HutBase", cf, -hw - 1, -2, -hd - 1, hw + 1, 1, hd + 1, "px_end_stone_bricks", nil, f)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			lbox(
				"HutPost",
				cf,
				sx * hw,
				1,
				sz * hd,
				sx * (hw - 2),
				WALL + 1,
				sz * (hd - 2),
				"px_dark_oak_log",
				nil,
				f
			)
		end
		lbox(
			"HutWall",
			cf,
			sx * hw,
			1,
			-hd + 2,
			sx * (hw - 1),
			WALL + 1,
			hd - 2,
			"px_dark_oak_planks",
			nil,
			f
		)
		-- a black glass window in a purpur frame on each side wall
		lbox(
			"HutWindowFrame",
			cf,
			sx * (hw - 0.2),
			4.5,
			-3,
			sx * (hw + 0.3),
			9.5,
			3,
			"px_purpur",
			nil,
			f,
			true
		)
		lbox(
			"HutWindow",
			cf,
			sx * (hw - 0.4),
			5.5,
			-2,
			sx * (hw + 0.4),
			8.5,
			2,
			Enum.Material.Glass,
			COL.glass,
			f,
			true
		)
	end
	lbox("HutWall", cf, -hw + 2, 1, hd - 1, hw - 2, WALL + 1, hd, "px_dark_oak_planks", nil, f)
	lbox("HutWall", cf, -hw + 2, 1, -hd, -dw / 2, WALL + 1, -hd + 1, "px_dark_oak_planks", nil, f)
	lbox("HutWall", cf, dw / 2, 1, -hd, hw - 2, WALL + 1, -hd + 1, "px_dark_oak_planks", nil, f)
	lbox("HutLintel", cf, -dw / 2, 9, -hd, dw / 2, WALL + 1, -hd + 1, "px_dark_oak_planks", nil, f)
	lbox(
		"HutTrim",
		cf,
		-hw - 0.3,
		WALL - 1,
		-hd - 0.3,
		hw + 0.3,
		WALL + 1,
		hd + 0.3,
		"px_purpur",
		nil,
		f
	)
	-- the stepped roof
	local y, lw, ld = WALL + 1, w + 4, d + 4
	while lw >= 4 and ld >= 4 do
		lbox(
			"HutRoof",
			cf,
			-lw / 2,
			y,
			-ld / 2,
			lw / 2,
			y + 2,
			ld / 2,
			"px_dark_oak_planks",
			COL.roof,
			f
		)
		y += 2
		lw -= 6
		ld -= 6
	end
	lbox("HutCap", cf, -2, y, -2, 2, y + 2, 2, "px_purpur_pillar", nil, f)
	-- the banner on the left of the door, the lantern on the right
	local side = hw - 2 - dw / 2
	local bw = math.min(B, side - 0.4)
	if bw >= 1.5 then
		banner(cf * CFrame.new(-(dw / 2 + side / 2), 6.2, -hd - 0.35), MAGENTA, f, COL.dark, bw, 7)
	end
	local lf = folder("Lantern", f)
	lantern((cf * CFrame.new(dw / 2 + side / 2, 9, -hd - 1.8)).Position, lf, false, BY + WALL + 1)
	S.lights += 1
	if S.lights > MAX_LIGHTS then
		for _, l in ipairs(lf:GetDescendants()) do
			if l:IsA("PointLight") then
				l:Destroy()
			end
		end
	end
	if not opt.lore then
		P.chest(cf * CFrame.new(hw - 4, 1, hd - 3.5), f)
		local bp = (cf * CFrame.new(-hw + 4, 0, hd - 3.5)).Position
		barrel(bp.X - BX, 1, bp.Z - BZ, f, opt.goods)
	end
	S.huts += 1
	return f, cf
end

-- ================================================================ the fence round the pit
-- purpur pillar posts every 3 blocks with a white candle on each, two purpur rails, on the ring path's inner edge
-- (x ±74, z −2 and z 146); open at the ladder shafts (north x −12..12, west / east z 60..84) and wider in the south
-- (x −24..24, ≥ 31 studs from the arrival); the corner posts are taller and carry end rods
do
	local corners = { { -74, -2 }, { 74, -2 }, { -74, 146 }, { 74, 146 } }
	local runs = {
		{ -74, -2, -14, -2 },
		{ 14, -2, 74, -2 },
		{ -74, 146, -26, 146 },
		{ 26, 146, 74, 146 },
		{ -74, -2, -74, 58 },
		{ -74, 86, -74, 146 },
		{ 74, -2, 74, 58 },
		{ 74, 86, 74, 146 },
	}
	local function isCorner(x, z)
		for _, c in ipairs(corners) do
			if math.abs(c[1] - x) < 0.5 and math.abs(c[2] - z) < 0.5 then
				return true
			end
		end
		return false
	end
	for _, r in ipairs(runs) do
		local ax, az, bx, bz = r[1], r[2], r[3], r[4]
		local len = math.abs(bx - ax) + math.abs(bz - az)
		local n = math.max(1, math.floor(len / 12 + 0.5))
		for i = 0, n do
			local x, z = ax + (bx - ax) * i / n, az + (bz - az) * i / n
			if not isCorner(x, z) then
				box("FencePost", x - 2, 0, z - 2, x + 2, 8, z + 2, "px_purpur_pillar", nil, F.fence)
				P.candles(x, 8, z, F.fence, 1)
			end
		end
		for _, rl in ipairs({ { 5, 7, 1 }, { 1.5, 3, 0.8 } }) do
			if az == bz then
				box(
					"FenceRail",
					math.min(ax, bx),
					rl[1],
					az - rl[3],
					math.max(ax, bx),
					rl[2],
					az + rl[3],
					"px_purpur",
					nil,
					F.fence
				)
			else
				box(
					"FenceRail",
					ax - rl[3],
					rl[1],
					math.min(az, bz),
					ax + rl[3],
					rl[2],
					math.max(az, bz),
					"px_purpur",
					nil,
					F.fence
				)
			end
		end
	end
	for _, c in ipairs(corners) do
		box(
			"FenceCorner",
			c[1] - 2,
			0,
			c[2] - 2,
			c[1] + 2,
			12,
			c[2] + 2,
			"px_purpur_pillar",
			nil,
			F.fence
		)
		box(
			"FenceCornerCap",
			c[1] - 2.5,
			12,
			c[2] - 2.5,
			c[1] + 2.5,
			13,
			c[2] + 2.5,
			"px_purpur",
			nil,
			F.fence
		)
		P.rod(c[1], 13, c[2], F.fence, true, 6)
	end
	-- a low end stone brick kerb with gaps on the south rim, clear of the south ladder approach
	for _, k in ipairs({ { -64, -52 }, { -48, -36 }, { 36, 48 }, { 52, 64 } }) do
		box("RimKerb", k[1], 0.4, 138, k[2], 1.6, 140, "px_end_stone_bricks", nil, F.fence)
	end
end
task.wait()

-- ================================================================ the bridges
-- railless purpur decks (one block, top at y 0.1) over each BRIDGES rectangle, a purpur-pillar band every 4th block;
-- under the gap: slab trims along both edges, a cross beam and a purpur pillar hanging down as a stalactite; end rod
-- posts beside the deck where it leaves each island (the gap measured along the deck's centre line)
do
	for bi, b in ipairs(BRIDGES) do
		local x0, z0, x1, z1 = b[1], b[2], b[3], b[4]
		local zm = (z0 + z1) / 2
		local f = folder(if bi == 1 then "WestBridge" else "EastBridge", F.bridges)
		local segs, xi, k = {}, x0, 0
		while xi < x1 - 0.01 do
			local xe = math.min(xi + B, x1)
			local v = if k % 4 == 2 then "px_purpur_pillar" else "px_purpur"
			local last = segs[#segs]
			if last and last[3] == v then
				last[2] = xe
			else
				table.insert(segs, { xi, xe, v })
			end
			xi = xe
			k += 1
		end
		for _, s in ipairs(segs) do
			box("BridgeDeck", s[1], 0.1 - B, z0, s[2], 0.1, z1, s[3], nil, f)
		end
		-- the gap (the longest run of void along the centre line)
		local ga, gb, best, runA = nil, nil, -1, nil
		for xs = x0, x1, 2 do
			if isleOf(xs, zm) == nil then
				runA = runA or xs
				if xs - runA > best then
					best, ga, gb = xs - runA, runA, xs
				end
			else
				runA = nil
			end
		end
		if not ga then
			ga, gb = (x0 + x1) / 2 - 4, (x0 + x1) / 2 + 4
		end
		local under = 0.1 - B
		for _, e in ipairs({ { z0 - 1, z0 + 2 }, { z1 - 2, z1 + 1 } }) do
			box(
				"BridgeTrim",
				ga - 4,
				under - 2,
				e[1],
				gb + 4,
				under,
				e[2],
				"px_purpur",
				COL.trim,
				f
			)
		end
		local mx = snap((ga + gb) / 2)
		box("BridgeBeam", mx - 2, under - 4, z0 - 0.5, mx + 2, under, z1 + 0.5, "px_purpur", nil, f)
		box(
			"BridgePillar",
			mx - 4,
			-20,
			zm - 4,
			mx + 4,
			under - 4,
			zm + 4,
			"px_purpur_pillar",
			nil,
			f
		)
		box("BridgePillar", mx - 2, -34, zm - 2, mx + 2, -20, zm + 2, "px_purpur_pillar", nil, f)
		box("BridgeStalactite", mx - 1, -42, zm - 1, mx + 1, -34, zm + 1, "px_purpur", COL.trim, f)
		-- end rod posts on the island lips at both ends of the gap, both sides of the deck
		for gi, g in ipairs({ { ga - 6, -1 }, { gb + 6, 1 } }) do
			for si, zs in ipairs({ z0 - 2, z1 + 2 }) do
				local gx = g[1]
				for _ = 1, 4 do
					if isleOf(gx, zs) ~= nil then
						break
					end
					gx += g[2] * 4
				end
				box("BridgePost", gx - 2, -2, zs - 2, gx + 2, 4, zs + 2, "px_purpur_pillar", nil, f)
				P.rod(gx, 4, zs, f, si == gi, 5)
			end
		end
	end
end
task.wait()

-- ================================================================ the purpur arch over the east path
-- two purpur pillars beside the deck at x 96 (z −40..−36 and −20..−16), a lintel at y 16..20 with a stepped crown,
-- brackets under it, a magenta crystal hanging on a chain over the path, banners toward the ring
do
	local f = folder("EastArch", mainF)
	local ax = 96
	for _, zc in ipairs({ -38, -18 }) do
		box("ArchPillar", ax - 2, -4, zc - 2, ax + 2, 16, zc + 2, "px_purpur_pillar", nil, f)
		banner(at(ax - 2.3, 9, zc) * CFrame.Angles(0, math.pi / 2, 0), MAGENTA, f, OBSIDIAN, 3, 7)
	end
	box("ArchLintel", ax - 2, 16, -40, ax + 2, 20, -16, "px_purpur", nil, f)
	box("ArchBracket", ax - 2, 12, -36, ax + 2, 16, -32, "px_purpur", nil, f)
	box("ArchBracket", ax - 2, 12, -24, ax + 2, 16, -20, "px_purpur", nil, f)
	box("ArchCrown", ax - 2, 20, -34, ax + 2, 24, -22, "px_purpur_pillar", nil, f)
	box("ArchCrown", ax - 2, 24, -30, ax + 2, 28, -26, "px_purpur", nil, f)
	decor(cube("ArchChain", ax, 14.25, -28, 0.3, 3.5, 0.3, nil, COL.iron, f)).Material =
		Enum.Material.Metal
	local crystal = P.neon(f, ax - 1, 9.5, -29, ax + 1, 12.5, -27, CRYSTAL, true)
	P.neon(f, ax - 0.5, 8, -28.5, ax + 0.5, 9.5, -27.5, MAGENTA, true)
	glow(crystal, 26, 1.1, CRYSTAL)
	table.insert(claims, { 93, -41, 99, -15 })
end

-- ================================================================ huts and stalls
do
	local HUTS = {
		-- the lore hut by the north path (west side), its wide door toward the path: the dragon egg inside
		{
			name = "LoreHut",
			x = -36,
			z = -44,
			fx = 1,
			fz = 0,
			w = 16,
			d = 16,
			door = 8,
			lore = true,
		},
		{
			name = "ShulkerHut",
			x = 38,
			z = -44,
			fx = -1,
			fz = 0,
			w = 16,
			d = 12,
			goods = "px_purpur",
		},
		{
			name = "WestHutNorth",
			x = -110,
			z = 6,
			fx = 1,
			fz = 0,
			w = 16,
			d = 12,
			goods = "px_chorus",
		},
		{
			name = "WestHutMiddle",
			x = -114,
			z = 96,
			fx = 1,
			fz = 0,
			w = 16,
			d = 12,
			goods = "px_end_stone",
		},
		{ name = "WestHutSouth", x = -110, z = 134, fx = 1, fz = 0, w = 12, d = 12 },
		{
			name = "EastHut",
			x = 114,
			z = 22,
			fx = -1,
			fz = 0,
			w = 16,
			d = 12,
			goods = "px_obsidian",
		},
	}
	for _, h in ipairs(HUTS) do
		local hx, hz
		if h.fx ~= 0 then
			hx, hz = h.d / 2 + 3, h.w / 2 + 3
		else
			hx, hz = h.w / 2 + 3, h.d / 2 + 3
		end
		local x, z = claimNear(h.x, h.z, hx, hz, 10)
		if x then
			local f, cf = P.hut(x, z, h.fx, h.fz, h)
			if h.lore then
				-- the dragon egg: a black block with purple speckles on a purpur pillar pedestal, candles round it
				local hd = h.d / 2
				local ecf = cf * CFrame.new(0, 1, hd - 5)
				lbox("EggPedestal", ecf, -2, 0, -2, 2, 4, 2, "px_purpur_pillar", nil, f)
				lbox(
					"DragonEgg",
					ecf,
					-1.5,
					4,
					-1.5,
					1.5,
					7,
					1.5,
					Enum.Material.SmoothPlastic,
					COL.egg,
					f
				)
				lbox(
					"DragonEggTop",
					ecf,
					-1,
					7,
					-1,
					1,
					8,
					1,
					Enum.Material.SmoothPlastic,
					COL.egg,
					f
				)
				for _, s in ipairs({
					{ -0.6, 5, -1 },
					{ 0.7, 6.2, -1 },
					{ 0.2, 7.4, -1 },
					{ -0.7, 5.6, 1 },
					{ 0.6, 4.6, 1 },
				}) do
					local zz = s[3] * 1.55
					lbox(
						"EggSpeck",
						ecf,
						s[1] - 0.3,
						s[2] - 0.3,
						zz - 0.05,
						s[1] + 0.3,
						s[2] + 0.3,
						zz + 0.05,
						Enum.Material.Neon,
						COL.speck,
						f,
						true
					)
				end
				for _, s in ipairs({ { -1.55, 5.4, 0.4 }, { 1.55, 6.4, -0.5 } }) do
					lbox(
						"EggSpeck",
						ecf,
						s[1] - 0.05,
						s[2] - 0.3,
						s[3] - 0.3,
						s[1] + 0.05,
						s[2] + 0.3,
						s[3] + 0.3,
						Enum.Material.Neon,
						COL.speck,
						f,
						true
					)
				end
				for _, c in ipairs({ { -3.5, -3 }, { 3.5, -3 }, { -3.5, 2.5 }, { 3.5, 2.5 } }) do
					local p = (ecf * CFrame.new(c[1], 0, c[2])).Position
					P.candles(p.X - BX, 1, p.Z - BZ, f, 2)
				end
				local board = lbox(
					"LoreBoard",
					cf,
					-3.5,
					8.6,
					hd - 1.4,
					3.5,
					10.4,
					hd - 1.1,
					"px_spruce_planks",
					nil,
					f
				)
				boardText(
					board,
					"Яйцо дракона",
					Color3.fromRGB(235, 200, 245),
					{ Enum.NormalId.Front }
				)
				P.chest(
					cf * CFrame.new(h.w / 2 - 3, 1, -hd + 4) * CFrame.Angles(0, -math.pi / 2, 0),
					f
				)
				P.shulker(cf * CFrame.new(-h.w / 2 + 3, 1, -hd + 4), COL.shulkers[4], false, f)
			end
		end
	end

	-- stalls: a shulker stall in the west strip, a chest stall in the east strip (both toward the ring path)
	for _, s in ipairs({
		{
			x = -110,
			z = 116,
			fx = 1,
			sign = "Шалкеры",
			goods = { "px_purpur", "px_chorus", "px_purpur_pillar", "px_end_stone" },
		},
		{
			x = 112,
			z = 46,
			fx = -1,
			sign = "Сундуки",
			goods = { "px_dark_oak_planks", "px_purpur", "px_iron_block" },
		},
	}) do
		local x, z = claimNear(s.x, s.z, 6, 8, 10)
		if x then
			stall(faceCF(x, z, s.fx, 0), {
				w = 3 * B,
				d = 2 * B,
				colA = MAGENTA,
				colB = COL.dark,
				goods = s.goods,
				sign = s.sign,
			}, F.market)
		end
	end

	-- the shulker market: stacks of shulker boxes (x, z, high, open top), chests, barrels and crates
	local SHULKERS = {
		-- north-east, round the shulker hut
		{ 22, -28, 2, true },
		{ 28, -28, 1, false },
		{ 34, -28, 2, false },
		{ 40, -28, 1, true },
		{ 46, -28, 1, false },
		{ 52, -28, 2, false },
		{ 21, -40, 1, false },
		{ 21, -46, 2, true },
		{ 21, -52, 1, false },
		-- west, between the north hut and the west path
		{ -100, 22, 2, false },
		{ -106, 21, 1, true },
		{ -112, 22, 1, false },
		{ -118, 21, 2, true },
		{ -124, 6, 1, false },
		-- east, by the east hut
		{ 104, 6, 1, true },
		{ 110, 6, 2, false },
		-- west south, by the stall
		{ -100, 128, 1, false },
		{ -100, 140, 2, true },
	}
	for _, s in ipairs(SHULKERS) do
		local x, z = claimNear(s[1], s[2], 2.5, 2.5, 10)
		if x then
			P.shulkers(x, z, s[3], s[4], F.market)
		end
	end
	for _, c in ipairs({
		{ 27, -36, math.pi / 2 },
		{ -98, 2, -math.pi / 2 },
		{ 126, 36, math.pi / 2 },
		{ -98, 100, -math.pi / 2 },
	}) do
		local x, z = claimNear(c[1], c[2], 2.5, 2.5, 10)
		if x then
			P.chest(at(x, 0, z) * CFrame.Angles(0, c[3], 0), F.market)
		end
	end
	for _, c in ipairs({
		{ 26, -52 },
		{ -98, -8 },
		{ 102, 34 },
		{ -100, 110 },
		{ -100, 120 },
		{ 60, -34 },
	}) do
		local x, z = claimNear(c[1], c[2], 2.5, 2.5, 10)
		if x then
			barrel(
				x,
				0,
				z,
				F.market,
				if rng:NextNumber() < 0.65 then pick({ "px_chorus", "px_purpur" }) else nil
			)
		end
	end
	for _, c in ipairs({ { 102, 40 }, { -98, -14 }, { 32, -58 } }) do
		local x, z = claimNear(c[1], c[2], 2.5, 2.5, 10)
		if x then
			crate(x, 0, z, F.market)
			if rng:NextNumber() < 0.5 then
				crate(x, B, z, F.market, 3, rng:NextNumber() * 0.4)
			end
		end
	end
end
task.wait()

-- ================================================================ crystal spires
do
	local SPIRES = {
		{ -118, 64, 12, { big = true, lit = true, banner = "E" } }, -- the landmark by the west path
		{ -70, -32, 7, { lit = true, banner = "S" } }, -- north-west
		{ 66, -32, 6, { lit = true } }, -- north-east
		{ 132, 64, 8, { lit = true, banner = "W" } }, -- east
		{ 104, 148, 6, { lit = true } }, -- south-east
		{ -40, 198, 5, { small = true } }, -- the south lawn
		{ 44, 198, 4, { small = true } },
		{ -104, 154, 5, { small = true } }, -- south-west
	}
	for _, s in ipairs(SPIRES) do
		local o = s[4]
		local half = if o.big then 13 elseif o.small then 7 else 9
		local x, z = claimNear(s[1], s[2], half, half, 10)
		if x then
			P.spire(x, z, s[3], o)
		end
	end
end
task.wait()

-- ================================================================ the ring of 10 obsidian pillars
-- 2×2-block pillars 3–7 blocks tall (some broken, two with a small crystal) round a little end stone brick plaza
-- with an obsidian altar and a crystal, east of the pit's south half (centre (117, 100), radius 18); decor, untagged
do
	local cx, cz = claimNear(117, 100, 22, 22, 4)
	if cx then
		box(
			"RingPlaza",
			cx - 12,
			0,
			cz - 8,
			cx + 12,
			0.2,
			cz + 8,
			"px_end_stone_bricks",
			nil,
			F.ring
		)
		box(
			"RingPlaza",
			cx - 8,
			0,
			cz - 12,
			cx + 8,
			0.2,
			cz - 8,
			"px_end_stone_bricks",
			nil,
			F.ring
		)
		box(
			"RingPlaza",
			cx - 8,
			0,
			cz + 8,
			cx + 8,
			0.2,
			cz + 12,
			"px_end_stone_bricks",
			nil,
			F.ring
		)
		box("RingAltar", cx - 2, 0, cz - 2, cx + 2, 4, cz + 2, "px_obsidian", nil, F.ring)
		local c = P.neon(F.ring, cx - 1.2, 4, cz - 1.2, cx + 1.2, 6.4, cz + 1.2, CRYSTAL, true)
		glow(c, 24, 1, CRYSTAL)
		for _, o in ipairs({ { -4, -4 }, { 4, 4 } }) do
			P.candles(cx + o[1], 0.2, cz + o[2], F.ring, 3)
		end
		local HEIGHTS = { 5, 3, 7, 4, 6, 3, 5, 7, 4, 6 }
		local BROKEN = { [2] = true, [4] = true, [6] = true, [9] = true }
		local CRYST = { [3] = true, [8] = true }
		for i = 1, 10 do
			local a = math.rad((i - 1) * 36 + 18)
			local px, pz =
				cx + math.floor(18 * math.cos(a) + 0.5), cz + math.floor(18 * math.sin(a) + 0.5)
			local rx, rz =
				cx + math.floor(11 * math.cos(a + 0.15) + 0.5),
				cz + math.floor(11 * math.sin(a + 0.15) + 0.5)
			P.pillar(px, pz, HEIGHTS[i], BROKEN[i], CRYST[i], rx, rz)
		end
	end
end
task.wait()

-- ================================================================ end rods along the paths (every ~24 studs)
do
	local RODS = {}
	for _, z in ipairs({ -12, 12, 60, 84, 108, 132, 156, 180 }) do
		table.insert(RODS, { -97, z, z == 108 })
		table.insert(RODS, { 97, z, false })
	end
	table.insert(RODS, { 97, 36, false })
	for _, x in ipairs({ -84, -60, -36, 36, 60 }) do
		table.insert(RODS, { x, -25, false })
	end
	for _, x in ipairs({ -64, -24, 0, 24, 64 }) do
		table.insert(RODS, { x, 192, x == -64 or x == 64 })
	end
	for _, r in ipairs({
		{ -17, -54 },
		{ 17, -54 },
		{ -17, -30 },
		{ 17, -30 },
		{ -100, 26 },
		{ -116, 26 },
		{ -100, 50 },
		{ -116, 50 },
	}) do
		table.insert(RODS, { r[1], r[2], false })
	end
	for _, r in ipairs(RODS) do
		if take(r[1] - 1, r[2] - 1, r[1] + 1, r[2] + 1, 6) then
			P.rod(r[1], 0, r[2], F.rods, r[3], 5)
			S.rods += 1
		end
	end
end
task.wait()

-- ================================================================ chorus bushes, boulders, purpur debris, candles
do
	local function scatter(n, half, tries, fn)
		local placed = 0
		for _ = 1, tries do
			if placed >= n then
				break
			end
			local x, z = rng:NextInteger(-38, 38) * B, rng:NextInteger(-18, 54) * B
			if take(x - half, z - half, x + half, z + half, 10) then
				fn(x, z)
				placed += 1
			end
		end
		return placed
	end
	S.bushes = scatter(40, 6, 1200, function(x, z)
		P.chorus(x, z, F.nature)
	end)
	scatter(12, 6, 500, function(x, z)
		P.boulder(x, z, F.nature)
	end)
	scatter(18, 2.5, 500, function(x, z)
		P.debris(x, z, F.nature)
	end)
	scatter(16, 1.5, 500, function(x, z)
		P.candles(x, 0, z, F.nature, rng:NextInteger(1, 3))
	end)
end

print(
	("[build-edge-gate] main: huts %d, spires %d, bushes %d, rods %d, lights %d, skipped %d"):format(
		S.huts,
		S.spires,
		S.bushes,
		S.rods,
		S.lights,
		S.skipped
	)
)
