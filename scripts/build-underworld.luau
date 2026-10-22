--!nocheck
-- Builds the Преисподняя (underworld), level 7 [меню]. «Преисподняя погружает в жар и мрак: каждый шаг даётся с
-- трудом, а работать здесь почти невозможно» [меню]. Blocks: Незерит 75 %, Незер-кварцевая руда 10 %, Песок душ
-- 10 %, воздух 5 % [меню]. Boss: Король Пиглинов — «алчный вождь, одержимый лишь властью и золотом» [клиент].
-- [владелец 22.10: «проделай работу лучше, чем в прошлый раз»] Ideas from the Minecraft Nether and its builders:
-- one enclosed cavern (no sky: a stepped rock ceiling, walls terracing up to it), a lava sea along the walls with
-- lavafalls, a lava river across the cave, glowstone clusters and stalactites on the ceiling, a red murk
-- (IndoorLighting: Haze / AtmosphereColor), ash and embers in the air, floating ghasts; the biomes each in its
-- own corner — the crimson forest (west), the warped forest (east), the soul sand valley with blue soul fire and
-- giant fossils (south-west), the ruins of a nether fortress (south-east), the basalt deltas round the bastion
-- (north). The mine is in the middle, ringed by nether-brick towers with chains to the ceiling; the convicts'
-- outpost with the ruined arrival portal is in the south; the bastion of the King of the Piglins stands on an
-- island in a lava moat in the north, its courtyard is the arena.
--   * terrain on an 8-stud grid; every bridge spans the real lava gap measured from the grid (gapEdges), its
--     heads are kept level (nearBridge); the arches are real arches: piers in the lava, the thinnest point at
--     the crown, the springing low on the piers [урок Подножья горы];
--   * every name stands at its place: the zone signs at the zone edges, «Шахта» over the mine, the bastion name
--     carved over its gate, «Скупщик блоков» over the buyer.
-- A separate zone at X = 3400 (StreamingEnabled). Run in Studio (Edit) via scripts/studio-loader.luau after
-- build-textures. Idempotent: replaces Workspace.Underworld. Arrival: LocationSpawn, LocationId "underworld".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
-- a fresh copy of the textures config: require() caches the module, a sync replaces its source
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("Underworld")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Underworld"
root:SetAttribute("LocationId", "underworld")
root:SetAttribute("SilentSteps", true) -- [владелец 23.10] no step sounds here (Footsteps)
root.Parent = workspace

