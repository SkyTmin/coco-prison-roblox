--!nocheck
-- Actual DeathService, isolated durable-profile and ephemeral-world mocks. No Studio.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local env = getfenv()
local checks = 0
local function check(name, ok)
	checks += 1
	assert(ok, name)
end
local function copy(v)
	if type(v) ~= "table" then
		return v
	end
	local out = {}
	for k, x in v do
		out[k] = copy(x)
	end
	return out
end
local function count(stacks, id)
	local n = 0
	for _, s in stacks or {} do
		if s.id == id then
			n += s.count
		end
	end
	return n
end
local function fixture()
	local f = { emitted = {}, queued = {}, attrs = {}, warnings = {}, online = true }
	f.player = {
		UserId = 1,
		Name = "Victim",
		DisplayName = "Victim",
		SetAttribute = function(_, k, v)
			f.attrs[k] = v
		end,
	}
	f.killer = { UserId = 2, Name = "Killer", DisplayName = "Killer" }
	f.live = {
		inventory = {
			[1] = { id = "apple", count = 3 },
			[2] = { id = "pickaxe", count = 1, level = 1 },
		},
		stats = {},
		coins = 50000,
		level = 2,
		location = "prison",
		storageTransfer = { id = "op", phase = "prepared" },
	}
	f.other = { coins = 0, stats = {} }
	f.disk = copy(f.live)
	local names = setmetatable({}, {
		__index = function(_, k)
			return k
		end,
	})
	local modules = {
		Types = {},
		Config = {
			moneyScale = 10000,
			tools = { pickaxe = {} },
			rules = { survival = { death = { dropInPvpOnly = false } } },
			location = function()
				return { pvp = true }
			end,
		},
		GangService = { progress = function() end },
		ItemDropService = {
			SpawnLoot = function(stack)
				table.insert(f.emitted, copy(stack))
			end,
		},
		Remotes = {
			event = function()
				return { FireClient = function() end }
			end,
		},
		Strings = {
			money = tostring,
			localeOf = function()
				return "en"
			end,
			t = function(k)
				return k
			end,
		},
	}
	local services = {
		CollectionService = {},
		Players = {
			GetPlayerByUserId = function(_, id)
				return if id == 2 and f.online then f.killer else nil
			end,
		},
		HttpService = {
			GenerateGUID = function()
				f.guid = (f.guid or 0) + 1
				return "death" .. f.guid
			end,
		},
		ReplicatedStorage = {
			Shared = names,
			WaitForChild = function()
				return names
			end,
		},
	}
	modules.ProfileService = {
		Get = function(player)
			return if player == f.player then f.live else f.other
		end,
		IsReal = function(player)
			return player == f.player or f.online
		end,
		Mutate = function(player, fn)
			fn(if player == f.player then f.live else f.other)
		end,
		SaveNow = function()
			f.disk = copy(f.live)
			return true
		end,
		OnLoaded = function() end,
		MutateDurable = function(_, transform)
			local staged = copy(f.live)
			transform(staged)
			local fault = f.fault
			f.fault = nil
			if fault == "before" then
				return false
			end
			f.disk = copy(staged)
			if f.duringSave then
				local fn = f.duringSave
				f.duringSave = nil
				fn()
			end
			if fault == "after" then
				return false
			end
			transform(f.live)
			return true
		end,
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
				workspace = {},
				script = { Parent = names },
				require = function(k)
					return assert(modules[k], k)
				end,
				Vector3 = rb.Vector3,
				task = {
					spawn = function(fn, ...)
						table.insert(f.queued, { fn, ... })
					end,
				},
				os = {
					clock = function()
						return 100
					end,
				},
				warn = function(message)
					table.insert(f.warnings, message)
				end,
			}, { __index = env })
		)
		return fn()
	end
	modules.Numbers = load("src/shared/Numbers.luau")
	modules.Persistence = load("src/shared/Persistence.luau")
	f.death = load("src/server/Services/DeathService.luau", function(source)
		return source:gsub(
			"return DeathService%s*$",
			"DeathService._died = died; DeathService._resolve = resolve; return DeathService"
		)
	end)
	f.character = {
		IsDescendantOf = function()
			return true
		end,
		FindFirstChildOfClass = function()
			return {
				GetAttribute = function(_, k)
					return if k == "LastHitBy" then 2 elseif k == "LastHitAt" then 100 else nil
				end,
			}
		end,
		FindFirstChild = function()
			return {
				Position = rb.Vector3.new(4, 5, 6),
				IsA = function()
					return true
				end,
			}
		end,
	}
	function f:die()
		self.death._died(self.player, self.character)
	end
	function f:resolve()
		self.death._resolve(self.player)
	end
	function f:ready()
		local remaining = {
			["1"] = {
				id = "ancient_book",
				count = 1,
				books = { { id = "hammer", level = 3 } },
				applyChance = 73,
			},
			["2"] = { id = "pickaxe", count = 1, level = 2 },
		}
		self.death.HoldTransfer(self.live, "op", remaining)
		self.live.storageTransfer = nil
		return remaining
	end
	return f
