--!nocheck
-- Real auction/drop/gang handlers, mocked profiles/physics/store transport. No external writes.
local fs, serde, rb = require("@lune/fs"), require("@lune/serde"), require("@lune/roblox")
local base = fs.readFile("scripts/qa-economy-audit-offline.luau")
base = base:sub(1, assert(base:find("local p = fresh()", 1, true)) - 1)
local f = assert(loadstring(base .. [[
return {M=modules,services=services,players=players,profiles=profiles,actor=actor,recipient=recipient,
fresh=fresh,workspace=workspaceMock,tasks=fakeTask,random=fakeRandom,events=events}
]]))()
local M, services = f.M, f.services
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
local function load(path, transform, extra)
	local text = fs.readFile(path)
	if transform then
		text = transform(text)
	end
	local fn = assert(loadstring(text, "@" .. path))
	local env = {
		game = {
			GetService = function(_, id)
				return assert(services[id], id)
			end,
		},
		script = { Parent = names },
		require = function(id)
			return assert(M[id], id)
		end,
		workspace = f.workspace,
		task = f.tasks,
		Random = f.random,
		Vector3 = rb.Vector3,
		Color3 = rb.Color3,
		Enum = rb.Enum,
	}
	for k, v in extra or {} do
		env[k] = v
	end
	setfenv(fn, setmetatable(env, { __index = getfenv() }))
	return fn()
end
services.RunService.IsStudio = function()
	return false
end
for _, id in
	{ "DataStoreService", "MemoryStoreService", "MessagingService", "ServerStorage", "TextService" }
do
	services[id] = {}
end
for _, id in { "StorageNames", "Donate", "PrisPlus", "Auction", "Gangs" } do
	M[id] = load("src/shared/" .. id .. ".luau")
end
local permissions = {}
local function can(p)
	return permissions[p] == true
end
M.CommercePolicyService =
	{ CanTrade = can, RequireTrade = can, CanRandom = can, RequireRandom = can }
M.Strings.itemName = function(id)
	return id
end
M.Strings.itemFullName = function(id)
	return id
end
M.DonateService = { OnBought = function() end }
local a, b = f.actor, f.recipient
function b:GetAttribute()
	return nil
end
b.Parent = true
local online = { [a.UserId] = a, [b.UserId] = b }
function f.players:GetPlayerByUserId(id)
	return online[id]
end
local serial = 0
function services.HttpService:GenerateGUID()
	serial += 1
	return "mock-" .. serial
end
local saveHook
M.ProfileService.SaveNow = function(p)
	if saveHook then
		saveHook(p)
	end
	return true
end
local auction = load("src/server/Services/AuctionService.luau", function(s)
	return s:gsub(
		"return AuctionService%s*$",
		[[
ready=true;memoryLots={};memoryIndex={};cacheAt=os.clock()
return {sell=sell,buy=buy,cancel=cancel,settle=settleAll,query=query,
lots=function() return memoryLots end,
seed=function(lot) memoryLots[lot.id]=deepCopy(lot);indexSet(lot) end}
]]
	)
end)
local p = f.fresh(a)
p.inventory[1] = { id = "apple", count = 3 }
auction.sell(a, 1, 1, 1, nil)
check(
	"unknown auction seller cannot escrow",
	p.inventory[1].count == 3 and next(auction.lots()) == nil
)
permissions[a] = true
auction.sell(a, 1, 1, 1, nil)
local id = next(auction.lots())
local lot = auction.lots()[id]
check(
	"allowed listing captures server policy authorization",
	lot
		and lot.paidTradeAuthorized == true
		and lot.paidTradeAuthorizedAt > 0
		and p.inventory[1].count == 2
)
local buyer = f.fresh(b)
buyer.coins = 100000
auction.buy(b, id, lot.price)
check("unknown buyer cannot debit", buyer.coins == 100000 and lot.status == "active")
permissions[b] = true
permissions[a] = false
auction.buy(b, id, lot.price)
check(
	"online denied seller blocks buyer",
	buyer.coins == 100000 and auction.lots()[id].status == "active"
)
permissions[a] = true
saveHook = function(who)
	if who == b then
		permissions[a] = false
	end
end
auction.buy(b, id, lot.price)
saveHook = nil
check(
	"seller restriction during buyer save prevents sale and refunds",
	buyer.coins == 100000 and auction.lots()[id].status == "active" and next(buyer.inventory) == nil
)
permissions[a] = true
saveHook = function(who)
	if who == b then
		permissions[b] = false
	end
