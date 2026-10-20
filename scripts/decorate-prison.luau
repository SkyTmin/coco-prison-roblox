--!strict
-- Decoration pass for the Тюрьма location (PLAN 1.4: locations must be spacious and not empty).
-- Run in Studio (Edit) after build-prison, build-buildings and build-npcs (outdoor props only). Idempotent: replaces Workspace.Prison.Decor.
-- Everything is cubic (parts only) so it reads as the same style as the block mines; no assets needed.
-- Placement is deterministic (seeded) and avoids paths, the plaza, buildings and the two pits.

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
local rng = Random.new(20261020)

local WOOD = Color3.fromRGB(120, 85, 50)
local DARK_WOOD = Color3.fromRGB(85, 60, 35)
local LEAF = Color3.fromRGB(70, 125, 55)
local LEAF2 = Color3.fromRGB(95, 150, 60)
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
}

local function part(
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?,
	parent: Instance?
): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or decor
	return p
end

-- Keep-out rectangles {x0, x1, z0, z1}: paths, plaza, pits (with rim), buildings (+margin).
local blocked: { { number } } = {
	{ -9, 9, -HALF, HALF }, -- N–S path
	{ -HALF, HALF, -9, 9 }, -- E–W path
	{ -34, 34, -34, 38 }, -- plaza, NPCs, teleporter
	{ -76, 76, -196, -44 }, -- Шахта pit + rim
	{ -44, 44, 76, 164 }, -- Малая шахта pit + rim
	{ -156, -80, -146, -84 }, -- Баня + дровник + водонапорная башня
	{ 86, 156, -136, -76 }, -- Рынок + прилавки
	{ -156, -86, 84, 136 }, -- Спальня + крыльцо
	{ 102, 164, -34, 54 }, -- Столовая + терраса
	{ -18, 18, -68, -40 }, -- Задания
	{ 66, 118, 112, 152 }, -- Тренер
}
local function free(x: number, z: number, margin: number): boolean
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
local placed: { Vector2 } = {}
local function farFromOthers(x: number, z: number, dist: number): boolean
	for _, v in ipairs(placed) do
		if (v - Vector2.new(x, z)).Magnitude < dist then
			return false
		end
	end
	return true
end

-- ---------------------------------------------------------------- props
local function tree(x: number, z: number, scale: number)
	local trunkH = 10 * scale
	local model = Instance.new("Model")
	model.Name = "Tree"
	model.Parent = decor
	part(
		"Trunk",
		Vector3.new(3, trunkH, 3),
		CFrame.new(x, trunkH / 2, z),
		DARK_WOOD,
		Enum.Material.Wood,
		model
	)
	local s = 10 * scale
	part(
		"Leaves",
		Vector3.new(s, s * 0.7, s),
		CFrame.new(x, trunkH + s * 0.3, z),
		LEAF,
		Enum.Material.Grass,
		model
	)
	part(
		"Leaves",
		Vector3.new(s * 0.6, s * 0.5, s * 0.6),
		CFrame.new(x, trunkH + s * 0.85, z),
		LEAF2,
		Enum.Material.Grass,
		model
	)
end

local function bush(x: number, z: number)
	local s = rng:NextNumber(3, 5)
	part("Bush", Vector3.new(s, s * 0.7, s), CFrame.new(x, s * 0.35, z), LEAF2, Enum.Material.Grass)
end

