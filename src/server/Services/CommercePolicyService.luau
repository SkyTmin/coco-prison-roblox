--!strict
-- Policy is session authority, never profile data or client-owned attributes.
-- Unknown, malformed and failed responses deny new commerce actions. Already-paid
-- receipts and durable transaction recovery must not call these action guards.
local Players = game:GetService("Players")
local PolicyService = game:GetService("PolicyService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)

local Policy = {}
type Entry = {
	state: string,
	random: boolean,
	trade: boolean,
	attempt: number,
	generation: number,
	request: thread?,
	timeout: thread?,
	retry: thread?,
}
local entries: { [Player]: Entry } = {}
local started = false
local TIMEOUT = 15

local function cancel(thread: thread?)
	if thread and coroutine.status(thread) ~= "dead" then
		pcall(task.cancel, thread)
	end
end

local function publish(player: Player, entry: Entry)
	player:SetAttribute("PaidRandomAllowed", entry.state == "ready" and entry.random)
	player:SetAttribute("PaidTradeAllowed", entry.state == "ready" and entry.trade)
	player:SetAttribute("PolicyState", entry.state)
end

local query: (Player, Entry) -> ()
query = function(player: Player, entry: Entry)
	if entries[player] ~= entry or player.Parent ~= Players then
		return
	end
	entry.retry = nil
	entry.attempt += 1
	entry.generation += 1
	local generation = entry.generation
	local completed = false
	local function finish(ok: boolean, value: any)
		if completed or entries[player] ~= entry or entry.generation ~= generation then
			return
		end
		completed = true
		cancel(entry.timeout)
		entry.timeout = nil
		local valid = ok
			and typeof(value) == "table"
			and typeof(value.ArePaidRandomItemsRestricted) == "boolean"
			and typeof(value.IsPaidItemTradingAllowed) == "boolean"
		entry.state = if valid then "ready" else "error"
		entry.random = valid and value.ArePaidRandomItemsRestricted == false
		entry.trade = valid and value.IsPaidItemTradingAllowed == true
		publish(player, entry)
		if not valid then
			local delay = math.min(60, 5 * 2 ^ math.min(entry.attempt - 1, 4))
			entry.retry = task.delay(delay, query, player, entry)
		end
	end
	entry.timeout = task.delay(TIMEOUT, function()
		entry.timeout = nil
		finish(false, nil)
		cancel(entry.request)
		entry.request = nil
	end)
	entry.request = task.spawn(function()
		local ok, value = pcall(function()
			return PolicyService:GetPolicyInfoForPlayerAsync(player)
		end)
		finish(ok, value)
	end)
end

local function added(player: Player)
	if entries[player] then
		return
	end
	local entry: Entry = {
		state = "pending",
		random = false,
		trade = false,
		attempt = 0,
		generation = 0,
	}
	entries[player] = entry
	publish(player, entry)
	task.defer(query, player, entry)
end

function Policy.CanRandom(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.state == "ready" and entry.random and player.Parent == Players
end

function Policy.CanTrade(player: Player): boolean
	local entry = entries[player]
	return entry ~= nil and entry.state == "ready" and entry.trade and player.Parent == Players
end

local function requireAllowed(player: Player, allowed: boolean, deniedKey: string): boolean
	if allowed then
		return true
	end
	local entry = entries[player]
	local key = if entry and entry.state == "ready" then deniedKey else "policy_loading"
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player)))
	return false
end

function Policy.RequireRandom(player: Player): boolean
	return requireAllowed(player, Policy.CanRandom(player), "policy_random_unavailable")
end

function Policy.RequireTrade(player: Player): boolean
	return requireAllowed(player, Policy.CanTrade(player), "policy_trade_unavailable")
end

function Policy.Start()
	if started then
		return
	end
	started = true
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		local entry = entries[player]
		entries[player] = nil
		if entry then
			entry.generation += 1
			cancel(entry.request)
			cancel(entry.timeout)
			cancel(entry.retry)
		end
	end)
	for _, player in Players:GetPlayers() do
		added(player)
	end
end

return Policy
