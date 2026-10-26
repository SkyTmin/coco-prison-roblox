--!strict
-- Our player body [владелец 26.10: «выключить модельки тела у игрока и сделать свои… похожие как у Майна у всех
-- игроков»; «своя тюремная форма»; «делай лучше тело, броню сделаем по телу в будущем»]. Every player wears the same
-- Minecraft-proportioned block body in our prison uniform (assets/models/player/player.py -- export →
-- Shared.Models.player) instead of the Roblox avatar. The rig keeps the R15 part and joint names (Motor6D), so Roblox's
-- Animate, CharacterAnimator, HeldItem, ArmorVisual and the bow pose work on it as before. It goes to StarterPlayer as
-- StarterCharacter at server start. On spawn each character gets its look: the colours by role (skin tone, hair,
-- hairstyle, eyes, a beard — picked from the userId, so a player looks the same on every server), the pixel details
-- as thin plates on the faces (skin + hairstyle + beard + armband merged into one grid per face, then greedy
-- rectangles: no plates overlap), and the armband in the faction's colour while the player is in one (player
-- attribute Faction). The character carries BlockBody = true: CharacterAnimator keeps its limbs rigid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockFaces = require(Shared.BlockFaces)
local Config = require(Shared.Config)
local Body = require(Shared.Models.player) :: any

local AvatarService = {}
local started = false

local PX: number = Body.px -- studs per skin pixel
local PLATE = 0.02 -- studs: the detail plates stand this far out of the faces
-- the root part as wide and deep as a Roblox one: doors, gaps and ladders were built for it
local ROOT_SIZE = Vector3.new(2, Body.root.size[2] * PX, 1)
local COLLIDE = { Head = true, UpperTorso = true, LowerTorso = true }

local FACES = BlockFaces -- the face grids of player.py

local function vec(t: { number }): Vector3
	return Vector3.new(t[1], t[2], t[3])
end

