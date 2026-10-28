--!strict
-- Faction, gang and global boosters, shared by every server [вики: «действует на Вашу фракцию / на всех онлайн игроков»;
-- владелец 27.10: «если кто-то активировал бустер для всех, там его ник»]. One MemoryStore sorted-map key holds the
-- list of running and queued shared boosters plus the ids of recent activations (`ops`, kept a day after the end):
-- UpdateAsync appends atomically, so two servers starting boosters at once queue them correctly, and an activation
-- id is never added twice. Every server reads the list every POLL_SECONDS and at once when another server announces
-- a start (MessagingService), and mirrors it into ReplicatedStorage.SharedBoosters (JSON) for Boosters.shared().
local HttpService = game:GetService("HttpService")
local MemoryStoreService = game:GetService("MemoryStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local MAP_NAME = "SharedBoosters_v1"
local KEY = "shared"
local TOPIC = "SharedBoosters"
local POLL_SECONDS = 15
local EXPIRE_SECONDS = 7 * 24 * 3600 -- the key lives a week past the last write
local OP_KEEP_SECONDS = 24 * 3600 -- an activation id is remembered a day past its end (settling pending steps)

type Record = { list: { Boosters.Active }, ops: { [string]: number } }

local GlobalBoosterService = {}
local map: MemoryStoreSortedMap? = nil
local mirror: StringValue

local function prune(record: Record, now: number)
	for i = #record.list, 1, -1 do
		if record.list[i].endsAt <= now then
			table.remove(record.list, i)
		end
	end
	for id, keepUntil in pairs(record.ops) do
		if keepUntil <= now then
			record.ops[id] = nil
		end
	end
end

local function show(list: { Boosters.Active })
	local json = HttpService:JSONEncode(list)
	if mirror.Value ~= json then
		mirror.Value = json
	end
end

local function read(): (boolean, Record?)
	if not map then
		return false, nil
	end
	local ok, record = pcall(function()
		return (map :: MemoryStoreSortedMap):GetAsync(KEY)
	end)
	if not ok then
		return false, nil
	end
	return true, if typeof(record) == "table" then record :: any else nil
end

function GlobalBoosterService.refresh()
	local ok, record = read()
	if ok then
		local list = if record then record.list else {}
		local now = Boosters.now()
		local live = {}
		for _, a in ipairs(list) do
			if a.endsAt > now then
				table.insert(live, a)
			end
		end
		show(live)
	end
end

-- Adds a shared booster (idempotent by entry.id); returns the stored entry, or nil when the store failed.
function GlobalBoosterService.add(entry: Boosters.Active, minutes: number): Boosters.Active?
	if not map then
		return nil
	end
	local result: Boosters.Active? = nil
	local ok = pcall(function()
		(map :: MemoryStoreSortedMap):UpdateAsync(KEY, function(old: any)
			local record: Record = if typeof(old) == "table" then old else { list = {}, ops = {} }
			record.list = record.list or {}
			record.ops = record.ops or {}
			local now = Boosters.now()
			prune(record, now)
			local id = entry.id :: string
			if record.ops[id] then
				for _, a in ipairs(record.list) do
					if a.id == id then
						result = a
					end
				end
				result = result or entry
				return record -- already added by an earlier try
			end
			local startsAt = Boosters.queueStart(
				record.list,
				entry.kind,
				Boosters.scopeOf(entry),
				Boosters.ownerOf(entry),
				now
			)
			local new = table.clone(entry)
			new.startsAt = startsAt
			new.endsAt = startsAt + minutes * 60
			table.insert(record.list, new)
			record.ops[id] = new.endsAt + OP_KEEP_SECONDS
			result = new
			return record
		end, EXPIRE_SECONDS)
	end)
	if not ok or not result then
		return nil
	end
	pcall(function()
		MessagingService:PublishAsync(TOPIC, { entry = result })
	end)
	GlobalBoosterService.refresh()
	return result
end

-- true / false = whether the activation id was added; nil = the store could not be read (try again later)
function GlobalBoosterService.hasOp(id: string): boolean?
	local ok, record = read()
	if not ok then
		return nil
	end
	return record ~= nil and record.ops ~= nil and record.ops[id] ~= nil
end

-- «<ник> запустил Глобальный бустер денег x1.1 на 30 минут!» to the players it boosts on this server
local function announce(a: Boosters.Active)
	local scope = Boosters.scopeOf(a)
	local minutes = math.floor((a.endsAt - a.startsAt) / 60 + 0.5)
	for _, player in ipairs(Players:GetPlayers()) do
		local p = ProfileService.Get(player)
		if
			p
			and (
				scope == "global"
				or (scope == "faction" and p.faction == a.faction)
				or (scope == "gang" and p.gang ~= nil and p.gang.id == a.gang)
			)
		then
			local locale = Strings.localeOf(player)
			Remotes.event("Toast"):FireClient(
				player,
				Strings.t(
					"booster_started_by",
					locale,
					a.by or "?",
					Strings.boosterName(a.kind, scope, locale),
					tostring(a.mult),
					minutes
				)
			)
		end
	end
end

function GlobalBoosterService.Start()
	mirror = Instance.new("StringValue")
	mirror.Name = Boosters.SHARED_VALUE
	mirror.Value = "[]"
	mirror.Parent = ReplicatedStorage
	local ok, result = pcall(function()
		return MemoryStoreService:GetSortedMap(MAP_NAME)
	end)
	if ok then
		map = result
	else
		warn("[GlobalBoosterService] MemoryStore unavailable: " .. tostring(result))
	end
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(TOPIC, function(message)
				local data = message.Data
				if typeof(data) == "table" and typeof(data.entry) == "table" then
					announce(data.entry)
				end
				GlobalBoosterService.refresh()
			end)
		end)
	end)
	task.spawn(function()
		while true do
			GlobalBoosterService.refresh()
			task.wait(POLL_SECONDS)
		end
	end)
end

return GlobalBoosterService
