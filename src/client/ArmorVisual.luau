--!strict
-- Armor rendered the Minecraft way: a textured box slightly larger than each limb, welded to it, with
-- the faces of the Minecraft armor layer (Pixel Perfection via VoxeLibre, CC BY-SA 4.0 — see
-- assets/thirdparty/voxelibre/ATTRIBUTION.md) as Decals. Faces come from Config.armor (generated from
-- assets/armor/ids.json). Enchanted pieces (level with an enchant > 0) get a purple glint overlay.
-- The server owns the `Armor` attribute ("helmet:<level>,chestplate:<level>,...").

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

type Rig = { character: Model, connections: { RBXScriptConnection }, visual: Model? }

local ArmorVisual = {}
local rigs: { [Instance]: Rig } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local started = false
local glintDecals: { [Decal]: boolean } = {}

-- Minecraft armor model is 1/16 block larger than the skin box on each side; R15 limbs are ~1 stud
-- wide, so +0.3 studs total keeps the same proportion and hides the body underneath.
local PAD = 0.42

-- piece → boxes: { limb name, texture limb key, vertical slice {y0, y1} of the limb (0 = top), pad }
type Box = { limb: string, key: string, y0: number, y1: number, pad: number? }
local BOXES: { [string]: { Box } } = {
	helmet = { { limb = "Head", key = "head", y0 = 0, y1 = 1, pad = 0.4 } },
	chestplate = {
		{ limb = "UpperTorso", key = "torsoupper", y0 = 0, y1 = 1, pad = 0.5 },
		{ limb = "LowerTorso", key = "torsolower", y0 = 0, y1 = 1, pad = 0.5 },
		{ limb = "LeftUpperArm", key = "upperarm", y0 = 0, y1 = 1 },
		{ limb = "RightUpperArm", key = "upperarm", y0 = 0, y1 = 1 },
		{ limb = "LeftLowerArm", key = "lowerarm", y0 = 0, y1 = 1 },
		{ limb = "RightLowerArm", key = "lowerarm", y0 = 0, y1 = 1 },
	},
	leggings = {
		{ limb = "LowerTorso", key = "torso", y0 = 0, y1 = 1, pad = 0.36 },
		{ limb = "LeftUpperLeg", key = "upperleg", y0 = 0, y1 = 1 },
		{ limb = "RightUpperLeg", key = "upperleg", y0 = 0, y1 = 1 },
		{ limb = "LeftLowerLeg", key = "lowerleg", y0 = 0, y1 = 0.65 },
		{ limb = "RightLowerLeg", key = "lowerleg", y0 = 0, y1 = 0.65 },
	},
	boots = {
		{ limb = "LeftFoot", key = "foot", y0 = 0, y1 = 1, pad = 0.36 },
		{ limb = "RightFoot", key = "foot", y0 = 0, y1 = 1, pad = 0.36 },
		{ limb = "LeftLowerLeg", key = "foot", y0 = 0.6, y1 = 1, pad = 0.36 },
		{ limb = "RightLowerLeg", key = "foot", y0 = 0.6, y1 = 1, pad = 0.36 },
	},
}
-- texture face → Roblox face. Crops: front = the limb's -Z side; Minecraft "left" is the model's left.
local FACES: { [string]: Enum.NormalId } = {
	front = Enum.NormalId.Front,
	back = Enum.NormalId.Back,
	left = Enum.NormalId.Right,
	right = Enum.NormalId.Left,
	top = Enum.NormalId.Top,
	bottom = Enum.NormalId.Bottom,
}
local limbNames: { [string]: boolean } = {}
for _, boxes in pairs(BOXES) do
	for _, box in ipairs(boxes) do
		limbNames[box.limb] = true
	end
end

local function faceTexture(piece: string, material: string, key: string, face: string): string?
	local faces = Config.armor and Config.armor.faces
	if not faces then
		return nil
	end
	return faces[piece .. "_" .. material .. "_" .. key .. "_" .. face]
