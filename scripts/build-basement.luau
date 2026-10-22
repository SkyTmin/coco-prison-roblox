--!nocheck
-- Builds the Подвал (basement), level 5 + the eternal pass [меню, владелец]. The whole location is INSIDE,
-- one long linear cellar [владелец 22.10: «вся локация внутри; вытянутая, линейно»], south → north:
--   1. the arrival room: a square with three closed sides, the fourth opens onto the cellar;
--   2. a path with 2 rats;
--   3. mine 1, small: dirt / sand / gravel (locations.json basement.mine), a zombie on each side (respawn 2 min);
--   4. a path with 2 rats;
--   5. mine 2, small: iron, diamond, gold, lapis blocks (design-decisions mines.basement_ore);
--   6. a path to the lair;
--   7. the lair of Сплинтер: a stone platform (BossSpawn; BossHud draws the «возродится через» board), a rat in
--      every corner, a zombie in the middle of every side; heaps of rubbish [меню: «выросшая в мраке подземелий
--      и гор мусора»].
-- Both mines reset every 30 s [меню Prison+]. No way out: players come and go by teleport.
-- A separate zone at X = 1500 so StreamingEnabled loads it only for players who are there.
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces
-- Workspace.Basement. Arrival: LocationSpawn, LocationId "basement".

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)
local old = workspace:FindFirstChild("Basement")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Basement"
root.Parent = workspace

local BX, BZ = 1500, 0 -- zone origin (the arrival room centre)
local B = 4 -- block size
local rng = Random.new(20261023) -- fixed seed: the same cellar every rebuild
local STONE = Color3.fromRGB(110, 110, 114)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(120, 85, 50)
local IRON = Color3.fromRGB(70, 70, 75)
local RUST = Color3.fromRGB(120, 70, 45)
local TORCH = Color3.fromRGB(255, 190, 110)
local BEDROCK = Color3.fromRGB(62, 58, 66)

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
-- an axis-aligned box between two corners, in zone coordinates
local function box(name, x0, y0, z0, x1, y1, z1, variant, color, parent)
	local p = part(name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, nil, parent)
	if variant then
		textured(p, variant, color)
	end
	return p
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
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

-- ---------------------------------------------------------------- the plan (z runs north = negative)
local CORRIDOR_W, CORRIDOR_H = 16, 12 -- the paths
local ROOM_H = 20 -- the mine rooms and the lair
local M1 = { size = 16, depth = 8 } -- mine 1: 16 × 8 × 16 blocks (locations.json basement.mine.size)
local M2 = { size = 12, depth = 6 } -- mine 2: 12 × 6 × 12 blocks (anchor attribute Size)
local SPAWN_HALF = 14 -- the arrival room: 28 × 28
local PATH_LEN = 56

local sections = {} -- { name, z0 (south), z1 (north), half width, height, hole? }
local z = SPAWN_HALF
local function add(name, length, half, height, hole)
	local s = { name = name, z0 = z, z1 = z - length, half = half, height = height, hole = hole }
	z -= length
	table.insert(sections, s)
	return s
end
local spawnRoom = add("Spawn", 2 * SPAWN_HALF, SPAWN_HALF, ROOM_H - 4)
local path1 = add("Path1", PATH_LEN, CORRIDOR_W / 2, CORRIDOR_H)
local m1w = M1.size * B
local mine1 = add("Mine1", m1w + 40, m1w / 2 + 22, ROOM_H, true)
local path2 = add("Path2", PATH_LEN, CORRIDOR_W / 2, CORRIDOR_H)
local m2w = M2.size * B
local mine2 = add("Mine2", m2w + 40, m2w / 2 + 22, ROOM_H, true)
local path3 = add("Path3", PATH_LEN, CORRIDOR_W / 2, CORRIDOR_H)
local lair = add("Lair", 84, 42, ROOM_H + 6)
for _, s in ipairs({ mine1, mine2 }) do
	local w = if s == mine1 then m1w else m2w
	local cz = (s.z0 + s.z1) / 2
	s.pit = { x0 = -w / 2, x1 = w / 2, z0 = cz - w / 2, z1 = cz + w / 2, w = w, cz = cz }
	s.hole = { x0 = -w / 2 - 2 * B, x1 = w / 2 + 2 * B, z0 = cz - w / 2 - 2 * B, z1 = cz + w / 2 + 2 * B }
