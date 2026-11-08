--!nocheck
-- lune run scripts/qa-profile-persistence-offline.luau
-- Actual ProfileService private boundaries exposed only in the loaded test chunk.
-- Real Persistence/Numbers/Inventory/StorageTransfer code; isolated DataStore, clock and players.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function copy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[key] = copy(child)
	end
	return result
end
local baseEnvironment = getfenv()
local function fixture(options)
	options = options or {}
	local f = {
		disk = {},
		clock = 1000,
		time = 100000,
		writes = 0,
		calls = 0,
		messages = {},
		tasks = {},
		warnings = {},
		actors = {},
		guid = 0,
		serverAttributes = {},
		studio = options.studio == true,
		testArgs = options.testArgs or "",
	}
	local names = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
	local modules = {
		CommercePolicyService = {
			CanTrade = function(actor)
				return actor.policyTrade ~= false
			end,
			RequireTrade = function(actor)
				return actor.policyTrade ~= false
			end,
		},
		Types = {},
		Remotes = {
			event = function(name)
				return {
					FireClient = function(_, actor, ...)
						table.insert(
							f.messages,
							{ remote = name, actor = actor, args = table.pack(...) }
						)
					end,
				}
			end,
		},
		Wire = { encode = copy },
		Boosters = { prune = function() end },
		Config = {
			chat = { giftRangeBlocks = 4 },
			rules = {
				combat = { blockStuds = 4 },
				survival = { hunger = { max = 20 } },
				ui = { locales = { "ru", "en", "es", "fr" }, defaultLocale = "ru" },
			},
			tools = { shovel = true, bow = true },
			faction = function()
				return nil
			end,
		},
		Vault = {
			SLOTS = 27,
			MAX = 3,
			unlocked = function(p)
				return p.vaultSections or 1
			end,
		},
		ItemEnchantment = {
			active = function()
				return false
			end,
		},
	}
	function f:advance(seconds)
		self.clock += seconds
		self.time += seconds
	end
	f.store = {
		GetAsync = function(_, key)
			return copy(f.disk[key])
		end,
		UpdateAsync = function(_, key, transform)
			f.calls += 1
			if f.beforeUpdate then
				f.beforeUpdate(key)
			end
			local updated = transform(copy(f.disk[key]))
			if updated ~= nil then
				f.disk[key] = copy(updated)
				f.writes += 1
			end
			if f.afterUpdate then
				f.afterUpdate(key, updated)
			end
			return copy(updated)
		end,
	}
	local services = {
		DataStoreService = {
			GetDataStore = function(_, name, scope)
				if scope then
					local prefix = name .. "@" .. scope .. "/"
					return {
						GetAsync = function(_, key)
							return f.store:GetAsync(prefix .. key)
						end,
						UpdateAsync = function(_, key, change)
							return f.store:UpdateAsync(prefix .. key, change)
						end,
					}
				end
				return f.store
			end,
		},
		MessagingService = {
			PublishAsync = function(_, topic, data)
				table.insert(f.messages, { topic, copy(data) })
			end,
		},
		Players = {
			GetPlayers = function()
				return f.actors
			end,
			GetPlayerByUserId = function(_, id)
				for _, actor in f.actors do
					if actor.UserId == id and actor.Parent then
						return actor
					end
				end
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
				return f.studio
			end,
		},
		HttpService = {
			GenerateGUID = function()
				f.guid += 1
				return (options.runName or "test-guid") .. "-" .. f.guid
			end,
		},
		StudioTestService = {
			GetTestArgs = function()
				return f.testArgs
			end,
		},
		ServerStorage = {
			SetAttribute = function(_, key, value)
				f.serverAttributes[key] = value
			end,
		},
	}
	local function load(path, job, instrument)
		local source = fs.readFile(path)
		if instrument then
			source = instrument(source)
		end
		local fn = assert(loadstring(source, "@" .. path))
		setfenv(
			fn,
			setmetatable({
				workspace = {
					GetServerTimeNow = function()
						return f.clock
					end,
				},
				game = {
					JobId = job or "A",
					GetService = function(_, name)
						return assert(services[name], name)
					end,
				},
				script = { Parent = names },
				require = function(name)
					return assert(modules[name], name)
				end,
				os = {
					time = function()
						return f.time
					end,
					clock = function()
						return f.clock
					end,
				},
				task = {
					wait = function(seconds)
						f:advance(seconds)
					end,
					spawn = function(fn, ...)
						table.insert(f.tasks, { fn = fn, args = table.pack(...) })
					end,
					defer = function(fn, ...)
						table.insert(f.tasks, { fn = fn, args = table.pack(...) })
					end,
				},
				warn = function(...)
					table.insert(f.warnings, table.pack(...))
				end,
			}, { __index = baseEnvironment })
		)
		return fn()
	end
	modules.Persistence = load("src/shared/Persistence.luau")
	modules.StorageNames = load("src/shared/StorageNames.luau")
	f.storageNames = modules.StorageNames
	modules.TestSessionScope = load("src/server/Services/TestSessionScope.luau")
	modules.Numbers = load("src/shared/Numbers.luau")
	modules.TransferAccess = load("src/shared/TransferAccess.luau")
	modules.Selling = load("src/shared/Selling.luau")
	modules.Tutorial = load("src/shared/Tutorial.luau")
	modules.ProgressReset = load("src/shared/ProgressReset.luau")
	modules.Config.donate = { items = { fixturePaidKey = { give = "ancient_key" } } }
	modules.Strings = {
		t = function(key)
			return key
		end,
		localeOf = function()
			return "en"
		end,
	}
	modules.InventoryService = load("src/server/Services/InventoryService.luau")
	function f:profile(job)
		local boundary = load("src/server/Services/ProfileService.luau", job, function(source)
			local exposed, n = source:gsub(
				"return ProfileService%s*$",
				[[
return {
 service = ProfileService, acquire = acquire, save = save, migrate = migrate, load = load, flush = flushReplication,
 storeName = STORE_NAME, releaseTopic = RELEASE_TOPIC,
 sessions = sessions, setStore = function(value) store = value end,
}
]]
			)
			assert(n == 1, "ProfileService return seam changed")
			return exposed
		end)
		boundary.setStore(self.store)
		return boundary
	end
	function f:player()
		local actor = {
			UserId = 42,
			Name = "IsolatedProfileFixture",
			Parent = true,
			attributes = {},
			kicks = {},
		}
		actor.GetAttribute = function(_, key)
			return actor.attributes[key]
		end
		actor.SetAttribute = function(_, key, value)
			actor.attributes[key] = value
		end
		actor.Kick = function(_, reason)
			table.insert(actor.kicks, reason)
		end
		table.insert(f.actors, actor)
		return actor
	end
	function f:session(boundary, actor, token, seed)
		local ok, stored = boundary.acquire(actor, token)
		assert(ok, "fixture session acquisition")
		local session = {
			profile = seed or boundary.migrate(stored),
			token = token,
			loadFailed = false,
			dirty = true,
			saving = false,
		}
		boundary.sessions[actor] = session
		return session
	end
	function f:transfers(boundary)
		modules.ProfileService = boundary.service
		modules.SharedStorageService = {
			Acknowledge = function() end,
			Commit = function()
				error("delivery test must not enter external chest commit")
			end,
		}
		modules.SharedStorageRecord = {}
		return load("src/server/Services/StorageTransferService.luau")
	end
	function f:playerTransfers(boundary)
		for _, actor in self.actors do
			if not actor.Character then
				local attributes = {}
				local root = {
					Position = rb.Vector3.zero,
					IsA = function()
						return true
					end,
				}
				local humanoid = { Health = 20 }
				actor.Character = {
					root = root,
					humanoid = humanoid,
					FindFirstChild = function(_, name)
						return if name == "HumanoidRootPart" then root else nil
					end,
					FindFirstChildOfClass = function(_, name)
						return if name == "Humanoid" then humanoid else nil
					end,
					GetAttribute = function(_, key)
						return attributes[key]
					end,
					SetAttribute = function(_, key, value)
						attributes[key] = value
					end,
				}
			end
		end
		modules.ProfileService = boundary.service
		modules.Remotes.event = function()
			return {
				FireClient = function(_, actor, message)
					table.insert(f.messages, { actor.UserId, message })
				end,
			}
		end
		local boundaryTransfer = load(
			"src/server/Services/PlayerTransferService.luau",
			nil,
			function(source)
				return source:gsub(
					"return Transfer%s*$",
					"return {service=Transfer,setInbox=function(value) inbox=value end}"
				)
			end
		)
		boundaryTransfer.setInbox(f.store)
		return boundaryTransfer.service
	end
	return f
