-- ================================================================ leprechaun valley: the fairy fort (bridges, banks, arena, totems, hawthorn)
-- The fort of 10-core: arena disc (y 0) inside r 60, moat bed y -4 at r 60..72, earth banks r 72..88 (crest y 8 at
-- r 76..84, steps y 4), all on 8-stud cells. This part dresses it:
--   bridges   three stone bridges, 6 blocks wide (walkable 5 between the rails), deck top y 0.1 from the outer
--             ground to the arena: South x 96..120, z -46..-12; West x 16..68, z -112..-88 (it also caps the
--             river's spring at the arena's west edge); East x 164..204, z -112..-88. The bank cells left one step
--             high (y 4) inside the south and west gate gaps by the 8-stud grid are trimmed to y 0 under the decks.
--   gates     menhir pairs with lanterns on the bank ends, lamp posts at the arena ends, newels with lanterns.
--   banks     a dry-stone wall (px_mossy_cobblestone) along the crest (r 80) with gaps, standing stones, hawthorn
--             bushes and flowers.
--   arena     flush stone rings (r 8, 18, 31, 38, 50), a cross of paths to the gates and the tree, a blackstone heart
--             under the BossSpawn; open (no collision) inside r 40 except the four pillars.
--   pillars   four mossy totem pillars 3×3 blocks, 8 blocks tall, at (86|134, -122|-78) (r ≈ 32.6) with carved faces
--             on every side, dark oak antlers, vines and lanterns on arms. The tagged parts (Pillar*) live in
--             Core/FortPillars: BossService only raycasts the BossSpawn's parent folder for the charge stun.
--   tree      the great hawthorn at (110, -150) with the spirit's totem in its trunk, roots, ritual stones, candles.
--   ritual    a ring of 8 standing stones inside the moat edge, the cultists' corner (altar, 4 cultists, banner,
--             skulls on posts), glow lichen on the roots, mist over the moat.
local fort = folder("Fort")
local partsBefore = count
local MOSS_STONE = Color3.fromRGB(196, 214, 182)
local STONE_L = Color3.fromRGB(214, 212, 206)
local STONE_D = Color3.fromRGB(70, 68, 74)
local LEAF = Color3.fromRGB(205, 235, 190)
local ROBE = Color3.fromRGB(36, 66, 38)
local ROBE_DARK = Color3.fromRGB(26, 48, 28)
local BONE = Color3.fromRGB(228, 222, 200)
local LICHEN = Color3.fromRGB(200, 240, 90)
local FLOWER_COLS = {
	{ "px_white_wool", Color3.fromRGB(255, 255, 255) },
	{ "px_yellow_wool", Color3.fromRGB(255, 255, 255) },
	{ "px_white_wool", Color3.fromRGB(255, 200, 220) },
	{ "px_white_wool", Color3.fromRGB(170, 150, 235) },
}

-- the top of the ground cell (8-stud grid of 10-core) at a local point: mirrors groundTop's heights
local function cellTop(x, z)
	local cx, cz = math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4
	if inRiver(cx, cz) and not inPlaza(cx, cz) then
		return -4
	end
	local fd = fortDist(cx, cz)
	if fd >= FORT.moatIn and fd <= FORT.moatOut then
		return -4
	end
	if fd > FORT.moatOut and fd <= FORT.bankOut then
		for _, g in ipairs(FORT_GATES) do
			if math.sqrt((cx - g.x) ^ 2 + (cz - g.z) ^ 2) < 14 then
				return 0
			end
		end
		return if fd > FORT.moatOut + 4 and fd < FORT.bankOut - 4 then 8 else 4
	end
	if fd < FORT.moatIn or inPlaza(cx, cz) or onPath(cx, cz) then
		return 0
	end
	return groundY(cx, cz)
end
-- the centre of the 4-stud block containing v (block edges on multiples of 4)
local function c4(v)
	return math.floor(v / B) * B + B / 2
end

-- the gate bridges: axis = the coordinate the bridge runs along, c = its lateral centre, inner = the arena end,
-- outer = the far end, span = the stretch with railings over the water; menhirs on the bank ends; lamps
-- {x, z, yaw} at the arena end (the lamp arm points toward the deck)
local GATE_B = {
	{ name = "South", axis = "z", c = 108, inner = -46, outer = -12, span = { -42, -22 }, menhirs = { { 94, -18 }, { 122, -18 } }, lamps = { { 92, -50, -math.pi / 2 }, { 124, -50, math.pi / 2 } } },
	{ name = "West", axis = "x", c = -100, inner = 68, outer = 16, span = { 34, 66 }, menhirs = { { 40, -118 }, { 40, -82 } }, lamps = { { 72, -116, math.pi }, { 72, -84, 0 } } },
	{ name = "East", axis = "x", c = -100, inner = 164, outer = 204, span = { 166, 186 }, menhirs = { { 190, -114 }, { 190, -86 } }, lamps = { { 160, -116, math.pi }, { 160, -84, 0 } } },
}
for _, g in ipairs(GATE_B) do
	local u0, u1 = math.min(g.inner, g.outer), math.max(g.inner, g.outer)
	g.rect = if g.axis == "z" then { g.c - 12, g.c + 12, u0, u1 } else { u0, u1, g.c - 12, g.c + 12 }
