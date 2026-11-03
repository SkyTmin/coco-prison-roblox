--!nocheck
-- Actual client RMB/L2 handler and consumable classifier; real catalog, fake input/network.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local base = fs.readFile("scripts/qa-economy-audit-offline.luau")
base = base:sub(1, assert(base:find("local p = fresh()", 1, true)) - 1)
local f = assert(loadstring(base .. "return {M=modules,load=execute}"))()
local M = f.M
M.Donate = f.load("src/shared/Donate.luau")
M.Potions = f.load("src/shared/Potions.luau")
local source = fs.readFile("src/client/init.client.luau")
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function signal()
	local cb
	return {
		Connect = function(_, fn)
			cb = fn
		end,
		Fire = function(_, ...)
			return cb(...)
		end,
	}
end
local profile = { selectedSlot = 2, inventory = {} }
local sent, opened, bow, eaten = 0, 0, 0, 0
local blocked, editing, focused = false, false, false
local input = {
	InputBegan = signal(),
	GetFocusedTextBox = function()
		return focused
	end,
}
local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
M.WindowInput = {
	GameplayBlocked = function()
		return blocked
	end,
}
M.BookWindow = {}
local env = {
	profile = profile,
	Config = M.Config,
	Shared = names,
	script = { Parent = names },
	require = function(id)
		return assert(M[id], id)
	end,
	HudLayout = {
		isEditing = function()
			return editing
		end,
	},
	open = function(kind)
		check("book route", kind == "book")
		opened += 1
	end,
	Remotes = {
		event = function(name)
			check("ordinary consumable intent only", name == "UseConsumable")
			return {
				FireServer = function(_, slot, look)
					check(
						"uses selected slot and look vector",
						slot == 2 and look == rb.Vector3.zAxis
					)
					sent += 1
				end,
			}
		end,
	},
	workspace = { CurrentCamera = { CFrame = { LookVector = rb.Vector3.zAxis } } },
	BowController = {
		InHand = function()
			return profile.inventory[2] and profile.inventory[2].id == "bow"
		end,
		Begin = function()
			bow += 1
		end,
	},
	Eating = {
		InHand = function()
			return profile.inventory[2] and profile.inventory[2].id == "apple"
		end,
		Hold = function()
			eaten += 1
		end,
	},
	UserInputService = input,
	Enum = rb.Enum,
}
env.script.WindowInput, env.script.BookWindow = "WindowInput", "BookWindow"
local a = assert(source:find("local function isNeedConsumable", 1, true))
local b = assert(source:find("-- The bow", a, true))
local c = assert(source:find("UserInputService.InputBegan:Connect", b, true))
local d = assert(source:find("UserInputService.InputEnded:Connect", c, true))
local fn = assert(loadstring(source:sub(a, b - 1) .. source:sub(c, d - 1)))
setfenv(fn, setmetatable(env, { __index = getfenv() }))
fn()
local function press(id, processed, key)
	profile.inventory[2] = if id then { id = id, count = 2 } else nil
	input.InputBegan:Fire(
		{ UserInputType = rb.Enum.UserInputType.MouseButton2, KeyCode = key or rb.Enum.KeyCode.A },
		processed or false
	)
end
for _, id in
	{
		"toilet_paper",
		"soap",
		"sleeping_bag",
		"needs_injection",
		"autosell",
		M.Donate.AUCTION_SLOT,
		"oblivion_scroll",
		"potion_drink",
		"potion_splash",
		"stand_recharge",
		M.Boosters.itemId("money", "local"),
	}
do
	local before = sent
	press(id)
	check("RMB sends exactly one use: " .. id, sent == before + 1)
end
for _, id in { M.Books.BOOK, M.Books.POWDER, M.Books.DISPELLER } do
	local before, uses = opened, sent
	press(id)
	check(
		"book UI retained: " .. id,
		opened == before + 1 and sent == uses and M.BookWindow.sourceSlot == 2
	)
end
local before = sent
press("bow")
press("apple")
press("stone")
press("pickaxe")
press(nil)
check(
	"bow and food keep their hold actions, ordinary items ignored",
	bow == 1 and eaten == 1 and sent == before
)
press("soap", true)
editing = true
press("soap")
editing = false
focused = true
press("soap")
focused = false
blocked = true
press("soap")
blocked = false
env.currentWindowKind = "inventory"
press("soap")
env.currentWindowKind = nil
check("processed input menus typing editing and loader block consumption", sent == before)
profile.inventory[2] = { id = "soap", count = 2 }
input.InputBegan:Fire(
	{ UserInputType = rb.Enum.UserInputType.Gamepad1, KeyCode = rb.Enum.KeyCode.ButtonL2 },
	false
)
check("gamepad L2 shares the fixed route", sent == before + 1)
local serverSource = fs.readFile("src/server/Services/NeedsService.luau")
local first = assert(serverSource:find("local function useConsumable(player:", 1, true))
local last = assert(serverSource:find("local function updatePlayers", first, true))
local factory = assert(loadstring(serverSource:sub(first, last - 1) .. "\nreturn useConsumable"))
local restoredNeed
local state = { inventory = {}, needs = { hygiene = 12, sleep = 8, toilet = 3 }, passes = {} }
local actor = {
	Character = {
		FindFirstChildOfClass = function()
			return { Health = 20 }
		end,
		FindFirstChild = function()
			return nil
		end,
	},
}
setfenv(
	factory,
	setmetatable({
		InventoryService = M.InventoryService,
		Config = M.Config,
		Donate = M.Donate,
		Boosters = M.Boosters,
		Potions = M.Potions,
		ProfileService = {
			Get = function()
				return state
			end,
			Mutate = function(_, fn)
				fn(state)
			end,
		},
		NEEDS = { "hygiene", "sleep", "toilet" },
		restored = function(_, need)
			restoredNeed = need
		end,
	}, { __index = getfenv() })
)
local serverUse = factory()
for _, need in { "hygiene", "sleep", "toilet" } do
	local id = M.Config.needs[need].consumable
	state.inventory = { [2] = { id = id, count = 2 }, [9] = { id = id, count = 4 } }
	restoredNeed = nil
	serverUse(actor, 2)
	check(
		"server consumes selected stack only: " .. id,
		state.inventory[2].count == 1 and state.inventory[9].count == 4
	)
	check("server restores actual need: " .. id, state.needs[need] == 100 and restoredNeed == need)
end
print(serde.encode("json", {
	passed = #checks,
	actualHandler = true,
	actualCatalog = true,
	actualServerConsumer = true,
	physicalInput = false,
	realProfiles = false,
}))
