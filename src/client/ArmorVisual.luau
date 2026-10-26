--!strict
-- Armor rendered the Minecraft way: a textured box slightly larger than each limb, welded to it, with
-- the faces of the Minecraft armor layer (Pixel Perfection via VoxeLibre, CC BY-SA 4.0 — see
-- assets/thirdparty/voxelibre/ATTRIBUTION.md) as Decals. Faces come from Config.armor (generated from
-- assets/armor/ids.json). Enchanted pieces (level with an enchant > 0) get a purple glint overlay.
-- The server owns the `Armor` attribute ("helmet:<level>,chestplate:<level>,...").
-- Our block body (character attribute BlockBody, AvatarService) wears our own armor [владелец 26.10: «броню сделаем по
-- телу»; «броню делаем новую в блендер: кожаная, кольчужная, железная и алмазная»; «бери пример с майна»]
-- (assets/models/armor/armor.py → assets/armor/block/*.png → Config.armor.block, faces named as Roblox's). It sits as
-- Minecraft's: each box wraps a whole limb grown by 1 px on every side (leggings ½ px, the inner layer, so the
-- chestplate and the boots cover them) and covers rows r0..r1 of it. The limbs never bend (CharacterAnimator), so a box
-- may run past its part onto the next one (the lower arm's over the hand, the boots up the shin). Until our faces are
-- uploaded the block body wears the VoxeLibre ones on the same boxes. R15 avatars (showcase mannequins) keep the old
-- per-part boxes.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Body = require(Shared.Models.player) :: any

type Rig = { character: Model, connections: { RBXScriptConnection }, visual: Model? }

local ArmorVisual = {}
local rigs: { [Instance]: Rig } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local started = false
local glintDecals: { [Decal]: number } = {} -- glint overlay → its phase (the box's height: the shimmer runs down)

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
-- the block body's boxes (assets/models/armor/armor.py BOXES): the part, the rows a0..a1 of the limb it holds, the
-- limb (length × width × depth px), the texture key, the rows r0..r1 the box covers, the growth per side in px
type BlockBox = {
	part: string,
	a0: number,
	a1: number,
	length: number,
	width: number,
	depth: number,
	key: string,
	r0: number,
	r1: number,
	grow: number,
}
local function blockBox(
	part: string,
	a0: number,
	a1: number,
	key: string,
	r0: number,
	r1: number,
	grow: number
): BlockBox
	local head, body = key == "head", key == "torsoupper" or key == "torsolower" or key == "torso"
	return {
		part = part,
		a0 = a0,
		a1 = a1,
		length = if head then 8 else 12,
		width = if head or body then 8 else 4,
		depth = if head then 8 else 4,
		key = key,
		r0 = r0,
		r1 = r1,
		grow = grow,
	}
end
local BLOCK_BOXES: { [string]: { BlockBox } } = {
	helmet = { blockBox("Head", 0, 8, "head", 0, 8, 1) },
	chestplate = {
		blockBox("UpperTorso", 0, 8, "torsoupper", 0, 8, 1),
		blockBox("LowerTorso", 8, 12, "torsolower", 8, 12, 1),
	},
	leggings = { blockBox("LowerTorso", 8, 12, "torso", 6, 12, 0.5) },
	boots = {},
}
for _, side in ipairs({ "Right", "Left" }) do
	table.insert(BLOCK_BOXES.chestplate, blockBox(side .. "UpperArm", 0, 6, "upperarm", 0, 6, 1))
	table.insert(BLOCK_BOXES.chestplate, blockBox(side .. "LowerArm", 6, 10, "lowerarm", 6, 12, 1))
	table.insert(BLOCK_BOXES.leggings, blockBox(side .. "UpperLeg", 0, 6, "upperleg", 0, 6, 0.5))
	table.insert(BLOCK_BOXES.leggings, blockBox(side .. "LowerLeg", 6, 10, "lowerleg", 6, 12, 0.5))
	table.insert(BLOCK_BOXES.boots, blockBox(side .. "Foot", 10, 12, "foot", 9, 12, 1))
end
for _, boxes in pairs(BLOCK_BOXES) do
	for _, box in ipairs(boxes) do
		limbNames[box.part] = true
	end
end
-- our faces are named as Roblox's (right = +X, the character's right)
local OWN_FACES: { [string]: Enum.NormalId } = {
	front = Enum.NormalId.Front,
	back = Enum.NormalId.Back,
	right = Enum.NormalId.Right,
	left = Enum.NormalId.Left,
	top = Enum.NormalId.Top,
	bottom = Enum.NormalId.Bottom,
}

local function faceTexture(piece: string, material: string, key: string, face: string): string?
	local faces = Config.armor and Config.armor.faces
	if not faces then
		return nil
	end
	return faces[piece .. "_" .. material .. "_" .. key .. "_" .. face]
end

-- the face images of one box: { [Roblox face]: { texture, glint } } — our own on the block body once uploaded (each
-- face with its own glint mask: the enchant shimmer lies only on the armor's pixels [владелец 26.10: «не забывай за
-- зачарования эффект»]), else VoxeLibre's with the shared glint over the whole face
type FaceImages = { texture: string, glint: string }
local function boxTextures(
	piece: string,
	material: string,
	key: string,
	own: boolean
): { [Enum.NormalId]: FaceImages }
	local out: { [Enum.NormalId]: FaceImages } = {}
	local armor = Config.armor :: any
	local fallbackGlint: string = armor and armor.glint or ""
	local block = own and armor and armor.block
	if block then
		local glints = armor.blockGlint or {}
		for face, normal in pairs(OWN_FACES) do
			local name = piece .. "_" .. material .. "_" .. key .. "_" .. face
			if block[name] then
				out[normal] = { texture = block[name], glint = glints[name] or fallbackGlint }
			end
		end
		-- our set has no face here (only chainmail has lower sleeves): no box, never VoxeLibre's with the
		-- shared glint over the bare skin
		return out
	end
	for face, normal in pairs(FACES) do
		local texture = faceTexture(piece, material, key, face)
		if texture then
			out[normal] = { texture = texture, glint = fallbackGlint }
		end
	end
	return out
end

local function enchanted(id: string, level: number): boolean
	local ok, value = pcall(Config.enchantForLevel, id, level)
	return ok and type(value) == "number" and value > 0
end

-- one textured box welded to the limb: `size` in studs, its centre `centreY` studs above the limb's centre
local function makeBox(
	parent: Model,
	limb: BasePart,
	piece: string,
	material: string,
	key: string,
	size: Vector3,
	centreY: number,
	glint: boolean,
	own: boolean
)
	local part = Instance.new("Part")
	part.Name = piece .. "_" .. limb.Name
	part.Size = size
	part.Transparency = 1 -- faces are drawn by the decals; the part itself is invisible
	part.Massless = true
	part.CanCollide, part.CanTouch, part.CanQuery = false, false, false
	part.CastShadow = true
	part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local offset = CFrame.new(0, centreY, 0)
	part.CFrame = limb.CFrame * offset
	local any = false
	for normal, images in pairs(boxTextures(piece, material, key, own)) do
		local decal = Instance.new("Decal")
		decal.Name = normal.Name
		decal.Face = normal
		decal.Texture = images.texture
		decal.Parent = part
		any = true
		if glint then
			local g = Instance.new("Decal")
			g.Name = "Glint"
			g.Face = normal
			g.Texture = images.glint
			g.Transparency = 0.55
			g.Color3 = Color3.fromRGB(200, 120, 255)
			g.ZIndex = 2
			g.Parent = part
			glintDecals[g] = part.Position.Y
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

-- an R15 avatar's box: the part grown by `pad`, the slice y0..y1 of its height
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
	local size = Vector3.new(limb.Size.X + pad, height, limb.Size.Z + pad)
	makeBox(parent, limb, piece, material, box.key, size, centreY, glint, false)
end

-- a block body's box: the limb grown by `grow` px a side, rows r0..r1 of it; the part holds rows a0..a1
local function buildBlockBox(
	parent: Model,
	limb: BasePart,
	piece: string,
	material: string,
	box: BlockBox,
	glint: boolean
)
	local px: number = Body.px
	local grown = box.length + 2 * box.grow
	local top = (box.a0 + box.a1) / 2 + box.grow -- the grown limb's top, px above the part's centre
	local y0 = top - grown * box.r0 / box.length
	local y1 = top - grown * box.r1 / box.length
	local size = Vector3.new(box.width + 2 * box.grow, y0 - y1, box.depth + 2 * box.grow) * px
	makeBox(parent, limb, piece, material, box.key, size, (y0 + y1) / 2 * px, glint, true)
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
	local block = rig.character:GetAttribute("BlockBody") == true
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
		if block then
			for _, box in ipairs(BLOCK_BOXES[id] or {}) do
				local limb = rig.character:FindFirstChild(box.part)
				if limb and limb:IsA("BasePart") then
					buildBlockBox(visual, limb, id, material, box, glint)
				end
			end
		else
			for _, box in ipairs(boxes) do
				local limb = rig.character:FindFirstChild(box.limb)
				if limb and limb:IsA("BasePart") then
					buildBox(visual, limb, id, material, box, glint)
				end
			end
		end
	end
	if anyGlint and not block then
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
	-- enchant glint shimmer: Decals have no UV offset, so the purple overlay's transparency pulses in a wave that runs
	-- down the body (the phase is each box's height), like Minecraft's sweeping glint
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, rig in pairs(rigs) do
			local visual = rig.visual
			local glow = visual and visual:FindFirstChild("EnchantGlow")
			if glow and glow:IsA("Highlight") then
				glow.FillTransparency = 0.65 + 0.2 * math.sin(os.clock() * 3)
			end
		end
		for decal, phase in pairs(glintDecals) do
			if decal.Parent then
				decal.Transparency = 0.2 + 0.55 * (0.5 + 0.5 * math.sin(now * 3.5 + phase * 1.6))
			else
				glintDecals[decal] = nil
			end
		end
	end)
end

return ArmorVisual
