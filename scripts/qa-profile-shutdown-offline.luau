--!nocheck
-- Actual ProfileService save/release/durable functions and extracted lifecycle callbacks.
-- Cooperative fake UpdateAsync yields deterministically; no real accounts, stores or Studio.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local suite = fs.readFile("scripts/qa-profile-persistence-offline.luau")
local prefix = suite:sub(1, assert(suite:find("\n-- Exact acquisition ownership", 1, true)) - 1)
local replaced
prefix, replaced = prefix:gsub(
	"service = ProfileService, acquire = acquire,",
	"service = ProfileService, beginRelease = beginRelease, closingSessions = closingSessions, acquire = acquire,"
)
assert(replaced == 1, "private fixture export seam")
local factory = assert(loadstring(prefix .. "\nreturn fixture", "@shutdown-profile-fixture"))()
local source = fs.readFile("src/server/Services/ProfileService.luau")
local function callback(first, last, env)
	local from = assert(source:find(first, 1, true), first) + #first
	local to = assert(source:find(last, from, true), last)
	local fn = assert(
		loadstring(
			"return function(player)\n" .. source:sub(from, to - 1) .. "\nend",
			"@ProfileService.lifecycle"
		)
	)
	setfenv(fn, env)
	return fn()
end
local function fixture()
	local f = factory()
	local b = f:profile("old-server")
	local actor = f:player()
	actor.UserId = -9001
	local session = f:session(b, actor, "original-token")
	local threads = {}
	local function resume(thread, ...)
		local ok, why = coroutine.resume(thread, ...)
		assert(ok, tostring(why))
	end
	local function spawn(fn, ...)
		local thread = coroutine.create(fn)
		table.insert(threads, thread)
		resume(thread, ...)
		return thread
	end
	local moduleEnv = getfenv(b.service.MutateDurable)
	moduleEnv.task = {
		spawn = spawn,
		wait = function()
			coroutine.yield("wait")
		end,
	}
	local env = setmetatable({
		sessions = b.sessions,
		closingSessions = b.closingSessions,
		beginRelease = b.beginRelease,
		save = b.save,
		store = f.store,
		task = moduleEnv.task,
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		rememberPosition = function() end,
		bootstrapAt = {},
		retrying = {},
		replicateDue = {},
		replicatedAt = {},
		sentCopies = {},
		restored = {},
		restoring = {},
	}, { __index = getfenv() })
	-- The distinct cleanup statement selects the real final-save listener, not earlier UI cleanup.
	local leaveFirst = assert(
		source:find("\tPlayers.PlayerRemoving:Connect(function(player)\n\t\tbootstrapAt", 1, true)
	)
	local leaveEnd = assert(source:find("\n\tend)\n\t-- another server waits", leaveFirst, true))
	local leaveBody = source:sub(
		leaveFirst + #"\tPlayers.PlayerRemoving:Connect(function(player)\n",
		leaveEnd - 1
	)
	local leaveFactory = assert(loadstring("return function(player)\n" .. leaveBody .. "\nend"))
	setfenv(leaveFactory, env)
	f.leave = leaveFactory()
	f.close = callback(
		"\tgame:BindToClose(function()\n",
		"\n\tend)\n\ttask.spawn(function()\n\t\twhile true do\n\t\t\ttask.wait(AUTOSAVE_SECONDS)",
		env
	)
	f.spawn = spawn
	f.pump = function()
		for _ = 1, 8 do
			for _, thread in table.clone(threads) do
				if coroutine.status(thread) ~= "dead" then
					resume(thread)
				end
			end
		end
	end
	return f, b, actor, session
end
do
	local f, b, actor, session = fixture()
	local hold = true
	f.beforeUpdate = function()
		while hold do
			coroutine.yield("store")
		end
	end
	f.leave(actor)
	check(
		"leave detaches spendable session before final write finishes",
		b.sessions[actor] == nil and session.saving
	)
	check("detached final write remains registered", b.closingSessions[session] == actor)
	local close = f.spawn(f.close)
	check(
		"shutdown waits for an already detached final write",
		coroutine.status(close) == "suspended"
	)
	local before = f.writes
	b.beginRelease(actor, session)
	hold = false
	f.pump()
	check("deduplicated release writes once", f.writes == before + 1)
	check(
		"shutdown returns only after exact lock release",
		coroutine.status(close) == "dead"
			and f.disk["User_-9001"]._lock == nil
			and next(b.closingSessions) == nil
	)
	b.beginRelease(actor, session)
	check("finished release is not repeated", f.writes == before + 1)
