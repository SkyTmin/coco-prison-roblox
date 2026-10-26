--!nocheck
-- ================================================================ inside_out: the mansion, the sky road, the arena
-- 1. The Creel mansion (hero) on its island (MANSION, ground y 48): main block x -24..24, z -358..-318 (3 storeys,
--    eave 88, stepped roof to 124), west wing x -36..-16, z -346..-310 (2 storeys, front gable), corner tower
--    x 20..36, z -330..-314 (4 storeys to 104, spire to 139), a wide porch x -16..20, z -318..-302 facing south with
--    steps down to the drive at z -298; the grandfather clock hangs over the porch (x -3.6..3.6, y 66..87, z ≈ -315.5)
--    under the central front gable. Dead garden: an iron fence at z -286 with a stone gate (x ±12), dead trees,
--    graves, beds; the drive x -8..8 stays clear.
-- 2. The sky road from the north street end (0, 0, -196) up to the mansion island: three stair flights (16 up over
--    16 each, 20 wide) joined by torn-off asphalt chunks (24 wide, top 16 and 32) with dirt cones and vines; the top
--    chunk lands on the island at y 48.1 (from the measured island edge to z -280). Tilted chunks float beside it.
-- 3. The arena (ARENA, floor y -16): a flush cracked floor (red magma and neon seams, a burnt star, dark rings),
--    4 broken lamp-post pillars at (±26, 320 ± 26) tagged Pillar, a broken rim wall r 58..62 with gaps (N, S, WNW,
--    ENE), the ring rift at (0, -16, 384), small rift tears, broken posts and ruins round the rim, and the clock of
--    Vecna floating over the centre (AmbientSpin). Ways in: the north bridge (0, 0, 194) → (0, -16, 258); the islet
--    bridges (∓120, 0, 188) → (∓120, -8, 248); the arches (∓112, -8, 272) → (∓44, -16, 272).
local works = folder("Heights")
local startCount = count
local IRON = Color3.fromRGB(44, 44, 50)
local CLAP = Color3.fromRGB(118, 160, 255) -- px_planks → dark grey clapboard
local ROOF_T = Color3.fromRGB(110, 160, 255) -- px_roof_tiles → dark slate-plum
local TRIM = Color3.fromRGB(232, 228, 220)
local PANE_DARK = Color3.fromRGB(24, 26, 38)
local PANE_LIT = Color3.fromRGB(255, 222, 150)
local STONE_T = Color3.fromRGB(150, 144, 144)
local STONE_DARK = Color3.fromRGB(120, 112, 116)
local DIRT_T = Color3.fromRGB(150, 108, 100)
local DECK_T = Color3.fromRGB(160, 152, 150)

-- the ground height of the 8-stud island cell holding (x, z) (the core builds the islands in those cells)
local function cellY(x, z)
	return groundY(math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4)
end
-- a decor part in a frame cf by size and local centre
local function lc(cf, name, sx, sy, sz, x, y, z, color, material, parent)
	return decor(part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, material, parent))
end
-- a crimson vine strand hanging from (x, yTop, z): w wide along axis ("x": in a wall facing z; "z": facing x)
local function strand(x, yTop, z, len, w, axis, parent)
	local sx, sz = if axis == "x" then w else 1, if axis == "x" then 1 else w
	local tint = if rng:NextNumber() < 0.5 then VINE_RED else VINE_DARK
	return decor(box("Vine", x - sx / 2, yTop - len, z - sz / 2, x + sx / 2, yTop, z + sz / 2, "px_nether_wart", tint, parent))
end
-- a vine curtain under an edge: strands one block wide from a0 to a1 (axis "x": along x at z = c, "z": along z at x = c)
local function curtain(axis, c, a0, a1, yTop, minLen, maxLen, density, parent)
	for a = a0 + 2, a1 - 2, B do
		if rng:NextNumber() < density then
			local len = rng:NextInteger(minLen, maxLen)
			if axis == "x" then
				strand(a, yTop, c, len, B, "x", parent)
			else
				strand(c, yTop, a, len, B, "z", parent)
			end
		end
	end
end
-- a tall window: white frame, a pane (dark glass or warm-lit neon) and a transom bar; axis "x" = a wall along x at
-- z = c facing out (±1 in z), "z" = a wall along z at x = c facing out in x
local function win(axis, c, out, a, y0, w, h, lit, parent)
	local function slab(name, a0, a1, b0, b1, d0, d1, color, material)
		local p
		if axis == "x" then
			p = box(name, a0, b0, c + out * d0, a1, b1, c + out * d1, nil, color, parent)
		else
			p = box(name, c + out * d0, b0, a0, c + out * d1, b1, a1, nil, color, parent)
		end
		p.Material = material or Enum.Material.SmoothPlastic
		return decor(p)
	end
	slab("WindowFrame", a - w / 2 - 0.6, a + w / 2 + 0.6, y0 - 0.6, y0 + h + 0.6, 0, 0.3, TRIM)
	local pane = slab("WindowPane", a - w / 2, a + w / 2, y0, y0 + h, 0, 0.45, if lit then PANE_LIT else PANE_DARK, if lit then Enum.Material.Neon else Enum.Material.Glass)
	slab("WindowBar", a - w / 2, a + w / 2, y0 + h * 0.62, y0 + h * 0.62 + 0.5, 0, 0.55, TRIM)
	return pane
end
-- an iron railing (guard rail, garden fence): posts every block and two rails between local points at height y0;
-- bars = a thin bar between the posts (a fence rather than a guard rail)
local function ironRail(ax, az, bx, bz, y0, h, parent, bars)
	local a, b = V(ax, y0, az), V(bx, y0, bz)
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / B + 0.5))
	for i = 0, n do
		local p = a:Lerp(b, i / n)
		part("IronPost", Vector3.new(0.6, h, 0.6), CFrame.new(p + Vector3.new(0, h / 2, 0)), IRON, Enum.Material.Metal, parent)
		if bars and i < n then
			local q = a:Lerp(b, (i + 0.5) / n)
			decor(part("IronBar", Vector3.new(0.35, h - 0.4, 0.35), CFrame.new(q + Vector3.new(0, h / 2 - 0.2, 0)), IRON, Enum.Material.Metal, parent))
		end
	end
	for _, f in ipairs({ 0.35, 0.9 }) do
		part("IronRail", Vector3.new(0.4, 0.4, len), CFrame.lookAt((a + b) / 2 + Vector3.new(0, h * f, 0), b + Vector3.new(0, h * f, 0)), IRON, Enum.Material.Metal, parent)
	end
end
-- a flight of the kit's walkable stairs (visible steps on an invisible ramp), tinted, the space under the steps filled
-- down to one block below the lower end; parapet = stepped stone parapets 2 studs wide on both sides
local function flight(name, c, a0, a1, y0, rise, w, variant, tint, parent, axis, parapet)
	local f = folder(name, parent)
	stairs(name, c, a0, a1, y0, rise, w, variant, f, axis)
	for _, p in ipairs(f:GetChildren()) do
		if p.Name == name .. "Step" then
			p.Color = tint
		end
	end
	local run = math.abs(a1 - a0)
	local dir = if a1 > a0 then 1 else -1
	local steps = math.max(1, math.floor(run / 2))
	local stepD = run / steps
	local low = math.min(y0, y0 + rise) - B
	local function slab(nm, s0, s1, c0, c1, ya, yb, v, t)
		if axis == "x" then
			box(nm, s0, ya, c0, s1, yb, c1, v, t, f)
		else
			box(nm, c0, ya, s0, c1, yb, s1, v, t, f)
		end
	end
	for k = 0, steps - 1 do
		local top = y0 + (k + 1) * rise / steps
		local s0, s1 = a0 + dir * k * stepD, a0 + dir * (k + 1) * stepD
		if top - B - low > 0.05 then
			slab(name .. "Fill", s0, s1, c - w / 2, c + w / 2, low, top - B, variant, tint)
		end
		if parapet then
			for _, sd in ipairs({ -1, 1 }) do
				slab(name .. "Parapet", s0, s1, c + sd * w / 2, c + sd * (w / 2 + 2), top - B, top + 3, "px_stone_bricks", STONE_DARK)
			end
		end
	end
	return f
