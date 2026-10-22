--!nocheck
-- Builds the Королевский сад, level 11, PvP [меню]. «Королевский вишнёвый сад окружают цветущие деревья, и среди
-- них трудятся рабочие, собирая плоды и ухаживая за растениями» [меню]. Blocks: розовые листья глицинии 70 %,
-- вишнёвое дерево 30 % [меню]. Boss: Рыцарь — «хладнокровный воин в сияющих доспехах» [клиент].
-- [владелец 23.10: «черпай идеи из интернета, максимум усилий»] Ideas from real royal gardens and Minecraft
-- cherry-grove builds: a Versailles axis (an allée of topiaries and cherries, reflecting pools, embroidered hedge
-- parterres, a three-tier fountain), a sunken garden round the mine with white gazebos and wisteria arches, a
-- wisteria tunnel (as in Kawachi Fujien), a cherry orchard on hills where the gardeners pick the fruit (ladders,
-- baskets, carts), a Japanese garden (a koi pond under a red arched bridge, stone lanterns, a tea house, a torii,
-- raked gravel, bamboo), a hedge maze with a gazebo in the middle; at the north end the white royal castle with
-- blue roofs and, before it, the tournament lists — the arena of the Knight (stands, a royal box, pavilions,
-- banners); falling petals and butterflies in the air, a soft pink haze. Every name stands at its place.
-- A separate zone at X = 5400 (StreamingEnabled). Run in Studio (Edit) via scripts/studio-loader.luau after
-- build-textures. Idempotent: replaces Workspace.RoyalGarden. Arrival: LocationSpawn, LocationId "royal_garden".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("RoyalGarden")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "RoyalGarden"
root:SetAttribute("LocationId", "royal_garden")
root.Parent = workspace

