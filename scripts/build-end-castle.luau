--!nocheck
-- Builds the Пустотная крепость, level 15, PvP [меню]. «Пустотная крепость окутана мраком, а шалкеры в лиловых
-- панцирях поджидают на каждом углу, готовые напасть» [меню]. Blocks: эндерняковые кирпичи 50 %, пурпур 50 %
-- [меню]. Boss: Иллюзионист — «хитрый маг, чьи иллюзии и острые как бритва клинки…» [клиент], minion «Кролик».
-- [владелец 23.10: «черпай идеи из интернета»] Ideas from the Minecraft End and its cities: floating end-stone
-- islands in a dark void, joined by wide purpur sky-bridges; an End City spire of stepped purpur tiers with
-- flat roofs, end rods and banners (its ground hall open to walk in); a chorus garden with obsidian pillars
-- crowned by caged end crystals; an End ship moored at the main island with a dragon head at its prow; shulkers
-- on every corner [меню]; the arena — the Hall of Illusions, a wide round platform with mirror pillars under a
-- floating halo, open from three wide bridges. The lessons of the earlier locations: the arrival and the buyer by
-- the mine, wide ways (PvP crowds), few soft lights, no textures on cylinders, invisible walls round the map and
-- a void net under the islands (LavaService: VoidCatch puts a faller back on the arrival point).
-- X 7400, height Y 9000 (each new location floats at its own height). Run in Studio (Edit) via
-- scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.EndCastle.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("EndCastle")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "EndCastle"
root:SetAttribute("LocationId", "end_castle")
root.Parent = workspace

