--!strict
-- One durable transport for /pay, /gift and their no-chat Actions UI.
-- Sender outbox -> recipient mailbox -> atomic receipt/grant -> sender cleanup.
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Persistence = require(Shared.Persistence)
local Numbers = require(Shared.Numbers)
local Strings = require(Shared.Strings)
local Remotes = require(Shared.Remotes)
local TransferAccess = require(Shared.TransferAccess)
local StorageNames = require(Shared.StorageNames)
local Inventory = require(script.Parent.InventoryService)
local Profile = require(script.Parent.ProfileService)
local Policy = require(script.Parent.CommercePolicyService)
local Transfer = {}
local inbox: any = nil
local testInbox: any = nil
local function scopeFor(userId: number): string?
	return if userId < 0 and RunService:IsStudio()
		then require(script.Parent.TestSessionScope).Get()
		else nil
end
local function inboxFor(userId: number): any
	local scope = scopeFor(userId)
	if scope then
		if not testInbox then
			testInbox =
				DataStoreService:GetDataStore(StorageNames.progress("PlayerTransfers_QA_v1"), scope)
		end
		return testInbox
	end
	return inbox
end
local working: { [Player]: boolean } = {}
local started = false

local function notify(player: Player, key: string)
	if player.Parent then
		Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player)))
	end
end

local function busy(player: Player)
	local p = Profile.Get(player) :: any
	player:SetAttribute(
		"SharedStorageBusy",
		p ~= nil
			and (
				p.storageTransfer ~= nil
				or p.storageDeath ~= nil
				or p.bossRewardPending ~= nil
				or p.playerTransfer ~= nil
				or p.playerTransferIncoming ~= nil
			)
	)
end

local function updateInbox(userId: number, change: (any) -> ()): (boolean, any)
	return pcall(function()
		local mailbox = assert(inboxFor(userId), "Transfer mailbox unavailable")
		return mailbox:UpdateAsync("Inbox_" .. userId, function(raw: any)
			local doc = if typeof(raw) == "table" then Persistence.copy(raw) else {}
			change(doc)
			return doc
		end)
	end)
end

-- A queued gift always keeps exact metadata. Moving it within one profile requires no second-account write.
function Transfer.Claim(player: Player): number
	if not Profile.CanExport(player) then
		return 0
	end
	local profile = Profile.Get(player) :: any
	if not profile.playerTransferGifts or next(profile.playerTransferGifts) == nil then
		return 0
	end
	local moved = 0
	Profile.Mutate(player, function(p: any)
		for id, stack in pairs(p.playerTransferGifts or {}) do
			local remaining = stack.count
			if Inventory.isStackable(stack.id) then
				for slot = 1, Inventory.SLOTS do
					local other = p.inventory[slot]
					if other then
						local a, b = Persistence.copy(stack), Persistence.copy(other)
						a.count, b.count = nil, nil
						if Persistence.equal(a, b) then
							local amount = math.min(remaining, math.max(0, 64 - other.count))
							other.count += amount
							remaining -= amount
						end
					end
				end
			end
			for slot = 1, Inventory.SLOTS do
				if remaining <= 0 then
					break
				end
				if not p.inventory[slot] then
					local copy = Persistence.copy(stack)
					copy.count = if Inventory.isStackable(stack.id)
						then math.min(64, remaining)
						else remaining
					p.inventory[slot], remaining = copy, remaining - copy.count
				end
			end
			moved += stack.count - remaining
			if remaining == 0 then
				p.playerTransferGifts[id] = nil
			else
				stack.count = remaining
			end
		end
		if p.playerTransferGifts and next(p.playerTransferGifts) == nil then
			p.playerTransferGifts = nil
		end
	end)
	if moved > 0 then
		task.spawn(Profile.SaveNow, player)
	end
	return moved
end

local function markDone(packet: any): boolean
	local ok = updateInbox(packet.recipient, function(doc)
		local entry = doc[packet.id]
		if not entry then
			entry = { packet = Persistence.copy(packet) }
			doc[packet.id] = entry
		end
		assert(Persistence.equal(entry.packet, packet), "Transfer identity collision")
		entry.done = true
		entry.doneAt = entry.doneAt or os.time()
	end)
	return ok
