--!nocheck
-- Actual storage/escrow modules under Lune. Every profile/store/scheduler is an isolated deep-copy mock.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local env = getfenv()
local checks, failures = {}, {}
local function check(name, ok)
	table.insert(checks, { name = name, pass = ok == true })
	if not ok then
		table.insert(failures, name)
	end
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = copy(v)
	end
	return out
end
local function fixture(seedInventory, seedPages)
	local f = {
		live = { inventory = copy(seedInventory or {}), coins = 0 },
		disk = {},
		stores = {},
		tasks = {},
		saves = 0,
		calls = 0,
		warnings = {},
	}
	f.disk = copy(f.live)
	f.stores.GangChest_v1 =
		{ guild = { pages = copy(seedPages or {}), revisions = {}, receipts = {} } }
	f.stores.FactionStorage_v1 = {}
	f.actor = {
		SetAttribute = function(_, key, value)
			f[key] = value
		end,
	}
	local names = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	})
	local modules = {
		Config = {
			tools = { pickaxe = true, sword = true },
			moneyScale = 10000,
			blockLocked = function()
				return false
			end,
			rules = {
				combat = { blockStuds = 4 },
				survival = {
					drops = {
						pickupReachBlocks = { horizontal = 1, vertical = 1 },
						mergeBlocks = 1,
						maxPerSecond = 10,
						pickupDelaySeconds = 1,
					},
				},
			},
		},
	}
	local services = {
		Players = {
			GetPlayers = function()
				return { f.actor }
			end,
		},
		CollectionService = {},
		ReplicatedStorage = {
			Shared = names,
			WaitForChild = function()
				return names
			end,
		},
		HttpService = {
			GenerateGUID = function()
				f.guid = (f.guid or 0) + 1
				return "operation" .. f.guid
			end,
		},
		DataStoreService = {
			GetDataStore = function(_, name)
				return {
					GetAsync = function(_, key)
						if f.readFail then
							error("injected read failure")
						end
						return copy(f.stores[name][key])
					end,
					UpdateAsync = function(_, key, transform)
						f.calls += 1
						local mode = f.updateFault
						f.updateFault = nil
						if mode == "before" then
							error("injected precommit failure")
						end
						local changed = transform(copy(f.stores[name][key]))
						if f.retryWith then
							f.stores[name][key] = copy(f.retryWith)
							f.retryWith = nil
							changed = transform(copy(f.stores[name][key]))
						end
						if changed ~= nil then
							f.stores[name][key] = copy(changed)
						end
						if mode == "after" then
							error("injected lost acknowledgement")
						end
						return if changed ~= nil then copy(f.stores[name][key]) else nil
					end,
				}
			end,
		},
	}
	local function load(path, transform)
		local source = fs.readFile(path)
		if transform then
			source = transform(source)
		end
		local fn = assert(loadstring(source, "@" .. path))
		setfenv(
			fn,
			setmetatable({
				game = {
					GetService = function(_, k)
						return assert(services[k], k)
					end,
				},
				script = { Parent = names },
				require = function(k)
					return assert(modules[k], k)
				end,
				warn = function(...)
					table.insert(f.warnings, table.pack(...))
				end,
				Random = {
					new = function()
						return {}
					end,
				},
				Vector3 = rb.Vector3,
				onWorldDrop = function(stack)
					f.escaped = (f.escaped or 0) + stack.count
				end,
				task = {
					spawn = function(fn, ...)
						table.insert(f.tasks, { fn = fn, args = table.pack(...) })
					end,
				},
			}, { __index = env })
		)
		return fn()
	end
	modules.Types = {}
	modules.Persistence = load("src/shared/Persistence.luau")
	modules.Numbers = load("src/shared/Numbers.luau")
	modules.InventoryService = load("src/server/Services/InventoryService.luau")
	modules.ProfileService = {
		Get = function()
			return f.live
		end,
		IsReal = function()
			return f.live ~= nil
		end,
		CanExport = function()
			return f.live ~= nil and f.live.storageTransfer == nil
		end,
		Mutate = function(_, fn)
			fn(f.live)
		end,
		OnLoaded = function() end,
		SaveNow = function()
			f.saves += 1
			local mode = f.saveFaults and f.saveFaults[f.saves]
			if mode == "before" then
				return false
			end
			f.disk = copy(f.live)
			if f.onSave then
				f.onSave(f.saves)
			end
			return mode ~= "after"
		end,
		MutateDurable = function(_, transform)
			local staged = copy(f.live)
			transform(staged)
			f.saves += 1
			local mode = f.saveFaults and f.saveFaults[f.saves]
			if mode == "before" then
				return false
			end
			f.disk = copy(staged)
			if f.onSave then
				f.onSave(f.saves)
			end
			if mode == "after" then
				return false
			end
			transform(f.live)
			return true
		end,
	}
	modules.SharedStorageRecord = load("src/server/Services/SharedStorageRecord.luau")
	modules.SharedStorageService = load("src/server/Services/SharedStorageService.luau")
	modules.StorageTransferService = load("src/server/Services/StorageTransferService.luau")
	modules.Remotes, modules.Sfx, modules.Strings, modules.CollisionGroups = {}, {}, {}, {}
	f.drop = load("src/server/Services/ItemDropService.luau", function(source)
		return source:gsub(
			"return ItemDropService%s*$",
			"ItemDropService.Spawn = onWorldDrop; return onDropItem"
		)
	end)
	f.actor.Character = {
		FindFirstChild = function()
			return {
				IsA = function()
					return true
				end,
				Position = rb.Vector3.zero,
				CFrame = rb.CFrame.new(),
			}
		end,
		FindFirstChildOfClass = function()
			return { Health = 100 }
		end,
	}
	f.record, f.storage, f.transfers, f.inventory =
		modules.SharedStorageRecord,
		modules.SharedStorageService,
		modules.StorageTransferService,
		modules.InventoryService
	function f:rejoin()
		self.live = copy(self.disk)
		self.tasks = {}
		self.saveFaults = nil
		self.onSave = nil
		-- A real restart creates new service busy/cache state too.
		modules.SharedStorageService = load("src/server/Services/SharedStorageService.luau")
		modules.StorageTransferService = load("src/server/Services/StorageTransferService.luau")
		self.storage, self.transfers = modules.SharedStorageService, modules.StorageTransferService
	end
	function f:resolve()
		self.transfers.Resolve(self.actor)
	end
	function f:begin(before, after, page, revision, coins)
		return self.transfers.Begin(
			self.actor,
			"gang",
			"guild",
			1,
			revision or 0,
			before,
			after,
			page,
			coins or 0
		)
	end
	return f
