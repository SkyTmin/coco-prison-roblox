--!nocheck
-- ================================================================ farm: the grove (L1 west of x -24) and the three stairs
-- The three L0 → L1 stairs (MAIN x -10..10, EAST x 80..96, WEST x -180..-164; z -64 → -80) with log kerbs and lamp
-- posts; dirt paths on L1: the track from the main stair top to the arena's east opening, the forest path from the
-- south opening to the west stair top, the trail from the west opening to the woodcutter, the hut and the west stair.
-- The arena ARENA (-92, -136) r 52: packed dirt (core) with a stone paving ring r 30..34, a leaf-litter ring r 38..42
-- and a cobbled border r 48..52 laid flush; four old dark oak pillar trees on the diagonals (r 34, tagged Pillar);
-- ruined mossy posts r 54.5; a dark oak fence ring r 58 (straight along the cliff in the south) with three openings
-- 6 blocks wide (E 0°, S 140°, W 180°) and lamp posts beside them; the north side is left to the Ent.
-- The Ent at ENT (-92, -200): a 6×6-block trunk 12 blocks high with a carved angry face toward the arena (deep-set
-- eyes with a faint green glow, heavy brows, a frowning mouth, a dark hollow at the bottom), root arches and branch
-- arms on both sides, a stepped crown y 64..92 with hanging vines, moss and mushrooms at the roots.
-- The forest: old dark oak trees with wide crowns, bushes, ferns, fallen logs, mossy boulders, mushrooms, a
-- woodcutter's stump with an axe, a hunter's hut; grass curtains and roots on the cliffs.
local grove = folder("Grove")
local GY = L1_Y
local count0 = count
local GREEN_GLOW = Color3.fromRGB(140, 255, 110)
local LEAF_TINTS = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(215, 235, 200), Color3.fromRGB(190, 212, 172) }
local DARK_LOG = "px_dark_oak_log"

-- the yaw that turns a kit prop's local -Z toward (dx, dz)
local function yawToward(dx, dz)
	return math.atan2(-dx, -dz)
end
-- what the core really built under (x, z): its 8-stud island cell
local function cellOf(v)
	return math.floor(v / 8) * 8 + 4
end
local function onL1(x, z)
	local cx, cz = cellOf(x), cellOf(z)
	return onIsland(cx, cz) and groundY(cx, cz) == GY
end
-- flush tiles (y 15.8 .. 16.1) on the 4-stud cells of [x0, x1] × [z0, z1]: fn(cx, cz) -> variant, tint | nil;
-- equal neighbours along x are merged into one run
local function tiles(name, x0, x1, z0, z1, fn, parent)
	for z = z0, z1 - B, B do
		local runX, runKey, runV, runT = nil, nil, nil, nil
		local function flush(xEnd)
			if runX then
				box(name, runX, GY - 0.2, z, xEnd, GY + 0.1, z + B, runV, runT, parent)
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

-- dirt paths on L1 (polylines, width in studs)
local ROUTES = {
	{ w = 16, pts = { { 0, -82 }, { -6, -102 }, { -20, -128 }, { -30, -136 }, { -42, -136 } } }, -- main stair → arena E
	{ w = 12, pts = { { -129, -105 }, { -140, -96 }, { -156, -94 }, { -168, -92 }, { -172, -82 } } }, -- arena S → west stair
	{ w = 12, pts = { { -142, -136 }, { -164, -134 }, { -184, -124 } } }, -- arena W → the woodcutter
	{ w = 10, pts = { { -184, -124 }, { -180, -106 }, { -172, -92 } } }, -- the woodcutter → the west stair
	{ w = 8, pts = { { -184, -124 }, { -188, -146 }, { -190, -160 } } }, -- the woodcutter → the hunter's hut
}
-- the distance from (x, z) to the nearest path edge (negative: on a path)
local function routeDist(x, z)
	local best = math.huge
	for _, r in ipairs(ROUTES) do
		for i = 1, #r.pts - 1 do
			local a, b = r.pts[i], r.pts[i + 1]
			local d = segDist(x, z, a[1], a[2], b[1], b[2]) - r.w / 2
			if d < best then
				best = d
			end
		end
	end
	return best
end

-- the arena openings (angle from +X toward +Z: 0 east, 90 south, 180 west) and their half clear width
local OPEN = { 0, 140, 180 }
local OPEN_HALF = 12
-- the distance of (dx, dz) from the arena centre to the nearest opening axis, on the outward side of it
local function openPerp(dx, dz)
	local best = math.huge
	for _, deg in ipairs(OPEN) do
		local a = math.rad(deg)
		local along = dx * math.cos(a) + dz * math.sin(a)
		if along > 0 then
			best = math.min(best, math.abs(-dx * math.sin(a) + dz * math.cos(a)))
		end
	end
	return best
end

-- the Ent's footprint with its roots and arms; reserved clearings { x, z, r }: the hut, the woodcutter
local ENT_BOX = { -162, -232, -24, -182 }
local HUT = { x = -190, z = -172 }
local RES = { { HUT.x, HUT.z, 16 }, { -186, -118, 14 } }
local OCC = {} -- placed solid things { x, z, r } (trees, boulders, logs)
local function taken(x, z, r)
	for _, o in ipairs(OCC) do
		if (x - o[1]) ^ 2 + (z - o[2]) ^ 2 < (r + o[3]) ^ 2 then
			return true
		end
	end
	return false
end
-- room for a solid thing of radius rad: grove L1 ground all round, 10 studs from the rim, off the paths, the stairs,
-- the arena (outside the fence), the Ent and the clearings
local function solidOk(x, z, rad)
	for _, o in ipairs({ { 0, 0 }, { rad, 0 }, { -rad, 0 }, { 0, rad }, { 0, -rad } }) do
		local px, pz = x + o[1], z + o[2]
		if not onIsland(px, pz, 10) or not onL1(px, pz) or px >= -26 or inStairCorridor(px, pz) then
			return false
		end
	end
	if inArena(x, z, 7 + rad) then
		return false
	end
	if x > ENT_BOX[1] - rad and x < ENT_BOX[3] + rad and z > ENT_BOX[2] - rad and z < ENT_BOX[4] + rad then
		return false
	end
	if routeDist(x, z) < rad + 1 then
		return false
	end
	for _, c in ipairs(RES) do
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < (c[3] + rad) ^ 2 then
			return false
		end
	end
	return true
end

