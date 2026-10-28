--!strict
-- «Пригласить друга» and the «Избранное» card (docs/research/remaining-features-design.md, этап 10) [владелец 28.10:
-- «Да нужно» — рост игры; every number in Config.referrals is ours, [решение]].
--   * A player who joins through a Roblox invite carries GetJoinData().ReferredByPlayerId. A brand-new profile
--     (ProfileService.IsNew) that is not the inviter's own remembers it (p.referral.by) and gets the newcomer gift at
--     once (an ordinary key + 500 $).
--   * When that friend reaches Config.referrals.friendLevel (5 — fake accounts rarely get there) the friend's server
--     adds the friend's userId to DataStore Referrals_v1/Inviter_<inviterId> (UpdateAsync: the list holds each id
--     once) and only then marks p.referral.credited; then it pings the inviter (here directly, elsewhere via
--     MessagingService). The persistent «level ≥ 5 and not credited» is the friend's outbox note: a crash between the
--     two steps just repeats the idempotent write on the next login or loop tick.
--   * The inviter settles the record on every join and on a ping: each friend id not in p.invites.seen is counted
--     once («Приглашено друзей» = p.stats.referrals) and pays an improved ancient key + 2 500 $ while fewer than
--     maxRewards (20) were paid. The record is append-only and never touched by the inviter; the dedupe lives in the
--     session-locked profile, so a ping and a join at the same time, or two servers, can never pay one friend twice.
--   * Time in the game: p.stats.playSeconds, added once a minute (the «Избранное» card waits for 30 minutes).
--   * Favorite(op): the client's card tells what the player chose — "done" (added, never again) or "later"
--     (laterDays later). No reward of any kind: rewarding a like / favorite is against the Roblox rules.
-- QA (Studio): ServerStorage.ReferralDebug:Invoke(op, …) — ("refer", userId, inviterId) as a fresh invite join (the
-- new-profile check skipped) → true when the gift was given; ("friendLevel", userId) the friend reaches the level and
-- is credited → true; ("credit", inviterId, friendId) put a friend into the inviter's record as another server would
-- and settle → the inviter's state; ("state", userId) → JSON {referral, invites, referrals, playSeconds, favorite,
-- record}; ("favoriteReset", userId) forget the card's choice; ("play", userId, seconds) add play time.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)

local ReferralService = {}

local cfg = Config.referrals
local STORE_NAME = "Referrals_v1"
local TOPIC = "Referrals_v1"
local PLAY_TICK = 60 -- seconds between play-time ticks (and retries of a friend's credit)

local store: DataStore? = nil
local memoryRecords: { [number]: { number } } = {} -- Studio without API access: the records live in memory
local crediting: { [Player]: boolean } = {}
local settling: { [Player]: boolean } = {}
local settleAgain: { [Player]: boolean } = {}
local lastFavorite: { [Player]: number } = {}
local playTick: { [Player]: number } = {} -- os.clock() the play time was last added (from the profile load)

local function key(inviterId: number): string
	return "Inviter_" .. tostring(inviterId)
end

local function toast(player: Player, stringKey: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(stringKey, Strings.localeOf(player), ...))
end

-- the item into the inventory; what does not fit goes to the storage [B] (p.stash), like boss drops
local function grant(p: any, id: string, count: number)
	local left = InventoryService.add(p, id, count)
	if left > 0 then
		local stash = table.clone(p.stash or {})
		local merged = false
		for _, entry in ipairs(stash) do
			if entry.id == id then
				entry.count += left
				merged = true
			end
		end
		if not merged then
			table.insert(stash, { id = id, count = left })
		end
		p.stash = stash
	end
end

local function cleanList(value: any): { number }
	local out: { number } = {}
	if typeof(value) == "table" and typeof(value.friends) == "table" then
		for _, id in ipairs(value.friends) do
			if typeof(id) == "number" and id == math.floor(id) then
				table.insert(out, id)
			end
		end
	end
	return out
end

-- Adds the friend to the inviter's record once. true = the friend is in the record (or the record is full, which
-- counts as done too); false = the write failed, try again later.
local function addFriend(inviterId: number, friendId: number): boolean
	if not store then
		local list = memoryRecords[inviterId] or {}
		memoryRecords[inviterId] = list
		if not table.find(list, friendId) and #list < cfg.recordCap then
			table.insert(list, friendId)
		end
		return true
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(inviterId), function(old: any)
			local list = cleanList(old)
			if table.find(list, friendId) or #list >= cfg.recordCap then
				return nil -- already there (or full): leave the record as it is
			end
			table.insert(list, friendId)
			return { friends = list }
		end)
	end)
	if not ok then
		warn("[ReferralService] record write failed: " .. tostring(err))
	end
	return ok