local BX, BZ = 7400, 0
local BY = 9000 -- the location's own height [владелец 23.10]
local B = 4
local rng = Random.new(20261515)
local OBSIDIAN = Color3.fromRGB(30, 20, 44)
local IRON = Color3.fromRGB(70, 66, 80)
local WHITE = Color3.fromRGB(240, 238, 245)
local VIOLET = Color3.fromRGB(150, 90, 200)
local SHULKER = Color3.fromRGB(150, 100, 160)
local ROD = Color3.fromRGB(250, 245, 255)
local CRYSTAL = Color3.fromRGB(255, 150, 230)

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
		label.TextColor3 = color or Color3.fromRGB(240, 220, 255)
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
local PIT = { x = 0, z = 40, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json end_castle.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local SPAWN_Z = PIT.z + PIT.hole + 12
-- the islands: centre, radii, depth of the rock under them
local MAIN = { x = 0, z = 50, rx = 130, rz = 145, depth = 120 } -- deep: the mine pit (48) must stay inside the rock
local ARENA = { x = 0, z = -205, r = 72, depth = 50 }
local WEST = { x = -205, z = -40, r = 62, depth = 50 }
local EAST = { x = 205, z = -40, r = 62, depth = 50 }
local ISLANDS = { MAIN, ARENA, WEST, EAST }
local ISLETS = { { -120, 210, 14 }, { 150, 230, 12 }, { -250, 140, 16 }, { 260, 110, 13 }, { -110, -270, 12 }, { 140, -280, 15 } }
-- the sky-bridges (wide: PvP crowds) between island centres; each deck runs from inside one island into the next
local BRIDGES = {
	{ MAIN, ARENA, 24 },
	{ MAIN, WEST, 18, -30 },
	{ MAIN, EAST, 18, -30 },
	{ WEST, ARENA, 16 },
	{ EAST, ARENA, 16 },
}
local SHIP = { x = 196, z = 160 }

-- ================================================================ the islands (8-stud cells), rock tapering under each
local C = 8
local X0, Z0 = -320, -320
local NX, NZ = 80, 80
local function islandAt(x, z)
	for _, s in ipairs(ISLANDS) do
		local rx, rz = s.rx or s.r, s.rz or s.r
		local d = math.sqrt(((x - s.x) / rx) ^ 2 + ((z - s.z) / rz) ^ 2) * (1 + n2(x, z, 2.2 + s.x * 0.01, 0.035) * 0.1)
		if d < 1 then
			return s, d
		end
	end
	return nil
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local terrain = folder("Islands")
local count = 0
for iz = 0, NZ - 1 do
	local z0, z1 = Z0 + iz * C, Z0 + (iz + 1) * C
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
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, z0 + C / 2
		local used = {}
		local s, d = islandAt(x, z)
		if s and not inHole(x, z) then
			-- the underside: deepest in the middle, ragged by noise, in 4-stud steps
			local under = -4 * math.floor((s.depth * (1 - d * d) ^ 0.8 + 4 + n2(x, z, 9.1, 0.08) * 8) / 4)
			local plaza = (s == ARENA) or (s == MAIN and math.abs(x - PIT.x) < PIT.hole + 16 and math.abs(z - PIT.z) < PIT.hole + 16)
			local topV = if plaza then "px_end_stone_bricks" elseif n2(x, z, 4.4, 0.06) > 0.45 then "px_end_stone_bricks" else "px_end_stone"
			push(ix, "rock", "IslandRock", under, -1, "px_end_stone", Color3.fromRGB(200, 196, 170))
			push(ix, "top", "IslandTop", -1, 0, topV, nil)
			used.rock, used.top = true, true
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
-- small floating islets round the edge, each with a chorus plant or an end crystal
local islets = folder("Islets")
for _, s in ipairs(ISLETS) do
	local x, z, r = s[1], s[2], s[3]
	local y = rng:NextNumber(-20, 30)
	for k = 0, 3 do
		local w = r * 2 * (1 - k * 0.24)
		textured(part("Islet", Vector3.new(w, 4, w * 0.9), at(x, y - 2 - k * 4, z) * CFrame.Angles(0, k * 0.4, 0), nil, nil, islets), "px_end_stone")
	end
	s.y = y
end

-- ================================================================ small builders
local props = folder("Props")
-- a shulker: a lilac shell, the lid lifted a little, the yellow head peeping out [меню: шалкеры на каждом углу]
local function shulker(x, y, z, yaw, parent)
	local base = at(x, y, z) * CFrame.Angles(0, yaw or 0, 0)
	part("ShulkerShell", Vector3.new(3, 1.8, 3), base * CFrame.new(0, 0.9, 0), SHULKER, Enum.Material.SmoothPlastic, parent or props)
	part("ShulkerLid", Vector3.new(3.1, 1.2, 3.1), base * CFrame.new(0, 2.6, 0), SHULKER:Lerp(WHITE, 0.15), Enum.Material.SmoothPlastic, parent or props)
	part("ShulkerHead", Vector3.new(1.6, 1.4, 1.6), base * CFrame.new(0, 2, -0.4), Color3.fromRGB(240, 220, 120), Enum.Material.SmoothPlastic, parent or props)
	decor(part("ShulkerEyes", Vector3.new(1, 0.25, 0.1), base * CFrame.new(0, 2.2, -1.22), Color3.fromRGB(40, 30, 50), nil, parent or props))
end
local function endRod(x, y, z, len, lit, parent)
	part("EndRodBase", Vector3.new(1, 0.4, 1), at(x, y + 0.2, z), Color3.fromRGB(200, 190, 220), nil, parent or props)
	local rod = decor(part("EndRod", Vector3.new(0.35, len, 0.35), at(x, y + 0.4 + len / 2, z), ROD, Enum.Material.Neon, parent or props))
	if lit then
		light(rod, 22, 1.2, Color3.fromRGB(230, 210, 255))
	end
	return rod
end
local function chorus(x, y, z, h, parent)
	-- a branching chorus plant: a stem of blocks, side branches, pale flowers on the tips
	local function stem(px, py, pz, len, depth)
		for k = 0, len - 1 do
			textured(part("Chorus", Vector3.new(1.6, 2, 1.6), at(px, py + k * 2 + 1, pz), nil, nil, parent or props), "px_chorus")
		end
		local top = py + len * 2
		if depth > 0 then
			for _ = 1, rng:NextInteger(1, 2) do
				local dx, dz = rng:NextInteger(-1, 1) * 1.6, rng:NextInteger(-1, 1) * 1.6
				if dx ~= 0 or dz ~= 0 then
					textured(part("Chorus", Vector3.new(1.6, 1.6, 1.6), at(px + dx, top - 1, pz + dz), nil, nil, parent or props), "px_chorus")
					stem(px + dx, top - 0.2, pz + dz, rng:NextInteger(1, 3), depth - 1)
				end
			end
		else
			part("ChorusFlower", Vector3.new(1.8, 1.8, 1.8), at(px, top + 0.9, pz), Color3.fromRGB(230, 200, 235), nil, parent or props)
		end
	end
	stem(x, y, z, h, 2)
end
local function zoneSign(x, z, text, yaw)
	textured(part("SignPost", Vector3.new(0.8, 5, 0.8), at(x, 2.5, z), nil, nil, props), "px_purpur_pillar")
	local board = textured(part("ZoneSign", Vector3.new(8, 1.8, 0.4), at(x, 4.6, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, props), "px_purpur")
	boardText(board, text)
end
local function banner(cf, parent)
	part("BannerRod", Vector3.new(4.4, 0.3, 0.3), cf * CFrame.new(0, 4.3, 0), IRON, Enum.Material.Metal, parent or props)
	decor(part("Banner", Vector3.new(3.6, 8, 0.15), cf, Color3.fromRGB(70, 40, 90), Enum.Material.Fabric, parent or props))
	decor(part("BannerStripe", Vector3.new(3.6, 1, 0.17), cf * CFrame.new(0, -2, 0), Color3.fromRGB(230, 200, 240), Enum.Material.Fabric, parent or props))
	decor(part("BannerMark", Vector3.new(1.2, 1.2, 0.17), cf * CFrame.new(0, 1.2, 0), Color3.fromRGB(240, 220, 120), Enum.Material.Fabric, parent or props))
end

-- ================================================================ the sky-bridges (wide, with railings and end rods)
local bridges = folder("SkyBridges")
for _, br in ipairs(BRIDGES) do
	local a, b, W = br[1], br[2], br[3]
	local ax, az = a.x, if br[4] then br[4] else a.z
	local bx, bz = b.x, if br[4] then br[4] else b.z
	local dx, dz = bx - ax, bz - az
	local L = math.sqrt(dx * dx + dz * dz)
	local ux, uz = dx / L, dz / L
	-- from 70 % of the way to each island's rim (deep enough onto the rock), for the bridges between islands
	local ra = if br[4] then (a.rx or a.r) * 0.6 else (a.rz or a.r) * 0.75
	local rb = (b.rz or b.r) * 0.75
	if br[4] then
		rb = (b.rx or b.r) * 0.75
	end
	local x0, z0 = ax + ux * ra, az + uz * ra
	local x1, z1 = bx - ux * rb, bz - uz * rb
	local len = math.sqrt((x1 - x0) ^ 2 + (z1 - z0) ^ 2)
	local cf = CFrame.lookAt(Vector3.new(BX + (x0 + x1) / 2, 0, BZ + (z0 + z1) / 2), Vector3.new(BX + x1, 0, BZ + z1))
	textured(part("BridgeDeck", Vector3.new(W, 1.2, len), cf * CFrame.new(0, -0.4, 0), nil, nil, bridges), "px_purpur")
	textured(part("BridgeBeam", Vector3.new(W - 4, 3, len), cf * CFrame.new(0, -2.6, 0), nil, nil, bridges), "px_purpur_pillar")
	for _, s in ipairs({ -1, 1 }) do
		textured(part("BridgeRail", Vector3.new(1, 1.6, len), cf * CFrame.new(s * (W / 2 - 0.5), 1, 0), nil, nil, bridges), "px_end_stone_bricks")
		for d = -len / 2 + 4, len / 2 - 4, 12 do
			local p = cf * CFrame.new(s * (W / 2 - 0.5), 1.8, d)
			part("RailPost", Vector3.new(1.4, 1.4, 1.4), p, Color3.fromRGB(200, 160, 200), nil, bridges)
			local rod = decor(part("EndRod", Vector3.new(0.35, 3, 0.35), p * CFrame.new(0, 2.2, 0), ROD, Enum.Material.Neon, bridges))
			if math.floor(d / 12) % 3 == 0 then
				light(rod, 20, 1, Color3.fromRGB(230, 210, 255))
			end
		end
	end
	-- arched supports hanging under the deck every 24 studs
	for d = -len / 2 + 12, len / 2 - 12, 24 do
		textured(part("BridgeHanger", Vector3.new(W - 6, 8, 3), cf * CFrame.new(0, -6, d), nil, nil, bridges), "px_purpur")
		textured(part("BridgeHangerTip", Vector3.new(W - 12, 4, 3), cf * CFrame.new(0, -12, d), nil, nil, bridges), "px_purpur")
	end
	-- shulkers at both ends of every bridge
	for _, e in ipairs({ { -len / 2 + 2, 1 }, { len / 2 - 2, -1 } }) do
		local p = (cf * CFrame.new(W / 2 + 2.5, 0, e[1])).Position
		shulker(p.X - BX, 0, p.Z - BZ, 0, bridges)
	end
end
task.wait()

-- ================================================================ the mine and the arrival by it
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	textured(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(mx, -h - B / 2, mz), nil, nil, mine), "px_obsidian")
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(mx, -h / 2, mz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(mx - w / 2 - B, -h / 2, mz) },
		{ Vector3.new(2 * B, h, w), at(mx + w / 2 + B, -h / 2, mz) },
	}) do
		textured(part("PitWall", wall[1], wall[2], nil, nil, mine), "px_end_stone", Color3.fromRGB(190, 186, 160))
	end
	local edge = w / 2 + 2 * B
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 0.6, 2 * B), at(mx, 0.3, mz + w / 2 + B) },
		{ Vector3.new(2 * B, 0.6, w), at(mx - w / 2 - B, 0.3, mz) },
		{ Vector3.new(2 * B, 0.6, w), at(mx + w / 2 + B, 0.3, mz) },
	}) do
		textured(part("PitRim", r[1], r[2], nil, nil, mine), "px_purpur")
	end
	-- purpur columns with end rods at the corners, shulkers between them
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = mx + s[1] * (edge + 4), mz + s[2] * (edge + 4)
		textured(part("PitColumn", Vector3.new(4, 12, 4), at(x, 6, z), nil, nil, mine), "px_purpur_pillar")
		textured(part("PitColumnCap", Vector3.new(5.4, 1.2, 5.4), at(x, 12.6, z), nil, nil, mine), "px_purpur")
		endRod(x, 13.2, z, 4, true, mine)
		shulker(x - s[1] * 6, 0, z, 0, mine)
	end
	local anchor = part("MineAnchor_end_castle", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), nil, nil, mine)
	anchor:SetAttribute("LocationId", "end_castle")
	anchor:SetAttribute("MineId", "end_castle")
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
	-- the arrival, the buyer at a purpur stall beside it
	local spawn = part("LocationSpawn_end_castle", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + SPAWN_Z), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), nil, nil, mine)
	textured(spawn, "px_purpur")
	spawn:SetAttribute("LocationId", "end_castle")
	CollectionService:AddTag(spawn, "LocationSpawn")
	local sx, sz = PIT.x + 18, SPAWN_Z + 2
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(200, 180, 210)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(60, 40, 80), Color3.fromRGB(40, 30, 50), Color3.fromRGB(40, 30, 50)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "EndBuyer"
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
	part("Hood", Vector3.new(2.3, 1.2, 2.3), model.Head.CFrame * CFrame.new(0, 0.5, 0.1), Color3.fromRGB(60, 40, 80), Enum.Material.Fabric, model).CanCollide = false
	textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), nil, nil, mine), "px_purpur")
	textured(part("CounterTop", Vector3.new(2.8, 0.4, 9.4), at(sx, 3.2, sz), nil, nil, mine), "px_end_stone_bricks")
	for _, dz in ipairs({ -4.4, 4.4 }) do
		for _, dxo in ipairs({ -1.2, 5 }) do
			textured(part("StallPost", Vector3.new(0.8, 9, 0.8), at(sx + dxo, 4.5, sz + dz), nil, nil, mine), "px_purpur_pillar")
		end
	end
	textured(part("StallRoof", Vector3.new(8, 0.8, 10), at(sx + 1.9, 9.4, sz), nil, nil, mine), "px_purpur")
	endRod(sx + 1.9, 9.8, sz - 4, 2.4, true, mine)
	for _, c in ipairs({ { -0.3, -2.5, "px_end_stone_bricks" }, { -0.3, 2.5, "px_purpur" } }) do
		local crate = textured(part("Crate", Vector3.new(1.8, 1.8, 1.8), at(sx + c[1], 4.3, sz + c[2]), nil, nil, mine), c[3])
		_ = crate
	end
