--!nocheck
-- Compile live harness/installers and guard the real remote/no-grant boundaries.
local fs = require("@lune/fs")
local process = require("@lune/process")
local serde = require("@lune/serde")
local server = fs.readFile("scripts/qa-release-tutorial-server.luau")
local client = fs.readFile("scripts/qa-release-tutorial-client.luau")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
check("server script compiles", loadstring(server) ~= nil)
check("client script compiles", loadstring(client) ~= nil)
for _, path in { "scripts/run-release-tutorial-qa.luau", "scripts/qa-release-resume-map.luau" } do
	check(path .. " compiles", loadstring(fs.readFile(path), "@" .. path) ~= nil)
end
for _, source in { server, client } do
	for _, forbidden in
		{
			"TutorialService",
			"Tutorial.dug(",
			"Tutorial.sold(",
			"Tutorial.upgraded(",
			"ResetProgress",
			'"Reset"',
		}
	do
		-- Comments describe the prohibition; inspect executable lines only.
		for line in source:gmatch("[^\r\n]+") do
			if not line:match("^%s*%-%-") then
				assert(not line:find(forbidden, 1, true), forbidden)
			end
		end
	end
end
check("no synthetic tutorial transition or reset calls", true)
local installer = process.exec("node", { "scripts/make-release-tutorial-qa.mjs" })
check("Edit installer emits and compiles", installer.ok and loadstring(installer.stdout) ~= nil)
local count = 0
for source in installer.stdout:gmatch("%[====%[(.-)%]====%]") do
	count += 1
	check("embedded live script " .. count .. " compiles", loadstring(source) ~= nil)
end
check("only two test scripts installed", count == 2)
local cleanup = process.exec("node", { "scripts/make-release-tutorial-qa.mjs", "--cleanup" })
check("exact-name cleanup compiles", cleanup.ok and loadstring(cleanup.stdout) ~= nil)
check(
	"Ready listener precedes folder publication",
	server:find("ready.OnServerEvent:Connect", 1, true)
		< server:find("folder.Parent = game.ReplicatedStorage", 1, true)
)
check(
	"server enforces fresh scoped account rather than manufacturing tutorial state",
	server:find("assert(report.testScope", 1, true)
		and server:find('"Refuse to reset or manufacture fresh tutorial state"', 1, true)
		and not server:find("p.tutorial =", 1, true)
)
for _, name in
	{
		"P.Mutate(",
		"P.MutateDurable(",
		"profile.coins =",
		"p.coins =",
		"profile.counters[",
		"StarterReward",
		"AchievementService.OnStat",
	}
do
	check(
		"live harness never manufactures resources: " .. name,
		not server:gsub("==", "~="):find(name, 1, true)
	)
end
for _, name in { "DigStart", "DigAccepted", "Sell", "UpgradeItem", "LevelUp" } do
	check(
		"ordinary client transport " .. name,
		client:find('R.event("' .. name .. '")', 1, true) ~= nil
	)
end
check(
	"loading readiness gate precedes Ready",
	client:find('player:GetAttribute("LoadingBlocked") == false', 1, true)
		< client:find('phase = "ready"', 1, true)
)
check("twenty minute deadline recorded", server:find("task.delay(1200", 1, true) ~= nil)
check(
	"real mine natural reset clock matches server clock",
	server:find("mine.resetAt-os.clock()", 1, true) ~= nil
		or server:find("mine.resetAt - os.clock()", 1, true) ~= nil
)
check("real support block selected separately", server:find("local support", 1, true) ~= nil)
check(
	"VirtualInput drives actual shovel selection",
	client:find("CreateVirtualInput", 1, true) ~= nil
		and client:find("SendMouseButton", 1, true) ~= nil
)
local _, rawCalls = server:gsub(":InvokeClient%(", "")
check("every client RPC goes through the bounded wrapper", rawCalls == 1)
check(
	"streaming request has an explicit10second engine timeout",
	server:find("RequestStreamAroundAsync(at, 10)", 1, true) ~= nil
)
check(
	"FlowPhase exists before first RPC",
	server:find('folder:SetAttribute("FlowPhase", "startup")', 1, true)
		< server:find('callClient("inspect"', 1, true)
)
check(
	"client reports progress before possibly yielding debug hook",
	client:find('progress("inspect_close_window")', 1, true)
		< client:find('debugHook:Invoke("close")', 1, true)
)
check(
	"client rejects unsettled guide and missing rendered frames",
	client:find("inspect_guide_timeout", 1, true) and client:find("inspect_render_timeout", 1, true)
)

