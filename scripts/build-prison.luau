--!strict
-- Builds the Тюрьма (spawn) location blockout, following the Телепортатор map
-- (wiki/in-game-wiki/JOBS-CASES-SPAWN.md): spawn with a fountain in the centre, Шахта north,
-- Малая шахта south, Баня NW, Рынок NE, Спальня SW, Столовая E, Задания under the mine, Тренер SE,
-- perimeter wall. Spacious layout (400×400 studs) with room for decoration passes.
-- Run in Studio (Command Bar or MCP execute_luau). Replaces Workspace.Prison and Mine_* folders.
-- The mines themselves are generated at runtime by MineService from the MineAnchor parts.

local CollectionService = game:GetService("CollectionService")

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
local WATER = Color3.fromRGB(60, 120, 200)

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

local function sign(target: BasePart, text: string, offset: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, (offset or target.Size.Y / 2) + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 200
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

-- Mine pits (x0, x1, z0, z1 of the hole incl. 2-block rim) are carved out of the ground slabs.
local pits = {
	{ id = "prison", cx = 0, cz = -120, sx = 32, sy = 12, sz = 32, label = "Шахта" },
	{
		id = "prison_small",
		cx = 0,
		cz = 120,
		sx = 16,
		sy = 8,
		sz = 16,
		label = "Малая шахта",
	},
}
local holes: { { x0: number, x1: number, z0: number, z1: number } } = {}
for _, m in ipairs(pits) do
	local w, d = m.sx * B, m.sz * B
	table.insert(holes, {
		x0 = m.cx - w / 2 - 2 * B,
		x1 = m.cx + w / 2 + 2 * B,
		z0 = m.cz - d / 2 - 2 * B,
		z1 = m.cz + d / 2 + 2 * B,
	})
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

-- Perimeter wall
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

-- Paths (the N–S path is cut where it would cover a mine hole)
local segs = { -HALF + 10 }
for _, h in ipairs(holes) do
	table.insert(segs, h.z0)
	table.insert(segs, h.z1)
end
table.insert(segs, HALF - 10)
table.sort(segs)
for i = 1, #segs - 1, 2 do
	local z0, z1 = segs[i], segs[i + 1]
	if z1 - z0 > 2 then
		part(
			"PathNS",
			Vector3.new(14, 0.4, z1 - z0),
			CFrame.new(0, 0.2, (z0 + z1) / 2),
			PATH,
			Enum.Material.Concrete
		)
	end
end
part(
	"PathEW",
	Vector3.new(2 * HALF - 20, 0.4, 14),
	CFrame.new(0, 0.2, 0),
	PATH,
	Enum.Material.Concrete
)

-- Spawn plaza with fountain
part(
	"Plaza",
	Vector3.new(56, 0.6, 56),
	CFrame.new(0, 0.3, 0),
	Color3.fromRGB(170, 160, 145),
	Enum.Material.Concrete
)
local fountain =
	part("Fountain", Vector3.new(12, 3, 12), CFrame.new(0, 1.5, 0), STONE, Enum.Material.Slate)
part("FountainWater", Vector3.new(10, 1, 10), CFrame.new(0, 3.2, 0), WATER, Enum.Material.Glass).Transparency =
	0.4
part("FountainPillar", Vector3.new(2, 6, 2), CFrame.new(0, 6, 0), STONE, Enum.Material.Slate)
sign(fountain, "Спавн", 8)
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(0, 0.8, 16)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = root

local arrival = part("LocationSpawn", Vector3.new(4, 1, 4), CFrame.new(0, 1, 16), STONE)
arrival.Transparency = 1
arrival.CanCollide = false
arrival.CanTouch = false
arrival.CanQuery = false
arrival:SetAttribute("LocationId", "prison")
CollectionService:AddTag(arrival, "LocationSpawn")

local teleporter =
	part("Teleporter", Vector3.new(10, 6, 1), CFrame.new(0, 4, 30), WOOD, Enum.Material.Wood)
part("TeleporterPost", Vector3.new(1, 4, 1), CFrame.new(-4, 2, 30), WOOD, Enum.Material.Wood)
part("TeleporterPost", Vector3.new(1, 4, 1), CFrame.new(4, 2, 30), WOOD, Enum.Material.Wood)
CollectionService:AddTag(teleporter, "Teleporter")
sign(teleporter, "Телепортатор")

-- NPCs around the plaza
local function npc(name: string, tag: string, cf: CFrame, text: string): Part
	local p = part(name, Vector3.new(3, 7, 3), cf, WOOD, Enum.Material.Wood)
	CollectionService:AddTag(p, tag)
	sign(p, text)
	return p
end
npc("Buyer", "SellPoint", CFrame.new(-22, 3.5, 12), "Скупщик блоков")
npc("ItemShop", "ItemShop", CFrame.new(22, 3.5, 12), "Продавец предметов")
npc("FoodShop", "FoodShop", CFrame.new(22, 3.5, -12), "Продавец еды")

local ordinaryCase =
	part("OrdinaryCase", Vector3.new(5, 5, 4), CFrame.new(-22, 3, -12), WOOD, Enum.Material.Wood)
CollectionService:AddTag(ordinaryCase, "OrdinaryCase")
sign(ordinaryCase, "Обычный кейс")

-- Buildings (blockout with signs; decoration pass comes later)
local function building(
	name: string,
	size: Vector3,
	pos: Vector3,
	text: string,
	open: boolean?
): Part
	-- Restore buildings need accessible interiors: keep the blockout footprint as a roof.
	local b = part(
		name,
		if open then Vector3.new(size.X, 1, size.Z) else size,
		CFrame.new(pos.X, if open then size.Y else size.Y / 2, pos.Z),
		STONE,
		Enum.Material.Brick
	)
	if open then
		for _, corner in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
			part(
				name .. "Pillar",
				Vector3.new(2, size.Y, 2),
				CFrame.new(
					pos.X + corner[1] * (size.X / 2 - 1),
					size.Y / 2,
					pos.Z + corner[2] * (size.Z / 2 - 1)
				),
				STONE,
				Enum.Material.Brick,
				b
			)
		end
	end
	sign(b, text, if open then 1 else nil)
	return b
end
local bath = building("Bath", Vector3.new(56, 16, 36), Vector3.new(-120, 0, -110), "Баня", true)
building("Market", Vector3.new(56, 16, 36), Vector3.new(120, 0, -110), "Рынок")
local bedroom =
	building("Bedroom", Vector3.new(56, 16, 36), Vector3.new(-120, 0, 110), "Спальня", true)
building("Canteen", Vector3.new(36, 16, 80), Vector3.new(140, 0, 10), "Столовая")
building("Quests", Vector3.new(28, 12, 18), Vector3.new(0, 0, -52), "Задания")
building("Trainer", Vector3.new(30, 12, 24), Vector3.new(90, 0, 130), "Тренер")

local bathWater = part(
	"BathWater",
	Vector3.new(12, 1, 10),
	CFrame.new(-120, 0.5, -110),
	WATER,
	Enum.Material.Glass,
	bath
)
bathWater.Transparency = 0.4
bathWater.CanCollide = false
CollectionService:AddTag(bathWater, "RestoreHygiene")
local bed = part(
	"Bed",
	Vector3.new(5, 2, 9),
	CFrame.new(-120, 1, 110),
	WATER,
	Enum.Material.Fabric,
	bedroom
)
CollectionService:AddTag(bed, "RestoreSleep")
local toilet = part(
	"Toilet",
	Vector3.new(3, 3, 3),
	CFrame.new(-84, 1.5, -100),
	Color3.fromRGB(225, 225, 230),
	Enum.Material.SmoothPlastic
)
CollectionService:AddTag(toilet, "RestoreToilet")

-- Mine pits: unbreakable rim walls and floor below ground, anchor at ground level, ladders out.
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
	-- rim fence at ground level with an opening on the south side
	part(
		"PitRimN",
		Vector3.new(w + 4 * B, 3, 1),
		CFrame.new(cx, 1.5, cz - d / 2 - 2 * B),
		STONE,
		Enum.Material.Metal
	)
	part(
		"PitRimW",
		Vector3.new(1, 3, d + 4 * B),
		CFrame.new(cx - w / 2 - 2 * B, 1.5, cz),
		STONE,
		Enum.Material.Metal
	)
	part(
		"PitRimE",
		Vector3.new(1, 3, d + 4 * B),
		CFrame.new(cx + w / 2 + 2 * B, 1.5, cz),
		STONE,
		Enum.Material.Metal
	)
	local anchor =
		part("MineAnchor_" .. m.id, Vector3.new(w, 0.2, d), CFrame.new(cx, -0.1, cz), DARK)
	anchor:SetAttribute("LocationId", "prison")
	anchor:SetAttribute("MineId", m.id)
	anchor:SetAttribute("Size", Vector3.new(m.sx, m.sy, m.sz))
	anchor.CanQuery = false
	anchor.CanTouch = false
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, m.label, 10)
	-- ladders (trusses) on the inner side of every wall
	for _, side in ipairs({
		{ cx, cz - d / 2 + 1 },
		{ cx, cz + d / 2 - 1 },
		{ cx - w / 2 + 1, cz },
		{ cx + w / 2 - 1, cz },
	}) do
		local truss = Instance.new("TrussPart")
		truss.Name = "Ladder"
		truss.Size = Vector3.new(2, h + 2, 2)
		truss.CFrame = CFrame.new(side[1], -h / 2 + 1, side[2])
		truss.Anchored = true
		truss.Color = STONE
		truss.Parent = root
	end
end

print("[build-prison] done")
