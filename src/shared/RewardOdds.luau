--!strict
-- Exact hierarchical paid-case outcomes. All probabilities are fractions (0..1).
-- Main nodes/children are JOINT probabilities within ONE draw, never conditional percentages.
-- Bonus nodes/children are JOINT probabilities per opening, independent of the main draws.
local Config = require(script.Parent.Config)
local AncientRoll = require(script.Parent.AncientRoll)
local CaseRoll = require(script.Parent.CaseRoll)
local Nicknames = require(script.Parent.Nicknames)
local RewardOdds = {}

export type Range = { field: string, min: number, max: number, probabilityPerValue: number }
export type Node = {
	kind: string,
	id: string,
	probability: number,
	stack: any?,
	rarity: string?,
	nickname: string?,
	children: { Node }?,
	range: Range?,
	tier: string?,
	index: number?,
	duplicate: boolean?,
	grantedIndices: { number }?,
	duplicatesAfter: number?,
}
export type Plan = {
	caseId: string,
	keyId: string?,
	draws: { any },
	outcomes: { Node },
	bonuses: { Node },
	unavailable: boolean,
	unavailableReason: string?,
}

local function uniform(field: string, minimum: number, maximum: number, probability: number): Range
	assert(minimum <= maximum and minimum % 1 == 0 and maximum % 1 == 0, "Noninteger reward range")
	return {
		field = field,
		min = minimum,
		max = maximum,
		probabilityPerValue = probability / (maximum - minimum + 1),
	}
end

local function books(improved: boolean, parentProbability: number): { Node }
	local out: { Node } = {}
	for _, book in ipairs(AncientRoll.distribution(improved)) do
		local p = parentProbability * book.probability
		local stack = {
			id = "ancient_book",
			count = 1,
			level = book.level,
			books = { { id = book.id, level = book.level } },
			rarity = book.rarity,
		}
		local children: { Node } = {}
		for _, band in ipairs(AncientRoll.chanceBands(improved)) do
			local probability = p * band.probability
			local example = table.clone(stack) :: any
			example.applyChance = band.min
			table.insert(children, {
				kind = "applyChance",
				id = book.id .. ":" .. book.level .. ":" .. band.min,
				stack = example,
				rarity = book.rarity,
				probability = probability,
				range = uniform("applyChance", band.min, band.max, probability),
			})
		end
		table.insert(out, {
			kind = "book",
			id = book.id .. ":" .. book.level,
			stack = stack,
			rarity = book.rarity,
			probability = p,
			children = children,
		})
	end
	return out
end

-- Projects the existing deterministic duplicate conversion after one uniformly selected tile.
-- The display never treats an already owned tile as a second collectible inventory item.
local function fragment(profile: any, index: number, probability: number): Node
	local old = profile and profile.artifacts and profile.artifacts.common
	local fragments = table.clone(if old and old.fragments then old.fragments else {})
	local duplicates = if old then old.duplicates or 0 else 0
	local duplicate = (fragments[index] or 0) > 0
	local granted = {}
	if duplicate then
		duplicates += 1
	else
		fragments[index] = 1
		table.insert(granted, index)
	end
	while duplicates >= Config.artifacts.duplicatesPerMissingFragment do
		local nextMissing: number? = nil
		for candidate = 1, Config.artifacts.fragmentsPerArtifact do
			if (fragments[candidate] or 0) < 1 then
				nextMissing = candidate
				break
			end
		end
		if not nextMissing then
			break
		end
		duplicates -= Config.artifacts.duplicatesPerMissingFragment
		fragments[nextMissing] = 1
		table.insert(granted, nextMissing)
	end
	return {
		kind = "artifactFragment",
		id = "common:" .. index,
		tier = "common",
		index = index,
		probability = probability,
		duplicate = duplicate,
		grantedIndices = granted,
		duplicatesAfter = duplicates,
	}
end

function RewardOdds.case(caseId: string, profile: any?, keyId: string?): Plan
	local plan: Plan = {
		caseId = caseId,
		keyId = keyId,
		draws = CaseRoll.draws(caseId),
		outcomes = {},
		bonuses = {},
		unavailable = false,
	}
	if caseId == "ancientCase" then
		plan.keyId = keyId or "ancient_key"
		plan.outcomes = books(keyId == "improved_ancient_key", 1)
		return plan
	elseif caseId == "nicknameCase" then
		local total = 0
		for _, name in ipairs(Nicknames.list) do
			if not Nicknames.owns(profile, name) then
				total += Nicknames.weight(name)
			end
		end
		for _, name in ipairs(Nicknames.list) do
			if not Nicknames.owns(profile, name) then
				table.insert(plan.outcomes, {
					kind = "nickname",
					id = name,
					nickname = name,
					rarity = Nicknames.tier(name),
					probability = Nicknames.weight(name) / total,
				})
			end
		end
		plan.unavailable = total == 0
		plan.unavailableReason = if total == 0 then "nickname_all_owned" else nil
		return plan
	end
	local cfg = Config.keys[caseId]
	local rewards = if typeof(cfg) == "table" then cfg.rewards or cfg else nil
	if typeof(rewards) ~= "table" or #rewards == 0 then
		plan.unavailable = true
		return plan
	end
	local total = 0
	for _, reward in ipairs(rewards) do
		total += reward.weight
	end
	for _, reward in ipairs(rewards) do
		local p = reward.weight / total
		if reward.id == "money" then
			local minimum, maximum = CaseRoll.moneyRange(reward)
			table.insert(plan.outcomes, {
				kind = "money",
				id = "money",
				stack = { id = "money_bag", count = 1, coins = minimum },
				rarity = reward.rarity,
				probability = p,
				range = uniform("coins", minimum, maximum, p),
			})
		elseif reward.id == "ancient_book" then
			table.insert(plan.outcomes, {
				kind = "bookPool",
				id = "ancient_book",
				stack = { id = "ancient_book", count = 1 },
				rarity = reward.rarity,
				probability = p,
				children = books(false, p),
			})
		else
			for _, variant in ipairs(CaseRoll.variants(reward)) do
				local probability = p * variant.probability
				table.insert(plan.outcomes, {
					kind = "item",
					id = variant.stack.id,
					stack = variant.stack,
					rarity = reward.rarity,
					probability = probability,
					range = if variant.minCount ~= variant.maxCount
						then uniform("count", variant.minCount, variant.maxCount, probability)
						else nil,
				})
			end
		end
	end
	if caseId == "ordinaryCase" then
		local p = Config.artifacts.fromCaseChance.ordinaryCase
		local children: { Node } = {}
		for index = 1, Config.artifacts.fragmentsPerArtifact do
			table.insert(
				children,
				fragment(profile, index, p / Config.artifacts.fragmentsPerArtifact)
			)
		end
		plan.bonuses = {
			{ kind = "none", id = "none", probability = 1 - p },
			{
				kind = "artifactPool",
				id = "common",
				tier = "common",
				probability = p,
				children = children,
			},
		}
	end
	return plan
end

-- Marginal chance of at least one specified per-draw event. Does not include the independent bonus.
function RewardOdds.atLeastOne(plan: Plan, perDraw: number): number
	local probability = 0
	for _, draw in ipairs(plan.draws) do
		probability += draw.probability * (1 - (1 - perDraw) ^ draw.count)
	end
	return probability
end

return RewardOdds
