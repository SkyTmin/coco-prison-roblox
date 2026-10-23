--!nocheck
-- Builds the Снежная длань, level 19, PvP [меню]. «Снежно-ледяной остров суров и безжалостен: холодный ветер бьёт в
-- лицо, а ледяные глыбы делают каждый шаг опасным» [клиент]. Blocks: лёд 50 %, плотный лёд 50 % [меню] (Roblox Ice /
-- Glacier materials, MineService.MATERIALS). Boss: Моль (Moth) — «убийца, выходящая на охоту под покровом ночи» [клиент].
-- [владелец 23.10: «вдохновляйся в интернете, особенно много усилий к мелким деталям»] The island IS a hand: a palm of
-- snow in a frozen sea, four fingers and a thumb. Ideas: Nordic winter villages (stone footings, log walls, steep roofs
-- heavy with snow, icicles under every eave, smoking chimneys, woodpiles, snow drifts against the walls), Minecraft
-- snowy biomes (ice spikes, igloos, spruces with snow on every tier, a frozen ocean with icebergs), moth lore (moths
-- gather at lit lanterns — the arena is a frozen moonlit lake ringed by lantern columns, the charge stuns on them).
-- Zones: the wrist (arrival, the ice quarry, the buyer, a sledge camp), the palm (the Moon lake, dead birches with
-- cocoons, an igloo camp), the index finger (spruce forest, a hunters' lodge you can enter), the middle finger (a ring
-- of rune stones and a stone moth), the ring finger (ice spikes), the little finger (a ship frozen in the ice, a whale
-- skeleton), the thumb (a fishing village with ice holes, a dock, boats frozen in). Polar night with an aurora.
-- X 9400, height Y 12000. Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent:
-- replaces Workspace.SnowyHand and the Terrain water of its region.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("SnowyHand")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "SnowyHand"
root:SetAttribute("LocationId", "snowy_hand")
root.Parent = workspace

local BX, BZ = 9400, 0
local BY = 12000 -- the location's own height [владелец 23.10]
local B = 4
local rng = Random.new(20261919)
local SNOW = Color3.fromRGB(242, 246, 252)
local SNOW_PATH = Color3.fromRGB(206, 214, 228)
local ICE = Color3.fromRGB(175, 215, 245)
local SEA_ICE = Color3.fromRGB(150, 190, 225)
local ROCK = Color3.fromRGB(150, 158, 172)
local LOG = Color3.fromRGB(150, 118, 92)
local DARK_LOG = Color3.fromRGB(96, 74, 58)
local IRON = Color3.fromRGB(62, 62, 68)
local WARM = Color3.fromRGB(255, 196, 120)
local GLASS_WARM = Color3.fromRGB(255, 205, 130)
local RUNE = Color3.fromRGB(140, 210, 255)
local FUR = Color3.fromRGB(196, 186, 170)
local FUR_DARK = Color3.fromRGB(110, 86, 64)
local CLOTH = Color3.fromRGB(150, 50, 44)

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or SNOW
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end
local function wedge(name, size, cf, color, material, parent)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or SNOW
	p.Material = material or Enum.Material.SmoothPlastic
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
local function V(x, y, z)
	return Vector3.new(BX + x, y, BZ + z)
end
local function blob(name, size, cf, color, parent, material)
	local p = part(name, size, cf, color, material or Enum.Material.SmoothPlastic, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
local function beam(name, a, b, thick, color, parent, material)
	local len = (b - a).Magnitude
	return part(name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, material, parent)
end
local LIGHT_POWER, LIGHT_RANGE = 0.45, 0.7
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
		gui.LightInfluence = 0.5
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(245, 235, 215)
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
	return math.sqrt((px - ax - dx * t) ^ 2 + (pz - az - dz * t) ^ 2), t
end
local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return e
end

-- ================================================================ the plan: a hand in a frozen sea
local PIT = { x = 0, z = 200, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json snowy_hand.mine); on the grid
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local SPAWN_Z = PIT.z + PIT.hole + 14
local WRIST = { x = 0, z = 215, hx = 122, hz = 112 }
local PALM = { x = 0, z = -20, hx = 178, hz = 132 }
local LAKE = { x = 0, z = -20, r = 72 }
-- fingers and the thumb: capsules { ax, az, bx, bz, radius, rise (studs at the knuckle) }
local FINGERS = {
	index = { -118, -120, -150, -300, 30, 8 },
	middle = { -40, -140, -48, -360, 30, 8 },
	ring = { 42, -140, 54, -330, 29, 8 },
	pinky = { 122, -110, 162, -258, 26, 4 },
	thumb = { -165, 40, -322, -40, 32, 4 },
}
local SEA_TOP = -3
local function roundSq(dx, dz, hx, hz)
	return ((math.abs(dx) / hx) ^ 4 + (math.abs(dz) / hz) ^ 4) ^ 0.25
end
-- < 1 on land; also the height of the ground there
local function land(x, z)
	local wob = 1 + n2(x, z, 2.7, 0.03) * 0.07
	local best, h, who = math.huge, 0, nil
	local dw = roundSq(x - WRIST.x, z - WRIST.z, WRIST.hx, WRIST.hz) * wob
	if dw < best then
		best, h, who = dw, 0, "wrist"
	end
	local dp = roundSq(x - PALM.x, z - PALM.z, PALM.hx, PALM.hz) * wob
	if dp < best then
		best, h, who = dp, 0, "palm"
	end
	for name, f in pairs(FINGERS) do
		local d, t = segDist(x, z, f[1], f[2], f[3], f[4])
		d = d / f[5] * wob
		if d < best then
			best, who = d, name
			-- knuckles: a 4-stud step up from the palm, a level plateau along the finger, a step down to the tip
			local rise = if t < 0.12 or t > 0.95 then 0 elseif t < 0.25 or t > 0.85 then 4 else f[6]
			h = if d < 0.75 then rise else 0
		end
	end
	return best, h, who
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local function inLake(x, z)
	return math.sqrt((x - LAKE.x) ^ 2 + (z - LAKE.z) ^ 2) < LAKE.r + n2(x, z, 3.3, 0.05) * 4
end
-- the trails (packed snow) between the zones
local TRAILS = {
	{ { 0, SPAWN_Z }, { 90, SPAWN_Z - 4 }, { 92, 120 }, { 40, 66 } },
	{ { 0, SPAWN_Z }, { -90, SPAWN_Z - 4 }, { -92, 120 }, { -40, 66 } },
	{ { -40, -100 }, { -44, -160 }, { -48, -320 } },
	{ { -78, -84 }, { -122, -140 }, { -146, -280 } },
	{ { 40, -100 }, { 46, -160 }, { 54, -300 } },
	{ { 78, -84 }, { 126, -126 }, { 156, -236 } },
	{ { -74, 0 }, { -170, 34 }, { -300, -32 } },
	{ { 76, 6 }, { 130, 40 } },
}
local function polyDist(t, x, z)
	local best = math.huge
	for i = 1, #t - 1 do
		best = math.min(best, (segDist(x, z, t[i][1], t[i][2], t[i + 1][1], t[i + 1][2])))
	end
	return best
end
local function onTrail(x, z)
	for _, t in ipairs(TRAILS) do
		if polyDist(t, x, z) < 5 + n2(x, z, 8.8, 0.15) * 1.5 then
			return true
		end
	end
	return false
end
-- open water in the sea ice (Terrain water): by the fishing village and by the wreck
local POLYNYAS = { { -372, -96, 20, 12 }, { -290, -130, 10, 8 }, { 250, -345, 16, 10 } }
local function inPolynya(x, z)
	for _, p in ipairs(POLYNYAS) do
		if roundSq(x - p[1], z - p[2], p[3], p[4]) < 1 then
			return true
		end
	end
	return false
end

-- ================================================================ the ground and the sea ice (8-stud cells)
local C = 8
local X0, Z0 = -416, -424
local NX, NZ = 104, 104
local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local d, h, who = land(x, z)
		local c = { x = x, z = z, d = d, who = who }
		if d < 1 then
			if inHole(x, z) then
				c.kind = "hole"
			elseif inLake(x, z) then
				c.kind = "lake"
				c.top = 0
			else
				c.kind = "land"
				c.top = h
				c.path = onTrail(x, z)
			end
		elseif inPolynya(x, z) then
			c.kind = "water"
		else
			c.kind = "sea"
			c.top = SEA_TOP
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
local function groundAt(x, z)
	local c = cellAtPos(x, z)
	if not c then
		return SEA_TOP
	end
	return c.top or SEA_TOP
end
local function isLand(x, z)
	local c = cellAtPos(x, z)
	return c ~= nil and c.kind == "land"
end

local terrainFolder = folder("Ground")
local T = workspace.Terrain
for zz = Z0, Z0 + NZ * C, 40 do
	T:FillBlock(CFrame.new(BX, BY - 20, BZ + zz + 20), Vector3.new(NX * C, 60, 40), Enum.Material.Air)
	task.wait()
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
		if r.water then
			T:FillBlock(CFrame.new(BX + (x0 + x1) / 2, BY + (r.y0 + r.y1) / 2, BZ + (z0 + z1) / 2), Vector3.new(x1 - x0, r.y1 - r.y0, z1 - z0), Enum.Material.Water)
		else
			local p = part(r.name, Vector3.new(x1 - x0, r.y1 - r.y0, z1 - z0), at((x0 + x1) / 2, (r.y0 + r.y1) / 2, (z0 + z1) / 2), r.color, r.mat, terrainFolder)
			if r.variant then
				textured(p, r.variant, r.color)
			end
		end
		count += 1
		runs[k] = nil
	end
	local function push(ix, k, name, y0, y1, mat, color, variant, water)
		local r = runs[k]
		if r and r.ix1 == ix - 1 and r.y0 == y0 and r.y1 == y1 and r.mat == mat and r.color == color and r.variant == variant then
			r.ix1 = ix
			return
		end
		flushKey(k)
		runs[k] = { ix0 = ix, ix1 = ix, name = name, y0 = y0, y1 = y1, mat = mat, color = color, variant = variant, water = water }
	end
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		local used = {}
		if c.kind == "land" then
			local v = n2(c.x, c.z, 7.7, 0.06)
			local rocky = c.top >= 4 and c.d > 0.55 and v > 0.15
			push(ix, "body", "Rock", -14, c.top - 1, nil, ROCK, "px_stone")
			if c.path then
				push(ix, "cap", "Trail", c.top - 1, c.top, Enum.Material.Snow, SNOW_PATH)
			elseif rocky then
				push(ix, "cap", "RockTop", c.top - 1, c.top, Enum.Material.Slate, Color3.fromRGB(150, 158, 172))
			else
				push(ix, "cap", "Snow", c.top - 1, c.top, Enum.Material.Snow, SNOW)
			end
			used.body, used.cap = true, true
		elseif c.kind == "lake" then
			push(ix, "body", "Rock", -14, -2, nil, ROCK, "px_stone")
			push(ix, "cap", "LakeIce", -2, 0, Enum.Material.Ice, ICE)
			used.body, used.cap = true, true
		elseif c.kind == "sea" then
			local v = n2(c.x, c.z, 5.5, 0.04)
			push(ix, "cap", "SeaIce", SEA_TOP - 3, SEA_TOP, if v > 0.2 then Enum.Material.Ice else Enum.Material.Glacier, if v > 0.2 then ICE else SEA_ICE)
			used.cap = true
		elseif c.kind == "water" then
			push(ix, "body", "SeaBed", -24, -20, Enum.Material.Slate, Color3.fromRGB(40, 50, 60))
			push(ix, "water", "Water", -20, SEA_TOP - 1, nil, nil, nil, true)
			used.body, used.water = true, true
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
	if iz % 4 == 0 then
		task.wait()
	end
end

-- ================================================================ small builders (the details)
local props = folder("Props")
-- a snow cap on top of any part (slightly wider, a little lumpy)
local function snowCap(p, th, parent)
	th = th or 0.45
	local s = p.Size
	local cap = part("SnowCap", Vector3.new(s.X + 0.25, th, s.Z + 0.25), p.CFrame * CFrame.new(0, s.Y / 2 + th / 2 - 0.02, 0), SNOW, Enum.Material.Snow, parent or p.Parent)
	cap.CanCollide = false
	if s.X > 2 and s.Z > 2 and rng:NextNumber() < 0.6 then
		decor(blob("SnowLump", Vector3.new(s.X * 0.4, th * 1.6, s.Z * 0.4), cap.CFrame * CFrame.new(rng:NextNumber(-s.X / 5, s.X / 5), th * 0.4, rng:NextNumber(-s.Z / 5, s.Z / 5)), SNOW, parent or p.Parent, Enum.Material.Snow))
	end
	return cap
end
-- a row of icicles hanging from y along a to b (world points)
local function icicles(a, b, parent, density)
	local f = parent or props
	local len = (b - a).Magnitude
	local t = rng:NextNumber(0.2, 0.8)
	while t < len do
		local p = a + (b - a).Unit * t
		local l = rng:NextNumber(0.6, 2.8)
		local w = 0.34
		local y = p.Y
		for k = 1, 3 do
			local seg = l / 3 * (1.25 - k * 0.15)
			local ic = decor(part("Icicle", Vector3.new(w, seg, w), CFrame.new(p.X, y - seg / 2, p.Z), Color3.fromRGB(210, 235, 255), Enum.Material.Ice, f))
			ic.Transparency = 0.2
			ic.CastShadow = false
			y -= seg
			w *= 0.62
		end
		t += rng:NextNumber(0.5, 1.6) / (density or 1)
	end
end
-- a snowdrift heaped against something (a flattened lump of snow)
local function drift(cf, w, d, h, parent)
	return decor(blob("Drift", Vector3.new(w, h, d), cf, SNOW, parent or props, Enum.Material.Snow))
end
-- a spruce with snow on every tier [ваниль: snowy taiga]
local function spruce(x, z, h, parent)
	local f = parent or props
	local y = groundAt(x, z)
	textured(part("SpruceTrunk", Vector3.new(1.2, h * 0.4, 1.2), at(x, y + h * 0.2, z), nil, nil, f), "px_oak_log", DARK_LOG)
	local tiers = math.clamp(math.floor(h / 4), 3, 6)
	for k = 0, tiers - 1 do
		local t = k / tiers
		local r = h * 0.3 * (1 - t * 0.8)
		local ty = y + h * 0.22 + t * h * 0.72
		local th = h * 0.72 / tiers * 0.9
		local leaf = textured(part("SpruceLeaves", Vector3.new(r * 2, th, r * 2), at(x, ty + th / 2, z) * CFrame.Angles(0, k * 0.785 + rng:NextNumber(-0.2, 0.2), 0), nil, nil, f), "px_hedge", Color3.fromRGB(110, 140, 128))
		leaf.CanCollide = k == 0
		local cap = decor(part("SpruceSnow", Vector3.new(r * 1.7, 0.5, r * 1.7), leaf.CFrame * CFrame.new(0, th / 2 + 0.2, 0), SNOW, Enum.Material.Snow, f))
		_ = cap
		if k < tiers - 1 and rng:NextNumber() < 0.5 then
			decor(part("SpruceSnowLedge", Vector3.new(r * 2.05, 0.35, 0.8), leaf.CFrame * CFrame.new(0, -th / 2 + 0.6, r * 0.95), SNOW, Enum.Material.Snow, f))
		end
	end
	decor(part("SpruceTip", Vector3.new(0.8, 1.6, 0.8), at(x, y + h * 0.95 + 0.8, z), SNOW, Enum.Material.Snow, f))
	drift(at(x + 0.6, y + 0.1, z + 0.4), h * 0.25, h * 0.25, 0.9, f)
end
-- a dead white birch with snow on its branches; moth cocoons hang from some
local function deadBirch(x, z, h, cocoons, parent)
	local f = parent or props
	local y = groundAt(x, z)
	local trunk = textured(part("BirchTrunk", Vector3.new(1.3, h, 1.3), at(x, y + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06)), nil, nil, f), "px_birch_log", Color3.fromRGB(220, 222, 228))
	snowCap(trunk, 0.3, f)
	for k = 1, rng:NextInteger(3, 5) do
		local a = rng:NextNumber(0, 6.28)
		local sy = y + h * rng:NextNumber(0.45, 0.9)
		local a0 = V(x, sy, z)
		local len = rng:NextNumber(3, 6)
		local tip = a0 + Vector3.new(math.cos(a) * len, len * rng:NextNumber(0.4, 0.9), math.sin(a) * len)
		textured(beam("BirchBranch", a0, tip, 0.5, nil, f), "px_birch_log", Color3.fromRGB(215, 216, 222))
		decor(beam("BranchSnow", a0 + Vector3.new(0, 0.32, 0), tip + Vector3.new(0, 0.32, 0), 0.3, SNOW, f, Enum.Material.Snow))
		if cocoons and k <= 2 then
			local hang = tip:Lerp(a0, 0.3)
			local l = rng:NextNumber(1, 3)
			decor(beam("CocoonThread", hang, hang - Vector3.new(0, l, 0), 0.08, Color3.fromRGB(230, 230, 220), f))
			blob("MothCocoon", Vector3.new(1.1, 2.4, 1.1), CFrame.new(hang - Vector3.new(0, l + 1.1, 0)), Color3.fromRGB(196, 190, 170), f, Enum.Material.Fabric)
		end
	end