end

local function enchanted(id: string, level: number): boolean
	local ok, value = pcall(Config.enchantForLevel, id, level)
	return ok and type(value) == "number" and value > 0
end

local function buildBox(
	parent: Model,
	limb: BasePart,
	piece: string,
	material: string,
	box: Box,
	glint: boolean
)
	local pad = box.pad or PAD
	local fullY = limb.Size.Y + pad
	local height = fullY * (box.y1 - box.y0)
	local centreY = fullY / 2 - fullY * (box.y0 + box.y1) / 2 -- limb-space Y of the slice centre
	local part = Instance.new("Part")
	part.Name = piece .. "_" .. box.limb
	part.Size = Vector3.new(limb.Size.X + pad, height, limb.Size.Z + pad)
	part.Transparency = 1 -- faces are drawn by the decals; the part itself is invisible
	part.Massless = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local offset = CFrame.new(0, centreY, 0)
	part.CFrame = limb.CFrame * offset
	local any = false
	for face, normal in pairs(FACES) do
		local texture = faceTexture(piece, material, box.key, face)
		if texture then
			local decal = Instance.new("Decal")
			decal.Name = face
			decal.Face = normal
			decal.Texture = texture
			decal.Parent = part
			any = true
			if glint then
				local g = Instance.new("Decal")
				g.Name = "Glint"
				g.Face = normal
				g.Texture = Config.armor.glint or ""
				g.Transparency = 0.55
				g.Color3 = Color3.fromRGB(200, 120, 255)
				g.ZIndex = 2
				g.Parent = part
				glintDecals[g] = true
			end
		end
	end
	if not any then
		part:Destroy()
		return
	end
	local weld = Instance.new("Weld")
	weld.Name = "ArmorWeld"
	weld.Part0, weld.Part1 = limb, part
	weld.C0 = offset
	weld.Parent = part
	part.Parent = parent
end

-- Minecraft draws armor over the skin and hides nothing else, but Roblox avatars wear bulky layered
-- clothing (jackets, pants) and hair that poke through the armor boxes. Hide those accessories while
-- the matching piece is worn: hair under a helmet, upper-body clothing under a chestplate, lower-body
-- clothing under leggings/boots.
local UPPER_CLOTHING =
	{ Jacket = true, Sweater = true, Shirt = true, TShirt = true, DressSkirt = true }
local LOWER_CLOTHING =
	{ Pants = true, Shorts = true, LeftShoe = true, RightShoe = true, DressSkirt = true }
local function setAccessoriesHidden(character: Model, rendered: { [string]: boolean })
	for _, accessory in ipairs(character:GetChildren()) do
		if accessory:IsA("Accessory") then
			local kind = accessory.AccessoryType.Name
			local isHair = kind == "Hair"
				or string.find(string.lower(accessory.Name), "hair") ~= nil
			local hidden = (isHair and rendered.helmet)
				or (UPPER_CLOTHING[kind] and rendered.chestplate)
				or (LOWER_CLOTHING[kind] and (rendered.leggings or rendered.boots))
			for _, d in ipairs(accessory:GetDescendants()) do
				if d:IsA("BasePart") then
					d.LocalTransparencyModifier = if hidden then 1 else 0
				end
			end
		end
	end
end

local function forgetGlints(model: Model)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Decal") then
			glintDecals[d] = nil
		end
	end
end

