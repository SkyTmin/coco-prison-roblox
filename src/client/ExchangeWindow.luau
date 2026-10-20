--!strict
-- Star / shard exchanger windows of the original (NPC-MENU-RECOVERY npc-03 / npc-09): a dark card per
-- offer with blue "−" / "+" quantity buttons around the item icon, "Стоимость » <icon>10" and a blue
-- "Обменять" button; under the cards an "Инвентарь" panel with the 9×4 inventory grid.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Strings = require(Shared.Strings)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
local ExchangeWindow = {}

local CARD_W, CARD_H, GAP = 196, 214, 10
local SLOT = 44

local function itemCount(profile: Types.Profile?, id: string): number
	local count = 0
	if profile then
		for _, stack in pairs(profile.inventory) do
			if stack.id == id then
				count += stack.count
			end
		end
	end
	return count
end

function ExchangeWindow.build(
	parent: Instance,
	kind: string,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local offers = if kind == "stars"
		then Config.market.starExchange
		else Config.market.shardExchange
	-- card order of the original screens [меню]: ancient key, improved key, dispeller / blade, stone
	local ORDER = {
		stars = { "ancient_key", "improved_ancient_key", "dispeller" },
		shards = { "moon_blade", "volcanic_stone" },
	}
	local ids: { string } = {}
	for _, id in ipairs(ORDER[kind] or {}) do
		if offers[id] then
			table.insert(ids, id)
		end
	end
	for id in pairs(offers) do
		if not table.find(ids, id) then
			table.insert(ids, id)
		end
	end
	local invWidth = 9 * (SLOT + 4) + 16
	local width = math.max(#ids * (CARD_W + GAP) + 10, invWidth + 8)
	local invY = CARD_H + 14
	local win, content = createWindow(
		parent,
		Strings.t("exchange_" .. kind, locale),
		UDim2.fromOffset(width, invY + 4 * (SLOT + 4) + 44 + 46),
		onClose
	)
	Ui.titleColor(win, Ui.colors.header)
	local updates: { (Types.Profile?) -> () } = {}
	for index, id in ipairs(ids) do
		local offer = offers[id]
		local input = if kind == "stars" then "ancient_star" else offer.input
		local cost: number = if kind == "stars" then offer else offer.count
		local quantity = 1
		local card = Ui.panel(
			content,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset((index - 1) * (CARD_W + GAP) + 4, 4)
		)
		local minus = Ui.button(card, "−", UDim2.fromOffset(36, 36), UDim2.fromOffset(14, 14))
		local plus = Ui.button(card, "+", UDim2.fromOffset(36, 36), UDim2.new(1, -50, 0, 14))
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Size = UDim2.fromOffset(64, 64)
		icon.Position = UDim2.new(0.5, 0, 0, 10)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.iconFor(id) or ""
		icon.Parent = card
		local qty = Ui.label(
			card,
			"",
			UDim2.new(1, -16, 0, 18),
			UDim2.fromOffset(8, 76),
			13,
			Ui.colors.muted
		)
		qty.TextXAlignment = Enum.TextXAlignment.Center
		local line = Instance.new("Frame")
		line.Size = UDim2.new(1, -24, 0, 1)
		line.Position = UDim2.fromOffset(12, 100)
		line.BackgroundColor3 = Ui.colors.border
		line.BorderSizePixel = 0
		line.Parent = card
		local costLabel = Ui.rich(card, "", UDim2.new(1, -56, 0, 24), UDim2.fromOffset(12, 108), 14)
		local costIcon = Instance.new("ImageLabel")
		costIcon.Size = UDim2.fromOffset(22, 22)
		costIcon.Position = UDim2.new(1, -54, 0, 109)
		costIcon.BackgroundTransparency = 1
		costIcon.ScaleType = Enum.ScaleType.Fit
		costIcon.ResampleMode = Enum.ResamplerMode.Pixelated
		costIcon.Image = Config.iconFor(input) or ""
		costIcon.Parent = card
		local costValue =
			Ui.label(card, "", UDim2.fromOffset(40, 24), UDim2.new(1, -32, 0, 108), 14)
		local button = Ui.button(
			card,
			Strings.t("exchange", locale),
			UDim2.new(1, -24, 0, 38),
			UDim2.new(0, 12, 1, -50)
		)
		local function update(p: Types.Profile?)
			local have = itemCount(p, input)
			local need = cost * quantity
			qty.Text = string.format("×%d", quantity)
			costLabel.Text = string.format(
				'%s <font color="%s">»</font>',
				Strings.t("cost", locale),
				Ui.hex(Ui.colors.muted)
			)
			costValue.Text = tostring(need)
			costValue.TextColor3 = if have >= need then Ui.colors.text else Ui.colors.red
			local ok = p ~= nil and have >= need
			button.BackgroundColor3 = if ok then Ui.colors.buttonBlue else Ui.colors.buttonGrey
			button.Interactable = ok
		end
		minus.Activated:Connect(function()
			quantity = math.max(1, quantity - 1)
			update(profile)
		end)
		plus.Activated:Connect(function()
			quantity = math.min(64, quantity + 1)
			update(profile)
		end)
		button.Activated:Connect(function()
			Remotes.event("Exchange"):FireServer(kind, id, quantity)
		end)
		table.insert(updates, update)
	end
	-- inventory panel (read-only, like the original's exchanger screens)
	local inv = Ui.panel(
		content,
		UDim2.fromOffset(invWidth, 4 * (SLOT + 4) + 40),
		UDim2.fromOffset(4, invY)
	)
	Ui.label(
		inv,
		Strings.t("inventory", locale),
		UDim2.new(1, -16, 0, 24),
		UDim2.fromOffset(8, 4),
		14,
		Ui.colors.muted
	)
	local views: { { index: number, name: TextLabel, count: TextLabel, icon: ImageLabel } } = {}
	local function slotAt(index: number, column: number, row: number)
		local frame, name, count, icon = Ui.slot(inv, SLOT)
		frame.Position = UDim2.fromOffset(8 + column * (SLOT + 4), 30 + row * (SLOT + 4))
		table.insert(views, { index = index, name = name, count = count, icon = icon })
	end
	for row = 0, 2 do
		for column = 0, 8 do
			slotAt(10 + row * 9 + column, column, row)
		end
	end
	for column = 0, 8 do
		slotAt(column + 1, column, 3)
	end
	local function refresh(p: Types.Profile?)
		profile = p
		for _, update in ipairs(updates) do
			update(p)
		end
		for _, view in ipairs(views) do
			local stack = if p then p.inventory[view.index] else nil
			local image = if stack then Config.iconFor(stack.id, stack.level) else nil
			view.icon.Image, view.icon.Visible = image or "", image ~= nil
			view.name.Text = if stack and not image
				then Strings.itemName(stack.id, stack.level, locale)
				else ""
			view.count.Text = if stack and stack.count > 1 then tostring(stack.count) else ""
		end
	end
	refresh(profile)
	return win, refresh
end

return ExchangeWindow
