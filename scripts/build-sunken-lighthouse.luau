--!nocheck
-- Builds the Затопленный маяк, level 13, PvP [меню]. «Старинный затопленный маяк возвышается из океана, его стены
-- покрыты водорослями, а вокруг бьются волны» [меню]. Blocks: бирюзовый цемент 70 %, призмарин 30 % [меню].
-- Boss: Посейдон — «владыка морей, дремавший на дне Затопленного маяка; его трезубец призывает молнии» [клиент].
-- [владелец 23.10: «следующий этаж с такой же мощностью»] An archipelago in real Terrain water (you can swim):
--   * the main island: the mine (drained ocean ruins of prismarine) with the arrival and the buyer by its rim
--     [владелец 23.10: старт и скупщик рядом с шахтой], a beach, a pier with rowboats, paths, lamps, benches;
--   * the headland with the old lighthouse — a round tower of white and red bands with algae on the lower half, a
--     door, windows, a gallery and a lantern room with a beam; a spiral stair inside goes UP to the gallery and
--     DOWN through a shaft to the sanctum of Poseidon on the sea floor — the arena (a prismarine hall with a glass
--     roof, the sea above it, pillars, sea lanterns, the throne with a giant trident);
--   * a fishing village on stilts on the east island (a measured plank bridge to it), a shipwreck on the western
--     rocks, a coral reef in the south-west shallows, kelp, ocean ruins, sea stacks round the edge;
--   * every name at its place; edges unclimbable (sea stacks + invisible walls); few soft lights.
-- A separate zone at X = 6400 (StreamingEnabled). Run in Studio (Edit) via scripts/studio-loader.luau after
-- build-textures. Idempotent: replaces Workspace.SunkenLighthouse and the Terrain water of its region.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local texModule = game:GetService("ReplicatedStorage").Shared.Config.textures:Clone()
local textures = require(texModule)
texModule:Destroy()
local TEX = textures.textures

local old = workspace:FindFirstChild("SunkenLighthouse")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "SunkenLighthouse"
root:SetAttribute("LocationId", "sunken_lighthouse")
root.Parent = workspace

