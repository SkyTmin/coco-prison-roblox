--!strict
-- The renderer and PvP history must agree on the same small, bounded extrapolation.
local MotionTiming = {}
MotionTiming.MAX_AHEAD = 0.05
MotionTiming.MAX_DISTANCE = 3

function MotionTiming.delay(lateness: number, jitter: number, gap: number): number
	-- Spend up to one frame predicting steady motion instead of adding another full snapshot buffer.
	-- Jitter still increases the delay; a lost/stalled stream has a separate stale fallback.
	return math.clamp(lateness + jitter * 0.5 - math.min(gap, 1 / 60), 1 / 120, 0.3)
end

function MotionTiming.project(
	position: Vector3,
	previous: Vector3,
	interval: number,
	ahead: number
): (Vector3, Vector3)
	if interval <= 0 or interval > 0.15 then
		return position, Vector3.zero
	end
	local velocity = (position - previous) / math.max(interval, 1 / 120)
	local offset = velocity * math.clamp(ahead, 0, MotionTiming.MAX_AHEAD)
	if offset.Magnitude > MotionTiming.MAX_DISTANCE then
		offset = offset.Unit * MotionTiming.MAX_DISTANCE
	end
	return position + offset, velocity
end

return MotionTiming
