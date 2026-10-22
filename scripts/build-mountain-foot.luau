--!nocheck
-- Builds the Подножье горы (mountain foot), level 5 [меню]. «Суровый климат истощает силы рабочих, и задерживаются
-- здесь обычно не более пары месяцев» [клиент]. Blocks: red sand 91 %, iron ore 6 %, gold ore 3 % [меню].
-- [владелец 22.10: «дизайнерский шедевр, максимум усилий, черпай идеи в интернете»] Ideas: the badlands — banded
-- terracotta canyon walls stepping back in terraces, hoodoos and a natural arch, an open-pit mine with scaffolds and
-- a crane, a mining camp of convicts (tents, campfire, water tower, wind pump, wagon), a dry ravine with a rope
-- bridge; the boss is «древний страж, закованный в цепи» [клиент] — so a ruined labyrinth leads to a broken
-- colosseum where the Minotaur sleeps chained to four pillars. Behind the canyon rises the snowy mountain itself.
--   * terrain on an 8-stud grid: the valley floor (red sand dunes, worn trails), the canyon walls (terracotta strata
--     6 studs thick, tinted orange / red / yellow / pale / brown, a red sand cap on every terrace), the ravine
--     (strata walls down to −30), scree at the foot of the cliffs;
--   * the mountain to the north: stepped rock with a snow cap, far above the canyon rim.
-- A separate zone at X = 2400 (StreamingEnabled). Run in Studio (Edit) via scripts/studio-loader.luau after
-- build-textures. Idempotent: replaces Workspace.MountainFoot. Arrival: LocationSpawn, LocationId "mountain_foot".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)
local old = workspace:FindFirstChild("MountainFoot")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "MountainFoot"
root.Parent = workspace

local BX, BZ = 2400, 0
local B = 4
local rng = Random.new(20261024)
local STONE = Color3.fromRGB(150, 140, 130)
local WOOD = Color3.fromRGB(120, 85, 50)
local DRYWOOD = Color3.fromRGB(150, 120, 85)
local IRON = Color3.fromRGB(70, 66, 64)
local ROPE = Color3.fromRGB(170, 140, 95)
local CANVAS = Color3.fromRGB(225, 210, 175)
local LAMP = Color3.fromRGB(255, 190, 110)
local BONE = Color3.fromRGB(232, 224, 205)
local BEDROCK = Color3.fromRGB(70, 52, 44)

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
local function light(p, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color
	l.Shadows = false
	l.Parent = p
	return l
end
local function folder(name)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 24)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = false -- a place label sits over its place, never through the canyon walls
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
-- text painted on a board (a signpost arrow, a carved lintel): on the given faces, not floating in the air
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
		label.Size = UDim2.fromScale(0.92, 0.84)
		label.Position = UDim2.fromScale(0.04, 0.08)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(255, 235, 200)
		label.TextStrokeTransparency = 0.4
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