local BX, BZ = 6400, 0
local B = 4
local rng = Random.new(20261313)
local STONE = Color3.fromRGB(130, 130, 128)
local WOOD = Color3.fromRGB(110, 80, 52)
local IRON = Color3.fromRGB(60, 60, 66)
local WHITE = Color3.fromRGB(236, 236, 240)
local RED = Color3.fromRGB(190, 40, 36)
local GOLD = Color3.fromRGB(240, 190, 60)
local LAMP = Color3.fromRGB(255, 205, 140)
local SEA = Color3.fromRGB(150, 230, 240)

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
local LIGHT_POWER, LIGHT_RANGE = 0.45, 0.7 -- [урок Пирамиды] few, soft lights
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
local ALL_FACES = { Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }
local function glow(name, size, cf, color, texKey, parent)
	local p = part(name, size, cf, color, Enum.Material.Neon, parent)
	if TEX[texKey] then
		for _, face in ipairs(ALL_FACES) do
			local t = Instance.new("Texture")
			t.Texture = TEX[texKey]
			t.Face = face
			t.StudsPerTileU, t.StudsPerTileV = B, B
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
local PIT = { x = 0, z = 40, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json sunken_lighthouse.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local SPAWN_Z = PIT.z + PIT.hole + 12
local LH = { x = 0, z = -110 } -- the lighthouse
local SANCT = { x0 = -48, x1 = 48, z0 = -188, z1 = -92, floor = -50, ceil = -26 } -- the sanctum of Poseidon
local VILLAGE = { x = 176, z = 60, r = 46 }
local WRECK = { x = -176, z = -30, r = 26 }
local REEF = { x = -130, z = 170, r = 60 }
local ISLANDS = {
	{ 0, 30, 112 },
	{ LH.x, LH.z, 36 },
	{ VILLAGE.x, VILLAGE.z, VILLAGE.r },
	{ WRECK.x, WRECK.z, WRECK.r },
	{ -160, 120, 14 },
	{ 150, -170, 20 },
}
local TRAILS = {
	{ { 14, SPAWN_Z }, { 84, SPAWN_Z - 10 }, { 86, -30 }, { 30, -70 }, { 0, -88 } }, -- the arrival → the lighthouse
	{ { 86, 60 }, { 112, 60 } }, -- → the bridge to the village
	{ { -14, SPAWN_Z }, { -84, SPAWN_Z - 14 }, { -88, 0 }, { -106, -20 } }, -- → the western beach (the wreck in view)
	{ { 0, SPAWN_Z + 6 }, { 0, 146 } }, -- → the pier
}

-- ================================================================ the grid (8-stud cells): land, sea, the pit, the lighthouse shaft
local C = 8
local X0, Z0 = -320, -320
local NX, NZ = 80, 80
local function landR(x, z)
	-- how far inside the nearest island (positive = land)
	local best = -math.huge
	for _, s in ipairs(ISLANDS) do
		local d = math.sqrt((x - s[1]) ^ 2 + (z - s[2]) ^ 2)
		local r = s[3] * (1 + n2(x, z, 2.2 + s[1] * 0.01, 0.035) * 0.16)
		best = math.max(best, r - d)
	end
	-- the isthmus to the headland
	best = math.max(best, 16 - segDist(x, z, 0, -60, 0, -92))
	return best
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local function inShaft(x, z)
	return math.abs(x - LH.x) < 16 and math.abs(z - LH.z) < 16
end
local function inSanct(x, z)
	return x > SANCT.x0 and x < SANCT.x1 and z > SANCT.z0 and z < SANCT.z1
end
local function onTrail(x, z)
	for _, t in ipairs(TRAILS) do
		if lineDist(t, x, z) < 4 + n2(x, z, 8.8, 0.15) then
			return true
		end
	end
	return false
end
local function flat(x, z)
	return (math.abs(x - PIT.x) < PIT.hole + 18 and math.abs(z - PIT.z) < PIT.hole + 18)
		or math.sqrt((x - VILLAGE.x) ^ 2 + (z - VILLAGE.z) ^ 2) < VILLAGE.r - 6
		or math.sqrt((x - LH.x) ^ 2 + (z - LH.z) ^ 2) < 26
end
local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local c = { x = x, z = z, land = landR(x, z) }
		if inHole(x, z) then
			c.kind = "hole"
		elseif inShaft(x, z) then
			c.kind = "shaft"
		elseif c.land > 0 then
			c.kind = "land"
			c.path = onTrail(x, z)
			local h = 0
			if c.land < 10 then
				h = if c.land < 5 then 1 else 2 -- the beach
				c.beach = true
			elseif not (flat(x, z) or c.path) then
				h = 4 * math.clamp(math.floor(1 + n2(x, z, 3.3, 0.04) * 1.6 + n2(x, z, 6.1, 0.1) * 0.6), 0, 2)
			end
			c.top = h
		else
			c.kind = "sea"
			local shallow = math.clamp(-c.land / 50, 0, 1)
			local depth = 4 * math.floor((4 + 28 * shallow + n2(x, z, 5.5, 0.04) * 6) / 4 + 0.5)
			if math.sqrt((x - REEF.x) ^ 2 + (z - REEF.z) ^ 2) < REEF.r then
				depth = 8
				c.reef = true
			end
			c.seabed = -math.clamp(depth, 4, 36)
			if inSanct(x, z) then
				c.seabed = SANCT.ceil + 2 -- the sea sits on the glass roof of the sanctum
				c.overSanct = true
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
	return if c and c.kind == "land" then c.top else 0
end

-- ================================================================ the ground, the sea bed and the water (Terrain)
local terrain = folder("Terrain")
local T = workspace.Terrain
-- clear this region's terrain first (idempotent), in slices so Studio stays responsive
for zz = -320, 280, 40 do
	T:FillBlock(CFrame.new(BX, -20, BZ + zz + 20), Vector3.new(640, 120, 40), Enum.Material.Air)
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
			T:FillBlock(CFrame.new(BX + (x0 + x1) / 2, r.y0 / 2, BZ + (z0 + z1) / 2), Vector3.new(x1 - x0, -r.y0, z1 - z0), Enum.Material.Water)
		else
			box(r.name, x0, r.y0, z0, x1, r.y1, z1, r.variant, r.tint, terrain)
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
		if c.kind == "land" then
			local under = if inSanct(c.x, c.z) then SANCT.ceil + 2 else -40
			local v, tint
			if c.path then
				v, tint = "px_gravel", Color3.fromRGB(220, 210, 190)
			elseif c.beach then
				v, tint = "px_sand", nil
			elseif n2(c.x, c.z, 7.7, 0.06) > 0.45 then
				v, tint = "px_stone", nil
			else
				v, tint = "px_grass_top", Color3.fromRGB(150, 200, 120)
			end
			push(ix, "body", "Ground", under, c.top - 1, if c.beach then "px_sand" else "px_stone", if c.beach then Color3.fromRGB(220, 210, 180) else nil)
			push(ix, "top", "GroundTop", c.top - 1, c.top, v, tint)
			used.body, used.top = true, true
		elseif c.kind == "sea" then
			if not c.overSanct then
				push(ix, "bed", "SeaBed", -44, c.seabed, "px_sand", if c.reef then Color3.fromRGB(240, 230, 200) else Color3.fromRGB(200, 195, 170))
				used.bed = true
			end
			push(ix, "water", "Water", c.seabed, 0, nil, nil, true)
			used.water = true
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
local function lamp(x, z, h, parent)
	local y = floorAt(x, z)
	part("LampPost", Vector3.new(0.5, h, 0.5), at(x, y + h / 2, z), IRON, Enum.Material.Metal, parent or props)
	part("LampCap", Vector3.new(1.4, 0.4, 1.4), at(x, y + h + 1.1, z), IRON, Enum.Material.Metal, parent or props)
	local l = decor(part("Lamp", Vector3.new(1, 1.4, 1), at(x, y + h + 0.3, z), LAMP, Enum.Material.Neon, parent or props))
	light(l, 22, 1.2, LAMP)
end
local function zoneSign(x, z, text, yaw)
	local y = floorAt(x, z)
	part("SignPost", Vector3.new(0.6, 5, 0.6), at(x, y + 2.5, z), WOOD, Enum.Material.Wood, props)
	local board = textured(part("ZoneSign", Vector3.new(7, 1.8, 0.4), at(x, y + 4.6, z) * CFrame.Angles(0, yaw or 0, 0), nil, nil, props), "px_spruce_planks")
	boardText(board, text, Color3.fromRGB(255, 240, 210))
end
local function rowboat(x, z, yaw, parent)
	local base = at(x, 0.2, z) * CFrame.Angles(0, yaw, 0)
	textured(part("BoatBottom", Vector3.new(2.6, 0.5, 7), base, nil, nil, parent), "px_spruce_planks")
	for _, s in ipairs({ -1, 1 }) do
		textured(part("BoatSide", Vector3.new(0.4, 1.2, 7), base * CFrame.new(s * 1.4, 0.6, 0) * CFrame.Angles(0, 0, s * -0.2), nil, nil, parent), "px_spruce_planks")
		part("Oar", Vector3.new(0.25, 0.25, 5), base * CFrame.new(s * 1.8, 0.9, 0.5) * CFrame.Angles(0, s * 0.4, 0), WOOD, Enum.Material.Wood, parent)
	end
	textured(part("BoatSeat", Vector3.new(2.4, 0.3, 0.8), base * CFrame.new(0, 0.7, 0), nil, nil, parent), "px_spruce_planks")
end
local function kelp(x, z, bottom, top, parent)
	local y = bottom
	while y < top - 1 do
		local len = math.min(rng:NextNumber(2, 3.5), top - 1 - y)
		decor(part("Kelp", Vector3.new(0.8, len, 0.3), at(x + math.sin(y * 0.6) * 0.5, y + len / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(50, 120, 50), Enum.Material.Grass, parent or props))
		y += len
	end
end

-- ================================================================ the mine: drained ocean ruins of prismarine
local mine = folder("Mine")
do
	local w, h = PIT.w, PIT.depth * B
	local mx, mz = PIT.x, PIT.z
	local function bedrock(p)
		textured(p, "px_dark_prismarine")
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
		textured(part("PitRim", r[1], r[2], nil, nil, mine), "px_prismarine_bricks")
	end
	-- broken prismarine walls of the ruin round the rim, with gaps where the paths come in, sea lanterns on posts
	for _, s in ipairs({ -1, 1 }) do
		for _, half in ipairs({ -1, 1 }) do
			local a, b = 10, edge - 4
			for t = a, b, 4 do
				local hgt = 1.6 + math.abs(n2(t, s * half, 1.1, 0.3)) * 4
				textured(part("RuinWall", Vector3.new(4, hgt, 1.6), at(mx + half * (t + 2), 0.6 + hgt / 2, mz + s * edge), nil, nil, mine), "px_prismarine_bricks")
				textured(part("RuinWall", Vector3.new(1.6, hgt, 4), at(mx + s * edge, 0.6 + hgt / 2, mz + half * (t + 2)), nil, nil, mine), "px_prismarine_bricks")
			end
		end
	end
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, z = mx + s[1] * (edge + 4), mz + s[2] * (edge + 4)
		textured(part("RuinColumn", Vector3.new(4, 10, 4), at(x, 5, z), nil, nil, mine), "px_dark_prismarine")
		local g = glow("SeaLantern", Vector3.new(4, 4, 4), at(x, 12, z), SEA, "sea_lantern", mine)
		light(g, 30, 1.2, Color3.fromRGB(170, 240, 255))
	end
	local anchor = part("MineAnchor_sunken_lighthouse", Vector3.new(w, 0.2, w), at(mx, -0.1, mz), nil, nil, mine)
	anchor:SetAttribute("LocationId", "sunken_lighthouse")
	anchor:SetAttribute("MineId", "sunken_lighthouse")
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

-- ================================================================ the arrival and the buyer by the mine
local harbour = folder("Harbour")
do
	local spawn = part("LocationSpawn_sunken_lighthouse", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX + PIT.x, 0.5, BZ + SPAWN_Z), Vector3.new(BX + PIT.x, 0.5, BZ + PIT.z)), nil, nil, harbour)
	textured(spawn, "px_prismarine_bricks")
	spawn:SetAttribute("LocationId", "sunken_lighthouse")
	CollectionService:AddTag(spawn, "LocationSpawn")
	local sx, sz = PIT.x + 18, SPAWN_Z + 2
	local desc = Instance.new("HumanoidDescription")
	local skin = Color3.fromRGB(210, 160, 120)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor, desc.LeftLegColor, desc.RightLegColor = Color3.fromRGB(230, 200, 40), Color3.fromRGB(50, 60, 90), Color3.fromRGB(50, 60, 90)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = "SeaBuyer"
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
	model.Parent = harbour
	model:PivotTo(CFrame.lookAt(Vector3.new(BX + sx + 3, 3, BZ + sz), Vector3.new(BX + PIT.x, 3, BZ + SPAWN_Z)))
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = model:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, "SellPoint")
	sign(hrp, "Скупщик блоков", 4.5, Color3.fromRGB(255, 55, 55))
	part("SouWester", Vector3.new(2.6, 0.3, 2.8), model.Head.CFrame * CFrame.new(0, 0.65, 0.2), Color3.fromRGB(230, 200, 40), Enum.Material.Fabric, model).CanCollide = false
	textured(part("Counter", Vector3.new(2.4, 3, 9), at(sx, 1.5, sz), nil, nil, harbour), "px_spruce_planks")
	for _, dz in ipairs({ -4.4, 4.4 }) do
		for _, dx in ipairs({ -1.2, 5 }) do
			textured(part("StallPost", Vector3.new(0.6, 9, 0.6), at(sx + dx, 4.5, sz + dz), nil, nil, harbour), "px_spruce_planks")
		end
	end
	for k = 0, 5 do
		decor(part("Awning", Vector3.new(7.4, 0.15, 1.6), at(sx + 1.9, 9.1 - k * 0.12, sz - 4.5 + k * 1.6 + 0.8) * CFrame.Angles(0, 0, -0.15), if k % 2 == 0 then Color3.fromRGB(40, 120, 170) else WHITE, Enum.Material.Fabric, harbour))
	end
	for _, c in ipairs({ { -0.3, -2.5, "px_cyan_concrete" }, { -0.3, 2.5, "px_prismarine" } }) do
		local crate = textured(part("Crate", Vector3.new(1.8, 1.8, 1.8), at(sx + c[1], 3.9, sz + c[2]), nil, nil, harbour), "px_spruce_planks")
		textured(decor(part("CrateLoad", Vector3.new(1.4, 0.3, 1.4), crate.CFrame * CFrame.new(0, 0.9, 0), nil, nil, harbour)), c[3])
	end
	-- the pier south into the sea: planks on posts, rowboats tied up, a bell, nets and barrels
	local p0, p1 = 140, 196
	textured(part("PierDeck", Vector3.new(8, 0.8, p1 - p0), at(0, 1.6, (p0 + p1) / 2), nil, nil, harbour), "px_spruce_planks")
	for z = p0 + 2, p1, 6 do
		for _, s in ipairs({ -1, 1 }) do
			part("PierPost", Vector3.new(0.9, 34, 0.9), at(s * 3.6, -15, z), WOOD, Enum.Material.Wood, harbour)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		part("PierRail", Vector3.new(0.3, 0.3, p1 - p0), at(s * 3.8, 3.2, (p0 + p1) / 2), WOOD, Enum.Material.Wood, harbour)
	end
	rowboat(-7, 170, 0.1, harbour)
	rowboat(7, 182, -0.15, harbour)
	rowboat(-8, 190, 0.3, harbour)
	part("PierBellPost", Vector3.new(0.6, 6, 0.6), at(3, 5, p1 - 2), WOOD, Enum.Material.Wood, harbour)
	part("PierBell", Vector3.new(1.4, 1.4, 1.4), at(3, 6.6, p1 - 1), GOLD, Enum.Material.Metal, harbour)
	for k = 0, 3 do
		lamp(if k % 2 == 0 then -4 else 4, p0 + 6 + k * 14, 5, harbour)
	end
	zoneSign(6, 140, "Причал", 0)
