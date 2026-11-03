--!strict
-- Preserve half of horizontal momentum. Airborne hits do not restart the jump arc [ваниль].
local Knockback = {}

function Knockback.finite(v: any): boolean
	return typeof(v) == "Vector3"
		and v.X == v.X
		and v.Y == v.Y
		and v.Z == v.Z
		and math.abs(v.X) < math.huge
		and math.abs(v.Y) < math.huge
		and math.abs(v.Z) < math.huge
end

function Knockback.velocity(current: Vector3, push: Vector3, grounded: boolean): Vector3
	local horizontal = Vector3.new(current.X * 0.5 + push.X, 0, current.Z * 0.5 + push.Z)
	return horizontal
		+ Vector3.new(0, if grounded then math.max(current.Y * 0.5, push.Y) else current.Y, 0)
end

return Knockback
