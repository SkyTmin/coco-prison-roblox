--!strict
local BookTuning = {}
local adjusted: { [string]: boolean } = { plastolom = true, vampirism = true, enlightened = true }

function BookTuning.roll(effect: string, level: number, choices: { string }, random: Random): string
	if level ~= 3 or not adjusted[effect] or random:NextNumber() < 0.5 then
		return effect
	end
	local alternatives = {}
	for _, id in ipairs(choices) do
		if not adjusted[id] then
			table.insert(alternatives, id)
		end
	end
	assert(#alternatives > 0, "Book pool has no alternative reward")
	return alternatives[random:NextInteger(1, #alternatives)]
end

function BookTuning.proc(effect: string, level: number, chance: number): number
	return chance * (if effect == "plastolom" and level == 3 then 0.5 else 1)
end

return BookTuning
