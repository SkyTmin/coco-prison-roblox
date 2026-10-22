--!nocheck
-- Builds the Пирамида, level 9, PvP [меню]. «Гробница фараона мрачна и заброшена, внутри тлеет древнее проклятие,
-- способное коснуться каждого» [меню]. Blocks: песчаник 61 %, красный песчаник 39 % [меню]. Boss: Скелетон —
-- «павший предводитель навеки забытой армии» [клиент], his minions «Скелет-воин» [клиент].
-- [владелец 23.10: «следующая локация с такой же мощностью»] The plan:
--   * a desert valley closed by red sandstone mesas, dunes on an 8-stud grid; the convicts' oasis (arrival) in the
--     south, an avenue of obelisks and lions to the gate pylons of a great stepped pyramid (22 steps of 8 studs);
--   * inside the pyramid (carved out of the step layers): the grand gallery with hieroglyph walls and torches →
--     the mine hall (papyrus columns, giant seated pharaohs, braziers on chains, the mine 32×12×32 in the middle);
--   * from the hall a stair goes down to the tomb under the pyramid: the arena of the Скелетон (a starry blue
--     ceiling, statues of the forgotten army in niches, the sarcophagus, four pillars, blue cursed fire);
--   * outside: the field of the forgotten army (half-buried skeletons, swords, standards), a ruined temple, a
--     necropolis of mastabas behind the pyramid; every name stands at its place.
-- A separate zone at X = 4400 (StreamingEnabled). Run in Studio (Edit) via scripts/studio-loader.luau after
-- build-textures. Idempotent: replaces Workspace.Pyramid. Arrival: LocationSpawn, LocationId "pyramid".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("Pyramid")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Pyramid"
root:SetAttribute("LocationId", "pyramid")
root:SetAttribute("SilentSteps", true) -- [владелец 23.10] no step sounds here (Footsteps)
root.Parent = workspace

local BX, BZ = 4400, 15000 -- [владелец 23.10: «вижу соседние локации»] 5000 studs from any other location: beyond streaming and haze
local B = 4
local rng = Random.new(20261023)
local STONE = Color3.fromRGB(220, 200, 150)
local IRON = Color3.fromRGB(60, 56, 52)
local WOOD = Color3.fromRGB(120, 85, 50)
local CANVAS = Color3.fromRGB(230, 214, 178)
local BONE = Color3.fromRGB(226, 220, 198)
local GOLD = Color3.fromRGB(240, 190, 60)
local LAPIS = Color3.fromRGB(40, 76, 160)
local LAMP = Color3.fromRGB(255, 180, 100)
local CURSE = Color3.fromRGB(110, 220, 255)

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
local LIGHT_POWER, LIGHT_RANGE = 0.35, 0.6
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
-- the hieroglyph panel: our own glyph sheet (3 × 3 glyphs, one glyph = one block) as a Texture on a face
local function glyphs(p, face, tile)
	if TEX.hieroglyphs then
		local t = Instance.new("Texture")
		t.Texture = TEX.hieroglyphs
		t.Face = face
		t.StudsPerTileU, t.StudsPerTileV = tile or 3 * B, tile or 3 * B
		t.Parent = p
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
		gui.LightInfluence = 0.5
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(90, 60, 30)
		label.TextStrokeTransparency = 1
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
local function torch(x, y, z, cursed, parent)
	part("TorchStick", Vector3.new(0.4, 1.6, 0.4), at(x, y - 0.6, z), WOOD, Enum.Material.Wood, parent)
	local flame = decor(part("TorchFlame", Vector3.new(0.6, 0.6, 0.6), at(x, y + 0.4, z), if cursed then CURSE else LAMP, Enum.Material.Neon, parent))
	local f = Instance.new("Fire")
	f.Size = 2
	f.Heat = 5
	if cursed then
		f.Color = Color3.fromRGB(90, 210, 255)
		f.SecondaryColor = Color3.fromRGB(40, 110, 255)
	end
	f.Parent = flame
	light(flame, 22, 1.3, if cursed then Color3.fromRGB(120, 210, 255) else Color3.fromRGB(255, 170, 90))
	return flame
end
local function brazier(x, y, z, cursed, parent)
	textured(part("BrazierFoot", Vector3.new(1.4, 3, 1.4), at(x, y + 1.5, z), STONE, nil, parent), "px_cut_sandstone")
	local bowl = part("BrazierBowl", Vector3.new(3.2, 1.2, 3.2), at(x, y + 3.6, z), GOLD, Enum.Material.Metal, parent)
	local coals = decor(part("BrazierFire", Vector3.new(2.6, 0.3, 2.6), bowl.CFrame * CFrame.new(0, 0.6, 0), if cursed then CURSE else Color3.fromRGB(255, 120, 40), Enum.Material.Neon, parent))
	local f = Instance.new("Fire")
	f.Size = 4
	f.Heat = 8
	if cursed then
		f.Color = Color3.fromRGB(90, 210, 255)
		f.SecondaryColor = Color3.fromRGB(40, 110, 255)
	end
	f.Parent = coals
	light(coals, 32, 1.6, if cursed then Color3.fromRGB(120, 210, 255) else Color3.fromRGB(255, 160, 80))
end

