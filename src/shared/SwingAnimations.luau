--!strict
-- Our own keyframed swings for R15 characters [владелец 22.10: «анимации удара как в Better Combat»].
-- Better Combat's animation files are "All Rights Reserved", so nothing is copied from them: these
-- keyframes are made here in the same spirit — a big Minecraft-style overhead chop for tools and a
-- wide horizontal slash for swords. Played on top of the Roblox animations by CharacterAnimator.
--
-- Each animation: duration (s) and per-joint keys { t (0..1), x, y, z } in degrees, applied to the
-- joint's Transform. Joints: RightShoulder, RightElbow, RightWrist, LeftShoulder, Waist, Neck.
-- +x on a shoulder raises the arm forward, +y on the waist turns the chest to the left.

export type Key = { t: number, x: number, y: number, z: number }
export type Animation = { duration: number, joints: { [string]: { Key } } }

local ANIMATIONS: { [string]: Animation } = {
	-- tools (pickaxe, shovel, axe) and the bare hand: wind up high, chop down across the body
	chop = {
		duration = 0.32,
		joints = {
			RightShoulder = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.38, x = 125, y = 15, z = -18 },
				{ t = 0.62, x = 25, y = -30, z = 12 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			RightElbow = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.38, x = 35, y = 0, z = 0 },
				{ t = 0.62, x = 8, y = 0, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			RightWrist = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.38, x = -25, y = 0, z = 0 },
				{ t = 0.62, x = 20, y = 0, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			LeftShoulder = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.38, x = -12, y = 0, z = 6 },
				{ t = 0.62, x = 18, y = 0, z = -4 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			Waist = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.38, x = 6, y = -14, z = 0 },
				{ t = 0.62, x = -10, y = 16, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			Neck = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.38, x = 4, y = 8, z = 0 },
				{ t = 0.62, x = -6, y = -8, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
		},
	},
	-- swords: arm out to the right, then a wide sweep from right to left with the whole body
	slash = {
		duration = 0.36,
		joints = {
			RightShoulder = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.3, x = 85, y = 70, z = -10 },
				{ t = 0.62, x = 80, y = -55, z = 5 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			RightElbow = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.3, x = 40, y = 0, z = 0 },
				{ t = 0.62, x = 5, y = 0, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			LeftShoulder = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.3, x = 20, y = -15, z = 10 },
				{ t = 0.62, x = -10, y = 10, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			Waist = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.3, x = 0, y = -28, z = 0 },
				{ t = 0.62, x = -6, y = 30, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
			Neck = {
				{ t = 0, x = 0, y = 0, z = 0 },
				{ t = 0.3, x = 0, y = 14, z = 0 },
				{ t = 0.62, x = 0, y = -14, z = 0 },
				{ t = 1, x = 0, y = 0, z = 0 },
			},
		},
	},
}

local function ease(
	t: number
): number -- in-out quad, like the keyframe easing of most swing animations
	return if t < 0.5 then 2 * t * t else 1 - (-2 * t + 2) ^ 2 / 2
end

-- The rotation of one joint at progress p (0..1) of an animation, or nil when the joint is not animated.
local function sample(animation: Animation, joint: string, p: number): CFrame?
	local keys = animation.joints[joint]
	if not keys then
		return nil
	end
	p = math.clamp(p, 0, 1)
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if p <= b.t then
			local k = ease((p - a.t) / math.max(b.t - a.t, 1e-3))
			local x = a.x + (b.x - a.x) * k
			local y = a.y + (b.y - a.y) * k
			local z = a.z + (b.z - a.z) * k
			return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
		end
	end
	return CFrame.identity
end

return {
	animations = ANIMATIONS,
	sample = sample,
}