-- ================================================================ the plan
local VALLEY = { rx = 200, rz = 210 }
local PIT = { x = -56, z = -24, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json mountain_foot.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local CAMP = { x = 0, z = 150, r = 24 }
local ARENA = { x = 110, z = -70, r = 40 }
local LAB = { x0 = 20, x1 = 48, z0 = -96, z1 = -48 } -- the ruined labyrinth before the arena gate (west of it)
local function ravineZ(x)
	return 86 + 12 * math.sin(x / 34)
end
local RAVINE_W = 12
local RAVINE_FLOOR = -24
local BRIDGE_A = { x = -18 } -- the rope bridge on the camp → mine trail
local BRIDGE_B = { x = 56 } -- the old stone bridge on the camp → arena trail
BRIDGE_A.z, BRIDGE_B.z = ravineZ(BRIDGE_A.x), ravineZ(BRIDGE_B.x)
local TRAILS = {
	{ { CAMP.x - 4, CAMP.z - 20 }, { BRIDGE_A.x, BRIDGE_A.z + 14 }, { BRIDGE_A.x, BRIDGE_A.z - 14 }, { PIT.x + 10, PIT.z + PIT.hole + 4 } },
	{ { CAMP.x + 10, CAMP.z - 18 }, { BRIDGE_B.x, BRIDGE_B.z + 14 }, { BRIDGE_B.x, BRIDGE_B.z - 14 }, { 58, -10 }, { LAB.x1 - 6, LAB.z1 + 8 } },
	{ { LAB.x1, ARENA.z }, { ARENA.x - ARENA.r - 18, ARENA.z } },
	{ { PIT.x + PIT.hole + 4, PIT.z }, { LAB.x1 - 6, LAB.z1 + 8 } },
}

-- ================================================================ the terrain grid (8-stud cells)
local C = 8
local X0, Z0 = -280, -296 -- grid corner (x, z min)
local NX, NZ = 70, 72
local STRATA = 6 -- terracotta band thickness
local BAND = {
	Color3.fromRGB(226, 128, 70), -- orange
	Color3.fromRGB(190, 82, 56), -- red
	Color3.fromRGB(236, 190, 110), -- yellow
	Color3.fromRGB(238, 222, 196), -- pale
	Color3.fromRGB(200, 104, 64), -- orange red
	Color3.fromRGB(150, 92, 64), -- brown
	Color3.fromRGB(226, 150, 96), -- light orange
	Color3.fromRGB(176, 72, 52), -- dark red
	Color3.fromRGB(230, 206, 160), -- sand
}
local function bandColor(k)
	return BAND[(k % #BAND) + 1]
end
local cells = {}
local function valleyD(x, z)
	return math.sqrt((x / VALLEY.rx) ^ 2 + (z / VALLEY.rz) ^ 2) / (1 + n2(x, z, 2.7, 0.012) * 0.08)
end
local function inRavine(x, z)
	return math.abs(z - ravineZ(x)) < RAVINE_W + n2(x, z, 5.1, 0.06) * 3
end
local function onTrail(x, z)
	for _, t in ipairs(TRAILS) do
		if lineDist(t, x, z) < 5 + n2(x, z, 8.8, 0.15) * 1.5 then
			return true
		end
	end
	return false
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local function flat(x, z) -- places that keep a level floor
	return math.sqrt((x - CAMP.x) ^ 2 + (z - CAMP.z) ^ 2) < CAMP.r + 14
		or math.sqrt((x - ARENA.x) ^ 2 + (z - ARENA.z) ^ 2) < ARENA.r + 12
		or (x > LAB.x0 - 8 and x < LAB.x1 + 4 and z > LAB.z0 - 8 and z < LAB.z1 + 8)
		or (math.abs(x - PIT.x) < PIT.hole + 14 and math.abs(z - PIT.z) < PIT.hole + 14)
end
local function nearBridge(x, z) -- the bridge heads stay level with the deck
	for _, b in ipairs({ BRIDGE_A, BRIDGE_B }) do
		if math.abs(x - b.x) < 12 and math.abs(z - b.z) < RAVINE_W + 20 then
			return true
		end
	end
	return false
end
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local d = valleyD(x, z)
		local c = { x = x, z = z, d = d }
		if d < 1 then
			c.kind = "valley"
			if inHole(x, z) then
				c.kind = "hole"
			elseif inRavine(x, z) and not flat(x, z) then
				c.kind = "ravine"
				c.top = RAVINE_FLOOR
			else
				c.path = onTrail(x, z)
				local dune = if flat(x, z) or c.path or nearBridge(x, z) then 0 else math.clamp(math.floor(n2(x, z, 3.3, 0.03) * 2.2 + n2(x, z, 6.1, 0.1) * 1.4 + 1), 0, 3)
				c.top = dune
			end
		elseif d < 1.45 then
			-- the canyon wall: terraces stepping up with the distance from the valley, ragged by noise
			c.kind = "cliff"
			local t = math.clamp((d - 1) / 0.22, 0, 1)
			local h = 30 + 54 * t ^ 0.8 + n2(x, z, 4.4, 0.035) * 16 + n2(x, z, 9.4, 0.11) * 6
			c.top = math.max(STRATA * 4, STRATA * math.floor(h / STRATA + 0.5))
		end
		if c.kind then
			cells[ix + iz * NX] = c
		end
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
	return if c and c.kind == "valley" then c.top else 0
end
-- valley cells next to the ravine show strata down its walls
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		if c and (c.kind == "valley" or c.kind == "cliff") then
			for dz = -1, 1 do
				for dx = -1, 1 do
					local n = cellAt(ix + dx, iz + dz)
					if n and n.kind == "ravine" then
						c.ravineEdge = true
					end
				end
			end
		end
	end
end

-- ================================================================ build the terrain (runs merged along x)
local terrain = folder("Terrain")
local function floorVariant(c)
	if c.path then
		return "px_gravel", Color3.fromRGB(205, 160, 130)
	end
	local v = n2(c.x, c.z, 7.7, 0.05) + n2(c.x, c.z, 2.9, 0.13) * 0.5
	if v > 0.42 then
		return "px_terracotta_pale", Color3.fromRGB(236, 196, 150) -- bare rock showing through the sand
	elseif v > 0.28 then
		return "px_terracotta_pale", Color3.fromRGB(214, 140, 96)
	elseif v < -0.45 then
		return "px_red_sandstone", nil
	elseif v < -0.3 then
		return "px_gravel", Color3.fromRGB(205, 150, 120) -- coarse dirt
	end
	return "px_red_sand", Color3.fromRGB(228, 206, 192) -- toned down: a sun-bleached floor, the strata stay the colour
end
local count = 0
for iz = 0, NZ - 1 do
	local z0, z1 = Z0 + iz * C, Z0 + (iz + 1) * C
	-- per band of the strata, and for the floors, keep a run going along x while the same thing continues
	local runs = {}
	local function flushKey(k)
		local r = runs[k]
		if r then
			box(r.name, X0 + r.ix0 * C, r.y0, z0, X0 + (r.ix1 + 1) * C, r.y1, z1, r.variant, r.tint, terrain)
			count += 1
			runs[k] = nil
		end
	end
	local function push(ix, k, name, y0, y1, variant, tint)
		local r = runs[k]
		if r and r.ix1 == ix - 1 and r.y0 == y0 and r.y1 == y1 and r.variant == variant and r.tint == tint then
			r.ix1 = ix
			return
		end
		flushKey(k)
		runs[k] = { ix0 = ix, ix1 = ix, name = name, y0 = y0, y1 = y1, variant = variant, tint = tint }
	end
	local seen = {}
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		local used = {}
		if c then
			if c.kind == "valley" then
				local v, tint = floorVariant(c)
				local base = if c.ravineEdge then -6 else -8
				push(ix, "floor", "Ground", base, c.top, v, tint)
				used.floor = true
				if c.ravineEdge then
					for k = 0, 3 do
						local y0 = -30 + k * STRATA
						push(ix, "s" .. k, "Strata", y0, y0 + STRATA, "px_terracotta_pale", bandColor(k + 3))
						used["s" .. k] = true
					end
				end
			elseif c.kind == "ravine" then
				push(ix, "floor", "RavineBed", -32, RAVINE_FLOOR, "px_gravel", Color3.fromRGB(190, 140, 110))
				used.floor = true
			elseif c.kind == "cliff" then
				local topK = math.floor(c.top / STRATA) - 1
				for k = if c.ravineEdge then -5 else -1, topK do
					local y0, y1 = k * STRATA, (k + 1) * STRATA
					if k == topK then
						push(ix, "s" .. k, "MesaCap", y0, y1 - 1, "px_terracotta_pale", bandColor(k + 3))
						push(ix, "cap", "MesaSand", y1 - 1, y1, "px_red_sand", nil)
						used.cap = true
					else
						push(ix, "s" .. k, "Strata", y0, y1, "px_terracotta_pale", bandColor(k + 3))
					end
					used["s" .. k] = true
				end
			end
		end
		for k in pairs(runs) do
			if not used[k] then
				flushKey(k)
			end
		end
		seen = used
	end
	for k in pairs(runs) do
		flushKey(k)
	end
	if iz % 4 == 0 then
		task.wait()
	end
end
-- scree: fallen strata blocks at the foot of the canyon walls
for _, c in pairs(cells) do
	if c.kind == "valley" and c.d > 0.93 and not c.path and rng:NextNumber() < 0.35 then
		for _ = 1, rng:NextInteger(1, 3) do
			local s = rng:NextNumber(2, 4.5)
			textured(part("Scree", Vector3.new(s, s * 0.8, s), at(c.x + rng:NextNumber(-3, 3), c.top + s * 0.35, c.z + rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)), STONE, nil, terrain), "px_terracotta_pale", bandColor(rng:NextInteger(0, 8)))
		end
	end
end

-- ================================================================ the mountain behind the canyon (north)
-- a Persistent model: with streaming the far mountain would never load, and it is the backdrop of the whole valley
local mountain = Instance.new("Model")
mountain.Name = "Mountain"
mountain.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
mountain.Parent = root
do
	local MC, MX, MZ, MR = 24, 0, -600, 360
	for gz = -MR, MR, MC do
		for gx = -MR, MR, MC do
			local x, z = MX + gx, MZ + gz
			local d = math.sqrt(gx * gx + gz * gz) / MR
			if d < 1 and z < -280 then
				-- a massif, not a cone: two peaks, ridges (folded noise), gullies
				local ridge = 1 - math.abs(n2(x, z, 6.6, 0.014))
				local peak2 = math.max(0, 1 - math.sqrt((x + 170) ^ 2 + (z + 470) ^ 2) / 170)
				local h = 60 + 250 * (1 - d) ^ 1.3 + 90 * ridge * (1 - d) + 140 * peak2 ^ 1.4 + n2(x, z, 1.9, 0.05) * 18
				h = 12 * math.floor(h / 12)
				local snow = 165 + n2(x, z, 3.1, 0.03) * 25
				local rockTop = math.min(h, snow)
				-- the foot of the mountain in the canyon's own banded terracotta, grey granite higher up
				local band = math.min(rockTop, 100)
				box("MountainFoot", x - MC / 2, 0, z - MC / 2, x + MC / 2, band, z + MC / 2, "px_terracotta_pale", bandColor(math.floor(band / 12)), mountain)
				if rockTop > band then
					box("MountainRock", x - MC / 2, band, z - MC / 2, x + MC / 2, rockTop, z + MC / 2, "px_smooth_stone", Color3.fromRGB(205, 198, 192):Lerp(Color3.fromRGB(235, 232, 228), math.clamp((rockTop - 100) / 80, 0, 1)), mountain)
				end
				if h > snow then
					box("MountainSnow", x - MC / 2, rockTop, z - MC / 2, x + MC / 2, h, z + MC / 2, nil, Color3.fromRGB(245, 248, 252), mountain).Material = Enum.Material.Snow
				else
					box("MountainScree", x - MC / 2, h, z - MC / 2, x + MC / 2, h + 2, z + MC / 2, "px_gravel", Color3.fromRGB(170, 150, 135), mountain)
				end
			end
		end
	end
end

-- warm, dusty light over the valley (IndoorLighting volumes carry Ambient / Exposure for the client)
local warmModel = Instance.new("Model")
warmModel.Name = "WarmVolume"
warmModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
warmModel.Parent = root
local warm = decor(part("WarmVolume", Vector3.new(VALLEY.rx * 2.4, 260, VALLEY.rz * 2.4), at(0, 60, 0), STONE, nil, warmModel))
warm.Transparency = 1
warm:SetAttribute("Ambient", Color3.fromRGB(150, 122, 100))
warm:SetAttribute("Exposure", 0.15)
CollectionService:AddTag(warm, "IndoorLighting")

-- ================================================================ small builders
local props = folder("Props")
local function log(size, cf, parent)
	return textured(part("Log", size, cf, WOOD, nil, parent or props), "px_oak_log")
end
local function plank(size, cf, parent)
	return textured(part("Plank", size, cf, WOOD, nil, parent or props), "px_spruce_planks")
end
local function lantern(x, y, z, parent)
	part("LanternCap", Vector3.new(1.2, 0.3, 1.2), at(x, y + 0.9, z), IRON, Enum.Material.Metal, parent or props)
	local l = decor(part("Lantern", Vector3.new(0.9, 1.3, 0.9), at(x, y, z), LAMP, Enum.Material.Neon, parent or props))
	light(l, 22, 1.2, LAMP)
	return l
end
local function lampPost(x, z)
	local y = floorAt(x, z)
	log(Vector3.new(0.8, 9, 0.8), at(x, y + 4.5, z))
	log(Vector3.new(0.6, 0.6, 2.4), at(x, y + 8.6, z - 1))
	part("Hook", Vector3.new(0.15, 0.8, 0.15), at(x, y + 7.9, z - 2), IRON, Enum.Material.Metal, props)
	lantern(x, y + 6.9, z - 2)
end
local function crate(x, y, z, s, load)
	local c = textured(part("Crate", Vector3.new(s, s, s), at(x, y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), WOOD, nil, props), "px_planks")
	if load then
		textured(decor(part("CrateLoad", Vector3.new(s * 0.8, 0.3, s * 0.8), c.CFrame * CFrame.new(0, s / 2, 0), STONE, nil, props)), load)
	end
	return c
end
local function barrel(x, y, z)
	local b = part("Barrel", Vector3.new(2.8, 2.4, 2.4), at(x, y + 1.4, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(105, 72, 42), Enum.Material.Wood, props)
	b.Shape = Enum.PartType.Cylinder
	for _, dy in ipairs({ -0.9, 0.9 }) do
		local hoop = decor(part("Hoop", Vector3.new(0.3, 2.55, 2.55), b.CFrame * CFrame.new(dy, 0, 0), IRON, Enum.Material.Metal, props))
		hoop.Shape = Enum.PartType.Cylinder
	end
end
local function deadBush(x, z)
	local y = floorAt(x, z)
	for _ = 1, rng:NextInteger(4, 7) do
		local len = rng:NextNumber(1, 2.4)
		decor(part("DeadBush", Vector3.new(0.15, len, 0.15), at(x, y + len / 2 - 0.2, z) * CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 6), rng:NextNumber(-0.7, 0.7)), Color3.fromRGB(125, 90, 55), Enum.Material.Wood, props))
	end
end
local function cactus(x, z)
	local y = floorAt(x, z)
	local h = rng:NextInteger(3, 6) * 1.5
	local green = Color3.fromRGB(80, 120, 55)
	part("Cactus", Vector3.new(1.4, h, 1.4), at(x, y + h / 2, z), green, Enum.Material.Grass, props)
	part("CactusTop", Vector3.new(1.1, 0.4, 1.1), at(x, y + h + 0.2, z), Color3.fromRGB(110, 150, 70), Enum.Material.Grass, props)
	for _, side in ipairs({ -1, 1 }) do
		if rng:NextNumber() < 0.7 then
			local ay = y + rng:NextNumber(h * 0.35, h * 0.6)
			part("CactusArm", Vector3.new(1.6, 0.9, 0.9), at(x + side * 1.4, ay, z), green, Enum.Material.Grass, props)
			part("CactusArmUp", Vector3.new(0.9, 2.2, 0.9), at(x + side * 1.9, ay + 1.4, z), green, Enum.Material.Grass, props)
		end
	end
end
local function deadTree(x, z)
	local y = floorAt(x, z)
	local h = rng:NextNumber(7, 11)
	local trunk = part("DeadTrunk", Vector3.new(1, h, 1), at(x, y + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), 0, rng:NextNumber(-0.08, 0.08)), Color3.fromRGB(110, 90, 70), Enum.Material.Wood, props)
	for k = 1, 4 do
		local a = rng:NextNumber(0, 6.28)
		local len = rng:NextNumber(2.5, 4.5)
		local by = h * rng:NextNumber(0.5, 0.95) - h / 2
		decor(part("DeadBranch", Vector3.new(0.45, 0.45, len), trunk.CFrame * CFrame.new(0, by, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0.6, 0, 0) * CFrame.new(0, 0, -len / 2), Color3.fromRGB(105, 85, 65), Enum.Material.Wood, props))
		if k % 2 == 0 then
			decor(part("Twig", Vector3.new(0.25, 0.25, len * 0.5), trunk.CFrame * CFrame.new(0, by + 1, 0) * CFrame.Angles(0, a + 1, 0) * CFrame.Angles(0.9, 0, 0) * CFrame.new(0, 0, -len * 0.4), Color3.fromRGB(105, 85, 65), Enum.Material.Wood, props))
		end
	end