-- Run the exact server RPC wrapper with deterministic scheduler/transport boundaries.
local first = assert(server:find("local function callClient(", 1, true))
local last = assert(server:find("local function finish(", first, true))
local rpcSource = server:sub(first, last - 1) .. "\nreturn callClient"
local function rpcFixture(options)
	options = options or {}
	local now, calls, cancelled = 0, 0, 0
	local pending = {}
	local attributes = {}
	local fakeReport = {
		rpc = { started = 0, completed = 0, recent = {} },
		startup = { lastClient = { phase = "inspect_wait_render", rpcId = 1 } },
	}
	local env = { report = fakeReport, startedAt = 0, ended = false, player = { UserId = -701 } }
	local function resume(thread)
		pending[thread] = nil
		local ok, delay = coroutine.resume(thread)
		assert(ok, delay)
		if coroutine.status(thread) ~= "dead" then
			pending[thread] = now + (delay or 0)
		end
	end
	local function advance(seconds)
		now += seconds
		if options.abortAt and now >= options.abortAt then
			env.ended = true
		end
		local due = {}
		for thread, at in pending do
			if at <= now then
				table.insert(due, thread)
			end
		end
		for _, thread in due do
			resume(thread)
		end
	end
	env.os = {
		clock = function()
			return now
		end,
	}
	env.folder = {
		SetAttribute = function(_, name, value)
			attributes[name] = value
		end,
	}
	env.task = {
		spawn = function(fn)
			local thread = coroutine.create(fn)
			resume(thread)
			return thread
		end,
		wait = function(seconds)
			advance(seconds)
			return seconds
		end,
		cancel = function(thread)
			cancelled += 1
			if options.cancelFails then
				error("simulated engine cancellation unavailable")
			end
			pending[thread] = nil
			coroutine.close(thread)
		end,
	}
	env.rpc = {
		InvokeClient = function(_, _, op, args, id)
			calls += 1
			if options.delay then
				coroutine.yield(options.delay)
			end
			if options.failure then
				error(options.failure)
			end
			return { op = op, args = args, id = id }
		end,
	}
	local fn = assert(loadstring(rpcSource))
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return {
		call = fn(),
		env = env,
		report = fakeReport,
		attributes = attributes,
		advance = advance,
		stats = function()
			return {
				now = now,
				calls = calls,
				cancelled = cancelled,
				pending = next(pending) ~= nil,
			}
		end,
	}
end
local test = rpcFixture()
local result = test.call("inspect", { marker = "mine" }, 0.2)
check(
	"bounded RPC returns exact successful response",
	result.op == "inspect" and result.args.marker == "mine" and result.id == 1
)
check(
	"successful RPC records completion and clears pending state",
	test.report.rpc.completed == 1
		and test.report.rpc.active == nil
		and test.attributes.RpcStatus == "complete"
)
test = rpcFixture({ delay = 0.15 })
result = test.call("inspect", {}, 0.2)
check(
	"response before deadline remains successful",
	result.op == "inspect" and test.stats().now < 0.2
)
test = rpcFixture({ delay = math.huge })
local ok, err = pcall(test.call, "inspect", {}, 0.2)
check(
	"hung RPC fails at its deadline instead of20minute global deadline",
	not ok
		and tostring(err):find("rpc_timeout: inspect #1", 1, true)
		and test.stats().now >= 0.2
		and test.stats().now <= 0.251
)
check(
	"hung RPC is never retried or counted as completed",
	test.stats().calls == 1
		and test.report.rpc.completed == 0
		and test.attributes.RpcStatus == "timeout"
)
check(
	"timeout retains operation deadline and last client subphase",
	test.report.rpc.active.timeout == 0.2
		and test.report.rpc.active.lastClient.phase == "inspect_wait_render"
)
check(
	"timeout cancels pending worker when engine permits",
	test.stats().cancelled == 1 and not test.stats().pending
)
test = rpcFixture({ delay = 1, cancelFails = true })
ok = pcall(test.call, "upgrade", {}, 0.2)
test.advance(2)
check(
	"late reply cannot convert timeout into success even if cancellation fails",
	not ok
		and test.report.rpc.active.status == "timeout"
		and test.report.rpc.completed == 0
		and test.stats().calls == 1
)
test = rpcFixture({ failure = "native UI assertion failed" })
ok, err = pcall(test.call, "inspect", {}, 0.2)
check(
	"client exception remains a visible failed RPC",
	not ok
		and tostring(err):find("native UI assertion failed", 1, true)
		and test.attributes.RpcStatus == "error"
)
test = rpcFixture({ delay = 10, abortAt = 0.1 })
ok, err = pcall(test.call, "dig", { expectedSeconds = 0.5 }, 1)
check(
	"ended test aborts pending RPC promptly",
	not ok and tostring(err):find("rpc_aborted", 1, true) and test.stats().now <= 0.151
)
test = rpcFixture()
test.call("dig", { expectedSeconds = 30 })
check("dig RPC budget includes real configured mining duration", test.attributes.RpcTimeout >= 42)
for _ = 1, 19 do
	test.call("inspect", {})
end
check(
	"RPC history remains bounded during long mining run",
	#test.report.rpc.recent == 12
		and test.report.rpc.started == 20
		and test.report.rpc.completed == 20
)
test.env.ended = true
ok = pcall(test.call, "sell", {})
check("finished harness refuses to launch another action", not ok and test.stats().calls == 20)
result = test.call("stop")
check(
	"best-effort stop remains allowed without overwriting action history",
	result.op == "stop" and test.report.rpc.started == 20 and test.report.rpc.completed == 20
)
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	realProfiles = false,
	realStores = false,
	liveExecutionClaimed = false,
}))