-- ================================================================ the plan
local R = 300 -- the desert valley radius (mesas beyond)
local PYR = { x = 0, z = -40, half = 176, layers = 22 } -- 22 steps of 8 × 8 studs, top at y 176
local PIT = { x = 0, z = -40, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json pyramid.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local HALL = { x0 = -104, x1 = 104, z0 = -136, z1 = 56, y1 = 48 }
local GALLERY = { x0 = -8, x1 = 8, z0 = 56, z1 = 140, y1 = 24 }
local STAIR = { x0 = -8, x1 = 8, z0 = -184, z1 = -136, bottom = -32 } -- from the hall floor (z −136) down north
local CRYPT = { x0 = -44, x1 = 44, z0 = -264, z1 = -188, floor = -32, ceil = -8 } -- the tomb (arena) interior
local CAMP = { x = 0, z = 232, r = 46 }
-- the parts of the pyramid carved out (in layers): the hall, the gallery, the top of the stair passage
local CARVE = {
	{ HALL.x0, HALL.x1, HALL.z0, HALL.z1, 0, HALL.y1 },
	{ GALLERY.x0, GALLERY.x1, GALLERY.z0, GALLERY.z1 + 8, 0, GALLERY.y1 },
	{ STAIR.x0, STAIR.x1, -160, STAIR.z1, 0, 16 },
}
-- [владелец 23.10: «потолок внутри тоже как пирамида, а не плоский»] over the hall the ceiling steps inwards like
-- the pyramid itself (a corbelled vault, as in the Grand Gallery): every 8-stud layer above the hall walls is
-- carved 8 studs narrower on each side, up to an apex
local HALL_APEX = HALL.y1
do
	local cz = (HALL.z0 + HALL.z1) / 2
	local hx, hz = (HALL.x1 - HALL.x0) / 2, (HALL.z1 - HALL.z0) / 2
	local j = 0
	while hx - 8 * (j + 1) >= 8 and hz - 8 * (j + 1) >= 8 do
		j += 1
		local y0 = HALL.y1 + 8 * (j - 1)
		table.insert(CARVE, { -(hx - 8 * j), hx - 8 * j, cz - (hz - 8 * j), cz + (hz - 8 * j), y0, y0 + 8 })
		HALL_APEX = y0 + 8
	end
end
-- the ceiling height over a point of the hall (for chains hung from it)
local function hallCeilingAt(x, z)
	local top = HALL.y1
	for i = 4, #CARVE do
		local b = CARVE[i]
		if x > b[1] and x < b[2] and z > b[3] and z < b[4] then
			top = math.max(top, b[6])
		end
	end
	return top
end
local TRAILS = {
	{ { -24, 220 }, { -110, 150 }, { -170, 80 }, { -200, 0 }, { -200, -200 }, { -130, -250 } }, -- the army field → the necropolis
	{ { 24, 220 }, { 110, 150 }, { 190, 70 }, { 205, 0 }, { 205, -200 }, { 130, -250 } }, -- the ruined temple → the necropolis
}
local function inAvenue(x, z)
	return math.abs(x) < 20 and z > PYR.z + PYR.half - 4 and z < CAMP.z
end
local function inPyramid(x, z, margin)
	margin = margin or 0
	return math.abs(x - PYR.x) < PYR.half + margin and math.abs(z - PYR.z) < PYR.half + margin
end
local function inVoid(x, z) -- the stair passage and the tomb are dug out of the ground under the pyramid
	return (x > -16 and x < 16 and z > STAIR.z0 and z < STAIR.z1) or (x > -48 and x < 48 and z > -272 and z < STAIR.z0)
end

-- ================================================================ the desert grid (8-stud cells)
local C = 8
local X0, Z0 = -320, -320
local NX, NZ = 80, 80
local function valleyD(x, z)
	return math.sqrt((x / R) ^ 2 + (z / R) ^ 2) / (1 + n2(x, z, 2.7, 0.012) * 0.07)
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
local function flat(x, z)
	return math.sqrt((x - CAMP.x) ^ 2 + (z - CAMP.z) ^ 2) < CAMP.r
		or inAvenue(x, z)
		or inPyramid(x, z, 16)
		or (x > -64 and x < 64 and z > -288 and z < -168) -- over the tomb
end
local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local d = valleyD(x, z)
		local c = { x = x, z = z, d = d }
		if d >= 1 then
			c.kind = "mesa"
			local t = math.clamp((d - 1) / 0.16, 0, 1)
			local h = 26 + 64 * t ^ 0.8 + n2(x, z, 4.4, 0.035) * 14
			c.top = math.max(16, 6 * math.floor(h / 6 + 0.5))
		elseif inHole(x, z) then
			c.kind = "hole"
		elseif inVoid(x, z) then
			c.kind = "void"
		else
			c.kind = "ground"
			c.path = onTrail(x, z)
			c.inside = inPyramid(x, z)
			local h = 0
			if not (flat(x, z) or c.path) then
				h = math.clamp(math.floor(n2(x, z, 3.3, 0.022) * 2.6 + n2(x, z, 6.1, 0.07) * 1.2 + 1.1), 0, 3)
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
	return if c and c.kind == "ground" then c.top else 0
end

-- ================================================================ build the desert and the mesas (runs along x)
local terrain = folder("Terrain")
local count = 0
local function floorLook(c)
	if c.inside or inAvenue(c.x, c.z) or math.sqrt((c.x - CAMP.x) ^ 2 + (c.z - CAMP.z) ^ 2) < 20 then
		return "px_cut_sandstone", nil
	elseif c.path then
		return "px_sandstone", Color3.fromRGB(230, 214, 180)
	end
	local v = n2(c.x, c.z, 7.7, 0.04) + n2(c.x, c.z, 2.9, 0.13) * 0.4
	if c.d > 0.9 or v > 0.55 then
		return "px_red_sand", Color3.fromRGB(240, 220, 200)
	elseif v < -0.5 then
		return "px_sandstone", nil
	end
	return "px_sand", nil
end
local function runner(z0, z1, parent)
	local runs = {}
	local self = {}
	function self.flush(k)
		local r = runs[k]
		if r then
			box(r.name, X0 + r.ix0 * C, r.y0, z0, X0 + (r.ix1 + 1) * C, r.y1, z1, r.variant, r.tint, parent)
			count += 1
			runs[k] = nil
		end
	end
	function self.push(ix, k, name, y0, y1, variant, tint)
		local r = runs[k]
		if r and r.ix1 == ix - 1 and r.y0 == y0 and r.y1 == y1 and r.variant == variant and r.tint == tint then
			r.ix1 = ix
			return
		end
		self.flush(k)
		runs[k] = { ix0 = ix, ix1 = ix, name = name, y0 = y0, y1 = y1, variant = variant, tint = tint }
	end
	function self.endCell(used)
		for k in pairs(runs) do
			if not used[k] then
				self.flush(k)
			end
		end
	end
	function self.finish()
		for k in pairs(runs) do
			self.flush(k)
		end
	end
	return self
end
for iz = 0, NZ - 1 do
	local z0, z1 = Z0 + iz * C, Z0 + (iz + 1) * C
	local run = runner(z0, z1, terrain)
	for ix = 0, NX - 1 do
		local c = cellAt(ix, iz)
		local used = {}
		if c.kind == "ground" then
			local v, tint = floorLook(c)
			run.push(ix, "floor", "Ground", -8, c.top, v, tint)
			used.floor = true
		elseif c.kind == "mesa" then
			local band = math.floor(c.top / 6) % 3
			run.push(ix, "mesa", "Mesa", -8, c.top - 1, "px_red_sandstone", if band == 0 then nil elseif band == 1 then Color3.fromRGB(235, 200, 180) else Color3.fromRGB(215, 175, 150))
			run.push(ix, "cap", "MesaCap", c.top - 1, c.top, "px_red_sand", nil)
			used.mesa, used.cap = true, true
		end
		run.endCell(used)
	end
	run.finish()
	if iz % 5 == 0 then
		task.wait()
	end
end

-- ================================================================ the pyramid: 22 step layers, the interior carved out
local pyramid = folder("PyramidBody")
local function carved(x, z, y0, y1)
	for _, b in ipairs(CARVE) do
		if x > b[1] and x < b[2] and z > b[3] and z < b[4] and y0 < b[6] and y1 > b[5] then
			return true
		end
	end
	return false
end
for k = 0, PYR.layers - 1 do
	local y0, y1 = k * 8, k * 8 + 8
	local half = PYR.half - k * 8
	local variant, tint = "px_cut_sandstone", nil
	if k % 5 == 4 then
		variant = "px_cut_red_sandstone"
	elseif k % 5 == 2 then
		tint = Color3.fromRGB(236, 226, 206)
	end
	for iz = 0, NZ - 1 do
		local z0, z1 = Z0 + iz * C, Z0 + (iz + 1) * C
		local zc = (z0 + z1) / 2
		if math.abs(zc - PYR.z) < half then
			local run = runner(z0, z1, pyramid)
			for ix = 0, NX - 1 do
				local xc = X0 + ix * C + C / 2
				local used = {}
				if math.abs(xc - PYR.x) < half and not carved(xc, zc, y0, y1) then
					run.push(ix, "layer", "PyramidStep", y0, y1, variant, tint)
					used.layer = true
				end
				run.endCell(used)
			end
			run.finish()
		end
	end
	task.wait()
end
-- the golden capstone
do
	local top = PYR.layers * 8
	textured(part("Capstone", Vector3.new(8, 6, 8), at(PYR.x, top + 3, PYR.z), STONE, nil, pyramid), "px_gold_block")
	textured(part("CapstoneTip", Vector3.new(4, 4, 4), at(PYR.x, top + 8, PYR.z), STONE, nil, pyramid), "px_gold_block")
	local beacon = decor(part("CapstoneGlow", Vector3.new(1, 1, 1), at(PYR.x, top + 11, PYR.z), GOLD, Enum.Material.Neon, pyramid))
	light(beacon, 60, 1.5, Color3.fromRGB(255, 210, 120))
end

-- ================================================================ the gate pylons and the avenue of obelisks and lions
local avenue = folder("Avenue")
local function obelisk(x, z, h)
	local y = floorAt(x, z)
	textured(part("ObeliskBase", Vector3.new(6, 2, 6), at(x, y + 1, z), STONE, nil, avenue), "px_cut_red_sandstone")
	local shaft = textured(part("Obelisk", Vector3.new(3.6, h, 3.6), at(x, y + 2 + h / 2, z), STONE, nil, avenue), "px_cut_sandstone")
	for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right, Enum.NormalId.Front, Enum.NormalId.Back }) do
		glyphs(shaft, face, 3.6)
	end
	textured(part("ObeliskTip", Vector3.new(2.6, 2.4, 2.6), at(x, y + 3.2 + h, z), STONE, nil, avenue), "px_gold_block")
	textured(part("ObeliskTipTop", Vector3.new(1.4, 1.4, 1.4), at(x, y + 5, z + 0) + Vector3.new(0, h, 0), STONE, nil, avenue), "px_gold_block")
end
-- a lion lying on a plinth, blocky, facing the avenue (our own design)
local function lion(x, z, yaw, s)
	local y = floorAt(x, z)
	local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local function b(name, size, off, variant, tint)
		return textured(part(name, size * s, base * CFrame.new(off[1] * s, off[2] * s, off[3] * s), STONE, nil, avenue), variant or "px_cut_sandstone", tint)
	end
	b("LionPlinth", Vector3.new(4.4, 1.2, 8.6), { 0, 0.6, 0 }, "px_cut_red_sandstone")
	b("LionBody", Vector3.new(3, 2, 6), { 0, 2.2, 0.6 })
	b("LionHaunch", Vector3.new(3.4, 2.4, 2.4), { 0, 2.4, 3 })
	b("LionPaw", Vector3.new(1, 0.8, 2.4), { -1, 1.6, -3.2 })
	b("LionPaw", Vector3.new(1, 0.8, 2.4), { 1, 1.6, -3.2 })
	b("LionChest", Vector3.new(2.8, 2.6, 1.6), { 0, 2.8, -2.2 })
	b("LionHead", Vector3.new(2.4, 2.4, 2.2), { 0, 4.6, -2.4 })
	b("LionMane", Vector3.new(3.4, 3, 1.2), { 0, 4.4, -1.4 }, "px_cut_sandstone", Color3.fromRGB(230, 200, 140))
	b("LionNemesL", Vector3.new(0.6, 2.4, 1.6), { -1.5, 3.8, -2.2 }, "px_terracotta_blue")
	b("LionNemesR", Vector3.new(0.6, 2.4, 1.6), { 1.5, 3.8, -2.2 }, "px_terracotta_blue")
	b("LionMuzzle", Vector3.new(1.2, 0.9, 0.6), { 0, 4.1, -3.7 })
	b("LionTail", Vector3.new(0.5, 0.5, 2.6), { 0.9, 1.8, 4.6 })
	for _, sx in ipairs({ -0.6, 0.6 }) do
		decor(part("LionEye", Vector3.new(0.4, 0.25, 0.1) * s, base * CFrame.new(sx * s, 5 * s, -3.52 * s), Color3.fromRGB(60, 40, 30), nil, avenue))
	end
