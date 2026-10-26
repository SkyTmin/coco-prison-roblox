--!nocheck
-- ================================================================ market: the hero square, the crypt of the Undead King,
-- the ways down (the sinkhole stairs, the cliff cave tunnel, the smugglers' way). Everything below y 0 lives in the
-- voids 10-core carved out of the island (VOIDS): the crypt cylinder (r 64, y -52..-4), the sinkhole (SINK, r 18,
-- y -56..2), the cave box (x 160..224, z -120..-96 in 8-stud cells, y -52..-24), the hatch shaft (x 32..48,
-- z -72..-56, y -52..2) and the smugglers' corridors (x 32..48, z -120..-56 and x 32..64, z -120..-96, y -52..-24).
-- The concept's crypt panel: huge dark square pillars with skull faces, soul lanterns on chains, a bone throne on a
-- stepped dais with a crowned skeleton, a ring-patterned floor, a gallery with stairs, cobwebs, skulls on posts.
-- THE ROUTE DOWN (local studs, every flight walkable: visible steps on the kit's invisible ramp):
--   plaza east of the hole (x 112, z -104..-88, y 0) → SinkStair west through the hole (x 112 → 72, y 0 → -20; it
--   rests on the SW pillar) → landing x 56..72, z -104..-88 (y -20) → CryptStair north (z -104 → -124, y -20 → -32)
--   → landing x 56..72, z -132..-124 (y -32) = the west end of the gallery (north half ring r 48..56, top y -32) →
--   GalleryStairW (z -156..-148, x 84 → 116, y -32 → -48) or GalleryStairE (x 144..152, z -148 → -120) → the floor.
local crypt = folder("Crypt")
local c0 = count
local CX, CZ = CRYPT.x, CRYPT.z
local FLOOR, VAULT = CRYPT.floor, CRYPT.vault -- -48, -8
local GAL = -32 -- the gallery top
local BONE = Color3.fromRGB(232, 224, 200)
-- over blackstone, lifted [Studio 26.10: at 128 the arena floor, the walls and the pillars read black in the dark
-- crypt]: the texture keeps its own dark grey
local DARK = Color3.fromRGB(205, 210, 222)
local CSTONE = CRYPT_STONE:Lerp(Color3.new(1, 1, 1), 0.25) -- the crypt's stone bricks (the plan's CRYPT_STONE, lifted)
local ROCK_T = Color3.fromRGB(135, 132, 128)
local function cdist(x, z)
	return math.sqrt((x - CX) ^ 2 + (z - CZ) ^ 2)
end
-- a point on a circle round the crypt centre; degrees: 0 east (+X), 90 south (+Z), -90 north
local function polar(r, deg)
	local a = math.rad(deg)
	return CX + r * math.cos(a), CZ + r * math.sin(a)
end
local function cellC(v)
	return math.floor(v / B) * B + B / 2
end
-- the 8-stud island cells the core carved for the sinkhole (the exact hole outline)
local function inSink(x, z)
	local g0 = -ISLAND_R - 16
	local cx = math.floor((x - g0) / 8) * 8 + g0 + 4
	local cz = math.floor((z - g0) / 8) * 8 + g0 + 4
	return (cx - SINK.x) ^ 2 + (cz - SINK.z) ^ 2 <= SINK.r * SINK.r
end
-- walkable structures (x0, z0, x1, z1)
local R_F1 = { 72, -104, 112, -88 } -- the sinkhole stair (in the hole, y -20..0)
local R_L1 = { 56, -104, 72, -88 }
local R_F2 = { 56, -124, 72, -104 }
local R_L2 = { 56, -132, 72, -124 }
local R_G1 = { 84, -156, 116, -148 }
local R_G2 = { 144, -148, 152, -120 }
local STAIR_RECTS = { R_L1, R_F2, R_L2, R_G1, R_G2 }
local function hits(r, x0, z0, x1, z1, pad)
	pad = pad or 0
	return x0 < r[3] + pad and x1 > r[1] - pad and z0 < r[4] + pad and z1 > r[2] - pad
end
local function onStairs(cx, cz, pad)
	for _, r in ipairs(STAIR_RECTS) do
		if hits(r, cx - 2, cz - 2, cx + 2, cz + 2, pad) then
			return true
		end
	end
	return false
end
-- the four huge pillars (3×3 blocks): x, z, top; the SW one carries the sinkhole stair
local PILLARS = { { 88, -132, VAULT }, { 132, -132, VAULT }, { 142, -98, VAULT }, { 86, -96, -24 } }
local THRONE_DEG, THRONE_R, SWORD_DEG = 55, 44, 80
-- where loose decor must not land (stairs, pillars, the pool, the throne, the sword, the two entrance lanes)
local KEEP = {
	R_L1,
	R_F2,
	R_L2,
	R_G1,
	R_G2,
	{ 80, -116, 104, -102 },
	{ 78, -104, 94, -88 },
	{ 80, -140, 96, -124 },
	{ 124, -140, 140, -124 },
	{ 134, -106, 150, -90 },
	{ 118, -92, 154, -56 },
	{ 110, -72, 126, -56 },
	{ 150, -118, 184, -98 },
	{ 36, -118, 74, -98 },
}
local function free(x, z, pad)
	for _, r in ipairs(KEEP) do
		if hits(r, x - pad, z - pad, x + pad, z + pad) then
			return false
		end
	end
	return true
end
-- a textured part at a CFrame (rotated pieces of props)
local function rb(name, cf, sx, sy, sz, variant, tint, parent)
	local p = part(name, Vector3.new(sx, sy, sz), cf, tint, nil, parent or crypt)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- merged x-runs over 4-stud cells: fn(cx, cz) -> key, spans { {y0, y1, variant, tint, name}, ... } (or nil)
local function gridRuns(name, x0, x1, z0, z1, fn, parent)
	for z = z0, z1 - B, B do
		local runX, runKey, runSpans = nil, nil, nil
		local function flush(xe)
			if runKey then
				for _, s in ipairs(runSpans) do
					box(s[5] or name, runX, s[1], z, xe, s[2], z + B, s[3], s[4], parent)
				end
			end
			runKey = nil
		end
		for x = x0, x1 - B, B do
			local key, spans = fn(x + B / 2, z + B / 2)
			if key ~= runKey then
				flush(x)
				if key then
					runX, runKey, runSpans = x, key, spans
				end
			end
		end
		flush(x1)
	end
end
-- the body under a kit staircase (same step maths as kit `stairs`), in groups of 4 steps: solid down to baseY, or
-- (baseY nil) a 10-stud thick stepped underside; sideOff = a stepped side wall 2 wide, 3 above the steps
local function stairBody(alongX, cross, a0, a1, y0, rise, w, baseY, variant, tint, sideOff, parent)
	local run = math.abs(a1 - a0)
	local dir = if a1 > a0 then 1 else -1
	local steps = math.max(1, math.floor(run / 2))
	local stepD = run / steps
	local function slab(name, c0_, c1_, p0, p1, ya, yb)
		local lo, hi = math.min(p0, p1), math.max(p0, p1)
		if yb - ya < 0.2 then
			return
		end
		if alongX then
			box(name, lo, ya, c0_, hi, yb, c1_, variant, tint, parent)
		else
			box(name, c0_, ya, lo, c1_, yb, hi, variant, tint, parent)
		end
	end
	for k = 0, steps - 1, 4 do
		local kn = math.min(steps, k + 4)
		local lowTop = y0 + (k + 1) * rise / steps
		local highTop = y0 + kn * rise / steps
		local p0, p1 = a0 + dir * (k * stepD + 0.1), a0 + dir * (kn * stepD - 0.1)
		local bottom = baseY or (lowTop - 10)
		-- 0.1 narrower than the steps so no face is shared with them
		slab("StairBody", cross - w / 2 + 0.1, cross + w / 2 - 0.1, p0, p1, bottom, lowTop - 0.5)
		if sideOff then
			slab("StairSide", cross + sideOff - 1, cross + sideOff + 1, p0, p1, bottom, highTop + 3)
		end
	end
end
-- a standing skeleton statue (s = scale, ≈ 11.7·s tall), facing −Z of cf (cf = the feet)
local function skeleton(cf, s, parent, crown)
	local function bp(name, x, y, z, sx, sy, sz, variant, tint)
		return rb(name, cf * CFrame.new(x * s, y * s, z * s), sx * s, sy * s, sz * s, variant or "px_white_stone_bricks", tint or BONE, parent)
	end
	bp("SkelLeg", -0.9, 2, 0, 1, 4, 1)
	bp("SkelLeg", 0.9, 2, 0, 1, 4, 1)
	bp("SkelPelvis", 0, 4.5, 0, 3, 1, 1.6)
	bp("SkelSpine", 0, 5.6, 0, 1, 1.2, 1)
	bp("SkelRibs", 0, 7.6, 0, 3.4, 2.8, 2)
	bp("SkelArm", -2.2, 7.2, 0, 1, 4, 1)
	bp("SkelArm", 2.2, 7.2, 0, 1, 4, 1)
	bp("SkelSkull", 0, 10.4, 0, 2.6, 2.6, 2.6)
	for _, ex in ipairs({ -0.6, 0.6 }) do
		decor(bp("SkelEye", ex, 10.6, -1.32, 0.7, 0.7, 0.1, "px_coal_block", Color3.fromRGB(40, 40, 45)))
	end
	if crown then
		bp("SkelCrown", 0, 12, 0, 2.9, 0.6, 2.9, "px_gold_block")
	end
end
-- a skull block (2·s) with dark eyes, facing −Z of cf
local function skull(cf, s, parent)
	rb("Skull", cf, 2 * s, 2 * s, 2 * s, "px_white_stone_bricks", BONE, parent)
	for _, ex in ipairs({ -0.45, 0.45 }) do
		decor(rb("SkullEye", cf * CFrame.new(ex * s, 0.15 * s, -1.02 * s), 0.6 * s, 0.6 * s, 0.1, "px_coal_block", Color3.fromRGB(40, 40, 45), parent))
	end
end
-- a cobweb: Minecraft cross sprite (two crossed planes with the web decal), decor only (not tagged Cobweb)
local WEB = TEXCFG.sprites and TEXCFG.sprites.cobweb
local function cobweb(x, y, z, size, parent)
	for _, yaw in ipairs({ math.pi / 4, -math.pi / 4 }) do
		local p = decor(part("CobwebSprite", Vector3.new(size * 1.41, size, 0.05), at(x, y, z) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(235, 235, 235), Enum.Material.SmoothPlastic, parent))
		p.CastShadow = false
		if WEB then
			p.Transparency = 1
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local d = Instance.new("Decal")
				d.Texture = WEB
				d.Face = face
				d.Parent = p
			end
		else
			p.Transparency = 0.65
		end
	end
end
-- a bone lying on the floor (shaft + two knobs)
local function bone(x, y, z, yaw, parent)
	local cf = at(x, y + 0.4, z) * CFrame.Angles(0, yaw, 0)
	decor(rb("Bone", cf, 0.8, 0.8, 3.2, "px_white_stone_bricks", BONE, parent))
	for _, e in ipairs({ -1.7, 1.7 }) do
		decor(rb("BoneKnob", cf * CFrame.new(0, 0.15, e), 1.4, 1.1, 0.9, "px_white_stone_bricks", BONE, parent))
	end
end
-- a wax candle with a small warm flame
local function candle(pos, parent)
	part("Candle", Vector3.new(0.8, 1.6, 0.8), CFrame.new(pos + Vector3.new(0, 0.8, 0)), Color3.fromRGB(235, 225, 200), Enum.Material.SmoothPlastic, parent)
	local flame = decor(part("CandleFlame", Vector3.new(0.35, 0.6, 0.35), CFrame.new(pos + Vector3.new(0, 1.9, 0)), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, parent))
	light(flame, 10, 0.8, Color3.fromRGB(255, 180, 100))
end
local function vaultBottom(x, z)
	local d = cdist(x, z)
	if d >= 48 then
		return -16
	elseif d >= 40 then
		return -12
	end
	return VAULT
end
-- a soul lantern hanging on a chain from the vault (local x, y, z)
local function hangLantern(x, y, z, parent)
	lantern(V(x, y, z), parent, true, BY + vaultBottom(x, z) + 1)
end

-- ================================================================ the crypt shell: floor, walls, vault, gallery
local shell = folder("Shell", crypt)
do
	-- the floor: concentric rings of light and dark stone with a dark cross (the concept's floor pattern)
	local function sp(variant, tint)
		return { { -52, FLOOR, variant, tint, "CryptFloor" } }
	end
	local SP = {
		c = sp("px_obsidian", nil),
		l = sp("px_stone_bricks", Color3.fromRGB(152, 154, 162)),
		m = sp("px_stone_bricks", Color3.fromRGB(130, 132, 142)),
		d = sp("px_blackstone_bricks", DARK),
		t = sp("px_basalt", Color3.fromRGB(105, 150, 155)),
	}
	gridRuns("CryptFloor", 48, 172, -172, -48, function(cx, cz)
		local d = cdist(cx, cz)
		if d >= 56 then
			return nil
		end
		local cross = (math.abs(cx - CX) < 2.5 or math.abs(cz - CZ) < 2.5) and d >= 10 and d < 38
		local k
		if d < 6 then
			k = "c"
		elseif cross or (d >= 10 and d < 14) or (d >= 34 and d < 38) or d >= 50 then
			k = "d"
		elseif d >= 22 and d < 26 then
			k = "t"
		elseif d >= 26 and d < 34 then
			k = "m"
		else
			k = "l"
		end
		return k, SP[k]
	end, shell)

	-- the wall ring r 56..68 (a solid annulus: the carved rock beyond never shows), dark bricks below, a basalt band at
	-- the gallery height, stone bricks above; doorways for the cave tunnel (east, 20 high) and the smugglers (west, 12)
	local LOW = { -52, -36, "px_blackstone_bricks", DARK, "CryptWallLow" }
	local BAND = { -36, -32, "px_basalt", Color3.fromRGB(112, 120, 128), "CryptWallBand" }
	local HIGH = { -32, -4, "px_stone_bricks", CSTONE, "CryptWall" }
	local W = { LOW, BAND, HIGH }
	local T = { { -52, FLOOR, "px_blackstone_bricks", DARK, "CryptWallLow" }, { -28, -4, "px_stone_bricks", CSTONE, "CryptWall" } }
	local S = { BAND, HIGH } -- the smugglers' doorway: its floor is the corridor's
	gridRuns("CryptWall", 40, 180, -180, -40, function(cx, cz)
		local d = cdist(cx, cz)
		if d < 56 or d >= 68 then
			return nil
		end
		if cz > -116 and cz < -100 then
			if cx > CX then
				return "t", T
			end
			return "s", S
		end
		return "w", W
	end, shell)

	-- the vault: a slab under the ground with stepped rings toward the wall (upside-down stairs) and dark ribs
	local SLAB = { { VAULT, -4, "px_stone_bricks", CSTONE, "Vault" } }
	local RIB = { { -12, -4, "px_blackstone_bricks", DARK, "VaultRib" } }
	local RA = { { -12, -4, "px_stone_bricks", Color3.fromRGB(96, 100, 110), "VaultStep" } }
	local RB = { { -16, -4, "px_blackstone_bricks", DARK, "VaultStep" } }
	gridRuns("Vault", 48, 172, -172, -48, function(cx, cz)
		local d = cdist(cx, cz)
		if d >= 56 or inSink(cx, cz) then
			return nil
		end
		if d >= 48 and not onStairs(cx, cz) then
			return "b", RB
		elseif d >= 40 then
			return "a", RA
		elseif d < 8 then
			return "r", RIB
		end
		local dx, dz = cx - CX, cz - CZ
		for i = 0, 7 do
			local a = math.rad(22.5 + i * 45)
			if math.abs(-math.sin(a) * dx + math.cos(a) * dz) < 2.3 and (math.cos(a) * dx + math.sin(a) * dz) > 0 then
				return "r", RIB
			end
		end
		return "s", SLAB
	end, shell)

	-- the gallery: the north half of a ring r 48..56 at y -32 (cut where the flights pass under or meet it)
	local G = { { GAL - B, GAL, "px_stone_bricks", Color3.fromRGB(128, 130, 138), "Gallery" } }
	gridRuns("Gallery", 48, 172, -172, -120, function(cx, cz)
		local d = cdist(cx, cz)
		if d < 48 or d >= 56 or cz > -124 then
			return nil
		end
		for _, r in ipairs({ R_G1, R_G2, R_L2 }) do
			if hits(r, cx - 2, cz - 2, cx + 2, cz + 2) then
				return nil
			end
		end
		return "g", G
	end, shell)
	-- low merlons on the gallery's inner edge (away from the flights)
	for cx = 50, 170, B do
		for cz = -170, -126, B do
			local d = cdist(cx, cz)
			if d >= 48 and d < 50.5 and (cx + cz) % 12 == 0 and not onStairs(cx, cz, 6) then
				box("GalleryMerlon", cx - 2, GAL, cz - 2, cx + 2, GAL + 3, cz + 2, "px_blackstone_bricks", DARK, shell)
			end
		end
	end
	print(("[build-market] crypt shell: %d parts"):format(count - c0))
end

-- ================================================================ the way down: sinkhole stair, landings, gallery flights
do
	local f = folder("Stairs", crypt)
	-- the sinkhole stair: west through the hole, 16 wide, y 0 → -20, a thick stepped underside (from below it reads
	-- as an upside-down stair) resting on the SW pillar
	stairs("SinkStair", -96, 72, 112, -20, 20, 16, "px_mossy_stone_bricks", f, "x")
	stairBody(true, -96, 72, 112, -20, 20, 16, nil, "px_stone_bricks", CSTONE, nil, f)
	box("SinkStairSupport", 88, -24, -103.9, 94, -21, -88.1, "px_stone_bricks", CSTONE, f)
	-- the landing under the ground (y -20), its south parapet and two piers
	box("Landing", 56, -24, -104, 72, -20, -88, "px_stone_bricks", Color3.fromRGB(140, 142, 148), f)
	box("LandingParapet", 56, -20, -90, 72, -17, -88, "px_blackstone_bricks", DARK, f)
	box("LandingPier", 56, FLOOR, -92, 60, -24, -88, "px_blackstone_bricks", DARK, f)
	box("LandingPier", 68, FLOOR, -92, 72, -24, -88, "px_blackstone_bricks", DARK, f)
	-- north along the west wall to the gallery (y -20 → -32), bridging the smugglers' doorway; a stepped side wall
	stairs("CryptStair", 64, -124, -104, -32, 12, 16, "px_stone_bricks", f)
	stairBody(false, 64, -124, -104, -32, 12, 16, nil, "px_stone_bricks", CSTONE, 9, f)
	-- the gallery's west landing, solid to the floor, with its side wall
	box("GalleryLanding", 56, FLOOR, -132, 72, GAL, -124, "px_stone_bricks", Color3.fromRGB(128, 130, 138), f)
	box("GalleryLandingSide", 72, FLOOR, -132, 74, GAL + 3, -124, "px_blackstone_bricks", DARK, f)
	-- two flights from the gallery down to the arena floor, solid, a stepped wall on the arena side
	stairs("GalleryStairW", -152, 116, 84, FLOOR, 16, 8, "px_blackstone_bricks", f, "x")
	stairBody(true, -152, 116, 84, FLOOR, 16, 8, FLOOR, "px_blackstone_bricks", DARK, 5, f)
	stairs("GalleryStairE", 148, -120, -148, FLOOR, 16, 8, "px_blackstone_bricks", f)
	stairBody(false, 148, -120, -148, FLOOR, 16, 8, FLOOR, "px_blackstone_bricks", DARK, -5, f)
	-- lanterns at the landings
	lantern(V(58, -17.2, -102), f, true)
	lantern(V(58, GAL + 3.8, -130), f, true)
	box("LanternBlock", 56, -20, -104, 60, -18, -100, "px_blackstone_bricks", DARK, f)
end

-- ================================================================ pillars, pilasters, statues
do
	local f = folder("Pillars", crypt)
	for _, pl in ipairs(PILLARS) do
		local x, z, top = pl[1], pl[2], pl[3]
		box("PillarBase", x - 8, FLOOR, z - 8, x + 8, FLOOR + 2, z + 8, "px_blackstone_bricks", DARK, f)
		local shaft = box("Pillar", x - 6, FLOOR + 2, z - 6, x + 6, top - 4, z + 6, "px_blackstone_bricks", Color3.fromRGB(185, 190, 202), f)
		pillarTag(shaft)
		box("PillarBand", x - 7, -32, z - 7, x + 7, -30, z + 7, "px_basalt", Color3.fromRGB(112, 120, 128), f)
		box("PillarCapital", x - 7.5, top - 4, z - 7.5, x + 7.5, top, z + 7.5, "px_stone_bricks", CSTONE, f)
		-- a skull carved into each face near the top
		local sy = top - 12
		for _, fc in ipairs({ { 0, -1 }, { 0, 1 }, { -1, 0 }, { 1, 0 } }) do
			local face = V(x + fc[1] * 6, sy, z + fc[2] * 6)
			local cf = CFrame.lookAt(face, face + Vector3.new(fc[1], 0, fc[2]))
			decor(rb("PillarSkull", cf * CFrame.new(0, 0, -0.2), 7, 7, 0.4, "px_white_stone_bricks", BONE, f))
			for _, ex in ipairs({ -1.6, 1.6 }) do
				decor(rb("PillarSkullEye", cf * CFrame.new(ex, 0.9, -0.45), 2, 2, 0.2, "px_coal_block", Color3.fromRGB(35, 35, 40), f))
			end
			decor(rb("PillarSkullNose", cf * CFrame.new(0, -0.8, -0.45), 0.9, 1.3, 0.2, "px_coal_block", Color3.fromRGB(35, 35, 40), f))
			decor(rb("PillarSkullTeeth", cf * CFrame.new(0, -2.5, -0.45), 4, 0.8, 0.2, "px_coal_block", Color3.fromRGB(35, 35, 40), f))
		end
		-- two soul lanterns on brackets (east and west faces)
		local ly = if top > -20 then -28 else -36
		for _, sx in ipairs({ -1, 1 }) do
			rb("PillarArm", at(x + sx * 7.5, ly + 2.6, z), 3, 0.8, 0.8, "px_dark_oak_log", nil, f)
			lantern(V(x + sx * 8.6, ly, z), f, true, BY + ly + 2.2)
		end
	end
	-- thinner pilasters at the wall line: under the gallery they carry it, in the south they run to the vault
	for _, deg in ipairs({ -130, -110, -90, -70, -50, -30, 25, 85, 105, 125, 145 }) do
		local x, z = polar(54, deg)
		x, z = cellC(x), cellC(z)
		local top = if z < -124 then GAL - B else -16
		box("Pilaster", x - 2, FLOOR, z - 2, x + 2, top, z + 2, "px_blackstone_bricks", DARK, f)
		box("PilasterBase", x - 3, FLOOR, z - 3, x + 3, FLOOR + 2, z + 3, "px_stone_bricks", CSTONE, f)
		box("PilasterCap", x - 3, top - 2, z - 3, x + 3, top, z + 3, "px_stone_bricks", CSTONE, f)
	end
	-- skeleton statues in the bays between the pilasters (small under the gallery, tall in the south) with a hood
	local function statue(deg, r, s, hood)
		local x, z = polar(r, deg)
		local base = CFrame.lookAt(V(x, FLOOR, z), V(CX, FLOOR, CZ))
		rb("StatuePlinth", base * CFrame.new(0, 1, 0), 5, 2, 5, "px_stone_bricks", CSTONE, f)
		skeleton(base * CFrame.new(0, 2, 0), s, f)
		if hood then
			rb("StatueHood", base * CFrame.new(0, 2 + 12 * s + 2, 1.5), 10, 2, 5, "px_blackstone_bricks", DARK, f)
		end
	end
	for _, deg in ipairs({ -140, -100, -80, -60 }) do
		statue(deg, 52, 0.8, false)
	end
	for _, deg in ipairs({ 95, 115, 135 }) do
		statue(deg, 52, 1.3, true)
	end
end

-- ================================================================ the throne of the Undead King (south-east)
do
	local f = folder("Throne", crypt)
	local px, pz = polar(THRONE_R, THRONE_DEG)
	-- local frame: −Z looks at the arena centre, +Z goes to the wall
	local tcf = CFrame.lookAt(V(px, FLOOR, pz), V(CX, FLOOR, CZ))
	local W = "px_white_stone_bricks"
	local GOLD = "px_gold_block"
	local function tb(name, x, y, z, sx, sy, sz, variant, tint)
		return rb(name, tcf * CFrame.new(x, y, z), sx, sy, sz, variant, tint, f)
	end
	-- the stepped dais (2-stud steps)
	tb("Dais", 0, 1, 2, 24, 2, 20, "px_blackstone_bricks", DARK)
	tb("Dais", 0, 3, 4.5, 18, 2, 15, "px_basalt", Color3.fromRGB(120, 125, 135))
	tb("Dais", 0, 5, 7, 13, 2, 10, "px_obsidian")
	-- the bone throne with a gold crown motif
	tb("ThroneSeat", 0, 7.5, 8.5, 10, 3, 7, W, BONE)
	tb("ThroneBack", 0, 19, 12.75, 12, 20, 2.5, W, BONE)
	tb("ThroneBack", 0, 30, 12.75, 8, 2, 2.5, W, BONE)
	tb("ThroneBack", 0, 32, 12.75, 4, 2, 2.5, W, BONE)
	tb("ThroneGold", 0, 30.2, 11.3, 9, 1, 0.6, GOLD)
	for _, c in ipairs({ { -3.5, 31.5 }, { 0, 32.4 }, { 3.5, 31.5 } }) do
		tb("ThroneGold", c[1], c[2], 11.3, 1.8, 2, 0.6, GOLD)
	end
	for _, sx in ipairs({ -1, 1 }) do
		tb("ThroneArm", sx * 6.25, 8, 8.5, 2.5, 4, 7, W, BONE)
		tb("ThroneArmSkull", sx * 6.25, 11.25, 5.6, 2.5, 2.5, 2.5, W, BONE)
		tb("ThronePost", sx * 7.25, 16, 12.5, 2, 20, 2, W, BONE)
		tb("ThroneGold", sx * 7.25, 27.2, 12.5, 2.6, 2.4, 2.6, GOLD)
	end
	-- the crowned skeleton king seated on it
	tb("KingPelvis", 0, 10, 8.5, 6, 2, 4, W, BONE)
	for _, sx in ipairs({ -1, 1 }) do
		tb("KingThigh", sx * 1.8, 10.2, 4.5, 2, 2, 6, W, BONE)
		tb("KingShin", sx * 1.8, 6.75, 1.8, 2, 5.5, 2, W, BONE)
		tb("KingFoot", sx * 1.8, 4.5, 0.6, 2.4, 1, 3, W, BONE)
		tb("KingUpperArm", sx * 4.6, 16, 9.5, 1.8, 5, 1.8, W, BONE)
		tb("KingForearm", sx * 5.6, 10.9, 7, 1.8, 1.8, 5, W, BONE)
		tb("KingHand", sx * 5.6, 10.8, 4, 2.4, 1.6, 2.4, W, BONE)
	end
	tb("KingSpine", 0, 12.5, 10, 1.6, 3, 1.6, W, BONE)
	tb("KingRibs", 0, 16, 9.5, 7, 6, 4, W, BONE)
	for _, ry in ipairs({ 14.8, 16.8 }) do
		decor(tb("KingRibGap", 0, ry, 9.5, 7.1, 0.6, 4.1, "px_coal_block", Color3.fromRGB(40, 40, 46)))
	end
	tb("KingShoulders", 0, 18.8, 9.5, 10, 1.6, 3, W, BONE)
	tb("KingNeck", 0, 20.2, 9.5, 1.6, 1.6, 1.6, W, BONE)
	tb("KingSkull", 0, 24, 8.5, 6, 6, 6, W, BONE)
	tb("KingJaw", 0, 20.6, 7.5, 4.4, 1.4, 4, W, BONE)
	for _, ex in ipairs({ -1.4, 1.4 }) do
		decor(tb("KingEye", ex, 24.6, 5.4, 1.8, 1.8, 0.3, "px_coal_block", Color3.fromRGB(30, 30, 36)))
		-- the only glowing eyes in the crypt: a small teal accent
		decor(part("KingEyeGlow", Vector3.new(0.8, 0.8, 0.2), tcf * CFrame.new(ex, 24.6, 5.2), SOUL_GLOW, Enum.Material.Neon, f))
	end
	decor(tb("KingNose", 0, 23, 5.4, 0.8, 1.2, 0.3, "px_coal_block", Color3.fromRGB(30, 30, 36)))
	light(part("KingGlowLight", Vector3.new(0.2, 0.2, 0.2), tcf * CFrame.new(0, 24.6, 4.6), nil, nil, f), 12, 0.8, SOUL_GLOW).Parent.Transparency = 1
	tb("KingCrown", 0, 27.7, 8.5, 6.6, 1.4, 6.6, GOLD)
	for _, c in ipairs({ { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } }) do
		tb("KingCrownSpike", c[1], 29.4, 8.5 + c[2], 1.6, 2, 1.6, GOLD)
	end
	-- two skeleton guards on the lowest step, soul lanterns on posts, candles, dark banners on the wall
	for _, sx in ipairs({ -1, 1 }) do
		skeleton(tcf * CFrame.new(sx * 9.5, 2, -5), 1.3, f)
		tb("ThroneLanternPost", sx * 14, 5, -6, 2, 10, 2, "px_blackstone_bricks", DARK)
		lantern((tcf * CFrame.new(sx * 14, 10.8, -6)).Position, f, true)
		banner(tcf * CFrame.new(sx * 11, 18, 10.4), Color3.fromRGB(58, 44, 78), f, BONE)
	end
	for _, c in ipairs({ { -5, 4, -2 }, { 5, 4, -2 }, { -8, 4, -1 }, { 8, 4, -1 }, { -5.5, 6, 2.8 }, { 5.5, 6, 2.8 } }) do
		candle((tcf * CFrame.new(c[1], c[2], c[3])).Position, f)
	end
end

-- ================================================================ the ghost-sword statue, sarcophagi, the arena dressing
do
	local f = folder("GhostSword", crypt)
	local x, z = polar(47, SWORD_DEG)
	local scf = CFrame.lookAt(V(x, FLOOR, z), V(CX, FLOOR, CZ))
	local BLUE = Color3.fromRGB(120, 215, 235)
	local DEEP = Color3.fromRGB(70, 170, 190)
	local function sb(name, lx, ly, lz, sx, sy, sz, variant, tint)
		return rb(name, scf * CFrame.new(lx, ly, lz), sx, sy, sz, variant, tint, f)
	end
	sb("SwordMound", 0, 1.5, 0, 10, 3, 8, "px_cobblestone", Color3.fromRGB(110, 112, 118))
	sb("SwordMound", 1, 3.5, 1, 6, 1.5, 5, "px_blackstone", DARK)
	local blade = sb("GhostBlade", 0, 13, 0, 4, 20, 1.6, "px_iron_block", BLUE)
	blade.Transparency = 0.15
	sb("GhostGuard", 0, 24, 0, 12, 2, 2.4, "px_iron_block", DEEP)
	for _, gx in ipairs({ -6.9, 6.9 }) do
		sb("GhostGuardTip", gx, 25.5, 0, 2, 3, 2.4, "px_iron_block", DEEP)
	end
	sb("GhostGrip", 0, 28, 0, 2, 6, 2, "px_dark_oak_log")
	sb("GhostPommel", 0, 32, 0, 3, 2, 3, "px_iron_block", DEEP)
	-- the one neon accent: a thin core down the blade, a soft light and a few drifting motes
	local core = decor(part("GhostCore", Vector3.new(0.8, 18, 1.7), scf * CFrame.new(0, 13, 0), Color3.fromRGB(120, 240, 255), Enum.Material.Neon, f))
	core.Transparency = 0.35
	light(core, 20, 1, SOUL_GLOW)
	emitter(core, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 4,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(180, 180),
		Size = NumberSequence.new(0.5, 0),
		Color = ColorSequence.new(SOUL_GLOW),
		LightEmission = 0.6,
		Transparency = NumberSequence.new(0.3, 1),
		Acceleration = Vector3.new(0, 1, 0),
	})
end
do
	local f = folder("Dressing", crypt)
	-- sarcophagi along the south-west wall (tangential), lids ajar, candles
	for _, deg in ipairs({ 105, 125 }) do
		local x, z = polar(45, deg)
		local cf = CFrame.lookAt(V(x, FLOOR, z), V(CX, FLOOR, CZ)) * CFrame.Angles(0, math.pi / 2, 0)
		rb("Sarcophagus", cf * CFrame.new(0, 1.5, 0), 5, 3, 10, "px_blackstone_bricks", DARK, f)
		rb("SarcophagusLid", cf * CFrame.new(0.6, 3.5, 0.8) * CFrame.Angles(0, math.rad(9), 0), 6, 1, 11, "px_stone_bricks", CSTONE, f)
		skull(cf * CFrame.new(-1.6, 4.6, -4.2), 0.7, f)
		candle((cf * CFrame.new(3.4, 0, 4.5)).Position, f)
	end
	-- skulls on posts round the edge of the open arena floor
	for i = 0, 14 do
		local x, z = polar(41, i * 24 + 6)
		if free(x, z, 3) then
			rb("SkullPost", at(x, FLOOR + 3, z), 1, 6, 1, "px_dark_oak_log", nil, f)
			skull(CFrame.lookAt(V(x, FLOOR + 7, z), V(CX, FLOOR + 7, CZ)), 1, f)
		end
	end
	-- soul lanterns on chains from the vault: a centre crown, two rings, over the gallery
	for i = 0, 3 do
		local x, z = polar(7, 45 + i * 90)
		hangLantern(x, -22, z, f)
	end
	for i = 0, 7 do
		local x, z = polar(22, 22.5 + i * 45)
		if not inSink(x, z) then
			hangLantern(x, -26, z, f)
		end
	end
	for i = 0, 11 do
		local x, z = polar(42, 15 + i * 30)
		if not inSink(x, z) and not onStairs(x, z, 3) then
			hangLantern(x, -24, z, f)
		end
	end
	for _, deg in ipairs({ -150, -126, -102, -78, -54, -30 }) do
		local x, z = polar(52, deg)
		hangLantern(x, -24, z, f)
	end
	-- empty chains with shackles
	for _, c in ipairs({ { 60, 10 }, { 100, 14 }, { 140, 8 }, { -20, 12 }, { -170, 9 }, { 20, 16 }, { 155, 11 } }) do
		local x, z = polar(47 + (c[1] % 3), c[1])
		if free(x, z, 1) and not inSink(x, z) then
			local top = vaultBottom(x, z) + 1
			decor(part("Chain", Vector3.new(0.3, c[2], 0.3), at(x, top - c[2] / 2, z), Color3.fromRGB(55, 55, 60), Enum.Material.Metal, f))
			decor(part("Shackle", Vector3.new(1.4, 1, 1.4), at(x, top - c[2] - 0.4, z), Color3.fromRGB(60, 60, 66), Enum.Material.Metal, f))
		end
	end
	-- cobwebs in the high corners, under the gallery, by the throne
	for _, deg in ipairs({ 35, 75, 95, 115, 135, -140, -120, -60, -20, 20 }) do
		local x, z = polar(54, deg)
		cobweb(x, -20, z, 6, f)
	end
	for _, deg in ipairs({ -118, -88, -62 }) do
		local x, z = polar(54, deg)
		cobweb(x, -39, z, 4, f)
	end
	-- bones and skull piles by the walls
	for _ = 1, 22 do
		local x, z = polar(rng:NextNumber(43, 54), rng:NextNumber(-180, 180))
		if free(x, z, 2) then
			bone(x, FLOOR, z, rng:NextNumber() * math.pi, f)
		end
	end
	for _ = 1, 9 do
		local x, z = polar(rng:NextNumber(46, 53), rng:NextNumber(-180, 180))
		if free(x, z, 3) then
			for k = 1, rng:NextInteger(2, 3) do
				local yaw = rng:NextNumber() * math.pi * 2
				skull(at(x + math.cos(yaw) * 1.6, FLOOR + 1, z + math.sin(yaw) * 1.6) * CFrame.Angles(0, yaw, 0), 1, f)
				if k == 3 then
					skull(at(x, FLOOR + 3, z) * CFrame.Angles(0, yaw + 1, 0), 1, f)
				end
			end
		end
	end
end

-- ================================================================ THE HERO: the collapsed fountain square on top
do
	local hero = folder("FountainSquare", crypt)
	local STONE_MIX = { "px_stone_bricks", "px_mossy_stone_bricks", "px_cobblestone", "px_mossy_cobblestone" }
	local TINT = Color3.fromRGB(150, 150, 148)
	local FOUNT = { 84, -114, 100, -104 }
	-- the broken edge of the hole: lips flush with the ground, blocks hanging below them, blocks sliding into the hole;
	-- cracked slabs, roots and vines on the ground side (never over the stair)
	for cx = 70, 114, B do
		for cz = -114, -78, B do
			local hole = inSink(cx, cz)
			local nb = { { 4, 0 }, { -4, 0 }, { 0, 4 }, { 0, -4 } }
			if hole then
				local edge = false
				for _, n in ipairs(nb) do
					if not inSink(cx + n[1], cz + n[2]) then
						edge = true
					end
				end
				if edge and not hits(R_F1, cx - 2, cz - 2, cx + 2, cz + 2) and not hits(FOUNT, cx - 2, cz - 2, cx + 2, cz + 2) then
					local r = rng:NextNumber()
					if r < 0.5 then
						box("BrokenLip", cx - 2, -4, cz - 2, cx + 2, 0, cz + 2, pick(STONE_MIX), TINT, hero)
						if rng:NextNumber() < 0.55 then
							box("BrokenLip", cx - 2, -8, cz - 2, cx + 2, -4, cz + 2, "px_stone", ROCK_T, hero)
						end
					elseif r < 0.75 then
						rb("SlidingBlock", at(cx, -3, cz) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber() * 3, math.rad(rng:NextNumber(-20, 20))), 4, 4, 4, pick(STONE_MIX), TINT, hero)
					end
				end
			else
				local into
				for _, n in ipairs(nb) do
					if inSink(cx + n[1], cz + n[2]) and not into then
						into = n
					end
				end
				if into and not hits(R_F1, cx + into[1] - 2, cz + into[2] - 2, cx + into[1] + 2, cz + into[2] + 2) then
					local ux, uz = into[1] / 4, into[2] / 4
					if rng:NextNumber() < 0.35 then
						rb("CrackedSlab", at(cx, 0.4, cz) * CFrame.Angles(math.rad(rng:NextNumber(-5, 5)), 0, math.rad(rng:NextNumber(-5, 5))), 4, 1, 4, pick(STONE_MIX), TINT, hero)
					end
					if rng:NextNumber() < 0.45 then
						local len = rng:NextNumber(6, 16)
						decor(rb("Root", at(cx + ux * 2.6 + uz * rng:NextNumber(-1.5, 1.5), -7 - len / 2, cz + uz * 2.6 + ux * rng:NextNumber(-1.5, 1.5)), 1.2, len, 1.2, "px_dark_oak_log", Color3.fromRGB(150, 120, 95), hero))
					end
					if rng:NextNumber() < 0.35 then
						local len = rng:NextNumber(8, 18)
						local vine = decor(rb("Vine", at(cx + ux * 2.2, -4 - len / 2, cz + uz * 2.2), if ux ~= 0 then 0.3 else 3.6, len, if uz ~= 0 then 0.3 else 3.6, "px_grass_top", Color3.fromRGB(90, 140, 70), hero))
						vine.CastShadow = false
					end
				end
			end
		end
	end

	-- the big two-tier fountain at the north edge of the hole, tilted south and half sunk into it
	local fcf = at(92, -1, -116) * CFrame.Angles(math.rad(13), 0, math.rad(-5))
	local function fb(name, x, y, z, sx, sy, sz, variant, tint)
		return rb(name, fcf * CFrame.new(x, y, z), sx, sy, sz, variant, tint, hero)
	end
	local function water(p, tr)
		p.Transparency = tr or 0.25
		p.CanCollide = false
		p.CanQuery = false
		p.CastShadow = false
		return p
	end
	fb("FountainBasin", 0, -1, 0, 16, 2, 16, "px_stone_bricks", TINT)
	fb("FountainRim", 0, 1, -7, 16, 4, 2, "px_stone_bricks", TINT)
	fb("FountainRim", -7, 1, 0, 2, 4, 12, "px_mossy_stone_bricks", TINT)
	fb("FountainRim", 7, 1, 0, 2, 4, 12, "px_stone_bricks", TINT)
	fb("FountainRim", -5, 0.6, 7, 6, 3.2, 2, "px_mossy_stone_bricks", TINT) -- the south rim is broken in the middle
	fb("FountainRim", 5.5, 1, 7, 5, 4, 2, "px_stone_bricks", TINT)
	water(fb("FountainWater", 0, 1.9, 0, 12, 0.5, 12, "px_water"))
	fb("FountainColumn", 0, 4.5, 0, 4, 7, 4, "px_stone_bricks", TINT)
	fb("FountainBowl", 0, 8.5, 0, 10, 2, 10, "px_stone_bricks", TINT)
	water(fb("FountainBowlWater", 0, 9.6, 0, 8, 0.4, 8, "px_water"))
	fb("FountainSpout", 0, 11.5, 0, 2, 4, 2, "px_mossy_stone_bricks", TINT)
	fb("FountainCap", 0, 14, 0, 4, 1, 4, "px_stone_bricks", TINT)
	for _, s in ipairs({ { 0, 5.2, 4, 0.4, 6 }, { 0, -5.2, 4, 0.4, 6 }, { 5.2, 0, 0.4, 4, 6 }, { -5.2, 0, 0.4, 4, 6 } }) do
		water(fb("FountainStream", s[1], 5.5, s[2], s[3] * 1.5, s[5], s[4] * 1.5, "px_water"), 0.35)
	end
	-- a rim chunk broke off and lies on the hole's edge
	rb("FountainChunk", at(103, 1.6, -115) * CFrame.Angles(0.3, 0.7, 0.2), 4, 3, 2, "px_stone_bricks", TINT, hero)
	-- the waterfall: from the broken south rim straight down through the hole to the crypt floor
	local lip = (fcf * CFrame.new(0.25, 1.4, 8.4)).Position
	local top = lip.Y - BY
	water(rb("WaterSpill", CFrame.new(lip) * CFrame.new(0, -0.6, 0.7) * CFrame.Angles(math.rad(-55), 0, 0), 7, 0.6, 2.6, "px_water", nil, hero))
	local fall = water(rb("Waterfall", at(lip.X - BX, (top + FLOOR) / 2, lip.Z - BZ + 1.4), 7, top - FLOOR, 1.2, "px_water", nil, hero))
	water(rb("WaterfallFoam", at(lip.X - BX + 0.5, (top + FLOOR) / 2 - 2, lip.Z - BZ + 2.1), 5, top - FLOOR - 4, 0.6, "px_water", Color3.fromRGB(220, 240, 245), hero), 0.5)
	emitter(fall, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 5,
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(1, 2),
		SpreadAngle = Vector2.new(40, 40),
		Size = NumberSequence.new(2, 4),
		Color = ColorSequence.new(Color3.fromRGB(220, 240, 245)),
		Transparency = NumberSequence.new(0.7, 1),
		EmissionDirection = Enum.NormalId.Back,
	})
	-- the splash pool on the crypt floor (1-stud rim, walkable) and its mist
	local fz = lip.Z - BZ + 1.4
	box("PoolRim", 82, FLOOR, -114, 102, FLOOR + 1, -112, "px_stone_bricks", CSTONE, hero)
	box("PoolRim", 82, FLOOR, -105, 102, FLOOR + 1, -103, "px_stone_bricks", CSTONE, hero)
	box("PoolRim", 82, FLOOR, -112, 84, FLOOR + 1, -105, "px_stone_bricks", CSTONE, hero)
	box("PoolRim", 100, FLOOR, -112, 102, FLOOR + 1, -105, "px_stone_bricks", CSTONE, hero)
	water(box("PoolWater", 84, FLOOR + 0.3, -112, 100, FLOOR + 0.7, -105, "px_water", nil, hero), 0.2)
	local mist = decor(part("PoolMist", Vector3.new(10, 1, 5), at(lip.X - BX, FLOOR + 1, fz), nil, nil, hero))
	mist.Transparency = 1
	emitter(mist, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = 14,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(70, 70),
		Size = NumberSequence.new(3, 8),
		Color = ColorSequence.new(Color3.fromRGB(200, 235, 238)),
		Transparency = NumberSequence.new(0.6, 1),
		Acceleration = Vector3.new(0, 1.5, 0),
		LightEmission = 0.15,
	})

	-- warning fence pieces round the hole (broken, gaps), the sign and two lamps at the stair head
	for _, s in ipairs({
		{ 78, -114, 84, -114 },
		{ 100, -114, 106, -114 },
		{ 106, -114, 106, -104 },
		{ 106, -86, 106, -78 },
		{ 94, -78, 106, -78 },
		{ 78, -78, 88, -78 },
		{ 78, -86, 78, -78 },
		{ 70, -86, 78, -86 },
		{ 70, -98, 70, -86 },
		{ 70, -106, 70, -100 },
		{ 70, -106, 78, -106 },
		{ 78, -114, 78, -106 },
	}) do
		fence(s[1], s[2], s[3], s[4], hero, 0, WOOD)
	end
	zoneSign(124, -108, "Провал", math.pi / 2, hero)
	lampPost(118, -108, hero, false, 0)
	lampPost(118, -84, hero, false, math.pi)

	-- the ruined arcade round the square (r 50): columns, some broken with their drums lying by, lintels between the
	-- whole ones, a few low ruined wall bays; the west bay (the cross street) stays open
	local cols = {}
	for k = 0, 19 do
		local deg = k * 18
		if deg < 160 or deg > 200 then
			local x, z = polar(50, deg)
			x, z = cellC(x), cellC(z)
			local h = pick({ 4, 8, 12, 16, 16, 16 })
			cols[k] = { x, z, h }
			box("ArcadeBase", x - 3, 0, z - 3, x + 3, 1, z + 3, "px_stone_bricks", TINT, hero)
			box("ArcadeColumn", x - 2, 1, z - 2, x + 2, 1 + h, z + 2, if k % 2 == 0 then "px_stone_bricks" else "px_mossy_stone_bricks", TINT, hero)
			if h >= 16 then
				box("ArcadeCapital", x - 3, 17, z - 3, x + 3, 19, z + 3, "px_stone_bricks", TINT, hero)
			else
				local yaw = rng:NextNumber() * math.pi * 2
				local d = 6
				rb("ArcadeDrum", at(x + math.cos(yaw) * d, 2, z + math.sin(yaw) * d) * CFrame.Angles(0, yaw, math.pi / 2), 4, 6, 4, "px_mossy_stone_bricks", TINT, hero)
			end
		end
	end
	for k = 0, 19 do
		local a, b = cols[k], cols[(k + 1) % 20]
		if a and b then
			local pa, pb = V(a[1], 0, a[2]), V(b[1], 0, b[2])
			local len = (pb - pa).Magnitude
			if a[3] >= 16 and b[3] >= 16 then
				rb("ArcadeLintel", CFrame.lookAt((pa + pb) / 2 + Vector3.new(0, 21, 0), pb + Vector3.new(0, 21, 0)), 4, 4, len + 4, "px_stone_bricks", TINT, hero)
			elseif k % 5 == 1 then
				local cf = CFrame.lookAt((pa + pb) / 2, pb)
				for i = 1, 3 do
					local h = pick({ 4, 4, 8 })
					rb("RuinWall", cf * CFrame.new(0, h / 2, -len / 2 + (i - 0.5) * len / 3), 4, h, len / 3, pick(STONE_MIX), TINT, hero)
				end
			end
		end
	end

	-- dead trees, overturned benches, rubble
	for _, t in ipairs({ { 142, -80, 14 }, { 80, -140, 12 }, { 140, -140, 16 } }) do
		local x, z, h = t[1], t[2], t[3]
		local DEAD = Color3.fromRGB(120, 100, 85)
		box("DeadTrunk", x - 2, 0, z - 2, x + 2, h, z + 2, "px_oak_log", DEAD, hero)
		for i, br in ipairs({ { 1, 0.3 }, { -1, 0.6 }, { 0.4, -1 } }) do
			local a = V(x, h - 2 - i * 2, z)
			local b = a + Vector3.new(br[1] * 6, 4 + i, br[2] * 6)
			textured(beam("DeadBranch", a, b, 2, DEAD, hero), "px_oak_log", DEAD)
		end
	end
	for _, b in ipairs({ { 130, -124, 0.4 }, { 100, -140, 1.2 }, { 134, -92, -0.3 } }) do
		local bcf = at(b[1], 1.25, b[2]) * CFrame.Angles(0, b[3], 0) * CFrame.Angles(math.rad(90), 0, 0)
		rb("BenchSeat", bcf, 8, 1, 2.5, WOOD, nil, hero)
		for _, lx in ipairs({ -3, 3 }) do
			rb("BenchLeg", bcf * CFrame.new(lx, -1.6, 0), 1, 2.2, 2, WOOD_DARK, nil, hero)
		end
	end
	local placed = 0
	for _ = 1, 80 do
		if placed >= 26 then
			break
		end
		local x, z = polar(rng:NextNumber(14, 45), rng:NextNumber(-180, 180))
		local clear = not (inSink(x, z) or inSink(x + 6, z) or inSink(x - 6, z) or inSink(x, z + 6) or inSink(x, z - 6))
		clear = clear and (x - 92) ^ 2 + (z + 116) ^ 2 > 16 * 16 and not hits({ 106, -112, 128, -80 }, x - 3, z - 3, x + 3, z + 3)
		for _, t in ipairs({ { 142, -80 }, { 80, -140 }, { 140, -140 }, { 130, -124 }, { 100, -140 }, { 134, -92 } }) do
			if (x - t[1]) ^ 2 + (z - t[2]) ^ 2 < 49 then
				clear = false
			end
		end
		if clear then
			placed += 1
			rb("Rubble", at(x, 1, z) * CFrame.Angles(0, rng:NextNumber() * 3, math.rad(rng:NextNumber(-12, 12))), 4, 4, 4, pick(STONE_MIX), TINT, hero)
			if rng:NextNumber() < 0.5 then
				decor(rb("RubbleBit", at(x + rng:NextNumber(-4, 4), 1, z + rng:NextNumber(-4, 4)) * CFrame.Angles(rng:NextNumber(), rng:NextNumber() * 3, rng:NextNumber()), 2, 2, 2, pick(STONE_MIX), TINT, hero))
			end
		end
	end
