--!nocheck
-- Builds the Паучье логово, level 17, PvP [меню]. «Паучье логово окутано мраком, стены густо покрыты паутиной, а
-- тени, скользящие по углам, вызывают дрожь» [клиент]. Blocks: белая шерсть 90 %, паутина 10 % [меню]. Boss: Паучья
-- матка — «королева, скрывающаяся в тени своей армии» [клиент].
-- [владелец 23.10: «вдохновляйся в интернете»] Ideas from spider dungeons (RotMG Spider Den: round chambers joined
-- by short passages, egg sacs that hatch; Vesteria Spider Lair: webs over openings, eggs hanging from the ceiling;
-- battle maps with funnel webs and humanoid cocoons) and the Minecraft abandoned mineshaft (dark oak frames, rails,
-- minecarts, cobwebs round a spider spawner): a closed cavern in the dark — the abandoned adit (arrival, the mine,
-- the buyer, a prospectors' camp lost to the spiders), the Clutch (egg sacs glowing green, hatchlings), the Cocoon
-- graveyard (wrapped prisoners hanging from the vault, bones, rusty gear), and the Queen's nest — a round arena under
-- a dome with a giant floor web, a funnel web in the vault, six web-wrapped stone columns (the charge stuns on them).
-- Webs are our own: thin threads built from parts (orb webs, corner sheets, hanging strands).
-- The lessons of the earlier locations: the arrival and the buyer by the mine, wide ways (PvP crowds), few soft
-- lights with a raised ambient (dark mines), no textures on round parts, closed edges.
-- X 8400, height Y 10500 (each new location floats at its own height). Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.SpiderLair.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("SpiderLair")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "SpiderLair"
root:SetAttribute("LocationId", "spider_lair")
root.Parent = workspace

local BX, BZ = 8400, 0
local BY = 10500 -- the location's own height [владелец 23.10]
local B = 4
local rng = Random.new(20261717)
local THREAD = Color3.fromRGB(232, 232, 238)
local ROCK = Color3.fromRGB(170, 162, 174) -- the stone tint of the cave walls
local VAULT = Color3.fromRGB(140, 134, 148)
local BARK = Color3.fromRGB(96, 74, 56) -- dark oak from our oak log
local IRON = Color3.fromRGB(70, 68, 74)
local RUST = Color3.fromRGB(120, 76, 50)
local SPIDER = Color3.fromRGB(34, 30, 34)
local EYE = Color3.fromRGB(230, 30, 40)
local EGG = Color3.fromRGB(232, 228, 210)
local GLOW = Color3.fromRGB(140, 255, 120)
local SILK = Color3.fromRGB(224, 220, 206)
local BONE = Color3.fromRGB(226, 220, 200)

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or THREAD
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
local function V(x, y, z)
	return Vector3.new(BX + x, y, BZ + z)
end
local function box(name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	local p = part(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), tint, nil, parent)
	if variant then
		textured(p, variant, tint)
	end
	return p
end
-- an ellipsoid (a round part with no texture: textures on round parts look broken)
local function blob(name, size, cf, color, parent, material)
	local p = part(name, size, cf, color, material or Enum.Material.SmoothPlastic, parent)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end
-- a straight piece between two world points
local function beam(name, a, b, thick, color, parent, material)
	local len = (b - a).Magnitude
	local p = part(name, Vector3.new(thick, thick, len), CFrame.lookAt((a + b) / 2, b), color, material, parent)
	return p
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
		label.TextColor3 = color or Color3.fromRGB(235, 225, 200)
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
local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return e
end

-- ================================================================ the plan
local PIT = { x = 0, z = 136, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json spider_lair.mine); z 136: the hole edges lie on the 8-stud cave grid
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local SPAWN_Z = PIT.z + PIT.hole + 14
-- the chambers (round, ragged) and their vault heights
local ENTRY = { x = 0, z = 150, r = 120, h = 58, name = "entry" }
local ARENA = { x = 0, z = -190, r = 82, h = 78, name = "arena" }
local CLUTCH = { x = -178, z = -20, r = 60, h = 44, name = "clutch" }
local COCOONS = { x = 178, z = -20, r = 60, h = 46, name = "cocoons" }
local CHAMBERS = { ENTRY, ARENA, CLUTCH, COCOONS }
-- the passages: wide (PvP crowds), an abandoned mineshaft in each; { ax, az, bx, bz, half-width }
local TUNNELS = {
	{ 0, 40, 0, -112, 17, main = true },
	{ -92, 96, -160, 18, 13 },
	{ -150, -62, -64, -160, 12 },
	{ 92, 96, 160, 18, 13 },
	{ 150, -62, 64, -160, 12 },
	{ -96, 214, -196, 246, 11, deadEnd = true }, -- the collapsed old drift
}
local TUNNEL_H = 30

-- ================================================================ the cave grid (8-stud cells)
local C = 8
local X0, Z0 = -272, -296
local NX, NZ = 68, 74
local TOP = 104 -- the rock above the vault
local function openness(x, z)
	-- < 1 inside the cave; also the feature that owns the cell and its vault height
	local best, owner, vault = math.huge, nil, 0
	for _, s in ipairs(CHAMBERS) do
		local d = math.sqrt((x - s.x) ^ 2 + (z - s.z) ^ 2) / s.r * (1 + n2(x, z, 1.3 + s.r * 0.01, 0.03) * 0.09)
		local h = s.h * (1 - 0.4 * math.min(d, 1) ^ 2)
		if d < best then
			best, owner = d, s
		end
		if d < 1.1 then
			vault = math.max(vault, h)
		end
	end
	for _, t in ipairs(TUNNELS) do
		local d = segDist(x, z, t[1], t[2], t[3], t[4]) / t[5] * (1 + n2(x, z, 4.7, 0.06) * 0.14)
		if d < best then
			best, owner = d, t
		end
		if d < 1.1 then
			vault = math.max(vault, TUNNEL_H - 6 * math.min(d, 1) ^ 2)
		end
	end
	return best, owner, vault
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end

local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local d, owner, vault = openness(x, z)
		local c = { x = x, z = z, d = d, owner = owner }
		c.ceil = 4 * math.floor((math.max(vault, 22) + n2(x, z, 6.6, 0.05) * 6 + n2(x, z, 7.3, 0.13) * 3) / 4)
		if d >= 1 then
			c.kind = "wall"
		elseif inHole(x, z) then
			c.kind = "hole"
		else
			c.kind = "ground"
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
local function ceilAt(x, z)
	local c = cellAtPos(x, z)
	return if c then c.ceil else 30
end
local function isOpen(x, z)
	local c = cellAtPos(x, z)
	return c ~= nil and c.kind == "ground"
end

-- ================================================================ build the floor, the walls and the vault
local terrain = folder("Cave")
local function floorLook(c)
	local v = n2(c.x, c.z, 7.7, 0.05) + n2(c.x, c.z, 2.9, 0.13) * 0.5
	local o = c.owner
	if o == ARENA then
		return if v > 0.35 then "px_mossy_cobblestone" else "px_cobblestone", Color3.fromRGB(150, 146, 150)
	elseif o == CLUTCH then
		return if v > 0.2 then "px_grass_top" else "px_dirt", if v > 0.2 then Color3.fromRGB(70, 84, 60) else Color3.fromRGB(110, 96, 90)
	elseif o == COCOONS then
		return if v > 0.3 then "px_gravel" else "px_stone", Color3.fromRGB(140, 134, 140)
	elseif o and o[1] then -- a passage: gravel and cobble
		return if v > 0.15 then "px_gravel" else "px_cobblestone", Color3.fromRGB(145, 140, 145)
	end
	if v > 0.55 then
		return "px_mossy_cobblestone", Color3.fromRGB(150, 150, 150)
	elseif v < -0.4 then
		return "px_gravel", Color3.fromRGB(150, 146, 150)
	end
	return "px_cobblestone", Color3.fromRGB(150, 146, 150)
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
		box(r.name, X0 + r.ix0 * C, r.y0, z0, X0 + (r.ix1 + 1) * C, r.y1, z1, r.variant, r.tint, terrain)
		count += 1
		runs[k] = nil
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
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		local used = {}
		if c.kind == "ground" then
			local v, tint = floorLook(c)
			push(ix, "body", "Ground", -24, -1, "px_stone", ROCK)
			push(ix, "cap", "GroundTop", -1, 0, v, tint)
			used.body, used.cap = true, true
			push(ix, "ceil", "Vault", c.ceil, TOP, "px_stone", VAULT)
			used.ceil = true
		elseif c.kind == "hole" then
			push(ix, "ceil", "Vault", c.ceil, TOP, "px_stone", VAULT)
			used.ceil = true
		else
			push(ix, "wall", "CaveWall", -24, TOP, "px_stone", ROCK)
			used.wall = true
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

-- ================================================================ small builders
local props = folder("Props")
local webs = folder("Webs")
-- an orb web in the plane of cf (X, Y in the plane), spokes and rings of thin threads; a0..a1 for a part web
local function orbWeb(cf, R, spokes, rings, parent, a0, a1)
	a0 = a0 or 0
	a1 = a1 or math.pi * 2
	local full = a1 - a0 >= math.pi * 2 - 1e-3
	local thick = if R > 24 then 0.2 elseif R > 10 then 0.14 else 0.1
	local angles = {}
	for k = 0, spokes - 1 do
		local t = if full then k / spokes else k / (spokes - 1)
		table.insert(angles, a0 + (a1 - a0) * t + rng:NextNumber(-0.06, 0.06))
	end
	local centre = cf.Position
	for _, a in ipairs(angles) do
		local p = beam("WebSpoke", centre, (cf * CFrame.new(math.cos(a) * R, math.sin(a) * R, 0)).Position, thick, THREAD, parent or webs)
		decor(p).CastShadow = false
		p.Transparency = 0.2
	end
	for k = 1, rings do
		local r = R * (k / (rings + 0.6)) ^ 0.9
		local pts = {}
		for _, a in ipairs(angles) do
			local rr = r * rng:NextNumber(0.94, 1.05)
			table.insert(pts, (cf * CFrame.new(math.cos(a) * rr, math.sin(a) * rr, 0)).Position)
		end
		for i = 1, #pts - (if full then 0 else 1) do
			local a, b = pts[i], pts[i % #pts + 1]
			local p = beam("WebThread", a, b, thick * 0.8, THREAD, parent or webs)
			decor(p).CastShadow = false
			p.Transparency = 0.3
		end
	end
end
-- a hanging strand from the vault, optionally with a small spider at its end
local spiderModel
local function strand(x, z, len, withSpider, parent)
	local top = ceilAt(x, z)
	local p = beam("Strand", V(x, top, z), V(x, top - len, z), 0.1, THREAD, parent or webs)
	decor(p).CastShadow = false
	p.Transparency = 0.25
	if withSpider then
		spiderModel(at(x, top - len - 0.6, z) * CFrame.Angles(math.pi / 2, rng:NextNumber(0, 6.28), 0), 0.35, parent or props, true)
	end
end
-- a blocky spider: abdomen with a red mark, thorax, head, eight red eyes, eight jointed legs
spiderModel = function(cf, s, parent, hanging)
	local f = parent or props
	local body = part("SpiderAbdomen", Vector3.new(3.2, 2.4, 3.8) * s, cf * CFrame.new(0, 1.9 * s, 2.4 * s), SPIDER, Enum.Material.SmoothPlastic, f)
	part("SpiderMark", Vector3.new(1.2, 0.2, 1.8) * s, body.CFrame * CFrame.new(0, 1.22 * s, 0), Color3.fromRGB(150, 24, 30), nil, f)
	part("SpiderThorax", Vector3.new(2.2, 1.6, 2.2) * s, cf * CFrame.new(0, 1.6 * s, 0), SPIDER:Lerp(Color3.new(1, 1, 1), 0.06), nil, f)
	local head = part("SpiderHead", Vector3.new(1.6, 1.3, 1.3) * s, cf * CFrame.new(0, 1.6 * s, -1.7 * s), SPIDER, nil, f)
	for i = 0, 3 do
		for _, side in ipairs({ -1, 1 }) do
			local eye = decor(part("SpiderEye", Vector3.new(0.26, 0.26, 0.1) * s, head.CFrame * CFrame.new(side * (0.22 + i % 2 * 0.36) * s, (0.32 - math.floor(i / 2) * 0.32) * s, -0.66 * s), EYE, Enum.Material.Neon, f))
			_ = eye
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		decor(part("SpiderFang", Vector3.new(0.3, 0.8, 0.3) * s, head.CFrame * CFrame.new(side * 0.35 * s, -0.8 * s, -0.5 * s), BONE, nil, f))
	end
	for k = 0, 3 do
		local yaw = math.rad(-55 + k * 36)
		for _, side in ipairs({ -1, 1 }) do
			local out = Vector3.new(side * math.cos(yaw), 0, math.sin(yaw))
			local rootP = (cf * CFrame.new(side * 1.0 * s, 1.6 * s, 0)).Position
			local knee = rootP + cf:VectorToWorldSpace(out * 2.2 * s + Vector3.new(0, 1.4 * s, 0))
			local foot = rootP + cf:VectorToWorldSpace(out * 4.2 * s + Vector3.new(0, (if hanging then -0.4 else -1.6) * s, 0))
			decor(beam("SpiderLeg", rootP, knee, 0.42 * s, SPIDER, f))
			decor(beam("SpiderLeg", knee, foot, 0.34 * s, SPIDER, f))
		end
	end
	return body
end
-- a cocoon: a wrapped prisoner, the silk bound with darker strands; sometimes a hand or a pickaxe sticks out
local function cocoon(cf, len, parent)
	local f = parent or props
	local c = blob("Cocoon", Vector3.new(len * 0.42, len, len * 0.42), cf, SILK, f)
	for k = -1, 1 do
		local band = blob("CocoonBand", Vector3.new(len * 0.45, 0.35, len * 0.45), cf * CFrame.new(0, k * len * 0.24, 0) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), SILK:Lerp(Color3.new(0.5, 0.48, 0.42), 0.35), f)
		decor(band)
	end
	local roll = rng:NextNumber()
	if roll < 0.2 then
		decor(part("CocoonHand", Vector3.new(0.5, 1.2, 0.5), cf * CFrame.new(len * 0.2, -len * 0.05, -len * 0.06) * CFrame.Angles(0, 0, -0.9), Color3.fromRGB(196, 150, 120), nil, f))
	elseif roll < 0.32 then
		decor(part("CocoonPick", Vector3.new(0.3, 2.6, 0.3), cf * CFrame.new(0, len * 0.25, -len * 0.2) * CFrame.Angles(0.8, 0, 0), Color3.fromRGB(110, 80, 50), Enum.Material.Wood, f))
		decor(part("CocoonPickHead", Vector3.new(2, 0.35, 0.35), cf * CFrame.new(0, len * 0.25 + 1, -len * 0.2 - 0.9), IRON, Enum.Material.Metal, f))
	end
	return c
end
-- a cluster of egg sacs; some glow green from inside, some are hatched (broken shells)
local glowLights = 0
local function eggs(x, y, z, n, parent, glowing)
	local f = parent or props
	for _ = 1, n do
		local s = rng:NextNumber(1.4, 3)
		local p = V(x + rng:NextNumber(-2.4, 2.4), y + s / 2 + rng:NextNumber(0, 1.2), z + rng:NextNumber(-2.4, 2.4))
		if rng:NextNumber() < 0.15 then
			-- a hatched one: two halves of shell
			blob("EggShell", Vector3.new(s, s * 0.5, s), CFrame.new(p.X, y + s * 0.25, p.Z), EGG, f).Transparency = 0.1
			blob("EggShell", Vector3.new(s * 0.9, s * 0.45, s * 0.9), CFrame.new(p.X + s * 0.6, y + s * 0.2, p.Z + 0.4) * CFrame.Angles(2.6, 0, 0.4), EGG, f).Transparency = 0.1
		else
			local egg = blob("EggSac", Vector3.new(s, s * 1.15, s), CFrame.new(p), EGG, f)
			egg.Transparency = 0.12
			if glowing and rng:NextNumber() < 0.45 then
				local core = decor(blob("EggGlow", Vector3.new(s * 0.5, s * 0.55, s * 0.5), CFrame.new(p), GLOW, f, Enum.Material.Neon))
				core.Transparency = 0.35
				if glowLights < 22 and rng:NextNumber() < 0.35 then
					glowLights += 1
					light(core, 18, 1, GLOW)
				end
			end
		end
	end
end
local function lantern(cfTop, lit, parent)
	local f = parent or props
	decor(part("LanternChain", Vector3.new(0.2, 1.4, 0.2), cfTop * CFrame.new(0, -0.7, 0), IRON, Enum.Material.Metal, f))
	part("LanternCap", Vector3.new(1.3, 0.3, 1.3), cfTop * CFrame.new(0, -1.55, 0), IRON, Enum.Material.Metal, f)
	local glass = part("Lantern", Vector3.new(1, 1.2, 1), cfTop * CFrame.new(0, -2.3, 0), Color3.fromRGB(255, 196, 110), Enum.Material.Neon, f)
	glass.Transparency = 0.15
	part("LanternBase", Vector3.new(1.3, 0.3, 1.3), cfTop * CFrame.new(0, -3.05, 0), IRON, Enum.Material.Metal, f)
	if lit then
		light(glass, 30, 1.3, Color3.fromRGB(255, 190, 120))
	end
	return glass
end
local function crate(cf, s, parent)
	local c = textured(part("Crate", Vector3.new(s, s, s), cf, nil, nil, parent or props), "px_dark_oak_planks", Color3.fromRGB(190, 170, 150))
	return c
end
local function barrel(x, z, parent)
	local f = parent or props
	part("Barrel", Vector3.new(2.6, 3.2, 2.6), at(x, 1.6, z), Color3.fromRGB(96, 66, 44), Enum.Material.Wood, f)
	for _, y in ipairs({ 0.6, 2.6 }) do
		decor(part("BarrelHoop", Vector3.new(2.7, 0.25, 2.7), at(x, y, z), IRON, Enum.Material.Metal, f))
	end
end
local function bones(x, z, parent)
	local f = parent or props
	local y0 = 0.2
	part("Skull", Vector3.new(1.2, 1.1, 1.3), at(x, y0 + 0.55, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)), BONE, nil, f)
	for _ = 1, rng:NextInteger(2, 4) do
		decor(part("Bone", Vector3.new(0.35, 0.35, rng:NextNumber(1.6, 2.8)), at(x + rng:NextNumber(-1.8, 1.8), y0 + 0.2, z + rng:NextNumber(-1.8, 1.8)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), BONE, nil, f))
	end
	if rng:NextNumber() < 0.3 then
		decor(part("RustyHelmet", Vector3.new(1.5, 1, 1.6), at(x + 1.4, y0 + 0.5, z - 0.6) * CFrame.Angles(0.3, 0.5, 0.2), RUST, Enum.Material.Metal, f))
	end
