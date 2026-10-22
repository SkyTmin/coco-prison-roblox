--!nocheck
-- Builds the База фракций (faction base, level 5, only for faction members) [вики LOCATIONS-MENU,
-- BASEMENT-FACTION-BASE; клиент: «Необходимо находиться во фракции»]. What the original has [владелец]:
-- four faction spawns, each with a personal ender chest, 8 double chests (the faction's storage) and a
-- mini-mine; the boss Зомбарь on the square in the centre (an open square with a mossy «RIP» gravestone and
-- a respawn board); rats; PvP. Nothing online shows how it looks [docs: web research], so the look is ours
-- [владелец 22.10: «база фракций должна быть ещё лучше спавна — сделай шедевр»; «попасть на базу к другим
-- можно только по тропинке, которая ведёт в центр из каждой фракции, вокруг — барьеры-горы; карту ×2,
-- тропы широкие»; «здания больше, просторнее, с подходящими декорациями, красиво и насыщенно»]:
--   * four valleys in the corners, one per faction, walled off by blocky mountains (snow on the peaks);
--     from each valley a wide paved trail runs through a mountain pass to the centre — the only way
--     between the factions;
--   * the centre: the Зомбарь graveyard square in a ring of cliffs, the four passes open onto it;
--   * every valley in the spirit of its faction [клиент: names, colours, taglines]:
--       Славяне (white)   north-west — a great wooden терем with onion domes, izbas, birches, a well;
--       Афро (dark grey)   north-east — a great round kraal hall under a thatched cone, huts, baobabs;
--       Азиаты (yellow)    south-east — a three-tier pagoda, torii, cherry trees, a koi pond, bamboo;
--       Латиносы (brown)   south-west — a stepped temple pyramid, jungle palms, a hacienda market;
--     each hall is spacious and furnished in its style, holds the faction storage (8 double chests tagged
--     FactionChest + an EnderChest); in front of it the faction spawn (LocationSpawn, attribute Faction);
--     a 12×6×12 mini-mine (quarry blocks [меню]), a block buyer (SellPoint), a banner monument at the
--     trail, rat spawn points (MobSpawn, for the future MobService).
-- A separate zone at X = −1050 (StreamingEnabled loads it only for players there). Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures (and after build-prison: that one clears Terrain).
-- Idempotent: replaces Workspace.FactionBase.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local old = workspace:FindFirstChild("FactionBase")
if old then
	old:Destroy()
end
for _, f in ipairs(workspace:GetChildren()) do
	if f.Name:match("^Mine_fb_") then
		f:Destroy()
	end
end
local root = Instance.new("Folder")
root.Name = "FactionBase"
root.Parent = workspace

-- [22.10] at X = −1050: at −700 its outer mountains (to −144) reached into the prison (west wall at −202)
local BASE_X, BASE_Z = -1050, 0 -- zone centre
local FX, FZ = BASE_X, BASE_Z -- the current origin: districts are built in their own frame (see the end)
local B = 4 -- block size
local rng = Random.new(20261023) -- fixed seed: the same base every rebuild
-- [владелец 22.10: «центр, где босс, больше в 2 раза; вокруг — место, где можно бегать, просторно»]
local PLAZA = 110 -- radius of the central square (the graveyard of Зомбарь)
local MEADOW = 50 -- an open meadow ring round the square before the cliffs
local OFF = 170 -- a district's own origin sits at (±OFF, ±OFF): its valley spans local 10..230
local RIDGE = OFF + 10 -- the mountain ridges between the valleys reach |x| or |z| < RIDGE
local EDGE = OFF + 236 -- the outer mountains start at |x| or |z| > EDGE
local GROUND = EDGE + 150
local PASS = 26 -- half width of the mountain passes on the diagonals
local DMAX = 226 -- the far edge of a district in its own coordinates

local STONE = Color3.fromRGB(120, 120, 124)
local DARK = Color3.fromRGB(40, 38, 44)
local IRON = Color3.fromRGB(45, 45, 50)
local LAMP = Color3.fromRGB(255, 205, 120)
local LEAF = Color3.fromRGB(70, 125, 50)
local LEAF2 = Color3.fromRGB(95, 150, 60)

-- ---------------------------------------------------------------- helpers
local built = 0
local function mk(name, size, cf, mat, color, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if typeof(mat) == "Color3" then -- a plain coloured part
		color = color or mat
		mat = if mat == IRON then Enum.Material.Metal else Enum.Material.SmoothPlastic
	end
	if type(mat) == "string" then -- a block texture (MaterialVariant px_*), optionally tinted
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = mat
		p.Color = color or Color3.new(1, 1, 1)
	else
		p.Material = mat or Enum.Material.SmoothPlastic
		p.Color = color or STONE
	end
	p.Parent = parent or root
	built += 1
	if built % 400 == 0 then
		task.wait() -- keep Studio responsive while thousands of parts go in
	end
	return p
end
local function at(x, y, z)
	return CFrame.new(FX + x, y, FZ + z)
end
local function world(x, y, z)
	return Vector3.new(FX + x, y, FZ + z)
end
-- an axis-aligned box from two corners (zone coordinates)
local function box(name, x0, y0, z0, x1, y1, z1, mat, color, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return mk(name, size, at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), mat, color, parent)
end
-- a vertical cylinder standing on y0
local function cyl(name, radius, height, cf, mat, color, parent)
	local p = mk(name, Vector3.new(height, radius * 2, radius * 2), cf * CFrame.new(0, height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), mat, color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- a horizontal log (cylinder along the local X of cf)
local function logX(name, length, d, cf, mat, color, parent)
	local p = mk(name, Vector3.new(length, d, d), cf, mat, color, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local function ball(name, d, cf, mat, color, parent)
	local p = mk(name, Vector3.one * d, cf, mat, color, parent)
	p.Shape = Enum.PartType.Ball
	return p
end
local function light(p, color, range, brightness, shadows)
	local l = Instance.new("PointLight")
	l.Color = color or LAMP
	l.Range = range or 18
	l.Brightness = brightness or 1.2
	l.Shadows = shadows or false
	l.Parent = p
	return l
end
local function decorOnly(p)
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	return p
end
local function glowPart(name, size, cf, color, range, brightness, parent)
	local p = decorOnly(mk(name, size, cf, Enum.Material.Neon, color, parent))
	if range > 0 then
		light(p, color, range, brightness)
	end
	return p
end
local function sign(target, text, offset, color, maxDistance, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 150, 26)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = maxDistance or 160
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
local function surfaceText(target, face, text, color, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(200, 120)
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.Font = font or Enum.Font.Code
	label.TextColor3 = color or Color3.fromRGB(40, 40, 40)
	label.Text = text
	label.Parent = gui
end

-- keep-out circles for the random decor (current origin's coordinates; cleared for every district)
local claims = {}
local function claim(x, z, r)
	table.insert(claims, { x = x, z = z, r = r })
end
local function claimed(x, z, pad)
	for _, c in ipairs(claims) do
		if (x - c.x) ^ 2 + (z - c.z) ^ 2 < (c.r + (pad or 0)) ^ 2 then
			return true
		end
	end
	return false
end
-- a long strip (path, rail) between two points at the ground
local function strip(name, x0, z0, x1, z1, width, y0, y1, mat, color, parent)
	local a, b = world(x0, 0, z0), world(x1, 0, z1)
	local len = (b - a).Magnitude
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(Vector3.new(mid.X, (y0 + y1) / 2, mid.Z), Vector3.new(b.X, (y0 + y1) / 2, b.Z))
	return mk(name, Vector3.new(width, y1 - y0, len), cf, mat, color, parent)
end

-- the four mini-mine pits (with their walls) are cut out of the ground: one per district at local
-- (55, 165) ± 28; LOCAL_HOLE in a district's own coordinates, ZONE_HOLE shifted by OFF
local LOCAL_HOLE = { 27, 83, 137, 193 }
local ZONE_HOLE = { OFF + 27, OFF + 83, OFF + 137, OFF + 193 }
local function groundRect(name, x0, x1, z0, z1, y0, y1, mat, color, parent, hole)
	-- a slab with the mine holes of its z band left open (in all four quadrants)
	local hx0, hx1, hz0, hz1 = hole[1], hole[2], hole[3], hole[4]
	local bands = { { -1e4, -hz1 }, { -hz1, -hz0 }, { -hz0, hz0 }, { hz0, hz1 }, { hz1, 1e4 } }
	for i, band in ipairs(bands) do
		local bz0, bz1 = math.max(z0, band[1]), math.min(z1, band[2])
		if bz1 - bz0 > 0.1 then
			local cuts = if i == 2 or i == 4 then { { -1e4, -hx1 }, { -hx0, hx0 }, { hx1, 1e4 } } else { { -1e4, 1e4 } }
			for _, c in ipairs(cuts) do
				local cx0, cx1 = math.max(x0, c[1]), math.min(x1, c[2])
				if cx1 - cx0 > 0.1 then
					box(name, cx0, y0, bz0, cx1, y1, bz1, mat, color, parent)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- ground and the mountains
groundRect("Ground", -GROUND, GROUND, -GROUND, GROUND, -4, 0, "px_grass_top", nil, root, ZONE_HOLE)
-- Mountains on a 16-stud grid: a cell is rock unless it is in a valley, on the square or in a pass.
-- Height grows with the distance (in cells) from open ground: a cliff at the edge, peaks with snow inside.
local mountains = Instance.new("Folder")
mountains.Name = "Mountains"
mountains.Parent = root
local CELL = 16
local FLOWER_COLORS = { Color3.fromRGB(240, 70, 60), Color3.fromRGB(250, 210, 40), Color3.fromRGB(90, 130, 240), Color3.fromRGB(245, 245, 240), Color3.fromRGB(230, 90, 190) }
local N = math.ceil(GROUND / CELL)
local function isOpen(x, z)
	local ax, az = math.abs(x), math.abs(z)
	if ax > EDGE or az > EDGE then
		return false
	end
	if math.sqrt(x * x + z * z) < PLAZA + MEADOW then
		return true -- the square and the meadow round it
	end
	if ax > RIDGE and az > RIDGE then
		return true -- the valleys
	end
	return math.abs(ax - az) < PASS and ax < RIDGE + 24 and az < RIDGE + 24 -- the four passes
end
local open, dist, heights = {}, {}, {}
local STRATA = {
	{ "px_stone", nil },
	{ "px_terracotta", Color3.fromRGB(235, 170, 120) },
	{ "px_sandstone", nil },
	{ "px_terracotta", Color3.fromRGB(190, 110, 90) },
	{ "px_stone", nil },
	{ "px_mossy_cobblestone", nil },
	{ "px_terracotta", Color3.fromRGB(250, 215, 160) },
	{ "px_cobblestone", nil },
}
local ORES = { "px_gold_ore", "px_iron_ore", "px_coal_ore" }
local queue = {}
for i = -N, N - 1 do
	open[i], dist[i], heights[i] = {}, {}, {}
	for j = -N, N - 1 do
		local o = isOpen((i + 0.5) * CELL, (j + 0.5) * CELL)
		open[i][j] = o
		if o then
			dist[i][j] = 0
			table.insert(queue, { i, j })
		end
	end
end
local head = 1
while head <= #queue do -- breadth-first distance from open ground
	local c = queue[head]
	head += 1
	local d = dist[c[1]][c[2]]
	for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local ni, nj = c[1] + o[1], c[2] + o[2]
		if ni >= -N and ni < N and nj >= -N and nj < N and dist[ni][nj] == nil then
			dist[ni][nj] = d + 1
			table.insert(queue, { ni, nj })
		end
	end
end
for i = -N, N - 1 do
	for j = -N, N - 1 do
		if not open[i][j] then
			local d = dist[i][j] or 9
			-- rings of distance give the slope, Perlin noise the peaks and saddles
			local lump = (math.noise(i * 0.21, j * 0.21, 3.7) + 0.5) * 30
			local h = math.floor(math.clamp(10 + d * 7 + lump + rng:NextNumber(0, 6), 12, 100) / 4) * 4
			local x0, z0 = i * CELL, j * CELL
			local top = if h >= 76 then "px_white_wool" elseif d <= 1 and rng:NextNumber() < 0.35 then "px_stone" else "px_grass_top"
			heights[i][j] = h
			local r = math.sqrt((x0 + CELL / 2) ^ 2 + (z0 + CELL / 2) ^ 2)
			if r < PLAZA + MEADOW + 90 and d <= 2 then
				-- [владелец: «горы в центре покрасочнее»] the cliffs round the square show coloured strata like
				-- Minecraft badlands: stone, terracotta, sandstone, moss, with ore veins
				local shift = math.floor((math.noise(i * 0.15, j * 0.15, 9.1) + 0.5) * 3)
				for y = 0, h - 8, 8 do
					local band = (math.floor(y / 8) + shift) % #STRATA + 1
					local mat, tint = STRATA[band][1], STRATA[band][2]
					if rng:NextNumber() < 0.07 then
						mat, tint = ORES[rng:NextInteger(1, #ORES)], nil
					end
					box("Strata", x0, y, z0, x0 + CELL, math.min(y + 8, h - 4), z0 + CELL, mat, tint, mountains)
				end
			else
				local rock = if rng:NextNumber() < 0.2 then "px_cobblestone" else "px_stone"
				box("Rock", x0, 0, z0, x0 + CELL, h - 4, z0 + CELL, rock, nil, mountains)
			end
			box("RockTop", x0, h - 4, z0, x0 + CELL, h, z0 + CELL, top, if top == "px_white_wool" then Color3.fromRGB(240, 246, 255) else nil, mountains)
			-- flowers and bushes on the green ledges round the square
			if top == "px_grass_top" and r < PLAZA + MEADOW + 120 then
				for _ = 1, rng:NextInteger(2, 4) do
					local fx, fz = x0 + rng:NextNumber(1, CELL - 1), z0 + rng:NextNumber(1, CELL - 1)
					decorOnly(mk("LedgeFlower", Vector3.new(0.8, 0.6, 0.8), at(fx, h + 0.8, fz), Enum.Material.SmoothPlastic, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], mountains))
				end
				if rng:NextNumber() < 0.35 then
					local b = rng:NextNumber(2.5, 4)
					mk("LedgeBush", Vector3.new(b, b * 0.8, b), at(x0 + CELL / 2, h + b * 0.4, z0 + CELL / 2), Enum.Material.Grass, Color3.fromRGB(80, 145, 60), mountains)
				end
			end
			-- pines on the lower green slopes
			if top == "px_grass_top" and h <= 40 and rng:NextNumber() < 0.18 then
				local px, pz = x0 + CELL / 2, z0 + CELL / 2
				box("SlopePine", px - 0.8, h, pz - 0.8, px + 0.8, h + 8, pz + 0.8, "px_spruce_planks", nil, mountains)
				for k = 1, 3 do
					local w = 7 - k * 1.6
					box("SlopeNeedles", px - w / 2, h + 2 + k * 2, pz - w / 2, px + w / 2, h + 4 + k * 2, pz + w / 2, Enum.Material.Grass, Color3.fromRGB(45, 95, 55), mountains)
				end
			end
		end
	end
end

-- ---------------------------------------------------------------- waterfalls on the cliffs round the square
-- one in each cardinal direction (between the passes): a water sheet down the cliff, a pool, spray
local falls = Instance.new("Folder")
falls.Name = "Waterfalls"
falls.Parent = root
for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
	for k = 0, 40 do
		local r = PLAZA + MEADOW - 10 + k * 4
		local x, z = d[1] * r + math.abs(d[2]) * 8, d[2] * r + math.abs(d[1]) * 8
		local i, j = math.floor(x / CELL), math.floor(z / CELL)
		if open[i] and open[i][j] == false then
			local h = heights[i][j]
			-- the cliff face that looks at the square, and the direction back to the centre
			local faceX = if d[1] > 0 then i * CELL elseif d[1] < 0 then (i + 1) * CELL else x
			local faceZ = if d[2] > 0 then j * CELL elseif d[2] < 0 then (j + 1) * CELL else z
			local back = Vector3.new(-d[1], 0, -d[2])
			local sheetCf = CFrame.lookAt(world(faceX, h / 2 + 1, faceZ) + back * 0.5, world(faceX, h / 2 + 1, faceZ) + back * 2)
			local sheet = decorOnly(mk("Waterfall", Vector3.new(10, h - 2, 0.8), sheetCf, "px_water", nil, falls))
			sheet.Transparency = 0.15
			mk("FallLip", Vector3.new(12, 1.2, 3), CFrame.lookAt(world(faceX, h - 0.4, faceZ) + back * 0.6, world(faceX, h - 0.4, faceZ) + back * 2), "px_mossy_cobblestone", nil, falls)
			local poolC = world(faceX, 0, faceZ) + back * 10
			local rim = mk("PoolRim", Vector3.new(1.2, 22, 22), CFrame.new(poolC + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.pi / 2), "px_mossy_cobblestone", nil, falls)
			rim.Shape = Enum.PartType.Cylinder
			local pool = decorOnly(mk("Pool", Vector3.new(0.4, 19.6, 19.6), CFrame.new(poolC + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, 0, math.pi / 2), "px_water", nil, falls))
			pool.Shape = Enum.PartType.Cylinder
			pool.Transparency = 0.2
			local spray = Instance.new("ParticleEmitter")
			spray.Rate = 25
			spray.Lifetime = NumberRange.new(1, 1.8)
			spray.Speed = NumberRange.new(2, 5)
			spray.SpreadAngle = Vector2.new(60, 60)
			spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 3) })
			spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
			spray.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
			spray.Parent = pool
			for _, s in ipairs({ -1, 1 }) do -- flowers and lanterns by the pool
				local side = Vector3.new(-back.Z, 0, back.X) * s * 14
				local lp = poolC + side
				box("PoolLampPost", lp.X - FX - 0.4, 0, lp.Z - FZ - 0.4, lp.X - FX + 0.4, 7, lp.Z - FZ + 0.4, "px_dark_oak_planks", nil, falls)
				glowPart("PoolLantern", Vector3.new(1.4, 1.6, 1.4), CFrame.new(lp + Vector3.new(0, 7.8, 0)), LAMP, 22, 1.2, falls)
			end
			break
		end
	end
end

-- ---------------------------------------------------------------- the meadow round the square
-- an open green ring to run about in, a gravel ring path with lamps and benches, flowers and a few oaks
local meadow = Instance.new("Folder")
meadow.Name = "Meadow"
meadow.Parent = root
local RING = PLAZA + 18
for k = 0, 71 do
	local a0, a1 = k / 72 * math.pi * 2, (k + 1) / 72 * math.pi * 2
	-- neighbouring segments overlap at the joints: alternate their height so they never share a face
	strip("RingPath", math.cos(a0) * RING, math.sin(a0) * RING, math.cos(a1) * RING, math.sin(a1) * RING, 7, 0, if k % 2 == 0 then 0.28 else 0.36, "px_gravel", nil, meadow)
end
local function onTrail(x, z, pad)
	return math.abs(math.abs(x) - math.abs(z)) < PASS / math.sqrt(2) * 2 + (pad or 0)
end
for k = 0, 15 do
	local a = (k + 0.5) / 16 * math.pi * 2
	local x, z = math.cos(a) * (RING + 6.5), math.sin(a) * (RING + 6.5)
	if not onTrail(x, z, 4) then
		if k % 2 == 0 then
			box("MeadowLampPost", x - 0.35, 0, z - 0.35, x + 0.35, 9, z + 0.35, IRON, IRON, meadow)
			box("MeadowLampCap", x - 1.1, 10.6, z - 1.1, x + 1.1, 11.2, z + 1.1, IRON, IRON, meadow)
			glowPart("MeadowLantern", Vector3.new(1.6, 1.6, 1.6), at(x, 9.8, z), LAMP, 24, 1.2, meadow)
		else
			mk("MeadowBench", Vector3.new(6, 0.6, 1.6), at(x, 1.4, z) * CFrame.Angles(0, -a + math.pi / 2, 0), "px_spruce_planks", nil, meadow)
			mk("MeadowBenchBack", Vector3.new(6, 1.6, 0.4), at(x + math.cos(a) * 0.8, 2.4, z + math.sin(a) * 0.8) * CFrame.Angles(0, -a + math.pi / 2, 0), "px_spruce_planks", nil, meadow)
		end
	end
end
for _ = 1, 260 do
	local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(PLAZA + 4, PLAZA + MEADOW - 6)
	local x, z = math.cos(a) * r, math.sin(a) * r
	if not onTrail(x, z) and math.abs(r - RING) > 4.5 then
		decorOnly(mk("MeadowFlower", Vector3.new(0.8, 0.5, 0.8), at(x, 1.1, z), Enum.Material.SmoothPlastic, FLOWER_COLORS[rng:NextInteger(1, #FLOWER_COLORS)], meadow))
		decorOnly(mk("MeadowStem", Vector3.new(0.25, 1.2, 0.25), at(x, 0.6, z), Enum.Material.Grass, LEAF, meadow))
	end
end
local oakPlaced = 0
for _ = 1, 80 do
	if oakPlaced >= 12 then
		break
	end
	local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(RING + 12, PLAZA + MEADOW - 10)
	local x, z = math.cos(a) * r, math.sin(a) * r
	if not onTrail(x, z, 8) then
		local h = rng:NextNumber(8, 11)
		box("MeadowOakTrunk", x - 1.3, 0, z - 1.3, x + 1.3, h, z + 1.3, "px_oak_log", nil, meadow)
		mk("MeadowOakLeaves", Vector3.new(9, 7, 9), at(x, h + 2, z), Enum.Material.Grass, LEAF, meadow)
		mk("MeadowOakLeaves", Vector3.new(6, 5, 6), at(x + 2, h + 5, z - 1), Enum.Material.Grass, LEAF2, meadow)
		oakPlaced += 1
	end
end

-- ---------------------------------------------------------------- the trails through the passes
local trails = Instance.new("Folder")
trails.Name = "Trails"
trails.Parent = root
local TRAIL_W = 22
for _, d in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
	local from = (PLAZA - 4) / math.sqrt(2)
	local to = OFF + 30
	strip("Trail", d[1] * from, d[2] * from, d[1] * to, d[2] * to, TRAIL_W, 0, 0.45, "px_stone_bricks", nil, trails)
	for _, side in ipairs({ -1, 1 }) do
		-- curbs and lanterns on both sides, offset across the diagonal
		local nx, nz = -d[2] * side / math.sqrt(2), d[1] * side / math.sqrt(2)
		local off = TRAIL_W / 2 + 0.8
		strip("TrailCurb", d[1] * from + nx * off, d[2] * from + nz * off, d[1] * to + nx * off, d[2] * to + nz * off, 1.6, 0, 0.7, "px_smooth_stone", nil, trails)
		for t = 0.2, 0.95, 0.25 do
			local r = from + (to - from) * t
			local lx, lz = d[1] * r + nx * (off + 2.4), d[2] * r + nz * (off + 2.4)
			box("TrailLampBase", lx - 0.8, 0, lz - 0.8, lx + 0.8, 1, lz + 0.8, "px_stone_bricks", nil, trails)
			box("TrailLampPost", lx - 0.35, 1, lz - 0.35, lx + 0.35, 9, lz + 0.35, IRON, IRON, trails)
			box("TrailLampCap", lx - 1.1, 10.6, lz - 1.1, lx + 1.1, 11.2, lz + 1.1, IRON, IRON, trails)
			glowPart("TrailLantern", Vector3.new(1.6, 1.6, 1.6), at(lx, 9.8, lz), LAMP, 26, 1.3, trails)
		end
	end
end

-- ---------------------------------------------------------------- rats (MobService): MobSpawn points
-- [владелец 22.10: «3 крысы по каждой тропинке и крысы вокруг круга босса, через 2 минуты появляются снова»]
local mobs = Instance.new("Folder")
mobs.Name = "MobSpawns"
mobs.Parent = root
local function mobSpawn(x, z, radius)
	local m = decorOnly(mk("MobSpawn", Vector3.new(2, 1, 2), at(x, 0.5, z), STONE, STONE, mobs))
	m.Transparency = 1
	m:SetAttribute("MobId", "rat")
	m:SetAttribute("LocationId", "fraction_base")
	m:SetAttribute("Wander", radius)
	CollectionService:AddTag(m, "MobSpawn")
end
for _, d in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
	local from, to = (PLAZA + 8) / math.sqrt(2), OFF + 20
	for _, t in ipairs({ 0.25, 0.55, 0.85 }) do
		local r = from + (to - from) * t
		mobSpawn(d[1] * r, d[2] * r, 8)
	end
end
for k = 0, 7 do
	local a = (k + 0.5) / 8 * math.pi * 2 -- 22.5° off the trails
	mobSpawn(math.cos(a) * (PLAZA + 30), math.sin(a) * (PLAZA + 30), 12)
end

-- ---------------------------------------------------------------- the central square: the graveyard of Зомбарь
local square = Instance.new("Folder")
square.Name = "BossSquare"
square.Parent = root
local function disc(name, radius, top, mat, color)
	local p = mk(name, Vector3.new(1, radius * 2, radius * 2), at(0, top - 0.5, 0) * CFrame.Angles(0, 0, math.pi / 2), mat, color, square)
	p.Shape = Enum.PartType.Cylinder
	return p
end
disc("SquareRing", PLAZA, 0.5, "px_stone_bricks")
disc("SquareGround", PLAZA - 8, 0.8, "px_mossy_cobblestone")
disc("GraveSoil", 20, 1.0, "px_dirt", Color3.fromRGB(150, 130, 120))
-- the iron fence around the graveyard, open towards the four trails (the diagonals)
local FENCE_R = PLAZA - 8.5
for i = 0, 319 do
	local a = i / 320 * math.pi * 2
	local gap = math.abs(math.abs(math.sin(a)) - math.abs(math.cos(a))) < 0.16
	if not gap then
		local x, z = math.cos(a) * FENCE_R, math.sin(a) * FENCE_R
		box("FencePost", x - 0.2, 0.8, z - 0.2, x + 0.2, 4.6, z + 0.2, IRON, IRON, square)
		if i % 2 == 0 then
			decorOnly(mk("FenceRail", Vector3.new(0.25, 0.25, 2 * math.pi * FENCE_R / 160 + 0.1), at(x, 3.8, z) * CFrame.Angles(0, -a, 0), Enum.Material.Metal, IRON, square))
			decorOnly(mk("FenceSpike", Vector3.new(0.3, 0.6, 0.3), at(x, 4.9, z), Enum.Material.Metal, IRON, square))
		end
	end
end
-- the big mossy RIP gravestone at the north side, the boss rises in front of it
local stone = box("RipStone", -10, 1, -80, 10, 25, -76, "px_mossy_stone_bricks", nil, square)
local arch = mk("RipStoneTop", Vector3.new(4, 20, 20), at(0, 25, -78) * CFrame.Angles(0, math.pi / 2, 0), "px_mossy_stone_bricks", nil, square)
arch.Shape = Enum.PartType.Cylinder
box("RipPlinth", -13, 0.8, -83, 13, 2.6, -73, "px_mossy_cobblestone", nil, square)
surfaceText(stone, Enum.NormalId.Back, "R.I.P.", Color3.fromRGB(35, 45, 30), Enum.Font.Antique)
for _, s in ipairs({ -1, 1 }) do -- two soul fires in braziers beside the stone
	box("RipBrazier", s * 17 - 1.8, 0.8, -80, s * 17 + 1.8, 3.6, -76.4, "px_stone_bricks", nil, square)
	local f = glowPart("SoulFire", Vector3.new(2.6, 0.6, 2.6), at(s * 17, 3.9, -78.2), Color3.fromRGB(90, 230, 255), 28, 1.6, square)
	local fire = Instance.new("Fire")
	fire.Color, fire.SecondaryColor = Color3.fromRGB(90, 230, 255), Color3.fromRGB(30, 120, 160)
	fire.Size, fire.Heat = 4, 7
	fire.Parent = f
end
-- small gravestones and crosses in two rings, bones in the grass (the trails and the dead trees kept clear)
for n = 0, 4 * 48 - 1 do
	local i = n % 48
	local r = ({ 40, 54, 68, 84 })[n // 48 + 1]
	local a = (i + 0.5 + (n // 48) * 0.5) / 48 * math.pi * 2 + rng:NextNumber(-0.03, 0.03)
	local x, z = math.cos(a) * r, math.sin(a) * r
	local nearTrail = math.abs(math.abs(math.sin(a)) - math.abs(math.cos(a))) < 0.3
	local nearTree = math.abs(math.sin(a)) < 0.08 or math.abs(math.cos(a)) < 0.08
	if not nearTrail and not nearTree and not (z < -66 and math.abs(x) < 26) and rng:NextNumber() < 0.75 then
		local face = CFrame.lookAt(world(x, 0, z), world(0, 0, 0))
		local tilt = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
		if rng:NextNumber() < 0.7 then
			mk("Gravestone", Vector3.new(2.6, 3.4, 0.7), face * CFrame.new(0, 2.4, 0) * tilt, if rng:NextNumber() < 0.5 then "px_mossy_cobblestone" else "px_cobblestone", nil, square)
		else
			mk("Cross", Vector3.new(0.6, 4, 0.6), face * CFrame.new(0, 2.8, 0) * tilt, "px_dark_oak_planks", nil, square)
			mk("CrossBar", Vector3.new(2.4, 0.6, 0.6), face * CFrame.new(0, 3.6, 0) * tilt, "px_dark_oak_planks", nil, square)
		end
		mk("GraveMound", Vector3.new(2.4, 0.4, 4), face * CFrame.new(0, 0.95, -2.6), "px_dirt", Color3.fromRGB(150, 130, 120), square)
	end
end
for _ = 1, 45 do
	local a, r = rng:NextNumber(0, math.pi * 2), rng:NextNumber(22, PLAZA - 12)
	decorOnly(mk("Bone", Vector3.new(0.35, 0.35, rng:NextNumber(1.2, 2.2)), at(math.cos(a) * r, 0.95, math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Enum.Material.SmoothPlastic, Color3.fromRGB(230, 225, 205), square))
end
-- dead trees at the sides (between the trails)
local function deadTree(x, z, parent)
	local h = rng:NextNumber(14, 18)
	box("DeadTrunk", x - 1.2, 0.8, z - 1.2, x + 1.2, h, z + 1.2, "px_dark_oak_planks", Color3.fromRGB(150, 140, 135), parent)
	for k = 1, 5 do
		local a = k * math.pi * 2 / 5 + rng:NextNumber(-0.4, 0.4)
		local y = h * rng:NextNumber(0.5, 0.95)
		local len = rng:NextNumber(4, 8)
		mk("DeadBranch", Vector3.new(0.8, 0.8, len), at(x + math.cos(a) * len / 2, y, z + math.sin(a) * len / 2) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0.6, 0, 0), "px_dark_oak_planks", Color3.fromRGB(150, 140, 135), parent)
	end
end
for _, d in ipairs({ { 0, 62 }, { 62, 0 }, { -62, 0 }, { 0, 96 }, { 96, 0 }, { -96, 0 } }) do
	deadTree(d[1], d[2], square)
end
-- soul lanterns (cold green light) on posts around the graveyard
for i = 0, 19 do
	local a = (i + 0.5) / 20 * math.pi * 2
	local x, z = math.cos(a) * (PLAZA - 4), math.sin(a) * (PLAZA - 4)
	box("SoulPost", x - 0.4, 0.5, z - 0.4, x + 0.4, 7, z + 0.4, "px_dark_oak_planks", nil, square)
	glowPart("SoulLantern", Vector3.new(1.4, 1.8, 1.4), at(x, 7.9, z), Color3.fromRGB(110, 255, 200), 22, 1.2, square)
end
-- low green mist over the graves
local mist = decorOnly(mk("GraveMist", Vector3.new(190, 1, 190), at(0, 1.5, 0), Enum.Material.SmoothPlastic, DARK, square))
mist.Transparency = 1
local emitter = Instance.new("ParticleEmitter")
emitter.Rate = 32
emitter.Lifetime = NumberRange.new(6, 9)
emitter.Speed = NumberRange.new(0.4, 1)
emitter.SpreadAngle = Vector2.new(180, 10)
emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) })
emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
emitter.Color = ColorSequence.new(Color3.fromRGB(150, 200, 160))
emitter.LightEmission = 0.1
emitter.Parent = mist
-- the boss (BossService: BossSpawn with BossId) — Зомбарь rises from the soil in the middle
local bossSpawn = box("BossSpawn", -2, 1, -2, 2, 2, 2, STONE, nil, square)
bossSpawn.Transparency = 1
decorOnly(bossSpawn)
bossSpawn:SetAttribute("BossId", "giant_zombie")
bossSpawn:SetAttribute("ArenaRadius", PLAZA - 6)
CollectionService:AddTag(bossSpawn, "BossSpawn")
local boardAnchor = decorOnly(box("BossSign", -0.5, 31, -79, 0.5, 32, -78, STONE, nil, square))
boardAnchor.Transparency = 1
sign(boardAnchor, "Босс Зомбарь", 0, Color3.fromRGB(80, 200, 80), 140)

-- ---------------------------------------------------------------- shared district pieces
local function npc(name, tag, cf, label, labelColor, skin, shirt, pants, parent)
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
	model.Parent = parent
	model:PivotTo(cf)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = model:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, tag)
	sign(hrp, label, 4.5, labelColor, 60)
	return model
end

-- A Minecraft double chest (two chests side by side), the lock side facing −Z of cf. FactionChest:
-- the faction's shared storage (FactionStorageService; CaseService opens it only for its members).
local function doubleChest(cf, faction, index, parent)
	local model = Instance.new("Model")
	model.Name = "FactionChest_" .. index
	model.Parent = parent
	local base = mk("Base", Vector3.new(7.6, 3, 3.6), cf * CFrame.new(0, 1.5, 0), "px_planks", Color3.fromRGB(205, 160, 110), model)
	mk("Lid", Vector3.new(7.8, 1, 3.8), cf * CFrame.new(0, 3.5, 0), "px_planks", Color3.fromRGB(185, 140, 95), model)
	for _, dx in ipairs({ -1.9, 1.9 }) do
		mk("Latch", Vector3.new(0.7, 1, 0.3), cf * CFrame.new(dx, 3, -1.95), Enum.Material.Metal, Color3.fromRGB(70, 70, 75), model)
	end
	mk("Seam", Vector3.new(0.15, 3.9, 3.85), cf * CFrame.new(0, 2, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(70, 50, 30), model)
	model.PrimaryPart = base
	base:SetAttribute("Faction", faction)
	base:SetAttribute("ChestIndex", index)
	CollectionService:AddTag(base, "FactionChest")
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end
local function enderChest(cf, parent)
	local model = Instance.new("Model")
	model.Name = "EnderChest"
	model.Parent = parent
	mk("Pedestal", Vector3.new(6, 1, 5), cf * CFrame.new(0, 0.5, 0), "px_smooth_stone", nil, model)
	local base = mk("Base", Vector3.new(4.2, 3, 4), cf * CFrame.new(0, 2.5, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(28, 24, 38), model)
	mk("Lid", Vector3.new(4.4, 1.2, 4.2), cf * CFrame.new(0, 4.6, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(38, 32, 52), model)
	mk("Lock", Vector3.new(1, 1.2, 0.4), cf * CFrame.new(0, 3.9, -2.15), Enum.Material.Metal, Color3.fromRGB(80, 230, 180), model)
	local glow = decorOnly(mk("Glow", Vector3.new(4, 0.2, 3.8), cf * CFrame.new(0, 4.02, 0), Enum.Material.Neon, Color3.fromRGB(70, 230, 180), model))
	glow.Transparency = 0.3
	light(glow, Color3.fromRGB(70, 230, 180), 12, 1)
	model.PrimaryPart = base
	CollectionService:AddTag(base, "EnderChest")
	sign(base, "Эндер-сундук", 4, Color3.fromRGB(150, 255, 210), 40)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	return model
end
-- The hall's storage: 8 double chests along the two side walls (4 each) and the ender chest at the back
-- wall. frame: the hall centre at floor level, −Z towards the door; w, d: the inner size.
local function storage(frame, faction, w, d, floorY, parent)
	local index = 0
	for _, side in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			index += 1
			local z = -d / 2 + 8 + k * ((d - 16) / 3)
			local cf = frame * CFrame.new(side * (w / 2 - 2.6), floorY, z) * CFrame.Angles(0, side * math.pi / 2, 0)
			doubleChest(cf, faction, index, parent)
		end
	end
	enderChest(frame * CFrame.new(0, floorY, d / 2 - 4), parent) -- the lock faces the door
end
-- a brighter ambient light inside the roofed hall (IndoorLighting client)
local function indoor(frame, size, parent)
	local model = Instance.new("Model")
	model.Name = "IndoorLighting"
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	model.Parent = parent
	local v = decorOnly(mk("IndoorVolume", size, frame * CFrame.new(0, size.Y / 2, 0), Enum.Material.SmoothPlastic, STONE, model))
	v.Transparency = 1
	-- [владелец 22.10: «внутри очень светло, бьёт по глазам»] a soft indoor light, no extra exposure
	v:SetAttribute("Ambient", Color3.fromRGB(105, 100, 96))
	v:SetAttribute("Exposure", -0.1)
	CollectionService:AddTag(v, "IndoorLighting")
end
local function banner(cf, cloth, accent, parent, height)
	height = height or 10
	mk("BannerBar", Vector3.new(4.6, 0.4, 0.4), cf * CFrame.new(0, height, 0), "px_dark_oak_planks", nil, parent)
	local c = decorOnly(mk("Banner", Vector3.new(4, height - 1.5, 0.25), cf * CFrame.new(0, height / 2 + 0.6, 0), cloth, nil, parent))
	if accent then
		decorOnly(mk("BannerStripe", Vector3.new(4.02, 0.9, 0.27), cf * CFrame.new(0, height - 2.2, 0), accent, nil, parent))
		decorOnly(mk("BannerEmblem", Vector3.new(1.8, 1.8, 0.27), cf * CFrame.new(0, height / 2 + 0.2, 0) * CFrame.Angles(0, 0, math.pi / 4), accent, nil, parent))
	end
	return c
end
-- a flat rug with a border (frame space)
local function rug(frame, x, z, w, d, y, mat, color, border, parent)
	mk("Rug", Vector3.new(w, 0.16, d), frame * CFrame.new(x, y + 0.08, z), mat, color, parent)
	if border then
		mk("RugBorder", Vector3.new(w + 0.8, 0.06, d + 0.8), frame * CFrame.new(x, y + 0.03, z), Enum.Material.Fabric, border, parent)
	end
end

-- the mini-mine of a district: a 12 × 6 × 12 pit with dark bedrock-like walls, ladders on all four
-- sides like the other mines (MineService fills it: quarry blocks [меню], reset every 120 s [решение])
local function miniMine(cx, cz, faction, parent)
	local SX, SY, SZ = 12, 6, 12
	local w, h, d = SX * B, SY * B, SZ * B
	local BEDROCK = Color3.fromRGB(62, 58, 66)
	box("MineFloor", cx - w / 2 - B, -h - B, cz - d / 2 - B, cx + w / 2 + B, -h, cz + d / 2 + B, "px_cobblestone", BEDROCK, parent)
	box("MineWall", cx - w / 2 - B, -h, cz - d / 2 - B, cx + w / 2 + B, 0, cz - d / 2, "px_cobblestone", BEDROCK, parent)
	box("MineWall", cx - w / 2 - B, -h, cz + d / 2, cx + w / 2 + B, 0, cz + d / 2 + B, "px_cobblestone", BEDROCK, parent)
	box("MineWall", cx - w / 2 - B, -h, cz - d / 2, cx - w / 2, 0, cz + d / 2, "px_cobblestone", BEDROCK, parent)
	box("MineWall", cx + w / 2, -h, cz - d / 2, cx + w / 2 + B, 0, cz + d / 2, "px_cobblestone", BEDROCK, parent)
	box("MineRim", cx - w / 2 - B, 0, cz - d / 2 - B, cx + w / 2 + B, 0.5, cz - d / 2, "px_cobblestone", BEDROCK, parent)
	box("MineRim", cx - w / 2 - B, 0, cz + d / 2, cx + w / 2 + B, 0.5, cz + d / 2 + B, "px_cobblestone", BEDROCK, parent)
	box("MineRim", cx - w / 2 - B, 0, cz - d / 2, cx - w / 2, 0.5, cz + d / 2, "px_cobblestone", BEDROCK, parent)
	box("MineRim", cx + w / 2, 0, cz - d / 2, cx + w / 2 + B, 0.5, cz + d / 2, "px_cobblestone", BEDROCK, parent)
	-- a wooden rail round the pit with a gap at every ladder
	local e = w / 2 + B - 0.3
	for _, s in ipairs({ -1, 1 }) do
		for _, run in ipairs({ { -e, -10 }, { 10, e } }) do
			box("MineRail", cx + run[1], 0.5, cz + s * e - 0.3, cx + run[2], 3.5, cz + s * e + 0.3, "px_spruce_planks", nil, parent)
			box("MineRail", cx + s * e - 0.3, 0.5, cz + run[1], cx + s * e + 0.3, 3.5, cz + run[2], "px_spruce_planks", nil, parent)
		end
	end
	-- the anchor (MineService grows the grid down from its top centre)
	local anchor = box("MineAnchor_fb_" .. faction, cx - w / 2, -0.2, cz - d / 2, cx + w / 2, 0, cz + d / 2, DARK, DARK, parent)
	anchor:SetAttribute("LocationId", "fraction_base")
	anchor:SetAttribute("MineId", "fb_" .. faction)
	anchor:SetAttribute("Size", Vector3.new(SX, SY, SZ))
	anchor:SetAttribute("MiniMine", true)
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, "Шахта фракции", 6, Color3.fromRGB(255, 190, 60), 80)
	-- ladders (the four 4-wide shafts MineService keeps free): invisible trusses + a ladder texture plate
	local ladder = require(game:GetService("ReplicatedStorage").Shared.Config.textures).textures.ladder
	for _, s in ipairs({
		{ cx, cz - d / 2, Vector3.new(0, 0, 1) },
		{ cx, cz + d / 2, Vector3.new(0, 0, -1) },
		{ cx - w / 2, cz, Vector3.new(1, 0, 0) },
		{ cx + w / 2, cz, Vector3.new(-1, 0, 0) },
	}) do
		local inward = s[3]
		local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
		local base = world(s[1], -h / 2, s[2])
		for k = 0, 7 do -- eight 2×2 trusses across the 16-stud shaft, like the quarry ladders
			local truss = Instance.new("TrussPart")
			truss.Name = "Ladder"
			truss.Size = Vector3.new(2, h, 2)
			truss.CFrame = CFrame.new(base - inward * 0.6 + along * (-8 + 1 + k * 2))
			truss.Anchored = true
			truss.Transparency = 1
			truss.Parent = parent
		end
		local plate = Instance.new("Part")
		plate.Name = "LadderFace"
		plate.Size = Vector3.new(16 * along.X + 0.2 * math.abs(inward.X), h, 16 * along.Z + 0.2 * math.abs(inward.Z))
		plate.CFrame = CFrame.new(base + inward * 0.15)
		plate.Anchored, plate.CanCollide, plate.CanQuery, plate.Transparency = true, false, false, 1
		plate.Parent = parent
		if ladder then
			local tex = Instance.new("Texture")
			tex.Texture = ladder
			tex.Face = if inward.Z > 0 then Enum.NormalId.Back elseif inward.Z < 0 then Enum.NormalId.Front elseif inward.X > 0 then Enum.NormalId.Right else Enum.NormalId.Left
			tex.StudsPerTileU, tex.StudsPerTileV = B, B
			tex.Parent = plate
		end
	end
	claim(cx, cz, w / 2 + 12)
end
local function spawnPad(x, z, faceX, faceZ, faction, cloth, parent)
	box("SpawnPad", x - 7, 0, z - 7, x + 7, 0.8, z + 7, "px_smooth_stone", nil, parent)
	box("SpawnInlay", x - 5, 0.8, z - 5, x + 5, 0.95, z + 5, cloth, nil, parent)
	local p = mk("LocationSpawn_fraction_base_" .. faction, Vector3.new(4, 1, 4), CFrame.lookAt(world(x, 1.05, z), world(faceX, 1.05, faceZ)), "px_stone_bricks", nil, parent)
	p:SetAttribute("LocationId", "fraction_base")
	p:SetAttribute("Faction", faction)
	CollectionService:AddTag(p, "LocationSpawn")
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		box("SpawnPost", x + c[1] * 6.5 - 0.5, 0.8, z + c[2] * 6.5 - 0.5, x + c[1] * 6.5 + 0.5, 4, z + c[2] * 6.5 + 0.5, "px_stone_bricks", nil, parent)
		glowPart("SpawnLight", Vector3.new(1, 1, 1), at(x + c[1] * 6.5, 4.5, z + c[2] * 6.5), LAMP, 16, 0.9, parent)
	end
	claim(x, z, 13)
	return p
end
-- the monument by the trail: a tall pole with the faction's banners and its name
local function monument(x, z, name, color, cloth, accent, parent)
	box("MonumentBase", x - 5, 0, z - 5, x + 5, 1.5, z + 5, "px_stone_bricks", nil, parent)
	box("MonumentStep", x - 3.5, 1.5, z - 3.5, x + 3.5, 3, z + 3.5, "px_smooth_stone", nil, parent)
	box("MonumentPole", x - 0.7, 3, z - 0.7, x + 0.7, 26, z + 0.7, "px_dark_oak_planks", nil, parent)
	ball("MonumentFinial", 2.2, at(x, 26.8, z), "px_gold_block", nil, parent)
	for k = 0, 3 do
		local cf = at(x, 10, z) * CFrame.Angles(0, k * math.pi / 2, 0) * CFrame.new(0, 0, -1.3)
		banner(cf, cloth, accent, parent, 13)
	end
	local anchor = decorOnly(box("MonumentSign", x - 0.5, 28, z - 0.5, x + 0.5, 29, z + 0.5, STONE, nil, parent))
	anchor.Transparency = 1
	sign(anchor, name, 1, color, 260, 190)
	claim(x, z, 9)
end

-- ---------------------------------------------------------------- trees and small decor
local function leafCube(x, y, z, s, color, parent)
	return mk("Leaves", Vector3.new(s, s * 0.8, s), at(x, y, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), Enum.Material.Grass, color, parent)
end
local function birch(x, z, s, parent)
	local h = 12 * s
	box("BirchTrunk", x - s, 0, z - s, x + s, h, z + s, "px_birch_log", nil, parent)
	leafCube(x, h + 1, z, 7 * s, LEAF2, parent)
	leafCube(x + 2.4 * s, h + 2.5, z - 1.4 * s, 4.8 * s, Color3.fromRGB(130, 175, 70), parent)
	leafCube(x - 2 * s, h + 3.2, z + 2 * s, 4.5 * s, LEAF2, parent)
	leafCube(x, h + 5 * s, z, 3.2 * s, Color3.fromRGB(130, 175, 70), parent)
end
local function oak(x, z, s, parent)
	local h = 9 * s
	box("OakTrunk", x - 1.4 * s, 0, z - 1.4 * s, x + 1.4 * s, h, z + 1.4 * s, "px_oak_log", nil, parent)
	leafCube(x, h + 2, z, 9 * s, LEAF, parent)
	for k = 1, 4 do
		local a = k * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		leafCube(x + math.cos(a) * 3.8 * s, h + rng:NextNumber(0, 2), z + math.sin(a) * 3.8 * s, 6 * s, if k % 2 == 0 then LEAF2 else LEAF, parent)
	end
	leafCube(x, h + 6 * s, z, 5 * s, LEAF2, parent)
end
local function pine(x, z, s, parent)
	local h = 14 * s
	box("PineTrunk", x - 1.1 * s, 0, z - 1.1 * s, x + 1.1 * s, h, z + 1.1 * s, "px_spruce_planks", nil, parent)
	for k = 1, 5 do
		local w = (9 - k * 1.4) * s
		mk("Needles", Vector3.new(w, 2 * s, w), at(x, h * 0.35 + (k - 1) * 2.6 * s, z) * CFrame.Angles(0, (k % 2) * math.pi / 4, 0), Enum.Material.Grass, Color3.fromRGB(45, 95, 55), parent)
	end
end
-- random spots in the district (its own coordinates, both signs handled), away from the claims
local function scatter(count, a0, a1, b0, b1, pad, sx, sz, fn)
	local placed, tries = 0, 0
	while placed < count and tries < count * 40 do
		tries += 1
		local x, z = sx * rng:NextNumber(a0, a1), sz * rng:NextNumber(b0, b1)
		if not claimed(x, z, pad) then
			fn(x, z)
			claim(x, z, pad)
			placed += 1
		end
	end
end
local function fenceLine(x0, z0, x1, z1, parent, mat)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local n = math.max(1, math.floor(len / 4))
	for k = 0, n do
		local t = k / n
		local x, z = x0 + (x1 - x0) * t, z0 + (z1 - z0) * t
		box("FencePost", x - 0.4, 0, z - 0.4, x + 0.4, 3.4, z + 0.4, mat or "px_planks", nil, parent)
	end
	for _, y in ipairs({ 1.4, 2.7 }) do
		strip("FenceRail", x0, z0, x1, z1, 0.3, y - 0.2, y + 0.2, mat or "px_planks", nil, parent)
	end
end
local function flowers(count, colors, sx, sz, parent)
	scatter(count, 14, DMAX, 14, DMAX, 1.5, sx, sz, function(x, z)
		decorOnly(mk("FlowerStem", Vector3.new(0.25, 1.4, 0.25), at(x, 0.7, z), Enum.Material.Grass, LEAF, parent))
		decorOnly(mk("Flower", Vector3.new(0.8, 0.5, 0.8), at(x, 1.5, z), Enum.Material.SmoothPlastic, colors[rng:NextInteger(1, #colors)], parent))
	end)
end

-- bushes, rocks and grass tufts all over a valley (and a band of trees at the foot of the mountains), so
-- no ground stays bare [владелец: «красиво и насыщенно»]
local function dress(sx, sz, parent, leaf, grass)
	scatter(50, 14, DMAX, 14, DMAX, 3, sx, sz, function(x, z)
		local s = rng:NextNumber(2, 3.6)
		leafCube(x, s * 0.4, z, s, if rng:NextNumber() < 0.5 then leaf else leaf:Lerp(Color3.new(0, 0, 0), 0.15), parent)
		if rng:NextNumber() < 0.4 then
			leafCube(x + s * 0.6, s * 0.35, z + s * 0.3, s * 0.7, leaf:Lerp(Color3.new(1, 1, 1), 0.08), parent)
		end
	end)
	scatter(24, 14, DMAX, 14, DMAX, 3, sx, sz, function(x, z)
		for k = 1, rng:NextInteger(1, 3) do
			local s = rng:NextNumber(1.6, 3.4)
			mk("Boulder", Vector3.new(s, s * 0.8, s), at(x + (k - 1) * 1.8, s * 0.3, z + rng:NextNumber(-1, 1)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), if rng:NextNumber() < 0.7 then "px_stone" else "px_mossy_cobblestone", nil, parent)
		end
	end)
	scatter(160, 14, DMAX, 14, DMAX, 0.8, sx, sz, function(x, z)
		decorOnly(mk("TallGrass", Vector3.new(0.25, rng:NextNumber(1, 2.2), 0.25), at(x, 0.8, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Enum.Material.Grass, grass, parent))
	end)
end

-- ---------------------------------------------------------------- the four districts
-- Built in the district's own coordinates (origin at (±OFF, ±OFF)): x = sx*a, z = sz*b for a, b in
-- 10..230. The hall faces −sz (towards the spawn and the trail).
local HALL_A, HALL_B = 150, 168
local MINE_A, MINE_B = 55, 165
local SPAWN_A, SPAWN_B = 150, 96

-- Славяне: a great wooden терем — a log hall with a steep gable roof, carved white window frames, a
-- porch and three onion domes (gold and teal); inside: long feast tables, a white tiled stove, embroidered
-- towels, shields on the walls, a bear rug, wooden chandeliers, a spinning wheel, a samovar, kvass.
-- The yard: izbas, a well, haystacks, a hay cart, a fenced garden, birches and cornflowers.
local function slavs(sx, sz, parent)
	local hx, hz = sx * HALL_A, sz * HALL_B
	local frame = CFrame.lookAt(world(hx, 0, hz), world(hx, 0, hz - sz))
	local W, D, H = 60, 46, 18
	local function rel(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local LOG = Color3.fromRGB(170, 130, 95)
	mk("Foundation", Vector3.new(W + 3, 2, D + 3), rel(0, 1, 0), "px_cobblestone", nil, parent)
	mk("HallFloor", Vector3.new(W - 2, 0.4, D - 2), rel(0, 2.2, 0), "px_spruce_planks", nil, parent)
	-- log walls: horizontal round logs up to the roof, the door gap in the front wall
	for row = 0, 8 do
		local y = 2 + 1 + row * 2
		for _, s in ipairs({ -1, 1 }) do
			logX("WallLog", D + 2, 2, rel(s * W / 2, y, 0) * CFrame.Angles(0, math.pi / 2, 0), "px_oak_log", LOG, parent)
		end
		logX("WallLog", W + 2, 2, rel(0, y, D / 2), "px_oak_log", LOG, parent)
		if row >= 5 then
			logX("WallLog", W + 2, 2, rel(0, y, -D / 2), "px_oak_log", LOG, parent)
		else
			for _, s in ipairs({ -1, 1 }) do
				logX("WallLog", W / 2 - 5, 2, rel(s * (W / 4 + 2.5), y, -D / 2), "px_oak_log", LOG, parent)
			end
		end
	end
	-- carved white window frames (наличники) with blue panes and teal shutters
	local windows = {}
	for _, z in ipairs({ -12, 0, 12 }) do
		table.insert(windows, { -W / 2 - 1.1, z, math.pi / 2 })
		table.insert(windows, { W / 2 + 1.1, z, -math.pi / 2 })
	end
	for _, x in ipairs({ -18, 18 }) do
		table.insert(windows, { x, -D / 2 - 1.1, 0 })
		table.insert(windows, { x, D / 2 + 1.1, math.pi })
	end
	for _, w in ipairs(windows) do
		local cf = rel(w[1], 9, w[2]) * CFrame.Angles(0, w[3], 0)
		mk("WindowPane", Vector3.new(3.4, 4, 0.3), cf, Enum.Material.Glass, Color3.fromRGB(80, 130, 190), parent).Transparency = 0.2
		mk("Nalichnik", Vector3.new(4.8, 0.6, 0.4), cf * CFrame.new(0, 2.4, 0), "px_white_wool", nil, parent)
		mk("NalichnikTop", Vector3.new(2.8, 1.1, 0.4), cf * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.pi / 4), "px_white_wool", nil, parent)
		mk("Nalichnik", Vector3.new(4.8, 0.6, 0.4), cf * CFrame.new(0, -2.3, 0), "px_white_wool", nil, parent)
		mk("Nalichnik", Vector3.new(0.5, 4.6, 0.4), cf * CFrame.new(-2.1, 0, 0), "px_white_wool", nil, parent)
		mk("Nalichnik", Vector3.new(0.5, 4.6, 0.4), cf * CFrame.new(2.1, 0, 0), "px_white_wool", nil, parent)
		mk("Shutter", Vector3.new(1.4, 4, 0.3), cf * CFrame.new(-3.1, 0, 0), "px_spruce_planks", Color3.fromRGB(140, 200, 210), parent)
		mk("Shutter", Vector3.new(1.4, 4, 0.3), cf * CFrame.new(3.1, 0, 0), "px_spruce_planks", Color3.fromRGB(140, 200, 210), parent)
	end
	-- the steep gable roof (ridge front to back), gable boards with a white carved trim
	local a = math.rad(46)
	local half = W / 2 + 3
	local slope = half / math.cos(a)
	local ridgeY = 2 + H + half * math.tan(a)
	for _, s in ipairs({ -1, 1 }) do
		mk("Roof", Vector3.new(slope, 1.2, D + 7), rel(s * half / 2, 2 + H + half * math.tan(a) / 2, 0) * CFrame.Angles(0, 0, -s * a), "px_dark_oak_planks", nil, parent)
	end
	mk("Ridge", Vector3.new(2.4, 2.4, D + 8), rel(0, ridgeY + 0.6, 0), "px_spruce_planks", nil, parent)
	for _, zEnd in ipairs({ -D / 2 - 0.6, D / 2 + 0.6 }) do
		local step = (ridgeY - 2 - H) / 12
		for k = 0, 11 do
			local w = (W + 2) * (1 - k / 12)
			mk("Gable", Vector3.new(w, step + 0.05, 1), rel(0, 2 + H + k * step + step / 2, zEnd), "px_spruce_planks", nil, parent)
		end
		for _, s in ipairs({ -1, 1 }) do
			mk("GableTrim", Vector3.new(slope, 0.7, 0.5), rel(s * half / 2, 2 + H + half * math.tan(a) / 2, zEnd + (if zEnd < 0 then -0.6 else 0.6)) * CFrame.Angles(0, 0, -s * a), "px_white_wool", nil, parent)
		end
		-- a round attic window in the gable
		local attic = mk("AtticWindow", Vector3.new(0.4, 5, 5), rel(0, 2 + H + 7, zEnd + (if zEnd < 0 then -0.4 else 0.4)) * CFrame.Angles(0, math.pi / 2, 0), Enum.Material.Glass, Color3.fromRGB(80, 130, 190), parent)
		attic.Shape = Enum.PartType.Cylinder
	end
	mk("Konyok", Vector3.new(1.4, 3.6, 5), rel(0, ridgeY + 2.4, -D / 2 - 4) * CFrame.Angles(-0.5, 0, 0), "px_spruce_planks", nil, parent)
	-- the porch: wide steps, carved posts, a little gable roof
	for k = 0, 2 do
		mk("PorchStep", Vector3.new(16 - k * 2, 0.8, 3), rel(0, 0.4 + k * 0.8, -D / 2 - 7.5 + k * 2), "px_spruce_planks", nil, parent)
	end
	for _, s in ipairs({ -1, 1 }) do
		mk("PorchPost", Vector3.new(1.4, 11, 1.4), rel(s * 6, 7.5, -D / 2 - 5), "px_white_wool", nil, parent)
		mk("PorchPostTop", Vector3.new(2, 1, 2), rel(s * 6, 13.2, -D / 2 - 5), "px_gold_block", nil, parent)
		mk("PorchRoof", Vector3.new(9.2, 1, 9), rel(s * 3.6, 15.2, -D / 2 - 4.5) * CFrame.Angles(0, 0, -s * math.rad(35)), "px_dark_oak_planks", nil, parent)
	end
	-- three onion domes on white drums rising out of the roof
	for _, d in ipairs({ { 0, 0, 9, 1.0, "px_gold_block", nil }, { -12, 8, 5.5, 0.7, "px_white_wool", Color3.fromRGB(70, 175, 190) }, { 12, 8, 5.5, 0.7, "px_white_wool", Color3.fromRGB(70, 175, 190) } }) do
		local dx, dz, size, k = d[1], d[2], d[3], d[4]
		local roofY = ridgeY - math.abs(dx) * math.tan(a)
		local drumH = if dx == 0 then 8 else (ridgeY - roofY) + 4
		local base = roofY - 1
		mk("DomeDrum", Vector3.new(size * 0.8, drumH, size * 0.8), rel(dx, base + drumH / 2, dz), "px_white_wool", nil, parent)
		mk("DomeDrumBand", Vector3.new(size * 0.85, 0.8, size * 0.85), rel(dx, base + drumH - 0.6, dz), "px_gold_block", nil, parent)
		local top = base + drumH
		ball("OnionDome", size, rel(dx, top + size * 0.4, dz), d[5], d[6], parent)
		mk("DomeNeck", Vector3.new(size * 0.3, size * 0.5, size * 0.3), rel(dx, top + size * 0.95, dz), d[5], d[6], parent)
		mk("Spire", Vector3.new(0.5, 4 * k, 0.5), rel(dx, top + size * 1.2 + 2 * k, dz), "px_gold_block", nil, parent)
		ball("SpireBall", 1.2 * k, rel(dx, top + size * 1.2 + 4 * k, dz), "px_gold_block", nil, parent)
	end
	-- inside ---------------------------------------------------------------
	local F = 2.4 -- floor top
	storage(frame, "white", W - 2, D - 2, F, parent)
	-- a red runner rug from the door to the stove, two long feast tables with benches
	rug(frame, 0, -4, 6, D - 12, F, "px_brown_wool", Color3.fromRGB(230, 120, 110), Color3.fromRGB(240, 220, 120), parent)
	for _, s in ipairs({ -1, 1 }) do
		local tx = s * 11
		mk("FeastTable", Vector3.new(5, 0.8, 22), rel(tx, F + 3.2, -2), "px_spruce_planks", nil, parent)
		mk("TableCloth", Vector3.new(4, 0.1, 21), rel(tx, F + 3.65, -2), "px_white_wool", nil, parent)
		for _, zz in ipairs({ -11, 7 }) do
			mk("TableLeg", Vector3.new(0.8, 2.8, 0.8), rel(tx, F + 1.4, zz), "px_spruce_planks", nil, parent)
		end
		for _, bx in ipairs({ -4, 4 }) do
			mk("Bench", Vector3.new(1.8, 0.7, 22), rel(tx + bx, F + 1.8, -2), "px_spruce_planks", nil, parent)
			mk("BenchLeg", Vector3.new(1.4, 1.5, 0.6), rel(tx + bx, F + 0.75, -11), "px_spruce_planks", nil, parent)
			mk("BenchLeg", Vector3.new(1.4, 1.5, 0.6), rel(tx + bx, F + 0.75, 7), "px_spruce_planks", nil, parent)
		end
		-- bread, pies, mugs on the tables
		for k = -4, 4 do
			local item = k % 3
			if item == 0 then
				ball("Bread", 1.4, rel(tx, F + 4.2, -2 + k * 2.2), Enum.Material.SmoothPlastic, Color3.fromRGB(200, 140, 70), parent)
			elseif item == 1 then
				cyl("Mug", 0.45, 1, rel(tx + 1.2, F + 3.7, -2 + k * 2.2), "px_spruce_planks", nil, parent)
			else
				cyl("Pie", 0.9, 0.5, rel(tx - 0.8, F + 3.7, -2 + k * 2.2), Enum.Material.SmoothPlastic, Color3.fromRGB(220, 160, 90), parent)
			end
		end
	end
	-- the white tiled stove (печь), firewood beside it
	local stoveX = -W / 2 + 13
	mk("Stove", Vector3.new(8, 8, 7), rel(stoveX, F + 4, D / 2 - 6), "px_white_wool", Color3.fromRGB(245, 240, 230), parent)
	mk("StoveTiles", Vector3.new(8.2, 0.8, 7.2), rel(stoveX, F + 2.5, D / 2 - 6), "px_brown_wool", Color3.fromRGB(80, 120, 200), parent)
	mk("StoveMouth", Vector3.new(3, 2.4, 0.3), rel(stoveX, F + 2.8, D / 2 - 9.6), Enum.Material.SmoothPlastic, Color3.fromRGB(30, 25, 25), parent)
	glowPart("StoveFire", Vector3.new(2.2, 1, 0.2), rel(stoveX, F + 2.4, D / 2 - 9.5), Color3.fromRGB(255, 140, 50), 12, 0.6, parent)
	mk("StoveChimney", Vector3.new(3, 8, 3), rel(stoveX, F + 12, D / 2 - 6), "px_white_wool", Color3.fromRGB(245, 240, 230), parent)
	for k = 0, 2 do
		logX("Firewood", 4, 1, rel(stoveX + 6, F + 0.5 + k * 1, D / 2 - 4) * CFrame.Angles(0, math.pi / 2, 0), "px_oak_log", nil, parent)
	end
	-- the samovar on a little table, a spinning wheel, barrels of kvass
	mk("SideTable", Vector3.new(3, 3, 3), rel(W / 2 - 9, F + 1.5, D / 2 - 6), "px_spruce_planks", nil, parent)
	cyl("Samovar", 0.9, 2.4, rel(W / 2 - 9, F + 3, D / 2 - 6), "px_gold_block", nil, parent)
	ball("SamovarTop", 1.4, rel(W / 2 - 9, F + 5.6, D / 2 - 6), "px_gold_block", nil, parent)
	local wheel = mk("SpinningWheel", Vector3.new(0.4, 3.6, 3.6), rel(W / 2 - 13, F + 3, D / 2 - 5), "px_spruce_planks", nil, parent)
	wheel.Shape = Enum.PartType.Cylinder
	mk("SpinningStand", Vector3.new(1, 2, 3), rel(W / 2 - 13, F + 1, D / 2 - 5), "px_spruce_planks", nil, parent)
	for k = 0, 1 do
		cyl("KvassBarrel", 1.4, 3, rel(8 + k * 3.4, F, D / 2 - 3), "px_oak_log", Color3.fromRGB(190, 150, 110), parent)
	end
	-- embroidered towels (рушники) high between the chests, red shields above them
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -D / 2 + 13, -D / 2 + 23, -D / 2 + 33 }) do
			local cf = rel(s * (W / 2 - 1.3), F + 9, z) * CFrame.Angles(0, s * math.pi / 2, 0)
			decorOnly(mk("Rushnik", Vector3.new(1.6, 6, 0.15), cf, "px_white_wool", nil, parent))
			decorOnly(mk("RushnikStripe", Vector3.new(1.62, 0.5, 0.17), cf * CFrame.new(0, -2, 0), "px_brown_wool", Color3.fromRGB(230, 80, 70), parent))
			decorOnly(mk("RushnikStripe", Vector3.new(1.62, 0.5, 0.17), cf * CFrame.new(0, 1.8, 0), "px_brown_wool", Color3.fromRGB(230, 80, 70), parent))
			local shield = decorOnly(mk("Shield", Vector3.new(0.4, 3.6, 3.6), rel(s * (W / 2 - 1.4), F + 14, z + 5), Enum.Material.SmoothPlastic, Color3.fromRGB(190, 40, 40), parent))
			shield.Shape = Enum.PartType.Cylinder
			decorOnly(ball("ShieldBoss", 1, rel(s * (W / 2 - 1.7), F + 14, z + 5), "px_gold_block", nil, parent))
		end
	end
	-- the bear rug in front of the stove
	mk("BearRug", Vector3.new(7, 0.15, 5), rel(-20, F + 0.08, 0), "px_brown_wool", Color3.fromRGB(120, 80, 55), parent)
	mk("BearHead", Vector3.new(2, 1.2, 1.8), rel(-20, F + 0.6, -3.4), "px_brown_wool", Color3.fromRGB(110, 72, 50), parent)
	-- wooden chandeliers with candles
	for _, z in ipairs({ -10, 8 }) do
		local ring = decorOnly(mk("Chandelier", Vector3.new(0.6, 6, 6), rel(0, F + 13, z) * CFrame.Angles(0, 0, math.pi / 2), "px_spruce_planks", nil, parent))
		ring.Shape = Enum.PartType.Cylinder
		decorOnly(mk("ChandelierChain", Vector3.new(0.2, 3, 0.2), rel(0, F + 14.8, z), IRON, IRON, parent))
		for k = 0, 5 do
			local ca = k * math.pi / 3
			decorOnly(mk("Candle", Vector3.new(0.4, 0.8, 0.4), rel(math.cos(ca) * 2.6, F + 13.7, z + math.sin(ca) * 2.6), Enum.Material.SmoothPlastic, Color3.fromRGB(245, 235, 210), parent))
		end
		light(ring, LAMP, 24, 0.7)
	end
	banner(rel(0, F + 2, D / 2 - 1.4), "px_white_wool", "px_brown_wool", parent, 10)
	indoor(frame, Vector3.new(W, H + 2, D), parent)
	claim(hx, hz, 42)

	-- the yard -----------------------------------------------------------------
	local function izba(x, z, rot)
		local f = at(x, 0, z) * CFrame.Angles(0, rot, 0)
		mk("IzbaBase", Vector3.new(16, 1.4, 14), f * CFrame.new(0, 0.7, 0), "px_cobblestone", nil, parent)
		for row = 0, 4 do
			for _, s in ipairs({ -1, 1 }) do
				logX("IzbaLog", 15, 1.8, f * CFrame.new(0, 2.3 + row * 1.8, s * 6.4), "px_oak_log", LOG, parent)
				logX("IzbaLog", 13, 1.8, f * CFrame.new(s * 7.2, 2.3 + row * 1.8, 0) * CFrame.Angles(0, math.pi / 2, 0), "px_oak_log", LOG, parent)
			end
		end
		local top = 2.3 + 4 * 1.8 + 0.9
		for _, s in ipairs({ -1, 1 }) do
			mk("IzbaRoof", Vector3.new(11.2, 0.8, 17), f * CFrame.new(s * 4.2, top + 3.4, 0) * CFrame.Angles(0, 0, -s * math.rad(40)), "px_dark_oak_planks", nil, parent)
		end
		for _, zEnd in ipairs({ -6.6, 6.6 }) do
			for k = 0, 3 do
				mk("IzbaGable", Vector3.new(15 * (1 - k / 4), 1.7, 1.6), f * CFrame.new(0, top + k * 1.7 + 0.85, zEnd), "px_spruce_planks", nil, parent)
			end
		end
		mk("IzbaWindow", Vector3.new(0.3, 2.8, 2.8), f * CFrame.new(-8.2, 5.4, 0), Enum.Material.Glass, Color3.fromRGB(80, 130, 190), parent)
		mk("IzbaFrame", Vector3.new(0.4, 0.6, 4), f * CFrame.new(-8.3, 7.2, 0), "px_white_wool", nil, parent)
		mk("IzbaDoor", Vector3.new(2.8, 5, 0.3), f * CFrame.new(0, 3.9, -7.4), "px_spruce_planks", nil, parent)
		mk("IzbaChimney", Vector3.new(2, 5, 2), f * CFrame.new(3, top + 6, 2), "px_cobblestone", nil, parent)
		claim(x, z, 13)
	end
	izba(sx * 205, sz * 70, if sz < 0 then 0 else math.pi)
	izba(sx * 95, sz * 30, math.pi / 2)
	izba(sx * 210, sz * 125, math.pi / 2)
	-- the well with a little roof
	local wx, wz = sx * 100, sz * 135
	cyl("WellRing", 3.2, 3, at(wx, 0, wz), "px_cobblestone", nil, parent)
	cyl("WellWater", 2.4, 2.6, at(wx, 0.3, wz), "px_water", nil, parent)
	for _, s in ipairs({ -1, 1 }) do
		box("WellPost", wx + s * 2.8 - 0.4, 3, wz - 0.4, wx + s * 2.8 + 0.4, 8.5, wz + 0.4, "px_spruce_planks", nil, parent)
		mk("WellRoof", Vector3.new(7.6, 0.6, 3.8), at(wx, 9.4, wz + s * 1.4) * CFrame.Angles(s * 0.6, 0, 0), "px_dark_oak_planks", nil, parent)
	end
	box("WellBeam", wx - 3.2, 8, wz - 0.3, wx + 3.2, 8.6, wz + 0.3, "px_spruce_planks", nil, parent)
	cyl("WellBucket", 0.7, 1.2, at(wx, 5, wz), "px_spruce_planks", nil, parent)
	claim(wx, wz, 6)
	-- haystacks and a hay cart
	for _, h in ipairs({ { 214, 30 }, { 218, 34 }, { 214, 38 }, { 216, 34, 4 } }) do
		local y = h[3] or 0
		box("Hay", sx * h[1] - 2, y, sz * h[2] - 2, sx * h[1] + 2, y + 4, sz * h[2] + 2, "px_hay", nil, parent)
	end
	claim(sx * 216, sz * 34, 7)
	local cx, cz = sx * 180, sz * 28
	box("CartBed", cx - 3, 1.6, cz - 5, cx + 3, 2.4, cz + 5, "px_spruce_planks", nil, parent)
	box("CartHay", cx - 2.6, 2.4, cz - 4.4, cx + 2.6, 4.6, cz + 4.4, "px_hay", nil, parent)
	for _, s in ipairs({ -1, 1 }) do
		local w = mk("CartWheel", Vector3.new(0.5, 3.2, 3.2), at(cx + s * 3.2, 1.6, cz), "px_spruce_planks", nil, parent)
		w.Shape = Enum.PartType.Cylinder
	end
	strip("CartShaft", cx, cz - 5, cx, cz - 10, 0.5, 1.2, 1.6, "px_spruce_planks", nil, parent)
	claim(cx, cz, 7)
	-- a fenced vegetable garden with cabbages
	local gx, gz = sx * 120, sz * 212
	box("Garden", gx - 12, 0, gz - 8, gx + 12, 0.4, gz + 8, "px_dirt", nil, parent)
	for k = -2, 2 do
		for j = -1, 1 do
			ball("Cabbage", 1.6, at(gx + k * 4.4, 1, gz + j * 4.4), Enum.Material.Grass, Color3.fromRGB(120, 180, 80), parent)
		end
	end
	fenceLine(gx - 13, gz - 9, gx + 13, gz - 9, parent)
	fenceLine(gx - 13, gz + 9, gx + 13, gz + 9, parent)
	fenceLine(gx - 13, gz - 9, gx - 13, gz + 9, parent)
	fenceLine(gx + 13, gz - 9, gx + 13, gz + 9, parent)
	claim(gx, gz, 16)
	-- benches by the spawn
	for _, b in ipairs({ 172, 128 }) do
		box("YardBench", sx * b - 3, 1, sz * 84 - 0.8, sx * b + 3, 1.6, sz * 84 + 0.8, "px_spruce_planks", nil, parent)
	end
	-- a birch grove with a few oaks and pines, cornflowers and chamomile
	scatter(64, 14, DMAX, 14, DMAX, 7, sx, sz, function(x, z)
		local r = rng:NextNumber()
		if r < 0.7 then
			birch(x, z, rng:NextNumber(0.85, 1.25), parent)
		elseif r < 0.88 then
			oak(x, z, rng:NextNumber(0.85, 1.15), parent)
		else
			pine(x, z, rng:NextNumber(0.9, 1.2), parent)
		end
	end)
	flowers(130, { Color3.fromRGB(80, 120, 230), Color3.fromRGB(250, 250, 245), Color3.fromRGB(250, 210, 40) }, sx, sz, parent)
end

-- Афро: a great round kraal hall — a terracotta wall painted with zigzag bands, a thatched cone roof on
-- carved posts; inside: a central fire ring, woven mats and cushions, drums, clay pots, masks, spears and
-- hides on the walls, hanging baskets. Outside: round huts, a grain store on stilts, baobabs and acacias
-- on dry savanna grass, totem poles, a fire pit with drums, a waterhole with reeds.
local function afro(sx, sz, parent)
	local hx, hz = sx * HALL_A, sz * HALL_B
	local frame = CFrame.lookAt(world(hx, 0, hz), world(hx, 0, hz - sz))
	local function rel(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local R, H = 30, 14
	cyl("HallBase", R + 2, 1.6, rel(0, 0, 0), "px_terracotta", Color3.fromRGB(200, 170, 140), parent)
	cyl("HallFloor", R - 1, 0.3, rel(0, 1.6, 0), "px_sandstone", nil, parent)
	local N = 40
	for i = 0, N - 1 do
		local a = (i + 0.5) / N * math.pi * 2
		local front = math.abs(a - math.pi * 1.5) < 0.2 -- (−Z in the frame is angle 270°)
		local seg = 2 * math.pi * R / N + 0.6
		local cf = rel(math.cos(a) * R, 0, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0)
		if front then
			mk("WallLintel", Vector3.new(seg, 4, 2.2), cf * CFrame.new(0, 1.6 + H - 2, 0), "px_terracotta", nil, parent)
		else
			mk("Wall", Vector3.new(seg, H, 2.2), cf * CFrame.new(0, 1.6 + H / 2, 0), "px_terracotta", nil, parent)
			local up = i % 2 == 0
			mk("Paint", Vector3.new(seg * 0.5, 1.6, 0.3), cf * CFrame.new(-seg * 0.25, 1.6 + H - (if up then 3.2 else 4.6), 1.2), if up then "px_white_wool" else "px_gray_wool", nil, parent)
			mk("Paint", Vector3.new(seg * 0.5, 1.6, 0.3), cf * CFrame.new(seg * 0.25, 1.6 + H - (if up then 4.6 else 3.2), 1.2), if up then "px_gray_wool" else "px_yellow_wool", nil, parent)
			mk("PaintBase", Vector3.new(seg, 0.9, 0.3), cf * CFrame.new(0, 3.4, 1.2), "px_gray_wool", nil, parent)
			if i % 5 == 2 then -- small windows
				mk("HutWindow", Vector3.new(1.6, 2.4, 2.4), cf * CFrame.new(0, 8, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(30, 22, 18), parent)
			end
		end
	end
	for k = 0, 10 do
		local r = (R + 5) * (1 - k / 11.5)
		cyl("Thatch", r, 2.2, rel(0, 1.6 + H + k * 2.1, 0), "px_hay", nil, parent)
	end
	mk("RoofSpike", Vector3.new(1.2, 6, 1.2), rel(0, 1.6 + H + 25, 0), "px_dark_oak_planks", nil, parent)
	ball("RoofKnob", 2.2, rel(0, 1.6 + H + 28.4, 0), "px_gold_block", nil, parent)
	for _, p in ipairs({ { -12, -12 }, { 12, -12 }, { -12, 12 }, { 12, 12 } }) do -- carved roof posts
		cyl("RoofPost", 1, H, rel(p[1], 1.6, p[2]), "px_dark_oak_planks", nil, parent)
		mk("PostCarving", Vector3.new(2.4, 1.2, 2.4), rel(p[1], 9, p[2]), "px_terracotta", Color3.fromRGB(255, 200, 120), parent)
	end
	for _, s in ipairs({ -1, 1 }) do -- the door frame: carved posts with masks, torches in pots
		mk("DoorPost", Vector3.new(1.6, 12, 1.6), rel(s * 4.4, 7.6, -R - 0.6), "px_dark_oak_planks", nil, parent)
		mk("Mask", Vector3.new(2, 2.8, 0.6), rel(s * 4.4, 11, -R - 1.6), "px_terracotta", Color3.fromRGB(255, 200, 120), parent)
		glowPart("MaskEye", Vector3.new(0.4, 0.4, 0.2), rel(s * 4.4 - 0.45, 11.5, -R - 1.95), Color3.fromRGB(255, 220, 90), 0, 0, parent)
		glowPart("MaskEye", Vector3.new(0.4, 0.4, 0.2), rel(s * 4.4 + 0.45, 11.5, -R - 1.95), Color3.fromRGB(255, 220, 90), 0, 0, parent)
		cyl("DoorTorchPot", 0.8, 1.2, rel(s * 7, 1.6, -R - 3), "px_terracotta", nil, parent)
		local f = glowPart("DoorTorch", Vector3.new(1, 1, 1), rel(s * 7, 3.4, -R - 3), Color3.fromRGB(255, 150, 60), 20, 1.3, parent)
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 3, 6
		fire.Parent = f
	end
	-- inside ---------------------------------------------------------------
	local F = 1.9
	storage(frame, "black", 40, 40, F, parent)
	cyl("FireRing", 3.4, 0.8, rel(0, F, -2), "px_cobblestone", nil, parent)
	local embers = glowPart("Embers", Vector3.new(4.4, 0.4, 4.4), rel(0, F + 0.8, -2), Color3.fromRGB(255, 120, 40), 22, 0.9, parent)
	local fire = Instance.new("Fire")
	fire.Size, fire.Heat = 5, 9
	fire.Parent = embers
	-- woven mats with cushions round the fire, drums, pots
	local MAT_COLORS = { Color3.fromRGB(210, 90, 40), Color3.fromRGB(240, 190, 60), Color3.fromRGB(60, 60, 60), Color3.fromRGB(150, 60, 40) }
	for k = 0, 5 do
		local a = k * math.pi / 3 + 0.3
		local mx, mz = math.cos(a) * 8, -2 + math.sin(a) * 8
		mk("WovenMat", Vector3.new(4, 0.12, 3), rel(mx, F + 0.06, mz) * CFrame.Angles(0, -a, 0), Enum.Material.Fabric, MAT_COLORS[k % 4 + 1], parent)
		mk("MatStripe", Vector3.new(4.02, 0.24, 0.6), rel(mx, F + 0.12, mz) * CFrame.Angles(0, -a, 0), Enum.Material.Fabric, MAT_COLORS[(k + 2) % 4 + 1], parent)
		mk("Cushion", Vector3.new(1.8, 0.8, 1.8), rel(mx * 1.15, F + 0.5, -2 + (mz + 2) * 1.15), Enum.Material.Fabric, MAT_COLORS[(k + 1) % 4 + 1], parent)
	end
	for _, d in ipairs({ { -6, 10 }, { 6, 10 }, { 0, 12 } }) do
		cyl("Drum", 1.1, 2.6, rel(d[1], F, d[2]), "px_dark_oak_planks", nil, parent)
		cyl("DrumSkin", 1.15, 0.2, rel(d[1], F + 2.6, d[2]), Enum.Material.Fabric, Color3.fromRGB(225, 200, 160), parent)
		cyl("DrumBand", 1.18, 0.4, rel(d[1], F + 1, d[2]), Enum.Material.Fabric, Color3.fromRGB(200, 70, 40), parent)
	end
	for _, p in ipairs({ { -11, 0 }, { -11, 5 }, { 11, 0 }, { 11, 5 }, { -10, -14 }, { 10, -14 } }) do
		cyl("ClayPot", 1, 2, rel(p[1], F, p[2]), "px_terracotta", nil, parent)
		cyl("PotNeck", 0.6, 0.6, rel(p[1], F + 2, p[2]), "px_terracotta", Color3.fromRGB(220, 180, 150), parent)
	end
	-- masks, crossed spears and hides on the wall above the chests
	for k = 0, 9 do
		local a = math.pi * 0.62 + k * (math.pi * 1.76 / 9)
		local wx, wz = math.cos(a) * (R - 1.4), math.sin(a) * (R - 1.4)
		local face = CFrame.lookAt(rel(wx, F + 10, wz).Position, rel(0, F + 10, 0).Position)
		if k % 3 == 0 then
			decorOnly(mk("WallMask", Vector3.new(2, 2.8, 0.4), face, "px_terracotta", Color3.fromRGB(255, 200, 120), parent))
			decorOnly(mk("WallMaskStripe", Vector3.new(2.02, 0.4, 0.42), face * CFrame.new(0, -0.6, 0), Enum.Material.SmoothPlastic, Color3.fromRGB(240, 240, 230), parent))
		elseif k % 3 == 1 then
			decorOnly(mk("Spear", Vector3.new(0.3, 7, 0.3), face * CFrame.Angles(0, 0, 0.5), "px_dark_oak_planks", nil, parent))
			decorOnly(mk("Spear", Vector3.new(0.3, 7, 0.3), face * CFrame.Angles(0, 0, -0.5), "px_dark_oak_planks", nil, parent))
			decorOnly(ball("SpearShield", 2.6, face * CFrame.new(0, 0, 0.3), "px_brown_wool", Color3.fromRGB(240, 230, 210), parent))
		else
			decorOnly(mk("Hide", Vector3.new(3.4, 3.8, 0.15), face * CFrame.Angles(0, 0, 0.1), "px_brown_wool", Color3.fromRGB(220, 170, 110), parent))
		end
	end
	-- hanging baskets
	for _, p in ipairs({ { -8, -12 }, { 8, -12 }, { 0, 4 } }) do
		decorOnly(mk("BasketRope", Vector3.new(0.15, 3, 0.15), rel(p[1], F + 13, p[2]), Enum.Material.Fabric, Color3.fromRGB(140, 110, 70), parent))
		decorOnly(cyl("Basket", 1, 1.2, rel(p[1], F + 10.6, p[2]), "px_hay", nil, parent))
	end
	banner(rel(0, F, R - 7), "px_gray_wool", "px_yellow_wool", parent, 11)
	indoor(frame, Vector3.new(R * 2, H + 4, R * 2), parent)
	claim(hx, hz, R + 10)

	-- the savanna ------------------------------------------------------------------
	groundRect("Savanna", sx < 0 and -DMAX - 4 or 8, sx < 0 and -8 or DMAX + 4, sz < 0 and -DMAX - 4 or 8, sz < 0 and -8 or DMAX + 4, 0, 0.2, "px_grass_top", Color3.fromRGB(235, 205, 120), parent, LOCAL_HOLE)
	local function hut(x, z, r)
		cyl("HutWall", r, 6.5, at(x, 0.2, z), "px_terracotta", Color3.fromRGB(230, 200, 170), parent)
		cyl("HutBand", r + 0.1, 1, at(x, 4.2, z), "px_gray_wool", nil, parent)
		for k = 0, 5 do
			cyl("HutThatch", (r + 1.8) * (1 - k / 6.5), 1.6, at(x, 6.7 + k * 1.6, z), "px_hay", nil, parent)
		end
		local dir = Vector3.new(-x, 0, -z).Unit
		mk("HutDoor", Vector3.new(2.6, 4.4, 0.4), CFrame.lookAt(world(x, 2.4, z) + dir * (r - 0.1), world(x, 2.4, z) + dir * (r + 1)), Enum.Material.SmoothPlastic, DARK, parent)
		claim(x, z, r + 4)
	end
	for _, h in ipairs({ { 205, 75, 6 }, { 95, 35, 6.5 }, { 212, 125, 5.5 }, { 125, 38, 5 }, { 185, 30, 6 } }) do
		hut(sx * h[1], sz * h[2], h[3])
	end
	-- the grain store on stilts
	local gx, gz = sx * 212, sz * 212
	for _, c in ipairs({ { -2.5, -2.5 }, { 2.5, -2.5 }, { -2.5, 2.5 }, { 2.5, 2.5 } }) do
		box("Stilt", gx + c[1] - 0.4, 0, gz + c[2] - 0.4, gx + c[1] + 0.4, 4, gz + c[2] + 0.4, "px_dark_oak_planks", nil, parent)
	end
	cyl("Granary", 3.6, 5, at(gx, 4, gz), "px_terracotta", nil, parent)
	for k = 0, 3 do
		cyl("GranaryRoof", 4.6 * (1 - k / 4.5), 1.4, at(gx, 9 + k * 1.4, gz), "px_hay", nil, parent)
	end
	claim(gx, gz, 7)
	-- the fire pit with drums and log seats, by the spawn
	local fx, fz = sx * 110, sz * 92
	cyl("FireRing", 3, 0.8, at(fx, 0.2, fz), "px_cobblestone", nil, parent)
	local pit = glowPart("Embers", Vector3.new(4, 0.4, 4), at(fx, 1, fz), Color3.fromRGB(255, 120, 40), 28, 1.6, parent)
	local pitFire = Instance.new("Fire")
	pitFire.Size, pitFire.Heat = 5, 7
	pitFire.Parent = pit
	for k = 0, 2 do
		local a = k * 2.1
		logX("LogSeat", 5, 1.4, at(fx + math.cos(a) * 6, 0.9, fz + math.sin(a) * 6) * CFrame.Angles(0, -a + math.pi / 2, 0), "px_oak_log", nil, parent)
		cyl("Drum", 0.9, 2.2, at(fx + math.cos(a + 1) * 6.5, 0.2, fz + math.sin(a + 1) * 6.5), "px_dark_oak_planks", nil, parent)
		cyl("DrumSkin", 0.95, 0.2, at(fx + math.cos(a + 1) * 6.5, 2.4, fz + math.sin(a + 1) * 6.5), Enum.Material.Fabric, Color3.fromRGB(225, 200, 160), parent)
	end
	claim(fx, fz, 9)
	-- the waterhole with reeds
	local px, pz = sx * 62, sz * 95
	box("WaterholeBed", px - 10, 0, pz - 6, px + 10, 0.25, pz + 6, Color3.fromRGB(70, 60, 40), nil, parent)
	local water = box("Waterhole", px - 9, 0.25, pz - 5, px + 9, 0.7, pz + 5, "px_water", nil, parent)
	water.Transparency, water.CanCollide = 0.3, false
	for _ = 1, 10 do
		decorOnly(mk("Reed", Vector3.new(0.3, rng:NextNumber(2, 4), 0.3), at(px + rng:NextNumber(-10, 10), 1.4, pz + (if rng:NextNumber() < 0.5 then -6 else 6)), Enum.Material.Grass, Color3.fromRGB(140, 150, 70), parent))
	end
	claim(px, pz, 12)
	-- totem poles
	local function totem(x, z)
		local colors = { Color3.fromRGB(200, 70, 40), Color3.fromRGB(240, 190, 60), Color3.fromRGB(60, 60, 60), Color3.fromRGB(230, 230, 220), Color3.fromRGB(200, 70, 40) }
		for k = 0, 4 do
			box("Totem", x - 1.4, k * 3, z - 1.4, x + 1.4, k * 3 + 3, z + 1.4, "px_dark_oak_planks", nil, parent)
			local face = Vector3.new(-x, 0, -z).Unit
			mk("TotemFace", Vector3.new(2.2, 1.4, 0.3), CFrame.lookAt(world(x, k * 3 + 1.8, z) + face * 1.5, world(x, k * 3 + 1.8, z) + face * 3), Enum.Material.SmoothPlastic, colors[k + 1], parent)
		end
		mk("TotemWings", Vector3.new(8, 1, 1.2), at(x, 15.5, z), "px_dark_oak_planks", nil, parent)
		claim(x, z, 3)
	end
	totem(sx * 78, sz * 72)
	totem(sx * 222, sz * 175)
	totem(sx * 175, sz * 222)
	-- baobabs and acacias, dry grass
	local function baobab(x, z)
		cyl("BaobabTrunk", 4, 16, at(x, 0, z), "px_oak_log", Color3.fromRGB(200, 170, 140), parent)
		for k = 0, 5 do
			local a = k * 1.05
			mk("BaobabBranch", Vector3.new(1.4, 7, 1.4), at(x + math.cos(a) * 3, 18.5, z + math.sin(a) * 3) * CFrame.Angles(math.cos(a) * 0.6, 0, math.sin(a) * -0.6), "px_oak_log", Color3.fromRGB(200, 170, 140), parent)
			leafCube(x + math.cos(a) * 5.4, 22, z + math.sin(a) * 5.4, 4.6, Color3.fromRGB(110, 140, 60), parent)
		end
	end
	local function acacia(x, z)
		local lean = rng:NextNumber(0, math.pi * 2)
		mk("AcaciaTrunk", Vector3.new(1.6, 10, 1.6), at(x, 4.9, z) * CFrame.Angles(math.cos(lean) * 0.25, 0, math.sin(lean) * 0.25), "px_oak_log", Color3.fromRGB(180, 140, 110), parent)
		local tx, tz = x + math.sin(lean) * -2.2, z + math.cos(lean) * 2.2
		mk("AcaciaCanopy", Vector3.new(15, 1.6, 13), at(tx, 10.6, tz), Enum.Material.Grass, Color3.fromRGB(120, 150, 55), parent)
		mk("AcaciaCanopy", Vector3.new(10, 1.4, 9), at(tx + 1, 11.9, tz - 1), Enum.Material.Grass, Color3.fromRGB(140, 165, 65), parent)
	end
	scatter(7, 20, DMAX - 6, 20, DMAX - 6, 12, sx, sz, baobab)
	scatter(32, 16, DMAX, 16, DMAX, 8, sx, sz, acacia)
	scatter(170, 14, DMAX, 14, DMAX, 1, sx, sz, function(x, z)
		decorOnly(mk("DryGrass", Vector3.new(0.3, rng:NextNumber(1.2, 2.6), 0.3), at(x, 1, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3)), Enum.Material.Grass, Color3.fromRGB(210, 180, 90), parent))
	end)
end

-- Азиаты: a three-tier pagoda on a stone terrace — red columns, paper walls in dark frames, stepped tile
-- roofs with upturned corners, lanterns, a gold finial; inside: a tatami floor, low tables with cushions and
-- tea sets, folding screens, bonsai, a gong, a golden dragon, scrolls, a katana rack, paper lanterns.
-- Outside: a torii gate, a koi pond with an arched bridge, stone lanterns, cherry trees, bamboo, a zen
-- garden, a tea house.
local function asians(sx, sz, parent)
	local hx, hz = sx * HALL_A, sz * HALL_B
	local frame = CFrame.lookAt(world(hx, 0, hz), world(hx, 0, hz - sz))
	local function rel(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local RED = Color3.fromRGB(180, 40, 35)
	local TILE = Color3.fromRGB(95, 100, 115)
	local W, D = 56, 44
	mk("Terrace", Vector3.new(W + 10, 2.4, D + 10), rel(0, 1.2, 0), "px_smooth_stone", nil, parent)
	for k = 0, 1 do
		mk("TerraceStep", Vector3.new(18 - k * 2, 1.2, 3), rel(0, 0.6 + k * 1.2, -D / 2 - 7.5 + k * 2.5), "px_smooth_stone", nil, parent)
	end
	mk("HallFloor", Vector3.new(W, 0.4, D), rel(0, 2.6, 0), "px_spruce_planks", nil, parent)
	local function tier(w, d, y0, h, roofOver, withWalls)
		for _, cx in ipairs({ -w / 2, w / 2 }) do
			for cz = -d / 2, d / 2 + 0.01, d / 4 do
				mk("Column", Vector3.new(1.6, h, 1.6), rel(cx, y0 + h / 2, cz), Enum.Material.SmoothPlastic, RED, parent)
			end
		end
		for cx = -w / 2 + w / 4, w / 2 - w / 4 + 0.01, w / 4 do
			for _, cz in ipairs({ -d / 2, d / 2 }) do
				mk("Column", Vector3.new(1.6, h, 1.6), rel(cx, y0 + h / 2, cz), Enum.Material.SmoothPlastic, RED, parent)
			end
		end
		if withWalls then
			for _, s in ipairs({ -1, 1 }) do
				mk("PaperWall", Vector3.new(0.6, h - 4, d - 1.6), rel(s * w / 2, y0 + 2 + (h - 4) / 2, 0), "px_white_wool", Color3.fromRGB(250, 245, 230), parent)
				mk("WallPanel", Vector3.new(0.8, 2, d - 1.6), rel(s * w / 2, y0 + 1, 0), "px_dark_oak_planks", nil, parent)
				for lz = -d / 2 + 3, d / 2 - 3, 3 do
					decorOnly(mk("Lattice", Vector3.new(0.3, h - 4, 0.25), rel(s * (w / 2 + 0.45), y0 + 2 + (h - 4) / 2, lz), "px_dark_oak_planks", nil, parent))
				end
				decorOnly(mk("LatticeBar", Vector3.new(0.3, 0.25, d - 1.6), rel(s * (w / 2 + 0.45), y0 + 2 + (h - 4) * 0.5, 0), "px_dark_oak_planks", nil, parent))
			end
			mk("PaperWall", Vector3.new(w - 1.6, h - 4, 0.6), rel(0, y0 + 2 + (h - 4) / 2, d / 2), "px_white_wool", Color3.fromRGB(250, 245, 230), parent)
			mk("WallPanel", Vector3.new(w - 1.6, 2, 0.8), rel(0, y0 + 1, d / 2), "px_dark_oak_planks", nil, parent)
			for _, s in ipairs({ -1, 1 }) do
				mk("PaperWall", Vector3.new(w / 2 - 8, h - 4, 0.6), rel(s * (w / 4 + 4), y0 + 2 + (h - 4) / 2, -d / 2), "px_white_wool", Color3.fromRGB(250, 245, 230), parent)
				mk("WallPanel", Vector3.new(w / 2 - 8, 2, 0.8), rel(s * (w / 4 + 4), y0 + 1, -d / 2), "px_dark_oak_planks", nil, parent)
			end
		end
		mk("Beam", Vector3.new(w + 2, 1.4, d + 2), rel(0, y0 + h + 0.7, 0), Enum.Material.SmoothPlastic, RED, parent)
		mk("BeamGold", Vector3.new(w + 2.6, 0.3, d + 2.6), rel(0, y0 + h + 0.2, 0), "px_gold_block", nil, parent)
		local layers = 4
		for k = 0, layers - 1 do
			local ow, od = w + roofOver * 2 - k * (roofOver * 0.9), d + roofOver * 2 - k * (roofOver * 0.9)
			mk("RoofTiles", Vector3.new(ow, 1.1, od), rel(0, y0 + h + 1.4 + k * 1.1 + 0.55, 0), "px_roof_tiles", TILE, parent)
		end
		for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			local ex, ez = c[1] * (w / 2 + roofOver - 0.5), c[2] * (d / 2 + roofOver - 0.5)
			mk("Eave", Vector3.new(2.6, 1, 2.6), rel(ex, y0 + h + 2.4, ez) * CFrame.Angles(c[2] * 0.45, 0, -c[1] * 0.45), "px_roof_tiles", TILE, parent)
			mk("EaveTip", Vector3.new(1, 1, 1), rel(ex + c[1] * 1.2, y0 + h + 3.3, ez + c[2] * 1.2), "px_gold_block", nil, parent)
			local lx, lz = c[1] * (w / 2 + roofOver * 0.5), c[2] * (d / 2 + roofOver * 0.5)
			decorOnly(mk("LanternCord", Vector3.new(0.15, 1.4, 0.15), rel(lx, y0 + h - 0.6, lz), Enum.Material.Fabric, DARK, parent))
			local l = decorOnly(cyl("PaperLantern", 1, 2, rel(lx, y0 + h - 3.4, lz), Enum.Material.Neon, Color3.fromRGB(255, 190, 60), parent))
			light(l, Color3.fromRGB(255, 200, 80), 16, 1)
		end
		return y0 + h + 1.4 + layers * 1.1
	end
	local y1 = tier(W, D, 2.8, 14, 7, true)
	mk("Floor2", Vector3.new(W - 18, 9, D - 14), rel(0, y1 + 4.5, 0), "px_white_wool", Color3.fromRGB(250, 245, 230), parent)
	local y2 = tier(W - 18, D - 14, y1, 9, 5, false)
	mk("Floor3", Vector3.new(W - 32, 8, D - 26), rel(0, y2 + 4, 0), "px_white_wool", Color3.fromRGB(250, 245, 230), parent)
	local y3 = tier(W - 32, D - 26, y2, 8, 4, false)
	for k = 0, 4 do
		cyl("Finial", 1.4 - k * 0.22, 2.2, rel(0, y3 + k * 2.2, 0), "px_gold_block", nil, parent)
	end
	ball("FinialTop", 1.8, rel(0, y3 + 11.6, 0), "px_gold_block", nil, parent)
	-- inside ---------------------------------------------------------------
	local F = 2.8
	storage(frame, "yellow", W - 2, D - 2, F, parent)
	-- tatami mats in dark borders
	for i = -2, 2 do
		for j = -2, 1 do
			mk("Tatami", Vector3.new(7.6, 0.18, 3.6), rel(i * 8, F + 0.09, -6 + j * 4), "px_hay", Color3.fromRGB(215, 220, 150), parent)
			mk("TatamiEdge", Vector3.new(7.8, 0.06, 3.8), rel(i * 8, F + 0.03, -6 + j * 4), Enum.Material.Fabric, Color3.fromRGB(40, 50, 40), parent)
		end
	end
	-- low tables with cushions and tea sets
	for _, t in ipairs({ { -12, -8 }, { 12, -8 }, { 0, 2 } }) do
		mk("LowTable", Vector3.new(6, 0.6, 4), rel(t[1], F + 1.6, t[2]), "px_dark_oak_planks", nil, parent)
		for _, c in ipairs({ { -2.4, -1.6 }, { 2.4, -1.6 }, { -2.4, 1.6 }, { 2.4, 1.6 } }) do
			mk("TableFoot", Vector3.new(0.5, 1.3, 0.5), rel(t[1] + c[1], F + 0.65, t[2] + c[2]), "px_dark_oak_planks", nil, parent)
		end
		for _, c in ipairs({ { -4.4, Color3.fromRGB(200, 50, 50) }, { 4.4, Color3.fromRGB(240, 200, 50) } }) do
			mk("Cushion", Vector3.new(2.4, 0.7, 2.4), rel(t[1] + c[1], F + 0.4, t[2]), Enum.Material.Fabric, c[2], parent)
		end
		cyl("Teapot", 0.6, 0.9, rel(t[1], F + 1.9, t[2]), Enum.Material.SmoothPlastic, Color3.fromRGB(60, 100, 80), parent)
		for k = -1, 1, 2 do
			cyl("TeaCup", 0.3, 0.4, rel(t[1] + k * 1.6, F + 1.9, t[2] + 0.8), Enum.Material.SmoothPlastic, Color3.fromRGB(245, 245, 240), parent)
		end
	end
	-- the golden dragon on a dais at the back
	mk("Dais", Vector3.new(14, 1.2, 6), rel(0, F + 0.6, D / 2 - 11), "px_dark_oak_planks", nil, parent)
	local dragonY = F + 1.2
	for k = 0, 6 do -- the dragon's body: a winding chain of gold blocks
		mk("DragonBody", Vector3.new(1.6, 1.6, 1.6), rel(math.sin(k * 0.9) * 3, dragonY + 1 + k * 0.9, D / 2 - 11 + math.cos(k * 0.9) * 1.2), "px_gold_block", nil, parent)
	end
	local headX = math.sin(6.3) * 3
	mk("DragonHead", Vector3.new(2.6, 2, 3), rel(headX, dragonY + 7.4, D / 2 - 12.8), "px_gold_block", nil, parent)
	for _, s in ipairs({ -1, 1 }) do
		mk("DragonHorn", Vector3.new(0.4, 1.6, 0.4), rel(headX + s * 0.8, dragonY + 8.8, D / 2 - 12.4) * CFrame.Angles(0.4, 0, s * 0.3), "px_gold_block", nil, parent)
		glowPart("DragonEye", Vector3.new(0.4, 0.4, 0.2), rel(headX + s * 0.7, dragonY + 7.8, D / 2 - 14.35), Color3.fromRGB(255, 60, 40), 0, 0, parent)
	end
	-- the gong
	for _, s in ipairs({ -1, 1 }) do
		mk("GongPost", Vector3.new(0.8, 9, 0.8), rel(-12 + s * 3.4, F + 4.5, D / 2 - 9), Enum.Material.SmoothPlastic, RED, parent)
	end
	mk("GongBar", Vector3.new(7.6, 0.8, 0.8), rel(-12, F + 9, D / 2 - 9), Enum.Material.SmoothPlastic, RED, parent)
	local gong = mk("Gong", Vector3.new(0.4, 5, 5), rel(-12, F + 5.6, D / 2 - 9) * CFrame.Angles(0, math.pi / 2, 0), "px_gold_block", Color3.fromRGB(230, 170, 70), parent)
	gong.Shape = Enum.PartType.Cylinder
	-- bonsai on stands
	for _, p in ipairs({ { 12, D / 2 - 9 }, { 18, -D / 2 + 6 }, { -18, -D / 2 + 6 } }) do
		mk("BonsaiStand", Vector3.new(2.4, 2.6, 2.4), rel(p[1], F + 1.3, p[2]), "px_dark_oak_planks", nil, parent)
		cyl("BonsaiPot", 1, 0.8, rel(p[1], F + 2.6, p[2]), Enum.Material.SmoothPlastic, Color3.fromRGB(70, 90, 140), parent)
		mk("BonsaiTrunk", Vector3.new(0.4, 2, 0.4), rel(p[1], F + 4.2, p[2]) * CFrame.Angles(0, 0, 0.3), "px_dark_oak_planks", nil, parent)
		mk("BonsaiLeaves", Vector3.new(2.6, 1, 2), rel(p[1] - 0.5, F + 5.4, p[2]), Enum.Material.Grass, Color3.fromRGB(70, 130, 60), parent)
	end
	-- folding screens with painted cranes and mountains
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 3 do
			local cf = rel(s * (16 + k * 2.1), F + 3, D / 2 - 15) * CFrame.Angles(0, (k % 2) * 0.5 - 0.25, 0)
			mk("ScreenPanel", Vector3.new(2.2, 6, 0.2), cf, "px_white_wool", Color3.fromRGB(250, 240, 215), parent)
			decorOnly(mk("ScreenPaint", Vector3.new(1.2, 1.4, 0.22), cf * CFrame.new(0, (k - 1.5) * 0.6, 0), Enum.Material.SmoothPlastic, if k % 2 == 0 then Color3.fromRGB(60, 70, 90) else Color3.fromRGB(200, 60, 50), parent))
		end
	end
	-- hanging scrolls on the walls and a katana rack
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -D / 2 + 14, -D / 2 + 26 }) do
			local cf = rel(s * (W / 2 - 1.1), F + 9, z + 4.5) * CFrame.Angles(0, s * math.pi / 2, 0)
			decorOnly(mk("Scroll", Vector3.new(2.2, 5, 0.15), cf, "px_white_wool", Color3.fromRGB(250, 240, 215), parent))
			decorOnly(mk("ScrollRod", Vector3.new(2.8, 0.3, 0.3), cf * CFrame.new(0, 2.6, 0), "px_dark_oak_planks", nil, parent))
			decorOnly(mk("ScrollInk", Vector3.new(0.5, 3, 0.17), cf, Enum.Material.SmoothPlastic, Color3.fromRGB(25, 25, 25), parent))
		end
	end
	mk("KatanaRack", Vector3.new(6, 0.6, 1.4), rel(12, F + 3, D / 2 - 15), "px_dark_oak_planks", nil, parent)
	for k = 0, 2 do
		mk("Katana", Vector3.new(5.4, 0.25, 0.25), rel(12, F + 3.6 + k * 0.7, D / 2 - 15), Enum.Material.Metal, Color3.fromRGB(200, 200, 210), parent)
		mk("KatanaHilt", Vector3.new(1.4, 0.35, 0.35), rel(14.4, F + 3.6 + k * 0.7, D / 2 - 15), Enum.Material.Fabric, Color3.fromRGB(30, 30, 30), parent)
	end
	-- paper lanterns over the hall
	for _, p in ipairs({ { -14, -10 }, { 14, -10 }, { -14, 8 }, { 14, 8 }, { 0, -12 } }) do
		decorOnly(mk("LanternCord", Vector3.new(0.15, 2, 0.15), rel(p[1], F + 13, p[2]), Enum.Material.Fabric, DARK, parent))
		local l = decorOnly(cyl("HallLantern", 1.3, 2.6, rel(p[1], F + 9.4, p[2]), Enum.Material.SmoothPlastic, Color3.fromRGB(235, 175, 80), parent))
		light(l, Color3.fromRGB(255, 200, 120), 20, 0.6)
	end
	banner(rel(14, F + 1.2, D / 2 - 1.4), "px_yellow_wool", "px_gray_wool", parent, 10)
	banner(rel(-14, F + 1.2, D / 2 - 1.4), "px_yellow_wool", "px_gray_wool", parent, 10)
	indoor(frame, Vector3.new(W, 16, D), parent)
	claim(hx, hz, 42)

	-- the gardens --------------------------------------------------------------------
	-- the torii gate where the trail enters the valley
	-- (it spans the path from the trail: pillars on both sides)
	local tx, tz = sx * (10 + 0.2 * (SPAWN_A - 10)), sz * (10 + 0.2 * (SPAWN_B - 10))
	local tf = CFrame.lookAt(world(tx, 0, tz), world(tx - sx * (SPAWN_A - 10), 0, tz - sz * (SPAWN_B - 10)))
	for _, s in ipairs({ -1, 1 }) do
		cyl("ToriiPillar", 1.2, 18, tf * CFrame.new(s * 9, 0, 0), Enum.Material.SmoothPlastic, RED, parent)
		mk("ToriiFoot", Vector3.new(3.2, 1.2, 3.2), tf * CFrame.new(s * 9, 0.6, 0), Enum.Material.SmoothPlastic, DARK, parent)
	end
	mk("ToriiNuki", Vector3.new(21, 1.2, 1.2), tf * CFrame.new(0, 14, 0), Enum.Material.SmoothPlastic, RED, parent)
	mk("ToriiKasagi", Vector3.new(26, 1.6, 2), tf * CFrame.new(0, 18.4, 0), Enum.Material.SmoothPlastic, DARK, parent)
	mk("ToriiShimaki", Vector3.new(23, 1.2, 1.6), tf * CFrame.new(0, 17.2, 0), Enum.Material.SmoothPlastic, RED, parent)
	mk("ToriiPlaque", Vector3.new(3, 4, 0.5), tf * CFrame.new(0, 15.6, -0.6), Enum.Material.SmoothPlastic, DARK, parent)
	for _, s in ipairs({ -1, 1 }) do
		mk("ToriiTip", Vector3.new(2.4, 1.4, 2), tf * CFrame.new(s * 13.4, 19, 0) * CFrame.Angles(0, 0, s * 0.3), Enum.Material.SmoothPlastic, DARK, parent)
	end
	claim(tx, tz, 14)
	-- the koi pond with an arched red bridge
	local px, pz = sx * 200, sz * 55
	box("PondBed", px - 16, 0, pz - 11, px + 16, 0.1, pz + 11, Color3.fromRGB(30, 60, 70), nil, parent)
	local water = box("PondWater", px - 16, 0.1, pz - 11, px + 16, 0.8, pz + 11, "px_water", nil, parent)
	water.Transparency, water.CanCollide = 0.3, false
	box("PondRim", px - 17, 0, pz - 12, px + 17, 1, pz - 11, "px_smooth_stone", nil, parent)
	box("PondRim", px - 17, 0, pz + 11, px + 17, 1, pz + 12, "px_smooth_stone", nil, parent)
	box("PondRim", px - 17, 0, pz - 11, px - 16, 1, pz + 11, "px_smooth_stone", nil, parent)
	box("PondRim", px + 16, 0, pz - 11, px + 17, 1, pz + 11, "px_smooth_stone", nil, parent)
	for k = -4, 4 do
		local y = 1.6 + (16 - k * k) * 0.22
		box("BridgeDeck", px + k * 2 - 1.05, y - 0.4, pz - 2.6, px + k * 2 + 1.05, y, pz + 2.6, "px_spruce_planks", nil, parent)
		for _, s in ipairs({ -1, 1 }) do
			box("BridgeRail", px + k * 2 - 1, y, pz + s * 2.6 - 0.25, px + k * 2 + 1, y + 1.4, pz + s * 2.6 + 0.25, Enum.Material.SmoothPlastic, RED, parent)
		end
	end
	for _ = 1, 9 do
		decorOnly(mk("Koi", Vector3.new(1.4, 0.3, 0.6), at(px + rng:NextNumber(-14, 14), 0.35, pz + rng:NextNumber(-9, 9)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Enum.Material.SmoothPlastic, if rng:NextNumber() < 0.5 then Color3.fromRGB(255, 120, 40) else Color3.fromRGB(250, 250, 245), parent))
	end
	for _ = 1, 7 do
		decorOnly(cyl("LilyPad", 1.1, 0.1, at(px + rng:NextNumber(-14, 14), 0.82, pz + rng:NextNumber(-9, 9)), Enum.Material.Grass, Color3.fromRGB(80, 150, 60), parent))
	end
	claim(px, pz, 20)
	-- stone lanterns (tōrō) along the path to the spawn
	local function toro(x, z)
		box("ToroBase", x - 1.3, 0, z - 1.3, x + 1.3, 1, z + 1.3, "px_smooth_stone", nil, parent)
		box("ToroPost", x - 0.6, 1, z - 0.6, x + 0.6, 3.6, z + 0.6, "px_smooth_stone", nil, parent)
		glowPart("ToroLight", Vector3.new(2, 1.6, 2), at(x, 4.4, z), Color3.fromRGB(255, 210, 120), 16, 1, parent)
		box("ToroRoof", x - 1.9, 5.2, z - 1.9, x + 1.9, 6, z + 1.9, "px_smooth_stone", nil, parent)
		box("ToroTop", x - 0.5, 6, z - 0.5, x + 0.5, 6.8, z + 0.5, "px_smooth_stone", nil, parent)
		claim(x, z, 3)
	end
	for t = 0.2, 0.9, 0.175 do
		local x, z = 10 + t * (SPAWN_A - 10), 10 + t * (SPAWN_B - 10)
		toro(sx * (x - 6), sz * (z + 9))
		toro(sx * (x + 5), sz * (z - 10))
	end
	-- the raked gravel garden with rocks
	local gx, gz = sx * 212, sz * 120
	box("ZenGarden", gx - 11, 0, gz - 16, gx + 11, 0.3, gz + 16, "px_gravel", Color3.fromRGB(235, 235, 230), parent)
	for _ = 1, 4 do
		mk("ZenRock", Vector3.new(rng:NextNumber(2, 4), rng:NextNumber(1.5, 3.4), rng:NextNumber(2, 3.4)), at(gx + rng:NextNumber(-7, 7), 1, gz + rng:NextNumber(-12, 12)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), "px_stone", nil, parent)
	end
	claim(gx, gz, 18)
	-- a small tea house by the pond
	local hx2, hz2 = sx * 100, sz * 150
	box("TeaBase", hx2 - 7, 0, hz2 - 6, hx2 + 7, 1.2, hz2 + 6, "px_smooth_stone", nil, parent)
	for _, c in ipairs({ { -6, -5 }, { 6, -5 }, { -6, 5 }, { 6, 5 } }) do
		box("TeaColumn", hx2 + c[1] - 0.5, 1.2, hz2 + c[2] - 0.5, hx2 + c[1] + 0.5, 8, hz2 + c[2] + 0.5, Enum.Material.SmoothPlastic, RED, parent)
	end
	box("TeaWall", hx2 - 6, 1.2, hz2 + 4.6, hx2 + 6, 7, hz2 + 5, "px_white_wool", Color3.fromRGB(250, 245, 230), parent)
	for k = 0, 2 do
		box("TeaRoof", hx2 - 9 + k * 2.4, 8 + k, hz2 - 8 + k * 2.4, hx2 + 9 - k * 2.4, 9 + k, hz2 + 8 - k * 2.4, "px_roof_tiles", TILE, parent)
	end
	claim(hx2, hz2, 11)
	-- bamboo clumps and cherry trees
	local function bamboo(x, z)
		for _ = 1, 8 do
			local bx, bz = x + rng:NextNumber(-2.4, 2.4), z + rng:NextNumber(-2.4, 2.4)
			local h = rng:NextNumber(13, 20)
			decorOnly(cyl("Bamboo", 0.35, h, at(bx, 0, bz), Enum.Material.SmoothPlastic, Color3.fromRGB(110, 165, 60), parent))
			for y = 3, h - 1, 3 do
				decorOnly(cyl("BambooNode", 0.42, 0.3, at(bx, y, bz), Enum.Material.SmoothPlastic, Color3.fromRGB(85, 130, 45), parent))
			end
			decorOnly(mk("BambooLeaf", Vector3.new(2.6, 0.2, 0.8), at(bx + 1, h - 1, bz) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.3), Enum.Material.Grass, Color3.fromRGB(110, 170, 60), parent))
		end
	end
	scatter(16, 14, DMAX, 185, DMAX, 6, sx, sz, bamboo)
	local function cherry(x, z)
		local s = rng:NextNumber(0.9, 1.25)
		local h = 8 * s
		box("CherryTrunk", x - 0.9 * s, 0, z - 0.9 * s, x + 0.9 * s, h, z + 0.9 * s, "px_dark_oak_planks", Color3.fromRGB(190, 150, 150), parent)
		local pink, pink2 = Color3.fromRGB(255, 175, 205), Color3.fromRGB(250, 145, 185)
		local top = leafCube(x, h + 1.6, z, 9 * s, pink, parent)
		for k = 1, 4 do
			local a = k * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
			leafCube(x + math.cos(a) * 3.6 * s, h + rng:NextNumber(0, 1.6), z + math.sin(a) * 3.6 * s, 5.5 * s, if k % 2 == 0 then pink2 else pink, parent)
		end
		local petals = Instance.new("ParticleEmitter")
		petals.Rate = 1.5
		petals.Lifetime = NumberRange.new(5, 8)
		petals.Speed = NumberRange.new(0.5, 1.2)
		petals.Acceleration = Vector3.new(0.3, -1.2, 0.2)
		petals.SpreadAngle = Vector2.new(180, 180)
		petals.Size = NumberSequence.new(0.25)
		petals.Rotation = NumberRange.new(0, 360)
		petals.RotSpeed = NumberRange.new(-90, 90)
		petals.Color = ColorSequence.new(Color3.fromRGB(255, 190, 215))
		petals.Parent = top
	end
	scatter(44, 16, DMAX, 16, DMAX, 7, sx, sz, cherry)
	flowers(70, { Color3.fromRGB(255, 200, 220), Color3.fromRGB(250, 250, 245) }, sx, sz, parent)
end

-- Латиносы: a stepped temple pyramid (sandstone and mossy stone bricks) with a shrine and fire braziers
-- on top and a great hall inside its base: carved columns, a golden sun idol on an altar, treasure,
-- braziers, painted murals, woven rugs, serpent statues, hanging vines. Outside: palms and jungle trees,
-- mossy ruins and stelae, a hacienda market with striped awnings and flag strings, a fountain, cacti.
local function latinos(sx, sz, parent)
	local hx, hz = sx * HALL_A, sz * HALL_B
	local frame = CFrame.lookAt(world(hx, 0, hz), world(hx, 0, hz - sz))
	local function rel(x, y, z)
		return frame * CFrame.new(x, y, z)
	end
	local W, D = 66, 56
	local TIERS = 7
	local TH = 6 -- tier height
	for k = 0, TIERS - 1 do
		local w, d = W - k * 8, D - k * 7
		local mat = if k % 2 == 0 then "px_sandstone" else "px_mossy_stone_bricks"
		local band = Color3.fromRGB(170, 150, 120)
		local y0 = k * TH
		if k < 2 then
			-- the two lowest tiers are hollow: they hold the hall (walls only, the door in the middle)
			-- (front and back walls fit between the side walls: overlapping walls flickered at the corners)
			mk("Tier", Vector3.new(w - 6, TH, 3), rel(0, y0 + TH / 2, d / 2 - 1.5), mat, nil, parent)
			for _, s in ipairs({ -1, 1 }) do
				mk("Tier", Vector3.new(3, TH, d), rel(s * (w / 2 - 1.5), y0 + TH / 2, 0), mat, nil, parent)
				mk("Tier", Vector3.new(w / 2 - 7.5, TH, 3), rel(s * (4.5 + (w / 2 - 7.5) / 2), y0 + TH / 2, -d / 2 + 1.5), mat, nil, parent)
			end
			if k == 1 then
				mk("Tier", Vector3.new(9, 3, 3), rel(0, y0 + TH - 1.5, -d / 2 + 1.5), mat, nil, parent)
			end
			-- the bands stop just under the tier's top face and never overlap each other (no shared faces)
			mk("TierBand", Vector3.new(w - 0.8, 0.8, 0.6), rel(0, y0 + TH - 0.5, d / 2), "px_stone_bricks", band, parent)
			for _, s in ipairs({ -1, 1 }) do
				mk("TierBand", Vector3.new(0.6, 0.8, d + 0.4), rel(s * w / 2, y0 + TH - 0.5, 0), "px_stone_bricks", band, parent)
				mk("TierBand", Vector3.new(w / 2 - 7.5, 0.8, 0.6), rel(s * (4.5 + (w / 2 - 7.5) / 2), y0 + TH - 0.5, -d / 2), "px_stone_bricks", band, parent)
			end
		else
			mk("Tier", Vector3.new(w, TH, d), rel(0, y0 + TH / 2, 0), mat, nil, parent)
			mk("TierBand", Vector3.new(w + 0.4, 0.8, d + 0.4), rel(0, y0 + TH - 0.5, 0), "px_stone_bricks", band, parent)
		end
		-- carved glyph blocks along the front of every tier
		for g = -2, 2 do
			if math.abs(g) >= 1 or k >= 2 then
				mk("Glyph", Vector3.new(1.6, 1.6, 0.3), rel(g * (w / 6), y0 + TH / 2 - 0.3, -d / 2 - 0.2), Enum.Material.SmoothPlastic, Color3.fromRGB(60, 110, 70), parent)
			end
		end
	end
	mk("HallCeiling", Vector3.new(W - 8, 1, D - 8), rel(0, 2 * TH + 0.4, 0), "px_sandstone", nil, parent)
	mk("HallFloor", Vector3.new(W - 6, 0.4, D - 6), rel(0, 0.2, 0), "px_smooth_stone", Color3.fromRGB(230, 210, 170), parent)
	-- two solid staircases up the front face, one on each side of the door, to the top tier
	local steps = TIERS * TH
	local zFrom, zTo = -D / 2 - 6, -(D - (TIERS - 1) * 7) / 2
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, steps - 1 do
			local z = zFrom + k * (zTo - zFrom) / steps
			mk("Stair", Vector3.new(5, k + 1.07, 1.4), rel(s * 8.5, (k + 1.07) / 2, z), "px_sandstone", nil, parent)
		end
		mk("SerpentHead", Vector3.new(3.6, 3.6, 5), rel(s * 8.5, 1.8, zFrom - 3), "px_mossy_stone_bricks", nil, parent)
		mk("SerpentJaw", Vector3.new(3.8, 1, 1.6), rel(s * 8.5, 0.7, zFrom - 6), "px_mossy_stone_bricks", nil, parent)
		glowPart("SerpentEye", Vector3.new(0.7, 0.7, 0.7), rel(s * 8.5 + 1.5, 2.9, zFrom - 4.6), Color3.fromRGB(80, 255, 140), 0, 0, parent)
		glowPart("SerpentEye", Vector3.new(0.7, 0.7, 0.7), rel(s * 8.5 - 1.5, 2.9, zFrom - 4.6), Color3.fromRGB(80, 255, 140), 0, 0, parent)
	end
	-- the shrine on top with a roof comb and two fire braziers
	local topY = TIERS * TH
	local sw, sd = W - (TIERS - 1) * 8 - 3, D - (TIERS - 1) * 7 - 3
	mk("Shrine", Vector3.new(sw, 8, sd), rel(0, topY + 4, 1), "px_sandstone", nil, parent)
	mk("ShrineDoor", Vector3.new(3.4, 5, 0.4), rel(0, topY + 2.5, 1 - sd / 2 - 0.1), Enum.Material.SmoothPlastic, DARK, parent)
	mk("RoofComb", Vector3.new(sw - 2, 6, 1.6), rel(0, topY + 11, 1), "px_mossy_stone_bricks", nil, parent)
	for i = -2, 2 do
		mk("CombHole", Vector3.new(1.1, 2.4, 1.7), rel(i * 2.8, topY + 11, 1), Enum.Material.SmoothPlastic, DARK, parent)
	end
	for _, s in ipairs({ -1, 1 }) do
		local bowl = mk("Brazier", Vector3.new(2.8, 1.6, 2.8), rel(s * (sw / 2 + 1.2), topY + 0.8, -sd / 2), "px_gold_block", nil, parent)
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 6, 9
		fire.Parent = bowl
		light(bowl, Color3.fromRGB(255, 150, 70), 34, 1.7)
	end
	-- inside ---------------------------------------------------------------
	local F = 0.4
	storage(frame, "latino", W - 8, D - 8, F, parent)
	-- carved stone columns in two rows
	for _, s in ipairs({ -1, 1 }) do
		for z = -14, 14, 14 do
			mk("Column", Vector3.new(2.6, 2 * TH - 0.4, 2.6), rel(s * 14, F + TH - 0.2, z), "px_mossy_stone_bricks", nil, parent)
			mk("ColumnCap", Vector3.new(3.4, 1, 3.4), rel(s * 14, F + 2 * TH - 1.4, z), "px_sandstone", nil, parent)
			mk("ColumnFace", Vector3.new(1.4, 1.4, 0.2), rel(s * 14, F + 6, z - 1.4), Enum.Material.SmoothPlastic, Color3.fromRGB(60, 110, 70), parent)
		end
	end
	-- the altar with the golden sun idol at the back
	mk("AltarStep", Vector3.new(16, 1, 7), rel(0, F + 0.5, D / 2 - 16), "px_sandstone", nil, parent)
	mk("Altar", Vector3.new(8, 3, 4), rel(0, F + 2.5, D / 2 - 16), "px_mossy_stone_bricks", nil, parent)
	local sun = mk("SunDisc", Vector3.new(0.6, 7, 7), rel(0, F + 8, D / 2 - 13.6) * CFrame.Angles(0, math.pi / 2, 0), "px_gold_block", nil, parent)
	sun.Shape = Enum.PartType.Cylinder
	for k = 0, 11 do
		local a = k * math.pi / 6
		mk("SunRay", Vector3.new(0.8, 2.2, 0.5), rel(math.cos(a) * 4.6, F + 8 + math.sin(a) * 4.6, D / 2 - 13.6) * CFrame.Angles(0, 0, a - math.pi / 2), "px_gold_block", nil, parent)
	end
	light(sun, Color3.fromRGB(255, 210, 120), 12, 0.5)
	-- treasure: gold blocks round the altar
	for _ = 1, 14 do
		local x, z = rng:NextNumber(-7, 7), D / 2 - 16 + rng:NextNumber(-5, 3)
		if math.abs(x) > 4.4 or z < D / 2 - 19 then
			mk("Gold", Vector3.new(1.2, 0.8, 1.2), rel(x, F + 0.4 + rng:NextInteger(0, 1) * 0.8, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), "px_gold_block", nil, parent)
		end
	end
	-- fire braziers between the columns
	for _, s in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -8, 8 }) do
			mk("BrazierStand", Vector3.new(1.4, 3, 1.4), rel(s * 8, F + 1.5, z), "px_sandstone", nil, parent)
			local b = mk("HallBrazier", Vector3.new(2.2, 1, 2.2), rel(s * 8, F + 3.5, z), "px_gold_block", nil, parent)
			local fire = Instance.new("Fire")
			fire.Size, fire.Heat = 3, 6
			fire.Parent = b
			light(b, Color3.fromRGB(255, 160, 80), 18, 0.7)
		end
	end
	-- painted murals on the side walls above the chests
	local MURAL = { Color3.fromRGB(200, 60, 40), Color3.fromRGB(240, 190, 50), Color3.fromRGB(50, 130, 120), Color3.fromRGB(230, 220, 200) }
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 7 do
			decorOnly(mk("Mural", Vector3.new(0.15, 2, 3.4), rel(s * 25.9, F + 8 + (k % 2) * 1.2, -D / 2 + 10 + k * 4.6), Enum.Material.SmoothPlastic, MURAL[k % 4 + 1], parent))
		end
	end
	-- woven striped rugs down the middle
	for k = 0, 3 do
		rug(frame, 0, -16 + k * 7, 7, 5, F, Enum.Material.Fabric, MURAL[k % 4 + 1], MURAL[(k + 2) % 4 + 1], parent)
	end
	-- serpent statues at the door and hanging vines
	for _, s in ipairs({ -1, 1 }) do
		mk("SerpentStatue", Vector3.new(2.4, 5, 2.4), rel(s * 6.5, F + 2.5, -D / 2 + 7), "px_mossy_stone_bricks", nil, parent)
		mk("SerpentStatueHead", Vector3.new(2.6, 2.2, 3.6), rel(s * 6.5, F + 6, -D / 2 + 6.4), "px_mossy_stone_bricks", nil, parent)
	end
	for _ = 1, 16 do
		local x, z = rng:NextNumber(-(W - 12) / 2, (W - 12) / 2), rng:NextNumber(-(D - 12) / 2, (D - 12) / 2)
		local len = rng:NextNumber(2, 5)
		decorOnly(mk("Vine", Vector3.new(0.3, len, 0.3), rel(x, 2 * TH - len / 2, z), Enum.Material.Grass, Color3.fromRGB(60, 130, 50), parent))
	end
	banner(rel(12, F, D / 2 - 5), "px_brown_wool", "px_gold_block", parent, 10)
	banner(rel(-12, F, D / 2 - 5), "px_brown_wool", "px_gold_block", parent, 10)
	indoor(frame, Vector3.new(W - 6, 2 * TH, D - 6), parent)
	claim(hx, hz, 46)

	-- the jungle -------------------------------------------------------------------
	groundRect("JungleGrass", sx < 0 and -DMAX - 4 or 8, sx < 0 and -8 or DMAX + 4, sz < 0 and -DMAX - 4 or 8, sz < 0 and -8 or DMAX + 4, 0, 0.2, "px_grass_top", Color3.fromRGB(170, 215, 140), parent, LOCAL_HOLE)
	-- the hacienda market: stalls with striped awnings, pots, a flag string
	local mx, mz = sx * 105, sz * 45
	local stripes = { Color3.fromRGB(220, 60, 50), Color3.fromRGB(250, 200, 50), Color3.fromRGB(60, 160, 90), Color3.fromRGB(70, 120, 210) }
	for k = 0, 3 do
		local x = mx + sx * (k - 1.5) * 15
		box("Stall", x - 4.5, 0, mz - 2.8, x + 4.5, 3, mz + 2.8, "px_terracotta", nil, parent)
		for _, s in ipairs({ -1, 1 }) do
			box("StallPost", x + s * 4 - 0.4, 3, mz + 2.2 - 0.4, x + s * 4 + 0.4, 9.5, mz + 2.2 + 0.4, "px_spruce_planks", nil, parent)
			box("StallPost", x + s * 4 - 0.4, 3, mz - 2.2 - 0.4, x + s * 4 + 0.4, 9.5, mz - 2.2 + 0.4, "px_spruce_planks", nil, parent)
		end
		for st = 0, 3 do
			mk("Awning", Vector3.new(2.35, 0.4, 7.4), at(x - 3.5 + st * 2.35, 9.7, mz) * CFrame.Angles(0.15, 0, 0), Enum.Material.Fabric, stripes[(st + k) % 4 + 1], parent)
		end
		for p = 0, 2 do
			cyl("Pot", 0.7, 1.2, at(x - 2.6 + p * 2.6, 3, mz - 1), "px_terracotta", nil, parent)
			ball("Fruit", 0.9, at(x - 2.6 + p * 2.6, 4.5, mz - 1), Enum.Material.SmoothPlastic, stripes[(p + k + 1) % 4 + 1], parent)
		end
		claim(x, mz, 8)
	end
	for f = 0, 19 do
		local x = mx - sx * 30 + sx * f * 3.1
		decorOnly(mk("PapelPicado", Vector3.new(1.6, 1.8, 0.1), at(x, 11.5 - math.sin(f / 19 * math.pi) * 1.6, mz + sz * 6), Enum.Material.Fabric, stripes[f % 4 + 1], parent))
	end
	strip("FlagString", mx - sx * 31, mz + sz * 6, mx + sx * 31, mz + sz * 6, 0.1, 12.1, 12.2, DARK, nil, parent)
	-- the fountain on the little square by the spawn
	local fx, fz = sx * 195, sz * 62
	cyl("FountainBasin", 6, 1.4, at(fx, 0, fz), "px_sandstone", nil, parent)
	local fw = cyl("FountainWater", 5.2, 0.4, at(fx, 1.1, fz), "px_water", nil, parent)
	fw.Transparency = 0.25
	cyl("FountainPillar", 1, 5, at(fx, 1.4, fz), "px_mossy_stone_bricks", nil, parent)
	cyl("FountainBowl", 2.4, 0.8, at(fx, 6.4, fz), "px_sandstone", nil, parent)
	local spray = Instance.new("ParticleEmitter")
	spray.Rate = 30
	spray.Lifetime = NumberRange.new(0.8, 1.2)
	spray.Speed = NumberRange.new(6, 8)
	spray.SpreadAngle = Vector2.new(15, 15)
	spray.Acceleration = Vector3.new(0, -18, 0)
	spray.Size = NumberSequence.new(0.3)
	spray.Color = ColorSequence.new(Color3.fromRGB(170, 220, 255))
	spray.Transparency = NumberSequence.new(0.3)
	spray.Parent = fw
	claim(fx, fz, 8)
	-- mossy ruins: stelae and broken columns
	local function stela(x, z)
		box("Stela", x - 1.8, 0, z - 0.9, x + 1.8, 8, z + 0.9, "px_mossy_stone_bricks", nil, parent)
		box("StelaGlyph", x - 1.1, 4.5, z - 1, x + 1.1, 6.8, z - 0.9, Enum.Material.SmoothPlastic, Color3.fromRGB(70, 100, 60), parent)
		claim(x, z, 3)
	end
	local function brokenColumn(x, z)
		local h = rng:NextNumber(3, 10)
		cyl("RuinColumn", 1.5, h, at(x, 0, z), "px_mossy_stone_bricks", nil, parent)
		mk("RuinBlock", Vector3.new(3, 2, 3), at(x + 2.6, 1, z + 1) * CFrame.Angles(0, rng:NextNumber(0, 1), 0.3), "px_mossy_cobblestone", nil, parent)
		claim(x, z, 4)
	end
	stela(sx * 78, sz * 72)
	stela(sx * 215, sz * 110)
	stela(sx * 110, sz * 215)
	scatter(8, 20, DMAX - 6, 20, DMAX - 6, 6, sx, sz, brokenColumn)
	-- palms, jungle trees with vines, cacti and ferns
	local function palm(x, z)
		local lean = rng:NextNumber(0, math.pi * 2)
		local px, pz = x, z
		for k = 0, 6 do
			px += math.cos(lean) * 0.35 * k
			pz += math.sin(lean) * 0.35 * k
			box("PalmTrunk", px - 0.8, k * 2.4, pz - 0.8, px + 0.8, k * 2.4 + 2.4, pz + 0.8, "px_oak_log", Color3.fromRGB(190, 160, 120), parent)
		end
		local top = 16.8
		for k = 0, 6 do
			local a = k * math.pi * 2 / 7
			mk("PalmLeaf", Vector3.new(1.6, 0.4, 9), at(px + math.cos(a) * 4, top - 0.8, pz + math.sin(a) * 4) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(0.35, 0, 0), Enum.Material.Grass, Color3.fromRGB(70, 150, 55), parent)
		end
		ball("Coconut", 1, at(px + 0.6, top - 1, pz), Enum.Material.SmoothPlastic, Color3.fromRGB(110, 75, 40), parent)
	end
	local function jungleTree(x, z)
		local h = rng:NextNumber(16, 22)
		box("JungleTrunk", x - 1.8, 0, z - 1.8, x + 1.8, h, z + 1.8, "px_oak_log", Color3.fromRGB(150, 140, 110), parent)
		leafCube(x, h + 2, z, 13, Color3.fromRGB(55, 120, 45), parent)
		leafCube(x + 4.4, h, z - 3, 8, Color3.fromRGB(70, 140, 50), parent)
		leafCube(x - 4.4, h + 1, z + 3, 8, Color3.fromRGB(55, 120, 45), parent)
		for _ = 1, 6 do
			local len = rng:NextNumber(4, 9)
			decorOnly(mk("Vine", Vector3.new(0.3, len, 0.3), at(x + rng:NextNumber(-6, 6), h - len / 2, z + rng:NextNumber(-6, 6)), Enum.Material.Grass, Color3.fromRGB(60, 130, 50), parent))
		end
	end
	scatter(34, 16, DMAX, 16, DMAX, 7, sx, sz, palm)
	scatter(20, 20, DMAX - 4, 20, DMAX - 4, 10, sx, sz, jungleTree)
	scatter(8, 60, 150, 20, 70, 4, sx, sz, function(x, z)
		local h = rng:NextNumber(4, 7)
		box("Cactus", x - 0.8, 0, z - 0.8, x + 0.8, h, z + 0.8, Enum.Material.Grass, Color3.fromRGB(70, 140, 60), parent)
		box("CactusArm", x + 0.8, h * 0.5, z - 0.5, x + 2.4, h * 0.5 + 1, z + 0.5, Enum.Material.Grass, Color3.fromRGB(70, 140, 60), parent)
		box("CactusArm", x + 1.6, h * 0.5 + 1, z - 0.5, x + 2.4, h * 0.5 + 3, z + 0.5, Enum.Material.Grass, Color3.fromRGB(70, 140, 60), parent)
	end)
	scatter(150, 14, DMAX, 14, DMAX, 1.5, sx, sz, function(x, z)
		decorOnly(mk("Fern", Vector3.new(2.4, 0.3, 0.8), at(x, 0.6, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0.25), Enum.Material.Grass, Color3.fromRGB(70, 145, 55), parent))
	end)
	flowers(70, { Color3.fromRGB(255, 80, 60), Color3.fromRGB(255, 160, 40), Color3.fromRGB(230, 60, 160) }, sx, sz, parent)
end

local FACTIONS = {
	{ id = "white", name = "Славяне", sx = -1, sz = -1, color = Color3.fromRGB(255, 255, 255), cloth = "px_white_wool", accent = "px_brown_wool", build = slavs, leaf = Color3.fromRGB(85, 140, 55), grass = Color3.fromRGB(90, 150, 60) },
	{ id = "black", name = "Афро", sx = 1, sz = -1, color = Color3.fromRGB(150, 150, 150), cloth = "px_gray_wool", accent = "px_yellow_wool", build = afro, leaf = Color3.fromRGB(130, 150, 60), grass = Color3.fromRGB(205, 175, 90) },
	{ id = "yellow", name = "Азиаты", sx = 1, sz = 1, color = Color3.fromRGB(255, 255, 0), cloth = "px_yellow_wool", accent = "px_gray_wool", build = asians, leaf = Color3.fromRGB(80, 140, 70), grass = Color3.fromRGB(95, 155, 70) },
	{ id = "latino", name = "Латиносы", sx = -1, sz = 1, color = Color3.fromRGB(205, 120, 80), cloth = "px_brown_wool", accent = "px_gold_block", build = latinos, leaf = Color3.fromRGB(55, 125, 45), grass = Color3.fromRGB(70, 150, 55) },
}
for _, f in ipairs(FACTIONS) do
	local district = Instance.new("Folder")
	district.Name = "District_" .. f.id
	district.Parent = root
	local sx, sz = f.sx, f.sz
	-- the district's own origin, and fresh keep-out claims for its decor
	FX, FZ = BASE_X + sx * OFF, BASE_Z + sz * OFF
	table.clear(claims)
	-- keep the trail's end, the paths and the mountain edge free
	for t = 0, 1, 0.1 do
		claim(sx * (10 + t * 20), sz * (10 + t * 20), 14)
		claim(sx * (30 + t * (SPAWN_A - 30)), sz * (30 + t * (SPAWN_B - 30)), 9)
		claim(sx * (SPAWN_A + t * (MINE_A - SPAWN_A)), sz * (SPAWN_B + t * (122 - SPAWN_B)), 5)
	end
	claim(sx * SPAWN_A, sz * ((SPAWN_B + HALL_B) / 2 - 10), 8)
	-- the shared pieces first (they claim their ground), then the faction's own architecture and nature
	miniMine(sx * MINE_A, sz * MINE_B, f.id, district)
	spawnPad(sx * SPAWN_A, sz * SPAWN_B, sx * HALL_A, sz * HALL_B, f.id, f.cloth, district)
	monument(sx * 62, sz * 22, f.name, f.color, f.cloth, f.accent, district)
	npc(
		"Buyer_" .. f.id,
		"SellPoint",
		CFrame.lookAt(world(sx * MINE_A, 4, sz * 122), world(sx * SPAWN_A, 4, sz * SPAWN_B)),
		"Скупщик блоков",
		Color3.fromRGB(255, 55, 55),
		Color3.fromRGB(198, 140, 100),
		Color3.fromRGB(70, 70, 80),
		Color3.fromRGB(50, 45, 40),
		district
	)
	claim(sx * MINE_A, sz * 122, 6)
	-- the paths: the trail continues to the spawn, the spawn to the hall door, a side path to the buyer
	strip("Path", sx * 10, sz * 10, sx * SPAWN_A, sz * SPAWN_B, 12, 0, 0.62, "px_stone_bricks", Color3.fromRGB(230, 225, 215), district)
	strip("Path", sx * SPAWN_A, sz * SPAWN_B, sx * SPAWN_A, sz * (HALL_B - 26), 8, 0, 0.55, "px_gravel", nil, district)
	strip("Path", sx * SPAWN_A, sz * SPAWN_B, sx * MINE_A, sz * 125, 6, 0, 0.5, "px_gravel", nil, district)
	f.build(sx, sz, district)
	dress(sx, sz, district, f.leaf, f.grass)
	-- banners along the main path
	for t = 0.3, 0.9, 0.3 do
		local x, z = 10 + t * (SPAWN_A - 10), 10 + t * (SPAWN_B - 10)
		banner(at(sx * (x - 5), 0, sz * (z + 8)) * CFrame.Angles(0, math.atan2(sx, sz), 0), f.cloth, f.accent, district, 10)
		banner(at(sx * (x + 4), 0, sz * (z - 9)) * CFrame.Angles(0, math.atan2(sx, sz), 0), f.cloth, f.accent, district, 10)
	end
end
FX, FZ = BASE_X, BASE_Z

local count = 0
for _, x in ipairs(root:GetDescendants()) do
	if x:IsA("BasePart") then
		count += 1
	end
end
return "[build-fraction-base] done, parts: " .. count