end
do
	local f, b, actor, session = fixture()
	local hold = true
	f.beforeUpdate = function()
		while hold do
			coroutine.yield("store")
		end
	end
	f.spawn(function()
		b.save(actor, session, false)
	end)
	f.leave(actor)
	local close = f.spawn(f.close)
	check(
		"leave and shutdown await autosave before release",
		session.saving and coroutine.status(close) == "suspended"
	)
	local before = f.writes
	hold = false
	f.pump()
	check(
		"autosave then one final release complete in order",
		f.writes == before + 2
			and f.disk["User_-9001"]._lock == nil
			and coroutine.status(close) == "dead"
	)
end
do
	local f, b, actor, session = fixture()
	local hold = true
	f.beforeUpdate = function()
		while hold do
			coroutine.yield("store")
		end
	end
	local before = f.writes
	local close = f.spawn(f.close)
	f.leave(actor)
	check(
		"shutdown-first also detaches and owns final save",
		session.closing and b.sessions[actor] == nil and coroutine.status(close) == "suspended"
	)
	hold = false
	f.pump()
	check(
		"later PlayerRemoving cannot duplicate shutdown release",
		f.writes == before + 1 and f.disk["User_-9001"]._lock == nil
	)
end
do
	local f, b, actor, session = fixture()
	local second = f:player()
	second.UserId = -9002
	local secondSession = f:session(b, second, "second-token")
	local hold = { ["User_-9001"] = true, ["User_-9002"] = true }
	f.beforeUpdate = function(key)
		while hold[key] do
			coroutine.yield("store")
		end
	end
	f.leave(actor)
	local close = f.spawn(f.close)
	check(
		"shutdown includes leaving and still-active profiles together",
		b.closingSessions[session] == actor and b.closingSessions[secondSession] == second
	)
	hold["User_-9001"] = false
	f.pump()
	check(
		"one completed profile cannot end another pending release",
		coroutine.status(close) == "suspended"
			and b.closingSessions[secondSession] == second
			and f.disk["User_-9001"]._lock == nil
	)
	hold["User_-9002"] = false
	f.pump()
	check(
		"all profile releases drain before shutdown completion",
		coroutine.status(close) == "dead"
			and f.disk["User_-9002"]._lock == nil
			and next(b.closingSessions) == nil
	)
end
for _, fail in { false, true } do
	local f, b, actor, session = fixture()
	session.profile.coins = 10
	local hold, first = true, true
	f.beforeUpdate = function()
		if first then
			first = false
			while hold do
				coroutine.yield("store")
			end
			if fail then
				error("isolated failed checkpoint")
			end
		end
	end
	local granted
	f.spawn(function()
		granted = b.service.MutateDurable(actor, function(p)
			p.coins += 5
		end)
	end)
	f.leave(actor)
	local close = f.spawn(f.close)
	hold = false
	f.pump()
	check("departed durable caller cannot export " .. tostring(fail), granted == false)
	check(
		"final release preserves only acknowledged durable checkpoint " .. tostring(fail),
		f.disk["User_-9001"].coins == (if fail then 10 else 15)
			and session.profile.coins == (if fail then 10 else 15)
	)
	check(
		"durable/save race releases exact lock " .. tostring(fail),
		f.disk["User_-9001"]._lock == nil and coroutine.status(close) == "dead"
	)
end
do
	local f, b, actor, session = fixture()
	local hold = true
	f.beforeUpdate = function()
		while hold do
			coroutine.yield("store")
		end
	end
	f.leave(actor)
	local close = f.spawn(f.close)
	f.disk["User_-9001"]._lock = { job = "new-server", token = "new-token", at = f.time }
	f.disk["User_-9001"].coins = 77
	hold = false
	f.pump()
	check(
		"final save never clears another acquisition's lock",
		f.disk["User_-9001"]._lock.token == "new-token" and f.disk["User_-9001"].coins == 77
	)
	check(
		"lost ownership settles pending shutdown without retry overwrite",
		session.loadFailed and coroutine.status(close) == "dead" and next(b.closingSessions) == nil
	)
end
do
	local f, b, actor = fixture()
	f.beforeUpdate = function()
		error("isolated unavailable store")
	end
	f.leave(actor)
	local close = f.spawn(f.close)
	check(
		"failed final store settles callback without inventing release",
		coroutine.status(close) == "dead"
			and f.disk["User_-9001"]._lock.token == "original-token"
			and next(b.closingSessions) == nil
	)
end
print(
	serde.encode(
		"json",
		{ passed = #checks, checks = checks, actualSource = true, realDataStores = false },
		true
	)
)