-- a stepped leaf layer of w × d blocks centred on (cx, cz), corners cut (three boxes, no overlaps)
local function leafLayer(name, cx, cz, w, d, y0, y1, tint, parent, isDecor)
	local hw, hd = w * B / 2, d * B / 2
	local parts = {}
	if w >= 3 and d >= 3 then
		table.insert(parts, box(name, cx - hw + B, y0, cz - hd, cx + hw - B, y1, cz + hd, "px_hedge", tint, parent))
		table.insert(parts, box(name, cx - hw, y0, cz - hd + B, cx - hw + B, y1, cz + hd - B, "px_hedge", tint, parent))
		table.insert(parts, box(name, cx + hw - B, y0, cz - hd + B, cx + hw, y1, cz + hd - B, "px_hedge", tint, parent))
	else
		table.insert(parts, box(name, cx - hw, y0, cz - hd, cx + hw, y1, cz + hd, "px_hedge", tint, parent))
	end
	if isDecor then
		for _, p in ipairs(parts) do
			decor(p)
		end
	end
end
-- a hanging vine strand (decor) from yTop down by len
local function vine(x, yTop, z, len, parent)
	local p = textured(decor(part("Vine", Vector3.new(1.2, len, 1.2), at(x, yTop - len / 2, z), nil, nil, parent)), "px_hedge")
	p.CastShadow = false
	return p
end
-- a block mushroom (decor): a pale stem and a red or brown cap; s scales it
local function mushroom(x, y, z, red, s, parent)
	s = s or 1
	textured(
		decor(part("MushroomStem", Vector3.new(1.2 * s, 1.6 * s, 1.2 * s), at(x, y + 0.8 * s, z), nil, nil, parent)),
		"px_white_wool",
		Color3.fromRGB(235, 225, 200)
	)
	local cap = decor(part("MushroomCap", Vector3.new(3 * s, 1.2 * s, 3 * s), at(x, y + 2.2 * s, z), nil, nil, parent))
	if red then
		textured(cap, "px_white_wool", Color3.fromRGB(205, 45, 40))
	else
		textured(cap, "px_brown_wool", nil)
	end
