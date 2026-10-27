--!strict
-- Profile schema v3 (docs/GAME-DESIGN.md, docs/PLAN.md stage 1).

-- [владелец 27.10: «в меню настройки общие … скрыть уведомления … бар бустеров … языки … уменьшить звук, выключить»]
export type Settings = {
	volume: number?, -- 0..1, default 1
	muted: boolean?,
	hideToasts: boolean?,
	hideBoosters: boolean?,
}

export type ItemStack = {
	id: string, -- item id: block id ("dirt"), tool id ("pickaxe"), consumable ("apple"), key ("ordinary_key")
	count: number,
	level: number?, -- for tools/weapons/armor
	books: { { id: string, level: number } }?, -- ancient enchantments on the item
	rarity: string?, -- rolled ancient book rarity
	applyChance: number?, -- ancient book application percentage
	coins: number?, -- unclaimed case money bag, in 1/moneyScale
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
	hunger: number, -- 0..20
	saturation: number?, -- 0..hunger, spent before hunger [ваниль]; nil = 0; schema stays v3
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
	stats: { [string]: number }, -- rats, zombies, bats, kills, deaths
	lastPosition: { number }?, -- {x, y, z} where the player left; restored on the next join [владелец]
	nicknames: { string }?, -- owned nicknames from the nickname case; schema stays v3
	nickname: string?, -- shown as a prefix of the display name
	trainer: { [string]: number }?, -- strength / agility / needs levels (Config.trainer); schema stays v3
	faction: string?, -- white / black / yellow / latino (Config.factions); nil = none; schema stays v3
	factionChanges: number?, -- «Смен фракций» [клиент]; schema stays v3
	hudLayout: { [string]: { [string]: { number } } }?, -- mode → element id → {x, y, shown, size} (HudLayout); schema stays v3
	settings: Settings?, -- the settings window (SettingsWindow); nil = the defaults; schema stays v3
	location: string,
	operationIds: { [string]: boolean },
}

return {}
