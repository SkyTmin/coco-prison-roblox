--!nocheck
-- Actual-source receipt boundary. All services, profiles and stores below are local mocks.
-- No Roblox process, Marketplace call or real DataStore is used.
local fs = require("@lune/fs")
local checks = 0
local function check(name, condition)
	assert(condition, name)
	checks += 1
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for key, child in value do
		out[key] = copy(child)
	end
	return out
end
local names = setmetatable({}, {
	__index = function(_, name)
		return name
	end,
})
local function fixture()
	local f = {
		profile = { crystals = 0, inventory = {} },
		real = true,
		reads = 0,
		opens = 0,
		saves = 0,
		mutations = 0,
		notices = 0,
	}
	f.player = { UserId = 123456, Parent = true }
	local modules = {
		CommercePolicy = {
			RequiresRandomPurchase = function()
				return true
			end,
		},
		CommercePolicyService = {
			CanRandom = function()
				return false
			end,
			RequireRandom = function()
				error("Already-paid receipts must never use the purchase policy guard")
			end,
		},
		Boosters = {},
		Config = { boosters = { maxStored = 100 } },
		PrisPlus = {},
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
					FireClient = function()
						f.notices += 1
					end,
				}
			end,
		},
		InventoryService = {
			add = function(profile, id, count)
				profile.inventory[id] = (profile.inventory[id] or 0) + count
				return 0
			end,
		},
		Donate = {
			byProduct = function(id)
				return if id == 101 then { crystals = 100 } else nil,
					if id == 102 then "key" else nil
			end,
			item = function(id)
				return if id == "key" then { give = "key", price = 10 } else nil
			end,
			limit = function()
				return 1
			end,
			name = function(id)
				return id
			end,
		},
	}
	local store = {
		GetAsync = function(_, key, options)
			f.reads += 1
			f.lastKey, f.lastOptions = key, options
			if f.readError then
				error("injected read failure")
			end
			if f.onRead then
				f.onRead()
			end
			return copy(f.legacy)
		end,
	}
	local services = {
		DataStoreService = {
			GetDataStore = function(_, name)
				f.opens += 1
				f.storeName = name
				if f.openError then
					error("injected store open failure")
				end
				return store
			end,
		},
		ReplicatedStorage = {
			Shared = names,
			WaitForChild = function()
				return names
			end,
		},
		RunService = {
			IsStudio = function()
				return false
			end,
		},
		Players = {
			GetPlayerByUserId = function(_, id)
				return if id == 123456 then f.player else nil
			end,
		},
		MarketplaceService = {},
	}
	modules.ProfileService = {
		Get = function()
			return f.profile
		end,
		IsReal = function()
			return f.real
		end,
		SaveNow = function()
			f.saves += 1
			return not f.saveError
		end,
		MutateDurable = function(_, transform)
			f.mutations += 1
			local staged = copy(f.profile)
			transform(staged)
			if f.durableError == "before" then
				return false
			end
			f.disk = copy(staged)
			if f.durableError == "after" then
				return false
			end
			transform(f.profile)
			return true
		end,
	}
	local env = setmetatable({
		game = {
			GetService = function(_, name)
				return assert(services[name], name)
			end,
		},
		script = { Parent = names },
		require = function(name)
			return assert(modules[name], name)
		end,
		Instance = {
			new = function(class)
				assert(class == "DataStoreGetOptions")
				return {}
			end,
		},
		Enum = {
			ProductPurchaseDecision = { PurchaseGranted = "granted", NotProcessedYet = "retry" },
		},
		warn = function() end,
		task = {
			spawn = function(fn, ...)
				fn(...)
			end,
		},
	}, { __index = getfenv() })
	local function load(path, expose)
		local source = fs.readFile(path)
		if expose then
			source = source:gsub("return DonateService%s*$", "return processReceipt")
		end
		local fn = assert(loadstring(source, "@" .. path))
		setfenv(fn, env)
		return fn()
	end
	modules.StorageNames = load("src/shared/StorageNames.luau")
	f.guard = load("src/server/Services/LegacyReceiptGuard.luau")
	modules.LegacyReceiptGuard = f.guard
	f.receipt = load("src/server/Services/DonateService.luau", true)
	function f:call(id, product)
		return self.receipt({ PlayerId = 123456, ProductId = product or 101, PurchaseId = id })
	end
	return f
end

