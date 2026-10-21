--!nocheck
-- Builds the Каменоломня (quarry) location, level 3 [вики LOCATIONS-MENU]. The pit mine (40×16×40, stone /
-- coal / iron, locations.json) and the whole location are IN ONE CAVE [владелец 22.10]: rock walls with ore
-- veins, a closed roof with stalactites, torches and hanging lanterns, scaffolding, a rail line with
-- minecarts, ore piles; the arrival area with the block buyer south of the pit and the boss arena
-- (Базальтовый страж) in the east part of the cave. No way out: players come and go by teleport.
-- A separate zone at X = 700 so StreamingEnabled loads it only for players who are there.
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces
-- Workspace.Quarry. Spots (LocationSpawn, LocationId "quarry"): spawn, mine, boss.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)
local old = workspace:FindFirstChild("Quarry")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Quarry"
root.Parent = workspace

local QX, QZ = 700, 0 -- zone centre
local B = 4 -- block size
local rng = Random.new(20261022) -- fixed seed: the same quarry every rebuild
local STONE = Color3.fromRGB(110, 110, 114)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(120, 85, 50)
local IRON = Color3.fromRGB(70, 70, 75)
local LEAVES = Color3.fromRGB(70, 120, 50)
local LAMP = Color3.fromRGB(255, 205, 120)

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
local function textured(p, variant)
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = variant
	p.Color = Color3.new(1, 1, 1)
	return p
end
local function at(x, y, z)
	return CFrame.new(QX + x, y, QZ + z)
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
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
local function lamp(x, z, height)
	height = height or 10
	textured(part("LampPost", Vector3.new(1, height, 1), at(x, height / 2, z), WOOD), "px_oak_log")
	part("LampArm", Vector3.new(1, 1, 3), at(x, height - 0.5, z - 1), WOOD, Enum.Material.Wood)
	local bulb = part("Lantern", Vector3.new(1.6, 1.6, 1.6), at(x, height - 1.8, z - 2), LAMP, Enum.Material.Neon)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 26
	light.Brightness = 1.4
	light.Color = LAMP
	light.Parent = bulb
end
local function spot(id, x, z, faceX, faceZ)
	local p = part("LocationSpawn_quarry_" .. id, Vector3.new(4, 1, 4), CFrame.lookAt(
		Vector3.new(QX + x, 0.5, QZ + z),
		Vector3.new(QX + faceX, 0.5, QZ + faceZ)
	), STONE)
	textured(p, "px_cobblestone")
	p.Transparency = 0
	p.CanCollide = true
	p:SetAttribute("LocationId", "quarry")
	if id ~= "spawn" then
		p:SetAttribute("Spot", id)
	end
	CollectionService:AddTag(p, "LocationSpawn")
	return p
end

-- ---------------------------------------------------------------- the pit (mine 40 × 16 × 40)
local MX, MZ = 0, -20 -- pit centre
local SX, SY, SZ = 40, 16, 40
local w, h, d = SX * B, SY * B, SZ * B
local hole = { x0 = MX - w / 2 - 2 * B, x1 = MX + w / 2 + 2 * B, z0 = MZ - d / 2 - 2 * B, z1 = MZ + d / 2 + 2 * B }

-- ground: four grass slabs around the pit hole, 4 studs thick, top at y = 0
local HALF = 260
local function slab(name, x0, x1, z0, z1)
	if x1 - x0 < 0.5 or z1 - z0 < 0.5 then
		return
	end
	local p = part(name, Vector3.new(x1 - x0, 4, z1 - z0), at((x0 + x1) / 2, -2, (z0 + z1) / 2), LEAVES)
	textured(p, "px_grass_top")
end
slab("Ground", -HALF, HALF, -HALF, hole.z0)
slab("Ground", -HALF, HALF, hole.z1, HALF)
slab("Ground", -HALF, hole.x0, hole.z0, hole.z1)
slab("Ground", hole.x1, HALF, hole.z0, hole.z1)

textured(part("PitFloor", Vector3.new(w + 4 * B, B, d + 4 * B), at(MX, -h - B / 2, MZ), DARK), "px_stone")
for _, wall in ipairs({
	{ "PitWallN", Vector3.new(w + 4 * B, h, 2 * B), at(MX, -h / 2, MZ - d / 2 - B) },
	{ "PitWallS", Vector3.new(w + 4 * B, h, 2 * B), at(MX, -h / 2, MZ + d / 2 + B) },
	{ "PitWallW", Vector3.new(2 * B, h, d), at(MX - w / 2 - B, -h / 2, MZ) },
	{ "PitWallE", Vector3.new(2 * B, h, d), at(MX + w / 2 + B, -h / 2, MZ) },
}) do
	textured(part(wall[1], wall[2], wall[3], STONE), "px_stone")
