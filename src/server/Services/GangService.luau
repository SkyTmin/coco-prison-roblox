--!strict
-- Gangs «Банды» [вики HANDBOOK-WIKI; клиент gang.*; docs/research/remaining-features-design.md §1.1–1.4, 1.6]. A gang
-- is one document for all servers: DataStore Gangs_v1 (key = id), every change one UpdateAsync that re-checks the
-- rights, slots, points and money inside the transform (two servers editing one gang never lose a write); the tag is
-- unique through GangTags_v1 (UpdateAsync «free / taken»). After a change MessagingService (topic Gangs_v1) tells the
-- other servers to re-read their copy; a gang with members online is re-read at least every POLL_SECONDS anyway.
-- Invites live in a MemoryStore hash (GangInvites_v1, userId → list, 5 min). Quest progress and member levels are
-- collected here and written once every Config.gangs.flushSeconds per gang [решение: бюджет DataStore].
-- Money between the profile and the gang (create, deposit, withdraw) and joining go in steps that can never
-- duplicate: (1) note the step in p.gangOps and save the profile, (2) the gang's UpdateAsync records the op id in
-- doc.ops, (3) clear the note (and refund when (2) refused). A crash between the steps is settled on the next load by
-- looking the op id up in the document. The profile side of membership (p.gang.id) follows the document: a player
-- the document does not list (kicked, disbanded) loses it when this server sees that.
-- Perks are read where they apply: DigService (Фарт, Конверсия), NeedsService (Выносливость, Каратель), MobService
-- (Охотник), CombatService / BookService (PvP inside the gang). The base / library / forge / ghetto stages read
-- `GangService.level(profile, id)` (= Gangs.level of the player's gang).
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)

type Gang = Gangs.Gang
type Profile = Types.Profile

local GANG_STORE = "Gangs_v1"
local TAG_STORE = "GangTags_v1"
local INVITE_MAP = "GangInvites_v1"
local TOPIC = "Gangs_v1" -- one topic for all gangs (payload id) [решение: лимит подписок на сервер]
local POLL_SECONDS = 60 -- [решение] a gang with members online is re-read at least this often
local OP_KEEP_SECONDS = 14 * 86400 -- an op id is remembered two weeks (settling a crashed step)
local OPS_MAX = 300
local STALE_TAG_SECONDS = 600 -- a tag reserved by a creation that never finished is free again after this
local ACTION_GAP = 0.4
-- steps that save the profile: DataStore writes one key at most every 6 s [решение: не упираться в лимит ключа]
local SAVING_GAP = 6
local SAVING_OPS = { create = true, accept = true, deposit = true, withdraw = true, upgrade = true }

local cfg = Gangs.cfg
local GangService = {}

local gangStore: DataStore? = nil
local tagStore: DataStore? = nil
local inviteMap: MemoryStoreHashMap? = nil
-- Studio without API access: everything lives in memory until Play stops
local memoryGangs: { [string]: any }? = nil
local memoryTags: { [string]: any }? = nil
local memoryInvites: { [string]: any }? = nil

type Cached = { doc: Gang?, readAt: number }
type Pending = {
	kinds: { [string]: number }, -- "kind|what" → amount
	levels: { [string]: { level: number, name: string } },
	goal: { [string]: number }, -- member key → blocks towards the «Задания» goal
}
local cache: { [string]: Cached } = {}
local pending: { [string]: Pending } = {}
local busy: { [Player]: boolean } = {}
local lastAction: { [Player]: number } = {}
local lastSaving: { [Player]: number } = {}
local refreshQueued: { [string]: boolean } = {}
local rng = Random.new()
-- called with (gangId, doc?) whenever this server sees a new copy of a gang (GangHouseService: chest / NPCs by upgrades)
local changedHooks: { (string, Gang?) -> () } = {}

-- ── helpers ─────────────────────────────────────────────────────────────────────────────────────────────────────

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in pairs(value :: any) do
		out[k] = deepCopy(v)
	end
	return out :: any
end

local function now(): number
	return os.time()
end

local function coins(dollars: number): number
	return math.floor(dollars * Config.moneyScale + 0.5)
end

-- arguments of a localized message: a {t = key, a = {...}} table is translated for each reader
local function render(arg: any, locale: string): any
	if typeof(arg) == "table" and typeof(arg.quest) == "table" then
		return Gangs.questText(arg.quest, locale)
	end
	if typeof(arg) == "table" and typeof(arg.t) == "string" then
		local inner = {}
		for i, v in ipairs(arg.a or {}) do
			inner[i] = render(v, locale)
		end
		return Strings.t(arg.t, locale, table.unpack(inner))
	end
	return arg
end

local ERR_ARGS: { [string]: () -> { any } } = {
	gang_err_level = function()
		return { cfg.minLevel }
	end,
	gang_err_target_level = function()
		return { cfg.minLevel }
	end,
	gang_err_deputies = function()
		return { cfg.deputiesMax }
	end,
	gang_err_tag = function()
		return { cfg.tagLength }
	end,
	gang_err_name = function()
		return { cfg.nameMax }
	end,
	gang_err_min_deposit = function()
		return { Strings.money(coins(cfg.treasury.minDeposit)) }
	end,
}

local function toast(player: Player, key: string, ...: any)
	local locale = Strings.localeOf(player)
	local args = table.pack(...)
	while args.n > 0 and args[args.n] == nil do
		args.n -= 1
	end
	if args.n == 0 and ERR_ARGS[key] then
		args = table.pack(table.unpack(ERR_ARGS[key]()))
	end
	for i = 1, args.n do
		args[i] = render(args[i], locale)
	end
	Remotes.event("Toast"):FireClient(player, Strings.t(key, locale, table.unpack(args, 1, args.n)))
end

local function gangIdOf(p: Profile?): string?
	return if p and p.gang then p.gang.id else nil
end

local function throttled(player: Player): boolean
	local t = os.clock()
	if t - (lastAction[player] or -math.huge) < ACTION_GAP then
		return true
	end
	lastAction[player] = t
	return false
end

-- player-typed text goes through the Roblox filter before anyone sees it (nil = the filter did not answer)
local function filter(text: string, userId: number): string?
	if text == "" then
		return ""
	end
	local ok, result = pcall(function()
		local r = TextService:FilterStringAsync(text, userId, Enum.TextFilterContext.PublicChat)
		return r:GetNonChatStringForBroadcastAsync()
	end)
	if ok and typeof(result) == "string" then
		return result
	end
	-- Studio test players (negative ids) cannot be filtered: the text stays as typed there
	return if RunService:IsStudio() then text else nil
end

-- ── stores ──────────────────────────────────────────────────────────────────────────────────────────────────────

-- UpdateAsync on a store (or the Studio memory): returns whether the call went through, what the transform returned
-- (nil = cancelled) and the value it saw last
local function storeUpdate(
	store: DataStore?,
	memory: { [string]: any }?,
	key: string,
	transform: (any) -> any
): (boolean, any, any)
	local seen, result = nil, nil
	if memory then
		seen = deepCopy(memory[key])
		result = transform(deepCopy(seen))
		if result ~= nil then
			memory[key] = deepCopy(result)
		end
		return true, result, seen
	end
	if not store then
		return false, nil, nil
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old: any)
			seen = deepCopy(old)
			result = transform(old)
			return result
		end)
	end)
	if not ok then
		warn("[GangService] " .. key .. ": " .. tostring(err))
		return false, nil, nil
	end
	return true, result, seen
