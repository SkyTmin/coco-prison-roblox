--!nocheck
-- Builds a placeholder first-chapter yard in the open place (PROTOTYPE-SPEC.md §2).
-- Run it in Studio: paste into the Command Bar, or let Claude run it through the Studio
-- MCP server (run_code). Safe to re-run: it replaces Workspace.Yard.
--
-- Layout (studs): spawn at the centre, sawmill (wood) to the north, earth patch (dirt/clay)
-- to the east, quarry (stone/coal/iron, level 3) to the south, sell point by the spawn.

local CollectionService = game:GetService("CollectionService")

local existing = workspace:FindFirstChild("Yard")
if existing then
	existing:Destroy()
end

local yard = Instance.new("Folder")
yard.Name = "Yard"
yard.Parent = workspace

local function part(name, size, cframe, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or yard
	return p
end

local function sign(target, text)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 32)
	gui.StudsOffset = Vector3.new(0, target.Size.Y / 2 + 2, 0)
	gui.AlwaysOnTop = true
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Text = text
	label.Parent = gui
end

local function workNode(name, size, cframe, color, material, resource, parent)
	local node = part(name, size, cframe, color, material, parent)
	node:SetAttribute("Resource", resource)
	node:SetAttribute("Generation", 1)
	node:SetAttribute("Depleted", false)
	CollectionService:AddTag(node, "WorkNode")
	return node
end

-- Ground and spawn
part(
	"Ground",
	Vector3.new(220, 2, 220),
	CFrame.new(0, -1, 0),
	Color3.fromRGB(96, 92, 84),
	Enum.Material.Concrete
)
local wall = Color3.fromRGB(70, 70, 76)
for _, offset in ipairs({ Vector3.new(0, 0, -110), Vector3.new(0, 0, 110) }) do
	part(
		"Wall",
		Vector3.new(220, 14, 2),
		CFrame.new(offset + Vector3.new(0, 7, 0)),
		wall,
		Enum.Material.Brick
	)
end
for _, offset in ipairs({ Vector3.new(-110, 0, 0), Vector3.new(110, 0, 0) }) do
	part(
		"Wall",
		Vector3.new(2, 14, 220),
		CFrame.new(offset + Vector3.new(0, 7, 0)),
		wall,
		Enum.Material.Brick
	)
end

local spawn = Instance.new("SpawnLocation")
spawn.Name = "Spawn"
spawn.Size = Vector3.new(12, 1, 12)
spawn.CFrame = CFrame.new(0, 0.5, 0)
spawn.Anchored = true
spawn.Color = Color3.fromRGB(120, 120, 130)
spawn.Material = Enum.Material.Concrete
spawn.Parent = yard

-- Sell point (guide NPC placeholder)
local sellPoint = part(
	"SellPoint",
	Vector3.new(4, 6, 4),
	CFrame.new(12, 3, 0),
	Color3.fromRGB(200, 160, 60),
	Enum.Material.Wood
)
CollectionService:AddTag(sellPoint, "SellPoint")
sign(sellPoint, "Проводник: продать")

-- Sawmill: 8 trunks (wood, axe, level 1)
local sawmill = Instance.new("Folder")
sawmill.Name = "Sawmill"
sawmill.Parent = yard
for i = 1, 8 do
	local x = -28 + (i - 1) * 8
	workNode(
		"Tree" .. i,
		Vector3.new(3, 9, 3),
		CFrame.new(x, 4.5, -50),
		Color3.fromRGB(110, 75, 40),
		Enum.Material.Wood,
		"wood",
		sawmill
	)
	local crown = part(
		"Crown",
		Vector3.new(7, 5, 7),
		CFrame.new(x, 11, -50),
		Color3.fromRGB(60, 120, 50),
		Enum.Material.Grass,
		sawmill
	)
	crown.CanCollide = false
	crown.Shape = Enum.PartType.Ball
end
sign(
	part(
		"SawmillSign",
		Vector3.new(6, 3, 0.5),
		CFrame.new(0, 1.5, -38),
		wall,
		Enum.Material.Metal,
		sawmill
	),
	"Лесопилка (топор)"
)

-- Earth patch: 6 x 5 cells (dirt, shovel, level 1), about 15% clay
local earth = Instance.new("Folder")
earth.Name = "EarthPatch"
earth.Parent = yard
local rng = Random.new(42)
for row = 1, 5 do
	for col = 1, 6 do
		local resource = if rng:NextNumber() < 0.15 then "clay" else "dirt"
		local color = if resource == "clay"
			then Color3.fromRGB(150, 130, 110)
			else Color3.fromRGB(105, 75, 50)
		workNode(
			string.format("Cell_%d_%d", row, col),
			Vector3.new(4, 2, 4),
			CFrame.new(40 + (col - 1) * 4.2, 1, -10 + (row - 1) * 4.2),
			color,
			Enum.Material.Ground,
			resource,
			earth
		)
	end
end
sign(
	part(
		"EarthSign",
		Vector3.new(6, 3, 0.5),
		CFrame.new(50, 1.5, -16),
		wall,
		Enum.Material.Metal,
		earth
	),
	"Земляной участок (лопата)"
)

-- Quarry: 8 x 4 cells (stone/coal/iron, pickaxe, level 3)
local quarry = Instance.new("Folder")
quarry.Name = "Quarry"
quarry.Parent = yard
for row = 1, 4 do
	for col = 1, 8 do
		local roll = rng:NextNumber()
		local resource = if roll < 0.08 then "iron" elseif roll < 0.3 then "coal" else "stone"
		local color = if resource == "iron"
			then Color3.fromRGB(190, 170, 150)
			elseif resource == "coal" then Color3.fromRGB(40, 40, 40)
			else Color3.fromRGB(120, 120, 120)
		workNode(
			string.format("Rock_%d_%d", row, col),
			Vector3.new(4, 4, 4),
			CFrame.new(-16 + (col - 1) * 4.2, 2, 50 + (row - 1) * 4.2),
			color,
			Enum.Material.Slate,
			resource,
			quarry
		)
	end
end
sign(
	part(
		"QuarrySign",
		Vector3.new(6, 3, 0.5),
		CFrame.new(0, 1.5, 40),
		wall,
		Enum.Material.Metal,
		quarry
	),
	"Каменоломня (кирка, уровень 3)"
)

-- Living block placeholders (interactions come in step 2 of the implementation order)
local living = Instance.new("Folder")
living.Name = "LivingBlock"
living.Parent = yard
for i, name in ipairs({ "Столовая", "Душ", "Туалет", "Кровать" }) do
	local p = part(
		name,
		Vector3.new(6, 6, 6),
		CFrame.new(-60, 3, -30 + (i - 1) * 12),
		Color3.fromRGB(90, 110, 140),
		Enum.Material.Metal,
		living
	)
	sign(p, name)
end

print(string.format("[build-yard] done: %d work nodes", #CollectionService:GetTagged("WorkNode")))
