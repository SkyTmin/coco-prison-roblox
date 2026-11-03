--!nocheck
-- lune run scripts/qa-release-ui-onboarding.luau
-- Real modules, fake services only. Reset actors have negative IDs; no Studio/network/profile writes.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local rb = require("@lune/roblox")
local checks = {}
local function check(name, value)
	assert(value, name)
	table.insert(checks, name)
end
local function load(path, env, edit)
	local source = fs.readFile(path)
	if edit then
		source = edit(source)
	end
	local fn = assert(loadstring(source, "@" .. path))
	setfenv(fn, setmetatable(env or {}, { __index = getfenv() }))
	return fn()
end
local Persistence = load("src/shared/Persistence.luau")
local Tutorial = load("src/shared/Tutorial.luau", {
	script = { Parent = { Config = "Config" } },
	require = function()
		return {
			achievementsCfg = serde.decode(
				"json",
				fs.readFile("src/shared/Config/achievements.json")
			),
		}
	end,
})
local Numbers = load("src/shared/Numbers.luau")
local Books = load("src/shared/CreativeBooks.luau")
local Layout = load("src/client/ReleaseLayout.luau")
local p = { tutorial = Tutorial.new() }
check("genuine new profile starts with actual upgrade requirements", Tutorial.step(p) == 3)
check(
	"mining and selling do not create synthetic tutorial rewards",
	not Tutorial.dug(p, "prison", "sand", 200, 0)
		and not Tutorial.sold(p, { sand = 200 })
		and Tutorial.step(p) == 3
)
check("unconfirmed level cannot skip upgrade task", not Tutorial.leveled(p, 1, 2, 100))
check("failed/no-change upgrade cannot advance tutorial", not Tutorial.upgraded(p, 1, 1, 100))
check(
	"actual upgrade starts persisted level task",
	Tutorial.upgraded(p, 1, 2, 100)
		and Tutorial.step(Persistence.copy(p)) == 4
		and p.tutorial.completedAt == nil
)
check("failed/no-change level cannot complete tutorial", not Tutorial.leveled(p, 1, 1, 101))
p.level = 2
check(
	"actual level completes persisted guide",
	Tutorial.leveled(p, 1, 2, 102)
		and Tutorial.step(Persistence.copy(p)) == 5
		and p.tutorial.completedAt == 102
)
check(
	"completed guide never replays",
	not Tutorial.upgraded(p, 2, 3, 103) and not Tutorial.leveled(p, 2, 3, 103)
)
local bookConfig = serde.decode("json", fs.readFile("src/shared/Config/books.json"))
local groups = Books.groups(bookConfig.catalog, bookConfig.effects, function(id)
	return id
end)
local actual = {}
for _, group in groups do
	actual[group.itemId] = {}
	for _, id in group.books do
		actual[group.itemId][id] = true
	end
end
local multi = 0
for id, card in bookConfig.catalog do
	if bookConfig.effects[id] then
		for _, item in card.items do
			check(
				"book " .. id .. " appears in compatible " .. item,
				actual[item] and actual[item][id]
			)
		end
		if #card.items > 1 then
			multi += 1
		end
	end
end
check("real catalog includes repeated multi-target books", multi > 0)
local sorted = Books.groups({
	low = { items = { "sword" }, rarity = "common" },
	high = { items = { "sword" }, rarity = "epic" },
	mid = { items = { "sword" }, rarity = "rare" },
}, { low = { 1 }, high = { 1 }, mid = { 1 } }, function(id)
	return id
end)
check("books sort by rarity before name", table.concat(sorted[1].books, ",") == "high,mid,low")
for _, size in { { 390, 844 }, { 844, 390 } } do
	for _, kind in { "Window_Actions", "Window_ResetProgress", "Window_Creative" } do
		local width, height = Layout.window(kind, size[1], size[2], 58)
		check(
			kind .. " fits native pixels at " .. size[1],
			width <= size[1] - 20 and height <= size[2] - 70
		)
		if kind == "Window_Actions" then
			check("action form retains a full touch row " .. size[1], height - 58 - 154 >= 44)
		end
	end
end