end
task.wait()

-- ================================================================ the lighthouse: tower, stair up and down, gallery, lantern, beam
local lighthouse = folder("Lighthouse")
local STEP_RISE, STEPS_PER_TURN = 1.4, 16
local DOOR_Y = 6
do
	local lx, lz = LH.x, LH.z
	-- the rock platform it stands on: mossy stone, steps down to the path
	-- (each tier is four slabs round a 14 × 14 opening: the spiral stair passes through the base)
	for k = 0, 2 do
		local r = 22 - k * 3
		local v = if k == 0 then "px_mossy_cobblestone" else "px_mossy_stone_bricks"
		local y0 = k * 2
		for _, b in ipairs({ { -r, -7, -r, r }, { 7, r, -r, r }, { -7, 7, -r, -7 }, { -7, 7, 7, r } }) do
			box("LighthouseBase", lx + b[1], y0, lz + b[3], lx + b[2], y0 + 2, lz + b[4], v, nil, lighthouse)
		end
	end
	-- the rock round the shaft between the sanctum ceiling and the base (outside the shaft ring)
	for _, b in ipairs({ { 7, 16, 7, 16 }, { -16, -7, 7, 16 }, { 7, 16, -16, -7 }, { -16, -7, -16, -7 }, { 9.8, 16, -7, 7 }, { -16, -9.8, -7, 7 }, { -7, 7, 9.8, 16 }, { -7, 7, -16, -9.8 } }) do
		box("ShaftRock", lx + b[1], SANCT.ceil, lz + b[3], lx + b[2], 0, lz + b[4], "px_stone", nil, lighthouse)
	end
	-- the tower: a ring of block segments, bands of white and red, algae on the lower half; door and windows open
	local N = 28
	local BAND = 8
	local bands = 10
	local doorA = 0 -- the door faces south (+z)
	local function ring(y0, y1, r, variantFor, skip)
		for i = 0, N - 1 do
			local a = (i + 0.5) / N * math.pi * 2
			if not skip(a, i) then
				local seg = 2 * math.pi * r / N + 0.35
				local v, tint = variantFor(a, i)
				textured(part("TowerWall", Vector3.new(seg, y1 - y0, 1.6), CFrame.new(BX + lx + math.sin(a) * r, (y0 + y1) / 2, BZ + lz + math.cos(a) * r) * CFrame.Angles(0, a, 0), nil, nil, lighthouse), v, tint)
			end
		end
	end
	local function angDiff(a, b)
		local d = (a - b) % (math.pi * 2)
		return math.min(d, math.pi * 2 - d)
	end
	for b = 0, bands - 1 do
		local y0 = DOOR_Y + b * BAND
		local r = 9 - b * 0.22
		local white = b % 2 == 0
		ring(y0, y0 + BAND, r, function(a, i)
			if b < 4 and n2(i, b, 3.3, 0.5) > 0.1 then
				return "px_mossy_stone_bricks", nil -- algae over the lower half [меню: стены покрыты водорослями]
			end
			return if white then "px_white_stone_bricks" else "px_red_brick", nil
		end, function(a, i)
			if b == 0 and angDiff(a, doorA) < 0.25 then
				return true -- the door
			end
			return b > 0 and b % 2 == 1 and angDiff(a, (b * 1.7) % (math.pi * 2)) < 0.12 -- a window
		end)
	end
	local topY = DOOR_Y + bands * BAND
	local rTop = 9 - bands * 0.22
	-- the lintel over the door, the door frame
	textured(part("DoorLintel", Vector3.new(4, 1.4, 2), at(lx, DOOR_Y + 7, lz + 9.2), nil, nil, lighthouse), "px_dark_prismarine")
	local nameBoard = textured(decor(part("LighthouseName", Vector3.new(6, 1.4, 0.3), at(lx, DOOR_Y + 9.2, lz + 9.95), nil, nil, lighthouse)), "px_white_stone_bricks")
	boardText(nameBoard, "Маяк", Color3.fromRGB(40, 60, 120), { Enum.NormalId.Back })
	-- kelp and vines hanging on the outside of the lower bands
	for _ = 1, 24 do
		local a = rng:NextNumber(0, 6.28)
		if angDiff(a, doorA) > 0.4 then
			local y = DOOR_Y + rng:NextNumber(6, 30)
			local len = rng:NextNumber(3, 8)
			decor(part("Algae", Vector3.new(0.6, len, 0.2), CFrame.new(BX + lx + math.sin(a) * 9.9, y - len / 2, BZ + lz + math.cos(a) * 9.9) * CFrame.Angles(0, a, 0), Color3.fromRGB(60, 120, 60), Enum.Material.Grass, lighthouse))
		end
	end
	-- the shaft below the door level: a prismarine ring down to the sanctum ceiling
	ring(SANCT.ceil, DOOR_Y, 9, function()
		return "px_prismarine_bricks", nil
	end, function()
		return false
	end)
	-- the spiral stair: from the sanctum floor up to the gallery, round a central column; the step at the door
	-- level faces the door
	local stepBottom = SANCT.floor
	local nSteps = math.floor((topY - stepBottom) / STEP_RISE)
	local kDoor = math.floor((DOOR_Y - stepBottom) / STEP_RISE + 0.5) - 1
	local dA = math.pi * 2 / STEPS_PER_TURN
	local a0 = doorA - kDoor * dA
	textured(part("StairColumn", Vector3.new(3, topY - stepBottom, 3), at(lx, (topY + stepBottom) / 2, lz), nil, nil, lighthouse), "px_white_stone_bricks")
	for k = 0, nSteps - 1 do
		local a = a0 + k * dA
		local y = stepBottom + (k + 1) * STEP_RISE
		textured(part("SpiralStep", Vector3.new(3, 0.8, 6.2), CFrame.new(BX + lx + math.sin(a) * 4.6, y - 0.4, BZ + lz + math.cos(a) * 4.6) * CFrame.Angles(0, a + math.pi / 2, 0), nil, nil, lighthouse), if y < DOOR_Y then "px_prismarine_bricks" else "px_spruce_planks")
	end
	-- a landing between the door and the stair, lanterns up the tower
	textured(part("DoorLanding", Vector3.new(4, 0.8, 3), at(lx, DOOR_Y - 0.4, lz + 7.4), nil, nil, lighthouse), "px_spruce_planks")
	for k = 0, 9 do
		local y = DOOR_Y + 4 + k * 8
		local a = k * 2.2
		local l = decor(part("WallLantern", Vector3.new(0.8, 1, 0.8), CFrame.new(BX + lx + math.sin(a) * 7.6, y, BZ + lz + math.cos(a) * 7.6), LAMP, Enum.Material.Neon, lighthouse))
		light(l, 16, 1, LAMP)
	end
	-- the gallery: a platform ring with a railing, the floor of the lantern room over the stair top
	-- the gallery floor: a ring outside the tower, and inside it 2×2 tiles with a hatch over the last steps
	for _, b in ipairs({ { -13, -7, -13, 13 }, { 7, 13, -13, 13 }, { -7, 7, -13, -7 }, { -7, 7, 7, 13 } }) do
		box("GalleryFloor", lx + b[1], topY, lz + b[3], lx + b[2], topY + 1, lz + b[4], "px_dark_prismarine", nil, lighthouse)
	end
	local aEnd = a0 + (nSteps - 1) * dA
	for gx = -6, 4, 2 do
		for gz = -6, 4, 2 do
			local tx, tz = gx + 1, gz + 1
			local r = math.sqrt(tx * tx + tz * tz)
			local a = math.atan2(tx, tz)
			local d = (a - aEnd) % (math.pi * 2)
			local inHatch = r > 1.6 and (d > math.pi * 2 - 5 * dA or d < 0.6 * dA)
			if not inHatch then
				box("GalleryTile", lx + gx, topY, lz + gz, lx + gx + 2, topY + 1, lz + gz + 2, "px_dark_prismarine", nil, lighthouse)
			end
		end
	end
	for i = 0, 31 do
		local a = i / 32 * math.pi * 2
		part("GalleryRail", Vector3.new(0.3, 3, 0.3), at(lx + math.sin(a) * 12.4, topY + 2.5, lz + math.cos(a) * 12.4), IRON, Enum.Material.Metal, lighthouse)
	end
	for _, s in ipairs({ -1, 1 }) do
		part("GalleryTopRail", Vector3.new(25, 0.3, 0.3), at(lx, topY + 4, lz + s * 12.4), IRON, Enum.Material.Metal, lighthouse)
		part("GalleryTopRail", Vector3.new(0.3, 0.3, 25), at(lx + s * 12.4, topY + 4, lz), IRON, Enum.Material.Metal, lighthouse)
	end
	-- the stair comes up through a hatch: leave the floor open over the last turn (a hole cut by four slabs)
	-- (simpler: the top steps reach the floor height; the floor part is lifted by its thickness above them)
	-- the lantern room: glass panes on iron frames, the lamp of sea lanterns, the beam
	local roomY = topY + 1
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local glass = i ~= 0 and part("LanternGlass", Vector3.new(3.4, 8, 0.3), CFrame.new(BX + lx + math.sin(a) * 6, roomY + 4, BZ + lz + math.cos(a) * 6) * CFrame.Angles(0, a, 0), Color3.fromRGB(200, 240, 250), Enum.Material.Glass, lighthouse)
		if glass then
			glass.Transparency = 0.55 -- (pane 0 is left open: the door out to the gallery)
		end
		part("LanternFrame", Vector3.new(0.4, 8, 0.4), CFrame.new(BX + lx + math.sin(a + 0.26) * 6.1, roomY + 4, BZ + lz + math.cos(a + 0.26) * 6.1), IRON, Enum.Material.Metal, lighthouse)
	end
	local lampCore = glow("LighthouseLamp", Vector3.new(4, 4, 4), at(lx, roomY + 3, lz), SEA, "sea_lantern", lighthouse)
	light(lampCore, 70, 2.5, Color3.fromRGB(255, 245, 210))
	for _, dir in ipairs({ 0, math.pi }) do
		local beam = decor(part("LighthouseBeam", Vector3.new(3, 3, 80), at(lx, roomY + 3, lz) * CFrame.Angles(0, dir + 0.5, 0) * CFrame.new(0, 0, -42), Color3.fromRGB(255, 250, 210), Enum.Material.Neon, lighthouse))
		beam.Transparency = 0.85
		beam.CastShadow = false
	end
	for k = 0, 3 do
		part("LanternRoof", Vector3.new(14 - k * 3.2, 1.4, 14 - k * 3.2), at(lx, roomY + 8.7 + k * 1.4, lz), Color3.fromRGB(70, 130, 110), Enum.Material.Metal, lighthouse)
	end
	part("Vane", Vector3.new(0.3, 4, 0.3), at(lx, roomY + 15, lz), IRON, Enum.Material.Metal, lighthouse)
	part("VaneArrow", Vector3.new(0.2, 0.6, 3), at(lx, roomY + 16.5, lz), GOLD, Enum.Material.Metal, lighthouse)
	-- the inside light of the tower
	local vol = decor(part("TowerVolume", Vector3.new(16, topY - SANCT.ceil, 16), at(lx, (topY + SANCT.ceil) / 2, lz), nil, nil, lighthouse))
	vol.Transparency = 1
	vol:SetAttribute("Ambient", Color3.fromRGB(150, 145, 140))
	vol:SetAttribute("Exposure", 0)
	CollectionService:AddTag(vol, "IndoorLighting")