local BX, BZ = 5400, 0
local B = 4
local rng = Random.new(20261111)
local WHITE = Color3.fromRGB(236, 236, 240)
local WOOD = Color3.fromRGB(120, 85, 50)
local IRON = Color3.fromRGB(60, 60, 66)
local RED = Color3.fromRGB(200, 40, 34)
local ROYAL = Color3.fromRGB(40, 70, 170)
local GOLD = Color3.fromRGB(240, 190, 60)
local LAMP = Color3.fromRGB(255, 200, 130)

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or WHITE
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
-- daylight place: the few lamps stay soft [урок Пирамиды: десятки тёплых огней засвечивали всё]
local LIGHT_POWER, LIGHT_RANGE = 0.5, 0.7
local function light(p, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range * LIGHT_RANGE
	l.Brightness = brightness * LIGHT_POWER
	l.Color = color
	l.Shadows = false
	l.Parent = p
	return l
end
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end
local function cyl(name, height, diameter, cf, variant, tint, parent)
	local p = part(name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), tint, nil, parent)
	p.Shape = Enum.PartType.Cylinder
	if variant then
		textured(p, variant, tint)
	end
	return p
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 24)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 140
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
local function boardText(target, text, color, faces)
	for _, face in ipairs(faces or { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.MaxDistance = 90
		gui.LightInfluence = 0.6
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(255, 240, 210)
		label.TextStrokeTransparency = 0.5
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Text = text
		label.Parent = gui
	end
end
local function n2(x, z, seed, scale)
	return math.noise(x * scale, z * scale, seed)
end
local function segDist(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local t = math.clamp(((px - ax) * dx + (pz - az) * dz) / (dx * dx + dz * dz), 0, 1)
	return math.sqrt((px - ax - dx * t) ^ 2 + (pz - az - dz * t) ^ 2)
end
local function lineDist(pts, x, z)
	local best = math.huge
	for i = 1, #pts - 1 do
		best = math.min(best, segDist(x, z, pts[i][1], pts[i][2], pts[i + 1][1], pts[i + 1][2]))
	end
	return best
end
local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return e
end

-- ================================================================ the plan
local R = 290
local PIT = { x = 0, z = -40, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json royal_garden.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local YARD = { x = 0, z = 250, r = 34 }
local FOUNTAIN = { x = 0, z = 96, r = 26 }
local LISTS = { x = 0, z = -176, hx = 56, hz = 30 } -- the tournament field (arena)
local CASTLE_Z = -236 -- the front face of the castle wall
local POND = { x = 185, z = -30, rx = 40, rz = 22 } -- the koi pond
local MAZE = { x0 = 120, z0 = 112, n = 13, c = 8 } -- 13 × 13 cells of 8 studs
local TUNNEL = { x0 = -230, x1 = -64, z = 190, w = 10 } -- the wisteria tunnel
local POOLS = { { 22, 46, 140, 212 }, { -46, -22, 140, 212 } } -- reflecting pools beside the allée
local TRAILS = {
	{ { -16, 236 }, { -64, TUNNEL.z } },
	{ { TUNNEL.x0 + 6, TUNNEL.z }, { -200, 130 }, { -170, 60 } },
	{ { 16, 236 }, { 80, 196 }, { MAZE.x0 + 52, MAZE.z0 + MAZE.n * MAZE.c + 6 } },
	{ { -FOUNTAIN.r, FOUNTAIN.z }, { -110, 70 }, { -150, 40 } },
	{ { FOUNTAIN.r, FOUNTAIN.z }, { 100, 50 }, { 136, 4 } },
	{ { 0, FOUNTAIN.z - FOUNTAIN.r }, { 0, PIT.z + PIT.hole + 2 } },
	{ { 0, PIT.z - PIT.hole - 2 }, { 0, LISTS.z + LISTS.hz + 2 } },
	{ { -PIT.hole - 2, PIT.z }, { -110, -40 } },
	{ { PIT.hole + 2, PIT.z }, { 120, -40 } },
}
local function inAllee(x, z)
	return math.abs(x) < 12 and z > FOUNTAIN.z + FOUNTAIN.r - 4 and z < YARD.z
end
local function inPool(x, z)
	for _, p in ipairs(POOLS) do
		if x > p[1] and x < p[2] and z > p[3] and z < p[4] then
			return true
		end
	end
	return false
end
local function inPond(x, z)
	return ((x - POND.x) / POND.rx) ^ 2 + ((z - POND.z) / POND.rz) ^ 2 < 1 + n2(x, z, 4.4, 0.06) * 0.25
end

-- ================================================================ the terrain grid (8-stud cells)
local C = 8
local X0, Z0 = -320, -320
local NX, NZ = 80, 80
local function caveD(x, z)
	return math.sqrt((x / R) ^ 2 + (z / R) ^ 2) / (1 + n2(x, z, 2.7, 0.012) * 0.06)
end
local function onTrail(x, z)
	for _, t in ipairs(TRAILS) do
		if lineDist(t, x, z) < 4 + n2(x, z, 8.8, 0.15) then
			return true
		end
	end
	return false
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local function zone(x, z)
	if x < -100 and z > -120 and z < 150 then
		return "orchard"
	elseif x > 100 and z > -120 and z < 70 then
		return "japan"
	end
	return "garden"
end
local function flat(x, z)
	return math.sqrt((x - YARD.x) ^ 2 + (z - YARD.z) ^ 2) < YARD.r + 6
		or inAllee(x, z)
		or math.sqrt((x - FOUNTAIN.x) ^ 2 + (z - FOUNTAIN.z) ^ 2) < FOUNTAIN.r + 30
		or (math.abs(x - PIT.x) < PIT.hole + 16 and math.abs(z - PIT.z) < PIT.hole + 16)
		or (math.abs(x - LISTS.x) < LISTS.hx + 40 and z < LISTS.z + LISTS.hz + 12)
		or (x > MAZE.x0 - 12 and x < MAZE.x0 + MAZE.n * MAZE.c + 12 and z > MAZE.z0 - 12 and z < MAZE.z0 + MAZE.n * MAZE.c + 12)
		or (math.abs(z - TUNNEL.z) < TUNNEL.w and x > TUNNEL.x0 - 8 and x < TUNNEL.x1 + 8)
end
local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local d = caveD(x, z)
		local c = { x = x, z = z, d = d, zone = zone(x, z) }
		if d >= 1 then
			c.kind = "hill"
			local t = math.clamp((d - 1) / 0.14, 0, 1)
			c.top = math.max(8, 4 * math.floor((8 + 36 * t ^ 0.8 + n2(x, z, 4.4, 0.04) * 8) / 4))
		elseif inHole(x, z) then
			c.kind = "hole"
		elseif inPool(x, z) or (c.zone == "japan" and inPond(x, z)) then
			c.kind = "water"
		else
			c.kind = "ground"
			c.path = onTrail(x, z)
			local h = 0
			if not (flat(x, z) or c.path) then
				local hill = n2(x, z, 3.3, 0.03) * 2.2 + n2(x, z, 6.1, 0.09) * 0.8
				if c.zone == "orchard" then
					h = math.clamp(math.floor(hill + 1), 0, 3)
				elseif c.d > 0.85 then
					h = math.clamp(math.floor(hill + 0.5), 0, 1)
				end
			end
			c.top = h * B
		end
		cells[ix + iz * NX] = c
	end
end
local function cellAt(ix, iz)
	if ix < 0 or iz < 0 or ix >= NX or iz >= NZ then
		return nil
	end
	return cells[ix + iz * NX]
end
local function cellAtPos(x, z)
	return cellAt(math.floor((x - X0) / C), math.floor((z - Z0) / C))
end
local function floorAt(x, z)
	local c = cellAtPos(x, z)
	return if c and (c.kind == "ground" or c.kind == "hill") then c.top else 0
end

-- ================================================================ build the ground (runs merged along x)
local terrain = folder("Terrain")
local waterFolder = folder("Water")
local count = 0
local function floorLook(c)
	local formal = inAllee(c.x, c.z) or math.sqrt((c.x - FOUNTAIN.x) ^ 2 + (c.z - FOUNTAIN.z) ^ 2) < FOUNTAIN.r
	if formal or c.path then
		return "px_gravel", Color3.fromRGB(235, 222, 200)
	elseif math.sqrt((c.x - YARD.x) ^ 2 + (c.z - YARD.z) ^ 2) < YARD.r then
		return "px_gravel", Color3.fromRGB(215, 200, 180)
	elseif c.kind == "ground" and math.abs(c.x - LISTS.x) < LISTS.hx and math.abs(c.z - LISTS.z) < LISTS.hz then
		return "px_sand", Color3.fromRGB(240, 225, 195)
	end
	local v = n2(c.x, c.z, 7.7, 0.05)
	return "px_grass_top", if v > 0.3 then Color3.fromRGB(165, 210, 120) elseif v < -0.3 then Color3.fromRGB(130, 180, 100) else Color3.fromRGB(150, 196, 110)
end
for iz = 0, NZ - 1 do
	local z0, z1 = Z0 + iz * C, Z0 + (iz + 1) * C
	local runs = {}
	local function flushKey(k)
		local r = runs[k]
		if not r then
			return
		end
		local x0, x1 = X0 + r.ix0 * C, X0 + (r.ix1 + 1) * C
		local p = box(r.name, x0, r.y0, z0, x1, r.y1, z1, r.variant, r.tint, if r.water then waterFolder else terrain)
		if r.water then
			p.Transparency = 0.25
			p.CanCollide = false
			p.CastShadow = false
		end
		count += 1
		runs[k] = nil
	end
	local function push(ix, k, name, y0, y1, variant, tint, water)
		local r = runs[k]
		if r and r.ix1 == ix - 1 and r.y0 == y0 and r.y1 == y1 and r.variant == variant and r.tint == tint then
			r.ix1 = ix
			return
		end
		flushKey(k)
		runs[k] = { ix0 = ix, ix1 = ix, name = name, y0 = y0, y1 = y1, variant = variant, tint = tint, water = water }
	end
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		local used = {}
		if c.kind == "ground" or c.kind == "hill" then
			local v, tint = floorLook(c)
			push(ix, "body", "Ground", -8, c.top - 1, "px_dirt", nil)
			push(ix, "top", "GroundTop", c.top - 1, c.top, v, tint)
			used.body, used.top = true, true
		elseif c.kind == "water" then
			push(ix, "bed", "WaterBed", -8, -3, "px_gravel", Color3.fromRGB(150, 160, 150))
			push(ix, "water", "Water", -3, -0.6, "px_water", Color3.fromRGB(170, 220, 230), true)
			used.bed, used.water = true, true
		end
		for k in pairs(runs) do
			if not used[k] then
				flushKey(k)
			end
		end
	end
	for k in pairs(runs) do
		flushKey(k)
	end
	if iz % 5 == 0 then
		task.wait()
	end
end

-- ================================================================ small builders
local props = folder("Props")
local function hedgeBox(name, size, cf, parent)
	return textured(part(name, size, cf, nil, nil, parent or props), "px_hedge")
end
local function whiteStone(name, size, cf, parent)
	return textured(part(name, size, cf, nil, nil, parent or props), "px_white_stone_bricks")
end
-- a cherry tree: a leaning trunk, two or three branches, pink canopy blobs, petals on the grass
local function cherryTree(x, z, s)
	s = s or 1
	local y = floorAt(x, z)
	local h = rng:NextNumber(6, 9) * s
	local lean = rng:NextNumber(-0.15, 0.15)
	local yaw = rng:NextNumber(0, 6.28)
	local trunk = textured(part("CherryTrunk", Vector3.new(1.4 * s, h, 1.4 * s), at(x, y + h / 2, z) * CFrame.Angles(0, yaw, lean), nil, nil, props), "px_cherry_log")
	local top = trunk.CFrame * CFrame.new(0, h / 2, 0)
	for k = 1, rng:NextInteger(2, 3) do
		local a = k * 2.1 + rng:NextNumber(-0.4, 0.4)
		local len = rng:NextNumber(3, 5) * s
		textured(part("CherryBranch", Vector3.new(0.8 * s, 0.8 * s, len), top * CFrame.new(0, -1 * s, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0.7, 0, 0) * CFrame.new(0, 0, -len / 2), nil, nil, props), "px_cherry_log")
	end
	for _ = 1, rng:NextInteger(4, 6) do
		local w = rng:NextNumber(5, 8) * s
		textured(part("CherryBlossom", Vector3.new(w, w * 0.6, w), top * CFrame.new(rng:NextNumber(-3, 3) * s, rng:NextNumber(0, 2.5) * s, rng:NextNumber(-3, 3) * s) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, props), "px_cherry_leaves", Color3.fromRGB(255, 240, 245))
	end
	for _ = 1, 4 do
		local px, pz = x + rng:NextNumber(-5, 5) * s, z + rng:NextNumber(-5, 5) * s
		decor(part("Petals", Vector3.new(rng:NextNumber(1.5, 3), 0.05, rng:NextNumber(1.5, 3)), at(px, floorAt(px, pz) + 0.03, pz) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(250, 190, 210), nil, props))
	end
	return top
end
-- a green tree for the hills round the garden
local function oakTree(x, z)
	local y = floorAt(x, z)
	local h = rng:NextNumber(8, 13)
	textured(part("OakTrunk", Vector3.new(1.6, h, 1.6), at(x, y + h / 2, z), nil, nil, props), "px_oak_log")
	for _ = 1, 4 do
		local w = rng:NextNumber(6, 10)
		textured(part("OakLeaves", Vector3.new(w, w * 0.7, w), at(x + rng:NextNumber(-3, 3), y + h + rng:NextNumber(-1, 2), z + rng:NextNumber(-3, 3)), nil, nil, props), "px_hedge", Color3.fromRGB(200, 230, 180))
	end
end
-- clipped topiaries: a cone of shrinking boxes, or a ball on a pot
local function topiaryCone(x, z, h)
	local y = floorAt(x, z)
	whiteStone("TopiaryPot", Vector3.new(2.6, 1.4, 2.6), at(x, y + 0.7, z))
	local k = 0
	local seg = h / 4
	while k < 4 do
		local w = 3 * (1 - k / 4.4)
		hedgeBox("TopiaryCone", Vector3.new(w, seg, w), at(x, y + 1.4 + seg * (k + 0.5), z))
		k += 1
	end
end
local function topiaryBall(x, z, d)
	local y = floorAt(x, z)
	whiteStone("TopiaryPot", Vector3.new(2.4, 1.6, 2.4), at(x, y + 0.8, z))
	local ball = part("TopiaryBall", Vector3.new(d, d, d), at(x, y + 1.6 + d / 2, z), nil, nil, props)
	ball.Shape = Enum.PartType.Ball
	textured(ball, "px_hedge")
end
local function lamp(x, z, h, parent)
	local y = floorAt(x, z)
	part("LampPost", Vector3.new(0.5, h, 0.5), at(x, y + h / 2, z), IRON, Enum.Material.Metal, parent or props)
	part("LampCap", Vector3.new(1.4, 0.4, 1.4), at(x, y + h + 1.1, z), IRON, Enum.Material.Metal, parent or props)
	local l = decor(part("Lamp", Vector3.new(1, 1.4, 1), at(x, y + h + 0.3, z), LAMP, Enum.Material.Neon, parent or props))
	light(l, 22, 1.2, LAMP)
end
local function flowerBed(x0, z0, x1, z1, colors)
	local y = floorAt((x0 + x1) / 2, (z0 + z1) / 2)
	textured(part("FlowerBed", Vector3.new(x1 - x0, 0.4, z1 - z0), at((x0 + x1) / 2, y + 0.2, (z0 + z1) / 2), nil, nil, props), "px_dirt")
	for x = x0 + 0.8, x1 - 0.8, 1.6 do
		for z = z0 + 0.8, z1 - 0.8, 1.6 do
			if rng:NextNumber() < 0.75 then
				local col = colors[rng:NextInteger(1, #colors)]
				decor(part("Flower", Vector3.new(0.9, 0.9, 0.9), at(x + rng:NextNumber(-0.3, 0.3), y + 0.8, z + rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), col, nil, props))
			end
		end
	end
end
local FLOWERS_WARM = { Color3.fromRGB(230, 60, 70), Color3.fromRGB(250, 200, 60), Color3.fromRGB(250, 140, 170), Color3.fromRGB(255, 250, 240) }
local FLOWERS_COOL = { Color3.fromRGB(120, 110, 230), Color3.fromRGB(250, 250, 255), Color3.fromRGB(190, 130, 230), Color3.fromRGB(250, 170, 200) }
local function zoneSign(x, z, text, yaw)
	local y = floorAt(x, z)
	part("SignPost", Vector3.new(0.6, 5, 0.6), at(x, y + 2.5, z), WOOD, Enum.Material.Wood, props)
	local board = textured(part("ZoneSign", Vector3.new(7, 1.8, 0.4), at(x, y + 4.6, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, props), "px_cherry_planks")
	boardText(board, text, Color3.fromRGB(90, 40, 40))
end
-- a gazebo: a white platform, six columns, a blue stepped dome with a gold finial
local function gazebo(x, z, r, parent)
	local y = floorAt(x, z)
	cyl("GazeboFloor", 1, r * 2 + 2, at(x, y + 0.5, z), "px_white_stone_bricks", nil, parent)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		cyl("GazeboColumn", 9, 1, at(x + math.cos(a) * r, y + 5.5, z + math.sin(a) * r), "px_white_stone_bricks", nil, parent)
	end
	for k = 0, 3 do
		cyl("GazeboRoof", 1.4, (r + 1.5) * 2 * (1 - k * 0.24), at(x, y + 10.7 + k * 1.4, z), nil, Color3.fromRGB(78, 112, 200), parent)
	end
	part("GazeboFinial", Vector3.new(0.8, 2.4, 0.8), at(x, y + 17, z), GOLD, Enum.Material.Metal, parent or props)
end

-- ================================================================ the yard of the gardeners (arrival)
local yard = folder("Yard")
do
	local ox, oz = YARD.x, YARD.z
	local spawn = part("LocationSpawn_royal_garden", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + ox, 0.5, BZ + oz - 12), Vector3.new(BX + ox, 0.5, BZ + FOUNTAIN.z)), nil, nil, yard)
	textured(spawn, "px_white_stone_bricks")
	spawn:SetAttribute("LocationId", "royal_garden")
	CollectionService:AddTag(spawn, "LocationSpawn")
	-- the orangery: a glass house on a white base with a pitched glass roof
	do
		local gx, gz, W, D, H = ox - 22, oz + 10, 16, 12, 8
		whiteStone("OrangeryBase", Vector3.new(W, 1.2, D), at(gx, 0.6, gz), yard)
		for _, s in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local size = if s[1] ~= 0 then Vector3.new(0.3, H, D) else Vector3.new(W, H, 0.3)
			local glass = part("OrangeryGlass", size, at(gx + s[1] * W / 2, 1.2 + H / 2, gz + s[2] * D / 2), Color3.fromRGB(200, 230, 230), Enum.Material.Glass, yard)
			glass.Transparency = 0.6
		end
		for k = -W / 2, W / 2, 4 do
			part("OrangeryFrame", Vector3.new(0.4, H, 0.4), at(gx + k, 1.2 + H / 2, gz - D / 2), WHITE, nil, yard)
			part("OrangeryFrame", Vector3.new(0.4, H, 0.4), at(gx + k, 1.2 + H / 2, gz + D / 2), WHITE, nil, yard)
		end
		for _, s in ipairs({ -1, 1 }) do
			local roof = part("OrangeryRoof", Vector3.new(W + 0.6, 0.3, D / 2 + 1.4), at(gx, 1.2 + H + 1.7, gz + s * D / 4) * CFrame.Angles(s * 0.55, 0, 0), Color3.fromRGB(200, 230, 230), Enum.Material.Glass, yard)
			roof.Transparency = 0.5
		end
		for _ = 1, 8 do
			cherryTree(gx + rng:NextNumber(-5, 5), gz + rng:NextNumber(-3, 3), 0.35)
		end
	end
	-- the block buyer under a pink striped awning
	do
		local sx, sz = ox + 20, oz - 6
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(230, 190, 160)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(70, 110, 60), Color3.fromRGB(90, 70, 50), Color3.fromRGB(90, 70, 50)
		local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		model.Name = "GardenBuyer"
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
		model.Parent = yard
		model:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + ox, 3, BZ + oz)))
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hrp = model:FindFirstChild("HumanoidRootPart")
		CollectionService:AddTag(hrp, "SellPoint")
		sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
		local hat = part("StrawHat", Vector3.new(2.8, 0.25, 2.8), model.Head.CFrame * CFrame.new(0, 0.65, 0), Color3.fromRGB(220, 190, 110), Enum.Material.Fabric, model)
		hat.CanCollide = false
		textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), nil, nil, yard), "px_cherry_planks")
		for _, dz in ipairs({ -4.4, 4.4 }) do
			for _, dx in ipairs({ -1.2, 5 }) do
				textured(part("StallPost", Vector3.new(0.6, 9, 0.6), at(sx + dx, 4.5, sz + dz), nil, nil, yard), "px_cherry_log")
			end
		end
		for k = 0, 5 do
			decor(part("Awning", Vector3.new(7.4, 0.15, 1.6), at(sx + 1.9, 9.1 - k * 0.12, sz - 4.5 + k * 1.6 + 0.8) * CFrame.Angles(0, 0, -0.15), if k % 2 == 0 then Color3.fromRGB(240, 150, 180) else WHITE, Enum.Material.Fabric, yard))
		end
		for _, c in ipairs({ { -0.3, -2.5, "px_wisteria_leaves" }, { -0.3, 2.5, "px_cherry_log" } }) do
			local crate = textured(part("Crate", Vector3.new(1.8, 1.8, 1.8), at(sx + c[1], 3.9, sz + c[2]), nil, nil, yard), "px_planks")
			textured(decor(part("CrateLoad", Vector3.new(1.4, 0.3, 1.4), crate.CFrame * CFrame.new(0, 0.9, 0), nil, nil, yard)), c[3])
		end
	end
	-- wheelbarrows, flower crates, a tool rack, the signpost
	for _, w in ipairs({ { ox - 8, oz + 22, 0.5 }, { ox + 10, oz + 20, -0.8 } }) do
		local base = at(w[1], 0, w[2]) * CFrame.Angles(0, w[3], 0)
		part("Barrow", Vector3.new(2.4, 1.2, 3.4), base * CFrame.new(0, 1.4, 0) * CFrame.Angles(0.15, 0, 0), WOOD, Enum.Material.Wood, yard)
		decor(part("BarrowSoil", Vector3.new(2, 0.3, 3), base * CFrame.new(0, 2, 0), Color3.fromRGB(90, 60, 40), nil, yard))
		local wheel = part("BarrowWheel", Vector3.new(0.4, 1.4, 1.4), base * CFrame.new(0, 0.7, -2.2) * CFrame.Angles(0, 0, math.pi / 2), IRON, nil, yard)
		wheel.Shape = Enum.PartType.Cylinder
	end
	for k = 0, 3 do
		flowerBed(ox - 30 + k * 4.5, oz - 22, ox - 27 + k * 4.5, oz - 18, if k % 2 == 0 then FLOWERS_WARM else FLOWERS_COOL)
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.5
		lamp(ox + math.cos(a) * (YARD.r - 4), oz + math.sin(a) * (YARD.r - 4), 6, yard)
	end
	local sx, sz = ox + 6, oz - 24
	part("SignPost", Vector3.new(0.6, 7, 0.6), at(sx, 3.5, sz), WOOD, Enum.Material.Wood, yard)
	local toMine = textured(part("Signboard", Vector3.new(5, 1, 0.3), at(sx, 5.8, sz) * CFrame.Angles(0, math.atan2(PIT.x - sx, PIT.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), nil, nil, yard), "px_cherry_planks")
	boardText(toMine, "Шахта", Color3.fromRGB(90, 40, 40))
	local toLists = textured(part("Signboard", Vector3.new(5, 1, 0.3), at(sx, 4.6, sz) * CFrame.Angles(0, math.atan2(LISTS.x - sx + 30, LISTS.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), nil, nil, yard), "px_cherry_planks")
	boardText(toLists, "Ристалище", Color3.fromRGB(90, 40, 40))
end
task.wait()

-- ================================================================ the allée, the reflecting pools, the parterres and the great fountain
local formal = folder("Formal")
do
	-- topiary cones and cherries alternate along the allée
	local k = 0
	for z = YARD.z - YARD.r - 4, FOUNTAIN.z + FOUNTAIN.r + 8, -10 do
		for _, s in ipairs({ -1, 1 }) do
			if k % 2 == 0 then
				topiaryCone(s * 15, z, 7)
			else
				cherryTree(s * 15, z, 0.85)
			end
		end
		k += 1
	end
	-- the reflecting pools: white stone kerbs, a small jet at each end
	for _, p in ipairs(POOLS) do
		local x0, x1, z0, z1 = p[1], p[2], p[3], p[4]
		for _, side in ipairs({ { x0, (z0 + z1) / 2, 1, z1 - z0 }, { x1, (z0 + z1) / 2, 1, z1 - z0 } }) do
			whiteStone("PoolKerb", Vector3.new(1.2, 1, side[4] + 1.2), at(side[1], 0.5, side[2]), formal)
		end
		for _, z in ipairs({ z0, z1 }) do
			whiteStone("PoolKerb", Vector3.new(x1 - x0 + 1.2, 1, 1.2), at((x0 + x1) / 2, 0.5, z), formal)
		end
		for _, z in ipairs({ z0 + 6, z1 - 6 }) do
			local jet = decor(part("PoolJet", Vector3.new(0.6, 0.6, 0.6), at((x0 + x1) / 2, -0.4, z), Color3.fromRGB(210, 240, 255), Enum.Material.Glass, formal))
			emitter(jet, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
				Size = NumberSequence.new(0.35),
				Transparency = NumberSequence.new(0.2),
				Rate = 30,
				Lifetime = NumberRange.new(0.9, 1.2),
				Speed = NumberRange.new(10, 12),
				SpreadAngle = Vector2.new(4, 4),
				Acceleration = Vector3.new(0, -24, 0),
			})
		end
	end
	-- embroidered parterres: four squares round the fountain, hedge borders, a hedge circle, flowers inside
	for _, q in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local cx, cz = FOUNTAIN.x + q[1] * 46, FOUNTAIN.z + q[2] * 36
		local hx, hz = 16, 12
		for _, e in ipairs({ { 0, -hz, hx * 2, 1 }, { 0, hz, hx * 2, 1 }, { -hx, 0, 1, hz * 2 }, { hx, 0, 1, hz * 2 } }) do
			hedgeBox("ParterreHedge", Vector3.new(e[3], 1.6, e[4]), at(cx + e[1], 0.8, cz + e[2]), formal)
		end
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			hedgeBox("ParterreCircle", Vector3.new(1, 1.4, 2.8), at(cx + math.cos(a) * 7, 0.7, cz + math.sin(a) * 7) * CFrame.Angles(0, -a, 0), formal)
		end
		flowerBed(cx - hx + 1.5, cz - hz + 1.5, cx - 8, cz + hz - 1.5, FLOWERS_WARM)
		flowerBed(cx + 8, cz - hz + 1.5, cx + hx - 1.5, cz + hz - 1.5, FLOWERS_WARM)
		flowerBed(cx - 4, cz - 4, cx + 4, cz + 4, FLOWERS_COOL)
		topiaryBall(cx - hx, cz - hz, 3)
		topiaryBall(cx + hx, cz - hz, 3)
		topiaryBall(cx - hx, cz + hz, 3)
		topiaryBall(cx + hx, cz + hz, 3)
	end
	-- the three-tier fountain: a wide basin, a pedestal, two bowls, a gold finial, jets and splashes
	do
		local fx, fz = FOUNTAIN.x, FOUNTAIN.z
		cyl("FountainRim", 1.6, 30, at(fx, 0.8, fz), "px_white_stone_bricks", nil, formal)
		local water = cyl("FountainWater", 0.4, 28, at(fx, 1.4, fz), "px_water", Color3.fromRGB(170, 220, 235), formal)
		water.Transparency = 0.2
		decor(water)
		cyl("FountainPedestal", 6, 4, at(fx, 4, fz), "px_white_stone_bricks", nil, formal)
		cyl("FountainBowl", 1.2, 14, at(fx, 7.4, fz), "px_white_stone_bricks", nil, formal)
		decor(cyl("FountainBowlWater", 0.3, 12.4, at(fx, 8.05, fz), "px_water", Color3.fromRGB(170, 220, 235), formal)).Transparency = 0.2
		cyl("FountainStem", 4, 2, at(fx, 10, fz), "px_white_stone_bricks", nil, formal)
		cyl("FountainTopBowl", 1, 7, at(fx, 12.4, fz), "px_white_stone_bricks", nil, formal)
		local finial = part("FountainFinial", Vector3.new(1.2, 2.4, 1.2), at(fx, 14.1, fz), GOLD, Enum.Material.Metal, formal)
		emitter(finial, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
			Size = NumberSequence.new(0.5),
			Transparency = NumberSequence.new(0.15),
			Rate = 60,
			Lifetime = NumberRange.new(1.2, 1.6),
			Speed = NumberRange.new(12, 15),
			SpreadAngle = Vector2.new(14, 14),
			Acceleration = Vector3.new(0, -26, 0),
		})
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local jet = decor(part("FountainJet", Vector3.new(0.4, 0.4, 0.4), at(fx + math.cos(a) * 12, 1.6, fz + math.sin(a) * 12), WHITE, Enum.Material.Glass, formal))
			jet.Transparency = 1
			emitter(jet, {
				Texture = "rbxasset://textures/particles/sparkles_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(220, 240, 255)),
				Size = NumberSequence.new(0.3),
				Transparency = NumberSequence.new(0.25),
				Rate = 25,
				Lifetime = NumberRange.new(0.8, 1),
				Speed = NumberRange.new(9, 10),
				EmissionDirection = Enum.NormalId.Top,
				SpreadAngle = Vector2.new(3, 3),
				Acceleration = Vector3.new(-math.cos(a) * 9, -22, -math.sin(a) * 9),
			})
		end
		-- four statues of knights round the fountain (white stone, blocky, sword point down)
		for k = 0, 3 do
			local a = k / 4 * math.pi * 2 + math.pi / 4
			local x, z = fx + math.cos(a) * 21, fz + math.sin(a) * 21
			local base = CFrame.lookAt(Vector3.new(BX + x, 0, BZ + z), Vector3.new(BX + fx, 0, BZ + fz))
			local function b(name, size, off)
				whiteStone(name, size, base * CFrame.new(off[1], off[2], off[3]), formal)
			end
			b("StatuePlinth", Vector3.new(4, 3, 4), { 0, 1.5, 0 })
			b("StatueLegs", Vector3.new(1.8, 3, 1), { 0, 4.5, 0 })
			b("StatueBody", Vector3.new(2.2, 2.6, 1.2), { 0, 7.3, 0 })
			b("StatueHelm", Vector3.new(1.4, 1.6, 1.4), { 0, 9.4, 0 })
			b("StatueArms", Vector3.new(3, 0.8, 1), { 0, 7.6, -0.6 })
			b("StatueSword", Vector3.new(0.4, 4.6, 0.2), { 0, 5, -1.3 })
			b("StatueGuard", Vector3.new(1.6, 0.3, 0.3), { 0, 7.2, -1.3 })
			b("StatueShield", Vector3.new(0.3, 2.4, 1.8), { -1.4, 6.8, 0 })
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		for z = FOUNTAIN.z + FOUNTAIN.r + 14, YARD.z - YARD.r - 4, 28 do
			lamp(s * 9.5, z, 6, formal)
		end
	end