local BX, BZ = 3400, 10000 -- [владелец 23.10: «вижу соседние локации»] 5000 studs from any other location: beyond streaming and haze
local B = 4
local rng = Random.new(20261025)
local STONE = Color3.fromRGB(110, 50, 48)
local IRON = Color3.fromRGB(52, 50, 54)
local CHAIN = Color3.fromRGB(60, 62, 70)
local GOLD = Color3.fromRGB(240, 190, 60)
local BONE = Color3.fromRGB(226, 220, 198)
local LAVA = Color3.fromRGB(255, 120, 30)
local LAMP = Color3.fromRGB(255, 180, 100)
local SOUL = Color3.fromRGB(90, 210, 255)
local GLOW = Color3.fromRGB(255, 205, 120)

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
-- [владелец 23.10: «освещение ужасное, слишком яркое, что не видно»] dozens of warm lights on light stone
-- washed the whole place out; every light is scaled down here (checked in Play)
local LIGHT_POWER, LIGHT_RANGE = 0.4, 0.65
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
-- a glowing block: Neon (it lights itself in the dark) with our pixel texture drawn over the faces
local ALL_FACES = { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local function glow(name, size, cf, color, texKey, parent, faces, tile)
	local p = part(name, size, cf, color, Enum.Material.Neon, parent)
	local id = TEX[texKey]
	if id then
		for _, face in ipairs(faces or ALL_FACES) do
			local t = Instance.new("Texture")
			t.Texture = id
			t.Face = face
			t.StudsPerTileU, t.StudsPerTileV = tile or B, tile or B
			t.Parent = p
		end
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
-- text painted on a board or carved in stone, on the given faces
local function boardText(target, text, color, faces)
	for _, face in ipairs(faces or { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.MaxDistance = 90
		gui.LightInfluence = 0.4
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(255, 220, 160)
		label.TextStrokeTransparency = 0.3
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
local R = 250 -- the cavern radius
local PIT = { x = 0, z = 4, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json underworld.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local OUTPOST = { x = 0, z = 170, r = 40 }
local PORTAL = { x = 0, z = 200 }
local BASTION = { x = 0, z = -170, island = 56, moat = 84, half = 44 } -- a rounded-square island in a lava moat
local LAVA_TOP, LAVA_FLOOR = -20, -24 -- the lava surface and the solid bed under it (players sink in to −24)
local function riverZ(x)
	return 112 + 12 * math.sin(x / 45)
end
local RIVER_W = 13
local function roundSq(dx, dz)
	return (dx ^ 4 + dz ^ 4) ^ 0.25
end
local BRIDGES = {
	{ x = 0, z = riverZ(0), style = "fortress" },
	{ x = -150, z = riverZ(-150), style = "crimson" },
	{ x = 150, z = riverZ(150), style = "basalt" },
	{ x = 0, z = BASTION.z + (BASTION.island + BASTION.moat) / 2, style = "bastion" },
}
local TRAILS = {
	{ { 0, 186 }, { 0, 84 } }, -- outpost → the main bridge → the mine
	{ { 0, -72 }, { 0, BASTION.z + BASTION.half + 2 } }, -- the mine → the moat bridge → the bastion gate
	{ { -PIT.hole - 4, PIT.z }, { -120, 10 }, { -170, 0 }, { -150, 60 }, { -150, 150 }, { -130, 178 } }, -- the crimson forest → the soul valley
	{ { PIT.hole + 4, PIT.z }, { 120, -4 }, { 170, 6 }, { 150, 50 }, { 150, 150 }, { 130, 176 } }, -- the warped forest → the fortress ruins
	{ { -18, 176 }, { -70, 170 }, { -130, 178 } },
	{ { 18, 176 }, { 70, 170 }, { 130, 176 } },
	{ { -30, -PIT.hole + PIT.z - 4 }, { -110, -112 }, { -165, -150 } }, -- into the basalt deltas, both sides
	{ { 30, -PIT.hole + PIT.z - 4 }, { 110, -112 }, { 165, -150 } },
}

-- ================================================================ the terrain grid (8-stud cells)
local C = 8
local X0, Z0 = -288, -288
local NX, NZ = 72, 72
local function caveD(x, z)
	return math.sqrt((x / R) ^ 2 + (z / R) ^ 2) * (1 + n2(x, z, 1.7, 0.012) * 0.07)
end
local function inRiver(x, z)
	return math.abs(z - riverZ(x)) < RIVER_W + n2(x, z, 5.1, 0.05) * 3
end
local function islandD(x, z)
	return roundSq(x - BASTION.x, z - BASTION.z)
end
local function inMoat(x, z)
	local d = islandD(x, z)
	return d >= BASTION.island and d < BASTION.moat + n2(x, z, 4.2, 0.05) * 6
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
local function nearBridge(x, z)
	for _, b in ipairs(BRIDGES) do
		if math.abs(x - b.x) < 12 and math.abs(z - b.z) < 34 then
			return true
		end
	end
	return false
end
local function flat(x, z) -- places that keep a level floor
	return math.sqrt((x - OUTPOST.x) ^ 2 + (z - OUTPOST.z) ^ 2) < OUTPOST.r
		or islandD(x, z) < BASTION.island
		or (math.abs(x - PIT.x) < PIT.hole + 14 and math.abs(z - PIT.z) < PIT.hole + 14)
end
local function biome(x, z)
	local wx = x + n2(x, z, 2.2, 0.02) * 22
	if z < -86 + n2(x, z, 3.1, 0.03) * 10 then
		return "delta"
	elseif z > riverZ(x) then
		return if wx < -56 then "soul" elseif wx > 56 then "wastes" else "outpost"
	end
	return if wx < -84 then "crimson" elseif wx > 84 then "warped" else "center"
end
local function ceilY(x, z, d)
	local h = 150 - 40 * math.min(d, 1.1) ^ 2 + n2(x, z, 6.6, 0.02) * 14 + n2(x, z, 7.3, 0.07) * 4
	return 4 * math.floor(h / 4)
end

local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local d = caveD(x, z)
		local c = { x = x, z = z, d = d, ceil = ceilY(x, z, d) }
		if d >= 1 then
			c.kind = "wall"
			local t = (d - 1) / 0.1
			local h = 16 + (c.ceil - 16) * math.clamp(t, 0, 1) ^ 0.7 + n2(x, z, 9.1, 0.06) * 12
			c.top = if t >= 1 or h >= c.ceil - 6 then c.ceil else math.max(12, 8 * math.floor(h / 8))
		elseif inHole(x, z) then
			c.kind = "hole"
		else
			c.biome = biome(x, z)
			local pool = (c.biome == "delta" or c.biome == "wastes") and n2(x, z, 9.9, 0.045) > 0.42
			local island = islandD(x, z) < BASTION.island
			local lava = not island
				and (
					d > 0.87 + n2(x, z, 3.3, 0.03) * 0.03
					or inRiver(x, z)
					or inMoat(x, z)
					or (pool and not flat(x, z) and not onTrail(x, z) and not nearBridge(x, z))
				)
			if lava then
				c.kind = "lava"
			else
				c.kind = "ground"
				c.path = onTrail(x, z)
				local h = 0
				if not (flat(x, z) or c.path or nearBridge(x, z)) then
					local b = c.biome
					local hill = n2(x, z, 3.3, 0.035) * 2.4 + n2(x, z, 6.1, 0.1) * 1.2
					if b == "crimson" or b == "warped" then
						h = math.clamp(math.floor(hill + 0.6), 0, 2)
					elseif b == "delta" then
						h = math.clamp(math.floor(hill * 1.4 + 0.8), 0, 2)
					elseif b == "soul" or b == "wastes" then
						h = math.clamp(math.floor(hill + 0.3), 0, 1)
					end
				end
				c.top = h * B
			end
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
	return if c and c.kind == "ground" then c.top else 0
end
local function nearLava(x, z, r)
	r = r or 1
	local ix, iz = math.floor((x - X0) / C), math.floor((z - Z0) / C)
	for dz = -r, r do
		for dx = -r, r do
			local n = cellAt(ix + dx, iz + dz)
			if n and (n.kind == "lava" or n.kind == "hole" or n.kind == "wall") then
				return true
			end
		end
	end
	return false
end

-- ================================================================ build the terrain, the walls and the ceiling
local terrain = folder("Terrain")
local lavaFolder = folder("Lava")
local CAP = { crimson = 1, warped = 1, soul = 2, delta = 2 }
local function floorLook(c)
	local v = n2(c.x, c.z, 7.7, 0.05) + n2(c.x, c.z, 2.9, 0.13) * 0.5
	local b = c.biome
	if c.path then
		return "px_netherrack_cobble", Color3.fromRGB(150, 118, 110), 0.4
	elseif b == "crimson" then
		return if v > 0.5 then "px_netherite" else "px_crimson_nylium", nil, CAP.crimson
	elseif b == "warped" then
		return if v > 0.5 then "px_netherite" else "px_warped_nylium", nil, CAP.warped
	elseif b == "soul" then
		return if v > 0.05 then "px_soul_soil" else "px_soul_sand", nil, CAP.soul
	elseif b == "delta" then
		if v > 0.55 then
			return "px_magma", nil, CAP.delta
		end
		return if v > 0 then "px_basalt" else "px_blackstone", nil, CAP.delta
	end
	if v > 0.6 then
		return "px_magma", nil, 1
	elseif v < -0.45 then
		return "px_netherrack_cobble", nil, 1
	elseif v > 0.38 and b == "wastes" then
		return "px_soul_sand", nil, 1
	end
	return nil, nil, 0
end
local count = 0
for iz = 0, NZ - 1 do
	local z0, z1 = Z0 + iz * C, Z0 + (iz + 1) * C
	local runs = {}
	local function flushKey(k)
		local r = runs[k]
		if not r then
			return
		end
		local x0, x1 = X0 + r.ix0 * C, X0 + (r.ix1 + 1) * C
		if r.lava then
			local p = glow("Lava", Vector3.new(x1 - x0, r.y1 - r.y0, z1 - z0), at((x0 + x1) / 2, (r.y0 + r.y1) / 2, (z0 + z1) / 2), LAVA, "lava", lavaFolder, { Enum.NormalId.Top }, 8)
			p.CanCollide = false
			p.CastShadow = false
			CollectionService:AddTag(p, "Lava")
		else
			box(r.name, x0, r.y0, z0, x1, r.y1, z1, r.variant, r.tint, terrain)
		end
		count += 1
		runs[k] = nil
	end
	local function push(ix, k, name, y0, y1, variant, tint, lava)
		local r = runs[k]
		if r and r.ix1 == ix - 1 and r.y0 == y0 and r.y1 == y1 and r.variant == variant and r.tint == tint then
			r.ix1 = ix
			return
		end
		flushKey(k)
		runs[k] = { ix0 = ix, ix1 = ix, name = name, y0 = y0, y1 = y1, variant = variant, tint = tint, lava = lava }
	end
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		local used = {}
		if c.kind == "ground" then
			local capV, capTint, capH = floorLook(c)
			if capV and capH > 0 then
				push(ix, "body", "Ground", -26, c.top - capH, "px_netherite", nil)
				push(ix, "cap", "GroundTop", c.top - capH, c.top, capV, capTint)
				used.cap = true
			else
				push(ix, "body", "Ground", -26, c.top, "px_netherite", nil)
			end
			used.body = true
		elseif c.kind == "lava" then
			push(ix, "bed", "LavaBed", -30, LAVA_FLOOR, "px_netherite", Color3.fromRGB(120, 70, 60))
			push(ix, "lava", "Lava", LAVA_FLOOR, LAVA_TOP, nil, nil, true)
			used.bed, used.lava = true, true
		elseif c.kind == "wall" then
			push(ix, "wall", "CaveWall", -30, c.top, "px_netherite", Color3.fromRGB(215, 190, 185))
			used.wall = true
		end
		-- the ceiling over every cell (on the wall cells that reach it, it sits right on top)
		push(ix, "ceil", "Ceiling", c.ceil, 190, "px_netherite", Color3.fromRGB(165, 130, 125))
		used.ceil = true
		for k in pairs(runs) do
			if not used[k] then
				flushKey(k)
			end
		end
	end
	for k in pairs(runs) do
		flushKey(k)
	end
	if iz % 4 == 0 then
		task.wait()
	end
end

-- the cliffs over the lava: ore, magma and rubble plates on the netherrack faces, lights over the lava
local lavaLights = 0
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		if c.kind == "ground" then
			for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local n = cellAt(ix + dir[1], iz + dir[2])
				if n and n.kind == "lava" and rng:NextNumber() < 0.35 then
					local y = rng:NextInteger(-4, -1) * B + 2
					local off = rng:NextNumber(-2, 2)
					local px = c.x + dir[1] * (C / 2 + 0.15) + math.abs(dir[2]) * off
					local pz = c.z + dir[2] * (C / 2 + 0.15) + math.abs(dir[1]) * off
					local size = if dir[1] ~= 0 then Vector3.new(0.3, B, B) else Vector3.new(B, B, 0.3)
					local roll = rng:NextNumber()
					local plate = part("CliffOre", size, at(px, y, pz), STONE, nil, terrain)
					textured(plate, if roll < 0.45 then "px_quartz_ore" elseif roll < 0.75 then "px_netherrack_cobble" else "px_magma")
				end
			end
		elseif c.kind == "lava" and lavaLights < 70 and rng:NextNumber() < 0.07 then
			lavaLights += 1
			local l = decor(part("LavaGlow", Vector3.new(1, 1, 1), at(c.x, LAVA_TOP + 3, c.z), LAVA, nil, lavaFolder))
			l.Transparency = 1
			light(l, 34, 1.4, Color3.fromRGB(255, 120, 50))
			if lavaLights % 5 == 0 then
				emitter(l, {
					Texture = "rbxasset://textures/particles/sparkles_main.dds",
					Color = ColorSequence.new(Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 80, 20)),
					LightEmission = 1,
					Size = NumberSequence.new(0.35, 0),
					Rate = 6,
					Lifetime = NumberRange.new(2, 4),
					Speed = NumberRange.new(4, 8),
					SpreadAngle = Vector2.new(25, 25),
					Acceleration = Vector3.new(0, 1, 0),
				})
			end
		end
	end
end
task.wait()

-- ================================================================ the ceiling: glowstone clusters, stalactites
local ceiling = folder("Ceiling")
local glowCount = 0
for _ = 1, 600 do
	if glowCount >= 46 then
		break
	end
	local x, z = rng:NextNumber(-R, R) * 0.9, rng:NextNumber(-R, R) * 0.9
	local c = cellAtPos(x, z)
	if c and c.kind ~= "wall" then
		glowCount += 1
		local top = c.ceil
		local s = rng:NextInteger(2, 3) * 2
		local main = glow("Glowstone", Vector3.new(s, s, s), at(x, top - s / 2 + 0.5, z), GLOW, "glowstone", ceiling)
		light(main, 48, 1.8, Color3.fromRGB(255, 196, 120))
		for _ = 1, rng:NextInteger(4, 9) do
			local k = rng:NextInteger(1, 2) * 2
			glow("Glowstone", Vector3.new(k, k, k), main.CFrame * CFrame.new(rng:NextInteger(-2, 2) * 2, -rng:NextInteger(1, 4) * 2, rng:NextInteger(-2, 2) * 2), GLOW, "glowstone", ceiling)
		end
	end
end
for _ = 1, 90 do
	local x, z = rng:NextNumber(-R, R) * 0.95, rng:NextNumber(-R, R) * 0.95
	local c = cellAtPos(x, z)
	if c and c.kind ~= "wall" then
		local y = c.ceil
		local w = rng:NextInteger(2, 3) * B
		while w >= B do
			local len = rng:NextInteger(1, 3) * B
			textured(part("Stalactite", Vector3.new(w, len, w), at(x, y - len / 2, z), STONE, nil, ceiling), "px_netherite", Color3.fromRGB(165, 130, 125))
			y -= len
			w -= B
		end
	end
end
task.wait()

-- ================================================================ lavafalls from the cave walls and the ceiling
local falls = folder("Lavafalls")
local function lavafall(x, z, top, width, facing)
	local h = top - LAVA_TOP + 2
	local cf = CFrame.lookAt(Vector3.new(BX + x, LAVA_TOP - 2 + h / 2, BZ + z), Vector3.new(BX + facing.X, LAVA_TOP - 2 + h / 2, BZ + facing.Z))
	local f = glow("Lavafall", Vector3.new(width, h, 3), cf, LAVA, "lava", falls, { Enum.NormalId.Front, Enum.NormalId.Left, Enum.NormalId.Right }, 8)
	f.CanCollide = false
	f.CastShadow = false
	CollectionService:AddTag(f, "Lava")
	local foot = decor(part("LavafallFoot", Vector3.new(width + 6, 1, 6), cf * CFrame.new(0, -h / 2 + 2.5, -2), LAVA, nil, falls))
	foot.Transparency = 1
	light(foot, 40, 2, Color3.fromRGB(255, 120, 40))
	emitter(foot, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 140, 60), Color3.fromRGB(90, 40, 30)),
		LightEmission = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
		Rate = 6,
		Lifetime = NumberRange.new(2, 3.5),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(40, 40),
	})
	local mid = decor(part("LavafallGlow", Vector3.new(1, 1, 1), cf * CFrame.new(0, h * 0.15, -3), LAVA, nil, falls))
	mid.Transparency = 1
	light(mid, 50, 1.4, Color3.fromRGB(255, 130, 50))
end
local fallsMade = 0
for k = 0, 300 do
	if fallsMade >= 11 then
		break
	end
	local a = k * 2.399 -- golden angle: spread round the cave
	local dx, dz = math.sin(a), math.cos(a)
	-- walk outwards to the first wall cell; a fall only where that wall is already high
	local prev
	for r = R * 0.8, R * 1.4, 4 do
		local c = cellAtPos(dx * r, dz * r)
		if not c then
			break
		end
		if c.kind == "wall" then
			if c.top >= 56 and prev and prev.kind == "lava" then
				local rr = r - 4
				lavafall(dx * rr, dz * rr, c.top - rng:NextNumber(4, 16), rng:NextInteger(2, 3) * B, Vector3.new(0, 0, 0))
				fallsMade += 1
			end
			break
		end
		prev = c
	end
