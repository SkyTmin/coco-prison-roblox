--!strict
-- The book window [владелец 28.10: «Если взять книгу в руку, можно будет нажать использовать. Выйдет меню, и можно
-- выбрать предмет, куда наложится»; «сделай красивыми, ты уже инвентарь наш делал чёткий»]: an ancient book, powder
-- or a dispeller in the hand → «Использовать» (F / the touch button) → this window, in the dark inventory style: a
-- card with the held item (name in its rarity colour, what it does, the apply chance), the items it can go on (the bag
-- and the worn armor; powder: the books) — the ones that do not fit dimmed with the reason in the tooltip — and a
-- card with the outcome line and the button. The server (BookService) checks everything again and rolls the chance.
-- The dispeller asks twice: the books are lost.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Books = require(Shared.Books)
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ItemTooltip = require(script.Parent.ItemTooltip)
local SlotView = require(script.Parent.SlotView)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
type Candidate = { stack: Types.ItemStack, where: string, key: number | string, refusal: string? }

local BookWindow = {}

local SLOT, GAP, PAD, COLS = 44, 4, 16, 9
local MAX_ROWS = 4
local GRID_W = COLS * SLOT + (COLS - 1) * GAP
local INNER_W = GRID_W + 2 * PAD
local SOURCE_H = 78
local FOOT_H = 54
local TITLES = {
	[Books.BOOK] = "book_window_book",
	[Books.POWDER] = "book_window_powder",
	[Books.DISPELLER] = "book_window_dispel",
}
local ACTIONS = {
	[Books.BOOK] = "book_action_apply",
	[Books.POWDER] = "book_action_powder",
	[Books.DISPELLER] = "book_action_dispel",
}
local ACTION_COLORS = {
	[Books.BOOK] = Ui.colors.buttonGreen,
	[Books.POWDER] = Ui.colors.buttonBlue,
	[Books.DISPELLER] = Ui.colors.close,
}

-- the slot of the held item the window opens for (set before opening)
BookWindow.sourceSlot = 1

-- is this stack worth listing for the source at all (the right kind of item)
local function relevant(source: Types.ItemStack, stack: Types.ItemStack): boolean
	if source.id == Books.POWDER then
		return stack.id == Books.BOOK
	elseif source.id == Books.DISPELLER then
		return stack.id ~= Books.BOOK and stack.books ~= nil and #stack.books > 0
	end
	local entry = source.books and source.books[1]
	local card = entry and Config.books.catalog[entry.id]
	return card ~= nil and table.find(card.items, stack.id) ~= nil
end

local function candidates(profile: Types.Profile, sourceSlot: number): { Candidate }
	local source = profile.inventory[sourceSlot]
	local out: { Candidate } = {}
	if not source then
		return out
	end
	for _, piece in ipairs(Books.ARMOR) do
		local stack = profile.armor and profile.armor[piece]
		if stack and relevant(source, stack) then
			table.insert(out, {
				stack = stack,
				where = "armor",
				key = piece,
				refusal = Books.refusalFor(source, stack),
			})
		end
	end
	for slot = 1, 36 do
		local stack = profile.inventory[slot]
		if slot ~= sourceSlot and stack and relevant(source, stack) then
			table.insert(out, {
				stack = stack,
				where = "inv",
				key = slot,
				refusal = Books.refusalFor(source, stack),
			})
		end
	end
	-- the ones that fit first
	table.sort(out, function(a, b)
		if (a.refusal == nil) ~= (b.refusal == nil) then
			return a.refusal == nil
		end
		return false
	end)
	return out
end

local function rarityOf(stack: Types.ItemStack): string?
	local book = stack.books and stack.books[1]
	local card = book and Config.books.catalog[book.id]
	return stack.rarity or (card and card.rarity) or nil
end

