--!strict
-- All clients render the server-owned HeldItem attribute; no physical Tools or gameplay state.
local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)
local ItemModels = require(script.Parent:WaitForChild("ItemModels"))

type Rig = { character: Model, connections: { RBXScriptConnection }, visual: Instance? }
local HeldItem = {}
local rigs: { [Instance]: Rig } = {}
local playerConnections: { [Player]: { RBXScriptConnection } } = {}
local swing = Instance.new("NumberValue")
local swingTween: Tween? = nil
local started = false
local posed: { [Motor6D]: CFrame } = {}
local enchantedParts: { [BasePart]: Color3 } = {} -- part → base colour, pulsed toward purple
local GLINT = Color3.fromRGB(170, 90, 255)
local visibleArms: { [BasePart]: boolean } = {}

function HeldItem.SetDigging(active: boolean)
	if active == (swingTween ~= nil) then
		return
	end
	if swingTween then
		swingTween:Cancel()
		swingTween = nil
	end
	swing.Value = 0
	if active then
		local tween = TweenService:Create(
			swing,
			TweenInfo.new(0.125, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Value = 1 }
		)
		swingTween = tween
		tween:Play()
	end
end

local function rightHand(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

local function render(rig: Rig)
	if rig.visual then
		rig.visual:Destroy()
		rig.visual = nil
	end
	local attribute = rig.character:GetAttribute("HeldItem")
	local hand = rightHand(rig.character)
	if typeof(attribute) ~= "string" or attribute == "" or not hand then
		return
	end
	local id, rawLevel = string.match(attribute, "^([^:]+):(%d+)$")
	if not id then
		return
	end
	local level = tonumber(rawLevel) or 0
	local icon = Config.iconFor(id, if level > 0 then level else nil)
	local block = Config.block(id)
	local cube = block ~= nil and not block.itemOnly
	local tool = Config.tools[id] ~= nil
	local spriteSize = if tool then 1.45 else 1.2
	local visual: BasePart
	local container: Instance
	if cube then
		local p = Instance.new("Part")
		p.Name = "HeldItemVisual"
		p.Size = Vector3.new(1.2, 1.2, 1.2)
		p.Material = Enum.Material.Plastic
		if MaterialService:FindFirstChild("px_" .. id) then
			p.MaterialVariant = "px_" .. id
		else
			local texture = Config.textures.textures[id]
			if texture then
				for _, face in ipairs(Enum.NormalId:GetEnumItems()) do
					local decal = Instance.new("Decal")
					decal.Face, decal.Texture, decal.Parent = face, texture, p
				end
			end
		end
		visual, container = p, p
	else
		local model = ItemModels.get(id, if level > 0 then level else nil, spriteSize)
		if not model then
			-- no sprite data: fall back to a flat icon plane
			local p = Instance.new("Part")
			p.Name = "HeldItemVisual"
			p.Size = Vector3.new(0.1, spriteSize, spriteSize)
			p.Transparency = 1
			if icon then
				for _, face in ipairs({ Enum.NormalId.Left, Enum.NormalId.Right }) do
					local decal = Instance.new("Decal")
					decal.Face, decal.Texture, decal.Parent = face, icon, p
				end
			end
			visual, container = p, p
		else
			model.Name = "HeldItemVisual"
			visual, container = model.PrimaryPart :: BasePart, model
			if Config.isEnchanted(id, if level > 0 then level else nil) then
				for _, px in ipairs(model:GetChildren()) do
					if px:IsA("BasePart") and px.Name == "Px" then
						enchantedParts[px] = px.Color
					end
				end
			end
		end
	end
	visual.CanCollide, visual.CanTouch, visual.CanQuery = false, false, false
	visual.Massless = true
	visual.CastShadow = false
	local motor = Instance.new("Motor6D")
	motor.Name = "HeldItemGrip"
	motor.Part0, motor.Part1 = hand, visual
	if cube then
		motor.C0 = CFrame.new(0.2, -0.5, -0.9) * CFrame.Angles(0, math.rad(25), 0)
	else
		local size = spriteSize
		-- Tuned on the live character (21.10): sprite model has image-right = +Z, so yaw it 180° to
		-- point the head forward (hand −Z); handle end (bottom-left of the icon) sits in the palm.
		motor.C0 = CFrame.new(0.3, -0.3, -0.2)
			* CFrame.Angles(math.rad(-20), 0, 0)
			* CFrame.Angles(0, math.pi, 0)
			* CFrame.new(0, size * 0.45, size * 0.45)
	end
	visual.CFrame = hand.CFrame * motor.C0
	motor.Parent = visual
	container.Parent = rig.character
	rig.visual = container
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
		character:GetAttributeChangedSignal("HeldItem"):Connect(function()
			render(rig)
		end)
	)
	table.insert(
		rig.connections,
		character.DescendantAdded:Connect(function(descendant)
			if
				descendant.Name == "RightHand"
				or descendant.Name == "Right Arm"
				or descendant.Name == "RightGripAttachment"
			then
				render(rig)
			end
		end)
	)
	render(rig)
