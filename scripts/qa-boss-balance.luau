--!nocheck
-- Studio/Server, isolated Humanoids and deterministic reward draws. No profile writes or boss kills.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local Config = require(game.ReplicatedStorage.Shared.Config)
local Combat = require(game.ReplicatedStorage.Shared.Combat)
local Limit = require(game.ServerScriptService.Server.Services.BossDamage).Limit
local Loot = require(game.ReplicatedStorage.Shared.BossLoot)
local count = 0
local function check(ok, label)
	assert(ok, label)
	count += 1
end
local cards = {}
for _, card in Config.bosses.bosses do cards[card.id] = card end
local h = Instance.new("Humanoid")
h.MaxHealth = 54
check(math.abs(Limit(h, 999, 10) - 35.1) < 1e-6, "full health survives strongest raw hit")
check(Limit(h, 999, 10.74) == 0, "overlapping skill / summon blocked")
check(math.abs(Limit(h, 999, 10.76) - 35.1) < 1e-6, "window expires")
h:Destroy()
h = Instance.new("Humanoid"); h.MaxHealth = 20
check(Limit(h, 4, 0) == 4, "small hits retain real damage")
check(Limit(h, 4, .4) == 4, "successive small hits")
check(Limit(h, 99, .74) == 5, "burst fills remaining budget")
check(Limit(h, 99, .76) == 4, "rolling window, no reset exploit")
check(Limit(h, 99, 1.14) == 0, "later hits still consume budget")
h:Destroy()
local armor = {}
for _, slot in {"helmet", "chestplate", "leggings", "boots"} do armor[slot] = {level = 15} end
local armored = Combat.armorReduce(cards.reaper.fight.meleeDamage, armor)
check(armored >= 14 and armored < 22, "late melee substantial through diamond Protection II")
for _, card in Config.bosses.bosses do
	h = Instance.new("Humanoid"); h.MaxHealth = 20 + card.unlockLevel - 1
	local heavy = math.max(card.fight.meleeDamage, card.fight.charge.damage, card.fight.earthSpikes.damage)
	check(Limit(h, heavy, 1) < h.MaxHealth, card.id .. " no unarmored full-health one-shot")
	h:Destroy()
end
local low = {NextNumber = function() return 0 end, NextInteger = function(_, a) return a end}
local high = {NextNumber = function() return .999999 end, NextInteger = function(_, _, b) return b end}
for _, card in Config.bosses.bosses do
	check(next(Loot.Roll(card, .049, true, low)) == nil, card.id .. " participation threshold")
	local noLast, last = Loot.Roll(card, .2, false, low), Loot.Roll(card, .2, true, low)
	check(noLast.ancient_powder == nil and noLast.fire_shard == nil and noLast.moon_steel == nil, card.id .. " last-hit ownership")
	if card.ancientStars then
		check(noLast.ancient_star == card.ancientStars[1] and Loot.Roll(card, .2, false, high).ancient_star == card.ancientStars[2], card.id .. " star range")
	end
	if card.powderChance then
		check(last.ancient_powder == 1 and Loot.Roll(card, 1, true, high).ancient_powder == nil, card.id .. " powder roll works")
	end
	for _, id in Config.bosses.rewards.lastHitItems[card.id] or {} do check(last[id] == 1, card.id .. " " .. id) end
end
for _, id in {"piglin", "splinter", "reaper"} do
	local drops = 0
	for i = 1, 10000 do
		local rng = {NextNumber = function() return (i-.5)/10000 end, NextInteger = low.NextInteger}
		if Loot.Roll(cards[id], .25, true, rng).ancient_powder then drops += 1 end
	end
	local expected = ({piglin=150,splinter=200,reaper=1325})[id]
	check(drops == expected, id .. " deterministic 10000-draw probability")
end
local out = {checks = count, reaperArmoredMelee = armored, status = "PASS"}
local result = game.ServerStorage:FindFirstChild("QABossBalanceResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QABossBalanceResult", game:GetService("HttpService"):JSONEncode(out), game.ServerStorage
return result.Value
