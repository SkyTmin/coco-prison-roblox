--!strict
-- «Ежедневные награды» (/daily, the menu tile, the NPC on the spawn; этап 7) [клиент daily.*]: seven day cards in a
-- row — taken ones say «Получено», today's glows with «Получить», the rest «Недоступно»; under them «Заберите награду
-- за вход в игру» or «Награда доступна через 5:12:03», the button DailyClaim() and the canteen line (open for how long,
-- or when it opens). The server decides (DailyService); the window only reads the profile (p.daily) and the clock.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Daily = require(Shared.Daily)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)

local DailyWindow = {}

local CARD_W, CARD_H, GAP, PAD = 84, 150, 6, 14
local GOLD = Color3.fromRGB(255, 200, 60)

local function iconOf(reward: Daily.Reward): string
	if reward.money then
		return Config.iconFor("money_bag") or ""
	elseif reward.booster then
		return Boosters.icon(reward.booster, "local")
	end
	return Config.iconFor(reward.item or "") or ""
end

function DailyWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local n = Daily.CYCLE
	local width = n * CARD_W + (n - 1) * GAP + 2 * PAD
	local height = 30 + CARD_H + 110
	local win, content =
		createWindow(parent, T("daily_title"), UDim2.fromOffset(width + 12, height + 52), onClose)
	win.Name = "Window_Daily"
	Ui.titleColor(win, Ui.colors.header)

	local current = profile
	type Card = {
		frame: Frame,
		status: TextLabel,
		glow: (boolean) -> (),
		check: TextLabel,
	}
	local cards: { Card } = {}
	for day, reward in ipairs(Daily.days) do
		local frame = Kit.frame(
			content,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset(PAD + (day - 1) * (CARD_W + GAP), 6),
			Kit.CARD
		)
		Kit.corner(frame, 10)
		Kit.stroke(frame, Kit.EDGE, 1)
		local title = Kit.text(
			frame,
			T("daily_day", day),
			UDim2.new(1, 0, 0, 22),
			UDim2.fromOffset(0, 6),
			14,
			if day == n then GOLD else Ui.colors.text,
			Kit.BOLD
		)
		title.TextXAlignment = Enum.TextXAlignment.Center
		local image =
			Kit.image(frame, iconOf(reward), UDim2.fromOffset(44, 44), UDim2.new(0.5, -22, 0, 32))
		image.ScaleType = Enum.ScaleType.Fit
		image.ResampleMode = Enum.ResamplerMode.Pixelated
		local name = Kit.text(
			frame,
			Daily.rewardText(reward, locale),
			UDim2.new(1, -8, 0, 44),
			UDim2.fromOffset(4, 80),
			11,
			Ui.colors.muted
		)
		name.TextWrapped = true
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextYAlignment = Enum.TextYAlignment.Top
		local status = Kit.text(
			frame,
			"",
			UDim2.new(1, -8, 0, 18),
			UDim2.new(0, 4, 1, -24),
			12,
			Ui.colors.muted,
			Kit.BOLD
		)
		status.TextXAlignment = Enum.TextXAlignment.Center
		local check = Kit.text(
			frame,
			"✓",
			UDim2.fromOffset(22, 22),
			UDim2.new(1, -24, 0, 4),
			18,
			Kit.GOOD,
			Kit.BOLD
		)
		check.Visible = false
		cards[day] = { frame = frame, status = status, glow = Kit.glow(frame, GOLD), check = check }
	end

	local below = 6 + CARD_H + 12
	local hint = Kit.text(
		content,
		"",
		UDim2.new(1, -2 * PAD, 0, 20),
		UDim2.fromOffset(PAD, below),
		14,
		Ui.colors.text,
		Kit.BOLD
	)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	local button, buttonLabel, buttonBack = Kit.actionButton(
		content,
		UDim2.fromOffset(220, 40),
		UDim2.new(0.5, -110, 0, below + 26),
		16
	)
	local buttonGradient = Kit.gradient(buttonBack, Kit.GOOD, Kit.GOOD, 90)
	Kit.pressable(button)
	local canteen = Kit.text(
		content,
		"",
		UDim2.new(1, -2 * PAD, 0, 18),
		UDim2.fromOffset(PAD, below + 74),
		12,
		Ui.colors.muted
	)
	canteen.TextXAlignment = Enum.TextXAlignment.Center

	local ready = false
	button.Activated:Connect(function()
		if ready then
			Remotes.event("DailyClaim"):FireServer()
		end
	end)

	local shownTaken: number? = nil
	local function render()
		local t = workspace:GetServerTimeNow()
		local state = Daily.state(current or {}, t)
		for day, card in ipairs(cards) do
			local taken = day <= state.taken
			local today = not state.claimed and day == state.day
			card.check.Visible = taken
			card.glow(today)
			card.frame.BackgroundColor3 = if today then Kit.CARD_HOVER else Kit.CARD
			card.status.Text = if taken
				then T("daily_status_taken")
				elseif today then T("daily_status_take")
				else T("daily_status_locked")
			card.status.TextColor3 = if taken
				then Kit.GOOD
				elseif today then GOLD
				else Ui.colors.muted
		end
		if shownTaken and state.taken > shownTaken then
			local card = cards[state.taken]
			if card then
				Kit.flash(card.frame, GOLD)
				Kit.pop(card.frame, 1.1)
			end
		end
		shownTaken = state.taken
		ready = current ~= nil and not state.claimed
		hint.Text = if ready
			then T("daily_take_hint")
			else T("daily_wait", Daily.clock(state.nextAt - t))
		buttonLabel.Text = if ready then T("daily_take") else T("daily_taken")
		local color = if ready then Kit.GOOD else Kit.GREY
		buttonGradient.Color = ColorSequence.new(color, color)
		local open, changeAt = Daily.canteenOpen(t)
		canteen.Text = if open
			then T("daily_canteen_open", Daily.clock(changeAt - t))
			else T("daily_canteen_closed", Daily.clock(changeAt - t))
	end

	-- the countdowns tick once a second while the window lives
	local elapsed = 0
	local ticker = RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed >= 1 then
			elapsed = 0
			render()
		end
	end)
	win.Destroying:Once(function()
		ticker:Disconnect()
	end)

	render()
	return win, function(nextProfile: Types.Profile?)
		current = nextProfile
		render()
	end
end

return DailyWindow
