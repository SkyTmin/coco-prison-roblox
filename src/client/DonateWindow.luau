--!strict
-- «Донат-магазин» [N] [владелец 27.10: «переходи к донат меню»; wiki DONATE-SHOP-BOOSTERS]: the crystal balance on top
-- with «Пополнить», five tabs (Кристаллы, Бустеры, Ключи и предметы, Нужды, Аукцион), a grid of goods and the
-- purchase panel on the right: the big picture, the name, what it does, the amount (−10 −1 N +1 +10, up to the
-- item's limit), the total (red when the crystals are short) and «Купить» glowing — or «Пополнить» when short. The
-- crystals tab sells the packs for Robux (the Roblox prompt; Robux prices carry Roblox's own Robux glyph \u{E002},
-- our crystal prices our crystal picture). Shared/Donate holds the rules, DonateService decides; built once and
-- updated in place, a purchase flashes the panel and «+N» floats up. Every item can also be bought straight for Robux,
-- one piece per purchase (the green button; its own Developer Product, DonateBuyRobux).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Donate = require(Shared.Donate)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)
local Kit = require(script.Parent.WindowKit)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local DonateWindow = {}

local W, H = 790, 600
local CARD_W, CARD_H, GAP, COLS = 112, 132, 8, 4
local GRID_W = COLS * CARD_W + (COLS - 1) * GAP + 12
local ROBUX = utf8.char(0xE002)
local CRYSTAL = Color3.fromRGB(90, 200, 255)
local TABS: { [string]: { color: Color3, icon: string } } = {
	crystals = { color = CRYSTAL, icon = "crystal" },
	boosters = { color = Color3.fromRGB(190, 125, 255), icon = "booster_set" },
	keys = { color = Color3.fromRGB(255, 190, 70), icon = "ancient_key" },
	needs = { color = Color3.fromRGB(120, 220, 140), icon = "soap" },
	auction = { color = Color3.fromRGB(255, 140, 90), icon = "auction_slot" },
}

