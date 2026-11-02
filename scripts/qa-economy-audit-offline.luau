--!nocheck
-- Lune, repository root. Actual modules; fake profiles/remotes/scheduler, no Roblox services or DataStores.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local env = getfenv()
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local modules, hooks, events = {}, {}, {}
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
local profiles = {}
local clock = 100
local tasks = {}
local fakeTask = {
	delay = function(seconds, fn, ...)
		table.insert(tasks, { at = clock + seconds, fn = fn, args = table.pack(...) })
	end,
	spawn = function() end,
	defer = function() end,
}
local function signal()
	return {
		Connect = function(self, fn)
			self.callback = fn
			return { Disconnect = function() end }
		end,
	}
end
local players = { PlayerRemoving = signal(), list = {} }
function players:GetPlayers()
	return self.list
end
local sharedJson
local services = {
	Players = players,
	RunService = { Heartbeat = signal() },
	ReplicatedStorage = {
		WaitForChild = function()
			return names
		end,
		FindFirstChild = function()
			return sharedJson
				and {
					Value = sharedJson,
					IsA = function()
						return true
					end,
				}
		end,
	},
	CollectionService = {
		GetTagged = function()
			return {}
		end,
	},
	HttpService = {
		JSONDecode = function(_, text)
			return serde.decode("json", text)
		end,
	},
	TextChatService = {},
}
local gameMock = {
	GetService = function(_, id)
		return assert(services[id], id)
	end,
}
local workspaceMock = {
	GetServerTimeNow = function()
		return clock
	end,
}
local fakeRandom = {
	new = function()
		return {
			NextNumber = function(_, a)
				return a or 0
			end,
			NextInteger = function(_, a)
				return a
			end,
		}
	end,
}
local function execute(path, transform)
	local src = fs.readFile(path)
	if transform then
		src = transform(src)
	end
	local fn = assert(loadstring(src, "@" .. path))
	setfenv(
		fn,
		setmetatable({
			game = gameMock,
			workspace = workspaceMock,
			task = fakeTask,
			script = {
				Parent = names,
				WaitForChild = function(_, k)
					return k
				end,
			},
			require = function(id)
				return assert(modules[id], "missing " .. tostring(id))
			end,
			Vector3 = rb.Vector3,
			CFrame = rb.CFrame,
			Color3 = rb.Color3,
			Random = fakeRandom,
			RaycastParams = {
				new = function()
					return {}
				end,
			},
			Enum = { RaycastFilterType = { Exclude = "Exclude" } },
			os = setmetatable({
				clock = function()
					return clock
				end,
			}, { __index = os }),
			typeof = function(value)
				return if type(value) == "table" and value.__instance
					then "Instance"
					else typeof(value)
			end,
		}, { __index = env })
	)
	return fn()
end
for _, file in fs.readDir("src/shared/Config") do
	if file:match("%.json$") then
		modules[file:sub(1, -6)] = serde.decode("json", fs.readFile("src/shared/Config/" .. file))
	end
end
modules.Config = execute("src/shared/Config/init.luau")
local C = modules.Config
modules.Types = {}
modules.Remotes = {
	event = function(id)
		if not events[id] then
			events[id] = {
				OnServerEvent = signal(),
				calls = {},
				FireClient = function(self, ...)
					table.insert(self.calls, table.pack(...))
				end,
			}
		end
		return events[id]
	end,
}
modules.Remotes.unreliable = modules.Remotes.event
modules.Strings = {
	t = function(key)
		return key
	end,
	localeOf = function()
		return "en"
	end,
	counterName = function(x)
		return x
	end,
	blockName = function(x)
		return x
	end,
	grouped = tostring,
	money = tostring,
	boosterName = tostring,
	lower = string.lower,
}
modules.ProfileService = {
	Get = function(p)
		return profiles[p]
	end,
	Mutate = function(p, fn)
		if profiles[p] then
			fn(profiles[p])
		end
	end,
	OnLoaded = function(fn)
		table.insert(hooks, fn)
	end,
	IsReal = function(p)
		return profiles[p] ~= nil
	end,
	CanExport = function(p)
		return profiles[p] ~= nil and profiles[p].storageTransfer == nil
	end,
	SaveNow = function()
		return true
	end,
}
modules.Warzone = {
	bonuses = function()
		return {}
	end,
	cfg = { bonus = 0.2 },
}
modules.Sfx = { toPlayer = function() end }
modules.GangService = {
	progress = function() end,
	perk = function()
		return 0
	end,
}
modules.ArtifactService = {
	RollDig = function()
		return {}
	end,
	Notify = function() end,
}
modules.HungerService = { OnBlockDug = function() end }
modules.NeedsService, modules.HurtService, modules.Effects, modules.Potions = {}, {}, {}, {}
modules.PrisPlus = {
	cfg = { rubbMin = 1 },
	rubies = function(p)
		return p.rubies or 0
	end,
}
modules.Chat, modules.CollisionGroups = {}, {}
modules.ChatService = { fail = function() end, reply = function() end }
modules.WarzoneService = { OnDug = function() end }
for _, name in
	{
		"Numbers",
		"Boosters",
		"Selling",
		"MiningDrops",
		"MiningStats",
		"Books",
		"Skills",
		"Achievements",
	}
