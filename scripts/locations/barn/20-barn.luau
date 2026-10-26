--!nocheck
-- ================================================================ barn: the hero barn and its sides (zone "barn")
-- The same red barn as on the farm floor, decades later. Footprint BARN x -52..52, z -72..4: walls 7 blocks (y 0..28)
-- of faded red / brown planks in patches with missing boards, dark oak log corner posts, frame lines and top plate,
-- a white-grey eave trim; big doorways 6 blocks wide and 6 high at x -12..12 in the SOUTH wall (z 0..4, facing the
-- mine) and the NORTH wall (z -72..-68, facing the arena), the leaves swung inward; the aisle x -10..10 runs clear
-- from door to door. The gambrel roof (ridge north-south, stepped layers y 28..56, half-widths HW) is caved in over
-- the north-east (inHole: x -2..46, z ≈ -64..-12): broken rafters stick out of the ragged hole, slabs hang from its
-- edges, shingles lie on the floor. The east wall's north part leans out (the sagging north-east corner), the north
-- wall's east end is broken. Boarded windows with cobwebs; a decorative loft door with a hay hook and a pulley rope in
-- the south gable; the sign «Амбар» over the south door.
-- The tree through the roof: rooted at BARN.tree (16, -32), trunk 3×3 blocks (x 10..22) to y 20, then 2×2 to y 64,
-- roots east / north / south (never west, into the aisle), branches over the roof, an orange crown y 56..82,
-- x ≈ -16..48. Inside: plank patches over the podzol, the hay loft along the west wall (x -48..-26, floor y 16) with a
-- ladder at (-25, -44), four broken stalls under it, an SE stall, hay with candles, jack o'lanterns, a rusty cart,
-- chains and lanterns hanging from the tie beams, cobwebs, crows. Outside (x ±52..70, z -80..-72): a collapsed lean-to
-- on the east (x 52..70, z -64..-22), a broken trough, hay and a junk heap on the west, a lamp post by the north door,
-- lanterns by the south door, pumpkins, weeds, vines and moss on the walls, ravens on the ridge.
local barn = folder("BarnHero")
local partsBefore = count
local WALL_H = 28
local HW = { 54, 50, 46, 38, 28, 16, 6 } -- the roof's outer half-width per 4-stud layer (layer i at y 28 + 4i)
local TRIM = Color3.fromRGB(206, 200, 188)
local LOG = "px_dark_oak_log"
local WALL_TINTS = {
	BARN_RED,
	Color3.fromRGB(176, 88, 74), -- faded red
	Color3.fromRGB(124, 56, 44), -- dark red
	Color3.fromRGB(122, 88, 66), -- brown
	Color3.fromRGB(154, 108, 88), -- weathered
	Color3.fromRGB(150, 122, 96), -- a replacement board (spruce)
}

-- the caved-in part of the roof (plan x, z)
local function inHole(x, z)
	if x < -2 then
		return false
	end
	local d = ((x - 22) / 24) ^ 2 + ((z + 38) / 27) ^ 2
	return d + n2(x, z, 9.1, 0.11) * 0.45 < 1
end
-- a frame on a wall face: local X along the wall, local Z out of the wall (`out` studs from the face `plane`)
local function faceCF(face, a, y, plane, out)
	if face == "S" then
		return at(a, y, plane + out)
	elseif face == "N" then
		return at(a, y, plane - out)
	elseif face == "E" then
		return at(plane + out, y, a) * CFrame.Angles(0, math.pi / 2, 0)
	end
	return at(plane - out, y, a) * CFrame.Angles(0, math.pi / 2, 0)
end
-- a flat decor plate on a wall face from a0..a1 (x on N/S faces, z on W/E), `out` studs thick
local function fp(name, face, a0, y0, a1, y1, plane, out, variant, tint, parent)
	local p = part(name, Vector3.new(math.abs(a1 - a0), y1 - y0, out), faceCF(face, (a0 + a1) / 2, (y0 + y1) / 2, plane, out / 2), tint, nil, parent or barn)
	if variant then
		textured(p, variant, tint)
	end
	return decor(p)
end
-- a rotated textured box by centre, size and angles
local function rbox(name, x, y, z, sx, sy, sz, rx, ry, rz, variant, tint, parent)
	local p = part(name, Vector3.new(sx, sy, sz), at(x, y, z) * CFrame.Angles(rx, ry, rz), tint, nil, parent or barn)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- a pumpkin standing on (x, y, z) with its face toward (tx, tz); mode "lit" (glowing face + light), "dim" (dark carved
-- face) or "plain" (no face)
local function jack(x, y, z, tx, tz, mode, parent, s)
	s = s or B
	parent = parent or barn
	local cf = at(x, y, z) * CFrame.Angles(0, math.atan2(-(tx - x), -(tz - z)), 0)
	local h = s * 0.85
	local tint = if mode == "plain" and rng:NextNumber() < 0.4 then Color3.fromRGB(214, 112, 34) else PUMPKIN
	local body = textured(part("Pumpkin", Vector3.new(s, h, s), cf * CFrame.new(0, h / 2, 0), nil, nil, parent), "px_hay", tint)
	textured(decor(part("PumpkinStem", Vector3.new(s * 0.22, s * 0.3, s * 0.22), cf * CFrame.new(0, h + s * 0.15, 0), nil, nil, parent)), "px_oak_log", Color3.fromRGB(110, 120, 60))
	if mode ~= "plain" then
		local lit = mode == "lit"
		local col = if lit then Color3.fromRGB(255, 200, 90) else Color3.fromRGB(64, 34, 14)
		local mat = if lit then Enum.Material.Neon else Enum.Material.SmoothPlastic
		local fz = -s / 2 - 0.04
		for _, ex in ipairs({ -0.22, 0.22 }) do
			decor(part("JackEye", Vector3.new(s * 0.2, s * 0.18, 0.12), cf * CFrame.new(ex * s, h * 0.64, fz), col, mat, parent))
		end
		decor(part("JackMouth", Vector3.new(s * 0.56, s * 0.14, 0.12), cf * CFrame.new(0, h * 0.3, fz), col, mat, parent))
		if lit then
			light(body, 22, 1.8, Color3.fromRGB(255, 150, 60))
		end
	end
	return body
end
local function candle(x, y, z, h, lit, parent)
	textured(decor(part("Candle", Vector3.new(0.7, h, 0.7), at(x, y + h / 2, z), nil, nil, parent or barn)), "px_white_wool", Color3.fromRGB(240, 228, 196))
	local flame = decor(part("CandleFlame", Vector3.new(0.35, 0.6, 0.35), at(x, y + h + 0.35, z), CANDLE, Enum.Material.Neon, parent or barn))
	if lit then
		light(flame, 16, 1.4, CANDLE)
	end
end
-- a block crow / raven standing on (x, y, z), looking along -Z of its yaw
local function crow(x, y, z, yaw, parent)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local black = Color3.fromRGB(34, 32, 40)
	for _, b in ipairs({
		{ "CrowBody", Vector3.new(1.3, 1.2, 2.2), CFrame.new(0, 0.9, 0), black },
		{ "CrowHead", Vector3.new(1, 1, 1), CFrame.new(0, 1.85, -1), black },
		{ "CrowBeak", Vector3.new(0.35, 0.35, 0.8), CFrame.new(0, 1.7, -1.85), Color3.fromRGB(70, 64, 56) },
		{ "CrowTail", Vector3.new(1, 0.3, 1.4), CFrame.new(0, 1.05, 1.5) * CFrame.Angles(0.35, 0, 0), black },
		{ "CrowLegs", Vector3.new(0.7, 0.3, 0.25), CFrame.new(0, 0.15, 0), Color3.fromRGB(60, 56, 50) },
	}) do
		textured(decor(part(b[1], b[2], cf * b[3], nil, nil, parent or barn)), "px_white_wool", b[4])
	end
end
-- a cobweb: four thin white strands crossed in the XY plane of cf
local function cobweb(cf, s, parent)
	for k = 0, 3 do
		local p = decor(part("Cobweb", Vector3.new(s, 0.12, 0.08), cf * CFrame.Angles(0, 0, k * math.pi / 4), Color3.fromRGB(236, 236, 236), nil, parent or barn))
		p.Transparency = 0.2
		p.CastShadow = false
	end
