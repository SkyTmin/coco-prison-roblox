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
local TOP = 60 -- every rock column reaches this high: no gap ever shows the sky

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
local LAIR = { cx = 0, cz = -448, r = 50, floor = -8 }
local SHAPES = {
	{ id = "tunnel1", kind = "line", r = 14, pts = { { 0, -12 }, { 5, -34 }, { -7, -58 }, { 2, -80 }, { 0, -92 } }, h = { 13, 21 } },
	{ id = "cave1", kind = "ellipse", cx = 0, cz = M1.cz, rx = 62, rz = 56, h = { 15, 38 } },
	{ id = "tunnel2", kind = "line", r = 14, pts = { { 0, -186 }, { -9, -208 }, { 7, -230 }, { 0, -252 } }, h = { 13, 21 } },
	{ id = "cave2", kind = "ellipse", cx = 0, cz = M2.cz, rx = 52, rz = 48, h = { 15, 34 } },
	{ id = "tunnel3", kind = "line", r = 14, pts = { { 0, -334 }, { 9, -354 }, { -5, -376 }, { 0, -400 } }, h = { 13, 21 } },
	{ id = "lair", kind = "ellipse", cx = LAIR.cx, cz = LAIR.cz, rx = LAIR.r, rz = LAIR.r, h = { 18, 42 } },
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
local X0, ZTOP = -76, 28
local NX, NZ = 38, 134
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
		elseif z > HALL.z1 - 4 then
			-- the hall's walls stay straight: only the portal opens north
			if math.abs(x) < PORTAL and z < HALL.z1 then
				shape, best = "tunnel1", 0
			end
		else
			for _, s in ipairs(SHAPES) do
				local score
				if s.kind == "line" then
					score = lineDist(s.pts, x, z) / (s.r + n2(x, z, 1.7, 0.08) * 3)
				else
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
	elseif c.shape == "lair" then
		return math.abs(c.x) < 4 and c.z > LAIR.cz + 16
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
	else
		local R = if s.kind == "line" then 3 else 7
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
	if shape == "lair" and v > 0.1 then
		return if v > 0.35 then "px_mossy_cobblestone" else "px_cobblestone"
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
		return if v > 0.15 then "px_dirt" elseif v > -0.2 then "px_gravel" else "px_mossy_cobblestone"
	end
	if c.shape == "tunnel1" and c.z > -40 then
		return if v > 0 then "px_cobblestone" else "px_mossy_cobblestone"
	end
	return if v > 0.3 then "px_cobblestone" elseif v < -0.3 then "px_gravel" elseif v < -0.15 then "px_dirt" else "px_stone"
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
		local ck = c and (if c.shape == "hall" then "px_stone_bricks" else "px_stone") .. "|" .. c.ceil or nil
		if cr and cr.key ~= ck then
			table.insert(ceilRuns, cr)
			cr = nil
		end
		if ck and not cr then
			cr = { key = ck, ix0 = ix, variant = if c.shape == "hall" then "px_stone_bricks" else "px_stone", bottom = c.ceil }
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
		w.Transparency = 0.82
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

-- ================================================================ the lair of Сплинтер
local lairF = folder("Lair")
local LF = LAIR.floor
local PLATFORM_R = 16
local dais = part("LairDais", Vector3.new(1.4, 2 * PLATFORM_R, 2 * PLATFORM_R), at(0, LF + 0.7, LAIR.cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, lairF)
dais.Shape = Enum.PartType.Cylinder
textured(dais, "px_stone_bricks")
local daisTop = part("LairDaisTop", Vector3.new(1.7, 2 * (PLATFORM_R - 3), 2 * (PLATFORM_R - 3)), at(0, LF + 0.85, LAIR.cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, lairF)
daisTop.Shape = Enum.PartType.Cylinder
textured(daisTop, "px_smooth_stone")
-- cracked slabs and claw scratches on the dais
for i = 0, 5 do
	local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	for k = -1, 1 do
		decor(part("Scratch", Vector3.new(0.25, 0.08, 5), CFrame.new(BX, LF + 1.72, BZ + LAIR.cz) * CFrame.Angles(0, a, 0) * CFrame.new(k * 0.6, 0, -8), Color3.fromRGB(45, 42, 40), nil, lairF))
	end
end
-- the nest: a broken ring of straw, planks and bones round the dais edge
for i = 0, 27 do
	local a = i / 28 * math.pi * 2
	if math.sin(a) < 0.9 then -- open towards the entrance (south)
		local r = PLATFORM_R + rng:NextNumber(0.5, 2.5)
		local s = rng:NextNumber(1.6, 2.8)
		local p = part("Nest", Vector3.new(s, s * 0.6, s * 1.4), at(math.cos(a) * r, LF + s * 0.3, LAIR.cz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), -a + rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3)), WOOD, nil, lairF)
		textured(p, ({ "px_hay", "px_hay", "px_planks", "px_spruce_planks", "px_dirt" })[rng:NextInteger(1, 5)])
		if i % 4 == 0 then
			bones(math.cos(a) * (r + 2), LF, LAIR.cz + math.sin(a) * (r + 2), 2)
		end
	end
end
-- heaps of rubbish against the walls at the diagonals: mounds of blocks, planks, bones [меню: «горы мусора»]
local function heap(x, z, size)
	for i = 1, 26 do
		local s = rng:NextNumber(1.4, 3)
		local r = rng:NextNumber(0, size)
		local a = rng:NextNumber(0, 6.28)
		local y = LF + s / 2 + math.max(0, size - r) * 0.9
		local p = part("Rubbish", Vector3.new(s, s * rng:NextNumber(0.5, 1), s), at(x + math.cos(a) * r, y, z + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)), STONE, nil, lairF)
		textured(p, ({ "px_dirt", "px_gravel", "px_planks", "px_cobblestone", "px_mossy_cobblestone", "px_spruce_planks", "px_hay" })[rng:NextInteger(1, 7)])
	end
	bones(x, LF + 0.5, z, 5)
	barrel(x + rng:NextNumber(-3, 3), LF + size * 0.5, z + rng:NextNumber(-3, 3), true)
