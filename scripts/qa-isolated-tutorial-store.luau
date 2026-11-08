--!nocheck
-- Installed ONLY in an explicitly marked disposable local QA DataModel, never in src/.
-- The real profile/mailbox transaction code runs over session memory. No cloud persistence claim.
assert(game.RunService:IsStudio() and game.PlaceId == 0 and game.GameId == 0, "Local QA only")
assert(game.StudioTestService:GetTestArgs() == "release-tutorial-v1", "Tutorial STS only")
local marker = game.ServerStorage:FindFirstChild("QAIsolatedTutorial")
assert(
	marker and marker:GetAttribute("Mode") == "DISPOSABLE_LOCAL_TUTORIAL",
	"Missing isolated QA marker"
)
assert(
	marker:GetAttribute("BackupSHA256")
		== "da82e4c0a83933c0b074cafac50b447ecf73ea115fbb04739377373ecd8ca4a0",
	"Unexpected QA backup"
)
local Scope = require(game.ServerScriptService.Server.Services.TestSessionScope)
local Names = require(game.ReplicatedStorage.Shared.StorageNames)
local expectedScope = assert(Scope.Get(), "No isolated test scope")
assert(typeof(expectedScope) == "string" and expectedScope:match("^Run_"), "Invalid test scope")
local stores, writes, reads, rejected = {}, 0, 0, 0
local function copy(value, seen)
	local kind = typeof(value)
	assert(
		kind == "nil"
			or kind == "table"
			or kind == "number"
			or kind == "string"
			or kind == "boolean",
		"Unsupported stored type"
	)
	if kind == "number" then
		assert(value == value and math.abs(value) < math.huge, "Non-finite stored number")
	end
	if kind ~= "table" then
		return value
	end
	seen = seen or {}
	assert(not seen[value], "Cyclic stored table")
	seen[value] = true
	local result = {}
	for key, child in value do
		assert(typeof(key) == "string" or typeof(key) == "number", "Unsupported stored key")
		result[key] = copy(child, seen)
	end
	seen[value] = nil
	return result
end
local function keyAllowed(name, scope, key)
	local prefix = if name == Names.progress("PlayerProfiles_v3_QA")
		then "User_"
		elseif name == Names.progress("PlayerTransfers_QA_v1") then "Inbox_"
		else nil
	local valid = scope == expectedScope
		and prefix
		and typeof(key) == "string"
		and key:match("^" .. prefix .. "%-%d+$") ~= nil
	local id = if valid then tonumber(key:sub(#prefix + 1)) else nil
	valid = valid and id ~= nil and id < 0 and id > -math.huge
	if not valid then
		rejected += 1
	end
	assert(valid, "Refuse unscoped or nonnegative account storage")
end
local Adapter = {}
function Adapter:GetDataStore(name, scope)
	assert(
		name == Names.progress("PlayerProfiles_v3")
			or name == Names.progress("PlayerProfiles_v3_QA")
			or name == Names.progress("PlayerTransfers_v1")
			or name == Names.progress("PlayerTransfers_QA_v1"),
		"Unexpected QA store"
	)
	local id = name .. ":" .. tostring(scope)
	if stores[id] then
		return stores[id]
	end
	local records, store = {}, {}
	function store:GetAsync(key)
		keyAllowed(name, scope, key)
		reads += 1
		return copy(records[key])
	end
	function store:UpdateAsync(key, transform)
		keyAllowed(name, scope, key)
		reads += 1
		local result = transform(copy(records[key]))
		if result ~= nil then
			records[key] = copy(result)
			writes += 1
		end
		return copy(records[key])
	end
	stores[id] = store
	return store
end
function Adapter.Evidence()
	return {
		mode = "SESSION_MEMORY",
		scope = expectedScope,
		reads = reads,
		writes = writes,
		rejected = rejected,
		cloudPersistenceTested = false,
	}
end
return Adapter
