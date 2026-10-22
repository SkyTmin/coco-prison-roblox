--!nocheck
-- Builds the Подвал (basement), level 5 + the eternal pass [меню, владелец]. The whole location is INSIDE,
-- one long linear cellar [владелец 22.10: «вся локация внутри; вытянутая, линейно»; then «все комнаты
-- квадратные, плоские, мне вообще не нравится — мастерство на высшем уровне»]. So nothing here is a box:
--   * the cellar is carved out of a 4-stud block grid like a Minecraft cave: every open cell gets a floor
--     block and a ceiling block, every closed cell next to an open one is a rock column — irregular walls
--     (noise on the outline), stepped domes (the ceiling rises with the distance from the wall), winding
--     tunnels, raised rubble along the walls, a stair down into the lair;
--   * the prison's old masonry cellar at the start (the arrival hall: a brick barrel vault with ribs,
--     pilasters, barred cells, a stair to a sealed door) breaks down into natural caves: brick fades into
--     cobble and rock along the first tunnel, a broken arch marks the end of the masonry;
--   * caves: stone with ore veins (coal, iron; the ore cave also gold, lapis and iron blocks glinting in the
--     walls), moss, stalactites and stalagmites, roots, cobwebs, glowing mushrooms, puddles and drips.
-- Route (south → north) [владелец 22.10]:
--   1. the arrival hall: three closed sides, the fourth opens onto the cellar (a brick arch);
--   2. a tunnel with 2 rats;
--   3. cave 1 with mine 1, small (dirt / sand / gravel), a zombie on each side (respawn 2 min);
--   4. a tunnel with 2 rats;
--   5. cave 2 with mine 2, small (iron / diamond / gold / lapis blocks, design-decisions mines.basement_ore);
--   6. a tunnel stepping down to the lair;
--   7. the lair of Сплинтер: a round cave, a stone dais (BossSpawn; BossHud draws the «возродится через»
--      board), the rat's nest, heaps of rubbish [меню: «выросшая в мраке подземелий и гор мусора»], a rat
--      at each of the four diagonals, a zombie at each of the four sides.
-- Both mines reset every 30 s [меню Prison+]. No way out: players come and go by teleport.
-- A separate zone at X = 1500 so StreamingEnabled loads it only for players who are there.
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces
-- Workspace.Basement. Arrival: LocationSpawn, LocationId "basement".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)
local old = workspace:FindFirstChild("Basement")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Basement"
root.Parent = workspace

local BX, BZ = 1500, 0 -- zone origin (the arrival hall centre)
local B = 4 -- block size
local C = 4 -- carve grid cell
local rng = Random.new(20261023) -- fixed seed: the same cellar every rebuild
local STONE = Color3.fromRGB(110, 110, 114)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(120, 85, 50)
local IRON = Color3.fromRGB(62, 62, 68)
local TORCH = Color3.fromRGB(255, 180, 100)
local BEDROCK = Color3.fromRGB(62, 58, 66)
local WALL_TINT = Color3.fromRGB(196, 192, 188) -- rock a little darker than the floor
local CEIL_TINT = Color3.fromRGB(170, 166, 164)
local TOP = 76 -- every rock column reaches this high: no gap ever shows the sky

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or STONE
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end
local function textured(p, variant, tint)
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = variant
	p.Color = tint or Color3.new(1, 1, 1)
	return p