end

local function readRecord(inviterId: number): { number }?
	if not store then
		return table.clone(memoryRecords[inviterId] or {})
	end
	local ok, result = pcall(function()
		local options = Instance.new("DataStoreGetOptions")
		options.UseCache = false -- a friend's server may have written it a moment ago
		return (store :: DataStore):GetAsync(key(inviterId), options)
	end)
	if not ok then
		warn("[ReferralService] record read failed: " .. tostring(result))
		return nil
	end
	return cleanList(result)
end

-- The inviter's side: count the new friends of the record and pay for them (see the header).
function ReferralService.settle(player: Player)
	if settling[player] then
		settleAgain[player] = true
		return
	end
	settling[player] = true
	repeat
		settleAgain[player] = nil
		local friends = if ProfileService.IsReal(player) or not store
			then readRecord(player.UserId)
			else nil
		local paid, counted = 0, 0
		if friends and #friends > 0 and player.Parent then
			ProfileService.Mutate(player, function(p)
				local invites = p.invites or { seen = {}, rewarded = 0 }
				for _, friendId in ipairs(friends) do
					local id = tostring(friendId)
					if friendId ~= player.UserId and not invites.seen[id] then
						invites.seen[id] = true
						counted += 1
						if invites.rewarded < cfg.maxRewards then
							invites.rewarded += 1
							paid += 1
							grant(p, cfg.inviter.item, cfg.inviter.count)
							p.coins += cfg.inviter.money * Config.moneyScale
						end
					end
				end
				p.invites = invites
				local total = 0
				for _ in pairs(invites.seen) do
					total += 1
				end
				p.stats.referrals = total
			end)
		end
		local locale = Strings.localeOf(player)
		for _ = 1, paid do
			toast(
				player,
				"referral_reward",
				cfg.friendLevel,
				Strings.itemName(cfg.inviter.item, nil, locale),
				Strings.grouped(cfg.inviter.money, 0)
			)
		end
		if counted > paid then
			toast(player, "referral_counted", cfg.friendLevel, cfg.maxRewards)
		end
	until not settleAgain[player] or not player.Parent
	settling[player] = nil
	settleAgain[player] = nil
end

-- tells the inviter's server (or this one) that the record grew
local function notify(inviterId: number)
	local inviter = Players:GetPlayerByUserId(inviterId)
	if inviter and ProfileService.Get(inviter) then
		task.spawn(ReferralService.settle, inviter)
		return
	end
	if store then
		pcall(function()
			MessagingService:PublishAsync(TOPIC, { inviter = inviterId })
		end)
	end
end

-- The friend's side: once the friend level is reached, into the inviter's record (see the header). Called after a
-- level-up, on every join and by the play-time loop (a failed write is retried there).
function ReferralService.check(player: Player)
	local p = ProfileService.Get(player)
	local referral = p and p.referral
	if
		not p
		or not referral
		or referral.credited
		or p.level < cfg.friendLevel
		or crediting[player]
	then
		return
	end
	if store and not ProfileService.IsReal(player) then
		return -- a default profile that is never saved must not count as a friend
	end
	crediting[player] = true
	local inviterId = referral.by
	local ok = addFriend(inviterId, player.UserId)
	crediting[player] = nil
	if not ok or not player.Parent then
		return
	end
	ProfileService.Mutate(player, function(q)
		if q.referral and q.referral.by == inviterId then
			q.referral.credited = true
		end
	end)
	notify(inviterId)
end

-- The newcomer's side: remember the inviter and give the gift. false = not an invite, a self-invite or already done.
function ReferralService.refer(player: Player, inviterId: any): boolean
	if
		typeof(inviterId) ~= "number"
		or inviterId <= 0
		or inviterId ~= math.floor(inviterId)
		or inviterId == player.UserId
	then
		return false
	end
	local given = false
	ProfileService.Mutate(player, function(p)
		if p.referral then
			return
		end
		p.referral = { by = inviterId }
		grant(p, cfg.newcomer.item, cfg.newcomer.count)
		p.coins += cfg.newcomer.money * Config.moneyScale
		given = true
	end)
	if given then
		local locale = Strings.localeOf(player)
		toast(
			player,
			"referral_welcome",
			Strings.itemName(cfg.newcomer.item, nil, locale),
			Strings.grouped(cfg.newcomer.money, 0)
		)
	end
	return given