end
-- a torn-off chunk of asphalt road (x -12..12, z zN..zS, top y): a dashed yellow centre line, broken edges, an
-- upside-down cone of dirt and rock below, vines hanging off the sides, iron guard rails (some broken)
local function roadChunk(name, zN, zS, top, parent, layers)
	local f = folder(name, parent)
	local hw = 12
	box("Asphalt", -hw, top - B, zN, hw, top, zS, "px_smooth_stone", ASPHALT, f)
	for z = zN + 2, zS - 5, 8 do
		decor(box("RoadLine", -0.6, top - 0.2, z, 0.6, top + 0.05, z + 4, "px_yellow_wool", LINE_YELLOW, f))
	end
	for _, s in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.7 then
			local zz = zN + rng:NextInteger(0, math.max(0, math.floor((zS - zN) / B) - 1)) * B
			box("AsphaltTorn", s * hw, top - B - 1.5, zz, s * (hw + B), top - 1.5, zz + B, "px_smooth_stone", ASPHALT, f)
		end
	end
	local w, a0, a1, y = hw - B, zN, zS, top - B
	for k = 1, layers do
		local inset = math.min(B, math.max(0, (a1 - a0 - B) / 2))
		a0 += inset
		a1 -= inset
		local h = if k == 1 then B else 2 * B
		box("ChunkRock", -w, y - h, a0, w, y, a1, if k == 1 then "px_dirt" else "px_blackstone", if k == 1 then DIRT_T else ROCK_RED, f)
		y -= h
		w -= if w > 4 then B else 2
		if w < 2 then
			break
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		curtain("z", s * (hw + 0.5), zN, zS, top - 1, 4, 18, 0.45, f)
		curtain("z", s * (hw - B + 0.5), zN, zS, top - B - 1, 6, 14, 0.3, f)
		local r = rng:NextNumber()
		if r < 0.45 then
			ironRail(s * 11.4, zN + 1, s * 11.4, zS - 1, top, 3.2, f)
		elseif r < 0.85 then
			local zm = (zN + zS) / 2
			ironRail(s * 11.4, zm, s * 11.4, zS - 1, top, 3.2, f)
			decor(beam("BentRail", V(s * 11.4, top + 2.9, zm), V(s * 15, top - 2, zm - 6), 0.4, IRON, f, Enum.Material.Metal))
		end
	end
	return f
end
-- a hanging lantern (kit) whose cage does not collide, chain up to local height top
local function hangLantern(x, y, z, top, parent)
	return decor(lantern(V(x, y, z), parent, false, BY + top))
end
-- a dead tree of blocks: a dark trunk and bare branches sticking out (axis-aligned) with a twig up at each end
local function deadTree(x, z, y0, h, parent)
	local f = folder("DeadTree", parent)
	box("Trunk", x - 2, y0, z - 2, x + 2, y0 + h, z + 2, "px_dark_oak_log", Color3.fromRGB(150, 130, 130), f)
	local dirs = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	for i = 1, 3 do
		local d = dirs[rng:NextInteger(1, 4)]
		local y = y0 + h - 2 - (i - 1) * 4
		local len = rng:NextInteger(2, 4) * 2
		local ex, ez = x + d[1] * (2 + len), z + d[2] * (2 + len)
		local bx0, bz0 = x + d[1] * 2 - (if d[1] == 0 then 1 else 0), z + d[2] * 2 - (if d[2] == 0 then 1 else 0)
		local bx1, bz1 = ex + (if d[1] == 0 then 1 else 0), ez + (if d[2] == 0 then 1 else 0)
		box("Branch", bx0, y - 1, bz0, bx1, y + 1, bz1, "px_dark_oak_log", Color3.fromRGB(150, 130, 130), f)
		local tx, tz = ex - d[1], ez - d[2]
		box("Twig", tx - 1, y + 1, tz - 1, tx + 1, y + 1 + rng:NextInteger(2, 3) * 2, tz + 1, "px_dark_oak_log", Color3.fromRGB(150, 130, 130), f)
		if rng:NextNumber() < 0.6 then
			strand(tx, y - 1, tz, rng:NextInteger(4, 10), 2, if d[1] == 0 then "z" else "x", f)
		end
	end
	return f
end
-- a grandfather clock in a frame cf (base centre, the face toward -Z of cf), scale s; evil = the clock of Vecna (a
-- face on both sides, red neon marks and glow)
local function grandClock(cf, s, parent, evil)
	local WOODV, TRIMV = "px_dark_oak_planks", "px_spruce_planks"
	local BRASS = Color3.fromRGB(196, 156, 70)
	local function bit(name, sx, sy, sz, x, y, z, variant, tint, material)
		local p = lc(cf, name, sx * s, sy * s, sz * s, x * s, y * s, z * s, tint, material, parent)
		if variant then
			textured(p, variant, tint)
		end
		return p
	end
	bit("ClockPlinth", 8, 2.5, 4.4, 0, 1.25, 0, WOODV, nil)
	bit("ClockTrunk", 6.4, 10, 3.6, 0, 7.5, 0, WOODV, nil)
	bit("ClockBand", 7.4, 1, 4.2, 0, 13, 0, TRIMV, Color3.fromRGB(170, 130, 120))
	bit("ClockHood", 8, 6.5, 4.4, 0, 16.75, 0, WOODV, nil)
	bit("ClockCrown", 9, 1, 4.8, 0, 20.5, 0, TRIMV, Color3.fromRGB(170, 130, 120))
	bit("ClockPediment", 5, 1.2, 4.6, 0, 21.6, 0, WOODV, nil)
	bit("ClockFinial", 1.2, 1.4, 1.2, 0, 22.9, 0, nil, BRASS, Enum.Material.Metal)
	for _, side in ipairs(if evil then { 1, -1 } else { 1 }) do
		local zf = -side
		for _, cx in ipairs({ -3.6, 3.6 }) do
			bit("ClockColumn", 0.8, 6.5, 0.8, cx, 16.75, zf * 2.2, TRIMV, Color3.fromRGB(170, 130, 120))
		end
		local glass = bit("ClockGlass", 3.2, 7, 0.3, 0, 7.5, zf * 1.9, nil, if evil then Color3.fromRGB(120, 16, 20) else PANE_DARK, if evil then Enum.Material.Neon else Enum.Material.Glass)
		if evil then
			glass.Transparency = 0.35
		end
		bit("PendulumRod", 0.3, 5, 0.2, 0.3, 8.6, zf * 2.1, nil, BRASS, Enum.Material.Metal)
		bit("PendulumBob", 1.6, 1.6, 0.3, 0.5, 5.8, zf * 2.15, nil, BRASS, Enum.Material.Metal)
		local face = bit("ClockFace", 5.6, 5.6, 0.3, 0, 16.75, zf * 2.3, nil, Color3.fromRGB(228, 218, 194), Enum.Material.SmoothPlastic)
		local markC, markM = if evil then GLOW_RED else Color3.fromRGB(34, 28, 28), if evil then Enum.Material.Neon else Enum.Material.SmoothPlastic
		for _, m in ipairs({ { 0, 2.1, 0.6, 1.1 }, { 0, -2.1, 0.6, 1.1 }, { 2.1, 0, 1.1, 0.6 }, { -2.1, 0, 1.1, 0.6 } }) do
			bit("ClockMark", m[3], m[4], 0.2, m[1], 16.75 + m[2], zf * 2.5, nil, markC, markM)
		end
		-- the hands a few minutes to midnight (seen from the front the hour hand leans to 11)
		for _, hnd in ipairs({ { 0.5, 1.8, -0.45 }, { 0.35, 2.5, -0.1 } }) do
			local hcf = cf * CFrame.new(0, 16.75 * s, zf * 2.6 * s) * CFrame.Angles(0, 0, hnd[3] * side) * CFrame.new(0, hnd[2] / 2 * s, 0)
			decor(part("ClockHand", Vector3.new(hnd[1] * s, hnd[2] * s, 0.2 * s), hcf, Color3.fromRGB(26, 22, 22), Enum.Material.SmoothPlastic, parent))
		end
		if evil and side == 1 then
			light(face, 50, 2, GLOW_RED)
		end
	end