end
do
	local gz = PYR.z + PYR.half -- the south face at the ground (z 136)
	-- the paved avenue edges
	for _, s in ipairs({ -1, 1 }) do
		textured(part("AvenueKerb", Vector3.new(1, 0.8, CAMP.z - 20 - gz), at(s * 9, 0.4, (gz + CAMP.z - 20) / 2), STONE, nil, avenue), "px_cut_red_sandstone")
	end
	-- obelisks every 16 studs, two lions at the gate
	for z = gz + 24, CAMP.z - 30, 16 do
		obelisk(-14, z, 16)
		obelisk(14, z, 16)
	end
	lion(-16, gz + 14, math.pi, 1.6)
	lion(16, gz + 14, math.pi, 1.6)
	-- the gate pylons: two stepped towers either side of the gallery mouth, glyph faces, blue-gold bands
	for _, s in ipairs({ -1, 1 }) do
		local px = s * 22
		for k = 0, 3 do
			local w = 24 - k * 2
			local p = textured(part("Pylon", Vector3.new(w, 9, 12 - k), at(px, 4.5 + k * 9, gz + 6), STONE, nil, avenue), "px_cut_sandstone")
			glyphs(p, Enum.NormalId.Back, 3 * B)
		end
		textured(part("PylonCornice", Vector3.new(19, 2, 10), at(px, 37, gz + 6), STONE, nil, avenue), "px_cut_red_sandstone")
		textured(part("PylonBand", Vector3.new(19.4, 1.2, 10.4), at(px, 33.6, gz + 6), STONE, nil, avenue), "px_terracotta_blue")
		textured(part("PylonBandGold", Vector3.new(19.6, 0.5, 10.6), at(px, 32.7, gz + 6), STONE, nil, avenue), "px_gold_block")
		-- a tall banner pole with a blue-gold banner
		part("BannerPole", Vector3.new(0.6, 34, 0.6), at(px + s * -9, 17, gz + 12.6), WOOD, Enum.Material.Wood, avenue)
		decor(part("Banner", Vector3.new(0.15, 12, 4), at(px + s * -9, 26, gz + 14.8), LAPIS, Enum.Material.Fabric, avenue))
		decor(part("BannerGold", Vector3.new(0.17, 12, 0.8), at(px + s * -9, 26, gz + 14.8), GOLD, Enum.Material.Fabric, avenue))
	end
	-- the gateway between the pylons: a lintel with the carved name, glyph jambs
	for _, s in ipairs({ -1, 1 }) do
		local jamb = textured(part("GateJamb", Vector3.new(4, 24, 6), at(s * 10, 12, gz + 3), STONE, nil, avenue), "px_cut_sandstone")
		glyphs(jamb, Enum.NormalId.Back, 3 * B)
	end
	local lintel = textured(part("GateLintel", Vector3.new(24, 5, 7), at(0, 26.5, gz + 3), STONE, nil, avenue), "px_cut_red_sandstone")
	local nameBoard = textured(decor(part("GateName", Vector3.new(18, 3, 0.3), at(0, 26.5, gz + 6.65), STONE, nil, avenue)), "px_cut_sandstone")
	boardText(nameBoard, "Гробница фараона", Color3.fromRGB(110, 60, 20), { Enum.NormalId.Back })
	textured(part("GateSunDisc", Vector3.new(4, 4, 0.6), at(0, 30.5, gz + 6.4), STONE, nil, avenue), "px_gold_block")
	for _, s in ipairs({ -1, 1 }) do
		textured(part("GateWing", Vector3.new(5, 1.4, 0.4), at(s * 4.6, 30.6, gz + 6.5) * CFrame.Angles(0, 0, s * -0.12), STONE, nil, avenue), "px_terracotta_blue")
	end
	_ = lintel
end
task.wait()

-- ================================================================ the grand gallery (inside)
local inside = folder("Interior")
do
	local g = GALLERY
	-- glyph walls on both sides, torches every 12 studs, a painted band, roof beams
	for _, s in ipairs({ -1, 1 }) do
		local wx = if s < 0 then g.x0 else g.x1
		local wall = textured(decor(part("GalleryGlyphs", Vector3.new(0.2, 12, g.z1 - g.z0 - 2), at(wx - s * 0.1, 8, (g.z0 + g.z1) / 2), STONE, nil, inside)), "px_cut_sandstone")
		glyphs(wall, if s < 0 then Enum.NormalId.Right else Enum.NormalId.Left, 3 * B)
		textured(decor(part("GalleryBand", Vector3.new(0.3, 1.6, g.z1 - g.z0), at(wx - s * 0.15, 16, (g.z0 + g.z1) / 2), STONE, nil, inside)), "px_terracotta_blue")
		textured(decor(part("GalleryBandGold", Vector3.new(0.32, 0.5, g.z1 - g.z0), at(wx - s * 0.16, 15, (g.z0 + g.z1) / 2), STONE, nil, inside)), "px_gold_block")
		for z = g.z0 + 6, g.z1 - 6, 12 do
			torch(wx - s * 0.8, 11, z, false, inside)
		end
	end
	for z = g.z0 + 4, g.z1 - 4, 8 do
		textured(part("GalleryBeam", Vector3.new(g.x1 - g.x0, 1.2, 1.4), at(0, g.y1 - 0.6, z), STONE, nil, inside), "px_cut_red_sandstone")
	end
	-- a red runner on the floor and dust in the air
	decor(part("GalleryCarpet", Vector3.new(6, 0.1, g.z1 - g.z0 - 4), at(0, 0.06, (g.z0 + g.z1) / 2), Color3.fromRGB(140, 40, 34), Enum.Material.Fabric, inside))
	local dust = decor(part("GalleryDust", Vector3.new(14, 1, g.z1 - g.z0), at(0, 20, (g.z0 + g.z1) / 2), STONE, nil, inside))
	dust.Transparency = 1
	emitter(dust, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(220, 200, 160)),
		Size = NumberSequence.new(0.2),
		Transparency = NumberSequence.new(0.5),
		Rate = 12,
		Lifetime = NumberRange.new(8, 12),
		Speed = NumberRange.new(0.5, 1.5),
		EmissionDirection = Enum.NormalId.Bottom,
		SpreadAngle = Vector2.new(60, 60),
	})
end

-- ================================================================ the mine hall: columns, pharaohs, braziers, the mine
local mine = folder("Mine")
-- a giant seated pharaoh against a wall (our own blocky design): throne, legs, hands on knees, nemes headdress
local function pharaoh(x, z, yaw, s)
	local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function b(name, size, off, variant, tint)
		return textured(part(name, size * s, base * CFrame.new(off[1] * s, off[2] * s, off[3] * s), STONE, nil, inside), variant or "px_cut_sandstone", tint)
	end
	b("PharaohPlinth", Vector3.new(8, 2, 9), { 0, 1, 0 }, "px_cut_red_sandstone")
	b("PharaohThrone", Vector3.new(7, 6, 3), { 0, 5, 3 })
	b("PharaohSeat", Vector3.new(6, 1.6, 5), { 0, 5.8, 0.4 })
	b("PharaohShin", Vector3.new(1.8, 4, 1.8), { -1.4, 4, -1.6 })
	b("PharaohShin", Vector3.new(1.8, 4, 1.8), { 1.4, 4, -1.6 })
	b("PharaohFoot", Vector3.new(1.8, 0.8, 2.6), { -1.4, 2.4, -2 })
	b("PharaohFoot", Vector3.new(1.8, 0.8, 2.6), { 1.4, 2.4, -2 })
	b("PharaohThigh", Vector3.new(1.9, 1.8, 4), { -1.4, 7.4, -0.6 })
	b("PharaohThigh", Vector3.new(1.9, 1.8, 4), { 1.4, 7.4, -0.6 })
	b("PharaohKilt", Vector3.new(4.6, 1.4, 2.6), { 0, 7.2, 0.6 }, "px_cut_sandstone", Color3.fromRGB(245, 235, 210))
	b("PharaohTorso", Vector3.new(4.2, 5, 2.4), { 0, 10.4, 1 })
	b("PharaohArm", Vector3.new(1.3, 4.2, 1.4), { -2.8, 10, 0.8 })
	b("PharaohArm", Vector3.new(1.3, 4.2, 1.4), { 2.8, 10, 0.8 })
	b("PharaohHand", Vector3.new(1.3, 1, 2.6), { -2.4, 8.4, -1.4 })
	b("PharaohHand", Vector3.new(1.3, 1, 2.6), { 2.4, 8.4, -1.4 })
	b("PharaohCollar", Vector3.new(4.6, 1, 2.6), { 0, 12.6, 0.9 }, "px_terracotta_blue")
	b("PharaohHead", Vector3.new(2.6, 3, 2.6), { 0, 14.6, 0.8 })
	b("PharaohNemes", Vector3.new(4, 3.4, 2.8), { 0, 15, 1.4 }, "px_terracotta_blue")
	b("PharaohNemesTop", Vector3.new(3, 1, 2.8), { 0, 16.9, 1.2 }, "px_gold_block")
	for _, sx in ipairs({ -1, 1 }) do
		b("PharaohLappet", Vector3.new(1, 3.2, 1.2), { sx * 1.7, 12.8, -0.2 }, "px_gold_block")
	end
	b("PharaohBeard", Vector3.new(0.7, 1.6, 0.7), { 0, 12.6, -0.6 }, "px_gold_block")
	b("PharaohCobra", Vector3.new(0.6, 1.2, 0.5), { 0, 16.6, -0.3 }, "px_gold_block")
	for _, sx in ipairs({ -0.6, 0.6 }) do
		decor(part("PharaohEye", Vector3.new(0.6, 0.3, 0.1) * s, base * CFrame.new(sx * s, 15 * s, -0.52 * s), Color3.fromRGB(30, 30, 40), nil, inside))
	end