-- 1 234 567
local function grouped(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1 "):reverse()
	return (out:gsub("^ ", ""))
end

local function centred(label: TextLabel): TextLabel
	label.TextXAlignment = Enum.TextXAlignment.Center
	return label
end

-- a row centred in its box: [picture] text (the price of a card, the total)
local function priceRow(
	parent: Instance,
	size: UDim2,
	position: UDim2,
	textSize: number
): (ImageLabel, TextLabel)
	local row = Kit.frame(parent, size, position, Kit.CARD)
	row.BackgroundTransparency = 1
	local list = Instance.new("UIListLayout")
	list.FillDirection = Enum.FillDirection.Horizontal
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	list.Padding = UDim.new(0, 4)
	list.SortOrder = Enum.SortOrder.LayoutOrder
	list.Parent = row
	local icon = Kit.image(
		row,
		Config.icons.icons.crystal,
		UDim2.fromOffset(textSize + 2, textSize + 2),
		UDim2.new()
	)
	icon.LayoutOrder = 1
	local label =
		Kit.text(row, "", UDim2.fromScale(0, 1), UDim2.new(), textSize, Ui.colors.text, Kit.BOLD)
	label.AutomaticSize = Enum.AutomaticSize.X
	label.LayoutOrder = 2
	return icon, label
end

function DonateWindow.build(
	parent: Instance,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local win, content = createWindow(parent, t("donate_title"), UDim2.fromOffset(W, H), onClose)
	Ui.titleColor(win, CRYSTAL)
	local current: Types.Profile? = profile
	local tab = "keys"
	local selected: string? = nil
	local count = 1
	local cards: { [string]: { frame: Frame, edge: UIStroke, price: TextLabel? } } = {}
	local refreshAll: () -> () = function() end

	-- ------------------------------------------------------------------ the balance
	local header = Kit.frame(content, UDim2.new(1, -8, 0, 60), UDim2.fromOffset(4, 2), Kit.CARD)
	Kit.corner(header, 12)
	Kit.stroke(header, Kit.EDGE, 1.5)
	Kit.gradient(header, CRYSTAL:Lerp(Kit.CARD, 0.72), Kit.CARD, 0)
	local balanceIcon = Kit.image(
		header,
		Config.icons.icons.crystal,
		UDim2.fromOffset(44, 44),
		UDim2.fromOffset(12, 8)
	)
	Kit.bob(balanceIcon, 3, 2.4)
	Kit.text(
		header,
		t("donate_tab_crystals"),
		UDim2.fromOffset(300, 18),
		UDim2.fromOffset(66, 8),
		13,
		Ui.colors.muted,
		Kit.BOLD
	)
	local balance = Kit.text(
		header,
		"0",
		UDim2.fromOffset(300, 30),
		UDim2.fromOffset(66, 24),
		28,
		CRYSTAL,
		Kit.BOLD
	)
	local balanceEdge = Instance.new("UIStroke")
	balanceEdge.Thickness = 1.5
	balanceEdge.Transparency = 0.5
	balanceEdge.Parent = balance
	local topUp, topUpLabel, topUpBack =
		Kit.actionButton(header, UDim2.fromOffset(180, 40), UDim2.new(1, -192, 0, 10), 18)
	topUpLabel.Text = "+ " .. t("donate_top_up")
	Kit.fit(topUpLabel)
	Kit.gradient(
		topUpBack,
		CRYSTAL:Lerp(Color3.new(1, 1, 1), 0.1),
		CRYSTAL:Lerp(Color3.new(), 0.45),
		90
	)
	Kit.pressable(topUp)

	-- ------------------------------------------------------------------ the tabs
	local tabBar = Kit.frame(content, UDim2.new(1, -8, 0, 38), UDim2.fromOffset(4, 70), Kit.CARD)
	tabBar.BackgroundTransparency = 1
	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.Padding = UDim.new(0, 6)
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Parent = tabBar
	local tabButtons: { [string]: { button: TextButton, edge: UIStroke, label: TextLabel } } = {}
	local selectTab: (string) -> () = function() end
	for i, entry in ipairs(Donate.tabs) do
		local look = TABS[entry.id] or TABS.keys
		local button = Instance.new("TextButton")
		button.AutoButtonColor = false
		button.Text = ""
		button.Size = UDim2.new(0.2, -5, 1, 0)
		button.BackgroundColor3 = Kit.CARD
		button.LayoutOrder = i
		button.Parent = tabBar
		Kit.corner(button, 9)
		local edge = Kit.stroke(button, Kit.EDGE, 1.5)
		Kit.image(
			button,
			Config.icons.icons[look.icon],
			UDim2.fromOffset(26, 26),
			UDim2.fromOffset(7, 6)
		)
		local label = Kit.text(
			button,
			t("donate_tab_" .. entry.id),
			UDim2.new(1, -42, 1, 0),
			UDim2.fromOffset(38, 0),
			14,
			Ui.colors.text,
			Kit.BOLD
		)
		Kit.fit(label)
		Kit.pressable(button)
		button.Activated:Connect(function()
			selectTab(entry.id)
		end)
		tabButtons[entry.id] = { button = button, edge = edge, label = label }
	end

	-- ------------------------------------------------------------------ the grid
	local grid = Instance.new("ScrollingFrame")
	grid.BackgroundTransparency = 1
	grid.BorderSizePixel = 0
	grid.Size = UDim2.new(0, GRID_W, 1, -122)
	grid.Position = UDim2.fromOffset(4, 116)
	grid.ScrollBarThickness = 6
	grid.ScrollBarImageColor3 = Kit.EDGE
	grid.ScrollingDirection = Enum.ScrollingDirection.Y
	grid.CanvasSize = UDim2.new()
	grid.Parent = content

	-- ------------------------------------------------------------------ the purchase panel
	local panel = Kit.frame(
		content,
		UDim2.new(1, -(GRID_W + 16), 1, -122),
		UDim2.fromOffset(GRID_W + 12, 116),
		Kit.CARD
	)
	Kit.corner(panel, 12)
	Kit.stroke(panel, Kit.EDGE, 1.5)
	local panelWash = Kit.frame(panel, UDim2.fromScale(1, 0.5), UDim2.new(), CRYSTAL)
	Kit.corner(panelWash, 12)
	local washFade = Instance.new("UIGradient")
	washFade.Rotation = 90
	washFade.Transparency = NumberSequence.new(0.75, 1)
	washFade.Parent = panelWash
	local bigIcon = Kit.image(panel, nil, UDim2.fromOffset(84, 84), UDim2.new(0.5, -42, 0, 10))
	Kit.bob(bigIcon, 4, 2.8)
	local name = centred(
		Kit.text(
			panel,
			"",
			UDim2.new(1, -20, 0, 24),
			UDim2.fromOffset(10, 98),
			19,
			Ui.colors.text,
			Kit.BOLD
		)
	)
	Kit.fit(name)
	local description = centred(
		Kit.text(
			panel,
			"",
			UDim2.new(1, -24, 0, 66),
			UDim2.fromOffset(12, 124),
			13,
			Ui.colors.muted
		)
	)
	description.TextWrapped = true
	description.TextYAlignment = Enum.TextYAlignment.Top

	local amountCaption = centred(
		Kit.text(
			panel,
			t("donate_amount"),
			UDim2.new(1, -20, 0, 16),
			UDim2.fromOffset(10, 194),
			12,
			Ui.colors.muted,
			Kit.BOLD
		)
	)
	local stepper = Kit.frame(panel, UDim2.new(1, -24, 0, 34), UDim2.fromOffset(12, 212), Kit.TRACK)
	stepper.BackgroundTransparency = 1
	local amount = centred(
		Kit.text(
			stepper,
			"1",
			UDim2.new(1, -168, 1, 0),
			UDim2.fromOffset(84, 0),
			22,
			Ui.colors.text,
			Kit.BOLD
		)
	)
	local function stepButton(text: string, x: UDim, delta: number)
		local b = Instance.new("TextButton")
		b.AutoButtonColor = false
		b.Size = UDim2.fromOffset(38, 34)
		b.Position = UDim2.new(x, UDim.new())
		b.BackgroundColor3 = Kit.GREY
		b.Font = Kit.BOLD
		b.TextSize = 15
		b.TextColor3 = Ui.colors.text
		b.Text = text
		b.Parent = stepper
		Kit.corner(b, 8)
		Kit.stroke(b, Kit.EDGE, 1)
		Kit.hoverable(b, Kit.GREY, Kit.GREY:Lerp(Color3.new(1, 1, 1), 0.15))
		Kit.pressable(b)
		b.Activated:Connect(function()
			count += delta
			refreshAll()
			Kit.pop(amount, 1.2)
		end)
	end
	stepButton("−10", UDim.new(0, 0), -10)
	stepButton("−1", UDim.new(0, 42), -1)
	stepButton("+1", UDim.new(1, -80), 1)
	stepButton("+10", UDim.new(1, -38), 10)

	local totalCaption = Kit.text(
		panel,
		t("donate_total"),
		UDim2.new(0.5, -12, 0, 22),
		UDim2.fromOffset(12, 254),
		14,
		Ui.colors.muted,
		Kit.BOLD
	)
	totalCaption.TextYAlignment = Enum.TextYAlignment.Center
	local totalIcon, total =
		priceRow(panel, UDim2.new(0.5, 0, 0, 24), UDim2.new(0.5, -12, 0, 253), 18)
	local note = centred(
		Kit.text(
			panel,
			"",
			UDim2.new(1, -20, 0, 18),
			UDim2.fromOffset(10, 282),
			13,
			Ui.colors.muted,
			Kit.BOLD
		)
	)
	Kit.fit(note)
	-- the two buttons: for crystals (blue, any amount) and straight for Robux (green, one piece) [владелец 28.10:
	-- «хочу, чтобы игрок мог покупать сами предметы. Даже за 10 роблакс»]
	type Action = {
		button: TextButton,
		label: TextLabel,
		paint: (Color3?, boolean) -> (),
		run: () -> (),
	}
	local function actionSlot(y: number, glowColor: Color3): Action
		local button, label, back =
			Kit.actionButton(panel, UDim2.new(1, -24, 0, 44), UDim2.new(0, 12, 1, y), 20)
		Kit.fit(label)
		local gradient = Kit.gradient(back, Kit.GOOD, Kit.GOOD, 90)
		Kit.pressable(button)
		local glow = Kit.glow(button, glowColor)
		local slot: Action
		slot = {
			button = button,
			label = label,
			paint = function(color: Color3?, ready: boolean)
				local c = color or Kit.GREY
				gradient.Color =
					ColorSequence.new(c:Lerp(Color3.new(1, 1, 1), 0.1), c:Lerp(Color3.new(), 0.4))
				label.TextTransparency = if color then 0 else 0.3
				glow(ready)
			end,
			run = function() end,
		}
		button.Activated:Connect(function()
			slot.run()
		end)
		return slot
	end
	local buy = actionSlot(-122, CRYSTAL)
	local orRobux = centred(
		Kit.text(
			panel,
			t("donate_or_robux"),
			UDim2.new(1, -20, 0, 16),
			UDim2.new(0, 10, 1, -74),
			12,
			Ui.colors.muted,
			Kit.BOLD
		)
	)
	local robux = actionSlot(-56, Kit.GOOD)

	-- ------------------------------------------------------------------ one card of the grid
	local function makeCard(
		id: string,
		index: number,
		color: Color3,
		icon: string?,
		title: string
	): Frame
		local f = Instance.new("TextButton")
		f.AutoButtonColor = false
		f.Text = ""
		f.Size = UDim2.fromOffset(CARD_W, CARD_H)
		f.Position = UDim2.fromOffset(
			((index - 1) % COLS) * (CARD_W + GAP) + 2,
			math.floor((index - 1) / COLS) * (CARD_H + GAP) + 2
		)
		f.BackgroundColor3 = Kit.CARD
		f.Parent = grid
		Kit.corner(f, 10)
		local edge = Kit.stroke(f, Kit.EDGE, 1.5)
		Kit.hoverable(f)
		local wash = Kit.frame(f, UDim2.fromScale(1, 0.6), UDim2.new(), color)
		Kit.corner(wash, 10)
		local fade = Instance.new("UIGradient")
		fade.Rotation = 90
		fade.Transparency = NumberSequence.new(0.8, 1)
		fade.Parent = wash
		local picture = Kit.image(f, icon, UDim2.fromOffset(56, 56), UDim2.new(0.5, -28, 0, 8))
		local label = centred(
			Kit.text(
				f,
				title,
				UDim2.new(1, -10, 0, 32),
				UDim2.fromOffset(5, 66),
				12,
				Ui.colors.text,
				Kit.BOLD
			)
		)
		label.TextWrapped = true
		label.TextYAlignment = Enum.TextYAlignment.Center
		f.MouseEnter:Connect(function()
			Kit.pop(picture, 1.12)
		end)
		Kit.pressable(f)
		f.Activated:Connect(function()
			if selected ~= id then
				selected = id
				count = 1
				refreshAll()
				Kit.pop(bigIcon, 1.2)
			end
		end)
		cards[id] = { frame = f :: any, edge = edge }
		return f :: any
	end

	local function badge(f: Frame, text: string, color: Color3)
		local b = Kit.text(
			f,
			text,
			UDim2.fromOffset(46, 18),
			UDim2.new(1, -50, 0, 4),
			13,
			color,
			Kit.BOLD
		)
		b.TextXAlignment = Enum.TextXAlignment.Right
		local edge = Instance.new("UIStroke")
		edge.Thickness = 1.5
		edge.Transparency = 0.3
		edge.Parent = b
	end

	local function fillGrid()
		for _, child in ipairs(grid:GetChildren()) do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		table.clear(cards)
		local look = TABS[tab] or TABS.keys
		local n = 0
		if tab == "crystals" then
			for i, pack in ipairs(Donate.packs) do
				local f = makeCard(
					pack.id,
					i,
					look.color,
					Config.icons.icons[pack.icon],
					t("donate_pack_name", pack.crystals)
				)
				if pack.bonus then
					badge(f, "+" .. pack.bonus .. "%", Kit.GOOD)
				end
				local price = centred(
					Kit.text(
						f,
						ROBUX .. " " .. grouped(pack.robux),
						UDim2.new(1, -10, 0, 22),
						UDim2.fromOffset(5, 102),
						16,
						Kit.GOOD,
						Kit.BOLD
					)
				)
				cards[pack.id].price = price
				n = i
			end
		else
			local items = {}
			for _, entry in ipairs(Donate.tabs) do
				if entry.id == tab then
					items = entry.items or {}
				end
			end
			for i, id in ipairs(items) do
				local item = Donate.item(id)
				if item then
					local f = makeCard(id, i, look.color, Donate.icon(id), Donate.name(id, locale))
					if (item.each or 1) > 1 then
						badge(f, "×" .. (item.each or 1), Ui.colors.text)
					elseif item.booster then
						badge(f, "×" .. Donate.MULT, look.color)
					end
					local _, price =
						priceRow(f, UDim2.new(1, -10, 0, 22), UDim2.fromOffset(5, 102), 15)
					price.Text = grouped(item.price)
					cards[id].price = price
					n = i
				end
			end
		end
		grid.CanvasSize = UDim2.fromOffset(0, math.ceil(n / COLS) * (CARD_H + GAP) + 4)
		grid.CanvasPosition = Vector2.zero
	end

	-- ------------------------------------------------------------------ everything that follows the profile
	refreshAll = function()
		local p = current
		local crystals = Donate.crystals(p)
		balance.Text = grouped(crystals)
		local look = TABS[tab] or TABS.keys
		for id, entry in pairs(tabButtons) do
			local on = id == tab
			local c = (TABS[id] or TABS.keys).color
			entry.button.BackgroundColor3 = if on then c:Lerp(Kit.CARD, 0.55) else Kit.CARD
			entry.edge.Color = if on then c else Kit.EDGE
			entry.label.TextColor3 = if on then Ui.colors.white else Ui.colors.muted
		end
		panelWash.BackgroundColor3 = look.color
		for id, card in pairs(cards) do
			local on = id == selected
			card.edge.Color = if on then look.color else Kit.EDGE
			card.edge.Thickness = if on then 2.5 else 1.5
			local item = Donate.item(id)
			if item and card.price then
				card.price.TextColor3 = if crystals >= item.price then Ui.colors.text else Kit.BAD
			end
		end

		local pack = if tab == "crystals" then Donate.pack(selected) else nil
		local item = if tab ~= "crystals" then Donate.item(selected) else nil
		local id = selected or ""
		amountCaption.Visible = item ~= nil
		stepper.Visible = item ~= nil
		totalCaption.Visible = true
		if pack then
			bigIcon.Image = Config.icons.icons[pack.icon] or ""
			name.Text = t("donate_pack_name", pack.crystals)
			description.Text = t("donate_hint_crystals")
			totalIcon.Visible = false
			total.Text = ROBUX .. " " .. grouped(pack.robux)
			total.TextColor3 = Kit.GOOD
			note.Text = if pack.bonus then t("donate_pack_bonus", pack.bonus) else ""
			note.TextColor3 = Kit.GOOD
			buy.button.Visible = false
			orRobux.Visible = false
			robux.label.Text = ROBUX .. " " .. grouped(pack.robux)
			robux.paint(Kit.GOOD, true)
			robux.run = function()
				Remotes.event("DonateTopUp"):FireServer(pack.id)
			end
		elseif item then
			buy.button.Visible = true
			orRobux.Visible = true
			local limit = Donate.limit(p, id)
			count = math.clamp(count, 1, math.max(limit, 1))
			local price = item.price * count
			bigIcon.Image = Donate.icon(id) or ""
			name.Text = Donate.name(id, locale)
			description.Text = Donate.description(id, locale)
			amount.Text = tostring(count)
			totalIcon.Visible = true
			total.Text = grouped(price)
			total.TextColor3 = if crystals >= price then Ui.colors.text else Kit.BAD
			if item.auctionSlot then
				note.Text = t("donate_bought_count", p and p.auctionSlots or 0, item.max)
			else
				note.Text = ""
			end
			note.TextColor3 = Ui.colors.muted
			robux.label.Text = t("donate_robux_buy", ROBUX .. " " .. grouped(item.robux))
			if limit <= 0 then
				buy.label.Text = t("donate_limit")
				buy.paint(nil, false)
				buy.run = function() end
				robux.paint(nil, false)
				robux.run = function() end
			else
				robux.paint(Kit.GOOD, false)
				robux.run = function()
					Remotes.event("DonateBuyRobux"):FireServer(id)
				end
				if crystals < price then
					buy.label.Text = t("donate_top_up")
					buy.paint(CRYSTAL:Lerp(Kit.GREY, 0.5), false)
					buy.run = function()
						selectTab("crystals")
					end
				else
					buy.label.Text = t("donate_buy")
					buy.paint(CRYSTAL, true)
					local n = count
					buy.run = function()
						Remotes.event("DonateBuy"):FireServer(id, n)
					end
				end
			end
		end
	end

	selectTab = function(id: string)
		tab = id
		fillGrid()
		selected = nil
		if id == "crystals" then
			selected = if Donate.packs[1] then Donate.packs[1].id else nil
		else
			for _, entry in ipairs(Donate.tabs) do
				if entry.id == id and entry.items then
					selected = entry.items[1]
				end
			end
		end
		count = 1
		refreshAll()
		Kit.pop(bigIcon, 1.15)
	end
	topUp.Activated:Connect(function()
		selectTab("crystals")
	end)

	-- ------------------------------------------------------------------ what the server answers
	local connections = {
		Remotes.event("DonateBought").OnClientEvent:Connect(function(_id: string, n: number)
			Kit.flash(panel, Kit.GOOD)
			Kit.pop(bigIcon, 1.35)
			Kit.floatText(panel, "+" .. n, Kit.GOOD, UDim2.new(0.5, 0, 0, 60))
		end),
		Remotes.event("DonateCrystals").OnClientEvent:Connect(function(n: number)
			Kit.flash(header, CRYSTAL)
			Kit.pop(balanceIcon, 1.4)
			Kit.floatText(header, "+" .. grouped(n), CRYSTAL, UDim2.fromOffset(330, 30))
		end),
	}
	win.Destroying:Connect(function()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
	end)

	local function refresh(p: Types.Profile?)
		current = p
		refreshAll()
	end
	-- no crystals yet: open on the packs
	selectTab(if Donate.crystals(profile) > 0 then "keys" else "crystals")
	return win, refresh
end

return DonateWindow
