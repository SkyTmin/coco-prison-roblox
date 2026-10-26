--!nocheck
-- ================================================================ kyoto: the hill — the L1 terrace, the west of L2, the boss arena
-- The HILL part (zoneOf == "hill": x < 56, z < -8, except the main stair corridor):
--   arena       ARENA (-88, -128) r 56 on L2 (y 32): a wooden floor laid flush on the core's stone (a five-petal red mon
--               with a white rim, a cherry dash ring, a red ring, a red-white chequer, a dark border, a stone ring
--               r 50..56); four red pillars at r 34 on the diagonals (black base 3×3 blocks, red shaft 2×2 blocks up to
--               +24, a dark stepped roof with raised tips and two paper lanterns; base and shaft tagged Pillar);
--               a red fence ring r 58 with openings (6 blocks) east (0°, the L2 path to the temple court), south (90°,
--               the arena stair) and west-north-west (200°, the cliff path to the overlook); stone lanterns flank each
--               opening; a stone retaining platform where the round terrace hangs over L1 in the south
--   outside     nobori banners, a weapon rack with straw targets, a katana stand, a fox shrine with a torii and a fox pair,
--               a bell tower, cherry trees, bamboo behind the shrine
--   stairs      the arena stair L1 → L2 (x -96..-80, z -40 → -72) with stepped side walls and a torii at its foot;
--               the west stair L0 → L1 (x -180..-164, z 24 → -8) with a stone lantern pair at the top
--   L1          a gravel path from the west stair top along z -36..-16 to the main stair landing (x 16), a spur to the
--               arena stair; the dry zen garden x -168..-112, z -68..-40 (raked rows and rings, three black rock piles
--               on moss, a plaster wall with a dark tile coping west and north, a tea veranda east); three machiya
--               x -68..8, z -60..-40 facing the path; a bamboo grove x -220..-188; cherry trees, petals, lanterns
--   cliffs      moss plates, leafy lips and hanging vine curtains on some cliff faces of the hill zone
local hill = folder("Hill")
local startCount = count
local lightsLeft = 26 -- PointLights this part may still add
local RED_V = "px_white_wool" -- red lacquer: white wool tinted TORII_RED
local WHITE = Color3.fromRGB(246, 242, 236)
local BAMBOO = Color3.fromRGB(150, 205, 100)
local MOSS = Color3.fromRGB(96, 140, 70)
local CORNERS = { { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }
local OPENINGS = { 0, 90, 200 } -- the arena ways in: degrees from +X toward +Z (90 = south)
local OPEN_HALF = 12 -- half the clear width of an opening (6 blocks)
local RES = {} -- reserved rects {x0, z0, x1, z1} and path segments the scatter keeps off

local function warm(p, range, bright)
	if lightsLeft > 0 then
		lightsLeft -= 1
		light(p, range or 24, bright or 1.1, LANTERN_GLOW)
	end
end
local function reserve(x0, z0, x1, z1)
	table.insert(RES, { x0, z0, x1, z1 })
end
local function reserved(x, z, pad)
	pad = pad or 0
	for _, r in ipairs(RES) do
		if r[6] then
			if segDist(x, z, r[1], r[2], r[3], r[4]) < r[5] + pad then
				return true
			end
		elseif x >= r[1] - pad and x <= r[3] + pad and z >= r[2] - pad and z <= r[4] + pad then
			return true
		end
	end
	return false
end
-- the terrace height of the island cell (8 studs) holding a point: tests agree with the core's ground runs
local function gy8(x, z)
	return groundY(math.floor((x + 248) / 8) * 8 - 244, math.floor((z + 248) / 8) * 8 - 244)
end
-- flush pattern runs: fn(cx, cz, ix, iz) -> variant, tint[, y0, y1] or nil for each cell of c studs; equal neighbours
-- along x merge into one box
local function layRuns(name, x0, z0, nx, nz, c, y0, y1, fn, parent)
	local n = 0
	for iz = 0, nz - 1 do
		local zc = z0 + iz * c
		local runX, runKey, runV, runT, runY0, runY1 = nil, nil, nil, nil, nil, nil
		local function flush(xEnd)
			if runX then
				box(name, runX, runY0, zc, xEnd, runY1, zc + c, runV, runT, parent)
				n += 1
			end
			runX = nil
		end
		for ix = 0, nx - 1 do
			local xc = x0 + ix * c
			local v, t, ya, yb = fn(xc + c / 2, zc + c / 2, ix, iz)
			ya, yb = ya or y0, yb or y1
			local key = if v then v .. "|" .. tostring(t) .. "|" .. ya .. "|" .. yb else nil
			if key ~= runKey then
				flush(xc)
				if v then
					runX, runV, runT, runY0, runY1 = xc, v, t, ya, yb
				end
				runKey = key
			end
		end
		flush(x0 + nx * c)
	end
	return n
end
-- a textured part in a frame cf by size and local centre
local function lp(cf, name, sx, sy, sz, x, y, z, variant, tint, parent)
	local p = part(name, Vector3.new(sx, sy, sz), cf * CFrame.new(x, y, z), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- the distance of (dx, dz) (from the arena centre) to the nearest opening axis, on the outward side of it
local function openPerp(dx, dz)
	local best = math.huge
	for _, deg in ipairs(OPENINGS) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		if dx * ux + dz * uz > 0 then
			best = math.min(best, math.abs(-dx * uz + dz * ux))
		end
	end
	return best
end
-- a stone lantern (tōrō): base, stem, seat, a fire box with glowing windows on four sides, a stepped roof
local function stoneLantern(x, y, z, parent, lit)
	local f = folder("StoneLantern", parent)
	local DARKER = Color3.fromRGB(128, 126, 124)
	cube("ToroBase", x, y + 0.6, z, 4, 1.2, 4, "px_stone_bricks", STONE, f)
	cube("ToroStem", x, y + 2.6, z, 2.2, 2.8, 2.2, "px_smooth_stone", STONE, f)
	cube("ToroSeat", x, y + 4.4, z, 3.6, 0.8, 3.6, "px_stone_bricks", STONE, f)
	cube("ToroBox", x, y + 6, z, 3, 2.4, 3, "px_smooth_stone", STONE, f)
	local glow = decor(part("ToroGlow", Vector3.new(3.2, 1.3, 1.3), at(x, y + 6, z), LANTERN_GLOW, Enum.Material.Neon, f))
	decor(part("ToroGlow", Vector3.new(1.3, 1.3, 3.2), at(x, y + 6, z), LANTERN_GLOW, Enum.Material.Neon, f))
	cube("ToroRoof", x, y + 7.7, z, 4.6, 1, 4.6, "px_stone_bricks", DARKER, f)
	cube("ToroRoofTop", x, y + 8.6, z, 2.6, 0.8, 2.6, "px_stone_bricks", DARKER, f)
	cube("ToroKnob", x, y + 9.4, z, 1.2, 0.8, 1.2, "px_smooth_stone", STONE, f)
	if lit then
		warm(glow, 24, 1)
	end
	return f
end
-- a paper lantern hanging on a cord from hangTop (local y)
local function paperLantern(x, y, z, parent, hangTop, lit, color)
	local body = textured(decor(part("PaperLantern", Vector3.new(2.2, 2.8, 2.2), at(x, y, z), nil, nil, parent)), "px_white_wool", color or PAPER)
	decor(part("LanternRim", Vector3.new(1.6, 0.4, 1.6), at(x, y + 1.6, z), DARK_WOOD, Enum.Material.Wood, parent))
	decor(part("LanternRim", Vector3.new(1.6, 0.4, 1.6), at(x, y - 1.6, z), DARK_WOOD, Enum.Material.Wood, parent))
	if hangTop and hangTop > y + 1.8 then
		decor(part("LanternCord", Vector3.new(0.25, hangTop - y - 1.8, 0.25), at(x, (hangTop + y + 1.8) / 2, z), Color3.fromRGB(40, 36, 34), Enum.Material.Fabric, parent))
	end
	if lit then
		warm(body, 22, 1)
	end
	return body
end
-- a square dark roof with raised tips: y = its base (top of the posts), s = half the main roof
local function squareRoof(cx, y, cz, s, parent)
	local T = "px_roof_tiles"
	box("Eave", cx - s - 2, y, cz - s - 2, cx + s + 2, y + 1.5, cz + s + 2, T, ROOF_DARK, parent)
	box("Roof", cx - s, y + 1.5, cz - s, cx + s, y + 4.5, cz + s, T, ROOF_DARK, parent)
	box("RoofTop", cx - s / 2, y + 4.5, cz - s / 2, cx + s / 2, y + 7.5, cz + s / 2, T, ROOF_DARK, parent)
	box("RoofCrown", cx - 2, y + 7.5, cz - 2, cx + 2, y + 9.5, cz + 2, "px_blackstone", nil, parent)
	for _, c in ipairs(CORNERS) do
		-- each corner climbs out in two blocks: the curved tip of the concept
		local tx, tz = cx + c[1] * (s + 2), cz + c[2] * (s + 2)
		box("RoofTip", tx - 2, y + 1.5, tz - 2, tx + 2, y + 4, tz + 2, T, ROOF_DARK, parent)
		local ux, uz = cx + c[1] * (s + 3.5), cz + c[2] * (s + 3.5)
		box("RoofTipEnd", ux - 1.5, y + 3.5, uz - 1.5, ux + 1.5, y + 6, uz + 1.5, T, ROOF_DARK, parent)
	end
end
-- a cherry tree of blocks: a crooked trunk, a leafy skirt, a pink wool core, a cap, loose lumps and drips, petals below
local function cherry(x, z, y, parent, h)
	h = h or rng:NextInteger(3, 4) * B
	local f = folder("CherryTree", parent)
	local trunkV = if rng:NextNumber() < 0.5 then "px_cherry_log" else "px_dark_oak_log"
	box("Trunk", x - 2, y, z - 2, x + 2, y + h, z + 2, trunkV, nil, f)
	local d = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
	box("Branch", x - 2 + d[1] * 4, y + h - 4, z - 2 + d[2] * 4, x + 2 + d[1] * 4, y + h, z + 2 + d[2] * 4, trunkV, nil, f)
	box("Root", x - 2 - d[1] * 4, y, z - 2 - d[2] * 4, x + 2 - d[1] * 4, y + 1.5, z + 2 - d[2] * 4, trunkV, nil, f)
	local cy = y + h
	local ox, oz = d[1] * 2, d[2] * 2 -- the crown leans over the branch
	box("CrownSkirt", x + ox - 14, cy - 2, z + oz - 14, x + ox + 14, cy + 2, z + oz + 14, "px_cherry_leaves", nil, f)
	box("CrownCore", x + ox - 10, cy + 2, z + oz - 10, x + ox + 10, cy + 10, z + oz + 10, "px_white_wool", SAKURA, f)
	box("CrownCap", x + ox - 6, cy + 10, z + oz - 6, x + ox + 6, cy + 14, z + oz + 6, "px_cherry_leaves", nil, f)
	local spots = { -8, -4, 0, 4, 8 }
	for i = 1, 4 do
		local side, along = pick({ -12, 12 }), pick(spots)
		local lx, lz = if i % 2 == 0 then side else along, if i % 2 == 0 then along else side
		if i <= 2 then
			box("CrownLump", x + ox + lx - 2, cy + 2, z + oz + lz - 2, x + ox + lx + 2, cy + 6, z + oz + lz + 2, "px_white_wool", SAKURA_DEEP, f)
		else
			box("CrownLump", x + ox + lx - 2, cy + 2, z + oz + lz - 2, x + ox + lx + 2, cy + 6, z + oz + lz + 2, "px_cherry_leaves", nil, f)
		end
	end
	for _ = 1, 2 do
		local lx, lz = pick({ -12, 12 }), pick(spots)
		if rng:NextNumber() < 0.5 then
			lx, lz = lz, lx
		end
		decor(box("CrownDrip", x + ox + lx - 2, cy - 6, z + oz + lz - 2, x + ox + lx + 2, cy - 2, z + oz + lz + 2, "px_cherry_leaves", nil, f))
	end
	-- the petal carpet under the crown (only where the ground is level)
	local r = 12
	for _, c in ipairs(CORNERS) do
		if gy8(x + c[1] * 12, z + c[2] * 12) ~= y then
			r = 6
		end
	end
	decor(box("Petals", x + ox - r, y + 0.06, z + oz - r, x + ox + r, y + 0.36, z + oz + r, "px_white_wool", SAKURA, f))
	return f
end
-- a clump of bamboo: 4..6 stalks (4..8 blocks tall) with a node band and leaf tufts on top
local function bambooClump(x, z, y, parent)
	local f = folder("Bamboo", parent)
	local slots = {}
	for _, a in ipairs({ -2.8, 0, 2.8 }) do
		for _, b in ipairs({ -2.8, 0, 2.8 }) do
			table.insert(slots, { a, b })
		end
	end
	local n = rng:NextInteger(4, 6)
	local tallest, tx, tz = 0, x, z
	for i = 1, n do
		local k = rng:NextInteger(i, #slots)
		slots[i], slots[k] = slots[k], slots[i]
		local sx, sz = x + slots[i][1], z + slots[i][2]
		local h = rng:NextInteger(4, 8) * B
		box("BambooStalk", sx - 1.2, y, sz - 1.2, sx + 1.2, y + h, sz + 1.2, "px_hedge", BAMBOO, f)
		decor(box("BambooNode", sx - 1.35, y + h * 0.55, sz - 1.35, sx + 1.35, y + h * 0.55 + 0.5, sz + 1.35, "px_hedge", Color3.fromRGB(120, 170, 80), f))
		if h > tallest then
			tallest, tx, tz = h, sx, sz
		end
	end
	decor(box("BambooLeaves", tx - 4, y + tallest - 2, tz - 4, tx + 4, y + tallest + 2, tz + 4, "px_hedge", Color3.fromRGB(116, 170, 84), f))
	decor(box("BambooLeaves", x - 2, y + tallest - 8, z - 2, x + 2, y + tallest - 4, z + 2, "px_hedge", Color3.fromRGB(130, 186, 92), f))
	return f
end
-- a torii: axis "x" = the gate spans along x (walk through along z); span = post centre to post centre
local function torii(cx, cz, y, span, h, axis, parent)
	local f = folder("Torii", parent)
	local function tb(name, a0, y0, b0, a1, y1, b1, v, t)
		if axis == "x" then
			return box(name, cx + a0, y + y0, cz + b0, cx + a1, y + y1, cz + b1, v, t, f)
		end
		return box(name, cx + b0, y + y0, cz + a0, cx + b1, y + y1, cz + a1, v, t, f)
	end
	local hs = span / 2
	for _, s in ipairs({ -1, 1 }) do
		tb("ToriiFoot", s * hs - 1.7, 0, -1.7, s * hs + 1.7, 1.5, 1.7, "px_blackstone", nil)
		tb("ToriiPost", s * hs - 1.2, 1.5, -1.2, s * hs + 1.2, h, 1.2, RED_V, TORII_RED)
		tb("ToriiTip", s * (hs + 3.5) - 1.5, h + 2.4, -1.6, s * (hs + 3.5) + 1.5, h + 3.4, 1.6, "px_blackstone", nil)
	end
	tb("ToriiNuki", -hs - 2.5, h - 4, -0.8, hs + 2.5, h - 2.8, 0.8, RED_V, TORII_RED)
	tb("ToriiKasagi", -hs - 3.5, h, -1.4, hs + 3.5, h + 1.4, 1.4, RED_V, TORII_RED)
	tb("ToriiTop", -hs - 5, h + 1.4, -1.6, hs + 5, h + 2.4, 1.6, "px_blackstone", nil)
	tb("ToriiPlaque", -1, h - 2.8, -0.5, 1, h, 0.5, "px_blackstone", nil)
	return f
end
-- a red wooden fence span from (ax, az) to (bx, bz) at y: end posts (shared joints kept in `posts`) and two rails
local function redFence(ax, az, bx, bz, y, parent, posts)
	for _, p in ipairs({ { ax, az }, { bx, bz } }) do
		local key = ("%.2f,%.2f"):format(p[1], p[2])
		if not posts[key] then
			posts[key] = true
			box("FencePost", p[1] - 0.7, y, p[2] - 0.7, p[1] + 0.7, y + 5, p[2] + 0.7, RED_V, TORII_RED, parent)
			box("FenceCap", p[1] - 0.9, y + 5, p[2] - 0.9, p[1] + 0.9, y + 5.6, p[2] + 0.9, "px_blackstone", nil, parent)
		end
	end
	for _, h in ipairs({ 1.6, 3.8 }) do
		textured(beam("FenceRail", V(ax, y + h, az), V(bx, y + h, bz), 0.7, nil, parent), RED_V, TORII_RED)
	end
end
-- a sitting stone fox (kitsune) with a red bib on a plinth; cf at the ground, the fox looks along -Z of cf
local function foxStatue(cf, parent)
	local f = folder("FoxStatue", parent)
	local FOX = Color3.fromRGB(222, 220, 214)
	lp(cf, "FoxPlinth", 4, 2.4, 4, 0, 1.2, 0, "px_stone_bricks", STONE, f)
	lp(cf, "FoxBody", 2.6, 2.8, 3, 0, 3.8, 0.4, "px_smooth_stone", FOX, f)
	lp(cf, "FoxChest", 2.2, 2.6, 1.4, 0, 4.5, -1.4, "px_smooth_stone", FOX, f)
	lp(cf, "FoxHead", 2.2, 2, 2.2, 0, 6.8, -1.2, "px_smooth_stone", FOX, f)
	lp(cf, "FoxSnout", 1.2, 1, 1.2, 0, 6.5, -2.9, "px_smooth_stone", FOX, f)
	for _, s in ipairs({ -1, 1 }) do
		decor(lp(cf, "FoxEar", 0.7, 1.2, 0.7, s * 0.7, 8.4, -1, "px_smooth_stone", FOX, f))
	end
	decor(lp(cf, "FoxBib", 2.4, 1, 1.6, 0, 5.3, -1.5, RED_V, TORII_RED, f))
	lp(cf, "FoxTail", 1.4, 3.2, 1.4, 0.9, 4.6, 2.2, "px_smooth_stone", FOX, f)
	decor(lp(cf, "FoxTailTip", 1.2, 1, 1.2, 0.9, 6.7, 2.2, "px_white_wool", WHITE, f))
	return f
end
-- a machiya (dark-wood town house / tea house) on x0..x1, z0..z1 at ground y: the front (+Z) is an open shop with a
-- noren curtain, paper lanterns and a sign; dark wood below, paper panels above, a stepped dark roof with raised tips
local function machiya(x0, z0, x1, z1, y, parent, signText, curtain, lanternColor)
	local f = folder("Machiya", parent)
	local DW, DP, T = "px_dark_oak_planks", "px_dark_oak_log", "px_roof_tiles"
	local yf = y + 1
	local xc, zc = (x0 + x1) / 2, (z0 + z1) / 2
	box("HouseBase", x0, y, z0, x1, yf, z1, "px_cobblestone", STONE, f)
	box("HouseFloor", x0 + 1, yf, z0 + 1, x1 - 1, yf + 0.2, z1 - 1, "px_spruce_planks", nil, f)
	local function wall(ax0, az0, ax1, az1)
		box("WallLow", ax0, yf, az0, ax1, yf + 3, az1, DW, nil, f)
		box("WallPaper", ax0, yf + 3, az0, ax1, yf + 9, az1, "px_white_wool", PAPER, f)
		box("WallBeam", ax0, yf + 9, az0, ax1, yf + 10, az1, DW, nil, f)
	end
	wall(x0, z0, x1, z0 + 1)
	wall(x0, z0 + 1, x0 + 1, z1)
	wall(x1 - 1, z0 + 1, x1, z1)
	-- the shoji grid on the side walls
	for _, sx in ipairs({ x0 - 0.15, x1 + 0.15 }) do
		decor(box("ShojiRail", sx - 0.2, yf + 5.8, z0 + 1, sx + 0.2, yf + 6.3, z1 - 1, DW, nil, f))
		for zz = z0 + 4, z1 - 4, 4 do
			decor(box("ShojiBar", sx - 0.2, yf + 3, zz - 0.25, sx + 0.2, yf + 9, zz + 0.25, DW, nil, f))
		end
	end
	-- the front: lattice panels at the sides, an open shop between, a lintel and a paper band over it
	box("FrontLattice", x0 + 1, yf, z1 - 1, x0 + 4, yf + 7, z1, "px_spruce_planks", DARK_WOOD, f)
	box("FrontLattice", x1 - 4, yf, z1 - 1, x1 - 1, yf + 7, z1, "px_spruce_planks", DARK_WOOD, f)
	box("Lintel", x0 + 1, yf + 7, z1 - 1, x1 - 1, yf + 8, z1, DP, nil, f)
	box("FrontPaper", x0 + 1, yf + 8, z1 - 1, x1 - 1, yf + 9, z1, "px_white_wool", PAPER, f)
	box("FrontBeam", x0 + 1, yf + 9, z1 - 1, x1 - 1, yf + 10, z1, DW, nil, f)
	for _, c in ipairs(CORNERS) do
		local px, pz = if c[1] > 0 then x1 else x0, if c[2] > 0 then z1 else z0
		box("HousePost", px - 0.7, y, pz - 0.7, px + 0.7, yf + 10, pz + 0.7, DP, nil, f)
	end
	-- the noren: three cloth strips under the lintel, a white mon on the middle one
	local ow = (x1 - x0 - 8) / 3
	for i = 0, 2 do
		local nx0 = x0 + 4 + i * ow
		decor(box("Noren", nx0 + 0.1, yf + 4.5, z1 - 0.6, nx0 + ow - 0.1, yf + 7, z1 - 0.4, "px_white_wool", curtain, f))
	end
	decor(box("NorenMon", xc - 0.8, yf + 5.2, z1 - 0.38, xc + 0.8, yf + 6.6, z1 - 0.3, "px_white_wool", WHITE, f))
	-- inside: a counter, a shelf with sake jars, a barrel
	box("Counter", x0 + 5, yf, z0 + 8, x1 - 5, yf + 3, z0 + 10, "px_spruce_planks", nil, f)
	box("CounterTop", x0 + 4.7, yf + 3, z0 + 7.7, x1 - 4.7, yf + 3.4, z0 + 10.3, DW, nil, f)
	box("Shelf", x0 + 2, yf + 4, z0 + 1, x1 - 2, yf + 4.5, z0 + 3, DW, nil, f)
	for jx = x0 + 4, x1 - 4, 4 do
		decor(box("Jar", jx - 0.8, yf + 4.5, z0 + 1.2, jx + 0.8, yf + 6.3, z0 + 2.8, "px_white_wool", WHITE, f))
	end
	barrel(x0 + 3.5, yf, z0 + 4, f)
	-- the roof: a wide eave, two stepped layers, a dark ridge with raised ends, raised eave corners
	local yr = yf + 10
	box("Eave", x0 - 3, yr, z0 - 3, x1 + 3, yr + 1.5, z1 + 3, T, ROOF_DARK, f)
	box("Roof", x0 - 2, yr + 1.5, z0 + 1, x1 + 2, yr + 4.5, z1 - 1, T, ROOF_DARK, f)
	box("RoofUpper", x0 - 1, yr + 4.5, z0 + 5, x1 + 1, yr + 7.5, z1 - 5, T, ROOF_DARK, f)
	box("Ridge", x0 - 2, yr + 7.5, zc - 2, x1 + 2, yr + 9, zc + 2, "px_blackstone", nil, f)
	for _, s in ipairs({ -1, 1 }) do
		local ex = if s < 0 then x0 - 2.5 else x1 + 2.5
		box("RidgeTip", ex - 1.5, yr + 8, zc - 1.5, ex + 1.5, yr + 10.5, zc + 1.5, "px_blackstone", nil, f)
	end
	for _, c in ipairs(CORNERS) do
		local tx, tz = if c[1] > 0 then x1 + 2 else x0 - 2, if c[2] > 0 then z1 + 2 else z0 - 2
		box("EaveTip", tx - 2, yr + 1.5, tz - 2, tx + 2, yr + 3, tz + 2, T, ROOF_DARK, f)
	end
	-- lanterns at the front corners, one lit; the sign over the shop
	paperLantern(x0 + 2.5, yf + 5.5, z1 + 1.6, f, yr, true, lanternColor)
	paperLantern(x1 - 2.5, yf + 5.5, z1 + 1.6, f, yr, false, lanternColor)
	local board = box("ShopSign", xc - 4, yf + 7.9, z1, xc + 4, yf + 9.5, z1 + 0.4, DW, nil, f)
	boardText(board, signText)
	return f
end
-- free ground for a tree / prop in the hill zone at terrace height y
local function okSpot(x, z, y, pad)
	if zoneOf(x, z) ~= "hill" or not freeGround(x, z, pad or 0) or reserved(x, z, pad or 0) then
		return false
	end
	for _, d in ipairs({ { 0, 0 }, { 3, 0 }, { -3, 0 }, { 0, 3 }, { 0, -3 } }) do
		if gy8(x + d[1], z + d[2]) ~= y then
			return false
		end
	end
	return true
end

-- the reserved footprints (paths, houses, garden, stairs, the temple's landing, the shrines)
reserve(-186, -38, 18, -14) -- the L1 path
reserve(-184, -38, -160, -6) -- the west stair approach
reserve(-72, -62, 10, -36) -- the machiya
reserve(-176, -72, -100, -38) -- the zen garden and the veranda
reserve(12, -44, 56, -4) -- the main stair landing (temple part)
reserve(-36, -142, 56, -114) -- the L2 path to the temple court
reserve(-38, -190, -8, -156) -- the fox shrine
reserve(8, -108, 34, -84) -- the bell tower
reserve(-30, -110, -6, -86) -- the weapon rack and the targets
reserve(-8, -158, 8, -146) -- the katana stand
local WEST_PATH = { { -140, -147 }, { -158, -128 }, { -160, -104 }, { -152, -90 } }
for i = 1, #WEST_PATH - 1 do
	local a, b = WEST_PATH[i], WEST_PATH[i + 1]
	table.insert(RES, { a[1], a[2], b[1], b[2], 10, true }) -- a segment: {ax, az, bx, bz, radius, true}
end

-- ================================================================ 1. the boss arena
do
	local arena = folder("Arena", hill)
	local AX, AZ, Y = ARENA.x, ARENA.z, L2_Y
	local RING_C = Color3.fromRGB(150, 148, 146)
	-- 1a. the retaining platform: where the round terrace hangs over L1 (the south rim) stone fills up to y 32
	-- (the notch x -100..-76 south of z -72 stays open for the arena stair)
	layRuns("ArenaFooting", AX - 64, AZ - 64, 32, 32, B, 0, Y, function(cx, cz)
		local rr = math.sqrt((cx - AX) ^ 2 + (cz - AZ) ^ 2)
		if rr > 61 or (cx > -100 and cx < -76 and cz > -72) then
			return nil
		end
		local gy = gy8(cx, cz)
		if gy >= Y then
			return nil
		end
		return "px_stone_bricks", Color3.fromRGB(138, 136, 134), gy, Y
	end, arena)
	-- 1b. the wooden floor laid flush (y 31.8..32.1) on the stone in runs along x
	layRuns("ArenaFloor", AX - 56, AZ - 56, 28, 28, B, Y - 0.2, Y + 0.1, function(cx, cz, ix, iz)
		local dx, dz = cx - AX, cz - AZ
		local rr = math.sqrt(dx * dx + dz * dz)
		if rr >= 56 then
			return nil
		end
		if rr >= 50 then
			if openPerp(dx, dz) < 8 then
				return "px_spruce_planks", nil -- the plank paths entering through the stone ring
			end
			return "px_smooth_stone", RING_C
		end
		local th = math.atan2(dz, dx)
		if rr < 32 then
			-- the mon: five red petals (discs at r 17 pointing north first) split by white gaps, a white rim, a white
			-- heart with a pink stamen
			if rr < 5 then
				return RED_V, SAKURA_DEEP
			end
			if rr < 8 then
				return RED_V, WHITE
			end
			local petal, gap = math.huge, math.huge
			for k = 0, 4 do
				local a = k * 2 * math.pi / 5 - math.pi / 2
				petal = math.min(petal, math.sqrt((dx - math.cos(a) * 17) ^ 2 + (dz - math.sin(a) * 17) ^ 2))
				local ux, uz = math.cos(a + math.pi / 5), math.sin(a + math.pi / 5)
				if dx * ux + dz * uz > 0 then
					gap = math.min(gap, math.abs(-dx * uz + dz * ux))
				end
			end
			if petal < 10.5 and gap >= 2.5 then
				return RED_V, TORII_RED
			end
			if petal < 14.5 then
				return RED_V, WHITE
			end
		end
		if rr >= 47 then
			return "px_dark_oak_planks", nil
		end
		if rr >= 43 then
			return RED_V, if (ix + iz) % 2 == 0 then TORII_RED else WHITE
		end
		if rr >= 39.5 then
			return RED_V, TORII_RED -- the red border ring
		end
		if rr >= 34 and rr < 37.5 and math.floor((th + math.pi) / (math.pi / 10)) % 2 == 0 then
			return "px_cherry_planks", nil
		end
		return "px_spruce_planks", nil
	end, arena)
	task.wait()

	-- 1c. four red pillars on the diagonals (r 34): black base, red shaft, a dark roof with raised tips, two lanterns
	for _, c in ipairs(CORNERS) do
		local px, pz = AX + c[1] * 24, AZ + c[2] * 24
		pillarTag(box("PillarBase", px - 6, Y, pz - 6, px + 6, Y + 4, pz + 6, "px_blackstone", nil, arena))
		pillarTag(box("Pillar", px - 4, Y + 4, pz - 4, px + 4, Y + 24, pz + 4, RED_V, TORII_RED, arena))
		decor(box("PillarBand", px - 4.3, Y + 20, pz - 4.3, px + 4.3, Y + 21, pz + 4.3, "px_blackstone", nil, arena))
		box("PillarBracket", px - 6, Y + 24, pz - 6, px + 6, Y + 26, pz + 6, "px_dark_oak_planks", nil, arena)
		squareRoof(px, Y + 26, pz, 8, arena)
		for i, l in ipairs({ { c[1], -c[2] }, { -c[1], c[2] } }) do
			paperLantern(px + l[1] * 10, Y + 21.5, pz + l[2] * 10, arena, Y + 26, i == 1)
		end
	end

	-- 1d. the red fence ring r 58 (posts every 2 blocks, 2 rails), cut at the three openings
	local posts, ring = {}, {}
	local N = 45
	for k = 0, N - 1 do
		local a = (k + 0.5) / N * 2 * math.pi
		local dx, dz = math.cos(a) * 58, math.sin(a) * 58
		if openPerp(dx, dz) >= OPEN_HALF and onIsland(AX + dx, AZ + dz, 4) then
			ring[k] = { AX + dx, AZ + dz }
		end
	end
	for k = 0, N - 1 do
		local a, b = ring[k], ring[(k + 1) % N]
		if a and b then
			redFence(a[1], a[2], b[1], b[2], Y, arena, posts)
		end
	end
	-- stone lanterns flank every opening on the stone ring
	for _, deg in ipairs(OPENINGS) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		for i, s in ipairs({ -1, 1 }) do
			stoneLantern(AX + ux * 52 - uz * s * 17, Y, AZ + uz * 52 + ux * s * 17, arena, i == 1)
		end
	end
	task.wait()

	-- 1e. outside the fence: nobori banners, the training corner, the katana stand
	for _, deg in ipairs({ 20, 340, 300 }) do
		local a = math.rad(deg)
		local x, z = AX + math.cos(a) * 64, AZ + math.sin(a) * 64
		if gy8(x, z) == Y and onIsland(x, z, 10) then
			box("NoboriFoot", x - 1.5, Y, z - 1.5, x + 1.5, Y + 1.5, z + 1.5, "px_stone_bricks", STONE, arena)
			box("NoboriPole", x - 0.4, Y + 1.5, z - 0.4, x + 0.4, Y + 17, z + 0.4, "px_dark_oak_log", nil, arena)
			local cf = CFrame.lookAt(V(x, Y + 10, z), V(AX, Y + 10, AZ)) * CFrame.new(2, 0, 0)
			banner(cf, WHITE, arena, TORII_RED, 3, 10)
		end
	end
	do
		local f = folder("WeaponRack", arena)
		local cf = at(-20, Y, -98) * CFrame.Angles(0, math.pi / 2, 0) -- faces west, to the arena
		lp(cf, "RackBase", 13, 0.8, 3, 0, 0.4, 0, "px_dark_oak_planks", nil, f)
		for _, s in ipairs({ -1, 1 }) do
			lp(cf, "RackPost", 1, 8, 1, s * 6, 4.8, 0, "px_dark_oak_log", nil, f)
		end
		lp(cf, "RackBar", 13, 0.8, 1, 0, 8.2, 0, "px_dark_oak_planks", nil, f)
		lp(cf, "RackBar", 13, 0.8, 1, 0, 3.4, 0, "px_dark_oak_planks", nil, f)
		local STEEL = Color3.fromRGB(196, 200, 206)
		for i, wx in ipairs({ -4.2, -1.4, 1.4, 4.2 }) do
			decor(lp(cf, "Spear", 0.45, 10, 0.45, wx, 5.8, -0.9, "px_dark_oak_planks", nil, f))
			local blade = decor(lp(cf, "SpearBlade", 0.5, if i == 2 then 2.8 else 1.8, if i == 2 then 0.8 else 0.3, wx, if i == 2 then 12.2 else 11.7, -0.9, nil, STEEL, f))
			blade.Material = Enum.Material.Metal
			decor(lp(cf, "Tassel", 0.7, 0.7, 0.7, wx, 10.6, -0.9, RED_V, TORII_RED, f))
		end
		-- two straw targets (makiwara) beside the rack
		for _, tz in ipairs({ -106, -90 }) do
			box("TargetPost", -15, Y, tz - 0.6, -13.8, Y + 4, tz + 0.6, "px_dark_oak_log", nil, f)
			box("TargetStraw", -16.4, Y + 3, tz - 1, -12.4, Y + 8, tz + 1, "px_hay", nil, f)
			decor(box("TargetBand", -16.6, Y + 5.2, tz - 1.1, -12.2, Y + 5.8, tz + 1.1, RED_V, TORII_RED, f))
		end
	end
	do
		local f = folder("KatanaStand", arena)
		local cf = at(0, Y, -152) * CFrame.Angles(0, math.pi, 0) -- faces south, to the path
		lp(cf, "StandBase", 7, 1, 2.4, 0, 0.5, 0, "px_dark_oak_planks", nil, f)
		for _, s in ipairs({ -1, 1 }) do
			lp(cf, "StandArm", 0.8, 3.8, 1, s * 2.6, 2.9, 0, "px_dark_oak_planks", nil, f)
		end
		for _, h in ipairs({ 2.6, 4 }) do
			decor(lp(cf, "Scabbard", 7.4, 0.5, 0.6, 0.6, h, -0.6, nil, Color3.fromRGB(26, 22, 24), f))
			decor(lp(cf, "Hilt", 2.2, 0.55, 0.65, -4.2, h, -0.6, RED_V, TORII_RED, f))
			decor(lp(cf, "Tsuba", 0.3, 1, 1, -3, h, -0.6, nil, Color3.fromRGB(200, 160, 60), f))
		end
	end

	-- 1f. the fox shrine north-east of the arena: a stone plinth, a small hokora, an offering box, a fox pair, a torii
	do
		local sh = folder("FoxShrine", arena)
		local sx, sz = -24, -178
		box("ShrinePlinth", sx - 8, Y, sz - 8, sx + 8, Y + 1, sz + 6, "px_stone_bricks", STONE, sh)
		box("Hokora", sx - 4, Y + 1, sz - 6, sx + 4, Y + 7, sz + 1, "px_dark_oak_planks", nil, sh)
		for _, s in ipairs({ -1, 1 }) do
			box("HokoraPost", sx + s * 4 - 0.6, Y + 1, sz + 0.6, sx + s * 4 + 0.6, Y + 7.5, sz + 1.8, RED_V, TORII_RED, sh)
		end
		box("HokoraLintel", sx - 4.6, Y + 7, sz + 0.6, sx + 4.6, Y + 8, sz + 1.8, RED_V, TORII_RED, sh)
		decor(box("HokoraDoor", sx - 2.6, Y + 1.6, sz + 1, sx + 2.6, Y + 6, sz + 1.3, "px_white_wool", PAPER, sh))
		squareRoof(sx, Y + 8, sz - 2.5, 5, sh)
		box("OfferingBox", sx - 2.5, Y + 1, sz + 2.5, sx + 2.5, Y + 3.4, sz + 5, "px_dark_oak_planks", nil, sh)
		decor(box("OfferingSlats", sx - 2.2, Y + 3.4, sz + 2.8, sx + 2.2, Y + 3.7, sz + 4.7, "px_spruce_planks", nil, sh))
		paperLantern(sx, Y + 5.2, sz + 3.6, sh, Y + 8, true, TORII_RED)
		for _, s in ipairs({ -1, 1 }) do
			foxStatue(at(sx + s * 8, Y, sz + 10) * CFrame.Angles(0, math.pi + s * 0.25, 0), sh)
		end
		torii(sx, sz + 16, Y, 12, 11, "x", sh)
		for _, b in ipairs({ { -36, -192 }, { -26, -195 }, { -14, -193 } }) do
			if gy8(b[1], b[2]) == Y and onIsland(b[1], b[2], 10) then
				bambooClump(b[1], b[2], Y, sh)
			end
		end
	end
end
task.wait()

-- ================================================================ 2. the stairs: arena stair L1 → L2, west stair L0 → L1
do
	local st = folder("Stairs", hill)
	local WALL_C = Color3.fromRGB(132, 130, 128)
	-- stepped side walls 4 studs wide, one segment per 8 studs of run, 2.5 studs over the steps
	local function sideWalls(xa, xb, zStart, dir, y0, name)
		for i = 0, 3 do
			local za, zb = zStart + dir * 8 * i, zStart + dir * 8 * (i + 1)
			local top = y0 + 4 * (i + 1) + 2.5
			for _, wx in ipairs({ xa, xb }) do
				box(name, wx, y0, za, wx + 4, top, zb, "px_stone_bricks", WALL_C, st)
				box(name .. "Cap", wx - 0.3, top, za, wx + 4.3, top + 0.6, zb, "px_smooth_stone", STONE, st)
			end
		end
	end
	stairs("ArenaStair", (ARENA_STAIR.x0 + ARENA_STAIR.x1) / 2, ARENA_STAIR.z0, ARENA_STAIR.z1, L1_Y, L2_Y - L1_Y, ARENA_STAIR.x1 - ARENA_STAIR.x0, "px_stone_bricks", st)
	sideWalls(ARENA_STAIR.x0 - 4, ARENA_STAIR.x1, ARENA_STAIR.z0, -1, L1_Y, "ArenaStairWall")
	torii(-88, -38, L1_Y, 20, 14, "x", st)
	stairs("WestStair", (WEST_STAIR.x0 + WEST_STAIR.x1) / 2, WEST_STAIR.z0, WEST_STAIR.z1, 0, L1_Y, WEST_STAIR.x1 - WEST_STAIR.x0, "px_stone_bricks", st)
	sideWalls(WEST_STAIR.x0 - 4, WEST_STAIR.x1, WEST_STAIR.z0, -1, 0, "WestStairWall")
	stoneLantern(WEST_STAIR.x0 - 6, L1_Y, WEST_STAIR.z1 - 4, st, true)
	stoneLantern(WEST_STAIR.x1 + 6, L1_Y, WEST_STAIR.z1 - 4, st, false)
end
task.wait()

-- ================================================================ 3. the L1 terrace: the path, the zen garden, the machiya
do
	local l1 = folder("Terrace", hill)
	local Y = L1_Y
	-- 3a. the gravel path with stone edges: the main band z -36..-16 from x -180 to the main stair landing (x 16), the
	-- approach to the west stair top and the spur to the arena stair
	layRuns("Path", -184, -40, 50, 8, B, Y - 0.2, Y + 0.1, function(cx, cz)
		local onMain = cz > -36 and cz < -16 and cx > -180 and cx < 16
		local onApproach = cx > -180 and cx < -164 and cz > -36 and cz < -8
		local onSpur = cx > -96 and cx < -80 and cz > -40 and cz < -36
		if not (onMain or onApproach or onSpur) or gy8(cx, cz) ~= Y then
			return nil
		end
		local edge
		if onApproach and cz > -16 then
			edge = cx < -176 or cx > -168
		elseif onSpur then
			edge = cx < -92 or cx > -84
		else
			edge = (cz < -32 and not (cx > -96 and cx < -80)) or (cz > -20 and not (cx > -180 and cx < -164))
		end
		if edge then
			return "px_stone_bricks", STONE
		end
		return "px_gravel", Color3.fromRGB(214, 208, 198)
	end, l1)
	-- stone lanterns along the path: the north edge between the houses and by the garden, the south edge on the rim
	local li = 0
	for _, p in ipairs({ { -156, -38 }, { -124, -38 }, { -44, -38 }, { -16, -38 }, { -150, -13 }, { -120, -13 }, { -60, -13 }, { -30, -13 }, { -2, -13 } }) do
		if gy8(p[1], p[2]) == Y and gy8(p[1], p[2] + 2) == Y then
			li += 1
			stoneLantern(p[1], Y, p[2], l1, li % 2 == 1)
		end
	end
	-- petals blown onto the path
	for _ = 1, 12 do
		local x, z = rng:NextInteger(-44, 2) * B, rng:NextInteger(-9, -5) * B
		if gy8(x, z) == Y then
			decor(box("PathPetals", x, Y + 0.1, z, x + rng:NextInteger(1, 2) * B, Y + 0.3, z + B, "px_white_wool", SAKURA, l1))
		end
	end
	task.wait()

	-- 3b. the dry zen garden x -168..-112, z -68..-40: raked rows (2-stud strips), rings round three black rock piles
	-- standing on moss; a plaster wall with a dark tile coping west and north, a low curb south, a tea veranda east
	do
		local g = folder("ZenGarden", l1)
		local GX0, GZ0 = -168, -68
		local ROCKS = { { -152, -56, 12 }, { -134, -48, 10 }, { -122, -60, 8 } }
		local RAKE_L, RAKE_D = Color3.fromRGB(246, 244, 236), Color3.fromRGB(214, 212, 204)
		layRuns("RakedGravel", GX0, GZ0, 28, 14, 2, Y - 0.2, Y + 0.1, function(cx, cz, _, iz)
			if gy8(cx, cz) ~= Y then
				return nil
			end
			for _, r in ipairs(ROCKS) do
				local d = math.sqrt((cx - r[1]) ^ 2 + (cz - r[2]) ^ 2)
				if d < 5.5 then
					return "px_hedge", MOSS, Y - 0.2, Y + 0.2
				end
				if d < r[3] then
					if math.floor(d / 2) % 2 == 0 then
						return "px_sand", RAKE_L
					end
					return "px_gravel", RAKE_D
				end
			end
			if iz % 2 == 0 then
				return "px_sand", RAKE_L
			end
			return "px_gravel", RAKE_D
		end, g)
		-- the rock piles (stepped blackstone and coal blocks)
		box("Rock", -156, Y, -60, -148, Y + 4, -52, "px_blackstone", nil, g)
		box("Rock", -156, Y + 4, -60, -152, Y + 8, -56, "px_coal_block", nil, g)
		box("Rock", -155, Y + 8, -59, -153, Y + 10, -57, "px_blackstone", nil, g)
		box("Rock", -148, Y, -56, -144, Y + 2, -52, "px_coal_block", nil, g)
		box("Rock", -138, Y, -52, -130, Y + 3, -44, "px_blackstone", nil, g)
		box("Rock", -136, Y + 3, -50, -132, Y + 7, -46, "px_coal_block", nil, g)
		box("Rock", -124, Y, -62, -120, Y + 4, -58, "px_blackstone", nil, g)
		box("Rock", -120, Y, -61, -117, Y + 2, -58, "px_coal_block", nil, g)
		-- the plaster walls with a tile coping (the north one only where L1 reaches it, the cliff stands elsewhere)
		local PLASTER = Color3.fromRGB(236, 228, 212)
		local function gardenWall(x0, z0, x1, z1, alongX)
			box("GardenWallBase", x0, Y, z0, x1, Y + 2, z1, "px_stone_bricks", STONE, g)
			box("GardenWall", x0, Y + 2, z0, x1, Y + 6, z1, "px_white_wool", PLASTER, g)
			if alongX then
				box("WallCoping", x0, Y + 6, z0 - 0.6, x1, Y + 7, z1 + 0.6, "px_roof_tiles", ROOF_DARK, g)
				box("WallRidge", x0, Y + 7, z0 + 1, x1, Y + 7.8, z1 - 1, "px_blackstone", nil, g)
			else
				box("WallCoping", x0 - 0.6, Y + 6, z0, x1 + 0.6, Y + 7, z1, "px_roof_tiles", ROOF_DARK, g)
				box("WallRidge", x0 + 1, Y + 7, z0, x1 - 1, Y + 7.8, z1, "px_blackstone", nil, g)
			end
		end
		gardenWall(-172, -68, -168, -40, false)
		local runX = nil
		for x = -172, -100, 8 do
			local okCell = x < -104 and gy8(x + 4, -70) == Y and gy8(x + 4, -66) == Y
			if okCell then
				runX = runX or x
			elseif runX then
				gardenWall(runX, -72, x, -68, true)
				runX = nil
			end
		end
		box("GardenCurb", -168, Y, -41, -112, Y + 0.8, -40, "px_smooth_stone", STONE, g)
		-- the tea veranda: a low deck under a stepped pent roof, a paper wall behind, cushions and a tea table
		local VX0, VX1 = -112, -104
		box("VerandaDeck", VX0, Y, -66, VX1, Y + 1.6, -42, "px_dark_oak_planks", nil, g)
		for _, pz in ipairs({ -65, -54, -43 }) do
			box("VerandaPost", VX0, Y + 1.6, pz - 0.6, VX0 + 1.2, Y + 10.6, pz + 0.6, "px_dark_oak_log", nil, g)
		end
		box("VerandaWallLow", VX1 - 1, Y + 1.6, -66, VX1, Y + 3.6, -42, "px_dark_oak_planks", nil, g)
		box("VerandaPaper", VX1 - 1, Y + 3.6, -66, VX1, Y + 9.6, -42, "px_white_wool", PAPER, g)
		box("VerandaBeam", VX1 - 1, Y + 9.6, -66, VX1, Y + 10.6, -42, "px_dark_oak_planks", nil, g)
		box("VerandaEave", VX0 - 2.5, Y + 10.6, -69, VX1 + 1, Y + 12, -39, "px_roof_tiles", ROOF_DARK, g)
		box("VerandaRoof", VX0 + 0.5, Y + 12, -68, VX1 + 0.5, Y + 14.5, -40, "px_roof_tiles", ROOF_DARK, g)
		box("VerandaRoofTop", VX0 + 4, Y + 14.5, -67, VX1, Y + 16.5, -41, "px_roof_tiles", ROOF_DARK, g)
		for _, tz in ipairs({ -69, -42 }) do
			box("VerandaTip", VX0 - 3, Y + 12, tz, VX0 + 0.5, Y + 13.5, tz + 3, "px_roof_tiles", ROOF_DARK, g)
		end
		box("TeaTable", -110, Y + 1.6, -56, -107, Y + 2.8, -52, "px_dark_oak_planks", nil, g)
		for _, cz in ipairs({ -59, -49 }) do
			decor(box("Cushion", -110.4, Y + 1.6, cz - 1, -107.6, Y + 2.1, cz + 1, RED_V, TORII_RED, g))
		end
		paperLantern(VX0 - 1, Y + 7, -54, g, Y + 10.6, true)
	end
	task.wait()

	-- 3c. three machiya along the north of the path, fronts facing south; a stone step in front of each
	do
		local houses = folder("Machiya", l1)
		local INDIGO = Color3.fromRGB(44, 54, 96)
		for _, h in ipairs({
			{ -68, "Чайная", INDIGO, nil },
			{ -40, "Саке", TORII_RED, TORII_RED },
			{ -12, "Сладости", INDIGO, nil },
		}) do
			local x0 = h[1]
			machiya(x0, -60, x0 + 20, -40, Y, houses, h[2], h[3], h[4])
			box("HouseStep", x0 + 4, Y - 0.2, -40, x0 + 16, Y + 0.1, -36, "px_smooth_stone", STONE, houses)
		end
	end
	task.wait()

	-- 3d. cherry trees on L1 (first), then the bamboo grove in the north-west round them
	do
		local trees = folder("Trees", l1)
		for _, p in ipairs({ { -204, -44 }, { -196, -20 }, { -208, -28 }, { -150, -12 }, { -126, -12 }, { -96, -12 }, { -60, -12 }, { -30, -12 }, { 0, -12 }, { -180, -56 } }) do
			if okSpot(p[1], p[2], Y, 1) then
				cherry(p[1], p[2], Y, trees)
				reserve(p[1] - 8, p[2] - 8, p[1] + 8, p[2] + 8)
			end
		end
		local grove = folder("BambooGrove", l1)
		for cz = -64, -24, 8 do
			for cx = -216, -192, 8 do
				if rng:NextNumber() < 0.6 and okSpot(cx, cz, Y, 1) then
					bambooClump(cx, cz, Y, grove)
				end
			end
		end
	end
end
task.wait()

-- ================================================================ 4. the west of L2: the path to the temple court, the cliff path, the bell, trees
do
	local l2 = folder("TopTerrace", hill)
	local Y = L2_Y
	-- 4a. the path from the arena east opening to the temple court (x 48): gravel with cobble edges, 5 blocks wide
	layRuns("TopPath", -32, -138, 20, 5, B, Y - 0.2, Y + 0.1, function(cx, cz, _, iz)
		if (cx - ARENA.x) ^ 2 + (cz - ARENA.z) ^ 2 < 56 ^ 2 or gy8(cx, cz) ~= Y then
			return nil
		end
		if iz == 0 or iz == 4 then
			return "px_cobblestone", STONE
		end
		return "px_gravel", Color3.fromRGB(214, 208, 198)
	end, l2)
	for i, p in ipairs({ { -8, -142 }, { 28, -142 }, { -8, -114 }, { 28, -114 } }) do
		if gy8(p[1], p[2]) == Y then
			stoneLantern(p[1], Y, p[2], l2, i == 1 or i == 4)
		end
	end
	-- 4b. the cliff path from the west-north-west opening to an overlook over the zen garden
	layRuns("CliffPath", -176, -160, 12, 20, B, Y - 0.2, Y + 0.1, function(cx, cz)
		if (cx - ARENA.x) ^ 2 + (cz - ARENA.z) ^ 2 < 56.5 ^ 2 or gy8(cx, cz) ~= Y or not onIsland(cx, cz, 6) then
			return nil
		end
		for i = 1, #WEST_PATH - 1 do
			local a, b = WEST_PATH[i], WEST_PATH[i + 1]
			if segDist(cx, cz, a[1], a[2], b[1], b[2]) < 7 then
				return "px_gravel", Color3.fromRGB(206, 200, 190)
			end
		end
		return nil
	end, l2)
	do
		local ov = folder("Overlook", l2)
		-- a red fence along the rim of L2 above the garden (found per island cell)
		local posts, prev = {}, nil
		for cx = -164, -140, 8 do
			local zr = nil
			for cz = -100, -52, 8 do
				if gy8(cx, cz) < Y then
					zr = cz - 4
					break
				end
			end
			if zr then
				local fz = zr - 1.2
				redFence(cx - 4, fz, cx + 4, fz, Y, ov, posts)
				if prev and prev ~= fz then
					redFence(cx - 4, prev, cx - 4, fz, Y, ov, posts)
				end
				prev = fz
			else
				prev = nil
			end
		end
		box("BenchSeat", -158, Y + 1.6, -95, -150, Y + 2.4, -92.6, "px_dark_oak_planks", nil, ov)
		for _, bx in ipairs({ -157, -151 }) do
			box("BenchLeg", bx - 0.6, Y, -94.4, bx + 0.6, Y + 1.6, -93.2, "px_dark_oak_planks", nil, ov)
		end
		stoneLantern(-146, Y, -96, ov, true)
	end
	-- 4c. the bell tower (shōrō) north of the temple path
	do
		local f = folder("BellTower", l2)
		local bx, bz = 21, -96
		local BRONZE = Color3.fromRGB(170, 120, 62)
		box("BellBase", bx - 8, Y, bz - 8, bx + 8, Y + 1.5, bz + 8, "px_stone_bricks", STONE, f)
		for _, c in ipairs(CORNERS) do
			box("BellPost", bx + c[1] * 5 - 0.8, Y + 1.5, bz + c[2] * 5 - 0.8, bx + c[1] * 5 + 0.8, Y + 14, bz + c[2] * 5 + 0.8, RED_V, TORII_RED, f)
		end
		box("BellBeam", bx - 6.5, Y + 13, bz - 1, bx + 6.5, Y + 14, bz + 1, "px_dark_oak_planks", nil, f)
		box("BellBeam", bx - 1, Y + 13.1, bz - 6.5, bx + 1, Y + 13.9, bz + 6.5, "px_dark_oak_planks", nil, f)
		squareRoof(bx, Y + 14, bz, 6, f)
		box("BellCrown", bx - 1, Y + 11.5, bz - 1, bx + 1, Y + 13, bz + 1, "px_iron_block", BRONZE, f)
		box("Bell", bx - 2, Y + 7, bz - 2, bx + 2, Y + 11.5, bz + 2, "px_iron_block", BRONZE, f)
		box("BellLip", bx - 2.6, Y + 6.2, bz - 2.6, bx + 2.6, Y + 7.2, bz + 2.6, "px_iron_block", BRONZE, f)
		decor(box("BellStriker", bx + 3, Y + 8.5, bz - 0.5, bx + 10, Y + 9.5, bz + 0.5, "px_dark_oak_log", nil, f))
		decor(box("StrikerRope", bx + 6.3, Y + 9.5, bz - 0.15, bx + 6.7, Y + 13, bz + 0.15, nil, Color3.fromRGB(200, 180, 140), f))
	end
	task.wait()
	-- 4d. cherry trees round the arena and along the top terrace
	do
		local trees = folder("Trees", l2)
		for _, p in ipairs({
			{ -40, -198 },
			{ -4, -198 },
			{ 24, -186 },
			{ 40, -152 },
			{ 42, -110 },
			{ -2, -102 },
			{ 8, -170 },
			{ -58, -196 },
			{ -150, -100 },
			{ -176, -116 },
			{ -168, -150 },
			{ -24, -78 },
			{ 0, -82 },
			{ -128, -72 },
		}) do
			if okSpot(p[1], p[2], Y, 2) and (p[1] - ARENA.x) ^ 2 + (p[2] - ARENA.z) ^ 2 > 64 ^ 2 then
				cherry(p[1], p[2], Y, trees, rng:NextInteger(3, 5) * B)
				reserve(p[1] - 8, p[2] - 8, p[1] + 8, p[2] + 8)
			end
		end
	end
end
task.wait()

-- ================================================================ 5. the cliffs: moss plates, leafy lips and vine curtains
do
	local greens = folder("CliffGreens", hill)
	local VINE = Color3.fromRGB(100, 150, 72)
	for cz = -244, -12, 8 do
		for cx = -244, 52, 8 do
			local near = (cx - ARENA.x) ^ 2 + (cz - ARENA.z) ^ 2 < 66 ^ 2
			if not near and zoneOf(cx, cz) == "hill" and onIsland(cx, cz, 12) and not inStairCorridor(cx, cz) then
				local y = groundY(cx, cz)
				for _, d in ipairs({ { 0, 1 }, { 1, 0 }, { -1, 0 }, { 0, -1 } }) do
					local nx, nz = cx + d[1] * 8, cz + d[2] * 8
					local ly = groundY(nx, nz)
					local drop = y - ly
					if drop >= 12 and onIsland(nx, nz, 12) and not inStairCorridor(nx, nz) and zoneOf(nx, nz) ~= "temple" and rng:NextNumber() < 0.35 then
						local fx, fz = cx + d[1] * 4, cz + d[2] * 4 -- the face plane
						local tx, tz = math.abs(d[2]), math.abs(d[1]) -- along the face
						-- the leafy lip on the rim
						local lip = decor(part("CliffLip", Vector3.new(tx * 8 + math.abs(d[1]) * 2.4, 0.3, tz * 8 + math.abs(d[2]) * 2.4), at(fx - d[1] * 0.8, y + 0.15, fz - d[2] * 0.8), nil, nil, greens))
						textured(lip, "px_hedge", VINE)
						-- three vine strips of ragged length hanging 0.6 off the face
						for _, off in ipairs({ -2.66, 0, 2.66 }) do
							if rng:NextNumber() < 0.8 then
								local len = math.min(drop - 2, rng:NextInteger(2, 7) * 2)
								local v = decor(part("Vines", Vector3.new(tx * 2.6 + math.abs(d[1]) * 0.4, len, tz * 2.6 + math.abs(d[2]) * 0.4), at(fx + d[1] * 0.8 + tx * off, y - len / 2, fz + d[2] * 0.8 + tz * off), nil, nil, greens))
								textured(v, "px_hedge", VINE)
							end
						end
						-- a moss plate lower on the face
						if rng:NextNumber() < 0.5 then
							local w, h = rng:NextInteger(1, 2) * 4, rng:NextInteger(1, 2) * 4
							local off = if w < 8 then pick({ -2, 2 }) else 0
							local yc = ly + h / 2 + rng:NextInteger(0, math.max(0, math.floor((drop - h - 6) / 2))) * 2
							local m = decor(part("Moss", Vector3.new(tx * w + math.abs(d[1]) * 0.3, h, tz * w + math.abs(d[2]) * 0.3), at(fx + d[1] * 0.35 + tx * off, yc, fz + d[2] * 0.35 + tz * off), nil, nil, greens))
							textured(m, pick({ "px_mossy_cobblestone", "px_mossy_stone_bricks" }))
						end
					end
				end
			end
		end
	end
end
print(("[build-kyoto] hill: %d parts, %d point lights left"):format(count - startCount, lightsLeft))