end

local function watch(player: Player)
	playerConnections[player] = {
		player.CharacterAdded:Connect(function(character)
			characterAdded(player, character)
		end),
		player.CharacterRemoving:Connect(function()
			clear(player)
			if player == Players.LocalPlayer then
				HeldItem.SetDigging(false)
			end
		end),
	}
	if player.Character then
		characterAdded(player, player.Character)
	end
end

function HeldItem.Start()
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
	local function mannequin(model: Instance)
		if model:IsA("Model") then
			characterAdded(model, model)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("HeldMannequin")) do
		mannequin(model)
	end
	CollectionService:GetInstanceAddedSignal("HeldMannequin"):Connect(mannequin)
	CollectionService:GetInstanceRemovedSignal("HeldMannequin"):Connect(clear)
	RunService.Heartbeat:Connect(function()
		local k = 0.2 + 0.25 * (0.5 + 0.5 * math.sin(os.clock() * 4))
		for px, base in pairs(enchantedParts) do
			if px.Parent then
				px.Color = base:Lerp(GLINT, k)
			else
				enchantedParts[px] = nil
			end
		end
	end)
	RunService:BindToRenderStep("HeldItemPose", Enum.RenderPriority.Camera.Value + 2, function()
		-- Restore our offsets before applying this frame's pose; never accumulate rotations.
		for motor, base in pairs(posed) do
			if motor.Parent then
				motor.C0 = base
			end
		end
		table.clear(posed)
		local character = Players.LocalPlayer.Character
		local camera = workspace.CurrentCamera
		local head = character and character:FindFirstChild("Head")
		local firstPerson = camera ~= nil
			and head ~= nil
			and head:IsA("BasePart")
			and (camera.CFrame.Position - head.Position).Magnitude < 1
		for arm in pairs(visibleArms) do
			if arm.Parent then
				arm.LocalTransparencyModifier = if firstPerson then 1 else 0
			end
		end
		table.clear(visibleArms)
		if not character then
			return
		end
		local hand = rightHand(character)
		for _, descendant in ipairs(character:GetDescendants()) do
			if descendant:IsA("Motor6D") and descendant.Part1 then
				if descendant.Part1 == hand then
					posed[descendant] = descendant.C0
					descendant.C0 *= CFrame.Angles(
						math.rad(-35) * swing.Value,
						0,
						math.rad(15) * swing.Value
					)
				elseif
					firstPerson
					and descendant.Name == "RightShoulder"
					and camera
					and descendant.Part0
				then
					local base = descendant.C0
					posed[descendant] = base
					local look = descendant.Part0.CFrame:ToObjectSpace(camera.CFrame).Rotation
					descendant.C0 = CFrame.new(base.Position)
						* look
						* base.Rotation
						* CFrame.Angles(math.rad(85 - 15 * swing.Value), 0, math.rad(-10))
				end
			elseif
				descendant:IsA("BasePart")
				and firstPerson
				and table.find(
					{ "RightHand", "RightLowerArm", "RightUpperArm", "Right Arm", "HeldItemVisual" },
					descendant.Name
				)
			then
				descendant.LocalTransparencyModifier = 0
				visibleArms[descendant] = true
			end
		end
	end)
end

return HeldItem