end
local function decor(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end
local function at(x, y, z)
	return CFrame.new(BX + x, y, BZ + z)
end
local function box(name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local p = part(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
local function light(parentPart, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Shadows = false
	l.Parent = parentPart
	return l
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(140, 24)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 90
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color or Color3.fromRGB(255, 190, 60)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
end
local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

-- ================================================================ the plan
-- Shapes in zone coordinates (z runs north = negative). Tunnels are polylines with a radius, caves are
-- ellipses; the noise on the radius makes the outline ragged. heights = { min at the wall, max in the middle }.
local HALL = { x0 = -16, x1 = 16, z0 = 16, z1 = -16 } -- the arrival hall interior (32 × 32)
local PORTAL = 12 -- half width of the hall's open side
local M1 = { size = 16, depth = 8, cz = -136 } -- mine 1: 16 × 8 × 16 blocks (locations.json basement.mine.size)
local M2 = { size = 12, depth = 6, cz = -292 } -- mine 2: 12 × 6 × 12 blocks (anchor attribute Size)
for _, m in ipairs({ M1, M2 }) do
	m.w = m.size * B
	m.hole = m.w / 2 + 2 * B -- half size of the hole in the floor (the pit plus its bedrock walls)
end
-- the lair: a ROUND hall of an ancient abandoned castle under a dome [владелец 22.10: «зал в древнем заброшенном
-- замке»; «зал сделай круглым, окна убери, статуи во весь рост зала, потолок купольный»], radius 96 (×2 of the
-- first lair [владелец: «увеличь арену и комнату в 2 раза»]), its door in the south at z = −404
local LAIR = { cx = 0, cz = -500, r = 96, floor = -8, door = 12 }
LAIR.hx = LAIR.r
LAIR.z0, LAIR.z1 = LAIR.cz + LAIR.r, LAIR.cz - LAIR.r
-- the dome: 39 above the floor at the wall rising to 68 at the top, 2-stud steps
local function domeCeil(r)
	return LAIR.floor + 28 + 2 * math.floor(20 * math.sqrt(math.max(0, 1 - (r / 100) ^ 2)) + 0.5)
end
local function lairCeil(x, z)
	return domeCeil(math.sqrt((x - LAIR.cx) ^ 2 + ((z or LAIR.cz) - LAIR.cz) ^ 2))
end
local function inLair(x, z)
	return (x - LAIR.cx) ^ 2 + (z - LAIR.cz) ^ 2 < LAIR.r ^ 2
end
local SHAPES = {
	{ id = "tunnel1", kind = "line", r = 14, pts = { { 0, -12 }, { 5, -34 }, { -7, -58 }, { 2, -80 }, { 0, -92 } }, h = { 13, 21 } },
	{ id = "cave1", kind = "ellipse", cx = 0, cz = M1.cz, rx = 62, rz = 56, h = { 15, 38 } },
	{ id = "tunnel2", kind = "line", r = 14, pts = { { 0, -186 }, { -9, -208 }, { 7, -230 }, { 0, -252 } }, h = { 13, 21 } },
	{ id = "cave2", kind = "ellipse", cx = 0, cz = M2.cz, rx = 52, rz = 48, h = { 15, 34 } },
	{ id = "tunnel3", kind = "line", r = 14, pts = { { 0, -334 }, { 9, -354 }, { -5, -376 }, { 0, -400 } }, h = { 13, 21 } },
	{ id = "lair", kind = "rect" }, -- carved exactly (inLair), not by the noise
	-- side grottos off the route, each with its own little story (see "grottos" below)
	{ id = "storeroom", kind = "ellipse", cx = 17, cz = -66, rx = 14, rz = 10, h = { 11, 17 } },
	{ id = "spring", kind = "ellipse", cx = -27, cz = -212, rx = 15, rz = 11, h = { 11, 18 } },
	{ id = "shaft", kind = "ellipse", cx = 52, cz = -308, rx = 15, rz = 10, h = { 11, 17 } },
}
local SHAPE = {}
for _, s in ipairs(SHAPES) do
	SHAPE[s.id] = s
end

local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	local cx, cz = ax + dx * t, az + dz * t
	return math.sqrt((px - cx) ^ 2 + (pz - cz) ^ 2)
end
local function lineDist(pts, x, z)
	local best = math.huge
	for i = 1, #pts - 1 do
		best = math.min(best, segDist(x, z, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]))
	end
	return best
end
-- a point along a polyline at fraction t of its length
local function linePoint(pts, t)
	local total, lens = 0, {}
	for i = 1, #pts - 1 do
		lens[i] = math.sqrt((pts[i + 1][1] - pts[i][1]) ^ 2 + (pts[i + 1][2] - pts[i][2]) ^ 2)
		total += lens[i]
	end
	local want = total * t
	for i = 1, #pts - 1 do
		if want <= lens[i] then
			local k = want / lens[i]
			return pts[i][1] + (pts[i + 1][1] - pts[i][1]) * k, pts[i][2] + (pts[i + 1][2] - pts[i][2]) * k
		end
		want -= lens[i]
	end
	return pts[#pts][1], pts[#pts][2]
end
local function n2(x, z, seed, scale)
	return math.noise(x * scale, z * scale, seed)
end

-- the floor level: 0, then a stair down (1 stud every 4) in tunnel 3, the lair 8 studs lower
local STAIR_TOP, STAIR_BOTTOM = -352, -384
local function floorAt(z)
	if z >= STAIR_TOP then
		return 0
	elseif z <= STAIR_BOTTOM then
		return LAIR.floor
	end
	return -math.min(8, math.floor((STAIR_TOP - z) / 4) + 1)
end

-- ================================================================ carve the grid
local X0, ZTOP = -116, 28
local NX, NZ = 58, 164
local function cx(ix)
	return X0 + ix * C + C / 2
end
local function cz(iz)
	return ZTOP - iz * C - C / 2
end
local cells = {} -- [ix + iz * NX] = { shape, floor, ceil, edge, hole, path, ... } for open cells
local function key(ix, iz)
	return ix + iz * NX
end
-- the hall's barrel vault: 14 at the walls, 22 in the middle, 2-stud steps
local function hallCeil(x)
	return 14 + 2 * math.floor(4 * math.sqrt(math.max(0, 1 - (x / 18) ^ 2)) + 0.5)
end
local function inHall(x, z)
	return x > HALL.x0 and x < HALL.x1 and z < HALL.z0 and z > HALL.z1
end
-- the barred cells: 8 × 8 alcoves cut into the hall's side walls (west at z = 8 and −8, east at z = 8)
local ALCOVES = { { -1, 8 }, { -1, -8 }, { 1, 8 } }
local function inAlcove(x, z)
	for _, a in ipairs(ALCOVES) do
		if x * a[1] > HALL.x1 and x * a[1] < HALL.x1 + 8 and math.abs(z - a[2]) < 4 then
			return true
		end
	end
	return false
end
local function inHole(x, z)
	for _, m in ipairs({ M1, M2 }) do
		if math.abs(x) < m.hole and math.abs(z - m.cz) < m.hole then
			return m
		end
	end
	return nil
end
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = cx(ix), cz(iz)
		local shape, best = nil, math.huge
		if inHall(x, z) or inAlcove(x, z) then
			shape, best = "hall", 0
		elseif z < LAIR.z0 + 4 then
			-- the castle hall: straight walls, one great door in the south wall
			if inLair(x, z) then
				shape, best = "lair", 0
			elseif z > LAIR.z0 and math.abs(x) < LAIR.door then
				shape, best = "tunnel3", 0
			end
		elseif z > HALL.z1 - 4 then
			-- the hall's walls stay straight: only the portal opens north
			if math.abs(x) < PORTAL and z < HALL.z1 then
				shape, best = "tunnel1", 0
			end
		else
			for _, s in ipairs(SHAPES) do
				local score = math.huge
				if s.kind == "line" then
					score = lineDist(s.pts, x, z) / (s.r + n2(x, z, 1.7, 0.08) * 3)
				elseif s.kind == "ellipse" then
					local d = math.sqrt(((x - s.cx) / s.rx) ^ 2 + ((z - s.cz) / s.rz) ^ 2)
					score = d / (1 + n2(x, z, 4.2, 0.05) * 0.07)
				end
				if score < best then
					shape, best = s.id, score
				end
			end
			if best >= 1 then
				shape = nil
			end
		end
		if shape then
			cells[key(ix, iz)] = { shape = shape, x = x, z = z, floor = floorAt(z), hole = inHole(x, z), alcove = inAlcove(x, z) }
		end
	end
end
local function cellAt(ix, iz)
	if ix < 0 or iz < 0 or ix >= NX or iz >= NZ then
		return nil
	end
	return cells[key(ix, iz)]
end
local function cellAtPos(x, z)
	return cellAt(math.floor((x - X0) / C), math.floor((ZTOP - z) / C))
end
-- distance to the wall in cells (BFS from the closed cells): drives the domes and the decor
do
	local queue, head = {}, 1
	for iz = 0, NZ - 1 do
		for ix = 0, NX - 1 do
			local c = cellAt(ix, iz)
			if c then
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					if not cellAt(ix + d[1], iz + d[2]) then
						c.edge = 1
						table.insert(queue, { ix, iz })
						break
					end
				end
			end
		end
	end
	while head <= #queue do
		local q = queue[head]
		head += 1
		local c = cellAt(q[1], q[2])
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local n = cellAt(q[1] + d[1], q[2] + d[2])
			if n and not n.edge then
				n.edge = c.edge + 1
				table.insert(queue, { q[1] + d[1], q[2] + d[2] })
			end
		end
	end
end
-- the trail: down the middle of the tunnels, round the pits, across the lair to the dais
local function onTrail(c)
	local s = SHAPE[c.shape]
	if c.shape == "hall" then
		return math.abs(c.x) < 4 and c.z < 4
	elseif s and s.kind == "line" then
		return lineDist(s.pts, c.x, c.z) < 3.5 + n2(c.x, c.z, 9.1, 0.2) * 1.5
	elseif c.shape == "cave1" or c.shape == "cave2" then
		local m = if c.shape == "cave1" then M1 else M2
		local d = math.max(math.abs(c.x), math.abs(c.z - m.cz))
		return d > m.hole and d < m.hole + 8
	end
	return false
end
-- floor relief and the ceiling
for _, c in pairs(cells) do
	c.path = onTrail(c)
	local s = SHAPE[c.shape]
	if c.alcove then
		c.ceil = 10
	elseif c.shape == "hall" then
		c.ceil = hallCeil(c.x)
	elseif c.shape == "lair" then
		c.ceil = lairCeil(c.x, c.z)
	else
		local R = if s.kind == "line" then 3 elseif s.id == "lair" then 14 else 7
		local k = math.min(1, (c.edge - 1) / R) ^ 0.7
		local ceil = s.h[1] + (s.h[2] - s.h[1]) * k + n2(c.x, c.z, 6.3, 0.09) * 3
		c.ceil = c.floor + math.max(11, 2 * math.floor(ceil / 2 + 0.5))
		-- rubble along the cave walls: the floor steps up a stud or two (never on the trail or by a pit)
		local nearHole = false
		for _, m in ipairs({ M1, M2 }) do
			if math.abs(c.x) < m.hole + 10 and math.abs(c.z - m.cz) < m.hole + 10 then
				nearHole = true
			end
		end
		if c.edge == 1 and not c.path and not nearHole and n2(c.x, c.z, 2.2, 0.15) > 0.05 then
			c.floor += if n2(c.x, c.z, 3.3, 0.3) > 0.2 then 2 else 1
		end
	end
end

-- ================================================================ materials
local function pick(c, seed)
	return n2(c.x, c.z, seed, 0.11)
end
local function wallVariant(x, z, shape)
	local v = math.noise(x * 0.09, z * 0.09, 11.1)
	local r = rng:NextNumber()
	if shape == "hall" then
		return if v > 0.25 then "px_mossy_stone_bricks" else "px_stone_bricks"
	end
	if shape == "lair" then
		-- the castle masonry, patched with cobble; in the north-east corner the cave rock has broken in
		if x > 44 and z < LAIR.z1 + 40 then
			return if v > 0.2 then "px_mossy_cobblestone" elseif v > -0.1 then "px_cobblestone" else "px_stone"
		end
		return if v > 0.28 then "px_mossy_stone_bricks" elseif r < 0.07 then "px_cobblestone" else "px_stone_bricks"
	end
	-- the masonry of the first tunnel crumbles into the rock: brick near the hall, cobble, then stone
	if shape == "tunnel1" and z > -44 then
		local brick = math.clamp((z + 44) / 30, 0, 1)
		if r < brick then
			return if v > 0.2 then "px_mossy_stone_bricks" else "px_stone_bricks"
		elseif r < brick + 0.3 then
			return if v > 0 then "px_mossy_cobblestone" else "px_cobblestone"
		end
	end
	if shape == "cave2" then
		if r < 0.03 then
			return "px_gold_ore"
		elseif r < 0.045 then
			return "px_lapis_block"
		elseif r < 0.055 then
			return "px_iron_block"
		end
	end
	if r < 0.04 then
		return "px_coal_ore"
	elseif r < 0.065 then
		return "px_iron_ore"
	end
	if v > 0.32 then
		return "px_mossy_cobblestone"
	elseif v > 0.18 then
		return "px_cobblestone"
	elseif v < -0.35 then
		return "px_gravel"
	end
	return "px_stone"
end
local function floorVariant(c)
	if c.alcove then
		return "px_cobblestone"
	elseif c.shape == "hall" then
		if c.path then
			return "px_cobblestone"
		end
		return if (math.floor(c.x / 4) + math.floor(c.z / 4)) % 2 == 0 then "px_smooth_stone" else "px_stone_bricks"
	end
	if c.path then
		return if pick(c, 21.5) > -0.1 then "px_gravel" else "px_dirt"
	end
	local v = pick(c, 13.7)
	if c.shape == "lair" then
		-- the castle floor: big slabs in a checker, moss creeping in, broken through to the earth in places
		if v < -0.42 then
			return if v < -0.55 then "px_dirt" else "px_gravel"
		elseif v > 0.3 then
			return "px_mossy_stone_bricks"
		end
		return if (math.floor(c.x / 8) + math.floor(c.z / 8)) % 2 == 0 then "px_stone_bricks" else "px_smooth_stone"
	end
	if c.shape == "tunnel1" and c.z > -40 then
		return if v > 0 then "px_cobblestone" else "px_mossy_cobblestone"
	end
	return if v > 0.3 then "px_cobblestone" elseif v < -0.3 then "px_gravel" elseif v < -0.15 then "px_dirt" else "px_stone"
end

-- the vault: plain stone over the caves, brick over the halls; the dome of the lair mixes in moss and cobble so it
-- never reads as one flat colour [владелец 22.10: «плоские, однотонные»]
local function ceilVariant(c)
	if c.shape == "lair" then
		local v = n2(c.x, c.z, 17.3, 0.12)
		return if v > 0.3 then "px_mossy_stone_bricks" elseif v < -0.35 then "px_cobblestone" else "px_stone_bricks"
	end
	return if c.shape == "hall" then "px_stone_bricks" else "px_stone"
end

-- ================================================================ build the shell (runs merged along x)
local shell = folder("Shell")
local count = 0
local function flushRuns(iz, runs, make)
	for _, r in ipairs(runs) do
		make(r, iz)
		count += 1
	end
end
for iz = 0, NZ - 1 do
	local floorRuns, ceilRuns, wallRuns = {}, {}, {}
	local fr, cr, wr = nil, nil, nil
	for ix = 0, NX do
		local c = if ix < NX then cellAt(ix, iz) else nil
		-- floor: solid down to −20 (the pit holes stay open)
		local fk = c and not c.hole and (floorVariant(c) .. "|" .. c.floor) or nil
		if fr and fr.key ~= fk then
			table.insert(floorRuns, fr)
			fr = nil
		end
		if fk and not fr then
			fr = { key = fk, ix0 = ix, variant = floorVariant(c), top = c.floor }
		end
		if fr then
			fr.ix1 = ix
		end
		-- ceiling: a column from the dome surface up to TOP
		local ck = c and ceilVariant(c) .. "|" .. c.ceil or nil
		if cr and cr.key ~= ck then
			table.insert(ceilRuns, cr)
			cr = nil
		end
		if ck and not cr then
			cr = { key = ck, ix0 = ix, variant = ceilVariant(c), bottom = c.ceil }
		end
		if cr then
			cr.ix1 = ix
		end
		-- walls: closed cells touching an open one (8 neighbours)
		local wk = nil
		if ix < NX and not c then
			local touch = nil
			for dz = -1, 1 do
				for dx = -1, 1 do
					touch = touch or cellAt(ix + dx, iz + dz)
				end
			end
			if touch then
				wk = wallVariant(cx(ix), cz(iz), touch.shape)
			end
		end
		if wr and wr.key ~= wk then
			table.insert(wallRuns, wr)
			wr = nil
		end
		if wk and not wr then
			wr = { key = wk, ix0 = ix }
		end
		if wr then
			wr.ix1 = ix
		end
	end
	local z1, z0 = cz(iz) - C / 2, cz(iz) + C / 2
	flushRuns(iz, floorRuns, function(r)
		-- dirt and gravel turn orange under the torches: a cooler, darker tint keeps them earthy
		local tint = if r.variant == "px_dirt" or r.variant == "px_gravel" then Color3.fromRGB(180, 172, 166) else nil
		box("Floor", X0 + r.ix0 * C, -20, z1, X0 + (r.ix1 + 1) * C, r.top, z0, r.variant, tint, shell)
	end)
	flushRuns(iz, ceilRuns, function(r)
		box("Vault", X0 + r.ix0 * C, r.bottom, z1, X0 + (r.ix1 + 1) * C, TOP, z0, r.variant, CEIL_TINT, shell)
	end)
	flushRuns(iz, wallRuns, function(r)
		box("Rock", X0 + r.ix0 * C, -20, z1, X0 + (r.ix1 + 1) * C, TOP, z0, r.key, WALL_TINT, shell)
	end)
	if iz % 8 == 0 then
		task.wait()
	end
end

-- [владелец 22.10: подвал целиком внутри] the client (IndoorLighting) lifts the ambient light inside this
-- volume. A Persistent model: with streaming the client always has it.
local indoorModel = Instance.new("Model")
indoorModel.Name = "IndoorVolume"
indoorModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
indoorModel.Parent = root
local indoor = decor(part("IndoorVolume", Vector3.new(NX * C, 200, NZ * C), at(X0 + NX * C / 2, 0, ZTOP - NZ * C / 2), STONE, nil, indoorModel))
indoor.Transparency = 1
indoor:SetAttribute("Ambient", Color3.fromRGB(128, 120, 114))
indoor:SetAttribute("Exposure", 0.05)
CollectionService:AddTag(indoor, "IndoorLighting")

-- ================================================================ small builders
local props = folder("Props")
local function torch(x, y, z, nx, nz)
	-- a wall torch leaning out of the wall face (nx, nz = the direction into the room)
	local base = CFrame.lookAt(Vector3.new(BX + x, y, BZ + z), Vector3.new(BX + x + nx, y, BZ + z + nz))
	decor(part("TorchBracket", Vector3.new(0.5, 0.5, 0.8), base * CFrame.new(0, 0, -0.2), IRON, Enum.Material.Metal, props))
	local stick = decor(part("TorchStick", Vector3.new(0.4, 1.6, 0.4), base * CFrame.new(0, 0.5, -0.5) * CFrame.Angles(-0.4, 0, 0), WOOD, Enum.Material.Wood, props))
	local flame = decor(part("TorchFlame", Vector3.new(0.6, 0.6, 0.6), stick.CFrame * CFrame.new(0, 1, 0), TORCH, Enum.Material.Neon, props))
	light(flame, 20, 1.4, TORCH)
	local fire = Instance.new("Fire")
	fire.Size = 1.4
	fire.Heat = 3
	fire.Parent = flame
end
-- the wall face nearest to (x, z) in direction (dx, 0): walks cells until a closed one
local function wallFace(x, z, dx)
	local px = x
	for _ = 1, 20 do
		local nx = px + dx * C
		if not cellAtPos(nx, z) then
			local ix = math.floor((nx - X0) / C)
			local edge = X0 + ix * C + (if dx > 0 then 0 else C)
			return edge
		end
		px = nx
	end
	return nil
end
local function crate(x, y, z, size)
	size = size or 3
	return textured(part("Crate", Vector3.new(size, size, size), at(x, y + size / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), WOOD, nil, props), "px_planks")
end
local function barrel(x, y, z, broken)
	local b = part("Barrel", Vector3.new(2.8, 2.4, 2.4), at(x, y + 1.4, z) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood, props)
	b.Shape = Enum.PartType.Cylinder
	b.Color = Color3.fromRGB(105, 72, 42)
	if broken then
		b.CFrame = at(x, y + 1.2, z) * CFrame.Angles(0, rng:NextNumber(0, 6), 0) * CFrame.Angles(0, 0, 0) -- lying on its side
	end
	for _, dy in ipairs({ -0.9, 0.9 }) do
		local hoop = decor(part("Hoop", Vector3.new(0.3, 2.55, 2.55), b.CFrame * CFrame.new(dy, 0, 0), IRON, Enum.Material.Metal, props))
		hoop.Shape = Enum.PartType.Cylinder
	end
end
local function bones(x, y, z, n)
	for _ = 1, n do
		decor(part("Bone", Vector3.new(0.35, 0.35, rng:NextNumber(1.4, 2.4)), at(x + rng:NextNumber(-2.5, 2.5), y + 0.2, z + rng:NextNumber(-2.5, 2.5)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color3.fromRGB(226, 220, 198), nil, props))
	end
	if rng:NextNumber() < 0.5 then
		local skull = decor(part("Skull", Vector3.new(1.1, 1, 1.2), at(x + rng:NextNumber(-1, 1), y + 0.5, z + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color3.fromRGB(226, 220, 198), nil, props))
		for _, s in ipairs({ -0.25, 0.25 }) do
			decor(part("Eye", Vector3.new(0.3, 0.3, 0.05), skull.CFrame * CFrame.new(s, 0.1, -0.6), Color3.fromRGB(25, 22, 20), nil, props))
		end
	end
end
local function cobweb(x, y, z, yaw)
	for _, a in ipairs({ 0.6, -0.6 }) do
		local w = decor(part("Cobweb", Vector3.new(3.6, 3.6, 0.05), at(x, y, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, a), Color3.fromRGB(235, 235, 240), Enum.Material.SmoothPlastic, props))
		w.Transparency = 0.9
	end
end

-- ================================================================ the arrival hall (old prison cellar)
local hall = folder("Hall")
-- pilasters along the side walls and the back wall, ribs of the vault between them, torches on every
-- other pilaster
for _, z in ipairs({ 12, 4, -4, -12 }) do
	for _, side in ipairs({ -1, 1 }) do
		local x = side * (HALL.x1 - 0.75)
		box("Pilaster", x - 0.75, 0, z - 1.25, x + 0.75, 14, z + 1.25, "px_stone_bricks", Color3.fromRGB(215, 210, 205), hall)
		box("PilasterBase", x - 1, 0, z - 1.5, x + 1, 1, z + 1.5, "px_smooth_stone", nil, hall)
		box("PilasterCap", x - 1.1, 13.4, z - 1.6, x + 1.1, 14.2, z + 1.6, "px_smooth_stone", nil, hall)
		if z == 4 or z == -12 then
			torch(x - side * 0.9, 8, z, -side, 0)
		end
	end
	-- the rib: a stepped arch of darker bricks under the barrel vault, 1 stud below it
	for k = 0, 15 do
		local x0 = HALL.x0 + k * 2
		local xm = x0 + 1
		local ceil = hallCeil(xm)
		box("Rib", x0, ceil - 1, z - 1, x0 + 2, ceil, z + 1, "px_stone_bricks", Color3.fromRGB(160, 150, 145), hall)
	end
end
-- the barred cells (ALCOVES, carved with the grid): iron bars across the front, a straw bed, chains and
-- bones inside
local function cell(side, z)
	local wx = side * HALL.x1 -- the wall face
	local depth = 8
	-- bars: an iron frame and vertical rods at the wall face
	local bx = wx + side * 0.2
	box("BarsTop", bx - 0.2, 7.4, z - 3.5, bx + 0.2, 7.9, z + 3.5, nil, IRON, hall).Material = Enum.Material.Metal
	box("BarsMid", bx - 0.15, 3.8, z - 3.5, bx + 0.15, 4.1, z + 3.5, nil, IRON, hall).Material = Enum.Material.Metal
	for k = -3, 3 do
		local rod = part("Bar", Vector3.new(0.25, 7.4, 0.25), at(bx, 3.7, z + k * 0.95), IRON, Enum.Material.Metal, hall)
		rod.CanCollide = true
	end
	-- inside: a straw bed on planks, a chain on the back wall, a bucket, bones
	local back = wx + side * (depth - 1)
	textured(part("Bed", Vector3.new(2.2, 0.6, 5), at(back - side * 0.6, 0.6, z - 0.5), WOOD, nil, hall), "px_planks")
	textured(decor(part("Straw", Vector3.new(2, 0.4, 4.6), at(back - side * 0.6, 1.1, z - 0.5), WOOD, nil, hall)), "px_hay")
	for i = 0, 4 do
		decor(part("Chain", Vector3.new(0.25, 0.6, 0.25), at(back + side * 0.4, 6 - i * 0.55, z + 2.3) * CFrame.Angles(0, i % 2 * math.pi / 2, 0), IRON, Enum.Material.Metal, hall))
	end
	bones(wx + side * 3, 0, z + 1.5, 3)
end
for _, a in ipairs(ALCOVES) do
	cell(a[1], a[2])
end
-- the back wall: a stair up to the sealed iron door (the way the prisoners were brought down)
for i = 0, 3 do
	box("Step", -4, 0, HALL.z0 - 2 - (3 - i) * 1.5, 4, (i + 1) * 0.8, HALL.z0 - (3 - i) * 1.5 + 0.0001, "px_stone_bricks", nil, hall)
end
box("Landing", -4, 0, HALL.z0 - 2, 4, 3.2, HALL.z0, "px_stone_bricks", nil, hall)
box("DoorFrame", -3, 3.2, HALL.z0 - 0.6, 3, 10, HALL.z0, "px_smooth_stone", nil, hall)
local door = box("Door", -2.2, 3.2, HALL.z0 - 0.9, 2.2, 9.2, HALL.z0 - 0.5, nil, Color3.fromRGB(70, 66, 64), hall)
door.Material = Enum.Material.DiamondPlate
for _, y in ipairs({ 4.5, 6.2, 7.9 }) do
	box("DoorBand", -2.2, y - 0.2, HALL.z0 - 1.05, 2.2, y + 0.2, HALL.z0 - 0.85, nil, IRON, hall).Material = Enum.Material.Metal
end
box("DoorLock", 1.2, 5.6, HALL.z0 - 1.25, 1.8, 6.6, HALL.z0 - 0.9, nil, Color3.fromRGB(150, 120, 50), hall).Material = Enum.Material.Metal
local lamp = decor(part("DoorLamp", Vector3.new(1, 1.3, 1), at(0, 11.2, HALL.z0 - 1.2), TORCH, Enum.Material.Neon, hall))
light(lamp, 22, 1.2, TORCH)
local signPart = decor(part("BasementSign", Vector3.new(1, 1, 1), at(0, 18, HALL.z0 - 2), STONE, nil, hall))
signPart.Transparency = 1
sign(signPart, "Подвал", 0)
-- the portal: a brick arch framing the open side (on the hall side of the wall)
local function arch(z, half, springY, rise, variant, tint, parent)
	-- stepped semicircle of 2-stud bricks from the springing line up to the wall top, 1.5 studs deep
	for k = 0, half - 1 do
		local xL = -half + k * 2
		local xm = xL + 1
		local top = springY + rise * math.sqrt(math.max(0, 1 - (xm / half) ^ 2))
		local y0 = 2 * math.floor(top / 2 + 0.5)
		box("Arch", xL, y0, z - 0.75, xL + 2, y0 + 2.5, z + 0.75, variant, tint, parent)
	end
	box("Keystone", -1, springY + rise - 0.5, z - 0.9, 1, springY + rise + 2.5, z + 0.9, "px_smooth_stone", nil, parent)
	for _, side in ipairs({ -1, 1 }) do
		box("ArchPier", side * half - (if side > 0 then 0 else 1.5), 0, z - 1, side * half + (if side > 0 then 1.5 else 0), springY + 1, z + 1, variant, tint, parent)
	end
end
arch(HALL.z1 + 0.75, PORTAL, 8, 6, "px_stone_bricks", Color3.fromRGB(205, 198, 192), hall)
-- arrival point, a worn rug, crates and barrels, a table with a candle, cobwebs in the upper corners
local spawnPart = part("LocationSpawn_basement", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX, 0.5, BZ + 6), Vector3.new(BX, 0.5, BZ - 100)), STONE, nil, hall)
textured(spawnPart, "px_smooth_stone")
spawnPart:SetAttribute("LocationId", "basement")
CollectionService:AddTag(spawnPart, "LocationSpawn")
local rug = part("Rug", Vector3.new(7, 0.12, 10), at(0, 0.06, 2), Color3.fromRGB(110, 40, 35), Enum.Material.Fabric, hall)
rug.CanCollide = false
decor(part("RugBorder", Vector3.new(7.6, 0.1, 10.6), at(0, 0.05, 2), Color3.fromRGB(150, 110, 50), Enum.Material.Fabric, hall))
crate(13.5, 0, 13.5)
crate(10.5, 0, 13.8, 2.4)
crate(13.4, 3, 13.3, 2.2)
barrel(13.6, 0, -1)
barrel(-13.6, 0, 13.6)
barrel(-10.8, 0, 13.6, true)
textured(part("Table", Vector3.new(4, 0.4, 2.6), at(11, 2.6, 0), WOOD, nil, hall), "px_spruce_planks")
for _, d in ipairs({ { -1.7, -1.1 }, { 1.7, -1.1 }, { -1.7, 1.1 }, { 1.7, 1.1 } }) do
	part("TableLeg", Vector3.new(0.4, 2.4, 0.4), at(11 + d[1], 1.2, d[2]), WOOD, Enum.Material.Wood, hall)
end
decor(part("Candle", Vector3.new(0.4, 0.8, 0.4), at(11.5, 3.2, 0.3), Color3.fromRGB(240, 230, 200), nil, hall))
local candle = decor(part("CandleFlame", Vector3.new(0.25, 0.4, 0.25), at(11.5, 3.8, 0.3), TORCH, Enum.Material.Neon, hall))
light(candle, 10, 0.8, TORCH)
for _, c in ipairs({ { -15, 15, 0.8 }, { 15, 15, -0.8 }, { -15, -15, -0.8 }, { 15, -15, 0.8 } }) do
	cobweb(c[1], 13, c[2], c[3])
end

-- block buyers (SellPoint on the rig's root, like scripts/build-quarry.luau): in the hall and in cave 2
local npcs = folder("Npcs")
local function npc(name, tag, cf, label, labelColor, skin, shirt, pants)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = shirt, pants, pants
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
		end
	end
	model.Parent = npcs
	model:PivotTo(cf)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = model:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, tag)
	sign(hrp, label, 4.5, labelColor)
	return model
end
local function buyer(name, x, y, z, faceX, faceZ)
	npc(
		name,
		"SellPoint",
		CFrame.lookAt(Vector3.new(BX + x, y + 3, BZ + z), Vector3.new(BX + faceX, y + 3, BZ + faceZ)),
		"Скупщик блоков",
		Color3.fromRGB(255, 55, 55),
		Color3.fromRGB(198, 140, 100),
		Color3.fromRGB(70, 70, 80),
		Color3.fromRGB(50, 45, 40)
	)
	local dx, dz = faceX - x, faceZ - z
	local len = math.sqrt(dx * dx + dz * dz)
	dx, dz = dx / len, dz / len
	local counter = part("Counter", Vector3.new(7, 3, 2.2), CFrame.lookAt(Vector3.new(BX + x + dx * 2.6, y + 1.5, BZ + z + dz * 2.6), Vector3.new(BX + x + dx * 10, y + 1.5, BZ + z + dz * 10)), WOOD, nil, props)
	textured(counter, "px_spruce_planks")
	local lantern = decor(part("CounterLamp", Vector3.new(0.8, 1, 0.8), counter.CFrame * CFrame.new(2.6, 2, 0), TORCH, Enum.Material.Neon, props))
	light(lantern, 14, 1, TORCH)
end
-- the hall buyer stands at the west wall between the two cells
buyer("BasementBuyer", -13.5, 0, 0, 0, 0)

-- ================================================================ the mines
local function pit(m, id, label)
	local w, h = m.w, m.depth * B
	local mz = m.cz
	local function bedrock(p)
		textured(p, "px_cobblestone", BEDROCK)
	end
	bedrock(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(0, -h - B / 2, mz), DARK))
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(0, -h / 2, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(0, -h / 2, mz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(-w / 2 - B, -h / 2, mz) },
		{ Vector3.new(2 * B, h, w), at(w / 2 + B, -h / 2, mz) },
	}) do
		bedrock(part("PitWall", wall[1], wall[2], STONE))
	end
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 1, 2 * B), at(0, 0, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 1, 2 * B), at(0, 0, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 1, w), at(-w / 2 - B, 0, mz) },
		{ Vector3.new(2 * B, 1, w), at(w / 2 + B, 0, mz) },
	}) do
		bedrock(part("PitRim", r[1], r[2], STONE))
	end
	-- a log fence round the pit: posts every 8 studs, two rails, gaps where the trail meets it (south, north)
	local edge = w / 2 + 2 * B
	local function post(x, z)
		textured(part("FencePost", Vector3.new(0.8, 3.4, 0.8), at(x, 1.7, z), WOOD, nil, props), "px_oak_log")
	end
	for _, sz in ipairs({ -1, 1 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local len = edge - 6
			textured(part("FenceRail", Vector3.new(len, 0.4, 0.3), at(sx * (6 + len / 2), 2.6, mz + sz * edge), WOOD, nil, props), "px_planks")
			textured(part("FenceRail", Vector3.new(len, 0.4, 0.3), at(sx * (6 + len / 2), 1.4, mz + sz * edge), WOOD, nil, props), "px_planks")
			for x = 6, edge, 8 do
				post(sx * x, mz + sz * edge)
			end
		end
		textured(part("FenceRail", Vector3.new(0.3, 0.4, 2 * edge), at(sz * edge, 2.6, mz), WOOD, nil, props), "px_planks")
		textured(part("FenceRail", Vector3.new(0.3, 0.4, 2 * edge), at(sz * edge, 1.4, mz), WOOD, nil, props), "px_planks")
		for z = -edge, edge, 8 do
			post(sz * edge, mz + z)
		end
	end
	local anchor = part("MineAnchor_" .. id, Vector3.new(w, 0.2, w), at(0, -0.1, mz), DARK)
	anchor:SetAttribute("LocationId", "basement")
	anchor:SetAttribute("MineId", id)
	anchor:SetAttribute("Size", Vector3.new(m.size, m.depth, m.size))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, label, 8)
	-- four ladders like the quarry (invisible 2×2 trusses + a textured plate each)
	local LADDER_W = 4 * B
	local ladderTexture = textures and textures.textures and textures.textures.ladder
	for _, side in ipairs({
		{ 0, mz - w / 2, Vector3.new(0, 0, 1) },
		{ 0, mz + w / 2, Vector3.new(0, 0, -1) },
		{ -w / 2, mz, Vector3.new(1, 0, 0) },
		{ w / 2, mz, Vector3.new(-1, 0, 0) },
	}) do
		local inward = side[3]
		local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
		local base = Vector3.new(BX + side[1], -h / 2, BZ + side[2])
		for k = 0, LADDER_W / 2 - 1 do
			local truss = Instance.new("TrussPart")
			truss.Name = "Ladder"
			truss.Size = Vector3.new(2, h, 2)
			truss.CFrame = CFrame.new(base - inward * 0.6 + along * (-LADDER_W / 2 + 1 + k * 2))
			truss.Anchored = true
			truss.Transparency = 1
			truss.Parent = root
		end
		local plate = Instance.new("Part")
		plate.Name = "LadderFace"
		plate.Size = Vector3.new(LADDER_W * along.X + 0.2 * math.abs(inward.X), h, LADDER_W * along.Z + 0.2 * math.abs(inward.Z))
		plate.CFrame = CFrame.new(base + inward * 0.15)
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.Transparency = 1
		plate.Parent = root
		if ladderTexture then
			local tex = Instance.new("Texture")
			tex.Texture = ladderTexture
			tex.Face = if inward.Z > 0
				then Enum.NormalId.Back
				elseif inward.Z < 0 then Enum.NormalId.Front
				elseif inward.X > 0 then Enum.NormalId.Right
				else Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end
	-- lanterns on chains from the dome over the pit corners (the warm light of the cave)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = c[1] * (edge + 2), mz + c[2] * (edge + 2)
		local cl = cellAtPos(x, z)
		local ceil = if cl then cl.ceil else 20
		local drop = math.max(3, ceil - 12)
		decor(part("Chain", Vector3.new(0.2, drop, 0.2), at(x, ceil - drop / 2, z), IRON, Enum.Material.Metal, props))
		local lantern = decor(part("Lantern", Vector3.new(1.3, 1.6, 1.3), at(x, ceil - drop - 0.8, z), TORCH, Enum.Material.Neon, props))
		decor(part("LanternCap", Vector3.new(1.7, 0.4, 1.7), at(x, ceil - drop, z), IRON, Enum.Material.Metal, props))
		light(lantern, 30, 1.25, TORCH)
	end
end
pit(M1, "basement", "Шахта")
pit(M2, "basement_ore", "Рудная шахта")
buyer("BasementOreBuyer", M2.hole + 9, 0, M2.cz, 0, M2.cz)
-- a cart of ore and piles by the ore mine; rubble by mine 1
local function pile(x, z, variants, n)
	local y0 = (cellAtPos(x, z) or { floor = 0 }).floor
	for i = 1, n do
		local s = rng:NextNumber(1.2, 2.2)
		local p = part("Pile", Vector3.new(s, s, s), at(x + rng:NextNumber(-2.2, 2.2), y0 + s / 2 + (if i > n * 0.6 then 1.1 else 0), z + rng:NextNumber(-2.2, 2.2)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), 0), STONE, nil, props)
		textured(p, variants[rng:NextInteger(1, #variants)])
	end
end
pile(-M2.hole - 10, M2.cz - 12, { "px_gold_block", "px_iron_block", "px_lapis_block", "px_cobblestone" }, 9)
pile(-M1.hole - 10, M1.cz + 14, { "px_gravel", "px_dirt", "px_cobblestone" }, 9)
pile(M1.hole + 12, M1.cz - 16, { "px_sand", "px_gravel" }, 7)
local function minecart(x, z, yaw, load)
	local base = CFrame.new(BX + x, 0, BZ + z) * CFrame.Angles(0, yaw, 0)
	part("Minecart", Vector3.new(3, 0.6, 4), base * CFrame.new(0, 0.9, 0), IRON, Enum.Material.Metal, props)
	for _, d in ipairs({ { 0, 1.85, 3, 0.3 }, { 0, -1.85, 3, 0.3 }, { 1.35, 0, 0.3, 4 }, { -1.35, 0, 0.3, 4 } }) do
		decor(part("CartSide", Vector3.new(d[3], 1.6, d[4]), base * CFrame.new(d[1], 2, d[2]), IRON, Enum.Material.Metal, props))
	end
	textured(decor(part("CartLoad", Vector3.new(2.4, 0.8, 3.4), base * CFrame.new(0, 2.4, 0), STONE, nil, props)), load)
	for _, wx in ipairs({ -1.5, 1.5 }) do
		for _, wz in ipairs({ -1.3, 1.3 }) do
			local wheel = decor(part("Wheel", Vector3.new(0.3, 1, 1), base * CFrame.new(wx, 0.5, wz), DARK, Enum.Material.Metal, props))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end
minecart(-M2.hole - 14, M2.cz + 10, 0.3, "px_gold_block")
minecart(M1.hole + 13, M1.cz + 14, -0.2, "px_gravel")

-- ================================================================ the lair of Сплинтер: the round hall of an abandoned castle
-- [владелец 22.10: «зал в древнем заброшенном замке, статуи»; «зал круглым, окна убери, статуи во весь рост зала,
-- потолок купольный, больше средневековых декораций»]. A stepped stone dome on 16 ribs rising from wall pilasters to
-- a ring at the top, a great chandelier hanging from it over the arena; eight giant knight statues round the wall,
-- almost as tall as the hall, facing the middle (one headless, one without an arm); between them banners, shields
-- with arms and crossed swords on the wall, suits of armour on stands; a feast table with benches, goblets and
-- plates (west), an armoury with an anvil, a grindstone and weapon racks (east); the throne of the dead king under a
-- torn tapestry (north), treasure chests by its steps; stone lions inside the great door (south); braziers and candle
-- stands round the arena; the torn carpet; a crashed chandelier; the caved-in north-east. Сплинтер made it his lair:
-- the round dais, a nest of straw and bones, heaps of rubbish [меню: «горы мусора»].
local lairF = folder("Lair")
local LF = LAIR.floor
local PLATFORM_R = 32 -- the arena dais, ×2 with the lair
local STATUE = Color3.fromRGB(196, 194, 188)
local MOSSY = Color3.fromRGB(150, 168, 128)
local GOLD = Color3.fromRGB(200, 160, 60)
local CLOTH = Color3.fromRGB(120, 28, 30)
local STEEL = Color3.fromRGB(150, 152, 158)
local function lairAt(x, y, z)
	return at(x, LF + y, z)
end
local function stoneTint()
	return if rng:NextNumber() < 0.2 then MOSSY else STATUE
end
-- a point round the hall: θ from the door (south, +z) clockwise towards the east (+x), r from the centre
local function polar(theta, r)
	return math.sin(theta) * r, LAIR.cz + math.cos(theta) * r
end
-- a frame at a point round the hall looking at the centre (−Z of the frame faces the middle)
local function facing(theta, r, y)
	local x, z = polar(theta, r)
	return CFrame.lookAt(Vector3.new(BX + x, LF + (y or 0), BZ + z), Vector3.new(BX + LAIR.cx, LF + (y or 0), BZ + LAIR.cz))
end
local function ruinedCorner(x, z)
	return x > 44 and z < LAIR.z1 + 44
end

-- the dais (the arena): a ring of bricks, a smooth disc, an inlaid gold star, claw scratches
local dais = part("LairDais", Vector3.new(1.4, 2 * PLATFORM_R, 2 * PLATFORM_R), lairAt(0, 0.7, LAIR.cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, lairF)
dais.Shape = Enum.PartType.Cylinder
textured(dais, "px_stone_bricks")
local daisTop = part("LairDaisTop", Vector3.new(1.7, 2 * (PLATFORM_R - 3), 2 * (PLATFORM_R - 3)), lairAt(0, 0.85, LAIR.cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, lairF)
daisTop.Shape = Enum.PartType.Cylinder
textured(daisTop, "px_smooth_stone")
for i = 0, 7 do
	local a = i / 8 * math.pi * 2
	decor(part("Inlay", Vector3.new(1.2, 0.06, PLATFORM_R - 8), CFrame.new(BX, LF + 1.72, BZ + LAIR.cz) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(PLATFORM_R - 8) / 2), GOLD, Enum.Material.Metal, lairF))
end
for i = 0, 5 do
	local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	for k = -1, 1 do
		decor(part("Scratch", Vector3.new(0.25, 0.08, 9), CFrame.new(BX, LF + 1.74, BZ + LAIR.cz) * CFrame.Angles(0, a + 0.3, 0) * CFrame.new(k * 0.6, 0, -16), Color3.fromRGB(45, 42, 40), nil, lairF))
	end
end
-- the nest: a broken ring of straw, planks and bones round the dais edge
for i = 0, 55 do
	local a = i / 56 * math.pi * 2
	if math.sin(a) < 0.9 then -- open towards the door (south)
		local r = PLATFORM_R + rng:NextNumber(0.5, 2.5)
		local s = rng:NextNumber(1.6, 2.8)
		local p = part("Nest", Vector3.new(s, s * 0.6, s * 1.4), lairAt(math.cos(a) * r, s * 0.3, LAIR.cz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), -a + rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3)), WOOD, nil, lairF)
		textured(p, ({ "px_hay", "px_hay", "px_planks", "px_spruce_planks", "px_dirt" })[rng:NextInteger(1, 5)])
		if i % 4 == 0 then
			bones(math.cos(a) * (r + 2), LF, LAIR.cz + math.sin(a) * (r + 2), 2)
		end
	end
end
-- heaps of rubbish: mounds of blocks, planks, bones [меню: «горы мусора»]
local function heap(x, z, size)
	for _ = 1, 40 do
		local s = rng:NextNumber(1.4, 3.4)
		local r = rng:NextNumber(0, size)
		local a = rng:NextNumber(0, 6.28)
		local y = s / 2 + math.max(0, size - r) * 0.8
		local p = part("Rubbish", Vector3.new(s, s * rng:NextNumber(0.5, 1), s), lairAt(x + math.cos(a) * r, y, z + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)), STONE, nil, lairF)
		textured(p, ({ "px_dirt", "px_gravel", "px_planks", "px_cobblestone", "px_mossy_cobblestone", "px_spruce_planks", "px_hay" })[rng:NextInteger(1, 7)])
	end
	bones(x, LF + 0.5, z, 5)
	barrel(x + rng:NextNumber(-3, 3), LF + size * 0.4, z + rng:NextNumber(-3, 3), true)
end
for _, th in ipairs({ 45, 135, 225, 315 }) do
	local x, z = polar(math.rad(th), 56)
	heap(x, z, 6)
end

-- ---------------------------------------------------------------- the wall: depth and weathering
-- [владелец 22.10: «стены плоские, однотонные — добавь глубины»] Builders' rules for a wall that reads (the
-- usual Minecraft advice: layers at different depths, ledges and corbels, a material gradient, mixed blocks):
-- the round wall is dressed in courses of separate blocks, each pushed in or out a little; a protruding plinth of
-- dark mossy cobble at the foot, stone brick courses getting cleaner and lighter towards the top, a string course
-- ledge on corbels at mid height, recessed panels with darker backs between the pilasters, a two-step cornice on
-- corbels under the dome; stepped pilasters (base, shaft, capital) carry the ribs; iron sconces light the relief.
local WALL_R = LAIR.r - 0.6 -- the dressing's face line (the rock behind it is the carved grid)
local SEG = 120
local DARK_T, MID_T, LIGHT_T = Color3.fromRGB(140, 136, 130), Color3.fromRGB(190, 186, 180), Color3.fromRGB(222, 218, 210)
local function gradient(y)
	local t = math.clamp(y / 36, 0, 1)
	local base = if t < 0.5 then DARK_T:Lerp(MID_T, t * 2) else MID_T:Lerp(LIGHT_T, (t - 0.5) * 2)
	local k = rng:NextNumber(0.92, 1.06)
	return Color3.new(math.min(1, base.R * k), math.min(1, base.G * k), math.min(1, base.B * k))
