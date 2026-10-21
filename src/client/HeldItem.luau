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
local posed: { [Motor6D]: CFrame } = {} -- motor → its unposed C0
local enchantedParts: { [BasePart]: Color3 } = {} -- part → base colour, pulsed toward purple
local GLINT = Color3.fromRGB(170, 90, 255)

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

-- One attack swing like Minecraft's arm swing (about 6 ticks there); ignored while digging.
-- 0..1 while the arm swings (digging loop or a single hit); FirstPersonHand animates with it
function HeldItem.SwingAmount(): number
	return swing.Value
end

function HeldItem.Swing()
	if swingTween then
		return
	end
	swing.Value = 0
	local tween = TweenService:Create(
		swing,
		TweenInfo.new(0.15, Enum.EasingStyle.Sine, Enum.EasingDirection.Out, 0, true),
		{ Value = 1 }
	)
	swingTween = tween
	tween.Completed:Once(function()
		if swingTween == tween then
			swingTween = nil
			swing.Value = 0
		end
	end)
	tween:Play()
end

local function rightHand(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

-- The held item as a model: a textured cube for blocks, the extruded sprite for items (ItemModels),
-- a flat icon plane when there is no sprite. Used for characters and the first-person hand.
function HeldItem.MakeVisual(
	id: string,
	level: number,
	spriteScale: number?
): (Instance, BasePart, boolean)
	local icon = Config.iconFor(id, if level > 0 then level else nil)
	local block = Config.block(id)
	local cube = block ~= nil and not block.itemOnly
	local tool = Config.tools[id] ~= nil
	local spriteSize = (if tool then 1.45 else 1.2) * (spriteScale or 1)
	local visual: BasePart
	local container: Instance
	if cube then
		local p = Instance.new("Part")
		p.Name = "HeldItemVisual"
		p.Size = Vector3.one * 1.2 * (spriteScale or 1)
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
				local glow = Instance.new("Highlight")
				glow.Name = "EnchantGlow"
				glow.FillColor = Color3.fromRGB(190, 110, 255)
				glow.FillTransparency = 0.6
				glow.OutlineColor = Color3.fromRGB(230, 180, 255)
				glow.OutlineTransparency = 0.5
				glow.DepthMode = Enum.HighlightDepthMode.Occluded
				glow.Adornee = model
				glow.Parent = model
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
	return container, visual, cube
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
	local tool = Config.tools[id] ~= nil
	local spriteSize = if tool then 1.45 else 1.2
	local container, visual, cube = HeldItem.MakeVisual(id, level)
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
		local fill = 0.55 + 0.25 * math.sin(os.clock() * 3)
		for _, rig in pairs(rigs) do
			local visual = rig.visual
			local glow = visual and visual:FindFirstChild("EnchantGlow")
			if glow and glow:IsA("Highlight") then
				glow.FillTransparency = fill
				glow.OutlineTransparency = 0.3 + 0.4 * (0.5 + 0.5 * math.sin(os.clock() * 5))
			end
		end
		for px, base in pairs(enchantedParts) do
			if px.Parent then
				px.Color = base:Lerp(GLINT, k)
			else
				enchantedParts[px] = nil
			end
		end
	end)
	-- Current Roblox avatars are rigged with AnimationConstraints (no C0): the swing goes into the
	-- shoulder's Transform after the Animator wrote this frame's pose and before physics moves the arm.
	-- If the Animator did not rewrite it (no track on the joint), start from our own base again.
	local lastSet: CFrame? = nil
	local lastBase = CFrame.identity
	RunService.PreSimulation:Connect(function()
		local character = Players.LocalPlayer.Character
		local upperArm = character and character:FindFirstChild("RightUpperArm")
		local joint = upperArm and upperArm:FindFirstChild("RightShoulder")
		if not joint or not joint:IsA("AnimationConstraint") then
			lastSet = nil
			return
		end
		local current = joint.Transform
		if lastSet and current == lastSet then
			current = lastBase
		end
		local s = swing.Value
		if s > 0 then
			local turned = current * CFrame.Angles(math.rad(80) * s, 0, math.rad(-20) * s)
			lastBase, lastSet = current, turned
			joint.Transform = turned
		elseif lastSet then
			joint.Transform = current
			lastSet = nil
		end
	end)
	RunService:BindToRenderStep("HeldItemPose", Enum.RenderPriority.Last.Value, function()
		-- Restore our offsets before applying this frame's pose; never accumulate rotations.
		for motor, base in pairs(posed) do
			if motor.Parent then
				motor.C0 = base
			end
		end
		table.clear(posed)
		-- first person is drawn by FirstPersonHand (a Minecraft-style hand at the camera)
		local character = Players.LocalPlayer.Character
		if not character then
			return
		end
		-- the whole arm swings forward from the shoulder like Minecraft's (the wrist alone was barely visible)
		local upperArm = character:FindFirstChild("RightUpperArm") or rightHand(character)
		local s = swing.Value
		if s > 0 and upperArm then
			local turn = CFrame.Angles(math.rad(80) * s, 0, math.rad(-20) * s)
			for _, descendant in ipairs(character:GetDescendants()) do
				if descendant:IsA("Motor6D") and descendant.Part1 == upperArm then
					posed[descendant] = descendant.C0
					descendant.C0 *= turn
				end
			end
		end
	end)
end

return HeldItem