end
-- cobblestone rim around the opening; a gate in the south rail towards the plaza
local rimY = 0.5
for _, r in ipairs({
	{ Vector3.new(w + 4 * B, 1, 2 * B), at(MX, rimY - 0.5, MZ - d / 2 - B) },
	{ Vector3.new(w + 4 * B, 1, 2 * B), at(MX, rimY - 0.5, MZ + d / 2 + B) },
	{ Vector3.new(2 * B, 1, d), at(MX - w / 2 - B, rimY - 0.5, MZ) },
	{ Vector3.new(2 * B, 1, d), at(MX + w / 2 + B, rimY - 0.5, MZ) },
}) do
	textured(part("PitRim", r[1], r[2], STONE), "px_cobblestone")
end
local function rail(size, cf)
	textured(part("PitRail", size, cf, WOOD), "px_planks")
end
local railLen = (w + 4 * B) / 2 - 8
for _, half in ipairs({ -1, 1 }) do
	rail(Vector3.new(railLen, 3, 0.6), at(MX + half * (8 + railLen / 2), 1.5, MZ + d / 2 + 2 * B))
end
rail(Vector3.new(w + 4 * B, 3, 0.6), at(MX, 1.5, MZ - d / 2 - 2 * B))
rail(Vector3.new(0.6, 3, d + 4 * B), at(MX - w / 2 - 2 * B, 1.5, MZ))
rail(Vector3.new(0.6, 3, d + 4 * B), at(MX + w / 2 + 2 * B, 1.5, MZ))

local anchor = part("MineAnchor_quarry", Vector3.new(w, 0.2, d), at(MX, -0.1, MZ), DARK)
anchor:SetAttribute("LocationId", "quarry")
anchor:SetAttribute("MineId", "quarry")
anchor:SetAttribute("Size", Vector3.new(SX, SY, SZ))
anchor.CanQuery = false
anchor.CanTouch = false
CollectionService:AddTag(anchor, "MineAnchor")
sign(anchor, "Каменоломня", 12)

-- four ladders like the prison mines (eight invisible 2×2 trusses + a textured plate each)
local LADDER_W = 4 * B
local ladderTexture = textures and textures.textures and textures.textures.ladder
for _, side in ipairs({
	{ MX, MZ - d / 2, Vector3.new(0, 0, 1) },
	{ MX, MZ + d / 2, Vector3.new(0, 0, -1) },
	{ MX - w / 2, MZ, Vector3.new(1, 0, 0) },
	{ MX + w / 2, MZ, Vector3.new(-1, 0, 0) },
}) do
	local inward = side[3]
	local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X))
	local base = Vector3.new(QX + side[1], -h / 2, QZ + side[2])
	for k = 0, LADDER_W / 2 - 1 do
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Size = Vector3.new(2, h, 2)
		truss.CFrame = CFrame.new(base - inward * 0.6 + along * (-LADDER_W / 2 + 1 + k * 2))
		truss.Anchored = true
		truss.Transparency = 1
		truss.Parent = root
	end
	local plate = Instance.new("Part")
	plate.Name = "LadderFace"
	plate.Size = Vector3.new(LADDER_W * along.X + 0.2 * math.abs(inward.X), h, LADDER_W * along.Z + 0.2 * math.abs(inward.Z))
	plate.CFrame = CFrame.new(base + inward * 0.15)
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.Transparency = 1
	plate.Parent = root
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


-- ---------------------------------------------------------------- the cave around the pit [владелец 22.10]
-- The mine sits in a cave: thick rock walls, a closed stone roof with stalactites, torches on the walls,
-- lanterns hanging on chains; one entrance in the south wall towards the plaza. Outside the cave is a
-- rocky hill (stepped stone blocks with grass on top).
local CX0, CX1 = MX - w / 2 - 2 * B - 24, 214 -- cave interior, x (east part = boss arena)
local CZ0, CZ1 = MZ - d / 2 - 2 * B - 24, 152 -- cave interior, z (south part = arrival area)
local cave = Instance.new("Folder")
cave.Name = "Cave"
cave.Parent = root
-- cave floor: cut stone around the pit hole (just above the grass so it wins the z-fight)
local function floor(x0, x1, z0, z1)
	if x1 - x0 > 0.5 and z1 - z0 > 0.5 then
		textured(part("CaveFloor", Vector3.new(x1 - x0, 0.4, z1 - z0), at((x0 + x1) / 2, 0.2, (z0 + z1) / 2), STONE, nil, cave), "px_stone")
	end
