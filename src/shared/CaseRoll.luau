--!strict
-- Pure random choices used by the server and by the paid-case probability description.
local Config = require(script.Parent.Config)
local AncientRoll = require(script.Parent.AncientRoll)
local CaseRoll = {}
CaseRoll.ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local ORDINARY_MIN_DRAWS, ORDINARY_MAX_DRAWS = 2, 4

function CaseRoll.ordinaryHasRoom(contents: { [number]: any }?): boolean
	local free = 0
	for slot = 1, 27 do
		if not contents or not contents[slot] then
			free += 1
			if free == ORDINARY_MAX_DRAWS then
				return true
			end
		end
	end
	return false
end

CaseRoll.ORDINARY_MAX_DRAWS = ORDINARY_MAX_DRAWS

function CaseRoll.draws(caseId: string): { any }
	if caseId ~= "ordinaryCase" then
		return { { count = 1, probability = 1 } }
	end
	local draws = {}
	local probability = 1 / (ORDINARY_MAX_DRAWS - ORDINARY_MIN_DRAWS + 1)
	for count = ORDINARY_MIN_DRAWS, ORDINARY_MAX_DRAWS do
		table.insert(draws, { count = count, probability = probability })
	end
	return draws
end

function CaseRoll.drawCount(caseId: string, random: Random): number
	return if caseId == "ordinaryCase"
		then random:NextInteger(ORDINARY_MIN_DRAWS, ORDINARY_MAX_DRAWS)
		else 1
end

function CaseRoll.select(rewards: { any }, random: Random): any
	local total = 0
	for _, reward in ipairs(rewards) do
		total += reward.weight
	end
	local value = random:NextNumber() * total
	for _, reward in ipairs(rewards) do
		value -= reward.weight
		if value < 0 then
			return reward
		end
	end
	return rewards[#rewards]
end

function CaseRoll.moneyRange(reward: any): (number, number)
	return math.floor(reward.min * Config.moneyScale + 0.5),
		math.floor(reward.max * Config.moneyScale + 0.5)
end

-- Alternatives within a selected configured reward. Count remains an independent integer.
function CaseRoll.variants(reward: any): { any }
	local ids = if reward.id == "food"
		then reward.items
		elseif reward.id == "leather_armor_piece" then CaseRoll.ARMOR
		elseif reward.id == "wooden_sword_or_bow" then { "sword", "bow" }
		elseif reward.id == "booster" then Config.boosters.kinds
		else { reward.id }
	local out = {}
	for _, rawId in ipairs(ids) do
		local id = rawId
		local level: number? = nil
		local books: { any }? = nil
		if reward.id == "leather_armor_piece" or reward.id == "wooden_sword_or_bow" then
			level, books = 1, {}
		elseif reward.id == "rare_wooden_pickaxe_silk_touch" then
			id, level, books = "pickaxe", 1, { { id = "silk_touch", level = 1 } }
		elseif reward.id == "booster" then
			id = "booster_" .. rawId .. "_local"
		end
		local counts = if reward.id == "rare_wooden_pickaxe_silk_touch"
			then { 1, 1 }
			else reward.count or { 1, 1 }
		table.insert(out, {
			stack = { id = id, count = counts[1], level = level, books = books },
			minCount = counts[1],
			maxCount = counts[2],
			probability = 1 / #ids,
		})
	end
	return out
end

-- Returns stack, directly credited coins. Keeps the original random call order, including
-- the first unused food-count sample, so seeded pre/post-refactor behavior is identical.
function CaseRoll.resolve(caseId: string, reward: any, random: Random): (any?, number)
	if reward.id == "money" then
		local minimum, maximum = CaseRoll.moneyRange(reward)
		local amount = random:NextInteger(minimum, maximum)
		if caseId == "artifactCase" then
			return { id = "money_bag", count = 1, coins = amount }, 0
		end
		return nil, amount
	elseif reward.id == "ancient_book" then
		return AncientRoll.roll(false, random), 0
	end
	local count = if reward.count then random:NextInteger(reward.count[1], reward.count[2]) else 1
	local variants = CaseRoll.variants(reward)
	local chosen = variants[1]
	if
		reward.id == "food"
		or reward.id == "leather_armor_piece"
		or reward.id == "wooden_sword_or_bow"
		or reward.id == "booster"
	then
		chosen = variants[random:NextInteger(1, #variants)]
	end
	if reward.id == "food" then
		count = random:NextInteger(reward.count[1], reward.count[2])
	end
	if reward.id == "rare_wooden_pickaxe_silk_touch" then
		count = 1
	end
	local stack = table.clone(chosen.stack)
	stack.count = count
	return stack, 0
end

return CaseRoll
