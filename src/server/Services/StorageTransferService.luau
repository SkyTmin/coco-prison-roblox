--!strict
-- Durable ownership: profile escrow -> atomic chest CAS/receipt -> profile delivery marker.
-- Every uncertain step is retried by its id; rejoin recovery needs no open chest.
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Persistence = require(Shared.Persistence)
local Numbers = require(Shared.Numbers)
local Profile = require(script.Parent.ProfileService)
local Inventory = require(script.Parent.InventoryService)
local Storage = require(script.Parent.SharedStorageService)
local Record = require(script.Parent.SharedStorageRecord)
local Policy = require(script.Parent.CommercePolicyService)
local Transfers = {}
local busy: { [Player]: boolean } = {}
local started = false
local changed: (Player) -> () = function(_player: Player) end

local function hasDeath(player: Player): boolean
	local profile = Profile.Get(player)
	return profile ~= nil and (profile :: any).storageDeath ~= nil
end

local function hasOtherSettlement(player: Player): boolean
	local profile = Profile.Get(player)
	return profile ~= nil
		and (
			(profile :: any).bossRewardPending ~= nil
			or (profile :: any).playerTransfer ~= nil
			or (profile :: any).playerTransferIncoming ~= nil
		)
end

local function pending(player: Player): any
	local profile = Profile.Get(player)
	return profile and (profile :: any).storageTransfer
end

function Transfers.Pending(player: Player): boolean
	return pending(player) ~= nil
		or hasDeath(player)
		or hasOtherSettlement(player)
		or busy[player] == true
end

local function deliver(profile: any, remaining: any)
	for key, stack in remaining do
		local slot = tonumber(key)
		if slot and not profile.inventory[slot] then
			profile.inventory[slot] = Persistence.copy(stack)
			remaining[key] = nil
		else
			local source = { [1] = stack }
			Inventory.transfer(source, 1, profile.inventory, 1, Inventory.SLOTS)
			remaining[key] = source[1]
		end
	end
end

local function resolve(player: Player)
	local operation = pending(player)
	if not operation or not Profile.IsReal(player) then
		return
	end
	if operation.phase == "prepared" then
		-- Reconfirm exact session ownership and the escrow before each uncertain outside write.
		if not Profile.SaveNow(player) or pending(player) ~= operation then
			return
		end
		local committed = Storage.Commit(operation.kind, operation.key, operation)
		if committed == nil or pending(player) ~= operation or not Profile.IsReal(player) then
			return
		end
		Profile.Mutate(player, function(p: any)
			operation.remaining = Persistence.copy(
				if committed then operation.afterInventory else operation.beforeInventory
			)
			operation.coins = if committed then operation.coins else 0
			operation.phase = "delivering"
			p.storageTransfer = operation
		end)
	end
	if operation.phase == "delivering" then
		local saved = Profile.MutateDurable(player, function(p: any)
			local delivery = p.storageTransfer
			if p.storageDeath then
				require(script.Parent.DeathService).HoldTransfer(p, delivery.id, delivery.remaining)
			end
			deliver(p, delivery.remaining)
			if Numbers.canCredit(p.coins, delivery.coins) then
				p.coins += delivery.coins
				delivery.coins = 0
			end
			if next(delivery.remaining) == nil and delivery.coins == 0 then
				delivery.phase = "delivered"
				p.storageSettled = (p.storageSettled or 0) + 1
			end
		end)
		if not saved then
			return
		end
	end
	if not Profile.SaveNow(player) or pending(player) ~= operation then
		return
	end
	if operation.phase == "delivered" then
		Profile.Mutate(player, function(p: any)
			p.storageTransfer = nil
		end)
		-- The durable delivery marker prevents another grant even if cleanup was not saved.
		task.spawn(Storage.Acknowledge, operation.kind, operation.key, operation.id)
	end
end

function Transfers.Resolve(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true
	player:SetAttribute(
		"SharedStorageBusy",
		pending(player) ~= nil or hasDeath(player) or hasOtherSettlement(player)
	)
	local ok, err = pcall(resolve, player)
	busy[player] = nil
	player:SetAttribute(
		"SharedStorageBusy",
		pending(player) ~= nil or hasDeath(player) or hasOtherSettlement(player)
	)
	if not ok then
		warn("[StorageTransfer] recovery deferred: " .. tostring(err))
	end
	changed(player)
end

function Transfers.Begin(
	player: Player,
	kind: string,
	key: string,
	page: number,
	revision: number,
	before: any,
	after: any,
	afterPage: any,
	coins: number
): boolean
	-- This journal is used only by multiuser gang/faction pages, never the personal vault.
	if not Policy.RequireTrade(player) then
		return false
	end
	if Transfers.Pending(player) or not Profile.CanExport(player) or not Numbers.integer(coins) then
		return false
	end
	local original, result = {}, {}
	for slot = 1, Inventory.SLOTS do
		if not Persistence.equal(before[slot], after[slot]) then
			original[tostring(slot)] = Persistence.copy(before[slot])
			result[tostring(slot)] = Persistence.copy(after[slot])
		end
	end
	local operation = {
		id = HttpService:GenerateGUID(false),
		kind = kind,
		key = key,
		page = page,
		revision = revision,
		phase = "prepared",
		beforeInventory = original,
		afterInventory = result,
		afterPage = Record.encode(afterPage),
		coins = coins,
	}
	Profile.Mutate(player, function(p: any)
		for slot = 1, Inventory.SLOTS do
			if not Persistence.equal(before[slot], after[slot]) then
				p.inventory[slot] = nil
			end
		end
		p.storageTransfer = operation
	end)
	player:SetAttribute("SharedStorageBusy", true)
	task.spawn(Transfers.Resolve, player)
	return true
end

function Transfers.Start(onChanged: (Player) -> ())
	if started then
		return
	end
	started = true
	changed = onChanged
	Profile.OnLoaded(Transfers.Resolve)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if pending(player) then
					task.spawn(Transfers.Resolve, player)
				end
			end
			task.wait(3)
		end
	end)
end

return Transfers
