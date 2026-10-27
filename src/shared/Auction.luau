--!strict
-- Auction rules shared by AuctionService and AuctionWindow [вики MENUS-SOCIAL «Аукцион /ah»]: lot categories (the
-- type filter Все / Оружие / Броня / Инструменты / Зачарования, plus Прочее), what may be sold, the commission.
local Config = require(script.Parent.Config)

export type Summary = {
	id: string,
	item: any, -- ItemStack
	price: number, -- 1/moneyScale units
	seller: number,
	sellerName: string,
	createdAt: number, -- os.time()
	expiresAt: number,
}

local Auction = {}
local cfg = Config.auction
Auction.cfg = cfg
Auction.CATEGORIES = { "all", "weapons", "armor", "tools", "enchant", "other" }

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

-- what the seller gets for a sale at `price` (units): the price minus the commission, rounded down in the house's favour
function Auction.net(price: number): number
	return price - math.ceil(price * cfg.commission)
end

-- «6д 21ч 12м» / «12м 08с» (locale-free numbers; the words come from Strings)
function Auction.timeLeft(seconds: number): (number, number, number, number)
	local s = math.max(0, math.floor(seconds))
	return s // 86400, (s % 86400) // 3600, (s % 3600) // 60, s % 60
end

return Auction