end
task.wait()

-- ================================================================ the sanctum of Poseidon on the sea floor (the arena)
local sanct = folder("Sanctum")
do
	local S = SANCT
	local cx, cz = (S.x0 + S.x1) / 2, (S.z0 + S.z1) / 2
	local W, D, H = S.x1 - S.x0, S.z1 - S.z0, S.ceil - S.floor
	textured(part("SanctFloor", Vector3.new(W + 8, 4, D + 8), at(cx, S.floor - 2, cz), nil, nil, sanct), "px_dark_prismarine")
	-- a glowing water channel in a cross on the floor
	for _, s in ipairs({ { W - 12, 2 }, { 2, D - 12 } }) do
		decor(part("FloorChannel", Vector3.new(s[1], 0.12, s[2]), at(cx, S.floor + 0.06, cz - 10), Color3.fromRGB(80, 200, 230), Enum.Material.Neon, sanct)).Transparency = 0.3
	end
	-- the walls (ArenaWall: the charge stops there) with a band of sea lanterns
	for _, w in ipairs({
		{ Vector3.new(4, H + 2, D + 8), at(S.x0 - 2, S.floor + (H + 2) / 2, cz) },
		{ Vector3.new(4, H + 2, D + 8), at(S.x1 + 2, S.floor + (H + 2) / 2, cz) },
		{ Vector3.new(W, H + 2, 4), at(cx, S.floor + (H + 2) / 2, S.z0 - 2) },
		{ Vector3.new(W, H + 2, 4), at(cx, S.floor + (H + 2) / 2, S.z1 + 2) },
	}) do
		textured(part("ArenaWall", w[1], w[2], nil, nil, sanct), "px_prismarine_bricks")
	end
	for _, w in ipairs({ { S.x0 + 0.3, nil }, { S.x1 - 0.3, nil } }) do
		for z = S.z0 + 8, S.z1 - 8, 12 do
			local g = glow("WallSeaLantern", Vector3.new(0.6, 2, 2), at(w[1], S.floor + 12, z), SEA, "sea_lantern", sanct)
			if (z - S.z0) % 24 < 12 then
				light(g, 26, 1, Color3.fromRGB(150, 230, 255))
			end
		end
	end
	-- the roof: glass where the sea is above, dark prismarine under the island; beams over it all
	for iz = 0, NZ - 1 do
		for ix = 0, NX - 1 do
			local c = cellAt(ix, iz)
			if inSanct(c.x, c.z) and not inShaft(c.x, c.z) then
				if c.kind == "sea" then
					local g = part("SanctGlass", Vector3.new(C, 1, C), at(c.x, S.ceil + 0.5, c.z), Color3.fromRGB(170, 230, 240), Enum.Material.Glass, sanct)
					g.Transparency = 0.45
				else
					textured(part("SanctRoof", Vector3.new(C, 2, C), at(c.x, S.ceil + 1, c.z), nil, nil, sanct), "px_dark_prismarine")
				end
			end
		end
	end
	for x = S.x0 + 8, S.x1 - 8, 16 do
		textured(part("RoofBeam", Vector3.new(1.4, 1.6, D), at(x, S.ceil - 0.4, cz), nil, nil, sanct), "px_dark_prismarine")
	end
	-- four pillars round the arena centre (the charge stuns on them: names Pillar*) with sea-lantern caps
	local ax, az = cx, S.z0 + 38
	for _, p in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local px, pz = ax + p[1] * 20, az + p[2] * 16
		textured(part("PillarBase", Vector3.new(7, 2, 7), at(px, S.floor + 1, pz), nil, nil, sanct), "px_dark_prismarine")
		textured(part("Pillar", Vector3.new(5, H - 6, 5), at(px, S.floor + 2 + (H - 6) / 2, pz), nil, nil, sanct), "px_prismarine")
		local g = glow("PillarLantern", Vector3.new(4, 4, 4), at(px, S.ceil - 4, pz), SEA, "sea_lantern", sanct)
		light(g, 30, 1.2, Color3.fromRGB(150, 230, 255))
	end
	-- the throne of Poseidon at the north end, with a giant golden trident
	local tz = S.z0 + 8
	for k = 0, 2 do
		textured(part("ThroneDais", Vector3.new(22 - k * 5, 1, 10 - k * 2), at(cx, S.floor + 0.5 + k, tz + k * 0.4), nil, nil, sanct), "px_dark_prismarine")
	end
	textured(part("Throne", Vector3.new(6, 10, 2), at(cx, S.floor + 8, tz - 2), nil, nil, sanct), "px_prismarine_bricks")
	textured(part("ThroneSeat", Vector3.new(6, 1.4, 4), at(cx, S.floor + 4, tz), nil, nil, sanct), "px_prismarine")
	part("TridentShaft", Vector3.new(0.8, 18, 0.8), at(cx + 6, S.floor + 12, tz - 1), GOLD, Enum.Material.Metal, sanct)
	part("TridentHead", Vector3.new(5, 0.8, 0.8), at(cx + 6, S.floor + 20.6, tz - 1), GOLD, Enum.Material.Metal, sanct)
	for _, dx in ipairs({ -2.2, 0, 2.2 }) do
		part("TridentProng", Vector3.new(0.6, 3.4, 0.6), at(cx + 6 + dx, S.floor + 22.6, tz - 1), GOLD, Enum.Material.Metal, sanct)
	end
	local sanctSign = textured(decor(part("SanctSign", Vector3.new(16, 2.4, 0.3), at(cx, S.floor + 15, S.z0 + 0.15), nil, nil, sanct)), "px_dark_prismarine")
	boardText(sanctSign, "Святилище Посейдона", Color3.fromRGB(170, 240, 255), { Enum.NormalId.Back })
	-- coral, treasure and broken columns round the walls
	for _ = 1, 22 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local x = cx + side * rng:NextNumber(W / 2 - 6, W / 2 - 2)
		local z = rng:NextNumber(S.z0 + 6, S.z1 - 6)
		local s = rng:NextNumber(1.6, 3)
		textured(part("Coral", Vector3.new(s, s * 1.4, s), at(x, S.floor + s * 0.7, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, sanct), "px_coral", ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 170, 255), Color3.fromRGB(190, 110, 230) })[rng:NextInteger(1, 4)])
	end
	for _, p in ipairs({ { -16, S.z0 + 12 }, { 16, S.z0 + 12 } }) do
		textured(part("TreasureChest", Vector3.new(3, 2.4, 2), at(p[1], S.floor + 1.2, p[2]), nil, nil, sanct), "px_spruce_planks")
		decor(part("TreasureGold", Vector3.new(2.6, 0.6, 1.6), at(p[1], S.floor + 2.6, p[2]), GOLD, Enum.Material.Metal, sanct))
	end
	-- the hall's light: blue-green, a little murk
	local vol = decor(part("SanctVolume", Vector3.new(W, H, D), at(cx, (S.floor + S.ceil) / 2, cz), nil, nil, sanct))
	vol.Transparency = 1
	vol:SetAttribute("Ambient", Color3.fromRGB(110, 150, 160))
	vol:SetAttribute("Exposure", 0)
	vol:SetAttribute("Haze", 0.18)
	vol:SetAttribute("AtmosphereColor", Color3.fromRGB(60, 140, 160))
	vol:SetAttribute("AtmosphereDecay", Color3.fromRGB(20, 60, 80))
	CollectionService:AddTag(vol, "IndoorLighting")
	-- the boss
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(ax, S.floor + 1.2, az), nil, nil, sanct)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "poseidon")
	bossSpawn:SetAttribute("ArenaRadius", 40)
	CollectionService:AddTag(bossSpawn, "BossSpawn")
