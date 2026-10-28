--!strict
-- «Копатель (<блок>)» achievements (shared/Achievements): every dug block moves its card; each reached tier pays at
-- once, like the original's auto-credited money checks, or puts a local booster into the storage. Toasts as in the
-- original: «Вы выполнили достижение … ! Поздравляем!», then «Вы получили награду …».
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Achievements)
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
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

-- After DigService counted the block (p.counters for counter cards); blocks without a counter count here.
function AchievementService.OnDug(player: Player, blockId: string)
	local card = Achievements.cardFor(blockId)
	if not card or not ProfileService.Get(player) then
		return
	end
	local rewards: { Achievements.Reward } = {}
	ProfileService.Mutate(player, function(p)
		if not card.counter then
			p.dug = p.dug or {}
			p.dug[card.id] = (p.dug[card.id] or 0) + 1
		end
		local progress = Achievements.progress(p, card)
		for tier = Achievements.claimed(p, card) + 1, Achievements.tiers do
			if progress < Achievements.threshold(tier) then
				break
			end
			local reward = Achievements.reward(card, tier)
			if reward.booster then
				Boosters.store(p, reward.booster, reward.scope)
			else
				p.coins += reward.money or 0
			end
			p.achievements[card.id] = tier
			table.insert(rewards, reward)
		end
	end)
	if #rewards == 0 then
		return
	end
	local locale = Strings.localeOf(player)
	local name = AchievementService.cardName(card, locale)
	local toast = Remotes.event("Toast")
	for _, reward in ipairs(rewards) do
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
				if have < card.steps[step].count then
					break
				end
				local reward = Achievements.statReward(card.steps[step])
				if reward.booster then
					Boosters.store(p, reward.booster, reward.scope)
				else
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

function AchievementService.Start() end

return AchievementService