end
-- thin falls from cracks in the ceiling straight into the lava
local ceilingFalls = 0
for _ = 1, 400 do
	if ceilingFalls >= 5 then
		break
	end
	local x, z = rng:NextNumber(-R, R), rng:NextNumber(-R, R)
	local c = cellAtPos(x, z)
	if c and c.kind == "lava" and not nearBridge(x, z) then
		ceilingFalls += 1
		local h = c.ceil - LAVA_TOP + 2
		local f = glow("CeilingLavafall", Vector3.new(2, h, 2), at(c.x, LAVA_TOP - 2 + h / 2, c.z), LAVA, "lava", falls, { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }, 8)
		f.CanCollide = false
		f.CastShadow = false
		CollectionService:AddTag(f, "Lava")
		light(f, 30, 1.2, Color3.fromRGB(255, 130, 50))
	end
end
task.wait()

-- ================================================================ small builders
local props = folder("Props")
local function netherBrick(name, size, cf, parent)
	return textured(part(name, size, cf, STONE, nil, parent or props), "px_nether_bricks")
end
local function blackBrick(name, size, cf, parent)
	return textured(part(name, size, cf, STONE, nil, parent or props), "px_blackstone_bricks")
end
-- a nether-brick fence: posts every 4 studs and two rails, from (x0, z0) to (x1, z1)
local function fence(x0, z0, x1, z1, y, parent)
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local n = math.max(1, math.floor(len / 4 + 0.5))
	local yaw = math.atan2(x1 - x0, z1 - z0)
	for k = 0, n do
		local t = k / n
		netherBrick("FencePost", Vector3.new(0.8, 3, 0.8), at(x0 + (x1 - x0) * t, y + 1.5, z0 + (z1 - z0) * t), parent)
	end
	for _, ry in ipairs({ 1.3, 2.5 }) do
		netherBrick("FenceRail", Vector3.new(0.4, 0.4, len), at((x0 + x1) / 2, y + ry, (z0 + z1) / 2) * CFrame.Angles(0, yaw, 0), parent)
	end
end
local function lantern(x, y, z, soul, parent)
	part("LanternCap", Vector3.new(1.2, 0.3, 1.2), at(x, y + 0.85, z), IRON, Enum.Material.Metal, parent or props)
	part("LanternBase", Vector3.new(1.2, 0.25, 1.2), at(x, y - 0.75, z), IRON, Enum.Material.Metal, parent or props)
	local l = decor(part("Lantern", Vector3.new(0.9, 1.2, 0.9), at(x, y, z), if soul then SOUL else LAMP, Enum.Material.Neon, parent or props))
	light(l, 24, 1.3, if soul then Color3.fromRGB(110, 200, 255) else LAMP)
	return l
end
-- a chain of alternating links between two points
local function chain(a, b, parent, linkLen)
	linkLen = linkLen or 1.6
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / linkLen))
	local cf = CFrame.lookAt(a, b)
	for k = 0, n - 1 do
		local link = part("ChainLink", Vector3.new(0.35, 0.9, linkLen * 1.1), cf * CFrame.new(0, 0, -(k + 0.5) * linkLen) * CFrame.Angles(0, 0, if k % 2 == 0 then 0 else math.pi / 2), CHAIN, Enum.Material.Metal, parent or props)
		decor(link)
	end
end
local function brazier(x, y, z, soul, parent)
	blackBrick("BrazierBase", Vector3.new(3, 3, 3), at(x, y + 1.5, z), parent)
	local coals = decor(part("BrazierFire", Vector3.new(2.4, 0.4, 2.4), at(x, y + 3.2, z), if soul then SOUL else LAVA, Enum.Material.Neon, parent or props))
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 8
	if soul then
		fire.Color = Color3.fromRGB(80, 200, 255)
		fire.SecondaryColor = Color3.fromRGB(30, 90, 255)
	end
	fire.Parent = coals
	light(coals, 30, 1.6, if soul then Color3.fromRGB(110, 200, 255) else Color3.fromRGB(255, 150, 70))
end
-- a blackstone signboard on a nether-brick post, its name on both faces, facing the trail
local function zoneSign(x, z, text, yaw, color)
	local y = floorAt(x, z)
	netherBrick("SignPost", Vector3.new(0.8, 5, 0.8), at(x, y + 2.5, z), props)
	local board = blackBrick("ZoneSign", Vector3.new(7, 1.8, 0.4), at(x, y + 4.6, z) * CFrame.Angles(0, yaw or 0, 0), props)
	boardText(board, text, color)
	return board
end

-- ================================================================ bridges: every one spans the measured lava gap
local bridges = folder("Bridges")
local function gapEdges(bx, bz, halfW)
	local function lavaAt(z)
		for _, dx in ipairs({ -halfW, 0, halfW }) do
			local c = cellAtPos(bx + dx, z)
			if c and c.kind == "lava" then
				return true
			end
		end
		return false
	end
	local zS, zN = bz, bz
	while lavaAt(zS - 0.5) do
		zS -= 1
	end
	while lavaAt(zN + 0.5) do
		zN += 1
	end
	return zS, zN
end
-- arches over the gap: piers every bay down into the lava bed, a semicircular arch between them —
-- the springing on the piers, the crown (thinnest) in the middle of each bay
local function arches(bx, zS, zN, width, crown, variant, tint, ringTint)
	local n = math.max(1, math.floor((zN - zS - 4) / 16 + 0.5))
	local s = (zN - zS - 4) / n
	local r = (s - 4) / 2
	local spring = crown - r
	for z = zS, zN - 1 do
		local u = z + 0.5 - (zS + 2)
		local k = math.clamp(math.floor(u / s), 0, n - 1)
		local local_ = u - k * s
		local bottom
		if u < 2 or u > n * s - 2 or local_ < 2 or local_ > s - 2 then
			bottom = -30 -- a pier, down into the lava bed
		else
			local c = local_ - s / 2
			bottom = spring + math.sqrt(math.max(0, r * r - c * c))
		end
		local deckBottom = -2
		textured(part("BridgeArch", Vector3.new(width, deckBottom - bottom, 1), at(bx, (deckBottom + bottom) / 2, z + 0.5), STONE, nil, bridges), variant, tint)
		if bottom > -30 then
			textured(decor(part("ArchRing", Vector3.new(width + 0.3, 0.8, 1), at(bx, bottom + 0.35, z + 0.5), STONE, nil, bridges)), variant, ringTint)
		end
	end
	-- pier footings where the piers enter the lava
	for k = 0, n do
		local pz = zS + 2 + k * s
		textured(part("PierFooting", Vector3.new(width + 1.6, 3, 5), at(bx, LAVA_TOP - 0.5, pz), STONE, nil, bridges), variant, ringTint)
	end
