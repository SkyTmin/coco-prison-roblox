--!nocheck
-- ================================================================ barn: the yard (z < -80): the boss arena, the guardian's tree, the north
-- The arena ARENA (0, -140) r 52: the overgrown barnyard laid flush on the core ground (y -0.2 .. 0.1): a worn wagon
-- track with two ruts from the south opening to the tree, patches of old cobble / stone paving, podzol, coarse dirt
-- and gravel; four old striped silos on the diagonals (r 34) as the stun pillars (every solid part tagged Pillar):
-- octagonal shafts 4 blocks across of grey stone bricks with red-brown bands, vines, ragged tops 8–14 blocks high, the
-- SE one with a collapsed dome; four root mounds (creature spawns, decor only, attribute CreatureSpawn) — nothing
-- else solid inside r 44. A crooked broken fence ring r 56 with three openings 6 blocks wide: S (to the barn's north
-- doors), SE and SW (to the round-the-barn paths ending at (±84, -84)), gallows lamp posts with chains and lanterns
-- beside each; jack o'lanterns, candles on hay, stumps with chains, a scarecrow with a burning pumpkin head and a
-- raven on a post round the rim. The guardian's gnarled dead tree behind the north rim (GUARDIAN (0, -204), moved
-- south while its back is too near the edge): a 4×4-block leaning, twisted trunk with a glowing angry face, stepped
-- roots (decor where they reach into the arena), crooked bare branches, a sparse broken orange crown and hanging
-- lanterns. The north: two more broken silos (decor), autumn and dead trees, junk heaps, an abandoned cart, a small
-- graveyard, broken fence lines, tall weeds and three sparse fog emitters.
local yard = folder("Yard")
local count0 = count
local AX, AZ = ARENA.x, ARENA.z
local FENCE_R = 56
local OPEN = { 90, 34, 146 } -- S, SE, SW: degrees of atan2(dz, dx) from the arena centre (0 east, 90 south)
local OPEN_HALF = 12 -- half the clear width of an opening (6 blocks)
local SILOS = { -- the four stun pillars on the diagonals, r ≈ 34
	{ x = 24, z = -116, h = 40, bands = { 12, 28 }, dome = true },
	{ x = -24, z = -116, h = 56, bands = { 8, 24, 44 } },
	{ x = 24, z = -164, h = 48, bands = { 12, 24, 36 } },
	{ x = -24, z = -164, h = 32, bands = { 8, 20 } },
}
local MOUNDS = { { 28, -140 }, { -28, -140 }, { 8, -174 }, { -8, -112 } } -- root mounds (creature spawns)
local ROUTES = { -- dirt paths into the openings: { w, pts }
	{ w = 20, pts = { { 0, -80 }, { 0, -96 } } },
	{ w = 18, pts = { { 84, -80 }, { 84, -86 }, { 66, -96 }, { 40, -114 } } },
	{ w = 18, pts = { { -84, -80 }, { -84, -86 }, { -66, -96 }, { -40, -114 } } },
}
local COARSE = Color3.fromRGB(128, 96, 70)
local BARK = Color3.fromRGB(150, 140, 132)
local FACE_GLOW = Color3.fromRGB(255, 150, 40)
local METAL = Color3.fromRGB(52, 52, 58)
local lightsUsed = 0
local OCC = {} -- placed solid things { x, z, r }

-- a PointLight within the yard's budget (20)
local function glow(p, range, brightness, color)
	if lightsUsed >= 20 then
		return nil
	end
	lightsUsed += 1
	return light(p, range, brightness, color)
end
-- a box relative to a CFrame (studs)
local function lp(cf, name, sx, sy, sz, x, y, z, variant, tint, parent)
	local p = part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- local coordinates of a point given relative to a CFrame
local function loc(cf, x, y, z)
	local p = (cf * CFrame.new(x, y, z)).Position
	return p.X - BX, p.Y - BY, p.Z - BZ
end
-- an iron chain of links from a to b (world points), decor
local function chain(a, b, parent)
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 0.9 + 0.5))
	local up = if math.abs(d.Unit.Y) > 0.95 then Vector3.xAxis else Vector3.yAxis
	for i = 1, n do
		local c = a:Lerp(b, (i - 0.5) / n)
		local cf = CFrame.lookAt(c, c + d, up) * CFrame.Angles(0, 0, if i % 2 == 0 then math.pi / 2 else 0)
		decor(part("Chain", Vector3.new(0.45, 0.16, len / n + 0.35), cf, METAL, Enum.Material.Metal, parent)).CastShadow = false
	end
end
-- a lantern (open iron frame, glowing core) centred at pos (world); its hook is 1.3 above pos
local function lamp(pos, parent)
	local cf = CFrame.new(pos)
	decor(part("LanternBase", Vector3.new(1.4, 0.3, 1.4), cf * CFrame.new(0, -0.75, 0), METAL, Enum.Material.Metal, parent))
	decor(part("LanternTop", Vector3.new(1.4, 0.3, 1.4), cf * CFrame.new(0, 0.75, 0), METAL, Enum.Material.Metal, parent))
	decor(part("LanternCap", Vector3.new(0.7, 0.4, 0.7), cf * CFrame.new(0, 1.1, 0), METAL, Enum.Material.Metal, parent))
	local core = decor(part("LanternGlow", Vector3.new(1, 1.2, 1), cf, LANTERN_GLOW, Enum.Material.Neon, parent))
	glow(core, 30, 1.2, LANTERN_GLOW)
	return core
end
-- flush tiles (y -0.2 .. 0.1) on the 4-stud cells of [x0, x1] × [z0, z1]: fn(cx, cz) -> variant, tint | nil; equal
-- neighbours along x are merged into one run
local function tiles(name, x0, x1, z0, z1, fn, parent)
	for z = z0, z1 - B, B do
		local runX, runKey, runV, runT = nil, nil, nil, nil
		local function flush(xEnd)
			if runX then
				box(name, runX, -0.2, z, xEnd, 0.1, z + B, runV, runT, parent)
			end
			runX = nil
		end
		for x = x0, x1 - B, B do
			local v, t = fn(x + B / 2, z + B / 2)
			local key = if v then v .. tostring(t) else nil
			if key ~= runKey then
				flush(x)
				if v then
					runX, runV, runT = x, v, t
				end
				runKey = key
			end
		end
		flush(x1)
	end
end
-- the yaw that turns a prop's local -Z toward (dx, dz)
local function yawToward(dx, dz)
	return math.atan2(-dx, -dz)
end
-- the distance of (dx, dz) from the arena centre to the nearest opening axis, on the outward side of it
local function openPerp(dx, dz)
	local best = math.huge
	for _, deg in ipairs(OPEN) do
		local a = math.rad(deg)
		if dx * math.cos(a) + dz * math.sin(a) > 0 then
			best = math.min(best, math.abs(-dx * math.sin(a) + dz * math.cos(a)))
		end
	end
	return best
end
-- the distance from (x, z) to the nearest path edge (negative: on a path)
local function routeDist(x, z)
	local best = math.huge
	for _, r in ipairs(ROUTES) do
		for i = 1, #r.pts - 1 do
			local a, b = r.pts[i], r.pts[i + 1]
			best = math.min(best, segDist(x, z, a[1], a[2], b[1], b[2]) - r.w / 2)
		end
	end
	return best
end
local function taken(x, z, r)
	for _, o in ipairs(OCC) do
		if (x - o[1]) ^ 2 + (z - o[2]) ^ 2 < (r + o[3]) ^ 2 then
			return true
		end
	end
	return false
end
local function claim(x, z, r)
	table.insert(OCC, { x, z, r })
end
-- a jack o'lantern block standing on cf (its carved face toward cf's -Z); s = size
local function jack(cf, parent, lit, s)
	s = s or B
	local body = lp(cf, "JackOLantern", s, s * 0.9, s, 0, s * 0.45, 0, "px_hay", PUMPKIN, parent)
	local e = s / 4
	local fz = -s / 2 - 0.05
	for _, sx in ipairs({ -1, 1 }) do
		decor(lp(cf, "JackEye", e, e, 0.12, sx * e * 1.05, s * 0.6, fz, nil, FACE_GLOW, parent)).Material = Enum.Material.Neon
	end
	local mouth = decor(lp(cf, "JackMouth", s * 0.6, e * 0.7, 0.12, 0, s * 0.27, fz, nil, FACE_GLOW, parent))
	mouth.Material = Enum.Material.Neon
	decor(lp(cf, "JackTooth", e * 0.5, e * 0.35, 0.16, 0, s * 0.27 + e * 0.2, fz - 0.02, "px_hay", PUMPKIN, parent))
	decor(lp(cf, "JackStem", s * 0.2, s * 0.2, s * 0.2, 0, s * 0.9 + s * 0.1, 0, nil, Color3.fromRGB(96, 104, 52), parent))
	if lit then
		glow(mouth, 16, 1, FACE_GLOW)
	end
	return body
