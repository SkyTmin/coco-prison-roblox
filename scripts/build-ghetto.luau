--!nocheck
-- Builds the Гетто (ghetto: «Нужна банда и улучшение Гетто», PvP, own gang members may hit each other
-- [вики LOCATIONS-MENU]; docs/research/remaining-features-design.md «Этап 1в. Гетто») — Workspace.Ghetto at X 11400,
-- height Y 15000. A walled city block at dusk: a main street (north–south) crossed by a second one, sixteen lots
-- between them with 8-stud back alleys. Most lots hold brick blocks of 3–5 storeys (lit / dark / boarded windows,
-- fire escapes, shop shutters with signs, roof parapets, water towers, chimneys); two lots are wastelands (zombies,
-- wrecked cars, fences), one is a fenced basketball court, one the walled yard of the Чёрный рынок (tag BlackMarket).
-- The Торговец stands at a kiosk by the arrival (tag GhettoTrader). Rats in the alleys and zombies on the
-- wastelands (MobSpawn, LocationId ghetto), 6 TreasurePoint parts for the treasure chest event (GhettoService),
-- fire barrels, dumpsters, laundry lines, lamps, graffiti, puddles; dusk light (IndoorLighting); invisible edge walls.
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Ghetto.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local old = workspace:FindFirstChild("Ghetto")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Ghetto"
root:SetAttribute("LocationId", "ghetto")
root.Parent = workspace

local OX, OZ = 11400, 0
local BY = 15000 -- the location's own height [CLAUDE.md: new locations float at their own height]
local HALF = 120 -- the inner half size of the walled block
local FLOOR = 9 -- one storey
local rng = Random.new(20261029)

local DARK = Color3.fromRGB(38, 36, 40)
local IRON = Color3.fromRGB(70, 66, 64)
local RUST = Color3.fromRGB(120, 66, 40)
local ASPHALT = Color3.fromRGB(78, 78, 84)
local WARM = Color3.fromRGB(255, 190, 110)
local GRAFFITI = {
	Color3.fromRGB(255, 70, 90),
	Color3.fromRGB(80, 220, 255),
	Color3.fromRGB(255, 220, 60),
	Color3.fromRGB(140, 255, 90),
	Color3.fromRGB(230, 120, 255),
	Color3.fromRGB(255, 150, 40),
}
local TAGS =
	{ "GST", "ГЕТТО", "КРЫСЫ", "OGG", "WAR", "DOP", "#13", "ZONA", "BOSS", "777" }
local SHOPS = {
	"ЛОМБАРД",
	"24/7",
	"БАР",
	"ШАУРМА",
	"АПТЕКА",
	"РЕМОНТ",
	"ПИВО",
	"СКУПКА",
	"ЗАКРЫТО",
	"ХОЗТОВАРЫ",
}

-- ---------------------------------------------------------------- helpers
local count = 0
local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or DARK
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	count += 1
	if count % 500 == 0 then
		task.wait()
	end
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
	return CFrame.new(OX + x, y, OZ + z)
end
local function box(name, x0, y0, z0, x1, y1, z1, color, material, parent)
	local size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	return part(
		name,
		size,
		at((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2),
		color,
		material,
		parent
	)
end
local function tbox(name, x0, y0, z0, x1, y1, z1, variant, tint, parent)
	return textured(box(name, x0, y0, z0, x1, y1, z1, nil, nil, parent), variant, tint)
end
local function folder(name, parent)
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or root
	return f
end
local function light(p, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness
	l.Color = color or WARM
	l.Shadows = false
	l.Parent = p
	return l
end
local function fire(p, size)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20))
	e.LightEmission = 0.8
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, size),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new(0.2, 1)
	e.Rate = 30
	e.Lifetime = NumberRange.new(0.5, 1)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(15, 15)
	e.Parent = p
	local smoke = Instance.new("ParticleEmitter")
	smoke.Color = ColorSequence.new(Color3.fromRGB(60, 60, 60))
	smoke.Size = NumberSequence.new(size, size * 3)
	smoke.Transparency = NumberSequence.new(0.6, 1)
	smoke.Rate = 4
	smoke.Lifetime = NumberRange.new(2, 3)
	smoke.Speed = NumberRange.new(3, 5)
	smoke.Parent = p
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 24)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
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
local function boardText(target, text, color, faces, font)
	for _, face in ipairs(faces) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 30
		gui.MaxDistance = 110
		gui.LightInfluence = 0.3
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(0.94, 0.84)
		label.Position = UDim2.fromScale(0.03, 0.08)
		label.BackgroundTransparency = 1
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.5
		label.TextScaled = true
		label.Font = font or Enum.Font.Code
		label.Text = text
		label.Parent = gui
	end
end
local function npc(spec)
	local desc = Instance.new("HumanoidDescription")
	local skin = spec.skin or Color3.fromRGB(215, 175, 145)
	desc.HeadColor, desc.LeftArmColor, desc.RightArmColor = skin, skin, skin
	desc.TorsoColor = spec.shirt or Color3.fromRGB(90, 90, 100)
	desc.LeftLegColor = spec.pants or Color3.fromRGB(50, 50, 60)
	desc.RightLegColor = desc.LeftLegColor
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = spec.name
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
	model:SetAttribute("Costume", spec.costume)
	model.Parent = spec.parent
	model:PivotTo(spec.cf)
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	local hrp = model:FindFirstChild("HumanoidRootPart")
	for _, tag in ipairs(spec.tags or {}) do
		CollectionService:AddTag(hrp, tag)
	end
	if spec.label then
		sign(hrp, spec.label, 4.5, spec.labelColor)
	end
	return model, hrp
end

-- a face of an axis-aligned block: axis "x" (normal ±X) or "z", sign ±1, plane = the wall coordinate, lo..hi along it
local FACE_ID = {
	x = { [1] = Enum.NormalId.Right, [-1] = Enum.NormalId.Left },
	z = { [1] = Enum.NormalId.Back, [-1] = Enum.NormalId.Front },
}
-- a box on a face: u = the centre along the face, y = the centre height, w × h on the face, d deep, `out` = how far
-- its centre stands out of the wall plane
local function facePart(name, f, u, y, w, h, d, out, color, material, parent)
	if f.axis == "x" then
		return part(
			name,
			Vector3.new(d, h, w),
			at(f.plane + f.sign * out, y, u),
			color,
			material,
			parent
		)
	end
	return part(
		name,
		Vector3.new(w, h, d),
		at(u, y, f.plane + f.sign * out),
		color,
		material,
		parent
	)
