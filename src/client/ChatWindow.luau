--!strict
-- The chat (этап 3; reworked by docs/research/chat-ux-spec.md) [владелец 28.10: «у нас вообще никакого чата нет»;
-- «МАКСИМУМ УСИЛИЙ К ЧАТУ. Как сделать так, чтобы не мешало игрокам, расположение чата, размеры»; вики MENUS-SOCIAL:
-- мульти-чат, вкладки с «+2»]. Our own chat over TextChatService replaces Roblox's window and input bar (both off).
--   * Closed = the feed, exactly like Minecraft: the newest lines of the open tab, the system lines and (unless the
--     setting says no) the global lines appear bottom-left on a computer, each on its own dark backing, stay
--     Config.chat.fadeSeconds and fade out; when nobody writes nothing of the chat is visible. Nothing in it takes a
--     click or a touch. «+N» over the feed counts what reached the other tabs. On a phone the feed is 3 thin lines
--     under a small round chat button under the touch menu button (the joystick and the action buttons own the
--     bottom corners).
--   * Open (Enter or «/» on a computer, the chat button, gamepad DPadUp): the same corner grows into the panel —
--     tab pills (Фракция / Банда only when the player has one), the history (newest at the bottom, the wheel
--     scrolls, a new line never yanks the view while the player reads above: «↓ новые»), the input with the channel
--     hint, a gear (quick settings) and ×. The mouse is free while it is open. Closing: Esc, Enter on an empty
--     line, sending (computer), ×, the chat button, a click / tap on the game world (it only closes the chat).
--   * Where and how big: ChatLayout, against the real rects of the HUD init.client hands over (ChatWindow.hud) —
--     never over the hotbar, the hearts, the hints (they fade under the open panel), the top-left buttons, the
--     booster bar, the stats, the joystick, the jump / action buttons, the crosshair, Roblox's top bar. The HUD
--     editor [H] moves and resizes it (HudLayout id "chat"; a sample feed shows while it is placed).
--   * Settings (profile.settings, the «Чат» section of SettingsWindow and the gear here — one source): size, the
--     feed backing, how the feed hides (10 s / never / always), bubbles, global lines in the feed, tips, the chat
--     button on a computer, the whole chat off (then Enter and «/» do nothing; back on in Settings).
--   * Sending: «/…» = a command (ChatCommands); otherwise Chat.route — a «!» / «@» / «#» prefix wins over the open
--     tab. Общий, Фракция, Банда go through TextChatService (TextChannel:SendAsync: Roblox filters it for every
--     receiver); Глобальный through ChatGlobal (ChatService filters it and sends it to every server).
--   * Receiving: TextChatService.MessageReceived (text already filtered for this player), ChatGlobal, ChatSystem.
--     Everything is drawn as RichText with the player's part escaped (Chat.escape). Line format [вики MENUS-SOCIAL]:
--     «[G] [PRIS+] [TAG] Ник [48 ур.] Кличка » текст». Identical consecutive lines from one sender collapse into
--     «×N»; announcements reach the chat at most one per Config.chat.announceGapSeconds (queued, repeats dropped).
--   * Bubbles over heads only for Общий (ChatBubbles; Roblox's own bubbles are off — they cannot skip a channel).
--   * An account Roblox does not let chat (attribute ChatAllowed = false) still sees the announcements and may type
--     commands; the input says so. «[Совет]» every Config.chat.tipsMinutes (chat_tip_1…N), off in the settings.
-- Этап 9: a click / tap on another player's line in the open history opens his card in the TAB list.
-- QA (Studio): Player.ClientDebug "chatLayout" {w, h, touch, rows} / "chatLive" / "chatSpam" n / "chatOpen" bool /
-- "chatState" (ChatWindow.debug).
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)
local ChatCommands = require(script.Parent.ChatCommands)
local ChatLayout = require(script.Parent.ChatLayout)
local ChatBubbles = require(script.Parent.ChatBubbles)
local HidePlayers = require(script.Parent.HidePlayers)
local HudLayout = require(script.Parent.HudLayout)

export type Api = {
	open: (kind: string) -> (), -- one of our windows (init.client windowBuilders)
	profile: () -> Types.Profile?,
	locale: () -> string,
	toast: (text: string) -> (),
	windowOpen: (() -> boolean)?, -- one of our windows is on the screen (the feed and the buttons give way)
}

type Kind = Chat.Kind
-- kind nil = a system line, shown in every tab; key = what makes two lines «the same» (×N); at = os.clock() it arrived
type Line = {
	kind: Kind?,
	text: string,
	own: boolean,
	user: number?,
	key: string?,
	count: number,
	at: number,
}
type FeedItem = { line: Line, row: Frame, label: TextLabel }

local ChatWindow = {}

local cfg = Config.chat
local LAYOUT = cfg.layout
local player = Players.LocalPlayer
local HEADER, INPUT_H, PAD = 26, 30, 6
local MARKER_H = 18
local GLOBAL = Color3.fromRGB(85, 220, 255)
local NICK = Color3.fromRGB(255, 200, 80)
local MUTED = Color3.fromRGB(150, 150, 165)
local PRIS = Color3.fromRGB(255, 190, 40) -- the [PRIS+] prefix (этап 8) [вики MENUS-SOCIAL]
local REPLY = Color3.fromRGB(205, 205, 215)
local TIP = Color3.fromRGB(110, 225, 130)
local PANEL_BG = Color3.fromRGB(12, 12, 16)
local SYSTEM_COLORS: { [string]: Color3 } = {
	announce = Ui.colors.header,
	reply = REPLY,
	error = Kit.BAD,
}
local FADE_HINTS = TweenInfo.new(0.25)

local hudObjects: { [string]: GuiObject } = {}
local requestLayout: () -> () = function() end
local debugHandler: ((string, any) -> any)? = nil

-- init.client hands over the HUD elements the chat keeps clear of (names: see ChatLayout); called again is fine
function ChatWindow.hud(objects: { [string]: GuiObject })
	for name, object in pairs(objects) do
		hudObjects[name] = object
		object:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
			requestLayout()
		end)
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			requestLayout()
		end)
		object:GetPropertyChangedSignal("Visible"):Connect(function()
			requestLayout()
		end)
	end
	requestLayout()
end

-- the Studio QA hook (init.client ClientDebug passes the "chat…" actions here)
function ChatWindow.debug(action: string, arg: any): any
	local handler = debugHandler
	return if handler then handler(action, arg) else nil
end

local function isMobile(): boolean
	if RunService:IsStudio() and workspace:GetAttribute("ForceMobile") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function colored(text: string, color: Color3): string
	return '<font color="' .. Ui.hex(color) .. '">' .. text .. "</font>"
end

-- shown on the screen: itself and every GuiObject above it visible, its ScreenGui enabled
local function shown(object: GuiObject): boolean
	local node: Instance? = object
	while node do
		if node:IsA("GuiObject") then
			if not node.Visible then
				return false
			end
		elseif node:IsA("LayerCollector") then
			return node.Enabled
		end
		node = node.Parent
	end
	return false
end

-- in screen pixels: AbsolutePosition is measured from below Roblox's top bar even in an IgnoreGuiInset ScreenGui,
-- the chat's own positions (UDim2 offsets in such a ScreenGui) from the screen's corner
local function rectOf(object: GuiObject, withChildren: boolean): ChatLayout.Rect?
	if not shown(object) or object.AbsoluteSize.X <= 0 or object.AbsoluteSize.Y <= 0 then
		return nil
	end
	local origin = GuiService:GetGuiInset()
	local p, s = object.AbsolutePosition, object.AbsoluteSize
	local x0, y0, x1, y1 = p.X, p.Y, p.X + s.X, p.Y + s.Y
	if withChildren then -- the hotbar with the meters and the armour row drawn over it
		for _, d in ipairs(object:GetDescendants()) do
			if d:IsA("GuiObject") and d.AbsoluteSize.X > 0 and shown(d) then
				local dp, ds = d.AbsolutePosition, d.AbsoluteSize
				x0, y0 = math.min(x0, dp.X), math.min(y0, dp.Y)
				x1, y1 = math.max(x1, dp.X + ds.X), math.max(y1, dp.Y + ds.Y)
			end
		end
	end
	return { x = x0 + origin.X, y = y0 + origin.Y, w = x1 - x0, h = y1 - y0 }
