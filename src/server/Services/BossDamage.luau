--!strict
-- Shared by a boss and all of its summons; applied AFTER armor and defensive books.
-- Sliding window prevents overlapping telegraphs from turning a survivable hit into an instant kill.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local BossDamage = {}
type Hit = { at: number, amount: number }
local recent: { [Humanoid]: { Hit } } = setmetatable({}, { __mode = "k" }) :: any

function BossDamage.Limit(humanoid: Humanoid, amount: number, now: number?): number
	local at = now or os.clock()
	local rules = Config.bosses.safety
	local hits = recent[humanoid] or {}
	local spent = 0
	for i = #hits, 1, -1 do
		if at - hits[i].at >= rules.windowSeconds then
			table.remove(hits, i)
		else
			spent += hits[i].amount
		end
	end
	local allowed =
		math.clamp(amount, 0, math.max(0, humanoid.MaxHealth * rules.maxHealthFraction - spent))
	if allowed > 0 then
		table.insert(hits, { at = at, amount = allowed })
	end
	recent[humanoid] = hits
	return allowed
end

return BossDamage