end
local function tumbleweed(x, z)
	local y = floorAt(x, z)
	local ball = decor(part("Tumbleweed", Vector3.new(2.4, 2.4, 2.4), at(x, y + 1.2, z), Color3.fromRGB(150, 120, 80), Enum.Material.Wood, props))
	ball.Shape = Enum.PartType.Ball
	ball.Transparency = 0.45
	for _ = 1, 6 do
		decor(part("TumbleTwig", Vector3.new(0.12, 0.12, 2.6), ball.CFrame * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0), Color3.fromRGB(130, 100, 65), Enum.Material.Wood, props))
	end
end
-- a hoodoo: a column of strata blocks narrowing upwards with a wide cap rock
local function hoodoo(x, z, h)
	local y = floorAt(x, z)
	local w = rng:NextNumber(5, 8)
	local k = 0
	while y < h do
		local seg = math.min(STRATA, h - y)
		local s = w * (1 - 0.35 * (y / h)) + rng:NextNumber(-0.4, 0.4)
		textured(part("Hoodoo", Vector3.new(s, seg, s), at(x + rng:NextNumber(-0.3, 0.3), y + seg / 2, z + rng:NextNumber(-0.3, 0.3)) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0), STONE, nil, props), "px_terracotta_pale", bandColor(math.floor(y / STRATA) + 3))
		y += seg
		k += 1
	end
	textured(part("HoodooCap", Vector3.new(w * 1.1, 3, w * 1.1), at(x, y + 1.5, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0.05), STONE, nil, props), "px_red_sandstone")
end
local function bullSkull(x, z, scale, yaw)
	local y = floorAt(x, z)
	local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local function b(name, size, offset, angles)
		local cf = base * CFrame.new(offset[1] * scale, offset[2] * scale, offset[3] * scale)
		if angles then
			cf *= CFrame.Angles(angles[1], angles[2], angles[3])
		end
		return part(name, size * scale, cf, BONE, nil, props)
	end
	b("Skull", Vector3.new(2.2, 1.6, 2.6), { 0, 1, 0 }, { -0.25, 0, 0 })
	b("Snout", Vector3.new(1.5, 1.1, 1.6), { 0, 0.6, -1.8 }, { -0.25, 0, 0 })
	for _, s in ipairs({ -1, 1 }) do
		decor(b("EyeHole", Vector3.new(0.5, 0.5, 0.1), { s * 0.6, 1.35, -1.25 }))
		part("EyeDark", Vector3.new(0.45, 0.45, 0.12) * scale, base * CFrame.new(s * 0.6 * scale, 1.35 * scale, -1.32 * scale), Color3.fromRGB(40, 30, 25), nil, props)
		b("HornBase", Vector3.new(1.4, 0.7, 0.7), { s * 1.5, 1.6, 0.2 }, { 0, 0, s * 0.2 })
		b("Horn", Vector3.new(1.4, 0.55, 0.55), { s * 2.6, 2.1, 0.1 }, { 0, 0, s * 0.6 })
		b("HornTip", Vector3.new(0.9, 0.4, 0.4), { s * 3.2, 3, -0.1 }, { 0, 0.3 * s, s * 1.1 })
	end
end

-- ================================================================ the ravine: a rope bridge and an old stone bridge
local bridges = folder("Bridges")
-- the real gap under a bridge (the ravine edge is noisy and runs at an angle): from the centre outwards until no
-- cell across the bridge width is ravine any more; the bridge heads are kept level (nearBridge in the grid)
local function gapEdges(bx, bz, halfW)
	local function ravineAt(z)
		for _, dx in ipairs({ -halfW, 0, halfW }) do
			local c = cellAtPos(bx + dx, z)
			if c and c.kind == "ravine" then
				return true
			end
		end
		return false
	end
	local zS, zN = bz, bz
	while ravineAt(zS - 0.5) do
		zS -= 1
	end
	while ravineAt(zN + 0.5) do
		zN += 1
	end
	return zS, zN
