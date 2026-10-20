--!nocheck
-- NPC characters (R15 rigs) and the Ordinary case as a chest model. Run in Studio (Edit) after
-- scripts/build-prison.luau; idempotent (replaces Workspace.Prison.Npcs). The services bind by tag to a
-- BasePart: here the tag goes on the rig's HumanoidRootPart (SellPoint / ItemShop / FoodShop) and on
-- the chest base (OrdinaryCase), so EconomyService / CaseService keep working unchanged.
-- [владелец] 20.10.2026: скупщик, торговцы и т. д. — персонажи, кейс — модель сундука.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

local root = workspace:FindFirstChild("Prison")
if not root then
	error("[build-npcs] run scripts/build-prison.luau first")
end
-- Remove the blockout stand-ins from build-prison and the previous NPC folder.
for _, name in ipairs({ "Buyer", "ItemShop", "FoodShop", "OrdinaryCase", "Npcs" }) do
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
end
local folder = Instance.new("Folder")
folder.Name = "Npcs"
folder.Parent = root

local SKIN = {
	Color3.fromRGB(234, 184, 146),
	Color3.fromRGB(198, 140, 100),
	Color3.fromRGB(120, 80, 55),
	Color3.fromRGB(245, 205, 170),
}

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.CanCollide = false
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function sign(target, text, offset)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(220, 40)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
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

-- spec: { name, tag, cf (facing direction included), label, skin, shirt, pants, hat = "cap"|"chef"|"band"|"helmet"|nil, apron = Color3? }
local function npc(spec)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = spec.skin
	desc.LeftArmColor = spec.skin
	desc.RightArmColor = spec.skin
	desc.TorsoColor = spec.shirt
	desc.LeftLegColor = spec.pants
	desc.RightLegColor = spec.pants
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
	model.Parent = folder
	model:PivotTo(spec.cf)
	local hrp = model:FindFirstChild("HumanoidRootPart")
	CollectionService:AddTag(hrp, spec.tag)
	sign(hrp, spec.label, 4.5)
	local head = model:FindFirstChild("Head")
	local headCf = head.CFrame
	if spec.hat == "cap" then
		part(
			"Cap",
			Vector3.new(1.3, 0.5, 1.3),
			headCf * CFrame.new(0, 0.6, 0),
			Color3.fromRGB(90, 60, 35),
			Enum.Material.Fabric,
			model
		)
		part(
			"CapBrim",
			Vector3.new(1.3, 0.15, 0.7),
			headCf * CFrame.new(0, 0.4, -0.7),
			Color3.fromRGB(90, 60, 35),
			Enum.Material.Fabric,
			model
		)
	elseif spec.hat == "chef" then
		part(
			"ChefHat",
			Vector3.new(1.1, 1.1, 1.1),
			headCf * CFrame.new(0, 0.95, 0),
			Color3.fromRGB(245, 245, 245),
			Enum.Material.Fabric,
			model
		)
	elseif spec.hat == "band" then
		part(
			"Headband",
			Vector3.new(1.35, 0.25, 1.35),
			headCf * CFrame.new(0, 0.25, 0),
			Color3.fromRGB(200, 50, 50),
			Enum.Material.Fabric,
			model
		)
	elseif spec.hat == "helmet" then
		local h = part(
			"Helmet",
			Vector3.new(1.35, 0.8, 1.35),
			headCf * CFrame.new(0, 0.5, 0),
			Color3.fromRGB(230, 200, 60),
			Enum.Material.Metal,
			model
		)
		local lamp = part(
			"HelmetLamp",
			Vector3.new(0.3, 0.3, 0.3),
			headCf * CFrame.new(0, 0.5, -0.75),
			Color3.fromRGB(255, 240, 200),
			Enum.Material.Neon,
			model
		)
		local light = Instance.new("SpotLight")
		light.Range = 20
		light.Angle = 60
		light.Face = Enum.NormalId.Front
		light.Parent = lamp
		h.Shape = Enum.PartType.Ball
	end
	if spec.apron then
		local torso = model:FindFirstChild("UpperTorso")
		part(
			"Apron",
			Vector3.new(1.6, 2.2, 0.15),
			torso.CFrame * CFrame.new(0, -0.6, -0.55),
			spec.apron,
			Enum.Material.Fabric,
			model
		)
	end
	return model
end

-- Facing the plaza centre (0, 0, 0): CFrame.lookAt(pos, target).
local function facing(x, z, tx, tz)
	return CFrame.lookAt(Vector3.new(x, 3, z), Vector3.new(tx, 3, tz))
end

