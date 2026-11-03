--!nocheck
-- Actual UpgradeWindow module under Lune, with a small GUI/event boundary mock.
local fs = require("@lune/fs")
local rb = require("@lune/roblox")
local serde = require("@lune/serde")
local prefix = fs.readFile("scripts/qa-economy-audit-offline.luau")
prefix = prefix:sub(1, assert(prefix:find("local p = fresh()", 1, true)) - 1)
local f = assert(loadstring(prefix .. "return { modules=modules, fresh=fresh, events=events }"))()
local function signal()
	local list = {}
	return {
		Connect = function(_, fn)
			table.insert(list, fn)
		end,
		Fire = function(_, ...)
			for _, fn in list do
				fn(...)
			end
		end,
	}
end
local function node(class)
	local props = {
		ClassName = class,
		children = {},
		Visible = true,
		Interactable = true,
		Activated = signal(),
		CanvasPosition = rb.Vector2.zero,
	}
	local n = {}
	function props:FindFirstChild(name)
		for _, child in props.children do
			if child.Name == name then
				return child
			end
		end
		return nil
	end
	function props:SetAttribute(name, value)
		props.attributes = props.attributes or {}
		props.attributes[name] = value
	end
	function props:GetChildren()
		return table.clone(props.children)
	end
	function props:FindFirstChildOfClass(kind)
		for _, child in props.children do
			if child.ClassName == kind then
				return child
			end
		end
		return nil
	end
	function props:Destroy()
		props.destroyed = true
		props.Parent = nil
	end
	return setmetatable(n, {
		__index = props,
		__newindex = function(_, key, v)
			props[key] = v
			if key == "Parent" and v then
				table.insert(v.children, n)
			end
		end,
	})
end
local Ui = {
	colors = setmetatable({}, {
		__index = function()
			return rb.Color3.new(1, 1, 1)
		end,
	}),
	hex = function()
		return "#ffffff"
	end,
}
local function frame(parent, size, pos)
	local n = node("Frame")
	n.Parent = parent
	n.Size = size
	n.Position = pos
	return n
end
Ui.panel, Ui.inset = frame, frame
local function label(parent, text, size, pos)
	local n = node("TextLabel")
	n.Parent = parent
	n.Text = text
	n.Size = size
	n.Position = pos
	return n
end
Ui.rich, Ui.label = label, label
Ui.button = function(parent, text, size, pos)
	local n = label(parent, text, size, pos)
	n.ClassName = "TextButton"
	return n
end
Ui.invSlot = function(parent, size)
	local n = frame(parent, rb.UDim2.fromOffset(size, size), rb.UDim2.new())
	local icon = node("ImageLabel")
	icon.Parent = n
	return n, nil, nil, icon
end
f.modules.Ui = Ui
f.modules.EnchantmentVisual = { slot = function() end }
for _, key in { "itemFullName", "big", "counterName" } do
	f.modules.Strings[key] = tostring
end
local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local fn = assert(loadstring(fs.readFile("src/client/UpgradeWindow.luau")))
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
			return assert(f.modules[id], id)
		end,
		Instance = { new = node },
		Vector2 = rb.Vector2,
		UDim2 = rb.UDim2,
		Enum = rb.Enum,
	}, { __index = getfenv() })
)
local Upgrade = fn()
local p = f.fresh()
p.coins = 1e12
for _, tool in f.modules.Config.tools do
	for _, up in tool.upgrades do
		for id in up.requirements do
			p.counters[id] = 1e12
		end
	end
end
for i = 1, 20 do
	p.inventory[i] = { id = "pickaxe", count = 1, level = 1 }
end
local parent = node("Frame")
local window, content
local _, refresh = Upgrade.build(parent, p, "en", function() end, function(host, _, size)
	window = frame(host, size, rb.UDim2.new())
	content = frame(window, rb.UDim2.fromOffset(680, 430), rb.UDim2.new())
	return window, content
end)
local function find(root, name)
	for _, child in root:GetChildren() do
		if child.Name == name then
			return child
		end
		local nested = find(child, name)
		if nested then
			return nested
		end
	end
end
local buy = find(window, "TutorialUpgrade")
local row = find(window, "UpgradeItems")
local checks = {}
local function check(name, yes)
	assert(yes, name)
	table.insert(checks, name)
end
check(
	"upgrade button remains visible and enabled",
	buy.Visible and buy.Interactable and buy.Text == "upgrade_button"
)
row.CanvasPosition = rb.Vector2.new(320, 0)
local item = row.children[12]
local select
for _, child in item.children do
	if child.ClassName == "TextButton" then
		select = child
	end
end
select.Activated:Fire()
local preferences = {}
f.modules.Remotes.event("SetSetting").FireServer = function(_, key, value)
	preferences[key] = value
end
local pin = find(window, "PinUpgradeRequirements")
pin.Activated:Fire()
check(
	"pin stores selected equipment tier and enables card",
	preferences.trackedUpgrade == "pickaxe:1" and preferences.hideRequirements == false
)
local event = f.modules.Remotes.event("UpgradeItem")
local target
event.FireServer = function(_, v)
	target = v
end
buy.Activated:Fire()
check("selected scrolled item is submitted", target == 12)
p.inventory[12].level = 2
refresh(p)
pin.Activated:Fire()
check(
	"pin follows next real upgrade after successful purchase",
	preferences.trackedUpgrade == "pickaxe:2"
)
check(
	"upgrade result immediately shows next upgrade",
	buy.Text == "upgrade_button" and buy.Interactable
)
buy.Activated:Fire()
check("next upgrade keeps same selected item", target == 12)
check("profile refresh preserves horizontal scroll", row.CanvasPosition.X == 320)
check("all owned item buttons fit scrolling canvas", row.CanvasSize.X.Offset >= 20 * 52 - 4)
p.coins = 0
refresh(p)
check("insufficient funds keeps visible disabled button", buy.Visible and not buy.Interactable)
p.coins = 1e12
p.inventory[12] = nil
refresh(p)
buy.Activated:Fire()
check("removed selected item falls back to held tool", target == 1)
check(
	"buy button stays within card bounds",
	buy.Position.Y.Scale == 1 and buy.Position.Y.Offset + buy.Size.Y.Offset <= 0
)
print(
	serde.encode(
		"json",
		{ passed = #checks, checks = checks, realGui = false, realProfiles = false },
		true
	)
)
