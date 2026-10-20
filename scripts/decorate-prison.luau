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
