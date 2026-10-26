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
local Config = require(Shared.Config)
local BlockBody = require(script.Parent.BlockBody)
local Body = BlockBody.Body

local AvatarService = {}
local started = false

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
	local data = Body.parts[name]
	local layers = table.clone(look.layers)
	local colours = look.colours
	if faction then
		table.insert(layers, "armband")
		colours = table.clone(colours)
		colours.faction = Config.factionColor(faction)
	end
	local lists = {}
	for face in pairs(BlockBody.Faces) do
		local list = { data.faces[face] }
		for _, layer in ipairs(layers) do
			local onPart = Body.layers[layer][name]
			table.insert(list, onPart and onPart[face])
		end
		lists[face] = list
	end
	BlockBody.paint(part, BlockBody.vec(data.size), data.base, lists, colours, false)
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
	BlockBody.build("StarterCharacter").Parent = StarterPlayer
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