end

-- the chat's own drawing of a speech bubble (the phone button, the optional button on a computer)
local function drawBubbleIcon(parent: GuiObject)
	local icon = (Config.icons.icons :: any).menu_chat
	if typeof(icon) == "string" and icon ~= "" then
		local image = Instance.new("ImageLabel")
		image.Name = "Icon"
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(0.7, 0.7)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		image.Image = icon
		image.Parent = parent
		return
	end
	local body = Instance.new("Frame")
	body.Name = "Icon"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.44)
	body.Size = UDim2.fromScale(0.6, 0.44)
	body.BackgroundColor3 = Ui.colors.white
	body.BorderSizePixel = 0
	body.Parent = parent
	Kit.corner(body, 4)
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.fromScale(0.3, 0.95)
	tail.Size = UDim2.fromScale(0.28, 0.4)
	tail.Rotation = 35
	tail.BackgroundColor3 = Ui.colors.white
	tail.BorderSizePixel = 0
	tail.Parent = body
	for i = 0, 2 do
		local dot = Instance.new("Frame")
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.Position = UDim2.fromScale(0.25 + i * 0.25, 0.5)
		dot.Size = UDim2.fromScale(0.13, 0.26)
		dot.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
		dot.BorderSizePixel = 0
		dot.ZIndex = 2
		dot.Parent = body
		Kit.corner(dot, 2)
	end
end

