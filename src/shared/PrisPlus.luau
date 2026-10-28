--!strict
-- PRIS+ and the rubies (этап 8; docs/research/remaining-features-design.md, facts §8), the rules server and client
-- share. PRIS+ [клиент donate.list.subscribe.description, prison_plus.*] is a donate-shop good (pris_plus, 299 кр.
-- [решение]): each one adds Config.pris.days to p.prisPlusUntil (os.time()), so a repeated purchase extends it. It gives
-- the auto-dig, the [PRIS+] chat prefix, 10 auction slots and 0 % commission, the /pp menu (night, AppleSkin, the mine
-- and boss respawn boards), another player's /stats and the enchant particles. The server publishes the state as the
-- player attribute PrisPlus (true / nil) for the other clients (chat prefix, particles); a player's own client reads
-- his profile. Rubies (p.rubies) [вики DONATE-SHOP-BOOSTERS]: 1 ruby = 1 crystal, bought for crystals, spent before the
-- crystals on any donate purchase, an auction currency, sent with /rubb.
local Config = require(script.Parent.Config)

local PrisPlus = {}
local cfg = Config.pris
PrisPlus.cfg = cfg
PrisPlus.ATTRIBUTE = "PrisPlus"
PrisPlus.DAY = 86400

function PrisPlus.active(p: any, now: number?): boolean
	return typeof(p) == "table"
		and typeof(p.prisPlusUntil) == "number"
		and p.prisPlusUntil > (now or os.time())
end

-- seconds of PRIS+ left (0 = none)
function PrisPlus.left(p: any, now: number?): number
	if not PrisPlus.active(p, now) then
		return 0
	end
	return p.prisPlusUntil - (now or os.time())
end

-- inside a profile mutation: `days` more, counted from now when it has run out
function PrisPlus.extend(p: any, days: number, now: number?)
	local t = now or os.time()
	local from = if PrisPlus.active(p, t) then p.prisPlusUntil else t
	p.prisPlusUntil = math.floor(from + days * PrisPlus.DAY)
end

-- the auction commission of this seller now: 0 with PRIS+ or the «Удаление комиссии» purchase
function PrisPlus.commission(p: any, now: number?): number
	if PrisPlus.active(p, now) or (typeof(p) == "table" and p.noAuctionFee == true) then
		return 0
	end
	return Config.auction.commission
end

-- the auction slots: 5, 10 with PRIS+ [вики], plus the bought extra slots
function PrisPlus.auctionSlots(p: any, now: number?): number
	local base = if PrisPlus.active(p, now) then cfg.auctionSlots else Config.auction.slots
	return base + (if typeof(p) == "table" then p.auctionSlots or 0 else 0)
end

-- another player's PRIS+ (the attribute the server keeps)
function PrisPlus.of(player: Player): boolean
	return player:GetAttribute(PrisPlus.ATTRIBUTE) == true
end

function PrisPlus.rubies(p: any): number
	return if typeof(p) == "table" and typeof(p.rubies) == "number" then p.rubies else 0
end

-- «12 д 5 ч» / «3 ч 20 мин» / «45 мин» — locale-free numbers (the words come from Strings)
function PrisPlus.split(seconds: number): (number, number, number)
	local s = math.max(0, math.floor(seconds))
	return s // 86400, (s % 86400) // 3600, (s % 3600) // 60
end

-- AppleSkin [клиент prison_plus «AppleSkin»]: what eating `food` / `saturation` gives now — hunger points, saturation
-- points and the health the regeneration will make from the gain [ваниль: 1 HP costs 6 exhaustion = 1,5 points,
-- spent from saturation first, health regenerates while hunger ≥ 18]
function PrisPlus.appleSkin(
	hunger: number,
	saturation: number,
	food: number,
	foodSaturation: number,
	missingHealth: number
): (number, number, number)
	local max = Config.rules.survival.hunger.max
	local above = Config.rules.survival.hunger.regenHealthAbove
	local newHunger = math.min(max, hunger + food)
	local newSaturation = math.min(newHunger, saturation + foodSaturation)
	local function pool(h: number, s: number): number
		return s + math.max(0, h - above)
	end
	local gained = pool(newHunger, newSaturation) - pool(hunger, math.min(saturation, hunger))
	local health =
		math.clamp(math.floor(gained / cfg.regenPerHealth), 0, math.max(0, missingHealth))
	return newHunger - hunger, math.max(0, newSaturation - math.min(saturation, hunger)), health
end

return PrisPlus
