--!nocheck
-- Outdoor decoration pass for the Тюрьма location (owner: spacious, detailed, nothing on the paths).
-- Run in Studio (Edit) after build-prison, build-buildings and build-npcs. Idempotent: replaces
-- Workspace.Prison.Decor. Keep-out zones are read from the world (paths, plaza, buildings, pits,
-- basins, NPC models), so moving a building never leaves props on a road.

local root = workspace:FindFirstChild("Prison")
if not root then
	error("[decorate-prison] run scripts/build-prison.luau first")
end
local old = root:FindFirstChild("Decor")
if old then
	old:Destroy()
end
local decor = Instance.new("Folder")
decor.Name = "Decor"
decor.Parent = root

local HALF = 200
local rng = Random.new(20261021)

local WOOD = Color3.fromRGB(120, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 60, 35)
local BIRCH = Color3.fromRGB(225, 220, 205)
local LEAF = Color3.fromRGB(70, 125, 55)
local LEAF2 = Color3.fromRGB(95, 150, 60)
local LEAF3 = Color3.fromRGB(55, 105, 50)
local PINE = Color3.fromRGB(40, 90, 55)
local STONE = Color3.fromRGB(96, 96, 100)
local DARK = Color3.fromRGB(60, 60, 66)
local IRON = Color3.fromRGB(70, 70, 75)
local LAMP = Color3.fromRGB(255, 215, 130)
local CLOTH = Color3.fromRGB(190, 60, 50)
local FLOWERS = {
	Color3.fromRGB(230, 70, 70),
	Color3.fromRGB(240, 200, 60),
	Color3.fromRGB(200, 90, 200),
	Color3.fromRGB(250, 250, 250),
	Color3.fromRGB(90, 140, 240),
}

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	if typeof(material) == "string" then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = material
		p.Color = Color3.new(1, 1, 1)
	else
		p.Material = material or Enum.Material.SmoothPlastic
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or decor
	return p
