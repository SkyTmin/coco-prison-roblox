--!strict
-- Profile schema v3 (docs/GAME-DESIGN.md, docs/PLAN.md stage 1).

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
	achievements: { [string]: number }, -- digger_dirt = claimed tier
	stats: { [string]: number }, -- rats, zombies, bats, kills, deaths
	lastPosition: { number }?, -- {x, y, z} where the player left; restored on the next join [владелец]
	nicknames: { string }?, -- owned nicknames from the nickname case; schema stays v3
	nickname: string?, -- shown as a prefix of the display name
	trainer: { [string]: number }?, -- strength / agility / needs levels (Config.trainer); schema stays v3
	location: string,
	operationIds: { [string]: boolean },
}

return {}
