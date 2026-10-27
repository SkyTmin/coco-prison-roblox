--!strict
-- The donate shop (shared/Donate, client DonateWindow [N]):
--   * DonateBuy(itemId, count): goods for crystals. The server checks the item, the count (1 … its limit), the
--     crystals, the room (inventory / booster storage / the 50 auction slots) and only then takes the crystals and
--     gives the goods in one profile mutation.
--   * DonateTopUp(packId): crystals for Robux — MarketplaceService prompts the pack's Developer Product; the money
--     arrives through ProcessReceipt. A receipt is granted once: its PurchaseId is noted in p.receipts together with
--     the crystals and the profile saved before Roblox hears «granted» (a failed save answers NotProcessedYet and
--     Roblox retries; the noted id stops a second grant). No product id yet (productId 0, the owner creates them in
--     the Creator Dashboard): in Studio the pack is given for free to test, live the player is told it is not set up.
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Donate = require(Shared.Donate)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

local DonateService = {}
local RECEIPTS_KEPT = 50
local lastAction: { [Player]: number } = {}

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
	if count < 1 or count > Donate.limit(profile, id) then
		toast(player, "donate_limit")
		return
	end
	local price = item.price * count
	if Donate.crystals(profile) < price then
		toast(player, "donate_not_enough", tostring(price - Donate.crystals(profile)))
		return
	end
	local amount = count * (item.each or 1)
	if item.give and not InventoryService.canAdd(profile, item.give, amount) then
		toast(player, "donate_no_room")
		return
	end
	if
		item.booster
		and Boosters.storedCount(profile) + count * #item.booster.kinds
			> Config.boosters.maxStored
	then
		toast(player, "donate_storage_full")
		return
	end
	local done = false
	ProfileService.Mutate(player, function(p)
		-- checked again on the profile itself: nothing may change between the checks and the sale
		if Donate.crystals(p) < price then
			return
		end
		p.crystals = Donate.crystals(p) - price
		if item.give then
			InventoryService.add(p, item.give, amount)
		elseif item.booster then
			for _ = 1, count do
				for _, kind in ipairs(item.booster.kinds) do
					Boosters.store(p, kind, item.booster.scope, Donate.MULT, Donate.MINUTES)
				end
			end
		elseif item.auctionSlot then
			p.auctionSlots = (p.auctionSlots or 0) + count
		end
		done = true
	end)
	if done then
		toast(player, "donate_bought", Donate.name(id, Strings.localeOf(player)), count)
		Remotes.event("DonateBought"):FireClient(player, id, count)
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

local function processReceipt(info: any): Enum.ProductPurchaseDecision
	local pack: Donate.Pack? = nil
	for _, p in ipairs(Donate.packs) do
		if p.productId > 0 and p.productId == info.ProductId then
			pack = p
		end
	end
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local profile = player and ProfileService.Get(player)
	if not pack then
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
	local crystals = pack.crystals
	ProfileService.Mutate(player, function(p)
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
	toast(player, "donate_crystals_added", crystals)
	Remotes.event("DonateCrystals"):FireClient(player, crystals)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function DonateService.Start()
	Remotes.event("DonateBuy").OnServerEvent:Connect(onBuy)
	Remotes.event("DonateTopUp").OnServerEvent:Connect(onTopUp)
	MarketplaceService.ProcessReceipt = processReceipt
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return DonateService