end
-- a broken lamp post round the arena / on the islets: a dark brick shaft, an arm with a hanging lantern (lit) or a
-- broken top; (dx, dz) = the arm direction
local function brokenPost(x, z, y0, h, dx, dz, lit, parent)
	local f = folder("BrokenLamp", parent)
	box("LampBase", x - 3, y0, z - 3, x + 3, y0 + 2, z + 3, "px_blackstone_bricks", nil, f)
	box("LampShaft", x - 2, y0 + 2, z - 2, x + 2, y0 + h, z + 2, "px_stone_bricks", STONE_DARK, f)
	if lit then
		local ex, ez = x + dx * 8, z + dz * 8
		box("LampArm", math.min(x, ex) - (if dx == 0 then 1 else 0), y0 + h - 2, math.min(z, ez) - (if dz == 0 then 1 else 0), math.max(x, ex) + (if dx == 0 then 1 else 0), y0 + h, math.max(z, ez) + (if dz == 0 then 1 else 0), "px_blackstone_bricks", nil, f)
		hangLantern(x + dx * 7, y0 + h - 5.5, z + dz * 7, y0 + h - 2, f)
	else
		textured(lc(at(x, y0 + h + 1.4, z) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), "LampRubble", 4, 3, 4, 0, 0, 0, nil, nil, f), "px_stone_bricks", STONE_DARK)
	end
	strand(x + 2.5, y0 + h - 1, z, rng:NextInteger(4, math.max(5, math.floor(h - 3))), 2, "z", f)
	return f
end

