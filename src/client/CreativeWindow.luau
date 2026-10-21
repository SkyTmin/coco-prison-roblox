--!strict
-- Creative test window [владелец 21.10]: the mode switch, money / level / food buttons and a catalog
-- of every item (blocks, tools and armor at the chosen level, other items, ancient books). A tap
-- asks the server for the item (Creative "give"); CreativeService checks the player is allowed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockColors = require(Shared.BlockColors)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local CreativeWindow = {}
local CELL = 48
local toolLevel = 1 -- kept between openings

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
	local win, content = createWindow(parent, t("creative"), UDim2.fromOffset(640, 440), function()
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
		b.TextScaled = action.w < 120
		b.Activated:Connect(function()
			remote:FireServer(action.op)
		end)
		x += action.w + 6
	end
	-- tool level selector
	local maxTool = 1
	for _, tool in pairs(Config.tools) do
		maxTool = math.max(maxTool, #tool.upgrades + 1)
	end
	local levelLabel = Ui.label(
		content,
		"",
		UDim2.fromOffset(250, 26),
		UDim2.fromOffset(78, 40),
		14,
		Ui.colors.text
	)
	local minus = Ui.button(
		content,
		"-",
		UDim2.fromOffset(30, 26),
		UDim2.fromOffset(4, 40),
		Ui.colors.buttonGrey
	)
	local plus = Ui.button(
		content,
		"+",
		UDim2.fromOffset(30, 26),
		UDim2.fromOffset(40, 40),
		Ui.colors.buttonGrey
	)
	local hint = Ui.label(
		content,
		t("creative_hint"),
		UDim2.new(1, -340, 0, 30),
		UDim2.fromOffset(334, 38),
		11,
		Ui.colors.muted
	)
	hint.TextWrapped = true

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(4, 72)
	list.Size = UDim2.new(1, -8, 1, -76)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 8
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = content
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 4)
	layout.Parent = list

	local toolIcons: { { image: ImageLabel, id: string } } = {}
	local order = 0
	local function section(titleKey: string): Frame
		order += 1
		local header =
			Ui.label(list, t(titleKey), UDim2.new(1, -12, 0, 20), UDim2.new(), 15, Ui.colors.header)
		header.LayoutOrder = order
		order += 1
		local grid = Instance.new("Frame")
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, -12, 0, 0)
		grid.AutomaticSize = Enum.AutomaticSize.Y
		grid.LayoutOrder = order
		grid.Parent = list
		local gridLayout = Instance.new("UIGridLayout")
		gridLayout.CellSize = UDim2.fromOffset(CELL, CELL)
		gridLayout.CellPadding = UDim2.fromOffset(4, 4)
		gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
		gridLayout.Parent = grid
		return grid
	end
	local function cell(grid: Frame, id: string, level: number?, extra: any?): ImageLabel
		local frame, _, count, image = Ui.slot(grid, CELL)
		count.Text = ""
		local icon = Config.iconFor(id, level)
		image.Image = icon or ""
		image.Visible = true -- Ui.slot starts empty and hidden
		if not icon then
			image.BackgroundColor3 = BlockColors.of(id)
			image.BackgroundTransparency = 0
		end
		local button = Instance.new("TextButton")
		button.Size = UDim2.fromScale(1, 1)
		button.BackgroundTransparency = 1
		button.Text = ""
		button.ZIndex = frame.ZIndex + 5
		button.Parent = frame
		local function stack(): Types.ItemStack
			local s: any = { id = id, count = 1 }
			if Config.tools[id] then
				s.level = toolLevel
			elseif id == "ancient_book" then
				local effect = Config.books.effects[extra]
				s.level = #effect
				s.books = { { id = extra, level = #effect } }
				s.applyChance = 100
			end
			return s
		end
		button.MouseEnter:Connect(function()
			ItemTooltip.show(stack(), frame)
		end)
		button.MouseLeave:Connect(function()
			ItemTooltip.hide()
		end)
		button.Activated:Connect(function()
			ItemTooltip.show(stack(), frame) -- touch has no hover: the tap names the item too
			remote:FireServer("give", id, if id == "ancient_book" then extra else toolLevel)
		end)
		return image
	end

	-- blocks by id
	local blocks = section("creative_blocks")
	local blockIds = {}
	for id in pairs(Config.blocks) do
		table.insert(blockIds, id)
	end
	table.sort(blockIds)
	for _, id in ipairs(blockIds) do
		cell(blocks, id)
	end
	local tools = section("creative_tools")
	for _, id in ipairs({
		"pickaxe",
		"shovel",
		"axe",
		"sword",
		"helmet",
		"chestplate",
		"leggings",
		"boots",
	}) do
		if Config.tools[id] then
			table.insert(toolIcons, { image = cell(tools, id, toolLevel), id = id })
		end
	end
	local items = section("creative_items")
	for _, id in ipairs(ItemInfo.knownIds()) do
		if not Config.tools[id] and not Config.block(id) and id ~= "ancient_book" then
			cell(items, id)
		end
	end
	local books = section("creative_books")
	local effectIds = {}
	for effect in pairs(Config.books.effects) do
		if Config.books.catalog[effect] then
			table.insert(effectIds, effect)
		end
	end
	table.sort(effectIds)
	for _, effect in ipairs(effectIds) do
		cell(books, "ancient_book", nil, effect)
	end

	local function setToolLevel(level: number)
		toolLevel = math.clamp(level, 1, maxTool)
		levelLabel.Text = t("creative_tool_level", toolLevel)
		for _, entry in ipairs(toolIcons) do
			entry.image.Image = Config.iconFor(entry.id, toolLevel) or ""
		end
	end
	minus.Activated:Connect(function()
		setToolLevel(toolLevel - 1)
	end)
	plus.Activated:Connect(function()
		setToolLevel(toolLevel + 1)
	end)
	setToolLevel(toolLevel)

	local function refresh(_: Types.Profile?)
		local on = player:GetAttribute("Creative") == true
		toggle.Text = t(if on then "creative_on" else "creative_off")
		toggle.BackgroundColor3 = if on then Ui.colors.buttonGreen else Ui.colors.buttonGrey
	end
	local watch = player:GetAttributeChangedSignal("Creative"):Connect(refresh)
	win.Destroying:Connect(function()
		watch:Disconnect()
		ItemTooltip.hide()
	end)
	refresh(nil)
	return win, refresh
end

return CreativeWindow