end
local function zoneSign(x, z, text, yaw)
	textured(part("SignPost", Vector3.new(0.8, 5, 0.8), at(x, 2.5, z), nil, nil, props), "px_oak_log", BARK)
	local board = textured(part("ZoneSign", Vector3.new(8, 1.8, 0.4), at(x, 4.6, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, props), "px_dark_oak_planks")
	boardText(board, text)
	orbWeb(at(x, 4.6, z) * CFrame.Angles(0, yaw or 0, 0) * CFrame.new(3.6, 0.6, -0.3), 2.2, 5, 2, webs, math.pi / 2, math.pi)
end
-- a mineshaft frame (two dark oak posts, a cap beam) across a passage; a web sheet in its upper corners
local function frame(cf, halfW, h, parent, lit)
	local f = parent or props
	for _, s in ipairs({ -1, 1 }) do
		textured(part("FramePost", Vector3.new(1.6, h, 1.6), cf * CFrame.new(s * halfW, h / 2, 0), nil, nil, f), "px_oak_log", BARK)
		if rng:NextNumber() < 0.55 then
			orbWeb(cf * CFrame.new(s * (halfW - 0.8), h - 0.8, 0), rng:NextNumber(3, 5.5), 5, 3, webs, if s < 0 then -math.pi / 2 else math.pi, if s < 0 then 0 else math.pi * 1.5)
		end
	end
	textured(part("FrameCap", Vector3.new(halfW * 2 + 2.4, 1.6, 2), cf * CFrame.new(0, h + 0.8, 0), nil, nil, f), "px_dark_oak_planks")
	if lit ~= nil then
		lantern(cf * CFrame.new(0, h, -1.4), lit, f)
	end
end
local function rails(a, b, parent)
	local f = parent or props
	local d = b - a
	local len = d.Magnitude
	local cf = CFrame.lookAt(a, b)
	for _, s in ipairs({ -1.2, 1.2 }) do
		decor(part("Rail", Vector3.new(0.3, 0.3, len), cf * CFrame.new(s, 0.15, -len / 2), IRON, Enum.Material.Metal, f))
	end
	for t = 1, len - 1, 2.2 do
		decor(textured(part("Sleeper", Vector3.new(3.6, 0.2, 0.8), cf * CFrame.new(0, 0.05, -t), nil, nil, f), "px_dark_oak_planks"))
	end
end
local function minecart(cf, parent, tipped)
	local f = parent or props
	local base = if tipped then cf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(100)) else cf * CFrame.new(0, 1.3, 0)
	part("CartFloor", Vector3.new(3.2, 0.3, 4.2), base * CFrame.new(0, -0.8, 0), IRON, Enum.Material.Metal, f)
	for _, w in ipairs({ { 0, 0, -2, 3.2, 1.8, 0.3 }, { 0, 0, 2, 3.2, 1.8, 0.3 }, { -1.6, 0, 0, 0.3, 1.8, 4.2 }, { 1.6, 0, 0, 0.3, 1.8, 4.2 } }) do
		part("CartSide", Vector3.new(w[4], w[5], w[6]), base * CFrame.new(w[1], w[2], w[3]), IRON:Lerp(RUST, 0.3), Enum.Material.Metal, f)
	end
	for _, s in ipairs({ { -1.2, -1.4 }, { 1.2, -1.4 }, { -1.2, 1.4 }, { 1.2, 1.4 } }) do
		decor(part("CartWheel", Vector3.new(0.4, 1, 1), base * CFrame.new(s[1] * 1.45, -1, s[2]), Color3.fromRGB(40, 38, 42), Enum.Material.Metal, f))
	end
	if not tipped then
		for _ = 1, 3 do
			textured(part("CartLoad", Vector3.new(1.4, 1.4, 1.4), base * CFrame.new(rng:NextNumber(-0.7, 0.7), 0.4, rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), nil, nil, f), "px_white_wool")
		end
	end
	orbWeb(base * CFrame.new(0, 0.9, -2.1), 2.2, 5, 2, webs, 0, math.pi)
