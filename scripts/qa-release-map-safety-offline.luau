--!nocheck
-- Actual helper sources with synthetic Roblox instances; no Studio/cloud map access.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local preflightSource = fs.readFile("scripts/qa-release-full-map-preflight.luau")
local legacySource = fs.readFile("scripts/qa-release-scene-session.luau")
local checks = {}
local function check(name, condition)
	assert(condition, name)
	table.insert(checks, name)
end
local expected = {
	"Prison",
	"InsideOut",
	"Barn",
	"Quarry",
	"EdgeGate",
	"Tree",
	"Church",
	"Purgatory",
	"Eden",
	"Cherubim",
	"Gate",
	"Basement",
	"Warzone",
	"Ghetto",
	"Showcase",
	"FactionBase",
	"Paradise",
	"SunkenLighthouse",
	"RoyalGarden",
	"Pyramid",
	"Underworld",
	"MountainFoot",
	"EndCastle",
	"SnowyHand",
	"SpiderLair",
	"Market",
	"LeprechaunValley",
	"Castle",
	"Farm",
	"Kyoto",
}
local function fixture()
	local model = rb.Instance.new("DataModel")
	local ws, storage = model:GetService("Workspace"), model:GetService("ServerStorage")
	for index, name in expected do
		local root = rb.Instance.new("Model")
		root.Name, root.Parent = name, ws
		root:SetAttribute("GeometrySentinel", index)
		for partIndex = 1, 5 do
			local part = rb.Instance.new("Part")
			part.Name = "Part" .. partIndex
			part.Anchored = true
			part.CFrame = rb.CFrame.new(index * 100, partIndex * 3, index + partIndex)
			part.Size = rb.Vector3.new(partIndex, 2, 3)
			part.Parent = root
		end
	end
	local link = rb.Instance.new("ObjectValue")
	link.Name, link.Value, link.Parent = "CrossRootLink", ws.Quarry.Part1, ws.Prison
	return { model = model, workspace = ws, storage = storage }
end
local function environment(f, options)
	options = options or {}
	local state = { calls = 0 }
	local env = {
		workspace = f.workspace,
		Instance = rb.Instance,
		game = {
			PlaceId = options.placeId or 92594200898716,
			RunService = {
				IsStudio = function()
					return not options.notStudio
				end,
				IsRunning = function()
					return options.running == true
				end,
			},
			ServerStorage = f.storage,
			HttpService = {
				GetAsync = function(_, url)
					assert(url:find("qa-release-full-map-preflight.luau", 1, true), url)
					if options.httpError then
						error("simulated source fetch failure")
					end
					return preflightSource
				end,
				JSONEncode = function(_, value)
					return serde.encode("json", value)
				end,
			},
			GetService = function(_, service)
				assert(service == "StudioTestService")
				return {
					ExecuteMultiplayerTestAsync = function(_, count, args)
						state.calls += 1
						state.count, state.args = count, args
						state.duringScenery = #f.workspace:GetDescendants()
						state.snapshotDuringTest = f.model:Clone()
						state.quarryBefore = f.workspace.Quarry.Part1.CFrame
						state.quarrySize = f.workspace.Quarry.Part1.Size
						state.quarrySentinel = f.workspace.Quarry:GetAttribute("GeometrySentinel")
						if options.interrupt then
							coroutine.yield("simulated Studio close")
						end
						if options.testError then
							error("simulated STS failure")
						end
						if options.changeMap then
							f.workspace.Quarry.Part1:Destroy()
						end
						return "synthetic STS result"
					end,
				}
			end,
		},
		task = {
			spawn = function(fn)
				state.worker = coroutine.create(fn)
				local ok, result = coroutine.resume(state.worker)
				assert(ok, result)
				return state.worker
			end,
		},
	}
	setmetatable(env, { __index = getfenv() })
	env.loadstring = function(source)
		local fn, err = loadstring(source)
		if fn then
			setfenv(fn, env)
		end
		return fn, err
	end
	return env, state
end
local function execute(source, f, options)
	local env, state = environment(f, options)
	local fn = assert(env.loadstring(source))
	local ok, result = pcall(fn, { Prison = true })
	return ok, result, state
end
local function readReport(f, label)
	return serde.decode("json", f.storage["QARelease" .. label .. "Result"].Value)