end
floor(CX0, CX1, CZ0, hole.z0)
floor(CX0, CX1, hole.z1, CZ1)
floor(CX0, hole.x0, hole.z0, hole.z1)
floor(hole.x1, CX1, hole.z0, hole.z1)
-- the vault: a stepped stone DOME over the whole cave [владелец 22.10: «крыша как сфера, а не коробка»].
-- Ceiling height follows an ellipsoid (64 studs in the middle, falling to the walls); every 8 × 8 column
-- is one block reaching up to its neighbours' height, so the steps never leave a gap to the sky. Columns
-- where the vault would be lower than 12 studs (the corners, the edge) are solid rock down to the floor.
local DCX, DCZ = (CX0 + CX1) / 2, (CZ0 + CZ1) / 2
local DRX, DRZ = (CX1 - CX0) / 2 * 1.25, (CZ1 - CZ0) / 2 * 1.25
local DOME_H = 64
local function ceilingAt(x, z)
	local k = 1 - ((x - DCX) / DRX) ^ 2 - ((z - DCZ) / DRZ) ^ 2
	return math.floor(DOME_H * math.sqrt(math.max(0, k)) / 4) * 4
end
local CELL = 8
local cols = {}
local gx0, gx1 = math.floor((CX0 - CELL) / CELL), math.ceil((CX1 + CELL) / CELL)
local gz0, gz1 = math.floor((CZ0 - CELL) / CELL), math.ceil((CZ1 + CELL) / CELL)
local function colAt(ix, iz)
	local row = cols[ix]
	return row and row[iz]
end
for ix = gx0, gx1 do
	cols[ix] = {}
	for iz = gz0, gz1 do
		local x, z = ix * CELL + CELL / 2, iz * CELL + CELL / 2
		local inside = x > CX0 and x < CX1 and z > CZ0 and z < CZ1
		local y = if inside then ceilingAt(x, z) else 0
		cols[ix][iz] = { x = x, z = z, y = y, open = inside and y >= 12 }
	end
end
local function vaultCell(x, z, y0, y1)
	local roll = rng:NextNumber()
	local variant = if roll < 0.78 then "px_stone" elseif roll < 0.9 then "px_cobblestone" elseif roll < 0.96 then "px_coal_ore" else "px_iron_ore"
	textured(part("CaveVault", Vector3.new(CELL, y1 - y0, CELL), at(x, (y0 + y1) / 2, z), STONE, nil, cave), variant)
end
for ix = gx0, gx1 do
	for iz = gz0, gz1 do
		local c = cols[ix][iz]
		local top = if c.open then c.y else 0
		local nearOpen = c.open
		for _, o in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			local n = colAt(ix + o[1], iz + o[2])
			if n and n.open then
				top = math.max(top, n.y)
				nearOpen = true
			end
		end
		if nearOpen then -- columns deep inside the rock are never seen: skip them
			vaultCell(c.x, c.z, if c.open then c.y else 0, top + CELL)
		end
	end
end
-- stalactites hang from the vault (no collision, they only look heavy)
for _ = 1, 140 do
	local x = math.floor(rng:NextNumber(CX0 + 8, CX1 - 8) / 4) * 4 + 2
	local z = math.floor(rng:NextNumber(CZ0 + 8, CZ1 - 8) / 4) * 4 + 2
	local roof = ceilingAt(x, z)
	if roof >= 24 then
		local len = rng:NextInteger(1, 4) * 4
		local s = part("Stalactite", Vector3.new(4, len, 4), at(x, roof - len / 2, z), STONE, nil, cave)
		textured(s, if rng:NextNumber() < 0.8 then "px_stone" else "px_cobblestone")
		s.CanCollide = false
		if len >= 8 then
			local tip = part("StalactiteTip", Vector3.new(2, 4, 2), s.CFrame * CFrame.new(0, -len / 2 - 2, 0), STONE, nil, cave)
			textured(tip, "px_stone")
			tip.CanCollide = false
		end
	end