end
-- a plain pumpkin (no face) at local (x, z)
local function pumpkin(x, y, z, parent, s)
	s = s or 3.2
	cube("Pumpkin", x, y + s * 0.45, z, s, s * 0.9, s, "px_hay", PUMPKIN, parent)
	decor(cube("PumpkinStem", x, y + s * 0.9 + 0.3, z, 0.6, 0.6, 0.6, nil, Color3.fromRGB(96, 104, 52), parent))
end
-- 1–3 candles standing at local (x, y, z) (decor)
local function candles(x, y, z, parent)
	for _ = 1, rng:NextInteger(1, 3) do
		local ox, oz = rng:NextNumber(-1.2, 1.2), rng:NextNumber(-1.2, 1.2)
		local h = rng:NextNumber(0.8, 1.6)
		decor(part("Candle", Vector3.new(0.5, h, 0.5), at(x + ox, y + h / 2, z + oz), Color3.fromRGB(236, 226, 200), Enum.Material.SmoothPlastic, parent))
		decor(part("CandleFlame", Vector3.new(0.25, 0.4, 0.25), at(x + ox, y + h + 0.22, z + oz), CANDLE, Enum.Material.Neon, parent))
	end
end
local function hayBale(x, y, z, parent, yaw)
	return textured(part("HayBale", Vector3.new(B, B, B), at(x, y + B / 2, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, parent), "px_hay")
end
-- a block raven perched on cf (looking toward cf's -Z), decor
local function raven(cf, parent)
	local c = Color3.fromRGB(40, 40, 48)
	local body = decor(lp(cf, "Raven", 1.3, 1.3, 2.2, 0, 1.05, 0.1, "px_white_wool", c, parent))
	decor(lp(cf, "RavenHead", 1, 1, 1, 0, 2.05, -1.1, "px_white_wool", c, parent))
	decor(lp(cf, "RavenBeak", 0.35, 0.35, 0.8, 0, 1.95, -1.95, nil, Color3.fromRGB(64, 64, 70), parent))
	decor(lp(cf, "RavenTail", 0.9, 0.3, 1.4, 0, 0.75, 1.75, nil, c, parent))
	for _, s in ipairs({ -1, 1 }) do
		decor(lp(cf, "RavenWing", 0.2, 0.9, 1.6, s * 0.75, 1.15, 0.2, nil, Color3.fromRGB(30, 30, 36), parent))
	end
	decor(lp(cf, "RavenEyes", 1.04, 0.2, 0.2, 0, 2.2, -1.35, nil, Color3.fromRGB(255, 120, 40), parent)).Material = Enum.Material.Neon
	decor(lp(cf, "RavenLegs", 0.7, 0.4, 0.3, 0, 0.2, 0.1, nil, Color3.fromRGB(40, 40, 44), parent))
	return body
end
-- a tuft of tall dry weeds (two crossed plates, decor) at local (x, z)
local function weed(x, z, parent, y0)
	local h = rng:NextNumber(2.5, 5)
	local tint = pick({ Color3.fromRGB(190, 165, 90), Color3.fromRGB(160, 150, 80), Color3.fromRGB(200, 140, 70), Color3.fromRGB(140, 140, 80) })
	local yaw = rng:NextNumber(0, math.pi)
	for k = 0, 1 do
		local p = part("Weeds", Vector3.new(2.6, h, 0.15), at(x, (y0 or 0) + h / 2, z) * CFrame.Angles(0, yaw + k * math.pi / 2, 0), nil, nil, parent)
		textured(decor(p), "px_hedge", tint).CastShadow = false
	end
end
-- a square block cart wheel centred on cf, in cf's YZ plane (decor)
local function wheel(cf, parent)
	local w = Color3.fromRGB(130, 100, 72)
	for _, s in ipairs({ -1, 1 }) do
		decor(lp(cf, "WheelRim", 0.6, 1, 5.2, 0, s * 2.1, 0, "px_spruce_planks", w, parent))
		decor(lp(cf, "WheelRim", 0.6, 3.2, 1, 0, 0, s * 2.1, "px_spruce_planks", w, parent))
	end
	decor(lp(cf, "WheelSpoke", 0.4, 3.4, 0.5, 0, 0, 0, nil, OLD_WOOD, parent))
	decor(lp(cf, "WheelSpoke", 0.4, 0.5, 3.4, 0, 0, 0, nil, OLD_WOOD, parent))
	decor(lp(cf, "WheelHub", 0.9, 1.3, 1.3, 0, 0, 0, "px_iron_block", Color3.fromRGB(110, 100, 95), parent))
end
-- an old striped silo: an octagonal shaft (4 blocks across, corners cut) on a plinth, red-brown bands, vines, a ragged
-- broken top or a collapsed dome; s = { x, z, h, bands, dome }; tagIt = every solid part is a stun pillar
local function silo(s, tagIt, parent)
	local f = folder("Silo", parent)
	local cx, cz, H = s.x, s.z, s.h
	local STONE_T = Color3.fromRGB(178, 174, 168)
	local function solid(p)
		if tagIt then
			pillarTag(p)
		end
		return p
	end
	local function layer(name, y0, y1, variant, tint)
		solid(box(name, cx - 4, y0, cz - 8, cx + 4, y1, cz + 8, variant, tint, f))
		solid(box(name, cx - 8, y0, cz - 4, cx - 4, y1, cz + 4, variant, tint, f))
		solid(box(name, cx + 4, y0, cz - 4, cx + 8, y1, cz + 4, variant, tint, f))
	end
	-- the plinth: 5 blocks across, half a block high
	solid(box("SiloPlinth", cx - 6, 0, cz - 10, cx + 6, 2, cz + 10, "px_mossy_cobblestone", nil, f))
	solid(box("SiloPlinth", cx - 10, 0, cz - 6, cx - 6, 2, cz + 6, "px_mossy_cobblestone", nil, f))
	solid(box("SiloPlinth", cx + 6, 0, cz - 6, cx + 10, 2, cz + 6, "px_mossy_cobblestone", nil, f))
	local shaftTop = if s.dome then H else H - 2 * B
	local y = 2
	for i, b in ipairs(s.bands) do
		if b < shaftTop then
			if b > y then
				layer("SiloShaft", y, b, "px_stone_bricks", STONE_T)
			end
			local bt = math.min(b + B, shaftTop)
			if i % 2 == 1 then
				layer("SiloBand", b, bt, "px_terracotta", Color3.fromRGB(190, 104, 84))
			else
				layer("SiloBand", b, bt, "px_red_brick", Color3.fromRGB(200, 140, 125))
			end
			y = bt
		end
	end
	if y < shaftTop then
		layer("SiloShaft", y, shaftTop, "px_stone_bricks", STONE_T)
	end
	-- the hollow inside the broken top
	decor(box("SiloHollow", cx - 4, shaftTop, cz - 4, cx + 4, shaftTop + 0.1, cz + 4, "px_coal_block", Color3.fromRGB(70, 70, 70), f))
	-- the rim cells of the 4×4 grid (no corners, no inside)
	local rim = {}
	for i = 0, 3 do
		for j = 0, 3 do
			local corner = (i == 0 or i == 3) and (j == 0 or j == 3)
			local inner = i >= 1 and i <= 2 and j >= 1 and j <= 2
			if not corner and not inner then
				table.insert(rim, { cx - 6 + 4 * i, cz - 6 + 4 * j, i, j })
			end
		end
	end
	if s.dome then
		-- a rusty ring, then the dome caved in on one side, a sagging broken piece and fallen tiles at the foot
		for _, c in ipairs(rim) do
			solid(cube("SiloRing", c[1], H + 2, c[2], B, B, B, "px_terracotta", Color3.fromRGB(170, 96, 76), f))
		end
		for i = 0, 3 do
			for j = 0, 3 do
				local corner = (i == 0 or i == 3) and (j == 0 or j == 3)
				if not corner and i + j <= 3 then
					solid(cube("SiloDome", cx - 6 + 4 * i, H + 6, cz - 6 + 4 * j, B, B, B, "px_roof_tiles", RUST, f))
				end
			end
		end
		solid(cube("SiloDome", cx - 2, H + 10, cz - 2, B, B, B, "px_roof_tiles", RUST, f))
		solid(cube("SiloDome", cx + 2, H + 10, cz - 2, B, B, B, "px_roof_tiles", RUST, f))
		local sag = part("SiloDomeSag", Vector3.new(B, 0.8, 2 * B), at(cx + 3, H + 5, cz + 3) * CFrame.Angles(0.5, 0.8, 0.3), nil, nil, f)
		textured(decor(sag), "px_roof_tiles", RUST)
		local ox, oz = cx - AX, cz - AZ
		local m = math.sqrt(ox * ox + oz * oz)
		ox, oz = ox / m, oz / m
		for k = 1, 3 do
			local d = 11 + k * 2.5
			local p = part("FallenTile", Vector3.new(B, B, B), at(cx + ox * d + oz * (k - 2) * 3, 1.2, cz + oz * d - ox * (k - 2) * 3) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), nil, nil, f)
			textured(decor(p), "px_roof_tiles", RUST)
		end
	else
		for _, c in ipairs(rim) do
			local n = rng:NextInteger(0, 2)
			if n > 0 then
				local v = if rng:NextNumber() < 0.3 then "px_mossy_stone_bricks" else "px_stone_bricks"
				solid(cube("SiloRim", c[1], shaftTop + n * B / 2, c[2], B, n * B, B, v, if v == "px_stone_bricks" then STONE_T else nil, f))
			elseif rng:NextNumber() < 0.5 then
				-- a knocked-off block lying askew on the broken edge
				local p = part("SiloBroken", Vector3.new(B, B * 0.7, B), at(c[1], shaftTop + 1.2, c[2]) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 1), rng:NextNumber(-0.3, 0.3)), nil, nil, f)
				textured(decor(p), "px_stone_bricks", STONE_T)
			end
		end
	end
	-- a dark slit window high on the south face
	local wy = shaftTop - 12
	if wy >= 8 then
		decor(box("SiloWindow", cx - 1.5, wy, cz + 8, cx + 1.5, wy + 5, cz + 8.15, "px_coal_block", Color3.fromRGB(60, 60, 60), f))
	end
	-- vines climbing the four flat faces, leaf clumps along them
	local VINE_T = { Color3.fromRGB(120, 150, 70), Color3.fromRGB(150, 150, 60), Color3.fromRGB(196, 112, 52), Color3.fromRGB(100, 130, 60) }
	for _, face in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		for _ = 1, rng:NextInteger(1, 3) do
			local len = rng:NextInteger(3, math.max(4, shaftTop // B - 1)) * B
			local t = rng:NextInteger(-1, 1) * 2.5
			local vx = cx + face[1] * 8.15 + face[2] * t
			local vz = cz + face[2] * 8.15 + face[1] * t
			local flatX = face[1] ~= 0
			local tint = pick(VINE_T)
			local v = part("Vine", Vector3.new(if flatX then 0.25 else 1.4, len, if flatX then 1.4 else 0.25), at(vx, len / 2, vz), nil, nil, f)
			textured(decor(v), "px_hedge", tint).CastShadow = false
			for _ = 1, rng:NextInteger(1, 2) do
				local cy = rng:NextNumber(3, len)
				local cl = part("VineLeaves", Vector3.new(if flatX then 0.35 else 3, 3, if flatX then 3 else 0.35), at(vx + face[1] * 0.05, cy, vz + face[2] * 0.05), nil, nil, f)
				textured(decor(cl), "px_hedge", tint).CastShadow = false
			end
		end
	end
	return f
end

-- ================================================================ 1. the arena floor, the paths, the root mounds
do
	local f = folder("ArenaFloor", yard)
	local RUT = Color3.fromRGB(104, 80, 60)
	tiles("ArenaFloor", AX - 56, AX + 56, AZ - 56, AZ + 56, function(cx, cz)
		local dx, dz = cx - AX, cz - AZ
		local rr = math.sqrt(dx * dx + dz * dz)
		if rr >= 52 or not onIsland(cx, cz, 2) then
			return nil
		end
		for _, s in ipairs(SILOS) do
			if math.abs(cx - s.x) < 10 and math.abs(cz - s.z) < 10 then
				return nil
			end
		end
		for _, m in ipairs(MOUNDS) do
			local d = math.sqrt((cx - m[1]) ^ 2 + (cz - m[2]) ^ 2)
			if d < 8.5 then
				if d < 4.5 then
					return "px_forest_floor", Color3.fromRGB(150, 120, 96)
				end
				return "px_dirt", Color3.fromRGB(96, 70, 52)
			end
		end
		-- the worn wagon track from the south opening to the tree: two ruts and a stony middle
		local t = math.abs(dx - math.sin(cz * 0.045) * 6)
		if t >= 4 and t < 8 then
			if n2(cx, cz, 6.1, 0.3) > -0.3 then
				return "px_dirt", RUT
			end
		elseif t < 4 then
			local u = n2(cx, cz, 7.3, 0.2)
			if u > 0.12 then
				return "px_cobblestone", nil
			elseif u > -0.06 then
				return "px_gravel", nil
			end
			return "px_dirt", PATH_DIRT
		end
		local a = n2(cx, cz, 12.1, 0.06)
		if a > 0.36 then
			return "px_stone_bricks", Color3.fromRGB(170, 166, 160)
		elseif a > 0.26 then
			return (if n2(cx, cz, 2.3, 0.4) > 0.1 then "px_mossy_cobblestone" else "px_cobblestone"), nil
		end
		if a < -0.3 then
			return "px_gravel", Color3.fromRGB(176, 166, 156)
		end
		local b = n2(cx, cz, 15.7, 0.08)
		if b > 0.24 then
			return "px_dirt", PODZOL
		elseif b < -0.28 then
			return "px_dirt", COARSE
		end
		if rr > 46 and n2(cx, cz, 9.9, 0.15) > 0.05 then
			return "px_forest_floor", Color3.fromRGB(205, 150, 100) -- fallen leaves along the rim
		end
		return nil
	end, f)
	task.wait()
	-- the dirt paths into the three openings
	tiles("Path", -100, 100, -124, -84, function(cx, cz)
		if inArena(cx, cz, 0) or not onIsland(cx, cz, 2) then
			return nil
		end
		local d = routeDist(cx, cz)
		if d > 0 then
			return nil
		end
		if d > -2.5 and n2(cx, cz, 5.5, 0.2) > -0.05 then
			return "px_dirt", PODZOL
		end
		if n2(cx, cz, 2.2, 0.09) > 0.3 then
			return "px_gravel", nil
		end
		return "px_dirt", PATH_DIRT
	end, f)
	task.wait()
	-- the root mounds: a low hump of earth with roots breaking out (all decor) and a CreatureSpawn marker
	for _, m in ipairs(MOUNDS) do
		local mf = folder("RootMound", f)
		mf:SetAttribute("CreatureSpawn", true)
		local mx, mz = m[1], m[2]
		decor(box("MoundEarth", mx - 4, 0, mz - 4, mx + 4, 1.2, mz + 4, "px_dirt", Color3.fromRGB(96, 70, 52), mf))
		decor(box("MoundEarth", mx - 2, 1.2, mz - 2, mx + 2, 2, mz + 2, "px_forest_floor", Color3.fromRGB(150, 120, 96), mf))
		local n = rng:NextInteger(5, 6)
		for i = 1, n do
			local a = i / n * 2 * math.pi + rng:NextNumber(-0.35, 0.35)
			local ux, uz = math.cos(a), math.sin(a)
			local segs = rng:NextInteger(2, 3)
			for s = 1, segs do
				local d = 1 + s * 3.2
				local pos = V(mx + ux * d, 0.4 - s * 0.3, mz + uz * d)
				local p = part("MoundRoot", Vector3.new(3, 3, 4.4), CFrame.lookAt(pos, pos + Vector3.new(ux, -0.18, uz)), nil, nil, mf)
				textured(decor(p), "px_dark_oak_log", BARK)
			end
			if rng:NextNumber() < 0.6 then
				-- a root claw arching out of the ground at the end
				local d = 1 + (segs + 1) * 3.2
				local pos = V(mx + ux * d, 1.2, mz + uz * d)
				local p = part("MoundClaw", Vector3.new(2, 4, 2), CFrame.lookAt(pos, pos + Vector3.new(ux, 0, uz)) * CFrame.Angles(-0.45, 0, 0), nil, nil, mf)
				textured(decor(p), "px_dark_oak_log", BARK)
			end
		end
		local mk = decor(part("CreatureSpawn", Vector3.new(4, 1, 4), at(mx, 0.5, mz), nil, nil, mf))
		mk.Transparency = 1
		mk:SetAttribute("RootMound", true)
	end
end
task.wait()

-- ================================================================ 2. the four silo pillars
do
	local f = folder("SiloPillars", yard)
	for _, s in ipairs(SILOS) do
		silo(s, true, f)
		claim(s.x, s.z, 11)
	end
end
task.wait()

-- ================================================================ 3. the broken fence ring, the openings, the lamps
do
	local f = folder("Fence", yard)
	local N = 48
	local pts = {}
	for i = 0, N - 1 do
		local deg = i * 360 / N
		local a = math.rad(deg)
		local x, z = AX + math.cos(a) * FENCE_R, AZ + math.sin(a) * FENCE_R
		local ok = not (deg > 242 and deg < 298) -- the tree stands there
			and openPerp(x - AX, z - AZ) >= OPEN_HALF + 1
			and onIsland(x, z, 6)
			and z < -83
			and rng:NextNumber() > 0.08 -- a post gone
		pts[i] = { x = x, z = z, ok = ok }
	end
	for i = 0, N - 1 do
		local p, q = pts[i], pts[(i + 1) % N]
		if p.ok then
			local h = rng:NextNumber(2.8, 4.2)
			local cf = at(p.x, h / 2 - 0.2, p.z) * CFrame.Angles(rng:NextNumber(-0.14, 0.14), rng:NextNumber(0, 1), rng:NextNumber(-0.14, 0.14))
			textured(part("FencePost", Vector3.new(1, h, 1), cf, nil, nil, f), WOOD_DARK)
		end
		if p.ok and q.ok then
			local u = rng:NextNumber()
			local function rail(a, b)
				local len = (b - a).Magnitude
				textured(part("FenceRail", Vector3.new(0.4, 0.6, len), CFrame.lookAt((a + b) / 2, b), nil, nil, f), WOOD_DARK)
			end
			-- u < 0.16: a missing section
			if u >= 0.16 and u < 0.3 then
				-- a fallen rail: one end still on the post, the other on the ground
				rail(V(p.x, 2.4, p.z), V(q.x, 0.35, q.z))
			elseif u >= 0.3 then
				for _, h in ipairs(if u < 0.45 then { 1.2 } else { 1.2, 2.6 }) do
					rail(V(p.x, h + rng:NextNumber(-0.3, 0.3), p.z), V(q.x, h + rng:NextNumber(-0.3, 0.3), q.z))
				end
			end
		end
	end
	task.wait()
	-- each opening: two crooked gate posts at the fence line and a gallows lamp outside each side
	local function gallows(x, z, ux, uz, withRaven)
		local cf = at(x, 0, z) * CFrame.Angles(0, yawToward(ux, uz), 0)
		lp(cf, "LampBase", B + 1, 1, B + 1, 0, 0.5, 0, "px_mossy_cobblestone", nil, f)
		lp(cf, "LampPost", B, 14, B, 0, 8, 0, "px_dark_oak_log", nil, f)
		lp(cf, "LampArm", B, B, 2 * B, 0, 13, -6, "px_dark_oak_log", nil, f)
		textured(decor(beam("LampBrace", (cf * CFrame.new(0, 6.5, -2)).Position, (cf * CFrame.new(0, 11, -6.5)).Position, 1.4, nil, f)), WOOD_DARK)
		local lpos = (cf * CFrame.new(0, 5.6, -8)).Position
		chain((cf * CFrame.new(0, 11, -8)).Position, lpos + Vector3.new(0, 1.3, 0), f)
		lamp(lpos, f)
		if withRaven then
			raven(cf * CFrame.new(0, 15, -5) * CFrame.Angles(0, math.pi / 2, 0), f)
		end
	end
	for oi, deg in ipairs(OPEN) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		local px, pz = -uz, ux
		for _, side in ipairs({ -1, 1 }) do
			local gx, gz = AX + ux * FENCE_R + px * side * (OPEN_HALF + 1.5), AZ + uz * FENCE_R + pz * side * (OPEN_HALF + 1.5)
			if onIsland(gx, gz, 6) then
				local cf = at(gx, 2.6, gz) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 1), rng:NextNumber(-0.1, 0.1))
				textured(part("GatePost", Vector3.new(1.6, 5.6, 1.6), cf, nil, nil, f), "px_dark_oak_log")
			end
			local lx, lz = AX + ux * (FENCE_R + 3) + px * side * (OPEN_HALF + 5), AZ + uz * (FENCE_R + 3) + pz * side * (OPEN_HALF + 5)
			lz = math.min(lz, -85) -- the barn part starts at z -80
			if onIsland(lx, lz, 8) then
				gallows(lx, lz, -px * side, -pz * side, oi == 3 and side == 1)
				claim(lx, lz, 5)
			end
		end
	end
	-- a broken gate leaf lying in the grass beside the SE opening
	do
		local a = math.rad(OPEN[2])
		local x, z = AX + math.cos(a) * (FENCE_R + 6) + math.sin(a) * 20, AZ + math.sin(a) * (FENCE_R + 6) - math.cos(a) * 20
		if onIsland(x, z, 8) then
			local cf = at(x, 0.35, z) * CFrame.Angles(0, a, 0)
			for k = -1, 1 do
				decor(lp(cf, "GateBoard", 0.6, 0.6, 8, k * 1.3, 0, 0, WOOD_DARK, nil, f))
			end
			decor(lp(cf * CFrame.Angles(0, 0.5, 0), "GateBoard", 3.6, 0.6, 0.6, 0, 0.3, 0, WOOD_DARK, nil, f))
		end
	end
