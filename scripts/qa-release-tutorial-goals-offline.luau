--!nocheck
-- Actual Tutorial/Profile goals and checkpoints; fake stores only, no reward grants.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-profile-persistence-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("-- Exact acquisition ownership", 1, true)) - 1)
local fixture = assert(loadstring(prefix .. "\nreturn fixture"))()
local base = fs.readFile("scripts/qa-economy-audit-offline.luau")
base = base:sub(1, assert(base:find("local p = fresh()", 1, true)) - 1)
local economy = assert(loadstring(base .. "\nreturn modules"))()
local C = economy.Config
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function setup()
	local f = fixture()
	local actor = f:player()
	actor.UserId = -700
	local boundary = f:profile("tutorial-qa")
	local session = f:session(boundary, actor, "tutorial-token")
	local M = { Config = C, Selling = economy.Selling, ProfileService = boundary.service }
	local names = setmetatable({}, {
		__index = function(_, key)
			return key
		end,
	})
	local pending = {}
	local function load(path)
		local fn = assert(loadstring(fs.readFile(path), "@" .. path))
		setfenv(
			fn,
			setmetatable({
				script = { Parent = names },
				require = function(key)
					return assert(M[key], key)
				end,
				game = {
					GetService = function()
						return {
							WaitForChild = function()
								return names
							end,
						}
					end,
				},
				task = {
					spawn = function(fn, ...)
						fn(...)
					end,
					delay = function(_, fn)
						table.insert(pending, fn)
					end,
				},
			}, { __index = getfenv() })
		)
		return fn()
	end
	M.Numbers = load("src/shared/Numbers.luau")
	M.Tutorial = load("src/shared/Tutorial.luau")
	M.Achievements = load("src/shared/Achievements.luau")
	M.Boosters = {
		store = function()
			error("Unexpected booster reward")
		end,
	}
	M.Strings = {
		t = function(key)
			return key
		end,
		localeOf = function()
			return "en"
		end,
		grouped = tostring,
	}
	M.Remotes = {
		event = function()
			return { FireClient = function() end }
		end,
	}
	M.AchievementService = load("src/server/Services/AchievementService.luau")
	M.TutorialService = load("src/server/Services/TutorialService.luau")
	return f, actor, boundary, session, M, pending
end
local f, actor, boundary, session, M = setup()
check("fresh profile directly starts upgrade task", M.Tutorial.step(session.profile) == 3)
local initialWrites = f.writes
for _ = 1, 10 do
	M.TutorialService.OnDug(actor, "prison", "sand", 200, 0)
end
M.TutorialService.OnSold(actor, { sand = 2000 })
check(
	"ordinary callbacks cannot mint money achievement or counters",
	session.profile.coins == 0
		and session.profile.achievements.beginner == nil
		and session.profile.stats.starterBlocksClean == nil
		and f.writes == initialWrites
)
for _, card in C.achievementsCfg.statCards do
	check(
		"catalog contains no cancelled beginner card: " .. card.id,
		card.id ~= "beginner" and card.stat ~= "starterBlocksClean"
	)
end
M.TutorialService.OnLevelUp(actor, 1, 2)
check("unconfirmed level cannot skip first upgrade", M.Tutorial.step(session.profile) == 3)
M.TutorialService.OnUpgraded(actor, "shovel", 1, 1)
check("no change upgrade cannot advance", M.Tutorial.step(session.profile) == 3)
M.TutorialService.OnUpgraded(actor, "shovel", 1, 2)
check(
	"confirmed upgrade starts and saves level task",
	M.Tutorial.step(session.profile) == 4
		and session.profile.tutorial.completedAt == nil
		and f.disk["User_-700"].tutorial.step == 4
)
session.profile = boundary.migrate(f.disk["User_-700"])
M.TutorialService.OnLevelUp(actor, 1, 1)
check("unchanged level cannot complete tutorial", M.Tutorial.step(session.profile) == 4)
session.profile.level = 2
M.TutorialService.OnLevelUp(actor, 1, 2)
check(
	"actual level completes and persists tutorial",
	M.Tutorial.step(session.profile) == 5 and f.disk["User_-700"].tutorial.completedAt ~= nil
)
session.profile = boundary.migrate(f.disk["User_-700"])
check("completed rejoin remains complete", M.Tutorial.step(session.profile) == 5)
local saves = f.writes
M.TutorialService.OnUpgraded(actor, "shovel", 2, 3)
M.TutorialService.OnLevelUp(actor, 2, 3)
check("completion never replays checkpoints", f.writes == saves and session.profile.coins == 0)
check(
	"old completed and legacy states stay complete",
	M.Tutorial.step({ tutorial = { version = 1, step = 4, completedAt = 100 } }) == 5
		and M.Tutorial.step({ tutorial = { version = 1, step = 4, legacy = true } }) == 5
)
for oldStep = 1, 3 do
	check(
		"old unfinished step " .. oldStep .. " maps to real requirements",
		M.Tutorial.step({ tutorial = { version = 1, step = oldStep } }) == 3
	)
