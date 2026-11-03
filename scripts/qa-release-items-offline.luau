--!nocheck
-- Actual-source, offline-only release regressions. No Marketplace purchase, real profile, or DataStore.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local base = fs.readFile("scripts/qa-economy-audit-offline.luau")
base = base:sub(1, assert(base:find("local p = fresh()", 1, true)) - 1)
local f = assert(loadstring(base .. [[
return {modules=modules, profiles=profiles, actor=actor, recipient=recipient, fresh=fresh, services=services,
events=events, players=players, fakeTask=fakeTask, fakeRandom=fakeRandom, workspace=workspaceMock,
setClock=function(t) clock=t end, getClock=function() return clock end}
]]))()
local M, C, actor = f.modules, f.modules.Config, f.actor
M.Strings.itemName = function(id)
	return id
end
local checks = {}
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
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
local function signal()
	local callbacks = {}
	return {
		Connect = function(_, fn)
			table.insert(callbacks, fn)
			return {
				Disconnect = function()
					local i = table.find(callbacks, fn)
					if i then
						table.remove(callbacks, i)
					end
				end,
			}
		end,
		Fire = function(_, ...)
			for _, fn in table.clone(callbacks) do
				fn(...)
			end
		end,
	}
end
local names = setmetatable({}, {
	__index = function(_, k)
		return k
	end,
})
local function load(path, transform, extra)
	local source = fs.readFile(path)
	if transform then
		source = transform(source)
	end
	local fn = assert(loadstring(source, "@" .. path))
	local environment = {
		game = {
			GetService = function(_, k)
				return assert(f.services[k], k)
			end,
		},
		script = { Parent = names },
		require = function(k)
			return assert(M[k], k)
		end,
		workspace = f.workspace,
		task = f.fakeTask,
		Random = f.fakeRandom,
		Vector3 = rb.Vector3,
		Vector2 = rb.Vector2,
		UDim2 = rb.UDim2,
		UDim = rb.UDim,
		Color3 = rb.Color3,
		Enum = rb.Enum,
		os = setmetatable({ clock = f.getClock }, { __index = os }),
	}
	for k, v in extra or {} do
		environment[k] = v
	end
	setfenv(fn, setmetatable(environment, { __index = getfenv() }))
	return fn()
end
for _, name in { "Effects", "Potions", "PrisPlus", "Donate", "Auction" } do
	M[name] = load("src/shared/" .. name .. ".luau")
end
f.services.StarterPlayer = {}
local hunger = load("src/server/Services/HungerService.luau", function(s)
	return s:gsub("return HungerService%s*$", "HungerService.update=update; return HungerService")
end)
M.HungerService = hunger
M.MineService = {}
M.BookService = load("src/server/Services/BookService.luau", function(s)
	return s:gsub("return BookService%s*$", "BookService.springs=springs; return BookService")
end)
local attrs = {}
local h = {
	Health = 20,
	MaxHealth = 20,
	MoveDirection = rb.Vector3.zero,
	IsA = function()
		return true
	end,
}
local character = {
	Parent = true,
	GetAttribute = function(_, k)
		return attrs[k]
	end,
	SetAttribute = function(_, k, v)
		attrs[k] = v
	end,
	FindFirstChildOfClass = function()
		return h
	end,
}
actor.Character = character
f.players.list = { actor }
local randomValue = 0
f.fakeRandom.new = function()
	return {
		NextNumber = function()
			return randomValue
		end,
	}
end
local food = load("src/server/Services/FoodService.luau", function(s)
	return s:gsub("return FoodService%s*$", "return {start=onStart,update=update,cancel=stop}")
end)
check(
	"vanilla rotten flesh config",
	C.rules.survival.food.rotten_flesh == 4 and C.rules.survival.saturation.rotten_flesh == 0.8
)
check("vanilla Hunger drain config", M.Potions.HUNGER_PER_SECOND == 0.025)
local effect = C.rules.survival.foodEffects.rotten_flesh[1]
check(
	"vanilla rotten chance/duration config",
	effect.chance == 0.8 and effect.level == 1 and effect.seconds == 30
)
local function eat(roll)
	local p = f.fresh()
	p.hunger = 10
	p.saturation = nil
	p.inventory[1] = { id = "rotten_flesh", count = 2 }
	attrs = {}
	randomValue = roll
	f.setClock(100)
	food.start(actor, 1)
	f.setClock(101.59)
	food.update()
	check("food not consumed early " .. roll, p.inventory[1].count == 2)
	f.setClock(101.61)
	food.update()
	return p
