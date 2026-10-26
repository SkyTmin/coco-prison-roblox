--!nocheck
-- ================================================================ castle: the courtyard arena and the districts
-- The round court in front of the keep — the raven knight's arena (COURT, r 52, floor y 0): a rosette of dark and
-- light stone laid flush on the smooth quartz (a cross medallion in the centre, a dark ring, eight petals toward the
-- pillars, eight dark spokes, a grey ring, a chequered ring, a dark border); a low quartz balustrade ring r 52..57.7
-- with six openings (S 90° to the stables alley, SW 150° to the avenue, NW 210° to the hall and the graveyard, N 270°
-- to the keep, NE 330° to the east bailey, SE 30° to the chapel), each flanked by two knight statues on plinths; four
-- square quartz pillars on the diagonals at r ≈ 31 with black wing banners (tagged Pillar); black feathers; lamp posts
-- round it. The disc r ≈ 40 stays open for the fight except the pillars.
-- Around it: the chapel (CHAPEL), the stables, barracks and training yard (STABLES), the knights' hall with its
-- colonnade and round table (HALL), the cursed knight's graveyard (GRAVES), gardens of dark trees on free bailey
-- ground, a hedge alley south of the court, lamp posts along the avenue, a well, guards and ravens.
-- Lanes kept clear (LANES): court openings → districts, the avenue → the arrival and the buyer, the court → the mine.
local court = folder("Court")
local startCount = count
local IRON = Color3.fromRGB(48, 48, 54)
local RAVEN = Color3.fromRGB(30, 30, 36)
local DARK_GLASS = Color3.fromRGB(32, 36, 52)
local WOOL_RED = Color3.fromRGB(128, 34, 40)
local LEAF_DARK = Color3.fromRGB(96, 122, 92)
local WAX = Color3.fromRGB(232, 226, 208)
local FLAME = Color3.fromRGB(255, 186, 90)
local ROOF_V, ROOF_T = "px_blackstone_bricks", Color3.fromRGB(176, 182, 204) -- dark slate
local OPEN_DEG = { 30, 90, 150, 210, 270, 330 } -- the court openings: angle from +X toward +Z (90 = south)
local OPEN_HALF = 10 -- half the clear width of an opening

-- a textured box in a frame cf (a world CFrame) by two local corners
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
-- a small plain decor bit in a frame cf by size and local centre
local function lc(cf, name, sx, sy, sz, x, y, z, color, material, parent)
	return decor(
		part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), color, material, parent)
	)
end
-- a frame at local (x, y, z) whose front (-Z) looks along (dx, dz)
local function fr(x, z, dx, dz, y)
	return at(x, y or 0, z) * CFrame.Angles(0, math.atan2(-dx, -dz), 0)
end
-- the distance of (dx, dz) (from the court centre) to the nearest opening axis, on the outward side of that axis
local function openingPerp(dx, dz)
	local best = math.huge
	for _, deg in ipairs(OPEN_DEG) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		if dx * ux + dz * uz > 0 then
			best = math.min(best, math.abs(-dx * uz + dz * ux))
		end
	end
	return best
end
-- a wall of blocks: axis "x" runs x a0..a1 at z c0..c1 (axis "z": z a0..a1 at x c0..c1); a stone course y 0..4 under
-- the upper variant up to h; doors = { {from, to, top}, ... } (sorted) are cut through it
local function wallRun(name, axis, c0, c1, a0, a1, h, doors, parent, upV, upT, lowV, lowT)
	local function seg(s0, s1, y0, y1, v, t)
		if s1 - s0 < 0.05 or y1 - y0 < 0.05 then
			return
		end
		if axis == "x" then
			box(name, s0, y0, c0, s1, y1, c1, v, t, parent)
		else
			box(name, c0, y0, s0, c1, y1, s1, v, t, parent)
		end
	end
	local cur = a0
	for _, d in ipairs(doors or {}) do
		seg(cur, d[1], 0, 4, lowV or upV, lowT or upT)
		seg(cur, d[1], 4, h, upV, upT)
		seg(d[1], d[2], d[3], h, upV, upT)
		cur = d[2]
	end
	seg(cur, a1, 0, 4, lowV or upV, lowT or upT)
	seg(cur, a1, 4, h, upV, upT)
end
-- a pointed (gothic) window of dark glass through a wall (same axis convention as wallRun), centred at a along the
-- wall, from y0 to y1 plus a pointed top w/2 high
local function glassWin(axis, c0, c1, a, y0, y1, parent, w, color, material)
	w = w or B
	color = color or DARK_GLASS
	material = material or Enum.Material.Glass
	local th = math.abs(c1 - c0) + 0.3
	local c = (c0 + c1) / 2
	local cf = if axis == "x" then at(a, 0, c) else at(c, 0, a) * CFrame.Angles(0, math.pi / 2, 0)
	lc(cf, "Window", w, y1 - y0, th, 0, (y0 + y1) / 2, 0, color, material, parent)
	for _, s in ipairs({ -1, 1 }) do
		-- WedgePart is high at its +Z end: each half rises toward the middle of the window
		decor(
			wedge(
				"WindowArch",
				Vector3.new(th, w / 2, w / 2),
				cf * CFrame.new(s * w / 4, y1 + w / 4, 0) * CFrame.Angles(0, -s * math.pi / 2, 0),
				color,
				material,
				parent
			)
		)
	end
end
-- a stepped roof of dark slate: the ridge runs along axis; each layer is one block up and one block in per side
local function stepRoof(name, axis, x0, x1, z0, z1, y0, n, parent)
	for k = 0, n - 1 do
		local i = 4 * k
		if axis == "z" then
			if x1 - x0 - 2 * i <= 0 then
				break
			end
			box(name, x0 + i, y0 + i, z0, x1 - i, y0 + i + 4, z1, ROOF_V, ROOF_T, parent)
		else
			if z1 - z0 - 2 * i <= 0 then
				break
			end
			box(name, x0, y0 + i, z0 + i, x1, y0 + i + 4, z1 - i, ROOF_V, ROOF_T, parent)
		end
	end
end
-- a ragged black banner with the white wing of the raven knight; cf = the cloth centre, the cloth in the XY plane
local function wingBanner(cf, w, h, parent)
	decor(
		part(
			"BannerPole",
			Vector3.new(w + 0.8, 0.5, 0.5),
			cf * CFrame.new(0, h / 2 + 0.25, 0),
			Color3.fromRGB(70, 52, 38),
			Enum.Material.Wood,
			parent
		)
	)
	local top = h * 0.84
	local cloth = lc(
		cf,
		"Banner",
		w,
		top,
		0.2,
		0,
		h / 2 - top / 2,
		0,
		BANNER_BLACK,
		Enum.Material.Fabric,
		parent
	)
	local tail = h - top
	for _, t in ipairs({ { -0.36, 0.28, 0.8 }, { 0, 0.2, 1 }, { 0.36, 0.28, 0.55 } }) do
		lc(
			cf,
			"BannerTail",
			w * t[2],
			tail * t[3],
			0.2,
			w * t[1],
			-h / 2 + tail - tail * t[3] / 2,
			0,
			BANNER_BLACK,
			Enum.Material.Fabric,
			parent
		)
	end
	-- the wing: a body and two stepped wings rising outward (u = w/8, v = h/16)
	local u, v, y0 = w / 8, h / 16, h * 0.08
	for _, m in ipairs({
		{ 0, 0, 1.2, 4.4 },
		{ 0, 2.8, 1, 1 },
		{ -1.4, 0.8, 1.2, 3.2 },
		{ 1.4, 0.8, 1.2, 3.2 },
		{ -2.6, 1.7, 1.2, 3 },
		{ 2.6, 1.7, 1.2, 3 },
	}) do
		lc(
			cf,
			"BannerWing",
			m[3] * u,
			m[4] * v,
			0.3,
			m[1] * u,
			y0 + m[2] * v,
			0,
			WING_WHITE,
			Enum.Material.Fabric,
			parent
		)
	end
	return cloth
end
-- a raven of blocks perched at cf (cf = the surface it stands on, front -Z); s = scale
local function raven(cf, parent, s)
	s = s or 1
	local function bit(name, sx, sy, sz, x, y, z, color, variant)
		local p = lc(
			cf,
			name,
			sx * s,
			sy * s,
			sz * s,
			x * s,
			y * s,
			z * s,
			color,
			Enum.Material.SmoothPlastic,
			parent
		)
		if variant then
			textured(p, variant, color)
		end
		return p
	end
	local body = bit("Raven", 1.3, 1.3, 2.2, 0, 1.05, 0.1, RAVEN, "px_white_wool")
	bit("RavenHead", 1, 1, 1, 0, 2.05, -1.1, RAVEN, "px_white_wool")
	bit("RavenBeak", 0.35, 0.35, 0.8, 0, 1.95, -1.95, Color3.fromRGB(64, 64, 70))
	bit("RavenTail", 0.9, 0.3, 1.4, 0, 0.75, 1.75, RAVEN)
	bit("RavenLegs", 0.7, 0.4, 0.3, 0, 0.2, 0.1, Color3.fromRGB(40, 40, 44))
	return body
end
-- a sword standing point-down at cf (blade length len)
local function sword(cf, parent, len, color)
	color = color or Color3.fromRGB(200, 204, 212)
	local hilt = Color3.fromRGB(70, 66, 60)
	lc(cf, "SwordBlade", 0.9, len, 0.35, 0, len / 2, 0, color, Enum.Material.Metal, parent)
	lc(cf, "SwordGuard", 3, 0.6, 0.7, 0, len + 0.3, 0, hilt, Enum.Material.Metal, parent)
	lc(
		cf,
		"SwordGrip",
		0.6,
		1.8,
		0.6,
		0,
		len + 1.5,
		0,
		Color3.fromRGB(60, 42, 30),
		Enum.Material.Wood,
		parent
	)
	lc(cf, "SwordPommel", 1, 1, 1, 0, len + 2.8, 0, hilt, Enum.Material.Metal, parent)
