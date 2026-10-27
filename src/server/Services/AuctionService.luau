--!strict
-- The auction between players [вики MENUS-SOCIAL «Аукцион /ah»; владелец 27.10: «как будет работать между
-- игроками, как товар туда кидать … чтобы не было дюпов»]. Design and the anti-dupe checklist:
-- docs/research/auction-design.md.
--
-- Where things live:
--   DataStore AuctionLots_v1, key "lot_<id>" — the lot record, the only truth about a lot: its item, price, seller
--     and status active → sold | cancelled | expired (or "void", a tombstone for a lot that was never created).
--     Every status change is an UpdateAsync on that one key, so two buyers on two servers can never both win.
--   MemoryStore sorted map AuctionIndex_v1 — copies of the active lots for browsing (expire with the lot). It may
--     lag behind the records; a purchase always checks the record.
--   The profile, p.auction — the player's side of each step (outbox): lots (their listed lots), pendingSells /
--     pendingBuys (a step whose outside write is not confirmed yet), returns (items that did not fit — «Забрать»).
--
-- Every step that touches a lot: (1) change the profile and note the step in it, (2) ProfileService.SaveNow — the
-- profile is on disk before anything outside changes, (3) the UpdateAsync on the lot, (4) finish the step in the
-- profile. A crash or an error after (2) is settled from the note by re-reading the lot record (UpdateAsync that
-- writes nothing: never a cached GetAsync): the item or the money moves exactly once, because the note and the
-- move are one profile change. Settling runs on load, after each step, when another server reports a sale of the
-- player's lot (MessagingService AuctionSold), on opening «Личные товары» and every settleSeconds.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auction = require(Shared.Auction)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

type ItemStack = Types.ItemStack
type Summary = Auction.Summary
type Lot = {
	id: string,
	item: ItemStack,
	price: number,
	seller: number,
	sellerName: string,
	createdAt: number,
	expiresAt: number,
	status: string, -- active / sold / cancelled / expired / void
	buyer: number?,
	buyerName: string?,
	buyOp: string?, -- the purchase id that won it (a retried purchase recognises itself)
	soldAt: number?,
}
type PendingBuy = { price: number, op: string, at: number, seller: number? }
type Data = {
	lots: { [string]: Summary },
	pendingSells: { [string]: Summary },
	pendingBuys: { [string]: PendingBuy },
	returns: { ItemStack },
}

local LOTS_STORE = "AuctionLots_v1"
local INDEX_MAP = "AuctionIndex_v1"
local SOLD_TOPIC = "AuctionSold"
local MAX_INDEX_PAGES = 50 -- 200 lots a page
local QUERY_COOLDOWN = 0.3
local OPEN_SETTLE_COOLDOWN = 10
local LOCK_WAIT = 10

local cfg = Auction.cfg
local AuctionService = {}

local lotStore: DataStore? = nil
local indexMap: MemoryStoreSortedMap? = nil
-- Studio without API access: the same steps over tables in memory (one server, gone when Play stops)
local memoryLots: { [string]: Lot }? = nil
local memoryIndex: { [string]: Summary }? = nil
local ready = false

local busy: { [Player]: boolean } = {}
local lastAction: { [Player]: number } = {}
local lastQuery: { [Player]: number } = {}
local lastOpenSettle: { [Player]: number } = {}

local cache: { Summary } = {}
local cacheAt = -math.huge
local refreshing = false
local lastWanted = -math.huge

-- QA (Studio): make the next n calls of a step fail — "save", "lot" (before the write), "lotAfter" (the write lands,
-- the answer is lost), "index"
local failNext: { [string]: number } = {}

local function failing(what: string): boolean
	local n = failNext[what]
	if n and n > 0 then
		failNext[what] = n - 1
		return true
	end
	return false
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value) do
		out[k] = deepCopy(v)
	end
	return out
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function itemText(player: Player, item: ItemStack): string
	local name = Strings.itemName(item.id, item.level, Strings.localeOf(player))
	return if item.count > 1 then name .. " ×" .. item.count else name
