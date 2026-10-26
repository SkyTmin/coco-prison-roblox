--!strict
-- Selling, shops, item upgrades and level-ups. Everything is computed from the live profile.
-- NPC markup: BaseParts tagged "SellPoint", "ItemShop", "FoodShop" get a ProximityPrompt; the client
-- opens the matching window when triggered (server fires OpenMenu).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local ProfessionService = require(script.Parent.ProfessionService)

local SHOP_PRICES: { [string]: number } = { shovel = 4, axe = 4, pickaxe = 22.5, shears = 4000 } -- [меню]
local FOOD_PRICES: { [string]: number } = { apple = 0.03, bread = 0.25, cooked_chicken = 0.5 } -- [меню]
local PROMPTS = {
	SellPoint = "sell",
	ItemShop = "shop",
	FoodShop = "food",
	StarExchange = "stars",
	ShardExchange = "shards",
	TrainerNpc = "trainer",
}

local EconomyService = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function units(dollars: number): number
	return math.floor(dollars * Config.moneyScale + 0.5)
end

-- Server-side proximity to an NPC of the given tag (menus are opened by prompt, but the remote
-- itself must also be used next to the NPC).
local NPC_RANGE = 16 -- prompt shows at 10, a couple of steps of slack while the window is open
local function nearNpc(player: Player, tag: string): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return false
	end
	for _, npc in ipairs(CollectionService:GetTagged(tag)) do
		if
			npc:IsA("BasePart")
			and npc:IsDescendantOf(workspace)
			and (npc.Position - root.Position).Magnitude <= NPC_RANGE
		then
			return true
		end
	end
	return false
end

local function exchange(player: Player, kind: any, id: any, rawCount: any)
	if typeof(kind) ~= "string" or typeof(id) ~= "string" then
		return
	end
	-- −/+ in the exchanger window: 1..64 exchanges at once [меню]
	local count = if typeof(rawCount) == "number"
			and rawCount == rawCount
			and rawCount >= 1
			and rawCount <= 64
		then math.floor(rawCount)
		else 1
	local input: string
	local cost: number
	local tag: string
	if kind == "stars" then
		local price = Config.market.starExchange[id]
		if typeof(price) ~= "number" then
			return
		end
		input, cost, tag = "ancient_star", price, "StarExchange"
	elseif kind == "shards" then
		local offer = Config.market.shardExchange[id]
		if typeof(offer) ~= "table" then
			return
		end
		input, cost, tag = offer.input, offer.count, "ShardExchange"
	else
		return
	end
	if not ProfileService.Get(player) then
		return
	end
	if not nearNpc(player, tag) then
		toast(player, "too_far")
		return
	end
	local result = ""
	ProfileService.Mutate(player, function(p)
		if InventoryService.count(p, input) < cost * count then
			result = "exchange_need_items"
			return
		end
		if not InventoryService.canAdd(p, id, count) then
			result = "bag_full"
			return
		end
		-- No yields: inputs and output change atomically, using only the server offer.
		InventoryService.remove(p, input, cost * count)
		InventoryService.add(p, id, count)
		result = "exchanged"
	end)
	if result ~= "" then
		toast(player, result, Strings.itemName(id, nil, Strings.localeOf(player)))
	end
end