end
local X =
	{ id = "ancient_book", count = 1, books = { { id = "hammer", level = 3 } }, applyChance = 73 }
local function amount(slots, id)
	local n = 0
	for _, stack in slots or {} do
		if stack.id == id then
			n += stack.count
		end
	end
	return n
end
local function owned(f, id)
	local n = amount(f.disk.inventory, id)
	local op = f.disk.storageTransfer
	if op then
		if op.phase == "prepared" then
			local receipt = f.stores.GangChest_v1.guild.receipts[op.id]
			n += amount(
				if receipt and receipt.committed then op.afterInventory else op.beforeInventory,
				id
			)
		elseif op.phase == "delivering" then
			n += amount(op.remaining, id)
		end
	end
	for _, page in f.stores.GangChest_v1.guild.pages do
		n += amount(page, id)
	end
	return n
end

local f = fixture({ [1] = X })
f.saveFaults = { [1] = "before" }
f:begin(copy(f.live.inventory), {}, { [1] = X })
f:resolve()
check("failed escrow save cannot write outside profile", f.calls == 0 and owned(f, X.id) == 1)
f:rejoin()
f:resolve()
check("pre-escrow crash retains original item once", amount(f.live.inventory, X.id) == 1)

for _, fault in { "before", "after" } do
	f = fixture({ [1] = X })
	f.updateFault = fault
	f:begin(copy(f.live.inventory), {}, { [1] = X })
	f:resolve()
	check(
		"uncertain deposit keeps durable escrow " .. fault,
		f.disk.storageTransfer.phase == "prepared" and owned(f, X.id) == 1
	)
	f:rejoin()
	f:resolve()
	check(
		"uncertain deposit recovers exactly once " .. fault,
		owned(f, X.id) == 1
			and amount(f.live.inventory, X.id) == 0
			and f.live.storageTransfer == nil
	)
	f:resolve()
	check("deposit recovery replay does not duplicate " .. fault, owned(f, X.id) == 1)
end