end
-- a lamp post with a hanging lantern and a snow cap
local litLamps = 0
local function lampPost(x, z, parent, forceLit)
	local f = parent or props
	local y = groundAt(x, z)
	local post = part("LampPost", Vector3.new(0.6, 9, 0.6), at(x, y + 4.5, z), IRON, Enum.Material.Metal, f)
	part("LampFoot", Vector3.new(1.4, 0.6, 1.4), at(x, y + 0.3, z), IRON, Enum.Material.Metal, f)
	local arm = part("LampArm", Vector3.new(0.3, 0.3, 2.2), at(x, y + 8.6, z - 0.9), IRON, Enum.Material.Metal, f)
	snowCap(arm, 0.2, f)
	decor(part("LampChain", Vector3.new(0.12, 0.8, 0.12), at(x, y + 8.1, z - 1.8), IRON, Enum.Material.Metal, f))
	local glass = part("LampGlass", Vector3.new(0.9, 1.1, 0.9), at(x, y + 7.1, z - 1.8), GLASS_WARM, Enum.Material.Neon, f)
	glass.Transparency = 0.1
	local cap = part("LampCap", Vector3.new(1.2, 0.3, 1.2), at(x, y + 7.8, z - 1.8), IRON, Enum.Material.Metal, f)
	snowCap(cap, 0.25, f)
	snowCap(post, 0.3, f)
	icicles(V(x - 0.5, y + 7.65, z - 2.3), V(x + 0.5, y + 7.65, z - 2.3), f, 1.6)
	litLamps += 1
	if forceLit or litLamps % 2 == 0 then
		light(glass, 26, 1.2, WARM)
	end
	-- a moth or two at the lantern (moths go to the light)
	if rng:NextNumber() < 0.5 then
		local m = V(x + rng:NextNumber(-0.6, 0.6), y + 7.3, z - 1.3)
		decor(part("MothWing", Vector3.new(0.5, 0.05, 0.3), CFrame.new(m) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(200, 186, 150), nil, f))
		decor(part("MothWing", Vector3.new(0.5, 0.05, 0.3), CFrame.new(m + Vector3.new(0.4, 0, 0)) * CFrame.Angles(0, 0, -0.5), Color3.fromRGB(200, 186, 150), nil, f))
	end
	return glass
end
local function crate(cf, s, parent)
	local c = textured(part("Crate", Vector3.new(s, s, s), cf, nil, nil, parent or props), "px_spruce_planks")
	snowCap(c, 0.3, parent)
	return c
end
local function barrelAt(cf, parent, iceTop)
	local f = parent or props
	local b = part("Barrel", Vector3.new(2.4, 3, 2.4), cf * CFrame.new(0, 1.5, 0), Color3.fromRGB(110, 78, 52), Enum.Material.Wood, f)
	for _, hy in ipairs({ 0.5, 2.5 }) do
		decor(part("BarrelHoop", Vector3.new(2.5, 0.22, 2.5), cf * CFrame.new(0, hy, 0), IRON, Enum.Material.Metal, f))
	end
	if iceTop then
		local ic = part("FrozenWater", Vector3.new(2.1, 0.2, 2.1), cf * CFrame.new(0, 3, 0), ICE, Enum.Material.Ice, f)
		ic.Transparency = 0.15
	else
		snowCap(b, 0.35, f)
	end
	return b
end
local function barrel(x, z, parent, iceTop)
	return barrelAt(at(x, groundAt(x, z), z), parent, iceTop)
end
-- a woodpile against a wall: logs stacked in a pyramid under a snow cap
local function woodpile(cf, len, rows, parent)
	local f = parent or props
	for r = 0, rows - 1 do
		local n = rows - r + 1
		for k = 0, n - 1 do
			local lg = part("Firewood", Vector3.new(0.9, 0.9, len), cf * CFrame.new((k - (n - 1) / 2) * 0.95, 0.45 + r * 0.85, 0) * CFrame.Angles(0, rng:NextNumber(-0.03, 0.03), 0), Color3.fromRGB(140, 104, 74), Enum.Material.Wood, f)
			_ = lg
			decor(part("LogEnd", Vector3.new(0.75, 0.75, 0.05), cf * CFrame.new((k - (n - 1) / 2) * 0.95, 0.45 + r * 0.85, -len / 2 - 0.02), Color3.fromRGB(205, 170, 120), Enum.Material.Wood, f))
		end
	end
	decor(part("WoodSnow", Vector3.new(1.6, 0.35, len + 0.2), cf * CFrame.new(0, rows * 0.85 + 0.3, 0), SNOW, Enum.Material.Snow, f))
