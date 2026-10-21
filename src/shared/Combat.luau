--!strict
-- Melee rules shared by the client (animation, cooldown) and the server (hits) [владелец 22.10]: the
-- attack set of the held weapon (Config.rules.combat.weapons — arc angle, the moment of the hit and the
-- reach bonus follow Better Combat's open weapon attributes), the attack length from the vanilla attack
-- speed, and the combo: attacks made within the attack length + comboResetSeconds walk through the set.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

export type Attack = {
	animation: string,
	hitbox: string,
	angle: number,
	upswing: number,
	damage: number,
}
export type Weapon = { rangeBonus: number, attacks: { Attack } }
export type ComboState = { lastAt: number, index: number }

local Combat = {}
local rules = Config.rules.combat

-- the weapon kind of a held item id ("sword", "axe", "pickaxe", "shovel" or "hand")
function Combat.kind(itemId: string?): string
	if itemId and rules.weapons[itemId] then
		return itemId
	end
	return "hand"
end

function Combat.weapon(kind: string): Weapon
	return rules.weapons[kind] or rules.weapons.hand
end

-- seconds one attack takes = 1 / vanilla attack speed of the item at that level
function Combat.duration(kind: string, level: number?): number
	local speeds = Config.vanilla.attackSpeed
	local speed = speeds[kind] or speeds.hand
	if typeof(speed) == "table" then
		speed = speed[Config.materialForLevel(level or 1)] or 1
	end
	return 1 / math.max(0.1, speed :: number)
end

-- reach in studs for a weapon kind
function Combat.range(kind: string): number
	return (rules.reachBlocks + Combat.weapon(kind).rangeBonus) * rules.blockStuds
end

-- the next attack of the combo; mutates state
function Combat.next(
	state: ComboState,
	kind: string,
	duration: number,
	now: number
): (number, Attack)
	local attacks = Combat.weapon(kind).attacks
	local index = if now - state.lastAt <= duration + rules.comboResetSeconds
		then state.index % #attacks + 1
		else 1
	state.lastAt, state.index = now, index
	return index, attacks[index]
end

return Combat