end
task.wait()

-- ================================================================ the Hall of Illusions (the arena)
local arena = folder("HallOfIllusions")
do
	local ax, az, R = ARENA.x, ARENA.z, ARENA.r
	-- rings of purpur in the floor, a low parapet with openings where the bridges arrive
	for k = 1, 4 do
		local rr = k * 15
		for i = 0, 47 do
			local a = i / 48 * math.pi * 2
			if rr < R then
				textured(decor(part("FloorRing", Vector3.new(2 * math.pi * rr / 48 + 0.3, 0.1, 1.4), at(ax + math.sin(a) * rr, 0.05, az + math.cos(a) * rr) * CFrame.Angles(0, a + math.pi / 2, 0), nil, nil, arena)), "px_purpur")
			end
		end
	end
	local openings = {}
	for _, br in ipairs(BRIDGES) do
		if br[2] == ARENA then
			table.insert(openings, math.atan2(br[1].x - ax, br[1].z - az))
		end
	end
	local function nearOpening(a)
		for _, o in ipairs(openings) do
			local d = (a - o) % (math.pi * 2)
			if math.min(d, math.pi * 2 - d) < 0.22 then
				return true
			end
		end
		return false
	end
	for i = 0, 71 do
		local a = (i + 0.5) / 72 * math.pi * 2
		if not nearOpening(a) then
			local rr = R - 3
			textured(part("Parapet", Vector3.new(2 * math.pi * rr / 72 + 0.4, 2, 1.4), at(ax + math.sin(a) * rr, 1, az + math.cos(a) * rr) * CFrame.Angles(0, a + math.pi / 2, 0), nil, nil, arena), "px_end_stone_bricks")
		end
	end
	-- eight mirror pillars (the charge stuns on them: names Pillar*): obsidian, violet glass faces, end rods
	for k = 0, 7 do
		local a = (k + 0.5) / 8 * math.pi * 2
		local px, pz = ax + math.sin(a) * 40, az + math.cos(a) * 40
		local cf = at(px, 0, pz) * CFrame.Angles(0, a, 0)
		part("PillarBase", Vector3.new(8, 2, 8), cf * CFrame.new(0, 1, 0), OBSIDIAN, Enum.Material.Slate, arena)
		part("Pillar", Vector3.new(5, 26, 5), cf * CFrame.new(0, 15, 0), OBSIDIAN, Enum.Material.Slate, arena)
		local mirror = part("PillarMirror", Vector3.new(4, 20, 0.3), cf * CFrame.new(0, 15, -2.6), Color3.fromRGB(180, 140, 230), Enum.Material.Glass, arena)
		mirror.Reflectance = 0.5
		mirror.Transparency = 0.2
		local rod = endRod(px, 28, pz, 5, k % 2 == 0, arena)
		_ = rod
		shulker(px + math.sin(a) * 6, 0, pz + math.cos(a) * 6, a, arena)
	end
	-- the floating halo over the arena: a ring of violet light and slowly drifting cubes (static)
	for i = 0, 63 do
		local a = i / 64 * math.pi * 2
		decor(part("Halo", Vector3.new(2 * math.pi * 30 / 64 + 0.2, 0.8, 1.4), at(ax + math.sin(a) * 30, 46, az + math.cos(a) * 30) * CFrame.Angles(0, a + math.pi / 2, 0), VIOLET, Enum.Material.Neon, arena)).Transparency = 0.25
	end
	for _ = 1, 16 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 50)
		local s = rng:NextNumber(2, 5)
		textured(decor(part("FloatingCube", Vector3.new(s, s, s), at(ax + math.sin(a) * r, rng:NextNumber(30, 60), az + math.cos(a) * r) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 1), rng:NextNumber(0, 1)), nil, nil, arena)), if rng:NextNumber() < 0.5 then "px_purpur" else "px_end_stone_bricks")
	end
	local swirl = decor(part("IllusionSwirl", Vector3.new(30, 1, 30), at(ax, 2, az), VIOLET, nil, arena))
	swirl.Transparency = 1
	emitter(swirl, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(220, 160, 255), Color3.fromRGB(140, 90, 220)),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Rate = 20,
		Lifetime = NumberRange.new(3, 5),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
	})
	-- two white rabbit statues at the main entrance (the Illusionist's minion «Кролик» [клиент])
	local entry = math.atan2(MAIN.x - ax, MAIN.z - az)
	for _, s in ipairs({ -1, 1 }) do
		local ea = entry + s * 0.3
		local rx, rz = ax + math.sin(ea) * (R - 8), az + math.cos(ea) * (R - 8)
		local base = at(rx, 0, rz) * CFrame.Angles(0, ea + math.pi, 0)
		local function b(name, size, off, col)
			part(name, size, base * CFrame.new(off[1], off[2], off[3]), col or WHITE, nil, arena)
		end
		b("RabbitPlinth", Vector3.new(6, 3, 6), { 0, 1.5, 0 }, Color3.fromRGB(200, 160, 200))
		b("RabbitBody", Vector3.new(3, 3.4, 4), { 0, 4.7, 0.4 })
		b("RabbitHead", Vector3.new(2.4, 2.2, 2.4), { 0, 7, -1.4 })
		b("RabbitEar", Vector3.new(0.6, 3, 0.4), { -0.6, 9.4, -1.4 })
		b("RabbitEar", Vector3.new(0.6, 3, 0.4), { 0.6, 9.4, -1.4 })
		b("RabbitTail", Vector3.new(1, 1, 1), { 0, 4.4, 2.6 })
		b("RabbitEye", Vector3.new(0.4, 0.4, 0.1), { -0.6, 7.3, -2.62 }, Color3.fromRGB(200, 30, 60))
		b("RabbitEye", Vector3.new(0.4, 0.4, 0.1), { 0.6, 7.3, -2.62 }, Color3.fromRGB(200, 30, 60))
	end
	local gateCf = at(ax + math.sin(entry) * (R + 4), 0, az + math.cos(entry) * (R + 4)) * CFrame.Angles(0, entry, 0)
	for _, s in ipairs({ -1, 1 }) do
		textured(part("GatePillar", Vector3.new(3, 14, 3), gateCf * CFrame.new(s * 13, 7, 0), nil, nil, arena), "px_purpur_pillar")
	end
	textured(part("GateLintel", Vector3.new(30, 3, 3), gateCf * CFrame.new(0, 15.5, 0), nil, nil, arena), "px_purpur")
	local gateSign = textured(decor(part("ArenaSign", Vector3.new(16, 2, 0.3), gateCf * CFrame.new(0, 15.5, 1.65), nil, nil, arena)), "px_end_stone_bricks")
	boardText(gateSign, "Зал иллюзий", Color3.fromRGB(110, 40, 140), { Enum.NormalId.Back, Enum.NormalId.Front })
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(ax, 1.2, az), nil, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "illusionist")
	bossSpawn:SetAttribute("ArenaRadius", R - 6)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end
