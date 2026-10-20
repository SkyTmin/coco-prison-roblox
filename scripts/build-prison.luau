--!nocheck
-- Builds the Тюрьма (spawn) location as a blockout, following the Телепортатор map
-- (wiki/in-game-wiki/JOBS-CASES-SPAWN.md): spawn with a fountain in the centre, Шахта north,
-- Малая шахта south, Баня NW, Рынок NE, Спальня SW, Столовая E, Задания under the mine, Тренер SE,
-- perimeter wall. Run in Studio (Command Bar or MCP execute_luau). Replaces Workspace.Prison.
-- The mines themselves are generated at runtime by MineService from the MineAnchor parts.

local CollectionService = game:GetService("CollectionService")

local old = workspace:FindFirstChild("Prison")
if old then
	old:Destroy()
end
local old2 = workspace:FindFirstChild("Baseplate")
if old2 then
	old2:Destroy()
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
local STONE = Color3.fromRGB(96, 96, 100)
local DARK = Color3.fromRGB(60, 60, 66)
local WOOD = Color3.fromRGB(120, 85, 50)
local GRASS = Color3.fromRGB(80, 130, 60)
local PATH = Color3.fromRGB(150, 140, 125)
local WATER = Color3.fromRGB(60, 120, 200)

local function part(name, size, cf, color, material, parent)
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

local function sign(target, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(200, 40)
	gui.StudsOffset = Vector3.new(0, (offset or target.Size.Y / 2) + 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 160
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

-- Ground 260×260 and perimeter wall
part("Ground", Vector3.new(260, B, 260), CFrame.new(0, -B / 2, 0), GRASS, Enum.Material.Grass)
for _, d in ipairs({ { 0, -130 }, { 0, 130 } }) do
	part("Wall", Vector3.new(260, 24, B), CFrame.new(d[1], 12, d[2]), DARK, Enum.Material.Brick)
end
for _, d in ipairs({ { -130, 0 }, { 130, 0 } }) do
	part("Wall", Vector3.new(B, 24, 260), CFrame.new(d[1], 12, d[2]), DARK, Enum.Material.Brick)
end

-- Paths: cross through the centre
part("PathNS", Vector3.new(12, 0.4, 240), CFrame.new(0, 0.2, 0), PATH, Enum.Material.Concrete)
part("PathEW", Vector3.new(240, 0.4, 12), CFrame.new(0, 0.2, 0), PATH, Enum.Material.Concrete)

-- Spawn plaza with fountain
part(
	"Plaza",
	Vector3.new(44, 0.6, 44),
	CFrame.new(0, 0.3, 0),
	Color3.fromRGB(170, 160, 145),
	Enum.Material.Concrete
)
local fountain =
	part("Fountain", Vector3.new(10, 3, 10), CFrame.new(0, 1.5, 0), STONE, Enum.Material.Slate)
part("FountainWater", Vector3.new(8, 1, 8), CFrame.new(0, 3.2, 0), WATER, Enum.Material.Glass).Transparency =
	0.4
sign(fountain, "Спавн")
local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(8, 1, 8)
spawn.CFrame = CFrame.new(0, 0.8, 12)
spawn.Anchored = true
spawn.Transparency = 1
spawn.CanCollide = false
spawn.Parent = root

-- NPCs around the plaza
local function npc(name, tag, cf, text)
	local p = part(name, Vector3.new(3, 7, 3), cf, WOOD, Enum.Material.Wood)
	CollectionService:AddTag(p, tag)
	sign(p, text)
	return p
end
npc("Buyer", "SellPoint", CFrame.new(-16, 3.5, 10), "Скупщик блоков")
npc("ItemShop", "ItemShop", CFrame.new(16, 3.5, 10), "Продавец предметов")
npc("FoodShop", "FoodShop", CFrame.new(16, 3.5, -10), "Продавец еды")

-- Buildings (blockout boxes with signs)
local function building(name, size, pos, text)
	local b = part(name, size, CFrame.new(pos.X, size.Y / 2, pos.Z), STONE, Enum.Material.Brick)
	sign(b, text)
	return b
end
building("Bath", Vector3.new(40, 14, 28), Vector3.new(-80, 0, -70), "Баня")
building("Market", Vector3.new(40, 14, 28), Vector3.new(80, 0, -70), "Рынок")
building("Bedroom", Vector3.new(40, 14, 28), Vector3.new(-80, 0, 70), "Спальня")
building("Canteen", Vector3.new(28, 14, 56), Vector3.new(90, 0, 10), "Столовая")
building("Quests", Vector3.new(24, 10, 16), Vector3.new(0, 0, -48), "Задания")
building("Trainer", Vector3.new(24, 10, 20), Vector3.new(60, 0, 90), "Тренер")

-- Mine pits: a ring of unbreakable stone around each mine volume; the MineAnchor marks the top centre.
local function minePit(name, mineId, centre, sx, sy, sz)
	local w, h, d = sx * B, sy * B, sz * B
	-- rim walls (unbreakable) 2 blocks thick around the pit, from the floor level up to ground
	part(
		name .. "Floor",
		Vector3.new(w + 4 * B, B, d + 4 * B),
		CFrame.new(centre.X, -h - B / 2 - 0.1, centre.Z),
		DARK,
		Enum.Material.Slate
	)
	part(
		name .. "WallN",
		Vector3.new(w + 4 * B, h + B, 2 * B),
		CFrame.new(centre.X, -h / 2 + B / 2 - 0.1, centre.Z - d / 2 - B),
		DARK,
		Enum.Material.Slate
	)
	part(
		name .. "WallS",
		Vector3.new(w + 4 * B, h + B, 2 * B),
		CFrame.new(centre.X, -h / 2 + B / 2 - 0.1, centre.Z + d / 2 + B),
		DARK,
		Enum.Material.Slate
	)
	part(
		name .. "WallW",
		Vector3.new(2 * B, h + B, d),
		CFrame.new(centre.X - w / 2 - B, -h / 2 + B / 2 - 0.1, centre.Z),
		DARK,
		Enum.Material.Slate
	)
	part(
		name .. "WallE",
		Vector3.new(2 * B, h + B, d),
		CFrame.new(centre.X + w / 2 + B, -h / 2 + B / 2 - 0.1, centre.Z),
		DARK,
		Enum.Material.Slate
	)
	-- cut the ground: a hole is simulated by placing the mine top flush with the ground (y = 0)
	local anchor =
		part(name .. "Anchor", Vector3.new(w, 0.2, d), CFrame.new(centre.X, -0.1, centre.Z), DARK)
	anchor:SetAttribute("LocationId", "prison")
	anchor:SetAttribute("MineId", mineId)
	anchor:SetAttribute("Size", Vector3.new(sx, sy, sz))
	CollectionService:AddTag(anchor, "MineAnchor")
	sign(anchor, (if mineId == "prison" then "Шахта" else "Малая шахта"), 6)
	-- stairs down on the south side
	for i = 1, sy do
		part(
			name .. "Stair" .. i,
			Vector3.new(6, B, B),
			CFrame.new(centre.X, -i * B + B / 2, centre.Z + d / 2 + B * 2 + i * B),
			PATH,
			Enum.Material.Concrete
		)
	end
end
-- Ground above the pits must be removed: carve by splitting the ground into four slabs around each pit
-- (simple blockout: we leave the grass and rely on the mine top at y=0 being walkable).
minePit("Mine", "prison", Vector3.new(0, 0, -100), 32, 12, 32)
minePit("SmallMine", "prison_small", Vector3.new(0, 0, 100), 16, 8, 16)

print("[build-prison] done")
