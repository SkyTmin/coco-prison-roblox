--!nocheck
-- Actual TopBoards startup/refresh, with deterministic replicated-child signals.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local source = fs.readFile("src/client/TopBoards.luau")
local first = assert(source:find("function TopBoards.Refresh()", 1, true))
local last = assert(source:find("\nreturn TopBoards", first, true))
local body = source:sub(first, last - 1)
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local function signal()
	local listeners = {}
	return {
		Connect = function(_, fn)
			table.insert(listeners, fn)
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(listeners) do
				fn(...)
			end
		end,
		count = function()
			return #listeners
		end,
	}
end
local function node(name, kind)
	local object =
		{ Name = name, kind = kind, children = {}, ChildAdded = signal(), Changed = signal() }
	function object:IsA(class)
		return self.kind == class
	end
	function object:GetChildren()
		return table.clone(self.children)
	end
	function object:FindFirstChild(key)
		for _, child in self.children do
			if child.Name == key then
				return child
			end
		end
	end
	function object:add(child)
		table.insert(self.children, child)
		self.ChildAdded:Fire(child)
	end
	function object:WaitForChild()
		error("Startup must not wait for leaderboard data")
	end
	return object
end
local function fixture(existing)
	local replicated = node("ReplicatedStorage", "Folder")
	local tops = node("Tops", "Folder")
	local money = node("money", "StringValue")
	if existing then
		tops:add(money)
		replicated:add(tops)
	end
	local rendered = { money = 0, level = 0 }
	local guis = {}
	for _, id in { "money", "level" } do
		guis[{
			GetAttribute = function()
				return id
			end,
		}] = {}
	end
	local added, removed = signal(), signal()
	local fn = assert(
		loadstring(
			"local TopBoards = {}\nlocal started = false\nlocal localeOf\n"
				.. body
				.. "\nreturn TopBoards",
			"@TopBoards.Start"
		)
	)
	setfenv(
		fn,
		setmetatable({
			ReplicatedStorage = replicated,
			guis = guis,
			CollectionService = {
				GetTagged = function()
					return {}
				end,
				GetInstanceAddedSignal = function()
					return added
				end,
				GetInstanceRemovedSignal = function()
					return removed
				end,
			},
			attach = function() end,
			detach = function() end,
			render = function(part)
				local id = part:GetAttribute("Board")
				rendered[id] += 1
			end,
			task = {
				spawn = function()
					error("No suspended startup waiter expected")
				end,
			},
		}, { __index = getfenv() })
	)
	return fn(), replicated, tops, money, rendered
end
do
	local boards, replicated, tops, money, rendered = fixture(false)
	boards.Start(function()
		return "en"
	end)
	check("start returns before Tops exists", replicated.ChildAdded.count() == 1)
	replicated:add(node("Other", "Folder"))
	replicated:add(node("Tops", "StringValue"))
	check("unrelated and wrong-class children are ignored", rendered.money == 0)
	-- Remove the deliberately invalid mock name before adding the real folder.
	replicated.children = {}
	replicated:add(tops)
	check(
		"late folder gets child subscription and refresh",
		tops.ChildAdded.count() == 1 and rendered.money == 1
	)
	tops:add(money)
	check(
		"late board value gets change subscription and initial refresh",
		money.Changed.count() == 1 and rendered.money == 2
	)
	local oldMoney, oldLevel = rendered.money, rendered.level
	money.Changed:Fire("new rows")
	check(
		"late value changes redraw only matching board",
		rendered.money == oldMoney + 1 and rendered.level == oldLevel
	)
	tops.ChildAdded:Fire(money)
	replicated.ChildAdded:Fire(tops)
	boards.Start(function()
		return "fr"
	end)
	check(
		"duplicate add and start do not duplicate subscriptions",
		money.Changed.count() == 1
			and tops.ChildAdded.count() == 1
			and replicated.ChildAdded.count() == 1
	)
end
do
	local boards, _, tops, money, rendered = fixture(true)
	boards.Start(function()
		return "en"
	end)
	check(
		"already replicated folder and values are observed",
		tops.ChildAdded.count() == 1 and money.Changed.count() == 1 and rendered.money > 0
	)
	local before = rendered.money
	money.Changed:Fire("updated rows")
	check("existing value updates remain live", rendered.money == before + 1)
end
print(
	serde.encode(
		"json",
		{ actualSource = true, passed = #checks, checks = checks, realEngine = false },
		true
	)
)