end
local bridgeSpans = {}
for _, b in ipairs(BRIDGES) do
	local zS, zN = gapEdges(b.x, b.z, if b.style == "bastion" then 6 else 4)
	bridgeSpans[b.style] = { zS, zN }
	local d0, d1 = zS - 4, zN + 4
	if b.style == "fortress" or b.style == "bastion" then
		local bastion = b.style == "bastion"
		local W = if bastion then 10 else 8
		local variant = if bastion then "px_blackstone_bricks" else "px_nether_bricks"
		textured(part("BridgeDeck", Vector3.new(W, 2, d1 - d0), at(b.x, -1, (d0 + d1) / 2), STONE, nil, bridges), variant)
		arches(b.x, zS, zN, W - 0.4, -3.5, variant, nil, if bastion then Color3.fromRGB(150, 140, 160) else Color3.fromRGB(150, 110, 110))
		if bastion then
			-- parapets with merlons and a gold band, gold-trimmed lamp posts at both ends
			for _, side in ipairs({ -1, 1 }) do
				blackBrick("Parapet", Vector3.new(1, 2.4, d1 - d0), at(b.x + side * (W / 2 - 0.5), 1.2, (d0 + d1) / 2), bridges)
				textured(decor(part("ParapetGold", Vector3.new(1.1, 0.4, d1 - d0), at(b.x + side * (W / 2 - 0.5), 1.6, (d0 + d1) / 2), STONE, nil, bridges)), "px_gilded_blackstone")
				for z = d0 + 1, d1 - 1, 4 do
					blackBrick("Merlon", Vector3.new(1, 1.4, 2), at(b.x + side * (W / 2 - 0.5), 3.1, z), bridges)
				end
				for _, z in ipairs({ d0 + 1, d1 - 1 }) do
					blackBrick("BridgePost", Vector3.new(2, 7, 2), at(b.x + side * (W / 2 + 0.6), 3.5, z), bridges)
					textured(part("PostGold", Vector3.new(2.3, 0.6, 2.3), at(b.x + side * (W / 2 + 0.6), 7.2, z), STONE, nil, bridges), "px_gold_block")
					lantern(b.x + side * (W / 2 + 0.6), 8.6, z, false, bridges)
				end
			end
		else
			for _, side in ipairs({ -1, 1 }) do
				fence(b.x + side * (W / 2 - 0.4), d0 + 0.5, b.x + side * (W / 2 - 0.4), d1 - 0.5, 0, bridges)
			end
			for _, z in ipairs({ d0 + 1, (d0 + d1) / 2, d1 - 1 }) do
				for _, side in ipairs({ -1, 1 }) do
					netherBrick("BridgeLampPost", Vector3.new(1, 6, 1), at(b.x + side * (W / 2 + 0.6), 3, z), bridges)
					lantern(b.x + side * (W / 2 + 0.6), 6.8, z, false, bridges)
				end
			end
		end
	elseif b.style == "crimson" then
		-- planks of crimson stem on stilts, chain hand rails sagging between posts
		local W = 6
		for z = d0, d1 - 1 do
			textured(part("BridgePlank", Vector3.new(W, 0.6, 0.95), at(b.x + rng:NextNumber(-0.1, 0.1), -0.3, z + 0.5) * CFrame.Angles(0, rng:NextNumber(-0.02, 0.02), 0), STONE, nil, bridges), "px_crimson_stem")
		end
		for _, side in ipairs({ -1, 1 }) do
			textured(part("BridgeBeam", Vector3.new(1, 1, d1 - d0), at(b.x + side * (W / 2 - 0.5), -1.1, (d0 + d1) / 2), STONE, nil, bridges), "px_crimson_stem")
			local posts = {}
			for z = d0 + 0.5, d1 - 0.5, 8 do
				table.insert(posts, z)
			end
			if posts[#posts] < d1 - 1.5 then
				table.insert(posts, d1 - 0.5)
			end
			for i, z in ipairs(posts) do
				textured(part("BridgePost", Vector3.new(1, 4, 1), at(b.x + side * (W / 2 + 0.3), 1.6, z), STONE, nil, bridges), "px_crimson_stem")
				local c = cellAtPos(b.x, z)
				if c and c.kind == "lava" then
					textured(part("BridgeStilt", Vector3.new(1.2, 30, 1.2), at(b.x + side * (W / 2 - 0.5), -16.5, z), STONE, nil, bridges), "px_crimson_stem")
				end
				if i > 1 then
					local a = Vector3.new(BX + b.x + side * (W / 2 + 0.3), 3.4, BZ + posts[i - 1])
					local e = Vector3.new(BX + b.x + side * (W / 2 + 0.3), 3.4, BZ + z)
					local m = (a + e) / 2 - Vector3.new(0, 0.9, 0)
					chain(a, m, bridges, 1.2)
					chain(m, e, bridges, 1.2)
				end
			end
		end
	else
		-- basalt slabs on two massive basalt piers in the lava, broken basalt kerbs
		local W = 8
		textured(part("BridgeDeck", Vector3.new(W, 2, d1 - d0), at(b.x, -1, (d0 + d1) / 2), STONE, nil, bridges), "px_basalt")
		local third = (zN - zS) / 3
		for _, pz in ipairs({ zS + third, zN - third }) do
			textured(part("BasaltPier", Vector3.new(W + 2, 30, 6), at(b.x, -17, pz), STONE, nil, bridges), "px_basalt", Color3.fromRGB(200, 200, 205))
			textured(part("BasaltPierCap", Vector3.new(W + 3, 1.4, 7), at(b.x, -2.6, pz), STONE, nil, bridges), "px_blackstone")
		end
		for _, side in ipairs({ -1, 1 }) do
			for z = d0, d1 - 2, 2 do
				if rng:NextNumber() < 0.8 then
					local h = rng:NextNumber(0.9, 1.8)
					textured(part("Kerb", Vector3.new(1, h, 2), at(b.x + side * (W / 2 - 0.5), h / 2, z + 1), STONE, nil, bridges), "px_basalt")
				end
			end
		end
	end
end
task.wait()

-- ================================================================ the outpost (arrival): the ruined portal, the buyer, a guardhouse
local outpost = folder("Outpost")
do
	local ox, oz = OUTPOST.x, OUTPOST.z
	local plaza = part("Plaza", Vector3.new(0.4, 36, 36), at(ox, 0.15, oz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, outpost)
	plaza.Shape = Enum.PartType.Cylinder
	textured(plaza, "px_nether_bricks", Color3.fromRGB(200, 170, 170))
	local ring = part("PlazaRing", Vector3.new(0.3, 38, 38), at(ox, 0.1, oz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, outpost)
	ring.Shape = Enum.PartType.Cylinder
	textured(ring, "px_blackstone_bricks")
	-- the ruined portal: an obsidian frame (a few blocks fallen), a violet veil, netherrack and gold round it
	do
		local px, pz = PORTAL.x, PORTAL.z
		local frame = {}
		for i = -2, 2 do
			table.insert(frame, { i, 0 })
			table.insert(frame, { i, 6 })
		end
		for j = 1, 5 do
			table.insert(frame, { -2, j })
			table.insert(frame, { 2, j })
		end
		local missing = { ["2,6"] = true, ["2,5"] = true }
		for _, f in ipairs(frame) do
			if not missing[f[1] .. "," .. f[2]] then
				textured(part("PortalFrame", Vector3.new(B, B, B), at(px + f[1] * B, f[2] * B + B / 2, pz), STONE, nil, outpost), "px_obsidian")
			end
		end
		-- the fallen blocks at its foot
		for _, f in ipairs({ { 11, 3, 0.3 }, { 9, 6, -0.4 } }) do
			textured(part("PortalFrameFallen", Vector3.new(B, B, B), at(px + f[1], B / 2, pz + f[2]) * CFrame.Angles(0, f[3], 0.2), STONE, nil, outpost), "px_obsidian")
		end
		local veil = decor(part("PortalVeil", Vector3.new(3 * B, 5 * B, 0.6), at(px, 3.5 * B, pz), Color3.fromRGB(150, 60, 230), Enum.Material.Neon, outpost))
		veil.Transparency = 0.35
		light(veil, 34, 2.2, Color3.fromRGB(170, 90, 255))
		emitter(veil, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(120, 40, 220)),
			LightEmission = 1,
			Size = NumberSequence.new(0.5, 0),
			Rate = 22,
			Lifetime = NumberRange.new(1.5, 3),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
		})
		for _ = 1, 14 do
			local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 16)
			local s = rng:NextInteger(1, 2) * 2
			local x, z = px + math.cos(a) * r, pz + math.abs(math.sin(a)) * r * 0.6 - 2
			textured(part("PortalRubble", Vector3.new(s, s, s), at(x, s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), STONE, nil, outpost), if rng:NextNumber() < 0.2 then "px_gold_block" elseif rng:NextNumber() < 0.5 then "px_netherrack_cobble" else "px_obsidian")
		end
		local spawn = part("LocationSpawn_underworld", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z + PIT.hole + 12), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), STONE, nil, outpost) -- [владелец 23.10] the arrival is by the mine, just south of the pit rim
		textured(spawn, "px_blackstone_bricks")
		spawn:SetAttribute("LocationId", "underworld")
		CollectionService:AddTag(spawn, "LocationSpawn")
	end
	-- soul lanterns on nether-brick posts round the plaza
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + 0.2
		local x, z = ox + math.cos(a) * 20, oz + math.sin(a) * 20
		if math.abs(x - ox) > 6 or z > oz then
			netherBrick("LampPost", Vector3.new(1, 7, 1), at(x, 3.5, z), outpost)
			netherBrick("LampArm", Vector3.new(0.6, 0.6, 2.2), at(x, 7, z) * CFrame.Angles(0, a + math.pi / 2, 0) * CFrame.new(0, 0, -0.8), outpost)
			lantern(x + math.cos(a + math.pi) * 0 + math.sin(a) * 0, 5.4, z, k % 2 == 0, outpost)
		end
	end
	-- the soul campfire in the middle with log benches
	do
		local fx, fz = ox - 8, oz + 6
		for k = 0, 2 do
			textured(part("CampLog", Vector3.new(0.8, 0.8, 3.2), at(fx, 0.7, fz) * CFrame.Angles(0, k * 1.05, 0.1), STONE, nil, outpost), "px_crimson_stem")
		end
		local fire = decor(part("SoulFire", Vector3.new(2.2, 0.3, 2.2), at(fx, 0.6, fz), SOUL, Enum.Material.Neon, outpost))
		local f = Instance.new("Fire")
		f.Size = 5
		f.Heat = 9
		f.Color = Color3.fromRGB(80, 200, 255)
		f.SecondaryColor = Color3.fromRGB(30, 90, 255)
		f.Parent = fire
		light(fire, 28, 1.8, Color3.fromRGB(110, 200, 255))
		for _, a in ipairs({ 0.4, 2.5, 4.5 }) do
			textured(part("Bench", Vector3.new(1, 1, 4.5), at(fx + math.cos(a) * 5, 0.5, fz + math.sin(a) * 5) * CFrame.Angles(0, -a + math.pi / 2, 0), STONE, nil, outpost), "px_crimson_stem")
		end
	end
	-- the block buyer at a stall of crimson stems under a nether-wart awning
	do
		-- [владелец 23.10] the buyer stands by the mine, next to the arrival
		local sx, sz = PIT.x + 18, PIT.z + PIT.hole + 10
		local ox, oz = PIT.x, PIT.z + PIT.hole + 12
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(196, 136, 100)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(70, 40, 40), Color3.fromRGB(40, 32, 34), Color3.fromRGB(40, 32, 34)
		local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		model.Name = "UnderworldBuyer"
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
		model.Parent = outpost
		model:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + ox, 3, BZ + oz)))
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hrp = model:FindFirstChild("HumanoidRootPart")
		CollectionService:AddTag(hrp, "SellPoint")
		sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
		-- a heat-resistant hood
		part("Hood", Vector3.new(2.3, 1.2, 2.3), model.Head.CFrame * CFrame.new(0, 0.5, 0.1), Color3.fromRGB(90, 30, 30), Enum.Material.Fabric, model).CanCollide = false
		textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), STONE, nil, outpost), "px_crimson_stem")
		textured(part("CounterTop", Vector3.new(2.8, 0.4, 9.4), at(sx, 3.2, sz), STONE, nil, outpost), "px_blackstone_bricks")
		for _, dz in ipairs({ -4.4, 4.4 }) do
			for _, dx in ipairs({ -1.2, 5 }) do
				textured(part("StallPost", Vector3.new(0.8, 9, 0.8), at(sx + dx, 4.5, sz + dz), STONE, nil, outpost), "px_crimson_stem")
			end
		end
		for k = 0, 4 do
			textured(decor(part("Awning", Vector3.new(7.6, 0.4, 2), at(sx + 1.9, 9.1 - k * 0.15, sz - 4 + k * 2) * CFrame.Angles(0, 0, -0.15), STONE, nil, outpost)), if k % 2 == 0 then "px_nether_wart" else "px_shroomlight")
		end
		lantern(sx + 1.9, 7.6, sz, false, outpost)
		for _, c in ipairs({ { -0.3, -2.5, "px_netherite" }, { -0.3, 2.5, "px_quartz_ore" }, { 6.5, 6, "px_soul_sand" } }) do
			local s = 1.8
			local crate = textured(part("Crate", Vector3.new(s, s, s), at(sx + c[1], (if c[1] < 0 then 3.4 else 0) + s / 2, sz + c[2]) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), STONE, nil, outpost), "px_crimson_stem")
			textured(decor(part("CrateLoad", Vector3.new(s * 0.8, 0.3, s * 0.8), crate.CFrame * CFrame.new(0, s / 2, 0), STONE, nil, outpost)), c[3])
		end
	end
	-- the guardhouse: nether-brick walls, a stepped blackstone roof, a barred window, a chest and a bed inside
	do
		local gx, gz = ox - 26, oz - 6
		local W, D, H = 12, 10, 7
		for _, w in ipairs({
			{ Vector3.new(W, H, 1), at(gx, H / 2, gz - D / 2) },
			{ Vector3.new(1, H, D), at(gx - W / 2, H / 2, gz) },
			{ Vector3.new(1, H, D), at(gx + W / 2, H / 2, gz) },
		}) do
			netherBrick("GuardWall", w[1], w[2], outpost)
		end
		-- the front wall (south) with a door gap and a window
		netherBrick("GuardWall", Vector3.new(4, H, 1), at(gx - 4, H / 2, gz + D / 2), outpost)
		netherBrick("GuardWall", Vector3.new(4, H, 1), at(gx + 4, H / 2, gz + D / 2), outpost)
		netherBrick("GuardLintel", Vector3.new(4, 2, 1), at(gx, H - 1, gz + D / 2), outpost)
		for k = 0, 2 do
			blackBrick("GuardRoof", Vector3.new(W + 2 - k * 4, 1, D + 2 - k * 3), at(gx, H + 0.5 + k, gz), outpost)
		end
		for _, x in ipairs({ -0.8, 0, 0.8 }) do
			part("WindowBar", Vector3.new(0.2, 2.4, 0.2), at(gx - 4 + x, 4, gz + D / 2), IRON, Enum.Material.Metal, outpost)
		end
		textured(part("GuardFloor", Vector3.new(W - 1, 0.3, D - 1), at(gx, 0.15, gz), STONE, nil, outpost), "px_blackstone")
		part("Bed", Vector3.new(3, 1.2, 5.5), at(gx + 3.5, 0.6, gz - 1.5), Color3.fromRGB(120, 30, 30), Enum.Material.Fabric, outpost)
		textured(part("Chest", Vector3.new(2.6, 2.2, 2), at(gx - 4, 1.1, gz - 3.4), STONE, nil, outpost), "px_crimson_stem")
		lantern(gx, H - 1.4, gz, false, outpost)
		lantern(gx + 3, 5, gz + D / 2 + 0.9, true, outpost)
	end
	-- crates and barrels of supplies, braziers at the plaza edge
	brazier(ox - 16, 0, oz - 16, false, outpost)
	brazier(ox + 16, 0, oz - 16, false, outpost)
	-- the signpost at the plaza: «Шахта» points north to the mine
	do
		local sx, sz = ox + 6, oz - 20
		netherBrick("SignPost", Vector3.new(0.8, 7, 0.8), at(sx, 3.5, sz), outpost)
		local toMine = blackBrick("Signboard", Vector3.new(5, 1.2, 0.35), at(sx, 5.8, sz) * CFrame.Angles(0, math.atan2(PIT.x - sx, PIT.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), outpost)
		boardText(toMine, "Шахта")
		local toBastion = blackBrick("Signboard", Vector3.new(5, 1.2, 0.35), at(sx, 4.4, sz) * CFrame.Angles(0, math.atan2(BASTION.x - sx, BASTION.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), outpost)
		boardText(toBastion, "Бастион")
	end
end
task.wait()

-- ================================================================ the mine: pit, nether-brick rim, towers, chains to the ceiling
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	local function bedrock(p)
		textured(p, "px_blackstone", Color3.fromRGB(150, 130, 130))
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
	-- the rim: nether bricks round the edge (just above the ground), a fence with gaps where the trails come in
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], STONE, nil, mine), "px_nether_bricks")
	end
	for _, s in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			fence(mx + half * 8, mz + s * edge, mx + half * (edge - 10), mz + s * edge, 0.6, mine)
			fence(mx + s * edge, mz + half * 8, mx + s * edge, mz + half * (edge - 10), 0.6, mine)
		end
	end
	local anchor = part("MineAnchor_underworld", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), STONE, nil, mine)
	anchor:SetAttribute("LocationId", "underworld")
	anchor:SetAttribute("MineId", "underworld")
	anchor:SetAttribute("Size", Vector3.new(PIT.size, PIT.depth, PIT.size))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, "Шахта", 14)
	-- four ladders (invisible 2×2 trusses + a textured plate), like the other mines
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
	-- four nether-brick towers at the corners: battlements, a brazier on top, a great chain up to the ceiling
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local tx, tz = mx + s[1] * (edge + 6), mz + s[2] * (edge + 6)
		local TH = 22
		netherBrick("TowerBase", Vector3.new(10, 2, 10), at(tx, 1, tz), mine)
		netherBrick("Tower", Vector3.new(8, TH, 8), at(tx, TH / 2, tz), mine)
		for _, y in ipairs({ 7, 15 }) do
			textured(part("TowerBand", Vector3.new(8.4, 0.8, 8.4), at(tx, y, tz), STONE, nil, mine), "px_blackstone_bricks")
		end
		netherBrick("TowerTop", Vector3.new(10, 1.2, 10), at(tx, TH + 0.6, tz), mine)
		for _, m in ipairs({ { -4.4, -4.4 }, { 0, -4.4 }, { 4.4, -4.4 }, { -4.4, 0 }, { 4.4, 0 }, { -4.4, 4.4 }, { 0, 4.4 }, { 4.4, 4.4 } }) do
			netherBrick("Merlon", Vector3.new(1.2, 1.6, 1.2), at(tx + m[1], TH + 2, tz + m[2]), mine)
		end
		brazier(tx, TH + 1.2, tz, false, mine)
		-- the window slits facing the pit, glowing from inside
		for _, y in ipairs({ 11, 18 }) do
			decor(part("TowerSlit", Vector3.new(0.9, 2.2, 0.2), at(tx - s[1] * 2, y, tz - s[2] * 4.05), LAMP, Enum.Material.Neon, mine))
		end
		local c = cellAtPos(tx, tz)
		local top = (c and c.ceil or 140) - 1
		chain(Vector3.new(BX + tx, TH + 4, BZ + tz), Vector3.new(BX + tx - s[1] * 10, top, BZ + tz - s[2] * 10), mine, 2.2)
		textured(part("ChainAnchor", Vector3.new(4, 2, 4), at(tx - s[1] * 10, top - 0.5, tz - s[2] * 10), STONE, nil, mine), "px_blackstone_bricks")
	end
	-- carts of quartz and soul sand at the rim, a hoist frame over the north ladder
	for _, c in ipairs({ { mx - 20, mz + edge + 5, "px_quartz_ore" }, { mx + 24, mz - edge - 5, "px_soul_sand" }, { mx - edge - 5, mz - 18, "px_netherite" } }) do
		local cart = part("Cart", Vector3.new(4, 2.4, 3), at(c[1], 1.8, c[2]), IRON, Enum.Material.Metal, mine)
		textured(decor(part("CartLoad", Vector3.new(3.4, 0.6, 2.4), cart.CFrame * CFrame.new(0, 1.3, 0), STONE, nil, mine)), c[3])
		for _, w in ipairs({ { -1.4, -1.6 }, { 1.4, -1.6 }, { -1.4, 1.6 }, { 1.4, 1.6 } }) do
			local wheel = part("CartWheel", Vector3.new(0.4, 1.2, 1.2), at(c[1] + w[1], 0.6, c[2] + w[2] * 0.95), IRON, Enum.Material.Metal, mine)
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end
task.wait()