end
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	local function bedrock(p)
		textured(p, "px_sandstone", Color3.fromRGB(170, 150, 120))
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
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], STONE, nil, mine), "px_cut_red_sandstone")
	end
	-- a low balustrade round the pit, with gaps at the middle of each side
	for _, s in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			local a, b = 8, edge - 2
			textured(part("Balustrade", Vector3.new(b - a, 2.4, 1), at(mx + half * (a + b) / 2, 1.8, mz + s * edge), STONE, nil, mine), "px_cut_sandstone")
			textured(part("Balustrade", Vector3.new(1, 2.4, b - a), at(mx + s * edge, 1.8, mz + half * (a + b) / 2), STONE, nil, mine), "px_cut_sandstone")
			textured(part("BalustradeTop", Vector3.new(b - a, 0.5, 1.4), at(mx + half * (a + b) / 2, 3.2, mz + s * edge), STONE, nil, mine), "px_cut_red_sandstone")
			textured(part("BalustradeTop", Vector3.new(1.4, 0.5, b - a), at(mx + s * edge, 3.2, mz + half * (a + b) / 2), STONE, nil, mine), "px_cut_red_sandstone")
		end
	end
	local anchor = part("MineAnchor_pyramid", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), STONE, nil, mine)
	anchor:SetAttribute("LocationId", "pyramid")
	anchor:SetAttribute("MineId", "pyramid")
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
	-- papyrus columns in two rows along the long sides: a round shaft, a blue-gold band, a flared capital
	for _, s in ipairs({ -1, 1 }) do
		for z = HALL.z0 + 16, HALL.z1 - 16, 24 do
			local x = s * 90
			textured(part("ColumnBase", Vector3.new(9, 2, 9), at(x, 1, z), STONE, nil, inside), "px_cut_red_sandstone")
			local shaft = part("Column", Vector3.new(HALL.y1 - 6, 7, 7), at(x, 2 + (HALL.y1 - 6) / 2, z) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, inside)
			shaft.Shape = Enum.PartType.Cylinder
			textured(shaft, "px_cut_sandstone")
			for _, y in ipairs({ 10, 32 }) do
				local band = part("ColumnBand", Vector3.new(1.6, 7.3, 7.3), at(x, y, z) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, inside)
				band.Shape = Enum.PartType.Cylinder
				textured(band, "px_terracotta_blue")
				local gold = part("ColumnGold", Vector3.new(0.5, 7.4, 7.4), at(x, y + 1, z) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, inside)
				gold.Shape = Enum.PartType.Cylinder
				textured(gold, "px_gold_block")
			end
			textured(part("ColumnCapital", Vector3.new(10, 4, 10), at(x, HALL.y1 - 2, z), STONE, nil, inside), "px_cut_red_sandstone")
		end
	end
	-- the hall walls: a hieroglyph frieze all round, blue-gold bands, torches
	for _, w in ipairs({
		{ (HALL.x0 + HALL.x1) / 2, HALL.z0 + 0.1, HALL.x1 - HALL.x0, true, Enum.NormalId.Back },
		{ (HALL.x0 + HALL.x1) / 2, HALL.z1 - 0.1, HALL.x1 - HALL.x0, true, Enum.NormalId.Front },
		{ HALL.x0 + 0.1, (HALL.z0 + HALL.z1) / 2, HALL.z1 - HALL.z0, false, Enum.NormalId.Right },
		{ HALL.x1 - 0.1, (HALL.z0 + HALL.z1) / 2, HALL.z1 - HALL.z0, false, Enum.NormalId.Left },
	}) do
		local size = if w[4] then Vector3.new(w[3], 12, 0.2) else Vector3.new(0.2, 12, w[3])
		local frieze = textured(decor(part("HallGlyphs", size, at(w[1], 24, w[2]), STONE, nil, inside)), "px_cut_sandstone")
		glyphs(frieze, w[5], 3 * B)
		local band = if w[4] then Vector3.new(w[3], 1.6, 0.3) else Vector3.new(0.3, 1.6, w[3])
		textured(decor(part("HallBand", band, at(w[1], 31, w[2]), STONE, nil, inside)), "px_terracotta_blue")
		textured(decor(part("HallBand", band, at(w[1], 17, w[2]), STONE, nil, inside)), "px_terracotta_blue")
	end
	for z = HALL.z0 + 12, HALL.z1 - 12, 24 do
		torch(HALL.x0 + 0.9, 11, z, false, inside)
		torch(HALL.x1 - 0.9, 11, z, false, inside)
	end
	-- braziers hanging on chains from the ceiling over the pit corners, and standing ones by the columns
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = mx + s[1] * (edge + 8), mz + s[2] * (edge + 8)
		for y = hallCeilingAt(x, z) - 1, 24, -1.6 do
			decor(part("ChainLink", Vector3.new(0.35, 1.7, 0.9), at(x, y, z) * CFrame.Angles(0, if math.floor(y) % 2 == 0 then 0 else math.pi / 2, 0), IRON, Enum.Material.Metal, inside))
		end
		local bowl = part("HangingBowl", Vector3.new(4, 1.4, 4), at(x, 22.4, z), GOLD, Enum.Material.Metal, inside)
		local coals = decor(part("HangingFire", Vector3.new(3.2, 0.3, 3.2), bowl.CFrame * CFrame.new(0, 0.7, 0), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, inside))
		local f = Instance.new("Fire")
		f.Size = 5
		f.Heat = 9
		f.Parent = coals
		light(coals, 46, 1.8, Color3.fromRGB(255, 160, 80))
	end
	for _, s in ipairs({ -1, 1 }) do
		for z = HALL.z0 + 28, HALL.z1 - 28, 48 do
			brazier(s * 78, 0, z, false, inside)
		end
	end
	-- the great chandelier over the pit, hung from the apex of the stepped vault: a gold ring of flames
	do
		local top = hallCeilingAt(mx, mz)
		local ringY = 34
		for y = top - 1, ringY + 2, -1.6 do
			decor(part("ChainLink", Vector3.new(0.5, 1.7, 1.2), at(mx, y, mz) * CFrame.Angles(0, if math.floor(y) % 2 == 0 then 0 else math.pi / 2, 0), IRON, Enum.Material.Metal, inside))
		end
		local ring = part("ChandelierRing", Vector3.new(1, 22, 22), at(mx, ringY, mz) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal, inside)
		ring.Shape = Enum.PartType.Cylinder
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local x, z = mx + math.cos(a) * 10, mz + math.sin(a) * 10
			decor(part("ChandelierArm", Vector3.new(0.4, 0.4, 10), CFrame.lookAt(Vector3.new(BX + mx, ringY + 3, BZ + mz), Vector3.new(BX + x, ringY, BZ + z)) * CFrame.new(0, 0, -5), GOLD, Enum.Material.Metal, inside))
			local cup = part("ChandelierCup", Vector3.new(1.6, 0.8, 1.6), at(x, ringY + 0.9, z), GOLD, Enum.Material.Metal, inside)
			local flame = decor(part("ChandelierFlame", Vector3.new(1, 1, 1), cup.CFrame * CFrame.new(0, 0.9, 0), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, inside))
			local f = Instance.new("Fire")
			f.Size = 2.5
			f.Heat = 6
			f.Parent = flame
		end
		-- one broad soft light under it reaches the pit floor (48 studs down)
		local glow = decor(part("ChandelierGlow", Vector3.new(1, 1, 1), at(mx, ringY - 2, mz), Color3.fromRGB(255, 200, 120), nil, inside))
		glow.Transparency = 1
		local l = Instance.new("PointLight")
		l.Range = 60
		l.Brightness = 1.2
		l.Color = Color3.fromRGB(255, 215, 160)
		l.Shadows = false
		l.Parent = glow
	end
	-- two seated pharaohs flanking the stair door in the north wall
	pharaoh(-26, HALL.z0 + 9, math.pi, 2.2)
	pharaoh(26, HALL.z0 + 9, math.pi, 2.2)
	-- the stair door: a frame with a lintel and the cursed blue light from below
	for _, s in ipairs({ -1, 1 }) do
		textured(part("CryptDoorJamb", Vector3.new(3, 18, 3), at(s * 9.5, 9, HALL.z0 + 1.5), STONE, nil, inside), "px_cut_red_sandstone")
	end
	local doorLintel = textured(part("CryptDoorLintel", Vector3.new(22, 4, 3.4), at(0, 18, HALL.z0 + 1.6), STONE, nil, inside), "px_cut_red_sandstone")
	local doorName = textured(decor(part("CryptDoorName", Vector3.new(16, 2.4, 0.3), at(0, 18, HALL.z0 + 3.45), STONE, nil, inside)), "px_cut_sandstone")
	boardText(doorName, "Усыпальница", Color3.fromRGB(110, 60, 20), { Enum.NormalId.Back })
	_ = doorLintel
	-- urns and treasure along the walls
	for _ = 1, 26 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = side * rng:NextNumber(96, 101)
		local z = rng:NextNumber(HALL.z0 + 4, HALL.z1 - 4)
		local hgt = rng:NextNumber(1.8, 3)
		local urn = part("Urn", Vector3.new(hgt, 1.8, 1.8), at(x, hgt / 2, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(170, 100, 60), Enum.Material.Slate, inside)
		urn.Shape = Enum.PartType.Cylinder
		decor(part("UrnBand", Vector3.new(0.4, 1.9, 1.9), urn.CFrame * CFrame.new(hgt * 0.15, 0, 0), LAPIS, nil, inside)).Shape = Enum.PartType.Cylinder
	end
end
task.wait()

-- ================================================================ the stair down and the tomb of the Скелетон (the arena)
local tomb = folder("Tomb")
do
	local s = STAIR
	local run = s.z1 - s.z0
	local stepD = 3
	local steps = math.floor(run / stepD)
	local rise = -s.bottom / steps
	-- the steps (visible) on an invisible ramp (smooth walking)
	for k = 0, steps - 1 do
		local z = s.z1 - (k + 0.5) * stepD
		local top = -(k + 1) * rise
		textured(part("Step", Vector3.new(s.x1 - s.x0, top + 40, stepD), at(0, (top - 40) / 2, z), STONE, nil, tomb), "px_cut_sandstone")
	end
	local ramp = Instance.new("WedgePart")
	ramp.Name = "StairRamp"
	ramp.Anchored = true
	ramp.Transparency = 1
	ramp.Size = Vector3.new(s.x1 - s.x0, -s.bottom, run)
	ramp.CFrame = at(0, s.bottom / 2, (s.z0 + s.z1) / 2) -- the high end to the south (the hall), sloping down north
	ramp.Parent = tomb
	-- side walls of the passage below the ground and a flat roof at the pyramid base (y 0)
	for _, side in ipairs({ -1, 1 }) do
		local wx = side * (s.x1 + 2)
		local wall = textured(part("StairWall", Vector3.new(4, -s.bottom + 4, run + 4), at(wx, s.bottom / 2 - 2, (s.z0 + s.z1) / 2 - 2), STONE, nil, tomb), "px_cut_sandstone", Color3.fromRGB(215, 200, 170))
		glyphs(wall, if side < 0 then Enum.NormalId.Right else Enum.NormalId.Left, 3 * B)
		for z = s.z0 + 6, s.z1 - 6, 10 do
			local y = -(s.z1 - z) / run * -s.bottom + 8
			torch(side * (s.x1 - 0.8), y, z, true, tomb)
		end
	end
	-- the passage roof where it runs under the open ground (north of the pyramid base edge it is the ground slab)
	textured(part("StairRoof", Vector3.new(s.x1 - s.x0 + 8, 2, -160 - s.z0), at(0, -1, (s.z0 - 160) / 2), STONE, nil, tomb), "px_cut_sandstone", Color3.fromRGB(200, 185, 155))
	-- the tomb box: floor, walls (the inner faces are ArenaWall: the charge stuns on them), ceiling
	local c = CRYPT
	local cx, cz = (c.x0 + c.x1) / 2, (c.z0 + c.z1) / 2
	local W, D, H = c.x1 - c.x0, c.z1 - c.z0, c.ceil - c.floor
	textured(part("TombFloor", Vector3.new(W + 8, 4, D + 8), at(cx, c.floor - 2, cz), STONE, nil, tomb), "px_cut_sandstone", Color3.fromRGB(200, 186, 150))
	for _, w in ipairs({
		{ Vector3.new(4, H, D + 8), at(c.x0 - 2, c.floor + H / 2, cz) },
		{ Vector3.new(4, H, D + 8), at(c.x1 + 2, c.floor + H / 2, cz) },
		{ Vector3.new(W, H, 4), at(cx, c.floor + H / 2, c.z0 - 2) },
	}) do
		local p = textured(part("ArenaWall", w[1], w[2], STONE, nil, tomb), "px_cut_sandstone", Color3.fromRGB(205, 190, 160))
		_ = p
	end
	-- the south wall with the doorway where the stair comes in
	for _, side in ipairs({ -1, 1 }) do
		local x0, x1 = if side < 0 then c.x0 else s.x1, if side < 0 then s.x0 else c.x1
		textured(part("ArenaWall", Vector3.new(x1 - x0, H, 4), at((x0 + x1) / 2, c.floor + H / 2, c.z1 + 2), STONE, nil, tomb), "px_cut_sandstone", Color3.fromRGB(205, 190, 160))
	end
	textured(part("TombDoorLintel", Vector3.new(s.x1 - s.x0, H - 16, 4), at(0, c.floor + 16 + (H - 16) / 2, c.z1 + 2), STONE, nil, tomb), "px_cut_red_sandstone")
	-- the starry ceiling: deep blue with gold stars, as in the tombs
	local ceiling = part("TombCeiling", Vector3.new(W + 8, 7, D + 8), at(cx, c.ceil + 3.5, cz), STONE, nil, tomb)
	box("TombRoofSand", -48, -1, -272, 48, 0, STAIR.z0, "px_sand", nil, tomb)
	textured(ceiling, "px_terracotta_blue", Color3.fromRGB(120, 130, 170))
	for _ = 1, 140 do
		decor(part("Star", Vector3.new(0.6, 0.1, 0.6), at(rng:NextNumber(c.x0 + 1, c.x1 - 1), c.ceil - 0.05, rng:NextNumber(c.z0 + 1, c.z1 - 1)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), GOLD, Enum.Material.Neon, tomb))
	end
	-- the walls: glyph panels, niches with the statues of the forgotten army
	for _, w in ipairs({ { c.x0 + 0.1, Enum.NormalId.Right, 1 }, { c.x1 - 0.1, Enum.NormalId.Left, -1 } }) do
		local panel = textured(decor(part("TombGlyphs", Vector3.new(0.2, 10, D - 4), at(w[1], c.floor + 15, cz), STONE, nil, tomb)), "px_cut_sandstone")
		glyphs(panel, w[2], 3 * B)
	end
	local function skeletonStatue(x, z, yaw, s, parent)
		local y = c.floor
		local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
		local function b(name, size, off, col)
			return part(name, size * s, base * CFrame.new(off[1] * s, off[2] * s, off[3] * s), col or BONE, Enum.Material.SmoothPlastic, parent)
		end
		b("SkLeg", Vector3.new(0.4, 2.6, 0.4), { -0.45, 1.3, 0 })
		b("SkLeg", Vector3.new(0.4, 2.6, 0.4), { 0.45, 1.3, 0 })
		b("SkPelvis", Vector3.new(1.4, 0.5, 0.6), { 0, 2.7, 0 })
		b("SkSpine", Vector3.new(0.35, 2, 0.35), { 0, 3.9, 0 })
		for k = 0, 2 do
			b("SkRib", Vector3.new(1.4, 0.25, 0.8), { 0, 3.6 + k * 0.5, 0 })
		end
		b("SkArm", Vector3.new(0.35, 2.4, 0.35), { -0.95, 3.6, 0 })
		b("SkArm", Vector3.new(0.35, 2.4, 0.35), { 0.95, 3.6, -0.3 })
		b("SkSkull", Vector3.new(1.2, 1.2, 1.2), { 0, 5.6, 0 })
		b("SkEye", Vector3.new(0.3, 0.3, 0.1), { -0.25, 5.7, -0.61 }, Color3.fromRGB(30, 30, 40))
		b("SkEye", Vector3.new(0.3, 0.3, 0.1), { 0.25, 5.7, -0.61 }, Color3.fromRGB(30, 30, 40))
		b("SkSword", Vector3.new(0.15, 3, 0.4), { 0.95, 3.2, -1.2 }, Color3.fromRGB(150, 140, 120))
		b("SkShield", Vector3.new(0.2, 1.8, 1.4), { -1.2, 3.6, -0.2 }, Color3.fromRGB(120, 80, 50))
	end
	for z = c.z0 + 10, c.z1 - 10, 12 do
		for _, side in ipairs({ -1, 1 }) do
			local x = if side < 0 then c.x0 + 3 else c.x1 - 3
			textured(part("NichePlinth", Vector3.new(5, 2, 5), at(x, c.floor + 1, z), STONE, nil, tomb), "px_cut_red_sandstone")
			skeletonStatue(x, z, if side < 0 then -math.pi / 2 else math.pi / 2, 1.6, tomb)
			for _, p in ipairs(tomb:GetChildren()) do
				if p.Name:match("^Sk") and not p:GetAttribute("Lifted") then
					p.CFrame = p.CFrame + Vector3.new(0, 2, 0)
					p:SetAttribute("Lifted", true)
				end
			end
			torch(x + side * -2.2 * 0 + (if side < 0 then 1 else -1), c.floor + 11, z + 6, true, tomb)
		end
	end
	-- the sarcophagus on a dais at the north end, braziers of blue cursed fire
	local sz = c.z0 + 10
	for k = 0, 2 do
		textured(part("SarcDais", Vector3.new(20 - k * 4, 1, 12 - k * 2), at(cx, c.floor + 0.5 + k, sz), STONE, nil, tomb), "px_cut_red_sandstone")
	end
	textured(part("Sarcophagus", Vector3.new(5, 2.6, 10), at(cx, c.floor + 4.3, sz), STONE, nil, tomb), "px_gold_block")
	textured(part("SarcophagusLid", Vector3.new(4.6, 0.8, 9.4), at(cx + 3.4, c.floor + 3.4, sz + 1) * CFrame.Angles(0, 0.3, 0.25), STONE, nil, tomb), "px_gold_block")
	textured(decor(part("SarcophagusBand", Vector3.new(5.2, 0.8, 10.2), at(cx, c.floor + 4.6, sz), STONE, nil, tomb)), "px_terracotta_blue")
	brazier(cx - 12, c.floor, sz, true, tomb)
	brazier(cx + 12, c.floor, sz, true, tomb)
	-- four pillars round the centre (the charge stuns on them: names Pillar*)
	for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local px, pz = cx + p[1] * 18, cz + p[2] * 18
		textured(part("PillarBase", Vector3.new(7, 2, 7), at(px, c.floor + 1, pz), STONE, nil, tomb), "px_cut_red_sandstone")
		local pil = textured(part("Pillar", Vector3.new(5, H - 4, 5), at(px, c.floor + 2 + (H - 4) / 2, pz), STONE, nil, tomb), "px_cut_sandstone")
		for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do
			glyphs(pil, face, 5)
		end
		textured(part("PillarCap", Vector3.new(7, 2, 7), at(px, c.ceil - 1, pz), STONE, nil, tomb), "px_cut_red_sandstone")
	end
	-- bones on the floor, cursed mist
	for _ = 1, 40 do
		decor(part("Bone", Vector3.new(0.4, 0.4, rng:NextNumber(1.2, 2.6)), at(rng:NextNumber(c.x0 + 4, c.x1 - 4), c.floor + 0.2, rng:NextNumber(c.z0 + 4, c.z1 - 4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), BONE, nil, tomb))
	end
	for _ = 1, 6 do
		decor(part("Skull", Vector3.new(1, 1, 1), at(rng:NextNumber(c.x0 + 4, c.x1 - 4), c.floor + 0.5, rng:NextNumber(c.z0 + 4, c.z1 - 4)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.2), BONE, nil, tomb))
	end
	local mist = decor(part("CurseMist", Vector3.new(W - 4, 1, D - 4), at(cx, c.floor + 0.6, cz), STONE, nil, tomb))
	mist.Transparency = 1
	emitter(mist, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(120, 200, 230)),
		LightEmission = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 5) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.4, 0.85), NumberSequenceKeypoint.new(1, 1) }),
		Rate = 10,
		Lifetime = NumberRange.new(5, 8),
		Speed = NumberRange.new(0.3, 1),
		SpreadAngle = Vector2.new(90, 90),
	})
	-- the boss
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(cx, c.floor + 1.2, cz), STONE, nil, tomb)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "skeleton")
	bossSpawn:SetAttribute("ArenaRadius", 36)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end