end
local function wallBlock(name, th, y0, y1, depth, inset, variant, tint, width)
	local w = width or (2 * math.pi * WALL_R / SEG + 0.12)
	local cf = facing(th, WALL_R - inset - depth / 2, (y0 + y1) / 2)
	return textured(part(name, Vector3.new(w, y1 - y0, depth), cf, STONE, nil, lairF), variant, tint)
end
-- pilaster angles (16, between the statues) and the angular distance of a segment to the nearest one, in segments
local PIL = {}
for k = 0, 15 do
	PIL[k + 1] = (k + 0.5) / 16 * math.pi * 2
end
local function pilasterDist(th)
	local best = math.huge
	for _, p in ipairs(PIL) do
		local d = math.abs((th - p + math.pi) % (2 * math.pi) - math.pi)
		best = math.min(best, d)
	end
	return best / (2 * math.pi / SEG)
end
local DOOR_TH = math.asin((LAIR.door + 1) / LAIR.r)
for i = 0, SEG - 1 do
	local th = (i + 0.5) / SEG * math.pi * 2
	local x, z = polar(th, WALL_R)
	local doorGap = math.abs((th + math.pi) % (2 * math.pi) - math.pi) < DOOR_TH
	local ruined = ruinedCorner(x, z)
	if not doorGap then
		local function keep()
			return not ruined or rng:NextNumber() < 0.45 -- the fallen corner: half the dressing is gone
		end
		-- the plinth: dark mossy cobble, protruding 2.4, with a chamfer course on top
		if keep() then
			wallBlock("Plinth", th, 0, 3, 2.4, 0, if rng:NextNumber() < 0.5 then "px_mossy_cobblestone" else "px_cobblestone", gradient(0))
			wallBlock("PlinthCap", th, 3, 3.6, 1.6, 0, "px_smooth_stone", gradient(3))
		end
		-- the lower courses (3.6 → 16): bricks, moss thinning out upwards, a block now and then sticking out
		local y = 3.6
		while y < 15.9 do
			local h = math.min(4, 16 - y)
			if keep() then
				local mossy = rng:NextNumber() < 0.45 - y * 0.02
				local v = if mossy then "px_mossy_stone_bricks" elseif rng:NextNumber() < 0.1 then "px_cobblestone" else "px_stone_bricks"
				wallBlock("Course", th, y, y + h, 1.2 + rng:NextNumber(-0.25, 0.35), 0, v, gradient(y))
			end
			y += h
		end
		-- the string course: a smooth ledge on corbels
		if keep() then
			wallBlock("StringCourse", th, 16, 17.4, 2.2, 0, "px_smooth_stone", gradient(16))
			if i % 2 == 0 then
				wallBlock("Corbel", th, 14.6, 16, 1.8, 0, "px_stone_bricks", gradient(15), 1.4)
			end
		end
		-- the upper courses (17.4 → 33.4): a recessed panel with a darker back in every bay, the frame stands out
		local inBay = pilasterDist(th) > 2.2
		y = 17.4
		while y < 33.3 do
			local h = math.min(4, 33.4 - y)
			if keep() then
				local panel = inBay and y > 18 and y < 31
				local v = if rng:NextNumber() < 0.12 then "px_mossy_stone_bricks" elseif rng:NextNumber() < 0.12 then "px_smooth_stone" else "px_stone_bricks"
				local tint = gradient(y)
				if panel then
					tint = tint:Lerp(Color3.fromRGB(95, 90, 86), 0.35) -- the panel's back lies in shadow
				end
				wallBlock("Course", th, y, y + h, if panel then 0.6 else 1.4 + rng:NextNumber(-0.2, 0.3), 0, v, tint)
			end
			y += h
		end
		-- the cornice under the dome: two stepped courses on corbels
		if keep() then
			wallBlock("CorniceLow", th, 33.4, 35, 2.2, 0, "px_smooth_stone", gradient(34))
			wallBlock("CorniceHigh", th, 35, 37, 3.4, 0, "px_stone_bricks", gradient(36))
			if i % 2 == 1 then
				wallBlock("CorniceCorbel", th, 31.8, 33.4, 1.8, 0, "px_smooth_stone", gradient(33), 1.2)
			end
		end
	end