do
	modules[name] = execute("src/shared/" .. name .. ".luau")
end
for _, name in { "InventoryService", "ProfessionService", "AchievementService", "BookTuning" } do
	modules[name] = execute("src/server/Services/" .. name .. ".luau")
end
local Inventory, Achievements, Stats =
	modules.InventoryService, modules.AchievementService, modules.MiningStats
local actor = {
	Name = "Actor",
	DisplayName = "Actor",
	UserId = 1,
	Parent = true,
	GetAttribute = function()
		return false
	end,
}
local recipient = { Name = "Recipient", DisplayName = "Recipient", UserId = 2 }
players.list = { actor, recipient }
local function fresh(player)
	local p = {
		coins = 0,
		level = 50,
		inventory = {},
		armor = {},
		selectedSlot = 1,
		counters = {},
		dug = {},
		achievements = {},
		stats = {},
		blocksTotal = 0,
		professions = {
			upgrades = { money = 0, blocks = 0, mobs = 0 },
			xp = {},
			level = {},
			points = 0,
		},
		needs = { sleep = 100 },
		skills = {},
	}
	profiles[player or actor] = p
	return p
end
local p = fresh()
p.dug.coal_block = 31
Achievements.OnDugMany(actor, { coal_block = 1 })
check(
	"AoE non-counter milestone paid immediately",
	p.dug.coal_block == 32 and p.achievements.coal_block == 1 and p.coins > 0
)
local paid = p.coins
Achievements.CatchUp(actor)
check(
	"achievement catch-up does not repay or add cells",
	p.coins == paid and p.dug.coal_block == 32
)
p = fresh()
p.counters["Камень"] = 32
Achievements.CatchUp(actor)
check(
	"unclaimed counter milestone survives login",
	p.achievements["Камень"] == 1 and p.coins > 0
)
p = fresh()
p.boosters = { { kind = "money", mult = 2, minutes = 30, count = 200 } }
p.counters["Песок"] = 256
p.achievements["Песок"] = 3
Achievements.OnDugMany(actor, { sand = 0 })
check(
	"full storage preserves guaranteed booster milestone",
	modules.Boosters.storedCount(p) == 201 and p.achievements["Песок"] == 4
)
modules.Boosters.store(p, "money")
check("ordinary booster additions remain capped", modules.Boosters.storedCount(p) == 201)
Achievements.CatchUp(actor)
check("guaranteed reward replay is idempotent", modules.Boosters.storedCount(p) == 201)
p.stats.dailyClaims = 30
Achievements.OnStat(actor, "dailyClaims")
check(
	"daily milestone preserves its booster at full capacity",
	modules.Boosters.storedCount(p) == 202
)
local drop, amount = modules.MiningDrops.resolve(C.block("melon"), true, fakeRandom.new())
check("Silk Touch yields one whole melon", drop == "melon" and amount == 1)
drop, amount = modules.MiningDrops.resolve(C.block("melon"), false, fakeRandom.new())
check("ordinary melon retains slice range", drop == "melon_slice" and amount == 3)
p = fresh()
p.professions.upgrades.money = 50
p.faction = "red"
p.activeBoosters = { { kind = "money", mult = 2, startsAt = 0, endsAt = 1000 } }
sharedJson = serde.encode("json", {
	{ kind = "money", mult = 2, scope = "faction", faction = "red", startsAt = 0, endsAt = 1000 },
	{ kind = "money", mult = 2, scope = "global", startsAt = 0, endsAt = 1000 },
})
check(
	"final money multiplier is capped after all scopes",
	modules.ProfessionService.moneyMultiplier(p) == 5 and modules.Selling.multiplier(p) == 5
)
p.autosell = true
local money = Inventory.autoSell(p, "melon", 1, modules.Selling.multiplier(p))
check("auto-sell uses capped payout", money == 70000 and p.coins == 70000)
sharedJson = nil
p = fresh()
for _ = 1, 100 do
	Stats.credit(p, "sand", 1, 2)