-- ================================================================ the bastion of the King of the Piglins (the arena)
local arena = folder("PiglinBastion")
-- a blocky piglin (the minion of the King [клиент: «Пиглин»]) as a golden statue
local function piglinStatue(x, z, scale, yaw, material, tint, variant)
	local y = 0
	local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local function b(name, size, offset)
		local p = part(name, size * scale, base * CFrame.new(offset[1] * scale, offset[2] * scale, offset[3] * scale), tint, material, arena)
		if variant then
			textured(p, variant, tint)
		end
		return p
	end
	b("StatueLeg", Vector3.new(0.9, 1.5, 0.9), { -0.5, 0.75, 0 })
	b("StatueLeg", Vector3.new(0.9, 1.5, 0.9), { 0.5, 0.75, 0 })
	b("StatueBody", Vector3.new(2, 1.6, 1.1), { 0, 2.3, 0 })
	b("StatueArm", Vector3.new(0.8, 1.6, 0.8), { -1.4, 2.3, 0 })
	b("StatueArm", Vector3.new(0.8, 1.6, 0.8), { 1.4, 2.3, -0.3 })
	b("StatueHead", Vector3.new(2.2, 1.7, 1.8), { 0, 3.95, 0 })
	b("StatueSnout", Vector3.new(1, 0.7, 0.4), { 0, 3.7, -1.05 })
	b("StatueEar", Vector3.new(0.3, 0.9, 0.6), { -1.25, 4.1, 0 })
	b("StatueEar", Vector3.new(0.3, 0.9, 0.6), { 1.25, 4.1, 0 })
	b("StatueTusk", Vector3.new(0.2, 0.4, 0.2), { -0.6, 3.35, -0.95 })
	b("StatueTusk", Vector3.new(0.2, 0.4, 0.2), { 0.6, 3.35, -0.95 })
	b("StatueAxe", Vector3.new(0.2, 2.6, 0.2), { 1.4, 2.6, -1.1 })
	b("StatueAxeHead", Vector3.new(0.25, 0.9, 1), { 1.4, 3.6, -1.4 })