npc({
	name = "Buyer",
	tag = "SellPoint",
	cf = facing(-22, 12, 0, 0),
	label = "Скупщик блоков",
	skin = SKIN[2],
	shirt = Color3.fromRGB(60, 90, 60),
	pants = Color3.fromRGB(50, 45, 40),
	hat = "cap",
	apron = Color3.fromRGB(110, 80, 40),
})
npc({
	name = "ItemShop",
	tag = "ItemShop",
	cf = facing(22, 12, 0, 0),
	label = "Продавец предметов",
	skin = SKIN[1],
	shirt = Color3.fromRGB(120, 70, 40),
	pants = Color3.fromRGB(45, 50, 70),
	hat = "helmet",
})
npc({
	name = "FoodShop",
	tag = "FoodShop",
	cf = facing(22, -12, 0, 0),
	label = "Продавец еды",
	skin = SKIN[4],
	shirt = Color3.fromRGB(240, 240, 240),
	pants = Color3.fromRGB(40, 40, 45),
	hat = "chef",
	apron = Color3.fromRGB(250, 250, 250),
})
npc({
	name = "Trainer",
	tag = "TrainerNpc",
	cf = facing(72, 128, 0, 0),
	label = "Тренер",
	skin = SKIN[3],
	shirt = Color3.fromRGB(200, 60, 50),
	pants = Color3.fromRGB(60, 60, 70),
	hat = "band",
})
npc({
	name = "QuestGiver",
	tag = "QuestNpc",
	cf = facing(6, -40, 0, 0),
	label = "Задания",
	skin = SKIN[1],
	shirt = Color3.fromRGB(70, 80, 120),
	pants = Color3.fromRGB(45, 40, 40),
	hat = "cap",
})
npc({
	name = "Guard",
	tag = "GuardNpc",
	cf = facing(-6, -186, 0, 0),
	label = "Охранник",
	skin = SKIN[2],
	shirt = Color3.fromRGB(40, 60, 110),
	pants = Color3.fromRGB(30, 35, 55),
	hat = "cap",
})

-- Ordinary case as a chest: base is the tagged part, lid + bands + lock are decoration.
local chest = Instance.new("Model")
chest.Name = "OrdinaryCase"
chest.Parent = folder
local base = part(
	"Base",
	Vector3.new(5, 3, 4),
	CFrame.new(-22, 1.5, -12),
	Color3.fromRGB(150, 110, 70),
	Enum.Material.Plastic,
	chest
)
base.CanCollide = true
base.MaterialVariant = "px_planks"
local lid = part(
	"Lid",
	Vector3.new(5.2, 1.4, 4.2),
	CFrame.new(-22, 3.7, -12),
	Color3.fromRGB(150, 110, 70),
	Enum.Material.Plastic,
	chest
)
lid.MaterialVariant = "px_planks"
lid.CanCollide = true
for _, dx in ipairs({ -1.8, 1.8 }) do
	part(
		"Band",
		Vector3.new(0.5, 3.1, 4.1),
		CFrame.new(-22 + dx, 1.5, -12),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal,
		chest
	)
	part(
		"LidBand",
		Vector3.new(0.5, 1.5, 4.3),
		CFrame.new(-22 + dx, 3.7, -12),
		Color3.fromRGB(60, 60, 66),
		Enum.Material.Metal,
		chest
	)
end
part(
	"Lock",
	Vector3.new(1, 1.2, 0.4),
	CFrame.new(-22, 3, -14.1),
	Color3.fromRGB(230, 190, 70),
	Enum.Material.Metal,
	chest
)
part(
	"Keyhole",
	Vector3.new(0.3, 0.5, 0.2),
	CFrame.new(-22, 2.95, -14.3),
	Color3.fromRGB(30, 30, 30),
	Enum.Material.Metal,
	chest
)
local glow = part(
	"Glow",
	Vector3.new(4.6, 0.2, 3.6),
	CFrame.new(-22, 3.05, -12),
	Color3.fromRGB(255, 210, 90),
	Enum.Material.Neon,
	chest
)
glow.Transparency = 0.3
local light = Instance.new("PointLight")
light.Color = Color3.fromRGB(255, 200, 90)
light.Range = 10
light.Parent = glow
chest.PrimaryPart = base
CollectionService:AddTag(base, "OrdinaryCase")
sign(base, "Обычный кейс", 5)
part(
	"Pedestal",
	Vector3.new(7, 0.6, 6),
	CFrame.new(-22, 0.3, -12),
	Color3.fromRGB(96, 96, 100),
	Enum.Material.Plastic,
	chest
).MaterialVariant =
	"px_cobblestone"

return "[build-npcs] " .. #folder:GetChildren() .. " models"
