--!strict
-- Trainer NPC (Config.trainer): three directions — strength, agility, needs — up to maxLevel each.
-- [меню] the first requirements (strength: 30 zombies, 15 kills, 500 $; agility: 50 $, 5 bats;
-- needs: 450 $). Later levels are our decision: every requirement grows ×costGrowth per level [решение].
-- Money is paid on upgrade; kill counters are thresholds and are not consumed [решение].
-- Effects: needs → NeedsService drains needs slower; strength / agility are stored in the profile and
-- exposed through TrainerService.multiplier for the combat code (no player-vs-mob damage yet).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)

local STATS = { "strength", "agility", "needs" }
local TrainerService = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function level(profile: Types.Profile, stat: string): number
	local trainer = profile.trainer
	return if trainer then (trainer[stat] or 0) else 0
end

-- Requirements for the upgrade from `current` to `current + 1`, in display units (money in $).
function TrainerService.requirements(stat: string, current: number): { [string]: number }
	local rule = Config.trainer[stat]
	local out: { [string]: number } = {}
	local growth = (Config.trainer.costGrowth :: number) ^ current
	for name, first in pairs(rule.first) do
		out[name] = if name == "money"
			then math.floor(first * growth + 0.5)
			else math.floor(first * growth + 0.5)
	end
	return out
end

-- How much of each requirement the player has (money in $, counters from stats).
function TrainerService.progress(profile: Types.Profile, name: string): number
	if name == "money" then
		return profile.coins / Config.moneyScale
	end
	return profile.stats[name] or 0
end

function TrainerService.multiplier(profile: Types.Profile, stat: string): number
	local rule = Config.trainer[stat]
	return 1 + level(profile, stat) * (rule.perLevel :: number)
end

local function nearTrainer(player: Player): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	for _, npc in ipairs(game:GetService("CollectionService"):GetTagged("TrainerNpc")) do
		if
			npc:IsA("BasePart")
			and npc:IsDescendantOf(workspace)
			and (npc.Position - root.Position).Magnitude <= 14
		then
			return true
		end
	end
	return false
end

local function upgrade(player: Player, stat: any)
	if typeof(stat) ~= "string" or not table.find(STATS, stat) then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile or not nearTrainer(player) then
		return
	end
	local result: string? = nil
	local newLevel = 0
	ProfileService.Mutate(player, function(p)
		local current = level(p, stat)
		if current >= Config.trainer[stat].maxLevel then
			result = "upgrade_max"
			return
		end
		local needs = TrainerService.requirements(stat, current)
		for name, amount in pairs(needs) do
			if TrainerService.progress(p, name) < amount then
				result = "requirements_not_met"
				return
			end
		end
		if needs.money then
			p.coins -= math.floor(needs.money * Config.moneyScale + 0.5)
		end
		p.trainer = p.trainer or { strength = 0, agility = 0, needs = 0 }
		p.trainer[stat] = current + 1
		newLevel = current + 1
	end)
	if result then
		toast(player, result)
	else
		toast(player, "trained", Strings.t("trainer_" .. stat, Strings.localeOf(player)), newLevel)
	end
end

function TrainerService.Start()
	Remotes.event("TrainerUpgrade").OnServerEvent:Connect(upgrade)
end

return TrainerService
