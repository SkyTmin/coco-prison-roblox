--!nocheck
-- ================================================================ inside_out: the sky round the islands
-- 1. Vine curtains on every island rim: dark-red strands (1 block wide, 2..8 long, a second shorter strand in front
--    of many) hang down the outer faces of the rim cells, 0.6 stud off the cliff; crimson carpets spill over the top
--    edge; weeping strands hang from the cone undersides. Nothing on the path landings (CORRIDORS).
-- 2. Floating upside-down cone islets (the signature look): a flat top (dead grass, dirt or crimson nylium, now and
--    then a dead bush, a broken lamp post, a telephone pole, a ruined wall corner or a tilted mailbox), stepped
--    layers of dirt and dark rock shrinking to a point, red vines from the edges. Far ones are bigger.
-- 3. Torn-off asphalt road chunks (yellow dashes, a dirt cone under each, some tilted) and floating boulders.
-- 4. Red zig-zag lightning high at the edge of the sky; slow red embers rising under the main island and the arena.
-- Every floater keeps 24 studs off every island (groundY) and out of the path corridors; all of it is decor.
local sky = folder("Sky")
local startCount = count
local ROCK_TOP_T = Color3.fromRGB(150, 108, 100) -- core's rockTopTint
local VINES = { VINE_RED, VINE_DARK }
-- the walkable paths other parts build through the void: x0, x1, z0, z1, y0, y1, pad
local CORRIDORS = {
	{ -20, 20, -275, -185, -20, 70, 12 }, -- the sky road up to the mansion
	{ -20, 20, 185, 255, -30, 20, 12 }, -- the bridge down to the arena
	{ -140, -100, 180, 245, -20, 20, 12 }, -- the west islet bridge
	{ 100, 140, 180, 245, -20, 20, 12 }, -- the east islet bridge
	{ -120, -76, 262, 300, -30, 20, 16 }, -- the west arch islet → arena
	{ 76, 120, 262, 300, -30, 20, 16 }, -- the east arch islet → arena
}
-- does the box x0..x1, z0..z1, y0..y1 touch a corridor (with its pad)?
local function inCorridor(x0, x1, z0, z1, y0, y1)
	for _, c in ipairs(CORRIDORS) do
		local p = c[7]
		if x1 >= c[1] - p and x0 <= c[2] + p and z1 >= c[3] - p and z0 <= c[4] + p and y1 >= c[5] - p and y0 <= c[6] + p then
			return true
		end
	end
	return false
end
-- a hanging vine strand: a world-aligned box (local corners), the colour by index
local function vine(name, x0, y0, z0, x1, y1, z1, ci, parent)
	return decor(box(name, x0, y0, z0, x1, y1, z1, "px_nether_wart", VINES[(ci % 2) + 1], parent))
end