for _, fault in { "before", "after" } do
	f = fixture({}, { ["1"] = { ["1"] = X } })
	f.saveFaults = { [2] = fault }
	f:begin({}, { [1] = X }, {})
	f:resolve()
	check("delivery-save uncertainty retains one durable owner " .. fault, owned(f, X.id) == 1)
	check(
		"uncertain durable grant is not visible before acknowledgement " .. fault,
		amount(f.live.inventory, X.id) == 0
	)
	f:rejoin()
	f:resolve()
	check(
		"delivery marker recovery grants item once " .. fault,
		amount(f.live.inventory, X.id) == 1
			and f.live.storageTransfer == nil
			and owned(f, X.id) == 1
	)
	check(
		"book metadata survives recovery " .. fault,
		f.live.inventory[1].books[1].level == 3 and f.live.inventory[1].applyChance == 73
	)
end

for _, fault in { "before", "after" } do
	f = fixture({}, { ["1"] = { ["1"] = X } })
	f.saveFaults = { [3] = fault }
	f:begin({}, { [1] = X }, {})
	f:resolve()
	check(
		"confirmed grant survives final marker-save failure " .. fault,
		f.live.storageTransfer.phase == "delivered"
			and owned(f, X.id) == 1
			and amount(f.live.inventory, X.id) == 1
	)
	f:rejoin()
	f:resolve()
	check(
		"final marker-save recovery never reapplies grant " .. fault,
		owned(f, X.id) == 1
			and amount(f.live.inventory, X.id) == 1
			and f.live.storageTransfer == nil
	)

	f = fixture({}, { ["1"] = { ["1"] = { id = "money_bag", count = 1, coins = 500 } } })
	f.saveFaults = { [2] = fault }
	f:begin({}, {}, {}, 0, 500)
	f:resolve()
	check("unconfirmed currency delivery remains unspendable " .. fault, f.live.coins == 0)
	f:rejoin()
	f:resolve()
	f:resolve()
	check(
		"currency delivery recovery credits exactly once " .. fault,
		f.live.coins == 500 and f.disk.coins == 500 and f.live.storageTransfer == nil
	)
end

f = fixture({ [1] = X })
local other =
	{ id = "other", page = 1, revision = 0, afterPage = { ["1"] = { id = "apple", count = 1 } } }
check("other writer wins initial page revision", f.storage.Commit("gang", "guild", other) == true)
f:begin(copy(f.live.inventory), {}, { [1] = X })
f:resolve()
check(
	"CAS loser gets original escrow back",
	amount(f.live.inventory, X.id) == 1
		and amount(f.stores.GangChest_v1.guild.pages["1"], "apple") == 1
)
check(
	"committed op retry is idempotent",
	f.storage.Commit("gang", "guild", other) == true
		and f.stores.GangChest_v1.guild.revisions["1"] == 1
)
f.storage.Acknowledge("gang", "guild", "other")
check(
	"late transform cannot replay after receipt cleanup",
	f.storage.Commit("gang", "guild", other) == false
		and f.stores.GangChest_v1.guild.revisions["1"] == 1
)

f = fixture({ [1] = X })
f.retryWith = {
	pages = { ["1"] = { ["1"] = { id = "apple", count = 1 } } },
	revisions = { ["1"] = 1 },
	receipts = {},
}
f:begin(copy(f.live.inventory), {}, { [1] = X })
f:resolve()
check(
	"UpdateAsync conflict callback retry uses final CAS outcome",
	amount(f.live.inventory, X.id) == 1
		and f.stores.GangChest_v1.guild.pages["1"]["1"].id == "apple"
)
local second = { id = "secondPage", page = 2, revision = 0, afterPage = { ["1"] = X } }
check(
	"independent page write preserves other writer page",
	f.storage.Commit("gang", "guild", second) == true
		and f.stores.GangChest_v1.guild.pages["1"]["1"].id == "apple"
		and f.stores.GangChest_v1.guild.pages["2"]["1"].applyChance == 73
)
f.stores.FactionStorage_v1.red =
	{ ["1"] = { ["1"] = X }, ["8"] = { ["27"] = { id = "apple", count = 3 } } }