local function abs(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

-- the face grid's width and height in pixels for a part of `size` px
local function faceDims(size: Vector3, face: string): (number, number)
	if face == "front" or face == "back" then
		return size.X, size.Y
	elseif face == "right" or face == "left" then
		return size.Z, size.Y
	end
	return size.X, size.Z
end

-- ---------------------------------------------------------------- the rig
local function buildTemplate(): Model
	local model = Instance.new("Model")
	model.Name = "StarterCharacter"
	local humanoid = Instance.new("Humanoid")
	humanoid.RigType = Enum.HumanoidRigType.R15
	humanoid.AutomaticScalingEnabled = false
	humanoid.HipHeight = Body.hipHeight * PX
	Instance.new("Animator").Parent = humanoid
	humanoid.Parent = model
	local parts: { [string]: BasePart } = {}
	local centres: { [string]: Vector3 } = {}
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = ROOT_SIZE
	root.Transparency = 1
	centres.HumanoidRootPart = vec(Body.root.pos)
	root.CFrame = CFrame.new(centres.HumanoidRootPart * PX)
	local attachment = Instance.new("Attachment")
	attachment.Name = "RootAttachment"
	attachment.Parent = root
	root.Parent = model
	parts.HumanoidRootPart = root
	model.PrimaryPart = root
	for name, data in pairs(Body.parts) do
		local part = Instance.new("Part")
		part.Name = name
		part.Size = vec(data.size) * PX
		centres[name] = vec(data.pos)
		part.CFrame = CFrame.new(centres[name] * PX)
		part.Material = Enum.Material.SmoothPlastic
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		part.CanCollide = COLLIDE[name] == true
		part:SetAttribute("Role", data.base)
		part.Parent = model
		parts[name] = part
	end
	for _, joint in ipairs(Body.joints) do
		local name, from, to, pivot = joint[1], joint[2], joint[3], vec(joint[4])
		local motor = Instance.new("Motor6D")
		motor.Name = name
		motor.Part0, motor.Part1 = parts[from], parts[to]
		motor.C0 = CFrame.new((pivot - centres[from]) * PX)
		motor.C1 = CFrame.new((pivot - centres[to]) * PX)
		motor.Parent = parts[to]
	end
	model:SetAttribute("BlockBody", true)
	return model
end

-- ---------------------------------------------------------------- one player's look
type Look = { colours: { [string]: Color3 }, layers: { string } }

local function hex(s: string): Color3
	return Color3.fromHex(s)
end

local function lookOf(player: Player): Look
	local random = Random.new(math.abs(player.UserId) + 7919)
	local palettes = Body.palettes
	local skin = random:NextInteger(1, #palettes.skin)
	local hair = random:NextInteger(1, #palettes.hair)
	local iris = random:NextInteger(1, #palettes.iris)
	-- hairstyles [решение]: short 35 %, buzz 25 %, fringe 25 %, bald 15 %; a beard one in five
	local roll = random:NextNumber()
	local style = if roll < 0.35
		then "short"
		elseif roll < 0.6 then "buzz"
		elseif roll < 0.85 then "fringe"
		else "bald"
	local beard = random:NextNumber() < 0.2
	local colours: { [string]: Color3 } = {}
	for role, value in pairs(Body.fixed) do
		colours[role] = hex(value)
	end
	colours.skin = hex(palettes.skin[skin])
	colours.skin_dark = hex(palettes.skin_dark[skin])
	colours.mouth = hex(palettes.mouth[skin])
	colours.hair = hex(palettes.hair[hair])
	colours.hair_dark = hex(palettes.hair_dark[hair])
	colours.brow = colours.hair_dark
	colours.iris = hex(palettes.iris[iris])
	local layers = {}
	if style ~= "bald" then
		table.insert(layers, "hair_" .. style)
	end
	if beard then
		table.insert(layers, "beard")
	end
	return { colours = colours, layers = layers }
end

-- the plates of one part: its base rects with the active layers painted over, merged per face
local function paint(part: BasePart, name: string, look: Look, faction: string?)
	for _, child in ipairs(part:GetChildren()) do
		if child.Name == "Px" then
			child:Destroy()
		end
	end
	local data = Body.parts[name]
	local base: string = data.base
	part.Color = look.colours[base] or Color3.new(1, 0, 1)
	local size = vec(data.size)
	local layers = table.clone(look.layers)
	if faction then
		table.insert(layers, "armband")
	end
	local colours = look.colours
	if faction then
		colours = table.clone(colours)
		colours.faction = Config.factionColor(faction)
	end
	local half = part.Size / 2
	for face, geometry in pairs(FACES) do
		local w, h = faceDims(size, face)
		local grid: { { string } } = {}
		for r = 1, h do
			grid[r] = table.create(w, base)
		end
		local painted = false
		local function put(rects: { { any } }?)
			for _, rect in ipairs(rects or {}) do
				local c, r, rw, rh, role = rect[1], rect[2], rect[3], rect[4], rect[5]
				for y = r + 1, r + rh do
					for x = c + 1, c + rw do
						grid[y][x] = role
					end
				end
				painted = true
			end
		end
		put(data.faces[face])
		for _, layer in ipairs(layers) do
			local onPart = Body.layers[layer][name]
			put(onPart and onPart[face])
		end
		if not painted then
			continue
		end
		-- greedy rectangles of everything that is not the base colour
		local done: { { boolean } } = {}
		for r = 1, h do
			done[r] = table.create(w, false)
		end
		local origin = geometry.tl * half
		for r = 1, h do
			for c = 1, w do
				local role = grid[r][c]
				if done[r][c] or role == base then
					continue
				end
				local rw = 1
				while c + rw <= w and not done[r][c + rw] and grid[r][c + rw] == role do
					rw += 1
				end
				local rh = 1
				while r + rh <= h do
					local same = true
					for i = 0, rw - 1 do
						if done[r + rh][c + i] or grid[r + rh][c + i] ~= role then
							same = false
							break
						end
					end
					if not same then
						break
					end
					rh += 1
				end
				for y = r, r + rh - 1 do
					for x = c, c + rw - 1 do
						done[y][x] = true
					end
				end
				local plate = Instance.new("Part")
				plate.Name = "Px"
				plate.Size = abs(geometry.right) * rw * PX
					+ abs(geometry.down) * rh * PX
					+ abs(geometry.normal) * PLATE
				local centre = origin
					+ geometry.right * (c - 1 + rw / 2) * PX
					+ geometry.down * (r - 1 + rh / 2) * PX
					+ geometry.normal * PLATE / 2
				plate.CFrame = part.CFrame * CFrame.new(centre)
				plate.Color = colours[role] or Color3.new(1, 0, 1)
				plate.Material = Enum.Material.SmoothPlastic
				plate.TopSurface, plate.BottomSurface =
					Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
				plate.CanCollide, plate.CanQuery, plate.CanTouch = false, false, false
				plate.Massless = true
				plate.CastShadow = false
				local weld = Instance.new("WeldConstraint")
				weld.Part0, weld.Part1 = part, plate
				weld.Parent = plate
				plate.Parent = part
			end
		end
	end
end

local function factionOf(player: Player): string?
	local faction = player:GetAttribute("Faction")
	return if typeof(faction) == "string" and faction ~= "" then faction else nil
end

local looks: { [Player]: Look } = {}

local function dress(player: Player, character: Model)
	if character:GetAttribute("BlockBody") ~= true then
		return
	end
	local look = looks[player] or lookOf(player)
	looks[player] = look
	local faction = factionOf(player)
	for name in pairs(Body.parts) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			paint(part, name, look, faction)
		end
	end
end

-- the armband follows the faction: repaint only the parts it lies on
local function refreshArmband(player: Player)
	local character = player.Character
	local look = looks[player]
	if not character or not look or character:GetAttribute("BlockBody") ~= true then
		return
	end
	for name in pairs(Body.layers.armband) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			paint(part, name, look, factionOf(player))
		end
	end
end

function AvatarService.Start()
	if started then
		return
	end
	started = true
	local old = StarterPlayer:FindFirstChild("StarterCharacter")
	if old then
		old:Destroy()
	end
	StarterPlayer.LoadCharacterAppearance = false
	buildTemplate().Parent = StarterPlayer
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			dress(player, character)
		end)
		player:GetAttributeChangedSignal("Faction"):Connect(function()
			refreshArmband(player)
		end)
		local character = player.Character
		if character and character:GetAttribute("BlockBody") ~= true then
			-- spawned with the Roblox avatar before the template existed (Studio): respawn in our body
			task.defer(function()
				if player.Parent then
					player:LoadCharacter()
				end
			end)
		elseif character then
			dress(player, character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		looks[player] = nil
	end)
end

return AvatarService
