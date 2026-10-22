--!nocheck
-- Builds the Затопленный маяк, level 13, PvP [меню]. «Старинный затопленный маяк возвышается из океана, его стены
-- покрыты водорослями, а вокруг бьются волны» [меню]. Blocks: бирюзовый цемент 70 %, призмарин 30 % [меню].
-- Boss: Посейдон — «владыка морей, дремавший на дне Затопленного маяка; его трезубец призывает молнии» [клиент].
-- [владелец 23.10: «следующий этаж с такой же мощностью»] An archipelago in real Terrain water (you can swim):
--   * the main island: the mine (drained ocean ruins of prismarine) with the arrival and the buyer by its rim
--     [владелец 23.10: старт и скупщик рядом с шахтой], a beach, a pier with rowboats, paths, lamps, benches;
--   * v2 [владелец 23.10: «узко, люди будут толпиться, это PvP», 2/10]: the old lighthouse rises straight out of a
--     wide shallow lagoon, leaning a little, algae up to half its height, a broken gallery, the lantern and its beam;
--     at its foot the flooded temple of Poseidon — a plaza 112 studs across under ankle-deep water, a ring of broken
--     columns, a statue with a trident: the arena, open from every side, three 18-stud causeways, the lagoon wadeable;
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

local BX, BZ = 6400, 25000 -- [владелец 23.10: «вижу соседние локации»] 5000 studs from any other location: beyond streaming and haze
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
-- [владелец 23.10: «ужасно, особенно как попасть к боссу — узко, люди будут толпиться, это PvP»] v2: no stairs
-- and no tunnels. The sunken lighthouse stands in a wide shallow lagoon; round its foot lies a huge flooded temple
-- plaza (ankle-deep water) — the arena, open from every side: three wide causeways lead to it and the whole lagoon
-- can be waded. The islands are bigger, terraced, with rock outcrops; the paths are wide.
local PIT = { x = 0, z = 70, size = 32, depth = 12 } -- 32 × 12 × 32 blocks (locations.json sunken_lighthouse.mine)
PIT.w = PIT.size * B
PIT.hole = PIT.w / 2 + 2 * B
local SPAWN_Z = PIT.z + PIT.hole + 12
local LAGOON = { x = 0, z = -140, r = 112 } -- shallow (wading) water round the plaza
local PLAZA = { x = 0, z = -140, r = 56, top = -1 } -- the flooded temple plaza: the arena
local LH = { x = 0, z = -198, r = 15, tilt = 0.09 } -- the lighthouse, leaning a little to the east
local VILLAGE = { x = 190, z = 40, r = 54 }
local WRECK = { x = -186, z = -40, r = 34 }
local REEF = { x = -150, z = 190, r = 60 }
local ISLANDS = {
	{ 0, 70, 128 },
	{ VILLAGE.x, VILLAGE.z, VILLAGE.r },
	{ WRECK.x, WRECK.z, WRECK.r },
	{ -150, 130, 18 },
	{ 170, -190, 26 },
	{ -150, -230, 22 },
}
-- the causeways to the plaza: 18 studs wide, awash at the ends
local CAUSEWAYS = {
	{ 0, -54, 0, -84 }, -- from the main island (north shore)
	{ 150, -40, 50, -120 }, -- from the village island
	{ -160, -60, -50, -126 }, -- from the wreck island
}
local CAUSE_W = 9
local TRAILS = {
	{ { 0, PIT.z - PIT.hole - 4 }, { 0, -56 } }, -- the mine → the causeway to the arena
	{ { PIT.hole + 4, PIT.z }, { 116, 40 }, { 140, 40 } }, -- → the village
	{ { -PIT.hole - 4, PIT.z }, { -110, 20 }, { -150, -30 } }, -- → the wreck island
	{ { 0, SPAWN_Z + 6 }, { 0, 196 } }, -- → the pier
	{ { 30, SPAWN_Z }, { 96, SPAWN_Z - 20 }, { PIT.hole + 4, PIT.z } },
	{ { -30, SPAWN_Z }, { -96, SPAWN_Z - 20 }, { -PIT.hole - 4, PIT.z } },
}