task.wait()

-- ================================================================ the End City (west island): a stepped purpur spire, its hall open
local city = folder("EndCity")
do
	local cx, cz = WEST.x, WEST.z
	local tiers = { { 38, 16 }, { 30, 16 }, { 24, 16 }, { 18, 14 }, { 13, 14 }, { 9, 12 } }
	local y = 0
	for k, t in ipairs(tiers) do
		local w, h = t[1], t[2]
		if k == 1 then
			-- the ground hall: walls with a wide door on the east (towards the bridge), a floor, things inside
			local T = 2
			for _, wseg in ipairs({ { 0, -w / 2 + T / 2, w, T }, { 0, w / 2 - T / 2, w, T }, { -w / 2 + T / 2, 0, T, w } }) do
				textured(part("CityWall", Vector3.new(wseg[3], h, wseg[4]), at(cx + wseg[1], h / 2, cz + wseg[2]), nil, nil, city), "px_purpur")
			end
			for _, s in ipairs({ -1, 1 }) do
				textured(part("CityWall", Vector3.new(T, h, w / 2 - 5), at(cx + w / 2 - T / 2, h / 2, cz + s * (w / 4 + 2.5)), nil, nil, city), "px_purpur")
			end
			textured(part("DoorLintel", Vector3.new(T, h - 9, 10), at(cx + w / 2 - T / 2, 9 + (h - 9) / 2, cz), nil, nil, city), "px_purpur_pillar")
			textured(part("CityFloor", Vector3.new(w - 2, 0.3, w - 2), at(cx, 0.15, cz), nil, nil, city), "px_end_stone_bricks")
			shulker(cx - w / 2 + 4, 0.3, cz - w / 2 + 4, 0, city)
			shulker(cx - w / 2 + 4, 0.3, cz + w / 2 - 4, 0, city)
			for _, z in ipairs({ -5, 5 }) do
				textured(part("Chest", Vector3.new(2.4, 2, 2), at(cx - w / 2 + 3, 1.3, cz + z), nil, nil, city), "px_purpur")
			end
			banner(at(cx - w / 2 + T + 0.2, 7, cz) * CFrame.Angles(0, math.pi / 2, 0), city)
			endRod(cx, 0.3, cz, 3, true, city)
		else
			textured(part("CityTier", Vector3.new(w, h, w), at(cx, y + h / 2, cz), nil, nil, city), "px_purpur")
			for _, s in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				for wy = y + 4, y + h - 4, 6 do
					decor(part("CityWindow", Vector3.new(if s[1] ~= 0 then 0.3 else 3, 3, if s[2] ~= 0 then 0.3 else 3), at(cx + s[1] * (w / 2 + 0.05), wy, cz + s[2] * (w / 2 + 0.05)), Color3.fromRGB(200, 120, 220), Enum.Material.Glass, city)).Transparency = 0.2
				end
			end
		end
		-- the flat roof cap overhanging the tier, end rods at its corners, a banner on the east face
		textured(part("CityRoof", Vector3.new(w + 4, 1.4, w + 4), at(cx, y + h + 0.7, cz), nil, nil, city), "px_end_stone_bricks")
		for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
			endRod(cx + s[1] * (w / 2 + 1.4), y + h + 1.4, cz + s[2] * (w / 2 + 1.4), 3, false, city)
		end
		if k > 1 then
			banner(at(cx + w / 2 + 0.2, y + h / 2, cz) * CFrame.Angles(0, math.pi / 2, 0), city)
		end
		y += h + 1.4
	end
	-- side turrets, shulkers at the corners of the island plaza
	for _, s in ipairs({ -1, 1 }) do
		local tx, tz = cx - 4, cz + s * 34
		textured(part("Turret", Vector3.new(8, 22, 8), at(tx, 11, tz), nil, nil, city), "px_purpur_pillar")
		textured(part("TurretRoof", Vector3.new(11, 1.4, 11), at(tx, 22.7, tz), nil, nil, city), "px_end_stone_bricks")
		endRod(tx, 23.4, tz, 4, true, city)
		shulker(tx + 7, 0, tz, 0, city)
	end
	zoneSign(cx + 44, cz + 14, "Город Края", math.pi / 2)
