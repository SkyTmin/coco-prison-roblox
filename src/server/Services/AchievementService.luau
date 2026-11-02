--!strict
-- «Копатель (<блок>)» achievements (shared/Achievements): every dug block moves its card; each reached tier pays at
-- once, like the original's auto-credited money checks, or puts a local booster into the storage. Toasts as in the
-- original: «Вы выполнили достижение … ! Поздравляем!», then «Вы получили награду …».
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Numbers = require(Shared.Numbers)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local AchievementService = {}

function AchievementService.cardName(card: Achievements.Card, locale: string): string
	local what = if card.counter
		then Strings.counterName(card.counter, locale)
		else Strings.blockName(card.id, Config.blocks[card.id].name, locale)
	return Strings.t("digger_card", locale, what)
end

function AchievementService.rewardText(reward: Achievements.Reward, locale: string): string
	if reward.booster then
		return Strings.t(
			"booster_for_minutes",
			locale,
			Strings.boosterName(reward.booster, reward.scope, locale),
			Config.boosters.minutes
		)
	end
	return Strings.t(
		"money_check",
		locale,
		Strings.grouped((reward.money or 0) / Config.moneyScale, 0)
	)
end

-- After MiningStats credited the actual cells. A batch evaluates each affected card once.
-- Zero counts are used only for catch-up: they never manufacture mined cells.
function AchievementService.OnDugMany(player: Player, counts: { [string]: number })
	if not ProfileService.Get(player) then
		return
	end
	local cards: { [string]: Achievements.Card } = {}
	local increments: { [string]: number } = {}
	for blockId, count in pairs(counts) do
		local card = Achievements.cardFor(blockId)
		if card and Numbers.integer(count) then
			cards[card.id] = card
			increments[card.id] = (increments[card.id] or 0) + count
		end
	end
	if next(cards) == nil then
		return
	end
	local rewards: { { card: Achievements.Card, reward: Achievements.Reward } } = {}
	ProfileService.Mutate(player, function(p)
		for _, card in pairs(cards) do
			if not card.counter then
				p.dug = p.dug or {}
				p.dug[card.id] = (p.dug[card.id] or 0) + increments[card.id]
			end
			local progress = Achievements.progress(p, card)
			for tier = Achievements.claimed(p, card) + 1, Achievements.tiers do
				if not Numbers.finite(progress) or progress < Achievements.threshold(tier) then
					break
				end
				local reward = Achievements.reward(card, tier)
				if reward.booster then
					Boosters.store(p, reward.booster, reward.scope, nil, nil, nil, true)
				else
					if not Numbers.canCredit(p.coins, reward.money or 0) then
						break
					end
					p.coins += reward.money or 0
				end
				p.achievements[card.id] = tier
				table.insert(rewards, { card = card, reward = reward })
			end
		end
	end)
	if #rewards == 0 then
		return
	end
	local locale = Strings.localeOf(player)
	local toast = Remotes.event("Toast")
	for _, entry in ipairs(rewards) do
		local name = AchievementService.cardName(entry.card, locale)
		local reward = entry.reward
		toast:FireClient(player, Strings.t("achievement_done", locale, name))
		toast:FireClient(
			player,
			Strings.t(
				"achievement_reward",
				locale,
				AchievementService.rewardText(reward, locale),
				name
			)
		)
	end
end

function AchievementService.OnDug(player: Player, blockId: string)
	AchievementService.OnDugMany(player, { [blockId] = 1 })
end

-- After p.stats[stat] grew (WarzoneService: warzonePoints): pays every step of the counter achievements now reached.
function AchievementService.OnStat(player: Player, stat: string)
	for _, card in ipairs(Achievements.statCards) do
		if card.stat ~= stat then
			continue
		end
		local done: { { step: number, reward: Achievements.Reward } } = {}
		ProfileService.Mutate(player, function(p)
			local have = Achievements.statProgress(p, card)
			for step = Achievements.statClaimed(p, card) + 1, #card.steps do
				if not Numbers.finite(have) or have < card.steps[step].count then
					break
				end
				local reward = Achievements.statReward(card.steps[step])
				if reward.booster then
					Boosters.store(p, reward.booster, reward.scope, nil, nil, nil, true)
				else
					if not Numbers.canCredit(p.coins, reward.money or 0) then
						break
					end
					p.coins += reward.money or 0
				end
				p.achievements[card.id] = step
				table.insert(done, { step = step, reward = reward })
			end
		end)
		local locale = Strings.localeOf(player)
		local toast = Remotes.event("Toast")
		for _, entry in ipairs(done) do
			local name = Strings.t("achievement_" .. card.id .. "_" .. entry.step, locale)
			toast:FireClient(player, Strings.t("achievement_done", locale, name))
			toast:FireClient(
				player,
				Strings.t(
					"achievement_reward",
					locale,
					AchievementService.rewardText(entry.reward, locale),
					name
				)
			)
		end
	end
end

function AchievementService.CatchUp(player: Player)
	local counts = {}
	for _, card in ipairs(Achievements.cards) do
		counts[card.blocks[1]] = 0
	end
	AchievementService.OnDugMany(player, counts)
	local seen = {}
	for _, card in ipairs(Achievements.statCards) do
		if not seen[card.stat] then
			seen[card.stat] = true
			AchievementService.OnStat(player, card.stat)
		end
	end
end

function AchievementService.Start()
	ProfileService.OnLoaded(AchievementService.CatchUp)
end

return AchievementService