local legacy = f.storage.Snapshot("faction", "red", 1)
check("legacy faction record reads without losing metadata", legacy[1].applyChance == 73)
local legacyOp = { id = "legacy", page = 1, revision = 0, afterPage = {} }
check(
	"legacy faction CAS migration preserves untouched pages",
	f.storage.Commit("faction", "red", legacyOp) == true
		and f.stores.FactionStorage_v1.red.pages["8"]["27"].count == 3
)

f = fixture({}, { ["1"] = { ["1"] = X } })
f.onSave = function(n)
	if n == 1 then
		for slot = 1, 36 do
			f.live.inventory[slot] =
				{ id = "pickaxe", count = 1, level = slot % 16 + 1, books = {} }
		end
	end
end
f:begin({}, { [1] = X }, {})
f:resolve()
check(
	"full bag retains pending ownership",
	f.live.storageTransfer.phase == "delivering"
		and amount(f.live.storageTransfer.remaining, X.id) == 1
		and owned(f, X.id) == 1
)
f:rejoin()
f.live.inventory[9] = nil
f:resolve()
check(
	"pending item delivered after freeing space without metadata loss",
	f.live.inventory[9].id == X.id
		and f.live.inventory[9].applyChance == 73
		and f.live.storageTransfer == nil
)

f = fixture({}, { ["1"] = { ["1"] = X } })
f.onSave = function(n)
	if n == 2 then
		for slot = 1, 36 do
			f.live.inventory[slot] = { id = "pickaxe", count = 1, level = 1 }
		end
	end
end
f:begin({}, { [1] = X }, {})
f:resolve()
check(
	"bag filling during grant write preserves pending ownership",
	f.live.storageTransfer.phase == "delivering"
		and owned(f, X.id) == 1
		and amount(f.live.inventory, X.id) == 0
)
f:rejoin()
f.live.inventory[4] = nil
f:resolve()
check(
	"concurrent full bag resumes exact grant after rejoin",
	f.live.storageTransfer == nil and amount(f.live.inventory, X.id) == 1 and owned(f, X.id) == 1
)

f = fixture({}, { ["1"] = { ["1"] = X } })
f.onSave = function(n)
	if n == 2 then
		local otherBook = copy(X)
		otherBook.books[1].level = 1
		otherBook.applyChance = 24
		f.live.inventory[1] = otherBook
	end
end
f:begin({}, { [1] = X }, {})
f:resolve()
check(
	"changed slot metadata is never overwritten by delivery",
	f.live.inventory[1].books[1].level == 1
		and f.live.inventory[1].applyChance == 24
		and f.live.inventory[2].books[1].level == 3
		and f.live.inventory[2].applyChance == 73
)

f = fixture({}, { ["1"] = { ["1"] = X } })
local page = f.storage.Snapshot("gang", "guild", 1)
page[1].books[1].level = 1
check(
	"page snapshot cannot mutate durable metadata",
	f.stores.GangChest_v1.guild.pages["1"]["1"].books[1].level == 3
)
f.readFail = true
check(
	"failed read is unavailable rather than empty writable data",
	f.storage.Read("gang", "guild", true) == nil
)
check("failed read performs no writes", f.calls == 0)

-- Critical boundary: after a failed delivery save, can a spendable item escape to another profile?
f = fixture({}, { ["1"] = { ["1"] = X } })
f.saveFaults = { [2] = "before" }
f:begin({}, { [1] = X }, {})
f:resolve()
-- Actual DropItem handler: world spawn is the only replaced boundary, records external ownership.
f.drop(f.actor, 1)
check(
	"pending delivery refuses real DropItem export",
	(f.escaped or 0) == 0 and amount(f.live.inventory, X.id) == 0
)
f:rejoin()
f:resolve()
check(
	"failed delivery cannot expose a replayable transferable item",
	(f.escaped or 0) + owned(f, X.id) == 1
)
f.drop(f.actor, 1)
check(
	"resolved delivery resumes ordinary world export",
	f.escaped == 1 and amount(f.live.inventory, X.id) == 0
)

