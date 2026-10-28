--!strict
-- Creative test window [владелец 21.10]: the mode switch, money / level / food buttons and tabs with every item
-- [владелец 28.10: «добавить все блоки… сделать понятным», every book at every level]: blocks, tools and armor at
-- every level, ancient books I–III, items by kind, the server log. A tap asks the server for the item (Creative
-- "give"); CreativeService checks the player is allowed. A held finger shows the item info instead.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockColors = require(Shared.BlockColors)
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local CreativeWindow = {}
local LOG_LINES = 30
local logLines: { { text: string, error: boolean, at: string } } = {} -- server warnings, newest last
local logChanged = Instance.new("BindableEvent")

local function addLog(text: string, isError: boolean)
	table.insert(logLines, { text = text, error = isError, at = os.date("%H:%M:%S") :: string })
	while #logLines > LOG_LINES do
		table.remove(logLines, 1)
	end
	logChanged:Fire()
end

-- A client-side line in the same log (e.g. "the Open button was pressed"), for allowed players only.
function CreativeWindow.LocalLog(text: string)
	if Players.LocalPlayer:GetAttribute("CreativeAllowed") then
		addLog("[клиент] " .. text, false)
	end
end

-- Collects the server's warnings/errors (CreativeService relays them to allowed players only).
function CreativeWindow.Listen()
	Remotes.event("ServerLog").OnClientEvent:Connect(function(message: string, isError: boolean)
		addLog(message, isError)
	end)
end

-- the open tab is kept between openings
local currentTab = "blocks"
local TABS = { "blocks", "tools", "armor", "books", "items", "log" }
local TAB_KEYS: { [string]: string } = {
	blocks = "creative_blocks",
	tools = "creative_tools",
	armor = "creative_armor",
	books = "creative_books",
	items = "creative_items",
	log = "creative_log",
}
local TOOLS = { "pickaxe", "shovel", "axe", "shears", "sword", "bow" }
local ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local BOOK_ITEMS = { "ancient_powder", "dispeller", "oblivion_scroll" } -- shown on the books tab
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }
local HOLD = 0.35 -- a finger held this long shows the item info instead of giving it (like the inventory)
local NAMED = Vector2.new(74, 82) -- a cell with the name under it