end

-- Exact acquisition ownership: stale server A must not save even after B released its lock.
local f = fixture()
local actor = f:player()
local a, b = f:profile("A"), f:profile("B")
local sessionA = f:session(a, actor, "A-token")
sessionA.profile.coins = 10
check("A initial save succeeds", a.save(actor, sessionA, false))
f:advance(301)
local sessionB = f:session(b, actor, "B-token")
sessionB.profile.coins = 20
check("B stale-lock takeover and release succeed", b.save(actor, sessionB, true))
check("B released the stored lock", f.disk.User_42._lock == nil)
local writes = f.writes
sessionA.profile.coins = 999
check("A stale save after B release is rejected", not a.save(actor, sessionA, false))
check("A cannot overwrite B released data", f.disk.User_42.coins == 20 and f.writes == writes)
check("lost ownership freezes A and kicks actor", sessionA.loadFailed and #actor.kicks == 1)
local staleRelease = {
	profile = sessionA.profile,
	token = "A-token",
	loadFailed = false,
	dirty = true,
	saving = false,
}
check(
	"A stale release with nil stored lock is rejected",
	not a.save(actor, staleRelease, true) and f.writes == writes
)

f = fixture()
actor = f:player()
a, b = f:profile("same-job"), f:profile("same-job")
sessionA = f:session(a, actor, "old-acquisition")
local acquired, why = b.acquire(actor, "new-acquisition")
check("same job with different token cannot acquire fresh lock", not acquired and why == "locked")
check("blocked acquisition asks owner once", #f.messages == 1)
check("blocked acquisition retains exact token", f.disk.User_42._lock.token == "old-acquisition")
f.disk.User_42._lock.token = "new-acquisition"
check("same-job stale-token save is rejected", not a.save(actor, sessionA, false))
check(
	"same-job stale-token rejection preserves current lock",
	f.disk.User_42._lock.token == "new-acquisition"
)

-- Snapshot must be taken deeply before UpdateAsync yields, including nested item metadata.
f = fixture()
actor = f:player()
a = f:profile("A")
sessionA = f:session(a, actor, "snapshot")
local p = sessionA.profile
p.inventory = { [1] = { id = "ancient_book", count = 1, books = { { id = "hammer", level = 3 } } } }
p.enderChest = { [1] = { id = "stone", count = 2 } }
p.caseContents = {
	ancientCase = {
		[1] = { id = "ancient_book", count = 1, books = { { id = "speed", level = 2 } } },
	},
}
p.artifacts = { common = { fragments = { [1] = 2 }, duplicates = 3, completed = 0 } }
p.stats = { nested = { value = 5 } }
f.beforeUpdate = function()
	f.beforeUpdate = nil
	coroutine.yield("snapshot-await")
end
local thread = coroutine.create(function()
	return a.service.SaveNow(actor)
end)
local ok, result = coroutine.resume(thread)
check(
	"SaveNow yields inside real UpdateAsync boundary",
	ok and result == "snapshot-await" and sessionA.saving
)
a.service.Mutate(actor, function(live)
	live.inventory[1].books[1].level = 99
	live.enderChest[1].count = 9
	live.caseContents.ancientCase[1].books[1].level = 9
	live.artifacts.common.fragments[1] = 9
	live.stats.nested.value = 9
	live.coins = 77
end)
ok, result = coroutine.resume(thread)
check("snapshot save completes", ok and result == true and coroutine.status(thread) == "dead")
local disk = f.disk.User_42
check("saved nested inventory metadata is immutable", disk.inventory["1"].books[1].level == 3)
check(
	"saved ender/case data is immutable",
	disk.enderChest["1"].count == 2 and disk.caseContents.ancientCase["1"].books[1].level == 2
)
check(
	"saved artifact fragments and arbitrary nested tables are immutable",
	disk.artifacts.common.fragments["1"] == 2 and disk.stats.nested.value == 5
)
check(
	"live mutations during save survive and remain dirty",
	p.coins == 77 and p.inventory[1].books[1].level == 99 and sessionA.dirty
)

local reward =
	{ id = "ancient_book", count = 1, books = { { id = "hammer", level = 3 } }, applyChance = 73 }
local function deliveryFixture()
	local current = fixture()
	local currentActor = current:player()
	local boundary = current:profile("A")
	local session = current:session(boundary, currentActor, "delivery")
	session.profile.inventory = {}
	session.profile.storageTransfer = {
		id = "delivery-id",
		kind = "gang",
		key = "fixture",
		phase = "delivering",
		remaining = { ["2"] = copy(reward) },
		coins = 11,
	}
	return current, currentActor, boundary, session, current:transfers(boundary)
end
local function amount(inventory, id)
	local n = 0
	for _, stack in inventory do
		if stack.id == id then
			n += stack.count
		end
	end
	return n
end

-- Exercise the real storage transform through the real MutateDurable/save implementation.
local transfers
f, actor, a, sessionA, transfers = deliveryFixture()
f.afterUpdate = function()
	f.afterUpdate = nil
	coroutine.yield("applied-await-ack")
end
thread = coroutine.create(function()
	transfers.Resolve(actor)
end)
ok, result = coroutine.resume(thread)
check(
	"durable checkpoint can apply while acknowledgement is outstanding",
	ok and result == "applied-await-ack"
)
check(
	"confirmed grant is not spendable before save acknowledgement",
	amount(sessionA.profile.inventory, reward.id) == 0 and sessionA.profile.coins == 0
)
check("pending checkpoint blocks item export", not a.service.CanExport(actor))
check(
	"staged checkpoint has reward and delivered marker",
	amount(f.disk.User_42.inventory, reward.id) == 1
		and f.disk.User_42.storageTransfer.phase == "delivered"
)
a.service.Mutate(actor, function(live)
	live.inventory[2] = { id = "arrow", count = 7 }
end)
ok, result = coroutine.resume(thread)
check("delivery completes after acknowledgement", ok and coroutine.status(thread) == "dead")
check(
	"concurrent occupied slot is preserved",
	sessionA.profile.inventory[2].id == "arrow" and sessionA.profile.inventory[2].count == 7
)
check(
	"actual delivery transform merges reward into a free slot once",
	amount(sessionA.profile.inventory, reward.id) == 1 and sessionA.profile.coins == 11
)
check(
	"final save captures concurrent inventory and grant once",
	amount(f.disk.User_42.inventory, "arrow") == 7
		and amount(f.disk.User_42.inventory, reward.id) == 1
		and f.disk.User_42.coins == 11
)
check(
	"confirmed delivery clears busy/export gate",
	actor.attributes.SharedStorageBusy == false and a.service.CanExport(actor)
)

for _, fault in { "before", "after" } do
	f, actor, a, sessionA, transfers = deliveryFixture()
	if fault == "before" then
		f.beforeUpdate = function()
			f.beforeUpdate = nil
			error("injected before-commit error")
		end
	else
		f.afterUpdate = function()
			f.afterUpdate = nil
			error("injected applied-but-error")
		end
	end
	transfers.Resolve(actor)
	check(
		fault .. " error never publishes an unconfirmed grant",
		amount(sessionA.profile.inventory, reward.id) == 0 and sessionA.profile.coins == 0
	)
	check(
		fault .. " error leaves durable export gate closed",
		not a.service.CanExport(actor) and actor.attributes.SharedStorageBusy == true
	)
	if fault == "after" then
		check(
			"applied-but-error persisted exactly one grant",
			amount(f.disk.User_42.inventory, reward.id) == 1
				and f.disk.User_42.storageTransfer.phase == "delivered"
		)
	end
	transfers.Resolve(actor)
	check(
		fault .. " retry grants exactly once",
		amount(sessionA.profile.inventory, reward.id) == 1
			and amount(f.disk.User_42.inventory, reward.id) == 1
			and sessionA.profile.coins == 11
	)
end

-- Rejoin after a lost response must read the persisted delivered marker, not pay again.
f, actor, a, sessionA, transfers = deliveryFixture()
f.afterUpdate = function()
	f.afterUpdate = nil
	error("lost acknowledgement before crash")
end
transfers.Resolve(actor)
f:advance(301)
b = f:profile("B")
sessionB = f:session(b, actor, "rejoin")
f:transfers(b).Resolve(actor)
check(
	"rejoin of applied-but-error keeps one durable grant",
	amount(sessionB.profile.inventory, reward.id) == 1 and sessionB.profile.coins == 11
)
check(
	"rejoin clears delivered marker without replay",
	sessionB.profile.storageTransfer == nil and amount(f.disk.User_42.inventory, reward.id) == 1
)

-- Migration retains earned-but-unclaimed tiers for AchievementService catch-up.
f = fixture()
a = f:profile("A")
local seed = a.service.defaultProfile()
seed.counters = { ["Песок"] = 4096 }
seed.dug = { stone = 4096, dirt = 4096 }
seed.achievements = { ["Песок"] = 1, stone = 2 }
seed.coins = 19
local migrated = a.migrate(copy(seed))
check(
	"migration preserves explicit claimed tiers",
	migrated.achievements["Песок"] == 1 and migrated.achievements.stone == 2
)
check("migration does not mark missing crossed tier paid", migrated.achievements.dirt == nil)
check(
	"migration retains progress without inventing payout",
	migrated.dug.dirt == 4096 and migrated.counters["Песок"] == 4096 and migrated.coins == 19
)

print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualProfileService = true,
	actualStorageTransform = true,
	realProfiles = false,
	realDataStores = false,
}, true))

return { fixture = fixture }