end

-- ================================================================ the walls: rock outcrops, moss, corner webs
local walls = folder("WallDetail")
local cornerWebs = 0
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		if c.kind == "ground" then
			for _, dir in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				local n = cellAt(ix + dir[1], iz + dir[2])
				if n and n.kind == "wall" then
					local fx, fz = c.x + dir[1] * C / 2, c.z + dir[2] * C / 2
					local along = Vector3.new(math.abs(dir[2]), 0, math.abs(dir[1]))
					-- outcrops: blocks of rock at different depths
					for _ = 1, rng:NextInteger(0, 2) do
						local s = rng:NextInteger(1, 2) * B
						local off = rng:NextNumber(-C / 2 + s / 2, C / 2 - s / 2)
						local y = rng:NextInteger(0, math.max(1, math.floor(c.ceil / B) - 2)) * B + s / 2
						local depth = rng:NextNumber(0.6, 2.2)
						local pos = V(fx, y, fz) - Vector3.new(dir[1], 0, dir[2]) * (s / 2 - depth) + along * off
						local v = if rng:NextNumber() < 0.25 then "px_mossy_cobblestone" elseif rng:NextNumber() < 0.5 then "px_cobblestone" else "px_stone"
						textured(part("Outcrop", Vector3.new(s, s, s), CFrame.new(pos), nil, nil, walls), v, ROCK)
					end
					-- a web sheet in the corner between the wall and the vault: a half web tilted down into the room
					if rng:NextNumber() < 0.16 and cornerWebs < 150 then
						cornerWebs += 1
						local inward = Vector3.new(-dir[1], 0, -dir[2])
						local anchor = V(fx, c.ceil, fz) + inward * 0.3 + along * rng:NextNumber(-2, 2)
						local cf = CFrame.fromMatrix(anchor, along, (inward - Vector3.yAxis).Unit)
						orbWeb(cf, rng:NextNumber(5, 10), 7, 4, webs, 0, math.pi)
					end
				end
			end
		end
	end
	if iz % 6 == 0 then
		task.wait()
	end
