--!strict
-- Offline only: lune run scripts/qa-ui-regressions.luau
-- Loads the real modules / handler bodies against isolated mocks; no Studio/profile changes.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local checks = 0
local function check(value: boolean, message: string)
	assert(value, message)
	checks += 1
end
local function compile(source: string, environment: any): any
	local chunk = assert(loadstring(source))
	setfenv(chunk, setmetatable(environment, { __index = getfenv() }))
	return chunk()
end
local Layout = compile(fs.readFile("src/client/AuctionLayout.luau"), {})
local Transfers = compile(fs.readFile("src/client/StorageTransferUi.luau"), {})
local state = Transfers.new()
state.queue = { page = 2, index = 1 }
check(Transfers.next(state) == 1, "take all starts at slot1")
local first = Transfers.begin(state, 8, 2)
check(Transfers.next(state) == nil, "only one durable request is in flight")
Transfers.observe(state, 8, false, 2)
check(state.pending == first, "idle attribute alone does not acknowledge a transfer")
Transfers.observe(state, 9, true, 2)
check(state.pending == first, "profile revision alone does not unblock a busy server")
Transfers.observe(state, 9, false, 2)
check(
	state.pending == nil and Transfers.next(state) == 2,
	"matched durable revision and idle server advance one slot"
)
local second = Transfers.begin(state, 9, 2)
check(
	not Transfers.expire(state, first) and state.pending == second,
	"an old timeout cannot cancel a newer transfer"
)
Transfers.observe(state, 8, false, 2)
check(state.pending == second, "older profile revision cannot acknowledge a newer transfer")
Transfers.observe(state, 10, false, 3)
check(
	state.pending == nil and state.queue == nil,
	"page changes cancel pending selection and take-all queue"
)
state.queue = { page = 3, index = 1 }
local timeout = Transfers.begin(state, 10, 3)
check(Transfers.expire(state, timeout) and state.queue == nil, "latest timeout cancels whole queue")
state.queue = { page = 3, index = 1 }
for i = 1, 27 do
	check(Transfers.next(state) == i, "take all visits each page slot once")