end

local function data(p: Types.Profile): Data
	local a = (p :: any).auction
	if typeof(a) ~= "table" then
		a = {}
		(p :: any).auction = a
	end
	a.lots = a.lots or {}
	a.pendingSells = a.pendingSells or {}
	a.pendingBuys = a.pendingBuys or {}
	a.returns = a.returns or {}
	return a
end

local function count(map: { [string]: any }): number
	local n = 0
	for _ in pairs(map) do
		n += 1
	end
	return n
end

-- Puts a stack into the inventory keeping all its data (books, rarity, level); returns what did not fit.
local function put(p: Types.Profile, stack: ItemStack): ItemStack?
	if InventoryService.isStackable(stack.id) then
		local left = InventoryService.add(p, stack.id, stack.count, stack.level)
		if left <= 0 then
			return nil
		end
		local rest = deepCopy(stack)
		rest.count = left
		return rest
	end
	for slot = 1, InventoryService.SLOTS do
		if not p.inventory[slot] then
			p.inventory[slot] = deepCopy(stack)
			return nil
		end
	end
	return deepCopy(stack)
end

-- an item to the inventory, or to «Забрать» when it is full; true when it went to «Забрать»
local function give(p: Types.Profile, stack: ItemStack): boolean
	local rest = put(p, stack)
	if rest then
		table.insert(data(p).returns, rest)
		return true
	end
	return false
end

-- one auction step at a time per player; waits a little for a running one when asked
local function lock(player: Player, wait: boolean?): boolean
	local deadline = os.clock() + (if wait then LOCK_WAIT else 0)
	while busy[player] do
		if os.clock() >= deadline or not player.Parent then
			return false
		end
		task.wait(0.2)
	end
	busy[player] = true
	return true
end

local function unlock(player: Player)
	busy[player] = nil
end

local function saveNow(player: Player): boolean
	if failing("save") then
		return false
	end
	return ProfileService.SaveNow(player)
end

-- The one way to read or change a lot record: transform(old) returns the new record, or nil to write nothing.
-- false = the store failed (the transform may or may not have landed — settle by reading it again).
local function lotUpdate(id: string, transform: (any) -> any): boolean
	if failing("lot") then
		return false
	end
	if memoryLots then
		local new = transform(deepCopy(memoryLots[id]))
		if new ~= nil then
			memoryLots[id] = deepCopy(new)
		end
	else
		local store = lotStore
		if not store then
			return false
		end
		local ok, err = pcall(function()
			store:UpdateAsync("lot_" .. id, function(old: any)
				return transform(old)
			end)
		end)
		if not ok then
			warn("[AuctionService] lot " .. id .. ": " .. tostring(err))
			return false
		end
	end
	return not failing("lotAfter")
end

local function summaryOf(lot: Lot | Summary): Summary
	return {
		id = lot.id,
		item = deepCopy(lot.item),
		price = lot.price,
		seller = lot.seller,
		sellerName = lot.sellerName,
		createdAt = lot.createdAt,
		expiresAt = lot.expiresAt,
	}
end

local function indexSet(s: Summary)
	if failing("index") then
		return
	end
	local ttl = s.expiresAt - os.time()
	if ttl <= 0 then
		return
	end
	if memoryIndex then
		memoryIndex[s.id] = summaryOf(s)
	elseif indexMap then
		local map = indexMap
		local ok, err = pcall(function()
			map:SetAsync(s.id, summaryOf(s), math.min(ttl, 45 * 86400))
		end)
		if not ok then
			warn("[AuctionService] index set: " .. tostring(err))
		end
	end
	for i, c in ipairs(cache) do
		if c.id == s.id then
			cache[i] = summaryOf(s)
			return
		end
	end
	table.insert(cache, summaryOf(s))
end

local function indexRemove(id: string)
	for i = #cache, 1, -1 do
		if cache[i].id == id then
			table.remove(cache, i)
		end
	end
	if memoryIndex then
		memoryIndex[id] = nil
	elseif indexMap then
		local map = indexMap
		pcall(function()
			map:RemoveAsync(id)
		end)
	end
