--!nocheck
-- Actual layout calculator, init updateLayout closure, and HudLayout.apply; mocked GUI boundaries.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-hint-layout-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local original =", 1, true)) - 1)
local f = assert(
	loadstring(
		prefix .. "\nreturn {node=node,gui=gui,reflow=reflow,Hud=Hud,core=core,signal=signal}"
	)
)()
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local module = assert(loadstring(fs.readFile("src/client/HudDefaults.luau")))
setfenv(
	module,
	setmetatable(
		{ UDim2 = rb.UDim2, Vector2 = rb.Vector2, Enum = rb.Enum },
		{ __index = getfenv() }
	)
)
local Defaults = module()
local src = fs.readFile("src/client/init.client.luau")
check("whole client compiles within Luau register limit", loadstring(src) ~= nil)
local first = assert(src:find("local function updateLayout()", 1, true))
local last = assert(src:find("relayoutHud = function()", first, true))
local update = assert(loadstring(src:sub(first, last - 1) .. "\nreturn updateLayout"))
local e = {
	gui = f.gui,
	HudLayout = f.Hud,
	statText = {},
	hotbarSlots = {},
	slotScales = {},
	hudOverride = {},
	windowLayouts = {},
	profile = { hudLayout = {} },
	SLOT = 44,
	isMobile = function()
		return true
	end,
	script = { HudDefaults = "HudDefaults" },
	require = function()
		return Defaults
	end,
	cancelDigInput = function() end,
	renderCameraButton = function() end,
	Vector2 = rb.Vector2,
	UDim2 = rb.UDim2,
	Enum = rb.Enum,
}
for _, name in
	{
		"touchMenus",
		"touchActions",
		"hints",
		"languageButton",
		"artifactButton",
		"menuButton",
		"stats",
		"effectsHud",
		"boosterHud",
		"hotbar",
		"viewButton",
		"inventoryButton",
		"toast",
		"toastText",
		"menuToggle",
		"touchMenuGrid",
		"eatButton",
		"teleportCountdown",
		"hotbarScale",
		"survivalScale",
	}
do
	e[name] = f.node("Frame")
	e[name].Name = name
	e[name].Parent = f.gui
	e[name].Position = rb.UDim2.new()
	e[name].Size = rb.UDim2.new()
end
e.touchMenuGrid.Size = rb.UDim2.fromOffset(360, 240)
e.menuToggle.Parent = e.touchMenus
e.touchMenuGrid.Parent = e.touchMenus
e.inventoryButton.Parent = e.touchActions
e.eatButton.Parent = e.touchActions
for name, id in
	{
		stats = "stats",
		effectsHud = "effects",
		boosterHud = "boosters",
		viewButton = "view",
		inventoryButton = "inventory",
		toast = "toasts",
		touchMenus = "menu",
		eatButton = "eat",
	}
do
	f.Hud.register(id, e[name], true, true)
end
for name, id in { Touch_jump = "jump", Touch_attack = "attack", Touch_sprint = "sprint" } do
	local n = f.node("Frame")
	n.Name = name
	n.Parent = e.touchActions
	n.AnchorPoint = if id == "jump" then rb.Vector2.zero else rb.Vector2.one
	f.Hud.register(id, n, true, false)
end
e.statText.sbTitle = f.node("TextLabel")
for i, key in { "statLevel", "statMoney", "statBlocks", "statFaction", "statRats", "statKD" } do
	e.statText[key], e.statText[key .. "Label"] = f.node("TextLabel"), f.node("TextLabel")
	local icon = f.node("ImageLabel")
	icon.Name = "StatIcon_" .. i
	icon.Parent = e.stats
end
for i = 1, 9 do
	e.hotbarSlots[i] = f.node("Frame")
	e.slotScales[i] = f.node("UIScale")
end
e.player = f.node("Player")
setfenv(update, setmetatable(e, { __index = getfenv() }))
update = update()

local requirement = f.node("Frame")
requirement.Name, requirement.Parent, requirement.Size =
	"FirstSteps", f.gui, rb.UDim2.fromOffset(210, 126)
f.Hud.register("requirements", requirement, true, true)
local function prepare(w, h)
	e.workspace = { CurrentCamera = { ViewportSize = rb.Vector2.new(w, h) } }
	e.GuiService = {
		GetGuiInset = function()
			return rb.Vector2.new(0, 58)
		end,
	}
	f.gui.AbsoluteSize, f.gui.AbsolutePosition = rb.Vector2.new(w, h), rb.Vector2.new(0, -58)
	update()
	return rb.Vector2.new(w, h)