function BookWindow.build(
	parent: Instance,
	profile: Types.Profile,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local sourceSlot = BookWindow.sourceSlot
	local source = profile.inventory[sourceSlot]
	local sourceId = if source then source.id else Books.BOOK
	-- as many rows as there are items (the bag can change while it is open: up to MAX_ROWS)
	local rows = math.clamp(math.ceil(#candidates(profile, sourceSlot) / COLS), 1, MAX_ROWS)
	local gridTop = 4 + SOURCE_H + 30
	local gridH = rows * SLOT + (rows - 1) * GAP
	local footTop = gridTop + gridH + 12
	local height = footTop + FOOT_H + 8
	local title = t(TITLES[sourceId] or "book_window_book")
	local win, content =
		createWindow(parent, title, UDim2.fromOffset(INNER_W + 12, height + 46), onClose)
	win.Name = "Window_Book"
	win.BackgroundTransparency = 0

	-- the held item
	local sourceCard =
		Ui.card(content, UDim2.fromOffset(GRID_W, SOURCE_H), UDim2.fromOffset(PAD, 4))
	local bigSlot, bigName, bigCount, bigImage = Ui.invSlot(sourceCard, 56)
	bigSlot.Position = UDim2.fromOffset(11, 11)
	local textX = 11 + 56 + 12
	local nameLabel =
		Ui.label(sourceCard, "", UDim2.new(1, -textX - 10, 0, 20), UDim2.fromOffset(textX, 9), 16)
	nameLabel.Font = Enum.Font.SourceSansBold
	nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
	local descLabel = Ui.label(
		sourceCard,
		"",
		UDim2.new(1, -textX - 10, 0, 28),
		UDim2.fromOffset(textX, 29),
		12,
		Ui.colors.muted
	)
	descLabel.TextWrapped = true
	descLabel.TextYAlignment = Enum.TextYAlignment.Top
	local chanceLabel = Ui.label(
		sourceCard,
		"",
		UDim2.new(1, -textX - 10, 0, 16),
		UDim2.fromOffset(textX, 56),
		13,
		Ui.colors.yellow
	)

	local pickCaption = Ui.label(
		content,
		"",
		UDim2.fromOffset(GRID_W, 18),
		UDim2.fromOffset(PAD, 4 + SOURCE_H + 8),
		12
	)
	pickCaption.TextColor3 = Ui.colors.muted
	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(GRID_W, gridH)
	grid.Position = UDim2.fromOffset(PAD, gridTop)
	grid.Parent = content

	-- the outcome line and the button
	local foot = Ui.card(content, UDim2.fromOffset(GRID_W, FOOT_H), UDim2.fromOffset(PAD, footTop))
	local info = Ui.label(foot, "", UDim2.new(1, -170, 1, -8), UDim2.fromOffset(12, 4), 13)
	info.TextWrapped = true
	local button = Ui.button(
		foot,
		t(ACTIONS[sourceId] or "book_action_apply"),
		UDim2.fromOffset(140, 36),
		UDim2.new(1, -150, 0, 9),
		ACTION_COLORS[sourceId]
	)
	button.Font = Enum.Font.SourceSansBold
	button.TextSize = 17
	local function setButton(active: boolean)
		button.Active = active
		button.AutoButtonColor = active
		button.BackgroundColor3 = if active
			then ACTION_COLORS[sourceId] or Ui.colors.buttonGreen
			else Ui.colors.buttonGrey
		button.TextColor3 = if active then Color3.new(1, 1, 1) else Ui.colors.muted
	end

	local current = profile
	local list: { Candidate } = {}
	local selected: Candidate? = nil
	local confirm = false
	local frames: { [Frame]: Candidate } = {}
	local hover: Frame? = nil
	local focus: Frame? = nil

	local function sameTarget(a: Candidate?, b: Candidate?): boolean
		return a ~= nil and b ~= nil and a.where == b.where and a.key == b.key
	end

	local function updateSource()
		local held = current.inventory[sourceSlot]
		if not held then
			return
		end
		SlotView.render(bigName, bigCount, bigImage, held)
		local book = held.id == Books.BOOK and held.books and held.books[1] or nil
		if book then
			local rarity = rarityOf(held) or "common"
			nameLabel.Text = ItemInfo.bookName(book.id, book.level, locale)
			nameLabel.TextColor3 = ItemInfo.RARITY_COLORS[rarity] or Ui.colors.text
			descLabel.Text = ItemInfo.bookDescription(book.id, book.level, locale) or ""
			chanceLabel.Text = t("tip_apply_chance", held.applyChance or 100)
		else
			nameLabel.Text = Strings.itemFullName(held.id, held.level, locale)
				.. (if held.count > 1 then "  ×" .. held.count else "")
			nameLabel.TextColor3 = Ui.colors.header
			descLabel.Text = if Strings.has("desc_" .. held.id, locale)
				then t("desc_" .. held.id)
				else ""
			chanceLabel.Text = ""
		end
		pickCaption.Text =
			t(if sourceId == Books.POWDER then "book_pick_book" else "book_pick_item")
	end

	local function updateInfo()
		local pick = selected
		if #list == 0 then
			info.Text = t("book_none_fit")
			info.TextColor3 = Ui.colors.muted
		elseif not pick then
			-- what the book fits (the caption above already asks to pick)
			local held = current.inventory[sourceSlot]
			local book = held and held.books and held.books[1]
			local card = book and Config.books.catalog[book.id]
			local names = {}
			for _, itemId in ipairs(card and card.items or {}) do
				table.insert(names, Strings.itemName(itemId, nil, locale))
			end
			info.Text = if #names > 0 then t("tip_book_targets", table.concat(names, ", ")) else ""
			info.TextColor3 = Ui.colors.muted
		elseif pick.refusal then
			info.Text = t(pick.refusal)
			info.TextColor3 = Ui.colors.red
		elseif sourceId == Books.POWDER then
			local chance = pick.stack.applyChance or 100
			info.Text = t("book_chance_now", chance, math.min(100, chance + Books.POWDER_STEP))
			info.TextColor3 = Ui.colors.green
		elseif confirm then
			info.Text = t("book_dispel_confirm")
			info.TextColor3 = Ui.colors.red
		else
			info.Text = Strings.itemFullName(pick.stack.id, pick.stack.level, locale)
				.. "\n"
				.. t("book_slots_line", #(pick.stack.books or {}), Books.limit(pick.stack.id))
			info.TextColor3 = Ui.colors.text
		end
		setButton(pick ~= nil and pick.refusal == nil)
	end

	local function rebuild()
		for frame in pairs(frames) do
			frame:Destroy()
		end
		table.clear(frames)
		hover, focus = nil, nil
		list = candidates(current, sourceSlot)
		local keep: Candidate? = nil
		for _, entry in ipairs(list) do
			if sameTarget(entry, selected) then
				keep = entry
			end
		end
		selected = keep
		for i, entry in ipairs(list) do
			if i > rows * COLS then
				break
			end
			local column, row = (i - 1) % COLS, (i - 1) // COLS
			local frame, name, count, image = Ui.invSlot(grid, SLOT)
			frame.Position = UDim2.fromOffset(column * (SLOT + GAP), row * (SLOT + GAP))
			SlotView.render(name, count, image, entry.stack)
			if entry.refusal then
				image.ImageTransparency = 0.65
				frame.BackgroundTransparency = 0.4
			end
			local rarity = if entry.stack.id == Books.BOOK then rarityOf(entry.stack) else nil
			if rarity then
				SlotView.rarityBar(frame, ItemInfo.RARITY_COLORS[rarity] or Ui.colors.muted)
			end
			if entry.where == "armor" then
				-- worn: a small dot in the corner (the tooltip says «Надето»)
				local dot = Instance.new("Frame")
				dot.Size = UDim2.fromOffset(6, 6)
				dot.Position = UDim2.fromOffset(4, 4)
				dot.BackgroundColor3 = Ui.colors.level
				dot.BorderSizePixel = 0
				dot.ZIndex = frame.ZIndex + 2
				local round = Instance.new("UICorner")
				round.CornerRadius = UDim.new(1, 0)
				round.Parent = dot
				dot.Parent = frame
			end
			local stroke = frame:FindFirstChildOfClass("UIStroke")
			if stroke and sameTarget(entry, selected) then
				stroke.Color = Ui.colors.slotSelected
				stroke.Thickness = 2
			end
			local pick = Instance.new("TextButton")
			pick.BackgroundTransparency = 1
			pick.Text = ""
			pick.Size = UDim2.fromScale(1, 1)
			pick.ZIndex = frame.ZIndex + 3
			pick.Parent = frame
			pick.Activated:Connect(function()
				if not sameTarget(selected, entry) then
					confirm = false
				end
				selected = entry
				rebuild()
			end)
			frames[frame] = entry
			frame.MouseEnter:Connect(function()
				hover = frame
			end)
			frame.MouseLeave:Connect(function()
				if hover == frame then
					hover = nil
				end
			end)
			frame.InputBegan:Connect(function(input: InputObject)
				if input.UserInputType == Enum.UserInputType.Touch then
					focus = frame
				end
			end)
		end
		updateSource()
		updateInfo()
	end

	button.Activated:Connect(function()
		local pick = selected
		if not pick or pick.refusal or not button.Active then
			return
		end
		if sourceId == Books.DISPELLER and not confirm then
			confirm = true
			updateInfo()
			return
		end
		confirm = false
		Remotes.event("BookUse"):FireServer(sourceSlot, pick.where, pick.key)
	end)

	local tip = RunService.RenderStepped:Connect(function()
		local at: Frame? = focus or hover
		local entry = if at then frames[at] else nil
		if not entry or not at then
			ItemTooltip.hide()
			return
		end
		local extra: { ItemInfo.Line } = {}
		if entry.where == "armor" then
			table.insert(extra, { text = t("book_worn"), color = Ui.colors.level })
		end
		if entry.refusal then
			table.insert(extra, { text = t(entry.refusal), color = Ui.colors.red })
		end
		local anchor: Vector2 | GuiObject = if focus
			then at
			else UserInputService:GetMouseLocation()
		ItemTooltip.show(entry.stack, anchor, extra)
	end)
	win.Destroying:Connect(function()
		tip:Disconnect()
		ItemTooltip.hide()
	end)

	rebuild()
	local function refresh(newProfile: Types.Profile)
		current = newProfile
		local held = current.inventory[sourceSlot]
		if not held or held.id ~= sourceId then
			onClose() -- used up (or moved away)
			return
		end
		rebuild()
	end
	return win, refresh
end

return BookWindow