-- ================================================================ 1. the mansion
do
	local house = folder("Mansion", works)
	local G = MANSION.y
	local F1, F2, F3, EAVE = G + 4, G + 16, G + 28, G + 40 -- 52, 64, 76, 88
	local ROOFV = "px_roof_tiles"
	local function mass(name, x0, z0, x1, z1, top)
		box(name .. "Base", x0 - 0.5, G - 2, z0 - 0.5, x1 + 0.5, F1, z1 + 0.5, "px_stone_bricks", STONE_DARK, house)
		box(name, x0, F1, z0, x1, top, z1, "px_planks", CLAP, house)
		for _, y in ipairs({ F2, F3, EAVE }) do
			if y < top - 2 then
				decor(box(name .. "Band", x0 - 0.3, y - 0.4, z0 - 0.3, x1 + 0.3, y + 0.4, z1 + 0.3, "px_smooth_stone", TRIM, house))
			end
		end
		decor(box(name .. "Cornice", x0 - 1, top - 1, z0 - 1, x1 + 1, top, z1 + 1, "px_smooth_stone", TRIM, house))
		for _, cx in ipairs({ x0, x1 }) do
			for _, cz in ipairs({ z0, z1 }) do
				decor(box(name .. "Corner", cx - 0.6, F1, cz - 0.6, cx + 0.6, top - 1, cz + 0.6, "px_smooth_stone", TRIM, house))
			end
		end
	end
	mass("MainBlock", -24, -358, 24, -318, EAVE)
	mass("WestWing", -36, -346, -16, -310, F3)
	mass("Tower", 20, -330, 36, -314, G + 56)

	-- roofs: the main roof (ridge along x, steep: one block in per 6 studs up), the central front gable, the wing gable
	for k = 0, 5 do
		box("Roof", -26, EAVE + 6 * k, -360 + 4 * k, 26, EAVE + 6 * k + 6, -316 - 4 * k, ROOFV, ROOF_T, house)
	end
	for k = 0, 2 do
		local hw = 12 - 4 * k
		box("GableRoof", -hw, EAVE + 6 * k, -334, hw, EAVE + 6 * k + 6, -314, ROOFV, ROOF_T, house)
		box("GableFace", -(hw - 2), EAVE + 6 * k, -314, hw - 2, EAVE + 6 * k + 6, -313.6, "px_planks", CLAP, house)
		local ww = 12 - 4 * k
		box("WingRoof", -26 - ww, F3 + 6 * k, -348, -26 + ww, F3 + 6 * k + 6, -308, ROOFV, ROOF_T, house)
		box("WingGableFace", -26 - (ww - 2), F3 + 6 * k, -308, -26 + (ww - 2), F3 + 6 * k + 6, -307.6, "px_planks", CLAP, house)
	end
	-- dormers on the front slope of the main roof
	for _, dx in ipairs({ -19, 15 }) do
		box("Dormer", dx - 3, EAVE + 6, -326, dx + 3, EAVE + 15, -319.6, "px_planks", CLAP, house)
		box("DormerRoof", dx - 4, EAVE + 15, -327, dx + 4, EAVE + 17, -319, ROOFV, ROOF_T, house)
		box("DormerRoof", dx - 2, EAVE + 17, -327, dx + 2, EAVE + 19, -320, ROOFV, ROOF_T, house)
		win("x", -319.6, 1, dx, EAVE + 7.5, 3, 6, false, house)
	end
	-- the tower spire: stepped to a point with an iron finial
	box("SpireBase", 19, G + 56, -331, 37, G + 58, -313, "px_dark_oak_planks", nil, house)
	for k, hw in ipairs({ 7, 5, 3 }) do
		box("Spire", 28 - hw, G + 58 + (k - 1) * 8, -322 - hw, 28 + hw, G + 66 + (k - 1) * 8, -322 + hw, ROOFV, ROOF_T, house)
	end
	box("SpireTip", 27, G + 82, -323, 29, G + 90, -321, nil, IRON, house).Material = Enum.Material.Metal
	cube("SpireBall", 28, G + 91, -322, 1.6, 1.6, 1.6, nil, IRON, house).Material = Enum.Material.Metal
	-- chimneys of dark brick
	for _, c in ipairs({ { -12, -346, 128 }, { 16, -352, 122 } }) do
		box("Chimney", c[1] - 2, EAVE + 8, c[2] - 2, c[1] + 2, c[3], c[2] + 2, "px_red_brick", Color3.fromRGB(150, 120, 120), house)
		box("ChimneyCap", c[1] - 3, c[3], c[2] - 3, c[1] + 3, c[3] + 1, c[2] + 3, "px_stone_bricks", STONE_DARK, house)
	end
	task.wait()

	-- windows: tall, white frames, mostly dark, a few warm-lit (three of them cast light)
	local lights = 0
	local function w(axis, c, out, a, y0, lit, ww, hh)
		local pane = win(axis, c, out, a, y0, ww or 4, hh or 8, lit, house)
		if lit and lights < 3 and (ww or 4) >= 4 then
			lights += 1
			light(pane, 22, 1.2, PANE_LIT)
		end
	end
	local Y1, Y2, Y3, Y4 = F1 + 2, F2 + 2, F3 + 2, EAVE + 3
	for _, a in ipairs({ -12, 12 }) do
		w("x", -318, 1, a, Y1, false)
		w("x", -318, 1, a, Y2, a == 12)
		w("x", -318, 1, a, Y3, a == -12, 4, 7.5)
	end
	for _, a in ipairs({ -30, -22 }) do
		w("x", -310, 1, a, Y1, a == -30)
		w("x", -310, 1, a, Y2, false)
	end
	for _, a in ipairs({ -340, -326 }) do
		w("z", -36, -1, a, Y1, false)
		w("z", -36, -1, a, Y2, false)
	end
	for _, a in ipairs({ -350, -340 }) do
		for _, y in ipairs({ Y1, Y2, Y3 }) do
			w("z", 24, 1, a, y, false, 4, if y == Y3 then 7.5 else 8)
		end
	end
	for _, y in ipairs({ Y1, Y2, Y3 }) do
		w("z", -24, -1, -352, y, y == Y2, 4, if y == Y3 then 7.5 else 8)
	end
	for _, a in ipairs({ -16, 0, 16 }) do
		w("x", -358, -1, a, Y2, false)
		w("x", -358, -1, a, Y3, false, 4, 7.5)
	end
	w("x", -314, 1, 28, Y4, true)
	for _, y in ipairs({ Y1, Y2, Y3 }) do
		w("x", -314, 1, 28, y, false, 4, if y == Y3 then 7.5 else 8)
		w("z", 36, 1, -322, y, false, 4, if y == Y3 then 7.5 else 8)
	end
	w("z", 36, 1, -322, Y4, false)
	w("z", 20, -1, -322, Y4, false)
	w("x", -330, -1, 28, Y4, false)
	w("x", -313.6, 1, 0, EAVE + 2, true, 3, 6) -- the attic window in the front gable
	w("x", -307.6, 1, -26, F3 + 2, false, 3, 6) -- the wing gable

	-- the front door: one leaf swung out onto the porch, a dark hall behind it, a lit transom
	decor(box("DoorFrame", -5, F1, -318, 5, F1 + 11, -317.7, "px_smooth_stone", TRIM, house))
	local hall = decor(box("DarkHall", -4, F1, -318, 4, F1 + 10, -317.5, nil, Color3.fromRGB(10, 8, 12), house))
	hall.Material = Enum.Material.SmoothPlastic
	textured(decor(part("DoorLeaf", Vector3.new(4, 10, 0.4), at(4 - 2, F1 + 5, -317.2), nil, nil, house)), "px_dark_oak_planks")
	local a = math.rad(70)
	textured(decor(part("DoorLeaf", Vector3.new(4, 10, 0.4), at(-4 + 2 * math.cos(a), F1 + 5, -317.4 + 2 * math.sin(a)) * CFrame.Angles(0, -a, 0), nil, nil, house)), "px_dark_oak_planks")
	local transom = decor(box("Transom", -4, F1 + 10.3, -318, 4, F1 + 11.3, -317.4, nil, PANE_LIT, house))
	transom.Material = Enum.Material.Neon

	-- the porch: stone base, plank deck, white columns, lattice railings, a slate roof, lanterns, steps to the drive
	box("PorchBase", -16, G - 2, -318, 20, F1 - 1, -302, "px_stone_bricks", STONE_DARK, house)
	box("PorchDeck", -16, F1 - 1, -318, 20, F1, -302, "px_spruce_planks", Color3.fromRGB(170, 150, 140), house)
	for _, cx in ipairs({ -15, -8, 8, 18 }) do
		box("PorchColumn", cx - 1, F1, -304, cx + 1, F2, -302, "px_smooth_stone", TRIM, house)
		box("ColumnCap", cx - 1.5, F2 - 1, -304.5, cx + 1.5, F2, -301.5, "px_smooth_stone", TRIM, house)
	end
	for _, r in ipairs({ { -16, -303.4, -8, -302.6 }, { 8, -303.4, 20, -302.6 }, { -16.4, -310, -15.6, -303 }, { 19.6, -314, 20.4, -303 } }) do
		box("PorchRail", r[1], F1, r[2], r[3], F1 + 2.6, r[4], "px_spruce_planks", TRIM, house)
		box("PorchRailTop", r[1] - 0.2, F1 + 2.6, r[2] - 0.2, r[3] + 0.2, F1 + 3.2, r[4] + 0.2, "px_smooth_stone", TRIM, house)
	end
	box("PorchRoof", -17, F2, -319, 21, F2 + 1.5, -301, ROOFV, ROOF_T, house)
	decor(box("PorchFascia", -17, F2 - 1, -301.6, 21, F2, -301, "px_smooth_stone", TRIM, house))
	for _, lx in ipairs({ -12, 12 }) do
		hangLantern(lx, F2 - 4, -306, F2, house)
	end
	flight("PorchSteps", 0, -298, -302, G, 4, 16, "px_stone_bricks", STONE_T, house)

	-- the grandfather clock hanging over the porch under the front gable, on an iron bracket
	local clock = folder("MansionClock", house)
	grandClock(CFrame.lookAt(V(0, F2 + 2, -315.5), V(0, F2 + 2, -300)), 0.9, clock, false)
	decor(box("ClockBracket", -1, EAVE - 0.6, -318, 1, EAVE, -314.5, nil, IRON, clock)).Material = Enum.Material.Metal
	task.wait()

	-- vines: curtains from the eaves, the porch roof and the gables; blobs on the roofs
	curtain("x", -317.4, -16, -4, EAVE - 1, 4, 16, 0.6, house)
	curtain("x", -317.4, 4, 20, EAVE - 1, 4, 16, 0.6, house)
	curtain("x", -300.6, -17, -8, F2, 3, 9, 0.7, house)
	curtain("x", -300.6, 8, 21, F2, 3, 9, 0.7, house)
	curtain("x", -307.2, -38, -14, F3, 4, 14, 0.5, house)
	curtain("x", -313.2, 20, 36, G + 55, 6, 22, 0.6, house)
	curtain("z", 24.6, -358, -330, EAVE - 1, 6, 20, 0.5, house)
	curtain("z", -36.6, -346, -310, F3 - 1, 4, 16, 0.5, house)
	curtain("x", -358.6, -24, 24, EAVE - 1, 6, 24, 0.4, house)
	for _, b in ipairs({
		{ -38, F3 + 6, -336, -34, F3 + 9, -324 },
		{ -26, EAVE + 6, -320, -22, EAVE + 9, -316 },
		{ 0, EAVE + 6, -360, 12, EAVE + 9, -356 },
		{ 33, G + 66, -329, 36, G + 69, -324 },
		{ -14, F2 + 1.5, -312, -8, F2 + 4, -306 },
		{ 10, F2 + 1.5, -310, 18, F2 + 4, -304 },
		{ 4, EAVE + 24, -332, 10, EAVE + 27, -328 },
	}) do
		decor(box("VineBlob", b[1], b[2], b[3], b[4], b[5], b[6], "px_nether_wart", VINE_DARK, house))
	end

	-- the dead garden: beds of dead shrubs, an iron fence with a stone gate across the drive, dead trees, graves
	local garden = folder("Garden", house)
	for _, bed in ipairs({ { -35, -309, -17, -303 }, { 21, -313, 35, -305 } }) do
		box("DeadBed", bed[1], G - 0.2, bed[2], bed[3], G + 0.1, bed[4], "px_dirt", Color3.fromRGB(120, 96, 88), garden)
		for x = bed[1] + 1, bed[3] - 4, 6 do
			if rng:NextNumber() < 0.75 then
				box("DeadShrub", x, G + 0.1, bed[2] + 1, x + 4, G + 3, bed[2] + 5, "px_nether_wart", Color3.fromRGB(110, 70, 70), garden)
			end
		end
	end
	ironRail(-44, -286, -14, -286, G, 6, garden, true)
	ironRail(14, -286, 44, -286, G, 6, garden, true)
	ironRail(-44, -306, -44, -286, G, 6, garden, true)
	ironRail(44, -306, 44, -286, G, 6, garden, true)
	for _, sx in ipairs({ -1, 1 }) do
		box("GatePillar", sx * 10, G, -288, sx * 14, G + 10, -284, "px_stone_bricks", STONE_DARK, garden)
		box("GatePillarCap", sx * 9.5, G + 10, -288.5, sx * 14.5, G + 11, -283.5, "px_smooth_stone", STONE_T, garden)
		local lan = lantern(V(sx * 12, G + 11.75, -286), garden, false)
		decor(lan)
		-- the gate leaf stands open, swung in along the pillar line (off the drive)
		local gx = sx * 9.5
		box("GateRail", gx - 0.3, G + 1, -298, gx + 0.3, G + 1.6, -288, nil, IRON, garden).Material = Enum.Material.Metal
		box("GateRail", gx - 0.3, G + 6.4, -298, gx + 0.3, G + 7, -288, nil, IRON, garden).Material = Enum.Material.Metal
		for gz = -297, -289, 2.5 do
			box("GateBar", gx - 0.2, G + 0.5, gz - 0.2, gx + 0.2, G + 8, gz + 0.2, nil, IRON, garden).Material = Enum.Material.Metal
		end
	end
	for _, t in ipairs({ { -48, -300 }, { 46, -296 }, { -52, -344 }, { 50, -350 }, { -28, -274 }, { 30, -280 }, { -40, -368 }, { 36, -370 } }) do
		local y = cellY(t[1], t[2])
		if y == G and cellY(t[1] + 8, t[2]) and cellY(t[1] - 8, t[2]) then
			deadTree(t[1], t[2], G, rng:NextInteger(4, 6) * 4, garden)
		end
	end
	local function grave(x, z)
		if cellY(x, z) ~= G or cellY(x, z + 6) ~= G then
			return
		end
		local cf = at(x, G, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.1, 0.1))
		textured(part("Grave", Vector3.new(4, 5, 1.6), cf * CFrame.new(0, 2.2, 0), nil, nil, garden), "px_stone_bricks", Color3.fromRGB(170, 164, 168))
		if rng:NextNumber() < 0.4 then
			textured(decor(part("GraveTop", Vector3.new(2, 2, 1.4), cf * CFrame.new(0, 5.4, 0), nil, nil, garden)), "px_stone_bricks", Color3.fromRGB(170, 164, 168))
		end
		box("GraveMound", x - 2, G - 0.2, z + 1, x + 2, G + 0.4, z + 5, "px_dirt", Color3.fromRGB(120, 96, 88), garden)
	end
	for _, gz in ipairs({ -330, -320, -310 }) do
		for _, gx in ipairs({ -58, -51, -44 }) do
			if rng:NextNumber() < 0.8 then
				grave(gx, gz)
			end
		end
	end
	for _, g in ipairs({ { 46, -336 }, { 53, -336 }, { 46, -326 }, { 53, -324 } }) do
		grave(g[1], g[2])
	end
	-- vine carpets creeping over the lawn toward the house
	for _ = 1, 10 do
		local x, z = rng:NextInteger(-14, 14) * 4, rng:NextInteger(-92, -72) * 4
		if math.abs(x) > 14 and not (math.abs(x + 4) < 44 and z > -366 and z < -298) and cellY(x, z) == G and cellY(x + 8, z + 8) == G then
			box("VineCarpet", x, G - 0.2, z, x + 8, G + 0.15, z + 4 * rng:NextInteger(1, 3), "px_nether_wart", VINE_DARK, garden)
		end
	end
