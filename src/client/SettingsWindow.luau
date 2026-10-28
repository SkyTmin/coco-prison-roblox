--!strict
-- «Настройки» [P] [владелец 27.10: «в меню настройки общие и туда добавить кнопки можно. Где можно скрыть
-- уведомления, уменьшить там уведомления, переместить их … тоже самое с баром бустеров. Туда же языки добавить и
-- уменьшить звук, выключить, в общем базовые настройки»]: language, volume (−/+ by 10 %), sound on/off,
-- notifications and the booster bar shown / hidden, and «Кнопки и интерфейс» — the layout editor, where every
-- element (the notifications and the booster bar too) is moved and resized. Values live in the profile
-- (profile.settings, SetSetting; the language: SetLocale); the window is rebuilt on every profile change.
-- [владелец 28.10, вики MENUS-SOCIAL: «Авто-продажа блоков», «Частицы у прицела при автопродаже»] two more rows: auto-sell
-- on / off and the income at the crosshair shown / hidden (both on by default; locked until the auto-sell is bought).
-- [владелец 28.10: «в меню кнопки язык и вид убери в настройки»] the «Вид» row: first / third person (V / F5 on a
-- computer), moved here from the menu grid together with the language.
-- Этап 8 [сеть TG/40: «эффекты чар можно выключить в /settings» — for subscribers]: the «Эффекты чар PRIS+» row (the
-- particles of Вихрь / Ярость / Бульдозер, EnchantFx), locked without PRIS+; the same switch is in the /pp window.
-- The «Чат» section [владелец 28.10: «МАКСИМУМ УСИЛИЙ К ЧАТУ»; вечер: чат Roblox]: the chat on / off, the size of Roblox's
-- chat window (not the text — Roblox takes that from the player's own settings), its background, bubbles over heads,
-- tips (ChatWindow applies them). The rows scroll (the window stays the size of 12 rows); the scroll position
-- survives the rebuild after every change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)

local SettingsWindow = {}

local W, ROW, LABEL_W = 420, 44, 150
local LANGUAGES = { ru = "Русский", en = "English", es = "Español", fr = "Français" }

-- the settings with their defaults filled in
function SettingsWindow.of(profile: Types.Profile?): Types.Settings
	local s = profile and profile.settings or {}
	return {
		volume = if typeof(s.volume) == "number" then s.volume else 1,
		muted = s.muted == true,
		hideToasts = s.hideToasts == true,
		hideBoosters = s.hideBoosters == true,
		autosellOff = s.autosellOff == true,
		autosellTextOff = s.autosellTextOff == true,
		tipsOff = s.tipsOff == true,
		payOff = s.payOff == true,
		giftOff = s.giftOff == true,
		hidePlayers = s.hidePlayers == true,
		autoDig = s.autoDig == true,
		night = s.night == true,
		appleSkinOff = s.appleSkinOff == true,
		enchantFxOff = s.enchantFxOff == true,
		chatSize = if s.chatSize == 1 or s.chatSize == 3 then s.chatSize else 2,
		chatBack = if s.chatBack == 1 or s.chatBack == 3 then s.chatBack else 2,
		bubblesOff = s.bubblesOff == true,
		chatOff = s.chatOff == true,
		auctionAdsOff = s.auctionAdsOff == true,
	}
end

local function set(key: string, value: any)
	Remotes.event("SetSetting"):FireServer(key, value)
end

local scrollY = 0 -- where the rows were scrolled to (the window is rebuilt on every profile change)
local VISIBLE_ROWS = 12

