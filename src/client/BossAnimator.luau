--!strict
-- Boss animation on every client [владелец 22.10: «у босса должны быть анимации»]. Blender bosses (BlockModel)
-- play their own clips (animateBlock); the template golems use the poses below. BossService only
-- tells what the golem does (model attributes Action / ActionAt / ActionLen); here the six joints
-- (Torso, Neck, Left/RightShoulder, Left/RightHip Motor6Ds) are posed locally every frame through
-- Motor6D.Transform: idle breathing, a heavy walk cycle, wind-ups and blows, the two-fist ground slam,
-- the charge lean, the stunned slump, the spawn roar and the jump over a block. Smooth at any frame
-- rate and costs no network traffic.
-- Angles: +X on a shoulder / hip swings the limb forward (towards −Z, the facing); +X on the neck
-- tilts the head up; −X on the torso leans it forward.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockRig = require(Shared.BlockRig)

local BossAnimator = {}

type Pose = { [string]: CFrame }
local rad = math.rad

local function ease(t: number): number -- smoothstep 0..1
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

local function lerpPose(a: Pose, b: Pose, t: number): Pose
	local out: Pose = {}
	for name, cf in pairs(a) do
		out[name] = cf:Lerp(b[name] or CFrame.identity, t)
	end
	for name, cf in pairs(b) do
		if not out[name] then
			out[name] = CFrame.new():Lerp(cf, t)
		end
	end
	return out
end

local function rx(degrees: number, y: number?, z: number?): CFrame
	return CFrame.Angles(rad(degrees), rad(y or 0), rad(z or 0))
end

-- key poses
local REST: Pose = {}
local ARM_UP: Pose = { RightShoulder = rx(165, 0, -15), Torso = rx(8, -15, 0), Neck = rx(10) }
local ARM_DOWN: Pose = { RightShoulder = rx(-15, 0, 10), Torso = rx(-18, 20, 0), Neck = rx(-10) }
local BOTH_UP: Pose = {
	LeftShoulder = rx(170, 0, 10),
	RightShoulder = rx(170, 0, -10),
	Torso = rx(10),
	Neck = rx(15),
}
local SLAM: Pose = {
	LeftShoulder = rx(40, 0, 10),
	RightShoulder = rx(40, 0, -10),
	Torso = CFrame.new(0, -0.5, 0) * rx(-35),
	Neck = rx(-15),
	LeftHip = rx(25),
	RightHip = rx(25),
}
local CHARGE: Pose = {
	Torso = rx(-30),
	LeftShoulder = rx(-50, 0, 15),
	RightShoulder = rx(-50, 0, -15),
	Neck = rx(20),
	LeftHip = rx(30), -- legs stay under the body while it leans
	RightHip = rx(30),
}
local STUNNED: Pose = {
	Torso = CFrame.new(0, -0.3, 0) * rx(-25),
	Neck = rx(-35, 0, 12),
	LeftHip = rx(22),
	RightHip = rx(22),
	LeftShoulder = rx(-10, 0, 8),
	RightShoulder = rx(-10, 0, -8),
}
local ROAR: Pose =
	{ Torso = rx(14), Neck = rx(30), LeftShoulder = rx(40, 0, 70), RightShoulder = rx(40, 0, -70) }
local JUMP: Pose = {
	LeftHip = rx(55),
	RightHip = rx(55),
	LeftShoulder = rx(60, 0, 30),
	RightShoulder = rx(60, 0, -30),
}

