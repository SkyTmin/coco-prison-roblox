--!strict
-- Achievements [L] like the original [вики 26.10 «Достижения»; владелец 27.10: «меню достижений тоже надо переделать
-- как по скриншотам»]: a grid of «Копатель (<блок>)» cards — block icon, green name, the tier in grey on the right,
-- 10 stars (yellow = claimed tiers), «НАКОПАЙТЕ N», a blue bar have / target, «НАГРАДА» with its icon. Only the
-- cards of open floors show; the header counts fully completed cards. Rewards are credited by the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Boosters = require(Shared.Boosters)
local BlockColors = require(Shared.BlockColors)
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local AchievementsWindow = {}

local CARD_W, CARD_H, GAP = 250, 122, 8
local STAR_YELLOW = Color3.fromRGB(255, 205, 40)
local STAR_GREY = Color3.fromRGB(70, 70, 78)
local BAR_BLUE = Color3.fromRGB(60, 140, 255)

local function cardName(card: Achievements.Card, locale: string): string
	local what = if card.counter
		then Strings.counterName(card.counter, locale)
		else Strings.blockName(card.id, Config.blocks[card.id].name, locale)
	return Strings.t("digger_card", locale, what)
end

local function image(parent: Instance, size: number, position: UDim2, id: string?): ImageLabel
	local i = Instance.new("ImageLabel")
	i.Size = UDim2.fromOffset(size, size)
	i.Position = position
	i.BackgroundTransparency = 1
	i.ScaleType = Enum.ScaleType.Fit
	i.ResampleMode = Enum.ResamplerMode.Pixelated
	i.Image = id or ""
	i.Parent = parent
	return i
end

-- reward line: money check (green, money icon) or local booster (its bottle)
local function rewardView(
	card: Achievements.Card,
	tier: number,
	locale: string
): (string, string?, Color3)
	local reward = Achievements.reward(card, tier)
	if reward.booster then
		local scope = reward.scope or "local"
		return string.format(
			"%s x%s",
			Strings.t("booster_" .. reward.booster, locale),
			tostring(Config.boosters.localMultiplier)
		),
			Boosters.icon(reward.booster, scope),
			Boosters.SCOPE_COLORS[scope]
	end
	return Strings.grouped((reward.money or 0) / Config.moneyScale, 0) .. " $",
		Config.icons.icons.money,
		Ui.colors.money
end