end
-- stepped pilasters between the bays: a wide base, a protruding shaft with a darker edge band, a capital under the
-- cornice; an iron sconce with a flame on every other one
for k, th in ipairs(PIL) do
	if math.abs(math.cos(th)) < 0.995 then -- not across the door
		local function pil(name, w, d, y0, y1, variant, tint)
			return textured(part(name, Vector3.new(w, y1 - y0, d), facing(th, WALL_R - d / 2, (y0 + y1) / 2), STONE, nil, lairF), variant, tint)
		end
		pil("PilasterBase", 6, 4.2, 0, 3.6, "px_smooth_stone", gradient(1))
		pil("PilasterBase2", 5, 3.6, 3.6, 5, "px_stone_bricks", gradient(4))
		pil("PilasterShaft", 3.6, 3, 5, 33.4, "px_stone_bricks", gradient(18))
		pil("PilasterEdge", 4.4, 2.2, 5, 33.4, "px_stone_bricks", gradient(14):Lerp(DARK_T, 0.4))
		pil("PilasterCapital", 5, 3.8, 31, 33.4, "px_smooth_stone", gradient(32))
		if k % 2 == 0 then
			local cf = facing(th, WALL_R - 3.4, 0)
			local pos = Vector3.new(cf.Position.X, LF + 12, cf.Position.Z)
			part("SconceArm", Vector3.new(0.4, 0.4, 1.4), CFrame.new(pos) * cf.Rotation * CFrame.new(0, 0, -0.5), IRON, Enum.Material.Metal, lairF)
			part("SconceCup", Vector3.new(1.2, 0.8, 1.2), CFrame.new(pos) * cf.Rotation * CFrame.new(0, 0.3, -1.2), IRON, Enum.Material.Metal, lairF)
			local flame = decor(part("SconceFlame", Vector3.new(0.7, 0.7, 0.7), CFrame.new(pos) * cf.Rotation * CFrame.new(0, 1, -1.2), TORCH, Enum.Material.Neon, lairF))
			light(flame, 22, 1.2, TORCH)
			local fire = Instance.new("Fire")
			fire.Size = 1.6
			fire.Heat = 4
			fire.Parent = flame
		end
	end
end