end
check(Transfers.next(state) == nil and state.queue == nil, "take all stops at page boundary")
local chestSource = fs.readFile("src/client/ChestWindow.luau")
local batchStart = assert(
	chestSource:find("end, function(from: Address, targets: { Address }, count: number)", 1, true)
) + 5
local batchEnd = assert(chestSource:find("\n\tend)\n\tpumpTakeAll =", batchStart, true))
local pumpStart = assert(chestSource:find("\tpumpTakeAll = function()", batchEnd, true))
local pumpEnd = assert(chestSource:find("\n\tlocal function grid", pumpStart, true))
local requests = {}
local splitState = Transfers.new()
local splitEnvironment = {
	isShared = true,
	transfer = splitState,
	StorageTransferUi = Transfers,
	moveSection = function()
		return 2
	end,
	busy = function()
		return splitState.pending ~= nil
	end,
	stackAt = function()
		return nil
	end,
	move = function(from, to, count)
		table.insert(requests, { from = from, to = to, count = count })
		Transfers.begin(splitState, #requests - 1, 2)
	end,
}
compile(chestSource:sub(pumpStart, pumpEnd - 1), splitEnvironment)
local batch =
	compile("return " .. chestSource:sub(batchStart, batchEnd - 1) .. "\nend", splitEnvironment)
batch({ container = "case", index = 1 }, {
	{ container = "inv", index = 1 },
	{ container = "inv", index = 2 },
	{ container = "inv", index = 3 },
}, 4)
check(#requests == 1, "actual shared split gesture sends only first request immediately")
for i = 1, 3 do
	check(
		#requests == i and requests[i].to.index == i and requests[i].count == 4,
		"actual split queue preserves destination and split amount"
	)
	Transfers.observe(splitState, i, false, 2)
	splitEnvironment.pumpTakeAll()
end
check(
	#requests == 3 and splitEnvironment.moveQueue == nil,
	"all split destinations complete sequentially without losing later requests"
)
local dragSource = fs.readFile("src/client/DragDrop.luau")
local distributeStart =
	assert(dragSource:find("\tlocal function distribute(path: { Address })", 1, true))
local distributeEnd = assert(dragSource:find("\n\tlocal function endSplit", distributeStart, true))
local delegated, heldCleared = false, false
local distribute =
	compile(dragSource:sub(distributeStart, distributeEnd - 1) .. "\nreturn distribute", {
		held = { from = { container = "case", index = 1 } },
		getStack = function(address)
			return if address.container == "case" then { id = "stone", count = 12 } else nil
		end,
		same = function(a, b)
			return a.container == b.container and a.index == b.index
		end,
		setHeld = function(value)
			heldCleared = value == nil
		end,
		moveMany = function(_, targets, each)
			delegated = #targets == 3 and each == 4
		end,
		move = function()
			error("batch-enabled chest must not emit concurrent individual split requests")
		end,
	})
distribute({
	{ container = "inv", index = 1 },
	{ container = "inv", index = 2 },
	{ container = "inv", index = 3 },
})
check(
	delegated and heldCleared,
	"actual DragDrop distribution delegates the complete gesture and clears held selection"
)
for _, viewport in ipairs({ { 390, 844 }, { 844, 390 }, { 1280, 720 } }) do
	local width, height = Layout.window(viewport[1], viewport[2], 58)
	local contentWidth, pageHeight = width - 12, height - 58 - 70
	local plan = Layout.plan(contentWidth, pageHeight)
	check(
		width <= viewport[1] - 20 and height <= viewport[2] - 58 - 12,
		"window fits without scale"
	)
	check(
		plan.gridHeight >= 46 and 48 + plan.gridHeight <= pageHeight - 44,
		"lot area clears header / pager"
	)
	check(plan.gridX + plan.gridWidth <= contentWidth, "grid fits content")
	local cells = {}
	for i = 1, 60 do
		local x, y = ((i - 1) % plan.columns) * 50, math.floor((i - 1) / plan.columns) * 50
		check(
			x + 46 <= plan.gridWidth - 6 and y + 46 <= plan.gridCanvas,
			"all 60 full-size lots fit canvas"
		)
	end
	for slot = 1, 36 do
		local x, y = Layout.inventory(slot, plan.inventoryColumns)
		local key = x .. ":" .. y
		check(not cells[key], "inventory cells do not overlap")
		cells[key] = true
		check(
			x + 44 <= (if plan.wide then 428 else contentWidth - 8),
			"inventory fits at full touch size"
		)
		check(plan.wide or y + 44 < plan.formY, "portrait inventory clears sale form")
	end
	check(
		plan.formWidth >= 280 and plan.formX + plan.formWidth <= contentWidth - 8,
		"sale form fits"
	)
	print(
		string.format(
			"layout %dx%d: window %dx%d, lots %d columns x %dpx viewport, sale %dpx",
			viewport[1],
			viewport[2],
			width,
			height,
			plan.columns,
			plan.gridHeight,
			plan.formWidth
		)
	)
end

local editing, focused = false, false
local humanoid = { Health = 100 }
local player = {
	Character = nil,
	PlayerGui = {
		GetGuiObjectsAtPosition = function()
			return {}
		end,
	},
}
local character = {
	FindFirstChildOfClass = function()
		return humanoid
	end,
}
local inputService = {
	TouchEnabled = true,
	GetFocusedTextBox = function()
		return focused and {} or nil
	end,
	GetMouseLocation = function()
		return roblox.Vector2.new(100, 100)
	end,
}
local fakeScript = { Parent = { HudLayout = {} } }
local Input = compile(fs.readFile("src/client/WindowInput.luau"), {
	script = fakeScript,
	game = {
		GetService = function(_, name)
			if name == "Players" then
				return { LocalPlayer = player }
			end
			if name == "UserInputService" then
				return inputService
			end
			return {}
		end,
	},
	require = function()
		return {
			isEditing = function()
				return editing
			end,
		}
	end,
})
check(Input.GameplayBlocked(false), "no character blocks gameplay")
player.Character = character
check(not Input.GameplayBlocked(false), "living character can act")
check(Input.GameplayBlocked(true), "window blocks gameplay")
editing = true
check(Input.GameplayBlocked(false), "HUD editor blocks gameplay")
editing = false
focused = true
check(Input.GameplayBlocked(false), "typing blocks gameplay")
focused = false
humanoid.Health = 0
check(Input.GameplayBlocked(false), "dead character blocks gameplay")
humanoid.Health = 100

local source = fs.readFile("src/client/init.client.luau")
check(loadstring(source) ~= nil, "whole client script compiles within Luau local/register limits")
check(
	loadstring(fs.readFile("src/client/AuctionWindow.luau")) ~= nil,
	"whole auction module compiles"
)
local actions, aims = 0, 0
local touchStarted, heartbeat
local env = {
	script = { WindowInput = {} },
	require = function()
		return Input
	end,
	Enum = roblox.Enum,
	Vector2 = roblox.Vector2,
	player = player,
	UserInputService = inputService,
	isMobile = function()
		return true
	end,
	touchOnRightHalf = function()
		return true
	end,
	aimAt = function()
		aims += 1
		return nil
	end,
	attack = function()
		actions += 1
	end,
	stopDig = function() end,
	BowController = {
		InHand = function()
			return false
		end,
		Cancel = function() end,
	},
	Eating = { Hold = function() end },
}
local mouseStart = assert(source:find("local function onDig", 1, true))
local mouseEnd = assert(source:find("\nContextActionService:BindAction(", mouseStart, true))
local mouse = compile(source:sub(mouseStart, mouseEnd - 1) .. "\nreturn onDig", env)
inputService.TouchStarted = {
	Connect = function(_, callback)
		touchStarted = callback
	end,
}
local touchStart = assert(source:find("UserInputService.TouchStarted:Connect(function(", 1, true))
local touchEnd = assert(source:find("\nend)", touchStart, true))
compile(source:sub(touchStart, touchEnd + 4), env)
local begin = roblox.Enum.UserInputState.Begin
local mouseInput = { UserInputType = roblox.Enum.UserInputType.MouseButton1 }
local touchInput =
	{ UserInputType = roblox.Enum.UserInputType.Touch, Position = roblox.Vector3.new(300, 200, 0) }
-- Real desktop input rather than the synthetic mouse event emitted by a touch screen.
inputService.TouchEnabled = false
for _, condition in ipairs({ "window", "editor", "missing", "dead", "typing" }) do
	env.currentWindowKind = if condition == "window" then "inventory" else nil
	editing, focused = condition == "editor", condition == "typing"
	player.Character = if condition == "missing" then nil else character
	humanoid.Health = if condition == "dead" then 0 else 100
	local beforeActions, beforeAims = actions, aims
	mouse("Dig", begin, mouseInput)
	touchStarted(touchInput, false)
	check(
		actions == beforeActions and aims == beforeAims and env.activeTouch == nil,
		condition .. " blocks actual mouse and touch entry handlers"
	)
end
editing, focused, env.currentWindowKind = false, false, nil
player.Character, humanoid.Health = character, 100
mouse("Dig", begin, mouseInput)
check(actions == 1, "actual unblocked mouse handler attacks")
touchStarted(touchInput, false)
check(env.activeTouch == touchInput, "actual unblocked touch handler tracks finger")
-- Run the exact blocked heartbeat prefix: held inputs must not resume after closing an editor.
local beatStart = assert(
	source:find(
		"RunService.Heartbeat:Connect(function()\n\tif require(script.WindowInput).GameplayBlocked",
		1,
		true
	)
)
local beatEnd = assert(source:find("\n\t-- a finger resting", beatStart, true))
env.RunService = { Heartbeat = {
	Connect = function(_, callback)
		heartbeat = callback
	end,
} }
local cancelStart = assert(source:find("local function cancelDigInput()", 1, true))
local cancelEnd = assert(source:find("\nend", cancelStart, true))
env.cancelDigInput =
	compile(source:sub(cancelStart, cancelEnd + 3) .. "\nreturn cancelDigInput", env)
compile(source:sub(beatStart, beatEnd - 1) .. "\nend)", env)
editing, env.holding, env.attackHeld, env.touchBow = true, true, true, true
heartbeat()
check(
	not env.holding and not env.attackHeld and not env.touchBow and env.activeTouch == nil,
	"editor cancels all held mouse/touch intents"
)

local reticleStart = assert(
	source:find(
		"\tcrosshair.Visible = (firstPerson or isMobile() or BowController.Drawing())",
		1,
		true
	)
)
local reticleEnd = assert(source:find("\n\tif require", reticleStart, true))
local drawing = true
env.crosshair = {}
env.firstPerson = false
env.isMobile = function()
	return false
end
env.BowController.Drawing = function()
	return drawing
end
editing = false
compile(source:sub(reticleStart, reticleEnd - 1), env)
check(env.crosshair.Visible, "third-person bow reticle stays visible in actual frame assignment")
drawing = false
compile(source:sub(reticleStart, reticleEnd - 1), env)
check(not env.crosshair.Visible, "third-person idle reticle is hidden")

local bowSource = fs.readFile("src/client/BowController.luau")
local releaseStart = assert(bowSource:find("function BowController.Release()", 1, true))
local releaseEnd = assert(bowSource:find("\nend", releaseStart, true))
local canceled = false
local bowEnvironment = {
	BowController = {
		Cancel = function()
			canceled = true
		end,
	},
	BowState = { LocalDrawAt = 1 },
	isBlocked = function()
		return true
	end,
}
compile(bowSource:sub(releaseStart, releaseEnd + 3), bowEnvironment)
bowEnvironment.BowController.Release()
check(canceled, "bow release cancels immediately when UI opens between heartbeat and release")

local effectSource = fs.readFile("src/client/EffectsHud.luau")
local effectStart = assert(
	effectSource:find(
		"\t\tfunction(dt: number)",
		effectSource:find('"PrisonEffects"', 1, true),
		true
	)
)
local effectEnd = assert(effectSource:find("\n\t\tend\n\t)", effectStart, true))
local camera = { FieldOfView = 96 }
local effectsEnv = {
	workspace = { CurrentCamera = camera },
	player = { Character = nil },
	nausea = 1,
	blind = 1,
	fovFactor = 1.5,
	hurtAt = 100,
	darkness = { Visible = true },
	fovApplied = true,
	BASE_FOV = 70,
}
local effectFrame = compile("return " .. effectSource:sub(effectStart, effectEnd + 5), effectsEnv)
for _ = 1, 60 do
	effectFrame(1 / 60)
end
check(
	camera.FieldOfView == 70
		and not effectsEnv.darkness.Visible
		and effectsEnv.nausea == 0
		and effectsEnv.blind == 0,
	"60 characterless effects frames safely reset FOV and overlays"
)

print(string.format("PASS: %d UI regression checks", checks))
