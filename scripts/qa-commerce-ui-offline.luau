--!nocheck
-- Actual disclosure/policy/book handlers. Mock GUI/services only; no Studio, purchase or profile writes.
local fs, rb, serde = require("@lune/fs"), require("@lune/roblox"), require("@lune/serde")
local checks = {}
local function check(name, ok)
	assert(ok, name)
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
	local p = {
		ClassName = kind,
		ZIndex = 1,
		children = {},
		attributes = {},
		changed = {},
		Visible = true,
		Active = true,
		Size = rb.UDim2.new(),
		Position = rb.UDim2.new(),
		AnchorPoint = rb.Vector2.zero,
		CanvasPosition = rb.Vector2.zero,
		Activated = signal(),
		Destroying = signal(),
		InputBegan = signal(),
		MouseEnter = signal(),
		MouseLeave = signal(),
	}
	local n = {}
	function p:GetChildren()
		local r = {}
		for _, c in p.children do
			if c.Parent == n then
				table.insert(r, c)
			end
		end
		return r
	end
	function p:GetDescendants()
		local r = {}
		for _, c in self:GetChildren() do
			table.insert(r, c)
			for _, d in c:GetDescendants() do
				table.insert(r, d)
			end
		end
		return r
	end
	function p:FindFirstChild(name, recursive)
		for _, c in (if recursive then self:GetDescendants() else self:GetChildren()) do
			if c.Name == name then
				return c
			end
		end
	end
	function p:FindFirstChildOfClass(class)
		for _, c in self:GetChildren() do
			if c.ClassName == class then
				return c
			end
		end
	end
	function p:IsA(class)
		return class == p.ClassName
			or class == "GuiObject"
				and table.find(
					{ "Frame", "TextLabel", "TextButton", "ImageLabel", "ScrollingFrame" },
					kind
				) ~= nil
	end
	function p:SetAttribute(key, value)
		p.attributes[key] = value
		if p.changed[key] then
			p.changed[key]:Fire()
		end
	end
	function p:GetAttribute(key)
		return p.attributes[key]
	end
	function p:GetAttributeChangedSignal(key)
		p.changed[key] = p.changed[key] or signal()
		return p.changed[key]
	end
	p.GetPropertyChangedSignal = p.GetAttributeChangedSignal
	function p:Destroy()
		p.Destroying:Fire()
		for _, c in self:GetChildren() do
			c:Destroy()
		end
		n.Parent = nil
		p.dead = true
	end
	return setmetatable(n, {
		__index = function(_, k)
			if k == "AbsoluteSize" then
				if p.absolute then
					return p.absolute
				end
				local area = if p.Parent then p.Parent.AbsoluteSize else rb.Vector2.new(750, 381)
				return rb.Vector2.new(
					p.Size.X.Scale * area.X + p.Size.X.Offset,
					p.Size.Y.Scale * area.Y + p.Size.Y.Offset
				)
			end
			return p[k]
		end,
		__newindex = function(_, k, v)
			p[k] = v
			if k == "Parent" and v then
				table.insert(v.children, n)
			end
		end,
	})
end
local Config = {}
for _, id in { "keys", "books", "boosters", "artifacts", "rules", "tools", "donate", "gangs" } do
	Config[id] = serde.decode("json", fs.readFile("src/shared/Config/" .. id .. ".json"))
end
Config.moneyScale, Config.tools = Config.rules.money.scale, Config.tools.tools
Config.iconFor = function(id)
	return id
end
local modules = { Config = Config, Types = {} }
local names = setmetatable({}, {
	__index = function(_, key)
		return key
	end,
})
local player = node("Player")
local run = { Heartbeat = signal(), RenderStepped = signal() }
local viewport = rb.Vector2.new(568, 320)
local workspace = { CurrentCamera = { ViewportSize = viewport } }
local sent = {}
modules.Remotes = {
	event = function(name)
		return {
			FireServer = function(_, ...)
				table.insert(sent, { name, ... })
			end,
		}
	end,
}
local env = setmetatable({
	game = {
		GetService = function(_, name)
			if name == "Players" then
				return { LocalPlayer = player }
			end
			if name == "RunService" then
				return run
			end
			if name == "GuiService" then
				return {
					GetGuiInset = function()
						return rb.Vector2.new(0, 58), rb.Vector2.zero
					end,
				}
			end
			if name == "ProximityPromptService" then
				return { PromptTriggered = signal() }
			end
			if name == "UserInputService" then
				return {
					GetMouseLocation = function()
						return rb.Vector2.zero
					end,
				}
			end
			return {
				Shared = names,
				WaitForChild = function()
					return names
				end,
			}
		end,
	},
	script = { Parent = names },
	require = function(id)
		return assert(modules[id], id)
	end,
	Instance = { new = node },
	workspace = workspace,
	Vector2 = rb.Vector2,
	UDim2 = rb.UDim2,
	UDim = rb.UDim,
	Color3 = rb.Color3,
	Enum = rb.Enum,
}, { __index = getfenv() })
local function load(path)
	local fn = assert(loadstring(fs.readFile(path), "@" .. path))
	setfenv(fn, env)
	return fn()