function SettingsWindow.build(
	parent: Instance,
	locale: string,
	profile: Types.Profile?,
	onClose: () -> (),
	createWindow: CreateWindow,
	openLayout: () -> (),
	view: { firstPerson: () -> boolean, toggle: () -> () }
): Frame
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local settings = SettingsWindow.of(profile)
	local rows = 21 -- 2 section titles, 12 general rows + the layout button, 6 chat rows
	local win, content = createWindow(
		parent,
		T("settings_title"),
		UDim2.fromOffset(W, VISIBLE_ROWS * ROW + 56),
		onClose
	)
	win.Name = "Window_Settings"
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Rows"
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.CanvasSize = UDim2.fromOffset(0, rows * ROW)
	scroll.ScrollBarThickness = 5
	scroll.ScrollBarImageColor3 = Ui.colors.border
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = content
	task.defer(function()
		scroll.CanvasPosition = Vector2.new(0, scrollY)
	end)
	scroll:GetPropertyChangedSignal("CanvasPosition"):Connect(function()
		scrollY = scroll.CanvasPosition.Y
	end)
	local W_ROW = W - 12 - 8 -- the rows leave room for the scroll bar
	-- a section title over its rows («Общие», «Чат»)
	local function section(slot: number, caption: string)
		local title = Ui.label(
			scroll,
			caption,
			UDim2.new(1, -8, 0, ROW - 10),
			UDim2.fromOffset(4, slot * ROW + 6),
			15,
			Ui.colors.header
		)
		title.Name = "Section" .. slot
	end
	-- general rows sit at slot i (the «Общие» title takes slot 0)
	local function row(i: number, caption: string): Frame
		local line = Instance.new("Frame")
		line.Name = "Row" .. i
		line.BackgroundTransparency = 1
		line.Size = UDim2.fromOffset(W_ROW, ROW - 6)
		line.Position = UDim2.fromOffset(0, i * ROW)
		line.Parent = scroll
		local label = Ui.label(
			line,
			caption,
			UDim2.new(0, LABEL_W, 1, 0),
			UDim2.fromOffset(4, 0),
			15,
			Ui.colors.text
		)
		label.TextXAlignment = Enum.TextXAlignment.Left
		return line
	end
	local function toggle(
		line: Frame,
		name: string,
		on: boolean,
		onText: string,
		offText: string,
		flip: () -> ()
	)
		local b = Ui.button(
			line,
			if on then onText else offText,
			UDim2.new(1, -LABEL_W - 8, 1, 0),
			UDim2.fromOffset(LABEL_W + 4, 0),
			if on then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		b.Name = name
		b.Activated:Connect(flip)
		return b
	end

	section(0, T("settings_general_section"))
	-- 1. language: a button per locale, the current one green
	local languages = row(1, T("settings_language"))
	local count = #Config.locales
	local width = (W_ROW - LABEL_W - 8 - (count - 1) * 4) / count
	for i, code in ipairs(Config.locales) do
		local b = Ui.button(
			languages,
			LANGUAGES[code] or code,
			UDim2.new(0, width, 1, 0),
			UDim2.fromOffset(LABEL_W + 4 + (i - 1) * (width + 4), 0),
			if code == locale then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		b.Name = "Lang_" .. code
		b.TextSize = 13
		b.Activated:Connect(function()
			if code ~= locale then
				Remotes.event("SetLocale"):FireServer(code)
			end
		end)
	end

	-- 2. the view: first / third person (changes at once, no profile round trip)
	local viewButton = toggle(
		row(2, T("touch_camera")),
		"View",
		view.firstPerson(),
		T("settings_view_first"),
		T("settings_view_third"),
		function() end
	)
	viewButton.BackgroundColor3 = Ui.colors.buttonGrey
	viewButton.Activated:Connect(function()
		view.toggle()
		viewButton.Text = if view.firstPerson()
			then T("settings_view_first")
			else T("settings_view_third")
	end)

	-- 3. volume: − 70 % +
	local volumeRow = row(3, T("settings_volume"))
	local volume = settings.volume :: number
	local minus = Ui.button(
		volumeRow,
		"−",
		UDim2.new(0, 44, 1, 0),
		UDim2.fromOffset(LABEL_W + 4, 0),
		Ui.colors.buttonGrey
	)
	minus.Name = "VolumeDown"
	local plus = Ui.button(
		volumeRow,
		"+",
		UDim2.new(0, 44, 1, 0),
		UDim2.new(1, -44, 0, 0),
		Ui.colors.buttonGrey
	)
	plus.Name = "VolumeUp"
	local shown = Ui.label(
		volumeRow,
		string.format("%d%%", math.floor(volume * 100 + 0.5)),
		UDim2.new(1, -LABEL_W - 4 - 96, 1, 0),
		UDim2.fromOffset(LABEL_W + 4 + 48, 0),
		16,
		if settings.muted then Ui.colors.muted else Ui.colors.text
	)
	shown.Name = "VolumeValue"
	shown.TextXAlignment = Enum.TextXAlignment.Center
	minus.Activated:Connect(function()
		set("volume", math.max(0, math.floor(volume * 10 + 0.5) / 10 - 0.1))
	end)
	plus.Activated:Connect(function()
		set("volume", math.min(1, math.floor(volume * 10 + 0.5) / 10 + 0.1))
	end)

	-- 4. sound on / off
	toggle(
		row(4, T("settings_sound")),
		"Sound",
		not settings.muted,
		T("settings_on"),
		T("settings_off"),
		function()
			set("muted", not settings.muted)
		end
	)
	-- 5–6. notifications and the booster bar
	toggle(
		row(5, T("settings_toasts")),
		"Toasts",
		not settings.hideToasts,
		T("settings_shown"),
		T("settings_hidden"),
		function()
			set("hideToasts", not settings.hideToasts)
		end
	)
	toggle(
		row(6, T("settings_boosters")),
		"Boosters",
		not settings.hideBoosters,
		T("settings_shown"),
		T("settings_hidden"),
		function()
			set("hideBoosters", not settings.hideBoosters)
		end
	)
	-- 7–8. the auto-sell (a donate purchase) and its income at the crosshair
	local owned = profile ~= nil and profile.autosell == true
	local function autosellToggle(
		i: number,
		caption: string,
		name: string,
		key: string,
		off: boolean
	)
		local line = row(i, caption)
		if not owned then
			local b = toggle(line, name, false, "", T("settings_autosell_locked"), function() end)
			b.TextSize = 13
			return
		end
		toggle(line, name, not off, T("settings_on"), T("settings_off"), function()
			set(key, not off)
		end)
	end
	autosellToggle(
		7,
		T("settings_autosell"),
		"Autosell",
		"autosellOff",
		settings.autosellOff == true
	)
	autosellToggle(
		8,
		T("settings_autosell_text"),
		"AutosellText",
		"autosellTextOff",
		settings.autosellTextOff == true
	)
	-- 9–11. the chat (этап 3): money transfers and gifts to this player [клиент pay.*, gift.*], the other players
	-- hidden (/hide; H stays the layout editor); the «[Совет]» lines [клиент settings.elements.advice_toggle] are in «Чат»
	local function flag(
		i: number,
		caption: string,
		name: string,
		key: string,
		on: boolean,
		onText: string,
		offText: string
	)
		toggle(row(i, caption), name, on, onText, offText, function()
			set(key, on)
		end)
	end
	flag(
		9,
		T("settings_pay"),
		"Pay",
		"payOff",
		not settings.payOff,
		T("settings_accept"),
		T("settings_refuse")
	)
	flag(
		10,
		T("settings_gift"),
		"Gift",
		"giftOff",
		not settings.giftOff,
		T("settings_accept"),
		T("settings_refuse")
	)
	toggle(
		row(11, T("settings_players")),
		"Players",
		not settings.hidePlayers,
		T("settings_shown"),
		T("settings_hidden"),
		function()
			set("hidePlayers", not settings.hidePlayers)
		end
	)
	-- 12. the PRIS+ enchant particles (этап 8), only for subscribers
	do
		local line = row(12, T("settings_enchant_fx"))
		if PrisPlus.active(profile, workspace:GetServerTimeNow()) then
			toggle(
				line,
				"EnchantFx",
				not settings.enchantFxOff,
				T("settings_shown"),
				T("settings_hidden"),
				function()
					set("enchantFxOff", not settings.enchantFxOff)
				end
			)
		else
			local b = toggle(
				line,
				"EnchantFx",
				false,
				"",
				T("settings_pris_locked"),
				function() end
			)
			b.TextSize = 13
		end
	end
	-- 13. move and resize the buttons, the notifications, the booster bar
	local layout = Ui.button(
		scroll,
		T("settings_layout"),
		UDim2.fromOffset(W_ROW, ROW - 6),
		UDim2.fromOffset(0, 13 * ROW),
		Ui.colors.buttonBlue
	)
	layout.Name = "Layout"
	layout.Activated:Connect(openLayout)

	-- «Чат» (slots 14…)
	section(14, T("settings_chat_section"))
	local function choice(
		i: number,
		caption: string,
		name: string,
		key: string,
		value: number,
		prefix: string
	)
		local line = row(i, caption)
		local w = (W_ROW - LABEL_W - 8 - 2 * 4) / 3
		for n = 1, 3 do
			local b = Ui.button(
				line,
				T(prefix .. n),
				UDim2.new(0, w, 1, 0),
				UDim2.fromOffset(LABEL_W + 4 + (n - 1) * (w + 4), 0),
				if value == n then Ui.colors.buttonGreen else Ui.colors.buttonGrey
			)
			b.Name = name .. n
			b.TextSize = 13
			b.Activated:Connect(function()
				if value ~= n then
					set(key, n)
				end
			end)
		end
	end
	toggle(
		row(15, T("chat_enabled")),
		"Chat",
		not settings.chatOff,
		T("settings_on"),
		T("settings_off"),
		function()
			set("chatOff", not settings.chatOff)
		end
	)
	choice(16, T("chat_size"), "ChatSize", "chatSize", settings.chatSize :: number, "chat_size_")
	choice(17, T("chat_back"), "ChatBack", "chatBack", settings.chatBack :: number, "chat_back_")
	flag(
		18,
		T("chat_bubbles"),
		"Bubbles",
		"bubblesOff",
		not settings.bubblesOff,
		T("settings_on"),
		T("settings_off")
	)
	flag(
		19,
		T("settings_tips"),
		"Tips",
		"tipsOff",
		not settings.tipsOff,
		T("settings_shown"),
		T("settings_hidden")
	)
	-- the paid auction announcements of other players (AuctionBanner + their chat line)
	flag(
		20,
		T("settings_auction_ads"),
		"AuctionAds",
		"auctionAdsOff",
		not settings.auctionAdsOff,
		T("settings_shown"),
		T("settings_hidden")
	)
	scroll.CanvasSize = UDim2.fromOffset(0, rows * ROW)
	return win
end

return SettingsWindow