end
-- torches on the inside walls and lanterns on chains under the roof
local function torch(x, y, z)
	local stick = part("Torch", Vector3.new(0.6, 2, 0.6), at(x, y, z), WOOD, Enum.Material.Wood, cave)
	stick.CanCollide = false
	local flame = part("TorchFlame", Vector3.new(0.8, 0.8, 0.8), at(x, y + 1.3, z), Color3.fromRGB(255, 170, 60), Enum.Material.Neon, cave)
	flame.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 1.6
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Parent = flame
end
local function wallTorch(x, z)
	if ceilingAt(x, z) >= 16 then -- skip spots inside the solid corners
		torch(x, 10, z)
	end
end
for t = 0, 1, 1 / 12 do
	wallTorch(CX0 + 1, CZ0 + (CZ1 - CZ0) * t)
	wallTorch(CX1 - 1, CZ0 + (CZ1 - CZ0) * t)
	wallTorch(CX0 + (CX1 - CX0) * t, CZ0 + 1)
	wallTorch(CX0 + (CX1 - CX0) * t, CZ1 - 1)
end
local function lantern(x, z, drop)
	local roof = ceilingAt(x, z)
	drop = math.max(drop, roof - 30) -- long chains under the high middle of the dome
	local chain = part("Chain", Vector3.new(0.3, drop, 0.3), at(x, roof - drop / 2, z), IRON, Enum.Material.Metal, cave)
	chain.CanCollide = false
	local box = part("HangingLantern", Vector3.new(2, 2.4, 2), at(x, roof - drop - 1.2, z), LAMP, Enum.Material.Neon, cave)
	box.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 34
	light.Brightness = 1.3
	light.Color = LAMP
	light.Shadows = true -- otherwise the light shows through the roof from outside
	light.Parent = box
end
for _, xz in ipairs({
	{ -60, -100 },
	{ 60, -100 },
	{ -60, 60 },
	{ 60, 60 },
	{ -100, -20 },
	{ 0, -20 },
	{ -40, 116 },
	{ 40, 116 },
	{ 120, 116 },
	{ 190, 116 },
	{ 156, -90 },
	{ 200, -20 },
}) do
	lantern(MX + xz[1], xz[2], if xz[1] == 0 and xz[2] == -20 then 10 else 6)
end
-- a misty, dim cave: a few dust particles in the air over the pit
local dust = part("CaveDust", Vector3.new(w, 1, d), at(MX, 30, MZ), STONE, nil, cave)
dust.Transparency = 1
dust.CanCollide = false
dust.CanQuery = false
local emitter = Instance.new("ParticleEmitter")
emitter.Rate = 6
emitter.Lifetime = NumberRange.new(8, 12)
emitter.Speed = NumberRange.new(0.3, 0.8)
emitter.SpreadAngle = Vector2.new(180, 180)
emitter.Size = NumberSequence.new(0.25)
emitter.Transparency = NumberSequence.new(0.6)
emitter.Color = ColorSequence.new(Color3.fromRGB(200, 190, 170))
emitter.LightEmission = 0.2
emitter.Parent = dust

-- ---------------------------------------------------------------- arrival plaza and the buyer
local PZ = 116 -- arrival area centre, south of the pit, inside the cave
textured(part("Plaza", Vector3.new(56, 1, 48), at(0, 0.5, PZ), STONE), "px_cobblestone")
for ix = -3, 3 do
	for iz = -2, 2 do
		if (ix + iz) % 2 == 0 then
			textured(part("PlazaTile", Vector3.new(8, 0.2, 8), at(ix * 8, 1.05, PZ + iz * 8), STONE), "px_stone")
		end
	end
end
textured(part("RoadPit", Vector3.new(16, 0.4, PZ - 24 - hole.z1), at(MX, 0.5, (PZ - 24 + hole.z1) / 2), STONE), "px_gravel")
spot("spawn", 0, PZ + 8, 0, MZ)
spot("mine", 0, hole.z1 + 8, 0, MZ)
for _, xz in ipairs({ { -26, PZ - 22 }, { 26, PZ - 22 }, { -26, PZ + 22 }, { 26, PZ + 22 } }) do
	lamp(xz[1], xz[2])
end