end
local function snowman(x, z, yaw, parent)
	local f = parent or props
	local y = groundAt(x, z)
	local base = at(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	blob("SnowmanBase", Vector3.new(3.4, 3.2, 3.4), base * CFrame.new(0, 1.5, 0), SNOW, f, Enum.Material.Snow)
	blob("SnowmanBody", Vector3.new(2.5, 2.4, 2.5), base * CFrame.new(0, 3.7, 0), SNOW, f, Enum.Material.Snow)
	blob("SnowmanHead", Vector3.new(1.8, 1.8, 1.8), base * CFrame.new(0, 5.4, 0), SNOW, f, Enum.Material.Snow)
	for _, s in ipairs({ -0.35, 0.35 }) do
		decor(part("CoalEye", Vector3.new(0.22, 0.22, 0.1), base * CFrame.new(s, 5.6, -0.86), Color3.fromRGB(20, 20, 22), nil, f))
	end
	decor(part("CarrotNose", Vector3.new(0.22, 0.22, 0.9), base * CFrame.new(0, 5.35, -1.2), Color3.fromRGB(240, 130, 30), nil, f))
	for k = 0, 2 do
		decor(part("CoalButton", Vector3.new(0.2, 0.2, 0.1), base * CFrame.new(0, 3.2 + k * 0.5, -1.2 + k * 0.03), Color3.fromRGB(20, 20, 22), nil, f))
	end
	for _, s in ipairs({ -1, 1 }) do
		decor(beam("StickArm", (base * CFrame.new(s * 1.1, 3.9, 0)).Position, (base * CFrame.new(s * 2.6, 5, 0)).Position, 0.18, Color3.fromRGB(90, 64, 40), f))
	end
	decor(part("Bucket", Vector3.new(1.3, 1.1, 1.3), base * CFrame.new(0, 6.6, 0) * CFrame.Angles(0, 0, 0.15), Color3.fromRGB(110, 112, 118), Enum.Material.Metal, f))
	decor(part("Scarf", Vector3.new(1.9, 0.4, 1.9), base * CFrame.new(0, 4.7, 0), CLOTH, Enum.Material.Fabric, f))
	decor(part("ScarfTail", Vector3.new(0.4, 1.2, 0.15), base * CFrame.new(0.5, 4.2, -0.95) * CFrame.Angles(0, 0, 0.2), CLOTH, Enum.Material.Fabric, f))
end
-- a sledge with lashed crates and a rope
local function sledge(cf, parent, loaded)
	local f = parent or props
	for _, s in ipairs({ -1.1, 1.1 }) do
		part("SledRunner", Vector3.new(0.3, 0.3, 6), cf * CFrame.new(s, 0.15, 0), IRON, Enum.Material.Metal, f)
		decor(part("RunnerCurl", Vector3.new(0.3, 1, 0.3), cf * CFrame.new(s, 0.5, -3.1) * CFrame.Angles(0.5, 0, 0), IRON, Enum.Material.Metal, f))
		for _, z in ipairs({ -2, 0, 2 }) do
			decor(part("SledStrut", Vector3.new(0.25, 0.7, 0.25), cf * CFrame.new(s, 0.6, z), Color3.fromRGB(120, 88, 60), Enum.Material.Wood, f))
		end
	end
	textured(part("SledBed", Vector3.new(2.8, 0.25, 5.6), cf * CFrame.new(0, 1, 0), nil, nil, f), "px_spruce_planks")
	if loaded then
		crate(cf * CFrame.new(0, 2.1, 1.2), 1.9, f)
		crate(cf * CFrame.new(0.1, 2.1, -1) * CFrame.Angles(0, 0.2, 0), 1.7, f)
		decor(part("Rope", Vector3.new(2.9, 0.15, 0.15), cf * CFrame.new(0, 2.9, 0.2), Color3.fromRGB(170, 140, 90), Enum.Material.Fabric, f))
		decor(part("Fur", Vector3.new(2.6, 0.2, 2), cf * CFrame.new(0, 3.1, 1.2), FUR, Enum.Material.Fabric, f))
	end
	decor(beam("TowRope", (cf * CFrame.new(0, 0.6, -3.2)).Position, (cf * CFrame.new(0.6, 0.1, -6)).Position, 0.15, Color3.fromRGB(170, 140, 90), f, Enum.Material.Fabric))
end
-- footprints along a trail (alternating left / right, a little pressed into the snow)
local function footprints(t, parent, step)
	local f = parent or props
	for i = 1, #t - 1 do
		local a, b = Vector3.new(t[i][1], 0, t[i][2]), Vector3.new(t[i + 1][1], 0, t[i + 1][2])
		local d = b - a
		local len = d.Magnitude
		local u = d.Unit
		local side = Vector3.new(-u.Z, 0, u.X)
		local k = 0
		for s = 2, len - 2, step or 1.7 do
			k += 1
			local p = a + u * s + side * (if k % 2 == 0 then 0.45 else -0.45) + side * math.sin(s / 9) * 1.2
			local y = groundAt(p.X, p.Z)
			decor(part("Footprint", Vector3.new(0.55, 0.06, 0.95), CFrame.lookAt(V(p.X, y + 0.02, p.Z), V(p.X + u.X, y + 0.02, p.Z + u.Z)), Color3.fromRGB(196, 206, 222), Enum.Material.Snow, f))
		end
	end
end
-- a Nordic cabin: stone footing, plank walls with log corners, a steep snowy gable roof with icicles, a smoking
-- chimney, glowing shuttered windows, a lantern by the door, a woodpile, drifts; optional furnished interior
local function cabin(cf, w, d, h, opt, parent)
	opt = opt or {}
	local f = parent or folder("Cabin", props)
	local wallV = opt.wall or "px_spruce_planks"
	part("Footing", Vector3.new(w + 1, 1.2, d + 1), cf * CFrame.new(0, 0.6, 0), ROCK, Enum.Material.Cobblestone, f)
	textured(part("Floor", Vector3.new(w - 1, 0.2, d - 1), cf * CFrame.new(0, 1.3, 0), nil, nil, f), "px_dark_oak_planks")
	local y0 = 1.2
	-- walls (front has the door gap)
	textured(part("Wall", Vector3.new(w, h, 1), cf * CFrame.new(0, y0 + h / 2, d / 2 - 0.5), nil, nil, f), wallV)
	for _, s in ipairs({ -1, 1 }) do
		local side = textured(part("Wall", Vector3.new(1, h, d), cf * CFrame.new(s * (w / 2 - 0.5), y0 + h / 2, 0), nil, nil, f), wallV)
		_ = side
		-- the window in the side wall: glowing pane, frame, shutters, a sill with snow
		local wcf = cf * CFrame.new(s * (w / 2 - 0.4), y0 + h * 0.55, 0) * CFrame.Angles(0, -s * math.pi / 2, 0)
		local pane = part("Window", Vector3.new(2.4, 2.2, 0.3), wcf * CFrame.new(0, 0, -0.2), GLASS_WARM, Enum.Material.Neon, f)
		pane.Transparency = 0.25
		decor(part("WindowCross", Vector3.new(0.18, 2.2, 0.36), wcf * CFrame.new(0, 0, -0.25), DARK_LOG, nil, f))
		decor(part("WindowCross", Vector3.new(2.4, 0.18, 0.36), wcf * CFrame.new(0, 0, -0.25), DARK_LOG, nil, f))
		for _, sh in ipairs({ -1, 1 }) do
			decor(textured(part("Shutter", Vector3.new(1.2, 2.4, 0.15), wcf * CFrame.new(sh * 1.95, 0, -0.55) * CFrame.Angles(0, sh * 0.35, 0), nil, nil, f), "px_dark_oak_planks"))
		end
		local sill = part("Sill", Vector3.new(2.9, 0.25, 0.7), wcf * CFrame.new(0, -1.25, -0.55), DARK_LOG, Enum.Material.Wood, f)
		snowCap(sill, 0.2, f)
		-- drifts along the wall
		drift(cf * CFrame.new(s * (w / 2 + 0.3), y0 + 0.2, rng:NextNumber(-d / 4, d / 4)), 2.4, d * 0.7, 1.6, f)
	end
	local doorW = 3.6
	for _, s in ipairs({ -1, 1 }) do
		local seg = (w - doorW) / 2
		textured(part("Wall", Vector3.new(seg, h, 1), cf * CFrame.new(s * (doorW / 2 + seg / 2), y0 + h / 2, -d / 2 + 0.5), nil, nil, f), wallV)
	end
	textured(part("Wall", Vector3.new(doorW, h - 6.4, 1), cf * CFrame.new(0, y0 + 6.4 + (h - 6.4) / 2, -d / 2 + 0.5), nil, nil, f), wallV)
	-- the door, half open, and its frame
	textured(part("DoorFrame", Vector3.new(0.5, 6.6, 1.3), cf * CFrame.new(-doorW / 2 - 0.25, y0 + 3.3, -d / 2 + 0.5), nil, nil, f), "px_oak_log", DARK_LOG)
	textured(part("DoorFrame", Vector3.new(0.5, 6.6, 1.3), cf * CFrame.new(doorW / 2 + 0.25, y0 + 3.3, -d / 2 + 0.5), nil, nil, f), "px_oak_log", DARK_LOG)
	textured(part("Door", Vector3.new(doorW - 0.3, 6.2, 0.3), cf * CFrame.new(-doorW / 2, y0 + 3.1, -d / 2) * CFrame.Angles(0, math.rad(-75), 0) * CFrame.new(doorW / 2 - 0.15, 0, 0), nil, nil, f), "px_dark_oak_planks")
	-- log corners standing out of the walls
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			textured(part("CornerLog", Vector3.new(1.4, h + 0.4, 1.4), cf * CFrame.new(sx * w / 2, y0 + h / 2, sz * d / 2), nil, nil, f), "px_oak_log", LOG)
		end
	end
	-- the roof: steep gable along the depth, overhanging, snow on both slopes, icicles along the eaves
	local slope = math.rad(opt.pitch or 38)
	local half = w / 2 + 1.4
	local slab = half / math.cos(slope)
	local ry = y0 + h
	for _, s in ipairs({ -1, 1 }) do
		local rcf = cf * CFrame.new(s * half / 2, ry + math.tan(slope) * half / 2, 0) * CFrame.Angles(0, 0, -s * slope)
		textured(part("Roof", Vector3.new(slab, 0.8, d + 3), rcf, nil, nil, f), opt.roof or "px_dark_oak_planks", opt.roofTint)
		local cover = part("RoofSnow", Vector3.new(slab - 0.6, 0.7, d + 3.2), rcf * CFrame.new(s * 0.2, 0.7, 0), SNOW, Enum.Material.Snow, f)
		cover.CanCollide = false
		local eave = (cf * CFrame.new(s * (half + 0.1), ry - 0.15, 0)).Position
		local along = cf:VectorToWorldSpace(Vector3.new(0, 0, 1))
		icicles(eave - along * (d / 2 + 1.3), eave + along * (d / 2 + 1.3), f)
	end
	textured(part("RidgeBeam", Vector3.new(1, 1, d + 3.4), cf * CFrame.new(0, ry + math.tan(slope) * half + 0.35, 0), nil, nil, f), "px_oak_log", DARK_LOG)
	-- gable ends: two wedges each
	local gh = math.tan(slope) * (w / 2)
	for _, sz in ipairs({ -1, 1 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local wcf = cf * CFrame.new(sx * w / 4, ry + gh / 2, sz * (d / 2 - 0.5)) * CFrame.Angles(0, if sx > 0 then -math.pi / 2 else math.pi / 2, 0)
			textured(wedge("Gable", Vector3.new(1, gh, w / 2), wcf, nil, nil, f), wallV)
		end
	end
	-- the chimney with smoke
	local chx = if opt.chimneyLeft then -w / 4 else w / 4
	local ch = part("Chimney", Vector3.new(2.2, h * 0.6 + gh + 2, 2.2), cf * CFrame.new(chx, ry + (gh + 2) / 2 + h * 0.1, d / 2 - 2), ROCK, Enum.Material.Cobblestone, f)
	snowCap(ch, 0.3, f)
	local smoke = decor(part("ChimneySmoke", Vector3.new(1, 1, 1), ch.CFrame * CFrame.new(0, ch.Size.Y / 2 + 0.6, 0), nil, nil, f))
	smoke.Transparency = 1
	emitter(smoke, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(150, 150, 158)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(1.2, 4),
		Rate = 4,
		Lifetime = NumberRange.new(4, 6),
		Speed = NumberRange.new(2, 3),
		Acceleration = Vector3.new(1.5, 0.6, 0.4),
		SpreadAngle = Vector2.new(10, 10),
	})
	-- a lantern by the door, a woodpile along a side, a doormat of fur, a shovel in a drift
	local lan = part("DoorLantern", Vector3.new(0.8, 1, 0.8), cf * CFrame.new(doorW / 2 + 1.2, y0 + 5.2, -d / 2 - 0.4), GLASS_WARM, Enum.Material.Neon, f)
	lan.Transparency = 0.1
	part("LanternCap", Vector3.new(1.1, 0.25, 1.1), lan.CFrame * CFrame.new(0, 0.62, 0), IRON, Enum.Material.Metal, f)
	if opt.lit ~= false then
		light(lan, 22, 1, WARM)
	end
	woodpile(cf * CFrame.new(w / 2 + 1.4, y0 - 1.2, 0) * CFrame.Angles(0, 0, 0), d * 0.7, 3, f)
	decor(part("Doormat", Vector3.new(3, 0.1, 1.6), cf * CFrame.new(0, y0 + 0.05, -d / 2 - 1.2), FUR_DARK, Enum.Material.Fabric, f))
	if rng:NextNumber() < 0.6 then
		local sh = cf * CFrame.new(-doorW / 2 - 2.2, y0 + 1.2, -d / 2 - 1.4) * CFrame.Angles(0.2, 0, 0.25)
		decor(part("ShovelHandle", Vector3.new(0.2, 3.6, 0.2), sh, Color3.fromRGB(120, 90, 60), Enum.Material.Wood, f))
		decor(part("ShovelBlade", Vector3.new(1.1, 1.2, 0.12), sh * CFrame.new(0, -2, 0), Color3.fromRGB(120, 124, 130), Enum.Material.Metal, f))
		drift(cf * CFrame.new(-doorW / 2 - 2.2, y0, -d / 2 - 1.4), 2.6, 2.2, 1.4, f)
	end
	-- the interior
	if opt.interior then
		local fire = part("Hearth", Vector3.new(4, 4, 1.6), cf * CFrame.new(chx, y0 + 2, d / 2 - 1.8), ROCK, Enum.Material.Cobblestone, f)
		local flame = decor(part("HearthFire", Vector3.new(1.8, 1.2, 0.6), fire.CFrame * CFrame.new(0, -0.9, -0.6), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, f))
		light(flame, 24, 1.6, Color3.fromRGB(255, 160, 80))
		local bed = textured(part("BedFrame", Vector3.new(3, 1.2, 6), cf * CFrame.new(-w / 2 + 2.6, y0 + 0.6, 1), nil, nil, f), "px_dark_oak_planks")
		decor(part("BedFur", Vector3.new(2.8, 0.4, 4.4), bed.CFrame * CFrame.new(0, 0.8, 0.6), FUR, Enum.Material.Fabric, f))
		decor(part("Pillow", Vector3.new(2.2, 0.5, 1), bed.CFrame * CFrame.new(0, 0.85, -2.3), Color3.fromRGB(230, 225, 210), Enum.Material.Fabric, f))
		local table_ = textured(part("Table", Vector3.new(3.4, 0.3, 2.4), cf * CFrame.new(w / 2 - 3, y0 + 2.6, -0.5), nil, nil, f), "px_spruce_planks")
		for _, sx in ipairs({ -1.4, 1.4 }) do
			for _, sz in ipairs({ -0.9, 0.9 }) do
				part("TableLeg", Vector3.new(0.3, 2.5, 0.3), table_.CFrame * CFrame.new(sx, -1.4, sz), DARK_LOG, Enum.Material.Wood, f)
			end
		end
		decor(part("Mug", Vector3.new(0.4, 0.5, 0.4), table_.CFrame * CFrame.new(0.6, 0.4, 0.2), Color3.fromRGB(120, 90, 60), Enum.Material.Wood, f))
		decor(part("Bowl", Vector3.new(0.8, 0.3, 0.8), table_.CFrame * CFrame.new(-0.6, 0.3, -0.2), Color3.fromRGB(140, 110, 80), Enum.Material.Wood, f))
		local candle = decor(part("Candle", Vector3.new(0.2, 0.5, 0.2), table_.CFrame * CFrame.new(0, 0.4, 0.7), Color3.fromRGB(240, 230, 200), nil, f))
		decor(part("CandleFlame", Vector3.new(0.12, 0.2, 0.12), candle.CFrame * CFrame.new(0, 0.35, 0), Color3.fromRGB(255, 190, 80), Enum.Material.Neon, f))
		for _, sz in ipairs({ -1.9, 1.9 }) do
			textured(part("Stool", Vector3.new(1.2, 1.6, 1.2), table_.CFrame * CFrame.new(0, -1.75, sz), nil, nil, f), "px_spruce_planks")
		end
		decor(part("Rug", Vector3.new(4, 0.08, 3), cf * CFrame.new(0, y0 + 0.25, 0.5), FUR, Enum.Material.Fabric, f))
		-- antlers over the door inside, a shelf with jars, a barrel
		local antler = cf * CFrame.new(0, y0 + h - 1.2, -d / 2 + 1.1)
		decor(part("TrophyPlaque", Vector3.new(1.2, 1.4, 0.2), antler, DARK_LOG, Enum.Material.Wood, f))
		for _, s in ipairs({ -1, 1 }) do
			decor(beam("Antler", (antler * CFrame.new(s * 0.3, 0.3, 0.3)).Position, (antler * CFrame.new(s * 1.6, 1.5, 0.4)).Position, 0.18, Color3.fromRGB(225, 210, 180), f))
			decor(beam("AntlerTine", (antler * CFrame.new(s * 1, 0.9, 0.35)).Position, (antler * CFrame.new(s * 1.1, 1.9, 0.3)).Position, 0.14, Color3.fromRGB(225, 210, 180), f))
		end
		local shelf = part("Shelf", Vector3.new(0.6, 0.2, 3.4), cf * CFrame.new(w / 2 - 1.3, y0 + 4.4, 2.4), DARK_LOG, Enum.Material.Wood, f)
		for k = -1, 1 do
			decor(part("Jar", Vector3.new(0.5, 0.7, 0.5), shelf.CFrame * CFrame.new(0, 0.45, k * 1.1), if k == 0 then Color3.fromRGB(200, 140, 60) else Color3.fromRGB(150, 180, 120), Enum.Material.Glass, f)).Transparency = 0.2
		end
		barrelAt(cf * CFrame.new(-w / 2 + 2, y0 + 0.1, -d / 2 + 2.4), f, true)
	end
	return f
end
-- an igloo of snow blocks with a short tunnel; a fur rug and a lantern inside
local function igloo(x, z, r, yaw, parent)
	local f = parent or folder("Igloo", props)
	local y = groundAt(x, z)
	local base = at(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	local layers = 6
	for k = 0, layers - 1 do
		local a0 = k / layers * math.pi / 2
		local rr = r * math.cos(a0)
		local ly = r * math.sin(a0) * 1.05
		local n = math.max(6, math.floor(2 * math.pi * rr / 2.6))
		for i = 0, n - 1 do
			local a = (i + (k % 2) * 0.5) / n * math.pi * 2
			-- the door gap faces -Z
			if not (k < 2 and math.abs(((a + math.pi) % (math.pi * 2)) - math.pi) < 0.38) then
				local blk = part("SnowBrick", Vector3.new(2 * math.pi * rr / n + 0.2, r / layers * 1.15, 1.6), base * CFrame.new(math.sin(a) * rr, ly + r / layers / 2, -math.cos(a) * rr) * CFrame.Angles(0, -a, 0) * CFrame.Angles(-a0 * 0.8, 0, 0), SNOW:Lerp(ICE, rng:NextNumber(0, 0.25)), Enum.Material.Snow, f)
				_ = blk
			end
		end
	end
	part("IglooCap", Vector3.new(r * 0.5, 0.8, r * 0.5), base * CFrame.new(0, r * 1.05 + 0.4, 0), SNOW, Enum.Material.Snow, f)
	for _, s in ipairs({ -1, 1 }) do
		part("TunnelWall", Vector3.new(1.2, 3.4, 3.6), base * CFrame.new(s * 2, 1.7, -r - 1.4), SNOW, Enum.Material.Snow, f)
	end
	part("TunnelRoof", Vector3.new(5.2, 1, 3.8), base * CFrame.new(0, 3.9, -r - 1.4), SNOW, Enum.Material.Snow, f)
	decor(part("IglooRug", Vector3.new(r * 1.1, 0.08, r * 1.1), base * CFrame.new(0, 0.1, 0), FUR, Enum.Material.Fabric, f))
	local l = decor(part("IglooLamp", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(r * 0.4, 0.5, r * 0.3), GLASS_WARM, Enum.Material.Neon, f))
	light(l, r * 3, 0.9, WARM)
	return f
end
-- an ice fishing hole: dark water, chips of ice round it, a stool, a rod with its line, a bucket and a caught fish
local function fishingHole(x, z, parent)
	local f = parent or props
	local y = groundAt(x, z)
	local hole = part("FishingHole", Vector3.new(2.6, 0.1, 2.6), at(x, y + 0.02, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color3.fromRGB(20, 50, 70), Enum.Material.Glass, f)
	hole.CanCollide = false
	hole.Reflectance = 0.2
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		decor(part("IceChip", Vector3.new(rng:NextNumber(0.5, 0.9), rng:NextNumber(0.2, 0.5), rng:NextNumber(0.5, 0.9)), at(x + math.sin(a) * 1.8, y + 0.15, z + math.cos(a) * 1.8) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), a, 0), ICE, Enum.Material.Ice, f))
	end
	local stool = textured(part("Stool", Vector3.new(1.1, 1.2, 1.1), at(x + 2.6, y + 0.6, z + 0.6), nil, nil, f), "px_spruce_planks")
	snowCap(stool, 0.15, f)
	local grip = V(x + 2, y + 1.3, z + 0.4)
	local tip = V(x + 0.3, y + 2.6, z)
	decor(beam("FishingRod", grip, tip, 0.12, Color3.fromRGB(120, 90, 60), f, Enum.Material.Wood))
	decor(beam("FishingLine", tip, V(x + 0.3, y + 0.05, z), 0.04, Color3.fromRGB(230, 230, 230), f))
	local bucket = part("Bucket", Vector3.new(1, 1, 1), at(x - 2.2, y + 0.5, z + 1.2), Color3.fromRGB(120, 124, 130), Enum.Material.Metal, f)
	decor(part("BucketWater", Vector3.new(0.85, 0.1, 0.85), bucket.CFrame * CFrame.new(0, 0.42, 0), Color3.fromRGB(40, 80, 110), Enum.Material.Glass, f))
	local fish = decor(part("Fish", Vector3.new(0.5, 0.35, 1.4), at(x - 1.6, y + 0.18, z - 1.6) * CFrame.Angles(0, rng:NextNumber(0, 6), math.pi / 2), Color3.fromRGB(150, 160, 170), Enum.Material.SmoothPlastic, f))
	decor(wedge("FishTail", Vector3.new(0.1, 0.6, 0.5), fish.CFrame * CFrame.new(0, 0, 0.9), Color3.fromRGB(130, 140, 150), nil, f))
end
-- an ice spike [ваниль: ice spikes biome]: packed ice stacked and tapering, sometimes leaning
local function iceSpike(x, z, h, parent)
	local f = parent or props
	local y = groundAt(x, z)
	local w = math.clamp(h / 7, 2, 6)
	local lean = CFrame.Angles(rng:NextNumber(-0.12, 0.12), 0, rng:NextNumber(-0.12, 0.12))
	local base = at(x, y, z) * lean
	local yy = 0
	while w >= 1 do
		local seg = math.min(h - yy, rng:NextNumber(3, 6))
		if seg <= 0 then
			break
		end
		local p = part("IceSpike", Vector3.new(w, seg, w), base * CFrame.new(0, yy + seg / 2, 0), Color3.fromRGB(150, 195, 240), Enum.Material.Glacier, f)
		p.Reflectance = 0.05
		yy += seg
		w *= 0.8
		if yy >= h then
			break
		end
	end
	decor(part("SpikeTip", Vector3.new(0.6, 2, 0.6), base * CFrame.new(0, yy + 1, 0), Color3.fromRGB(200, 230, 255), Enum.Material.Ice, f))
	-- a faint blue glow of crystals at the foot of the bigger ones
	if h > 22 and rng:NextNumber() < 0.5 then
		local cr = decor(part("FrostCrystal", Vector3.new(0.8, 1.6, 0.8), at(x + w + 1.2, y + 0.8, z) * CFrame.Angles(0.3, 0, 0.2), RUNE, Enum.Material.Neon, f))
		cr.Transparency = 0.2
	end
end
-- a raven on a post or a rock
local function raven(cf, parent)
	local f = parent or props
	local body = decor(part("Raven", Vector3.new(0.5, 0.5, 0.9), cf * CFrame.new(0, 0.3, 0), Color3.fromRGB(22, 22, 28), nil, f))
	decor(part("RavenHead", Vector3.new(0.35, 0.35, 0.35), body.CFrame * CFrame.new(0, 0.3, -0.5), Color3.fromRGB(22, 22, 28), nil, f))
	decor(part("RavenBeak", Vector3.new(0.12, 0.12, 0.3), body.CFrame * CFrame.new(0, 0.28, -0.8), Color3.fromRGB(40, 40, 44), nil, f))
	decor(part("RavenTail", Vector3.new(0.3, 0.08, 0.5), body.CFrame * CFrame.new(0, 0.05, 0.6) * CFrame.Angles(-0.3, 0, 0), Color3.fromRGB(22, 22, 28), nil, f))
end
local function fence(a, b, parent)
	local f = parent or props
	local d = b - a
	local len = d.Magnitude
	local n = math.max(1, math.floor(len / 5))
	for k = 0, n do
		local p = a + d * (k / n)
		local y = groundAt(p.X - BX, p.Z - BZ)
		local post = part("FencePost", Vector3.new(0.6, 3, 0.6), CFrame.new(p.X, y + 1.5, p.Z), DARK_LOG, Enum.Material.Wood, f)
		snowCap(post, 0.35, f)
		if k < n then
			local q = a + d * ((k + 1) / n)
			local y2 = groundAt(q.X - BX, q.Z - BZ)
			for _, hh in ipairs({ 1.2, 2.4 }) do
				local rail = beam("FenceRail", Vector3.new(p.X, y + hh, p.Z), Vector3.new(q.X, y2 + hh, q.Z), 0.3, LOG, f, Enum.Material.Wood)
				if hh > 2 then
					decor(beam("RailSnow", Vector3.new(p.X, y + hh + 0.25, p.Z), Vector3.new(q.X, y2 + hh + 0.25, q.Z), 0.25, SNOW, f, Enum.Material.Snow))
				end
				_ = rail
			end
		end
	end
end
local function zoneSign(x, z, text, yaw)
	local y = groundAt(x, z)
	textured(part("SignPost", Vector3.new(0.8, 5, 0.8), at(x, y + 2.5, z), nil, nil, props), "px_oak_log", DARK_LOG)
	local board = textured(part("ZoneSign", Vector3.new(8, 1.8, 0.4), at(x, y + 4.6, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, props), "px_spruce_planks")
	boardText(board, text)
	snowCap(board, 0.3, props)
	icicles((board.CFrame * CFrame.new(-3.8, -0.9, 0)).Position, (board.CFrame * CFrame.new(3.8, -0.9, 0)).Position, props, 0.7)
end
-- a small moth resting with spread wings (pale, a dark eye spot on each wing)
local function moth(cf, s, parent)
	local f = parent or props
	decor(part("MothBody", Vector3.new(0.3, 0.3, 1.2) * s, cf, Color3.fromRGB(150, 130, 100), Enum.Material.Fabric, f))
	for _, side in ipairs({ -1, 1 }) do
		local wing = decor(part("MothWing", Vector3.new(1.6, 0.05, 1.2) * s, cf * CFrame.new(side * 0.9 * s, 0, -0.1 * s) * CFrame.Angles(0, side * 0.2, side * 0.15), Color3.fromRGB(215, 205, 180), Enum.Material.Fabric, f))
		decor(part("WingSpot", Vector3.new(0.4, 0.06, 0.4) * s, wing.CFrame * CFrame.new(side * 0.2 * s, 0, 0), Color3.fromRGB(70, 60, 60), nil, f))
		decor(beam("Antenna", (cf * CFrame.new(side * 0.1 * s, 0.05, -0.6 * s)).Position, (cf * CFrame.new(side * 0.5 * s, 0.25, -1.2 * s)).Position, 0.05 * s, Color3.fromRGB(120, 100, 80), f))
	end
end

-- ================================================================ the coast: snow cornices and icicles over the sea ice
local coast = folder("Coast")
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		if c.kind == "land" then
			for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local n = cellAt(ix + dir[1], iz + dir[2])
				if n and (n.kind == "sea" or n.kind == "water") and rng:NextNumber() < 0.55 then
					local along = Vector3.new(math.abs(dir[2]), 0, math.abs(dir[1]))
					local out = Vector3.new(dir[1], 0, dir[2])
					local edge = V(c.x, c.top, c.z) + out * (C / 2)
					-- a cornice of snow overhanging the edge, icicles under it
					local lip = part("Cornice", along * C + Vector3.new(math.abs(out.X), 0.6, math.abs(out.Z)) * Vector3.new(1.6, 1, 1.6), CFrame.new(edge + out * 0.5 + Vector3.new(0, -0.2, 0)), SNOW, Enum.Material.Snow, coast)
					lip.CanCollide = false
					if c.top >= 0 then
						icicles(edge + out * 1.1 - along * (C / 2) - Vector3.new(0, 0.5, 0), edge + out * 1.1 + along * (C / 2) - Vector3.new(0, 0.5, 0), coast, 0.7)
					end
					-- ice chunks heaped against the shore
					if rng:NextNumber() < 0.3 then
						local s = rng:NextNumber(1.5, 3.5)
						part("ShoreIce", Vector3.new(s, s * 0.6, s * 1.2), CFrame.new(edge + out * (2 + s / 2) + along * rng:NextNumber(-3, 3) + Vector3.new(0, SEA_TOP - c.top + s * 0.2, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), ICE, Enum.Material.Ice, coast)
					end
				end
				-- knuckle steps on the fingers: icicles under the higher edge
				if n and n.kind == "land" and n.top < c.top and rng:NextNumber() < 0.5 then
					local along = Vector3.new(math.abs(dir[2]), 0, math.abs(dir[1]))
					local out = Vector3.new(dir[1], 0, dir[2])
					local edge = V(c.x, c.top - 0.1, c.z) + out * (C / 2 + 0.2)
					icicles(edge - along * (C / 2 - 0.4), edge + along * (C / 2 - 0.4), coast, 0.6)
				end
			end
		end
	end
	if iz % 8 == 0 then
		task.wait()
	end
end

-- ================================================================ the wrist: the ice quarry, the arrival, the buyer, the camp
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	textured(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(mx, -h - B / 2, mz), nil, nil, mine), "px_stone", ROCK)
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(mx - w / 2 - B, -h / 2, mz) },
		{ Vector3.new(2 * B, h, w), at(mx + w / 2 + B, -h / 2, mz) },
	}) do
		textured(part("PitWall", wall[1], wall[2], nil, nil, mine), "px_stone", ROCK)
	end
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B), Vector3.new(1, 0, 0), -1 },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B), Vector3.new(1, 0, 0), 1 },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz), Vector3.new(0, 0, 1), -1 },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz), Vector3.new(0, 0, 1), 1 },
	}) do
		local rim = textured(part("PitRim", r[1], r[2], nil, nil, mine), "px_cobblestone", ROCK)
		-- snow on the rim, icicles hanging over the pit's inner edge
		local cap = part("RimSnow", r[1] - Vector3.new(0.4, 0.2, 0.4) + Vector3.new(0, 0, 0), rim.CFrame * CFrame.new(0, 0.4, 0), SNOW, Enum.Material.Snow, mine)
		cap.CanCollide = false
		local along = r[3]
		local inward = if along.X ~= 0 then Vector3.new(0, 0, -r[4]) else Vector3.new(-r[4], 0, 0)
		local innerEdge = rim.Position + inward * B - Vector3.new(0, 0.3, 0)
		local half = (if along.X ~= 0 then r[1].X else r[1].Z) / 2 - 2 * B
		icicles(innerEdge - along * half, innerEdge + along * half, mine, 0.5)
	end
	-- timber gantries at the corners with lanterns and pulleys (an old ice-cutting quarry)
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local x, z = mx + s[1] * (edge + 3), mz + s[2] * (edge + 3)
		local post = textured(part("QuarryPost", Vector3.new(2.2, 13, 2.2), at(x, 6.5, z), nil, nil, mine), "px_oak_log", DARK_LOG)
		snowCap(post, 0.4, mine)
		local arm = textured(part("CraneArm", Vector3.new(1.4, 1.4, 9), CFrame.lookAt(V(x, 12.2, z), V(mx, 12.2, mz)) * CFrame.new(0, 0, -4), nil, nil, mine), "px_spruce_planks")
		snowCap(arm, 0.3, mine)
		local tip = (arm.CFrame * CFrame.new(0, -0.7, -4.2)).Position
		decor(part("Pulley", Vector3.new(0.4, 1, 1), CFrame.new(tip) * CFrame.Angles(0, 0, 0), IRON, Enum.Material.Metal, mine))
		decor(beam("CraneRope", tip, tip - Vector3.new(0, 7, 0), 0.15, Color3.fromRGB(170, 140, 90), mine, Enum.Material.Fabric))
		local blockOnRope = part("HangingIce", Vector3.new(2.6, 2.6, 2.6), CFrame.new(tip - Vector3.new(0, 8.4, 0)), ICE, Enum.Material.Ice, mine)
		blockOnRope.CanCollide = false
		local lan = part("QuarryLantern", Vector3.new(0.9, 1.1, 0.9), at(x - s[1] * 1.6, 9, z - s[2] * 1.6), GLASS_WARM, Enum.Material.Neon, mine)
		lan.Transparency = 0.1
		light(lan, 34, 1.3, WARM)
		drift(at(x + s[1] * 1.4, 0.1, z + s[2] * 1.4), 3.4, 3.4, 1.4, mine)
	end
	local anchor = part("MineAnchor_snowy_hand", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), nil, nil, mine)
	anchor.Transparency = 1
	anchor:SetAttribute("LocationId", "snowy_hand")
	anchor:SetAttribute("MineId", "snowy_hand")
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
	-- the arrival, the buyer at a fur-roofed stall beside it
	local spawn = part("LocationSpawn_snowy_hand", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + SPAWN_Z), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), nil, nil, mine)
	textured(spawn, "px_spruce_planks")
	spawn:SetAttribute("LocationId", "snowy_hand")
	CollectionService:AddTag(spawn, "LocationSpawn")
	local sx, sz = PIT.x + 18, SPAWN_Z + 2
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(220, 180, 150)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = FUR_DARK, Color3.fromRGB(70, 56, 46), Color3.fromRGB(70, 56, 46)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "SnowBuyer"
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
	model.Parent = mine
	model:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + PIT.x, 3, BZ + SPAWN_Z)))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = model:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, "SellPoint")
	sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
	-- a fur hat with ear flaps and a scarf
	part("FurHat", Vector3.new(2.4, 1.1, 2.4), model.Head.CFrame * CFrame.new(0, 0.65, 0), FUR, Enum.Material.Fabric, model).CanCollide = false
	for _, s in ipairs({ -1, 1 }) do
		part("EarFlap", Vector3.new(0.3, 1, 1), model.Head.CFrame * CFrame.new(s * 1.15, 0, 0), FUR, Enum.Material.Fabric, model).CanCollide = false
	end
	part("BuyerScarf", Vector3.new(1.6, 0.5, 1.4), model.Head.CFrame * CFrame.new(0, -0.75, 0), CLOTH, Enum.Material.Fabric, model).CanCollide = false
	textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), nil, nil, mine), "px_spruce_planks")
	local top = textured(part("CounterTop", Vector3.new(2.8, 0.4, 9.4), at(sx, 3.2, sz), nil, nil, mine), "px_dark_oak_planks")
	decor(part("CounterFur", Vector3.new(2.6, 0.12, 3), top.CFrame * CFrame.new(0, 0.26, 0), FUR, Enum.Material.Fabric, mine))
	for _, dz in ipairs({ -4.4, 4.4 }) do
		for _, dxo in ipairs({ -1.2, 5 }) do
			textured(part("StallPost", Vector3.new(0.8, 9, 0.8), at(sx + dxo, 4.5, sz + dz), nil, nil, mine), "px_oak_log", DARK_LOG)
		end
	end
	local roof = part("StallRoof", Vector3.new(8, 0.6, 10.4), at(sx + 1.9, 9.3, sz) * CFrame.Angles(0, 0, 0.18), FUR_DARK, Enum.Material.Fabric, mine)
	snowCap(roof, 0.5, mine)
	icicles(V(sx - 2.1, 8.5, sz - 5.1), V(sx - 2.1, 8.5, sz + 5.1), mine)
	local lan = part("StallLantern", Vector3.new(0.9, 1.1, 0.9), at(sx + 1.9, 7.8, sz - 4), GLASS_WARM, Enum.Material.Neon, mine)
	light(lan, 24, 1.1, WARM)
	for k = 0, 2 do
		part("IceBlockForSale", Vector3.new(1.6, 1.6, 1.6), at(sx - 0.2, 4.2, sz - 2.6 + k * 2.6) * CFrame.Angles(0, k * 0.3, 0), if k == 1 then Color3.fromRGB(125, 165, 225) else ICE, if k == 1 then Enum.Material.Glacier else Enum.Material.Ice, mine)
	end
	zoneSign(PIT.x - 14, SPAWN_Z + 4, "Снежная длань", math.pi)