end

local function receive(player: Player, packet: any): boolean
	local current = Profile.Get(player) :: any
	if not current or not Profile.IsReal(player) or packet.recipient ~= player.UserId then
		return false
	end
	if packet.testScope ~= scopeFor(player.UserId) then
		return false
	end
	if current.playerTransferReceipts and current.playerTransferReceipts[packet.id] then
		return markDone(packet)
	end
	-- Existing durable workflows must settle before this one takes the receiver's export barrier.
	if current.storageTransfer or current.storageDeath or current.bossRewardPending then
		return false
	end
	if current.playerTransferIncoming and current.playerTransferIncoming.id ~= packet.id then
		return false
	end
	if not current.playerTransferIncoming then
		Profile.Mutate(player, function(p: any)
			p.playerTransferIncoming = Persistence.copy(packet)
		end)
		busy(player)
	end
	-- Persist the incoming guard first; a failed/uncertain credit must remain unexportable on retry.
	if not Profile.SaveNow(player) then
		return false
	end
	local discard = (packet.recipientGeneration or 0) ~= (current.playerTransferGeneration or 0)
	if
		not discard
		and packet.kind == "pay"
		and not Numbers.canCredit(current.coins, packet.amount)
	then
		return false
	end
	if
		not discard
		and packet.kind == "rubies"
		and not Numbers.canCredit(current.rubies or 0, packet.amount)
	then
		return false
	end
	local confirmed = Profile.MutateDurable(player, function(p: any)
		p.playerTransferReceipts = p.playerTransferReceipts or {}
		if not p.playerTransferReceipts[packet.id] then
			-- Deliberate own reset forfeits outstanding old mail, even if the source posts
			-- its already persisted outbox later. Keep a permanent tombstone for retries.
			if (packet.recipientGeneration or 0) == (p.playerTransferGeneration or 0) then
				if packet.kind == "pay" then
					assert(Numbers.canCredit(p.coins, packet.amount), "Transfer credit limit")
					p.coins += packet.amount
				elseif packet.kind == "rubies" then
					assert(Numbers.canCredit(p.rubies or 0, packet.amount), "Transfer credit limit")
					p.rubies = (p.rubies or 0) + packet.amount
				elseif packet.kind == "gift" then
					p.playerTransferGifts = p.playerTransferGifts or {}
					p.playerTransferGifts[packet.id] = Persistence.copy(packet.stack)
				else
					error("Invalid transfer kind")
				end
			end
			p.playerTransferReceipts[packet.id] = true
		end
		if p.playerTransferIncoming and p.playerTransferIncoming.id == packet.id then
			p.playerTransferIncoming = nil
		end
	end)
	busy(player)
	if not confirmed then
		return false
	end
	markDone(packet) -- failure leaves mailbox queued; the permanent receipt makes the next acknowledgement safe
	Transfer.Claim(player)
	if not discard then
		notify(
			player,
			if current.playerTransferGifts and next(current.playerTransferGifts)
				then "release_transfer_space"
				else "release_transfer_received"
		)
	end
	return true
end