end

-- the vault: stalactites, hanging strands with small spiders
local vault = folder("VaultDetail")
for _ = 1, 140 do
	local x, z = rng:NextNumber(-260, 260), rng:NextNumber(-280, 270)
	local c = cellAtPos(x, z)
	if c and c.kind == "ground" and not inHole(x, z) then
		local y = c.ceil
		local w = rng:NextInteger(1, 2) * B
		while w >= B do
			local len = rng:NextInteger(1, 3) * B
			textured(part("Stalactite", Vector3.new(w, len, w), at(x, y - len / 2, z), nil, nil, vault), "px_stone", VAULT)
			y -= len
			w -= B
		end
	end
end
for _ = 1, 110 do
	local x, z = rng:NextNumber(-260, 260), rng:NextNumber(-280, 270)
	if isOpen(x, z) then
		strand(x, z, rng:NextNumber(6, 22), rng:NextNumber() < 0.35, vault)
	end
end
-- stalagmites and rubble along the walls (not on the passages' middle)
for _ = 1, 160 do
	local x, z = rng:NextNumber(-260, 260), rng:NextNumber(-280, 270)
	local c = cellAtPos(x, z)
	if c and c.kind == "ground" and c.d > 0.84 and not inHole(x, z) then
		local w = rng:NextInteger(1, 2) * B
		local y = 0
		while w >= B do
			local len = rng:NextInteger(1, 2) * B
			textured(part("Stalagmite", Vector3.new(w, len, w), at(x, y + len / 2, z), nil, nil, vault), "px_stone", ROCK)
			y += len
			w -= B
		end
	end
end
task.wait()

-- ================================================================ the mineshafts in the passages
local shafts = folder("Mineshafts")
for ti, t in ipairs(TUNNELS) do
	local a, b = V(t[1], 0, t[2]), V(t[3], 0, t[4])
	local d = b - a
	local len = d.Magnitude
	local dirv = d.Unit
	local n = 0
	for s = 8, len - 8, 18 do
		local p = a + dirv * s
		local half = t[5] * 0.72
		local h = math.min(ceilAt(p.X - BX, p.Z - BZ) - 4, 15)
		n += 1
		frame(CFrame.lookAt(p, p + dirv), half, h, shafts, if n % 2 == 0 then (n % 4 == 0) else nil)
	end
	if t.main or ti == 2 or ti == 4 then
		rails(a + dirv * 4, b - dirv * 4, shafts)
	end
	-- a high web across each passage
	local mid = a + dirv * len * 0.5
	local h = ceilAt(mid.X - BX, mid.Z - BZ)
	orbWeb(CFrame.lookAt(mid + Vector3.new(0, h - 9, 0), mid + Vector3.new(0, h - 9, 0) + dirv), math.min(t[5] - 3, 9), 9, 5, webs)
	if t.deadEnd then
		-- the collapsed end: a heap of rubble and broken beams, a tipped cart
		for _ = 1, 22 do
			local s = rng:NextInteger(1, 3) * B
			local q = b - dirv * rng:NextNumber(0, 18) + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-8, 8))
			textured(part("Rubble", Vector3.new(s, s, s), CFrame.new(q + Vector3.new(0, s / 2 + rng:NextNumber(0, 6), 0)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, shafts), if rng:NextNumber() < 0.5 then "px_cobblestone" else "px_gravel", ROCK)
		end
		for _ = 1, 4 do
			local q = b - dirv * rng:NextNumber(10, 24)
			textured(part("BrokenBeam", Vector3.new(1.6, 1.6, rng:NextNumber(8, 14)), CFrame.new(q + Vector3.new(rng:NextNumber(-6, 6), 2, rng:NextNumber(-6, 6))) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 3), rng:NextNumber(-0.4, 0.4)), nil, nil, shafts), "px_dark_oak_planks")
		end
		minecart(CFrame.lookAt(b - dirv * 30, b), shafts, true)
		bones((b - dirv * 34).X - BX + 4, (b - dirv * 34).Z - BZ, shafts)
	end
	task.wait()