end
task.wait()

local camp = folder("SledgeCamp")
do
	-- a campfire ringed by stones and log seats, two snowy tents, sledges, a signpost with arrows to every zone
	local fx, fz = -52, 300
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		part("FireStone", Vector3.new(1.3, 0.9, 1.3), at(fx + math.sin(a) * 2.6, 0.45, fz + math.cos(a) * 2.6) * CFrame.Angles(0, a, 0), ROCK, Enum.Material.Slate, camp)
	end
	for k = 0, 3 do
		part("FireLog", Vector3.new(0.6, 0.6, 3), at(fx, 0.5, fz) * CFrame.Angles(0, k * 0.8, 0.25), Color3.fromRGB(90, 60, 40), Enum.Material.Wood, camp)
	end
	local flame = decor(part("Campfire", Vector3.new(1.4, 1.6, 1.4), at(fx, 1.4, fz), Color3.fromRGB(255, 140, 40), Enum.Material.Neon, camp))
	flame.Transparency = 0.3
	light(flame, 40, 1.8, Color3.fromRGB(255, 160, 80))
	emitter(flame, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 80), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		Size = NumberSequence.new(0.3, 0),
		Rate = 10,
		Lifetime = NumberRange.new(1, 2),
		Speed = NumberRange.new(3, 6),
		SpreadAngle = Vector2.new(20, 20),
	})
	-- a pot over the fire on a tripod
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		decor(beam("Tripod", V(fx + math.sin(a) * 2.2, 0, fz + math.cos(a) * 2.2), V(fx, 4.4, fz), 0.25, DARK_LOG, camp, Enum.Material.Wood))
	end
	decor(part("Pot", Vector3.new(1.4, 1.2, 1.4), at(fx, 2.8, fz), IRON, Enum.Material.Metal, camp))
	for _, s in ipairs({ { 5, 0, 0 }, { -5, 0, 0 }, { 0, 5, math.pi / 2 } }) do
		local seat = part("LogSeat", Vector3.new(1.4, 1.4, 4.4), at(fx + s[1], 0.7, fz + s[2]) * CFrame.Angles(0, s[3], 0), Color3.fromRGB(120, 90, 66), Enum.Material.Wood, camp)
		snowCap(seat, 0.25, camp)
	end
	for _, t in ipairs({ { -76, 292, 0.3 }, { -62, 304, -0.4 } }) do
		local tcf = at(t[1], 0, t[2]) * CFrame.Angles(0, t[3], 0)
		for _, s in ipairs({ -1, 1 }) do
			local cloth = part("TentCloth", Vector3.new(0.4, 8.6, 9), tcf * CFrame.new(s * 2.9, 3.4, 0) * CFrame.Angles(0, 0, s * 0.6), Color3.fromRGB(140, 120, 90), Enum.Material.Fabric, camp)
			snowCap(cloth, 0.4, camp)
		end
		decor(part("TentPole", Vector3.new(0.4, 0.4, 10), tcf * CFrame.new(0, 7, 0), DARK_LOG, Enum.Material.Wood, camp))
		decor(part("TentFlap", Vector3.new(3, 5, 0.2), tcf * CFrame.new(-1.2, 2.6, -4.6) * CFrame.Angles(0, 0.7, 0), Color3.fromRGB(120, 100, 76), Enum.Material.Fabric, camp))
		drift(tcf * CFrame.new(3.6, 0.2, 2), 2.5, 6, 1.4, camp)
	end
	sledge(at(-28, 0, 304) * CFrame.Angles(0, 0.4, 0), camp, true)
	sledge(at(48, 0, 300) * CFrame.Angles(0, -0.8, 0), camp, false)
	snowman(62, 286, -0.5, camp)
	barrel(-86, 304, camp, true)
	crate(at(-88, 1, 298), 2, camp)
	crate(at(-88, 3, 298) * CFrame.Angles(0, 0.3, 0), 1.6, camp)
	woodpile(at(-40, 0, 308) * CFrame.Angles(0, math.pi / 2, 0), 5, 3, camp)
	-- skis leaning on a crate, a pair of snowshoes
	for _, s in ipairs({ -0.3, 0.3 }) do
		decor(part("Ski", Vector3.new(0.4, 0.1, 6), at(-84 + s, 3, 295) * CFrame.Angles(1.2, 0, 0), Color3.fromRGB(160, 60, 40), Enum.Material.Wood, camp))
	end
	-- the signpost with arrows (boards pointing to each zone)
	local px, pz = 24, SPAWN_Z + 6
	textured(part("SignpostPole", Vector3.new(0.8, 9, 0.8), at(px, 4.5, pz), nil, nil, camp), "px_oak_log", DARK_LOG)
	for k, a in ipairs({ { "Лунное озеро", 0, 0 }, { "Ледяные шипы", 54, -320 }, { "Святилище", -48, -330 }, { "Корабль", 190, -300 }, { "Деревня", -300, -32 } }) do
		local yaw = math.atan2(a[2] - px, a[3] - pz)
		local board = textured(part("ArrowBoard", Vector3.new(0.3, 1.1, 5.2), at(px, 8.6 - k * 1.3, pz) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 2.2), nil, nil, camp), "px_spruce_planks")
		boardText(board, a[1], nil, { Enum.NormalId.Left, Enum.NormalId.Right })
		snowCap(board, 0.15, camp)
	end
