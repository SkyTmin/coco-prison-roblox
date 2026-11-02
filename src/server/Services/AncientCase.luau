--!strict
-- Server-owned book rolls and atomic delivery. The case is the overflow container only.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local BookTuning = require(script.Parent.BookTuning)
local InventoryService = require(script.Parent.InventoryService)

local AncientCase = {}

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

function AncientCase.roll(improved: boolean, random: Random): Types.ItemStack
	local rules = Config.keys.ancientCase
	local rarity = weighted(rules.rarity, random)
	local effects, any = {}, {}
	for id, levels in pairs(Config.books.effects) do
		-- An improved key guarantees III, even for a catalog containing one-level effects.
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
	local effect = effects[random:NextInteger(1, #effects)]
	local level = if improved
		then 3
		else math.min(
			#Config.books.effects[effect],
			tonumber(weighted(rules.level, random)) :: number
		)
	effect = BookTuning.roll(effect, level, effects, random)
	level = if improved then 3 else math.min(level, #Config.books.effects[effect])
	local chance = rules.applyChance
	if improved then
		local bands = rules.improvedApplyChance
		chance = if random:NextNumber() < bands.lowWeight then bands.low else bands.high
	end
	return {
		id = "ancient_book",
		count = 1,
		level = level,
		books = { { id = effect, level = level } },
		rarity = Config.books.catalog[effect].rarity,
		applyChance = random:NextInteger(chance[1], chance[2]),
	}
end

-- Call only inside ProfileService.Mutate. A consumed last key frees a slot before testing capacity.
-- Work on cloned stacks so a full bag AND chest never consumes a key or alters an existing stack.
function AncientCase.deliver(profile: Types.Profile, key: string, book: Types.ItemStack): string
	local staged = table.clone(profile)
	staged.inventory = {}
	for slot, stack in pairs(profile.inventory) do
		staged.inventory[slot] = table.clone(stack)
	end
	if InventoryService.remove(staged, key, 1) ~= 1 then
		return "case_no_key"
	end
	local reward = { book }
	local destination = "inventory"
	local contents = table.clone(profile.caseContents.ancientCase or {})
	if InventoryService.transfer(reward, 1, staged.inventory, 1, InventoryService.SLOTS) == 0 then
		destination = "case"
		if InventoryService.transfer(reward, 1, contents, 1, 27) == 0 then
			return "case_full"
		end
	end
	profile.inventory = staged.inventory
	profile.caseContents.ancientCase = contents
	return destination
end

return AncientCase
