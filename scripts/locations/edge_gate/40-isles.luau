--!nocheck
-- ================================================================ edge_gate: the isles
-- 1. The west island WEST (-228, 40): the chorus plantation like a vineyard. The main walkway (end stone bricks, 5
--    blocks) z 28..48 from the bridge landing (x -180) west to a purpur gazebo with a crystal at (-258, 38); rows of
--    chorus plants run north (from z 56) and south (from z 20) of it at x -246 + 12k (every 3 blocks), paved aisles
--    between them, purpur trellis posts with lines, baskets of chorus fruit, end rods along the walkway; a gardener's
--    shed (dark oak + purpur) in the north-west at ~(-244, 74).
-- 2. The east island EAST (210, -28): a stepped end stone mound x 184..236, z -52..-4 and on it a blocky dragon head
--    (black blocks, magenta Neon eyes, open jaw, horns) facing west down the bridge; snout x 192, skull x 212..232,
--    neck to x 240; a tall obsidian obelisk north of it at ~(232, -60); crystal spires, shulker boxes, chorus plants
--    and a broken end gateway frame on the free ground. The walkway z -40..-16 from the bridge (x 172) to the mound.
-- 3. Purpur stalactites under every island (core's 8-stud cells, from the bottom of each column) and end stone lumps
--    on the rim faces; none under the grand stair and the bridge landings.
-- 4. Floating end stone islets round the cluster (stepped cones, purpur fringe, a prop on top), 24+ studs off every
--    island and out of the stair and bridge corridors; a few big far ones.
-- 5. Slow violet motes over the void. Everything floating is decor.
local isles = folder("Isles")
local startCount = count
local ROCK_TOP_T = Color3.fromRGB(214, 212, 180) -- core's rockTopTint
local ROCK_LOW_T = Color3.fromRGB(190, 160, 190) -- core's rockLowTint
local FLOWER = Color3.fromRGB(215, 178, 228) -- the chorus flower (white wool tinted lilac)
local FRUIT = Color3.fromRGB(170, 110, 190)
local CANDLE_WAX = Color3.fromRGB(240, 234, 222)
local FLAME = Color3.fromRGB(255, 200, 120)
local ROD_WHITE = Color3.fromRGB(245, 236, 250)
local SHELL = Color3.fromRGB(170, 112, 176) -- shulker shell over px_purpur
local lightsLeft = 19 -- PointLights of this part (≤ 20)
local function glow(p, range, brightness, color)
	if lightsLeft > 0 then
		lightsLeft -= 1
		light(p, range, brightness, color)
	end
end
-- core's rockDepth (10-core is wrapped in its own do … end, so it is replicated here)
local function rockDepth(x, z)
	local isle = isleOf(x, z)
	local rr, deep
	if isle == "main" then
		rr = math.sqrt(((x - MAIN.x) / MAIN.rx) ^ 2 + ((z - MAIN.z) / MAIN.rz) ^ 2)
		deep = 120
	else
		local c = if isle == "arena" then ARENA_ISLE elseif isle == "west" then WEST else EAST
		rr = math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) / c.r
		deep = if isle == "arena" then 96 else 64
	end
	rr = math.clamp(rr, 0, 1)
	local d = 12 + (1 - rr) ^ 1.3 * deep
	if rr > 0.82 then
		d += (n2(x, z, 7.7, 0.09) + 0.5) * 20
	end
	return math.max(8, math.floor(d / 16 + 0.5) * 16)
end
-- does a square of `half` round (x, z) overlap any rect { x0, z0, x1, z1 }?
local function rectHit(x, z, half, rects)
	for _, r in ipairs(rects) do
		if x + half > r[1] and x - half < r[3] and z + half > r[2] and z - half < r[4] then
			return true
		end
	end
	return false
end
-- end stone brick paving laid over the island top (a thin decor slab), merged into runs along x (or z)
local function pave(x0, z0, x1, z1, isle, pad, alongZ, avoid, f)
	local function ok(cx, cz)
		return isleOf(cx, cz, pad) == isle and not (avoid and rectHit(cx, cz, 0, avoid))
	end
	for a = (if alongZ then x0 else z0), (if alongZ then x1 else z1) - B, B do
		local run = nil
		local b0, b1 = if alongZ then z0 else x0, if alongZ then z1 else x1
		for b = b0, b1, B do
			local good = b < b1 and (if alongZ then ok(a + 2, b + 2) else ok(b + 2, a + 2))
			if good and run == nil then
				run = b
			elseif not good and run ~= nil then
				if alongZ then
					decor(box("Walk", a, -0.3, run, a + B, 0.12, b, "px_end_stone_bricks", nil, f))
				else
					decor(box("Walk", run, -0.3, a, b, 0.12, a + B, "px_end_stone_bricks", nil, f))
				end
				run = nil
			end
		end
	end
end
-- move a footprint (x ± hx, z ± hz) toward the island centre until its corners are on that island (pad studs in)
local function fitIsle(c, name, x, z, hx, hz, pad)
	for _ = 1, 24 do
		if
			isleOf(x - hx, z - hz, pad) == name
			and isleOf(x + hx, z - hz, pad) == name
			and isleOf(x - hx, z + hz, pad) == name
			and isleOf(x + hx, z + hz, pad) == name
		then
			return x, z
		end
		local dx, dz = c.x - x, c.z - z
		local len = math.max(1, math.sqrt(dx * dx + dz * dz))
		x, z = x + snap(dx / len * B), z + snap(dz / len * B)
	end
	warn("[build-edge-gate] isles: no fit on", name, x, z)
	return x, z
end
-- a random free spot on an island for a prop `half` wide; the spot is added to `rects`
local function landSpot(c, name, half, rects)
	for _ = 1, 300 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local rr = rng:NextNumber(0, c.r - 8)
		local x, z = snap(c.x + math.cos(a) * rr), snap(c.z + math.sin(a) * rr)
		if
			isleOf(x - half, z - half, 8) == name
			and isleOf(x + half, z - half, 8) == name
			and isleOf(x - half, z + half, 8) == name
			and isleOf(x + half, z + half, 8) == name
			and not rectHit(x, z, half, rects)
		then
			table.insert(rects, { x - half - 4, z - half - 4, x + half + 4, z + half + 4 })
			return x, z
		end
	end
	return nil