end
check(
	"100 real cells at x2 retain clean100 orange200 type200",
	p.stats.blocksClean == 100 and p.blocksTotal == 200 and p.counters["Песок"] == 200
)
p = fresh()
for _ = 1, 25 do
	Stats.credit(p, "sand", 1, 2.4)
end
check(
	"fractional credit reaches exact upgrade gate",
	p.blocksTotal == 60 and p.counters["Песок"] == 60
)
local bad = { 0 / 0, math.huge, -math.huge, -1, 0.5 }
for i, value in bad do
	p = fresh()
	p.inventory[1] = { id = "sand", count = 4 }
	check(
		"invalid add rejected before mutation " .. i,
		not pcall(Inventory.add, p, "sand", value) and p.inventory[1].count == 4
	)
	check(
		"invalid remove/move rejected " .. i,
		Inventory.remove(p, "sand", value) == 0
			and not Inventory.move(p, 1, 2, value)
			and p.inventory[1].count == 4
	)
end
p = fresh()
p.inventory[1] = { id = "sand", count = 0 / 0 }
local sold = Inventory.sellAll(p, 1)
check(
	"corrupt stack cannot poison coins through sale",
	sold == 0 and p.coins == 0 and p.inventory[1] ~= nil
)
local commands = execute("src/server/Services/ChatCommandService.luau", function(src)
	return src:gsub("return ChatCommandService%s*$", "return { pay = pay, rubb = rubb }")
end)
p.coins = 0 / 0
fresh(recipient)
commands.pay(actor, { "Recipient", "10" })
check("corrupt balance cannot mint money to another player", profiles[recipient].coins == 0)
p.coins = 100000
commands.pay(actor, { "Recipient", "5" })
check(
	"valid payment still transfers exact money",
	p.coins == 50000 and profiles[recipient].coins == 50000
)
p.storageTransfer = { phase = "delivered" }
commands.pay(actor, { "Recipient", "1" })
check(
	"pending storage prevents payment export",
	p.coins == 50000 and profiles[recipient].coins == 50000
)
p.storageTransfer = nil
local drops = execute("src/server/Services/ItemDropService.luau", function(src)
	return src:gsub("return ItemDropService%s*$", "return { drop = onDropItem }")
end)
modules.GlobalBoosterService = {}
services.HttpService.GenerateGUID = function()
	return "offline-activation"
end
local activateShared = execute("src/server/Services/BoosterService.luau", function(src)
	return src:gsub("return BoosterService%s*$", "return activateShared")
end)
p = fresh()
p.boosters = {
	{ kind = "money", scope = "global", mult = 2, minutes = 30, count = 1 },
	{ kind = "blocks", mult = 2, minutes = 30, count = 199 },
}
local ownedBooster = table.clone(p.boosters[1])
local saveNow = modules.ProfileService.SaveNow
modules.ProfileService.SaveNow = function()
	modules.Boosters.store(p, "blocks", nil, 2, 30, 1, true)
	return false
