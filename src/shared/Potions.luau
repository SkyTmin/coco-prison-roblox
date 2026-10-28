--!strict
-- The potion stand «Зельеварка» [вики POTIONS.md]: the Зельевар level gives that many modifiers; every chosen effect
-- takes one, «Улучшить» takes one more and makes every effect last ×1.7. A drinkable potion holds good effects, a
-- splash potion (Зельевар III) bad ones for whoever it lands near. After brewing the stand is empty and charges
-- again over rechargeMinutes[Зельевар level]. Shared by PotionService (decides) and PotionWindow (draws).
local Config = require(script.Parent.Config)
local Skills = require(script.Parent.Skills)
local Types = require(script.Parent.Types)

export type Entry = { id: string, seconds: number }
export type Kind = "drink" | "splash"

local Potions = {}

local rules = Config.levels.potions
Potions.positive = rules.positive :: { Entry }
Potions.negative = rules.negative :: { Entry }
Potions.UPGRADE = rules.upgradeMultiplier :: number
Potions.UPGRADE_COST = rules.upgradeCost :: number
Potions.SPLASH_LEVEL = rules.splashLevel :: number
Potions.SPLASH_RADIUS = rules.splashRadiusBlocks :: number
Potions.HUNGER_PER_SECOND = rules.hungerPerSecond :: number
Potions.STRENGTH_DAMAGE = rules.strengthDamage :: number
Potions.ITEMS = { drink = "potion_drink", splash = "potion_splash" }

function Potions.isPotion(id: string): boolean
	return id == Potions.ITEMS.drink or id == Potions.ITEMS.splash
end

function Potions.list(kind: Kind): { Entry }
	return if kind == "splash" then Potions.negative else Potions.positive
end

function Potions.entry(kind: Kind, id: string): Entry?
	for _, entry in ipairs(Potions.list(kind)) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Potions.modifiers(profile: Types.Profile?): number
	return Skills.level(profile, "brewer")
end

-- seconds the stand needs to charge at this Зельевар level
function Potions.rechargeSeconds(level: number): number
	local minutes = rules.rechargeMinutes :: { number }
	return (minutes[math.clamp(level, 1, #minutes)] or minutes[1]) * 60
end

-- the stand's charge 0..1 at server time `now`
function Potions.charge(profile: Types.Profile?, now: number): number
	local brewed = profile and (profile :: any).potionBrewedAt
	if typeof(brewed) ~= "number" then
		return 1
	end
	local level = math.max(1, Potions.modifiers(profile))
	return math.clamp((now - brewed) / Potions.rechargeSeconds(level), 0, 1)
end

-- seconds left until the stand is charged
function Potions.chargeLeft(profile: Types.Profile?, now: number): number
	local brewed = profile and (profile :: any).potionBrewedAt
	if typeof(brewed) ~= "number" then
		return 0
	end
	local level = math.max(1, Potions.modifiers(profile))
	return math.max(0, brewed + Potions.rechargeSeconds(level) - now)
end

function Potions.cost(effects: number, upgraded: boolean): number
	return effects + (if upgraded then Potions.UPGRADE_COST else 0)
end

-- the reason a brew is refused (Strings key) or nil; `creative` skips the charge
function Potions.refusal(
	profile: Types.Profile?,
	kind: Kind,
	ids: { string },
	upgraded: boolean,
	now: number,
	creative: boolean?
): string?
	local level = Potions.modifiers(profile)
	if level < 1 then
		return "potions_need_skill"
	end
	if kind == "splash" and level < Potions.SPLASH_LEVEL then
		return "potions_splash_locked"
	end
	if #ids == 0 then
		return "potions_pick_effect"
	end
	local seen: { [string]: boolean } = {}
	for _, id in ipairs(ids) do
		if seen[id] or not Potions.entry(kind, id) then
			return "potions_bad_effect"
		end
		seen[id] = true
	end
	if Potions.cost(#ids, upgraded) > level then
		return "potions_no_modifiers"
	end
	if not creative and Potions.charge(profile, now) < 1 then
		return "potions_not_charged"
	end
	return nil
end

-- the potion item: effects in the stand's order, durations already multiplied
function Potions.make(kind: Kind, ids: { string }, upgraded: boolean, by: string): Types.ItemStack
	local chosen: { [string]: boolean } = {}
	for _, id in ipairs(ids) do
		chosen[id] = true
	end
	local effects = {}
	for _, entry in ipairs(Potions.list(kind)) do
		if chosen[entry.id] then
			local seconds = if upgraded
				then math.floor(entry.seconds * Potions.UPGRADE + 0.5)
				else entry.seconds
			table.insert(effects, { id = entry.id, seconds = seconds })
		end
	end
	return {
		id = Potions.ITEMS[kind],
		count = 1,
		potion = { effects = effects, upgraded = upgraded, by = by },
	}
end

-- «0:12»
function Potions.clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds + 0.5))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

return Potions
