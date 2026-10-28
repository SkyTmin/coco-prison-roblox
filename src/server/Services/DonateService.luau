--!strict
-- The donate shop (shared/Donate, client DonateWindow [N]):
--   * DonateBuy(itemId, count): goods for crystals. The server checks the item, the count (1 … its limit), the
--     crystals, the room (inventory / booster storage / the 50 auction slots) and only then takes the crystals and
--     gives the goods in one profile mutation.
--   * DonateTopUp(packId): crystals for Robux — MarketplaceService prompts the pack's Developer Product; the money
--     arrives through ProcessReceipt. A receipt is granted once: its PurchaseId is noted in p.receipts together with
--     the crystals and the profile saved before Roblox hears «granted» (a failed save answers NotProcessedYet and
--     Roblox retries; the noted id stops a second grant). No product id yet (productId 0, the owner creates them with
--     scripts/create-dev-products.mjs): in Studio the pack is given for free to test, live the player is told it is
--     not set up.
--   * DonateBuyRobux(itemId) [владелец 28.10: «хочу, чтобы игрок мог покупать сами предметы. Даже за 10 роблакс»]:
--     one item straight for Robux through its own Developer Product, checked for room before the prompt; the receipt
--     gives it the same way.
--   * No room in the inventory [владелец 28.10: «когда в инвентаре нет мест … отправлять в хранилище, где бустеры, и
--     уведомление, что туда направлено; потом оттуда кнопка получить»]: whatever does not fit goes to p.stash, shown
--     in the storage window [B]; StashClaim(index) moves as much as fits back into the inventory. Bought boosters go to
--     the same storage and the toast says so. Only a full booster storage or the auction-slot limit can still refuse
--     a receipt that already came — then the item's price comes back in crystals, never nothing.
--   * Этап 8 (the «PRIS+» tab): pris_plus adds days to p.prisPlusUntil (PrisService publishes the attribute),
--     auction_no_fee sets p.noAuctionFee, rubies_100 adds p.rubies. Every purchase for crystals takes the rubies first
--     (Donate.pay), except rubies themselves; a crystal purchase is saved at once (SaveNow) like a receipt.
--   * auction_announce adds an announcement credit (p.announceCredits); it is sold from the auction's offer card
--     (AuctionService calls BuyRobux / BuyCrystals), not from a shop tab; OnBought tells AuctionService it came.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Donate = require(Shared.Donate)
local Remotes = require(Shared.Remotes)
local PrisPlus = require(Shared.PrisPlus)
local Strings = require(Shared.Strings)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

local DonateService = {}
local RECEIPTS_KEPT = 50
local lastAction: { [Player]: number } = {}
local boughtHooks: { (Player, string) -> () } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- a few requests a second at most
local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or 0) < 0.25 then
		return true
	end
	lastAction[player] = now
	return false
end

local function addCrystals(p: any, amount: number)
	p.crystals = (p.crystals or 0) + amount
end

-- why `count` of the item cannot be given to this profile now (a toast key), nil when it can
local function blocked(p: any, id: string, item: Donate.Item, count: number): string?
	if count < 1 or count > Donate.limit(p, id) then
		return "donate_limit"
	end
	if
		item.booster
		and Boosters.storedCount(p) + count * #item.booster.kinds > Config.boosters.maxStored
	then
		return "donate_storage_full"
	end
	return nil
end

-- items into the storage (the same id stacks)
local function stash(p: any, id: string, count: number)
	p.stash = p.stash or {}
	for _, entry in ipairs(p.stash) do
		if entry.id == id then
			entry.count += count
			return
		end
	end
	table.insert(p.stash, { id = id, count = count })
end