end
local commerce = load("src/shared/Strings/Commerce.luau")
modules.Strings = {
	t = function(key, locale, ...)
		local row = commerce[key]
		if not row then
			return key
		end
		return if select("#", ...) > 0 then string.format(row[locale], ...) else row[locale]
	end,
	itemName = function(id)
		return id
	end,
	itemFullName = function(id, level)
		return id .. (if level then " " .. level else "")
	end,
	has = function()
		return false
	end,
}
modules.ItemInfo = {
	bookName = function(id, level)
		return id .. " " .. level
	end,
	bookDescription = function()
		return "description"
	end,
	RARITY_COLORS = {},
}
modules.ItemTooltip = { hide = function() end, show = function() end }
modules.SlotView = {
	render = function(name, count, icon, stack)
		name.Text = stack.id
		count.Text = tostring(stack.count)
		icon.Image = stack.id
	end,
	rarityBar = function() end,
}
local Ui =
	{ colors = setmetatable({}, {
		__index = function()
			return rb.Color3.new(1, 1, 1)
		end,
	}) }
local function frame(parent, size, pos)
	local n = node("Frame")
	n.Parent, n.Size, n.Position = parent, size, pos
	return n
end
Ui.panel, Ui.card = frame, frame
Ui.label = function(parent, text, size, pos, font, color)
	local n = frame(parent, size, pos)
	n.ClassName, n.Text, n.TextSize, n.TextColor3 = "TextLabel", text, font, color
	return n
end
Ui.button = function(...)
	local n = Ui.label(...)
	n.ClassName = "TextButton"
	return n
end
Ui.invSlot = function(parent, size)
	local n = frame(parent, rb.UDim2.fromOffset(size, size), rb.UDim2.new())
	return n,
		Ui.label(n, "", rb.UDim2.new(), rb.UDim2.new()),
		Ui.label(n, "", rb.UDim2.new(), rb.UDim2.new()),
		node("ImageLabel")
end
modules.Ui = Ui
for _, id in
	{
		"Numbers",
		"AncientRoll",
		"CaseRoll",
		"Nicknames",
		"RewardOdds",
		"Books",
		"CasePreview",
		"CommercePolicy",
	}
do
	modules[id] = load("src/shared/" .. id .. ".luau")
end
modules.CommerceUi = load("src/client/CommerceUi.luau")
local Preview, Book = load("src/client/CasePreviewWindow.luau"), load("src/client/BookWindow.luau")
local gui = node("ScreenGui")
gui.absolute = viewport
local function create(parent, title, size, close)
	local win = frame(parent, size, rb.UDim2.new())
	win.close = close
	local content = frame(win, rb.UDim2.new(1, -12, 1, -46), rb.UDim2.fromOffset(6, 40))
	return win, content
end
local function allText(win)
	local t = {}
	for _, n in win:GetDescendants() do
		if n.Text then
			table.insert(t, n.Text)
		end
	end
	return table.concat(t, "\n")
