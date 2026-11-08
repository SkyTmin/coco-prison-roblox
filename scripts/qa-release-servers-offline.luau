--!nocheck
-- Actual reward policy/service + BossService reward function + affinity service, isolated stores.
local fs = require("@lune/fs")
local base = getfenv()
local n = 0
local function check(label, ok)
	n += 1
	assert(ok, label)
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
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
local function load(path, globals, rewrite)
	local source = fs.readFile(path)
	if rewrite then
		source = rewrite(source)
	end
	local fn = assert(loadstring(source, "@" .. path))
	setfenv(fn, setmetatable(globals or {}, { __index = base }))
	return fn()
end
local function signal()
	local s = { callbacks = {} }
	function s:Connect(fn)
		table.insert(self.callbacks, fn)
	end
	function s:Fire(...)
		for _, fn in self.callbacks do
			fn(...)
		end
	end
	return s
end
local function rewardFixture()
	local f = {
		live = {},
		disk = {},
		toasts = {},
		attrs = {},
		queued = {},
		players = {},
		chats = {},
		quests = {},
	}
	local mods = {
		Numbers = load("src/shared/Numbers.luau"),
		Persistence = load("src/shared/Persistence.luau"),
		InventoryService = {
			add = function(p, id, count)
				if f.full then
					return count
				end
				p.inventory[id] = (p.inventory[id] or 0) + count
				return 0
			end,
		},
		Strings = {
			t = function(key, _, ...)
				return { key, ... }
			end,
			money = tostring,
			grouped = tostring,
			localeOf = function()
				return "en"
			end,
			itemName = function(id)
				return id
			end,
		},
		Remotes = {
			event = function()
				return {
					FireClient = function(_, _, text)
						table.insert(f.toasts, text)
					end,
				}
			end,
		},
	}
	local players = {
		GetPlayers = function()
			return f.players
		end,
		GetPlayerByUserId = function(_, id)
			return f.players[id]
		end,
	}
	local function newPlayer(id)
		local p = {
			UserId = id,
			Name = "P" .. id,
			SetAttribute = function(_, k, v)
				f.attrs[k] = v
			end,
		}
		f.players[id] = p
		f.live[id] = { coins = 100, stats = {}, inventory = {}, location = "arena" }
		f.disk[id] = copy(f.live[id])
		return p
	end
	f.player = newPlayer(1)
	f.newPlayer = newPlayer
	mods.ProfileService = {
		Get = function(p)
			return f.live[p.UserId]
		end,
		IsReal = function(p)
			return f.live[p.UserId] ~= nil
		end,
		Mutate = function(p, fn)
			fn(f.live[p.UserId])
		end,
		SaveNow = function(p)
			if f.journalFail then
				return false
			end
			f.disk[p.UserId] = copy(f.live[p.UserId])
			return true
		end,
		MutateDurable = function(p, fn)
			local staged = copy(f.live[p.UserId])
			fn(staged)
			local fault = f.fault
			f.fault = nil
			if fault == "before" then
				return false
			end
			f.disk[p.UserId] = copy(staged)
			if f.duringSave then
				local cb = f.duringSave
				f.duringSave = nil
				cb()
			end
			if fault == "after" then
				return false
			end
			fn(f.live[p.UserId])
			return true
		end,
		OnLoaded = function() end,
	}
	local globals = {
		game = {
			GetService = function(_, name)
				return if name == "Players" then players else { Shared = names }
			end,
		},
		script = { Parent = names },
		require = function(name)
			return assert(mods[name], name)
		end,
		task = {
			spawn = function(fn, ...)
				table.insert(f.queued, { fn, ... })
			end,
		},
		warn = function() end,
	}
	mods.BossRewardPolicy = load("src/server/Services/BossRewardPolicy.luau", globals)
	f.policy = mods.BossRewardPolicy
	f.service = load("src/server/Services/BossRewardService.luau", globals)
	function f:award(id, boss, killed, cooldown)
		return {
			id = id,
			bossId = boss or "a",
			killedAt = killed or 100.25,
			untilAt = (killed or 100.25) + (cooldown or 60),
			coins = 200,
			items = { ancient_star = 2 },
			share = 1,
		}
	end
	function f:resolve()
		return self.service.Resolve(self.player)
	end
	function f:boss(damage, last, card)
		local scope = {
			BossRewardPolicy = self.policy,
			BossRewardService = self.service,
			ProfileService = mods.ProfileService,
			Config = {
				moneyScale = 1,
				money = { displayDecimals = 0 },
				bosses = { rewards = { minDamageShare = 0.05, lastHitBonus = 0.2 } },
			},
			playersInLocation = function()
				return self.players
			end,
			Players = players,
			Strings = mods.Strings,
			BookService = {
				bossBonus = function()
					return 1, 1
				end,
			},
			BossLoot = {
				Roll = function(_, _, isLast)
					return { ancient_star = if isLast then 3 else 1 }
				end,
			},
			HttpService = {
				GenerateGUID = function()
					f.guid = (f.guid or 0) + 1
					return "award" .. f.guid
				end,
			},
			toast = function() end,
			bossName = function()
				return "Boss"
			end,
			random = {},
			GangService = {
				progressOnce = function(ids)
					f.quests = ids
				end,
			},
			ChatService = {
				announceWith = function() end,
				announce = function(...)
					table.insert(f.chats, { ... })
				end,
			},
			task = globals.task,
		}
		local fn = load("src/server/Services/BossService.luau", scope, function(source)
			return source:match("(local function reward%b()%s.-)\nlocal function died")
				.. "\nreturn reward"
		end)
		fn({
			id = if card then card.id else "a",
			card = card or { name = "Boss", money = { 0, 1000 }, respawnSeconds = 60 },
			damageBy = damage,
		}, last, 100.25)
		while #f.queued > 0 do
			local call = table.remove(f.queued, 1)
			call[1](table.unpack(call, 2))
		end
	end
	return f
