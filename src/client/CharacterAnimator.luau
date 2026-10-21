--!strict
-- Plays our keyframed swings (shared/SwingAnimations) on R15 characters, on top of the Roblox animations:
-- every frame after the Animator, the joint's Transform gets the swing rotation. Our own swing starts
-- here at once and is sent to the server (Swing), which relays it to nearby players (SwingFx,
-- unreliable); each of them plays it on our character locally — so everyone sees the swing, in first
-- and third person, with no uploaded animation assets [владелец 22.10].
-- Works with both rigs: classic Motor6D joints and the AnimationConstraint joints of current avatars.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local SwingAnimations = require(Shared.SwingAnimations)

local CharacterAnimator = {}

type Playing = { kind: string, startedAt: number }
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
local SEND_INTERVAL = 0.12
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
	local part = character:FindFirstChild(JOINT_PARTS[name])
	local joint = part and part:FindFirstChild(name)
	if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
		state = { joint = joint, lastSet = nil, lastBase = CFrame.identity }
		cache[name] = state
		return state
	end
	return nil
end

-- plays `kind` on a character (restarts it if it is already swinging)
function CharacterAnimator.Play(character: Model?, kind: string)
	if character and SwingAnimations.animations[kind] then
		playing[character] = { kind = kind, startedAt = os.clock() }
	end
end

-- our own swing: play now, tell the others
function CharacterAnimator.PlayLocal(kind: string)
	CharacterAnimator.Play(Players.LocalPlayer.Character, kind)
	local now = os.clock()
	if now - lastSent >= SEND_INTERVAL then
		lastSent = now
		Remotes.event("Swing"):FireServer(kind)
	end
end

local function apply()
	local now = os.clock()
	for character, entry in pairs(playing) do
		local animation = SwingAnimations.animations[entry.kind]
		local p = (now - entry.startedAt) / animation.duration
		for name in pairs(animation.joints) do
			local state = jointOf(character, name)
			if state then
				local joint = state.joint :: any
				local current: CFrame = joint.Transform
				if state.lastSet and current == state.lastSet then
					current = state.lastBase -- the Animator did not rewrite it: never stack our rotation
				end
				if p < 1 then
					local turn = SwingAnimations.sample(animation, name, p) or CFrame.identity
					local set = current * turn
					state.lastBase, state.lastSet = current, set
					joint.Transform = set
				elseif state.lastSet then
					joint.Transform = current
					state.lastSet = nil
				end
			end
		end
		if p >= 1 then
			playing[character] = nil
		end
	end
end

function CharacterAnimator.Start()
	-- after the Animator has written this frame's pose and before physics moves the limbs
	RunService.PreSimulation:Connect(apply)
	Remotes.unreliable("SwingFx").OnClientEvent:Connect(function(userId: number, kind: string)
		local player = Players:GetPlayerByUserId(userId)
		if player and player ~= Players.LocalPlayer then
			CharacterAnimator.Play(player.Character, kind)
		end
	end)
end

return CharacterAnimator
