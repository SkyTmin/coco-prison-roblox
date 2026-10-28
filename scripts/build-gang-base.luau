--!nocheck
-- Builds the База банды (gang_base, «Нужна банда», PvP [вики LOCATIONS-MENU]; docs/research/remaining-features-design.md
-- §1.5) and the gang house template. [владелец 28.10: у каждой банды свой одинаковый дом, без лимита]:
--   * Workspace.GangBase — the shared courtyard of a gang quarter, X 10400, height Y 13500: a walled square paved in
--     stone, the arrival at the south gate (LocationSpawn), a fountain with a brazier in the middle, the «Улица домов»
--     on the north side — four timber-framed house fronts whose doors (tag GangHouseDoor) take a member into HIS
--     gang's house (GangHouseService), the Шнырь by the cart with the «Гетто →» post (tag GangShnyr: the trip to the
--     Гетто), the Чёрный рынок tent (tag BlackMarket), lamp posts, benches, barrels, crates, planters, graffiti boards;
--     corner towers; invisible edge walls. PvP here.
--   * ServerStorage.GangHouseTemplate — ONE house interior (pivot = the middle of its floor, built at the origin):
--     a hall with the gang storage (4 double chests, HouseTags GangChest), the Библиотекарь's corner (bookshelves,
--     lectern, HouseTags GangLibrarian), the Кузнец's forge (furnace, anvil, HouseTags GangForge), a bed / bath /
--     toilet (Restore*), a table, banners and a carpet in the gang colour (attribute HouseBanner), the «[TAG] name»
--     board (TextLabel GangTagLabel), the exit door (GangHouseExit), the arrival (LocationSpawn, HouseSpawn) and the
--     house box HouseBounds. Tags live in the attribute HouseTags: GangHouseService adds them on each copy only.
-- NPC rigs are R15 models with a Costume attribute → NpcBodyService puts them in our block body at runtime.
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.GangBase and
-- ServerStorage.GangHouseTemplate.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

for _, old in ipairs({
	workspace:FindFirstChild("GangBase"),
	ServerStorage:FindFirstChild("GangHouseTemplate"),
}) do
	if old then
		old:Destroy()
	end
end
local root = Instance.new("Folder")
root.Name = "GangBase"
root:SetAttribute("LocationId", "gang_base")
root.Parent = workspace

local BX, BZ = 10400, 0
local BY = 13500 -- the location's own height [CLAUDE.md: new locations float at their own height]
local rng = Random.new(20261028)
local OX, OZ = BX, BZ -- the current origin: the courtyard is built at (BX, BZ), the house template at (0, 0)

local STONE = Color3.fromRGB(128, 128, 132)
local DARK = Color3.fromRGB(42, 40, 46)
local IRON = Color3.fromRGB(60, 60, 66)
local WARM = Color3.fromRGB(255, 196, 120)
local LEAF = Color3.fromRGB(80, 130, 60)
local BANNERS = {
	Color3.fromRGB(200, 50, 50),
	Color3.fromRGB(50, 110, 200),
	Color3.fromRGB(60, 160, 70),
	Color3.fromRGB(220, 180, 40),
	Color3.fromRGB(150, 60, 170),
	Color3.fromRGB(230, 120, 40),
}

-- ---------------------------------------------------------------- helpers
local count = 0
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
	count += 1
	if count % 500 == 0 then
		task.wait()
	end
	return p
end
local function wedge(name, size, cf, color, material, parent)
	local p = Instance.new("WedgePart")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color or STONE
	p.Material = material or Enum.Material.SmoothPlastic
	p.Parent = parent or root
	count += 1
	return p
end
-- our block textures (MaterialVariants px_*, scripts/build-textures.luau), optionally tinted
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
-- an axis-aligned box from two corners (current origin)
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
local function emitter(p, props)
	local e = Instance.new("ParticleEmitter")
	for k, v in pairs(props) do
		e[k] = v
	end
	e.Parent = p
	return e
end
local function fire(p, size)
	emitter(p, {
		Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 80, 20)),
		LightEmission = 0.8,
		Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, size),
			NumberSequenceKeypoint.new(1, 0),
		}),
		Transparency = NumberSequence.new(0.2, 1),
		Rate = 30,
		Lifetime = NumberRange.new(0.5, 0.9),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(15, 15),
	})