-- the goods into the profile (inside a mutation, after `blocked`); where they went: "inventory", "stash" (some or
-- all did not fit), "boosters" or "auction"
local function give(p: any, item: Donate.Item, count: number): string
	if item.give then
		local left = InventoryService.add(p, item.give, count * (item.each or 1))
		if left > 0 then
			stash(p, item.give, left)
			return "stash"
		end
		return "inventory"
	elseif item.booster then
		for _ = 1, count do
			for _, kind in ipairs(item.booster.kinds) do
				Boosters.store(p, kind, item.booster.scope, Donate.MULT, Donate.MINUTES)
			end
		end
	elseif item.prisDays then
		PrisPlus.extend(p, item.prisDays * count)
		return "pris"
	elseif item.noFee then
		p.noAuctionFee = true
		return "nofee"
	elseif item.rubies then
		p.rubies = Donate.rubies(p) + item.rubies * count
		return "rubies"
	elseif item.announce then
		p.announceCredits = (p.announceCredits or 0) + count
		return "announce"
	elseif item.auctionSlot then
		-- an item until used, so it can be sold at the Auction [владелец 28.10]
		local left = InventoryService.add(p, Donate.AUCTION_SLOT, count)
		if left > 0 then
			stash(p, Donate.AUCTION_SLOT, left)
			return "stash"
		end
		return "inventory"
	end
	return "boosters"
end

-- the toast after a purchase: what was bought and, when it is not in the inventory, where it went
local function bought(player: Player, id: string, count: number, place: string)
	local locale = Strings.localeOf(player)
	local text = Strings.t("donate_bought", locale, Donate.name(id, locale), count)
	if place == "stash" or place == "boosters" then
		text ..= ". " .. Strings.t("donate_to_" .. place, locale)
	end
	Remotes.event("Toast"):FireClient(player, text)
	Remotes.event("DonateBought"):FireClient(player, id, count)
	for _, hook in ipairs(boughtHooks) do
		task.spawn(hook, player, id)
	end
end

local function onBuy(player: Player, id: any, rawCount: any)
	local item = Donate.item(id)
	if not item or typeof(rawCount) ~= "number" or rawCount ~= rawCount or throttled(player) then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local count = math.floor(rawCount)
	local why = blocked(profile, id, item, count)
	if why then
		toast(player, why)
		return
	end
	local price = item.price * count
	if Donate.wallet(profile, id) < price then
		toast(player, "donate_not_enough", tostring(price - Donate.wallet(profile, id)))
		return
	end
	local place: string? = nil
	ProfileService.Mutate(player, function(p)
		-- checked again on the profile itself: nothing may change between the checks and the sale
		if Donate.wallet(p, id) < price or blocked(p, id, item, count) then
			return
		end
		Donate.pay(p, id, price) -- the rubies first
		place = give(p, item, count)
	end)
	if place then
		bought(player, id, count, place)
		task.spawn(ProfileService.SaveNow, player) -- the donate currency moved: keep it through a crash
	end
end

local function onTopUp(player: Player, packId: any)
	local pack = Donate.pack(packId)
	if not pack or throttled(player) then
		return
	end
	if pack.productId > 0 then
		MarketplaceService:PromptProductPurchase(player, pack.productId)
	elseif RunService:IsStudio() then
		ProfileService.Mutate(player, function(p)
			addCrystals(p, pack.crystals)
		end)
		toast(player, "donate_studio_free")
		Remotes.event("DonateCrystals"):FireClient(player, pack.crystals)
	else
		toast(player, "donate_no_product")
	end
end

-- one item straight for Robux: the room is checked before Roblox asks for the money
local function onBuyRobux(player: Player, id: any)
	local item = Donate.item(id)
	if not item or throttled(player) then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local why = blocked(profile, id, item, 1)
	if why then
		toast(player, why)
		return
	end
	if item.productId > 0 then
		MarketplaceService:PromptProductPurchase(player, item.productId)
	elseif RunService:IsStudio() then
		local place: string? = nil
		ProfileService.Mutate(player, function(p)
			if not blocked(p, id, item, 1) then
				place = give(p, item, 1)
			end
		end)
		if place then
			toast(player, "donate_studio_free_item")
			bought(player, id, 1, place)
		end
	else
		toast(player, "donate_no_product")
	end
