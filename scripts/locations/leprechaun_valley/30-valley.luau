--!nocheck
-- ================================================================ leprechaun valley: the valley outside the fort
-- Everything outside the fairy fort (fortDist > 92) and the mine plaza: the rainbow into the cauldron of gold on its
-- hill with stairs up from the west path, stone bridges where the paths cross the river (gold in the water), the
-- river's waterfall off the west edge and two spring falls (south-west, north), hobbit burrows and the windmill in the
-- west hills, giant red mushrooms, the fairy ring, dolmens and menhirs, the cultists' camp, trees and undergrowth,
-- lamp posts along the paths, signposts at the junctions and the lookout over the clouds at the south end.
-- Every object stands on the ground cell the island really built (cellY: 8-stud cells, as in 10-core).
local valley = folder("Valley")
local startCount = count
local RES = {} -- reserved circles { x, z, r }: the scatter keeps off them
local function reserve(x, z, r)
	table.insert(RES, { x, z, r })
end
local function isReserved(x, z, pad)
	for _, c in ipairs(RES) do
		local r = c[3] + pad
		if (x - c[1]) ^ 2 + (z - c[2]) ^ 2 < r * r then
			return true
		end
	end
	return false
end
-- the top of the ground cell under (x, z), as the island built it (the river bed is one block down)
local function cellY(x, z)
	local cx, cz = math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4
	if inRiver(cx, cz) and not inPlaza(cx, cz) then
		return -4
	end
	return groundY(cx, cz)
end
local function cellLand(x, z)
	return onIsland(math.floor(x / 8) * 8 + 4, math.floor(z / 8) * 8 + 4)
end
local function inCamp(x, z, pad)
	return x >= CAMP.x0 - pad and x <= CAMP.x1 + pad and z >= CAMP.z0 - pad and z <= CAMP.z1 + pad
end
local function isFree(x, z, pad)
	return freeGround(x, z, pad)
		and cellLand(x, z)
		and fortDist(x, z) > 94 + pad
		and not inCamp(x, z, pad)
		and not isReserved(x, z, pad)
		and cellY(x, z) > -4
end
local function nearPath(x, z, d)
	for _, line in ipairs(PATHS) do
		if polyDist(line, x, z) < d then
			return true
		end
	end
	return false
end
local function g4(v) -- the centre of the 4-stud block column holding v
	return math.floor(v / 4) * 4 + 2