end
-- a knight statue in plate armour leaning on a sword, on a plinth (cf at the ground, front -Z); returns the local y
-- of the pauldron tops (a perch for a raven at x ±3.2)
local function knight(cf, parent, tint)
	tint = tint or QUARTZ_SHADE
	lb(cf, "StatuePlinth", -4, 0, -4, 4, 4, 4, "px_stone_bricks", DEEP, parent)
	lb(cf, "StatueStep", -3, 4, -3, 3, 5, 3, "px_smooth_stone", QUARTZ_SHADE, parent)
	local y = 5
	local A = "px_iron_block"
	lb(cf, "StatueLeg", -2.2, y, -1, -0.2, y + 5, 1, A, tint, parent)
	lb(cf, "StatueLeg", 0.2, y, -1, 2.2, y + 5, 1, A, tint, parent)
	lb(cf, "StatueTorso", -2.6, y + 5, -1.4, 2.6, y + 10, 1.4, A, tint, parent)
	decor(
		lb(cf, "StatueBelt", -2.8, y + 5.2, -1.6, 2.8, y + 6, 1.6, "px_stone_bricks", DEEP, parent)
	)
	for _, s in ipairs({ -1, 1 }) do
		decor(
			lb(
				cf,
				"StatuePauldron",
				s * 2.2,
				y + 8.6,
				-1.7,
				s * 4.2,
				y + 10.4,
				1.7,
				A,
				tint,
				parent
			)
		)
		decor(lb(cf, "StatueArm", s * 2.3, y + 6.2, -2.6, s * 3.9, y + 9.2, -0.2, A, tint, parent))
	end
	decor(lb(cf, "StatueHands", -2.4, y + 5.4, -3.4, 2.4, y + 6.6, -2.2, A, tint, parent))
	lb(cf, "StatueHelm", -1.6, y + 10, -1.6, 1.6, y + 13.2, 1.6, A, tint, parent)
	lc(
		cf,
		"StatueVisor",
		2.4,
		0.5,
		0.2,
		0,
		y + 11.8,
		-1.65,
		SOOT,
		Enum.Material.SmoothPlastic,
		parent
	)
	decor(
		lb(
			cf,
			"StatueCrest",
			-0.4,
			y + 13.2,
			-1.4,
			0.4,
			y + 14.2,
			1.4,
			"px_stone_bricks",
			DEEP,
			parent
		)
	)
	sword(cf * CFrame.new(0, y, -2.8), parent, 5.2)
	return y + 10.4