local f = fixture()
f.legacy = {
	receipts = { "old-paid" },
	crystals = 999999,
	rubies = 1000,
	inventory = { rare_key = 99 },
	passes = { prison = true },
	noAuctionFee = true,
}
check("old durable receipt acknowledges", f:call("old-paid") == "granted")
check(
	"old durable receipt grants nothing",
	f.profile.crystals == 0 and next(f.profile.inventory) == nil
)
check("legacy recognition never mutates/saves current gameplay", f.mutations == 0 and f.saves == 0)
check("legacy recognition never shows a new-purchase notice", f.notices == 0)
check(
	"old passes and paid balances are not migrated",
	f.profile.passes == nil and f.profile.rubies == nil and f.profile.noAuctionFee == nil
)
check(
	"guard reads exact archived store/key",
	f.storeName == "PlayerProfiles_v3" and f.lastKey == "User_123456"
)
check("guard bypasses stale backend read cache", f.lastOptions.UseCache == false)
check(
	"repeated archived callback stays acknowledged",
	f:call("old-paid") == "granted" and f.reads == 2 and f.mutations == 0
)
check(
	"read does not modify archived record",
	f.legacy.receipts[1] == "old-paid" and f.legacy.crystals == 999999
)

f = fixture()
check("missing old profile permits normal purchase", f:call("new-paid") == "granted")
check(
	"new purchase uses existing durable grant",
	f.profile.crystals == 100 and f.disk.crystals == 100 and f.profile.receipts[1] == "new-paid"
)
f.readError = true
check(
	"current receipt retry precedes failed legacy lookup",
	f:call("new-paid") == "granted" and f.reads == 1
)
check(
	"current receipt retry never rewards twice",
	f.profile.crystals == 100 and f.mutations == 1 and f.saves == 1
)
f.saveError = true
check(
	"current receipt still needs existing SaveNow acknowledgement",
	f:call("new-paid") == "retry" and f.reads == 1
)

f = fixture()
f.legacy = { receipts = { "other" }, inventory = { key = 500 }, crystals = 9000 }
check("nonmatching archived receipt allows actual item path", f:call("new-item", 102) == "granted")
check(
	"only newly purchased item is granted",
	f.profile.inventory.key == 1 and f.profile.crystals == 0 and f.profile.receipts[1] == "new-item"
)
check("archived item quantities remain unchanged", f.legacy.inventory.key == 500)

f = fixture()
f.readError = true
check("legacy read failure asks Roblox to retry", f:call("read-retry") == "retry")
check(
	"failed legacy read grants nothing",
	f.mutations == 0 and f.profile.crystals == 0 and f.notices == 0
)
f.readError = false
check(
	"legacy read recovery resumes one grant",
	f:call("read-retry") == "granted" and f.profile.crystals == 100
)

f = fixture()
f.openError = true
check("store-open failure also fails closed", f:call("open-retry") == "retry" and f.mutations == 0)
f.openError = false
check("store-open failure is retryable", f:call("open-retry") == "granted" and f.opens == 2)

f = fixture()
f.legacy = "invalid"
check("invalid legacy record fails closed", f:call("bad-shape") == "retry" and f.mutations == 0)
f.legacy = { receipts = "invalid" }
check(
	"invalid legacy receipt list fails closed",
	f:call("bad-receipts") == "retry" and f.mutations == 0
)
f.legacy = { schemaVersion = 3 }
check("valid archived profile without receipt list is absent", f:call("no-list") == "granted")

f = fixture()
check("first absence is confirmed", f.guard.WasGranted(123456, "late") == false)
f.legacy = { receipts = { "late" } }
check(
	"negative result is not memoized across callbacks",
	f.guard.WasGranted(123456, "late") == true and f.reads == 2
)

f = fixture()
f.onRead = function()
	f.profile = { crystals = 0, inventory = {} }
end
check(
	"profile replacement during legacy read does not grant",
	f:call("replaced") == "retry" and f.mutations == 0
)
f = fixture()
f.onRead = function()
	f.real = false
end
check(
	"failed or detached profile during read does not grant",
	f:call("detached") == "retry" and f.mutations == 0
)

for _, failure in { "before", "after" } do
	f = fixture()
	f.durableError = failure
	check(
		"new durable " .. failure .. " failure remains retryable",
		f:call("durable-" .. failure) == "retry"
	)
	check(
		"unacknowledged new grant not exposed live " .. failure,
		f.profile.crystals == 0 and f.notices == 0
	)
	f.durableError = nil
	if f.disk then
		f.profile = copy(f.disk)
	end
	check(
		"new durable " .. failure .. " retry grants exactly once",
		f:call("durable-" .. failure) == "granted" and f.profile.crystals == 100
	)
end

f = fixture()
check(
	"unknown product does not consult archive",
	f:call("unknown", 999) == "retry" and f.reads == 0
)
f.real = false
check("not loaded profile does not consult archive", f:call("not-real") == "retry" and f.reads == 0)
print("PASS " .. checks .. " actual-source release receipt checks (offline mocks only)")
