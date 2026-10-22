--!strict
-- Client: digging input (hold on PC / touch button / gamepad), target outline and crack stages,
-- HUD (right stats panel, hotkeys), hotbar, inventory [E], shop/sell/food windows (prompts),
-- upgrade [J], level [U], jobs [O], achievements [L], locations [M], case results (server event).

local ContextActionService = game:GetService("ContextActionService")
local CollectionService = game:GetService("CollectionService")
local GuiService = game:GetService("GuiService")
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
local AchievementsWindow = require(script.AchievementsWindow)
local ExchangeWindow = require(script.ExchangeWindow)
local ArtifactWindow = require(script.ArtifactWindow)
local SellWindow = require(script.SellWindow)
local ShopWindow = require(script.ShopWindow)
local CreativeWindow = require(script.CreativeWindow)
local BossHud = require(script.BossHud)
local BossAnimator = require(script.BossAnimator)
local IndoorLighting = require(script.IndoorLighting)
local CharacterAnimator = require(script.CharacterAnimator)
local Combat = require(ReplicatedStorage.Shared.Combat)
CharacterAnimator.Start() -- keyframed swings on every character (ours and the relayed ones)
local TrainerWindow = require(script.TrainerWindow)
local FactionWindow = require(script.FactionWindow)
local UpgradeWindow = require(script.UpgradeWindow)
local HeldItem = require(script.HeldItem)
local ArmorVisual = require(script.ArmorVisual)
local BlockBreak = require(script.BlockBreak)
local EffectsHud = require(script.EffectsHud)
local FirstPersonHand = require(script.FirstPersonHand)
local Footsteps = require(script.Footsteps)
local ItemInfo = require(Shared.ItemInfo)
local Wire = require(Shared.Wire)
local BlockColors = require(Shared.BlockColors)
HeldItem.Start()
FirstPersonHand.Start()
Footsteps.Start()
require(Shared.Sfx).listen() -- sounds the server asks for (hurt, chests, eating, level up…)
ArmorVisual.Start()
BlockBreak.Start()

local player = Players.LocalPlayer
local locale = Config.defaultLocale
local camera = workspace.CurrentCamera
local function isMobile(): boolean
	-- QA (Studio only): the device emulator sometimes reports a keyboard; workspace attribute
	-- ForceMobile = true forces the phone layout
	if RunService:IsStudio() and workspace:GetAttribute("ForceMobile") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end
local localizedButtons: { [TextButton]: string } = {}
local localizedLabels: { [TextLabel]: string } = {} -- captions under touch icons
local T = function(key: string, ...: any)
	return Strings.t(key, locale, ...)
end

local profile: Types.Profile? = nil

local gui = Instance.new("ScreenGui")
gui.Name = "PrisonHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling -- windows (later children) draw above the HUD
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
-- [владелец 22.10: «кнопку 3 лица кинь в меню»] no camera button on the HUD: the view switches from the
-- touch menu (Touch_camera) or with V / F5 like Minecraft
local function renderCameraButton()
	crosshair.Visible = firstPerson or isMobile()
end
local THIRD_PERSON_ZOOM = 12
local function toggleFirstPerson()
	firstPerson = not firstPerson
	local currentCamera = workspace.CurrentCamera
	if currentCamera then
		currentCamera.CameraType = Enum.CameraType.Custom
	end
	if firstPerson then
		player.CameraMode = Enum.CameraMode.LockFirstPerson
	else
		-- Classic mode alone keeps the camera glued to the head (zoom 0.5); push it back out by
		-- clamping the zoom range for one frame, then restore the normal range.
		player.CameraMode = Enum.CameraMode.Classic
		player.CameraMinZoomDistance = THIRD_PERSON_ZOOM
		player.CameraMaxZoomDistance = THIRD_PERSON_ZOOM
		task.delay(0.1, function()
			player.CameraMinZoomDistance = 0.5
			player.CameraMaxZoomDistance = 128
		end)
	end
	renderCameraButton()
end

-- ---------------------------------------------------------------- HUD: stats panel (right), hints, toast, combo
local stats = Ui.panel(gui, UDim2.fromOffset(190, 114), UDim2.new(1, -200, 0.42, 0))
Ui.label(stats, "PRISON", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 2), 13, Ui.colors.header)
local statLevel = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 20), 14)
local statMoney = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 38), 14)
local statBlocks = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 56), 14)
local statRats = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 74), 14)
local statKD = Ui.label(stats, "", UDim2.new(1, -12, 0, 18), UDim2.fromOffset(6, 92), 14)

-- [владелец 21.10] no hygiene / sleep / toilet bars: NeedsService sends a message when a need runs out
-- and the effect icon (EffectsHud) shows while it lasts

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
-- the destination's preview while the teleport channel runs (set up after locationPreview, below)
local showTeleportPreview: (locationId: string?) -> () = function() end
local teleportCardLabel: TextLabel? = nil -- the countdown inside the preview card, when there is one
local function renderTeleportCountdown()
	local endsAt = teleportEndsAt
	local cardLabel = teleportCardLabel
	teleportCountdown.Visible = endsAt ~= nil and cardLabel == nil
	if endsAt then
		local text = T("teleport_channel", math.max(0, math.ceil(endsAt - os.clock())))
		teleportCountdown.Text = text
		if cardLabel then
			cardLabel.Text = text
		end
	end
end
Remotes.event("TeleportChannel").OnClientEvent:Connect(function(seconds: any, locationId: any)
	if seconds == nil then
		teleportEndsAt = nil
		showTeleportPreview(nil)
	elseif typeof(seconds) == "number" and seconds > 0 and seconds < math.huge then
		teleportEndsAt = os.clock() + seconds
		showTeleportPreview(if typeof(locationId) == "string" then locationId else nil)
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
-- [владелец 21.10] like Minecraft: hearts start at the hotbar's left edge, food ends at its right edge
survivalHud.AnchorPoint = Vector2.new(0, 1)
survivalHud.Position = UDim2.fromOffset(6, -4)
survivalHud.Size = UDim2.new(1, -12, 0, 24)
survivalHud.Parent = hotbar
local survivalScale = Instance.new("UIScale")
survivalScale.Parent = survivalHud
type SurvivalMeter = { fills: { Frame }, tooltip: TextLabel }
local function buildMeter(rightAligned: boolean, glyph: string, color: Color3): SurvivalMeter
	local group = Instance.new("Frame")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromOffset(190, 24)
	group.AnchorPoint = Vector2.new(if rightAligned then 1 else 0, 0)
	group.Position = UDim2.fromScale(if rightAligned then 1 else 0, 0)
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
		-- the food row fills from the right like Minecraft's: icon 1 is the rightmost
		cell.Position = UDim2.fromOffset((if rightAligned then 10 - i else i - 1) * 19, 0)
		cell.BackgroundTransparency = 1
		cell.Parent = group
		drawIcon(cell, false)
		local clip = Instance.new("Frame")
		clip.Size = UDim2.fromScale(1, 1)
		clip.BackgroundTransparency = 1
		clip.ClipsDescendants = true
		clip.Parent = cell
		if rightAligned then
			-- a half icon keeps its right half: the clip shrinks towards the right and the icon inside
			-- stays pinned to the cell's right edge (it was drawn from the clip's left edge, shifted)
			clip.AnchorPoint, clip.Position = Vector2.new(1, 0), UDim2.fromScale(1, 0)
			local holder = Instance.new("Frame")
			holder.BackgroundTransparency = 1
			holder.Size = UDim2.fromOffset(18, 24)
			holder.AnchorPoint, holder.Position = Vector2.new(1, 0), UDim2.fromScale(1, 0)
			holder.Parent = clip
			drawIcon(holder, true)
		else
			drawIcon(clip, true)
		end
		fills[i] = clip
	end
	return { fills = fills, tooltip = tooltip }
end
local hearts = buildMeter(false, "♥", Color3.fromRGB(235, 55, 55))
local drumsticks = buildMeter(true, "🍗", Color3.fromRGB(225, 150, 65))