end
local WEED_TINTS = { Color3.fromRGB(150, 140, 80), Color3.fromRGB(122, 132, 62), Color3.fromRGB(176, 150, 74), Color3.fromRGB(104, 120, 56) }
-- a clump of tall weeds (two crossed blades, one block wide)
local function weeds(x, z, parent, y0)
	local h = rng:NextNumber(2.2, 4.6)
	local tint = pick(WEED_TINTS)
	local yaw = rng:NextNumber(0, math.pi)
	for k = 0, 1 do
		local p = decor(part("Weeds", Vector3.new(3.4, h, 0.15), at(x, (y0 or 0) + h / 2, z) * CFrame.Angles(0, yaw + k * math.pi / 2, 0), nil, nil, parent or barn))
		textured(p, "px_grass_top", tint)
		p.CastShadow = false
	end
end
local function hay(x, y, z, parent)
	return cube("HayBale", x, y + 2, z, B, B, B, "px_hay", nil, parent or barn)
end
-- a chain of links hanging from yTop down to about yBot, with a hook
local function chain(x, z, yTop, yBot, parent)
	local n = math.max(1, math.floor((yTop - yBot) / 1.4))
	for k = 0, n - 1 do
		local p = decor(part("Chain", Vector3.new(0.6, 1.6, 0.22), at(x, yTop - 0.8 - k * 1.4, z) * CFrame.Angles(0, (k % 2) * math.pi / 2, 0), Color3.fromRGB(64, 62, 60), Enum.Material.Metal, parent or barn))
		p.CastShadow = false
	end
	decor(part("ChainHook", Vector3.new(0.3, 1.1, 0.9), at(x, yTop - n * 1.4 - 0.4, z), Color3.fromRGB(58, 56, 54), Enum.Material.Metal, parent or barn))
end
local VINE_TINTS = { Color3.fromRGB(58, 92, 40), Color3.fromRGB(76, 104, 44), Color3.fromRGB(96, 112, 50), Color3.fromRGB(140, 96, 40) }
-- a vine strip one block wide hanging down a wall face from yTop
local function vine(face, a, yTop, len, plane, parent)
	fp("Vine", face, a - 2, yTop - len, a + 2, yTop, plane, 0.55, "px_hedge", pick(VINE_TINTS), parent)
end
-- a two-wheeled cart rusted through, standing at (x, z), its handles toward -Z of the yaw
local function cart(x, z, yaw, parent)
	local f = folder("RustyCart", parent or barn)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, 0.07)
	local wood = Color3.fromRGB(104, 80, 60)
	for _, b in ipairs({
		{ "CartBed", Vector3.new(6, 1, 9), CFrame.new(0, 3, 0), "px_spruce_planks", wood, true },
		{ "CartSide", Vector3.new(0.6, 2.2, 9), CFrame.new(-2.7, 4.6, 0), "px_spruce_planks", wood },
		{ "CartSide", Vector3.new(0.6, 2.2, 9), CFrame.new(3, 4.4, 0) * CFrame.Angles(0, 0, -0.3), "px_spruce_planks", wood },
		{ "CartEnd", Vector3.new(5, 2.2, 0.6), CFrame.new(0, 4.6, 4.2), "px_spruce_planks", wood },
		{ "CartAxle", Vector3.new(7.2, 0.6, 0.6), CFrame.new(0, 2, 1), "px_iron_block", RUST },
		{ "CartWheel", Vector3.new(0.8, 4, 4), CFrame.new(-3.6, 2, 1), "px_iron_block", RUST, true },
		{ "CartWheel", Vector3.new(0.8, 4, 4), CFrame.new(3.6, 2, 1) * CFrame.Angles(0.4, 0, 0), "px_iron_block", RUST, true },
		{ "CartHub", Vector3.new(1, 1.2, 1.2), CFrame.new(-3.6, 2, 1), "px_iron_block", Color3.fromRGB(90, 60, 44) },
		{ "CartHub", Vector3.new(1, 1.2, 1.2), CFrame.new(3.6, 2, 1), "px_iron_block", Color3.fromRGB(90, 60, 44) },
		{ "CartHandle", Vector3.new(0.6, 0.6, 6), CFrame.new(-2.2, 2.4, -6.5) * CFrame.Angles(-0.25, 0, 0), "px_dark_oak_planks" },
		{ "CartHandle", Vector3.new(0.6, 0.6, 6), CFrame.new(2.2, 2.4, -6.5) * CFrame.Angles(-0.25, 0, 0), "px_dark_oak_planks" },
	}) do
		local p = textured(part(b[1], b[2], cf * b[3], nil, nil, f), b[4], b[5])
		if not b[6] then
			decor(p)
		end
	end
	return f
end
-- a stall gate: two stiles, three rails and a brace; hinge at cf, the gate runs along +Z of cf for len studs
local function gate(cf, len, parent)
	local wood = Color3.fromRGB(140, 110, 84)
	for _, b in ipairs({
		{ Vector3.new(0.6, 5.4, 0.8), CFrame.new(0, 2.9, 0.4) },
		{ Vector3.new(0.6, 5.4, 0.8), CFrame.new(0, 2.9, len - 0.4) },
		{ Vector3.new(0.5, 0.6, len), CFrame.new(0, 1.2, len / 2) },
		{ Vector3.new(0.5, 0.6, len), CFrame.new(0, 3.2, len / 2) },
		{ Vector3.new(0.5, 0.6, len), CFrame.new(0, 5.2, len / 2) },
		{ Vector3.new(0.4, 0.6, math.sqrt(len * len + 16)), CFrame.new(0, 3.2, len / 2) * CFrame.Angles(math.atan2(4, len), 0, 0) },
	}) do
		textured(part("StallGate", b[1], cf * b[2], nil, nil, parent or barn), "px_spruce_planks", wood)
	end
end
local inside = folder("BarnInside", barn)

