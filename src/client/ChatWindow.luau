--!strict
-- The chat window (этап 3) [владелец 28.10: «у нас вообще никакого чата нет»; вики MENUS-SOCIAL: мульти-чат слева
-- внизу, вкладки с «+2»]. Our own dark panel replaces Roblox's chat window and input bar (both switched off here),
-- bottom left on a computer (always there, «–» folds it into the «Чат» button), behind the «Чат» button under the
-- menu button on a phone. Tabs Общий / Глобальный / Фракция / Банда; a tab shows its channel plus the system lines
-- (announcements, command answers, «[Совет]»), the other tabs count what arrived as «+N».
--   * Sending: «/…» = a command (ChatCommands); otherwise Chat.route — a «!» / «@» / «#» prefix wins over the open
--     tab. Общий, Фракция, Банда go through TextChatService (TextChannel:SendAsync: Roblox filters it for every
--     receiver); Глобальный through ChatGlobal (ChatService filters it and sends it to every server).
--   * Receiving: TextChatService.MessageReceived (text already filtered for this player), ChatGlobal, ChatSystem.
--     Everything is drawn as RichText with the player's part escaped (Chat.escape).
--   * Line format [вики MENUS-SOCIAL]: «[G] [TAG] Ник [48 ур.] Кличка » текст» — the level in the faction colour, the
--     gang tag in the gang colour.
--   * An account Roblox does not let chat (attribute ChatAllowed = false) still sees the announcements and may type
--     commands; the input says so.
--   * «[Совет]» every Config.chat.tipsMinutes (chat_tip_1…N in Strings), off in the settings (settings.tipsOff).
-- Keys: Enter or «/» focus the input (H stays the HUD editor; /hide hides the players instead of the original's H).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)
local ChatCommands = require(script.Parent.ChatCommands)
local HidePlayers = require(script.Parent.HidePlayers)

export type Api = {
	open: (kind: string) -> (), -- one of our windows (init.client windowBuilders)
	profile: () -> Types.Profile?,
	locale: () -> string,
	toast: (text: string) -> (),
}

type Kind = Chat.Kind
type Line = { kind: Kind?, text: string, own: boolean } -- kind nil = a system line, shown in every tab

local ChatWindow = {}

local cfg = Config.chat
local player = Players.LocalPlayer
local TAB_H, INPUT_H, PAD = 26, 30, 6
local GLOBAL = Color3.fromRGB(85, 220, 255)
local NICK = Color3.fromRGB(255, 200, 80)
local MUTED = Color3.fromRGB(150, 150, 165)
local REPLY = Color3.fromRGB(205, 205, 215)
local TIP = Color3.fromRGB(110, 225, 130)
local SYSTEM_COLORS: { [string]: Color3 } = {
	announce = Ui.colors.header,
	reply = REPLY,
	error = Kit.BAD,
}

local function isMobile(): boolean
	if RunService:IsStudio() and workspace:GetAttribute("ForceMobile") == true then
		return true
	end
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

local function colored(text: string, color: Color3): string
	return '<font color="' .. Ui.hex(color) .. '">' .. text .. "</font>"
end

function ChatWindow.start(api: Api)
	local locale = api.locale()
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end

	-- Roblox's own window and input bar give way to ours (the bubbles over the heads stay)
	pcall(function()
		TextChatService.ChatWindowConfiguration.Enabled = false
		TextChatService.ChatInputBarConfiguration.Enabled = false
	end)

	local gui = Instance.new("ScreenGui")
	gui.Name = "ChatGui"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = -1 -- under the windows of PrisonHud
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Kit.frame(gui, UDim2.fromOffset(420, 220), UDim2.new(), Kit.CARD)
	panel.Name = "Chat"
	panel.BackgroundTransparency = 0.3
	Kit.corner(panel, 8)
	Kit.stroke(panel, Kit.EDGE, 1, 0.4)

	local button = Ui.button(gui, "", UDim2.fromOffset(56, 56), UDim2.new(), Ui.colors.buttonGrey)
	button.Name = "ChatButton"
	button.BackgroundTransparency = 0.35
	button.TextSize = 14
	Kit.corner(button, 8)

	-- the tabs and the fold button
	local tabs: { [Kind]: TextButton } = {}
	local fold = Ui.button(panel, "–", UDim2.fromOffset(TAB_H, TAB_H - 4), UDim2.new(), Kit.GREY)
	fold.Name = "Fold"
	fold.TextSize = 16
	Kit.corner(fold, 5)
	for _, kind in ipairs(Chat.KINDS) do
		local tab = Ui.button(panel, "", UDim2.fromOffset(80, TAB_H - 4), UDim2.new(), Kit.GREY)
		tab.Name = "Tab_" .. kind
		tab.TextScaled = true -- «Глобальный» on a narrow phone panel
		tab.Font = Kit.BOLD
		tab.RichText = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 13
		limit.Parent = tab
		Kit.corner(tab, 5)
		tabs[kind] = tab
	end

	local log = Instance.new("ScrollingFrame")
	log.Name = "Log"
	log.BackgroundTransparency = 1
	log.BorderSizePixel = 0
	log.ScrollBarThickness = 4
	log.ScrollBarImageColor3 = Kit.EDGE
	log.AutomaticCanvasSize = Enum.AutomaticSize.Y
	log.CanvasSize = UDim2.new()
	log.ScrollingDirection = Enum.ScrollingDirection.Y
	log.Parent = panel
	local list = Instance.new("UIListLayout")
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Padding = UDim.new(0, 2)
	list.Parent = log

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
	input.Parent = panel
	Kit.corner(input, 5)
	local inputPad = Instance.new("UIPadding")
	inputPad.PaddingLeft = UDim.new(0, 6)
	inputPad.PaddingRight = UDim.new(0, 6)
	inputPad.Parent = input
	local sendButton = Ui.button(
		panel,
		"»",
		UDim2.fromOffset(INPUT_H + 6, INPUT_H),
		UDim2.new(),
		Ui.colors.buttonBlue
	)
	sendButton.Name = "Send"
	sendButton.TextSize = 18
	Kit.corner(sendButton, 5)

	-- ── state ───────────────────────────────────────────────────────────────────────────────────────────────────
	local tab: Kind = "local"
	local lines: { Line } = {}
	local unread: { [Kind]: number } = {}
	local unreadClosed = 0
	local opened = not isMobile()
	local order = 0
	local blocked: { [number]: boolean } = {}

	local function relabel()
		for kind, b in pairs(tabs) do
			local n = unread[kind] or 0
			b.Text = T("chat_tab_" .. kind)
				.. (if n > 0 then colored(" +" .. n, Ui.colors.yellow) else "")
			b.BackgroundColor3 = if kind == tab then Ui.colors.buttonBlue else Kit.GREY
		end
		button.Text = T("chat_button")
			.. (
				if unreadClosed > 0
					then (if isMobile() then "\n+" else " +") .. unreadClosed
					else ""
			)
		input.PlaceholderText = if player:GetAttribute("ChatAllowed") == false
			then T("chat_placeholder_disabled")
			else T("chat_placeholder")
	end

	local function atBottom(): boolean
		return log.CanvasPosition.Y >= log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y - 8
	end
	local function scrollDown()
		task.defer(function()
			log.CanvasPosition =
				Vector2.new(0, math.max(0, log.AbsoluteCanvasSize.Y - log.AbsoluteWindowSize.Y))
		end)
	end
	local function drawLine(line: Line)
		order += 1
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.new(1, -8, 0, 0)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.Font = Kit.TEXT
		label.TextSize = if isMobile() then 13 else 14
		label.TextColor3 = Ui.colors.white
		label.TextStrokeTransparency = 0.7
		label.TextWrapped = true
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.RichText = true
		label.Text = line.text
		label.LayoutOrder = order
		label.Parent = log
		local shown = 0
		for _, child in ipairs(log:GetChildren()) do
			if child:IsA("TextLabel") then
				shown += 1
			end
		end
		if shown > cfg.history then -- the oldest line goes
			local oldest: TextLabel? = nil
			for _, child in ipairs(log:GetChildren()) do
				if
					child:IsA("TextLabel")
					and (not oldest or child.LayoutOrder < oldest.LayoutOrder)
				then
					oldest = child
				end
			end
			if oldest then
				oldest:Destroy()
			end
		end
	end
	local function redraw()
		for _, child in ipairs(log:GetChildren()) do
			if child:IsA("TextLabel") then
				child:Destroy()
			end
		end
		local start = math.max(1, #lines - cfg.history * 4)
		local picked = {}
		for i = #lines, start, -1 do
			local line = lines[i]
			if line.kind == nil or line.kind == tab then
				table.insert(picked, 1, line)
				if #picked >= cfg.history then
					break
				end
			end
		end
		for _, line in ipairs(picked) do
			drawLine(line)
		end
		scrollDown()
	end

	local function add(kind: Kind?, text: string, own: boolean?)
		local line = { kind = kind, text = text, own = own == true }
		table.insert(lines, line)
		if #lines > cfg.history * 4 then
			table.remove(lines, 1)
		end
		if kind == nil or kind == tab then
			local follow = atBottom()
			drawLine(line)
			if follow or own then
				scrollDown()
			end
		elseif not own then
			unread[kind] = (unread[kind] or 0) + 1
		end
		if not opened and not own and kind ~= nil then
			unreadClosed += 1
		end
		relabel()
	end
	local function say(text: string, kind: string?)
		local color = SYSTEM_COLORS[kind or "reply"] or REPLY
		add(nil, colored(Chat.escape(text), color))
	end

	-- «[G] [TAG] Ник [48 ур.] Кличка » текст»
	local function playerLine(
		kind: Kind,
		info: {
			name: string,
			level: number?,
			faction: string?,
			tag: string?,
			color: number?,
			nick: string?,
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
		}
	end

	-- ── layout ──────────────────────────────────────────────────────────────────────────────────────────────────
	local function layout()
		local camera = workspace.CurrentCamera
		local viewport = if camera then camera.ViewportSize else Vector2.new(900, 560)
		local mobile = isMobile()
		local w, h
		if mobile then
			w = math.clamp(viewport.X - 230, 260, 440)
			h = math.clamp(viewport.Y * 0.5, 150, 230)
			panel.AnchorPoint = Vector2.new(0, 0)
			panel.Position = UDim2.fromOffset(70, 64)
			button.AnchorPoint = Vector2.new(0, 0)
			button.Size = UDim2.fromOffset(56, 56)
			button.Position = UDim2.fromOffset(8, 128)
		else
			-- left of the hotbar (≈ 500 px wide in the middle), above the key hints
			w = math.clamp(viewport.X / 2 - 270, 300, 440)
			h = 220
			panel.AnchorPoint = Vector2.new(0, 1)
			panel.Position = UDim2.new(0, 8, 1, -64)
			button.AnchorPoint = Vector2.new(0, 1)
			button.Size = UDim2.fromOffset(80, 30)
			button.Position = UDim2.new(0, 8, 1, -64)
		end
		panel.Size = UDim2.fromOffset(w, h)
		local tabW = math.floor((w - PAD * 2 - TAB_H - 4 * 3 - 4) / 4)
		for i, kind in ipairs(Chat.KINDS) do
			tabs[kind].Size = UDim2.fromOffset(tabW, TAB_H - 4)
			tabs[kind].Position = UDim2.fromOffset(PAD + (i - 1) * (tabW + 4), PAD - 2)
		end
		fold.Position = UDim2.new(1, -PAD - TAB_H, 0, PAD - 2)
		log.Position = UDim2.fromOffset(PAD, PAD + TAB_H)
		log.Size = UDim2.new(1, -PAD * 2, 1, -(PAD * 3 + TAB_H + INPUT_H))
		input.Position = UDim2.new(0, PAD, 1, -PAD - INPUT_H)
		input.Size = UDim2.new(1, -PAD * 3 - INPUT_H - 6, 0, INPUT_H)
		sendButton.Position = UDim2.new(1, -PAD - INPUT_H - 6, 1, -PAD - INPUT_H)
		panel.Visible = opened
		button.Visible = not opened
	end
	local function setOpen(value: boolean)
		opened = value
		if opened then
			unreadClosed = 0
		end
		layout()
		relabel()
		if opened then
			scrollDown()
		end
	end
	local function selectTab(kind: Kind)
		tab = kind
		unread[kind] = 0
		relabel()
		redraw()
	end
	for kind, b in pairs(tabs) do
		b.Activated:Connect(function()
			selectTab(kind)
		end)
	end
	fold.Activated:Connect(function()
		input:ReleaseFocus()
		setOpen(false)
	end)
	button.Activated:Connect(function()
		setOpen(true)
		if isMobile() then
			input:CaptureFocus()
		end
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
	input.FocusLost:Connect(function(enterPressed: boolean)
		if enterPressed then
			local text = input.Text
			input.Text = ""
			send(text)
		end
	end)
	sendButton.Activated:Connect(function()
		local text = input.Text
		input.Text = ""
		send(text)
	end)
	UserInputService.InputBegan:Connect(function(key: InputObject, processed: boolean)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local code = key.KeyCode
		if
			code == Enum.KeyCode.Return
			or code == Enum.KeyCode.KeypadEnter
			or code == Enum.KeyCode.Slash
		then
			setOpen(true)
			input:CaptureFocus()
			if code == Enum.KeyCode.Slash then
				task.defer(function()
					if input.Text == "/" then -- the key that opened the chat is not part of the message
						input.Text = ""
					end
				end)
			end
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
				add(nil, colored(message.Text, REPLY))
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
			source.UserId == player.UserId
		)
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
			}, data.t),
			data.u == player.UserId
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

	-- ── tips, the language, the settings, blocks ────────────────────────────────────────────────────────────────
	local tipCount = 0
	while Strings.has("chat_tip_" .. (tipCount + 1)) do
		tipCount += 1
	end
	task.spawn(function()
		task.wait(cfg.tipsFirstMinutes * 60)
		local deck: { number } = {}
		while true do
			local profile = api.profile()
			if tipCount > 0 and not (profile and profile.settings and profile.settings.tipsOff) then
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
			end
			task.wait(1)
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
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(layout)
		end
		layout()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
	UserInputService:GetPropertyChangedSignal("TouchEnabled"):Connect(layout)
	UserInputService:GetPropertyChangedSignal("KeyboardEnabled"):Connect(layout)
	watchViewport()
	relabel()
end

return ChatWindow
