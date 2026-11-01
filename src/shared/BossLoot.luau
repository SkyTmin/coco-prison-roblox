--!strict
-- Card ranges come from the local wiki. Powder interpolation and shard counts are our decisions.
local Config = require(script.Parent.Config)
local BossLoot = {}

function BossLoot.Roll(card: any, share: number, isLast: boolean, random: any): { [string]: number }
	local items: { [string]: number } = {}
	if share < Config.bosses.rewards.minDamageShare then
		return items
	end
	local stars = card.ancientStars
	if typeof(stars) == "table" and #stars == 2 then
		items.ancient_star = random:NextInteger(stars[1], stars[2])
	end
	if isLast then
		local powder = card.powderChance
		local q = typeof(powder) == "table" and powder.percentQualifier or nil
		if q and typeof(q.min) == "number" and typeof(q.max) == "number" then
			local chance = (q.min + (q.max - q.min) * math.clamp(share, 0, 1)) / 100
			if random:NextNumber() < chance then
				items.ancient_powder = 1
			end
		end
		for _, shard in ipairs(Config.bosses.rewards.lastHitItems[card.id] or {}) do
			items[shard] = (items[shard] or 0) + 1
		end
	end
	return items
end

return BossLoot
