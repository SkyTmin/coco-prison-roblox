--!strict
-- «Ваши клички» (/names, /titles, /nickname, the menu tile; этап 9) [клиент ranks.*: «Нажмите, чтобы применить /
-- снять», «Выбран / Не выбран», «Недоступен»]: every nickname of Shared/Nicknames on a dark card in its tier colour —
-- owned ones can be pressed (the active one glows; pressing it takes it off), the rest are dimmed «Недоступен». Above:
-- how many are unlocked and the active one; below: «Снять кличку» and where new ones come from. The server decides
-- (NicknameSet → NicknameService); the window repaints from the profile.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Nicknames = require(Shared.Nicknames)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)

local NicknameWindow = {}

local COLS, CARD_W, CARD_H, GAP, PAD = 4, 146, 58, 6, 12
local VISIBLE_ROWS = 5
local GRID_W = COLS * CARD_W + (COLS - 1) * GAP

function NicknameWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local rows = math.ceil(#Nicknames.list / COLS)
	local listH = VISIBLE_ROWS * (CARD_H + GAP)
	local width = GRID_W + 2 * PAD + 10 -- room for the scroll bar
	local height = 48 + listH + 70
	local win, content =
		createWindow(parent, T("names_title"), UDim2.fromOffset(width + 12, height + 52), onClose)
	win.Name = "Window_Names"
	Ui.titleColor(win, Ui.colors.header)

	local current = profile
	local count = Kit.text(
		content,
		"",
		UDim2.new(0.5, -PAD, 0, 20),
		UDim2.fromOffset(PAD, 4),
		15,
		Ui.colors.text,
		Kit.BOLD
	)
	local active = Kit.text(
		content,
		"",
		UDim2.new(0.5, -PAD, 0, 20),
		UDim2.new(0.5, 0, 0, 4),
		15,
		Ui.colors.text,
		Kit.BOLD
	)
	active.TextXAlignment = Enum.TextXAlignment.Right
	Kit.fit(active)
	local hint = Kit.text(
		content,
		T("names_hint"),
		UDim2.new(1, -2 * PAD, 0, 16),
		UDim2.fromOffset(PAD, 26),
		12,
		Ui.colors.muted
	)
	hint.TextXAlignment = Enum.TextXAlignment.Left

	local scroll = Instance.new("ScrollingFrame")
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.Position = UDim2.fromOffset(PAD, 48)
	scroll.Size = UDim2.new(1, -PAD, 0, listH)
	scroll.CanvasSize = UDim2.fromOffset(0, rows * (CARD_H + GAP))
	scroll.ScrollBarThickness = 6
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = content

	type Card = {
		name: string,
		button: TextButton,
		title: TextLabel,
		status: TextLabel,
		glow: (boolean) -> (),
	}
	local cards: { Card } = {}
	for i, name in ipairs(Nicknames.list) do
		local column, row = (i - 1) % COLS, (i - 1) // COLS
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Text = ""
		button.Size = UDim2.fromOffset(CARD_W, CARD_H)
		button.Position = UDim2.fromOffset(column * (CARD_W + GAP), row * (CARD_H + GAP))
		button.BackgroundColor3 = Kit.CARD
		button.BorderSizePixel = 0
		button.Parent = scroll
		Kit.corner(button, 8)
		Kit.stroke(button, Kit.EDGE, 1)
		Kit.pressable(button)
		local tier = Nicknames.tier(name) or "common"
		local strip = Kit.frame(
			button,
			UDim2.new(0, 4, 1, -12),
			UDim2.fromOffset(4, 6),
			Nicknames.COLORS[tier]
		)
		Kit.corner(strip, 2)
		local title = Kit.text(
			button,
			name,
			UDim2.new(1, -18, 0, 20),
			UDim2.fromOffset(13, 5),
			15,
			Nicknames.COLORS[tier],
			Kit.BOLD
		)
		Kit.fit(title)
		Kit.text(
			button,
			T("nick_tier_" .. tier),
			UDim2.new(1, -18, 0, 14),
			UDim2.fromOffset(13, 24),
			11,
			Ui.colors.muted
		)
		local status = Kit.text(
			button,
			"",
			UDim2.new(1, -18, 0, 14),
			UDim2.fromOffset(13, 39),
			11,
			Ui.colors.muted,
			Kit.BOLD
		)
		local card = {
			name = name,
			button = button,
			title = title,
			status = status,
			glow = Kit.glow(button, Kit.GOOD),
		}
		cards[i] = card
		button.Activated:Connect(function()
			if not Nicknames.owns(current, name) then
				return
			end
			-- pressing the active one takes it off [клиент ranks.*]
			local selected = current ~= nil and current.nickname == name
			Remotes.event("NicknameSet"):FireServer(if selected then "" else name)
		end)
	end

	local below = 48 + listH + 8
	local clear, clearLabel, clearBack =
		Kit.actionButton(content, UDim2.fromOffset(180, 34), UDim2.fromOffset(PAD, below), 14)
	clearLabel.Text = T("names_clear")
	local clearGradient = Kit.gradient(clearBack, Kit.BAD, Kit.BAD, 90)
	Kit.pressable(clear)
	clear.Activated:Connect(function()
		if current and current.nickname then
			Remotes.event("NicknameSet"):FireServer("")
		end
	end)
	local where = Kit.text(
		content,
		T("names_where"),
		UDim2.new(1, -2 * PAD - 190, 0, 34),
		UDim2.fromOffset(PAD + 190, below),
		12,
		Ui.colors.muted
	)
	where.TextWrapped = true

	local shownNick: string? = nil
	local function render()
		local nick = if current
				and typeof(current.nickname) == "string"
				and current.nickname ~= ""
			then current.nickname
			else nil
		count.Text = T("names_count", Nicknames.ownedCount(current), #Nicknames.list)
		active.Text = T(
			"names_current",
			if nick then Kit.colored(nick, Nicknames.color(nick)) else T("names_none")
		)
		for _, card in ipairs(cards) do
			local owned = Nicknames.owns(current, card.name)
			local selected = owned and nick == card.name
			card.glow(selected)
			card.button.BackgroundColor3 = if selected then Kit.CARD_HOVER else Kit.CARD
			card.title.TextTransparency = if owned then 0 else 0.55
			card.status.Text = if selected
				then T("names_selected")
				elseif owned then T("names_not_selected")
				else T("names_locked")
			card.status.TextColor3 = if selected
				then Kit.GOOD
				elseif owned then Ui.colors.text
				else Ui.colors.muted
			if selected and shownNick ~= nick then
				Kit.pop(card.button, 1.08)
			end
		end
		shownNick = nick
		local color = if nick then Kit.BAD else Kit.GREY
		clearGradient.Color = ColorSequence.new(color, color)
	end

	render()
	return win, function(nextProfile: Types.Profile?)
		current = nextProfile
		render()
	end
end

return NicknameWindow