end
local function descendants(win, prefix)
	local out = {}
	for _, n in win:GetDescendants() do
		if n.Name and n.Name:sub(1, #prefix) == prefix then
			table.insert(out, n)
		end
	end
	return out
end
player:SetAttribute("PolicyState", "pending")
check(
	"pending random and trade deny",
	modules.CommerceUi.reason("random") == "policy_loading"
		and modules.CommerceUi.reason("trade") == "policy_loading"
)
check(
	"deterministic goods remain purchasable while pending",
	modules.CommerceUi.reason("purchase", "soap") == nil
)
player:SetAttribute("PolicyState", "ready")
player:SetAttribute("PaidRandomAllowed", true)
player:SetAttribute("PaidTradeAllowed", true)
local profile = { nicknames = {}, artifacts = { common = { fragments = {}, duplicates = 0 } } }
for _, size in { rb.Vector2.new(360, 640), rb.Vector2.new(568, 320), rb.Vector2.new(705, 338) } do
	workspace.CurrentCamera.ViewportSize, gui.absolute = size, size
	for _, locale in { "ru", "en", "es", "fr" } do
		local win = Preview.build(gui, locale, function() end, create, "ordinaryCase", function()
			return profile
		end)
		check(
			"window within safe viewport " .. locale,
			win.Size.X.Offset <= size.X - 24 and win.Size.Y.Offset <= size.Y - 58 - 24
		)
		local scroll = win:FindFirstChild("RewardOdds", true)
		check(
			"long odds are scrollable",
			scroll.CanvasSize.Y.Offset > scroll.AbsoluteSize.Y and scroll.AbsoluteSize.Y > 80
		)
		local group = descendants(win, "OddsGroup_")[1]
		check("disclosure group target at least44", group.Size.Y.Offset >= 44)
		group.Activated:Fire()
		check(
			"real expand handler renders descendants",
			#descendants(win, "OddsOutcome_") + #descendants(win, "OddsGroup_") > 10
		)
		local range = descendants(win, "OddsRange_")[1]
		check(
			"exact tiny probability preserved",
			range:GetAttribute("ProbabilityPerValue") > 0 and not range.Text:find(" 0%%")
		)
		check("money step retained", allText(win):find("0.0001", 1, true) ~= nil)
		win:Destroy()
	end
end
local win = Preview.build(gui, "en", function() end, create, "ancientCase", function()
	return profile
end)
local normal = modules.RewardOdds.case("ancientCase", profile, "ancient_key")
check(
	"normal ancient includes exact booklevel nodes",
	#descendants(win, "OddsGroup_main_") == #normal.outcomes
)
win:FindFirstChild("OddsKey_improved_ancient_key", true).Activated:Fire()
local improved = modules.RewardOdds.case("ancientCase", profile, "improved_ancient_key")
check(
	"improved tab actualclick switchesdistribution",
	#descendants(win, "OddsGroup_main_") == #improved.outcomes
		and #normal.outcomes > #improved.outcomes
)
win:FindFirstChild("OddsGroup_main_1", true).Activated:Fire()
check("improved chancebands accessible", #descendants(win, "OddsRange_") == 2)
win:Destroy()
win = Preview.build(gui, "en", function() end, create, "nicknameCase", function()
	return profile
end)
local count = #descendants(win, "OddsOutcome_main_")
table.insert(profile.nicknames, modules.Nicknames.list[1])
run.Heartbeat:Fire(0.3)
check(
	"in-place owned nickname patch updates remaining probabilities",
	#descendants(win, "OddsOutcome_main_") == count - 1
)
local total = 0
for _, n in descendants(win, "OddsOutcome_main_") do
	total += n:GetAttribute("Probability")
end
check("remaining nicknames stillsum1", math.abs(total - 1) < 1e-10)
player:SetAttribute("PaidRandomAllowed", false)
check(
	"restriction explanation renders immediately",
	allText(win):find(commerce.policy_random_unavailable.en, 1, true) ~= nil
)
win:Destroy()
player:SetAttribute("PaidRandomAllowed", true)
local owner = frame(gui, rb.UDim2.fromOffset(500, 300), rb.UDim2.new())
local purchases = 0
local modal = Preview.purchase(owner, gui, "en", create, "ancient_key", function()
	return profile
end, function()
	purchases += 1
end, "Buy one key")
check(
	"details precede spend",
	not owner.Visible
		and purchases == 0
		and modal:FindFirstChild("OddsContinue", true).Size.Y.Offset == 44
)
player:SetAttribute("PaidRandomAllowed", false)
modal:FindFirstChild("OddsContinue", true).Activated:Fire()
check("policychange beforeconfirmation blocks spend", purchases == 0 and modal.Parent ~= nil)
player:SetAttribute("PaidRandomAllowed", true)
modal:FindFirstChild("OddsContinue", true).Activated:Fire()
check(
	"explicit confirmation spends once andreturnsowner",
	purchases == 1 and owner.Visible and modal.Parent == nil
)
local effect = "hammer"
local card = Config.books.catalog[effect]
local target = card.items[1]
profile.inventory = {
	[1] = {
		id = "ancient_book",
		count = 1,
		books = { { id = effect, level = 1 } },
		applyChance = 35,
	},
	[2] = { id = target, count = 1, level = 1 },
}
profile.armor = {}
Book.sourceSlot = 1
win = Book.build(gui, profile, "en", function() end, create)
check(
	"book successandfailure both disclosed",
	win:FindFirstChild("BookOutcome", true).Text == "Success 35% · Failure 65%"
)
local picks = {}
for _, n in win:GetDescendants() do
	if n.ClassName == "TextButton" and n.Text == "" then
		table.insert(picks, n)
	end
end
picks[1].Activated:Fire()
player:SetAttribute("PaidRandomAllowed", false)
win:FindFirstChild("BookApply", true).Activated:Fire()
check(
	"restrictedrandom book cannotspend",
	#sent == 0 and not win:FindFirstChild("BookApply", true).Active
)
win:Destroy()
profile.inventory[1].applyChance = 100
win = Book.build(gui, profile, "en", function() end, create)
for _, n in win:GetDescendants() do
	if n.ClassName == "TextButton" and n.Text == "" then
		n.Activated:Fire()
		break
	end
end
win:FindFirstChild("BookApply", true).Activated:Fire()
check("guaranteedbook remainsusable whenrestricted", #sent == 1 and sent[1][1] == "BookUse")
win:Destroy()
profile.inventory = {
	[1] = { id = "ancient_powder", count = 1 },
	[2] = {
		id = "ancient_book",
		count = 1,
		books = { { id = effect, level = 1 } },
		applyChance = 95,
	},
}
win = Book.build(gui, profile, "en", function() end, create)
for _, n in win:GetDescendants() do
	if n.ClassName == "TextButton" and n.Text == "" then
		n.Activated:Fire()
		break
	end
end
check(
	"powder discloses cap and failure before use",
	win:FindFirstChild("BookPreview", true).Text == "Success 95% → 100%; failure 5% → 0%."
)
win:FindFirstChild("BookApply", true).Activated:Fire()
check("deterministicpowder remainsusable whenrestricted", #sent == 2)
win:Destroy()

-- Exercise the case window's real buttons, including disclosure without a debit.
modules.CasePreviewWindow = Preview
modules.Donate, modules.Vault = {}, {}
modules.CreativeWindow = { LocalLog = function() end }
modules.DragDrop = {
	new = function()
		return { Bind = function() end, Clear = function() end }
	end,
}
modules.StorageTransferUi = load("src/client/StorageTransferUi.luau")
local renderSlot = modules.SlotView.render
modules.SlotView.render = function(name, count, icon, stack)
	if stack then
		renderSlot(name, count, icon, stack)
	end
end
player.CharacterRemoving = signal()
local Chest = load("src/client/ChestWindow.luau")
profile.inventory = { [1] = { id = "improved_ancient_key", count = 1 } }
profile.caseContents = {}
win = Chest.build(gui, "ancientCase", function()
	return profile
end, "en", function() end, create)
local open = win:FindFirstChild("CaseOpenReward", true)
open.Activated:Fire()
check("restricted chest Open is disabled and sends nothing", not open.Active and #sent == 2)
win:FindFirstChild("CaseRewardDetails", true).Activated:Fire()
local details = gui:FindFirstChild("Window_CasePreview")
check(
	"chest Details shows odds without spending",
	not win.Visible and #sent == 2 and details ~= nil
)
details.close()
player:SetAttribute("PaidRandomAllowed", true)
open.Activated:Fire()
check(
	"restored permission uses the selected key once",
	open.Active and #sent == 3 and sent[3][1] == "CaseOpen" and sent[3][3] == "improved_ancient_key"
)
win:Destroy()
profile.inventory = { [1] = { id = "ordinary_key", count = 1 } }
local contents = {}
for slot = 1, 24 do
	contents[slot] = { id = "apple", count = 1 }
end
profile.caseContents.ordinaryCase = contents
local refresh
win, refresh = Chest.build(gui, "ordinaryCase", function()
	return profile
end, "en", function() end, create)
open = win:FindFirstChild("CaseOpenReward", true)
open.Activated:Fire()
check(
	"three free slots keeps Open disabled and Details visible",
	not open.Active and #sent == 3 and win:FindFirstChild("CaseRewardDetails", true).Visible
)
contents[24] = nil
refresh()
check("clearing the fourth slot re-enables Open", open.Active)
win:Destroy()
print("PASS commerce UI", #checks, "actual-source checks (mock GUI/services, no physical input)")