local function render(rig: Rig)
	if rig.visual then
		forgetGlints(rig.visual)
		rig.visual:Destroy()
		rig.visual = nil
	end
	local attribute = rig.character:GetAttribute("Armor")
	if typeof(attribute) ~= "string" or attribute == "" then
		setAccessoriesHidden(rig.character, {})
		return
	end
	local visual = Instance.new("Model")
	visual.Name = "ArmorVisual"
	local rendered: { [string]: boolean } = {}
	local anyGlint = false
	for entry in string.gmatch(attribute, "[^,]+") do
		local id, rawLevel = string.match(entry, "^([^:]+):(%d+)$")
		local level = tonumber(rawLevel)
		local boxes = if id then BOXES[id] else nil
		if not id or not boxes or not level or level < 1 or rendered[id] then
			continue
		end
		rendered[id] = true
		local material = Config.materialForLevel(level)
		local glint = enchanted(id, level)
		anyGlint = anyGlint or glint
		for _, box in ipairs(boxes) do
			local limb = rig.character:FindFirstChild(box.limb)
			if limb and limb:IsA("BasePart") then
				buildBox(visual, limb, id, material, box, glint)
			end
		end
	end
	if anyGlint then
		local glow = Instance.new("Highlight")
		glow.Name = "EnchantGlow"
		glow.FillColor = Color3.fromRGB(190, 110, 255)
		glow.FillTransparency = 0.75
		glow.OutlineColor = Color3.fromRGB(230, 180, 255)
		glow.OutlineTransparency = 0.6
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Adornee = visual
		glow.Parent = visual
	end
	visual.Parent = rig.character
	rig.visual = visual
	setAccessoriesHidden(rig.character, rendered)
end

local function clear(player: Instance)
	local rig = rigs[player]
	if not rig then
		return
	end
	for _, connection in ipairs(rig.connections) do
		connection:Disconnect()
	end
	if rig.visual then
		forgetGlints(rig.visual)
		rig.visual:Destroy()
	end
	rigs[player] = nil
end

local function characterAdded(player: Instance, character: Model)
	clear(player)
	local rig: Rig = { character = character, connections = {}, visual = nil }
	rigs[player] = rig
	table.insert(
		rig.connections,
		character:GetAttributeChangedSignal("Armor"):Connect(function()
			render(rig)
		end)
	)
	local function childChanged(child: Instance)
		if (child:IsA("BasePart") and limbNames[child.Name]) or child:IsA("Accessory") then
			task.defer(function()
				if rig.character.Parent then
					render(rig)
				end
			end)
		end
	end
	table.insert(rig.connections, character.ChildAdded:Connect(childChanged))
	table.insert(rig.connections, character.ChildRemoved:Connect(childChanged))
	render(rig)
end

local function watch(player: Player)
	playerConnections[player] = {
		player.CharacterAdded:Connect(function(character)
			characterAdded(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			clear(player)
		end),
	}
	if player.Character then
		characterAdded(player, player.Character)
	end
end

function ArmorVisual.Start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		clear(player)
		for _, connection in ipairs(playerConnections[player] or {}) do
			connection:Disconnect()
		end
		playerConnections[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	-- showcase mannequins (scripts/build-showcase.luau): the model itself is the key
	local function mannequin(model: Instance)
		if model:IsA("Model") then
			characterAdded(model, model)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("ArmorMannequin")) do
		mannequin(model)
	end
	CollectionService:GetInstanceAddedSignal("ArmorMannequin"):Connect(mannequin)
	CollectionService:GetInstanceRemovedSignal("ArmorMannequin"):Connect(clear)
	-- enchant glint shimmer: Decals have no UV offset, so pulse the purple overlay's transparency
	RunService.Heartbeat:Connect(function()
		local pulse = 0.45 + 0.25 * math.sin(os.clock() * 4)
		for _, rig in pairs(rigs) do
			local visual = rig.visual
			local glow = visual and visual:FindFirstChild("EnchantGlow")
			if glow and glow:IsA("Highlight") then
				glow.FillTransparency = 0.65 + 0.2 * math.sin(os.clock() * 3)
			end
		end
		for decal in pairs(glintDecals) do
			if decal.Parent then
				decal.Transparency = pulse
			else
				glintDecals[decal] = nil
			end
		end
	end)
end

return ArmorVisual
