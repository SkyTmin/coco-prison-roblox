--!strict
-- Typed access to Config/rpg-systems.json (Rojo syncs the JSON file as a ModuleScript).
-- Source of truth for balance: ../../wiki/rpg-systems-config.json is mirrored here;
-- keep the two files identical (see CLAUDE.md).

local raw = require(script.Parent.Config["rpg-systems"]) :: any

export type Resource = {
	id: string,
	label: { [string]: string },
	coinPrice: number,
	tool: string,
}

export type LevelRule = {
	level: number,
	totalWork: number,
	coinCost: number,
	quest: string?,
	mobKills: { [string]: number }?,
}

local Config = {}

Config.raw = raw
Config.moneyScale = raw.moneyScale :: number
Config.defaultLocale = raw.defaultLocale :: string
Config.locales = raw.locales :: { string }

local resourcesById: { [string]: Resource } = {}
for _, resource in ipairs(raw.resources) do
	resourcesById[resource.id] = resource
end
Config.resources = resourcesById

function Config.resource(id: string): Resource?
	return resourcesById[id]
end

function Config.levelRule(level: number): LevelRule?
	for _, rule in ipairs(raw.levels) do
		if rule.level == level then
			return rule
		end
	end
	return nil
end

-- Returns the job name and its minimum level for the tool that harvests a resource.
function Config.jobForTool(tool: string): (string?, number)
	for name, job in pairs(raw.jobs) do
		if job.tool == tool then
			return name, job.minimumLevel
		end
	end
	return nil, 0
end

return Config