end
-- an old dark oak: a 2×2 trunk h studs high, root flares, a wide stepped crown, optional hanging vines
local function bigTree(x, z, h, cw, parent, vines)
	local f = folder("OldTree", parent)
	local top = GY + h
	box("Trunk", x - 4, GY, z - 4, x + 4, top + 4, z + 4, DARK_LOG, nil, f)
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		if rng:NextNumber() < 0.7 then
			local rh = pick({ 4, 4, 8 })
			local off = pick({ -2, 2 })
			local px, pz = x + d[1] * 6 + d[2] * off, z + d[2] * 6 + d[1] * off
			cube("TreeRoot", px, GY + rh / 2, pz, B, rh, B, DARK_LOG, nil, f)
		end
	end
	-- a branch stub or two under the crown
	for _ = 1, rng:NextInteger(1, 2) do
		local d = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
		cube("Branch", x + d[1] * 6, top - 6, z + d[2] * 6, B, B, B, DARK_LOG, nil, f)
		cube("Branch", x + d[1] * 10, top - 2, z + d[2] * 10, B, B, B, DARK_LOG, nil, f)
	end
	local tint = pick(LEAF_TINTS)
	leafLayer("Leaves", x, z, cw, cw, top - 4, top + 4, tint, f)
	leafLayer("Leaves", x, z, cw - 2, cw - 2, top + 4, top + 8, tint, f)
	leafLayer("Leaves", x, z, cw - 4, cw - 4, top + 8, top + 12, tint, f)
	local e = cw * B / 2
	for _ = 1, rng:NextInteger(3, 5) do
		local side = rng:NextInteger(1, 4)
		local t = rng:NextInteger(-cw // 2 + 1, cw // 2 - 1) * B
		local bx, bz = x + t, z + t
		if side == 1 then
			bx = x + e
		elseif side == 2 then
			bx = x - e
		elseif side == 3 then
			bz = z + e
		else
			bz = z - e
		end
		cube("Leaves", bx, top + pick({ -6, -2, 2 }), bz, 2 * B, B, 2 * B, "px_hedge", tint, f)
	end
	if vines then
		for _ = 1, rng:NextInteger(4, 7) do
			local t = rng:NextNumber(-e + 2, e - 2)
			local side = rng:NextInteger(1, 4)
			local vx, vz = x + t, z + t
			if side == 1 then
				vx = x + e - 1
			elseif side == 2 then
				vx = x - e + 1
			elseif side == 3 then
				vz = z + e - 1
			else
				vz = z - e + 1
			end
			vine(vx, top - 4, vz, math.min(rng:NextInteger(6, 16), h - 8), f)
		end
	end
	return f
end

-- ================================================================ 1. the three stairs L0 → L1
do
	local f = folder("Stairs", grove)
	for _, s in ipairs({
		{ "Main", STAIRS.main, "px_cobblestone", nil },
		{ "East", STAIRS.east, "px_dirt", PATH_DIRT },
		{ "West", STAIRS.west, "px_dirt", PATH_DIRT },
	}) do
		local name, st, variant, tint = s[1], s[2], s[3], s[4]
		local x0, x1 = st.x0, st.x1
		local sf = folder(name .. "Stair", f)
		stairs(name, (x0 + x1) / 2, st.z0, st.z1, 0, L1_Y, x1 - x0, variant, sf)
		for _, c in ipairs(sf:GetChildren()) do
			if c.Name == name .. "Step" and tint then
				c.Color = tint
			end
		end
		-- fill under the steps (8 steps of 2 studs; each step box is one block high)
		for k = 0, 7 do
			local top = 2 * (k + 1)
			if top - B > 0 then
				local za = st.z0 - 2 * k
				box(name .. "StepFill", x0, 0, za - 2, x1, top - B, za, variant, tint, sf)
			end
		end
		-- log kerbs on both sides, a block above the steps
		for j = 0, 3 do
			local za = st.z0 - 4 * j
			local top = 4 * (j + 1) + 4
			box("Kerb", x0 - B, 0, za - 4, x0, top, za, "px_oak_log", nil, sf)
			box("Kerb", x1, 0, za - 4, x1 + B, top, za, "px_oak_log", nil, sf)
		end
		-- lamp posts at the foot (east side) and the top (west side), lanterns over the steps
		lampPost(x1 + 6, st.z0 + 6, sf, false, yawToward(-1, 0), 0)
		lampPost(x0 - 6, st.z1 - 6, sf, false, yawToward(1, 0), L1_Y)
	end
end
task.wait()

-- ================================================================ 2. the paths on L1
do
	local f = folder("Paths", grove)
	tiles("Path", -204, 16, -168, -76, function(cx, cz)
		if not onL1(cx, cz) or inArena(cx, cz, 8) then
			return nil
		end
		local d = routeDist(cx, cz)
		if d > 0 then
			return nil
		end
		if d > -2.5 and n2(cx, cz, 5.5, 0.2) > -0.1 then
			return "px_dirt", Color3.fromRGB(150, 118, 84) -- ragged darker edges
		end
		if n2(cx, cz, 2.2, 0.09) > 0.3 then
			return "px_gravel", nil
		end
		return "px_dirt", PATH_DIRT
	end, f)
end
task.wait()

-- ================================================================ 3. the arena
do
	local arena = folder("Arena", grove)
	local AX, AZ = ARENA.x, ARENA.z
	-- the floor pattern laid flush: the paving ring, the leaf litter, the cobbled border, the opening thresholds
	tiles("ArenaFloor", AX - 60, AX + 60, AZ - 60, AZ + 60, function(cx, cz)
		local dx, dz = cx - AX, cz - AZ
		local rr = math.sqrt(dx * dx + dz * dz)
		if rr >= 60 or not onL1(cx, cz) then
			return nil
		end
		if rr >= 52 then
			if openPerp(dx, dz) < OPEN_HALF then
				return if rng:NextNumber() < 0.3 then "px_mossy_cobblestone" else "px_cobblestone", nil
			end
			return nil
		end
		if rr >= 48 then
			return if rng:NextNumber() < 0.3 then "px_mossy_cobblestone" else "px_cobblestone", nil
		end
		if rr >= 38 and rr < 42 and n2(cx, cz, 9.3, 0.09) > -0.1 then
			return "px_forest_floor", Color3.fromRGB(175, 135, 95) -- a ring of fallen, scorched leaves
		end
		if rr >= 30 and rr < 34 then
			local u = rng:NextNumber()
			if u < 0.08 then
				return nil -- a missing stone
			end
			return if u < 0.32 then "px_mossy_stone_bricks" else "px_stone_bricks", nil
		end
		return nil
	end, arena)
	task.wait()

	-- four old dark oaks on the diagonals (r 34): 3×3 trunks 8 blocks high, crowns above y +28 (every trunk part is
	-- a stun pillar)
	for _, s in ipairs({ { 1, 1 }, { -1, 1 }, { -1, -1 }, { 1, -1 } }) do
		local px, pz = AX + s[1] * 24, AZ + s[2] * 24
		local f = folder("PillarTree", arena)
		pillarTag(box("PillarTrunk", px - 6, GY, pz - 6, px + 6, GY + 36, pz + 6, DARK_LOG, nil, f))
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local outward = d[1] * s[1] + d[2] * s[2] > 0
			local h = if outward then 8 else 4
			local rx, rz = px + d[1] * 8, pz + d[2] * 8
			local hx, hz = if d[1] ~= 0 then 2 else 4, if d[2] ~= 0 then 2 else 4
			pillarTag(box("PillarRoot", rx - hx, GY, rz - hz, rx + hx, GY + h, rz + hz, DARK_LOG, nil, f))
		end
		-- stripped lighter bark patches and moss on the trunk
		for _ = 1, 3 do
			local d = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
			local y = GY + rng:NextInteger(2, 7) * B
			local o = rng:NextInteger(-1, 1) * B
			local bx, bz = px + d[1] * 6.2 + d[2] * o, pz + d[2] * 6.2 + d[1] * o
			local sx, sz = if d[1] ~= 0 then 0.4 else B, if d[2] ~= 0 then 0.4 else B
			pillarTag(cube("PillarBark", bx, y, bz, sx, 2 * B, sz, "px_oak_log", nil, f))
		end
		-- branch stubs reaching out under the crown
		for _, d in ipairs({ { s[1], 0 }, { 0, s[2] } }) do
			pillarTag(cube("PillarBranch", px + d[1] * 8, GY + 26, pz + d[2] * 8, B, B, B, DARK_LOG, nil, f))
			pillarTag(cube("PillarBranch", px + d[1] * 12, GY + 30, pz + d[2] * 12, B, B, B, DARK_LOG, nil, f))
		end
		local tint = LEAF_TINTS[2]
		leafLayer("PillarLeaves", px, pz, 9, 9, GY + 28, GY + 36, tint, f)
		leafLayer("PillarLeaves", px, pz, 7, 7, GY + 36, GY + 44, tint, f)
		leafLayer("PillarLeaves", px, pz, 5, 5, GY + 44, GY + 48, tint, f)
		for _ = 1, 4 do
			local side = rng:NextInteger(1, 4)
			local t = rng:NextInteger(-3, 3) * B
			local bx, bz = px + t, pz + t
			if side == 1 then
				bx = px + 18
			elseif side == 2 then
				bx = px - 18
			elseif side == 3 then
				bz = pz + 18
			else
				bz = pz - 18
			end
			decor(cube("PillarLeaves", bx, GY + 26, bz, 2 * B, B, 2 * B, "px_hedge", tint, f))
		end
		for _ = 1, 6 do
			local t = rng:NextNumber(-16, 16)
			local side = rng:NextInteger(1, 4)
			local vx, vz = px + t, pz + t
			if side == 1 then
				vx = px + 17
			elseif side == 2 then
				vx = px - 17
			elseif side == 3 then
				vz = pz + 17
			else
				vz = pz - 17
			end
			vine(vx, GY + 28, vz, rng:NextInteger(6, 12), f)
		end
	end
	task.wait()

	-- ruined stone posts round the rim (r 54.5): mossy, broken, some with a fallen block
	local VARS = { "px_mossy_stone_bricks", "px_stone_bricks", "px_mossy_cobblestone", "px_mossy_stone_bricks" }
	for k = 0, 23 do
		local a = math.rad(k * 15 + 7.5)
		local deg = k * 15 + 7.5
		local x, z = AX + math.cos(a) * 54.5, AZ + math.sin(a) * 54.5
		local dx, dz = x - AX, z - AZ
		if openPerp(dx, dz) >= OPEN_HALF + 4 and not (deg > 228 and deg < 312) and z < -86 and onL1(x, z) then
			local f = folder("RuinedPost", arena)
			local cf = at(x, GY, z) * CFrame.Angles(0, -a, 0)
			local n = rng:NextInteger(1, 3)
			for i = 1, n do
				textured(part("PostBlock", Vector3.new(B, B, B), cf * CFrame.new(0, (i - 0.5) * B, 0), nil, nil, f), pick(VARS))
			end
			local u = rng:NextNumber()
			if u < 0.4 then
				-- a broken top block, knocked askew
				textured(
					part("PostBroken", Vector3.new(B, B * 0.75, B), cf * CFrame.new(0.5, n * B + 1.4, 0.3) * CFrame.Angles(0.15, 0.3, 0.22), nil, nil, f),
					pick(VARS)
				)
			elseif u < 0.7 then
				textured(part("PostCap", Vector3.new(B + 0.6, 1, B + 0.6), cf * CFrame.new(0, n * B + 0.5, 0), nil, nil, f), "px_stone_bricks")
			end
			if rng:NextNumber() < 0.35 then
				-- a fallen block on the ground beside it (along the ring)
				textured(
					part("PostFallen", Vector3.new(B, B, B), cf * CFrame.new(0, 1.6, pick({ -6, 6 })) * CFrame.Angles(0, 0.4, 0.25), nil, nil, f),
					pick(VARS)
				)
			end
			if rng:NextNumber() < 0.5 then
				textured(decor(part("PostMoss", Vector3.new(B + 0.3, 0.4, B + 0.3), cf * CFrame.new(0, n * B + 0.2, 0), nil, nil, f)), "px_hedge")
			end
		end
	end

	-- the dark oak fence ring r 58 (straight along the cliff in the south), open at E, S, W and toward the Ent
	local FR, N = 58, 48
	local pts = {}
	for i = 0, N do
		local a = i / N * 2 * math.pi
		local x, z = AX + math.cos(a) * FR, AZ + math.sin(a) * FR
		local deg = math.deg(a) % 360
		z = math.min(z, -83)
		local ok = not (deg > 236 and deg < 304) and openPerp(x - AX, z - AZ) >= OPEN_HALF + 1 and onL1(x, z)
		pts[i] = { V(x, GY, z), ok }
	end
	local fence = folder("Fence", arena)
	for i = 0, N - 1 do
		local p, q = pts[i], pts[i + 1]
		if p[2] then
			textured(part("FencePost", Vector3.new(1, 3.4, 1), CFrame.new(p[1] + Vector3.new(0, 1.7, 0)), nil, nil, fence), WOOD_DARK)
		end
		if p[2] and q[2] then
			local len = (q[1] - p[1]).Magnitude
			for _, h in ipairs({ 1.2, 2.6 }) do
				local mid = (p[1] + q[1]) / 2 + Vector3.new(0, h, 0)
				textured(part("FenceRail", Vector3.new(0.4, 0.6, len), CFrame.lookAt(mid, q[1] + Vector3.new(0, h, 0)), nil, nil, fence), WOOD_DARK)
			end
		end
	end
	-- each opening: mossy stone columns at the fence ends and a lamp post outside each
	for _, deg in ipairs(OPEN) do
		local a = math.rad(deg)
		local ux, uz = math.cos(a), math.sin(a)
		local px, pz = -uz, ux
		for _, side in ipairs({ -1, 1 }) do
			local off = side * (OPEN_HALF + 2.5)
			local cx, cz = AX + ux * FR + px * off, AZ + uz * FR + pz * off
			if onL1(cx, cz) then
				box("OpeningColumn", cx - 2, GY, cz - 2, cx + 2, GY + 8, cz + 2, "px_mossy_cobblestone", nil, fence)
				box("OpeningColumnCap", cx - 2.3, GY + 8, cz - 2.3, cx + 2.3, GY + 9, cz + 2.3, "px_stone_bricks", nil, fence)
			end
			for r = 63, 59, -1 do
				local lx, lz = AX + ux * r + px * side * (OPEN_HALF + 4), AZ + uz * r + pz * side * (OPEN_HALF + 4)
				if onL1(lx, lz) and onL1(lx + 2, lz + 2) and onL1(lx - 2, lz - 2) then
					lampPost(lx, lz, fence, false, yawToward(-px * side, -pz * side), GY)
					break
				end
			end
		end
	end
end
task.wait()

-- ================================================================ 4. the Ent: the huge ancient tree with a face
do
	local ent = folder("Ent", grove)
	local EX, EZ = ENT.x, ENT.z
	local tx0, tx1 = EX - 12, EX + 12 -- 6 blocks wide
	local tzF = EZ + 12 -- the face toward the arena (z -188)
	local tzB = EZ - 12 -- 6 blocks deep, less if the north rim is too close
	while tzB < EZ - 4 and not (onIsland(tx0, tzB, 10) and onIsland(tx1, tzB, 10)) do
		tzB += B
	end
	local TOP = GY + 48 -- 12 blocks of trunk
	local hx0, hx1 = tx0 + 8, tx0 + 16 -- the hollow at the bottom, 2 blocks wide, 3 high, 2 deep
	-- the trunk core with the notch of the hollow
	box("EntTrunk", tx0, GY + 12, tzB, tx1, TOP, tzF - B, DARK_LOG, nil, ent)
	box("EntTrunk", tx0, GY, tzB, hx0, GY + 12, tzF - B, DARK_LOG, nil, ent)
	box("EntTrunk", hx1, GY, tzB, tx1, GY + 12, tzF - B, DARK_LOG, nil, ent)
	box("EntTrunk", hx0, GY, tzB, hx1, GY + 12, tzF - 2 * B, DARK_LOG, nil, ent)
	-- the dark inside of the hollow
	local function darkPlate(x0, y0, z0, x1, y1, z1)
		decor(box("EntHollow", x0, y0, z0, x1, y1, z1, "px_coal_block", Color3.fromRGB(70, 70, 70), ent))
	end
	darkPlate(hx0, GY, tzF - 2 * B, hx1, GY + 12, tzF - 2 * B + 0.2)
	darkPlate(hx0, GY, tzF - 2 * B, hx0 + 0.2, GY + 12, tzF)
	darkPlate(hx1 - 0.2, GY, tzF - 2 * B, hx1, GY + 12, tzF)
	darkPlate(hx0, GY + 11.8, tzF - 2 * B, hx1, GY + 12, tzF)
	darkPlate(hx0, GY, tzF - 2 * B, hx1, GY + 0.3, tzF)

	-- the face layer (6 × 12 cells of one block, the front block row): carved mouth and eyes, lighter stripped bark
	local KIND = {}
	for r = 0, 2 do
		KIND[r * 6 + 2], KIND[r * 6 + 3] = "hole", "hole"
	end
	for c = 1, 4 do
		KIND[5 * 6 + c] = "carve" -- the frowning mouth: the middle high, the corners lower
	end
	KIND[4 * 6 + 1], KIND[4 * 6 + 4] = "carve", "carve"
	KIND[7 * 6 + 1], KIND[7 * 6 + 4] = "eye", "eye"
	for r = 0, 11 do
		local runC, runV = nil, nil
		local function flush(cEnd)
			if runC and runV then
				box("EntFace", tx0 + runC * B, GY + r * B, tzF - B, tx0 + cEnd * B, GY + (r + 1) * B, tzF, runV, nil, ent)
			end
		end
		for c = 0, 5 do
			local k = KIND[r * 6 + c]
			local v = nil
			if k == nil then
				v = if rng:NextNumber() < 0.2 then "px_oak_log" else DARK_LOG
			end
			if v ~= runV then
				flush(c)
				runC, runV = c, v
			end
			if k == "carve" or k == "eye" then
				local x0 = tx0 + c * B
				local y0 = GY + r * B
				box("EntCarve", x0, y0, tzF - B, x0 + B, y0 + B, tzF - B + 1.5, "px_coal_block", nil, ent)
				if k == "eye" then
					-- a faint green glow deep in the socket, nearer the nose
					local gx = x0 + B / 2 + (if c < 3 then 0.6 else -0.6)
					local glow = decor(part("EntEyeGlow", Vector3.new(1.6, 1.4, 0.3), at(gx, y0 + 1.6, tzF - B + 1.65), GREEN_GLOW, Enum.Material.Neon, ent))
					glow.Transparency = 0.25
					light(glow, 10, 0.8, GREEN_GLOW)
				end
			end
		end
		flush(6)
	end
	-- heavy brows slanting down to the nose (angry), the nose, cheek ridges
	local BROW = Color3.fromRGB(150, 130, 120)
	box("EntBrow", tx0, GY + 51.5, tzF, tx0 + 4, GY + 54.5, tzF + 3, DARK_LOG, BROW, ent)
	box("EntBrow", tx0 + 4, GY + 49, tzF, tx0 + 10, GY + 52, tzF + 3, DARK_LOG, BROW, ent)
	box("EntBrow", tx1 - 4, GY + 51.5, tzF, tx1, GY + 54.5, tzF + 3, DARK_LOG, BROW, ent)
	box("EntBrow", tx1 - 10, GY + 49, tzF, tx1 - 4, GY + 52, tzF + 3, DARK_LOG, BROW, ent)
	box("EntNose", EX - 2, GY + 40, tzF, EX + 2, GY + 47, tzF + 2.5, DARK_LOG, nil, ent)
	box("EntCheek", tx0 + 1, GY + 41, tzF, tx0 + 7, GY + 43, tzF + 1.2, "px_oak_log", nil, ent)
	box("EntCheek", tx1 - 7, GY + 41, tzF, tx1 - 1, GY + 43, tzF + 1.2, "px_oak_log", nil, ent)
	-- the lintel over the hollow and the bark lips round it
	box("EntLip", hx0 - 1, GY + 12, tzF, hx1 + 1, GY + 14, tzF + 1.5, DARK_LOG, BROW, ent)
	box("EntLip", hx0 - 1.5, GY, tzF, hx0, GY + 12, tzF + 1, DARK_LOG, BROW, ent)
	box("EntLip", hx1, GY, tzF, hx1 + 1.5, GY + 12, tzF + 1, DARK_LOG, BROW, ent)

	-- bark texture on the sides and back: stripped lighter patches, moss low down, shelf fungi
	for _ = 1, 14 do
		local side = rng:NextInteger(1, 3)
		local y = GY + rng:NextInteger(1, 10) * B
		if side == 3 then
			local x = rng:NextInteger(0, 4) * B + tx0 + 2
			cube("EntBark", x + 2, y, tzB - 0.2, B, 2 * B, 0.4, "px_oak_log", nil, ent)
		else
			local x = if side == 1 then tx0 - 0.2 else tx1 + 0.2
			local z = tzB + rng:NextInteger(1, math.max(1, (tzF - tzB) / B - 2)) * B
			cube("EntBark", x, y, z, 0.4, 2 * B, B, "px_oak_log", nil, ent)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		local x = if side < 0 then tx0 - 0.25 else tx1 + 0.25
		decor(box("EntMoss", x - 0.25, GY, tzB + 4, x + 0.25, GY + 6, tzF - 2, "px_hedge", nil, ent))
		for i = 1, 2 do
			local fy = GY + 18 + i * 9 + rng:NextInteger(0, 4)
			local fz = tzB + 6 + rng:NextNumber() * (tzF - tzB - 12)
			textured(decor(part("ShelfFungus", Vector3.new(3, 0.8, 4), at(x + side * 1.5, fy, fz), nil, nil, ent)), "px_brown_wool")
		end
	end
	decor(box("EntMoss", tx0, GY, tzF, hx0 - 1.5, GY + 4, tzF + 0.4, "px_hedge", nil, ent))
	decor(box("EntMoss", hx1 + 1.5, GY, tzF, tx1, GY + 3, tzF + 0.4, "px_hedge", nil, ent))
	task.wait()

	-- root arches on both sides (2 blocks thick): an inner root springing from the trunk at +36 and landing 7 blocks
	-- out (walk under it), then a smaller round arch beyond it; low roots creep out in front of the trunk
	local function column(name, x0, x1, b, t, z0, z1)
		box(name, x0, GY + b, z0, x1, GY + t, z1, DARK_LOG, nil, ent)
	end
	for _, s in ipairs({ -1, 1 }) do
		local edge = if s > 0 then tx1 else tx0
		local D, H = 28, 36
		for i = 0, D / B - 1 do
			local d = i * B + 2
			local t = math.floor(H * math.sqrt(1 - (d / D) ^ 2) / B + 0.5) * B
			local b = t - 8
			if b < 8 then
				b = 0
			end
			column("EntRoot", edge + s * i * B, edge + s * (i + 1) * B, b, t, tzF - 10, tzF - 2)
		end
		local A, AH, T = 12, 20, 8
		local start = edge + s * D
		for i = 0, 2 * A / B - 1 do
			local u = i * B + 2 - A
			local t = math.floor(AH * math.sqrt(math.max(0, 1 - (u / A) ^ 2)) / B + 0.5) * B
			local ia, ih = A - T, AH - T
			local b = 0
			if math.abs(u) < ia then
				b = math.floor(ih * math.sqrt(1 - (u / ia) ^ 2) / B + 0.5) * B
			end
			if b >= t then
				b = t - B
			end
			column("EntRoot", start + s * i * B, start + s * (i + 1) * B, b, math.max(t, B), tzF - 14, tzF - 6)
		end
		-- the root feet flare
		local fx = start + s * 2 * A
		column("EntRootFoot", fx, fx + s * B, 0, B, tzF - 14, tzF - 6)
		column("EntRootFoot", start - s * 2, start + s * 2, 0, B, tzF - 6, tzF - 2)
		-- low roots creeping out in front of the trunk corners (outside r 48)
		local cx = if s > 0 then tx1 else tx0
		box("EntLowRoot", cx, GY, tzF - 2, cx + s * 6, GY + 4, tzF + 2, DARK_LOG, nil, ent)
		box("EntLowRoot", cx + s * 4, GY, tzF + 2, cx + s * 10, GY + 3, tzF + 5, DARK_LOG, nil, ent)
		box("EntLowRoot", cx + s * 9, GY, tzF + 5, cx + s * 14, GY + 2, tzF + 8, DARK_LOG, nil, ent)
		-- the branch arm from high on the back of the trunk down to the ground, with splayed fingers
		local za, zb = tzB, tzB + 8
		local top = GY + 40
		local x = edge
		local flat = 0
		while flat < 3 do
			box("EntArm", x, top - 8, za, x + s * B, top, zb, DARK_LOG, nil, ent)
			x += s * B
			if top > GY + 8 then
				top -= B
			else
				flat += 1
			end
		end
		box("EntFinger", x, GY, za + 4, x + s * 10, GY + 4, zb, DARK_LOG, nil, ent)
		box("EntFinger", x, GY, za, x + s * 6, GY + 4, za + 4, "px_oak_log", nil, ent)
		if onIsland(x, zb + 8, 4) then
			box("EntFinger", x - s * 4, GY, zb, x, GY + 4, zb + 8, DARK_LOG, nil, ent)
		end
		if onIsland(x, za - 8, 4) then
			box("EntFinger", x - s * 8, GY, za - 8, x - s * 4, GY + 4, za, DARK_LOG, nil, ent)
		end
		-- limbs climbing from the trunk top into the crown
		for i = 0, 3 do
			local lx = edge + s * (i * 8)
			cube("EntLimb", lx + s * 4, TOP - 4 + i * 4, EZ - 4, 8, 8, 8, DARK_LOG, nil, ent)
		end
	end
	for i = 0, 2 do
		cube("EntLimb", EX + 2, TOP - 2 + i * 4, tzB - 4 - i * 8, 8, 8, 8, DARK_LOG, nil, ent)
	end
	task.wait()

	-- the crown: stepped leaf layers (decor) leaning back over the north rim, side blobs, drooping lobes, vines
	local CZ = EZ - 6
	local tint = Color3.fromRGB(190, 218, 172)
	local crown = folder("EntCrown", ent)
	leafLayer("EntLeaves", EX, CZ, 16, 12, TOP, TOP + 8, tint, crown, true)
	leafLayer("EntLeaves", EX, CZ, 20, 16, TOP + 8, TOP + 16, tint, crown, true)
	leafLayer("EntLeaves", EX, CZ, 16, 14, TOP + 16, TOP + 24, tint, crown, true)
	leafLayer("EntLeaves", EX, CZ, 10, 8, TOP + 24, TOP + 28, tint, crown, true)
	for _ = 1, 12 do
		local side = rng:NextInteger(1, 4)
		local bx, bz = EX + rng:NextInteger(-9, 9) * B, CZ + rng:NextInteger(-7, 7) * B
		if side == 1 then
			bx = EX + 40
		elseif side == 2 then
			bx = EX - 40
		elseif side == 3 then
			bz = CZ + 32
		else
			bz = CZ - 32
		end
		local sz = rng:NextInteger(3, 5) * B
		decor(cube("EntLeaves", bx, TOP + rng:NextInteger(1, 5) * B, bz, sz, rng:NextInteger(2, 3) * B, sz, "px_hedge", tint, crown))
	end
	for _, s in ipairs({ -1, 1 }) do
		decor(cube("EntLeaves", EX + s * 44, TOP - 6, CZ - 4, 16, 8, 20, "px_hedge", tint, crown))
		decor(cube("EntLeaves", EX + s * 50, TOP - 12, CZ - 2, 8, 4, 12, "px_hedge", tint, crown))
	end
	for _ = 1, 44 do
		local layer = rng:NextInteger(1, 3)
		local hw, hd, y = 32, 24, TOP
		if layer == 2 then
			hw, hd, y = 40, 32, TOP + 8
		elseif layer == 3 then
			hw, hd, y = 50, 10, TOP - 8 -- under the drooping lobes
		end
		local side = rng:NextInteger(1, 4)
		local vx, vz = EX + rng:NextNumber(-hw + 2, hw - 2), CZ + rng:NextNumber(-hd + 2, hd - 2)
		if side == 1 then
			vx = EX + hw - 1
		elseif side == 2 then
			vx = EX - hw + 1
		elseif side == 3 then
			vz = CZ + hd - 1
		else
			vz = CZ - hd + 1
		end
		local len = rng:NextInteger(8, 30)
		if inArena(vx, vz, 4) then
			len = math.min(len, y - (GY + 22)) -- keep the fight clear
		end
		vine(vx, y, vz, len, crown)
	end
	-- mushrooms and moss at the roots
	for _, m in ipairs({
		{ EX - 9, tzF + 3, true, 1.4 },
		{ EX + 9, tzF + 2, false, 1.2 },
		{ tx0 - 30, tzF + 1, true, 1.8 },
		{ tx0 - 26, tzF + 3, false, 1.2 },
		{ tx1 + 30, tzF + 1, true, 1.8 },
		{ tx1 + 34, tzF + 2, false, 1.4 },
		{ tx0 - 52, tzF - 2, false, 1.6 },
		{ tx1 + 52, tzF - 3, true, 1.4 },
		{ tx0 - 14, tzF - 4, false, 1 },
		{ tx1 + 14, tzF - 4, true, 1 },
	}) do
		mushroom(m[1], GY, m[2], m[3], m[4], ent)
	end
	for _, s in ipairs({ -1, 1 }) do
		local edge = if s > 0 then tx1 else tx0
		decor(box("RootMoss", edge + s * 4, GY, tzF - 2, edge + s * 26, GY + 0.3, tzF + 2, "px_hedge", nil, ent))
		decor(box("RootMoss", edge + s * 30, GY, tzF - 6, edge + s * 50, GY + 0.3, tzF - 2, "px_hedge", nil, ent))
	end
end
task.wait()

-- ================================================================ 5. the forest
do
	local forest = folder("Forest", grove)
	-- the hunter's hut (door south to the path) and the woodcutter's clearing are hand-placed
	do
		local f = folder("HunterHut", forest)
		local hx, hz = HUT.x, HUT.z
		local x0, x1, z0, z1 = hx - 10, hx + 10, hz - 8, hz + 8
		for _, cx in ipairs({ x0, x1 - B }) do
			for _, cz in ipairs({ z0, z1 - B }) do
				box("HutCorner", cx, GY, cz, cx + B, GY + 12, cz + B, "px_oak_log", nil, f)
			end
		end
		box("HutWall", x0 + B, GY, z0, x1 - B, GY + 12, z0 + B, WOOD, nil, f)
		box("HutWall", x0 + B, GY, z1 - B, hx - 2, GY + 12, z1, WOOD, nil, f)
		box("HutWall", hx + 2, GY, z1 - B, x1 - B, GY + 12, z1, WOOD, nil, f)
		box("HutLintel", hx - 2, GY + 8, z1 - B, hx + 2, GY + 12, z1, WOOD_DARK, nil, f)
		box("HutWall", x0, GY, z0 + B, x0 + B, GY + 12, z1 - B, WOOD, nil, f)
		box("HutWall", x1 - B, GY, z0 + B, x1, GY + 4, z1 - B, WOOD, nil, f)
		box("HutWall", x1 - B, GY + 8, z0 + B, x1, GY + 12, z1 - B, WOOD, nil, f)
		box("HutWall", x1 - B, GY + 4, z0 + B, x1, GY + 8, hz - 2, WOOD, nil, f)
		box("HutWall", x1 - B, GY + 4, hz + 2, x1, GY + 8, z1 - B, WOOD, nil, f)
		box("HutFloor", x0 + B, GY, z0 + B, x1 - B, GY + 0.3, z1 - B, WOOD_DARK, nil, f)
		box("HutRoof", x0 - 2, GY + 12, z0 - 2, x1 + 2, GY + 16, z1 + 2, WOOD_DARK, nil, f)
		box("HutRoof", x0 - 2, GY + 16, z0 + 2, x1 + 2, GY + 20, z1 - 2, WOOD_DARK, nil, f)
		box("HutRoof", x0 - 2, GY + 20, hz - 2, x1 + 2, GY + 24, hz + 2, WOOD_DARK, nil, f)
		box("HutRidge", x0 - 3, GY + 24, hz - 1, x1 + 3, GY + 25, hz + 1, "px_oak_log", nil, f)
		box("HutChimney", x0 + 2, GY + 12, z0 + 2, x0 + 6, GY + 28, z0 + 6, "px_cobblestone", nil, f)
		lantern(V(hx + 4.5, GY + 9.5, z1 + 1.2), f, false, BY + GY + 12)
		barrel(x0 + 6, GY, z0 + 6, f)
		crate(x1 - 6, GY, z0 + 6, f)
		textured(box("HutBed", x0 + 4, GY, hz - 2, x0 + 8, GY + 2, hz + 6, nil, nil, f), "px_white_wool", Color3.fromRGB(160, 50, 45))
		-- a drying rack with a hide beside the door, a stack of firewood on the east wall
		local rx = x1 + 6
		box("RackPost", rx, GY, z1 - 2, rx + 1, GY + 7, z1 - 1, WOOD_DARK, nil, f)
		box("RackPost", rx, GY, z1 - 11, rx + 1, GY + 7, z1 - 10, WOOD_DARK, nil, f)
		box("RackBar", rx, GY + 6.5, z1 - 11, rx + 1, GY + 7.3, z1 - 1, WOOD_DARK, nil, f)
		textured(decor(box("Hide", rx + 0.3, GY + 2, z1 - 9.5, rx + 0.7, GY + 6.5, z1 - 2.5, nil, nil, f)), "px_brown_wool")
		box("Firewood", x1, GY, z0 + 1, x1 + B, GY + 8, z0 + 7, "px_oak_log", nil, f)
	end
	do
		local f = folder("Woodcutter", forest)
		box("Stump", -198, GY, -118, -194, GY + 4, -114, "px_oak_log", nil, f)
		box("StumpTop", -197.8, GY + 4, -117.8, -194.2, GY + 4.15, -114.2, "px_oak_log_top", nil, f)
		local axe = at(-196, GY + 5.6, -116) * CFrame.Angles(0, 0.6, math.rad(22))
		textured(decor(part("AxeHandle", Vector3.new(0.4, 3.6, 0.4), axe, nil, nil, f)), "px_planks")
		textured(decor(part("AxeHead", Vector3.new(0.5, 1.2, 1.8), axe * CFrame.new(0, -1.5, 0.6), nil, nil, f)), "px_iron_block")
		box("ChoppingBlock", -192, GY, -124, -188, GY + 2.5, -120, "px_oak_log", nil, f)
		box("ChoppingTop", -191.8, GY + 2.5, -123.8, -188.2, GY + 2.6, -120.2, "px_oak_log_top", nil, f)
		box("LogPile", -174, GY, -120, -170, GY + 4, -108, "px_oak_log", nil, f)
		box("LogPile", -170, GY, -120, -166, GY + 4, -108, "px_oak_log", nil, f)
		box("LogPile", -172, GY + 4, -119, -168, GY + 8, -109, "px_oak_log", nil, f)
		box("LogEnd", -174, GY, -120.2, -166, GY + 4, -120, "px_oak_log_top", nil, f)
		box("Planks", -198, GY, -128, -192, GY + 1, -126, "px_planks", nil, f)
		box("Planks", -198, GY + 1, -128, -193, GY + 1.6, -126, "px_planks", nil, f)
		table.insert(OCC, { -196, -116, 4 })
		table.insert(OCC, { -170, -114, 8 })
	end
	task.wait()

	-- old trees: random spots with room (deterministic rng), spaced apart
	local trees = 0
	for _ = 1, 2000 do
		if trees >= 28 then
			break
		end
		local x = snap(rng:NextNumber(-212, -32))
		local z = snap(rng:NextNumber(-212, -88))
		if solidOk(x, z, 10) and not taken(x, z, 14) then
			local cw = pick({ 7, 7, 9 })
			bigTree(x, z, rng:NextInteger(6, 9) * B, cw, forest, rng:NextNumber() < 0.45)
			table.insert(OCC, { x, z, 10 })
			trees += 1
		end
	end
	task.wait()

	-- fallen logs with moss and a mushroom, mossy boulders
	local logs, rocks = 0, 0
	for _ = 1, 800 do
		if logs >= 6 and rocks >= 10 then
			break
		end
		local x = snap(rng:NextNumber(-210, -32))
		local z = snap(rng:NextNumber(-210, -90))
		if logs < 6 then
			local len = pick({ 12, 16, 20 })
			if solidOk(x, z, len / 2 + 2) and not taken(x, z, len / 2 + 2) then
				local f = folder("FallenLog", forest)
				local alongX = rng:NextNumber() < 0.5
				local hx, hz = if alongX then len / 2 else 2, if alongX then 2 else len / 2
				box("FallenLog", x - hx, GY, z - hz, x + hx, GY + B, z + hz, pick({ DARK_LOG, "px_oak_log" }), nil, f)
				decor(box("LogMoss", x - hx * 0.6, GY + B, z - hz * 0.6, x + hx * 0.4, GY + B + 0.3, z + hz * 0.4, "px_hedge", nil, f))
				mushroom(x + (if alongX then hx * 0.6 else 0), GY + B, z + (if alongX then 0 else hz * 0.6), rng:NextNumber() < 0.5, 0.8, f)
				table.insert(OCC, { x, z, len / 2 + 2 })
				logs += 1
				continue
			end
		end
		if rocks < 10 and solidOk(x, z, 6) and not taken(x, z, 6) then
			local f = folder("Boulder", forest)
			local big = rng:NextNumber() < 0.5
			local s = if big then 2 * B else B
			box("Boulder", x - s / 2 - 2, GY, z - s / 2, x + s / 2 - 2, GY + s, z + s / 2, "px_mossy_cobblestone", nil, f)
			box("Boulder", x + s / 2 - 2, GY, z - 2, x + s / 2 + 2, GY + B, z + 2, pick({ "px_cobblestone", "px_mossy_cobblestone" }), nil, f)
			if big then
				box("Boulder", x - 4, GY + s, z - 2, x, GY + s + B, z + 2, "px_mossy_cobblestone", nil, f)
			end
			decor(box("BoulderMoss", x - s / 2 - 2, GY + s, z - s / 2, x - 2, GY + s + 0.3, z + s / 2, "px_hedge", nil, f))
			table.insert(OCC, { x, z, 6 })
			rocks += 1
		end
	end
	task.wait()

	-- bushes and ferns (hedge blocks) round the trees and along the paths, mushrooms in the shade
	local bushes, shrooms = 0, 0
	for _ = 1, 1500 do
		if bushes >= 64 and shrooms >= 30 then
			break
		end
		local x = snap(rng:NextNumber(-212, -30)) + 2
		local z = snap(rng:NextNumber(-212, -88)) + 2
		if bushes < 64 and solidOk(x, z, 3) and not taken(x, z, 3) then
			local f = folder("Bush", forest)
			local h = pick({ B, B, B / 2 })
			cube("Bush", x, GY + h / 2, z, B, h, B, "px_hedge", pick(LEAF_TINTS), f)
			if rng:NextNumber() < 0.5 then
				local d = pick({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } })
				cube("Bush", x + d[1] * B, GY + B / 4, z + d[2] * B, B, B / 2, B, "px_hedge", pick(LEAF_TINTS), f)
			end
			if rng:NextNumber() < 0.25 then
				cube("Bush", x, GY + h + B / 4, z, B, B / 2, B, "px_hedge", nil, f)
			end
			table.insert(OCC, { x, z, 4 })
			bushes += 1
		elseif shrooms < 30 and solidOk(x, z, 2) and not taken(x, z, 2) then
			local red = rng:NextNumber() < 0.5
			mushroom(x, GY, z, red, pick({ 0.8, 1, 1.2 }), forest)
			if rng:NextNumber() < 0.5 then
				mushroom(x + 3, GY, z + 2, red, 0.7, forest)
			end
			table.insert(OCC, { x, z, 2 })
			shrooms += 1
		end
	end
	print(("[build-farm] grove forest: %d trees, %d logs, %d boulders, %d bushes, %d mushroom spots"):format(trees, logs, rocks, bushes, shrooms))