task.wait()

-- ================================================================ the oasis camp (arrival)
local camp = folder("Oasis")
local props = folder("Props")
local function palm(x, z, h)
	local y = floorAt(x, z)
	local lean = rng:NextNumber(-0.18, 0.18)
	local yaw = rng:NextNumber(0, 6.28)
	local cf = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local segs = math.floor(h / 2)
	local top
	for k = 0, segs - 1 do
		local p = part("PalmTrunk", Vector3.new(1.3 - k * 0.03, 2.1, 1.3 - k * 0.03), cf * CFrame.Angles(lean * k / segs, 0, 0) * CFrame.new(0, k * 2 + 1, lean * k * 1.2), Color3.fromRGB(140, 105, 70), Enum.Material.Wood, props)
		top = p
	end
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		decor(part("PalmLeaf", Vector3.new(1.6, 0.2, 7), top.CFrame * CFrame.new(0, 1, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(-0.35, 0, 0) * CFrame.new(0, 0, -3.4), Color3.fromRGB(70, 130, 50), Enum.Material.Grass, props))
	end
	for _ = 1, 3 do
		part("Coconut", Vector3.new(0.8, 0.8, 0.8), top.CFrame * CFrame.new(rng:NextNumber(-0.6, 0.6), 0.4, rng:NextNumber(-0.6, 0.6)), Color3.fromRGB(110, 75, 40), nil, props).Shape = Enum.PartType.Ball
	end
end
do
	local ox, oz = CAMP.x, CAMP.z
	local plaza = part("Plaza", Vector3.new(0.4, 36, 36), at(ox, 0.15, oz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, camp)
	plaza.Shape = Enum.PartType.Cylinder
	textured(plaza, "px_cut_sandstone")
	local spawn = part("LocationSpawn_pyramid", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z + PIT.hole + 12), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), STONE, nil, camp) -- [владелец 23.10] the arrival is by the mine, just south of the pit rim
	textured(spawn, "px_cut_red_sandstone")
	spawn:SetAttribute("LocationId", "pyramid")
	CollectionService:AddTag(spawn, "LocationSpawn")
	-- the pond (water texture, a sandstone rim) with reeds and palms
	local px, pz = ox - 32, oz + 14
	local pond = part("Pond", Vector3.new(0.6, 26, 26), at(px, 0.1, pz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, camp)
	pond.Shape = Enum.PartType.Cylinder
	textured(pond, "px_water", Color3.fromRGB(150, 210, 230))
	local grass = part("PondGrass", Vector3.new(0.4, 34, 34), at(px, 0.05, pz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, camp)
	grass.Shape = Enum.PartType.Cylinder
	textured(grass, "px_grass_top", Color3.fromRGB(170, 200, 120))
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		palm(px + math.cos(a) * 16, pz + math.sin(a) * 16, rng:NextNumber(12, 20))
	end
	for _ = 1, 18 do
		local a = rng:NextNumber(0, 6.28)
		decor(part("Reed", Vector3.new(0.2, rng:NextNumber(1.6, 3), 0.2), at(px + math.cos(a) * 12.5, 1.2, pz + math.sin(a) * 12.5), Color3.fromRGB(120, 150, 70), Enum.Material.Grass, camp))
	end
	-- tents of striped canvas
	local function tent(x, z, yaw)
		local base = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
		for _, s in ipairs({ -1, 1 }) do
			part("TentSide", Vector3.new(0.15, 5.4, 7), base * CFrame.new(s * 1.9, 2.1, 0) * CFrame.Angles(0, 0, s * 0.62), if s < 0 then CANVAS else Color3.fromRGB(190, 70, 50), Enum.Material.Fabric, camp)
		end
		part("RidgePole", Vector3.new(0.3, 0.3, 7.6), base * CFrame.new(0, 4.35, 0), WOOD, Enum.Material.Wood, camp)
		decor(part("Rug", Vector3.new(3, 0.1, 5), base * CFrame.new(0, 0.05, 0), Color3.fromRGB(150, 40, 40), Enum.Material.Fabric, camp))
	end
	tent(ox + 24, oz + 10, 0.4)
	tent(ox + 20, oz + 24, -0.3)
	tent(ox - 6, oz + 30, 1.6)
	-- a well
	do
		local wx, wz = ox + 8, oz + 14
		local ring = part("Well", Vector3.new(3, 5, 5), at(wx, 1.5, wz) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, camp)
		ring.Shape = Enum.PartType.Cylinder
		textured(ring, "px_sandstone")
		decor(part("WellWater", Vector3.new(0.2, 4, 4), at(wx, 2.6, wz) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 110, 140), Enum.Material.Glass, camp)).Shape = Enum.PartType.Cylinder
		for _, s in ipairs({ -1, 1 }) do
			part("WellPost", Vector3.new(0.5, 5, 0.5), at(wx + s * 2.2, 4, wz), WOOD, Enum.Material.Wood, camp)
		end
		part("WellBeam", Vector3.new(5, 0.5, 0.5), at(wx, 6.4, wz), WOOD, Enum.Material.Wood, camp)
		part("WellBucket", Vector3.new(0.9, 0.9, 0.9), at(wx, 4.6, wz), WOOD, Enum.Material.Wood, camp)
	end
	-- the block buyer at a stall under a striped awning
	do
		-- [владелец 23.10] the buyer stands by the mine, next to the arrival
		local sx, sz = PIT.x + 18, PIT.z + PIT.hole + 14
		local ox, oz = PIT.x, PIT.z + PIT.hole + 12
		local desc = Instance.new("HumanoidDescription")
		local skin = Color3.fromRGB(176, 120, 80)
		desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
		desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(230, 220, 190), Color3.fromRGB(200, 190, 160), Color3.fromRGB(200, 190, 160)
		local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
		model.Name = "PyramidBuyer"
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
		model:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + ox, 3, BZ + oz)))
		model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
		local hrp = model:FindFirstChild("HumanoidRootPart")
		CollectionService:AddTag(hrp, "SellPoint")
		sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
		part("Headscarf", Vector3.new(2.3, 1.2, 2.3), model.Head.CFrame * CFrame.new(0, 0.5, 0.1), Color3.fromRGB(240, 235, 220), Enum.Material.Fabric, model).CanCollide = false
		textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), STONE, nil, camp), "px_planks")
		for _, dz in ipairs({ -4.4, 4.4 }) do
			for _, dx in ipairs({ -1.2, 5 }) do
				part("StallPost", Vector3.new(0.6, 9, 0.6), at(sx + dx, 4.5, sz + dz), WOOD, Enum.Material.Wood, camp)
			end
		end
		for k = 0, 5 do
			decor(part("Awning", Vector3.new(7.4, 0.15, 1.6), at(sx + 1.9, 9.1 - k * 0.12, sz - 4.5 + k * 1.6 + 0.8) * CFrame.Angles(0, 0, -0.15), if k % 2 == 0 then LAPIS else CANVAS, Enum.Material.Fabric, camp))
		end
		for _, c in ipairs({ { -0.3, -2.5, "px_sandstone" }, { -0.3, 2.5, "px_red_sandstone" } }) do
			local crate = textured(part("Crate", Vector3.new(1.8, 1.8, 1.8), at(sx + c[1], 3.9, sz + c[2]), STONE, nil, camp), "px_planks")
			textured(decor(part("CrateLoad", Vector3.new(1.4, 0.3, 1.4), crate.CFrame * CFrame.new(0, 0.9, 0), STONE, nil, camp)), c[3])
		end
	end
	-- lamp posts round the plaza, the signpost
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.5
		local x, z = ox + math.cos(a) * 20, oz + math.sin(a) * 20
		part("LampPost", Vector3.new(0.7, 7, 0.7), at(x, 3.5, z), WOOD, Enum.Material.Wood, camp)
		local l = decor(part("Lamp", Vector3.new(1, 1.2, 1), at(x, 7.4, z), LAMP, Enum.Material.Neon, camp))
		light(l, 22, 1.2, LAMP)
	end
	do
		local sx, sz = ox - 8, oz - 20
		part("SignPost", Vector3.new(0.6, 7, 0.6), at(sx, 3.5, sz), WOOD, Enum.Material.Wood, camp)
		local toPyr = textured(part("Signboard", Vector3.new(5, 1, 0.3), at(sx, 5.8, sz) * CFrame.Angles(0, math.atan2(PYR.x - sx, PYR.z - sz) + math.pi / 2, 0) * CFrame.new(2.2, 0, 0), STONE, nil, camp), "px_planks")
		boardText(toPyr, "Пирамида", Color3.fromRGB(255, 235, 200))
	end
