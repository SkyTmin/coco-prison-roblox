--!nocheck
-- The Хранилище on the Спавн [вики DONATE-SHOP-BOOSTERS: «постройка с голограммой ХРАНИЛИЩЕ»]: a small stone
-- strongroom on the west lawn, south of the money top board, its door to the ring road (z = 56). Inside, an ender
-- chest (tag EnderChest, attribute Vault): the same p.enderChest as every other ender chest, shown by CaseService as
-- the Хранилище with sections «Отсек 1/2/3» (Shared/Vault). Above the roof a floating hologram «ХРАНИЛИЩЕ».
-- Size and spot are ours [решение]. Run in Studio (Edit) after build-prison / decorate-prison (and build-tops).
-- Idempotent: replaces Workspace.Prison.Vault and removes the decoration props in its footprint (decorate-prison keeps
-- out of it next time: it skips every model in a Prison folder). The model is Atomic (StreamingEnabled).

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")

local root = workspace:FindFirstChild("Prison")
if not root then
	error("[build-vault] run scripts/build-prison.luau first")
end
local old = root:FindFirstChild("Vault")
if old then
	old:Destroy()
end
local folder = Instance.new("Folder")
folder.Name = "Vault"
folder.Parent = root

local STONE = Color3.fromRGB(150, 150, 156)
local DARK = Color3.fromRGB(70, 70, 76)
local IRON = Color3.fromRGB(190, 192, 198)
local GLOW = Color3.fromRGB(60, 230, 170) -- the ender glow, like the plaza ender chest
local HOLO = Color3.fromRGB(110, 255, 210)

local W, D, H = 16, 14, 9 -- inside the walls (studs): width along x, depth along z, height
local DOOR = 6
local CENTRE = Vector3.new(-86, 0, 44)
-- the building's own space: −Z = the door side, looking south at the ring road
local frame = CFrame.lookAt(CENTRE, CENTRE + Vector3.zAxis)
local function at(x, y, z)
	return frame * CFrame.new(x, y, z)
end

local model = Instance.new("Model")
model.Name = "VaultBuilding"
model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

