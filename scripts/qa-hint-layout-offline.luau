--!nocheck
-- Actual Panel, HudLayout handlers, server SetHudLayout and Profile save/reacquisition.
-- GUI geometry/signals and stores are isolated mocks, never the owner or Studio.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-tutorial-panel-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local checks = {}", 1, true)) - 1)
local core = assert(loadstring(prefix .. "\nreturn {Panel=Panel,node=node,M=M}"))()
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local function signal()
	local entries = {}
	local s = {}
	function s:Connect(fn)
		local entry = { fn = fn, active = true }
		table.insert(entries, entry)
		return {
			Disconnect = function()
				entry.active = false
			end,
		}
	end
	function s:Fire(...)
		for _, entry in table.clone(entries) do
			if entry.active then
				entry.fn(...)
			end
		end
	end
	return s
end
local function node(kind)
	local n = core.node(kind)
	n.AnchorPoint, n.Scale = rb.Vector2.zero, 1
	for _, key in { "InputBegan", "Activated" } do
		n[key] = signal()
	end
	return n
end
local gui = node("ScreenGui")
gui.AbsoluteSize, gui.AbsolutePosition = rb.Vector2.new(750, 381), rb.Vector2.new(0, -58)
function gui:IsA(kind)
	return kind == "ScreenGui" or kind == "GuiBase2d"
end
local function reflow(parent, parentScale)
	for _, child in parent:GetChildren() do
		if child:IsA("GuiObject") then
			child.AnchorPoint = child.AnchorPoint or rb.Vector2.zero
			local own = child:FindFirstChildOfClass("UIScale")
			local scale = parentScale * (if own then own.Scale else 1)
			local area = parent.AbsoluteSize / parentScale
			local s, p = child.Size or rb.UDim2.new(), child.Position or rb.UDim2.new()
			child.AbsoluteSize = rb.Vector2.new(
				s.X.Scale * area.X + s.X.Offset,
				s.Y.Scale * area.Y + s.Y.Offset
			) * scale
			child.AbsolutePosition = parent.AbsolutePosition
				+ rb.Vector2.new(p.X.Scale * area.X + p.X.Offset, p.Y.Scale * area.Y + p.Y.Offset) * parentScale
				- child.AnchorPoint * child.AbsoluteSize
			reflow(child, scale)
		end
	end
end
local input = { InputChanged = signal(), InputEnded = signal() }
local render = signal()
local function loadHud()
	local fn = assert(loadstring(fs.readFile("src/client/HudLayout.luau")))
	setfenv(
		fn,
		setmetatable({
			game = {
				GetService = function(_, id)
					return ({
						RunService = { RenderStepped = render },
						UserInputService = input,
						GuiService = {
							GetGuiInset = function()
								return rb.Vector2.new(0, 58)
							end,
						},
					})[id]
				end,
			},
			Instance = { new = node },
			Enum = rb.Enum,
			Color3 = rb.Color3,
			UDim = rb.UDim,
			UDim2 = rb.UDim2,
			Vector2 = rb.Vector2,
		}, { __index = getfenv() })
	)
	return fn()
end
local Hud = loadHud()
local original = {
	stats = { 0.8, 0.2, 1, 0.65 },
	view = { 0.2, 0.9, 1, 1 },
	boosters = { 0.0116, 0.0116, 1, 1 },
}
local saved = table.clone(original)
local function find(name)
	for _, n in gui:GetDescendants() do
		if n.Name == name and n:IsDescendantOf(gui) then
			return n
		end
	end
	error("Missing " .. name)