end

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local pack, itemId = Donate.byProduct(info.ProductId)
	local item = if itemId then Donate.item(itemId) else nil
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and ProfileService.Get(player)
	if not pack and not item then
		warn("[DonateService] unknown product", info.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- the player left or the profile is not (properly) loaded: Roblox retries on their next join
	if not player or not profile or not ProfileService.IsReal(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = tostring(info.PurchaseId)
	if table.find(profile.receipts or {}, id) then
		-- given before (a retry): granted once it is surely saved
		return if ProfileService.SaveNow(player)
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	-- what the receipt gave: the pack's crystals, the item, or (no room for the item) its price in crystals
	local crystals, place: string? = 0, nil
	ProfileService.Mutate(player, function(p)
		if pack then
			crystals = pack.crystals
		elseif item and itemId and not blocked(p, itemId, item, 1) then
			place = give(p, item, 1)
		elseif item then
			crystals = item.price
		end
		addCrystals(p, crystals)
		local receipts = p.receipts or {}
		table.insert(receipts, id)
		while #receipts > RECEIPTS_KEPT do
			table.remove(receipts, 1)
		end
		p.receipts = receipts
	end)
	if not ProfileService.SaveNow(player) then
		-- kept in memory with its id: a retry on this server sees the id; a lost server loses both and is retried
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if place and itemId then
		bought(player, itemId, 1, place)
	else
		toast(player, if item then "donate_refund_crystals" else "donate_crystals_added", crystals)
		Remotes.event("DonateCrystals"):FireClient(player, crystals)
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- a stored item back into the inventory: as much as fits
local function onClaim(player: Player, index: any)
	if typeof(index) ~= "number" or throttled(player) then
		return
	end
	local found, moved, left = false, 0, 0
	ProfileService.Mutate(player, function(p)
		local entry = p.stash and p.stash[index]
		if not entry then
			return
		end
		found = true
		left = InventoryService.add(p, entry.id, entry.count)
		moved = entry.count - left
		if left > 0 then
			entry.count = left
		else
			table.remove(p.stash, index)
		end
	end)
	if not found then
		return
	elseif moved == 0 then
		toast(player, "donate_no_room")
	elseif left > 0 then
		toast(player, "donate_claimed_part", moved, left)
	end
end

-- a donate booster (×Donate.MULT, Donate.MINUTES) out of the storage as an inventory item, for the Auction or a friend
-- [владелец 28.10: «всё, что можно купить в донат-магазине, можно выставлять на аукционе»]
local function onBoosterToItem(player: Player, index: any)
	if typeof(index) ~= "number" or throttled(player) then
		return
	end
	local result = ""
	ProfileService.Mutate(player, function(p)
		local stored = p.boosters and p.boosters[index]
		if not stored or stored.mult ~= Donate.MULT or stored.minutes ~= Donate.MINUTES then
			return
		end
		local id = Boosters.itemId(stored.kind, stored.scope)
		if not InventoryService.canAdd(p, id, 1) then
			result = "donate_no_room"
			return
		end
		local taken = Boosters.take(p, index)
		if taken then
			InventoryService.add(p, id, 1)
			result = "booster_to_item_done"
		end
	end)
	if result ~= "" then
		toast(player, result)
	end
end

-- fn(player, itemId) after every purchase that gave the item (crystals, a Robux receipt, the free Studio test)
function DonateService.OnBought(fn: (Player, string) -> ())
	table.insert(boughtHooks, fn)
end

-- the same purchases from another service (the auction's announcement card)
function DonateService.BuyCrystals(player: Player, id: string, count: number)
	onBuy(player, id, count)
end

function DonateService.BuyRobux(player: Player, id: string)
	onBuyRobux(player, id)
end

function DonateService.Start()
	Remotes.event("BoosterToItem").OnServerEvent:Connect(onBoosterToItem)
	Remotes.event("DonateBuy").OnServerEvent:Connect(onBuy)
	Remotes.event("DonateTopUp").OnServerEvent:Connect(onTopUp)
	Remotes.event("DonateBuyRobux").OnServerEvent:Connect(onBuyRobux)
	Remotes.event("StashClaim").OnServerEvent:Connect(onClaim)
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return DonateService