local function flowerBed(x: number, z: number, w: number, d: number)
	part("FlowerBed", Vector3.new(w, 1, d), CFrame.new(x, 0.5, z), DARK_WOOD, Enum.Material.Wood)
	part(
		"Soil",
		Vector3.new(w - 1, 0.6, d - 1),
		CFrame.new(x, 1.1, z),
		Color3.fromRGB(80, 55, 35),
		Enum.Material.Ground
	)
	local n = math.floor(w * d / 6)
	for _ = 1, n do
		local fx = x + rng:NextNumber(-w / 2 + 1, w / 2 - 1)
		local fz = z + rng:NextNumber(-d / 2 + 1, d / 2 - 1)
		part(
			"Flower",
			Vector3.new(0.6, 1.2, 0.6),
			CFrame.new(fx, 1.9, fz),
			FLOWERS[rng:NextInteger(1, #FLOWERS)],
			Enum.Material.Neon
		)
	end
end

local function lampPost(x: number, z: number)
	part("LampBase", Vector3.new(1.6, 1, 1.6), CFrame.new(x, 0.5, z), IRON, Enum.Material.Metal)
	part("LampPole", Vector3.new(0.6, 9, 0.6), CFrame.new(x, 5, z), IRON, Enum.Material.Metal)
	local head =
		part("LampHead", Vector3.new(1.8, 1.8, 1.8), CFrame.new(x, 10, z), LAMP, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Brightness = 1.5
	light.Range = 26
	light.Parent = head
end

local function bench(x: number, z: number, rotY: number)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, rotY, 0)
	part("BenchSeat", Vector3.new(6, 0.5, 2), cf * CFrame.new(0, 1.5, 0), WOOD, Enum.Material.Wood)
	part(
		"BenchBack",
		Vector3.new(6, 2, 0.4),
		cf * CFrame.new(0, 2.6, -0.9),
		WOOD,
		Enum.Material.Wood
	)
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

local function crate(x: number, y: number, z: number, s: number)
	local p = part(
		"Crate",
		Vector3.new(s, s, s),
		CFrame.new(x, y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
		WOOD,
		Enum.Material.WoodPlanks
	)
	return p
end

local function barrel(x: number, z: number)
	local p =
		part("Barrel", Vector3.new(3, 4, 3), CFrame.new(x, 2, z), DARK_WOOD, Enum.Material.Wood)
	p.Shape = Enum.PartType.Cylinder
	p.CFrame = CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.pi / 2)
	part(
		"BarrelRing",
		Vector3.new(0.4, 3.2, 3.2),
		CFrame.new(x, 2, z) * CFrame.Angles(0, 0, math.pi / 2),
		IRON,
		Enum.Material.Metal
	)
end

local function rock(x: number, z: number)
	local s = rng:NextNumber(2, 5)
	part(
		"Rock",
		Vector3.new(s, s * 0.6, s * 0.8),
		CFrame.new(x, s * 0.25, z) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0),
		STONE,
		Enum.Material.Slate
	)
end

local function banner(x: number, z: number, rotY: number)
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

local function guardTower(x: number, z: number)
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
	part(
		"TowerRoof",
		Vector3.new(20, 1, 20),
		CFrame.new(x, 44, z),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
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
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Brightness = 2
	light.Range = 60
	light.Parent = l
end

-- ---------------------------------------------------------------- layout
-- Guard towers at the four wall corners, torches along the walls.
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
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 90)
		light.Range = 30
		light.Parent = torch
	end
end

-- Plaza: benches, flower beds in the corners, banners by the teleporter.
for _, b in ipairs({ { -12, -22, 0 }, { 12, -22, 0 }, { -22, 22, math.pi }, { 12, 22, math.pi } }) do
	bench(b[1], b[2], b[3])
end
for _, c in ipairs({ { -24, -24 }, { 24, -24 }, { -24, 24 }, { 24, 24 } }) do
	flowerBed(c[1], c[2], 8, 8)
end
banner(-8, 30, 0)
banner(8, 30, math.pi)
for _, c in ipairs({ { -30, -30 }, { 30, -30 }, { -30, 30 }, { 30, 30 } }) do
	lampPost(c[1], c[2])
end

-- Lamp posts along both paths (skipping the mine holes and the plaza).
for z = -180, 180, 40 do
	local inHole = (z > -196 and z < -44) or (z > 76 and z < 164)
	if math.abs(z) > 34 and not inHole then
		lampPost(-10, z)
		lampPost(10, z)
	end
end
for x = -180, 180, 40 do
	if math.abs(x) > 34 then
		lampPost(x, -10)
		lampPost(x, 10)
	end
end

-- Market stalls outside Рынок, crates and barrels by the buyer.
for i = 0, 2 do
	local x = 96 + i * 16
	part("StallTop", Vector3.new(10, 0.6, 8), CFrame.new(x, 7, -80), CLOTH, Enum.Material.Fabric)
	part(
		"StallCounter",
		Vector3.new(10, 3, 3),
		CFrame.new(x, 1.5, -78),
		WOOD,
		Enum.Material.WoodPlanks
	)
	for _, dx in ipairs({ -4.5, 4.5 }) do
		part(
			"StallPost",
			Vector3.new(0.6, 7, 0.6),
			CFrame.new(x + dx, 3.5, -84),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	crate(x - 3, 3, -78, 2)
end
crate(-30, 0, 14, 4)
crate(-30, 4, 14, 3)
crate(-34, 0, 18, 3)
barrel(-30, 22)
barrel(-34, 24)
crate(30, 0, -18, 3)
barrel(34, -20)

-- Rope fence posts around both pit rims (decorative, no collision so ladders stay reachable).
for _, h in ipairs({ { -72, 72, -192, -48 }, { -40, 40, 80, 160 } }) do
	for x = h[1], h[2], 8 do
		for _, z in ipairs({ h[3], h[4] }) do
			local p = part(
				"FencePost",
				Vector3.new(1, 4, 1),
				CFrame.new(x, 2, z),
				DARK_WOOD,
				Enum.Material.Wood
			)
			p.CanCollide = false
		end
	end
	for z = h[3] + 8, h[4] - 8, 8 do
		for _, x in ipairs({ h[1], h[2] }) do
			local p = part(
				"FencePost",
				Vector3.new(1, 4, 1),
				CFrame.new(x, 2, z),
				DARK_WOOD,
				Enum.Material.Wood
			)
			p.CanCollide = false
		end
	end
	-- mine carts and ore piles by the pit entrance (south side)
	local ex, ez = h[1] + 20, h[4] + 10
	part("CartBody", Vector3.new(6, 3, 4), CFrame.new(ex, 2.5, ez), IRON, Enum.Material.Metal)
	part("CartOre", Vector3.new(5, 1.5, 3), CFrame.new(ex, 4.5, ez), STONE, Enum.Material.Slate)
	for _, d in ipairs({ { -2, -1.5 }, { 2, -1.5 }, { -2, 1.5 }, { 2, 1.5 } }) do
		local w = part(
			"CartWheel",
			Vector3.new(1.6, 1.6, 0.5),
			CFrame.new(ex + d[1], 0.8, ez + d[2]),
			DARK,
			Enum.Material.Metal
		)
		w.Shape = Enum.PartType.Cylinder
		w.CFrame = CFrame.new(ex + d[1], 0.8, ez + d[2]) * CFrame.Angles(0, 0, math.pi / 2)
		w.Size = Vector3.new(0.5, 1.6, 1.6)
	end
	rock(ex + 8, ez)
	rock(ex + 11, ez + 3)
	part(
		"Rail",
		Vector3.new(0.5, 0.3, 16),
		CFrame.new(ex - 2, 0.15, ez + 10),
		IRON,
		Enum.Material.Metal
	)
	part(
		"Rail",
		Vector3.new(0.5, 0.3, 16),
		CFrame.new(ex + 2, 0.15, ez + 10),
		IRON,
		Enum.Material.Metal
	)
end

-- ---------------------------------------------------------------- outdoor detail pass (v2)
local function textured(p: Part, variant: string): Part
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = variant
	p.Color = Color3.new(1, 1, 1)
	return p
end
local function boardText(target: BasePart, face: Enum.NormalId, text: string)
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
-- Plaza: checker tiles, miner statue in the fountain, splashing water, notice board, well, gazebo.
for ix = -3, 3 do
	for iz = -3, 3 do
		if (ix + iz) % 2 == 0 and not (ix == 0 and iz == 0) then
			textured(
				part(
					"PlazaTile",
					Vector3.new(7.6, 0.2, 7.6),
					CFrame.new(ix * 8, 0.7, iz * 8),
					STONE
				),
				"px_cobblestone"
			)
		end
	end
end
do -- statue of a miner on the fountain pillar
	local s = CFrame.new(0, 9.5, 0)
	part("StatueBody", Vector3.new(2, 3, 1.2), s, STONE, Enum.Material.Slate)
	part(
		"StatueHead",
		Vector3.new(1.2, 1.2, 1.2),
		s * CFrame.new(0, 2.1, 0),
		STONE,
		Enum.Material.Slate
	)
	part(
		"StatueHelmet",
		Vector3.new(1.4, 0.5, 1.4),
		s * CFrame.new(0, 2.8, 0),
		STONE,
		Enum.Material.Slate
	)
	part(
		"StatueLegs",
		Vector3.new(2, 2.5, 1.2),
		s * CFrame.new(0, -2.75, 0),
		STONE,
		Enum.Material.Slate
	)
	part(
		"StatueArm",
		Vector3.new(0.7, 2.6, 0.7),
		s * CFrame.new(1.4, 0.9, 0) * CFrame.Angles(0, 0, -0.9),
		STONE,
		Enum.Material.Slate
	)
	part(
		"StatuePick",
		Vector3.new(0.3, 4, 0.3),
		s * CFrame.new(2.6, 2.4, 0) * CFrame.Angles(0, 0, 0.5),
		DARK,
		Enum.Material.Slate
	)
	part(
		"StatuePickHead",
		Vector3.new(2.4, 0.5, 0.5),
		s * CFrame.new(3.5, 4.2, 0) * CFrame.Angles(0, 0, 0.5),
		DARK,
		Enum.Material.Slate
	)
	local spray =
		part("Spray", Vector3.new(1, 1, 1), CFrame.new(0, 4, 0), LAMP, Enum.Material.SmoothPlastic)
	spray.Transparency = 1
	spray.CanCollide = false
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
	e.Rate = 40
	e.Size = NumberSequence.new(0.35)
	e.Speed = NumberRange.new(9, 12)
	e.Lifetime = NumberRange.new(1.2)
	e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0, -16, 0)
	e.Transparency = NumberSequence.new(0.3)
	e.Parent = spray
	for i = 1, 8 do
		local a = i * math.pi / 4
		local jet = part(
			"Jet",
			Vector3.new(0.5, 0.5, 0.5),
			CFrame.new(math.cos(a) * 4.5, 3.6, math.sin(a) * 4.5),
			STONE,
			Enum.Material.Slate
		)
		local je = e:Clone()
		je.Rate = 8
		je.Speed = NumberRange.new(5, 7)
		je.Parent = jet
	end
end
do -- notice board by the quest office and a well on the south-west lawn
	textured(
		part("NoticeBoard", Vector3.new(8, 4.5, 0.4), CFrame.new(-26, 4.5, -38), DARK_WOOD),
		"px_planks"
	)
	part(
		"NoticePost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(-29.5, 3.5, -38),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"NoticePost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(-22.5, 3.5, -38),
		DARK_WOOD,
		Enum.Material.Wood
	)
	part(
		"NoticeRoof",
		Vector3.new(9, 0.4, 2),
		CFrame.new(-26, 7, -38),
		DARK_WOOD,
		Enum.Material.Wood
	)
	for i = 1, 5 do
		part(
			"Notice",
			Vector3.new(1.6, 2, 0.1),
			CFrame.new(-29 + i * 1.3 + (i % 2) * 0.2, 4.6 + (i % 2) * 0.6, -37.7)
				* CFrame.Angles(0, 0, rng:NextNumber(-0.15, 0.15)),
			({ Color3.fromRGB(240, 240, 240), Color3.fromRGB(250, 240, 180) })[rng:NextInteger(1, 2)],
			Enum.Material.SmoothPlastic
		)
	end
	local wx, wz = -60, 60
	local ring = part(
		"WellRing",
		Vector3.new(3, 6, 6),
		CFrame.new(wx, 1.5, wz) * CFrame.Angles(0, 0, math.pi / 2),
		STONE
	)
	ring.Shape = Enum.PartType.Cylinder
	textured(ring, "px_cobblestone")
	local water = part(
		"WellWater",
		Vector3.new(0.4, 4.6, 4.6),
		CFrame.new(wx, 2.2, wz) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(40, 80, 140),
		Enum.Material.Glass
	)
	water.Shape = Enum.PartType.Cylinder
	water.Transparency = 0.3
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
		Enum.Material.WoodPlanks
	)
	part(
		"WellRoof",
		Vector3.new(8, 0.5, 5),
		CFrame.new(wx, 8.3, wz + 1.3) * CFrame.Angles(-0.5, 0, 0),
		DARK_WOOD,
		Enum.Material.WoodPlanks
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
do -- gazebo on the east lawn
	local gx, gz = 70, -40
	local fl = textured(
		part("GazeboFloor", Vector3.new(14, 0.6, 14), CFrame.new(gx, 0.3, gz), WOOD),
		"px_planks"
	)
	for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(
			"GazeboPost",
			Vector3.new(0.8, 9, 0.8),
			CFrame.new(gx + c[1] * 6.3, 4.5, gz + c[2] * 6.3),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	for _, s in ipairs({ { 0, -6.3, 0 }, { -6.3, 0, math.pi / 2 }, { 6.3, 0, math.pi / 2 } }) do
		part(
			"GazeboRail",
			Vector3.new(12, 0.4, 0.4),
			CFrame.new(gx + s[1], 2.5, gz + s[2]) * CFrame.Angles(0, s[3], 0),
			DARK_WOOD,
			Enum.Material.Wood
		)
	end
	part(
		"GazeboRoof",
		Vector3.new(16, 0.6, 16),
		CFrame.new(gx, 9.3, gz),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	part(
		"GazeboRoof2",
		Vector3.new(11, 0.6, 11),
		CFrame.new(gx, 10.6, gz),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	part(
		"GazeboRoof3",
		Vector3.new(6, 0.6, 6),
		CFrame.new(gx, 11.9, gz),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	part(
		"GazeboTop",
		Vector3.new(1.5, 1.5, 1.5),
		CFrame.new(gx, 12.9, gz),
		LAMP,
		Enum.Material.Neon
	)
	local l = Instance.new("PointLight")
	l.Color = LAMP
	l.Range = 22
	l.Parent = fl
	bench(gx, gz - 4, 0)
	bench(gx, gz + 4, math.pi)
	part("GazeboTable", Vector3.new(4, 0.5, 4), CFrame.new(gx, 2.7, gz), WOOD, Enum.Material.Wood)
	part(
		"GazeboTableLeg",
		Vector3.new(0.6, 2.5, 0.6),
		CFrame.new(gx, 1.5, gz),
		DARK_WOOD,
		Enum.Material.Wood
	)
end
-- Paths: cobblestone edging and puddles.
for _, seg in ipairs({ { -196, -190 }, { -44, -34 }, { 34, 76 }, { 164, 190 } }) do
	for _, x in ipairs({ -8, 8 }) do
		textured(
			part(
				"PathEdge",
				Vector3.new(1.2, 0.5, seg[2] - seg[1]),
				CFrame.new(x, 0.25, (seg[1] + seg[2]) / 2),
				STONE
			),
			"px_cobblestone"
		)
	end
end
for _, z in ipairs({ -8, 8 }) do
	for _, seg in ipairs({ { -190, -34 }, { 34, 190 } }) do
		textured(
			part(
				"PathEdge",
				Vector3.new(seg[2] - seg[1], 0.5, 1.2),
				CFrame.new((seg[1] + seg[2]) / 2, 0.25, z),
				STONE
			),
			"px_cobblestone"
		)
	end
end
for _ = 1, 10 do
	local x, z = rng:NextNumber(-180, 180), rng:NextNumber(-180, 180)
	if free(x, z, 2) then
		local p = part(
			"Puddle",
			Vector3.new(rng:NextNumber(3, 6), 0.12, rng:NextNumber(2, 5)),
			CFrame.new(x, 0.06, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.fromRGB(90, 130, 170),
			Enum.Material.Glass
		)
		p.Transparency = 0.4
		p.CanCollide = false
	end
end
-- Perimeter wall: crenellations, buttresses, vines, main gate on the north wall.
for i = -24, 24 do
	local t = i * 8
	if i % 2 == 0 then
		part("Merlon", Vector3.new(4, 3, 4), CFrame.new(t, 29.5, -HALF), DARK, Enum.Material.Brick)
		part("Merlon", Vector3.new(4, 3, 4), CFrame.new(t, 29.5, HALF), DARK, Enum.Material.Brick)
		part("Merlon", Vector3.new(4, 3, 4), CFrame.new(-HALF, 29.5, t), DARK, Enum.Material.Brick)
		part("Merlon", Vector3.new(4, 3, 4), CFrame.new(HALF, 29.5, t), DARK, Enum.Material.Brick)
	end
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
for _ = 1, 40 do
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
	local v = part("Vine", size, cf, ({ LEAF, LEAF2 })[rng:NextInteger(1, 2)], Enum.Material.Grass)
	v.CanCollide = false
end
do -- main gate (north), closed: iron bars in a stone arch
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
		local pl = Instance.new("PointLight")
		pl.Color = LAMP
		pl.Range = 40
		pl.Brightness = 1.5
		pl.Parent = l
	end
	local gs = part(
		"GateSign",
		Vector3.new(16, 2.4, 0.5),
		CFrame.new(0, 29, -HALF + 3.2),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	boardText(gs, Enum.NormalId.Front, "ТЮРЬМА")
end
-- Mine yards: lantern posts on the rim corners, scaffolding, a crane and block piles by the entrance.
for _, h in ipairs({ { -72, 72, -192, -48 }, { -40, 40, 80, 160 } }) do
	for _, c in ipairs({ { h[1], h[3] }, { h[2], h[3] }, { h[1], h[4] }, { h[2], h[4] } }) do
		lampPost(c[1] + (if c[1] < 0 then -3 else 3), c[2] + (if c[2] < 0 then -3 else 3))
	end
	local sx, sz = h[2] + 6, h[3] + 10
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
		textured(
			part("ScaffoldDeck", Vector3.new(7, 0.4, 7), CFrame.new(sx, 6.2 + lv * 6, sz), WOOD),
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
	local craneX, craneZ = h[1] - 8, h[4] - 10
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
	textured(
		part("CraneLoad", Vector3.new(3, 3, 3), CFrame.new(craneX, 5.3, craneZ - 12.5), STONE),
		"px_stone"
	)
	local px, pz = h[1] + 12, h[4] + 8
	for i, variant in ipairs({ "px_dirt", "px_sand", "px_gravel", "px_cobblestone" }) do
		local bx = px + (i - 1) * 7
		for lv = 1, 3 do
			local n = 4 - lv
			for j = 1, n do
				textured(
					part(
						"Pile",
						Vector3.new(3, 3, 3),
						CFrame.new(bx + (j - (n + 1) / 2) * 3, lv * 3 - 1.5, pz + (lv - 1) * 0.3),
						STONE
					),
					variant
				)
			end
		end
	end
	part(
		"SignPost",
		Vector3.new(0.6, 7, 0.6),
		CFrame.new(h[1] - 4, 3.5, h[4] + 4),
		DARK_WOOD,
		Enum.Material.Wood
	).CanCollide =
		false
	local arrow = part(
		"SignArrow",
		Vector3.new(6, 1.4, 0.4),
		CFrame.new(h[1] - 1.5, 6.5, h[4] + 4),
		DARK_WOOD,
		Enum.Material.WoodPlanks
	)
	boardText(
		arrow,
		Enum.NormalId.Back,
		if h[4] < 0 then "ШАХТА →" else "МАЛАЯ ШАХТА →"
	)
end
-- Grass tufts, flowers, mushrooms, stumps and logs scattered on the lawns.
local tufts, flowers, shrooms, logs = 0, 0, 0, 0
for _ = 1, 3000 do
	if tufts >= 260 and flowers >= 120 and shrooms >= 30 and logs >= 14 then
		break
	end
	local x = rng:NextNumber(-HALF + 10, HALF - 10)
	local z = rng:NextNumber(-HALF + 10, HALF - 10)
	if free(x, z, 1.5) then
		local roll = rng:NextNumber()
		if tufts < 260 and roll < 0.55 then
			for i = 1, 3 do
				local t = part(
					"Grass",
					Vector3.new(1.4, rng:NextNumber(1, 1.8), 0.15),
					CFrame.new(x, 0.6, z)
						* CFrame.Angles(0, i * math.pi / 3 + rng:NextNumber(0, 0.5), 0),
					({ LEAF, LEAF2, Color3.fromRGB(120, 170, 70) })[rng:NextInteger(1, 3)],
					Enum.Material.Grass
				)
				t.CanCollide = false
			end
			tufts += 1
		elseif flowers < 120 and roll < 0.85 then
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
		elseif shrooms < 30 and roll < 0.95 then
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
		elseif logs < 14 and free(x, z, 5) then
			if rng:NextNumber() < 0.5 then
				local l = part(
					"Log",
					Vector3.new(7, 1.8, 1.8),
					CFrame.new(x, 0.9, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
					WOOD
				)
				l.Shape = Enum.PartType.Cylinder
				textured(l, "px_oak_log")
			else
				local s = part(
					"Stump",
					Vector3.new(1.6, 2.4, 2.4),
					CFrame.new(x, 0.8, z) * CFrame.Angles(0, 0, math.pi / 2),
					WOOD
				)
				s.Shape = Enum.PartType.Cylinder
				textured(s, "px_oak_log")
			end
			logs += 1
		end
	end
end
-- Birds perched on the wall (static silhouettes).
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

-- Scattered nature: trees, bushes, rocks in the free grass.
local trees, bushes, rocks = 0, 0, 0
for _ = 1, 2500 do
	if trees >= 70 and bushes >= 60 and rocks >= 25 then
		break
	end
	local x = rng:NextNumber(-HALF + 12, HALF - 12)
	local z = rng:NextNumber(-HALF + 12, HALF - 12)
	if free(x, z, 6) and farFromOthers(x, z, 9) then
		table.insert(placed, Vector2.new(x, z))
		local roll = rng:NextNumber()
		if trees < 70 and roll < 0.45 then
			tree(x, z, rng:NextNumber(0.9, 1.5))
			trees += 1
		elseif bushes < 60 and roll < 0.85 then
			bush(x, z)
			bushes += 1
		elseif rocks < 25 then
			rock(x, z)
			rocks += 1
		end
	end
end

-- Lighting mood: afternoon sun, light atmosphere so the far wall fades.
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

print(
	string.format(
		"[decorate-prison] trees %d, bushes %d, rocks %d, parts %d",
		trees,
		bushes,
		rocks,
		#decor:GetDescendants()
	)
)