-- Above the meters, bottom to top (all inside the hotbar so they share its scale): combo, the held
-- item's name, the hint of a harmful effect.
local function hudLine(y: number, size: number, color: Color3): TextLabel
	local label =
		Ui.label(hotbar, "", UDim2.new(1, 160, 0, size + 4), UDim2.new(0.5, 0, 0, y), size, color)
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextStrokeTransparency = 0.4
	return label
end
-- [владелец 21.10] combo above the hearts and food; resets after 30 s without digging (server)
local combo = hudLine(-38, 14, Ui.colors.muted)
local comboMultiplier: number? = nil
local comboBlocks = 0
local comboAt = 0 -- os.clock() of the last dug block
-- [владелец 21.10] combo timer: a bar under the combo text, full after every block, draining over the
-- idle time (rules.combo.breakAfterIdleSeconds = 30 s) — empty means the combo resets
local comboBar = Ui.inset(hotbar, UDim2.fromOffset(180, 5), UDim2.new(0.5, 0, 0, -31))
comboBar.AnchorPoint = Vector2.new(0.5, 1)
comboBar.Visible = false
local comboFill = Instance.new("Frame")
comboFill.BackgroundColor3 = Ui.colors.money
comboFill.BorderSizePixel = 0
comboFill.Size = UDim2.fromScale(1, 1)
comboFill.Parent = comboBar
local function renderCombo()
	if comboMultiplier then
		combo.Text = T("combo", comboMultiplier, comboBlocks, Config.rules.combo.blocksPerStep)
		combo.TextColor3 = if comboMultiplier > 1 then Ui.colors.money else Ui.colors.muted
	end
