--!strict
-- Typed access to the generated configs in Config/*.json (Rojo syncs each JSON as a ModuleScript).
-- Source of truth: wiki/in-game-wiki/*.json + scripts/design-decisions.json → node scripts/build-configs.mjs.

local folder = script -- JSON configs are this module's children (Config/init.luau + Config/*.json)

local function load(name: string): any
	return require(folder:WaitForChild(name)) :: any
end

local Config = {}

Config.levels = load("levels")
Config.blocksFile = load("blocks")
Config.locationsFile = load("locations")
Config.toolsFile = load("tools")
Config.bosses = load("bosses")
Config.mobs = load("mobs")
Config.needs = load("needs")
Config.professions = load("professions")
Config.keys = load("keys")
Config.books = load("books")
Config.rules = load("rules")
Config.trainer = load("trainer")
Config.textures = load("textures")

Config.money = Config.rules.money
Config.moneyScale = Config.rules.money.scale :: number
Config.blocks = Config.blocksFile.blocks
Config.tools = Config.toolsFile.tools
Config.vanilla = Config.toolsFile.vanilla
Config.defaultLocale = "ru"
Config.locales = { "ru", "en", "es", "fr" }

export type Block = {
	id: string,
	name: string,
	basePrice: number,
	hardness: number,
	tool: string,
	minTier: number,
	dropsAs: string?,
	itemOnly: boolean,
	upgradeCounter: string?,
}

export type LevelRule = {
	level: number,
	money: number,
	blocks: number,
	hearts: number,
	skillPoints: number,
}

export type Upgrade = {
	from: number,
	to: number,
	cost: number,
	requirements: { [string]: number },
	enchantAfter: number,
	materialAfter: string,
}

export type Location = {
	id: string,
	kind: string,
	name: string,
	unlockLevel: number,
	requiresPass: boolean,
	pvp: boolean,
	mine: {
		size: { number },
		resetSeconds: number,
		warnSeconds: number,
		shares: { [string]: number },
	},
	sellList: { string },
}

local locationsById: { [string]: Location } = {}
for _, loc in ipairs(Config.locationsFile.locations) do
	locationsById[loc.id] = loc
end

function Config.block(id: string): Block?
	return Config.blocks[id]
end

function Config.location(id: string): Location?
	return locationsById[id]
end

function Config.levelRule(level: number): LevelRule?
	for _, rule in ipairs(Config.levels.levels) do
		if rule.level == level then
			return rule
		end
	end
	return nil
end

-- Upgrade record that takes an item from `fromLevel` to `fromLevel + 1`.
function Config.upgrade(itemId: string, fromLevel: number): Upgrade?
	local tool = Config.tools[itemId]
	if not tool then
		return nil
	end
	for _, up in ipairs(tool.upgrades) do
		if up.from == fromLevel then
			return up
		end
	end
	return nil
end

-- Material tier index for an item level: wood 0, stone 1, iron 2, diamond 3.
local MATERIALS = { "wood", "stone", "iron", "diamond" }
function Config.materialForLevel(level: number): string
	return MATERIALS[math.clamp(math.floor((level - 1) / 4) + 1, 1, 4)]
end
function Config.tierIndex(material: string): number
	return (table.find(MATERIALS, material) or 1) - 1
end

-- Enchant level (Efficiency/Sharpness/Protection) for an item level.
function Config.enchantForLevel(itemId: string, level: number): number
	if level <= 1 then
		return 0
	end
	for _, up in ipairs(Config.tools[itemId].upgrades) do
		if up.to == level then
			return up.enchantAfter
		end
	end
	return 0
end

-- Vanilla break time in seconds (0.05 minimum). Returns nil when the tool cannot harvest the block.
function Config.breakTime(block: Block, toolId: string?, toolLevel: number): number?
	if block.itemOnly then
		return nil
	end
	local mult: number
	if block.tool == "any" then
		mult = 1
	else
		if toolId ~= block.tool or toolLevel < 1 then
			return nil
		end
		local material = Config.materialForLevel(toolLevel)
		if Config.tierIndex(material) < block.minTier then
			return nil
		end
		local enchant = Config.enchantForLevel(toolId :: string, toolLevel)
		mult = Config.vanilla.toolSpeed[material]
			+ (if enchant > 0 then enchant * enchant + 1 else 0)
	end
	return math.max(0.05, block.hardness * 1.5 / mult)
end

return Config