end
local PILLARS = { { 86, -122 }, { 134, -122 }, { 86, -78 }, { 134, -78 } }
local ALTAR = { x = 146, z = -134 }
-- keep-out rectangles for the flush floor stones {x0, x1, z0, z1}: the decks, the pillar plinths, the trunk, the altar
local EXCL = {}
for _, g in ipairs(GATE_B) do
	table.insert(EXCL, g.rect)
end
for _, p in ipairs(PILLARS) do
	table.insert(EXCL, { p[1] - 8, p[1] + 8, p[2] - 8, p[2] + 8 })
end
table.insert(EXCL, { 98, 122, -164, -140 })
table.insert(EXCL, { ALTAR.x - 4, ALTAR.x + 4, ALTAR.z - 2, ALTAR.z + 2 })
local function excluded(x, z)
	for _, r in ipairs(EXCL) do
		if x > r[1] and x < r[2] and z > r[3] and z < r[4] then
			return true
		end
	end
	return false
end
-- 4-stud cells already taken by a stone or a root (key "x,z" of the block centre)
local taken = {}
local function take(x, z)
	local k = c4(x) .. "," .. c4(z)
	if taken[k] then
		return false
	end
	taken[k] = true
	return true
end

-- a standing stone: a column of mossy blocks with a lighter top block (h studs from y0)
local function standingStone(x, z, y0, h, parent, lean)
	local f = folder("StandingStone", parent)
	x, z = c4(x), c4(z)
	take(x, z)
	cube("Menhir", x, y0 + (h - B) / 2, z, B, h - B, B, "px_mossy_cobblestone", MOSS_STONE, f)
	local tx = if lean then x + lean * B else x
	cube("MenhirTop", tx, y0 + h - B / 2, z, B, B, B, if rng:NextNumber() < 0.5 then "px_cobblestone" else "px_mossy_stone_bricks", STONE_L, f)
	return f
end
-- a skull on a short dark oak post, facing yaw
local function skullPost(x, z, yaw, parent)
	textured(part("SkullPost", Vector3.new(1, 4, 1), at(x, 2, z), nil, nil, parent), WOOD_DARK)
	local skull = textured(part("Skull", Vector3.new(2, 2, 2), at(x, 5, z) * CFrame.Angles(0, yaw, 0), nil, nil, parent), "px_white_stone_bricks", BONE)
	for _, ex in ipairs({ -0.5, 0.5 }) do
		textured(decor(part("SkullEye", Vector3.new(0.6, 0.6, 0.1), skull.CFrame * CFrame.new(ex, 0.15, -1.03), nil, nil, parent)), "px_blackstone", STONE_D)
	end
	decor(part("SkullJaw", Vector3.new(1, 0.3, 0.1), skull.CFrame * CFrame.new(0, -0.55, -1.03), STONE_D, Enum.Material.SmoothPlastic, parent))
end
-- a candle (world position of its foot); lit = with a small light
local function candle(pos, parent, lit)
	textured(decor(part("Candle", Vector3.new(0.8, 1.6, 0.8), CFrame.new(pos + Vector3.new(0, 0.8, 0)), nil, nil, parent)), "px_white_wool", Color3.fromRGB(240, 232, 205))
	local flame = decor(part("CandleFlame", Vector3.new(0.35, 0.6, 0.35), CFrame.new(pos + Vector3.new(0, 1.9, 0)), Color3.fromRGB(255, 200, 100), Enum.Material.Neon, parent))
	if lit then
		light(flame, 12, 0.8, Color3.fromRGB(255, 190, 110))
	end
end
-- glow lichen: a small green-yellow glowing patch on a surface (world position of its centre)
local function lichen(pos, parent, lit)
	local p = decor(part("GlowLichen", Vector3.new(1.2, 0.2, 1.2), CFrame.new(pos), LICHEN, Enum.Material.Neon, parent))
	p.CastShadow = false
	if lit then
		light(p, 10, 0.7, LICHEN)
	end
end
-- a flower tuft: a leafy base with a coloured bloom on top (local x, z on the ground top y)
local function flowerTuft(x, y, z, parent)
	local fc = pick(FLOWER_COLS)
	textured(decor(part("FlowerLeaves", Vector3.new(1.6, 1, 1.6), at(x, y + 0.5, z), nil, nil, parent)), "px_hedge", LEAF)
	textured(decor(part("Flower", Vector3.new(1, 1, 1), at(x, y + 1.5, z), nil, nil, parent)), fc[1], fc[2])