end

-- ================================================================ the adit: the mine and the arrival by it
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
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], nil, nil, mine), "px_dark_oak_planks")
	end
	-- timber posts at the corners with lanterns, webs strung between the post tops along each side
	local corners = {}
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { 1, 1 }, { -1, 1 } }) do
		local x, z = mx + s[1] * (edge + 3), mz + s[2] * (edge + 3)
		textured(part("PitPost", Vector3.new(2.4, 14, 2.4), at(x, 7, z), nil, nil, mine), "px_oak_log", BARK)
		textured(part("PitPostCap", Vector3.new(3.4, 1.2, 3.4), at(x, 14.6, z), nil, nil, mine), "px_dark_oak_planks")
		lantern(at(x - s[1] * 2, 14, z - s[2] * 2), true, mine)
		orbWeb(CFrame.lookAt(V(x, 13, z), V(mx, 13, mz)) * CFrame.Angles(0, math.pi / 4, 0), 4.5, 6, 3, webs, math.pi, math.pi * 1.5)
		table.insert(corners, V(x, 14, z))
	end
	for i = 1, 4 do
		local a, b = corners[i], corners[i % 4 + 1]
		for k = 0, 1 do
			-- two sagging threads per side (a drooping silk garland)
			local sag = (a + b) / 2 - Vector3.new(0, 5 + k * 2, 0)
			decor(beam("Garland", a - Vector3.new(0, k, 0), sag, 0.14, THREAD, webs)).Transparency = 0.25
			decor(beam("Garland", sag, b - Vector3.new(0, k, 0), 0.14, THREAD, webs)).Transparency = 0.25
		end
	end
	local anchor = part("MineAnchor_spider_lair", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), nil, nil, mine)
	anchor.Transparency = 1
	anchor:SetAttribute("LocationId", "spider_lair")
	anchor:SetAttribute("MineId", "spider_lair")
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
	-- the arrival, the buyer at a timber stall beside it
	local spawn = part("LocationSpawn_spider_lair", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + SPAWN_Z), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), nil, nil, mine)
	textured(spawn, "px_dark_oak_planks")
	spawn:SetAttribute("LocationId", "spider_lair")
	CollectionService:AddTag(spawn, "LocationSpawn")
	local sx, sz = PIT.x + 18, SPAWN_Z + 2
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(205, 160, 125)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(70, 80, 60), Color3.fromRGB(60, 50, 40), Color3.fromRGB(60, 50, 40)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "LairBuyer"
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
	-- a miner's helmet with a lamp
	part("Helmet", Vector3.new(2.3, 0.9, 2.3), model.Head.CFrame * CFrame.new(0, 0.6, 0), Color3.fromRGB(200, 160, 40), Enum.Material.SmoothPlastic, model).CanCollide = false
	decor(part("HelmetLamp", Vector3.new(0.6, 0.5, 0.3), model.Head.CFrame * CFrame.new(0, 0.7, -1.2), Color3.fromRGB(255, 230, 160), Enum.Material.Neon, model))
	textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), nil, nil, mine), "px_dark_oak_planks")
	textured(part("CounterTop", Vector3.new(2.8, 0.4, 9.4), at(sx, 3.2, sz), nil, nil, mine), "px_spruce_planks")
	for _, dz in ipairs({ -4.4, 4.4 }) do
		for _, dxo in ipairs({ -1.2, 5 }) do
			textured(part("StallPost", Vector3.new(0.8, 9, 0.8), at(sx + dxo, 4.5, sz + dz), nil, nil, mine), "px_oak_log", BARK)
		end
	end
	textured(part("StallRoof", Vector3.new(8, 0.8, 10), at(sx + 1.9, 9.4, sz), nil, nil, mine), "px_dark_oak_planks")
	lantern(at(sx + 1.9, 9, sz - 4), true, mine)
	orbWeb(at(sx + 5, 8.6, sz + 4.4) * CFrame.Angles(0, math.pi / 2, 0), 3, 5, 2, webs, math.pi, math.pi * 1.5)
	textured(part("Crate", Vector3.new(1.8, 1.8, 1.8), at(sx - 0.3, 4.3, sz - 2.5), nil, nil, mine), "px_white_wool")
	crate(at(sx - 0.3, 4.3, sz + 2.5), 1.8, mine)
	-- the zone sign by the arrival
	zoneSign(PIT.x - 14, SPAWN_Z + 4, "Паучье логово", math.pi)