-- ---------------------------------------------------------------- the dome: 16 ribs, the crown ring
local RIBS = 16
for k = 0, RIBS - 1 do
	local th = (k + 0.5) / RIBS * math.pi * 2
	-- the rib: blocks stepping up the dome along the radius, 1.5 below its surface
	for r = LAIR.r - 3, 9, -3 do
		local y = domeCeil(r) - 1.6
		local x, z = polar(th, r)
		textured(part("Rib", Vector3.new(2, 1.6, 3.4), CFrame.lookAt(Vector3.new(BX + x, y, BZ + z), Vector3.new(BX, y, BZ + LAIR.cz)), STONE, nil, lairF), "px_stone_bricks", Color3.fromRGB(165, 158, 150))
	end
	-- an iron chain hanging from every other rib
	if k % 2 == 0 then
		local x, z = polar(th, 62)
		local top = domeCeil(62)
		local len = rng:NextNumber(8, 16)
		for i = 0, math.floor(len / 0.7) do
			decor(part("Chain", Vector3.new(0.3, 0.8, 0.3), at(x, top - 2 - i * 0.7, z) * CFrame.Angles(0, i % 2 * math.pi / 2, 0), IRON, Enum.Material.Metal, lairF))
		end
	end
end
-- the crown ring at the top of the dome and the great chandelier hanging from it over the arena
for k = 0, 15 do
	local a = k / 16 * math.pi * 2
	local y = domeCeil(7) - 2
	textured(part("DomeRing", Vector3.new(3.4, 2.4, 2.4), CFrame.new(BX + LAIR.cx, y, BZ + LAIR.cz) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -7), STONE, nil, lairF), "px_smooth_stone", STATUE)
end
textured(part("DomeBoss", Vector3.new(5, 2, 5), at(LAIR.cx, domeCeil(0) - 1, LAIR.cz), STONE, nil, lairF), "px_gold_block")

-- ---------------------------------------------------------------- statues
-- a knight in plate holding a sword point-down, on a moulded pedestal; base = the frame on the floor (−Z forward).
-- [владелец 22.10: «добавь глубины, также со статуями»] Built of layered plates (sabatons, greaves, knee cops,
-- cuisses, a two-tier mail skirt, belt and buckle, plackart, breastplate with a ridge, gorget, three-plate
-- pauldrons, elbow cops, gauntlets, a great helm with a brow and slits, a plume), the cape in folds; shaded like
-- weathered stone: darker and mossier low down, lighter high up, every plate a slightly different tone.
local STATUE_DARK, STATUE_LIGHT = Color3.fromRGB(128, 125, 119), Color3.fromRGB(218, 215, 208)
local function knight(base, scale, damage)
	local function shade(y)
		local t = math.clamp(y / 10, 0, 1)
		local c = STATUE_DARK:Lerp(STATUE_LIGHT, t ^ 0.8)
		if rng:NextNumber() < 0.16 - t * 0.1 then
			c = c:Lerp(MOSSY, 0.6)
		end
		local k = rng:NextNumber(0.93, 1.05)
		return Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
	end
	local function piece(name, size, offset, angles, variant)
		local cf = base * CFrame.new(offset[1] * scale, offset[2] * scale, offset[3] * scale)
		if angles then
			cf *= CFrame.Angles(angles[1], angles[2], angles[3])
		end
		return textured(part(name, size * scale, cf, STONE, nil, lairF), variant or "px_smooth_stone", shade(offset[2]))
	end
	local function dark(p)
		p.MaterialVariant = ""
		p.Material = Enum.Material.SmoothPlastic
		p.Color = Color3.fromRGB(32, 30, 28)
		return p
	end
	-- the pedestal: a dark foot, a body with a sunken plaque, a moulded cornice, the plinth
	piece("PedestalFoot", Vector3.new(5.4, 0.6, 5.4), { 0, 0.3, 0 }, nil, "px_stone_bricks")
	piece("Pedestal", Vector3.new(4.4, 1.7, 4.4), { 0, 1.45, 0 }, nil, "px_stone_bricks")
	piece("PedestalPlaque", Vector3.new(2.6, 0.9, 0.1), { 0, 1.45, -2.22 }).Color = Color3.fromRGB(110, 106, 100)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			piece("PedestalCorner", Vector3.new(0.7, 1.7, 0.7), { sx * 2.1, 1.45, sz * 2.1 })
		end
	end
	piece("PedestalCornice", Vector3.new(5, 0.4, 5), { 0, 2.5, 0 })
	piece("Plinth", Vector3.new(3.8, 0.4, 3.8), { 0, 2.9, 0 })
	local y0 = 3.1 -- the figure stands here
	local function f(name, size, offset, angles)
		return piece(name, size, { offset[1], offset[2] + y0 - 2, offset[3] }, angles)
	end
	-- legs
	for _, sx in ipairs({ -0.52, 0.52 }) do
		f("Sabaton", Vector3.new(1, 0.5, 1.5), { sx, 2.25, -0.2 })
		f("Greave", Vector3.new(0.95, 1.5, 1.05), { sx, 3.2, 0 })
		f("KneeCop", Vector3.new(0.8, 0.5, 0.45), { sx, 3.95, -0.55 })
		f("Cuisse", Vector3.new(1.02, 1.1, 1.12), { sx, 4.5, 0 })
	end
	-- waist: two tiers of mail, the belt and its buckle, a stone tabard hanging in front
	f("MailLow", Vector3.new(2.7, 0.6, 1.55), { 0, 5.05, 0 })
	f("MailHigh", Vector3.new(2.5, 0.5, 1.45), { 0, 5.55, 0 })
	f("Belt", Vector3.new(2.45, 0.32, 1.42), { 0, 5.9, 0 })
	f("Buckle", Vector3.new(0.45, 0.35, 0.12), { 0, 5.9, -0.76 })
	f("Tabard", Vector3.new(1.1, 1.9, 0.14), { 0, 4.8, -0.84 })
	-- torso: the core, the plackart, the breastplate with its ridge, the gorget
	f("Torso", Vector3.new(2.3, 2.3, 1.3), { 0, 7.1, 0 })
	f("Plackart", Vector3.new(1.9, 0.8, 0.26), { 0, 6.45, -0.72 })
	f("Breastplate", Vector3.new(2.05, 1.3, 0.3), { 0, 7.5, -0.74 })
	f("Ridge", Vector3.new(0.26, 1.3, 0.16), { 0, 7.5, -0.95 })
	f("Gorget", Vector3.new(1.35, 0.42, 1.05), { 0, 8.45, 0 })
	-- the cape in three folds at different depths
	for k = -1, 1 do
		f("CapeFold", Vector3.new(0.86, 5.2 + k * 0.15, 0.24), { k * 0.84, 5.8, 0.8 + math.abs(k) * 0.08 }, { -0.07, 0, 0 })
	end
	-- arms: three-plate pauldrons, upper arms, elbow cops, forearms reaching to the hands on the sword
	local function arm(sx)
		f("Pauldron", Vector3.new(1.3, 0.45, 1.6), { sx * 1.45, 8.2, 0 })
		f("Pauldron", Vector3.new(1.22, 0.4, 1.5), { sx * 1.52, 7.85, 0 })
		f("Pauldron", Vector3.new(1.12, 0.35, 1.4), { sx * 1.58, 7.52, 0 })
		f("UpperArm", Vector3.new(0.8, 1.3, 0.9), { sx * 1.45, 6.95, -0.1 })
		f("ElbowCop", Vector3.new(0.62, 0.55, 0.62), { sx * 1.42, 6.25, -0.35 })
		f("Forearm", Vector3.new(0.72, 0.62, 1.7), { sx * 0.76, 5.95, -0.72 }, { 0, sx * -0.75, 0 })
	end
	arm(-1)
	if damage ~= "armless" then
		arm(1)
	else
		f("Pauldron", Vector3.new(1.3, 0.45, 1.6), { 1.45, 8.2, 0 })
		f("Stump", Vector3.new(0.8, 0.5, 0.9), { 1.45, 7.4, -0.1 })
		piece("FallenArm", Vector3.new(0.8, 2.4, 0.9), { 2.8, 0.45, -3 }, { 0, 0.4, math.pi / 2 })
	end
	f("Gauntlets", Vector3.new(1.15, 0.85, 0.9), { 0, 5.85, -1.25 })
	-- the sword, point down: blade, fuller, guard with quillon blocks, pommel
	f("Blade", Vector3.new(0.34, 3.5, 0.15), { 0, 3.95, -1.3 })
	dark(f("Fuller", Vector3.new(0.1, 3, 0.17), { 0, 4.05, -1.3 }))
	f("Guard", Vector3.new(2, 0.26, 0.34), { 0, 5.55, -1.3 })
	for _, sx in ipairs({ -1, 1 }) do
		f("Quillon", Vector3.new(0.36, 0.42, 0.42), { sx * 1.05, 5.62, -1.3 })
	end
	f("Pommel", Vector3.new(0.48, 0.48, 0.48), { 0, 6.45, -1.3 })
	-- the great helm with a brow band, eye slits, breaths and a plume sweeping back
	if damage ~= "headless" then
		f("Helm", Vector3.new(1.3, 1.45, 1.3), { 0, 9.15, 0 })
		f("HelmTop", Vector3.new(1.1, 0.25, 1.1), { 0, 9.98, 0 })
		f("Brow", Vector3.new(1.36, 0.22, 0.22), { 0, 9.35, -0.6 })
		f("Nasal", Vector3.new(0.18, 0.7, 0.12), { 0, 8.95, -0.68 })
		for _, sx in ipairs({ -0.33, 0.33 }) do
			dark(f("EyeSlit", Vector3.new(0.36, 0.1, 0.06), { sx, 9.15, -0.66 }))
			for k = 0, 1 do
				dark(f("Breath", Vector3.new(0.08, 0.08, 0.06), { sx, 8.7 - k * 0.18, -0.66 }))
			end
		end
		f("Plume", Vector3.new(0.26, 0.55, 0.5), { 0, 10.3, -0.1 })
		f("Plume", Vector3.new(0.26, 0.5, 0.5), { 0, 10.4, 0.35 })
		f("Plume", Vector3.new(0.24, 0.45, 0.5), { 0, 10.2, 0.78 }, { 0.4, 0, 0 })
	else
		f("Neck", Vector3.new(0.7, 0.3, 0.7), { 0, 8.75, 0 })
		piece("FallenHelm", Vector3.new(1.3, 1.45, 1.3), { 1.6, 0.65, -3.4 }, { 0.3, 0.8, 1.2 })
	end
end
-- eight giant knights round the wall, almost as tall as the hall, facing the middle (θ = 22.5° + 45° k: two flank
-- the door, two flank the throne)
local GIANT = 3.9
for k = 0, 7 do
	local th = math.rad(22.5 + 45 * k)
	local dmg = if k == 2 then "headless" elseif k == 5 then "armless" else nil
	knight(facing(th, LAIR.r - 14, 0), GIANT, dmg)
end
-- a stone lion lying on a pedestal
local function lion(base)
	local function piece(name, size, offset)
		return textured(part(name, size, base * CFrame.new(offset[1], offset[2], offset[3]), STONE, nil, lairF), "px_smooth_stone", stoneTint())
	end
	piece("LionPedestal", Vector3.new(4, 2, 7), { 0, 1, 0 })
	piece("LionBody", Vector3.new(2.6, 2.2, 4.6), { 0, 3.1, 0.4 })
	piece("LionHaunch", Vector3.new(3, 2.4, 1.8), { 0, 3.2, 2 })
	piece("LionMane", Vector3.new(3.2, 3, 1.6), { 0, 4.6, -1.9 })
	piece("LionHead", Vector3.new(2.2, 2.2, 1.6), { 0, 4.8, -2.8 })
	piece("LionMuzzle", Vector3.new(1.3, 0.9, 0.8), { 0, 4.3, -3.8 })
	for _, sx in ipairs({ -0.75, 0.75 }) do
		piece("LionPaw", Vector3.new(0.9, 0.7, 2), { sx, 2.35, -2.9 })
		piece("LionEar", Vector3.new(0.5, 0.5, 0.4), { sx, 6, -2.7 })
	end
	piece("LionTail", Vector3.new(0.4, 0.4, 2.6), { 1.3, 2.4, 2.9 })
end
-- the lions guard the door from inside, facing whoever comes in
for _, sx in ipairs({ -1, 1 }) do
	lion(CFrame.lookAt(Vector3.new(BX + sx * 13, LF, BZ + LAIR.z0 - 22), Vector3.new(BX + sx * 13, LF, BZ + LAIR.z0 + 10)))
end

-- ---------------------------------------------------------------- the walls between the statues
-- a banner on the wall face: an iron rod, the cloth torn into strips at the bottom, a gold charge
local function banner(cf, len)
	part("BannerRod", Vector3.new(4.8, 0.3, 0.3), cf * CFrame.new(0, 22, 0), IRON, Enum.Material.Metal, lairF)
	local strips = 6
	for k = 0, strips - 1 do
		local w = 4 / strips
		local l = len - rng:NextNumber(0, len * 0.45) * (if k % 2 == 0 then 1 else 0.4)
		local strip = decor(part("Banner", Vector3.new(w, l, 0.12), cf * CFrame.new(-2 + w / 2 + k * w, 22 - l / 2, 0), CLOTH, Enum.Material.Fabric, lairF))
		strip.Color = CLOTH:Lerp(Color3.fromRGB(70, 20, 20), rng:NextNumber(0, 0.4))
	end
	decor(part("BannerTrim", Vector3.new(4, 0.5, 0.14), cf * CFrame.new(0, 21.6, -0.02), GOLD, Enum.Material.Fabric, lairF))
	decor(part("BannerCharge", Vector3.new(1.6, 1.6, 0.15), cf * CFrame.new(0, 18.5, -0.05) * CFrame.Angles(0, 0, math.pi / 4), GOLD, Enum.Material.Fabric, lairF))
end
-- a heater shield with a coat of arms (field, a band, a boss), and two swords crossed behind it
local function shield(cf, field)
	part("ShieldBack", Vector3.new(3.4, 3.6, 0.3), cf, Color3.fromRGB(90, 70, 50), Enum.Material.Wood, lairF)
	decor(part("ShieldField", Vector3.new(3, 3, 0.1), cf * CFrame.new(0, 0.2, -0.2), field, Enum.Material.SmoothPlastic, lairF))
	decor(part("ShieldPoint", Vector3.new(2, 2, 0.1), cf * CFrame.new(0, -1.3, -0.2) * CFrame.Angles(0, 0, math.pi / 4), field, Enum.Material.SmoothPlastic, lairF))
	decor(part("ShieldBand", Vector3.new(0.6, 3.6, 0.12), cf * CFrame.new(0, 0, -0.27), GOLD, Enum.Material.Metal, lairF))
	decor(part("ShieldBoss", Vector3.new(0.9, 0.9, 0.3), cf * CFrame.new(0, 0.4, -0.35), STEEL, Enum.Material.Metal, lairF))
	for _, a in ipairs({ 0.75, -0.75 }) do
		local sword = cf * CFrame.new(0, 0, 0.2) * CFrame.Angles(0, 0, a)
		decor(part("WallBlade", Vector3.new(0.35, 6, 0.1), sword * CFrame.new(0, 1.2, 0), STEEL, Enum.Material.Metal, lairF))
		decor(part("WallGuard", Vector3.new(1.6, 0.25, 0.2), sword * CFrame.new(0, -1.9, 0), GOLD, Enum.Material.Metal, lairF))
		decor(part("WallGrip", Vector3.new(0.3, 1.2, 0.2), sword * CFrame.new(0, -2.6, 0), Color3.fromRGB(70, 45, 30), Enum.Material.Wood, lairF))
	end