-- ================================================================ 1. the vine fringe on the island rims
do
	local fringe = folder("RimVines", sky)
	local c0 = count
	local C = 8
	-- core's rockDepth (10-core is wrapped in its own do … end, so it is replicated here)
	local function rockDepth(x, z)
		local y = groundY(x, z)
		local jag = (n2(x, z, 7.7, 0.09) + 0.5) * 22 + n2(x, z, 3.1, 0.035) * 14
		local rr, deep
		if y == 0 then
			rr = ((math.abs(x) / MAIN.rx) ^ 4 + (math.abs(z) / MAIN.rz) ^ 4) ^ 0.25
			deep = 150
		elseif y == MANSION.y then
			rr, deep = math.sqrt((x - MANSION.x) ^ 2 + (z - MANSION.z) ^ 2) / MANSION.r, 96
		elseif y == ARENA.y then
			rr, deep = math.sqrt((x - ARENA.x) ^ 2 + (z - ARENA.z) ^ 2) / ARENA.islandR, 80
		else
			local s = if x < 0 then ISLETS[1] else ISLETS[2]
			rr, deep = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) / s.r, 36
		end
		rr = math.clamp(rr, 0, 1)
		local d = 10 + (1 - rr) ^ 1.4 * deep
		if rr > 0.82 then
			d += jag
		end
		return math.max(8, math.floor(d / 16 + 0.5) * 16)
	end
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local strands, carpets, weeps, ci = 0, 0, 0, 0
	-- one strand down a face: the face is perpendicular to x (dx ~= 0) at `face`, or to z; a0..a1 along it
	local function faceStrand(dx, dz, face, a0, a1, top, len, off, thick)
		ci += 1
		local o0, o1 = face + (dx + dz) * off, face + (dx + dz) * (off + thick)
		if dx ~= 0 then
			vine("RimVine", o0, top - len, a0, o1, top, a1, ci, fringe)
		else
			vine("RimVine", a0, top - len, o0, a1, top, o1, ci, fringe)
		end
		strands += 1
	end
	for z = -408, 408 - C, C do
		for x = -240, 240 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			local gy = groundY(cx, cz)
			if gy ~= nil and not inCorridor(cx - 4, cx + 4, cz - 4, cz + 4, gy, gy) then
				local depth = rockDepth(cx, cz)
				for _, d in ipairs(DIRS) do
					local dx, dz = d[1], d[2]
					if groundY(cx + dx * C, cz + dz * C) == nil then
						local face = if dx ~= 0 then cx + dx * 4 else cz + dz * 4
						local along = if dx ~= 0 then cz else cx
						-- two 1-block strands per 8-stud face (some skipped for a ragged edge)
						for k = 0, 1 do
							if rng:NextNumber() > 0.2 then
								local a0 = along - 4 + k * B
								local top = gy - rng:NextNumber(0.05, 0.4)
								-- longer where the rock below is deep; a few run past the rock bottom
								local maxLen = math.clamp(math.floor((depth + 4) / B) + 2, 3, 8)
								local len = rng:NextInteger(2, maxLen) * B
								local thick = rng:NextNumber(0.7, 1.5)
								faceStrand(dx, dz, face, a0, a0 + B, top, len, 0.6, thick)
								-- a shorter strand in front, shifted half a block: a thick curtain
								if rng:NextNumber() < 0.6 then
									local s = math.clamp(a0 + (if rng:NextNumber() < 0.5 then -2 else 2), along - 4, along + 4 - B)
									local len2 = rng:NextInteger(1, math.max(1, len / B - 1)) * B
									faceStrand(dx, dz, face, s, s + B, top - rng:NextNumber(0.5, 2), len2, 0.6 + thick, rng:NextNumber(0.6, 1))
								end
							end
						end
						-- crimson vine carpet spilling over the top edge (not on the asphalt)
						if rng:NextNumber() < 0.28 and not (gy == 0 and onStreet(cx, cz, 2)) then
							local w = rng:NextInteger(1, 2) * B
							local a0 = math.clamp(along - 4 + rng:NextInteger(0, 1) * B, along - 4, along + 4 - w)
							local inner = face - (dx + dz) * B * rng:NextInteger(1, 2)
							local outer = face + (dx + dz) * 1.8
							if dx ~= 0 then
								decor(box("VineCarpet", inner, gy, a0, outer, gy + 0.4, a0 + w, "px_crimson_nylium", nil, fringe))
							else
								decor(box("VineCarpet", a0, gy, inner, a0 + w, gy + 0.4, outer, "px_crimson_nylium", nil, fringe))
							end
							carpets += 1
						end
					end
				end
				-- weeping strands from the underside of the hanging rock (longer toward the deep tip)
				if rng:NextNumber() < 0.045 then
					local bottom = gy - B - depth
					local len = rng:NextInteger(2, 4 + math.floor(depth / 40)) * B
					local ox, oz = rng:NextInteger(-1, 1) * 2, rng:NextInteger(-1, 1) * 2
					ci += 1
					if rng:NextNumber() < 0.5 then
						vine("WeepingVine", cx + ox - 2, bottom - len, cz + oz - 0.6, cx + ox + 2, bottom + 0.2, cz + oz + 0.6, ci, fringe)
					else
						vine("WeepingVine", cx + ox - 0.6, bottom - len, cz + oz - 2, cx + ox + 0.6, bottom + 0.2, cz + oz + 2, ci, fringe)
					end
					weeps += 1
				end
			end
		end
		if z % 64 == 0 then
			task.wait()
		end
	end
	print(("[build-inside-out] sky: rim strands %d, carpets %d, weeping %d (%d parts)"):format(strands, carpets, weeps, count - c0))
end
task.wait()