end
-- a textured box in a local frame cf (a world CFrame) by two corners
local function lbox(cf, name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	local p = part(name, size, cf * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- the yaw that turns a frame's front (-Z) toward (dx, dz)
local function faceYaw(dx, dz)
	return math.atan2(-dx, -dz)
end
-- a local point of frame cf back in plan studs (x, z)
local function toPlan(cf, x, z)
	local w = (cf * CFrame.new(x, 0, z)).Position
	return w.X - BX, w.Z - BZ
end
local function waterPart(name, size, cf, parent)
	local p = part(name, size, cf, WATER_C, nil, parent)
	textured(p, "px_water", WATER_C)
	p.Transparency = 0.25
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local function mist(p, rate, size, color)
	emitter(p, {
		Texture = SMOKE_TEX,
		Color = ColorSequence.new(color or Color3.fromRGB(235, 245, 255)),
		Size = NumberSequence.new(size * 0.5, size),
		Transparency = NumberSequence.new(0.5, 1),
		Lifetime = NumberRange.new(2.5, 4.5),
		Rate = rate,
		Speed = NumberRange.new(1.5, 4),
		SpreadAngle = Vector2.new(70, 70),
		RotSpeed = NumberRange.new(-20, 20),
	})
end
local RED_CAP = Color3.fromRGB(205, 40, 40)
local DOT_WHITE = Color3.fromRGB(245, 242, 236)
local STEM_WHITE = Color3.fromRGB(232, 226, 212)
local GILL = Color3.fromRGB(215, 195, 165)
local HAT_GREEN = Color3.fromRGB(45, 125, 50)
local CULT_GREEN = Color3.fromRGB(40, 95, 45)
local PLANK_T = Color3.fromRGB(205, 165, 115)
local WINDOW_C = Color3.fromRGB(250, 215, 140)
local FLOWERS = {
	Color3.fromRGB(220, 50, 50),
	Color3.fromRGB(240, 210, 60),
	Color3.fromRGB(240, 240, 235),
	Color3.fromRGB(80, 120, 220),
	Color3.fromRGB(230, 140, 180),
	Color3.fromRGB(235, 130, 30),
}

-- a leprechaun's hat on a stand (green crown, black band, gold buckle)
local function leprechaunHat(x, y, z, parent)
	textured(part("HatStand", Vector3.new(1, 4, 1), at(x, y + 2, z), nil, nil, parent), "px_dark_oak_planks")
	cube("HatBrim", x, y + 4.25, z, 4, 0.5, 4, "px_white_wool", HAT_GREEN, parent)
	cube("Hat", x, y + 5.7, z, 2.6, 2.4, 2.6, "px_white_wool", HAT_GREEN, parent)
	decor(cube("HatBand", x, y + 4.95, z, 2.7, 0.6, 2.7, "px_blackstone", nil, parent))
	decor(cube("HatBuckle", x, y + 4.95, z - 1.42, 0.9, 0.7, 0.2, "px_gold_block", GOLD_T, parent))
end

-- a signpost: one post, a board per direction pointing along it ({ text, dx, dz })
local function signpost(x, z, boards, parent)
	local y = cellY(x, z)
	textured(part("SignPost", Vector3.new(1, 8.5, 1), at(x, y + 4.25, z), nil, nil, parent), "px_dark_oak_planks")
	for i, b in ipairs(boards) do
		local len = math.sqrt(b[2] ^ 2 + b[3] ^ 2)
		local yaw = math.atan2(-b[3] / len, b[2] / len)
		local cf = at(x, y + 8.3 - i * 1.9, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(3.4, 0, 0)
		local board = textured(part("SignBoard", Vector3.new(6, 1.6, 0.4), cf, nil, nil, parent), "px_spruce_planks")
		boardText(board, b[1])
	end
	reserve(x, z, 5)
end

-- ================================================================ giant red mushrooms (block style)
-- stem / height in blocks; caps { width, base block }; ring = a cap rim hanging one block down (the big ones)
local MUSH = {
	large = { stem = 2, h = 6, caps = { { 8, 6 }, { 6, 7 }, { 4, 8 } }, ring = 8 },
	medium = { stem = 1, h = 4, caps = { { 5, 4 }, { 3, 5 } } },
	small = { stem = 1, h = 2, caps = { { 3, 2 }, { 1, 3 } } },
}
-- white dots (one block face each) on the open top cells of a cap layer and on its four sides
local function capDots(cx, cz, w, y, nextW, parent, chance)
	local half = w * B / 2
	for i = 0, w - 1 do
		for k = 0, w - 1 do
			local ox, oz = -half + (i + 0.5) * B, -half + (k + 0.5) * B
			if math.max(math.abs(ox), math.abs(oz)) > nextW * B / 2 and rng:NextNumber() < chance then
				decor(cube("CapDot", cx + ox, y + 0.12, cz + oz, B, 0.24, B, "px_white_wool", DOT_WHITE, parent))
			end
		end
	end
	for i = 0, w - 1 do
		local o = -half + (i + 0.5) * B
		for _, s in ipairs({ { o, half + 0.12, B, 0.24 }, { o, -half - 0.12, B, 0.24 }, { half + 0.12, o, 0.24, B }, { -half - 0.12, o, 0.24, B } }) do
			if rng:NextNumber() < chance * 0.7 then
				decor(cube("CapDot", cx + s[1], y - B / 2, cz + s[2], s[3], B, s[4], "px_white_wool", DOT_WHITE, parent))
			end
		end
	end
end
local function mushroom(x, z, kind, parent)
	local m = MUSH[kind]
	local even = m.stem % 2 == 0
	local cx = if even then math.floor(x / 4 + 0.5) * 4 else g4(x)
	local cz = if even then math.floor(z / 4 + 0.5) * 4 else g4(z)
	local capHalf = m.caps[1][1] * B / 2
	if not cellLand(cx, cz) or nearPath(cx, cz, PATH_W / 2 + capHalf + 1) or fortDist(cx, cz) <= 94 + capHalf then
		return false
	end
	if isReserved(cx, cz, 2) or inPlaza(cx, cz, 2) then
		return false
	end
	local hs = m.stem * B / 2
	local yLo, yHi = math.huge, -math.huge
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local y = cellY(cx + c[1] * (hs - 0.5), cz + c[2] * (hs - 0.5))
		yLo, yHi = math.min(yLo, y), math.max(yHi, y)
	end
	if yLo <= -4 then
		return false
	end
	local f = folder("Mushroom", parent)
	local base = yHi
	box("MushroomStem", cx - hs, yLo - 1, cz - hs, cx + hs, base + m.h * B, cz + hs, "px_white_wool", STEM_WHITE, f)
	local capY = base + m.h * B
	if m.ring then
		local r = m.ring * B / 2
		local y0, y1 = capY - B, capY
		box("CapRim", cx - r, y0, cz - r, cx + r, y1, cz - r + B, "px_white_wool", RED_CAP, f)
		box("CapRim", cx - r, y0, cz + r - B, cx + r, y1, cz + r, "px_white_wool", RED_CAP, f)
		box("CapRim", cx - r, y0, cz - r + B, cx - r + B, y1, cz + r - B, "px_white_wool", RED_CAP, f)
		box("CapRim", cx + r - B, y0, cz - r + B, cx + r, y1, cz + r - B, "px_white_wool", RED_CAP, f)
		capDots(cx, cz, m.ring, y1, m.ring, f, 0.35)
		decor(box("Gills", cx - r + B, y1 - 0.3, cz - r + B, cx + r - B, y1 - 0.05, cz + r - B, "px_white_wool", GILL, f))
	else
		decor(box("Gills", cx - capHalf + 0.5, capY - 0.3, cz - capHalf + 0.5, cx + capHalf - 0.5, capY - 0.05, cz + capHalf - 0.5, "px_white_wool", GILL, f))
	end
	for i, c in ipairs(m.caps) do
		local w = c[1] * B / 2
		local yb = base + c[2] * B
		box("Cap", cx - w, yb, cz - w, cx + w, yb + B, cz + w, "px_white_wool", RED_CAP, f)
		local nextW = if m.caps[i + 1] then m.caps[i + 1][1] else 0
		capDots(cx, cz, c[1], yb + B, nextW, f, if c[1] == 1 then 0 else 0.35)
	end
	reserve(cx, cz, capHalf + 2)
	return true
end

-- ================================================================ the cauldron of gold, its stairs, the rainbow
do
	local cd = folder("Cauldron", valley)
	-- CAULDRON moved onto the block grid and 4 studs north, so the stairs from the west path end land in front
	local cx, cz, y0 = -110, -66, CAULDRON.y
	local function layer(name, y, h, test, variant, tint)
		for k = -3, 3 do
			local run = nil
			for i = -3, 4 do
				local inside = i <= 3 and test(math.sqrt(i * i + k * k))
				if inside and not run then
					run = i
				elseif not inside and run then
					box(name, cx + run * B - 2, y, cz + k * B - 2, cx + (i - 1) * B + 2, y + h, cz + k * B + 2, variant, tint, cd)
					run = nil
				end
			end
		end
	end
	for _, s in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		local lx, lz = cx + s[1] * B, cz + s[2] * B
		box("CauldronLeg", lx - 2, math.min(cellY(lx, lz), y0) - 1, lz - 2, lx + 2, y0 + 4, lz + 2, "px_blackstone", nil, cd)
	end
	layer("CauldronBelly", y0 + 4, 4, function(r)
		return r <= 2.6
	end, "px_blackstone")
	layer("CauldronWall", y0 + 8, 8, function(r)
		return r > 2.3 and r <= 3.61
	end, "px_blackstone")
	layer("CauldronRim", y0 + 16, 4, function(r)
		return r > 2.3 and r <= 3.61
	end, "px_obsidian")
	-- the heap of gold: full to the rim, then a stepped mound
	layer("Gold", y0 + 8, 16, function(r)
		return r <= 2.3
	end, "px_gold_block", GOLD_T)
	layer("Gold", y0 + 24, 4, function(r)
		return r <= 1.5
	end, "px_gold_block", GOLD_T)
	cube("Gold", cx, y0 + 30, cz, B, B, B, "px_gold_block", GOLD_T, cd)
	-- gold spilt on the rim
	local rimCells = {}
	for i = -3, 3 do
		for k = -3, 3 do
			local r = math.sqrt(i * i + k * k)
			if r > 2.3 and r <= 3.61 then
				table.insert(rimCells, { i, k })
			end
		end
	end
	for _ = 1, 5 do
		local c = table.remove(rimCells, rng:NextInteger(1, #rimCells))
		cube("Gold", cx + c[1] * B, y0 + 22, cz + c[2] * B, B, B, B, "px_gold_block", GOLD_T, cd)
	end
	-- the stairs from the west path end (-112, -40) up the hill's south face, 4 blocks wide, Minecraft-steep
	stairs("CauldronStairs", -112, -32, -48, 0, 16, 16, "px_stone_bricks", cd)
	for k = 2, 7 do
		local top = 2 * (k + 1)
		box("CauldronStairFill", -120, 0, -34 - 2 * k, -104, top - 4, -32 - 2 * k, "px_stone_bricks", nil, cd)
	end
	for _, sx in ipairs({ -122, -102 }) do
		local y = cellY(sx, -46)
		if y < 20 then
			box("StairPillar", sx - 2, y - 1, -48, sx + 2, 20, -44, "px_mossy_stone_bricks", MOSS_T, cd)
			lantern(V(sx, 20.75, -46), cd)
		end
	end
	reserve(-112, -40, 14)
	reserve(cx, cz, 22)
	leprechaunHat(-126, cellY(-126, -50), -50, cd)

	-- the rainbow: 7 bands (1 block thick, 2 wide) in a vertical plane from the north-west hill into the cauldron,
	-- drawn cell by cell on a 4-stud grid in the plane so it reads pixel-perfect; below the arc's centre line the
	-- bands drop straight down to the ground (the start) or into the gold (the cauldron)
	local rb = folder("Rainbow", valley)
	local dx, dz = cx - RAINBOW_FROM.x, cz - RAINBOW_FROM.z
	local dl = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / dl, dz / dl
	local L = 66 -- RAINBOW_FROM itself is at the island edge: the arc starts 66 studs from the cauldron toward it
	local sx, sz = cx - dx * L, cz - dz * L
	local YB, RO = y0 + 20, 47 -- the ends sit on the rim (y 36); outer radius 47 → the top 40 above the rim
	local yc, uc = YB - 7, L / 2
	local dirW = Vector3.new(dx, 0, dz)
	for i = -4, 20 do
		local u = i * B + B / 2
		local du = math.abs(u - uc)
		if du <= RO then
			local wx, wz = sx + dx * u, sz + dz * u
			local bottom
			if math.sqrt((wx - cx) ^ 2 + (wz - cz) ^ 2) <= 13 then
				bottom = y0 + 16
			else
				bottom = math.max(cellY(wx, wz), cellY(wx - dz * 3, wz + dx * 3), cellY(wx + dz * 3, wz - dx * 3))
			end
			local runB, runY0 = nil, 0
			local function flush(yEnd)
				if runB then
					local h = yEnd - runY0
					local p = part("RainbowBand", Vector3.new(B, h, 2 * B), CFrame.fromMatrix(V(wx, runY0 + h / 2, wz), dirW, Vector3.yAxis), nil, nil, rb)
					textured(p, "px_white_wool", RAINBOW[runB])
				end
				runB = nil
			end
			local j = math.floor(bottom / B)
			while j < 40 do
				local y = j * B + B / 2
				local dy = math.max(0, y - yc)
				local rho = math.sqrt(du * du + dy * dy)
				if rho > RO then
					break
				end
				local b = math.floor((RO - rho) / B) + 1
				if b > 7 then
					b = nil
				end
				if b ~= runB then
					flush(j * B)
					if b then
						runB, runY0 = b, j * B
					end
				end
				j += 1
			end
			flush(j * B)
		end
	end
	reserve(sx, sz, 20)
	for _, u in ipairs({ 18, 30, 42 }) do
		reserve(sx + dx * u, sz + dz * u, 10)
	end
	-- gold blocks and coin piles scattered round the cauldron on the hill (off the stairs and the rainbow)
	for a = 0, 13 do
		local ang = a / 14 * math.pi * 2 + rng:NextNumber(-0.15, 0.15)
		local r = rng:NextNumber(17, 26)
		local gx, gz = g4(cx + math.cos(ang) * r), g4(cz + math.sin(ang) * r)
		local pu, pw = (gx - sx) * dx + (gz - sz) * dz, math.abs((gx - sx) * dz - (gz - sz) * dx)
		local onStairs = gx > -126 and gx < -98 and gz > -54 and gz < -28
		local gy = cellY(gx, gz)
		if not onStairs and not (pu > -18 and pu < 82 and pw < 7) and gy >= 4 and not nearPath(gx, gz, 12) then
			if rng:NextNumber() < 0.55 then
				cube("GoldBlock", gx, gy + 2, gz, B, B, B, "px_gold_block", GOLD_T, cd)
			else
				decor(cube("GoldCoins", gx, gy + 0.5, gz, 2.4, 1, 2.4, "px_gold_block", GOLD_T, cd))
				decor(cube("GoldCoins", gx + 0.4, gy + 1.3, gz - 0.3, 1.4, 0.6, 1.4, "px_gold_block", GOLD_T, cd))
			end
		end
	end
end
task.wait()

-- ================================================================ stone bridges where the paths cross the river
do
	local br = folder("Bridges", valley)
	local DECK_T = Color3.fromRGB(165, 162, 155)
	local gate = FORT_GATES[1]
	for _, g in ipairs(FORT_GATES) do
		if g.name == "West" then
			gate = g
		end
	end
	-- the deck: every river cell under a path (and its edge cells), flush with the path (top y 0); the cells by the
	-- fort's west gate are the fort's own bridge
	for cz = -244, 244, 8 do
		local runX = nil
		local function flush(xEnd)
			if runX then
				box("BridgeDeck", runX, -1.6, cz - 4, xEnd, 0, cz + 4, "px_stone_bricks", DECK_T, br)
			end
			runX = nil
		end
		for cx = -244, 244, 8 do
			local ok = inRiver(cx, cz)
				and not inPlaza(cx, cz)
				and onPath(cx, cz, 4)
				and fortDist(cx, cz) > 80
				and math.sqrt((cx - gate.x) ^ 2 + (cz - gate.z) ^ 2) >= 14
			if ok then
				runX = runX or cx - 4
			else
				flush(cx - 4)
			end
		end
		flush(248)
	end
	-- parapets: lines 12 studs off the path centre; a block stays where it is over (or by) the water and off every
	-- path; the blocks over mid-stream rise one block (the arch's crown); each run ends in a pillar with a lantern
	local LINES = {
		{ -12, -36, -12, -84 }, -- the north path, west side (crossing at (0, -62))
		{ 12, -36, 12, -66 }, -- the north path, east side
		{ 9.2, -56.3, 39.2, -92.3 }, -- the north path's NE leg runs along the river: its south-east side
		{ -135.0, 49.4, -121.4, -5.0 }, -- the west path (crossing at (-139.8, 19.3)), east side
		{ -158.2, 43.6, -144.6, -10.8 }, -- the west path, west side
	}
	for _, ln in ipairs(LINES) do
		local ax, az, bx, bz = ln[1], ln[2], ln[3], ln[4]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		local ux, uz = (bx - ax) / len, (bz - az) / len
		local n = math.floor(len / B)
		local run = {}
		local function endRun()
			if #run >= 2 then
				for _, e in ipairs({ run[1], run[#run] }) do
					local p = part("BridgePillar", Vector3.new(5, 14, 5), CFrame.lookAt(V(e[1], 3, e[2]), V(e[1] + ux, 3, e[2] + uz)), nil, nil, br)
					textured(p, "px_mossy_stone_bricks", MOSS_T)
					lantern(V(e[1], 10.75, e[2]), br)
					reserve(e[1], e[2], 4)
				end
			end
			run = {}
		end
		for i = 0, n do
			local x, z = ax + ux * len * i / n, az + uz * len * i / n
			if inRiver(x, z, 5) and not nearPath(x, z, 11.5) and fortDist(x, z) > 84 then
				local top = if polyDist(RIVER, x, z) <= 4 then 8 else 4
				local cy = (top - 4) / 2
				local p = part("Parapet", Vector3.new(B, top + 4, 4.3), CFrame.lookAt(V(x, cy, z), V(x + ux, cy, z + uz)), nil, nil, br)
				textured(p, "px_stone_bricks", STONE_T)
				table.insert(run, { x, z })
			else
				endRun()
			end
		end
		endRun()
	end
	-- leprechaun gold glinting on the river bed downstream of the west bridge
	local placed = 0
	for _ = 1, 40 do
		if placed >= 8 then
			break
		end
		local t = rng:NextNumber()
		local x, z
		if t < 0.6 then
			local s = t / 0.6
			x, z = -100 - 60 * s, 10 + 14 * s
		else
			x, z = -160 - 50 * (t - 0.6) / 0.4, 24
		end
		x, z = g4(x + rng:NextNumber(-4, 4)), g4(z + rng:NextNumber(-4, 4))
		if inRiver(x, z, -3) and not onPath(x, z, 6) and cellY(x, z) == -4 and x > -200 then
			cube("RiverGold", x, -4, z, B, B, B, "px_gold_block", GOLD_T, br)
			placed += 1
		end
	end
end

-- ================================================================ waterfalls: the river off the west edge, two springs
do
	local wf = folder("Waterfalls", valley)
	local edge = math.huge
	for _, zc in ipairs({ 20, 28 }) do
		for cx = -164, -276, -8 do
			if not onIsland(cx, zc) then
				edge = math.min(edge, cx + 4)
				break
			end
		end
	end
	if edge < math.huge then
		for k = 0, 3 do
			local len = 52 + rng:NextInteger(0, 3) * B
			waterPart("Waterfall", Vector3.new(3, len, B), at(edge - 1.5 - (k % 2) * 0.6, -1 - len / 2, 18 + k * B), wf)
		end
		waterPart("WaterfallLip", Vector3.new(6, 3, 16), at(edge - 1, -2.5, 24), wf)
		local m = decor(part("WaterfallMist", Vector3.new(10, 2, 18), at(edge - 4, -58, 24), nil, nil, wf))
		m.Transparency = 1
		m.CastShadow = false
		mist(m, 14, 12)
		for _, z in ipairs({ 10, 38 }) do
			local y = cellY(edge + 6, z)
			cube("FallRock", g4(edge + 6), y + 2, z, B, 2 * B, B, "px_mossy_cobblestone", MOSS_T, wf)
		end
		reserve(edge + 8, 24, 14)
	end
	-- a spring: a mossy rock with water pouring out, a short kerbed channel to the edge and a thin fall off it
	local function spring(x0, z0, ddx, ddz)
		local lx, lz
		for s = 0, 160, 8 do
			local x, z = x0 + ddx * s, z0 + ddz * s
			if not cellLand(x, z) then
				break
			end
			lx, lz = x, z
		end
		if not lx then
			return
		end
		local ex = if ddx ~= 0 then math.floor(lx / 8) * 8 + 4 + ddx * 4 else lx
		local ez = if ddz ~= 0 then math.floor(lz / 8) * 8 + 4 + ddz * 4 else lz
		local latX, latZ = math.abs(ddz), math.abs(ddx)
		local function along(s)
			return ex - ddx * s, ez - ddz * s
		end
		local sx, sz = along(22)
		local sy = cellY(sx, sz)
		box("SpringRock", sx - 6, sy - 2, sz - 6, sx + 6, sy + 8, sz + 6, "px_mossy_cobblestone", MOSS_T, wf)
		local bx, bz = along(26)
		box("SpringRock", bx - 4, sy + 8, bz - 4, bx + 4, sy + 12, bz + 4, "px_stone", STONE_T, wf)
		local rx, rz = along(20)
		cube("SpringRock", rx + latX * 8, sy + 2, rz + latZ * 8, B, B, B, "px_mossy_stone_bricks", MOSS_T, wf)
		local px, pz = along(15)
		waterPart("SpringSpout", Vector3.new(latX * 4 + latZ * 2, 6, latZ * 4 + latX * 2), at(px, sy + 4, pz), wf)
		local yEnd = sy
		for s = 14, 2, -4 do
			local cx, cz = along(s)
			local y = cellY(cx, cz)
			yEnd = y
			waterPart("SpringBrook", Vector3.new(B, 1, B), at(cx, y + 0.55, cz), wf)
			for _, side in ipairs({ -1, 1 }) do
				cube("SpringKerb", cx + side * latX * B, y + 1, cz + side * latZ * B, B, 2, B, "px_cobblestone", STONE_T, wf)
			end
		end
		waterPart("SpringFall", Vector3.new(latX * 4 + latZ * 2, 40, latZ * 4 + latX * 2), at(ex + ddx, yEnd + 1 - 20, ez + ddz), wf)
		local m = decor(part("SpringMist", Vector3.new(6, 2, 6), at(ex + ddx * 3, yEnd - 38, ez + ddz * 3), nil, nil, wf))
		m.Transparency = 1
		m.CastShadow = false
		mist(m, 5, 6)
		reserve(sx, sz, 12)
		local mx, mz = along(8)
		reserve(mx, mz, 9)
	end
	spring(-42, -148, 0, -1) -- the north edge (over the ridge)
	spring(-100, 170, -1, 0) -- the south-west edge (past the mushroom grove)
end
task.wait()

-- ================================================================ the west hills: hobbit burrows and the windmill
do
	local hills = folder("WestHills", valley)
	local DOOR_GREEN = Color3.fromRGB(105, 185, 85)
	local SOIL = Color3.fromRGB(110, 80, 55)
	-- a burrow dug into a hill: front-centre (fx, fz), the door facing (dx, dz); returns false if it does not fit
	local function burrow(fx, fz, dx, dz)
		local rot = CFrame.Angles(0, faceYaw(dx, dz), 0)
		local probe = at(fx, 0, fz) * rot
		for _, p in ipairs({ { -22, -14 }, { 22, -14 }, { -22, 20 }, { 22, 20 } }) do
			local px, pz = toPlan(probe, p[1], p[2])
			if not cellLand(px, pz) or math.sqrt(px * px + pz * pz) > ISLAND_R - 12 or nearPath(px, pz, PATH_W / 2 + 1) then
				return false
			end
		end
		-- the floor: the highest ground cell under the yard (nothing in the yard rises above it)
		local y0 = -math.huge
		for _, p in ipairs({ { -18, -14 }, { 18, -14 }, { -18, -2 }, { 18, -2 }, { 0, -8 } }) do
			local px, pz = toPlan(probe, p[1], p[2])
			y0 = math.max(y0, cellY(px, pz))
		end
		local fl = y0 + 0.2
		local cf = at(fx, fl, fz) * rot
		local f = folder("Burrow", hills)
		-- the yard terrace, the footing, the plank facade and the grass hill over it (stepped, block by block)
		lbox(cf, "Yard", -18, -12, -14, 18, 0, -1, "px_grass_top", GRASS_T, f)
		decor(lbox(cf, "YardPath", -2, 0, -14, 2, 0.2, -2, "px_gravel", Color3.fromRGB(185, 178, 165), f))
		lbox(cf, "Footing", -17, -12, -2, 17, 1, 3, "px_cobblestone", STONE_T, f)
		lbox(cf, "Facade", -16, 1, -1, 16, 16, 3, "px_planks", PLANK_T, f)
		lbox(cf, "Mound", -20, -12, 3, 20, 16, 19, "px_grass_top", GRASS_T, f)
		lbox(cf, "MoundWing", -22, -12, -3, -16, 12, 15, "px_grass_top", GRASS_T, f)
		lbox(cf, "MoundWing", 16, -12, -3, 22, 12, 15, "px_grass_top", GRASS_T, f)
		lbox(cf, "GrassRoof", -18, 16, -3, 18, 20, 19, "px_grass_top", GRASS_DARK_T, f)
		lbox(cf, "Mound", -14, 20, 1, 14, 24, 17, "px_grass_top", GRASS_T, f)
		lbox(cf, "Mound", -8, 24, 5, 8, 28, 13, "px_grass_top", GRASS_DARK_T, f)
		-- the round green door in a stepped stone frame
		lbox(cf, "Door", -4, 1, -1.5, 4, 9, -1, "px_planks", DOOR_GREEN, f)
		lbox(cf, "Door", -2, 9, -1.5, 2, 12, -1, "px_planks", DOOR_GREEN, f)
		decor(lbox(cf, "DoorKnob", 2.3, 4.6, -2, 3.1, 5.4, -1.5, "px_gold_block", GOLD_T, f))
		lbox(cf, "DoorFrame", -8, 1, -2.5, -4, 9, -1, "px_stone_bricks", STONE_T, f)
		lbox(cf, "DoorFrame", 4, 1, -2.5, 8, 9, -1, "px_stone_bricks", STONE_T, f)
		lbox(cf, "DoorFrame", -6, 9, -2.5, -2, 13, -1, "px_stone_bricks", STONE_T, f)
		lbox(cf, "DoorFrame", 2, 9, -2.5, 6, 13, -1, "px_stone_bricks", STONE_T, f)
		lbox(cf, "DoorFrame", -2, 12, -2.5, 2, 16, -1, "px_mossy_stone_bricks", MOSS_T, f)
		-- two round windows (a pane in a plus-shaped frame) with flower boxes
		for _, s in ipairs({ -1, 1 }) do
			local wx = s * 12
			part("Window", Vector3.new(4, 4, 0.4), cf * CFrame.new(wx, 8, -1.2), WINDOW_C, nil, f)
			lbox(cf, "WindowFrame", wx - 2, 10, -1.8, wx + 2, 11, -1, "px_dark_oak_planks", nil, f)
			lbox(cf, "WindowFrame", wx - 2, 5, -1.8, wx + 2, 6, -1, "px_dark_oak_planks", nil, f)
			lbox(cf, "WindowFrame", wx - 3, 6, -1.8, wx - 2, 10, -1, "px_dark_oak_planks", nil, f)
			lbox(cf, "WindowFrame", wx + 2, 6, -1.8, wx + 3, 10, -1, "px_dark_oak_planks", nil, f)
			decor(lbox(cf, "FlowerBox", wx - 3, 3.6, -2.8, wx + 3, 5, -1, "px_spruce_planks", nil, f))
			for j = 0, 2 do
				decor(lbox(cf, "Flower", wx - 2.6 + j * 2, 5, -2.5, wx - 1.4 + j * 2, 6.2, -1.3, "px_white_wool", pick(FLOWERS), f))
			end
			-- lanterns hanging under the grass eave at the corners
			lantern((cf * CFrame.new(s * 17, 13, -4.5)).Position, f, false, (cf * CFrame.new(0, 16, 0)).Position.Y)
		end
		-- the chimney with smoke
		lbox(cf, "Chimney", 8, 20, 9, 12, 34, 13, "px_cobblestone", STONE_T, f)
		local top = lbox(cf, "ChimneyTop", 7.5, 34, 8.5, 12.5, 35, 13.5, "px_stone_bricks", STONE_T, f)
		emitter(top, {
			Texture = SMOKE_TEX,
			Color = ColorSequence.new(Color3.fromRGB(195, 195, 195)),
			Size = NumberSequence.new(1.5, 4.5),
			Transparency = NumberSequence.new(0.35, 1),
			Lifetime = NumberRange.new(3, 5),
			Rate = 3,
			Speed = NumberRange.new(2, 3),
			SpreadAngle = Vector2.new(8, 8),
			Acceleration = Vector3.new(0.5, 0.6, 0),
		})
		-- the yard: a fence with a gate and lanterns, vegetable patches either side of the path
		local plY = fl
		for _, seg in ipairs({ { -18, -14, -4, -14 }, { 4, -14, 18, -14 }, { -18, -14, -18, -3 }, { 18, -14, 18, -3 } }) do
			local ax, az = toPlan(cf, seg[1], seg[2])
			local bx, bz = toPlan(cf, seg[3], seg[4])
			fence(ax, az, bx, bz, f, plY)
		end
		for _, s in ipairs({ -1, 1 }) do
			lantern((cf * CFrame.new(s * 4, 4.2, -14)).Position, f)
		end
		lbox(cf, "VegPatch", -16, 0, -12, -6, 0.5, -4, "px_dirt", SOIL, f)
		decor(lbox(cf, "Wheat", -15, 0.5, -11, -7, 2.5, -9, "px_hay", nil, f))
		decor(lbox(cf, "Cabbages", -15, 0.5, -7, -7, 2, -5, "px_hedge", Color3.fromRGB(150, 210, 120), f))
		lbox(cf, "VegPatch", 6, 0, -12, 16, 0.5, -4, "px_dirt", SOIL, f)
		lbox(cf, "Pumpkin", 7.5, 0.5, -11.5, 11.5, 4.5, -7.5, "px_white_wool", Color3.fromRGB(230, 130, 30), f)
		decor(lbox(cf, "Carrots", 8, 0.5, -6.5, 15, 2, -4.5, "px_hedge", Color3.fromRGB(120, 180, 70), f))
		local rx, rz = toPlan(cf, 0, 4)
		reserve(rx, rz, 22)
		return true
	end
	local built = 0
	for _, b in ipairs({
		{ -168, -10, 1, 0 },
		{ -172, -54, 1, 0 },
		{ -128, 96, 1, 0 },
		{ -78, -80, 1, 0 },
		{ -120, -122, 0, -1 },
		{ -118, 140, 0, 1 },
	}) do
		if burrow(b[1], b[2], b[3], b[4]) then
			built += 1
		end
	end
	-- the windmill: stone base, plank body, stepped roof and four sails (they turn: AmbientSpin round the hub axis);
	-- the plan's spot is at the very edge, so the first spot that fits is used
	for _, spot in ipairs({ { WINDMILL.x, WINDMILL.z }, { -168, 96 }, { -160, 104 } }) do
		local wx, wz = math.floor(spot[1] / 4 + 0.5) * 4, math.floor(spot[2] / 4 + 0.5) * 4
		local fits = not isReserved(wx, wz, 10)
		local y0 = -math.huge
		for _, c in ipairs({ { -10, -10 }, { 10, -10 }, { -10, 10 }, { 10, 10 }, { 12, -24 }, { 12, 24 } }) do
			local px, pz = wx + c[1], wz + c[2]
			if not cellLand(px, pz) or math.sqrt(px * px + pz * pz) > ISLAND_R - 14 or nearPath(px, pz, PATH_W / 2 + 2) then
				fits = false
			end
			if math.abs(c[1]) == 10 then
				y0 = math.max(y0, cellY(px, pz))
			end
		end
		if fits then
			local f = folder("Windmill", hills)
			box("MillBase", wx - 8, y0 - 12, wz - 8, wx + 8, y0 + 12, wz + 8, "px_cobblestone", STONE_T, f)
			box("MillBand", wx - 8.4, y0 + 11, wz - 8.4, wx + 8.4, y0 + 13, wz + 8.4, "px_stone_bricks", STONE_T, f)
			box("MillBody", wx - 6, y0 + 12, wz - 6, wx + 6, y0 + 32, wz + 6, "px_planks", PLANK_T, f)
			for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
				local bx, bz = wx + s[1] * 6, wz + s[2] * 6
				box("MillBeam", bx - 1, y0 + 12, bz - 1, bx + 1, y0 + 32, bz + 1, "px_dark_oak_log", nil, f)
			end
			for i, w in ipairs({ 8, 6, 4, 2 }) do
				local y = y0 + 28 + i * 4
				box("MillRoof", wx - w, y, wz - w, wx + w, y + 4, wz + w, "px_roof_tiles", nil, f)
			end
			box("MillDoor", wx + 8, y0, wz - 2, wx + 8.5, y0 + 8, wz + 2, "px_dark_oak_planks", nil, f)
			part("MillWindow", Vector3.new(0.4, 4, 4), at(wx + 6.1, y0 + 22, wz), WINDOW_C, nil, f)
			box("MillAxle", wx + 6, y0 + 26, wz - 1.5, wx + 9, y0 + 29, wz + 1.5, "px_dark_oak_log", nil, f)
			local hub = V(wx + 9.75, y0 + 27.5, wz)
			local sails = Instance.new("Model")
			sails.Name = "MillSails"
			sails.Parent = f
			textured(part("MillHub", Vector3.new(1.5, 4, 4), CFrame.new(hub), nil, nil, sails), "px_dark_oak_planks")
			for k = 0, 3 do
				local base = CFrame.new(hub) * CFrame.Angles(math.pi / 4 + k * math.pi / 2, 0, 0)
				textured(part("SailArm", Vector3.new(1, 22, 1), base * CFrame.new(0.9, 12, 0), nil, nil, sails), "px_spruce_planks")
				textured(part("Sail", Vector3.new(0.4, 16, 7), base * CFrame.new(1.1, 14, 4), nil, nil, sails), "px_white_wool", Color3.fromRGB(238, 230, 212))
				for _, yy in ipairs({ 7, 14, 21 }) do
					textured(decor(part("SailBar", Vector3.new(0.6, 0.6, 8), base * CFrame.new(1.4, yy, 3.5), nil, nil, sails)), "px_spruce_planks")
				end
			end
			sails.WorldPivot = CFrame.fromMatrix(hub, Vector3.yAxis, Vector3.xAxis) -- the pivot's Y axis = the hub axis (east)
			sails.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
			sails:SetAttribute("Speed", 0.35)
			CollectionService:AddTag(sails, "AmbientSpin")
			-- hay by the base
			cube("Hay", wx - 2, y0 + 2, wz + 10, B, B, B, "px_hay", nil, f)
			cube("Hay", wx + 2, y0 + 2, wz + 10, B, B, B, "px_hay", nil, f)
			cube("Hay", wx, y0 + 6, wz + 10, B, B, B, "px_hay", nil, f)
			lantern(V(wx + 8.8, y0 + 9.5, wz + 3.5), f, false, y0 + 11)
			reserve(wx, wz, 16)
			reserve(wx + 10, wz, 25)
			break
		end
	end
	print(("[build-leprechaun-valley] valley: %d burrows"):format(built))
end
task.wait()

-- ================================================================ the cultists' camp (flat, CAMP)
do
	local camp = folder("CultistCamp", valley)
	local FX, FZ = 162, 70
	local TENT_A, TENT_B = Color3.fromRGB(45, 110, 50), Color3.fromRGB(60, 135, 60)
	local CLOVER_L = Color3.fromRGB(150, 220, 120)
	-- a banner of the cult: a dark green cloth with a light four-leaf clover on a post
	local function cloverBanner(cf)
		lbox(cf, "BannerPost", -0.5, 0, -0.5, 0.5, 12, 0.5, "px_dark_oak_planks", nil, camp)
		lbox(cf, "BannerBar", 0.5, 11, -0.4, 5.5, 11.8, 0.4, "px_dark_oak_planks", nil, camp)
		decor(lbox(cf, "Banner", 1.5, 3, -0.15, 5.5, 11, 0.15, "px_white_wool", CULT_GREEN, camp))
		for _, s in ipairs({ -1, 1 }) do
			for _, o in ipairs({ { -0.65, -0.65 }, { 0.65, -0.65 }, { -0.65, 0.65 }, { 0.65, 0.65 } }) do
				local ox, oy = 3.5 + o[1], 8 + o[2]
				decor(lbox(cf, "BannerClover", ox - 0.6, oy - 0.6, s * 0.15, ox + 0.6, oy + 0.6, s * 0.3, "px_white_wool", CLOVER_L, camp))
			end
			decor(lbox(cf, "BannerClover", 3.35, 5.6, s * 0.15, 3.65, 7.2, s * 0.3, "px_white_wool", CLOVER_L, camp))
		end
	end
	-- a stepped A-frame tent of green wool, the entrance toward the fire
	local function tent(tx, tz, dx, dz)
		local cf = at(tx, 0, tz) * CFrame.Angles(0, faceYaw(dx, dz), 0)
		lbox(cf, "Tent", -6, 0, -6, 6, 4, 6, "px_white_wool", TENT_A, camp)
		lbox(cf, "Tent", -4, 4, -6, 4, 8, 6, "px_white_wool", TENT_B, camp)
		lbox(cf, "Tent", -2, 8, -6, 2, 12, 6, "px_white_wool", TENT_A, camp)
		decor(lbox(cf, "TentDoor", -2, 0, -6.3, 2, 7, -5.95, nil, Color3.fromRGB(25, 40, 25), camp))
		lbox(cf, "TentRidge", -0.5, 12, -7, 0.5, 13, 7, "px_dark_oak_planks", nil, camp)
		cloverBanner(cf * CFrame.new(7.5, 0, -7))
		local bx, bz = toPlan(cf, -8.5, -3)
		barrel(bx, 0, bz, camp, if rng:NextNumber() < 0.5 then "px_hay" else nil)
	end
	tent(162, 92, 0, -1)
	tent(138, 84, 1, 0)
	tent(184, 72, -1, 0)
	tent(184, 48, -1, 0)
	-- the fire pit: a ring of cobblestone half-blocks, crossed logs, the fire, a tripod with the pot
	for i = -1, 1 do
		for k = -1, 1 do
			if i ~= 0 or k ~= 0 then
				cube("FireRing", FX + i * B, 1, FZ + k * B, B, 2, B, "px_cobblestone", STONE_T, camp)
			end
		end
	end
	for _, a in ipairs({ 0.5, -0.5 }) do
		textured(part("FireLog", Vector3.new(3.8, 1.2, 1.2), at(FX, 0.6, FZ) * CFrame.Angles(0, a, 0), nil, nil, camp), "px_oak_log")
	end
	local fire = decor(part("Fire", Vector3.new(1.8, 1.8, 1.8), at(FX, 1.8, FZ) * CFrame.Angles(0, math.pi / 4, 0), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, camp))
	fire.Transparency = 0.15
	light(fire, 26, 1.4, Color3.fromRGB(255, 160, 80))
	emitter(fire, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(230, 70, 30)),
		Size = NumberSequence.new(1.6, 0.3),
		Transparency = NumberSequence.new(0.2, 1),
		Lifetime = NumberRange.new(0.6, 1.1),
		Rate = 22,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(10, 10),
		LightEmission = 0.8,
	})
	mist(fire, 3, 4, Color3.fromRGB(120, 120, 120))
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local leg = beam("Tripod", V(FX + math.cos(a) * 5, 0, FZ + math.sin(a) * 5), V(FX, 11, FZ), 0.8, nil, camp)
		textured(leg, "px_spruce_planks")
	end
	cube("CampPot", FX, 6, FZ, 3.2, 3, 3.2, "px_blackstone", nil, camp)
	decor(cube("CampBrew", FX, 7.55, FZ, 2.6, 0.1, 2.6, "px_white_wool", Color3.fromRGB(95, 175, 60), camp))
	decor(part("PotChain", Vector3.new(0.25, 3.5, 0.25), at(FX, 9.25, FZ), Color3.fromRGB(55, 55, 60), Enum.Material.Metal, camp))
	-- log benches round the fire (the north side stays open to the path)
	cube("LogBench", FX - 13, 1.2, FZ, 3, 2.4, 12, "px_oak_log", nil, camp)
	cube("LogBench", FX + 13, 1.2, FZ, 3, 2.4, 12, "px_oak_log", nil, camp)
	cube("LogBench", FX, 1.2, FZ + 12, 12, 2.4, 3, "px_oak_log", nil, camp)
	-- the totem post: a log with two carved faces, a green cloth and antlers of dark oak
	do
		local cf = at(174, 0, 90) * CFrame.Angles(0, faceYaw(0, -1), 0)
		lbox(cf, "Totem", -2, 0, -2, 2, 20, 2, "px_oak_log", nil, camp)
		decor(lbox(cf, "TotemCloth", -2.2, 4, -2.2, 2.2, 5, 2.2, "px_white_wool", CULT_GREEN, camp))
		for _, fy in ipairs({ 7, 14 }) do
			lbox(cf, "TotemFace", -2, fy, -2.4, 2, fy + 5, -2, "px_dark_oak_planks", nil, camp)
			for _, ex in ipairs({ -1, 1 }) do
				decor(lbox(cf, "TotemEye", ex - 0.5, fy + 3, -2.6, ex + 0.5, fy + 4, -2.4, "px_blackstone", nil, camp))
			end
			decor(lbox(cf, "TotemMouth", -1.2, fy + 1, -2.6, 1.2, fy + 1.6, -2.4, "px_blackstone", nil, camp))
		end
		for _, s in ipairs({ -1, 1 }) do
			local a = (cf * CFrame.new(s * 1.5, 20, 0)).Position
			local b = (cf * CFrame.new(s * 5, 25, 0)).Position
			local c = (cf * CFrame.new(s * 4, 23.5, 0)).Position
			local d = (cf * CFrame.new(s * 4, 27.5, 0)).Position
			textured(beam("Antler", a, b, 0.8, nil, camp), "px_dark_oak_planks")
			textured(beam("Antler", c, d, 0.7, nil, camp), "px_dark_oak_planks")
		end
	end
	-- stores: barrels, crates, firewood
	barrel(148, 0, 94, camp)
	barrel(152, 0, 95, camp, "px_hay")
	barrel(190, 0, 60, camp)
	crate(128, 0, 90, camp)
	crate(130, 0, 72, camp, nil, 0.3)
	crate(131, 0, 68, camp, 2.6, 0.8)
	cube("Firewood", 132, 1, 95, 8, 2, 3, "px_oak_log", nil, camp)
	cube("Firewood", 132, 3, 95, 4, 2, 3, "px_oak_log", nil, camp)
	-- the cultists round the fire (decorative, no tag)
	for _, c in ipairs({ { 151, 73 }, { 171, 66 }, { 158, 79 }, { 168, 60 } }) do
		npc("Cultist", CFrame.lookAt(V(c[1], 3, c[2]), V(FX, 3, FZ)), {
			shirt = Color3.fromRGB(35, 75, 40),
			pants = Color3.fromRGB(28, 52, 30),
			skin = Color3.fromRGB(205, 170, 140),
		}, camp)
	end
end
task.wait()

-- ================================================================ mushrooms, the fairy ring, dolmens and menhirs
do
	local wild = folder("Wild", valley)
	local made = 0
	for _, m in ipairs({
		{ -72, 170, "large" },
		{ -46, 182, "medium" },
		{ -28, 164, "small" },
		{ -90, 160, "small" },
		{ -52, -108, "large" },
		{ -148, -46, "medium" },
		{ -84, -50, "small" },
		{ -80, -128, "medium" },
		{ -116, 38, "small" },
		{ 100, 160, "medium" },
		{ 112, 112, "medium" },
	}) do
		if mushroom(m[1], m[2], m[3], wild) then
			made += 1
		end
	end
	-- the fairy ring: small red mushrooms round a mossy stone
	do
		local fr = folder("FairyRing", wild)
		local cx, cz = g4(FAIRY_RING.x), g4(FAIRY_RING.z)
		local y = cellY(cx, cz)
		cube("RingStone", cx, y + 3, cz, B, 8, B, "px_mossy_cobblestone", MOSS_T, fr)
		cube("RingStone", cx + B, y + 1, cz, B, 4, B, "px_mossy_stone_bricks", MOSS_T, fr)
		decor(cube("RingMoss", cx, y + 7.1, cz, B, 0.2, B, "px_hedge", Color3.fromRGB(140, 190, 110), fr))
		for i = 0, 11 do
			local a = i / 12 * math.pi * 2
			local x = math.floor((cx + math.cos(a) * 12) / 2 + 0.5) * 2
			local z = math.floor((cz + math.sin(a) * 12) / 2 + 0.5) * 2
			local yy = cellY(x, z)
			decor(cube("RingStem", x, yy + 1, z, 1.6, 2, 1.6, "px_white_wool", STEM_WHITE, fr))
			decor(cube("RingCap", x, yy + 2.8, z, 3.6, 1.6, 3.6, "px_white_wool", RED_CAP, fr))
			decor(cube("RingDot", x + 0.6, yy + 3.65, z - 0.6, 1.2, 0.1, 1.2, "px_white_wool", DOT_WHITE, fr))
		end
		for _, o in ipairs({ { -6, -4 }, { 5, 6 }, { -3, 7 }, { 6, -6 } }) do
			local x, z = cx + o[1], cz + o[2]
			local yy = cellY(x, z)
			decor(part("FlowerStem", Vector3.new(0.3, 1.4, 0.3), at(x, yy + 0.7, z), Color3.fromRGB(80, 140, 60), nil, fr))
			decor(cube("Flower", x, yy + 1.6, z, 1.1, 1.1, 1.1, "px_white_wool", pick(FLOWERS), fr))
		end
		reserve(cx, cz, 18)
	end
	-- dolmens: two uprights and a capstone, a back stone, a fallen block, a stump with a lantern
	for _, d in ipairs({ { -24, -136, 0.3 }, { 140, 130, -0.4 } }) do
		local x, z, yaw = d[1], d[2], d[3]
		if isFree(x, z, 6) then
			local cf0 = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
			local y = math.huge
			for _, ox in ipairs({ -6, 6 }) do
				local px, pz = toPlan(cf0, ox, 0)
				y = math.min(y, cellY(px, pz))
			end
			local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
			local f = folder("Dolmen", wild)
			lbox(cf, "DolmenStone", -8, -4, -2, -4, 12, 2, "px_mossy_cobblestone", MOSS_T, f)
			lbox(cf, "DolmenStone", 4, -4, -2, 8, 12, 2, "px_mossy_cobblestone", MOSS_T, f)
			lbox(cf, "DolmenCap", -10, 12, -4, 10, 16, 4, "px_stone", STONE_T, f)
			decor(lbox(cf, "DolmenMoss", -6, 16, -2, 4, 16.3, 4, "px_hedge", Color3.fromRGB(140, 190, 110), f))
			lbox(cf, "DolmenStone", -4, -4, 6, 4, 6, 10, "px_cobblestone", STONE_T, f)
			lbox(cf, "DolmenRubble", 10, -1, -7, 14, 2, -3, "px_mossy_cobblestone", MOSS_T, f)
			lbox(cf, "Stump", -14, -2, 2, -10, 3, 6, "px_oak_log", nil, f)
			lantern((cf * CFrame.new(-12, 3.75, 4)).Position, f)
			reserve(x, z, 16)
		end
	end
	-- menhirs: single standing stones by the dolmens and a row along the north ridge
	for _, m in ipairs({ { -42, -148, 3 }, { -14, -118, 2 }, { 158, 118, 3 }, { 124, 144, 2 }, { -90, -160, 4 }, { -72, -168, 3 }, { -54, -174, 2 }, { -134, -150, 3 } }) do
		local x, z = g4(m[1]), g4(m[2])
		if isFree(x, z, 2) then
			local y = cellY(x, z)
			box("Menhir", x - 2, y - 2, z - 2, x + 2, y + (m[3] - 1) * B, z + 2, "px_mossy_cobblestone", MOSS_T, wild)
			box("Menhir", x - 2, y + (m[3] - 1) * B, z - 2, x + 2, y + m[3] * B, z + 2, "px_stone", STONE_T, wild)
			reserve(x, z, 4)
		end
	end
	print(("[build-leprechaun-valley] valley: %d mushrooms"):format(made))
end

-- ================================================================ the lookout over the clouds (the arrival path's end)
do
	local lk = folder("Lookout", valley)
	local edgeZ = math.huge
	for _, cx in ipairs({ -12, -4, 4, 12 }) do
		for cz = 180, 276, 8 do
			if not onIsland(cx, cz) then
				edgeZ = math.min(edgeZ, cz - 4)
				break
			end
		end
	end
	if edgeZ < math.huge then
		local z1 = edgeZ + 20
		box("LookoutDeck", -12, -0.6, edgeZ - 12, 12, 0.4, z1, "px_dark_oak_planks", nil, lk)
		for _, x in ipairs({ -10, 0, 10 }) do
			box("LookoutJoist", x - 1, -2.6, edgeZ - 4, x + 1, -0.6, z1, "px_spruce_planks", nil, lk)
			textured(beam("LookoutBrace", V(x, -2.6, z1 - 2), V(x, -18, edgeZ - 2), 2, nil, lk), "px_oak_log")
		end
		fence(-12, edgeZ - 6, -12, z1, lk, 0.4)
		fence(12, edgeZ - 6, 12, z1, lk, 0.4)
		fence(-12, z1, 12, z1, lk, 0.4)
		for _, x in ipairs({ -12, 12 }) do
			lantern(V(x, 4.6, z1), lk)
		end
		box("LookoutBench", -8, 0.4, z1 - 8, -2, 1.9, z1 - 6, "px_spruce_planks", nil, lk)
		textured(part("SpyglassPost", Vector3.new(1, 4, 1), at(6, 2.4, z1 - 4), nil, nil, lk), "px_dark_oak_planks")
		part("Spyglass", Vector3.new(0.9, 0.9, 3.4), at(6, 4.8, z1 - 4) * CFrame.Angles(math.rad(12), 0, 0), Color3.fromRGB(150, 110, 50), Enum.Material.Metal, lk)
		leprechaunHat(-9, 0.4, z1 - 2.5, lk)
		reserve(0, edgeZ, 22)
	end
end

-- ================================================================ signposts at the junctions, lamp posts along the paths
do
	local signs = folder("Signposts", valley)
	signpost(14, -42, { { "Форт", 0.64, -0.77 }, { "Шахта", 0, 1 } }, signs)
	signpost(-102, 46, { { "Котёл золота", -1, 0 }, { "Шахта", 1, 0 } }, signs)
	signpost(-164, 74, { { "Котёл золота", 0.24, -0.97 }, { "Шахта", 1, 0 }, { "Мельница", -0.3, 1 } }, signs)
	signpost(104, 70, { { "Лагерь", 0.97, -0.26 }, { "Форт", 0.55, -0.84 }, { "Шахта", -1, 0 } }, signs)
	signpost(140, 26, { { "Лагерь", 0.41, 0.91 }, { "Форт", 0.55, -0.84 }, { "Шахта", -0.97, 0.26 } }, signs)
	signpost(14, 176, { { "Смотровая", 0, 1 }, { "Шахта", 0, -1 } }, signs)
	signpost(-98, -28, { { "Котёл золота", -0.76, -0.65 } }, signs)

	local lamps = folder("Lamps", valley)
	local side = 1
	for _, line in ipairs(PATHS) do
		local carry = 14
		for i = 1, #line - 1 do
			local ax, az, bx, bz = line[i][1], line[i][2], line[i + 1][1], line[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local ux, uz = (bx - ax) / len, (bz - az) / len
			local s = carry
			while s <= len do
				local cx, cz = ax + ux * s, az + uz * s
				local x, z = g4(cx - uz * 13 * side), g4(cz + ux * 13 * side)
				local ok = not inPlaza(x, z, 6)
					and fortDist(x, z) > 96
					and not inRiver(x, z, 4)
					and cellLand(x, z)
					and math.sqrt(x * x + z * z) < ISLAND_R - 14
					and not isReserved(x, z, 2)
					and not nearPath(x, z, 11.5)
				if ok then
					lampPost(x, z, lamps, false, faceYaw(cx - x, cz - z), cellY(x, z))
					reserve(x, z, 4)
				end
				side = -side
				s += 28
			end
			carry = s - len
		end
	end
end
task.wait()

-- ================================================================ trees, bushes, flowers, clover, grass, rocks
reserve(28, 160, 16) -- the buyer's stall (it reaches past the plaza)
reserve(-14, 158, 6) -- the zone sign
do
	local trees = folder("Trees", valley)
	local BIRCH_LEAF = Color3.fromRGB(175, 215, 125)
	local SPRUCE_LEAF = Color3.fromRGB(95, 140, 85)
	local n = 0
	-- a tree may stand by a path only if its crown starts above head height (tall variants), never on it
	local function treeSpot(x, z)
		return freeGround(x, z, 0)
			and cellLand(x, z)
			and not inRiver(x, z, 4)
			and not nearPath(x, z, PATH_W / 2 + 4)
			and not inPlaza(x, z, 4)
			and fortDist(x, z) > 96
			and not inCamp(x, z, 6)
			and not isReserved(x, z, 5)
			and cellY(x, z) > -4
	end
	for gx = -216, 216, 10 do
		for gz = -216, 216, 10 do
			local x = g4(gx + rng:NextNumber(-4, 4))
			local z = g4(gz + rng:NextNumber(-4, 4))
			local dens = 0.65 + n2(x, z, 4.4, 0.025) * 0.9
			if rng:NextNumber() < dens and treeSpot(x, z) then
				local y = cellY(x, z)
				local clear = not nearPath(x, z, PATH_W / 2 + 14) and not inPlaza(x, z, 14)
				local kind = rng:NextNumber()
				if kind < 0.1 and clear and not isReserved(x, z, 12) and not nearPath(x, z, PATH_W / 2 + 24) then
					-- a great oak: a 2×2 trunk and a wide stepped crown
					local f = folder("Tree", trees)
					local cx, cz = x - 2, z - 2
					local ylo, yhi = math.huge, -math.huge
					for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
						local cy = cellY(cx + c[1], cz + c[2])
						ylo, yhi = math.min(ylo, cy), math.max(yhi, cy)
					end
					y = yhi
					box("Trunk", cx - 4, ylo - 1, cz - 4, cx + 4, y + 16, cz + 4, "px_oak_log", nil, f)
					for _, l in ipairs({ { 7, 12 }, { 7, 16 }, { 5, 20 }, { 3, 24 } }) do
						local w = l[1] * B / 2 + 2
						box("Leaves", cx - w, y + l[2], cz - w, cx + w, y + l[2] + B, cz + w, "px_hedge", nil, f)
					end
					reserve(cx, cz, 12)
				elseif kind < 0.6 then
					tree(x, z, if clear then pick({ 8, 12, 12 }) else pick({ 12, 16 }), trees, "px_hedge", "px_oak_log", y)
				elseif kind < 0.85 then
					local f = folder("Tree", trees)
					local h = if clear then pick({ 12, 16 }) else 16
					box("Trunk", x - 2, y, z - 2, x + 2, y + h, z + 2, "px_birch_log", nil, f)
					box("Leaves", x - 6, y + h - 8, z - 6, x + 6, y + h, z + 6, "px_hedge", BIRCH_LEAF, f)
					box("Leaves", x - 2, y + h, z - 6, x + 2, y + h + 4, z + 6, "px_hedge", BIRCH_LEAF, f)
					box("Leaves", x - 6, y + h, z - 2, x - 2, y + h + 4, z + 2, "px_hedge", BIRCH_LEAF, f)
					box("Leaves", x + 2, y + h, z - 2, x + 6, y + h + 4, z + 2, "px_hedge", BIRCH_LEAF, f)
				else
					local f = folder("Tree", trees)
					local h = if clear then pick({ 16, 20 }) else 20
					box("Trunk", x - 2, y, z - 2, x + 2, y + h, z + 2, "px_dark_oak_log", nil, f)
					for _, l in ipairs({ { 5, h - 12 }, { 3, h - 8 }, { 3, h - 4 }, { 1, h } }) do
						local w = l[1] * B / 2
						box("Leaves", x - w, y + l[2], z - w, x + w, y + l[2] + B, z + w, "px_hedge", SPRUCE_LEAF, f)
					end
				end
				reserve(x, z, 7)
				n += 1
			end
		end
	end
	print(("[build-leprechaun-valley] valley: %d trees"):format(n))
end
task.wait()
do
	local deco = folder("Undergrowth", valley)
	for gx = -220, 220, 8 do
		for gz = -220, 220, 8 do
			local x = g4(gx + rng:NextNumber(-3, 3))
			local z = g4(gz + rng:NextNumber(-3, 3))
			if isFree(x, z, 2) then
				local y = cellY(x, z)
				local r = rng:NextNumber()
				if r < 0.12 then
					if isFree(x, z, 6) then
						box("Bush", x - 2, y, z - 2, x + 2, y + B, z + 2, "px_hedge", Color3.fromRGB(150, 200, 120), deco)
						if rng:NextNumber() < 0.4 then
							local o = pick({ { B, 0 }, { -B, 0 }, { 0, B }, { 0, -B } })
							box("Bush", x + o[1] - 2, y, z + o[2] - 2, x + o[1] + 2, y + B, z + o[2] + 2, "px_hedge", Color3.fromRGB(130, 185, 105), deco)
						end
					end
				elseif r < 0.26 then
					local col = pick(FLOWERS)
					for _ = 1, 3 do
						local fx, fz = x + rng:NextNumber(-1.4, 1.4), z + rng:NextNumber(-1.4, 1.4)
						decor(part("FlowerStem", Vector3.new(0.3, 1.4, 0.3), at(fx, y + 0.7, fz), Color3.fromRGB(80, 140, 60), nil, deco))
						decor(cube("Flower", fx, y + 1.6, fz, 1.1, 1.1, 1.1, "px_white_wool", col, deco))
					end
				elseif r < 0.42 then
					decor(cube("Clover", x, y + 0.1, z, B, 0.2, B, "px_grass_top", CLOVER_T, deco))
					if rng:NextNumber() < 0.5 then
						local o = pick({ { B, 0 }, { -B, 0 }, { 0, B }, { 0, -B } })
						decor(cube("Clover", x + o[1], y + 0.1, z + o[2], B, 0.2, B, "px_grass_top", CLOVER_T, deco))
					end
				elseif r < 0.72 then
					for _, a in ipairs({ math.pi / 4, -math.pi / 4 }) do
						local t = decor(part("TallGrass", Vector3.new(0.15, 2.2, 2.6), at(x, y + 1.1, z) * CFrame.Angles(0, a, 0), nil, nil, deco))
						textured(t, "px_hedge", Color3.fromRGB(140, 200, 100))
						t.CastShadow = false
					end
				elseif r < 0.79 then
					if isFree(x, z, 6) then
						local v = pick({ "px_cobblestone", "px_mossy_cobblestone", "px_stone" })
						local wide = rng:NextNumber() < 0.35
						box("Rock", x - 2, y - 1, z - 2, x + (if wide then 6 else 2), y + 2.5, z + 2, v, if v == "px_mossy_cobblestone" then MOSS_T else STONE_T, deco)
					end
				end
			end
		end
	end
end
print(("[build-leprechaun-valley] valley: %d parts"):format(count - startCount))