-- block buyer (SellPoint on the rig's root, like scripts/build-npcs.luau)
local npcs = Instance.new("Folder")
npcs.Name = "Npcs"
npcs.Parent = root
local function npc(name, tag, cf, label, labelColor, skin, shirt, pants)
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
	model.Parent = npcs
	model:PivotTo(cf)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = model:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, tag)
	sign(hrp, label, 4.5, labelColor)
	local head = model:FindFirstChild("Head")
	local helmet = part("Helmet", Vector3.new(1.35, 0.8, 1.35), head.CFrame * CFrame.new(0, 0.5, 0), Color3.fromRGB(230, 200, 60), Enum.Material.Metal, model)
	helmet.Shape = Enum.PartType.Ball
	helmet.CanCollide = false
	return model
end
npc(
	"QuarryBuyer",
	"SellPoint",
	CFrame.lookAt(Vector3.new(QX + 22, 4, QZ + PZ - 6), Vector3.new(QX, 4, QZ + PZ - 6)),
	"Скупщик блоков",
	Color3.fromRGB(255, 55, 55),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(70, 70, 80),
	Color3.fromRGB(50, 45, 40)
)
textured(part("Stall", Vector3.new(4, 3, 10), at(19, 1.5, PZ - 6), WOOD), "px_planks")
for _, z in ipairs({ -10, -2 }) do
	textured(part("StallPost", Vector3.new(1, 9, 1), at(17, 4.5, PZ + z), WOOD), "px_oak_log")
	textured(part("StallPost", Vector3.new(1, 9, 1), at(25, 4.5, PZ + z), WOOD), "px_oak_log")
end
part("Awning", Vector3.new(10, 0.6, 12), at(21, 9.3, PZ - 6), Color3.fromRGB(170, 60, 50), Enum.Material.Fabric)

-- ---------------------------------------------------------------- inside the cave: scaffolding, rails, piles
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = root
local function log(size, cf)
	return textured(part("Log", size, cf, WOOD, nil, props), "px_oak_log")
end
local function planks(size, cf)
	return textured(part("Planks", size, cf, WOOD, nil, props), "px_planks")
end
-- scaffolding towers in the pit corners, down the walls
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	local x, z = MX + c[1] * (w / 2 - 6), MZ + c[2] * (d / 2 - 6)
	for _, o in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
		log(Vector3.new(1, h + 6, 1), at(x + o[1], (-h + 6) / 2, z + o[2]))
	end
	for level = 0, 3 do
		planks(Vector3.new(8, 0.6, 8), at(x, -h + 8 + level * 16, z))
	end
end
-- wooden roof props (mine supports) along the cave walls
for t = 0.1, 0.9, 0.2 do
	for _, side in ipairs({ { CX0 + 3, nil }, { CX1 - 3, nil } }) do
		local z = CZ0 + (CZ1 - CZ0) * t
		local roof = math.min(ceilingAt(side[1], z), 30)
		log(Vector3.new(2, roof, 2), at(side[1], roof / 2, z))
		log(Vector3.new(2, 2, 10), at(side[1], roof - 1, z))
	end
end
-- rail line inside the cave along the south wall, with minecarts
local railZ = hole.z1 + 14
for i = 0, 17 do
	planks(Vector3.new(1, 0.4, 6), at(-100 + i * 4, 0.6, railZ))
end
for _, dz in ipairs({ -2.2, 2.2 }) do
	part("Rail", Vector3.new(72, 0.4, 0.4), at(-66, 1, railZ + dz), IRON, Enum.Material.Metal, props)
end
for i, fill in ipairs({ "px_coal_ore", "px_stone", "px_iron_ore" }) do
	local x = -92 + i * 14
	part("Cart", Vector3.new(6, 3, 5), at(x, 2.4, railZ), IRON, Enum.Material.DiamondPlate, props)
	textured(part("CartLoad", Vector3.new(5, 1, 4), at(x, 4.2, railZ), STONE, nil, props), fill)
	for _, o in ipairs({ { -2, -2.4 }, { 2, -2.4 }, { -2, 2.4 }, { 2, 2.4 } }) do
		local wheel = part("Wheel", Vector3.new(1.4, 1.4, 0.6), at(x + o[1], 1.3, railZ + o[2]), DARK, Enum.Material.Metal, props)
		wheel.Shape = Enum.PartType.Cylinder
		wheel.CFrame = at(x + o[1], 1.3, railZ + o[2]) * CFrame.Angles(0, math.pi / 2, 0)
	end