end
task.wait()

-- ================================================================ the chorus garden and the crystal pillars (east island)
local garden = folder("ChorusGarden")
do
	local cx, cz = EAST.x, EAST.z
	for _ = 1, 26 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(10, 48)
		chorus(cx + math.sin(a) * r, 0, cz + math.cos(a) * r, rng:NextInteger(2, 5), garden)
	end
	-- four obsidian pillars with caged end crystals
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + 0.4
		local px, pz = cx + math.sin(a) * 30, cz + math.cos(a) * 30
		local h = 30 + k * 7
		part("ObsidianPillar", Vector3.new(7, h, 7), at(px, h / 2, pz), OBSIDIAN, Enum.Material.Slate, garden)
		for _, e in ipairs({ { -1.8, -1.8 }, { 1.8, -1.8 }, { -1.8, 1.8 }, { 1.8, 1.8 } }) do
			part("CageBar", Vector3.new(0.3, 5, 0.3), at(px + e[1], h + 2.5, pz + e[2]), IRON, Enum.Material.Metal, garden)
		end
		part("CageTop", Vector3.new(4, 0.3, 4), at(px, h + 5.1, pz), IRON, Enum.Material.Metal, garden).Transparency = 0.4
		local crystal = decor(part("EndCrystal", Vector3.new(2, 2, 2), at(px, h + 2.6, pz) * CFrame.Angles(0.6, 0.7, 0.3), CRYSTAL, Enum.Material.Neon, garden))
		decor(part("EndCrystalFrame", Vector3.new(2.8, 2.8, 2.8), crystal.CFrame * CFrame.Angles(0.4, 0.4, 0), Color3.fromRGB(240, 220, 255), Enum.Material.Glass, garden)).Transparency = 0.6
		light(crystal, 26, 1.4, CRYSTAL)
		emitter(crystal, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(CRYSTAL),
			LightEmission = 1,
			Size = NumberSequence.new(0.4, 0),
			Rate = 6,
			Lifetime = NumberRange.new(1.5, 2.5),
			Speed = NumberRange.new(1, 3),
			SpreadAngle = Vector2.new(180, 180),
		})
		shulker(px + 6, 0, pz, 0, garden)
	end
	zoneSign(cx - 44, cz + 14, "Сад хоруса", math.pi / 2)
