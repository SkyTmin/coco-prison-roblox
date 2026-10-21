--!strict
-- Our own keyframed melee animations for R15 characters [владелец 22.10: «боевые анимации уровня Better
-- Combat»]. Better Combat's animation files are "All Rights Reserved" — nothing is copied from them; these
-- keys are made here following the same principles: a wind-up (the arm cocked, the chest turned away),
-- the blow at the attack's upswing point (Combat: 0.3–0.5 of the attack), a quick follow-through and an
-- eased return; the chest and the head turn with the arm, the free arm counters. Played by
-- CharacterAnimator over the Roblox animations, stretched to the weapon's attack length.
--
-- Keys per joint: { t (0..1 of the animation), x, y, z } in degrees, applied to the joint's Transform.
-- Measured on the R15 rig (22.10): shoulder +x raises the arm forward/up, shoulder +z swings it out to the
-- side, waist +y turns the chest to the left, neck +y turns the head left, elbow +x bends it.

export type Key = { t: number, x: number, y: number, z: number }
export type Animation = { joints: { [string]: { Key } } }

local function k(t: number, x: number, y: number?, z: number?): Key
	return { t = t, x = x, y = y or 0, z = z or 0 }
end

local ANIMATIONS: { [string]: Animation } = {
	-- overhead blow (digging, pickaxe, shovel): raise high behind the head, drive down in front
	slam = {
		joints = {
			RightShoulder = {
				k(0, 0),
				k(0.4, 155, 0, 12),
				k(0.55, 35, 0, -6),
				k(0.7, 18, 0, -4),
				k(1, 0),
			},
			RightElbow = { k(0, 0), k(0.4, 45), k(0.55, 6), k(1, 0) },
			RightWrist = { k(0, 0), k(0.4, -30), k(0.55, 25), k(1, 0) },
			LeftShoulder = { k(0, 0), k(0.4, -15, 0, 8), k(0.55, 20, 0, -4), k(1, 0) },
			Waist = { k(0, 0), k(0.4, 10, -10), k(0.55, -16, 8), k(1, 0) },
			Neck = { k(0, 0), k(0.4, 8, 6), k(0.55, -10, -4), k(1, 0) },
		},
	},
	-- sword / axe, first of the combo: cocked out to the right, a wide horizontal cut to the left
	slash_right = {
		joints = {
			RightShoulder = {
				k(0, 0),
				k(0.35, 80, 0, 78),
				k(0.55, 86, 0, -42),
				k(0.7, 80, 0, -52),
				k(1, 0),
			},
			RightElbow = { k(0, 0), k(0.35, 45), k(0.55, 8), k(1, 0) },
			RightWrist = { k(0, 0), k(0.35, 0, 0, 25), k(0.55, 0, 0, -20), k(1, 0) },
			LeftShoulder = { k(0, 0), k(0.35, 25, 0, -10), k(0.55, -15, 0, 15), k(1, 0) },
			Waist = { k(0, 0), k(0.35, 0, -32), k(0.55, -6, 30), k(0.7, -6, 34), k(1, 0) },
			Neck = { k(0, 0), k(0.35, 0, 16), k(0.55, 0, -14), k(1, 0) },
		},
	},
	-- second of the combo: a backhand from the left (arm across the chest) out to the right
	slash_left = {
		joints = {
			RightShoulder = {
				k(0, 0),
				k(0.35, 82, 0, -55),
				k(0.55, 86, 0, 72),
				k(0.7, 80, 0, 80),
				k(1, 0),
			},
			RightElbow = { k(0, 0), k(0.35, 75), k(0.55, 6), k(1, 0) },
			RightWrist = { k(0, 0), k(0.35, 0, 0, -25), k(0.55, 0, 0, 20), k(1, 0) },
			LeftShoulder = { k(0, 0), k(0.35, -12, 0, 12), k(0.55, 22, 0, -10), k(1, 0) },
			Waist = { k(0, 0), k(0.35, 0, 28), k(0.55, -6, -30), k(0.7, -6, -34), k(1, 0) },
			Neck = { k(0, 0), k(0.35, 0, -14), k(0.55, 0, 14), k(1, 0) },
		},
	},
	-- third of the combo: pull back with the elbow bent, thrust straight forward with a lunge
	stab = {
		joints = {
			RightShoulder = {
				k(0, 0),
				k(0.35, 55, 0, 14),
				k(0.52, 92, 0, -2),
				k(0.7, 88, 0, 0),
				k(1, 0),
			},
			RightElbow = { k(0, 0), k(0.35, 105), k(0.52, 0), k(1, 0) },
			RightWrist = { k(0, 0), k(0.35, -20), k(0.52, 10), k(1, 0) },
			LeftShoulder = { k(0, 0), k(0.35, 20, 0, -8), k(0.52, -20, 0, 10), k(1, 0) },
			Waist = { k(0, 0), k(0.35, 4, -20), k(0.52, -14, 14), k(1, 0) },
			Neck = { k(0, 0), k(0.35, 0, 10), k(0.52, 4, -8), k(1, 0) },
		},
	},
	-- bare hand: a short jab
	punch = {
		joints = {
			RightShoulder = { k(0, 0), k(0.3, 62, 0, 10), k(0.5, 92, 0, -4), k(1, 0) },
			RightElbow = { k(0, 0), k(0.3, 115), k(0.5, 4), k(1, 0) },
			LeftShoulder = { k(0, 0), k(0.3, 30, 0, -6), k(0.5, 10), k(1, 0) },
			Waist = { k(0, 0), k(0.3, 0, -18), k(0.5, -6, 14), k(1, 0) },
			Neck = { k(0, 0), k(0.3, 0, 8), k(0.5, 0, -6), k(1, 0) },
		},
	},
}

-- Holding an item like in Minecraft (owner's reference, 22.10): the arm hangs relaxed a little forward,
-- the elbow slightly bent, so the item sits in front of the hip — not stretched out straight.
local HOLD: { [string]: CFrame } = {
	RightShoulder = CFrame.Angles(math.rad(14), 0, math.rad(4)),
	RightElbow = CFrame.Angles(math.rad(22), 0, 0),
}

local function ease(t: number): number -- in-out quad
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
			local w = ease((p - a.t) / math.max(b.t - a.t, 1e-3))
			return CFrame.Angles(
				math.rad(a.x + (b.x - a.x) * w),
				math.rad(a.y + (b.y - a.y) * w),
				math.rad(a.z + (b.z - a.z) * w)
			)
		end
	end
	return CFrame.identity
end

return {
	animations = ANIMATIONS,
	hold = HOLD,
	sample = sample,
}
