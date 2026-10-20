--!strict
-- Client: digging input (hold on PC / touch button / gamepad), target highlight with progress,
-- HUD (right stats panel, hotkeys), hotbar, inventory [E], shop/sell/food windows (prompts),
-- upgrade [J], level [U], jobs [O], achievements [L], locations [M], case results (server event).

local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Ui)
local DragDrop = require(script.DragDrop)
local ChestWindow = require(script.ChestWindow)
local HeldItem = require(script.HeldItem)
HeldItem.Start()

local player = Players.LocalPlayer
local locale = Config.defaultLocale
local camera = workspace.CurrentCamera
local function isMobile(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local localizedButtons: { [TextButton]: string } = {}
local T = function(key: string, ...: any)
	return Strings.t(key, locale, ...)
end

local profile: Types.Profile? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "PrisonHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Parent = player:WaitForChild("PlayerGui")

local firstPerson = false
local crosshair = Instance.new("Frame")
crosshair.Name = "Crosshair"
crosshair.Size = UDim2.fromOffset(12, 12)
crosshair.AnchorPoint = Vector2.new(0.5, 0.5)
crosshair.Position = UDim2.fromScale(0.5, 0.5)
crosshair.BackgroundTransparency = 1
crosshair.Visible = false
crosshair.Parent = gui
for _, size in ipairs({ Vector2.new(12, 2), Vector2.new(2, 12) }) do
	local line = Instance.new("Frame")
	line.Size = UDim2.fromOffset(size.X, size.Y)
	line.AnchorPoint = Vector2.new(0.5, 0.5)
	line.Position = UDim2.fromScale(0.5, 0.5)
	line.BackgroundColor3 = Color3.new(1, 1, 1)
	line.BorderSizePixel = 0
	line.Parent = crosshair
end
local cameraButton = Ui.button(
	gui,
	T("camera_first_person"),
	UDim2.fromOffset(150, 28),
	UDim2.new(1, -160, 0, 88),
	Ui.colors.buttonGrey
)
local function renderCameraButton()
	cameraButton.Text = T(if firstPerson then "camera_third_person" else "camera_first_person")
	crosshair.Visible = firstPerson or isMobile()
end
local function toggleFirstPerson()
	firstPerson = not firstPerson
	player.CameraMode = if firstPerson
		then Enum.CameraMode.LockFirstPerson
		else Enum.CameraMode.Classic
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		currentCamera.CameraType = Enum.CameraType.Custom
	end
	renderCameraButton()
end
cameraButton.Activated:Connect(toggleFirstPerson)

-- ---------------------------------------------------------------- HUD: stats panel (right), hints, toast, combo
local stats = Ui.panel(gui, UDim2.fromOffset(190, 96), UDim2.new(1, -200, 0.42, 0))
Ui.label(stats, "PRISON", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 2), 13, Ui.colors.header)
local statLevel = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 20), 14)
local statMoney = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 38), 14)
local statBlocks = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 56), 14)
local statRats = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 74), 14)

local needsPanel = Ui.panel(gui, UDim2.fromOffset(190, 78), UDim2.new(1, -200, 0.42, 102))
type Need = "hygiene" | "sleep" | "toilet"
local needNames: { Need } = { "hygiene", "sleep", "toilet" }
local needBars: { [string]: Frame } = {}
local needValues: { [string]: TextLabel } = {}
local needLabels: { [string]: TextLabel } = {}
for i, need in ipairs(needNames) do
	local y = 5 + (i - 1) * 24
	needLabels[need] = Ui.label(
		needsPanel,
		T("need_" .. need),
		UDim2.fromOffset(82, 20),
		UDim2.fromOffset(6, y),
		12
	)
	local track = Ui.panel(needsPanel, UDim2.fromOffset(90, 16), UDim2.fromOffset(94, y + 2))
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Ui.colors.money
	fill.BorderSizePixel = 0
	fill.Parent = track
	local value = Ui.label(track, "100", UDim2.fromScale(1, 1), UDim2.fromOffset(0, 0), 11)
	value.TextXAlignment = Enum.TextXAlignment.Center
	needBars[need], needValues[need] = fill, value
end

-- Bottom-left, at most 60 % of the width so it never runs under the right-hand panels.
local hints = Ui.label(
	gui,
	T("keys_hint"),
	UDim2.new(0.6, 0, 0, 36),
	UDim2.new(0, 10, 1, -138),
	13,
	Ui.colors.muted
)
hints.TextXAlignment = Enum.TextXAlignment.Left
hints.TextWrapped = true