end
task.wait()

-- ================================================================ 2. the sky road up to the mansion
do
	local road = folder("SkyRoad", works)
	-- the island's south edge on the road (x -20..20): the top landing starts where the island cells begin
	local zE = -264
	for _, cx in ipairs({ -20, -12, -4, 4, 12, 20 }) do
		if groundY(cx, -260) then
			zE = -256
		end
	end
	local land = (-196 - zE - 48) / 2 -- each mid landing: 6 or 10 studs (plus 8 under the next flight)
	local z, y = -196, 0
	for k = 1, 3 do
		flight("SkyStairs" .. k, 0, z, z - 16, y, 16, 20, "px_stone_bricks", STONE_T, road)
		-- a small rock under each floating flight
		box("StairRock", -6, y - 12, z - 12, 6, y - 4, z - 4, "px_dirt", DIRT_T, road)
		box("StairRock", -2, y - 20, z - 10, 2, y - 12, z - 6, "px_blackstone", ROCK_RED, road)
		z -= 16
		y += 16
		if k < 3 then
			roadChunk("RoadChunk" .. k, z - land - 8, z, y, road, 3 + k % 2)
			-- a bent street lamp with a hanging lantern
			local sx = if k == 1 then -1 else 1
			local lz = z - land / 2
			part("StreetLamp", Vector3.new(1, 11, 1), at(sx * 11, y + 5.5, lz), IRON, Enum.Material.Metal, road)
			part("StreetLampArm", Vector3.new(4, 0.8, 0.8), at(sx * 9, y + 10.6, lz) * CFrame.Angles(0, 0, sx * 0.25), IRON, Enum.Material.Metal, road)
			hangLantern(sx * 7.5, y + 7, lz, y + 10, road)
			z -= land
		end
	end
	roadChunk("RoadChunkTop", -280, zE, MANSION.y + 0.1, road, 2)
	-- torn chunks drifting beside the road (decor, out of the path)
	for _, t in ipairs({ { -26, 4, -206, 0.3, 0.2 }, { 25, 18, -226, -0.25, -0.3 }, { -25, 30, -246, 0.2, 0.4 }, { 26, 44, -254, -0.35, 0.1 } }) do
		local cf = at(t[1], t[2], t[3]) * CFrame.Angles(t[5], rng:NextNumber(0, 6.28), t[4])
		local m = folder("TiltedChunk", road)
		textured(lc(cf, "Asphalt", 12, 4, 12, 0, 0, 0, nil, nil, m), "px_smooth_stone", ASPHALT)
		textured(lc(cf, "RoadLine", 1.2, 0.3, 4, 0, 2.05, 0, nil, nil, m), "px_yellow_wool", LINE_YELLOW)
		textured(lc(cf, "ChunkRock", 8, 6, 8, 0, -5, 0, nil, nil, m), "px_dirt", DIRT_T)
		textured(lc(cf, "ChunkRock", 4, 6, 4, 0, -11, 0, nil, nil, m), "px_blackstone", ROCK_RED)
		textured(lc(cf, "Vine", 4, 10, 1, 2, -7, 6.5, nil, nil, m), "px_nether_wart", VINE_RED)
	end
end
task.wait()

