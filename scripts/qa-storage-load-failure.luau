--!nocheck
-- Privileged execute_luau, Server. Actual source with in-memory-only storage/scheduler.
-- No loadstring or changes to real profiles, shared storage, or LoadStringEnabled.
local source = game.ServerScriptService.Server.Services.FactionStorageService.Source
local setup = [==[
local saved = { ["1"] = { ["1"] = { id = "diamond", count = 12 } } }
local warnings, jobs, writes = {}, {}, 0
local store = {}
function store:GetAsync(_key)
	error("QA injected read failure")
end
function store:SetAsync(_key, value)
	writes += 1
	saved = value
end
local config = {
	factions = { list = { { id = "qa_faction" } } },
	faction = function(id)
		return id == "qa_faction"
	end,
}
local shared = { Config = {}, Types = {} }
local services = {
	DataStoreService = {
		GetDataStore = function()
			return store
		end,
	},
	ReplicatedStorage = {
		WaitForChild = function(_, name)
			assert(name == "Shared")
			return shared
		end,
	},
}
local game = {}
function game:GetService(name)
	assert(services[name], "Unexpected service: " .. name)
	return services[name]
end
function game:BindToClose(_callback) end
local function require(module)
 assert(module == shared.Config or module == shared.Types, "Unexpected require")
 return if module == shared.Config then config else {}
end
local function warn(...)
 table.insert(warnings, { ... })
end
local task = {
 spawn = function(fn, ...)
  local args = table.pack(...)
  table.insert(jobs, coroutine.create(function() fn(table.unpack(args,1,args.n)) end))
 end,
 wait = function() coroutine.yield() end,
}
local function runModule()
]==]
local checks = [==[
end
local service = runModule()
local chest = service.Chest("qa_faction", 1)
local exposedEmptyAfterFailure = chest ~= nil and next(chest) == nil
-- Mirrors CaseService's dirty notification after an attempted move.
service.MarkDirty("qa_faction")
service.Start()
local timer
for _, job in jobs do
	assert(coroutine.resume(job))
	if coroutine.status(job) == "suspended" then
		timer = job
	end
end
assert(timer, "Missing save loop")
assert(coroutine.resume(timer))
for _, job in jobs do
	if job ~= timer and coroutine.status(job) == "suspended" then
		assert(coroutine.resume(job))
	end
end
return {
	test = "actual faction module with fake storage",
	readFailureWarned = #warnings == 1,
	exposedEmptyAfterFailure = exposedEmptyAfterFailure,
	writes = writes,
	previousStackLost = saved["1"]["1"] == nil,
	realDataStoresUsed = false,
}
]==]
local isolated = Instance.new("ModuleScript")
isolated.Name = "QAIsolatedFactionStorage"
isolated.Source = setup .. source .. checks
isolated.Parent = game.ServerStorage
local ok, result = pcall(require, isolated)
isolated:Destroy()
assert(ok, result)
return game.HttpService:JSONEncode(result)