local languageButton = Ui.button(
	gui,
	T("language_code"),
	UDim2.fromOffset(64, 28),
	UDim2.new(1, -74, 1, -38),
	Ui.colors.buttonGrey
)
local function cycleLocale()
	local index = table.find(Config.locales, locale) or 1
	Remotes.event("SetLocale"):FireServer(Config.locales[index % #Config.locales + 1])
end
languageButton.Activated:Connect(cycleLocale)

local teleportCountdown = Ui.label(
	gui,
	"",
	UDim2.fromOffset(520, 28),
	UDim2.new(0.5, -260, 1, -180),
	16,
	Ui.colors.header
)
teleportCountdown.TextXAlignment = Enum.TextXAlignment.Center
teleportCountdown.Visible = false
local teleportEndsAt: number? = nil
local function renderTeleportCountdown()
	local endsAt = teleportEndsAt
	teleportCountdown.Visible = endsAt ~= nil
	if endsAt then
		teleportCountdown.Text = T("teleport_channel", math.max(0, math.ceil(endsAt - os.clock())))
	end
end
Remotes.event("TeleportChannel").OnClientEvent:Connect(function(seconds: any)
	if seconds == nil then
		teleportEndsAt = nil
	elseif typeof(seconds) == "number" and seconds > 0 and seconds < math.huge then
		teleportEndsAt = os.clock() + seconds
	else
		return
	end
	renderTeleportCountdown()
end)
RunService.Heartbeat:Connect(function()
	if teleportEndsAt then
		renderTeleportCountdown()
	end
end)

local toast = Ui.panel(gui, UDim2.fromOffset(520, 66), UDim2.new(1, -530, 0, 12))
local toastText =
	Ui.label(toast, "", UDim2.new(1, -12, 1, 0), UDim2.fromOffset(6, 0), 14, Ui.colors.header)
toastText.TextWrapped = true
toast.Visible = false
local toastToken = 0
local function showToast(text: string)
	toastToken += 1
	local token = toastToken
	toastText.Text = text
	toast.Visible = true
	task.delay(3, function()
		if toastToken == token then
			toast.Visible = false
		end
	end)
end

local combo =
	Ui.label(gui, "", UDim2.fromOffset(200, 18), UDim2.new(0.5, 120, 1, -112), 13, Ui.colors.muted)
local comboMultiplier: number? = nil
local comboBlocks = 0
local function renderCombo()
	if comboMultiplier then
		combo.Text = T("combo", comboMultiplier, comboBlocks, Config.rules.combo.blocksPerStep)
	end
end

-- ---------------------------------------------------------------- hotbar
local SLOT = 44
local hotbar = Ui.panel(
	gui,
	UDim2.fromOffset(9 * (SLOT + 4) + 8, SLOT + 12),
	UDim2.new(0.5, -(9 * (SLOT + 4) + 8) / 2, 1, -SLOT - 20)
)
local hotbarSlots: { Frame } = {}
local hotbarNames: { TextLabel } = {}
local hotbarCounts: { TextLabel } = {}
local hotbarImages: { ImageLabel } = {}
for i = 1, 9 do
	local f, name, count, image = Ui.slot(hotbar, SLOT)
	f.Position = UDim2.fromOffset(6 + (i - 1) * (SLOT + 4), 6)
	hotbarSlots[i], hotbarNames[i], hotbarCounts[i] = f, name, count
	hotbarImages[i] = image
end

-- Both meters inherit the hotbar's viewport scale, with an extra reduction on touch.
local survivalHud = Instance.new("Frame")
survivalHud.Name = "SurvivalHud"
survivalHud.BackgroundTransparency = 1
survivalHud.AnchorPoint = Vector2.new(0.5, 1)
survivalHud.Position = UDim2.new(0.5, 0, 0, -4)
survivalHud.Size = UDim2.fromOffset(408, 24)
survivalHud.Parent = hotbar
local survivalScale = Instance.new("UIScale")
survivalScale.Parent = survivalHud
type SurvivalMeter = { fills: { Frame }, tooltip: TextLabel }
local function buildMeter(x: number, glyph: string, color: Color3): SurvivalMeter
	local group = Instance.new("Frame")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromOffset(190, 24)
	group.Position = UDim2.fromOffset(x, 0)
	group.Parent = survivalHud
	local function drawIcon(parent: Frame, filled: boolean)
		local tint = if filled then color else Ui.colors.border
		local zIndex = if filled then 2 else 1
		if glyph == "♥" then
			local heart =
				Ui.label(parent, glyph, UDim2.fromOffset(18, 24), UDim2.fromOffset(0, 0), 22, tint)
			heart.Font = Enum.Font.SourceSansBold
			heart.TextXAlignment = Enum.TextXAlignment.Center
			heart.TextStrokeTransparency = 0
			heart.ZIndex = zIndex
			return
		end
		-- Frame drumsticks avoid platform-dependent colour emoji and clip cleanly at half hunger.
		local icon = Instance.new("Frame")
		icon.BackgroundTransparency = 1
		icon.Size = UDim2.fromOffset(18, 24)
		icon.ZIndex = zIndex
		icon.Parent = parent
		for index, geometry in ipairs({
			{ 7, 10, 4, 10 }, -- bone
			{ 5, 17, 8, 4 }, -- knuckle
			{ 3, 2, 12, 14 }, -- meat
		}) do
			local shape = Instance.new("Frame")
			shape.Position = UDim2.fromOffset(geometry[1], geometry[2])
			shape.Size = UDim2.fromOffset(geometry[3], geometry[4])
			shape.BackgroundColor3 = if filled and index < 3
				then Color3.fromRGB(230, 215, 185)
				else tint
			shape.BorderSizePixel = 0
			shape.ZIndex = zIndex
			local rounding = Instance.new("UICorner")
			rounding.CornerRadius = UDim.new(0.5, 0)
			rounding.Parent = shape
			local outline = Instance.new("UIStroke")
			outline.Color = Ui.colors.panel
			outline.Thickness = 1
			outline.Parent = shape
			shape.Parent = icon
		end
	end
	local tooltip = Ui.label(group, "", UDim2.fromOffset(220, 22), UDim2.new(0.5, -110, 0, -26), 12)
	tooltip.TextXAlignment = Enum.TextXAlignment.Center
	tooltip.BackgroundColor3 = Ui.colors.panel
	tooltip.BackgroundTransparency = 0.15
	tooltip.Visible = false
	group.MouseEnter:Connect(function()
		tooltip.Visible = true
	end)
	group.MouseLeave:Connect(function()
		tooltip.Visible = false
	end)
	local fills: { Frame } = {}
	for i = 1, 10 do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.fromOffset(18, 24)
		cell.Position = UDim2.fromOffset((i - 1) * 19, 0)
		cell.BackgroundTransparency = 1
		cell.Parent = group
		drawIcon(cell, false)
		local clip = Instance.new("Frame")
		clip.Size = UDim2.fromScale(1, 1)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Parent = cell
		drawIcon(clip, true)
		fills[i] = clip
	end
	return { fills = fills, tooltip = tooltip }
end
local hearts = buildMeter(0, "♥", Color3.fromRGB(235, 55, 55))
local drumsticks = buildMeter(218, "🍗", Color3.fromRGB(225, 150, 65))
local trackedHumanoid: Humanoid? = nil
local healthConnections: { RBXScriptConnection } = {}
local function fillMeter(meter: SurvivalMeter, value: number)
	-- Any partially filled icon is a half; full icons require both points.
	local points = math.clamp(value, 0, 20)
	local fullPoints = math.floor(points / 2) * 2
	local halves = fullPoints + (if points > fullPoints then 1 else 0)
	for i, fill in ipairs(meter.fills) do
		fill.Size = UDim2.fromScale(math.clamp(halves - (i - 1) * 2, 0, 2) / 2, 1)
	end
end
local function renderSurvival()
	local humanoid = trackedHumanoid
	local health = if humanoid then humanoid.Health else 0
	local maxHealth = if humanoid then humanoid.MaxHealth else 20
	fillMeter(hearts, if maxHealth > 0 then health / maxHealth * 20 else 0)
	hearts.tooltip.Text = T("health_tooltip", health, maxHealth)
	local hunger = if profile then profile.hunger else Config.rules.survival.hunger.max
	fillMeter(drumsticks, hunger / Config.rules.survival.hunger.max * 20)
	drumsticks.tooltip.Text = T("hunger_tooltip", hunger, Config.rules.survival.hunger.max)
end
local function watchHealth(character: Model)
	for _, connection in ipairs(healthConnections) do
		connection:Disconnect()
	end
	table.clear(healthConnections)
	trackedHumanoid = nil
	renderSurvival()
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	trackedHumanoid = humanoid
	table.insert(healthConnections, humanoid.HealthChanged:Connect(renderSurvival))
	table.insert(
		healthConnections,
		humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(renderSurvival)
	)
	renderSurvival()
end
player.CharacterAdded:Connect(watchHealth)
if player.Character then
	task.spawn(watchHealth, player.Character)
end
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
renderSurvival()

-- All menu builders use this viewport clamp, including menus rebuilt after profile updates.
type WindowLayout = { size: UDim2, position: UDim2, anchor: Vector2, scale: UIScale }
local windowLayouts: { [Frame]: WindowLayout } = {}
local function fitWindow(win: Frame, layout: WindowLayout)
	local currentCamera = workspace.CurrentCamera
	if not currentCamera then
		return
	end
	local viewport = currentCamera.ViewportSize
	local width = layout.size.X.Offset + layout.size.X.Scale * viewport.X
	local height = layout.size.Y.Offset + layout.size.Y.Scale * viewport.Y
	layout.scale.Scale =
		math.clamp(math.min((viewport.X - 20) / width, (viewport.Y - 20) / height), 0.1, 1)
	if layout.scale.Scale < 1 then
		win.AnchorPoint = Vector2.new(0.5, 0.5)
		win.Position = UDim2.fromScale(0.5, 0.5)
	else
		win.AnchorPoint, win.Position = layout.anchor, layout.position
	end
end
local function createWindow(
	parent: Instance,
	title: string,
	size: UDim2,
	onClose: () -> ()
): (Frame, Frame)
	local win, content = Ui.window(parent, title, size, onClose)
	local scale = Instance.new("UIScale")
	scale.Parent = win
	local layout: WindowLayout =
		{ size = size, position = win.Position, anchor = win.AnchorPoint, scale = scale }
	windowLayouts[win] = layout
	win.Destroying:Once(function()
		windowLayouts[win] = nil
	end)
	fitWindow(win, layout)
	return win, content
end

local function stackLabel(stack: Types.ItemStack?): (string, string)
	if not stack then
		return "", ""
	end
	local name = Strings.itemName(stack.id, stack.level, locale)
	if stack.level then
		name ..= " " .. tostring(stack.level)
	end
	return name, if stack.count > 1 then tostring(stack.count) else ""
end

local function renderSlot(
	name: TextLabel,
	count: TextLabel,
	image: ImageLabel,
	stack: Types.ItemStack?
)
	local n, c = stackLabel(stack)
	local icon = if stack then Config.iconFor(stack.id, stack.level) else nil
	name.Text, count.Text = n, c
	image.Image = icon or ""
	image.Visible = icon ~= nil
	-- Keep the name until the image has actually loaded (fresh uploads can take a while).
	name.Visible = icon == nil or not image.IsLoaded
	if icon and not image.IsLoaded then
		local conn: RBXScriptConnection
		conn = image:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			if image.IsLoaded then
				name.Visible = false
				conn:Disconnect()
			end
		end)
	end
end

local function renderHotbar()
	if not profile then
		return
	end
	for i = 1, 9 do
		renderSlot(hotbarNames[i], hotbarCounts[i], hotbarImages[i], profile.inventory[i])
		local s = hotbarSlots[i]:FindFirstChildOfClass("UIStroke")
		if s then
			s.Color = if profile.selectedSlot == i then Ui.colors.slotSelected else Ui.colors.border
			s.Thickness = if profile.selectedSlot == i then 2 else 1
		end
	end
end

local function selectSlot(n: number)
	if profile and profile.selectedSlot ~= n then
		profile.selectedSlot = n
		renderHotbar()
		Remotes.event("SelectSlot"):FireServer(n)
	end
end

-- ---------------------------------------------------------------- windows
local openWindow: Frame? = nil
local currentWindowKind: string? = nil
local refreshLocations: (() -> ())? = nil
local refreshInventory: (() -> ())? = nil
local refreshChest: (() -> ())? = nil
local openedCaseId = "ordinaryCase"
local function closeWindow()
	if currentWindowKind == "case" then
		Remotes.event("CaseClose"):FireServer(openedCaseId)
	end
	refreshLocations = nil
	refreshInventory, refreshChest = nil, nil
	if openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
	currentWindowKind = nil
end

-- Inventory [E]: shared drag/drop gestures; profile updates repaint slots in place.
local function buildInventory(): Frame
	local win, content = createWindow(
		gui,
		T("inventory"),
		UDim2.fromOffset(9 * (SLOT + 4) + 160, 5 * (SLOT + 4) + 70),
		closeWindow
	)
	local views: { { index: number, name: TextLabel, count: TextLabel, image: ImageLabel } } = {}
	local armorViews: { { part: string, name: TextLabel, count: TextLabel, image: ImageLabel } } =
		{}
	local function renderArmor(part: string, name: TextLabel, count: TextLabel, image: ImageLabel)
		local armor = if profile then profile.armor[part] else nil
		renderSlot(name, count, image, armor or { id = part, level = 1, count = 1 })
		image.ImageColor3 = if armor then Color3.new(1, 1, 1) else Color3.fromRGB(145, 145, 145)
		image.ImageTransparency = if armor then 0 else 0.6
		name.TextColor3 = if armor then Ui.colors.text else Ui.colors.muted
	end
	local function stackAt(address: DragDrop.Address): Types.ItemStack?
		return if profile then profile.inventory[address.index] else nil
	end
	local drag = DragDrop.new(win, stackAt, function(from, to)
		Remotes.event("InventoryMove"):FireServer(from.index, to.index)
	end, function(from)
		local first, last = if from.index <= 9 then 10 else 1, if from.index <= 9 then 36 else 9
		for index = first, last do
			if not stackAt({ container = "inv", index = index }) then
				Remotes.event("InventoryMove"):FireServer(from.index, index)
				break
			end
		end
	end)
	local function slotAt(index: number, x: number, y: number)
		local f, name, count, image = Ui.slot(content, SLOT)
		f.Position = UDim2.fromOffset(x, y)
		renderSlot(name, count, image, if profile then profile.inventory[index] else nil)
		table.insert(views, { index = index, name = name, count = count, image = image })
		drag.Bind(f, { container = "inv", index = index })
	end
	for r = 0, 2 do
		for c = 0, 8 do
			slotAt(10 + r * 9 + c, c * (SLOT + 4), r * (SLOT + 4))
		end
	end
	for c = 0, 8 do
		slotAt(c + 1, c * (SLOT + 4), 3 * (SLOT + 4) + 10)
	end
	local y = 0
	for _, part in ipairs({ "helmet", "chestplate", "leggings", "boots" }) do
		local f, name, count, image = Ui.slot(content, SLOT)
		f.Position = UDim2.fromOffset(9 * (SLOT + 4) + 12, y)
		renderArmor(part, name, count, image)
		table.insert(armorViews, { part = part, name = name, count = count, image = image })
		y += SLOT + 4
	end
	local equip = Ui.button(
		content,
		"⤒",
		UDim2.fromOffset(SLOT, 24),
		UDim2.fromOffset(9 * (SLOT + 4) + 12, y + 4),
		Ui.colors.buttonGrey
	)
	equip.Activated:Connect(function()
		local picked = drag.Selected()
		if picked then
			Remotes.event("EquipArmor"):FireServer(picked.index)
			drag.Clear()
		end
	end)
	refreshInventory = function()
		for _, view in ipairs(views) do
			renderSlot(
				view.name,
				view.count,
				view.image,
				if profile then profile.inventory[view.index] else nil
			)
		end
		for _, view in ipairs(armorViews) do
			renderArmor(view.part, view.name, view.count, view.image)
		end
	end
	return win
end

-- Sell window: list of blocks in bag with prices, "sell all".
local function buildSell(): Frame
	local win, content =
		createWindow(gui, T("sell_prompt"), UDim2.fromOffset(360, 320), closeWindow)
	local y = 0
	local totals: { [string]: number } = {}
	if profile then
		for _, stack in pairs(profile.inventory) do
			if Config.block(stack.id) then
				totals[stack.id] = (totals[stack.id] or 0) + stack.count
			end
		end
	end
	local mult = if profile
		then 1 + profile.professions.upgrades.money * Config.professions.upgrades.money
		else 1
	local sum = 0
	for id, n in pairs(totals) do
		local block = Config.block(id) :: Config.Block
		local value = math.floor(block.basePrice * Config.moneyScale * mult * n + 0.5)
		sum += value
		Ui.label(
			content,
			string.format("%s ×%d", block.name, n),
			UDim2.new(0.6, 0, 0, 20),
			UDim2.fromOffset(4, y),
			14
		)
		Ui.label(
			content,
			Strings.money(value) .. " $",
			UDim2.new(0.4, -8, 0, 20),
			UDim2.new(0.6, 0, 0, y),
			14,
			Ui.colors.money
		)
		y += 20
	end
	Ui.label(
		content,
		string.format("×%.2f", mult),
		UDim2.new(1, 0, 0, 20),
		UDim2.new(0, 4, 1, -56),
		13,
		Ui.colors.muted
	)
	local btn = Ui.button(
		content,
		T("sell_all") .. "  " .. Strings.money(sum) .. " $",
		UDim2.new(1, -8, 0, 30),
		UDim2.new(0, 4, 1, -32),
		Ui.colors.buttonGreen
	)
	btn.Activated:Connect(function()
		Remotes.event("Sell"):FireServer()
		closeWindow()
	end)
	return win
end

local function buildShop(kind: string): Frame
	type ShopItem = { id: string, price: number }
	local items: { ShopItem } = if kind == "food"
		then {
			{ id = "apple", price = 0.03 },
			{ id = "bread", price = 0.25 },
			{ id = "cooked_chicken", price = 0.5 },
		}
		else {
			{ id = "axe", price = 4 },
			{ id = "pickaxe", price = 22.5 },
			{ id = "shears", price = 4000 },
			{ id = "shovel", price = 4 },
		}
	local win, content = createWindow(
		gui,
		T(if kind == "food" then "food_prompt" else "shop_prompt"),
		UDim2.fromOffset(#items * 120 + 40, 180),
		closeWindow
	)
	for i, item in ipairs(items) do
		local card =
			Ui.panel(content, UDim2.fromOffset(110, 120), UDim2.fromOffset((i - 1) * 120 + 4, 4))
		local name = Ui.label(
			card,
			Strings.itemName(item.id, 1, locale),
			UDim2.new(1, -8, 0, 40),
			UDim2.fromOffset(4, 4),
			13
		)
		name.TextWrapped = true
		Ui.label(
			card,
			Strings.money(item.price * Config.moneyScale) .. " $",
			UDim2.new(1, -8, 0, 20),
			UDim2.fromOffset(4, 60),
			14,
			Ui.colors.money
		)
		local btn = Ui.button(
			card,
			T("buy"),
			UDim2.new(1, -8, 0, 26),
			UDim2.new(0, 4, 1, -30),
			Ui.colors.buttonGreen
		)
		btn.Activated:Connect(function()
			Remotes.event("BuyItem"):FireServer(item.id)
		end)
	end
	return win
end

-- Upgrade [J]: every owned tool/armor with next upgrade cost and requirements.
local function buildUpgrade(): Frame
	local win, content = createWindow(gui, T("upgrade"), UDim2.fromOffset(520, 360), closeWindow)
	local y = 0
	if profile then
		local owned: { { id: string, level: number } } = {}
		local seen: { [string]: boolean } = {}
		for _, stack in pairs(profile.inventory) do
			if Config.tools[stack.id] and not seen[stack.id] then
				seen[stack.id] = true
				table.insert(owned, { id = stack.id, level = stack.level or 1 })
			end
		end
		for id, stack in pairs(profile.armor) do
			if not seen[id] then
				table.insert(owned, { id = id, level = stack.level or 1 })
			end
		end
		for _, item in ipairs(owned) do
			local up = Config.upgrade(item.id, item.level)
			Ui.label(
				content,
				Strings.itemName(item.id, item.level, locale) .. "  " .. tostring(item.level),
				UDim2.new(0.45, 0, 0, 24),
				UDim2.fromOffset(4, y),
				14
			)
			if up then
				local req = {}
				for counter, needed in pairs(up.requirements) do
					table.insert(
						req,
						string.format(
							"%s %s/%s",
							counter,
							Strings.big(profile.counters[counter] or 0),
							Strings.big(needed)
						)
					)
				end
				Ui.label(
					content,
					string.format(
						"→ %d: %s $  %s",
						up.to,
						Strings.big(up.cost),
						table.concat(req, " ")
					),
					UDim2.new(0.45, 0, 0, 24),
					UDim2.new(0.45, 0, 0, y),
					12,
					Ui.colors.muted
				)
				local btn =
					Ui.button(content, "↑", UDim2.fromOffset(40, 22), UDim2.new(1, -44, 0, y + 1))
				local id = item.id
				btn.Activated:Connect(function()
					Remotes.event("UpgradeItem"):FireServer(id)
				end)
			else
				Ui.label(
					content,
					T("upgrade_max"),
					UDim2.new(0.5, 0, 0, 24),
					UDim2.new(0.45, 0, 0, y),
					12,
					Ui.colors.muted
				)
			end
			y += 28
		end
	end
	return win
end

-- Level [U]
local function buildLevel(): Frame
	local win, content = createWindow(gui, T("level_up"), UDim2.fromOffset(360, 180), closeWindow)
	if profile then
		local rule = Config.levelRule(profile.level + 1)
		Ui.label(
			content,
			T("level")
				.. " "
				.. tostring(profile.level)
				.. (if rule then " → " .. tostring(rule.level) else ""),
			UDim2.new(1, -8, 0, 24),
			UDim2.fromOffset(4, 0),
			16,
			Ui.colors.level
		)
		if rule then
			Ui.label(
				content,
				T("level_need_blocks", Strings.big(profile.blocksTotal), Strings.big(rule.blocks)),
				UDim2.new(1, -8, 0, 22),
				UDim2.fromOffset(4, 30),
				14,
				if profile.blocksTotal >= rule.blocks then Ui.colors.money else Ui.colors.text
			)
			Ui.label(
				content,
				T("level_need_money", Strings.money(profile.coins), Strings.big(rule.money)),
				UDim2.new(1, -8, 0, 22),
				UDim2.fromOffset(4, 54),
				14,
				if profile.coins >= rule.money * Config.moneyScale
					then Ui.colors.money
					else Ui.colors.text
			)
			local btn =
				Ui.button(content, T("level_up"), UDim2.new(1, -8, 0, 30), UDim2.new(0, 4, 1, -32))
			btn.Activated:Connect(function()
				Remotes.event("LevelUp"):FireServer()
			end)
		else
			Ui.label(content, T("level_max"), UDim2.new(1, -8, 0, 22), UDim2.fromOffset(4, 30), 14)
		end
	end
	return win
end

-- Jobs [O]: three professions + three boosters, spend points.
local function buildJobs(): Frame
	local win, content = createWindow(gui, T("jobs"), UDim2.fromOffset(560, 300), closeWindow)
	if profile then
		local pro = profile.professions
		local jobs = { "mason", "surveyor", "blademaster" }
		for i, job in ipairs(jobs) do
			local card = Ui.panel(
				content,
				UDim2.fromOffset(176, 110),
				UDim2.fromOffset((i - 1) * 184 + 4, 4)
			)
			Ui.label(
				card,
				T("job_" .. job),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 4),
				14,
				Ui.colors.header
			)
			Ui.label(
				card,
				T("level")
					.. " "
					.. tostring(pro.level[job] or 0)
					.. " / "
					.. tostring(Config.professions.levels),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 28),
				13
			)
			local base = Config.professions.xpThresholds.base[job] or 100
			local need = math.floor(base * 1.6 ^ (pro.level[job] or 0))
			Ui.label(
				card,
				string.format("XP %s / %s", Strings.big(pro.xp[job] or 0), Strings.big(need)),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 50),
				13,
				Ui.colors.money
			)
		end
		Ui.label(
			content,
			T("claim_points", pro.points),
			UDim2.new(1, -8, 0, 20),
			UDim2.fromOffset(4, 124),
			14,
			Ui.colors.level
		)
		local kinds = { "blocks", "money", "mobs" }
		for i, kind in ipairs(kinds) do
			local card = Ui.panel(
				content,
				UDim2.fromOffset(176, 96),
				UDim2.fromOffset((i - 1) * 184 + 4, 150)
			)
			Ui.label(
				card,
				T("booster_" .. kind),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 4),
				14,
				Ui.colors.header
			)
			local lvl = (pro.upgrades :: any)[kind] :: number
			Ui.label(
				card,
				string.format(
					"%d / %d   ×%.2f",
					lvl,
					Config.professions.upgrades.maxLevel,
					1 + lvl * 0.01
				),
				UDim2.new(1, -8, 0, 20),
				UDim2.fromOffset(4, 28),
				13
			)
			local btn = Ui.button(
				card,
				"+1",
				UDim2.new(1, -8, 0, 26),
				UDim2.new(0, 4, 1, -30),
				if pro.points > 0 then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			)
			btn.Activated:Connect(function()
				Remotes.event("SpendPoint"):FireServer(kind)
			end)
		end
	end
	return win