-- ================================================================ the walls: plank patches, gaps, posts, frames
do
	local walls = folder("Walls", barn)
	-- the wall grid: column c (4 studs along the wall), row r (y 4r .. 4r + 4); the value is a tint index (+ 10 per
	-- 2 studs of outward lean), nil = no plank there. Columns 0 and ncols - 1 are the corner posts.
	local function grid(ncols, holes, gaps, lean)
		local g = {}
		local panelTint = {}
		for c = 0, ncols - 1 do
			g[c] = {}
			local p = (c - 1) // 4
			if not panelTint[p] then
				panelTint[p] = pick({ 1, 1, 1, 2, 3, 4, 5, 2 })
			end
			for r = 0, 6 do
				g[c][r] = panelTint[p]
			end
		end
		for p = 0, (ncols - 2) // 4 do
			if rng:NextNumber() < 0.75 then
				local c0 = 1 + p * 4 + rng:NextInteger(0, 2)
				local r0 = rng:NextInteger(0, 5)
				local t = pick({ 2, 3, 4, 5, 6 })
				for c = c0, math.min(c0 + rng:NextInteger(0, 1), ncols - 2) do
					for r = r0, math.min(6, r0 + rng:NextInteger(0, 2)) do
						g[c][r] = t
					end
				end
			end
		end
		for _ = 1, 3 do
			g[rng:NextInteger(1, ncols - 2)][rng:NextInteger(0, 6)] = 6
		end
		for _, h in ipairs(holes) do
			for c = h[1], h[2] do
				for r = h[3], h[4] do
					g[c][r] = nil
				end
			end
		end
		for _ = 1, gaps do
			g[rng:NextInteger(2, ncols - 3)][rng:NextInteger(1, 5)] = nil
		end
		if lean then
			for c = 1, ncols - 2 do
				for r = 0, 6 do
					local o = lean(c, r)
					if g[c][r] and o > 0 then
						g[c][r] += o * 10
					end
				end
			end
		end
		return g
	end
	-- greedy rectangles of equal cells → boxes
	local function build(g, ncols, axis, a0, p0, p1, outSign)
		local used = {}
		for c = 0, ncols - 1 do
			used[c] = {}
		end
		for r = 0, 6 do
			for c = 1, ncols - 2 do
				local k = g[c][r]
				if k and not used[c][r] then
					local c2 = c
					while c2 + 1 <= ncols - 2 and g[c2 + 1][r] == k and not used[c2 + 1][r] do
						c2 += 1
					end
					local r2 = r
					while r2 + 1 <= 6 do
						local ok = true
						for cc = c, c2 do
							if g[cc][r2 + 1] ~= k or used[cc][r2 + 1] then
								ok = false
								break
							end
						end
						if not ok then
							break
						end
						r2 += 1
					end
					for cc = c, c2 do
						for rr = r, r2 do
							used[cc][rr] = true
						end
					end
					local t, off = k % 10, (k // 10) * 2
					local variant = if t == 6 then "px_spruce_planks" else "px_planks"
					local s0, s1 = a0 + c * B, a0 + (c2 + 1) * B
					local q0, q1 = p0 + outSign * off, p1 + outSign * off
					if axis == "x" then
						box("BarnWall", s0, r * B, q0, s1, (r2 + 1) * B, q1, variant, WALL_TINTS[t], walls)
					else
						box("BarnWall", q0, r * B, s0, q1, (r2 + 1) * B, s1, variant, WALL_TINTS[t], walls)
					end
				end
			end
		end
	end
	local DOOR = { 10, 15, 0, 5 } -- x -12..12, y 0..24
	build(grid(26, { DOOR, { 4, 5, 3, 4 }, { 20, 21, 3, 4 } }, 4), 26, "x", -52, 0, 4, 1)
	build(grid(26, { DOOR, { 4, 5, 3, 4 }, { 20, 21, 3, 4 }, { 24, 24, 3, 6 }, { 23, 23, 4, 6 }, { 22, 22, 5, 6 } }, 4), 26, "x", -52, -72, -68, -1)
	build(grid(19, { { 4, 5, 2, 3 }, { 9, 10, 2, 3 }, { 13, 14, 2, 3 }, { 7, 7, 5, 5 } }, 3), 19, "z", -72, -52, -48, -1)
	-- the east wall: its north part (z < -48) leans out east above y 16 (+2 studs, the top row +4)
	build(
		grid(19, { { 4, 5, 3, 4 }, { 13, 14, 3, 4 }, { 8, 10, 5, 6 }, { 9, 9, 4, 4 }, { 7, 7, 6, 6 } }, 4, function(c, r)
			if c > 5 or r < 4 then
				return 0
			end
			return if r == 6 then 2 else 1
		end),
		19,
		"z",
		-72,
		48,
		52,
		1
	)
	-- dark oak log corner posts; the north-east one leans with the wall
	for _, cn in ipairs({ { -52, 0 }, { 48, 0 }, { -52, -72 } }) do
		box("CornerPost", cn[1] - 0.4, 0, cn[2] - 0.4, cn[1] + 4.4, WALL_H + 0.8, cn[2] + 4.4, LOG, nil, walls)
	end
	for _, s in ipairs({ { 0, 16, 0 }, { 16, 24, 2 }, { 24, WALL_H + 0.8, 4 } }) do
		box("CornerPost", 47.6 + s[3], s[1], -72.4, 52.4 + s[3], s[2], -67.6, LOG, nil, walls)
	end
	-- the log top plate and the white-grey eave trim under it
	for _, b in ipairs({ { "S", -48, 48, 4 }, { "N", -48, 36, -72 }, { "W", -68, 0, -52 }, { "E", -28, 0, 52 }, { "E", -68, -48, 56 } }) do
		fp("TopPlate", b[1], b[2], 26, b[3], 28, b[4], 0.35, LOG, nil, walls)
		fp("EaveTrim", b[1], b[2], 25, b[3], 25.8, b[4], 0.3, "px_white_wool", TRIM, walls)
	end
	-- the log mid rails
	for _, b in ipairs({
		{ "S", -48, -13.4, 4, 10 },
		{ "S", 13.4, 48, 4, 10 },
		{ "N", -48, -13.4, -72, 10 },
		{ "N", 13.4, 48, -72, 10 },
		{ "W", -68, 0, -52, 18 },
		{ "E", -68, 0, 52, 10 },
	}) do
		fp("FrameRail", b[1], b[2], b[5], b[3], b[5] + 1, b[4], 0.35, LOG, nil, walls)
	end
	-- the vertical frame lines (face, a, y0, y1, plane)
	for _, s in ipairs({
		{ "S", -36, 0, 26, 4 },
		{ "S", -20, 0, 26, 4 },
		{ "S", 20, 0, 26, 4 },
		{ "S", 36, 0, 26, 4 },
		{ "N", -36, 0, 26, -72 },
		{ "N", -20, 0, 26, -72 },
		{ "N", 20, 0, 26, -72 },
		{ "N", 36, 0, 20, -72 },
		{ "W", -56, 0, 26, -52 },
		{ "W", -40, 0, 26, -52 },
		{ "W", -24, 0, 26, -52 },
		{ "W", -8, 0, 26, -52 },
		{ "E", -24, 0, 26, 52 },
		{ "E", -8, 0, 26, 52 },
		{ "E", -40, 0, 16, 52 },
		{ "E", -56, 0, 16, 52 },
		{ "E", -56, 16, 24, 54 },
		{ "E", -56, 24, 26, 56 },
	}) do
		fp("FramePost", s[1], s[2] - 0.6, s[3], s[2] + 0.6, s[4], s[5], 0.45, LOG, nil, walls)
	end
	-- the doorways: log frames on both faces
	for _, d in ipairs({ { "S", 4, "N", 0 }, { "N", -72, "S", -68 } }) do
		for _, fc in ipairs({ { d[1], d[2] }, { d[3], d[4] } }) do
			fp("DoorPost", fc[1], -13.4, 0, -12, 24, fc[2], 0.5, LOG, nil, walls)
			fp("DoorPost", fc[1], 12, 0, 13.4, 24, fc[2], 0.5, LOG, nil, walls)
			fp("DoorLintel", fc[1], -13.4, 24, 13.4, 25.6, fc[2], 0.5, LOG, nil, walls)
		end
	end
	-- the door leaves (red planks, white frame and X); cf = the leaf centre, its local +X face is the trimmed one
	local function leaf(cf)
		textured(part("BarnDoor", Vector3.new(0.6, 23.2, 12), cf, nil, nil, walls), "px_planks", BARN_RED)
		for _, t in ipairs({
			{ Vector3.new(0.2, 1, 12), CFrame.new(0.4, 11.1, 0) },
			{ Vector3.new(0.2, 1, 12), CFrame.new(0.4, -11.1, 0) },
			{ Vector3.new(0.2, 23.2, 1), CFrame.new(0.4, 0, 5.5) },
			{ Vector3.new(0.2, 23.2, 1), CFrame.new(0.4, 0, -5.5) },
		}) do
			textured(decor(part("DoorTrim", t[1], cf * t[2], nil, nil, walls)), "px_white_wool", TRIM)
		end
		local a, len = math.atan2(21.2, 10), math.sqrt(21.2 ^ 2 + 10 ^ 2)
		for _, sg in ipairs({ 1, -1 }) do
			textured(decor(part("DoorX", Vector3.new(0.2, 1, len), cf * CFrame.new(0.42, 0, 0) * CFrame.Angles(sg * a, 0, 0), nil, nil, walls)), "px_white_wool", TRIM)
		end
	end
	-- south: both leaves swung in along the doorway, the west one sagging off a hinge
	leaf(at(12.5, 12, -6) * CFrame.Angles(0, math.pi, 0))
	leaf(at(-12.5, 11.6, -6.4) * CFrame.Angles(0.07, 0, 0))
	-- north: the east leaf swung in, the west one off its hinges, propped against the wall inside
	leaf(at(12.5, 12, -62) * CFrame.Angles(0, math.pi, 0))
	leaf(at(-18, 11.6, -65.6) * CFrame.Angles(0, -math.pi / 2, 0) * CFrame.Angles(0, 0, 0.12))
	task.wait()

	-- boarded windows: a white-grey frame, boards nailed across, a cobweb in the opening, a loose shutter
	for i, w in ipairs({
		{ "S", -32, 16, 8, 8, 4 },
		{ "S", 32, 16, 8, 8, 4 },
		{ "N", -32, 16, 8, 8, -72 },
		{ "N", 32, 16, 8, 8, -72 },
		{ "W", -52, 12, 8, 8, -52 },
		{ "W", -32, 12, 8, 8, -52 },
		{ "W", -16, 12, 8, 8, -52 },
		{ "W", -42, 22, 4, 4, -52 },
		{ "E", -16, 16, 8, 8, 52 },
		{ "E", -52, 16, 8, 8, 52, true }, -- in the leaning part: no frame
	}) do
		local face, a, yc, ww, wh, plane = w[1], w[2], w[3], w[4], w[5], w[6]
		if not w[7] then
			fp("WindowTrim", face, a - ww / 2 - 0.8, yc - wh / 2 - 0.8, a + ww / 2 + 0.8, yc - wh / 2, plane, 0.3, "px_white_wool", TRIM, walls)
			fp("WindowTrim", face, a - ww / 2 - 0.8, yc + wh / 2, a + ww / 2 + 0.8, yc + wh / 2 + 0.8, plane, 0.3, "px_white_wool", TRIM, walls)
			fp("WindowTrim", face, a - ww / 2 - 0.8, yc - wh / 2, a - ww / 2, yc + wh / 2, plane, 0.3, "px_white_wool", TRIM, walls)
			fp("WindowTrim", face, a + ww / 2, yc - wh / 2, a + ww / 2 + 0.8, yc + wh / 2, plane, 0.3, "px_white_wool", TRIM, walls)
		end
		for k, ang in ipairs({ 0.32, -0.28 }) do
			if k == 1 or i % 3 ~= 0 then
				local board = part("WindowBoard", Vector3.new(ww + 2, 1.2, 0.4), faceCF(face, a, yc + (k - 1.5) * wh * 0.28, plane, 0.75) * CFrame.Angles(0, 0, ang), nil, nil, walls)
				textured(decor(board), pick({ "px_spruce_planks", "px_planks" }), Color3.fromRGB(150, 120, 90))
			end
		end
		cobweb(faceCF(face, a - ww / 2 + 1.6, yc + wh / 2 - 1.6, plane, -2), math.min(ww, 4), walls)
		if i % 2 == 1 and ww >= 8 then
			local sh = part("Shutter", Vector3.new(3.6, wh, 0.3), faceCF(face, a + ww / 2 + 2.6, yc - 0.6, plane, 0.25) * CFrame.Angles(0, 0, 0.16), nil, nil, walls)
			textured(decor(sh), "px_planks", Color3.fromRGB(110, 46, 40))
		end
	end
	-- moss creeping up the foot of the walls, vines hanging from the eaves
	for _, f in ipairs({ { "S", 4, -48, 48 }, { "N", -72, -48, 48 }, { "W", -52, -68, 0 }, { "E", 52, -68, 0 } }) do
		for _ = 1, 5 do
			local a = rng:NextNumber(f[3], f[4] - 8)
			if (f[1] ~= "S" and f[1] ~= "N") or a > 14 or a + 12 < -14 then
				fp("Moss", f[1], a, 0, a + 4 * rng:NextInteger(1, 3), rng:NextInteger(1, 3) * 2, f[2], 0.25, "px_hedge", Color3.fromRGB(88, 112, 52), walls)
			end
		end
	end
	for _, v in ipairs({
		{ "S", -46, 36, 30, 4 },
		{ "S", -42, 30, 12, 4 },
		{ "S", -24, 28, 14, 4 },
		{ "S", 26, 28, 22, 4 },
		{ "S", 30, 24, 8, 4 },
		{ "S", 42, 34, 26, 4 },
		{ "S", 46, 28, 12, 4 },
		{ "N", -44, 28, 18, -72 },
		{ "N", -26, 28, 12, -72 },
		{ "N", 28, 20, 14, -72 },
		{ "N", 40, 16, 10, -72 },
		{ "W", -64, 28, 20, -52 },
		{ "W", -60, 26, 10, -52 },
		{ "W", -44, 28, 12, -52 },
		{ "W", -24, 28, 22, -52 },
		{ "W", -6, 28, 16, -52 },
		{ "E", -12, 28, 18, 52 },
		{ "E", -4, 26, 10, 52 },
		{ "E", -24, 28, 12, 52 },
		{ "E", -60, 14, 10, 52 },
	}) do
		vine(v[1], v[2], v[3], v[4], v[5], walls)
	end
end
task.wait()

-- ================================================================ the gambrel roof, caved in over the north-east
do
	local roof = folder("Roof", barn)
	local ROOF_T = { Color3.fromRGB(96, 88, 96), Color3.fromRGB(78, 70, 74) }
	-- layer i, side s (-1 west, 1 east): the slab's x span
	local function cellX(i, s)
		local a, b = HW[i + 2] or 0, HW[i + 1]
		if s < 0 then
			return -b, -a
		end
		return a, b
	end
	for i = 0, 6 do
		local y0 = WALL_H + 4 * i
		for _, s in ipairs({ -1, 1 }) do
			local xa, xb = cellX(i, s)
			local xc = (xa + xb) / 2
			local runZ, runKey = nil, nil
			local function flush(zEnd)
				if runKey then
					local v, dx = runKey // 10, runKey % 10
					box("BarnRoof", xa + dx, y0, runZ, xb + dx, y0 + 4, zEnd, if v == 1 then "px_roof_tiles" else "px_dark_oak_planks", ROOF_T[v], roof)
				end
				runKey = nil
			end
			local prevHole = false
			for z = -76, 4, 4 do
				local zc = z + 2
				local hole = inHole(xc, zc)
				local key = nil
				if not hole then
					local v = if n2(xc, zc, 2.2, 0.09) > 0.12 then 2 else 1
					local dx = 0
					if s > 0 and zc < -52 and i <= 1 then
						dx = 2 -- the eave sags out with the leaning wall
					end
					key = v * 10 + dx
				end
				if key ~= runKey then
					flush(z)
					if key then
						runZ, runKey = z, key
					end
				end
				-- a slab hanging into the hole from its ragged edge
				if hole ~= prevHole and rng:NextNumber() < 0.4 then
					local edge = z
					local dir = if hole then 1 else -1 -- toward the hole
					local sl = rbox("HangingSlab", xc, y0 + 1.2, edge + dir * 2.2, xb - xa, 1, 4.4, dir * rng:NextNumber(0.4, 0.8), 0, s * rng:NextNumber(-0.15, 0.15), "px_roof_tiles", ROOF_T[1], roof)
					decor(sl)
				end
				prevHole = hole
			end
			flush(8)
		end
	end
	-- the gables (south z 0..4 with the loft door, north z -72..-68): red boards in patches, white-grey edge trim
	for _, g in ipairs({ { 0, 4, "S", 4 }, { -72, -68, "N", -72 } }) do
		for i = 0, 5 do
			local y0 = WALL_H + 4 * i
			local w = HW[i + 2]
			local x = -w
			while x < w do
				local x2 = math.min(w, x + 4 * rng:NextInteger(2, 6))
				if w - x2 < 8 then
					x2 = w
				end
				box("BarnGable", x, y0, g[1], x2, y0 + 4, g[2], "px_planks", WALL_TINTS[pick({ 1, 1, 2, 3, 5 })], roof)
				x = x2
			end
			fp("GableTrim", g[3], -w, y0, -w + 1.2, y0 + 4, g[4], 0.3, "px_white_wool", TRIM, roof)
			fp("GableTrim", g[3], w - 1.2, y0, w, y0 + 4, g[4], 0.3, "px_white_wool", TRIM, roof)
		end
	end
	-- the south loft door (shut behind: a dark opening), one leaf swung out, one hanging off a hinge
	fp("LoftDoorFrame", "S", -6.8, 31.2, 6.8, 44.8, 4, 0.3, "px_white_wool", TRIM, roof)
	fp("LoftDoorDark", "S", -6, 32, 6, 44, 4, 0.4, nil, Color3.fromRGB(30, 22, 18), roof)
	textured(decor(box("LoftDoorLeaf", 6.4, 32, 4.4, 7, 44, 10.4, nil, nil, roof)), "px_planks", BARN_RED)
	textured(decor(part("LoftDoorLeaf", Vector3.new(6, 12, 0.3), faceCF("S", -2.6, 37.4, 4, 0.6) * CFrame.Angles(0, 0, 0.24), nil, nil, roof)), "px_planks", Color3.fromRGB(124, 56, 44))
	-- the hay hook beam over it with a pulley, the rope down and its loose end tied off by the door
	box("HayHookBeam", -0.8, 45.2, 2, 0.8, 46.8, 11.4, LOG, nil, roof)
	decor(part("Pulley", Vector3.new(1.4, 1.4, 1.4), at(0, 44.3, 10.4), Color3.fromRGB(60, 58, 56), Enum.Material.Metal, roof))
	decor(part("PulleyRope", Vector3.new(0.3, 13, 0.3), at(-0.4, 37.2, 10.4), Color3.fromRGB(130, 110, 78), Enum.Material.Fabric, roof))
	decor(beam("PulleyRope", V(0.5, 44, 10.4), V(9, 26, 4.6), 0.3, Color3.fromRGB(130, 110, 78), roof, Enum.Material.Fabric))
	decor(part("HayHook", Vector3.new(0.4, 1.4, 1.2), at(-0.4, 30.2, 10.4), Color3.fromRGB(58, 56, 54), Enum.Material.Metal, roof))
	-- the north attic vent, boarded, with a cobweb
	fp("VentFrame", "N", -4.8, 35.2, 4.8, 44.8, -72, 0.3, "px_white_wool", TRIM, roof)
	fp("VentDark", "N", -4, 36, 4, 44, -72, 0.4, nil, Color3.fromRGB(30, 22, 18), roof)
	textured(decor(part("VentBoard", Vector3.new(9, 1.2, 0.4), faceCF("N", 0, 39, -72, 0.7) * CFrame.Angles(0, 0, 0.4), nil, nil, roof)), "px_spruce_planks", Color3.fromRGB(150, 120, 90))
	cobweb(faceCF("N", 2, 42, -72, 0.6), 3.4, roof)
	-- leaves and moss lying on the roof steps
	for _ = 1, 16 do
		local i = rng:NextInteger(0, 4)
		local s = pick({ -1, 1, 1 })
		local xa, xb = cellX(i, s)
		local x = rng:NextNumber(math.min(xa, xb) + 2, math.max(xa, xb) - 2)
		local z = rng:NextNumber(-72, 2)
		if not inHole(x, z) and not (s > 0 and z < -52 and i <= 1) then
			local tint = pick({ Color3.fromRGB(243, 200, 59), Color3.fromRGB(194, 127, 44), Color3.fromRGB(88, 112, 52) })
			decor(box("RoofLeaves", x - 2, WALL_H + 4 * i + 4, z - 2, x + 2, WALL_H + 4 * i + 4.3, z + 2, if tint.G < 120 then "px_hedge" else "px_cherry_leaves", tint, roof))
		end
	end
	-- the sign «Амбар» hanging crooked over the south doorway
	local board = textured(part("BarnSign", Vector3.new(18, 4, 0.5), at(0, 27.4, 4.9) * CFrame.Angles(0, 0, 0.07), nil, nil, roof), "px_spruce_planks", Color3.fromRGB(120, 92, 66))
	boardText(board, "Амбар", Color3.fromRGB(240, 226, 200), { Enum.NormalId.Back })
	-- ravens on the ridge
	crow(2, 56, 6, math.pi, roof)
	crow(-2.4, 56, 2.4, 2.5, roof)
	crow(1, 56, -73, 0.3, roof)
end
task.wait()

-- ================================================================ rafters, tie beams, chains and hanging lanterns
do
	local frame = folder("Rafters", barn)
	local function rafter(a, b)
		textured(decor(beam("Rafter", a, b, 1, nil, frame)), LOG)
	end
	-- the rafter line under the stepped roof: the inner lower corner of each layer, then the ridge
	local Q = {}
	for i = 0, 5 do
		table.insert(Q, { HW[i + 2], WALL_H + 4 * i })
	end
	table.insert(Q, { 0, WALL_H + 24 })
	for _, z in ipairs({ -62, -52, -42, -32, -22, -12, -2 }) do
		for _, s in ipairs({ -1, 1 }) do
			for i = 1, #Q - 1 do
				local a = V(s * Q[i][1], Q[i][2] - 0.6, z)
				local b = V(s * Q[i + 1][1], Q[i + 1][2] - 0.6, z)
				local mx = s * (Q[i][1] + Q[i + 1][1]) / 2
				if not (z == -32 and s > 0 and Q[i + 1][1] < 21) then -- the trunk
					if inHole(mx, z) then
						local roll = rng:NextNumber()
						if roll < 0.4 then
							rafter(a, b) -- bare over the hole
						elseif roll < 0.78 then
							-- snapped: a stub poking up out of the hole
							rafter(a, a:Lerp(b, rng:NextNumber(0.45, 0.85)) + Vector3.new(0, rng:NextNumber(1.5, 3.5), 0))
						end
					else
						rafter(a, b)
					end
				end
			end
		end
	end
	-- a couple of rafter pieces dangling into the barn from the hole's edge
	rafter(V(38, 35.4, -62), V(35, 27, -60))
	rafter(V(28, 39.4, -12), V(26, 31, -15))
	-- the ridge beam, broken where the roof fell in
	do
		local runZ = nil
		for z = -68, 0, 4 do
			local solid = z < 0 and not inHole(3, z + 2)
			if solid and not runZ then
				runZ = z
			elseif not solid and runZ then
				decor(box("RidgeBeam", -0.8, 50.4, runZ, 0.8, 51.9, z, LOG, nil, frame))
				runZ = nil
			end
		end
	end
	-- tie beams across at the wall top; the middle one snapped, its east half fallen on the floor
	box("TieBeam", -48, 26, -63, 48, 28, -61, LOG, nil, frame)
	box("TieBeam", -48, 26, -13, 48, 28, -11, LOG, nil, frame)
	box("TieBeam", -48, 26, -53, 2, 28, -51, LOG, nil, frame)
	rbox("TieBeamStub", 4.4, 25.6, -52, 5, 1.4, 1.4, 0, 0, -0.45, LOG, nil, frame)
	rbox("FallenBeam", 34, 1.6, -58, 26, 2, 2, 0, 0.25, 0.08, LOG, nil, frame)
	chain(-18, -62, 26, 14, frame)
	chain(30, -62, 26, 10, frame)
	chain(-36, -12, 26, 20, frame)
	chain(4, -12, 26, 17, frame)
	chain(36, -12, 26, 13, frame)
	lantern(V(0, 19, -62), frame, false, BY + 26)
	lantern(V(-3, 19, -12), frame, false, BY + 26)
	crow(-30, 28, -12, 0.4, frame)
end
task.wait()

-- ================================================================ inside: floor, loft, stalls, hay, pumpkins, junk
do
	-- old plank floor in patches over the podzol (flush thin runs; more bare dirt under the hole)
	local floorF = folder("Floor", inside)
	local FLOOR = { { "px_spruce_planks", Color3.fromRGB(150, 120, 92) }, { "px_planks", OLD_WOOD } }
	for z = -68, -4, 4 do
		local runX, runV = nil, nil
		local function flush(xe)
			if runV and xe > runX then
				decor(box("FloorPlanks", runX, 0, z, xe, 0.15, z + 4, FLOOR[runV][1], FLOOR[runV][2], floorF))
			end
			runV = nil
		end
		for x = -48, 40, 8 do
			local cx, cz = x + 4, z + 2
			local n = n2(cx, cz, 5.5, 0.07)
			local v = nil
			local trunk = cx > 6 and cx < 26 and cz > -42 and cz < -22
			if not trunk and n > (if inHole(cx, cz) then 0.2 else -0.28) then
				v = if n2(cx, cz, 6.6, 0.15) > 0.1 then 2 else 1
			end
			if v ~= runV then
				flush(x)
				if v then
					runX, runV = x, v
				end
			end
		end
		flush(48)
	end
	task.wait()

	-- the hay loft along the west wall: floor (a hole broken through), edge joist, posts, a railing, the ladder
	local loft = folder("HayLoft", inside)
	local LOFT_WOOD = Color3.fromRGB(150, 120, 92)
	box("LoftFloor", -48, 15, -68, -26, 16, -18, "px_spruce_planks", LOFT_WOOD, loft)
	box("LoftFloor", -48, 15, -8, -26, 16, 0, "px_spruce_planks", LOFT_WOOD, loft)
	box("LoftFloor", -48, 15, -18, -40, 16, -8, "px_spruce_planks", LOFT_WOOD, loft)
	box("LoftFloor", -32, 15, -18, -26, 16, -8, "px_spruce_planks", LOFT_WOOD, loft)
	decor(rbox("BrokenBoard", -36, 13, -12, 8, 0.6, 2, 0, 0.2, 0.6, "px_spruce_planks", LOFT_WOOD, loft))
	decor(rbox("BrokenBoard", -38, 0.6, -14, 7, 0.5, 2, 0, 0.8, 0.1, "px_spruce_planks", LOFT_WOOD, loft))
	box("LoftJoist", -27, 13.6, -68, -26, 15, 0, LOG, nil, loft)
	for _, z in ipairs({ -52, -36, -20 }) do
		box("LoftPost", -28, 0, z - 1, -26, 15, z + 1, LOG, nil, loft)
	end
	for _, z in ipairs({ -64, -56, -48, -40, -32, -24, -16, -4 }) do
		box("LoftRailPost", -27, 16, z - 0.5, -26, 20, z + 0.5, "px_spruce_planks", LOFT_WOOD, loft)
	end
	for _, r in ipairs({ { -68, -47 }, { -41, -16 }, { -6, 0 } }) do
		box("LoftRail", -26.9, 17.6, r[1], -26.3, 18.2, r[2], "px_spruce_planks", LOFT_WOOD, loft)
		box("LoftRail", -26.9, 19.2, r[1], -26.3, 19.8, r[2], "px_spruce_planks", LOFT_WOOD, loft)
	end
	decor(rbox("LoftRailBroken", -26.6, 16.9, -10, 0.6, 0.6, 8, 0.45, 0, 0, "px_spruce_planks", LOFT_WOOD, loft))
	do
		local truss = Instance.new("TrussPart")
		truss.Name = "LoftLadder"
		truss.Size = Vector3.new(2, 18, 2)
		truss.CFrame = at(-25, 9, -44)
		truss.Anchored = true
		truss.Transparency = 1
		truss.Parent = loft
		local plate = decor(part("LoftLadderFace", Vector3.new(0.2, 16, 4), at(-23.9, 8, -44), nil, nil, loft))
		plate.Transparency = 1
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = Enum.NormalId.Right
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end
	-- the loft: hay along the wall, candles on a bale, a lit jack o'lantern, a cobweb under the roof, a crow
	decor(box("LoftHay", -48, 16, -68, -30, 16.3, -48, "px_hay", nil, loft))
	for _, h in ipairs({ { -46, 16, -64 }, { -46, 16, -60 }, { -46, 16, -56 }, { -46, 20, -62 }, { -46, 20, -58 }, { -42, 16, -62 }, { -46, 16, -30 }, { -46, 16, -26 }, { -46, 20, -28 }, { -42, 16, -28 } }) do
		hay(h[1], h[2], h[3], loft)
	end
	candle(-41, 20, -61, 1.4, true, loft)
	candle(-42.7, 20, -62.9, 1, false, loft)
	candle(-41.3, 20, -63.3, 0.8, false, loft)
	candle(-41.2, 20, -27, 1.2, false, loft)
	jack(-34, 16, -60, 0, -60, "lit", loft)
	jack(-44, 16, -40, 0, -40, "dim", loft, 3)
	cobweb(at(-45, 25, -65) * CFrame.Angles(0, math.pi / 4, 0), 6, loft)
	crow(-26.5, 20, -30, -math.pi / 2, loft)
	task.wait()

	-- four stalls under the loft (partitions x -48..-28), gates broken in turn, hay on the floor
	local stalls = folder("Stalls", inside)
	local STALL_WOOD = Color3.fromRGB(140, 112, 86)
	box("StallWall", -48, 0, -52.5, -28, 8, -51.5, "px_spruce_planks", STALL_WOOD, stalls)
	box("StallWall", -48, 0, -36.5, -28, 8, -35.5, "px_spruce_planks", STALL_WOOD, stalls)
	box("StallWall", -48, 0, -20.5, -36, 8, -19.5, "px_spruce_planks", STALL_WOOD, stalls)
	box("StallWall", -36, 0, -20.5, -28, 3, -19.5, "px_spruce_planks", STALL_WOOD, stalls)
	decor(rbox("StallBoard", -31, 4.2, -20, 7, 1, 0.6, 0, 0, 0.45, "px_spruce_planks", STALL_WOOD, stalls))
	for _, s in ipairs({ { -67.5, -52.5 }, { -51.5, -36.5 }, { -35.5, -20.5 }, { -19.5, 0 } }) do
		decor(box("StallHay", -48, 0.15, s[1], -28.5, 0.35, s[2], "px_hay", nil, stalls))
	end
	gate(at(-27.5, 0, -66), 12, stalls) -- shut
	gate(at(-27.5, 0, -50.5) * CFrame.Angles(0, 0.9, 0) * CFrame.Angles(0.1, 0, 0), 12, stalls) -- swung open, sagging
	gate(at(-24.2, 0.3, -34) * CFrame.Angles(0, 0.12, 0) * CFrame.Angles(0, 0, -math.pi / 2), 12, stalls) -- fallen
	box("Trough", -47, 0, -66, -43, 2.4, -58, "px_spruce_planks", STALL_WOOD, stalls)
	decor(box("TroughWater", -46.4, 2.4, -65.4, -43.6, 2.5, -58.6, nil, Color3.fromRGB(52, 64, 56), stalls))
	jack(-38, 0, -62, 0, -62, "plain", stalls)
	jack(-40, 0, -44, 0, -44, "dim", stalls)
	crate(-44, 0, -40, stalls, 3, 0.3)
	rbox("TippedBarrel", -42, 2, -28, B, B, B, math.pi / 2, 0.4, 0, "px_spruce_planks", Color3.fromRGB(150, 110, 80), stalls)
	cobweb(at(-46, 6, -34) * CFrame.Angles(0, math.pi / 4, 0), 4, stalls)
	hay(-44, 0, -14, stalls)
	hay(-44, 0, -10, stalls)
	hay(-44, 4, -12, stalls)
	jack(-36, 0, -6, 0, -6, "dim", stalls)
	cobweb(at(-46, 12, -2) * CFrame.Angles(0, -math.pi / 4, 0), 4, stalls)
	task.wait()

	-- the strip west of the aisle: a hay stack with candles and a lit jack, the rusty cart, barrels and crates
	local west = folder("WestSide", inside)
	for _, h in ipairs({ { -20, 0, -16 }, { -16, 0, -16 }, { -20, 0, -12 }, { -16, 0, -12 }, { -18, 4, -14 } }) do
		hay(h[1], h[2], h[3], west)
	end
	candle(-15, 4, -11, 1.4, true, west)
	candle(-21, 4, -11.2, 1, false, west)
	candle(-15.2, 4, -17, 0.9, false, west)
	jack(-18, 8, -14, 0, -14, "lit", west)
	cart(-18, -5, math.pi / 2, west)
	jack(-18, 3.5, -5, 0, -5, "dim", west, 3)
	barrel(-15, 0, -30, west)
	crate(-15, 0, -36, west)
	jack(-16, 0, -58, 0, -58, "lit", west)
	crate(-22, 0, -60, west, 3, 0.5)

	-- the east side: lit jacks by the roots, the south-east stall, junk in the north-east corner, debris under the hole
	local east = folder("EastSide", inside)
	jack(25, 0, -18, 0, -18, "lit", east)
	jack(23, 0, -47, 0, -47, "lit", east)
	jack(16, 0, -6, 0, -6, "lit", east)
	jack(15, 0, -60, 0, -60, "dim", east, 3)
	box("StallWall", 30, 0, -16.5, 48, 8, -15.5, "px_spruce_planks", STALL_WOOD, east)
	decor(box("StallHay", 30.5, 0.15, -15.5, 48, 0.35, 0, "px_hay", nil, east))
	gate(at(30, 0, -14) * CFrame.Angles(0.12, 0, 0), 12, east)
	for _, h in ipairs({ { 44, 0, -12 }, { 44, 0, -8 }, { 40, 0, -12 }, { 44, 4, -10 } }) do
		hay(h[1], h[2], h[3], east)
	end
	candle(39, 4, -11, 1.4, true, east)
	candle(41, 4, -13, 1, false, east)
	candle(45, 8, -9, 1.2, false, east)
	jack(40, 0, -5, 0, -5, "lit", east)
	cobweb(at(46, 24, -2) * CFrame.Angles(0, math.pi / 4, 0), 5, east)
	crate(20, 0, -4, east)
	crate(24, 0, -4, east, 3, 0.4)
	barrel(26, 0, -10, east)
	crate(44, 0, -64, east)
	crate(40, 0, -64, east, 3, 0.6)
	barrel(46, 0, -52, east)
	jack(36, 0, -64, 30, -40, "dim", east)
	cobweb(at(46, 24, -66) * CFrame.Angles(0, -math.pi / 4, 0), 5, east)
	crow(40, 3.6, -57, 1.2, east)
	-- under the hole: fallen shingles, leaves and weeds on the floor
	local placed = 0
	for _ = 1, 80 do
		if placed >= 30 then
			break
		end
		local x, z = rng:NextNumber(24, 46), rng:NextNumber(-64, -16)
		if not (x < 38 and z > -50 and z < -20) and not (z > -62 and z < -54 and x < 48) then
			placed += 1
			if placed <= 14 then
				local sz = pick({ { 4, 8 }, { 8, 4 }, { 4, 4 } })
				decor(rbox("FallenShingles", x, 0.6, z, sz[1], 1, sz[2], rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, math.pi), rng:NextNumber(-0.25, 0.25), pick({ "px_roof_tiles", "px_dark_oak_planks" }), Color3.fromRGB(90, 82, 88), east))
			elseif placed <= 22 then
				decor(box("FallenLeaves", x - 2, 0.15, z - 2, x + 2, 0.4, z + 2, "px_cherry_leaves", pick({ Color3.fromRGB(243, 200, 59), Color3.fromRGB(194, 127, 44) }), east))
			else
				weeds(x, z, east)
			end
		end
	end
	-- weeds and moss along the inner walls
	for _, w in ipairs({ { -46, -30 }, { -46, -46 }, { 46, -30 }, { 46, -24 }, { 46, -44 }, { -24, -66 }, { 24, -66 }, { 34, -2 }, { -30, -2 } }) do
		weeds(w[1], w[2], inside)
	end