end
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	heap(c[1] * 31, LAIR.cz + c[2] * 31, 5.5)
end
-- eight broken columns round the dais: stacked bricks, some reaching the dome, some snapped off
for i = 0, 7 do
	local a = (i + 0.5) / 8 * math.pi * 2
	local x, z = math.cos(a) * (PLATFORM_R + 8), LAIR.cz + math.sin(a) * (PLATFORM_R + 8)
	local cl = cellAtPos(x, z)
	local full = (cl and cl.ceil or LF + 24) - LF
	local height = if i % 3 == 0 then full else rng:NextNumber(5, 11)
	local y = LF
	while y < LF + height - 0.1 do
		local seg = math.min(4, LF + height - y)
		local s = 3.4 - (if y > LF + height - 4 and height < full then 0.6 else 0)
		textured(part("Column", Vector3.new(s, seg, s), at(x + rng:NextNumber(-0.15, 0.15), y + seg / 2, z + rng:NextNumber(-0.15, 0.15)) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), STONE, nil, lairF), if rng:NextNumber() < 0.35 then "px_mossy_stone_bricks" else "px_stone_bricks", Color3.fromRGB(200, 195, 190))
		y += seg
	end
	if height < full then
		pile(x + math.cos(a) * 3, z + math.sin(a) * 3, { "px_stone_bricks", "px_mossy_stone_bricks", "px_cobblestone" }, 4)
	end
	-- a fire bowl on every other column stump
	if i % 2 == 1 and height < full then
		local bowl = decor(part("FireBowl", Vector3.new(1.8, 0.8, 1.8), at(x, LF + height + 0.4, z), Color3.fromRGB(255, 110, 50), Enum.Material.Neon, lairF))
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 5
		fire.Parent = bowl
		light(bowl, 26, 1.3, Color3.fromRGB(255, 140, 80))
	end
end
-- a murky pool in the east of the lair, green slime glowing faintly
local pool = part("Pool", Vector3.new(0.3, 16, 16), at(-18, LF + 0.1, LAIR.cz - 36) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 90, 50), Enum.Material.Glass, lairF)
pool.Shape = Enum.PartType.Cylinder
pool.Transparency = 0.25
pool.Reflectance = 0.15
pool.CanCollide = false
pool.Size = Vector3.new(0.3, 12, 12)
light(pool, 16, 0.6, Color3.fromRGB(120, 220, 90))
local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(0, LF + 1.7, LAIR.cz), STONE, nil, lairF)
bossSpawn.Transparency = 1
bossSpawn.CanCollide = false
bossSpawn.CanQuery = false
bossSpawn:SetAttribute("BossId", "splinter")
bossSpawn:SetAttribute("ArenaRadius", LAIR.r - 6)
CollectionService:AddTag(bossSpawn, "BossSpawn")
-- the entrance to the lair: an old mossy arch over the stair, a warning of bones and a skull on a stake
arch(STAIR_BOTTOM - 10, 12, LF + 8, 6, "px_mossy_stone_bricks", Color3.fromRGB(190, 185, 180), lairF)
local lairSign = decor(part("LairSign", Vector3.new(1, 1, 1), at(0, LF + 19, STAIR_BOTTOM - 10), STONE, nil, lairF))
lairSign.Transparency = 1
sign(lairSign, "Логово Сплинтера", 0, Color3.fromRGB(255, 80, 60))
for _, side in ipairs({ -1, 1 }) do
	part("Stake", Vector3.new(0.4, 5, 0.4), at(side * 9, LF + 2.5, STAIR_BOTTOM - 14), WOOD, Enum.Material.Wood, lairF)
	bones(side * 9, LF, STAIR_BOTTOM - 14, 2)
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
		local onDais = c.shape == "lair" and math.sqrt(c.x ^ 2 + (c.z - LAIR.cz) ^ 2) < PLATFORM_R + 12
		local r = rng:NextNumber()
		-- stalactites: a short stack of shrinking stone blocks under the dome
		if (cave or c.edge >= 2) and r < (if cave then 0.09 else 0.05) and c.edge >= 2 then
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
		if c.edge == 1 and not c.path and c.shape ~= "hall" and r > 0.3 and r < 0.37 then
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
-- a thin dust in the caves' air
for _, m in ipairs({ { 0, M1.cz, 6 }, { 0, M2.cz, 6 }, { 0, LAIR.cz, LF + 6 } }) do
	local e = decor(part("Dust", Vector3.new(80, 10, 80), at(m[1], m[3], m[2]), STONE, nil, life))
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
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	mobSpawn("rat", c[1] * 24, LAIR.cz + c[2] * 24, 3)
end
for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
	mobSpawn("zombie", d[1] * 36, LAIR.cz + d[2] * 36, 3)
end

print(("[build-basement] built: %d parts"):format(#root:GetDescendants()))