end
do
	local cx, cz, HALF = BASTION.x, BASTION.z, BASTION.half
	local WALL_H, T = 26, 6
	local floorP = part("BastionFloor", Vector3.new(HALF * 2 - 2, 0.4, HALF * 2 - 2), at(cx, 0.2, cz), STONE, nil, arena)
	textured(floorP, "px_blackstone_bricks")
	-- the courtyard pattern: a gold ring and a gilded cross under the boss
	local ringP = decor(part("FloorRing", Vector3.new(0.1, 30, 30), at(cx, 0.42, cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, arena))
	ringP.Shape = Enum.PartType.Cylinder
	textured(ringP, "px_gilded_blackstone")
	local ringIn = decor(part("FloorRingIn", Vector3.new(0.12, 26, 26), at(cx, 0.43, cz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, arena))
	ringIn.Shape = Enum.PartType.Cylinder
	textured(ringIn, "px_blackstone")
	for _, s in ipairs({ { 1, 0 }, { 0, 1 } }) do
		textured(decor(part("FloorCross", Vector3.new(if s[1] == 1 then 24 else 2, 0.14, if s[1] == 1 then 2 else 24), at(cx, 0.44, cz), STONE, nil, arena)), "px_gold_block")
	end
	-- the walls: each side as segments; the inner faces are the ArenaWall (the charge stuns on them)
	local function wallSeg(x0, z0, x1, z1)
		local p = blackBrick("ArenaWall", Vector3.new(math.abs(x1 - x0) + T * (if z0 == z1 then 0 else 1), WALL_H, math.abs(z1 - z0) + T * (if x0 == x1 then 0 else 1)), at((x0 + x1) / 2, WALL_H / 2, (z0 + z1) / 2), arena)
		return p
	end
	wallSeg(cx - HALF, cz - HALF, cx + HALF, cz - HALF) -- north
	wallSeg(cx - HALF, cz - HALF, cx - HALF, cz + HALF) -- west
	wallSeg(cx + HALF, cz - HALF, cx + HALF, cz + HALF) -- east
	-- the south wall with the gate (16 wide, 18 high)
	local GATE_W, GATE_H = 16, 18
	local sideLen = HALF - GATE_W / 2
	for _, s in ipairs({ -1, 1 }) do
		blackBrick("ArenaWall", Vector3.new(sideLen + T / 2, WALL_H, T), at(cx + s * (GATE_W / 2 + (sideLen + T / 2) / 2), WALL_H / 2, cz + HALF), arena)
	end
	blackBrick("GateLintel", Vector3.new(GATE_W, WALL_H - GATE_H, T), at(cx, GATE_H + (WALL_H - GATE_H) / 2, cz + HALF), arena)
	-- the raised portcullis with a few bars hanging down
	for x = -GATE_W / 2 + 1, GATE_W / 2 - 1, 2 do
		local len = if (x % 6 == 1) then 6 else 2.5
		part("Portcullis", Vector3.new(0.4, len, 0.4), at(cx + x, GATE_H - len / 2, cz + HALF + 1.5), IRON, Enum.Material.Metal, arena)
	end
	part("PortcullisBar", Vector3.new(GATE_W, 0.5, 0.5), at(cx, GATE_H - 0.3, cz + HALF + 1.5), IRON, Enum.Material.Metal, arena)
	-- the name carved over the gate on the outer (south) face of the lintel
	local gateSign = textured(decor(part("BastionSign", Vector3.new(GATE_W + 4, 3, 0.3), at(cx, GATE_H + 4, cz + HALF + T / 2 + 0.15), STONE, nil, arena)), "px_gilded_blackstone")
	boardText(gateSign, "Бастион Короля Пиглинов", Color3.fromRGB(255, 215, 90), { Enum.NormalId.Back })
	-- gold bands, battlements and black-and-gold banners on the walls, outside and in
	for _, w in ipairs({
		{ cx, cz - HALF, true },
		{ cx - HALF, cz, false },
		{ cx + HALF, cz, false },
	}) do
		local len = HALF * 2 + T
		local size = if w[3] then Vector3.new(len, 0.8, T + 0.3) else Vector3.new(T + 0.3, 0.8, len)
		textured(part("WallBand", size, at(w[1], 9, w[2]), STONE, nil, arena), "px_gilded_blackstone")
		textured(part("WallBand", size, at(w[1], WALL_H - 1, w[2]), STONE, nil, arena), "px_gilded_blackstone")
	end
	for _, w in ipairs({ { cx - HALF - 0, cz + HALF, cx - GATE_W / 2, cz + HALF }, { cx + GATE_W / 2, cz + HALF, cx + HALF, cz + HALF } }) do
		local len = math.abs(w[3] - w[1])
		textured(part("WallBand", Vector3.new(len, 0.8, T + 0.3), at((w[1] + w[3]) / 2, 9, w[2]), STONE, nil, arena), "px_gilded_blackstone")
	end
	-- battlements all round
	for k = -HALF, HALF, 4 do
		for _, m in ipairs({ { cx + k, cz - HALF }, { cx - HALF, cz + k }, { cx + HALF, cz + k }, { cx + k, cz + HALF } }) do
			if not (m[2] == cz + HALF and math.abs(m[1] - cx) < GATE_W / 2) then
				blackBrick("Merlon", Vector3.new(2, 2.4, 2), at(m[1], WALL_H + 1.2, m[2]), arena)
			end
		end
	end
	-- corner towers, taller, with gold caps and braziers
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local tx, tz = cx + s[1] * HALF, cz + s[2] * HALF
		blackBrick("BastionTower", Vector3.new(14, 38, 14), at(tx, 19, tz), arena)
		textured(part("TowerGold", Vector3.new(14.4, 1, 14.4), at(tx, 30, tz), STONE, nil, arena), "px_gold_block")
		blackBrick("TowerCrown", Vector3.new(16, 1.6, 16), at(tx, 38.8, tz), arena)
		for _, m in ipairs({ { -7.2, -7.2 }, { 0, -7.2 }, { 7.2, -7.2 }, { -7.2, 0 }, { 7.2, 0 }, { -7.2, 7.2 }, { 0, 7.2 }, { 7.2, 7.2 } }) do
			blackBrick("Merlon", Vector3.new(2, 2.6, 2), at(tx + m[1], 40.9, tz + m[2]), arena)
		end
		brazier(tx, 39.6, tz, false, arena)
	end
	-- banners: black cloth with a gold stripe, hanging on the outer faces and inside
	local function banner(x, z, yaw, y)
		local base = at(x, y or 20, z) * CFrame.Angles(0, yaw, 0)
		part("BannerRod", Vector3.new(4.4, 0.3, 0.3), base * CFrame.new(0, 4.2, 0), IRON, Enum.Material.Metal, arena)
		decor(part("Banner", Vector3.new(3.6, 8, 0.15), base, Color3.fromRGB(28, 24, 30), Enum.Material.Fabric, arena))
		decor(part("BannerStripe", Vector3.new(0.9, 7.6, 0.17), base, GOLD, Enum.Material.Fabric, arena))
		decor(part("BannerTip", Vector3.new(3.6, 0.6, 0.17), base * CFrame.new(0, -3.4, 0), GOLD, Enum.Material.Fabric, arena))
	end
	for _, k in ipairs({ -26, -12, 12, 26 }) do
		banner(cx + k, cz + HALF + T / 2 + 0.2, 0, 16) -- outside, south, either side of the gate
		banner(cx + k, cz - HALF + T / 2 + 0.2, 0, 16) -- inside, north
		banner(cx - HALF + T / 2 + 0.2, cz + k, math.pi / 2, 16) -- inside, west
		banner(cx + HALF - T / 2 - 0.2, cz + k, math.pi / 2, 16) -- inside, east
	end
	-- the four pillars round the centre: the charge stuns on them (names Pillar*)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local px, pz = cx + s[1] * 18, cz + s[2] * 18
		blackBrick("PillarBase", Vector3.new(7, 2, 7), at(px, 1, pz), arena)
		textured(part("Pillar", Vector3.new(5, 18, 5), at(px, 11, pz), STONE, nil, arena), "px_gilded_blackstone")
		blackBrick("PillarCap", Vector3.new(7, 1.6, 7), at(px, 20.8, pz), arena)
		brazier(px, 21.6, pz, false, arena)
	end
	-- the throne on a stepped dais against the north wall, gold heaps round it
	do
		local tz = cz - HALF + T / 2 + 6
		for k = 0, 2 do
			blackBrick("Dais", Vector3.new(22 - k * 5, 1, 10 - k * 2), at(cx, 0.9 + k, tz - k * 0.5), arena)
		end
		local seatY = 3.4
		textured(part("ThroneSeat", Vector3.new(6, 1.6, 4), at(cx, seatY + 0.8, tz - 1.4), STONE, nil, arena), "px_gilded_blackstone")
		textured(part("ThroneBack", Vector3.new(6, 9, 1.4), at(cx, seatY + 5, tz - 3.6), STONE, nil, arena), "px_gilded_blackstone")
		textured(part("ThroneCrest", Vector3.new(3.4, 2.4, 1.6), at(cx, seatY + 10.4, tz - 3.6), STONE, nil, arena), "px_gold_block")
		for _, s in ipairs({ -1, 1 }) do
			textured(part("ThroneArm", Vector3.new(1.2, 2.4, 4), at(cx + s * 3.4, seatY + 1.6, tz - 1.4), STONE, nil, arena), "px_gold_block")
			textured(part("ThroneSpike", Vector3.new(1, 3, 1), at(cx + s * 2.6, seatY + 11, tz - 3.6), STONE, nil, arena), "px_gold_block")
		end
		-- heaps of gold blocks and bars
		for _ = 1, 26 do
			local a = rng:NextNumber(-0.3, math.pi + 0.3)
			local r = rng:NextNumber(9, 15)
			local x, z = cx + math.cos(a) * r, tz - math.abs(math.sin(a)) * 3 + rng:NextNumber(-1, 4)
			local s = rng:NextInteger(1, 2) * 2
			textured(part("GoldHeap", Vector3.new(s, s, s), at(x, s / 2 + 0.4, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), STONE, nil, arena), "px_gold_block")
		end
		for _ = 1, 30 do
			local x, z = cx + rng:NextNumber(-12, 12), tz + rng:NextNumber(-2, 5)
			decor(part("GoldBar", Vector3.new(1.2, 0.4, 0.6), at(x, 0.6 + rng:NextNumber(0, 1.2), z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), GOLD, Enum.Material.Metal, arena))
		end
	end
	-- two golden piglins guard the gate, outside, on pedestals
	for _, s in ipairs({ -1, 1 }) do
		local x, z = cx + s * (GATE_W / 2 + 5), cz + HALF + T / 2 + 4
		blackBrick("StatuePedestal", Vector3.new(6, 3, 6), at(x, 1.5, z), arena)
		textured(part("PedestalGold", Vector3.new(6.3, 0.5, 6.3), at(x, 3, z), STONE, nil, arena), "px_gilded_blackstone")
	end
	piglinStatue(cx - (GATE_W / 2 + 5), cz + HALF + T / 2 + 4, 2.1, math.pi, Enum.Material.Metal, GOLD)
	piglinStatue(cx + (GATE_W / 2 + 5), cz + HALF + T / 2 + 4, 2.1, math.pi, Enum.Material.Metal, GOLD)
	-- lift the statues onto the pedestals
	for _, p in ipairs(arena:GetChildren()) do
		if p.Name:match("^Statue") and p.Name ~= "StatuePedestal" then
			p.CFrame = p.CFrame + Vector3.new(0, 3.25, 0)
		end
	end
	-- chains from the walls into the courtyard, hanging lanterns
	for _, k in ipairs({ -20, 20 }) do
		chain(Vector3.new(BX + cx + k, WALL_H - 2, BZ + cz - HALF + T / 2), Vector3.new(BX + cx + k * 0.4, WALL_H - 8, BZ + cz - 8), arena, 1.4)
		chain(Vector3.new(BX + cx + k * 0.4, WALL_H - 8, BZ + cz - 8), Vector3.new(BX + cx + k * 0.4, WALL_H - 12, BZ + cz - 8), arena, 1.4)
		lantern(cx + k * 0.4, WALL_H - 13, cz - 8, false, arena)
	end
	-- the boss
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(cx, 1.2, cz), STONE, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "piglin")
	bossSpawn:SetAttribute("ArenaRadius", HALF - T)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end
task.wait()

-- ================================================================ nature: forests, the soul valley, the deltas, the fortress ruins
local nature = folder("Nature")
local function clear(x, z, margin)
	local c = cellAtPos(x, z)
	if not c or c.kind ~= "ground" or c.path or flat(x, z) or nearBridge(x, z) or onTrail(x, z) then
		return false
	end
	if margin and nearLava(x, z, margin) then
		return false
	end
	return true
end
local function scatter(n, tries, test, place)
	local made = 0
	for _ = 1, tries do
		if made >= n then
			break
		end
		local x, z = rng:NextNumber(-R, R), rng:NextNumber(-R, R)
		if test(x, z) then
			place(x, z)
			made += 1
		end
	end
	return made
end
-- a huge fungus: a stem, a cap of wart blocks on a 4-stud grid with a hanging skirt, shroomlights under it
local function fungus(x, z, warped)
	local y = floorAt(x, z)
	local big = rng:NextNumber() < 0.35
	local sw = if big then 8 else 4
	local h = rng:NextInteger(if big then 6 else 4, if big then 9 else 7) * B
	local stemV = if warped then "px_warped_stem" else "px_crimson_stem"
	local wartV = if warped then "px_warped_wart" else "px_nether_wart"
	textured(part("FungusStem", Vector3.new(sw, h, sw), at(x, y + h / 2, z), STONE, nil, nature), stemV)
	local r = if big then 4 else 3
	local topY = y + h
	-- the top layer, merged into rows
	for j = -r, r do
		local i0 = nil
		for i = -r, r + 1 do
			local inside = i <= r and (i * i + j * j) <= r * r + 1
			if inside and not i0 then
				i0 = i
			elseif not inside and i0 then
				textured(part("FungusCap", Vector3.new((i - i0) * B, B, B), at(x + (i0 + i - 1) / 2 * B, topY + B / 2, z + j * B), STONE, nil, nature), wartV)
				i0 = nil
			end
		end
	end
	-- a second, smaller top layer
	for j = -(r - 2), r - 2 do
		local w = math.floor(math.sqrt(math.max(0, (r - 2) ^ 2 + 1 - j * j)))
		if w >= 0 then
			textured(part("FungusCap", Vector3.new((2 * w + 1) * B, B, B), at(x, topY + B * 1.5, z + j * B), STONE, nil, nature), wartV)
		end
	end
	-- the skirt hanging from the edge, shroomlights in it, weeping vines from the crimson ones
	for j = -r, r do
		for i = -r, r do
			local d2 = i * i + j * j
			if d2 <= r * r + 1 and d2 >= (r - 1) * (r - 1) then
				local drop = rng:NextInteger(1, 2)
				for k = 1, drop do
					local cf = at(x + i * B, topY - (k - 0.5) * B, z + j * B)
					if rng:NextNumber() < 0.14 then
						glow("Shroomlight", Vector3.new(B, B, B), cf, Color3.fromRGB(255, 170, 90), "shroomlight", nature)
					else
						textured(part("FungusSkirt", Vector3.new(B, B, B), cf, STONE, nil, nature), wartV)
					end
				end
				if not warped and rng:NextNumber() < 0.3 then
					local len = rng:NextNumber(4, 12)
					decor(part("WeepingVine", Vector3.new(0.6, len, 0.6), at(x + i * B + rng:NextNumber(-1.2, 1.2), topY - drop * B - len / 2, z + j * B + rng:NextNumber(-1.2, 1.2)), Color3.fromRGB(150, 20, 28), Enum.Material.Grass, nature))
				end
			end
		end
	end
	local l = decor(part("FungusGlow", Vector3.new(1, 1, 1), at(x, topY - B, z), GLOW, nil, nature))
	l.Transparency = 1
	light(l, 26, 1.1, Color3.fromRGB(255, 160, 90))
end
-- small flora: roots (two crossed planes), sprouts, small fungi
local function roots(x, z, warped)
	local y = floorAt(x, z)
	local col = if warped then Color3.fromRGB(30, 170, 150) else Color3.fromRGB(170, 30, 40)
	local h = rng:NextNumber(1.2, 2.2)
	for k = 0, 1 do
		decor(part("Roots", Vector3.new(1.6, h, 0.05), at(x, y + h / 2, z) * CFrame.Angles(0, k * math.pi / 2 + 0.78, 0), col, Enum.Material.Grass, nature))
	end
end
local function smallFungus(x, z, warped)
	local y = floorAt(x, z)
	decor(part("FungusSmallStem", Vector3.new(0.35, 1.1, 0.35), at(x, y + 0.55, z), Color3.fromRGB(230, 200, 170), Enum.Material.SmoothPlastic, nature))
	decor(part("FungusSmallCap", Vector3.new(1.4, 0.5, 1.4), at(x, y + 1.25, z), if warped then Color3.fromRGB(30, 150, 140) else Color3.fromRGB(190, 30, 30), Enum.Material.SmoothPlastic, nature))
end
local function twistingVine(x, z)
	local y = floorAt(x, z)
	local h = rng:NextNumber(4, 12)
	local seg = 0
	while seg < h do
		local len = math.min(2, h - seg)
		decor(part("TwistingVine", Vector3.new(0.6, len, 0.6), at(x + math.sin(seg * 1.3) * 0.4, y + seg + len / 2, z + math.cos(seg * 1.1) * 0.4), Color3.fromRGB(40, 190, 170), Enum.Material.Grass, nature))
		seg += len
	end
end
local function inBiome(b)
	return function(x, z, margin)
		local c = cellAtPos(x, z)
		return c and c.biome == b and clear(x, z) and not nearLava(x, z, margin or 1)
	end
end
local crimsonOk, warpedOk, soulOk, deltaOk, wastesOk = inBiome("crimson"), inBiome("warped"), inBiome("soul"), inBiome("delta"), inBiome("wastes")
-- fungi keep apart from each other
local fungi = {}
local function apart(x, z, d)
	for _, f in ipairs(fungi) do
		if (f[1] - x) ^ 2 + (f[2] - z) ^ 2 < d * d then
			return false
		end
	end
	return true
end
scatter(24, 3000, function(x, z)
	return crimsonOk(x, z, 1) and apart(x, z, 22)
end, function(x, z)
	table.insert(fungi, { x, z })
	fungus(x, z, false)
end)
task.wait()
scatter(24, 3000, function(x, z)
	return warpedOk(x, z, 1) and apart(x, z, 22)
end, function(x, z)
	table.insert(fungi, { x, z })
	fungus(x, z, true)
end)
task.wait()
scatter(220, 6000, function(x, z)
	return crimsonOk(x, z, 0)
end, function(x, z)
	if rng:NextNumber() < 0.15 then
		smallFungus(x, z, false)
	else
		roots(x, z, false)
	end
end)
scatter(220, 6000, function(x, z)
	return warpedOk(x, z, 0)
end, function(x, z)
	local roll = rng:NextNumber()
	if roll < 0.15 then
		smallFungus(x, z, true)
	elseif roll < 0.35 then
		twistingVine(x, z)
	else
		roots(x, z, true)
	end
end)
task.wait()

-- the soul sand valley: blue soul fire, giant fossils, basalt pillars, soul wisps
local function soulFire(x, z)
	local y = floorAt(x, z)
	local p = decor(part("SoulFireBase", Vector3.new(2, 0.2, 2), at(x, y + 0.1, z), SOUL, Enum.Material.Neon, nature))
	local f = Instance.new("Fire")
	f.Size = rng:NextNumber(3, 5)
	f.Heat = 8
	f.Color = Color3.fromRGB(80, 200, 255)
	f.SecondaryColor = Color3.fromRGB(30, 90, 255)
	f.Parent = p
	light(p, 22, 1.5, Color3.fromRGB(100, 200, 255))
end
local function fossil(x, z, yaw, len)
	local y = floorAt(x, z) - 1.5 -- half buried
	local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local function bone(size, off)
		local p = part("Fossil", size, base * CFrame.new(off[1], off[2], off[3]), BONE, Enum.Material.SmoothPlastic, nature)
		return p
	end
	bone(Vector3.new(2, 2, len), { 0, 6, 0 }) -- the spine, high
	for k = -len / 2 + 2, len / 2 - 2, 4 do
		for _, s in ipairs({ -1, 1 }) do
			bone(Vector3.new(4, 2, 2), { s * 2, 6, k })
			bone(Vector3.new(2, 2, 2), { s * 4.6, 4.5, k })
			bone(Vector3.new(2, 4, 2), { s * 5.4, 1.8, k })
		end
	end
	-- the skull at the front
	local skull = bone(Vector3.new(7, 6, 7), { 0, 6, -len / 2 - 3.5 })
	for _, s in ipairs({ -1, 1 }) do
		decor(part("FossilEye", Vector3.new(1.6, 1.4, 0.2), skull.CFrame * CFrame.new(s * 1.6, 0.6, -3.55), Color3.fromRGB(20, 18, 22), Enum.Material.SmoothPlastic, nature))
	end
	bone(Vector3.new(5, 1.4, 3), { 0, 3.3, -len / 2 - 5 })
end
local function basaltPillar(x, z, h)
	local y = floorAt(x, z)
	textured(part("BasaltColumn", Vector3.new(B, h, B), at(x, y + h / 2, z), STONE, nil, nature), "px_basalt")
end
scatter(16, 3000, function(x, z)
	return soulOk(x, z, 1)
end, soulFire)
local fossils = 0
for _ = 1, 400 do
	if fossils >= 4 then
		break
	end
	local x, z = rng:NextNumber(-R, -40), rng:NextNumber(120, R)
	local ok = true
	for dx = -14, 14, 7 do
		for dz = -14, 14, 7 do
			if not soulOk(x + dx, z + dz, 0) then
				ok = false
			end
		end
	end
	if ok then
		fossils += 1
		fossil(x, z, rng:NextNumber(0, math.pi), rng:NextInteger(5, 7) * 4)
	end
end
scatter(9, 2000, function(x, z)
	return soulOk(x, z, 1)
end, function(x, z)
	for _ = 1, rng:NextInteger(1, 3) do
		basaltPillar(x + rng:NextInteger(-1, 1) * B, z + rng:NextInteger(-1, 1) * B, rng:NextInteger(2, 6) * B)
	end
end)
task.wait()

-- the basalt deltas: clusters of basalt columns, blackstone mounds, magma
scatter(34, 4000, function(x, z)
	return deltaOk(x, z, 0)
end, function(x, z)
	for _ = 1, rng:NextInteger(3, 7) do
		local px, pz = x + rng:NextInteger(-2, 2) * B, z + rng:NextInteger(-2, 2) * B
		if deltaOk(px, pz, 0) then
			basaltPillar(px, pz, rng:NextInteger(1, 9) * B)
		end
	end
end)
scatter(30, 3000, function(x, z)
	return deltaOk(x, z, 0)
end, function(x, z)
	local y = floorAt(x, z)
	for _ = 1, rng:NextInteger(2, 5) do
		local s = rng:NextInteger(1, 2) * B
		textured(part("Blackstone", Vector3.new(s, s, s), at(x + rng:NextInteger(-1, 1) * B, y + s / 2, z + rng:NextInteger(-1, 1) * B), STONE, nil, nature), if rng:NextNumber() < 0.15 then "px_gilded_blackstone" else "px_blackstone")
	end
end)
task.wait()

-- the ruins of a nether fortress (south-east): a corridor on arches over a lava pool, a broken tower,
-- a nether-wart garden, a caged fire (a spawner)
local ruins = folder("FortressRuins")
do
	local rx, rz = 150, 196
	-- the broken tower
	local TW = 12
	for _, w in ipairs({
		{ Vector3.new(TW, 30, 1.5), at(rx, 15, rz - TW / 2) },
		{ Vector3.new(1.5, 24, TW), at(rx - TW / 2, 12, rz) },
		{ Vector3.new(1.5, 18, TW), at(rx + TW / 2, 9, rz) },
		{ Vector3.new(TW / 2 - 2, 14, 1.5), at(rx - TW / 4 - 1, 7, rz + TW / 2) },
	}) do
		netherBrick("RuinWall", w[1], w[2], ruins)
	end
	for _, y in ipairs({ 10, 20 }) do
		for _, x in ipairs({ -0.8, 0, 0.8 }) do
			netherBrick("RuinWindowBar", Vector3.new(0.3, 3, 0.3), at(rx + x, y, rz - TW / 2 - 0.4), ruins)
		end
	end
	for _ = 1, 16 do
		local s = rng:NextInteger(1, 2) * 2
		netherBrick("RuinRubble", Vector3.new(s, s, s), at(rx + rng:NextNumber(-12, 14), s / 2, rz + rng:NextNumber(-10, 12)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), rng:NextNumber(-0.2, 0.2)), ruins)
	end
	-- the corridor: a raised nether-brick walk on arches, ending broken off
	local cx0, cx1, cz = rx - 70, rx - 16, rz - 22
	for x = cx0, cx1 - 1, 1 do
		local u = x - cx0
		local s = 16
		local l = u % s
		local bottom = if l < 4 then floorAt(x, cz) else 6 + math.sqrt(math.max(0, 36 - (l - 10) ^ 2))
		local top = 12
		if x > cx1 - 8 then
			top = 12 - (x - (cx1 - 8)) * 0.8 -- the broken end
		end
		netherBrick("CorridorArch", Vector3.new(1, top - bottom, 8), at(x + 0.5, (top + bottom) / 2, cz), ruins)
	end
	for _, side in ipairs({ -1, 1 }) do
		fence(cx0 + 0.5, cz + side * 3.6, cx1 - 9, cz + side * 3.6, 12, ruins)
	end
	-- the nether-wart garden on soul sand with nether-brick stair edges
	local gx, gz = rx - 26, rz + 4
	textured(part("WartBed", Vector3.new(12, 1, 8), at(gx, 0.5, gz), STONE, nil, ruins), "px_soul_sand")
	for _, s in ipairs({ -1, 1 }) do
		netherBrick("WartEdge", Vector3.new(14, 1.4, 1), at(gx, 0.7, gz + s * 4.5), ruins)
		netherBrick("WartEdge", Vector3.new(1, 1.4, 8), at(gx + s * 6.5, 0.7, gz), ruins)
	end
	for i = -2, 2 do
		for j = -1, 1 do
			local x, z = gx + i * 2.2, gz + j * 2.2
			decor(part("Wart", Vector3.new(0.9, rng:NextNumber(0.6, 1.2), 0.9), at(x, 1.4, z), Color3.fromRGB(150, 20, 30), Enum.Material.Grass, ruins))
		end
	end
	-- the caged fire
	local fx, fz = rx + 2, rz + 14
	for _, e in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
		part("CageEdge", Vector3.new(0.3, 4, 0.3), at(fx + e[1], 2, fz + e[2]), IRON, Enum.Material.Metal, ruins)
	end
	for _, y in ipairs({ 0.15, 3.85 }) do
		part("CageFrame", Vector3.new(4.3, 0.3, 4.3), at(fx, y, fz), IRON, Enum.Material.Metal, ruins).Transparency = 0.5
	end
	for k = -1.2, 1.2, 0.8 do
		for _, s in ipairs({ -1, 1 }) do
			part("CageBar", Vector3.new(0.12, 3.6, 0.12), at(fx + k, 2, fz + s * 2), IRON, Enum.Material.Metal, ruins)
			part("CageBar", Vector3.new(0.12, 3.6, 0.12), at(fx + s * 2, 2, fz + k), IRON, Enum.Material.Metal, ruins)
		end
	end
	local flame = decor(part("CageFlame", Vector3.new(1, 1, 1), at(fx, 1.5, fz), LAVA, Enum.Material.Neon, ruins))
	local f = Instance.new("Fire")
	f.Size = 4
	f.Heat = 10
	f.Parent = flame
	light(flame, 20, 1.4, Color3.fromRGB(255, 150, 60))
