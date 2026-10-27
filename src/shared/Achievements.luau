--!strict
-- «Копатель (<блок>)» cards [вики 26.10 «Достижения»; владелец 27.10: «дают деньги за определённые блоки накопанные и
-- достижения появляются когда открываются этажи»]: one card per mine block (an upgrade counter such as Камень joins
-- its blocks), shown once its first floor is open. Thresholds double from tier to tier, progress is never reset;
-- each tier pays a money check (or a local booster on scripts/design-decisions.json boosterTiers). Shared by
-- AchievementService (grants) and AchievementsWindow.
local Config = require(script.Parent.Config)

export type Card = {
	id: string, -- p.achievements key: the counter name or the block id
	counter: string?, -- progress lives in p.counters[counter] (upgrade requirements count the same blocks)
	blocks: { string },
	unlockLevel: number,
	location: string,
	icon: string, -- block id
	price: number, -- $ per block, for the money check
}
export type Reward = { money: number?, booster: string?, scope: string? }

local Achievements = {}
local cfg = Config.achievementsCfg

Achievements.cards = cfg.cards :: { Card }
Achievements.tiers = cfg.tiers :: number

local byBlock: { [string]: Card } = {}
for _, card in ipairs(Achievements.cards) do
	for _, id in ipairs(card.blocks) do
		byBlock[id] = card
	end
end

function Achievements.cardFor(blockId: string): Card?
	return byBlock[blockId]
end

function Achievements.threshold(tier: number): number
	return math.round(cfg.thresholdBase * cfg.thresholdGrowth ^ (tier - 1))
end

-- money in 1/moneyScale units, or a booster: kind (blocks / money / mobs) and scope (nil = local)
function Achievements.reward(card: Card, tier: number): Reward
	local booster = cfg.boosterTiers[tostring(tier)]
	if booster then
		return { booster = booster.kind, scope = booster.scope }
	end
	local dollars = math.max(
		cfg.rewardMin,
		math.round(Achievements.threshold(tier) * card.price * cfg.rewardFactor)
	)
	return { money = dollars * Config.moneyScale }
end

function Achievements.progress(p: any, card: Card): number
	if card.counter then
		return p.counters[card.counter] or 0
	end
	return if p.dug then p.dug[card.id] or 0 else 0
end

function Achievements.claimed(p: any, card: Card): number
	return math.clamp(p.achievements[card.id] or 0, 0, Achievements.tiers)
end

function Achievements.visible(p: any, card: Card): boolean
	return p.level >= card.unlockLevel
end

-- tiers reached by progress alone (the migration marks them claimed without paying)
function Achievements.satisfied(count: number): number
	local tier = 0
	while tier < Achievements.tiers and count >= Achievements.threshold(tier + 1) do
		tier += 1
	end
	return tier
end

return Achievements
