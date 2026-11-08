--!nocheck
-- Actual release world sources in isolated service mocks/Lune Instances. No Studio or live assets.
local fs, serde, rb = require("@lune/fs"), require("@lune/serde"), require("@lune/roblox")
local env, checks = getfenv(), 0
local function check(name, ok)
	checks += 1
	assert(ok, name)
end
local function signal()
	return {
		Connect = function()
			return { Disconnect = function() end }
		end,
	}
end
local function node(name, attributes)
	local n =
		{ Name = name, attributes = attributes or {}, children = {}, Position = rb.Vector3.zero }
	function n:GetAttribute(k)
		return self.attributes[k]
	end
	function n:SetAttribute(k, v)
		self.attributes[k] = v
	end
	function n:IsA(k)
		return k == "BasePart" or k == "Part"
	end
	function n:IsDescendantOf()
		return true
	end
	function n:GetDescendants()
		return {}
	end
	function n:FindFirstChild(k)
		return self.children[k]
	end
	function n:FindFirstChildOfClass()
		return nil
	end
	function n:WaitForChild(k)
		return self.children[k]
	end
	function n:Destroy()
		self.destroyed = true
	end
	return n
end
local clock, randomIndex, randomUnit = 100, 1, 0.99
local rules = serde.decode("json", fs.readFile("src/shared/Config/rules.json"))
local config = {
	warzone = serde.decode("json", fs.readFile("src/shared/Config/warzone.json")),
	ghetto = serde.decode("json", fs.readFile("src/shared/Config/ghetto.json")),
	tools = serde.decode("json", fs.readFile("src/shared/Config/tools.json")),
	boosters = serde.decode("json", fs.readFile("src/shared/Config/boosters.json")),
	moneyScale = rules.money.scale,
	factions = rules.factions,
	factionColor = function()
		return rb.Color3.new(1, 0, 0)
	end,
}
config.faction = function(id)
	for _, faction in config.factions.list do
		if faction.id == id then
			return faction
		end
	end
	return nil
end
local factionA, factionB = config.factions.list[1].id, config.factions.list[2].id
local player = node("Player")
player.UserId, player.DisplayName = 11, "Tester"
player.profile = {
	faction = factionA,
	level = 50,
	location = "ghetto",
	coins = 1000000000,
	inventory = {},
	stats = {},
	gang = { id = "guild" },
}
local character, root = node("Character"), node("HumanoidRootPart")
local humanoid = { Health = 100 }
character.FindFirstChildOfClass = function()
	return humanoid
end
character.children.HumanoidRootPart = root
player.Character = character
local tags, toasts, external = {}, {}, {}
local collection = {
	GetTagged = function(_, k)
		return tags[k] or {}
	end,
	GetInstanceAddedSignal = signal,
}
local replicated = node("ReplicatedStorage")
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
replicated.Shared = names
replicated.WaitForChild = function()
	return names