local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local clock, guid, saves = 100, 0, 0
local actors, profiles, chat = {}, {}, {}
local function actor(id, name, display, x)
	local a = { UserId = id, Name = name, DisplayName = display, Parent = true, attrs = {} }
	a.GetAttribute = function(_, key)
		return a.attrs[key]
	end
	a.SetAttribute = function(_, key, value)
		a.attrs[key] = value
	end
	a.Character = {
		FindFirstChildOfClass = function(_, class)
			return if class == "Humanoid" then { Health = a.health or 20 } else nil
		end,
		FindFirstChild = function()
			return {
				IsA = function()
					return true
				end,
				Position = rb.Vector3.new(x or 0, 0, 0),
			}
		end,
	}
	return a
end
local sender, recipient, spoof =
	actor(11, "Alice", "Alice"), actor(22, "Bob", "Bob"), actor(33, "Other", "Bob")
actors = { spoof, recipient, sender }
local function resetProfiles()
	profiles[sender] = {
		coins = 10000,
		inventory = { [4] = { id = "apple", count = 5 } },
		selectedSlot = 4,
		location = "prison",
		settings = {},
	}
	profiles[recipient] = { coins = 0, inventory = {}, location = "prison", settings = {} }
	profiles[spoof] = { coins = 0, inventory = {}, location = "prison", settings = {} }
	clock += 2
end
resetProfiles()
local config = {
	moneyScale = 100,
	tools = {},
	chat = {
		payMin = 1,
		giftForbidden = { "blocked" },
		giftRangeBlocks = 4,
		commandCooldownSeconds = 0,
	},
	rules = { combat = { blockStuds = 4 } },
	block = function(id)
		return id == "sand"
	end,
}
local modules = {
	Types = {},
	Config = config,
	Numbers = Numbers,
	Persistence = Persistence,
	Boosters = {},
	PrisPlus = { cfg = { rubbMin = 1 } },
	Warzone = { LOCATION = "warzone" },
	Chat = {},
	Strings = {
		lower = string.lower,
		money = tostring,
		localeOf = function()
			return "en"
		end,
		itemName = function(id)
			return id
		end,
		t = function(key)
			return key
		end,
	},
	ChatService = {
		reply = function(a, key)
			table.insert(chat, { a, key })
		end,
		fail = function(a, key)
			table.insert(chat, { a, key })
		end,
	},
	Remotes = {
		event = function()
			return { FireClient = function() end }
		end,
	},
	ProfileService = {
		Get = function(a)
			return profiles[a]
		end,
		IsReal = function(a)
			return profiles[a] ~= nil and not a.failed
		end,
		CanExport = function(a)
			return profiles[a] ~= nil
				and not profiles[a].storageTransfer
				and not profiles[a].playerTransfer
				and not profiles[a].playerTransferIncoming
				and not a.failed
		end,
		Mutate = function(a, fn)
			fn(profiles[a])
		end,
		SaveNow = function()
			saves += 1
			return true
		end,
		MutateDurable = function(a, fn)
			fn(profiles[a])
			return true
		end,
	},
}
local services = {
	DataStoreService = {},
	RunService = {
		IsStudio = function()
			return false
		end,
	},
	Players = {
		GetPlayers = function()
			return actors
		end,
		GetPlayerByUserId = function(_, id)
			for _, a in actors do
				if a.UserId == id then
					return a
				end
			end
		end,
	},
	ReplicatedStorage = {
		WaitForChild = function()
			return names
		end,
	},
	TextChatService = {},
	HttpService = {
		GenerateGUID = function()
			guid += 1
			return "nonce-" .. guid
		end,
	},
}
local env = {
	game = {
		GetService = function(_, name)
			return assert(services[name], name)
		end,
	},
	script = { Parent = names },
	require = function(name)
		return assert(modules[name], name)
	end,
	os = {
		clock = function()
			return clock
		end,
		time = function()
			return clock
		end,
	},
	task = {
		spawn = function(fn, ...)
			fn(...)
		end,
		defer = function() end,
	},
	warn = function() end,
}
modules.InventoryService = load("src/server/Services/InventoryService.luau", env)
modules.TransferAccess = load("src/shared/TransferAccess.luau", env)
local mail = {}
modules.PlayerTransferService = load(
	"src/server/Services/PlayerTransferService.luau",
	env,
	function(source)
		return source:gsub(
			"return Transfer%s*$",
			"Transfer.setInbox=function(value) inbox=value end; return Transfer"
		)
	end
)
modules.PlayerTransferService.setInbox({
	GetAsync = function(_, key)
		return Persistence.copy(mail[key])
	end,
	UpdateAsync = function(_, key, change)
		mail[key] = change(Persistence.copy(mail[key]))
		return Persistence.copy(mail[key])
	end,
})
modules.ChatCommandService = load("src/server/Services/ChatCommandService.luau", env)
local Actions = load("src/server/Services/ActionsService.luau", env)
local actualRequest = Actions.Request
Actions.Request = function(...)
	local answer = actualRequest(...)
	modules.PlayerTransferService.Resolve(sender)
	modules.PlayerTransferService.Resolve(recipient)
	modules.PlayerTransferService.Resolve(sender)
	return answer