end
task.wait()

-- ================================================================ the fishing village on stilts (east island) and the bridge to it
local village = folder("FishingVillage")
do
	-- the measured gap between the main island and the village along x at z = 60 (span the real water)
	local bz = 60
	local function wet(x)
		for _, dz in ipairs({ -3, 0, 3 }) do
			local c = cellAtPos(x, bz + dz)
			if c and c.kind == "sea" then
				return true
			end
		end
		return false
	end
	local xa = 100
	while not wet(xa + 0.5) and xa < 150 do
		xa += 1
	end
	local xb = xa
	while wet(xb + 0.5) and xb < 200 do
		xb += 1
	end
	local x0, x1 = xa - 4, xb + 4
	textured(part("BridgeDeck", Vector3.new(x1 - x0, 0.8, 6), at((x0 + x1) / 2, 1.6, bz), nil, nil, village), "px_spruce_planks")
	for x = x0 + 2, x1 - 1, 6 do
		for _, s in ipairs({ -1, 1 }) do
			part("BridgePost", Vector3.new(0.9, 40, 0.9), at(x, -17, bz + s * 2.8), WOOD, Enum.Material.Wood, village)
			part("BridgeRailPost", Vector3.new(0.4, 2.6, 0.4), at(x, 3.3, bz + s * 2.8), WOOD, Enum.Material.Wood, village)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		part("BridgeRope", Vector3.new(x1 - x0, 0.25, 0.25), at((x0 + x1) / 2, 4.4, bz + s * 2.8), Color3.fromRGB(170, 140, 95), Enum.Material.Fabric, village)
	end
	-- stilt huts: a plank floor on posts, walls with a door and window, a pitched roof
	local function hut(x, z, yaw)
		local y = floorAt(x, z)
		local base = at(x, y, z) * CFrame.Angles(0, yaw, 0)
		for _, p in ipairs({ { -4, -4 }, { 4, -4 }, { -4, 4 }, { 4, 4 } }) do
			part("Stilt", Vector3.new(0.8, 4, 0.8), base * CFrame.new(p[1], 2, p[2]), WOOD, Enum.Material.Wood, village)
		end
		textured(part("HutFloor", Vector3.new(10, 0.6, 10), base * CFrame.new(0, 4.3, 0), nil, nil, village), "px_spruce_planks")
		for _, w in ipairs({ { 0, -4.7, 10, 0.4 }, { -4.7, 0, 0.4, 9 }, { 4.7, 0, 0.4, 9 } }) do
			textured(part("HutWall", Vector3.new(w[3], 6, w[4]), base * CFrame.new(w[1], 7.6, w[2]), nil, nil, village), "px_spruce_planks", Color3.fromRGB(200, 190, 170))
		end
		for _, s in ipairs({ -1, 1 }) do
			textured(part("HutWall", Vector3.new(3.6, 6, 0.4), base * CFrame.new(s * 3.2, 7.6, 4.7), nil, nil, village), "px_spruce_planks", Color3.fromRGB(200, 190, 170))
			part("HutRoof", Vector3.new(6.4, 0.5, 11.6), base * CFrame.new(s * 2.6, 11.4, 0) * CFrame.Angles(0, 0, s * -0.6), Color3.fromRGB(70, 90, 120), Enum.Material.Slate, village)
		end
		textured(part("HutSteps", Vector3.new(3, 0.5, 3), base * CFrame.new(0, 2, 6.4) * CFrame.Angles(0.6, 0, 0), nil, nil, village), "px_spruce_planks")
		part("Barrel", Vector3.new(1.6, 2, 1.6), base * CFrame.new(-6, 1, 3), WOOD, Enum.Material.Wood, village)
	end
	for _, h in ipairs({ { 160, 40, 0.2 }, { 190, 40, -0.3 }, { 170, 80, 3.3 }, { 200, 74, 2.9 }, { 150, 66, 1.6 } }) do
		hut(h[1], h[2], h[3])
	end
	-- drying racks with fish, nets on poles, crates, a smokehouse chimney, lamps
	for _, r in ipairs({ { 180, 58 }, { 160, 56 } }) do
		local y = floorAt(r[1], r[2])
		for _, s in ipairs({ -1, 1 }) do
			part("RackPost", Vector3.new(0.4, 4, 0.4), at(r[1] + s * 3, y + 2, r[2]), WOOD, Enum.Material.Wood, village)
		end
		part("RackBar", Vector3.new(6.4, 0.3, 0.3), at(r[1], y + 3.8, r[2]), WOOD, Enum.Material.Wood, village)
		for k = -2, 2 do
			decor(part("DriedFish", Vector3.new(0.4, 1.4, 0.2), at(r[1] + k * 1.1, y + 3, r[2]), Color3.fromRGB(170, 160, 130), nil, village))
		end
	end
	for _, n in ipairs({ { 196, 56 }, { 154, 82 } }) do
		local y = floorAt(n[1], n[2])
		part("NetPole", Vector3.new(0.4, 6, 0.4), at(n[1], y + 3, n[2]), WOOD, Enum.Material.Wood, village)
		part("NetPole", Vector3.new(0.4, 6, 0.4), at(n[1] + 6, y + 3, n[2]), WOOD, Enum.Material.Wood, village)
		local net = decor(part("FishingNet", Vector3.new(6, 4, 0.1), at(n[1] + 3, y + 3.6, n[2]), Color3.fromRGB(150, 140, 110), Enum.Material.Fabric, village))
		net.Transparency = 0.4
	end
	rowboat(210, 88, 1.2, village)
	rowboat(214, 30, 1.8, village)
	for _, p in ipairs({ { 176, 50 }, { 176, 70 } }) do
		lamp(p[1], p[2], 5, village)
	end
	zoneSign(126, 66, "Рыбацкая деревня", math.pi / 2)