function CreativeWindow.build(
	parent: Instance,
	_profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local player = Players.LocalPlayer
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local remote = Remotes.event("Creative")
	local win, content = createWindow(parent, t("creative"), UDim2.fromOffset(660, 460), function()
		ItemTooltip.hide()
		onClose()
	end)
	Ui.titleColor(win, Ui.colors.header)

	-- top bar: mode switch and quick actions
	local toggle = Ui.button(
		content,
		"",
		UDim2.fromOffset(150, 30),
		UDim2.fromOffset(4, 4),
		Ui.colors.buttonGrey
	)
	toggle.TextSize = 14
	toggle.Activated:Connect(function()
		remote:FireServer("toggle")
	end)
	local x = 160
	for _, action in ipairs({
		{ op = "coins", key = "creative_coins", w = 80 },
		{ op = "level", key = "creative_level", w = 100 },
		{ op = "refill", key = "creative_refill", w = 140 },
		{ op = "clear", key = "creative_clear", w = 150 },
	}) do
		local b = Ui.button(
			content,
			t(action.key),
			UDim2.fromOffset(action.w, 30),
			UDim2.fromOffset(x, 4),
			if action.op == "clear" then Ui.colors.close else Ui.colors.buttonBlue
		)
		b.TextSize = 13
		b.Activated:Connect(function()
			remote:FireServer(action.op)
		end)
		x += action.w + 6
	end

	-- tabs
	local tabBar = Instance.new("Frame")
	tabBar.BackgroundTransparency = 1
	tabBar.Position = UDim2.fromOffset(4, 40)
	tabBar.Size = UDim2.new(1, -8, 0, 30)
	tabBar.Parent = content
	local tabLayout = Instance.new("UIListLayout")
	tabLayout.FillDirection = Enum.FillDirection.Horizontal
	tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
	tabLayout.Padding = UDim.new(0, 4)
	tabLayout.Parent = tabBar
	local hint = Ui.label(
		content,
		t("creative_hint"),
		UDim2.new(1, -8, 0, 16),
		UDim2.fromOffset(4, 72),
		11,
		Ui.colors.muted
	)
	hint.TextTruncate = Enum.TextTruncate.AtEnd

	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local builders: { [string]: (ScrollingFrame) -> () } = {}
	local seenLog = #logLines

	local function page(): ScrollingFrame
		local list = Instance.new("ScrollingFrame")
		list.Position = UDim2.fromOffset(4, 92)
		list.Size = UDim2.new(1, -8, 1, -96)
		list.BackgroundTransparency = 1
		list.BorderSizePixel = 0
		list.ScrollBarThickness = 8
		list.AutomaticCanvasSize = Enum.AutomaticSize.Y
		list.CanvasSize = UDim2.new()
		list.Visible = false
		list.Parent = content
		local layout = Instance.new("UIListLayout")
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Padding = UDim.new(0, 6)
		layout.Parent = list
		return list
	end
	local function grid(parent: Instance, cellSize: Vector2, order: number): Frame
		local g = Instance.new("Frame")
		g.BackgroundTransparency = 1
		g.Size = UDim2.new(1, -12, 0, 0)
		g.AutomaticSize = Enum.AutomaticSize.Y
		g.LayoutOrder = order
		g.Parent = parent
		local layout = Instance.new("UIGridLayout")
		layout.CellSize = UDim2.fromOffset(cellSize.X, cellSize.Y)
		layout.CellPadding = UDim2.fromOffset(4, 4)
		layout.SortOrder = Enum.SortOrder.LayoutOrder
		layout.Parent = g
		return g
	end
	local function header(parent: Instance, text: string, order: number)
		local label =
			Ui.label(parent, text, UDim2.new(1, -12, 0, 20), UDim2.new(), 15, Ui.colors.header)
		label.LayoutOrder = order
	end

	-- One item cell: a tap gives the item, a mouse hover or a held finger shows its info.
	local function slot(
		parent: Instance,
		size: number,
		stack: Types.ItemStack,
		give: { any },
		caption: string?
	): Frame
		local frame, _, count, image = Ui.invSlot(parent, size)
		count.Text = caption or ""
		local icon = Config.iconFor(stack.id, stack.level)
		local tint = Color3.new(1, 1, 1)
		if not icon then
			icon, tint = BlockColors.icon(stack.id)
		end
		image.Image = icon or ""
		image.ImageColor3 = tint
		image.Visible = true -- slots start empty and hidden
		if not icon then
			image.BackgroundColor3 = BlockColors.of(stack.id)
			image.BackgroundTransparency = 0
		end
		local glint = image:FindFirstChild("Glint")
		if glint and glint:IsA("ImageLabel") and icon then
			glint.Image, glint.Visible = icon, Config.isEnchanted(stack.id, stack.level)
		end
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = frame.ZIndex + 5
		button.Parent = frame
		local held, heldInfo = 0, false
		button.MouseEnter:Connect(function()
			if UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch then
				ItemTooltip.show(stack, frame)
			end
		end)
		button.MouseLeave:Connect(function()
			if not heldInfo then
				ItemTooltip.hide()
			end
		end)
		button.InputBegan:Connect(function(input)
			if input.UserInputType ~= Enum.UserInputType.Touch then
				return
			end
			held += 1
			local mine = held
			heldInfo = false
			task.delay(HOLD, function()
				if held == mine then
					heldInfo = true
					ItemTooltip.show(stack, frame)
				end
			end)
		end)
		button.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.Touch then
				held += 1
			end
		end)
		button.Activated:Connect(function()
			if heldInfo then
				heldInfo = false -- the finger was held for the info: no item
				return
			end
			ItemTooltip.hide()
			remote:FireServer("give", table.unpack(give))
			local s = frame:FindFirstChildOfClass("UIStroke")
			if s then
				s.Color = Ui.colors.green
				task.delay(0.25, function()
					s.Color = Ui.colors.border
				end)
			end
		end)
		return frame
	end
	-- a cell with the item's name under it (blocks and items)
	local function named(parent: Instance, id: string, order: number)
		local box = Instance.new("Frame")
		box.BackgroundTransparency = 1
		box.LayoutOrder = order
		box.Parent = parent
		local frame = slot(box, 52, { id = id, count = 1 } :: any, { id })
		frame.AnchorPoint = Vector2.new(0.5, 0)
		frame.Position = UDim2.fromScale(0.5, 0)
		local name = Ui.label(
			box,
			Strings.itemName(id, nil, locale),
			UDim2.new(1, 0, 0, 26),
			UDim2.fromOffset(0, 54),
			10,
			Ui.colors.text
		)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextYAlignment = Enum.TextYAlignment.Top
		name.TextWrapped = true
	end
	local function byName(ids: { string }): { string }
		local names: { [string]: string } = {}
		for _, id in ipairs(ids) do
			names[id] = Strings.itemName(id, nil, locale)
		end
		table.sort(ids, function(a, b)
			return names[a] < names[b]
		end)
		return ids
	end

	builders.blocks = function(list)
		local ids = {}
		for id in pairs(Config.blocks) do
			table.insert(ids, id)
		end
		local g = grid(list, NAMED, 1)
		for i, id in ipairs(byName(ids)) do
			named(g, id, i)
		end
	end
	-- every level of each tool / armor piece under its name: «Кирка» 1 2 3 … 16
	local function levelRows(list: ScrollingFrame, ids: { string })
		for i, id in ipairs(ids) do
			local tool = Config.tools[id]
			if tool then
				header(list, Strings.itemName(id, nil, locale), i * 2)
				local g = grid(list, Vector2.new(46, 46), i * 2 + 1)
				for level = 1, #tool.upgrades + 1 do
					local stack: any = { id = id, count = 1, level = level }
					slot(g, 46, stack, { id, level }, tostring(level))
				end
			end
		end
	end
	builders.tools = function(list)
		levelRows(list, TOOLS)
	end
	builders.armor = function(list)
		levelRows(list, ARMOR)
	end
	builders.books = function(list)
		header(list, t("creative_book_items"), 1)
		local extras = grid(list, NAMED, 2)
		for i, id in ipairs(BOOK_ITEMS) do
			named(extras, id, i)
		end
		header(list, t("creative_books_all"), 3)
		local effects = {}
		for effect in pairs(Config.books.effects) do
			if Config.books.catalog[effect] then
				table.insert(effects, effect)
			end
		end
		local names: { [string]: string } = {}
		for _, effect in ipairs(effects) do
			local key = "book_" .. effect
			names[effect] = if Strings.has(key, locale) then t(key) else effect
		end
		table.sort(effects, function(a, b)
			return names[a] < names[b]
		end)
		-- one card per book: its name in the rarity colour and a cell per level (I, II, III)
		local cards = grid(list, Vector2.new(152, 74), 4)
		for i, effect in ipairs(effects) do
			local card = Ui.card(cards, UDim2.new(), UDim2.new())
			card.LayoutOrder = i
			local rarity = Config.books.catalog[effect].rarity or "common"
			local title = Ui.label(
				card,
				names[effect],
				UDim2.new(1, -8, 0, 18),
				UDim2.fromOffset(6, 2),
				12,
				ItemInfo.RARITY_COLORS[rarity] or Ui.colors.text
			)
			title.TextTruncate = Enum.TextTruncate.AtEnd
			for level = 1, #Config.books.effects[effect] do
				local stack: any = {
					id = "ancient_book",
					count = 1,
					level = level,
					books = { { id = effect, level = level } },
					rarity = rarity,
					applyChance = 100,
				}
				local frame = slot(card, 44, stack, { "ancient_book", effect, level }, ROMAN[level])
				frame.Position = UDim2.fromOffset(6 + (level - 1) * 48, 24)
			end
		end
	end
	builders.items = function(list)
		local sections: { { key: string, ids: { string } } } = {
			{ key = "creative_food", ids = {} },
			{ key = "creative_keys", ids = {} },
			{ key = "creative_boosters", ids = {} },
			{ key = "creative_other", ids = {} },
		}
		for _, id in ipairs(ItemInfo.knownIds()) do
			local plainBooster = id:match("^booster_(%a+)$")
			if
				Config.tools[id]
				or Config.block(id)
				or id == "ancient_book"
				or id == "money_bag" -- money comes from the +1000 $ button
				or (plainBooster and Boosters.isKind(plainBooster)) -- a picture; the items are per scope
				or table.find(BOOK_ITEMS, id)
			then
				continue
			end
			local food = Config.rules.survival.food[id]
			local index = if typeof(food) == "number"
				then 1
				elseif id:match("_key$") or id:match("_pass$") then 2
				else 4
			table.insert(sections[index].ids, id)
		end
		for _, kind in ipairs(Boosters.kinds) do
			for _, scope in ipairs(Boosters.scopes) do
				table.insert(sections[3].ids, Boosters.itemId(kind, scope))
			end
		end
		for i, section in ipairs(sections) do
			header(list, t(section.key), i * 2)
			local g = grid(list, NAMED, i * 2 + 1)
			-- boosters keep the kind × scope order, the rest go by name
			for n, id in ipairs(if i == 3 then section.ids else byName(section.ids)) do
				named(g, id, n)
			end
		end
	end
	-- the server's warnings yellow, errors red, newest first; the tab counts the unread lines
	local logLabel: TextLabel? = nil
	local function escape(text: string): string
		return (text:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
	end
	local function drawLog()
		if currentTab == "log" then
			seenLog = #logLines
		end
		local tab = tabButtons.log
		if tab then
			local fresh = #logLines - seenLog
			tab.Text = t("creative_log") .. (if fresh > 0 then " (" .. fresh .. ")" else "")
		end
		if not logLabel then
			return
		end
		local lines = {}
		for i = #logLines, 1, -1 do
			local line = logLines[i]
			table.insert(
				lines,
				string.format(
					'<font color="%s">%s %s</font>',
					Ui.hex(if line.error then Ui.colors.red else Ui.colors.yellow),
					line.at,
					escape(line.text)
				)
			)
		end
		logLabel.Text = if #lines > 0
			then table.concat(lines, string.char(10))
			else t("creative_log_empty")
	end
	builders.log = function(list)
		local label = Ui.label(list, "", UDim2.new(1, -12, 0, 0), UDim2.new(), 12, Ui.colors.text)
		label.AutomaticSize = Enum.AutomaticSize.Y
		label.TextWrapped = true
		label.RichText = true
		label.TextYAlignment = Enum.TextYAlignment.Top
		logLabel = label
	end

	local function openTab(tab: string)
		currentTab = tab
		ItemTooltip.hide()
		if not pages[tab] then
			pages[tab] = page()
			builders[tab](pages[tab]) -- built on first open: the tabs together hold ~400 cells
		end
		for id, list in pairs(pages) do
			list.Visible = id == tab
		end
		for id, button in pairs(tabButtons) do
			button.BackgroundColor3 = if id == tab
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		drawLog()
	end
	for i, tab in ipairs(TABS) do
		local b = Ui.button(
			tabBar,
			t(TAB_KEYS[tab]),
			UDim2.new(1 / #TABS, -4, 1, 0),
			UDim2.new(),
			Ui.colors.buttonGrey
		)
		b.LayoutOrder = i
		b.TextSize = 14
		b.Activated:Connect(function()
			openTab(tab)
		end)
		tabButtons[tab] = b
	end
	openTab(currentTab)
	local logWatch = logChanged.Event:Connect(drawLog)

	local function refresh(_: Types.Profile?)
		local on = player:GetAttribute("Creative") == true
		toggle.Text = t(if on then "creative_on" else "creative_off")
		toggle.BackgroundColor3 = if on then Ui.colors.buttonGreen else Ui.colors.buttonGrey
	end
	local watch = player:GetAttributeChangedSignal("Creative"):Connect(refresh)
	win.Destroying:Connect(function()
		watch:Disconnect()
		logWatch:Disconnect()
		ItemTooltip.hide()
	end)
	refresh(nil)
	return win, refresh
end

return CreativeWindow
