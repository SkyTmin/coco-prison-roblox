--!strict
-- Plays our keyframed melee animations (shared/SwingAnimations) on R15 characters over the Roblox
-- animations, and the Minecraft-like hold pose while an item is in hand [владелец 22.10]. Every frame,
-- after the Animator, a joint's Transform gets: hold pose × swing. Our own swing starts here at once and
-- is sent to the server (Swing), which relays it to nearby players (SwingFx, unreliable) — everyone sees
-- the swing, in first and third person, with no uploaded animation assets. During the blow a light trail
-- follows the held item (the Trail HeldItem puts on the item model).
-- Works with both rigs: classic Motor6D joints and the AnimationConstraint joints of current avatars.
-- Our block body (character attribute BlockBody, AvatarService) keeps its limbs rigid like Minecraft's: elbows, wrists,
-- knees and ankles stay straight, and the right arm's swing and hold bends turn the whole arm at the shoulder instead
-- (the same item direction, a straight arm). Its whole stance is ours, not the Roblox Animate idle/walk (which
-- splayed the stiff legs and swung the hips): Minecraft's biped model [ваниль ModelBiped / LivingEntity] —
-- legs straight together, arms breathing a little, arms and legs swinging against each other when walking,
-- the riding pose when seated.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SwingAnimations = require(Shared.SwingAnimations)
local BowState = require(script.Parent:WaitForChild("BowState"))
local Eating = require(script.Parent:WaitForChild("Eating"))
local Motion = require(script.Parent:WaitForChild("Motion"))

local CharacterAnimator = {}

type Playing = { kind: string, startedAt: number, duration: number }
type JointState = { joint: Instance, lastSet: CFrame?, lastBase: CFrame }
local playing: { [Model]: Playing } = {}
local joints: { [Model]: { [string]: JointState } } = {}
local JOINT_PARTS = {
	RightShoulder = "RightUpperArm",
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftShoulder = "LeftUpperArm",
	Waist = "UpperTorso",
	Neck = "Head",
	RightHip = "RightUpperLeg",
	LeftHip = "LeftUpperLeg",
	Root = "LowerTorso",
}
-- the joints a block body never bends (the right elbow and wrist are folded into the shoulder in applyTo)
local RIGID = {
	RightElbow = "RightLowerArm",
	RightWrist = "RightHand",
	LeftElbow = "LeftLowerArm",
	LeftWrist = "LeftHand",
	RightKnee = "RightLowerLeg",
	RightAnkle = "RightFoot",
	LeftKnee = "LeftLowerLeg",
	LeftAnkle = "LeftFoot",
}
local SEND_INTERVAL = 0.1
local lastSent = 0
-- [ваниль] limbSwingAmount = min(blocks a tick × 4, 1): walking 4.3 blocks/s → 0.86; a block is 4 studs here,
-- so studs/s ÷ 20 (WalkSpeed 16 → 0.8)
local SWING_STUDS = 20
type Walk = { swing: number, amount: number }
local walks: { [Model]: Walk } = {}

local function jointOf(character: Model, name: string): JointState?
	local cache = joints[character]
	if not cache then
		cache = {}
		joints[character] = cache
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(workspace) then
				joints[character] = nil
				playing[character] = nil
				walks[character] = nil
			end
		end)
	end
	local state = cache[name]
	if state and state.joint.Parent then
		return state
	end
	local part = character:FindFirstChild(JOINT_PARTS[name] or RIGID[name])
	local joint = part and part:FindFirstChild(name)
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		state = { joint = joint, lastSet = nil, lastBase = CFrame.identity }
		cache[name] = state
		return state
	end
	return nil
end

local function setTrail(character: Model, on: boolean)
	local visual = character:FindFirstChild("HeldItemVisual")
	local trail = visual and visual:FindFirstChildWhichIsA("Trail", true)
	if trail then
		trail.Enabled = on
	end
end

-- plays `kind` on a character over `duration` seconds (restarts it if it is already swinging)
function CharacterAnimator.Play(character: Model?, kind: string, duration: number)
	if character and SwingAnimations.animations[kind] then
		playing[character] =
			{ kind = kind, startedAt = os.clock(), duration = math.clamp(duration, 0.1, 2) }
	end