end
task.wait()

-- ================================================================ the prospectors' camp lost to the spiders (the adit, south-east)
local camp = folder("Camp")
do
	local cx, cz = 60, 226
	-- a tent wrapped in silk
	for _, s in ipairs({ -1, 1 }) do
		local p = part("TentCloth", Vector3.new(0.4, 11, 13), at(cx + s * 3.6, 4.2, cz) * CFrame.Angles(0, 0, s * 0.58), Color3.fromRGB(150, 130, 96), Enum.Material.Fabric, camp)
		_ = p
	end
	textured(part("TentPole", Vector3.new(0.6, 0.6, 14), at(cx, 8.8, cz), nil, nil, camp), "px_oak_log", BARK)
	orbWeb(at(cx, 5, cz - 6.6), 6, 9, 4, webs)
	cocoon(at(cx + 1, 1.2, cz + 2) * CFrame.Angles(0, 0, math.pi / 2), 5, camp)
	-- a cold campfire, barrels, crates, picks left behind
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		textured(part("FireStone", Vector3.new(1.4, 0.9, 1.4), at(cx - 14 + math.sin(a) * 2.6, 0.45, cz + 10 + math.cos(a) * 2.6), nil, nil, camp), "px_cobblestone", ROCK)
	end
	for k = 0, 2 do
		textured(part("Ash", Vector3.new(0.6, 0.6, 3), at(cx - 14, 0.4, cz + 10) * CFrame.Angles(0, k, 0), nil, nil, camp), "px_oak_log", Color3.fromRGB(60, 50, 44))
	end
	barrel(cx - 10, cz - 6, camp)
	barrel(cx - 7, cz - 8, camp)
	crate(at(cx + 9, 1.25, cz - 4), 2.5, camp)
	crate(at(cx + 9, 3.75, cz - 4) * CFrame.Angles(0, 0.4, 0), 2.5, camp)
	crate(at(cx + 11.5, 1.25, cz - 2) * CFrame.Angles(0, 0.2, 0), 2.5, camp)
	orbWeb(at(cx + 10, 4, cz - 2.5) * CFrame.Angles(0, -math.pi / 4, 0), 3, 6, 3, webs)
	bones(cx - 18, cz - 2, camp)
	bones(cx + 16, cz + 8, camp)
	-- a minecart on a short spur by the camp, rails into the mine's rim
	rails(V(cx - 30, 0, cz - 20), V(cx - 30, 0, cz + 24), camp)
	minecart(at(cx - 30, 0, cz + 4), camp, false)
	frame(at(cx - 30, 0, cz + 22), 4, 10, camp, true)
	spiderModel(at(cx + 24, 0, cz - 14) * CFrame.Angles(0, 2.4, 0), 1.1, camp)
	-- eggs laid in the camp: the spiders came from the drift
	eggs(-118, 0, 228, 6, camp, true)
	eggs(-60, 0, 240, 5, camp, false)
	eggs(-104, 0, 194, 4, camp, true)
end
-- the adit's own mineshaft: frames at the mouths of the side drifts, rails from the main tunnel to the mine
rails(V(0, 0, 44), V(0, 0, PIT.z - PIT.hole - 2), shafts)
for _, q in ipairs({ { -98, 140 }, { 98, 140 }, { -90, 96 }, { 90, 96 } }) do
	local px, pz = q[1], q[2]
	if isOpen(px, pz) and not inHole(px + 8, pz) and not inHole(px - 8, pz) then
		frame(CFrame.lookAt(V(px, 0, pz), V(ENTRY.x, 0, ENTRY.z)), 5, 12, shafts, true)
	end
end
task.wait()