end
local function quote(kind, value)
	clock += 1
	return Actions.Request(
		sender,
		"quote",
		{ kind = kind, recipient = recipient.UserId, amount = value, slot = 4, count = value }
	)
end
local q = quote("pay", 2.50)
check(
	"money review has no side effect",
	q.ok and profiles[sender].coins == 10000 and profiles[recipient].coins == 0
)
local result = Actions.Request(sender, "confirm", q.token)
check(
	"confirmed money transfer reuses command validation",
	result.ok and profiles[sender].coins == 9750 and profiles[recipient].coins == 250
)
check("canonical recipient beats display-name spoof", profiles[spoof].coins == 0)
check(
	"single-use confirmation prevents replay",
	not Actions.Request(sender, "confirm", q.token).ok and profiles[recipient].coins == 250
)
check(
	"sender sees structured result without chat",
	#chat == 0 and result.key == "release_transfer_pending"
)
resetProfiles()
q = quote("gift", 2)
result = Actions.Request(sender, "confirm", q.token)
check(
	"partial gift moves exactly requested count",
	result.ok
		and profiles[sender].inventory[4].count == 3
		and modules.InventoryService.count(profiles[recipient], "apple") == 2
)
resetProfiles()
q = quote("gift", 2)
profiles[sender].inventory[4].count = 4
check(
	"changed item snapshot requires another review",
	not Actions.Request(sender, "confirm", q.token).ok and profiles[sender].inventory[4].count == 4
)
resetProfiles()
profiles[sender].inventory[4] = {
	id = "ancient_book",
	count = 1,
	books = { { id = "hammer", level = 3 } },
	rarity = "epic",
	applyChance = 73,
}
q = quote("gift", 1)
result = Actions.Request(sender, "confirm", q.token)
check(
	"gift preserves book metadata",
	result.ok
		and profiles[recipient].inventory[1].books[1].level == 3
		and profiles[recipient].inventory[1].applyChance == 73
)
for _, failure in { "off", "location", "distance", "full", "forbidden", "block", "escrow" } do
	resetProfiles()
	if failure == "off" then
		profiles[recipient].settings.giftOff = true
	end
	if failure == "location" then
		profiles[recipient].location = "other"
	end
	if failure == "distance" then
		recipient.Character = actor(22, "Bob", "Bob", 100).Character
	else
		recipient.Character = actor(22, "Bob", "Bob").Character
	end
	if failure == "full" then
		for i = 1, 36 do
			profiles[recipient].inventory[i] = { id = "stone", count = 64 }
		end
	end
	if failure == "forbidden" then
		profiles[sender].inventory[4].id = "blocked"
	end
	if failure == "block" then
		profiles[sender].inventory[4].id = "sand"
	end
	if failure == "escrow" then
		profiles[recipient].storageTransfer = {}
	end
	q = quote("gift", 1)
	check(
		"gift server refuses " .. failure,
		not Actions.Request(sender, "confirm", q.token).ok
			and profiles[sender].inventory[4].count == 5
	)
end
resetProfiles()
q = quote("pay", 2)
clock += 31
check(
	"expired review cannot transfer",
	not Actions.Request(sender, "confirm", q.token).ok and profiles[sender].coins == 10000
)
resetProfiles()
q = quote("pay", 2)
actors = { sender, spoof }
check(
	"recipient departure cannot retarget confirmation",
	not Actions.Request(sender, "confirm", q.token).ok and profiles[spoof].coins == 0
)
actors = { spoof, recipient, sender }
resetProfiles()
check(
	"non-finite and fractional quantity quotes refused",
	not quote("gift", 0 / 0).ok and not quote("gift", 1.5).ok and not quote("pay", math.huge).ok
)
check(
	"hide action works without chat",
	Actions.Request(sender, "hide", nil).ok and profiles[sender].settings.hidePlayers == true
)
resetProfiles()
recipient.UserId = -22
q = quote("pay", 2)
check(
	"connected simulated negative-ID recipient uses ordinary actions",
	q.ok and Actions.Request(sender, "confirm", q.token).ok and profiles[recipient].coins == 200
)
recipient.UserId = 22