end
do
	-- the rope bridge (camp → mine): log posts on both rims, planks hanging in a curve from rim to rim, rope rails
	local bx = BRIDGE_A.x
	local zS, zN = gapEdges(bx, BRIDGE_A.z, 3)
	local z0, z1 = zS - 2, zN + 2 -- the planks rest 2 studs on the ground each side
	local mid, halfSpan = (z0 + z1) / 2, (z1 - z0) / 2
	local SAG = math.min(2, halfSpan * 0.12)
	local function sagAt(z)
		local t = (z - mid) / halfSpan
		return SAG * math.max(0, 1 - t * t)
	end
	for _, side in ipairs({ -1, 1 }) do
		for _, zEnd in ipairs({ z0 - 0.5, z1 + 0.5 }) do
			log(Vector3.new(1, 6, 1), at(bx + side * 3.2, 2.5, zEnd), bridges)
		end
		for z = z0 - 0.5, z1 - 0.5 + 1e-6 do
			part("Rope", Vector3.new(0.2, 0.2, 1.05), at(bx + side * 3.2, 4.6 - sagAt(z + 0.5) * 1.3, z + 0.5), ROPE, Enum.Material.Fabric, bridges).CanCollide = false
		end
	end
	for z = z0, z1 - 1 do
		local p = plank(Vector3.new(6, 0.35, 0.85), at(bx + rng:NextNumber(-0.15, 0.15), 0.18 - sagAt(z + 0.5), z + 0.5) * CFrame.Angles(rng:NextNumber(-0.04, 0.04), 0, rng:NextNumber(-0.04, 0.04)), bridges)
		if z > zS and z < zN - 1 and rng:NextNumber() < 0.06 then
			p.Transparency = 1 -- a missing plank (still walkable: the collider stays)
		end
	end
	-- the ropes that carry the deck, down under the planks from post to post
	for _, side in ipairs({ -1, 1 }) do
		for z = z0, z1 - 1 do
			decor(part("DeckRope", Vector3.new(0.15, 0.15, 1.02), at(bx + side * 2.8, -0.05 - sagAt(z + 0.5), z + 0.5), ROPE, Enum.Material.Fabric, bridges))
		end
	end
	-- the old stone bridge (camp → arena): a real arch — thin at the crown, springing low from both ravine walls —
	-- a level deck on top, a darker ring of voussoirs along the arch, parapets with broken gaps
	local sx = BRIDGE_B.x
	zS, zN = gapEdges(sx, BRIDGE_B.z, 4)
	local amid, ahalf = (zS + zN) / 2, (zN - zS) / 2
	local CROWN, SPRING = -3.2, RAVINE_FLOOR + 6
	local deck0, deck1 = zS - 3, zN + 3
	for z = deck0, deck1 - 1, 2 do
		local len = math.min(2, deck1 - z)
		textured(part("BridgeDeck", Vector3.new(8, 1.4, len), at(sx, -0.7, z + len / 2), STONE, nil, bridges), "px_red_sandstone")
		for _, side in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.8 then
				local hgt = rng:NextNumber(1.3, 2.3)
				textured(part("Parapet", Vector3.new(0.9, hgt, len), at(sx + side * 3.55, hgt / 2, z + len / 2), STONE, nil, bridges), "px_red_sandstone")
			end
		end
	end
	for z = zS, zN - 1 do
		local t = math.clamp((z + 0.5 - amid) / ahalf, -1, 1)
		local intrados = SPRING + (CROWN - SPRING) * math.sqrt(1 - t * t)
		local hgt = -1.4 - intrados
		textured(part("BridgeArch", Vector3.new(7, hgt, 1), at(sx, intrados + hgt / 2, z + 0.5), STONE, nil, bridges), "px_red_sandstone", Color3.fromRGB(215, 190, 170))
		textured(decor(part("ArchRing", Vector3.new(7.3, 0.9, 1), at(sx, intrados + 0.4, z + 0.5), STONE, nil, bridges)), "px_red_sandstone", Color3.fromRGB(150, 110, 95))
	end
	-- the piers the arch springs from, down to the ravine bed against both walls
	for _, z in ipairs({ zS + 1, zN - 1 }) do
		textured(part("BridgePier", Vector3.new(8, SPRING - RAVINE_FLOOR + 1, 2), at(sx, (SPRING + RAVINE_FLOOR) / 2, z), STONE, nil, bridges), "px_red_sandstone", Color3.fromRGB(190, 160, 140))
	end
end