end
local function faceText(target, f, text, color, font)
	boardText(target, text, color, { FACE_ID[f.axis][f.sign] }, font)
end

-- ---------------------------------------------------------------- props
local function barrelFire(x, z, parent)
	local b = part(
		"FireBarrel",
		Vector3.new(3.2, 2.6, 2.6),
		at(x, 1.7, z) * CFrame.Angles(0, 0, math.pi / 2),
		RUST,
		Enum.Material.CorrodedMetal,
		parent
	)
	b.Shape = Enum.PartType.Cylinder
	local flame = decor(
		part(
			"Flame",
			Vector3.new(2, 0.4, 2),
			at(x, 3.4, z),
			Color3.fromRGB(255, 120, 40),
			Enum.Material.Neon,
			parent
		)
	)
	light(flame, 26, 1.8, Color3.fromRGB(255, 150, 70))
	fire(flame, 1.4)
end
local function dumpster(x, z, yaw, parent)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
	part(
		"Dumpster",
		Vector3.new(7, 4, 4),
		cf * CFrame.new(0, 2.1, 0),
		Color3.fromRGB(40, 90, 50),
		Enum.Material.DiamondPlate,
		parent
	)
	part(
		"DumpsterLid",
		Vector3.new(7.2, 0.3, 4.2),
		cf * CFrame.new(0, 4.3, -0.6) * CFrame.Angles(-0.35, 0, 0),
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Metal,
		parent
	)
	for k = 0, 2 do
		decor(
			part(
				"TrashBag",
				Vector3.new(1.8, 1.6, 1.8),
				cf * CFrame.new(-2.5 + k * 2.2, 0.9, 3.2) * CFrame.Angles(0, k, 0.1),
				Color3.fromRGB(25, 25, 28),
				Enum.Material.Plastic,
				parent
			)
		)
	end
end
local function crate(x, y, z, s, parent)
	textured(
		part(
			"Crate",
			Vector3.new(s, s, s),
			at(x, y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0),
			nil,
			nil,
			parent
		),
		"px_planks",
		Color3.fromRGB(200, 185, 165)
	)
end
local function tires(x, z, parent)
	for k = 0, rng:NextInteger(1, 3) do
		local t = part(
			"Tire",
			Vector3.new(1, 3, 3),
			at(x, 0.6 + k * 1, z) * CFrame.Angles(0, 0, math.pi / 2),
			Color3.fromRGB(22, 22, 24),
			Enum.Material.Rubber,
			parent
		)
		t.Shape = Enum.PartType.Cylinder
		t.Size = Vector3.new(1, 3, 3)
	end
end
local function wreck(x, z, yaw, parent)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw, rng:NextNumber(-0.05, 0.05))
	local paint = ({
		RUST,
		Color3.fromRGB(70, 80, 100),
		Color3.fromRGB(110, 40, 40),
		Color3.fromRGB(90, 90, 70),
	})[rng:NextInteger(1, 4)]
	part(
		"CarBody",
		Vector3.new(6, 2.4, 12),
		cf * CFrame.new(0, 1.9, 0),
		paint,
		Enum.Material.CorrodedMetal,
		parent
	)
	part(
		"CarCabin",
		Vector3.new(5.6, 2.2, 6),
		cf * CFrame.new(0, 4.2, 0.6),
		paint,
		Enum.Material.CorrodedMetal,
		parent
	)
	for _, w in ipairs({
		{ 0, 4.2, -2.45, 5, 1.8, 0.2 },
		{ 0, 4.2, 3.65, 5, 1.8, 0.2 },
		{ 2.85, 4.2, 0.6, 0.2, 1.8, 5 },
		{ -2.85, 4.2, 0.6, 0.2, 1.8, 5 },
	}) do
		decor(
			part(
				"BrokenGlass",
				Vector3.new(w[4], w[5], w[6]),
				cf * CFrame.new(w[1], w[2], w[3]),
				Color3.fromRGB(15, 15, 18),
				Enum.Material.Glass,
				parent
			)
		)
	end
	for _, p in ipairs({ { -3, -4 }, { 3, -4 }, { -3, 4 }, { 3, 4 } }) do
		if rng:NextNumber() < 0.75 then
			local wheel = part(
				"Wheel",
				Vector3.new(1, 2.4, 2.4),
				cf * CFrame.new(p[1], 1.1, p[2]) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(22, 22, 24),
				Enum.Material.Rubber,
				parent
			)
			wheel.Shape = Enum.PartType.Cylinder
		else
			part(
				"Brick",
				Vector3.new(1.4, 1, 2),
				cf * CFrame.new(p[1], 0.5, p[2]),
				Color3.fromRGB(150, 70, 50),
				Enum.Material.Brick,
				parent
			)
		end
	end
	decor(
		part(
			"Headlight",
			Vector3.new(1, 0.6, 0.2),
			cf * CFrame.new(-2, 2.4, -6.05),
			Color3.fromRGB(200, 200, 170),
			Enum.Material.Glass,
			parent
		)
	)
end
local function lamp(x, z, broken, parent)
	part("LampPole", Vector3.new(0.6, 16, 0.6), at(x, 8, z), DARK, Enum.Material.Metal, parent)
	part(
		"LampArm",
		Vector3.new(3.4, 0.4, 0.4),
		at(x + (if x > 0 then -1.5 else 1.5), 16, z),
		DARK,
		Enum.Material.Metal,
		parent
	)
	local head = decor(
		part(
			"LampHead",
			Vector3.new(1.8, 0.7, 1.2),
			at(x + (if x > 0 then -3 else 3), 15.7, z),
			if broken then Color3.fromRGB(60, 60, 55) else Color3.fromRGB(255, 200, 120),
			if broken then Enum.Material.Glass else Enum.Material.Neon,
			parent
		)
	)
	if not broken then
		light(head, 36, 1.6)
	end
end
local function fence(x0, z0, x1, z1, height, parent)
	local length = math.max(math.abs(x1 - x0), math.abs(z1 - z0))
	local alongX = math.abs(x1 - x0) > math.abs(z1 - z0)
	local mesh = part(
		"ChainFence",
		if alongX then Vector3.new(length, height, 0.2) else Vector3.new(0.2, height, length),
		at((x0 + x1) / 2, height / 2, (z0 + z1) / 2),
		Color3.fromRGB(150, 150, 150),
		Enum.Material.DiamondPlate,
		parent
	)
	mesh.Transparency = 0.55
	for k = 0, length, 6 do
		local px = if alongX then math.min(x0, x1) + k else x0
		local pz = if alongX then z0 else math.min(z0, z1) + k
		part(
			"FencePost",
			Vector3.new(0.4, height + 0.6, 0.4),
			at(px, (height + 0.6) / 2, pz),
			IRON,
			Enum.Material.Metal,
			parent
		)
	end
	part(
		"FenceRail",
		if alongX then Vector3.new(length, 0.3, 0.3) else Vector3.new(0.3, 0.3, length),
		at((x0 + x1) / 2, height, (z0 + z1) / 2),
		IRON,
		Enum.Material.Metal,
		parent
	)