end

local function storeRead(store: DataStore?, memory: { [string]: any }?, key: string): (boolean, any)
	if memory then
		return true, deepCopy(memory[key])
	end
	if not store then
		return false, nil
	end
	local ok, value = pcall(function()
		return (store :: DataStore):GetAsync(key)
	end)
	return ok, if ok then value else nil
end

local function gangUpdate(id: string, transform: (Gang?) -> Gang?): (boolean, Gang?, Gang?)
	return storeUpdate(gangStore, memoryGangs, id, transform)
end

local function gangRead(id: string): (boolean, Gang?)
	local ok, value = storeRead(gangStore, memoryGangs, id)
	return ok, if typeof(value) == "table" then value :: Gang else nil
end

local function tagUpdate(tag: string, transform: (any) -> any): (boolean, any, any)
	return storeUpdate(tagStore, memoryTags, tag, transform)
end

local function releaseTag(tag: string, id: string)
	tagUpdate(tag, function(old: any)
		if typeof(old) == "table" and old.id == id then
			return { free = true, at = now() }
		end
		return nil
	end)
end

local function inviteUpdate(userId: number, transform: (any) -> any): boolean
	local key = tostring(userId)
	if memoryInvites then
		local new = transform(deepCopy(memoryInvites[key]))
		if new ~= nil then
			memoryInvites[key] = deepCopy(new)
		end
		return true
	end
	if not inviteMap then
		return false
	end
	local ok, err = pcall(function()
		(inviteMap :: MemoryStoreHashMap):UpdateAsync(key, transform, cfg.inviteSeconds)
	end)
	if not ok then
		warn("[GangService] invites: " .. tostring(err))
	end
	return ok
end

local function invitesOf(userId: number): { any }
	local list: any = nil
	if memoryInvites then
		list = deepCopy(memoryInvites[tostring(userId)])
	elseif inviteMap then
		local ok, value = pcall(function()
			return (inviteMap :: MemoryStoreHashMap):GetAsync(tostring(userId))
		end)
		list = if ok then value else nil
	end
	local out = {}
	if typeof(list) == "table" then
		for _, entry in ipairs(list) do
			if typeof(entry) == "table" and (entry.expires or 0) > now() then
				table.insert(out, entry)
			end
		end
	end
	return out
end

local function publish(data: { [string]: any })
	data.server = game.JobId
	pcall(function()
		MessagingService:PublishAsync(TOPIC, data)
	end)
end

-- ── the local copy and what members see ────────────────────────────────────────────────────────────────────────

local MIRRORED_UPGRADES = { "ghetto", "library", "forge", "chests" }

local function viewOf(doc: Gang, player: Player): any
	local view: any = deepCopy(doc)
	view.ops = nil
	view.you = Gangs.roleOf(doc, player.UserId)
	view.now = now()
	return view
end

local function mirror(player: Player, doc: Gang?)
	player:SetAttribute("GangId", if doc then doc.id else nil)
	player:SetAttribute("GangTag", if doc then doc.tag else nil)
	player:SetAttribute("GangColor", if doc then doc.color else nil)
	-- the upgrades the base / ghetto stages show on the client (location cards, NPC windows): GangUp_<id> = level
	for _, upgradeId in ipairs(MIRRORED_UPGRADES) do
		player:SetAttribute(
			"GangUp_" .. upgradeId,
			if doc then Gangs.level(doc, upgradeId) else nil
		)
	end
end

local function sendState(player: Player)
	local p = ProfileService.Get(player)
	local id = gangIdOf(p)
	local c = id and cache[id]
	local doc = c and c.doc
	if doc and not doc.disbanded and doc.members[tostring(player.UserId)] then
		mirror(player, doc)
		Remotes.event("GangState"):FireClient(player, viewOf(doc, player))
	else
		mirror(player, nil)
		Remotes.event("GangState"):FireClient(player, false)
	end
end

local function sendInvites(player: Player)
	Remotes.event("GangInvites"):FireClient(player, invitesOf(player.UserId))
end

-- the document changed: push it to the members here; a member it no longer lists loses the gang
local function pushState(id: string)
	local c = cache[id]
	local doc = c and c.doc
	for _, player in ipairs(Players:GetPlayers()) do
		local p = ProfileService.Get(player)
		if not p or gangIdOf(p) ~= id then
			continue
		end
		local listed = doc ~= nil
			and not doc.disbanded
			and doc.members[tostring(player.UserId)] ~= nil
		if listed then
			sendState(player)
		elseif not busy[player] then -- the player's own action finishes the profile side itself
			ProfileService.Mutate(player, function(q)
				if q.gang and q.gang.id == id then
					q.gang = { leftAt = q.gang.leftAt }
				end
			end)
			sendState(player)
			toast(player, if doc and doc.disbanded then "gang_disbanded" else "gang_kicked")
		end
	end
end

local function setCache(id: string, doc: Gang?)
	local c = cache[id]
	if c and c.doc and doc and (doc.version or 0) < (c.doc.version or 0) then
		return -- an older read arrived after a newer write
	end
	cache[id] = { doc = doc, readAt = os.clock() }
	pushState(id)
	for _, fn in ipairs(changedHooks) do
		task.spawn(fn, id, doc)
	end
end

local function refreshGang(id: string)
	local ok, doc = gangRead(id)
	if ok then
		setCache(id, doc)
	end
end

local function queueRefresh(id: string)
	if refreshQueued[id] then
		return
	end
	refreshQueued[id] = true
	task.delay(0.3 + rng:NextNumber(), function()
		refreshQueued[id] = nil
		refreshGang(id)
	end)
end

local function pruneOps(doc: Gang)
	local ops = doc.ops or {}
	doc.ops = ops
	local t, list = now(), {}
	for op, at in pairs(ops) do
		if at < t - OP_KEEP_SECONDS then
			ops[op] = nil
		else
			table.insert(list, { op, at })
		end
	end
	if #list > OPS_MAX then
		table.sort(list, function(a, b)
			return a[2] < b[2]
		end)
		for i = 1, #list - OPS_MAX do
			ops[list[i][1]] = nil
		end
	end
end

-- Runs change(doc) inside the gang's UpdateAsync (it may run more than once: reset outputs at its top). change returns
-- nil to write, an error key to cancel, or "_done" when the change is already there (no write, still a success).
-- Returns the error key (nil = success) and the document after it; a success updates the local copy.
local function edit(id: string, change: (Gang) -> string?, quiet: boolean?): (string?, Gang?)
	local err: string? = nil
	local ok, result, seen = gangUpdate(id, function(old: Gang?): Gang?
		err = nil
		if typeof(old) ~= "table" or old.disbanded then
			err = "gang_err_no_gang"
			return nil
		end
		local doc = old :: Gang
		err = change(doc)
		if err then
			return nil
		end
		doc.version = (doc.version or 0) + 1
		pruneOps(doc)
		return doc
	end)
	if not ok then
		return "gang_err_try_later", nil
	end
	local doc: Gang? = result
	if err == "_done" then
		err, doc = nil, seen
	end
	if err == nil and doc then
		setCache(id, doc)
		if not quiet then
			publish({ ev = "refresh", id = id })
		end
	end
	return err, doc