end

-- [решение] Same owner-specified thresholds and rewards as AchievementService.
local function buildAchievements(): Frame
	local win, content =
		createWindow(gui, T("achievements"), UDim2.fromOffset(772, 486), closeWindow)
	local p = profile
	if not p then
		return win
	end
	for i, blockId in ipairs({ "dirt", "sand", "gravel", "coal_ore", "oak_log" }) do
		local id = "digger_" .. blockId
		local claimed = math.clamp(p.achievements[id] or 0, 0, 12)
		local tier = math.min(claimed + 1, 12)
		local threshold = math.floor(64 * 1.7 ^ (tier - 1) + 0.5)
		local counter = Config.blocks[blockId].upgradeCounter
		local progress = p.counters[counter] or 0
		local claimable = claimed < 12 and progress >= threshold
		local card = Ui.panel(
			content,
			UDim2.fromOffset(244, 210),
			UDim2.fromOffset(4 + ((i - 1) % 3) * 252, 4 + math.floor((i - 1) / 3) * 218)
		)
		local title = Ui.label(
			card,
			T(id),
			UDim2.new(1, -12, 0, 36),
			UDim2.fromOffset(6, 4),
			14,
			Ui.colors.header
		)
		title.TextWrapped = true
		local stars = Ui.label(
			card,
			'<font color="#FFAA28">'
				.. string.rep("★", claimed)
				.. '</font><font color="#96969E">'
				.. string.rep("☆", 12 - claimed)
				.. "</font>",
			UDim2.new(1, -12, 0, 24),
			UDim2.fromOffset(6, 42),
			18
		)
		stars.RichText = true
		local track = Ui.panel(card, UDim2.new(1, -12, 0, 24), UDim2.fromOffset(6, 74))
		local fill = Instance.new("Frame")
		fill.Size = UDim2.fromScale(math.clamp(progress / threshold, 0, 1), 1)
		fill.BackgroundColor3 = Ui.colors.buttonGreen
		fill.BorderSizePixel = 0
		fill.Parent = track
		local value = Ui.label(
			track,
			string.format("%s / %s", Strings.big(progress), Strings.big(threshold)),
			UDim2.fromScale(1, 1),
			UDim2.fromOffset(0, 0),
			13
		)
		value.TextXAlignment = Enum.TextXAlignment.Center
		value.ZIndex = fill.ZIndex + 1
		local reward = if claimed == 12
			then T("achievement_complete")
			else T("reward") .. ": " .. tostring(tier * 10) .. " $"
		if claimed < 12 and tier % 4 == 0 then
			reward ..= " + " .. T("item_booster_money") .. " ×1"
		end
		local rewardLabel = Ui.label(
			card,
			reward,
			UDim2.new(1, -12, 0, 64),
			UDim2.fromOffset(6, 102),
			12,
			Ui.colors.money
		)
		rewardLabel.TextWrapped = true
		local button = Ui.button(
			card,
			T("claim"),
			UDim2.new(1, -12, 0, 30),
			UDim2.new(0, 6, 1, -36),
			if claimable then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		button.Interactable = claimable
		button.AutoButtonColor = claimable
		button.Activated:Connect(function()
			if claimable then
				Remotes.event("ClaimAchievement"):FireServer(id, tier)
			end
		end)
	end
	return win
end

local function buildCase(): Frame
	local win, refresh = ChestWindow.build(gui, openedCaseId, function()
		return profile
	end, locale, closeWindow, createWindow)
	refreshChest = refresh
	return win
end

-- Locations [M]. Procedural previews need no uploaded assets or streamed world geometry.
local locationTab = "mines"
local selectedLocations: { [string]: string } = {}
local locationScroll: { [string]: number } = {}
local lastLocationClick: string? = nil
local lastLocationClickAt = -math.huge
local SPOTS = {
	{ id = "spawn", icon = "⌂" },
	{ id = "mine", icon = "⛏" },
	{ id = "small_mine", icon = "⛏" },
	{ id = "market", icon = "$" },
	{ id = "canteen", icon = "🍎" },
	{ id = "bedroom", icon = "☾" },
	{ id = "bath", icon = "♨" },
	{ id = "trainer", icon = "⚔" },
}
local DESCRIBED_LOCATIONS: { [string]: boolean } = {
	prison = true,
	quarry = true,
	mountain_foot = true,
	underworld = true,
	pyramid = true,
	basement = true,
}

local function locationCategory(location: Config.Location): string
	if location.kind == "social" or location.id == "basement" then
		return "other"
	elseif location.kind == "mine" and location.unlockLevel >= 37 then
		return "sky"
	elseif location.kind == "mine" and location.unlockLevel <= 35 then
		return "mines"
	end
	return ""
end

local function locationAvailable(location: Config.Location): boolean
	local p = profile
	return p ~= nil
		and p.level >= location.unlockLevel
		and (not location.requiresPass or p.passes[location.id] == true)
end

local function locationPreview(
	parent: Instance,
	location: Config.Location,
	size: UDim2,
	position: UDim2
): ViewportFrame | ImageLabel
	local previewId = Config.previews and Config.previews.previews[location.id]
	if typeof(previewId) == "string" and previewId ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Preview_" .. location.id
		image.Size, image.Position = size, position
		image.BackgroundColor3 = Ui.colors.slot
		image.BorderSizePixel = 0
		image.Image = previewId
		image.ScaleType = Enum.ScaleType.Crop
		image.Parent = parent
		return image
	end
	local view = Instance.new("ViewportFrame")
	view.Name = "Preview_" .. location.id
	view.Size, view.Position = size, position
	view.BackgroundColor3 = Ui.colors.slot
	view.BorderSizePixel = 0
	view.Ambient = Color3.fromRGB(170, 170, 180)
	view.LightColor = Color3.fromRGB(255, 225, 185)
	view.LightDirection = Vector3.new(-1, -2, -1)
	view.Parent = parent
	local camera = Instance.new("Camera")
	camera.CFrame = CFrame.lookAt(Vector3.new(23, 23, 27), Vector3.new(0, 1, 0))
	camera.FieldOfView = 40
	camera.Parent = view
	view.CurrentCamera = camera
	local colors: { [string]: Color3 } = {
		prison = Color3.fromRGB(125, 145, 100),
		quarry = Color3.fromRGB(115, 120, 130),
		mountain_foot = Color3.fromRGB(175, 100, 65),
		underworld = Color3.fromRGB(150, 45, 35),
		pyramid = Color3.fromRGB(215, 175, 90),
		basement = Color3.fromRGB(70, 80, 65),
	}
	local color = colors[location.id]
		or (
			if locationCategory(location) == "sky"
				then Color3.fromRGB(175, 195, 220)
				else Color3.fromHSV((location.unlockLevel * 0.037) % 1, 0.3, 0.6)
		)
	local function block(blockSize: Vector3, cf: CFrame, tint: Color3)
		local part = Instance.new("Part")
		part.Size, part.CFrame, part.Color = blockSize, cf, tint
		part.Anchored = true
		part.Material = Enum.Material.Slate
		part.Parent = view
	end
	block(Vector3.new(20, 1, 20), CFrame.new(0, -2, 0), color)
	block(Vector3.new(11, 1, 11), CFrame.new(0, -1, 0), color:Lerp(Color3.new(), 0.45))
	for i = 1, 12 do
		local angle = i * math.pi / 6
		block(
			Vector3.new(4.2, 3, 3),
			CFrame.new(math.sin(angle) * 7, 0, math.cos(angle) * 7) * CFrame.Angles(0, angle, 0),
			color
		)
	end
	for i = 1, math.min(5, #location.sellList) do
		block(
			Vector3.new(2, 1.5, 2),
			CFrame.new((i % 3 - 1) * 3, 0, math.floor((i - 1) / 3) * 3 - 2),
			color:Lerp(Ui.colors.header, i / 8)
		)
	end
	if location.id == "pyramid" then
		for i = 1, 4 do
			block(Vector3.new(11 - i * 2, 2, 11 - i * 2), CFrame.new(-5, i * 2, -6), color)
		end
	else
		for i = 1, 3 do
			local height = if location.id == "basement" then 7 else 3 + i * 2
			block(Vector3.new(2, height, 2), CFrame.new(i * 5 - 10, height / 2, -8), color)
		end
	end
	return view
end

local function buildLocations(): Frame
	local win, content = createWindow(gui, T("locations"), UDim2.fromOffset(900, 560), closeWindow)
	win.Name = "Window_locations"
	local playerLevel =
		Ui.label(win, "", UDim2.fromOffset(300, 28), UDim2.new(1, -350, 0, 6), 14, Ui.colors.level)
	playerLevel.TextXAlignment = Enum.TextXAlignment.Right
	local left = Ui.panel(content, UDim2.new(0, 304, 1, -42), UDim2.fromOffset(0, 42))
	local detail = Instance.new("ScrollingFrame")
	detail.Name = "LocationDetails"
	detail.Size = UDim2.new(1, -12, 1, -92)
	detail.Position = UDim2.fromOffset(6, 6)
	detail.BackgroundTransparency = 1
	detail.BorderSizePixel = 0
	detail.ScrollBarThickness = 4
	detail.CanvasSize = UDim2.new()
	detail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	detail.Parent = left
	local refusal =
		Ui.label(left, "", UDim2.new(1, -16, 0, 32), UDim2.new(0, 8, 1, -82), 12, Ui.colors.muted)
	refusal.TextWrapped = true
	local teleportButton =
		Ui.button(left, T("teleport"), UDim2.new(1, -16, 0, 36), UDim2.new(0, 8, 1, -44))
	local grid = Instance.new("ScrollingFrame")
	grid.Name = "LocationCards"
	grid.Size = UDim2.new(1, -316, 1, -68)
	grid.Position = UDim2.fromOffset(314, 44)
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.ScrollBarThickness = 4
	grid.CanvasSize = UDim2.new()
	grid.AutomaticCanvasSize = Enum.AutomaticSize.Y
	grid.Parent = content
	local clickHint = Ui.label(
		content,
		T("locations_double_click"),
		UDim2.new(1, -320, 0, 20),
		UDim2.new(0, 318, 1, -20),
		12,
		Ui.colors.muted
	)

	local selected: Config.Location? = nil
	local tabButtons: { [string]: TextButton } = {}
	type Card = {
		location: Config.Location,
		panel: Frame,
		name: TextLabel,
		level: TextLabel,
		preview: ViewportFrame | ImageLabel,
	}
	local cards: { Card } = {}
	local function updateAvailability()
		playerLevel.Text = T("locations_player_level", if profile then profile.level else 1)
		local available = selected ~= nil and locationAvailable(selected)
		teleportButton.Interactable = available
		teleportButton.AutoButtonColor = available
		teleportButton.BackgroundColor3 = if available
			then Ui.colors.buttonBlue
			else Ui.colors.buttonGrey
		refusal.Text = ""
		if selected then
			if not profile then
				refusal.Text = T("teleport_not_ready")
			elseif profile.level < selected.unlockLevel then
				refusal.Text = T("level_too_low", selected.unlockLevel)
			elseif not available then
				refusal.Text = T("location_pass_required")
			end
		end
		for _, card in ipairs(cards) do
			local unlocked = locationAvailable(card.location)
			card.name.Text = (if unlocked then "" else "🔒 ") .. card.location.name
			card.name.TextColor3 = if unlocked then Ui.colors.text else Ui.colors.muted
			card.level.TextColor3 = if unlocked then Ui.colors.level else Ui.colors.muted
			card.preview.ImageColor3 = if unlocked
				then Color3.new(1, 1, 1)
				else Color3.fromRGB(135, 135, 145)
			local stroke = card.panel:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if selected == card.location
					then Ui.colors.buttonBlue
					else Ui.colors.border
				stroke.Thickness = if selected == card.location then 2 else 1
			end
		end
	end
	local function selectLocation(location: Config.Location)
		selected = location
		selectedLocations[locationTab] = location.id
		detail:ClearAllChildren()
		detail.CanvasPosition = Vector2.zero
		local detailLayout = Instance.new("UIListLayout")
		detailLayout.Padding = UDim.new(0, 6)
		detailLayout.SortOrder = Enum.SortOrder.LayoutOrder
		detailLayout.Parent = detail
		local preview = locationPreview(detail, location, UDim2.new(1, -6, 0, 128), UDim2.new())
		preview.LayoutOrder = 1
		local name = Ui.label(
			detail,
			location.name,
			UDim2.new(1, -8, 0, 40),
			UDim2.fromOffset(2, 134),
			18,
			Ui.colors.header
		)
		name.LayoutOrder = 2
		name.TextWrapped = true
		local key = if DESCRIBED_LOCATIONS[location.id] then location.id else "generic"
		local description = Ui.label(
			detail,
			T("location_description_" .. key),
			UDim2.new(1, -12, 0, 0),
			UDim2.fromOffset(2, 178),
			13
		)
		description.LayoutOrder = 3
		description.AutomaticSize = Enum.AutomaticSize.Y
		description.TextWrapped = true
		description.TextYAlignment = Enum.TextYAlignment.Top
		-- A vertical layout below the preview keeps translations and long block lists scrollable.
		local sections = Instance.new("Frame")
		sections.Size = UDim2.new(1, -10, 0, 0)
		sections.AutomaticSize = Enum.AutomaticSize.Y
		sections.BackgroundTransparency = 1
		sections.LayoutOrder = 4
		sections.Parent = detail
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 6)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = sections
		if #location.sellList > 0 then
			local heading = Ui.label(
				sections,
				T("blocks"),
				UDim2.new(1, 0, 0, 22),
				UDim2.new(),
				15,
				Ui.colors.header
			)
			heading.LayoutOrder = 1
			local chips = Instance.new("Frame")
			chips.Size = UDim2.new(1, -4, 0, math.ceil(#location.sellList / 2) * 36 - 4)
			chips.BackgroundTransparency = 1
			chips.LayoutOrder = 2
			chips.Parent = sections
			local chipLayout = Instance.new("UIGridLayout")
			chipLayout.CellSize = UDim2.new(0.5, -4, 0, 32)
			chipLayout.CellPadding = UDim2.fromOffset(4, 4)
			chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
			chipLayout.Parent = chips
			for i, id in ipairs(location.sellList) do
				local chip = Ui.panel(chips, UDim2.new(), UDim2.new())
				chip.LayoutOrder = i
				chip.BackgroundColor3 = Ui.colors.slot
				local blockName = Ui.label(
					chip,
					Strings.itemName(id, nil, locale),
					UDim2.new(1, -12, 1, 0),
					UDim2.fromOffset(6, 0),
					12
				)
				blockName.TextWrapped = true
			end
		end
		local bossNames: { string } = {}
		local bossLevels: { string } = {}
		for _, boss in ipairs(Config.bosses.bosses) do
			if boss.location == location.name then
				table.insert(bossNames, boss.name)
				table.insert(
					bossLevels,
					boss.name .. " · " .. T("location_level", boss.unlockLevel)
				)
			end
		end
		if #bossNames > 0 then
			local heading = Ui.label(
				sections,
				T("bosses"),
				UDim2.new(1, 0, 0, 22),
				UDim2.new(),
				15,
				Ui.colors.header
			)
			heading.LayoutOrder = 100
			local bosses = Ui.label(
				sections,
				table.concat(bossNames, "\n"),
				UDim2.new(1, -4, 0, 0),
				UDim2.new(),
				13
			)
			bosses.TextWrapped = true
			bosses.AutomaticSize = Enum.AutomaticSize.Y
			bosses.LayoutOrder = 101
			local more =
				Ui.button(sections, T("more_details"), UDim2.new(1, -4, 0, 25), UDim2.new())
			more.LayoutOrder = 102
			more.Activated:Connect(function()
				bosses.Text = if bosses.Text == table.concat(bossNames, "\n")
					then table.concat(bossLevels, "\n")
					else table.concat(bossNames, "\n")
			end)
		end
		updateAvailability()
	end
	local function requestTeleport(location: Config.Location)
		if locationAvailable(location) then
			Remotes.event("Teleport"):FireServer(location.id)
		end
	end
	teleportButton.Activated:Connect(function()
		if selected then
			requestTeleport(selected)
		end
	end)
	local drawingTab = false
	local function drawTab()
		drawingTab = true
		local scrollY = locationScroll[locationTab] or 0
		grid:ClearAllChildren()
		cards = {}
		lastLocationClick = nil
		local layout = Instance.new("UIListLayout")
		layout.Padding = UDim.new(0, 10)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = grid
		for tab, button in pairs(tabButtons) do
			button.BackgroundColor3 = if tab == locationTab
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		local spots = locationTab == "spots"
		left.Visible = not spots
		clickHint.Visible = not spots
		grid.Position = UDim2.fromOffset(if spots then 0 else 314, 44)
		grid.Size = UDim2.new(1, if spots then 0 else -316, 1, if spots then -44 else -68)
		if spots then
			selected = nil
			detail:ClearAllChildren()
			for i, spot in ipairs(SPOTS) do
				local card = Ui.panel(grid, UDim2.new(1, -8, 0, 72), UDim2.new())
				card.Name = "Spot_" .. spot.id
				card.LayoutOrder = i
				local icon = Ui.label(
					card,
					spot.icon,
					UDim2.fromOffset(52, 52),
					UDim2.fromOffset(10, 10),
					30,
					Ui.colors.header
				)
				icon.TextXAlignment = Enum.TextXAlignment.Center
				Ui.label(
					card,
					T("spot_" .. spot.id),
					UDim2.new(1, -84, 1, 0),
					UDim2.fromOffset(76, 0),
					18
				)
				local hit = Ui.button(card, "", UDim2.fromScale(1, 1), UDim2.new())
				hit.BackgroundTransparency = 1
				hit.Activated:Connect(function()
					if profile then
						Remotes.event("Teleport"):FireServer(profile.location, spot.id)
					end
				end)
			end
			grid.CanvasPosition = Vector2.new(0, scrollY)
			drawingTab = false
			updateAvailability()
			return
		end
		local locations: { Config.Location } = {}
		for _, location in ipairs(Config.locationsFile.locations) do
			if locationCategory(location) == locationTab then
				table.insert(locations, location)
			end
		end
		table.sort(locations, function(a, b)
			return if a.unlockLevel == b.unlockLevel
				then a.id < b.id
				else a.unlockLevel < b.unlockLevel
		end)
		local row: Frame? = nil
		local column = 0
		for i, location in ipairs(locations) do
			local starting = location.id == "prison"
			if column == 0 or starting then
				row = Instance.new("Frame")
				row.Size = UDim2.new(1, -8, 0, if starting then 110 else 144)
				row.BackgroundTransparency = 1
				row.LayoutOrder = i
				row.Parent = grid
			end
			local card = Ui.panel(
				row :: Frame,
				UDim2.new(if starting then 1 else 0.5, if starting then -4 else -7, 1, -4),
				UDim2.new(column * 0.5, 2, 0, 2)
			)
			card.Name = "Location_" .. location.id
			local preview = locationPreview(
				card,
				location,
				if starting then UDim2.new(0.3, -8, 1, -12) else UDim2.new(1, -12, 0, 76),
				UDim2.fromOffset(6, 6)
			)
			local name = Ui.label(
				card,
				"",
				if starting then UDim2.new(0.7, -18, 0, 38) else UDim2.new(1, -12, 0, 32),
				if starting then UDim2.new(0.3, 6, 0, 12) else UDim2.fromOffset(6, 84),
				13
			)
			name.TextWrapped = true
			local level = Ui.label(
				card,
				if starting then T("location_start") else T("location_level", location.unlockLevel),
				if starting then UDim2.new(0.7, -18, 0, 20) else UDim2.new(1, -12, 0, 18),
				if starting then UDim2.new(0.3, 6, 0, 58) else UDim2.fromOffset(6, 118),
				12
			)
			if location.pvp then
				local badge =
					Ui.label(card, T("pvp"), UDim2.fromOffset(38, 20), UDim2.new(1, -44, 0, 8), 12)
				badge.BackgroundTransparency = 0
				badge.BackgroundColor3 = Ui.colors.close
				badge.TextXAlignment = Enum.TextXAlignment.Center
			end
			table.insert(
				cards,
				{ location = location, panel = card, name = name, level = level, preview = preview }
			)
			local hit = Ui.button(card, "", UDim2.fromScale(1, 1), UDim2.new())
			hit.BackgroundTransparency = 1
			hit.Activated:Connect(function()
				local now = os.clock()
				local doubleClick = lastLocationClick == location.id
					and now - lastLocationClickAt <= 0.35
				lastLocationClick, lastLocationClickAt = location.id, now
				selectLocation(location)
				if doubleClick then
					lastLocationClick = nil
					requestTeleport(location)
				end
			end)
			column = if starting then 0 else (column + 1) % 2
		end
		for tab, button in pairs(tabButtons) do
			button.BackgroundColor3 = if tab == locationTab
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		grid.CanvasPosition = Vector2.new(0, scrollY)
		drawingTab = false
		for _, location in ipairs(locations) do
			if location.id == selectedLocations[locationTab] then
				selectLocation(location)
				return
			end
		end
		if locations[1] then
			selectLocation(locations[1])
		end
	end
	for i, tab in ipairs({ "mines", "sky", "other", "spots" }) do
		local button = Ui.button(
			content,
			T("locations_" .. tab),
			UDim2.new(1 / 4, -6, 0, 32),
			UDim2.new((i - 1) / 4, 2, 0, 0)
		)
		tabButtons[tab] = button
		button.Activated:Connect(function()
			if locationTab ~= tab then
				locationScroll[locationTab] = grid.CanvasPosition.Y
				locationTab = tab
				drawTab()
			end
		end)
	end
	grid:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if not drawingTab then
			locationScroll[locationTab] = grid.CanvasPosition.Y
		end
	end)
	drawTab()
	refreshLocations = updateAvailability
	return win
end

local windowBuilders: { [string]: () -> Frame } = {
	inventory = buildInventory,
	sell = buildSell,
	shop = function()
		return buildShop("shop")
	end,
	food = function()
		return buildShop("food")
	end,
	upgrade = buildUpgrade,
	level = buildLevel,
	jobs = buildJobs,
	achievements = buildAchievements,
	case = buildCase,
	locations = buildLocations,
}
local function open(kind: string)
	local builder = windowBuilders[kind]
	if not builder then
		return
	end
	if currentWindowKind == kind then
		closeWindow()
		currentWindowKind = nil
		return
	end
	closeWindow()
	currentWindowKind = kind
	openWindow = builder()
end
local function refreshWindow(force: boolean?)
	if not force and currentWindowKind == "inventory" and refreshInventory then
		refreshInventory()
		return
	end
	if not force and currentWindowKind == "case" and refreshChest then
		refreshChest()
		return
	end
	if not force and currentWindowKind == "locations" and refreshLocations then
		refreshLocations()
		return
	end
	if currentWindowKind and openWindow then
		local kind = currentWindowKind
		openWindow:Destroy()
		openWindow = windowBuilders[kind]()
	end
end

-- ---------------------------------------------------------------- profile rendering
local function render(p: Types.Profile)
	local nextLocale = p.locale or Config.defaultLocale
	local rebuild = locale ~= nextLocale or (profile ~= nil and profile.location ~= p.location)
	profile = p
	locale = nextLocale
	languageButton.Text = T("language_code")
	renderCameraButton()
	for button, key in pairs(localizedButtons) do
		button.Text = T(key)
	end
	hints.Text = T("keys_hint")
	renderTeleportCountdown()
	renderCombo()
	statLevel.Text = string.format("%s  %d", T("level"), p.level)
	statLevel.TextColor3 = Ui.colors.level
	statMoney.Text = string.format("%s  %s $", T("coins"), Strings.money(p.coins))
	statMoney.TextColor3 = Ui.colors.money
	statBlocks.Text = string.format("%s  %s", T("blocks"), Strings.big(p.blocksTotal))
	statRats.Text = string.format("%s  %d", T("rats"), p.stats.rats or 0)
	for _, need in ipairs(needNames) do
		needLabels[need].Text = T("need_" .. need)
		local value = math.clamp(p.needs[need], 0, 100)
		needBars[need].Size = UDim2.fromScale(value / 100, 1)
		needBars[need].BackgroundColor3 = if value < 25 then Ui.colors.close else Ui.colors.money
		needValues[need].Text = tostring(math.floor(value))
	end
	renderHotbar()
	renderSurvival()
	refreshWindow(rebuild)
end
Remotes.event("ProfileUpdated").OnClientEvent:Connect(render)
Remotes.event("Toast").OnClientEvent:Connect(showToast)
Remotes.event("OpenMenu").OnClientEvent:Connect(function(kind: string, tab: string?)
	if kind == "locations" and tab == "spots" then
		locationTab = "spots"
	end
	closeWindow()
	open(kind)
end)
Remotes.event("CaseOpened").OnClientEvent:Connect(function(id: string)
	-- The server has already replaced the session; closing the old UI must not close it.
	currentWindowKind = nil
	closeWindow()
	openedCaseId = id
	open("case")
end)
Remotes.event("CaseUpdated").OnClientEvent:Connect(function(id: string, active: boolean)
	if currentWindowKind == "case" and id == openedCaseId then
		if not active then
			closeWindow()
		elseif refreshChest then
			refreshChest()
		end
	end
end)
Remotes.event("Combo").OnClientEvent:Connect(function(mult: number, n: number)
	comboMultiplier, comboBlocks = mult, n
	renderCombo()
end)

-- Camera changes run after Roblox's camera update; remove our previous roll when needed so a
-- stationary/Scriptable camera cannot accumulate it. Only our own blur is ever destroyed.
local nauseaBlur: BlurEffect? = nil
local nauseaAttributeConnection: RBXScriptConnection? = nil
local rolledCamera: Camera? = nil
local baseCFrame: CFrame? = nil
local appliedCFrame: CFrame? = nil

local function clearCameraRoll()
	if rolledCamera and baseCFrame and rolledCamera.CFrame == appliedCFrame then
		rolledCamera.CFrame = baseCFrame
	end
	rolledCamera, baseCFrame, appliedCFrame = nil, nil, nil
end

local function setNausea(enabled: boolean)
	RunService:UnbindFromRenderStep("PrisonNausea")
	clearCameraRoll()
	if nauseaBlur then
		nauseaBlur:Destroy()
		nauseaBlur = nil
	end
	if not enabled then
		return
	end
	local blur = Instance.new("BlurEffect")
	blur.Name = "PrisonNausea"
	blur.Size = 8
	blur.Parent = Lighting
	nauseaBlur = blur
	RunService:BindToRenderStep("PrisonNausea", Enum.RenderPriority.Camera.Value + 1, function()
		clearCameraRoll()
		local currentCamera = workspace.CurrentCamera
		if currentCamera then
			local base = currentCamera.CFrame
			local rolled = base
				* CFrame.Angles(0, 0, math.rad(2) * math.sin(os.clock() * 2 * math.pi))
			rolledCamera, baseCFrame, appliedCFrame = currentCamera, base, rolled
			currentCamera.CFrame = rolled
		end
	end)
end

local function watchNausea(character: Model?)
	if nauseaAttributeConnection then
		nauseaAttributeConnection:Disconnect()
		nauseaAttributeConnection = nil
	end
	setNausea(false)
	if character then
		nauseaAttributeConnection = character:GetAttributeChangedSignal("Nausea"):Connect(function()
			setNausea(character:GetAttribute("Nausea") == true)
		end)
		setNausea(character:GetAttribute("Nausea") == true)
	end
end
player.CharacterAdded:Connect(watchNausea)
player.CharacterRemoving:Connect(function()
	watchNausea(nil)
end)
watchNausea(player.Character)

-- ---------------------------------------------------------------- digging
local highlight = Instance.new("Highlight")
highlight.FillTransparency = 0.7
highlight.OutlineColor = Color3.fromRGB(255, 220, 80)
highlight.Enabled = false
highlight.Parent = gui
local progress = Ui.panel(gui, UDim2.fromOffset(160, 10), UDim2.new(0.5, -80, 0.5, 40))
local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.fromScale(0, 1)
progressFill.BackgroundColor3 = Ui.colors.header
progressFill.BorderSizePixel = 0
progressFill.Parent = progress
progress.Visible = false

local MAX_TARGET = 14
local function targetUnderCursor(point: Vector2?): BasePart?
	local character = player.Character
	local currentCamera = workspace.CurrentCamera
	if not character or not currentCamera or currentWindowKind then
		return nil
	end
	local ray: Ray
	if point then
		ray = currentCamera:ViewportPointToRay(point.X, point.Y)
	elseif
		not firstPerson
		and not isMobile()
		and UserInputService.PreferredInput == Enum.PreferredInput.KeyboardAndMouse
	then
		local m = UserInputService:GetMouseLocation()
		ray = currentCamera:ViewportPointToRay(m.X, m.Y)
	else
		ray = currentCamera:ViewportPointToRay(
			currentCamera.ViewportSize.X / 2,
			currentCamera.ViewportSize.Y / 2
		)
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 100, params)
	if not hit or not CollectionService:HasTag(hit.Instance, "MineBlock") then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if
		root
		and root:IsA("BasePart")
		and (root.Position - hit.Instance.Position).Magnitude > MAX_TARGET
	then
		return nil
	end
	return hit.Instance :: BasePart
end

local digging = false
local holding = false
local digTarget: BasePart? = nil
local tapTarget: BasePart? = nil
local digStarted = 0
local digNeeded = 0

local function expectedTime(part: BasePart): number?
	if not profile then
		return nil
	end
	local id = part:GetAttribute("Block")
	local block = if typeof(id) == "string" then Config.block(id) else nil
	if not block then
		return nil
	end
	local stack = profile.inventory[profile.selectedSlot]
	local toolId = if stack and Config.tools[stack.id] then stack.id else nil
	local level = if stack and stack.level then stack.level else 0
	if profile.needs.sleep <= 0 then
		return nil
	end
	local needed = Config.breakTime(block, toolId, level)
	if needed then
		if profile.needs.hygiene <= 0 then
			needed *= 1 + Config.needs.hygiene.digSlowdownAtZero
		end
		local character = player.Character
		if character and character:GetAttribute("Haste") == 1 then
			needed /= 1.2
		end
	end
	return needed
end

local function stopDig()
	HeldItem.SetDigging(false)
	digging = false
	digTarget = nil
	tapTarget = nil
	progress.Visible = false
end

RunService.RenderStepped:Connect(function()
	if currentWindowKind then
		holding = false
		stopDig()
		highlight.Enabled = false
		return
	end
	if tapTarget then
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if
			not tapTarget:IsDescendantOf(workspace)
			or not root
			or not root:IsA("BasePart")
			or (root.Position - tapTarget.Position).Magnitude > MAX_TARGET
		then
			stopDig()
		end
	end
	local target = tapTarget or targetUnderCursor()
	highlight.Adornee = target
	highlight.Enabled = target ~= nil
	if digging then
		if target ~= digTarget then
			stopDig()
			if target then
				local needed = expectedTime(target)
				if needed then
					digging, digTarget, digStarted, digNeeded = true, target, os.clock(), needed
					Remotes.event("DigStart"):FireServer(target)
				end
			end
		elseif digTarget then
			local k = math.clamp((os.clock() - digStarted) / digNeeded, 0, 1)
			progress.Visible = true
			progressFill.Size = UDim2.fromScale(k, 1)
			if k >= 1 then
				Remotes.event("DigFinish"):FireServer(digTarget)
				stopDig()
			end
		end
	elseif holding and target then
		-- button still held: start on whatever block is under the cursor now
		local needed = expectedTime(target)
		if needed then
			digging, digTarget, digStarted, digNeeded = true, target, os.clock(), needed
			Remotes.event("DigStart"):FireServer(target)
		end
	end
	HeldItem.SetDigging(digging)
end)

local function onDig(_: string, state: Enum.UserInputState, input: InputObject?)
	if state == Enum.UserInputState.Begin then
		if
			currentWindowKind
			or (input and isMobile() and input.UserInputType == Enum.UserInputType.MouseButton1)
		then
			return Enum.ContextActionResult.Pass
		end
		if input and input.UserInputType == Enum.UserInputType.MouseButton1 then
			local point = UserInputService:GetMouseLocation()
			for _, object in ipairs(player.PlayerGui:GetGuiObjectsAtPosition(point.X, point.Y)) do
				if object:IsA("GuiButton") or object:IsA("ScrollingFrame") then
					return Enum.ContextActionResult.Pass
				end
			end
		end
		stopDig()
		holding = true
		local target = targetUnderCursor()
		local needed = if target then expectedTime(target) else nil
		if target and needed then
			digging, digTarget, digStarted, digNeeded = true, target, os.clock(), needed
			Remotes.event("DigStart"):FireServer(target)
		elseif target then
			Remotes.event("DigStart"):FireServer(target) -- server replies with the reason
		end
		return Enum.ContextActionResult.Sink
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holding = false
		stopDig()
	end
	return Enum.ContextActionResult.Pass
end
ContextActionService:BindAction(
	"Dig",
	onDig,
	false,
	Enum.UserInputType.MouseButton1,
	Enum.KeyCode.ButtonR2
)

-- Touch only: leave Roblox's camera, thumbstick and jump controls in charge of movement.
local touchMenus = Instance.new("ScrollingFrame")
touchMenus.Name = "TouchMenus"
touchMenus.Position = UDim2.fromOffset(8, 120)
touchMenus.BackgroundTransparency = 1
touchMenus.BorderSizePixel = 0
touchMenus.ScrollBarThickness = 2
touchMenus.CanvasSize = UDim2.fromOffset(0, 7 * 52 - 8)
touchMenus.Parent = gui
local menuKeys =
	{ "locations", "inventory", "jobs", "upgrade", "level", "achievements", "language_code" }
local menuGlyphs = { "M", "E", "O", "J", "U", "L", "" }
for i, kind in ipairs(menuKeys) do
	local button = Ui.button(
		touchMenus,
		menuGlyphs[i],
		UDim2.fromOffset(44, 44),
		UDim2.fromOffset(0, (i - 1) * 52),
		Ui.colors.buttonGrey
	)
	button.Name = "Touch_" .. kind
	button.Activated:Connect(function()
		if kind == "language_code" then
			cycleLocale()
		else
			open(kind)
		end
	end)
	if kind == "language_code" then
		button.Text = T(kind)
		localizedButtons[button] = kind
	end
end
local touchActions = Instance.new("Frame")
touchActions.Name = "TouchActions"
touchActions.Size = UDim2.fromScale(1, 1)
touchActions.BackgroundTransparency = 1
touchActions.Parent = gui
local digButton =
	Ui.button(touchActions, T("touch_dig"), UDim2.fromOffset(80, 80), UDim2.new(1, -96, 1, -188))
digButton.Name = "TouchDig"
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0.5, 0)
round.Parent = digButton
localizedButtons[digButton] = "touch_dig"
local useButton = Ui.button(
	touchActions,
	T("touch_use"),
	UDim2.fromOffset(64, 48),
	UDim2.new(1, -168, 1, -176),
	Ui.colors.buttonGrey
)
useButton.TextScaled = true
useButton.TextWrapped = true
localizedButtons[useButton] = "touch_use"
local function useConsumable()
	if profile then
		Remotes.event("UseConsumable"):FireServer(profile.selectedSlot)
	end