end
task.wait()

-- ================================================================ outside: the field of the forgotten army, the ruined temple, the necropolis
local outside = folder("Outside")
local function clear(x, z, margin)
	local c = cellAtPos(x, z)
	return c and c.kind == "ground" and not c.path and not flat(x, z) and not inPyramid(x, z, (margin or 0) + 20) and c.d < 0.92
end
local function zoneSign(x, z, text, yaw)
	local y = floorAt(x, z)
	part("SignPost", Vector3.new(0.7, 5, 0.7), at(x, y + 2.5, z), WOOD, Enum.Material.Wood, outside)
	local board = textured(part("ZoneSign", Vector3.new(7, 1.8, 0.4), at(x, y + 4.6, z) * CFrame.Angles(0, yaw or 0, 0), STONE, nil, outside), "px_planks")
	boardText(board, text, Color3.fromRGB(255, 235, 200))
end
-- a half-buried skeleton warrior of the forgotten army, his sword stuck in the sand beside him
local function fallenWarrior(x, z)
	local y = floorAt(x, z)
	local yaw = rng:NextNumber(0, 6.28)
	local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
	local roll = rng:NextNumber()
	if roll < 0.5 then
		-- lying, half under the sand
		part("FallenSkull", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 0.3, -2.2) * CFrame.Angles(0.3, 0, 0.2), BONE, nil, outside)
		decor(part("FallenSpine", Vector3.new(0.35, 0.35, 2.6), base * CFrame.new(0, 0.1, -0.6), BONE, nil, outside))
		for k = 0, 2 do
			decor(part("FallenRib", Vector3.new(1.4, 0.3, 0.3), base * CFrame.new(0, 0.15, -1.2 + k * 0.5), BONE, nil, outside))
		end
		decor(part("FallenArm", Vector3.new(0.3, 0.3, 2), base * CFrame.new(1, 0.1, -0.8) * CFrame.Angles(0, 0.5, 0), BONE, nil, outside))
	else
		-- kneeling, buried to the waist
		part("BuriedTorso", Vector3.new(0.35, 1.6, 0.35), base * CFrame.new(0, 0.8, 0), BONE, nil, outside)
		for k = 0, 2 do
			decor(part("BuriedRib", Vector3.new(1.3, 0.25, 0.7), base * CFrame.new(0, 0.6 + k * 0.45, 0), BONE, nil, outside))
		end
		part("BuriedSkull", Vector3.new(1.2, 1.2, 1.2), base * CFrame.new(0, 2.3, 0) * CFrame.Angles(0.4, 0, 0), BONE, nil, outside)
		decor(part("BuriedArm", Vector3.new(0.3, 2, 0.3), base * CFrame.new(0.9, 1.3, -0.4) * CFrame.Angles(-0.8, 0, 0), BONE, nil, outside))
	end
	-- the sword or a spear, and sometimes a shield
	local sx = rng:NextNumber(-2, 2)
	part("RustySword", Vector3.new(0.2, 3, 0.5), base * CFrame.new(sx, 1.2, 1.5) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), 0, rng:NextNumber(-0.25, 0.25)), Color3.fromRGB(130, 100, 80), Enum.Material.CorrodedMetal, outside)
	part("SwordGuard", Vector3.new(1.2, 0.25, 0.3), base * CFrame.new(sx, 2.7, 1.5), Color3.fromRGB(150, 120, 60), Enum.Material.Metal, outside)
	if rng:NextNumber() < 0.35 then
		part("Shield", Vector3.new(0.2, 2, 1.6), base * CFrame.new(-1.8, 0.7, 0.6) * CFrame.Angles(0, 0.4, 0.5), Color3.fromRGB(120, 80, 50), Enum.Material.Wood, outside)
	end