end
-- a hawthorn bush: one or two hedge blocks, sometimes a blossom block beside them (block centre x, z; ground y)
local function bush(x, z, y, parent)
	x, z = c4(x), c4(z)
	cube("Hawthorn", x, y + 2, z, B, B, B, "px_hedge", nil, parent)
	local r = rng:NextNumber()
	if r < 0.5 then
		local dx, dz = pick({ { B, 0 }, { -B, 0 }, { 0, B }, { 0, -B } })[1], 0
		if rng:NextNumber() < 0.5 then
			dx, dz = 0, pick({ B, -B })
		end
		cube("HawthornBloom", x + dx, y + 2, z + dz, B, B, B, "px_cherry_leaves", Color3.fromRGB(255, 240, 245), parent)
	elseif r < 0.75 then
		cube("Hawthorn", x, y + 6, z, B, B, B, "px_hedge", nil, parent)
	end
end
local pillarHome = folder("FortPillars", root:FindFirstChild("Core") or fort)

-- ================================================================ the gates: trim the bank steps under the decks
do
	local core = root:FindFirstChild("Core")
	local island = core and core:FindFirstChild("Island")
	local clear = {}
	for _, g in ipairs(GATE_B) do
		local r = g.rect
		for cx = math.floor(r[1] / 8) * 8 + 4, r[2], 8 do
			for cz = math.floor(r[3] / 8) * 8 + 4, r[4], 8 do
				local fd = fortDist(cx, cz)
				local top = cellTop(cx, cz)
				if cx > r[1] and cx < r[2] and cz > r[3] and cz < r[4] and fd > FORT.moatOut and fd <= FORT.bankOut and top > 0 then
					if top > 4 then
						warn(("[build-leprechaun-valley] fort: a crest cell (%d, %d) under the %s bridge"):format(cx, cz, g.name))
					end
					table.insert(clear, { cx - 4, cx + 4, cz - 4, cz + 4 })
				end
			end
		end
	end
	if island and #clear > 0 then
		local off = Vector3.new(BX, BY, BZ)
		for _, p in ipairs(island:GetChildren()) do
			if p:IsA("BasePart") and p.Name == "Ground" then
				local c, s = p.Position - off, p.Size
				if c.Y + s.Y / 2 > 0.5 then
					local x0, x1, z0, z1 = c.X - s.X / 2, c.X + s.X / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
					for _, r in ipairs(clear) do
						if x0 < r[2] - 0.01 and x1 > r[1] + 0.01 and z0 < r[4] - 0.01 and z1 > r[3] + 0.01 then
							-- a ground run is one cell deep along z: keep what lies left and right of the cleared cell
							for _, seg in ipairs({ { x0, math.min(x1, r[1]) }, { math.max(x0, r[2]), x1 } }) do
								if seg[2] - seg[1] > 0.05 then
									local q = p:Clone()
									q.Size = Vector3.new(seg[2] - seg[1], s.Y, s.Z)
									q.CFrame = at((seg[1] + seg[2]) / 2, c.Y, c.Z)
									q.Parent = p.Parent
									count += 1
								end
							end
							p:Destroy()
							break
						end
					end
				end
			end
		end
	end
end

-- ================================================================ the gates: bridges, rails, newels, menhirs, lamps
do
	local gates = folder("Gates", fort)
	for _, g in ipairs(GATE_B) do
		local f = folder(g.name .. "Gate", gates)
		-- a box in the bridge frame: u along the bridge, v across it (from the lateral centre)
		local function gb(name, u0, y0, v0, u1, y1, v1, variant, tint)
			if g.axis == "z" then
				return box(name, g.c + v0, y0, u0, g.c + v1, y1, u1, variant, tint, f)
			end
			return box(name, u0, y0, g.c + v0, u1, y1, g.c + v1, variant, tint, f)
		end
		local function gxz(u, v)
			if g.axis == "z" then
				return g.c + v, u
			end
			return u, g.c + v
		end
		-- the deck: stone bricks with mossy kerbs, 24 wide
		gb("BridgeDeck", g.inner, -1.9, -10, g.outer, 0.1, 10, "px_stone_bricks", STONE_L)
		gb("BridgeKerb", g.inner, -1.9, -12, g.outer, 0.1, -10, "px_mossy_stone_bricks", MOSS_STONE)
		gb("BridgeKerb", g.inner, -1.9, 10, g.outer, 0.1, 12, "px_mossy_stone_bricks", MOSS_STONE)
		-- piers under the kerbs where the deck crosses water (every other block of the bed)
		local s0, s1 = g.span[1], g.span[2]
		local k = 0
		for u = s0, s1 - B, B do
			local wet = true
			for _, v in ipairs({ -10, 10 }) do
				local x, z = gxz(u + 2, v)
				if cellTop(x, z) > -4 then
					wet = false
				end
			end
			if wet then
				if k % 2 == 0 then
					for _, sv in ipairs({ -1, 1 }) do
						gb("BridgePier", u, -4, sv * 8, u + B, -1.9, sv * 12, "px_mossy_stone_bricks", MOSS_STONE)
					end
				end
				k += 1
			end
		end
		-- rails along the water stretch, dark oak newels at their ends; lanterns on the outer newels
		for _, sv in ipairs({ -1, 1 }) do
			local ax, az = gxz(s0, sv * 11.5)
			local bx, bz = gxz(s1, sv * 11.5)
			fence(ax, az, bx, bz, f, 0.1)
			for _, u in ipairs({ s0, s1 }) do
				local x, z = gxz(u, sv * 11)
				cube("BridgeNewel", x, 2.6, z, 2, 5, 2, "px_dark_oak_log", nil, f)
				local outerEnd = math.abs(u - g.outer) < math.abs(u - g.inner)
				if outerEnd then
					lantern(V(x, 5.85, z), f)
				end
			end
		end
		-- the gate menhirs on the bank ends (or in the stream), a lantern on each
		for _, m in ipairs(g.menhirs) do
			local y0 = cellTop(m[1], m[2])
			local h = math.max(12, 16 - y0)
			standingStone(m[1], m[2], y0, h, f)
			lantern(V(c4(m[1]), y0 + h + 0.75, c4(m[2])), f)
		end
		-- lamp posts where the bridge meets the arena
		for _, l in ipairs(g.lamps) do
			lampPost(l[1], l[2], f, false, l[3])
		end
		-- a flush threshold stripe where the deck leaves the arena
		local tu = if g.inner < g.outer then g.inner + 2 else g.inner - 2
		gb("BridgeThreshold", tu - 2, 0.1, -10, tu + 2, 0.25, 10, "px_mossy_stone_bricks", MOSS_STONE)
	end