end
task.wait()

-- ================================================================ 6. grass curtains and roots on the cliffs of the grove
do
	local f = folder("CliffCurtains", grove)
	for x = -240, -32, 8 do
		for z = -240, -72, 8 do
			local mx, mz = x + 4, z + 4
			if mx < -24 and onIsland(mx, mz) and groundY(mx, mz) == GY then
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local nx, nz = mx + d[1] * 8, mz + d[2] * 8
					local outer = not onIsland(nx, nz)
					local low = not outer and groundY(nx, nz) == 0
					local fx, fz = mx + d[1] * 4, mz + d[2] * 4
					if (outer or low) and not inStairCorridor(fx, fz) and rng:NextNumber() < (if outer then 0.4 else 0.65) then
						local len = if outer then rng:NextInteger(3, 7) * B else rng:NextInteger(1, 3) * B
						local w = pick({ 8, 8, 4 })
						local o = if w == 4 then pick({ -2, 2 }) else 0
						local px, pz = fx + d[1] * 0.8, fz + d[2] * 0.8
						local sx, sz = 0.4, w
						if d[2] ~= 0 then
							px, sx, sz = mx + o, w, 0.4
						else
							pz = mz + o
						end
						local p = textured(decor(part("GrassCurtain", Vector3.new(sx, len, sz), at(px, GY - len / 2, pz), nil, nil, f)), "px_hedge")
						p.CastShadow = false
						if rng:NextNumber() < 0.4 then
							-- a hanging root strand a little further out
							local rl = len + rng:NextInteger(1, 2) * B
							local t = rng:NextNumber(-3, 3)
							local rx, rz = fx + d[1] * 1.4, fz + d[2] * 1.4
							if d[2] ~= 0 then
								rx = mx + t
							else
								rz = mz + t
							end
							textured(decor(part("HangingRoot", Vector3.new(1, rl, 1), at(rx, GY - rl / 2, rz), nil, nil, f)), DARK_LOG)
						end
					end
				end
			end
		end
	end
end
print(("[build-farm] grove: %d parts"):format(count - count0))