end
do
	-- the field: rows of fallen warriors, tattered standards, a broken chariot
	local made = 0
	for _ = 1, 3000 do
		if made >= 60 then
			break
		end
		local x, z = rng:NextNumber(-260, -110), rng:NextNumber(-60, 170)
		if clear(x, z) then
			fallenWarrior(x, z)
			made += 1
		end
	end
	for _, s in ipairs({ { -180, 40 }, { -150, 110 }, { -220, -20 }, { -200, 140 } }) do
		local y = floorAt(s[1], s[2])
		part("StandardPole", Vector3.new(0.5, 12, 0.5), at(s[1], y + 6, s[2]) * CFrame.Angles(0.08, 0, -0.06), WOOD, Enum.Material.Wood, outside)
		decor(part("Standard", Vector3.new(0.15, 4, 3), at(s[1] + 0.2, y + 9.5, s[2] + 1.6), Color3.fromRGB(110, 40, 34), Enum.Material.Fabric, outside)).Transparency = 0.15
		textured(part("StandardDisc", Vector3.new(1.6, 1.6, 0.3), at(s[1], y + 12.5, s[2]), STONE, nil, outside), "px_gold_block")
	end
	do
		local x, z = -165, 70
		local y = floorAt(x, z)
		part("ChariotBed", Vector3.new(4, 1.4, 3), at(x, y + 1.2, z) * CFrame.Angles(0, 0.6, 0.3), WOOD, Enum.Material.Wood, outside)
		local wheel = part("ChariotWheel", Vector3.new(0.4, 3.6, 3.6), at(x + 2.6, y + 1.2, z + 1) * CFrame.Angles(0, 0.6, 1.1), WOOD, Enum.Material.Wood, outside)
		wheel.Shape = Enum.PartType.Cylinder
		local wheel2 = part("ChariotWheel", Vector3.new(0.4, 3.6, 3.6), at(x - 3, y + 0.4, z - 2) * CFrame.Angles(0, 0, math.pi / 2 - 0.05), WOOD, Enum.Material.Wood, outside)
		wheel2.Shape = Enum.PartType.Cylinder
	end
	zoneSign(-104, 152, "Поле забытой армии", math.atan2(1, 1))
	-- the ruined temple (east): a colonnade on a stepped platform, some columns fallen, a giant buried head
	local tx, tz = 205, 60
	for k = 0, 2 do
		textured(part("TemplePlatform", Vector3.new(56 - k * 6, 1.2, 40 - k * 6), at(tx, floorAt(tx, tz) + 0.6 + k * 1.2, tz), STONE, nil, outside), "px_cut_sandstone")
	end
	local ty = floorAt(tx, tz) + 3.6
	for _, s in ipairs({ -1, 1 }) do
		for k = -2, 2 do
			local x, z = tx + k * 9, tz + s * 12
			local fallen = rng:NextNumber() < 0.3
			if fallen then
				local col = part("TempleColumnFallen", Vector3.new(18, 4, 4), at(x + 4, ty + 2, z + s * 6) * CFrame.Angles(0, rng:NextNumber(-0.5, 0.5), 0), STONE, nil, outside)
				col.Shape = Enum.PartType.Cylinder
				textured(col, "px_cut_sandstone")
			else
				local hgt = if rng:NextNumber() < 0.3 then rng:NextNumber(6, 12) else 18
				local col = part("TempleColumn", Vector3.new(hgt, 4, 4), at(x, ty + hgt / 2, z) * CFrame.Angles(0, 0, math.pi / 2), STONE, nil, outside)
				col.Shape = Enum.PartType.Cylinder
				textured(col, "px_cut_sandstone")
				if hgt == 18 then
					textured(part("TempleCapital", Vector3.new(5, 1.6, 5), at(x, ty + 18.8, z), STONE, nil, outside), "px_cut_red_sandstone")
				end
			end
		end
		if s < 0 then
			textured(part("TempleArchitrave", Vector3.new(30, 2.4, 5), at(tx - 4, ty + 20.8, tz + s * 12), STONE, nil, outside), "px_cut_sandstone")
		end
	end
	-- the giant head of a fallen statue, half in the sand
	do
		local hx, hz = tx - 40, tz - 36
		local y = floorAt(hx, hz)
		local head = textured(part("GiantHead", Vector3.new(12, 12, 12), at(hx, y + 4, hz) * CFrame.Angles(0.2, 0.8, 0.35), STONE, nil, outside), "px_cut_sandstone")
		textured(part("GiantNemes", Vector3.new(16, 10, 6), head.CFrame * CFrame.new(0, 1, 4), STONE, nil, outside), "px_terracotta_blue")
		for _, s in ipairs({ -1, 1 }) do
			decor(part("GiantEye", Vector3.new(2.6, 1, 0.2), head.CFrame * CFrame.new(s * 2.6, 1.6, -6.05), Color3.fromRGB(40, 36, 40), nil, outside))
		end
		textured(part("GiantNose", Vector3.new(2, 3, 1.4), head.CFrame * CFrame.new(0, -0.4, -6.4), STONE, nil, outside), "px_cut_sandstone")
	end
	zoneSign(118, 146, "Руины храма", math.atan2(1, -1))
	-- the necropolis behind the pyramid: mastabas (low flat tombs) with false doors, obelisks
	for _, m in ipairs({ { -150, -230 }, { -96, -262 }, { 96, -262 }, { 150, -230 } }) do
		local y = floorAt(m[1], m[2])
		for k = 0, 2 do
			textured(part("Mastaba", Vector3.new(26 - k * 4, 4, 18 - k * 3), at(m[1], y + 2 + k * 4, m[2]), STONE, nil, outside), if k == 2 then "px_cut_red_sandstone" else "px_cut_sandstone")
		end
		local door = textured(part("FalseDoor", Vector3.new(5, 7, 0.4), at(m[1], y + 3.5, m[2] + 9.2), STONE, nil, outside), "px_cut_red_sandstone")
		glyphs(door, Enum.NormalId.Back, 2.5)
		obelisk(m[1] + 16, m[2] + 10, 12)
	end
	zoneSign(-200, -170, "Некрополь", 0)
	zoneSign(205, -170, "Некрополь", 0)
	-- the desert: dead bushes, cacti, bones, urns
	local function deadBush(x, z)
		local y = floorAt(x, z)
		for _ = 1, rng:NextInteger(4, 7) do
			local len = rng:NextNumber(1, 2.4)
			decor(part("DeadBush", Vector3.new(0.15, len, 0.15), at(x, y + len / 2 - 0.2, z) * CFrame.Angles(rng:NextNumber(-0.7, 0.7), rng:NextNumber(0, 6), rng:NextNumber(-0.7, 0.7)), Color3.fromRGB(125, 90, 55), Enum.Material.Wood, outside))
		end
	end
	local function cactus(x, z)
		local y = floorAt(x, z)
		local h = rng:NextInteger(3, 6) * 1.5
		local green = Color3.fromRGB(80, 120, 55)
		part("Cactus", Vector3.new(1.4, h, 1.4), at(x, y + h / 2, z), green, Enum.Material.Grass, outside)
		for _, side in ipairs({ -1, 1 }) do
			if rng:NextNumber() < 0.6 then
				local ay = y + rng:NextNumber(h * 0.35, h * 0.6)
				part("CactusArm", Vector3.new(1.6, 0.9, 0.9), at(x + side * 1.4, ay, z), green, Enum.Material.Grass, outside)
				part("CactusArmUp", Vector3.new(0.9, 2.2, 0.9), at(x + side * 1.9, ay + 1.4, z), green, Enum.Material.Grass, outside)
			end
		end
	end
	local made2 = 0
	for _ = 1, 4000 do
		if made2 >= 140 then
			break
		end
		local x, z = rng:NextNumber(-R, R), rng:NextNumber(-R, R)
		if clear(x, z) then
			made2 += 1
			local roll = rng:NextNumber()
			if roll < 0.45 then
				deadBush(x, z)
			elseif roll < 0.8 then
				cactus(x, z)
			else
				decor(part("Bone", Vector3.new(0.5, 0.5, rng:NextNumber(1.5, 3)), at(x, floorAt(x, z) + 0.2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), BONE, nil, outside))
			end
		end
	end