end
-- scattered netherrack boulders and quartz in the wastes
scatter(26, 2000, function(x, z)
	return wastesOk(x, z, 0)
end, function(x, z)
	local y = floorAt(x, z)
	local s = rng:NextInteger(1, 3) * B
	textured(part("Boulder", Vector3.new(s, s, s), at(x, y + s / 2 - 1, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), STONE, nil, nature), if rng:NextNumber() < 0.3 then "px_quartz_ore" else "px_netherrack_cobble")
end)
task.wait()

-- ================================================================ zone signs: each name at its zone edge, on the trail
zoneSign(-116, 18, "Багровый лес", math.atan2(1, 0))
zoneSign(116, 4, "Искажённый лес", math.atan2(1, 0))
zoneSign(-80, 178, "Долина душ", math.atan2(1, 0))
zoneSign(80, 178, "Руины крепости", math.atan2(1, 0))
zoneSign(-46, -84, "Базальтовые дельты", math.atan2(1, 0.4))
zoneSign(46, -84, "Базальтовые дельты", math.atan2(1, -0.4))

-- ================================================================ ghasts drifting high in the cave
local function ghast(x, y, z, yaw, crying)
	local m = Instance.new("Model")
	m.Name = "Ghast"
	m.Parent = props
	local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local body = part("GhastBody", Vector3.new(16, 16, 16), base, Color3.fromRGB(238, 236, 236), Enum.Material.SmoothPlastic, m)
	decor(body)
	for _, s in ipairs({ -1, 1 }) do
		decor(part("GhastEye", Vector3.new(3, 0.8, 0.2), base * CFrame.new(s * 3.4, 2.4, -8.05), Color3.fromRGB(40, 40, 46), nil, m))
		if crying then
			decor(part("GhastTear", Vector3.new(0.8, 3, 0.2), base * CFrame.new(s * 3.4, 0.4, -8.05), Color3.fromRGB(170, 190, 200), nil, m))
		end
	end
	decor(part("GhastMouth", Vector3.new(4, 2.4, 0.2), base * CFrame.new(0, -3, -8.05), Color3.fromRGB(40, 40, 46), nil, m))
	for i = -1, 1 do
		for j = -1, 1 do
			local len = rng:NextNumber(8, 16)
			decor(part("GhastTentacle", Vector3.new(2, len, 2), base * CFrame.new(i * 5, -8 - len / 2, j * 5) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), 0, rng:NextNumber(-0.1, 0.1)), Color3.fromRGB(225, 222, 222), nil, m))
		end
	end