end

-- ================================================================ the End ship moored at the main island
local ship = folder("EndShip")
do
	local sx, sz = SHIP.x, SHIP.z
	local hullY = -4
	-- the hull: a keel, sides narrowing to the bow, a deck at the level of the gangway
	for k = 0, 8 do
		local z = sz - 28 + k * 7
		local w = 14 - math.abs(k - 4.5) * 1.6
		textured(part("Hull", Vector3.new(w, 8, 7.2), at(sx, hullY, z), nil, nil, ship), "px_purpur")
		textured(part("Keel", Vector3.new(w - 6, 4, 7.2), at(sx, hullY - 6, z), nil, nil, ship), "px_purpur_pillar")
	end
	textured(part("Deck", Vector3.new(12, 1, 56), at(sx, 0.5, sz), nil, nil, ship), "px_end_stone_bricks")
	for _, s in ipairs({ -1, 1 }) do
		textured(part("Gunwale", Vector3.new(1, 2, 56), at(sx + s * 6.5, 2, sz), nil, nil, ship), "px_purpur")
	end
	-- the stern cabin, two masts with banners, the dragon head at the prow
	textured(part("Cabin", Vector3.new(12, 8, 10), at(sx, 5, sz + 22), nil, nil, ship), "px_purpur")
	textured(part("CabinRoof", Vector3.new(14, 1.2, 12), at(sx, 9.6, sz + 22), nil, nil, ship), "px_end_stone_bricks")
	for _, z in ipairs({ -10, 6 }) do
		textured(part("Mast", Vector3.new(1.6, 26, 1.6), at(sx, 14, sz + z), nil, nil, ship), "px_purpur_pillar")
		banner(at(sx + 1, 20, sz + z) * CFrame.Angles(0, math.pi / 2, 0), ship)
		endRod(sx, 27, sz + z, 3, false, ship)
	end
	local head = at(sx, 3, sz - 33)
	part("DragonHead", Vector3.new(6, 5, 7), head, Color3.fromRGB(20, 16, 26), nil, ship)
	part("DragonSnout", Vector3.new(4, 3, 5), head * CFrame.new(0, -0.6, -5.6), Color3.fromRGB(20, 16, 26), nil, ship)
	for _, s in ipairs({ -1, 1 }) do
		part("DragonHorn", Vector3.new(0.8, 3, 0.8), head * CFrame.new(s * 1.8, 3.4, 1.6) * CFrame.Angles(-0.4, 0, 0), Color3.fromRGB(50, 44, 60), nil, ship)
		decor(part("DragonEye", Vector3.new(1.2, 0.6, 0.2), head * CFrame.new(s * 1.6, 1, -3.55), Color3.fromRGB(230, 120, 255), Enum.Material.Neon, ship))
	end
	shulker(sx - 3, 1, sz - 18, 0, ship)
	shulker(sx + 3, 1, sz + 12, 0, ship)
	-- the gangway from the island to the ship's side
	local gx0, gx1 = 70, sx - 6
	textured(part("Gangway", Vector3.new(gx1 - gx0, 1, 10), at((gx0 + gx1) / 2, 0.1, sz - 2), nil, nil, ship), "px_purpur")
	for _, s in ipairs({ -1, 1 }) do
		textured(part("GangwayRail", Vector3.new(gx1 - gx0, 1.4, 0.8), at((gx0 + gx1) / 2, 1.2, sz - 2 + s * 4.6), nil, nil, ship), "px_end_stone_bricks")
	end
	zoneSign(gx0 + 4, sz - 12, "Корабль Края", 0)