end

-- a message to every member online on any server
local function say(id: string, key: string, ...: any)
	local args = { ... }
	for _, player in ipairs(Players:GetPlayers()) do
		if gangIdOf(ProfileService.Get(player)) == id then
			toast(player, key, table.unpack(args))
		end
	end
	publish({ ev = "say", id = id, key = key, args = args })
end

local function cachedGang(player: Player): (Profile?, string?, Gang?)
	local p = ProfileService.Get(player)
	local id = gangIdOf(p)
	local c = id and cache[id]
	return p, id, c and c.doc
end

-- ── perks and the shared API ───────────────────────────────────────────────────────────────────────────────────

function GangService.OnChanged(fn: (string, Gang?) -> ())
	table.insert(changedHooks, fn)
end

-- the player's gang as this server knows it (nil = none)
function GangService.gangOf(p: any): Gang?
	local id = gangIdOf(p)
	local c = id and cache[id]
	local doc = c and c.doc
	return if doc and not doc.disbanded then doc else nil
end

-- an upgrade level of the player's gang (the base, library, forge, ghetto and chests stages read this)
function GangService.level(p: any, upgradeId: string): number
	return Gangs.level(GangService.gangOf(p), upgradeId)
end

-- a perk's chance / share for the player (0 without a gang)
function GangService.perk(p: any, upgradeId: string): number
	return Gangs.perk(GangService.gangOf(p), upgradeId)
end

-- two members of one gang with its PvP off do not hurt each other [клиент gang.settings.pvp]
function GangService.allies(a: Player, b: Player): boolean
	local pa, pb = ProfileService.Get(a), ProfileService.Get(b)
	local id = gangIdOf(pa)
	if not id or id ~= gangIdOf(pb) then
		return false
	end
	local doc = GangService.gangOf(pa)
	return doc ~= nil and doc.pvp ~= true
end

-- the Библиотекарь on the base [владелец 28.10: «Перерабатывайте книги в очки и при достижении определённого количества
-- банда получит награду», полоса 0 / 4000]: a book's points fill gang.library up to the goal (one UpdateAsync; the caller
-- has taken the book and gives it back on an error). Returns the error key, nil = written.
function GangService.addLibrary(player: Player, amount: number): string?
	local id = gangIdOf(ProfileService.Get(player))
	if not id then
		return "gang_err_no_gang"
	end
	if amount <= 0 or amount ~= amount or amount >= math.huge then
		return "gang_library_need_book"
	end
	local goal = cfg.base.library.goal
	return (
		edit(id, function(gang)
			if not gang.members[tostring(player.UserId)] then
				return "gang_err_no_gang"
			end
			local have = gang.library or 0
			if have >= goal then
				return "gang_library_full"
			end
			gang.library = math.min(goal, have + math.floor(amount))
			return nil
		end)
	)
end

-- «Забрать награду»: a full bar becomes the reward (gang points) and starts again from 0; any member may take it
-- [решение]
function GangService.claimLibrary(player: Player)
	local id = gangIdOf(ProfileService.Get(player))
	if not id then
		toast(player, "gang_err_no_gang")
		return
	end
	local lib = cfg.base.library
	local err = edit(id, function(gang)
		if not gang.members[tostring(player.UserId)] then
			return "gang_err_no_gang"
		end
		if (gang.library or 0) < lib.goal then
			return "gang_library_not_full"
		end
		gang.library = 0
		gang.points += lib.reward.points
		return nil
	end)
	if err then
		toast(player, err)
		return
	end
	say(id, "gang_library_claimed", player.Name, lib.reward.points)
end

-- quest progress of a member (Gangs.QUEST_KINDS; `what` = the boss / mob id of bossKill / mobKill), written by the
-- flush; dig also counts towards the member's own goal of the «Задания» tab
function GangService.progress(player: Player?, kind: string, amount: number, what: string?)
	if not player or amount <= 0 or amount ~= amount or amount >= math.huge then
		return
	end
	local p = ProfileService.Get(player)
	local id = gangIdOf(p)
	local doc = GangService.gangOf(p)
	if not id or not doc then
		return
	end
	local key = tostring(player.UserId)
	local wants = Gangs.wants(doc, kind, what)
	local goal = kind == "dig"
		and now() >= Gangs.questsOpenAt(doc)
		and Gangs.goalOf(doc, key, now()) < cfg.quests.goal.blocks
	if not wants and not goal then
		return
	end
	local pend = pending[id] or { kinds = {}, levels = {}, goal = {} }
	pending[id] = pend
	if wants then
		local slot = kind .. "|" .. (what or "")
		pend.kinds[slot] = (pend.kinds[slot] or 0) + amount
	end
	if goal then
		pend.goal[key] = (pend.goal[key] or 0) + amount
	end
end

function GangService.progressByUserId(userId: any, kind: string, amount: number, what: string?)
	if typeof(userId) == "number" then
		GangService.progress(Players:GetPlayerByUserId(userId), kind, amount, what)
	end
end

