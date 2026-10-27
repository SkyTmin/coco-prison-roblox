--!strict
-- «Настройки» [P] [владелец 27.10: «в меню настройки общие и туда добавить кнопки можно. Где можно скрыть
-- уведомления, уменьшить там уведомления, переместить их … тоже самое с баром бустеров. Туда же языки добавить и
-- уменьшить звук, выключить, в общем базовые настройки»]: language, volume (−/+ by 10 %), sound on/off,
-- notifications and the booster bar shown / hidden, and «Кнопки и интерфейс» — the layout editor, where every
-- element (the notifications and the booster bar too) is moved and resized. Values live in the profile
-- (profile.settings, SetSetting; the language: SetLocale); the window is rebuilt on every profile change.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
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
	}
end

local function set(key: string, value: any)
	Remotes.event("SetSetting"):FireServer(key, value)
end

function SettingsWindow.build(
	parent: Instance,
	locale: string,
	profile: Types.Profile?,
	onClose: () -> (),
	createWindow: CreateWindow,
	openLayout: () -> ()
): Frame
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local settings = SettingsWindow.of(profile)
	local rows = 6
	local win, content =
		createWindow(parent, T("settings_title"), UDim2.fromOffset(W, rows * ROW + 56), onClose)
	win.Name = "Window_Settings"
	local function row(i: number, caption: string): Frame
		local line = Instance.new("Frame")
		line.Name = "Row" .. i
		line.BackgroundTransparency = 1
		line.Size = UDim2.new(1, 0, 0, ROW - 6)
		line.Position = UDim2.fromOffset(0, (i - 1) * ROW)
		line.Parent = content
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

	-- 1. language: a button per locale, the current one green
	local languages = row(1, T("settings_language"))
	local count = #Config.locales
	local width = (W - 12 - LABEL_W - 8 - (count - 1) * 4) / count
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

	-- 2. volume: − 70 % +
	local volumeRow = row(2, T("settings_volume"))
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

	-- 3. sound on / off
	toggle(
		row(3, T("settings_sound")),
		"Sound",
		not settings.muted,
		T("settings_on"),
		T("settings_off"),
		function()
			set("muted", not settings.muted)
		end
	)
	-- 4–5. notifications and the booster bar
	toggle(
		row(4, T("settings_toasts")),
		"Toasts",
		not settings.hideToasts,
		T("settings_shown"),
		T("settings_hidden"),
		function()
			set("hideToasts", not settings.hideToasts)
		end
	)
	toggle(
		row(5, T("settings_boosters")),
		"Boosters",
		not settings.hideBoosters,
		T("settings_shown"),
		T("settings_hidden"),
		function()
			set("hideBoosters", not settings.hideBoosters)
		end
	)
	-- 6. move and resize the buttons, the notifications, the booster bar
	local layout = Ui.button(
		content,
		T("settings_layout"),
		UDim2.new(1, 0, 0, ROW - 6),
		UDim2.fromOffset(0, 5 * ROW),
		Ui.colors.buttonBlue
	)
	layout.Name = "Layout"
	layout.Activated:Connect(openLayout)
	return win
end

return SettingsWindow
