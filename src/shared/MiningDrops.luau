--!strict
-- A quantity range belongs to the normal drop (e.g. melon slices), never the Silk Touch block.
local MiningDrops = {}

function MiningDrops.resolve(block: any, silkTouch: boolean, random: Random): (string, number)
	if silkTouch then
		return block.id, 1
	end
	local range = block.dropCount
	local count = if typeof(range) == "table" and #range == 2
		then random:NextInteger(range[1], range[2])
		else 1
	return block.dropsAs or block.id, count
end

return MiningDrops