end
task.wait()

-- ================================================================ the shipwreck on the western rocks
local wreck = folder("Shipwreck")
do
	local wx, wz = WRECK.x + 4, WRECK.z
	local base = at(wx, -2, wz) * CFrame.Angles(0.25, 0.7, 0.35) -- run aground, listing
	local function hull(name, size, off, variant)
		return textured(part(name, size, base * CFrame.new(off[1], off[2], off[3]), nil, nil, wreck), variant or "px_dark_oak_planks")
	end
	hull("HullBottom", Vector3.new(6, 1.4, 30), { 0, 0, 0 })
	for _, s in ipairs({ -1, 1 }) do
		hull("HullSide", Vector3.new(1, 6, 30), { s * 3.6, 2.6, 0 }).CFrame = base * CFrame.new(s * 3.6, 2.6, 0) * CFrame.Angles(0, 0, s * -0.25)
		hull("HullUpper", Vector3.new(1, 3, 26), { s * 4.6, 6.4, 1 })
	end
	hull("Deck", Vector3.new(8, 0.6, 18), { 0, 5.4, 4 })
	hull("Bow", Vector3.new(4, 7, 4), { 0, 3.6, -16 })
	hull("Stern", Vector3.new(9, 9, 5), { 0, 5, 14 })
	hull("SternCabin", Vector3.new(8, 4, 4), { 0, 11, 14 })
	-- the broken mast with a torn sail
	part("Mast", Vector3.new(1.2, 18, 1.2), base * CFrame.new(0, 14, 0) * CFrame.Angles(0, 0, 0.3), WOOD, Enum.Material.Wood, wreck)
	part("MastBroken", Vector3.new(1, 10, 1), base * CFrame.new(5, 4, -6) * CFrame.Angles(1.2, 0, 0.4), WOOD, Enum.Material.Wood, wreck)
	local sail = decor(part("TornSail", Vector3.new(0.1, 9, 10), base * CFrame.new(1.8, 16, 0) * CFrame.Angles(0, 0, 0.3), Color3.fromRGB(220, 210, 185), Enum.Material.Fabric, wreck))
	sail.Transparency = 0.15
	-- a hole in the side, barrels and a chest spilled on the rocks
	for _ = 1, 6 do
		part("SpilledBarrel", Vector3.new(1.6, 2, 1.6), at(wx + rng:NextNumber(-12, 12), floorAt(wx, wz) + 1, wz + rng:NextNumber(-12, 12)) * CFrame.Angles(rng:NextNumber(0, 1.6), 0, rng:NextNumber(0, 1.6)), WOOD, Enum.Material.Wood, wreck)
	end
	textured(part("WreckChest", Vector3.new(3, 2.4, 2), at(wx - 10, floorAt(wx - 10, wz + 8) + 1.2, wz + 8), nil, nil, wreck), "px_spruce_planks")
	decor(part("WreckGold", Vector3.new(2.6, 0.6, 1.6), at(wx - 10, floorAt(wx - 10, wz + 8) + 2.6, wz + 8), GOLD, Enum.Material.Metal, wreck))
	zoneSign(-108, -14, "Затонувший корабль", math.pi / 2)
