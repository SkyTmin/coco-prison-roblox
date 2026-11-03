--!strict
-- Only server-confirmed outcomes advance the first-login guide.
local Config = require(script.Parent.Config)
local Selling = require(script.Parent.Selling)
local Tutorial = {}
Tutorial.VERSION = 2

function Tutorial.new()
	return { version = Tutorial.VERSION, step = 3 }
end

function Tutorial.step(profile: any): number
	local state = profile and profile.tutorial
	if typeof(state) == "table" and (state.completedAt or state.legacy) then
		return 5
	end
	return if typeof(state) == "table"
			and (state.version == Tutorial.VERSION or state.version == 1)
		then math.clamp(tonumber(state.step) or 5, 3, 5)
		else 5
end

function Tutorial.upgradeGoal(profile: any): any
	if not profile then
		return nil
	end
	local target, stack
	for slot = 1, 36 do
		local item = profile.inventory[slot]
		if item and item.id == "shovel" and Config.upgrade(item.id, item.level or 1) then
			target, stack = slot, item
			break
		end
	end
	if not stack then
		return nil
	end
	local up = Config.upgrade(stack.id, stack.level or 1)
	local cost = math.floor(up.cost * Config.moneyScale + 0.5)
	local goal = {
		target = target,
		itemId = stack.id,
		level = stack.level or 1,
		to = up.to,
		cost = cost,
		coins = profile.coins,
		ready = profile.coins >= cost,
		resourcesReady = true,
		estimatedSale = Selling.quote(profile),
		requirements = {},
	}
	for counter, needed in up.requirements do
		local have = Config.requirementHave(profile, counter)
		table.insert(goal.requirements, { counter = counter, have = have, needed = needed })
		if have < needed then
			goal.ready = false
			goal.resourcesReady = false
		end
	end
	table.sort(goal.requirements, function(a, b)
		return a.counter < b.counter
	end)
	goal.saleReady = goal.resourcesReady
		and profile.coins < cost
		and goal.estimatedSale > 0
		and profile.coins + goal.estimatedSale >= cost
	return goal
end

function Tutorial.levelGoal(profile: any): any
	if not profile then
		return nil
	end
	local rule = Config.levelRule(profile.level + 1)
	if not rule then
		return nil
	end
	local cost = math.floor(rule.money * Config.moneyScale + 0.5)
	local estimatedSale = Selling.quote(profile)
	local resourcesReady = profile.blocksTotal >= rule.blocks
	return {
		level = rule.level,
		cost = cost,
		coins = profile.coins,
		blocks = profile.blocksTotal,
		neededBlocks = rule.blocks,
		ready = profile.coins >= cost and resourcesReady,
		resourcesReady = resourcesReady,
		estimatedSale = estimatedSale,
		saleReady = resourcesReady
			and profile.coins < cost
			and estimatedSale > 0
			and profile.coins + estimatedSale >= cost,
	}
end

-- Ordinary mining/selling mutate the real counters and coins; the guide reads them directly.
function Tutorial.dug(
	_profile: any,
	_mineId: string,
	_dropId: string,
	_received: number,
	_sold: number
): boolean
	return false
end
function Tutorial.sold(_profile: any, _items: { [string]: number }): boolean
	return false
end

function Tutorial.upgraded(profile: any, before: number, after: number, at: number): boolean
	if Tutorial.step(profile) ~= 3 or after <= before then
		return false
	end
	profile.tutorial = { version = Tutorial.VERSION, step = 4, upgradedAt = at }
	return true
end

function Tutorial.leveled(profile: any, before: number, after: number, at: number): boolean
	if Tutorial.step(profile) ~= 4 or after <= before then
		return false
	end
	profile.tutorial = { version = Tutorial.VERSION, step = 5, completedAt = at }
	return true
end

return Tutorial