end
task.wait()

-- ================================================================ decor over the main island: chorus, rods, shulkers at corners, floating debris
do
	local deco = folder("Decor")
	local made = 0
	for _ = 1, 4000 do
		if made >= 70 then
			break
		end
		local x, z = rng:NextNumber(-130, 130), rng:NextNumber(-90, 190)
		local s, d = islandAt(x, z)
		if s == MAIN and d < 0.88 and not (math.abs(x - PIT.x) < PIT.hole + 18 and math.abs(z - PIT.z) < PIT.hole + 18) and math.abs(x) > 14 then
			made += 1
			local roll = rng:NextNumber()
			if roll < 0.3 then
				chorus(x, 0, z, rng:NextInteger(2, 4), deco)
			elseif roll < 0.6 then
				endRod(x, 0, z, 3, made % 6 == 0, deco)
			elseif roll < 0.75 then
				shulker(x, 0, z, rng:NextNumber(0, 6.28), deco)
			else
				local sz = rng:NextNumber(2, 5)
				textured(part("EndRock", Vector3.new(sz, sz * 0.8, sz), at(x, sz * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 2), 0.1), nil, nil, deco), "px_end_stone")
			end
		end
	end
	-- floating end-stone debris in the void between the islands
	for _ = 1, 40 do
		local x, z = rng:NextNumber(-300, 300), rng:NextNumber(-300, 300)
		if not islandAt(x, z) then
			local s = rng:NextNumber(3, 9)
			textured(decor(part("Debris", Vector3.new(s, s * 0.7, s), at(x, rng:NextNumber(-60, 60), z) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 6), rng:NextNumber(0, 1)), nil, nil, deco)), "px_end_stone")
		end
	end
	-- chorus and crystals on the islets
	for i, s in ipairs(ISLETS) do
		if i % 2 == 0 then
			chorus(s[1], s.y, s[2], rng:NextInteger(2, 4), deco)
		else
			local c = decor(part("IsletCrystal", Vector3.new(2, 2, 2), at(s[1], s.y + 3, s[2]) * CFrame.Angles(0.6, 0.7, 0.3), CRYSTAL, Enum.Material.Neon, deco))
			_ = c
		end
	end
	-- the stars and ender particles in the dark
	for _, spot in ipairs({ { 0, 0 }, { -200, -150 }, { 200, -150 }, { 0, 200 }, { -220, 150 }, { 220, 150 } }) do
		local p = decor(part("Stars", Vector3.new(200, 1, 200), at(spot[1], 120, spot[2]), nil, nil, deco))
		p.Transparency = 1
		emitter(p, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(220, 180, 255)),
			LightEmission = 1,
			Size = NumberSequence.new(0.6),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }),
			Rate = 12,
			Lifetime = NumberRange.new(6, 10),
			Speed = NumberRange.new(0, 0.5),
		})
		local q = decor(part("EnderMotes", Vector3.new(150, 1, 150), at(spot[1], 2, spot[2]), nil, nil, deco))
		q.Transparency = 1
		emitter(q, {
			Texture = "rbxasset://textures/particles/sparkles_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(200, 120, 255)),
			LightEmission = 1,
			Size = NumberSequence.new(0.3, 0),
			Rate = 10,
			Lifetime = NumberRange.new(3, 5),
			Speed = NumberRange.new(0.5, 1.5),
			Acceleration = Vector3.new(0, 0.6, 0),
		})
	end
	-- the void net (LavaService: VoidCatch → back to the arrival) and the invisible walls round the map
	local net = part("VoidCatch", Vector3.new(660, 10, 660), at(0, -110, 0), nil, nil, deco)
	net.Transparency = 1
	net.CanCollide = false
	net.CanTouch = false
	net.CastShadow = false
	net:SetAttribute("LocationId", "end_castle")
	CollectionService:AddTag(net, "VoidCatch")
	local E = 318
	for _, w in ipairs({ { 0, E, 2 * E, 4 }, { 0, -E, 2 * E, 4 }, { E, 0, 4, 2 * E }, { -E, 0, 4, 2 * E } }) do
		local p = part("EdgeWall", Vector3.new(w[3], 500, w[4]), at(w[1], 100, w[2]), nil, nil, deco)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
end

-- the murk [меню: окутана мраком]: dim violet light, a dark haze (IndoorLighting, Persistent so it always applies)
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(part("VoidAir", Vector3.new(660, 400, 660), at(0, 40, 0), nil, nil, air))
volume.Transparency = 1
volume:SetAttribute("Ambient", Color3.fromRGB(130, 115, 150))
volume:SetAttribute("Exposure", -0.1)
volume:SetAttribute("Haze", 0.32)
volume:SetAttribute("ClockTime", 0) -- the End has no day: a night sky with stars over the void
volume:SetAttribute("Brightness", 1)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(46, 30, 66))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(22, 14, 36))
CollectionService:AddTag(volume, "IndoorLighting")

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
print(("[build-end-castle] built: %d instances (runs %d)"):format(total, count))
return ("built %d instances, runs %d"):format(total, count)