end
local services = {
	ReplicatedStorage = replicated,
	CollectionService = collection,
	Players = {
		GetPlayers = function()
			return { player }
		end,
		GetPlayerByUserId = function(_, id)
			return if id == 11 then player else nil
		end,
	},
	RunService = {
		IsStudio = function()
			return false
		end,
		Heartbeat = signal(),
	},
	HttpService = {},
	ServerStorage = {},
}
local modules = {
	Config = config,
	Types = {},
	Remotes = {
		event = function()
			return {
				FireClient = function(_, _, key)
					table.insert(toasts, key)
				end,
			}
		end,
	},
	Strings = {
		t = function(k)
			return k
		end,
		localeOf = function()
			return "en"
		end,
		itemName = function(k)
			return k
		end,
		money = tostring,
	},
	ProfileService = {
		Get = function(p)
			return p.profile
		end,
		Mutate = function(p, fn)
			fn(p.profile)
		end,
	},
	ChatService = {
		announce = function() end,
		announceWith = function(fn)
			fn("en")
		end,
	},
	FactionService = {
		Of = function(p)
			return p.profile.faction
		end,
	},
	NeedsService = {
		SetWarzoneHaste = function(p, level)
			p.haste = level
		end,
	},
	AchievementService = { OnStat = function() end },
	Sfx = { toPlayer = function() end },
	GangService = {
		gangOf = function(p)
			return p and p.gang
		end,
		level = function(p)
			return if p and p.gang then 1 else 0
		end,
	},
	GangHouseService = {
		allowed = function(part)
			return part.allowed ~= false
		end,
	},
	ItemDropService = {
		SpawnLoot = function(stack)
			table.insert(external, stack)
		end,
	},
	LocationService = { Request = function() end },
	MineService = {},
	CombatService = {},
	FallService = {},
	Boosters = {
		storedCount = function(p)
			return p.boosterCount or 0
		end,
		store = function(p)
			p.boosterCount = (p.boosterCount or 0) + 1
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
			workspace = {
				GetServerTimeNow = function()
					return clock
				end,
			},
			script = { Parent = names },
			require = function(k)
				return assert(modules[k], k)
			end,
			os = {
				clock = function()
					return clock
				end,
				time = function()
					return math.floor(clock)
				end,
			},
			Random = {
				new = function()
					return {
						NextInteger = function(_, low, high)
							return math.clamp(randomIndex, low, high)
						end,
						NextNumber = function()
							return randomUnit
						end,
					}
				end,
			},
			Vector3 = rb.Vector3,
			CFrame = rb.CFrame,
			Color3 = rb.Color3,
			Instance = rb.Instance,
		}, { __index = env })
	)
	return fn()
end
local function expose(name, extra)
	return function(source)
		return source:gsub("return " .. name .. "%s*$", extra .. "\nreturn " .. name)
	end
end
modules.Numbers = load("src/shared/Numbers.luau")
modules.InventoryService = load("src/server/Services/InventoryService.luau")
modules.Warzone = load("src/shared/Warzone.luau")
local warzone = load(
	"src/server/Services/WarzoneService.luau",
	expose(
		"WarzoneService",
		"WarzoneService._points=points; WarzoneService._next=nextRound; WarzoneService._tick=tick"
	)
)
local mirrored = node("Warzone")
replicated.children.Warzone = mirrored
tags.WarzonePoint, tags.WarzoneBeam = {}, {}
for _, def in modules.Warzone.points do
	local folder = node(def.id)
	mirrored.children[def.id] = folder
	warzone._points[def.id] = {
		def = def,
		folder = folder,
		active = false,
		scores = {},
		diggers = {},
		started = {},
		since = 0,
		untilAt = 0,
		lastDigAt = 0,
		lastDecayAt = 0,
	}
	table.insert(tags.WarzonePoint, node(def.id, { Point = def.id }))
	table.insert(tags.WarzoneBeam, node(def.id, { Point = def.id }))
end
local function activeCount()
	local n = 0
	for _, p in warzone._points do
		if p.active then
			n += 1
		end
	end
	return n
end
for index, def in modules.Warzone.points do
	randomIndex = index
	check("random selection starts a valid round " .. def.id, warzone._next())
	check(
		"exactly the selected point is active " .. def.id,
		activeCount() == 1 and modules.Warzone.state(def.id).active
	)
end
randomIndex = 1
warzone._next()
local first, second = modules.Warzone.points[1], modules.Warzone.points[2]
warzone.OnDug(player, modules.Warzone.mineId(second.id))
check("inactive pad grants no score", next(warzone._points[second.id].scores) == nil)
for _ = 1, config.warzone.captureScore do
	warzone.OnDug(player, modules.Warzone.mineId(first.id))
