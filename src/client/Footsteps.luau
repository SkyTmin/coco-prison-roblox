--!strict
-- Footsteps like Minecraft [владелец 21.10: звуки VoxeLibre]: Roblox's own running sound is muted and
-- every character (this client hears everyone nearby) plays the step sound of the block under its feet
-- every STRIDE studs walked — mine blocks by their sound type (sounds.blockMaterial), the map by its
-- part material / px_* texture / terrain material, water while swimming.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Sfx = require(Shared.Sfx)

local Footsteps = {}

local STRIDE = 7 -- studs per step (≈ 1.75 blocks; Minecraft walks ~2 steps a second)
local HEAR = 48
local VOLUME = 0.22

-- Roblox materials / px_* texture names → Minecraft sound type
local BY_MATERIAL: { [Enum.Material]: string } = {
	[Enum.Material.Grass] = "grass",
	[Enum.Material.LeafyGrass] = "grass",
	[Enum.Material.Sand] = "sand",
	[Enum.Material.Sandstone] = "sand",
	[Enum.Material.Wood] = "wood",
	[Enum.Material.WoodPlanks] = "wood",
	[Enum.Material.Ground] = "gravel",
	[Enum.Material.Mud] = "gravel",
	[Enum.Material.Pebble] = "gravel",
	[Enum.Material.Metal] = "metal",
	[Enum.Material.DiamondPlate] = "metal",
	[Enum.Material.CorrodedMetal] = "metal",
	[Enum.Material.Foil] = "metal",
	[Enum.Material.Fabric] = "wool",
	[Enum.Material.Carpet] = "wool",
	[Enum.Material.Glass] = "glass",
	[Enum.Material.Ice] = "ice",
	[Enum.Material.Glacier] = "ice",
	[Enum.Material.Snow] = "snow",
	[Enum.Material.Water] = "water",
}
local BY_TEXTURE: { { word: string, kind: string } } = {
	{ word = "sand", kind = "sand" },
	{ word = "grass", kind = "grass" },
	{ word = "leaves", kind = "grass" },
	{ word = "plank", kind = "wood" },
	{ word = "log", kind = "wood" },
	{ word = "wood", kind = "wood" },
	{ word = "dirt", kind = "gravel" },
	{ word = "gravel", kind = "gravel" },
	{ word = "wool", kind = "wool" },
	{ word = "glass", kind = "glass" },
	{ word = "ice", kind = "ice" },
	{ word = "snow", kind = "snow" },
}

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function stepSound(kind: string): string
	local sounds = Config.effects and Config.effects.sounds
	local materials = sounds and sounds.materials
	local entry = materials and (materials[kind] or materials.stone)
	return if entry and entry.step then entry.step else "stone_hit"
end

-- [владелец 23.10: «выключи этот неприятный звук, когда ходишь» — Преисподняя, Пирамида] a location root folder
-- with the attribute SilentSteps (and LocationId) mutes the steps on its map and on the blocks of its mine
local function silent(part: Instance): boolean
	local node: Instance? = part
	while node and node ~= workspace do
		if node:GetAttribute("SilentSteps") == true then
			return true
		end
		node = node.Parent
	end
	local mineId = part:GetAttribute("MineId")
	if typeof(mineId) == "string" then
		for _, child in ipairs(workspace:GetChildren()) do
			if
				child:GetAttribute("SilentSteps") == true
				and child:GetAttribute("LocationId") == mineId
			then
				return true
			end
		end
	end
	return false
end

local function kindUnder(character: Model, root: BasePart, humanoid: Humanoid): string?
	if humanoid:GetState() == Enum.HumanoidStateType.Swimming then
		return "water"
	end
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -5, 0), params)
	if not hit then
		return "stone"
	end
	local part = hit.Instance
	if silent(part) then
		return nil
	end
	local blockId = part:GetAttribute("Block")
	if typeof(blockId) == "string" then
		local map = Config.effects and Config.effects.sounds and Config.effects.sounds.blockMaterial
		return (map and (map[blockId] or map._default)) or "stone"
	end
	if part:IsA("BasePart") and part.MaterialVariant ~= "" then
		local variant = string.lower(part.MaterialVariant)
		for _, entry in ipairs(BY_TEXTURE) do
			if string.find(variant, entry.word, 1, true) then
				return entry.kind
			end
		end
	end
	return BY_MATERIAL[hit.Material] or "stone"
end

function Footsteps.Start()
	local walked: { [Model]: number } = {}
	local last: { [Model]: Vector3 } = {}
	RunService.Heartbeat:Connect(function()
		local camera = workspace.CurrentCamera
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not character or not humanoid or not root or not root:IsA("BasePart") then
				continue
			end
			-- mute Roblox's running sound (RbxCharacterSounds re-plays it, so keep it silent)
			local running = root:FindFirstChild("Running")
			if running and running:IsA("Sound") and running.Volume ~= 0 then
				running.Volume = 0
			end
			if camera and (camera.CFrame.Position - root.Position).Magnitude > HEAR then
				last[character] = root.Position
				continue
			end
			local position = root.Position
			local previous = last[character] or position
			last[character] = position
			local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
				or humanoid:GetState() == Enum.HumanoidStateType.Swimming
			if not grounded or humanoid.Health <= 0 then
				continue
			end
			local flat = Vector3.new(position.X - previous.X, 0, position.Z - previous.Z).Magnitude
			if flat > 20 then
				continue -- teleport, not walking
			end
			walked[character] = (walked[character] or 0) + flat
			if walked[character] >= STRIDE then
				walked[character] = 0
				local kind = kindUnder(character, root, humanoid)
				if kind then
					Sfx.play(stepSound(kind), root, VOLUME)
				end
			end
		end
		for character in pairs(last) do
			if not character.Parent then
				last[character], walked[character] = nil, nil
			end
		end
	end)
end

return Footsteps
