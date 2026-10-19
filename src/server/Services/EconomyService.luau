--!strict
-- Selling and level-ups. Both are computed on the server from the live profile;
-- the client never sends amounts (PROTOTYPE-SPEC.md §4, §14).
-- Sell points: any BasePart tagged "SellPoint" (a ProximityPrompt is created if missing).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local SELL_TAG = "SellPoint"

local EconomyService = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function sell(player: Player)
	if not ProfileService.Get(player) then
		return
	end
	local total = 0
	ProfileService.Mutate(player, function(p)
		for id, count in pairs(p.inventory) do
			local resource = Config.resource(id)
			if resource and count > 0 then
				total += count * resource.coinPrice * Config.moneyScale
				p.inventory[id] = nil
			end
		end
		if total > 0 then
			p.coins += total
			if p.quests.first_sale ~= "done" then
				p.quests.first_sale = "done"
			end
		end
	end)
	if total > 0 then
		toast(player, "sold", Strings.money(total))
	else
		toast(player, "nothing_to_sell")
	end
end

local function bindSellPoint(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = Strings.t("sell_prompt")
		prompt.HoldDuration = 0.5
		prompt.MaxActivationDistance = 8
		prompt.Parent = part
	end
	-- ProximityPrompt.Triggered fires on the server with the triggering player.
	(prompt :: ProximityPrompt).Triggered:Connect(sell)
end

local function levelUp(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local locale = Strings.localeOf(player)
	local nextLevel = profile.level + 1
	local rule = Config.levelRule(nextLevel)
	if not rule or nextLevel > Config.raw.chapter.maxLevel then
		toast(player, "level_max")
		return
	end
	if profile.workCount < rule.totalWork then
		toast(player, "level_need_work", profile.workCount, rule.totalWork)
		return
	end
	local cost = rule.coinCost * Config.moneyScale
	if profile.coins < cost then
		toast(player, "level_need_coins", tostring(rule.coinCost))
		return
	end
	if rule.quest and profile.quests[rule.quest] ~= "done" then
		toast(player, "level_need_quest", Strings.t("quest_" .. rule.quest, locale))
		return
	end
	if rule.mobKills then
		for mob, needed in pairs(rule.mobKills) do
			local have = profile.mobKills[mob] or 0
			if have < needed then
				toast(player, "level_need_kills", Strings.t("mob_" .. mob, locale), have, needed)
				return
			end
		end
	end

	ProfileService.Mutate(player, function(p)
		p.coins -= cost
		p.level = nextLevel
		-- Level 3 opens the quarry: the pickaxe is granted with it (spec §3).
		if nextLevel >= 3 and (p.tools.pickaxe or 0) < 1 then
			p.tools.pickaxe = 1
		end
	end)
	toast(player, "level_reached", nextLevel)
end

function EconomyService.Start()
	for _, part in ipairs(CollectionService:GetTagged(SELL_TAG)) do
		bindSellPoint(part)
	end
	CollectionService:GetInstanceAddedSignal(SELL_TAG):Connect(bindSellPoint)
	Remotes.event("LevelUp").OnServerEvent:Connect(levelUp)
end

return EconomyService