end
-- a suit of armour on a wooden stand
local function armourStand(cf)
	textured(part("StandBase", Vector3.new(2.4, 0.4, 2.4), cf * CFrame.new(0, 0.2, 0), WOOD, nil, lairF), "px_spruce_planks")
	part("StandPole", Vector3.new(0.3, 4, 0.3), cf * CFrame.new(0, 2.2, 0.3), WOOD, Enum.Material.Wood, lairF)
	local function steel(name, size, offset)
		return part(name, size, cf * CFrame.new(offset[1], offset[2], offset[3]), STEEL, Enum.Material.Metal, lairF)
	end
	steel("ArmourLegs", Vector3.new(1.6, 2, 0.9), { 0, 1.6, 0 })
	steel("ArmourTasset", Vector3.new(1.9, 0.6, 1.1), { 0, 2.9, 0 })
	steel("ArmourChest", Vector3.new(2, 1.9, 1.1), { 0, 4.1, 0 })
	steel("ArmourPauldron", Vector3.new(0.9, 0.6, 1.2), { -1.3, 4.8, 0 })
	steel("ArmourPauldron", Vector3.new(0.9, 0.6, 1.2), { 1.3, 4.8, 0 })
	steel("ArmourArm", Vector3.new(0.6, 1.6, 0.7), { -1.3, 3.8, 0 })
	steel("ArmourArm", Vector3.new(0.6, 1.6, 0.7), { 1.3, 3.8, 0 })
	steel("ArmourHelm", Vector3.new(1.1, 1.2, 1.1), { 0, 5.7, 0 })
	decor(part("ArmourVisor", Vector3.new(0.8, 0.12, 0.05), cf * CFrame.new(0, 5.8, -0.57), Color3.fromRGB(25, 25, 28), nil, lairF))
	decor(part("ArmourPlume", Vector3.new(0.25, 0.8, 1), cf * CFrame.new(0, 6.6, 0.1), CLOTH, Enum.Material.Fabric, lairF))
end
-- a rack of weapons: two posts, a rail, spears, a halberd, an axe leaning in it
local function weaponRack(cf)
	for _, x in ipairs({ -2.6, 2.6 }) do
		part("RackPost", Vector3.new(0.4, 4, 0.4), cf * CFrame.new(x, 2, 0), WOOD, Enum.Material.Wood, lairF)
	end
	part("RackRail", Vector3.new(5.6, 0.3, 0.4), cf * CFrame.new(0, 3.4, 0), WOOD, Enum.Material.Wood, lairF)
	part("RackFoot", Vector3.new(5.6, 0.3, 1.4), cf * CFrame.new(0, 0.15, 0.4), WOOD, Enum.Material.Wood, lairF)
	for i = -2, 2 do
		local tilt = CFrame.Angles(-0.12, 0, rng:NextNumber(-0.05, 0.05))
		local shaft = cf * CFrame.new(i * 1, 3, 0.25) * tilt
		decor(part("SpearShaft", Vector3.new(0.18, 6, 0.18), shaft, Color3.fromRGB(110, 80, 50), Enum.Material.Wood, lairF))
		if i == 0 then
			decor(part("HalberdBlade", Vector3.new(1.2, 1.2, 0.1), shaft * CFrame.new(0.5, 2.6, 0), STEEL, Enum.Material.Metal, lairF))
		end
		decor(part("SpearHead", Vector3.new(0.3, 0.9, 0.08), shaft * CFrame.new(0, 3.4, 0), STEEL, Enum.Material.Metal, lairF))
	end
end
-- round the wall at θ = 45° k (between the statues): a banner, two shields, and a suit of armour or a weapon rack
for k = 1, 7 do
	local th = math.rad(45 * k)
	local x, z = polar(th, LAIR.r - 3)
	if k ~= 4 and not ruinedCorner(x, z) then -- not behind the throne, not in the fallen corner
		banner(facing(th, LAIR.r - 3.6, 0), rng:NextNumber(10, 14))
		for _, side in ipairs({ -1, 1 }) do
			shield(facing(th, LAIR.r - 3.2, 11) * CFrame.new(side * 6, 0, 0), if k % 2 == 0 then Color3.fromRGB(40, 60, 120) else Color3.fromRGB(30, 90, 50))
		end
		if k % 2 == 1 then
			armourStand(facing(th, LAIR.r - 8, 0))
		else
			weaponRack(facing(th, LAIR.r - 7, 0))
		end
	end
end

-- ---------------------------------------------------------------- the feast table (west) and the armoury (east)
do
	-- a long oak table along the west wall, one end collapsed, benches (one overturned), goblets, plates, a candlestick
	local tx, tz = -66, LAIR.cz
	textured(part("FeastTop", Vector3.new(5, 0.5, 28), lairAt(tx, 3, tz) * CFrame.Angles(0.04, 0, 0), WOOD, nil, lairF), "px_dark_oak_planks")
	for _, dz in ipairs({ -12, -4, 4 }) do
		for _, dx in ipairs({ -2, 2 }) do
			part("FeastLeg", Vector3.new(0.5, 2.8, 0.5), lairAt(tx + dx, 1.4, tz + dz), WOOD, Enum.Material.Wood, lairF)
		end
	end
	textured(part("FeastBroken", Vector3.new(5, 0.5, 6), lairAt(tx, 1.4, tz + 15) * CFrame.Angles(0.5, 0, 0), WOOD, nil, lairF), "px_dark_oak_planks")
	textured(part("Bench", Vector3.new(1.6, 0.4, 22), lairAt(tx + 4.5, 1.8, tz - 2), WOOD, nil, lairF), "px_spruce_planks")
	textured(part("BenchFallen", Vector3.new(1.6, 0.4, 22), lairAt(tx - 4.8, 0.8, tz - 1) * CFrame.Angles(0, 0.08, math.pi / 2), WOOD, nil, lairF), "px_spruce_planks")
	for i = 0, 6 do
		local gz = tz - 12 + i * 3.6
		decor(part("Plate", Vector3.new(1.4, 0.1, 1.4), lairAt(tx + 1.2, 3.3, gz), Color3.fromRGB(170, 160, 140), Enum.Material.Metal, lairF))
		if i % 2 == 0 then
			decor(part("Goblet", Vector3.new(0.45, 0.8, 0.45), lairAt(tx - 1, 3.65, gz + 0.8), GOLD, Enum.Material.Metal, lairF))
		end
	end
	decor(part("GobletFallen", Vector3.new(0.45, 0.8, 0.45), lairAt(tx + 3.6, 0.25, tz + 6) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, lairF))
	part("Candlestick", Vector3.new(0.6, 2, 0.6), lairAt(tx, 4.25, tz - 4), GOLD, Enum.Material.Metal, lairF)
	local flame = decor(part("CandleFlame", Vector3.new(0.3, 0.5, 0.3), lairAt(tx, 5.5, tz - 4), TORCH, Enum.Material.Neon, lairF))
	light(flame, 16, 0.9, TORCH)
	barrel(tx - 2, LF, tz - 17)
	barrel(tx + 2, LF, tz - 18.5)
end
do
	-- the armoury corner by the east wall: an anvil on a log, a grindstone, a forge of bricks with embers, a chest
	local ax, az = 64, LAIR.cz + 6
	textured(part("AnvilLog", Vector3.new(2.4, 2, 2.4), lairAt(ax, 1, az), WOOD, nil, lairF), "px_oak_log")
	part("AnvilBase", Vector3.new(1.4, 0.8, 1.6), lairAt(ax, 2.4, az), IRON, Enum.Material.Metal, lairF)
	part("AnvilTop", Vector3.new(1.6, 0.7, 3.2), lairAt(ax, 3.15, az), IRON, Enum.Material.Metal, lairF)
	part("AnvilHorn", Vector3.new(0.8, 0.5, 1), lairAt(ax, 3.2, az - 2), IRON, Enum.Material.Metal, lairF)
	part("Hammer", Vector3.new(0.3, 0.3, 1.8), lairAt(ax + 0.3, 3.65, az + 0.6) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, lairF)
	textured(part("Forge", Vector3.new(6, 4, 5), lairAt(ax + 6, 2, az + 9), STONE, nil, lairF), "px_red_brick")
	local embers = decor(part("ForgeEmbers", Vector3.new(4.4, 0.3, 3.4), lairAt(ax + 6, 4.1, az + 9), Color3.fromRGB(255, 90, 30), Enum.Material.Neon, lairF))
	light(embers, 22, 1.2, Color3.fromRGB(255, 120, 50))
	local smoke = Instance.new("Smoke")
	smoke.Color = Color3.fromRGB(80, 75, 70)
	smoke.Opacity = 0.08
	smoke.RiseVelocity = 3
	smoke.Size = 2
	smoke.Parent = embers
	textured(part("ForgeHood", Vector3.new(5, 1, 4), lairAt(ax + 6, 8.5, az + 9), STONE, nil, lairF), "px_red_brick")
	local grind = part("Grindstone", Vector3.new(0.8, 3, 3), lairAt(ax - 2, 2.4, az + 6) * CFrame.Angles(0, 0, 0), STONE, nil, lairF)
	grind.Shape = Enum.PartType.Cylinder
	textured(grind, "px_smooth_stone")
	for _, dz in ipairs({ -0.8, 0.8 }) do
		part("GrindFrame", Vector3.new(0.3, 2.4, 0.3), lairAt(ax - 2, 1.2, az + 6 + dz), WOOD, Enum.Material.Wood, lairF)
	end
	weaponRack(CFrame.lookAt(Vector3.new(BX + ax + 2, LF, BZ + az - 10), Vector3.new(BX, LF, BZ + az - 10)))
	crate(ax + 3, LF, az - 4, 2.6)
end

-- ---------------------------------------------------------------- the north end: the throne of the dead king
local TZ = LAIR.z1 + 14
for k = 0, 2 do
	box("ThroneStep", -16 + k * 3, LF, TZ - 9, 16 - k * 3, LF + 1 + k, TZ + 8 - k * 2.5, "px_stone_bricks", STATUE, lairF)
end
local ty = 3
textured(part("ThroneBase", Vector3.new(5.4, 1.4, 4.2), lairAt(0, ty + 0.7, TZ - 4), STONE, nil, lairF), "px_stone_bricks", STATUE)
textured(part("ThroneSeat", Vector3.new(6, 1, 4.6), lairAt(0, ty + 1.9, TZ - 4), STONE, nil, lairF), "px_smooth_stone", STATUE)
textured(part("ThroneBack", Vector3.new(6, 9, 1.2), lairAt(0, ty + 6.4, TZ - 6.2), STONE, nil, lairF), "px_smooth_stone", STATUE)
for k = 1, 3 do
	textured(part("ThroneSpire", Vector3.new(6 - k * 1.6, 1, 1.2), lairAt(0, ty + 10.4 + k, TZ - 6.2), STONE, nil, lairF), "px_smooth_stone", STATUE)
end
for _, sx in ipairs({ -1, 1 }) do
	textured(part("ThroneArm", Vector3.new(1, 2.2, 4.6), lairAt(sx * 3.3, ty + 3, TZ - 4), STONE, nil, lairF), "px_smooth_stone", STATUE)
	textured(part("ThroneFinial", Vector3.new(1.4, 1.4, 1.4), lairAt(sx * 3.3, ty + 11.2, TZ - 6.2), STONE, nil, lairF), "px_gold_block")
	-- tall iron candle stands at the throne
	part("CandleStand", Vector3.new(0.4, 7, 0.4), lairAt(sx * 9, ty + 3.5, TZ - 3), IRON, Enum.Material.Metal, lairF)
	part("CandleDish", Vector3.new(1.6, 0.3, 1.6), lairAt(sx * 9, ty + 7, TZ - 3), IRON, Enum.Material.Metal, lairF)
	for k = 0, 2 do
		decor(part("Candle", Vector3.new(0.35, 0.9, 0.35), lairAt(sx * 9 + (k - 1) * 0.5, ty + 7.6, TZ - 3), Color3.fromRGB(238, 228, 200), nil, lairF))
		decor(part("CandleFlame", Vector3.new(0.22, 0.35, 0.22), lairAt(sx * 9 + (k - 1) * 0.5, ty + 8.25, TZ - 3), TORCH, Enum.Material.Neon, lairF))
	end
	-- treasure chests by the steps, one open with gold spilling out
	local chest = textured(part("Chest", Vector3.new(3.4, 2.2, 2.2), lairAt(sx * 20, 1.1, TZ + 6), WOOD, nil, lairF), "px_spruce_planks")
	decor(part("ChestBand", Vector3.new(3.5, 2.3, 0.3), chest.CFrame, IRON, Enum.Material.Metal, lairF))
	if sx > 0 then
		decor(part("ChestLid", Vector3.new(3.4, 0.4, 2.2), lairAt(sx * 20, 2.8, TZ + 4.6) * CFrame.Angles(1.2, 0, 0), WOOD, Enum.Material.Wood, lairF))
		decor(part("ChestGold", Vector3.new(3, 0.4, 1.8), lairAt(sx * 20, 2.25, TZ + 6), GOLD, Enum.Material.Metal, lairF))
		for _ = 1, 10 do
			decor(part("Coin", Vector3.new(0.5, 0.1, 0.5), lairAt(sx * 20 + rng:NextNumber(-3, 3), 0.06, TZ + 8 + rng:NextNumber(0, 3)), GOLD, Enum.Material.Metal, lairF))
		end
	else
		decor(part("ChestLid", Vector3.new(3.5, 0.5, 2.3), lairAt(sx * 20, 2.45, TZ + 6), WOOD, Enum.Material.Wood, lairF))
		decor(part("ChestLock", Vector3.new(0.6, 0.7, 0.2), lairAt(sx * 20, 1.8, TZ + 4.85), GOLD, Enum.Material.Metal, lairF))
	end
