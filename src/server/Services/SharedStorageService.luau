--!strict
-- Both shared stores use atomic page revisions, never delayed whole-cache saves.
-- Existing keys/formats are migrated in place on the first committed operation.
local DataStoreService = game:GetService("DataStoreService")
local Persistence = require(game:GetService("ReplicatedStorage").Shared.Persistence)
local Record = require(script.Parent.SharedStorageRecord)
local Storage = {}
local stores: { [string]: DataStore } = {}
local cache: { [string]: any } = {}
local READ_GAP = 4

local function storeFor(kind: string): DataStore
	assert(kind == "gang" or kind == "faction", "Unknown shared storage")
	if not stores[kind] then
		stores[kind] = DataStoreService:GetDataStore(
			if kind == "gang" then "GangChest_v1" else "FactionStorage_v1"
		)
	end
	return stores[kind]
end

local function cacheKey(kind: string, id: string): string
	return kind .. ":" .. id
end

function Storage.Read(kind: string, id: string, fresh: boolean?): any
	local key = cacheKey(kind, id)
	local saved = cache[key]
	if not fresh and saved and os.clock() - saved.at < READ_GAP then
		return saved.record
	end
	local ok, raw = pcall(function()
		return storeFor(kind):GetAsync(id)
	end)
	if not ok or not Persistence.finiteTree(raw) then
		cache[key] = nil -- fail closed; an absent record is different from an unreadable one
		warn("[SharedStorage] read unavailable: " .. key)
		return nil
	end
	local record = Record.decode(raw, kind == "faction")
	cache[key] = { record = record, at = os.clock() }
	return record
end

function Storage.Snapshot(kind: string, id: string, page: number): (any, number?)
	local record = Storage.Read(kind, id)
	if not record then
		return nil, nil
	end
	return Record.slots(record, page), record.revisions[tostring(page)] or 0
end

function Storage.Commit(kind: string, id: string, operation: any): boolean?
	local committed: boolean? = nil
	local ok, saved = pcall(function()
		return storeFor(kind):UpdateAsync(id, function(raw: any)
			if not Persistence.finiteTree(raw) then
				return nil
			end
			local record = Record.decode(raw, kind == "faction")
			local nextRecord, outcome = Record.apply(record, operation)
			committed = outcome
			return nextRecord
		end)
	end)
	if not ok or saved == nil then
		return nil -- write outcome unknown: keep the profile's escrow and retry its exact id
	end
	cache[cacheKey(kind, id)] = { record = saved, at = os.clock() }
	return committed
end

-- Only after the delivered profile has been durably confirmed. Its page revision still
-- prevents any delayed original transform from applying again after receipt cleanup.
function Storage.Acknowledge(kind: string, id: string, operationId: string)
	pcall(function()
		storeFor(kind):UpdateAsync(id, function(raw: any)
			local record = Record.decode(raw, kind == "faction")
			if not record.receipts[operationId] then
				return nil
			end
			record.receipts[operationId] = nil
			return record
		end)
	end)
end

return Storage