end
check("full own reset succeeds", boundary.service.ResetOwnProgress(actor))
check(
	"reset restarts requirements with no free money",
	session.profile.tutorial.step == 3
		and session.profile.coins == 0
		and session.profile.achievements.beginner == nil
)
check(
	"reset state persists after rejoin",
	M.Tutorial.step(boundary.migrate(f.disk["User_-700"])) == 3
)
local first = C.upgrade("shovel", 1)
check(
	"owner real first-upgrade requirements preserved",
	first.cost == 5
		and first.requirements["Гравий"] == 20
		and first.requirements["Песок"] == 15
		and first.requirements["Земля"] == 15
)
local p = boundary.service.defaultProfile()
p.coins, p.counters = 50000, { ["Гравий"] = 19, ["Песок"] = 15, ["Земля"] = 15 }
local goal = M.Tutorial.upgradeGoal(p)
check(
	"one missing credited block prevents upgrade guidance",
	not goal.ready and goal.cost == 5 * C.moneyScale and #goal.requirements == 3
)
p.counters["Гравий"] = 20
p.coins = 49999
check("one missing money unit prevents upgrade guidance", not M.Tutorial.upgradeGoal(p).ready)
p.coins = 50000
p.stats.blocksClean = 1
check("orange credited counters independently enable guidance", M.Tutorial.upgradeGoal(p).ready)
p.inventory[1], p.inventory[7] = nil, p.inventory[1]
check("moved shovel target stays correct", M.Tutorial.upgradeGoal(p).target == 7)
p.blocksTotal = 469
check(
	"level task reads real config and cannot complete early",
	M.Tutorial.levelGoal(p).neededBlocks == 470 and not M.Tutorial.levelGoal(p).ready
)
p.blocksTotal = 470
check("level guidance becomes ready at actual threshold", M.Tutorial.levelGoal(p).ready)
p.coins = 49999
check("level guidance requires actual available money", not M.Tutorial.levelGoal(p).ready)
p = boundary.service.defaultProfile()
p.counters["Гравий"] = 1
p.inventory[2] = { id = "gravel", count = 1 }
goal = M.Tutorial.upgradeGoal(p)
check(
	"first real block keeps mining instead of a sale trip",
	not goal.resourcesReady and not goal.saleReady and goal.estimatedSale == 115
)
p.counters = { ["Гравий"] = 19, ["Песок"] = 15, ["Земля"] = 15 }
p.coins = 49999
check(
	"one missing resource forbids sale guidance even with affordable bag",
	not M.Tutorial.upgradeGoal(p).saleReady
)
p.counters["Гравий"] = 20
p.coins = 0
goal = M.Tutorial.upgradeGoal(p)
check(
	"complete shovel resources guide sale even when bag cannot cover the full price",
	goal.resourcesReady and goal.saleReady and not goal.ready
)
check("empty sale cannot acknowledge first guided sale", not M.Tutorial.soldForUpgrade(p, 0))
local firstSale = economy.InventoryService.sellAll(p, economy.Selling.multiplier(p))
p.coins += firstSale
check(
	"real first sale records checkpoint without advancing upgrade",
	M.Tutorial.soldForUpgrade(p, firstSale) and M.Tutorial.step(p) == 3
)
local restored = boundary.migrate(p)
check("sale checkpoint survives profile reload", restored.tutorial.upgradeSold == true)
p.inventory[2] = { id = "sand", count = 1 }
check(
	"after first sale one more block cannot send player back again",
	not M.Tutorial.upgradeGoal(p).saleReady
)
check("sale acknowledgement is idempotent", not M.Tutorial.soldForUpgrade(p, firstSale))
p.inventory[2] = nil
check("empty bag never sends player to pointless sale", not M.Tutorial.upgradeGoal(p).saleReady)
p.coins = 49000
p.inventory[2] = { id = "sand", count = 9 }
goal = M.Tutorial.upgradeGoal(p)
check(
	"complete resources and sufficient exact sale value guide one sale",
	goal.resourcesReady and goal.saleReady and not goal.ready and goal.estimatedSale == 1035
)
local quote = economy.Selling.quote(p)
local actual = economy.InventoryService.sellAll(p, economy.Selling.multiplier(p))
p.coins += actual
goal = M.Tutorial.upgradeGoal(p)
check(
	"actual sale exactly matches quote and unlocks upgrade",
	actual == quote
		and goal.ready
		and not goal.saleReady
		and p.inventory[2] == nil
		and p.inventory[1].id == "shovel"
)
p.coins, p.blocksTotal = 49999, 469
p.inventory[2] = { id = "sand", count = 1 }
check(
	"level missing one block stays mining despite enough sale value",
	not M.Tutorial.levelGoal(p).saleReady
)
p.blocksTotal = 470
check(
	"level complete blocks plus affordable bag enables sale",
	M.Tutorial.levelGoal(p).saleReady and not M.Tutorial.levelGoal(p).ready
)
p.coins = 0
p.professions.upgrades.money = 7
p.activeBoosters = { { kind = "money", mult = 2, startsAt = 0, endsAt = 1000000 } }
p.inventory[2], p.inventory[3], p.inventory[4] =
	{ id = "sand", count = 3 }, { id = "gravel", count = 5 }, { id = "purpur", count = 64 }