function AchievementsWindow.build(
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
		T("achievements"),
		UDim2.fromOffset(3 * CARD_W + 2 * GAP + 30, 470),
		onClose
	)
	local hint = Ui.label(
		content,
		T("achievements_hint"),
		UDim2.new(1, -90, 0, 20),
		UDim2.fromOffset(4, 0),
		12,
		Ui.colors.muted
	)
	hint.TextTruncate = Enum.TextTruncate.AtEnd
	local doneLabel = Ui.label(
		content,
		"",
		UDim2.fromOffset(80, 20),
		UDim2.new(1, -84, 0, 0),
		15,
		Ui.colors.header
	)
	doneLabel.TextXAlignment = Enum.TextXAlignment.Right

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -26)
	list.Position = UDim2.fromOffset(0, 24)
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

	local updates: { (Types.Profile) -> (boolean, boolean) } = {}
	for index, card in ipairs(Achievements.cards) do
		local frame = Ui.card(list, UDim2.fromOffset(CARD_W, CARD_H), UDim2.new())
		frame.Name = "Card_" .. card.id
		frame.LayoutOrder = index
		frame.Visible = false
		local picture, tint = BlockColors.icon(card.icon)
		image(frame, 40, UDim2.fromOffset(8, 8), picture).ImageColor3 = tint
		local name = Ui.label(
			frame,
			cardName(card, locale),
			UDim2.new(1, -96, 0, 18),
			UDim2.fromOffset(56, 6),
			13,
			Ui.colors.green
		)
		name.TextScaled = true
		local limit = Instance.new("UITextSizeConstraint")
		limit.MaxTextSize = 13
		limit.Parent = name
		local tierLabel = Ui.label(
			frame,
			"",
			UDim2.fromOffset(32, 18),
			UDim2.new(1, -40, 0, 6),
			13,
			Ui.colors.gray
		)
		tierLabel.TextXAlignment = Enum.TextXAlignment.Right
		local stars: { TextLabel } = {}
		for i = 1, Achievements.tiers do
			local star = Ui.label(
				frame,
				"★",
				UDim2.fromOffset(17, 16),
				UDim2.fromOffset(54 + (i - 1) * 18, 28),
				15,
				STAR_GREY
			)
			star.TextXAlignment = Enum.TextXAlignment.Center
			stars[i] = star
		end
		local goal = Ui.label(
			frame,
			"",
			UDim2.new(1, -16, 0, 16),
			UDim2.fromOffset(8, 52),
			12,
			Ui.colors.text
		)
		local bar = Instance.new("Frame")
		bar.Size = UDim2.new(1, -16, 0, 16)
		bar.Position = UDim2.fromOffset(8, 70)
		bar.BackgroundColor3 = Ui.colors.inset
		bar.BorderSizePixel = 0
		bar.Parent = frame
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = BAR_BLUE
		fill.BorderSizePixel = 0
		fill.Parent = bar
		local barText = Ui.label(bar, "", UDim2.fromScale(1, 1), UDim2.new(), 11, Ui.colors.white)
		barText.TextXAlignment = Enum.TextXAlignment.Center
		barText.ZIndex = 2
		local rewardTitle = Ui.label(
			frame,
			T("achievement_reward_label"),
			UDim2.fromOffset(90, 22),
			UDim2.fromOffset(8, 92),
			12,
			Ui.colors.muted
		)
		rewardTitle.AutomaticSize = Enum.AutomaticSize.X
		local rewardIcon = image(frame, 18, UDim2.fromOffset(100, 94), nil)
		local rewardText = Ui.label(
			frame,
			"",
			UDim2.new(1, -130, 0, 22),
			UDim2.fromOffset(122, 92),
			12,
			Ui.colors.money
		)
		rewardText.TextTruncate = Enum.TextTruncate.AtEnd

		table.insert(updates, function(p: Types.Profile): (boolean, boolean)
			local visible = Achievements.visible(p, card)
			frame.Visible = visible
			if not visible then
				return false, false
			end
			local claimed = Achievements.claimed(p, card)
			local have = Achievements.progress(p, card)
			local complete = claimed >= Achievements.tiers
			local tier = math.min(claimed + 1, Achievements.tiers)
			local target = Achievements.threshold(tier)
			tierLabel.Text = tostring(tier)
			for i, star in ipairs(stars) do
				star.TextColor3 = if i <= claimed then STAR_YELLOW else STAR_GREY
			end
			if complete then
				goal.Text = T("achievement_done_short")
				goal.TextColor3 = Ui.colors.money
				fill.Size = UDim2.fromScale(1, 1)
				fill.BackgroundColor3 = Ui.colors.buttonGreen
				barText.Text = Strings.big(have)
				rewardTitle.Visible, rewardIcon.Visible, rewardText.Visible = false, false, false
			else
				goal.Text = T("achievement_collect", Strings.big(target))
				goal.TextColor3 = Ui.colors.text
				fill.Size = UDim2.fromScale(math.clamp(have / target, 0, 1), 1)
				fill.BackgroundColor3 = BAR_BLUE
				barText.Text = string.format("%s / %s", Strings.big(have), Strings.big(target))
				local text, icon, color = rewardView(card, tier, locale)
				rewardTitle.Visible, rewardIcon.Visible, rewardText.Visible =
					true, icon ~= nil, true
				rewardIcon.Image = icon or ""
				rewardText.Text = text
				rewardText.TextColor3 = color
			end
			return true, complete
		end)
	end

	local function refresh(p: Types.Profile?)
		if not p then
			return
		end
		local shown, done = 0, 0
		for _, update in ipairs(updates) do
			local visible, complete = update(p)
			if visible then
				shown += 1
				if complete then
					done += 1
				end
			end
		end
		doneLabel.Text = string.format("%d / %d", done, shown)
	end
	refresh(profile)
	return win, refresh
end

return AchievementsWindow
