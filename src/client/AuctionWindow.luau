--!strict
-- «Аукцион» [Y] [вики MENUS-SOCIAL «Аукцион /ah»; владелец 27.10: «как будет работать между игроками, как товар
-- туда кидать»]. Tabs «Аукцион / Личные товары» and «Продать»:
--   Аукцион — the type filter (Все / Оружие / Броня / Инструменты / Зачарования / Прочее), price and level from–to,
--     sort by time / price / level, search, a 10 × 6 grid with pages; a lot's tooltip adds «Продавец», «Стоимость»,
--     «Истекает через»; a click asks «Купить … за …$?». The server filters and pages (AuctionQuery).
--   Личные товары — the player's lots (from the replicated profile) with «Снять с продажи», listings and purchases
--     still being confirmed, and the items that came back but did not fit — «Забрать».
--   Продать — «Выберите предмет из инвентаря» → «Продажа предмета»: count, price, what the seller gets after the
--     commission → «Выставить на продажу».
-- Every outcome is the server's (AuctionService); the window only sends intents and redraws.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Auction = require(Shared.Auction)
local BlockColors = require(Shared.BlockColors)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ItemTooltip = require(script.Parent.ItemTooltip)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
type ItemStack = Types.ItemStack
type Summary = Auction.Summary
type SlotView = { frame: Frame, icon: ImageLabel, count: TextLabel, button: TextButton }

local AuctionWindow = {}

local SLOT, GAP, COLS, ROWS = 46, 4, 10, 6
local LEFT_W = 196
local GRID_X = LEFT_W + 12
local WIN_W = GRID_X + COLS * (SLOT + GAP) + 16
local WIN_H = 500
local POLL_SECONDS = 10
local cfg = Auction.cfg

local function paint(view: SlotView, stack: ItemStack?)
	local icon = if stack then Config.iconFor(stack.id, stack.level) else nil
	local tint = Color3.new(1, 1, 1)
	if stack and not icon then
		icon, tint = BlockColors.icon(stack.id)
	end
	local tile = if stack and not icon then BlockColors.of(stack.id) else nil
	view.icon.Image, view.icon.Visible = icon or "", icon ~= nil or tile ~= nil
	view.icon.ImageColor3 = tint
	view.icon.BackgroundColor3 = tile or Color3.new()
	view.icon.BackgroundTransparency = if tile then 0 else 1
	view.count.Text = if stack and stack.count > 1 then tostring(stack.count) else ""
end

local function slotView(parent: Instance, size: number, position: UDim2): SlotView
	local frame, name, count, icon = Ui.invSlot(parent, size)
	frame.Position = position
	name.Visible = false
	local button = Instance.new("TextButton")
	button.Text = ""
	button.BackgroundTransparency = 1
	button.Size = UDim2.fromScale(1, 1)
	button.ZIndex = 5
	button.Parent = frame
	return { frame = frame, icon = icon, count = count, button = button }
end

local function textBox(parent: Instance, placeholder: string, size: UDim2, position: UDim2): TextBox
	local box = Instance.new("TextBox")
	box.Size = size
	box.Position = position
	box.BackgroundColor3 = Ui.colors.inset
	box.BorderSizePixel = 0
	box.Font = Ui.font
	box.TextSize = 14
	box.TextColor3 = Ui.colors.text
	box.PlaceholderText = placeholder
	box.PlaceholderColor3 = Ui.colors.muted
	box.Text = ""
	box.ClearTextOnFocus = false
	box.TextXAlignment = Enum.TextXAlignment.Left
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 6)
	pad.Parent = box
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 3)
	corner.Parent = box
	local stroke = Instance.new("UIStroke")
	stroke.Color = Ui.colors.border
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = box
	box.Parent = parent
	return box
end

local function number(box: TextBox): number?
	local n = tonumber((box.Text:gsub("[%s,]", "")))
	return if n and n == n and n >= 0 then n else nil
end

function AuctionWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local current: Types.Profile? = profile
	local win, content =
		createWindow(parent, T("auction_title"), UDim2.fromOffset(WIN_W, WIN_H), onClose)
	win.Name = "Window_Auction"
	local offset = 0 -- server os.time() − ours, from the last answer
	local function serverNow(): number
		return os.time() + offset
	end
	local function timeText(seconds: number): string
		local d, h, m, s = Auction.timeLeft(seconds)
		if d > 0 then
			return T("auction_time_dhm", d, h, m)
		elseif h > 0 then
			return T("auction_time_hm", h, m)
		end
		return T("auction_time_ms", m, s)
	end
	local function nameOf(stack: ItemStack): string
		local name = Strings.itemName(stack.id, stack.level, locale)
		return if stack.count > 1 then name .. " ×" .. stack.count else name
	end
	local function lotLines(lot: Summary, mine: boolean): { ItemInfo.Line }
		return {
			{ text = T("auction_seller", lot.sellerName), color = Ui.colors.gray },
			{ text = T("auction_cost", Strings.money(lot.price)), color = Ui.colors.money },
			{
				text = T("auction_expires", timeText(lot.expiresAt - serverNow())),
				color = Ui.colors.gray,
			},
			{
				text = if mine then T("auction_my_lot") else T("auction_click_buy"),
				color = if mine then Ui.colors.header else Ui.colors.yellow,
				small = true,
			},
		}
	end

	-- ── top bar: tabs, money, «Продать» ──
	local tab = "auction"
	local tabButtons: { [string]: TextButton } = {}
	local pages: { [string]: Frame } = {}
	local show: (string) -> ()
	for i, kind in ipairs({ "auction", "mine" }) do
		local button = Ui.button(
			content,
			T("auction_tab_" .. kind),
			UDim2.fromOffset(150, 28),
			UDim2.fromOffset((i - 1) * 156, 0),
			Ui.colors.buttonGrey
		)
		button.Name = "Tab_" .. kind
		button.TextSize = 15
		button.Activated:Connect(function()
			show(kind)
		end)
		tabButtons[kind] = button
	end
	local sellButton = Ui.button(
		content,
		T("auction_sell"),
		UDim2.fromOffset(120, 28),
		UDim2.new(1, -120, 0, 0),
		Ui.colors.buttonGreen
	)
	sellButton.Name = "Sell"
	sellButton.TextSize = 15
	local money = Ui.rich(content, "", UDim2.fromOffset(180, 28), UDim2.new(1, -310, 0, 0), 15)
	money.TextXAlignment = Enum.TextXAlignment.Right
	local function drawMoney()
		money.Text = string.format(
			'<font color="%s">%s$</font>',
			Ui.hex(Ui.colors.money),
			Strings.money(if current then current.coins else 0)
		)
	end
	for _, kind in ipairs({ "auction", "mine", "sell" }) do
		local page = Instance.new("Frame")
		page.Name = "Page_" .. kind
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 1, -36)
		page.Position = UDim2.fromOffset(0, 36)
		page.Visible = false
		page.Parent = content
		pages[kind] = page
	end

	-- ── Аукцион ──
	local auctionPage = pages.auction
	local category = "all"
	local sort = "time"
	local desc = true
	local page, pageCount = 1, 1
	local lots: { Summary } = {}
	local requestN = 0
	local query: () -> ()

	local function heading(parentFrame: Instance, key: string, y: number)
		Ui.label(
			parentFrame,
			T(key),
			UDim2.fromOffset(LEFT_W, 18),
			UDim2.fromOffset(0, y),
			13,
			Ui.colors.muted
		)
	end
	heading(auctionPage, "auction_type", 0)
	local categoryButtons: { [string]: TextButton } = {}
	for i, kind in ipairs(Auction.CATEGORIES) do
		local button = Ui.button(
			auctionPage,
			T("auction_cat_" .. kind),
			UDim2.fromOffset(LEFT_W, 22),
			UDim2.fromOffset(0, 18 + (i - 1) * 25),
			Ui.colors.buttonGrey
		)
		button.Name = "Cat_" .. kind
		button.TextSize = 14
		button.Activated:Connect(function()
			category = kind
			page = 1
			query()
		end)
		categoryButtons[kind] = button
	end
	local y = 18 + #Auction.CATEGORIES * 25 + 4
	heading(auctionPage, "auction_price", y)
	local half = (LEFT_W - 6) / 2
	local minPrice = textBox(
		auctionPage,
		T("auction_from"),
		UDim2.fromOffset(half, 24),
		UDim2.fromOffset(0, y + 18)
	)
	local maxPrice = textBox(
		auctionPage,
		T("auction_to"),
		UDim2.fromOffset(half, 24),
		UDim2.fromOffset(half + 6, y + 18)
	)
	y += 46
	heading(auctionPage, "auction_level", y)
	local minLevel = textBox(
		auctionPage,
		T("auction_from"),
		UDim2.fromOffset(half, 24),
		UDim2.fromOffset(0, y + 18)
	)
	local maxLevel = textBox(
		auctionPage,
		T("auction_to"),
		UDim2.fromOffset(half, 24),
		UDim2.fromOffset(half + 6, y + 18)
	)
	y += 46
	heading(auctionPage, "auction_sort", y)
	local sortButtons: { [string]: TextButton } = {}
	for i, kind in ipairs({ "time", "price", "level" }) do
		local button = Ui.button(
			auctionPage,
			T("auction_sort_" .. kind),
			UDim2.fromOffset((LEFT_W - 8) / 3, 22),
			UDim2.fromOffset((i - 1) * ((LEFT_W - 8) / 3 + 4), y + 18),
			Ui.colors.buttonGrey
		)
		button.Name = "Sort_" .. kind
		button.TextSize = 13
		button.Activated:Connect(function()
			if sort == kind then
				desc = not desc
			else
				sort = kind
				desc = true
			end
			page = 1
			query()
		end)
		sortButtons[kind] = button
	end
	local order = Ui.label(
		auctionPage,
		"",
		UDim2.fromOffset(LEFT_W, 16),
		UDim2.fromOffset(0, y + 42),
		12,
		Ui.colors.muted
	)
	y += 62
	local search = textBox(
		auctionPage,
		T("auction_search"),
		UDim2.fromOffset(LEFT_W, 26),
		UDim2.fromOffset(0, y)
	)
	search.Name = "Search"
	for _, box in ipairs({ minPrice, maxPrice, minLevel, maxLevel, search }) do
		box.FocusLost:Connect(function()
			page = 1
			query()
		end)
	end

	local grid = Instance.new("Frame")
	grid.Name = "Grid"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(GRID_X, 0)
	grid.Size = UDim2.fromOffset(COLS * (SLOT + GAP), ROWS * (SLOT + GAP))
	grid.Parent = auctionPage
	local empty =
		Ui.label(grid, "", UDim2.new(1, 0, 0, 30), UDim2.new(0, 0, 0.5, -15), 15, Ui.colors.muted)
	empty.TextXAlignment = Enum.TextXAlignment.Center
	empty.ZIndex = 6
	local views: { SlotView } = {}
	local selected: Summary? = nil
	local hovered: number? = nil
	local confirm: (Summary) -> ()
	for i = 1, COLS * ROWS do
		local view = slotView(
			grid,
			SLOT,
			UDim2.fromOffset(
				((i - 1) % COLS) * (SLOT + GAP),
				math.floor((i - 1) / COLS) * (SLOT + GAP)
			)
		)
		view.frame.Name = "Lot_" .. i
		view.button.MouseEnter:Connect(function()
			hovered = i
		end)
		view.button.MouseMoved:Connect(function()
			local lot = lots[i]
			if lot and hovered == i then
				local userId = game:GetService("Players").LocalPlayer.UserId
				ItemTooltip.show(
					lot.item,
					UserInputService:GetMouseLocation(),
					lotLines(lot, lot.seller == userId)
				)
			end
		end)
		view.button.MouseLeave:Connect(function()
			if hovered == i then
				hovered = nil
				ItemTooltip.hide()
			end
		end)
		view.button.Activated:Connect(function()
			local lot = lots[i]
			if lot then
				confirm(lot)
			end
		end)
		views[i] = view
	end
	local pagerY = ROWS * (SLOT + GAP) + 6
	local prev = Ui.button(
		auctionPage,
		"<",
		UDim2.fromOffset(34, 28),
		UDim2.fromOffset(GRID_X, pagerY),
		Ui.colors.buttonGrey
	)
	prev.Name = "Prev"
	local pageLabel = Ui.label(
		auctionPage,
		"",
		UDim2.fromOffset(80, 28),
		UDim2.fromOffset(GRID_X + 38, pagerY),
		15,
		Ui.colors.text
	)
	pageLabel.TextXAlignment = Enum.TextXAlignment.Center
	local nextButton = Ui.button(
		auctionPage,
		">",
		UDim2.fromOffset(34, 28),
		UDim2.fromOffset(GRID_X + 122, pagerY),
		Ui.colors.buttonGrey
	)
	nextButton.Name = "Next"
	local totalLabel = Ui.label(
		auctionPage,
		"",
		UDim2.fromOffset(160, 28),
		UDim2.fromOffset(GRID_X + 166, pagerY),
		14,
		Ui.colors.muted
	)
	local refreshButton = Ui.button(
		auctionPage,
		T("auction_refresh"),
		UDim2.fromOffset(110, 28),
		UDim2.fromOffset(GRID_X + COLS * (SLOT + GAP) - 114, pagerY),
		Ui.colors.buttonBlue
	)
	refreshButton.Name = "Refresh"
	refreshButton.TextSize = 14
	prev.Activated:Connect(function()
		if page > 1 then
			page -= 1
			query()
		end
	end)
	nextButton.Activated:Connect(function()
		if page < pageCount then
			page += 1
			query()
		end
	end)
	refreshButton.Activated:Connect(function()
		query()
	end)
	local commissionNote = Ui.label(
		auctionPage,
		T("auction_commission_note", math.floor(cfg.commission * 100 + 0.5), cfg.lotDays),
		UDim2.new(1, -GRID_X, 0, 18),
		UDim2.fromOffset(GRID_X, pagerY + 34),
		12,
		Ui.colors.muted
	)
	commissionNote.TextWrapped = true

	-- the purchase question over the grid
	local ask = Ui.panel(auctionPage, UDim2.fromOffset(340, 120), UDim2.new())
	ask.Name = "Confirm"
	ask.Position = UDim2.fromOffset(GRID_X + (COLS * (SLOT + GAP) - 340) / 2, 80)
	ask.BackgroundTransparency = 0.02
	ask.ZIndex = 20
	ask.Visible = false
	local askView = slotView(ask, 46, UDim2.fromOffset(12, 14))
	askView.button.Visible = false
	local askText = Ui.rich(ask, "", UDim2.new(1, -78, 0, 52), UDim2.fromOffset(66, 10), 14)
	askText.TextWrapped = true
	local buyButton = Ui.button(
		ask,
		T("auction_buy"),
		UDim2.fromOffset(150, 30),
		UDim2.new(0, 12, 1, -42),
		Ui.colors.buttonGreen
	)
	buyButton.Name = "Buy"
	local noButton = Ui.button(
		ask,
		T("auction_cancel"),
		UDim2.fromOffset(150, 30),
		UDim2.new(1, -162, 1, -42),
		Ui.colors.buttonGrey
	)
	noButton.Name = "No"
	for _, d in ipairs(ask:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 21
		end
	end
	confirm = function(lot: Summary)
		ItemTooltip.hide()
		selected = lot
		paint(askView, lot.item)
		local userId = game:GetService("Players").LocalPlayer.UserId
		local mine = lot.seller == userId
		askText.Text = if mine
			then T("auction_own_lot")
			else T(
				"auction_confirm_buy",
				nameOf(lot.item),
				string.format(
					'<font color="%s">%s$</font>',
					Ui.hex(Ui.colors.money),
					Strings.money(lot.price)
				)
			)
		buyButton.Visible = not mine
		ask.Visible = true
		-- a touch has no hover: the tooltip next to the question
		if UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
			ItemTooltip.show(lot.item, askView.frame, lotLines(lot, mine))
		end
	end
	buyButton.Activated:Connect(function()
		local lot = selected
		ask.Visible = false
		ItemTooltip.hide()
		if lot then
			Remotes.event("AuctionBuy"):FireServer(lot.id, lot.price)
		end
	end)
	noButton.Activated:Connect(function()
		ask.Visible = false
		ItemTooltip.hide()
	end)

	local function drawAuction()
		for kind, button in pairs(categoryButtons) do
			button.BackgroundColor3 = if kind == category
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		for kind, button in pairs(sortButtons) do
			button.BackgroundColor3 = if kind == sort
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		order.Text = T(if desc then "auction_order_desc" else "auction_order_asc")
		for i, view in ipairs(views) do
			paint(view, if lots[i] then lots[i].item else nil)
		end
		pageLabel.Text = T("auction_page", page, pageCount)
		prev.Visible, nextButton.Visible = page > 1, page < pageCount
		if hovered and not lots[hovered] then
			hovered = nil
			ItemTooltip.hide()
		end
	end

	query = function()
		requestN += 1
		local n = requestN
		drawAuction()
		local request = {
			category = category,
			sort = sort,
			desc = desc,
			minPrice = number(minPrice),
			maxPrice = number(maxPrice),
			minLevel = number(minLevel),
			maxLevel = number(maxLevel),
			search = if search.Text ~= "" then search.Text else nil,
			page = page,
		}
		task.spawn(function()
			local ok, answer = pcall(function()
				return Remotes.func("AuctionQuery"):InvokeServer(request)
			end)
			if n ~= requestN or not win.Parent then
				return -- a newer request or the window closed
			end
			if not ok or typeof(answer) ~= "table" then
				if ok and answer == nil then
					task.delay(0.4, function() -- too fast: the server skipped it, ask again
						if n == requestN and win.Parent then
							query()
						end
					end)
				end
				return
			end
			lots = answer.lots or {}
			page, pageCount = answer.page or 1, answer.pages or 1
			offset = (answer.now or os.time()) - os.time()
			totalLabel.Text = T("auction_total", answer.total or #lots)
			empty.Text = if answer.unavailable
				then T("auction_unavailable")
				elseif #lots == 0 then T("auction_empty")
				else ""
			drawAuction()
		end)
	end

	-- ── Личные товары ──
	local minePage = pages.mine
	local slotsLabel = Ui.label(
		minePage,
		"",
		UDim2.fromOffset(300, 22),
		UDim2.fromOffset(0, 0),
		15,
		Ui.colors.header
	)
	local mineList = Instance.new("ScrollingFrame")
	mineList.Name = "List"
	mineList.Size = UDim2.new(1, 0, 1, -110)
	mineList.Position = UDim2.fromOffset(0, 28)
	mineList.BackgroundTransparency = 1
	mineList.BorderSizePixel = 0
	mineList.ScrollBarThickness = 6
	mineList.ScrollBarImageColor3 = Ui.colors.border
	mineList.AutomaticCanvasSize = Enum.AutomaticSize.Y
	mineList.CanvasSize = UDim2.new()
	mineList.Parent = minePage
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 6)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = mineList
	local returnsBox = Ui.card(minePage, UDim2.new(1, 0, 0, 74), UDim2.new(0, 0, 1, -76))
	returnsBox.Name = "Returns"
	local returnsLabel = Ui.label(
		returnsBox,
		"",
		UDim2.new(1, -150, 0, 20),
		UDim2.fromOffset(10, 4),
		14,
		Ui.colors.text
	)
	local returnViews: { SlotView } = {}
	for i = 1, 10 do
		local view = slotView(returnsBox, 40, UDim2.fromOffset(10 + (i - 1) * 44, 28))
		view.frame.Visible = false
		returnViews[i] = view
	end
	local claimButton = Ui.button(
		returnsBox,
		T("auction_claim"),
		UDim2.fromOffset(130, 32),
		UDim2.new(1, -140, 0.5, -16),
		Ui.colors.buttonGreen
	)
	claimButton.Name = "Claim"
	claimButton.Activated:Connect(function()
		Remotes.event("AuctionClaim"):FireServer()
	end)

	local function row(
		order_: number,
		stack: ItemStack,
		text: string,
		button: string?,
		onClick: (() -> ())?
	)
		local card = Ui.card(mineList, UDim2.new(1, -10, 0, 56), UDim2.new())
		card.LayoutOrder = order_
		local view = slotView(card, 44, UDim2.fromOffset(6, 6))
		view.button.MouseMoved:Connect(function()
			ItemTooltip.show(stack, UserInputService:GetMouseLocation())
		end)
		view.button.MouseLeave:Connect(function()
			ItemTooltip.hide()
		end)
		paint(view, stack)
		local label = Ui.rich(card, text, UDim2.new(1, -230, 1, -8), UDim2.fromOffset(58, 4), 14)
		label.TextWrapped = true
		if button and onClick then
			local b = Ui.button(
				card,
				button,
				UDim2.fromOffset(150, 30),
				UDim2.new(1, -160, 0.5, -15),
				Ui.colors.close
			)
			b.Name = "Withdraw"
			b.TextSize = 14
			b.Activated:Connect(onClick)
		end
		return card
	end

	local function drawMine()
		for _, child in ipairs(mineList:GetChildren()) do
			if child:IsA("GuiObject") then -- the rows and the empty hint
				child:Destroy()
			end
		end
		local a = current and current.auction
		local lotsMine = if a then a.lots else {}
		local pendingSells = if a then a.pendingSells else {}
		local pendingBuys = if a then a.pendingBuys else {}
		local used = 0
		local sorted: { Summary } = {}
		for _, s in pairs(lotsMine) do
			table.insert(sorted, s)
			used += 1
		end
		table.sort(sorted, function(x, z)
			return x.createdAt > z.createdAt
		end)
		local n = 0
		for _, s in pairs(pendingSells) do
			used += 1
			n += 1
			row(
				n,
				s.item,
				string.format(
					'<b>%s</b>\n<font color="%s">%s</font>',
					nameOf(s.item),
					Ui.hex(Ui.colors.muted),
					T("auction_status_pending")
				)
			)
		end
		for _, s in ipairs(sorted) do
			n += 1
			local left = s.expiresAt - serverNow()
			local status = if left > 0
				then T("auction_expires", timeText(left))
				else T("auction_status_expired")
			row(
				n,
				s.item,
				string.format(
					'<b>%s</b>\n<font color="%s">%s$</font>  <font color="%s">%s</font>',
					nameOf(s.item),
					Ui.hex(Ui.colors.money),
					Strings.money(s.price),
					Ui.hex(Ui.colors.muted),
					status
				),
				T("auction_withdraw"),
				function()
					Remotes.event("AuctionCancel"):FireServer(s.id)
				end
			)
		end
		for _, b in pairs(pendingBuys) do
			n += 1
			local card = Ui.card(mineList, UDim2.new(1, -10, 0, 34), UDim2.new())
			card.LayoutOrder = n
			Ui.label(
				card,
				T("auction_buying", Strings.money(b.price)),
				UDim2.new(1, -16, 1, 0),
				UDim2.fromOffset(8, 0),
				14,
				Ui.colors.yellow
			)
		end
		if n == 0 then
			local hint = Ui.label(
				mineList,
				T("auction_mine_empty"),
				UDim2.new(1, -10, 0, 40),
				UDim2.new(),
				15,
				Ui.colors.muted
			)
			hint.TextXAlignment = Enum.TextXAlignment.Center
		end
		slotsLabel.Text = T("auction_slots", used, cfg.slots)
		local returns = if a then a.returns else {}
		returnsLabel.Text = T("auction_returns", #returns)
		for i, view in ipairs(returnViews) do
			view.frame.Visible = returns[i] ~= nil
			paint(view, returns[i])
		end
		claimButton.Visible = #returns > 0
		returnsBox.Visible = #returns > 0
		mineList.Size = if #returns > 0 then UDim2.new(1, 0, 1, -110) else UDim2.new(1, 0, 1, -30)
	end

	-- ── Продать ──
	local sellPage = pages.sell
	Ui.label(
		sellPage,
		T("auction_choose_item"),
		UDim2.fromOffset(400, 22),
		UDim2.fromOffset(0, 0),
		15,
		Ui.colors.header
	)
	local INV = 40
	local invViews: { SlotView } = {}
	local chosen: number? = nil
	local drawSell: () -> ()
	local countBox: TextBox
	for slot = 1, 36 do
		-- rows like the inventory window: the main 27 above, the hotbar below
		local index = if slot <= 9 then 27 + slot else slot - 9
		local rowN = math.floor((index - 1) / 9)
		local view = slotView(
			sellPage,
			INV,
			UDim2.fromOffset(
				((index - 1) % 9) * (INV + 4),
				28 + rowN * (INV + 4) + (if rowN == 3 then 8 else 0)
			)
		)
		view.frame.Name = "Inv_" .. slot
		view.button.MouseMoved:Connect(function()
			local stack = current and current.inventory[slot]
			if stack then
				ItemTooltip.show(stack, UserInputService:GetMouseLocation())
			end
		end)
		view.button.MouseLeave:Connect(function()
			ItemTooltip.hide()
		end)
		view.button.Activated:Connect(function()
			local stack = current and current.inventory[slot]
			if stack and Auction.tradable(stack) then
				chosen = slot
				countBox.Text = tostring(stack.count)
				drawSell()
			end
		end)
		invViews[slot] = view
	end
	local formX = 9 * (INV + 4) + 16
	local form = Ui.card(sellPage, UDim2.new(1, -formX, 0, 300), UDim2.fromOffset(formX, 28))
	form.Name = "SellForm"
	Ui.label(
		form,
		T("auction_sell_title"),
		UDim2.new(1, -16, 0, 22),
		UDim2.fromOffset(10, 6),
		16,
		Ui.colors.header
	)
	local formView = slotView(form, 52, UDim2.fromOffset(10, 34))
	formView.button.Visible = false
	local formName = Ui.rich(form, "", UDim2.new(1, -80, 0, 52), UDim2.fromOffset(70, 34), 14)
	formName.TextWrapped = true
	Ui.label(
		form,
		T("auction_count"),
		UDim2.fromOffset(100, 20),
		UDim2.fromOffset(10, 96),
		13,
		Ui.colors.muted
	)
	countBox = textBox(form, "1", UDim2.fromOffset(90, 26), UDim2.fromOffset(10, 116))
	countBox.Name = "Count"
	local allButton = Ui.button(
		form,
		T("auction_all"),
		UDim2.fromOffset(60, 26),
		UDim2.fromOffset(106, 116),
		Ui.colors.buttonGrey
	)
	allButton.TextSize = 13
	Ui.label(
		form,
		T("auction_price_input"),
		UDim2.fromOffset(160, 20),
		UDim2.fromOffset(10, 148),
		13,
		Ui.colors.muted
	)
	local priceBox =
		textBox(form, tostring(cfg.minPrice), UDim2.fromOffset(156, 26), UDim2.fromOffset(10, 168))
	priceBox.Name = "Price"
	local net = Ui.rich(form, "", UDim2.new(1, -20, 0, 36), UDim2.fromOffset(10, 198), 13)
	net.TextWrapped = true
	local listButton = Ui.button(
		form,
		T("auction_list"),
		UDim2.new(1, -20, 0, 32),
		UDim2.new(0, 10, 1, -78),
		Ui.colors.buttonGreen
	)
	listButton.Name = "List"
	listButton.TextSize = 15
	local backButton = Ui.button(
		form,
		T("auction_back_btn"),
		UDim2.new(1, -20, 0, 28),
		UDim2.new(0, 10, 1, -40),
		Ui.colors.buttonGrey
	)
	backButton.Name = "Back"
	backButton.TextSize = 14

	local function readSell(): (ItemStack?, number?, number?)
		local stack = if chosen and current then current.inventory[chosen] else nil
		if not stack then
			return nil, nil, nil
		end
		local amount = math.floor(number(countBox) or 1)
		amount = math.clamp(amount, 1, stack.count)
		local dollars = number(priceBox)
		if dollars then
			dollars = math.floor(dollars)
			if dollars < cfg.minPrice or dollars > cfg.maxPrice then
				dollars = nil
			end
		end
		return stack, amount, dollars
	end
	drawSell = function()
		for slot, view in ipairs(invViews) do
			local stack = current and current.inventory[slot]
			paint(view, stack)
			local ok = stack ~= nil and Auction.tradable(stack)
			view.icon.ImageTransparency = if stack and not ok then 0.6 else 0
			local stroke = view.frame:FindFirstChildOfClass("UIStroke")
			if stroke then
				stroke.Color = if slot == chosen then Ui.colors.slotSelected else Ui.colors.border
				stroke.Thickness = if slot == chosen then 2 else 1
			end
		end
		local stack, amount, dollars = readSell()
		if not stack then
			chosen = nil
		end
		paint(formView, stack)
		formName.Text = if stack
			then string.format("<b>%s</b>", Strings.itemName(stack.id, stack.level, locale))
			else string.format(
				'<font color="%s">%s</font>',
				Ui.hex(Ui.colors.muted),
				T("auction_pick_hint")
			)
		countBox.TextEditable = stack ~= nil and stack.count > 1
		if stack and amount and tostring(amount) ~= countBox.Text and countBox.Text ~= "" then
			countBox.Text = tostring(amount)
		end
		if dollars then
			local units = dollars * Config.moneyScale
			net.Text = T(
				"auction_you_get",
				math.floor(cfg.commission * 100 + 0.5),
				string.format(
					'<font color="%s">%s$</font>',
					Ui.hex(Ui.colors.money),
					Strings.money(Auction.net(units))
				)
			)
		else
			net.Text = string.format(
				'<font color="%s">%s</font>',
				Ui.hex(Ui.colors.muted),
				T(
					"auction_price_range",
					Strings.grouped(cfg.minPrice, 0),
					Strings.grouped(cfg.maxPrice, 0)
				)
			)
		end
		local ready = stack ~= nil and dollars ~= nil
		listButton.AutoButtonColor = ready
		listButton.BackgroundColor3 = if ready then Ui.colors.buttonGreen else Ui.colors.buttonGrey
	end
	allButton.Activated:Connect(function()
		local stack = readSell()
		if stack then
			countBox.Text = tostring(stack.count)
			drawSell()
		end
	end)
	countBox.FocusLost:Connect(function()
		drawSell()
	end)
	priceBox:GetPropertyChangedSignal("Text"):Connect(function()
		drawSell()
	end)
	listButton.Activated:Connect(function()
		local stack, amount, dollars = readSell()
		if stack and amount and dollars and chosen then
			Remotes.event("AuctionSell"):FireServer(chosen, amount, dollars)
			chosen = nil
			priceBox.Text = ""
			countBox.Text = ""
			show("mine")
		end
	end)
	backButton.Activated:Connect(function()
		show("auction")
	end)
	sellButton.Activated:Connect(function()
		show(if tab == "sell" then "auction" else "sell")
	end)

	show = function(kind: string)
		tab = kind
		ask.Visible = false
		ItemTooltip.hide()
		for k, frame in pairs(pages) do
			frame.Visible = k == kind
		end
		for k, button in pairs(tabButtons) do
			button.BackgroundColor3 = if k == kind
				then Ui.colors.buttonBlue
				else Ui.colors.buttonGrey
		end
		if kind == "auction" then
			query()
		elseif kind == "mine" then
			Remotes.event("AuctionSettle"):FireServer() -- sold lots pay out now
			drawMine()
		else
			drawSell()
		end
	end

	-- the server says something changed (a purchase, a listing): redraw from fresh data
	local updated = Remotes.event("AuctionUpdated").OnClientEvent:Connect(function()
		if tab == "auction" then
			query()
		end
	end)
	local alive = true
	win.Destroying:Connect(function()
		alive = false
		updated:Disconnect()
		ItemTooltip.hide()
	end)
	task.spawn(function()
		while alive do
			task.wait(POLL_SECONDS)
			if alive and tab == "auction" and not ask.Visible then
				query()
			elseif alive and tab == "mine" then
				drawMine() -- the time left ticks
			end
		end
	end)

	drawMoney()
	show("auction")
	return win,
		function(p: Types.Profile?)
			current = p
			drawMoney()
			if tab == "mine" then
				drawMine()
			elseif tab == "sell" then
				drawSell()
			end
		end
end

return AuctionWindow