end
check(
	"capture grants only current point and credits actual digger",
	modules.Warzone.heldBy(factionA) == 1
		and player.profile.stats.warzonePoints == 1
		and #modules.Warzone.bonuses(player.profile) == 1
)
player.profile.faction = factionB
warzone.OnDug(player, modules.Warzone.mineId(first.id))
check(
	"held point cannot be captured again before expiry",
	modules.Warzone.state(first.id).owner == factionA
)
randomIndex = 4
clock += config.warzone.holdMinutes * 60 + 1
warzone._tick()
check(
	"hold expiry removes old owner and activates one new random point",
	activeCount() == 1
		and modules.Warzone.state("haste").active
		and modules.Warzone.heldBy(factionA) == 0
)
for _ = 1, config.warzone.captureScore do
	warzone.OnDug(player, "warzone_haste")
end
check("Haste source follows the sole held point", player.haste == config.warzone.hasteLevel)
randomIndex = 2
clock += config.warzone.holdMinutes * 60 + 1
warzone._tick()
check("new round revokes previous Haste source", player.haste == nil and activeCount() == 1)

modules.Ghetto = load("src/shared/Ghetto.luau")
modules.CommercePolicy = load("src/shared/CommercePolicy.luau")
modules.CommercePolicyService = {
	RequireRandom = function()
		return true
	end,
}
local ghetto = load(
	"src/server/Services/GhettoService.luau",
	expose(
		"GhettoService",
		"GhettoService._buy=buyTrader; GhettoService._black=buyBlack; GhettoService._restock=restock; GhettoService._valid=validHold; GhettoService._holds=updateHolds; GhettoService._capture=capture; GhettoService._set=function(t) treasure=t end"
	)
)
tags.GhettoTrader, tags.BlackMarket = { node("Trader") }, { node("Black") }
local balance = player.profile.coins
ghetto._buy(player, "ordinary_key", 0 / 0)
ghetto._buy(player, "ordinary_key", 1.5)
check(
	"malformed trader counts do not purchase a fallback item",
	player.profile.coins == balance and next(player.profile.inventory) == nil
)
ghetto._buy(player, "ordinary_key", 2)
check(
	"trader charges configured total and delivers quantity",
	player.profile.coins == balance - config.ghetto.trader.ordinary_key * config.moneyScale * 2
		and modules.InventoryService.count(player.profile, "ordinary_key") == 2
)
ghetto._restock()
player.profile.level = 19
balance = player.profile.coins
ghetto._black(player, config.ghetto.blackMarket.items[1].id)
check("black market rejects below-level purchase without charging", player.profile.coins == balance)
player.profile.level = 20
tags.BlackMarket[1].allowed = false
ghetto._black(player, config.ghetto.blackMarket.items[1].id)
check("foreign gang-house NPC cannot be used", player.profile.coins == balance)
tags.BlackMarket[1].allowed = true
ghetto._black(player, config.ghetto.blackMarket.items[1].id)
check(
	"eligible black market purchase charges and delivers",
	modules.InventoryService.count(player.profile, "ancient_key") == 1
		and player.profile.coins < balance
)
local body = node("Body")
local model = node("Chest")
model.PrimaryPart = body
local treasure = { model = model, point = node("Point"), holds = {} }
ghetto._set(treasure)
local hold = {
	character = character,
	position = root.Position,
	startedAt = clock - 10,
	connection = { Disconnect = function() end },
}
treasure.holds[player] = hold
check("eligible stationary living character has valid hold", ghetto._valid(treasure, player, hold))
root.Position = rb.Vector3.new(3, 0, 0)
check("moving away cancels hold", not ghetto._valid(treasure, player, hold))
root.Position = rb.Vector3.zero
humanoid.Health = 0
check("dead character cannot complete hold", not ghetto._valid(treasure, player, hold))
humanoid.Health = 100
hold.endedAt = clock - 1
check("old completed hold cannot be replayed", not ghetto._valid(treasure, player, hold))
hold.endedAt = clock
check(
	"immediate HoldEnded to Triggered handoff remains valid",
	ghetto._valid(treasure, player, hold)
)
player.profile.gang = nil
check("lost access cancels treasure hold", not ghetto._valid(treasure, player, hold))
player.profile.gang = { id = "guild" }
player.Character = node("Respawn")
check("respawn cannot inherit old hold", not ghetto._valid(treasure, player, hold))
player.Character = character
randomUnit = 0.99
balance = player.profile.coins
ghetto._capture(player)
check(
	"treasure money outcome delivered once and source disappears",
	player.profile.coins == balance + 5000 * config.moneyScale
		and model.destroyed
		and player.profile.stats.ghettoChests == 1
)
ghetto._capture(player)
check("second capture cannot replay reward", player.profile.stats.ghettoChests == 1)

