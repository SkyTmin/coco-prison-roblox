--!strict
-- The gang storage «склад» on the База банды [вики HANDBOOK-WIKI: «Здесь склад…»; docs/research/remaining-features-
-- design.md §1.5]. One storage per gang, shared by every member on every server: Config.gangs.base.chest.slotsPerLevel
-- (54: a double chest [сеть S7: «до 32 уровня = 32 двойных сундука»]) slots per level of «Сундуки», shown as pages of
-- 27 in the chest window. The slots live in the DataStore GangChest_v1 (key = gang id; only filled pages and slots are
-- written: 32 × 54 full slots stay far under the 4 MB value limit). Anti-dupe [решение]: only ONE server may have a gang's storage open — a
-- MemoryStore lock (hash map GangChestLock_v1, key = gang id, value = this JobId) taken for lockSeconds and renewed
-- every renewSeconds while anyone here has it open; another server refuses with «склад открыт на другом сервере».
-- The slots are read fresh when the lock is taken, written (UpdateAsync) at most every saveGapSeconds after a change,
-- and written once more before the lock is let go (no viewers for IDLE_SECONDS) or the server closes. A lock this
-- server could not renew in time makes `valid` false: CaseService closes the windows, the slots are saved and dropped.
-- CaseService opens the chest (tag GangChest) and moves the items; this module only keeps the slots and the lock.
-- Studio without API access: slots in memory, no lock.
local DataStoreService = game:GetService("DataStoreService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Types = require(Shared.Types)

type Slots = { [number]: Types.ItemStack }
type Chest = {
	pages: { [number]: Slots },
	dirty: boolean,
	savedAt: number,
	lockedAt: number, -- os.clock() of the last confirmed lock write
	idleSince: number?,
}

local STORE = "GangChest_v1"
local LOCK_MAP = "GangChestLock_v1"
local SLOTS = 27
local IDLE_SECONDS = 10 -- [решение] the lock is let go this long after the last viewer closed
local cfg = Config.gangs.base.chest

local GangChestService = {}
GangChestService.SLOTS = SLOTS
-- [сеть S7] a level of «Сундуки» is a double chest of 54 slots = two pages of 27 in the window; 32 levels = 64 pages
GangChestService.PAGES_PER_LEVEL = math.max(1, math.floor(cfg.slotsPerLevel / SLOTS))
GangChestService.MAX_PAGES = ((Gangs.upgrade("chests") :: any).max :: number)
	* GangChestService.PAGES_PER_LEVEL

local chests: { [string]: Chest } = {}
local acquiring: { [string]: boolean } = {}
local store: DataStore? = nil
local lockMap: MemoryStoreHashMap? = nil
local memory: { [string]: any }? = nil -- Studio without API access
local viewersOf: (string) -> number = function(_id: string): number
	return 0
end
local started = false

local function validStack(stack: any): boolean
	return typeof(stack) == "table"
		and typeof(stack.id) == "string"
		and typeof(stack.count) == "number"
		and stack.count >= 1
		and stack.count == math.floor(stack.count)
end

local function decode(saved: any): { [number]: Slots }
	local pages: { [number]: Slots } = {}
	-- Keep old pages intact when reducing the purchase cap (withdraw-only below).
	for i = 1, math.max(64, GangChestService.MAX_PAGES) do
		pages[i] = {}
	end
	if typeof(saved) ~= "table" or typeof(saved.pages) ~= "table" then
		return pages
	end
	for rawPage, slots in pairs(saved.pages) do
		local page = tonumber(rawPage)
		if page and pages[page] and typeof(slots) == "table" then
			for rawSlot, stack in pairs(slots) do
				local slot = tonumber(rawSlot)
				if
					slot
					and slot >= 1
					and slot <= SLOTS
					and slot == math.floor(slot)
					and validStack(stack)
				then
					pages[page][slot] = stack
				end
			end
		end
	end
	return pages
end

local function encode(pages: { [number]: Slots }): any
	local out = {}
	for page, slots in pairs(pages) do
		local encoded = {}
		local any = false
		for slot, stack in pairs(slots) do
			encoded[tostring(slot)] = stack
			any = true
		end
		if any then
			out[tostring(page)] = encoded
		end
	end
	return { pages = out, at = os.time() }
end

-- the lock: free, expired or ours → ours for lockSeconds; held by another server → refused
local function lock(id: string): boolean
	if memory then
		return true
	end
	local map = lockMap
	if not map then
		return false
	end
	local ok, result = pcall(function()
		return map:UpdateAsync(id, function(old: any)
			if
				typeof(old) == "table"
				and old.job ~= game.JobId
				and (old.untilAt or 0) > os.time()
			then
				return nil -- another server has it open
			end
			return { job = game.JobId, untilAt = os.time() + cfg.lockSeconds }
		end, cfg.lockSeconds)
	end)
	return ok and typeof(result) == "table" and result.job == game.JobId
end

local function unlock(id: string)
	local map = lockMap
	if memory or not map then
		return
	end
	pcall(function()
		map:UpdateAsync(id, function(old: any)
			if typeof(old) == "table" and old.job == game.JobId then
				return { job = "", untilAt = 0 } -- free (a RemoveAsync could delete another server's fresh lock)
			end
			return nil
		end, 5)
	end)
end

local function save(id: string, chest: Chest): boolean
	chest.savedAt = os.clock()
	if memory then
		memory[id] = encode(chest.pages)
		chest.dirty = false
		return true
	end
	local s = store
	if not s then
		return false
	end
	local data = encode(chest.pages)
	chest.dirty = false
	local ok, err = pcall(function()
		s:UpdateAsync(id, function()
			return data
		end)
	end)
	if not ok then
		chest.dirty = true -- try again on the next round
		warn("[GangChest] save failed " .. id .. ": " .. tostring(err))
	end
	return ok
end

-- Opens a gang's storage on this server (yields: the lock and the read). Returns nil and the refusal key.
function GangChestService.Open(id: string): (boolean, string?)
	while acquiring[id] do
		task.wait()
	end
	local chest = chests[id]
	if chest then
		chest.idleSince = nil
		return true, nil
	end
	if not memory and (not store or not lockMap) then
		return false, "gang_chest_unavailable"
	end
	acquiring[id] = true
	local function finish(ok: boolean, key: string?): (boolean, string?)
		acquiring[id] = nil
		return ok, key
	end
	if not lock(id) then
		return finish(false, "gang_chest_busy")
	end
	local saved: any = nil
	if memory then
		saved = memory[id]
	else
		local s = store :: DataStore
		local ok, value = pcall(function()
			return s:GetAsync(id)
		end)
		if not ok then
			unlock(id)
			warn("[GangChest] load failed " .. id .. ": " .. tostring(value))
			return finish(false, "gang_chest_unavailable")
		end
		saved = value
	end
	chests[id] = {
		pages = decode(saved),
		dirty = false,
		savedAt = os.clock(),
		lockedAt = os.clock(),
		idleSince = nil,
	}
	return finish(true, nil)
end

-- the live slots of one page (change them, then MarkDirty); nil when the storage is not open here
function GangChestService.Page(id: string?, page: any): Slots?
	local chest = id and chests[id]
	if not chest or typeof(page) ~= "number" then
		return nil
	end
	return chest.pages[page]
end

-- pages a gang has: two per level of «Сундуки»; level 0 (a new gang) = none [владелец 28.10]
function GangChestService.PageCount(gang: any): number
	if not gang then
		return 0
	end
	local count = math.clamp(
		Gangs.level(gang, "chests") * GangChestService.PAGES_PER_LEVEL,
		0,
		GangChestService.MAX_PAGES
	)
	local chest = chests[gang.id]
	if chest then
		for page, slots in pairs(chest.pages) do
			if next(slots) ~= nil then
				count = math.max(count, page)
			end
		end
	end
	return count
end

function GangChestService.MarkDirty(id: string)
	local chest = chests[id]
	if chest then
		chest.dirty = true
	end
end

-- false once this server can no longer be sure it holds the lock (the windows must close)
function GangChestService.Valid(id: string?): boolean
	local chest = id and chests[id]
	return chest ~= nil and (memory ~= nil or os.clock() - chest.lockedAt < cfg.lockSeconds - 10)
end

-- CaseService tells how many players here have a gang's storage open
function GangChestService.SetViewerCounter(fn: (string) -> number)
	viewersOf = fn
end

local function tick()
	local now = os.clock()
	for id, chest in pairs(chests) do
		local viewers = viewersOf(id)
		if chest.dirty and now - chest.savedAt >= cfg.saveGapSeconds then
			save(id, chest)
		end
		if viewers > 0 then
			chest.idleSince = nil
			if now - chest.lockedAt >= cfg.renewSeconds then
				if lock(id) then
					chest.lockedAt = now
				end
			end
		else
			chest.idleSince = chest.idleSince or now
		end
		local lost = not GangChestService.Valid(id)
		if (chest.idleSince and now - chest.idleSince >= IDLE_SECONDS) or lost then
			-- let go only after the last write went through (a failed write keeps the slots and tries again)
			if (not chest.dirty or save(id, chest)) and viewers == 0 then
				chests[id] = nil
				unlock(id)
			end
		end
	end
end

local function connect()
	local ok, s = pcall(function()
		local ds = DataStoreService:GetDataStore(STORE)
		ds:GetAsync("probe") -- fails in Studio without API access
		return ds
	end)
	if ok then
		store = s
		local okMap, map = pcall(function()
			local m = MemoryStoreService:GetHashMap(LOCK_MAP)
			m:GetAsync("probe")
			return m
		end)
		if okMap then
			lockMap = map
		else
			warn("[GangChest] MemoryStore unavailable, the storage stays closed: " .. tostring(map))
		end
	elseif RunService:IsStudio() then
		memory = {}
		warn("[GangChest] no DataStore in Studio: gang storages live in memory until Play stops")
	else
		warn("[GangChest] DataStore unavailable: " .. tostring(s))
	end
end

function GangChestService.Start()
	if started then
		return
	end
	started = true
	connect()
	task.spawn(function()
		while true do
			task.wait(2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[GangChest] tick: " .. tostring(err))
			end
		end
	end)
	game:BindToClose(function()
		for id, chest in pairs(chests) do
			if chest.dirty then
				save(id, chest)
			end
			unlock(id)
		end
	end)
end

return GangChestService