end

-- ================================================================ the banks: crest wall, standing stones, bushes, flowers
do
	local banks = folder("Banks", fort)
	local GATE_PTS = { { 108, -20 }, { 28, -100 }, { 192, -100 } }
	local function nearGate(x, z, r)
		for _, p in ipairs(GATE_PTS) do
			if math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2) < r then
				return true
			end
		end
		return false
	end
	-- standing stones on the crest
	local stones = {}
	for _, deg in ipairs({ 30, 62, 124, 152, 226, 304, 334 }) do
		local a = math.rad(deg)
		local x, z = c4(FORT.x + math.cos(a) * 80), c4(FORT.z + math.sin(a) * 80)
		local y0 = cellTop(x, z)
		if y0 >= 4 and not nearGate(x, z, 20) then
			standingStone(x, z, y0, pick({ 8, 12, 12 }), banks, if rng:NextNumber() < 0.3 then pick({ -1, 1 }) else nil)
			table.insert(stones, { x, z })
		end
	end
	-- the dry-stone wall: one block high on the crest cells, merged along x, gaps every 30 degrees
	local function wallVar(cx, cz)
		local d = fortDist(cx, cz)
		if math.abs(d - 80) > 2.9 or cellTop(cx, cz) ~= 8 then
			return nil
		end
		local deg = math.deg(math.atan2(cz - FORT.z, cx - FORT.x)) % 360
		if deg % 30 < 6 then
			return nil
		end
		for _, s in ipairs(stones) do
			if math.abs(cx - s[1]) < 7 and math.abs(cz - s[2]) < 7 then
				return nil
			end
		end
		return if n2(cx, cz, 9.1, 0.08) > 0.3 then "px_cobblestone" else "px_mossy_cobblestone"
	end
	local wall = folder("CrestWall", banks)
	for tz = FORT.z - 84, FORT.z + 80, B do
		local runX0, runVar = nil, nil
		for tx = FORT.x - 88, FORT.x + 88, B do
			local v = wallVar(tx + 2, tz + 2)
			if v ~= runVar then
				if runVar then
					box("DryStoneWall", runX0, 8, tz, tx, 12, tz + B, runVar, if runVar == "px_cobblestone" then STONE_L else MOSS_STONE, wall)
				end
				runX0, runVar = tx, v
			end
		end
	end
	-- hawthorn bushes and flowers on the bank tops
	local placed = 0
	for _ = 1, 120 do
		if placed >= 18 then
			break
		end
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(73, 87)
		local x, z = c4(FORT.x + math.cos(a) * r), c4(FORT.z + math.sin(a) * r)
		local y = cellTop(x, z)
		local d = fortDist(x, z)
		local onWall = y == 8 and math.abs(d - 80) < 4
		if (y == 4 or y == 8) and not onWall and not nearGate(x, z, 22) and take(x, z) then
			bush(x, z, y, banks)
			placed += 1
		end
	end
	local flowers = folder("Flowers", banks)
	local tufts = 0
	for _ = 1, 200 do
		if tufts >= 36 then
			break
		end
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(73, 87)
		local x, z = FORT.x + math.cos(a) * r, FORT.z + math.sin(a) * r
		local y = cellTop(x, z)
		local d = fortDist(x, z)
		if (y == 4 or y == 8) and not (y == 8 and math.abs(d - 80) < 3.5) and not nearGate(x, z, 16) and not taken[c4(x) .. "," .. c4(z)] then
			flowerTuft(x, y, z, flowers)
			tufts += 1
		end
	end
end

