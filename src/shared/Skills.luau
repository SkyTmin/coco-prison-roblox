--!strict
-- The skill tree «Древо навыков» [меню 26.10, wiki/in-game-wiki/SKILL-TREE.md; владелец 28.10]: four branches of five
-- levels, each level costs one point and opens in order; one point on every even level (2, 4 … 50); the oblivion
-- scroll gives every point back. Shared by SkillService (decides) and SkillWindow (draws). Effects:
--   * Оружейник III / V — armor upgrades 13 → 14 / 14 → 15 (Config.requirementHave "Оружейник");
--   * Счастливчик — +keyChanceBonus × level to the ordinary key chance while digging (DigService);
--   * Охотник — doubleKill[level] chance that a mob kill counts twice in the stats (MobService);
--   * Зельевар — no potion stand yet: the levels are bought and wait for it.
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

export type Branch = {
	id: string,
	color: { number },
	levels: number,
	keyChanceBonus: number?,
	doubleKill: { number }?,
}

local Skills = {}

Skills.branches = Config.levels.skills.branches :: { Branch }
Skills.COST = Config.levels.skills.cost :: number

function Skills.branch(id: string): Branch?
	for _, branch in ipairs(Skills.branches) do
		if branch.id == id then
			return branch
		end
	end
	return nil
end

function Skills.level(profile: Types.Profile?, id: string): number
	local skills = profile and (profile :: any).skills
	return if typeof(skills) == "table" then tonumber(skills[id]) or 0 else 0
end

-- points the player's level gave (the level rules' skillPoints up to the current level)
function Skills.earned(profile: Types.Profile?): number
	if not profile then
		return 0
	end
	local total = 0
	for _, rule in ipairs(Config.levels.levels) do
		if rule.level <= profile.level then
			total += rule.skillPoints or 0
		end
	end
	return total
end

function Skills.spent(profile: Types.Profile?): number
	local total = 0
	for _, branch in ipairs(Skills.branches) do
		total += Skills.level(profile, branch.id) * Skills.COST
	end
	return total
end

function Skills.free(profile: Types.Profile?): number
	return math.max(0, Skills.earned(profile) - Skills.spent(profile))
end

-- nil when the next level of the branch can be bought, else the refusal's string key
function Skills.refusal(profile: Types.Profile?, id: string): string?
	local branch = Skills.branch(id)
	if not profile or not branch then
		return "skills_unknown"
	end
	if Skills.level(profile, id) >= branch.levels then
		return "skills_maxed"
	end
	if Skills.free(profile) < Skills.COST then
		return "skills_no_points"
	end
	return nil
end

-- the ordinary key chance multiplier of Счастливчик
function Skills.keyChanceMultiplier(profile: Types.Profile?): number
	local branch = Skills.branch("lucky")
	return 1 + (if branch then branch.keyChanceBonus or 0 else 0) * Skills.level(profile, "lucky")
end

-- the chance of Охотник that a mob kill counts twice
function Skills.doubleKillChance(profile: Types.Profile?): number
	local branch = Skills.branch("hunter")
	local level = Skills.level(profile, "hunter")
	return if branch and branch.doubleKill and level > 0 then branch.doubleKill[level] or 0 else 0
end

return Skills
