--!nocheck
-- Actual StorageNames and LeaderboardService, isolated stores/players/GUI tree. No Studio/cloud calls.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function storageNames(studio)
	local calls = 0
	local fn = assert(loadstring(fs.readFile("src/shared/StorageNames.luau")))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, id)
					assert(id == "RunService")
					return {
						IsStudio = function()
							calls += 1
							return studio
						end,
					}
				end,
			},
		}, { __index = getfenv() })
	)
	local result = fn()
	check("Studio detection happens once " .. tostring(studio), calls == 1)
	return result
end
local live, studio = storageNames(false), storageNames(true)
check("explicit release epoch", live.ProductionDataEpoch == "release1_20261103")
check(
	"receipt lookup keeps exact archived profile name",
	live.LegacyProfileStore == "PlayerProfiles_v3"
)
for kind, bases in live.catalog do
	local seen = {}
	for _, base in bases do
		local a, b = live.progress(base), studio.progress(base)
		check(
			kind .. ": " .. base .. " old/live/studio isolated",
			a ~= base and b ~= base and a ~= b
		)
		check(kind .. ": " .. base .. " safe platform name length", #a <= 50 and #b <= 50)
		check(kind .. ": " .. base .. " unique within service", not seen[a] and not seen[b])
		seen[a], seen[b] = true, true
	end
end
local function signal()
	return { Connect = function() end }
end
local function node(class)
	local children, p = {}, {}
	local n = { ClassName = class }
	function n:GetChildren()
		return children
	end
	function n:FindFirstChild(name)
		for _, child in children do
			if child.Name == name then
				return child
			end
		end
	end
	function n:IsA(kind)
		return kind == class
	end
	return setmetatable(n, {
		__index = p,
		__newindex = function(self, key, value)
			if key == "Parent" then
				p.Parent = value
				table.insert(value:GetChildren(), self)
			else
				rawset(self, key, value)
			end
		end,
	})
end
local function fixture(studioMode)
	local f =
		{ studio = studioMode, players = {}, profiles = {}, data = {}, acquired = {}, writes = 0 }
	local Names = storageNames(studioMode)
	f.names = Names
	local Profile = {
		Get = function(player)
			return f.profiles[player.UserId]
		end,
		IsReal = function(player)
			return player.real ~= false
		end,
	}
	local function store(name)
		table.insert(f.acquired, name)
		f.data[name] = f.data[name] or {}
		local values = f.data[name]
		return {
			SetAsync = function(_, key, value)
				values[key] = value
				f.writes += 1
			end,
			GetAsync = function(_, key)
				return values[key]
			end,
			GetSortedAsync = function()
				local rows = {}
				for key, value in values do
					table.insert(rows, { key = key, value = value })
				end
				return {
					GetCurrentPage = function()
						return rows
					end,
				}
			end,
		}
	end
	local shared = { Types = "Types", StorageNames = "StorageNames" }
	local replicated = node("ReplicatedStorage")
	function replicated:WaitForChild()
		return shared
	end
	f.replicated = replicated
	local services = {
		Players = {
			PlayerRemoving = signal(),
			GetPlayers = function()
				return f.players
			end,
			GetPlayerByUserId = function(_, id)
				for _, player in f.players do
					if player.UserId == id then
						return player
					end
				end
			end,
			GetNameFromUserIdAsync = function(_, id)
				return "User" .. id
			end,
		},
		DataStoreService = {
			GetDataStore = function(_, name)
				return store(name)
			end,
			GetOrderedDataStore = function(_, name)
				return store(name)
			end,
		},
		HttpService = {
			JSONEncode = function(_, data)
				return serde.encode("json", data)
			end,
		},
		ReplicatedStorage = replicated,
		RunService = {
			IsStudio = function()
				return f.studio
			end,
		},
		ServerStorage = node("ServerStorage"),
	}
	local src = fs.readFile("src/server/Services/LeaderboardService.luau")
	src = src:gsub(
		"return LeaderboardService%s*$",
		"return {service=LeaderboardService,write=writePlayer,read=readBoards,publish=publish,counts=counts}"
	)
	local fn = assert(loadstring(src))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, key)
					return services[key]
				end,
				BindToClose = function() end,
			},
			script = { Parent = { ProfileService = "ProfileService" } },
			require = function(key)
				return ({ Types = {}, StorageNames = Names, ProfileService = Profile })[key]
			end,
			Instance = { new = node },
			task = { spawn = function() end },
		}, { __index = getfenv() })
	)
	f.boundary = fn()
	f.data.Top_money_v1 = { ["999"] = 999999999 }
	f.boundary.service.Start()
	function f:actor(id, creative, real)
		local p = { UserId = id, DisplayName = "P" .. id, creative = creative, real = real }
		function p:GetAttribute(key)
			return if key == "Creative" then self.creative else nil
		end
		table.insert(self.players, p)
		self.profiles[id] = {
			level = 5,
			coins = 100,
			blocksTotal = 20,
			stats = { rats = 10, ratsTotal = 20, blocksClean = 10, deaths = 1 },
		}
		return p
	end
	function f:rows(id)
		return serde.decode("json", self.replicated:FindFirstChild("Tops"):FindFirstChild(id).Value)
	end
	return f