end
check("legacy scene script compiles", loadstring(legacySource) ~= nil)
check("full-map preflight compiles", loadstring(preflightSource) ~= nil)
do
	local f = fixture()
	local count = #f.model:GetDescendants()
	local ok, message = execute(legacySource, f)
	check(
		"old scene entry point fails closed",
		not ok and tostring(message):find("UNSAFE_SCENE_LEASE_DISABLED", 1, true)
	)
	check("legacy invocation changes no instances", #f.model:GetDescendants() == count)
	check("legacy invocation leaves all roots parented", #f.workspace:GetChildren() == #expected)
	check(
		"legacy invocation creates no lease or staging",
		not f.storage:FindFirstChild("QAReleaseMapLease")
			and not f.workspace:FindFirstChild("QAReleaseStaging")
	)
end
do
	local f = fixture()
	local before = #f.model:GetDescendants()
	local ok, result = execute(preflightSource, f)
	check("complete synthetic map passes read-only preflight", ok and #result.roots == 30)
	check(
		"preflight truthfully reports no memory reduction",
		result.mode == "FULL_MAP"
			and result.memoryReduction == false
			and result.sceneryMoved == false
	)
	check("preflight leaves object count unchanged", #f.model:GetDescendants() == before)
end
for _, case in
	{ "missing", "empty", "duplicate", "nonarchivable", "wrongclass", "lease", "staging" }
do
	local f = fixture()
	if case == "missing" then
		f.workspace.Quarry:Destroy()
	elseif case == "empty" then
		f.workspace.Quarry:ClearAllChildren()
	elseif case == "duplicate" then
		f.workspace.Quarry:Clone().Parent = f.workspace
	elseif case == "nonarchivable" then
		f.workspace.Quarry.Archivable = false
	elseif case == "wrongclass" then
		f.workspace.Quarry:Destroy()
		local fake = rb.Instance.new("StringValue")
		fake.Name, fake.Parent = "Quarry", f.workspace
	elseif case == "lease" then
		local lease = rb.Instance.new("BindableFunction")
		lease.Name, lease.Parent = "QAReleaseMapLease", f.storage
	else
		local staging = rb.Instance.new("Model")
		staging.Name, staging.Parent = "QAReleaseStaging", f.workspace
	end
	local before = #f.model:GetDescendants()
	local ok, message = execute(preflightSource, f)
	check(
		"preflight rejects " .. case,
		not ok and tostring(message):find("RECOVERY_REQUIRED", 1, true)
	)
	check("rejected " .. case .. " scene is not altered", #f.model:GetDescendants() == before)
end
for _, options in { { notStudio = true }, { running = true }, { placeId = 1 } } do
	check(
		"preflight refuses invalid execution context",
		not execute(preflightSource, fixture(), options)
	)
end
for _, helper in
	{
		{ id = "tutorial", label = "Tutorial", players = 1 },
		{ id = "pvp", label = "Pvp", players = 2 },
		{ id = "actions", label = "Actions", players = 2 },
	}
do
	local source = fs.readFile("scripts/run-release-" .. helper.id .. "-qa.luau")
	check(helper.id .. " coordinator compiles", loadstring(source) ~= nil)
	check(
		helper.id .. " has no legacy scene/restore path",
		not source:find("qa-release-scene-session", 1, true)
			and not source:find(':Invoke("restore")', 1, true)
	)
	for _, mode in
		{ "success", "failure", "interruption", "missing", "legacy", "http_error", "changed" }
	do
		local f = fixture()
		if mode == "missing" then
			f.workspace.Quarry:Destroy()
		elseif mode == "legacy" then
			local staleLease = rb.Instance.new("BindableFunction")
			staleLease.Name, staleLease.Parent = "QAReleaseMapLease", f.storage
		end
		local before = #f.workspace:GetDescendants()
		local ok, result, state = execute(source, f, {
			interrupt = mode == "interruption",
			testError = mode == "failure",
			httpError = mode == "http_error",
			changeMap = mode == "changed",
		})
		check(
			helper.id .. " " .. mode .. " returns a started status",
			ok and result:find("FULL_MAP", 1, true)
		)
		if mode ~= "changed" then
			check(
				helper.id .. " " .. mode .. " leaves scenery intact in memory",
				#f.workspace:GetDescendants() == before
			)
		end
		if mode == "missing" or mode == "legacy" or mode == "http_error" then
			local report = readReport(f, helper.label)
			check(
				helper.id .. " " .. mode .. " never launches STS",
				state.calls == 0 and not report.ok and not report.mapIntact
			)
		else
			check(
				helper.id .. " " .. mode .. " uses requested player count",
				state.calls == 1
					and state.count == helper.players
					and state.args == "release-" .. helper.id .. "-v1"
			)
			check(
				helper.id .. " " .. mode .. " keeps full scenery during STS",
				state.duringScenery == before
			)
			local saved = rb.deserializePlace(rb.serializePlace(state.snapshotDuringTest))
			local savedWorkspace = saved:GetService("Workspace")
			check(
				helper.id .. " " .. mode .. " binary save/reopen retains every root",
				#savedWorkspace:GetChildren() == 30 and #savedWorkspace:GetDescendants() == before
			)
			check(
				helper.id .. " " .. mode .. " retains geometry and cross-root references",
				savedWorkspace.Quarry.Part1.CFrame == state.quarryBefore
					and savedWorkspace.Quarry.Part1.Size == state.quarrySize
					and savedWorkspace.Quarry:GetAttribute("GeometrySentinel") == state.quarrySentinel
					and savedWorkspace.Prison.CrossRootLink.Value == savedWorkspace.Quarry.Part1
			)
			if mode == "interruption" then
				check(
					helper.id .. " interrupted run cannot claim completion",
					f.storage["QARelease" .. helper.label .. "Result"].Value == "running"
						and coroutine.status(state.worker) == "suspended"
				)
				check(
					helper.id .. " interrupted save needs no restore closure",
					not saved:GetService("ServerStorage"):FindFirstChild("QAReleaseMapLease")
						and not savedWorkspace:FindFirstChild("QAReleaseStaging")
				)
				local repeated = execute(source, f)
				check(helper.id .. " blocks another run over interrupted result", not repeated)
			else
				local report = readReport(f, helper.label)
				check(
					helper.id .. " " .. mode .. " truthfully reports map/memory state",
					report.mapIntact == (mode ~= "changed")
						and not report.sceneryMoved
						and not report.memoryReduction
				)
				check(
					helper.id .. " " .. mode .. " preserves actual test error status",
					report.ok == (mode ~= "failure")
				)
			end
		end
	end
end
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	realMap = false,
	nativeMemoryBenchmark = false,
	serialization = "actual binary place round trip of synthetic fixtures",
}))