-- ================================================================ the grid (8-stud cells): land, lagoon, sea, the pit
local C = 8
local X0, Z0 = -320, -320
local NX, NZ = 80, 80
local function landR(x, z)
	-- how far inside the nearest island (positive = land)
	local best = -math.huge
	for _, s in ipairs(ISLANDS) do
		local d = math.sqrt((x - s[1]) ^ 2 + (z - s[2]) ^ 2)
		local r = s[3] * (1 + n2(x, z, 2.2 + s[1] * 0.01, 0.03) * 0.18)
		best = math.max(best, r - d)
	end
	return best
end
local function inHole(x, z)
	return math.abs(x - PIT.x) < PIT.hole and math.abs(z - PIT.z) < PIT.hole
end
local function onCauseway(x, z)
	for _, c in ipairs(CAUSEWAYS) do
		if segDist(x, z, c[1], c[2], c[3], c[4]) < CAUSE_W then
			return true
		end
	end
	return false
end
local function onTrail(x, z)
	for _, t in ipairs(TRAILS) do
		if lineDist(t, x, z) < 7 + n2(x, z, 8.8, 0.15) then
			return true
		end
	end
	return false
end
local function plazaD(x, z)
	return math.sqrt((x - PLAZA.x) ^ 2 + (z - PLAZA.z) ^ 2)
end
local function flat(x, z)
	return (math.abs(x - PIT.x) < PIT.hole + 20 and math.abs(z - PIT.z) < PIT.hole + 20)
		or math.sqrt((x - VILLAGE.x) ^ 2 + (z - VILLAGE.z) ^ 2) < VILLAGE.r - 8
		or onCauseway(x, z)
end
local cells = {}
for iz = 0, NZ - 1 do
	for ix = 0, NX - 1 do
		local x, z = X0 + ix * C + C / 2, Z0 + iz * C + C / 2
		local c = { x = x, z = z, land = landR(x, z) }
		local lagoon = math.sqrt((x - LAGOON.x) ^ 2 + (z - LAGOON.z) ^ 2) < LAGOON.r * (1 + n2(x, z, 6.4, 0.02) * 0.12)
		if inHole(x, z) then
			c.kind = "hole"
		elseif plazaD(x, z) < PLAZA.r then
			c.kind = "plaza"
		elseif c.land > 0 then
			c.kind = "land"
			c.path = onTrail(x, z)
			local h = 0
			if c.land < 12 then
				h = if c.land < 6 then 1 else 2 -- the beach, in two steps
				c.beach = true
			elseif not (flat(x, z) or c.path) then
				-- terraces of grass, and rock outcrops rising in 8-stud cliffs
				local v = n2(x, z, 3.3, 0.03) * 1.6 + n2(x, z, 6.1, 0.09) * 0.6
				if v > 0.55 and c.land > 30 then
					h = 12 + 8 * math.clamp(math.floor((v - 0.55) * 6), 0, 2)
					c.rock = true
				else
					h = 4 * math.clamp(math.floor(1.2 + v * 1.5), 1, 2)
				end
			end
			c.top = h
		else
			c.kind = "sea"
			if lagoon or onCauseway(x, z) then
				c.seabed = -8 -- the lagoon round the plaza: turquoise, swimmable (2-stud water read as sand)
				c.lagoon = true
			else
				local shallow = math.clamp(-c.land / 50, 0, 1)
				local depth = 4 * math.floor((4 + 28 * shallow + n2(x, z, 5.5, 0.04) * 6) / 4 + 0.5)
				if math.sqrt((x - REEF.x) ^ 2 + (z - REEF.z) ^ 2) < REEF.r then
					depth = 8
					c.reef = true
				end
				c.seabed = -math.clamp(depth, 4, 36)
			end
			c.causeway = onCauseway(x, z)
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
			local under = -40
			local v, tint
			if c.path then
				v, tint = "px_gravel", Color3.fromRGB(220, 210, 190)
			elseif c.beach then
				v, tint = "px_sand", nil
			elseif c.rock or n2(c.x, c.z, 7.7, 0.06) > 0.5 then
				v, tint = "px_stone", nil
			else
				v, tint = "px_grass_top", Color3.fromRGB(150, 200, 120)
			end
			push(ix, "body", "Ground", under, c.top - 1, if c.beach then "px_sand" else "px_stone", if c.beach then Color3.fromRGB(220, 210, 180) else nil)
			push(ix, "top", "GroundTop", c.top - 1, c.top, v, tint)
			used.body, used.top = true, true
		elseif c.kind == "sea" then
			-- the bed must read as deep water through the clear Terrain water: dark prismarine paving in the lagoon
			-- (the sunken temple), dark sand at sea, bright sand only on the reef
			if c.lagoon then
				push(ix, "bed", "SeaBed", -44, c.seabed, "px_prismarine", Color3.fromRGB(190, 225, 215))
			else
				push(ix, "bed", "SeaBed", -44, c.seabed, "px_sand", if c.reef then Color3.fromRGB(240, 230, 200) else Color3.fromRGB(120, 125, 120))
			end
			-- Terrain water comes in 4-stud voxels: it starts at the voxel below the bed (the bed hides the rest)
			push(ix, "water", "Water", 4 * math.floor(c.seabed / 4), 0, nil, nil, true)
			used.bed, used.water = true, true
		elseif c.kind == "plaza" then
			push(ix, "bed", "SeaBed", -44, -3, "px_prismarine_bricks", nil)
			push(ix, "water", "Water", -4, 0, nil, nil, true)
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
	local p0, p1 = 190, 246
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
	zoneSign(8, 188, "Причал", 0)
