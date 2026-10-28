--!nocheck
-- Builds the Дворы (warzone: 7 ур. + фракция, PvP, крысы [вики LOCATIONS-MENU, HANDBOOK-WIKI]; docs/research/
-- remaining-features-design.md «Этап 2») — Workspace.Warzone at X 14400, height Y 19500. A Soviet block of flats on a
-- summer evening: two streets cross at a small square (the arrival), and each of the four quarters is a yard closed by
-- an L of five-storey panel houses (windows, balconies, entrances with canopies). In the middle of every yard stands a
-- faction point: a beacon (tag WarzonePoint on its top, WarzoneBeam on its light beam, attribute Point) and next to it
-- a 5×5 pad of ore three blocks deep — the mini-mine warzone_<point> (MineAnchor, MiniMine, NoLadders; WarzoneService
-- counts the dug blocks as capture points). Around them: playgrounds, garages, bins (rats: MobSpawn, LocationId
-- warzone), benches, a domino table, laundry lines, parked cars, poplars and birches, lamps; invisible edge walls.
-- Points: Деньги north-east, Блоки north-west, Мобы south-west, Спешка south-east (−Z is north).
-- Run in Studio (Edit) via scripts/studio-loader.luau after build-textures. Idempotent: replaces Workspace.Warzone.

local CollectionService = game:GetService("CollectionService")

local old = workspace:FindFirstChild("Warzone")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Warzone"
root:SetAttribute("LocationId", "warzone")
root.Parent = workspace

local OX, OZ = 14400, 0
local BY = 19500 -- the location's own height [CLAUDE.md: new locations float at their own height]
local HALF = 150 -- the inner half size of the block of flats
local B = 4 -- block size
local FLOOR = 8 -- one storey
local STOREYS = 5
local PAD = 5 -- pad blocks across
local PAD_DEPTH = 3 -- pad layers
local rng = Random.new(20261030)

local DARK = Color3.fromRGB(42, 42, 46)
local ASPHALT = Color3.fromRGB(70, 70, 76)
local METAL = Color3.fromRGB(90, 96, 104)
local WARM = Color3.fromRGB(255, 200, 130)
local PIPE = Color3.fromRGB(60, 110, 160)

-- the four points: quarter signs (sx, sz), the colour of the beacon core, a symbol (no words: the boards are localized)
local POINTS = {
	{ id = "money", sx = 1, sz = -1, core = Color3.fromRGB(90, 230, 110), symbol = "$" },
	{ id = "blocks", sx = -1, sz = -1, core = Color3.fromRGB(80, 160, 255), symbol = "▣" },
	{ id = "mobs", sx = -1, sz = 1, core = Color3.fromRGB(255, 80, 70), symbol = "☠" },
	{ id = "haste", sx = 1, sz = 1, core = Color3.fromRGB(255, 215, 60), symbol = "⛏" },
}
-- the look of each yard's houses: panel concrete or silicate / red brick
local FACADES = {
	{ variant = "px_white_stone_bricks", tint = Color3.fromRGB(235, 232, 225), seams = false },
	{ variant = nil, color = Color3.fromRGB(196, 194, 186), seams = true },
	{ variant = "px_red_brick", tint = Color3.fromRGB(230, 215, 205), seams = false },
	{ variant = nil, color = Color3.fromRGB(212, 200, 176), seams = true },
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
local function cylinder(name, length, d, cf, color, material, parent)
	-- a cylinder's axis is its X: `cf` points X along the length
	local p = part(name, Vector3.new(length, d, d), cf, color, material, parent)
	p.Shape = Enum.PartType.Cylinder
	return p
end
local UP = CFrame.Angles(0, 0, math.pi / 2) -- turns a cylinder upright
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
		label.Font = font or Enum.Font.GothamBlack
		label.Text = text
		label.Parent = gui
	end
end
local ALL_SIDES =
	{ Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }

-- a yard's own coordinates: u runs from the N–S street outwards (x = sx·u), v from the E–W street (z = sz·v)
local function yardAt(sx, sz)
	return function(u, y, v)
		return at(sx * u, y, sz * v)
	end, function(name, u0, y0, v0, u1, y1, v1, color, material, parent)
		return box(name, sx * u0, y0, sz * v0, sx * u1, y1, sz * v1, color, material, parent)
	end
end

-- reserved rectangles (world-local x/z) the random trees keep out of
local claims = {}
local function claim(x0, z0, x1, z1)
	table.insert(claims, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1) })
end
local function claimed(x, z, pad)
	for _, c in ipairs(claims) do
		if x > c[1] - pad and x < c[3] + pad and z > c[2] - pad and z < c[4] + pad then
			return true
		end
	end
	return false
end

-- a slab cut by rectangular holes (the pits of the pads): a grid on every hole edge, merged along X per row
local function slabWithHoles(name, x0, x1, z0, z1, y0, y1, holes, variant, tint, parent)
	local xs, zs = { x0, x1 }, { z0, z1 }
	for _, h in ipairs(holes) do
		table.insert(xs, h[1])
		table.insert(xs, h[3])
		table.insert(zs, h[2])
		table.insert(zs, h[4])
	end
	table.sort(xs)
	table.sort(zs)
	local function inHole(x, z)
		for _, h in ipairs(holes) do
			if x > h[1] and x < h[3] and z > h[2] and z < h[4] then
				return true
			end
		end
		return false
	end
	for i = 1, #zs - 1 do
		local za, zb = zs[i], zs[i + 1]
		if zb - za > 0.01 then
			local runStart = nil
			for j = 1, #xs - 1 do
				local xa, xb = xs[j], xs[j + 1]
				if xb - xa > 0.01 then
					if inHole((xa + xb) / 2, (za + zb) / 2) then
						if runStart then
							tbox(name, runStart, y0, za, xa, y1, zb, variant, tint, parent)
							runStart = nil
						end
					elseif not runStart then
						runStart = xa
					end
				end
			end
			if runStart then
				tbox(name, runStart, y0, za, x1, y1, zb, variant, tint, parent)
			end
		end
	end