-- ================================================================ the mining camp (arrival)
local camp = folder("Camp")
do
	local cx, cz = CAMP.x, CAMP.z
	local plaza = part("Plaza", Vector3.new(0.4, CAMP.r * 2, CAMP.r * 2), at(cx, 0.15, cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, camp)
	plaza.Shape = Enum.PartType.Cylinder
	textured(plaza, "px_gravel", Color3.fromRGB(200, 165, 135))
	local spawn = part("LocationSpawn_mountain_foot", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + cx, 0.5, BZ + cz + 6), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), STONE, nil, camp)
	textured(spawn, "px_red_sandstone")
	spawn:SetAttribute("LocationId", "mountain_foot")
	CollectionService:AddTag(spawn, "LocationSpawn")
	-- the campfire: a ring of stones, logs, embers, a pot on a tripod, log benches round it
	local fx, fz = cx - 8, cz + 2
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		textured(part("FireStone", Vector3.new(1.3, 0.9, 1.3), at(fx + math.cos(a) * 2.4, 0.45, fz + math.sin(a) * 2.4) * CFrame.Angles(0, a, 0), STONE, nil, camp), "px_cobblestone")
	end
	for k = 0, 2 do
		log(Vector3.new(0.7, 0.7, 3), at(fx, 0.6, fz) * CFrame.Angles(0, k * 1.05, 0.15), camp)
	end
	local embers = decor(part("Embers", Vector3.new(2.4, 0.3, 2.4), at(fx, 0.5, fz), Color3.fromRGB(255, 110, 40), Enum.Material.Neon, camp))
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Parent = embers
	light(embers, 28, 1.6, Color3.fromRGB(255, 150, 80))
	local smoke = Instance.new("Smoke")
	smoke.Opacity = 0.06
	smoke.RiseVelocity = 4
	smoke.Size = 3
	smoke.Parent = embers
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		part("TripodStick", Vector3.new(0.25, 5.5, 0.25), at(fx + math.cos(a) * 1.6, 2.5, fz + math.sin(a) * 1.6) * CFrame.Angles(math.sin(a) * 0.3, 0, -math.cos(a) * 0.3), WOOD, Enum.Material.Wood, camp)
	end
	part("Pot", Vector3.new(1.6, 1.3, 1.6), at(fx, 2.3, fz), IRON, Enum.Material.Metal, camp)
	for _, a in ipairs({ 0.3, 2.4, 4.4 }) do
		log(Vector3.new(0.9, 0.9, 4.5), at(fx + math.cos(a) * 5.5, 0.45, fz + math.sin(a) * 5.5) * CFrame.Angles(0, -a + math.pi / 2, 0), camp)
	end
	-- canvas tents (A-frames with a ridge pole, guy ropes, a bedroll inside)
	local function tent(x, z, yaw)
		local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
		for _, s in ipairs({ -1, 1 }) do
			decor(part("TentSide", Vector3.new(0.15, 5.4, 7), base * CFrame.new(s * 1.9, 2.1, 0) * CFrame.Angles(0, 0, s * 0.62), CANVAS:Lerp(Color3.fromRGB(180, 160, 120), rng:NextNumber(0, 0.4)), Enum.Material.Fabric, camp)).CanCollide = true
			part("GuyRope", Vector3.new(0.1, 0.1, 3), base * CFrame.new(s * 4.4, 1.5, 3.8) * CFrame.Angles(0.5, s * 0.6, 0), ROPE, Enum.Material.Fabric, camp).CanCollide = false
		end
		part("RidgePole", Vector3.new(0.3, 0.3, 7.6), base * CFrame.new(0, 4.35, 0), WOOD, Enum.Material.Wood, camp)
		for _, e in ipairs({ -3.7, 3.7 }) do
			part("TentPole", Vector3.new(0.3, 4.4, 0.3), base * CFrame.new(0, 2.2, e), WOOD, Enum.Material.Wood, camp)
		end
		decor(part("Bedroll", Vector3.new(1.6, 0.4, 4), base * CFrame.new(0.4, 0.2, -0.5), Color3.fromRGB(120, 60, 50), Enum.Material.Fabric, camp))
	end
	tent(cx + 14, cz + 8, 0.3)
	tent(cx + 16, cz - 6, -0.2)
	tent(cx - 18, cz + 14, 1.4)
	tent(cx - 4, cz + 20, 1.7)
	-- the water tower: four log legs with cross braces, a barrel tank with hoops, a ladder
	do
		local wx, wz = cx - 22, cz - 8
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			log(Vector3.new(1, 14, 1), at(wx + s[1] * 3, 7, wz + s[2] * 3) * CFrame.Angles(s[2] * 0.05, 0, -s[1] * 0.05), camp)
		end
		for _, y in ipairs({ 4, 9 }) do
			for _, side in ipairs({ -1, 1 }) do
				plank(Vector3.new(7, 0.4, 0.4), at(wx, y, wz + side * 3) * CFrame.Angles(0, 0, side * 0.5), camp)
				plank(Vector3.new(0.4, 0.4, 7), at(wx + side * 3, y, wz) * CFrame.Angles(side * 0.5, 0, 0), camp)
			end
		end
		plank(Vector3.new(8, 0.5, 8), at(wx, 14.2, wz), camp)
		local tank = part("Tank", Vector3.new(7, 7, 7), at(wx, 18, wz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(120, 85, 50), Enum.Material.WoodPlanks, camp)
		tank.Shape = Enum.PartType.Cylinder
		for _, y in ipairs({ 15.5, 18, 20.5 }) do
			local hoop = decor(part("TankHoop", Vector3.new(0.4, 7.3, 7.3), at(wx, y, wz) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, camp))
			hoop.Shape = Enum.PartType.Cylinder
		end
		local roof = part("TankRoof", Vector3.new(4, 7.6, 7.6), at(wx, 22.5, wz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 75, 45), Enum.Material.WoodPlanks, camp)
		roof.Shape = Enum.PartType.Cylinder
		roof.Size = Vector3.new(1, 6, 6)
		part("Spout", Vector3.new(0.6, 0.6, 3), at(wx + 3.5, 15, wz) * CFrame.Angles(0.5, math.pi / 2, 0), IRON, Enum.Material.Metal, camp)
		for k = 0, 13 do
			plank(Vector3.new(1.6, 0.25, 0.3), at(wx + 4.1, 0.8 + k, wz + 3), camp)
		end
		for _, dz in ipairs({ 2.3, 3.7 }) do
			part("LadderRail", Vector3.new(0.25, 14.5, 0.25), at(wx + 4.1, 7.2, wz + dz), WOOD, Enum.Material.Wood, camp)
		end
	end
	-- the wind pump: an iron lattice tower with a bladed wheel and a tail vane, a trough below
	do
		local px, pz = cx + 24, cz + 22
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			part("PumpLeg", Vector3.new(0.4, 22, 0.4), at(px + s[1] * 1.6, 11, pz + s[2] * 1.6) * CFrame.Angles(s[2] * 0.07, 0, -s[1] * 0.07), IRON, Enum.Material.Metal, camp)
		end
		for y = 3, 19, 4 do
			for _, side in ipairs({ -1, 1 }) do
				part("PumpBrace", Vector3.new(0.2, 0.2, 4.4), at(px + side * 1.4, y, pz) * CFrame.Angles(0.8, 0, 0), IRON, Enum.Material.Metal, camp)
				part("PumpBrace", Vector3.new(4.4, 0.2, 0.2), at(px, y, pz + side * 1.4) * CFrame.Angles(0, 0, 0.8), IRON, Enum.Material.Metal, camp)
			end
		end
		local hub = part("PumpHub", Vector3.new(1, 1, 1.4), at(px, 22.6, pz - 0.6), IRON, Enum.Material.Metal, camp)
		local wheel = Instance.new("Model")
		wheel.Name = "PumpWheel"
		wheel.Parent = camp
		for k = 0, 11 do
			local a = k / 12 * math.pi * 2
			local blade = part("PumpBlade", Vector3.new(0.9, 3.6, 0.1), hub.CFrame * CFrame.new(0, 0, -0.8) * CFrame.Angles(0, 0, a) * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0.35, 0), Color3.fromRGB(190, 185, 175), Enum.Material.Metal, wheel)
			blade.CanCollide = false
		end
		part("PumpTail", Vector3.new(0.15, 2.4, 4), at(px, 22.6, pz + 3), Color3.fromRGB(180, 60, 45), Enum.Material.Metal, camp)
		part("PumpTailBoom", Vector3.new(0.3, 0.3, 4), at(px, 22.6, pz + 1), IRON, Enum.Material.Metal, camp)
		part("PumpTrough", Vector3.new(6, 1.4, 2.4), at(px - 4, 0.7, pz + 1), WOOD, Enum.Material.WoodPlanks, camp)
		local water = decor(part("TroughWater", Vector3.new(5.4, 0.2, 1.8), at(px - 4, 1.3, pz + 1), Color3.fromRGB(70, 120, 150), Enum.Material.Glass, camp))
		water.Transparency = 0.3
	end
	-- the covered wagon: a bed on four spoked wheels, hoops and canvas, a yoke pole
	do
		local base = at(cx - 26, 0, cz - 24) * CFrame.Angles(0, 0.4, 0)
		plank(Vector3.new(4, 0.6, 9), base * CFrame.new(0, 2.6, 0), camp)
		for _, s in ipairs({ -1, 1 }) do
			plank(Vector3.new(0.4, 1.4, 9), base * CFrame.new(s * 2, 3.5, 0), camp)
			for _, e in ipairs({ -3, 3 }) do
				local w = part("Wheel", Vector3.new(0.4, 3.6, 3.6), base * CFrame.new(s * 2.3, 1.8, e), Color3.fromRGB(90, 60, 35), Enum.Material.Wood, camp)
				w.Shape = Enum.PartType.Cylinder
				part("Hub", Vector3.new(0.6, 0.8, 0.8), base * CFrame.new(s * 2.5, 1.8, e), IRON, Enum.Material.Metal, camp)
			end
		end
		for _, e in ipairs({ -3.5, 0, 3.5 }) do
			for k = 0, 6 do
				local a = k / 6 * math.pi
				part("Hoop", Vector3.new(0.2, 0.2, 0.9), base * CFrame.new(math.cos(a) * 2.1, 4 + math.sin(a) * 2.4, e), WOOD, Enum.Material.Wood, camp)
			end
		end
		for k = 0, 5 do
			local a = (k + 0.5) / 6 * math.pi
			decor(part("WagonCanvas", Vector3.new(1.3, 0.12, 8.6), base * CFrame.new(math.cos(a) * 2.2, 4.1 + math.sin(a) * 2.5, 0) * CFrame.Angles(0, 0, a - math.pi / 2), CANVAS, Enum.Material.Fabric, camp))
		end
		part("YokePole", Vector3.new(0.3, 0.3, 6), base * CFrame.new(0, 2, -7.2) * CFrame.Angles(0.2, 0, 0), WOOD, Enum.Material.Wood, camp)
	end
	-- the block buyer at a stall with a striped awning, sacks and crates of ore
	do
		local sx, sz = cx + 10, cz - 6
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(198, 140, 100)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(140, 90, 50), Color3.fromRGB(70, 55, 45), Color3.fromRGB(70, 55, 45)
		local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		model.Name = "MountainBuyer"
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
		model.Parent = camp
		model:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + cx, 3, BZ + cz)))
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hrp = model:FindFirstChild("HumanoidRootPart")
		CollectionService:AddTag(hrp, "SellPoint")
		sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
		local hat = part("Hat", Vector3.new(2.4, 0.2, 2.4), model.Head.CFrame * CFrame.new(0, 0.65, 0), Color3.fromRGB(150, 110, 70), Enum.Material.Fabric, model)
		hat.CanCollide = false
		part("HatCrown", Vector3.new(1.3, 0.7, 1.3), model.Head.CFrame * CFrame.new(0, 1, 0), Color3.fromRGB(140, 100, 60), Enum.Material.Fabric, model).CanCollide = false
		plank(Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), camp)
		for _, dz in ipairs({ -4.4, 4.4 }) do
			log(Vector3.new(0.6, 9, 0.6), at(sx - 1.2, 4.5, sz + dz), camp)
			log(Vector3.new(0.6, 9, 0.6), at(sx + 5, 4.5, sz + dz), camp)
		end
		for k = 0, 5 do
			decor(part("Awning", Vector3.new(7.4, 0.15, 1.6), at(sx + 1.9, 9.1 - k * 0.12, sz - 4.5 + k * 1.6 + 0.8) * CFrame.Angles(0, 0, -0.15), if k % 2 == 0 then Color3.fromRGB(190, 60, 45) else Color3.fromRGB(235, 220, 190), Enum.Material.Fabric, camp))
		end
		crate(sx - 0.3, 3, sz - 2.5, 1.6, "px_red_sand")
		crate(sx - 0.3, 3, sz + 2.5, 1.6, "px_gold_ore")
		crate(sx + 6.5, 0, sz + 6, 2.4, "px_iron_ore")
		barrel(sx + 7, 0, sz - 6)
	end
	-- a notice board, a signpost to the quarry and the arena, lamp posts round the plaza, a hitching rail
	do
		local nx, nz = cx - 6, cz - 20
		log(Vector3.new(0.6, 6, 0.6), at(nx - 2.6, 3, nz), camp)
		log(Vector3.new(0.6, 6, 0.6), at(nx + 2.6, 3, nz), camp)
		plank(Vector3.new(5.6, 3.4, 0.3), at(nx, 4, nz), camp)
		plank(Vector3.new(6.4, 0.4, 1.2), at(nx, 6, nz - 0.2), camp)
		for k = 0, 4 do
			decor(part("Notice", Vector3.new(1.1, 1.4, 0.05), at(nx - 2 + k + rng:NextNumber(-0.2, 0.2), 4 + rng:NextNumber(-0.8, 0.8), nz - 0.2) * CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)), Color3.fromRGB(235, 225, 195), Enum.Material.SmoothPlastic, camp))
		end
		local sx, sz = cx - 2, cz - 26
		log(Vector3.new(0.6, 7, 0.6), at(sx, 3.5, sz), camp)
		local toPit = plank(Vector3.new(5, 0.9, 0.3), at(sx, 5.8, sz) * CFrame.Angles(0, math.atan2(PIT.x - sx, PIT.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), camp)
		boardText(toPit, "Карьер")
		local toArena = plank(Vector3.new(5, 0.9, 0.3), at(sx, 4.6, sz) * CFrame.Angles(0, math.atan2(ARENA.x - sx, ARENA.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), camp)
		boardText(toArena, "Арена")
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2 + 0.3
			lampPost(cx + math.cos(a) * (CAMP.r + 2), cz + math.sin(a) * (CAMP.r + 2))
		end
		log(Vector3.new(0.6, 3, 0.6), at(cx + 20, 1.5, cz - 14), camp)
		log(Vector3.new(0.6, 3, 0.6), at(cx + 26, 1.5, cz - 14), camp)
		log(Vector3.new(6.6, 0.5, 0.5), at(cx + 23, 2.8, cz - 14), camp)
		barrel(cx - 12, 0, cz - 14)
		barrel(cx - 9.5, 0, cz - 15)
		crate(cx - 11, 0, cz - 17.5, 2.6)
	end
end

-- ================================================================ the open-pit mine: pit, scaffolds, crane, rails
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	local function bedrock(p)
		textured(p, "px_red_sandstone", BEDROCK)
	end
	bedrock(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(mx, -h - B / 2, mz), STONE, nil, mine))
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(mx - w / 2 - B, -h / 2, mz) },
		{ Vector3.new(2 * B, h, w), at(mx + w / 2 + B, -h / 2, mz) },
	}) do
		bedrock(part("PitWall", wall[1], wall[2], STONE, nil, mine))
	end
	-- the rim: planks laid round the edge, a log fence with gaps where the trails come in
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], STONE, nil, mine), "px_spruce_planks")
	end
	local function post(x, z)
		log(Vector3.new(0.8, 3.4, 0.8), at(x, 1.7, z), mine)
	end
	for _, sz in ipairs({ -1, 1 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local len = edge - 8
			plank(Vector3.new(len, 0.4, 0.3), at(mx + sx * (8 + len / 2), 2.6, mz + sz * edge), mine)
			plank(Vector3.new(len, 0.4, 0.3), at(mx + sx * (8 + len / 2), 1.4, mz + sz * edge), mine)
			for x = 8, edge, 10 do
				post(mx + sx * x, mz + sz * edge)
			end
		end
		plank(Vector3.new(0.3, 0.4, 2 * edge), at(mx + sz * edge, 2.6, mz), mine)
		plank(Vector3.new(0.3, 0.4, 2 * edge), at(mx + sz * edge, 1.4, mz), mine)
		for z = -edge, edge, 10 do
			post(mx + sz * edge, mz + z)
		end
	end
	local anchor = part("MineAnchor_mountain_foot", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), STONE, nil, mine)
	anchor:SetAttribute("LocationId", "mountain_foot")
	anchor:SetAttribute("MineId", "mountain_foot")
	anchor:SetAttribute("Size", Vector3.new(PIT.size, PIT.depth, PIT.size))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, "Карьер", 14)
	-- four ladders (invisible 2×2 trusses + a textured plate), like the other mines
	local LADDER_W = 4 * B
	local ladderTexture = textures and textures.textures and textures.textures.ladder
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
	-- scaffold towers at two corners: log frames with plank platforms, ladders and lanterns
	local function scaffold(x, z, levels)
		for lv = 0, levels - 1 do
			local y = lv * 7
			for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
				log(Vector3.new(0.8, 7, 0.8), at(x + s[1] * 3, y + 3.5, z + s[2] * 3), mine)
			end
			for _, side in ipairs({ -1, 1 }) do
				plank(Vector3.new(6.8, 0.35, 0.35), at(x, y + 3.5, z + side * 3) * CFrame.Angles(0, 0, side * 0.75), mine)
			end
			plank(Vector3.new(7.6, 0.5, 7.6), at(x, y + 7, z), mine)
		end
		lantern(x + 3.6, levels * 7 - 1.5, z)
		local flag = decor(part("Flag", Vector3.new(0.1, 1.6, 2.6), at(x, levels * 7 + 4, z + 1.3), Color3.fromRGB(190, 60, 45), Enum.Material.Fabric, mine))
		log(Vector3.new(0.3, 4, 0.3), at(x, levels * 7 + 2.5, z), mine)
		flag.Name = "Flag"
	end
	scaffold(mx - edge - 8, mz - edge + 10, 3)
	scaffold(mx + edge + 8, mz + edge - 12, 2)
	-- the crane on the north rim: a mast, a boom out over the pit, a rope and a bucket of red sand
	do
		local cx, cz = mx + 10, mz - edge - 6
		log(Vector3.new(1.4, 22, 1.4), at(cx, 11, cz), mine)
		for _, s in ipairs({ -1, 1 }) do
			log(Vector3.new(0.7, 9, 0.7), at(cx + s * 2.4, 3.5, cz) * CFrame.Angles(0, 0, s * 0.4), mine)
		end
		local boomLen = 30
		log(Vector3.new(1, 1, boomLen), at(cx, 21, cz + boomLen / 2 - 2) * CFrame.Angles(0.12, 0, 0), mine)
		log(Vector3.new(0.6, 0.6, 12), at(cx, 23, cz + 3) * CFrame.Angles(-0.45, 0, 0), mine)
		local tipZ = cz + boomLen - 3
		local ropeLen = 18
		part("CraneRope", Vector3.new(0.2, ropeLen, 0.2), at(cx, 18 - ropeLen / 2, tipZ), ROPE, Enum.Material.Fabric, mine).CanCollide = false
		local bucket = part("Bucket", Vector3.new(3, 2.2, 3), at(cx, 18 - ropeLen - 1, tipZ), Color3.fromRGB(110, 75, 45), Enum.Material.WoodPlanks, mine)
		textured(decor(part("BucketSand", Vector3.new(2.6, 0.3, 2.6), bucket.CFrame * CFrame.new(0, 1.15, 0), STONE, nil, mine)), "px_red_sand")
		part("Winch", Vector3.new(2, 1.4, 1.4), at(cx, 3, cz + 1.4), IRON, Enum.Material.Metal, mine)
	end
	-- rails from the south rim to a loading dock with ore carts
	do
		local rz0, rz1 = mz + edge + 2, mz + edge + 9
		local rx = mx - 24
		for _, side in ipairs({ -0.7, 0.7 }) do
			decor(part("Rail", Vector3.new(0.3, 0.2, rz1 - rz0), at(rx + side, 0.3, (rz0 + rz1) / 2), IRON, Enum.Material.Metal, mine))
		end
		for z = rz0, rz1, 2 do
			textured(decor(part("Sleeper", Vector3.new(2.4, 0.2, 0.6), at(rx, 0.1, z), WOOD, nil, mine)), "px_spruce_planks")
		end
		local function cart(z, load)
			local base = at(rx, 0, z)
			part("Cart", Vector3.new(3, 0.6, 4), base * CFrame.new(0, 0.9, 0), IRON, Enum.Material.Metal, mine)
			for _, d in ipairs({ { 0, 1.85, 3, 0.3 }, { 0, -1.85, 3, 0.3 }, { 1.35, 0, 0.3, 4 }, { -1.35, 0, 0.3, 4 } }) do
				decor(part("CartSide", Vector3.new(d[3], 1.6, d[4]), base * CFrame.new(d[1], 2, d[2]), IRON, Enum.Material.Metal, mine))
			end
			textured(decor(part("CartLoad", Vector3.new(2.4, 0.8, 3.4), base * CFrame.new(0, 2.4, 0), STONE, nil, mine)), load)
		end
		cart(rz0 + 3, "px_red_sand")
		plank(Vector3.new(10, 2, 6), at(rx, 1, rz1 + 3), mine)
		crate(rx - 3, 2, rz1 + 2.5, 2.2, "px_gold_ore")
		crate(rx + 3, 2, rz1 + 3.5, 1.8, "px_red_sand")
		lampPost(rx + 7, rz1)
	end
	-- piles of red sand and ore beside the pit
	for _, pp in ipairs({ { mx - edge - 14, mz + 20 }, { 30, 12 } }) do
		for _ = 1, 14 do
			local s = rng:NextNumber(1.5, 3)
			local r = rng:NextNumber(0, 4)
			local a = rng:NextNumber(0, 6.28)
			textured(part("OrePile", Vector3.new(s, s, s), at(pp[1] + math.cos(a) * r, s / 2 + math.max(0, 3 - r) * 0.8, pp[2] + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, 0), STONE, nil, mine), ({ "px_red_sand", "px_red_sand", "px_iron_ore", "px_gold_ore" })[rng:NextInteger(1, 4)])
		end
	end