end
useButton.Activated:Connect(useConsumable)
local digTouch: InputObject? = nil
digButton.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.Touch and not digTouch and isMobile() then
		digTouch = input
		onDig("TouchDig", Enum.UserInputState.Begin)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if input == digTouch then
		digTouch = nil
		onDig("TouchDig", Enum.UserInputState.End)
	end
end)
UserInputService.TouchTapInWorld:Connect(function(position: Vector2, processed: boolean)
	if processed or not isMobile() or currentWindowKind or digTouch then
		return
	end
	holding = false
	stopDig()
	local target = targetUnderCursor(position)
	local needed = if target then expectedTime(target) else nil
	if target and needed then
		digging, digTarget, tapTarget, digStarted, digNeeded =
			true, target, target, os.clock(), needed
		Remotes.event("DigStart"):FireServer(target)
	elseif target then
		Remotes.event("DigStart"):FireServer(target)
	end
end)
local function cancelDigInput()
	digTouch = nil
	holding = false
	stopDig()
end
UserInputService.WindowFocusReleased:Connect(cancelDigInput)
player.CharacterRemoving:Connect(cancelDigInput)

local statsScale = Instance.new("UIScale")
statsScale.Parent = stats
local needsScale = Instance.new("UIScale")
needsScale.Parent = needsPanel
local hotbarScale = Instance.new("UIScale")
hotbarScale.Parent = hotbar
local slotScales: { UIScale } = {}
for i, slot in ipairs(hotbarSlots) do
	local scale = Instance.new("UIScale")
	scale.Parent = slot
	slotScales[i] = scale
