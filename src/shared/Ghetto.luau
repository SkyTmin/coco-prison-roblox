--!strict
-- The Гетто rules both the server (GhettoService decides) and the client (the trader / black market windows) read
-- [вики LOCATIONS-MENU, HANDBOOK-WIKI; клиент blackmarket.*, gang.ghetto.*; docs/research/remaining-features-design.md
-- этап 1в]. Numbers: Config.ghetto (scripts/design-decisions.json → ghetto).
--   * Торговец: ordinary keys and ancient stars for $ (fixed prices);
--   * Чёрный рынок (from minLevel): 6 goods, a stock per server refilled every restockMinutes; the price grows with the
--     buyer's level: price × (1 + levelStep × (level − minLevel)). The server mirrors the stock in
--     ReplicatedStorage.BlackMarket (attributes <id> = pieces left, RestockAt = server time of the next refill).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(script.Parent.Config)

export type Offer = { id: string, price: number } -- price in $
export type BlackItem = { id: string, price: number, stock: { number } }

local Ghetto = {}
local cfg = Config.ghetto
Ghetto.cfg = cfg
Ghetto.STOCK_FOLDER = "BlackMarket"
Ghetto.TRADER_ORDER = { "ordinary_key", "ancient_star" }

-- the trader's goods in the window order (keys starting with _ are notes)
function Ghetto.traderOffers(): { Offer }
	local out: { Offer } = {}
	for _, id in ipairs(Ghetto.TRADER_ORDER) do
		local price = cfg.trader[id]
		if typeof(price) == "number" then
			table.insert(out, { id = id, price = price })
		end
	end
	for id, price in pairs(cfg.trader) do
		if
			typeof(price) == "number"
			and string.sub(id, 1, 1) ~= "_"
			and not table.find(Ghetto.TRADER_ORDER, id)
		then
			table.insert(out, { id = id, price = price })
		end
	end
	return out
end

function Ghetto.traderPrice(id: any): number?
	if typeof(id) ~= "string" or string.sub(id, 1, 1) == "_" then
		return nil
	end
	local price = cfg.trader[id]
	return if typeof(price) == "number" then price else nil
end

function Ghetto.blackItems(): { BlackItem }
	return cfg.blackMarket.items :: { BlackItem }
end

function Ghetto.blackItem(id: any): BlackItem?
	for _, item in ipairs(Ghetto.blackItems()) do
		if item.id == id then
			return item
		end
	end
	return nil
end

-- the black market price in $ for a buyer of this level [решение]
function Ghetto.blackPrice(item: BlackItem, level: number): number
	local bm = cfg.blackMarket
	local k = 1 + bm.levelStep * math.max(0, level - bm.minLevel)
	return math.floor(item.price * k + 0.5)
end

-- pieces left on this server (client: the mirrored attributes; 0 before the server filled them)
function Ghetto.stock(id: string): number
	local folder = ReplicatedStorage:FindFirstChild(Ghetto.STOCK_FOLDER)
	local value = folder and folder:GetAttribute(id)
	return if typeof(value) == "number" then value else 0
end

function Ghetto.restockAt(): number
	local folder = ReplicatedStorage:FindFirstChild(Ghetto.STOCK_FOLDER)
	local value = folder and folder:GetAttribute("RestockAt")
	return if typeof(value) == "number" then value else 0
end

return Ghetto