end
local f = fixture(false)
local normal, creative, failed, negative =
	f:actor(1), f:actor(2, true), f:actor(3, false, false), f:actor(-1)
f.boundary.read()
f.boundary.publish()
check(
	"archived high-score never leaks into fresh release board",
	#f:rows("money") == 1 and f:rows("money")[1].n == "P1"
)
check("all board handles use live prefix", #f.acquired == 6)
for _, name in f.acquired do
	check("live acquisition " .. name, name:sub(1, #live.Prefix) == live.Prefix)
end
for _, actor in { creative, failed, negative } do
	local before = f.writes
	f.boundary.write(actor)
	check("ineligible actor never persists " .. actor.UserId, f.writes == before)
end
f.boundary.write(normal)
check("ordinary live player persists five values and metadata", f.writes == 6)
check("archive preserved byte-for-byte values", f.data.Top_money_v1["999"] == 999999999)
local money = f.data[live.progress("Top_money_v1")]
money["2"], money["3"], money["-1"], money["7"] = 999, 888, 777, 500
f.boundary.read()
f.boundary.publish()
check(
	"cached rows filter creative/failed/negative but retain ordinary offline",
	#f:rows("money") == 2
)
normal.creative = true
f.boundary.publish()
check(
	"entering Creative immediately removes cached own row",
	#f:rows("money") == 1 and f:rows("money")[1].n == "User7"
)
local s = fixture(true)
local owner, actor = s:actor(6182034556), s:actor(-1)
s.boundary.write(owner)
s.boundary.write(actor)
s.data[studio.progress("Top_money_v1")]["7"] = 99999
s.boundary.read()
s.boundary.publish()
check("Studio positive and negative actors never persist tops", s.writes == 0)
for _, id in { "rats", "money", "level", "blocks", "deaths" } do
	check("Studio board empty " .. id, #s:rows(id) == 0)
end
for _, name in s.acquired do
	check("Studio acquisition " .. name, name:sub(1, #studio.Prefix) == studio.Prefix)
end
check("preflight compiles", loadstring(fs.readFile("scripts/reset-release-preflight.luau")) ~= nil)
for _, mode in { "empty", "occupied", "failed" } do
	local seen, reads = {}, 0
	local output = node("ServerStorage")
	local function get(name)
		check(
			mode .. " preflight only acquires exact new live store " .. name,
			name:sub(1, #live.LivePrefix) == live.LivePrefix
		)
		seen[name] = true
		local function list()
			reads += 1
			if mode == "failed" then
				error("isolated unavailable read")
			end
			return {
				IsFinished = true,
				GetCurrentPage = function()
					return if mode == "occupied" and name == live.progress("Top_money_v1")
						then { { key = "42", value = 10 } }
						else {}
				end,
			}
		end
		return {
			ListKeysAsync = function(_, prefix, size)
				assert(prefix == "" and size == 1)
				return list()
			end,
			GetSortedAsync = function(_, ascending, size)
				assert(ascending == false and size == 1)
				return list()
			end,
			GetAsync = function(_, key, options)
				assert(key == "User_6182034556" and options.UseCache == false)
				reads += 1
				return nil
			end,
			-- No write methods are provided: accidental mutations would fail this actual-source test.
		}
	end
	local preflight = assert(loadstring(fs.readFile("scripts/reset-release-preflight.luau")))
	setfenv(
		preflight,
		setmetatable({
			game = {
				PlaceId = 92594200898716,
				GameId = 10772144679,
				GetService = function(_, id)
					return ({
						RunService = {
							IsStudio = function()
								return true
							end,
						},
						DataStoreService = {
							GetDataStore = function(_, name)
								return get(name)
							end,
							GetOrderedDataStore = function(_, name)
								return get(name)
							end,
						},
						HttpService = {
							JSONEncode = function(_, value)
								return serde.encode("json", value)
							end,
						},
						ServerStorage = output,
					})[id]
				end,
			},
			Instance = { new = node },
			print = function() end,
		}, { __index = getfenv() })
	)
	local result = preflight()
	check(mode .. " preflight exact14 stores and15 reads", #result.stores == 14 and reads == 15)
	check(
		mode .. " preflight fail-closed result",
		result.livePersistentNamespacesEmpty == (mode == "empty")
	)
	check(
		mode .. " preflight reports without any DataStore write",
		result.dataStoreWrites == 0 and output:FindFirstChild("ReleaseResetPreflight") ~= nil
	)
	for _, kind in { "dataStores", "orderedDataStores" } do
		for _, base in live.catalog[kind] do
			check(mode .. " preflight covers manifest " .. base, seen[live.progress(base)])
		end
	end
end
local profileFactory = require("./qa-profile-persistence-offline").fixture
local copy = assert(loadstring(fs.readFile("src/shared/Persistence.luau")))().copy
local archive = {
	schemaVersion = 3,
	level = 99,
	coins = 999999,
	inventory = { ["1"] = { id = "diamond", count = 64 } },
	receipts = { "legacy-receipt" },
}
local disks = { PlayerProfiles_v3 = { User_42 = copy(archive) } }
local function profile(studioMode, job)
	local env = profileFactory({ studio = studioMode })
	local boundary = env:profile(job)
	check(
		"actual profile store name " .. job,
		boundary.storeName == (if studioMode then studio else live).progress("PlayerProfiles_v3")
	)
	disks[boundary.storeName] = disks[boundary.storeName] or {}
	local disk = disks[boundary.storeName]
	boundary.setStore({
		UpdateAsync = function(_, key, transform)
			local nextValue = transform(copy(disk[key]))
			if nextValue ~= nil then
				disk[key] = copy(nextValue)
			end
			return copy(disk[key])
		end,
	})
	local actor = env:player()
	local session = env:session(boundary, actor, job)
	return boundary, actor, session
end
local sb, sp, ss = profile(true, "studio-release")
check(
	"positive Studio owner gets fresh profile without legacy loot",
	ss.profile.level == 1 and ss.profile.coins == 0 and ss.profile.inventory[1].id == "shovel"
)
ss.profile.coins = 123456
check("Studio test grant saves only Studio profile", sb.save(sp, ss, true))
local lb, lp, ls = profile(false, "live-release")
check(
	"positive live player never imports Studio or archived test progress",
	ls.profile.level == 1 and ls.profile.coins == 0 and ls.profile.inventory[1].id == "shovel"
)
check("release keeps existing profile schema", ls.profile.schemaVersion == 3)
ls.profile.coins = 12
check("live profile saves normally after fresh start", lb.save(lp, ls, true))
local _, _, studioRejoin = profile(true, "studio-rejoin")
check(
	"Studio rejoin retains only separate Studio test progress",
	studioRejoin.profile.coins == 123456
)
check(
	"live namespace remains independent after Studio rejoin",
	disks[live.progress("PlayerProfiles_v3")].User_42.coins == 12
)
check(
	"original profile and receipt archive never changed",
	serde.encode("json", disks.PlayerProfiles_v3.User_42) == serde.encode("json", archive)
)
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualSources = true,
	realDataStores = false,
	realPlayers = false,
}))