-- ================================================================ floaters: placement shared by cones, chunks, boulders
local taken = {} -- { x, z, r, y0, y1 }
-- no island cell within `half` + 24 studs of (x, z)
local function clearOfIslands(x, z, half)
	if groundY(x, z) ~= nil then
		return false
	end
	local e = half + 24
	local n = math.max(1, math.ceil(2 * e / 8))
	for i = 0, n do
		for j = 0, n do
			if groundY(x - e + 2 * e * i / n, z - e + 2 * e * j / n) ~= nil then
				return false
			end
		end
	end
	return true
end
-- a free spot for a floater `half` studs wide (horizontal half-size), reaching `down` below and `up` above its y
local function findSpot(half, down, up, yMin, yMax, far)
	for attempt = 1, 400 do
		if attempt % 100 == 0 then
			task.wait()
		end
		local x, z = rng:NextNumber(-420, 420), rng:NextNumber(-520, 520)
		local y = rng:NextNumber(yMin, yMax)
		local ok = (not far or math.abs(x) > 330 or math.abs(z) > 450)
			and not inCorridor(x - half, x + half, z - half, z + half, y - down, y + up)
			and clearOfIslands(x, z, half)
		if ok then
			for _, t in ipairs(taken) do
				local dh = math.sqrt((x - t[1]) ^ 2 + (z - t[2]) ^ 2)
				if dh < t[3] + half + 10 and y + up + 8 > t[4] and y - down - 8 < t[5] then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(taken, { x, z, half, y - down, y + up })
			return x, y, z
		end
	end
	return nil
end
-- the rock of a hanging layer `dep` studs under the top of a floater `total` deep: dirt above, dark rock below
local function rockOf(dep, total)
	if dep < math.max(8, total * 0.4) then
		return "px_dirt", ROCK_TOP_T
	end
	return "px_blackstone", ROCK_RED
end