end

-- ================================================================ ground, streets, the square
local ground = folder("Ground")
local PAD_HALF = PAD * B / 2 -- 10 studs
local PAD_UV = 74 -- the pad centre in yard coordinates (u = v)
local holes = {}
for _, pt in ipairs(POINTS) do
	local cx, cz = pt.sx * PAD_UV, pt.sz * PAD_UV
	table.insert(holes, { cx - PAD_HALF, cz - PAD_HALF, cx + PAD_HALF, cz + PAD_HALF })
end
slabWithHoles(
	"Grass",
	-HALF - 6,
	HALF + 6,
	-HALF - 6,
	HALF + 6,
	-2,
	0,
	holes,
	"px_grass_top",
	Color3.fromRGB(200, 215, 180),
	ground
)
-- the cross of streets (asphalt), curbs and sidewalks
box("RoadNS", -8, -0.4, -HALF - 6, 8, 0.12, HALF + 6, ASPHALT, Enum.Material.Asphalt, ground)
box("RoadEW", -HALF - 6, -0.4, -8, HALF + 6, 0.12, 8, ASPHALT, Enum.Material.Asphalt, ground)
for _, s in ipairs({ -1, 1 }) do
	for _, run in ipairs({ { -HALF - 6, -12 }, { 12, HALF + 6 } }) do
		tbox("Sidewalk", s * 8, -0.4, run[1], s * 12, 0.45, run[2], "px_smooth_stone", nil, ground)
		tbox("Sidewalk", run[1], -0.4, s * 8, run[2], 0.45, s * 12, "px_smooth_stone", nil, ground)
	end
end
-- road markings: a dashed centre line
for k = -HALF + 4, HALF - 4, 12 do
	if math.abs(k) > 30 then
		decor(
			box(
				"Marking",
				-0.3,
				0.12,
				k - 3,
				0.3,
				0.16,
				k + 3,
				Color3.fromRGB(235, 235, 225),
				nil,
				ground
			)
		)
		decor(
			box(
				"Marking",
				k - 3,
				0.12,
				-0.3,
				k + 3,
				0.16,
				0.3,
				Color3.fromRGB(235, 235, 225),
				nil,
				ground
			)
		)
	end
end
-- the square at the crossing
tbox(
	"Square",
	-28,
	-0.4,
	-28,
	28,
	0.5,
	28,
	"px_stone_bricks",
	Color3.fromRGB(215, 210, 200),
	ground
)
claim(-30, -30, 30, 30)
claim(-14, -HALF - 6, 14, HALF + 6)
claim(-HALF - 6, -14, HALF + 6, 14)

