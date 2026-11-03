--!nocheck
-- Actual TutorialPanel + Strings + Config; only GUI/event boundaries are mocked.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local prefix = fs.readFile("scripts/qa-release-upgrade-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local fn = assert(loadstring", 1, true)) - 1)
local boundary = assert(loadstring(prefix .. "\nreturn {node=node, Ui=Ui, modules=f.modules}"))()
local M, Ui = boundary.modules, boundary.Ui
local function node(kind)
	local n = boundary.node(kind)
	n.Enabled, n.AbsolutePosition, n.AbsoluteSize = true, rb.Vector2.zero, rb.Vector2.new(10, 10)
	function n:GetAttribute(key)
		return self.attributes and self.attributes[key]
	end
	function n:IsA(class)
		return self.ClassName == class
			or (class == "GuiButton" and self.ClassName == "TextButton")
			or (
				class == "GuiObject"
				and table.find(
						{ "Frame", "TextButton", "TextLabel", "ImageLabel", "ScrollingFrame" },
						self.ClassName
					)
					~= nil
			)
	end
	function n:GetDescendants()
		local out = {}
		for _, child in self.children do
			table.insert(out, child)
			for _, desc in child:GetDescendants() do
				table.insert(out, desc)
			end
		end
		return out
	end
	function n:IsDescendantOf(ancestor)
		local p = self.Parent
		while p do
			if p == ancestor then
				return true
			end
			p = p.Parent
		end
		return false
	end
	return n
end
local function make(kind, parent, text, size, pos)
	local n = node(kind)
	n.Parent, n.Text, n.Size, n.Position = parent, text, size, pos
	return n
end
Ui.card = function(parent, size, pos)
	return make("Frame", parent, nil, size, pos)
end
Ui.inset = Ui.card
Ui.label = function(parent, text, size, pos)
	return make("TextLabel", parent, text, size, pos)
end
Ui.button = function(parent, text, size, pos)
	return make("TextButton", parent, text, size, pos)
end
local names = setmetatable({ Parent = { Config = "Config" } }, {
	__index = function(_, key)
		return key
	end,
})
local sf = assert(loadstring(fs.readFile("src/shared/Strings/init.luau")))
setfenv(
	sf,
	setmetatable({
		script = names,
		require = function(id)
			return if id == "Config"
				then M.Config
				else assert(loadstring(fs.readFile("src/shared/Strings/" .. id .. ".luau")))()
		end,
	}, { __index = getfenv() })
)
M.Strings = sf()
local fn = assert(loadstring(fs.readFile("src/client/TutorialPanel.luau")))
setfenv(
	fn,
	setmetatable({
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
		require = function(id)
			return assert(M[id], id)
		end,
		Instance = { new = node },
		Enum = rb.Enum,
		UDim2 = rb.UDim2,
	}, { __index = getfenv() })
)
local Panel = fn()
local checks = {}
local function check(name, pass)
	assert(pass, name)
	table.insert(checks, name)
end
local playerGui, gui = node("PlayerGui"), node("ScreenGui")
gui.Parent = playerGui
local opened
local card = Panel.new(gui, function(kind)
	opened = kind
end)
local function find(name)
	for _, n in card.frame:GetDescendants() do
		if n.Name == name then
			return n
		end
	end
	error(name)
end
local goal = {
	itemId = "shovel",
	level = 1,
	to = 2,
	cost = 30000,
	coins = 0,
	ready = false,
	estimatedSale = 1200,
	requirements = {},
}
for counter, needed in M.Config.upgrade("shovel", 1).requirements do
	table.insert(goal.requirements, { counter = counter, needed = needed, have = needed - 1 })