end
local p = eat(0.79999)
check(
	"rotten feeds once and applies Hunger",
	p.hunger == 14
		and p.saturation == 0.8
		and p.inventory[1].count == 1
		and attrs.Hunger == 1
		and math.abs(attrs.HungerUntil - 131.61) < 1e-6
)
M.BookService.GiveHunger(actor, 1, 30)
check(
	"repeat food refreshes without duration stacking",
	math.abs(attrs.HungerUntil - 131.61) < 1e-6
)
local idle = C.rules.survival.hunger.drainPerMinuteIdle
C.rules.survival.hunger.drainPerMinuteIdle = 0
f.setClock(110)
hunger.update(30)
check(
	"Hunger I causes actual 3 exhaustion equivalent in30s",
	math.abs(p.saturation - 0.05) < 1e-6 and p.hunger == 14
)
f.setClock(132)
local sat = p.saturation
hunger.update(1)
check("expired Hunger stops draining", p.saturation == sat)
C.rules.survival.hunger.drainPerMinuteIdle = idle
p = eat(0.8)
check("20 percent safe food branch", attrs.Hunger == nil and p.hunger == 14 and p.saturation == 0.8)
f.setClock(200)
p.hunger = 20
food.start(actor, 1)
f.setClock(202)
food.update()
check("full hunger refuses rotten flesh", p.inventory[1].count == 1)

-- Silk changes drops only, not tool-level/efficiency/haste timing. Wrong-tier drops are an owner rule.
for _, spec in
	{
		{ "stone", "pickaxe", 1 },
		{ "iron_ore", "pickaxe", 1 },
		{ "stone", "pickaxe", 16 },
		{ "sand", "shovel", 8 },
		{ "melon", "axe", 1 },
	}
do
	local id, tool, level = table.unpack(spec)
	p = f.fresh()
	p.inventory[1] = { id = tool, count = 1, level = level, books = {} }
	local block = C.block(id)
	local plain = C.breakTime(block, tool, level, 1)
	p.inventory[1].books = { { id = "silk_touch", level = 1 } }
	local silk = M.BookService.silkTouch(p)
	local same = C.breakTime(block, tool, level, 1)
	local drop, n = M.MiningDrops.resolve(block, silk, {
		NextInteger = function(_, a)
			return a
		end,
	})
	check(
		"Silk preserves speed and original single drop " .. id .. level,
		silk and same == plain and drop == id and n == 1
	)
end
check(
	"under-tier pickaxe still takes slower time",
	C.breakTime(C.block("iron_ore"), "pickaxe", 1) > C.breakTime(C.block("iron_ore"), "pickaxe", 9)
)

-- Spring controller: real events and real Vector3; preserve both horizontal components.
p = f.fresh()
h.JumpHeight = 4.2
p.armor.boots = { id = "boots", count = 1, level = 1, books = { { id = "springs", level = 1 } } }
M.BookService.springs(actor, p)
check(
	"server publishes Springs extra-jump height",
	math.abs(attrs.SpringsJumpHeight - 5.2) < 1e-6 and h.UseJumpPower == false
)
p.armor.boots = nil
M.BookService.springs(actor, p)
check("unequipping Springs revokes extra jump", attrs.SpringsJumpHeight == nil)
local state = rb.Enum.HumanoidStateType.Running
h.StateChanged = signal()
h.FloorMaterial = rb.Enum.Material.Concrete
h.GetState = function()
	return state
end
h.ChangeState = function(_, v)
	local old = state
	state = v
	h.StateChanged:Fire(old, v)
end
local root = {
	AssemblyLinearVelocity = rb.Vector3.new(22, -8, 7),
	IsA = function()
		return true
	end,
}
character.FindFirstChild = function()
	return root