-- ================================================================ 3. the arena island
do
	local arena = folder("Arena", works)
	local AX, AZ, AY = ARENA.x, ARENA.z, ARENA.y
	-- openings in the rim: angle (deg from +X toward +Z) and half width: N bridge, S rift, WNW and ENE arches
	local OPEN = { { 270, 14 }, { 90, 16 }, { 223.8, 14 }, { 316.2, 14 } }
	local function openingPerp(dx, dz)
		local best = math.huge
		for _, o in ipairs(OPEN) do
			local ang = math.rad(o[1])
			local ux, uz = math.cos(ang), math.sin(ang)
			if dx * ux + dz * uz > 0 then
				best = math.min(best, math.abs(-dx * uz + dz * ux) - o[2])
			end
		end
		return best
	end

	-- the cracked floor: jagged seams of magma and red neon from a burnt star, a dark ring, laid flush in runs
	local floorF = folder("Floor", arena)
	local crack = {}
	local function mark(dx, dz, kind)
		local key = math.floor(dx / B) .. "," .. math.floor(dz / B)
		if not crack[key] then
			crack[key] = kind
		end
	end
	local function walk(x, z, phi, len, depth)
		local s = 0
		while s < len do
			if x * x + z * z >= 51 * 51 then
				break
			end
			mark(x, z, if rng:NextNumber() < 0.3 then "neon" else "magma")
			if s < 14 and depth == 0 then
				mark(x - math.sin(phi) * 3, z + math.cos(phi) * 3, "magma")
			end
			if depth == 0 and s >= 20 and s < 22.5 and rng:NextNumber() < 0.75 then
				walk(x, z, phi + (if rng:NextNumber() < 0.5 then 0.7 else -0.7), rng:NextNumber(10, 16), 1)
			end
			x += math.cos(phi) * 2.5
			z += math.sin(phi) * 2.5
			phi += rng:NextNumber(-0.16, 0.16)
			s += 2.5
		end
	end
	for i = 0, 9 do
		local th = i * math.pi / 5 + rng:NextNumber(-0.18, 0.18)
		walk(math.cos(th) * 7, math.sin(th) * 7, th, 46, 0)
	end
	local KIND = {
		neon = { nil, GLOW_RED },
		magma = { "px_magma", nil },
		ring = { "px_blackstone_bricks", Color3.fromRGB(110, 100, 110) },
		star = { "px_basalt", Color3.fromRGB(96, 88, 94) },
		soot = { "px_basalt", Color3.fromRGB(130, 120, 126) },
	}
	local function cellKind(ix, iz)
		local dx, dz = ix * B + 2, iz * B + 2
		local rr = math.sqrt(dx * dx + dz * dz)
		if rr >= 56 then
			return nil
		end
		if rr < 4 then
			return "magma"
		end
		local c = crack[ix .. "," .. iz]
		if c and rr < 52 then
			return c
		end
		if rr >= 52 then
			return "ring"
		end
		local th = math.atan2(dz, dx)
		if rr < 9 + 9 * math.max(0, math.cos(5 * th)) ^ 3 then
			return "star"
		end
		if rr >= 20 and rr < 23.5 then
			return "ring"
		end
		if rng:NextNumber() < 0.05 then
			return "soot"
		end
		return nil
	end
	for iz = -14, 13 do
		local z0 = AZ + iz * B
		local runX, runKey = nil, nil
		local function flush(xEnd)
			if runX then
				local k = KIND[runKey]
				local p = box("ArenaFloor", runX, AY - 0.2, z0, xEnd, AY + 0.1, z0 + B, k[1], k[2], floorF)
				if runKey == "neon" then
					p.Material = Enum.Material.Neon
				end
			end
			runX = nil
		end
		for ix = -14, 13 do
			local kind = cellKind(ix, iz)
			if kind ~= runKey then
				flush(AX + ix * B)
				if kind then
					runX = AX + ix * B
				end
				runKey = kind
			end
		end
		flush(AX + 14 * B)
	end
	task.wait()

	-- the four broken lamp-post pillars on the diagonals (tagged Pillar: the boss's charge stuns on them)
	for i, s in ipairs({ { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }) do
		local px, pz = AX + s[1] * 26, AZ + s[2] * 26
		local pf = folder("LampPillar", arena)
		pillarTag(box("PillarBase", px - 6, AY, pz - 6, px + 6, AY + 8, pz + 6, "px_blackstone_bricks", nil, pf))
		pillarTag(box("PillarPlinth", px - 5, AY + 8, pz - 5, px + 5, AY + 9, pz + 5, "px_stone_bricks", STONE_DARK, pf))
		local shaftTop = if i == 3 then AY + 20 else AY + 24
		pillarTag(box("PillarShaft", px - 4, AY + 9, pz - 4, px + 4, shaftTop, pz + 4, "px_stone_bricks", STONE_DARK, pf))
		local inward = -s[1] -- the arm reaches toward the middle along x
		if i == 3 then
			-- snapped off: two jagged stubs and a tilted broken block
			pillarTag(box("PillarStub", px - 4, shaftTop, pz - 4, px, shaftTop + 6, pz, "px_stone_bricks", STONE_DARK, pf))
			pillarTag(box("PillarStub", px, shaftTop, pz, px + 4, shaftTop + 3, pz + 4, "px_stone_bricks", STONE_DARK, pf))
			textured(lc(at(px + 1, shaftTop + 4, pz + 2) * CFrame.Angles(0.3, 0.6, -0.35), "PillarRubble", 4, 4, 4, 0, 0, 0, nil, nil, pf), "px_blackstone_bricks")
		else
			pillarTag(box("PillarCollar", px - 5, AY + 24, pz - 5, px + 5, AY + 26, pz + 5, "px_blackstone_bricks", nil, pf))
			-- the bent top: straight on two pillars, crooked on one
			local cf = at(px, AY + 26, pz) * CFrame.Angles(0, 0, if i == 2 then inward * 0.16 else 0)
			local function seg(name, sx, sy, sz, x, y, z, variant, tint)
				local p = part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), nil, nil, pf)
				textured(p, variant, tint)
				return pillarTag(p)
			end
			seg("PillarNeck", 6, 8, 6, 0, 4, 0, "px_stone_bricks", STONE_DARK)
			seg("PillarArm", 14, 4, 4, inward * 6, 6, 0, "px_blackstone_bricks", nil)
			seg("PillarHook", 4, 4, 4, inward * 12, 2, 0, "px_blackstone_bricks", nil)
			local tip = (cf * CFrame.new(inward * 12, 0, 0)).Position
			decor(lantern(tip - Vector3.new(0, 3.5, 0), pf, false, tip.Y))
		end
		-- crimson vines wrapping and hanging down the shaft
		decor(box("VineWrap", px - 4.6, AY + 12 + rng:NextInteger(0, 2) * 3, pz - 4.6, px + 4.6, AY + 15 + rng:NextInteger(0, 2) * 3, pz + 4.6, "px_nether_wart", VINE_RED, pf))
		curtain("z", px + s[1] * 4.6, pz - 4, pz + 4, shaftTop - 1, 6, 14, 0.8, pf)
		curtain("x", pz + s[2] * 4.6, px - 4, px + 4, shaftTop - 1, 4, 12, 0.7, pf)
		decor(box("VineCarpet", px - 8, AY - 0.15, pz - 8, px + 8, AY + 0.2, pz - 6, "px_nether_wart", VINE_DARK, pf))
	end
	task.wait()

	-- the broken rim wall r 58..62.5 (1-3 blocks, gaps and openings), merged in runs per row by height
	local rim = folder("Rim", arena)
	local HEIGHTS = {}
	for k = 1, 36 do
		HEIGHTS[k] = pick({ 0, 4, 4, 8, 8, 8, 12 })
	end
	for iz = -16, 15 do
		local z0 = AZ + iz * B
		local runX, runH = nil, 0
		local function flush(xEnd)
			if runX and runH > 0 then
				box("RimWall", runX, AY, z0, xEnd, AY + runH, z0 + B, "px_stone_bricks", STONE_T, rim)
				if runH >= 8 and rng:NextNumber() < 0.4 then
					decor(box("RimVine", runX, AY + runH, z0, xEnd, AY + runH + 0.8, z0 + B, "px_nether_wart", VINE_DARK, rim))
				end
			end
			runX = nil
		end
		for ix = -16, 15 do
			local dx, dz = ix * B + 2, iz * B + 2
			local rr = math.sqrt(dx * dx + dz * dz)
			local h = 0
			if rr >= 58 and rr < 62.5 and openingPerp(dx, dz) > 0 then
				local deg = (math.deg(math.atan2(dz, dx)) + 360) % 360
				h = HEIGHTS[math.floor(deg / 10) % 36 + 1]
			end
			if h ~= runH then
				flush(AX + ix * B)
				if h > 0 then
					runX = AX + ix * B
				end
				runH = h
			end
		end
		flush(AX + 16 * B)
	end

	-- round the rim in the free arcs between the openings: broken lamp posts (two flank the rift), ruins, rift tears
	for _, p in ipairs({ { 352, 66, true }, { 38, 66, false }, { 64, 64, true }, { 116, 64, true }, { 158, 66, false }, { 186, 66, false } }) do
		local ang = math.rad(p[1])
		local x, z = AX + snap(math.cos(ang) * p[2]) + 2, AZ + snap(math.sin(ang) * p[2]) + 2
		if cellY(x - 3, z - 3) == AY and cellY(x + 3, z + 3) == AY and cellY(x - 3, z + 3) == AY and cellY(x + 3, z - 3) == AY then
			local dx = if math.cos(ang) > 0 then -1 else 1
			brokenPost(x, z, AY, if p[3] then 18 else rng:NextInteger(3, 5) * 4, dx, 0, p[3], rim)
		end
	end
	for _, r in ipairs({ { 22, 70 }, { 144, 70 } }) do
		local ang = math.rad(r[1])
		local x, z = AX + snap(math.cos(ang) * r[2]), AZ + snap(math.sin(ang) * r[2])
		local ok = true
		for _, c in ipairs({ { -6, -2 }, { 6, 2 }, { -2, -6 }, { 2, 6 } }) do
			if cellY(x + c[1], z + c[2]) ~= AY then
				ok = false
			end
		end
		if ok then
			local f = folder("Ruin", rim)
			box("RuinWall", x - 6, AY, z - 2, x + 6, AY + 4 * rng:NextInteger(1, 2), z + 2, "px_stone_bricks", STONE_T, f)
			box("RuinWall", x - 6, AY, z + 2, x - 2, AY + 4 * rng:NextInteger(1, 3), z + 6, "px_stone_bricks", STONE_T, f)
			box("RuinRubble", x + 2, AY, z + 2, x + 6, AY + 4, z + 6, "px_cobblestone", STONE_DARK, f)
			curtain("x", z - 2.5, x - 6, x + 6, AY + 4, 2, 4, 0.6, f)
		end
	end
		for _, deg in ipairs({ 340, 8, 52, 130, 172, 200, 247, 293 }) do
		local ang = math.rad(deg)
		local cx, cz = AX + math.cos(ang) * 70, AZ + math.sin(ang) * 70
		if cellY(cx, cz) == AY then
			local f = folder("RiftTear", rim)
			local tx, tz = -math.sin(ang), math.cos(ang)
			for j = -2, 2 do
				local x, z = snap(cx + tx * j * 4), snap(cz + tz * j * 4)
				if cellY(x, z) == AY then
					decor(box("TearCrack", x - 2, AY - 0.1, z - 2, x + 2, AY + 0.12, z + 2, "px_magma", nil, f))
				end
			end
			local glow = decor(part("TearGlow", Vector3.new(1.2, 0.3, 14), CFrame.lookAt(V(cx, AY + 0.15, cz), V(cx + tx, AY + 0.15, cz + tz)), GLOW_RED, Enum.Material.Neon, f))
			if deg == 8 or deg == 172 or deg == 247 then
				light(glow, 18, 1.2, GLOW_RED)
			end
		end
	end
	task.wait()

	-- the ring rift at the back (south): an oval of crimson wart and stems round a red glowing core
	do
		local rift = folder("RingRift", arena)
		local RZ = AZ + 64
		local CY = AY + 17
		for iy = 0, 8 do
			local cy = AY + iy * B + 2
			local runX, runKey = nil, nil
			local coreX0, coreX1 = nil, nil
			local function flush(xEnd)
				if runX then
					box("RiftRing", runX, AY + iy * B, RZ - 2, xEnd, AY + iy * B + B, RZ + 2, runKey, if runKey == "px_nether_wart" then VINE_RED else nil, rift)
				end
				runX = nil
			end
			for ix = -4, 3 do
				local cx = ix * B + 2
				local e = (cx / 13) ^ 2 + ((cy - CY) / 17) ^ 2
				local key = nil
				if e >= 0.5 and e <= 1.05 then
					key = if (ix + iy) % 3 == 0 then "px_crimson_stem" else "px_nether_wart"
				elseif e < 0.5 then
					coreX0 = coreX0 or ix * B
					coreX1 = ix * B + B
				end
				if key ~= runKey then
					flush(AX + ix * B)
					if key then
						runX = AX + ix * B
					end
					runKey = key
				end
			end
			flush(AX + 16)
			if coreX0 then
				local core = decor(box("RiftCore", AX + coreX0, AY + iy * B, RZ - 0.5, AX + coreX1, AY + iy * B + B, RZ + 0.5, nil, GLOW_RED, rift))
				core.Material = Enum.Material.Neon
				core.Transparency = 0.15
				if iy == 4 then
					light(core, 50, 2.2, GLOW_RED)
					emitter(core, {
						Rate = 6,
						Lifetime = NumberRange.new(2, 4),
						Speed = NumberRange.new(1, 3),
						SpreadAngle = Vector2.new(40, 40),
						Size = NumberSequence.new(0.4),
						Color = ColorSequence.new(GLOW_RED),
						LightEmission = 0.6,
					})
				end
			end
		end
		-- tendrils curling out of the top, vines spreading over the ground from its foot
		for _, t in ipairs({ { -10, 30, 0.5 }, { 8, 32, -0.4 }, { -2, 36, 0.15 } }) do
			textured(lc(at(AX + t[1], AY + t[2], RZ) * CFrame.Angles(0, 0, t[3]), "RiftTendril", 2, 9, 2, 0, 0, 0, nil, nil, rift), "px_crimson_stem")
		end
		for _, v in ipairs({ { -20, -4, -12, 8 }, { 12, -2, 22, 6 }, { -6, 2, 6, 6 }, { -16, -10, -8, -4 }, { 10, -12, 18, -6 } }) do
			box("RiftVines", AX + v[1], AY - 0.15, RZ + v[2], AX + v[3], AY + 0.2, RZ + v[4], "px_nether_wart", VINE_DARK, rift)
		end
		curtain("x", RZ - 2.5, AX - 12, AX + 12, AY + 34, 4, 10, 0.5, rift)
		curtain("x", RZ + 2.5, AX - 12, AX + 12, AY + 34, 4, 14, 0.5, rift)
	end

	-- the clock of Vecna floating over the arena, turning slowly (src/client/AmbientMotion.luau, tag AmbientSpin)
	do
		local model = Instance.new("Model")
		model.Name = "VecnaClock"
		model.Parent = arena
		local s = 1.6
		grandClock(at(AX, 26 - 12 * s, AZ), s, model, true)
		model.WorldPivot = at(AX, 26, AZ)
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		model:SetAttribute("Speed", 0.12)
		CollectionService:AddTag(model, "AmbientSpin")
	end
	task.wait()

	-- the north bridge: from the south street end (y 0) down one flight to the arena island (y -16)
	do
		local nb = folder("NorthBridge", arena)
		box("BridgeHead", -12, -3.9, 194, 12, 0.1, 212, "px_stone_bricks", DECK_T, nb)
		for _, sx in ipairs({ -1, 1 }) do
			box("BridgeParapet", sx * 10, 0.1, 200, sx * 12, 3.1, 210, "px_stone_bricks", STONE_DARK, nb)
			box("BridgePost", sx * 10, 0.1, 210, sx * 13, 5.1, 214, "px_stone_bricks", STONE_DARK, nb)
		end
		decor(lantern(V(-11.5, 5.85, 212), nb, false))
		flight("NorthStairs", 0, 212, 228, 0, -16, 20, "px_stone_bricks", DECK_T, nb, nil, true)
		box("BridgeDeck", -12, AY - 3.9, 228, 12, AY + 0.1, 258, "px_stone_bricks", DECK_T, nb)
		for _, sx in ipairs({ -1, 1 }) do
			box("BridgeParapet", sx * 10, AY + 0.1, 228, sx * 12, AY + 2.6, 244, "px_stone_bricks", STONE_DARK, nb)
			fence(sx * 11, 229, sx * 11, 243, nb, AY + 2.6, "px_planks")
			box("BridgePost", sx * 10, AY + 0.1, 244, sx * 13, AY + 5.1, 248, "px_stone_bricks", STONE_DARK, nb)
		end
		decor(lantern(V(11.5, AY + 5.85, 246), nb, false))
		-- stepped supports under the spans
		box("BridgeArch", -10, -12, 202, 10, -4, 210, "px_stone_bricks", STONE_DARK, nb)
		box("BridgeArch", -6, -20, 204, 6, -12, 208, "px_stone_bricks", STONE_DARK, nb)
		box("BridgeArch", -10, AY - 12, 230, 10, AY - 4, 242, "px_stone_bricks", STONE_DARK, nb)
		box("BridgeArch", -6, AY - 20, 233, 6, AY - 12, 239, "px_stone_bricks", STONE_DARK, nb)
		curtain("x", 241.5, -10, 10, AY - 4, 4, 14, 0.5, nb)
	end

	-- the islets: bridges from the SW/SE street ends (y 0) down to their north edges (y -8), then stone arches down
	-- to the arena island's west and east sides (y -16); a ruin, a broken lamp post and vines on each islet
	for _, sx in ipairs({ -1, 1 }) do
		local c = sx * 120
		local isl = ISLETS[if sx < 0 then 1 else 2]
		local ib = folder(if sx < 0 then "WestIslet" else "EastIslet", arena)
		box("IsletBridgeHead", c - 12, -3.9, 188, c + 12, 0.1, 208, "px_stone_bricks", DECK_T, ib)
		for _, sd in ipairs({ -1, 1 }) do
			box("IsletParapet", c + sd * 10, 0.1, 197, c + sd * 12, 3.1, 208, "px_stone_bricks", STONE_DARK, ib)
		end
		flight("IsletStairs", c, 208, 216, 0, -8, 20, "px_stone_bricks", DECK_T, ib, nil, true)
		box("IsletBridgeDeck", c - 12, isl.y - 3.9, 216, c + 12, isl.y + 0.1, 248, "px_stone_bricks", DECK_T, ib)
		for _, sd in ipairs({ -1, 1 }) do
			box("IsletParapet", c + sd * 10, isl.y + 0.1, 216, c + sd * 12, isl.y + 2.6, 236, "px_stone_bricks", STONE_DARK, ib)
			if rng:NextNumber() < 0.6 then
				fence(c + sd * 11, 218, c + sd * 11, 234, ib, isl.y + 2.6, "px_planks")
			end
		end
		box("IsletArch", c - 10, isl.y - 12, 218, c + 10, isl.y - 4, 232, "px_stone_bricks", STONE_DARK, ib)
		box("IsletArch", c - 6, isl.y - 20, 221, c + 6, isl.y - 12, 229, "px_stone_bricks", STONE_DARK, ib)
		curtain("x", 232.5, c - 10, c + 10, isl.y - 4, 4, 12, 0.5, ib)

		-- the arch bridge east/west to the arena island: walkway z 264..280, parapets outside it
		box("ArchDeckHigh", sx * 112, isl.y - 3.9, 262, sx * 88, isl.y + 0.1, 282, "px_stone_bricks", DECK_T, ib)
		flight("ArchStairs", 272, sx * 88, sx * 80, isl.y, AY - isl.y, 16, "px_stone_bricks", DECK_T, ib, "x", true)
		box("ArchDeckLow", sx * 80, AY - 3.9, 262, sx * 44, AY + 0.1, 282, "px_stone_bricks", DECK_T, ib)
		for _, z in ipairs({ 262, 280 }) do
			box("ArchParapet", sx * 98, isl.y + 0.1, z, sx * 88, isl.y + 3.1, z + 2, "px_stone_bricks", STONE_DARK, ib)
			box("ArchParapet", sx * 80, AY + 0.1, z, sx * 70, AY + 3.1, z + 2, "px_stone_bricks", STONE_DARK, ib)
			box("ArchParapet", sx * 66, AY + 0.1, z, sx * 58, AY + 2.1, z + 2, "px_stone_bricks", STONE_DARK, ib)
			-- the gateway arch at the arena end
			box("ArchPost", sx * 58, AY + 0.1, z, sx * 62, AY + 14, z + 2, "px_stone_bricks", STONE_DARK, ib)
		end
		box("ArchLintel", sx * 57, AY + 14, 261, sx * 63, AY + 17, 283, "px_stone_bricks", STONE_DARK, ib)
		box("ArchLintel", sx * 58, AY + 17, 265, sx * 62, AY + 19, 279, "px_stone_bricks", STONE_DARK, ib)
		curtain("z", sx * 56.6, 262, 282, AY + 17, 3, 8, 0.6, ib)
		-- the stone arch under the span between the islet and the arena island
		box("ArchUnder", sx * 98, isl.y - 12, 264, sx * 88, isl.y - 4, 280, "px_stone_bricks", STONE_DARK, ib)
		box("ArchUnder", sx * 80, AY - 10, 264, sx * 66, AY - 4, 280, "px_stone_bricks", STONE_DARK, ib)
		box("ArchUnder", sx * 76, AY - 16, 266, sx * 70, AY - 10, 278, "px_stone_bricks", STONE_DARK, ib)
		curtain("z", sx * 66 - sx * 0.5, 264, 280, AY - 4, 4, 14, 0.5, ib)

		-- the islet itself: a broken lamp post, a ruin and vines (keep its middle free for the walk)
		brokenPost(c + sx * 12, 250, isl.y, 16, -sx, 0, true, ib)
		local rx, rz = c + sx * 10, 270
		box("IsletRuin", rx - 4, isl.y, rz - 6, rx + 4, isl.y + 8, rz - 2, "px_stone_bricks", STONE_T, ib)
		box("IsletRuin", rx, isl.y, rz - 2, rx + 4, isl.y + 12, rz + 6, "px_stone_bricks", STONE_T, ib)
		box("IsletRubble", rx - 4, isl.y, rz + 2, rx, isl.y + 4, rz + 6, "px_cobblestone", STONE_DARK, ib)
		decor(box("VineBlob", rx, isl.y + 12, rz - 2, rx + 4, isl.y + 14, rz + 6, "px_nether_wart", VINE_DARK, ib))
		curtain("x", rz - 6.5, rx - 4, rx + 4, isl.y + 8, 3, 7, 0.8, ib)
		box("IsletVines", c - sx * 14, isl.y - 0.15, 256, c - sx * 6, isl.y + 0.2, 262, "px_nether_wart", VINE_DARK, ib)
	end
end
print(("[build-inside-out] mansion + sky road + arena: %d parts"):format(count - startCount))