function ChatWindow.start(api: Api)
	local locale = api.locale()
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local function windowOpen(): boolean
		local check = api.windowOpen
		return check ~= nil and check()
	end

	-- Roblox's own window, input bar and bubbles give way to ours
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = false
		TextChatService.ChatInputBarConfiguration.Enabled = false
		TextChatService.BubbleChatConfiguration.Enabled = false
	end)

	-- ── the settings (profile.settings; a fresh change wins until the profile catches up) ──────────────────────
	local pending: { [string]: { value: any, untilAt: number } } = {}
	local function setting(key: string): any
		local profile = api.profile()
		local saved = if profile and profile.settings then (profile.settings :: any)[key] else nil
		local p = pending[key]
		if p then
			if saved == p.value or os.clock() > p.untilAt then
				pending[key] = nil
			else
				return p.value
			end
		end
		return saved
	end
	local function step(key: string): number
		local v = setting(key)
		return if v == 1 or v == 3 then v else 2
	end
	type View = {
		size: number,
		back: number,
		fade: number,
		bubbles: boolean,
		globalFeed: boolean,
		off: boolean,
		button: boolean,
		tips: boolean,
	}
	local function view(): View
		return {
			size = step("chatSize"),
			back = step("chatBack"),
			fade = if setting("chatFade") == 2 or setting("chatFade") == 3
				then setting("chatFade")
				else 1,
			bubbles = setting("bubblesOff") ~= true,
			globalFeed = setting("chatGlobalOff") ~= true,
			off = setting("chatOff") == true,
			button = setting("chatButton") == true,
			tips = setting("tipsOff") ~= true,
		}
	end
	local current: View = view()

	-- ── the instances ───────────────────────────────────────────────────────────────────────────────────────────
	local playerGui = player:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "ChatGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 2 -- over the HUD and Roblox's touch controls (the panel and the phone button)
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	-- a click / tap on the game world while the chat is open only closes it (under the HUD and the joystick, which
	-- keep working); Modal frees the mouse in first person
	local catcherGui = Instance.new("ScreenGui")
	catcherGui.Name = "ChatCatcher"
	catcherGui.ResetOnSpawn = false
	catcherGui.IgnoreGuiInset = true
	catcherGui.DisplayOrder = -1
	catcherGui.Parent = playerGui
	local catcher = Instance.new("TextButton")
	catcher.Name = "World"
	catcher.Size = UDim2.fromScale(1, 1)
	catcher.BackgroundTransparency = 1
	catcher.Text = ""
	catcher.AutoButtonColor = false
	catcher.Modal = true
	catcher.Visible = false
	catcher.Parent = catcherGui

	-- the holder: what the HUD editor moves (the feed, the «+N», the chat button); takes no input itself
	local holder = Instance.new("Frame")
	holder.Name = "Chat"
	holder.BackgroundTransparency = 1
	holder.Active = false
	holder.Size = UDim2.fromOffset(400, 200)
	holder.Parent = gui
	local holderScale = Instance.new("UIScale")
	holderScale.Parent = holder
	local feed = Instance.new("Frame")
	feed.Name = "Feed"
	feed.BackgroundTransparency = 1
	feed.Active = false
	feed.Parent = holder
	local feedList = Instance.new("UIListLayout")
	feedList.SortOrder = Enum.SortOrder.LayoutOrder
	feedList.Padding = UDim.new(0, 2)
	feedList.Parent = feed
	local marker = Instance.new("TextLabel")
	marker.Name = "Unread"
	marker.BackgroundColor3 = Color3.new(0, 0, 0)
	marker.BackgroundTransparency = 0.55
	marker.AutomaticSize = Enum.AutomaticSize.X
	marker.Size = UDim2.fromOffset(0, MARKER_H - 2)
	marker.Font = Kit.BOLD
	marker.TextSize = 12
	marker.TextColor3 = Ui.colors.yellow
	marker.TextStrokeTransparency = 0.6
	marker.RichText = true
	marker.Text = ""
	marker.Visible = false
	marker.LayoutOrder = -1 -- over the oldest line of the feed
	marker.Parent = feed
	Kit.corner(marker, 4)
	do
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
		pad.Parent = marker
	end
	-- the chat button: a frame with a hit button (the hit hides while the HUD editor drags the holder)
	local button = Instance.new("Frame")
	button.Name = "ChatButton"
	button.BackgroundColor3 = Ui.colors.buttonGrey
	button.BackgroundTransparency = 0.5
	button.Visible = false
	button.Parent = holder
	local buttonCorner = Instance.new("UICorner")
	buttonCorner.CornerRadius = UDim.new(1, 0)
	buttonCorner.Parent = button
	Kit.stroke(button, Ui.colors.white, 1, 0.75)
	drawBubbleIcon(button)
	local badge = Instance.new("TextLabel")
	badge.Name = "Badge"
	badge.AnchorPoint = Vector2.new(0.5, 0.5)
	badge.Position = UDim2.fromScale(0.88, 0.14)
	badge.Size = UDim2.fromOffset(18, 16)
	badge.AutomaticSize = Enum.AutomaticSize.X
	badge.BackgroundColor3 = Color3.fromRGB(210, 50, 50)
	badge.Font = Kit.BOLD
	badge.TextSize = 11
	badge.TextColor3 = Ui.colors.white
	badge.Visible = false
	badge.ZIndex = 3
	badge.Parent = button
	Kit.corner(badge, 8)
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.Size = UDim2.fromScale(1, 1)
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.ZIndex = 4
	hit.Parent = button

	-- the open panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.BackgroundColor3 = PANEL_BG
	panel.BackgroundTransparency = cfg.panelBack
	panel.Active = true
	panel.Visible = false
	panel.Parent = gui
	Kit.corner(panel, 8)
	Kit.stroke(panel, Kit.EDGE, 1, 0.5)
	local panelScale = Instance.new("UIScale")
	panelScale.Parent = panel
	local tabsRow = Instance.new("Frame")
	tabsRow.Name = "Tabs"
	tabsRow.BackgroundTransparency = 1
	tabsRow.Position = UDim2.fromOffset(PAD, PAD)
	tabsRow.Size = UDim2.new(1, -PAD * 2 - (HEADER - 4) * 2 - 8, 0, HEADER - 4)
	tabsRow.Parent = panel
	local tabs: { [Kind]: TextButton } = {}
	for _, kind in ipairs(Chat.KINDS) do
		local tab = Ui.button(tabsRow, "", UDim2.fromOffset(80, HEADER - 4), UDim2.new(), Kit.GREY)
		tab.Name = "Tab_" .. kind
		tab.Font = Kit.BOLD
		tab.TextSize = 13
		tab.RichText = true
		local round = tab:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(1, 0)
		end
		tabs[kind] = tab
	end
	local function headerButton(text: string, name: string, slot: number): TextButton
		local b = Ui.button(
			panel,
			text,
			UDim2.fromOffset(HEADER - 4, HEADER - 4),
			UDim2.new(1, -PAD - slot * (HEADER - 4) - (slot - 1) * 4, 0, PAD),
			Kit.GREY
		)
		b.Name = name
		b.Font = Kit.BOLD
		b.TextSize = 15
		local round = b:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(1, 0)
		end
		return b
	end
	local closeButton = headerButton("×", "Close", 1)
	local gearButton = headerButton("⚙", "Gear", 2)

	local log = Instance.new("ScrollingFrame")
	log.Name = "History"
	log.BackgroundTransparency = 1
	log.BorderSizePixel = 0
	log.ScrollBarThickness = 4
	log.ScrollBarImageColor3 = Kit.EDGE
	log.AutomaticCanvasSize = Enum.AutomaticSize.Y
	log.CanvasSize = UDim2.new()
	log.ScrollingDirection = Enum.ScrollingDirection.Y
	log.Position = UDim2.fromOffset(PAD, PAD + HEADER)
	log.Size = UDim2.new(1, -PAD * 2, 1, -(PAD * 3 + HEADER + INPUT_H))
	log.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = log
	local newBelow = Ui.button(
		panel,
		"",
		UDim2.fromOffset(84, 20),
		UDim2.new(0.5, 0, 1, -(PAD * 2 + INPUT_H + 4)),
		Ui.colors.buttonBlue
	)
	newBelow.Name = "NewBelow"
	newBelow.AnchorPoint = Vector2.new(0.5, 1)
	newBelow.Font = Kit.BOLD
	newBelow.TextSize = 12
	newBelow.Visible = false
	newBelow.ZIndex = 3
	do
		local round = newBelow:FindFirstChildOfClass("UICorner")
		if round then
			round.CornerRadius = UDim.new(1, 0)
		end
	end

	local input = Instance.new("TextBox")
	input.Name = "Input"
	input.BackgroundColor3 = Kit.TRACK
	input.BackgroundTransparency = 0.2
	input.BorderSizePixel = 0
	input.ClearTextOnFocus = false
	input.Font = Kit.TEXT
	input.TextSize = 14
	input.TextColor3 = Ui.colors.white
	input.PlaceholderColor3 = MUTED
	input.TextXAlignment = Enum.TextXAlignment.Left
	input.TextTruncate = Enum.TextTruncate.AtEnd
	input.Text = ""
	input.Position = UDim2.new(0, PAD, 1, -PAD - INPUT_H)
	input.Size = UDim2.new(1, -PAD * 3 - INPUT_H - 6, 0, INPUT_H)
	input.Parent = panel
	Kit.corner(input, 6)
	do
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
		pad.Parent = input
	end
	local sendButton = Ui.button(
		panel,
		"»",
		UDim2.fromOffset(INPUT_H + 6, INPUT_H),
		UDim2.new(1, -PAD - INPUT_H - 6, 1, -PAD - INPUT_H),
		Ui.colors.buttonBlue
	)
	sendButton.Name = "Send"
	sendButton.TextSize = 18
	Kit.corner(sendButton, 6)

	-- the gear's quick settings (the same profile settings as the «Чат» section of the settings window)
	local POP_W, POP_ROW = 286, 34
	local popover = Instance.new("Frame")
	popover.Name = "QuickSettings"
	popover.AnchorPoint = Vector2.new(1, 0)
	popover.Position = UDim2.new(1, -PAD, 0, PAD + HEADER)
	popover.Size = UDim2.fromOffset(POP_W, 4 * POP_ROW + 30)
	popover.BackgroundColor3 = Kit.CARD
	popover.BackgroundTransparency = 0
	popover.Visible = false
	popover.ZIndex = 5
	popover.Active = true
	popover.Parent = panel
	Kit.corner(popover, 8)
	Kit.stroke(popover, Kit.EDGE, 1, 0.2)
	local popTitle = Ui.label(
		popover,
		"",
		UDim2.new(1, -12, 0, 22),
		UDim2.fromOffset(8, 3),
		13,
		Ui.colors.header
	)
	popTitle.Font = Kit.BOLD
	popTitle.ZIndex = 6
	local function popRow(i: number): (TextLabel, Frame)
		local row = Instance.new("Frame")
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(8, 26 + (i - 1) * POP_ROW)
		row.Size = UDim2.new(1, -16, 0, POP_ROW - 4)
		row.ZIndex = 6
		row.Parent = popover
		local caption = Ui.label(row, "", UDim2.new(0, 80, 1, 0), UDim2.new(), 13, Ui.colors.text)
		caption.Font = Kit.TEXT
		caption.TextWrapped = true
		caption.ZIndex = 6
		return caption, row
	end
	local function popButton(row: Frame, text: string, x: number, w: number): TextButton
		local b = Ui.button(row, text, UDim2.new(0, w, 1, 0), UDim2.fromOffset(x, 0), Kit.GREY)
		b.Font = Kit.BOLD
		b.TextSize = 14
		b.ZIndex = 7
		return b
	end
	local sizeCaption, sizeRow = popRow(1)
	local sizeDown = popButton(sizeRow, "−", 86, 30)
	local sizeValue =
		Ui.label(sizeRow, "", UDim2.fromOffset(118, POP_ROW - 4), UDim2.fromOffset(122, 0), 13)
	sizeValue.TextXAlignment = Enum.TextXAlignment.Center
	sizeValue.Font = Kit.BOLD
	sizeValue.ZIndex = 7
	local sizeUp = popButton(sizeRow, "+", 240, 30)
	local backCaption, backRow = popRow(2)
	local backButtons: { TextButton } = {}
	for i = 1, 3 do
		backButtons[i] = popButton(backRow, "", 86 + (i - 1) * 62, 60)
		backButtons[i].TextSize = 13
	end
	local buttonCaption, buttonRow = popRow(3)
	local buttonToggle = popButton(buttonRow, "", 86, 184)
	local offRow = Instance.new("Frame")
	offRow.BackgroundTransparency = 1
	offRow.Position = UDim2.fromOffset(8, 26 + 3 * POP_ROW)
	offRow.Size = UDim2.new(1, -16, 0, POP_ROW - 4)
	offRow.ZIndex = 6
	offRow.Parent = popover
	local offButton = Ui.button(offRow, "", UDim2.fromScale(1, 1), UDim2.new(), Ui.colors.close)
	offButton.Font = Kit.BOLD
	offButton.TextSize = 14
	offButton.ZIndex = 7

	-- ── state ───────────────────────────────────────────────────────────────────────────────────────────────────
	local tab: Kind = "local"
	local lines: { Line } = {}
	local unread: { [Kind]: number } = {}
	local unreadClosed = 0 -- for the chat button's badge
	local markerAt = -math.huge -- when the «+N» last changed (it fades with the feed)
	local opened = false
	local order = 0
	local blocked: { [number]: boolean } = {}
	local labels: { [Line]: TextLabel } = {} -- the open history
	local items: { FeedItem } = {} -- the closed feed, oldest first
	local layoutNow: ChatLayout.Result? = nil
	local sampling = false -- the HUD editor is open: a sample feed is shown
	local hintsFaded = false
	local prevMouseIcon: boolean? = nil
	local openedAt = 0
	local windowWasOpen = false

	local function has(kind: Kind): boolean
		if kind == "faction" then
			local id = player:GetAttribute("Faction")
			return typeof(id) == "string" and id ~= ""
		elseif kind == "gang" then
			local id = player:GetAttribute("GangId")
			return typeof(id) == "string" and id ~= ""
		end
		return true
	end
	local function display(line: Line): string
		return if line.count > 1
			then line.text .. colored(" ×" .. line.count, MUTED)
			else line.text
	end
	local function inFeed(line: Line): boolean
		return line.kind == nil
			or line.kind == tab
			or (line.kind == "global" and current.globalFeed)
	end

	-- ── texts ───────────────────────────────────────────────────────────────────────────────────────────────────
	local function renderMarker()
		local parts = {}
		for _, kind in ipairs(Chat.KINDS) do
			local n = unread[kind] or 0
			if kind ~= tab and n > 0 and not (kind == "global" and current.globalFeed) then
				table.insert(parts, T("chat_tab_" .. kind) .. " +" .. n)
			end
		end
		marker.Text = table.concat(parts, "  ")
	end
	local function relabel()
		local visible = {}
		for _, kind in ipairs(Chat.KINDS) do
			local b = tabs[kind]
			local n = unread[kind] or 0
			b.Text = T("chat_tab_" .. kind)
				.. (if n > 0 then colored(" +" .. n, Ui.colors.yellow) else "")
			b.BackgroundColor3 = if kind == tab then Ui.colors.buttonBlue else Kit.GREY
			b.Visible = has(kind) or kind == tab
			if b.Visible then
				table.insert(visible, b)
			end
		end
		-- equal pills over the row (a narrow phone panel shrinks the text, Ui.button scales it)
		local rowW = panel.Size.X.Offset - PAD * 2 - (HEADER - 4) * 2 - 8
		local w = math.floor((math.max(120, rowW) - (#visible - 1) * 4) / math.max(1, #visible))
		for i, b in ipairs(visible) do
			b.Size = UDim2.fromOffset(w, HEADER - 4)
			b.Position = UDim2.fromOffset((i - 1) * (w + 4), 0)
		end
		input.PlaceholderText = if player:GetAttribute("ChatAllowed") == false
			then T("chat_placeholder_disabled")
			else T("chat_placeholder")
		newBelow.Text = T("chat_new")
		badge.Text = if unreadClosed > 99 then "99+" else tostring(unreadClosed)
		badge.Visible = unreadClosed > 0 and not opened
		renderMarker()
		-- the quick settings
		popTitle.Text = T("chat_settings")
		sizeCaption.Text = T("chat_size")
		sizeValue.Text = T("chat_size_" .. current.size)
		backCaption.Text = T("chat_back")
		for i, b in ipairs(backButtons) do
			b.Text = T("chat_back_" .. i)
			b.BackgroundColor3 = if current.back == i then Ui.colors.buttonGreen else Kit.GREY
		end
		buttonCaption.Text = T("chat_button_option")
		buttonToggle.Text = if current.button then T("settings_on") else T("settings_off")
		buttonToggle.BackgroundColor3 = if current.button then Ui.colors.buttonGreen else Kit.GREY
		offButton.Text = T("chat_turn_off")
		local mobile = isMobile()
		buttonRow.Visible = not mobile -- a phone always has the button
		offRow.Position = UDim2.fromOffset(8, 26 + (if mobile then 2 else 3) * POP_ROW)
		popover.Size = UDim2.fromOffset(POP_W, (if mobile then 3 else 4) * POP_ROW + 30)
	end

	-- ── the history (open panel) ────────────────────────────────────────────────────────────────────────────────
	local function textSize(): number
		local r = layoutNow
		return if r then r.textSize else LAYOUT.textSize
	end
	local function atBottom(): boolean
		return log.CanvasPosition.Y >= log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y - 8
	end
	local function scrollDown()
		task.defer(function()
			log.CanvasPosition =
				Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y))
			newBelow.Visible = false
		end)
	end
	local function drawHistory(line: Line)
		order += 1
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -6, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = Kit.TEXT
		label.TextSize = textSize()
		label.TextColor3 = Ui.colors.white
		label.TextStrokeTransparency = 0.7
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.RichText = true
		label.Text = display(line)
		label.LayoutOrder = order
		label.Parent = log
		labels[line] = label
		local user = line.user
		if user and not line.own then
			-- the sender's card (этап 9): only while he is on this server
			local cardHit = Instance.new("TextButton")
			cardHit.BackgroundTransparency = 1
			cardHit.Text = ""
			cardHit.Size = UDim2.fromScale(1, 1)
			cardHit.Parent = label
			cardHit.Activated:Connect(function()
				if Players:GetPlayerByUserId(user) then
					require(script.Parent.PlayerListWindow).focusUser = user
					api.open("players")
				end
			end)
		end
		local count = 0
		local oldest: TextLabel? = nil
		local oldestLine: Line? = nil
		for l, lab in pairs(labels) do
			count += 1
			if not oldest or lab.LayoutOrder < oldest.LayoutOrder then
				oldest, oldestLine = lab, l
			end
		end
		if count > cfg.history and oldest and oldestLine then -- the oldest line goes
			oldest:Destroy()
			labels[oldestLine] = nil
		end
	end
	local function redrawHistory()
		for _, label in pairs(labels) do
			label:Destroy()
		end
		table.clear(labels)
		local picked = {}
		for i = #lines, 1, -1 do
			local line = lines[i]
			if line.kind == nil or line.kind == tab then
				table.insert(picked, 1, line)
				if #picked >= cfg.history then
					break
				end
			end
		end
		for _, line in ipairs(picked) do
			drawHistory(line)
		end
		scrollDown()
	end

	-- ── the feed (closed) ───────────────────────────────────────────────────────────────────────────────────────
	local function backing(): number
		return (cfg.feedBacks :: { number })[current.back] or 0.55
	end
	local function feedRow(text: string, at: number?): FeedItem
		order += 1
		local r = layoutNow
		local width = if r then r.feedWidth else 400
		local row = Instance.new("Frame")
		row.Name = "Line"
		row.BackgroundColor3 = Color3.new(0, 0, 0)
		row.BackgroundTransparency = backing()
		row.BorderSizePixel = 0
		row.AutomaticSize = Enum.AutomaticSize.XY
		row.Size = UDim2.new()
		row.LayoutOrder = order
		row.Active = false
		Kit.corner(row, 3)
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 5), UDim.new(0, 5)
		pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 1), UDim.new(0, 2)
		pad.Parent = row
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.AutomaticSize = Enum.AutomaticSize.XY
		label.Size = UDim2.new()
		label.Font = Kit.TEXT
		label.TextSize = textSize()
		label.TextColor3 = Ui.colors.white
		label.TextStrokeColor3 = Color3.new(0, 0, 0)
		label.TextStrokeTransparency = if backing() >= 1 then 0.2 else 0.6
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.RichText = true
		label.Text = text
		label.Active = false
		label.Parent = row
		local limit = Instance.new("UISizeConstraint")
		limit.MaxSize = Vector2.new(math.max(40, width - 10), math.huge)
		limit.Parent = label
		row.Parent = feed
		local item = {
			line = { kind = nil, text = text, own = false, count = 1, at = at or os.clock() },
			row = row,
			label = label,
		}
		return item
	end
	local function clearFeed()
		for _, item in ipairs(items) do
			item.row:Destroy()
		end
		table.clear(items)
	end
	local function trimFeed()
		local r = layoutNow
		local max = if r then r.feedLines else cfg.feedLines
		while #items > max do
			table.remove(items, 1).row:Destroy()
		end
	end
	local function pushFeed(line: Line)
		local item = feedRow(display(line), line.at)
		item.line = line
		table.insert(items, item)
		trimFeed()
	end
	local function fadeWindow(): number
		return cfg.fadeSeconds + cfg.fadeOutSeconds
	end
	-- the feed again from the recent lines (after closing, a tab change, a setting): only what is still fresh
	local function rebuildFeed()
		clearFeed()
		if sampling then
			for i, text in ipairs({
				colored(T("layout_chat"), Ui.colors.header),
				"<b>"
					.. Chat.escape(player.DisplayName)
					.. "</b>"
					.. colored(" » ", MUTED)
					.. "…",
			}) do
				local item = feedRow(text, math.huge)
				item.row.LayoutOrder = i
				table.insert(items, item)
			end
			return
		end
		local now = os.clock()
		local r = layoutNow
		local max = if r then r.feedLines else cfg.feedLines
		local picked = {}
		for i = #lines, 1, -1 do
			local line = lines[i]
			if current.fade ~= 2 and now - line.at > fadeWindow() then
				break
			end
			if inFeed(line) then
				table.insert(picked, 1, line)
				if #picked >= max then
					break
				end
			end
		end
		for _, line in ipairs(picked) do
			pushFeed(line)
		end
	end

	-- ── adding lines ────────────────────────────────────────────────────────────────────────────────────────────
	local function add(kind: Kind?, text: string, own: boolean?, user: number?, key: string?)
		local now = os.clock()
		local last = lines[#lines]
		if key and last and last.key == key then -- the same line again from the same sender: «×N»
			last.count += 1
			last.at = now
			local label = labels[last]
			if label then
				label.Text = display(last)
			end
			local found = false
			for _, item in ipairs(items) do
				if item.line == last then
					item.label.Text = display(last)
					found = true
				end
			end
			if not found and not opened and inFeed(last) and not sampling then
				pushFeed(last)
			end
			return
		end
		local line: Line = {
			kind = kind,
			text = text,
			own = own == true,
			user = user,
			key = key,
			count = 1,
			at = now,
		}
		table.insert(lines, line)
		if #lines > cfg.history * 4 then
			table.remove(lines, 1)
		end
		if kind == nil or kind == tab then
			local follow = atBottom()
			drawHistory(line)
			if follow or own then
				scrollDown()
			elseif opened then
				newBelow.Visible = true
			end
		elseif not own and kind then
			unread[kind] = (unread[kind] or 0) + 1
		end
		if inFeed(line) then
			if not sampling then
				pushFeed(line)
			end
		elseif not own then
			markerAt = now
		end
		if not opened and not own and kind ~= nil then
			unreadClosed += 1
		end
		relabel()
	end
	local function system(text: string, kind: string?)
		local color = SYSTEM_COLORS[kind or "reply"] or REPLY
		add(
			nil,
			colored(Chat.escape(text), color),
			false,
			nil,
			"sys:" .. (kind or "reply") .. ":" .. text
		)
	end
	-- announcements: one line per announceGapSeconds, the same text never twice in the queue
	local queue: { string } = {}
	local pumping = false
	local lastAnnounce = -math.huge
	local function say(text: string, kind: string?)
		if kind ~= "announce" then
			system(text, kind)
			return
		end
		if table.find(queue, text) then
			return
		end
		table.insert(queue, text)
		if #queue > 10 then
			table.remove(queue, 1)
		end
		if pumping then
			return
		end
		pumping = true
		task.spawn(function()
			while #queue > 0 do
				local wait = lastAnnounce + cfg.announceGapSeconds - os.clock()
				if wait > 0 then
					task.wait(wait)
				end
				local nextText = table.remove(queue, 1)
				if nextText then
					lastAnnounce = os.clock()
					system(nextText, "announce")
				end
			end
			pumping = false
		end)
	end

	-- «[G] [PRIS+] [TAG] Ник [48 ур.] Кличка » текст» [вики MENUS-SOCIAL: «[G] [PRIS+] <донат> | <ник> …»]
	local function playerLine(
		kind: Kind,
		info: {
			name: string,
			level: number?,
			faction: string?,
			tag: string?,
			color: number?,
			nick: string?,
			pris: boolean?,
		},
		text: string
	): string
		local parts = {}
		if kind == "global" then
			table.insert(parts, colored("[" .. T("chat_tag_global") .. "]", GLOBAL))
		elseif kind == "faction" then
			table.insert(
				parts,
				colored("[" .. T("chat_tag_faction") .. "]", Config.factionColor(info.faction))
			)
		end
		if info.pris then
			table.insert(parts, colored("<b>" .. T("pris_tag") .. "</b>", PRIS))
		end
		if info.tag and info.tag ~= "" then
			table.insert(
				parts,
				colored("[" .. Chat.escape(info.tag) .. "]", Gangs.color(info.color))
			)
		end
		table.insert(parts, "<b>" .. Chat.escape(info.name) .. "</b>")
		if info.level then
			local levelColor = if info.faction and info.faction ~= ""
				then Config.factionColor(info.faction)
				else MUTED
			table.insert(parts, colored("[" .. T("chat_level", info.level) .. "]", levelColor))
		end
		if info.nick and info.nick ~= "" then
			table.insert(parts, colored(Chat.escape(info.nick), NICK))
		end
		return table.concat(parts, " ") .. colored(" » ", MUTED) .. Chat.escape(text)
	end
	local function infoOf(userId: number, fallback: string)
		local who = Players:GetPlayerByUserId(userId)
		if not who then
			return { name = fallback }
		end
		local level = who:GetAttribute("Level")
		local faction = who:GetAttribute("Faction")
		local tag = who:GetAttribute("GangTag")
		local color = who:GetAttribute("GangColor")
		local nick = who:GetAttribute("Nick")
		return {
			name = who.DisplayName,
			level = if typeof(level) == "number" then level else nil,
			faction = if typeof(faction) == "string" then faction else nil,
			tag = if typeof(tag) == "string" then tag else nil,
			color = if typeof(color) == "number" then color else nil,
			nick = if typeof(nick) == "string" then nick else nil,
			pris = PrisPlus.of(who),
		}
	end
	local function playerKey(kind: Kind, user: number, text: string): string
		return kind .. ":" .. user .. ":" .. text
	end

	-- ── layout ──────────────────────────────────────────────────────────────────────────────────────────────────
	local function viewport(): Vector2
		local camera = workspace.CurrentCamera
		return if camera then camera.ViewportSize else Vector2.new(900, 560)
	end
	local function liveHud(
		w: number,
		h: number,
		touch: boolean,
		inset: number
	): { [string]: ChatLayout.Rect }
		-- the joystick, the crosshair, the centre and the top bar come from the formulas (Roblox's thumbstick has
		-- no fixed frame); everything else from the real objects
		local model = ChatLayout.model(w, h, touch, inset, "", 0)
		local hud: { [string]: ChatLayout.Rect } = {
			topbar = model.topbar,
			joystick = model.joystick,
			crosshair = model.crosshair,
			centre = model.centre,
		}
		for name, object in pairs(hudObjects) do
			if object.Parent then
				local r = rectOf(object, name == "hotbar")
				if r then
					hud[name] = r
				end
			end
		end
		if not touch then -- the touch-only pieces are hidden anyway; the phone menu does not exist on a computer
			hud.touchMenu, hud.joystick, hud.crosshair = nil, nil, nil
		end
		return hud
	end
	local function inputFor(
		w: number,
		h: number,
		touch: boolean,
		inset: number,
		hud: { [string]: ChatLayout.Rect },
		moved: Vector2?
	): ChatLayout.Input
		return {
			w = w,
			h = h,
			touch = touch,
			inset = inset,
			hud = hud,
			setting = (cfg.sizes :: { number })[current.size] or 1,
			user = HudLayout.sizeNow("chat"),
			lines = if touch then cfg.phoneFeedLines else cfg.feedLines,
			button = touch or current.button,
			moved = moved,
		}
	end
	local function fadeHints(on: boolean)
		local hints = hudObjects.hints
		if on == hintsFaded or not hints or not hints:IsA("TextLabel") then
			return
		end
		hintsFaded = on
		TweenService:Create(hints, FADE_HINTS, { TextTransparency = if on then 1 else 0 }):Play()
	end
	local function layout()
		if HudLayout.isEditing() then
			return -- the editor owns the holder's place and size until «Готово»
		end
		local size = viewport()
		local touch = isMobile()
		local inset = GuiService:GetGuiInset().Y
		local moved: Vector2? = nil
		if HudLayout.moved("chat") then
			local p = holder.Position
			moved = Vector2.new(p.X.Scale * size.X + p.X.Offset, p.Y.Scale * size.Y + p.Y.Offset)
		end
		local r = ChatLayout.compute(
			inputFor(size.X, size.Y, touch, inset, liveHud(size.X, size.Y, touch, inset), moved)
		)
		local before = layoutNow
		layoutNow = r
		holder.AnchorPoint = r.anchor
		if not moved then
			holder.Position = UDim2.fromOffset(r.at.X, r.at.Y)
			HudLayout.setDefault(holder)
		end
		HudLayout.setBaseScale(holder, r.scale * ((cfg.sizes :: { number })[current.size] or 1))
		holderScale.Scale = r.k
		holder.Size = UDim2.fromOffset(r.holderSize.X, r.holderSize.Y)
		local lineArea = r.feedLines * r.lineH
		if touch then
			local b = LAYOUT.phone.button
			button.Size = UDim2.fromOffset(b, b)
			button.AnchorPoint = Vector2.new(0, 0)
			button.Position = UDim2.new()
			buttonCorner.CornerRadius = UDim.new(1, 0)
			feed.Position = UDim2.fromOffset(0, b + 6)
			feed.Size = UDim2.fromOffset(r.feedWidth, lineArea)
			feedList.VerticalAlignment = Enum.VerticalAlignment.Top
			marker.Visible = false
		else
			local b = LAYOUT.button
			button.Size = UDim2.fromOffset(b, b)
			button.AnchorPoint = Vector2.new(0, 1)
			button.Position = UDim2.fromScale(0, 1)
			buttonCorner.CornerRadius = UDim.new(0, 6)
			feed.Position = UDim2.new()
			feed.Size = UDim2.fromOffset(r.feedWidth, lineArea + MARKER_H)
			feedList.VerticalAlignment = Enum.VerticalAlignment.Bottom
		end
		panel.Position = UDim2.fromOffset(r.panel.x, r.panel.y)
		panelScale.Scale = r.k
		panel.Size = UDim2.fromOffset(r.panelSize.X, r.panelSize.Y)
		fadeHints(opened and r.fadeHints)
		if
			not before
			or before.textSize ~= r.textSize
			or before.feedWidth ~= r.feedWidth
			or before.feedLines ~= r.feedLines
		then
			rebuildFeed()
			for _, label in pairs(labels) do
				label.TextSize = r.textSize
			end
		end
		trimFeed()
		relabel()
	end
	local layoutQueued = false
	requestLayout = function()
		if layoutQueued then
			return
		end
		layoutQueued = true
		task.defer(function()
			layoutQueued = false
			layout()
		end)
	end
	HudLayout.register("chat", holder, true, true)
	HudLayout.onApplied(requestLayout)

	-- ── open / close ────────────────────────────────────────────────────────────────────────────────────────────
	local function setOpen(value: boolean)
		if value and (current.off or HudLayout.isEditing()) then
			return
		end
		if value == opened then
			return
		end
		opened = value
		panel.Visible = opened
		catcher.Visible = opened
		popover.Visible = false
		if opened then
			openedAt = os.clock()
			unreadClosed = 0
			unread[tab] = 0
			prevMouseIcon = UserInputService.MouseIconEnabled
			UserInputService.MouseIconEnabled = true
			clearFeed()
			scrollDown()
		else
			input:ReleaseFocus()
			if prevMouseIcon ~= nil then
				UserInputService.MouseIconEnabled = prevMouseIcon
				prevMouseIcon = nil
			end
			newBelow.Visible = false
			rebuildFeed()
		end
		local r = layoutNow
		fadeHints(opened and r ~= nil and r.fadeHints)
		relabel()
	end
	local function selectTab(kind: Kind)
		tab = kind
		unread[kind] = 0
		relabel()
		redrawHistory()
		if not isMobile() then
			input:CaptureFocus()
		end
	end
	for kind, b in pairs(tabs) do
		b.Activated:Connect(function()
			selectTab(kind)
		end)
	end
	closeButton.Activated:Connect(function()
		setOpen(false)
	end)
	hit.Activated:Connect(function()
		setOpen(not opened)
	end)
	catcher.InputBegan:Connect(function(press: InputObject)
		if
			press.UserInputType == Enum.UserInputType.MouseButton1
			or press.UserInputType == Enum.UserInputType.Touch
		then
			setOpen(false)
		end
	end)
	newBelow.Activated:Connect(scrollDown)
	log:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		if newBelow.Visible and atBottom() then
			newBelow.Visible = false
		end
	end)

	-- ── settings from here (the gear) ───────────────────────────────────────────────────────────────────────────
	local applySettings: () -> () = function() end
	local function change(key: string, value: any)
		pending[key] = { value = value, untilAt = os.clock() + 3 }
		Remotes.event("SetSetting"):FireServer(key, value)
		applySettings()
	end
	gearButton.Activated:Connect(function()
		popover.Visible = not popover.Visible
	end)
	sizeDown.Activated:Connect(function()
		change("chatSize", math.max(1, current.size - 1))
	end)
	sizeUp.Activated:Connect(function()
		change("chatSize", math.min(3, current.size + 1))
	end)
	for i, b in ipairs(backButtons) do
		b.Activated:Connect(function()
			change("chatBack", i)
		end)
	end
	buttonToggle.Activated:Connect(function()
		change("chatButton", not current.button)
	end)
	offButton.Activated:Connect(function()
		change("chatOff", true)
		api.toast(T("chat_off_toast"))
	end)

	-- ── sending ─────────────────────────────────────────────────────────────────────────────────────────────────
	local function channelOf(kind: Kind): (TextChannel?, string?)
		if kind == "local" then
			local folder = TextChatService:FindFirstChild("TextChannels")
			local general = folder and folder:FindFirstChild(Chat.GENERAL)
			return if general and general:IsA("TextChannel") then general else nil, "chat_not_ready"
		end
		local attribute = if kind == "faction" then "Faction" else "GangId"
		local id = player:GetAttribute(attribute)
		if typeof(id) ~= "string" or id == "" then
			return nil, if kind == "faction" then "chat_no_faction" else "chat_no_gang"
		end
		local folder = TextChatService:FindFirstChild(Chat.FOLDER)
		local name = if kind == "faction" then Chat.factionChannel(id) else Chat.gangChannel(id)
		local channel = folder and folder:FindFirstChild(name)
		return if channel and channel:IsA("TextChannel") then channel else nil, "chat_not_ready"
	end

	local hideState = { on = false, pendingUntil = 0 } -- a /hide the profile has not caught up with yet
	local commands: ChatCommands.Context = {
		open = api.open,
		profile = api.profile,
		locale = function()
			return locale
		end,
		say = say,
		toggleHide = function(): boolean
			hideState.on = not hideState.on
			hideState.pendingUntil = os.clock() + 3
			HidePlayers.set(hideState.on)
			Remotes.event("SetSetting"):FireServer("hidePlayers", hideState.on)
			return hideState.on
		end,
	}

	local function send(raw: string)
		local text = Chat.clean(raw)
		if text == "" then
			return
		end
		if text:sub(1, 1) == "/" then
			ChatCommands.run(text, commands)
			return
		end
		if player:GetAttribute("ChatAllowed") == false then
			say(T("chat_unavailable"), "error")
			return
		end
		local kind, body = Chat.route(text, tab)
		if body == "" then
			return
		end
		if kind == "global" then
			Remotes.event("ChatGlobal"):FireServer(body)
			return
		end
		local channel, problem = channelOf(kind)
		if not channel then
			say(T(problem or "chat_send_failed"), "error")
			return
		end
		task.spawn(function()
			local ok, message = pcall(function()
				return channel:SendAsync(body)
			end)
			if
				not ok
				or (
					message
					and message.Status ~= Enum.TextChatMessageStatus.Success
					and message.Status ~= Enum.TextChatMessageStatus.Sending
				)
			then
				say(T("chat_send_failed"), "error")
			end
		end)
	end
	local function submit()
		local text = input.Text
		input.Text = ""
		if Chat.clean(text) == "" then
			if os.clock() - openedAt < 0.25 then -- the Enter that opened the chat reached the box: keep it open
				task.defer(function()
					input:CaptureFocus()
				end)
				return
			end
			setOpen(false) -- Enter on an empty line closes
			return
		end
		send(text)
		if not isMobile() then
			setOpen(false) -- a computer closes after sending (Minecraft); a phone stays for the next line
		end
	end
	input.FocusLost:Connect(function(enterPressed: boolean, cause: InputObject?)
		if enterPressed then
			submit()
		elseif cause and cause.KeyCode == Enum.KeyCode.Escape then
			setOpen(false)
		end
	end)
	sendButton.Activated:Connect(submit)
	UserInputService.InputBegan:Connect(function(key: InputObject, processed: boolean)
		local code = key.KeyCode
		if code == Enum.KeyCode.Escape then
			if opened then -- also while typing (then Roblox marks it processed)
				setOpen(false)
			end
			return
		end
		if
			processed
			or UserInputService:GetFocusedTextBox()
			or current.off
			or HudLayout.isEditing()
		then
			return
		end
		if code == Enum.KeyCode.DPadUp then -- a gamepad: no other binding uses it
			setOpen(not opened)
			return
		end
		if
			code == Enum.KeyCode.Return
			or code == Enum.KeyCode.KeypadEnter
			or code == Enum.KeyCode.Slash
		then
			setOpen(true)
			-- a frame later: the key that opened the chat is not typed into the line
			task.defer(function()
				input:CaptureFocus()
				task.defer(function()
					if input.Text == "/" then
						input.Text = ""
					end
				end)
			end)
		end
	end)

	-- ── receiving ───────────────────────────────────────────────────────────────────────────────────────────────
	TextChatService.MessageReceived:Connect(function(message: TextChatMessage)
		local channel = message.TextChannel
		if not channel then
			return
		end
		if channel.Name == "RBXSystem" then -- Roblox's own notices (too fast, not sent …)
			if message.Text ~= "" then
				add(nil, colored(message.Text, REPLY), false, nil, "rbx:" .. message.Text)
			end
			return
		end
		local kind = Chat.kindOfChannel(channel.Name)
		local source = message.TextSource
		if not kind or not source or message.Text == "" then
			return
		end
		add(
			kind,
			playerLine(kind, infoOf(source.UserId, source.Name), message.Text),
			source.UserId == player.UserId,
			source.UserId,
			playerKey(kind, source.UserId, message.Text)
		)
		-- the bubble over the head: Общий only, not over hidden players
		local who = Players:GetPlayerByUserId(source.UserId)
		if
			kind == "local"
			and who
			and current.bubbles
			and not current.off
			and not HidePlayers.isHidden()
			and not HidePlayers.isPlayerHidden(source.UserId)
		then
			ChatBubbles.show(who, Chat.escape(message.Text))
		end
	end)
	Remotes.event("ChatGlobal").OnClientEvent:Connect(function(data: any)
		if
			typeof(data) ~= "table"
			or typeof(data.u) ~= "number"
			or typeof(data.t) ~= "string"
			or typeof(data.n) ~= "string"
			or blocked[data.u]
		then
			return
		end
		add(
			"global",
			playerLine("global", {
				name = data.n,
				level = if typeof(data.l) == "number" then data.l else nil,
				faction = if typeof(data.f) == "string" then data.f else nil,
				tag = if typeof(data.g) == "string" then data.g else nil,
				color = if typeof(data.c) == "number" then data.c else nil,
				nick = if typeof(data.k) == "string" then data.k else nil,
				pris = data.p == 1,
			}, data.t),
			data.u == player.UserId,
			data.u,
			playerKey("global", data.u, data.t)
		)
	end)
	Remotes.event("ChatSystem").OnClientEvent:Connect(function(text: any, kind: any)
		if typeof(text) == "string" then
			say(text, if typeof(kind) == "string" then kind else nil)
		end
	end)
	player:GetAttributeChangedSignal("ChatAllowed"):Connect(function()
		relabel()
		if player:GetAttribute("ChatAllowed") == false then
			say(T("chat_unavailable"), "error")
		end
	end)
	local function membershipChanged()
		if not has(tab) then
			tab = "local"
			redrawHistory()
			rebuildFeed()
		end
		relabel()
	end
	player:GetAttributeChangedSignal("Faction"):Connect(membershipChanged)
	player:GetAttributeChangedSignal("GangId"):Connect(membershipChanged)

	-- ── the settings applied ────────────────────────────────────────────────────────────────────────────────────
	local function signature(v: View): string
		return table.concat({
			v.size,
			v.back,
			v.fade,
			tostring(v.bubbles),
			tostring(v.globalFeed),
			tostring(v.off),
			tostring(v.button),
		}, ",")
	end
	applySettings = function()
		local before = current
		current = view()
		if signature(before) == signature(current) then
			return
		end
		if current.off and opened then
			setOpen(false)
		end
		if not current.bubbles and before.bubbles then
			ChatBubbles.clear()
		end
		layoutNow = nil -- the size or the button may have changed: everything is drawn again
		layout()
		rebuildFeed()
		relabel()
	end

	-- ── every frame: the fade, what is on the screen ────────────────────────────────────────────────────────────
	local tickAt = 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - tickAt < 1 / 20 then
			return
		end
		tickAt = now
		local editing = HudLayout.isEditing()
		if editing ~= sampling then -- the HUD editor opened / closed: a sample feed while the chat is placed
			sampling = editing
			if editing then
				setOpen(false)
			end
			rebuildFeed()
			if not editing then
				requestLayout()
			end
		end
		local windowNow = windowOpen()
		if windowNow and not windowWasOpen and opened then -- one of our windows opened: the chat gives way
			setOpen(false)
		end
		windowWasOpen = windowNow
		local hidden = current.off or (windowNow and not editing)
		holder.Visible = not hidden
		local mobile = isMobile()
		-- the phone button stays beside the open panel (it closes it too); the optional one on a computer sits under it
		button.Visible = editing or (not hidden and (mobile or (current.button and not opened)))
		hit.Visible = not editing
		feed.Visible = editing or (not opened and current.fade ~= 3)
		badge.Visible = unreadClosed > 0 and not opened
		-- fade: the newest lines stay fadeSeconds, then fade out over fadeOutSeconds; faded ones leave the feed
		local back = backing()
		local stroke = if back >= 1 then 0.2 else 0.6
		local i = 1
		while i <= #items do
			local item = items[i]
			local a = 0
			if not editing and current.fade == 1 then
				a = math.clamp((now - item.line.at - cfg.fadeSeconds) / cfg.fadeOutSeconds, 0, 1)
			end
			if a >= 1 then
				item.row:Destroy()
				table.remove(items, i)
			else
				item.row.BackgroundTransparency = back + (1 - back) * a
				item.label.TextTransparency = a
				item.label.TextStrokeTransparency = stroke + (1 - stroke) * a
				i += 1
			end
		end
		-- a wrapped line may need more room than the feed has: the oldest go
		while #items > 1 and feedList.AbsoluteContentSize.Y > feed.AbsoluteSize.Y + 2 do
			table.remove(items, 1).row:Destroy()
		end
		-- «+N» over the desktop feed: what the other tabs got, fading like a line
		if not mobile then
			local ma = if current.fade == 2
				then 0
				else math.clamp((now - markerAt - cfg.fadeSeconds) / cfg.fadeOutSeconds, 0, 1)
			marker.Visible = marker.Text ~= ""
				and ma < 1
				and not opened
				and current.fade ~= 3
				and not editing
			marker.TextTransparency = ma
			marker.BackgroundTransparency = 0.55 + 0.45 * ma
		end
	end)

	-- ── tips, the language, the settings, blocks ────────────────────────────────────────────────────────────────
	local tipCount = 0
	while Strings.has("chat_tip_" .. (tipCount + 1)) do
		tipCount += 1
	end
	task.spawn(function()
		task.wait(cfg.tipsFirstMinutes * 60)
		local deck: { number } = {}
		while true do
			if tipCount > 0 and current.tips then
				if #deck == 0 then -- every tip once, in a new order each round
					for i = 1, tipCount do
						table.insert(deck, math.random(1, #deck + 1), i)
					end
				end
				local i = table.remove(deck) :: number
				add(
					nil,
					colored(T("chat_tip"), TIP)
						.. " "
						.. colored(Chat.escape(T("chat_tip_" .. i)), REPLY)
				)
			end
			task.wait(cfg.tipsMinutes * 60)
		end
	end)
	task.spawn(function()
		while true do
			local nextLocale = api.locale()
			if nextLocale ~= locale then
				locale = nextLocale
				relabel()
			end
			local profile = api.profile()
			local hide = profile ~= nil
				and profile.settings ~= nil
				and profile.settings.hidePlayers == true
			if profile and hide ~= hideState.on and os.clock() > hideState.pendingUntil then -- the settings switch, or the saved state after a rejoin
				hideState.on = hide
				HidePlayers.set(hide)
				if hide then
					ChatBubbles.clear()
				end
			end
			applySettings() -- the settings window or a rejoin changed them
			task.wait(0.5)
		end
	end)
	task.spawn(function()
		while true do -- the players this account blocked never show in the global chat
			local ok, ids = pcall(function()
				return StarterGui:GetCore("GetBlockedUserIds")
			end)
			if ok and typeof(ids) == "table" then
				table.clear(blocked)
				for _, id in ipairs(ids) do
					if typeof(id) == "number" then
						blocked[id] = true
					end
				end
			end
			task.wait(30)
		end
	end)

	local function watchViewport()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(requestLayout)
		end
		requestLayout()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(requestLayout)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(requestLayout)
	workspace:GetAttributeChangedSignal("ForceMobile"):Connect(requestLayout)
	watchViewport()
	relabel()

	-- ── QA (Studio) ─────────────────────────────────────────────────────────────────────────────────────────────
	local function rectTable(r: ChatLayout.Rect?): { number }?
		return if r
			then { math.floor(r.x), math.floor(r.y), math.floor(r.w), math.floor(r.h) }
			else nil
	end
	local function describe(r: ChatLayout.Result, hud: { [string]: ChatLayout.Rect })
		local overlaps, soft = ChatLayout.check(r, hud)
		local hudOut = {}
		for name, q in pairs(hud) do
			hudOut[name] = rectTable(q)
		end
		return {
			scale = math.floor(r.scale * 1000) / 1000,
			k = math.floor(r.k * 1000) / 1000,
			feed = rectTable(r.feed),
			feedLines = r.feedLines,
			panel = rectTable(r.panel),
			button = rectTable(r.button),
			fadeHints = r.fadeHints,
			above = r.above,
			overlaps = overlaps,
			soft = soft,
			hud = hudOut,
		}
	end
	if RunService:IsStudio() then
		debugHandler = function(action: string, arg: any): any
			if action == "chatLayout" then
				local a = if typeof(arg) == "table" then arg else {}
				local w, h = tonumber(a[1] or a.w) or 1920, tonumber(a[2] or a.h) or 1080
				local touch = (a[3] or a.touch) == true
				local inset = tonumber(a.inset) or 58
				local hud =
					ChatLayout.model(w, h, touch, inset, T("keys_hint"), tonumber(a.rows) or 2)
				local r = ChatLayout.compute(inputFor(w, h, touch, inset, hud, nil))
				return describe(r, hud)
			elseif action == "chatLive" then
				local size = viewport()
				local touch = isMobile()
				local inset = GuiService:GetGuiInset().Y
				local hud = liveHud(size.X, size.Y, touch, inset)
				local r = ChatLayout.compute(inputFor(size.X, size.Y, touch, inset, hud, nil))
				local out = describe(r, hud)
				out.viewport = { size.X, size.Y }
				out.model = ChatLayout.model(size.X, size.Y, touch, inset, T("keys_hint"), 0)
				out.holder = rectTable(rectOf(holder, false))
				out.panelReal = rectTable(rectOf(panel, false))
				return out
			elseif action == "chatSpam" then
				local n = math.clamp(tonumber(arg) or 10, 1, 200)
				local me = infoOf(player.UserId, player.Name)
				for i = 1, n do
					local m = i % 6
					if m == 0 then
						say(
							"Тестовое объявление " .. math.floor(i / 6),
							"announce"
						)
					elseif m == 1 then
						add(
							"local",
							playerLine("local", me, "одинаковая строка"),
							false,
							1,
							playerKey("local", 1, "same")
						)
					elseif m == 2 then
						add(
							"global",
							playerLine(
								"global",
								{ name = "Глобал", level = 12 },
								"строка " .. i
							),
							false,
							2,
							nil
						)
					elseif m == 3 then
						add(
							"faction",
							playerLine(
								"faction",
								{ name = "Фракционер", level = 30 },
								"строка " .. i
							),
							false,
							3,
							nil
						)
					else
						add(
							"local",
							playerLine(
								"local",
								me,
								"тестовая строка "
									.. i
									.. " — длинная, чтобы проверить перенос текста в ленте чата"
							),
							false,
							1,
							nil
						)
					end
				end
				return #lines
			elseif action == "chatOpen" then
				setOpen(arg == true)
				return opened
			elseif action == "chatState" then
				return {
					opened = opened,
					tab = tab,
					lines = #lines,
					feedItems = #items,
					settings = signature(current),
					holderVisible = holder.Visible,
					buttonVisible = button.Visible,
					feedVisible = feed.Visible,
					hintsFaded = hintsFaded,
				}
			end
			return nil
		end
	end
end

return ChatWindow