end
-- ore and stone piles in the cave corners (stacked blocks, like Minecraft)
local function pile(cx, cz, variant, size)
	for layer = 0, size - 1 do
		for ix = -size + layer + 1, size - layer - 1 do
			for iz = -size + layer + 1, size - layer - 1 do
				if rng:NextNumber() < 0.8 then
					textured(part("Pile", Vector3.new(B, B, B), at(cx + ix * B, 0.4 + B / 2 + layer * B, cz + iz * B), STONE, nil, props), variant)
				end
			end
		end
	end
end
pile(CX1 - 14, CZ1 - 14, "px_stone", 3)
pile(CX0 + 12, CZ0 + 12, "px_coal_ore", 2)
pile(CX1 - 12, CZ0 + 12, "px_cobblestone", 2)
pile(CX0 + 12, CZ1 - 22, "px_iron_ore", 2)
-- ---------------------------------------------------------------- cave decor [владелец 22.10: «больше дизайна»]
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = root
-- glowing crystal clusters along the walls (cyan and violet, soft light)
local function crystal(x, z)
	local hue = if rng:NextNumber() < 0.6 then Color3.fromRGB(90, 220, 255) else Color3.fromRGB(190, 110, 255)
	for k = 1, rng:NextInteger(3, 5) do
		local height = rng:NextNumber(2, 5)
		local c = part("Crystal", Vector3.new(0.9, height, 0.9), CFrame.new(QX + x + rng:NextNumber(-1.5, 1.5), height / 2 + 0.2, QZ + z + rng:NextNumber(-1.5, 1.5)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), hue, Enum.Material.Neon, decor)
		c.CanCollide = false
		if k == 1 then
			local light = Instance.new("PointLight")
			light.Range = 14
			light.Brightness = 0.9
			light.Color = hue
			light.Parent = c
		end
	end
end
-- mushrooms by the walls (Minecraft brown and red)
local function mushroom(x, z)
	local red = rng:NextNumber() < 0.5
	part("MushroomStem", Vector3.new(0.6, 1.2, 0.6), at(x, 1, z), Color3.fromRGB(230, 220, 200), nil, decor).CanCollide = false
	part("MushroomCap", Vector3.new(1.8, 0.6, 1.8), at(x, 1.9, z), if red then Color3.fromRGB(200, 40, 40) else Color3.fromRGB(150, 110, 75), nil, decor).CanCollide = false
end
local placed = 0
for _ = 1, 400 do
	if placed >= 60 then
		break
	end
	local x = rng:NextNumber(CX0 + 6, CX1 - 6)
	local z = rng:NextNumber(CZ0 + 6, CZ1 - 6)
	local open = ceilingAt(x, z) >= 12
	local nearWall = ceilingAt(x, z) < 30 -- the low ring of the dome, by the walls
	local clear = not (x > hole.x0 - 4 and x < hole.x1 + 4 and z > hole.z0 - 4 and z < hole.z1 + 4) -- not at the pit
		and not (x > -30 and x < 30 and z > PZ - 26) -- not on the arrival area
		and (x - 156) ^ 2 + (z - MZ) ^ 2 > 46 ^ 2 -- not in the arena
	if open and nearWall and clear then
		if placed % 3 == 0 then
			crystal(x, z)
		else
			mushroom(x, z)
		end
		placed += 1
	end
end
-- mine supports around the pit: two posts and a beam every 32 studs, just outside the rim rail
for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
	for k = -2, 2 do
		local along = k * 32
		local x = if side[1] ~= 0 then MX + side[1] * (w / 2 + 2 * B + 5) else MX + along
		local z = if side[2] ~= 0 then MZ + side[2] * (d / 2 + 2 * B + 5) else MZ + along
		local gate = side[2] == 1 and math.abs(along) < 10 -- keep the way from the arrival area open
		if not gate then
			local dx, dz = math.abs(side[2]) * 3, math.abs(side[1]) * 3
			log(Vector3.new(1.4, 12, 1.4), at(x - dx, 6, z - dz))
			log(Vector3.new(1.4, 12, 1.4), at(x + dx, 6, z + dz))
			log(Vector3.new(1.4 + dx * 2, 1.4, 1.4 + dz * 2), at(x, 12.4, z))
		end
	end
end
-- a still underground pool in the south-west, with a cobblestone rim and a lily pad
local POOL_X, POOL_Z, POOL_W, POOL_D = -80, 128, 28, 20
for _, r in ipairs({
	{ Vector3.new(POOL_W + 4, 2, 2), at(POOL_X, 1, POOL_Z - POOL_D / 2 - 1) },
	{ Vector3.new(POOL_W + 4, 2, 2), at(POOL_X, 1, POOL_Z + POOL_D / 2 + 1) },
	{ Vector3.new(2, 2, POOL_D), at(POOL_X - POOL_W / 2 - 1, 1, POOL_Z) },
	{ Vector3.new(2, 2, POOL_D), at(POOL_X + POOL_W / 2 + 1, 1, POOL_Z) },
}) do
	textured(part("PoolRim", r[1], r[2], STONE, nil, decor), "px_cobblestone")
