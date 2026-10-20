--!nocheck
-- Showcase ("витрина") for the owner: every armor set (leather, chain, iron, diamond; plain and
-- enchanted) on walking R15 mannequins, every tool (4 materials × pickaxe/shovel/axe/sword + shears)
-- held by mannequins and on racks, and a wall with all inventory icons and names. Built outside the
-- prison wall (north, z ≈ -320). Run in Studio (Edit) via scripts/studio-loader.luau after the map
-- scripts; idempotent (replaces Workspace.Showcase). Mannequins carry the attributes `Armor` /
-- `HeldItem` and the tags ArmorMannequin / HeldMannequin, so the normal client renderers draw them.
-- A small Script inside plays the walk animation in Play mode.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local old = workspace:FindFirstChild("Showcase")
if old then
	old:Destroy()
end
local root = Instance.new("Folder")
root.Name = "Showcase"
root.Parent = workspace

local icons = require(ReplicatedStorage.Shared.Config.icons).icons
local toolsCfg = require(ReplicatedStorage.Shared.Config.tools).tools

local CX, CZ = 0, -330
local DARK = Color3.fromRGB(40, 40, 46)
local STONE = Color3.fromRGB(96, 96, 100)
local LAMP = Color3.fromRGB(255, 215, 130)

local function part(name, size, cf, color, material, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	if typeof(material) == "string" then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = material
		p.Color = Color3.new(1, 1, 1)
	else
		p.Material = material or Enum.Material.SmoothPlastic
	end
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or root
	return p
end
local function label(target, text, offset, width)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(width or 120, 18)
	gui.StudsOffset = Vector3.new(0, offset or 4, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 120
	gui.Parent = target
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.TextColor3 = Color3.fromRGB(255, 220, 140)
	l.TextStrokeTransparency = 0.2
	l.TextScaled = true
	l.Font = Enum.Font.Code
	l.Text = text
	l.Parent = gui
end

-- floor, back wall with lamps
part("Floor", Vector3.new(160, 1, 80), CFrame.new(CX, -0.5, CZ), STONE, "px_concrete_floor")
part("BackWall", Vector3.new(160, 20, 1), CFrame.new(CX, 10, CZ - 40), DARK, Enum.Material.Brick)
for i = -3, 3 do
	local l = part(
		"Lamp",
		Vector3.new(1.5, 1.5, 1.5),
		CFrame.new(CX + i * 24, 12, CZ - 38),
		LAMP,
		Enum.Material.Neon
	)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Range = 40
	light.Brightness = 1.2
	light.Parent = l
end
local title =
	part("Title", Vector3.new(60, 4, 0.5), CFrame.new(CX, 16, CZ - 39.5), DARK, "px_planks")
label(
	title,
	"ВИТРИНА: броня (кожа, кольчуга, железо, алмаз), инструменты, зачарования",
	3,
	420
)

-- Level per material from tools.json: first upgrade whose materialAfter matches; enchanted = first
-- upgrade of that material with enchantAfter > 0.
local function levelFor(id, material, enchanted)
	local cfg = toolsCfg[id]
	if material == "wood" and not enchanted then
		return 1
	end
	for _, up in ipairs(cfg.upgrades) do
		if
			up.materialAfter == material
			and ((not enchanted and up.enchantAfter == 0) or (enchanted and up.enchantAfter > 0))
		then
			return up.to
		end
	end
	for _, up in ipairs(cfg.upgrades) do
		if up.materialAfter == material then
			return up.to
		end
	end
	return 1
end

-- mannequin: animated R15 rig; returns the model
local walkScript = [[
local humanoid = script.Parent:WaitForChild("Humanoid")
local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
local anim = Instance.new("Animation")
anim.AnimationId = script:GetAttribute("AnimationId")
local track = animator:LoadAnimation(anim)
track.Looped = true
track:Play()
]]
local function mannequin(name, cf, attrs, animationId)
	local desc = Instance.new("HumanoidDescription")
	desc.HeadColor = Color3.fromRGB(234, 184, 146)
	desc.LeftArmColor = Color3.fromRGB(234, 184, 146)
	desc.RightArmColor = Color3.fromRGB(234, 184, 146)
	desc.TorsoColor = Color3.fromRGB(70, 110, 160)
	desc.LeftLegColor = Color3.fromRGB(50, 60, 90)
	desc.RightLegColor = Color3.fromRGB(50, 60, 90)
	local model = Players:CreateHumanoidModelFromDescription(desc, Enum.HumanoidRigType.R15)
	model.Name = name
	local animate = model:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	model.Parent = root
	model:PivotTo(cf)
	model.HumanoidRootPart.Anchored = true -- stays in place; limbs animate through Motor6Ds
	for k, v in pairs(attrs) do
		model:SetAttribute(k, v)
	end
	if attrs.Armor then
		CollectionService:AddTag(model, "ArmorMannequin")
	end
	if attrs.HeldItem then
		CollectionService:AddTag(model, "HeldMannequin")
	end
	if animationId then
		local s = Instance.new("Script")
		s.Name = "ShowcaseAnimate"
		s.Source = walkScript
		s:SetAttribute("AnimationId", animationId)
		s.Parent = model
	end
	return model
end

local WALK = "rbxassetid://913402848" -- Roblox default R15 walk
local IDLE = "rbxassetid://507766666" -- Roblox default R15 idle
local MATERIALS = { "wood", "stone", "iron", "diamond" }
local ARMOR_NAMES = {
	wood = "Кожаная",
	stone = "Кольчужная",
	iron = "Железная",
	diamond = "Алмазная",
}
local TOOL_NAMES =
	{ pickaxe = "кирка", shovel = "лопата", axe = "топор", sword = "меч" }
local MAT_NAMES = {
	wood = "Деревянная",
	stone = "Каменная",
	iron = "Железная",
	diamond = "Алмазная",
}

-- Row 1 (back): armor sets, walking. Plain then enchanted for each material.
for i, material in ipairs(MATERIALS) do
	for j, enchanted in ipairs({ false, true }) do
		local x = CX - 70 + ((i - 1) * 2 + (j - 1)) * 20
		local armor = string.format(
			"helmet:%d,chestplate:%d,leggings:%d,boots:%d",
			levelFor("helmet", material, enchanted),
			levelFor("chestplate", material, enchanted),
			levelFor("leggings", material, enchanted),
			levelFor("boots", material, enchanted)
		)
		local m = mannequin(
			"Armor_" .. material .. (enchanted and "_ench" or ""),
			CFrame.new(x, 3.1, CZ - 24),
			{
				Armor = armor,
				HeldItem = "sword:" .. levelFor("sword", material, enchanted),
			},
			WALK
		)
		local base =
			part("Pedestal", Vector3.new(8, 0.4, 8), CFrame.new(x, 0.2, CZ - 24), STONE, "px_stone")
		label(
			base,
			ARMOR_NAMES[material] .. (enchanted and " (зачарованная)" or ""),
			8,
			160
		)
		m.Name = m.Name
	end
end

-- Row 2 (middle): tools held by idle mannequins, 4 per material.
local TOOLS = { "pickaxe", "shovel", "axe", "sword" }
for i, material in ipairs(MATERIALS) do
	for j, tool in ipairs(TOOLS) do
		local x = CX - 75 + ((i - 1) * 4 + (j - 1)) * 10
		local level = levelFor(tool, material, false)
		mannequin(
			"Tool_" .. tool .. "_" .. material,
			CFrame.new(x, 3.1, CZ - 4) * CFrame.Angles(0, math.rad(-30), 0),
			{ HeldItem = tool .. ":" .. level },
			IDLE
		)
		local base =
			part("Pedestal", Vector3.new(6, 0.4, 6), CFrame.new(x, 0.2, CZ - 4), STONE, "px_stone")
		label(base, MAT_NAMES[material] .. " " .. TOOL_NAMES[tool], 7.5, 140)
	end
end
-- enchanted tool examples + shears
do
	local x = CX - 75
	for j, tool in ipairs(TOOLS) do
		local level = levelFor(tool, "diamond", true)
		mannequin(
			"ToolEnch_" .. tool,
			CFrame.new(x + (j - 1) * 10, 3.1, CZ + 14) * CFrame.Angles(0, math.rad(-30), 0),
			{ HeldItem = tool .. ":" .. level },
			IDLE
		)
		local base = part(
			"Pedestal",
			Vector3.new(6, 0.4, 6),
			CFrame.new(x + (j - 1) * 10, 0.2, CZ + 14),
			STONE,
			"px_stone"
		)
		label(base, "Зачарованная: " .. TOOL_NAMES[tool], 7.5, 160)
	end
	mannequin(
		"Tool_shears",
		CFrame.new(x + 50, 3.1, CZ + 14) * CFrame.Angles(0, math.rad(-30), 0),
		{ HeldItem = "shears:1" },
		IDLE
	)
	local base = part(
		"Pedestal",
		Vector3.new(6, 0.4, 6),
		CFrame.new(x + 50, 0.2, CZ + 14),
		STONE,
		"px_stone"
	)
	label(base, "Ножницы", 7.5, 120)
end

-- Icon wall: every inventory icon with its key, 8 per row, on the back wall.
local keys = {}
for k in pairs(icons) do
	table.insert(keys, k)
end
table.sort(keys)
for n, key in ipairs(keys) do
	local col = (n - 1) % 16
	local row = math.floor((n - 1) / 16)
	local tile = part(
		"Icon_" .. key,
		Vector3.new(6, 6, 0.4),
		CFrame.new(CX - 75 + col * 10, 7 + row * 0, CZ - 39.2),
		DARK,
		Enum.Material.SmoothPlastic
	)
	tile.CFrame = CFrame.new(CX - 75 + col * 10, 3.5 + row * 7 + 2, CZ - 39.2)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 32
	gui.Parent = tile
	local img = Instance.new("ImageLabel")
	img.Size = UDim2.fromScale(0.8, 0.8)
	img.Position = UDim2.fromScale(0.1, 0.02)
	img.BackgroundTransparency = 1
	img.Image = icons[key]
	img.ScaleType = Enum.ScaleType.Fit
	img.ResampleMode = Enum.ResamplerMode.Pixelated
	img.Parent = gui
	local txt = Instance.new("TextLabel")
	txt.Size = UDim2.fromScale(1, 0.18)
	txt.Position = UDim2.fromScale(0, 0.82)
	txt.BackgroundTransparency = 1
	txt.TextColor3 = Color3.fromRGB(255, 220, 140)
	txt.TextScaled = true
	txt.Font = Enum.Font.Code
	txt.Text = key
	txt.Parent = gui
end

-- teleport spot so the Teleporter's "Спавн" tab can jump here (Studio/testing)
local spot = part("LocationSpawn_showcase", Vector3.new(4, 1, 4), CFrame.new(CX, 1, CZ + 30), STONE)
spot.Transparency = 1
spot.CanCollide = false
spot:SetAttribute("LocationId", "prison")
spot:SetAttribute("Spot", "showcase")
CollectionService:AddTag(spot, "LocationSpawn")

return "[build-showcase] " .. #root:GetChildren() .. " objects at (" .. CX .. ", " .. CZ .. ")"
