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
Config.previews = load("previews")
Config.icons = load("icons")
Config.itemVoxels = load("itemvoxels")
Config.armor = load("armor")
Config.effects = load("effects")
Config.achievementsCfg = load("achievements")
Config.artifacts = load("artifacts")
Config.market = load("market")

Config.money = Config.rules.money
Config.moneyScale = Config.rules.money.scale :: number
Config.blocks = Config.blocksFile.blocks
Config.tools = Config.toolsFile.tools
Config.vanilla = Config.toolsFile.vanilla
Config.defaultLocale = Config.rules.ui.defaultLocale :: string
Config.locales = Config.rules.ui.locales :: { string }

export type Block = {
	id: string,
	name: string,
	basePrice: number,
	hardness: number,
	tool: string,
	minTier: number,
	dropsAs: string?,
	itemOnly: boolean,
	sellable: boolean?, -- false: the buyer does not take it (melon slices are food only) [владелец]
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

local ICON_FALLBACKS = { artifact_key = "ancient_key" }
function Config.iconFor(itemId: string, level: number?): string?
	local icons = Config.icons.icons
	if level and Config.tools[itemId] then
		local materialIcon = icons[itemId .. "_" .. Config.materialForLevel(level)]
		if materialIcon then
			return materialIcon
		end
	end
	return icons[itemId] or icons[ICON_FALLBACKS[itemId]] or Config.textures.textures[itemId]
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

-- True when the item is a tool/armor piece whose level carries an enchantment (glint in UI/world).
function Config.isEnchanted(itemId: string, level: number?): boolean
	if not level or not Config.tools[itemId] then
		return false
	end
	return Config.enchantForLevel(itemId, level) > 0
end

-- Break time in seconds, exactly Minecraft Java Edition (minecraft.wiki/w/Breaking) [ваниль]:
--   speed = 1 by hand; with the matching tool type: toolSpeed[material] (wood 2, stone 4, iron 6,
--   diamond 8) + (efficiency² + 1) when enchanted; damage per tick = speed / hardness / 30 when the
--   tool can harvest the block (or the block needs no tool), / 100 otherwise; the block breaks after
--   ceil(1 / damage) ticks of 0.05 s, instantly when damage ≥ 1. Haste is applied by DigService.
-- [владелец 20.10] digging by hand / with the wrong tool is always allowed and the block still drops;
-- it just takes the vanilla "wrong tool" time (pickaxe blocks: /100, e.g. stone by hand 7.5 s).
local TICK = 0.05
function Config.breakTime(block: Block, toolId: string?, toolLevel: number): number?
	if block.itemOnly then
		return nil
	end
	local hardness = block.hardness
	if hardness <= 0 then
		return TICK
	end
	local speed = Config.vanilla.toolSpeed.hand
	local canHarvest = true
	if block.tool ~= "any" then
		if toolId == block.tool and toolLevel >= 1 then
			local material = Config.materialForLevel(toolLevel)
			speed = Config.vanilla.toolSpeed[material]
			local enchant = Config.enchantForLevel(toolId :: string, toolLevel)
			if enchant > 0 then
				speed += enchant * enchant + 1
			end
			-- the tool type speeds up digging even when its tier is too low to harvest (iron ore with
			-- a wooden pickaxe), harvesting then falls to the /100 rule like in Minecraft
			canHarvest = Config.tierIndex(material) >= block.minTier
		else
			-- shovel/axe blocks (dirt, sand, logs, melons) can be taken by hand; pickaxe blocks cannot
			canHarvest = block.tool ~= "pickaxe"
		end
	end
	local damage = speed / hardness / (if canHarvest then 30 else 100)
	if damage >= 1 then
		return TICK -- instant break [ваниль]
	end
	return math.ceil(1 / damage - 1e-9) * TICK
end

-- Minecraft pauses 5 ticks after a block breaks before the next one can start [ваниль]
function Config.hitDelay(): number
	local digging = Config.rules.digging
	local ticks = if digging and typeof(digging.hitDelayTicks) == "number"
		then digging.hitDelayTicks
		else 5
	return ticks * TICK
end

return Config