end
task.wait()

-- ================================================================ 4. round the rim: the scarecrow, the raven post, pumpkins, hay, stumps
do
	local f = folder("Rim", yard)
	-- the scarecrow with a burning pumpkin head (west of the arena)
	do
		local a = math.rad(200)
		local x, z = AX + math.cos(a) * 50, AZ + math.sin(a) * 50
		local sf = folder("Scarecrow", f)
		local cf = at(x, 0, z) * CFrame.Angles(0, yawToward(AX - x, AZ - z), 0)
		lp(cf, "ScarecrowPost", 1.2, 10, 1.2, 0, 5, 0, "px_oak_log", nil, sf)
		lp(cf, "ScarecrowArms", 11, 1, 1, 0, 7.6, 0, "px_oak_log", nil, sf)
		lp(cf, "ScarecrowCoat", 3.8, 4.4, 2.4, 0, 6.6, 0, "px_brown_wool", Color3.fromRGB(150, 120, 100), sf)
		lp(cf, "ScarecrowBelt", 3.9, 0.5, 2.5, 0, 5.2, 0, nil, Color3.fromRGB(60, 45, 35), sf)
		for _, s in ipairs({ -1, 1 }) do
			lp(cf, "ScarecrowSleeve", 3, 1.6, 1.6, s * 3.2, 7.6, 0, "px_brown_wool", Color3.fromRGB(130, 104, 86), sf)
			decor(lp(cf, "ScarecrowStraw", 1.4, 1.4, 1.4, s * 5.2, 7.4, 0, "px_hay", nil, sf))
		end
		jack(cf * CFrame.new(0, 8.8, 0), sf, false, 3.4)
		-- the hat pushed back off the burning head
		lp(cf * CFrame.new(0, 12, 1.6) * CFrame.Angles(-0.5, 0, 0.15), "HatBrim", 4.6, 0.4, 4.6, 0, 0, 0, "px_brown_wool", Color3.fromRGB(80, 62, 50), sf)
		lp(cf * CFrame.new(0, 12, 1.6) * CFrame.Angles(-0.5, 0, 0.15), "HatCrown", 2.6, 1.8, 2.6, 0, 1.1, 0, "px_brown_wool", Color3.fromRGB(80, 62, 50), sf)
		local fire = decor(part("HeadFire", Vector3.new(1.6, 0.4, 1.6), cf * CFrame.new(0, 12, -0.3), nil, nil, sf))
		fire.Transparency = 1
		emitter(fire, {
			Texture = "rbxasset://textures/particles/fire_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 196, 90), Color3.fromRGB(230, 80, 20)),
			LightEmission = 0.9,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 0.2) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(0.5, 0.9),
			Rate = 14,
			Speed = NumberRange.new(2, 3.5),
			SpreadAngle = Vector2.new(12, 12),
			RotSpeed = NumberRange.new(-40, 40),
			EmissionDirection = Enum.NormalId.Top,
		})
		glow(fire, 18, 1.1, FACE_GLOW)
		chain((cf * CFrame.new(4.6, 7.1, 0)).Position, (cf * CFrame.new(4.6, 2.6, 0)).Position, sf)
		local hx, _, hz = loc(cf, -3.5, 0, 2)
		hayBale(hx, 0, hz, sf, 0.3)
		candles(hx, B, hz, sf)
		claim(x, z, 6)
	end
	-- the raven on a post, a hay bale with candles and a barrel at its foot (north-east of the arena)
	do
		local a = math.rad(330)
		local x, z = AX + math.cos(a) * 50, AZ + math.sin(a) * 50
		local cf = at(x, 0, z) * CFrame.Angles(0, yawToward(AX - x, AZ - z), 0)
		lp(cf, "RavenPost", 1.6, 9, 1.6, 0, 4.5, 0, "px_dark_oak_log", nil, f)
		raven(cf * CFrame.new(0, 9, 0) * CFrame.Angles(0, 0.6, 0), f)
		local hx, _, hz = loc(cf, 3, 0, 1)
		hayBale(hx, 0, hz, f, 0.2)
		candles(hx, B, hz, f)
		local bx, _, bz = loc(cf, -3, 0, 1.5)
		barrel(bx, 0, bz, f)
		claim(x, z, 6)
	end
	-- the props round the ring: inside the fence (r 47.5–52, outside the fight circle r 44) and outside it (r 60–66)
	local KINDS = { "jackHay", "stump", "hayCandles", "jack", "barrel", "weeds", "jackHay", "hayCandles", "stump", "jack", "weeds" }
	local litLeft = 5
	local ki = 0
	for k = 0, 47 do
		local deg = k * 7.5 + rng:NextNumber(-2, 2)
		local a = math.rad(deg)
		local inside = k % 2 == 0
		local r = if inside then rng:NextNumber(47.5, 52) else rng:NextNumber(60, 66)
		local x, z = AX + math.cos(a) * r, AZ + math.sin(a) * r
		local dd = deg % 360
		if not (dd > 236 and dd < 304) and openPerp(x - AX, z - AZ) >= OPEN_HALF + 3 and onIsland(x, z, 10) and z < -87 and routeDist(x, z) > 3 and not taken(x, z, 4) then
			ki += 1
			claim(x, z, 4)
			local kind = KINDS[(ki - 1) % #KINDS + 1]
			local face = if inside then yawToward(AX - x, AZ - z) else yawToward(x - AX, z - AZ)
			local tx, tz = -math.sin(a), math.cos(a) -- along the ring
			local pf = folder("RimProp", f)
			if kind == "jackHay" then
				hayBale(x, 0, z, pf, face)
				jack(at(x, B, z) * CFrame.Angles(0, face, 0), pf, litLeft > 0)
				litLeft -= 1
				hayBale(x + tx * 4.4, 0, z + tz * 4.4, pf, face + 0.2)
				candles(x + tx * 4.4, B, z + tz * 4.4, pf)
			elseif kind == "hayCandles" then
				hayBale(x, 0, z, pf, face)
				hayBale(x - tx * 4.2, 0, z - tz * 4.2, pf, face - 0.15)
				if rng:NextNumber() < 0.5 then
					hayBale(x, B, z, pf, face + 0.3)
					candles(x, 2 * B, z, pf)
				else
					candles(x, B, z, pf)
				end
				candles(x - tx * 4.2, B, z - tz * 4.2, pf)
			elseif kind == "jack" then
				jack(at(x, 0, z) * CFrame.Angles(0, face, 0), pf, litLeft > 0)
				litLeft -= 1
				jack(at(x + tx * 4, 0, z + tz * 4) * CFrame.Angles(0, face + 0.4, 0), pf, false, 3)
				candles(x - tx * 3.5, 0, z - tz * 3.5, pf)
			elseif kind == "barrel" then
				barrel(x, 0, z, pf)
				candles(x, B, z, pf)
				pumpkin(x + tx * 4, 0, z + tz * 4, pf)
			elseif kind == "weeds" then
				for _ = 1, rng:NextInteger(3, 5) do
					weed(x + rng:NextNumber(-4, 4), z + rng:NextNumber(-4, 4), pf)
				end
				pumpkin(x, 0, z, pf)
			else -- a stump with a chain over its side to a stake in the ground
				local h = pick({ B, B * 1.5 })
				cube("Stump", x, h / 2, z, B, h, B, "px_oak_log", Color3.fromRGB(150, 120, 100), pf)
				textured(decor(part("StumpTop", Vector3.new(B - 0.4, 0.2, B - 0.4), at(x, h + 0.1, z), nil, nil, pf)), "px_oak_log_top")
				local d = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
				local p1 = V(x + d[1] * 0.6, h + 0.25, z + d[2] * 0.6)
				local p2 = V(x + d[1] * 2.15, h - 0.2, z + d[2] * 2.15)
				local p3 = V(x + d[1] * 2.25, 0.25, z + d[2] * 2.25)
				local p4 = V(x + d[1] * 5 + d[2] * 1.5, 0.15, z + d[2] * 5 + d[1] * 1.5)
				chain(p1, p2, pf)
				chain(p2, p3, pf)
				chain(p3, p4, pf)
				decor(part("ChainStake", Vector3.new(0.7, 1.2, 0.7), CFrame.new(p4 + Vector3.new(0, 0.3, 0)), METAL, Enum.Material.Metal, pf))
				decor(part("ChainStaple", Vector3.new(0.8, 0.4, 0.8), CFrame.new(p1), METAL, Enum.Material.Metal, pf))
				-- a root flare or two
				for _ = 1, 2 do
					local e = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
					decor(cube("StumpRoot", x + e[1] * 3, 0.6, z + e[2] * 3, if e[1] ~= 0 then 2.4 else 1.6, 1.8, if e[2] ~= 0 then 2.4 else 1.6, "px_oak_log", Color3.fromRGB(150, 120, 100), pf))
				end
			end
		end
	end
	-- tall weeds along the inner rim (decor, r 44–52)
	for _ = 1, 40 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(44.5, 55)
		local x, z = AX + math.cos(a) * r, AZ + math.sin(a) * r
		if onIsland(x, z, 4) and z < -84 and routeDist(x, z) > 0 then
			weed(x, z, f)
		end
	end
end
task.wait()

-- ================================================================ 5. the guardian's gnarled dead tree with the glowing face
do
	local f = folder("GuardianTree", yard)
	local DARK = "px_dark_oak_log"
	local GX, GZ = GUARDIAN.x, GUARDIAN.z
	-- keep the trunk on the island: move it south (at most to z -196, its front stays outside r 44)
	while GZ < -196 and not (onIsland(GX - 12, GZ - 12, 10) and onIsland(GX + 12, GZ - 12, 10) and onIsland(GX, GZ - 14, 10)) do
		GZ += B
	end
	claim(GX, GZ, 40)
	local function maybeDecor(p, x, z)
		if inArena(x, z, 2) or not onIsland(x, z, 10) then
			decor(p)
		end
		return p
	end
	-- the root flare (5 blocks across, corners cut) and the trunk: 4×4 blocks, leaning west as it climbs, narrower
	-- at the top; bark ridges spiral round it
	box("RootFlare", GX - 6, 0, GZ - 10, GX + 6, 4, GZ + 10, DARK, BARK, f)
	box("RootFlare", GX - 10, 0, GZ - 6, GX - 6, 4, GZ + 6, DARK, BARK, f)
	box("RootFlare", GX + 6, 0, GZ - 6, GX + 10, 4, GZ + 6, DARK, BARK, f)
	local SECT = { { 0, 8 }, { 0, 8 }, { 0, 8 }, { -4, 8 }, { -4, 8 }, { -8, 6 }, { -8, 6 } } -- { x offset, half width }
	local CORN = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
	for k, s in ipairs(SECT) do
		local y0 = 4 + (k - 1) * 8
		local ox, hw = GX + s[1], s[2]
		box("Trunk", ox - hw, y0, GZ - hw, ox + hw, y0 + 8, GZ + hw, DARK, if k % 2 == 0 then BARK else Color3.fromRGB(135, 125, 118), f)
		local c = CORN[(k - 1) % 4 + 1]
		if k >= 3 then -- the ridges start above the face
			cube("BarkRidge", ox + c[1] * hw, y0 + 4, GZ + c[2] * hw, B, 8, B, DARK, Color3.fromRGB(120, 110, 104), f)
		end
	end
	local TOP_Y = 4 + #SECT * 8 -- 60
	-- the face on the south side (toward the arena), all decor plates on the front z F
	local F = GZ + 8
	local function plate(name, x0, y0, x1, y1, depth, variant, tint, neon)
		local p = decor(box(name, GX + x0, y0, F, GX + x1, y1, F + depth, variant, tint, f))
		if neon then
			p.Material = Enum.Material.Neon
			p.Color = tint
		end
		return p
	end
	local SOCKET = Color3.fromRGB(60, 56, 54)
	local BROW = Color3.fromRGB(110, 100, 94)
	for _, sx in ipairs({ -1, 1 }) do
		local function xs(a, b) -- mirror an x range to this side
			if sx < 0 then
				return -b, -a
			end
			return a, b
		end
		local a0, a1 = xs(2, 7)
		plate("EyeSocket", a0, 19, a1, 24, 0.15, "px_coal_block", SOCKET)
		a0, a1 = xs(2.5, 6.5)
		plate("Eye", a0, 20, a1, 21.6, 0.3, nil, FACE_GLOW, true)
		a0, a1 = xs(4.5, 6.5)
		plate("Eye", a0, 21.6, a1, 22.8, 0.3, nil, FACE_GLOW, true) -- the outer corner higher: an angry slant
		a0, a1 = xs(5, 8)
		plate("Brow", a0, 24, a1, 25.6, 1.4, DARK, BROW)
		a0, a1 = xs(1.5, 5)
		plate("Brow", a0, 23, a1, 24.6, 1.4, DARK, BROW) -- the brows drop toward the nose
	end
	plate("Nose", -1.5, 16, 1.5, 19.5, 1.6, DARK, BROW)
	plate("MouthSocket", -6, 9, 6, 15, 0.15, "px_coal_block", SOCKET)
	plate("Mouth", -5, 10.5, 5, 13.5, 0.3, nil, FACE_GLOW, true)
	for _, tx in ipairs({ -4, -1, 2 }) do
		plate("Tooth", tx, 12.4, tx + 2, 13.6, 0.5, DARK, BROW)
	end
	for _, tx in ipairs({ -2.5, 0.5, 3.5 }) do
		plate("Tooth", tx - 1, 10.4, tx + 1, 11.4, 0.5, DARK, BROW)
	end
	local faceLight = decor(part("FaceGlow", Vector3.new(1, 1, 1), at(GX, 17, F + 3), nil, nil, f))
	faceLight.Transparency = 1
	glow(faceLight, 28, 1.1, FACE_GLOW)
	task.wait()

	-- the roots: stepped log runs on the 4-stud grid, high by the trunk, sinking outward; decor inside the arena
	local used = {}
	local ROOTS = { { 15, 32 }, { 50, 40 }, { 78, 44 }, { 102, 44 }, { 130, 40 }, { 165, 32 }, { 200, 22 }, { 340, 22 }, { 240, 16 }, { 300, 16 } }
	for _, rd in ipairs(ROOTS) do
		local a = math.rad(rd[1] + rng:NextNumber(-6, 6))
		local wob = rng:NextNumber(-0.012, 0.012)
		local s = 9
		while s <= rd[2] do
			local aa = a + wob * s
			local cx = math.floor((GX + math.cos(aa) * s) / B) * B + 2
			local cz = math.floor((GZ + math.sin(aa) * s) / B) * B + 2
			if not onIsland(cx, cz, 2) then
				break
			end
			local key = cx .. "," .. cz
			local inTrunk = math.abs(cx - GX) < 8 and math.abs(cz - GZ) < 8
			if not used[key] and not inTrunk then
				local tf = (s - 9) / math.max(1, rd[2] - 9)
				local top = if tf < 0.25 then 8 elseif tf < 0.6 then 4 else 2
				if inArena(cx, cz, 2) then
					top = math.min(top, 1.6)
				end
				used[key] = top
				maybeDecor(box("Root", cx - 2, -1, cz - 2, cx + 2, top, cz + 2, DARK, BARK, f), cx, cz)
			end
			s += 2.5
		end
	end
	task.wait()

	-- the branches: crooked runs of log blocks with kinks, climbing; twigs off the middle; crown blobs at the tips
	local usedB, tips, cells = {}, {}, {}
	local function branch(x, y, z, deg, steps, rise, twig)
		local a = math.rad(deg)
		local fx, fz = x, z
		for st = 1, steps do
			if st % 3 == 0 then
				a += math.rad(rng:NextNumber(-35, 35))
			end
			fx += math.cos(a) * B
			fz += math.sin(a) * B
			if st % rise == 0 then
				y += B
			end
			local cx, cz = math.floor(fx / B) * B + 2, math.floor(fz / B) * B + 2
			local key = cx .. "," .. y .. "," .. cz
			if not usedB[key] then
				usedB[key] = true
				maybeDecor(cube("Branch", cx, y + 2, cz, B, B, B, DARK, BARK, f), cx, cz)
				table.insert(cells, { cx, y, cz })
			end
			if not twig and st == steps // 2 then
				branch(fx, y, fz, math.deg(a) + pick({ -55, 55 }), 3, 1, true)
			end
		end
		table.insert(tips, { math.floor(fx / B) * B + 2, y, math.floor(fz / B) * B + 2 })
	end
	local BR = { -- { degrees, start y, steps, rise every n steps, x offset of the section, half width }
		{ 20, 50, 8, 3, -8, 6 },
		{ 72, 46, 7, 2, -8, 6 },
		{ 108, 48, 7, 2, -8, 6 },
		{ 160, 52, 8, 3, -8, 6 },
		{ 205, 54, 6, 2, -8, 6 },
		{ 335, 54, 6, 2, -8, 6 },
		{ 268, 56, 4, 1, -8, 6 },
		{ 0, 26, 6, 2, 0, 8 }, -- the low arms
		{ 180, 22, 6, 2, 0, 8 },
	}
	for _, b in ipairs(BR) do
		local a = math.rad(b[1])
		branch(GX + b[5] + math.cos(a) * (b[6] - 2), b[2], GZ + math.sin(a) * (b[6] - 2), b[1], b[3], b[4], false)
	end
	-- a stub of broken top
	cube("Branch", GX - 8, TOP_Y + 2, GZ - 2, B, B, B, DARK, BARK, f)
	local LEAF = { Color3.fromRGB(243, 200, 59), Color3.fromRGB(194, 127, 44), Color3.fromRGB(255, 255, 70), Color3.fromRGB(220, 150, 50) } -- px_cherry_leaves tinted autumn (as 40-outskirts)
	local usedL = {}
	for _, t in ipairs(tips) do
		local tint = pick(LEAF)
		for _ = 1, rng:NextInteger(5, 8) do
			local x = t[1] + rng:NextInteger(-1, 1) * B
			local y = t[2] + rng:NextInteger(-1, 1) * B
			local z = t[3] + rng:NextInteger(-1, 1) * B
			local key = x .. "," .. y .. "," .. z
			if not usedL[key] and not usedB[key] then
				usedL[key] = true
				local p = cube("Leaves", x, y + 2, z, B, B, B, "px_cherry_leaves", tint, f)
				decor(p)
			end
		end
	end
	task.wait()
	-- lanterns hanging on chains from branches over the arena side, one bare chain
	local hang = {}
	for _, c in ipairs(cells) do
		if c[3] > GZ + 10 and c[2] >= 26 and c[2] <= 52 then
			table.insert(hang, c)
		end
	end
	local picked = {}
	if #hang > 0 then
		local first = hang[1]
		table.insert(picked, first)
		local best, bestD = nil, -1
		for _, c in ipairs(hang) do
			local d = (c[1] - first[1]) ^ 2 + (c[3] - first[3]) ^ 2
			if d > bestD then
				best, bestD = c, d
			end
		end
		if best and best ~= first then
			table.insert(picked, best)
		end
	end
	for i, c in ipairs(picked) do
		local len = if i == 1 then 9 else 12
		local top = V(c[1], c[2], c[3])
		local lpos = top - Vector3.new(0, len, 0)
		chain(top, lpos + Vector3.new(0, 1.3, 0), f)
		lamp(lpos, f)
	end
	if #hang > 2 then
		local c = hang[math.ceil(#hang / 2)]
		chain(V(c[1], c[2], c[3]), V(c[1], c[2] - 7, c[3]), f)
	end
	-- pumpkins and candles at the roots in front of the trunk, three old gravestones beside it
	local function groundAt(x, z)
		local cx, cz = math.floor(x / B) * B + 2, math.floor(z / B) * B + 2
		return used[cx .. "," .. cz] or 0, cx, cz
	end
	for i, sx in ipairs({ -14, 14 }) do
		local y, cx, cz = groundAt(GX + sx, F + 4)
		if y <= 8 then
			jack(at(cx, y, cz) * CFrame.Angles(0, yawToward(0, 1), 0), f, i == 1)
			candles(cx + 3, groundAt(cx + 3, cz), cz + 1, f)
		end
	end
	for _, g in ipairs({ { -30, 2 }, { -38, -8 }, { 32, -6 } }) do
		local x, z = GX + g[1], GZ + g[2]
		local y = groundAt(x, z)
		if y == 0 and onIsland(x, z, 8) then
			local cf = at(x, 0, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), yawToward(0, 1) + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.12, 0.12))
			lp(cf, "Gravestone", B, 5, 1.6, 0, 2.3, 0, pick({ "px_mossy_stone_bricks", "px_cobblestone", "px_mossy_cobblestone" }), nil, f)
			decor(lp(cf, "GraveMound", B, 0.4, 6, 0, 0, -4, "px_dirt", PODZOL, f))
			if rng:NextNumber() < 0.6 then
				local cx, _, cz = loc(cf, 0, 0, -2)
				candles(cx, 0, cz, f)
			end
		end
	end
end
task.wait()

-- ================================================================ 6. the north of the island
do
	local f = folder("North", yard)
	-- free ground for a solid thing of radius r: the yard zone, on the island, outside the fence ring and its props,
	-- off the paths and everything placed
	local function free(x, z, r)
		if z > -86 - r then
			return false
		end
		for _, o in ipairs({ { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } }) do
			local px, pz = x + o[1], z + o[2]
			if not onIsland(px, pz, 10) or zoneOf(px, pz) ~= "yard" then
				return false
			end
		end
		if (x - AX) ^ 2 + (z - AZ) ^ 2 < (68 + r) ^ 2 then
			return false
		end
		if routeDist(x, z) < r + 2 or onPath(x, z, r + 2) or taken(x, z, r) then
			return false
		end
		return true
	end
	local function spot(r, tries)
		for _ = 1, tries or 60 do
			local x, z = rng:NextNumber(-200, 200), rng:NextNumber(-216, -88)
			if free(x, z, r) then
				claim(x, z, r)
				return math.floor(x / B) * B + 2, math.floor(z / B) * B + 2
			end
		end
		return nil
	end

	-- two more broken silos (decor, not pillars), west and east of the arena
	for _, cand in ipairs({
		{ { -108, -128 }, { -112, -150 }, { -100, -172 }, { -120, -110 } },
		{ { 108, -146 }, { 112, -124 }, { 100, -172 }, { 120, -110 } },
	}) do
		for i, c in ipairs(cand) do
			if free(c[1], c[2], 12) then
				claim(c[1], c[2], 12)
				local west = c[1] < 0
				silo({ x = c[1], z = c[2], h = if west then 44 else 28, bands = if west then { 8, 20, 32 } else { 8, 20 }, dome = not west }, false, f)
				break
			end
			if i == #cand then
				warn("[build-barn] yard: no room for a north silo")
			end
		end
	end
	task.wait()

	-- the abandoned cart: three wheels (the fourth lies in the grass), the bed tipped onto the missing corner
	do
		local x, z = spot(12)
		if x then
			local cartF = folder("Cart", f)
			local cf = at(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
			local bed = cf * CFrame.new(0, 3.4, 0) * CFrame.Angles(-0.07, 0, 0.09)
			lp(bed, "CartBed", 8, 0.8, 16, 0, 0, 0, "px_spruce_planks", OLD_WOOD, cartF)
			for _, s in ipairs({ -1, 1 }) do
				lp(bed, "CartSide", 0.8, 2, 16, s * 3.6, 1.4, 0, "px_spruce_planks", OLD_WOOD, cartF)
			end
			lp(bed, "CartEnd", 6.4, 2, 0.8, 0, 1.4, 7.6, "px_spruce_planks", OLD_WOOD, cartF)
			lp(bed, "CartEnd", 6.4, 0.8, 0.8, 0, 0.8, -7.6, "px_spruce_planks", OLD_WOOD, cartF) -- the broken front board
			lp(bed, "CartAxle", 9.6, 0.6, 0.6, 0, -1, 5, nil, METAL, cartF)
			lp(bed, "CartAxle", 9.6, 0.6, 0.6, 0, -1, -5, nil, METAL, cartF)
			wheel(cf * CFrame.new(4.6, 2.6, 5), cartF)
			wheel(cf * CFrame.new(-4.6, 2.6, 5), cartF)
			wheel(cf * CFrame.new(4.6, 2.6, -5), cartF)
			wheel(cf * CFrame.new(-8, 0.35, -8) * CFrame.Angles(0, 0.4, math.pi / 2), cartF)
			lp(cf * CFrame.new(0, 0.6, -13) * CFrame.Angles(0, 0.25, 0.1), "CartShaft", 0.8, 0.8, 10, 0, 0, 0, "px_spruce_planks", OLD_WOOD, cartF)
			-- the load: a hay bale, pumpkins, a fallen board
			textured(part("CartHay", Vector3.new(B, B, B), bed * CFrame.new(1.2, 2.4, 3.4) * CFrame.Angles(0, 0.2, 0), nil, nil, cartF), "px_hay")
			lp(bed, "CartPumpkin", 3, 2.7, 3, -1.4, 1.75, -2, "px_hay", PUMPKIN, cartF)
			lp(bed, "CartPumpkin", 2.6, 2.4, 2.6, 1.6, 1.6, -4.6, "px_hay", PUMPKIN, cartF)
			decor(lp(cf * CFrame.new(6.5, 0.3, 2) * CFrame.Angles(0, 0.7, 0), "CartBoard", 0.8, 0.6, 7, 0, 0, 0, "px_spruce_planks", OLD_WOOD, cartF))
			for _ = 1, 3 do
				weed(x + rng:NextNumber(-8, 8), z + rng:NextNumber(-8, 8), cartF)
			end
		end
	end

	-- junk heaps: coarse dirt mounds with planks, barrels, a crate, a chain, a cart wheel and a pumpkin on top
	for i = 1, 3 do
		local x, z = spot(11)
		if x then
			local jf = folder("JunkHeap", f)
			local ox, oz = pick({ -2, 2 }), pick({ -2, 2 })
			box("JunkMound", x - 6, 0, z - 6, x + 6, 4, z + 6, "px_dirt", COARSE, jf)
			box("JunkMound", x - 4 + ox, 4, z - 4 + oz, x + 4 + ox, 8, z + 4 + oz, "px_dirt", Color3.fromRGB(116, 88, 64), jf)
			cube("JunkTop", x + ox * 2, 10, z + oz * 2, B, B, B, pick({ "px_gravel", "px_planks", "px_dirt" }), nil, jf)
			jack(at(x + ox * 2, 12, z + oz * 2) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), jf, i == 1, 3.2)
			for _ = 1, 2 do
				local p = part("JunkPlank", Vector3.new(0.6, 1, 8), at(x + rng:NextNumber(-3, 3), 5, z + rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), nil, nil, jf)
				textured(decor(p), "px_spruce_planks", OLD_WOOD)
			end
			barrel(x - ox * 4, 0, z + 8, jf, if rng:NextNumber() < 0.5 then "px_coal_block" else nil)
			if rng:NextNumber() < 0.6 then
				crate(x + 8, 0, z - oz * 3, jf, B, rng:NextNumber(0, 1))
			end
			chain(V(x + ox * 2 + 1.5, 11, z + oz * 2 + 1.5), V(x + ox + 4.6, 4.4, z + oz + 4.6), jf)
			chain(V(x + ox + 4.6, 4.2, z + oz + 4.6), V(x + 7, 0.3, z + 7.4), jf)
			wheel(at(x - 7.2, 2.7, z - 1) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), -0.3), jf)
			for _ = 1, 3 do
				weed(x + rng:NextNumber(-9, 9), z + rng:NextNumber(-9, 9), jf)
			end
		end
	end
	task.wait()

	-- autumn trees: a log trunk and a stepped crown of orange, red and amber leaves (corners cut, loose blocks)
	local LEAVES = { Color3.fromRGB(243, 200, 59), Color3.fromRGB(194, 127, 44), Color3.fromRGB(220, 110, 40), Color3.fromRGB(255, 255, 70) } -- px_cherry_leaves tinted autumn
	local function leafLayer(cx, cz, w, y0, tint, parent)
		local hw = w * B / 2
		box("Leaves", cx - hw + B, y0, cz - hw, cx + hw - B, y0 + B, cz + hw, "px_cherry_leaves", tint, parent)
		box("Leaves", cx - hw, y0, cz - hw + B, cx - hw + B, y0 + B, cz + hw - B, "px_cherry_leaves", tint, parent)
		box("Leaves", cx + hw - B, y0, cz - hw + B, cx + hw, y0 + B, cz + hw - B, "px_cherry_leaves", tint, parent)
	end
	for _ = 1, 8 do
		local x, z = spot(11)
		if x then
			local tf = folder("AutumnTree", f)
			local h = rng:NextInteger(4, 6) * B
			local tint = pick(LEAVES)
			box("Trunk", x - 2, 0, z - 2, x + 2, h + B, z + 2, pick({ "px_oak_log", "px_dark_oak_log" }), nil, tf)
			leafLayer(x, z, 5, h - B, tint, tf)
			leafLayer(x, z, 5, h, tint, tf)
			leafLayer(x, z, 3, h + B, tint, tf)
			cube("Leaves", x, h + 2 * B + 2, z, B, B, B, "px_cherry_leaves", tint, tf)
			for _ = 1, 4 do
				local lx, lz = x + rng:NextInteger(-3, 3) * B, z + rng:NextInteger(-3, 3) * B
				if math.abs(lx - x) > 8 or math.abs(lz - z) > 8 then
					cube("Leaves", lx, h + rng:NextInteger(-1, 1) * B + 2, lz, B, B, B, "px_cherry_leaves", pick(LEAVES), tf)
				end
			end
			-- fallen leaves under it
			decor(box("LeafLitter", x - 10, 0, z - 10, x + 10, 0.15, z + 10, "px_forest_floor", Color3.fromRGB(215, 150, 95), tf)).CastShadow = false
		end
	end
	task.wait()

	-- dead trees: grey bare trunks with crooked stepped branches, one with a raven, a few orange leaves left
	local ravenDone = false
	for _ = 1, 5 do
		local x, z = spot(9)
		if x then
			local df = folder("DeadTree", f)
			local h = rng:NextInteger(5, 7) * B
			box("DeadTrunk", x - 2, 0, z - 2, x + 2, h, z + 2, "px_dark_oak_log", BARK, df)
			for _, d in ipairs({ { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }) do
				if rng:NextNumber() < 0.75 then
					local y = h - rng:NextInteger(1, 3) * B
					local len = rng:NextInteger(1, 2)
					for k = 1, len do
						cube("DeadBranch", x + d[1] * B * k, y + 2 + (k - 1) * B, z + d[2] * B * k, B, B, B, "px_dark_oak_log", BARK, df)
					end
					local tx, ty, tz = x + d[1] * B * len, y + len * B, z + d[2] * B * len
					cube("DeadBranch", tx, ty + 2, tz, B, B, B, "px_dark_oak_log", BARK, df)
					if not ravenDone then
						ravenDone = true
						raven(at(tx, ty + B, tz) * CFrame.Angles(0, yawToward(AX - tx, AZ - tz), 0), df)
					elseif rng:NextNumber() < 0.35 then
						decor(cube("Leaves", tx, ty + B + 2, tz, B, B, B, "px_cherry_leaves", pick(LEAVES), df))
					end
				end
			end
		end
	end
	task.wait()

	-- broken fence lines out in the weeds
	for _ = 1, 4 do
		local x, z = spot(6)
		if x then
			local ff = folder("BrokenFence", f)
			local a = rng:NextNumber(0, math.pi)
			local ux, uz = math.cos(a), math.sin(a)
			local prev = nil
			for k = -3, 3 do
				local px, pz = x + ux * k * 4.5, z + uz * k * 4.5
				local ok = onIsland(px, pz, 10) and zoneOf(px, pz) == "yard" and pz < -86 and routeDist(px, pz) > 2 and not onPath(px, pz, 2) and rng:NextNumber() > 0.15
				if ok then
					local h = rng:NextNumber(2.6, 4)
					textured(part("FencePost", Vector3.new(1, h, 1), at(px, h / 2 - 0.2, pz) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), 0, rng:NextNumber(-0.15, 0.15)), nil, nil, ff), WOOD_DARK)
					if prev and rng:NextNumber() < 0.75 then
						local a0, b0 = V(prev[1], 1.4 + rng:NextNumber(-0.3, 0.3), prev[2]), V(px, 1.4 + rng:NextNumber(-0.3, 0.3), pz)
						textured(part("FenceRail", Vector3.new(0.4, 0.6, (b0 - a0).Magnitude), CFrame.lookAt((a0 + b0) / 2, b0), nil, nil, ff), WOOD_DARK)
						if rng:NextNumber() < 0.5 then
							local a1, b1 = a0 + Vector3.new(0, 1.4, 0), b0 + Vector3.new(0, 1.4, 0)
							textured(part("FenceRail", Vector3.new(0.4, 0.6, (b1 - a1).Magnitude), CFrame.lookAt((a1 + b1) / 2, b1), nil, nil, ff), WOOD_DARK)
						end
					end
					prev = { px, pz }
				else
					prev = nil
				end
			end
		end
	end

	-- tall weeds all over the north (decor), thicker toward the rim
	for _ = 1, 140 do
		local x, z = rng:NextNumber(-210, 210), rng:NextNumber(-218, -84)
		local rr = (x - AX) ^ 2 + (z - AZ) ^ 2
		if onIsland(x, z, 3) and z < -83 and rr > 58 * 58 and routeDist(x, z) > 0 and not onPath(x, z, 0) then
			weed(x, z, f)
			if rng:NextNumber() < 0.4 then
				weed(x + rng:NextNumber(-2.5, 2.5), z + rng:NextNumber(-2.5, 2.5), f)
			end
		end
	end
	task.wait()

	-- a thin ground fog (three sparse emitters): behind the arena by the tree, west and east
	for _, fp in ipairs({ { 0, -186, 70, 30 }, { -120, -150, 60, 50 }, { 120, -150, 60, 50 } }) do
		local fogPart = decor(part("YardFog", Vector3.new(fp[3], 1, fp[4]), at(fp[1], 1.5, fp[2]), nil, nil, f))
		fogPart.Transparency = 1
		fogPart.CastShadow = false
		emitter(fogPart, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(196, 170, 150)),
			Size = NumberSequence.new(8, 16),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.82),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(10, 14),
			Rate = 3,
			Speed = NumberRange.new(0.3, 0.9),
			SpreadAngle = Vector2.new(180, 8),
			RotSpeed = NumberRange.new(-6, 6),
			LightInfluence = 0.6,
		})
	end
end
print(("[build-barn] yard: %d parts, %d lights"):format(count - count0, lightsUsed))