end

local f = fixture()
f:die()
f:resolve()
check(
	"pending transfer death emits neither world loot nor killer money",
	#f.emitted == 0 and f.other.coins == 0
)
check(
	"death captures live loot and money as profile-owned escrow",
	count(f.live.storageDeath.queue[1].drops, "apple") == 3
		and f.live.coins == 30000
		and f.live.storageDeath.queue[1].loss == 20000
)
check(
	"kept tools remain and busy stays visible",
	f.live.inventory[2].id == "pickaxe" and f.attrs.SharedStorageBusy == true
)
local remaining = f:ready()
check(
	"reserved droppable delivery goes to original death while kept tools still deliver",
	remaining["1"] == nil
		and remaining["2"].id == "pickaxe"
		and count(f.live.storageDeath.queue[1].drops, "ancient_book") == 1
)
f.live.inventory[3] = { id = "apple", count = 7 }
f:resolve()
check(
	"settlement consumes death durably before emitting loot",
	f.disk.storageDeath == nil
		and f.live.storageDeath == nil
		and count(f.emitted, "apple") == 3
		and count(f.emitted, "ancient_book") == 1
)
check("respawn-earned inventory is not captured by old death", f.live.inventory[3].count == 7)
check(
	"online killer receives escrow once and busy clears",
	f.other.coins == 20000 and f.attrs.SharedStorageBusy == false
)
f:resolve()
f.live = copy(f.disk)
f:resolve()
check(
	"retry and rejoin cannot replay consumed death",
	count(f.emitted, "apple") == 3 and f.other.coins == 20000
)

for _, fault in { "before", "after" } do
	f = fixture()
	f:die()
	f:ready()
	f.disk = copy(f.live)
	f.fault = fault
	f:resolve()
	check(
		"failed durable consume exports nothing " .. fault,
		#f.emitted == 0 and f.other.coins == 0
	)
	f.live = copy(f.disk)
	f:resolve()
	check(
		"rejoin after consume uncertainty never duplicates " .. fault,
		count(f.emitted, "apple") == (if fault == "before" then 3 else 0)
			and f.other.coins == (if fault == "before" then 20000 else 0)
	)
end

f = fixture()
f:die()
f:ready()
f.online = false
f:resolve()
check(
	"offline killer loss is refunded in durable consumption",
	f.live.coins == 50000 and f.disk.coins == 50000 and count(f.emitted, "apple") == 3
)

f = fixture()
f:die()
f:ready()
f.online = false
f.duringSave = function()
	f.live.coins = 9007199254740991
end
f:resolve()
check(
	"wallet filled during refund write retains escrow without exporting",
	f.live.coins == 9007199254740991 and f.live.storageDeath ~= nil and #f.emitted == 0
)
f.live.coins = 0
f:resolve()
check(
	"retained refund settles once when capacity is available",
	f.live.coins == 20000 and f.live.storageDeath == nil and count(f.emitted, "apple") == 3
)

f = fixture()
f:die()
f.live.inventory[3] = { id = "apple", count = 4 }
f:die()
check(
	"successive deaths own separate loot and only first owns pending transfer",
	#f.live.storageDeath.queue == 2
		and f.live.storageDeath.queue[1].transferId == "op"
		and f.live.storageDeath.queue[2].transferId == nil
)
f:ready()
f:resolve()
f:resolve()
check(
	"queued deaths settle separately with one reserved item",
	count(f.emitted, "apple") == 7
		and count(f.emitted, "ancient_book") == 1
		and f.other.coins == 40000
)

f = fixture()
f.live.storageTransfer = nil
f:die()
check(
	"ordinary non-pending death retains existing immediate behavior",
	count(f.emitted, "apple") == 3 and f.other.coins == 20000 and f.live.storageDeath == nil
)
print(
	string.format(
		"Death/storage integration PASS: %d actual-source checks; durable/world mocks, no Studio",
		checks
	)
)