end
decor(part("ThroneCushion", Vector3.new(4.6, 0.4, 3.8), lairAt(0, ty + 2.6, TZ - 3.8), CLOTH, Enum.Material.Fabric, lairF))
decor(part("ThroneBackCloth", Vector3.new(4.2, 6, 0.2), lairAt(0, ty + 6.2, TZ - 5.5), CLOTH, Enum.Material.Fabric, lairF))
-- the dead king still sits on it: a skull with a crown, bones on the cushion, a sceptre on the steps
local skull = decor(part("KingSkull", Vector3.new(1.2, 1.1, 1.3), lairAt(0.2, ty + 4.6, TZ - 4.9) * CFrame.Angles(0.3, 0.2, 0.15), Color3.fromRGB(226, 220, 198), nil, lairF))
for _, s in ipairs({ -0.27, 0.27 }) do
	decor(part("Eye", Vector3.new(0.32, 0.32, 0.05), skull.CFrame * CFrame.new(s, 0.1, -0.66), Color3.fromRGB(25, 22, 20), nil, lairF))
end
decor(part("Crown", Vector3.new(1.4, 0.4, 1.4), skull.CFrame * CFrame.new(0, 0.7, 0), GOLD, Enum.Material.Metal, lairF))
for k = 0, 3 do
	local a = k / 4 * math.pi * 2
	decor(part("CrownTooth", Vector3.new(0.3, 0.5, 0.3), skull.CFrame * CFrame.new(math.cos(a) * 0.55, 1.1, math.sin(a) * 0.55), GOLD, Enum.Material.Metal, lairF))
end
bones(0, LF + ty + 2.8, TZ - 3.6, 4)
decor(part("Sceptre", Vector3.new(0.25, 0.25, 3.2), lairAt(4, 1.2, TZ + 4) * CFrame.Angles(0, 0.6, 0), GOLD, Enum.Material.Metal, lairF))
decor(part("SceptreGem", Vector3.new(0.6, 0.6, 0.6), lairAt(4.9, 1.2, TZ + 2.7), Color3.fromRGB(180, 30, 40), Enum.Material.Neon, lairF))
-- the tapestry on the north wall behind the throne: red cloth, a gold border and emblem, torn at the bottom
do
	local cf = facing(math.pi, LAIR.r - 1.6, 0)
	local tw = 22
	for k = 0, 10 do
		local w = tw / 11
		local l = 24 - rng:NextNumber(0, 7) * (if k % 3 == 0 then 1 else 0.35)
		local strip = decor(part("Tapestry", Vector3.new(w, l, 0.15), cf * CFrame.new(-tw / 2 + w / 2 + k * w, 34 - l / 2, 0), CLOTH, Enum.Material.Fabric, lairF))
		strip.Color = CLOTH:Lerp(Color3.fromRGB(60, 18, 18), rng:NextNumber(0, 0.35))
	end
	decor(part("TapestryTop", Vector3.new(tw + 1, 1, 0.3), cf * CFrame.new(0, 34, 0.05), GOLD, Enum.Material.Fabric, lairF))
	decor(part("TapestryEmblem", Vector3.new(5, 5, 0.2), cf * CFrame.new(0, 25, -0.15) * CFrame.Angles(0, 0, math.pi / 4), GOLD, Enum.Material.Fabric, lairF))
	decor(part("TapestryEmblemIn", Vector3.new(3, 3, 0.25), cf * CFrame.new(0, 25, -0.2) * CFrame.Angles(0, 0, math.pi / 4), CLOTH, Enum.Material.Fabric, lairF))
end
local throneLight = decor(part("ThroneLight", Vector3.new(1, 1, 1), lairAt(0, 14, TZ + 8), STONE, nil, lairF))
throneLight.Transparency = 1
light(throneLight, 40, 1, Color3.fromRGB(255, 200, 150))

-- ---------------------------------------------------------------- the carpet, braziers, chandeliers
-- the red carpet runner from the door to the throne, torn and gone in places (not across the dais)
do
	local z = LAIR.z0 - 2
	while z > TZ + 9 do
		local len = rng:NextNumber(5, 14)
		local z2 = math.max(TZ + 9, z - len)
		local mz = (z + z2) / 2
		if math.abs(mz - LAIR.cz) > PLATFORM_R + 2 then
			local rug = part("Carpet", Vector3.new(9, 0.12, z - z2), lairAt(rng:NextNumber(-0.3, 0.3), 0.06, mz) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0), CLOTH, Enum.Material.Fabric, lairF)
			rug.CanCollide = false
			decor(part("CarpetTrim", Vector3.new(9.8, 0.1, z - z2), rug.CFrame * CFrame.new(0, -0.01, 0), GOLD, Enum.Material.Fabric, lairF))
		end
		z = z2 - rng:NextNumber(0.5, 3)
	end
end
-- eight braziers on iron tripods round the arena
for k = 0, 7 do
	local x, z = polar(math.rad(22.5 + 45 * k), 42)
	for leg = 0, 2 do
		local a = leg / 3 * math.pi * 2
		part("TripodLeg", Vector3.new(0.35, 5.4, 0.35), lairAt(x + math.cos(a) * 0.9, 2.6, z + math.sin(a) * 0.9) * CFrame.Angles(math.sin(a) * 0.2, 0, -math.cos(a) * 0.2), IRON, Enum.Material.Metal, lairF)
	end
	part("BrazierBowl", Vector3.new(2.8, 0.9, 2.8), lairAt(x, 5.3, z), IRON, Enum.Material.Metal, lairF)
	local coals = decor(part("BrazierCoals", Vector3.new(2.3, 0.3, 2.3), lairAt(x, 5.85, z), Color3.fromRGB(255, 110, 40), Enum.Material.Neon, lairF))
	local fire = Instance.new("Fire")
	fire.Size = 3.5
	fire.Heat = 6
	fire.Parent = coals
	light(coals, 32, 1.4, Color3.fromRGB(255, 150, 80))
end
-- chandeliers: an iron ring with candles; the great one hangs from the crown of the dome over the arena
local function chandelier(x, y, z, radius, crashed)
	local tilt = if crashed then CFrame.Angles(0.25, 0, -0.2) else CFrame.new()
	local centre = lairAt(x, y, z) * tilt
	local n = math.floor(radius * 3)
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		decor(part("ChandelierRing", Vector3.new(0.5, 0.5, radius * 2 * math.pi / n + 0.2), centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius), IRON, Enum.Material.Metal, lairF))
		if k % 2 == 0 then
			local cpos = centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, -radius)
			decor(part("Candle", Vector3.new(0.4, 1, 0.4), cpos, Color3.fromRGB(238, 228, 200), nil, lairF))
			if not crashed then
				decor(part("CandleFlame", Vector3.new(0.25, 0.4, 0.25), cpos * CFrame.new(0, 0.7, 0), TORCH, Enum.Material.Neon, lairF))
			end
		end
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		decor(part("ChandelierSpoke", Vector3.new(0.35, 0.35, radius), centre * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -radius / 2), IRON, Enum.Material.Metal, lairF))
	end
	if crashed then
		pile(x + 2, z + 1, { "px_stone_bricks", "px_cobblestone" }, 4)
		decor(part("BrokenChain", Vector3.new(0.25, 8, 0.25), lairAt(x + 3, 0.3, z - 2) * CFrame.Angles(math.pi / 2, 0.4, 0), IRON, Enum.Material.Metal, lairF))
	else
		local ceil = lairCeil(x, z) - LF
		decor(part("ChandelierChain", Vector3.new(0.4, ceil - y, 0.4), lairAt(x, (ceil + y) / 2, z), IRON, Enum.Material.Metal, lairF))
		local glow = decor(part("ChandelierGlow", Vector3.new(0.5, 0.5, 0.5), lairAt(x, y + 1, z), TORCH, nil, lairF))
		glow.Transparency = 1
		light(glow, 60, 1.4, TORCH)
	end
end
chandelier(0, 34, LAIR.cz, 9, false)
chandelier(-50, 0.6, LAIR.cz + 24, 4.2, true)

-- the caved-in north-east: the cave rock broke the wall, boulders and masonry everywhere
for _ = 1, 5 do
	local x, z = polar(math.rad(135 + rng:NextNumber(-10, 10)), rng:NextNumber(70, 86))
	pile(x, z, { "px_stone", "px_cobblestone", "px_mossy_cobblestone", "px_stone_bricks" }, 10)
end
for _ = 1, 6 do
	local s = rng:NextNumber(3, 6)
	local x, z = polar(math.rad(135 + rng:NextNumber(-12, 12)), rng:NextNumber(74, 90))
	textured(part("Boulder", Vector3.new(s, s * 0.8, s), lairAt(x, s * 0.35, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)), STONE, nil, lairF), "px_stone", WALL_TINT)
end
-- a pool of murky water where the floor sank
do
	local x, z = polar(math.rad(165), 56)
	local pool = part("Pool", Vector3.new(0.3, 14, 14), lairAt(x, 0.1, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 90, 50), Enum.Material.Glass, lairF)
	pool.Shape = Enum.PartType.Cylinder
	pool.Transparency = 0.25
	pool.Reflectance = 0.15
	pool.CanCollide = false
	light(pool, 16, 0.5, Color3.fromRGB(120, 220, 90))
end

local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), lairAt(0, 1.7, LAIR.cz), STONE, nil, lairF)
bossSpawn.Transparency = 1
bossSpawn.CanCollide = false
bossSpawn.CanQuery = false
bossSpawn:SetAttribute("BossId", "splinter")
bossSpawn:SetAttribute("ArenaRadius", LAIR.r - 20)
CollectionService:AddTag(bossSpawn, "BossSpawn")
-- the great door: a high arch on the hall side, one wooden leaf still on its hinges, the other fallen in
arch(LAIR.z0 - 2.2, LAIR.door, LF + 12, 8, "px_stone_bricks", Color3.fromRGB(205, 198, 192), lairF)
local hinge = lairAt(-LAIR.door + 0.5, 8, LAIR.z0 - 3.5) * CFrame.Angles(0, 1.1, 0)
textured(part("DoorLeaf", Vector3.new(10, 16, 0.8), hinge * CFrame.new(5, 0, 0), WOOD, nil, lairF), "px_dark_oak_planks")
for _, y in ipairs({ -5, 5 }) do
	decor(part("DoorBand", Vector3.new(10.2, 0.6, 1), hinge * CFrame.new(5, y, 0), IRON, Enum.Material.Metal, lairF))
end
textured(part("FallenLeaf", Vector3.new(10, 0.8, 16), lairAt(6, 0.4, LAIR.z0 - 13) * CFrame.Angles(0, 0.2, 0.05), WOOD, nil, lairF), "px_dark_oak_planks")
local lairSign = decor(part("LairSign", Vector3.new(1, 1, 1), lairAt(0, 25, LAIR.z0 - 4), STONE, nil, lairF))
lairSign.Transparency = 1
sign(lairSign, "Логово Сплинтера", 0, Color3.fromRGB(255, 80, 60))
for _, side in ipairs({ -1, 1 }) do
	part("Stake", Vector3.new(0.4, 5, 0.4), at(side * 9, LF + 2.5, STAIR_BOTTOM - 8), WOOD, Enum.Material.Wood, lairF)
	bones(side * 9, LF, STAIR_BOTTOM - 8, 2)
end

-- the broken arch where the masonry ends in tunnel 1
do
	local ax = select(1, linePoint(SHAPE.tunnel1.pts, 0.42))
	local _, az = linePoint(SHAPE.tunnel1.pts, 0.42)
	local az4 = 4 * math.floor(az / 4) + 2
	local left, right = wallFace(ax, az4, -1), wallFace(ax, az4, 1)
	if left and right then
		local half = math.floor((right - left) / 4) * 2
		local mid = (left + right) / 2
		local f = folder("BrokenArch")
		for k = 0, half - 1 do
			local xL = mid - half + k * 2
			local t = (xL + 1 - mid) / half
			if t < 0.35 then -- the right half has fallen
				local top = 8 + 6 * math.sqrt(math.max(0, 1 - t * t))
				box("Arch", xL, 2 * math.floor(top / 2 + 0.5), az4 - 1, xL + 2, 22, az4 + 1, "px_mossy_stone_bricks", Color3.fromRGB(190, 185, 180), f)
			end
		end
		box("ArchPier", left, 0, az4 - 1, left + 1.5, 10, az4 + 1, "px_stone_bricks", nil, f)
		box("ArchPierStub", right - 1.5, 0, az4 - 1, right, 2.5, az4 + 1, "px_stone_bricks", nil, f)
		pile(right - 3, az4 - 3, { "px_stone_bricks", "px_mossy_stone_bricks", "px_cobblestone" }, 7)
	end
end