end
activateShared(actor, 1, ownedBooster)
modules.ProfileService.SaveNow = saveNow
check(
	"failed activation refund survives earned booster overflow",
	modules.Boosters.storedCount(p) == 201 and p.boosters[2].scope == "global"
)
-- Valid character: the old malformed path changed the profile before Spawn could raise.
actor.Character = {
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
for i, value in bad do
	p = fresh()
	p.inventory[1] = { id = "sand", count = 4 }
	local ok = pcall(drops.drop, actor, 1, value)
	check(
		"DropItem invalid quantity rejected before mutation " .. i,
		ok and p.inventory[1].count == 4
	)
end

-- Actual BookService, forced RNG only: mixed AoE must feed both kinds of achievement.
local mineApi = {}
function mineApi.index(m, x, y, z)
	return ((z - 1) * m.size[2] + y - 1) * m.size[1] + x
end
function mineApi.coords(m, i)
	return (i - 1) % m.size[1] + 1,
		math.floor((i - 1) / m.size[1]) % m.size[2] + 1,
		math.floor((i - 1) / (m.size[1] * m.size[2])) + 1
end
function mineApi.breakBlock(m, i)
	local id = m.cells[i]
	m.cells[i] = nil
	return id
end
modules.MineService = mineApi
modules.BookService = execute("src/server/Services/BookService.luau")
p = fresh()
p.inventory[1] =
	{ id = "pickaxe", level = 16, count = 1, books = { { id = "plastolom", level = 3 } } }
p.dug.coal_block = 31
p.counters["Камень"] = 31
p.activeBoosters = { { kind = "blocks", mult = 2, startsAt = 0, endsAt = 1000 } }
local m = { size = { 3, 1, 1 }, cells = { [2] = "coal_block", [3] = "stone" } }
modules.BookService.onDug(actor, m, 1, rb.Vector3.yAxis, "cobblestone", 1, 1.2)
check(
	"real book AoE pays non-counter and counter achievements",
	p.dug.coal_block == 32
		and p.achievements.coal_block == 1
		and p.achievements["Камень"] == 1
)
check(
	"real book AoE retains actual clean and boosted type stats",
	p.stats.blocksClean == 2 and p.blocksTotal == 4.8 and p.counters["Камень"] == 33.4
)
paid = p.coins
modules.BookService.onDug(actor, m, 1, rb.Vector3.yAxis, "cobblestone", 1, 1.2)
check(
	"empty AoE repeat cannot repay or count cells",
	p.coins == paid and p.stats.blocksClean == 2 and p.dug.coal_block == 32
)

-- Real DigService with fake engine ray intersections and a deterministic server clock.
local partList, byPart, removed = {}, {}, {}
local mineFolder = {}
local function part(position, id)
	local b = {
		__instance = true,
		Position = position,
		Size = rb.Vector3.new(4, 4, 4),
		CFrame = rb.CFrame.new(position),
		Parent = mineFolder,
		Color = rb.Color3.new(1, 1, 1),
		IsA = function()
			return true
		end,
	}
	table.insert(partList, b)
	local i = #partList
	m.cells[i] = id
	byPart[b] = i
	return b
end
local head = {
	Position = rb.Vector3.new(0, 4, 0),
	IsA = function()
		return true
	end,
}
local root = {
	Position = head.Position,
	AssemblyLinearVelocity = rb.Vector3.zero,
	IsA = function()
		return true
	end,
}
actor.Character = {
	PrimaryPart = root,
	FindFirstChild = function(_, name)
		return if name == "Head" then head else root
	end,
	GetAttribute = function()
		return nil
	end,
	SetAttribute = function() end,
}
actor.GetNetworkPing = function()
	return 0.15
end
function workspaceMock:Raycast(origin, delta, params)
	local nearest, best = nil, math.huge
	for _, b in partList do
		if b.Parent and not table.find(params.FilterDescendantsInstances, b.Parent) then
			local lo, hi = 0, 1
			for _, axis in { "X", "Y", "Z" } do
				local low, high = b.Position[axis] - 2, b.Position[axis] + 2
				if math.abs(delta[axis]) < 1e-9 then
					if origin[axis] < low or origin[axis] > high then
						lo = 2
					end
				else
					local a, z =
						(low - origin[axis]) / delta[axis], (high - origin[axis]) / delta[axis]
					lo, hi = math.max(lo, math.min(a, z)), math.min(hi, math.max(a, z))
				end
			end
			if lo <= hi and lo < best then
				nearest, best = b, lo
			end
		end
	end
	return nearest and { Instance = nearest }
end
function mineApi.lookup(b)
	return if byPart[b] then m else nil, byPart[b]
end
function mineApi.breakBlock(grid, i)
	local id = grid.cells[i]
	if id then
		grid.cells[i] = nil
		partList[i].Parent = nil
		table.insert(removed, { at = clock, id = id })
	end
	return id
end
modules.BookService = {
	silkTouch = function()
		return false
	end,
	onDug = function() end,
}
local dig = execute("src/server/Services/DigService.luau")
dig.Start()
local start = events.DigStart.OnServerEvent.callback
local cancel = events.DigCancel.OnServerEvent.callback
local function advance(to)
	while true do
		local pick, at = nil, math.huge
		for i, job in tasks do
			if job.at <= to and job.at < at then
				pick, at = i, job.at
			end
		end
		if not pick then
			break
		end
		local job = table.remove(tasks, pick)
		clock = job.at
		job.fn(table.unpack(job.args, 1, job.args.n))
	end
	clock = to
end
local function grid()
	cancel(actor)
	tasks = {}
	partList = {}
	byPart = {}
	removed = {}
	mineFolder = {}
	clock += 1
	p = fresh()
	p.inventory[1] = { id = "shovel", level = 16, count = 1, books = {} }
	m = {
		cells = {},
		generation = 1,
		location = C.location("prison"),
		anchor = {
			GetAttribute = function()
				return nil
			end,
		},
	}
	return part(rb.Vector3.zero, "sand"), part(rb.Vector3.new(0, -4, 0), "sand")
end
local a, b = grid()
start(actor, b, rb.Vector3.new(0, -2, 0))
advance(clock + 1)
check("buried block cannot bypass intact foreground cell", #removed == 0)
a, b = grid()
start(actor, a, rb.Vector3.zero)
advance(clock + 1)
check("interior hit point is not a block face", #removed == 0)
a, b = grid()
local t = clock
start(actor, a, rb.Vector3.new(0, 2, 0))
for _ = 1, 8 do
	start(actor, b, rb.Vector3.new(0, -2, 0))
end
check("zero-time burst credits no blocks", #removed == 0)
advance(t + 0.049)
check("instant block still waits full 50ms budget", #removed == 0)
advance(t + 0.05)
check(
	"queued predecessor is credited at deadline",
	#removed == 1 and math.abs(removed[1].at - t - 0.05) < 1e-8
)
advance(t + 0.099)
check("queued next block cannot inherit predecessor elapsed time", #removed == 1)
advance(t + 0.1)
check(
	"lagged next block succeeds after actual foreground removal",
	#removed == 2 and p.stats.blocksClean == 2
)
a, b = grid()
t = clock
start(actor, a, rb.Vector3.new(0, 2, 0))
start(actor, b, rb.Vector3.new(0, -2, 0))
cancel(actor)
advance(t + 1)
check("cancel clears pending target and active timer", #removed == 0)
a, b = grid()
t = clock
start(actor, a, rb.Vector3.new(0, 2, 0))
m.generation += 1
advance(t + 1)
check("regeneration invalidates pending dig", #removed == 0)
a, b = grid()
t = clock
p.inventory[1].level = 1
local needed = C.breakTime(C.block("sand"), "shovel", 1, 0)
local pause = C.pauseAfter(m.location, needed)
start(actor, a, rb.Vector3.new(0, 2, 0))
advance(t + needed - 0.03)
start(actor, b, rb.Vector3.new(0, -2, 0))
advance(t + needed - 0.001)
check("jitter on slow dig does not credit early", #removed == 0)
advance(t + needed)
check("slow foreground completes at full deadline", #removed == 1)
advance(t + 2 * needed + pause - 0.001)
check("queued slow dig includes the vanilla post-break pause", #removed == 1)
advance(t + 2 * needed + pause + 0.001)
check("queued slow dig completes after full work plus pause", #removed == 2)
print(
	serde.encode(
		"json",
		{ passed = #checks, checks = checks, realProfiles = false, realDataStores = false },
		true
	)
)