end
workspace.Terrain:FillBlock(at(POOL_X, 1.1, POOL_Z), Vector3.new(POOL_W + 8, 4, POOL_D + 8), Enum.Material.Air) -- re-runs
workspace.Terrain:FillBlock(at(POOL_X, 1.1, POOL_Z), Vector3.new(POOL_W, 1.4, POOL_D), Enum.Material.Water)
part("LilyPad", Vector3.new(2.4, 0.1, 2.4), at(POOL_X + 6, 1.85, POOL_Z - 3), Color3.fromRGB(60, 140, 50), nil, decor).CanCollide = false
crystal(POOL_X - POOL_W / 2 - 4, POOL_Z + POOL_D / 2 + 3)
-- barrels and crates by the buyer's stall
local function barrel(x, z)
	local b = part("Barrel", Vector3.new(3, 2.6, 2.6), at(x, 1.7, z) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood, decor)
	b.Shape = Enum.PartType.Cylinder
	part("BarrelHoop", Vector3.new(0.3, 2.7, 2.7), at(x, 2.4, z) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, decor).Shape = Enum.PartType.Cylinder
end
for _, xz in ipairs({ { 30, PZ - 16 }, { 33, PZ - 12 }, { 30, PZ + 2 } }) do
	barrel(xz[1], xz[2])
end
for _, c in ipairs({ { 33, PZ + 6, 0 }, { 33, PZ + 9.5, 0 }, { 33, PZ + 7.5, 3.5 } }) do
	textured(part("Crate", Vector3.new(3.5, 3.5, 3.5), at(c[1], 1 + 1.75 + c[3], c[2]), WOOD, nil, decor), "px_planks")
end
-- a signpost at the arrival area pointing to the mine and the arena
local post = textured(part("SignPost", Vector3.new(1, 7, 1), at(-12, 4, PZ - 18), WOOD, nil, decor), "px_oak_log")
local board = textured(part("SignBoard", Vector3.new(6, 2.4, 0.4), at(-12, 6.6, PZ - 18), WOOD, nil, decor), "px_planks")
local gui = Instance.new("SurfaceGui")
gui.Face = Enum.NormalId.Back
gui.CanvasSize = Vector2.new(240, 96)
gui.Parent = board
local text = Instance.new("TextLabel")
text.Size = UDim2.fromScale(1, 1)
text.BackgroundTransparency = 1
text.TextScaled = true
text.Font = Enum.Font.Code
text.TextColor3 = Color3.fromRGB(60, 40, 20)
text.Text = "↑ Шахта   → Арена"
text.Parent = gui
_ = post

-- ---------------------------------------------------------------- boss arena (east part of the cave)
-- A round floor of cut stone, a ring of cobblestone pillars with fire bowls, a low wall with the gate
-- facing the road (south). BossService spawns the boss on the BossSpawn part (attribute BossId).
local arena = Instance.new("Folder")
arena.Name = "BossArena"
arena.Parent = root
local AX, AZ, AR = 156, MZ, 40
local SEGMENTS = 24
local function isGate(a)
	return math.sin(a) > 0.93 -- the +Z side, towards the road
end
for i = 0, SEGMENTS - 1 do
	local a = (i + 0.5) / SEGMENTS * math.pi * 2
	local tile = part("ArenaFloor", Vector3.new(2 * AR * math.tan(math.pi / SEGMENTS) + 0.5, 1, AR), CFrame.new(QX + AX, 0.5, QZ + AZ) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.new(0, 0, -AR / 2), STONE, nil, arena)
	textured(tile, if i % 2 == 0 then "px_stone" else "px_cobblestone")
end
part("ArenaCentre", Vector3.new(16, 1.2, 16), at(AX, 0.6, AZ), Color3.fromRGB(52, 52, 58), Enum.Material.Basalt, arena)
-- lava cracks running out from the centre (flush with the floor, decoration only)
for i = 0, 7 do
	local a = i / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
	local len = rng:NextNumber(18, AR - 6)
	local crack = part("LavaCrack", Vector3.new(0.8, 0.12, len), CFrame.new(QX + AX, 1.06, QZ + AZ) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -(8 + len / 2)), Color3.fromRGB(255, 100, 25), Enum.Material.Neon, arena)
	crack.CanCollide = false
	crack.CanQuery = false