-- ================================================================ cave life: dripstone, roots, mushrooms, webs, puddles
local life = folder("CaveLife")
local lights = 0
for _, c in pairs(cells) do
	local s = SHAPE[c.shape]
	if s then
		local cave = s.kind == "ellipse"
		local nearHole = c.hole ~= nil
		for _, m in ipairs({ M1, M2 }) do
			if math.abs(c.x) < m.hole + 3 and math.abs(c.z - m.cz) < m.hole + 3 then
				nearHole = true
			end
		end
		local onDais = c.shape == "lair" and math.sqrt(c.x ^ 2 + (c.z - LAIR.cz) ^ 2) < PLATFORM_R + 18
		local r = rng:NextNumber()
		-- stalactites: a short stack of shrinking stone blocks under the dome
		if c.shape ~= "lair" and (cave or c.edge >= 2) and r < (if cave then 0.09 else 0.05) and c.edge >= 2 then
			local y = c.ceil
			local s0 = rng:NextNumber(1.6, 2.6)
			for k = 0, rng:NextInteger(1, 3) do
				local sz = s0 * (1 - k * 0.28)
				local len = rng:NextNumber(1.4, 2.6)
				textured(decor(part("Stalactite", Vector3.new(sz, len, sz), at(c.x + rng:NextNumber(-0.8, 0.8), y - len / 2, c.z + rng:NextNumber(-0.8, 0.8)), STONE, nil, life)), "px_stone", CEIL_TINT)
				y -= len
			end
		end
		-- stalagmites on the cave floors, away from the trail, the pits and the dais
		if cave and not c.path and not nearHole and not onDais and c.edge >= 2 and r > 0.955 then
			local y = c.floor
			local s0 = rng:NextNumber(1.8, 3)
			for k = 0, rng:NextInteger(1, 3) do
				local sz = s0 * (1 - k * 0.27)
				local len = rng:NextNumber(1.6, 2.8)
				textured(part("Stalagmite", Vector3.new(sz, len, sz), at(c.x + rng:NextNumber(-0.6, 0.6), y + len / 2, c.z + rng:NextNumber(-0.6, 0.6)), STONE, nil, life), "px_stone", WALL_TINT)
				y += len
			end
		end
		-- roots hanging from the tunnel ceilings
		if s.kind == "line" and r > 0.25 and r < 0.29 then
			for _ = 1, rng:NextInteger(2, 4) do
				local len = rng:NextNumber(1.5, 4)
				decor(part("Root", Vector3.new(0.25, len, 0.25), at(c.x + rng:NextNumber(-1.5, 1.5), c.ceil - len / 2, c.z + rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), Color3.fromRGB(80, 60, 40), Enum.Material.Wood, life))
			end
		end
		-- glowing mushrooms at the foot of the walls (cyan and violet, a soft light on every few)
		if c.edge == 1 and not c.path and c.shape ~= "hall" and c.shape ~= "lair" and r > 0.3 and r < 0.37 then
			local hue = if rng:NextNumber() < 0.6 then Color3.fromRGB(90, 230, 230) else Color3.fromRGB(190, 110, 255)
			for k = 1, rng:NextInteger(2, 4) do
				local h = rng:NextNumber(0.5, 1.3)
				local mx, mz = c.x + rng:NextNumber(-1.4, 1.4), c.z + rng:NextNumber(-1.4, 1.4)
				decor(part("MushStem", Vector3.new(0.25, h, 0.25), at(mx, c.floor + h / 2, mz), Color3.fromRGB(220, 215, 200), nil, life))
				local cap = decor(part("MushCap", Vector3.new(0.7 + h * 0.4, 0.3, 0.7 + h * 0.4), at(mx, c.floor + h + 0.1, mz), hue, Enum.Material.Neon, life))
				if k == 1 and lights < 40 then
					light(cap, 9, 0.9, hue)
					lights += 1
				end
			end
		end
		-- cobwebs in the corners of the tunnel vaults
		if s.kind == "line" and c.edge == 1 and r > 0.5 and r < 0.53 then
			cobweb(c.x, c.ceil - 1.6, c.z, rng:NextNumber(0, 6.28))
		end
		-- puddles in the tunnels and caves
		if not c.path and not nearHole and not onDais and c.edge >= 2 and r > 0.6 and r < 0.615 then
			local p = decor(part("Puddle", Vector3.new(0.1, 5, 5), at(c.x, c.floor + 0.04, c.z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(55, 75, 90), Enum.Material.Glass, life))
			p.Shape = Enum.PartType.Cylinder
			p.Transparency = 0.35
			p.Reflectance = 0.3
			local drip = Instance.new("ParticleEmitter")
			drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			drip.Color = ColorSequence.new(Color3.fromRGB(150, 180, 200))
			drip.Size = NumberSequence.new(0.12)
			drip.Rate = 1
			drip.Lifetime = NumberRange.new(0.6, 0.9)
			drip.Speed = NumberRange.new(0)
			drip.Acceleration = Vector3.new(0, -40, 0)
			local emitter = decor(part("Drip", Vector3.new(0.2, 0.2, 0.2), at(c.x, c.ceil - 0.2, c.z), STONE, nil, life))
			emitter.Transparency = 1
			drip.Parent = emitter
		end
	end
	if count % 400 == 0 then
		task.wait()
	end
	count += 1
end
-- ================================================================ grottos
local grottos = folder("Grottos")
-- the old storeroom of the prison: crates and sacks the guards forgot, a broken shelf, a lantern
do
	local g = SHAPE.storeroom
	for _, c in ipairs({ { 6, -3, 3 }, { 8.5, -1, 2.4 }, { 6.3, -3, 2.2, 3 }, { 4, 4, 3 }, { -2, -6, 2.6 } }) do
		crate(g.cx + c[1], c[4] or 0, g.cz + c[2], c[3])
	end
	barrel(g.cx + 2, 0, g.cz - 6)
	barrel(g.cx + 9, 0, g.cz + 3, true)
	for i = 1, 5 do
		local sack = part("Sack", Vector3.new(1.8, 1.4, 1.4), at(g.cx - 4 + i * 1.5, 0.7, g.cz + 5.5 + rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(176, 150, 110), Enum.Material.Fabric, grottos)
		sack.Shape = Enum.PartType.Block
	end
	textured(part("ShelfBroken", Vector3.new(6, 0.4, 1.4), at(g.cx + 3, 2.2, g.cz - 8) * CFrame.Angles(0, 0, 0.35), WOOD, nil, grottos), "px_planks")
	local lantern = decor(part("Lantern", Vector3.new(1, 1.3, 1), at(g.cx + 1, 1.4, g.cz + 1), TORCH, Enum.Material.Neon, grottos))
	light(lantern, 18, 1.1, TORCH)
	cobweb(g.cx + 10, 8, g.cz - 4, 0.9)
end
-- the underground spring: a clear pool fed by a trickle from the rock, moss and glowing mushrooms round it
do
	local g = SHAPE.spring
	local pool = part("Spring", Vector3.new(0.4, 14, 14), at(g.cx - 3, 0.3, g.cz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 120, 160), Enum.Material.Glass, grottos)
	pool.Shape = Enum.PartType.Cylinder
	pool.Transparency = 0.3
	pool.Reflectance = 0.25
	pool.CanCollide = false
	light(pool, 20, 0.9, Color3.fromRGB(110, 190, 255))
	local rim = part("SpringRim", Vector3.new(0.6, 16, 16), at(g.cx - 3, 0.1, g.cz) * CFrame.Angles(0, 0, math.pi / 2), Color3.new(1, 1, 1), nil, grottos)
	rim.Shape = Enum.PartType.Cylinder
	textured(rim, "px_mossy_cobblestone")
	-- the trickle: a thin falling sheet from the west rock face into the pool
	local face = wallFace(g.cx - 3, g.cz, -1)
	if face then
		local fall = decor(part("Trickle", Vector3.new(0.4, 9, 1.4), at(face + 0.3, 4.6, g.cz), Color3.fromRGB(150, 200, 235), Enum.Material.Glass, grottos))
		fall.Transparency = 0.45
		local splash = Instance.new("ParticleEmitter")
		splash.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		splash.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
		splash.Size = NumberSequence.new(0.2)
		splash.Rate = 10
		splash.Lifetime = NumberRange.new(0.3, 0.6)
		splash.Speed = NumberRange.new(2, 4)
		splash.SpreadAngle = Vector2.new(60, 60)
		splash.EmissionDirection = Enum.NormalId.Top
		local foot = decor(part("Splash", Vector3.new(0.5, 0.5, 0.5), at(face + 1.2, 0.4, g.cz), STONE, nil, grottos))
		foot.Transparency = 1
		splash.Parent = foot
	end
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local hue = if i % 3 == 0 then Color3.fromRGB(190, 110, 255) else Color3.fromRGB(90, 230, 230)
		local mx, mz = g.cx - 3 + math.cos(a) * 9.5, g.cz + math.sin(a) * 9.5
		local h = rng:NextNumber(0.5, 1.2)
		decor(part("MushStem", Vector3.new(0.25, h, 0.25), at(mx, h / 2, mz), Color3.fromRGB(220, 215, 200), nil, grottos))
		decor(part("MushCap", Vector3.new(0.8 + h * 0.4, 0.3, 0.8 + h * 0.4), at(mx, h + 0.1, mz), hue, Enum.Material.Neon, grottos))
	end
end
-- the collapsed side shaft by the ore cave: rails running into a fallen heap, broken supports, a pickaxe
do
	local g = SHAPE.shaft
	for _, side in ipairs({ -0.7, 0.7 }) do
		decor(part("Rail", Vector3.new(22, 0.2, 0.3), at(g.cx - 2, 0.1, g.cz + side), IRON, Enum.Material.Metal, grottos))
	end
	for k = 0, 10 do
		textured(decor(part("Sleeper", Vector3.new(0.6, 0.2, 2.4), at(g.cx - 12 + k * 2, 0.05, g.cz), WOOD, nil, grottos)), "px_spruce_planks")
	end
	for _, x in ipairs({ -6, 2 }) do
		for _, side in ipairs({ -1, 1 }) do
			textured(part("Support", Vector3.new(1, 9, 1), at(g.cx + x, 4.5, g.cz + side * 5), WOOD, nil, grottos), "px_oak_log")
		end
		textured(part("Beam", Vector3.new(1, 1, 11), at(g.cx + x, 8.6, g.cz) * CFrame.Angles(if x > 0 then 0.25 else 0, 0, if x > 0 then 0.3 else 0), WOOD, nil, grottos), "px_oak_log")
	end
	pile(g.cx + 9, g.cz, { "px_cobblestone", "px_stone", "px_gravel", "px_iron_ore" }, 12)
	pile(g.cx + 7, g.cz - 3, { "px_cobblestone", "px_stone", "px_gold_ore" }, 8)
	minecart(g.cx + 2, g.cz, math.pi / 2 + 0.15, "px_iron_ore")
	part("PickHandle", Vector3.new(0.3, 3, 0.3), at(g.cx + 5, 2.2, g.cz + 2.5) * CFrame.Angles(0, 0, -0.6), WOOD, Enum.Material.Wood, grottos)
	part("PickHead", Vector3.new(0.4, 0.4, 2.4), at(g.cx + 5.85, 3.4, g.cz + 2.5) * CFrame.Angles(0, 0, -0.6), IRON, Enum.Material.Metal, grottos)
end

-- torches along the tunnels: every 18 studs, alternating sides, on the real rock face
for _, id in ipairs({ "tunnel1", "tunnel2", "tunnel3" }) do
	local pts = SHAPE[id].pts
	local n = 7
	for i = 1, n - 1 do
		local x, z = linePoint(pts, i / n)
		local dir = if i % 2 == 0 then -1 else 1
		local face = wallFace(x, z, dir)
		if face then
			local cl = cellAtPos(x, z)
			torch(face - dir * 0.3, (cl and cl.floor or 0) + 7, z, -dir, 0)
		end
	end
end
-- torches round the cave walls (east and west faces of each cave at a few heights of z)
for _, m in ipairs({ M1, M2 }) do
	for _, dz in ipairs({ -24, 0, 24 }) do
		for _, dir in ipairs({ -1, 1 }) do
			local face = wallFace(0, m.cz + dz, dir)
			if face then
				torch(face - dir * 0.3, 8, m.cz + dz, -dir, 0)
			end
		end
	end
end
-- a soft light high under each dome, so the stepped vault reads from below (the torches only light the walls)
for _, m in ipairs({ { 0, M1.cz, 0 }, { 0, M2.cz, 0 }, { 0, LAIR.cz, LF } }) do
	local cl = cellAtPos(m[1], m[2])
	local glow = decor(part("DomeLight", Vector3.new(1, 1, 1), at(m[1], (cl and cl.ceil or 20) - 5, m[2]), STONE, nil, life))
	glow.Transparency = 1
	light(glow, 60, 0.8, Color3.fromRGB(255, 225, 190))
end
-- the lair is huge now: four more soft lights round its dome
for k = 0, 3 do
	local a = k / 4 * math.pi * 2 + math.pi / 4
	local x, z = math.cos(a) * 55, LAIR.cz + math.sin(a) * 55
	local cl = cellAtPos(x, z)
	local glow = decor(part("DomeLight", Vector3.new(1, 1, 1), at(x, (cl and cl.ceil or LF + 30) - 5, z), STONE, nil, life))
	glow.Transparency = 1
	light(glow, 60, 0.7, Color3.fromRGB(255, 205, 160))
end
-- a thin dust in the caves' air
for _, m in ipairs({ { 0, M1.cz, 6 }, { 0, M2.cz, 6 }, { 0, LAIR.cz, LF + 6 } }) do
	local e = decor(part("Dust", Vector3.new(if m[2] == LAIR.cz then 170 else 80, 10, if m[2] == LAIR.cz then 170 else 80), at(m[1], m[3], m[2]), STONE, nil, life))
	e.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
	dust.Size = NumberSequence.new(0.25)
	dust.Transparency = NumberSequence.new(0.75)
	dust.Rate = 6
	dust.Lifetime = NumberRange.new(6, 10)
	dust.Speed = NumberRange.new(0.2, 0.6)
	dust.SpreadAngle = Vector2.new(180, 180)
	dust.LightEmission = 0.2
	dust.Parent = e
end

-- ================================================================ mobs (MobService): MobSpawn points
local mobs = folder("MobSpawns")
local function mobSpawn(id, x, z, radius)
	local cl = cellAtPos(x, z)
	local y = (if cl then cl.floor else 0) + 0.5
	local m = decor(part("MobSpawn_" .. id, Vector3.new(2, 1, 2), at(x, y, z), STONE, nil, mobs))
	m.Transparency = 1
	m:SetAttribute("MobId", id)
	m:SetAttribute("LocationId", "basement")
	m:SetAttribute("Wander", radius)
	CollectionService:AddTag(m, "MobSpawn")
end
-- 2 rats on each of the first two tunnels
for _, id in ipairs({ "tunnel1", "tunnel2" }) do
	local pts = SHAPE[id].pts
	for _, t in ipairs({ 0.45, 0.8 }) do
		local x, z = linePoint(pts, t)
		mobSpawn("rat", x, z, 7)
	end
end
-- a zombie on each side of mine 1 [владелец 22.10: «2 зомби по бокам шахты, кд 2 минуты»]
for _, side in ipairs({ -1, 1 }) do
	mobSpawn("zombie", side * (M1.hole + 8), M1.cz, 3)
end
-- the lair: a rat at each diagonal (by the rubbish heaps), a zombie at each side
for _, th in ipairs({ 45, 135, 225, 315 }) do
	local x, z = polar(math.rad(th), 47)
	mobSpawn("rat", x, z, 4)
end
for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
	mobSpawn("zombie", d[1] * 50, LAIR.cz + d[2] * 64, 4)
end

print(("[build-basement] built: %d parts"):format(#root:GetDescendants()))