end
local goal = {
	level = 5,
	blocks = 10,
	neededBlocks = 2500,
	coins = 0,
	cost = 500000,
	ready = false,
	estimatedSale = 0,
}
local card
local saves = 0
card = core.Panel.new(gui, function() end, nil, function()
	Hud.edit(gui, "mobile", saved, {
		title = core.M.Strings.t("tracker_edit_hint", "en"),
		done = core.M.Strings.t("tracker_lock", "en"),
		reset = "Reset",
		hide = "Hide",
		show = "Show",
	}, function(result)
		saved = result
		saves += 1
		Hud.apply("mobile", saved)
	end, "requirements")
end)
card.manual = true
card.frame.AnchorPoint = rb.Vector2.zero
Hud.register("requirements", card.frame, true, true, card.grip)
local stats = node("Frame")
stats.Size = rb.UDim2.fromOffset(100, 100)
stats.Position = rb.UDim2.new()
stats.Parent = gui
Hud.register("stats", stats, true, true)
card.Update(4, "en", goal, "tutorial_collect_level", gui.AbsoluteSize, 58, {})
Hud.setDefault(card.frame)
Hud.apply("mobile", saved)
reflow(gui, 1)
check(
	"tracked level card is220x100",
	card.frame.Size.X.Offset == 220 and card.frame.Size.Y.Offset == 100
)
check(
	"tracked redundant heading removed",
	not find("RequirementsTitle").Visible and not find("RequirementsCount").Visible
)
check(
	"tracked footer and menu shortcut removed",
	not find("TaskHint").Visible and not card.shortcut.Visible
)
local edit, close = find("EditRequirementsLayout"), find("HideRequirements")
check(
	"gear and close have separate44px hit areas",
	edit.Size.X.Offset == 44
		and close.Size.X.Offset == 44
		and edit.Position.X.Offset + 44 <= close.Position.X.Offset
)
for _, locale in { "ru", "en", "es", "fr" } do
	card.Update(4, locale, goal, "tutorial_collect_level", gui.AbsoluteSize, 58, {})
	check(
		locale .. " gear tooltip localized",
		edit:GetAttribute("Tooltip") == core.M.Strings.t("tracker_layout", locale)
	)
end
edit.MouseEnter:Fire()
check("gear hover shows explanation", find("RequirementsLayoutTooltip").Visible)
edit.MouseLeave:Fire()
check("gear hover ends cleanly", not find("RequirementsLayoutTooltip").Visible)
local autoPosition = card.frame.Position
card.Update(
	4,
	"en",
	goal,
	"tutorial_collect_level",
	gui.AbsoluteSize,
	58,
	{ { x = 0, y = 66, width = 750, height = 150 } }
)
check("automatic position stable when HUD buttons change", card.frame.Position == autoPosition)
edit.Activated:Fire()
reflow(gui, 1)
render:Fire()
reflow(gui, 1)
check("gear opens direct editor", Hud.isEditing())
check("only requirements receives drag handle", find("Handle_requirements") ~= nil)
local otherHandle = false
for _, n in gui:GetDescendants() do
	if n.Name == "Handle_stats" then
		otherHandle = true
	end
end
check("direct editor cannot move other HUD entries", not otherHandle)
check("size controls immediately visible", find("Sizer").Visible)
check(
	"size controls have44px touch height",
	find("Smaller").Size.Y.Offset == 44 and find("Bigger").Size.Y.Offset == 44
)
for _ = 1, 7 do
	find("Smaller").Activated:Fire()
end
check("minimum size is50percent", card.frame:FindFirstChildOfClass("UIScale").Scale == 0.5)
for _ = 1, 3 do
	find("Bigger").Activated:Fire()
end
check("plus uses10percent steps", card.frame:FindFirstChildOfClass("UIScale").Scale == 0.8)
card.preservePosition, card.editing = true, true
card.Update(4, "en", goal, "tutorial_collect_level", gui.AbsoluteSize, 58, {})
reflow(gui, 1)
render:Fire()
reflow(gui, 1)
local handle = find("Handle_requirements")
local before = card.frame.AbsolutePosition - gui.AbsolutePosition
local mouse =
	{ UserInputType = rb.Enum.UserInputType.MouseButton1, Position = rb.Vector3.new(20, 80, 0) }
handle.InputBegan:Fire(mouse)
input.InputChanged:Fire({
	UserInputType = rb.Enum.UserInputType.MouseMovement,
	Position = rb.Vector3.new(140, 120, 0),
})
reflow(gui, 1)
check(
	"actual mouse drag translates header",
	math.abs(card.frame.Position.X.Scale * 750 - before.X - 120) < 0.001
)
input.InputEnded:Fire(mouse)
local touch =
	{ UserInputType = rb.Enum.UserInputType.Touch, Position = rb.Vector3.new(100, 100, 0) }
