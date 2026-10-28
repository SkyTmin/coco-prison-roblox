--!strict
-- Auction rules shared by AuctionService and AuctionWindow [вики MENUS-SOCIAL «Аукцион /ah»]: lot categories (the
-- type filter Все / Оружие / Броня / Инструменты / Зачарования, plus Прочее), what may be sold, the commission.
-- Этап 8: a lot costs money or rubies [клиент advice.3] (cur = "rubies": price in whole rubies, otherwise in
-- 1/moneyScale units); the commission is 0 with PRIS+ or the «Удаление комиссии» purchase (Shared/PrisPlus), and the
-- rate the seller had when listing is kept on the lot (fee): the lower of it and his rate at the sale is charged.
local Config = require(script.Parent.Config)
local Strings = require(script.Parent.Strings)

export type Summary = {
	id: string,
	item: any, -- ItemStack
	price: number, -- 1/moneyScale units, or whole rubies when cur = "rubies"
	cur: string?, -- "rubies"; nil = money
	fee: number?, -- the seller's commission rate when he listed it; nil = cfg.commission
	seller: number,
	sellerName: string,
	createdAt: number, -- os.time()
	expiresAt: number,
}

local Auction = {}
local cfg = Config.auction
Auction.cfg = cfg
Auction.CATEGORIES = { "all", "weapons", "armor", "tools", "enchant", "other" }
Auction.RUBIES = "rubies"
Auction.CURRENCIES = { "money", "rubies" }

local categoryOf: { [string]: string } = {}
for category, ids in pairs(cfg.categories) do
	for _, id in ipairs(ids) do
		categoryOf[id] = category
	end
end

function Auction.category(itemId: string): string
	return categoryOf[itemId] or "other"
end

function Auction.tradable(stack: any): boolean
	return typeof(stack) == "table"
		and typeof(stack.id) == "string"
		and stack.coins == nil
		and not table.find(cfg.notTradable, stack.id)
end

-- what the seller gets for a sale at `price`: the price minus the commission (rate, default the config's), rounded
-- down in the house's favour
function Auction.net(price: number, rate: number?): number
	return price - math.ceil(price * (rate or cfg.commission) - 1e-9)
end

function Auction.isRubies(lot: any): boolean
	return typeof(lot) == "table" and lot.cur == Auction.RUBIES
end

-- the lot's price for people: «1 234,5$» or «120 руб.»
function Auction.priceText(lot: any, amount: number?, locale: string?): string
	local value = amount or lot.price
	if Auction.isRubies(lot) then
		return Strings.t("rubies_short", locale, Strings.big(value))
	end
	return Strings.money(value) .. "$"
end

-- «6д 21ч 12м» / «12м 08с» (locale-free numbers; the words come from Strings)
function Auction.timeLeft(seconds: number): (number, number, number, number)
	local s = math.max(0, math.floor(seconds))
	return s // 86400, (s % 86400) // 3600, (s % 3600) // 60, s % 60
end

return Auction