end

-- ================================================================ block props shared by the islands and the islets
local DIRS = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }
-- a chorus plant: a knobby purple stalk h blocks tall, side branches (a knob, an elbow block, a stem up) with pale
-- flower blocks on every tip; branches mostly along z (or x); only the main stalk can be solid
local function chorusPlant(x, y, z, h, f, solid, alongX)
	local pf = folder("ChorusPlant", f)
	local stalk = cube("ChorusStalk", x, y + h * B / 2, z, 2.8, h * B, 2.8, "px_chorus", nil, pf)
	if not solid then
		decor(stalk)
	end
	decor(cube("ChorusFlower", x, y + h * B + B / 2, z, B, B, B, "px_white_wool", FLOWER, pf))
	local used = {}
	for k = 2, h - 1 do
		if rng:NextNumber() < 0.6 then
			local di = if rng:NextNumber() < 0.75
				then rng:NextInteger(1, 2)
				else rng:NextInteger(3, 4)
			if alongX then
				di = (di + 1) % 4 + 1
			end
			if not used[di] then
				used[di] = true
				local d = DIRS[di]
				local by = y + (k - 0.5) * B
				local ex, ez = x + d[1] * B, z + d[2] * B
				local up = rng:NextInteger(1, math.max(1, h - k))
				decor(cube("ChorusKnob", x, by, z, B, B, B, "px_chorus", nil, pf))
				decor(cube("ChorusKnob", ex, by, ez, B, B, B, "px_chorus", nil, pf))
				decor(
					cube(
						"ChorusStem",
						ex,
						by + B / 2 + up * B / 2,
						ez,
						2.8,
						up * B,
						2.8,
						"px_chorus",
						nil,
						pf
					)
				)
				decor(
					cube(
						"ChorusFlower",
						ex,
						by + B / 2 + up * B + B / 2,
						ez,
						B,
						B,
						B,
						"px_white_wool",
						FLOWER,
						pf
					)
				)
			end
		end
	end
	return pf
end
-- a basket of chorus fruit (1 block)
local function basket(x, y, z, f, solid)
	local b =
		cube("Basket", x, y + 1.5, z, B, 3, B, "px_spruce_planks", Color3.fromRGB(150, 110, 80), f)
	if not solid then
		decor(b)
	end
	decor(
		box(
			"BasketRim",
			x - 2.1,
			y + 2.6,
			z - 2.1,
			x + 2.1,
			y + 3.2,
			z + 2.1,
			"px_dark_oak_planks",
			nil,
			f
		)
	)
	decor(
		box(
			"ChorusFruit",
			x - 1.7,
			y + 3,
			z - 1.7,
			x + 1.7,
			y + 3.6,
			z + 1.7,
			"px_chorus",
			FRUIT,
			f
		)
	)
	decor(
		cube(
			"ChorusFruit",
			x + rng:NextNumber(-0.8, 0.8),
			y + 4.1,
			z + rng:NextNumber(-0.8, 0.8),
			1.5,
			1.2,
			1.5,
			"px_chorus",
			FRUIT,
			f
		)
	)
	return b
end
-- a shulker box: shell base + lid (open = the lid raised, the pale head inside)
local function shulker(x, y, z, f, open, solid)
	local sf = folder("Shulker", f)
	local base = cube("ShulkerBase", x, y + 1.25, z, B, 2.5, B, "px_purpur", SHELL, sf)
	if not solid then
		decor(base)
	end
	if open then
		decor(
			cube(
				"ShulkerHead",
				x,
				y + 3,
				z,
				2.4,
				2.4,
				2.4,
				"px_end_stone",
				Color3.fromRGB(232, 236, 170),
				sf
			)
		)
		decor(cube("ShulkerLid", x, y + 4.95, z, B, 1.5, B, "px_purpur", SHELL, sf))
	else
		decor(cube("ShulkerLid", x, y + 3.25, z, B, 1.5, B, "px_purpur", SHELL, sf))
		decor(
			part(
				"ShulkerSeam",
				Vector3.new(B + 0.1, 0.3, B + 0.1),
				at(x, y + 2.5, z),
				Color3.fromRGB(80, 50, 90),
				nil,
				sf
			)
		)
	end
	return sf
end
local function candle(x, y, z, f, h)
	h = h or 3
	decor(cube("Candle", x, y + h / 2, z, 1.6, h, 1.6, "px_white_wool", CANDLE_WAX, f))
	local fl = decor(
		part(
			"CandleFlame",
			Vector3.new(0.6, 0.9, 0.6),
			at(x, y + h + 0.5, z),
			FLAME,
			Enum.Material.Neon,
			f
		)
	)
	fl.CastShadow = false
end
local function endRod(x, y, z, f, lit)
	decor(cube("EndRodBase", x, y + 0.5, z, 2, 1, 2, "px_purpur", nil, f))
	local rod = decor(
		part(
			"EndRod",
			Vector3.new(0.8, 5, 0.8),
			at(x, y + 3.5, z),
			ROD_WHITE,
			Enum.Material.Neon,
			f
		)
	)
	rod.CastShadow = false
	decor(
		part(
			"EndRodCap",
			Vector3.new(1.4, 0.5, 1.4),
			at(x, y + 6.25, z),
			Color3.fromRGB(230, 220, 236),
			nil,
			f
		)
	)
	if lit then
		glow(rod, 22, 1, Color3.fromRGB(235, 215, 255))
	end