end

-- ================================================================ the labyrinth and the Minotaur's colosseum
local arena = folder("MinotaurArena")
local SAND = Color3.fromRGB(226, 196, 170)
do
	-- the labyrinth: walls of red sandstone 8 high in a small maze, crumbled tops, a meander frieze on the gate
	local L = LAB
	local walls = {
		-- { x0, z0, x1, z1 } in zone coords, 2 studs thick
		{ L.x0, L.z0, L.x1, L.z0 }, -- south outer
		{ L.x0, L.z1, L.x1 - 12, L.z1 }, -- north outer (gap at the north-east)
		{ L.x0, L.z0, L.x0, L.z1 }, -- west outer
		{ L.x1, L.z0, L.x1, ARENA.z - 6 }, -- east outer, a gap facing the arena gate
		{ L.x1, ARENA.z + 6, L.x1, L.z1 },
		{ L.x0 + 10, L.z1, L.x0 + 10, L.z1 - 30 },
		{ L.x0 + 10, L.z1 - 30, L.x0 + 26, L.z1 - 30 },
		{ L.x0 + 20, L.z0, L.x0 + 20, L.z0 + 18 },
		{ L.x0 + 20, L.z1 - 8, L.x1 - 8, L.z1 - 8 },
		{ L.x1 - 8, L.z1 - 8, L.x1 - 8, L.z1 - 40 },
		{ L.x0 + 28, L.z0 + 10, L.x1 - 8, L.z0 + 10 },
	}
	for _, wseg in ipairs(walls) do
		local x0, z0, x1, z1 = wseg[1], wseg[2], wseg[3], wseg[4]
		local len = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
		local alongX = math.abs(x1 - x0) > 0
		local n = math.ceil(len / 4)
		for k = 0, n - 1 do
			local t0 = k * 4
			local h = 8 - (if rng:NextNumber() < 0.35 then rng:NextInteger(1, 3) * 2 else 0)
			local sx, sz = if alongX then 4.05 else 2, if alongX then 2 else 4.05
			local px = if alongX then math.min(x0, x1) + t0 + 2 else x0
			local pz = if alongX then z0 else math.min(z0, z1) + t0 + 2
			textured(part("LabyrinthWall", Vector3.new(sx, h, sz), at(px, h / 2, pz), STONE, nil, arena), if rng:NextNumber() < 0.2 then "px_sandstone" else "px_red_sandstone", SAND:Lerp(Color3.fromRGB(255, 255, 255), rng:NextNumber(0, 0.3)))
			if h == 8 and k % 3 == 0 then
				-- a meander band on top (the Greek key: two small offset blocks)
				textured(decor(part("Meander", Vector3.new(sx * 0.6, 0.8, sz * 0.6), at(px, 8.4, pz), STONE, nil, arena)), "px_sandstone")
			end
		end
	end
	for _ = 1, 8 do
		local x, z = rng:NextNumber(L.x0, L.x1), rng:NextNumber(L.z0, L.z1)
		textured(part("FallenBlock", Vector3.new(2.6, 2, 2.6), at(x, 1, z) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), 0.2), STONE, nil, arena), "px_red_sandstone")
	end
	-- the colosseum: a sand floor, three tiers of seats (partly collapsed), an outer wall of arches, the gate
	local ax, az, R = ARENA.x, ARENA.z, ARENA.r
	local floorDisc = part("ArenaSand", Vector3.new(0.6, 2 * R, 2 * R), at(ax, 0.3, az) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, arena)
	floorDisc.Shape = Enum.PartType.Cylinder
	textured(floorDisc, "px_sand", Color3.fromRGB(235, 205, 170))
	local inner = part("ArenaCircle", Vector3.new(0.8, 24, 24), at(ax, 0.4, az) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, arena)
	inner.Shape = Enum.PartType.Cylinder
	textured(inner, "px_red_sandstone")
	local SEG = 40
	local gateA = 0 -- (the ring frames sit at angle a + π) the gate faces west, towards the labyrinth
	local function inGate(a)
		return math.abs(((a - gateA + math.pi) % (2 * math.pi)) - math.pi) < 0.22
	end
	for i = 0, SEG - 1 do
		local a = (i + 0.5) / SEG * math.pi * 2
		local collapsed = math.cos(a - 3 * math.pi / 4) > 0.85 -- the north-east of the stands has fallen in
		if not inGate(a) then
			for tier = 0, 2 do
				if not (collapsed and tier > 0) then
					local r = R + 2 + tier * 4
					local w = 2 * r * math.tan(math.pi / SEG) + 0.4
					local hgt = 2 + tier * 2.5
					textured(part("Seats", Vector3.new(w, hgt, 4.2), CFrame.new(BX + ax, hgt / 2, BZ + az) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.new(0, 0, -r), STONE, nil, arena), "px_sandstone", SAND)
				end
			end
			-- the outer wall: piers and arches (every other segment an opening), broken in places
			local r = R + 16
			local w = 2 * r * math.tan(math.pi / SEG) + 0.3
			local cf = CFrame.new(BX + ax, 0, BZ + az) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.new(0, 0, -r)
			local wallH = if collapsed then rng:NextNumber(4, 9) else 20 + (if rng:NextNumber() < 0.25 then -rng:NextNumber(3, 8) else 0)
			if i % 2 == 0 then
				textured(part("ArenaPier", Vector3.new(w, wallH, 3), cf * CFrame.new(0, wallH / 2, 0), STONE, nil, arena), "px_red_sandstone")
			else
				textured(part("ArenaArchTop", Vector3.new(w, math.max(1, wallH - 12), 3), cf * CFrame.new(0, 12 + math.max(1, wallH - 12) / 2, 0), STONE, nil, arena), "px_red_sandstone")
				textured(part("ArenaArchFoot", Vector3.new(w, 1, 3.4), cf * CFrame.new(0, 0.5, 0), STONE, nil, arena), "px_sandstone", SAND)
			end
			if not collapsed and wallH >= 20 then
				textured(part("ArenaCornice", Vector3.new(w + 0.2, 1, 3.8), cf * CFrame.new(0, wallH + 0.5, 0), STONE, nil, arena), "px_sandstone", SAND)
			end
		end
	end
	-- fallen blocks where the stands collapsed
	for _ = 1, 16 do
		local a = -math.pi / 4 + rng:NextNumber(-0.5, 0.5)
		local r = R + rng:NextNumber(2, 18)
		textured(part("Rubble", Vector3.new(3, 2.4, 3), at(ax + math.cos(a) * r, 1.2, az + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), 0.3), STONE, nil, arena), "px_red_sandstone")
	end
	-- the gate (west): two towers, a lintel, the bull skull above, torches
	local gx, gz = ax - R - 16, az
	for _, s in ipairs({ -1, 1 }) do
		textured(part("GateTower", Vector3.new(6, 24, 6), at(gx, 12, gz + s * 9), STONE, nil, arena), "px_red_sandstone")
		textured(part("GateTowerTop", Vector3.new(7, 1.2, 7), at(gx, 24.6, gz + s * 9), STONE, nil, arena), "px_sandstone", SAND)
		local torch = decor(part("GateFlame", Vector3.new(1, 1, 1), at(gx - 3.6, 10, gz + s * 9), LAMP, Enum.Material.Neon, arena))
		light(torch, 24, 1.3, LAMP)
		local fire = Instance.new("Fire")
		fire.Size = 2.4
		fire.Parent = torch
	end
	textured(part("GateLintel", Vector3.new(6, 4, 24), at(gx, 18, gz), STONE, nil, arena), "px_red_sandstone")
	for k = -2, 2 do
		textured(decor(part("GateMeander", Vector3.new(0.4, 0.8, 1.6), at(gx - 3.1, 17, gz + k * 3.2), STONE, nil, arena)), "px_sandstone")
	end
	bullSkull(gx - 3.4, gz, 1.6, -math.pi / 2)
	-- the name carved over the gate, on the lintel's outer face (the gate faces west, −X)
	local gateSign = textured(decor(part("ArenaSign", Vector3.new(0.3, 1.6, 14), at(gx - 3.15, 18.7, gz), STONE, nil, arena)), "px_sandstone", SAND)
	boardText(gateSign, "Арена Минотавра", Color3.fromRGB(95, 40, 25), { Enum.NormalId.Left })
	-- four pillars round the centre with great chains running to the sleeping Minotaur [клиент: «закованный в цепи»]
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local px, pz = ax + math.cos(a) * 20, az + math.sin(a) * 20
		textured(part("ChainPillarBase", Vector3.new(6, 2, 6), at(px, 1, pz), STONE, nil, arena), "px_sandstone", SAND)
		textured(part("ChainPillar", Vector3.new(4, 16, 4), at(px, 10, pz), STONE, nil, arena), "px_red_sandstone")
		textured(part("ChainPillarCap", Vector3.new(5.4, 1.4, 5.4), at(px, 18.7, pz), STONE, nil, arena), "px_sandstone", SAND)
		part("ChainRing", Vector3.new(0.6, 2.4, 2.4), at(px - math.cos(a) * 2.2, 14, pz - math.sin(a) * 2.2) * CFrame.Angles(0, -a, 0), IRON, Enum.Material.Metal, arena).Shape = Enum.PartType.Cylinder
		-- the chain: links from the pillar ring down to the shackle near the centre, sagging
		local from = Vector3.new(BX + px - math.cos(a) * 2.2, 14, BZ + pz - math.sin(a) * 2.2)
		local to = Vector3.new(BX + ax + math.cos(a) * 3, 4, BZ + az + math.sin(a) * 3)
		local links = 22
		for i = 0, links - 1 do
			local t = (i + 0.5) / links
			local p = from:Lerp(to, t) - Vector3.new(0, 3.5 * math.sin(math.pi * t), 0)
			local nextP = from:Lerp(to, math.min(1, t + 1 / links)) - Vector3.new(0, 3.5 * math.sin(math.pi * math.min(1, t + 1 / links)), 0)
			local link = part("ChainLink", Vector3.new(0.35, 0.9, 1.4), CFrame.lookAt(p, nextP) * CFrame.Angles(0, 0, if i % 2 == 0 then 0 else math.pi / 2), IRON, Enum.Material.Metal, arena)
			link.CanCollide = false
		end
	end
	-- the sleeping place: a stone slab with an iron collar, bones and horns of those who woke him
	textured(part("RestSlab", Vector3.new(10, 1.2, 6), at(ax, 1, az), STONE, nil, arena), "px_sandstone", SAND)
	part("Collar", Vector3.new(1, 3.4, 3.4), at(ax, 2.6, az) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, arena).Shape = Enum.PartType.Cylinder
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(8, 30)
		decor(part("Bone", Vector3.new(0.4, 0.4, rng:NextNumber(1.4, 2.6)), at(ax + math.cos(a) * r, 0.9, az + math.sin(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), BONE, nil, arena))
	end
	-- braziers on the arena floor
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local bx, bz = ax + math.cos(a) * (R - 4), az + math.sin(a) * (R - 4)
		if not inGate(a + math.pi) then
			textured(part("BrazierPost", Vector3.new(1.6, 4, 1.6), at(bx, 2, bz), STONE, nil, arena), "px_sandstone", SAND)
			part("BrazierBowl", Vector3.new(2.6, 0.8, 2.6), at(bx, 4.4, bz), IRON, Enum.Material.Metal, arena)
			local coals = decor(part("BrazierCoals", Vector3.new(2.2, 0.3, 2.2), at(bx, 4.9, bz), Color3.fromRGB(255, 110, 40), Enum.Material.Neon, arena))
			local fire = Instance.new("Fire")
			fire.Size = 3
			fire.Heat = 6
			fire.Parent = coals
			light(coals, 26, 1.2, Color3.fromRGB(255, 150, 80))
		end
	end
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(ax, 1.2, az), STONE, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "minotaur")
	bossSpawn:SetAttribute("ArenaRadius", R - 4)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end