local mult = economy.Selling.multiplier(p)
local total, locked, count = economy.Selling.quote(p)
local expected = math.floor(C.block("sand").basePrice * C.moneyScale * mult * 3 + 0.5)
	+ math.floor(C.block("gravel").basePrice * C.moneyScale * mult * 5 + 0.5)
check(
	"quote includes profession boosters and exact per-stack rounding",
	total == expected and mult > 1
)
check("quote excludes higher-floor locked blocks and tools", locked == 64 and count == 8)
local sold, kept, n = economy.InventoryService.sellAll(p, mult)
check(
	"authoritative SellAll and estimate share filter rounding and multiplier",
	sold == total and kept == locked and n == count and p.inventory[4].count == 64
)
p.inventory[2] = { id = "sand", count = 0 / 0 }
check(
	"invalid inventory cannot create a fictitious sale-ready estimate",
	economy.Selling.quote(p) == 0
)
-- Run the production NPC sale callback: coins, loot removal and tutorial checkpoint
-- must be observed in the same mutation, without requiring the old dropId field.
local saleProfile = boundary.service.defaultProfile()
saleProfile.counters = { ["Гравий"] = 20, ["Песок"] = 15, ["Земля"] = 15 }
saleProfile.inventory[2] = { id = "sand", count = 15 }
local saleSource = fs.readFile("src/server/Services/EconomyService.luau")
local saleStart = assert(saleSource:find("local function sell(player:", 1, true))
local saleEnd = assert(saleSource:find("local BULK", saleStart, true))
local saleFactory = assert(loadstring(saleSource:sub(saleStart, saleEnd - 1) .. "\nreturn sell"))
local committed, writes = false, 0
setfenv(
	saleFactory,
	setmetatable({
		ProfileService = {
			Get = function()
				return saleProfile
			end,
			Mutate = function(_, fn)
				writes += 1
				fn(saleProfile)
				committed = saleProfile.coins > 0
					and saleProfile.inventory[2] == nil
					and saleProfile.tutorial.upgradeSold == true
			end,
		},
		InventoryService = economy.InventoryService,
		ProfessionService = { moneyMultiplier = economy.Selling.multiplier },
		Tutorial = M.Tutorial,
		TutorialService = {
			OnSold = function()
				error("obsolete dropId hook")
			end,
		},
		GangService = { progress = function() end },
		Strings = { money = tostring },
		Sfx = { toPlayer = function() end },
		nearNpc = function()
			return true
		end,
		toast = function() end,
	}, { __index = getfenv() })
)
saleFactory()(actor)
check(
	"real seller callback atomically records cash loot and first-sale checkpoint",
	committed and writes == 1
)
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	realProfiles = false,
	realStores = false,
}))
