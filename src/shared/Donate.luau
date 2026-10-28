--!strict
-- The donate shop's goods [меню 26.10, wiki/in-game-wiki/DONATE-SHOP-BOOSTERS.md; владелец 27.10: «переходи к донат
-- меню»]: prices in crystals (the shop currency, p.crystals), crystals bought in packs for Robux (DonateService).
-- An item gives inventory items (give × each), boosters into the storage (booster: kinds × ×2 for 30 minutes) or an
-- auction slot. Server and client read the same rules: the price of N, how many may still be bought, the name, the
-- description, the picture.
-- Этап 8 (the «PRIS+» tab): pris_plus adds prisDays of PRIS+ (Shared/PrisPlus), auction_no_fee removes the auction
-- commission for good, rubies_100 gives rubies. Rubies are spent before the crystals on every purchase here [вики
-- DONATE-SHOP-BOOSTERS: «при покупке доната тратятся первыми»] — except on rubies themselves, bought with crystals.
local Config = require(script.Parent.Config)
local Strings = require(script.Parent.Strings)

export type Item = {
	price: number,
	give: string?,
	each: number?,
	booster: { kinds: { string }, scope: string }?,
	auctionSlot: boolean?,
	prisDays: number?, -- PRIS+ for this many days
	noFee: boolean?, -- «Удаление комиссии на Аукционе», for good
	rubies: number?, -- this many rubies
	announce: boolean?, -- one paid auction announcement (a credit, AuctionService)
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

function Donate.rubies(p: any): number
	return if p then p.rubies or 0 else 0
end

-- what can pay for this item: the crystals and (unless it is rubies) the rubies
function Donate.wallet(p: any, id: string?): number
	local item = Donate.item(id)
	if item and item.rubies then
		return Donate.crystals(p)
	end
	return Donate.crystals(p) + Donate.rubies(p)
end

-- inside a profile mutation, after checking Donate.wallet: rubies first, then crystals; → the rubies spent
function Donate.pay(p: any, id: string?, price: number): number
	local item = Donate.item(id)
	local fromRubies = if item and item.rubies then 0 else math.min(Donate.rubies(p), price)
	if fromRubies > 0 then
		p.rubies = Donate.rubies(p) - fromRubies
		if p.rubies <= 0 then
			p.rubies = nil
		end
	end
	p.crystals = Donate.crystals(p) - (price - fromRubies)
	return fromRubies
end

-- how many of an item one purchase may take at most (an auction slot: what is left of the 50)
function Donate.limit(p: any, id: string): number
	local item = Donate.item(id)
	if not item then
		return 0
	end
	if item.auctionSlot then
		return math.max(0, item.max - (if p then p.auctionSlots or 0 else 0))
	elseif item.noFee then
		return if p and p.noAuctionFee then 0 else 1
	end
	return item.max
end

-- the pictures of the PRIS+ tab until our Blender icons are uploaded (assets/icons/pending-upload.txt)
local ICON_UNTIL_UPLOADED: { [string]: string } = {
	menu_pris = "top_crown",
	ruby = "crystal",
	auction_no_fee = "auction_slot",
}

-- the picture: its own icon (boosters, packs of the shop) or the item's
function Donate.icon(id: string): string?
	local item = Donate.item(id)
	if not item then
		return nil
	end
	local icons = Config.icons.icons
	local name = item.icon or item.give or id
	return icons[name] or icons[ICON_UNTIL_UPLOADED[name] or ""]
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
	elseif item.prisDays then
		return t("donate_pris_name", item.prisDays)
	elseif item.noFee then
		return t("donate_nofee_name")
	elseif item.rubies then
		return t("donate_rubies_name", item.rubies)
	elseif item.announce then
		return t("donate_announce_name")
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
	elseif item.prisDays then
		return t("donate_desc_pris", item.prisDays)
	elseif item.noFee then
		return t("donate_desc_nofee")
	elseif item.rubies then
		return t("donate_desc_rubies", item.rubies)
	elseif item.announce then
		return t("donate_desc_announce")
	elseif item.give and (item.each or 1) > 1 then
		return t("donate_desc_stars", item.each or 1)
	elseif item.give then
		local key = "desc_" .. item.give
		local text = t(key)
		return if text ~= key then text else ""
	end
	return ""
end

-- the auto-sell item [владелец 28.10]: used from the hand, it switches the profile's auto-sell on for good
Donate.AUTOSELL = "autosell"
-- the extra auction slot: an item too (it can be sold at the Auction), used from the hand → +1 slot
Donate.AUCTION_SLOT = "auction_slot"

return Donate