end

-- ---------------------------------------------------------------- shell: floors, walls, vaults
local shell = Instance.new("Folder")
shell.Name = "Shell"
shell.Parent = root
local WALL_VARIANTS = { "px_stone_bricks", "px_stone_bricks", "px_stone_bricks", "px_mossy_stone_bricks", "px_mossy_stone_bricks", "px_cobblestone" }
local function floorSlab(x0, x1, z0, z1, s)
	if x1 - x0 < 0.5 or z0 - z1 < 0.5 then
		return
	end
	box("Floor", x0, -4, z1, x1, 0, z0, if s.name:find("Path") then "px_cobblestone" else "px_stone", nil, shell)
end
-- a wall along x (north / south end) from xa to xb, or along z (east / west side) from za to zb; cut in 8-stud
-- chunks with random brick variants (moss, cobble patches) and a cobblestone footing
local function wallX(zc, xa, xb, height)
	local x = xa
	while x < xb - 0.01 do
		local x2 = math.min(xb, x + 8)
		box("Wall", x, 0, zc - 2, x2, height, zc + 2, WALL_VARIANTS[rng:NextInteger(1, #WALL_VARIANTS)], nil, shell)
		x = x2
	end
end
local function wallZ(xc, za, zb, height) -- za north (smaller) .. zb south
	local zz = za
	while zz < zb - 0.01 do
		local z2 = math.min(zb, zz + 8)
		box("Wall", xc - 2, 0, zz, xc + 2, height, z2, WALL_VARIANTS[rng:NextInteger(1, #WALL_VARIANTS)], nil, shell)
		zz = z2
	end
end
for i, s in ipairs(sections) do
	-- floor (around the pit hole in the mine rooms)
	if s.hole then
		local h = s.hole
		floorSlab(-s.half, s.half, s.z0, h.z1, s)
		floorSlab(-s.half, s.half, h.z0, s.z1, s)
		floorSlab(-s.half, h.x0, h.z1, h.z0, s)
		floorSlab(h.x1, s.half, h.z1, h.z0, s)
	else
		floorSlab(-s.half, s.half, s.z0, s.z1, s)
	end
	-- side walls and the vault (stone, a little darker)
	wallZ(-s.half - 2, s.z1, s.z0, s.height + 4)
	wallZ(s.half + 2, s.z1, s.z0, s.height + 4)
	box("Vault", -s.half - 4, s.height, s.z1, s.half + 4, s.height + 4, s.z0, "px_stone", Color3.fromRGB(150, 150, 155), shell)
	-- the end walls: where a narrower neighbour joins, wall off the difference (the corridor mouth stays open)
	local prev, nextS = sections[i - 1], sections[i + 1]
	local function endWall(zc, neighbour)
		local open = if neighbour then math.min(neighbour.half, s.half) else 0
		local height = s.height + 4
		if open > 0 then
			if s.half > open then
				wallX(zc, -s.half - 4, -open, height)
				wallX(zc, open, s.half + 4, height)
			end
			if neighbour.height < s.height then -- the lintel over a lower corridor mouth
				box("Lintel", -open, neighbour.height, zc - 2, open, height, zc + 2, "px_stone_bricks", nil, shell)
			end
		else
			wallX(zc, -s.half - 4, s.half + 4, height)
		end
	end
	endWall(s.z0 + 2, prev)
	endWall(s.z1 - 2, nextS)
end

-- [владелец 22.10: подвал целиком внутри] the closed vault shuts out the sky: the client (IndoorLighting)
-- lifts the ambient light inside this volume. A Persistent model: with streaming the client always has it.
local indoorModel = Instance.new("Model")
indoorModel.Name = "IndoorVolume"
indoorModel.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
indoorModel.Parent = root
local indoor = decor(part("IndoorVolume", Vector3.new(140, 200, SPAWN_HALF - z + 20), at(0, 0, (SPAWN_HALF + z) / 2), STONE, nil, indoorModel))
indoor.Transparency = 1
indoor:SetAttribute("Ambient", Color3.fromRGB(140, 132, 125))
indoor:SetAttribute("Exposure", 0.1)
CollectionService:AddTag(indoor, "IndoorLighting")

-- ---------------------------------------------------------------- light and supports
local props = Instance.new("Folder")
props.Name = "Props"
props.Parent = root
local function torch(x, y, zz, face)
	-- a wall torch: a stick and a glowing head, leaning out from the wall
	local stick = decor(part("TorchStick", Vector3.new(0.4, 1.6, 0.4), at(x + face * 0.4, y, zz) * CFrame.Angles(0, 0, face * 0.35), WOOD, Enum.Material.Wood, props))
	local flame = decor(part("TorchFlame", Vector3.new(0.6, 0.6, 0.6), stick.CFrame * CFrame.new(0, 1, 0), TORCH, Enum.Material.Neon, props))
	local light = Instance.new("PointLight")
	light.Range = 18
	light.Brightness = 1.3
	light.Color = TORCH
	light.Shadows = false
	light.Parent = flame
	local fire = Instance.new("Fire")
	fire.Size = 1.4
	fire.Heat = 3
	fire.Parent = flame
end
-- along every corridor and room wall: a torch every 16 studs, oak supports (posts + beam) every 16 in corridors
for _, s in ipairs(sections) do
	local corridor = s.name:find("Path") ~= nil
	local zz = s.z0 - 8
	local k = 0
	while zz > s.z1 + 4 do
		if k % 2 == 0 then
			torch(-s.half + 0.2, 6, zz, 1)
		else
			torch(s.half - 0.2, 6, zz, -1)
		end
		if corridor and k % 2 == 1 then
			for _, side in ipairs({ -1, 1 }) do
				textured(part("Support", Vector3.new(1.2, CORRIDOR_H, 1.2), at(side * (s.half - 0.6), CORRIDOR_H / 2, zz), WOOD, nil, props), "px_oak_log")
			end
			textured(part("Beam", Vector3.new(2 * s.half, 1.2, 1.2), at(0, CORRIDOR_H - 0.6, zz), WOOD, nil, props), "px_planks")
		end
		zz -= 8
		k += 1
	end
end
-- an old rusty pipe along the vault of every corridor, dripping now and then
for _, s in ipairs({ path1, path2, path3 }) do
	local len = s.z0 - s.z1
	local pipe = decor(part("Pipe", Vector3.new(len, 1, 1), at(s.half - 2, s.height - 2.2, (s.z0 + s.z1) / 2), RUST, Enum.Material.Metal, props))
	pipe.Shape = Enum.PartType.Cylinder
	pipe.CFrame = pipe.CFrame * CFrame.Angles(0, math.pi / 2, 0)
	local drip = Instance.new("ParticleEmitter")
	drip.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	drip.Color = ColorSequence.new(Color3.fromRGB(140, 170, 190))
	drip.Size = NumberSequence.new(0.15)
	drip.Rate = 1.5
	drip.Lifetime = NumberRange.new(1, 1.4)
	drip.Speed = NumberRange.new(0)
	drip.Acceleration = Vector3.new(0, -30, 0)
	drip.Transparency = NumberSequence.new(0.3)
	drip.Parent = pipe
	-- a puddle under it
	local puddle = decor(part("Puddle", Vector3.new(0.1, 6, 6), at(s.half - 3, 0.05, (s.z0 + s.z1) / 2 + rng:NextNumber(-10, 10)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(60, 80, 95), Enum.Material.Glass, props))
	puddle.Shape = Enum.PartType.Cylinder
	puddle.Transparency = 0.35
	puddle.Reflectance = 0.25
end

-- the path (тропинка): a worn strip of gravel and dirt down the middle of every corridor
for _, s in ipairs({ path1, path2, path3 }) do
	local zz = s.z0
	while zz > s.z1 + 0.01 do
		local z2 = math.max(s.z1, zz - 4)
		local wob = rng:NextNumber(-0.8, 0.8)
		box("Trail", -3 + wob, 0, z2, 3 + wob, 0.12, zz, if rng:NextNumber() < 0.6 then "px_gravel" else "px_dirt", nil, props)
		zz = z2
	end
end

-- ---------------------------------------------------------------- the arrival room
local ROOM = spawnRoom
local spawnPart = part("LocationSpawn_basement", Vector3.new(4, 1, 4), CFrame.lookAt(Vector3.new(BX, 0.5, BZ + 6), Vector3.new(BX, 0.5, BZ - 100)), STONE)
textured(spawnPart, "px_cobblestone")
spawnPart:SetAttribute("LocationId", "basement")
CollectionService:AddTag(spawnPart, "LocationSpawn")
-- a ring of cut stone around the arrival point and a rug
for ix = -2, 2 do
	for iz = -2, 2 do
		if (ix + iz) % 2 == 0 then
			box("SpawnTile", ix * 4 - 2, 0, iz * 4, ix * 4 + 2, 0.15, iz * 4 + 4, "px_smooth_stone", nil, props)
		end
	end
end
-- crates and barrels in the corners, shelves on the back wall
local function crate(x, zz, size)
	size = size or 3
	local c = part("Crate", Vector3.new(size, size, size), at(x, size / 2, zz) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), WOOD, nil, props)
	textured(c, "px_planks")
	return c
end
local function barrel(x, zz)
	local b = part("Barrel", Vector3.new(3, 2.6, 2.6), at(x, 1.5, zz) * CFrame.Angles(0, 0, math.pi / 2), WOOD, Enum.Material.Wood, props)
	b.Shape = Enum.PartType.Cylinder
	b.Color = Color3.fromRGB(105, 72, 42)
	for _, y in ipairs({ 0.6, 2.4 }) do
		local hoop = decor(part("Hoop", Vector3.new(0.3, 2.75, 2.75), at(x, y, zz) * CFrame.Angles(0, 0, math.pi / 2), IRON, Enum.Material.Metal, props))
		hoop.Shape = Enum.PartType.Cylinder
	end
end
crate(-ROOM.half + 2.5, ROOM.z0 - 2.5)
crate(-ROOM.half + 2.5, ROOM.z0 - 6, 2.4)
crate(-ROOM.half + 2, ROOM.z0 - 2.5, 2).CFrame *= CFrame.new(0, 2.8, 0)
barrel(ROOM.half - 2.5, ROOM.z0 - 2.5)
barrel(ROOM.half - 2.5, ROOM.z0 - 6)
barrel(ROOM.half - 6, ROOM.z0 - 2.5)
for _, y in ipairs({ 3, 6.5 }) do
	textured(part("Shelf", Vector3.new(10, 0.4, 1.6), at(0, y, ROOM.z0 - 0.8), WOOD, nil, props), "px_planks")
end
for i = 1, 6 do
	local jar = decor(part("Jar", Vector3.new(0.8, 1, 0.8), at(-4.5 + i * 1.4, 3.7, ROOM.z0 - 0.8), Color3.fromHSV(rng:NextNumber(0.05, 0.4), 0.5, 0.6), Enum.Material.Glass, props))
	jar.Transparency = 0.2
end
local signPart = decor(part("BasementSign", Vector3.new(1, 1, 1), at(0, 11, ROOM.z0 - 1), STONE, nil, props))
signPart.Transparency = 1
sign(signPart, "Подвал", 0)

-- block buyers (SellPoint on the rig's root, like scripts/build-quarry.luau): in the arrival room and at mine 2
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
	return model
end
local function buyer(name, x, zz, faceX)
	npc(
		name,
		"SellPoint",
		CFrame.lookAt(Vector3.new(BX + x, 3, BZ + zz), Vector3.new(BX + faceX, 3, BZ + zz)),
		"Скупщик блоков",
		Color3.fromRGB(255, 55, 55),
		Color3.fromRGB(198, 140, 100),
		Color3.fromRGB(70, 70, 80),
		Color3.fromRGB(50, 45, 40)
	)
end
buyer("BasementBuyer", -ROOM.half + 3, ROOM.z0 - 14, 0)
textured(part("Counter", Vector3.new(3, 3, 8), at(-ROOM.half + 6, 1.5, ROOM.z0 - 14), WOOD, nil, props), "px_planks")

-- ---------------------------------------------------------------- the mines
local function pit(s, id, size, depth, label)
	local p = s.pit
	local w, h = p.w, depth * B
	local cz = p.cz
	local function bedrock(x)
		textured(x, "px_cobblestone", BEDROCK)
	end
	bedrock(part("PitFloor", Vector3.new(w + 4 * B, B, w + 4 * B), at(0, -h - B / 2, cz), DARK))
	for _, wall in ipairs({
		{ Vector3.new(w + 4 * B, h, 2 * B), at(0, -h / 2, cz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, h, 2 * B), at(0, -h / 2, cz + w / 2 + B) },
		{ Vector3.new(2 * B, h, w), at(-w / 2 - B, -h / 2, cz) },
		{ Vector3.new(2 * B, h, w), at(w / 2 + B, -h / 2, cz) },
	}) do
		bedrock(part("PitWall", wall[1], wall[2], STONE))
	end
	for _, r in ipairs({
		{ Vector3.new(w + 4 * B, 1, 2 * B), at(0, 0, cz - w / 2 - B) },
		{ Vector3.new(w + 4 * B, 1, 2 * B), at(0, 0, cz + w / 2 + B) },
		{ Vector3.new(2 * B, 1, w), at(-w / 2 - B, 0, cz) },
		{ Vector3.new(2 * B, 1, w), at(w / 2 + B, 0, cz) },
	}) do
		bedrock(part("PitRim", r[1], r[2], STONE))
	end
	-- a wooden rail round the pit with gaps on the path side (south) and the far side (north)
	local railLen = (w + 4 * B) / 2 - 6
	for _, half in ipairs({ -1, 1 }) do
		for _, side in ipairs({ -1, 1 }) do
			textured(part("PitRail", Vector3.new(railLen, 3, 0.6), at(half * (6 + railLen / 2), 1.5, cz + side * (w / 2 + 2 * B)), WOOD), "px_planks")
		end
	end
	textured(part("PitRail", Vector3.new(0.6, 3, w + 4 * B), at(-w / 2 - 2 * B, 1.5, cz), WOOD), "px_planks")
	textured(part("PitRail", Vector3.new(0.6, 3, w + 4 * B), at(w / 2 + 2 * B, 1.5, cz), WOOD), "px_planks")

	local anchor = part("MineAnchor_" .. id, Vector3.new(w, 0.2, w), at(0, -0.1, cz), DARK)
	anchor:SetAttribute("LocationId", "basement")
	anchor:SetAttribute("MineId", id)
	anchor:SetAttribute("Size", Vector3.new(size, depth, size))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, label, 8)

	-- four ladders like the quarry (invisible 2×2 trusses + a textured plate each)
	local LADDER_W = 4 * B
	local ladderTexture = textures and textures.textures and textures.textures.ladder
	for _, side in ipairs({
		{ 0, cz - w / 2, Vector3.new(0, 0, 1) },
		{ 0, cz + w / 2, Vector3.new(0, 0, -1) },
		{ -w / 2, cz, Vector3.new(1, 0, 0) },
		{ w / 2, cz, Vector3.new(-1, 0, 0) },
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
	-- a lantern hanging over each pit corner (the room is the darkest place otherwise)
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local x, zz = c[1] * (w / 2 + 3 * B), cz + c[2] * (w / 2 + 3 * B)
		decor(part("Chain", Vector3.new(0.2, 5, 0.2), at(x, s.height - 2.5, zz), IRON, Enum.Material.Metal, props))
		local lantern = decor(part("Lantern", Vector3.new(1.4, 1.6, 1.4), at(x, s.height - 5.8, zz), TORCH, Enum.Material.Neon, props))
		local light = Instance.new("PointLight")
		light.Range = 28
		light.Brightness = 1.2
		light.Color = TORCH
		light.Parent = lantern
	end
end
pit(mine1, "basement", M1.size, M1.depth, "Шахта")
pit(mine2, "basement_ore", M2.size, M2.depth, "Рудная шахта")
buyer("BasementOreBuyer", mine2.half - 3, mine2.pit.cz, 0)

-- ore piles and minecarts by the ore mine; rubble by mine 1
local function pile(x, zz, variants, n)
	for i = 1, n do
		local s = rng:NextNumber(1.2, 2.2)
		local p = part("Pile", Vector3.new(s, s, s), at(x + rng:NextNumber(-2, 2), s / 2 + (if i > n / 2 then 1 else 0), zz + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), STONE, nil, props)
		textured(p, variants[rng:NextInteger(1, #variants)])
	end
end
pile(-mine2.half + 4, mine2.z1 + 5, { "px_gold_block", "px_iron_block", "px_lapis_block", "px_cobblestone" }, 8)
pile(-mine1.half + 4, mine1.z1 + 5, { "px_gravel", "px_dirt", "px_cobblestone" }, 8)
pile(mine1.half - 4, mine1.z0 - 5, { "px_sand", "px_gravel", "px_cobblestone" }, 6)
local function minecart(x, zz)
	local base = part("Minecart", Vector3.new(3, 1.6, 4), at(x, 1.2, zz), IRON, Enum.Material.Metal, props)
	for _, d in ipairs({ { 0, 1.8 }, { 0, -1.8 }, { 1.3, 0 }, { -1.3, 0 } }) do
		local wall = part("CartSide", Vector3.new(if d[1] == 0 then 3 else 0.3, 1, if d[1] == 0 then 0.3 else 4), at(x + d[1], 2.4, zz + d[2]), IRON, Enum.Material.Metal, props)
		wall.CanCollide = false
	end
	textured(decor(part("CartLoad", Vector3.new(2.4, 0.8, 3.4), at(x, 2.3, zz), STONE, nil, props)), "px_iron_block")
	for _, wx in ipairs({ -1.5, 1.5 }) do
		for _, wz in ipairs({ -1.3, 1.3 }) do
			local wheel = decor(part("Wheel", Vector3.new(0.3, 0.9, 0.9), at(x + wx, 0.45, zz + wz), DARK, Enum.Material.Metal, props))
			wheel.Shape = Enum.PartType.Cylinder
		end
	end
end
minecart(-mine2.half + 5, mine2.z0 - 6)
for _, s in ipairs({ mine1, mine2 }) do
	-- a rail line along the west wall of each mine room
	for _, side in ipairs({ -0.7, 0.7 }) do
		decor(part("Rail", Vector3.new(0.3, 0.2, s.z0 - s.z1 - 8), at(-s.half + 5 + side, 0.1, (s.z0 + s.z1) / 2), IRON, Enum.Material.Metal, props))
	end
end

-- ---------------------------------------------------------------- the lair of Сплинтер
local L = lair
local LCZ = (L.z0 + L.z1) / 2
local PLATFORM_R = 16
local plat = part("LairPlatform", Vector3.new(1.2, 2 * PLATFORM_R, 2 * PLATFORM_R), at(0, 0.6, LCZ) * CFrame.Angles(0, 0, math.pi / 2), STONE)
plat.Shape = Enum.PartType.Cylinder
textured(plat, "px_stone_bricks")
local inner = part("LairPlatformInner", Vector3.new(1.5, 2 * (PLATFORM_R - 4), 2 * (PLATFORM_R - 4)), at(0, 0.75, LCZ) * CFrame.Angles(0, 0, math.pi / 2), STONE)
inner.Shape = Enum.PartType.Cylinder
textured(inner, "px_smooth_stone")
-- claw scratches on the platform
for i = 0, 5 do
	local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
	for k = -1, 1 do
		decor(part("Scratch", Vector3.new(0.25, 0.1, 5), CFrame.new(BX, 1.52, BZ + LCZ) * CFrame.Angles(0, a, 0) * CFrame.new(k * 0.6, 0, -8), Color3.fromRGB(45, 42, 40), nil, props))
	end
end
-- heaps of rubbish in the corners: blocks, planks, bones [меню: «горы мусора»]
local function rubbish(x, zz)
	for i = 1, 14 do
		local s = rng:NextNumber(1.4, 3)
		local r = rng:NextNumber(0, 4.5)
		local a = rng:NextNumber(0, 6.28)
		local y = s / 2 + math.max(0, 3.5 - r) * 0.9
		local p = part("Rubbish", Vector3.new(s, s * rng:NextNumber(0.5, 1), s), at(x + math.cos(a) * r, y, zz + math.sin(a) * r) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), a, rng:NextNumber(-0.4, 0.4)), STONE, nil, props)
		textured(p, ({ "px_dirt", "px_gravel", "px_planks", "px_cobblestone", "px_mossy_cobblestone", "px_spruce_planks" })[rng:NextInteger(1, 6)])
	end
	for i = 1, 4 do
		local bone = decor(part("Bone", Vector3.new(0.4, 0.4, rng:NextNumber(1.6, 2.6)), at(x + rng:NextNumber(-5, 5), 0.25, zz + rng:NextNumber(-5, 5)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color3.fromRGB(225, 220, 200), nil, props))
		bone.Name = "Bone" .. i
	end
end
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	rubbish(c[1] * (L.half - 7), LCZ + c[2] * (L.half - 7))
end
-- fire bowls on stone posts round the platform
for i = 0, 7 do
	local a = (i + 0.5) / 8 * math.pi * 2
	local x, zz = math.cos(a) * (PLATFORM_R + 6), LCZ + math.sin(a) * (PLATFORM_R + 6)
	textured(part("BowlPost", Vector3.new(2, 4, 2), at(x, 2, zz), STONE, nil, props), "px_stone_bricks")
	local bowl = decor(part("FireBowl", Vector3.new(1.6, 0.8, 1.6), at(x, 4.4, zz), Color3.fromRGB(255, 110, 50), Enum.Material.Neon, props))
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 5
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Range = 20
	light.Color = Color3.fromRGB(255, 140, 80)
	light.Parent = bowl
end
local bossSpawn = part("BossSpawn", Vector3.new(4, 1, 4), at(0, 1.5, LCZ), STONE)
bossSpawn.Transparency = 1
bossSpawn.CanCollide = false
bossSpawn.CanQuery = false
bossSpawn:SetAttribute("BossId", "splinter")
bossSpawn:SetAttribute("ArenaRadius", L.half - 4)
CollectionService:AddTag(bossSpawn, "BossSpawn")
local lairSign = decor(part("LairSign", Vector3.new(1, 1, 1), at(0, L.height - 4, L.z0 - 1), STONE, nil, props))
lairSign.Transparency = 1
sign(lairSign, "Логово Сплинтера", 0, Color3.fromRGB(255, 80, 60))

-- ---------------------------------------------------------------- mobs (MobService): MobSpawn points
local mobs = Instance.new("Folder")
mobs.Name = "MobSpawns"
mobs.Parent = root
local function mobSpawn(id, x, zz, radius)
	local m = decor(part("MobSpawn_" .. id, Vector3.new(2, 1, 2), at(x, 0.5, zz), STONE, nil, mobs))
	m.Transparency = 1
	m:SetAttribute("MobId", id)
	m:SetAttribute("LocationId", "basement")
	m:SetAttribute("Wander", radius)
	CollectionService:AddTag(m, "MobSpawn")
end
-- 2 rats on each of the first two paths
for _, s in ipairs({ path1, path2 }) do
	local len = s.z0 - s.z1
	mobSpawn("rat", -3, s.z0 - len * 0.35, 4)
	mobSpawn("rat", 3, s.z0 - len * 0.7, 4)
end
-- a zombie on each side of mine 1 [владелец 22.10: «2 зомби по бокам шахты, кд 2 минуты»]
for _, side in ipairs({ -1, 1 }) do
	mobSpawn("zombie", side * (mine1.pit.w / 2 + 2 * B + 6), mine1.pit.cz, 3)
end
-- the lair: a rat in every corner, a zombie in the middle of every side
local cornerR, sideR = L.half - 12, L.half - 6
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	mobSpawn("rat", c[1] * cornerR, LCZ + c[2] * cornerR, 3)
end
for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { 0, 1 }, { -1, 0 } }) do
	mobSpawn("zombie", d[1] * sideR, LCZ + d[2] * sideR, 3)
end

print(("[build-basement] built: %d parts, cellar %d studs long"):format(#root:GetDescendants(), SPAWN_HALF - z))
