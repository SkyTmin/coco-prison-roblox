--!nocheck
-- Actual generated Config, localized tooltip and server upgrade/damage closures. No Studio/stores.
local fs, serde = require("@lune/fs"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-release-localization-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local function formats", 1, true)) - 1)
local M = assert(loadstring(prefix .. "\nreturn M"))()
local C = M.Config
local checks = {}
local function check(name, yes)
	assert(yes, name)
	table.insert(checks, name)
end
local raw = serde.decode(
	"json",
	fs.readFile("wiki/client-audit/content-analysis/other-upgrades-recovery.json")
)
check(
	"recovered screenshot facts still stop at15",
	raw.sword.transitions[#raw.sword.transitions].toLevel == 15
		and raw.sword.terminalPreview.rightUpgradeRow == "Алмазный меч 15 → 15"
)
local up = C.upgrade("sword", 15)
check(
	"generated owner extension is contiguous15to16",
	up
		and up.from == 15
		and up.to == 16
		and C.upgrade("sword", 16) == nil
		and #C.tools.sword.upgrades == 15
)
check(
	"approved extension price and requirements are explicit",
	up.cost == 20000
		and up.requirements["Крысы"] == 16700
		and up.requirements["Оружейник"] == 5
		and up.source:find("решение", 1, true)
)
check(
	"display enchant is diamond SharpIII",
	C.materialForLevel(16) == "diamond"
		and C.enchantForLevel("sword", 16) == 3
		and C.isEnchanted("sword", 16)
)
check(
	"level16 reuses actual diamond icon",
	C.iconFor("sword", 16) ~= nil and C.iconFor("sword", 16) == C.iconFor("sword", 15)
)
check("Java SharpIII standalone bonus is two", C.sharpnessBonus(3) == 2)
local previous = { 0, 1, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8 }
for level, power in previous do
	check(
		"accepted previous power stays unchanged " .. level,
		C.enchantPower("sword", level) == power
	)
end
check(
	"new strength extends monotonic curve without fallback nerf",
	C.enchantPower("sword", 16) == 9
)
local function closure(path, first, last, name, env)
	local source = fs.readFile(path)
	local a = assert(source:find(first, 1, true))
	local b = assert(source:find(last, a, true))
	local f = assert(loadstring(source:sub(a, b - 1) .. "\nreturn " .. name, "@" .. path))
	setfenv(f, setmetatable(env, { __index = getfenv() }))
	return f()
end
local weapon = closure(
	"src/server/Services/CombatService.luau",
	"local function weapon(",
	"-- Better Combat-style melee",
	"weapon",
	{ Config = C, InventoryService = M.InventoryService }
)
local p = {
	selectedSlot = 1,
	inventory = {
		{ id = "sword", level = 15, count = 1, books = { { id = "berserk", level = 1 } } },
	},
	armor = {},
	coins = 20000 * C.moneyScale,
	stats = { ratsTotal = 16700 },
	counters = {},
	skills = { armorer = 5 },
}
local damage, bonus = weapon(p)
check("actual old weapon damage remains11point5", damage + bonus == 11.5)
p.inventory[1].level = 16
damage, bonus = weapon(p)
check(
	"actual new weapon damage is12 with seven base plus five enchant",
	damage == 7 and bonus == 5 and damage + bonus == 12
)
for _, locale in { "ru", "en", "es", "fr" } do
	local lines = M.ItemInfo.lines(p.inventory[1], locale)
	local texts = {}
	for _, line in lines do
		table.insert(texts, line.text)
	end
	local text = table.concat(texts, "\n")
	check(
		"actual tooltip SharpIII translated " .. locale,
		text:find(M.Strings.t("enchant_sharpness", locale) .. " III", 1, true) ~= nil
	)
	check(
		"actual tooltip gives new max16 " .. locale,
		text:find(M.Strings.t("tip_upgrade_level", locale, 16, 16), 1, true) ~= nil
	)
	check(
		"actual tooltip damage agrees with server " .. locale,
		text:find(M.Strings.t("tip_attack_damage", locale, "12"), 1, true) ~= nil
	)
end
local actor = {
	GetAttribute = function()
		return "en"
	end,
}
local notices, outcomes = {}, {}
local upgrade = closure(
	"src/server/Services/EconomyService.luau",
	"local function upgrade(",
	"local function levelUp(",
	"upgrade",
	{
		Config = C,
		Numbers = M.Numbers,
		InventoryService = M.InventoryService,
		Strings = M.Strings,
		ProfileService = {
			Get = function()
				return p
			end,
			Mutate = function(_, fn)
				fn(p)
			end,
		},
		units = function(dollars)
			return math.floor(dollars * C.moneyScale + 0.5)
		end,
		toast = function(_, key)
			table.insert(notices, key)
		end,
		Sfx = { toPlayer = function() end },
		TutorialService = {
			OnUpgraded = function(_, id, old, new)
				table.insert(outcomes, { id, old, new })
			end,
		},
	}
)
p.inventory[1].level = 15
p.coins = up.cost * C.moneyScale - 1
upgrade(actor, 1)
check(
	"actual upgrade rejects one missing currency unit",
	p.inventory[1].level == 15 and #outcomes == 0
)
p.coins = up.cost * C.moneyScale
p.stats.ratsTotal = 16699
upgrade(actor, 1)
check(
	"actual upgrade rejects one missing credited rat",
	p.inventory[1].level == 15 and #outcomes == 0
)
p.stats.ratsTotal = 16700
p.skills.armorer = 4
upgrade(actor, 1)
check("actual upgrade requires ArmorerV", p.inventory[1].level == 15 and #outcomes == 0)
p.skills.armorer = 5
upgrade(actor, 1)
check(
	"actual exact-threshold upgrade reaches16 and debits once",
	p.inventory[1].level == 16 and p.coins == 0 and #outcomes == 1 and outcomes[1][3] == 16
)
check(
	"upgrade retains ancient metadata and cumulative rat count",
	p.inventory[1].books[1].id == "berserk" and p.stats.ratsTotal == 16700
)
upgrade(actor, 1)
check(
	"max retry cannot charge or advance again",
	p.coins == 0 and #outcomes == 1 and notices[#notices] == "upgrade_max"
)
local creativePath = "src/server/Services/CreativeService.luau"
local maximum = closure(
	creativePath,
	"local function maxLevel(",
	"-- an invisible ForceField",
	"maxLevel",
	{ Config = C }
)
local give = closure(creativePath, "local function give(", "local function onRequest(", "give", {
	Config = C,
	maxLevel = maximum,
	catalog = { sword = true },
	rules = { stackCount = 64 },
	InventoryService = M.InventoryService,
	ProfileService = {
		Mutate = function(_, fn)
			fn(p)
		end,
	},
})
give(actor, "sword", 16)
give(actor, "sword", 99)
check(
	"actual Creative giver accepts16 and clamps above to16",
	maximum("sword") == 16 and p.inventory[2].level == 16 and p.inventory[3].level == 16
)
check(
	"Creative picker uses generated count with no15 cap",
	fs.readFile("src/client/CreativeWindow.luau")
		:find("for level = 1, #tool.upgrades + 1 do", 1, true) ~= nil
)
local persistence = fs.readFile("scripts/qa-profile-persistence-offline.luau")
persistence =
	persistence:sub(1, assert(persistence:find("-- Exact acquisition ownership", 1, true)) - 1)
local fixture = assert(loadstring(persistence .. "\nreturn fixture"))()
local boundary = fixture():profile("sword-migration")
local saved = boundary.service.defaultProfile()
saved.inventory[1] =
	{ id = "sword", level = 16, count = 1, books = { { id = "berserk", level = 1 } } }
local rejoined = boundary.migrate(saved)
check(
	"actual profile migration preserves sword16 and metadata",
	rejoined.inventory[1].level == 16 and rejoined.inventory[1].books[1].id == "berserk"
)
local result =
	{ status = "PASS", count = #checks, checks = checks, realProfiles = false, realStores = false }
print(serde.encode("json", result))