end
local glow = part("ArenaGlow", Vector3.new(1, 1, 1), at(AX, 3, AZ), Color3.new(), nil, arena)
glow.Transparency = 1
glow.CanCollide = false
glow.CanQuery = false
local arenaLight = Instance.new("PointLight")
arenaLight.Range = 46
arenaLight.Brightness = 1.2
arenaLight.Color = Color3.fromRGB(255, 120, 50)
arenaLight.Parent = glow
for i = 0, 9 do
	local a = (i + 0.5) / 10 * math.pi * 2
	local x, z = AX + math.cos(a) * (AR + 2), AZ + math.sin(a) * (AR + 2)
	if not isGate(a) then
		-- basalt columns for the Базальтовый страж: dark, faceted, with a glowing lava seam
		local basalt = Color3.fromRGB(52, 52, 58)
		part("Pillar", Vector3.new(5, 18, 5), at(x, 9, z) * CFrame.Angles(0, a, 0), basalt, Enum.Material.Basalt, arena)
		part("PillarFacet", Vector3.new(5, 15, 5), at(x, 7.5, z) * CFrame.Angles(0, a + math.pi / 4, 0), basalt, Enum.Material.Basalt, arena)
		local seam = part("LavaSeam", Vector3.new(0.4, 12, 5.2), at(x, 7, z) * CFrame.Angles(0, a, 0), Color3.fromRGB(255, 110, 30), Enum.Material.Neon, arena)
		seam.CanCollide = false
		part("PillarCap", Vector3.new(6.5, 1.5, 6.5), at(x, 18.75, z), basalt, Enum.Material.Basalt, arena)
		local fire = part("FireBowl", Vector3.new(2.5, 1.5, 2.5), at(x, 20.2, z), Color3.fromRGB(255, 120, 40), Enum.Material.Neon, arena)
		fire.CanCollide = false
		local flames = Instance.new("Fire")
		flames.Size = 4
		flames.Heat = 6
		flames.Parent = fire
		local light = Instance.new("PointLight")
		light.Range = 22
		light.Color = Color3.fromRGB(255, 150, 70)
		light.Parent = fire
	end
end
for i = 0, SEGMENTS - 1 do
	local a = (i + 0.5) / SEGMENTS * math.pi * 2
	if not isGate(a) then
		local seg = part("ArenaWall", Vector3.new(2 * (AR + 2) * math.tan(math.pi / SEGMENTS) + 0.5, 3, 2), CFrame.new(QX + AX, 1.5, QZ + AZ) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.new(0, 0, -(AR + 2)), STONE, nil, arena)
		textured(seg, "px_stone")
	end
end
local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(AX, 1.3, AZ), STONE, nil, arena) -- the arena centre: BossService measures the arena from here
bossSpawn.Transparency = 1
bossSpawn.CanCollide = false
bossSpawn.CanQuery = false
bossSpawn:SetAttribute("BossId", "basalt_guardian")
bossSpawn:SetAttribute("ArenaRadius", AR)
CollectionService:AddTag(bossSpawn, "BossSpawn")
-- the road: plaza → east → north to the arena gate
local GATE_Z = AZ + AR + 2
textured(part("RoadEast", Vector3.new(AX - 28 + 5, 0.4, 10), at((28 + AX + 5) / 2, 0.2, PZ), STONE), "px_gravel")
textured(part("RoadNorth", Vector3.new(10, 0.4, PZ - GATE_Z + 5), at(AX, 0.2, (PZ + GATE_Z) / 2), STONE), "px_gravel")
lamp(AX + 8, GATE_Z + 30)
local arenaSign = part("ArenaSign", Vector3.new(1, 1, 1), at(AX, 8, GATE_Z + 6), STONE, nil, arena)
arenaSign.Transparency = 1
arenaSign.CanCollide = false
sign(arenaSign, "Арена босса", 0, Color3.fromRGB(255, 80, 60))
spot("boss", AX, GATE_Z + 14, AX, AZ)

local count = 0
for _, x in ipairs(root:GetDescendants()) do
	if x:IsA("BasePart") then
		count += 1
	end
end
return "[build-quarry] done, parts: " .. count