end
task.wait()

-- ================================================================ the old tree growing up through the roof
do
	local t = folder("RoofTree", barn)
	local tx, tz = BARN.tree.x, BARN.tree.z
	box("TreeTrunk", tx - 6, 0, tz - 6, tx + 6, 20, tz + 6, LOG, nil, t)
	box("TreeTrunk", tx - 4, 20, tz - 4, tx + 4, 64, tz + 4, LOG, nil, t)
	box("TreeTrunk", tx - 2, 64, tz - 2, tx + 2, 74, tz + 2, LOG, nil, t)
	-- buttresses and roots breaking the floor (east, north, south — the aisle side stays clear)
	for _, r in ipairs({
		{ 6, 0, -2, 10, 8, 2 },
		{ -2, 0, -10, 2, 6, -6 },
		{ -2, 0, 6, 2, 6, 10 },
		{ 10, 0, -2, 18, 3, 2 },
		{ 18, 0, -1, 26, 1.6, 3 },
		{ -2, 0, -18, 2, 3, -10 },
		{ 0, 0, -24, 4, 1.6, -18 },
		{ -2, 0, 10, 2, 3, 14 },
		{ 0, 0, 14, 4, 1.6, 20 },
		{ 6, 0, -10, 10, 2.4, -6 },
		{ 10, 0, -14, 14, 1.4, -10 },
		{ 6, 0, 6, 10, 2.4, 10 },
	}) do
		box("TreeRoot", tx + r[1], r[2], tz + r[3], tx + r[4], r[5], tz + r[6], LOG, nil, t)
	end
	decor(box("RootDirt", tx + 6, 0, tz - 6, tx + 14, 0.8, tz + 6, "px_dirt", PODZOL, t))
	decor(box("RootDirt", tx - 4, 0, tz + 6, tx + 6, 0.6, tz + 12, "px_dirt", PODZOL, t))
	decor(box("RootDirt", tx - 4, 0, tz - 14, tx + 8, 0.6, tz - 6, "px_dirt", PODZOL, t))
	for _, b in ipairs({ { 12, 0.8, 5, 0.4, 0.3 }, { 4, 0.9, -12, -0.5, 0.35 }, { 9, 0.7, 12, 1.1, -0.3 }, { 20, 0.6, 5, 0.2, 0.25 } }) do
		decor(rbox("BrokenPlank", tx + b[1], b[2], tz + b[3], 6, 0.4, 3, 0, b[4], b[5], "px_spruce_planks", Color3.fromRGB(150, 120, 92), t))
	end
	-- branches spreading over the roof (one block thick, stepping up)
	for _, r in ipairs({
		{ 4, 52, -2, 16, 56, 2 },
		{ 16, 56, -2, 24, 60, 2 },
		{ -16, 56, -2, -4, 60, 2 },
		{ -24, 60, -2, -16, 64, 2 },
		{ -2, 56, -16, 2, 60, -4 },
		{ -2, 60, -24, 2, 64, -16 },
		{ -2, 54, 4, 2, 58, 16 },
		{ -2, 58, 16, 2, 62, 24 },
		{ 4, 60, -12, 12, 64, -8 },
		{ -12, 62, 6, -4, 66, 10 },
	}) do
		box("TreeBranch", tx + r[1], r[2], tz + r[3], tx + r[4], r[5], tz + r[6], LOG, nil, t)
	end
	-- the autumn crown: stepped blobs of orange, rust and gold leaves
	local tints = { Color3.fromRGB(243, 200, 59), Color3.fromRGB(194, 127, 44), Color3.fromRGB(255, 255, 70) } -- px_cherry_leaves tinted autumn (as 40-outskirts)
	for k, b in ipairs({
		{ 0, 72, 0, 36 },
		{ 20, 64, 2, 20 },
		{ -22, 66, 0, 20 },
		{ 0, 66, -22, 20 },
		{ 0, 64, 22, 20 },
		{ 16, 72, -16, 16 },
		{ -14, 74, 14, 16 },
		{ 12, 76, 12, 16 },
		{ -12, 70, -18, 16 },
	}) do
		local cx, cy, cz, w = tx + b[1], b[2], tz + b[3], b[4]
		local tint = tints[(k - 1) % 3 + 1]
		box("TreeLeaves", cx - w / 2 + 4, cy - 6, cz - w / 2 + 4, cx + w / 2 - 4, cy - 2, cz + w / 2 - 4, "px_cherry_leaves", tint, t)
		box("TreeLeaves", cx - w / 2, cy - 2, cz - w / 2, cx + w / 2, cy + 2, cz + w / 2, "px_cherry_leaves", tint, t)
		box("TreeLeaves", cx - w / 2 + 4, cy + 2, cz - w / 2 + 4, cx + w / 2 - 4, cy + 6, cz + w / 2 - 4, "px_cherry_leaves", tints[k % 3 + 1], t)
		if w > 24 then
			box("TreeLeaves", cx - w / 2 + 8, cy + 6, cz - w / 2 + 8, cx + w / 2 - 8, cy + 10, cz + w / 2 - 8, "px_cherry_leaves", tint, t)
		end
	end
	-- loose leaf blocks so the crown is ragged, a few hanging under it
	for _ = 1, 26 do
		local x = tx + rng:NextInteger(-7, 7) * B
		local z = tz + rng:NextInteger(-7, 7) * B
		local y = rng:NextInteger(15, 20) * B
		cube("TreeLeaves", x, y, z, B, B, B, "px_hedge", pick(tints), t)
	end
	-- leaves drifting down into the barn through the hole
	for _ = 1, 6 do
		local x, z = tx + rng:NextNumber(10, 28), tz + rng:NextNumber(-22, 22)
		decor(box("FallenLeaves", x - 2, 0.15, z - 2, x + 2, 0.35, z + 2, "px_hedge", pick(tints), t))
	end