end
task.wait()

-- ================================================================ the causeways, the flooded temple plaza (the arena) and the lighthouse
local arena = folder("TemplePlaza")
local lighthouse = folder("Lighthouse")
do
	-- the causeways: wide stone roads just above the water, kerbs, sea lanterns on posts every 16 studs
	for _, cw in ipairs(CAUSEWAYS) do
		local ax, az, bx, bz = cw[1], cw[2], cw[3], cw[4]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2) + 8
		local yaw = math.atan2(bx - ax, bz - az)
		local cf = at((ax + bx) / 2, 0, (az + bz) / 2) * CFrame.Angles(0, yaw, 0)
		textured(part("Causeway", Vector3.new(CAUSE_W * 2, 6, len), cf * CFrame.new(0, -2.6, 0), nil, nil, arena), "px_prismarine_bricks")
		textured(part("CausewayTop", Vector3.new(CAUSE_W * 2 - 2, 0.3, len), cf * CFrame.new(0, 0.55, 0), nil, nil, arena), "px_dark_prismarine")
		for _, s in ipairs({ -1, 1 }) do
			textured(part("CausewayKerb", Vector3.new(1.2, 1, len), cf * CFrame.new(s * (CAUSE_W - 0.6), 0.9, 0), nil, nil, arena), "px_prismarine")
			for d = -len / 2 + 6, len / 2 - 6, 16 do
				textured(part("CausewayPost", Vector3.new(1.4, 4, 1.4), cf * CFrame.new(s * (CAUSE_W - 0.6), 2.4, d), nil, nil, arena), "px_dark_prismarine")
				local g = glow("CausewayLantern", Vector3.new(1.8, 1.8, 1.8), cf * CFrame.new(s * (CAUSE_W - 0.6), 5.3, d), SEA, "sea_lantern", arena)
				if math.floor(d / 16) % 2 == 0 then
					light(g, 22, 1, Color3.fromRGB(170, 240, 255))
				end
			end
		end
	end
	-- the plaza: a wide disc of dark prismarine under ankle-deep water, rings of bricks, a mosaic star
	local px, pz, R = PLAZA.x, PLAZA.z, PLAZA.r
	for iz = 0, NZ - 1 do
		for ix = 0, NX - 1 do
			local c = cellAt(ix, iz)
			if c.kind == "plaza" then
				local d = plazaD(c.x, c.z)
				local v = if d > R - 8 then "px_prismarine_bricks" elseif math.floor(d / 12) % 2 == 0 then "px_dark_prismarine" else "px_prismarine"
				box("PlazaFloor", c.x - C / 2, -3, c.z - C / 2, c.x + C / 2, PLAZA.top, c.z + C / 2, v, nil, arena)
			end
		end
	end
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		local strip = textured(decor(part("MosaicRay", Vector3.new(2, 0.1, R - 14), at(px + math.sin(a) * (R - 14) / 2, PLAZA.top + 0.05, pz + math.cos(a) * (R - 14) / 2) * CFrame.Angles(0, a, 0), nil, nil, arena)), "px_sea_lantern")
		strip.Transparency = 0.2
	end
	-- a ring of 12 broken columns (the charge stuns on them: names Pillar*), some joined by arches, sea lanterns
	local RING = R - 10
	for k = 0, 11 do
		local a = (k + 0.5) / 12 * math.pi * 2
		local cx, cz = px + math.sin(a) * RING, pz + math.cos(a) * RING
		local h = ({ 22, 14, 22, 9, 22, 18, 22, 12, 22, 16, 22, 10 })[k + 1]
		textured(part("PillarBase", Vector3.new(7, 2, 7), at(cx, PLAZA.top + 1, cz) * CFrame.Angles(0, a, 0), nil, nil, arena), "px_dark_prismarine")
		textured(part("Pillar", Vector3.new(4.6, h, 4.6), at(cx, PLAZA.top + 2 + h / 2, cz) * CFrame.Angles(0, a, 0), nil, nil, arena), "px_prismarine")
		for y = 4, h - 2, 7 do
			decor(part("PillarAlgae", Vector3.new(4.8, 1.6, 4.8), at(cx, PLAZA.top + 2 + y, cz) * CFrame.Angles(0, a + 0.3, 0), Color3.fromRGB(60, 120, 60), Enum.Material.Grass, arena)).Transparency = 0.4
		end
		if h >= 22 then
			textured(part("PillarCap", Vector3.new(6.4, 1.6, 6.4), at(cx, PLAZA.top + 2 + h + 0.8, cz) * CFrame.Angles(0, a, 0), nil, nil, arena), "px_dark_prismarine")
			local g = glow("PillarLantern", Vector3.new(3, 3, 3), at(cx, PLAZA.top + 2 + h + 3.1, cz), SEA, "sea_lantern", arena)
			light(g, 30, 1, Color3.fromRGB(170, 240, 255))
			-- an arch to the next tall column
			local a2 = (k + 2.5) / 12 * math.pi * 2
			local nx, nz = px + math.sin(a2) * RING, pz + math.cos(a2) * RING
			if k % 4 == 0 then
				local len = math.sqrt((nx - cx) ^ 2 + (nz - cz) ^ 2)
				textured(part("Architrave", Vector3.new(len, 2.4, 3.6), CFrame.lookAt(Vector3.new(BX + (cx + nx) / 2, PLAZA.top + 2 + h + 1.2, BZ + (cz + nz) / 2), Vector3.new(BX + nx, PLAZA.top + 2 + h + 1.2, BZ + nz)) * CFrame.Angles(0, math.pi / 2, 0), nil, nil, arena), "px_prismarine_bricks")
			end
		else
			-- the broken top fallen beside it
			textured(part("FallenDrum", Vector3.new(4.6, 4.6, 8), at(cx + math.cos(a) * 6, PLAZA.top + 2.3, cz - math.sin(a) * 6) * CFrame.Angles(0, a + 1.2, math.pi / 2), nil, nil, arena), "px_prismarine")
		end
	end
	-- the statue of Poseidon at the north edge, before the lighthouse: on a plinth, trident raised (our design)
	do
		local sx, sz = px, pz - 26
		local base = at(sx, PLAZA.top, sz)
		local function b(name, size, off, variant, col)
			local p = part(name, size, base * CFrame.new(off[1], off[2], off[3]), col or STONE, nil, arena)
			if variant then
				textured(p, variant, col)
			end
			return p
		end
		b("StatuePlinth", Vector3.new(14, 4, 10), { 0, 2, 0 }, "px_dark_prismarine")
		b("StatueLegs", Vector3.new(5, 8, 3), { 0, 8, 0 }, "px_prismarine")
		b("StatueRobe", Vector3.new(6, 4, 3.4), { 0, 10, 0 }, "px_prismarine_bricks")
		b("StatueBody", Vector3.new(6, 7, 3.4), { 0, 15.5, 0 }, "px_prismarine")
		b("StatueArmL", Vector3.new(2, 7, 2), { -4, 15, 0 }, "px_prismarine")
		b("StatueArmR", Vector3.new(2, 7, 2), { 4, 20, 0 }, "px_prismarine")
		b("StatueHead", Vector3.new(4, 4, 4), { 0, 21, 0 }, "px_prismarine")
		b("StatueBeard", Vector3.new(4, 3, 1.4), { 0, 18.6, -2.4 }, "px_prismarine_bricks")
		b("StatueCrown", Vector3.new(4.4, 1.4, 4.4), { 0, 23.7, 0 }, nil, GOLD).Material = Enum.Material.Metal
		b("TridentShaft", Vector3.new(0.9, 26, 0.9), { 4.6, 18, -1 }, nil, GOLD).Material = Enum.Material.Metal
		b("TridentHead", Vector3.new(6, 0.9, 0.9), { 4.6, 31, -1 }, nil, GOLD).Material = Enum.Material.Metal
		for _, dx in ipairs({ -2.6, 0, 2.6 }) do
			b("TridentProng", Vector3.new(0.7, 4, 0.7), { 4.6 + dx, 33.4, -1 }, nil, GOLD).Material = Enum.Material.Metal
		end
		local eye = b("StatueEyes", Vector3.new(2.6, 0.5, 0.2), { 0, 21.6, -2.05 }, nil, Color3.fromRGB(120, 230, 255))
		eye.Material = Enum.Material.Neon
		local plaque = textured(decor(part("PlazaSign", Vector3.new(12, 2, 0.3), base * CFrame.new(0, 2.4, -5.2), nil, nil, arena)), "px_dark_prismarine")
		boardText(plaque, "Храм Посейдона", Color3.fromRGB(170, 240, 255), { Enum.NormalId.Front })
	end
	-- treasure, coral and seaweed scattered over the plaza edge
	for _ = 1, 30 do
		local a, r = rng:NextNumber(0, 6.28), rng:NextNumber(R - 8, R - 2)
		local x, z = px + math.sin(a) * r, pz + math.cos(a) * r
		local s = rng:NextNumber(1.4, 2.8)
		textured(part("Coral", Vector3.new(s, s * 1.3, s), at(x, PLAZA.top + s * 0.65, z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), nil, nil, arena), "px_coral", ({ Color3.fromRGB(255, 120, 160), Color3.fromRGB(255, 210, 90), Color3.fromRGB(120, 170, 255), Color3.fromRGB(190, 110, 230) })[rng:NextInteger(1, 4)])
	end
	for _, p in ipairs({ { -22, 0 }, { 22, -6 }, { 8, 24 } }) do
		textured(part("TreasureChest", Vector3.new(3, 2.4, 2), at(px + p[1], PLAZA.top + 1.2, pz + p[2]) * CFrame.Angles(0, p[1] * 0.05, 0), nil, nil, arena), "px_spruce_planks")
		decor(part("TreasureGold", Vector3.new(2.6, 0.6, 1.6), at(px + p[1], PLAZA.top + 2.6, pz + p[2]), GOLD, Enum.Material.Metal, arena))
	end
	-- the boss
	local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(px, PLAZA.top + 1.2, pz + 6), nil, nil, arena)
	bossSpawn.Transparency = 1
	bossSpawn.CanCollide = false
	bossSpawn.CanQuery = false
	bossSpawn:SetAttribute("BossId", "poseidon")
	bossSpawn:SetAttribute("ArenaRadius", R - 6)
	CollectionService:AddTag(bossSpawn, "BossSpawn")

	-- the lighthouse: rising straight out of the lagoon, leaning a little; white and red bands, algae up to half
	-- its height, a broken gallery, the lantern room with its beam [меню: возвышается из океана, водоросли, волны]
	local lean = CFrame.new(BX + LH.x, -4, BZ + LH.z) * CFrame.Angles(0, 0, -LH.tilt)
	local N, BAND, bands = 32, 9, 11
	local function angDiff(a, b)
		local d = (a - b) % (math.pi * 2)
		return math.min(d, math.pi * 2 - d)
	end
	for b = 0, bands - 1 do
		local y0 = b * BAND
		local r = LH.r - b * 0.45
		for i = 0, N - 1 do
			local a = (i + 0.5) / N * math.pi * 2
			local seg = 2 * math.pi * r / N + 0.4
			local v
			if b < 5 and n2(i, b, 3.3, 0.5) > -0.1 then
				v = "px_mossy_stone_bricks"
			else
				v = if b % 2 == 0 then "px_white_stone_bricks" else "px_red_brick"
			end
			local window = b > 1 and b % 2 == 0 and angDiff(a, (b * 1.3) % (math.pi * 2)) < 0.12
			if not window then
				textured(part("TowerWall", Vector3.new(seg, BAND, 2), lean * CFrame.new(math.sin(a) * r, y0 + BAND / 2, math.cos(a) * r) * CFrame.Angles(0, a, 0), nil, nil, lighthouse), v)
			end
		end
	end
	local topY = bands * BAND
	local rTop = LH.r - bands * 0.45
	-- the inside is filled (no climbing in a PvP crush): a core column
	textured(part("TowerCore", Vector3.new((rTop - 1) * 1.6, topY, (rTop - 1) * 1.6), lean * CFrame.new(0, topY / 2, 0), nil, nil, lighthouse), "px_stone")
	-- the base: a ring of fallen blocks and rocks in the water, foam
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
		local r = LH.r + rng:NextNumber(2, 7)
		local s = rng:NextNumber(3, 6)
		part("BaseRock", Vector3.new(s, s * 0.8, s), at(LH.x + math.sin(a) * r, -1 + s * 0.2, LH.z + math.cos(a) * r) * CFrame.Angles(0, rng:NextNumber(0, 2), rng:NextNumber(-0.2, 0.2)), Color3.fromRGB(120, 120, 118), Enum.Material.Slate, lighthouse)
	end
	-- the gallery (one side broken away), the lantern room, the beam, the green copper roof
	textured(part("GalleryFloor", Vector3.new((rTop + 4) * 2, 1.2, (rTop + 4) * 2), lean * CFrame.new(0, topY + 0.6, 0), nil, nil, lighthouse), "px_dark_prismarine")
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		if angDiff(a, 2.2) > 0.6 then
			part("GalleryRail", Vector3.new(0.4, 3, 0.4), lean * CFrame.new(math.sin(a) * (rTop + 3.6), topY + 2.7, math.cos(a) * (rTop + 3.6)), IRON, Enum.Material.Metal, lighthouse)
		end
	end
	for i = 0, 11 do
		local a = (i + 0.5) / 12 * math.pi * 2
		local glass = part("LanternGlass", Vector3.new(3.6, 9, 0.3), lean * CFrame.new(math.sin(a) * 6.4, topY + 5.7, math.cos(a) * 6.4) * CFrame.Angles(0, a, 0), Color3.fromRGB(200, 240, 250), Enum.Material.Glass, lighthouse)
		glass.Transparency = 0.55
		part("LanternFrame", Vector3.new(0.5, 9, 0.5), lean * CFrame.new(math.sin(a + 0.26) * 6.5, topY + 5.7, math.cos(a + 0.26) * 6.5), IRON, Enum.Material.Metal, lighthouse)
	end
	local lampCore = glow("LighthouseLamp", Vector3.new(5, 5, 5), lean * CFrame.new(0, topY + 5, 0), SEA, "sea_lantern", lighthouse)
	light(lampCore, 80, 2.5, Color3.fromRGB(255, 245, 210))
	for _, dir in ipairs({ 0, math.pi }) do
		local beam = decor(part("LighthouseBeam", Vector3.new(4, 4, 110), lean * CFrame.new(0, topY + 5, 0) * CFrame.Angles(0, dir + 0.7, 0) * CFrame.new(0, 0, -58), Color3.fromRGB(255, 250, 210), Enum.Material.Neon, lighthouse))
		beam.Transparency = 0.86
		beam.CastShadow = false
	end
	for k = 0, 4 do
		part("LanternRoof", Vector3.new(16 - k * 3.2, 1.6, 16 - k * 3.2), lean * CFrame.new(0, topY + 11 + k * 1.6, 0), Color3.fromRGB(70, 140, 115), Enum.Material.Metal, lighthouse)
	end
	part("Vane", Vector3.new(0.4, 5, 0.4), lean * CFrame.new(0, topY + 21, 0), IRON, Enum.Material.Metal, lighthouse)
	-- algae hanging down the lower half, gulls on the gallery
	for _ = 1, 40 do
		local a = rng:NextNumber(0, 6.28)
		local y = rng:NextNumber(4, 40)
		local len = rng:NextNumber(3, 9)
		decor(part("Algae", Vector3.new(0.8, len, 0.25), lean * CFrame.new(math.sin(a) * (LH.r - y / BAND * 0.45 + 1.05), y - len / 2, math.cos(a) * (LH.r - y / BAND * 0.45 + 1.05)) * CFrame.Angles(0, a, 0), Color3.fromRGB(60, 125, 60), Enum.Material.Grass, lighthouse))
	end
	for k = 0, 3 do
		local a = k * 1.4
		decor(part("Gull", Vector3.new(0.8, 0.6, 1.2), lean * CFrame.new(math.sin(a) * (rTop + 2.4), topY + 1.5, math.cos(a) * (rTop + 2.4)), WHITE, nil, lighthouse))
	end
	-- waves breaking round the foot of the tower and the plaza edge
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		for _, ring in ipairs({ { LH.x, LH.z, LH.r + 6 }, { px, pz, R + 4 } }) do
			local p = decor(part("Spray", Vector3.new(10, 1, 3), at(ring[1] + math.sin(a) * ring[3], 0.4, ring[2] + math.cos(a) * ring[3]) * CFrame.Angles(0, a, 0), WHITE, nil, lighthouse))
			p.Transparency = 1
			emitter(p, {
				Texture = "rbxasset://textures/particles/smoke_main.dds",
				Color = ColorSequence.new(Color3.fromRGB(240, 250, 255)),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 4) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) }),
				Rate = 3,
				Lifetime = NumberRange.new(1, 1.8),
				Speed = NumberRange.new(4, 8),
				SpreadAngle = Vector2.new(30, 30),
				Acceleration = Vector3.new(0, -8, 0),
			})
		end
	end
	zoneSign(12, -50, "Храм Посейдона", 0)
end
task.wait()

-- ================================================================ the fishing village on stilts (east island) and the bridge to it
local village = folder("FishingVillage")
do
	-- the measured gap between the main island and the village along x at z = 60 (span the real water)
	local bz = 40
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
	zoneSign(124, 52, "Рыбацкая деревня", math.pi / 2)
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
	zoneSign(-128, -6, "Затонувший корабль", math.pi / 2)
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
	zoneSign(-92, 160, "Коралловый риф", math.pi * 0.75)
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
		local r = if k % 2 == 0 then 134 else 64
		local cx, cz = if k % 2 == 0 then 0 else WRECK.x, if k % 2 == 0 then 70 else WRECK.z
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