-- ================================================================ the square: arrival, board, signposts, flower beds
local square = folder("Square")
do
	local spawn = part(
		"LocationSpawn_warzone",
		Vector3.new(4, 1, 4),
		CFrame.lookAt(Vector3.new(OX, 0.75, OZ + 18), Vector3.new(OX, 0.75, OZ)),
		nil,
		nil,
		square
	)
	textured(spawn, "px_gold_block")
	spawn:SetAttribute("LocationId", "warzone")
	CollectionService:AddTag(spawn, "LocationSpawn")
	-- the board «ДВОРЫ» (the location name, like the other locations' boards) on two posts
	tbox("BoardPost", -9, 0.5, -20, -8, 12, -19, "px_dark_oak_log", nil, square)
	tbox("BoardPost", 8, 0.5, -20, 9, 12, -19, "px_dark_oak_log", nil, square)
	local board = part(
		"Board",
		Vector3.new(19, 5, 0.6),
		at(0, 9.5, -19.5),
		Color3.fromRGB(40, 70, 120),
		Enum.Material.SmoothPlastic,
		square
	)
	boardText(
		board,
		"ДВОРЫ",
		Color3.fromRGB(255, 225, 120),
		{ Enum.NormalId.Back, Enum.NormalId.Front }
	)
	light(board, 18, 0.8)
	-- signposts to the four points: an arrow plate in the point's colour with its symbol
	for _, pt in ipairs(POINTS) do
		local x, z = pt.sx * 20, pt.sz * 20
		cylinder("SignPole", 7, 0.5, at(x, 4, z) * UP, METAL, Enum.Material.Metal, square)
		local yaw = math.atan2(-pt.sx, -pt.sz) -- the plate's front looks at the yard it points to
		local plate = part(
			"SignPlate",
			Vector3.new(3, 3, 0.3),
			at(x, 6.6, z) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(0, 0, math.pi / 4),
			pt.core,
			Enum.Material.SmoothPlastic,
			square
		)
		boardText(
			plate,
			pt.symbol,
			Color3.fromRGB(20, 20, 24),
			{ Enum.NormalId.Front, Enum.NormalId.Back }
		)
	end
	-- flower beds in the corners of the square
	for _, s in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local cx, cz = s[1] * 22, s[2] * 22
		tbox("BedCurb", cx - 4, 0.5, cz - 4, cx + 4, 1.3, cz + 4, "px_smooth_stone", nil, square)
		tbox("BedSoil", cx - 3.4, 1.3, cz - 3.4, cx + 3.4, 1.4, cz + 3.4, "px_dirt", nil, square)
		for k = 1, 7 do
			decor(
				part(
					"Flower",
					Vector3.new(0.6, 0.6, 0.6),
					at(cx + rng:NextNumber(-2.8, 2.8), 1.8, cz + rng:NextNumber(-2.8, 2.8)),
					({
						Color3.fromRGB(240, 70, 60),
						Color3.fromRGB(250, 210, 40),
						Color3.fromRGB(245, 245, 240),
						Color3.fromRGB(230, 90, 190),
					})[k % 4 + 1],
					Enum.Material.SmoothPlastic,
					square
				)
			)
		end
	end
end

-- ================================================================ props
local function lamp(x, z, parent)
	cylinder("LampPole", 10, 0.6, at(x, 5, z) * UP, METAL, Enum.Material.Metal, parent)
	box(
		"LampArm",
		x - 0.2,
		9.8,
		z - 0.2,
		x + 1.8,
		10.2,
		z + 0.2,
		METAL,
		Enum.Material.Metal,
		parent
	)
	local head = decor(
		part(
			"LampHead",
			Vector3.new(1.4, 0.4, 0.9),
			at(x + 1.8, 9.8, z),
			WARM,
			Enum.Material.Neon,
			parent
		)
	)
	light(head, 32, 1.1)
end
local function bench(cf, parent)
	textured(
		part("BenchSeat", Vector3.new(5, 0.3, 1.4), cf * CFrame.new(0, 1.6, 0), nil, nil, parent),
		"px_spruce_planks"
	)
	textured(
		part(
			"BenchBack",
			Vector3.new(5, 1.2, 0.25),
			cf * CFrame.new(0, 2.5, 0.65) * CFrame.Angles(-0.2, 0, 0),
			nil,
			nil,
			parent
		),
		"px_spruce_planks"
	)
	for _, dx in ipairs({ -2, 2 }) do
		part(
			"BenchLeg",
			Vector3.new(0.3, 1.5, 1.2),
			cf * CFrame.new(dx, 0.75, 0),
			DARK,
			Enum.Material.Metal,
			parent
		)
	end
end
local function bin(cf, parent)
	part(
		"Bin",
		Vector3.new(4, 3.6, 3),
		cf * CFrame.new(0, 1.8, 0),
		Color3.fromRGB(45, 95, 60),
		Enum.Material.DiamondPlate,
		parent
	)
	part(
		"BinLid",
		Vector3.new(4.2, 0.3, 3.2),
		cf * CFrame.new(0, 3.75, -0.3) * CFrame.Angles(-0.25, 0, 0),
		Color3.fromRGB(30, 30, 32),
		Enum.Material.Metal,
		parent
	)
end
local function trashBag(cf, parent)
	decor(
		part(
			"TrashBag",
			Vector3.new(1.6, 1.4, 1.6),
			cf,
			Color3.fromRGB(25, 25, 28),
			Enum.Material.Plastic,
			parent
		)
	)
end
local CAR_COLORS = {
	Color3.fromRGB(230, 220, 190),
	Color3.fromRGB(170, 40, 40),
	Color3.fromRGB(240, 240, 235),
	Color3.fromRGB(60, 90, 150),
	Color3.fromRGB(90, 130, 80),
	Color3.fromRGB(200, 150, 60),
}
-- a boxy old saloon: body, cabin with glass, bumpers, lights, four wheels
local function car(cf, parent)
	local m = Instance.new("Model")
	m.Name = "Car"
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	local color = CAR_COLORS[rng:NextInteger(1, #CAR_COLORS)]
	part(
		"Body",
		Vector3.new(5.2, 1.7, 10.4),
		cf * CFrame.new(0, 1.65, 0),
		color,
		Enum.Material.SmoothPlastic,
		m
	)
	part(
		"Cabin",
		Vector3.new(4.8, 1.5, 5),
		cf * CFrame.new(0, 3.25, 0.4),
		color,
		Enum.Material.SmoothPlastic,
		m
	)
	decor(
		part(
			"Glass",
			Vector3.new(4.9, 1.1, 5.1),
			cf * CFrame.new(0, 3.3, 0.4),
			Color3.fromRGB(60, 80, 100),
			Enum.Material.Glass,
			m
		)
	).Transparency =
		0.2
	for _, dz in ipairs({ -5.25, 5.25 }) do
		part(
			"Bumper",
			Vector3.new(5.4, 0.5, 0.3),
			cf * CFrame.new(0, 1.1, dz),
			Color3.fromRGB(170, 170, 175),
			Enum.Material.Metal,
			m
		)
	end
	for _, dx in ipairs({ -1.8, 1.8 }) do
		decor(
			part(
				"Headlight",
				Vector3.new(0.9, 0.5, 0.2),
				cf * CFrame.new(dx, 1.9, -5.25),
				Color3.fromRGB(255, 250, 220),
				Enum.Material.Neon,
				m
			)
		)
		decor(
			part(
				"Taillight",
				Vector3.new(0.9, 0.4, 0.2),
				cf * CFrame.new(dx, 1.9, 5.25),
				Color3.fromRGB(200, 30, 30),
				Enum.Material.Neon,
				m
			)
		)
	end
	for _, w in ipairs({ { -2.4, -3.3 }, { 2.4, -3.3 }, { -2.4, 3.3 }, { 2.4, 3.3 } }) do
		cylinder(
			"Wheel",
			0.8,
			2,
			cf * CFrame.new(w[1], 1, w[2]),
			Color3.fromRGB(22, 22, 24),
			Enum.Material.Rubber,
			m
		)
	end
end
local function birch(x, z, s, parent)
	local h = 7 * s
	tbox("Trunk", x - 0.6, 0, z - 0.6, x + 0.6, h, z + 0.6, "px_birch_log", nil, parent)
	for _, c in ipairs({
		{ 0, h, 0, 5 },
		{ 1.4, h - 1.6, 1, 3.6 },
		{ -1.3, h - 1.2, -1.2, 3.4 },
		{ 0, h + 2, 0, 3 },
	}) do
		local d = c[4] * s
		decor(
			textured(
				part("Leaves", Vector3.new(d, d, d), at(x + c[1], c[2], z + c[3]), nil, nil, parent),
				"px_hedge",
				Color3.fromRGB(185, 220, 140)
			)
		)
	end
end
local function poplar(x, z, s, parent)
	local h = 6 * s
	tbox("Trunk", x - 0.7, 0, z - 0.7, x + 0.7, h, z + 0.7, "px_oak_log", nil, parent)
	for k = 0, 3 do
		local w = (5 - k) * s
		decor(
			textured(
				part(
					"Leaves",
					Vector3.new(w, 4 * s, w),
					at(x, h + k * 3.6 * s, z),
					nil,
					nil,
					parent
				),
				"px_hedge",
				Color3.fromRGB(150, 185, 120)
			)
		)
	end
end

-- ================================================================ a panel house
-- x0..x1 × z0..z1 footprint; the yard-facing facade: f = {axis = "x"|"z", sign = ±1 (its outward normal),
-- plane = the wall coordinate, lo..hi = along it}; `look` = FACADES entry
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
local FACE_ID = {
	x = { [1] = Enum.NormalId.Right, [-1] = Enum.NormalId.Left },
	z = { [1] = Enum.NormalId.Back, [-1] = Enum.NormalId.Front },
}
local WINDOW_DARK =
	{ Color3.fromRGB(46, 58, 72), Color3.fromRGB(58, 70, 84), Color3.fromRGB(40, 48, 60) }
local CURTAINS =
	{ Color3.fromRGB(255, 215, 150), Color3.fromRGB(255, 190, 170), Color3.fromRGB(220, 235, 255) }
local function house(x0, z0, x1, z1, f, look, parent)
	local h = STOREYS * FLOOR + 1
	local body = box("House", x0, 0, z0, x1, h, z1, look.color, Enum.Material.Concrete, parent)
	if look.variant then
		textured(body, look.variant, look.tint)
	end
	-- the plinth and the flat roof with its parapet, a stair hut and aerials
	box(
		"Plinth",
		x0 - 0.3,
		0,
		z0 - 0.3,
		x1 + 0.3,
		1.4,
		z1 + 0.3,
		Color3.fromRGB(120, 116, 110),
		Enum.Material.Concrete,
		parent
	)
	tbox(
		"Roof",
		x0 - 0.4,
		h,
		z0 - 0.4,
		x1 + 0.4,
		h + 0.6,
		z1 + 0.4,
		"px_gravel",
		Color3.fromRGB(150, 150, 150),
		parent
	)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	box(
		"RoofHut",
		cx - 3,
		h + 0.6,
		cz - 3,
		cx + 3,
		h + 4.6,
		cz + 3,
		look.color or Color3.fromRGB(200, 196, 186),
		Enum.Material.Concrete,
		parent
	)
	for k = 1, 3 do
		local ax = x0 + (x1 - x0) * k / 4
		local az = z0 + (z1 - z0) * k / 4
		cylinder("Aerial", 6, 0.25, at(ax, h + 3.6, az) * UP, METAL, Enum.Material.Metal, parent)
		box(
			"AerialBar",
			ax - 1.5,
			h + 5.6,
			az - 0.1,
			ax + 1.5,
			h + 5.8,
			az + 0.1,
			METAL,
			Enum.Material.Metal,
			parent
		)
	end
	-- entrances: three along the facade (a door, a canopy with a lamp, a step, a bench beside)
	local length = f.hi - f.lo
	local doors = {}
	for k = 1, 3 do
		local u = f.lo + length * (2 * k - 1) / 6
		table.insert(doors, u)
		facePart(
			"Door",
			f,
			u,
			3.6,
			3.2,
			5.4,
			0.3,
			0.35,
			Color3.fromRGB(95, 60, 40),
			Enum.Material.Wood,
			parent
		)
		local canopy = facePart(
			"Canopy",
			f,
			u,
			7,
			5.4,
			0.4,
			2.8,
			1.4,
			Color3.fromRGB(150, 146, 140),
			Enum.Material.Concrete,
			parent
		)
		light(canopy, 14, 0.7)
		facePart(
			"Step",
			f,
			u,
			0.7,
			5.4,
			0.6,
			2.4,
			1.2,
			Color3.fromRGB(150, 146, 140),
			Enum.Material.Concrete,
			parent
		)
		local number = decor(
			facePart(
				"EntranceNo",
				f,
				u,
				8.4,
				1.4,
				1.2,
				0.2,
				0.15,
				Color3.fromRGB(40, 70, 130),
				nil,
				parent
			)
		)
		boardText(number, tostring(k), Color3.new(1, 1, 1), { FACE_ID[f.axis][f.sign] })
		-- a bench beside the door, facing the yard
		local side = u + 5
		local bx, bz
		if f.axis == "x" then
			bx, bz = f.plane + f.sign * 3.5, side
		else
			bx, bz = side, f.plane + f.sign * 3.5
		end
		local outward = if f.axis == "x"
			then Vector3.new(f.sign, 0, 0)
			else Vector3.new(0, 0, f.sign)
		local base = at(bx, 0.45, bz)
		bench(CFrame.lookAt(base.Position, base.Position + outward), parent) -- the back (+Z) to the wall
	end
	-- windows (and a few glazed balconies) on the yard facade; the ground floor skips the entrances
	local column = 0
	for u = f.lo + 4.5, f.hi - 4.5, 6 do
		column += 1
		local nearDoor = false
		for _, d in ipairs(doors) do
			if math.abs(u - d) < 4.6 then
				nearDoor = true
			end
		end
		for floor = 1, STOREYS do
			local y = (floor - 1) * FLOOR + 5
			if not (floor == 1 and nearDoor) then
				local lit = rng:NextNumber() < 0.18
				facePart(
					"Window",
					f,
					u,
					y,
					3,
					3.6,
					0.3,
					0.1,
					if lit
						then CURTAINS[rng:NextInteger(1, #CURTAINS)]
						else WINDOW_DARK[rng:NextInteger(1, #WINDOW_DARK)],
					if lit then Enum.Material.SmoothPlastic else Enum.Material.Glass,
					parent
				)
				facePart(
					"Sill",
					f,
					u,
					y - 2,
					3.6,
					0.25,
					0.6,
					0.3,
					Color3.fromRGB(235, 235, 230),
					nil,
					parent
				)
			end
			if floor >= 2 and column % 3 == 2 and not nearDoor then
				facePart(
					"Balcony",
					f,
					u,
					y - 3.2,
					4.8,
					0.4,
					2.4,
					1.2,
					Color3.fromRGB(170, 166, 160),
					Enum.Material.Concrete,
					parent
				)
				local railColor = if rng:NextNumber() < 0.4
					then Color3.fromRGB(110, 140, 170)
					else Color3.fromRGB(190, 186, 178)
				facePart(
					"BalconyRail",
					f,
					u,
					y - 2,
					4.8,
					2,
					0.25,
					2.3,
					railColor,
					Enum.Material.Concrete,
					parent
				)
			end
		end
	end
	-- floor seams of a panel house
	if look.seams then
		for floor = 1, STOREYS - 1 do
			decor(
				facePart(
					"Seam",
					f,
					(f.lo + f.hi) / 2,
					floor * FLOOR + 0.6,
					length,
					0.3,
					0.2,
					0.08,
					Color3.fromRGB(150, 148, 142),
					nil,
					parent
				)
			)
		end
	end
	claim(x0, z0, x1, z1)
end

-- ================================================================ a beacon and its pad
local anchors = {} -- tagged MineAnchor after the lift
local function ladderPlate(base, inward, along, height, parent)
	local ladderTexture =
		require(game:GetService("ReplicatedStorage").Shared.Config.textures).textures.ladder
	for k = 0, 3 do -- four 2×2 trusses across 8 studs, inside the wall (climbable once the blocks are dug)
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Size = Vector3.new(2, height, 2)
		truss.CFrame = CFrame.new(base - inward * 0.6 + along * (-4 + 1 + k * 2))
		truss.Anchored = true
		truss.Transparency = 1
		truss.Parent = parent
	end
	local plate = Instance.new("Part")
	plate.Name = "LadderFace"
	plate.Size = Vector3.new(
		8 * along.X + 0.2 * math.abs(inward.X),
		height,
		8 * along.Z + 0.2 * math.abs(inward.Z)
	)
	plate.CFrame = CFrame.new(base + inward * 0.15)
	plate.Anchored, plate.CanCollide, plate.CanQuery, plate.Transparency = true, false, false, 1
	plate.Parent = parent
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

local function pad(pt, cx, cz, parent)
	local h = PAD_DEPTH * B
	local e = PAD_HALF
	local STONE = Color3.fromRGB(110, 106, 112)
	-- the pit under the blocks: floor and walls (the grass slab has the hole)
	tbox(
		"PitFloor",
		cx - e - 1,
		-h - 1,
		cz - e - 1,
		cx + e + 1,
		-h,
		cz + e + 1,
		"px_cobblestone",
		STONE,
		parent
	)
	tbox(
		"PitWall",
		cx - e - 1,
		-h,
		cz - e - 1,
		cx + e + 1,
		-2,
		cz - e,
		"px_cobblestone",
		STONE,
		parent
	)
	tbox(
		"PitWall",
		cx - e - 1,
		-h,
		cz + e,
		cx + e + 1,
		-2,
		cz + e + 1,
		"px_cobblestone",
		STONE,
		parent
	)
	tbox("PitWall", cx - e - 1, -h, cz - e, cx - e, -2, cz + e, "px_cobblestone", STONE, parent)
	tbox("PitWall", cx + e, -h, cz - e, cx + e + 1, -2, cz + e, "px_cobblestone", STONE, parent)
	-- a paved rim round the pad, flush with the block tops
	local r = 4
	tbox(
		"PadRim",
		cx - e - r,
		-0.5,
		cz - e - r,
		cx + e + r,
		0.12,
		cz - e,
		"px_stone_bricks",
		nil,
		parent
	)
	tbox(
		"PadRim",
		cx - e - r,
		-0.5,
		cz + e,
		cx + e + r,
		0.12,
		cz + e + r,
		"px_stone_bricks",
		nil,
		parent
	)
	tbox("PadRim", cx - e - r, -0.5, cz - e, cx - e, 0.12, cz + e, "px_stone_bricks", nil, parent)
	tbox("PadRim", cx + e, -0.5, cz - e, cx + e + r, 0.12, cz + e, "px_stone_bricks", nil, parent)
	-- corner bollards in the point's colour
	for _, c in ipairs({ { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } }) do
		local bx, bz = cx + c[1] * (e + 2), cz + c[2] * (e + 2)
		box(
			"Bollard",
			bx - 0.6,
			0.12,
			bz - 0.6,
			bx + 0.6,
			2.2,
			bz + 0.6,
			Color3.fromRGB(40, 40, 44),
			Enum.Material.Metal,
			parent
		)
		decor(
			box(
				"BollardCap",
				bx - 0.7,
				2.2,
				bz - 0.7,
				bx + 0.7,
				2.6,
				bz + 0.7,
				pt.core,
				Enum.Material.Neon,
				parent
			)
		)
	end
	-- the anchor (MineService grows the grid down from its top centre)
	local anchor = box(
		"MineAnchor_warzone_" .. pt.id,
		cx - e,
		-0.2,
		cz - e,
		cx + e,
		0,
		cz + e,
		DARK,
		nil,
		parent
	)
	anchor:SetAttribute("LocationId", "warzone")
	anchor:SetAttribute("MineId", "warzone_" .. pt.id)
	anchor:SetAttribute("Size", Vector3.new(PAD, PAD_DEPTH, PAD))
	anchor:SetAttribute("MiniMine", true)
	anchor:SetAttribute("NoLadders", true)
	anchor.CanQuery = false
	anchor.CanTouch = false
	table.insert(anchors, anchor)
	-- ladders on the two walls across the street sides, to climb out of a dug pit
	ladderPlate(
		at(cx, -h / 2, cz + pt.sz * e).Position,
		Vector3.new(0, 0, -pt.sz),
		Vector3.new(1, 0, 0),
		h,
		parent
	)
	ladderPlate(
		at(cx + pt.sx * e, -h / 2, cz).Position,
		Vector3.new(-pt.sx, 0, 0),
		Vector3.new(0, 0, 1),
		h,
		parent
	)
	claim(cx - e - r - 2, cz - e - r - 2, cx + e + r + 2, cz + e + r + 2)
end

local function beacon(pt, x, z, parent)
	local m = Instance.new("Model")
	m.Name = "Beacon_" .. pt.id
	m.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	m.Parent = parent
	tbox("BeaconBase", x - 5, 0, z - 5, x + 5, 1.4, z + 5, "px_iron_block", nil, m)
	local tier = tbox(
		"BeaconTier",
		x - 3.5,
		1.4,
		z - 3.5,
		x + 3.5,
		2.8,
		z + 3.5,
		"px_iron_block",
		Color3.fromRGB(225, 225, 230),
		m
	)
	boardText(tier, pt.symbol, pt.core, ALL_SIDES)
	local glass = part(
		"BeaconGlass",
		Vector3.new(4.4, 4.4, 4.4),
		at(x, 5, z),
		Color3.fromRGB(200, 235, 245),
		Enum.Material.Glass,
		m
	)
	glass.Transparency = 0.55
	local core = decor(
		part("BeaconCore", Vector3.new(2.2, 2.2, 2.2), at(x, 5, z), pt.core, Enum.Material.Neon, m)
	)
	light(core, 18, 1.4, pt.core)
	tbox("BeaconCap", x - 2.6, 7.2, z - 2.6, x + 2.6, 7.8, z + 2.6, "px_obsidian", nil, m)
	-- the top (WarzoneHud hangs the board here) and the beam (WarzoneService paints it in the owner's colour)
	local top = decor(part("BeaconTop", Vector3.new(1, 1, 1), at(x, 8.4, z), nil, nil, m))
	top.Transparency = 1
	top:SetAttribute("Point", pt.id)
	CollectionService:AddTag(top, "WarzonePoint")
	local beam = decor(
		cylinder(
			"BeaconBeam",
			180,
			1.8,
			at(x, 7.8 + 90, z) * UP,
			Color3.fromRGB(235, 235, 245),
			Enum.Material.Neon,
			m
		)
	)
	beam.Transparency = 0.45
	beam.CastShadow = false
	beam:SetAttribute("Point", pt.id)
	CollectionService:AddTag(beam, "WarzoneBeam")
	claim(x - 6, z - 6, x + 6, z + 6)
end

-- ================================================================ yard furniture
local function playground(Y, B_, sx, sz, parent)
	-- sandbox
	local function plank(u0, v0, u1, v1)
		local p = B_("SandboxSide", u0, 0, v0, u1, 1.2, v1, nil, nil, parent)
		textured(p, "px_planks")
	end
	plank(26, 66, 38, 67)
	plank(26, 77, 38, 78)
	plank(26, 67, 27, 77)
	plank(37, 67, 38, 77)
	textured(B_("Sand", 27, 0, 67, 37, 0.7, 77, nil, nil, parent), "px_sand")
	-- swings: two A-frames, a bar, two seats on chains
	for _, du in ipairs({ 44, 54 }) do
		for _, dv in ipairs({ 66, 70 }) do
			B_(
				"SwingPost",
				du - 0.3,
				0,
				dv - 0.3,
				du + 0.3,
				8,
				dv + 0.3,
				PIPE,
				Enum.Material.Metal,
				parent
			)
		end
	end
	B_("SwingBar", 44, 7.7, 67.7, 54, 8.3, 68.3, PIPE, Enum.Material.Metal, parent)
	for _, su in ipairs({ 47, 51 }) do
		for _, off in ipairs({ -0.8, 0.8 }) do
			decor(
				B_(
					"Chain",
					su + off - 0.08,
					2.4,
					67.92,
					su + off + 0.08,
					7.7,
					68.08,
					METAL,
					Enum.Material.Metal,
					parent
				)
			)
		end
		textured(
			B_("SwingSeat", su - 1.1, 2.1, 67.4, su + 1.1, 2.4, 68.6, nil, nil, parent),
			"px_planks"
		)
	end
	-- slide: a platform with a ladder and a ramp down towards the street
	B_(
		"SlidePlatform",
		44,
		5,
		78,
		48,
		5.4,
		82,
		Color3.fromRGB(200, 70, 60),
		Enum.Material.SmoothPlastic,
		parent
	)
	for _, c in ipairs({ { 44, 78 }, { 48, 78 }, { 44, 82 }, { 48, 82 } }) do
		B_(
			"SlidePost",
			c[1] - 0.25,
			0,
			c[2] - 0.25,
			c[1] + 0.25,
			5,
			c[2] + 0.25,
			PIPE,
			Enum.Material.Metal,
			parent
		)
	end
	local top = Y(46, 5.2, 84.5)
	local bottom = Y(46, 0.6, 92)
	local mid = (top.Position + bottom.Position) / 2
	local len = (top.Position - bottom.Position).Magnitude
	part(
		"SlideRamp",
		Vector3.new(3, 0.3, len),
		CFrame.lookAt(mid, bottom.Position),
		Color3.fromRGB(230, 200, 60),
		Enum.Material.SmoothPlastic,
		parent
	)
	for k = 0, 4 do
		B_("SlideRung", 43.5, 1 + k, 76.8, 48.5, 1.2 + k, 77.2, PIPE, Enum.Material.Metal, parent)
	end
	-- carousel
	local c = Y(32, 0.6, 88)
	cylinder(
		"Carousel",
		0.4,
		8,
		c * UP,
		Color3.fromRGB(220, 80, 60),
		Enum.Material.SmoothPlastic,
		parent
	)
	cylinder(
		"CarouselPole",
		3.2,
		0.5,
		(c + Vector3.new(0, 1.8, 0)) * UP,
		PIPE,
		Enum.Material.Metal,
		parent
	)
	for k = 0, 3 do
		local a = k * math.pi / 2
		decor(
			part(
				"CarouselBar",
				Vector3.new(0.3, 0.3, 3.6),
				c * CFrame.Angles(0, a, 0) * CFrame.new(0, 2.6, 1.8),
				PIPE,
				Enum.Material.Metal,
				parent
			)
		)
	end
	-- a hedge round the playground, open towards the yard
	textured(B_("Hedge", 22, 0, 62, 23, 2.4, 94, nil, nil, parent), "px_hedge")
	textured(B_("Hedge", 22, 0, 94, 60, 2.4, 95, nil, nil, parent), "px_hedge")
	claim(sx * 22, sz * 60, sx * 60, sz * 96)
end

local function garages(B_, sx, sz, parent)
	local doors = {
		Color3.fromRGB(70, 110, 70),
		Color3.fromRGB(110, 70, 50),
		Color3.fromRGB(60, 80, 130),
		Color3.fromRGB(130, 120, 70),
	}
	for k = 0, 3 do
		local u0 = 74 + k * 6.5
		B_(
			"Garage",
			u0,
			0,
			18,
			u0 + 6.3,
			5,
			28,
			Color3.fromRGB(150, 150, 146),
			Enum.Material.Concrete,
			parent
		)
		B_(
			"GarageRoof",
			u0 - 0.1,
			5,
			17.6,
			u0 + 6.4,
			5.4,
			28.6,
			Color3.fromRGB(70, 66, 64),
			Enum.Material.CorrodedMetal,
			parent
		)
		-- the door faces the yard (+v)
		B_(
			"GarageDoor",
			u0 + 0.6,
			0.2,
			28,
			u0 + 5.7,
			4.4,
			28.25,
			doors[k + 1],
			Enum.Material.CorrodedMetal,
			parent
		)
	end
	claim(sx * 72, sz * 16, sx * 102, sz * 31)
end

local function laundry(B_, parent)
	for _, v in ipairs({ 30, 46 }) do
		B_("LaundryPole", 21.8, 0, v - 0.2, 22.2, 7, v + 0.2, METAL, Enum.Material.Metal, parent)
		B_("LaundryT", 19.5, 6.7, v - 0.15, 24.5, 6.9, v + 0.15, METAL, Enum.Material.Metal, parent)
	end
	for _, du in ipairs({ 20, 22, 24 }) do
		decor(
			B_(
				"Line",
				du - 0.05,
				6.75,
				30,
				du + 0.05,
				6.85,
				46,
				Color3.fromRGB(230, 230, 230),
				nil,
				parent
			)
		)
		for v = 32, 43, 3 do
			if rng:NextNumber() < 0.6 then
				local cloth = decor(
					B_(
						"Cloth",
						du - 0.1,
						4.8,
						v,
						du + 0.1,
						6.75,
						v + 2,
						nil,
						Enum.Material.Fabric,
						parent
					)
				)
				cloth.Color = ({
					Color3.fromRGB(240, 240, 235),
					Color3.fromRGB(200, 60, 60),
					Color3.fromRGB(70, 110, 190),
					Color3.fromRGB(240, 210, 80),
				})[rng:NextInteger(1, 4)]
			end
		end
	end
end

local function dominoTable(Y, parent)
	local c = Y(50, 0, 40)
	textured(
		part("DominoTable", Vector3.new(5, 0.3, 3.4), c * CFrame.new(0, 2.6, 0), nil, nil, parent),
		"px_spruce_planks"
	)
	part(
		"DominoLeg",
		Vector3.new(0.6, 2.5, 0.6),
		c * CFrame.new(0, 1.25, 0),
		DARK,
		Enum.Material.Metal,
		parent
	)
	for _, dz in ipairs({ -2.8, 2.8 }) do
		textured(
			part(
				"DominoBench",
				Vector3.new(5, 0.3, 1.2),
				c * CFrame.new(0, 1.5, dz),
				nil,
				nil,
				parent
			),
			"px_spruce_planks"
		)
		part(
			"DominoBenchLeg",
			Vector3.new(0.5, 1.4, 0.5),
			c * CFrame.new(0, 0.7, dz),
			DARK,
			Enum.Material.Metal,
			parent
		)
	end
	for k = 1, 5 do
		decor(
			part(
				"Domino",
				Vector3.new(0.5, 0.12, 0.9),
				c
					* CFrame.new(-1.6 + k * 0.6, 2.8, rng:NextNumber(-0.6, 0.6))
					* CFrame.Angles(0, rng:NextNumber(0, 3), 0),
				Color3.fromRGB(245, 245, 240),
				nil,
				parent
			)
		)
	end
end

local function pullUpBar(B_, parent)
	for _, v in ipairs({ 30, 36 }) do
		B_("BarPost", 57.7, 0, v - 0.3, 58.3, 8, v + 0.3, METAL, Enum.Material.Metal, parent)
	end
	B_("Bar", 57.85, 7.2, 30, 58.15, 7.5, 36, METAL, Enum.Material.Metal, parent)
end

-- ================================================================ the four yards
local mobs = folder("MobSpawns")
local function mobSpawn(x, z, radius)
	local m = decor(part("MobSpawn_rat", Vector3.new(2, 1, 2), at(x, 0.8, z), nil, nil, mobs))
	m.Transparency = 1
	m:SetAttribute("MobId", "rat")
	m:SetAttribute("LocationId", "warzone")
	m:SetAttribute("Wander", radius)
	CollectionService:AddTag(m, "MobSpawn")
end

for index, pt in ipairs(POINTS) do
	local sx, sz = pt.sx, pt.sz
	local yard = folder("Yard_" .. pt.id)
	local Y, B_ = yardAt(sx, sz)
	local look = FACADES[index]
	-- the L of houses on the outer edges; facades look into the yard
	house(
		math.min(sx * 124, sx * 140),
		math.min(sz * 18, sz * 132),
		math.max(sx * 124, sx * 140),
		math.max(sz * 18, sz * 132),
		{
			axis = "x",
			sign = -sx,
			plane = sx * 124,
			lo = math.min(sz * 18, sz * 132),
			hi = math.max(sz * 18, sz * 132),
		},
		look,
		yard
	)
	house(
		math.min(sx * 18, sx * 112),
		math.min(sz * 124, sz * 140),
		math.max(sx * 18, sx * 112),
		math.max(sz * 124, sz * 140),
		{
			axis = "z",
			sign = -sz,
			plane = sz * 124,
			lo = math.min(sx * 18, sx * 112),
			hi = math.max(sx * 18, sx * 112),
		},
		look,
		yard
	)
	-- a transformer box closes the corner between the two houses
	B_(
		"Transformer",
		113,
		0,
		126,
		123,
		7,
		139,
		Color3.fromRGB(170, 160, 120),
		Enum.Material.Brick,
		yard
	)
	claim(sx * 112, sz * 124, sx * 124, sz * 140)
	-- the driveways along the facades (asphalt) and sidewalks at the doors
	B_("Driveway", 104, -0.4, 18, 116, 0.12, 116, ASPHALT, Enum.Material.Asphalt, yard)
	B_("Driveway", 18, -0.4, 104, 104, 0.12, 116, ASPHALT, Enum.Material.Asphalt, yard)
	textured(B_("DoorWalk", 116, -0.4, 18, 124, 0.4, 124, nil, nil, yard), "px_smooth_stone")
	textured(B_("DoorWalk", 18, -0.4, 116, 116, 0.4, 124, nil, nil, yard), "px_smooth_stone")
	-- cars parked on the driveways
	for _, v in ipairs({ 34, 52, 88 }) do
		if rng:NextNumber() < 0.8 then
			car(
				Y(110, 0.12, v) * CFrame.Angles(0, if rng:NextNumber() < 0.5 then 0 else math.pi, 0),
				yard
			)
		end
	end
	for _, u in ipairs({ 30, 70, 92 }) do
		if rng:NextNumber() < 0.7 then
			car(
				Y(u, 0.12, 110)
					* CFrame.Angles(
						0,
						math.pi / 2 + (if rng:NextNumber() < 0.5 then 0 else math.pi),
						0
					),
				yard
			)
		end
	end
	-- the point: the pad of ore and the beacon on the street side of it
	local cx, cz = sx * PAD_UV, sz * PAD_UV
	pad(pt, cx, cz, yard)
	beacon(pt, cx, sz * (PAD_UV - PAD_HALF - 9), yard)
	-- a paved path from the street corner to the beacon
	textured(
		B_("Path", 12, -0.4, 52, 66, 0.15, 58, nil, nil, yard),
		"px_stone_bricks",
		Color3.fromRGB(200, 195, 185)
	)
	textured(
		B_("Path", 64, -0.4, 12, 70, 0.15, 52, nil, nil, yard),
		"px_stone_bricks",
		Color3.fromRGB(200, 195, 185)
	)
	claim(sx * 12, sz * 52, sx * 66, sz * 58)
	claim(sx * 64, sz * 12, sx * 70, sz * 52)
	claim(sx * 104, sz * 18, sx * 124, sz * 124)
	claim(sx * 18, sz * 104, sx * 104, sz * 124)
	-- the yard's furniture
	playground(Y, B_, sx, sz, yard)
	garages(B_, sx, sz, yard)
	laundry(B_, yard)
	claim(sx * 18, sz * 28, sx * 26, sz * 48)
	dominoTable(Y, yard)
	claim(sx * 46, sz * 35, sx * 54, sz * 45)
	pullUpBar(B_, yard)
	claim(sx * 56, sz * 28, sx * 60, sz * 38)
	-- bins by the street (rats live here), more bags by the garages
	for k = 0, 2 do
		local base = Y(34 + k * 4.6, 0.15, 22)
		bin(base, yard)
	end
	for k = 1, 4 do
		trashBag(
			Y(46 + rng:NextNumber(-3, 3), 0.8, 26 + rng:NextNumber(-2, 2))
				* CFrame.Angles(0, k, 0.1),
			yard
		)
	end
	claim(sx * 31, sz * 19, sx * 50, sz * 29)
	mobSpawn(sx * 40, sz * 30, 6)
	mobSpawn(sx * 88, sz * 34, 6)
	mobSpawn(sx * 96, sz * 80, 8)
	-- lamps
	for _, l in ipairs({ { 92, 56 }, { 96, 96 }, { 40, 49 }, { 62, 100 } }) do
		lamp(sx * l[1], sz * l[2], yard)
		claim(sx * l[1] - 1, sz * l[2] - 1, sx * l[1] + 1, sz * l[2] + 1)
	end
	-- trees on what is left of the grass
	local planted = 0
	for _ = 1, 140 do
		if planted >= 16 then
			break
		end
		local u, v = rng:NextNumber(18, 104), rng:NextNumber(18, 104)
		local x, z = sx * u, sz * v
		if not claimed(x, z, 4) then
			planted += 1
			claim(x - 1, z - 1, x + 1, z + 1)
			if rng:NextNumber() < 0.5 then
				birch(x, z, rng:NextNumber(0.9, 1.3), yard)
			else
				poplar(x, z, rng:NextNumber(1, 1.4), yard)
			end
		end
	end
end

-- street lamps along the cross
for k = -HALF + 20, HALF - 20, 30 do
	if math.abs(k) > 32 then
		lamp(10, k, square)
		lamp(k, 10, square)
	end
end

-- ================================================================ evening light, the edge
local air = Instance.new("Model")
air.Name = "IndoorLighting"
air.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
air.Parent = root
local volume = decor(
	part("EveningAir", Vector3.new(2 * HALF + 40, 300, 2 * HALF + 40), at(0, 100, 0), nil, nil, air)
)
volume.Transparency = 1
volume:SetAttribute("Ambient", Color3.fromRGB(135, 125, 120))
volume:SetAttribute("Exposure", 0)
volume:SetAttribute("Haze", 0.12)
volume:SetAttribute("ClockTime", 17.2) -- a summer evening: the sun low over the roofs
volume:SetAttribute("Brightness", 2)
volume:SetAttribute("AtmosphereColor", Color3.fromRGB(200, 170, 140))
volume:SetAttribute("AtmosphereDecay", Color3.fromRGB(120, 100, 110))
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
-- the pads become mines only now, at their final height
for _, anchor in ipairs(anchors) do
	CollectionService:AddTag(anchor, "MineAnchor")
end

local total = #root:GetDescendants()
print(("[build-warzone] built: %d instances"):format(total))
return ("built %d instances"):format(total)