end

-- ================================================================ the sea: coral reef, kelp, ocean ruins, sea stacks, buoys, gulls
local sea = folder("Sea")
do
	local COLS = { Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 170, 255), Color3.fromRGB(190, 110, 230), Color3.fromRGB(255, 150, 80) }
	local coral, kelps, ruins = 0, 0, 0
	for _ = 1, 8000 do
		local x, z = rng:NextNumber(-300, 300), rng:NextNumber(-300, 300)
		local c = cellAtPos(x, z)
		if c and c.kind == "sea" and not c.overSanct then
			if c.reef and coral < 160 then
				coral += 1
				local s = rng:NextNumber(1.4, 3.4)
				local col = COLS[rng:NextInteger(1, #COLS)]
				if rng:NextNumber() < 0.5 then
					textured(part("Coral", Vector3.new(s, s, s), at(x, c.seabed + s / 2, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, sea), "px_coral", col)
				else
					for k = 0, 2 do
						decor(part("CoralFan", Vector3.new(0.2, s, s * 0.8), at(x + k * 0.6, c.seabed + s / 2, z) * CFrame.Angles(0, k * 1.1, 0), col, Enum.Material.SmoothPlastic, sea))
					end
				end
				if rng:NextNumber() < 0.15 then
					local pickle = decor(part("SeaPickle", Vector3.new(0.6, 1, 0.6), at(x + 1.5, c.seabed + 0.5, z), Color3.fromRGB(150, 230, 120), Enum.Material.Neon, sea))
					_ = pickle
				end
			elseif c.seabed <= -12 and kelps < 140 and rng:NextNumber() < 0.5 then
				kelps += 1
				kelp(x, z, c.seabed, -1, sea)
			elseif c.seabed <= -20 and ruins < 26 and rng:NextNumber() < 0.08 then
				ruins += 1
				local h = rng:NextNumber(4, 12)
				textured(part("OceanRuin", Vector3.new(4, h, 4), at(x, c.seabed + h / 2, z) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, 1.5), rng:NextNumber(-0.2, 0.2)), nil, nil, sea), if rng:NextNumber() < 0.5 then "px_prismarine_bricks" else "px_prismarine")
			end
		end
	end
	-- fish over the reef
	for _ = 1, 40 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(0, REEF.r * 0.9)
		local x, z = REEF.x + math.cos(a) * r, REEF.z + math.sin(a) * r
		local c = cellAtPos(x, z)
		if c and c.kind == "sea" then
			decor(part("Fish", Vector3.new(0.4, 0.6, 1.2), at(x, rng:NextNumber(c.seabed + 1, -1.5), z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), COLS[rng:NextInteger(1, #COLS)], nil, sea))
		end
	end
	zoneSign(-96, 128, "Коралловый риф", math.pi * 0.75)
	-- sea stacks round the edge: tall rock pillars rising from the sea (the edge of the map)
	for k = 0, 59 do
		local a = k / 60 * math.pi * 2 + rng:NextNumber(-0.04, 0.04)
		local r = rng:NextNumber(270, 300)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local w = rng:NextInteger(3, 5) * 4
		local h = rng:NextNumber(24, 70)
		-- a rock pillar of three stepped tiers, weathered colours, a grassy cap with a few tufts
		local yaw = rng:NextNumber(0, 1.5)
		local rock = Color3.fromRGB(rng:NextInteger(185, 215), rng:NextInteger(175, 200), rng:NextInteger(160, 185))
		local y = -20
		for tier = 0, 2 do
			local th = (h + 20) * ({ 0.5, 0.3, 0.2 })[tier + 1]
			local tw = w * (1 - tier * 0.22)
			part("SeaStack", Vector3.new(tw, th, tw * 0.9), at(x + tier * 0.8, y + th / 2, z) * CFrame.Angles(0, yaw + tier * 0.3, 0), rock, Enum.Material.Slate, sea)
			y += th
		end
		textured(part("SeaStackCap", Vector3.new(w * 0.56 + 0.4, 1, w * 0.5 + 0.4), at(x + 1.6, y + 0.5, z) * CFrame.Angles(0, yaw + 0.6, 0), nil, nil, sea), "px_grass_top", Color3.fromRGB(150, 200, 120))
		if rng:NextNumber() < 0.5 then
			decor(part("Gull", Vector3.new(0.8, 0.6, 1.2), at(x + 1.6, y + 1.3, z), WHITE, nil, sea))
		end
	end
	-- a natural arch out at sea (south-east)
	do
		local x, z = 150, 170
		for _, s in ipairs({ -1, 1 }) do
			textured(part("ArchLeg", Vector3.new(10, 50, 10), at(x + s * 16, 5, z), nil, nil, sea), "px_stone", Color3.fromRGB(170, 165, 160))
		end
		textured(part("ArchTop", Vector3.new(44, 10, 12), at(x, 30, z), nil, nil, sea), "px_stone", Color3.fromRGB(170, 165, 160))
		textured(part("ArchTopMoss", Vector3.new(44, 1, 12), at(x, 35.5, z), nil, nil, sea), "px_grass_top", Color3.fromRGB(150, 200, 120))
	end
	-- buoys and foam round the islands
	for _, b in ipairs({ { 30, 220 }, { -40, 230 }, { 90, 150 }, { -90, -120 }, { 100, -140 } }) do
		local buoy = part("Buoy", Vector3.new(2, 3, 2), at(b[1], 0.8, b[2]), RED, nil, sea)
		_ = buoy
		part("BuoyBand", Vector3.new(2.1, 0.8, 2.1), at(b[1], 1.2, b[2]), WHITE, nil, sea)
		local l = decor(part("BuoyLight", Vector3.new(0.6, 0.6, 0.6), at(b[1], 2.6, b[2]), Color3.fromRGB(255, 80, 60), Enum.Material.Neon, sea))
		_ = l
	end
end
task.wait()

-- ================================================================ decor on the islands: trees, rocks, flowers, lamps and benches along the paths
do
	local deco = folder("Decor")
	for _, t in ipairs(TRAILS) do
		local k = 0
		for i = 1, #t - 1 do
			local ax, az, bx, bz = t[i][1], t[i][2], t[i + 1][1], t[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			local nx, nz = -(bz - az) / len, (bx - ax) / len
			for d = 10, len - 6, 24 do
				k += 1
				local side = if k % 2 == 0 then 1 else -1
				local x, z = ax + (bx - ax) * d / len + nx * 6 * side, az + (bz - az) * d / len + nz * 6 * side
				local c = cellAtPos(x, z)
				if c and c.kind == "land" then
					if k % 3 == 0 then
						local y = floorAt(x, z)
						local yaw = math.atan2(nx * side, nz * side)
						textured(part("Bench", Vector3.new(4.4, 0.5, 1.4), at(x, y + 1.3, z) * CFrame.Angles(0, yaw, 0), nil, nil, deco), "px_spruce_planks")
						textured(part("BenchBack", Vector3.new(4.4, 1.4, 0.3), at(x, y + 2.2, z) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, 0.6), nil, nil, deco), "px_spruce_planks")
					else
						lamp(x, z, 6, deco)
					end
				end
			end
		end
	end
	local made = 0
	for _ = 1, 6000 do
		if made >= 160 then
			break
		end
		local x, z = rng:NextNumber(-300, 300), rng:NextNumber(-300, 300)
		local c = cellAtPos(x, z)
		if c and c.kind == "land" and not c.path and not flat(x, z) and not onTrail(x, z) then
			made += 1
			local y = floorAt(x, z)
			local roll = rng:NextNumber()
			if c.beach then
				if roll < 0.5 then
					local s = rng:NextNumber(1.4, 3.4)
					part("BeachRock", Vector3.new(s, s * 0.7, s), at(x, y + s * 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, 2), 0.1), STONE, Enum.Material.Slate, deco)
				elseif roll < 0.75 then
					decor(part("Shell", Vector3.new(0.8, 0.3, 0.8), at(x, y + 0.15, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(250, 220, 210), nil, deco))
				else
					decor(part("Driftwood", Vector3.new(0.6, 0.6, rng:NextNumber(3, 6)), at(x, y + 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color3.fromRGB(170, 150, 120), Enum.Material.Wood, deco))
				end
			elseif roll < 0.35 then
				-- a wind-bent pine
				local h = rng:NextNumber(8, 13)
				textured(part("PineTrunk", Vector3.new(1.2, h, 1.2), at(x, y + h / 2, z) * CFrame.Angles(0, 0, 0.12), nil, nil, deco), "px_spruce_planks", Color3.fromRGB(150, 110, 80))
				for k = 0, 3 do
					local w = 7 - k * 1.6
					part("PineLeaves", Vector3.new(w, 2.2, w), at(x + 0.6 + k * 0.3, y + h - 4 + k * 2, z), Color3.fromRGB(50, 100, 60), Enum.Material.Grass, deco)
				end
			elseif roll < 0.6 then
				for _ = 1, rng:NextInteger(4, 8) do
					local fx, fz = x + rng:NextNumber(-2.5, 2.5), z + rng:NextNumber(-2.5, 2.5)
					decor(part("Bloom", Vector3.new(0.6, 0.6, 0.6), at(fx, y + 0.6, fz), ({ Color3.fromRGB(255, 250, 240), Color3.fromRGB(250, 200, 60), Color3.fromRGB(140, 160, 255) })[rng:NextInteger(1, 3)], nil, deco))
				end
			elseif roll < 0.85 then
				local s = rng:NextNumber(2, 5)
				part("Rock", Vector3.new(s, s * 0.8, s), at(x, y + s * 0.3, z) * CFrame.Angles(0, rng:NextNumber(0, 2), 0.1), STONE, Enum.Material.Slate, deco)
			else
				part("Crate", Vector3.new(2, 2, 2), at(x, y + 1, z) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), WOOD, Enum.Material.WoodPlanks, deco)
			end
		end
	end
	-- invisible walls at the edge of the map (the sea stacks mark it)
	local E = 318
	for _, w in ipairs({ { 0, E, 2 * E, 4 }, { 0, -E, 2 * E, 4 }, { E, 0, 4, 2 * E }, { -E, 0, 4, 2 * E } }) do
		local p = part("EdgeWall", Vector3.new(w[3], 400, w[4]), at(w[1], 150, w[2]), nil, nil, deco)
		p.Transparency = 1
		p.CanQuery = false
		p.CastShadow = false
	end
	-- spray where the waves hit the rocks round the main island and the headland [меню: вокруг бьются волны]
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		local r = if k % 2 == 0 then 118 else 40
		local cx, cz = if k % 2 == 0 then 0 else LH.x, if k % 2 == 0 then 30 else LH.z
		local p = decor(part("Spray", Vector3.new(14, 1, 4), at(cx + math.cos(a) * r, 0.5, cz + math.sin(a) * r), WHITE, nil, deco))
		p.Transparency = 1
		emitter(p, {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(Color3.fromRGB(240, 250, 255)),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) }),
			Rate = 4,
			Lifetime = NumberRange.new(1, 1.8),
			Speed = NumberRange.new(5, 9),
			SpreadAngle = Vector2.new(30, 30),
			Acceleration = Vector3.new(0, -8, 0),
		})
	end
end

local total = #root:GetDescendants()
print(("[build-sunken-lighthouse] built: %d instances (runs %d)"):format(total, count))
return ("built %d instances, runs %d"):format(total, count)
