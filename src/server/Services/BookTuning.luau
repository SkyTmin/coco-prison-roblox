--!strict
local BookTuning = {}
local adjusted: { [string]: boolean } = { plastolom = true, vampirism = true, enlightened = true }
local layerReadyAt: { [Player]: number } = {}
local LAYER_COOLDOWN = 90 -- [владелец 01.11] shared by every tool and tier, after a successful layer

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
	return chance * (if effect == "plastolom" and level >= 1 then 0.5 else 1)
end

function BookTuning.layerReady(player: Player, at: number): boolean
	return at >= (layerReadyAt[player] or 0)
end

function BookTuning.layerStarted(player: Player, at: number)
	layerReadyAt[player] = at + LAYER_COOLDOWN
end

function BookTuning.clear(player: Player)
	layerReadyAt[player] = nil
end

return BookTuning