end
-- a crystal spire: a black 3×3 base, a ring of black columns (some crowned with magenta), a black core turning into a
-- tall magenta crystal; 12 studs wide
local function crystalSpire(x, y, z, f, big, solid)
	local sf = folder("CrystalSpire", f)
	local function solidity(p)
		if not solid then
			decor(p)
		end
		return p
	end
	solidity(box("SpireBase", x - 6, y, z - 6, x + 6, y + B, z + 6, "px_blackstone", nil, sf))
	for i = -1, 1 do
		for j = -1, 1 do
			if i ~= 0 or j ~= 0 then
				local diag = i ~= 0 and j ~= 0
				local hgt = if diag
					then rng:NextInteger(0, 2)
					else rng:NextInteger(1, if big then 4 else 3)
				local cx, cz = x + i * B, z + j * B
				local yTop = y + B + hgt * B
				if hgt > 0 then
					solidity(
						box(
							"SpireBlack",
							cx - 2,
							y + B,
							cz - 2,
							cx + 2,
							yTop,
							cz + 2,
							pick({ "px_obsidian", "px_blackstone" }),
							nil,
							sf
						)
					)
				end
				if rng:NextNumber() < 0.45 then
					local s = decor(
						box(
							"SpireShard",
							cx - 1.5,
							yTop,
							cz - 1.5,
							cx + 1.5,
							yTop + rng:NextInteger(1, 2) * B,
							cz + 1.5,
							nil,
							MAGENTA,
							sf
						)
					)
					s.Material = Enum.Material.Neon
				end
			end
		end
	end
	local blackH = if big then 3 else 2
	local crystalH = rng:NextInteger(3, 4) + (if big then 2 else 0)
	solidity(
		box(
			"SpireCore",
			x - 2,
			y + B,
			z - 2,
			x + 2,
			y + B + blackH * B,
			z + 2,
			"px_obsidian",
			nil,
			sf
		)
	)
	local yc = y + B + blackH * B
	local cr = solidity(
		box("SpireCrystal", x - 2, yc, z - 2, x + 2, yc + crystalH * B, z + 2, nil, CRYSTAL, sf)
	)
	cr.Material = Enum.Material.Neon
	local tip = decor(
		box(
			"SpireTip",
			x - 1,
			yc + crystalH * B,
			z - 1,
			x + 1,
			yc + crystalH * B + B,
			z + 1,
			nil,
			CRYSTAL,
			sf
		)
	)
	tip.Material = Enum.Material.Neon
	return cr
end