end
-- lamp posts along the trails to the lake, fences along the quarry side trails
for _, t in ipairs({ TRAILS[1], TRAILS[2] }) do
	for i = 1, #t - 1 do
		local a, b = Vector3.new(t[i][1], 0, t[i][2]), Vector3.new(t[i + 1][1], 0, t[i + 1][2])
		local len = (b - a).Magnitude
		for s = 10, len - 4, 26 do
			local p = a + (b - a).Unit * s + Vector3.new(-(b - a).Unit.Z, 0, (b - a).Unit.X) * 6
			if isLand(p.X, p.Z) then
				lampPost(p.X, p.Z, props)
			end
		end
	end
	footprints(t, props)
end
task.wait()

-- ================================================================ the palm: the Moon lake (arena), birches, the igloo camp
local arena = folder("MoonLake")
do
	local ax, az, R = LAKE.x, LAKE.z, LAKE.r
	-- cracks in the ice and a few clear windows with fish frozen under them
	for k = 0, 13 do
		local a = rng:NextNumber(0, 6.28)
		local p0 = Vector3.new(ax + math.sin(a) * rng:NextNumber(4, 20), 0, az + math.cos(a) * rng:NextNumber(4, 20))
		for _ = 1, rng:NextInteger(3, 5) do
			local p1 = p0 + Vector3.new(math.sin(a), 0, math.cos(a)) * rng:NextNumber(5, 10)
			if math.sqrt((p1.X - ax) ^ 2 + (p1.Z - az) ^ 2) > R - 4 then
				break
			end
			decor(beam("IceCrack", V(p0.X, 0.03, p0.Z), V(p1.X, 0.03, p1.Z), 0.12, Color3.fromRGB(110, 150, 190), arena))
			p0 = p1
			a += rng:NextNumber(-0.6, 0.6)
		end
		_ = k
	end
	for _ = 1, 6 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(14, R - 14)
		local x, z = ax + math.sin(a) * r, az + math.cos(a) * r
		local win = part("ClearIce", Vector3.new(6, 0.1, 5), at(x, 0.04, z) * CFrame.Angles(0, a, 0), Color3.fromRGB(60, 110, 150), Enum.Material.Glass, arena)
		win.CanCollide = false
		win.Transparency = 0.1
		for _ = 1, 2 do
			decor(part("FrozenFish", Vector3.new(0.5, 0.06, 1.3), win.CFrame * CFrame.new(rng:NextNumber(-2, 2), 0.06, rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), Color3.fromRGB(230, 140, 60), nil, arena))
		end
	end
	-- frozen reeds along the shore, a ring of drifted snow
	for i = 0, 89 do
		local a = i / 90 * math.pi * 2 + rng:NextNumber(-0.02, 0.02)
		local r = R + rng:NextNumber(-1, 3)
		local x, z = ax + math.sin(a) * r, az + math.cos(a) * r
		if rng:NextNumber() < 0.45 then
			for _ = 1, 3 do
				local h = rng:NextNumber(1.5, 3.5)
				decor(part("FrozenReed", Vector3.new(0.12, h, 0.12), at(x + rng:NextNumber(-0.6, 0.6), h / 2, z + rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(170, 160, 120), nil, arena))
			end
		end
		if i % 3 == 0 then
			drift(at(x, 0.1, z) * CFrame.Angles(0, a, 0), rng:NextNumber(4, 7), 2.4, rng:NextNumber(0.8, 1.6), arena)
		end
	end
	-- eight lantern columns round the lake (the charge stuns on them: names Pillar*); moths swarm the light
	local tops = {}
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * math.pi * 2
		local px, pz = ax + math.sin(a) * 50, az + math.cos(a) * 50
		local cf = at(px, 0, pz) * CFrame.Angles(0, a, 0)
		local pb = part("PillarBase", Vector3.new(6, 2, 6), cf * CFrame.new(0, 1, 0), ROCK, Enum.Material.Cobblestone, arena)
		snowCap(pb, 0.4, arena)
		local col = part("Pillar", Vector3.new(3, 20, 3), cf * CFrame.new(0, 12, 0), Color3.fromRGB(70, 72, 80), Enum.Material.Slate, arena)
		_ = col
		for y = 6, 18, 6 do
			decor(part("PillarBand", Vector3.new(3.4, 0.5, 3.4), cf * CFrame.new(0, y, 0), IRON, Enum.Material.Metal, arena))
		end
		local capP = part("PillarCap", Vector3.new(4.4, 1, 4.4), cf * CFrame.new(0, 22.5, 0), ROCK, Enum.Material.Cobblestone, arena)
		snowCap(capP, 0.5, arena)
		icicles((capP.CFrame * CFrame.new(-2.2, -0.5, -2.25)).Position, (capP.CFrame * CFrame.new(2.2, -0.5, -2.25)).Position, arena)
		icicles((capP.CFrame * CFrame.new(-2.2, -0.5, 2.25)).Position, (capP.CFrame * CFrame.new(2.2, -0.5, 2.25)).Position, arena)
		-- the lantern cage on top
		local cage = part("LanternCage", Vector3.new(2.2, 3, 2.2), cf * CFrame.new(0, 24.5, 0), Color3.fromRGB(190, 225, 255), Enum.Material.Neon, arena)
		cage.Transparency = 0.15
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				decor(part("CageBar", Vector3.new(0.25, 3.2, 0.25), cage.CFrame * CFrame.new(sx * 1.15, 0, sz * 1.15), IRON, Enum.Material.Metal, arena))
			end
		end
		local roofL = part("LanternRoof", Vector3.new(3, 0.6, 3), cage.CFrame * CFrame.new(0, 1.8, 0), IRON, Enum.Material.Metal, arena)
		snowCap(roofL, 0.3, arena)
		light(cage, 46, 1.5, Color3.fromRGB(190, 220, 255))
		emitter(cage, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(230, 220, 190)),
			LightEmission = 0.4,
			Size = NumberSequence.new(0.35),
			Rate = 5,
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(1, 2.5),
			RotSpeed = NumberRange.new(-200, 200),
			SpreadAngle = Vector2.new(180, 180),
			Drag = 1,
		})
		for _ = 1, 3 do
			moth(cage.CFrame * CFrame.new(rng:NextNumber(-1, 1), rng:NextNumber(-1.4, 1.4), -1.2) * CFrame.Angles(math.pi / 2, 0, rng:NextNumber(-1, 1)), 0.5, arena)
		end
		table.insert(tops, cf)
	end
	-- dead birches with hanging cocoons round the shore
	for i = 0, 15 do
		local a = (i + 0.25) / 16 * math.pi * 2
		local r = R + rng:NextNumber(10, 26)
		local x, z = ax + math.sin(a) * r, az + math.cos(a) * r
		if isLand(x, z) and not (math.abs(x) < 12 and z > az) then
			deadBirch(x, z, rng:NextNumber(12, 20), true, arena)
		end
	end
	-- benches facing the lake, runestones at the way in, the sign
	for _, a in ipairs({ 1.1, 2.0, 4.3, 5.2 }) do
		local r = R + 6
		local x, z = ax + math.sin(a) * r, az + math.cos(a) * r
		local bcf = CFrame.lookAt(V(x, 0, z), V(ax, 0, az))
		local seat = textured(part("BenchSeat", Vector3.new(5, 0.4, 1.4), bcf * CFrame.new(0, 1.6, 0), nil, nil, arena), "px_spruce_planks")
		snowCap(seat, 0.25, arena)
		for _, s in ipairs({ -2, 2 }) do
			part("BenchLeg", Vector3.new(0.4, 1.5, 1.2), bcf * CFrame.new(s, 0.75, 0), IRON, Enum.Material.Metal, arena)
		end
		textured(part("BenchBack", Vector3.new(5, 1.4, 0.3), bcf * CFrame.new(0, 2.6, 0.7), nil, nil, arena), "px_spruce_planks")
	end
	for _, s in ipairs({ -1, 1 }) do
		local st = part("RuneStone", Vector3.new(3, 8, 1.6), at(ax + s * 10, 4, az + R + 8) * CFrame.Angles(0, s * 0.2, s * 0.06), ROCK, Enum.Material.Slate, arena)
		snowCap(st, 0.4, arena)
		for k = 0, 3 do
			local rn = decor(part("Rune", Vector3.new(0.9, 0.9, 0.06), st.CFrame * CFrame.new(rng:NextNumber(-0.6, 0.6), 2.4 - k * 1.5, -0.84) * CFrame.Angles(0, 0, rng:NextNumber(0, 0.8)), RUNE, Enum.Material.Neon, arena))
			rn.Transparency = 0.35
		end
	end
	zoneSign(-14, az + R + 12, "Лунное озеро", math.pi)
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(ax, 1.2, az), nil, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "mole")
	bossSpawn:SetAttribute("ArenaRadius", R - 8)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end
