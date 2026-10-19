--!strict
-- Shared type definitions. Profile schema v2 follows PROTOTYPE-SPEC.md §14.

export type Needs = {
	hygiene: number,
	rest: number,
	bladderComfort: number,
}

export type Profile = {
	schemaVersion: number,
	level: number,
	coins: number, -- integer, in hundredths of a coin (Config.moneyScale)
	inventory: { [string]: number }, -- resource id -> count
	tools: { [string]: number }, -- tool id -> tier, 0 = not owned
	weapon: number,
	armor: number,
	jobXp: { [string]: number },
	workCount: number, -- accepted work targets, never decreases
	mobKills: { [string]: number },
	keys: { [string]: number },
	workKeyCounter: number,
	faction: string?,
	needs: Needs,
	quests: { [string]: string }, -- quest id -> state
	cellStorage: { [string]: number },
	learnedEffects: { [string]: boolean },
	operationIds: { [string]: boolean },
}

return {}
