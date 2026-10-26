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
-- (the same item direction, a straight arm).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SwingAnimations = require(Shared.SwingAnimations)
local BowState = require(script.Parent:WaitForChild("BowState"))

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

local function jointOf(character: Model, name: string): JointState?
	local cache = joints[character]
	if not cache then
		cache = {}
		joints[character] = cache
		character.AncestryChanged:Connect(function()
			if not character:IsDescendantOf(workspace) then
				joints[character] = nil
				playing[character] = nil
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

local function applyTo(
	character: Model,
	holding: boolean,
	entry: Playing?,
	now: number,
	pose: { [string]: CFrame }?
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
		local elbow, wrist = adds.RightElbow, adds.RightWrist
		if elbow or wrist then
			adds.RightShoulder = (adds.RightShoulder or CFrame.identity)
				* (elbow or CFrame.identity).Rotation
				* (wrist or CFrame.identity).Rotation
		end
		adds.RightElbow, adds.RightWrist = nil, nil
		for name in pairs(RIGID) do
			local state = jointOf(character, name)
			if state then
				(state.joint :: any).Transform = CFrame.identity
				state.lastSet = nil
			end
		end
	end
	for name in pairs(JOINT_PARTS) do
		if block and RIGID[name] then
			continue
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

local function apply()
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
			end
			applyTo(
				character,
				typeof(held) == "string" and held ~= "",
				playing[character],
				now,
				pose
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