-- ================================================================ the arena floor: flush stone rings and the cross of paths
do
	local f = folder("ArenaFloor", fort)
	local RINGS = {
		{ 50, 54, "px_stone_bricks", STONE_L },
		{ 38, 41.5, "px_mossy_stone_bricks", MOSS_STONE },
		{ 30.5, 34, "px_cobblestone", STONE_L },
		{ 18, 21, "px_stone_bricks", STONE_L },
		{ 8, 11, "px_mossy_stone_bricks", MOSS_STONE },
	}
	local function tileVar(cx, cz)
		local d = fortDist(cx, cz)
		if d > 57 or cellTop(cx, cz) ~= 0 or excluded(cx, cz) then
			return nil, nil
		end
		if d < 4 then
			return "px_blackstone", STONE_L
		end
		for _, r in ipairs(RINGS) do
			if d >= r[1] and d < r[2] then
				return r[3], r[4]
			end
		end
		local lx, lz = math.abs(cx - 108), math.abs(cz - FORT.z)
		if lx < 12 or lz < 12 then
			if (lx > 8 and lz >= 12) or (lz > 8 and lx >= 12) then
				return "px_stone_bricks", STONE_L
			end
			return "px_cobblestone", STONE_L
		end
		-- worn stones scattered in the packed earth
		if d > 12 and n2(cx, cz, 4.4, 0.21) > 0.42 then
			return "px_mossy_cobblestone", MOSS_STONE
		end
		return nil, nil
	end
	for tz = FORT.z - 60, FORT.z + 56, B do
		local runX0, runVar, runTint = nil, nil, nil
		for tx = FORT.x - 58, FORT.x + 62, B do
			local v, t = tileVar(tx + 2, tz + 2)
			if v ~= runVar or t ~= runTint then
				if runVar then
					box("ArenaStone", runX0, -0.2, tz, tx, 0.05, tz + B, runVar, runTint, f)
				end
				runX0, runVar, runTint = tx, v, t
			end
		end
	end
end

-- ================================================================ the four totem pillars
do
	local f = folder("Pillars", fort)
	for i, p in ipairs(PILLARS) do
		local px, pz = p[1], p[2]
		local pf = folder("Pillar" .. i, f)
		pillarTag(box("PillarBase", px - 8, 0, pz - 8, px + 8, 4, pz + 8, "px_mossy_cobblestone", MOSS_STONE, pillarHome))
		pillarTag(box("Pillar", px - 6, 4, pz - 6, px + 6, 20, pz + 6, "px_mossy_stone_bricks", MOSS_STONE, pillarHome))
		pillarTag(box("PillarHead", px - 6, 20, pz - 6, px + 6, 32, pz + 6, "px_stone_bricks", STONE_L, pillarHome))
		pillarTag(box("PillarCap", px - 7, 32, pz - 7, px + 7, 34, pz + 7, "px_mossy_stone_bricks", MOSS_STONE, pillarHome))
		-- a carved face on every side: dark block eyes, a brow, a nose block, a dark mouth
		for _, n in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local nx, nz = n[1], n[2]
			local tx, tz = -nz, nx
			local function fp(name, lat, y, w, h, out, depth, variant, tint)
				local sx, sz = if nx ~= 0 then depth else w, if nx ~= 0 then w else depth
				local c = cube(name, px + nx * (6 + out) + tx * lat, y, pz + nz * (6 + out) + tz * lat, sx, h, sz, variant, tint, pf)
				return decor(c)
			end
			fp("FaceEye", -4, 26, 4, 4, 0.2, 0.4, "px_blackstone", STONE_D)
			fp("FaceEye", 4, 26, 4, 4, 0.2, 0.4, "px_blackstone", STONE_D)
			fp("FaceBrow", 0, 29, 12, 2, 0.5, 1, "px_mossy_stone_bricks", MOSS_STONE)
			fp("FaceNose", 0, 25.5, 4, 3, 0.6, 1.2, "px_stone_bricks", STONE_L)
			fp("FaceMouth", 0, 21.6, 8, 1.6, 0.2, 0.4, "px_blackstone", STONE_D)
			-- moss hanging down the shaft
			if rng:NextNumber() < 0.7 then
				local len = pick({ 4, 8, 12 })
				fp("Vines", pick({ -4, 0, 4 }), 20 - len / 2, 4, len, 0.15, 0.3, "px_hedge", LEAF)
			end
		end
		-- antlers of dark oak logs on the cap: inner prongs 2 blocks, outer prongs 3 blocks
		for _, s in ipairs({ -1, 1 }) do
			cube("AntlerInner", px + s * 4, 38, pz, B, 8, B, "px_dark_oak_log", nil, pf)
			cube("AntlerOuter", px + s * 8, 44, pz, B, 12, B, "px_dark_oak_log", nil, pf)
		end
		-- lanterns on chains from short arms on the two faces looking into the arena, one on the plinth
		local sx, sz = if FORT.x > px then 1 else -1, if FORT.z > pz then 1 else -1
		for _, n in ipairs({ { sx, 0 }, { 0, sz } }) do
			local ax, az = px + n[1] * 8.25, pz + n[2] * 8.25
			cube("LanternArm", ax, 18, az, if n[1] ~= 0 then 4.5 else 1.2, 1.2, if n[2] ~= 0 then 4.5 else 1.2, "px_dark_oak_planks", nil, pf)
			lantern(V(px + n[1] * 9.6, 13.4, pz + n[2] * 9.6), pf, false, BY + 17.4)
		end
		lantern(V(px - sx * 7, 4.75, pz - sz * 7), pf)
	end
