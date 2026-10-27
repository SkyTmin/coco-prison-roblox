--!strict
-- The donate shop's goods [меню 26.10, wiki/in-game-wiki/DONATE-SHOP-BOOSTERS.md; владелец 27.10: «переходи к донат
-- меню»]: prices in crystals (the shop currency, p.crystals), crystals bought in packs for Robux (DonateService).
-- An item gives inventory items (give × each), boosters into the storage (booster: kinds × ×2 for 30 minutes) or an
-- auction slot. Server and client read the same rules: the price of N, how many may still be bought, the name, the
-- description, the picture.
local Config = require(script.Parent.Config)
local Strings = require(script.Parent.Strings)

export type Item = {
	price: number,
	give: string?,
	each: number?,
	booster: { kinds: { string }, scope: string }?,
	auctionSlot: boolean?,
	max: number,
	icon: string?,
	robux: number, -- the same item straight for Robux, one per purchase (its own Developer Product)
	productId: number,
}
export type Pack = {
	id: string,
	crystals: number,
	robux: number,
	productId: number,
	icon: string,
	bonus: number?,
}

local Donate = {}
local cfg = Config.donate

Donate.tabs = cfg.tabs :: { { id: string, items: { string }? } }
Donate.packs = cfg.packs :: { Pack }
Donate.MULT = cfg.boosterMultiplier :: number
Donate.MINUTES = cfg.boosterMinutes :: number

function Donate.item(id: any): Item?
	if typeof(id) ~= "string" then
		return nil
	end
	return (cfg.items :: any)[id]
end

function Donate.pack(id: any): Pack?
	for _, pack in ipairs(Donate.packs) do
		if pack.id == id then
			return pack
		end
	end
	return nil
end

-- what a Developer Product sells: a crystal pack or one item
function Donate.byProduct(productId: number): (Pack?, string?)
	if productId <= 0 then
		return nil, nil
	end
	for _, pack in ipairs(Donate.packs) do
		if pack.productId == productId then
			return pack, nil
		end
	end
	for id, item in pairs(cfg.items :: { [string]: Item }) do
		if item.productId == productId then
			return nil, id
		end
	end
	return nil, nil
end

function Donate.crystals(p: any): number
	return if p then p.crystals or 0 else 0
end

-- how many of an item one purchase may take at most (an auction slot: what is left of the 50)
function Donate.limit(p: any, id: string): number
	local item = Donate.item(id)
	if not item then
		return 0
	end
	if item.auctionSlot then
		return math.max(0, item.max - (if p then p.auctionSlots or 0 else 0))
	end
	return item.max
end

-- the picture: its own icon (boosters, packs of the shop) or the item's
function Donate.icon(id: string): string?
	local item = Donate.item(id)
	if not item then
		return nil
	end
	local icons = Config.icons.icons
	return icons[item.icon or item.give or id]
end

function Donate.name(id: string, locale: string?): string
	local item = Donate.item(id)
	if not item then
		return id
	end
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	if item.booster then
		local scope = t("booster_scope_" .. item.booster.scope)
		if #item.booster.kinds > 1 then
			return t("donate_set_name", scope)
		end
		return t("donate_booster_name", scope, t("donate_kind_" .. item.booster.kinds[1]))
	elseif item.auctionSlot then
		return t("donate_slot_name")
	elseif item.give and (item.each or 1) > 1 then
		return t("donate_star_set_name")
	elseif item.give then
		return Strings.itemName(item.give, nil, locale)
	end
	return id
end

function Donate.description(id: string, locale: string?): string
	local item = Donate.item(id)
	if not item then
		return ""
	end
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	if item.booster then
		local on = t("donate_on_" .. item.booster.scope)
		if #item.booster.kinds > 1 then
			return t("donate_desc_set", Donate.MINUTES, on)
		end
		return t(
			"donate_desc_booster",
			t("donate_when_" .. item.booster.kinds[1]),
			on,
			Donate.MINUTES
		)
	elseif item.auctionSlot then
		return t("donate_desc_slot")
	elseif item.give and (item.each or 1) > 1 then
		return t("donate_desc_stars", item.each or 1)
	elseif item.give then
		local key = "desc_" .. item.give
		local text = t(key)
		return if text ~= key then text else ""
	end
	return ""
end

return Donate