end
check("actual starter has three material requirements", #goal.requirements == 3)
local expected = {}
for _, id in { "gravel", "dirt", "sand" } do
	expected[M.Config.iconFor(id)] = true
end
for _, locale in { "ru", "en", "es", "fr" } do
	card.Update(3, locale, goal, "tutorial_collect_upgrade", rb.Vector2.new(1280, 720), 58, {})
	check(
		locale .. " header is localized",
		find("RequirementsTitle").Text == M.Strings.t("requirements", locale)
	)
	check(locale .. " exact three rows", find("RequirementsCount").Text == "0 / 3")
	for index = 1, 3 do
		local row = find("Requirement_" .. index)
		check(
			locale .. " genuine icon " .. index,
			expected[row:FindFirstChild("Icon").Image] == true
		)
		check(
			locale .. " no false checkmark " .. index,
			not row:FindFirstChild("Progress").Text:find("✓", 1, true)
		)
		check(
			locale .. " exact counter name " .. index,
			row:FindFirstChild("ResourceName").Text
				== M.Strings.counterName(row:GetAttribute("RequirementCounter"), locale)
		)
	end
	check(
		locale .. " money has separate row",
		find("MoneyRequirement"):FindFirstChild("ResourceName").Text
			== M.Strings.t("tutorial_panel_money", locale)
	)
	check(
		locale .. " actual cash not projected cash",
		find("MoneyRequirement"):FindFirstChild("Progress").Text
			== "$" .. M.Strings.money(0) .. " / $" .. M.Strings.money(30000)
	)
	check(
		locale .. " projected sale labeled separately",
		find("TaskHint").Text
			== M.Strings.t(
				"tutorial_panel_after_sale",
				locale,
				M.Strings.money(1200),
				M.Strings.money(30000)
			)
	)
end
for _, r in goal.requirements do
	r.have = r.needed
end
goal.saleReady, goal.estimatedSale = true, 30000
card.Update(3, "en", goal, "tutorial_sell_blocks", rb.Vector2.new(1280, 720), 58, {})
check("completed materials header", find("RequirementsCount").Text == "3 / 3")
for index = 1, 3 do
	check(
		"complete marker " .. index,
		find("Requirement_" .. index):FindFirstChild("Progress").Text:find("✓", 1, true) ~= nil
	)
end
check("sale quote cannot enable upgrade shortcut", not card.shortcut.Visible)
check("seller phase explicit", find("TaskHint").Text == M.Strings.t("tutorial_panel_sell", "en"))
goal.coins, goal.ready, goal.saleReady = goal.cost, true, false
local function overlap(a, b)
	return a.x < b.x + b.width
		and a.x + a.width > b.x
		and a.y < b.y + b.height
		and a.y + a.height > b.y
end
for _, sample in
	{
		{
			view = rb.Vector2.new(1280, 720),
			blocks = {
				{ x = 1056, y = 288, width = 214, height = 160 },
				{
					x = 430,
					y = 660,
					width = 420,
					height = 52,
				},
			},
		},
		{
			view = rb.Vector2.new(390, 844),
			blocks = {
				{ x = 242, y = 64, width = 139, height = 104 },
				{ x = 0, y = 600, width = 156, height = 244 },
				{ x = 290, y = 690, width = 80, height = 80 },
				{ x = 54, y = 790, width = 280, height = 46 },
				{ x = 12, y = 64, width = 56, height = 56 },
			},
		},
		{
			view = rb.Vector2.new(844, 390),
			blocks = {
				{ x = 696, y = 64, width = 139, height = 104 },
				{ x = 0, y = 245, width = 300, height = 145 },
				{ x = 748, y = 225, width = 80, height = 80 },
				{ x = 640, y = 270, width = 84, height = 84 },
				{ x = 205, y = 330, width = 440, height = 52 },
			},
		},
	}
do
	card.Update(3, "en", goal, "tutorial_open_menu", sample.view, 58, sample.blocks)
	local p, s = card.frame.Position, card.frame.Size
	local rect = { x = p.X.Offset, y = p.Y.Offset, width = s.X.Offset, height = s.Y.Offset }
	check(
		tostring(sample.view) .. " usable right-side panel",
		rect.height >= 90 and rect.x + rect.width > sample.view.X / 2 and rect.width == 250
	)
	check(
		tostring(sample.view) .. " fits safe screen",
		rect.y >= 66 and rect.y + rect.height <= sample.view.Y - 8
	)
	for index, obstacle in sample.blocks do
		check(tostring(sample.view) .. " clear control " .. index, not overlap(rect, obstacle))
	end
	check(
		tostring(sample.view) .. " shortcut retains 44px touch height",
		card.shortcut.Size.Y.Offset == 44
	)
end
card.shortcut.Activated:Fire()
check("shortcut still opens ordinary menu", opened == "menu")
local levelGoal = {
	level = 2,
	blocks = 9,
	neededBlocks = 10,
	coins = 0,
	cost = 20000,
	ready = false,
	estimatedSale = 0,
}
card.Update(4, "fr", levelGoal, "tutorial_collect_level", rb.Vector2.new(390, 844), 58, {})
check(
	"level task reuses actual block count",
	find("Requirement_1"):FindFirstChild("Progress").Text == "9 / 10"
)
check("old third material hidden after phase transition", not find("Requirement_3").Visible)
card.Update(3, "en", goal, "tutorial_open_menu", rb.Vector2.new(390, 844), 58, {})
check(
	"reset reuses rows without old money sizing",
	find("Requirement_2"):FindFirstChild("Progress").Size.X.Offset == 86
)
local blocker = node("TextButton")
blocker.Name = "Touch_attack"
blocker.Parent = gui
local hidden = node("Frame")
hidden.Visible = false
hidden.Parent = gui
local child = node("TextButton")
child.Parent = hidden
local stats = node("Frame")
stats.Name = "Scoreboard"
stats.Parent = gui
local obstacles = Panel.obstacles(gui, card.frame, playerGui)
check("only visible controls and scoreboard block placement", #obstacles == 2)
local noSpace =
	Panel.place(rb.Vector2.new(390, 844), 58, 240, { { x = 0, y = 0, width = 390, height = 844 } })
check("fully obstructed HUD never covered by fallback", noSpace.height == 0)
local source = fs.readFile("src/client/TutorialGuide.luau")
local _, uses = source:gsub('worldMode = if goal.saleReady then "sell" else "mine"', "")
check(
	"both guide stages gate seller on shared sale readiness",
	uses == 2 and not source:find("canSell", 1, true)
)
print(serde.encode("json", {
	passed = #checks,
	actualPanel = true,
	actualConfig = true,
	actualLocales = true,
	nativeRendering = false,
}, true))