end
character.WaitForChild = function()
	return h
end
f.services.UserInputService = {
	JumpRequest = signal(),
	InputEnded = signal(),
	GetFocusedTextBox = function()
		return nil
	end,
}
f.players.LocalPlayer = actor
actor.CharacterAdded = signal()
f.workspace.Gravity = 196.2
local jump = load(
	"src/client/SpringJump.luau",
	nil,
	{ task = {
		spawn = function(fn, ...)
			fn(...)
		end,
	} }
)
jump.start()
local input = f.services.UserInputService
local function release()
	input.InputEnded:Fire({ KeyCode = rb.Enum.KeyCode.Space })
end
attrs.SpringsJumpHeight = 8.2
f.setClock(300)
input.JumpRequest:Fire()
h.FloorMaterial = rb.Enum.Material.Air
h:ChangeState(rb.Enum.HumanoidStateType.Jumping)
f.setClock(300.2)
input.JumpRequest:Fire()
check("held first jump cannot consume airborne charge", root.AssemblyLinearVelocity.Y == -8)
release()
local originalAttribute = actor.GetAttribute
actor.GetAttribute = function(_, key)
	return key == "LoadingBlocked"
end
input.JumpRequest:Fire()
check(
	"loading gate refuses extra jump without spending the charge",
	root.AssemblyLinearVelocity.Y == -8
)
actor.GetAttribute = originalAttribute
release()
input.JumpRequest:Fire()
check(
	"Spring extra jump preserves exact sprint velocity",
	root.AssemblyLinearVelocity.X == 22
		and root.AssemblyLinearVelocity.Z == 7
		and root.AssemblyLinearVelocity.Y > 0
)
root.AssemblyLinearVelocity = rb.Vector3.new(22, -3, 7)
release()
input.JumpRequest:Fire()
check("no third jump in same airborne period", root.AssemblyLinearVelocity.Y == -3)
h.FloorMaterial = rb.Enum.Material.Concrete
h:ChangeState(rb.Enum.HumanoidStateType.Landed)
release()
input.JumpRequest:Fire()
check("landing never produces extra grounded impulse", root.AssemblyLinearVelocity.Y == -3)
h.FloorMaterial = rb.Enum.Material.Air
h:ChangeState(rb.Enum.HumanoidStateType.Freefall)
f.setClock(301)
release()
attrs.SpringsJumpHeight = nil
input.JumpRequest:Fire()
check("no extra jump without Springs boots", root.AssemblyLinearVelocity.Y == -3)
attrs.SpringsJumpHeight = 5.2
release()
input.JumpRequest:Fire()
check("landing restores exactly one extra jump", root.AssemblyLinearVelocity.Y > 0)

-- Actual Sprint controller through input/heartbeat; the second jump must not revoke sprint.
input.InputBegan = signal()
input.TouchEnabled = false
f.services.RunService.Heartbeat = signal()
local sprintEvent = M.Remotes.event("Sprint")
local sprintIntents = {}
sprintEvent.FireServer = function(_, on)
	table.insert(sprintIntents, on)