handle.InputBegan:Fire(touch)
local beforeTouch = card.frame.Position
input.InputChanged:Fire({
	UserInputType = rb.Enum.UserInputType.Touch,
	Position = rb.Vector3.new(200, 150, 0),
})
check("another finger cannot steal drag", card.frame.Position == beforeTouch)
touch.Position = rb.Vector3.new(120, 110, 0)
input.InputChanged:Fire(touch)
reflow(gui, 1)
check(
	"matching touch moves card",
	math.abs(card.frame.Position.X.Scale - beforeTouch.X.Scale - 20 / 750) < 0.001
)
input.InputEnded:Fire(touch)
local positioned = card.frame.Position
Hud.apply("mobile", { requirements = { 0.9, 0.9, 1, 2 } })
check(
	"profile/layout refresh cannot interrupt edit",
	card.frame.Position == positioned and card.frame:FindFirstChildOfClass("UIScale").Scale == 0.8
)
find("LockLayout").Activated:Fire()
reflow(gui, 1)
check("lock leaves edit mode and submits once", not Hud.isEditing() and saves == 1)
check(
	"lock preserves unrelated HUD entries",
	saved.stats == original.stats and saved.view == original.view
)
check("lock stores chosen scale", saved.requirements[4] == 0.8)
card.editing = false
card.Update(4, "en", goal, "tutorial_collect_level", gui.AbsoluteSize, 58, {})
local pinned = card.frame.Position
for _ = 1, 30 do
	card.Update(
		4,
		"en",
		goal,
		"tutorial_collect_level",
		gui.AbsoluteSize,
		58,
		{ { x = 0, y = 0, width = 750, height = 381 } }
	)
end
check("pinned layout never auto-avoids transient controls", card.frame.Position == pinned)

-- The real server handler receives that tuple, then the actual Profile serializer saves/reloads it.
local profilePrefix = fs.readFile("scripts/qa-profile-persistence-offline.luau")
profilePrefix =
	profilePrefix:sub(1, assert(profilePrefix:find("-- Exact acquisition ownership", 1, true)) - 1)
local fixture = assert(loadstring(profilePrefix .. "\nreturn fixture"))()
local f = fixture()
local actor = f:player()
actor.UserId = -707
local a = f:profile("hint-layout-A")
local session = f:session(a, actor, "hint-A")
local remote = signal()
local serverTime = 100
local ps = fs.readFile("src/server/Services/ProfileService.luau")
local start = assert(ps:find("local HUD_IDS =", 1, true))
local finish = assert(ps:find("-- the settings window:", start, true))
local callback = assert(loadstring(ps:sub(start, finish - 1)))
setfenv(
	callback,
	setmetatable({
		Players = { PlayerRemoving = signal() },
		Remotes = {
			event = function()
				return { OnServerEvent = remote }
			end,
		},
		ProfileService = a.service,
		os = {
			clock = function()
				return serverTime
			end,
		},
	}, { __index = getfenv() })
)
callback()
remote:Fire(actor, "mobile", saved)
check(
	"actual server handler accepts requirements",
	session.profile.hudLayout.mobile.requirements[4] == 0.8
)
check(
	"already quantized coordinates survive floating-point representation",
	session.profile.hudLayout.mobile.boosters[1] == 0.0116
		and session.profile.hudLayout.mobile.boosters[2] == 0.0116
)
for _ = 1, 10 do
	serverTime += 2
	remote:Fire(actor, "mobile", session.profile.hudLayout.mobile)
end
check(
	"ten subsequent saves never move unrelated HUD entry",
	session.profile.hudLayout.mobile.boosters[1] == 0.0116
		and session.profile.hudLayout.mobile.boosters[2] == 0.0116
)
check("actual profile release saves layout", a.save(actor, session, true))
local b = f:profile("hint-layout-B")
local restored = f:session(b, actor, "hint-B")
local persisted = restored.profile.hudLayout.mobile
check("rejoin retains requirements size", persisted.requirements[4] == 0.8)
check("rejoin retains other HUD positions", persisted.stats[1] == 0.8 and persisted.view[2] == 0.9)
local rejoined = loadHud()
card.frame.Position = rb.UDim2.new()
card.frame:FindFirstChildOfClass("UIScale").Scale = 1
rejoined.register("requirements", card.frame, true, true, card.grip)
rejoined.apply("mobile", persisted)
check(
	"fresh client applies persisted coordinates",
	math.abs(card.frame.Position.X.Scale - persisted.requirements[1]) < 0.00001
		and math.abs(card.frame.Position.Y.Scale - persisted.requirements[2]) < 0.00001
)
check(
	"fresh client applies persisted scale",
	card.frame:FindFirstChildOfClass("UIScale").Scale == 0.8
)
local resetResult
rejoined.edit(
	gui,
	"mobile",
	persisted,
	{ title = "Drag", done = "Lock", reset = "Reset", hide = "Hide", show = "Show" },
	function(result)
		resetResult = result
	end,
	"requirements"
)
find("ResetLayout").Activated:Fire()
check(
	"direct reset removes only card layout",
	resetResult
		and resetResult.requirements == nil
		and resetResult.stats ~= nil
		and resetResult.view ~= nil
)
print(serde.encode("json", {
	passed = #checks,
	actualHudHandlers = true,
	actualServerHandler = true,
	actualProfileSaveReload = true,
	realProfiles = false,
	nativeInput = false,
}, true))
