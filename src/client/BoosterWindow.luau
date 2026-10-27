--!strict
-- «Хранилище бустеров» [B] [вики DONATE-SHOP-BOOSTERS; владелец 27.10: «раз появляются бустеры, нужно им и
-- хранилище»]: «Бустеров: N», tabs Все / Блоки / Деньги / Мобы, a card per stored booster (its bottle,
-- «Локальный Бустер денег», «x1.1 · 30 мин», how many, «Активировать»); empty — «Здесь пока что ничего нет…».
-- Running and queued boosters show in the HUD plaque (BoosterHud). The server starts or queues (BoosterService).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local BoosterWindow = {}

local CARD_W, CARD_H, GAP = 290, 78, 8
local TABS = { "all", "blocks", "money", "mobs" }

function BoosterWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(
		parent,
		T("boosters_title"),
		UDim2.fromOffset(2 * CARD_W + GAP + 30, 420),
		onClose
	)
	local countLabel = Ui.label(
		content,
		"",
		UDim2.fromOffset(200, 26),
		UDim2.fromOffset(4, 0),
		15,
		Ui.colors.header
	)

	local tab = "all"
	local current: Types.Profile? = profile
	local tabButtons: { [string]: TextButton } = {}
	local refresh: (Types.Profile?) -> ()
	for i, kind in ipairs(TABS) do
		local button = Ui.button(
			content,
			T("boosters_tab_" .. kind),
			UDim2.fromOffset(84, 26),
			UDim2.new(1, -(#TABS - i + 1) * 88, 0, 0),
			Ui.colors.buttonGrey
		)
		button.TextSize = 14
		button.Name = "Tab_" .. kind
		button.Activated:Connect(function()
			tab = kind
			refresh(current)
		end)
		tabButtons[kind] = button
	end

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -34)
	list.Position = UDim2.fromOffset(0, 32)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Ui.colors.border
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = content
	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(CARD_W, CARD_H)
	grid.CellPadding = UDim2.fromOffset(GAP, GAP)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 2)
	pad.PaddingLeft = UDim.new(0, 2)
	pad.Parent = list

	local empty = Ui.label(
		content,
		T("boosters_empty"),
		UDim2.new(1, 0, 0, 30),
		UDim2.new(0, 0, 0.5, -15),
		16,
		Ui.colors.muted
	)
	empty.TextXAlignment = Enum.TextXAlignment.Center

	local function card(stored: Boosters.Stored, index: number, order: number)
		local frame = Ui.card(list, UDim2.fromOffset(CARD_W, CARD_H), UDim2.new())
		frame.Name = "Booster_" .. index
		frame.LayoutOrder = order
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(48, 48)
		icon.Position = UDim2.fromOffset(10, 15)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.icons.icons["booster_" .. stored.kind] or ""
		icon.Parent = frame
		local name = Ui.rich(
			frame,
			string.format(
				'<font color="%s"><b>%s</b></font> %s',
				Ui.hex(Ui.colors.yellow),
				T("booster_local"),
				T("booster_" .. stored.kind)
			),
			UDim2.new(1, -76, 0, 20),
			UDim2.fromOffset(68, 8),
			14
		)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		Ui.label(
			frame,
			T("booster_card_mult", tostring(stored.mult), stored.minutes),
			UDim2.fromOffset(120, 18),
			UDim2.fromOffset(68, 30),
			13,
			Ui.colors.cyan
		)
		if stored.count > 1 then
			local count = Ui.label(
				frame,
				"×" .. stored.count,
				UDim2.fromOffset(60, 18),
				UDim2.new(1, -68, 0, 30),
				14,
				Ui.colors.header
			)
			count.TextXAlignment = Enum.TextXAlignment.Right
		end
		local button = Ui.button(
			frame,
			T("booster_activate"),
			UDim2.fromOffset(130, 24),
			UDim2.new(1, -138, 1, -30),
			Ui.colors.buttonGreen
		)
		button.TextSize = 14
		button.Activated:Connect(function()
			Remotes.event("ActivateBooster"):FireServer(index)
		end)
	end

	refresh = function(p: Types.Profile?)
		current = p
		for _, child in ipairs(list:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
		for kind, button in pairs(tabButtons) do
			button.BackgroundColor3 = if kind == tab
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		local stored = (if p then p.boosters else nil) or {}
		local shown = 0
		for index, s in ipairs(stored) do
			if tab == "all" or s.kind == tab then
				shown += 1
				-- kinds in the tab order, then as stored
				card(s, index, (table.find(Boosters.kinds, s.kind) or 9) * 1000 + index)
			end
		end
		countLabel.Text = T("boosters_count", if p then Boosters.storedCount(p) else 0)
		empty.Visible = shown == 0
	end
	refresh(profile)
	return win, refresh
end

return BoosterWindow
