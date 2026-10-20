--!strict
-- [решение] Owner-specified progression: 12 tiers, rounded 64 × 1.7^(tier - 1), $10 per tier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)

local BLOCKS: { [string]: string } = {
	digger_dirt = "dirt",
	digger_sand = "sand",
	digger_gravel = "gravel",
	digger_coal_ore = "coal_ore",
	digger_oak_log = "oak_log",
}
local AchievementService = {}
local started = false

local function claim(player: Player, id: any, tier: any)
	if typeof(id) ~= "string" or typeof(tier) ~= "number" then
		return
	end
	if tier ~= tier or tier < 1 or tier > 12 or tier ~= math.floor(tier) then
		return
	end
	local blockId = BLOCKS[id]
	local block = if blockId then Config.block(blockId) else nil
	if not block or not block.upgradeCounter then
		return
	end
	local counter = block.upgradeCounter
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local threshold = math.floor(64 * 1.7 ^ (tier - 1) + 0.5)
	-- Claim in order so a forged higher tier cannot discard earlier rewards.
	if
		tier ~= (profile.achievements[id] or 0) + 1
		or (profile.counters[counter] or 0) < threshold
	then
		return
	end
	local locale = Strings.localeOf(player)
	if tier % 4 == 0 and not InventoryService.canAdd(profile, "booster_money", 1) then
		Remotes.event("Toast"):FireClient(player, Strings.t("bag_full", locale))
		return
	end
	local reward = math.floor(tier * 10 * Config.moneyScale + 0.5)
	ProfileService.Mutate(player, function(p)
		p.coins += reward
		if tier % 4 == 0 then
			InventoryService.add(p, "booster_money", 1)
		end
		p.achievements[id] = tier
	end)
	Remotes.event("Toast"):FireClient(
		player,
		Strings.t("achievement_claimed", locale, Strings.t(id, locale), tier, Strings.money(reward))
	)
end

function AchievementService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("ClaimAchievement").OnServerEvent:Connect(claim)
end

return AchievementService