local mineNpc =
	load("src/server/Services/GhettoMineService.luau", expose("Service", "Service._act=act"))
player.profile.inventory =
	{ [1] = { id = "stone", count = 64 }, [2] = { id = "cobblestone", count = 64 } }
player.profile.stats.ghettoMasonStones = 0
mineNpc._act(player, "GhettoMason")
check(
	"mason remembers partial submission",
	player.profile.stats.ghettoMasonStones == 128 and next(player.profile.inventory) == nil
)
player.profile.inventory = { [1] = { id = "stone", count = 64 }, [2] = { id = "stone", count = 8 } }
mineNpc._act(player, "GhettoMason")
check(
	"mason pays one stored booster at completed total",
	player.profile.boosterCount == 1 and player.profile.stats.ghettoMasonStones == 0
)
player.profile.inventory = { [1] = { id = "iron_ore", count = config.ghetto.gangMine.passOre } }
mineNpc._act(player, "GhettoPassDealer")
check(
	"pass dealer exchanges exact ore for one unstackable pass",
	modules.InventoryService.count(player.profile, "gang_mine_pass") == 1
		and modules.InventoryService.count(player.profile, "iron_ore") == 0
)

local lighting = load("src/shared/MineLighting.luau", function(s)
	return s:gsub("anchor%.Position", "anchor.CFrame.Position")
end)
for _, size in { { 32, 12, 32 }, { 40, 16, 40 }, { 12, 8, 12 }, { 5, 3, 5 } } do
	local anchor = rb.Instance.new("Part")
	anchor.Size = rb.Vector3.new(size[1] * 4, 0.2, size[3] * 4)
	anchor.CFrame = rb.CFrame.new(100, 15000, 200) * rb.CFrame.Angles(0, 0.7, 0)
	local n = lighting.Apply(anchor, size)
	lighting.Apply(anchor, size)
	check("lighting is bounded and idempotent " .. size[1], #anchor:GetChildren() == n and n <= 9)
	local soft = true
	for _, attachment in anchor:GetChildren() do
		local light = attachment:FindFirstChild("Fill")
		soft = soft and light.Brightness <= 0.401 and not light.Shadows and light.Range == 60
	end
	check("fill is soft and shadowless " .. size[1], soft)
	local farthest = 0
	for _, x in { -size[1] * 2, 0, size[1] * 2 } do
		for _, y in { 0, -size[2] * 4 } do
			for _, z in { -size[3] * 2, 0, size[3] * 2 } do
				local p = anchor.CFrame.Position + rb.Vector3.new(x, 0.1 + y, z)
				local nearest = math.huge
				for _, attachment in anchor:GetChildren() do
					nearest = math.min(
						nearest,
						(anchor.CFrame:PointToWorldSpace(attachment.CFrame.Position) - p).Magnitude
					)
				end
				farthest = math.max(farthest, nearest)
			end
		end
	end
	check("light coverage reaches corners and deepest floor " .. size[1], farthest < 60)
end
print(
	string.format(
		"Release world PASS: %d actual-source checks; engine mocks/Lune instances, no Studio",
		checks
	)
)