-- ================================================================ the Clutch (west): egg sacs, hatchlings, a floor of silk
local clutch = folder("Clutch")
do
	local cx, cz = CLUTCH.x, CLUTCH.z
	orbWeb(at(cx, 0.08, cz) * CFrame.Angles(-math.pi / 2, 0, 0), 38, 12, 7, webs)
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, CLUTCH.r - 10)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		if isOpen(x, z) then
			eggs(x, 0, z, rng:NextInteger(3, 7), clutch, true)
		end
	end
	-- egg sacs hanging from the vault in silk bags
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(6, CLUTCH.r - 14)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local top = ceilAt(x, z)
		local len = rng:NextNumber(8, 18)
		decor(beam("Strand", V(x, top, z), V(x, top - len, z), 0.12, THREAD, webs)).Transparency = 0.25
		eggs(x, top - len - 3.5, z, 3, clutch, true)
	end
	for _ = 1, 12 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(8, CLUTCH.r - 12)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		if isOpen(x, z) then
			spiderModel(at(x, 0, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(0.35, 0.55), clutch)
		end
	end
	-- a tipped cart spilling wool: the miners fled
	minecart(at(cx + 30, 0, cz + 28) * CFrame.Angles(0, 0.6, 0), clutch, true)
	for _ = 1, 5 do
		textured(part("SpilledWool", Vector3.new(2, 2, 2), at(cx + 30 + rng:NextNumber(-5, 5), 1, cz + 33 + rng:NextNumber(-3, 3)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, clutch), "px_white_wool")
	end
	-- glowing cave mushrooms
	for _ = 1, 14 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(CLUTCH.r * 0.6, CLUTCH.r - 4)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		if isOpen(x, z) then
			local h = rng:NextNumber(1.2, 3)
			part("MushroomStem", Vector3.new(0.6, h, 0.6), at(x, h / 2, z), Color3.fromRGB(220, 220, 200), nil, clutch)
			local cap = part("MushroomCap", Vector3.new(2.4, 0.7, 2.4), at(x, h + 0.3, z), Color3.fromRGB(110, 230, 200), Enum.Material.Neon, clutch)
			cap.Transparency = 0.2
		end
	end
	zoneSign(-104, 80, "Кладка", math.rad(-50))
end
task.wait()

-- ================================================================ the Cocoon graveyard (east): wrapped prisoners, bones, rusty gear
local graveyard = folder("CocoonGraveyard")
do
	local cx, cz = COCOONS.x, COCOONS.z
	for _ = 1, 22 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, COCOONS.r - 12)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		local top = ceilAt(x, z)
		local len = rng:NextNumber(4, 16)
		local size = rng:NextNumber(5, 6.5)
		decor(beam("Strand", V(x, top, z), V(x, top - len, z), 0.14, THREAD, webs)).Transparency = 0.2
		cocoon(at(x, top - len - size / 2, z) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15)), size, graveyard)
	end
	for _ = 1, 10 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(6, COCOONS.r - 8)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		if isOpen(x, z) then
			cocoon(at(x, 1.1, z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.pi / 2), rng:NextNumber(4.5, 6), graveyard)
		end
	end
	for _ = 1, 18 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(4, COCOONS.r - 6)
		local x, z = cx + math.sin(a) * r, cz + math.cos(a) * r
		if isOpen(x, z) then
			bones(x, z, graveyard)
		end
	end
	-- the prisoners' things: a broken cart, pickaxes stuck in the ground, an old chest under webs
	minecart(at(cx - 26, 0, cz - 22) * CFrame.Angles(0, -0.5, 0), graveyard, false)
	for _ = 1, 6 do
		local x, z = cx + rng:NextNumber(-34, 34), cz + rng:NextNumber(-34, 34)
		if isOpen(x, z) then
			local tilt = CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4))
			decor(part("StuckPickHandle", Vector3.new(0.35, 3.2, 0.35), at(x, 1.4, z) * tilt, Color3.fromRGB(110, 80, 50), Enum.Material.Wood, graveyard))
			decor(part("StuckPickHead", Vector3.new(2.4, 0.4, 0.4), at(x, 1.4, z) * tilt * CFrame.new(0, 1.5, 0), RUST, Enum.Material.Metal, graveyard))
		end
	end
	local chest = textured(part("OldChest", Vector3.new(3.6, 2.6, 2.6), at(cx + 20, 1.3, cz - 30) * CFrame.Angles(0, 0.3, 0), nil, nil, graveyard), "px_spruce_planks")
	decor(part("ChestLock", Vector3.new(0.6, 0.8, 0.2), chest.CFrame * CFrame.new(0, 0.3, -1.35), IRON, Enum.Material.Metal, graveyard))
	orbWeb(chest.CFrame * CFrame.new(0, 1.6, -1.4), 3, 6, 3, webs, 0, math.pi)
	-- a pale glow: lichen on the floor
	for _ = 1, 6 do
		local x, z = cx + rng:NextNumber(-30, 30), cz + rng:NextNumber(-30, 30)
		if isOpen(x, z) then
			local l = decor(part("Lichen", Vector3.new(rng:NextNumber(3, 6), 0.1, rng:NextNumber(3, 6)), at(x, 0.06, z), Color3.fromRGB(120, 200, 160), Enum.Material.Neon, graveyard))
			l.Transparency = 0.5
			light(l, 20, 0.8, Color3.fromRGB(150, 230, 190))
		end
	end
	zoneSign(104, 80, "Кладбище коконов", math.rad(50))
end
task.wait()