-- one count per gang for an event several members share (a boss kill: every gang that hit it counts it once)
function GangService.progressOnce(userIds: { any }, kind: string, amount: number, what: string?)
	local seen: { [string]: boolean } = {}
	for _, userId in ipairs(userIds) do
		local player = if typeof(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
		local id = player and gangIdOf(ProfileService.Get(player))
		if player and id and not seen[id] then
			seen[id] = true
			GangService.progress(player, kind, amount, what)
		end
	end
end

-- «Нанести N урона игрокам» and «Восстановить N ❤ здоровья» from the player's own Humanoid: a drop with a fresh
-- LastHitBy of another player is that player's damage, a rise while alive is healing
local function watchHealth(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		local delta = health - last
		last = health
		if delta > 0 and health > 0 then
			GangService.progress(player, "heal", delta)
		elseif delta < 0 then
			local by = humanoid:GetAttribute("LastHitBy")
			local at = humanoid:GetAttribute("LastHitAt")
			if
				typeof(by) == "number"
				and by ~= player.UserId
				and typeof(at) == "number"
				and os.clock() - at <= 1
			then
				GangService.progressByUserId(by, "pvpDamage", -delta)
			end
		end
	end)
end

-- ── quests: rewards and the flush ──────────────────────────────────────────────────────────────────────────────

-- a finished quest: the points (× the «Задания» multiplier) are in the document already, members are told
local function reward(doc: Gang, quest: Gangs.Quest, points: number)
	say(doc.id, "gang_announce_quest", { quest = quest }, points)
end

local function needsQuests(doc: Gang, t: number): boolean
	if t < Gangs.questsOpenAt(doc) then
		return false
	end
	local state = doc.quests
	return not state or state.day ~= Gangs.dayIndex(t) or state.week ~= Gangs.weekIndex(t)
end

local function newPending(): Pending
	return { kinds = {}, levels = {}, goal = {} }
end

local function flushGang(id: string)
	local pend = pending[id]
	pending[id] = nil
	local finished: { { quest: Gangs.Quest, points: number } } = {}
	local announce = false
	local err, doc = edit(id, function(gang)
		finished = {}
		local t = now()
		local changed = Gangs.refreshQuests(gang, t, rng)
		if pend then
			for key, info in pairs(pend.levels) do
				local m = gang.members[key]
				if m then
					m.level, m.name = info.level, info.name
				end
			end
			-- the goal first: a member who reaches it lifts the multiplier for the quests finished in this flush
			for key, amount in pairs(pend.goal) do
				Gangs.addGoal(gang, key, amount, t)
				changed = true
			end
			for slot, amount in pairs(pend.kinds) do
				local kind, what = string.match(slot, "^([^|]*)|(.*)$")
				if kind then
					local list =
						Gangs.addProgress(gang, kind, amount, if what == "" then nil else what, t)
					for _, done in ipairs(list) do
						table.insert(finished, done)
					end
					changed = true
				end
			end
		end
		announce = changed or #finished > 0
		return nil
	end, true)
	if err == "gang_err_try_later" and pend then
		-- the store did not answer: the progress waits for the next flush
		local back = pending[id] or newPending()
		pending[id] = back
		for slot, amount in pairs(pend.kinds) do
			back.kinds[slot] = (back.kinds[slot] or 0) + amount
		end
		for key, amount in pairs(pend.goal) do
			back.goal[key] = (back.goal[key] or 0) + amount
		end
		for key, info in pairs(pend.levels) do
			back.levels[key] = back.levels[key] or info
		end
		return
	end
	if err == nil and doc then
		if announce then
			publish({ ev = "refresh", id = id })
		end
		for _, done in ipairs(finished) do
			reward(doc, done.quest, done.points)
		end
	end
end

-- every flushSeconds: members' levels and names, collected progress, quest refreshes; every POLL_SECONDS a re-read
local function tick()
	local online: { [string]: boolean } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local p = ProfileService.Get(player)
		local id = gangIdOf(p)
		local doc = GangService.gangOf(p)
		if p and id then
			online[id] = true
		end
		if p and id and doc then
			local key = tostring(player.UserId)
			local m = doc.members[key]
			if m and (m.level ~= p.level or m.name ~= player.Name) then
				local pend = pending[id] or { kinds = {}, levels = {}, goal = {} }
				pending[id] = pend
				pend.levels[key] = { level = p.level, name = player.Name }
			end
		end
	end
	local t = now()
	for id in pairs(online) do
		local c = cache[id]
		local doc = c and c.doc
		if c and (pending[id] or (doc and needsQuests(doc, t))) then
			task.spawn(flushGang, id)
		elseif not c or os.clock() - c.readAt >= POLL_SECONDS then
			task.spawn(refreshGang, id) -- stale, or the read at join failed
		end
	end
	for id in pairs(cache) do
		if not online[id] and not pending[id] then
			cache[id] = nil
		end
	end
end

-- ── the profile side: settling crashed steps ───────────────────────────────────────────────────────────────────

-- puts money back by a note: $ (coins) or, for a creation paid with crystals (cur = "crystals"), the crystals
local function refund(q: Profile, amount: number, cur: string?)
	if cur == "crystals" then
		q.crystals = (q.crystals or 0) + amount
	else
		q.coins += amount
	end
end

local function clearNote(player: Player, op: string, apply: ((Profile) -> ())?)
	ProfileService.Mutate(player, function(q)
		if q.gangOps and q.gangOps[op] then
			q.gangOps[op] = nil
			if next(q.gangOps) == nil then
				q.gangOps = nil
			end
			if apply then
				apply(q)
			end
		end
	end)
end

local function settle(player: Player)
	local p = ProfileService.Get(player)
	if not p or not p.gangOps then
		return
	end
	for op, note in pairs(table.clone(p.gangOps)) do
		local ok, doc = gangRead(note.gang)
		if not ok then
			continue -- the store did not answer: the note waits for the next load
		end
		local key = tostring(player.UserId)
		local member = doc ~= nil and not doc.disbanded and doc.members[key] ~= nil
		local applied = doc ~= nil and doc.ops ~= nil and doc.ops[op] ~= nil
		local amount = note.amount or 0
		if note.kind == "create" then
			clearNote(player, op, function(q)
				if member then
					q.gang = { id = note.gang, leftAt = q.gang and q.gang.leftAt }
				elseif doc == nil then
					refund(q, amount, note.cur) -- the gang was never written: the money comes back
				end
			end)
			if doc == nil and note.tag then
				releaseTag(note.tag, note.gang)
			end
		elseif note.kind == "join" then
			clearNote(player, op, function(q)
				if member then
					q.gang = { id = note.gang, leftAt = q.gang and q.gang.leftAt }
				end
			end)
		elseif note.kind == "deposit" or note.kind == "upgrade" then
			clearNote(player, op, function(q)
				if not applied then
					q.coins += amount
				end
			end)
		elseif note.kind == "withdraw" then
			clearNote(player, op, function(q)
				if applied then
					q.coins += amount
				end
			end)
		else
			clearNote(player, op)
		end
	end
end

local function onLoaded(player: Player)
	settle(player)
	local id = gangIdOf(ProfileService.Get(player))
	if id then
		local ok, doc = gangRead(id)
		if ok then
			setCache(id, doc) -- also drops the gang from the profile when it no longer lists the player
		end
	end
	sendState(player)
end

-- ── actions ─────────────────────────────────────────────────────────────────────────────────────────────────────

local function cooldownLeft(p: Profile): number
	local leftAt = p.gang and p.gang.leftAt
	return if leftAt then math.max(0, leftAt + cfg.rejoinCooldownSeconds - now()) else 0
end

-- may this player enter a gang now (create or join)? returns the error key and its argument
local function canEnter(p: Profile): (string?, any)
	if gangIdOf(p) then
		return "gang_err_has_gang", nil
	end
	if p.gangOps and next(p.gangOps) then
		return "gang_err_try_later", nil
	end
	if p.level < cfg.minLevel then
		return "gang_err_level", cfg.minLevel
	end
	local left = cooldownLeft(p)
	if left > 0 then
		return "gang_err_cooldown", Gangs.clock(left)
	end
	return nil, nil
end

local function note(player: Player, op: string, entry: any, take: number?): boolean
	local done = false
	ProfileService.Mutate(player, function(q)
		local crystals = entry.cur == "crystals"
		local have = if crystals then q.crystals or 0 else q.coins
		if take and have < take then
			return
		end
		if crystals then
			q.crystals = have - (take or 0)
		else
			q.coins -= take or 0
		end
		q.gangOps = q.gangOps or {}
		(q.gangOps :: any)[op] = entry
		done = true
	end)
	return done
end

local function create(player: Player, form: any, force: boolean?)
	local p = ProfileService.Get(player)
	if not p or typeof(form) ~= "table" then
		return
	end
	local err, arg = canEnter(p)
	if err and not (force and err ~= "gang_err_has_gang" and err ~= "gang_err_try_later") then
		toast(player, err, arg)
		return
	end
	-- 15 000 $ or 499 crystals [владелец 28.10: «Создать за 15,000 $» / «Создать за 499 💎»]
	local cur = if form.pay == "crystals" then "crystals" else nil
	local cost = if force then 0 elseif cur then cfg.createCrystals else coins(cfg.createCost)
	local function short()
		if cur then
			toast(player, "gang_err_crystals", Strings.big(cost))
		else
			toast(player, "gang_err_money", Strings.money(cost))
		end
	end
	if (if cur then p.crystals or 0 else p.coins) < cost then
		short()
		return
	end
	local tag, tagErr = Gangs.checkTag(form.tag)
	local name, nameErr = Gangs.checkName(form.name)
	local desc, descErr = Gangs.checkDesc(form.desc)
	if not tag or not name or not desc then
		toast(player, (tagErr or nameErr or descErr) :: string)
		return
	end
	local color = if typeof(form.color) == "number" and cfg.colors[form.color]
		then form.color
		else 1
	local icon = if typeof(form.icon) == "number" and cfg.emblems[form.icon] then form.icon else 1
	local cleanName, cleanDesc, cleanTag =
		filter(name, player.UserId), filter(desc, player.UserId), filter(tag, player.UserId)
	if not cleanName or not cleanDesc or not cleanTag then
		toast(player, "gang_err_try_later")
		return
	end
	if
		cleanTag ~= tag
		or (string.find(cleanName, "#", 1, true) and not string.find(name, "#", 1, true))
	then
		toast(player, "gang_err_filter")
		return
	end
	local id = HttpService:GenerateGUID(false)
	-- 1. the tag: free, released, or reserved long ago by a creation that never wrote its gang
	local staleId: string? = nil
	local function reserve(): (boolean, boolean, any)
		local got = false
		local ok, _, seen = tagUpdate(tag, function(old: any)
			got = false
			if
				typeof(old) ~= "table"
				or old.free
				or old.id == id
				or (staleId ~= nil and old.id == staleId)
			then
				got = true
				return { id = id, at = now() }
			end
			return nil
		end)
		return ok, got, seen
	end
	local ok, got, seen = reserve()
	if
		ok
		and not got
		and typeof(seen) == "table"
		and (seen.at or 0) < now() - STALE_TAG_SECONDS
	then
		local readOk, owner = gangRead(seen.id)
		if readOk and (owner == nil or owner.disbanded) then
			staleId = seen.id
			ok, got = reserve()
		end
	end
	if not ok then
		toast(player, "gang_err_try_later")
		return
	end
	if not got then
		toast(player, "gang_err_tag_taken")
		return
	end
	-- 2. the money out of the profile, noted and saved
	local op = HttpService:GenerateGUID(false)
	if
		not note(
			player,
			op,
			{ kind = "create", gang = id, amount = cost, cur = cur, tag = tag, at = now() },
			cost
		)
	then
		releaseTag(tag, id)
		short()
		return
	end
	if not ProfileService.SaveNow(player) then
		clearNote(player, op, function(q)
			refund(q, cost, cur)
		end)
		releaseTag(tag, id)
		toast(player, "gang_err_try_later")
		return
	end
	-- 3. the document
	local t = now()
	local doc: Gang = {
		id = id,
		name = cleanName,
		tag = tag,
		color = color,
		icon = icon,
		desc = cleanDesc,
		leader = player.UserId,
		members = {
			[tostring(player.UserId)] = {
				role = "leader",
				name = player.Name,
				joinedAt = t,
				level = p.level,
			},
		},
		upgrades = {},
		points = 0,
		treasury = 0,
		treasuryLog = {},
		pvp = cfg.pvpDefault == true,
		ops = { [op] = t },
		createdAt = t,
		v2 = true,
		version = 1,
	}
	local written, stored = gangUpdate(id, function(old: Gang?): Gang?
		if old ~= nil then
			return nil
		end
		return deepCopy(doc)
	end)
	local created = written and stored ~= nil
	clearNote(player, op, function(q)
		if created then
			q.gang = { id = id, leftAt = q.gang and q.gang.leftAt }
		else
			refund(q, cost, cur)
		end
	end)
	if not created then
		releaseTag(tag, id)
		toast(player, "gang_err_try_later")
		return
	end
	setCache(id, stored)
	sendState(player)
	toast(player, "gang_created", cleanName, tag)
end

local function resolvePlayer(name: string): (number?, string?)
	for _, other in ipairs(Players:GetPlayers()) do
		if string.lower(other.Name) == string.lower(name) then
			return other.UserId, other.Name
		end
	end
	local ok, userId = pcall(function()
		return Players:GetUserIdFromNameAsync(name)
	end)
	if not ok or typeof(userId) ~= "number" then
		return nil, nil
	end
	local okName, realName = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	return userId, if okName then realName else name
end

-- the invite toast for a player online on this server
local function inviteArrived(userId: number, from: string, name: string, tag: string)
	local target = Players:GetPlayerByUserId(userId)
	if target then
		toast(target, "gang_invite_got", from, name, tag)
		sendInvites(target)
	end
end

local function invite(player: Player, rawName: any)
	local _, id, doc = cachedGang(player)
	if not id or not doc then
		toast(player, "gang_err_no_gang")
		return
	end
	if not Gangs.can(Gangs.roleOf(doc, player.UserId), "invite") then
		toast(player, Gangs.rightsError("invite"))
		return
	end
	if Gangs.memberCount(doc) >= Gangs.slots(doc) then
		toast(player, "gang_err_full")
		return
	end
	if
		typeof(rawName) ~= "string"
		or #rawName < 3
		or #rawName > 20
		or not string.match(rawName, "^[%w_]+$")
	then
		toast(player, "gang_err_player")
		return
	end
	local userId, name = resolvePlayer(rawName)
	if not userId or userId == player.UserId then
		toast(player, "gang_err_player")
		return
	end
	if doc.members[tostring(userId)] then
		toast(player, "gang_err_already_member")
		return
	end
	local entry = {
		gang = id,
		name = doc.name,
		tag = doc.tag,
		from = player.Name,
		expires = now() + cfg.inviteSeconds,
	}
	local ok = inviteUpdate(userId, function(old: any)
		local list = {}
		if typeof(old) == "table" then
			for _, e in ipairs(old) do
				if typeof(e) == "table" and e.gang ~= id and (e.expires or 0) > now() then
					table.insert(list, e)
				end
			end
		end
		table.insert(list, entry)
		while #list > cfg.invitesMax do
			table.remove(list, 1)
		end
		return list
	end)
	if not ok then
		toast(player, "gang_err_try_later")
		return
	end
	toast(player, "gang_invited", name or rawName)
	inviteArrived(userId, player.Name, doc.name, doc.tag)
	publish({ ev = "invite", user = userId, from = player.Name, name = doc.name, tag = doc.tag })
end

local function dropInvite(userId: number, gangId: string)
	inviteUpdate(userId, function(old: any)
		if typeof(old) ~= "table" then
			return nil
		end
		local list = {}
		for _, e in ipairs(old) do
			if typeof(e) == "table" and e.gang ~= gangId and (e.expires or 0) > now() then
				table.insert(list, e)
			end
		end
		return list
	end)
end

local function join(player: Player, gangId: string, force: boolean?)
	local p = ProfileService.Get(player)
	if not p then
		return
	end
	local err, arg = canEnter(p)
	if err and not (force and err ~= "gang_err_has_gang" and err ~= "gang_err_try_later") then
		toast(player, err, arg)
		return
	end
	if not force then
		local found = false
		for _, e in ipairs(invitesOf(player.UserId)) do
			if e.gang == gangId then
				found = true
			end
		end
		if not found then
			toast(player, "gang_err_invite_not_found")
			return
		end
	end
	local op = HttpService:GenerateGUID(false)
	note(player, op, { kind = "join", gang = gangId, at = now() })
	if not ProfileService.SaveNow(player) then
		clearNote(player, op)
		toast(player, "gang_err_try_later")
		return
	end
	local key = tostring(player.UserId)
	local level = p.level
	local editErr, doc = edit(gangId, function(gang)
		if gang.members[key] then
			return "_done"
		end
		if Gangs.memberCount(gang) >= Gangs.slots(gang) then
			return "gang_err_full"
		end
		gang.members[key] = { role = "member", name = player.Name, joinedAt = now(), level = level }
		return nil
	end)
	clearNote(player, op, function(q)
		if editErr == nil then
			q.gang = { id = gangId, leftAt = q.gang and q.gang.leftAt }
		end
	end)
	dropInvite(player.UserId, gangId)
	if editErr or not doc then
		toast(player, editErr or "gang_err_try_later")
		sendInvites(player)
		return
	end
	sendState(player)
	toast(player, "gang_joined", doc.name, doc.tag)
	say(gangId, "gang_announce_join", player.Name)
end

local function leave(player: Player)
	local p, id = cachedGang(player)
	if not p or not id then
		toast(player, "gang_err_no_gang")
		return
	end
	local key = tostring(player.UserId)
	local err = edit(id, function(gang)
		local m = gang.members[key]
		if not m then
			return "_done"
		end
		if m.role == "leader" then
			return "gang_err_leader_leave" -- [клиент gang.error.leader_leave]
		end
		gang.members[key] = nil
		return nil
	end)
	if err and err ~= "gang_err_no_gang" then
		toast(player, err)
		return
	end
	ProfileService.Mutate(player, function(q)
		q.gang = { leftAt = now() } -- [сеть S7] the rejoin cooldown starts
	end)
	sendState(player)
	toast(player, "gang_left")
	if not err then
		say(id, "gang_announce_leave", player.Name)
	end
end

local function memberAction(player: Player, op: string, target: any)
	local _, id = cachedGang(player)
	if not id then
		toast(player, "gang_err_no_gang")
		return
	end
	if typeof(target) ~= "number" or target == player.UserId then
		return
	end
	local me, them = tostring(player.UserId), tostring(target)
	local targetName = ""
	local err = edit(id, function(gang)
		local actor, m = gang.members[me], gang.members[them]
		if not actor then
			return "gang_err_no_gang"
		end
		if not m then
			return "gang_err_player"
		end
		targetName = m.name
		if op == "kick" then
			if not Gangs.canKick(actor.role, m.role) then
				return Gangs.rightsError("kick")
			end
			gang.members[them] = nil
		elseif not Gangs.can(actor.role, op) then
			return Gangs.rightsError(op)
		elseif op == "promote" then
			if m.role ~= "member" then
				return "_done"
			end
			if Gangs.countRole(gang, "deputy") >= cfg.deputiesMax then
				return "gang_err_deputies"
			end
			m.role = "deputy"
		elseif op == "demote" then
			if m.role ~= "deputy" then
				return "_done"
			end
			m.role = "member"
		elseif op == "transfer" then
			if (m.level or 0) < cfg.minLevel then
				return "gang_err_target_level" -- [клиент error.leader_level_too_low]
			end
			m.role = "leader"
			actor.role = "deputy"
			gang.leader = target
		end
		return nil
	end)
	if err then
		toast(player, err)
		return
	end
	if op == "kick" then
		say(id, "gang_announce_kick", targetName)
	else
		local role = if op == "promote"
			then "deputy"
			elseif op == "transfer" then "leader"
			else "member"
		say(id, "gang_role_changed", targetName, { t = "gang_role_" .. role })
	end
end

local function disband(player: Player)
	local _, id, doc = cachedGang(player)
	if not id or not doc then
		toast(player, "gang_err_no_gang")
		return
	end
	local key = tostring(player.UserId)
	local tag = doc.tag
	local err = edit(id, function(gang)
		local m = gang.members[key]
		if not m or m.role ~= "leader" then
			return Gangs.rightsError("disband")
		end
		if gang.treasury > 0 then
			return "gang_err_treasury_not_empty" -- [решение] nobody's money disappears with the gang
		end
		gang.disbanded = true
		gang.members = {}
		return nil
	end)
	if err then
		toast(player, err)
		return
	end
	releaseTag(tag, id)
	ProfileService.Mutate(player, function(q)
		q.gang = { leftAt = q.gang and q.gang.leftAt } -- no cooldown for disbanding [решение]
	end)
	sendState(player)
	toast(player, "gang_disbanded")
end

local function parseDollars(raw: any): number?
	if
		typeof(raw) ~= "number"
		or raw ~= raw
		or raw == math.huge
		or raw < cfg.treasury.minDeposit
	then
		return nil
	end
	return math.floor(raw * Config.moneyScale)
end

local function logEntry(gang: Gang, entry: Gangs.LogEntry)
	table.insert(gang.treasuryLog, entry)
	while #gang.treasuryLog > cfg.treasury.log do
		table.remove(gang.treasuryLog, 1)
	end
end

-- after a failed UpdateAsync: did the op land anyway? (true / false; nil = could not read, the note waits for the load)
local function landed(id: string, op: string): boolean?
	local ok, doc = gangRead(id)
	if not ok then
		return nil
	end
	return doc ~= nil and doc.ops ~= nil and doc.ops[op] ~= nil
end

local function deposit(player: Player, raw: any)
	local p, id, doc = cachedGang(player)
	if not p or not id or not doc then
		toast(player, "gang_err_no_gang")
		return
	end
	local amount = parseDollars(raw)
	if not amount then
		toast(player, "gang_err_min_deposit")
		return
	end
	if p.coins < amount then
		toast(player, "gang_err_money", Strings.money(amount))
		return
	end
	if doc.treasury + amount > Gangs.treasuryCap(doc) then
		toast(player, "gang_err_treasury_full")
		return
	end
	local op = HttpService:GenerateGUID(false)
	if
		not note(player, op, { kind = "deposit", gang = id, amount = amount, at = now() }, amount)
	then
		toast(player, "gang_err_money", Strings.money(amount))
		return
	end
	local err: string? = "gang_err_try_later"
	if ProfileService.SaveNow(player) then
		local key = tostring(player.UserId)
		err = edit(id, function(gang)
			local ops = gang.ops or {}
			gang.ops = ops
			if ops[op] then
				return "_done"
			end
			if not gang.members[key] then
				return "gang_err_no_gang"
			end
			if gang.treasury + amount > Gangs.treasuryCap(gang) then
				return "gang_err_treasury_full"
			end
			gang.treasury += amount
			ops[op] = now()
			logEntry(gang, { at = now(), by = player.Name, kind = "in", amount = amount })
			return nil
		end)
		if err == "gang_err_try_later" then
			local done = landed(id, op)
			if done == nil then
				toast(player, "gang_err_try_later") -- settled on the next load
				return
			end
			err = if done then nil else err
		end
	end
	clearNote(player, op, function(q)
		if err then
			q.coins += amount
		end
	end)
	if err then
		toast(player, err)
		return
	end
	toast(player, "gang_deposited", Strings.money(amount))
end

local function withdraw(player: Player, raw: any)
	local p, id, doc = cachedGang(player)
	if not p or not id or not doc then
		toast(player, "gang_err_no_gang")
		return
	end
	if not Gangs.can(Gangs.roleOf(doc, player.UserId), "withdraw") then
		toast(player, Gangs.rightsError("withdraw"))
		return
	end
	local amount = parseDollars(raw)
	if not amount then
		toast(player, "gang_err_min_deposit")
		return
	end
	if doc.treasury < amount then
		toast(player, "gang_err_treasury_money")
		return
	end
	local op = HttpService:GenerateGUID(false)
	note(player, op, { kind = "withdraw", gang = id, amount = amount, at = now() })
	local err: string? = "gang_err_try_later"
	if ProfileService.SaveNow(player) then
		local key = tostring(player.UserId)
		err = edit(id, function(gang)
			local ops = gang.ops or {}
			gang.ops = ops
			if ops[op] then
				return "_done"
			end
			local m = gang.members[key]
			if not Gangs.can(m and m.role, "withdraw") then
				return Gangs.rightsError("withdraw")
			end
			if gang.treasury < amount then
				return "gang_err_treasury_money"
			end
			gang.treasury -= amount
			ops[op] = now()
			logEntry(gang, { at = now(), by = player.Name, kind = "out", amount = amount })
			return nil
		end)
		if err == "gang_err_try_later" then
			local done = landed(id, op)
			if done == nil then
				toast(player, "gang_err_try_later") -- settled on the next load
				return
			end
			err = if done then nil else err
		end
	end
	clearNote(player, op, function(q)
		if not err then
			q.coins += amount
		end
	end)
	if err then
		toast(player, err)
		return
	end
	toast(player, "gang_withdrew", Strings.money(amount))
end

-- «Прокачки» are bought for $ — from the buyer's own money as in the original, or from the treasury [владелец 28.10:
-- «можно добавить и из казны прокачку»]; «Перки» for gang points. a = upgrade id or { id, pay = "self" | "treasury" }.
-- Own money goes in the deposit steps: note + save, the document records the op, clear the note (refund on a refusal).
local function buyUpgrade(player: Player, a: any)
	local upgradeId, pay = a, nil
	if typeof(a) == "table" then
		upgradeId, pay = a.id, a.pay
	end
	local p, id, doc = cachedGang(player)
	if not p or not id or not doc then
		toast(player, "gang_err_no_gang")
		return
	end
	local u = if typeof(upgradeId) == "string" then Gangs.upgrade(upgradeId) else nil
	if not u then
		return
	end
	local upgrade = u :: Gangs.Upgrade
	if not Gangs.can(Gangs.roleOf(doc, player.UserId), "upgrade") then
		toast(player, Gangs.rightsError("upgrade"))
		return
	end
	local money = upgrade.currency == "money"
	local fromSelf = money and pay ~= "treasury"
	local seenCost = Gangs.nextCost(doc, upgrade.id)
	if not seenCost then
		toast(player, "gang_err_max")
		return
	end
	local price = if money then coins(seenCost) else seenCost
	local op: string? = nil
	if fromSelf then
		if p.coins < price then
			toast(player, "gang_err_money", Strings.money(price))
			return
		end
		local stepId = HttpService:GenerateGUID(false)
		op = stepId
		local entry = { kind = "upgrade", gang = id, amount = price, what = upgrade.id, at = now() }
		if not note(player, stepId, entry, price) then
			toast(player, "gang_err_money", Strings.money(price))
			return
		end
		if not ProfileService.SaveNow(player) then
			clearNote(player, stepId, function(q)
				q.coins += price
			end)
			toast(player, "gang_err_try_later")
			return
		end
	end
	local key = tostring(player.UserId)
	local from = 0
	local err = edit(id, function(gang)
		local ops = gang.ops or {}
		gang.ops = ops
		if op and ops[op] then
			return "_done"
		end
		local m = gang.members[key]
		if not Gangs.can(m and m.role, "upgrade") then
			return Gangs.rightsError("upgrade")
		end
		local cost = Gangs.nextCost(gang, upgrade.id)
		if not cost then
			return "gang_err_max"
		end
		if (if money then coins(cost) else cost) ~= price then
			return "gang_err_price" -- someone bought a level a moment ago: the price moved, nothing is taken
		end
		if not money then
			if gang.points < price then
				return "gang_err_points" -- [клиент gang.error.not_enough_points]
			end
			gang.points -= price
		elseif fromSelf then
			ops[op :: string] = now() -- own money: not a treasury transaction, no history line
		else
			if gang.treasury < price then
				return "gang_err_treasury_money"
			end
			gang.treasury -= price
			logEntry(
				gang,
				{ at = now(), by = player.Name, kind = "buy", amount = price, what = upgrade.id }
			)
		end
		from = Gangs.level(gang, upgrade.id)
		gang.upgrades[upgrade.id] = from + 1
		return nil
	end)
	if op then
		local stepId = op
		if err == "gang_err_try_later" then
			local done = landed(id, stepId)
			if done == nil then
				toast(player, "gang_err_try_later") -- settled on the next load
				return
			end
			err = if done then nil else err
		end
		clearNote(player, stepId, function(q)
			if err then
				q.coins += price
			end
		end)
	end
	if err then
		toast(player, err)
		return
	end
	-- [клиент] «%s повысил «%s» с %s -> %s уровня!»
	say(id, "gang_announce_upgrade", player.Name, { t = "gang_up_" .. upgrade.id }, from, from + 1)