end
auction.buy(b, id, lot.price)
saveHook = nil
check(
	"buyer restriction during save prevents sale and refunds",
	buyer.coins == 100000 and auction.lots()[id].status == "active"
)
permissions[b] = true
online[a.UserId] = nil
auction.buy(b, id, lot.price)
check(
	"verified finite offline listing can settle",
	auction.lots()[id].status == "sold"
		and buyer.coins == 100000 - lot.price
		and M.InventoryService.count(buyer, "apple") == 1
)
online[a.UserId] = a
local old = {
	id = "legacy",
	item = { id = "apple", count = 1 },
	price = 10000,
	seller = a.UserId,
	sellerName = a.Name,
	createdAt = os.time(),
	expiresAt = os.time() + 100,
	status = "active",
}
auction.seed(old)
local before = buyer.coins
auction.buy(b, "legacy", old.price)
check(
	"unverified legacy listing cannot sell",
	buyer.coins == before and auction.lots().legacy.status == "active"
)
old.paidTradeAuthorized = true
old.paidTradeAuthorizedAt = 0 / 0
old.id = "nan-authorization"
auction.seed(old)
auction.buy(b, old.id, old.price)
check(
	"malformed authorization timestamp is denied",
	buyer.coins == before and auction.lots()[old.id].status == "active"
)
permissions[a] = true
auction.sell(a, 1, 1, 1, nil)
local cancelId
for key, value in auction.lots() do
	if key:match("^mock") and value.status == "active" then
		cancelId = key
	end
end
permissions[a] = false
auction.cancel(a, cancelId)
auction.settle(a)
check(
	"restricted seller can reclaim own cancelled listing",
	auction.lots()[cancelId].status == "cancelled" and M.InventoryService.count(p, "apple") == 2
)

-- Real drop spawn captures ownership; pickup/merge use that data, not item-id guessing.
local function primitive()
	local part = { attributes = {}, Position = rb.Vector3.zero }
	function part:SetAttribute(k, v)
		self.attributes[k] = v
	end
	function part:GetAttribute(k)
		return self.attributes[k]
	end
	function part:GetMass()
		return 1
	end
	function part:SetNetworkOwner() end
	function part:Destroy()
		self.destroyed = true
	end
	return part
end
services.CollectionService.AddTag = function() end
M.CollisionGroups = { DROPS = "drops" }
f.workspace.Gravity = 196.2
local drop = load("src/server/Services/ItemDropService.luau", function(s)
	return s:gsub(
		"return ItemDropService%s*$",
		[[
return {spawn=ItemDropService.Spawn,pickup=pickUp,merge=merge,drop=onDropItem,
clear=function() table.clear(drops);table.clear(order) end,all=function() return drops end}
]]
	)
end, {
	Instance = { new = primitive },
	PhysicalProperties = {
		new = function()
			return {}
		end,
	},
})
local root = {
	Position = rb.Vector3.zero,
	Size = rb.Vector3.new(2, 2, 1),
	IsA = function()
		return true
	end,
}
local character = {
	FindFirstChild = function()
		return root
	end,
	FindFirstChildOfClass = function()
		return { Health = 20, HipHeight = 0 }
	end,
	GetExtentsSize = function()
		return rb.Vector3.new(2, 5, 1)
	end,
}
a.Character, b.Character = character, character
local function spawn(from)
	drop.spawn({ id = "apple", count = 1 }, rb.Vector3.zero, rb.Vector3.zero, 0, from)
end
local function pickup(from, sourceAllowed, receiver, receiverAllowed, stillOnline)
	drop.clear()
	permissions[a] = sourceAllowed
	permissions[receiver] = receiverAllowed
	online[a.UserId] = if stillOnline then a else nil
	spawn(from)
	f.players.list = { receiver }
	local result = f.fresh(receiver)
	drop.pickup()
	return M.InventoryService.count(result, "apple")
end
check("natural mob loot available to restricted receiver", pickup(nil, false, b, false, true) == 1)
check("own restricted death loot can be reclaimed", pickup(a, false, a, false, true) == 1)
check("restricted source death loot cannot be exported", pickup(a, false, b, true, true) == 0)
check("restricted receiver cannot pick another player's loot", pickup(a, true, b, false, true) == 0)
check("both allowed players can exchange ground loot", pickup(a, true, b, true, true) == 1)
check("allowed drop remains authorized after owner leaves", pickup(a, true, b, true, false) == 1)
drop.clear()
permissions[a] = true
permissions[b] = true
online[a.UserId] = a
spawn(a)
permissions[a] = false
f.players.list = { b }
local bag = f.fresh(b)
drop.pickup()
check("current origin denial overrides captured allowed drop", next(bag.inventory) == nil)
drop.clear()
permissions[a] = true
spawn(a)
spawn(nil)
drop.merge()
local count = 0
for _ in drop.all() do
	count += 1
