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
local HttpService = game:GetService("HttpService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Ui)
local DragDrop = require(script.DragDrop)
local MenuWindow = require(script.MenuWindow)
local ExchangeWindow = require(script.ExchangeWindow)
local ShopWindow = require(script.ShopWindow)
local CreativeWindow = require(script.CreativeWindow)
local TopBoards = require(script.TopBoards)
local HudLayout = require(script.HudLayout)
local Combat = require(ReplicatedStorage.Shared.Combat)
require(script.CharacterAnimator).Start() -- keyframed swings on every character (ours and the relayed ones)
local CombatFeel = require(script.CombatFeel)
local HeldItem = require(script.HeldItem)
local BowController = require(script.BowController)
local Eating = require(script.Eating)
local LevelWindow = require(script.LevelWindow)
local BlockBreak = require(script.BlockBreak)
local EffectsHud = require(script.EffectsHud)
local SettingsWindow = require(script.SettingsWindow)
local Wire = require(Shared.Wire)
local BlockColors = require(Shared.BlockColors)
HeldItem.Start()
require(script.FirstPersonHand).Start()
require(script.Footsteps).Start()
require(script.CobwebStuck).Start()
require(script.AmbientMotion).Start()
require(Shared.Sfx).listen() -- sounds the server asks for (hurt, chests, eating, level up…)
require(script.ArmorVisual).Start()
BlockBreak.Start()
require(script.Nameplates).Start() -- «lvl N [кличка] Ник» over the other players
require(script.GroundItems).Start() -- items on the ground drawn like Minecraft (ItemDropService keeps the boxes)
require(script.Motion).Start() -- other players drawn from our own fast movement snapshots
require(script.Audio).Start() -- the master volume (SettingsWindow)

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
	crosshair.Visible = firstPerson or isMobile() or BowController.Drawing()
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
-- [владелец 22.10, скриншот; клиент prison.classic.scoreboard.*] «PRISON CLASSIC», then icon · label · value:
-- Уровень, Баланс, Блоки (чистые in brackets), a divider, Фракция, Крыс (чистые in brackets), У / С.
local SB_ROW = 20
local stats =
	Ui.panel(gui, UDim2.fromOffset(214, 30 + SB_ROW * 6 + 10), UDim2.new(1, -224, 0.40, 0))
local sbTitle = Ui.label(
	stats,
	"",
	UDim2.new(1, -12, 0, 22),
	UDim2.fromOffset(6, 3),
	14,
	Color3.fromRGB(90, 150, 255)
)
sbTitle.TextXAlignment = Enum.TextXAlignment.Center
local function sbRow(index: number, icon: string): (TextLabel, TextLabel)
	local y = 28 + (index - 1) * SB_ROW + (if index >= 4 then 8 else 0)
	local image = Instance.new("ImageLabel")
	image.Size = UDim2.fromOffset(14, 14)
	image.Position = UDim2.fromOffset(8, y + 3)
	image.BackgroundTransparency = 1
	image.Image = (Config.icons.icons :: any)[icon] or ""
	image.ResampleMode = Enum.ResamplerMode.Pixelated
	image.Parent = stats
	local label = Ui.label(
		stats,
		"",
		UDim2.fromOffset(100, SB_ROW),
		UDim2.fromOffset(28, y),
		14,
		Ui.colors.text
	)
	local value = Ui.rich(stats, "", UDim2.new(1, -36, 0, SB_ROW), UDim2.fromOffset(28, y), 14)
	value.TextXAlignment = Enum.TextXAlignment.Right
	return label, value
end
local statLevelLabel, statLevel = sbRow(1, "hud_level")
local statMoneyLabel, statMoney = sbRow(2, "hud_money")
local statBlocksLabel, statBlocks = sbRow(3, "hud_blocks")
local divider = Instance.new("Frame")
divider.Size = UDim2.new(1, -16, 0, 1)
divider.Position = UDim2.fromOffset(8, 28 + SB_ROW * 3 + 3)
divider.BackgroundColor3 = Ui.colors.border
divider.BorderSizePixel = 0
divider.Parent = stats
local statFactionLabel, statFaction = sbRow(4, "hud_faction")
local statRatsLabel, statRats = sbRow(5, "hud_rat")
local statKDLabel, statKD = sbRow(6, "hud_kd")
local function sbColor(text: string, color: Color3): string
	return string.format('<font color="%s">%s</font>', Ui.hex(color), text)
end

-- [владелец 21.10] no hygiene / sleep / toilet bars: NeedsService sends a message when a need runs out
-- and the effect icon (EffectsHud) shows while it lasts

-- Right of the hotbar (wrapped into lines; updateLayout places it): Roblox's chat window owns the bottom-left corner.
local hints = Ui.label(
	gui,
	T("keys_hint"),
	UDim2.new(0.5, -270, 0, 0),
	UDim2.new(0, 10, 1, -10),
	13,
	Ui.colors.muted
)
hints.AnchorPoint = Vector2.new(0, 1)
hints.AutomaticSize = Enum.AutomaticSize.Y
hints.TextXAlignment = Enum.TextXAlignment.Left
hints.TextYAlignment = Enum.TextYAlignment.Bottom
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
	-- the player may have turned the notifications off (SettingsWindow) [владелец 27.10]
	toast.Visible = not SettingsWindow.of(profile).hideToasts
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
hotbar.Name = "Hotbar"
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
survivalHud.Position = UDim2.fromOffset(6, -14) -- the experience bar runs under it
survivalHud.Size = UDim2.new(1, -12, 0, 24)
survivalHud.Parent = hotbar
local survivalScale = Instance.new("UIScale")
survivalScale.Parent = survivalHud
type SurvivalMeter = { group: Frame, fills: { Frame }, tooltip: TextLabel }
local function buildMeter(
	rightAligned: boolean,
	glyph: string,
	color: Color3,
	count: number?
): SurvivalMeter
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
		if glyph == "armor" then
			-- our own 9×9 pixel chestplate (2 px a pixel), light from the upper left
			local rows = {
				"KKK...KKK",
				"K12KKK21K",
				"K1122222K",
				"KK12222KK",
				".K12222K.",
				".K12222K.",
				".K22223K.",
				".K22333K.",
				".KKKKKKK.",
			}
			local shades = if filled
				then {
					K = Color3.fromRGB(30, 30, 30),
					["1"] = Color3.fromRGB(236, 236, 236),
					["2"] = Color3.fromRGB(190, 190, 196),
					["3"] = Color3.fromRGB(140, 140, 148),
				}
				else {
					K = Color3.fromRGB(30, 30, 30),
					["1"] = Color3.fromRGB(70, 70, 74),
					["2"] = Color3.fromRGB(58, 58, 62),
					["3"] = Color3.fromRGB(50, 50, 54),
				}
			for y, row in ipairs(rows) do
				local x = 1
				while x <= #row do
					local ch = string.sub(row, x, x)
					local run = 1
					while string.sub(row, x + run, x + run) == ch do
						run += 1
					end
					if ch ~= "." then
						local px = Instance.new("Frame")
						px.BorderSizePixel = 0
						px.BackgroundColor3 = shades[ch]
						px.Position = UDim2.fromOffset((x - 1) * 2, 3 + (y - 1) * 2)
						px.Size = UDim2.fromOffset(run * 2, 2)
						px.ZIndex = zIndex
						px.Parent = parent
					end
					x += run
				end
			end
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
	for i = 1, count or 10 do
		local cell = Instance.new("Frame")
		cell.Size = UDim2.fromOffset(18, 24)
		-- the food row fills from the right like Minecraft's: icon 1 is the rightmost; more than 10 icons go on in
		-- rows of 10 (the hearts: renderSurvival stacks the rows)
		cell.Position = UDim2.fromOffset((if rightAligned then 10 - i else (i - 1) % 10) * 19, 0)
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
	return { group = group, fills = fills, tooltip = tooltip }
end
-- every heart of the level (10 + 0.5 a level, 34.5 at 50): rows of 10 stacked upwards like Minecraft's extra hearts
local hearts = buildMeter(false, "♥", Color3.fromRGB(235, 55, 55), 40)
local drumsticks = buildMeter(true, "🍗", Color3.fromRGB(225, 150, 65))
-- Minecraft's armor row over the hearts [владелец 27.10: «иконки брони как в майне»], hidden without armor
local armorMeter = buildMeter(false, "armor", Color3.new())
armorMeter.group.Position = UDim2.fromOffset(0, -22)
-- Absorption's golden hearts (the golden apple) [ваниль]: a row of their own over the red ones, only the hearts there
-- are; the armor row moves up over it
-- [ваниль Gui.renderHearts, minecraft.wiki/w/Damage; владелец 27.10: «эффект получения урона как в майне»] after a
-- loss the heart row blinks for 1 s (white outlines every 3 ticks) and shows the health just lost as pale hearts; at
-- 2 hearts or less the hearts jitter every tick; with Regeneration a lifted heart runs along the row
local HEART_WHITE = Color3.fromRGB(255, 255, 255)
local heartsBlinkUntil, heartsLost = 0, 0
local lastHealthShown: number? = nil
local paleHearts: { Frame } = {}
for i, fill in ipairs(hearts.fills) do
	local pale = fill:Clone()
	pale.Name = "Lost"
	for _, d in ipairs(pale:GetDescendants()) do
		if d:IsA("TextLabel") then
			d.TextColor3 = Color3.fromRGB(255, 225, 225)
		end
	end
	pale.ZIndex = 2
	fill.ZIndex = 3
	pale.Visible = false
	pale.Parent = fill.Parent
	paleHearts[i] = pale
end
local goldenHearts = buildMeter(false, "♥", Color3.fromRGB(255, 205, 40))
goldenHearts.group.Position = UDim2.fromOffset(0, -22)
goldenHearts.group.Visible = false

-- Minecraft's experience bar between the meters and the hotbar [владелец 27.10]: the number is the player's level, the
-- green fill how close the next level is (the blocks since the last level and the money it costs, the lower of the two)
local XP_GREEN = Color3.fromRGB(128, 255, 32)
local xpBar = Instance.new("Frame")
xpBar.Name = "ExperienceBar"
xpBar.AnchorPoint = Vector2.new(0, 1)
xpBar.Position = UDim2.fromOffset(6, -4)
xpBar.Size = UDim2.new(1, -12, 0, 7)
xpBar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
xpBar.BorderSizePixel = 0
xpBar.Parent = hotbar
local xpTrack = Instance.new("Frame")
xpTrack.Position = UDim2.fromOffset(1, 1)
xpTrack.Size = UDim2.new(1, -2, 1, -2)
xpTrack.BackgroundColor3 = Color3.fromRGB(46, 58, 30)
xpTrack.BorderSizePixel = 0
xpTrack.Parent = xpBar
local xpFill = Instance.new("Frame")
xpFill.Size = UDim2.fromScale(0, 1)
xpFill.BackgroundColor3 = XP_GREEN
xpFill.BorderSizePixel = 0
xpFill.Parent = xpTrack
local xpShine = Instance.new("Frame") -- the lighter top pixel row of the fill
xpShine.Size = UDim2.new(1, 0, 0, 1)
xpShine.BackgroundColor3 = Color3.fromRGB(200, 255, 140)
xpShine.BorderSizePixel = 0
xpShine.Parent = xpFill
local xpLevel =
	Ui.label(hotbar, "", UDim2.fromOffset(60, 18), UDim2.new(0.5, 0, 0, -8), 18, XP_GREEN)
xpLevel.AnchorPoint = Vector2.new(0.5, 1)
xpLevel.TextXAlignment = Enum.TextXAlignment.Center
xpLevel.Font = Enum.Font.SourceSansBold
xpLevel.TextStrokeTransparency = 0
xpLevel.TextStrokeColor3 = Color3.new(0, 0, 0)
xpLevel.ZIndex = 3

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
-- [владелец 28.10: «комбо бар падает на бар с сердечками. Сделай его выше над голодом»] it sits over the food row
-- (the right half), clear of the heart rows that grow upwards on the left; inside the food row's frame, so it shares
-- its place and its touch scale
local combo = hudLine(0, 14, Ui.colors.muted)
combo.Size = UDim2.fromOffset(240, 18)
combo.Position = UDim2.new(0.5, 0, 0, -12)
combo.Parent = drumsticks.group
local comboMultiplier: number? = nil
local comboBlocks = 0
local comboAt = 0 -- os.clock() of the last dug block
-- [владелец 21.10] combo timer: a bar under the combo text, full after every block, draining over the
-- idle time (rules.combo.breakAfterIdleSeconds = 30 s) — empty means the combo resets
local comboBar = Ui.inset(drumsticks.group, UDim2.fromOffset(180, 5), UDim2.new(0.5, 0, 0, -5))
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
	local points = math.clamp(value, 0, #meter.fills * 2)
	local fullPoints = math.floor(points / 2) * 2
	local halves = fullPoints + (if points > fullPoints then 1 else 0)
	for i, fill in ipairs(meter.fills) do
		fill.Size = UDim2.fromScale(math.clamp(halves - (i - 1) * 2, 0, 2) / 2, 1)
	end
end
-- 0 … 1: how close the next level is — the blocks since the last level and the money it costs, the lower of the two
local function levelProgress(): number
	if not profile then
		return 0
	end
	local nextRule = Config.levelRule(profile.level + 1)
	if not nextRule then
		return 1
	end
	local lastRule = Config.levelRule(profile.level)
	local from = if lastRule then lastRule.blocks else 0
	local blocks = (profile.blocksTotal - from) / math.max(1, nextRule.blocks - from)
	local money = profile.coins / math.max(1, nextRule.money)
	return math.clamp(math.min(blocks, money), 0, 1)
end
local function renderSurvival()
	local humanoid = trackedHumanoid
	local health = if humanoid then humanoid.Health else 0
	local maxHealth = if humanoid then humanoid.MaxHealth else 20
	-- [ваниль Gui.renderHearts] one heart per 2 HP of the max, rows of 10 going up; with many rows they close in
	-- (row step max(10 − (rows − 2), 3) of the heart's 10 px)
	local shownHearts = math.clamp(math.ceil(maxHealth / 2), 1, #hearts.fills)
	local heartRows = math.ceil(shownHearts / 10)
	local rowStep = 24 * math.max(10 - (heartRows - 2), 3) / 10
	if heartRows <= 1 then
		rowStep = 24
	end
	for i, fill in ipairs(hearts.fills) do
		local cell = fill.Parent
		if cell and cell:IsA("Frame") then
			cell.Visible = i <= shownHearts
			cell:SetAttribute("BaseY", -math.floor((i - 1) / 10) * rowStep)
		end
	end
	local heartsTop = (heartRows - 1) * rowStep
	fillMeter(hearts, health)
	hearts.tooltip.Text = T("health_tooltip", health, maxHealth)
	if humanoid and lastHealthShown and health < lastHealthShown - 0.01 then
		local now = os.clock()
		heartsLost = math.max(lastHealthShown, if now < heartsBlinkUntil then heartsLost else 0)
		heartsBlinkUntil = now + 1
		local halves = math.ceil(math.clamp(heartsLost, 0, #paleHearts * 2))
		for i, pale in ipairs(paleHearts) do
			pale.Size = UDim2.fromScale(math.clamp(halves - (i - 1) * 2, 0, 2) / 2, 1)
		end
	end
	lastHealthShown = if humanoid then health else nil
	local character = humanoid and humanoid.Parent
	local golden = character and character:GetAttribute("AbsorptionHealth")
	local absorbed = if typeof(golden) == "number" then math.clamp(golden, 0, 20) else 0
	goldenHearts.group.Visible = absorbed > 0
	fillMeter(goldenHearts, absorbed)
	for i, fill in ipairs(goldenHearts.fills) do
		local cell = fill.Parent
		if cell and cell:IsA("Frame") then
			cell.Visible = i <= math.ceil(absorbed / 2)
		end
	end
	goldenHearts.group.Position = UDim2.fromOffset(0, -heartsTop - 22)
	armorMeter.group.Position = UDim2.fromOffset(0, -heartsTop - (if absorbed > 0 then 44 else 22))
	local hunger = if profile then profile.hunger else Config.rules.survival.hunger.max
	fillMeter(drumsticks, hunger / Config.rules.survival.hunger.max * 20)
	drumsticks.tooltip.Text = T("hunger_tooltip", hunger, Config.rules.survival.hunger.max)
	require(script.PrisPerks).appleSkin(drumsticks.group, profile, health, maxHealth) -- PRIS+ AppleSkin (этап 8)
	local points = Combat.armorPoints(if profile then profile.armor else nil)
	armorMeter.group.Visible = points > 0
	fillMeter(armorMeter, points)
	armorMeter.tooltip.Text = T("armor_tooltip", points)
	xpLevel.Text = tostring(if profile then profile.level else 1)
	xpFill.Size = UDim2.fromScale(levelProgress(), 1)
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
		character:GetAttributeChangedSignal("AbsorptionHealth"):Connect(renderSurvival)
	)
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
local heartsTick = -1
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	local tick = math.floor(now / 0.05)
	if tick == heartsTick then
		return
	end
	heartsTick = tick
	local humanoid = trackedHumanoid
	local health = if humanoid then humanoid.Health else 0
	local character = humanoid and humanoid.Parent
	local regen = character ~= nil and typeof(character:GetAttribute("Regeneration")) == "number"
	local blinking = now < heartsBlinkUntil and math.floor((heartsBlinkUntil - now) / 0.15) % 2 == 1
	for i, fill in ipairs(hearts.fills) do
		local cell = fill.Parent
		if not cell or not cell:IsA("Frame") then
			continue
		end
		local outline = cell:FindFirstChildOfClass("TextLabel")
		if outline then
			outline.TextColor3 = if blinking then HEART_WHITE else Ui.colors.border
		end
		paleHearts[i].Visible = blinking
		if not cell.Visible then
			continue
		end
		local base = cell:GetAttribute("BaseY")
		local y = if typeof(base) == "number" then base else 0
		if health > 0 and health <= 4 then
			y += math.random(0, 1) * 2
		end
		if
			regen
			and i - 1 == tick % math.ceil((if humanoid then humanoid.MaxHealth else 20) + 5)
		then
			y -= 2
		end
		cell.Position = UDim2.fromOffset(cell.Position.X.Offset, y)
	end
end)
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
-- our TAB list (PlayerListWindow, этап 9) replaces Roblox's; block / report / friends stay in Roblox's Esc menu
StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
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
	local tint = Color3.new(1, 1, 1)
	if stack and not icon then
		icon, tint = BlockColors.icon(stack.id)
	end
	name.Text, count.Text = n, c
	image.Image = icon or ""
	image.ImageColor3 = tint
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
local heldName = hudLine(-92, 17, Ui.colors.white)
heldName.Visible = false
local heldNameToken = 0

-- [владелец 21.10] while a need's effect lasts, its hint (where to go / what to use) stays on screen
local effectHint = hudLine(-118, 14, Color3.fromRGB(255, 225, 120))
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
	local first = require(Shared.ItemInfo).lines(stack, locale)[1]
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
local refreshLevel: (() -> ())? = nil
local refreshInventory: (() -> ())? = nil
local refreshChest: (() -> ())? = nil
local refreshMenu: ((Types.Profile?) -> ())? = nil
local openedCaseId = "ordinaryCase"
local function closeWindow()
	if currentWindowKind == "case" then
		Remotes.event("CaseClose"):FireServer(openedCaseId)
	end
	refreshLocations = nil
	refreshLevel = nil
	refreshMenu = nil
	refreshInventory, refreshChest = nil, nil
	if openWindow then
		openWindow:Destroy()
		openWindow = nil
	end
	currentWindowKind = nil
	UserInputService.ModalEnabled = false
end

-- Inventory [E] in our own dark style [владелец 27.10: the vanilla grey copy «выглядит не профессионально … поищи
-- менюшки в интернете»; the layout of RPG inventory screens — equipment, the character, stats; the bag below]: cards
-- for the four armour slots, the player full height (turning slowly) and the stats the armour gives, then the 9×3 bag
-- and the hotbar row with its keys. Armour is equipped by dragging a piece onto its slot (or a double tap /
-- shift-click), taken off by dragging it back; profile updates repaint slots in place.
local INV_SLOT = 44
local INV_GAP = 4
local function buildInventory(): Frame
	local gridWidth = 9 * INV_SLOT + 8 * INV_GAP
	local pad = 16
	local innerWidth = gridWidth + 2 * pad
	local win, content =
		createWindow(gui, T("inventory"), UDim2.fromOffset(innerWidth + 12, 512), closeWindow)
	win.BackgroundTransparency = 0 -- the HUD under it never shows through the slots
	local views: { { index: number, name: TextLabel, count: TextLabel, image: ImageLabel } } = {}
	local armorViews: { { part: string, name: TextLabel, count: TextLabel, image: ImageLabel } } =
		{}
	local ARMOR_PARTS = { "helmet", "chestplate", "leggings", "boots" }
	local function renderArmor(part: string, name: TextLabel, count: TextLabel, image: ImageLabel)
		local armor = if profile then profile.armor[part] else nil
		renderSlot(name, count, image, armor or { id = part, level = 1, count = 1 })
		name.Visible = false
		-- an empty slot shows the piece's outline faintly
		image.ImageColor3 = if armor then Color3.new(1, 1, 1) else Color3.fromRGB(120, 124, 140)
		image.ImageTransparency = if armor then 0 else 0.7
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
	local function slotAt(index: number, x: number, y: number): Frame
		local f, name, count, image = Ui.invSlot(content, INV_SLOT)
		f.Position = UDim2.fromOffset(x, y)
		renderSlot(name, count, image, if profile then profile.inventory[index] else nil)
		table.insert(views, { index = index, name = name, count = count, image = image })
		drag.Bind(f, { container = "inv", index = index })
		return f
	end
	local function caption(text: string, x: number, y: number)
		local l = Ui.label(content, text, UDim2.fromOffset(300, 16), UDim2.fromOffset(x, y), 12)
		l.TextColor3 = Ui.colors.muted
	end

	-- top: equipment | character | stats, as tall as the four armour slots
	local topHeight = 4 * INV_SLOT + 3 * 8 + 2 * 10
	local equipment =
		Ui.card(content, UDim2.fromOffset(INV_SLOT + 20, topHeight), UDim2.fromOffset(pad, 4))
	for i, part in ipairs(ARMOR_PARTS) do
		local f, name, count, image = Ui.invSlot(equipment, INV_SLOT)
		f.Position = UDim2.fromOffset(10, 10 + (i - 1) * (INV_SLOT + 8))
		renderArmor(part, name, count, image)
		table.insert(armorViews, { part = part, name = name, count = count, image = image })
		drag.Bind(f, { container = "armor", index = i })
	end
	local statsWidth = 150
	local previewX = pad + INV_SLOT + 20 + 8
	local previewWidth = innerWidth - pad - statsWidth - 8 - previewX
	local stage =
		Ui.card(content, UDim2.fromOffset(previewWidth, topHeight), UDim2.fromOffset(previewX, 4))
	stage.ClipsDescendants = true
	stage.BackgroundColor3 = Color3.fromRGB(44, 52, 74)
	local backdrop = Instance.new("UIGradient") -- a soft spotlight from above
	backdrop.Rotation = 90
	backdrop.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(110, 110, 130))
	backdrop.Parent = stage
	local floor = Instance.new("Frame") -- the shadow the player stands on
	floor.AnchorPoint = Vector2.new(0.5, 0.5)
	floor.Position = UDim2.new(0.5, 0, 1, -16)
	floor.Size = UDim2.fromOffset(84, 14)
	floor.BackgroundColor3 = Color3.new(0, 0, 0)
	floor.BackgroundTransparency = 0.6
	floor.BorderSizePixel = 0
	floor.Parent = stage
	local floorCorner = Instance.new("UICorner")
	floorCorner.CornerRadius = UDim.new(0.5, 0)
	floorCorner.Parent = floor
	local preview = Instance.new("ViewportFrame")
	preview.Size = UDim2.fromScale(1, 1)
	preview.BackgroundTransparency = 1
	preview.Ambient = Color3.fromRGB(190, 190, 200)
	preview.LightColor = Color3.fromRGB(255, 250, 240)
	preview.LightDirection = Vector3.new(-0.5, -1, -0.6)
	preview.Parent = stage
	local previewCamera = Instance.new("Camera")
	previewCamera.Parent = preview
	preview.CurrentCamera = previewCamera
	local world = Instance.new("WorldModel")
	world.Parent = preview
	local clone: Model? = nil
	local function renderPreview()
		world:ClearAllChildren()
		clone = nil
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not character or not root or not root:IsA("BasePart") then
			return
		end
		character.Archivable = true
		local copy = character:Clone()
		character.Archivable = false
		for _, d in ipairs(copy:GetDescendants()) do
			if
				d:IsA("Script")
				or d:IsA("LocalScript")
				or d:IsA("Sound")
				or d:IsA("BillboardGui")
			then
				d:Destroy()
			end
		end
		copy:PivotTo(CFrame.new(0, 0, 0))
		copy.Parent = world
		clone = copy
		-- full height: the camera backs off until the whole body (head to feet) fits with a small margin
		local box, size = copy:GetBoundingBox()
		local fov = 30
		local half = math.tan(math.rad(fov) / 2)
		local fit = math.max(size.Y / 2, size.X / 2 * topHeight / previewWidth) * 1.1
		local centre = box.Position
		previewCamera.FieldOfView = fov
		previewCamera.CFrame = CFrame.lookAt(
			centre + Vector3.new(0, size.Y * 0.06, -(fit / half + size.Z / 2)),
			centre
		)
	end
	renderPreview()
	-- the player turns a little from side to side, like on a display stand
	local sway = RunService.RenderStepped:Connect(function()
		if clone and clone.Parent then
			clone:PivotTo(CFrame.Angles(0, math.rad(25) * math.sin(os.clock() * 0.8), 0))
		end
	end)
	win.Destroying:Once(function()
		sway:Disconnect()
	end)

	local stats = Ui.card(
		content,
		UDim2.fromOffset(statsWidth, topHeight),
		UDim2.fromOffset(innerWidth - pad - statsWidth, 4)
	)
	local nameLabel =
		Ui.label(stats, player.DisplayName, UDim2.new(1, -20, 0, 20), UDim2.fromOffset(10, 8), 15)
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local function statLine(y: number, color: Color3): (TextLabel, TextLabel)
		local key = Ui.label(
			stats,
			"",
			UDim2.new(1, -20, 0, 14),
			UDim2.fromOffset(10, y),
			12,
			Ui.colors.muted
		)
		local value =
			Ui.label(stats, "", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, y + 14), 15, color)
		value.Font = Enum.Font.SourceSansBold
		return key, value
	end
	local levelKey, levelValue = statLine(36, Color3.fromRGB(128, 255, 32))
	local levelBar = Instance.new("Frame")
	levelBar.Position = UDim2.fromOffset(10, 70)
	levelBar.Size = UDim2.new(1, -20, 0, 5)
	levelBar.BackgroundColor3 = Color3.fromRGB(46, 58, 30)
	levelBar.BorderSizePixel = 0
	levelBar.Parent = stats
	local levelFill = Instance.new("Frame")
	levelFill.BackgroundColor3 = Color3.fromRGB(128, 255, 32)
	levelFill.BorderSizePixel = 0
	levelFill.Size = UDim2.fromScale(0, 1)
	levelFill.Parent = levelBar
	local healthKey, healthValue = statLine(84, Color3.fromRGB(255, 95, 95))
	local armorKey, armorValue = statLine(122, Color3.fromRGB(205, 215, 235))
	local protectKey, protectValue = statLine(160, Color3.fromRGB(120, 200, 255))
	local function renderStats()
		levelKey.Text = T("level")
		healthKey.Text = T("inv_health")
		armorKey.Text = T("inv_armor")
		protectKey.Text = T("inv_protection")
		levelValue.Text = tostring(if profile then profile.level else 1)
		levelFill.Size = UDim2.fromScale(levelProgress(), 1)
		local humanoid = trackedHumanoid
		healthValue.Text = if humanoid
			then string.format("%d / %d", math.ceil(humanoid.Health), humanoid.MaxHealth)
			else "—"
		local armor = if profile then profile.armor else nil
		armorValue.Text = string.format("%d / 20", Combat.armorPoints(armor))
		-- how much of a 10-damage blow gets through the armour
		protectValue.Text = string.format(
			"−%d%%",
			math.floor((1 - Combat.armorReduce(10, armor) / 10) * 100 + 0.5)
		)
	end
	renderStats()

	-- the bag and the hotbar
	local bagY = 4 + topHeight + 14
	caption(T("inv_backpack"), pad, bagY)
	for r = 0, 2 do
		for col = 0, 8 do
			slotAt(
				10 + r * 9 + col,
				pad + col * (INV_SLOT + INV_GAP),
				bagY + 18 + r * (INV_SLOT + INV_GAP)
			)
		end
	end
	local barY = bagY + 18 + 3 * (INV_SLOT + INV_GAP) + 10
	caption(T("inv_hotbar"), pad, barY)
	for col = 0, 8 do
		local f = slotAt(col + 1, pad + col * (INV_SLOT + INV_GAP), barY + 18)
		local key =
			Ui.label(f, tostring(col + 1), UDim2.fromOffset(12, 12), UDim2.fromOffset(4, 2), 10)
		key.TextColor3 = Ui.colors.muted
		key.ZIndex = 5
	end
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
		renderStats()
	end
	return win
end

-- Level [U]: LevelWindow, updated in place while it is open
local function buildLevel(): Frame
	local win, refresh = LevelWindow.build(gui, locale, function()
		return profile
	end, createWindow, closeWindow)
	refreshLevel = refresh
	return win
end

-- Jobs [O]: JobsWindow, updated in place while it is open
local function buildJobs(): Frame
	local win, refresh =
		require(script.JobsWindow).build(gui, profile, locale, closeWindow, createWindow)
	refreshMenu = refresh
	return win
end

local function buildCase(): Frame
	local win, refresh = require(script.ChestWindow).build(gui, openedCaseId, function()
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
	gang_base = true,
	ghetto = true,
	warzone = true,
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
		and require(script.GangNpcWindow).locationRefusal(location) == nil -- База банды / Гетто
end

-- [владелец 22.10] a red «PVP» plate in the corner of the preview of every PvP location
local function pvpBadge(preview: GuiObject, location: Config.Location)
	if location.shot then
		-- a yellow «ШОТ» plate bottom-left: every block breaks in one hit [вики HANDBOOK-WIKI]
		local shot = Instance.new("TextLabel")
		shot.Name = "ShotBadge"
		shot.AnchorPoint = Vector2.new(0, 1)
		shot.Position = UDim2.new(0, 6, 1, -6)
		shot.Size = UDim2.fromOffset(52, 22)
		shot.BackgroundColor3 = Color3.fromRGB(230, 180, 30)
		shot.BorderSizePixel = 0
		shot.Font = Enum.Font.GothamBold
		shot.Text = T("shot_badge")
		shot.TextColor3 = Color3.fromRGB(30, 24, 8)
		shot.TextSize = 13
		shot.ZIndex = preview.ZIndex + 2
		shot.Parent = preview
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0, 4)
		round.Parent = shot
	end
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

-- A small card while the teleport channel runs: the destination's name, the countdown and the PVP plate.
-- [владелец 22.10: «фото убрать, а то это мешает видимости игроку»] no picture, kept high above the middle.
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
		local frame = Ui.panel(gui, UDim2.fromOffset(300, 62), UDim2.fromScale(0.5, 0.16))
		frame.Name = "TeleportPreview"
		frame.AnchorPoint = Vector2.new(0.5, 0.5)
		frame.ZIndex = 8
		local name = Ui.label(
			frame,
			Strings.locationName(location.name, locale),
			UDim2.new(1, -70, 0, 24),
			UDim2.fromOffset(10, 6),
			18,
			Ui.colors.header
		)
		name.TextXAlignment = Enum.TextXAlignment.Left
		local countdown = Ui.label(
			frame,
			"",
			UDim2.new(1, -20, 0, 22),
			UDim2.fromOffset(10, 32),
			14,
			Ui.colors.text
		)
		countdown.TextXAlignment = Enum.TextXAlignment.Left
		pvpBadge(frame, location)
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
			elseif require(script.GangNpcWindow).locationRefusal(selected) then
				-- [клиент location.list.non_access.ghetto]
				refusal.Text = T(require(script.GangNpcWindow).locationRefusal(selected) :: string)
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
				-- the block's picture before its name, as in the inventory [владелец 28.10: «добавь значки этих
				-- блоков»]: the uploaded icon, else the block-colour tile
				local picture = Instance.new("ImageLabel")
				picture.Size = UDim2.fromOffset(24, 24)
				picture.Position = UDim2.new(0, 5, 0.5, -12)
				picture.BorderSizePixel = 0
				picture.ScaleType = Enum.ScaleType.Fit
				picture.ResampleMode = Enum.ResamplerMode.Pixelated
				local icon, tint = BlockColors.icon(id)
				local tile = if icon then nil else BlockColors.of(id)
				picture.Image = icon or ""
				picture.ImageColor3 = tint
				picture.BackgroundColor3 = tile or Color3.new()
				picture.BackgroundTransparency = if tile then 0 else 1
				picture.Parent = chip
				local blockName = Ui.label(
					chip,
					Strings.itemName(id, nil, locale),
					UDim2.new(1, -40, 1, 0),
					UDim2.fromOffset(34, 0),
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
		local win, refresh =
			require(script.SellWindow).build(gui, profile, locale, closeWindow, createWindow)
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
		local win, refresh =
			require(script.TrainerWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	skills = function() -- «Древо навыков» [T]
		local win, refresh =
			require(script.SkillWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	potions = function() -- «Зельеварка» [Z]
		local win, refresh =
			require(script.PotionWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	upgrade = function()
		local win, refresh =
			require(script.UpgradeWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	level = buildLevel,
	jobs = buildJobs,
	donate = function()
		local win, refresh =
			require(script.DonateWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	achievements = function()
		local win, refresh = require(script.AchievementsWindow).build(
			gui,
			profile,
			locale,
			closeWindow,
			createWindow
		)
		refreshMenu = refresh
		return win
	end,
	boosters = function()
		local win, refresh =
			require(script.BoosterWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	auction = function()
		local win, refresh =
			require(script.AuctionWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	creative = function()
		local win, refresh = CreativeWindow.build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	artifacts = function()
		local win, refresh =
			require(script.ArtifactWindow).build(gui, profile, locale, closeWindow, createWindow)
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
	-- «Подробнее» at a case: what it can give, read only [владелец 28.10]
	casePreview = function()
		return require(script.CasePreviewWindow).build(gui, locale, closeWindow, createWindow)
	end,
	-- a book / powder / dispeller in the hand → «Использовать»: pick the item [владелец 28.10]
	book = function()
		local win, refresh =
			require(script.BookWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	locations = buildLocations,
	factions = function()
		local win, refresh =
			require(script.FactionWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	gangs = function() -- «Банда» [R] (GangWindow, GangService)
		local win, refresh =
			require(script.GangWindow).build(gui, profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	-- База банды: Библиотекарь / Кузнец (GangNpcWindow, GangBaseService)
	gangLibrary = function()
		local win, refresh = require(script.GangNpcWindow).build(
			gui,
			"library",
			profile,
			locale,
			closeWindow,
			createWindow
		)
		refreshMenu = refresh
		return win
	end,
	gangForge = function()
		local win, refresh = require(script.GangNpcWindow).build(
			gui,
			"forge",
			profile,
			locale,
			closeWindow,
			createWindow
		)
		refreshMenu = refresh
		return win
	end,
	-- Гетто: Торговец and Чёрный рынок in the exchanger window (GhettoService)
	ghettoTrader = function()
		local win, refresh =
			ExchangeWindow.build(gui, "trader", profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
	blackMarket = function()
		local win, refresh =
			ExchangeWindow.build(gui, "black", profile, locale, closeWindow, createWindow)
		refreshMenu = refresh
		return win
	end,
}
require(script.GangNpcWindow).listen() -- the treasure chest capture broken by damage lets the prompt go
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
-- «Урна» (/rubbish, этап 3): what lies in the bin is destroyed when the window goes (RubbishWindow)
windowBuilders.rubbish = function()
	local win, refresh =
		require(script.RubbishWindow).build(gui, profile, locale, closeWindow, createWindow)
	refreshMenu = refresh
	return win
end
-- «Ежедневные награды» (/daily, the NPC on the spawn, the menu tile; этап 7): DailyWindow, DailyService decides
windowBuilders.daily = function()
	local win, refresh =
		require(script.DailyWindow).build(gui, profile, locale, closeWindow, createWindow)
	refreshMenu = refresh
	return win
end
-- «PRIS+» (/pp, /mining, the menu tile; этап 8): PrisWindow; the switches go through SetSetting, PrisService decides
windowBuilders.pris = function()
	local win, refresh =
		require(script.PrisWindow).build(gui, profile, locale, closeWindow, createWindow, open)
	refreshMenu = refresh
	return win
end
require(script.EnchantFx).start(function()
	return profile
end) -- PRIS+ particles of Вихрь / Ярость / Бульдозер (этап 8)
-- «Ваши клички» (/names, /titles, /nickname, the menu tile; этап 9): NicknameWindow, NicknameService decides
windowBuilders.names = function()
	local win, refresh =
		require(script.NicknameWindow).build(gui, profile, locale, closeWindow, createWindow)
	refreshMenu = refresh
	return win
end
-- the TAB list with the player card (Tab, the menu tile, the phone grid; этап 9)
windowBuilders.players = function()
	local win, refresh =
		require(script.PlayerListWindow).build(gui, profile, locale, closeWindow, createWindow)
	refreshMenu = refresh
	return win
end
-- the chat (этап 3): Roblox's own chat window set up for our HUD, the system lines, «[Совет]», /hide, the client part of
-- the commands (ChatWindow); the hotbar it keeps clear of is handed over below the touch controls
require(script.ChatWindow).start({
	profile = function()
		return profile
	end,
	locale = function()
		return locale
	end,
	toast = showToast,
})
require(script.CasePreviewWindow).profile = function() -- the nickname case shows the chances without owned names
	return profile
end
require(script.CasePreviewWindow).listen(function()
	if currentWindowKind == "casePreview" then
		closeWindow()
		currentWindowKind = nil
	end
	open("casePreview")
end)
-- the Ancient case roulette [владелец 28.10]: books spin over the case, the window waits hidden (never closed: that
-- empties the case)
Remotes.event("AncientRoll").OnClientEvent
	:Connect(function(part: any, bookId: any, level: any, rarity: any)
		require(script.AncientRoulette).play(
			part,
			bookId,
			level,
			rarity,
			locale,
			function(visible: boolean)
				if openWindow and currentWindowKind == "case" then
					openWindow.Visible = visible
				end
			end
		)
	end)
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
	if not force and currentWindowKind == "level" and refreshLevel then
		refreshLevel()
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
-- «Меню [X]» next to it: every window in one place [владелец 27.10]
local menuButton = Ui.button(
	gui,
	T("menu_hotkey"),
	UDim2.fromOffset(130, 44),
	UDim2.fromOffset(204, 64),
	Ui.colors.buttonBlue
)
menuButton.Name = "MenuButton"
localizedButtons[menuButton] = "menu_hotkey"
menuButton.Activated:Connect(function()
	open("menu")
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
-- the movable HUD (HudLayout): set up with the touch controls below
local relayoutHud: () -> () = function() end
local openHudEditor: () -> () = function() end
-- «Меню» [X]: a tile for every window (MenuWindow)
windowBuilders.menu = function()
	return MenuWindow.build(gui, locale, closeWindow, createWindow, function(kind: string)
		if kind == "layout" then
			closeWindow()
			currentWindowKind = nil
			openHudEditor()
		elseif kind == "invite" then -- Roblox's invite window, not one of ours (Invite.luau)
			require(script.Invite).prompt(function()
				showToast(T("invite_unavailable"))
			end)
		else
			open(kind)
		end
	end)
end
-- «Настройки» [P]: language, volume, notifications, booster bar, the layout editor [владелец 27.10]
windowBuilders.settings = function()
	return SettingsWindow.build(gui, locale, profile, closeWindow, createWindow, function()
		closeWindow()
		currentWindowKind = nil
		openHudEditor()
	end, {
		firstPerson = function()
			return firstPerson
		end,
		toggle = toggleFirstPerson,
	})
end
local shownHudLayout = ""
local function render(p: Types.Profile)
	local nextLocale = p.locale or Config.defaultLocale
	local rebuild = locale ~= nextLocale or (profile ~= nil and profile.location ~= p.location)
	local previousLevel = if profile then profile.level else nil
	profile = p
	if previousLevel and p.level > previousLevel then
		LevelWindow.celebrate(gui, nextLocale, p.level, previousLevel)
	end
	locale = nextLocale
	if rebuild then
		localizeWorld()
		TopBoards.Refresh()
	end
	languageButton.Text = T("language_code")
	renderCameraButton()
	require(script.PrisPerks).sync(p) -- PRIS+ night (этап 8)
	do -- the settings window's values [владелец 27.10]
		local settings = SettingsWindow.of(p)
		require(script.Audio).set(settings.volume :: number, settings.muted == true)
		if settings.hideToasts then
			toast.Visible = false
		end
	end
	local hudJson = HttpService:JSONEncode(p.hudLayout or {})
	if hudJson ~= shownHudLayout then
		shownHudLayout = hudJson
		relayoutHud()
	end
	for button, key in pairs(localizedButtons) do
		button.Text = T(key)
	end
	for label, key in pairs(localizedLabels) do
		label.Text = T(key)
	end
	hints.Text = T("keys_hint")
	renderTeleportCountdown()
	renderCombo()
	sbTitle.Text = T("sb_title")
	statLevelLabel.Text = T("level")
	statMoneyLabel.Text = T("coins")
	statBlocksLabel.Text = T("blocks")
	statFactionLabel.Text = T("sb_faction")
	statRatsLabel.Text = T("sb_rats")
	statKDLabel.Text = T("sb_kd")
	statLevel.Text = sbColor(tostring(p.level), Ui.colors.yellow)
	-- balance like the original: 8,507; below 1 000 the exact "0.500" format [владелец 22.10]
	statMoney.Text = sbColor(
		if p.coins >= 1000 * Config.moneyScale
			then Strings.grouped(math.floor(p.coins / Config.moneyScale), 0)
			else Strings.money(p.coins),
		Ui.colors.green
	)
	statBlocks.Text = sbColor(Strings.big(p.blocksTotal), Ui.colors.orange)
		.. " "
		.. sbColor("(" .. Strings.big(p.stats.blocksClean or 0) .. ")", Ui.colors.gray)
	statFaction.Text = sbColor(
		if Config.faction(p.faction) then T("faction_" .. p.faction) else T("faction_none"),
		Ui.colors.gray
	)
	statRats.Text = sbColor(Strings.big(p.stats.ratsTotal or p.stats.rats or 0), Ui.colors.orange)
		.. " "
		.. sbColor("(" .. Strings.big(p.stats.rats or 0) .. ")", Ui.colors.gray)
	statKD.Text = sbColor(tostring(p.stats.kills or 0), Ui.colors.green)
		.. sbColor(" / ", Ui.colors.text)
		.. sbColor(tostring(p.stats.deaths or 0), Ui.colors.red)
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
-- paid auction announcements: the banner and the offer after listing; «Открыть» = the auction with the item searched
require(script.AuctionBanner).start(function()
	return locale
end, function(search: string?)
	require(script.AuctionWindow).pendingSearch = search
	closeWindow()
	open("auction")
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
-- running local boosters, top left under the artifacts button (placed in updateLayout)
local boosterHud = require(script.BoosterHud).start(
	gui,
	function()
		return profile
	end,
	T,
	function()
		open("boosters")
	end
)
-- the auto-sell income at the crosshair («+0,057 $») [владелец 28.10]
require(script.AutoSellFx).start(gui, function()
	return profile
end, function()
	return locale
end)
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

-- ---------------------------------------------------------------- ladders
require(script.LadderGrip).Start() -- catch a fall into the shaft without pushing away from the wall

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
	-- шот-шахта: one hit (the server refuses with a toast when the mine wants another tool)
	local mineId = part:GetAttribute("MineId")
	local shot = Config.shotTime(
		if typeof(mineId) == "string" then Config.location(mineId) else nil,
		toolId,
		level
	)
	if shot ~= nil then
		return shot or nil
	end
	local character = player.Character
	local haste = if character then tonumber(character:GetAttribute("Haste")) or 0 else 0
	return Config.breakTime(block, toolId, level, haste)
end

-- Prediction: the block disappears for this client the moment its timer ends; the server removes it
-- a few ms later. If the server rejects (or nothing arrives in 2 s) the block comes back as it was.
-- Only the look changes: collision stays until the server really removes the part, otherwise the
-- player could sink into the cell and fall through the unrendered solid cells below.
-- a cobweb block draws its cross sprite with child planes: they hide with it
local function setSpriteHidden(part: BasePart, hidden: boolean)
	for _, d in ipairs(part:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = if hidden then 1 else 0
		end
	end
end
local function hideLocally(part: BasePart)
	part.LocalTransparencyModifier = 1
	setSpriteHidden(part, true)
	part.CanQuery = false
	pending[part] = os.clock()
end
local function restoreLocally(part: BasePart)
	accepted[part] = nil
	if pending[part] then
		pending[part] = nil
		if part.Parent then
			part.LocalTransparencyModifier = 0
			setSpriteHidden(part, false)
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
	-- PRIS+ auto-dig (этап 8, PrisPerks): a mine block under the crosshair is dug as if the button were held
	local want = holding or (aim ~= nil and require(script.PrisPerks).autoDig(aim.part))
	if digging and digTarget then
		if digPredicted then
			-- [владелец 21.10, lag] do not wait for the server to remove the block: it gets our DigStarts
			-- in order and finishes this block before the next DigStart arrives, so dig on at once (the
			-- hidden block is not queryable, the crosshair finds the one behind it). Waiting cost a full
			-- round trip per block and looked like digging stopped.
			stopDig(false)
			if want and aim and not pending[aim.part] and now >= nextDigAt then
				startDig(aim)
			end
		elseif not aim or aim.part ~= digTarget then
			stopDig(true)
			if want and aim and not pending[aim.part] and now >= nextDigAt then
				startDig(aim)
			end
		else
			local k = math.clamp((now - digStarted) / digNeeded, 0, 1)
			BlockBreak.Update(digTarget, k)
			if k >= 1 then
				BlockBreak.Break(digTarget)
				hideLocally(digTarget)
				digPredicted = true
				local mineId = digTarget:GetAttribute("MineId")
				nextDigAt = now
					+ Config.pauseAfter(
						if typeof(mineId) == "string" then Config.location(mineId) else nil,
						digNeeded
					)
			end
		end
	elseif want and aim and not pending[aim.part] and now >= nextDigAt then
		startDig(aim)
	end
	-- keep swinging while the dig input is held on blocks (instant mining flips digging every few frames)
	HeldItem.SetDigging(digging or (want and digPredicted) or (want and aim ~= nil))
end)

-- Melee attack along the look direction (click / tap with nothing to dig), Better Combat-style
-- [владелец 22.10]: attacks come at the weapon's pace (vanilla attack speed), each plays the next animation
-- of the weapon's combo (sword: cut right, cut left, stab); the server hits along the arc (Combat).
-- [владелец 22.10: «бой неудобный»; docs/research/combat-feel.md] the soft lock of CombatFeel picks the
-- target, the character turns to it and the blow is aimed at it (the server re-aims at where it is when the
-- blow lands); a press a little early is buffered instead of lost; the impact is predicted on the client.
local attackState: Combat.ComboState = { lastAt = -math.huge, index = 0 }
local attackQueued = false
local BUFFER = 0.2 -- s before the weapon is ready in which a press is kept for later
local function heldKind(): (string, number)
	local stack = if profile then profile.inventory[profile.selectedSlot] else nil
	local toolId = if stack and Config.tools[stack.id] then stack.id else nil
	local kind = Combat.kind(toolId)
	return kind, Combat.duration(kind, stack and stack.level)
end
local function attack()
	local currentCamera = workspace.CurrentCamera
	if not currentCamera or currentWindowKind then
		return
	end
	local kind, duration = heldKind()
	local now = os.clock()
	local readyAt = attackState.lastAt + duration * 0.85
	if now < readyAt then
		if readyAt - now <= BUFFER and not attackQueued then
			attackQueued = true
			task.delay(readyAt - now + 0.01, function()
				attackQueued = false
				attack()
			end)
		end
		return -- still in the previous attack
	end
	local _, blow = Combat.next(attackState, kind, duration, now)
	local target = CombatFeel.Target()
	local aimed = if target then CombatFeel.FaceTarget(target) else nil
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
	CombatFeel.OnAttack(target, duration * blow.upswing, falling)
	-- the server time the other players are drawn at here: the server tests the blow there (lag compensation)
	Remotes.event("Attack"):FireServer(
		aimed or currentCamera.CFrame.LookVector,
		falling,
		target,
		require(script.Motion).viewTime()
	)
end
-- holding the attack (mouse with nothing to dig, the touch attack button) keeps swinging at the weapon's pace
local attackHeld = false
RunService.Heartbeat:Connect(function()
	if attackHeld and not currentWindowKind and not holding then
		attack()
	end
end)

-- PC / gamepad: hold the mouse button (R2) on a block
local function onDig(_: string, state: Enum.UserInputState, input: InputObject?)
	if state == Enum.UserInputState.Begin then
		if
			currentWindowKind
			-- a phone turns taps into MouseButton1 too: those are handled by the touch code. Without a touch screen the
			-- mouse is real and digs, also under Studio's ForceMobile [владелец 28.10: «не могу копать в Studio»]
			or (
				input
				and isMobile()
				and UserInputService.TouchEnabled
				and input.UserInputType == Enum.UserInputType.MouseButton1
			)
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
			attackHeld = true
			attack()
		end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		holding = false
		attackHeld = false
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

-- The bow [владелец 26.10]: hold the right mouse button (gamepad L2) to draw, let go to shoot (BowController); the
-- left button still digs and hits (with a bow in hand a blow is a bare-hand punch, as in Minecraft)
BowController.Start(function()
	return profile
end, function()
	return currentWindowKind ~= nil
end, renderCameraButton)
-- Eating [ваниль, владелец 27.10]: hold the right mouse button / L2 / F (or the «Съесть» button, a resting finger)
Eating.Start(function()
	return profile
end, function()
	return currentWindowKind ~= nil or HudLayout.isEditing()
end)
UserInputService.InputBegan:Connect(function(input: InputObject, processed: boolean)
	if
		not processed
		and (
			input.UserInputType == Enum.UserInputType.MouseButton2
			or input.KeyCode == Enum.KeyCode.ButtonL2
		)
	then
		if BowController.InHand() then
			BowController.Begin()
		elseif Eating.InHand() then
			Eating.Hold("mouse", true)
		end
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if
		input.UserInputType == Enum.UserInputType.MouseButton2
		or input.KeyCode == Enum.KeyCode.ButtonL2
	then
		BowController.Release()
		Eating.Hold("mouse", false)
	elseif input.KeyCode == Enum.KeyCode.F then
		Eating.Hold("key", false)
	elseif
		input.UserInputType == Enum.UserInputType.Touch
		or input.UserInputType == Enum.UserInputType.MouseButton1
	then
		Eating.Hold("button", false) -- let go anywhere, also off the button
	end
end)

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
-- [владелец 26.10, Bedrock] with a bow in hand a resting finger draws instead of digging (after DIG_HOLD); once
-- drawing, moving the finger aims (the camera turns) and lifting it shoots; a tap is still a blow
local touchBow = false
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
	-- the injection «Без нужд» too [владелец 28.10]
	-- and the donate items used from the hand: auto-sell, a booster item, the auction slot
	-- (required here: the top level of this script is at the 200-locals limit)
	local Donate = require(Shared.Donate)
	local Boosters = require(Shared.Boosters)
	if
		require(Shared.Books).isUsable(stack.id) -- an ancient book, powder, a dispeller: the book window
		or stack.id == Config.needs.injection.item
		or stack.id == Donate.AUTOSELL
		or stack.id == Donate.AUCTION_SLOT
		or stack.id == "oblivion_scroll" -- resets the skill tree (SkillService)
		or require(Shared.Potions).isUsable(stack.id) -- drink / throw / charge the stand (PotionService)
		or Boosters.fromItem(stack.id) ~= nil
	then
		return true
	end
	-- a location pass is used the same way (the server opens the location for good) [владелец 22.10]
	local passFor = stack.id:match("^(.+)_pass$")
	local location = passFor and Config.location(passFor)
	return location ~= nil and location.requiresPass == true
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
	local aim = if BowController.InHand() then nil else aimAt()
	touchAim = if aim and not pending[aim.part] then aim else nil
	touchBow = false
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
		Eating.Hold("touch", false)
		if touchBow then
			touchBow = false
			BowController.Release()
		elseif tapped and not touchDragged and not wasDigging and not touchAte then
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
	-- a finger resting with the bow in hand starts the draw (once per touch)
	if
		activeTouch
		and not touchBow
		and not touchDragged
		and BowController.InHand()
		and os.clock() - touchHeldSince >= DIG_HOLD
	then
		touchBow = true
		BowController.Begin()
	end
	-- hold with food and nothing under the crosshair → eat while the finger rests (Eating)
	if
		activeTouch
		and not digging
		and not touchAte
		and not touchDragged
		and isFood()
		and os.clock() - touchHeldSince >= EAT_HOLD
	then
		touchAte = true
		Eating.Hold("touch", true)
	end
end)
UserInputService.WindowFocusReleased:Connect(function()
	cancelDigInput()
	touchBow = false
	BowController.Cancel()
end)
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
-- screen and unfolds the grid to its right (2 rows × 6, clear of the joystick); choosing an item or
-- touching the game world folds it back
local touchMenuGrid = Instance.new("Frame")
touchMenuGrid.Name = "Grid"
touchMenuGrid.Position = UDim2.fromOffset(60, 0)
touchMenuGrid.Size = UDim2.fromOffset(6 * 60, 4 * 60)
touchMenuGrid.BackgroundTransparency = 1
touchMenuGrid.Visible = false
touchMenuGrid.Parent = touchMenus
local menuKeys = {
	"locations",
	"jobs",
	"upgrade",
	"level",
	"achievements",
	"boosters",
	"auction",
	"artifacts",
	"skills",
	"potions",
	"factions",
	"gangs",
	"donate",
	"rubbish", -- «Урна» (/rubbish, этап 3)
	"daily", -- «Ежедневные награды» (этап 7)
	"pris", -- «PRIS+» (этап 8)
	"names", -- «Ваши клички» (этап 9)
	"players", -- the TAB list (этап 9): the phone's way to it
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
		or (if kind == "gangs" then Config.icons.icons.top_crown else nil) -- until menu_gangs is uploaded
		or (if kind == "rubbish" then Config.iconFor("fire_shard") else nil) -- until menu_rubbish is uploaded
		or (if kind == "daily" then Config.iconFor("ancient_star") else nil) -- until menu_daily is uploaded
		or (if kind == "pris" then Config.icons.icons.top_crown else nil) -- until menu_pris is uploaded
		or (if kind == "names" then Config.iconFor("nickname_key") else nil) -- until menu_names is uploaded
		or (if kind == "players" then Config.icons.icons.rank_1 else nil) -- until menu_players is uploaded
	-- short captions: the full "Улучшить предмет" / "Повысить уровень" shrink to ~5 px in a 56 px button
	local captionKey = if kind == "level"
		then "touch_menu_level"
		elseif kind == "upgrade" then "touch_menu_upgrade"
		elseif kind == "factions" then "factions_title"
		elseif kind == "donate" then "touch_menu_donate"
		elseif kind == "rubbish" then "rubbish_title"
		elseif kind == "daily" then "daily_short"
		elseif kind == "pris" then "pris_title"
		else kind
	local button = touchIconButton(touchMenuGrid, icon, "", 56, T(captionKey))
	button.Position = UDim2.fromOffset(((i - 1) % 6) * 60, math.floor((i - 1) / 6) * 60)
	button.Name = "Touch_" .. kind
	button.Activated:Connect(function()
		setTouchMenuOpen(false)
		open(kind)
	end)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = captionKey
	end
end
-- [владелец 28.10] «Язык» and «Вид» left the grid for the settings. The cell after the windows: creative test mode, only for players CreativeService allows
do
	CreativeWindow.Listen()
	require(script.BossHud).Start(gui) -- boss name + health bar at the top, respawn boards over the arenas
	require(script.WarzoneHud).Start(gui) -- the Дворы: boards over the beacons, the capture hint at a free point
	require(script.BossAnimator).Start() -- smooth boss joints from its Action attributes
	require(script.MobAnimator).Start() -- Blender clips on the rats (idle, walk, bite, hurt, death)
	TopBoards.Start(function() -- the spawn top boards
		return locale
	end)
	CombatFeel.Start(gui, function() -- soft lock, predicted hits, damage numbers, mob health bars
		local kind = heldKind()
		return kind
	end, function()
		return locale
	end)
	require(script.IndoorLighting).Start() -- brighter ambient light under the quarry cave roof
	local button =
		touchIconButton(touchMenuGrid, Config.iconFor("golden_apple"), "", 56, T("creative"))
	button.Position = UDim2.fromOffset((#menuKeys % 6) * 60, math.floor(#menuKeys / 6) * 60)
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
-- the grid cell after the layout one: the settings [владелец 27.10] (key P on a computer)
do
	local button = touchIconButton(
		touchMenuGrid,
		Config.icons.icons["menu_settings"] or "",
		"",
		56,
		T("settings_title")
	)
	button.Position =
		UDim2.fromOffset(((#menuKeys + 2) % 6) * 60, math.floor((#menuKeys + 2) / 6) * 60)
	button.Name = "Touch_settings"
	button.Activated:Connect(function()
		setTouchMenuOpen(false)
		open("settings")
	end)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = "settings_title"
	end
end
-- the grid cell after the settings: «Пригласить друга» (этап 10; Roblox's invite window, Invite.luau) and the
-- «Избранное» card that slides in after 30 minutes of play (FavoriteCard)
do
	local button = touchIconButton(
		touchMenuGrid,
		Config.icons.icons.menu_invite or Config.iconFor("ordinary_key"),
		"",
		56,
		T("touch_menu_invite")
	)
	button.Position =
		UDim2.fromOffset(((#menuKeys + 3) % 6) * 60, math.floor((#menuKeys + 3) / 6) * 60)
	button.Name = "Touch_invite"
	button.Activated:Connect(function()
		setTouchMenuOpen(false)
		require(script.Invite).prompt(function()
			showToast(T("invite_unavailable"))
		end)
	end)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = "touch_menu_invite"
	end
	require(script.FavoriteCard).start(gui, function()
		return profile
	end, function()
		return locale
	end)
end
-- the 11th grid cell: move the HUD buttons [владелец 22.10] (HudLayout; key H on a computer)
do
	local button =
		touchIconButton(touchMenuGrid, Config.icons.icons["menu_layout"], "", 56, T("touch_layout"))
	button.Position =
		UDim2.fromOffset(((#menuKeys + 1) % 6) * 60, math.floor((#menuKeys + 1) / 6) * 60)
	button.Name = "Touch_layout"
	button.Activated:Connect(function()
		setTouchMenuOpen(false)
		openHudEditor()
	end)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = "touch_layout"
	end
end
-- [владелец 28.10: «добавить кнопку вид или убрать её»] the first / third person button: off at the start (the view
-- lives in the settings, V / F5 on a computer); «Добавить» in the layout editor puts it on the screen, where it is
-- moved and resized like the others, on a phone and on a computer
do
	local button =
		touchIconButton(gui, Config.icons.icons["menu_camera"], "", 56, T("touch_camera"))
	button.Name = "HudView"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Position = UDim2.new(1, -16, 1, -210)
	button.Visible = false
	button.Activated:Connect(toggleFirstPerson)
	HudLayout.register("view", button, true, true)
	HudLayout.setOptional("view", false)
	local caption = button:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		localizedLabels[caption] = "touch_camera"
	end
end
local touchActions = Instance.new("Frame")
touchActions.Name = "TouchActions"
touchActions.Size = UDim2.fromScale(1, 1)
touchActions.BackgroundTransparency = 1
touchActions.Parent = gui
-- [владелец 22.10: бой удобнее] a big round attack button next to Jump: a tap swings, holding keeps
-- swinging at the weapon's pace; the dark ring fills back while the weapon recovers. Taps on the screen
-- still swing too.
do
	local button = Instance.new("ImageButton")
	button.Name = "Touch_attack"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Size = UDim2.fromOffset(84, 84)
	button.Position = UDim2.new(1, -112, 1, -24)
	button.BackgroundColor3 = Color3.fromRGB(150, 35, 35)
	button.BackgroundTransparency = 0.25
	button.AutoButtonColor = true
	button.Image = Config.iconFor("sword", 10) or ""
	button.ScaleType = Enum.ScaleType.Fit
	button.ResampleMode = Enum.ResamplerMode.Pixelated
	button.Parent = touchActions
	HudLayout.register("attack", button, true, false)
	-- off at the start; «Добавить» in the layout editor puts it on the screen [владелец 27.10]
	HudLayout.setOptional("attack", false)
	button.Visible = false
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 220, 200)
	stroke.Transparency = 0.3
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	for _, side in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
		(pad :: any)[side] = UDim.new(0, 16)
	end
	pad.Parent = button
	local cooldown = Instance.new("Frame")
	cooldown.Name = "Cooldown"
	cooldown.AnchorPoint = Vector2.new(0.5, 0.5)
	cooldown.Position = UDim2.fromScale(0.5, 0.5)
	cooldown.Size = UDim2.fromScale(0, 0)
	cooldown.BackgroundColor3 = Color3.new(0, 0, 0)
	cooldown.BackgroundTransparency = 0.45
	cooldown.ZIndex = button.ZIndex + 1
	cooldown.Parent = button
	local cr = Instance.new("UICorner")
	cr.CornerRadius = UDim.new(1, 0)
	cr.Parent = cooldown
	button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			attackHeld = true
			attack()
		end
	end)
	button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		then
			attackHeld = false
		end
	end)
	RunService.RenderStepped:Connect(function()
		if not touchActions.Visible then
			return
		end
		local _, duration = heldKind()
		local left = math.clamp(1 - (os.clock() - attackState.lastAt) / (duration * 0.85), 0, 1)
		cooldown.Size = UDim2.fromScale(left * 1.4, left * 1.4)
	end)
end
-- [владелец 27.10: «кнопка прыгать с меню не двигается»] Roblox's own jump button (PlayerModule's TouchGui) follows
-- an invisible stand-in the layout editor moves; with no saved place it stays where Roblox puts it and the
-- stand-in follows it instead.
do
	local jumpProxy = Instance.new("Frame")
	jumpProxy.Name = "Touch_jump"
	jumpProxy.BackgroundTransparency = 1
	jumpProxy.Size = UDim2.fromOffset(70, 70)
	jumpProxy.Position = UDim2.new(1, -95, 1, -90)
	jumpProxy.Parent = touchActions
	HudLayout.register("jump", jumpProxy, true, false)
	-- while the layout is edited the real button is hidden (a tap on it would jump instead of dragging
	-- [владелец 27.10]) and the stand-in shows its picture
	local jumpLook = Instance.new("ImageLabel")
	jumpLook.Name = "Look"
	jumpLook.Size = UDim2.fromScale(1, 1)
	jumpLook.BackgroundTransparency = 1
	jumpLook.Visible = false
	jumpLook.Parent = jumpProxy
	local jumpMoved, jumpHidden = false, false
	local function robloxJumpButton(): GuiObject?
		local touchGui = player.PlayerGui:FindFirstChild("TouchGui")
		local frame = touchGui and touchGui:FindFirstChild("TouchControlFrame")
		local button = frame and frame:FindFirstChild("JumpButton")
		return if button and button:IsA("GuiObject") then button else nil
	end
	RunService.RenderStepped:Connect(function()
		local button = robloxJumpButton()
		local frame = button and button.Parent
		if not button or not frame or not frame:IsA("GuiObject") or not touchActions.Visible then
			return
		end
		-- Roblox's size (TouchJump: 70 on small screens, else 120) × the player's size; the stand-in keeps
		-- Roblox's size and its own UIScale (HudLayout) makes it match
		local small = math.min(frame.AbsoluteSize.X, frame.AbsoluteSize.Y) <= 500
		local base = if small then 70 else 120
		local userScale = jumpProxy:FindFirstChildOfClass("UIScale")
		local scaled = base * (if userScale then userScale.Scale else 1)
		button.Size = UDim2.fromOffset(scaled, scaled)
		jumpProxy.Size = UDim2.fromOffset(base, base)
		local editing = HudLayout.isEditing()
		if editing and not jumpHidden and button.Visible then
			if button:IsA("ImageButton") then
				jumpLook.Image, jumpLook.ImageRectOffset, jumpLook.ImageRectSize =
					button.Image, button.ImageRectOffset, button.ImageRectSize
			end
			button.Visible, jumpHidden = false, true
		elseif not editing and jumpHidden then
			button.Visible, jumpHidden = true, false
		end
		jumpLook.Visible = editing
		if HudLayout.moved("jump") or editing then
			local at = jumpProxy.AbsolutePosition - frame.AbsolutePosition
			button.Position = UDim2.fromOffset(at.X, at.Y)
			jumpMoved = true
			return
		end
		if jumpMoved then -- back to Roblox's own place (TouchJump's formula)
			local size = base
			button.Position = if small
				then UDim2.new(1, -(size * 1.5 - 10), 1, -size - 20)
				else UDim2.new(1, -(size * 1.5 - 10), 1, -size * 1.75)
			jumpMoved = false
		end
		local at = button.AbsolutePosition - touchActions.AbsolutePosition
		jumpProxy.Position = UDim2.fromOffset(at.X, at.Y)
	end)
end
local function useConsumable()
	if profile then
		local stack = profile.inventory[profile.selectedSlot]
		if stack and require(Shared.Books).isUsable(stack.id) then
			require(script.BookWindow).sourceSlot = profile.selectedSlot
			open("book")
			return
		end
		-- a splash potion flies where the camera looks (PotionService)
		Remotes.event("UseConsumable")
			:FireServer(profile.selectedSlot, workspace.CurrentCamera.CFrame.LookVector)
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
-- food: eaten while the button is held (Eating); soap and the rest: used on a tap
eatButton.InputBegan:Connect(function(input: InputObject)
	if
		(
			input.UserInputType == Enum.UserInputType.Touch
			or input.UserInputType == Enum.UserInputType.MouseButton1
		)
		and Eating.InHand()
		and not HudLayout.isEditing()
	then
		Eating.Hold("button", true)
	end
end)
eatButton.Activated:Connect(function()
	if not Eating.InHand() then
		useConsumable()
	end
end)
local inventoryButton = touchIconButton(touchActions, nil, "•••", 40)
inventoryButton.Name = "TouchInventory"
inventoryButton.TextSize = 20
inventoryButton.Activated:Connect(function()
	open("inventory")
end)
HudLayout.register("eat", eatButton, true, false)
HudLayout.register("menu", touchMenus, true, false, menuToggle)
HudLayout.register("inventory", inventoryButton, true, false)
HudLayout.register("stats", stats, true, true)
-- [владелец 27.10: «уменьшить … уведомления, переместить их … тоже самое с баром бустеров»]: moved and resized
-- here, shown or hidden in the settings
HudLayout.register("toasts", toast, true, true)
HudLayout.register("boosters", boosterHud, true, true)
-- [владелец 28.10] the status effect icons move too; the phone's «Бег» button (Sprint)
HudLayout.register("effects", effectsHud, true, true)
do
	local sprintButton = require(script.Sprint).start(touchActions)
	HudLayout.register("sprint", sprintButton, true, false)
	-- the joystick pushed to its edge sprints by itself, so the «Бег» button is off at the start; «Добавить» in the
	-- layout editor brings it back [владелец 28.10: «кнопка быстрого бега стоит не там … если джостик потянут сильно,
	-- бег будет быстрым»]
	HudLayout.setOptional("sprint", false)
	sprintButton.Visible = false
end
-- Roblox's chat window stays left of the hotbar band (the meters are drawn over the hotbar, as wide as it)
require(script.ChatWindow).hud({ hotbar = hotbar })

Instance.new("UIScale").Parent = stats -- HudLayout sets it: the mode's base × the player's size
local hotbarScale = Instance.new("UIScale")
hotbarScale.Parent = hotbar
Instance.new("UIScale").Parent = effectsHud -- HudLayout sets it: the mode's base × the player's size
local slotScales: { UIScale } = {}
for i, slot in ipairs(hotbarSlots) do
	local scale = Instance.new("UIScale")
	scale.Parent = slot
	slotScales[i] = scale
end
local hudOverride: { [string]: any } = {} -- mode → the layout just edited (false = reset)
local function updateLayout()
	local mobile = isMobile()
	local currentCamera = workspace.CurrentCamera
	local viewport = if currentCamera then currentCamera.ViewportSize else Vector2.new(900, 560)
	touchMenus.Visible, touchActions.Visible = mobile, mobile
	hints.Visible, languageButton.Visible = not mobile, not mobile
	artifactButton.Visible = not mobile
	menuButton.Visible = not mobile
	HudLayout.setBaseScale(stats, if mobile then 0.65 else 1) -- × the player's size (HudLayout.apply)
	stats.Position = if mobile then UDim2.new(1, -148, 0, 64) else UDim2.new(1, -224, 0.4, 0)
	-- effect icons sit left of the stats panel, top-aligned with it
	effectsHud.Position = if mobile then UDim2.new(1, -152, 0, 64) else UDim2.new(1, -230, 0.4, 0)
	HudLayout.setBaseScale(effectsHud, if mobile then 0.75 else 1)
	boosterHud.Position = if mobile then UDim2.fromOffset(72, 64) else UDim2.fromOffset(8, 116)
	local size = if mobile and viewport.X <= 700 then 40 else SLOT
	local width = 9 * (size + 4) + 8
	hotbar.Size = UDim2.fromOffset(width, size + 12)
	hotbar.AnchorPoint = Vector2.new(0.5, 1)
	hotbar.Position = UDim2.new(0.5, 0, 1, -8)
	hotbarScale.Scale = if mobile then math.min(1, (viewport.X - 20) / width) else 1
	survivalScale.Scale = 1 -- the meters span the hotbar and share its scale
	-- the key hints right of the hotbar, short of the language button: Roblox's chat window owns the bottom-left corner
	local hintsLeft = width / 2 * hotbarScale.Scale + 12
	hints.Position = UDim2.new(0.5, hintsLeft, 1, -10)
	hints.Size = UDim2.new(0.5, -hintsLeft - 84, 0, 0)
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
	-- the player's own positions over the defaults (a fresh edit wins until the profile catches up)
	local mode = if mobile then "mobile" else "desktop"
	local saved = if profile and profile.hudLayout then profile.hudLayout[mode] else nil
	local edited = hudOverride[mode]
	local layout = if edited ~= nil then (if edited then edited else nil) else saved
	HudLayout.setDefault(stats)
	HudLayout.setDefault(inventoryButton)
	HudLayout.setDefault(toast)
	HudLayout.setDefault(boosterHud)
	HudLayout.setDefault(effectsHud)
	HudLayout.apply(mode, layout)
	-- the status effect icons stay just left of the stats panel wherever it goes, unless moved themselves
	if layout and layout.stats and not layout.effects then
		effectsHud.Position = UDim2.new(
			stats.Position.X.Scale,
			stats.Position.X.Offset - 4,
			stats.Position.Y.Scale,
			stats.Position.Y.Offset
		)
	end
end
relayoutHud = function()
	updateLayout()
end
openHudEditor = function()
	if HudLayout.isEditing() then
		return
	end
	closeWindow()
	toastToken += 1 -- a sample in the notification panel while it is placed (no pending hide)
	toastText.Text = T("layout_toasts")
	toast.Visible = true
	local mode = if isMobile() then "mobile" else "desktop"
	local edited = hudOverride[mode]
	local saved = if profile and profile.hudLayout then profile.hudLayout[mode] else nil
	HudLayout.edit(gui, mode, if edited ~= nil then (if edited then edited else nil) else saved, {
		title = T("layout_title"),
		done = T("layout_done"),
		reset = T("layout_reset"),
		hide = T("layout_hide"),
		show = T("layout_show"),
	}, function(layout)
		hudOverride[mode] = if layout then layout else false
		Remotes.event("SetHudLayout"):FireServer(mode, layout)
		toast.Visible = false
		updateLayout()
	end)
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
	local hasInventoryRow = openWindow ~= nil
		and openWindow.Visible
		and (currentWindowKind == "inventory" or currentWindowKind == "case")
	hotbar.Visible = not hasInventoryRow
	local controlsVisible = isMobile() and currentWindowKind == nil
	touchMenus.Visible, touchActions.Visible = controlsVisible, controlsVisible
	local food, needItem = isFood(), isNeedConsumable()
	eatButton.Visible = controlsVisible and (food or needItem or HudLayout.isEditing())
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
	elseif k == Enum.KeyCode.N then
		open("donate") -- «Донат-магазин» [решение: клавиша]
	elseif k == Enum.KeyCode.L then
		open("achievements")
	elseif k == Enum.KeyCode.B then
		open("boosters") -- «Хранилище бустеров» [решение: клавиша]
	elseif k == Enum.KeyCode.T then
		open("skills") -- «Умения» [решение: клавиша; в оригинале /skills]
	elseif k == Enum.KeyCode.Z then
		open("potions") -- «Зельеварка» [решение: клавиша]
	elseif k == Enum.KeyCode.Y then
		open("auction") -- «Аукцион» [решение: клавиша; в оригинале /ah]
	elseif k == Enum.KeyCode.X then
		open("menu") -- the main menu [вики: клавиша X]
	elseif k == Enum.KeyCode.P then
		open("settings") -- [решение: клавиша]
	elseif k == Enum.KeyCode.G then
		open("factions") -- [клиент] /fraction
	elseif k == Enum.KeyCode.R then
		open("gangs") -- «Банда» [решение: клавиша; в оригинале /gang]
	elseif k == Enum.KeyCode.I then
		open("artifacts")
	elseif k == Enum.KeyCode.M then
		open("locations")
	elseif k == Enum.KeyCode.Tab then
		open("players") -- the TAB list (этап 9); Roblox's own list is off
	elseif k == Enum.KeyCode.H then
		openHudEditor() -- move the HUD [владелец 22.10]
	elseif k == Enum.KeyCode.K and player:GetAttribute("CreativeAllowed") then
		open("creative") -- test mode (CreativeService)
	elseif k == Enum.KeyCode.V or k == Enum.KeyCode.F5 then
		toggleFirstPerson()
	elseif k == Enum.KeyCode.F then
		if Eating.InHand() then
			Eating.Hold("key", true)
		else
			useConsumable()
		end
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
		if action == "attack" then
			attack()
			return CombatFeel.Target()
		elseif action == "swingAt" then
			HeldItem.DebugHold(tonumber(arg) or 0.2, 30)
			return true
		elseif action == "swingPose" then
			-- a blow frozen `arg` seconds in (the hitstop holds it), for first-person screenshots
			attack()
			task.wait(tonumber(arg) or 0.1)
			HeldItem.Hitstop(8)
			local kind, progress = HeldItem.SwingState()
			return kind .. " " .. tostring(progress)
		elseif action == "toggleCamera" then
			toggleFirstPerson()
			return firstPerson
		elseif action == "open" then
			open(arg)
			return currentWindowKind
		elseif action == "close" then
			closeWindow()
			return true
		elseif action:sub(1, 4) == "chat" then -- chatState / chatSystem
			return require(script.ChatWindow).debug(action, arg)
		elseif action == "hudEdit" then
			openHudEditor()
			return HudLayout.isEditing()
		elseif action == "aim" then
			local aim = aimAt(if typeof(arg) == "Vector2" then arg else nil)
			return if aim then { part = aim.part, hit = aim.hit } else nil
		elseif action == "bow" then
			-- true starts a draw (false when there is no bow or no arrow), false lets it go
			if arg == true then
				return BowController.Begin()
			end
			BowController.Release()
			return true
		elseif action == "eat" then
			-- true holds the use button with the selected item, false lets it go
			Eating.Hold("key", arg == true)
			return Eating.InHand()
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
	-- on the Player, not in PlayerGui: PlayerGui empties when the character respawns and the hook was lost
	hook.Parent = player
end
print(string.format("[coco-prison] client ready (%s)", locale))
