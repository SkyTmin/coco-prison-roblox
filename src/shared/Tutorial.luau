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
	if profile and (tonumber(profile.level) or 1) >= 2 then
		return 5
	end
	if typeof(state) == "table" and (state.completedAt or state.legacy) then
		return 5
	end
	return if typeof(state) == "table"
			and (state.version == Tutorial.VERSION or state.version == 1)
		then math.clamp(tonumber(state.step) or 5, 3, 5)
		else 5
end

function Tutorial.itemGoal(profile: any, target: number | string, stack: any): any
	if not profile or not stack then
		return nil
	end
	local up = Config.upgrade(stack.id, stack.level or 1)
	if not up then
		return nil
	end
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
		and (
			not (profile.tutorial and profile.tutorial.upgradeSold)
			or profile.coins + goal.estimatedSale >= cost
		)
	return goal
end

function Tutorial.upgradeGoal(profile: any): any
	if profile then
		for slot = 1, 36 do
			local item = profile.inventory[slot]
			if item and item.id == "shovel" and Config.upgrade(item.id, item.level or 1) then
				return Tutorial.itemGoal(profile, slot, item)
			end
		end
	end
	return nil
end

-- A preference identifies an equipment type and its current tier, not an inventory
-- slot: moving/equipping the item must not silently track an unrelated replacement.
function Tutorial.validTrackingTarget(value: any): boolean
	if value == "" or value == "level" then
		return true
	end
	if typeof(value) ~= "string" or #value > 48 then
		return false
	end
	local id, level = string.match(value, "^([a-z_]+):(%d+)$")
	return id ~= nil and Config.tools[id] ~= nil and Config.upgrade(id, tonumber(level)) ~= nil
end

function Tutorial.trackedGoal(profile: any): (any, number)
	local value = profile and profile.settings and profile.settings.trackedUpgrade
	if value == "level" then
		return Tutorial.levelGoal(profile), 4
	end
	if not Tutorial.validTrackingTarget(value) or value == "" then
		return nil, 3
	end
	local id, levelText = string.match(value, "^([a-z_]+):(%d+)$")
	local minimum = tonumber(levelText) or 1
	local chosen, target
	local function consider(stack: any, key: number | string)
		if
			stack
			and stack.id == id
			and (stack.level or 1) >= minimum
			and (not chosen or (stack.level or 1) < (chosen.level or 1))
		then
			chosen, target = stack, key
		end
	end
	for slot = 1, 36 do
		consider(profile.inventory[slot], slot)
	end
	for part, stack in profile.armor or {} do
		consider(stack, part)
	end
	return if chosen then Tutorial.itemGoal(profile, target, chosen) else nil, 3
end

function Tutorial.shouldGuideCase(profile: any): boolean
	local held = profile and profile.inventory and profile.inventory[profile.selectedSlot]
	return Tutorial.step(profile) < 5
		and held ~= nil
		and held.id == "ordinary_key"
		and held.count > 0
		and not (profile.tutorial and profile.tutorial.ordinaryCaseOpened)
end

-- Called only after the server's real equipment upgrade succeeds. Advancing the
-- pinned tier prevents a second identical lower-tier item from taking over the card.
function Tutorial.advanceTrackedUpgrade(
	profile: any,
	itemId: string,
	before: number,
	after: number
): boolean
	local settings = profile and profile.settings
	if after <= before or not settings or settings.trackedUpgrade ~= itemId .. ":" .. before then
		return false
	end
	local nextSettings = table.clone(settings)
	nextSettings.trackedUpgrade = itemId .. ":" .. after
	profile.settings = nextSettings
	return true
end

-- Called inside the same server mutation as the real sale. After the first guided
-- sale, a remaining money deficit is gathered in one batch, not one trip per block.
function Tutorial.soldForUpgrade(profile: any, amount: number): boolean
	if Tutorial.step(profile) ~= 3 or amount <= 0 or profile.tutorial.upgradeSold then
		return false
	end
	local goal = Tutorial.upgradeGoal(profile)
	if not goal or not goal.resourcesReady then
		return false
	end
	profile.tutorial.upgradeSold = true
	return true
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
	local state = table.clone(profile.tutorial)
	state.version, state.step, state.upgradedAt = Tutorial.VERSION, 4, at
	profile.tutorial = state
	return true
end

function Tutorial.leveled(profile: any, before: number, after: number, at: number): boolean
	if
		not profile.tutorial
		or profile.tutorial.completedAt
		or profile.tutorial.legacy
		or after < 2
		or (tonumber(profile.level) or 1) < 2
		or after <= before
	then
		return false
	end
	local state = table.clone(profile.tutorial)
	state.version, state.step, state.completedAt = Tutorial.VERSION, 5, at
	profile.tutorial = state
	return true
end

return Tutorial