end
check("player loot cannot merge into unrestricted natural loot", count == 2)

-- Gang NPC guards occur before physical input consumption. Real proximity/rules/roll path below.
local npc = {
	Position = rb.Vector3.zero,
	IsA = function()
		return true
	end,
	IsDescendantOf = function()
		return true
	end,
}
services.CollectionService.GetTagged = function()
	return { npc }
end
local libraryPoints = 0
M.GangService = {
	gangOf = function()
		return "guild"
	end,
	level = function()
		return 1
	end,
	addLibrary = function(_, points)
		libraryPoints += points
		return nil
	end,
}
M.GangHouseService = {
	allowed = function()
		return true
	end,
}
M.LocationService = {}
M.ItemInfo = {
	bookName = function()
		return "Hammer"
	end,
}
local gang = load("src/server/Services/GangBaseService.luau", function(s)
	return s:gsub("return GangBaseService%s*$", "return {forge=forge,library=library}")
end)
local function books()
	local profile = f.fresh(a)
	profile.inventory[1] = {
		id = "ancient_book",
		count = 1,
		level = 1,
		books = { { id = "hammer", level = 1 } },
		rarity = "rare",
		applyChance = 70,
	}
	profile.inventory[2] = {
		id = "ancient_book",
		count = 1,
		level = 1,
		books = { { id = "hammer", level = 1 } },
		rarity = "rare",
		applyChance = 80,
	}
	profile.inventory[3] = { id = "ancient_star", count = 100 }
	return profile
end
permissions[a] = false
p = books()
gang.forge(a, 1, 2)
check(
	"restricted forge preserves both books and paid stars",
	p.inventory[2] ~= nil and p.inventory[3].count == 100
)
gang.library(a, 1)
check("restricted library cannot export a paid book", p.inventory[1] ~= nil and libraryPoints == 0)
permissions[a] = true
gang.forge(a, 1, 2)
check(
	"allowed forge still consumes inputs and rolls",
	p.inventory[2] == nil and p.inventory[3].count < 100 and p.inventory[1].books[1].level == 2
)
p = books()
gang.library(a, 1)
check("allowed library donation reaches gang", p.inventory[1] == nil and libraryPoints > 0)
local treasury = load("src/server/Services/GangService.luau", function(s)
	return s:gsub("return GangService%s*$", "return {deposit=deposit,withdraw=withdraw}")
end)
permissions[a] = false
p = f.fresh(a)
p.coins = 100000
treasury.deposit(a, 5)
treasury.withdraw(a, 5)
check(
	"restricted gang treasury handlers do not create journal or change balance",
	p.coins == 100000 and p.gangOps == nil
)
M.CommercePolicy = load("src/shared/CommercePolicy.luau")
M.Ghetto = load("src/shared/Ghetto.luau")
M.ItemDropService = drop
local ghetto = load("src/server/Services/GhettoService.luau", function(s)
	return s:gsub(
		"return GhettoService%s*$",
		[[
for _,item in Ghetto.blackItems() do stock[item.id]=5 end
return {trader=buyTrader,black=buyBlack}
]]
	)
end)
p = f.fresh(a)
p.coins = 10000000000
for _, id in { "ordinary_key", "ancient_star" } do
	ghetto.trader(a, id, 1)
	check(
		"restricted NPC trader input never charges " .. id,
		p.coins == 10000000000 and next(p.inventory) == nil
	)
end
for _, id in { "ancient_key", "improved_ancient_key", "ancient_powder" } do
	ghetto.black(a, id)
	check(
		"restricted black market input never charges " .. id,
		p.coins == 10000000000 and next(p.inventory) == nil
	)
end
ghetto.black(a, "dispeller")
check(
	"deterministic black market goods remain available",
	M.InventoryService.count(p, "dispeller") == 1
)
permissions[a] = true
ghetto.trader(a, "ordinary_key", 1)
check("allowed NPC trader purchase still grants", M.InventoryService.count(p, "ordinary_key") == 1)
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	actualAuctionDropGangHandlers = true,
	realProfiles = false,
	realDataStores = false,
	realPurchases = false,
}, true))
