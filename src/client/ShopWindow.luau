--!strict
-- "Продавец еды" / "Продавец предметов" windows of the original (NPC-MENU-RECOVERY npc-02 / npc-10):
-- orange title in the strip, red ✕, one dark card per offer with a big pixel icon, an inset
-- "Цена » 0.03$" line (white / grey » / green value with $) and a green "Приобрести" button.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Ui = require(script.Parent.Ui)

type CreateWindow = (Instance, string, UDim2, () -> ()) -> (Frame, Frame)
type Offer = { id: string, price: number }
local ShopWindow = {}

-- [меню] NPC-MENU-RECOVERY: food 0.03 / 0.25 / 0.5 $, items 4 / 22.5 / 4000 / 4 $
local OFFERS: { [string]: { Offer } } = {
	food = {
		{ id = "apple", price = 0.03 },
		{ id = "bread", price = 0.25 },
		{ id = "cooked_chicken", price = 0.5 },
	},
	shop = {
		{ id = "axe", price = 4 },
		{ id = "pickaxe", price = 22.5 },
		{ id = "shears", price = 4000 },
		{ id = "shovel", price = 4 },
	},
}
local CARD_W, CARD_H, GAP = 220, 268, 10

-- Prices like the original cards: 0.03$, 22.5$, 4,000$ (no trailing zeros, thousands grouped).
local function priceText(price: number): string
	if price >= 1000 then
		local whole = tostring(math.floor(price + 0.5))
		local grouped = string.reverse((string.gsub(string.reverse(whole), "(%d%d%d)", "%1,")))
		return (string.gsub(grouped, "^,", ""))
	end
	local text = string.format("%.3f", price)
	return (string.gsub((string.gsub(text, "0+$", "")), "%.$", ""))
end

function ShopWindow.build(
	parent: Instance,
	kind: string,
	profile: Types.Profile?,
	locale: string,
	onClose: () -> (),
	createWindow: CreateWindow
): (Frame, (Types.Profile?) -> ())
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local offers = OFFERS[kind] or OFFERS.food
	local win, content = createWindow(
		parent,
		t(if kind == "food" then "food_prompt" else "shop_prompt"),
		UDim2.fromOffset(#offers * (CARD_W + GAP) + 10, CARD_H + 56),
		onClose
	)
	Ui.titleColor(win, Ui.colors.header)
	local buttons: { { button: TextButton, price: number } } = {}
	for index, offer in ipairs(offers) do
		local card = Ui.card(
			content,
			UDim2.fromOffset(CARD_W, CARD_H),
			UDim2.fromOffset((index - 1) * (CARD_W + GAP) + 4, 4)
		)
		local icon = Instance.new("ImageLabel")
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Size = UDim2.fromOffset(112, 112)
		icon.Position = UDim2.new(0.5, 0, 0, 44)
		icon.BackgroundTransparency = 1
		icon.ScaleType = Enum.ScaleType.Fit
		icon.ResampleMode = Enum.ResamplerMode.Pixelated
		icon.Image = Config.iconFor(offer.id, if Config.tools[offer.id] then 1 else nil) or ""
		icon.Parent = card
		-- the item's name over the picture (the cards had only a picture)
		local name = Ui.label(
			card,
			Strings.itemName(offer.id, if Config.tools[offer.id] then 1 else nil, locale),
			UDim2.new(1, -16, 0, 22),
			UDim2.fromOffset(8, 12),
			16,
			Ui.colors.header
		)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local priceBox = Ui.inset(card, UDim2.new(1, -24, 0, 34), UDim2.new(0, 12, 1, -92))
		local price = Ui.rich(
			priceBox,
			string.format(
				'%s <font color="%s">»</font> <font color="%s">%s$</font>',
				t("price"),
				Ui.hex(Ui.colors.muted),
				Ui.hex(Ui.colors.money),
				priceText(offer.price)
			),
			UDim2.new(1, -8, 1, 0),
			UDim2.fromOffset(4, 0),
			16
		)
		price.TextXAlignment = Enum.TextXAlignment.Center
		local buy = Ui.button(
			card,
			t("buy"),
			UDim2.new(1, -24, 0, 38),
			UDim2.new(0, 12, 1, -50),
			Ui.colors.buttonGreen
		)
		buy.TextSize = 17
		buy.Activated:Connect(function()
			Remotes.event("BuyItem"):FireServer(offer.id)
		end)
		table.insert(buttons, { button = buy, price = offer.price })
	end
	local function refresh(p: Types.Profile?)
		profile = p
		for _, entry in ipairs(buttons) do
			local affordable = p ~= nil
				and p.coins >= math.floor(entry.price * Config.moneyScale + 0.5)
			entry.button.BackgroundColor3 = if affordable
				then Ui.colors.buttonGreen
				else Ui.colors.buttonGrey
		end
	end
	refresh(profile)
	return win, refresh
end

return ShopWindow