end
task.wait()

-- ================================================================ around the barn: lamps, the shed, the trough, junk, weeds
do
	local out = folder("BarnYardSides", barn)
	-- lanterns on brackets by the south doors, a lamp post and a lantern by the north doors
	for _, x in ipairs({ -18, 18 }) do
		decor(box("LampBracket", x - 0.4, 20.6, 4, x + 0.4, 21.2, 7.2, LOG, nil, out))
		lantern(V(x, 18.6, 6.6), out, false, BY + 21)
	end
	decor(box("LampBracket", 17.6, 20.6, -75.2, 18.4, 21.2, -72, LOG, nil, out))
	lantern(V(18, 18.6, -74.6), out, false, BY + 21)
	lampPost(-20, -77, out, false, math.pi)
	crow(-20, 10, -77, 0.5, out)

	-- the lean-to shed on the east wall, collapsed: one post standing under the last bit of roof
	local shed = folder("CollapsedShed", out)
	local SHED_WOOD = Color3.fromRGB(118, 94, 72)
	box("ShedLedger", 52, 16.8, -48, 53.2, 18, -22, LOG, nil, shed)
	box("ShedPost", 67, 0, -24, 69, 13.4, -22, LOG, nil, shed)
	box("ShedPost", 67, 0, -44, 69, 6, -42, LOG, nil, shed)
	rbox("ShedPostSnapped", 68, 6.8, -43, 1.2, 2, 1.2, 0.3, 0, 0.2, LOG, nil, shed)
	rbox("ShedPostFallen", 61, 1, -61, 13, 2, 2, 0, 0.3, 0, LOG, nil, shed)
	rbox("ShedRoof", 60.5, 16.2, -28, 17.6, 1, 12, 0, 0, -0.264, "px_dark_oak_planks", Color3.fromRGB(120, 100, 96), shed)
	rbox("ShedRoof", 59, 9.3, -40, 22.4, 1, 12, 0, 0, -0.896, "px_roof_tiles", Color3.fromRGB(96, 88, 96), shed)
	rbox("ShedRoof", 60, 1.2, -50, 16, 1, 7, 0.05, 0.1, 0.08, "px_spruce_planks", SHED_WOOD, shed)
	rbox("ShedRoof", 61, 3.2, -58, 16, 1, 8, 0, -0.08, 0.35, "px_roof_tiles", Color3.fromRGB(96, 88, 96), shed)
	box("ShedWall", 53, 0, -22.6, 60, 12, -21.6, "px_planks", SHED_WOOD, shed)
	box("ShedWall", 60, 0, -22.6, 67, 5, -21.6, "px_planks", SHED_WOOD, shed)
	decor(rbox("ShedBoard", 63.5, 6.6, -22.1, 7, 1, 0.6, 0, 0, 0.5, "px_planks", SHED_WOOD, shed))
	crate(62, 0, -28, shed)
	crate(62, 4, -28, shed, 3, 0.3)
	rbox("TippedBarrel", 58, 2, -26.5, B, B, B, math.pi / 2, 0.2, 0, "px_spruce_planks", Color3.fromRGB(150, 110, 80), shed)
	lantern(V(66, 10.4, -24.8), shed, false, BY + 12.8)
	crow(68, 13.4, -23, -0.6, shed)
	jack(64, 0, -36, 90, -36, "plain", shed)
	jack(56, 0, -66, 80, -66, "dim", shed)

	-- the west side: the broken trough, hay bales, a junk heap with a chain, a lit jack o'lantern toward the path
	local west = folder("WestSide", out)
	local TROUGH = Color3.fromRGB(104, 84, 66)
	box("TroughBottom", -66, 0, -46, -60, 0.8, -34, "px_spruce_planks", TROUGH, west)
	box("TroughSide", -66, 0.8, -46, -65, 3, -34, "px_spruce_planks", TROUGH, west)
	box("TroughSide", -61, 0.8, -46, -60, 3, -38, "px_spruce_planks", TROUGH, west)
	box("TroughEnd", -65, 0.8, -46, -61, 3, -45, "px_spruce_planks", TROUGH, west)
	decor(rbox("TroughBoard", -58.4, 0.4, -36, 1, 0.6, 5, 0, 0.3, 1.45, "px_spruce_planks", TROUGH, west))
	decor(box("TroughWater", -65, 0.8, -45, -61, 1.8, -38, nil, Color3.fromRGB(56, 74, 66), west))
	decor(box("Puddle", -64, 0.02, -34, -58, 0.12, -30, nil, Color3.fromRGB(50, 62, 56), west))
	decor(box("TroughMoss", -66, 3, -46, -65, 3.2, -40, "px_hedge", Color3.fromRGB(88, 112, 52), west))
	for _, h in ipairs({ { -62, 0, -18 }, { -58, 0, -18 }, { -62, 0, -14 }, { -62, 4, -16 } }) do
		hay(h[1], h[2], h[3], west)
	end
	jack(-62, 8, -16, -90, -16, "plain", west, 3)
	jack(-62, 0, -26, -90, -26, "lit", west)
	jack(-56, 0, -8, -90, -8, "dim", west, 3)
	crate(-64, 0, -66, west)
	crate(-60, 0, -66, west, 3, 0.4)
	crate(-64, 4, -66, west, 3, -0.2)
	rbox("TippedBarrel", -66, 2, -58, B, B, B, math.pi / 2, 0.7, 0, "px_spruce_planks", Color3.fromRGB(150, 110, 80), west)
	rbox("BrokenWheel", -58, 2.2, -60, 0.8, 4, 4, 0, 0, 0.25, "px_iron_block", RUST, west)
	decor(rbox("JunkPlanks", -62, 0.6, -52, 8, 0.6, 2, 0.1, 0.5, 0.15, "px_planks", OLD_WOOD, west))
	decor(rbox("JunkPlanks", -61, 1.1, -53, 7, 0.6, 2, -0.1, 0.9, 0.2, "px_spruce_planks", OLD_WOOD, west))
	box("JunkPost", -68, 0, -54, -66, 8, -52, LOG, nil, west)
	box("JunkArm", -68, 7, -52, -66, 8, -48.5, LOG, nil, west)
	chain(-67, -50, 7, 2, west)
	jack(-58, 0, -72.5, -58, -100, "plain", west)

	-- the north strip by the arena side doors: pumpkins and hay
	for _, p in ipairs({ { -34, -77, "plain" }, { -40, -76, "dim" }, { 30, -77, "lit" }, { 36, -76, "plain" }, { 44, -78, "plain" }, { -60, -77, "plain" }, { -48, -78, "plain" } }) do
		jack(p[1], 0, p[2], p[1], -110, p[3], out, if p[3] == "plain" then 3 else B)
	end
	hay(56, 0, -76, out)
	hay(60, 0, -76, out)
	hay(58, 4, -76, out)
	crate(-52, 0, -76.5, out, 3, 0.3)
	-- the east strip south of the shed
	barrel(56, 0, -10, out)
	barrel(60, 0, -6, out, "px_hay")
	jack(64, 0, -14, 90, -14, "plain", out)
	jack(58, 0, -2, 90, -2, "plain", out, 3)
	jack(66, 0, -50, 90, -50, "plain", out, 3)
	jack(-56, 0, -44, -90, -44, "plain", out, 3)

	-- weeds all round, off the paths and the north doorway
	local placed = 0
	for _ = 1, 600 do
		if placed >= 80 then
			break
		end
		local x, z = rng:NextNumber(-70, 70), rng:NextNumber(-80, 1)
		if zoneOf(x, z) == "barn" and not inBarn(x, z, 1) and not onPath(x, z, 2) and onIsland(x, z, 10) and not (math.abs(x) < 14 and z < -70) then
			placed += 1
			weeds(x, z, out)
		end
	end
end

print(("[build-barn] barn: %d parts"):format(count - partsBefore))