-- ================================================================ 2. the floating cone islets
do
	local cones = folder("FloatingCones", sky)
	local c0 = count
	local WOOD_D = "px_dark_oak_planks"
	local POLE = "px_dark_oak_log"
	-- the props on a cone top (at local x, y, z: the top surface); w = top width in blocks
	local function deadBush(x, y, z, f)
		decor(cube("DeadBush", x, y + 1.5, z, 0.8, 3, 0.8, POLE, Color3.fromRGB(110, 86, 74), f))
		local base = V(x, y + 2, z)
		for i = 1, 3 do
			local a = rng:NextNumber(0, 2 * math.pi)
			local tip = base + Vector3.new(math.cos(a) * 1.8, rng:NextNumber(1, 2.4), math.sin(a) * 1.8)
			decor(beam("DeadTwig", base + Vector3.new(0, i * 0.3, 0), tip, 0.4, Color3.fromRGB(78, 58, 50), f, Enum.Material.Wood))
		end
	end
	local function brokenLamp(x, y, z, f)
		decor(cube("LampBase", x, y + 0.5, z, B, 1, B, "px_stone_bricks", COBBLE, f))
		local cf = at(x, y + 1, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(0.15, 0.35))
		textured(decor(part("LampPost", Vector3.new(1, 8, 1), cf * CFrame.new(0, 4, 0), nil, nil, f)), WOOD_D)
		textured(decor(part("LampArm", Vector3.new(1, 1, 3), cf * CFrame.new(0, 7.5, -1.5), nil, nil, f)), WOOD_D)
		decor(part("DeadLantern", Vector3.new(1.3, 1.5, 1.3), cf * CFrame.new(0, 6, -2.6), Color3.fromRGB(45, 42, 46), Enum.Material.Metal, f))
	end
	local function phonePole(x, y, z, f)
		local cf = at(x, y, z) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 6.28), rng:NextNumber(-0.12, 0.12))
		textured(decor(part("PhonePole", Vector3.new(1.2, 14, 1.2), cf * CFrame.new(0, 7, 0), nil, nil, f)), POLE)
		textured(decor(part("PoleBar", Vector3.new(7, 0.8, 0.8), cf * CFrame.new(0, 12.4, 0), nil, nil, f)), WOOD_D)
		textured(decor(part("PoleBar", Vector3.new(5, 0.8, 0.8), cf * CFrame.new(0, 10.6, 0), nil, nil, f)), WOOD_D)
		-- a torn wire dangling from one end
		decor(part("TornWire", Vector3.new(0.2, 5, 0.2), cf * CFrame.new(3.2, 9.9, 0) * CFrame.Angles(0, 0, 0.25), Color3.fromRGB(30, 28, 30), nil, f))
	end
	local function ruinedWall(x, y, z, f)
		local v, t = pick({ "px_stone_bricks", "px_cobblestone" }), COBBLE
		local h = rng:NextInteger(2, 3) * B
		decor(box("RuinWall", x - B, y, z - B, x + B, y + h, z, v, t, f))
		decor(box("RuinWall", x - B, y, z, x, y + h - B, z + B, v, t, f))
		decor(box("RuinWall", x, y + h, z - B, x + B, y + h + B, z, v, t, f)) -- a broken top block
	end
	local function mailbox(x, y, z, f)
		local cf = at(x, y, z) * CFrame.Angles(rng:NextNumber(0.2, 0.4), rng:NextNumber(0, 6.28), 0)
		textured(decor(part("MailPost", Vector3.new(0.6, 3.4, 0.6), cf * CFrame.new(0, 1.7, 0), nil, nil, f)), WOOD_D)
		decor(part("Mailbox", Vector3.new(1.4, 1.4, 2.4), cf * CFrame.new(0, 4, 0), Color3.fromRGB(70, 80, 108), Enum.Material.Metal, f))
		decor(part("MailFlag", Vector3.new(0.15, 1, 0.4), cf * CFrame.new(0.8, 4.6, 0.6), Color3.fromRGB(170, 36, 36), nil, f))
	end
	local PROPS = { deadBush, deadBush, brokenLamp, phonePole, phonePole, ruinedWall, mailbox }

	-- one cone: top w × d blocks at (x, y, z) = the centre of its top surface
	local function cone(x, y, z, w, d, layers, f)
		local cf = folder("Cone", f)
		local n = rng:NextNumber()
		local topV, topT = "px_grass_top", DEAD_GRASS
		if n < 0.35 then
			topV, topT = "px_crimson_nylium", nil
		elseif n < 0.55 then
			topV, topT = "px_dirt", Color3.fromRGB(120, 96, 88)
		end
		local hx, hz = w * B / 2, d * B / 2
		decor(box("ConeTop", x - hx, y - B, z - hz, x + hx, y, z + hz, topV, topT, cf))
		-- the stepped layers: each shrinks, its edges stay on the block grid of the top
		local heights, total = {}, B
		for k = 1, layers do
			heights[k] = if w >= 6 and rng:NextNumber() < 0.5 then 2 * B else B
			total += heights[k]
		end
		local tipLen = rng:NextInteger(1, 2) * B
		total += tipLen
		local yTop = y - B
		local ix0, ix1, iz0, iz1 = 0, w, 0, d -- the previous layer in block indices
		for k = 1, layers do
			local f01 = 1 - k / (layers + 1)
			local lw = math.max(1, math.floor(w * f01 + 0.5))
			local ld = math.max(1, math.floor(d * f01 + 0.5))
			lw, ld = math.min(lw, ix1 - ix0), math.min(ld, iz1 - iz0)
			local sx = ix0 + math.floor((ix1 - ix0 - lw) / 2 + rng:NextNumber(-0.5, 0.99))
			local sz = iz0 + math.floor((iz1 - iz0 - ld) / 2 + rng:NextNumber(-0.5, 0.99))
			sx = math.clamp(sx, ix0, ix1 - lw)
			sz = math.clamp(sz, iz0, iz1 - ld)
			local v, t = rockOf(y - yTop, total)
			local yb = yTop - heights[k]
			decor(box("ConeRock", x - hx + sx * B, yb, z - hz + sz * B, x - hx + (sx + lw) * B, yTop, z - hz + (sz + ld) * B, v, t, cf))
			-- a ragged nub: one more block row on a side, shorter (within the layer above)
			if lw >= 2 and rng:NextNumber() < 0.55 then
				local side = rng:NextInteger(1, 4)
				local nb = { sx, sz, sx + lw, sz + ld }
				if side == 1 and sx > ix0 then
					nb = { sx - 1, sz, sx, sz + math.max(1, ld - 1) }
				elseif side == 2 and sx + lw < ix1 then
					nb = { sx + lw, sz + 1, sx + lw + 1, sz + ld }
				elseif side == 3 and sz > iz0 then
					nb = { sx + 1, sz - 1, sx + lw, sz }
				elseif side == 4 and sz + ld < iz1 then
					nb = { sx, sz + ld, sx + math.max(1, lw - 1), sz + ld + 1 }
				else
					nb = nil
				end
				if nb then
					decor(box("ConeRock", x - hx + nb[1] * B, yTop - B, z - hz + nb[2] * B, x - hx + nb[3] * B, yTop, z - hz + nb[4] * B, v, t, cf))
				end
			end
			ix0, ix1, iz0, iz1 = sx, sx + lw, sz, sz + ld
			yTop = yb
		end
		-- the point: one block column
		local px = ix0 + rng:NextInteger(0, ix1 - ix0 - 1)
		local pz = iz0 + rng:NextInteger(0, iz1 - iz0 - 1)
		decor(box("ConeTip", x - hx + px * B, yTop - tipLen, z - hz + pz * B, x - hx + (px + 1) * B, yTop, z - hz + (pz + 1) * B, "px_blackstone", ROCK_RED, cf))
		-- red vines from the top edges, hanging free past the shrinking layers
		local ci = rng:NextInteger(0, 1)
		for side = 1, 4 do
			local along = if side <= 2 then w else d
			local nv = math.clamp(math.floor(along / 2 + rng:NextNumber(0, 1.5)), 1, 4)
			for _ = 1, nv do
				local a = rng:NextInteger(0, along - 1) * B
				local len = rng:NextInteger(2, math.max(3, math.floor(total / B) + 1)) * B
				local top = y - rng:NextNumber(0.05, 0.5)
				local th = rng:NextNumber(0.7, 1.3)
				ci += 1
				if side == 1 then
					vine("ConeVine", x - hx - 0.6 - th, top - len, z - hz + a, x - hx - 0.6, top, z - hz + a + B, ci, cf)
				elseif side == 2 then
					vine("ConeVine", x + hx + 0.6, top - len, z - hz + a, x + hx + 0.6 + th, top, z - hz + a + B, ci, cf)
				elseif side == 3 then
					vine("ConeVine", x - hx + a, top - len, z - hz - 0.6 - th, x - hx + a + B, top, z - hz - 0.6, ci, cf)
				else
					vine("ConeVine", x - hx + a, top - len, z + hz + 0.6, x - hx + a + B, top, z + hz + 0.6 + th, ci, cf)
				end
			end
		end
		-- a crimson carpet over one top edge
		if topV ~= "px_crimson_nylium" and rng:NextNumber() < 0.6 then
			local cw = math.max(1, math.floor(w / 2)) * B
			local cx0 = x - hx + rng:NextInteger(0, w - cw / B) * B
			decor(box("VineCarpet", cx0, y, z - hz - 1.6, cx0 + cw, y + 0.4, z - hz + B, "px_crimson_nylium", nil, cf))
		end
		-- a prop from the dead town on bigger tops
		if math.min(w, d) >= 3 and rng:NextNumber() < 0.5 then
			local ox = (rng:NextInteger(0, w - 1) - (w - 1) / 2) * B * 0.5
			local oz = (rng:NextInteger(0, d - 1) - (d - 1) / 2) * B * 0.5
			pick(PROPS)(x + ox, y, z + oz, cf)
		end
		return total
	end

	local made, big = 0, 0
	for i = 1, 56 do
		local isBig = i <= 6
		local w = if isBig then rng:NextInteger(8, 10) else rng:NextInteger(2, 7)
		local d = math.clamp(w + rng:NextInteger(-1, 1), 2, 10)
		local layers = math.clamp(math.floor(math.max(w, d) / 2) + rng:NextInteger(1, 2), 3, 6)
		local half = math.max(w, d) * B / 2 + 2
		local down = B * (layers * (if w >= 6 then 2 else 1) + 3)
		local yMin, yMax = -80, 140
		if not isBig and rng:NextNumber() < 0.6 then
			yMin, yMax = -40, 90 -- most of them near the town's eye line
		end
		local x, y, z = findSpot(half, down, 16, yMin, yMax, isBig)
		if x then
			-- snap to the block grid so the tops line up like blocks
			cone(snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2, w, d, layers, cones)
			made += 1
			if isBig then
				big += 1
			end
		end
		if i % 8 == 0 then
			task.wait()
		end
	end
	print(("[build-inside-out] sky: cones %d (big %d), %d parts"):format(made, big, count - c0))
