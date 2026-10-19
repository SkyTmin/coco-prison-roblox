--!strict
-- Client: one "Harvest" action for mouse, touch button and gamepad; a minimal HUD;
-- target highlight. All results are confirmed by the server through ProfileUpdated/Toast.

local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)

local player = Players.LocalPlayer
local locale = Strings.localeOf(player)
local camera = workspace.CurrentCamera

local TARGET_RANGE = 24

-- HUD -----------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "PrisonHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(name: string, position: UDim2, size: UDim2, textSize: number): TextLabel
	local text = Instance.new("TextLabel")
	text.Name = name
	text.Position = position
	text.Size = size
	text.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
	text.BackgroundTransparency = 0.35
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextSize = textSize
	text.Font = Enum.Font.GothamMedium
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextWrapped = true
	text.Parent = gui
	return text
end

local status = label("Status", UDim2.fromOffset(12, 12), UDim2.fromOffset(320, 72), 16)
local toast = label("Toast", UDim2.new(0.5, -160, 1, -120), UDim2.fromOffset(320, 36), 16)
toast.TextXAlignment = Enum.TextXAlignment.Center
toast.Visible = false

local levelButton = Instance.new("TextButton")
levelButton.Name = "LevelUp"
levelButton.Position = UDim2.fromOffset(12, 90)
levelButton.Size = UDim2.fromOffset(200, 32)
levelButton.BackgroundColor3 = Color3.fromRGB(60, 110, 60)
levelButton.TextColor3 = Color3.new(1, 1, 1)
levelButton.TextSize = 16
levelButton.Font = Enum.Font.GothamMedium
levelButton.Text = Strings.t("level_up", locale)
levelButton.Parent = gui
levelButton.Activated:Connect(function()
	Remotes.event("LevelUp"):FireServer()
end)

local function renderProfile(profile: Types.Profile)
	local bag = {}
	for id, count in pairs(profile.inventory) do
		if count > 0 then
			table.insert(bag, string.format("%s %d", Strings.resourceLabel(id, locale), count))
		end
	end
	table.sort(bag)
	status.Text = string.format(
		"%s: %s    %s: %d\n%s: %s",
		Strings.t("coins", locale),
		Strings.money(profile.coins),
		Strings.t("level", locale),
		profile.level,
		Strings.t("bag", locale),
		if #bag > 0 then table.concat(bag, ", ") else Strings.t("empty", locale)
	)
end

Remotes.event("ProfileUpdated").OnClientEvent:Connect(renderProfile)

local toastToken = 0
Remotes.event("Toast").OnClientEvent:Connect(function(text: string)
	toastToken += 1
	local token = toastToken
	toast.Text = text
	toast.Visible = true
	task.delay(2.5, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end)

-- Targeting -----------------------------------------------------------------

local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.6
highlight.OutlineColor = Color3.fromRGB(255, 220, 80)
highlight.Enabled = false
highlight.Parent = gui

local function targetUnderCursor(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local origin: Vector3
	local direction: Vector3
	local preferred = UserInputService.PreferredInput
	if preferred == Enum.PreferredInput.KeyboardAndMouse then
		local mouse = UserInputService:GetMouseLocation()
		local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
		origin, direction = ray.Origin, ray.Direction * 200
	else
		local viewport = camera.ViewportSize
		local ray = camera:ViewportPointToRay(viewport.X / 2, viewport.Y / 2)
		origin, direction = ray.Origin, ray.Direction * 200
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local result = workspace:Raycast(origin, direction, params)
	if not result or not result.Instance:IsA("BasePart") then
		return nil
	end
	local part = result.Instance
	if not CollectionService:HasTag(part, "WorkNode") then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if
		root
		and root:IsA("BasePart")
		and (root.Position - part.Position).Magnitude > TARGET_RANGE
	then
		return nil
	end
	return part
end

local currentTarget: BasePart? = nil
RunService.RenderStepped:Connect(function()
	local target = targetUnderCursor()
	if target ~= currentTarget then
		currentTarget = target
		highlight.Adornee = target
		highlight.Enabled = target ~= nil
	end
end)

local function onHarvest(_actionName: string, state: Enum.UserInputState)
	if state ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	local target = currentTarget
	if not target then
		return Enum.ContextActionResult.Pass
	end
	local generation = target:GetAttribute("Generation")
	if typeof(generation) == "number" then
		Remotes.event("Harvest"):FireServer(target, generation)
	end
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(
	"Harvest",
	onHarvest,
	true,
	Enum.UserInputType.MouseButton1,
	Enum.KeyCode.ButtonR2,
	Enum.KeyCode.E
)
ContextActionService:SetTitle("Harvest", "⛏")
ContextActionService:SetPosition("Harvest", UDim2.fromScale(0.72, 0.55))

print(
	string.format(
		"[coco-prison] client ready, locale %s, %d resources",
		locale,
		#Config.raw.resources
	)
)