end

local function settings(player: Player, form: any)
	local _, id, doc = cachedGang(player)
	if not id or not doc or typeof(form) ~= "table" then
		return
	end
	if not Gangs.can(Gangs.roleOf(doc, player.UserId), "settings") then
		toast(player, Gangs.rightsError("settings"))
		return
	end
	local desc: string? = nil
	if form.desc ~= nil then
		local checked, err = Gangs.checkDesc(form.desc)
		if not checked then
			toast(player, err :: string)
			return
		end
		desc = filter(checked, player.UserId)
		if not desc then
			toast(player, "gang_err_try_later")
			return
		end
	end
	local key = tostring(player.UserId)
	local err = edit(id, function(gang)
		local m = gang.members[key]
		if not Gangs.can(m and m.role, "settings") then
			return Gangs.rightsError("settings")
		end
		if typeof(form.pvp) == "boolean" then
			gang.pvp = form.pvp
		end
		if typeof(form.color) == "number" and cfg.colors[form.color] then
			gang.color = form.color
		end
		if typeof(form.icon) == "number" and cfg.emblems[form.icon] then
			gang.icon = form.icon
			gang.newIcon = true -- the index is into the new set from now on
		end
		if desc then
			gang.desc = desc
		end
		return nil
	end)
	toast(player, err or "gang_saved")
