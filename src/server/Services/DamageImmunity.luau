--!strict
-- Java hurt immunity: 10 ticks, stronger blows add only the RAW difference without restarting the timer.
-- Raid bosses keep a window per attacker, so a party can contribute simultaneously [решение].
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)
local DamageImmunity = {}
type Hit = { at: number, raw: number }
local history: { [Humanoid]: { [number]: Hit } } = setmetatable({}, { __mode = "k" }) :: any

function DamageImmunity.Accept(
	humanoid: Humanoid,
	raw: number,
	attackerKey: number?,
	now: number?
): number
	if raw <= 0 or raw ~= raw or raw == math.huge then
		return 0
	end
	local at, key = now or os.clock(), attackerKey or 0
	local list = history[humanoid] or {}
	history[humanoid] = list
	local previous = list[key]
	if previous and at - previous.at < Config.rules.combat.hurtImmunitySeconds then
		if raw <= previous.raw then
			return 0
		end
		local difference = raw - previous.raw
		previous.raw = raw
		return difference
	end
	list[key] = { at = at, raw = raw }
	return raw
end

return DamageImmunity
