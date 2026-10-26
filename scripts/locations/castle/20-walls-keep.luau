-- ================================================================ castle: the curtain wall, the towers, the gatehouse, the bridge, the keep
-- The wall ring |x| or |z| = 184..192, 9 blocks high (WALL_H): blackstone at the foot, then deepslate-dark stone
-- bricks → grey stone bricks → pale quartz bricks → white quartz at the top (segments with ragged band edges — the
-- white/black contrast of the concept). Buttresses every 4 blocks on the outer face run up into a quartz cornice
-- (y 28..32, w 192..196) where the raven nests sit; quartz merlons on the outer edge; the wall-walk (y 36) is 2 blocks
-- wide (one overhangs inside on corbels) except behind the keep. 9 towers (6×6 blocks, centred on w = 188): 4 corners,
-- mid N (x -96, the keep takes the middle), mid W / E and two gate towers; the walk passes through a room in each
-- (doorways y 36..48). Stairs up to the walk (kit stairs, w 172..180 along the inner face): STAIRS below.
-- The gatehouse: x -12..12, a stepped pointed arch, a raised portcullis, the walk over it; the bridge z 204..260 over
-- the gate terrace, knights on plinths at both ends, a lookout over the clouds at z 264..272.
-- The keep (KEEP): a quartz hall x 8..104, z -184..-116 on a blackstone plinth, four corner turrets with slate spires,
-- a stepped slate roof with crow-stepped quartz gables, the portal with steps (x 44..68, z -112..-104) facing the
-- court, a dark hall inside (columns, a black carpet, candles, soul lanterns, armour statues). The White Tower at
-- (56, -152) (the plan's TOWER snapped to the grid): three stepped stages to y 144, pinnacles, a slate spire to 180
-- crowned by a huge raven nest (y 157..167) with ravens on its rim.
local works = folder("Works")
local partsBefore = count
local METAL = Color3.fromRGB(42, 42, 48)
local STONE_MID = Color3.fromRGB(150, 150, 158)
local FOOT = Color3.fromRGB(118, 118, 128)
local IVY = Color3.fromRGB(70, 104, 62)
local RAVEN = Color3.fromRGB(34, 34, 40)
local GLASS = Color3.fromRGB(26, 28, 38)
local SLATE_LIGHT = Color3.fromRGB(165, 168, 186)
local IRON = Color3.fromRGB(176, 176, 184)
-- yaw that turns a CFrame's +Z to face outward from a face (N = -Z, S = +Z, W = -X, E = +X)
local YAW = { N = math.pi, S = 0, W = -math.pi / 2, E = math.pi / 2 }
local OPP = { N = "S", S = "N", W = "E", E = "W" }
-- the four sides of the ring: N / S run along x, W / E along z; s = the outward sign
local SIDES = {
	N = { along = "x", s = -1 },
	S = { along = "x", s = 1 },
	W = { along = "z", s = -1 },
	E = { along = "z", s = 1 },
}
local SIDE_ORDER = { "N", "S", "W", "E" }
-- the white wing on the black banners, in emblem units (x0, x1, y0, y1; y down from the emblem top)
local WING = {
	{ -5, -3, 0, 1 },
	{ 3, 5, 0, 1 },
	{ -4, -1, 1, 2 },
	{ 1, 4, 1, 2 },
	{ -0.6, 0.6, 0.2, 1.2 },
	{ -3, 3, 2, 3 },
	{ -1.5, 1.5, 3, 4.5 },
	{ -2.5, -0.5, 4.5, 5.5 },
	{ 0.5, 2.5, 4.5, 5.5 },
}
local nRavens = 0

-- a box on a side of the ring: u along the side, w = distance from the centre line
local function sbox(side, name, u0, y0, w0, u1, y1, w1, variant, tint, parent)
	if side.along == "x" then
		return box(name, u0, y0, side.s * w0, u1, y1, side.s * w1, variant, tint, parent)
	end
	return box(name, side.s * w0, y0, u0, side.s * w1, y1, u1, variant, tint, parent)
end
local function sxz(side, u, w)
	if side.along == "x" then
		return u, side.s * w
	end
	return side.s * w, u
end
local function faceCF(dir, x, y, z)
	return at(x, y, z) * CFrame.Angles(0, YAW[dir], 0)
end
local function jit(c, d)
	local k = rng:NextInteger(-d, d) / 255
	return Color3.new(math.clamp(c.R + k, 0, 1), math.clamp(c.G + k, 0, 1), math.clamp(c.B + k, 0, 1))
end
-- a flat decor plate on a face: cf on the face plane (+Z out), (dx, dy) the plate centre, `out` lifts it off the face
local function plate(name, cf, dx, dy, w, h, variant, tint, parent, out)
	local p = decor(part(name, Vector3.new(w, h, 0.3), cf * CFrame.new(dx, dy, (out or 0) + 0.15), tint, nil, parent))
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a long black banner with the white wing and a ragged foot, hanging off a face (cf on the face plane)
local function wingBanner(cf, w, h, parent)
	local c = cf * CFrame.new(0, 0, 0.5)
	banner(c, BANNER_BLACK, parent, nil, w, h)
	local u = w / 12
	local top = h * 0.32
	for _, r in ipairs(WING) do
		local size = Vector3.new((r[2] - r[1]) * u, (r[4] - r[3]) * u, 0.1)
		decor(part("BannerWing", size, c * CFrame.new((r[1] + r[2]) / 2 * u, top - (r[3] + r[4]) / 2 * u, 0.15), WING_WHITE, Enum.Material.Fabric, parent))
	end
	for _, sx in ipairs({ -1, 1 }) do
		decor(part("BannerTongue", Vector3.new(w / 4, 1.6, 0.2), c * CFrame.new(sx * w * 0.3, -h / 2 - 0.8, 0), BANNER_BLACK, Enum.Material.Fabric, parent))
	end
end
-- a cross-shaped arrow slit (cf on the face plane at the slit centre)
local function slit(cf, parent)
	plate("ArrowSlit", cf, 0, 0, 1, 6, "px_blackstone", SOOT, parent, 0.05)
	plate("ArrowSlit", cf, 0, 1, 3.2, 1, "px_blackstone", SOOT, parent, 0.15)
end
-- a tall pointed window of dark glass with an iron mullion and a quartz sill (cf at the glass centre)
local function gothicWindow(cf, w, h, parent)
	plate("WindowGlass", cf, 0, 0, w, h, nil, GLASS, parent).Material = Enum.Material.Glass
	plate("WindowGlass", cf, 0, h / 2 + w / 4, w / 2, w / 2, nil, GLASS, parent).Material = Enum.Material.Glass
	plate("WindowSill", cf, 0, -h / 2 - 0.5, w + 2, 1, "px_smooth_stone", QUARTZ, parent, 0.2)
	decor(part("WindowBar", Vector3.new(0.5, h + w / 2, 0.4), cf * CFrame.new(0, w / 4, 0.45), METAL, Enum.Material.Metal, parent))
	decor(part("WindowBar", Vector3.new(w, 0.5, 0.4), cf * CFrame.new(0, h / 6, 0.45), METAL, Enum.Material.Metal, parent))
end
-- a block raven standing on (x, y, z) local, looking along yaw
local function raven(x, y, z, yaw, parent)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	textured(decor(part("Raven", Vector3.new(1.6, 1.5, 2.4), cf * CFrame.new(0, 1.05, 0), nil, nil, parent)), "px_white_wool", RAVEN)
	textured(decor(part("RavenHead", Vector3.new(1.2, 1.2, 1.2), cf * CFrame.new(0, 2.1, 1.2), nil, nil, parent)), "px_white_wool", RAVEN)
	decor(part("RavenBeak", Vector3.new(0.4, 0.4, 0.8), cf * CFrame.new(0, 2, 2.2), Color3.fromRGB(110, 110, 116), Enum.Material.SmoothPlastic, parent))
	decor(part("RavenTail", Vector3.new(1, 0.4, 1.2), cf * CFrame.new(0, 1.3, -1.7), RAVEN, Enum.Material.SmoothPlastic, parent))
	nRavens += 1
end
-- a raven nest on a ledge (y = the ledge top): a black wool clump in a ring of dark oak sticks
local function nest(x, y, z, parent)
	textured(decor(part("NestWool", Vector3.new(3, 1.2, 3), at(x, y + 0.6, z), nil, nil, parent)), "px_white_wool", SOOT)
	for _, o in ipairs({ { 1.8, 0, 0.7, 4.2 }, { -1.8, 0, 0.7, 4.2 }, { 0, 1.8, 4.2, 0.7 }, { 0, -1.8, 4.2, 0.7 } }) do
		textured(decor(part("NestStick", Vector3.new(o[3], 0.8, o[4]), at(x + o[1], y + 0.9 + rng:NextNumber() * 0.4, z + o[2]), nil, nil, parent)), "px_dark_oak_log")
	end
	for _ = 1, 2 do
		local along = rng:NextNumber() < 0.5
		local size = Vector3.new(if along then 5.5 else 0.5, 0.5, if along then 0.5 else 5.5)
		textured(decor(part("NestStick", size, at(x + rng:NextNumber() * 2 - 1, y + 1.3, z + rng:NextNumber() * 2 - 1), nil, nil, parent)), "px_dark_oak_planks")
	end
end
-- a stepped slate spire from y on a square of half-size `half` (even), an iron rod and a black flag on top
local function spire(cx, cz, y, half, parent, flagYaw)
	local i = 0
	while half >= 2 do
		local h = if half >= 10 then 4 elseif half >= 6 then 6 elseif half >= 4 then 8 else 12
		if i % 2 == 0 then
			box("Spire", cx - half, y, cz - half, cx + half, y + h, cz + half, "px_blackstone", SLATE_LIGHT, parent)
		else
			box("Spire", cx - half, y, cz - half, cx + half, y + h, cz + half, "px_stone_bricks", SLATE, parent)
		end
		y += h
		half -= 2
		i += 1
	end
	decor(part("SpireRod", Vector3.new(0.6, 8, 0.6), at(cx, y + 4, cz), METAL, Enum.Material.Metal, parent))
	if flagYaw then
		local cf = at(cx, y + 6.4, cz) * CFrame.Angles(0, flagYaw, 0)
		decor(part("Flag", Vector3.new(0.3, 3, 5), cf * CFrame.new(0, 0, 2.8), BANNER_BLACK, Enum.Material.Fabric, parent))
		decor(part("FlagWing", Vector3.new(0.4, 1, 2), cf * CFrame.new(0, 0.2, 2.8), WING_WHITE, Enum.Material.Fabric, parent))
	end
	return y
end
-- dark quoins: the corner columns of a square body, a dark block then two white ones, from y0 to y1
local function quoins(x0, z0, x1, z1, y0, y1, parent)
	for _, c in ipairs({ { x0, z0 }, { x1 - 4, z0 }, { x0, z1 - 4 }, { x1 - 4, z1 - 4 } }) do
		local y, dark = y0, true
		while y < y1 - 0.01 do
			local h = math.min(y1 - y, if dark then 4 else 8)
			if dark then
				box("Quoin", c[1], y, c[2], c[1] + 4, y + h, c[2] + 4, "px_blackstone_bricks", FOOT, parent)
			else
				box("Quoin", c[1], y, c[2], c[1] + 4, y + h, c[2] + 4, "px_white_stone_bricks", QUARTZ, parent)
			end
			y += h
			dark = not dark
		end
	end
end
-- the body of a square tower without its corner columns (those are the quoins)
local function crossBody(x0, z0, x1, z1, y0, y1, variant, tint, parent)
	box("TowerBody", x0 + 4, y0, z0, x1 - 4, y1, z1, variant, tint, parent)
	box("TowerBody", x0, y0, z0 + 4, x0 + 4, y1, z1 - 4, variant, tint, parent)
	box("TowerBody", x1 - 4, y0, z0 + 4, x1, y1, z1 - 4, variant, tint, parent)
end
-- a lantern on a dark oak bracket out of a wall face at (x, y, z) local, (nx, nz) the outward normal
local function wallLantern(x, y, z, nx, nz, parent)
	local arm = part("LanternArm", Vector3.new(if nx ~= 0 then 2.6 else 0.8, 0.8, if nz ~= 0 then 2.6 else 0.8), at(x + nx * 1.3, y, z + nz * 1.3), nil, nil, parent)
	textured(decor(arm), WOOD_DARK)
	lantern(V(x + nx * 2.3, y - 1.6, z + nz * 2.3), parent, false, BY + y - 0.4)
end
-- a knight statue of iron blocks on a plinth (8×8), facing +Z of yaw, the sword planted in front
local function knight(x, z, yaw, parent, y0)
	local cf = at(x, y0 or 0, z) * CFrame.Angles(0, yaw, 0)
	local f = folder("KnightStatue", parent)
	local function piece(name, size, px, py, pz, variant, tint)
		return textured(part(name, size, cf * CFrame.new(px, py, pz), nil, nil, f), variant or "px_iron_block", tint or IRON)
	end
	piece("Plinth", Vector3.new(8, 4, 8), 0, 2, 0, "px_stone_bricks", DEEP)
	piece("PlinthTop", Vector3.new(6, 1, 6), 0, 4.5, 0, "px_smooth_stone", QUARTZ_SHADE)
	piece("Leg", Vector3.new(1.8, 6, 2.2), -1.1, 8, 0)
	piece("Leg", Vector3.new(1.8, 6, 2.2), 1.1, 8, 0)
	piece("Torso", Vector3.new(4.6, 5.4, 2.8), 0, 13.7, 0)
	piece("Arm", Vector3.new(1.6, 5, 2), -3.1, 13.6, 0.6)
	piece("Arm", Vector3.new(1.6, 5, 2), 3.1, 13.6, 0.6)
	piece("Helm", Vector3.new(3, 3.2, 3), 0, 18, 0)
	decor(part("Visor", Vector3.new(2.2, 0.5, 0.2), cf * CFrame.new(0, 18.2, 1.55), SOOT, Enum.Material.SmoothPlastic, f))
	decor(part("Plume", Vector3.new(0.6, 1.6, 2.4), cf * CFrame.new(0, 20.4, -0.2), BANNER_BLACK, Enum.Material.Fabric, f))
	decor(part("Blade", Vector3.new(0.7, 8, 0.3), cf * CFrame.new(0, 9, 2.2), Color3.fromRGB(200, 200, 206), Enum.Material.Metal, f))
	decor(part("Guard", Vector3.new(3, 0.6, 0.6), cf * CFrame.new(0, 13.3, 2.2), Color3.fromRGB(150, 130, 70), Enum.Material.Metal, f))
	decor(part("Grip", Vector3.new(0.5, 1.6, 0.5), cf * CFrame.new(0, 14.4, 2.2), Color3.fromRGB(60, 45, 35), Enum.Material.Wood, f))
	textured(decor(part("Shield", Vector3.new(0.6, 4, 3), cf * CFrame.new(-4.2, 13, 0.4), nil, nil, f)), "px_white_wool", BANNER_BLACK)
	return f
end
-- the parts of [a, b] along the north side that are not behind the keep
local function keepSkip(dir, a, b)
	if dir ~= "N" or b <= KEEP.x0 or a >= KEEP.x1 then
		return { { a, b } }
	end
	local out = {}
	if a < KEEP.x0 then
		table.insert(out, { a, KEEP.x0 })
	end
	if b > KEEP.x1 then
		table.insert(out, { KEEP.x1, b })
	end
	return out
end

-- ================================================================ the curtain wall
do
	local ring = folder("Curtain", works)
	-- the wall between the towers (each tower covers u = centre ± 12)
	local SPANS = {
		N = { { -176, -108 }, { -84, 176 } },
		S = { { -176, -36 }, { 36, 176 } },
		W = { { -176, -12 }, { 12, 176 } },
		E = { { -176, -12 }, { 12, 176 } },
	}
	for _, dir in ipairs(SIDE_ORDER) do
		local side = SIDES[dir]
		for _, sp in ipairs(SPANS[dir]) do
			local u0, u1 = sp[1], sp[2]
			-- the blackstone foot, one block wider outside
			sbox(side, "WallFoot", u0, 0, WALL_IN, u1, 4, WALL_OUT + 4, "px_blackstone", FOOT, ring)
			-- the body in segments of 3..6 blocks, the gradient bands at slightly different heights in each
			local u = u0
			while u < u1 - 0.01 do
				local len = math.min(u1 - u, rng:NextInteger(3, 6) * B)
				local b1 = pick({ 8, 12, 12, 16 })
				local b2 = b1 + pick({ 4, 8 })
				local b3 = math.min(28, b2 + pick({ 4, 8 }))
				sbox(side, "WallDeep", u, 4, WALL_IN, u + len, b1, WALL_OUT, "px_stone_bricks", jit(DEEP, 6), ring)
				sbox(side, "WallStone", u, b1, WALL_IN, u + len, b2, WALL_OUT, "px_stone_bricks", jit(STONE_MID, 8), ring)
				sbox(side, "WallPale", u, b2, WALL_IN, u + len, b3, WALL_OUT, "px_white_stone_bricks", jit(QUARTZ_SHADE, 6), ring)
				local top = if rng:NextNumber() < 0.3 then "px_smooth_stone" else "px_white_stone_bricks"
				sbox(side, "WallQuartz", u, b3, WALL_IN, u + len, WALL_H - 4, WALL_OUT, top, jit(QUARTZ, 4), ring)
				u += len
			end
			-- the wall-walk; one block of it overhangs inside on corbels (not behind the keep, which leans on the wall)
			sbox(side, "WallWalk", u0, WALL_H - 4, WALL_IN, u1, WALL_H, WALL_OUT, "px_smooth_stone", QUARTZ, ring)
			for _, iv in ipairs(keepSkip(dir, u0, u1)) do
				sbox(side, "WallWalk", iv[1], WALL_H - 4, WALL_IN - 4, iv[2], WALL_H, WALL_IN, "px_smooth_stone", QUARTZ_SHADE, ring)
				for gu = math.ceil((iv[1] + 4) / 12) * 12, iv[2] - 8, 12 do
					sbox(side, "WallCorbel", gu, WALL_H - 8, WALL_IN - 4, gu + 4, WALL_H - 4, WALL_IN, "px_stone_bricks", DEEP, ring)
				end
			end
			-- the quartz cornice on the outer face (the ledge of the nests) and the merlons
			sbox(side, "Cornice", u0, WALL_H - 8, WALL_OUT, u1, WALL_H - 4, WALL_OUT + 4, "px_white_stone_bricks", QUARTZ, ring)
			for gu = math.ceil(u0 / 8) * 8, u1 - 4, 8 do
				sbox(side, "Merlon", gu, WALL_H, WALL_OUT - 4, gu + 4, WALL_H + 4, WALL_OUT, "px_smooth_stone", QUARTZ, ring)
				local x, z = sxz(side, gu + 2, WALL_OUT - 2)
				if gu % 96 == 0 then
					lantern(V(x, WALL_H + 4.75, z), ring)
				elseif rng:NextNumber() < 0.025 then
					raven(x, WALL_H + 4, z, YAW[dir] + pick({ 0, math.pi / 2, -math.pi / 2 }), ring)
				end
			end
			-- buttresses every 4 blocks: two blocks out at the dark foot, one block up into the cornice
			for c = math.ceil((u0 + 4) / 16) * 16, u1 - 4, 16 do
				sbox(side, "Buttress", c - 2, 0, WALL_OUT, c + 2, 12, WALL_OUT + 8, "px_blackstone_bricks", FOOT, ring)
				sbox(side, "Buttress", c - 2, 12, WALL_OUT, c + 2, 24, WALL_OUT + 4, "px_stone_bricks", STONE_MID, ring)
				sbox(side, "ButtressCap", c - 2, 24, WALL_OUT, c + 2, 28, WALL_OUT + 4, "px_white_stone_bricks", QUARTZ, ring)
			end
			-- the bays between the buttresses: arrow slits, soot streaks under the cornice, ivy, nests on the cornice
			for b = math.ceil((u0 - 2) / 16) * 16 + 8, u1 - 6, 16 do
				local ox, oz = sxz(side, b, WALL_OUT)
				local ocf = faceCF(dir, ox, 0, oz)
				if (b // 16) % 2 == 0 then
					slit(ocf * CFrame.new(0, 18, 0), ring)
				end
				if rng:NextNumber() < 0.35 then
					local h = rng:NextInteger(2, 4) * 4
					plate("Soot", ocf, 4, WALL_H - 8 - h / 2, 3, h, "px_blackstone", SOOT, ring, 0.35)
				end
				if rng:NextNumber() < 0.3 then
					local h = rng:NextInteger(2, 5) * 4
					plate("Ivy", ocf, -3.5, 4 + h / 2, 4, h, "px_hedge", IVY, ring, 0.55)
				end
				if rng:NextNumber() < 0.15 then
					local nx, nz = sxz(side, b, WALL_OUT + 2)
					nest(nx, WALL_H - 4, nz, ring)
					if rng:NextNumber() < 0.45 then
						raven(nx, WALL_H - 3, nz, YAW[dir], ring)
					end
				end
				-- the inner face (not behind the keep): soot under the walk, ivy at the foot
				if dir ~= "N" or b + 6 < KEEP.x0 or b - 6 > KEEP.x1 then
					local ix, iz = sxz(side, b, WALL_IN)
					local icf = faceCF(OPP[dir], ix, 0, iz)
					if rng:NextNumber() < 0.3 then
						local h = rng:NextInteger(2, 4) * 4
						plate("Soot", icf, 2, WALL_H - 8 - h / 2, 3, h, "px_blackstone", SOOT, ring, 0.35)
					end
					if rng:NextNumber() < 0.3 then
						local h = rng:NextInteger(2, 4) * 4
						plate("Ivy", icf, -2, 4 + h / 2, 4, h, "px_hedge", IVY, ring, 0.55)
					end
				end
			end
		end
	end
	-- the stairs up to the wall-walk: kit stairs (visible steps + invisible ramp) on a stepped fill, along the inner
	-- face (w 172..180) from u low (y 0) to u high (y 36), the top beside the walk
	local STAIRS = { S = { -104, -176 }, N = { -8, -80 }, W = { 100, 28 }, E = { -100, -28 } }
	for _, dir in ipairs(SIDE_ORDER) do
		local side = SIDES[dir]
		local uLow, uHigh = STAIRS[dir][1], STAIRS[dir][2]
		stairs("WallStairs", side.s * 176, uLow, uHigh, 0, WALL_H, 8, "px_stone_bricks", ring, if side.along == "x" then "x" else nil)
		local run = math.abs(uHigh - uLow)
		local steps = math.max(1, math.floor(run / 2))
		local udir = if uHigh > uLow then 1 else -1
		for j = 0, WALL_H / 4 - 2 do
			local k = math.floor(steps * (4 * j + 4) / WALL_H)
			if k < steps then
				sbox(side, "StairFill", uLow + udir * k * run / steps, 4 * j, 172.05, uHigh, 4 * j + 4, 179.95, "px_stone_bricks", DEEP, ring)
			end
		end
		-- a lantern on the wall over the foot of the stairs
		local lx, lz = sxz(side, uLow + udir * 6, WALL_IN)
		wallLantern(lx, 14, lz, if side.along == "z" then -side.s else 0, if side.along == "x" then -side.s else 0, ring)
	end
end
task.wait()

-- ================================================================ the towers
do
	local towers = folder("Towers", works)
	-- doors: { face, a0, a1 } — the wall-walk passes through that face over [a0, a1] (z for W/E faces, x for N/S),
	-- y 36..48; flags: faces with a long wing banner, two arrow slits and soot; topY: the room roof (5 blocks over
	-- the wall for the ring towers)
	local function tower(name, cx, cz, doors, flags, topY)
		local f = folder(name, towers)
		local x0, x1, z0, z1 = cx - 12, cx + 12, cz - 12, cz + 12
		box("TowerFoot", x0, 0, z0, x1, 4, z1, "px_blackstone", FOOT, f)
		crossBody(x0, z0, x1, z1, 4, 12, "px_stone_bricks", jit(DEEP, 5), f)
		crossBody(x0, z0, x1, z1, 12, 20, "px_stone_bricks", jit(STONE_MID, 6), f)
		crossBody(x0, z0, x1, z1, 20, WALL_H, "px_white_stone_bricks", QUARTZ_SHADE, f)
		quoins(x0, z0, x1, z1, 4, topY, f)
		-- the room on the wall-walk: four quartz walls between the quoins, doorways where the walk passes
		for _, face in ipairs({ "N", "S", "W", "E" }) do
			local alongX = face == "N" or face == "S"
			local lo = if alongX then x0 + 4 else z0 + 4
			local hi = if alongX then x1 - 4 else z1 - 4
			local function piece(a, b, ya, yb)
				if b - a < 0.01 then
					return
				end
				if face == "N" then
					box("TowerWall", a, ya, z0, b, yb, z0 + 4, "px_white_stone_bricks", QUARTZ, f)
				elseif face == "S" then
					box("TowerWall", a, ya, z1 - 4, b, yb, z1, "px_white_stone_bricks", QUARTZ, f)
				elseif face == "W" then
					box("TowerWall", x0, ya, a, x0 + 4, yb, b, "px_white_stone_bricks", QUARTZ, f)
				else
					box("TowerWall", x1 - 4, ya, a, x1, yb, b, "px_white_stone_bricks", QUARTZ, f)
				end
			end
			local door = nil
			for _, d in ipairs(doors) do
				if d[1] == face then
					door = d
				end
			end
			if door then
				local a0, a1 = math.max(lo, door[2]), math.min(hi, door[3])
				piece(lo, a0, WALL_H, topY)
				piece(a1, hi, WALL_H, topY)
				piece(a0, a1, WALL_H + 12, topY)
			else
				piece(lo, hi, WALL_H, topY)
			end
		end
		-- the cornice (one block out) on corbels, merlons on its corners and mid-edges, the slate spire
		box("TowerCornice", x0 - 4, topY, z0 - 4, x1 + 4, topY + 4, z1 + 4, "px_stone_bricks", DEEP, f)
		for _, o in ipairs({ -10, 6 }) do
			box("TowerCorbel", cx + o, topY - 4, z0 - 4, cx + o + 4, topY, z0, "px_stone_bricks", DEEP, f)
			box("TowerCorbel", cx + o, topY - 4, z1, cx + o + 4, topY, z1 + 4, "px_stone_bricks", DEEP, f)
			box("TowerCorbel", x0 - 4, topY - 4, cz + o, x0, topY, cz + o + 4, "px_stone_bricks", DEEP, f)
			box("TowerCorbel", x1, topY - 4, cz + o, x1 + 4, topY, cz + o + 4, "px_stone_bricks", DEEP, f)
		end
		local merlons = {
			{ x0 - 4, z0 - 4 },
			{ x1, z0 - 4 },
			{ x0 - 4, z1 },
			{ x1, z1 },
			{ cx - 2, z0 - 4 },
			{ cx - 2, z1 },
			{ x0 - 4, cz - 2 },
			{ x1, cz - 2 },
		}
		for _, m in ipairs(merlons) do
			box("TowerMerlon", m[1], topY + 4, m[2], m[1] + 4, topY + 8, m[2] + 4, "px_smooth_stone", QUARTZ, f)
		end
		local m = pick(merlons)
		raven(m[1] + 2, topY + 8, m[2] + 2, rng:NextInteger(0, 3) * math.pi / 2, f)
		spire(cx, cz, topY + 4, 12, f, rng:NextNumber() * math.pi * 2)
		lantern(V(cx, topY - 3, cz), f, false, BY + topY)
		-- the banner faces: a long wing banner on the shaft, two slits in the room, soot under the cornice
		for _, face in ipairs(flags) do
			local fx, fz = cx, z0
			if face == "S" then
				fz = z1
			elseif face == "W" then
				fx, fz = x0, cz
			elseif face == "E" then
				fx, fz = x1, cz
			end
			local cf = faceCF(face, fx, 0, fz)
			wingBanner(cf * CFrame.new(0, 22, 0), 8, 20, f)
			slit(cf * CFrame.new(-6, WALL_H + 9, 0), f)
			slit(cf * CFrame.new(6, WALL_H + 9, 0), f)
			if rng:NextNumber() < 0.6 then
				plate("Soot", cf, 0, topY - 8, 3, 8, "px_blackstone", SOOT, f, 0.35)
			end
		end
		-- a nest on the cornice ledge of the first banner face
		if rng:NextNumber() < 0.6 then
			local face = flags[1]
			local nx, nz = cx + 6, z0 - 2
			if face == "S" then
				nz = z1 + 2
			elseif face == "W" then
				nx, nz = x0 - 2, cz + 6
			elseif face == "E" then
				nx, nz = x1 + 2, cz + 6
			end
			nest(nx, topY + 4, nz, f)
		end
		return f
	end
	tower("TowerNW", -188, -188, { { "E", -188, -180 }, { "S", -188, -180 } }, { "N", "W" }, WALL_H + 20)
	tower("TowerNE", 188, -188, { { "W", -188, -180 }, { "S", 180, 188 } }, { "N", "E" }, WALL_H + 20)
	tower("TowerSW", -188, 188, { { "E", 180, 188 }, { "N", -188, -180 } }, { "S", "W" }, WALL_H + 20)
	tower("TowerSE", 188, 188, { { "W", 180, 188 }, { "N", 180, 188 } }, { "S", "E" }, WALL_H + 20)
	tower("TowerN", -96, -188, { { "W", -188, -180 }, { "E", -188, -180 } }, { "N", "S" }, WALL_H + 20)
	tower("TowerW", -188, 0, { { "N", -188, -180 }, { "S", -188, -180 } }, { "W", "E" }, WALL_H + 20)
	tower("TowerE", 188, 0, { { "N", 180, 188 }, { "S", 180, 188 } }, { "E", "W" }, WALL_H + 20)
	tower("GateTowerW", -24, 188, { { "W", 180, 188 }, { "E", 180, 188 } }, { "S", "N" }, WALL_H + 28)
	tower("GateTowerE", 24, 188, { { "W", 180, 188 }, { "E", 180, 188 } }, { "S", "N" }, WALL_H + 28)
end
task.wait()

-- ================================================================ the gatehouse (x -12..12 between the gate towers)
do
	local g = folder("Gatehouse", works)
	-- the passage z 176..200: a stepped pointed arch, the lintel and the wall-walk over it
	box("GateLintel", -12, 24, 176, 12, WALL_H - 4, 200, "px_white_stone_bricks", QUARTZ_SHADE, g)
	box("GateWalk", -12, WALL_H - 4, 176, 12, WALL_H, 200, "px_smooth_stone", QUARTZ, g)
	for _, s in ipairs({ -1, 1 }) do
		box("GateArch", s * 12, 16, 176, s * 8, 24, 200, "px_stone_bricks", STONE_MID, g)
		box("GateArch", s * 8, 20, 176, s * 4, 24, 200, "px_stone_bricks", STONE_MID, g)
	end
	-- a dark frame around the arch on both faces
	for _, zf in ipairs({ { 200, 204 }, { 172, 176 } }) do
		local a, b = zf[1], zf[2]
		for _, s in ipairs({ -1, 1 }) do
			box("GateFrame", s * 16, 0, a, s * 12, 28, b, "px_blackstone_bricks", FOOT, g)
			box("GateFrame", s * 12, 16, a, s * 8, 28, b, "px_blackstone_bricks", FOOT, g)
			box("GateFrame", s * 8, 20, a, s * 4, 28, b, "px_blackstone_bricks", FOOT, g)
		end
		box("GateKeystone", -4, 24, a, 4, 28, b, "px_blackstone", FOOT, g)
	end
	for _, x in ipairs({ -12, -2, 8 }) do
		box("Merlon", x, WALL_H, 196, x + 4, WALL_H + 4, 200, "px_smooth_stone", QUARTZ, g)
		box("Merlon", x, WALL_H, 176, x + 4, WALL_H + 4, 180, "px_smooth_stone", QUARTZ, g)
	end
	raven(0, WALL_H + 4, 198, 0, g)
	-- the raised portcullis: dark iron bars hanging out of the lintel slot
	for _, x in ipairs({ -10, -6, -2, 2, 6, 10 }) do
		decor(part("Portcullis", Vector3.new(0.8, 10, 0.8), at(x, 21, 196), METAL, Enum.Material.Metal, g))
		decor(part("PortcullisSpike", Vector3.new(0.5, 1, 0.5), at(x, 15.5, 196), METAL, Enum.Material.Metal, g))
	end
	for _, y in ipairs({ 17.5, 21 }) do
		decor(part("Portcullis", Vector3.new(23.6, 0.8, 0.8), at(0, y, 196), METAL, Enum.Material.Metal, g))
	end
	-- the gate leaves stand open against the passage walls; the passage paving
	for _, s in ipairs({ -1, 1 }) do
		textured(decor(part("GateDoor", Vector3.new(1, 15, 12), at(s * 11.4, 7.5, 184), nil, nil, g)), WOOD_DARK)
		for _, y in ipairs({ 3, 12 }) do
			decor(part("DoorBand", Vector3.new(1.3, 0.8, 12), at(s * 11.4, y, 184), METAL, Enum.Material.Metal, g))
		end
		-- the drawbridge chains from the gate towers down to the bridge posts
		decor(beam("Chain", V(s * 18, 30, 200.4), V(s * 14, 8.6, 230), 0.4, METAL, g, Enum.Material.Metal))
		wallLantern(s * 14, 14, 204, 0, 1, g)
		wallLantern(s * 14, 14, 172, 0, -1, g)
	end
	box("GatePaving", -12, -0.2, 172, 12, 0.4, 204, "px_stone_bricks", DEEP, g)
end
task.wait()

-- ================================================================ the bridge over the gate terrace, the lookout
do
	local br = folder("Bridge", works)
	box("BridgeDeck", -12, -0.2, 204, 12, 0.4, 264, "px_white_stone_bricks", QUARTZ_SHADE, br)
	for _, s in ipairs({ -1, 1 }) do
		box("BridgeParapet", s * 16, 0, 204, s * 12, 4, 260, "px_blackstone_bricks", FOOT, br)
		for _, z in ipairs({ 208, 228, 248 }) do
			box("BridgePost", s * 16, 4, z, s * 12, 8, z + 4, "px_smooth_stone", QUARTZ, br)
			if z ~= 228 then
				lantern(V(s * 14, 8.75, z + 2), br)
			end
		end
		-- the terrace balustrade: across the end and down both sides
		box("Balustrade", s * 12, 0, 260, s * 40, 4, 264, "px_blackstone_bricks", FOOT, br)
		box("Balustrade", s * 36, 0, 220, s * 40, 4, 260, "px_blackstone_bricks", FOOT, br)
		box("BalustradePost", s * 36, 4, 260, s * 40, 8, 264, "px_smooth_stone", QUARTZ, br)
		box("BalustradePost", s * 36, 4, 220, s * 40, 8, 224, "px_smooth_stone", QUARTZ, br)
		lantern(V(s * 38, 8.75, 262), br)
		-- the lookout sides
		box("LookoutWall", s * 12, 0, 264, s * 16, 4, 272, "px_blackstone_bricks", FOOT, br)
		box("LookoutPost", s * 12, 4, 268, s * 16, 8, 272, "px_smooth_stone", QUARTZ, br)
		lantern(V(s * 14, 8.75, 270), br)
		-- knights on plinths: two outside the gate looking out, two at the terrace end looking back at the castle
		knight(s * 26, 208, 0, br)
		knight(s * 26, 248, math.pi, br)
	end
	-- the lookout: a balcony over the clouds on stepped corbels
	box("LookoutFloor", -16, -4, 264, 16, 0, 272, "px_stone_bricks", DEEP, br)
	box("LookoutWall", -12, 0, 268, 12, 4, 272, "px_blackstone_bricks", FOOT, br)
	box("LookoutCorbel", -12, -8, 264, 12, -4, 268, "px_stone_bricks", DEEP, br)
	box("LookoutCorbel", -8, -12, 264, 8, -8, 268, "px_blackstone_bricks", FOOT, br)
	raven(-38, 8, 222, math.pi / 2, br)
	raven(14, 4, 266, math.pi / 2, br)
end
task.wait()

-- ================================================================ the keep: the quartz hall in front of the White Tower
do
	local keep = folder("Keep", works)
	local K = KEEP
	local T = { x0 = TOWER.x - 16, x1 = TOWER.x + 16, z0 = TOWER.z - 18, z1 = TOWER.z + 14 } -- the White Tower, snapped
	local SX0, SX1, SZ0, SZ1 = K.x0 + 8, K.x1 - 8, K.z0, K.z1 - 4 -- the hall shell x 8..104, z -184..-116
	local PX0, PX1 = TOWER.x - 8, TOWER.x + 8 -- the portal x 48..64
	local TURRETS = { { K.x0, K.z1 - 16 }, { K.x1 - 16, K.z1 - 16 }, { K.x0, K.z0 }, { K.x1 - 16, K.z0 } }
	local function turretHit(x0, y0, z0, x1, _, z1)
		for _, t in ipairs(TURRETS) do
			if x0 < t[1] + 20 and x1 > t[1] - 4 and z0 < t[2] + 20 and z1 > t[2] - 4 and y0 < 100 then
				return true
			end
		end
		return false
	end
	-- dark stone up to y 12, white quartz bricks above
	local function wallBands(name, x0, z0, x1, z1, ya, yb)
		if ya < 12 then
			box(name, x0, ya, z0, x1, math.min(12, yb), z1, "px_stone_bricks", DEEP, keep)
		end
		if yb > 12 then
			box(name, x0, math.max(12, ya), z0, x1, yb, z1, "px_white_stone_bricks", QUARTZ, keep)
		end
	end
	-- the plinth, the porch and the steps down to the court
	box("KeepPlinth", K.x0 + 4, 0, SZ0, K.x1 - 4, 4, SZ1, "px_blackstone_bricks", FOOT, keep)
	box("KeepPorch", K.x0 + 16, 0, SZ1, K.x1 - 16, 4, K.z1, "px_blackstone_bricks", FOOT, keep)
	stairs("KeepSteps", TOWER.x, K.z1 + 8, K.z1, 0, 4, 24, "px_white_stone_bricks", keep)
	-- the shell (y 4..40): west, east, back (against the curtain wall), the front with the portal
	wallBands("KeepWall", SX0, SZ0, SX0 + 4, SZ1, 4, 40)
	wallBands("KeepWall", SX1 - 4, SZ0, SX1, SZ1, 4, 40)
	wallBands("KeepWall", SX0 + 4, SZ0, SX1 - 4, SZ0 + 4, 4, 40)
	wallBands("KeepFront", SX0 + 4, SZ1 - 4, PX0, SZ1, 4, 40)
	wallBands("KeepFront", PX1, SZ1 - 4, SX1 - 4, SZ1, 4, 40)
	box("KeepPortalArch", PX0, 24, SZ1 - 4, PX1, 40, SZ1, "px_white_stone_bricks", QUARTZ, keep)
	box("KeepPortalArch", PX0, 20, SZ1 - 4, PX0 + 4, 24, SZ1, "px_white_stone_bricks", QUARTZ, keep)
	box("KeepPortalArch", PX1 - 4, 20, SZ1 - 4, PX1, 24, SZ1, "px_white_stone_bricks", QUARTZ, keep)
	-- the four corner turrets (4×4 blocks) with slate spires
	for i, t in ipairs(TURRETS) do
		local x0, z0 = t[1], t[2]
		local x1, z1 = x0 + 16, z0 + 16
		box("TurretFoot", x0, 0, z0, x1, 4, z1, "px_blackstone", FOOT, keep)
		crossBody(x0, z0, x1, z1, 4, 12, "px_stone_bricks", DEEP, keep)
		crossBody(x0, z0, x1, z1, 12, 60, "px_white_stone_bricks", QUARTZ, keep)
		quoins(x0, z0, x1, z1, 4, 60, keep)
		box("TurretCornice", x0 - 4, 60, z0 - 4, x1 + 4, 64, z1 + 4, "px_stone_bricks", DEEP, keep)
		for _, m in ipairs({ { x0 - 4, z0 - 4 }, { x1, z0 - 4 }, { x0 - 4, z1 }, { x1, z1 } }) do
			box("TurretMerlon", m[1], 64, m[2], m[1] + 4, 68, m[2] + 4, "px_smooth_stone", QUARTZ, keep)
		end
		spire(x0 + 8, z0 + 8, 64, 8, keep, rng:NextNumber() * math.pi * 2)
		-- slits on the outer faces, soot under the cornice
		local side = if x0 == K.x0 then "W" else "E"
		local sideCf = faceCF(side, if side == "W" then x0 else x1, 0, z0 + 8)
		slit(sideCf * CFrame.new(0, 24, 0), keep)
		slit(sideCf * CFrame.new(0, 46, 0), keep)
		plate("Soot", sideCf, 2, 54, 3, 12, "px_blackstone", SOOT, keep, 0.35)
		if i <= 2 then
			local frontCf = faceCF("S", x0 + 8, 0, z1)
			slit(frontCf * CFrame.new(0, 46, 0), keep)
			plate("Ivy", frontCf, -2, 12, 4, 16, "px_hedge", IVY, keep, 0.55)
		end
		if i == 2 or i == 3 then
			raven(x0 + 2 + (if i == 2 then 16 else -4), 68, z0 + 2 + (if i == 2 then 16 else -4), YAW[side], keep)
		end
	end
	-- the side walls between the turrets: a buttress and two tall pointed windows
	for _, s in ipairs({ { "W", SX0, -1 }, { "E", SX1, 1 } }) do
		local face, fx, sg = s[1], s[2], s[3]
		box("KeepButtress", fx, 0, -150, fx + sg * 8, 24, -146, "px_stone_bricks", DEEP, keep)
		box("KeepButtress", fx, 24, -150, fx + sg * 4, 36, -146, "px_white_stone_bricks", QUARTZ_SHADE, keep)
		box("KeepButtressCap", fx, 36, -150, fx + sg * 4, 40, -146, "px_smooth_stone", QUARTZ, keep)
		for _, zc in ipairs({ -158, -138 }) do
			gothicWindow(faceCF(face, fx, 22, zc), 6, 14, keep)
		end
		plate("Soot", faceCF(face, fx, 0, -146), 0, 33, 3, 10, "px_blackstone", SOOT, keep, 0.35)
	end
	-- the façade (z -116): buttresses, windows, banners, the portal frame under a slate pediment
	for _, bx in ipairs({ 30, 78 }) do
		box("KeepButtress", bx, 0, SZ1, bx + 4, 24, SZ1 + 8, "px_stone_bricks", DEEP, keep)
		box("KeepButtress", bx, 24, SZ1, bx + 4, 36, SZ1 + 4, "px_white_stone_bricks", QUARTZ_SHADE, keep)
		box("KeepButtressCap", bx, 36, SZ1, bx + 4, 40, SZ1 + 4, "px_smooth_stone", QUARTZ, keep)
	end
	for _, wx in ipairs({ 23, 89 }) do
		gothicWindow(faceCF("S", wx, 22, SZ1), 6, 14, keep)
	end
	for _, bx in ipairs({ 39, 73 }) do
		wingBanner(faceCF("S", bx, 26, SZ1), 6, 18, keep)
	end
	for _, s in ipairs({ -1, 1 }) do
		box("PortalFrame", TOWER.x + s * 12, 4, SZ1, TOWER.x + s * 8, 28, SZ1 + 4, "px_blackstone_bricks", FOOT, keep)
		box("PortalFrame", TOWER.x + s * 8, 20, SZ1, TOWER.x + s * 4, 28, SZ1 + 4, "px_blackstone_bricks", FOOT, keep)
		wallLantern(TOWER.x + s * 10, 18, SZ1 + 4, 0, 1, keep)
		-- the doors stand open inside the portal
		textured(decor(part("KeepDoor", Vector3.new(1, 16, 8), at(TOWER.x + s * 7.5, 12, SZ1 - 8), nil, nil, keep)), WOOD_DARK)
	end
	box("PortalKeystone", TOWER.x - 4, 24, SZ1, TOWER.x + 4, 28, SZ1 + 4, "px_blackstone", FOOT, keep)
	box("Pediment", TOWER.x - 12, 28, SZ1, TOWER.x + 12, 32, SZ1 + 4, "px_stone_bricks", SLATE, keep)
	box("Pediment", TOWER.x - 8, 32, SZ1, TOWER.x + 8, 36, SZ1 + 4, "px_blackstone", SLATE_LIGHT, keep)
	box("Pediment", TOWER.x - 4, 36, SZ1, TOWER.x + 4, 40, SZ1 + 4, "px_stone_bricks", SLATE, keep)
	box("PedimentFinial", TOWER.x - 2, 40, SZ1, TOWER.x + 2, 46, SZ1 + 4, "px_smooth_stone", QUARTZ, keep)
	raven(TOWER.x, 46, SZ1 + 2, 0, keep)
	-- quartz merlons along the front eave
	for x = SX0 + 8, SX1 - 12, 8 do
		box("KeepMerlon", x, 44, SZ1 - 4, x + 4, 48, SZ1, "px_smooth_stone", QUARTZ, keep)
	end
	-- the stepped slate roof (ridge along x) around the White Tower, crow-stepped quartz gables at both ends
	for k = 0, 8 do
		local za, zb, y = SZ0 + 4 * k, SZ1 - 4 * k, 40 + 4 * k
		local slateV = if k % 2 == 0 then "px_stone_bricks" else "px_blackstone"
		local slateT = if k % 2 == 0 then SLATE else SLATE_LIGHT
		local pieces
		if za >= T.z1 or zb <= T.z0 then
			pieces = { { SX0 + 4, za, SX1 - 4, zb } }
		else
			pieces = { { SX0 + 4, za, T.x0, zb }, { T.x1, za, SX1 - 4, zb } }
			if za < T.z0 then
				table.insert(pieces, { T.x0, za, T.x1, T.z0 })
			end
			if zb > T.z1 then
				table.insert(pieces, { T.x0, T.z1, T.x1, zb })
			end
		end
		for _, p in ipairs(pieces) do
			box("KeepRoof", p[1], y, p[2], p[3], y + 4, p[4], slateV, slateT, keep)
		end
		for _, gx in ipairs({ SX0, SX1 - 4 }) do
			box("KeepGable", gx, y, za, gx + 4, y + 4, zb, "px_white_stone_bricks", QUARTZ, keep)
			local ends = if zb - za > 4 then { za, zb - 4 } else { za }
			for _, zc in ipairs(ends) do
				if not turretHit(gx, y + 4, zc, gx + 4, y + 8, zc + 4) then
					box("KeepGableStep", gx, y + 4, zc, gx + 4, y + 8, zc + 4, "px_smooth_stone", QUARTZ, keep)
				end
			end
		end
	end
	for _, rx in ipairs({ 20, 34, 90 }) do
		raven(rx, 76, SZ0 + 34, if rx < TOWER.x then -math.pi / 2 else math.pi / 2, keep)
	end

	-- the dark hall inside: columns, a black carpet to the White Tower's door, candles, soul lanterns, armour
	local hall = folder("Hall", keep)
	for _, c in ipairs({ { 26, -160 }, { 26, -144 }, { 26, -128 }, { 86, -160 }, { 86, -144 }, { 86, -128 } }) do
		box("HallColumnBase", c[1] - 4, 4, c[2] - 4, c[1] + 4, 8, c[2] + 4, "px_white_stone_bricks", QUARTZ_SHADE, hall)
		box("HallColumn", c[1] - 2, 8, c[2] - 2, c[1] + 2, 36, c[2] + 2, "px_blackstone_bricks", FOOT, hall)
		box("HallCapital", c[1] - 4, 36, c[2] - 4, c[1] + 4, 40, c[2] + 4, "px_white_stone_bricks", QUARTZ, hall)
	end
	textured(decor(part("Carpet", Vector3.new(8, 0.2, 24), at(TOWER.x, 4.1, (T.z1 + K.z1) / 2), nil, nil, hall)), "px_white_wool", BANNER_BLACK)
	do
		-- the tower door: dark oak with a pointed top in a blackstone frame
		local dcf = faceCF("S", TOWER.x, 4, T.z1)
		plate("TowerDoor", dcf, 0, 7, 8, 14, WOOD_DARK, nil, hall, 0.1)
		plate("TowerDoor", dcf, 0, 16, 4, 4, WOOD_DARK, nil, hall, 0.1)
		for _, s in ipairs({ -1, 1 }) do
			plate("TowerDoorFrame", dcf, s * 5, 9, 2, 18, "px_blackstone_bricks", FOOT, hall)
		end
		plate("TowerDoorFrame", dcf, 0, 19, 8, 2, "px_blackstone_bricks", FOOT, hall)
		for _, y in ipairs({ 3, 10 }) do
			decor(part("DoorBand", Vector3.new(8, 0.6, 0.3), dcf * CFrame.new(0, y, 0.55), METAL, Enum.Material.Metal, hall))
		end
	end
	local function candles(x, z)
		decor(part("CandleStand", Vector3.new(1, 6, 1), at(x, 7, z), METAL, Enum.Material.Metal, hall))
		local tray = decor(part("CandleTray", Vector3.new(2.6, 0.4, 2.6), at(x, 10.2, z), METAL, Enum.Material.Metal, hall))
		for i, o in ipairs({ { -0.8, 0 }, { 0.8, 0 }, { 0, 0.8 } }) do
			local h = 0.9 + i * 0.3
			decor(part("Candle", Vector3.new(0.5, h, 0.5), at(x + o[1], 10.4 + h / 2, z + o[2]), Color3.fromRGB(230, 225, 210), Enum.Material.SmoothPlastic, hall))
			decor(part("CandleFlame", Vector3.new(0.3, 0.4, 0.3), at(x + o[1], 10.6 + h, z + o[2]), LANTERN_GLOW, Enum.Material.Neon, hall))
		end
		light(tray, 18, 1, LANTERN_GLOW)
	end
	candles(TOWER.x - 8, T.z1 + 4)
	candles(TOWER.x + 8, T.z1 + 4)
	candles(PX0 - 6, SZ1 - 7)
	candles(PX1 + 6, SZ1 - 7)
	for _, l in ipairs({ { 26, -152 }, { 86, -152 }, { 26, -136 }, { 86, -136 }, { TOWER.x, -174 } }) do
		lantern(V(l[1], 30, l[2]), hall, true, BY + 40)
	end
	knight(16, -152, math.pi / 2, hall, 4)
	knight(16, -136, math.pi / 2, hall, 4)
	knight(96, -152, -math.pi / 2, hall, 4)
	knight(96, -136, -math.pi / 2, hall, 4)
	wingBanner(faceCF("W", T.x0, 24, TOWER.z - 2), 8, 20, hall)
	wingBanner(faceCF("E", T.x1, 24, TOWER.z - 2), 8, 20, hall)
end
task.wait()

-- ================================================================ the White Tower (the landmark) and its raven nest
do
	local wt = folder("WhiteTower", works)
	local tx, tz = TOWER.x, TOWER.z - 2 -- (56, -152), the footprint on the block grid
	-- a pinnacle at a cornice corner: a quartz block and a slate needle
	local function pinnacle(x0, z0, y)
		box("Pinnacle", x0, y, z0, x0 + 4, y + 8, z0 + 4, "px_white_stone_bricks", QUARTZ, wt)
		spire(x0 + 2, z0 + 2, y + 8, 2, wt)
	end
	-- merlons along the edge ring of a cornice (half-size h), between the corner pinnacles
	local function cornice(h, y)
		box("TowerCornice", tx - h, y, tz - h, tx + h, y + 4, tz + h, "px_stone_bricks", SLATE, wt)
		for _, c in ipairs({ { -h, -h }, { h - 4, -h }, { -h, h - 4 }, { h - 4, h - 4 } }) do
			pinnacle(tx + c[1], tz + c[2], y + 4)
		end
		for _, o in ipairs({ -12, -2, 8 }) do
			if o >= -h + 4 and o + 4 <= h - 4 then
				box("TowerMerlon", tx + o, y + 4, tz - h, tx + o + 4, y + 8, tz - h + 4, "px_smooth_stone", QUARTZ, wt)
				box("TowerMerlon", tx + o, y + 4, tz + h - 4, tx + o + 4, y + 8, tz + h, "px_smooth_stone", QUARTZ, wt)
				box("TowerMerlon", tx - h, y + 4, tz + o, tx - h + 4, y + 8, tz + o + 4, "px_smooth_stone", QUARTZ, wt)
				box("TowerMerlon", tx + h - 4, y + 4, tz + o, tx + h, y + 8, tz + o + 4, "px_smooth_stone", QUARTZ, wt)
			end
		end
	end
	-- stage 1 (8×8 blocks) from the hall floor through the roof to y 88
	crossBody(tx - 16, tz - 16, tx + 16, tz + 16, 4, 12, "px_blackstone_bricks", FOOT, wt)
	crossBody(tx - 16, tz - 16, tx + 16, tz + 16, 12, 44, "px_stone_bricks", STONE_MID, wt)
	crossBody(tx - 16, tz - 16, tx + 16, tz + 16, 44, 88, "px_white_stone_bricks", QUARTZ, wt)
	quoins(tx - 16, tz - 16, tx + 16, tz + 16, 4, 88, wt)
	cornice(20, 88)
	for _, face in ipairs({ "S", "N" }) do
		local cf = faceCF(face, tx, 0, if face == "S" then tz + 16 else tz - 16)
		wingBanner(cf * CFrame.new(0, 74, 0), 8, 20, wt)
		gothicWindow(cf * CFrame.new(-8.5, 72, 0), 5, 14, wt)
		gothicWindow(cf * CFrame.new(8.5, 72, 0), 5, 14, wt)
	end
	for _, face in ipairs({ "W", "E" }) do
		local cf = faceCF(face, if face == "W" then tx - 16 else tx + 16, 0, tz)
		gothicWindow(cf * CFrame.new(0, 81, 0), 5, 8, wt)
		plate("Soot", cf, -10, 78, 3, 16, "px_blackstone", SOOT, wt, 0.35)
		plate("Soot", cf, 10, 80, 3, 12, "px_blackstone", SOOT, wt, 0.35)
		plate("Ivy", cf, 6, 82, 4, 10, "px_hedge", IVY, wt, 0.55)
	end
	-- stage 2 (6×6 blocks) to y 120
	crossBody(tx - 12, tz - 12, tx + 12, tz + 12, 92, 120, "px_white_stone_bricks", QUARTZ, wt)
	quoins(tx - 12, tz - 12, tx + 12, tz + 12, 92, 120, wt)
	for _, face in ipairs({ "S", "N", "W", "E" }) do
		local fx, fz = tx, tz + 12
		if face == "N" then
			fz = tz - 12
		elseif face == "W" then
			fx, fz = tx - 12, tz
		elseif face == "E" then
			fx, fz = tx + 12, tz
		end
		local cf = faceCF(face, fx, 0, fz)
		gothicWindow(cf * CFrame.new(0, 104, 0), 6, 14, wt)
		plate("Soot", cf, pick({ -6.5, 6.5 }), 113, 2, 10, "px_blackstone", SOOT, wt, 0.35)
	end
	cornice(16, 120)
	-- stage 3: the belfry (4×4 blocks) — quartz corner columns around a dark core, a lintel slab
	for _, c in ipairs({ { -8, -8 }, { 4, -8 }, { -8, 4 }, { 4, 4 } }) do
		box("BelfryColumn", tx + c[1], 124, tz + c[2], tx + c[1] + 4, 136, tz + c[2] + 4, "px_smooth_stone", QUARTZ, wt)
	end
	box("BelfryCore", tx - 4, 124, tz - 4, tx + 4, 136, tz + 4, "px_blackstone", SOOT, wt)
	box("BelfryLintel", tx - 8, 136, tz - 8, tx + 8, 140, tz + 8, "px_white_stone_bricks", QUARTZ, wt)
	box("BelfryCornice", tx - 12, 140, tz - 12, tx + 12, 144, tz + 12, "px_stone_bricks", SLATE, wt)
	-- the slate spire to y 180 with the black flag
	spire(tx, tz, 144, 10, wt, math.pi * 0.3)
	-- THE NEST crowning the spire (y 157..167, 6×6 blocks): a dark oak bed, a ragged rim of sticks, black wool
	-- inside, sticks poking out and hanging under it, ravens on the rim
	local nestF = folder("RavenNest", wt)
	box("NestBed", tx - 12, 157, tz - 12, tx + 12, 161, tz + 12, "px_dark_oak_planks", nil, nestF)
	local rim = {}
	for i = 0, 5 do
		table.insert(rim, { tx - 12 + i * 4, tz - 12 })
		table.insert(rim, { tx - 12 + i * 4, tz + 8 })
	end
	for i = 1, 4 do
		table.insert(rim, { tx - 12, tz - 12 + i * 4 })
		table.insert(rim, { tx + 8, tz - 12 + i * 4 })
	end
	local tops = {}
	for _, c in ipairs(rim) do
		if rng:NextNumber() > 0.15 then
			local h = pick({ 4, 4, 6 })
			local v = pick({ "px_dark_oak_planks", "px_dark_oak_log" })
			box("NestRim", c[1], 161, c[2], c[1] + 4, 161 + h, c[2] + 4, v, nil, nestF)
			table.insert(tops, { c[1] + 2, 161 + h, c[2] + 2 })
		end
	end
	for _, c in ipairs({ { -8, -8 }, { -4, -8 }, { 0, -8 }, { 4, -8 }, { -8, 4 }, { -4, 4 }, { 0, 4 }, { 4, 4 }, { -8, -4 }, { -8, 0 }, { 4, -4 }, { 4, 0 } }) do
		box("NestWool", tx + c[1], 161, tz + c[2], tx + c[1] + 4, 163, tz + c[2] + 4, "px_white_wool", SOOT, nestF)
	end
	for _ = 1, 12 do
		local side = rng:NextInteger(1, 4)
		local a = rng:NextNumber() * 20 - 10
		local y = 162 + rng:NextNumber() * 3
		local size, pos
		if side <= 2 then
			size = Vector3.new(1, 1, 8)
			pos = V(tx + a, y, tz + (if side == 1 then -14 else 14))
		else
			size = Vector3.new(8, 1, 1)
			pos = V(tx + (if side == 3 then -14 else 14), y, tz + a)
		end
		textured(decor(part("NestStick", size, CFrame.new(pos), nil, nil, nestF)), "px_dark_oak_log")
	end
	for _ = 1, 8 do
		local x = tx + rng:NextNumber() * 22 - 11
		local z = tz + pick({ -11, 11 })
		if rng:NextNumber() < 0.5 then
			x, z = tx + pick({ -11, 11 }), tz + rng:NextNumber() * 22 - 11
		end
		textured(decor(part("NestStick", Vector3.new(1, 5, 1), at(x, 155, z), nil, nil, nestF)), "px_dark_oak_log")
	end
	for i = 1, math.min(7, #tops) do
		local t = table.remove(tops, rng:NextInteger(1, #tops))
		local yaw = math.atan2(t[1] - tx, t[3] - tz) + (if i % 2 == 0 then math.pi else 0)
		raven(t[1], t[2], t[3], yaw, nestF)
	end
	raven(tx - 10, 128, tz + 14, 0, wt)
	raven(tx - 10, 96, tz - 18, math.pi, wt)
	raven(tx - 5, 148, tz + 9, 0, wt)
end
print(("[build-castle] walls & keep: %d parts, %d ravens"):format(count - partsBefore, nRavens))