end
local function puddle(x, z, s, parent)
	local p = decor(
		part(
			"Puddle",
			Vector3.new(s, 0.05, s * rng:NextNumber(0.5, 0.9)),
			at(x, 0.13, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			Color3.fromRGB(40, 50, 60),
			Enum.Material.Glass,
			parent
		)
	)
	p.Transparency = 0.25
	p.Reflectance = 0.2
end
-- a laundry line across an alley: from (x0, z0) to (x1, z1) at height y, clothes hanging off it
local function laundry(x0, z0, x1, z1, y, parent)
	local a, b = Vector3.new(OX + x0, y, OZ + z0), Vector3.new(OX + x1, y, OZ + z1)
	local length = (b - a).Magnitude
	decor(
		part(
			"Line",
			Vector3.new(0.1, 0.1, length),
			CFrame.lookAt((a + b) / 2, b),
			Color3.fromRGB(200, 200, 200),
			Enum.Material.SmoothPlastic,
			parent
		)
	)
	for k = 1, math.floor(length / 2.5) - 1 do
		if rng:NextNumber() < 0.7 then
			local pos = a:Lerp(b, k * 2.5 / length)
			local cloth = decor(
				part(
					"Cloth",
					Vector3.new(1.8, rng:NextNumber(1.6, 3), 0.1),
					CFrame.lookAt(pos, b)
						* CFrame.Angles(0, math.pi / 2, 0)
						* CFrame.new(0, -1.2, 0),
					GRAFFITI[rng:NextInteger(1, #GRAFFITI)]:Lerp(Color3.new(1, 1, 1), 0.45),
					Enum.Material.Fabric,
					parent
				)
			)
			cloth.Name = "Cloth"
		end
	end
end
local function graffiti(f, u, y, parent)
	local tag =
		facePart("Graffiti", f, u, y, rng:NextNumber(6, 10), 3.4, 0.1, 0.07, nil, nil, parent)
	tag.Transparency = 1
	decor(tag)
	faceText(
		tag,
		f,
		TAGS[rng:NextInteger(1, #TAGS)],
		GRAFFITI[rng:NextInteger(1, #GRAFFITI)],
		Enum.Font.Cartoon
	)
end

-- ---------------------------------------------------------------- a brick block of flats
local BRICKS = {
	{ "px_red_brick", Color3.new(1, 1, 1) },
	{ "px_red_brick", Color3.fromRGB(205, 180, 170) },
	{ "px_terracotta", Color3.new(1, 1, 1) },
	{ "px_stone_bricks", Color3.fromRGB(190, 185, 180) },
	{ "px_blackstone_bricks", Color3.new(1, 1, 1) },
	{ "px_red_brick", Color3.fromRGB(160, 150, 150) },
}
local function building(x0, z0, x1, z1, streetFaces, parent)
	local f = folder("Block", parent)
	local floors = rng:NextInteger(3, 5)
	local h = floors * FLOOR + 1
	local look = BRICKS[rng:NextInteger(1, #BRICKS)]
	tbox("Walls", x0, 0, z0, x1, h, z1, look[1], look[2], f)
	-- storey bands, cornice, a parapet ring
	for k = 1, floors - 1 do
		tbox(
			"Band",
			x0 - 0.3,
			k * FLOOR - 0.3,
			z0 - 0.3,
			x1 + 0.3,
			k * FLOOR + 0.4,
			z1 + 0.3,
			"px_smooth_stone",
			Color3.fromRGB(170, 165, 160),
			f
		)
	end
	tbox(
		"Cornice",
		x0 - 0.6,
		h,
		z0 - 0.6,
		x1 + 0.6,
		h + 0.8,
		z1 + 0.6,
		"px_smooth_stone",
		Color3.fromRGB(150, 145, 140),
		f
	)
	for _, r in ipairs({
		{ x0, z0, x1, z0 + 1 },
		{ x0, z1 - 1, x1, z1 },
		{ x0, z0, x0 + 1, z1 },
		{ x1 - 1, z0, x1, z1 },
	}) do
		tbox("Parapet", r[1], h + 0.8, r[2], r[3], h + 2.6, r[4], look[1], look[2], f)
	end
	-- roof clutter: a water tower or a chimney, AC boxes, a satellite dish
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	if rng:NextNumber() < 0.5 then
		for _, l in ipairs({ { -2, -2 }, { 2, -2 }, { -2, 2 }, { 2, 2 } }) do
			part(
				"TowerLeg",
				Vector3.new(0.5, 5, 0.5),
				at(cx + l[1], h + 3.3, cz + l[2]),
				DARK,
				Enum.Material.Metal,
				f
			)
		end
		local tank = part(
			"WaterTower",
			Vector3.new(6, 6, 6),
			at(cx, h + 8.8, cz) * CFrame.Angles(0, 0, math.pi / 2),
			nil,
			nil,
			f
		)
		tank.Shape = Enum.PartType.Cylinder
		textured(tank, "px_spruce_planks", Color3.fromRGB(170, 150, 130))
		local cap = part(
			"TowerCap",
			Vector3.new(1, 6.4, 6.4),
			at(cx, h + 12.3, cz) * CFrame.Angles(0, 0, math.pi / 2),
			DARK,
			Enum.Material.Metal,
			f
		)
		cap.Shape = Enum.PartType.Cylinder
	else
		tbox("Chimney", cx - 1.5, h, cz - 1.5, cx + 1.5, h + 7, cz + 1.5, "px_red_brick", nil, f)
	end
	for _ = 1, rng:NextInteger(1, 3) do
		local ax, az = rng:NextNumber(x0 + 3, x1 - 3), rng:NextNumber(z0 + 3, z1 - 3)
		part(
			"AC",
			Vector3.new(2.6, 1.6, 2.6),
			at(ax, h + 1.6, az),
			Color3.fromRGB(150, 150, 150),
			Enum.Material.DiamondPlate,
			f
		)
	end
	-- the faces
	local faces = {
		{ axis = "x", sign = 1, plane = x1, lo = z0, hi = z1, street = streetFaces.east },
		{ axis = "x", sign = -1, plane = x0, lo = z0, hi = z1, street = streetFaces.west },
		{ axis = "z", sign = 1, plane = z1, lo = x0, hi = x1, street = streetFaces.south },
		{ axis = "z", sign = -1, plane = z0, lo = x0, hi = x1, street = streetFaces.north },
	}
	local escapeDone = false
	for _, face in ipairs(faces) do
		local length = face.hi - face.lo
		local n = math.max(1, math.floor((length - 4) / 7))
		local step = length / n
		-- windows on the upper storeys: lit, dark or boarded up
		for k = 1, floors - 1 do
			for i = 0, n - 1 do
				local u = face.lo + step * (i + 0.5)
				local y = k * FLOOR + 4.4
				local roll = rng:NextNumber()
				if roll < 0.22 then
					local w = decor(
						facePart(
							"WindowLit",
							face,
							u,
							y,
							3,
							4,
							0.2,
							0.05,
							Color3.fromRGB(255, 205, 130),
							Enum.Material.Neon,
							f
						)
					)
					if rng:NextNumber() < 0.35 then
						light(w, 12, 0.5)
					end
				elseif roll < 0.82 then
					decor(
						facePart(
							"Window",
							face,
							u,
							y,
							3,
							4,
							0.2,
							0.05,
							Color3.fromRGB(20, 24, 32),
							Enum.Material.Glass,
							f
						)
					)
				else
					decor(
						textured(
							facePart("Boarded", face, u, y, 3.2, 4.2, 0.3, 0.1, nil, nil, f),
							"px_spruce_planks",
							Color3.fromRGB(170, 150, 120)
						)
					)
				end
				decor(
					textured(
						facePart("Sill", face, u, y - 2.3, 3.8, 0.4, 0.6, 0.3, nil, nil, f),
						"px_smooth_stone",
						Color3.fromRGB(170, 165, 160)
					)
				)
			end
		end
		if face.street then
			-- shops on the ground floor: rolled-down shutters (rusty) or a lit shop window, a sign board above
			for i = 0, n - 1, 2 do
				local u = face.lo + step * (i + 0.5) + (if n > 1 then step / 2 else 0)
				if rng:NextNumber() < 0.5 then
					facePart(
						"Shutter",
						face,
						u,
						3.3,
						math.min(10, step * 1.6),
						6.2,
						0.3,
						0.15,
						Color3.fromRGB(110, 110, 112),
						Enum.Material.CorrodedMetal,
						f
					)
				else
					local w = decor(
						facePart(
							"ShopWindow",
							face,
							u,
							3.3,
							math.min(9, step * 1.4),
							5,
							0.2,
							0.05,
							Color3.fromRGB(255, 220, 160),
							Enum.Material.Neon,
							f
						)
					)
					light(w, 14, 0.7)
				end
				local board = decor(
					facePart(
						"ShopSign",
						face,
						u,
						7.6,
						math.min(10, step * 1.6),
						1.8,
						0.4,
						0.3,
						Color3.fromRGB(30, 30, 34),
						Enum.Material.SmoothPlastic,
						f
					)
				)
				faceText(
					board,
					face,
					SHOPS[rng:NextInteger(1, #SHOPS)],
					GRAFFITI[rng:NextInteger(1, #GRAFFITI)]
				)
			end
		else
			-- a back door with a bulb, a dark small window
			local u = face.lo + length / 2
			decor(
				textured(
					facePart("BackDoor", face, u, 3.6, 4, 7, 0.3, 0.12, nil, nil, f),
					"px_dark_oak_planks"
				)
			)
			tbox(
				"Step",
				if face.axis == "x"
					then face.plane - (if face.sign < 0 then 1.5 else 0)
					else u - 2.5,
				0,
				if face.axis == "z"
					then face.plane - (if face.sign < 0 then 1.5 else 0)
					else u - 2.5,
				if face.axis == "x"
					then face.plane + (if face.sign > 0 then 1.5 else 0)
					else u + 2.5,
				0.6,
				if face.axis == "z"
					then face.plane + (if face.sign > 0 then 1.5 else 0)
					else u + 2.5,
				"px_smooth_stone",
				nil,
				f
			)
			local bulb = decor(
				facePart(
					"Bulb",
					face,
					u,
					8,
					0.6,
					0.6,
					0.6,
					0.4,
					Color3.fromRGB(255, 230, 170),
					Enum.Material.Neon,
					f
				)
			)
			if rng:NextNumber() < 0.6 then
				light(bulb, 14, 0.8)
			end
			-- the fire escape on the first back face
			if not escapeDone and floors >= 3 then
				escapeDone = true
				local eu = face.lo + length * 0.25
				for k = 1, floors - 1 do
					local y = k * FLOOR
					decor(
						facePart(
							"EscapePlatform",
							face,
							eu,
							y,
							8,
							0.3,
							3,
							1.6,
							IRON,
							Enum.Material.DiamondPlate,
							f
						)
					)
					decor(
						facePart(
							"EscapeRail",
							face,
							eu,
							y + 2.6,
							8,
							0.2,
							0.2,
							3.1,
							IRON,
							Enum.Material.Metal,
							f
						)
					)
					for _, s in ipairs({ -3.9, 3.9 }) do
						decor(
							facePart(
								"EscapePost",
								face,
								eu + s,
								y + 1.3,
								0.2,
								2.6,
								0.2,
								3.1,
								IRON,
								Enum.Material.Metal,
								f
							)
						)
					end
					decor(
						facePart(
							"EscapeLadder",
							face,
							eu + 3,
							y - FLOOR / 2,
							0.3,
							FLOOR,
							0.3,
							2.6,
							IRON,
							Enum.Material.Metal,
							f
						)
					)
					decor(
						facePart(
							"EscapeLadder",
							face,
							eu + 4,
							y - FLOOR / 2,
							0.3,
							FLOOR,
							0.3,
							2.6,
							IRON,
							Enum.Material.Metal,
							f
						)
					)
				end
			end
		end
		-- graffiti low on the wall
		if rng:NextNumber() < 0.7 then
			graffiti(face, rng:NextNumber(face.lo + 5, face.hi - 5), 2.4, f)
		end
	end
	return f, h
end

-- ================================================================ ground, streets, sidewalks
local ground = folder("Ground")
tbox(
	"Base",
	-HALF - 6,
	-4,
	-HALF - 6,
	HALF + 6,
	0,
	HALF + 6,
	"px_cobblestone",
	Color3.fromRGB(140, 135, 135),
	ground
)
-- the roads (asphalt), with dashed markings
part(
	"MainRoad",
	Vector3.new(24, 0.3, 2 * HALF),
	at(0, -0.05, 0),
	ASPHALT,
	Enum.Material.Asphalt,
	ground
)
for _, s in ipairs({ -1, 1 }) do
	local cx = s * (12 + (HALF - 12) / 2)
	part(
		"CrossRoad",
		Vector3.new(HALF - 12, 0.3, 24),
		at(cx, -0.05, 0),
		ASPHALT,
		Enum.Material.Asphalt,
		ground
	)
end
for z = -HALF + 4, HALF - 4, 10 do
	if math.abs(z) > 14 then
		decor(
			part(
				"Marking",
				Vector3.new(0.6, 0.05, 4),
				at(0, 0.12, z),
				Color3.fromRGB(230, 200, 60),
				Enum.Material.SmoothPlastic,
				ground
			)
		)
		decor(
			part(
				"Marking",
				Vector3.new(4, 0.05, 0.6),
				at(z, 0.12, 0),
				Color3.fromRGB(230, 200, 60),
				Enum.Material.SmoothPlastic,
				ground
			)
		)
	end
end
-- zebra crossings round the crossroads
for _, s in ipairs({ -1, 1 }) do
	for k = -10, 10, 3 do
		decor(
			part(
				"Zebra",
				Vector3.new(1.6, 0.05, 4),
				at(k, 0.12, s * 16),
				Color3.fromRGB(220, 220, 220),
				Enum.Material.SmoothPlastic,
				ground
			)
		)
		decor(
			part(
				"Zebra",
				Vector3.new(4, 0.05, 1.6),
				at(s * 16, 0.12, k),
				Color3.fromRGB(220, 220, 220),
				Enum.Material.SmoothPlastic,
				ground
			)
		)
	end
end
-- sidewalks with curbs (raised 0.6)
local SIDE = Color3.fromRGB(175, 170, 165)
for _, s in ipairs({ -1, 1 }) do
	for _, r in ipairs({ { -HALF, -18 }, { 18, HALF } }) do
		tbox("Sidewalk", s * 12, 0.1, r[1], s * 18, 0.7, r[2], "px_smooth_stone", SIDE, ground)
		tbox("Sidewalk", r[1], 0.1, s * 12, r[2], 0.7, s * 18, "px_smooth_stone", SIDE, ground)
	end
	for _, t in ipairs({ -1, 1 }) do
		tbox(
			"SidewalkCorner",
			s * 12,
			0.1,
			t * 12,
			s * 18,
			0.7,
			t * 18,
			"px_smooth_stone",
			SIDE,
			ground
		)
	end
end

-- ================================================================ the lots
local LOTS = { { 18, 62 }, { 70, HALF } } -- inner / outer, mirrored to both signs
local lots = folder("Lots")
local special = {
	["1,-1,2,2"] = "wasteland", -- north-east corner
	["-1,-1,2,2"] = "wasteland", -- north-west corner
	["1,1,1,2"] = "court", -- south-east, by the arrival
	["-1,-1,1,1"] = "market", -- the yard next to the crossroads
}
local wastelands, court, marketLot = {}, nil, nil
for _, sx in ipairs({ -1, 1 }) do
	for _, sz in ipairs({ -1, 1 }) do
		for ix, lx in ipairs(LOTS) do
			for iz, lz in ipairs(LOTS) do
				local xa, xb = sx * lx[1], sx * lx[2]
				local za, zb = sz * lz[1], sz * lz[2]
				local x0, x1 = math.min(xa, xb), math.max(xa, xb)
				local z0, z1 = math.min(za, zb), math.max(za, zb)
				local kind = special[("%d,%d,%d,%d"):format(sx, sz, ix, iz)]
				local rect = { x0 = x0, z0 = z0, x1 = x1, z1 = z1 }
				if kind == "wasteland" then
					table.insert(wastelands, rect)
				elseif kind == "court" then
					court = rect
				elseif kind == "market" then
					marketLot = rect
				else
					-- the faces that look onto a street (the inner sides of the inner lots)
					building(x0, z0, x1, z1, {
						east = ix == 1 and sx < 0,
						west = ix == 1 and sx > 0,
						south = iz == 1 and sz < 0,
						north = iz == 1 and sz > 0,
					}, lots)
				end
			end
		end
	end
end

-- the wastelands: weeds, rubble, burnt cars, tyres, a fire barrel, broken fences (zombies live here)
local waste = folder("Wastelands")
for _, r in ipairs(wastelands) do
	tbox("Dirt", r.x0, 0, r.z0, r.x1, 0.2, r.z1, "px_dirt", Color3.fromRGB(150, 140, 125), waste)
	for _ = 1, 26 do
		local x, z = rng:NextNumber(r.x0 + 2, r.x1 - 2), rng:NextNumber(r.z0 + 2, r.z1 - 2)
		local roll = rng:NextNumber()
		if roll < 0.45 then
			decor(
				textured(
					part(
						"Weeds",
						Vector3.new(1.4, rng:NextNumber(0.8, 1.8), 1.4),
						at(x, 0.8, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
						nil,
						nil,
						waste
					),
					"px_hedge",
					Color3.fromRGB(110, 120, 70)
				)
			)
		elseif roll < 0.8 then
			textured(
				part(
					"Rubble",
					Vector3.new(
						rng:NextNumber(1, 3),
						rng:NextNumber(0.6, 1.6),
						rng:NextNumber(1, 3)
					),
					at(x, 0.5, z)
						* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 3), 0),
					nil,
					nil,
					waste
				),
				if rng:NextNumber() < 0.5 then "px_red_brick" else "px_cobblestone"
			)
		else
			puddle(x, z, rng:NextNumber(2, 4), waste)
		end
	end
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	wreck(cx - 12, cz + 8, rng:NextNumber(0, 3), waste)
	wreck(cx + 10, cz - 10, rng:NextNumber(0, 3), waste)
	tires(cx + 14, cz + 12, waste)
	barrelFire(cx - 4, cz - 4, waste)
	-- the fence on the street sides, with a gap torn in it
	local inner = if r.x0 > 0 then r.x0 else r.x1
	fence(inner, r.z0, inner, r.z0 + 18, 7, waste)
	fence(inner, r.z0 + 28, inner, r.z1, 7, waste)
	local innerZ = if r.z0 > 0 then r.z0 else r.z1
	fence(r.x0, innerZ, r.x0 + 20, innerZ, 7, waste)
	fence(r.x0 + 30, innerZ, r.x1, innerZ, 7, waste)
end

-- the basketball court
local courtF = folder("Court")
do
	local r = court
	part(
		"CourtFloor",
		Vector3.new(r.x1 - r.x0 - 4, 0.2, r.z1 - r.z0 - 4),
		at((r.x0 + r.x1) / 2, 0.1, (r.z0 + r.z1) / 2),
		Color3.fromRGB(90, 70, 70),
		Enum.Material.Asphalt,
		courtF
	)
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	for _, l in ipairs({
		{ 0, -18, 36, 0.4 },
		{ 0, 18, 36, 0.4 },
		{ -18, 0, 0.4, 36 },
		{ 18, 0, 0.4, 36 },
		{ 0, 0, 36, 0.4 },
	}) do
		decor(
			part(
				"CourtLine",
				Vector3.new(l[3], 0.05, l[4]),
				at(cx + l[1], 0.23, cz + l[2]),
				Color3.fromRGB(230, 230, 230),
				Enum.Material.SmoothPlastic,
				courtF
			)
		)
	end
	for _, s in ipairs({ -1, 1 }) do
		part(
			"HoopPole",
			Vector3.new(0.6, 11, 0.6),
			at(cx, 5.5, cz + s * 21),
			DARK,
			Enum.Material.Metal,
			courtF
		)
		part(
			"Backboard",
			Vector3.new(6, 4, 0.3),
			at(cx, 11, cz + s * 20.6),
			Color3.fromRGB(230, 230, 230),
			Enum.Material.SmoothPlastic,
			courtF
		)
		local ring = decor(
			part(
				"Ring",
				Vector3.new(0.2, 2.2, 2.2),
				at(cx, 9.6, cz + s * 19.4) * CFrame.Angles(0, 0, math.pi / 2),
				Color3.fromRGB(230, 90, 30),
				Enum.Material.Metal,
				courtF
			)
		)
		ring.Shape = Enum.PartType.Cylinder
	end
	fence(r.x0 + 2, r.z0 + 2, r.x1 - 2, r.z0 + 2, 10, courtF)
	fence(r.x0 + 2, r.z1 - 2, r.x1 - 2, r.z1 - 2, 10, courtF)
	fence(r.x1 - 2, r.z0 + 2, r.x1 - 2, r.z1 - 2, 10, courtF)
	fence(r.x0 + 2, r.z0 + 2, r.x0 + 2, r.z0 + 16, 10, courtF) -- the gap on the street side is the way in
	fence(r.x0 + 2, r.z0 + 28, r.x0 + 2, r.z1 - 2, 10, courtF)
	local ball = part(
		"Ball",
		Vector3.new(1.4, 1.4, 1.4),
		at(cx + 4, 0.9, cz - 3),
		Color3.fromRGB(220, 100, 30),
		Enum.Material.SmoothPlastic,
		courtF
	)
	ball.Shape = Enum.PartType.Ball
	textured(
		part("Bleacher", Vector3.new(14, 1.4, 3), at(r.x1 - 6, 0.7, cz), nil, nil, courtF),
		"px_spruce_planks"
	).Orientation =
		Vector3.new(0, 90, 0)
	barrelFire(r.x1 - 7, cz + 12, courtF)
end

-- the yard of the Чёрный рынок: brick walls, tarp stalls, the dealer at the back (tag BlackMarket)
local market = folder("BlackMarket")
do
	local r = marketLot
	tbox(
		"YardFloor",
		r.x0,
		0,
		r.z0,
		r.x1,
		0.2,
		r.z1,
		"px_stone_bricks",
		Color3.fromRGB(150, 145, 140),
		market
	)
	-- walls on the alley sides, the street sides open behind a fence with a gate post and the sign
	tbox(
		"YardWall",
		r.x0,
		0,
		r.z0,
		r.x1,
		12,
		r.z0 + 1.5,
		"px_red_brick",
		Color3.fromRGB(170, 150, 145),
		market
	)
	tbox(
		"YardWall",
		r.x0,
		0,
		r.z0,
		r.x0 + 1.5,
		12,
		r.z1,
		"px_red_brick",
		Color3.fromRGB(170, 150, 145),
		market
	)
	fence(r.x1, r.z0 + 2, r.x1, r.z1 - 14, 8, market)
	fence(r.x0 + 2, r.z1, r.x1 - 14, r.z1, 8, market)
	local post =
		tbox("GatePost", r.x1 - 2, 0, r.z1 - 2, r.x1, 14, r.z1, "px_dark_oak_log", nil, market)
	local board = tbox(
		"MarketBoard",
		r.x1 - 12,
		11,
		r.z1 - 0.4,
		r.x1 - 2,
		14,
		r.z1 + 0.4,
		"px_dark_oak_planks",
		nil,
		market
	)
	boardText(
		board,
		"ЧЁРНЫЙ РЫНОК",
		Color3.fromRGB(190, 120, 255),
		{ Enum.NormalId.Back, Enum.NormalId.Front }
	)
	post.Name = "GatePost"
	-- stalls under tarps
	for i, s in ipairs({
		{ r.x0 + 10, r.z0 + 10 },
		{ r.x0 + 26, r.z0 + 10 },
		{ r.x0 + 10, r.z0 + 28 },
	}) do
		local x, z = s[1], s[2]
		for _, p in ipairs({ { -4, -3 }, { 4, -3 }, { -4, 3 }, { 4, 3 } }) do
			part(
				"StallPost",
				Vector3.new(0.4, 8, 0.4),
				at(x + p[1], 4, z + p[2]),
				DARK,
				Enum.Material.Metal,
				market
			)
		end
		local tarp = textured(
			part(
				"Tarp",
				Vector3.new(9.4, 0.3, 7.4),
				at(x, 8.1, z) * CFrame.Angles(0.12, 0, 0),
				nil,
				nil,
				market
			),
			"px_gray_wool",
			GRAFFITI[i]:Lerp(Color3.new(0.2, 0.2, 0.25), 0.6)
		)
		tarp.Name = "Tarp"
		textured(
			part("StallTable", Vector3.new(7, 0.5, 2.6), at(x, 3, z - 1.4), nil, nil, market),
			"px_spruce_planks"
		)
		for k = 0, 3 do
			decor(
				part(
					"Goods",
					Vector3.new(1, 0.8, 1),
					at(x - 2.5 + k * 1.6, 3.65, z - 1.4),
					GRAFFITI[(k + i) % #GRAFFITI + 1],
					Enum.Material.SmoothPlastic,
					market
				)
			)
		end
		crate(x + 3, 0, z + 2, 2.4, market)
	end
	local lantern = decor(
		part(
			"YardLantern",
			Vector3.new(1.2, 1.6, 1.2),
			at(r.x0 + 22, 10, r.z0 + 22),
			Color3.fromRGB(180, 255, 160),
			Enum.Material.Neon,
			market
		)
	)
	light(lantern, 34, 1.2, Color3.fromRGB(180, 255, 160))
	barrelFire(r.x0 + 30, r.z0 + 30, market)
	npc({
		name = "BlackMarketDealer",
		costume = "cultist",
		shirt = Color3.fromRGB(40, 40, 46),
		parent = market,
		cf = CFrame.lookAt(
			Vector3.new(OX + r.x0 + 26, 3.2, OZ + r.z0 + 7),
			Vector3.new(OX + r.x0 + 26, 3.2, OZ + r.z1)
		),
		tags = { "BlackMarket" },
		label = "Чёрный рынок",
		labelColor = Color3.fromRGB(190, 120, 255),
	})
end

-- ================================================================ the walls round the block, barricades at the street ends
local walls = folder("Walls")
for _, w in ipairs({
	{ -HALF - 4, -HALF - 4, HALF + 4, -HALF },
	{ -HALF - 4, HALF, HALF + 4, HALF + 4 },
	{ -HALF - 4, -HALF, -HALF, HALF },
	{ HALF, -HALF, HALF + 4, HALF },
}) do
	tbox(
		"OuterWall",
		w[1],
		0,
		w[2],
		w[3],
		46,
		w[4],
		"px_red_brick",
		Color3.fromRGB(150, 130, 125),
		walls
	)
end
for _, e in ipairs({
	{ 0, -HALF + 4, 0 },
	{ 0, HALF - 4, 0 },
	{ -HALF + 4, 0, math.pi / 2 },
	{ HALF - 4, 0, math.pi / 2 },
}) do
	local cf = at(e[1], 0, e[2]) * CFrame.Angles(0, e[3], 0)
	for k = -2, 2 do
		part(
			"Barrier",
			Vector3.new(4.6, 3, 2),
			cf * CFrame.new(k * 5, 1.5, 0),
			Color3.fromRGB(170, 170, 165),
			Enum.Material.Concrete,
			walls
		)
		decor(
			part(
				"BarrierStripe",
				Vector3.new(4.7, 0.6, 2.1),
				cf * CFrame.new(k * 5, 2.2, 0),
				if k % 2 == 0 then Color3.fromRGB(220, 60, 50) else Color3.fromRGB(235, 235, 235),
				Enum.Material.SmoothPlastic,
				walls
			)
		)
	end
	local cfX, cfZ = cf.Position.X - OX, cf.Position.Z - OZ
	tires(cfX + 8, cfZ + 2, walls)
end

-- ================================================================ street furniture
local street = folder("Street")
for z = -HALF + 14, HALF - 14, 28 do
	if math.abs(z) > 20 then
		lamp(15, z, rng:NextNumber() < 0.25, street)
		lamp(z, 15, rng:NextNumber() < 0.25, street)
	end
	if math.abs(z + 14) > 20 and z + 14 < HALF - 6 then
		lamp(-15, z + 14, rng:NextNumber() < 0.25, street)
		lamp(z + 14, -15, rng:NextNumber() < 0.25, street)
	end
end
-- a broken traffic light at the crossroads, a burnt car in the middle of it
do
	part("TrafficPole", Vector3.new(0.6, 14, 0.6), at(14, 7, 14), DARK, Enum.Material.Metal, street)
	part("TrafficArm", Vector3.new(0.4, 0.4, 8), at(14, 14, 10), DARK, Enum.Material.Metal, street)
	part(
		"TrafficBox",
		Vector3.new(1.4, 4, 1.4),
		at(14, 12, 6.5),
		Color3.fromRGB(40, 40, 30),
		Enum.Material.Metal,
		street
	)
	for i, c in ipairs({
		Color3.fromRGB(255, 60, 40),
		Color3.fromRGB(70, 60, 20),
		Color3.fromRGB(20, 60, 20),
	}) do
		local l = decor(
			part(
				"TrafficLamp",
				Vector3.new(1, 1, 0.2),
				at(14, 13.3 - i * 1.2, 5.75),
				c,
				if i == 1 then Enum.Material.Neon else Enum.Material.Glass,
				street
			)
		)
		if i == 1 then
			light(l, 10, 0.8, c)
		end
	end
	wreck(-4, 3, 0.7, street)
end
-- dumpsters, fire barrels and junk on the sidewalks and in the alleys
for _, d in ipairs({
	{ 16, -40, math.pi / 2 },
	{ -16, 44, math.pi / 2 },
	{ 40, -16, 0 },
	{ -90, 16, 0 },
	{ 66, 40, math.pi / 2 },
	{ -66, -90, math.pi / 2 },
	{ 30, -66, 0 },
	{ -40, 66, 0 },
}) do
	dumpster(d[1], d[2], d[3], street)
end
for _, b in ipairs({
	{ 15, -70 },
	{ -15, 30 },
	{ 66, -30 },
	{ -66, 80 },
	{ -30, -66 },
	{ 90, 66 },
	{ 60, -15 },
}) do
	barrelFire(b[1], b[2], street)
end
for _ = 1, 30 do
	local onX = rng:NextNumber() < 0.5
	local along = rng:NextNumber(-HALF + 8, HALF - 8)
	local x, z
	if rng:NextNumber() < 0.5 then -- an alley
		local a = (if rng:NextNumber() < 0.5 then -1 else 1) * 66
		x, z = if onX then a else along, if onX then along else a
	else -- a sidewalk
		local a = (if rng:NextNumber() < 0.5 then -1 else 1) * 15.5
		x, z = if onX then a else along, if onX then along else a
	end
	if math.abs(x) > 20 or math.abs(z) > 20 then
		local roll = rng:NextNumber()
		if roll < 0.35 then
			crate(
				x,
				if math.abs(x) < 19 or math.abs(z) < 19 then 0.7 else 0,
				z,
				rng:NextInteger(2, 3),
				street
			)
		elseif roll < 0.6 then
			decor(
				part(
					"TrashBag",
					Vector3.new(1.8, 1.6, 1.8),
					at(x, 1.2, z) * CFrame.Angles(0, rng:NextNumber(0, 3), 0.15),
					Color3.fromRGB(25, 25, 28),
					Enum.Material.Plastic,
					street
				)
			)
		elseif roll < 0.8 then
			puddle(x, z, rng:NextNumber(2, 5), street)
		else
			tires(x, z, street)
		end
	end
end
-- laundry lines across the alleys
for _, l in ipairs({
	{ 62, 30, 70, 34 },
	{ 62, 90, 70, 86 },
	{ -62, 40, -70, 44 },
	{ -62, -40, -70, -36 },
	{ 30, -62, 34, -70 },
	{ -30, 62, -34, 70 },
	{ 90, 62, 86, 70 },
	{ -86, -62, -90, -70 },
}) do
	laundry(l[1], l[2], l[3], l[4], rng:NextNumber(14, 22), street)
	laundry(l[1], l[2] + 4, l[3], l[4] + 4, rng:NextNumber(20, 26), street)
end

-- ================================================================ the arrival, the Торговец's kiosk
local arrival = folder("Arrival")
do
	local spawn = part(
		"LocationSpawn_ghetto",
		Vector3.new(4, 1, 4),
		CFrame.lookAt(Vector3.new(OX, 0.6, OZ + HALF - 14), Vector3.new(OX, 0.6, OZ)),
		nil,
		nil,
		arrival
	)
	textured(spawn, "px_gold_block")
	spawn:SetAttribute("LocationId", "ghetto")
	CollectionService:AddTag(spawn, "LocationSpawn")
	-- the kiosk on the west sidewalk next to the arrival
	local x, z = -15, HALF - 26
	tbox("KioskBase", x - 3, 0.7, z - 4, x + 2, 3.6, z + 4, "px_dark_oak_planks", nil, arrival)
	part(
		"KioskGlass",
		Vector3.new(0.2, 3.4, 7.4),
		at(x + 2.1, 5.3, z),
		Color3.fromRGB(255, 225, 160),
		Enum.Material.Neon,
		arrival
	).Transparency =
		0.4
	tbox("KioskBack", x - 3, 3.6, z - 4, x - 2.4, 8, z + 4, "px_dark_oak_planks", nil, arrival)
	tbox(
		"KioskRoof",
		x - 3.6,
		8,
		z - 4.6,
		x + 3.2,
		8.8,
		z + 4.6,
		"px_iron_block",
		Color3.fromRGB(140, 140, 150),
		arrival
	)
	local board = decor(
		part(
			"KioskSign",
			Vector3.new(0.4, 1.6, 8),
			at(x + 2.6, 9.8, z),
			Color3.fromRGB(30, 30, 36),
			Enum.Material.SmoothPlastic,
			arrival
		)
	)
	boardText(board, "ОБМЕН", Color3.fromRGB(255, 210, 80), { Enum.NormalId.Right })
	light(board, 16, 0.9)
	npc({
		name = "GhettoTrader",
		costume = "buyer",
		shirt = Color3.fromRGB(150, 110, 40),
		parent = arrival,
		cf = CFrame.lookAt(
			Vector3.new(OX + x - 0.8, 3.7, OZ + z),
			Vector3.new(OX + 10, 3.7, OZ + z)
		),
		tags = { "GhettoTrader" },
		label = "Торговец",
	})
end

-- ================================================================ mobs, the treasure points
local mobs = folder("MobSpawns")
local function mobSpawn(id, x, z, radius)
	local m = decor(part("MobSpawn_" .. id, Vector3.new(2, 1, 2), at(x, 0.8, z), nil, nil, mobs))
	m.Transparency = 1
	m:SetAttribute("MobId", id)
	m:SetAttribute("LocationId", "ghetto")
	m:SetAttribute("Wander", radius)
	CollectionService:AddTag(m, "MobSpawn")
end
for _, p in ipairs({
	{ 66, 0 },
	{ 66, -50 },
	{ -66, 10 },
	{ -66, -40 },
	{ 40, -66 },
	{ -40, -66 },
	{ 90, -66 },
	{ -66, 66 },
}) do
	mobSpawn("rat", p[1], p[2], 6)
end
for _, r in ipairs(wastelands) do
	local cx, cz = (r.x0 + r.x1) / 2, (r.z0 + r.z1) / 2
	for _, o in ipairs({ { -8, -10 }, { 10, 4 }, { -4, 14 } }) do
		mobSpawn("zombie", cx + o[1], cz + o[2], 10)
	end
end
local treasure = folder("TreasurePoints")
local function treasurePoint(x, z, y)
	local t = decor(
		part("TreasurePoint", Vector3.new(4, 0.2, 4), at(x, (y or 0) + 0.1, z), nil, nil, treasure)
	)
	t.Transparency = 1
	CollectionService:AddTag(t, "TreasurePoint")
end
for _, r in ipairs(wastelands) do
	treasurePoint((r.x0 + r.x1) / 2 + 2, (r.z0 + r.z1) / 2 + 2, 0.2)
end
treasurePoint((court.x0 + court.x1) / 2 + 8, (court.z0 + court.z1) / 2 + 6, 0.2)
treasurePoint(66, 30)
treasurePoint(-66, 40)
treasurePoint(0, -HALF + 20)

-- ================================================================ dusk light, the edge
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(
	part("DuskAir", Vector3.new(2 * HALF + 40, 300, 2 * HALF + 40), at(0, 100, 0), nil, nil, air)
)
volume.Transparency = 1
volume:SetAttribute("Ambient", Color3.fromRGB(125, 105, 115))
volume:SetAttribute("Exposure", -0.15)
volume:SetAttribute("Haze", 0.22)
volume:SetAttribute("ClockTime", 18.4) -- dusk: the sun low, long shadows, the lamps already on
volume:SetAttribute("Brightness", 1.4)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(160, 100, 85))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(90, 55, 65))
CollectionService:AddTag(volume, "IndoorLighting")
for _, w in ipairs({
	{ 0, -HALF - 8, 2 * HALF + 30, 4 },
	{ 0, HALF + 8, 2 * HALF + 30, 4 },
	{ -HALF - 8, 0, 4, 2 * HALF + 30 },
	{ HALF + 8, 0, 4, 2 * HALF + 30 },
}) do
	local p = part("EdgeWall", Vector3.new(w[3], 400, w[4]), at(w[1], 150, w[2]), nil, nil, root)
	p.Transparency = 1
	p.CanQuery = false
	p.CastShadow = false
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
print(("[build-ghetto] built: %d instances"):format(total))
return ("built %d instances"):format(total)