end

-- hitstop on our own swing: the blow freezes for a moment when it lands (Sakurai) — the swing's clock
-- is pushed forward by that time
function CharacterAnimator.HoldLocal(seconds: number)
	local entry = playing[Players.LocalPlayer.Character :: any]
	if entry then
		entry.startedAt += seconds
	end
end

-- our own swing: play now, tell the others
function CharacterAnimator.PlayLocal(kind: string, duration: number)
	CharacterAnimator.Play(Players.LocalPlayer.Character, kind, duration)
	local now = os.clock()
	if now - lastSent >= SEND_INTERVAL then
		lastSent = now
		Remotes.event("Swing"):FireServer(kind, duration)
	end
end

-- Drawing a bow, Minecraft's bow-and-arrow arm pose [ваниль]: both arms raised level to the front, the bow arm
-- (right, the main hand) straight, the pulling arm (left) turned in towards it; our own arms also follow the camera's
-- pitch (aiming up or down). Shoulder +x raises the arm forward, +z moves it to the right (the R15 measurements of
-- SwingAnimations).
local function bowPose(pitch: number): { [string]: CFrame }
	return {
		RightShoulder = CFrame.Angles(math.rad(90) + pitch, 0, math.rad(-4)),
		RightElbow = CFrame.identity,
		LeftShoulder = CFrame.Angles(math.rad(90) + pitch, 0, math.rad(30)),
	}
end

-- Eating [ваниль, владелец 27.10: «добавь анимации для еды»]: the main arm comes up to the mouth in the first ticks
-- and bobs with every bite (each 4 ticks, from tick 7 on, with the chewing sound), turned in towards the face.
local function eatPose(seconds: number): { [string]: CFrame }
	local up = math.clamp(seconds / 0.15, 0, 1)
	up = up * up * (3 - 2 * up)
	local ticks = seconds / 0.05
	local bite = if ticks >= 6.4 then math.abs(math.cos(ticks / 4 * math.pi)) else 0
	return {
		RightShoulder = CFrame.Angles(math.rad(112 - 10 * bite) * up, 0, math.rad(-38) * up),
		RightElbow = CFrame.identity,
	}
end

local function rx(a: number): CFrame
	return CFrame.Angles(a, 0, 0)
end

-- The block body's own stance [ваниль ModelBiped.setupAnim]. Minecraft's x rotations are negated (its +x swings a
-- limb back, ours forward); the per-tick lerp and swing run on dt × 20 ticks.
local function stance(
	character: Model,
	dt: number,
	now: number,
	holding: boolean,
	bow: boolean
): { [string]: CFrame }
	local walk = walks[character]
	if not walk then
		walk = { swing = 0, amount = 0 }
		walks[character] = walk
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local speed = 0
	if root and root:IsA("BasePart") then
		-- another player drawn by Motion walks with the velocity it is drawn with, not Roblox's late one
		local v = Motion.velocity(character) or root.AssemblyLinearVelocity
		speed = Vector3.new(v.X, 0, v.Z).Magnitude
	end
	local ticks = dt * 20
	walk.amount += (math.min(speed / SWING_STUDS, 1) - walk.amount) * (1 - 0.6 ^ ticks)
	walk.swing += walk.amount * ticks
	local phase, amount = walk.swing * 0.6662, walk.amount
	local pose: { [string]: CFrame } = {}
	if humanoid and humanoid.Sit then
		-- riding: legs forward and apart, arms raised a little
		pose.RightHip = CFrame.Angles(1.4137, math.rad(18), 0)
		pose.LeftHip = CFrame.Angles(1.4137, math.rad(-18), 0)
		pose.RightShoulder, pose.LeftShoulder = rx(0.6283), rx(0.6283)
	else
		pose.RightHip = rx(-math.cos(phase) * 1.4 * amount)
		pose.LeftHip = rx(-math.cos(phase + math.pi) * 1.4 * amount)
		-- the main hand swings half as far while it holds something
		local right = -math.cos(phase + math.pi) * amount * (if holding then 0.5 else 1)
		pose.RightShoulder, pose.LeftShoulder = rx(right), rx(-math.cos(phase) * amount)
	end
	if bow then
		-- the bow pose sets both arms itself
		pose.RightShoulder, pose.LeftShoulder = nil, nil
	else
		-- breathing: the arms drift out and back a little (age in ticks)
		local age = now * 20
		local out = math.cos(age * 0.09) * 0.05 + 0.05
		local sway = math.sin(age * 0.067) * 0.05
		pose.RightShoulder = (pose.RightShoulder or CFrame.identity) * CFrame.Angles(-sway, 0, out)
		pose.LeftShoulder = (pose.LeftShoulder or CFrame.identity) * CFrame.Angles(sway, 0, -out)
	end
	return pose