-- action → pose at progress t (0..1 over ActionLen, seconds = elapsed)
local function actionPose(action: string, t: number, seconds: number, length: number): Pose?
	if action == "melee" then
		if t < 0.45 then
			return lerpPose(REST, ARM_UP, ease(t / 0.45))
		elseif t < 0.6 then
			return lerpPose(ARM_UP, ARM_DOWN, ease((t - 0.45) / 0.15))
		end
		return lerpPose(ARM_DOWN, REST, ease((t - 0.6) / 0.4))
	elseif action == "blade" then
		-- the arm stays raised over the telegraph, then sweeps the lava blade forward
		local raise = math.min(1, seconds / 0.5)
		local sweepAt = math.max(0.5, length - 0.9)
		if seconds < sweepAt then
			local tremble = CFrame.Angles(0, 0, rad(3 * math.sin(seconds * 30)))
			local pose = lerpPose(REST, ARM_UP, ease(raise))
			pose.RightShoulder = (pose.RightShoulder or CFrame.identity) * tremble
			return pose
		end
		local k = (seconds - sweepAt) / 0.9
		if k < 0.25 then
			return lerpPose(ARM_UP, ARM_DOWN, ease(k / 0.25))
		end
		return lerpPose(ARM_DOWN, REST, ease((k - 0.25) / 0.75))
	elseif action == "spikes" then
		local slamAt = math.max(0.3, length - 0.6)
		if seconds < slamAt then
			return lerpPose(REST, BOTH_UP, ease(seconds / math.min(slamAt, 0.6)))
		end
		local k = (seconds - slamAt) / 0.6
		if k < 0.2 then
			return lerpPose(BOTH_UP, SLAM, ease(k / 0.2))
		end
		return lerpPose(SLAM, REST, ease((k - 0.2) / 0.8))
	elseif action == "charge" then
		local wind = math.min(1, seconds / 0.4)
		return lerpPose(REST, CHARGE, ease(wind) * (1 - ease((t - 0.92) / 0.08)))
	elseif action == "stunned" then
		local pose =
			lerpPose(REST, STUNNED, ease(math.min(1, seconds / 0.25)) * (1 - ease((t - 0.9) / 0.1)))
		local wobble = math.sin(seconds * 5)
		pose.Torso = (pose.Torso or CFrame.identity) * CFrame.Angles(0, 0, rad(5 * wobble))
		pose.Neck = (pose.Neck or CFrame.identity) * CFrame.Angles(0, rad(15 * wobble), 0)
		return pose
	elseif action == "roar" then
		local k = if t < 0.25
			then ease(t / 0.25)
			elseif t > 0.8 then 1 - ease((t - 0.8) / 0.2)
			else 1
		local pose = lerpPose(REST, ROAR, k)
		pose.Torso = (pose.Torso or CFrame.identity)
			* CFrame.new(0, 0, 0)
			* CFrame.Angles(0, 0, rad(2 * math.sin(seconds * 40)) * k)
		return pose
	elseif action == "jump" then
		return lerpPose(REST, JUMP, math.sin(math.pi * math.clamp(t, 0, 1)))
	end
	return nil
end

type Rig = {
	model: Model,
	motors: { [string]: Motor6D },
	walkPhase: number,
	walkBlend: number,
	lava: { [BasePart]: Color3 }, -- glowing parts → their colour, pulsed while the boss is shielded
	-- Blender bosses (model attribute BlockModel → Shared.Models.<id>): the clips instead of the poses above
	block: BlockRig.Prepared?,
	blockMotors: { [string]: Motor6D },
	loco: string,
	locoT: number,
	locoFrom: { [string]: CFrame },
	locoFadeAt: number,
	last: { [string]: CFrame },
}
local rigs: { [Model]: Rig } = {}

local function track(model: Instance)
	if not model:IsA("Model") or rigs[model] then
		return
	end
	local rig: Rig = {
		model = model,
		motors = {},
		walkPhase = 0,
		walkBlend = 0,
		lava = {},
		block = nil,
		blockMotors = {},
		loco = "idle",
		locoT = 0,
		locoFrom = {},
		locoFadeAt = -1,
		last = {},
	}
	local blockId = model:GetAttribute("BlockModel")
	local def = typeof(blockId) == "string"
		and Shared:WaitForChild("Models"):FindFirstChild(blockId)
	if def and def:IsA("ModuleScript") then
		rig.block = BlockRig.prepare(require(def) :: any)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("Motor6D") then
				rig.blockMotors[d.Name] = d
			end
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			rig.lava[d] = d.Color
		end
	end
	rigs[model] = rig
	model.AncestryChanged:Connect(function()
		if not model:IsDescendantOf(workspace) then
			rigs[model] = nil
		end
	end)