end

-- ================================================================ the cliff cave tunnel (arena wall → the mouth at x 208)
do
	local f = folder("CaveTunnel", crypt)
	local ROUGH = { "px_stone", "px_cobblestone", "px_basalt", "px_stone" }
	-- the floor runs on to x 216 (the mouth frame is another part's); the crypt wall ring ends at x 176
	box("TunnelFloor", 176, -52, -120, 192, FLOOR, -96, "px_cobblestone", ROCK_T, f)
	box("TunnelFloor", 192, -52, -120, 204, FLOOR, -96, "px_gravel", Color3.fromRGB(160, 155, 150), f)
	box("TunnelFloor", 204, -52, -120, 216, FLOOR, -96, "px_cobblestone", ROCK_T, f)
	for i = 0, 2 do
		local xa = 176 + i * 12
		box("TunnelWall", xa, FLOOR, -120, xa + 12, -24, -116, pick(ROUGH), ROCK_T, f)
		box("TunnelWall", xa, FLOOR, -100, xa + 12, -24, -96, pick(ROUGH), ROCK_T, f)
	end
	box("TunnelCeiling", 176, -28, -116, 212, -24, -100, "px_stone", Color3.fromRGB(118, 116, 112), f)
	-- rough faces: half-buried blocks along the walls, a few hanging from the ceiling
	for x = 180, 208, 8 do
		for _, zc in ipairs({ -116, -100 }) do
			if rng:NextNumber() < 0.6 then
				cube("TunnelRock", x + rng:NextInteger(-1, 1), pick({ -42, -34, -30 }), zc, B, B, B, pick(ROUGH), ROCK_T, f)
			end
		end
	end
	for _ = 1, 5 do
		cube("TunnelDrip", rng:NextInteger(45, 52) * B, -30, pick({ -112, -104 }), B, B, B, pick(ROUGH), ROCK_T, f)
	end
	-- old mine timber every 3 blocks with a soul lantern
	for _, x in ipairs({ 182, 194, 206 }) do
		for _, zc in ipairs({ -115, -101 }) do
			box("TimberPost", x - 1, FLOOR, zc - 1, x + 1, -30, zc + 1, "px_oak_log", nil, f)
		end
		box("TimberBeam", x - 1, -30, -116, x + 1, -28, -100, "px_spruce_planks", nil, f)
		lantern(V(x, -33, -108), f, true, BY - 30)
	end
	-- the rails and a broken cart with spilled goods
	for _, zr in ipairs({ -110.5, -105.5 }) do
		decor(part("Rail", Vector3.new(48, 0.3, 0.4), at(190, FLOOR + 0.55, zr), Color3.fromRGB(95, 95, 100), Enum.Material.Metal, f))
	end
	for x = 168, 212, 4 do
		if x ~= 196 then
			textured(decor(part("Sleeper", Vector3.new(1.4, 0.4, 7), at(x, FLOOR + 0.2, -108), nil, nil, f)), "px_spruce_planks")
		end
	end
	local cart = at(198, FLOOR + 2, -103.5) * CFrame.Angles(math.rad(80), 0, math.rad(6))
	rb("CartBody", cart, 6, 3.5, 4, "px_iron_block", Color3.fromRGB(90, 90, 96), f)
	for _, wx in ipairs({ -2, 2 }) do
		decor(rb("CartWheel", cart * CFrame.new(wx, -2.1, 0), 1.6, 0.6, 1.6, "px_coal_block", nil, f))
	end
	for _, s in ipairs({ { 194, -106, WOOL_RED }, { 196, -110, WOOL_YELLOW }, { 201, -108, "coal" } }) do
		if s[3] == "coal" then
			cube("Spilled", s[1], FLOOR + 1, s[2], 2, 2, 2, "px_coal_block", nil, f)
		else
			cube("Spilled", s[1], FLOOR + 1, s[2], 2, 2, 2, "px_white_wool", s[3], f)
		end
	end
	cobweb(178, -31, -114, 5, f)
	cobweb(190, -31, -102, 5, f)
	cobweb(204, -31, -114, 4, f)
	bone(186, FLOOR, -103, 0.5, f)
	bone(209, FLOOR, -112, 2.1, f)
	skull(at(188, FLOOR + 1, -114) * CFrame.Angles(0, 1.2, 0), 1, f)
end

-- ================================================================ the smugglers' way: the hatch, the shaft, the corridors
do
	local f = folder("SmugglersWay", crypt)
	local COB = Color3.fromRGB(130, 128, 124)
	local PLAZA_T = Color3.fromRGB(163, 160, 154)
	-- corridor 1 (x 36..44 walkway, from the ladder at z -62 to z -116) and corridor 2 (z -100..-116, east into the
	-- crypt's west doorway); floors, walls, the low ceiling (12 high), all flush with the carved boxes
	box("SmugglerFloor", 32, -52, -120, 48, FLOOR, -56, "px_planks", Color3.fromRGB(180, 150, 110), f)
	box("SmugglerFloor", 48, -52, -116, 56, FLOOR, -100, "px_planks", Color3.fromRGB(180, 150, 110), f)
	box("SmugglerWall", 32, FLOOR, -120, 36, -24, -56, "px_cobblestone", COB, f)
	box("SmugglerWall", 44, FLOOR, -100, 48, -24, -56, "px_cobblestone", COB, f)
	box("SmugglerWall", 36, FLOOR, -120, 44, -24, -116, "px_cobblestone", COB, f)
	box("SmugglerCeiling", 36, -36, -116, 44, -24, -72, "px_stone", ROCK_T, f)
	-- the shaft: filled round an 8×8 opening (x 36..44, z -70..-62) from the corridor up to the plaza
	box("ShaftFill", 32, -24, -72, 36, -4, -56, "px_stone", ROCK_T, f)
	box("ShaftFill", 44, -24, -72, 48, -4, -56, "px_stone", ROCK_T, f)
	box("ShaftFill", 36, -36, -72, 44, -4, -70, "px_stone", ROCK_T, f)
	box("ShaftFill", 36, FLOOR, -62, 44, -4, -56, "px_stone_bricks", COB, f)
	-- the plaza surface over it and the trapdoor frame round the opening
	box("PlazaPatch", 32, -4, -72, 34, 0, -56, "px_stone_bricks", PLAZA_T, f)
	box("PlazaPatch", 46, -4, -72, 48, 0, -56, "px_stone_bricks", PLAZA_T, f)
	box("PlazaPatch", 34, -4, -60, 46, 0, -56, "px_stone_bricks", PLAZA_T, f)
	box("HatchFrame", 34, -4, -72, 46, 0, -70, WOOD_DARK, nil, f)
	box("HatchFrame", 34, -4, -62, 46, 0, -60, WOOD_DARK, nil, f)
	box("HatchFrame", 34, -4, -70, 36, 0, -62, WOOD_DARK, nil, f)
	box("HatchFrame", 44, -4, -70, 46, 0, -62, WOOD_DARK, nil, f)
	-- the lid stands open, leaning back on its hinge (north edge)
	rb("HatchLid", at(40, 3.9, -71.3) * CFrame.Angles(math.rad(-12), 0, 0), 8, 8, 0.8, "px_spruce_planks", nil, f)
	for _, hx in ipairs({ 37, 43 }) do
		decor(part("HatchHinge", Vector3.new(1.2, 0.6, 1.2), at(hx, 0.3, -70.6), Color3.fromRGB(60, 60, 64), Enum.Material.Metal, f))
	end
	crate(48.5, 0, -64, f, B, 0.2)
	-- the ladder on the opening's south face (z -62), corridor floor to the plaza (kit style: trusses + a face)
	local LH = 50
	for k = 0, 3 do
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Size = Vector3.new(2, LH, 2)
		truss.CFrame = at(37 + k * 2, FLOOR + LH / 2, -61.4)
		truss.Anchored = true
		truss.Transparency = 1
		truss.Parent = f
	end
	local plate = decor(part("LadderFace", Vector3.new(8, LH - 2, 0.2), at(40, FLOOR + (LH - 2) / 2, -62.15), nil, nil, f))
	plate.Transparency = 1
	if TEX.ladder then
		local tex = Instance.new("Texture")
		tex.Texture = TEX.ladder
		tex.Face = Enum.NormalId.Front
		tex.StudsPerTileU, tex.StudsPerTileV = B, B
		tex.Parent = plate
	end
	-- timber frames, lanterns (the smugglers' own, warm), the stash of dug wool, a table
	for _, z in ipairs({ -76, -88, -112 }) do
		for _, x in ipairs({ 36, 44 }) do
			box("TimberPost", x - 1, FLOOR, z - 1, x + 1, -36, z + 1, "px_oak_log", nil, f)
		end
		box("TimberBeam", 36, -38, z - 1, 44, -36, z + 1, "px_spruce_planks", nil, f)
	end
	lantern(V(40, -40, -82), f, false, BY - 36)
	lantern(V(40, -40, -106), f, false, BY - 36)
	lantern(V(41, -44, -66), f, false, BY - 36)
	for i, col in ipairs({ WOOL_RED, WOOL_YELLOW, WOOL_LIME, WOOL_RED, WOOL_LIME, WOOL_YELLOW }) do
		local x = 37.5 + ((i - 1) % 3) * 5
		local y = if i > 3 then FLOOR + B else FLOOR
		if i <= 3 or i == 5 then
			crate(x, y, -113.5, f)
			textured(decor(part("StashWool", Vector3.new(3.2, 1.2, 3.2), at(x, y + B + 0.3, -113.5), nil, nil, f)), "px_white_wool", col)
		else
			textured(cube("WoolBale", x, y + 2, -113.5, B, B, B, nil, nil, f), "px_white_wool", col)
		end
	end
	for _, b in ipairs({ { 52, -114 }, { 52, -102 } }) do
		barrel(b[1], FLOOR, b[2], f, "px_hay")
	end
	box("SmugglerTable", 38, FLOOR + 3, -98, 42, FLOOR + 3.6, -92, WOOD, nil, f)
	box("SmugglerTableLeg", 39, FLOOR, -97, 41, FLOOR + 3, -93, WOOD_DARK, nil, f)
	candle(V(40, FLOOR + 3.6, -95), f)
	-- broken barricade planks leaning at the doorway into the crypt
	for _, s in ipairs({ { 54, -115, 0.3 }, { 54, -101, -0.4 } }) do
		rb("Barricade", at(s[1], FLOOR + 4, s[2]) * CFrame.Angles(s[3], 0, math.rad(14)), 0.6, 9, 2, WOOD_DARK, nil, f)
	end
	cobweb(38, -38.5, -114, 4, f)
	cobweb(42, -38.5, -64, 3, f)
end
print(("[build-market] crypt: %d parts"):format(count - c0))
