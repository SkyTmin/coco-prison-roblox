--!strict
-- What a case can give, as item stacks for the read-only «Подробнее» window [владелец 28.10: «ниже «Открыть кейс» кнопку
-- «Подробнее» … открывается сундук с предметами, которые могут выпасть … оттуда нельзя забирать, только читать»; вики
-- JOBS-CASES-SPAWN: окно просмотра «Кейс с предметами» (15 предметов Обычного кейса), «Древний кейс» (все книги с
-- редкостью и подсказкой)]. Built from the same configs CaseService rolls from, with the same item shapes (the wooden
-- pickaxe with Silk Touch, level-1 armor and weapons, a book at its top level), so the tooltips say exactly what drops.
local Config = require(script.Parent.Config)
local Nicknames = require(script.Parent.Nicknames)
local Types = require(script.Parent.Types)

export type Entry = {
	stack: Types.ItemStack,
	money: { number }?, -- a money drop: { min, max } in $ (the slot shows a money bag)
	rarity: string, -- common | rare | legendary: the line under the item [владелец 28.10: «обычный, редкий, легендарный, как на скринах»]
}

local CasePreview = {}

local ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local RARITY_ORDER = { common = 1, rare = 2, legendary = 3 }

local function rewardEntries(rewards: { any }): { Entry }
	local out: { Entry } = {}
	local rarity = "common"
	local function add(stack: Types.ItemStack)
		table.insert(out, { stack = stack, rarity = rarity })
	end
	for _, reward in ipairs(rewards) do
		local id = reward.id
		rarity = reward.rarity or "common"
		if id == "food" then
			for _, food in ipairs(reward.items or {}) do
				add({ id = food, count = 1 })
			end
		elseif id == "money" then
			table.insert(out, {
				stack = {
					id = "money_bag",
					count = 1,
					coins = math.floor((reward.max or 0) * Config.moneyScale + 0.5),
				},
				money = { reward.min or 0, reward.max or 0 },
				rarity = rarity,
			})
		elseif id == "leather_armor_piece" then
			for _, piece in ipairs(ARMOR) do
				add({ id = piece, count = 1, level = 1 })
			end
		elseif id == "wooden_sword_or_bow" then
			add({ id = "sword", count = 1, level = 1 })
			add({ id = "bow", count = 1, level = 1 })
		elseif id == "booster" then
			-- the artifact case's box: a local booster of each kind (CaseService picks one)
			for _, kind in ipairs(Config.boosters.kinds) do
				add({ id = "booster_" .. kind .. "_local", count = 1 })
			end
		elseif id == "rare_wooden_pickaxe_silk_touch" then
			add({
				id = "pickaxe",
				count = 1,
				level = 1,
				books = { { id = "silk_touch", level = 1 } },
			})
		else
			add({ id = id, count = 1 })
		end
	end
	return out
end

-- every book of the Ancient case at its top level (the improved key's book), common → rare → legendary
local function bookEntries(): { Entry }
	local ids: { string } = {}
	for id in pairs(Config.books.effects) do
		table.insert(ids, id)
	end
	local function rarity(id: string): number
		local entry = Config.books.catalog[id]
		return RARITY_ORDER[entry and entry.rarity or "common"] or 1
	end
	table.sort(ids, function(a, b)
		if rarity(a) ~= rarity(b) then
			return rarity(a) < rarity(b)
		end
		return a < b
	end)
	local out: { Entry } = {}
	for _, id in ipairs(ids) do
		local entry = Config.books.catalog[id]
		local level = #Config.books.effects[id]
		table.insert(out, {
			stack = {
				id = "ancient_book",
				count = 1,
				level = level,
				books = { { id = id, level = level } },
				rarity = entry and entry.rarity or nil,
			},
			rarity = entry and entry.rarity or "common",
		})
	end
	return out
end

-- the entries of a case and, for the nickname case, its nicknames
function CasePreview.of(caseId: string): ({ Entry }, { string }?)
	if caseId == "ancientCase" then
		return bookEntries(), nil
	elseif caseId == "nicknameCase" then
		return {}, Nicknames.list -- клички (этап 9): 46, four rarity tiers
	end
	local config = Config.keys[caseId]
	local rewards = if typeof(config) == "table" then config.rewards or config else nil
	if typeof(rewards) ~= "table" or #rewards == 0 then
		return {}, nil
	end
	return rewardEntries(rewards), nil
end

return CasePreview
