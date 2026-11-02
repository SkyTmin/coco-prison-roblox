--!nocheck
-- Privileged Studio Server: actual shared-storage source, fake DataStore only.
-- Verifies fail-closed reads and recovery without any real key or profile mutation.
local source = game.ServerScriptService.Server.Services.SharedStorageService.Source
local setup = [==[
local realPersistence = require(game.ReplicatedStorage.Shared.Persistence)
local realRecord = require(game.ServerScriptService.Server.Services.SharedStorageRecord)
local saved = { ["1"] = { ["1"] = { id = "diamond", count = 12 } } }
local reads, writes = 0, 0
local store = {}
function store:GetAsync(_id)
 reads += 1
 if reads == 1 then error("QA injected read failure") end
 return realPersistence.copy(saved)
end
function store:UpdateAsync(_id, _fn)
 writes += 1
 error("No writes are permitted in this read-recovery fixture")
end
local persistenceToken, recordToken = {}, {}
local services = {
 DataStoreService = { GetDataStore = function() return store end },
 ReplicatedStorage = { Shared = { Persistence = persistenceToken } },
}
local game = { GetService = function(_, name) return assert(services[name]) end }
local script = { Parent = { SharedStorageRecord = recordToken } }
local function require(module)
 if module == persistenceToken then return realPersistence end
 assert(module == recordToken)
 return realRecord
end
local function warn(...) end
local function module()
]==]
local checks = [==[
end
local storage = module()
local first = storage.Snapshot("faction", "qa_faction", 1)
local recovered, revision = storage.Snapshot("faction", "qa_faction", 1)
assert(first == nil, "Failed read must not expose writable empty slots")
assert(recovered[1].id == "diamond" and recovered[1].count == 12, "Retry preserves seed")
assert(writes == 0 and reads == 2 and revision == 0)
return { status = "PASS", checks = 4, failedReadClosed = true, recoveredCount = recovered[1].count, writes = writes, realDataStoresUsed = false }
]==]
local isolated = Instance.new("ModuleScript")
isolated.Name = "QAIsolatedSharedReadFailure"
isolated.Source = setup .. source .. checks
isolated.Parent = game.ServerStorage
local ok, result = pcall(require, isolated)
isolated:Destroy()
assert(ok, result)
return game.HttpService:JSONEncode(result)