end

local function applyTo(
	character: Model,
	holding: boolean,
	entry: Playing?,
	now: number,
	pose: { [string]: CFrame }?,
	dt: number
)
	local animation = entry and SwingAnimations.animations[entry.kind]
	local p = if entry and animation then (now - entry.startedAt) / entry.duration else 1
	if entry then
		setTrail(character, p > 0.25 and p < 0.75)
	end
	local adds: { [string]: CFrame } = {}
	for name in pairs(JOINT_PARTS) do
		local hold = if pose then pose[name] elseif holding then SwingAnimations.hold[name] else nil
		local swing = if animation and p < 1
			then SwingAnimations.sample(animation, name, p)
			else nil
		if hold or swing then
			adds[name] = (hold or CFrame.identity) * (swing or CFrame.identity)
		end
	end
	local block = character:GetAttribute("BlockBody") == true
	if block then
		-- the stance replaces whatever the Roblox Animator wrote; holds and swings go on top of it
		local base = stance(character, dt, now, holding, pose ~= nil)
		for name in pairs(JOINT_PARTS) do
			if RIGID[name] then
				continue
			end
			local state = jointOf(character, name)
			if state then
				local add = adds[name]
				local set = (base[name] or CFrame.identity) * (add or CFrame.identity)
				if name == "RightShoulder" and (adds.RightElbow or adds.RightWrist) then
					set = set
						* (adds.RightElbow or CFrame.identity).Rotation
						* (adds.RightWrist or CFrame.identity).Rotation
				end
				(state.joint :: any).Transform = set
				state.lastSet = nil
			end
		end
		for name in pairs(RIGID) do
			local state = jointOf(character, name)
			if state then
				(state.joint :: any).Transform = CFrame.identity
				state.lastSet = nil
			end
		end
	end
	for name in pairs(JOINT_PARTS) do
		if block then
			break
		end
		local add = adds[name]
		local state = if add
			then jointOf(character, name)
			else (joints[character] and joints[character][name])
		if state then
			local joint = state.joint :: any
			local current: CFrame = joint.Transform
			if state.lastSet and current == state.lastSet then
				current = state.lastBase -- the Animator did not rewrite it: never stack our rotation
			end
			if add then
				local set = current * add
				state.lastBase, state.lastSet = current, set
				joint.Transform = set
			elseif state.lastSet then
				joint.Transform = current
				state.lastSet = nil
			end
		end
	end
	if entry and p >= 1 then
		playing[character] = nil
		setTrail(character, false)
	end
end

local function apply(dt: number)
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local held = character:GetAttribute("HeldItem")
			local pose: { [string]: CFrame }? = nil
			if BowState.DrawStart(character) then
				local pitch = 0
				local camera = workspace.CurrentCamera
				if player == Players.LocalPlayer and camera then
					pitch = math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1))
				end
				pose = bowPose(pitch)
			else
				local eaten = Eating.Progress(character)
				if eaten then
					pose = eatPose(eaten)
				end
			end
			applyTo(
				character,
				typeof(held) == "string" and held ~= "",
				playing[character],
				now,
				pose,
				math.min(dt, 0.1)
			)
		end
	end
end

function CharacterAnimator.Start()
	-- after the Animator has written this frame's pose and before physics moves the limbs
	RunService.PreSimulation:Connect(apply)
	Remotes.unreliable("SwingFx").OnClientEvent
		:Connect(function(userId: number, kind: string, duration: number)
			local player = Players:GetPlayerByUserId(userId)
			if player and player ~= Players.LocalPlayer then
				CharacterAnimator.Play(player.Character, kind, tonumber(duration) or 0.4)
			end
		end)
end

return CharacterAnimator