for _, kind in { "pay", "gift" } do
	resetProfiles()
	recipient.Character = actor(22, "Bob", "Bob", 32).Character
	check(
		kind .. " far quote rejected before review",
		quote(kind, 1).key == "release_transfer_nearby"
	)
	recipient.Character = actor(22, "Bob", "Bob", 4).Character
	q = quote(kind, 1)
	check(kind .. " nearby quote accepted", q.ok)
	recipient.Character = actor(22, "Bob", "Bob", 32).Character
	result = Actions.Request(sender, "confirm", q.token)
	check(
		kind .. " walking away after review refuses confirm",
		not result.ok and result.key == "release_transfer_nearby"
	)
	check(
		kind .. " walking away preserves balances and item",
		profiles[sender].coins == 10000
			and profiles[recipient].coins == 0
			and profiles[sender].inventory[4].count == 5
	)
	local command = modules.ChatCommandService.ExecuteAction(
		sender,
		kind,
		if kind == "pay" then { recipient.Name, "1" } else { recipient.Name, "4", "1" }
	)
	check(
		kind .. " command cannot bypass distance",
		not command.ok and command.key == "release_transfer_nearby"
	)
	recipient.Character = actor(22, "Bob", "Bob", 4).Character
	q = quote(kind, 1)
	recipient.health = 0
	-- This character closure must read the same actor's current health.
	local livingBody = recipient.Character
	recipient.Character = {
		FindFirstChildOfClass = function()
			return { Health = 0 }
		end,
		FindFirstChild = livingBody.FindFirstChild,
	}
	result = Actions.Request(sender, "confirm", q.token)
	check(
		kind .. " death after review refuses without debit",
		not result.ok
			and result.key == "release_transfer_alive"
			and profiles[sender].coins == 10000
			and profiles[sender].inventory[4].count == 5
	)
	recipient.health = nil
	recipient.Character = actor(22, "Bob", "Bob", 4).Character
end
resetProfiles()

-- Actual ProfileService reset at its real durable/session boundary, on negative simulated actors only.
local factory = require("./qa-profile-persistence-offline").fixture
local f = factory()
local owner = f:player()
owner.UserId = -777
local boundary = f:profile("isolated-reset")
local session = f:session(boundary, owner, "original-token")
local live = session.profile
live.level, live.coins, live.blocksTotal = 40, 99999, 5000
live.inventory =
	{ [1] = { id = "toilet_paper", count = 16 }, [2] = { id = "ancient_key", count = 23 } }
live.enderChest = { [1] = { id = "stone", count = 64 }, [81] = { id = "ancient_star", count = 2 } }
live.caseContents = { ancientCase = { [27] = { id = "ancient_star", count = 4 } } }
live.stash = { { id = "ancient_key", count = 8 } }
live.boosters = { { kind = "blocks", count = 3 } }
live.activeBoosters = { { kind = "blocks", endsAt = 999999 } }
live.playerTransferGifts = { old = { id = "ancient_book", count = 1 } }
live.playerTransferReceipts = { old = true }
live.auction = { returns = { { id = "toilet_paper", count = 5 } } }
live.vaultSections, live.auctionSlots, live.needsFree, live.autosell = 3, 4, true, true
live.armor = { boots = { id = "boots", level = 5, count = 1 } }
live.receipts, live.crystals, live.rubies, live.noAuctionFee = { "paid-1", "paid-2" }, 320, 70, true
live.bossRewardUntil, live.bossRewardReceipts, live.serverAffinity =
	{ boss = 9000 }, { receipt = true }, { job = "old" }
live.operationIds, live.passes, live.settings =
	{ oldGrant = true }, { basement = true }, { volume = 0.3 }