task.wait()

-- the igloo camp (palm, east) and a dog-sled team at rest
local iglooCamp = folder("IglooCamp")
do
	igloo(118, 34, 7, 2.6, iglooCamp)
	igloo(140, 4, 6, 2.0, iglooCamp)
	igloo(104, 64, 5.5, 3.2, iglooCamp)
	-- a drying rack with fish, a kayak on stands, spears in a drift
	for _, s in ipairs({ -2.4, 2.4 }) do
		decor(beam("RackPole", V(128 + s, 0, 46), V(128 + s, 5, 46), 0.3, DARK_LOG, iglooCamp, Enum.Material.Wood))
	end
	decor(part("RackBar", Vector3.new(5.4, 0.25, 0.25), at(128, 4.8, 46), DARK_LOG, Enum.Material.Wood, iglooCamp))
	for k = -2, 2 do
		local fish = decor(part("DriedFish", Vector3.new(0.4, 1.4, 0.2), at(128 + k, 3.8, 46), Color3.fromRGB(160, 130, 90), nil, iglooCamp))
		decor(wedge("FishTail", Vector3.new(0.1, 0.5, 0.5), fish.CFrame * CFrame.new(0, -0.9, 0) * CFrame.Angles(0, math.pi / 2, math.pi), Color3.fromRGB(140, 110, 80), nil, iglooCamp))
	end
	local kayak = blob("Kayak", Vector3.new(1.6, 1, 10), at(150, 1.7, 30) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(150, 110, 70), iglooCamp, Enum.Material.Wood)
	decor(part("KayakSnow", Vector3.new(1, 0.25, 6), kayak.CFrame * CFrame.new(0, 0.5, 0), SNOW, Enum.Material.Snow, iglooCamp))
	for _, s in ipairs({ -3, 3 }) do
		part("KayakStand", Vector3.new(2, 1.2, 0.4), kayak.CFrame * CFrame.new(0, -0.9, s), DARK_LOG, Enum.Material.Wood, iglooCamp)
	end
	for k = 0, 2 do
		decor(beam("Spear", V(112 + k * 0.8, 0, 10), V(112 + k * 0.8 + 0.6, 6.5, 10.4), 0.18, Color3.fromRGB(130, 100, 70), iglooCamp, Enum.Material.Wood))
	end
	drift(at(113, 0.2, 10.2), 3.4, 2.4, 1.4, iglooCamp)
	-- sled dogs curled in the snow (blocky huskies)
	for k = 0, 3 do
		local dcf = at(134 + k * 3.4, 0, 70 + (k % 2) * 2) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		blob("DogBody", Vector3.new(1.6, 1, 2.4), dcf * CFrame.new(0, 0.5, 0), Color3.fromRGB(120, 120, 128), iglooCamp, Enum.Material.Fabric)
		blob("DogBelly", Vector3.new(1.3, 0.6, 1.9), dcf * CFrame.new(0, 0.35, 0), Color3.fromRGB(230, 230, 230), iglooCamp, Enum.Material.Fabric)
		blob("DogHead", Vector3.new(0.9, 0.8, 1), dcf * CFrame.new(0.4, 0.55, -1.1), Color3.fromRGB(120, 120, 128), iglooCamp, Enum.Material.Fabric)
		for _, s in ipairs({ -0.25, 0.25 }) do
			decor(wedge("DogEar", Vector3.new(0.1, 0.4, 0.3), dcf * CFrame.new(0.4 + s, 1.05, -1.1), Color3.fromRGB(100, 100, 108), nil, iglooCamp))
		end
	end
	snowman(96, 30, 2.4, iglooCamp)
end
-- the palm: spruces and rocks scattered (off the trails, the lake and the quarry)
local palmTrees = folder("PalmWoods")
for _ = 1, 220 do
	local x, z = rng:NextNumber(-170, 170), rng:NextNumber(-150, 110)
	local c = cellAtPos(x, z)
	if c and c.kind == "land" and not c.path and math.sqrt((x - LAKE.x) ^ 2 + (z - LAKE.z) ^ 2) > LAKE.r + 30 and c.d < 0.85 and not (x > 90 and z > -10 and z < 80) then
		if rng:NextNumber() < 0.75 then
			spruce(x, z, rng:NextNumber(10, 22), palmTrees)
		else
			local s = rng:NextNumber(2, 5)
			local rock = part("Boulder", Vector3.new(s, s * 0.7, s * 1.1), at(x, c.top + s * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 3), rng:NextNumber(-0.2, 0.2)), ROCK, Enum.Material.Slate, palmTrees)
			snowCap(rock, 0.4, palmTrees)
			if rng:NextNumber() < 0.15 then
				raven(rock.CFrame * CFrame.new(0, s * 0.35 + 0.4, 0), palmTrees)
			end
		end
	end
end
task.wait()