end

-- ================================================================ the great hawthorn and the spirit's totem
do
	local f = folder("Hawthorn", fort)
	local wood = folder("Wood", f)
	-- the crooked trunk: a 3×3 block trunk leaning north-west, three limbs and a branch over the arena
	for _, b in ipairs({
		{ 104, 0, -156, 116, 24, -144 },
		{ 100, 0, -152, 104, 8, -144 },
		{ 116, 0, -156, 120, 8, -148 },
		{ 108, 0, -160, 116, 8, -156 },
		{ 100, 0, -160, 104, 4, -152 },
		{ 116, 0, -148, 120, 4, -144 },
		{ 102, 0, -144, 106, 4, -140 },
		{ 114, 0, -144, 118, 4, -140 },
		{ 100, 24, -160, 112, 32, -148 },
		{ 92, 32, -164, 104, 40, -152 },
		{ 84, 40, -168, 92, 44, -160 },
		{ 80, 44, -172, 84, 48, -168 },
		{ 112, 28, -156, 120, 36, -148 },
		{ 120, 36, -152, 128, 40, -144 },
		{ 128, 40, -148, 132, 44, -140 },
		{ 104, 32, -164, 112, 44, -156 },
		{ 104, 44, -168, 108, 52, -164 },
		{ 108, 32, -148, 116, 36, -140 },
		{ 112, 36, -140, 116, 40, -136 },
		{ 116, 40, -136, 120, 44, -132 },
	}) do
		box("HawthornTrunk", b[1], b[2], b[3], b[4], b[5], b[6], "px_dark_oak_log", nil, wood)
	end
	-- the crown: hedge clumps (three layers each) with hawthorn blossom blocks on top and vines hanging below
	local crown = folder("Crown", f)
	for _, c in ipairs({
		{ 84, -166, 44, 5, 5 },
		{ 130, -144, 40, 5, 5 },
		{ 106, -164, 48, 6, 6 },
		{ 118, -134, 42, 4, 4 },
		{ 96, -150, 40, 5, 4 },
		{ 122, -160, 44, 5, 5 },
		{ 108, -150, 52, 6, 6 },
		{ 92, -140, 36, 4, 3 },
	}) do
		local cx, cz, y, w, d = c[1], c[2], c[3], c[4] * B, c[5] * B
		local ws, ds = math.max(B, w - 2 * B), math.max(B, d - 2 * B)
		cube("HawthornLeaves", cx, y + 2, cz, ws, B, ds, "px_hedge", LEAF, crown)
		cube("HawthornLeaves", cx, y + 6, cz, w, B, d, "px_hedge", nil, crown)
		cube("HawthornLeaves", cx, y + 10, cz, ws, B, ds, "px_hedge", LEAF, crown)
		for _ = 1, 2 do
			local bx = cx + rng:NextInteger(0, math.max(0, ws / B - 1)) * B - ws / 2 + B / 2
			local bz = cz + rng:NextInteger(0, math.max(0, ds / B - 1)) * B - ds / 2 + B / 2
			cube("HawthornBlossom", bx, y + 14, bz, B, B, B, "px_cherry_leaves", Color3.fromRGB(255, 240, 245), crown)
		end
		-- blossom on a side of the middle layer
		local side = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
		cube("HawthornBlossom", cx + side[1] * (w / 2 + B / 2), y + 6, cz + side[2] * (d / 2 + B / 2), B, B, B, "px_cherry_leaves", Color3.fromRGB(255, 240, 245), crown)
		for _ = 1, 2 do
			local len = pick({ 6, 10, 14 })
			local vx, vz
			if rng:NextNumber() < 0.5 then
				vx, vz = cx + pick({ -1, 1 }) * (w / 2 - 1), cz + rng:NextNumber(-d / 2 + 1, d / 2 - 1)
			else
				vx, vz = cx + rng:NextNumber(-w / 2 + 1, w / 2 - 1), cz + pick({ -1, 1 }) * (d / 2 - 1)
			end
			textured(decor(part("HangingVine", Vector3.new(1.2, len, 1.2), at(vx, y + 4 - len / 2, vz), nil, nil, crown)), "px_hedge", LEAF)
		end
	end
	-- lanterns hanging from the front branch and the west limb
	lantern(V(118, 30, -134), f, false, BY + 40)
	lantern(V(88, 33, -164), f, false, BY + 40)
	-- the spirit's totem in the trunk: stripped oak with two carved faces, the upper one with glowing eyes
	local totem = folder("SpiritTotem", f)
	box("Totem", 106, 0, -146, 114, 24, -141, "px_oak_log", nil, totem)
	box("TotemBand", 105, 11, -146, 115, 13, -140.4, "px_planks", nil, totem)
	box("TotemBand", 105, 22, -146, 115, 24, -140.4, "px_planks", nil, totem)
	box("TotemCrown", 104, 24, -146, 116, 26, -140, "px_planks", nil, totem)
	for _, s in ipairs({ -1, 1 }) do
		box("TotemHorn", 110 + s * 4, 26, -144, 110 + s * 6, 30, -142, "px_dark_oak_log", nil, totem)
	end
	for _, ex in ipairs({ 108, 112 }) do
		textured(decor(part("TotemSocket", Vector3.new(2.6, 2.6, 0.2), at(ex, 19, -140.9), nil, nil, totem)), "px_blackstone", STONE_D)
		local eye = decor(part("TotemEye", Vector3.new(1.4, 1.2, 0.2), at(ex, 19, -140.7), LICHEN, Enum.Material.Neon, totem))
		if ex == 108 then
			light(eye, 14, 1, LICHEN)
		end
		textured(decor(part("TotemSocket", Vector3.new(2.4, 2.4, 0.2), at(ex, 8, -140.9), nil, nil, totem)), "px_blackstone", STONE_D)
	end
	box("TotemNose", 109, 16.2, -141, 111, 18.4, -140, "px_planks", nil, totem)
	textured(decor(part("TotemMouth", Vector3.new(4.4, 1.2, 0.2), at(110, 15, -140.9), nil, nil, totem)), "px_blackstone", STONE_D)
	box("TotemNose", 109, 5.6, -141, 111, 7.2, -140, "px_planks", nil, totem)
	textured(decor(part("TotemMouth", Vector3.new(5, 1.4, 0.2), at(110, 4, -140.9), nil, nil, totem)), "px_blackstone", STONE_D)

	-- ritual stones and candles round the trunk
	local rite = folder("Rite", f)
	for _, s in ipairs({ { 94, -146, 8 }, { 126, -146, 8 }, { 94, -158, 12 }, { 126, -158, 12 }, { 102, -138, 4 }, { 118, -138, 4 } }) do
		local x, z = c4(s[1]), c4(s[2])
		take(x, z)
		if s[3] > B then
			standingStone(x, z, 0, s[3], rite)
		else
			cube("RitualStone", x, 2, z, B, B, B, "px_mossy_cobblestone", MOSS_STONE, rite)
		end
		local cx = x + pick({ -1, 1 }) * 3
		local cz = z + pick({ -1, 1 }) * 3
		candle(V(cx, 0, cz), rite, s[3] == 12)
		candle(V(cx + 0.9, 0, cz - 0.6), rite, false)
	end
	for _, c in ipairs({ { 104.5, -141.2 }, { 115.5, -141.2 }, { 106, -139.5 }, { 114, -139.5 } }) do
		candle(V(c[1], 4, c[2]), rite, false)
	end
	skullPost(88, -146, -math.pi / 2 - 0.3, rite)
	skullPost(132, -146, math.pi / 2 + 0.3, rite)

	-- roots creeping over the floor toward the arena (low blocks, the thin tips without collision) with glow lichen
	local roots = folder("Roots", f)
	local lit = 0
	for _, r in ipairs({
		{ 102, -146, 135, 8 },
		{ 118, -146, 45, 8 },
		{ 100, -152, 170, 9 },
		{ 120, -152, 10, 9 },
		{ 106, -142, 105, 3 },
		{ 114, -142, 75, 3 },
		{ 100, -158, 200, 5 },
		{ 120, -158, -20, 5 },
	}) do
		local a = math.rad(r[3])
		for k = 1, r[4] do
			local x, z = c4(r[1] + math.cos(a) * k * B), c4(r[2] + math.sin(a) * k * B)
			if fortDist(x, z) < 42 or cellTop(x, z) ~= 0 or excluded(x, z) then
				break
			end
			if take(x, z) then
				local p
				if k <= 2 then
					p = cube("Root", x, 1, z, B, B, B, "px_dark_oak_log", nil, roots)
				elseif k <= 5 then
					p = cube("Root", x, 0.25, z, B, 2.5, B, "px_dark_oak_log", nil, roots)
				else
					p = decor(cube("RootTip", x, 0.4, z, 2.4, 1, B, "px_dark_oak_log", nil, roots))
				end
				if k >= 2 and rng:NextNumber() < 0.4 then
					local top = p.Position.Y + p.Size.Y / 2
					lit += 1
					lichen(Vector3.new(p.Position.X + rng:NextNumber(-1, 1), top + 0.1, p.Position.Z + rng:NextNumber(-1, 1)), roots, lit % 4 == 1)
				end
			end
		end
	end