end

local function readIndex(): { Summary }?
	if memoryIndex then
		local list = {}
		for _, s in pairs(memoryIndex) do
			table.insert(list, summaryOf(s))
		end
		return list
	end
	local map = indexMap
	if not map then
		return nil
	end
	local list = {}
	local lower: string? = nil
	for _ = 1, MAX_INDEX_PAGES do
		local ok, items = pcall(function()
			return map:GetRangeAsync(Enum.SortDirection.Ascending, 200, lower)
		end)
		if not ok then
			warn("[AuctionService] index read: " .. tostring(items))
			return nil
		end
		for _, entry in ipairs(items) do
			if typeof(entry.value) == "table" then
				table.insert(list, entry.value)
			end
		end
		if #items < 200 then
			break
		end
		lower = items[#items].key
	end
	return list
end

local function refreshCache()
	if refreshing then
		return
	end
	refreshing = true
	local list = readIndex()
	refreshing = false
	if list then
		cache = list
		cacheAt = os.clock()
	end
end

local function cached(id: string): Summary?
	for _, s in ipairs(cache) do
		if s.id == id then
			return s
		end
	end
	return nil
end

local function changed(player: Player)
	Remotes.event("AuctionUpdated"):FireClient(player)
end

-- ── settling the notes ──────────────────────────────────────────────────────────────────────────────────────────

-- A listed lot: sold → the money (minus the commission), cancelled / expired → the item back; an active lot past its
-- time becomes expired here. Idempotent: the profile change happens only while the lot is still in p.auction.lots.
local function settleLot(player: Player, id: string, reindex: boolean?)
	local profile = ProfileService.Get(player)
	local summary = profile and data(profile).lots[id]
	if not summary then
		return
	end
	local state: string? = nil
	local record: Lot? = nil
	local now = os.time()
	local ok = lotUpdate(id, function(old: any)
		if typeof(old) ~= "table" then
			state = "void" -- never happens: lots only holds created lots; give the item back, close the key
			record = nil
			return { status = "void", seller = player.UserId, voidAt = now }
		end
		record = old
		if old.status == "active" and old.expiresAt <= now then
			old.status = "expired"
			state = "expired"
			return old
		end
		state = old.status
		return nil
	end)
	if not ok or not state then
		return
	end
	if state == "active" then
		if reindex and record then
			indexSet(summaryOf(record))
		end
		return
	end
	local sold = state == "sold"
	local item: ItemStack = if record and record.item then record.item else summary.item
	local price = if record then record.price else summary.price
	local toInbox = false
	local done = false
	ProfileService.Mutate(player, function(p)
		local a = data(p)
		if not a.lots[id] then
			return
		end
		a.lots[id] = nil
		done = true
		if sold then
			p.coins += Auction.net(price)
		else
			toInbox = give(p, item)
		end
	end)
	indexRemove(id)
	if not done then
		return
	end
	if sold then
		toast(
			player,
			"auction_sold",
			itemText(player, item),
			record and record.buyerName or "?",
			Strings.money(Auction.net(price))
		)
	else
		toast(
			player,
			if toInbox then "auction_back_inbox" else "auction_back",
			itemText(player, item)
		)
	end
	changed(player)
end

-- A listing whose creation was not confirmed: the lot exists → it is listed; it does not → the key gets a tombstone
-- in the same atomic step (a late write can no longer create it) and the item comes back.
local function settleSell(player: Player, id: string): string?
	local profile = ProfileService.Get(player)
	local summary = profile and data(profile).pendingSells[id]
	if not summary then
		return nil
	end
	local state: string? = nil
	local ok = lotUpdate(id, function(old: any)
		if typeof(old) ~= "table" then
			state = "void"
			return { status = "void", seller = player.UserId, voidAt = os.time() }
		end
		state = if old.status == "void" then "void" else "created"
		return nil
	end)
	if not ok or not state then
		return nil
	end
	local s = summary :: Summary
	ProfileService.Mutate(player, function(p)
		local a = data(p)
		if not a.pendingSells[id] then
			return
		end
		a.pendingSells[id] = nil
		if state == "created" then
			a.lots[id] = s
		else
			give(p, s.item)
		end
	end)
	if state == "created" then
		settleLot(player, id, true)
	end
	changed(player)
	return state
end

-- authoritative: did the purchase `op` win the lot? "won" + the record / "gone" / nil (the store failed)
local function readBuy(id: string, op: string): (string?, Lot?)
	local state: string? = nil
	local record: Lot? = nil
	local ok = lotUpdate(id, function(old: any)
		record = if typeof(old) == "table" then old else nil
		state = if record and record.buyOp == op then "won" else "gone"
		return nil
	end)
	if not ok then
		return nil, nil
	end
	return state, record
end

local function notifySeller(seller: number?, id: string)
	if not seller or seller <= -1000 then -- QA fakes; Studio test players are −1, −2…
		return
	end
	local local_ = Players:GetPlayerByUserId(seller)
	if local_ then
		task.spawn(function()
			if lock(local_, true) then
				local ok, err = pcall(settleLot, local_, id)
				unlock(local_)
				if not ok then
					warn("[AuctionService] " .. tostring(err))
				end
			end
		end)
		return
	end
	task.spawn(function()
		pcall(function()
			MessagingService:PublishAsync(SOLD_TOPIC, { lot = id, seller = seller })
		end)
	end)
end

-- finish a purchase from its outcome: won → the item, gone → the money back, nil → the note waits
local function finishBuy(player: Player, id: string, op: string, state: string?, record: Lot?)
	if not state then
		return
	end
	local item = record and record.item
	local delivered = false
	local refunded = 0
	local toInbox = false
	ProfileService.Mutate(player, function(p)
		local a = data(p)
		local pending = a.pendingBuys[id]
		if not pending or pending.op ~= op then
			return
		end
		a.pendingBuys[id] = nil
		if state == "won" and item then
			toInbox = give(p, item)
			delivered = true
		else
			p.coins += pending.price
			refunded = pending.price
		end
	end)
	if delivered and item then
		indexRemove(id)
		toast(
			player,
			if toInbox then "auction_bought_inbox" else "auction_bought",
			itemText(player, item)
		)
		notifySeller(record and record.seller, id)
	elseif refunded > 0 then
		local stillOn = record ~= nil and record.status == "active" and record.expiresAt > os.time()
		if not stillOn then
			indexRemove(id)
		end
		-- still for sale: the store failed, not someone faster
		toast(
			player,
			if stillOn then "auction_refund_retry" else "auction_gone",
			Strings.money(refunded)
		)
	end
	changed(player)
end

local function settleAll(player: Player)
	local profile = ProfileService.Get(player)
	if
		not profile
		or not ProfileService.IsReal(player)
		or typeof((profile :: any).auction) ~= "table"
	then
		return
	end
	local a = data(profile)
	for id in pairs(table.clone(a.pendingSells)) do
		settleSell(player, id)
	end
	for id, pending in pairs(table.clone(a.pendingBuys)) do
		local state, record = readBuy(id, pending.op)
		finishBuy(player, id, pending.op, state, record)
	end
	for id in pairs(table.clone(a.lots)) do
		settleLot(player, id, true)
	end
end

local function settleLocked(player: Player, wait: boolean?)
	if not ready or not lock(player, wait) then
		return
	end
	local ok, err = pcall(settleAll, player)
	unlock(player)
	if not ok then
		warn("[AuctionService] settle: " .. tostring(err))
	end
end

-- ── the player's actions ────────────────────────────────────────────────────────────────────────────────────────

-- the checks every action shares; false = refuse quietly or with a toast
local function canAct(player: Player): boolean
	if not ready then
		toast(player, "auction_unavailable")
		return false
	end
	if not ProfileService.IsReal(player) then
		toast(player, "auction_unavailable") -- a profile that failed to load is never saved: nothing may leave it
		return false
	end
	local now = os.clock()
	if now - (lastAction[player] or -math.huge) < cfg.actionCooldown then
		toast(player, "auction_wait")
		return false
	end
	lastAction[player] = now
	return true
end

local function sell(player: Player, slot: number, amount: number, dollars: number)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local stack = profile.inventory[slot]
	if not stack or not Auction.tradable(stack) then
		toast(player, "auction_not_tradable")
		return
	end
	if amount > stack.count then
		return
	end
	local a = data(profile)
	local slots = cfg.slots + (profile.auctionSlots or 0) -- donate: «Дополнительный слот на Аукционе»
	if count(a.lots) + count(a.pendingSells) >= slots then
		toast(player, "auction_slots_full", slots)
		return
	end
	local summary: Summary? = nil
	ProfileService.Mutate(player, function(p)
		local s = p.inventory[slot]
		if not s or s.id ~= stack.id or s.count < amount then
			return
		end
		local item = deepCopy(s)
		item.count = amount
		s.count -= amount
		if s.count <= 0 then
			p.inventory[slot] = nil
		end
		local now = os.time()
		local new: Summary = {
			id = HttpService:GenerateGUID(false),
			item = item,
			price = dollars * Config.moneyScale,
			seller = player.UserId,
			sellerName = player.Name,
			createdAt = now,
			expiresAt = now + cfg.lotDays * 86400,
		}
		data(p).pendingSells[new.id] = new
		summary = new
	end)
	if not summary then
		return
	end
	local s = summary :: Summary
	if not saveNow(player) then
		-- nothing left the profile yet: undo
		ProfileService.Mutate(player, function(p)
			local d = data(p)
			if d.pendingSells[s.id] then
				d.pendingSells[s.id] = nil
				give(p, s.item)
			end
		end)
		toast(player, "auction_try_later")
		return
	end
	local created = false
	local ok = lotUpdate(s.id, function(old: any)
		if typeof(old) == "table" then
			created = old.status ~= "void" -- a retry of our own write
			return nil
		end
		created = true
		local lot: Lot = summaryOf(s) :: any
		lot.status = "active"
		return lot
	end)
	if ok and created then
		ProfileService.Mutate(player, function(p)
			local d = data(p)
			if d.pendingSells[s.id] then
				d.pendingSells[s.id] = nil
				d.lots[s.id] = s
			end
		end)
		indexSet(s)
		toast(player, "auction_listed", itemText(player, s.item), Strings.money(s.price))
	else
		-- not confirmed: read the key again at once (tombstone if missing → the item comes back)
		local state = settleSell(player, s.id)
		if state == "created" then
			toast(player, "auction_listed", itemText(player, s.item), Strings.money(s.price))
		elseif state == "void" then
			toast(player, "auction_try_later")
		else
			toast(player, "auction_pending")
		end
	end
	changed(player)
end

local function buy(player: Player, id: string, price: number)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local s = cached(id)
	if not s or s.expiresAt <= os.time() or s.price ~= price then
		toast(player, "auction_gone_listing")
		changed(player)
		return
	end
	if s.seller == player.UserId then
		toast(player, "auction_own_lot")
		return
	end
	if data(profile).pendingBuys[id] then
		return
	end
	if profile.coins < price then
		toast(player, "auction_no_money", Strings.money(price))
		return
	end
	local op = HttpService:GenerateGUID(false)
	local paid = false
	ProfileService.Mutate(player, function(p)
		local a = data(p)
		if p.coins >= price and not a.pendingBuys[id] then
			p.coins -= price
			a.pendingBuys[id] = { price = price, op = op, at = os.time(), seller = s.seller }
			paid = true
		end
	end)
	if not paid then
		return
	end
	if not saveNow(player) then
		-- nothing outside changed: the money back
		ProfileService.Mutate(player, function(p)
			local a = data(p)
			local pending = a.pendingBuys[id]
			if pending and pending.op == op then
				a.pendingBuys[id] = nil
				p.coins += pending.price
			end
		end)
		toast(player, "auction_try_later")
		return
	end
	local buyer = player.UserId
	local state: string? = nil
	local record: Lot? = nil
	local ok = lotUpdate(id, function(old: any)
		record = if typeof(old) == "table" then old else nil
		if not old then
			state = "gone"
			return nil
		end
		if old.buyOp == op then
			state = "won" -- our own earlier try landed
			return nil
		end
		if
			old.status ~= "active"
			or old.expiresAt <= os.time()
			or old.price ~= price
			or old.seller == buyer
		then
			state = "gone"
			return nil
		end
		old.status = "sold"
		old.buyer = buyer
		old.buyerName = player.Name
		old.buyOp = op
		old.soldAt = os.time()
		state = "won"
		return old
	end)
	if not ok then
		state, record = readBuy(id, op)
	end
	if not state then
		toast(player, "auction_pending")
		changed(player)
		return
	end
	finishBuy(player, id, op, state, record)
end

local function cancel(player: Player, id: string)
	local profile = ProfileService.Get(player)
	if not profile or not data(profile).lots[id] then
		return
	end
	local seller = player.UserId
	local ok = lotUpdate(id, function(old: any)
		if typeof(old) == "table" and old.status == "active" and old.seller == seller then
			old.status = "cancelled"
			old.cancelledAt = os.time()
			return old
		end
		return nil
	end)
	if ok then
		indexRemove(id)
		settleLot(player, id) -- cancelled → the item back; already sold → the money
	else
		toast(player, "auction_try_later")
	end
end

local function claim(player: Player)
	local back, left = 0, 0
	ProfileService.Mutate(player, function(p)
		local returns = data(p).returns
		for i = #returns, 1, -1 do
			local rest = put(p, returns[i])
			if rest then
				returns[i] = rest
				left += 1
			else
				table.remove(returns, i)
				back += 1
			end
		end
	end)
	if left > 0 then
		toast(player, "auction_claim_full", back, left)
	elseif back > 0 then
		toast(player, "auction_claimed", back)
	end
	changed(player)
end

-- the wrapper every remote goes through: types first, then one step at a time
local function action(fn: (Player, ...any) -> (), check: (...any) -> boolean)
	return function(player: Player, ...: any)
		if not check(...) or not canAct(player) or not lock(player) then
			return
		end
		local ok, err = pcall(fn, player, ...)
		unlock(player)
		if not ok then
			warn("[AuctionService] " .. tostring(err))
		end
	end
end

local function isId(v: any): boolean
	return typeof(v) == "string" and #v > 0 and #v <= 64 and v:match("^[%w%-]+$") ~= nil
end

local function isInt(v: any, lo: number, hi: number): boolean
	return typeof(v) == "number" and v == v and v == math.floor(v) and v >= lo and v <= hi
end

-- ── browsing ────────────────────────────────────────────────────────────────────────────────────────────────────

type Query = {
	category: string?,
	sort: string?, -- time / price / level
	desc: boolean?,
	minPrice: number?, -- dollars
	maxPrice: number?,
	minLevel: number?,
	maxLevel: number?,
	search: string?,
	page: number?,
}

local function num(v: any): number?
	return if typeof(v) == "number" and v == v and math.abs(v) < 1e15 then v else nil
end

local function query(player: Player, raw: any): any
	local clock = os.clock()
	if clock - (lastQuery[player] or -math.huge) < QUERY_COOLDOWN then
		return nil
	end
	lastQuery[player] = clock
	if not ready then
		return { lots = {}, total = 0, page = 1, pages = 1, now = os.time(), unavailable = true }
	end
	lastWanted = clock
	if clock - cacheAt > cfg.indexRefreshSeconds then
		refreshCache()
	end
	local q: Query = if typeof(raw) == "table" then raw else {}
	local category = if typeof(q.category) == "string"
			and table.find(Auction.CATEGORIES, q.category)
		then q.category
		else "all"
	local minPrice = (num(q.minPrice) or 0) * Config.moneyScale
	local maxPrice = (num(q.maxPrice) or math.huge) * Config.moneyScale
	local minLevel = num(q.minLevel) or -math.huge
	local maxLevel = num(q.maxLevel) or math.huge
	local search = if typeof(q.search) == "string" and #q.search > 0
		then Strings.lower(string.sub(q.search, 1, 64))
		else nil
	local locale = Strings.localeOf(player)
	local now = os.time()
	local list = {}
	for _, s in ipairs(cache) do
		local item = s.item
		local level = item.level or 0
		if
			s.expiresAt > now
			and (category == "all" or Auction.category(item.id) == category)
			and s.price >= minPrice
			and s.price <= maxPrice
			and level >= minLevel
			and level <= maxLevel
		then
			local found = not search
				or string.find(
					Strings.lower(Strings.itemName(item.id, item.level, locale)),
					search :: string,
					1,
					true
				) ~= nil
				or string.find(Strings.lower(s.sellerName), search :: string, 1, true) ~= nil
			if found then
				table.insert(list, s)
			end
		end
	end
	local sort = if q.sort == "price" or q.sort == "level" then q.sort else "time"
	local desc = q.desc ~= false
	table.sort(list, function(a, b)
		local x, y
		if sort == "price" then
			x, y = a.price, b.price
		elseif sort == "level" then
			x, y = a.item.level or 0, b.item.level or 0
		else
			x, y = a.createdAt, b.createdAt
		end
		if x == y then
			return a.id < b.id
		end
		if desc then
			return x > y
		end
		return x < y
	end)
	local pages = math.max(1, math.ceil(#list / cfg.pageSize))
	local page = math.clamp(if isInt(q.page, 1, 1e6) then q.page :: number else 1, 1, pages)
	local out = {}
	for i = (page - 1) * cfg.pageSize + 1, math.min(#list, page * cfg.pageSize) do
		table.insert(out, list[i])
	end
	return { lots = out, total = #list, page = page, pages = pages, now = now }
end

-- ── start ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function connectStores()
	local ok, store = pcall(function()
		local s = DataStoreService:GetDataStore(LOTS_STORE)
		s:GetAsync("probe") -- fails in Studio without API access
		return s
	end)
	if ok then
		lotStore = store
	elseif RunService:IsStudio() then
		memoryLots = {}
		warn("[AuctionService] no DataStore in Studio: lots live in memory until Play stops")
	else
		warn("[AuctionService] DataStore unavailable: " .. tostring(store))
		return false
	end
	local okMap, map = pcall(function()
		local m = MemoryStoreService:GetSortedMap(INDEX_MAP)
		m:GetRangeAsync(Enum.SortDirection.Ascending, 1)
		return m
	end)
	if okMap and not memoryLots then
		indexMap = map
	elseif memoryLots or RunService:IsStudio() then
		memoryIndex = {}
	else
		warn("[AuctionService] MemoryStore unavailable: " .. tostring(map))
		return false
	end
	return true
end

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "AuctionDebug"
	hook.OnInvoke = function(op: string, a: any, b: any, c: any, d: any): any
		if op == "fail" then
			failNext[a] = b or 1
			return true
		elseif op == "seed" then -- a lot from a fake seller (userId −1000): ("seed", itemId, count, dollars, level?)
			local now = os.time()
			local lot: Lot = {
				id = HttpService:GenerateGUID(false),
				item = { id = a, count = b or 1, level = d, books = if d then {} else nil },
				price = (c or 10) * Config.moneyScale,
				seller = -1000,
				sellerName = "QA_Seller",
				createdAt = now,
				expiresAt = now + cfg.lotDays * 86400,
				status = "active",
			}
			lotUpdate(lot.id, function()
				return lot
			end)
			indexSet(summaryOf(lot))
			return lot.id
		elseif op == "lot" then
			local record = nil
			lotUpdate(a, function(old: any)
				record = old
				return nil
			end)
			return if record then HttpService:JSONEncode(record) else nil
		elseif op == "expire" then -- the lot's time runs out now
			local done = false
			lotUpdate(a, function(old: any)
				if typeof(old) == "table" and old.status == "active" then
					old.expiresAt = os.time() - 1
					done = true
					return old
				end
				return nil
			end)
			indexRemove(a)
			return done
		elseif op == "buyas" then -- a fake buyer (userId −1001) buys the lot: the seller's payout path
			local seller: number? = nil
			lotUpdate(a, function(old: any)
				if typeof(old) == "table" and old.status == "active" then
					old.status = "sold"
					old.buyer = -1001
					old.buyerName = "QA_Buyer"
					old.buyOp = HttpService:GenerateGUID(false)
					old.soldAt = os.time()
					seller = old.seller
					return old
				end
				return nil
			end)
			indexRemove(a)
			notifySeller(seller, a)
			return seller ~= nil
		elseif op == "settle" then
			local player = Players:GetPlayerByUserId(a)
			if player then
				settleLocked(player, true)
				return true
			end
			return false
		elseif op == "state" then
			return HttpService:JSONEncode({
				ready = ready,
				memory = memoryLots ~= nil,
				cached = #cache,
				failNext = failNext,
			})
		end
		return nil
	end
	hook.Parent = ServerStorage
end

function AuctionService.Start()
	Remotes.event("AuctionUpdated")
	Remotes.event("AuctionSell").OnServerEvent
		:Connect(action(sell, function(slot: any, amount: any, dollars: any)
			return InventoryService.isSlot(slot)
				and isInt(amount, 1, 64)
				and isInt(dollars, cfg.minPrice, cfg.maxPrice)
		end))
	Remotes.event("AuctionBuy").OnServerEvent:Connect(action(buy, function(id: any, price: any)
		return isId(id) and isInt(price, 1, cfg.maxPrice * Config.moneyScale)
	end))
	Remotes.event("AuctionCancel").OnServerEvent:Connect(action(cancel, function(id: any)
		return isId(id)
	end))
	Remotes.event("AuctionClaim").OnServerEvent:Connect(action(claim, function()
		return true
	end))
	-- «Личные товары» opened: settle the player's lots now (sold ones pay out)
	Remotes.event("AuctionSettle").OnServerEvent:Connect(function(player: Player)
		local clock = os.clock()
		if clock - (lastOpenSettle[player] or -math.huge) < OPEN_SETTLE_COOLDOWN then
			return
		end
		lastOpenSettle[player] = clock
		settleLocked(player)
	end)
	Remotes.func("AuctionQuery").OnServerInvoke = query

	ProfileService.OnLoaded(function(player)
		task.spawn(function()
			while not ready and player.Parent do
				task.wait(1)
			end
			settleLocked(player, true)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastAction[player] = nil
		lastQuery[player] = nil
		lastOpenSettle[player] = nil
	end)
	debugHook()

	task.spawn(function()
		ready = connectStores()
		if not ready then
			return
		end
		refreshCache()
		pcall(function()
			MessagingService:SubscribeAsync(SOLD_TOPIC, function(message)
				local m = message.Data
				if typeof(m) ~= "table" or not isId(m.lot) or typeof(m.seller) ~= "number" then
					return
				end
				local seller = Players:GetPlayerByUserId(m.seller)
				if seller then
					task.spawn(function()
						if lock(seller, true) then
							pcall(settleLot, seller, m.lot)
							unlock(seller)
						end
					end)
				end
			end)
		end)
		-- the browse cache while someone browses; everyone's lots now and then (expired lots come back)
		task.spawn(function()
			while true do
				task.wait(cfg.indexRefreshSeconds)
				if os.clock() - lastWanted < 60 then
					refreshCache()
				end
			end
		end)
		while true do
			task.wait(cfg.settleSeconds)
			for _, player in ipairs(Players:GetPlayers()) do
				local p = ProfileService.Get(player)
				local a = p and (p :: any).auction
				if
					a
					and (
						next(a.lots or {})
						or next(a.pendingSells or {})
						or next(a.pendingBuys or {})
					)
				then
					settleLocked(player)
				end
			end
		end
	end)
end

return AuctionService
