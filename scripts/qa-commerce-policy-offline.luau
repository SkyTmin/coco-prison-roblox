--!nocheck
-- Actual CommercePolicyService under a deterministic, mock-only scheduler/API.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
		end,
		Fire = function(_, ...)
			for _, fn in callbacks do
				fn(...)
			end
		end,
	}
end
local now, scheduled, threads = 0, {}, {}
local function schedule(delay, fn, ...)
	local args = table.pack(...)
	local thread = coroutine.create(function()
		fn(table.unpack(args, 1, args.n))
	end)
	local work = { at = now + delay, thread = thread }
	threads[thread] = work
	table.insert(scheduled, work)
	return thread
end
local function advance(seconds)
	local finish = now + seconds
	for _ = 1, 1000 do
		table.sort(scheduled, function(a, b)
			return a.at < b.at
		end)
		local work = scheduled[1]
		if not work or work.at > finish then
			now = finish
			return
		end
		table.remove(scheduled, 1)
		now = work.at
		if not work.cancelled then
			local ok, err = coroutine.resume(work.thread)
			assert(ok, err)
		end
	end
	error("scheduler runaway")
end
local players = { PlayerAdded = signal(), PlayerRemoving = signal(), list = {} }
function players:GetPlayers()
	return self.list
end
local responses, calls, hanging, messages = {}, {}, {}, {}
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
local services = {
	Players = players,
	ReplicatedStorage = {
		WaitForChild = function()
			return names
		end,
	},
	PolicyService = {
		GetPolicyInfoForPlayerAsync = function(_, p)
			calls[p] = (calls[p] or 0) + 1
			local result = responses[p]
			if result == "error" then
				error("mock outage")
			end
			if result == "hang" then
				hanging[p] = coroutine.running()
				return coroutine.yield()
			end
			return result
		end,
	},
}
local modules = {
	Strings = {
		localeOf = function()
			return "en"
		end,
		t = function(key)
			return key
		end,
	},
	Remotes = {
		event = function()
			return {
				FireClient = function(_, p, text)
					table.insert(messages, { p = p, text = text })
				end,
			}
		end,
	},
}
local source = assert(loadstring(fs.readFile("src/server/Services/CommercePolicyService.luau")))
setfenv(
	source,
	setmetatable({
		game = {
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		script = { Parent = names },
		require = function(name)
			return assert(modules[name], name)
		end,
		task = {
			spawn = function(fn, ...)
				return schedule(0, fn, ...)
			end,
			defer = function(fn, ...)
				return schedule(0, fn, ...)
			end,
			delay = schedule,
			cancel = function(thread)
				threads[thread].cancelled = true
			end,
		},
	}, { __index = getfenv() })
)
local policy = source()
local function actor(response)
	local p = { Parent = players, attributes = {} }
	function p:SetAttribute(key, value)
		self.attributes[key] = value
	end
	responses[p] = response
	table.insert(players.list, p)
	players.PlayerAdded:Fire(p)
	return p
end
local allow = { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true }
local deny = { ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = false }
local existing = actor(allow)
check("uninitialized is denied", not policy.CanRandom(existing) and not policy.CanTrade(existing))
policy.Start()
policy.Start()
check(
	"pending publishes false before yielding",
	existing.attributes.PolicyState == "pending"
		and existing.attributes.PaidRandomAllowed == false
		and existing.attributes.PaidTradeAllowed == false
)
check(
	"pending action uses localized loading reason",
	not policy.RequireRandom(existing) and messages[#messages].text == "policy_loading"
)
advance(0)
check(
	"allowed response enables both gates",
	policy.CanRandom(existing) and policy.CanTrade(existing)
)
check("Start idempotent single API call", calls[existing] == 1)
local restricted = actor(deny)
advance(0)
check(
	"restricted ready remains denied",
	restricted.attributes.PolicyState == "ready"
		and not policy.CanRandom(restricted)
		and not policy.CanTrade(restricted)
)
policy.RequireRandom(restricted)
check("ready random denial reason", messages[#messages].text == "policy_random_unavailable")
policy.RequireTrade(restricted)
check("ready trade denial reason", messages[#messages].text == "policy_trade_unavailable")
restricted.attributes.PaidRandomAllowed = true
restricted.attributes.PaidTradeAllowed = true
check(
	"forged replicated attributes grant no authority",
	not policy.CanRandom(restricted) and not policy.CanTrade(restricted)
)
for _, values in
	{
		{ ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = false },
		{ ArePaidRandomItemsRestricted = true, IsPaidItemTradingAllowed = true },
	}
do
	local p = actor(values)
	advance(0)
	check(
		"independent API flags " .. tostring(values.ArePaidRandomItemsRestricted),
		policy.CanRandom(p) == not values.ArePaidRandomItemsRestricted
			and policy.CanTrade(p) == values.IsPaidItemTradingAllowed
	)
end
for index, value in
	{
		false,
		{},
		{ ArePaidRandomItemsRestricted = false },
		{ ArePaidRandomItemsRestricted = "false", IsPaidItemTradingAllowed = true },
		{ ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = 1 },
		"error",
	}
do
	local p = actor(value)
	advance(0)
	check(
		"malformed/error fails closed " .. index,
		p.attributes.PolicyState == "error" and not policy.CanRandom(p) and not policy.CanTrade(p)
	)
	responses[p] = allow
	advance(4.9)
	check("no hot-loop retry " .. index, calls[p] == 1)
	advance(0.1)
	check(
		"bounded retry recovers " .. index,
		calls[p] == 2 and policy.CanRandom(p) and policy.CanTrade(p)
	)
end
local backoff = actor("error")
advance(0)
for _, seconds in { 5, 10, 20, 40, 60, 60 } do
	local previous = calls[backoff]
	advance(seconds - 0.01)
	check("backoff waits " .. previous, calls[backoff] == previous)
	advance(0.01)
	check("backoff retries " .. previous, calls[backoff] == previous + 1)
end
players.PlayerRemoving:Fire(backoff)
backoff.Parent = nil
local prior = calls[backoff]
advance(120)
check("removal cancels retry", calls[backoff] == prior)
local stale = actor("hang")
advance(0)
check("hung API remains pending initially", stale.attributes.PolicyState == "pending")
advance(15)
check(
	"hung API times out closed",
	stale.attributes.PolicyState == "error" and not policy.CanTrade(stale)
)
responses[stale] = deny
advance(5)
check("timeout releases retry", calls[stale] == 2 and stale.attributes.PolicyState == "ready")
assert(coroutine.resume(hanging[stale], allow))
check(
	"late timed-out result cannot replace current denial",
	not policy.CanTrade(stale) and not policy.CanRandom(stale)
)
local departed = actor("hang")
advance(0)
players.PlayerRemoving:Fire(departed)
departed.Parent = nil
assert(coroutine.resume(hanging[departed], allow))
check(
	"late departed result cannot republish ready",
	departed.attributes.PolicyState == "pending" and not policy.CanRandom(departed)
)
local oldCalls = calls[departed]
advance(120)
check("departure cancels timeout and retries", calls[departed] == oldCalls)
existing.Parent = nil
check(
	"departed player denied even before removal event",
	not policy.CanRandom(existing) and not policy.CanTrade(existing)
)
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualCommercePolicyService = true,
	realPolicyRequests = false,
	realProfiles = false,
	realPurchases = false,
}, true))