local function part(name, size, cf, color, variant, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Anchored = true
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if variant and MaterialService:FindFirstChild(variant) then
		p.Material = Enum.Material.Plastic
		p.MaterialVariant = variant
	else
		p.Material = material or Enum.Material.SmoothPlastic
	end
	p.Parent = model
	return p
end

local function billboard(target, text, size, offset, color, distance)
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffset = offset
	gui.LightInfluence = 0
	gui.MaxDistance = distance
	gui.Parent = target
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(10, 40, 32)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.Code
	label.Text = text
	label.Parent = gui
	return gui
end

-- ---------------------------------------------------------------- shell
part("Floor", Vector3.new(W + 2, 1, D + 2), at(0, 0.5, 0), DARK, "px_smooth_stone")
part("WallBack", Vector3.new(W + 2, H, 1), at(0, 1 + H / 2, D / 2 + 0.5), STONE, "px_stone_bricks")
for _, s in ipairs({ -1, 1 }) do
	part("WallSide", Vector3.new(1, H, D), at(s * (W / 2 + 0.5), 1 + H / 2, 0), STONE, "px_stone_bricks")
	-- the front wall either side of the doorway
	local piece = (W + 2 - DOOR) / 2
	part(
		"WallFront",
		Vector3.new(piece, H, 1),
		at(s * (DOOR / 2 + piece / 2), 1 + H / 2, -D / 2 - 0.5),
		STONE,
		"px_stone_bricks"
	)
	-- iron door posts
	part("DoorPost", Vector3.new(0.6, H - 2, 1.4), at(s * (DOOR / 2 + 0.3), 1 + (H - 2) / 2, -D / 2 - 0.5), IRON, nil, Enum.Material.Metal)
end
part("DoorLintel", Vector3.new(DOOR, 2, 1), at(0, 1 + H - 1, -D / 2 - 0.5), STONE, "px_stone_bricks")
part("Roof", Vector3.new(W + 4, 1, D + 4), at(0, 1 + H + 0.5, 0), DARK, "px_smooth_stone")
part("RoofTrim", Vector3.new(W + 2, 0.6, D + 2), at(0, 1 + H + 1.3, 0), STONE, "px_stone_bricks")
-- a footpath from the door to the ring road
part("Footpath", Vector3.new(DOOR, 0.4, 6), at(0, 0.2, -D / 2 - 4), Color3.fromRGB(150, 140, 125), "px_cobblestone")

-- ---------------------------------------------------------------- inside: iron pillars, shelves of iron, a lamp
for _, x in ipairs({ -1, 1 }) do
	for _, z in ipairs({ -1, 1 }) do
		part("Pillar", Vector3.new(1.4, H, 1.4), at(x * (W / 2 - 1), 1 + H / 2, z * (D / 2 - 1)), IRON, nil, Enum.Material.Metal)
	end
	-- iron safes along the side walls (decoration)
	for i = 0, 1 do
		local safe = part("Safe", Vector3.new(2.4, 3, 3), at(x * (W / 2 - 2), 2.5 + i * 3.1, 0), IRON, nil, Enum.Material.DiamondPlate)
		safe.CanCollide = i == 0
		part("SafeDial", Vector3.new(0.2, 0.8, 0.8), at(x * (W / 2 - 3.3), 2.5 + i * 3.1, 0), DARK, nil, Enum.Material.Metal)
	end
end
local lamp = part("Lamp", Vector3.new(3, 0.4, 3), at(0, 1 + H - 0.3, 0), GLOW, nil, Enum.Material.Neon)
local light = Instance.new("PointLight")
light.Color = GLOW
light.Range = 18
light.Brightness = 1.2
light.Parent = lamp

-- ---------------------------------------------------------------- the ender chest (the Хранилище itself)
local function chestAt(x, y, z)
	-- the chest's lock side (−Z) faces the door
	return at(x, y, z)
end
local pedestal = part("Pedestal", Vector3.new(7, 1, 6), chestAt(0, 1.5, 3), STONE, "px_stone_bricks")
pedestal.CanCollide = true
local base = part("Base", Vector3.new(5, 3, 4), chestAt(0, 3.5, 3), Color3.fromRGB(28, 22, 40), nil, Enum.Material.WoodPlanks)
part("Lid", Vector3.new(5.2, 1.4, 4.2), chestAt(0, 5.7, 3), Color3.fromRGB(28, 22, 40), nil, Enum.Material.WoodPlanks)
for _, dx in ipairs({ -1.8, 1.8 }) do
	part("Band", Vector3.new(0.5, 3.1, 4.1), chestAt(dx, 3.5, 3), Color3.fromRGB(20, 60, 50), nil, Enum.Material.Metal)
	part("LidBand", Vector3.new(0.5, 1.5, 4.3), chestAt(dx, 5.7, 3), Color3.fromRGB(20, 60, 50), nil, Enum.Material.Metal)
end
part("Lock", Vector3.new(1, 1.2, 0.4), chestAt(0, 5, 0.9), GLOW, nil, Enum.Material.Metal)
local glow = part("Glow", Vector3.new(4.6, 0.2, 3.6), chestAt(0, 5.05, 3), GLOW, nil, Enum.Material.Neon)
glow.Transparency = 0.3
for _, p in ipairs(model:GetChildren()) do
	if p:IsA("BasePart") and (p.Name == "Lid" or p.Name == "Band" or p.Name == "LidBand" or p.Name == "Lock" or p.Name == "Glow") then
		p.CanCollide = false
	end
end
base.CanCollide = true
base:SetAttribute("Vault", true) -- CaseService: the prompt says «Хранилище»
CollectionService:AddTag(base, "EnderChest")
billboard(base, "Хранилище", UDim2.fromOffset(110, 18), Vector3.new(0, 4.5, 0), Color3.fromRGB(255, 190, 60), 60).AlwaysOnTop = true

-- ---------------------------------------------------------------- the hologram over the roof
local holo = part("Hologram", Vector3.new(1, 1, 1), at(0, 1 + H + 5, 0), HOLO)
holo.Transparency = 1
holo.CanCollide = false
holo.CanTouch = false
holo.CanQuery = false
-- sized in studs (scales with the distance like a sign in the world)
billboard(holo, "ХРАНИЛИЩЕ", UDim2.fromScale(16, 3), Vector3.zero, HOLO, 220)
billboard(holo, "3 отсека по 27 слотов", UDim2.fromScale(12, 1.2), Vector3.new(0, -2.4, 0), Color3.fromRGB(220, 255, 240), 120)
local pulse = Instance.new("PointLight")
pulse.Color = HOLO
pulse.Range = 12
pulse.Brightness = 0.6
pulse.Parent = holo

model.PrimaryPart = base

-- ---------------------------------------------------------------- clear the decoration props in the footprint
local removed = 0
local decor = root:FindFirstChild("Decor")
if decor then
	for _, p in ipairs(workspace:GetPartBoundsInBox(at(0, 8, -2), Vector3.new(W + 8, 18, D + 14))) do
		if p:IsDescendantOf(decor) then
			local top = p
			while top.Parent ~= decor do
				top = top.Parent
			end
			if top.Parent then
				-- loose parts of one prop (a lamp's pole, arm, head) share its x/z: take the whole prop
				if top:IsA("BasePart") then
					local here = Vector2.new(top.Position.X, top.Position.Z)
					for _, other in ipairs(decor:GetChildren()) do
						if other ~= top and other:IsA("BasePart") and (Vector2.new(other.Position.X, other.Position.Z) - here).Magnitude < 2.5 then
							other:Destroy()
						end
					end
				end
				top:Destroy()
				removed += 1
			end
		end
	end
end
model.Parent = folder
return ("[build-vault] the Хранилище built at (%d, %d), %d props cleared"):format(CENTRE.X, CENTRE.Z, removed)
