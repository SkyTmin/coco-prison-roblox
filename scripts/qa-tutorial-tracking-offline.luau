--!nocheck
-- Actual shared goal logic, Guide flow/facing closures, real Config and fake profiles/stores only.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local base = fs.readFile("scripts/qa-release-tutorial-goals-offline.luau")
base = base:sub(1, assert(base:find("local f, actor, boundary, session, M = setup()", 1, true)) - 1)
local setup = assert(loadstring(base .. "\nreturn setup"))()
local f, actor, boundary, session, M = setup()
local Tutorial, C = M.Tutorial, M.Config
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
check(
	"isolated native preview compiles",
	loadstring(fs.readFile("scripts/qa-tutorial-tracking-native.luau")) ~= nil
)
local source = fs.readFile("src/client/TutorialGuide.luau")
local a = assert(source:find('local phase = "tutorial_open_menu"', 1, true))
local b = assert(source:find("local ready = player:GetAttribute", a, true))
local flow = assert(
	loadstring(
		"return function(profile, controls)\nlocal step=Tutorial.step(profile)\nlocal shortcut={}\nlocal function object(name) return controls and controls[name] end\nlocal function chooseControl() return object('MenuButton'), 'tutorial_open_menu' end\n"
			.. source:sub(a, b - 1)
			.. "\nreturn {mode=worldMode,phase=phase,goal=displayGoal,control=nextControl}\nend"
	)
)
setfenv(flow, setmetatable({ Tutorial = Tutorial }, { __index = getfenv() }))
flow = flow()
local p = boundary.service.defaultProfile()
check("fresh player is directed at real mine blocks", flow(p).mode == "mine")
p.inventory[2] = { id = "gravel", count = 1 }
p.counters = { ["Гравий"] = 19, ["Песок"] = 15, ["Земля"] = 15 }
check("one missing resource cannot cause a sale trip", flow(p).mode == "mine")
p.counters["Гравий"] = 20
check("all resources give the first sale direction", flow(p).mode == "sell")
Tutorial.soldForUpgrade(p, 115)
p.inventory[2] = nil
check(
	"after first sale more earning is explained with no block target",
	flow(p).mode == nil and flow(p).phase == "tutorial_earn_upgrade"
)
p.inventory[2] = { id = "gravel", count = 1 }
check("another single block does not restart highlights or seller trips", flow(p).mode == nil)
p.coins = 49900
check("sufficient bag now leads back to seller", flow(p).mode == "sell")
p.coins = 50000
local menu = {}
check(
	"cash from any source goes directly to real menu control",
	flow(p, { MenuButton = menu }).control == menu
)
M.TutorialService.OnUpgraded(actor, "pickaxe", 1, 2)
check("other equipment cannot skip shovel onboarding", Tutorial.step(session.profile) == 3)
session.profile.tutorial.ordinaryCaseOpened = true
M.TutorialService.OnUpgraded(actor, "shovel", 1, 2)
check(
	"shovel checkpoint preserves first-case completion",
	session.profile.tutorial.ordinaryCaseOpened and Tutorial.step(session.profile) == 4
)
p.tutorial = { version = 2, step = 4 }
p.blocksTotal = 469
check(
	"level mining is explained without a world marker",
	flow(p).mode == nil and flow(p).phase == "tutorial_collect_level"
)
p.blocksTotal = 470
local button = {}
check(
	"complete resources and achievement money point to level up",
	flow(p, { LevelUp = button }).control == button
)
p.coins = 49900
check("complete level resources and valuable bag point to seller", flow(p).mode == "sell")
p.coins = 0
check("first level sale points to seller even with a partial bag", flow(p).mode == "sell")
check(
	"level sale checkpoint waits for a sufficient second batch",
	Tutorial.soldForLevel(p, 115) and flow(p).mode == nil
)
p.coins = 49900
check("second batch that covers the deficit points back to seller", flow(p).mode == "sell")
p.selectedSlot = 2
p.inventory[2] = { id = "ordinary_key", count = 1 }
check("equipped ordinary key temporarily guides its case", flow(p).mode == "case")
p.selectedSlot = 1
check("key merely in backpack never diverts onboarding", not Tutorial.shouldGuideCase(p))
p.selectedSlot = 2
p.tutorial.ordinaryCaseOpened = true
check("already opened case never repeats its guide", not Tutorial.shouldGuideCase(p))
p.tutorial.ordinaryCaseOpened = nil
p.level = 2
check(
	"level two ends all onboarding including case arrows",
	Tutorial.step(p) == 5 and flow(p).mode == nil
)
p.tutorial = { version = 2, step = 3 }
check("level two ends even if player skipped shovel sequence", Tutorial.step(p) == 5)

