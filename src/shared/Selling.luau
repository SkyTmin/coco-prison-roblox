--!strict
local Boosters = require(script.Parent.Boosters)
local Config = require(script.Parent.Config)
local Numbers = require(script.Parent.Numbers)

local Selling = {}
Selling.MAX_MULTIPLIER = 5 -- [owner 26.10] final money multiplier, including every booster scope

function Selling.multiplier(profile: any): number
	if not profile then
		return 1
	end
	local value = (1 + profile.professions.upgrades.money * Config.professions.upgrades.money)
		* Boosters.multiplier(profile, "money")
	return if Numbers.finite(value) and value >= 0
		then math.min(Selling.MAX_MULTIPLIER, value)
		else 0
end

-- The authoritative SellAll plan, also used for client progression estimates. Round each stack
-- exactly once, retain locked blocks, and fail closed on invalid quantities or currency overflow.
function Selling.quote(profile: any, multiplier: number?): (number, number, number, { number })
	local value = multiplier or Selling.multiplier(profile)
	if
		not profile
		or not Numbers.integer(profile.coins)
		or not Numbers.finite(value)
		or value <= 0
	then
		return 0, 0, 0, {}
	end
	for _, stack in profile.inventory do
		if not Numbers.integer(stack.count, 1) then
			return 0, 0, 0, {}
		end
	end
	local total, locked, count = 0, 0, 0
	local slots = {}
	for slot, stack in profile.inventory do
		local block = Config.block(stack.id)
		if block and block.sellable ~= false and Config.blockLocked(stack.id, profile.level) then
			locked += stack.count
		elseif block and block.sellable ~= false then
			total += math.floor(block.basePrice * Config.moneyScale * value * stack.count + 0.5)
			count += stack.count
			table.insert(slots, slot)
		end
	end
	if not Numbers.canCredit(profile.coins, total) then
		return 0, locked, 0, {}
	end
	return total, locked, count, slots
end

return Selling