local function sell(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	if not nearNpc(player, "SellPoint") then
		toast(player, "too_far")
		return
	end
	local total = 0
	ProfileService.Mutate(player, function(p)
		total = InventoryService.sellAll(p, ProfessionService.moneyMultiplier(p))
		p.coins += total
	end)
	if total > 0 then
		toast(player, "sold", Strings.money(total))
		Sfx.toPlayer(player, "xp", 0.5)
	else
		toast(player, "nothing_to_sell")
	end
end

local function buy(player: Player, id: any)
	if typeof(id) ~= "string" then
		return
	end
	local price = SHOP_PRICES[id] or FOOD_PRICES[id]
	if not price then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	if not nearNpc(player, if SHOP_PRICES[id] then "ItemShop" else "FoodShop") then
		toast(player, "too_far")
		return
	end
	if profile.coins < units(price) then
		toast(player, "not_enough_money")
		return
	end
	local overflow = 0
	ProfileService.Mutate(player, function(p)
		p.coins -= units(price)
		overflow = InventoryService.add(p, id, 1, if Config.tools[id] then 1 else nil)
		if overflow > 0 then
			p.coins += units(price) -- refund when it does not fit
		end
	end)
	if overflow > 0 then
		toast(player, "bag_full")
	else
		toast(player, "bought", Strings.itemName(id, 1, Strings.localeOf(player)))
	end
end

-- Upgrades one specific item [владелец 21.10]: `target` is an inventory slot (number) or an equipped
-- armor part ("helmet"…). The counters belong to the player (blocks dug in total), so a new tool
-- starts at level 1 and climbs level by level as long as the player meets each requirement.
local function upgrade(player: Player, target: any)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local slot: number? = nil
	local stack: Types.ItemStack? = nil
	if InventoryService.isSlot(target) then
		slot, stack = target, profile.inventory[target]
	elseif typeof(target) == "string" and profile.armor[target] then
		stack = profile.armor[target]
	end
	if not stack or not Config.tools[stack.id] then
		return
	end
	local id = stack.id
	local up = Config.upgrade(id, stack.level or 1)
	if not up then
		toast(player, "upgrade_max")
		return
	end
	local missing = {}
	if profile.coins < units(up.cost) then
		table.insert(missing, Strings.money(units(up.cost)) .. " $")
	end
	for counter, needed in pairs(up.requirements) do
		local have = Config.requirementHave(profile, counter)
		if needed and have < needed then
			table.insert(
				missing,
				string.format("%s %s/%s", counter, Strings.big(have), Strings.big(needed))
			)
		end
	end
	if #missing > 0 then
		toast(player, "upgrade_need", table.concat(missing, ", "))
		return
	end
	ProfileService.Mutate(player, function(p)
		p.coins -= units(up.cost)
		local item = if slot then p.inventory[slot] else p.armor[target]
		if item and item.id == id then
			item.level = up.to
		end
	end)
	Sfx.toPlayer(player, "enchant", 0.6)
	toast(player, "upgraded", Strings.itemName(id, up.to, Strings.localeOf(player)), up.to)
end

local function levelUp(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local rule = Config.levelRule(profile.level + 1)
	if not rule then
		toast(player, "level_max")
		return
	end
	if profile.blocksTotal < rule.blocks then
		toast(
			player,
			"level_need_blocks",
			Strings.big(profile.blocksTotal),
			Strings.big(rule.blocks)
		)
		return
	end
	if profile.coins < units(rule.money) then
		toast(player, "level_need_money", Strings.money(profile.coins), Strings.big(rule.money))
		return
	end
	ProfileService.Mutate(player, function(p)
		p.coins -= units(rule.money)
		p.level = rule.level
	end)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = rule.hearts * 2
		humanoid.Health = humanoid.MaxHealth
	end
	toast(player, "level_reached", rule.level)
	Sfx.toPlayer(player, "level_up", 0.7)
end

local function bindPrompt(part: Instance, kind: string, tag: string)
	if not part:IsA("BasePart") then
		return
	end
	local prompt = part:FindFirstChildOfClass("ProximityPrompt") or Instance.new("ProximityPrompt")
	prompt.ActionText =
		Strings.t(if kind == "stars" or kind == "shards" then "exchange" else kind .. "_prompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	-- The tag sits on the rig's HumanoidRootPart, which is inside the torso: with line of sight the
	-- prompt was hidden by the NPC's own body and the buyer/shops could not be opened at all.
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part:IsDescendantOf(workspace) and nearNpc(player, tag) then
			Remotes.event("OpenMenu"):FireClient(player, kind)
		end
	end)
end

function EconomyService.Start()
	for tag, kind in pairs(PROMPTS) do
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bindPrompt(part, kind, tag)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			bindPrompt(part, kind, tag)
		end)
	end
	Remotes.event("Sell").OnServerEvent:Connect(sell)
	Remotes.event("BuyItem").OnServerEvent:Connect(buy)
	Remotes.event("Exchange").OnServerEvent:Connect(exchange)
	Remotes.event("UpgradeItem").OnServerEvent:Connect(upgrade)
	Remotes.event("LevelUp").OnServerEvent:Connect(levelUp)
	Remotes.event("InventoryMove").OnServerEvent:Connect(function(player, from, to, count)
		if InventoryService.isSlot(from) and InventoryService.isSlot(to) then
			ProfileService.Mutate(player, function(p)
				InventoryService.move(p, from, to, if typeof(count) == "number" then count else nil)
			end)
		end
	end)
	Remotes.event("SelectSlot").OnServerEvent:Connect(function(player, n)
		if typeof(n) == "number" and n >= 1 and n <= 9 and n == math.floor(n) then
			ProfileService.Mutate(player, function(p)
				p.selectedSlot = n
			end)
		end
	end)
	Remotes.event("EquipArmor").OnServerEvent:Connect(function(player, slot)
		if InventoryService.isSlot(slot) then
			-- Mutate also replicates the equipped Armor attribute to the character.
			local profile = ProfileService.Get(player)
			local stack = profile and profile.inventory[slot]
			ProfileService.Mutate(player, function(p)
				InventoryService.equipArmor(p, slot)
			end)
			if stack and stack.level then
				-- armor tiers: leather / chainmail / iron / diamond (Minecraft equip sounds)
				local material = Config.materialForLevel(stack.level)
				Sfx.toPlayer(player, ({
					wood = "armor_equip_leather",
					stone = "armor_equip_chain",
					iron = "armor_equip_iron",
					diamond = "armor_equip_diamond",
				})[material] or "armor_equip", 0.6)
			end
		end
	end)
	Remotes.event("UnequipArmor").OnServerEvent:Connect(function(player, part, slot)
		if typeof(part) == "string" then
			ProfileService.Mutate(player, function(p)
				InventoryService.unequipArmor(
					p,
					part,
					if typeof(slot) == "number" then slot else nil
				)
			end)
		end
	end)
	Remotes.event("ClaimPoints").OnServerEvent:Connect(function(player)
		-- Points are granted on level-up already; the button exists for parity with the original UI.
		ProfileService.Replicate(player)
	end)
end

EconomyService.SHOP_PRICES = SHOP_PRICES
EconomyService.FOOD_PRICES = FOOD_PRICES
return EconomyService