-- ================================================================ the Queen's nest (the arena)
local arena = folder("QueensNest")
do
	local ax, az, R = ARENA.x, ARENA.z, ARENA.r
	-- the giant floor web over the whole arena
	orbWeb(at(ax, 0.08, az) * CFrame.Angles(-math.pi / 2, 0, 0), R - 10, 16, 9, webs)
	-- six stone columns from floor to vault, wrapped in silk (the charge stuns on them: names Pillar*)
	local tops = {}
	for k = 0, 5 do
		local a = (k + 0.5) / 6 * math.pi * 2
		local px, pz = ax + math.sin(a) * 48, az + math.cos(a) * 48
		local top = ceilAt(px, pz)
		local cf = at(px, 0, pz) * CFrame.Angles(0, a, 0)
		textured(part("PillarBase", Vector3.new(10, 3, 10), cf * CFrame.new(0, 1.5, 0), nil, nil, arena), "px_mossy_cobblestone", ROCK)
		textured(part("Pillar", Vector3.new(7, top, 7), cf * CFrame.new(0, top / 2, 0), nil, nil, arena), "px_stone", ROCK)
		textured(part("PillarFlare", Vector3.new(10, 6, 10), cf * CFrame.new(0, top - 3, 0), nil, nil, arena), "px_stone", VAULT)
		-- silk wrapping: pale bands up the column, a sheet from the column to the vault
		for y = 6, top - 10, 7 do
			local band = decor(part("SilkWrap", Vector3.new(7.4, rng:NextNumber(1, 2.4), 7.4), cf * CFrame.new(0, y, 0) * CFrame.Angles(rng:NextNumber(-0.12, 0.12), rng:NextNumber(0, 1), rng:NextNumber(-0.12, 0.12)), SILK, Enum.Material.Fabric, arena))
			band.Transparency = 0.35
		end
		eggs(px + math.sin(a) * 6, 0, pz + math.cos(a) * 6, 4, arena, true)
		if k % 2 == 0 then
			cocoon(cf * CFrame.new(0, 14, -4.3) * CFrame.Angles(0.1, 0, 0), 5.5, arena)
		end
		table.insert(tops, V(px, top - 14, pz))
	end
	-- orb webs strung high between neighbouring columns (except over the way in)
	for k = 1, 6 do
		local a, b = tops[k], tops[k % 6 + 1]
		local mid = (a + b) / 2
		local span = (b - a).Magnitude
		orbWeb(CFrame.lookAt(mid, mid + (b - a):Cross(Vector3.yAxis)), math.min(span / 2 - 2, 20), 10, 6, webs)
	end
	-- the funnel web in the vault: rings descending into a tube over the centre
	local vtop = ceilAt(ax, az)
	local prev
	for k = 0, 7 do
		local r = 40 - k * 4.6
		local y = vtop - 2 - k * 2.4
		local pts = {}
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			table.insert(pts, V(ax + math.sin(a) * r, y, az + math.cos(a) * r))
		end
		for i = 1, 16 do
			decor(beam("FunnelThread", pts[i], pts[i % 16 + 1], 0.2, THREAD, webs)).Transparency = 0.3
			if prev then
				decor(beam("FunnelSpoke", prev[i], pts[i], 0.2, THREAD, webs)).Transparency = 0.3
			end
		end
		prev = pts
	end
	for i = 1, 16 do
		local a = (i - 1) / 16 * math.pi * 2
		decor(beam("FunnelSpoke", V(ax + math.sin(a) * 40, vtop - 2, az + math.cos(a) * 40), V(ax + math.sin(a) * 70, ceilAt(ax + math.sin(a) * 70, az + math.cos(a) * 70), az + math.cos(a) * 70), 0.2, THREAD, webs)).Transparency = 0.3
	end
	-- the nest at the back (north): a mound of silk and eggs, wrapped victims, bones
	local nx, nz = ax, az - 58
	for k = 0, 3 do
		local s = 26 - k * 6
		textured(part("NestMound", Vector3.new(s, 2.4, s * 0.8), at(nx, 1.2 + k * 2.4, nz) * CFrame.Angles(0, k * 0.3, 0), nil, nil, arena), "px_white_wool", Color3.fromRGB(200, 196, 186))
	end
	eggs(nx, 9.6, nz, 9, arena, true)
	eggs(nx - 9, 0, nz + 4, 6, arena, true)
	eggs(nx + 10, 0, nz + 3, 6, arena, true)
	for _, d in ipairs({ { -14, -2, 0.4 }, { 14, -4, -0.3 }, { -6, -9, 1.2 }, { 7, -10, -1 } }) do
		cocoon(at(nx + d[1], 3.2, nz + d[2]) * CFrame.Angles(0.3, d[3], 0.2), 6, arena)
	end
	for _ = 1, 8 do
		bones(nx + rng:NextNumber(-20, 20), nz + rng:NextNumber(-6, 14), arena)
	end
	orbWeb(CFrame.lookAt(V(nx, 16, nz - 8), V(nx, 16, nz + 10)), 16, 12, 7, webs)
	-- the gate from the main passage: two curved fangs over the way in, a sign, two great spider statues
	local gz = az + R - 4
	for _, s in ipairs({ -1, 1 }) do
		local prevP = V(ax + s * 15, 0, gz)
		for k = 1, 6 do
			local t = k / 6
			local p = V(ax + s * (15 - 11 * t ^ 1.6), 24 * math.sin(t * math.pi / 2) + 0.5, gz)
			beam("GateFang", prevP, p, 3.2 - t * 1.8, BONE, arena)
			prevP = p
		end
		spiderModel(at(ax + s * 24, 1, gz - 10) * CFrame.Angles(0, if s < 0 then 0.5 else -0.5, 0), 2.3, arena)
		textured(part("StatuePlinth", Vector3.new(14, 1, 14), at(ax + s * 24, 0.5, gz - 9), nil, nil, arena), "px_cobblestone", ROCK)
	end
	local gateSign = textured(decor(part("ArenaSign", Vector3.new(14, 2, 0.3), at(ax, 27.5, gz), nil, nil, arena)), "px_dark_oak_planks")
	boardText(gateSign, "Гнездо матки", Color3.fromRGB(220, 60, 60), { Enum.NormalId.Back, Enum.NormalId.Front })
	-- light: a pale green glow from the nest, a little from the vault over the centre
	local nestGlow = decor(part("NestGlow", Vector3.new(1, 1, 1), at(nx, 14, nz), GLOW, nil, arena))
	nestGlow.Transparency = 1
	light(nestGlow, 60, 1.2, Color3.fromRGB(170, 255, 150))
	local dust = decor(part("ArenaDust", Vector3.new(120, 1, 120), at(ax, vtop - 6, az), THREAD, nil, arena))
	dust.Transparency = 1
	emitter(dust, {
		Color = ColorSequence.new(Color3.fromRGB(230, 230, 230)),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.18),
		Transparency = NumberSequence.new(0.4),
		Rate = 14,
		Lifetime = NumberRange.new(10, 16),
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(20, 20),
	})
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(ax, 1.2, az), nil, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "spider_queen")
	bossSpawn:SetAttribute("ArenaRadius", R - 8)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
	zoneSign(-12, -100, "Гнездо матки", 0)
end
task.wait()

-- ================================================================ big sleeping spiders by the chamber walls (off the ways)
for _, p in ipairs({ { -64, 196, 1.6 }, { 104, 150, 1.3 }, { -200, 0, 1.2 }, { 200, -40, 1.4 }, { 40, -160, 1.2 } }) do
	if isOpen(p[1], p[2]) then
		spiderModel(at(p[1], 0, p[2]) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), p[3], props)
	end
end

-- ================================================================ the murk: a dim cold light, a grey haze
-- [клиент: окутано мраком] dark, but the white mine and the ways must read (raised Ambient, see the lighting notes)
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(part("LairAir", Vector3.new(560, 140, 600), at(0, 40, -10), nil, nil, air))
volume.Transparency = 1
volume:SetAttribute("Ambient", Color3.fromRGB(150, 146, 162))
volume:SetAttribute("Exposure", 0.15)
volume:SetAttribute("Haze", 0.3)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(44, 46, 50))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(22, 24, 26))
CollectionService:AddTag(volume, "IndoorLighting")
-- dust motes over the adit
local motes = decor(part("Motes", Vector3.new(200, 1, 200), at(ENTRY.x, 40, ENTRY.z), THREAD, nil, air))
motes.Transparency = 1
emitter(motes, {
	Color = ColorSequence.new(Color3.fromRGB(220, 220, 210)),
	LightEmission = 0.2,
	Size = NumberSequence.new(0.15),
	Transparency = NumberSequence.new(0.5),
	Rate = 10,
	Lifetime = NumberRange.new(10, 16),
	Speed = NumberRange.new(0.5, 1.5),
	EmissionDirection = Enum.NormalId.Bottom,
	SpreadAngle = Vector2.new(40, 40),
})

-- webs never shadow; egg sacs never block (they lie in clusters all over the ways)
for _, d in ipairs(webs:GetDescendants()) do
	if d:IsA("BasePart") then
		d.CastShadow = false
	end
end
for _, d in ipairs(root:GetDescendants()) do
	if d:IsA("BasePart") and (d.Name == "EggSac" or d.Name == "EggShell") then
		decor(d)
	end
end

-- lift the location to its own height
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
print(("[build-spider-lair] built: %d instances (runs %d)"):format(total, count))
return ("built %d instances, runs %d"):format(total, count)