end
task.wait()

-- ================================================================ lighting volumes (inside the pyramid, the tomb) and blowing sand
local airModel = Instance.new("Model")
airModel.Name = "IndoorLighting"
airModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
airModel.Parent = root
local function volume(name, x0, y0, z0, x1, y1, z1, ambient, exposure, haze, color, decay)
	local v = decor(part(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), STONE, nil, airModel))
	v.Transparency = 1
	v:SetAttribute("Ambient", ambient)
	v:SetAttribute("Exposure", exposure)
	if haze then
		v:SetAttribute("Haze", haze)
		v:SetAttribute("AtmosphereColor", color)
		v:SetAttribute("AtmosphereDecay", decay)
	end
	CollectionService:AddTag(v, "IndoorLighting")
end
-- [владелец 23.10: «шахту светлее»] the hall ambient lifted (the lamps stay soft: they were the glare)
volume("HallVolume", HALL.x0, -52, HALL.z0, HALL.x1, HALL_APEX, HALL.z1, Color3.fromRGB(175, 160, 138), 0, 0.06, Color3.fromRGB(140, 115, 85), Color3.fromRGB(80, 60, 42))
volume("GalleryVolume", GALLERY.x0, 0, GALLERY.z0, GALLERY.x1, GALLERY.y1, GALLERY.z1 + 2, Color3.fromRGB(112, 98, 84), -0.25, 0.08, Color3.fromRGB(140, 115, 85), Color3.fromRGB(80, 60, 42))
volume("TombVolume", CRYPT.x0 - 4, CRYPT.floor - 2, CRYPT.z0 - 4, CRYPT.x1 + 4, 0, STAIR.z1, Color3.fromRGB(88, 92, 112), 0, 0.14, Color3.fromRGB(50, 56, 86), Color3.fromRGB(24, 28, 50))
for _, spot in ipairs({ { -160, 60 }, { 160, 60 }, { 0, 200 }, { -150, -200 }, { 150, -200 } }) do
	local p = decor(part("BlowingSand", Vector3.new(120, 1, 120), at(spot[1], 3, spot[2]), STONE, nil, outside))
	p.Transparency = 1
	emitter(p, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(230, 205, 150)),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 6) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.8), NumberSequenceKeypoint.new(1, 1) }),
		Rate = 5,
		Lifetime = NumberRange.new(4, 7),
		Speed = NumberRange.new(10, 16),
		EmissionDirection = Enum.NormalId.Right,
		SpreadAngle = Vector2.new(10, 10),
	})
end

local total = #root:GetDescendants()
print(("[build-pyramid] built: %d instances (terrain runs %d)"):format(total, count))
return ("built %d instances, runs %d"):format(total, count)