-- ================================================================ the valley: hoodoos, an arch, flora, bones, dust
local nature = folder("Nature")
local function clear(x, z, margin)
	margin = margin or 0
	return not flat(x, z) and not onTrail(x, z) and not inRavine(x, z) and math.abs(z - ravineZ(x)) > RAVINE_W + 4 + margin and valleyD(x, z) < 0.95
end
local placedH = 0
for _ = 1, 400 do
	if placedH >= 12 then
		break
	end
	local a, d = rng:NextNumber(0, 6.28), rng:NextNumber(0.6, 0.9)
	local x, z = math.sin(a) * VALLEY.rx * d, math.cos(a) * VALLEY.rz * d
	if clear(x, z, 6) then
		hoodoo(x, z, rng:NextNumber(18, 34))
		placedH += 1
	end
end
-- two buttes standing alone in the valley: tiers of strata stepping in, ragged by offset blocks, a sand cap
local function butte(cx, cz, r, h)
	local tiers = 3
	local y = floorAt(cx, cz)
	for t = 0, tiers - 1 do
		local tr = r * (1 - t * 0.28)
		local th = math.floor(h / tiers / STRATA + 0.5) * STRATA
		for k = 0, th / STRATA - 1 do
			local band = bandColor(math.floor((y + k * STRATA) / STRATA) + 3)
			for j = 0, 5 do
				local a = j / 6 * math.pi * 2 + t
				local off = tr * 0.35
				local s = tr * rng:NextNumber(1.1, 1.35)
				textured(part("Butte", Vector3.new(s, STRATA, s * rng:NextNumber(0.8, 1.1)), at(cx + math.cos(a) * off, y + k * STRATA + STRATA / 2, cz + math.sin(a) * off) * CFrame.Angles(0, a, 0), STONE, nil, nature), "px_terracotta_pale", band)
			end
		end
		y += th
		for j = 0, 3 do
			local a = j / 4 * math.pi * 2 + t
			textured(part("ButteCap", Vector3.new(tr * 1.1, 1, tr * 1.1), at(cx + math.cos(a) * tr * 0.3, y + 0.5, cz + math.sin(a) * tr * 0.3) * CFrame.Angles(0, a, 0), STONE, nil, nature), "px_red_sand")
		end
	end
