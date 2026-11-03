--!strict
-- The reward clock belongs to a player/boss pair, never to a server or a six-hour affinity window.
local Shared = game:GetService("ReplicatedStorage").Shared
local Numbers = require(Shared.Numbers)
local Persistence = require(Shared.Persistence)
local Inventory = require(script.Parent.InventoryService)
local Policy = {}

function Policy.Until(profile: any, bossId: string): number
	local untilAt = profile.bossRewardUntil and profile.bossRewardUntil[bossId] or 0
	if not Numbers.finite(untilAt) then
		return math.huge
	end
	for _, award in if profile.bossRewardPending then profile.bossRewardPending.queue else {} do
		if award.bossId == bossId then
			untilAt = math.max(untilAt, award.untilAt)
		end
	end
	return untilAt
end

function Policy.Eligible(profile: any, bossId: string, killedAt: number): boolean
	return profile ~= nil and Policy.Until(profile, bossId) <= killedAt
end

function Policy.Shares(
	bossId: string,
	killedAt: number,
	damage: any,
	profiles: any,
	lastHit: number?
): (any, number?, number)
	local total = 0
	local eligible = {}
	local best: number? = nil
	for userId, dealt in damage do
		if
			Numbers.finite(dealt)
			and dealt > 0
			and Policy.Eligible(profiles[userId], bossId, killedAt)
		then
			eligible[userId] = dealt
			total += dealt
			if
				not best
				or dealt > eligible[best]
				or (dealt == eligible[best] and userId < best)
			then
				best = userId
			end
		end
	end
	local rewardLast = if lastHit and eligible[lastHit] then lastHit else best
	for userId, dealt in eligible do
		eligible[userId] = dealt / total
	end
	return eligible, rewardLast, total
end

local function add(profile: any, id: string, count: number)
	local left = Inventory.add(profile, id, count)
	if left == 0 then
		return
	end
	profile.stash = profile.stash or {}
	for _, stack in profile.stash do
		if stack.id == id then
			stack.count += left
			return
		end
	end
	table.insert(profile.stash, { id = id, count = left })
end

-- Synchronous transform used on both the staged checkpoint and live state after acknowledgement.
function Policy.Apply(profile: any, award: any): boolean
	profile.bossRewardUntil = profile.bossRewardUntil or {}
	profile.bossRewardReceipts = profile.bossRewardReceipts or {}
	if profile.bossRewardReceipts[award.bossId] == award.id then
		return true
	end
	if
		(profile.bossRewardUntil[award.bossId] or 0) > award.killedAt
		or not Numbers.canCredit(profile.coins, award.coins)
	then
		return false
	end
	profile.coins += award.coins
	profile.stats.bosses = (profile.stats.bosses or 0) + 1
	local held = false
	for _, death in if profile.storageDeath then profile.storageDeath.queue else {} do
		if death.bossRewardIds and death.bossRewardIds[award.id] and death.dropItems then
			for id, count in award.items do
				table.insert(death.drops, { id = id, count = count })
			end
			held = true
			break
		end
	end
	if not held then
		for id, count in award.items do
			add(profile, id, count)
		end
	end
	profile.bossRewardUntil[award.bossId] = award.untilAt
	profile.bossRewardReceipts[award.bossId] = award.id
	return true
end

function Policy.Remove(profile: any, id: string)
	local state = profile.bossRewardPending
	if not state then
		return
	end
	for index, award in state.queue do
		if award.id == id then
			table.remove(state.queue, index)
			break
		end
	end
	if #state.queue == 0 then
		profile.bossRewardPending = nil
	end
end

function Policy.Enqueue(profile: any, award: any): boolean
	if not Policy.Eligible(profile, award.bossId, award.killedAt) then
		return false
	end
	profile.bossRewardPending = profile.bossRewardPending or { queue = {} }
	table.insert(profile.bossRewardPending.queue, Persistence.copy(award))
	return true
end

return Policy
