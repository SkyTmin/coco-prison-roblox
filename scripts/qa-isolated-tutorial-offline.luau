--!nocheck
-- Guarded local installer/runner and memory-store adapter; no Studio or real account access.
local fs, rb, serde, process =
	require("@lune/fs"), require("@lune/roblox"), require("@lune/serde"), require("@lune/process")
local generated = process.exec("node", { "scripts/make-isolated-tutorial-qa.mjs" })
assert(generated.ok, generated.stderr)
local installer = generated.stdout
local currentSync = process.exec("node", { "scripts/make-studio-sync.mjs" })
assert(currentSync.ok, currentSync.stderr)
local _, expectedSourceScripts = currentSync.stdout:gsub("do local s = at%(", "")
local refreshGenerated =
	process.exec("node", { "scripts/make-isolated-tutorial-qa.mjs", "--harness-only" })
assert(refreshGenerated.ok, refreshGenerated.stderr)
local refresh = refreshGenerated.stdout
local runner = fs.readFile("scripts/run-isolated-tutorial-qa.luau")
local adapterSource = fs.readFile("scripts/qa-isolated-tutorial-store.luau")
local manifest =
	serde.decode("json", fs.readFile("place/recovery-2026-11-03/version-428/manifest.json"))
local names = { Prison = true }
for _, root in manifest.roots do
	names[root.name] = true
end
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function fixture(options)
	options = options or {}
	local model = rb.Instance.new("DataModel")
	local ws, storage = model:GetService("Workspace"), model:GetService("ServerStorage")
	for name in names do
		local root, part = rb.Instance.new("Folder"), rb.Instance.new("Part")
		root.Name, root.Parent = name, ws
		part.Name, part.Parent = "Geometry", root
	end
	local anchor, spawn = rb.Instance.new("Part"), rb.Instance.new("SpawnLocation")
	anchor.Name, anchor.Parent = "MineAnchor_prison", ws.Prison
	spawn.Name, spawn.Parent = "Spawn", ws.Prison
	local sps = rb.Instance.new("StarterPlayerScripts")
	sps.Parent = model:GetService("StarterPlayer")
	local debugDraw = rb.Instance.new("WireframeHandleAdornment")
	debugDraw.Name, debugDraw.Parent = "DebugDraw", ws
	local state = { stsCalls = 0 }
	local game = {
		Name = options.name or "Katorga-Tutorial-QA-2026-11-03.rbxl",
		PlaceId = options.placeId or 0,
		GameId = options.gameId or 0,
		RunService = {
			IsStudio = function()
				return options.studio ~= false
			end,
			IsRunning = function()
				return options.running == true
			end,
		},
		Players = {
			GetPlayers = function()
				return if options.occupied then { { UserId = 1 } } else {}
			end,
		},
		HttpService = {
			JSONDecode = function(_, text)
				return serde.decode("json", text)
			end,
			JSONEncode = function(_, value)
				return serde.encode("json", value)
			end,
		},
		StudioTestService = {
			GetTestArgs = function()
				return options.testArgs or "release-tutorial-v1"
			end,
			ExecuteMultiplayerTestAsync = function(_, count, args)
				state.stsCalls += 1
				state.players, state.args = count, args
				if options.stsError then
					error("synthetic STS failure")
				end
				return serde.encode("json", options.result or {
					status = "PASS",
					storageMode = "SESSION_MEMORY",
					cloudPersistenceTested = false,
					storageEvidence = { mode = "SESSION_MEMORY" },
				})
			end,
		},
	}
	setmetatable(game, {
		__index = function(_, name)
			return model:GetService(name)
		end,
	})
	game.GetService = function(_, name)
		return game[name]
	end
	local env = {
		game = game,
		workspace = ws,
		Instance = rb.Instance,
		task = {
			wait = function() end,
			spawn = function(fn)
				fn()
			end,
		},
		print = function() end,
		require = function(key)
			if key.Name == "StorageNames" then
				local fn = assert(loadstring(fs.readFile("src/shared/StorageNames.luau")))
				setfenv(fn, setmetatable({ game = game }, { __index = getfenv() }))
				return fn()
			end
			assert(key.Name == "TestSessionScope", "Unexpected adapter dependency")
			return {
				Get = function()
					return options.scope or "Run_fixture"
				end,
			}
		end,
	}
	setmetatable(env, { __index = getfenv() })
	env.loadstring = function(source)
		local fn, err = loadstring(source)
		if fn then
			setfenv(fn, env)
		end
		return fn, err
	end
	return { model = model, ws = ws, storage = storage, env = env, state = state, options = options }
