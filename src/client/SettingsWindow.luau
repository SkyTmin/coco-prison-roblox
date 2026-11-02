--!strict
-- Personal settings grouped by purpose; responsive cards retain their size on small screens.
-- Values persist through SetSetting; profile updates refresh only the changed settings page.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Preferences = require(Shared.Preferences)
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local PlayerPreferences = require(script.Parent.PlayerPreferences)
type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local SettingsWindow = {}
local LANGUAGES = { ru = "Русский", en = "English", es = "Español", fr = "Français" }
local TABS = { "controls", "display", "sound", "game", "social", "language" }
local selectedTab = "controls"

-- the settings with their defaults filled in
function SettingsWindow.of(profile: Types.Profile?): Types.Settings
	local s = profile and profile.settings or {}
	return {
		mouseSensitivity = Preferences.number("mouseSensitivity", s.mouseSensitivity),
		touchSensitivity = Preferences.number("touchSensitivity", s.touchSensitivity),
		brightness = Preferences.number("brightness", s.brightness),
		volume = Preferences.number("volume", s.volume),
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

function SettingsWindow.build(
	parent: Instance,
	locale: string,
	profile: Types.Profile?,
	onClose: () -> (),
	createWindow: CreateWindow,
	openLayout: () -> (),
	view: { firstPerson: () -> boolean, toggle: () -> () }
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local current = profile
	local settings: any = PlayerPreferences.WithPreview(SettingsWindow.of(profile))
	local viewport = workspace.CurrentCamera.ViewportSize
	local inset = GuiService:GetGuiInset().Y
	local width = math.clamp(viewport.X - 24, 300, 540)
	local height = math.clamp(viewport.Y - inset - 24, 260, 580)
	local win, content =
		createWindow(parent, T("settings_title"), UDim2.fromOffset(width, height), onClose)
	win.Name = "Window_Settings"
	local tabs = Instance.new("Frame")
	tabs.Name, tabs.BackgroundTransparency = "Categories", 1
	tabs.Size, tabs.Parent = UDim2.new(1, -4, 0, 84), content
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name, scroll.BackgroundTransparency, scroll.BorderSizePixel = "Rows", 1, 0
	scroll.Position, scroll.Size = UDim2.fromOffset(0, 88), UDim2.new(1, 0, 1, -114)
	scroll.ScrollBarThickness, scroll.ScrollBarImageColor3 = 5, Ui.colors.border
	scroll.ScrollingDirection, scroll.Parent = Enum.ScrollingDirection.Y, content
	local note = Ui.label(
		content,
		T("settings_auto_save"),
		UDim2.new(1, -8, 0, 22),
		UDim2.new(0, 4, 1, -22),
		12,
		Ui.colors.muted
	)
	note.TextXAlignment = Enum.TextXAlignment.Center
	local buttons: { [string]: TextButton } = {}
	local renderPage: (boolean?) -> ()
	local function send(key: string, value: any)
		settings[key] = value
		PlayerPreferences.Preview(key, value)
		Remotes.event("SetSetting"):FireServer(key, value)
		renderPage(true)
	end
	local y = 0
	local function row(name: string, caption: string, hint: string?): Frame
		local h = if hint then 116 else 84
		local card = Ui.card(scroll, UDim2.new(1, -9, 0, h), UDim2.fromOffset(0, y))
		card.Name = "Row_" .. name
		y += h + 8
		local label = Ui.label(
			card,
			caption,
			UDim2.new(1, -20, 0, 32),
			UDim2.fromOffset(10, 2),
			16,
			Ui.colors.text
		)
		label.TextWrapped = true
		if hint then
			local detail = Ui.label(
				card,
				hint,
				UDim2.new(1, -20, 0, 30),
				UDim2.fromOffset(10, 34),
				12,
				Ui.colors.muted
			)
			detail.TextWrapped = true
		end
		local control = Instance.new("Frame")
		control.Name, control.BackgroundTransparency = "Control", 1
		control.Position, control.Size = UDim2.new(0, 10, 1, -46), UDim2.new(1, -20, 0, 38)
		control.Parent = card
		return control
	end
	local function toggle(
		caption: string,
		key: string,
		on: boolean,
		onText: string?,
		offText: string?,
		locked: string?
	)
		local control = row(key, T(caption))
		local b = Ui.button(
			control,
			locked or T(if on then onText or "settings_on" else offText or "settings_off"),
			UDim2.fromScale(1, 1),
			UDim2.new(),
			if on and not locked then Ui.colors.buttonGreen else Ui.colors.buttonGrey
		)
		b.Name, b.TextSize = key, 15
		b.Active, b.AutoButtonColor = locked == nil, locked == nil
		if not locked then
			b.Activated:Connect(function()
				send(key, not settings[key])
			end)
		end
	end
	local function number(key: string, caption: string, hint: string?)
		local control = row(key, T(caption), if hint then T(hint) else nil)
		local range = Preferences.numbers[key]
		local value = settings[key]
		local minus =
			Ui.button(control, "−", UDim2.fromOffset(42, 38), UDim2.new(), Ui.colors.buttonGrey)
		minus.Name = key .. "Down"
		local plus = Ui.button(
			control,
			"+",
			UDim2.fromOffset(42, 38),
			UDim2.new(1, -120, 0, 0),
			Ui.colors.buttonGrey
		)
		plus.Name = key .. "Up"
		local shown = Ui.label(
			control,
			string.format("%d%%", math.floor(value * 100 + 0.5)),
			UDim2.new(1, -174, 1, 0),
			UDim2.fromOffset(46, 0),
			18
		)
		shown.Name, shown.TextXAlignment = key .. "Value", Enum.TextXAlignment.Center
		local reset = Ui.button(
			control,
			T("settings_reset_value"),
			UDim2.fromOffset(72, 38),
			UDim2.new(1, -72, 0, 0),
			Ui.colors.buttonGrey
		)
		reset.Name, reset.TextSize = key .. "Reset", 13
		minus.Active, minus.AutoButtonColor = value > range.min, value > range.min
		plus.Active, plus.AutoButtonColor = value < range.max, value < range.max
		minus.Activated:Connect(function()
			send(key, math.max(range.min, math.round(value * 10 - 1) / 10))
		end)
		plus.Activated:Connect(function()
			send(key, math.min(range.max, math.round(value * 10 + 1) / 10))
		end)
		reset.Activated:Connect(function()
			send(key, range.default)
		end)
	end
	local function choice(key: string, caption: string, prefix: string)
		local control = row(key, T(caption))
		for i = 1, 3 do
			local b = Ui.button(
				control,
				T(prefix .. i),
				UDim2.new(1 / 3, -4, 1, 0),
				UDim2.fromScale((i - 1) / 3, 0),
				if settings[key] == i then Ui.colors.buttonGreen else Ui.colors.buttonGrey
			)
			b.Name, b.TextSize = key .. i, 13
			b.Activated:Connect(function()
				send(key, i)
			end)
		end
	end
	renderPage = function(keepScroll: boolean?)
		local previous = if keepScroll then scroll.CanvasPosition.Y else 0
		for _, child in scroll:GetChildren() do
			child:Destroy()
		end
		y = 0
		for id, button in buttons do
			button.BackgroundColor3 = if id == selectedTab
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		if selectedTab == "controls" then
			number("mouseSensitivity", "settings_mouse_sensitivity", "settings_mouse_hint")
			number("touchSensitivity", "settings_touch_sensitivity", "settings_touch_hint")
			local control = row("view", T("touch_camera"))
			local b = Ui.button(
				control,
				T(if view.firstPerson() then "settings_view_first" else "settings_view_third"),
				UDim2.fromScale(1, 1),
				UDim2.new(),
				Ui.colors.buttonGrey
			)
			b.Name = "View"
			b.Activated:Connect(function()
				view.toggle()
				renderPage(true)
			end)
			local layout = Ui.button(
				scroll,
				T("settings_layout"),
				UDim2.new(1, -9, 0, 44),
				UDim2.fromOffset(0, y),
				Ui.colors.buttonBlue
			)
			layout.Name = "Layout"
			layout.Activated:Connect(openLayout)
			y += 52
		elseif selectedTab == "display" then
			number("brightness", "settings_brightness", "settings_brightness_hint")
			toggle(
				"settings_toasts",
				"hideToasts",
				not settings.hideToasts,
				"settings_shown",
				"settings_hidden"
			)
			toggle(
				"settings_boosters",
				"hideBoosters",
				not settings.hideBoosters,
				"settings_shown",
				"settings_hidden"
			)
			toggle(
				"settings_players",
				"hidePlayers",
				not settings.hidePlayers,
				"settings_shown",
				"settings_hidden"
			)
			toggle(
				"settings_enchant_fx",
				"enchantFxOff",
				not settings.enchantFxOff,
				"settings_shown",
				"settings_hidden",
				if PrisPlus.active(current, workspace:GetServerTimeNow())
					then nil
					else T("settings_pris_locked")
			)
		elseif selectedTab == "sound" then
			number("volume", "settings_volume")
			toggle("settings_sound", "muted", not settings.muted)
		elseif selectedTab == "game" then
			local locked = if current and current.autosell
				then nil
				else T("settings_autosell_locked")
			toggle("settings_autosell", "autosellOff", not settings.autosellOff, nil, nil, locked)
			toggle(
				"settings_autosell_text",
				"autosellTextOff",
				not settings.autosellTextOff,
				"settings_shown",
				"settings_hidden",
				locked
			)
			toggle(
				"settings_pay",
				"payOff",
				not settings.payOff,
				"settings_accept",
				"settings_refuse"
			)
			toggle(
				"settings_gift",
				"giftOff",
				not settings.giftOff,
				"settings_accept",
				"settings_refuse"
			)
		elseif selectedTab == "social" then
			toggle("chat_enabled", "chatOff", not settings.chatOff)
			choice("chatSize", "chat_size", "chat_size_")
			choice("chatBack", "chat_back", "chat_back_")
			toggle("chat_bubbles", "bubblesOff", not settings.bubblesOff)
			toggle(
				"settings_tips",
				"tipsOff",
				not settings.tipsOff,
				"settings_shown",
				"settings_hidden"
			)
			toggle(
				"settings_auction_ads",
				"auctionAdsOff",
				not settings.auctionAdsOff,
				"settings_shown",
				"settings_hidden"
			)
		else
			for _, code in Config.locales do
				local b = Ui.button(
					scroll,
					LANGUAGES[code] or code,
					UDim2.new(1, -9, 0, 48),
					UDim2.fromOffset(0, y),
					if code == locale then Ui.colors.buttonGreen else Ui.colors.buttonGrey
				)
				b.Name = "Lang_" .. code
				y += 56
				b.Activated:Connect(function()
					if code ~= locale then
						Remotes.event("SetLocale"):FireServer(code)
					end
				end)
			end
		end
		scroll.CanvasSize = UDim2.fromOffset(0, y)
		scroll.CanvasPosition =
			Vector2.new(0, math.min(previous, math.max(0, y - scroll.AbsoluteWindowSize.Y)))
	end
	for i, id in TABS do
		local b = Ui.button(
			tabs,
			"",
			UDim2.new(1 / 3, -4, 0, 56),
			UDim2.new((i - 1) % 3 / 3, 0, 0, math.floor((i - 1) / 3) * 62),
			Ui.colors.buttonGrey
		)
		b.Name, b.TextSize = "Tab_" .. id, 14
		local icon = Instance.new("ImageLabel")
		icon.Name, icon.BackgroundTransparency = "Icon", 1
		icon.Image = Config.icons.icons["menu_settings_" .. id] or ""
		icon.Size, icon.Position = UDim2.fromOffset(28, 28), UDim2.new(0.5, -14, 0, 4)
		icon.ScaleType, icon.ResampleMode = Enum.ScaleType.Fit, Enum.ResamplerMode.Pixelated
		icon.Parent = b
		local caption = Ui.label(
			b,
			T("settings_tab_" .. id),
			UDim2.new(1, -4, 0, 20),
			UDim2.fromOffset(2, 33),
			12
		)
		caption.Name, caption.TextXAlignment = "Caption", Enum.TextXAlignment.Center
		buttons[id] = b
		b.Activated:Connect(function()
			selectedTab = id
			renderPage(false)
		end)
	end
	local function arrangeTabs()
		local columns = if win.AbsoluteSize.X >= 480 then 6 else 3
		local tabHeight = math.ceil(#TABS / columns) * 62
		tabs.Size = UDim2.new(1, -4, 0, tabHeight)
		scroll.Position = UDim2.fromOffset(0, tabHeight)
		scroll.Size = UDim2.new(1, 0, 1, -tabHeight - 26)
		for i, id in TABS do
			local button = buttons[id]
			button.Size = UDim2.new(1 / columns, -4, 0, 56)
			button.Position =
				UDim2.new((i - 1) % columns / columns, 0, 0, math.floor((i - 1) / columns) * 62)
			button.TextSize = if columns == 6 then 13 else 14
		end
	end
	win:GetPropertyChangedSignal("AbsoluteSize"):Connect(arrangeTabs)
	arrangeTabs()
	local function stamp(p: Types.Profile?): string
		return HttpService:JSONEncode({
			settings = p and p.settings or {},
			autosell = p and p.autosell,
			pris = PrisPlus.active(p, workspace:GetServerTimeNow()),
		})
	end
	local previous = stamp(profile)
	local function refresh(p: Types.Profile?)
		current = p
		local nextStamp = stamp(p)
		if nextStamp ~= previous then
			previous = nextStamp
			settings = PlayerPreferences.WithPreview(SettingsWindow.of(p))
			renderPage(true)
		end
	end
	local previewExpired = PlayerPreferences.PreviewExpired.Event:Connect(function()
		settings = PlayerPreferences.WithPreview(SettingsWindow.of(current))
		renderPage(true)
	end)
	win.Destroying:Once(function()
		previewExpired:Disconnect()
	end)
	renderPage(false)
	return win, refresh
end
return SettingsWindow