end
task.wait()

-- ================================================================ 3. torn-off road chunks and boulders
do
	local junk = folder("FloatingJunk", sky)
	local c0 = count
	local chunks, boulders = 0, 0
	-- a world-aligned-in-yaw vertical vine at world point p (yaw = the chunk's)
	local function hangVine(p, yaw, len, ci, f)
		local c = VINES[(ci % 2) + 1]
		local s = decor(part("ChunkVine", Vector3.new(B, len, 1), CFrame.new(p - Vector3.new(0, len / 2, 0)) * CFrame.Angles(0, yaw, 0), c, nil, f))
		textured(s, "px_nether_wart", c)
	end
	local function roadChunk(x, y, z, L, W, f)
		local cf0 = folder("RoadChunk", f)
		local yaw = rng:NextNumber(0, 2 * math.pi)
		local tilt = math.rad(rng:NextNumber(0, 25))
		local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(rng:NextNumber(-1, 1) * tilt, 0, rng:NextNumber(-1, 1) * tilt * 0.6)
		local lx, lz = W * B, L * B
		local slab = decor(part("Asphalt", Vector3.new(lx, B, lz), cf * CFrame.new(0, -B / 2, 0), nil, nil, cf0))
		textured(slab, "px_smooth_stone", ASPHALT)
		-- a broken end: a shorter piece of the next row
		local bw = rng:NextInteger(1, W - 1)
		local bx = (-W / 2 + bw / 2 + rng:NextInteger(0, W - bw)) * B
		textured(decor(part("Asphalt", Vector3.new(bw * B, B, B), cf * CFrame.new(bx, -B / 2, lz / 2 + B / 2), nil, nil, cf0)), "px_smooth_stone", ASPHALT)
		-- the yellow dashes down the middle (or a double line along one side of a wide chunk)
		local lineX = if W >= 4 and rng:NextNumber() < 0.5 then 0 else (if W % 2 == 1 then 0 else B / 2)
		for k = 0, L - 1, 2 do
			local zc = -lz / 2 + (k + 0.5) * B
			local dash = decor(part("RoadLine", Vector3.new(0.8, 0.12, 3), cf * CFrame.new(lineX, 0.06, zc), nil, nil, cf0))
			textured(dash, "px_yellow_wool", LINE_YELLOW)
		end
		-- a kerb on one side now and then
		if rng:NextNumber() < 0.4 then
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			textured(decor(part("Kerb", Vector3.new(B, 1, lz), cf * CFrame.new(side * (lx / 2 + B / 2), 0.5, 0), nil, nil, cf0)), "px_smooth_stone", COBBLE)
		end
		-- the dirt and rock torn off with it, stepped down to a point
		local layers = rng:NextInteger(2, 3)
		local total = B * (layers + 2)
		local yTop = -B
		for k = 1, layers do
			local f01 = 1 - k / (layers + 1)
			local sw = math.max(1, math.floor(W * f01 + 0.5)) * B
			local sl = math.max(1, math.floor(L * f01 + 0.5)) * B
			local v, t = rockOf(-yTop, total)
			textured(decor(part("ChunkRock", Vector3.new(sw, B, sl), cf * CFrame.new(rng:NextInteger(-1, 1) * 2 * (if sw < lx then 1 else 0), yTop - B / 2, rng:NextInteger(-1, 1) * 2), nil, nil, cf0)), v, t)
			yTop -= B
		end
		textured(decor(part("ChunkTip", Vector3.new(B, 2 * B, B), cf * CFrame.new(0, yTop - B, 0), nil, nil, cf0)), "px_blackstone", ROCK_RED)
		-- vines hanging from the long edges
		for i = 1, rng:NextInteger(2, 4) do
			local side = if i % 2 == 0 then -1 else 1
			local p = (cf * CFrame.new(side * (lx / 2 + 1.2), -0.3, rng:NextNumber(-lz / 2 + 2, lz / 2 - 2))).Position
			hangVine(p, yaw, rng:NextInteger(2, 6) * B, i, cf0)
		end
	end
	local function boulder(x, y, z, f)
		local bf = folder("Boulder", f)
		local v, t = "px_blackstone", ROCK_RED
		if rng:NextNumber() < 0.4 then
			v, t = "px_cobblestone", Color3.fromRGB(128, 114, 116)
		end
		local s = rng:NextInteger(2, 4)
		local h = s * B / 2
		decor(cube("Boulder", x, y, z, s * B, s * B, s * B, v, t, bf))
		-- stepped lumps on its faces
		for _ = 1, rng:NextInteger(2, 4) do
			local ls = rng:NextInteger(1, math.max(1, s - 1)) * B
			local ax = rng:NextInteger(1, 3)
			local sg = if rng:NextNumber() < 0.5 then -1 else 1
			local ox, oy, oz = rng:NextInteger(-1, 1) * 2, rng:NextInteger(-1, 1) * 2, rng:NextInteger(-1, 1) * 2
			if ax == 1 then
				ox = sg * (h + ls / 2 - B / 2)
			elseif ax == 2 then
				oy = sg * (h + ls / 2 - B / 2)
			else
				oz = sg * (h + ls / 2 - B / 2)
			end
			decor(cube("BoulderLump", x + ox, y + oy, z + oz, ls, ls, ls, v, t, bf))
		end
		if rng:NextNumber() < 0.6 then
			decor(box("VineCarpet", x - h, y + h, z - h, x - h + B, y + h + 0.4, z + h, "px_crimson_nylium", nil, bf))
			vine("BoulderVine", x - h - 1.6, y + h - rng:NextInteger(3, 6) * B, z - B, x - h - 0.6, y + h, z, 1, bf)
		end
	end
	for _ = 1, 9 do
		local L, W = rng:NextInteger(4, 7), rng:NextInteger(3, 4)
		local x, y, z = findSpot(L * B / 2 + 4, 6 * B, 8, -60, 120)
		if x then
			roadChunk(x, y, z, L, W, junk)
			chunks += 1
		end
	end
	task.wait()
	for _ = 1, 9 do
		local x, y, z = findSpot(16, 12, 12, -80, 140)
		if x then
			boulder(snap(x), snap(y), snap(z), junk)
			boulders += 1
		end
	end
	print(("[build-inside-out] sky: road chunks %d, boulders %d, %d parts"):format(chunks, boulders, count - c0))
end
task.wait()

-- ================================================================ 4. red lightning at the edge of the sky, embers below
do
	local bolts = folder("RedLightning", sky)
	local c0 = count
	-- high and far from the islands, round the edge of the volume
	local ANCHORS = { { -405, 240, -170 }, { 400, 215, 250 }, { -270, 255, 505 }, { 310, 190, -480 }, { 60, 235, -515 }, { -390, 175, 330 } }
	for _, a in ipairs(ANCHORS) do
		local p = V(a[1], a[2], a[3])
		local segs = rng:NextInteger(4, 7)
		local dir = 1
		for k = 1, segs do
			dir = -dir
			local q = p + Vector3.new(dir * rng:NextNumber(4, 10), -rng:NextNumber(10, 18), rng:NextNumber(-6, 6))
			local s = decor(beam("Bolt", p, q, 1.5, GLOW_RED, bolts, Enum.Material.Neon))
			s.CastShadow = false
			-- a short fork off the middle of the bolt
			if k == 2 and rng:NextNumber() < 0.7 then
				local fq = q + Vector3.new(-dir * rng:NextNumber(8, 14), -rng:NextNumber(8, 14), rng:NextNumber(-5, 5))
				local fs = decor(beam("BoltFork", q, fq, 1, GLOW_RED, bolts, Enum.Material.Neon))
				fs.CastShadow = false
			end
			p = q
		end
	end
	-- slow red embers rising toward the hanging rock of the main island and the arena island
	for _, e in ipairs({ { 0, -200, 0, 260, 240 }, { ARENA.x, -140, ARENA.z, 110, 110 } }) do
		local src = decor(part("EmberRise", Vector3.new(e[4], 1, e[5]), at(e[1], e[2], e[3]), nil, nil, bolts))
		src.Transparency = 1
		src.CastShadow = false
		emitter(src, {
			Rate = 5,
			Lifetime = NumberRange.new(18, 26),
			Speed = NumberRange.new(2, 4),
			SpreadAngle = Vector2.new(15, 15),
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new(0.35),
			Color = ColorSequence.new(Color3.fromRGB(255, 70, 40)),
			LightEmission = 1,
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.3), NumberSequenceKeypoint.new(0.85, 0.4), NumberSequenceKeypoint.new(1, 1) }),
		})
	end
	print(("[build-inside-out] sky: lightning and embers, %d parts"):format(count - c0))
end
print(("[build-inside-out] sky: %d parts in all"):format(count - startCount))
