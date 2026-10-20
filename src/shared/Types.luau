--!strict
-- Profile schema v3 (docs/GAME-DESIGN.md, docs/PLAN.md stage 1).

export type ItemStack = {
	id: string, -- item id: block id ("dirt"), tool id ("pickaxe"), consumable ("apple"), key ("ordinary_key")
	count: number,
	level: number?, -- for tools/weapons/armor
	books: { { id: string, level: number } }?, -- ancient enchantments on the item
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
	armor: { [string]: ItemStack }, -- helmet / chestplate / leggings / boots
	selectedSlot: number,
	professions: Professions,
	keys: { [string]: number },
	passes: { [string]: boolean }, -- basement = true
	needs: Needs,
	achievements: { [string]: number }, -- digger_dirt = claimed tier
	stats: { [string]: number }, -- rats, zombies, bats, kills, deaths
	location: string,
	operationIds: { [string]: boolean },
}

return {}