end
local function sign(target, text, offset, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 24)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = false
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
-- text on both faces of a board (labelName names the TextLabel, e.g. GangTagLabel for GangHouseService)
local function boardText(target, text, color, faces, labelName)
	for _, face in ipairs(faces or { Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.MaxDistance = 90
		gui.LightInfluence = 0.4
		gui.Parent = target
		local label = Instance.new("TextLabel")
		label.Name = labelName or "BoardText"
		label.Size = UDim2.fromScale(0.92, 0.8)
		label.Position = UDim2.fromScale(0.04, 0.1)
		label.BackgroundTransparency = 1
		label.TextColor3 = color or Color3.fromRGB(245, 235, 215)
		label.TextStrokeTransparency = 0.4
		label.TextScaled = true
		label.Font = Enum.Font.Code
		label.Text = text
		label.Parent = gui
	end
end
-- an R15 rig in a costume of Shared.Models.npcs (NpcBodyService rebuilds it in our body at runtime); `tags` go on the
-- HumanoidRootPart (or into its HouseTags attribute when `deferTags`)
local function npc(spec)
	local desc = Instance.new("HumanoidDescription")
	local skin = spec.skin or Color3.fromRGB(220, 180, 150)
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
	if spec.deferTags then
		hrp:SetAttribute("HouseTags", table.concat(spec.tags or {}, ","))
	else
		for _, tag in ipairs(spec.tags or {}) do
			CollectionService:AddTag(hrp, tag)
		end
	end
	if spec.label then
		sign(hrp, spec.label, 4.5, spec.labelColor)
	end
	return model, hrp
end

-- ---------------------------------------------------------------- props (shared by the courtyard and the house)
local function barrel(x, y, z, parent)
	local p = part(
		"Barrel",
		Vector3.new(3, 2.6, 2.6),
		at(x, y + 1.5, z) * CFrame.Angles(0, 0, math.pi / 2),
		nil,
		nil,
		parent
	)
	p.Shape = Enum.PartType.Cylinder
	textured(p, "px_spruce_planks")
	for _, dy in ipairs({ 0.4, 2.6 }) do
		local hoop = decor(
			part(
				"Hoop",
				Vector3.new(0.25, 2.75, 2.75),
				at(x, y + dy, z) * CFrame.Angles(0, 0, math.pi / 2),
				IRON,
				Enum.Material.Metal,
				parent
			)
		)
		hoop.Shape = Enum.PartType.Cylinder
	end
	return p
end
local function crate(x, y, z, s, parent)
	local p = textured(
		part(
			"Crate",
			Vector3.new(s, s, s),
			at(x, y + s / 2, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
			nil,
			nil,
			parent
		),
		"px_planks"
	)
	for _, e in ipairs({ -1, 1 }) do
		decor(
			textured(
				part(
					"CrateEdge",
					Vector3.new(s + 0.1, 0.3, 0.3),
					p.CFrame * CFrame.new(0, e * (s / 2 - 0.15), -s / 2),
					nil,
					nil,
					parent
				),
				"px_dark_oak_planks"
			)
		)
	end
	return p
end
local function lampPost(x, z, h, parent)
	tbox("LampBase", x - 1, 0, z - 1, x + 1, 1, z + 1, "px_stone_bricks", nil, parent)
	part(
		"LampPole",
		Vector3.new(0.6, h, 0.6),
		at(x, h / 2 + 1, z),
		DARK,
		Enum.Material.Metal,
		parent
	)
	local head = part(
		"LampHead",
		Vector3.new(1.6, 1.8, 1.6),
		at(x, h + 2, z),
		Color3.fromRGB(255, 215, 140),
		Enum.Material.Neon,
		parent
	)
	decor(head)
	part(
		"LampCap",
		Vector3.new(2.2, 0.4, 2.2),
		at(x, h + 3.1, z),
		DARK,
		Enum.Material.Metal,
		parent
	)
	light(head, 30, 1.4)
end
local function bench(x, z, yaw, parent)
	local cf = at(x, 0, z) * CFrame.Angles(0, yaw, 0)
	textured(
		part("BenchSeat", Vector3.new(6, 0.5, 1.8), cf * CFrame.new(0, 1.6, 0), nil, nil, parent),
		"px_spruce_planks"
	)
	textured(
		part("BenchBack", Vector3.new(6, 1.6, 0.4), cf * CFrame.new(0, 2.6, 0.75), nil, nil, parent),
		"px_spruce_planks"
	)
	for _, s in ipairs({ -2.5, 2.5 }) do
		part(
			"BenchLeg",
			Vector3.new(0.4, 1.4, 1.6),
			cf * CFrame.new(s, 0.7, 0),
			DARK,
			Enum.Material.Metal,
			parent
		)
	end
end
local function tree(x, z, parent)
	tbox("Planter", x - 3, 0, z - 3, x + 3, 2, z + 3, "px_stone_bricks", nil, parent)
	tbox("PlanterSoil", x - 2.5, 2, z - 2.5, x + 2.5, 2.2, z + 2.5, "px_dirt", nil, parent)
	tbox("Trunk", x - 0.8, 2, z - 0.8, x + 0.8, 10, z + 0.8, "px_oak_log", nil, parent)
	for i, s in ipairs({ 8, 6, 4 }) do
		local y = 8 + i * 2.4
		textured(
			part(
				"Leaves",
				Vector3.new(s, 2.6, s),
				at(x, y, z) * CFrame.Angles(0, i * 0.4, 0),
				nil,
				nil,
				parent
			),
			"px_hedge",
			LEAF
		)
	end
end
-- a double chest of the gang storage (the body is the clickable part)
local function chest(cf, parent, tags)
	local m = Instance.new("Model")
	m.Name = "GangChestModel"
	m.Parent = parent
	local body = textured(
		part("ChestBody", Vector3.new(6, 2.6, 3), cf * CFrame.new(0, 1.3, 0), nil, nil, m),
		"px_spruce_planks"
	)
	textured(
		part("ChestLid", Vector3.new(6.1, 0.9, 3.1), cf * CFrame.new(0, 3.05, 0), nil, nil, m),
		"px_dark_oak_planks"
	)
	for _, x in ipairs({ -1.6, 1.6 }) do
		part(
			"ChestLatch",
			Vector3.new(0.6, 0.9, 0.2),
			cf * CFrame.new(x, 2.4, -1.6),
			Color3.fromRGB(200, 200, 205),
			Enum.Material.Metal,
			m
		)
	end
	decor(
		part("ChestSeam", Vector3.new(0.12, 3.5, 3.12), cf * CFrame.new(0, 1.75, 0), DARK, nil, m)
	)
	body:SetAttribute("HouseTags", tags)
	return body
end

-- ================================================================ the courtyard (Workspace.GangBase)
local HALF = 96 -- the inner half size of the walled square
local yard = folder("Courtyard")

-- ground: a stone slab, paving in rings round the fountain, a darker cross of paths
tbox(
	"Ground",
	-HALF - 8,
	-6,
	-HALF - 8,
	HALF + 8,
	-0.4,
	HALF + 8,
	"px_stone",
	Color3.fromRGB(200, 200, 200),
	yard
)
for gx = -HALF, HALF - 8, 8 do
	for gz = -HALF, HALF - 8, 8 do
		local cx, cz = gx + 4, gz + 4
		local d = math.sqrt(cx * cx + cz * cz)
		local variant
		if math.abs(cx) < 8 or math.abs(cz) < 8 then
			variant = "px_smooth_stone"
		elseif d < 30 then
			variant = if (gx // 8 + gz // 8) % 2 == 0 then "px_stone_bricks" else "px_smooth_stone"
		else
			variant = if rng:NextNumber() < 0.15 then "px_mossy_cobblestone" else "px_cobblestone"
		end
		tbox("Paving", gx, -0.4, gz, gx + 8, 0, gz + 8, variant, nil, yard)
	end
end

-- the walls with battlements and the corner towers
local walls = folder("Walls")
local WALL_H = 16
for _, w in ipairs({
	{ -HALF - 4, -HALF - 4, HALF + 4, -HALF },
	{ -HALF - 4, HALF, HALF + 4, HALF + 4 },
	{ -HALF - 4, -HALF, -HALF, HALF },
	{ HALF, -HALF, HALF + 4, HALF },
}) do
	local x0, z0, x1, z1 = w[1], w[2], w[3], w[4]
	tbox("Wall", x0, 0, z0, x1, WALL_H, z1, "px_stone_bricks", nil, walls)
	-- mossy patches and the battlements
	local alongX = (x1 - x0) > (z1 - z0)
	local length = if alongX then x1 - x0 else z1 - z0
	for k = 0, length - 4, 4 do
		local bx = if alongX then x0 + k else x0
		local bz = if alongX then z0 else z0 + k
		if (k // 4) % 2 == 0 then
			tbox(
				"Merlon",
				bx,
				WALL_H,
				bz,
				bx + (if alongX then 4 else x1 - x0),
				WALL_H + 3,
				bz + (if alongX then z1 - z0 else 4),
				"px_stone_bricks",
				nil,
				walls
			)
		end
		if rng:NextNumber() < 0.25 then
			local y = rng:NextInteger(0, 3) * 4
			local mx = if alongX then bx else (if x0 < 0 then x1 + 0.05 else x0 - 0.05)
			local mz = if alongX then (if z0 < 0 then z1 + 0.05 else z0 - 0.05) else bz
			decor(
				tbox(
					"Moss",
					mx,
					y,
					mz,
					mx + (if alongX then 4 else 0.1),
					y + 4,
					mz + (if alongX then 0.1 else 4),
					"px_mossy_stone_bricks",
					nil,
					walls
				)
			)
		end
	end
end
for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
	local cx, cz = c[1] * (HALF + 2), c[2] * (HALF + 2)
	tbox("Tower", cx - 8, 0, cz - 8, cx + 8, 26, cz + 8, "px_stone_bricks", nil, walls)
	tbox("TowerRim", cx - 9, 26, cz - 9, cx + 9, 28, cz + 9, "px_smooth_stone", nil, walls)
	for k = 0, 3 do
		local yaw = k * math.pi / 2
		textured(
			wedge(
				"TowerRoof",
				Vector3.new(18, 10, 9),
				at(cx, 33, cz) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -4.5),
				nil,
				nil,
				walls
			),
			"px_dark_oak_planks"
		)
		local lantern = decor(
			part(
				"TowerLantern",
				Vector3.new(1.4, 1.8, 1.4),
				at(cx, 22, cz) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -8.8),
				Color3.fromRGB(255, 210, 130),
				Enum.Material.Neon,
				walls
			)
		)
		light(lantern, 26, 1.1)
	end
	local flag = part(
		"TowerFlag",
		Vector3.new(0.3, 5, 7),
		at(cx, 42, cz + 3.5),
		BANNERS[(c[1] + 2) + c[2] + 2] or BANNERS[1],
		Enum.Material.Fabric,
		walls
	)
	decor(flag)
	part("FlagPole", Vector3.new(0.4, 10, 0.4), at(cx, 40, cz), DARK, Enum.Material.Metal, walls)
end

-- ---------------------------------------------------------------- the north side: «Улица домов» with four doors
local street = folder("HouseFronts")
for i, x in ipairs({ -60, -20, 20, 60 }) do
	local z0, z1 = -HALF, -HALF + 10
	local h = 22 + (i % 2) * 4
	-- stone footing, timber-framed walls (spruce planks between dark oak logs), a gabled roof of tiles
	tbox("Footing", x - 17, 0, z0, x + 17, 4, z1, "px_cobblestone", nil, street)
	tbox(
		"FrontWall",
		x - 16,
		4,
		z1 - 1,
		x + 16,
		h,
		z1,
		"px_white_wool",
		Color3.fromRGB(235, 225, 205),
		street
	)
	for _, fx in ipairs({ -16, -6, 6, 16 }) do
		tbox(
			"Beam",
			x + fx - 0.6,
			4,
			z1 - 1.2,
			x + fx + 0.6,
			h,
			z1 + 0.2,
			"px_dark_oak_log",
			nil,
			street
		)
	end
	tbox(
		"BeamH",
		x - 16,
		h / 2 + 2,
		z1 - 1.2,
		x + 16,
		h / 2 + 3,
		z1 + 0.2,
		"px_dark_oak_log",
		nil,
		street
	)
	tbox("BackBlock", x - 17, 4, z0, x + 17, h, z1 - 1, "px_spruce_planks", nil, street)
	-- a WedgePart is high at its +Z end: the back slope as it is, the street slope turned round
	local mid = (z0 + z1) / 2
	for _, s in ipairs({ -1, 1 }) do
		textured(
			wedge(
				"Roof",
				Vector3.new(36, 8, 5.4),
				at(x, h + 4, mid + s * 2.7) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0),
				nil,
				nil,
				street
			),
			"px_roof_tiles"
		)
	end
	tbox(
		"Ridge",
		x - 18,
		h + 7.6,
		mid - 0.5,
		x + 18,
		h + 8.4,
		mid + 0.5,
		"px_dark_oak_planks",
		nil,
		street
	)
	-- the windows (lit), flower boxes
	for _, wx in ipairs({ -11, 11 }) do
		local win = decor(
			box(
				"Window",
				x + wx - 2,
				10,
				z1 + 0.05,
				x + wx + 2,
				15,
				z1 + 0.2,
				Color3.fromRGB(255, 220, 150),
				Enum.Material.Neon,
				street
			)
		)
		light(win, 14, 0.6)
		tbox(
			"Sill",
			x + wx - 2.6,
			9.4,
			z1,
			x + wx + 2.6,
			10,
			z1 + 1,
			"px_spruce_planks",
			nil,
			street
		)
		for k = 0, 3 do
			decor(
				part(
					"Flower",
					Vector3.new(0.8, 0.8, 0.8),
					at(x + wx - 1.5 + k, 10.4, z1 + 0.5),
					BANNERS[(k + i) % #BANNERS + 1],
					Enum.Material.SmoothPlastic,
					street
				)
			)
		end
		tbox(
			"Shutter",
			x + wx - 3.4,
			10,
			z1,
			x + wx - 2.2,
			15,
			z1 + 0.4,
			"px_dark_oak_planks",
			nil,
			street
		)
		tbox(
			"Shutter",
			x + wx + 2.2,
			10,
			z1,
			x + wx + 3.4,
			15,
			z1 + 0.4,
			"px_dark_oak_planks",
			nil,
			street
		)
	end
	-- the door: GangHouseDoor → «Домой» (each door leads every member to his own gang's house)
	tbox("DoorFrame", x - 4, 4, z1, x + 4, 14, z1 + 0.6, "px_dark_oak_log", nil, street)
	local door =
		tbox("Door", x - 3, 4, z1 + 0.2, x + 3, 13, z1 + 0.9, "px_dark_oak_planks", nil, street)
	CollectionService:AddTag(door, "GangHouseDoor")
	part(
		"DoorKnob",
		Vector3.new(0.5, 0.5, 0.4),
		at(x + 2, 8.5, z1 + 1),
		Color3.fromRGB(210, 170, 60),
		Enum.Material.Metal,
		street
	)
	tbox("Step", x - 5, 0, z1, x + 5, 4, z1 + 3, "px_smooth_stone", nil, street)
	tbox("Step2", x - 4, 0, z1 + 3, x + 4, 2, z1 + 5, "px_smooth_stone", nil, street)
	-- a banner over the door in a colour of its own, two lanterns
	local banner = decor(
		textured(
			box("Banner", x - 2, 15, z1 + 0.3, x + 2, 21, z1 + 0.5, nil, nil, street),
			"px_white_wool",
			BANNERS[i]
		)
	)
	banner.Name = "Banner"
	for _, s in ipairs({ -1, 1 }) do
		local lantern = decor(
			part(
				"DoorLantern",
				Vector3.new(1, 1.4, 1),
				at(x + s * 5.5, 11, z1 + 1.2),
				Color3.fromRGB(255, 210, 130),
				Enum.Material.Neon,
				street
			)
		)
		light(lantern, 16, 0.9)
		part(
			"LanternArm",
			Vector3.new(0.3, 0.3, 1.4),
			at(x + s * 5.5, 12, z1 + 0.6),
			DARK,
			Enum.Material.Metal,
			street
		)
	end
	barrel(x + 10, 0, z1 + 3, street)
	crate(x - 10, 0, z1 + 3, 3, street)
end
-- the board over the street
do
	local post =
		tbox("StreetBoardPost", -1, 0, -HALF + 18, 1, 9, -HALF + 20, "px_dark_oak_log", nil, street)
	local board = tbox(
		"StreetBoard",
		-7,
		9,
		-HALF + 18.6,
		7,
		13,
		-HALF + 19.4,
		"px_spruce_planks",
		nil,
		street
	)
	boardText(
		board,
		"Дома банд — у каждой свой",
		Color3.fromRGB(255, 215, 120)
	)
	post.Name = "StreetBoardPost"
end

-- ---------------------------------------------------------------- the south gate and the arrival
local gate = folder("Gate")
do
	local z = HALF
	tbox("GateTowerW", -18, 0, z - 6, -10, 24, z + 4, "px_stone_bricks", nil, gate)
	tbox("GateTowerE", 10, 0, z - 6, 18, 24, z + 4, "px_stone_bricks", nil, gate)
	tbox("GateArch", -10, 16, z - 4, 10, 24, z + 4, "px_stone_bricks", nil, gate)
	-- the portcullis (closed: the way out is the teleport)
	for gx = -9, 9, 2 do
		part(
			"Portcullis",
			Vector3.new(0.5, 16, 0.5),
			at(gx, 8, z - 1),
			IRON,
			Enum.Material.Metal,
			gate
		)
	end
	for gy = 2, 14, 3 do
		part(
			"PortcullisBar",
			Vector3.new(19, 0.5, 0.5),
			at(0, gy, z - 1),
			IRON,
			Enum.Material.Metal,
			gate
		)
	end
	for _, s in ipairs({ -1, 1 }) do
		local torch = decor(
			part(
				"GateTorch",
				Vector3.new(0.8, 1.2, 0.8),
				at(s * 9, 14, z - 7),
				Color3.fromRGB(255, 180, 80),
				Enum.Material.Neon,
				gate
			)
		)
		light(torch, 22, 1.2)
		fire(torch, 0.8)
	end
	-- the arrival platform facing the fountain
	tbox("ArrivalPlatform", -10, 0, z - 22, 10, 1, z - 8, "px_smooth_stone", nil, gate)
	for _, s in ipairs({ -1, 1 }) do
		tbox("ArrivalStep", -10, 0, z - 24, 10, 0.5, z - 22, "px_stone_bricks", nil, gate)
		tbox(
			"ArrivalPillar",
			s * 9 - 1,
			1,
			z - 21,
			s * 9 + 1,
			6,
			z - 19,
			"px_stone_bricks",
			nil,
			gate
		)
	end
	local spawn = part(
		"LocationSpawn_gang_base",
		Vector3.new(4, 1, 4),
		CFrame.lookAt(Vector3.new(OX, 1.5, OZ + z - 14), Vector3.new(OX, 1.5, OZ)),
		nil,
		nil,
		gate
	)
	textured(spawn, "px_gold_block")
	spawn:SetAttribute("LocationId", "gang_base")
	CollectionService:AddTag(spawn, "LocationSpawn")
	-- the teleporter stone next to the arrival (the locations menu)
	local tele = tbox("TeleporterStone", 13, 0, z - 18, 17, 5, z - 14, "px_obsidian", nil, gate)
	CollectionService:AddTag(tele, "Teleporter")
	tele:SetAttribute("LocationId", "gang_base")
	local glow = decor(
		part(
			"TeleporterGlow",
			Vector3.new(4.2, 0.3, 4.2),
			at(15, 5.2, z - 16),
			Color3.fromRGB(150, 110, 255),
			Enum.Material.Neon,
			gate
		)
	)
	light(glow, 14, 1, Color3.fromRGB(150, 110, 255))
end

-- ---------------------------------------------------------------- the fountain in the middle
local plaza = folder("Fountain")
do
	-- an octagon rim of stone bricks round water, a pillar with a brazier
	for k = 0, 7 do
		local a = k * math.pi / 4
		textured(
			part(
				"Rim",
				Vector3.new(9, 3, 2.4),
				at(math.cos(a) * 11, 1.5, math.sin(a) * 11) * CFrame.Angles(0, -a + math.pi / 2, 0),
				nil,
				nil,
				plaza
			),
			"px_stone_bricks"
		)
	end
	local water = tbox("Water", -10, 0.2, -10, 10, 2.2, 10, "px_water", nil, plaza)
	water.Transparency = 0.25
	water.CanCollide = false
	tbox("Pillar", -2, 0, -2, 2, 9, 2, "px_smooth_stone", nil, plaza)
	tbox("Bowl", -3.5, 9, -3.5, 3.5, 10.5, 3.5, "px_stone_bricks", nil, plaza)
	local coals = decor(
		part(
			"Coals",
			Vector3.new(5, 0.6, 5),
			at(0, 10.8, 0),
			Color3.fromRGB(255, 120, 40),
			Enum.Material.Neon,
			plaza
		)
	)
	light(coals, 40, 1.6, Color3.fromRGB(255, 160, 80))
	fire(coals, 2.2)
	for _, a in ipairs({ 0.4, 2, 3.6, 5.2 }) do
		lampPost(math.cos(a) * 22, math.sin(a) * 22, 10, plaza)
		bench(math.cos(a + 0.8) * 20, math.sin(a + 0.8) * 20, -(a + 0.8) + math.pi / 2, plaza)
	end
	for _, p in ipairs({ { -40, -30 }, { 40, -30 }, { -40, 40 }, { 40, 40 } }) do
		tree(p[1], p[2], plaza)
	end
end

-- ---------------------------------------------------------------- the west: the Шнырь by his cart → Гетто
local west = folder("Shnyr")
do
	local x, z = -HALF + 14, 6
	npc({
		name = "Shnyr",
		costume = "prisoner",
		shirt = Color3.fromRGB(230, 120, 40),
		parent = west,
		cf = CFrame.lookAt(Vector3.new(OX + x, 3, OZ + z), Vector3.new(OX, 3, OZ + z)),
		tags = { "GangShnyr" },
		label = "Шнырь",
	})
	-- a hand cart with sacks
	tbox("CartBed", x - 3, 2, z + 5, x + 3, 3, z + 11, "px_spruce_planks", nil, west)
	for _, s in ipairs({ -1, 1 }) do
		local wheel = part(
			"CartWheel",
			Vector3.new(0.6, 3.6, 3.6),
			at(x + s * 3.4, 1.8, z + 8) * CFrame.Angles(0, 0, math.pi / 2),
			nil,
			nil,
			west
		)
		wheel.Shape = Enum.PartType.Cylinder
		textured(wheel, "px_dark_oak_planks")
		part(
			"CartHandle",
			Vector3.new(0.4, 0.4, 6),
			at(x + s * 2, 3, z + 14),
			DARK,
			Enum.Material.Wood,
			west
		)
	end
	for k = 0, 2 do
		textured(
			part(
				"Sack",
				Vector3.new(2, 1.6, 2),
				at(x - 1.5 + k * 1.5, 3.8, z + 7 + (k % 2) * 2) * CFrame.Angles(0, k, 0),
				nil,
				nil,
				west
			),
			"px_brown_wool"
		)
	end
	-- the signpost with the arrow «Гетто →»
	tbox("SignPost", x + 6, 0, z - 6, x + 7, 9, z - 5, "px_dark_oak_log", nil, west)
	local arrow =
		tbox("SignArrow", x + 4, 6.5, z - 5.9, x + 12, 8.5, z - 5.1, "px_spruce_planks", nil, west)
	boardText(arrow, "Гетто →", Color3.fromRGB(255, 200, 90))
	barrel(x + 2, 0, z - 8, west)
	barrel(x - 2, 0, z - 9, west)
end

-- ---------------------------------------------------------------- the east: the Чёрный рынок tent
local market = folder("BlackMarket")
do
	local x, z = HALF - 16, 0
	tbox("TentFloor", x - 8, 0, z - 9, x + 8, 0.4, z + 9, "px_dark_oak_planks", nil, market)
	for _, p in ipairs({ { -7, -8 }, { 7, -8 }, { -7, 8 }, { 7, 8 } }) do
		tbox(
			"TentPost",
			x + p[1] - 0.5,
			0,
			z + p[2] - 0.5,
			x + p[1] + 0.5,
			11,
			z + p[2] + 0.5,
			"px_dark_oak_log",
			nil,
			market
		)
	end
	for _, s in ipairs({ -1, 1 }) do
		textured(
			wedge(
				"Canopy",
				Vector3.new(17, 4, 9.5),
				at(x, 13, z + s * 4.5) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0),
				nil,
				nil,
				market
			),
			"px_gray_wool",
			Color3.fromRGB(70, 60, 80)
		)
	end
	tbox(
		"CanopyBack",
		x + 7.6,
		4,
		z - 8,
		x + 8,
		11,
		z + 8,
		"px_gray_wool",
		Color3.fromRGB(60, 50, 70),
		market
	)
	tbox("Counter", x - 6, 0.4, z - 6, x - 4, 4, z + 6, "px_dark_oak_planks", nil, market)
	tbox("CounterTop", x - 6.4, 4, z - 6.4, x - 3.6, 4.4, z + 6.4, "px_spruce_planks", nil, market)
	-- the goods: chests, keys glinting, bottles
	for k = 0, 2 do
		decor(
			part(
				"Key",
				Vector3.new(0.3, 0.3, 1.2),
				at(x - 5, 4.6, z - 4 + k * 1.2) * CFrame.Angles(0, 0.4, 0),
				Color3.fromRGB(230, 190, 70),
				Enum.Material.Neon,
				market
			)
		)
		decor(
			part(
				"Bottle",
				Vector3.new(0.6, 1.2, 0.6),
				at(x - 5, 5, z + 2 + k * 1.2),
				Color3.fromRGB(90, 200, 120),
				Enum.Material.Glass,
				market
			)
		)
	end
	crate(x + 4, 0.4, z + 5, 3, market)
	crate(x + 4, 3.4, z + 5, 2.4, market)
	crate(x + 5, 0.4, z - 5, 3, market)
	local lantern = decor(
		part(
			"TentLantern",
			Vector3.new(1, 1.4, 1),
			at(x, 10, z),
			Color3.fromRGB(180, 255, 160),
			Enum.Material.Neon,
			market
		)
	)
	light(lantern, 22, 1, Color3.fromRGB(180, 255, 160))
	npc({
		name = "BlackMarketDealer",
		costume = "cultist",
		shirt = Color3.fromRGB(40, 40, 46),
		parent = market,
		cf = CFrame.lookAt(Vector3.new(OX + x - 1, 3.4, OZ + z), Vector3.new(OX, 3.4, OZ + z)),
		tags = { "BlackMarket" },
		label = "Чёрный рынок",
		labelColor = Color3.fromRGB(190, 120, 255),
	})
end

-- ---------------------------------------------------------------- props round the yard, graffiti boards, an edge
local props = folder("Props")
for _ = 1, 14 do
	local x, z = rng:NextNumber(-HALF + 8, HALF - 8), rng:NextNumber(-HALF + 22, HALF - 30)
	if math.abs(x) > 30 or math.abs(z) > 30 then
		if math.abs(x) < HALF - 26 then -- keep the Шнырь and the market clear
			if rng:NextNumber() < 0.5 then
				barrel(x, 0, z, props)
			else
				crate(x, 0, z, rng:NextInteger(2, 3), props)
			end
		end
	end
end
for i, p in ipairs({
	{ -HALF + 0.2, -40, "GST" },
	{ -HALF + 0.2, 50, "DOP" },
	{ HALF - 0.2, 50, "RAT" },
	{ HALF - 0.2, -50, "OGG" },
}) do
	local face = if p[1] < 0 then 0.6 else -0.6
	local board = decor(
		box(
			"Graffiti",
			p[1],
			4,
			p[2] - 5,
			p[1] + face,
			10,
			p[2] + 5,
			BANNERS[i],
			Enum.Material.SmoothPlastic,
			props
		)
	)
	board.Transparency = 0.2
	boardText(board, p[3], Color3.new(1, 1, 1), { Enum.NormalId.Left, Enum.NormalId.Right })
end
for _, w in ipairs({
	{ 0, -HALF - 12, 2 * HALF + 40, 4 },
	{ 0, HALF + 12, 2 * HALF + 40, 4 },
	{ -HALF - 12, 0, 4, 2 * HALF + 40 },
	{ HALF + 12, 0, 4, 2 * HALF + 40 },
}) do
	local p = part("EdgeWall", Vector3.new(w[3], 400, w[4]), at(w[1], 150, w[2]), nil, nil, root)
	p.Transparency = 1
	p.CanQuery = false
	p.CastShadow = false
end

-- lift the courtyard to its own height
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

-- ================================================================ the house template (ServerStorage.GangHouseTemplate)
OX, OZ = 0, 0
local house = Instance.new("Model")
house.Name = "GangHouseTemplate"
local IW, ID, IH = 24, 20, 16 -- half width, half depth, height of the hall
local function hp(name, x0, y0, z0, x1, y1, z1, variant, tint)
	return tbox(name, x0, y0, z0, x1, y1, z1, variant, tint, house)
end
-- the shell: floor, walls (stone below, planks above), log pillars, a beamed ceiling — closed all round
hp("Floor", -IW - 2, -2, -ID - 2, IW + 2, 0, ID + 2, "px_dark_oak_planks")
hp("Ceiling", -IW - 2, IH, -ID - 2, IW + 2, IH + 2, ID + 2, "px_dark_oak_planks")
for _, w in ipairs({
	{ -IW - 2, -ID - 2, IW + 2, -ID },
	{ -IW - 2, ID, IW + 2, ID + 2 },
	{ -IW - 2, -ID, -IW, ID },
	{ IW, -ID, IW + 2, ID },
}) do
	hp("WallLow", w[1], 0, w[2], w[3], 4, w[4], "px_stone_bricks")
	hp("WallHigh", w[1], 4, w[2], w[3], IH, w[4], "px_spruce_planks")
end
for _, x in ipairs({ -IW, -12, 0, 12, IW }) do
	for _, z in ipairs({ -ID, ID }) do
		hp("Pillar", x - 0.8, 0, z - 0.8, x + 0.8, IH, z + 0.8, "px_dark_oak_log")
	end
	hp("CeilingBeam", x - 0.6, IH - 1.2, -ID, x + 0.6, IH, ID, "px_dark_oak_log")
end
-- warm windows on the side walls (the light of the courtyard behind them)
for _, z in ipairs({ -10, 0, 10 }) do
	for _, s in ipairs({ -1, 1 }) do
		local x = s * (IW - 0.05)
		local win = decor(
			part(
				"Window",
				Vector3.new(0.1, 4, 5),
				at(x, 9, z),
				Color3.fromRGB(255, 225, 160),
				Enum.Material.Neon,
				house
			)
		)
		light(win, 12, 0.5)
		hp(
			"WindowFrame",
			x - 0.4 * s - 0.2,
			6.6,
			z - 3,
			x - 0.4 * s + 0.2,
			7,
			z + 3,
			"px_dark_oak_planks"
		)
	end
end
-- chandeliers
for _, x in ipairs({ -12, 12 }) do
	part(
		"ChandelierChain",
		Vector3.new(0.2, 3, 0.2),
		at(x, IH - 1.5, 0),
		DARK,
		Enum.Material.Metal,
		house
	)
	local ring = part(
		"Chandelier",
		Vector3.new(4, 0.4, 4),
		at(x, IH - 3.2, 0),
		DARK,
		Enum.Material.Metal,
		house
	)
	for k = 0, 3 do
		local a = k * math.pi / 2
		local candle = decor(
			part(
				"Candle",
				Vector3.new(0.4, 0.8, 0.4),
				at(x + math.cos(a) * 1.6, IH - 2.6, math.sin(a) * 1.6),
				Color3.fromRGB(255, 220, 150),
				Enum.Material.Neon,
				house
			)
		)
		fire(candle, 0.3)
	end
	light(ring, 30, 1.2)
end
-- the carpet and the banners in the gang colour (white wool tinted by GangHouseService)
local carpet = decor(hp("Carpet", -8, 0, -12, 8, 0.15, 12, "px_white_wool"))
carpet:SetAttribute("HouseBanner", true)
for _, x in ipairs({ -18, -6, 6, 18 }) do
	local banner = decor(hp("Banner", x - 2, 6, -ID + 0.1, x + 2, 13, -ID + 0.3, "px_white_wool"))
	banner:SetAttribute("HouseBanner", true)
	part(
		"BannerRod",
		Vector3.new(5, 0.3, 0.3),
		at(x, 13.2, -ID + 0.3),
		DARK,
		Enum.Material.Metal,
		house
	)
end
-- the «[TAG] name» board over the storage
do
	local board = hp("TagBoard", -9, 13, -ID + 0.05, 9, 15.4, -ID + 0.5, "px_spruce_planks")
	boardText(
		board,
		"[TAG] Банда",
		Color3.fromRGB(255, 215, 120),
		{ Enum.NormalId.Back },
		"GangTagLabel"
	)
end
-- the gang storage: four double chests along the north wall
for _, x in ipairs({ -15, -5, 5, 15 }) do
	chest(at(x, 0, -ID + 2.5), house, "GangChest")
end
-- the Библиотекарь's corner (west): bookshelves, a lectern, the librarian
do
	for _, z in ipairs({ -14, -8, -2 }) do
		hp("Shelf", -IW, 0, z - 2.5, -IW + 2, 10, z + 2.5, "px_planks")
		for row = 0, 3 do
			for k = 0, 4 do
				decor(
					part(
						"Book",
						Vector3.new(1.2, 1.8, 0.8),
						at(-IW + 2.2, 1.2 + row * 2.4, z - 2 + k),
						BANNERS[(row + k + z) % #BANNERS + 1],
						Enum.Material.SmoothPlastic,
						house
					)
				)
			end
		end
	end
	hp("Lectern", -16, 0, -6, -14, 3.6, -4, "px_spruce_planks")
	local book = decor(
		part(
			"OpenBook",
			Vector3.new(2.4, 0.3, 1.8),
			at(-15, 3.9, -5) * CFrame.Angles(0.3, 0, 0),
			Color3.fromRGB(240, 230, 200),
			Enum.Material.SmoothPlastic,
			house
		)
	)
	light(book, 8, 0.4, Color3.fromRGB(160, 200, 255))
	npc({
		name = "GangLibrarian",
		costume = "clerk",
		shirt = Color3.fromRGB(70, 60, 110),
		parent = house,
		cf = CFrame.lookAt(Vector3.new(-18, 3, -8), Vector3.new(0, 3, -8)),
		tags = { "GangLibrarian" },
		deferTags = true,
		label = "Библиотекарь",
	})
end
-- the Кузнец's forge (east): a furnace with fire, an anvil, a tool rack, the smith
do
	hp("Furnace", IW - 5, 0, -14, IW, 7, -6, "px_cobblestone")
	hp("Chimney", IW - 3.5, 7, -12, IW, IH, -8, "px_stone_bricks")
	local mouth = decor(
		part(
			"FurnaceFire",
			Vector3.new(0.2, 3, 4),
			at(IW - 5.1, 2.5, -10),
			Color3.fromRGB(255, 120, 30),
			Enum.Material.Neon,
			house
		)
	)
	light(mouth, 20, 1.6, Color3.fromRGB(255, 150, 70))
	fire(mouth, 1.2)
	-- the anvil: a blocky iron shape
	part("AnvilBase", Vector3.new(2.4, 1, 2), at(14, 0.5, -6), IRON, Enum.Material.Metal, house)
	part(
		"AnvilWaist",
		Vector3.new(1.2, 1.2, 1.2),
		at(14, 1.6, -6),
		IRON,
		Enum.Material.Metal,
		house
	)
	part("AnvilTop", Vector3.new(3.6, 1, 1.8), at(14, 2.7, -6), IRON, Enum.Material.Metal, house)
	local hot = decor(
		part(
			"HotBlade",
			Vector3.new(2, 0.2, 0.4),
			at(14, 3.3, -6),
			Color3.fromRGB(255, 140, 40),
			Enum.Material.Neon,
			house
		)
	)
	light(hot, 6, 0.6, Color3.fromRGB(255, 140, 40))
	hp("ToolRack", IW - 0.6, 3, -2, IW, 9, 6, "px_spruce_planks")
	for k = 0, 3 do
		part(
			"Tool",
			Vector3.new(0.4, 4, 0.4),
			at(IW - 1, 6, -1 + k * 2),
			DARK,
			Enum.Material.Metal,
			house
		)
	end
	npc({
		name = "GangSmith",
		costume = "miner",
		shirt = Color3.fromRGB(110, 70, 45),
		parent = house,
		cf = CFrame.lookAt(Vector3.new(17, 3, -8), Vector3.new(0, 3, -8)),
		tags = { "GangForge" },
		deferTags = true,
		label = "Кузнец",
	})
end
-- the needs corner (south): a bed, a wooden tub, a toilet behind a screen (Restore*)
do
	hp("BedFrame", -IW + 1, 0, ID - 10, -IW + 7, 1.4, ID - 1, "px_spruce_planks")
	local bed = textured(
		part("Bed", Vector3.new(5, 0.9, 8.4), at(-IW + 4, 1.85, ID - 5.5), nil, nil, house),
		"px_white_wool"
	)
	bed:SetAttribute("HouseBanner", true)
	bed:SetAttribute("HouseTags", "RestoreSleep")
	textured(
		part("Pillow", Vector3.new(3.6, 0.6, 1.8), at(-IW + 4, 2.6, ID - 2.4), nil, nil, house),
		"px_white_wool"
	)
	-- the tub
	hp("TubSide", IW - 10, 0, ID - 9, IW - 1, 3, ID - 8, "px_spruce_planks")
	hp("TubSide", IW - 10, 0, ID - 2, IW - 1, 3, ID - 1, "px_spruce_planks")
	hp("TubSide", IW - 10, 0, ID - 8, IW - 9, 3, ID - 2, "px_spruce_planks")
	hp("TubSide", IW - 2, 0, ID - 8, IW - 1, 3, ID - 2, "px_spruce_planks")
	local tubWater = hp("TubWater", IW - 9, 0, ID - 8, IW - 2, 2.4, ID - 2, "px_water")
	tubWater.Transparency = 0.2
	tubWater.CanCollide = false
	tubWater:SetAttribute("HouseTags", "RestoreHygiene")
	-- the toilet behind a plank screen
	hp("Screen", 5, 0, ID - 9, 6, 8, ID - 1, "px_spruce_planks")
	local toilet = part(
		"Toilet",
		Vector3.new(1.8, 1.6, 2.4),
		at(9, 0.8, ID - 3),
		Color3.fromRGB(235, 235, 235),
		Enum.Material.SmoothPlastic,
		house
	)
	toilet:SetAttribute("HouseTags", "RestoreToilet")
	part(
		"ToiletTank",
		Vector3.new(1.8, 1.8, 0.8),
		at(9, 2.2, ID - 1.6),
		Color3.fromRGB(235, 235, 235),
		Enum.Material.SmoothPlastic,
		house
	)
end
-- a long table with stools in the middle, a weapon stand
do
	hp("Table", -6, 2.6, 2, 6, 3.2, 8, "px_spruce_planks")
	for _, p in ipairs({ { -5.4, 2.4 }, { 5.4, 2.4 }, { -5.4, 7.6 }, { 5.4, 7.6 } }) do
		hp("TableLeg", p[1] - 0.3, 0, p[2] - 0.3, p[1] + 0.3, 2.6, p[2] + 0.3, "px_dark_oak_planks")
	end
	for _, x in ipairs({ -4, 0, 4 }) do
		for _, z in ipairs({ 0.4, 9.6 }) do
			hp("Stool", x - 0.8, 0, z - 0.8, x + 0.8, 1.8, z + 0.8, "px_spruce_planks")
		end
	end
	decor(
		part(
			"Mug",
			Vector3.new(0.6, 0.8, 0.6),
			at(-2, 3.6, 4),
			Color3.fromRGB(150, 110, 70),
			Enum.Material.Wood,
			house
		)
	)
	decor(
		part(
			"Cards",
			Vector3.new(1.4, 0.1, 1),
			at(1, 3.25, 5),
			Color3.fromRGB(240, 240, 240),
			Enum.Material.SmoothPlastic,
			house
		)
	)
	barrel(-IW + 3, 0, 8, house)
	barrel(-IW + 3, 0, 12, house)
	crate(IW - 4, 0, 8, 3, house)
end
-- the exit door (south wall middle) → the courtyard; the arrival in front of it
do
	hp("ExitFrame", -4, 0, ID - 0.6, 4, 10, ID, "px_dark_oak_log")
	local door = hp("ExitDoor", -3, 0, ID - 1, 3, 9, ID - 0.4, "px_dark_oak_planks")
	door:SetAttribute("HouseTags", "GangHouseExit")
	part(
		"ExitKnob",
		Vector3.new(0.5, 0.5, 0.4),
		at(2, 4.5, ID - 1.2),
		Color3.fromRGB(210, 170, 60),
		Enum.Material.Metal,
		house
	)
	local spawn = part(
		"HouseSpawn",
		Vector3.new(4, 0.4, 4),
		CFrame.lookAt(Vector3.new(0, 0.2, ID - 5), Vector3.new(0, 0.2, 0)),
		nil,
		nil,
		house
	)
	textured(spawn, "px_gold_block")
	spawn:SetAttribute("LocationId", "gang_base")
	spawn:SetAttribute("HouseSpawn", true)
	spawn:SetAttribute("HouseTags", "LocationSpawn")
	-- the house box: a non-member inside it is put back in the courtyard (GangHouseService)
	local bounds = part(
		"HouseBounds",
		Vector3.new(2 * IW + 4, IH + 6, 2 * ID + 4),
		at(0, IH / 2, 0),
		nil,
		nil,
		house
	)
	bounds.Transparency = 1
	decor(bounds)
end
house.WorldPivot = CFrame.new(0, 0, 0)
house.Parent = ServerStorage

local total = #root:GetDescendants() + #house:GetDescendants()
print(("[build-gang-base] built: %d instances (courtyard + house template)"):format(total))
return ("built %d instances"):format(total)