end
RunService.Heartbeat:Connect(function()
	local active = comboMultiplier ~= nil and (comboMultiplier > 1 or comboBlocks > 0)
	local left = if active
		then 1 - (os.clock() - comboAt) / Config.rules.combo.breakAfterIdleSeconds
		else 0
	comboBar.Visible = active and left > 0
	comboFill.Size = UDim2.fromScale(math.clamp(left, 0, 1), 1)
	comboFill.BackgroundColor3 = if left < 0.25 then Ui.colors.close else Ui.colors.money
end)
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
	-- the HUD ignores the GUI inset, so keep windows below Roblox's top bar (58 px on phones),
	-- otherwise its menu/chat buttons cover the window's tabs and title
	local inset = GuiService:GetGuiInset().Y
	local width = layout.size.X.Offset + layout.size.X.Scale * viewport.X
	local height = layout.size.Y.Offset + layout.size.Y.Scale * viewport.Y
	layout.scale.Scale =
		math.clamp(math.min((viewport.X - 20) / width, (viewport.Y - inset - 12) / height), 0.1, 1)
	local top = layout.position.Y.Scale * viewport.Y
		+ layout.position.Y.Offset
		- layout.anchor.Y * height * layout.scale.Scale
	if layout.scale.Scale < 1 or top < inset then
		win.AnchorPoint = Vector2.new(0.5, 0.5)
		win.Position = UDim2.new(0.5, 0, 0.5, (inset - 4) / 2)
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
	-- explicitly above the HUD: a window scaled down on a phone covers the hotbar, and with equal ZIndex
	-- the order between the two siblings is not guaranteed (suspected cause of "Открыть" doing nothing
	-- on the owner's phone, 22.10 — not reproduced in the emulator)
	win.ZIndex = 10
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

local glintLabels: { [ImageLabel]: boolean } = {}
RunService.Heartbeat:Connect(function()
	local pulse = 0.4 + 0.3 * math.sin(os.clock() * 4)
	for label in pairs(glintLabels) do
		if label.Parent then
			label.ImageTransparency = pulse
		else
			glintLabels[label] = nil
		end
	end
end)

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
	-- [владелец 21.10] no text on items/blocks: without a picture the slot shows a tile of the block colour
	local tile = if stack and not icon then BlockColors.of(stack.id) else nil
	image.Visible = icon ~= nil or tile ~= nil
	image.BackgroundColor3 = tile or Color3.new()
	image.BackgroundTransparency = if tile then 0 else 1
	-- Minecraft-style enchant glint: purple copy of the icon pulsing over it
	local glint = image:FindFirstChild("Glint")
	if glint and glint:IsA("ImageLabel") then
		local enchanted = stack ~= nil and icon ~= nil and Config.isEnchanted(stack.id, stack.level)
		glint.Image = icon or ""
		glint.Visible = enchanted
		glintLabels[glint] = if enchanted then true else nil
	end
	name.Visible = false
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

-- Minecraft: the name of the newly selected item shows above the hotbar for 2 s, then fades
local heldName = hudLine(-58, 17, Ui.colors.white)
heldName.Visible = false
local heldNameToken = 0

-- [владелец 21.10] while a need's effect lasts, its hint (where to go / what to use) stays on screen
local effectHint = hudLine(-84, 14, Color3.fromRGB(255, 225, 120))
effectHint.TextWrapped = true
effectHint.BackgroundColor3 = Ui.colors.panel
effectHint.BackgroundTransparency = 0.35
effectHint.Visible = false
local NEED_EFFECTS = { { "Nausea", "hygiene" }, { "Insomnia", "sleep" }, { "Slowness", "toilet" } }
task.spawn(function()
	while true do
		local character = player.Character
		local lines = {}
		for _, pair in ipairs(NEED_EFFECTS) do
			local level = if character then character:GetAttribute(pair[1]) else nil
			if typeof(level) == "number" and level > 0 then
				table.insert(lines, T("need_effect_" .. pair[2]))
			end
		end
		effectHint.Text = table.concat(lines, string.char(10))
		effectHint.Visible = #lines > 0
		-- one line per effect (AutomaticSize does not grow a bottom-anchored label): size it by the count
		effectHint.Size = UDim2.new(1, 160, 0, math.max(1, #lines) * 20 + 4)
		task.wait(0.5)
	end
end)
local function showHeldName(stack: Types.ItemStack?)
	heldNameToken += 1
	local token = heldNameToken
	if not stack then
		heldName.Visible = false
		return
	end
	local first = ItemInfo.lines(stack, locale)[1]
	heldName.Text = first.text
	heldName.TextColor3 = first.color
	heldName.TextTransparency, heldName.TextStrokeTransparency = 0, 0.4
	heldName.Visible = true
	task.delay(2, function()
		for step = 1, 10 do
			if heldNameToken ~= token then
				return
			end
			heldName.TextTransparency = step / 10
			heldName.TextStrokeTransparency = 0.4 + 0.6 * step / 10
			task.wait(0.05)
		end
		if heldNameToken == token then
			heldName.Visible = false
		end
	end)
end

local function selectSlot(n: number)
	if profile and profile.selectedSlot ~= n then
		profile.selectedSlot = n
		renderHotbar()
		Remotes.event("SelectSlot"):FireServer(n)
		showHeldName(profile.inventory[n])
	end
end

-- ---------------------------------------------------------------- windows
local openWindow: Frame? = nil
local currentWindowKind: string? = nil
local refreshLocations: (() -> ())? = nil
local refreshInventory: (() -> ())? = nil
local refreshChest: (() -> ())? = nil
local refreshMenu: ((Types.Profile?) -> ())? = nil
local openedCaseId = "ordinaryCase"
local function closeWindow()
	if currentWindowKind == "case" then
		Remotes.event("CaseClose"):FireServer(openedCaseId)
	end
	refreshLocations = nil
	refreshMenu = nil
	refreshInventory, refreshChest = nil, nil
	if openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
	currentWindowKind = nil
	UserInputService.ModalEnabled = false
end

-- Inventory [E] in the look of the original: the vanilla Minecraft survival inventory GUI
-- (176×166 GUI px at scale 2): four armour slots, the player preview, the decorative 2×2 "Создание"
-- grid, the 9×3 inventory and the hotbar. Armour is equipped by dragging a piece onto its slot (or a
-- double tap / shift-click), taken off by dragging it back; profile updates repaint slots in place.
local function buildInventory(): Frame
	local MC = Ui.MC
	local win, raw =
		createWindow(gui, T("inventory"), UDim2.fromOffset(176 * MC, 166 * MC), closeWindow)
	local content = Ui.toMc(win, raw)
	local views: { { index: number, name: TextLabel, count: TextLabel, image: ImageLabel } } = {}
	local armorViews: { { part: string, name: TextLabel, count: TextLabel, image: ImageLabel } } =
		{}
	local ARMOR_PARTS = { "helmet", "chestplate", "leggings", "boots" }
	local function renderArmor(part: string, name: TextLabel, count: TextLabel, image: ImageLabel)
		local armor = if profile then profile.armor[part] else nil
		renderSlot(name, count, image, armor or { id = part, level = 1, count = 1 })
		name.Visible = false
		image.ImageColor3 = if armor then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		image.ImageTransparency = if armor then 0 else 0.55
	end
	local function stackAt(address: DragDrop.Address): Types.ItemStack?
		if not profile then
			return nil
		end
		if address.container == "armor" then
			return profile.armor[ARMOR_PARTS[address.index]]
		end
		return profile.inventory[address.index]
	end
	local drag = DragDrop.new(win, stackAt, function(from, to, count)
		if from.container == "inv" and to.container == "armor" then
			local stack = stackAt(from)
			if stack and stack.id == ARMOR_PARTS[to.index] then
				Remotes.event("EquipArmor"):FireServer(from.index)
			end
		elseif from.container == "armor" and to.container == "inv" then
			Remotes.event("UnequipArmor"):FireServer(ARMOR_PARTS[from.index], to.index)
		elseif from.container == "inv" and to.container == "inv" then
			Remotes.event("InventoryMove"):FireServer(from.index, to.index, count)
		end
	end, function(from)
		if from.container == "armor" then
			Remotes.event("UnequipArmor"):FireServer(ARMOR_PARTS[from.index])
			return
		end
		local stack = stackAt(from)
		if stack and table.find(ARMOR_PARTS, stack.id) then
			Remotes.event("EquipArmor"):FireServer(from.index)
			return
		end
		local first, last = if from.index <= 9 then 10 else 1, if from.index <= 9 then 36 else 9
		for index = first, last do
			if not stackAt({ container = "inv", index = index }) then
				Remotes.event("InventoryMove"):FireServer(from.index, index)
				break
			end
		end
	end, function(from, count)
		Remotes.event("DropItem"):FireServer(from.index, count)
	end)
	local function slotAt(index: number, x: number, y: number)
		local f, name, count, image = Ui.mcSlot(content)
		f.Position = UDim2.fromOffset(x * MC, y * MC)
		renderSlot(name, count, image, if profile then profile.inventory[index] else nil)
		table.insert(views, { index = index, name = name, count = count, image = image })
		drag.Bind(f, { container = "inv", index = index })
	end
	-- [ваниль] armour column at (8, 8), inventory at (8, 84), hotbar at (8, 142)
	for i, part in ipairs(ARMOR_PARTS) do
		local f, name, count, image = Ui.mcSlot(content)
		f.Position = UDim2.fromOffset(8 * MC, (8 + (i - 1) * 18) * MC)
		renderArmor(part, name, count, image)
		table.insert(armorViews, { part = part, name = name, count = count, image = image })
		drag.Bind(f, { container = "armor", index = i })
	end
	for r = 0, 2 do
		for col = 0, 8 do
			slotAt(10 + r * 9 + col, 8 + col * 18, 84 + r * 18)
		end
	end
	for col = 0, 8 do
		slotAt(col + 1, 8 + col * 18, 142)
	end
	-- player preview [ваниль] (26, 8) 49×70
	local preview = Instance.new("ViewportFrame")
	preview.Size = UDim2.fromOffset(49 * MC, 70 * MC)
	preview.Position = UDim2.fromOffset(26 * MC, 8 * MC)
	preview.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	preview.BorderSizePixel = 0
	preview.Ambient = Color3.fromRGB(200, 200, 200)
	preview.LightColor = Color3.fromRGB(255, 255, 255)
	preview.Parent = content
	Ui.bevel(preview, MC, Ui.colors.mcSlotDark, Ui.colors.mcLight)
	local previewCamera = Instance.new("Camera")
	previewCamera.Parent = preview
	preview.CurrentCamera = previewCamera
	local world = Instance.new("WorldModel")
	world.Parent = preview
	local function renderPreview()
		world:ClearAllChildren()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			return
		end
		character.Archivable = true
		local clone = character:Clone()
		character.Archivable = false
		for _, d in ipairs(clone:GetDescendants()) do
			if
				d:IsA("Script")
				or d:IsA("LocalScript")
				or d:IsA("Sound")
				or d:IsA("BillboardGui")
			then
				d:Destroy()
			end
		end
		local cloneRoot = clone:FindFirstChild("HumanoidRootPart") :: BasePart
		clone:PivotTo(CFrame.new(0, 0, 0))
		clone.Parent = world
		previewCamera.CFrame = CFrame.lookAt(
			cloneRoot.Position + Vector3.new(0, 0.3, -8.5),
			cloneRoot.Position + Vector3.new(0, 0.3, 0)
		)
		previewCamera.FieldOfView = 36
	end
	renderPreview()
	-- decorative crafting area of the vanilla GUI [ваниль] (97, 8) label, 2×2 grid at (98, 18), result at (154, 28)
	Ui.mcText(
		content,
		T("crafting"),
		UDim2.fromOffset(60 * MC, 10 * MC),
		UDim2.fromOffset(97 * MC, 7 * MC)
	)
	for i = 0, 3 do
		local f = Ui.mcSlot(content)
		f.Position = UDim2.fromOffset((98 + (i % 2) * 18) * MC, (18 + math.floor(i / 2) * 18) * MC)
	end
	local arrow = Ui.mcText(
		content,
		"➜",
		UDim2.fromOffset(18 * MC, 18 * MC),
		UDim2.fromOffset(133 * MC, 28 * MC),
		11 * MC
	)
	arrow.TextXAlignment = Enum.TextXAlignment.Center
	arrow.TextColor3 = Ui.colors.mcSlot
	local result = Ui.mcSlot(content, 26 * MC)
	result.Position = UDim2.fromOffset(150 * MC, 24 * MC)
	local shield = Ui.mcSlot(content)
	shield.Position = UDim2.fromOffset(77 * MC, 62 * MC)
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
		renderPreview()
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
-- spots inside a location (LocationSpawn + Spot); `at` = the locations that have it (nil = all).
-- [владелец 22.10] spots and teleporting between them exist only at the spawn (prison)
local SPOTS: { { id: string, icon: string, at: { string }? } } = {
	{ id = "spawn", icon = "⌂", at = { "prison" } },
	{ id = "mine", icon = "⛏", at = { "prison" } },
	{ id = "small_mine", icon = "⛏", at = { "prison" } },
	{ id = "market", icon = "$", at = { "prison" } },
	{ id = "canteen", icon = "🍎", at = { "prison" } },
	{ id = "bedroom", icon = "☾", at = { "prison" } },
	{ id = "bath", icon = "♨", at = { "prison" } },
	{ id = "trainer", icon = "⚔", at = { "prison" } },
	{ id = "showcase", icon = "★", at = { "prison" } }, -- витрина брони и инструментов (scripts/build-showcase.luau)
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
		and (not location.requiresFaction or Config.faction(p.faction) ~= nil)
end

-- [владелец 22.10] a red «PVP» plate in the corner of the preview of every PvP location
local function pvpBadge(preview: GuiObject, location: Config.Location)
	if not location.pvp then
		return
	end
	local badge = Instance.new("TextLabel")
	badge.Name = "PvpBadge"
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -6, 0, 6)
	badge.Size = UDim2.fromOffset(48, 22)
	badge.BackgroundColor3 = Color3.fromRGB(200, 35, 35)
	badge.BorderSizePixel = 0
	badge.Font = Enum.Font.GothamBold
	badge.Text = "PVP"
	badge.TextColor3 = Color3.new(1, 1, 1)
	badge.TextSize = 14
	badge.ZIndex = preview.ZIndex + 2
	badge.Parent = preview
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 4)
	corner.Parent = badge
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
		pvpBadge(image, location)
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
	pvpBadge(view, location)
	return view
end

-- [владелец 22.10: «когда телепортируются — превью фото локации»] a card above the countdown with the
-- top-down picture of the destination, its name and the PVP plate
do
	local card: Frame? = nil
	showTeleportPreview = function(locationId: string?)
		if card then
			card:Destroy()
			card = nil
		end
		local location = if locationId then Config.location(locationId) else nil
		if not location then
			return
		end
		-- centred a little above the middle, scaled down to fit small (phone) screens; the countdown
		-- moves into the card
		local frame = Ui.panel(gui, UDim2.fromOffset(380, 262), UDim2.fromScale(0.5, 0.42))
		frame.Name = "TeleportPreview"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.ZIndex = 8
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(900, 600)
		local fit = Instance.new("UIScale")
		fit.Scale = math.min(1, viewport.Y * 0.62 / 262, viewport.X * 0.9 / 380)
		fit.Parent = frame
		locationPreview(frame, location, UDim2.new(1, -12, 0, 196), UDim2.fromOffset(6, 6))
		local name = Ui.label(
			frame,
			Strings.locationName(location.name, locale),
			UDim2.new(1, -12, 0, 26),
			UDim2.fromOffset(6, 204),
			18,
			Ui.colors.header
		)
		name.TextXAlignment = Enum.TextXAlignment.Center
		local countdown = Ui.label(
			frame,
			"",
			UDim2.new(1, -12, 0, 22),
			UDim2.fromOffset(6, 232),
			14,
			Ui.colors.text
		)
		countdown.TextXAlignment = Enum.TextXAlignment.Center
		teleportCardLabel = countdown
		card = frame
		frame.Destroying:Once(function()
			if teleportCardLabel == countdown then
				teleportCardLabel = nil
			end
		end)
	end
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
			elseif selected.requiresFaction and not Config.faction(profile.faction) then
				refusal.Text = T("faction_required") -- [клиент] «Необходимо находиться во фракции»
			elseif not available then
				refusal.Text = T("location_pass_required")
			end
		end
		for _, card in ipairs(cards) do
			local unlocked = locationAvailable(card.location)
			card.name.Text = (if unlocked then "" else "🔒 ")
				.. Strings.locationName(card.location.name, locale)
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
			Strings.locationName(location.name, locale),
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
					-- some bosses have no level in the wiki: fall back to their location's level
					boss.name
						.. " · "
						.. T("location_level", boss.unlockLevel or location.unlockLevel)
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
			closeWindow() -- [владелец 21.10] the menu closes; the countdown shows in the HUD
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
			local shownSpots = 0
			for i, spot in ipairs(SPOTS) do
				if spot.at and not (profile and table.find(spot.at, profile.location)) then
					continue
				end
				shownSpots += 1
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
						closeWindow()
					end
				end)
			end
			if shownSpots == 0 then
				Ui.label(
					grid,
					T("spots_only_spawn"),
					UDim2.new(1, -8, 0, 40),
					UDim2.new(),
					16,
					Ui.colors.muted
				).TextWrapped =
					true
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
	sell = function()
		local win, refresh = SellWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	shop = function()
		local win, refresh =
			ShopWindow.build(gui, "shop", profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	food = function()
		local win, refresh =
			ShopWindow.build(gui, "food", profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	trainer = function()
		local win, refresh = TrainerWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	upgrade = function()
		local win, refresh = UpgradeWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	level = buildLevel,
	jobs = buildJobs,
	achievements = function()
		local win, refresh =
			AchievementsWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	creative = function()
		local win, refresh = CreativeWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	artifacts = function()
		local win, refresh = ArtifactWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	stars = function()
		local win, refresh =
			ExchangeWindow.build(gui, "stars", profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	shards = function()
		local win, refresh =
			ExchangeWindow.build(gui, "shards", profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	case = buildCase,
	locations = buildLocations,
	factions = function()
		local win, refresh = FactionWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
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
	-- Roblox hides its touch controls and stops touch camera panning while a menu is open
	UserInputService.ModalEnabled = true
end
local function refreshWindow(force: boolean?)
	if not force and refreshMenu then
		refreshMenu(profile)
		return
	end
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
local artifactButton = Ui.button(
	gui,
	T("artifacts_hotkey"),
	UDim2.fromOffset(190, 44),
	UDim2.fromOffset(8, 64),
	Ui.colors.buttonGrey
)
localizedButtons[artifactButton] = "artifacts_hotkey"
artifactButton.Activated:Connect(function()
	open("artifacts")
end)

-- ---------------------------------------------------------------- world signs in the player's language
-- Signs are built in Russian; the original text is kept in the "RuText" attribute and re-rendered
-- whenever the locale changes.
local function localizeLabel(label: TextLabel)
	local ru = label:GetAttribute("RuText")
	if typeof(ru) ~= "string" then
		ru = label.Text
		label:SetAttribute("RuText", ru)
	end
	label.Text = Strings.worldText(ru, locale)
end
local function localizeWorld()
	for _, gui in ipairs(workspace:GetDescendants()) do
		if gui:IsA("BillboardGui") or gui:IsA("SurfaceGui") then
			for _, label in ipairs(gui:GetDescendants()) do
				if label:IsA("TextLabel") then
					localizeLabel(label)
				end
			end
		end
	end
end
workspace.DescendantAdded:Connect(function(instance)
	if instance:IsA("TextLabel") then
		local gui = instance:FindFirstAncestorWhichIsA("BillboardGui")
			or instance:FindFirstAncestorWhichIsA("SurfaceGui")
		if gui then
			task.defer(localizeLabel, instance)
		end
	end
end)
task.defer(localizeWorld)

-- ---------------------------------------------------------------- profile rendering
local function render(p: Types.Profile)
	local nextLocale = p.locale or Config.defaultLocale
	local rebuild = locale ~= nextLocale or (profile ~= nil and profile.location ~= p.location)
	profile = p
	locale = nextLocale
	if rebuild then
		localizeWorld()
	end
	languageButton.Text = T("language_code")
	renderCameraButton()
	for button, key in pairs(localizedButtons) do
		button.Text = T(key)
	end
	for label, key in pairs(localizedLabels) do
		label.Text = T(key)
	end
	hints.Text = T("keys_hint")
	renderTeleportCountdown()
	renderCombo()
	statLevel.Text = string.format("%s  %d", T("level"), p.level)
	statLevel.TextColor3 = Ui.colors.level
	-- [владелец 21.10] the bar shows whole money (exact amounts stay in the sell window)
	-- the original's money format ("0.500"): rewards below 1 $ (a rat gives 0.5) were shown as 0 [владелец 22.10]
	statMoney.Text = string.format("%s  %s $", T("coins"), Strings.money(p.coins))
	statMoney.TextColor3 = Ui.colors.money
	statBlocks.Text = string.format("%s  %s", T("blocks"), Strings.big(p.blocksTotal))
	statRats.Text = string.format("%s  %d", T("rats"), p.stats.rats or 0)
	statKD.Text =
		string.format("%s  %d / %d", T("kd_label"), p.stats.kills or 0, p.stats.deaths or 0)
	renderHotbar()
	renderSurvival()
	refreshWindow(rebuild)
end
-- the profile crosses the network Wire-encoded (sparse slot tables survive intact)
Remotes.event("ProfileUpdated").OnClientEvent:Connect(function(encoded: any)
	render(Wire.decode(encoded))
end)
-- then only the changes (ProfileService diff): a changed field, or changed entries of a table field;
-- changed tables are copied so the previous profile stays as it was
Remotes.event("ProfilePatch").OnClientEvent:Connect(function(ops: any)
	if not profile or typeof(ops) ~= "table" then
		return
	end
	local nextProfile = table.clone(profile :: any)
	local copied: { [string]: boolean } = {}
	for _, op in ipairs(ops) do
		local value = if op.d then nil else Wire.decode(op.v)
		if op.c == nil then
			nextProfile[op.k] = value
		else
			local field = nextProfile[op.k]
			if not copied[op.k] then
				field = if typeof(field) == "table" then table.clone(field) else {}
				nextProfile[op.k] = field
				copied[op.k] = true
			end
			field[op.c] = value
		end
	end
	render(nextProfile)
end)
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
	if mult > 1 or n > 0 then
		comboAt = os.clock() -- a block was dug (a reset arrives as ×1, 0 blocks)
	end
	comboMultiplier, comboBlocks = mult, n
	renderCombo()
end)

-- Status effects (Nausea / Insomnia / Slowness from needs, event effects): HUD icons and the
-- Minecraft-like screen effects live in EffectsHud; it is placed next to the stats panel in updateLayout.
local effectsHud = EffectsHud.start(gui, T, showToast)
-- [владелец] no auto-jump on touch: jumping is the jump button only
player.AutoJumpEnabled = false
local function disableAutoJump(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		humanoid.AutoJumpEnabled = false
	end
end
player.CharacterAdded:Connect(disableAutoJump)
if player.Character then
	disableAutoJump(player.Character)
end

-- ---------------------------------------------------------------- ladders [ваниль]
-- On a Minecraft ladder you climb at ≈ 2.35 blocks/s and slide down at ≈ 3 blocks/s when idle.
-- Roblox climbing (truss) holds still, so when the humanoid is climbing with no input we push it
-- down the ladder slowly.
local LADDER_SLIDE = 1 -- full "away" push while idle = climbing down at the climb speed
local LADDER_FALL = -12 -- studs/s: 3 blocks/s like a Minecraft ladder [ваниль]
local LADDER_REACH = 4.5 -- studs from the ladder (the shaft is one block deep)
-- nearest ladder truss piece whose column (full height, one block deep) contains the position
local LADDER_ROOTS = { "Prison", "Quarry" } -- map folders holding mine ladders and MineAnchor_ parts
local function ladderAt(position: Vector3): BasePart?
	local best, bestD = nil, LADDER_REACH
	for _, rootName in ipairs(LADDER_ROOTS) do
		local mapRoot = workspace:FindFirstChild(rootName)
		for _, p in ipairs(if mapRoot then mapRoot:GetChildren() else {}) do
			if p.Name == "Ladder" and p:IsA("BasePart") then
				local d = p.Position - position
				if math.abs(d.Y) <= p.Size.Y / 2 + 1 then
					local flat = Vector3.new(d.X, 0, d.Z).Magnitude - 1
					if flat < bestD then
						best, bestD = p, flat
					end
				end
			end
		end
	end
	return best
end
-- facing axis of a ladder piece: the pit wall is on the far side of the truss from the shaft
local function awayFromWall(ladder: BasePart): Vector3
	local mapRoot = ladder.Parent -- the location folder (Prison, Quarry) holding this ladder
	-- the wall side is the one farther from the mine's centre: push toward the pit centre
	local centre = Vector3.new(0, 0, 0)
	for _, p in ipairs(mapRoot and mapRoot:GetChildren() or {}) do
		if p.Name:match("^MineAnchor_") and (p.Position - ladder.Position).Magnitude < 120 then
			centre = p.Position
			break
		end
	end
	local d = (centre - ladder.Position) * Vector3.new(1, 0, 1)
	if math.abs(d.X) > math.abs(d.Z) then
		return Vector3.new(math.sign(d.X), 0, 0)
	end
	return Vector3.new(0, 0, math.sign(d.Z))
end
-- Runs after the Roblox control script each frame. Climbing with no input → slide down slowly
-- (push away from the ladder; the climb controller turns it into a descent). Falling through the
-- ladder column → the fall is capped at ladder speed, like being caught by a Minecraft ladder.
RunService:BindToRenderStep("LadderSlide", Enum.RenderPriority.Last.Value, function()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = humanoid and humanoid.RootPart
	if not humanoid or not rootPart then
		return
	end
	local state = humanoid:GetState()
	local ladder = ladderAt(rootPart.Position)
	if not ladder then
		return
	end
	local toCentre = awayFromWall(ladder)
	if state == Enum.HumanoidStateType.Climbing then
		if humanoid.MoveDirection.Magnitude <= 0.05 then
			humanoid:Move(toCentre * LADDER_SLIDE, false)
		end
	elseif
		state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.FallingDown
	then
		local v = rootPart.AssemblyLinearVelocity
		if v.Y < LADDER_FALL then
			rootPart.AssemblyLinearVelocity = Vector3.new(v.X, LADDER_FALL, v.Z)
		end
		-- lean onto the ladder so the climb controller grabs it
		if humanoid.MoveDirection.Magnitude <= 0.05 then
			humanoid:Move(-toCentre * 0.3, false)
		end
	end
end)

-- ---------------------------------------------------------------- digging
-- [владелец 22.10: «как в майне»] the targeted block gets Minecraft's thin dark wire outline, no fill and no
-- glow; there is no progress bar: the crack stages on the block (BlockBreak) show how far it is dug
local highlight = Instance.new("SelectionBox")
highlight.Name = "BlockOutline"
highlight.Color3 = Color3.new(0, 0, 0)
highlight.LineThickness = 0.03
highlight.Transparency = 0.45
highlight.SurfaceTransparency = 1
highlight.Visible = false
highlight.Parent = gui

local MAX_TARGET = (Config.rules.digging and Config.rules.digging.reachStuds or 18) :: number -- [ваниль] 4.5 blocks
type Aim = { part: BasePart, hit: Vector3 }

-- Minecraft measures reach from the eyes to the point on the block face being aimed at [ваниль].
local function eyePosition(): Vector3?
	local character = player.Character
	local currentCamera = workspace.CurrentCamera
	if not character then
		return nil
	end
	local head = character:FindFirstChild("Head")
	if firstPerson and currentCamera then
		return currentCamera.CFrame.Position
	end
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.5, 0) else nil
end

-- The mine block under a screen point (or under the cursor / crosshair) within reach, with the hit point.
-- blocks hidden locally, waiting for the server to remove them (declared before aimAt, which skips them)
local pending: { [BasePart]: number } = {}

local function aimAt(point: Vector2?): Aim?
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
	-- hidden (predicted) blocks keep their collision, and CanQuery = false is ignored while CanCollide is
	-- on, so they are excluded here: the crosshair finds the block behind and digging goes on
	local ignore: { Instance } = { character }
	for part in pairs(pending) do
		table.insert(ignore, part)
	end
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 200, params)
	if not hit or not CollectionService:HasTag(hit.Instance, "MineBlock") then
		return nil
	end
	local eye = eyePosition()
	if not eye or (hit.Position - eye).Magnitude > MAX_TARGET then
		return nil
	end
	return { part = hit.Instance :: BasePart, hit = hit.Position }
end

local digging = false
local holding = false
local digTarget: BasePart? = nil
local digStarted = 0
local digNeeded = 0
local digPredicted = false -- the client already played the break and hid the block
local tapTarget: Aim? = nil -- touch: the block under the finger when the hold began
local accepted: { [BasePart]: boolean } = {} -- the server started its timer for this block (DigAccepted)
-- [владелец 21.10] with lag the server removes a block late: once it accepted the dig, wait longer
-- before showing the block again (2 s made blocks vanish, come back and vanish again)
local CONFIRM_TIMEOUT = 3
local ACCEPTED_TIMEOUT = 8
local nextDigAt = 0 -- Minecraft's pause after a break, none after an instant one [ваниль]

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
	if player:GetAttribute("Creative") then
		return Config.rules.creative.breakSeconds -- creative test mode (CreativeService)
	end
	if profile.needs.sleep <= 0 then
		return nil
	end
	local character = player.Character
	local haste = if character then tonumber(character:GetAttribute("Haste")) or 0 else 0
	return Config.breakTime(block, toolId, level, haste)
end

-- Prediction: the block disappears for this client the moment its timer ends; the server removes it
-- a few ms later. If the server rejects (or nothing arrives in 2 s) the block comes back as it was.
-- Only the look changes: collision stays until the server really removes the part, otherwise the
-- player could sink into the cell and fall through the unrendered solid cells below.
local function hideLocally(part: BasePart)
	part.LocalTransparencyModifier = 1
	part.CanQuery = false
	pending[part] = os.clock()
end
local function restoreLocally(part: BasePart)
	accepted[part] = nil
	if pending[part] then
		pending[part] = nil
		if part.Parent then
			part.LocalTransparencyModifier = 0
			part.CanQuery = true
		end
	end
end

local function stopDig(tellServer: boolean)
	if digging and tellServer then
		Remotes.event("DigCancel"):FireServer()
	end
	HeldItem.SetDigging(false)
	BlockBreak.Clear()
	digging = false
	digTarget = nil
	digPredicted = false
end

local function startDig(aim: Aim)
	local needed = expectedTime(aim.part)
	if not needed then
		Remotes.event("DigStart"):FireServer(aim.part, aim.hit) -- the server replies with the reason
		return
	end
	digging, digTarget, digStarted, digNeeded, digPredicted =
		true, aim.part, os.clock(), needed, false
	Remotes.event("DigStart"):FireServer(aim.part, aim.hit)
end

Remotes.event("DigAccepted").OnClientEvent
	:Connect(function(part: BasePart, needed: number, pause: number?)
		accepted[part] = true
		if digging and digTarget == part then
			digNeeded = needed -- the server's number is the truth; progress keeps its local start
			if pause and pause > 0 then
				digStarted = math.max(digStarted, os.clock() + pause - (os.clock() - digStarted))
			end
		end
	end)
-- a mine reset re-uses its block parts: anything this client hid while digging there shows again
task.spawn(function() -- the remote may appear only after the first mine build
	Remotes.event("MineReset").OnClientEvent:Connect(function(mineId: any)
		for part in pairs(pending) do
			if part:GetAttribute("MineId") == mineId then
				restoreLocally(part)
				if digTarget == part then
					stopDig(false)
				end
			end
		end
	end)
end)
Remotes.event("DigRejected").OnClientEvent:Connect(function(part: BasePart)
	restoreLocally(part)
	if digTarget == part then
		stopDig(false)
	end
end)

RunService.RenderStepped:Connect(function()
	local now = os.clock()
	for part, at in pairs(pending) do
		if not part.Parent then
			pending[part], accepted[part] = nil, nil
		elseif now - at > (if accepted[part] then ACCEPTED_TIMEOUT else CONFIRM_TIMEOUT) then
			restoreLocally(part) -- the server never removed it: show it again
			if digTarget == part then
				-- leave the "waiting for removal" state, so a held finger / button digs on by itself
				-- (before, digging froze here until the player tapped again)
				stopDig(false)
			end
		end
	end
	if currentWindowKind then
		holding = false
		tapTarget = nil
		stopDig(true)
		highlight.Visible = false
		return
	end
	local aim: Aim? = nil
	if tapTarget then
		-- touch hold: the target is fixed to the block the finger landed on
		local eye = eyePosition()
		if
			tapTarget.part:IsDescendantOf(workspace)
			and eye
			and (tapTarget.hit - eye).Magnitude <= MAX_TARGET + 1
		then
			aim = tapTarget
		else
			tapTarget = nil
			stopDig(true)
		end
	else
		aim = aimAt()
	end
	highlight.Adornee = if aim then aim.part else nil
	highlight.Visible = aim ~= nil and not pending[aim.part]
	if digging and digTarget then
		if digPredicted then
			-- [владелец 21.10, lag] do not wait for the server to remove the block: it gets our DigStarts
			-- in order and finishes this block before the next DigStart arrives, so dig on at once (the
			-- hidden block is not queryable, the crosshair finds the one behind it). Waiting cost a full
			-- round trip per block and looked like digging stopped.
			stopDig(false)
			if holding and aim and not pending[aim.part] and now >= nextDigAt then
				startDig(aim)
			end
		elseif not aim or aim.part ~= digTarget then
			stopDig(true)
			if holding and aim and not pending[aim.part] and now >= nextDigAt then
				startDig(aim)
			end
		else
			local k = math.clamp((now - digStarted) / digNeeded, 0, 1)
			BlockBreak.Update(digTarget, k)
			if k >= 1 then
				BlockBreak.Break(digTarget)
				hideLocally(digTarget)
				digPredicted = true
				nextDigAt = now + Config.hitDelayAfter(digNeeded)
			end
		end
	elseif holding and aim and not pending[aim.part] and now >= nextDigAt then
		startDig(aim)
	end
	-- keep swinging while the dig input is held on blocks (instant mining flips digging every few frames)
	HeldItem.SetDigging(digging or (holding and digPredicted) or (holding and aim ~= nil))
end)

-- Melee attack along the look direction (click / tap with nothing to dig), Better Combat-style
-- [владелец 22.10]: attacks come at the weapon's pace (vanilla attack speed), each plays the next animation
-- of the weapon's combo (sword: cut right, cut left, stab); the server hits along the arc (Combat).
local attackState: Combat.ComboState = { lastAt = -math.huge, index = 0 }
local function attack()
	local currentCamera = workspace.CurrentCamera
	if not currentCamera or currentWindowKind then
		return
	end
	local stack = if profile then profile.inventory[profile.selectedSlot] else nil
	local toolId = if stack and Config.tools[stack.id] then stack.id else nil
	local kind = Combat.kind(toolId)
	local duration = Combat.duration(kind, stack and stack.level)
	local now = os.clock()
	if now - attackState.lastAt < duration * 0.85 then
		return -- still in the previous attack
	end
	local _, blow = Combat.next(attackState, kind, duration, now)
	HeldItem.Attack(blow.animation, duration)
	-- falling after a jump = a critical hit (×1.5) on the server, like Minecraft
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local falling = humanoid ~= nil
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid.FloorMaterial == Enum.Material.Air
		and root.AssemblyLinearVelocity.Y < -1
	Remotes.event("Attack"):FireServer(currentCamera.CFrame.LookVector, falling)
end

-- PC / gamepad: hold the mouse button (R2) on a block
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
		local aim = aimAt()
		if aim and not pending[aim.part] then
			holding = true
			stopDig(true)
			startDig(aim)
		else
			holding = false
			attack()
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holding = false
		stopDig(true)
	end
	return Enum.ContextActionResult.Sink
end
ContextActionService:BindAction(
	"Dig",
	onDig,
	false,
	Enum.UserInputType.MouseButton1,
	Enum.KeyCode.ButtonR2
)

-- Touch, Minecraft Bedrock "split controls" style [владелец 21.10]: the crosshair is always on; a
-- finger held on the RIGHT half of the screen breaks the block under the crosshair (and keeps
-- breaking the next ones while held — the same loop as the PC mouse button), while moving that
-- finger still turns the camera (Roblox's touch camera). With food in hand and nothing to dig, the
-- hold eats it. The left half stays with Roblox's thumbstick and jump button.
local activeTouch: InputObject? = nil
local touchHeldSince = 0
local touchStart = Vector2.zero
local touchAte = false
local touchDragged = false -- the finger moved: it turns the camera and never digs or hits
local touchAim: Aim? = nil -- the block under the crosshair when the finger landed
local DIG_HOLD = 0.12 -- s the finger must rest before digging starts [владелец 21.10]
local DRAG_SLOP = 14 -- px of movement that makes a touch a camera drag
local EAT_HOLD = 0.6 -- s, like Bedrock's hold-to-use
local function isFood(): boolean
	local stack = if profile then profile.inventory[profile.selectedSlot] else nil
	local food = Config.rules.survival and Config.rules.survival.food
	return stack ~= nil and food ~= nil and typeof(food[stack.id]) == "number"
end
-- soap / toilet paper / sleeping bag in hand (they restore a need when used) [вики]
local function isNeedConsumable(): boolean
	local stack = if profile then profile.inventory[profile.selectedSlot] else nil
	if not stack then
		return false
	end
	for _, need in ipairs({ "hygiene", "sleep", "toilet" }) do
		if Config.needs[need].consumable == stack.id then
			return true
		end
	end
	return false
end
local function cancelDigInput()
	activeTouch = nil
	tapTarget = nil
	holding = false
	stopDig(true)
end
local function touchOnRightHalf(input: InputObject): boolean
	local currentCamera = workspace.CurrentCamera
	return currentCamera ~= nil and input.Position.X >= currentCamera.ViewportSize.X / 2
end
UserInputService.TouchStarted:Connect(function(input: InputObject, processed: boolean)
	if
		processed
		or not isMobile()
		or currentWindowKind
		or activeTouch
		or not touchOnRightHalf(input)
	then
		return
	end
	activeTouch, touchHeldSince, touchAte, touchDragged = input, os.clock(), false, false
	touchStart = Vector2.new(input.Position.X, input.Position.Y)
	-- [владелец 21.10] digging starts only when the finger rests DIG_HOLD on a block (Heartbeat below);
	-- a finger that moves turns the camera only — no swings, no dig sounds while looking around
	local aim = aimAt()
	touchAim = if aim and not pending[aim.part] then aim else nil
	holding = false
end)
UserInputService.TouchMoved:Connect(function(input: InputObject)
	if input ~= activeTouch or touchDragged then
		return
	end
	if (Vector2.new(input.Position.X, input.Position.Y) - touchStart).Magnitude > DRAG_SLOP then
		-- [владелец 21.10, like Minecraft] a finger that moves BEFORE digging started only turns the
		-- camera; once digging has started, moving it aims the next blocks and digging goes on
		-- (cancelling here made digging stop every ~3 blocks, as soon as the crosshair had to move)
		touchDragged = true
		touchAim = nil
	end
end)
UserInputService.TouchEnded:Connect(function(input: InputObject)
	if input == activeTouch then
		local tapped = os.clock() - touchHeldSince < 0.3
			and (Vector2.new(input.Position.X, input.Position.Y) - touchStart).Magnitude < 12
		local wasDigging = holding
		cancelDigInput()
		touchAim = nil
		if tapped and not touchDragged and not wasDigging and not touchAte then
			-- a short tap = a swing, like Minecraft's attack tap; also on a block too short to start digging
			attack()
		end
	end
end)
RunService.Heartbeat:Connect(function()
	-- a finger resting on a block starts digging and keeps digging the next blocks while held
	if
		activeTouch
		and touchAim
		and not touchDragged
		and not holding
		and os.clock() - touchHeldSince >= DIG_HOLD
	then
		local aim = touchAim
		touchAim = nil
		holding = true
		stopDig(true)
		if aim.part:IsDescendantOf(workspace) and not pending[aim.part] then
			startDig(aim)
		end
	end
	-- hold with food and nothing under the crosshair → eat once per hold
	if
		activeTouch
		and not digging
		and not touchAte
		and isFood()
		and os.clock() - touchHeldSince >= EAT_HOLD
	then
		touchAte = true
		Remotes.event("UseConsumable"):FireServer(profile and profile.selectedSlot or 1)
	end
end)
UserInputService.WindowFocusReleased:Connect(cancelDigInput)
player.CharacterRemoving:Connect(cancelDigInput)

-- Touch HUD: icon buttons only (no letters). Menus in a 2-column grid at the top-left so every
-- button fits a phone in landscape; "•••" next to the hotbar opens the inventory.
local touchMenus = Instance.new("Frame")
touchMenus.Name = "TouchMenus"
touchMenus.Position = UDim2.fromOffset(8, 64)
touchMenus.Size = UDim2.fromOffset(6 * 60, 2 * 60)
touchMenus.BackgroundTransparency = 1
touchMenus.Parent = gui
-- [владелец 21.10] the menu buttons were hit by accident while playing: one "Menu" button stays on
-- screen and unfolds the grid to its right (2 rows × 5, clear of the joystick); choosing an item or
-- touching the game world folds it back
local touchMenuGrid = Instance.new("Frame")
touchMenuGrid.Name = "Grid"
touchMenuGrid.Position = UDim2.fromOffset(60, 0)
touchMenuGrid.Size = UDim2.fromOffset(5 * 60, 2 * 60)
touchMenuGrid.BackgroundTransparency = 1
touchMenuGrid.Visible = false
touchMenuGrid.Parent = touchMenus
local menuKeys = {
	"locations",
	"jobs",
	"upgrade",
	"level",
	"achievements",
	"artifacts",
	"factions",
	"language_code",
}
local function touchIconButton(
	parent: Instance,
	iconId: string?,
	fallbackText: string,
	size: number,
	caption: string?
): TextButton
	local button = Ui.button(
		parent,
		if iconId then "" else fallbackText,
		UDim2.fromOffset(size, size),
		UDim2.new(),
		Ui.colors.buttonGrey
	)
	button.BackgroundTransparency = 0.35
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = button
	if iconId then
		local image = Instance.new("ImageLabel")
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.7, 0.7)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Image = iconId
		image.Parent = button
		if caption then
			image.Size = UDim2.fromScale(0.55, 0.55)
			image.Position = UDim2.fromScale(0.5, 0.4)
			local label = Ui.label(
				button,
				caption,
				UDim2.new(1, -2, 0, 12),
				UDim2.new(0, 1, 1, -13),
				9,
				Ui.colors.white
			)
			label.Name = "Caption"
			label.TextXAlignment = Enum.TextXAlignment.Center
			label.TextScaled = true
			label.TextStrokeTransparency = 0.5
		end
	end
	return button
end
local menuToggle =
	Ui.button(touchMenus, "", UDim2.fromOffset(56, 56), UDim2.new(), Ui.colors.buttonGrey)
menuToggle.Name = "Touch_menu"
menuToggle.BackgroundTransparency = 0.35
do
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, 8)
	round.Parent = menuToggle
	for bar = 0, 2 do -- the "hamburger": three bars drawn with frames (the font has no ☰)
		local line = Instance.new("Frame")
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0.5, 0, 0, 12 + bar * 8)
		line.Size = UDim2.fromOffset(26, 4)
		line.BackgroundColor3 = Ui.colors.white
		line.BorderSizePixel = 0
		line.Parent = menuToggle
	end
	local caption = Ui.label(
		menuToggle,
		T("touch_menu"),
		UDim2.new(1, -2, 0, 12),
		UDim2.new(0, 1, 1, -13),
		9,
		Ui.colors.white
	)
	caption.Name = "Caption"
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextScaled = true
	caption.TextStrokeTransparency = 0.5
	localizedLabels[caption] = "touch_menu"
end
local function setTouchMenuOpen(open: boolean)
	touchMenuGrid.Visible = open
	menuToggle.BackgroundColor3 = if open then Ui.colors.buttonBlue else Ui.colors.buttonGrey
end
menuToggle.Activated:Connect(function()
	setTouchMenuOpen(not touchMenuGrid.Visible)
end)
-- a touch on the game world (not on a button) folds the menu
UserInputService.InputBegan:Connect(function(input, processed)
	if
		input.UserInputType == Enum.UserInputType.Touch
		and not processed
		and touchMenuGrid.Visible
	then
		setTouchMenuOpen(false)
	end
end)
for i, kind in ipairs(menuKeys) do
	local icon = Config.icons.icons["menu_" .. kind]
	-- short captions: the full "Улучшить предмет" / "Повысить уровень" shrink to ~5 px in a 56 px button
	local captionKey = if kind == "level"
		then "touch_menu_level"
		elseif kind == "upgrade" then "touch_menu_upgrade"
		elseif kind == "factions" then "factions_title"
		else kind
	local button = touchIconButton(
		touchMenuGrid,
		icon,
		if kind == "language_code" then T(kind) else "",
		56,
		if kind == "language_code" then nil else T(captionKey)
	)
	button.Position = UDim2.fromOffset(((i - 1) % 5) * 60, math.floor((i - 1) / 5) * 60)
	button.Name = "Touch_" .. kind
	button.Activated:Connect(function()
		if kind == "language_code" then
			cycleLocale() -- the menu stays open to see the new language
		else
			setTouchMenuOpen(false)
			open(kind)
		end
	end)
	if kind == "language_code" then
		localizedButtons[button] = kind
	end
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = captionKey
	end
end
-- the 8th grid cell: first / third person view (was a separate HUD button)
do
	local button =
		touchIconButton(touchMenuGrid, Config.icons.icons["menu_camera"], "", 56, T("touch_camera"))
	button.Position = UDim2.fromOffset((#menuKeys % 5) * 60, math.floor(#menuKeys / 5) * 60)
	button.Name = "Touch_camera"
	button.Activated:Connect(function()
		setTouchMenuOpen(false)
		toggleFirstPerson()
	end)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = "touch_camera"
	end
end
-- the 9th grid cell: creative test mode, only for players CreativeService allows
do
	CreativeWindow.Listen()
	BossHud.Start(gui) -- boss name + health bar at the top, respawn boards over the arenas
	BossAnimator.Start() -- smooth boss joints from its Action attributes
	IndoorLighting.Start() -- brighter ambient light under the quarry cave roof
	local button =
		touchIconButton(touchMenuGrid, Config.iconFor("golden_apple"), "", 56, T("creative"))
	button.Position =
		UDim2.fromOffset(((#menuKeys + 1) % 5) * 60, math.floor((#menuKeys + 1) / 5) * 60)
	button.Name = "Touch_creative"
	local function show()
		button.Visible = player:GetAttribute("CreativeAllowed") == true
	end
	player:GetAttributeChangedSignal("CreativeAllowed"):Connect(show)
	show()
	button.Activated:Connect(function()
		setTouchMenuOpen(false)
		open("creative")
	end)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = "creative"
	end
end
local touchActions = Instance.new("Frame")
touchActions.Name = "TouchActions"
touchActions.Size = UDim2.fromScale(1, 1)
touchActions.BackgroundTransparency = 1
touchActions.Parent = gui
local function useConsumable()
	if profile then
		Remotes.event("UseConsumable"):FireServer(profile.selectedSlot)
	end
end
-- Throw the held item like Minecraft: Q one item, Ctrl+Q the whole stack; on a phone hold a hotbar
-- slot. Tools and armor stay (the server refuses them with a toast) [владелец 21.10]
local function throwSelected(wholeStack: boolean)
	if profile and not currentWindowKind then
		Remotes.event("DropItem"):FireServer(profile.selectedSlot, if wholeStack then nil else 1)
	end
end
-- "Съесть" appears above the jump button whenever food is in the selected slot (hold-to-eat stays too);
-- with soap / toilet paper / a sleeping bag it becomes "Использовать" with that item's icon [владелец 21.10]
local eatButton = touchIconButton(touchActions, Config.icons.icons["apple"], T("eat"), 60, T("eat"))
eatButton.Name = "TouchEat"
local eatCaption = eatButton:FindFirstChild("Caption")
if eatCaption and eatCaption:IsA("TextLabel") then
	localizedLabels[eatCaption] = "eat"
end
eatButton.Position = UDim2.new(1, -180, 1, -200)
eatButton.Visible = false
eatButton.Activated:Connect(useConsumable)
local inventoryButton = touchIconButton(touchActions, nil, "•••", 40)
inventoryButton.Name = "TouchInventory"
inventoryButton.TextSize = 20
inventoryButton.Activated:Connect(function()
	open("inventory")
end)

local statsScale = Instance.new("UIScale")
statsScale.Parent = stats
local hotbarScale = Instance.new("UIScale")
hotbarScale.Parent = hotbar
local effectsScale = Instance.new("UIScale")
effectsScale.Parent = effectsHud
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
	hints.Visible, languageButton.Visible = not mobile, not mobile
	artifactButton.Visible = not mobile
	statsScale.Scale = if mobile then 0.65 else 1
	stats.Position = if mobile then UDim2.new(1, -132, 0, 64) else UDim2.new(1, -200, 0.42, 0)
	-- effect icons sit left of the stats panel, top-aligned with it
	effectsHud.Position = if mobile then UDim2.new(1, -136, 0, 64) else UDim2.new(1, -206, 0.42, 0)
	effectsScale.Scale = if mobile then 0.75 else 1
	local size = if mobile and viewport.X <= 700 then 40 else SLOT
	local width = 9 * (size + 4) + 8
	hotbar.Size = UDim2.fromOffset(width, size + 12)
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -8)
	hotbarScale.Scale = if mobile then math.min(1, (viewport.X - 20) / width) else 1
	survivalScale.Scale = 1 -- the meters span the hotbar and share its scale
	inventoryButton.Position = UDim2.new(0.5, width / 2 * hotbarScale.Scale + 6, 1, -8 - size - 4)
	inventoryButton.AnchorPoint = Vector2.new(0, 0)
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
workspace:GetAttributeChangedSignal("ForceMobile"):Connect(updateLayout)
watchViewport()
RunService.RenderStepped:Connect(function()
	local controlsVisible = isMobile() and currentWindowKind == nil
	touchMenus.Visible, touchActions.Visible = controlsVisible, controlsVisible
	local food, needItem = isFood(), isNeedConsumable()
	eatButton.Visible = controlsVisible and (food or needItem)
	if eatButton.Visible then
		local stack = if profile then profile.inventory[profile.selectedSlot] else nil
		local key = if food then "eat" else "touch_use"
		local icon = if food
			then Config.icons.icons["apple"]
			else (stack and Config.iconFor(stack.id))
		local image = eatButton:FindFirstChildOfClass("ImageLabel")
		if image and icon and image.Image ~= icon then
			image.Image = icon
		end
		if eatCaption and eatCaption:IsA("TextLabel") and localizedLabels[eatCaption] ~= key then
			localizedLabels[eatCaption] = key
			eatCaption.Text = T(key)
		end
	end
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
	elseif k == Enum.KeyCode.G then
		open("factions") -- [клиент] /fraction
	elseif k == Enum.KeyCode.I then
		open("artifacts")
	elseif k == Enum.KeyCode.M then
		open("locations")
	elseif k == Enum.KeyCode.K and player:GetAttribute("CreativeAllowed") then
		open("creative") -- test mode (CreativeService)
	elseif k == Enum.KeyCode.V or k == Enum.KeyCode.F5 then
		toggleFirstPerson()
	elseif k == Enum.KeyCode.F then
		useConsumable()
	elseif k == Enum.KeyCode.Q then
		throwSelected(
			UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
				or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
		)
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
local THROW_HOLD = 0.6 -- s a finger rests on a hotbar slot before its stack is thrown
for i = 1, 9 do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromScale(1, 1)
	btn.BackgroundTransparency = 1
	btn.Text = ""
	btn.Parent = hotbarSlots[i]
	btn.Activated:Connect(function()
		selectSlot(i)
	end)
	-- phone: hold a hotbar slot to throw that stack (Bedrock)
	btn.InputBegan:Connect(function(input)
		if input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local start = input.Position
		task.delay(THROW_HOLD, function()
			if
				input.UserInputState ~= Enum.UserInputState.End
				and input.UserInputState ~= Enum.UserInputState.Cancel
				and (input.Position - start).Magnitude < 20 -- a finger sliding along the bar throws nothing
			then
				selectSlot(i)
				if profile and not currentWindowKind then
					Remotes.event("DropItem"):FireServer(i, nil)
				end
			end
		end)
	end)
end

-- Studio-only QA hook: execute_luau cannot press our hotkeys, so tests drive the client through this.
if RunService:IsStudio() then
	local hook = Instance.new("BindableFunction")
	hook.Name = "ClientDebug"
	hook.OnInvoke = function(action: string, arg: any): any
		if action == "toggleCamera" then
			toggleFirstPerson()
			return firstPerson
		elseif action == "open" then
			open(arg)
			return currentWindowKind
		elseif action == "close" then
			closeWindow()
			return true
		elseif action == "aim" then
			local aim = aimAt(if typeof(arg) == "Vector2" then arg else nil)
			return if aim then { part = aim.part, hit = aim.hit } else nil
		elseif action == "holdDig" then
			holding = arg == true
			if not holding then
				stopDig(true)
			end
			return holding
		elseif action == "state" then
			local aim = aimAt()
			return {
				digging = digging,
				target = digTarget,
				predicted = digPredicted,
				firstPerson = firstPerson,
				holding = holding,
				aimPart = if aim then aim.part else nil,
				expected = if aim then expectedTime(aim.part) else nil, -- nil = the client thinks it can't dig
				sleep = if profile then profile.needs.sleep else nil,
				pending = (function()
					local n = 0
					for _ in pairs(pending) do
						n += 1
					end
					return n
				end)(),
			}
		end
		return nil
	end
	hook.Parent = player.PlayerGui
end
print(string.format("[coco-prison] client ready (%s)", locale))
