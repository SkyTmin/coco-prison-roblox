--!strict
local Boosters = require(script.Parent.Boosters)
local Config = require(script.Parent.Config)
local Numbers = require(script.Parent.Numbers)

local Selling = {}
Selling.MAX_MULTIPLIER = 5 -- [owner 26.10] final money multiplier, including every booster scope

function Selling.multiplier(profile: any): number
	if not profile then
		return 1
	end
	local value = (1 + profile.professions.upgrades.money * Config.professions.upgrades.money)
		* Boosters.multiplier(profile, "money")
	return if Numbers.finite(value) and value >= 0
		then math.min(Selling.MAX_MULTIPLIER, value)
		else 0
end

return Selling
