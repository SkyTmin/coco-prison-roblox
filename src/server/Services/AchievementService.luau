--!strict
-- Config-driven chains. Counter changes and ordered automatic rewards share one mutation.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local cfg = Config.achievementsCfg
local AchievementService = {}
local started = false

local function grant(player: Player, chain: string, increment: number, limit: number)
	local definition = cfg.chains[chain]
	if not definition or not ProfileService.Get(player) then
		return
	end
	local rewards: { { tier: number, money: number } } = {}
	ProfileService.Mutate(player, function(p)
		local counter = definition.counter
		p.counters[counter] = (p.counters[counter] or 0) + increment
		local progress = p.counters[counter]
		for tier = (p.achievements[chain] or 0) + 1, limit do
			local threshold = math.round(cfg.thresholdBase * cfg.thresholdGrowth ^ (tier - 1))
			if progress < threshold then
				break
			end
			local money =
				math.round(cfg.rewardFirst * cfg.rewardGrowth ^ (tier - 1) * Config.moneyScale)
			p.coins += money
			p.achievements[chain] = tier
			table.insert(rewards, { tier = tier, money = money })
		end
	end)
	local locale = Strings.localeOf(player)
	for _, reward in ipairs(rewards) do
		Remotes.event("Toast"):FireClient(
			player,
			Strings.t(
				"achievement_claimed",
				locale,
				Strings.t("item_" .. chain, locale),
				reward.tier,
				Strings.money(reward.money)
			)
		)
	end
end

function AchievementService.AddProgress(player: Player, chain: string, amount: number)
	if amount > 0 and amount < math.huge and amount == math.floor(amount) then
		grant(player, chain, amount, cfg.tiers)
	end
end

local function claim(player: Player, chain: any, tier: any)
	if typeof(chain) ~= "string" or typeof(tier) ~= "number" then
		return
	end
	if tier ~= tier or tier < 1 or tier > cfg.tiers or tier ~= math.floor(tier) then
		return
	end
	-- Compatibility intent: only eligible, unclaimed tiers up to the requested tier, in order.
	grant(player, chain, 0, tier)
end

function AchievementService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("ClaimAchievement").OnServerEvent:Connect(claim)
end

return AchievementService