end

local HANDLERS: { [string]: (Player, any) -> () } = {
	state = function(player)
		local _, id = cachedGang(player)
		if id then
			refreshGang(id)
		end
		sendState(player)
		sendInvites(player)
	end,
	invites = sendInvites,
	create = function(player, a)
		create(player, a)
	end,
	invite = invite,
	accept = function(player, a)
		if typeof(a) == "string" then
			join(player, a)
		end
	end,
	decline = function(player, a)
		if typeof(a) == "string" then
			dropInvite(player.UserId, a)
			sendInvites(player)
		end
	end,
	leave = leave,
	kick = function(player, a)
		memberAction(player, "kick", a)
	end,
	promote = function(player, a)
		memberAction(player, "promote", a)
	end,
	demote = function(player, a)
		memberAction(player, "demote", a)
	end,
	transfer = function(player, a)
		memberAction(player, "transfer", a)
	end,
	disband = disband,
	deposit = deposit,
	withdraw = withdraw,
	upgrade = buyUpgrade,
	settings = settings,
}

local function onAction(player: Player, op: any, a: any)
	local handler = if typeof(op) == "string" then HANDLERS[op] else nil
	if not handler or busy[player] or throttled(player) or not ProfileService.Get(player) then
		return
	end
	if SAVING_OPS[op] then
		if os.clock() - (lastSaving[player] or -math.huge) < SAVING_GAP then
			toast(player, "gang_err_wait")
			return
		end
		lastSaving[player] = os.clock()
	end
	busy[player] = true
	local ok, err = pcall(handler, player, a)
	busy[player] = nil
	if not ok then
		warn("[GangService] " .. tostring(op) .. ": " .. tostring(err))
	end