end
local function run(source, f)
	return pcall(assert(f.env.loadstring(source)))
end
check("generated installer compiles", loadstring(installer) ~= nil)
check("server-only refresh compiles", loadstring(refresh) ~= nil)
check("isolated runner compiles", loadstring(runner) ~= nil)
check("session-memory adapter compiles", loadstring(adapterSource) ~= nil)
for _, options in
	{
		{ placeId = 92594200898716 },
		{ gameId = 10772144679 },
		{ name = "Game" },
		{ name = "Katorga-Tutorial-QA-2026-11-03" },
		{ studio = false },
		{ running = true },
		{ occupied = true },
	}
do
	local f = fixture(options)
	local before = #f.model:GetDescendants()
	check("installer refuses wrong document/context", not run(installer, f))
	check("refused installer leaves every instance intact", #f.model:GetDescendants() == before)
	check("runner refuses wrong document/context", not run(runner, f))
	check("server-only refresh refuses wrong document/context", not run(refresh, f))
end
do
	local f = fixture()
	f.ws.Quarry:Destroy()
	local before = #f.model:GetDescendants()
	check("installer rejects incomplete local backup", not run(installer, f))
	check("incomplete backup is not modified", #f.model:GetDescendants() == before)
end
local f = fixture()
local beforePrison = #f.ws.Prison:GetDescendants()
local ok, result = run(installer, f)
check("installer completes in exact disposable local document", ok and result.status == "READY")
check(
	"only other29scenery roots are removed",
	result.removedRoots == 29 and #f.ws:GetChildren() == 1
)
check("real fixture Prison is retained unchanged", #f.ws.Prison:GetDescendants() == beforePrison)
check(
	"backup debug adornment is removed only from disposable copy",
	not f.ws:FindFirstChild("DebugDraw")
		and serde.decode("json", f.storage.QAIsolatedTutorial.Value).removedDebugDraw == true
)
check("all latest source scripts are synchronized", result.sourceScripts == expectedSourceScripts)
check("installer never creates a restore lease", not f.storage:FindFirstChild("QAReleaseMapLease"))
local marker = f.storage.QAIsolatedTutorial
check(
	"marker truthfully records fixture/storage limitations",
	marker:GetAttribute("State") == "READY"
		and serde.decode("json", marker.Value).cloudPersistenceTested == false
)
for _, name in { "ProfileService", "PlayerTransferService" } do
	local source = f.model:GetService("ServerScriptService").Server.Services[name].Source
	local original = fs.readFile("src/server/Services/" .. name .. ".luau")
	local restored, count = source:gsub(
		"local DataStoreService = require%(game.ServerStorage.QAIsolatedTutorialStore%)",
		'local DataStoreService = game:GetService("DataStoreService")'
	)
	check(name .. " differs only at the storage dependency", count == 1 and restored == original)
end
local liveServer = f.model:GetService("ServerScriptService").QAReleaseTutorialServer.Source
local liveClient =
	f.model:GetService("StarterPlayer").StarterPlayerScripts.QAReleaseTutorialClient.Source
check(
	"local harness scripts compile",
	loadstring(liveServer) ~= nil and loadstring(liveClient) ~= nil
)
check(
	"local client harness is unchanged",
	liveClient == fs.readFile("scripts/qa-release-tutorial-client.luau")
)
check(
	"local server cannot claim cloud persistence",
	liveServer:find('storageMode = "SESSION_MEMORY"', 1, true)
		and liveServer:find("cloudPersistenceTested = false", 1, true)
		and not liveServer:find('check("completed guide saved in isolated test scope"', 1, true)
)
check("second installer run is refused", not run(installer, f))
do
	local serverScript = f.model:GetService("ServerScriptService").QAReleaseTutorialServer
	serverScript.Source = "-- stale test harness fixture"
	local originals = {}
	for _, instance in f.model:GetDescendants() do
		if instance:IsA("LuaSourceContainer") then
			originals[instance] = instance.Source
		end
	end
	local count = #f.model:GetDescendants()
	local ok, result = run(refresh, f)
	check(
		"server-only refresh accepts prepared exact local document",
		ok and result.status == "HARNESS_REFRESHED"
	)
	local changed = 0
	for instance, source in originals do
		if instance.Source ~= source then
			changed += 1
			assert(instance == serverScript, "Refresh touched another script")
		end
	end
	check(
		"refresh changes exactly the temporary server script",
		changed == 1 and serverScript.Source == liveServer
	)
	check(
		"refresh never prunes map or reinstalls instances",
		#f.model:GetDescendants() == count
			and #f.ws.Prison:GetDescendants() == beforePrison
			and result.mapPruned == false
	)
	check(
		"refreshed server keeps both session-memory report substitutions",
		serverScript.Source:find('storageMode = "SESSION_MEMORY"', 1, true)
			and serverScript.Source:find("report.storageEvidence =", 1, true)
	)
	local hash = marker:GetAttribute("SourceSHA256")
	marker:SetAttribute("SourceSHA256", "another-gameplay-version")
	check("refresh refuses another gameplay source snapshot", not run(refresh, f))
	marker:SetAttribute("SourceSHA256", hash)
end
local adapterOk, adapter = run(adapterSource, f)
check("adapter loads only inside marked local tutorial fixture", adapterOk)
local storageNames = assert(f.env.loadstring(fs.readFile("src/shared/StorageNames.luau")))()
local store = adapter:GetDataStore(storageNames.progress("PlayerProfiles_v3_QA"), "Run_fixture")
check("fresh negative actor has no stored progress", store:GetAsync("User_-1") == nil)
store:UpdateAsync("User_-1", function(old)
	assert(old == nil)
	return { level = 1, inventory = { ["1"] = { id = "shovel", count = 1 } } }
end)
local read = store:GetAsync("User_-1")
read.inventory["1"].count = 99
check(
	"memory reads do not mutate stored records",
	store:GetAsync("User_-1").inventory["1"].count == 1
)
store:UpdateAsync("User_-1", function(old)
	old.level = 999
	return nil
end)
check("nil transform cancels without mutating stored record", store:GetAsync("User_-1").level == 1)
local failed = pcall(function()
	store:UpdateAsync("User_-1", function(old)
		old.level = 999
		error("fail")
	end)
end)
check(
	"throwing transform leaves previous checkpoint intact",
	not failed and store:GetAsync("User_-1").level == 1
)
for _, key in { "User_1", "User_0", "User_-0", "User_-", "User_-1_extra", "Inbox_-1" } do
	check("adapter refuses key " .. key, not pcall(function()
		store:UpdateAsync(key, function()
			return {}
		end)
	end))
end
check("adapter refuses a different session scope", not pcall(function()
	adapter
		:GetDataStore(storageNames.progress("PlayerProfiles_v3_QA"), "Run_other")
		:GetAsync("User_-1")
end))
check("production handle cannot read/write a profile", not pcall(function()
	adapter:GetDataStore(storageNames.progress("PlayerProfiles_v3")):GetAsync("User_-1")
end))
local mailbox = adapter:GetDataStore(storageNames.progress("PlayerTransfers_QA_v1"), "Run_fixture")
mailbox:UpdateAsync("Inbox_-1", function()
	return { packets = {} }
end)
check(
	"bootstrap mailbox also uses negative scoped memory",
	typeof(mailbox:GetAsync("Inbox_-1")) == "table"
)
check(
	"adapter makes its persistence limit explicit",
	adapter.Evidence().cloudPersistenceTested == false and adapter.Evidence().writes == 2
)
local runOk = run(runner, f)
local report = serde.decode("json", f.storage.QAIsolatedTutorialResult.Value)
check(
	"local coordinator invokes one scoped fresh STS actor",
	runOk
		and f.state.stsCalls == 1
		and f.state.players == 1
		and f.state.args == "release-tutorial-v1"
)
check(
	"coordinator retains complete memory-fixture evidence",
	report.status == "PASS"
		and report.storageMode == "SESSION_MEMORY"
		and not report.cloudPersistenceTested
		and not report.physicalPhoneTested
)
f.options.result = { status = "PASS" }
run(runner, f)
check(
	"coordinator refuses PASS without memory-fixture evidence",
	serde.decode("json", f.storage.QAIsolatedTutorialResult.Value).status == "FAIL"
)
f.options.stsError = true
run(runner, f)
check(
	"coordinator preserves STS failure",
	serde.decode("json", f.storage.QAIsolatedTutorialResult.Value).status == "FAIL"
)
f.storage.QAIsolatedTutorialResult.Value = "running"
check("coordinator blocks another test over unfinished run", not run(runner, f))
check(
	"native backup remains byte-identical",
	serde.hash(
		"sha256",
		fs.readFile("place/recovery-2026-11-03/version-428/katorga-full-version-428.rbxl")
	) == "da82e4c0a83933c0b074cafac50b447ecf73ea115fbb04739377373ecd8ca4a0"
)
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	studioAccessed = false,
	cloudPersistenceTested = false,
	actualNewbieRouteTested = false,
}))