function Transfer.Resolve(player: Player)
	if working[player] or not Profile.IsReal(player) then
		return
	end
	working[player] = true
	local ok, err = pcall(function()
		local p = Profile.Get(player) :: any
		local outgoing = p and p.playerTransfer
		if outgoing then
			assert(
				outgoing.testScope == scopeFor(player.UserId),
				"Refuse transfer from another test run"
			)
			-- No external credit exists until this exact debited outbox has a confirmed save.
			if not Profile.SaveNow(player) then
				return
			end
			local posted, doc = updateInbox(outgoing.recipient, function(entries)
				local entry = entries[outgoing.id]
				if not entry then
					entries[outgoing.id] = { packet = Persistence.copy(outgoing) }
				else
					assert(Persistence.equal(entry.packet, outgoing), "Transfer identity collision")
				end
			end)
			if not posted then
				return
			end
			if doc[outgoing.id].done then
				if
					Profile.MutateDurable(player, function(profile: any)
						if profile.playerTransfer and profile.playerTransfer.id == outgoing.id then
							profile.playerTransfer = nil
						end
					end)
				then
					-- If this cleanup fails, a harmless done entry remains; retries cannot grant again.
					updateInbox(outgoing.recipient, function(entries)
						entries[outgoing.id] = nil
					end)
					notify(player, "release_transfer_done")
				end
			else
				local target = Players:GetPlayerByUserId(outgoing.recipient)
				if target then
					task.defer(Transfer.Resolve, target)
				end
			end
		end
		if not Profile.IsReal(player) then
			return
		end
		p = Profile.Get(player) :: any
		if p.playerTransferIncoming then
			receive(player, Persistence.copy(p.playerTransferIncoming))
		else
			local read, entries = pcall(function()
				local mailbox = assert(inboxFor(player.UserId), "Transfer mailbox unavailable")
				return mailbox:GetAsync("Inbox_" .. player.UserId)
			end)
			if read and typeof(entries) == "table" then
				for _, entry in pairs(entries) do
					if
						typeof(entry) == "table"
						and not entry.done
						and typeof(entry.packet) == "table"
					then
						receive(player, entry.packet)
						break
					end
				end
			end
		end
		Transfer.Claim(player)
	end)
	working[player] = nil
	busy(player)
	if not ok then
		warn("[PlayerTransfer] pending retry: " .. tostring(err))
	end
end

-- Called after the shared command validation. No yield between recheck and the source debit/outbox.
function Transfer.Submit(
	player: Player,
	target: Player,
	kind: string,
	value: any,
	slot: number?
): (boolean, string?)
	if not Policy.RequireTrade(player) then
		return false
	end
	if not Policy.CanTrade(target) then
		return false, "policy_trade_unavailable"
	end
	local nearby, reason = TransferAccess.Check(player, target)
	if not nearby then
		return false, reason
	end
	if player == target or not Profile.CanExport(player) or not Profile.CanExport(target) then
		return false
	end
	local testScope = scopeFor(player.UserId)
	if testScope ~= scopeFor(target.UserId) then
		return false
	end
	local p = Profile.Get(player) :: any
	local packet: any = {
		id = HttpService:GenerateGUID(false),
		sender = player.UserId,
		recipient = target.UserId,
		kind = kind,
		at = os.time(),
		testScope = testScope,
		recipientGeneration = (Profile.Get(target) :: any).playerTransferGeneration or 0,
	}
	if kind == "pay" or kind == "rubies" then
		if not Numbers.canAfford(if kind == "pay" then p.coins else p.rubies or 0, value) then
			return false
		end
		packet.amount = value
	elseif kind == "gift" then
		local stack = slot and p.inventory[slot]
		if not stack or not Numbers.integer(value.count, 1) or value.count > stack.count then
			return false
		end
		local expected = Persistence.copy(stack)
		expected.count = value.count
		if not Persistence.equal(expected, value) then
			return false
		end
		packet.stack = Persistence.copy(value)
	else
		return false
	end
	-- All validation above is synchronous. This is the final gate immediately before
	-- reserving the debit/outbox; later save/recovery must finish even if either player leaves.
	nearby, reason = TransferAccess.Check(player, target)
	if not nearby then
		return false, reason
	end
	Profile.Mutate(player, function(profile: any)
		if kind == "pay" then
			profile.coins -= value
		elseif kind == "rubies" then
			profile.rubies = (profile.rubies or 0) - value
		else
			local stack = profile.inventory[slot]
			stack.count -= value.count
			if stack.count == 0 then
				profile.inventory[slot] = nil
			end
		end
		profile.playerTransfer = packet
	end)
	busy(player)
	task.defer(Transfer.Resolve, player)
	return true, nil
end

function Transfer.Start()
	if started then
		return
	end
	started = true
	-- Local map copies have no universe or mailbox. Keep the rest of Studio bootable.
	if RunService:IsStudio() and game.GameId == 0 then
		return
	end
	inbox = DataStoreService:GetDataStore(StorageNames.progress("PlayerTransfers_v1"))
	Profile.OnLoaded(function(player)
		busy(player)
		task.defer(Transfer.Resolve, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		working[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				task.spawn(Transfer.Resolve, player)
			end
			task.wait(4)
		end
	end)
end

return Transfer