end
local sprint = load(
	"src/client/Sprint.luau",
	nil,
	{ Instance = {
		new = function()
			return { Activated = signal() }
		end,
	} }
)
sprint.start({})
state = rb.Enum.HumanoidStateType.Running
h.MoveDirection = rb.Vector3.xAxis
input.InputBegan:Fire({ KeyCode = rb.Enum.KeyCode.LeftShift }, false)
f.services.RunService.Heartbeat:Fire()
check("keyboard sprint starts normally", sprintIntents[#sprintIntents] == true)
state = rb.Enum.HumanoidStateType.Freefall
h.MoveDirection = rb.Vector3.zero
f.setClock(302)
f.services.RunService.Heartbeat:Fire()
f.setClock(302.3)
f.services.RunService.Heartbeat:Fire()
check("midair direction gap does not cancel sprint", #sprintIntents == 1)
state = rb.Enum.HumanoidStateType.Running
f.services.RunService.Heartbeat:Fire()
f.setClock(302.5)
f.services.RunService.Heartbeat:Fire()
check("stationary landing still cancels sprint", sprintIntents[#sprintIntents] == false)

-- Actual auction query, comparator, cache insertion/update/removal with mixed currencies and ties.
for _, name in { "DataStoreService", "MemoryStoreService", "MessagingService", "ServerStorage" } do
	f.services[name] = {}
end
M.DonateService = { OnBought = function() end }
local auction = load("src/server/Services/AuctionService.luau", function(s)
	return s:gsub(
		"return AuctionService%s*$",
		[[
ready=true; memoryIndex={};cacheAt=os.clock()
return {query=query,add=indexSet,remove=indexRemove}
]]
	)
end)
local now = os.time()
local lots = {
	{
		id = "a",
		item = { id = "pickaxe", level = 4, count = 1 },
		price = 30000,
		sellerName = "One",
		createdAt = now - 4,
	},
	{
		id = "b",
		item = { id = "sword", level = 2, count = 1 },
		price = 10000,
		sellerName = "Two",
		createdAt = now - 2,
	},
	{
		id = "c",
		item = { id = "pickaxe", level = 4, count = 1 },
		price = 30000,
		sellerName = "One",
		createdAt = now - 4,
	},
	{
		id = "d",
		item = { id = "apple", count = 3 },
		price = 9,
		cur = "rubies",
		sellerName = "Four",
		createdAt = now - 1,
	},
	{
		id = "e",
		item = { id = "apple", count = 1 },
		price = 2,
		cur = "rubies",
		sellerName = "Five",
		createdAt = now - 5,
	},
}
for _, lot in lots do
	lot.expiresAt = now + 100
	lot.seller = 1
	auction.add(lot)
end
local function query(q)
	f.setClock(f.getClock() + 1)
	return auction.query(actor, q)
end
local expected = {
	time = { "e,a,c,b,d", "d,b,a,c,e" },
	price = { "b,a,c,e,d", "a,c,b,d,e" },
	level = { "d,e,b,a,c", "a,c,b,d,e" },
}
local function ids(a)
	local out = {}
	for _, lot in a.lots do
		table.insert(out, lot.id)
	end
	return table.concat(out, ",")
end
for sort, answers in expected do
	for i, desc in { false, true } do
		check(
			"auction " .. sort .. " " .. tostring(desc),
			ids(query({ sort = sort, desc = desc })) == answers[i]
		)
	end
end
local added = copy(lots[1])
added.id = "new"
added.price = 5000
added.createdAt = now
added.item.level = 20
auction.add(added)
check(
	"new listing participates immediately in price order",
	query({ sort = "price", desc = false }).lots[1].id == "new"
)
local afterAdd = {
	time = { "e,a,c,b,d,new", "new,d,b,a,c,e" },
	price = { "new,b,a,c,e,d", "a,c,b,new,d,e" },
	level = { "d,e,b,a,c,new", "new,a,c,b,d,e" },
}
for sort, answers in afterAdd do
	for i, desc in { false, true } do
		check(
			"new lot reorders " .. sort .. " " .. tostring(desc),
			ids(query({ sort = sort, desc = desc })) == answers[i]
		)
	end
end
added.price = 99000
auction.add(added)
check(
	"listing replacement does not duplicate sort entries",
	query({ sort = "price", desc = true }).lots[1].id == "new"
		and query({ sort = "time" }).total == 6
)
auction.remove("new")
check("removed listing absent after resort", query({ sort = "time" }).total == 5)
check("auction category/search/price/level filter together", ids(query({
	sort = "time",
	category = "tools",
	search = "One",
	minPrice = 3,
	maxPrice = 3,
	minLevel = 4,
	maxLevel = 4,
})) == "a,c")

-- Every configured product gives something; every tab item resolves; no real purchases.
for i = 1, C.auction.pageSize + 4 do
	local lot = copy(lots[1])
	lot.id = "page" .. string.format("%03d", i)
	lot.createdAt = now + i
	auction.add(lot)
end
local page1, page2 = query({ sort = "time", page = 1 }), query({ sort = "time", page = 2 })
local seen = {}
for _, lot in page1.lots do
	seen[lot.id] = true
end
local disjoint = true
for _, lot in page2.lots do
	if seen[lot.id] then
		disjoint = false
	end
end
check(
	"sorted pagination has no duplicate or omitted rows",
	#page1.lots == C.auction.pageSize
		and #page2.lots == 9
		and disjoint
		and page2.total == C.auction.pageSize + 9
)

local metadata, metadataReads, prompts = {}, {}, {}
f.services.MarketplaceService = {
	GetProductInfoAsync = function(_, id)
		metadataReads[id] = (metadataReads[id] or 0) + 1
		if metadata[id] == false then
			error("injected Marketplace read failure")
		end
		if metadata[id] then
			return copy(metadata[id])
		end
		local pack, itemId = M.Donate.byProduct(id)
		local item = itemId and M.Donate.item(itemId)
		local entry = pack or item
		return { Name = entry.productName, PriceInRobux = entry.robux, IsForSale = true }
	end,
	PromptProductPurchase = function(_, _, id)
		table.insert(prompts, id)
	end, -- isolated recorder, never an engine purchase
}
f.services.RunService.IsStudio = function()
	return false
end
f.players.GetPlayerByUserId = function(_, id)
	return if id == actor.UserId then actor else nil
end
local disk, saveFault, onCheckpoint
M.ProfileService.SaveNow = function()
	if saveFault == "before" then
		return false
	end
	disk = copy(f.profiles[actor])
	return saveFault ~= "after"
end
M.ProfileService.MutateDurable = function(_, transform)
	local staged = copy(f.profiles[actor])
	transform(staged)
	if saveFault == "before" then
		return false
	end
	disk = copy(staged)
	if saveFault == "after" then
		return false
	end
	if onCheckpoint then
		onCheckpoint()
	end
	transform(f.profiles[actor])
	return true
end
local donate = load("src/server/Services/DonateService.luau", function(s)
	return s:gsub(
		"return DonateService%s*$",
		"return {receipt=processReceipt,buy=onBuy,claim=onClaim,topUp=onTopUp,robux=onBuyRobux}"
	)
end)
local allProducts, missingProducts = {}, {}
for _, tab in M.Donate.tabs do
	for _, id in tab.items or {} do
		check("donate tab resolves " .. id, M.Donate.item(id) ~= nil)
	end
end
local function outcome(p, item)
	if item.give then
		return M.InventoryService.count(p, item.give) + (p.stash and p.stash[1].count or 0)
			== (item.each or 1)
	end
	if item.booster then
		return M.Boosters.storedCount(p) == #item.booster.kinds
	end
	if item.auctionSlot then
		return M.InventoryService.count(p, M.Donate.AUCTION_SLOT) == 1
	end
	if item.prisDays then
		return M.PrisPlus.active(p)
	end
	if item.noFee then
		return p.noAuctionFee == true
	end
	if item.rubies then
		return p.rubies == item.rubies
	end
	if item.announce then
		return p.announceCredits == 1
	end
	return false
end
for id, item in C.donate.items do
	p = f.fresh()
	p.crystals = 100000
	p.rubies = 0
	f.setClock(f.getClock() + 1)
	donate.buy(actor, id, 1)
	check("crystal purchase grants " .. id, outcome(p, item) and p.crystals == 100000 - item.price)
	if item.productId > 0 then
		check("unique product " .. id, allProducts[item.productId] == nil)
		allProducts[item.productId] = id
		p = f.fresh()
		local result = donate.receipt({
			ProductId = item.productId,
			PlayerId = actor.UserId,
			PurchaseId = "item-" .. id,
		})
		check(
			"receipt grants " .. id,
			result == rb.Enum.ProductPurchaseDecision.PurchaseGranted and outcome(p, item)
		)
	elseif item.robux > 0 then
		table.insert(missingProducts, id)
	end
end
for _, pack in M.Donate.packs do
	if pack.productId == 0 then
		table.insert(missingProducts, pack.id)
	end
end
local receiptPacks = table.clone(M.Donate.legacyPacks)
for _, pack in M.Donate.packs do
	if pack.productId > 0 then
		table.insert(receiptPacks, pack)
	end
end
for _, pack in receiptPacks do
	check(
		"unique pack product " .. pack.id,
		pack.productId > 0 and allProducts[pack.productId] == nil
	)
	allProducts[pack.productId] = pack.id
	p = f.fresh()
	donate.receipt({
		ProductId = pack.productId,
		PlayerId = actor.UserId,
		PurchaseId = "pack-" .. pack.id,
	})
	check("pack receipt grants exact crystals " .. pack.id, p.crystals == pack.crystals)
	donate.receipt({
		ProductId = pack.productId,
		PlayerId = actor.UserId,
		PurchaseId = "pack-" .. pack.id,
	})
	check("legacy pack receipt retry stays exact " .. pack.id, p.crystals == pack.crystals)
end
check(
	"current pack quantities stay owner-approved",
	M.Donate.packs[1].crystals == 80
		and M.Donate.packs[1].robux == 80
		and M.Donate.byProduct(3723068679).crystals == 100
)
local ordinary = C.donate.items.ordinary_key
p = f.fresh()
f.setClock(f.getClock() + 1)
metadata[ordinary.productId] = { Name = ordinary.productName, PriceInRobux = ordinary.robux + 1 }
donate.robux(actor, "ordinary_key")
check("mismatched live price never prompts", #prompts == 0)
metadata[ordinary.productId] = { Name = ordinary.productName, PriceInRobux = ordinary.robux }
f.setClock(f.getClock() + 1)
donate.robux(actor, "ordinary_key")
check(
	"mismatch cache avoids per-click Marketplace reads",
	#prompts == 0 and metadataReads[ordinary.productId] == 1
)
f.setClock(f.getClock() + 61)
donate.robux(actor, "ordinary_key")
check(
	"catalog repair becomes promptable after bounded cache",
	#prompts == 1 and metadataReads[ordinary.productId] == 2
)
metadata[ordinary.productId] = { Name = "Wrong quantity", PriceInRobux = ordinary.robux }
f.setClock(f.getClock() + 61)
donate.robux(actor, "ordinary_key")
check("mismatched product identity never prompts", #prompts == 1)
metadata[ordinary.productId] = false
f.setClock(f.getClock() + 61)
donate.robux(actor, "ordinary_key")
check("failed Marketplace read fails closed", #prompts == 1)
metadata[ordinary.productId] = {
	Name = ordinary.productName,
	PriceInRobux = ordinary.robux - 1,
	UserBasePriceInRobux = ordinary.robux,
}
f.setClock(f.getClock() + 6)
donate.robux(actor, "ordinary_key")
check("read retry recovers and base-price discount is accepted", #prompts == 2)
for _, pack in M.Donate.packs do
	if pack.productId == 0 then
		f.setClock(f.getClock() + 1)
		donate.topUp(actor, pack.id)
	end
end
check(
	"unregistered current packs never prompt or grant free live crystals",
	#prompts == 2 and (p.crystals or 0) == 0
)
local observed =
	serde.decode("json", fs.readFile("docs/research/release-product-metadata-2026-11-03.json"))
for i, pack in M.Donate.packs do
	local legacy = M.Donate.legacyPacks[i]
	local savedId = pack.productId
	pack.productId = legacy.productId
	for _, info in observed.result do
		if info.id == legacy.productId then
			metadata[info.id] = { Name = info.name, PriceInRobux = info.price }
		end
	end
	f.setClock(f.getClock() + 61)
	donate.topUp(actor, pack.id)
	check("observed wrong storefront pack refused " .. pack.id, #prompts == 2)
	pack.productId = savedId
end
metadata[3723068679] = false
p = f.fresh()
donate.receipt({
	ProductId = 3723068679,
	PlayerId = actor.UserId,
	PurchaseId = "old-pack-during-outage",
})
check("paid legacy pack delivery does not depend on current Marketplace", p.crystals == 100)
local product = C.donate.items.ordinary_key.productId
local receipt = { ProductId = product, PlayerId = actor.UserId, PurchaseId = "uncertain" }
for _, fault in { "before", "after" } do
	p = f.fresh()
	disk = copy(p)
	saveFault = fault
	check(
		"failed receipt unacknowledged " .. fault,
		donate.receipt(receipt) == rb.Enum.ProductPurchaseDecision.NotProcessedYet
	)
	check("failed receipt exposes no spendable item " .. fault, next(p.inventory) == nil)
	f.profiles[actor] = copy(disk)
	saveFault = nil
	donate.receipt(receipt)
	donate.receipt(receipt)
	check(
		"receipt rejoin recovery exactly once " .. fault,
		M.InventoryService.count(f.profiles[actor], "ordinary_key") == 1
	)
end
p = f.fresh()
saveFault = nil
for n = 1, 55 do
	donate.receipt({ ProductId = product, PlayerId = actor.UserId, PurchaseId = "old-" .. n })
end
donate.receipt({ ProductId = product, PlayerId = actor.UserId, PurchaseId = "old-1" })
check(
	"old receipt retry survives more than50 newer purchases",
	M.InventoryService.count(p, "ordinary_key") == 55
)
p = f.fresh()
local originalDurable = M.ProfileService.MutateDurable
M.ProfileService.MutateDurable = function(player, transform)
	-- Another callback completed while this caller waited for the profile save lock.
	p.receipts = { "concurrent" }
	M.InventoryService.add(p, "ordinary_key", 1)
	return originalDurable(player, transform)
end
donate.receipt({ ProductId = product, PlayerId = actor.UserId, PurchaseId = "concurrent" })
M.ProfileService.MutateDurable = originalDurable
check(
	"concurrent receipt rechecked after save lock wait",
	M.InventoryService.count(p, "ordinary_key") == 1
)
p = f.fresh()
p.boosters = { { kind = "money", count = 200, mult = 2, minutes = 30 } }
local booster = C.donate.items.booster_blocks_local
donate.receipt({
	ProductId = booster.productId,
	PlayerId = actor.UserId,
	PurchaseId = "booster-full",
})
check(
	"paid booster at capacity reimburses catalog crystals",
	M.Boosters.storedCount(p) == 200 and p.crystals == booster.price
)
p = f.fresh()
p.boosters = { { kind = "money", count = 200, mult = 2, minutes = 30 } }
onCheckpoint = function()
	p.boosters[1].count = 199
end
donate.receipt({
	ProductId = booster.productId,
	PlayerId = actor.UserId,
	PurchaseId = "capacity-freed",
})
onCheckpoint = nil
check(
	"receipt refund plan remains fixed when capacity changes",
	M.Boosters.storedCount(p) == 199 and p.crystals == booster.price
)
p = f.fresh()
p.boosters = { { kind = "money", count = 199, mult = 2, minutes = 30 } }
onCheckpoint = function()
	p.boosters[1].count = 200
end
donate.receipt({
	ProductId = booster.productId,
	PlayerId = actor.UserId,
	PurchaseId = "capacity-filled",
})
onCheckpoint = nil
check(
	"confirmed paid booster survives concurrent capacity fill",
	M.Boosters.storedCount(p) == 201 and (p.crystals or 0) == 0
)
p = f.fresh()
check(
	"unknown product waits without granting",
	donate.receipt({ ProductId = -1, PlayerId = actor.UserId, PurchaseId = "unknown" })
			== rb.Enum.ProductPurchaseDecision.NotProcessedYet
		and next(p.inventory) == nil
)
p = f.fresh()
for i = 1, 36 do
	p.inventory[i] = { id = "pickaxe", count = 1, level = 1 }
end
donate.receipt({ ProductId = product, PlayerId = actor.UserId, PurchaseId = "full" })
check(
	"full inventory paid item retained in stash",
	p.stash[1].id == "ordinary_key" and p.stash[1].count == 1
)
print(serde.encode("json", {
	passed = #checks,
	checks = checks,
	missingRobuxProductIds = missingProducts,
	realPurchases = false,
	realProfiles = false,
}, true))