check(
	"arbitrary tracking input rejected",
	not Tutorial.validTrackingTarget({})
		and not Tutorial.validTrackingTarget("../admin:1")
		and not Tutorial.validTrackingTarget("sword:999999")
)
check(
	"level and empty targets accepted",
	Tutorial.validTrackingTarget("level") and Tutorial.validTrackingTarget("")
)
for id, tool in C.tools do
	if tool.upgrades and #tool.upgrades > 0 then
		local q = boundary.service.defaultProfile()
		q.inventory = { [9] = { id = id, level = 1, count = 1 } }
		q.settings = { trackedUpgrade = id .. ":1" }
		local goal, kind = Tutorial.trackedGoal(q)
		check(
			id .. " current requirements can be pinned",
			goal and goal.itemId == id and kind == 3 and goal.target == 9
		)
		q.inventory[27], q.inventory[9] = q.inventory[9], nil
		check(id .. " moved item remains tracked", Tutorial.trackedGoal(q).target == 27)
		q.inventory[27].level = goal.to
		check(
			id .. " upgrade immediately tracks next tier",
			Tutorial.trackedGoal(q).level == goal.to
		)
	end
end
local q = boundary.service.defaultProfile()
q.inventory =
	{ [1] = { id = "sword", level = 1, count = 1 }, [2] = { id = "sword", level = 2, count = 1 } }
q.settings = { trackedUpgrade = "sword:1" }
check(
	"confirmed upgrade advances pinned tier past duplicate lower-tier items",
	Tutorial.advanceTrackedUpgrade(q, "sword", 1, 2) and Tutorial.trackedGoal(q).target == 2
)
check(
	"unrelated upgrade cannot advance the selected tracked tier",
	not Tutorial.advanceTrackedUpgrade(q, "pickaxe", 2, 3)
		and q.settings.trackedUpgrade == "sword:2"
)
session.profile.settings = { trackedUpgrade = "sword:2" }
local beforeStep = Tutorial.step(session.profile)
M.TutorialService.OnUpgraded(actor, "sword", 2, 3)
check(
	"actual server checkpoint saves manual tracker without changing onboarding",
	session.profile.settings.trackedUpgrade == "sword:3"
		and f.disk["User_-700"].settings.trackedUpgrade == "sword:3"
		and Tutorial.step(session.profile) == beforeStep
)
q.settings = { trackedUpgrade = "helmet:1" }
q.armor.helmet = { id = "helmet", level = 1, count = 1 }
check("equipped armor can be tracked", Tutorial.trackedGoal(q).target == "helmet")
q.settings.trackedUpgrade = "level"
q.level = 2
local goal, kind = Tutorial.trackedGoal(q)
check("manual level tracker remains after onboarding ends", kind == 4 and goal.level == 3)
q.level = 50
check("max level produces no invalid next-level card", Tutorial.trackedGoal(q) == nil)
session.profile.settings =
	{ trackedUpgrade = "shovel:1", hideRequirements = true, brightness = 1.2 }
boundary.service.SaveNow(actor)
check(
	"tracker preferences persist through profile reload",
	boundary.migrate(f.disk["User_-700"]).settings.trackedUpgrade == "shovel:1"
)
check("own reset succeeds with pinned card", boundary.service.ResetOwnProgress(actor))
check(
	"reset restores visible fresh tutorial but keeps personal brightness",
	session.profile.settings.trackedUpgrade == nil
		and session.profile.settings.hideRequirements == nil
		and session.profile.settings.brightness == 1.2
)

local first = assert(source:find("local initialFacing = false", 1, true))
local last = assert(source:find("task.spawn(function()", first, true))
local root = {
	Position = rb.Vector3.new(0, 4, 0),
	IsA = function()
		return true
	end,
}
local camera = { CFrame = rb.CFrame.new(0, 8, -10), Focus = rb.CFrame.new(0, 5, 0) }
local anchor = {
	Position = rb.Vector3.new(30, 0, 0),
	IsA = function()
		return true
	end,
	GetAttribute = function()
		return "prison"
	end,
}
local facing = assert(loadstring(source:sub(first, last - 1) .. "\nreturn faceMine"))
setfenv(
	facing,
	setmetatable({
		step = 3,
		player = { Character = {
			FindFirstChild = function()
				return root
			end,
		} },
		workspace = { CurrentCamera = camera },
		CollectionService = {
			GetTagged = function()
				return { anchor }
			end,
		},
		Vector3 = rb.Vector3,
		CFrame = rb.CFrame,
	}, { __index = getfenv() })
)
facing = facing()
q = boundary.service.defaultProfile()
facing(q)
check(
	"fresh character and camera face the actual mine anchor",
	root.CFrame.LookVector:Dot(rb.Vector3.xAxis) > 0.99
		and camera.CFrame.LookVector:Dot(rb.Vector3.xAxis) > 0.95
)
camera.CFrame = rb.CFrame.new(100, 100, 100)
facing(q)
check(
	"initial facing never takes control back after player turns",
	camera.CFrame == rb.CFrame.new(100, 100, 100)
)
print(serde.encode("json", {
	status = "PASS",
	count = #checks,
	checks = checks,
	realStores = false,
	nativeRendering = false,
}, true))
