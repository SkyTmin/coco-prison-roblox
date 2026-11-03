--!strict
-- Immutable planned awards are journaled, then their grant+cooldown are durably confirmed together.
local Players = game:GetService("Players")
local Shared = game:GetService("ReplicatedStorage").Shared
local Profile = require(script.Parent.ProfileService)
local Policy = require(script.Parent.BossRewardPolicy)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Service = {}
local busy: { [Player]: boolean } = {}
local started = false

function Service.Resolve(player: Player): { string }
	if busy[player] or not Profile.IsReal(player) then
		return {}
	end
	busy[player] = true
	local granted = {}
	local ok, err = pcall(function()
		local profile = Profile.Get(player) :: any
		local state = profile and profile.bossRewardPending
		while state and state.queue[1] do
			local award = state.queue[1]
			if not Profile.SaveNow(player) or Profile.Get(player) ~= profile then
				break
			end
			local saved = Profile.MutateDurable(player, function(p: any)
				if Policy.Apply(p, award) then
					Policy.Remove(p, award.id)
				end
			end)
			if not saved or Profile.Get(player) ~= profile then
				break
			end
			local pending = profile.bossRewardPending
			if pending and pending.queue[1] and pending.queue[1].id == award.id then
				break
			end
			table.insert(granted, award.id)
			Remotes.event("Toast"):FireClient(
				player,
				Strings.t(
					"boss_reward",
					Strings.localeOf(player),
					Strings.money(award.coins),
					math.floor(award.share * 100 + 0.5)
				)
			)
			for id, count in award.items do
				Remotes.event("Toast"):FireClient(
					player,
					Strings.t(
						"boss_item",
						Strings.localeOf(player),
						Strings.itemName(id, nil, Strings.localeOf(player)),
						count
					)
				)
			end
			state = profile.bossRewardPending
		end
	end)
	busy[player] = nil
	local current = Profile.Get(player) :: any
	player:SetAttribute(
		"SharedStorageBusy",
		current ~= nil
			and (
				current.bossRewardPending ~= nil
				or current.playerTransfer ~= nil
				or current.playerTransferIncoming ~= nil
				or current.storageTransfer ~= nil
				or current.storageDeath ~= nil
			)
	)
	if not ok then
		warn("[BossReward] settlement deferred: " .. tostring(err))
	end
	return granted
end

function Service.Enqueue(player: Player, award: any): boolean
	if not Profile.IsReal(player) then
		return false
	end
	local accepted = false
	Profile.Mutate(player, function(p: any)
		accepted = Policy.Enqueue(p, award)
	end)
	if accepted then
		player:SetAttribute("SharedStorageBusy", true)
	end
	return accepted
end

function Service.Start()
	if started then
		return
	end
	started = true
	Profile.OnLoaded(Service.Resolve)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				local p = Profile.Get(player) :: any
				if p and p.bossRewardPending then
					task.spawn(Service.Resolve, player)
				end
			end
			task.wait(3)
		end
	end)
end

return Service