-- ================================================================ 1. the west island: the chorus plantation
do
	local west = folder("ChorusPlantation", isles)
	local c0 = count
	local blocked = {} -- footprints the rows keep off
	-- the purpur gazebo at the west end of the walkway (5×5 blocks, open sides), a crystal on a pedestal inside
	local gx, gz = fitIsle(WEST, "west", -258, 38, 10, 10, 4)
	do
		local gf = folder("Gazebo", west)
		box(
			"GazeboFloor",
			gx - 10,
			-0.2,
			gz - 10,
			gx + 10,
			0.4,
			gz + 10,
			"px_end_stone_bricks",
			Color3.fromRGB(226, 220, 200),
			gf
		)
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local px, pz = gx + s[1] * 8, gz + s[2] * 8
			box(
				"GazeboPillar",
				px - 2,
				0.4,
				pz - 2,
				px + 2,
				12,
				pz + 2,
				"px_purpur_pillar",
				nil,
				gf
			)
			candle(px - s[1] * 3.5, 0.4, pz - s[2] * 3.5, gf, 2.5)
		end
		box("GazeboRoof", gx - 12, 12, gz - 12, gx + 12, 16, gz + 12, "px_purpur", nil, gf)
		box(
			"GazeboRoof",
			gx - 8,
			16,
			gz - 8,
			gx + 8,
			20,
			gz + 8,
			"px_purpur",
			Color3.fromRGB(220, 200, 222),
			gf
		)
		box("GazeboRoof", gx - 4, 20, gz - 4, gx + 4, 24, gz + 4, "px_purpur_pillar", nil, gf)
		endRod(gx, 24, gz, gf, false)
		box("CrystalPedestal", gx - 2, 0.4, gz - 2, gx + 2, 4, gz + 2, "px_purpur_pillar", nil, gf)
		local cr = decor(
			box("GazeboCrystal", gx - 1.5, 4, gz - 1.5, gx + 1.5, 9.5, gz + 1.5, nil, CRYSTAL, gf)
		)
		cr.Material = Enum.Material.Neon
		for _, o in ipairs({ { 1.8, 0.6 }, { -1.6, -1 } }) do
			local s = decor(
				box(
					"GazeboShard",
					gx + o[1] - 0.6,
					4,
					gz + o[2] - 0.6,
					gx + o[1] + 0.6,
					6.5,
					gz + o[2] + 0.6,
					nil,
					MAGENTA,
					gf
				)
			)
			s.Material = Enum.Material.Neon
		end
		glow(cr, 30, 1.2, CRYSTAL)
		table.insert(blocked, { gx - 12, gz - 12, gx + 12, gz + 12 })
	end
	-- the gardener's shed: purpur pillar corners, dark oak walls, a stepped purpur roof, the door south to the walkway
	local sx, sz = fitIsle(WEST, "west", -244, 74, 10, 8, 6)
	do
		local sf = folder("Shed", west)
		box("ShedFloor", sx - 10, -0.2, sz - 8, sx + 10, 0.3, sz + 8, "px_dark_oak_planks", nil, sf)
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
			local px, pz = sx + s[1] * 8, sz + s[2] * 6
			box("ShedCorner", px - 2, 0, pz - 2, px + 2, 12, pz + 2, "px_purpur_pillar", nil, sf)
		end
		box("ShedWall", sx - 6, 0, sz + 4, sx + 6, 12, sz + 8, "px_dark_oak_planks", nil, sf) -- north
		box("ShedWall", sx - 10, 0, sz - 4, sx - 6, 12, sz + 4, "px_dark_oak_planks", nil, sf) -- west
		box("ShedWall", sx + 6, 0, sz - 4, sx + 10, 12, sz + 4, "px_dark_oak_planks", nil, sf) -- east
		box("ShedWall", sx - 6, 0, sz - 8, sx - 2, 12, sz - 4, "px_dark_oak_planks", nil, sf) -- south, the door gap
		box("ShedWall", sx + 2, 0, sz - 8, sx + 6, 12, sz - 4, "px_dark_oak_planks", nil, sf)
		box("ShedLintel", sx - 2, 8, sz - 8, sx + 2, 12, sz - 4, "px_purpur", nil, sf)
		-- dark windows with purpur sills on the side walls
		for _, s in ipairs({ -1, 1 }) do
			decor(
				box(
					"ShedWindow",
					sx + s * 10 - 0.2,
					5,
					sz - 2,
					sx + s * 10 + 0.2,
					8,
					sz + 2,
					nil,
					Color3.fromRGB(34, 24, 44),
					sf
				)
			)
			decor(
				box(
					"ShedSill",
					sx + s * 10 - 0.6,
					4.4,
					sz - 2.4,
					sx + s * 10 + 0.6,
					5,
					sz + 2.4,
					"px_purpur",
					nil,
					sf
				)
			)
		end
		box("ShedRoof", sx - 12, 12, sz - 10, sx + 12, 16, sz + 10, "px_purpur", nil, sf)
		box(
			"ShedRoof",
			sx - 8,
			16,
			sz - 6,
			sx + 8,
			20,
			sz + 6,
			"px_purpur",
			Color3.fromRGB(214, 194, 216),
			sf
		)
		box("ShedRoof", sx - 4, 20, sz - 2, sx + 4, 22, sz + 2, "px_purpur_pillar", nil, sf)
		-- a lantern under the eave by the door (its PointLight counts in this part's budget)
		local lp = V(sx + 4, 9, sz - 9.5)
		lantern(lp, sf, false, BY + 12)
		lightsLeft -= 1
		barrel(sx + 4, 0.3, sz + 1, sf, "px_chorus")
		basket(sx - 4, 0.3, sz + 1, sf, true)
		crate(sx - 4, 0.3, sz - 2, sf, 3)
		-- the harvest outside: baskets and a shulker by the door
		basket(sx - 7, 0, sz - 11, sf, true)
		basket(sx - 3.5, 0, sz - 12, sf, true)
		shulker(sx + 7, 0, sz - 11, sf, false, true)
		table.insert(blocked, { sx - 14, sz - 15, sx + 14, sz + 12 })
	end
	task.wait()
	-- the walkway from the bridge into the plantation and the strips beside it (rows start 2 blocks off)
	pave(-252, 20, -180, 56, "west", 0, false, nil, west)
	-- end rods along the walkway at every row head (3 of them lit)
	for k = 0, 5 do
		local xk = -246 + 12 * k
		for _, rz in ipairs({ 52, 24 }) do
			if isleOf(xk, rz, 6) == "west" and not rectHit(xk, rz, 1, blocked) then
				endRod(
					xk,
					0,
					rz,
					west,
					(k == 1 and rz == 52) or (k == 3 and rz == 24) or (k == 5 and rz == 52)
				)
			end
		end
	end
	-- the rows: a plant every 2 blocks along z, trellis posts at the ends (and mid row) with two lines, now and then
	-- a basket of fruit in a plant's place; paved aisles between the rows
	local plants, baskets = 0, 0
	for k = 0, 5 do
		local xk = -246 + 12 * k
		for _, side in ipairs({ 1, -1 }) do
			local zs = {}
			local zc = if side > 0 then 60 else 16
			while
				#zs < 8
				and isleOf(xk, zc + side * 4, 10) == "west"
				and not rectHit(xk, zc, 4, blocked)
			do
				table.insert(zs, zc)
				zc += side * 8
			end
			local n = #zs
			if n > 0 then
				local rf = folder("ChorusRow", west)
				local zA, zB = zs[1] - side * 4, zs[n] + side * 4
				local posts = { zA, zB }
				if n >= 3 then
					table.insert(posts, zs[2] + side * 4)
				end
				for _, pz in ipairs(posts) do
					decor(
						box(
							"TrellisPost",
							xk - 0.6,
							0,
							pz - 0.6,
							xk + 0.6,
							9,
							pz + 0.6,
							"px_purpur_pillar",
							nil,
							rf
						)
					)
				end
				for _, h in ipairs({ 5, 8 }) do
					decor(
						part(
							"TrellisLine",
							Vector3.new(0.2, 0.2, math.abs(zB - zA)),
							at(xk, h, (zA + zB) / 2),
							Color3.fromRGB(222, 212, 230),
							nil,
							rf
						)
					)
				end
				for _, z in ipairs(zs) do
					if rng:NextNumber() < 0.12 then
						basket(xk, 0, z, rf, true)
						baskets += 1
					else
						chorusPlant(xk, 0, z, rng:NextInteger(3, 6), rf, true, false)
						plants += 1
					end
				end
			end
		end
		task.wait()
	end
	for k = -1, 5 do
		local ax = -246 + 12 * k + 2
		pave(ax, 56, ax + 8, 104, "west", 6, true, blocked, west)
		pave(ax, -40, ax + 8, 20, "west", 6, true, blocked, west)
	end
	print(
		("[build-edge-gate] isles: plantation %d plants, %d baskets, gazebo (%d, %d), shed (%d, %d), %d parts"):format(
			plants,
			baskets,
			gx,
			gz,
			sx,
			sz,
			count - c0
		)
	)
end
task.wait()

-- ================================================================ 2. the east island: the dragon head statue
do
	local east = folder("DragonIsle", isles)
	local c0 = count
	-- the walkway from the bridge (x 172) to the mound
	pave(172, -40, 184, -16, "east", 0, false, nil, east)
	-- the mound: two stepped end stone tiers with cut corners
	local mf = folder("Mound", east)
	for _, t in ipairs({
		{ 188, 0, -52, 232, 4, -4 },
		{ 184, 0, -48, 188, 4, -8 },
		{ 232, 0, -48, 236, 4, -8 },
		{ 192, 4, -48, 228, 8, -8 },
		{ 188, 4, -44, 192, 8, -12 },
		{ 228, 4, -44, 232, 8, -12 },
	}) do
		box("Mound", t[1], t[2], t[3], t[4], t[5], t[6], "px_end_stone", ROCK_TOP_T, mf)
	end
	-- the head: black blocks, the snout west (x 192) toward the bridge, the jaw open
	local df = folder("DragonHead", east)
	local function hb(name, x0, y0, z0, x1, y1, z1, v, solid, tint)
		local p = box(name, x0, y0, z0, x1, y1, z1, v, tint, df)
		if not solid then
			decor(p)
		end
		return p
	end
	hb("Skull", 212, 8, -44, 232, 32, -12, "px_blackstone", true)
	hb("Neck", 232, 0, -36, 240, 24, -20, "px_blackstone", true)
	hb("LowerJaw", 192, 8, -36, 212, 12, -20, "px_obsidian", true)
	hb("UpperSnout", 192, 20, -38, 212, 28, -18, "px_obsidian", true)
	hb("SnoutRidge", 200, 28, -32, 212, 32, -24, "px_blackstone", true)
	hb("Nostril", 194, 28, -35, 198, 30, -31, "px_blackstone", false)
	hb("Nostril", 194, 28, -25, 198, 30, -21, "px_blackstone", false)
	hb("Brow", 208, 28, -45, 216, 32, -38, "px_obsidian", false)
	hb("Brow", 208, 28, -18, 216, 32, -11, "px_obsidian", false)
	local mouth =
		hb("MouthDark", 211, 12, -36, 212, 20, -20, nil, false, Color3.fromRGB(36, 12, 48))
	mouth.Material = Enum.Material.SmoothPlastic
	-- the glowing eyes wrap the front corners of the skull
	for _, e in ipairs({ { -44.4, -40 }, { -16, -11.6 } }) do
		local eye = hb("DragonEye", 211.6, 24, e[1], 216, 28, e[2], nil, false, MAGENTA)
		eye.Material = Enum.Material.Neon
		glow(eye, 18, 1, MAGENTA)
	end
	-- teeth down from the snout and up from the jaw
	local TOOTH = Color3.fromRGB(226, 222, 206)
	for _, zt in ipairs({ -36, -22 }) do
		for _, xt in ipairs({ 194, 202, 208 }) do
			hb("Tooth", xt, 17, zt, xt + 2, 20, zt + 2, "px_white_wool", false, TOOTH)
		end
		for _, xt in ipairs({ 197, 205 }) do
			hb("Tooth", xt, 12, zt, xt + 2, 15, zt + 2, "px_white_wool", false, TOOTH)
		end
	end
	-- horns sweeping back, spikes down the ridge, frills on the cheeks
	for _, hz in ipairs({ -42, -18 }) do
		hb(
			"Horn",
			220,
			32,
			hz,
			224,
			40,
			hz + 4,
			"px_blackstone",
			false,
			Color3.fromRGB(150, 140, 160)
		)
		hb(
			"Horn",
			224,
			38,
			hz,
			228,
			46,
			hz + 4,
			"px_blackstone",
			false,
			Color3.fromRGB(150, 140, 160)
		)
		hb("Horn", 228, 44, hz, 232, 52, hz + 4, "px_obsidian", false)
	end
	hb("Spike", 216, 32, -30, 220, 36, -26, "px_obsidian", false)
	hb("Spike", 226, 32, -30, 230, 36, -26, "px_obsidian", false)
	hb("Spike", 234, 24, -30, 238, 28, -26, "px_obsidian", false)
	hb("Frill", 220, 22, -46, 228, 30, -44, "px_obsidian", false)
	hb("Frill", 220, 22, -12, 228, 30, -10, "px_obsidian", false)
	-- candles on the mound steps in front of the jaw
	for _, cp in ipairs({
		{ 186, 4, -44 },
		{ 186, 4, -12 },
		{ 190, 8, -41 },
		{ 190, 8, -15 },
		{ 234, 4, -46 },
		{ 234, 4, -10 },
	}) do
		candle(cp[1], cp[2], cp[3], df, rng:NextInteger(2, 4))
	end
	-- the obelisk north of the head
	local ox, oz = fitIsle(EAST, "east", 232, -60, 6, 6, 4)
	do
		local of = folder("Obelisk", east)
		box("ObeliskPlinth", ox - 6, 0, oz - 6, ox + 6, 4, oz + 6, "px_end_stone_bricks", nil, of)
		box("ObeliskShaft", ox - 4, 4, oz - 4, ox + 4, 52, oz + 4, "px_obsidian", nil, of)
		box("ObeliskBand", ox - 4.4, 44, oz - 4.4, ox + 4.4, 48, oz + 4.4, "px_blackstone", nil, of)
		box("ObeliskTop", ox - 2, 52, oz - 2, ox + 2, 68, oz + 2, "px_obsidian", nil, of)
		decor(box("ObeliskTip", ox - 1, 68, oz - 1, ox + 1, 72, oz + 1, "px_obsidian", nil, of))
		-- two magenta glyphs on the west face
		for _, gy in ipairs({ 22, 34 }) do
			local g = decor(
				box(
					"ObeliskGlyph",
					ox - 4.3,
					gy,
					oz - 1,
					ox - 3.9,
					gy + 2,
					oz + 1,
					nil,
					MAGENTA,
					of
				)
			)
			g.Material = Enum.Material.Neon
		end
	end
	task.wait()
	-- props on the free ground: crystal spires, a broken end gateway, shulker boxes, chorus plants
	local rects = {
		{ 150, -44, 188, -12 }, -- the bridge landing and the walkway
		{ 180, -56, 242, 0 }, -- the mound and the head
		{ ox - 8, oz - 8, ox + 8, oz + 8 },
	}
	local spires, shulkers, chorus = 0, 0, 0
	for i = 1, 4 do
		local x, z = landSpot(EAST, "east", 8, rects)
		if x then
			glow(crystalSpire(x, 0, z, east, i == 1, true), 30, 1.2, CRYSTAL)
			spires += 1
		end
	end
	do
		local x, z = landSpot(EAST, "east", 12, rects)
		if x then
			local gf = folder("BrokenGateway", east)
			local alongX = rng:NextNumber() < 0.5
			local DARK = Color3.fromRGB(64, 60, 70)
			-- u runs across the frame, w through it
			local function gb(name, u0, y0, w0, u1, y1, w1, solid)
				local p
				if alongX then
					p = box(name, x + u0, y0, z + w0, x + u1, y1, z + w1, "px_blackstone", DARK, gf)
				else
					p = box(name, x + w0, y0, z + u0, x + w1, y1, z + u1, "px_blackstone", DARK, gf)
				end
				if not solid then
					decor(p)
				end
				return p
			end
			gb("GatewayFrame", -10, 0, -2, -6, 20, 2, true)
			gb("GatewayFrame", 6, 0, -2, 10, 12, 2, true)
			gb("GatewayFrame", -6, 16, -2, 2, 20, 2, true)
			gb("GatewayFrame", -6, 0, -2, 6, 4, 2, true)
			gb("GatewayRubble", 10, 0, 3, 14, 4, 7, true)
			gb("GatewayRubble", -2, 0, -9, 2, 4, -5, true)
			local film = gb("GatewayFilm", -6, 12, -0.2, -2, 16, 0.2, false)
			film.Material = Enum.Material.Neon
			film.Color = VOID_VIOLET
			film.MaterialVariant = ""
			film.Transparency = 0.25
		end
	end
	for _ = 1, 6 do
		local x, z = landSpot(EAST, "east", 3, rects)
		if x then
			shulker(x, 0, z, east, rng:NextNumber() < 0.4, true)
			shulkers += 1
		end
	end
	for _ = 1, 5 do
		local x, z = landSpot(EAST, "east", 4, rects)
		if x then
			chorusPlant(x, 0, z, rng:NextInteger(3, 5), east, true, rng:NextNumber() < 0.5)
			chorus += 1
		end
	end
	print(
		("[build-edge-gate] isles: dragon isle, obelisk (%d, %d), spires %d, shulkers %d, chorus %d, %d parts"):format(
			ox,
			oz,
			spires,
			shulkers,
			chorus,
			count - c0
		)
	)
end
task.wait()

-- ================================================================ 3. purpur stalactites under every island
do
	local hang = folder("Stalactites", isles)
	local c0 = count
	local C = 8
	local cols, lumps = 0, 0
	local DIRS4 = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
	local PALE = Color3.fromRGB(236, 218, 236)
	local function skip(cx, cz)
		if cx >= -24 and cx <= 24 and cz >= -110 and cz <= -70 then
			return true -- the grand stair
		end
		for _, b in ipairs(BRIDGES) do
			if inRect(cx, cz, b, 16) then
				return true
			end
		end
		return false
	end
	-- one column s studs square, its top at `top`, `len` long
	local function column(x0, z0, s, top, len)
		local v, t = "px_purpur_pillar", nil
		local r = rng:NextNumber()
		if r < 0.35 then
			v, t = "px_purpur", ROCK_LOW_T
		elseif r < 0.6 then
			t = PALE
		end
		decor(box("Stalactite", x0, top - len, z0, x0 + s, top, z0 + s, v, t, hang))
		cols += 1
	end
	for z = -264, 240 - C, C do
		for x = -296, 280 - C, C do
			local cx, cz = x + C / 2, z + C / 2
			local gy = groundY(cx, cz)
			if gy ~= nil and not skip(cx, cz) and count - c0 < 1300 then
				local bottom = gy - B - rockDepth(cx, cz)
				local outX, outZ, rim = 0, 0, false
				for _, d in ipairs(DIRS4) do
					if groundY(cx + d[1] * C, cz + d[2] * C) == nil then
						rim = true
						outX += d[1]
						outZ += d[2]
						-- an end stone lump on the rim face, just under the ground block
						if rng:NextNumber() < 0.12 then
							local top = gy - B - rng:NextInteger(0, 1) * B
							local h = rng:NextInteger(1, 2) * B
							local a = rng:NextInteger(0, 1) * B
							if d[1] ~= 0 then
								local face = cx + d[1] * 4
								decor(
									box(
										"RimLump",
										face,
										top - h,
										z + a,
										face + d[1] * B,
										top,
										z + a + B,
										"px_end_stone",
										ROCK_TOP_T,
										hang
									)
								)
							else
								local face = cz + d[2] * 4
								decor(
									box(
										"RimLump",
										x + a,
										top - h,
										face,
										x + a + B,
										top,
										face + d[2] * B,
										"px_end_stone",
										ROCK_TOP_T,
										hang
									)
								)
							end
							lumps += 1
						end
					end
				end
				if rng:NextNumber() < (if rim then 0.7 else 0.22) then
					if not rim and rng:NextNumber() < 0.4 then
						-- a fat 2×2 column with a 1×1 tip under one quarter
						local len = rng:NextInteger(2, 7) * B
						column(x, z, 2 * B, bottom + 2, len + 2)
						if rng:NextNumber() < 0.7 then
							column(
								x + rng:NextInteger(0, 1) * B,
								z + rng:NextInteger(0, 1) * B,
								B,
								bottom - len,
								rng:NextInteger(1, 3) * B
							)
						end
					else
						-- 1×1 columns, on the outer quarter of a rim cell
						local qx = if outX > 0
							then 1
							elseif outX < 0 then 0
							else rng:NextInteger(0, 1)
						local qz = if outZ > 0
							then 1
							elseif outZ < 0 then 0
							else rng:NextInteger(0, 1)
						local len = if rim then rng:NextInteger(3, 10) else rng:NextInteger(2, 6)
						column(x + qx * B, z + qz * B, B, bottom + 2, len * B + 2)
						if rim and len > 3 and rng:NextNumber() < 0.35 then
							local q2x, q2z = 1 - qx, qz
							if outX == 0 then
								q2x, q2z = qx, 1 - qz
							end
							column(
								x + q2x * B,
								z + q2z * B,
								B,
								bottom + 2,
								rng:NextInteger(1, len - 2) * B + 2
							)
						end
					end
				end
			end
		end
		if z % 64 == 0 then
			task.wait()
		end
	end
	print(
		("[build-edge-gate] isles: stalactites %d, rim lumps %d, %d parts"):format(
			cols,
			lumps,
			count - c0
		)
	)
end
task.wait()

-- ================================================================ 4. floating end stone islets
do
	local fly = folder("FloatingIslets", isles)
	local c0 = count
	-- the walkable ways through the void: x0, x1, z0, z1, y0, y1
	local CORRIDORS = { { -24, 24, -110, -70, -20, 40 } }
	for _, b in ipairs(BRIDGES) do
		table.insert(CORRIDORS, { b[1] - 16, b[3] + 16, b[2] - 16, b[4] + 16, -20, 20 })
	end
	local function inCorridor(x0, x1, z0, z1, y0, y1)
		for _, c in ipairs(CORRIDORS) do
			if
				x1 >= c[1]
				and x0 <= c[2]
				and z1 >= c[3]
				and z0 <= c[4]
				and y1 >= c[5]
				and y0 <= c[6]
			then
				return true
			end
		end
		return false
	end
	-- no island cell within `half` + 24 studs (horizontally) of (x, z)
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
	local taken = {} -- { x, z, half, y0, y1 }
	local function findSpot(half, down, up, yMin, yMax, far)
		for attempt = 1, 400 do
			if attempt % 100 == 0 then
				task.wait()
			end
			local x, z = rng:NextNumber(-420, 400), rng:NextNumber(-380, 360)
			local y = rng:NextNumber(yMin, yMax)
			local ok = (not far or x < -320 or x > 300 or z < -290 or z > 270)
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
	local isletLights = 0
	-- the props on an islet top (x, y, z: a block centre on the top surface)
	local function crystal(x, y, z, f)
		decor(cube("CrystalBase", x, y + 2, z, B, B, B, "px_blackstone", nil, f))
		local h = rng:NextInteger(2, 3) * B
		local c = decor(
			box(
				"IsletCrystal",
				x - 1.3,
				y + B,
				z - 1.3,
				x + 1.3,
				y + B + h,
				z + 1.3,
				nil,
				CRYSTAL,
				f
			)
		)
		c.Material = Enum.Material.Neon
		local s = decor(
			box(
				"IsletShard",
				x + 1.3,
				y + B,
				z - 0.6,
				x + 2.5,
				y + B + h * 0.5,
				z + 0.6,
				nil,
				MAGENTA,
				f
			)
		)
		s.Material = Enum.Material.Neon
		if isletLights < 4 then
			isletLights += 1
			glow(c, 24, 1, CRYSTAL)
		end
	end
	local function candles(x, y, z, f)
		for i = 1, rng:NextInteger(2, 3) do
			candle(x + (i - 2) * 2.2, y, z + rng:NextNumber(-1.5, 1.5), f, rng:NextInteger(2, 4))
		end
	end
	local function bush(x, y, z, f)
		chorusPlant(x, y, z, rng:NextInteger(2, 4), f, false, rng:NextNumber() < 0.5)
	end
	local function box2(x, y, z, f)
		shulker(x, y, z, f, rng:NextNumber() < 0.5, false)
	end
	-- a broken purpur arch (needs a top 4+ blocks wide): one whole pillar, one snapped, half a lintel, a crystal
	local function brokenArch(x, y, z, f, alongX)
		local af = folder("BrokenArch", f)
		local function ab(name, u0, y0, u1, y1, v, tint)
			if alongX then
				return decor(box(name, x + u0, y + y0, z - 2, x + u1, y + y1, z + 2, v, tint, af))
			end
			return decor(box(name, x - 2, y + y0, z + u0, x + 2, y + y1, z + u1, v, tint, af))
		end
		ab("ArchPillar", -8, 0, -4, 16, "px_purpur_pillar")
		ab("ArchPillar", 4, 0, 8, rng:NextInteger(1, 2) * B, "px_purpur_pillar")
		ab("ArchLintel", -8, 16, 0, 20, "px_purpur")
		local c = ab("ArchCrystal", -3.2, 11, -1.8, 16, nil, MAGENTA)
		c.Material = Enum.Material.Neon
	end
	local PROPS = { bush, bush, crystal, box2, candles }
	-- one islet: top w × d blocks, (x, y, z) = the centre of its top surface
	local function islet(x, y, z, w, d, layers, f)
		local cf = folder("Islet", f)
		local hx, hz = w * B / 2, d * B / 2
		decor(box("IsletTop", x - hx, y - B, z - hz, x + hx, y, z + hz, "px_end_stone", nil, cf))
		-- a ragged nub on one top edge
		if rng:NextNumber() < 0.5 then
			local side = rng:NextInteger(1, 4)
			local along = if side <= 2 then d else w
			local a = rng:NextInteger(0, math.max(0, along - 2)) * B
			local len = math.min(2, along) * B
			if side == 1 then
				decor(
					box(
						"IsletTop",
						x - hx - B,
						y - B,
						z - hz + a,
						x - hx,
						y,
						z - hz + a + len,
						"px_end_stone",
						nil,
						cf
					)
				)
			elseif side == 2 then
				decor(
					box(
						"IsletTop",
						x + hx,
						y - B,
						z - hz + a,
						x + hx + B,
						y,
						z - hz + a + len,
						"px_end_stone",
						nil,
						cf
					)
				)
			elseif side == 3 then
				decor(
					box(
						"IsletTop",
						x - hx + a,
						y - B,
						z - hz - B,
						x - hx + a + len,
						y,
						z - hz,
						"px_end_stone",
						nil,
						cf
					)
				)
			else
				decor(
					box(
						"IsletTop",
						x - hx + a,
						y - B,
						z + hz,
						x - hx + a + len,
						y,
						z + hz + B,
						"px_end_stone",
						nil,
						cf
					)
				)
			end
		end
		-- the stepped layers: end stone above, purpur below, shrinking on the block grid
		local heights, total = {}, B
		for k = 1, layers do
			heights[k] = if w >= 6 and rng:NextNumber() < 0.5 then 2 * B else B
			total += heights[k]
		end
		local tipLen = rng:NextInteger(1, 2) * B
		total += tipLen
		local yTop = y - B
		local ix0, ix1, iz0, iz1 = 0, w, 0, d
		for k = 1, layers do
			local f01 = 1 - k / (layers + 1)
			local lw = math.min(math.max(1, math.floor(w * f01 + 0.5)), ix1 - ix0)
			local ld = math.min(math.max(1, math.floor(d * f01 + 0.5)), iz1 - iz0)
			local sx = math.clamp(
				ix0 + math.floor((ix1 - ix0 - lw) / 2 + rng:NextNumber(-0.5, 0.99)),
				ix0,
				ix1 - lw
			)
			local sz = math.clamp(
				iz0 + math.floor((iz1 - iz0 - ld) / 2 + rng:NextNumber(-0.5, 0.99)),
				iz0,
				iz1 - ld
			)
			local v, t = "px_end_stone", ROCK_TOP_T
			if y - yTop >= math.max(8, total * 0.4) then
				v, t = "px_purpur", ROCK_LOW_T
			end
			local yb = yTop - heights[k]
			decor(
				box(
					"IsletRock",
					x - hx + sx * B,
					yb,
					z - hz + sz * B,
					x - hx + (sx + lw) * B,
					yTop,
					z - hz + (sz + ld) * B,
					v,
					t,
					cf
				)
			)
			ix0, ix1, iz0, iz1 = sx, sx + lw, sz, sz + ld
			yTop = yb
		end
		local px = ix0 + rng:NextInteger(0, ix1 - ix0 - 1)
		local pz = iz0 + rng:NextInteger(0, iz1 - iz0 - 1)
		decor(
			box(
				"IsletTip",
				x - hx + px * B,
				yTop - tipLen,
				z - hz + pz * B,
				x - hx + (px + 1) * B,
				yTop,
				z - hz + (pz + 1) * B,
				"px_purpur_pillar",
				nil,
				cf
			)
		)
		-- the purpur fringe: columns hanging from the outer ring of the top, all round
		for side = 1, 4 do
			local along = if side <= 2 then d else w
			local nv = math.clamp(math.floor(along / 2 + rng:NextNumber(0, 1.5)), 1, 4)
			local used = {}
			for _ = 1, nv do
				local a = rng:NextInteger(0, along - 1)
				if not used[a] then
					used[a] = true
					local len = rng:NextInteger(1, math.max(2, math.floor(total / B) + 1)) * B
					local v = if rng:NextNumber() < 0.6 then "px_purpur_pillar" else "px_purpur"
					local t = if v == "px_purpur" then ROCK_LOW_T else nil
					local top = y - B
					local ab = a * B
					if side == 1 then
						decor(
							box(
								"IsletStalactite",
								x - hx,
								top - len,
								z - hz + ab,
								x - hx + B,
								top,
								z - hz + ab + B,
								v,
								t,
								cf
							)
						)
					elseif side == 2 then
						decor(
							box(
								"IsletStalactite",
								x + hx - B,
								top - len,
								z - hz + ab,
								x + hx,
								top,
								z - hz + ab + B,
								v,
								t,
								cf
							)
						)
					elseif side == 3 then
						decor(
							box(
								"IsletStalactite",
								x - hx + ab,
								top - len,
								z - hz,
								x - hx + ab + B,
								top,
								z - hz + B,
								v,
								t,
								cf
							)
						)
					else
						decor(
							box(
								"IsletStalactite",
								x - hx + ab,
								top - len,
								z + hz - B,
								x - hx + ab + B,
								top,
								z + hz,
								v,
								t,
								cf
							)
						)
					end
				end
			end
		end
		-- a prop on top (a broken arch on the wide ones)
		local bx = x - hx + (math.floor(w / 2) + 0.5) * B
		local bz = z - hz + (math.floor(d / 2) + 0.5) * B
		if math.min(w, d) >= 5 and rng:NextNumber() < 0.45 then
			brokenArch(bx, y, bz, cf, w >= d)
		elseif math.min(w, d) >= 2 and rng:NextNumber() < 0.75 then
			pick(PROPS)(bx, y, bz, cf)
		end
		return total
	end

	local made, big = 0, 0
	for i = 1, 44 do
		local isBig = i <= 4
		local w = if isBig then rng:NextInteger(8, 10) else rng:NextInteger(2, 6)
		local d = math.clamp(w + rng:NextInteger(-1, 1), 2, 10)
		local layers = math.clamp(math.floor(math.max(w, d) / 2) + rng:NextInteger(1, 2), 3, 6)
		local half = math.max(w, d) * B / 2 + B + 2
		local down = B * (layers * (if w >= 6 then 2 else 1) + 3)
		local yMin, yMax = -60, 120
		if not isBig and rng:NextNumber() < 0.6 then
			yMin, yMax = -30, 60 -- most of them near the eye line of the islands
		end
		local x, y, z = findSpot(half, down, 24, yMin, yMax, isBig)
		if x then
			islet(snap(x) + (w % 2) * 2, snap(y), snap(z) + (d % 2) * 2, w, d, layers, fly)
			made += 1
			if isBig then
				big += 1
			end
		end
		if i % 6 == 0 then
			task.wait()
		end
	end
	print(("[build-edge-gate] isles: islets %d (big %d), %d parts"):format(made, big, count - c0))
end
task.wait()

-- ================================================================ 5. slow violet motes over the void between islands
do
	local motes = folder("VoidMotes", isles)
	for _, m in ipairs({ { -196, -64 }, { 186, 64 }, { -150, -130 } }) do
		local src =
			decor(part("VoidMotes", Vector3.new(70, 1, 70), at(m[1], -40, m[2]), nil, nil, motes))
		src.Transparency = 1
		src.CastShadow = false
		emitter(src, {
			Rate = 3,
			Lifetime = NumberRange.new(14, 20),
			Speed = NumberRange.new(1.5, 3),
			SpreadAngle = Vector2.new(20, 20),
			EmissionDirection = Enum.NormalId.Top,
			Size = NumberSequence.new(0.4),
			Color = ColorSequence.new(Color3.fromRGB(190, 120, 255)),
			LightEmission = 1,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.15, 0.3),
				NumberSequenceKeypoint.new(0.85, 0.4),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end
end
print(
	("[build-edge-gate] isles: %d parts in all, %d lights left"):format(
		count - startCount,
		lightsLeft
	)
)
