--!strict
-- Builds the Тюрьма (spawn) location base: ground, perimeter wall, path network, spawn plaza with the
-- fountain, teleporter, mine pits, teleport spots. Layout follows the Телепортатор map (owner screenshot
-- #74, wiki/in-game-wiki/JOBS-CASES-SPAWN.md): spawn + fountain in the centre, Шахта north, Малая шахта
-- south, Баня NW, Рынок NE, Спальня SW, Столовая E, Тренер SE, ring road connecting everything.
-- Run in Studio (Edit) via scripts/studio-loader.luau. Replaces Workspace.Prison, Mine_* and terrain.
-- Order: build-textures → build-prison → build-buildings → build-npcs → decorate-prison.
-- Water is Terrain water (swimmable); basins are cut out of the ground slabs like the mine pits.

local CollectionService = game:GetService("CollectionService")
local textures = require(game:GetService("ReplicatedStorage").Shared.Config.textures)

for _, name in ipairs({ "Prison", "Baseplate", "Yard" }) do
	local old = workspace:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
for _, f in ipairs(workspace:GetChildren()) do
	if f.Name:match("^Mine_") then
		f:Destroy()
	end
end
workspace.Terrain:Clear()

local root = Instance.new("Folder")
root.Name = "Prison"
root.Parent = workspace

local B = 4 -- block size in studs
local HALF = 200 -- map half-size
local STONE = Color3.fromRGB(96, 96, 100)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(120, 85, 50)
local GRASS = Color3.fromRGB(80, 130, 60)
local PATH = Color3.fromRGB(150, 140, 125)
local LAMP = Color3.fromRGB(255, 215, 130)

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
	p.Parent = parent or root
	return p
end
local function textured(p: Part, variant: string): Part
	p.Material = Enum.Material.Plastic
	p.MaterialVariant = variant
	p.Color = Color3.new(1, 1, 1)
	return p
end

-- World labels: 60 % smaller than the first version (owner 21.10).
local function sign(target: BasePart, text: string, offset: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(88, 16)
	gui.StudsOffset = Vector3.new(0, (offset or target.Size.Y / 2) + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 140
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.fromRGB(255, 190, 60)
	label.TextStrokeTransparency = 0.2
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
end

local function water(cx: number, y0: number, cz: number, w: number, h: number, d: number)
	-- Terrain water voxels are 4 studs: callers pass grid-aligned boxes.
	workspace.Terrain:FillBlock(
		CFrame.new(cx, y0 + h / 2, cz),
		Vector3.new(w, h, d),
		Enum.Material.Water
	)
end

-- ---------------------------------------------------------------- pits and ground holes
-- opening = side of the rim fence left open (towards the spawn).
local pits = {
	{
		id = "prison",
		cx = 0,
		cz = -120,
		sx = 32,
		sy = 12,
		sz = 32,
		label = "Шахта",
		opening = "S",
	},
	{
		id = "prison_small",
		cx = 0,
		cz = 120,
		sx = 16,
		sy = 8,
		sz = 16,
		label = "Малая шахта",
		opening = "N",
	},
}
type Rect = { x0: number, x1: number, z0: number, z1: number }
local holes: { Rect } = {}
for _, m in ipairs(pits) do
	local w, d = m.sx * B, m.sz * B
	table.insert(holes, {
		x0 = m.cx - w / 2 - 2 * B,
		x1 = m.cx + w / 2 + 2 * B,
		z0 = m.cz - d / 2 - 2 * B,
		z1 = m.cz + d / 2 + 2 * B,
	})
end
-- Sunken water basins (grid-aligned, 4 studs deep below ground level 0): bath pools, pond.
local basins = {
	{ name = "BathPoolHot", cx = -136, cz = -116, w = 16, d = 12 },
	{ name = "BathPoolWarm", cx = -116, cz = -116, w = 16, d = 12 },
	{ name = "BathPoolCold", cx = -98, cz = -118, w = 8, d = 8 },
	{ name = "Pond", cx = -92, cz = 168, w = 32, d = 20 },
}
for _, b in ipairs(basins) do
	table.insert(
		holes,
		{ x0 = b.cx - b.w / 2, x1 = b.cx + b.w / 2, z0 = b.cz - b.d / 2, z1 = b.cz + b.d / 2 }
	)
end

-- Ground as slabs around the holes: split the map into column strips and cut each strip by the holes.
local function groundSlab(x0: number, x1: number, z0: number, z1: number)
	if x1 - x0 < 1 or z1 - z0 < 1 then
		return
	end
	part(
		"Ground",
		Vector3.new(x1 - x0, B, z1 - z0),
		CFrame.new((x0 + x1) / 2, -B / 2, (z0 + z1) / 2),
		GRASS,
		Enum.Material.Grass
	)
end
local xs = { -HALF, HALF }
for _, h in ipairs(holes) do
	table.insert(xs, h.x0)
	table.insert(xs, h.x1)
end
table.sort(xs)
for i = 1, #xs - 1 do
	local x0, x1 = xs[i], xs[i + 1]
	if x1 - x0 >= 1 then
		local cuts = { -HALF, HALF }
		for _, h in ipairs(holes) do
			if h.x0 <= x0 and h.x1 >= x1 then
				table.insert(cuts, h.z0)
				table.insert(cuts, h.z1)
			end
		end
		table.sort(cuts)
		for j = 1, #cuts - 1 do
			local z0, z1 = cuts[j], cuts[j + 1]
			local inside = false
			for _, h in ipairs(holes) do
				if h.x0 <= x0 and h.x1 >= x1 and h.z0 <= z0 and h.z1 >= z1 then
					inside = true
				end
			end
			if not inside then
				groundSlab(x0, x1, z0, z1)
			end
		end
	end
end
-- Basin floors/walls and water
for _, b in ipairs(basins) do
	part(
		b.name .. "Floor",
		Vector3.new(b.w + 2, 1, b.d + 2),
		CFrame.new(b.cx, -4.5, b.cz),
		DARK,
		Enum.Material.Slate
	)
	for _, s in ipairs({
		{ Vector3.new(b.w + 2, 4, 1), CFrame.new(b.cx, -2, b.cz - b.d / 2 - 0.5) },
		{ Vector3.new(b.w + 2, 4, 1), CFrame.new(b.cx, -2, b.cz + b.d / 2 + 0.5) },
		{ Vector3.new(1, 4, b.d + 2), CFrame.new(b.cx - b.w / 2 - 0.5, -2, b.cz) },
		{ Vector3.new(1, 4, b.d + 2), CFrame.new(b.cx + b.w / 2 + 0.5, -2, b.cz) },
	}) do
		local wall = part(b.name .. "Wall", s[1], s[2], STONE, Enum.Material.Plastic)
		textured(wall, if b.name == "Pond" then "px_dirt" else "px_cobblestone")
	end
	water(b.cx, -4, b.cz, b.w, 4, b.d)
end

-- ---------------------------------------------------------------- perimeter wall
for _, d in ipairs({ { 0, -HALF }, { 0, HALF } }) do
	part(
		"Wall",
		Vector3.new(2 * HALF, 28, B),
		CFrame.new(d[1], 14, d[2]),
		DARK,
		Enum.Material.Brick
	)
end
for _, d in ipairs({ { -HALF, 0 }, { HALF, 0 } }) do
	part(
		"Wall",
		Vector3.new(B, 28, 2 * HALF),
		CFrame.new(d[1], 14, d[2]),
		DARK,
		Enum.Material.Brick
	)
end

-- ---------------------------------------------------------------- paths
-- Every segment is axis-aligned {name, x0, z0, x1, z1}; width 12. Decoration reads parts named "Path*"
-- to keep props off the roads. Ring road around the plaza, spokes to the mines, stubs to every door.
local PATH_W = 12
local segments = {
	-- ring
	{ "PathRingN", -120, -40, 100, -40 },
	{ "PathRingS", -120, 62, 100, 62 },
	{ "PathRingW", -120, -86, -120, 86 }, -- Баня S door ↔ Спальня N door
	{ "PathRingE", 100, -86, 100, 62 },
	-- spokes from the plaza
	{ "PathSpokeN", 0, -46, 0, -40 }, -- plaza edge → ring → Шахта entrance (opening S at z = -48)
	{ "PathSpokeS", 0, 45, 0, 74 }, -- plaza edge → ring → Малая шахта entrance (opening N at z = 76)
	{ "PathSpokeE", 45, 0, 100, 0 },
	{ "PathSpokeW", -120, 0, -45, 0 },
	-- stubs to doors
	{ "PathMarket", 100, -86, 120, -86 }, -- Рынок S door at (120, -90)
	{ "PathCanteen", 100, 10, 118, 10 }, -- Столовая W door at (120, 10)
	{ "PathTrainer", 60, 62, 60, 132 }, -- down to the training yard
	{ "PathTrainer2", 60, 132, 68, 132 }, -- Тренер W entrance at (70, 132)
	{ "PathPond", -120, 86, -120, 150 }, -- Спальня → pond
	{ "PathPond2", -120, 150, -110, 150 },
	{ "PathGate", 0, -196, 0, -192 }, -- gate stub (decorative)
}
for _, s in ipairs(segments) do
	local name, x0, z0, x1, z1 = s[1], s[2], s[3], s[4], s[5]
	local sx = math.abs(x1 - x0) + PATH_W
	local sz = math.abs(z1 - z0) + PATH_W
	local p = part(
		name,
		Vector3.new(sx, 0.4, sz),
		CFrame.new((x0 + x1) / 2, 0.2, (z0 + z1) / 2),
		PATH,
		Enum.Material.Concrete
	)
	textured(p, "px_concrete_floor")
	p.Color = Color3.fromRGB(215, 205, 190)
end
-- cobble edging along the ring and spokes (visual only, no collision)
for _, s in ipairs(segments) do
	local name, x0, z0, x1, z1 = s[1], s[2], s[3], s[4], s[5]
	if name:match("^PathRing") or name:match("^PathSpoke") then
		local horizontal = z0 == z1
		local len = (if horizontal then math.abs(x1 - x0) else math.abs(z1 - z0)) + PATH_W
		for _, side in ipairs({ -1, 1 }) do
			local off = side * (PATH_W / 2 + 0.6)
			local e = part(
				"PathEdge",
				if horizontal then Vector3.new(len, 0.5, 1.2) else Vector3.new(1.2, 0.5, len),
				if horizontal
					then CFrame.new((x0 + x1) / 2, 0.25, z0 + off)
					else CFrame.new(x0 + off, 0.25, (z0 + z1) / 2),
				STONE
			)
			textured(e, "px_cobblestone")
			e.CanCollide = false
		end
	end
end

-- ---------------------------------------------------------------- spawn plaza (90 × 90) with the fountain
local PLAZA = 90
local plaza = part(
	"Plaza",
	Vector3.new(PLAZA, 0.6, PLAZA),
	CFrame.new(0, 0.3, 0),
	Color3.fromRGB(170, 160, 145)
)
textured(plaza, "px_concrete_floor")
plaza.Color = Color3.fromRGB(225, 215, 200)
-- checker inlay of cobblestone tiles, leaving the fountain square and the four entrances clear
for ix = -5, 5 do
	for iz = -5, 5 do
		local x, z = ix * 8, iz * 8
		if
			(ix + iz) % 2 == 0
			and (math.abs(x) > 20 or math.abs(z) > 20)
			and not (math.abs(x) <= 8 or math.abs(z) <= 8)
		then
			textured(
				part("PlazaTile", Vector3.new(7.6, 0.2, 7.6), CFrame.new(x, 0.7, z), STONE),
				"px_cobblestone"
			)
		end
	end
end
-- low wall + hedge around the plaza with gaps at the four spokes
for _, side in ipairs({
	{ 0, -PLAZA / 2, true },
	{ 0, PLAZA / 2, true },
	{ -PLAZA / 2, 0, false },
	{ PLAZA / 2, 0, false },
}) do
	for _, half in ipairs({ -1, 1 }) do
		local len = PLAZA / 2 - 10
		local mid = half * (10 + len / 2)
		local size = if side[3] then Vector3.new(len, 1.2, 1.5) else Vector3.new(1.5, 1.2, len)
		local cf = if side[3] then CFrame.new(mid, 1.2, side[2]) else CFrame.new(side[1], 1.2, mid)
		textured(part("PlazaWall", size, cf, STONE), "px_cobblestone")
		part(
			"PlazaHedge",
			if side[3] then Vector3.new(len, 2, 1.6) else Vector3.new(1.6, 2, len),
			cf * CFrame.new(0, 1.6, 0),
			Color3.fromRGB(70, 125, 55),
			Enum.Material.Grass
		)
	end
end
-- Fountain: three square tiers with terrain water, miner statue on top, jets.
for _, s in ipairs({
	{ Vector3.new(32, 5, 1.5), CFrame.new(0, 2.5, -15.25) },
	{ Vector3.new(32, 5, 1.5), CFrame.new(0, 2.5, 15.25) },
	{ Vector3.new(1.5, 5, 29), CFrame.new(-15.25, 2.5, 0) }, -- 29: no overlap with the N/S rims (z-fighting)
	{ Vector3.new(1.5, 5, 29), CFrame.new(15.25, 2.5, 0) },
}) do
	textured(part("FountainRim", s[1], s[2], STONE), "px_cobblestone")
end
part(
	"FountainBasin",
	Vector3.new(29, 0.4, 29),
	CFrame.new(0, 0.8, 0),
	Color3.fromRGB(60, 110, 140),
	Enum.Material.Marble
)
for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
	textured(
		part(
			"FountainPost",
			Vector3.new(2.5, 6.5, 2.5),
			CFrame.new(c[1] * 15.25, 3.25, c[2] * 15.25),
			STONE
		),
		"px_stone"
	)
	local lamp = part(
		"FountainLamp",
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(c[1] * 15.25, 7.2, c[2] * 15.25),
		LAMP,
		Enum.Material.Neon
	)
	local l = Instance.new("PointLight")
	l.Color = LAMP
	l.Range = 20
	l.Parent = lamp
end
water(0, 0, 0, 28, 4, 28) -- surface at y 4, rim top at 5
-- second tier
for _, s in ipairs({
	{ Vector3.new(16, 5, 1.2), CFrame.new(0, 6.5, -7.4) },
	{ Vector3.new(16, 5, 1.2), CFrame.new(0, 6.5, 7.4) },
	{ Vector3.new(1.2, 5, 13.6), CFrame.new(-7.4, 6.5, 0) },
	{ Vector3.new(1.2, 5, 13.6), CFrame.new(7.4, 6.5, 0) },
}) do
	textured(part("FountainTier2", s[1], s[2], STONE), "px_stone")
end
part(
	"FountainTier2Base",
	Vector3.new(16, 4.4, 16),
	CFrame.new(0, 4.2, 0),
	STONE,
	Enum.Material.Slate
)
water(0, 4, 0, 12, 4, 12) -- surface at y 8, tier rim top at 9
-- third tier
local t3 =
	textured(part("FountainTier3", Vector3.new(7, 4, 7), CFrame.new(0, 10, 0), STONE), "px_stone")
part("FountainBowl", Vector3.new(9, 0.8, 9), CFrame.new(0, 12.2, 0), STONE, Enum.Material.Slate)
local bowlWater = part(
	"FountainBowlWater",
	Vector3.new(8, 0.5, 8),
	CFrame.new(0, 12.7, 0),
	Color3.fromRGB(90, 160, 220),
	Enum.Material.Glass
)
bowlWater.Transparency = 0.4
bowlWater.CanCollide = false
-- statue of a miner
local s = CFrame.new(0, 16.5, 0)
part("StatuePlinth", Vector3.new(3, 1, 3), CFrame.new(0, 13.5, 0), STONE, Enum.Material.Slate)
part(
	"StatueLegs",
	Vector3.new(2, 2.5, 1.2),
	s * CFrame.new(0, -1.25, 0),
	STONE,
	Enum.Material.Slate
)
part("StatueBody", Vector3.new(2.2, 3, 1.3), s * CFrame.new(0, 1.5, 0), STONE, Enum.Material.Slate)
part(
	"StatueHead",
	Vector3.new(1.2, 1.2, 1.2),
	s * CFrame.new(0, 3.6, 0),
	STONE,
	Enum.Material.Slate
)
part(
	"StatueHelmet",
	Vector3.new(1.4, 0.5, 1.4),
	s * CFrame.new(0, 4.3, 0),
	STONE,
	Enum.Material.Slate
)
part(
	"StatueArm",
	Vector3.new(0.7, 2.6, 0.7),
	s * CFrame.new(1.5, 2.4, 0) * CFrame.Angles(0, 0, -0.9),
	STONE,
	Enum.Material.Slate
)
part(
	"StatueArm",
	Vector3.new(0.7, 2.4, 0.7),
	s * CFrame.new(-1.4, 1.2, 0),
	STONE,
	Enum.Material.Slate
)
part(
	"StatuePick",
	Vector3.new(0.3, 4, 0.3),
	s * CFrame.new(2.7, 3.9, 0) * CFrame.Angles(0, 0, 0.5),
	DARK,
	Enum.Material.Slate
)
part(
	"StatuePickHead",
	Vector3.new(2.4, 0.5, 0.5),
	s * CFrame.new(3.6, 5.7, 0) * CFrame.Angles(0, 0, 0.5),
	DARK,
	Enum.Material.Slate
)
-- jets: from the bowl outwards and from the second tier corners
local function jet(cf: CFrame, rate: number, speed: number, spread: number)
	local j = part("Jet", Vector3.new(0.5, 0.5, 0.5), cf, STONE, Enum.Material.Slate)
	j.CanCollide = false
	j.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(Color3.fromRGB(190, 225, 255))
	e.Rate = rate
	e.Size = NumberSequence.new(0.4)
	e.Speed = NumberRange.new(speed, speed + 2)
	e.Lifetime = NumberRange.new(1.4)
	e.SpreadAngle = Vector2.new(spread, spread)
	e.Acceleration = Vector3.new(0, -18, 0)
	e.Transparency = NumberSequence.new(0.25)
	e.LightEmission = 0.3
	e.Parent = j
end
jet(CFrame.new(0, 13.2, 0), 60, 14, 25)
for i = 1, 8 do
	local a = i * math.pi / 4
	jet(
		CFrame.new(math.cos(a) * 3.6, 13, math.sin(a) * 3.6)
			* CFrame.Angles(0, -a, 0)
			* CFrame.Angles(0, 0, -1.1),
		10,
		8,
		6
	)
end
for _, c in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
	jet(CFrame.new(c[1] * 6, 9.2, c[2] * 6), 12, 7, 15)
end
sign(t3, "Спавн", 10)

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(8, 1, 8)
-- [владелец 21.10] players appear by the big mine (north edge of the plaza), facing it (−Z)
spawn.CFrame = CFrame.new(0, 0.8, -40)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = root

-- Teleport spots (LocationSpawn + Spot attribute; LocationService picks them by (LocationId, Spot)).
local function spot(id: string, x: number, z: number)
	local p = part("LocationSpawn_" .. id, Vector3.new(4, 1, 4), CFrame.new(x, 1, z), STONE)
	p.Transparency = 1
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p:SetAttribute("LocationId", "prison")
	p:SetAttribute("Spot", id)
	CollectionService:AddTag(p, "LocationSpawn")
end
spot("spawn", 0, 24)
spot("mine", 0, -40)
spot("small_mine", 0, 70)
spot("market", 120, -80)
spot("canteen", 112, 10)
spot("bedroom", -120, 80)
spot("bath", -120, -80)
spot("trainer", 62, 132)

-- Teleporter board on the south edge of the plaza (facing the fountain)
local teleporter =
	textured(part("Teleporter", Vector3.new(10, 6, 1), CFrame.new(0, 4.6, 40), WOOD), "px_planks")
part("TeleporterPost", Vector3.new(1, 5, 1), CFrame.new(-4.2, 2.5, 40), WOOD, Enum.Material.Wood)
part("TeleporterPost", Vector3.new(1, 5, 1), CFrame.new(4.2, 2.5, 40), WOOD, Enum.Material.Wood)
part(
	"TeleporterRoof",
	Vector3.new(12, 0.5, 3),
	CFrame.new(0, 7.9, 40),
	DARK,
	Enum.Material.WoodPlanks
)
local tgui = Instance.new("SurfaceGui")
tgui.Face = Enum.NormalId.Back
tgui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
tgui.PixelsPerStud = 40
tgui.Parent = teleporter
local tlabel = Instance.new("TextLabel")
tlabel.Size = UDim2.fromScale(1, 0.3)
tlabel.BackgroundTransparency = 1
tlabel.TextColor3 = Color3.fromRGB(255, 190, 60)
tlabel.TextScaled = true
tlabel.Font = Enum.Font.Code
tlabel.Text = "ТЕЛЕПОРТАТОР"
tlabel.Parent = tgui
local tmap = Instance.new("ImageLabel")
tmap.Size = UDim2.fromScale(0.8, 0.65)
tmap.Position = UDim2.fromScale(0.1, 0.32)
tmap.BackgroundColor3 = Color3.fromRGB(60, 90, 50)
tmap.BorderSizePixel = 0
tmap.Image = "rbxassetid://121878160343691" -- preview of Тюрьма
tmap.ScaleType = Enum.ScaleType.Crop
tmap.Parent = tgui
CollectionService:AddTag(teleporter, "Teleporter")
sign(teleporter, "Телепортатор")

-- Buildings: scripts/build-buildings.luau (run after this script).

-- ---------------------------------------------------------------- mine pits
for _, m in ipairs(pits) do
	local w, h, d = m.sx * B, m.sy * B, m.sz * B
	local cx, cz = m.cx, m.cz
	part(
		"PitFloor",
		Vector3.new(w + 4 * B, B, d + 4 * B),
		CFrame.new(cx, -h - B / 2, cz),
		DARK,
		Enum.Material.Slate
	)
	part(
		"PitWallN",
		Vector3.new(w + 4 * B, h, 2 * B),
		CFrame.new(cx, -h / 2, cz - d / 2 - B),
		DARK,
		Enum.Material.Slate
	)
	part(
		"PitWallS",
		Vector3.new(w + 4 * B, h, 2 * B),
		CFrame.new(cx, -h / 2, cz + d / 2 + B),
		DARK,
		Enum.Material.Slate
	)
	part(
		"PitWallW",
		Vector3.new(2 * B, h, d),
		CFrame.new(cx - w / 2 - B, -h / 2, cz),
		DARK,
		Enum.Material.Slate
	)
	part(
		"PitWallE",
		Vector3.new(2 * B, h, d),
		CFrame.new(cx + w / 2 + B, -h / 2, cz),
		DARK,
		Enum.Material.Slate
	)
	-- rim fence at ground level, open towards the spawn
	local rims = {
		N = { Vector3.new(w + 4 * B, 3, 1), CFrame.new(cx, 1.5, cz - d / 2 - 2 * B) },
		S = { Vector3.new(w + 4 * B, 3, 1), CFrame.new(cx, 1.5, cz + d / 2 + 2 * B) },
		W = { Vector3.new(1, 3, d + 4 * B), CFrame.new(cx - w / 2 - 2 * B, 1.5, cz) },
		E = { Vector3.new(1, 3, d + 4 * B), CFrame.new(cx + w / 2 + 2 * B, 1.5, cz) },
	}
	for side, r in pairs(rims) do
		if side ~= m.opening then
			part("PitRim" .. side, r[1], r[2], STONE, Enum.Material.Metal)
		else
			-- on the open side keep two short rails leaving a 16-stud gate in the middle
			local len = (if side == "N" or side == "S" then w + 4 * B else d + 4 * B) / 2 - 8
			for _, half in ipairs({ -1, 1 }) do
				local off = half * (8 + len / 2)
				local size = if side == "N" or side == "S"
					then Vector3.new(len, 3, 1)
					else Vector3.new(1, 3, len)
				local cf = if side == "N" or side == "S"
					then r[2] * CFrame.new(off, 0, 0)
					else r[2] * CFrame.new(0, 0, off)
				part("PitRim" .. side, size, cf, STONE, Enum.Material.Metal)
			end
		end
	end
	local anchor =
		part("MineAnchor_" .. m.id, Vector3.new(w, 0.2, d), CFrame.new(cx, -0.1, cz), DARK)
	anchor:SetAttribute("LocationId", "prison")
	anchor:SetAttribute("MineId", m.id)
	anchor:SetAttribute("Size", Vector3.new(m.sx, m.sy, m.sz))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, m.label, 10)
	-- [владелец] four Minecraft-style ladders, 4 blocks (16 studs) wide, centred on every wall, floor
	-- to rim: a transparent plate carrying the ladder texture (one sprite per block) on the wall side of
	-- the shaft, plus an invisible TrussPart behind it that the humanoid actually climbs. MineService
	-- keeps the 4-wide shaft in front of each ladder free of blocks forever.
	local LADDER_W = 4 * B
	local ladderTexture = textures and textures.textures and textures.textures.ladder
	for _, side in ipairs({
		{ cx, cz - d / 2, Vector3.new(0, 0, 1) },
		{ cx, cz + d / 2, Vector3.new(0, 0, -1) },
		{ cx - w / 2, cz, Vector3.new(1, 0, 0) },
		{ cx + w / 2, cz, Vector3.new(-1, 0, 0) },
	}) do
		local inward = side[3] -- from the wall into the pit
		local along = Vector3.new(math.abs(inward.Z), 0, math.abs(inward.X)) -- ladder width direction
		-- Roblox climbs only 2×2 trusses: the 4-block ladder is eight of them side by side, invisible
		for k = 0, LADDER_W / 2 - 1 do
			local offset = along * (-LADDER_W / 2 + 1 + k * 2)
			local truss = Instance.new("TrussPart")
			truss.Name = "Ladder"
			truss.Size = Vector3.new(2, h, 2) -- top flush with the ground, like a Minecraft ladder
			truss.CFrame = CFrame.new(Vector3.new(side[1], -h / 2, side[2]) - inward * 0.6 + offset) -- 1.6 studs sunk into the wall: only 0.4 stud protrudes, nobody can stand on the top
			truss.Anchored = true
			truss.Transparency = 1
			truss.Parent = root
		end
		local plate = Instance.new("Part")
		plate.Name = "LadderFace"
		plate.Size = Vector3.new(
			LADDER_W * along.X + 0.2 * math.abs(inward.X),
			h,
			LADDER_W * along.Z + 0.2 * math.abs(inward.Z)
		)
		plate.CFrame = CFrame.new(Vector3.new(side[1], -h / 2, side[2]) + inward * 0.15) -- flush against the pit wall, like a Minecraft ladder on its block [владелец]
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
end

return "[build-prison] done, parts: " .. #root:GetDescendants()
