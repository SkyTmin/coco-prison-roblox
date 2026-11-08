--!strict
-- Paid-book selection and its exact distribution share the same eligibility and adjustment rules.
-- Combat proc tuning stays server-side; this module describes only the item awarded by a key.
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)
local AncientRoll = {}
local adjusted: { [string]: boolean } = { plastolom = true, vampirism = true, enlightened = true }
local KEEP_ADJUSTED = 0.5

local function weighted(weights: { [string]: number }, random: Random): string
	local ids, total = {}, 0
	for id, weight in pairs(weights) do
		table.insert(ids, id)
		total += weight
	end
	table.sort(ids)
	local value = random:NextNumber() * total
	for _, id in ipairs(ids) do
		value -= weights[id]
		if value < 0 then
			return id
		end
	end
	return ids[#ids]
end

local function pool(rarity: string, improved: boolean): { string }
	local effects, any = {}, {}
	for id, levels in pairs(Config.books.effects) do
		if not improved or #levels >= 3 then
			table.insert(any, id)
			local entry = Config.books.catalog[id]
			if entry and entry.rarity == rarity then
				table.insert(effects, id)
			end
		end
	end
	if #effects == 0 then
		effects = any
	end
	table.sort(effects)
	assert(#effects > 0, "Ancient case has no eligible books")
	return effects
end

local function alternatives(effect: string, level: number, choices: { string }): { string }?
	if level ~= 3 or not adjusted[effect] then
		return nil
	end
	local out = {}
	for _, id in ipairs(choices) do
		if not adjusted[id] then
			table.insert(out, id)
		end
	end
	assert(#out > 0, "Book pool has no alternative reward")
	return out
end

function AncientRoll.adjust(
	effect: string,
	level: number,
	choices: { string },
	random: Random
): string
	local other = alternatives(effect, level, choices)
	if not other or random:NextNumber() < KEEP_ADJUSTED then
		return effect
	end
	return other[random:NextInteger(1, #other)]
end

function AncientRoll.adjustments(effect: string, level: number, choices: { string }): { any }
	local other = alternatives(effect, level, choices)
	if not other then
		return { { id = effect, probability = 1 } }
	end
	local out = { { id = effect, probability = KEEP_ADJUSTED } }
	for _, id in ipairs(other) do
		table.insert(out, { id = id, probability = (1 - KEEP_ADJUSTED) / #other })
	end
	return out
end

function AncientRoll.chanceBands(improved: boolean): { any }
	local rules = Config.keys.ancientCase
	if not improved then
		return { { min = rules.applyChance[1], max = rules.applyChance[2], probability = 1 } }
	end
	local bands = rules.improvedApplyChance
	return {
		{ min = bands.low[1], max = bands.low[2], probability = bands.lowWeight },
		{ min = bands.high[1], max = bands.high[2], probability = 1 - bands.lowWeight },
	}
end

function AncientRoll.roll(improved: boolean, random: Random): Types.ItemStack
	local rules = Config.keys.ancientCase
	local effects = pool(weighted(rules.rarity, random), improved)
	local effect = effects[random:NextInteger(1, #effects)]
	local level = if improved
		then 3
		else math.min(
			#Config.books.effects[effect],
			tonumber(weighted(rules.level, random)) :: number
		)
	effect = AncientRoll.adjust(effect, level, effects, random)
	level = if improved then 3 else math.min(level, #Config.books.effects[effect])
	local bands = AncientRoll.chanceBands(improved)
	local band = bands[1]
	if improved and random:NextNumber() >= band.probability then
		band = bands[2]
	end
	return {
		id = "ancient_book",
		count = 1,
		level = level,
		books = { { id = effect, level = level } },
		rarity = Config.books.catalog[effect].rarity,
		applyChance = random:NextInteger(band.min, band.max),
	}
end

-- Aggregated final effect/level probability BEFORE the independent applyChance integer.
-- Clamped levels and replacement into a shorter book are merged, not displayed twice.
function AncientRoll.distribution(improved: boolean): { any }
	local rules = Config.keys.ancientCase
	local rarityTotal, levelTotal = 0, 0
	for _, weight in pairs(rules.rarity) do
		rarityTotal += weight
	end
	for _, weight in pairs(rules.level) do
		levelTotal += weight
	end
	local byKey: { [string]: any } = {}
	for rarity, rarityWeight in pairs(rules.rarity) do
		local choices = pool(rarity, improved)
		for _, selected in ipairs(choices) do
			local levels = if improved then { ["3"] = 1 } else rules.level
			for rawLevel, levelWeight in pairs(levels) do
				local initial = if improved
					then 3
					else math.min(
						tonumber(rawLevel) :: number,
						#Config.books.effects[selected]
					)
				local initialP = rarityWeight
					/ rarityTotal
					/ #choices
					* levelWeight
					/ (if improved then 1 else levelTotal)
				for _, branch in ipairs(AncientRoll.adjustments(selected, initial, choices)) do
					local effect = branch.id
					local level = if improved
						then 3
						else math.min(initial, #Config.books.effects[effect])
					local key = effect .. ":" .. tostring(level)
					local entry = byKey[key]
					if not entry then
						entry = {
							id = effect,
							level = level,
							rarity = Config.books.catalog[effect].rarity,
							probability = 0,
						}
						byKey[key] = entry
					end
					entry.probability += initialP * branch.probability
				end
			end
		end
	end
	local out = {}
	for _, entry in pairs(byKey) do
		table.insert(out, entry)
	end
	table.sort(out, function(a, b)
		return if a.id == b.id then a.level < b.level else a.id < b.id
	end)
	return out
end

return AncientRoll