-- ================================================================ the index finger: spruce forest and the hunters' lodge
local forest = folder("IndexForest")
do
	local f = FINGERS.index
	for _ = 1, 120 do
		local t = rng:NextNumber(0.05, 1)
		local x = f[1] + (f[3] - f[1]) * t + rng:NextNumber(-f[5], f[5]) * 0.85
		local z = f[2] + (f[4] - f[2]) * t + rng:NextNumber(-10, 10)
		local c = cellAtPos(x, z)
		if c and c.kind == "land" and not c.path and math.abs(z + 215) + math.abs(x + 143) > 22 then
			spruce(x, z, rng:NextNumber(12, 26), forest)
		end
	end
	-- the lodge (enterable, furnished) on a level clearing
	local y = groundAt(-143, -215)
	local lodge = cabin(at(-143, y, -215) * CFrame.Angles(0, -math.pi / 2, 0), 13, 11, 8, { interior = true, roof = "px_dark_oak_planks" }, folder("HuntersLodge", forest))
	-- skins stretched on frames, an axe in a stump, a hunting trophy rack outside
	for k = 0, 1 do
		local fcf = at(-124, y, -198 + k * 6) * CFrame.Angles(0, 0.3, 0)
		for _, s in ipairs({ -1.5, 1.5 }) do
			decor(beam("SkinFramePole", (fcf * CFrame.new(s, 0, 0)).Position, (fcf * CFrame.new(s, 4.4, 0)).Position, 0.25, DARK_LOG, lodge, Enum.Material.Wood))
		end
		decor(part("StretchedHide", Vector3.new(2.6, 2.8, 0.1), fcf * CFrame.new(0, 2.6, 0), if k == 0 then FUR_DARK else FUR, Enum.Material.Fabric, lodge))
	end
	local stump = part("Stump", Vector3.new(2, 1.4, 2), at(-124, y + 0.7, -230), Color3.fromRGB(120, 90, 66), Enum.Material.Wood, lodge)
	decor(part("StumpRings", Vector3.new(1.7, 0.05, 1.7), stump.CFrame * CFrame.new(0, 0.72, 0), Color3.fromRGB(200, 165, 120), Enum.Material.Wood, lodge))
	decor(part("AxeHandle", Vector3.new(0.2, 2.4, 0.2), stump.CFrame * CFrame.new(0.2, 1.7, 0) * CFrame.Angles(0, 0, 0.5), Color3.fromRGB(130, 100, 70), Enum.Material.Wood, lodge))
	decor(part("AxeHead", Vector3.new(0.8, 0.5, 0.15), stump.CFrame * CFrame.new(-0.25, 0.85, 0), IRON, Enum.Material.Metal, lodge))
	for _ = 1, 4 do
		part("SplitLog", Vector3.new(0.6, 0.6, 1.4), at(-124 + rng:NextNumber(-2.4, 2.4), y + 0.3, -230 + rng:NextNumber(-2.4, 2.4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(190, 150, 100), Enum.Material.Wood, lodge)
	end
	sledge(at(-140, y, -232) * CFrame.Angles(0, 1.4, 0), lodge, true)
	fence(V(-152, 0, -200), V(-152, 0, -230), lodge)
	raven(at(-152, y + 3.4, -200), lodge)
	zoneSign(-112, -172, "Охотничья заимка", math.pi)
end
task.wait()

-- ================================================================ the middle finger: the ring of rune stones and the stone moth
local shrine = folder("RuneShrine")
do
	local cx, cz = -48, -330
	local y = groundAt(cx, cz)
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		local h = rng:NextNumber(7, 11)
		local st = part("RuneStone", Vector3.new(3, h, 1.8), at(cx + math.sin(a) * 18, y + h / 2, cz + math.cos(a) * 18) * CFrame.Angles(0, a, rng:NextNumber(-0.06, 0.06)), ROCK, Enum.Material.Slate, shrine)
		snowCap(st, 0.45, shrine)
		for j = 0, 3 do
			local rn = decor(part("Rune", Vector3.new(0.9, 0.9, 0.06), st.CFrame * CFrame.new(rng:NextNumber(-0.6, 0.6), h / 2 - 1.6 - j * 1.6, 0.92) * CFrame.Angles(0, 0, rng:NextNumber(0, 0.8)), RUNE, Enum.Material.Neon, shrine))
			rn.Transparency = 0.3
		end
		drift(st.CFrame * CFrame.new(0, -h / 2 + 0.3, -1.4), 3.4, 2, 1.2, shrine)
		if k == 3 then
			-- a fallen one, half buried
			st.CFrame = at(cx + math.sin(a) * 20, y + 0.9, cz + math.cos(a) * 20) * CFrame.Angles(0, a, math.pi / 2 - 0.1)
		end
	end
	-- the altar and the stone moth over it, wings spread
	local altar = part("Altar", Vector3.new(6, 3, 4), at(cx, y + 1.5, cz), ROCK, Enum.Material.Cobblestone, shrine)
	snowCap(altar, 0.4, shrine)
	for _, s in ipairs({ -1, 1 }) do
		local br = part("Brazier", Vector3.new(2, 1.2, 2), at(cx + s * 5, y + 3, cz), IRON, Enum.Material.Metal, shrine)
		decor(part("BrazierLeg", Vector3.new(0.5, 2.4, 0.5), at(cx + s * 5, y + 1.2, cz), IRON, Enum.Material.Metal, shrine))
		local flame = decor(part("ColdFire", Vector3.new(1.4, 1.6, 1.4), br.CFrame * CFrame.new(0, 1.2, 0), RUNE, Enum.Material.Neon, shrine))
		flame.Transparency = 0.25
		light(flame, 30, 1.3, RUNE)
	end
	local mcf = at(cx, y + 11, cz - 2) * CFrame.Angles(-1.1, 0, 0)
	part("StoneMothBody", Vector3.new(2.4, 2.4, 9), mcf, Color3.fromRGB(130, 134, 146), Enum.Material.Slate, shrine)
	part("StoneMothHead", Vector3.new(2, 2, 2), mcf * CFrame.new(0, 0, -5.2), Color3.fromRGB(130, 134, 146), Enum.Material.Slate, shrine)
	for _, s in ipairs({ -1, 1 }) do
		local wing = part("StoneMothWing", Vector3.new(11, 0.8, 8), mcf * CFrame.new(s * 6.5, 0, -1) * CFrame.Angles(0, s * 0.15, s * 0.12), Color3.fromRGB(150, 154, 166), Enum.Material.Slate, shrine)
		part("StoneMothHindWing", Vector3.new(8, 0.8, 6), mcf * CFrame.new(s * 5, 0, 4) * CFrame.Angles(0, -s * 0.3, s * 0.1), Color3.fromRGB(140, 144, 156), Enum.Material.Slate, shrine)
		local eye = decor(part("WingEye", Vector3.new(2.6, 0.9, 2.6), wing.CFrame * CFrame.new(s * 1.5, 0, 0), RUNE, Enum.Material.Neon, shrine))
		eye.Transparency = 0.4
		decor(beam("StoneAntenna", (mcf * CFrame.new(s * 0.5, 0.4, -6)).Position, (mcf * CFrame.new(s * 3, 1.4, -10)).Position, 0.4, Color3.fromRGB(130, 134, 146), shrine, Enum.Material.Slate))
		snowCap(wing, 0.35, shrine)
	end
	part("MothPlinth", Vector3.new(3, 7, 3), at(cx, y + 6.5, cz + 1.5), ROCK, Enum.Material.Cobblestone, shrine)
	zoneSign(-30, -296, "Святилище Моли", 0)
	-- a frozen waterfall down the knuckle cliff on the way
	local cliffX
	for x = -44, 0, 1 do
		if groundAt(x, -232) < 8 and groundAt(x - 1, -232) >= 8 then
			cliffX = x - 0.6
			break
		end
	end
	if cliffX then
		for k = 0, 5 do
			local ic = part("FrozenFall", Vector3.new(0.8, 8, rng:NextNumber(1.5, 3)), at(cliffX, 4, -237 + k * 1.8) * CFrame.Angles(rng:NextNumber(-0.05, 0.05), 0, 0), Color3.fromRGB(200, 230, 255), Enum.Material.Ice, shrine)
			ic.Transparency = 0.15
		end
	end
end
task.wait()

-- ================================================================ the ring finger: ice spikes
local spikes = folder("IceSpikes")
do
	local f = FINGERS.ring
	for _ = 1, 60 do
		local t = rng:NextNumber(0.2, 1.05)
		local x = f[1] + (f[3] - f[1]) * t + rng:NextNumber(-f[5], f[5]) * 0.9
		local z = f[2] + (f[4] - f[2]) * t + rng:NextNumber(-12, 12)
		local c = cellAtPos(x, z)
		if c and (c.kind == "land" or c.kind == "sea") and not c.path then
			iceSpike(x, z, if rng:NextNumber() < 0.2 then rng:NextNumber(26, 42) else rng:NextNumber(6, 18), spikes)
		end
	end
	-- broken spikes lying in the snow
	for _ = 1, 8 do
		local t = rng:NextNumber(0.3, 0.95)
		local x = f[1] + (f[3] - f[1]) * t + rng:NextNumber(-16, 16)
		local z = f[2] + (f[4] - f[2]) * t
		if isLand(x, z) then
			part("FallenSpike", Vector3.new(2.6, 2.6, rng:NextNumber(8, 14)), at(x, groundAt(x, z) + 1.2, z) * CFrame.Angles(0.1, rng:NextNumber(0, 3), 0.15), Color3.fromRGB(150, 195, 240), Enum.Material.Glacier, spikes)
		end
	end
	zoneSign(62, -170, "Ледяные шипы", math.pi)
end
task.wait()

-- ================================================================ the little finger: a ship frozen in the sea ice, a whale skeleton
local wreck = folder("FrozenShip")
do
	local scf = at(196, SEA_TOP, -300) * CFrame.Angles(0, 0.7, 0) * CFrame.Angles(0, 0, 0.18)
	local hullC = Color3.fromRGB(90, 66, 48)
	textured(part("Keel", Vector3.new(3, 2, 34), scf * CFrame.new(0, 1, 0), nil, nil, wreck), "px_dark_oak_planks")
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			local hull = textured(part("Hull", Vector3.new(1, 2.4, 32 - k * 4), scf * CFrame.new(s * (2.6 + k * 1.4), 2.4 + k * 2.2, 0) * CFrame.Angles(0, 0, s * 0.35), nil, nil, wreck), "px_dark_oak_planks", hullC)
			_ = hull
		end
		local rail = textured(part("Rail", Vector3.new(0.8, 0.8, 26), scf * CFrame.new(s * 6.6, 8.4, 0), nil, nil, wreck), "px_spruce_planks")
		snowCap(rail, 0.3, wreck)
		icicles((rail.CFrame * CFrame.new(s * 0.45, -0.4, -12)).Position, (rail.CFrame * CFrame.new(s * 0.45, -0.4, 12)).Position, wreck)
	end
	local deck = textured(part("Deck", Vector3.new(12, 0.6, 26), scf * CFrame.new(0, 7.4, 0), nil, nil, wreck), "px_spruce_planks")
	part("DeckSnow", Vector3.new(11, 0.6, 24), deck.CFrame * CFrame.new(0, 0.55, 0), SNOW, Enum.Material.Snow, wreck)
	textured(wedge("Bow", Vector3.new(12, 6, 6), scf * CFrame.new(0, 5, -19) * CFrame.Angles(0, math.pi, 0), nil, nil, wreck), "px_dark_oak_planks", hullC)
	-- the broken mast with a torn, frozen sail and rigging
	local mast = textured(part("Mast", Vector3.new(1.2, 22, 1.2), scf * CFrame.new(0, 18, -2), nil, nil, wreck), "px_oak_log", DARK_LOG)
	snowCap(mast, 0.3, wreck)
	local yard = textured(part("Yard", Vector3.new(14, 0.8, 0.8), scf * CFrame.new(0, 25, -2) * CFrame.Angles(0, 0, 0.25), nil, nil, wreck), "px_oak_log", DARK_LOG)
	snowCap(yard, 0.25, wreck)
	local sail = part("TornSail", Vector3.new(11, 9, 0.15), yard.CFrame * CFrame.new(0.5, -4.8, 0.3) * CFrame.Angles(0.15, 0, 0), Color3.fromRGB(210, 200, 175), Enum.Material.Fabric, wreck)
	sail.CanCollide = false
	icicles((yard.CFrame * CFrame.new(-6.5, -0.45, 0)).Position, (yard.CFrame * CFrame.new(6.5, -0.45, 0)).Position, wreck)
	for _, s in ipairs({ -1, 1 }) do
		decor(beam("Rigging", (scf * CFrame.new(s * 6.4, 8.6, -12)).Position, (scf * CFrame.new(0, 27, -2)).Position, 0.12, Color3.fromRGB(160, 140, 100), wreck))
		decor(beam("Rigging", (scf * CFrame.new(s * 6.4, 8.6, 8)).Position, (scf * CFrame.new(0, 27, -2)).Position, 0.12, Color3.fromRGB(160, 140, 100), wreck))
	end
	-- ice heaved against the hull, scattered cargo, a lifeboat
	for _ = 1, 14 do
		local a = rng:NextNumber(0, 6.28)
		local s = rng:NextNumber(2, 5)
		part("PressureIce", Vector3.new(s, s * 0.5, s * 1.4), scf * CFrame.new(math.sin(a) * rng:NextNumber(7, 12), 0.6, math.cos(a) * rng:NextNumber(10, 20)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)), ICE, Enum.Material.Ice, wreck)
	end
	for k = 0, 5 do
		crate(at(176 + k * 3.5 + rng:NextNumber(-1, 1), SEA_TOP + 1, -282 + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 1), rng:NextNumber(-0.2, 0.2)), 2, wreck)
	end
	barrel(170, -290, wreck, true)
	local boat = blob("Lifeboat", Vector3.new(3.4, 1.6, 8), at(222, SEA_TOP + 0.4, -276) * CFrame.Angles(0.1, 1.1, 0.2), Color3.fromRGB(110, 80, 56), wreck, Enum.Material.Wood)
	decor(part("BoatSnow", Vector3.new(2.4, 0.4, 6), boat.CFrame * CFrame.new(0, 0.6, 0), SNOW, Enum.Material.Snow, wreck))
	decor(part("Oar", Vector3.new(0.25, 0.25, 6), at(226, SEA_TOP + 0.3, -270) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(150, 115, 80), Enum.Material.Wood, wreck))
	raven(mast.CFrame * CFrame.new(0, 11.4, 0), wreck)
	raven(yard.CFrame * CFrame.new(5, 0.4, 0), wreck)
	-- the whale skeleton on the ice off the finger's side
	local wcf = at(222, SEA_TOP, -196) * CFrame.Angles(0, -0.5, 0)
	part("WhaleSkull", Vector3.new(5, 3, 8), wcf * CFrame.new(0, 1.5, -16), Color3.fromRGB(230, 222, 200), Enum.Material.SmoothPlastic, wreck)
	for _, s in ipairs({ -1, 1 }) do
		decor(beam("WhaleJaw", (wcf * CFrame.new(s * 2, 0.4, -12)).Position, (wcf * CFrame.new(s * 1.2, 0.4, -24)).Position, 0.8, Color3.fromRGB(225, 218, 196), wreck))
	end
	for k = 0, 11 do
		local z = -10 + k * 2.4
		part("WhaleVertebra", Vector3.new(1.4, 1.2, 1.4), wcf * CFrame.new(0, 0.8 + math.sin(k / 3) * 0.3, z), Color3.fromRGB(230, 222, 200), Enum.Material.SmoothPlastic, wreck)
		if k < 8 then
			for _, s in ipairs({ -1, 1 }) do
				local w = 5.5 - k * 0.4
				local a = (wcf * CFrame.new(0, 1.2, z)).Position
				local mid = (wcf * CFrame.new(s * w * 0.8, w * 0.8, z + 0.4)).Position
				local tip = (wcf * CFrame.new(s * w, 0.2, z + 0.8)).Position
				decor(beam("WhaleRib", a, mid, 0.45, Color3.fromRGB(225, 218, 196), wreck))
				decor(beam("WhaleRib", mid, tip, 0.4, Color3.fromRGB(225, 218, 196), wreck))
			end
		end
	end
	drift(wcf * CFrame.new(1, 0.2, -2), 6, 10, 1.2, wreck)
	zoneSign(140, -244, "Вмёрзший корабль", math.pi + 0.3)
end
task.wait()