end
task.wait()

-- ================================================================ the sunken garden round the mine
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	local function bedrock(p)
		textured(p, "px_dirt", Color3.fromRGB(150, 130, 110))
	end
	bedrock(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(mx, -h - B / 2, mz), nil, nil, mine))
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(mx - w / 2 - B, -h / 2, mz) },
		{ Vector3.new(2 * B, h, w), at(mx + w / 2 + B, -h / 2, mz) },
	}) do
		bedrock(part("PitWall", wall[1], wall[2], nil, nil, mine))
	end
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], nil, nil, mine), "px_white_stone_bricks")
	end
	-- a white balustrade with gaps in the middle of each side; wisteria arches over the gaps
	for _, s in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			local a, b = 8, edge - 2
			whiteStone("Balustrade", Vector3.new(b - a, 2.2, 0.8), at(mx + half * (a + b) / 2, 1.7, mz + s * edge), mine)
			whiteStone("Balustrade", Vector3.new(0.8, 2.2, b - a), at(mx + s * edge, 1.7, mz + half * (a + b) / 2), mine)
		end
	end
	local function wisteriaArch(x, z, alongX)
		local side = if alongX then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
		for _, s in ipairs({ -1, 1 }) do
			local p = Vector3.new(x, 0, z) + side * s * 7
			whiteStone("ArchPost", Vector3.new(1.2, 10, 1.2), at(p.X, 5, p.Z), mine)
		end
		local beam = if alongX then Vector3.new(16, 1, 1.6) else Vector3.new(1.6, 1, 16)
		textured(part("ArchBeam", beam, at(x, 10.4, z), nil, nil, mine), "px_cherry_log")
		textured(part("ArchLeaves", beam + Vector3.new(2, 1.4, 2), at(x, 11.6, z), nil, nil, mine), "px_wisteria_leaves")
		for k = -6, 6, 2 do
			local p = Vector3.new(x, 0, z) + side * k
			local len = rng:NextNumber(2, 5)
			for j = 0, 2 do
				local wj = 1.4 - j * 0.4
				textured(decor(part("WisteriaCluster", Vector3.new(wj, len / 3, wj), at(p.X + rng:NextNumber(-0.3, 0.3), 10 - len / 6 - j * len / 3, p.Z + rng:NextNumber(-0.3, 0.3)), nil, nil, mine)), "px_wisteria_leaves", if j == 2 then Color3.fromRGB(255, 230, 255) else nil)
			end
		end
	end
	wisteriaArch(mx, mz + edge, true)
	wisteriaArch(mx, mz - edge, true)
	wisteriaArch(mx + edge, mz, false)
	wisteriaArch(mx - edge, mz, false)
	-- four gazebos at the corners, flower beds along the rim
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		gazebo(mx + s[1] * (edge + 9), mz + s[2] * (edge + 9), 4.5, mine)
	end
	for _, s in ipairs({ -1, 1 }) do
		flowerBed(mx + s * (edge + 3) - 2, mz - 50, mx + s * (edge + 3) + 2, mz - 12, FLOWERS_COOL)
		flowerBed(mx + s * (edge + 3) - 2, mz + 12, mx + s * (edge + 3) + 2, mz + 50, FLOWERS_WARM)
	end
	local anchor = part("MineAnchor_royal_garden", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), nil, nil, mine)
	anchor:SetAttribute("LocationId", "royal_garden")
	anchor:SetAttribute("MineId", "royal_garden")
	anchor:SetAttribute("Size", Vector3.new(PIT.size, PIT.depth, PIT.size))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, "Шахта", 14)
	local LADDER_W = 4 * B
	for _, side in ipairs({
		{ mx, mz - w / 2, Vector3.new(0, 0, 1) },
		{ mx, mz + w / 2, Vector3.new(0, 0, -1) },
		{ mx - w / 2, mz, Vector3.new(1, 0, 0) },
		{ mx + w / 2, mz, Vector3.new(-1, 0, 0) },
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
			truss.Parent = mine
		end
		local plate = Instance.new("Part")
		plate.Name = "LadderFace"
		plate.Size = Vector3.new(LADDER_W * along.X + 0.2 * math.abs(inward.X), h, LADDER_W * along.Z + 0.2 * math.abs(inward.Z))
		plate.CFrame = CFrame.new(base + inward * 0.15)
		plate.Anchored = true
		plate.CanCollide = false
		plate.CanQuery = false
		plate.Transparency = 1
		plate.Parent = mine
		if TEX.ladder then
			local tex = Instance.new("Texture")
			tex.Texture = TEX.ladder
			tex.Face = if inward.Z > 0 then Enum.NormalId.Back elseif inward.Z < 0 then Enum.NormalId.Front elseif inward.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end
end
task.wait()

-- ================================================================ the wisteria tunnel
local tunnel = folder("WisteriaTunnel")
do
	local t = TUNNEL
	for x = t.x0, t.x1, 8 do
		for _, s in ipairs({ -1, 1 }) do
			textured(part("TunnelPost", Vector3.new(1, 9, 1), at(x, 4.5, t.z + s * t.w / 2), nil, nil, tunnel), "px_cherry_log")
		end
		textured(part("TunnelBeam", Vector3.new(1, 1, t.w + 2), at(x, 9.4, t.z), nil, nil, tunnel), "px_cherry_log")
	end
	for _, s in ipairs({ -1, 1 }) do
		textured(part("TunnelRail", Vector3.new(t.x1 - t.x0, 1, 1), at((t.x0 + t.x1) / 2, 9.4, t.z + s * t.w / 2), nil, nil, tunnel), "px_cherry_log")
		-- leafy walls of wisteria on the sides, thinning to the bottom
		textured(part("TunnelSide", Vector3.new(t.x1 - t.x0, 3, 1.4), at((t.x0 + t.x1) / 2, 8.4, t.z + s * (t.w / 2 + 0.4)), nil, nil, tunnel), "px_wisteria_leaves")
	end
	textured(part("TunnelRoof", Vector3.new(t.x1 - t.x0 + 2, 1.6, t.w + 4), at((t.x0 + t.x1) / 2, 10.6, t.z), nil, nil, tunnel), "px_wisteria_leaves")
	-- the hanging racemes: three shrinking boxes each, violet, pink and white
	local tints = { nil, Color3.fromRGB(255, 220, 240), Color3.fromRGB(220, 200, 255) }
	for x = t.x0 + 2, t.x1 - 2, 3 do
		for _, dz in ipairs({ -3.6, -1, 1.6, 3.8 }) do
			if rng:NextNumber() < 0.8 then
				local len = rng:NextNumber(2.4, 5.5)
				local tint = tints[rng:NextInteger(1, 3)]
				for j = 0, 2 do
					local wj = 1.4 - j * 0.42
					textured(decor(part("Raceme", Vector3.new(wj, len / 3, wj), at(x + rng:NextNumber(-0.4, 0.4), 9.6 - len / 6 - j * len / 3, t.z + dz), nil, nil, tunnel)), "px_wisteria_leaves", tint)
				end
			end
		end
	end
	-- lanterns and benches inside, petals on the ground
	for x = t.x0 + 12, t.x1 - 12, 32 do
		local l = decor(part("TunnelLantern", Vector3.new(0.9, 1.2, 0.9), at(x, 7.6, t.z), LAMP, Enum.Material.Neon, tunnel))
		light(l, 22, 1.2, LAMP)
		textured(part("Bench", Vector3.new(4, 0.5, 1.2), at(x + 6, 1.2, t.z + t.w / 2 - 1.4), nil, nil, tunnel), "px_cherry_planks")
	end
	for x = t.x0, t.x1, 6 do
		decor(part("TunnelPetals", Vector3.new(4, 0.05, 3), at(x + rng:NextNumber(-1, 1), 0.04, t.z + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(220, 170, 230), nil, tunnel))
	end
	zoneSign(t.x1 + 6, t.z - 8, "Глициниевый тоннель", math.pi / 2)
end
task.wait()

-- ================================================================ the cherry orchard on the hills (the gardeners at work)
local orchard = folder("Orchard")
do
	local trees = {}
	for x = -250, -112, 14 do
		for z = -104, 140, 14 do
			local px, pz = x + rng:NextNumber(-3, 3), z + rng:NextNumber(-3, 3)
			local c = cellAtPos(px, pz)
			if c and c.kind == "ground" and not c.path and rng:NextNumber() < 0.85 then
				cherryTree(px, pz, rng:NextNumber(0.9, 1.25))
				table.insert(trees, { px, pz })
			end
		end
	end
	-- ladders against some trees, baskets of cherries under them, crates and a cart
	for i, tr in ipairs(trees) do
		if i % 5 == 0 then
			local y = floorAt(tr[1], tr[2])
			local base = at(tr[1] + 1.6, y, tr[2]) * CFrame.Angles(0, 0, -0.25)
			for _, s in ipairs({ -0.5, 0.5 }) do
				part("LadderRail", Vector3.new(0.25, 7, 0.25), base * CFrame.new(0, 3.5, s), WOOD, Enum.Material.Wood, orchard)
			end
			for k = 1, 6 do
				part("LadderRung", Vector3.new(0.2, 0.2, 1.1), base * CFrame.new(0, k, 0), WOOD, Enum.Material.Wood, orchard)
			end
		end
		if i % 3 == 0 then
			local y = floorAt(tr[1], tr[2])
			local bx, bz = tr[1] - 2, tr[2] + 1.5
			local basket = part("Basket", Vector3.new(1.8, 1.2, 1.8), at(bx, y + 0.6, bz), Color3.fromRGB(170, 130, 80), Enum.Material.Fabric, orchard)
			_ = basket
			for _ = 1, 5 do
				local cherry = decor(part("Cherry", Vector3.new(0.45, 0.45, 0.45), at(bx + rng:NextNumber(-0.5, 0.5), y + 1.3, bz + rng:NextNumber(-0.5, 0.5)), Color3.fromRGB(180, 20, 40), nil, orchard))
				cherry.Shape = Enum.PartType.Ball
			end
		end
	end
	do
		local x, z = -150, 30
		local y = floorAt(x, z)
		local base = at(x, y, z) * CFrame.Angles(0, 0.4, 0)
		textured(part("CartBed", Vector3.new(4, 0.6, 7), base * CFrame.new(0, 2, 0), nil, nil, orchard), "px_cherry_planks")
		for _, s in ipairs({ -1, 1 }) do
			textured(part("CartSide", Vector3.new(0.3, 1.2, 7), base * CFrame.new(s * 2, 2.8, 0), nil, nil, orchard), "px_cherry_planks")
			local wheel = part("CartWheel", Vector3.new(0.4, 3, 3), base * CFrame.new(s * 2.3, 1.5, 0) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood, orchard)
			wheel.Shape = Enum.PartType.Cylinder
		end
		for _ = 1, 4 do
			local basket = part("Basket", Vector3.new(1.6, 1.1, 1.6), base * CFrame.new(rng:NextNumber(-1, 1), 2.9, rng:NextNumber(-2.5, 2.5)), Color3.fromRGB(170, 130, 80), Enum.Material.Fabric, orchard)
			decor(part("BasketCherries", Vector3.new(1.3, 0.3, 1.3), basket.CFrame * CFrame.new(0, 0.6, 0), Color3.fromRGB(180, 20, 40), nil, orchard))
		end
	end
	zoneSign(-108, 64, "Вишнёвый сад", math.pi / 2)
end
task.wait()

-- ================================================================ the Japanese garden: koi pond, arched bridge, lanterns, tea house
local japan = folder("JapaneseGarden")
-- the measured gap of the pond under the bridge (the same lesson as every bridge: span the real water)
local function gapEdges(bx, bz, halfW)
	local function wet(z)
		for _, dx in ipairs({ -halfW, 0, halfW }) do
			local c = cellAtPos(bx + dx, z)
			if c and c.kind == "water" then
				return true
			end
		end
		return false
	end
	local zS, zN = bz, bz
	while wet(zS - 0.5) do
		zS -= 1
	end
	while wet(zN + 0.5) do
		zN += 1
	end
	return zS, zN
end
local bridgeSpan
do
	-- the red arched bridge across the pond along z: the deck follows a sine arch from bank to bank
	local bx = POND.x
	local zS, zN = gapEdges(bx, POND.z, 3)
	bridgeSpan = { zS, zN }
	local z0, z1 = zS - 3, zN + 3
	local L = z1 - z0
	local rise = math.min(7, L * 0.22)
	local function deckY(z)
		return rise * math.sin(math.pi * (z - z0) / L)
	end
	for z = z0, z1 - 1 do
		local ya, yb = deckY(z), deckY(z + 1)
		local mid = (ya + yb) / 2
		local ang = math.atan2(yb - ya, 1)
		textured(part("BridgeDeck", Vector3.new(5, 0.6, 1.05), at(bx, mid + 0.2, z + 0.5) * CFrame.Angles(-ang, 0, 0), nil, nil, japan), "px_cherry_planks", Color3.fromRGB(255, 200, 190))
		textured(part("BridgeBeam", Vector3.new(5.4, 0.8, 1.05), at(bx, mid - 0.5, z + 0.5) * CFrame.Angles(-ang, 0, 0), nil, nil, japan), "px_cherry_planks", Color3.fromRGB(230, 90, 80))
		if z % 2 == 0 then
			for _, s in ipairs({ -1, 1 }) do
				part("BridgePost", Vector3.new(0.4, 2.6, 0.4), at(bx + s * 2.6, mid + 1.5, z + 0.5), RED, nil, japan)
			end
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		for z = z0, z1 - 2, 2 do
			local ya, yb = deckY(z), deckY(z + 2)
			local ang = math.atan2(yb - ya, 2)
			part("BridgeRail", Vector3.new(0.35, 0.35, 2.1), at(bx + s * 2.6, (ya + yb) / 2 + 2.7, z + 1) * CFrame.Angles(-ang, 0, 0), RED, nil, japan)
		end
		-- the gold knobs (giboshi) on the end posts
		for _, z in ipairs({ z0 + 0.5, z1 - 0.5 }) do
			part("BridgeEndPost", Vector3.new(0.7, 3.4, 0.7), at(bx + s * 2.6, 1.7, z), RED, nil, japan)
			local knob = part("Giboshi", Vector3.new(0.9, 0.9, 0.9), at(bx + s * 2.6, 3.8, z), GOLD, Enum.Material.Metal, japan)
			knob.Shape = Enum.PartType.Ball
		end
	end
	-- the pond: rocks round the edge, koi under the water, lily pads
	for iz = 0, NZ - 1 do
		for ix = 0, NX - 1 do
			local c = cellAt(ix, iz)
			if c.kind == "ground" and c.zone == "japan" then
				for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
					local n = cellAt(ix + d[1], iz + d[2])
					if n and n.kind == "water" and rng:NextNumber() < 0.6 and math.abs(c.x - bx) > 6 then
						local s = rng:NextNumber(1.6, 3.2)
						part("PondRock", Vector3.new(s, s * 0.7, s), at(c.x + d[1] * 3.4, s * 0.25, c.z + d[2] * 3.4) * CFrame.Angles(0, rng:NextNumber(0, 2), 0.1), Color3.fromRGB(130, 130, 125), Enum.Material.Slate, japan)
					end
				end
			end
		end
	end
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0.2, 0.75)
		local x, z = POND.x + math.cos(a) * POND.rx * r, POND.z + math.sin(a) * POND.rz * r
		local c = cellAtPos(x, z)
		if c and c.kind == "water" then
			local koi = decor(part("Koi", Vector3.new(0.7, 0.4, 2), at(x, -1.8, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(250, 245, 240), nil, japan))
			decor(part("KoiSpot", Vector3.new(0.72, 0.42, 0.7), koi.CFrame * CFrame.new(0, 0, -0.3), Color3.fromRGB(220, 40, 30), nil, japan))
		end
		local lx, lz = POND.x + math.cos(a + 1) * POND.rx * r * 0.9, POND.z + math.sin(a + 1) * POND.rz * r * 0.9
		local lc = cellAtPos(lx, lz)
		if lc and lc.kind == "water" and math.abs(lx - bx) > 4 then
			local pad = decor(part("LilyPad", Vector3.new(0.1, 2, 2), at(lx, -0.55, lz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(70, 140, 60), nil, japan))
			pad.Shape = Enum.PartType.Cylinder
		end
	end
	-- stone lanterns (tōrō): a base, a post, the light box, a wide roof, a knob
	local function toro(x, z)
		local y = floorAt(x, z)
		local stone = Color3.fromRGB(150, 150, 145)
		part("ToroBase", Vector3.new(2.4, 0.8, 2.4), at(x, y + 0.4, z), stone, Enum.Material.Slate, japan)
		part("ToroPost", Vector3.new(1, 3, 1), at(x, y + 2.3, z), stone, Enum.Material.Slate, japan)
		part("ToroPlatform", Vector3.new(2, 0.5, 2), at(x, y + 4, z), stone, Enum.Material.Slate, japan)
		local box_ = part("ToroBox", Vector3.new(1.5, 1.4, 1.5), at(x, y + 4.95, z), stone, Enum.Material.Slate, japan)
		local glow = decor(part("ToroLight", Vector3.new(1.1, 0.9, 1.6), box_.CFrame, LAMP, Enum.Material.Neon, japan))
		light(glow, 18, 1, LAMP)
		part("ToroRoof", Vector3.new(3, 0.6, 3), at(x, y + 5.95, z), stone, Enum.Material.Slate, japan)
		part("ToroKnob", Vector3.new(0.7, 0.7, 0.7), at(x, y + 6.6, z), stone, Enum.Material.Slate, japan)
	end
	for _, p in ipairs({ { 140, -10 }, { 150, -56 }, { 228, -54 }, { 232, 0 }, { 176, 14 }, { 196, -74 } }) do
		local c = cellAtPos(p[1], p[2])
		if c and c.kind == "ground" then
			toro(p[1], p[2])
		end
	end
	-- the tea house on short stilts: a cherry-plank floor, paper walls, a wide dark roof flaring out
	do
		local hx, hz = 236, -86
		local y = floorAt(hx, hz)
		textured(part("TeaFloor", Vector3.new(12, 1, 10), at(hx, y + 1.8, hz), nil, nil, japan), "px_cherry_planks")
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			textured(part("TeaPost", Vector3.new(0.8, 7, 0.8), at(hx + s[1] * 5.6, y + 4.8, hz + s[2] * 4.6), nil, nil, japan), "px_cherry_log")
		end
		for _, w in ipairs({ { 0, -4.6, 11, 0.2 }, { -5.6, 0, 0.2, 9 }, { 5.6, 0, 0.2, 9 } }) do
			part("ShojiWall", Vector3.new(w[3], 4.6, w[4]), at(hx + w[1], y + 4.6, hz + w[2]), Color3.fromRGB(245, 240, 225), Enum.Material.SmoothPlastic, japan)
		end
		for k = -4, 4, 2 do
			part("ShojiGrid", Vector3.new(0.15, 4.6, 0.25), at(hx + k, y + 4.6, hz - 4.6), WOOD, Enum.Material.Wood, japan)
		end
		for k = 0, 2 do
			part("TeaRoof", Vector3.new(16 - k * 4, 0.8, 14 - k * 4), at(hx, y + 8.6 + k * 0.9, hz), Color3.fromRGB(50, 50, 56), Enum.Material.Slate, japan)
		end
		textured(part("TeaSteps", Vector3.new(4, 0.8, 2), at(hx, y + 0.9, hz + 6), nil, nil, japan), "px_cherry_planks")
	end
	-- the red torii at the entrance from the garden
	do
		local tx, tz = 132, 4
		for _, s in ipairs({ -1, 1 }) do
			part("ToriiPillar", Vector3.new(1.2, 12, 1.2), at(tx, 6, tz + s * 5), RED, nil, japan)
		end
		part("ToriiKasagi", Vector3.new(1.4, 1.2, 15), at(tx, 12.4, tz), Color3.fromRGB(40, 30, 30), nil, japan)
		part("ToriiShimaki", Vector3.new(1.2, 0.8, 14), at(tx, 11.4, tz), RED, nil, japan)
		part("ToriiNuki", Vector3.new(0.8, 0.8, 12.4), at(tx, 9.4, tz), RED, nil, japan)
	end
	-- raked gravel with three rocks, bamboo groves
	do
		local gx, gz = 214, 40
		textured(part("ZenGravel", Vector3.new(22, 0.2, 16), at(gx, 0.1, gz), nil, nil, japan), "px_gravel", Color3.fromRGB(235, 235, 230))
		for k = -7, 7, 1.4 do
			decor(part("Rake", Vector3.new(21, 0.05, 0.25), at(gx, 0.22, gz + k), Color3.fromRGB(200, 200, 195), nil, japan))
		end
		for _, r in ipairs({ { -5, -2, 3 }, { 4, 3, 2.2 }, { 7, -4, 1.6 } }) do
			part("ZenRock", Vector3.new(r[3] * 1.4, r[3], r[3] * 1.2), at(gx + r[1], r[3] * 0.4, gz + r[2]) * CFrame.Angles(0, rng:NextNumber(0, 2), 0.1), Color3.fromRGB(110, 110, 108), Enum.Material.Slate, japan)
		end
	end
	for _, g in ipairs({ { 250, 20 }, { 246, -30 }, { 160, 44 } }) do
		for _ = 1, 14 do
			local x, z = g[1] + rng:NextNumber(-5, 5), g[2] + rng:NextNumber(-5, 5)
			local h = rng:NextNumber(8, 14)
			local y = floorAt(x, z)
			local stalk = part("Bamboo", Vector3.new(h, 0.6, 0.6), at(x, y + h / 2, z) * CFrame.Angles(0, 0, math.pi / 2 + rng:NextNumber(-0.06, 0.06)), Color3.fromRGB(110, 170, 70), Enum.Material.SmoothPlastic, japan)
			stalk.Shape = Enum.PartType.Cylinder
			decor(part("BambooLeaves", Vector3.new(2.4, 0.8, 2.4), at(x, y + h, z), Color3.fromRGB(90, 160, 60), Enum.Material.Grass, japan))
		end
	end
	-- sakura and red Japanese maples round the pond (kept off the water, the paths and the bridge heads)
	local placed = 0
	for _ = 1, 1500 do
		if placed >= 18 then
			break
		end
		local x, z = rng:NextNumber(130, 260), rng:NextNumber(-110, 66)
		local c = cellAtPos(x, z)
		local clearOfWater = true
		for dx = -8, 8, 8 do
			for dz = -8, 8, 8 do
				local n = cellAtPos(x + dx, z + dz)
				if not n or n.kind ~= "ground" then
					clearOfWater = false
				end
			end
		end
		if c and c.kind == "ground" and not c.path and clearOfWater and math.abs(x - POND.x) > 8 then
			placed += 1
			if placed % 2 == 0 then
				cherryTree(x, z, 0.9)
			else
				local y = floorAt(x, z)
				local h = rng:NextNumber(4, 6)
				textured(part("MapleTrunk", Vector3.new(1, h, 1), at(x, y + h / 2, z) * CFrame.Angles(0, 0, rng:NextNumber(-0.2, 0.2)), nil, nil, japan), "px_cherry_log")
				for _ = 1, 4 do
					local w = rng:NextNumber(3.5, 5.5)
					textured(part("MapleLeaves", Vector3.new(w, w * 0.45, w), at(x + rng:NextNumber(-2.5, 2.5), y + h + rng:NextNumber(-0.5, 1.2), z + rng:NextNumber(-2.5, 2.5)), nil, nil, japan), "px_cherry_leaves", Color3.fromRGB(255, 70, 50))
				end
			end
		end
	end
	zoneSign(126, 18, "Японский сад", math.pi / 2)
end
task.wait()

-- ================================================================ the hedge maze with a gazebo in the middle
local maze = folder("HedgeMaze")
do
	local n, c = MAZE.n, MAZE.c
	-- recursive backtracker on n × n cells; walls between cells are hedges 6 tall
	local visited, walls = {}, {}
	local function key(i, j)
		return i * 100 + j
	end
	for i = 0, n - 1 do
		for j = 0, n - 1 do
			walls[key(i, j)] = { E = true, S = true }
		end
	end
	local stack = { { 0, 0 } }
	visited[key(0, 0)] = true
	local mrng = Random.new(1111)
	while #stack > 0 do
		local cur = stack[#stack]
		local i, j = cur[1], cur[2]
		local opts = {}
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local a, b = i + d[1], j + d[2]
			if a >= 0 and b >= 0 and a < n and b < n and not visited[key(a, b)] then
				table.insert(opts, { a, b, d })
			end
		end
		if #opts == 0 then
			table.remove(stack)
		else
			local o = opts[mrng:NextInteger(1, #opts)]
			local d = o[3]
			if d[1] == 1 then
				walls[key(i, j)].E = false
			elseif d[1] == -1 then
				walls[key(o[1], o[2])].E = false
			elseif d[2] == 1 then
				walls[key(i, j)].S = false
			else
				walls[key(o[1], o[2])].S = false
			end
			visited[key(o[1], o[2])] = true
			table.insert(stack, { o[1], o[2] })
		end
	end
	-- open the middle 3 × 3 for the gazebo
	local mid = math.floor(n / 2)
	for i = mid - 1, mid + 1 do
		for j = mid - 1, mid + 1 do
			if i < mid + 1 then
				walls[key(i, j)].E = false
			end
			if j < mid + 1 then
				walls[key(i, j)].S = false
			end
		end
	end
	local H = 6
	local x0, z0 = MAZE.x0, MAZE.z0
	local size = n * c
	-- outer walls with the entrance (south, towards the yard trail) and the exit (north)
	local entrance, exit_ = mid, mid
	for i = 0, n - 1 do
		if i ~= exit_ then
			hedgeBox("MazeWall", Vector3.new(c + 1, H, 1), at(x0 + i * c + c / 2, H / 2, z0), maze)
		end
		if i ~= entrance then
			hedgeBox("MazeWall", Vector3.new(c + 1, H, 1), at(x0 + i * c + c / 2, H / 2, z0 + size), maze)
		end
	end
	hedgeBox("MazeWall", Vector3.new(1, H, size + 1), at(x0, H / 2, z0 + size / 2), maze)
	hedgeBox("MazeWall", Vector3.new(1, H, size + 1), at(x0 + size, H / 2, z0 + size / 2), maze)
	-- inner walls: E walls run along z, S walls along x (merged into runs where they line up)
	for i = 0, n - 2 do
		local j0 = nil
		for j = 0, n do
			local has = j < n and walls[key(i, j)].E
			if has and not j0 then
				j0 = j
			elseif not has and j0 then
				hedgeBox("MazeWall", Vector3.new(1, H, (j - j0) * c + 1), at(x0 + (i + 1) * c, H / 2, z0 + (j0 + j) / 2 * c), maze)
				j0 = nil
			end
		end
	end
	for j = 0, n - 2 do
		local i0 = nil
		for i = 0, n do
			local has = i < n and walls[key(i, j)].S
			if has and not i0 then
				i0 = i
			elseif not has and i0 then
				hedgeBox("MazeWall", Vector3.new((i - i0) * c + 1, H, 1), at(x0 + (i0 + i) / 2 * c, H / 2, z0 + (j + 1) * c), maze)
				i0 = nil
			end
		end
	end
	gazebo(x0 + (mid + 0.5) * c, z0 + (mid + 0.5) * c, 4, maze)
	zoneSign(x0 + entrance * c + c / 2 + 7, z0 + size + 6, "Лабиринт", 0)
end
task.wait()

-- ================================================================ the royal castle and the tournament lists (the Knight's arena)
local castle = folder("Castle")
local arena = folder("Lists")
do
	-- the castle: a white curtain wall with battlements, round towers with blue cone roofs, a gatehouse, the keep
	local wallH, wallT = 30, 8
	local function tower(x, z, r, h, roofTiers)
		cyl("CastleTower", h, r * 2, at(x, h / 2, z), "px_white_stone_bricks", nil, castle)
		cyl("TowerCornice", 1.6, r * 2 + 1.6, at(x, h + 0.2, z), "px_white_stone_bricks", Color3.fromRGB(225, 225, 232), castle)
		for k = 0, roofTiers - 1 do
			cyl("TowerRoof", 2.4, (r + 1) * 2 * (1 - k / roofTiers), at(x, h + 1.4 + k * 2.4, z), nil, Color3.fromRGB(78, 112, 200), castle)
		end
		local poleTop = h + 1.4 + roofTiers * 2.4
		part("FlagPole", Vector3.new(0.4, 6, 0.4), at(x, poleTop + 3, z), IRON, Enum.Material.Metal, castle)
		decor(part("Flag", Vector3.new(0.12, 2.4, 4), at(x, poleTop + 4.6, z + 2), ROYAL, Enum.Material.Fabric, castle))
		decor(part("FlagStripe", Vector3.new(0.14, 0.6, 4), at(x, poleTop + 4.6, z + 2), GOLD, Enum.Material.Fabric, castle))
		for _, y in ipairs({ h * 0.45, h * 0.7 }) do
			decor(part("TowerWindow", Vector3.new(1.2, 2.6, 0.3), at(x, y, z + r - 0.05), Color3.fromRGB(40, 50, 70), nil, castle))
		end
	end
	local x0, x1 = -120, 120
	whiteStone("CastleWall", Vector3.new(x1 - x0, wallH, wallT), at(0, wallH / 2, CASTLE_Z - wallT / 2), castle)
	for x = x0, x1, 4 do
		whiteStone("Merlon", Vector3.new(2, 2.6, wallT + 0.4), at(x, wallH + 1.3, CASTLE_Z - wallT / 2), castle)
	end
	part("WallBand", Vector3.new(x1 - x0, 1.2, wallT + 0.4), at(0, wallH - 4, CASTLE_Z - wallT / 2), Color3.fromRGB(78, 112, 200), nil, castle)
	for _, x in ipairs({ x0, -60, 60, x1 }) do
		tower(x, CASTLE_Z - wallT / 2, 8, 44, 6)
	end
	-- the gatehouse (the gate is shut), banners either side
	for _, s in ipairs({ -1, 1 }) do
		tower(s * 14, CASTLE_Z - 2, 7, 50, 6)
	end
	whiteStone("GateArch", Vector3.new(16, 8, wallT + 4), at(0, 22, CASTLE_Z - 2), castle)
	part("Gate", Vector3.new(14, 18, 1), at(0, 9, CASTLE_Z + 0.6), Color3.fromRGB(90, 60, 40), Enum.Material.WoodPlanks, castle)
	for x = -6, 6, 2 do
		part("GateBand", Vector3.new(0.3, 18, 1.2), at(x, 9, CASTLE_Z + 0.7), IRON, Enum.Material.Metal, castle)
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, x in ipairs({ 30, 90 }) do
			decor(part("WallBanner", Vector3.new(5, 14, 0.2), at(s * x, wallH - 10, CASTLE_Z + 0.15), ROYAL, Enum.Material.Fabric, castle))
			decor(part("WallBannerStripe", Vector3.new(1.2, 13.6, 0.22), at(s * x, wallH - 10, CASTLE_Z + 0.2), GOLD, Enum.Material.Fabric, castle))
		end
	end
	-- the keep behind the wall
	whiteStone("Keep", Vector3.new(44, 64, 34), at(0, 32, CASTLE_Z - 40), castle)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		tower(s[1] * 22, CASTLE_Z - 40 + s[2] * 17, 6, 76, 7)
	end
	for k = 0, 4 do
		part("KeepRoof", Vector3.new(46 - k * 9, 3, 36 - k * 7), at(0, 65.5 + k * 3, CASTLE_Z - 40), Color3.fromRGB(78, 112, 200), nil, castle)
	end
	for x = -16, 16, 8 do
		for _, y in ipairs({ 36, 50 }) do
			decor(part("KeepWindow", Vector3.new(2, 4, 0.3), at(x, y, CASTLE_Z - 22.9), Color3.fromRGB(40, 50, 70), nil, castle))
		end
	end

	-- the lists: a sand field fenced with rails (ArenaWall: the charge stops there), entrances south and north
	local lx, lz, hx, hz = LISTS.x, LISTS.z, LISTS.hx, LISTS.hz
	local function fenceRun(xa, za, xb, zb)
		local len = math.sqrt((xb - xa) ^ 2 + (zb - za) ^ 2)
		local yaw = math.atan2(xb - xa, zb - za)
		for _, y in ipairs({ 1.4, 2.8 }) do
			local p = part("ArenaWall", Vector3.new(0.5, 0.5, len), at((xa + xb) / 2, y, (za + zb) / 2) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(240, 240, 240), nil, arena)
			_ = p
		end
		local steps = math.max(1, math.floor(len / 4))
		for k = 0, steps do
			local t = k / steps
			part("ArenaWall", Vector3.new(0.7, 3.4, 0.7), at(xa + (xb - xa) * t, 1.7, za + (zb - za) * t), if k % 2 == 0 then RED else WHITE, nil, arena)
		end
	end
	fenceRun(lx - hx, lz - hz, lx + hx, lz - hz)
	fenceRun(lx - hx, lz - hz, lx - hx, lz + hz)
	fenceRun(lx + hx, lz - hz, lx + hx, lz + hz)
	fenceRun(lx - hx, lz + hz, lx - 6, lz + hz)
	fenceRun(lx + 6, lz + hz, lx + hx, lz + hz)
	-- the four banner pillars (the charge stuns on them: names Pillar*)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local px, pz = lx + s[1] * 26, lz + s[2] * 14
		whiteStone("PillarBase", Vector3.new(5, 1.6, 5), at(px, 0.8, pz), arena)
		whiteStone("Pillar", Vector3.new(3.4, 16, 3.4), at(px, 9.6, pz), arena)
		part("PillarCap", Vector3.new(4.4, 1, 4.4), at(px, 18, pz), GOLD, Enum.Material.Metal, arena)
		decor(part("PillarBanner", Vector3.new(0.15, 9, 3), at(px + s[1] * 1.8, 11, pz), if s[2] < 0 then ROYAL else RED, Enum.Material.Fabric, arena))
		decor(part("PillarBannerStripe", Vector3.new(0.17, 8.6, 0.6), at(px + s[1] * 1.8, 11, pz), GOLD, Enum.Material.Fabric, arena))
	end
	-- stands on the east and west sides: three tiers of benches under a striped canopy
	for _, s in ipairs({ -1, 1 }) do
		local sx = lx + s * (hx + 8)
		for k = 0, 2 do
			textured(part("StandTier", Vector3.new(4, 1.2 + k * 1.6, hz * 1.6), at(sx + s * k * 3, (1.2 + k * 1.6) / 2, lz), nil, nil, arena), "px_cherry_planks")
		end
		for z = lz - hz * 0.8, lz + hz * 0.8, 8 do
			textured(part("StandPost", Vector3.new(0.6, 12, 0.6), at(sx + s * 9, 6, z), nil, nil, arena), "px_cherry_log")
			textured(part("StandPost", Vector3.new(0.6, 12, 0.6), at(sx - s * 2, 6, z), nil, nil, arena), "px_cherry_log")
		end
		for k = 0, 9 do
			decor(part("StandCanopy", Vector3.new(12, 0.2, hz * 0.16), at(sx + s * 3.5, 12.2, lz - hz * 0.8 + k * hz * 0.16 + hz * 0.08) * CFrame.Angles(0, 0, s * 0.12), if k % 2 == 0 then ROYAL else WHITE, Enum.Material.Fabric, arena))
		end
	end
	-- the royal box on the north side: a raised platform, two thrones under a blue-gold canopy
	do
		local bz = lz - hz - 8
		textured(part("RoyalBox", Vector3.new(24, 4, 10), at(lx, 2, bz), nil, nil, arena), "px_cherry_planks")
		decor(part("RoyalCarpet", Vector3.new(22, 0.1, 9), at(lx, 4.06, bz), Color3.fromRGB(150, 30, 40), Enum.Material.Fabric, arena))
		for _, s in ipairs({ -1, 1 }) do
			part("Throne", Vector3.new(3, 6, 2.4), at(lx + s * 3, 7, bz - 2), GOLD, Enum.Material.Metal, arena)
			part("ThroneSeat", Vector3.new(3, 0.8, 3), at(lx + s * 3, 5.2, bz - 0.6), Color3.fromRGB(150, 30, 40), Enum.Material.Fabric, arena)
		end
		for _, x in ipairs({ -11, 11 }) do
			part("BoxPost", Vector3.new(0.8, 10, 0.8), at(lx + x, 9, bz + 4.5), GOLD, Enum.Material.Metal, arena)
			part("BoxPost", Vector3.new(0.8, 10, 0.8), at(lx + x, 9, bz - 4.5), GOLD, Enum.Material.Metal, arena)
		end
		decor(part("BoxCanopy", Vector3.new(24, 0.3, 11), at(lx, 14.2, bz), ROYAL, Enum.Material.Fabric, arena))
		for x = -11, 11, 2 do
			decor(part("BoxValance", Vector3.new(1, 1.2, 0.2), at(lx + x, 13.4, bz + 5.5), if (x / 2) % 2 == 0 then GOLD else ROYAL, Enum.Material.Fabric, arena))
		end
	end
	-- round striped pavilions outside the corners, weapon racks, shields with heraldry
	for _, s in ipairs({ { -1, 1 }, { 1, 1 } }) do
		local px, pz = lx + s[1] * (hx + 22), lz + s[2] * (hz + 4)
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			decor(part("PavilionWall", Vector3.new(2.7, 6, 0.2), at(px + math.cos(a) * 5, 3, pz + math.sin(a) * 5) * CFrame.Angles(0, -a + math.pi / 2, 0), if k % 2 == 0 then RED else WHITE, Enum.Material.Fabric, arena)).CanCollide = true
		end
		for k = 0, 3 do
			cyl("PavilionRoof", 1.2, 11.4 * (1 - k * 0.24), at(px, 6.6 + k * 1.2, pz), nil, if k % 2 == 0 then RED else WHITE, arena)
		end
		part("PavilionPole", Vector3.new(0.3, 4, 0.3), at(px, 12.5, pz), IRON, Enum.Material.Metal, arena)
		decor(part("Pennant", Vector3.new(0.1, 1.2, 2.4), at(px, 13.6, pz + 1.2), GOLD, Enum.Material.Fabric, arena))
	end
	for _, s in ipairs({ -1, 1 }) do
		local rx, rz = lx + s * (hx - 4), lz + hz - 5
		textured(part("RackBase", Vector3.new(5, 0.4, 1.2), at(rx, 0.2, rz), nil, nil, arena), "px_cherry_planks")
		textured(part("RackBar", Vector3.new(5, 0.4, 0.4), at(rx, 3, rz), nil, nil, arena), "px_cherry_planks")
		for k = -2, 2 do
			part("RackLance", Vector3.new(0.3, 6, 0.3), at(rx + k, 3, rz) * CFrame.Angles(0.15, 0, 0), Color3.fromRGB(220, 210, 190), Enum.Material.Wood, arena)
		end
		local shield = part("Shield", Vector3.new(0.3, 3, 2.4), at(rx + s * 3.4, 2.2, rz), if s < 0 then ROYAL else RED, nil, arena)
		decor(part("ShieldChevron", Vector3.new(0.32, 0.6, 2.4), shield.CFrame * CFrame.Angles(0.6, 0, 0), GOLD, nil, arena))
	end
	-- a sign on the royal box
	local listsSign = textured(decor(part("ListsSign", Vector3.new(14, 2.2, 0.3), at(lx, 3, lz - hz - 2.9), nil, nil, arena)), "px_white_stone_bricks")
	boardText(listsSign, "Турнирное ристалище", Color3.fromRGB(40, 60, 150), { Enum.NormalId.Back })
	-- the boss
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(lx, 1.2, lz), nil, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "knight")
	bossSpawn:SetAttribute("ArenaRadius", 44)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end
task.wait()

-- ================================================================ the hills round the garden: green trees; free spots: cherries and flowers
do
	local made = 0
	for _ = 1, 3000 do
		if made >= 90 then
			break
		end
		local x, z = rng:NextNumber(-310, 310), rng:NextNumber(-310, 310)
		local c = cellAtPos(x, z)
		if c and c.kind == "hill" and c.d < 1.35 and z > CASTLE_Z + 10 then
			oakTree(x, z)
			made += 1
		end
	end
	local cherries = 0
	for _ = 1, 4000 do
		if cherries >= 40 then
			break
		end
		local x, z = rng:NextNumber(-R, R), rng:NextNumber(-R, R)
		local c = cellAtPos(x, z)
		if c and c.kind == "ground" and not c.path and not flat(x, z) and c.zone == "garden" and c.d < 0.9 and z > LISTS.z + LISTS.hz + 20 then
			cherryTree(x, z, rng:NextNumber(0.9, 1.2))
			cherries += 1
		end
	end
end

-- ================================================================ the air: petals, butterflies, a soft pink haze
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(part("GardenAir", Vector3.new(2 * R + 40, 160, 2 * R + 40), at(0, 60, 0), nil, nil, air))
volume.Transparency = 1
volume:SetAttribute("Haze", 0.14)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(255, 220, 232))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(230, 170, 200))
CollectionService:AddTag(volume, "IndoorLighting")
local function airEmitter(x, z, sx, sz, y, props_)
	local p = decor(part("AirParticles", Vector3.new(sx, 1, sz), at(x, y, z), nil, nil, props))
	p.Transparency = 1
	emitter(p, props_)
end
local PETALS = {
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(255, 190, 215), Color3.fromRGB(255, 225, 235)),
	Size = NumberSequence.new(0.35),
	Transparency = NumberSequence.new(0.1),
	Rate = 30,
	Lifetime = NumberRange.new(8, 12),
	Speed = NumberRange.new(1.5, 3),
	EmissionDirection = Enum.NormalId.Bottom,
	SpreadAngle = Vector2.new(40, 40),
	RotSpeed = NumberRange.new(-120, 120),
	Rotation = NumberRange.new(0, 360),
	Acceleration = Vector3.new(1.5, 0, 0.8),
}
airEmitter(-180, 20, 140, 240, 22, PETALS)
airEmitter(0, 170, 40, 130, 20, PETALS)
airEmitter(-147, 190, 170, 14, 14, PETALS)
airEmitter(0, -40, 160, 160, 26, PETALS)
for _, b in ipairs({ { 46, 60 }, { -46, 60 }, { 46, 132 }, { -46, 132 }, { 185, -30 }, { 0, 230 } }) do
	airEmitter(b[1], b[2], 30, 30, 3, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 240, 120)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(150, 200, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)) }),
		LightEmission = 0.5,
		Size = NumberSequence.new(0.45),
		Rate = 3,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(1, 2.5),
		SpreadAngle = Vector2.new(180, 60),
		Acceleration = Vector3.new(0, 0.3, 0),
	})
end

local total = #root:GetDescendants()
print(("[build-royal-garden] built: %d instances (terrain runs %d, bridge %s)"):format(total, count, game:GetService("HttpService"):JSONEncode(bridgeSpan)))
return ("built %d instances, runs %d, bridge %s"):format(total, count, game:GetService("HttpService"):JSONEncode(bridgeSpan))