end

-- ================================================================ ritual dressing: the stone ring, the cultists' corner, mist
do
	local f = folder("Ritual", fort)
	-- a ring of standing stones just inside the moat edge (not at the gates or the tree)
	for _, deg in ipairs({ 25, 50, 130, 155, 205, 232, 308, 335 }) do
		local a = math.rad(deg)
		local r = 55
		local x, z = FORT.x + math.cos(a) * r, FORT.z + math.sin(a) * r
		while cellTop(x, z) ~= 0 and r > 46 do
			r -= B
			x, z = FORT.x + math.cos(a) * r, FORT.z + math.sin(a) * r
		end
		standingStone(x, z, 0, pick({ 8, 12, 12, 16 }), f, if rng:NextNumber() < 0.25 then pick({ -1, 1 }) else nil)
		if rng:NextNumber() < 0.6 then
			flowerTuft(c4(x) + pick({ -3, 3 }), 0, c4(z) + pick({ -3, 3 }), f)
		end
	end
	-- the cultists' corner by the north-east pillar: an altar facing the tree, cultists in dark green robes
	local corner = folder("CultistCorner", f)
	box("Altar", ALTAR.x - 4, 0, ALTAR.z - 2, ALTAR.x + 4, 4, ALTAR.z + 2, "px_stone_bricks", STONE_L, corner)
	box("AltarTop", ALTAR.x - 4.5, 4, ALTAR.z - 2.5, ALTAR.x + 4.5, 4.6, ALTAR.z + 2.5, "px_mossy_stone_bricks", MOSS_STONE, corner)
	do
		local skull = textured(part("Skull", Vector3.new(2, 2, 2), at(ALTAR.x, 5.6, ALTAR.z) * CFrame.Angles(0, math.pi, 0), nil, nil, corner), "px_white_stone_bricks", BONE)
		for _, ex in ipairs({ -0.5, 0.5 }) do
			textured(decor(part("SkullEye", Vector3.new(0.6, 0.6, 0.1), skull.CFrame * CFrame.new(ex, 0.15, -1.03), nil, nil, corner)), "px_blackstone", STONE_D)
		end
	end
	candle(V(ALTAR.x - 3, 4.6, ALTAR.z), corner, true)
	candle(V(ALTAR.x + 3, 4.6, ALTAR.z - 0.8), corner, false)
	candle(V(ALTAR.x + 2.2, 4.6, ALTAR.z + 1), corner, false)
	-- a banner of the cult on a post behind the altar, skulls on posts
	textured(part("BannerPost", Vector3.new(1, 11, 1), at(152, 5.5, -139), nil, nil, corner), WOOD_DARK)
	textured(decor(part("BannerArm", Vector3.new(1, 1, 4), at(152, 10.5, -137.5), nil, nil, corner)), WOOD_DARK)
	banner(at(152, 6, -136) * CFrame.Angles(0, math.pi / 2, 0), ROBE, corner, LICHEN)
	skullPost(156, -126, math.pi / 2, corner)
	skullPost(136, -142, math.pi, corner)
	lampPost(158, -118, corner, false, math.pi / 2)
	local function cultist(x, z, lx, lz, withLantern)
		local cf = CFrame.lookAt(V(x, 3, z), V(lx, 3, lz))
		npc("Cultist", cf, { shirt = ROBE, pants = ROBE_DARK, skin = Color3.fromRGB(196, 178, 160) }, corner)
		if withLantern then
			local p = (cf * CFrame.new(1.6, -1.6, -0.5)).Position
			lantern(p, corner, false, p.Y + 1.4)
		end
	end
	cultist(138, -134, ALTAR.x, ALTAR.z, false)
	cultist(154, -131, ALTAR.x, ALTAR.z, true)
	cultist(146, -141, ALTAR.x, ALTAR.z, false)
	cultist(97, -137, 110, -141, false)
	-- flowers at the foot of the arena wall and round the tree
	for _ = 1, 40 do
		local a = rng:NextNumber() * math.pi * 2
		local r = rng:NextNumber(43, 57)
		local x, z = FORT.x + math.cos(a) * r, FORT.z + math.sin(a) * r
		if cellTop(x, z) == 0 and not excluded(x, z) and math.abs(x - 108) > 13 and math.abs(z - FORT.z) > 13 and not taken[c4(x) .. "," .. c4(z)] then
			flowerTuft(x, 0, z, f)
		end
	end
	-- mist drifting low over the moat (four sparse emitters)
	for _, deg in ipairs({ 45, 135, 225, 315 }) do
		local a = math.rad(deg)
		local m = decor(part("MoatMist", Vector3.new(16, 1, 16), at(FORT.x + math.cos(a) * 66, -1.5, FORT.z + math.sin(a) * 66), nil, nil, f))
		m.Transparency = 1
		m.CastShadow = false
		emitter(m, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Rate = 1.5,
			Lifetime = NumberRange.new(8, 12),
			Size = NumberSequence.new(7, 11),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.82), NumberSequenceKeypoint.new(1, 1) }),
			Speed = NumberRange.new(0.3, 0.8),
			SpreadAngle = Vector2.new(70, 70),
			Rotation = NumberRange.new(0, 360),
			RotSpeed = NumberRange.new(-8, 8),
			Color = ColorSequence.new(Color3.fromRGB(225, 240, 225)),
			LightInfluence = 1,
		})
	end
end
print(("[build-leprechaun-valley] fort: %d parts"):format(count - partsBefore))