end

-- Blender clips for a block boss: the walk / idle loop underneath, the action's clip over the joints it moves
-- (melee, roar, jump stretched over the action's length; the blade and the spikes held up over the telegraph,
-- then the sweep / slam in the last 0.9 / 0.6 s like the server's timing; charge held; stunned looping)
local FADE = 0.15
local function blockClip(
	action: string,
	seconds: number,
	length: number,
	clips: any
): (string?, number)
	if
		action == "melee"
		or action == "roar"
		or action == "jump"
		or action == "swoop"
		or action == "potion"
		or action == "shoot"
		or action == "summon"
		or action == "death"
	then
		local c = clips[action]
		return action, if c then seconds / length * c.length else 0
	elseif action == "blade" then
		local sweepAt = math.max(0.5, length - 0.9)
		if seconds < sweepAt then
			return "blade_raise", seconds
		end
		return "blade_sweep", seconds - sweepAt
	elseif action == "spikes" then
		local slamAt = math.max(0.3, length - 0.6)
		if seconds < slamAt then
			return "spikes_raise", seconds
		end
		return "spikes_slam", seconds - slamAt
	elseif action == "charge" or action == "stunned" then
		return action, seconds
	end
	return nil, 0
end

local function animateBlock(rig: Rig, dt: number, root: BasePart, now: number)
	local prepared = rig.block :: BlockRig.Prepared
	local clips = prepared.clips
	local model = rig.model
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	local loco = if speed > 1 then "walk" else "idle"
	if loco ~= rig.loco then
		rig.locoFrom = table.clone(rig.last)
		rig.locoFadeAt = now
		rig.loco = loco
	end
	rig.locoT += dt * (if loco == "walk" then math.clamp(speed / 8, 0.6, 2) else 1)
	local locoClip = clips[loco]
	local locoW = if rig.locoFadeAt >= 0 then math.clamp((now - rig.locoFadeAt) / FADE, 0, 1) else 1
	local action = model:GetAttribute("Action")
	local at = tonumber(model:GetAttribute("ActionAt")) or 0
	local length = math.max(0.05, tonumber(model:GetAttribute("ActionLen")) or 0)
	local seconds = workspace:GetServerTimeNow() - at
	local clipName, t = nil, 0
	if typeof(action) == "string" and seconds >= 0 and (seconds <= length or action == "death") then
		clipName, t = blockClip(action, math.min(seconds, length), length, clips)
	end
	local clip = clipName and clips[clipName]
	-- fade the action in and out so a blow never snaps
	local actionW = if clip
		then math.clamp(
			(if action == "death" then seconds else math.min(seconds, length - seconds)) / FADE,
			0,
			1
		)
		else 0
	for _, joint in ipairs(prepared.joints) do
		local motor = rig.blockMotors[joint]
		if motor then
			local cf = if locoClip
				then BlockRig.sample(locoClip, joint, rig.locoT)
				else CFrame.identity
			if locoW < 1 then
				cf = (rig.locoFrom[joint] or CFrame.identity):Lerp(cf, locoW)
			end
			if clip and clip.tracks[joint] then
				cf = cf:Lerp(BlockRig.sample(clip, joint, t), actionW)
			end
			if clipName == "blade_raise" and joint == "armL" and seconds > 0.4 then
				cf *= CFrame.Angles(0, 0, rad(3 * math.sin(seconds * 30))) -- the raised blade trembles
			end
			motor.Transform = cf
			rig.last[joint] = cf
		end
	end
end

local function animate(rig: Rig, dt: number)
	local model = rig.model
	local root = model.PrimaryPart
	if not root then
		return
	end
	if rig.block then
		-- no lava flare here: recolouring one Neon part of a ~3000-part block model rebuilds the whole model's
		-- render (~650 ms frozen frame each skill [владелец 22.10: «очень сильно логает»]); CombatFeel's
		-- ShieldGlow highlight shows the shield instead
		animateBlock(rig, dt, root, os.clock())
		return
	end
	for _, name in ipairs({
		"Torso",
		"Neck",
		"LeftShoulder",
		"RightShoulder",
		"LeftHip",
		"RightHip",
	}) do
		local m = rig.motors[name]
		if not m or not m.Parent then
			local found = model:FindFirstChild(name, true)
			rig.motors[name] = if found and found:IsA("Motor6D") then found else nil
		end
	end
	local now = os.clock()
	-- walking: legs and arms swing with the ground speed, the body bobs and rolls a little
	local speed = (root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)).Magnitude
	rig.walkBlend += ((if speed > 1 then 1 else 0) - rig.walkBlend) * math.min(1, dt * 8)
	rig.walkPhase += dt * math.clamp(speed, 0, 30) * 0.6
	local s = math.sin(rig.walkPhase)
	local w = rig.walkBlend
	local pose: Pose = {
		LeftHip = rx(38 * s * w),
		RightHip = rx(-38 * s * w),
		LeftShoulder = rx(-22 * s * w, 0, 4),
		RightShoulder = rx(22 * s * w, 0, -4),
		Torso = CFrame.new(0, -0.35 * math.abs(math.cos(rig.walkPhase)) * w, 0)
			* CFrame.Angles(rad(-4 * w), 0, rad(3 * s * w)),
		Neck = rx(-3 * w),
	}
	-- idle breathing on top (fades out while walking)
	local breathe = math.sin(now * 1.7) * (1 - w)
	pose.Torso = pose.Torso * CFrame.new(0, 0.12 * breathe, 0) * rx(1.5 * breathe)
	pose.Neck = pose.Neck * rx(2 * math.sin(now * 0.9), 6 * math.sin(now * 0.45), 0)
	pose.LeftShoulder = pose.LeftShoulder * rx(3 * breathe)
	pose.RightShoulder = pose.RightShoulder * rx(3 * breathe)
	-- the current action over it
	local action = model:GetAttribute("Action")
	local at = tonumber(model:GetAttribute("ActionAt")) or 0
	local length = math.max(0.05, tonumber(model:GetAttribute("ActionLen")) or 0)
	local seconds = workspace:GetServerTimeNow() - at
	if typeof(action) == "string" and seconds >= 0 and seconds <= length then
		local over = actionPose(action, seconds / length, seconds, length)
		if over then
			for name, cf in pairs(over) do
				-- an action owns the joints it moves; the walk keeps the legs unless the action moves them
				pose[name] = if name == "LeftHip" or name == "RightHip"
					then (pose[name] or CFrame.identity) * cf
					else cf
			end
		end
	end
	for name, m in pairs(rig.motors) do
		m.Transform = pose[name] or CFrame.identity
	end
	-- shielded (an attack animation, no damage gets through): the lava flares white-yellow and pulses
	local shielded = model:GetAttribute("Shielded") == true
	local flare = if shielded then 0.5 + 0.5 * math.sin(now * 12) else 0
	for part, base in pairs(rig.lava) do
		part.Color = base:Lerp(Color3.fromRGB(255, 240, 160), flare)
	end
end

function BossAnimator.Start()
	for _, model in ipairs(CollectionService:GetTagged("Boss")) do
		track(model)
	end
	CollectionService:GetInstanceAddedSignal("Boss"):Connect(track)
	RunService.RenderStepped:Connect(function(dt)
		for _, rig in pairs(rigs) do
			animate(rig, dt)
		end
	end)
end

return BossAnimator