end

local function onLoaded(player: Player)
	playTick[player] = os.clock()
	if ProfileService.IsNew(player) then
		local ok, data = pcall(function()
			return player:GetJoinData()
		end)
		if ok and typeof(data) == "table" then
			ReferralService.refer(player, tonumber(data.ReferredByPlayerId))
		end
	end
	ReferralService.check(player)
	ReferralService.settle(player)
end

-- Favorite(op): "done" — added to the favourites (never shown again); "later" — next time in laterDays. No reward.
local function onFavorite(player: Player, op: any)
	if op ~= "done" and op ~= "later" then
		return
	end
	local now = os.clock()
	if now - (lastFavorite[player] or 0) < 2 then
		return
	end
	lastFavorite[player] = now
	ProfileService.Mutate(player, function(p)
		if op == "done" then
			p.favorite = { done = true }
		elseif not (p.favorite and p.favorite.done) then
			p.favorite = { laterUntil = os.time() + cfg.favorite.laterDays * 86400 }
		end
	end)
end

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "ReferralDebug"
	hook.OnInvoke = function(op: string, a: any, b: any): any
		local player = Players:GetPlayerByUserId(tonumber(a) or 0)
		if op == "credit" then
			local inviterId, friendId = tonumber(a), tonumber(b)
			if not inviterId or not friendId or not addFriend(inviterId, friendId) then
				return false
			end
			notify(inviterId)
			if player then
				ReferralService.settle(player)
				op = "state"
			else
				return true
			end
		end
		if not player or not ProfileService.Get(player) then
			return false
		end
		if op == "refer" then
			return ReferralService.refer(player, tonumber(b))
		elseif op == "friendLevel" then
			ProfileService.Mutate(player, function(p)
				p.level = math.max(p.level, cfg.friendLevel)
			end)
			ReferralService.check(player)
			local p = ProfileService.Get(player)
			return p ~= nil and p.referral ~= nil and p.referral.credited == true
		elseif op == "favoriteReset" then
			ProfileService.Mutate(player, function(p)
				p.favorite = nil
			end)
			return true
		elseif op == "play" then
			ProfileService.Mutate(player, function(p)
				p.stats.playSeconds = (p.stats.playSeconds or 0) + (tonumber(b) or 0)
			end)
			return true
		elseif op == "state" then
			local p = ProfileService.Get(player) :: any
			return HttpService:JSONEncode({
				referral = p.referral or false,
				invites = p.invites or false,
				referrals = p.stats.referrals or 0,
				playSeconds = p.stats.playSeconds or 0,
				favorite = p.favorite or false,
				record = readRecord(player.UserId) or false,
			})
		end
		return false
	end
	hook.Parent = ServerStorage
end

function ReferralService.Start()
	local ok, result = pcall(function()
		local s = DataStoreService:GetDataStore(STORE_NAME)
		s:GetAsync("probe") -- fails in Studio without API access
		return s
	end)
	if ok then
		store = result
	elseif RunService:IsStudio() then
		warn(
			"[ReferralService] no DataStore in Studio: referral records live in memory until Play stops"
		)
	else
		warn("[ReferralService] DataStore unavailable: " .. tostring(result))
	end
	Remotes.event("Favorite").OnServerEvent:Connect(onFavorite)
	ProfileService.OnLoaded(function(player)
		task.spawn(onLoaded, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		crediting[player] = nil
		settling[player] = nil
		settleAgain[player] = nil
		lastFavorite[player] = nil
		playTick[player] = nil
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				local inviterId = typeof(data) == "table" and tonumber(data.inviter)
				local inviter = inviterId and Players:GetPlayerByUserId(inviterId)
				if inviter and ProfileService.Get(inviter) then
					ReferralService.settle(inviter)
				end
			end)
		end)
	end)
	-- time in the game (the «Избранное» card) and the retries of a friend's credit
	task.spawn(function()
		while true do
			task.wait(PLAY_TICK)
			local now = os.clock()
			for _, player in ipairs(Players:GetPlayers()) do
				local since = playTick[player]
				if not since then
					playTick[player] = now -- a profile whose load hooks did not run (Studio without API access)
				elseif ProfileService.Get(player) then
					local seconds = math.floor(now - since)
					playTick[player] = since + seconds
					ProfileService.Mutate(player, function(p)
						p.stats.playSeconds = (p.stats.playSeconds or 0) + seconds
					end)
					task.spawn(ReferralService.check, player)
				end
			end
		end
	end)
	debugHook()
end

return ReferralService