end
butte(4, -152, 22, 54)
butte(150, 112, 14, 36)
-- the natural arch in the west: two legs of strata and a span of blocks following an arc
do
	local ax, az = -150, 10
	local span, rise = 34, 22
	for k = 0, 16 do
		local t = k / 16
		local x = ax
		local z = az - span / 2 + span * t
		local y = rise * math.sin(math.pi * t)
		local thick = 6 - 2 * math.sin(math.pi * t)
		textured(part("ArchSpan", Vector3.new(7, thick, span / 16 + 1.2), at(x, y + 8, z), STONE, nil, nature), "px_terracotta_pale", bandColor(math.floor((y + 8) / STRATA) + 3))
	end
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			textured(part("ArchLeg", Vector3.new(8 - k, STRATA, 7 - k * 0.5), at(ax, k * STRATA + STRATA / 2, az + s * span / 2), STONE, nil, nature), "px_terracotta_pale", bandColor(k + 3))
		end
	end
end
-- flora and bones scattered over the open ground
for _ = 1, 260 do
	local x, z = rng:NextNumber(-VALLEY.rx, VALLEY.rx), rng:NextNumber(-VALLEY.rz, VALLEY.rz)
	if clear(x, z) then
		local r = rng:NextNumber()
		if r < 0.45 then
			deadBush(x, z)
		elseif r < 0.7 then
			cactus(x, z)
		elseif r < 0.82 then
			deadTree(x, z)
		elseif r < 0.95 then
			tumbleweed(x, z)
		else
			local y = floorAt(x, z)
			for _ = 1, 4 do
				decor(part("Bone", Vector3.new(0.4, 0.4, rng:NextNumber(1.4, 2.6)), at(x + rng:NextNumber(-2, 2), y + 0.2, z + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), BONE, nil, nature))
			end
		end
	end
end
-- a giant beast's ribcage half buried near the ravine, a great bull skull by the labyrinth
do
	local rx, rz = 110, 50
	for k = 0, 6 do
		for _, s in ipairs({ -1, 1 }) do
			for j = 0, 3 do
				local a = j / 4 * 1.3
				decor(part("Rib", Vector3.new(1, 3.4, 1), at(rx + k * 3, 0, rz) * CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, s * (0.35 + a)) * CFrame.new(0, 1.6 + j * 3, 0) * CFrame.new(s * (0.5 + j * 1.1), 0, 0), BONE, nil, nature)).CanCollide = true
			end
		end
	end
	for k = 0, 8 do
		part("Spine", Vector3.new(1.4, 1.2, 2.6), at(rx - 3 + k * 3, 0.4, rz), BONE, nil, nature)
	end
	bullSkull(rx - 8, rz, 2.4, math.pi / 2)
	bullSkull(LAB.x0 - 8, LAB.z1 - 4, 1.4, 0.6)
end
-- the dust: an orange haze drifting on the wind, two dust devils
for _, e in ipairs({ { 0, 0, 380 }, { 80, -40, 200 } }) do
	local p = decor(part("DustWind", Vector3.new(e[3], 20, e[3]), at(e[1], 10, e[2]), STONE, nil, nature))
	p.Transparency = 1
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(220, 150, 100))
	dust.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) })
	dust.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.88), NumberSequenceKeypoint.new(1, 1) })
	dust.Rate = 18
	dust.Lifetime = NumberRange.new(6, 9)
	dust.Speed = NumberRange.new(4, 8)
	dust.EmissionDirection = Enum.NormalId.Right
	dust.SpreadAngle = Vector2.new(20, 10)
	dust.Parent = p
end
for _, dd in ipairs({ { -120, -110 }, { 150, 90 } }) do
	local p = decor(part("DustDevil", Vector3.new(4, 1, 4), at(dd[1], floorAt(dd[1], dd[2]) + 0.5, dd[2]), STONE, nil, nature))
	p.Transparency = 1
	local swirl = Instance.new("ParticleEmitter")
	swirl.Texture = "rbxasset://textures/particles/smoke_main.dds"
	swirl.Color = ColorSequence.new(Color3.fromRGB(210, 140, 90))
	swirl.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) })
	swirl.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
	swirl.Rate = 25
	swirl.Lifetime = NumberRange.new(2.5, 3.5)
	swirl.Speed = NumberRange.new(8, 12)
	swirl.RotSpeed = NumberRange.new(200, 300)
	swirl.Rotation = NumberRange.new(0, 360)
	swirl.SpreadAngle = Vector2.new(10, 10)
	swirl.Parent = p
end

print(("[build-mountain-foot] built: %d parts (terrain runs %d)"):format(#root:GetDescendants(), count))