end
ghast(-130, 78, -40, 0.6, false)
ghast(150, 88, 40, -0.8, true)
ghast(-60, 96, 140, 2.6, false)

-- ================================================================ the air: the red murk, ash and embers
-- (a Persistent model: with streaming the client always has the lighting volume, however far its centre is)
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = part("IndoorVolume", Vector3.new(2 * 288, 240, 2 * 288), at(0, 80, 0), STONE, nil, air)
volume.Transparency = 1
decor(volume)
volume:SetAttribute("Ambient", Color3.fromRGB(115, 76, 70))
volume:SetAttribute("Exposure", -0.15)
volume:SetAttribute("Haze", 0.25) -- [владелец 23.10: «слишком ярко, не видно»]
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(150, 54, 36))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(110, 30, 18))
CollectionService:AddTag(volume, "IndoorLighting")
local function airEmitter(x, z, size, props_)
	local p = decor(part("AirParticles", Vector3.new(size, 1, size), at(x, 60, z), STONE, nil, props))
	p.Transparency = 1
	emitter(p, props_)
end
for _, spot in ipairs({ { 0, 0 }, { -140, 40 }, { 140, 40 }, { 0, 160 }, { 0, -170 } }) do
	airEmitter(spot[1], spot[2], 150, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 110, 110)),
		Size = NumberSequence.new(0.25),
		Transparency = NumberSequence.new(0.3),
		Rate = 30,
		Lifetime = NumberRange.new(14, 18),
		Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(30, 30),
		RotSpeed = NumberRange.new(-60, 60),
	})
end
-- soul wisps over the soul sand valley
airEmitter(-140, 180, 90, {
	Texture = "rbxasset://textures/particles/sparkles_main.dds",
	Color = ColorSequence.new(Color3.fromRGB(140, 230, 255)),
	LightEmission = 1,
	Size = NumberSequence.new(0.4),
	Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.2), NumberSequenceKeypoint.new(1, 1) }),
	Rate = 14,
	Lifetime = NumberRange.new(10, 14),
	Speed = NumberRange.new(1.5, 3),
	EmissionDirection = Enum.NormalId.Bottom,
	SpreadAngle = Vector2.new(50, 50),
})

print(("[build-underworld] built: %d parts (terrain runs %d, bridges %s)"):format(#root:GetDescendants(), count, game:GetService("HttpService"):JSONEncode(bridgeSpans)))
return ("built %d parts, terrain runs %d, spans %s"):format(#root:GetDescendants(), count, game:GetService("HttpService"):JSONEncode(bridgeSpans))