end

-- ── messages from other servers ────────────────────────────────────────────────────────────────────────────────

local function onMessage(message: any)
	local data = message and message.Data
	if typeof(data) ~= "table" or data.server == game.JobId then
		return
	end
	if data.ev == "refresh" and typeof(data.id) == "string" then
		if cache[data.id] then
			queueRefresh(data.id)
		end
	elseif data.ev == "say" and typeof(data.id) == "string" and typeof(data.key) == "string" then
		for _, player in ipairs(Players:GetPlayers()) do
			if gangIdOf(ProfileService.Get(player)) == data.id then
				toast(
					player,
					data.key,
					table.unpack(if typeof(data.args) == "table" then data.args else {})
				)
			end
		end
	elseif data.ev == "invite" and typeof(data.user) == "number" then
		inviteArrived(data.user, tostring(data.from), tostring(data.name), tostring(data.tag))
	end
end

-- ── start ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function connectStores()
	local ok, stores = pcall(function()
		local g = DataStoreService:GetDataStore(GANG_STORE)
		g:GetAsync("probe") -- fails in Studio without API access
		return { g, DataStoreService:GetDataStore(TAG_STORE) }
	end)
	if ok then
		gangStore, tagStore = stores[1], stores[2]
	elseif RunService:IsStudio() then
		memoryGangs, memoryTags = {}, {}
		warn("[GangService] no DataStore in Studio: gangs live in memory until Play stops")
	else
		warn("[GangService] DataStore unavailable: " .. tostring(stores))
	end
	local okMap, map = pcall(function()
		local m = MemoryStoreService:GetHashMap(INVITE_MAP)
		m:GetAsync("probe")
		return m
	end)
	if okMap and not memoryGangs then
		inviteMap = map
	elseif memoryGangs or RunService:IsStudio() then
		memoryInvites = {}
	else
		warn("[GangService] MemoryStore unavailable: " .. tostring(map))
	end