-- The actual ProfileService durable checkpoint, including deep serialization and exact lock fencing.
local function profileFixture(fault, lock)
	local state = {
		writes = 0,
		live = {
			coins = 0,
			inventory = {},
			enderChest = {},
			artifacts = {},
			caseContents = {},
			locale = "en",
			selectedSlot = 1,
		},
	}
	state.disk = {
		_lock = if lock == false then nil else lock or { job = "offline", token = "token", at = 1 },
	}
	local names = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
	local modules = { Types = {}, Remotes = {}, Wire = {}, Boosters = {}, Config = {}, Vault = {} }
	local function load(path, transform)
		local source = fs.readFile(path)
		if transform then
			source = transform(source)
		end
		local fn = assert(loadstring(source, "@" .. path))
		setfenv(
			fn,
			setmetatable({
				game = {
					JobId = "offline",
					GetService = function(_, name)
						return if name == "ReplicatedStorage"
							then {
								Shared = names,
								WaitForChild = function()
									return names
								end,
							}
							else {}
					end,
				},
				script = { Parent = names },
				require = function(key)
					return assert(modules[key], key)
				end,
				warn = function() end,
				task = {
					wait = function()
						error("Unexpected overlap")
					end,
				},
			}, { __index = env })
		)
		return fn()
	end
	modules.Persistence = load("src/shared/Persistence.luau")
	modules.Numbers = load("src/shared/Numbers.luau")
	local profile = load("src/server/Services/ProfileService.luau", function(source)
		return source:gsub(
			"return ProfileService%s*$",
			[[
return { Service = ProfileService, configure = function(player, p, ds)
	store = ds
	sessions[player] = { profile = p, loadFailed = false, saving = false, dirty = true, token = "token" }
end }
]]
		)
	end)
	state.actor = { UserId = 71, Name = "Offline", SetAttribute = function() end }
	state.store = {
		UpdateAsync = function(_, _, transform)
			state.writes += 1
			if fault == "before" then
				error("Before write")
			end
			local changed = transform(copy(state.disk))
			if state.onWrite then
				state.onWrite()
			end
			if changed then
				state.disk = copy(changed)
			end
			if fault == "after" then
				error("After write, acknowledgement lost")
			end
			return copy(changed)
		end,
	}
	profile.configure(state.actor, state.live, state.store)
	state.profile = profile.Service
	return state
end
for _, fault in { "before", "after" } do
	local s = profileFixture(fault)
	local ok = s.profile.MutateDurable(s.actor, function(p)
		p.inventory[1] = copy(X)
		p.coins += 50
	end)
	check(
		"actual Profile.MutateDurable failed acknowledgement does not publish " .. fault,
		not ok and s.live.inventory[1] == nil and s.live.coins == 0
	)
	check(
		"actual Profile.MutateDurable durable write outcome " .. fault,
		if fault == "before"
			then s.disk.inventory == nil
			else s.disk.inventory["1"].id == X.id and s.disk.coins == 50
	)
end
local s = profileFixture()
local ok = s.profile.MutateDurable(s.actor, function(p)
	p.inventory[1] = copy(X)
	p.coins += 50
end)
check(
	"actual confirmed durable grant publishes once",
	ok and s.live.coins == 50 and s.disk.coins == 50 and s.live.inventory[1].applyChance == 73
)
s = profileFixture()
s.live.inventory[2] = copy(X)
s.onWrite = function()
	s.live.inventory[2].books[1].level = 1
	s.live.inventory[3] = { id = "apple", count = 1 }
end
ok = s.profile.MutateDurable(s.actor, function(p)
	p.coins += 50
end)
check(
	"durable snapshot never aliases concurrent live metadata",
	ok and s.disk.inventory["2"].books[1].level == 3 and s.live.inventory[2].books[1].level == 1
)
check(
	"confirmed transform preserves concurrent live inventory additions",
	s.live.inventory[3].id == "apple" and s.live.coins == 50
)
for _, lock in
	{
		false,
		{},
		{ job = "offline", token = "successor", at = 1 },
		{ job = "other", token = "token", at = 1 },
	}
do
	s = profileFixture(nil, lock)
	ok = s.profile.MutateDurable(s.actor, function(p)
		p.inventory[1] = copy(X)
	end)
	check(
		"actual profile fencing refuses obsolete owner "
			.. (
				if lock == false
					then "missing lock"
					else tostring(lock.job) .. "/" .. tostring(lock.token)
			),
		not ok and s.live.inventory[1] == nil and s.disk.inventory == nil
	)
end

print(serde.encode("json", {
	checks = checks,
	passed = #checks - #failures,
	failures = failures,
	realDataStores = false,
	realProfiles = false,
}, true))
assert(#failures == 0, "Storage regressions: " .. table.concat(failures, ", "))
