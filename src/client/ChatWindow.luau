--!strict
-- The chat on this screen (этап 3) — Roblox's own chat, set up for our HUD [владелец 28.10, вечер: «Давай тогда
-- переводить на чат в роблокс»; docs/research/mobile-chat-research.md §0: from May 2027 platform-integrated chat is
-- required — code never reads message text, custom UIs never draw messages]. We draw no messages at all:
--   * The window: Roblox's default chat window + input bar + channel tabs (ChatWindowConfiguration,
--     ChatInputBarConfiguration, ChannelTabsConfiguration). Not TextChannelWindow: it draws nothing while
--     PlatformIntegratedChat is off (checked in Studio 28.10), binds one channel per window, cannot show the Global
--     channel and gets Quick Words only later — the default window works with the setting off and on, has the tabs,
--     the input, whispers, Quick Words and Roblox's own phone behaviour. It is placed by alignment only (no offsets):
--     computer bottom-left (the key hints moved right of the hotbar, init.client), narrowed until it stays left of the
--     hotbar band, centred on the left edge when even the narrowest is too wide; phone top-left, Roblox opens and
--     closes it with its top-bar button. So it is not in the HUD editor (no clean way to move it) and has no gear —
--     its quick settings would fight Roblox's own fading window; Settings «Чат» holds them.
--   * Tabs: Here (RBXGeneral, Общий + system lines), Фракция, Банда — the server's TextChannels (ChatService); a tab
--     shows its channel's Name, so this client renames its copy into its language when the channel arrives (before
--     the TextSource that makes the tab).
--   * Settings (profile.settings, the «Чат» section of SettingsWindow): window size 1–3 (HeightScale / WidthScale,
--     not the text — Roblox takes the text size from the player's own settings), background 1–3, bubbles over heads,
--     tips, «Выключить чат» (window, input, tabs, bubbles and Roblox's chat button off; a toast says where to turn it
--     back on). Old keys (chatFade, chatGlobalOff, chatButton) are ignored.
--   * System lines (announcements, command answers, «[Совет]» every Config.chat.tipsMinutes): ChatSystem → RBXSystem
--     DisplaySystemMessage with a RichText colour; Roblox shows them to everyone, also to players who may not chat.
--   * Bubbles: Roblox's BubbleChatConfiguration in the dark style, shorter distance (Config.chat.bubble*).
--   * The commands are the server's TextChatCommands (ChatCommandService); ChatCommands runs their client part.
-- QA (Studio): Player.ClientDebug "chatState" → the applied config and rects; "chatSystem" text → a system line.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local TextChatService = game:GetService("TextChatService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)
local ChatCommands = require(script.Parent.ChatCommands)
local HidePlayers = require(script.Parent.HidePlayers)

export type Api = {
	profile: () -> Types.Profile?,
	locale: () -> string,
	toast: (text: string) -> (),
}

local ChatWindow = {}

local cfg = Config.chat
local REPLY = Color3.fromRGB(205, 205, 215)
local TIP = Color3.fromRGB(110, 225, 130)
local SYSTEM_COLORS: { [string]: Color3 } = {
	announce = Ui.colors.header,
	reply = REPLY,
	error = Kit.BAD,
}
local GAP = 12 -- px between the chat and the hotbar band

local hudObjects: { [string]: GuiObject } = {}
local requestFit: () -> () = function() end
local debugHandler: ((string, any) -> any)? = nil

-- init.client hands over the HUD the chat window keeps clear of (the hotbar band); called again is fine
function ChatWindow.hud(objects: { [string]: GuiObject })
	for name, object in pairs(objects) do
		hudObjects[name] = object
		object:GetPropertyChangedSignal("AbsolutePosition"):Connect(function()
			requestFit()
		end)
	end
	requestFit()
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

-- every property write may meet an engine without it (pcall per property, the rest still applies)
local function setProp(object: Instance, key: string, value: any)
	pcall(function()
		(object :: any)[key] = value
	end)
end

function ChatWindow.start(api: Api)
	local locale = api.locale()
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local windowCfg =
		TextChatService:WaitForChild("ChatWindowConfiguration") :: ChatWindowConfiguration
	local inputCfg =
		TextChatService:WaitForChild("ChatInputBarConfiguration") :: ChatInputBarConfiguration
	local bubbleCfg =
		TextChatService:WaitForChild("BubbleChatConfiguration") :: BubbleChatConfiguration
	local tabsCfg = TextChatService:FindFirstChild("ChannelTabsConfiguration")

	-- ── the settings (profile.settings) ─────────────────────────────────────────────────────────────────────────
	type View = {
		size: number,
		back: number,
		bubbles: boolean,
		off: boolean,
		tips: boolean,
		mobile: boolean,
	}
	local function view(): View
		local profile = api.profile()
		local s: any = profile and profile.settings or {}
		return {
			size = if s.chatSize == 1 or s.chatSize == 3 then s.chatSize else 2,
			back = if s.chatBack == 1 or s.chatBack == 3 then s.chatBack else 2,
			bubbles = s.bubblesOff ~= true,
			off = s.chatOff == true,
			tips = s.tipsOff ~= true,
			mobile = isMobile(),
		}
	end
	local current: View? = nil
	local widthScale = 1 -- what the fit left of the chosen width

	-- bubbles in our dark style, short range (Roblox's own; they show what Roblox delivered to this player)
	setProp(bubbleCfg, "MaxDistance", cfg.bubbleDistance)
	setProp(bubbleCfg, "BubbleDuration", cfg.bubbleSeconds)
	setProp(bubbleCfg, "MaxBubbles", cfg.bubbleMax)
	setProp(bubbleCfg, "BackgroundColor3", Color3.fromRGB(18, 18, 22))
	setProp(bubbleCfg, "BackgroundTransparency", 0.15)
	setProp(bubbleCfg, "TextColor3", Color3.fromRGB(235, 235, 240))
	setProp(bubbleCfg, "TextSize", 16)
	setProp(bubbleCfg, "VerticalStudsOffset", cfg.bubbleOffset)
	setProp(bubbleCfg, "TailVisible", true)

	-- the computer window: as wide as the size setting asks, narrower until it stays left of the hotbar band
	local fitToken = 0
	local function fit()
		fitToken += 1
		local token = fitToken
		local v = current
		if not v or v.off or v.mobile then
			return
		end
		task.spawn(function()
			local wanted = (cfg.windowWidths :: { number })[v.size] or 1
			local w = wanted
			setProp(windowCfg, "VerticalAlignment", Enum.VerticalAlignment.Bottom)
			for _ = 1, 8 do
				setProp(windowCfg, "WidthScale", w)
				task.wait(0.25)
				if token ~= fitToken then
					return
				end
				local hotbar = hudObjects.hotbar
				local size = windowCfg.AbsoluteSize
				if not hotbar or size.X <= 0 then
					break -- not drawn yet: the next fit (viewport, settings, the hotbar moving) tries again
				end
				local right = windowCfg.AbsolutePosition.X + size.X
				if right + GAP <= hotbar.AbsolutePosition.X then
					break
				end
				if w <= cfg.windowMinWidth + 1e-3 then
					-- even the narrowest reaches the hotbar band: up on the left edge, clear of it
					setProp(windowCfg, "VerticalAlignment", Enum.VerticalAlignment.Center)
					break
				end
				w = math.max(cfg.windowMinWidth, w - 0.1)
			end
			widthScale = w
		end)
	end
	requestFit = fit

	local function apply(v: View)
		local was = current
		current = v
		local on = not v.off
		setProp(windowCfg, "Enabled", on)
		setProp(inputCfg, "Enabled", on)
		if tabsCfg then
			setProp(tabsCfg, "Enabled", on)
		end
		setProp(bubbleCfg, "Enabled", on and v.bubbles)
		pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Chat, on)
		end)
		local heights = if v.mobile then cfg.phoneHeights else cfg.windowHeights
		setProp(windowCfg, "HeightScale", (heights :: { number })[v.size] or 1)
		setProp(windowCfg, "HorizontalAlignment", Enum.HorizontalAlignment.Left)
		if v.mobile then
			-- the phone: Roblox's own place under its top bar (it opens and closes the window there)
			setProp(windowCfg, "VerticalAlignment", Enum.VerticalAlignment.Top)
			setProp(windowCfg, "WidthScale", (cfg.phoneWidths :: { number })[v.size] or 1)
		end
		local back = (cfg.windowBacks :: { number })[v.back] or 0.3
		setProp(windowCfg, "BackgroundTransparency", back)
		setProp(inputCfg, "BackgroundTransparency", math.min(back, cfg.inputBackMax))
		if tabsCfg then
			setProp(tabsCfg, "BackgroundTransparency", math.min(back, cfg.inputBackMax))
		end
		if not was or was.size ~= v.size or was.mobile ~= v.mobile or was.off ~= v.off then
			fit()
		end
		if was and not was.off and v.off then
			api.toast(T("chat_off_toast"))
		end
	end

	local function same(a: View, b: View): boolean
		return a.size == b.size
			and a.back == b.back
			and a.bubbles == b.bubbles
			and a.off == b.off
			and a.tips == b.tips
			and a.mobile == b.mobile
	end

	-- ── the faction / gang tabs in this player's language ───────────────────────────────────────────────────────
	local function localize(channel: Instance)
		local kind = channel:GetAttribute(Chat.KIND_ATTRIBUTE)
		if channel:IsA("TextChannel") and (kind == "faction" or kind == "gang") then
			channel.Name = T(Chat.TAB_KEY[kind :: Chat.Kind]) -- this client's copy only
		end
	end
	task.spawn(function()
		local folder = TextChatService:WaitForChild(Chat.FOLDER, 60)
		if not folder then
			return
		end
		folder.ChildAdded:Connect(localize)
		for _, channel in ipairs(folder:GetChildren()) do
			localize(channel)
		end
	end)

	-- ── system lines ────────────────────────────────────────────────────────────────────────────────────────────
	local systemChannel: TextChannel? = nil
	local function say(text: string)
		local channel = systemChannel
		if not channel then
			local folder = TextChatService:WaitForChild("TextChannels", 30)
			local found = folder and folder:WaitForChild(Chat.SYSTEM, 30)
			if not found or not found:IsA("TextChannel") then
				return
			end
			channel = found
			systemChannel = found
		end
		pcall(function()
			(channel :: TextChannel):DisplaySystemMessage(text)
		end)
	end
	Remotes.event("ChatSystem").OnClientEvent:Connect(function(text: any, kind: any)
		if typeof(text) ~= "string" then
			return
		end
		local color = SYSTEM_COLORS[if typeof(kind) == "string" then kind else "reply"] or REPLY
		task.spawn(say, colored(Chat.escape(text), color))
	end)

	-- «[Совет]» every Config.chat.tipsMinutes, every tip once in a new order each round
	local tipCount = 0
	while Strings.has("chat_tip_" .. (tipCount + 1)) do
		tipCount += 1
	end
	task.spawn(function()
		task.wait(cfg.tipsFirstMinutes * 60)
		local deck: { number } = {}
		while true do
			local v = current
			if tipCount > 0 and v and v.tips and not v.off then
				if #deck == 0 then
					for i = 1, tipCount do
						table.insert(deck, math.random(1, #deck + 1), i)
					end
				end
				local i = table.remove(deck) :: number
				say(
					colored(T("chat_tip"), TIP)
						.. " "
						.. colored(Chat.escape(T("chat_tip_" .. i)), REPLY)
				)
			end
			task.wait(cfg.tipsMinutes * 60)
		end
	end)

	-- ── the settings, the language, /hide ───────────────────────────────────────────────────────────────────────
	local hiddenNow = false
	task.spawn(function()
		while true do
			local nextLocale = api.locale()
			if nextLocale ~= locale then
				locale = nextLocale
				local folder = TextChatService:FindFirstChild(Chat.FOLDER)
				for _, channel in ipairs(if folder then folder:GetChildren() else {}) do
					localize(channel) -- an existing tab keeps its first name; new ones take the new language
				end
			end
			local v = view()
			if not current or not same(current :: View, v) then
				apply(v)
			end
			local profile = api.profile()
			local hide = profile ~= nil
				and profile.settings ~= nil
				and profile.settings.hidePlayers == true
			if profile and hide ~= hiddenNow then -- /hide, the settings switch, or the saved state after a rejoin
				hiddenNow = hide
				HidePlayers.set(hide)
			end
			task.wait(0.5)
		end
	end)
	local function watchViewport()
		local camera = workspace.CurrentCamera
		if camera then
			camera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
		end
		fit()
	end
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchViewport)
	watchViewport()

	ChatCommands.start()

	-- ── QA (Studio) ─────────────────────────────────────────────────────────────────────────────────────────────
	debugHandler = function(action: string, arg: any): any
		if action == "chatState" then
			local function rect(object: any): { number }?
				local ok, out = pcall(function()
					local p, s = object.AbsolutePosition, object.AbsoluteSize
					return { math.floor(p.X), math.floor(p.Y), math.floor(s.X), math.floor(s.Y) }
				end)
				return if ok then out else nil
			end
			local hotbar = hudObjects.hotbar
			return {
				view = current,
				widthScale = widthScale,
				heightScale = windowCfg.HeightScale,
				vertical = tostring(windowCfg.VerticalAlignment),
				enabled = windowCfg.Enabled,
				tabs = if tabsCfg then (tabsCfg :: any).Enabled else nil,
				bubbles = bubbleCfg.Enabled,
				window = rect(windowCfg),
				input = rect(inputCfg),
				hotbar = if hotbar then rect(hotbar) else nil,
				target = if inputCfg.TargetTextChannel
					then inputCfg.TargetTextChannel.Name
					else nil,
			}
		elseif action == "chatSystem" then
			task.spawn(say, colored(Chat.escape(tostring(arg)), SYSTEM_COLORS.announce))
			return true
		end
		return nil
	end
end

return ChatWindow