end
local function candle(x, y, z, parent, lit)
	decor(
		part(
			"Candle",
			Vector3.new(0.6, 1.2, 0.6),
			at(x, y + 0.6, z),
			WAX,
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	local flame = decor(
		part(
			"CandleFlame",
			Vector3.new(0.3, 0.45, 0.3),
			at(x, y + 1.45, z),
			FLAME,
			Enum.Material.Neon,
			parent
		)
	)
	if lit then
		light(flame, 14, 0.9, LANTERN_GLOW)
	end
end
-- a black feather lying on the floor (a thin plate, some with a second vane)
local function feather(x, z, y, parent)
	local cf = at(x, (y or 0) + 0.16, z) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0)
	lc(cf, "Feather", 0.8, 0.12, 2.4, 0, 0, 0, BANNER_BLACK, Enum.Material.Fabric, parent)
	if rng:NextNumber() < 0.4 then
		lc(
			cf * CFrame.Angles(0, 0.5, 0),
			"Feather",
			0.5,
			0.1,
			1.4,
			0.5,
			0.01,
			0.8,
			BANNER_BLACK,
			Enum.Material.Fabric,
			parent
		)
	end
end
-- an iron cage (4 × 6) at cf (its floor), optionally with a raven inside
local function cage(cf, parent, withRaven)
	lc(cf, "CageFloor", 4.4, 0.5, 4.4, 0, 0.25, 0, IRON, Enum.Material.Metal, parent)
	lc(cf, "CageTop", 4.4, 0.5, 4.4, 0, 5.75, 0, IRON, Enum.Material.Metal, parent)
	lc(cf, "CageRing", 1.4, 1, 0.3, 0, 6.5, 0, IRON, Enum.Material.Metal, parent)
	for _, p in ipairs({ -2, -0.7, 0.7, 2 }) do
		lc(cf, "CageBar", 0.35, 5, 0.35, p, 3, -2, IRON, Enum.Material.Metal, parent)
		lc(cf, "CageBar", 0.35, 5, 0.35, p, 3, 2, IRON, Enum.Material.Metal, parent)
		if math.abs(p) < 1 then
			lc(cf, "CageBar", 0.35, 5, 0.35, -2, 3, p, IRON, Enum.Material.Metal, parent)
			lc(cf, "CageBar", 0.35, 5, 0.35, 2, 3, p, IRON, Enum.Material.Metal, parent)
		end
	end
	if withRaven then
		raven(
			cf * CFrame.new(0, 0.5, 0) * CFrame.Angles(0, rng:NextNumber() * math.pi * 2, 0),
			parent
		)
	end
end
-- a raven nest of sticks at local (x, y, z)
local function nest(x, y, z, parent, withRaven)
	local cf = at(x, y, z) * CFrame.Angles(0, rng:NextNumber() * math.pi, 0)
	for i = 0, 3 do
		lb(
			cf * CFrame.Angles(0, i * math.pi / 2, 0),
			"Nest",
			-3.4,
			0,
			-3.4,
			2,
			1.6,
			-2,
			"px_dark_oak_log",
			Color3.fromRGB(150, 130, 110),
			parent
		)
	end
	decor(lb(cf, "NestLining", -2, 0, -2, 2, 0.8, 2, "px_white_wool", RAVEN, parent))
	lc(
		cf * CFrame.Angles(0, 0.6, 0.2),
		"NestStick",
		0.5,
		0.5,
		8,
		0,
		1.4,
		0,
		Color3.fromRGB(80, 60, 44),
		Enum.Material.Wood,
		parent
	)
	if withRaven then
		raven(cf * CFrame.new(0, 0.8, 0), parent)
	end
end
-- a dark garden tree (kit tree, leaves tinted darker, dark oak trunk)
local function darkTree(x, z, h, parent)
	local f = tree(x, z, h, parent, "px_hedge", "px_dark_oak_log")
	for _, p in ipairs(f:GetChildren()) do
		if p.Name == "Leaves" then
			p.Color = LEAF_DARK
		end
	end
	return f
end
-- a dead tree: a bare trunk with block branches turning up at the ends; returns the branch tips { {x, y, z}, ... }
local function deadTree(x, z, h, parent)
	local f = folder("DeadTree", parent)
	local bark = Color3.fromRGB(150, 140, 132)
	box("DeadTrunk", x - 2, 0, z - 2, x + 2, h, z + 2, "px_dark_oak_log", bark, f)
	local tips = { { x, h, z } }
	for _, s in ipairs({
		{ 1, 0, h - 10, 8 },
		{ 0, 1, h - 6, 8 },
		{ -1, 0, h - 14, 4 },
		{ 0, -1, h - 4, 4 },
	}) do
		local dx, dz, y, len = s[1], s[2], s[3], s[4]
		if y > 4 then
			local ax, az = x + dx * 2, z + dz * 2
			local ex, ez = x + dx * (2 + len), z + dz * (2 + len)
			local wx, wz = if dx == 0 then 2 else 0, if dz == 0 then 2 else 0
			box(
				"DeadBranch",
				math.min(ax, ex) - wx,
				y,
				math.min(az, ez) - wz,
				math.max(ax, ex) + wx,
				y + 4,
				math.max(az, ez) + wz,
				"px_dark_oak_log",
				bark,
				f
			)
			local cx, cz = x + dx * len, z + dz * len
			box(
				"DeadBranch",
				cx - 2,
				y + 4,
				cz - 2,
				cx + 2,
				y + 8,
				cz + 2,
				"px_dark_oak_log",
				bark,
				f
			)
			table.insert(tips, { cx, y + 8, cz, y })
		end
	end
	return tips
end
local function bench(x, z, dx, dz, parent)
	local cf = fr(x, z, dx, dz)
	lb(cf, "BenchSeat", -4, 1.6, -1.2, 4, 2.6, 1.2, "px_smooth_stone", QUARTZ_SHADE, parent)
	for _, s in ipairs({ -1, 1 }) do
		lb(
			cf,
			"BenchLeg",
			s * 3.2 - 0.8,
			0,
			-1,
			s * 3.2 + 0.8,
			1.6,
			1,
			"px_stone_bricks",
			DEEP,
			parent
		)
	end
end
-- a flock of ravens circling round a vertical axis at local (x, z): an Atomic model tagged AmbientSpin (the client
-- turns it, src/client/AmbientMotion.luau); each bird faces the way the turn carries it
local function flock(x, z, n, r0, r1, y0, y1, parent)
	local model = Instance.new("Model")
	model.Name = "RavenFlock"
	model.Parent = parent
	for i = 1, n do
		local phi = (i / n) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
		local r = rng:NextNumber(r0, r1)
		local px, pz = x + math.cos(phi) * r, z + math.sin(phi) * r
		local cf = fr(px, pz, math.sin(phi), -math.cos(phi), rng:NextNumber(y0, y1))
			* CFrame.Angles(0, 0, rng:NextNumber(-0.25, 0.25))
		textured(
			lc(cf, "FlyingRaven", 1.2, 1, 2.4, 0, 0, 0, RAVEN, nil, model),
			"px_white_wool",
			RAVEN
		)
		lc(
			cf,
			"FlyingRavenHead",
			0.9,
			0.9,
			0.9,
			0,
			0.3,
			-1.5,
			RAVEN,
			Enum.Material.SmoothPlastic,
			model
		)
		lc(
			cf,
			"FlyingRavenBeak",
			0.3,
			0.3,
			0.7,
			0,
			0.2,
			-2.2,
			Color3.fromRGB(64, 64, 70),
			Enum.Material.SmoothPlastic,
			model
		)
		lc(
			cf,
			"FlyingRavenTail",
			0.9,
			0.2,
			1.2,
			0,
			-0.1,
			1.7,
			RAVEN,
			Enum.Material.SmoothPlastic,
			model
		)
		for _, s in ipairs({ -1, 1 }) do
			lc(
				cf * CFrame.new(s * 2.1, 0.5, 0) * CFrame.Angles(0, 0, s * 0.35),
				"FlyingRavenWing",
				3.2,
				0.25,
				1.6,
				0,
				0,
				0,
				RAVEN,
				Enum.Material.SmoothPlastic,
				model
			)
		end
	end
	model.WorldPivot = at(x, (y0 + y1) / 2, z)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model:SetAttribute("Speed", 0.14)
	CollectionService:AddTag(model, "AmbientSpin")
	return model
end
local function guard(x, z, dx, dz, parent)
	npc(
		"Guard",
		fr(x, z, dx, dz, 3),
		{ shirt = Color3.fromRGB(120, 124, 132), pants = Color3.fromRGB(70, 72, 80) },
		parent
	)
end
-- lanes the scatter keeps off: { ax, az, bx, bz, half width }
local LANES = {
	{ 99, -23, 148, 20, 10 }, -- SE opening → the chapel yard
	{ 56, 8, 56, 120, 22 }, -- S opening → the hedge alley → the stables yard
	{ 4, -18, 0, 8, 12 }, -- SW opening → the avenue
	{ 4, -18, -140, -60, 10 }, -- SW opening → the knights' hall
	{ 4, -18, -96, -12, 8 }, -- the court → the mine (north rim)
	{ 13, -73, -100, -156, 10 }, -- NW opening → the graveyard gate
	{ 56, -100, 56, -114, 14 }, -- N opening → the keep
	{ 99, -73, 150, -110, 10 }, -- NE opening → the east bailey
	{ -12, 158, -110, 158, 16 }, -- the avenue → the arrival and the buyer
	{ 12, 136, 40, 136, 8 }, -- the avenue → the stables
	{ -130, -112, -130, -96, 8 }, -- the graveyard south gate → the hall
}
local function onLane(x, z, pad)
	for _, l in ipairs(LANES) do
		if segDist(x, z, l[1], l[2], l[3], l[4]) < l[5] + pad then
			return true
		end
	end
	return false
end
local RES = {} -- reserved circles { x, z, r } the garden scatter keeps off
local function reserve(x, z, r)
	table.insert(RES, { x, z, r })
end
local function isReserved(x, z, pad)
	for _, c in ipairs(RES) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < (c[3] + pad) ^ 2 then
			return true
		end
	end
	return false
end

-- ================================================================ 1. the courtyard arena
do
	local arena = folder("Arena", court)
	local CELLS = 15 -- cells of 4 studs each way from the centre (r 60)
	-- the floor pattern of the cell centred at (dx, dz) from the court centre: variant, tint (nil = the plain court)
	local function rosette(dx, dz, ix, iz)
		local rr = math.sqrt(dx * dx + dz * dz)
		if rr >= 52 then
			if rr < 60 and openingPerp(dx, dz) < OPEN_HALF then
				return "px_stone_bricks", DEEP -- the dark thresholds of the openings
			end
			return nil
		end
		local ax, az = math.abs(dx), math.abs(dz)
		if ax < 12 and az < 12 then
			if ax < 4 or az < 4 then
				return "px_white_stone_bricks", QUARTZ -- the white cross of the medallion
			end
			return "px_blackstone_bricks", nil
		end
		if rr >= 48 then
			return "px_stone_bricks", DEEP
		end
		if rr >= 40 and rr < 45.7 then
			if (ix + iz) % 2 == 0 then
				return "px_blackstone", nil
			end
			return "px_white_stone_bricks", QUARTZ
		end
		local th = math.atan2(dz, dx)
		if rr >= 30 then
			-- eight dark spokes between the petals cross the grey ring
			local k = math.floor((th - math.pi / 8) / (math.pi / 4) + 0.5)
			if math.abs(rr * math.sin(th - (k * math.pi / 4 + math.pi / 8))) < 2.6 then
				return "px_blackstone_bricks", nil
			end
			if rr < 35.7 then
				return "px_smooth_stone", QUARTZ_SHADE
			end
		end
		if rr >= 12 and rr < 17.7 then
			return "px_stone_bricks", DEEP
		end
		if rr >= 17.7 and rr < 30 then
			-- eight petals pointing at the pillars and the axes, with a grey rim
			local p = math.abs(math.cos(4 * th))
			if rr - 17.7 < 12 * p * p then
				return "px_stone_bricks", DEEP
			elseif rr - 17.7 < 12 * p then
				return "px_smooth_stone", QUARTZ_SHADE
			end
		end
		if rng:NextNumber() < 0.07 then
			return "px_blackstone", nil -- soot-stained tiles
		end
		return nil
	end
	-- lay the pattern flush (y -0.2 .. 0.1) in runs along x
	for iz = -CELLS, CELLS - 1 do
		local z0 = COURT.z + iz * B
		local runX, runKey, runV, runT = nil, nil, nil, nil
		local function flush(xEnd)
			if runX then
				box("Rosette", runX, -0.2, z0, xEnd, 0.1, z0 + B, runV, runT, arena)
			end
			runX = nil
		end
		for ix = -CELLS, CELLS - 1 do
			local v, t = rosette(ix * B + 2, iz * B + 2, ix, iz)
			local key = if v then v .. tostring(t) else nil
			if key ~= runKey then
				flush(COURT.x + ix * B)
				if v then
					runX, runV, runT = COURT.x + ix * B, v, t
				end
				runKey = key
			end
		end
		flush(COURT.x + CELLS * B)
	end
	task.wait()

	-- the balustrade ring r 52..57.7 (one block high with a coping), cut at the six openings
	local wallCells = {}
	for iz = -CELLS, CELLS - 1 do
		local z0 = COURT.z + iz * B
		local runX = nil
		local function flush(xEnd)
			if runX then
				box(
					"Balustrade",
					runX,
					0,
					z0,
					xEnd,
					4,
					z0 + B,
					"px_white_stone_bricks",
					QUARTZ,
					arena
				)
				box(
					"BalustradeCoping",
					runX,
					4,
					z0,
					xEnd,
					5,
					z0 + B,
					"px_smooth_stone",
					QUARTZ_SHADE,
					arena
				)
			end
			runX = nil
		end
		for ix = -CELLS, CELLS - 1 do
			local dx, dz = ix * B + 2, iz * B + 2
			local rr = math.sqrt(dx * dx + dz * dz)
			if rr >= 52 and rr < 57.7 and openingPerp(dx, dz) >= OPEN_HALF + 3 then
				wallCells[ix .. "," .. iz] = true
				runX = runX or COURT.x + ix * B
			else
				flush(COURT.x + ix * B)
			end
		end
		flush(COURT.x + CELLS * B)
	end
	-- posts on the balustrade every ~20°
	local used = {}
	for k = 0, 17 do
		local a = math.rad(k * 20 + 5)
		local ix, iz = math.floor(math.cos(a) * 54.8 / B), math.floor(math.sin(a) * 54.8 / B)
		local key = ix .. "," .. iz
		if wallCells[key] and not used[key] then
			used[key] = true
			local cx, cz = COURT.x + ix * B + 2, COURT.z + iz * B + 2
			cube("BalustradePost", cx, 7, cz, 4.4, 4, 4.4, "px_white_stone_bricks", QUARTZ, arena)
			cube("BalustradePostCap", cx, 9.5, cz, 4.8, 1, 4.8, "px_stone_bricks", DEEP, arena)
			if k % 5 == 1 then
				raven(fr(cx, cz, -math.cos(a), -math.sin(a), 10), arena)
			end
		end
	end

	-- four square quartz pillars on the diagonals (3×3 blocks, 8 blocks of shaft) with black wing banners
	for _, s in ipairs({ { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }) do
		local px, pz = COURT.x + s[1] * 22, COURT.z + s[2] * 22
		pillarTag(
			box("PillarBase", px - 8, 0, pz - 8, px + 8, 4, pz + 8, "px_stone_bricks", DEEP, arena)
		)
		pillarTag(
			box(
				"Pillar",
				px - 6,
				4,
				pz - 6,
				px + 6,
				32,
				pz + 6,
				"px_white_stone_bricks",
				QUARTZ,
				arena
			)
		)
		pillarTag(
			box(
				"PillarCapital",
				px - 8,
				32,
				pz - 8,
				px + 8,
				36,
				pz + 8,
				"px_stone_bricks",
				DEEP,
				arena
			)
		)
		box(
			"PillarCrown",
			px - 6,
			36,
			pz - 6,
			px + 6,
			40,
			pz + 6,
			"px_smooth_stone",
			QUARTZ_SHADE,
			arena
		)
		for _, m in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			box(
				"PillarMerlon",
				px + m[1] * 4 - 2,
				40,
				pz + m[2] * 4 - 2,
				px + m[1] * 4 + 2,
				44,
				pz + m[2] * 4 + 2,
				"px_white_stone_bricks",
				QUARTZ,
				arena
			)
		end
		-- the banners hang on the two faces turned to the centre of the court
		wingBanner(at(px - s[1] * 6.3, 19, pz) * CFrame.Angles(0, math.pi / 2, 0), 8, 18, arena)
		wingBanner(at(px, 19, pz - s[2] * 6.3), 8, 18, arena)
		raven(fr(px, pz, -s[1], -s[2], 40), arena)
	end

	-- knight statues flanking every opening, on the balustrade line, looking out
	for i, deg in ipairs(OPEN_DEG) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		local nx, nz = -uz, ux
		local off = if deg == 270 then 17 else 14 -- the keep steps (x 44..68, z -112..-104) sit between the north pair
		for _, sgn in ipairs({ -1, 1 }) do
			local cf =
				fr(COURT.x + ux * 54 + nx * sgn * off, COURT.z + uz * 54 + nz * sgn * off, ux, uz)
			local perch = knight(cf, arena)
			if (i + sgn) % 3 == 0 then
				raven(cf * CFrame.new(3.2 * sgn, perch, 0), arena)
			end
		end
	end
	-- guards beside the bailey openings and at the keep steps (no tag: decoration)
	for _, g in ipairs({ { 90, 1 }, { 30, -1 }, { 150, 1 }, { 210, -1 } }) do
		local a = math.rad(g[1])
		local ux, uz = math.cos(a), math.sin(a)
		guard(COURT.x + ux * 61 - uz * g[2] * 14, COURT.z + uz * 61 + ux * g[2] * 14, ux, uz, arena)
	end
	guard(COURT.x - 16, KEEP.z1 + 3, 0, 1, arena)
	guard(COURT.x + 16, KEEP.z1 + 3, 0, 1, arena)

	-- black feathers scattered over the court (not inside the pillar bases)
	for _ = 1, 70 do
		local a = rng:NextNumber() * math.pi * 2
		local r = 6 + rng:NextNumber() * 44
		local dx, dz = math.cos(a) * r, math.sin(a) * r
		if not (math.abs(math.abs(dx) - 22) < 9 and math.abs(math.abs(dz) - 22) < 9) then
			feather(COURT.x + dx, COURT.z + dz, 0, arena)
		end
	end
	-- ravens circling high over the court
	flock(COURT.x, COURT.z, 12, 18, 46, 52, 78, arena)
	-- lamp posts round the court (every 22.5°, not in front of an opening), lanterns toward the centre
	for k = 0, 15 do
		local deg = k * 22.5
		local near = 180
		for _, o in ipairs(OPEN_DEG) do
			near = math.min(near, math.abs((deg - o + 180) % 360 - 180))
		end
		if near >= 14 then
			local a = math.rad(deg)
			lampPost(
				COURT.x + math.cos(a) * 62,
				COURT.z + math.sin(a) * 62,
				arena,
				false,
				math.atan2(math.cos(a), math.sin(a))
			)
		end
	end
end
task.wait()

-- ================================================================ 2. the chapel (CHAPEL)
do
	local f = folder("Chapel", court)
	local X0, X1, Z0, Z1 = 136, 160, 48, 100 -- the nave, outer faces; the door in the north wall faces the bailey
	local H = 20
	local UP, UPT, LOW, LOWT = "px_white_stone_bricks", QUARTZ, "px_stone_bricks", DEEP
	box(
		"ChapelFloor",
		X0 + 4,
		-0.2,
		Z0 + 4,
		X1 - 4,
		0.1,
		Z1 - 4,
		"px_smooth_stone",
		QUARTZ_SHADE,
		f
	)
	decor(box("ChapelCarpet", 146, 0.1, Z0 + 4, 150, 0.3, 87, "px_white_wool", WOOL_RED, f))
	wallRun("ChapelWall", "x", Z0, Z0 + 4, X0, X1, H, { { 144, 152, 12 } }, f, UP, UPT, LOW, LOWT)
	wallRun("ChapelWall", "x", Z1 - 4, Z1, X0, X1, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun("ChapelWall", "z", X0, X0 + 4, Z0 + 4, Z1 - 4, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun("ChapelWall", "z", X1 - 4, X1, Z0 + 4, Z1 - 4, H, nil, f, UP, UPT, LOW, LOWT)
	-- the pointed door arch and the open dark oak doors
	for _, s in ipairs({ -1, 1 }) do
		textured(
			wedge(
				"DoorArch",
				Vector3.new(4, 2, 4),
				at(148 + s * 2, 11, Z0 + 2) * CFrame.Angles(0, s * math.pi / 2, 0),
				nil,
				nil,
				f
			),
			UP,
			UPT
		)
		box(
			"ChapelDoor",
			148 + s * 4,
			0.1,
			Z0 + 4,
			148 + s * 8,
			11,
			Z0 + 4.6,
			"px_dark_oak_planks",
			nil,
			f
		)
	end
	-- pointed windows of dark glass between the buttresses, three lancets behind the altar
	for _, z in ipairs({ 58, 70, 82 }) do
		glassWin("z", X0, X0 + 4, z, 5, 15, f)
		glassWin("z", X1 - 4, X1, z, 5, 15, f)
	end
	glassWin("x", Z1 - 4, Z1, 142, 6, 14, f)
	glassWin("x", Z1 - 4, Z1, 148, 5, 16, f)
	glassWin("x", Z1 - 4, Z1, 154, 6, 14, f)
	for _, bz in ipairs({ 48, 62, 74, 86, 96 }) do
		for _, bx in ipairs({ X0 - 4, X1 }) do
			box("Buttress", bx, 0, bz, bx + 4, 4, bz + 4, LOW, LOWT, f)
			box("Buttress", bx, 4, bz, bx + 4, 16, bz + 4, UP, QUARTZ_SHADE, f)
		end
	end
	stepRoof("ChapelRoof", "z", X0 - 4, X1 + 4, Z0 - 2, Z1 + 2, H, 4, f)
	-- the bell turret over the door: a quartz shaft through the roof, an open belfry, a slate spire, an iron cross
	box("Turret", 142, H, 48, 154, 40, 60, UP, UPT, f)
	for _, c in ipairs({ { 142, 48 }, { 150, 48 }, { 150, 56 }, { 142, 56 } }) do
		box("BelfryPost", c[1], 40, c[2], c[1] + 4, 48, c[2] + 4, UP, UPT, f)
	end
	decor(box("BellBeam", 143, 46.5, 53.5, 153, 47.5, 54.5, "px_dark_oak_log", nil, f))
	decor(
		box(
			"Bell",
			146.5,
			42.5,
			52.5,
			149.5,
			46.5,
			55.5,
			"px_gold_block",
			Color3.fromRGB(190, 150, 90),
			f
		)
	)
	box("BelfryCornice", 141, 48, 47, 155, 52, 61, LOW, LOWT, f)
	box("Spire", 143, 52, 49, 153, 56, 59, ROOF_V, ROOF_T, f)
	box("Spire", 145, 56, 51, 151, 60, 57, ROOF_V, ROOF_T, f)
	box("Spire", 147, 60, 53, 149, 68, 55, ROOF_V, ROOF_T, f)
	decor(box("SpireCross", 147.7, 68, 53.7, 148.3, 73, 54.3, nil, IRON, f)).Material =
		Enum.Material.Metal
	decor(box("SpireCross", 146.6, 70.6, 53.7, 149.4, 71.2, 54.3, nil, IRON, f)).Material =
		Enum.Material.Metal
	raven(fr(142.5, 47.5, -1, 0, 52), f)
	raven(fr(148, 76, 1, 0, 36), f)
	-- wing banners on the front, flanking the door
	wingBanner(at(140, 10, Z0 - 0.3), 4, 10, f)
	wingBanner(at(156, 10, Z0 - 0.3), 4, 10, f)
	-- pews (spruce), facing the altar in the south
	for row = 0, 4 do
		local z = 58 + row * 6
		for _, side in ipairs({ { 140.5, 145.5 }, { 150.5, 155.5 } }) do
			box("Pew", side[1], 0.1, z, side[2], 2, z + 2.4, "px_spruce_planks", nil, f)
			box("PewBack", side[1], 0.1, z - 0.6, side[2], 5, z, "px_spruce_planks", nil, f)
		end
	end
	-- the altar with a black cloth, the white wing, candles
	box("Altar", 143, 0.1, 88, 153, 4.1, 92, UP, UPT, f)
	decor(box("AltarCloth", 142.8, 4.1, 87.8, 153.2, 4.4, 92.2, "px_white_wool", BANNER_BLACK, f))
	decor(box("AltarDrape", 145, 1.2, 87.5, 151, 4.1, 87.8, "px_white_wool", BANNER_BLACK, f))
	lc(
		at(148, 2.9, 87.45),
		"AltarWing",
		2.4,
		1.2,
		0.1,
		0,
		0,
		0,
		WING_WHITE,
		Enum.Material.Fabric,
		f
	)
	for i, x in ipairs({ 144, 146, 150, 152 }) do
		candle(x, 4.4, 90.5, f, i == 2)
	end
	for _, x in ipairs({ 140.8, 155.2 }) do
		decor(box("CandleStand", x - 0.3, 0.1, 89.7, x + 0.3, 5, 90.3, nil, IRON, f)).Material =
			Enum.Material.Metal
		candle(x, 5, 90, f, false)
	end
	lantern(V(148, 13, 64), f, false, BY + H)
	lantern(V(148, 13, 80), f, false, BY + H)
	-- the yard in front: a path, a low hedge border, a knight statue and a raven on a column, lamps
	box("ChapelPath", 144, -0.2, CHAPEL.z0, 152, 0.1, Z0, LOW, LOWT, f)
	box("YardHedge", 122, 0, 22, 140, 4, 26, "px_hedge", LEAF_DARK, f)
	box("YardHedge", 156, 0, 22, 174, 4, 26, "px_hedge", LEAF_DARK, f)
	box("YardHedge", 122, 0, 26, 126, 4, 42, "px_hedge", LEAF_DARK, f)
	box("YardHedge", 170, 0, 26, 174, 4, 42, "px_hedge", LEAF_DARK, f)
	knight(fr(132, 35, 1, 0), f)
	box("RavenColumnBase", 160, 0, 31, 168, 4, 39, LOW, LOWT, f)
	box("RavenColumn", 162, 4, 33, 166, 16, 37, UP, UPT, f)
	box("RavenColumnCap", 161, 16, 32, 167, 17, 38, LOW, LOWT, f)
	raven(fr(164, 35, -1, 0, 17), f, 2.4)
	for _, x in ipairs({ 128, 136 }) do
		box("FlowerBed", x - 2, -0.2, 41, x + 2, 0.6, 45, "px_dirt", nil, f)
		decor(
			cube(
				"Flowers",
				x,
				1.4,
				43,
				2.2,
				1.6,
				2.2,
				"px_white_wool",
				if x == 128 then WOOL_RED else nil,
				f
			)
		)
	end
	lampPost(141, 30, f, false, -math.pi / 2)
	lampPost(155, 30, f, false, math.pi / 2)
	zoneSign(158, 16, "Часовня", 0, f)
	for _ = 1, 8 do
		feather(124 + rng:NextNumber() * 48, 28 + rng:NextNumber() * 14, 0, f)
	end
end
task.wait()

-- ================================================================ 3. the stables, the barracks and the training yard
do
	local f = folder("Stables", court)
	-- a block horse (body, legs, neck, head, mane, tail) at cf (the ground, front -Z = the head)
	local function horse(cf, variant, tint)
		local dark = Color3.fromRGB(46, 40, 36)
		lb(cf, "HorseBody", -2, 4, -4.5, 2, 8, 4.5, variant, tint, f)
		for _, l in ipairs({ { -1.2, -3.4 }, { 1.2, -3.4 }, { -1.2, 3.4 }, { 1.2, 3.4 } }) do
			decor(
				lb(
					cf,
					"HorseLeg",
					l[1] - 0.75,
					0,
					l[2] - 0.75,
					l[1] + 0.75,
					4,
					l[2] + 0.75,
					variant,
					tint,
					f
				)
			)
		end
		decor(lb(cf, "HorseNeck", -1, 6.5, -6, 1, 11.5, -3.6, variant, tint, f))
		decor(lb(cf, "HorseHead", -1.2, 9.6, -9.6, 1.2, 12, -5, variant, tint, f))
		decor(lb(cf, "HorseMane", -0.4, 7, -3.9, 0.4, 12.2, -3.2, "px_white_wool", dark, f))
		decor(lb(cf, "HorseTail", -0.5, 3.4, 4.5, 0.5, 7.6, 5.5, "px_white_wool", dark, f))
	end
	-- the stables: x 36..108, z 144..172, open to the north; quartz walls on a stone course, dark oak timbers
	local function timberWall(x0, z0, x1, z1)
		box("StableWall", x0, 0, z0, x1, 4, z1, "px_stone_bricks", DEEP, f)
		box("StableWall", x0, 4, z0, x1, 12, z1, "px_white_stone_bricks", QUARTZ, f)
		box("StableBeam", x0, 12, z0, x1, 16, z1, "px_dark_oak_log", nil, f)
	end
	box("StableFloor", 40, -0.2, 144, 104, 0.1, 168, "px_dirt", Color3.fromRGB(170, 150, 120), f)
	timberWall(36, 168, 108, 172)
	timberWall(36, 148, 40, 168)
	timberWall(104, 148, 108, 168)
	for _, x in ipairs({ 36, 54, 70, 86, 104 }) do
		box("StablePost", x, 0, 144, x + 4, 12, 148, "px_dark_oak_log", nil, f)
	end
	box("StableLintel", 36, 12, 144, 108, 16, 148, "px_dark_oak_log", nil, f)
	stepRoof("StableRoof", "x", 34, 110, 142, 174, 16, 4, f)
	for i = 1, 4 do
		local a = 40 + (i - 1) * 16
		if i < 4 then
			box("StallBoard", a + 15.5, 0.1, 148, a + 16.5, 6, 168, "px_spruce_planks", nil, f)
		end
		box("Trough", a + 2, 0.1, 164, a + 10, 3, 168, "px_spruce_planks", nil, f)
		lc(
			at(a + 6, 2.9, 166),
			"TroughWater",
			7,
			0.2,
			3,
			0,
			0,
			0,
			Color3.fromRGB(70, 92, 120),
			Enum.Material.Glass,
			f
		)
		box("HayBale", a + 11, 0.1, 164, a + 15, 4.1, 168, "px_hay", nil, f)
		if i == 1 then
			horse(fr(a + 8, 155, 0, -1), "px_brown_wool", nil)
		elseif i == 2 then
			horse(fr(a + 8, 155, 0, -1), "px_gray_wool", nil)
		elseif i == 3 then
			box("HayBale", a + 11, 4.1, 164, a + 15, 8.1, 168, "px_hay", nil, f)
			box("HayBale", a + 4, 0.1, 152, a + 8, 4.1, 156, "px_hay", nil, f)
			decor(box("Saddle", a + 15, 6, 156, a + 17, 7.6, 159, "px_brown_wool", nil, f))
		else
			horse(fr(a + 8, 155, 0, -1), "px_white_wool", QUARTZ_SHADE)
		end
	end
	lantern(V(64, 11, 158), f, false, BY + 16)
	lantern(V(88, 11, 158), f, false, BY + 16)
	raven(fr(50, 158, 1, 0, 32), f)
	-- hay stacked by the west wall, a horse outside at its hay and a trough
	for _, h in ipairs({ { 32, 152, 0 }, { 32, 156, 0 }, { 32, 160, 0 }, { 32, 154, 4 } }) do
		box("HayBale", h[1] - 2, h[3], h[2] - 2, h[1] + 2, h[3] + 4, h[2] + 2, "px_hay", nil, f)
	end
	horse(fr(86, 130, 1, 0), "px_brown_wool", Color3.fromRGB(200, 170, 150))
	box("HayBale", 98, 0, 128, 102, 4, 132, "px_hay", nil, f)
	box("Trough", 80, 0, 124, 92, 3, 127, "px_spruce_planks", nil, f)
	lc(
		at(86, 2.9, 125.5),
		"TroughWater",
		11,
		0.2,
		2,
		0,
		0,
		0,
		Color3.fromRGB(70, 92, 120),
		Enum.Material.Glass,
		f
	)

	-- the barracks: x 116..172, z 144..172, the door in the north wall toward the yard
	local K0, K1, KZ0, KZ1 = 116, 172, 144, 172
	local H = 20
	local UP, UPT, LOW, LOWT = "px_white_stone_bricks", QUARTZ, "px_stone_bricks", DEEP
	box("BarracksFloor", K0 + 4, -0.2, KZ0 + 4, K1 - 4, 0.1, KZ1 - 4, "px_spruce_planks", nil, f)
	wallRun(
		"BarracksWall",
		"x",
		KZ0,
		KZ0 + 4,
		K0,
		K1,
		H,
		{ { 140, 148, 12 } },
		f,
		UP,
		UPT,
		LOW,
		LOWT
	)
	wallRun("BarracksWall", "x", KZ1 - 4, KZ1, K0, K1, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun("BarracksWall", "z", K0, K0 + 4, KZ0 + 4, KZ1 - 4, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun("BarracksWall", "z", K1 - 4, K1, KZ0 + 4, KZ1 - 4, H, nil, f, UP, UPT, LOW, LOWT)
	for _, x in ipairs({ 126, 134, 156, 164 }) do
		glassWin("x", KZ0, KZ0 + 4, x, 6, 14, f)
	end
	for _, x in ipairs({ 130, 144, 158 }) do
		glassWin("x", KZ1 - 4, KZ1, x, 6, 14, f)
	end
	glassWin("z", K1 - 4, K1, 158, 6, 14, f)
	stepRoof("BarracksRoof", "x", K0 - 2, K1 + 2, KZ0 - 2, KZ1 + 2, H, 4, f)
	box("Chimney", 160, H, 163, 164, 40, 167, "px_cobblestone", nil, f)
	wingBanner(at(144, 16.2, KZ0 - 0.3), 4, 6, f)
	raven(fr(130, 158, -1, 0, 36), f)
	-- bunk beds along the south wall
	for _, cx in ipairs({ 124, 134, 144, 154, 164 }) do
		for _, px in ipairs({ cx - 2, cx + 2 }) do
			for _, pz in ipairs({ 158.5, 167.5 }) do
				box(
					"BunkPost",
					px - 0.5,
					0.1,
					pz - 0.5,
					px + 0.5,
					9,
					pz + 0.5,
					"px_dark_oak_planks",
					nil,
					f
				)
			end
		end
		for _, y in ipairs({ 1.2, 5.6 }) do
			box("BunkFrame", cx - 2, y, 158.5, cx + 2, y + 1, 167.5, "px_spruce_planks", nil, f)
			box(
				"BunkMattress",
				cx - 1.8,
				y + 1,
				158.8,
				cx + 1.8,
				y + 1.8,
				167.2,
				"px_white_wool",
				nil,
				f
			)
			decor(
				box(
					"BunkBlanket",
					cx - 1.9,
					y + 1.8,
					158.6,
					cx + 1.9,
					y + 2.1,
					164,
					"px_gray_wool",
					nil,
					f
				)
			)
		end
	end
	-- weapon racks with swords (one inside by the west wall, one in the yard)
	local function rack(cf)
		for _, s in ipairs({ -1, 1 }) do
			lb(
				cf,
				"RackPost",
				s * 4 - 0.5,
				0,
				-0.5,
				s * 4 + 0.5,
				7,
				0.5,
				"px_dark_oak_planks",
				nil,
				f
			)
		end
		lb(cf, "RackRail", -4.5, 5.4, -0.5, 4.5, 6.2, 0.5, "px_dark_oak_planks", nil, f)
		lb(cf, "RackRail", -4.5, 1, -0.5, 4.5, 1.8, 0.5, "px_dark_oak_planks", nil, f)
		for _, x in ipairs({ -2.4, -0.8, 0.8, 2.4 }) do
			sword(cf * CFrame.new(x, 0.3, -0.8), f, 4.2)
		end
	end
	rack(fr(121.5, 153, 1, 0))
	box("BarracksTable", 140, 0.1, 152, 148, 3, 156, "px_spruce_planks", nil, f)
	for _, x in ipairs({ 137, 151 }) do
		box("Stool", x - 1, 0.1, 153, x + 1, 2, 155, "px_spruce_planks", nil, f)
	end
	crate(130, 0, 152, f)
	barrel(166, 0, 151, f)
	lantern(V(132, 14, 158), f, false, BY + H)
	lantern(V(156, 14, 158), f, false, BY + H)

	-- the training yard north of the barracks: dummies, archery targets, a rack, a fence with a gap
	local function dummy(x, z)
		local cf = fr(x, z, 0, -1)
		lb(cf, "DummyBase", -1.5, 0, -1.5, 1.5, 1, 1.5, "px_spruce_planks", nil, f)
		lb(cf, "DummyPost", -0.5, 1, -0.5, 0.5, 5.5, 0.5, "px_dark_oak_planks", nil, f)
		lb(cf, "DummyBody", -1.6, 5, -1, 1.6, 9, 1, "px_hay", nil, f)
		decor(lb(cf, "DummyArms", -3.8, 7.4, -0.5, 3.8, 8.4, 0.5, "px_spruce_planks", nil, f))
		lb(cf, "DummyHead", -1.2, 9, -1.2, 1.2, 11.4, 1.2, "px_brown_wool", nil, f)
		decor(lb(cf, "DummyHelm", -1.4, 11, -1.4, 1.4, 12, 1.4, "px_iron_block", nil, f))
	end
	local function target(x, z)
		local cf = fr(x, z, 0, 1)
		for _, s in ipairs({ -1, 1 }) do
			lb(
				cf,
				"TargetLeg",
				s * 2.5 - 0.5,
				0,
				0.2,
				s * 2.5 + 0.5,
				6,
				1.2,
				"px_spruce_planks",
				nil,
				f
			)
		end
		lb(cf, "Target", -3, 3, -0.6, 3, 9, 0.6, "px_hay", nil, f)
		for i, r in ipairs({ { 5, nil }, { 3.6, WOOL_RED }, { 2.2, nil }, { 1, WOOL_RED } }) do
			decor(
				lb(
					cf,
					"TargetRing",
					-r[1] / 2,
					6 - r[1] / 2,
					-0.6 - 0.1 * i,
					r[1] / 2,
					6 + r[1] / 2,
					-0.6 - 0.1 * (i - 1),
					"px_white_wool",
					r[2],
					f
				)
			)
		end
		for _, a in ipairs({ { 0.8, 6.5 }, { -1.4, 5.2 } }) do
			lc(
				cf,
				"Arrow",
				0.25,
				0.25,
				2.4,
				a[1],
				a[2],
				-1.6,
				Color3.fromRGB(90, 70, 50),
				Enum.Material.Wood,
				f
			)
		end
	end
	for _, x in ipairs({ 124, 134, 144 }) do
		dummy(x, 128)
	end
	target(158, 121)
	target(167, 121)
	box("HayBale", 155, 0, 135, 159, 4, 139, "px_hay", nil, f)
	box("HayBale", 164, 0, 135, 168, 4, 139, "px_hay", nil, f)
	rack(fr(170, 130, -1, 0))
	fence(116, 118, 136, 118, f)
	fence(152, 118, 172, 118, f)
	bench(128, 138, 0, -1, f)
	raven(fr(134, 128, 1, 0, 12), f)
	raven(fr(116, 118, 0, -1, 3.4), f)
	zoneSign(112, 138, "Конюшни · Казармы", math.pi / 2, f)
end
task.wait()

-- ================================================================ 4. the knights' hall (HALL)
do
	local f = folder("KnightsHall", court)
	local X0, X1, Z0, Z1 = -172, -140, -92, -28 -- the hall body (outer); the colonnade east of it to x -122
	local H = 20
	local UP, UPT, LOW, LOWT = "px_white_stone_bricks", QUARTZ, "px_stone_bricks", DEEP
	box("HallFloor", X0 + 4, -0.2, Z0 + 4, X1 - 4, 0.1, Z1 - 4, "px_stone_bricks", DEEP, f)
	decor(box("HallCarpet", X0 + 5, 0.1, -62, X1 - 4, 0.3, -58, "px_white_wool", WOOL_RED, f))
	box("Portico", X1, -0.2, Z0, -122, 0.1, Z1, "px_smooth_stone", QUARTZ_SHADE, f)
	wallRun("HallWall", "x", Z0, Z0 + 4, X0, X1, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun("HallWall", "x", Z1 - 4, Z1, X0, X1, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun("HallWall", "z", X0, X0 + 4, Z0 + 4, Z1 - 4, H, nil, f, UP, UPT, LOW, LOWT)
	wallRun(
		"HallWall",
		"z",
		X1 - 4,
		X1,
		Z0 + 4,
		Z1 - 4,
		H,
		{ { -74, -70, 8 }, { -64, -56, 12 }, { -50, -46, 8 } },
		f,
		UP,
		UPT,
		LOW,
		LOWT
	)
	for _, z in ipairs({ -81, -69, -51, -39 }) do
		glassWin("z", X0, X0 + 4, z, 5, 15, f)
	end
	stepRoof("HallRoof", "z", X0 - 2, X1, Z0 - 2, Z1 + 2, H, 4, f)
	-- the open colonnade: six quartz columns with banners, an entablature with merlons, hanging lanterns
	for _, z in ipairs({ -90, -78, -66, -54, -42, -30 }) do
		box("ColumnBase", -128, 0, z - 2, -124, 4, z + 2, LOW, LOWT, f)
		box("Column", -128, 4, z - 2, -124, 16, z + 2, "px_smooth_stone", QUARTZ, f)
		box("ColumnCapital", -128, 16, z - 2, -124, 20, z + 2, UP, QUARTZ_SHADE, f)
		wingBanner(at(-123.7, 10.5, z) * CFrame.Angles(0, math.pi / 2, 0), 3.2, 9, f)
	end
	box("Entablature", X1, H, Z0 - 2, -122, H + 4, Z1 + 2, UP, UPT, f)
	for k = 0, 8 do
		local z = Z0 - 2 + k * 8
		box("Merlon", -126, H + 4, z, -122, H + 8, z + 4, UP, UPT, f)
	end
	for _, z in ipairs({ -84, -72, -60, -48, -36 }) do
		lantern(V(-132, 15, z), f, false, BY + H)
	end
	local plaque = textured(
		part("HallPlaque", Vector3.new(0.4, 2, 10), at(-139.8, 14, -60), nil, nil, f),
		"px_dark_oak_planks"
	)
	boardText(plaque, "Зал рыцарей", nil, { Enum.NormalId.Right })
	raven(fr(-124, -60, 1, 0, H + 8), f)
	raven(fr(-157, -40, 1, 0, 36), f)
	-- the round table (a ring of dark oak blocks), a black stone with a sword in the middle, chairs
	local tx, tz = -156, -60
	for i = -2, 2 do
		for j = -2, 2 do
			local d = math.sqrt(i * i + j * j)
			if d >= 1.5 and d <= 2.6 then
				box(
					"RoundTable",
					tx + i * 3 - 1.5,
					0.3,
					tz + j * 3 - 1.5,
					tx + i * 3 + 1.5,
					3.4,
					tz + j * 3 + 1.5,
					"px_dark_oak_planks",
					nil,
					f
				)
			end
		end
	end
	box(
		"TableStone",
		tx - 1.5,
		0.3,
		tz - 1.5,
		tx + 1.5,
		2.8,
		tz + 1.5,
		"px_blackstone_bricks",
		nil,
		f
	)
	sword(at(tx, 1.6, tz) * CFrame.Angles(0, 0.5, 0), f, 4, Color3.fromRGB(150, 154, 164))
	for k = 0, 11 do
		local a = math.rad(k * 30 + 15)
		local cx, cz = tx + math.cos(a) * 9.4, tz + math.sin(a) * 9.4
		local cf = fr(cx, cz, -math.cos(a), -math.sin(a))
		lb(cf, "Chair", -1.2, 0.3, -1.2, 1.2, 2.3, 1.2, "px_spruce_planks", nil, f)
		lb(cf, "ChairBack", -1.2, 2.3, 1.2, 1.2, 5.9, 1.8, "px_spruce_planks", nil, f)
	end
	-- armour stands along the walls
	local function armour(cf, tint)
		local A = "px_iron_block"
		lb(cf, "StandBase", -1.5, 0.1, -1.5, 1.5, 0.8, 1.5, "px_smooth_stone", QUARTZ_SHADE, f)
		lb(cf, "StandLeg", -1.4, 0.8, -0.6, -0.2, 5, 0.6, A, tint, f)
		lb(cf, "StandLeg", 0.2, 0.8, -0.6, 1.4, 5, 0.6, A, tint, f)
		lb(cf, "StandChest", -1.8, 5, -1, 1.8, 9, 1, A, tint, f)
		decor(lb(cf, "StandShoulders", -2.6, 8, -1.1, 2.6, 9.2, 1.1, A, tint, f))
		lb(cf, "StandHelm", -1.2, 9.2, -1.2, 1.2, 11.6, 1.2, A, tint, f)
		lc(cf, "StandVisor", 1.8, 0.4, 0.15, 0, 10.6, -1.25, SOOT, Enum.Material.SmoothPlastic, f)
	end
	for _, z in ipairs({ -86, -75, -45, -34 }) do
		armour(fr(-165.5, z, 1, 0), if z == -75 then Color3.fromRGB(90, 90, 100) else nil)
	end
	armour(fr(-146.5, -84, -1, 0), nil)
	armour(fr(-146.5, -36, -1, 0), nil)
	wingBanner(at(X0 + 4.3, 11, -60) * CFrame.Angles(0, math.pi / 2, 0), 8, 14, f)
	wingBanner(at(-156, 11, Z0 + 4.3), 6, 12, f)
	wingBanner(at(-156, 11, Z1 - 4.3), 6, 12, f)
	lantern(V(-156, 14, -76), f, false, BY + H)
	lantern(V(-156, 14, -44), f, false, BY + H)
end
task.wait()

-- ================================================================ 5. the cursed knight's graveyard (GRAVES)
do
	local f = folder("Graveyard", court)
	-- the iron fence x -170..-104, z -172..-112 with stone pillars; gates in the east (to the court) and the south
	local function ironFence(ax, az, bx, bz)
		local len = math.max(math.abs(bx - ax), math.abs(bz - az))
		local n = math.max(1, math.floor(len / B + 0.5))
		for i = 1, n - 1 do
			local t = i / n
			decor(
				part(
					"FenceBar",
					Vector3.new(0.5, 6, 0.5),
					at(ax + (bx - ax) * t, 3, az + (bz - az) * t),
					IRON,
					Enum.Material.Metal,
					f
				)
			).CanCollide =
				true
		end
		for _, h in ipairs({ 1, 5.2 }) do
			local a, b = V(ax, h, az), V(bx, h, bz)
			beam("FenceRail", a, b, 0.4, IRON, f, Enum.Material.Metal)
		end
	end
	ironFence(-170, -172, -104, -172)
	ironFence(-170, -172, -170, -112)
	ironFence(-170, -112, -136, -112)
	ironFence(-124, -112, -104, -112)
	ironFence(-104, -172, -104, -162)
	ironFence(-104, -150, -104, -112)
	for _, p in ipairs({
		{ -170, -172 },
		{ -104, -172 },
		{ -170, -112 },
		{ -104, -112 },
		{ -104, -162 },
		{ -104, -150 },
		{ -136, -112 },
		{ -124, -112 },
	}) do
		box(
			"FencePillar",
			p[1] - 2,
			0,
			p[2] - 2,
			p[1] + 2,
			7,
			p[2] + 2,
			"px_blackstone_bricks",
			nil,
			f
		)
		box(
			"FencePillarCap",
			p[1] - 2.5,
			7,
			p[2] - 2.5,
			p[1] + 2.5,
			8,
			p[2] + 2.5,
			"px_stone_bricks",
			DEEP,
			f
		)
	end
	lantern(V(-104, 8.75, -162), f, true)
	lantern(V(-104, 8.75, -150), f, true)
	raven(fr(-104, -172, 1, 0, 8), f)
	raven(fr(-170, -112, 0, 1, 8), f)
	zoneSign(-98, -144, "Кладбище", math.pi / 2, f)
	-- the mausoleum of the cursed knight: dark stone on a plinth, obsidian pilasters, a sealed door, a stepped roof
	box("TombPlinth", -168, 0, -168, -140, 4, -144, "px_stone_bricks", DEEP, f)
	box("TombStep", -140, 0, -160, -136, 2, -152, "px_stone_bricks", DEEP, f)
	box("Tomb", -164, 4, -164, -144, 20, -148, "px_blackstone_bricks", nil, f)
	for _, c in ipairs({ { -165, -165 }, { -147, -165 }, { -165, -151 }, { -147, -151 } }) do
		box("TombPilaster", c[1], 4, c[2], c[1] + 4, 22, c[2] + 4, "px_obsidian", nil, f)
	end
	glassWin(
		"z",
		-144.1,
		-143.7,
		-156,
		4,
		14,
		f,
		6,
		Color3.fromRGB(14, 14, 18),
		Enum.Material.SmoothPlastic
	)
	local plaque = textured(
		part("TombPlaque", Vector3.new(0.3, 2, 8), at(-143.75, 18.5, -156), nil, nil, f),
		"px_smooth_stone",
		QUARTZ_SHADE
	)
	boardText(
		plaque,
		"Проклятый рыцарь",
		Color3.fromRGB(230, 230, 236),
		{ Enum.NormalId.Right }
	)
	box("TombRoof", -166, 20, -166, -142, 24, -146, "px_blackstone_bricks", nil, f)
	box("TombRoof", -162, 24, -162, -146, 28, -150, "px_blackstone_bricks", nil, f)
	box("TombRoof", -158, 28, -158, -150, 32, -154, "px_blackstone_bricks", nil, f)
	box("TombSpire", -156, 32, -158, -152, 40, -154, "px_obsidian", nil, f)
	box("TombFlagPole", -154.5, 40, -156.5, -153.5, 50, -155.5, "px_dark_oak_planks", nil, f)
	lc(
		at(-154, 47, -159.2),
		"TombFlag",
		0.2,
		5,
		5.4,
		0,
		0,
		0,
		BANNER_BLACK,
		Enum.Material.Fabric,
		f
	)
	lc(
		at(-154, 47.3, -159.2),
		"TombFlagWing",
		0.3,
		2,
		2.4,
		0,
		0,
		0,
		WING_WHITE,
		Enum.Material.Fabric,
		f
	)
	wingBanner(at(-142.7, 13, -163) * CFrame.Angles(0, math.pi / 2, 0), 3.4, 9, f)
	wingBanner(at(-142.7, 13, -149) * CFrame.Angles(0, math.pi / 2, 0), 3.4, 9, f)
	raven(fr(-148, -152, 1, 0, 28), f)
	for _, c in ipairs({
		{ -138, 2, -159, true },
		{ -138, 2, -153, false },
		{ -141, 4, -166, false },
		{ -141, 4, -146, false },
	}) do
		candle(c[1], c[2], c[3], f, c[4])
	end
	-- the cursed sword in the stone on the aisle before the tomb
	box("SwordStone", -128, 0, -162, -120, 4, -154, "px_mossy_cobblestone", nil, f)
	box("SwordStone", -126, 4, -160, -122, 8, -156, "px_cobblestone", nil, f)
	sword(at(-124, 6, -158) * CFrame.Angles(0.12, 0.4, 0.08), f, 6, Color3.fromRGB(70, 72, 82))
	for i, c in ipairs({ { -129.5, -163 }, { -118.5, -163 }, { -129.5, -153 }, { -118.5, -153 } }) do
		candle(c[1], 0, c[2], f, i == 4)
	end
	-- graves in rows south of the aisle (a free path from the south gate along x -136..-124)
	local function grave(x, z)
		local cf = at(x, 0, z) * CFrame.Angles(0, rng:NextNumber(-0.12, 0.12), 0)
		if rng:NextNumber() < 0.3 then
			cf *= CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.08, 0.08))
		end
		lb(cf, "GraveBase", -2, 0, -1, 2, 1, 1, "px_stone_bricks", DEEP, f)
		if rng:NextNumber() < 0.55 then
			lb(
				cf,
				"Gravestone",
				-1.6,
				1,
				-0.6,
				1.6,
				6,
				0.6,
				pick({ "px_stone_bricks", "px_mossy_stone_bricks", "px_smooth_stone" }),
				QUARTZ_SHADE,
				f
			)
			lc(cf, "GraveCross", 0.6, 2.6, 0.1, 0, 4, 0.65, SOOT, Enum.Material.SmoothPlastic, f)
			lc(cf, "GraveCross", 1.8, 0.6, 0.1, 0, 4.5, 0.65, SOOT, Enum.Material.SmoothPlastic, f)
		else
			lb(
				cf,
				"GraveCross",
				-0.6,
				1,
				-0.6,
				0.6,
				8,
				0.6,
				pick({ "px_stone_bricks", "px_mossy_stone_bricks" }),
				QUARTZ_SHADE,
				f
			)
			lb(cf, "GraveCross", -2, 5.2, -0.6, 2, 6.4, 0.6, "px_stone_bricks", QUARTZ_SHADE, f)
		end
		box(
			"GraveMound",
			x - 1.8,
			-0.2,
			z + 1.2,
			x + 1.8,
			0.6,
			z + 7,
			"px_dirt",
			Color3.fromRGB(130, 112, 96),
			f
		)
		if rng:NextNumber() < 0.35 then
			candle(x + 1.3, 1, z + 0.6, f, false)
		end
	end
	for _, g in ipairs({ { -120, -147 }, { -110, -147 } }) do
		grave(g[1], g[2])
	end
	for _, z in ipairs({ -135, -123 }) do
		for _, x in ipairs({ -162, -151, -141, -119, -110 }) do
			grave(x, z)
		end
	end
	-- dead trees with nests, ravens in cages (one hanging from a branch)
	local tips = deadTree(-112, -166, 18, f)
	nest(tips[1][1], tips[1][2], tips[1][3], f, true)
	tips = deadTree(-133, -167, 16, f)
	nest(tips[3][1], tips[3][2], tips[3][3], f, false)
	tips = deadTree(-166, -141, 20, f)
	nest(tips[1][1], tips[1][2], tips[1][3], f, true)
	-- the +X branch of the last tree: a cage hangs under it on a chain
	local hb = tips[2]
	cage(at(hb[1] + 1, hb[4] - 7.5, hb[3]), f, true)
	lc(
		at(hb[1] + 1, hb[4] - 0.5, hb[3]),
		"CageChain",
		0.3,
		1,
		0.3,
		0,
		0,
		0,
		IRON,
		Enum.Material.Metal,
		f
	)
	box("CagePlinth", -120, 0, -169, -116, 4, -165, "px_stone_bricks", DEEP, f)
	cage(at(-118, 4, -167), f, true)
	box("CagePlinth", -140, 0, -149, -136, 4, -145, "px_stone_bricks", DEEP, f)
	cage(at(-138, 4, -147), f, true)
	for _ = 1, 22 do
		feather(-166 + rng:NextNumber() * 60, -170 + rng:NextNumber() * 56, 0, f)
	end
	flock(-138, -142, 6, 8, 22, 34, 48, f)
	-- a sparse ground fog over the graves (the only emitter of this part)
	local fogPart = part("GraveFog", Vector3.new(60, 1, 54), at(-137, 1.5, -142), nil, nil, f)
	fogPart.Transparency = 1
	decor(fogPart)
	fogPart.CastShadow = false
	emitter(fogPart, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 152, 162)),
		Size = NumberSequence.new(8, 16),
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.82),
			NumberSequenceKeypoint.new(1, 1),
		}),
		Lifetime = NumberRange.new(10, 14),
		Rate = 2.5,
		Speed = NumberRange.new(0.3, 0.9),
		SpreadAngle = Vector2.new(180, 8),
		RotSpeed = NumberRange.new(-6, 6),
		LightInfluence = 0.6,
	})
