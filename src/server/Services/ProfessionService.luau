--!strict
-- Professions (Работы): xp per action, levels 1..50, one upgrade point per level, points spent on
-- the three passive boosters (+1 % each). Thresholds: base × 1.6^(level-1) [решение], anchored on
-- observed points (blademaster L3 = 84, surveyor L4 = 5000, mason L6 = 25000).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)

type Profile = Types.Profile

local ProfessionService = {}

function ProfessionService.threshold(job: string, level: number): number
	local base = Config.professions.xpThresholds.base[job] or 100
	return math.floor(base * 1.6 ^ level)
end

-- Adds xp; levels up as many times as the xp allows and grants points.
function ProfessionService.addXp(profile: Profile, job: string, amount: number)
	local pro = profile.professions
	pro.xp[job] = (pro.xp[job] or 0) + amount
	local level = pro.level[job] or 0
	while
		level < Config.professions.levels
		and pro.xp[job] >= ProfessionService.threshold(job, level)
	do
		pro.xp[job] -= ProfessionService.threshold(job, level)
		level += 1
		pro.points += Config.professions.pointPerLevel
	end
	pro.level[job] = level
end

function ProfessionService.moneyMultiplier(profile: Profile): number
	return 1 + profile.professions.upgrades.money * Config.professions.upgrades.money
end

local function onSpendPoint(player: Player, kind: any)
	if kind ~= "blocks" and kind ~= "money" and kind ~= "mobs" then
		return
	end
	ProfileService.Mutate(player, function(p)
		local up = p.professions.upgrades
		if p.professions.points > 0 and up[kind] < Config.professions.upgrades.maxLevel then
			p.professions.points -= 1
			up[kind] += 1
		end
	end)
end

function ProfessionService.Start()
	Remotes.event("SpendPoint").OnServerEvent:Connect(onSpendPoint)
end

return ProfessionService
