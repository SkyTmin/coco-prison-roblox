--!nocheck
-- Builds the База банды template (gang_base, «Нужна банда» [вики LOCATIONS-MENU]; docs/research/remaining-features-design.md
-- §1.5). [владелец 28.10: «Ты создал банду. Появляется отдельная локация для банды твоей. Туда другие банды не могут
-- попасть. И есть общая локация для банд это Гетто»] — no shared courtyard: every gang gets its own copy of
--   * ServerStorage.GangHouseTemplate — ONE base interior (pivot = the middle of its floor, built at the origin):
--     a hall with the gang storage (4 double chests, HouseTags GangChest), the Библиотекарь's corner (bookshelves,
--     lectern, HouseTags GangLibrarian), the Кузнец's forge (furnace, anvil, HouseTags GangForge), a bed / bath /
--     toilet (Restore*), a table, banners and a carpet in the gang colour (attribute HouseBanner), the «[TAG] name»
--     board (TextLabel GangTagLabel), the Шнырь (HouseTags GangShnyr: the trip to the common Гетто), the exit door
--     (GangHouseExit → the prison), the arrival (LocationSpawn, HouseSpawn) and the
--     house box HouseBounds. Tags live in the attribute HouseTags: GangHouseService adds them on each copy only.
-- NPC rigs are R15 models with a Costume attribute → NpcBodyService puts them in our block body at runtime.
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces
-- ServerStorage.GangHouseTemplate and removes the old shared courtyard Workspace.GangBase.

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

local rng = Random.new(20261028)
local OX, OZ = 0, 0 -- the current origin: the template is built at (0, 0)

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
	-- [владелец 29.10] Window panes must not bloom like large light sources.
	if string.find(string.lower(name), "window") or name == "KioskGlass" then
		p.Material = Enum.Material.SmoothPlastic
		p.Color = p.Color:Lerp(Color3.fromRGB(70, 65, 55), 0.45)
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
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
	p.Parent = parent
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
	f.Parent = parent
	return f
end
local function light(p, range, brightness, color)
	local l = Instance.new("PointLight")
	l.Range = range
	l.Brightness = brightness * 0.45
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
for index = 1, 8 do
	local x = -15 + ((index - 1) % 4) * 10
	local body = chest(at(x, math.floor((index - 1) / 4) * 3.6, -ID + 2.5), house, "GangChest")
	body.Parent:SetAttribute("UpgradeLevel", index)
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
-- the Шнырь by the exit: the trip to the common Гетто (GangBaseService, needs the «Гетто» upgrade)
do
	npc({
		name = "Shnyr",
		costume = "prisoner",
		shirt = Color3.fromRGB(230, 120, 40),
		parent = house,
		cf = CFrame.lookAt(Vector3.new(-12, 3, ID - 4), Vector3.new(-12, 3, 0)),
		tags = { "GangShnyr" },
		deferTags = true,
		label = "Шнырь",
	})
	local post = hp("SignPost", -15.5, 0, ID - 3, -14.5, 8, ID - 2, "px_dark_oak_log")
	decor(post)
	local arrow = hp("SignArrow", -18, 6, ID - 3.4, -12, 7.8, ID - 2.8, "px_spruce_planks")
	boardText(arrow, "Гетто →", Color3.fromRGB(255, 200, 90))
	barrel(-9, 0, ID - 3, house)
end
-- the exit door (south wall middle) → the prison; the arrival in front of it
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
	-- the house box: a non-member inside it is sent to the prison (GangHouseService)
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

local total = #house:GetDescendants()
print(("[build-gang-base] built: %d instances (the gang base template)"):format(total))
return ("built %d instances"):format(total)