end
local function updateLayout()
	local mobile = isMobile()
	local currentCamera = workspace.CurrentCamera
	local viewport = if currentCamera then currentCamera.ViewportSize else Vector2.new(900, 560)
	touchMenus.Visible, touchActions.Visible = mobile, mobile
	touchMenus.Size = UDim2.fromOffset(52, math.clamp(viewport.Y - 260, 52, 356))
	hints.Visible, languageButton.Visible = not mobile, not mobile
	statsScale.Scale, needsScale.Scale = if mobile then 0.65 else 1, if mobile then 0.65 else 1
	stats.Position = if mobile then UDim2.new(1, -132, 0, 64) else UDim2.new(1, -200, 0.42, 0)
	needsPanel.Position = if mobile
		then UDim2.new(1, -132, 0, 130)
		else UDim2.new(1, -200, 0.42, 102)
	cameraButton.Parent = if mobile then touchActions else gui
	cameraButton.Size = if mobile then UDim2.fromOffset(64, 48) else UDim2.fromOffset(150, 28)
	cameraButton.Position = if mobile
		then UDim2.new(1, -168, 1, -120)
		else UDim2.new(1, -160, 0, 88)
	cameraButton.TextScaled, cameraButton.TextWrapped = mobile, mobile
	local size = if mobile and viewport.X <= 700 then 40 else SLOT
	local width = 9 * (size + 4) + 8
	hotbar.Size = UDim2.fromOffset(width, size + 12)
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -8)
	hotbarScale.Scale = if mobile then math.min(1, (viewport.X - 20) / width) else 1
	survivalScale.Scale = if mobile then 0.85 else 1
	for i, slot in ipairs(hotbarSlots) do
		slot.Position = UDim2.fromOffset(6 + (i - 1) * (size + 4), 6)
		slotScales[i].Scale = size / SLOT
	end
	if mobile then
		toast.Size = UDim2.fromOffset(math.min(520, viewport.X - 20), 66)
		toast.Position = UDim2.new(0.5, -toast.Size.X.Offset / 2, 0, 12)
		teleportCountdown.Size = UDim2.new(1, -120, 0, 28)
		teleportCountdown.Position = UDim2.new(0, 60, 1, -224)
		teleportCountdown.TextScaled = true
	else
		toast.Size, toast.Position = UDim2.fromOffset(520, 66), UDim2.new(1, -530, 0, 12)
		teleportCountdown.Size, teleportCountdown.Position =
			UDim2.fromOffset(520, 28), UDim2.new(0.5, -260, 1, -180)
		teleportCountdown.TextScaled = false
	end
	for win, layout in pairs(windowLayouts) do
		fitWindow(win, layout)
	end
	cancelDigInput()
	renderCameraButton()
