--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local AchievementsWindow = {}

function AchievementsWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local win, content =
		createWindow(parent, Strings.t("achievements", locale), UDim2.fromOffset(792, 370), onClose)
	local updates: { (Types.Profile?) -> () } = {}
	local cfg = Config.achievementsCfg
	for index, chain in ipairs({ "pickaxe", "shovel", "axe", "sword" }) do
		local card =
			Ui.panel(content, UDim2.new(0.25, -8, 1, -4), UDim2.new((index - 1) / 4, 4, 0, 2))
		local icon = Instance.new("ImageLabel")
		icon.Size = UDim2.fromOffset(28, 28)
		icon.Position = UDim2.fromOffset(6, 4)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.iconFor(chain, 1) or ""
		icon.Parent = card
		Ui.label(
			card,
			Strings.t("item_" .. chain, locale),
			UDim2.new(1, -44, 0, 28),
			UDim2.fromOffset(38, 4),
			13,
			Ui.colors.header
		)
		local summaryLabel = Ui.label(
			card,
			"",
			UDim2.new(1, -12, 0, 22),
			UDim2.fromOffset(6, 32),
			11,
			Ui.colors.money
		)
		summaryLabel.TextWrapped = true
		table.insert(updates, function(p: Types.Profile?)
			local claimed = if p then math.clamp(p.achievements[chain] or 0, 0, cfg.tiers) else 0
			local count = if p then (p.counters[cfg.chains[chain].counter] or 0) else 0
			local nextTier = math.min(claimed + 1, cfg.tiers)
			local threshold = math.round(cfg.thresholdBase * cfg.thresholdGrowth ^ (nextTier - 1))
			summaryLabel.Text = if claimed == cfg.tiers
				then Strings.t("achievement_complete", locale)
				else string.format("%d / %d", count, threshold)
		end)
		for tier = 1, cfg.tiers do
			local threshold = math.round(cfg.thresholdBase * cfg.thresholdGrowth ^ (tier - 1))
			local reward =
				math.round(cfg.rewardFirst * cfg.rewardGrowth ^ (tier - 1) * Config.moneyScale)
			local row =
				Ui.panel(card, UDim2.new(1, -12, 0, 20), UDim2.fromOffset(6, 56 + (tier - 1) * 22))
			local thresholdLabel =
				Ui.label(row, "", UDim2.new(0.58, 0, 0, 19), UDim2.fromOffset(3, 0), 11)
			local money = Ui.label(
				row,
				Strings.money(reward) .. " $",
				UDim2.new(0.42, -5, 0, 19),
				UDim2.fromScale(0.58, 0),
				11
			)
			money.TextXAlignment = Enum.TextXAlignment.Right
			local fill = Instance.new("Frame")
			fill.Position = UDim2.new(0, 0, 1, -2)
			fill.BorderSizePixel = 0
			fill.Parent = row
			table.insert(updates, function(p: Types.Profile?)
				local claimed = if p then (p.achievements[chain] or 0) else 0
				local count = if p then (p.counters[cfg.chains[chain].counter] or 0) else 0
				local nextReward = tier == claimed + 1
				local color = if tier <= claimed
					then Ui.colors.money
					elseif nextReward then Ui.colors.header
					else Ui.colors.muted
				row.BackgroundColor3 = if nextReward then Ui.colors.buttonGrey else Ui.colors.slot
				thresholdLabel.Text = string.format(
					"%s%d  %d",
					if tier <= claimed then "✓" else "",
					tier,
					threshold
				)
				thresholdLabel.TextColor3, money.TextColor3 = color, color
				fill.Size = UDim2.new(math.clamp(count / threshold, 0, 1), 0, 0, 2)
				fill.BackgroundColor3 = color
			end)
		end
	end
	local function refresh(p: Types.Profile?)
		for _, update in ipairs(updates) do
			update(p)
		end
	end
	refresh(profile)
	return win, refresh
end

return AchievementsWindow
