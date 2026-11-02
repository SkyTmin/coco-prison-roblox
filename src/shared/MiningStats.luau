--!strict
-- Server callers supply only successfully removed cells. Item drops/copies are not mined blocks.
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local MiningStats = {}
local PRECISION = 1000000

local function addCredit(current: number, amount: number): number
	-- Keep fractional progress, without letting 25 x 2.4 become 59.999999 and fail a 60-block gate.
	return math.round((current + amount) * PRECISION) / PRECISION
end

function MiningStats.credit(
	profile: Types.Profile,
	blockId: string,
	count: number,
	multiplier: number
)
	local block = Config.block(blockId)
	if not block or count <= 0 then
		return
	end
	local credited = count * multiplier
	profile.blocksTotal = addCredit(profile.blocksTotal, credited) -- orange total; player-level requirements
	profile.stats.blocksClean = (profile.stats.blocksClean or 0) + count -- actual cells, no multiplier
	if block.upgradeCounter then
		local key = block.upgradeCounter
		profile.counters[key] = addCredit(profile.counters[key] or 0, credited) -- same credit for tool requirements
	end
end

return MiningStats