end

local f = rewardFixture()
local a = f:award("first")
check("pending journal accepts first award", f.service.Enqueue(f.player, a))
check(
	"journal contains no spendable reward",
	f.live[1].coins == 100 and f.live[1].inventory.ancient_star == nil
)
check(
	"pending lock blocks another server's same-boss kill",
	not f.policy.Eligible(f.live[1], "a", 130)
)
check("different boss remains independent", f.policy.Eligible(f.live[1], "b", 130))
f:resolve()
check(
	"grant and exact respawn cooldown persist together",
	f.disk[1].coins == 300
		and f.disk[1].bossRewardUntil.a == 160.25
		and f.disk[1].bossRewardPending == nil
)
check(
	"reward available exactly at boundary",
	not f.policy.Eligible(f.live[1], "a", 160.249) and f.policy.Eligible(f.live[1], "a", 160.25)
)
f.policy.Apply(f.live[1], a)
check("receipt prevents replay", f.live[1].coins == 300 and f.live[1].inventory.ancient_star == 2)

for _, fault in { "before", "after" } do
	f = rewardFixture()
	f.service.Enqueue(f.player, f:award("one"))
	f.fault = fault
	f:resolve()
	check("uncertain write never grants live " .. fault, f.live[1].coins == 100 and #f.toasts == 0)
	f.live[1] = copy(f.disk[1])
	f:resolve()
	check(
		"rejoin grants once " .. fault,
		f.live[1].coins == 300 and f.live[1].inventory.ancient_star == 2
	)
end
f = rewardFixture()
f.service.Enqueue(f.player, f:award("one"))
f.journalFail = true
f:resolve()
check(
	"failed journal has no reward or toast",
	f.live[1].coins == 100 and #f.toasts == 0 and f.live[1].bossRewardPending ~= nil
)
f.journalFail = false
f.duringSave = function()
	f.service.Enqueue(f.player, f:award("two", "b"))
end
f:resolve()
check(
	"second boss queued during first write is not overwritten",
	f.live[1].coins == 500 and f.live[1].stats.bosses == 2 and f.disk[1].bossRewardUntil.b == 160.25
)
f = rewardFixture()
f.full = true
f.service.Enqueue(f.player, f:award("one"))
f:resolve()
check("full backpack keeps reward in stash", f.live[1].stash[1].count == 2)
f = rewardFixture()
f.service.Enqueue(f.player, f:award("held"))
f.duringSave = function()
	f.live[1].storageDeath =
		{ queue = { { dropItems = true, bossRewardIds = { held = true }, drops = {} } } }
end
f:resolve()
check(
	"death during reward write holds loot in death escrow",
	f.live[1].inventory.ancient_star == nil and f.live[1].storageDeath.queue[1].drops[1].count == 2
)
check("death escrow keeps exports busy after reward finishes", f.attrs.SharedStorageBusy)
f = rewardFixture()
f.newPlayer(2)
f.newPlayer(3)
f.live[3].bossRewardUntil = { a = 200 }
f:boss({ [1] = 30, [2] = 20, [3] = 950 }, 3)
check(
	"locked helper does not dilute eligible bank",
	f.live[1].coins == 820 and f.live[2].coins == 500 and f.live[3].coins == 100
)
check(
	"highest eligible hitter receives locked helper's last hit bonus",
	f.live[1].inventory.ancient_star == 3
		and f.live[2].inventory.ancient_star == 1
		and f.live[3].stats.bosses == nil
)
check(
	"chat lists damage and actual zero helper money",
	#f.chats == 3 and f.chats[1][3] == "P3" and f.chats[1][6] == "0"
)
check("locked helper cannot farm gang kill progress", #f.quests == 2)

local cards =
	require("@lune/serde").decode("json", fs.readFile("src/shared/Config/bosses.json")).bosses
check("all authored bosses covered", #cards == 19)
for _, card in cards do
	f = rewardFixture()
	f:boss({ [1] = 100 }, 1, card)
	check(
		"exact authored respawn interval " .. card.id,
		f.live[1].bossRewardUntil[card.id] == 100.25 + card.respawnSeconds
	)
end
f = rewardFixture()
f.live[1].coins = 9007199254740991
f.service.Enqueue(f.player, f:award("full"))
f:resolve()
check(
	"wallet overflow retains intact pending reward",
	f.live[1].bossRewardPending ~= nil and f.live[1].coins == 9007199254740991 and #f.toasts == 0
)
f.live[1].coins = 0
f:resolve()
check(
	"wallet capacity recovery grants full amount once",
	f.live[1].coins == 200 and f.live[1].bossRewardPending == nil
)
f = rewardFixture()
f.service.Enqueue(f.player, f:award("cycle1"))
f.service.Enqueue(f.player, f:award("cycle2", "a", 160.25))
f:resolve()
check(
	"delayed same-boss cycles remain ordered in queue",
	f.live[1].coins == 500 and f.live[1].bossRewardUntil.a == 220.25 and f.live[1].stats.bosses == 2
)
f = rewardFixture()
f.service.Enqueue(f.player, f:award("retry"))
f.fault = "after"
f:resolve()
f:resolve()
check(
	"retry without rejoin after uncertain acknowledgement grants once",
	f.live[1].coins == 300 and f.disk[1].coins == 300
)

local function affinityFixture()
	local q =
		{ now = 1000, maps = {}, queued = {}, remote = {}, teleports = {}, toast = {}, saves = 0 }
	local players = {
		MaxPlayers = 20,
		PlayerRemoving = signal(),
		GetPlayers = function()
			return { q.player }
		end,
	}
	q.player = {
		UserId = 1,
		Parent = players,
		FollowUserId = 0,
		GetJoinData = function()
			return q.join or {}
		end,
	}
	local teleport = {
		TeleportInitFailed = signal(),
		TeleportAsync = function(_, place, list, options)
			table.insert(q.teleports, { place = place, players = list, options = options })
			if q.teleportFail then
				error("full")
			end
		end,
	}
	q.teleport = teleport
	local ms = {
		GetHashMap = function(_, name)
			assert(name:sub(1, #q.namespacePrefix) == q.namespacePrefix)
			name = name:sub(#q.namespacePrefix + 1)
			q.maps[name] = q.maps[name] or {}
			local map = q.maps[name]
			return {
				GetAsync = function(_, key)
					if q.storeFail then
						error("outage")
					end
					return copy(map[key])
				end,
				SetAsync = function(_, key, value)
					if q.storeFail then
						error("outage")
					end
					map[key] = copy(value)
				end,
				UpdateAsync = function(_, key, fn)
					if q.storeFail then
						error("outage")
					end
					map[key] = fn(copy(map[key]))
					return copy(map[key])
				end,
				RemoveAsync = function(_, key)
					map[key] = nil
				end,
			}
		end,
	}
	local mods = {
		ProfileService = {
			IsReal = function()
				return true
			end,
			OnLoaded = function(fn)
				q.loaded = fn
			end,
			SaveNow = function()
				q.saves += 1
				return not q.saveFail
			end,
		},
		Strings = {
			t = function(k)
				return k
			end,
			localeOf = function()
				return "en"
			end,
		},
		Remotes = {
			func = function()
				return q.remote
			end,
			event = function()
				return {
					FireClient = function(_, _, k)
						table.insert(q.toast, k)
					end,
				}
			end,
		},
	}
	local services = {
		Players = players,
		MemoryStoreService = ms,
		TeleportService = teleport,
		HttpService = {
			GenerateGUID = function()
				return "12345678-1234-1234-1234-123456789abc"
			end,
		},
		RunService = {
			IsStudio = function()
				return q.studio == true
			end,
		},
		ReplicatedStorage = { Shared = names },
	}
	q.game = {
		PlaceId = 10,
		JobId = "current",
		PrivateServerId = "",
		GetService = function(_, k)
			return services[k]
		end,
		BindToClose = function(_, fn)
			q.close = fn
		end,
	}
	mods.StorageNames = load("src/shared/StorageNames.luau", { game = q.game })
	q.namespacePrefix = mods.StorageNames.Prefix
	q.service = load("src/server/Services/ServerAffinityService.luau", {
		game = q.game,
		script = { Parent = names },
		require = function(k)
			return mods[k]
		end,
		os = {
			time = function()
				return q.now
			end,
			clock = function()
				return q.now
			end,
		},
		task = {
			spawn = function(fn, ...)
				table.insert(q.queued, { fn, ... })
			end,
		},
		Instance = {
			new = function()
				return {}
			end,
		},
		warn = function() end,
	})
	function q:start(state)
		self.maps.ServerAffinity_v1 = state and { ["1"] = state } or {}
		self.service.Start()
	end
	function q:target(users)
		self.maps.ServerPresence_v1.previous =
			{ placeId = 10, users = users or 3, max = 20, updatedAt = self.now }
	end
	function q:route()
		self.loaded(self.player)
	end
	return q
end
local function old()
	return { jobId = "previous", placeId = 10, assignedAt = 500, untilAt = 22100 }
end
local q = affinityFixture()
q:start()
q:route()
check(
	"first join binds exactly six hours",
	q.maps.ServerAffinity_v1["1"].assignedAt == 1000
		and q.maps.ServerAffinity_v1["1"].untilAt == 22600
)
q = affinityFixture()
q:start(old())
q:target()
q:route()
check(
	"available assigned server redirects once after save",
	#q.teleports == 1 and q.teleports[1].options.ServerInstanceId == "previous" and q.saves == 1
)
q:route()
check("same join never loops", #q.teleports == 1)
check("rejoin does not renew affinity clock", q.maps.ServerAffinity_v1["1"].untilAt == 22100)
q.teleport.TeleportInitFailed:Fire(q.player, nil, nil, nil, q.teleports[1].options)
check(
	"init failure stays current and preserves expiry",
	q.maps.ServerAffinity_v1["1"].jobId == "current"
		and q.maps.ServerAffinity_v1["1"].untilAt == 22100
		and #q.teleports == 1
)
for _, kind in { "closed", "full", "stale", "throw" } do
	q = affinityFixture()
	q:start(old())
	if kind ~= "closed" then
		q:target(if kind == "full" then 20 else 3)
	end
	if kind == "stale" then
		q.now += 61
	end
	if kind == "throw" then
		q.teleportFail = true
	end
	q:route()
	check(
		"bounded current fallback " .. kind,
		q.maps.ServerAffinity_v1["1"].jobId == "current" and #q.teleports <= 1
	)
end
q = affinityFixture()
q:start(old())
q.player.FollowUserId = 25
q:route()
check(
	"native friend join overrides old affinity without renewal",
	#q.teleports == 0
		and q.maps.ServerAffinity_v1["1"].jobId == "current"
		and q.maps.ServerAffinity_v1["1"].untilAt == 22100
)
q = affinityFixture()
q:start(old())
q:target()
q.join = {
	LaunchData = "affinity:aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
	TeleportData = { jobId = "forged", override = true },
}
q:route()
check(
	"forged launch/teleport data cannot override assignment",
	q.teleports[1].options.ServerInstanceId == "previous"
)
q = affinityFixture()
q:start(old())
q:target()
local token = q.remote.OnServerInvoke(q.player)
q.join = { LaunchData = token }
q:route()
check(
	"server-issued invitation overrides to inviter's server",
	#q.teleports == 0 and q.maps.ServerAffinity_v1["1"].jobId == "current"
)
check("invite route request rate limited", q.remote.OnServerInvoke(q.player) == nil)
q = affinityFixture()
q:start(old())
q.now = 22101
q:route()
check(
	"expired window begins a fresh assignment",
	q.maps.ServerAffinity_v1["1"].untilAt == 43701 and #q.teleports == 0
)
q = affinityFixture()
q:start(old())
q:target()
q.saveFail = true
q:route()
check("unconfirmed profile save does not teleport", #q.teleports == 0)
q = affinityFixture()
q:start(old())
q.storeFail = true
q:route()
check("store outage never teleports or blocks entry", #q.teleports == 0)
q = affinityFixture()
q.studio = true
q:start()
check(
	"Studio never reaches live routing",
	q.loaded == nil and q.remote.OnServerInvoke(q.player) == nil
)
print(
	string.format(
		"Release servers PASS: %d actual-source checks; isolated stores/teleports, no live joins or invitations",
		n
	)
)