end
local viewportConnection: RBXScriptConnection? = nil
local function watchViewport()
	if viewportConnection then
		viewportConnection:Disconnect()
	end
	camera = workspace.CurrentCamera
	if camera then
		viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateLayout)
	end
	updateLayout()
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(updateLayout)
UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(updateLayout)
watchViewport()
RunService.RenderStepped:Connect(function()
	local controlsVisible = isMobile() and currentWindowKind == nil
	touchMenus.Visible, touchActions.Visible = controlsVisible, controlsVisible
	crosshair.Visible = (firstPerson or isMobile()) and currentWindowKind == nil
	if currentWindowKind then
		cancelDigInput()
	end
end)

-- ---------------------------------------------------------------- keys
UserInputService.InputBegan:Connect(function(input, processed)
	-- Roblox can mark Escape as processed when it opens its own menu.
	if input.KeyCode == Enum.KeyCode.Escape then
		closeWindow()
		return
	end
	if processed then
		return
	end
	local k = input.KeyCode
	if k == Enum.KeyCode.E then
		open("inventory")
	elseif k == Enum.KeyCode.J then
		open("upgrade")
	elseif k == Enum.KeyCode.U then
		open("level")
	elseif k == Enum.KeyCode.O then
		open("jobs")
	elseif k == Enum.KeyCode.L then
		open("achievements")
	elseif k == Enum.KeyCode.M then
		open("locations")
	elseif k == Enum.KeyCode.V then
		toggleFirstPerson()
	elseif k == Enum.KeyCode.F then
		useConsumable()
	elseif k.Value >= Enum.KeyCode.One.Value and k.Value <= Enum.KeyCode.Nine.Value then
		selectSlot(k.Value - Enum.KeyCode.One.Value + 1)
	end
end)
UserInputService.InputChanged:Connect(function(input, processed)
	if processed or not profile or input.UserInputType ~= Enum.UserInputType.MouseWheel then
		return
	end
	local n = profile.selectedSlot - math.sign(input.Position.Z)
	selectSlot((n - 1) % 9 + 1)
end)
for i = 1, 9 do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = hotbarSlots[i]
	btn.Activated:Connect(function()
		selectSlot(i)
	end)
end

print(string.format("[coco-prison] client ready (%s)", locale))