end
local function light(parent, color, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = color or LAMP
	l.Range = range or 24
	l.Brightness = brightness or 1.2
	l.Parent = parent
	return l
end
local function boardText(target, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 220, 140)
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
end

-- ---------------------------------------------------------------- keep-out zones from the world
local blocked = {} -- { x0, x1, z0, z1 }
local function block(cf, size, margin)
	-- axis-aligned bounds of an (unrotated) part/model
	local hx, hz = size.X / 2 + margin, size.Z / 2 + margin
	table.insert(
		blocked,
		{ cf.Position.X - hx, cf.Position.X + hx, cf.Position.Z - hz, cf.Position.Z + hz }
	)
end
for _, inst in ipairs(root:GetChildren()) do
	if inst:IsA("BasePart") then
		local n = inst.Name
		if n:match("^Path") and n ~= "PathEdge" then
			block(inst.CFrame, inst.Size, 2)
		elseif n == "Plaza" then
			block(inst.CFrame, inst.Size, 3)
		elseif n:match("^MineAnchor") then
			block(inst.CFrame, inst.Size + Vector3.new(16, 0, 16), 8) -- hole + rim + walkway
		elseif n:match("Floor$") then
			block(inst.CFrame, inst.Size, 4) -- basins
		elseif n == "Teleporter" then
			block(inst.CFrame, inst.Size, 5)
		end
	elseif inst:IsA("Model") or inst:IsA("Folder") then
		for _, m in ipairs(inst:GetChildren()) do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				block(cf, size, if inst.Name == "Buildings" then 5 else 4)
			end
		end
	end
end
local function free(x, z, margin)
	if math.abs(x) > HALF - 8 or math.abs(z) > HALF - 8 then
		return false
	end
	for _, r in ipairs(blocked) do
		if x > r[1] - margin and x < r[2] + margin and z > r[3] - margin and z < r[4] + margin then
			return false
		end
	end
	return true
end
local placed = {}
local function farFromOthers(x, z, dist)
	for _, v in ipairs(placed) do
		if (v - Vector2.new(x, z)).Magnitude < dist then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------- props
-- Trees v2: oak (round layered canopy + root flares), pine (stacked cones), birch (white trunk).
local function canopyCube(model, x, y, z, s, color)
	part(
		"Leaves",
		Vector3.new(s, s * 0.8, s),
		CFrame.new(x, y, z) * CFrame.Angles(0, rng:NextNumber(-0.2, 0.2), 0),
		color,
		Enum.Material.Grass,
		model
	)
end
local function oak(x, z, scale)
	local model = Instance.new("Model")
	model.Name = "Oak"
	model.Parent = decor
	local trunkH = 9 * scale
	part(
		"Trunk",
		Vector3.new(3 * scale, trunkH, 3 * scale),
		CFrame.new(x, trunkH / 2, z),
		WOOD,
		"px_oak_log",
		model
	)
	for i = 1, 4 do
		local a = i * math.pi / 2 + 0.4
		part(
			"Root",
			Vector3.new(1.4 * scale, 1.6, 2.2 * scale),
			CFrame.new(x + math.cos(a) * 1.8 * scale, 0.6, z + math.sin(a) * 1.8 * scale)
				* CFrame.Angles(0, -a, 0),
			WOOD,
			"px_oak_log",
			model
		)
	end
	local s = 9 * scale
	local y = trunkH + s * 0.25
	canopyCube(model, x, y, z, s, LEAF)
	for i = 1, 4 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		canopyCube(
			model,
			x + math.cos(a) * s * 0.42,
			y + rng:NextNumber(-1, 1.5),
			z + math.sin(a) * s * 0.42,
			s * 0.7,
			if i % 2 == 0 then LEAF2 else LEAF3
		)
	end
	canopyCube(
		model,
		x + rng:NextNumber(-1, 1),
		y + s * 0.55,
		z + rng:NextNumber(-1, 1),
		s * 0.6,
		LEAF2
	)
	canopyCube(model, x, y + s * 0.9, z, s * 0.35, LEAF)
	-- a branch with a small cluster
	local ba = rng:NextNumber(0, math.pi * 2)
	part(
		"Branch",
		Vector3.new(1, 1, 4 * scale),
		CFrame.new(x + math.cos(ba) * 2.5 * scale, trunkH * 0.65, z + math.sin(ba) * 2.5 * scale)
			* CFrame.Angles(0, -ba + math.pi / 2, 0)
			* CFrame.Angles(0.5, 0, 0),
		WOOD,
		"px_oak_log",
		model
	)
	canopyCube(
		model,
		x + math.cos(ba) * 4.2 * scale,
		trunkH * 0.65 + 1.5,
		z + math.sin(ba) * 4.2 * scale,
		3.2 * scale,
		LEAF2
	)
end
local function pine(x, z, scale)
	local model = Instance.new("Model")
	model.Name = "Pine"
	model.Parent = decor
	local trunkH = 14 * scale
	part(
		"Trunk",
		Vector3.new(2.2 * scale, trunkH, 2.2 * scale),
		CFrame.new(x, trunkH / 2, z),
		DARK_WOOD,
		"px_oak_log",
		model
	)
	local layers = 5
	for i = 1, layers do
		local s = (9 - i * 1.4) * scale
		local y = trunkH * 0.35 + (i - 1) * 2.6 * scale
		part(
			"Needles",
			Vector3.new(s, 2 * scale, s),
			CFrame.new(x, y, z) * CFrame.Angles(0, (i % 2) * math.pi / 4, 0),
			if i % 2 == 0 then PINE else LEAF3,
			Enum.Material.Grass,
			model
		)
	end
	part(
		"Top",
		Vector3.new(1.4 * scale, 2.4 * scale, 1.4 * scale),
		CFrame.new(x, trunkH + 0.8 * scale, z),
		PINE,
		Enum.Material.Grass,
		model
	)
end
local function birch(x, z, scale)
	local model = Instance.new("Model")
	model.Name = "Birch"
	model.Parent = decor
	local trunkH = 11 * scale
	part(
		"Trunk",
		Vector3.new(2 * scale, trunkH, 2 * scale),
		CFrame.new(x, trunkH / 2, z),
		BIRCH,
		Enum.Material.SmoothPlastic,
		model
	)
	for _ = 1, 6 do
		part(
			"Bark",
			Vector3.new(0.8, 0.5, 2.1 * scale),
			CFrame.new(x + rng:NextNumber(-0.6, 0.6), rng:NextNumber(1, trunkH - 1), z),
			DARK,
			Enum.Material.SmoothPlastic,
			model
		)
	end
	local s = 7 * scale
	canopyCube(model, x, trunkH + 1, z, s, LEAF2)
	canopyCube(
		model,
		x + s * 0.35,
		trunkH + 2.5,
		z - s * 0.2,
		s * 0.7,
		Color3.fromRGB(130, 175, 70)
	)
	canopyCube(model, x - s * 0.3, trunkH + 3.5, z + s * 0.3, s * 0.65, LEAF2)
	canopyCube(model, x, trunkH + s * 0.75, z, s * 0.45, Color3.fromRGB(130, 175, 70))
end
local function tree(x, z, scale)
	local roll = rng:NextNumber()
	if roll < 0.55 then
		oak(x, z, scale)
	elseif roll < 0.8 then
		pine(x, z, scale)
	else
		birch(x, z, scale)
	end
end
local function bush(x, z)
	local s = rng:NextNumber(3, 5)
	part("Bush", Vector3.new(s, s * 0.7, s), CFrame.new(x, s * 0.35, z), LEAF2, Enum.Material.Grass)
	part(
		"Bush",
		Vector3.new(s * 0.6, s * 0.5, s * 0.6),
		CFrame.new(x + s * 0.3, s * 0.6, z - s * 0.2),
		LEAF,
		Enum.Material.Grass
	)
	if rng:NextNumber() < 0.4 then
		for _ = 1, 4 do
			part(
				"Berry",
				Vector3.new(0.4, 0.4, 0.4),
				CFrame.new(
					x + rng:NextNumber(-s / 2, s / 2),
					s * 0.5 + rng:NextNumber(0, 0.5),
					z + rng:NextNumber(-s / 2, s / 2)
				),
				Color3.fromRGB(220, 50, 60),
				Enum.Material.SmoothPlastic
			).CanCollide =
				false
		end
	end
end
local function flowerBed(x, z, w, d)
	part("FlowerBed", Vector3.new(w, 1, d), CFrame.new(x, 0.5, z), DARK_WOOD, "px_planks")
	part(
		"Soil",
		Vector3.new(w - 1, 0.6, d - 1),
		CFrame.new(x, 1.1, z),
		Color3.fromRGB(80, 55, 35),
		"px_dirt"
	)
	for _ = 1, math.floor(w * d / 5) do
		local fx = x + rng:NextNumber(-w / 2 + 1, w / 2 - 1)
		local fz = z + rng:NextNumber(-d / 2 + 1, d / 2 - 1)
		part(
			"Flower",
			Vector3.new(0.6, 1.2, 0.6),
			CFrame.new(fx, 1.9, fz),
			FLOWERS[rng:NextInteger(1, #FLOWERS)],
			Enum.Material.Neon
		).CanCollide =
			false
	end
end
local function lampPost(x, z)
	part("LampBase", Vector3.new(1.6, 1, 1.6), CFrame.new(x, 0.5, z), IRON, Enum.Material.Metal)
	part("LampPole", Vector3.new(0.6, 9, 0.6), CFrame.new(x, 5, z), IRON, Enum.Material.Metal)
	part("LampArm", Vector3.new(0.4, 0.4, 1.6), CFrame.new(x, 9.3, z), IRON, Enum.Material.Metal)
	local head =
		part("LampHead", Vector3.new(1.8, 1.8, 1.8), CFrame.new(x, 10, z), LAMP, Enum.Material.Neon)
	light(head, LAMP, 26, 1.5)
end
local function bench(x, z, rotY)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rotY, 0)
	part("BenchSeat", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.5, 0), WOOD, "px_planks")
	part("BenchBack", Vector3.new(6, 2, 0.4), cf * CFrame.new(0, 2.6, -0.9), WOOD, "px_planks")
	for _, dx in ipairs({ -2.4, 2.4 }) do
		part(
			"BenchLeg",
			Vector3.new(0.5, 1.3, 2),
			cf * CFrame.new(dx, 0.65, 0),
			IRON,
			Enum.Material.Metal
		)
	end
end
local function crate(x, y, z, s, variant)
	return part(
		"Crate",
		Vector3.new(s, s, s),
		CFrame.new(x, y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
		WOOD,
		variant or "px_planks"
	)
end
local function barrel(x, z)
	local p = part(
		"Barrel",
		Vector3.new(4, 3, 3),
		CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		DARK_WOOD,
		Enum.Material.Wood
	)
	p.Shape = Enum.PartType.Cylinder
	part(
		"BarrelRing",
		Vector3.new(0.4, 3.2, 3.2),
		CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		IRON,
		Enum.Material.Metal
	)
end
local function rock(x, z)
	local s = rng:NextNumber(2, 5)
	part(
		"Rock",
		Vector3.new(s, s * 0.6, s * 0.8),
		CFrame.new(x, s * 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		STONE,
		"px_stone"
	)
	part(
		"Rock",
		Vector3.new(s * 0.5, s * 0.4, s * 0.5),
		CFrame.new(x + s * 0.3, s * 0.45, z + s * 0.2)
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		STONE,
		"px_cobblestone"
	)
end
local function banner(x, z, rotY)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rotY, 0)
	part(
		"BannerPole",
		Vector3.new(0.5, 14, 0.5),
		cf * CFrame.new(0, 7, 0),
		IRON,
		Enum.Material.Metal
	)
	part(
		"BannerCloth",
		Vector3.new(4, 7, 0.2),
		cf * CFrame.new(2.3, 10, 0),
		CLOTH,
		Enum.Material.Fabric
	)
	part(
		"BannerStripe",
		Vector3.new(4, 1, 0.25),
		cf * CFrame.new(2.3, 8, 0),
		LAMP,
		Enum.Material.Fabric
	)
end
local function guardTower(x, z)
	part("TowerBase", Vector3.new(14, 34, 14), CFrame.new(x, 17, z), DARK, Enum.Material.Brick)
	part("TowerFloor", Vector3.new(18, 1, 18), CFrame.new(x, 34.5, z), STONE, Enum.Material.Slate)
	part("TowerRail", Vector3.new(18, 2, 18), CFrame.new(x, 36, z), DARK, Enum.Material.Brick)
	part(
		"TowerRailInner",
		Vector3.new(16, 2.2, 16),
		CFrame.new(x, 36, z),
		STONE,
		Enum.Material.Slate
	)
	part("TowerRoof", Vector3.new(20, 1, 20), CFrame.new(x, 44, z), DARK_WOOD, "px_planks")
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(
			"TowerPost",
			Vector3.new(1, 8, 1),
			CFrame.new(x + c[1] * 8, 39.5, z + c[2] * 8),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	local l =
		part("TowerLight", Vector3.new(3, 3, 3), CFrame.new(x, 41, z), LAMP, Enum.Material.Neon)
	light(l, LAMP, 60, 2)
end

-- ---------------------------------------------------------------- walls, towers, gate
for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
	guardTower(c[1] * (HALF - 9), c[2] * (HALF - 9))
end
for i = -3, 3 do
	local t = i * 50
	for _, pos in ipairs({
		Vector3.new(t, 20, -HALF + 2.5),
		Vector3.new(t, 20, HALF - 2.5),
		Vector3.new(-HALF + 2.5, 20, t),
		Vector3.new(HALF - 2.5, 20, t),
	}) do
		local torch =
			part("WallTorch", Vector3.new(1, 1, 1), CFrame.new(pos), LAMP, Enum.Material.Neon)
		light(torch, Color3.fromRGB(255, 170, 90), 30, 1)
	end
end
for i = -24, 24, 2 do
	local t = i * 8
	part("Merlon", Vector3.new(4, 3, 4), CFrame.new(t, 29.5, -HALF), DARK, Enum.Material.Brick)
	part("Merlon", Vector3.new(4, 3, 4), CFrame.new(t, 29.5, HALF), DARK, Enum.Material.Brick)
	part("Merlon", Vector3.new(4, 3, 4), CFrame.new(-HALF, 29.5, t), DARK, Enum.Material.Brick)
	part("Merlon", Vector3.new(4, 3, 4), CFrame.new(HALF, 29.5, t), DARK, Enum.Material.Brick)
end
for i = -4, 4 do
	local t = i * 44
	if math.abs(t) > 12 then
		part(
			"Buttress",
			Vector3.new(5, 20, 3),
			CFrame.new(t, 10, -HALF + 3.5),
			DARK,
			Enum.Material.Brick
		)
		part(
			"Buttress",
			Vector3.new(5, 20, 3),
			CFrame.new(t, 10, HALF - 3.5),
			DARK,
			Enum.Material.Brick
		)
		part(
			"Buttress",
			Vector3.new(3, 20, 5),
			CFrame.new(-HALF + 3.5, 10, t),
			DARK,
			Enum.Material.Brick
		)
		part(
			"Buttress",
			Vector3.new(3, 20, 5),
			CFrame.new(HALF - 3.5, 10, t),
			DARK,
			Enum.Material.Brick
		)
	end
end
for _ = 1, 50 do
	local side = rng:NextInteger(1, 4)
	local t = rng:NextNumber(-180, 180)
	local y = rng:NextNumber(6, 24)
	local h = rng:NextNumber(4, 10)
	local cf = ({
		CFrame.new(t, y, -HALF + 2.3),
		CFrame.new(t, y, HALF - 2.3),
		CFrame.new(-HALF + 2.3, y, t),
		CFrame.new(HALF - 2.3, y, t),
	})[side]
	local size = if side <= 2
		then Vector3.new(rng:NextNumber(2, 4), h, 0.4)
		else Vector3.new(0.4, h, rng:NextNumber(2, 4))
	part("Vine", size, cf, ({ LEAF, LEAF2, LEAF3 })[rng:NextInteger(1, 3)], Enum.Material.Grass).CanCollide =
		false
end
do -- main gate (north)
	part("GateTower", Vector3.new(8, 34, 8), CFrame.new(-11, 17, -HALF), DARK, Enum.Material.Brick)
	part("GateTower", Vector3.new(8, 34, 8), CFrame.new(11, 17, -HALF), DARK, Enum.Material.Brick)
	part("GateArch", Vector3.new(14, 6, 6), CFrame.new(0, 25, -HALF), DARK, Enum.Material.Brick)
	for i = -3, 3 do
		part(
			"GateBar",
			Vector3.new(0.6, 22, 0.6),
			CFrame.new(i * 2, 11, -HALF + 2.6),
			IRON,
			Enum.Material.Metal
		)
	end
	part(
		"GateBar",
		Vector3.new(14, 0.6, 0.6),
		CFrame.new(0, 6, -HALF + 2.6),
		IRON,
		Enum.Material.Metal
	)
	part(
		"GateBar",
		Vector3.new(14, 0.6, 0.6),
		CFrame.new(0, 16, -HALF + 2.6),
		IRON,
		Enum.Material.Metal
	)
	for _, x in ipairs({ -11, 11 }) do
		local l = part(
			"GateLamp",
			Vector3.new(1.4, 1.4, 1.4),
			CFrame.new(x, 22, -HALF + 5),
			LAMP,
			Enum.Material.Neon
		)
		light(l, LAMP, 40, 1.5)
	end
	local gs = part(
		"GateSign",
		Vector3.new(16, 2.4, 0.5),
		CFrame.new(0, 29, -HALF + 3.2),
		DARK_WOOD,
		"px_planks"
	)
	boardText(gs, Enum.NormalId.Front, "ТЮРЬМА")
end
for _ = 1, 12 do
	local t = rng:NextNumber(-180, 180)
	local cf = ({
		CFrame.new(t, 31.4, -HALF),
		CFrame.new(t, 31.4, HALF),
		CFrame.new(-HALF, 31.4, t),
		CFrame.new(HALF, 31.4, t),
	})[rng:NextInteger(1, 4)]
	part(
		"Bird",
		Vector3.new(0.8, 0.6, 1.2),
		cf * CFrame.Angles(0, rng:NextNumber(0, 6), 0),
		DARK,
		Enum.Material.SmoothPlastic
	).CanCollide =
		false
	part(
		"BirdHead",
		Vector3.new(0.4, 0.4, 0.4),
		cf * CFrame.new(0, 0.4, 0.5),
		DARK,
		Enum.Material.SmoothPlastic
	).CanCollide =
		false
end

-- ---------------------------------------------------------------- plaza furniture (plaza is 90 × 90)
for _, b in ipairs({
	{ -24, -20, 0 },
	{ 24, -20, 0 },
	{ -24, 20, math.pi },
	{ 24, 20, math.pi },
	{ -20, -24, math.pi / 2 },
	{ 20, -24, -math.pi / 2 },
	{ -20, 24, math.pi / 2 },
	{ 20, 24, -math.pi / 2 },
}) do
	bench(b[1], b[2], b[3])
end
for _, c in ipairs({ { -36, -36 }, { 36, -36 }, { -36, 36 }, { 36, 36 } }) do
	flowerBed(c[1], c[2], 10, 10)
	lampPost(c[1] + (if c[1] < 0 then -5 else 5), c[2] + (if c[2] < 0 then -5 else 5))
end
for _, c in ipairs({ { -36, -14 }, { -36, 36 }, { 36, 36 }, { 36, -14 } }) do
	tree(c[1] + (if c[1] < 0 then 2 else -2), c[2] - 10, 0.9)
end
banner(-8, 44, 0)
banner(8, 44, math.pi)
for _, x in ipairs({ -22, 22 }) do
	lampPost(x, 42)
	lampPost(x, -42)
end
do -- notice board at the NW plaza corner and a well by the bedroom road
	part("NoticeBoard", Vector3.new(8, 4.5, 0.4), CFrame.new(-52, 4.5, -52), DARK_WOOD, "px_planks")
	part(
		"NoticePost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(-55.5, 3.5, -52),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"NoticePost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(-48.5, 3.5, -52),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part("NoticeRoof", Vector3.new(9, 0.4, 2), CFrame.new(-52, 7, -52), DARK_WOOD, "px_planks")
	for i = 1, 5 do
		part(
			"Notice",
			Vector3.new(1.6, 2, 0.1),
			CFrame.new(-55 + i * 1.3 + (i % 2) * 0.2, 4.6 + (i % 2) * 0.6, -51.7)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)),
			({ Color3.fromRGB(240, 240, 240), Color3.fromRGB(250, 240, 180) })[rng:NextInteger(1, 2)],
			Enum.Material.SmoothPlastic
		)
	end
	local wx, wz = -60, 104
	local ring = part(
		"WellRing",
		Vector3.new(3, 6, 6),
		CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, 0, math.pi / 2),
		STONE,
		"px_cobblestone"
	)
	ring.Shape = Enum.PartType.Cylinder
	local w = part(
		"WellWater",
		Vector3.new(0.4, 4.6, 4.6),
		CFrame.new(wx, 2.2, wz) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(40, 80, 140),
		Enum.Material.Glass
	)
	w.Shape = Enum.PartType.Cylinder
	w.Transparency = 0.3
	part(
		"WellPost",
		Vector3.new(0.6, 8, 0.6),
		CFrame.new(wx - 3, 4, wz),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"WellPost",
		Vector3.new(0.6, 8, 0.6),
		CFrame.new(wx + 3, 4, wz),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"WellRoof",
		Vector3.new(8, 0.5, 5),
		CFrame.new(wx, 8.3, wz - 1.3) * CFrame.Angles(0.5, 0, 0),
		DARK_WOOD,
		"px_planks"
	)
	part(
		"WellRoof",
		Vector3.new(8, 0.5, 5),
		CFrame.new(wx, 8.3, wz + 1.3) * CFrame.Angles(-0.5, 0, 0),
		DARK_WOOD,
		"px_planks"
	)
	local axle = part(
		"WellAxle",
		Vector3.new(7, 0.5, 0.5),
		CFrame.new(wx, 6.5, wz),
		DARK_WOOD,
		Enum.Material.Wood
	)
	axle.Shape = Enum.PartType.Cylinder
	part(
		"WellRope",
		Vector3.new(0.15, 3.5, 0.15),
		CFrame.new(wx, 4.7, wz),
		Color3.fromRGB(200, 180, 140),
		Enum.Material.Fabric
	)
	local bucket = part(
		"WellBucket",
		Vector3.new(1.2, 1.4, 1.4),
		CFrame.new(wx, 3.4, wz) * CFrame.Angles(0, 0, math.pi / 2),
		WOOD,
		Enum.Material.Wood
	)
	bucket.Shape = Enum.PartType.Cylinder
end
do -- gazebo on the east lawn between Рынок and Столовая
	local gx, gz = 160, -62
	local fl =
		part("GazeboFloor", Vector3.new(14, 0.6, 14), CFrame.new(gx, 0.3, gz), WOOD, "px_planks")
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(
			"GazeboPost",
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(gx + c[1] * 6.3, 4.5, gz + c[2] * 6.3),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	for _, s in ipairs({ { 0, -6.3, 0 }, { 6.3, 0, math.pi / 2 }, { 0, 6.3, 0 } }) do
		part(
			"GazeboRail",
			Vector3.new(12, 0.4, 0.4),
			CFrame.new(gx + s[1], 2.5, gz + s[2]) * CFrame.Angles(0, s[3], 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	part("GazeboRoof", Vector3.new(16, 0.6, 16), CFrame.new(gx, 9.3, gz), DARK_WOOD, "px_planks")
	part("GazeboRoof2", Vector3.new(11, 0.6, 11), CFrame.new(gx, 10.6, gz), DARK_WOOD, "px_planks")
	part("GazeboRoof3", Vector3.new(6, 0.6, 6), CFrame.new(gx, 11.9, gz), DARK_WOOD, "px_planks")
	local top = part(
		"GazeboTop",
		Vector3.new(1.5, 1.5, 1.5),
		CFrame.new(gx, 12.9, gz),
		LAMP,
		Enum.Material.Neon
	)
	light(top, LAMP, 22, 1)
	bench(gx, gz - 4, 0)
	bench(gx, gz + 4, math.pi)
	part("GazeboTable", Vector3.new(4, 0.5, 4), CFrame.new(gx, 2.7, gz), WOOD, "px_planks")
	part(
		"GazeboTableLeg",
		Vector3.new(0.6, 2.5, 0.6),
		CFrame.new(gx, 1.5, gz),
		DARK_WOOD,
		Enum.Material.Wood
	)
	fl.CanCollide = true
end

-- ---------------------------------------------------------------- lamps and benches along every road
for _, p in ipairs(root:GetChildren()) do
	if
		p:IsA("BasePart") and p.Name:match("^PathRing")
		or (p:IsA("BasePart") and p.Name:match("^PathSpoke"))
	then
		local horizontal = p.Size.X > p.Size.Z
		local len = if horizontal then p.Size.X else p.Size.Z
		local n = math.max(1, math.floor(len / 40))
		for i = 0, n do
			local t = -len / 2 + 8 + (len - 16) * i / n
			for _, side in ipairs({ -1, 1 }) do
				local off = side * (p.Size.Z / 2 + 3)
				local x = if horizontal then p.Position.X + t else p.Position.X + off
				local z = if horizontal then p.Position.Z + off else p.Position.Z + t
				if free(x, z, -4) then
					lampPost(x, z)
				end
			end
		end
	end
end
for _ = 1, 10 do
	local x, z = rng:NextNumber(-180, 180), rng:NextNumber(-180, 180)
	if free(x, z, 2) then
		local pud = part(
			"Puddle",
			Vector3.new(rng:NextNumber(3, 6), 0.12, rng:NextNumber(2, 5)),
			CFrame.new(x, 0.06, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.fromRGB(90, 130, 170),
			Enum.Material.Glass
		)
		pud.Transparency = 0.4
		pud.CanCollide = false
	end
end

-- ---------------------------------------------------------------- mine yards: scaffolding, crane, block piles, signs
for _, h in ipairs({
	{ -72, 72, -192, -48, "ШАХТА" },
	{ -40, 40, 80, 160, "МАЛАЯ ШАХТА" },
}) do
	for _, c in ipairs({ { h[1], h[3] }, { h[2], h[3] }, { h[1], h[4] }, { h[2], h[4] } }) do
		lampPost(c[1] + (if c[1] < 0 then -3 else 3), c[2] + (if c[2] < 0 then -3 else 3))
	end
	for x = h[1], h[2], 8 do
		for _, z in ipairs({ h[3], h[4] }) do
			if math.abs(x) > 9 then
				part(
					"FencePost",
					Vector3.new(1, 4, 1),
					CFrame.new(x, 2, z),
					DARK_WOOD,
					Enum.Material.Wood
				).CanCollide =
					false
			end
		end
	end
	for z = h[3] + 8, h[4] - 8, 8 do
		for _, x in ipairs({ h[1], h[2] }) do
			part(
				"FencePost",
				Vector3.new(1, 4, 1),
				CFrame.new(x, 2, z),
				DARK_WOOD,
				Enum.Material.Wood
			).CanCollide =
				false
		end
	end
	local sx, sz = h[2] + 8, h[3] + 12
	for lv = 0, 2 do
		for _, c in ipairs({ { -3, -3 }, { 3, -3 }, { -3, 3 }, { 3, 3 } }) do
			part(
				"Scaffold",
				Vector3.new(0.6, 6, 0.6),
				CFrame.new(sx + c[1], 3 + lv * 6, sz + c[2]),
				DARK_WOOD,
				Enum.Material.Wood
			)
		end
		part(
			"ScaffoldDeck",
			Vector3.new(7, 0.4, 7),
			CFrame.new(sx, 6.2 + lv * 6, sz),
			WOOD,
			"px_planks"
		)
		part(
			"ScaffoldRail",
			Vector3.new(7, 0.3, 0.3),
			CFrame.new(sx, 7.6 + lv * 6, sz + 3.5),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	local craneX, craneZ = h[1] - 10, h[4] - 12
	part(
		"CraneBase",
		Vector3.new(4, 1, 4),
		CFrame.new(craneX, 0.5, craneZ),
		DARK,
		Enum.Material.Slate
	)
	part(
		"CraneMast",
		Vector3.new(1.2, 18, 1.2),
		CFrame.new(craneX, 9, craneZ),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"CraneArm",
		Vector3.new(1, 1, 14),
		CFrame.new(craneX, 17, craneZ - 6) * CFrame.Angles(-0.35, 0, 0),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"CraneRope",
		Vector3.new(0.15, 10, 0.15),
		CFrame.new(craneX, 12, craneZ - 12.5),
		Color3.fromRGB(200, 180, 140),
		Enum.Material.Fabric
	)
	part(
		"CraneHook",
		Vector3.new(1.2, 0.3, 1.2),
		CFrame.new(craneX, 7, craneZ - 12.5),
		IRON,
		Enum.Material.Metal
	).CanCollide =
		false
	part(
		"CraneLoad",
		Vector3.new(3, 3, 3),
		CFrame.new(craneX, 5.3, craneZ - 12.5),
		STONE,
		"px_stone"
	)
	-- block piles + cart + rails on the side away from the entrance
	local px = h[2] + 12
	local pz = if h[4] < 0 then h[3] + 30 else h[3] + 20
	for i, variant in ipairs({ "px_dirt", "px_sand", "px_gravel", "px_cobblestone" }) do
		local bz = pz + (i - 1) * 7
		for lv = 1, 3 do
			local n = 4 - lv
			for j = 1, n do
				part(
					"Pile",
					Vector3.new(3, 3, 3),
					CFrame.new(px + (lv - 1) * 0.3, lv * 3 - 1.5, bz + (j - (n + 1) / 2) * 3),
					STONE,
					variant
				)
			end
		end
	end
	local ex, ez = px + 8, pz + 10
	part(
		"CartBody",
		Vector3.new(6, 3, 4),
		CFrame.new(ex, 2.5, ez) * CFrame.Angles(0, math.pi / 2, 0),
		IRON,
		Enum.Material.Metal
	)
	part(
		"CartOre",
		Vector3.new(5, 1.5, 3),
		CFrame.new(ex, 4.5, ez) * CFrame.Angles(0, math.pi / 2, 0),
		STONE,
		"px_coal_ore"
	)
	for _, d in ipairs({ { -1.5, -2 }, { 1.5, -2 }, { -1.5, 2 }, { 1.5, 2 } }) do
		local wheel = part(
			"CartWheel",
			Vector3.new(0.5, 1.6, 1.6),
			CFrame.new(ex + d[1], 0.8, ez + d[2]),
			DARK,
			Enum.Material.Metal
		)
		wheel.Shape = Enum.PartType.Cylinder
	end
	part(
		"Rail",
		Vector3.new(0.5, 0.3, 24),
		CFrame.new(ex - 1.5, 0.15, ez + 8),
		IRON,
		Enum.Material.Metal
	)
	part(
		"Rail",
		Vector3.new(0.5, 0.3, 24),
		CFrame.new(ex + 1.5, 0.15, ez + 8),
		IRON,
		Enum.Material.Metal
	)
	for i = 0, 5 do
		part(
			"Sleeper",
			Vector3.new(4, 0.25, 1),
			CFrame.new(ex, 0.1, ez - 2 + i * 4),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	-- signpost by the entrance gate
	local gateZ = if h[4] < 0 then h[4] else h[3]
	local sp = part(
		"SignPost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(-12, 3.5, gateZ + (if h[4] < 0 then 4 else -4)),
		DARK_WOOD,
		Enum.Material.Wood
	)
	sp.CanCollide = false
	local arrow = part(
		"SignArrow",
		Vector3.new(6, 1.4, 0.4),
		CFrame.new(-9.5, 6.5, gateZ + (if h[4] < 0 then 4 else -4)),
		DARK_WOOD,
		"px_planks"
	)
	boardText(arrow, if h[4] < 0 then Enum.NormalId.Back else Enum.NormalId.Front, h[5])
	rock(h[1] - 6, gateZ + (if h[4] < 0 then 8 else -8))
end

-- ---------------------------------------------------------------- Малая шахта surroundings: melon patches, orchard, hay
-- patch(cx, cz, alongX): a 14 × 6 field of melon vines with a low fence.
local function patch(cx, cz, alongX)
	local cf = CFrame.new(cx, 0, cz) * CFrame.Angles(0, if alongX then 0 else math.pi / 2, 0)
	part("FieldSoil", Vector3.new(14, 0.5, 6), cf * CFrame.new(0, 0.25, 0), STONE, "px_dirt")
	for i = -2, 2 do
		local lx = i * 3
		part(
			"Vine",
			Vector3.new(1.2, 0.3, 4),
			cf * CFrame.new(lx, 0.6, 0),
			LEAF,
			Enum.Material.Grass
		).CanCollide =
			false
		part(
			"VineLeaf",
			Vector3.new(1.8, 0.2, 1.4),
			cf
				* CFrame.new(lx + rng:NextNumber(-0.6, 0.6), 0.75, rng:NextNumber(-1.5, 1.5))
				* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			LEAF2,
			Enum.Material.Grass
		).CanCollide =
			false
		if rng:NextNumber() < 0.7 then
			part(
				"Melon",
				Vector3.new(2, 2, 2),
				cf
					* CFrame.new(
						lx + rng:NextNumber(-0.4, 0.4),
						1.5,
						if rng:NextNumber() < 0.5 then -2.2 else 2.2
					)
					* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				Color3.new(1, 1, 1),
				"px_melon"
			)
		end
	end
	for _, dz in ipairs({ -3.6, 3.6 }) do
		part(
			"FieldFence",
			Vector3.new(15, 0.3, 0.3),
			cf * CFrame.new(0, 1.3, dz),
			DARK_WOOD,
			Enum.Material.Wood
		).CanCollide =
			false
	end
end
-- west side of the small mine: four patches in a column + orchard
for row = 0, 3 do
	patch(-58, 92 + row * 16, true)
end
for _, z in ipairs({ 84, 108, 132, 156 }) do
	tree(-74, z, rng:NextNumber(0.8, 1.1))
end
-- south side (between the mine rim and the wall): three patches in a row + orchard
for _, x in ipairs({ -22, 0, 22 }) do
	patch(x, 176, true)
end
for _, x in ipairs({ -40, 40 }) do
	tree(x, 178, rng:NextNumber(0.8, 1.1))
end
for i = 1, 3 do
	local hb = part(
		"HayBale",
		Vector3.new(3, 2.2, 2.2),
		CFrame.new(-46, 1.1 + (i == 3 and 2.2 or 0), 160 + (i % 2) * 3.3),
		Color3.fromRGB(220, 190, 90),
		Enum.Material.Fabric
	)
	part("HayBand", Vector3.new(3.1, 0.3, 2.3), hb.CFrame, DARK_WOOD, Enum.Material.Fabric)
end
do
	local sx, sz = 44, 180
	part(
		"Scarecrow",
		Vector3.new(0.5, 7, 0.5),
		CFrame.new(sx, 3.5, sz),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"ScarecrowArms",
		Vector3.new(5, 0.4, 0.4),
		CFrame.new(sx, 5.5, sz),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"ScarecrowBody",
		Vector3.new(1.8, 2.4, 1),
		CFrame.new(sx, 5, sz),
		Color3.fromRGB(120, 70, 40),
		Enum.Material.Fabric
	)
	part(
		"ScarecrowHead",
		Vector3.new(1.2, 1.2, 1.2),
		CFrame.new(sx, 7.2, sz),
		Color3.fromRGB(230, 200, 100),
		Enum.Material.Fabric
	)
	part(
		"ScarecrowHat",
		Vector3.new(2, 0.3, 2),
		CFrame.new(sx, 7.9, sz),
		Color3.fromRGB(200, 170, 80),
		Enum.Material.Fabric
	)
	crate(-50, 0, 180, 2.5, "px_melon")
	crate(-50, 2.5, 180, 2, "px_melon")
	barrel(-54, 182)
end
-- Pond reeds and lily pads (pond cut by build-prison at (-92, 168), 32 × 20)
for i = 1, 14 do
	local a = i * math.pi * 2 / 14
	local x, z = -92 + math.cos(a) * 17.5, 168 + math.sin(a) * 11.5
	for _ = 1, 3 do
		part(
			"Reed",
			Vector3.new(0.25, rng:NextNumber(3, 5), 0.25),
			CFrame.new(x + rng:NextNumber(-1, 1), 1.5, z + rng:NextNumber(-1, 1)),
			LEAF3,
			Enum.Material.Grass
		).CanCollide =
			false
	end
end
for _ = 1, 6 do
	local lp = part(
		"LilyPad",
		Vector3.new(0.2, 1.8, 1.8),
		CFrame.new(-92 + rng:NextNumber(-12, 12), 0.1, 168 + rng:NextNumber(-7, 7))
			* CFrame.Angles(0, 0, math.pi / 2),
		LEAF2,
		Enum.Material.Grass
	)
	lp.Shape = Enum.PartType.Cylinder
	lp.CanCollide = false
end
part("Dock", Vector3.new(4, 0.5, 10), CFrame.new(-92, 0.5, 155), WOOD, "px_planks").CanCollide =
	true
part(
	"DockPost",
	Vector3.new(0.6, 3, 0.6),
	CFrame.new(-93.5, 0.8, 159),
	DARK_WOOD,
	Enum.Material.Wood
)
part(
	"DockPost",
	Vector3.new(0.6, 3, 0.6),
	CFrame.new(-90.5, 0.8, 159),
	DARK_WOOD,
	Enum.Material.Wood
)

-- ---------------------------------------------------------------- trees, bushes, rocks, grass, flowers
local trees, bushes, rocks = 0, 0, 0
for _ = 1, 4000 do
	if trees >= 90 and bushes >= 70 and rocks >= 30 then
		break
	end
	local x = rng:NextNumber(-HALF + 12, HALF - 12)
	local z = rng:NextNumber(-HALF + 12, HALF - 12)
	if free(x, z, 6) and farFromOthers(x, z, 10) then
		table.insert(placed, Vector2.new(x, z))
		local roll = rng:NextNumber()
		if trees < 90 and roll < 0.5 then
			tree(x, z, rng:NextNumber(0.85, 1.5))
			trees += 1
		elseif bushes < 70 and roll < 0.85 then
			bush(x, z)
			bushes += 1
		elseif rocks < 30 then
			rock(x, z)
			rocks += 1
		end
	end
end
local tufts, flowers, shrooms, logs = 0, 0, 0, 0
for _ = 1, 4000 do
	if tufts >= 320 and flowers >= 160 and shrooms >= 35 and logs >= 16 then
		break
	end
	local x = rng:NextNumber(-HALF + 10, HALF - 10)
	local z = rng:NextNumber(-HALF + 10, HALF - 10)
	if free(x, z, 1.5) then
		local roll = rng:NextNumber()
		if tufts < 320 and roll < 0.55 then
			for i = 1, 3 do
				part(
					"Grass",
					Vector3.new(1.4, rng:NextNumber(1, 1.8), 0.15),
					CFrame.new(x, 0.6, z)
						* CFrame.Angles(0, i * math.pi / 3 + rng:NextNumber(0, 0.5), 0),
					({ LEAF, LEAF2, Color3.fromRGB(120, 170, 70) })[rng:NextInteger(1, 3)],
					Enum.Material.Grass
				).CanCollide =
					false
			end
			tufts += 1
		elseif flowers < 160 and roll < 0.85 then
			part(
				"WildFlower",
				Vector3.new(0.5, 1, 0.5),
				CFrame.new(x, 0.5, z),
				FLOWERS[rng:NextInteger(1, #FLOWERS)],
				Enum.Material.Neon
			).CanCollide =
				false
			part(
				"Stem",
				Vector3.new(0.15, 0.8, 0.15),
				CFrame.new(x, 0.3, z),
				LEAF,
				Enum.Material.Grass
			).CanCollide =
				false
			flowers += 1
		elseif shrooms < 35 and roll < 0.95 then
			part(
				"MushroomStem",
				Vector3.new(0.5, 0.9, 0.5),
				CFrame.new(x, 0.45, z),
				Color3.fromRGB(230, 220, 200),
				Enum.Material.SmoothPlastic
			).CanCollide =
				false
			part(
				"MushroomCap",
				Vector3.new(1.3, 0.6, 1.3),
				CFrame.new(x, 1.1, z),
				({ Color3.fromRGB(200, 50, 50), Color3.fromRGB(160, 110, 70) })[rng:NextInteger(
					1,
					2
				)],
				Enum.Material.SmoothPlastic
			).CanCollide =
				false
			shrooms += 1
		elseif logs < 16 and free(x, z, 5) then
			if rng:NextNumber() < 0.5 then
				local l = part(
					"Log",
					Vector3.new(7, 1.8, 1.8),
					CFrame.new(x, 0.9, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
					WOOD,
					"px_oak_log"
				)
				l.Shape = Enum.PartType.Cylinder
			else
				local st = part(
					"Stump",
					Vector3.new(1.6, 2.4, 2.4),
					CFrame.new(x, 0.8, z) * CFrame.Angles(0, 0, math.pi / 2),
					WOOD,
					"px_oak_log"
				)
				st.Shape = Enum.PartType.Cylinder
			end
			logs += 1
		end
	end
end

-- Lighting mood
local Lighting = game:GetService("Lighting")
Lighting.ClockTime = 14.5
Lighting.Brightness = 2
Lighting.OutdoorAmbient = Color3.fromRGB(128, 128, 128)
if not Lighting:FindFirstChildOfClass("Atmosphere") then
	local atm = Instance.new("Atmosphere")
	atm.Density = 0.32
	atm.Haze = 1.2
	atm.Parent = Lighting
end

return string.format(
	"[decorate-prison] trees %d, bushes %d, rocks %d, parts %d, keep-outs %d",
	trees,
	bushes,
	rocks,
	#decor:GetDescendants(),
	#blocked
)