end

-- QA (Studio): ServerStorage.GangDebug:Invoke(op, …)
--   ("create", userId, tag, name) → gang id (no price / level / cooldown); ("join", userId, gangId) without an invite;
--   ("points", gangId, delta); ("treasury", gangId, dollars); ("upgrade", gangId, upgradeId, level);
--   ("quests", gangId) → opens the quests now; ("progress", userId, kind, amount); ("flush"); ("state", gangId) → JSON
local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "GangDebug"
	local function adminEdit(id: string, change: (Gang) -> ()): boolean
		local err = edit(id, function(gang)
			change(gang)
			return nil
		end)
		return err == nil
	end
	hook.OnInvoke = function(op: string, a: any, b: any, c: any): any
		if op == "create" then
			local player = Players:GetPlayerByUserId(a)
			if not player then
				return nil
			end
			create(player, { tag = b or "QAG", name = c or "QA Gang", desc = "" }, true)
			return gangIdOf(ProfileService.Get(player))
		elseif op == "join" then
			local player = Players:GetPlayerByUserId(a)
			if player then
				join(player, b, true)
			end
			return player ~= nil and gangIdOf(ProfileService.Get(player)) == b
		elseif op == "points" then
			return adminEdit(a, function(gang)
				gang.points = math.max(0, gang.points + (b or 0))
			end)
		elseif op == "treasury" then
			return adminEdit(a, function(gang)
				gang.treasury = math.max(0, gang.treasury + coins(b or 0))
			end)
		elseif op == "upgrade" then
			return adminEdit(a, function(gang)
				gang.upgrades[b] = c
			end)
		elseif op == "quests" then
			return adminEdit(a, function(gang)
				gang.createdAt = math.min(gang.createdAt, now() - cfg.quests.firstAfterHours * 3600)
				Gangs.refreshQuests(gang, now(), rng)
			end)
		elseif op == "progress" then
			local player = Players:GetPlayerByUserId(a)
			GangService.progress(player, b, c)
			local id = player and gangIdOf(ProfileService.Get(player))
			return id ~= nil and pending[id] ~= nil
		elseif op == "flush" then
			for id in pairs(table.clone(pending)) do
				flushGang(id)
			end
			return true
		elseif op == "state" then
			local ok, doc = gangRead(a)
			return if ok and doc then HttpService:JSONEncode(doc) else nil
		end
		return nil
	end
	hook.Parent = ServerStorage
end

function GangService.Start()
	connectStores()
	Remotes.event("GangAction").OnServerEvent:Connect(onAction)
	ProfileService.OnLoaded(function(player)
		task.spawn(onLoaded, player)
	end)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function(character)
			watchHealth(player, character)
		end)
		if player.Character then
			task.spawn(watchHealth, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
		lastAction[player] = nil
		lastSaving[player] = nil
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, onMessage)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(cfg.flushSeconds)
			local ok, err = pcall(tick)
			if not ok then
				warn("[GangService] tick: " .. tostring(err))
			end
		end
	end)
	game:BindToClose(function()
		for id in pairs(table.clone(pending)) do
			pcall(flushGang, id)
		end
	end)
	debugHook()
end

return GangService
