--!strict
-- Profile schema v3 (docs/GAME-DESIGN.md, docs/PLAN.md stage 1).

-- [владелец 27.10: «в меню настройки общие … скрыть уведомления … бар бустеров … языки … уменьшить звук, выключить»]
export type Settings = {
	volume: number?, -- 0..1, default 1
	muted: boolean?,
	hideToasts: boolean?,
	hideBoosters: boolean?,
	autosellOff: boolean?, -- the bought auto-sell switched off [владелец 28.10]
	autosellTextOff: boolean?, -- no «+0,057 $» at the crosshair
}

export type ItemStack = {
	id: string, -- item id: block id ("dirt"), tool id ("pickaxe"), consumable ("apple"), key ("ordinary_key")
	count: number,
	level: number?, -- for tools/weapons/armor
	books: { { id: string, level: number } }?, -- ancient enchantments on the item
	rarity: string?, -- rolled ancient book rarity
	applyChance: number?, -- ancient book application percentage
	coins: number?, -- unclaimed case money bag, in 1/moneyScale
	-- a brewed potion (Shared/Potions): effects with their seconds, «Улучшить», the brewer's name
	potion: { effects: { { id: string, seconds: number } }, upgraded: boolean?, by: string? }?,
}

export type ArtifactTier = {
	fragments: { [number]: number },
	duplicates: number,
	completed: number,
}

export type Needs = { hygiene: number, sleep: number, toilet: number }

export type Professions = {
	xp: { [string]: number }, -- mason / surveyor / blademaster
	level: { [string]: number },
	points: number, -- unspent upgrade points
	upgrades: { blocks: number, money: number, mobs: number },
}

export type Profile = {
	schemaVersion: number,
	locale: string?, -- nil uses Config.rules.ui.defaultLocale; schema stays v3
	level: number,
	coins: number, -- integer, in 1/moneyScale
	blocksTotal: number, -- cumulative blocks with multipliers (never spent)
	counters: { [string]: number }, -- upgrade counters by display name ("Земля", "Крысы", …)
	inventory: { [number]: ItemStack }, -- slots 1..36 (1..9 = hotbar)
	caseContents: { [string]: { [number]: ItemStack } }, -- per case kind, sparse slots 1..27; schema stays v3
	enderChest: { [number]: ItemStack }, -- personal sparse slots 1..27; schema stays v3
	artifacts: { [string]: ArtifactTier }, -- common / rare / epic; schema stays v3
	armor: { [string]: ItemStack }, -- helmet / chestplate / leggings / boots
	selectedSlot: number,
	professions: Professions,
	keys: { [string]: number },
	passes: { [string]: boolean }, -- basement = true
	needs: Needs,
	needsFree: boolean?,
	autosell: boolean?, -- the auto-sell was bought (used): dug blocks are sold at once [владелец 28.10] -- the injection «Без нужд» was used: needs never drain [владелец 28.10]
	hunger: number, -- 0..20
	saturation: number?, -- 0..hunger, spent before hunger [ваниль]; nil = 0; schema stays v3
	crystals: number?, -- donate currency (DonateService, bought for Robux); nil = 0; schema stays v3
	receipts: { string }?, -- the last Robux purchase ids already granted (ProcessReceipt is retried)
	auctionSlots: number?, -- extra auction slots bought in the donate shop
	stash: { { id: string, count: number } }?, -- bought items that did not fit the inventory, claimed from storage [B]
	achievements: { [string]: number }, -- «Копатель» card id (counter name or block id) = claimed tier
	dug: { [string]: number }?, -- blocks without an upgrade counter, per block id (achievements); schema stays v3
	boosters: { { kind: string, mult: number, minutes: number, count: number, scope: string? } }?, -- booster storage; schema stays v3
	activeBoosters: { { kind: string, mult: number, startsAt: number, endsAt: number } }?, -- local, running + queued; schema stays v3
	pendingBoosters: {
		[string]: { kind: string, mult: number, minutes: number, count: number, scope: string? },
	}?, -- shared activations between their steps (BoosterService); schema stays v3
	auction: {
		lots: { [string]: any }, -- lot id → Auction.Summary of the player's listed lots
		pendingSells: { [string]: any }, -- listings not confirmed yet (AuctionService outbox)
		pendingBuys: { [string]: { price: number, op: string, at: number, seller: number? } },
		returns: { ItemStack }, -- items that did not fit («Забрать»)
	}?, -- the auction; schema stays v3
	stats: { [string]: number }, -- rats, zombies, bats, kills, deaths, warzonePoints (points taken on the Дворы)
	lastPosition: { number }?, -- {x, y, z} where the player left; restored on the next join [владелец]
	lastSeen: number?, -- os.time() of that spot; older than rules.teleport.rejoinReturnSeconds = back to the spawn
	nicknames: { string }?, -- owned nicknames from the nickname case; schema stays v3
	skills: { [string]: number }?, -- the skill tree: branch id → bought levels (Shared/Skills); schema stays v3
	potionBrewedAt: number?, -- server time of the last brew: the potion stand charges from it (Shared/Potions)
	nickname: string?, -- shown as a prefix of the display name
	trainer: { [string]: number }?, -- strength / agility / needs levels (Config.trainer); schema stays v3
	faction: string?, -- white / black / yellow / latino (Config.factions); nil = none; schema stays v3
	factionChanges: number?, -- «Смен фракций» [клиент]; schema stays v3
	-- the gang (GangService; the gang document in DataStore Gangs_v1 is the truth, this is the player's side):
	-- id = the gang, leftAt = os.time() of the last voluntary leave (rejoin cooldown); schema stays v3
	gang: { id: string?, leftAt: number? }?,
	-- gang steps that move money or membership between the profile and the gang document, settled on load
	gangOps: { [string]: { kind: string, gang: string, amount: number?, tag: string?, at: number } }?,
	hudLayout: { [string]: { [string]: { number } } }?, -- mode → element id → {x, y, shown, size} (HudLayout); schema stays v3
	settings: Settings?, -- the settings window (SettingsWindow); nil = the defaults; schema stays v3
	location: string,
	operationIds: { [string]: boolean },
}

return {}