end
task.wait()

-- ================================================================ 6. gardens, lamps, the well, the hedge alley
do
	local g = folder("Gardens", court)
	-- lamp posts along both sides of the avenue every 24 studs, lanterns over the road (the west side stops before
	-- the way to the arrival)
	for z = 20, 164, 24 do
		lampPost(AVENUE[3] + 3, z, g, false, math.pi / 2)
		if z < 148 then
			lampPost(AVENUE[1] - 3, z, g, false, -math.pi / 2)
		end
		if z == 68 or z == 140 then
			raven(fr(AVENUE[3] + 3, z, -1, 0, 10), g)
		end
	end
	-- the hedge alley from the south opening to the stables yard (gaps every 28 studs), lamps inside it
	for _, s in ipairs({ { 16, 36 }, { 44, 64 }, { 72, 92 }, { 100, 108 } }) do
		box("AlleyHedge", 36, 0, s[1], 40, 4, s[2], "px_hedge", LEAF_DARK, g)
		box("AlleyHedge", 72, 0, s[1], 76, 4, s[2], "px_hedge", LEAF_DARK, g)
	end
	lampPost(42, 28, g, false, -math.pi / 2)
	lampPost(70, 52, g, false, math.pi / 2)
	lampPost(42, 80, g, false, -math.pi / 2)
	lampPost(70, 102, g, false, math.pi / 2)
	-- the well (-60, -72): a stone ring with water, two posts, a little slate roof and a bucket
	do
		local wx, wz = -60, -72
		reserve(wx, wz, 12)
		box("Well", wx - 6, 0, wz - 6, wx + 6, 4, wz - 2, "px_cobblestone", nil, g)
		box("Well", wx - 6, 0, wz + 2, wx + 6, 4, wz + 6, "px_cobblestone", nil, g)
		box("Well", wx - 6, 0, wz - 2, wx - 2, 4, wz + 2, "px_cobblestone", nil, g)
		box("Well", wx + 2, 0, wz - 2, wx + 6, 4, wz + 2, "px_cobblestone", nil, g)
		lc(
			at(wx, 2.6, wz),
			"WellWater",
			4,
			0.2,
			4,
			0,
			0,
			0,
			Color3.fromRGB(50, 70, 96),
			Enum.Material.Glass,
			g
		)
		for _, s in ipairs({ -1, 1 }) do
			box(
				"WellPost",
				wx + s * 5 - 0.5,
				4,
				wz - 0.5,
				wx + s * 5 + 0.5,
				11,
				wz + 0.5,
				"px_dark_oak_planks",
				nil,
				g
			)
		end
		decor(
			box(
				"WellBeam",
				wx - 5.5,
				10,
				wz - 0.4,
				wx + 5.5,
				10.8,
				wz + 0.4,
				"px_dark_oak_log",
				nil,
				g
			)
		)
		box("WellRoof", wx - 7, 11, wz - 4, wx + 7, 12, wz + 4, ROOF_V, ROOF_T, g)
		box("WellRoof", wx - 7, 12, wz - 2, wx + 7, 13, wz + 2, ROOF_V, ROOF_T, g)
		lc(
			at(wx, 8, wz),
			"WellRope",
			0.25,
			2.4,
			0.25,
			0,
			0,
			0,
			Color3.fromRGB(120, 100, 70),
			Enum.Material.Fabric,
			g
		)
		decor(cube("WellBucket", wx, 6.1, wz, 1.6, 1.6, 1.6, "px_spruce_planks", nil, g))
		raven(fr(wx, wz, 0, 1, 13), g)
		bench(wx, wz + 12, 0, 1, g)
	end
	-- a raven cage and a fallen nest in the east bailey (the props of the concept sheet)
	do
		local cx, cz = 136, -70
		reserve(cx, cz, 12)
		box("CagePlinth", cx - 2, 0, cz - 2, cx + 2, 4, cz + 2, "px_stone_bricks", DEEP, g)
		cage(at(cx, 4, cz), g, true)
		nest(cx + 7, 0, cz + 2, g, true)
		lampPost(cx - 6, cz + 6, g, false, math.pi / 4)
		for _ = 1, 6 do
			feather(cx - 8 + rng:NextNumber() * 18, cz - 6 + rng:NextNumber() * 14, 0, g)
		end
	end
	local function free(x, z, pad)
		return freeBailey(x, z, pad)
			and math.abs(x) <= 156
			and math.abs(z) <= 156
			and not onLane(x, z, pad)
			and not isReserved(x, z, pad)
			and not (math.abs(x) < 44 and z > 150)
	end
	-- formal garden patches packed greedily on free ground: a hedge square with a gap in each side, a dark tree in the
	-- middle, flower beds in the corners, a bench looking out of the south gap
	local patches = 0
	for cz = -152, 152, 8 do
		for cx = -152, 152, 8 do
			if free(cx, cz, 12) then
				patches += 1
				reserve(cx, cz, 16)
				local p = folder("GardenPatch", g)
				for _, s in ipairs({ -1, 1 }) do
					box(
						"Hedge",
						cx - 12,
						0,
						cz + s * 10 - 2,
						cx - 2,
						4,
						cz + s * 10 + 2,
						"px_hedge",
						LEAF_DARK,
						p
					)
					box(
						"Hedge",
						cx + 2,
						0,
						cz + s * 10 - 2,
						cx + 12,
						4,
						cz + s * 10 + 2,
						"px_hedge",
						LEAF_DARK,
						p
					)
					box(
						"Hedge",
						cx + s * 10 - 2,
						0,
						cz - 8,
						cx + s * 10 + 2,
						4,
						cz - 2,
						"px_hedge",
						LEAF_DARK,
						p
					)
					box(
						"Hedge",
						cx + s * 10 - 2,
						0,
						cz + 2,
						cx + s * 10 + 2,
						4,
						cz + 8,
						"px_hedge",
						LEAF_DARK,
						p
					)
				end
				darkTree(cx, cz, rng:NextInteger(3, 4) * B, p)
				for i, c in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
					local bx, bz = cx + c[1] * 6, cz + c[2] * 6
					box("FlowerBed", bx - 2, -0.2, bz - 2, bx + 2, 0.6, bz + 2, "px_dirt", nil, p)
					decor(
						cube(
							"Flowers",
							bx,
							1.4,
							bz,
							2.2,
							1.6,
							2.2,
							"px_white_wool",
							if i % 2 == 0 then WOOL_RED else nil,
							p
						)
					)
				end
				bench(cx, cz + 6, 0, 1, p)
				if rng:NextNumber() < 0.3 then
					raven(fr(cx - 6, cz - 10, 1, 0, 4), p)
				end
			end
		end
	end
	task.wait()
	-- loose dark trees and bushes on the rest of the free ground
	local trees, bushes = 0, 0
	for gx = -152, 152, 16 do
		for gz = -152, 152, 16 do
			local x, z = gx + rng:NextInteger(-1, 1) * 2, gz + rng:NextInteger(-1, 1) * 2
			if free(x, z, 6) then
				local n = n2(x, z, 8.1, 0.03)
				if n > -0.3 and rng:NextNumber() < 0.75 then
					trees += 1
					reserve(x, z, 7)
					darkTree(x, z, rng:NextInteger(3, 4) * B, g)
				elseif rng:NextNumber() < 0.35 then
					bushes += 1
					box("Bush", x - 2, 0, z - 2, x + 2, 4, z + 2, "px_hedge", LEAF_DARK, g)
					if rng:NextNumber() < 0.5 then
						box("Bush", x + 2, 0, z - 2, x + 6, 4, z + 2, "px_hedge", LEAF_DARK, g)
					end
				end
			end
		end
	end
	print(
		("[build-castle] court: %d garden patches, %d trees, %d bushes"):format(
			patches,
			trees,
			bushes
		)
	)
end
print(("[build-castle] court & districts: %d parts"):format(count - startCount))