session.fresh = true
local frozen = false
f.beforeUpdate = function()
	f.beforeUpdate = nil
	frozen = not boundary.service.IsReal(owner) and not boundary.service.CanExport(owner)
	boundary.service.Mutate(owner, function(profile)
		profile.coins = 123456
	end)
	check("reset freezes concurrent profile mutation", live.coins == 99999)
end
local resetOk = boundary.service.ResetOwnProgress(owner)
check(
	"confirmed own reset succeeds with same session token",
	resetOk
		and session.token == "original-token"
		and f.disk["User_-777"]._lock.token == "original-token"
)
check("reset cannot export old inventory during save", frozen)
check(
	"reset clears ordinary progression and restarts tutorial",
	live.level == 1
		and live.coins == 0
		and live.blocksTotal == 0
		and next(live.armor) == nil
		and Tutorial.step(live) == 3
)
check(
	"reset preserves paid currency and immutable receipts",
	live.crystals == 320 and live.rubies == 70 and #live.receipts == 2 and live.noAuctionFee
)
check(
	"reset clears catalog consumables in every vault section and keeps only starter shovel",
	live.inventory[1].id == "shovel"
		and live.inventory[2] == nil
		and next(live.enderChest) == nil
		and next(live.caseContents) == nil
)
check(
	"reset clears stash, boosters, overflow and auction returns",
	live.stash == nil
		and live.boosters == nil
		and live.activeBoosters == nil
		and live.playerTransferGifts == nil
		and next(live.auction.returns) == nil
)
check(
	"reset retains consumed permanent entitlements",
	live.vaultSections == 3 and live.auctionSlots == 4 and live.needsFree and live.autosell
)
check(
	"reset advances mail generation and retains old receipts",
	live.playerTransferGeneration == 1 and live.playerTransferReceipts.old
)
local reloadedReset = boundary.migrate(Persistence.copy(f.disk["User_-777"]))
check(
	"cleared containers stay cleared after saved-profile migration",
	reloadedReset.inventory[2] == nil
		and next(reloadedReset.enderChest) == nil
		and next(reloadedReset.caseContents.ancientCase) == nil
		and reloadedReset.stash == nil
		and reloadedReset.playerTransferGifts == nil
		and reloadedReset.playerTransferGeneration == 1
)
check(
	"reset preserves boss cooldown receipts and affinity",
	live.bossRewardUntil.boss == 9000
		and live.bossRewardReceipts.receipt
		and live.serverAffinity.job == "old"
)
check(
	"reset preserves settings access and operation locks",
	live.settings.volume == 0.3 and live.passes.basement and live.operationIds.oldGrant
)
check("reset is not a new referral account", session.fresh == false)
check(
	"reset tutorial resumes after rejoin",
	Tutorial.step(boundary.migrate(Persistence.copy(f.disk["User_-777"]))) == 3
)
local serverTutorial = load("src/server/Services/TutorialService.luau", {
	game = {
		GetService = function()
			return {
				WaitForChild = function()
					return names
				end,
			}
		end,
	},
	script = { Parent = names },
	require = function(name)
		if name == "Tutorial" then
			return Tutorial
		end
		if name == "AchievementService" then
			return {
				OnStat = function(actor)
					boundary.service.SaveNow(actor)
				end,
			}
		end
		return boundary.service
	end,
	task = {
		spawn = function(fn, ...)
			fn(...)
		end,
	},
})
local stageSaves = f.writes
serverTutorial.OnDug(owner, "prison_small", "sand", 1, 0)
check("server rejects unrelated dig without a tutorial save", f.writes == stageSaves)
serverTutorial.OnDug(owner, "prison", "sand", 1, 0)
serverTutorial.OnSold(owner, { sand = 1 })
check(
	"mining and selling callbacks do not mint rewards or save synthetic stages",
	f.writes == stageSaves
)
serverTutorial.OnUpgraded(owner, "shovel", 1, 2)
check(
	"upgrade checkpoints level task",
	f.writes == stageSaves + 1 and Tutorial.step(f.disk["User_-777"]) == 4
)
boundary.service.Mutate(owner, function(profile)
	profile.level = 2
end)
serverTutorial.OnLevelUp(owner, 1, 2)
check(
	"real tutorial service checkpoints completion",
	f.writes == stageSaves + 2 and Tutorial.step(f.disk["User_-777"]) == 5
)
check(
	"completed tutorial remains complete after profile migration",
	Tutorial.step(boundary.migrate(Persistence.copy(f.disk["User_-777"]))) == 5
)
local old = boundary.service.defaultProfile()
old.tutorial = nil
check(
	"pre-release existing v3 profiles do not receive first-login tutorial",
	Tutorial.step(boundary.migrate(old)) == 5
)
for _, field in
	{ "storageTransfer", "storageDeath", "bossRewardPending", "gangOps", "pendingBoosters" }