end
for _, dims in { { 666, 374 }, { 705, 338 }, { 750, 381 }, { 844, 390 }, { 1179, 819 } } do
	local view = prepare(dims[1], dims[2])
	local label = dims[1] .. "x" .. dims[2]
	local plan = Defaults.phone(view.X, view.Y, 58)
	local stats = Defaults.bounds(e.stats, view)
	check(
		label .. " stats fits top-right",
		stats.x >= 0 and stats.x + stats.width <= view.X and stats.y == 0 and stats.height == 116
	)
	check(
		label .. " title restored",
		e.statText.sbTitle.Visible and e.statText.sbTitle.TextSize == 12
	)
	for _, key in { "statLevel", "statMoney", "statBlocks", "statFaction", "statRats", "statKD" } do
		local name, value = e.statText[key .. "Label"], e.statText[key]
		check(
			label .. " label/value columns " .. key,
			name.Visible
				and name.Position.X.Offset + name.Size.X.Offset < value.Position.X.Offset
				and value.TextSize == 11
		)
	end
	check(
		label .. " small owner requirement scale",
		requirement:FindFirstChildOfClass("UIScale").Scale == 0.6
	)
	check(
		label .. " small owner effect scale",
		e.effectsHud:FindFirstChildOfClass("UIScale").Scale == 0.7
	)
	for _, object in { e.hotbar, e.viewButton, e.inventoryButton } do
		local r = Defaults.bounds(object, view)
		check(label .. " safe bottom " .. object.Name, math.abs(r.y + r.height - view.Y) < 0.001)
	end
	local menu = Defaults.bounds(e.touchMenus, view)
	check(label .. " owner menu remains left", menu.x < 40 and menu.y == 70)
	check(
		label .. " left menu grid opens right inside viewport",
		e.touchMenuGrid.Position.X.Offset > 0
			and menu.x + e.touchMenuGrid.Position.X.Offset + 360 <= view.X
	)
	local effects = Defaults.bounds(e.effectsHud, view)
	check(label .. " effects below restored labels", effects.y >= stats.y + stats.height + 6)
	check(
		label .. " owner left stack proportions",
		math.abs(plan.boosters.x - plan.menu.x - 51) < 0.01 and plan.requirements.y == 117
	)
end
local snapshot = serde.decode("json", fs.readFile("docs/research/owner-hud-layout-2026-11-03.json"))
local saved = {}
for id, raw in snapshot.profile.hudLayout.mobile do
	saved[id] = { raw["1"], raw["2"], raw["3"], raw["4"] }
end
local untouched = serde.encode("json", saved)
e.profile.hudLayout.mobile = saved
local view = prepare(750, 381)
local stats = Defaults.bounds(e.stats, view)
check(
	"saved wide stats clamps without writing profile",
	stats.x == 560 and serde.encode("json", saved) == untouched
)
check("saved0.6 never double scales", requirement:FindFirstChildOfClass("UIScale").Scale == 0.6)
check("saved0.7 never double scales", e.effectsHud:FindFirstChildOfClass("UIScale").Scale == 0.7)
check("saved effect below expanded stats", Defaults.bounds(e.effectsHud, view).y == 122)
check("saved menu opens into screen", e.touchMenuGrid.Position.X.Offset == 50)
for _, object in { e.viewButton, e.inventoryButton } do
	local r = Defaults.bounds(object, view)
	check("saved near-bottom docks " .. object.Name, math.abs(r.y + r.height - 381) < 0.001)
end
check("view saved X preserved", math.abs(e.viewButton.Position.X.Scale - saved.view[1]) < 0.000001)
check(
	"inventory saved X preserved",
	math.abs(e.inventoryButton.Position.X.Scale - saved.inventory[1]) < 0.000001
)
e.statText.statFaction.Text = string.rep("Long faction ", 20)
check(
	"long faction clips inside its own column",
	e.statText.statFaction.TextTruncate == rb.Enum.TextTruncate.AtEnd
		and not e.statText.statFaction.TextWrapped
		and e.statText.statFaction.Size.X.Offset == -98
)
e.profile.hudLayout.mobile.view = { 0.2, 0.5, 1, 1 }
prepare(750, 381)
check("unrelated higher custom control not docked", e.viewButton.Position.Y.Scale == 0.5)
e.profile.hudLayout.mobile.menu = { 0.92, 0.18, 1, 1 }
prepare(750, 381)
check("right custom menu opens left", e.touchMenuGrid.Position.X.Offset < 0)
e.profile.hudLayout = {}
e.isMobile = function()
	return false
end
view = prepare(1280, 720)
check("desktop retains labels", e.statText.statLevelLabel.Visible and e.statText.sbTitle.Visible)
check(
	"desktop bottom retained",
	e.hotbar.Position.Y.Offset == 0 and e.viewButton.Position.Y.Offset == 0
)
print(serde.encode("json", {
	passed = #checks,
	actualUpdateLayout = true,
	actualHudLayout = true,
	ownerSnapshot = true,
	nativeRendering = false,
}, true))