-- ================================================================ the thumb: the fishing village, the dock, boats frozen in, ice holes
local village = folder("FishingVillage")
do
	local thumb = FINGERS.thumb
	local spots = { { 0.32, 1, "smokehouse" }, { 0.5, -1, "house" }, { 0.66, 1, "house" }, { 0.82, -1, "net" } }
	for _, s in ipairs(spots) do
		local t = s[1]
		local x = thumb[1] + (thumb[3] - thumb[1]) * t
		local z = thumb[2] + (thumb[4] - thumb[2]) * t
		local dx, dz = thumb[3] - thumb[1], thumb[4] - thumb[2]
		local len = math.sqrt(dx * dx + dz * dz)
		local nx, nz = -dz / len, dx / len
		local hx, hz = x + nx * s[2] * 15, z + nz * s[2] * 15
		local y = groundAt(hx, hz)
		local facing = CFrame.lookAt(V(hx, y, hz), V(x, y, z))
		local f = folder("Cottage", village)
		cabin(facing, if s[3] == "smokehouse" then 9 else 11, if s[3] == "smokehouse" then 9 else 10, 7, { interior = s[3] == "house", roof = if s[3] == "net" then "px_spruce_planks" else "px_dark_oak_planks", wall = if s[3] == "smokehouse" then "px_dark_oak_planks" else "px_spruce_planks", chimneyLeft = s[2] < 0 }, f)
		if s[3] == "net" then
			-- nets drying on poles beside the house
			for k = 0, 1 do
				local p = facing * CFrame.new(9, 0, -2 + k * 5)
				decor(beam("NetPole", p.Position, (p * CFrame.new(0, 5, 0)).Position, 0.3, DARK_LOG, f, Enum.Material.Wood))
			end
			local net = decor(part("FishingNet", Vector3.new(0.1, 4, 5), facing * CFrame.new(9, 2.8, 0.5), Color3.fromRGB(120, 110, 80), Enum.Material.Fabric, f))
			net.Transparency = 0.45
			for k = 0, 3 do
				decor(part("NetFloat", Vector3.new(0.5, 0.5, 0.5), facing * CFrame.new(9, 4.8, -1.5 + k * 1.3), Color3.fromRGB(220, 120, 40), nil, f))
			end
		elseif s[3] == "smokehouse" then
			-- fish hanging in rows under the eave
			for k = 0, 5 do
				local fish = decor(part("SmokedFish", Vector3.new(0.4, 1.3, 0.2), facing * CFrame.new(-2.5 + k, 6.2, -6.2), Color3.fromRGB(170, 120, 60), nil, f))
				decor(beam("FishString", (fish.CFrame * CFrame.new(0, 0.65, 0)).Position, (fish.CFrame * CFrame.new(0, 1.3, 0)).Position, 0.05, Color3.fromRGB(200, 190, 160), f))
			end
		end
		barrel(hx + nx * s[2] * -6 + 3, hz + nz * s[2] * -6, f, rng:NextNumber() < 0.5)
		lampPost(x - nx * s[2] * 8, z - nz * s[2] * 8, village, true)
	end
	-- the dock off the thumb tip onto the sea ice, boats frozen in beside it
	local tip = Vector3.new(thumb[3], 0, thumb[4])
	local dir = (Vector3.new(thumb[3] - thumb[1], 0, thumb[4] - thumb[2])).Unit
	local start = tip + dir * 18
	local dcf = CFrame.lookAt(V(start.X, 0, start.Z), V(start.X + dir.X, 0, start.Z + dir.Z))
	local dockLen = 44
	textured(part("DockDeck", Vector3.new(7, 0.6, dockLen), dcf * CFrame.new(0, 0.2, -dockLen / 2 + 4), nil, nil, village), "px_spruce_planks")
	part("DockSnow", Vector3.new(4, 0.3, dockLen - 6), dcf * CFrame.new(rng:NextNumber(-0.6, 0.6), 0.65, -dockLen / 2 + 4), SNOW, Enum.Material.Snow, village).CanCollide = false
	for k = 0, dockLen, 6 do
		for _, s in ipairs({ -1, 1 }) do
			local pile = textured(part("DockPile", Vector3.new(1, 5, 1), dcf * CFrame.new(s * 3.7, -1.2, -k + 4), nil, nil, village), "px_oak_log", DARK_LOG)
			snowCap(pile, 0.3, village)
			decor(part("IceCollar", Vector3.new(2.2, 0.5, 2.2), dcf * CFrame.new(s * 3.7, SEA_TOP + 0.2, -k + 4), ICE, Enum.Material.Ice, village))
		end
	end
	icicles((dcf * CFrame.new(3.6, -0.15, 4)).Position, (dcf * CFrame.new(3.6, -0.15, -dockLen + 4)).Position, village, 0.6)
	icicles((dcf * CFrame.new(-3.6, -0.15, 4)).Position, (dcf * CFrame.new(-3.6, -0.15, -dockLen + 4)).Position, village, 0.6)
	for k, side in ipairs({ -1, 1, -1 }) do
		local bcf = dcf * CFrame.new(side * 9, SEA_TOP + 0.3, -8 - k * 11) * CFrame.Angles(rng:NextNumber(-0.08, 0.08), rng:NextNumber(-0.2, 0.2), side * 0.12)
		local hull = blob("FrozenBoat", Vector3.new(4, 2, 11), bcf, Color3.fromRGB(120, 86, 58), village, Enum.Material.Wood)
		decor(part("BoatBench", Vector3.new(3.2, 0.3, 1), hull.CFrame * CFrame.new(0, 0.7, 0), Color3.fromRGB(150, 115, 80), Enum.Material.Wood, village))
		decor(part("BoatSnow", Vector3.new(2.8, 0.4, 7), hull.CFrame * CFrame.new(0, 0.85, 1), SNOW, Enum.Material.Snow, village))
		decor(part("BoatIce", Vector3.new(5.5, 0.4, 12.5), bcf * CFrame.new(0, -0.3, 0), ICE, Enum.Material.Ice, village))
	end
	-- the ice-fishing ground on the sea ice by the open water, with a little shelter
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		fishingHole(-336 + math.sin(a) * 16, -112 + math.cos(a) * 9, village)
	end
	local shelter = at(-316, SEA_TOP, -96) * CFrame.Angles(0, 0.5, 0)
	for _, s in ipairs({ -1, 1 }) do
		textured(part("WindbreakPost", Vector3.new(0.5, 5, 0.5), shelter * CFrame.new(s * 3, 2.5, 0), nil, nil, village), "px_oak_log", DARK_LOG)
	end
	local wb = part("Windbreak", Vector3.new(6.4, 4, 0.2), shelter * CFrame.new(0, 2.6, 0.3), FUR_DARK, Enum.Material.Fabric, village)
	snowCap(wb, 0.25, village)
	sledge(shelter * CFrame.new(0, 0, -4) * CFrame.Angles(0, 1.4, 0), village, true)
	-- seals resting on the ice near the open water
	for k = 0, 3 do
		local scf2 = at(-382 + k * 7, SEA_TOP, -124 + (k % 2) * 5) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		blob("SealBody", Vector3.new(2, 1.4, 4.2), scf2 * CFrame.new(0, 0.7, 0), Color3.fromRGB(110, 112, 120), village, Enum.Material.SmoothPlastic)
		blob("SealHead", Vector3.new(1.2, 1.2, 1.3), scf2 * CFrame.new(0, 1.2, -2), Color3.fromRGB(110, 112, 120), village, Enum.Material.SmoothPlastic)
		for _, s in ipairs({ -0.3, 0.3 }) do
			decor(part("SealEye", Vector3.new(0.18, 0.18, 0.05), scf2 * CFrame.new(s, 1.45, -2.65), Color3.fromRGB(10, 10, 12), nil, village))
		end
		decor(wedge("SealFlipper", Vector3.new(0.2, 0.5, 1.4), scf2 * CFrame.new(0, 0.3, 2.5), Color3.fromRGB(100, 102, 110), nil, village))
	end
	zoneSign(-182, 20, "Рыбацкая деревня", -math.pi / 2 + 0.4)
end
task.wait()

-- ================================================================ the frozen sea: floes, pressure ridges, icebergs at the edge
local sea = folder("FrozenSea")
for _ = 1, 160 do
	local x, z = rng:NextNumber(-400, 400), rng:NextNumber(-410, 400)
	local c = cellAtPos(x, z)
	if c and c.kind == "sea" then
		local roll = rng:NextNumber()
		if roll < 0.55 then
			local s = rng:NextNumber(3, 9)
			part("IceFloe", Vector3.new(s, rng:NextNumber(0.6, 1.4), s * rng:NextNumber(0.6, 1.2)), at(x, SEA_TOP + 0.3, z) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), rng:NextNumber(0, 3), rng:NextNumber(-0.1, 0.1)), SEA_ICE:Lerp(SNOW, rng:NextNumber(0, 0.5)), if rng:NextNumber() < 0.5 then Enum.Material.Ice else Enum.Material.Glacier, sea)
		elseif roll < 0.85 then
			drift(at(x, SEA_TOP + 0.1, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), rng:NextNumber(4, 10), rng:NextNumber(2, 4), rng:NextNumber(0.6, 1.2), sea)
		else
			for _ = 1, rng:NextInteger(3, 6) do
				local s = rng:NextNumber(1.5, 4)
				part("RidgeBlock", Vector3.new(s, s * 0.4, s * 1.5), at(x + rng:NextNumber(-3, 3), SEA_TOP + s * 0.2, z + rng:NextNumber(-3, 3)) * CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 3), rng:NextNumber(-0.7, 0.7)), ICE, Enum.Material.Ice, sea)
			end
		end
	end
end
-- cracks across the sea ice
for _ = 1, 50 do
	local x, z = rng:NextNumber(-390, 390), rng:NextNumber(-400, 390)
	local a = rng:NextNumber(0, 6.28)
	for _ = 1, rng:NextInteger(3, 7) do
		local x2, z2 = x + math.sin(a) * rng:NextNumber(6, 14), z + math.cos(a) * rng:NextNumber(6, 14)
		local c1, c2 = cellAtPos(x, z), cellAtPos(x2, z2)
		if not (c1 and c2 and c1.kind == "sea" and c2.kind == "sea") then
			break
		end
		decor(beam("SeaCrack", V(x, SEA_TOP + 0.03, z), V(x2, SEA_TOP + 0.03, z2), 0.15, Color3.fromRGB(90, 130, 170), sea))
		x, z, a = x2, z2, a + rng:NextNumber(-0.5, 0.5)
	end
end
-- icebergs ring the map's edge (the edge walls stand behind them)
local E = 404
for i = 0, 55 do
	local t = i / 56
	local x, z
	if t < 0.25 then
		x, z = -E + t * 4 * 2 * E, -E
	elseif t < 0.5 then
		x, z = E, -E + (t - 0.25) * 4 * 2 * E
	elseif t < 0.75 then
		x, z = E - (t - 0.5) * 4 * 2 * E, E
	else
		x, z = -E, E - (t - 0.75) * 4 * 2 * E
	end
	-- an iceberg: a broad foot, stepped and tilted blocks narrowing upward, a snowy crest, a bluer waterline
	local h = rng:NextNumber(12, 34)
	local w = rng:NextNumber(14, 26)
	local yaw = rng:NextNumber(0, 3)
	local foot = part("IcebergFoot", Vector3.new(w * 1.3, 3, w * 1.1), at(x, SEA_TOP + 0.5, z) * CFrame.Angles(0, yaw, 0), Color3.fromRGB(140, 190, 230), Enum.Material.Ice, sea)
	_ = foot
	local y, bw, bd = SEA_TOP + 1, w, w * rng:NextNumber(0.7, 1)
	local ox, oz = 0, 0
	for k = 1, rng:NextInteger(3, 4) do
		local seg = h / 3 * rng:NextNumber(0.8, 1.2)
		local blk = part("Iceberg", Vector3.new(bw, seg, bd), at(x + ox, y + seg / 2, z + oz) * CFrame.Angles(rng:NextNumber(-0.1, 0.1), yaw + rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.1, 0.1)), Color3.fromRGB(185, 218, 245):Lerp(Color3.fromRGB(235, 245, 255), k / 4), Enum.Material.Glacier, sea)
		if k >= 2 then
			snowCap(blk, 0.7, sea)
		end
		y += seg * 0.92
		bw *= rng:NextNumber(0.55, 0.75)
		bd *= rng:NextNumber(0.55, 0.75)
		ox += rng:NextNumber(-bw / 3, bw / 3)
		oz += rng:NextNumber(-bd / 3, bd / 3)
	end
end
for _, w in ipairs({ { 0, E + 8, 2 * E + 40, 4 }, { 0, -E - 8, 2 * E + 40, 4 }, { E + 8, 0, 4, 2 * E + 40 }, { -E - 8, 0, 4, 2 * E + 40 } }) do
	local p = part("EdgeWall", Vector3.new(w[3], 400, w[4]), at(w[1], 150, w[2]), nil, nil, sea)
	p.Transparency = 1
	p.CanQuery = false
	p.CastShadow = false
end
task.wait()

-- ================================================================ the trails: footprints on the far ones, lamps by the villages
for i = 3, #TRAILS do
	footprints(TRAILS[i], props, 2.2)
end
-- animal tracks (a fox) wandering across the palm
do
	local x, z = -150, 80
	local a = 0.4
	for k = 1, 90 do
		x += math.sin(a) * 1.4
		z -= math.cos(a) * 1.4
		a += rng:NextNumber(-0.25, 0.25)
		if isLand(x, z) then
			local y = groundAt(x, z)
			decor(part("FoxTrack", Vector3.new(0.35, 0.05, 0.4), at(x + (if k % 2 == 0 then 0.25 else -0.25), y + 0.02, z), Color3.fromRGB(196, 206, 222), Enum.Material.Snow, props))
		end
	end
end

-- ================================================================ the sky: polar night, an aurora, a big moon; snowfall and wind
local sky = folder("Sky")
for r = 0, 2 do
	local phase = r * 2.1
	local baseZ = -260 - r * 70
	local colLow = ({ Color3.fromRGB(80, 255, 160), Color3.fromRGB(90, 230, 210), Color3.fromRGB(120, 255, 140) })[r + 1]
	local colHigh = ({ Color3.fromRGB(150, 90, 255), Color3.fromRGB(110, 140, 255), Color3.fromRGB(200, 100, 230) })[r + 1]
	local prev
	for x = -520, 520, 14 do
		local y = 230 + r * 22 + 18 * math.sin(x / 110 + phase)
		local z = baseZ + 60 * math.sin(x / 150 + phase * 1.3)
		local p = Vector3.new(x, y, z)
		if prev then
			local mid = (prev + p) / 2
			local len = (p - prev).Magnitude
			local cf = CFrame.lookAt(V(mid.X, mid.Y, mid.Z), V(p.X, mid.Y, p.Z))
			local low = decor(part("Aurora", Vector3.new(0.3, 26, len), cf, colLow, Enum.Material.Neon, sky))
			low.Transparency = 0.8
			low.CastShadow = false
			local high = decor(part("AuroraHigh", Vector3.new(0.3, 22, len), cf * CFrame.new(0, 24, 0), colHigh, Enum.Material.Neon, sky))
			high.Transparency = 0.9
			high.CastShadow = false
		end
		prev = p
	end
end
local moon = decor(part("Moon", Vector3.new(70, 70, 70), at(160, 340, -620), Color3.fromRGB(235, 240, 255), Enum.Material.Neon, sky))
moon.Shape = Enum.PartType.Ball
moon.CastShadow = false
for _ = 1, 5 do
	local crater = decor(part("MoonCrater", Vector3.new(14, 14, 14), moon.CFrame * CFrame.new(rng:NextNumber(-18, 18), rng:NextNumber(-18, 18), 26), Color3.fromRGB(200, 210, 230), Enum.Material.Neon, sky))
	crater.Shape = Enum.PartType.Ball
	crater.CastShadow = false
end
-- snowfall blown by the wind [клиент: холодный ветер бьёт в лицо]
for gx = -1, 1 do
	for gz = -1, 1 do
		local e = decor(part("Snowfall", Vector3.new(280, 1, 280), at(gx * 270, 90, gz * 270), SNOW, nil, sky))
		e.Transparency = 1
		emitter(e, {
			Color = ColorSequence.new(Color3.fromRGB(245, 248, 255)),
			LightEmission = 0.3,
			Size = NumberSequence.new(0.22),
			Transparency = NumberSequence.new(0.15),
			Rate = 35,
			Lifetime = NumberRange.new(9, 12),
			Speed = NumberRange.new(7, 10),
			EmissionDirection = Enum.NormalId.Bottom,
			Acceleration = Vector3.new(3.5, 0, 1.2),
			SpreadAngle = Vector2.new(15, 15),
			RotSpeed = NumberRange.new(-90, 90),
		})
	end
end
-- the cold night light (IndoorLighting: the whole island; ClockTime 0 → stars, no sun)
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(part("PolarNight", Vector3.new(900, 320, 900), at(0, 120, -10), nil, nil, air))
volume.Transparency = 1
volume:SetAttribute("Ambient", Color3.fromRGB(150, 165, 200))
volume:SetAttribute("Exposure", 0.35)
volume:SetAttribute("Haze", 0.18)
volume:SetAttribute("ClockTime", 0)
volume:SetAttribute("Brightness", 1.4)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(110, 130, 175))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(50, 66, 110))
CollectionService:AddTag(volume, "IndoorLighting")

-- lift the location to its own height (the Terrain water was filled in place already)
do
	local up = Vector3.new(0, BY, 0)
	for i, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CFrame += up
		end
		if i % 3000 == 0 then
			task.wait()
		end
	end
end

local total = #root:GetDescendants()
print(("[build-snowy-hand] built: %d instances (runs %d)"):format(total, count))
return ("built %d instances, runs %d"):format(total, count)