do
	live[field] = { pending = true }
	if field == "bossRewardPending" then
		check("pending boss reward blocks profile exports", not boundary.service.CanExport(owner))
	end
	local before = f.writes
	check(
		"reset refuses pending " .. field,
		not boundary.service.ResetOwnProgress(owner) and f.writes == before
	)
	live[field] = nil
end
live.gang = { id = "shared-membership" }
check("reset does not orphan gang membership", not boundary.service.ResetOwnProgress(owner))
live.gang = nil
f.afterUpdate = function()
	f.afterUpdate = nil
	error("applied-but-error reset")
end
check("uncertain reset does not report success", not boundary.service.ResetOwnProgress(owner))
check(
	"uncertain reset quarantines old profile and requires rejoin",
	session.loadFailed and not boundary.service.CanExport(owner) and #owner.kicks == 1
)

-- Validate the owner-only prepare/confirm endpoint without executing a real reset or respawn.
local resetCalls = 0
local own = actor(-888, "SimulatedOwner", "SimulatedOwner")
modules.Config.rules.creative = { admins = { -888 }, stackCount = 64 }
modules.ItemInfo = {}
modules.ProfileService = {
	IsReal = function()
		return true
	end,
	Get = function()
		return {}
	end,
	ResetOwnProgress = function(a)
		check("reset endpoint can only pass its sender", a == own)
		resetCalls += 1
		return true
	end,
}
modules.ProgressReset = load("src/shared/ProgressReset.luau", {
	script = { Parent = names },
	require = function()
		return Persistence
	end,
})
services.LogService, services.RunService = {}, {
	IsStudio = function()
		return true
	end,
}
env.game.CreatorType, env.game.CreatorId, env.Enum = rb.Enum.CreatorType.User, -888, rb.Enum
env.task.defer = function() end
local resetRequest = load("src/server/Services/CreativeService.luau", env, function(source)
	return source:gsub("return CreativeService%s*$", "return resetRequest")
end)
local prepared = resetRequest(own, "prepare")
check("reset preparation alone deletes nothing", prepared.ok and resetCalls == 0)
check(
	"wrong reset token deletes nothing",
	not resetRequest(own, "confirm", "wrong").ok and resetCalls == 0
)
check(
	"another actor cannot reuse owner's reset token",
	not resetRequest(sender, "confirm", prepared.token).ok and resetCalls == 0
)
check(
	"explicit owner confirmation resets once",
	resetRequest(own, "confirm", prepared.token).ok and resetCalls == 1
)
check(
	"reset token replay is rejected",
	not resetRequest(own, "confirm", prepared.token).ok and resetCalls == 1
)
prepared = resetRequest(own, "prepare")
clock += 46
check(
	"reset confirmation expires",
	not resetRequest(own, "confirm", prepared.token).ok and resetCalls == 1
)

local entries = load("src/shared/Strings/ReleaseUi.luau")
for key, entry in entries do
	for _, locale in { "ru", "en", "es", "fr" } do
		check(
			key .. " translated " .. locale,
			type(entry[locale]) == "string" and #entry[locale] > 0
		)
	end
end
for _, path in
	{
		"src/client/init.client.luau",
		"src/client/ActionsWindow.luau",
		"src/client/CreativeWindow.luau",
		"src/client/ResetProgressWindow.luau",
		"src/client/TutorialGuide.luau",
		"src/client/Invite.luau",
		"scripts/qa-release-actions-server.luau",
		"scripts/qa-release-actions-client.luau",
	}
do
	check(path .. " compiles", loadstring(fs.readFile(path)) ~= nil)
end
print(serde.encode("json", {
	passed = #checks,
	actualModules = true,
	realProfiles = false,
	realDataStores = false,
	ownerResetExecuted = false,
	checks = checks,
}, true))
