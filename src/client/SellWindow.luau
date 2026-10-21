--!strict
-- "Скупщик блоков" — the block buyer window of the original (17 owner screenshots, BLOCK-PRICES.md):
-- title strip "Скупщик блоков" + "Цены с вашим множителем ×1.04" (green multiplier) + red ✕;
-- a scrolling list grouped by location (orange name; "С 3 уровня" / 🔒 "Откроется с N уровня" on the
-- right); every block is a row: icon slot, coloured name, "В инвентаре нет" / "В инвентаре: N",
-- green price with $ and "за 1 блок"; a full-width green "Продать всё" button at the bottom.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local SellWindow = {}

local ROW = 50
local GROUP = 26

local function nameColor(blockId: string): Color3
	local colors = Config.rules.ui and Config.rules.ui.blockNameColors
	local key = if colors then colors[blockId] else nil
	return (if typeof(key) == "string" then (Ui.colors :: any)[key] else nil) or Ui.colors.text
end

-- same as ProfessionService.moneyMultiplier: dig reward boost × «Бустер денег» points
local function moneyMultiplier(profile: Types.Profile?): number
	return (Config.money.digRewardMultiplier or 1)
		* (
			if profile
				then 1 + profile.professions.upgrades.money * Config.professions.upgrades.money
				else 1
		)
end

function SellWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(parent, t("sell_title"), UDim2.fromOffset(620, 600), onClose)
	Ui.titleColor(win, Ui.colors.header)
	local mult = Ui.rich(win, "", UDim2.fromOffset(330, 28), UDim2.new(1, -374, 0, 6), 14)
	mult.TextXAlignment = Enum.TextXAlignment.Right
	mult.ZIndex = 3
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, 0, 1, -52)
	list.BackgroundColor3 = Ui.colors.panel
	list.BackgroundTransparency = 0.4
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Ui.colors.border
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = content
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ui.colors.border
	stroke.Parent = list
	local sellAll = Ui.button(
		content,
		"",
		UDim2.new(1, 0, 0, 40),
		UDim2.new(0, 0, 1, -42),
		Ui.colors.buttonGreen
	)
	sellAll.TextSize = 18
	sellAll.Activated:Connect(function()
		Remotes.event("Sell"):FireServer()
		onClose() -- [владелец 21.10] the window closes after selling everything
	end)

	-- rows: every location in level order; its sell list from the buyer menu [меню] (fallback: mine shares)
	type Row = { id: string, have: TextLabel, price: TextLabel }
	type Group = { level: number, label: TextLabel }
	local rows: { Row } = {}
	local groups: { Group } = {}
	local y = 6
	local locations = table.clone(Config.locationsFile.locations) :: { Config.Location }
	table.sort(locations, function(a, b)
		if a.unlockLevel ~= b.unlockLevel then
			return a.unlockLevel < b.unlockLevel
		end
		return a.id < b.id
	end)
	for _, loc in ipairs(locations) do
		local ids: { string } = {}
		if typeof(loc.sellList) == "table" and #loc.sellList > 0 then
			ids = loc.sellList
		elseif loc.mine and loc.mine.shares then
			for blockId in pairs(loc.mine.shares) do
				if Config.block(blockId) then
					table.insert(ids, blockId)
				end
			end
			table.sort(ids)
		end
		if #ids == 0 then
			continue
		end
		Ui.label(
			list,
			Strings.locationName(loc.name, locale),
			UDim2.new(1, -200, 0, GROUP),
			UDim2.fromOffset(12, y),
			15,
			Ui.colors.header
		)
		local levelLabel = Ui.label(
			list,
			"",
			UDim2.fromOffset(240, GROUP),
			UDim2.new(1, -258, 0, y),
			13,
			Ui.colors.muted
		)
		levelLabel.TextXAlignment = Enum.TextXAlignment.Right
		table.insert(groups, { level = loc.unlockLevel, label = levelLabel })
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, -24, 0, 1)
		line.Position = UDim2.fromOffset(12, y + GROUP - 2)
		line.BackgroundColor3 = Ui.colors.border
		line.BorderSizePixel = 0
		line.Parent = list
		y += GROUP + 2
		local shown: { [string]: boolean } = {}
		for _, listedId in ipairs(ids) do
			local listed = Config.block(listedId)
			-- the buyer takes what actually drops (melon → melon slices) [ваниль]
			local blockId = if listed
					and listed.dropsAs
					and Config.block(listed.dropsAs)
				then listed.dropsAs
				else listedId
			local block = Config.block(blockId)
			if not block or shown[blockId] or block.sellable == false then
				continue -- stone and cobblestone both drop cobblestone: one row per sold item
			end
			shown[blockId] = true
			local row = Ui.inset(list, UDim2.new(1, -24, 0, ROW - 4), UDim2.fromOffset(12, y))
			local slot, _, _, icon = Ui.slot(row, 36)
			slot.Position = UDim2.fromOffset(6, 5)
			local image = Config.iconFor(blockId)
			icon.Image, icon.Visible = image or "", image ~= nil
			Ui.label(
				row,
				Strings.itemName(blockId, nil, locale),
				UDim2.new(0.6, 0, 0, 20),
				UDim2.fromOffset(52, 4),
				15,
				nameColor(blockId)
			)
			local have = Ui.label(
				row,
				"",
				UDim2.new(0.6, 0, 0, 18),
				UDim2.fromOffset(52, 24),
				13,
				Ui.colors.muted
			)
			local price = Ui.rich(row, "", UDim2.fromOffset(200, 20), UDim2.new(1, -210, 0, 4), 15)
			price.TextXAlignment = Enum.TextXAlignment.Right
			local per = Ui.label(
				row,
				t("per_block"),
				UDim2.fromOffset(200, 18),
				UDim2.new(1, -210, 0, 24),
				13,
				Ui.colors.muted
			)
			per.TextXAlignment = Enum.TextXAlignment.Right
			table.insert(rows, { id = blockId, have = have, price = price })
			y += ROW
		end
		y += 6
	end

	local function refresh(p: Types.Profile?)
		profile = p
		local m = moneyMultiplier(p)
		mult.Text = string.format(
			'%s <font color="%s">×%.2f</font>',
			t("prices_multiplier"),
			Ui.hex(Ui.colors.money),
			m
		)
		local totals: { [string]: number } = {}
		local sum = 0
		if p then
			for _, stack in pairs(p.inventory) do
				local b = Config.block(stack.id)
				if b and b.sellable ~= false then
					totals[stack.id] = (totals[stack.id] or 0) + stack.count
				end
			end
		end
		for _, row in ipairs(rows) do
			local block = Config.block(row.id) :: Config.Block
			local n = totals[row.id] or 0
			local unit = math.floor(block.basePrice * Config.moneyScale * m + 0.5)
			row.have.Text = if n > 0 then t("in_inventory", n) else t("in_inventory_none")
			row.have.TextColor3 = if n > 0 then Ui.colors.text else Ui.colors.muted
			row.price.Text = string.format(
				'<font color="%s">%s $</font>',
				Ui.hex(Ui.colors.money),
				Strings.money(unit)
			)
		end
		-- the same block can be listed under several locations: count every stack once
		for id, n in pairs(totals) do
			local block = Config.block(id) :: Config.Block
			sum += math.floor(block.basePrice * Config.moneyScale * m + 0.5) * n
		end
		for _, group in ipairs(groups) do
			local level = if p then p.level else 1
			group.label.Text = if group.level <= 1
				then ""
				elseif level >= group.level then t("from_level", group.level)
				else "🔒 " .. t("opens_at_level", group.level)
		end
		sellAll.Text = if sum > 0
			then string.format("%s  (%s $)", t("sell_all"), Strings.money(sum))
			else t("sell_all")
	end
	refresh(profile)
	return win, refresh
end

return SellWindow
