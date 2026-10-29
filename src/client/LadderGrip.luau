--!strict
-- [владелец 29.10] Falling into a ladder shaft catches the player, even when facing away from the wall.
-- Leave horizontal input and native climbing alone: never push an idle climber off the ladder.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Ladders = require(Shared.Ladders)
local Cobweb = require(Shared.Cobweb)

local LadderGrip = {}
local player = Players.LocalPlayer
local started = false
local held: Humanoid? = nil
local jumpUntil = 0
local JUMP_RELEASE = 0.3 -- [решение] let a deliberate jump clear the ladder before catching again

local function release()
	local humanoid = held
	held = nil
	if humanoid and humanoid.Parent and humanoid:GetState() == Enum.HumanoidStateType.Climbing then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

local function step()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root or root.Anchored or humanoid.Health <= 0 then
		release()
		return
	end
	local state = humanoid:GetState()
	if humanoid.Jump or state == Enum.HumanoidStateType.Jumping then
		held = nil -- let the native jump run; do not replace it with Freefall
		jumpUntil = os.clock() + JUMP_RELEASE
		return
	end
	if
		os.clock() < jumpUntil
		or Cobweb.holds(character)
		or not humanoid:GetStateEnabled(Enum.HumanoidStateType.Climbing)
		or (
			state ~= Enum.HumanoidStateType.Freefall
			and state ~= Enum.HumanoidStateType.Climbing
			and state ~= Enum.HumanoidStateType.Running
		)
	then
		held = nil -- swimming, knockback/ragdolls and webs keep their own movement
		return
	end
	if
		(state ~= Enum.HumanoidStateType.Climbing and humanoid.FloorMaterial ~= Enum.Material.Air)
		or not Ladders.near(character)
	then
		release()
		return
	end
	local catching = held ~= humanoid
	held = humanoid
	if state ~= Enum.HumanoidStateType.Climbing then
		humanoid:ChangeState(Enum.HumanoidStateType.Climbing)
	end
	-- Cancel the incoming fall immediately. Idle players hold; native directional climbing can descend slowly.
	local floorSpeed = if catching or humanoid.MoveDirection.Magnitude <= 0.05
		then 0
		else -Ladders.SLIDE_SPEED
	local velocity = root.AssemblyLinearVelocity
	if velocity.Y < floorSpeed then
		root.AssemblyLinearVelocity = Vector3.new(velocity.X, floorSpeed, velocity.Z)
	end
end

function LadderGrip.Start()
	if started then
		return
	end
	started = true
	-- Run before physics, not at the render frame rate: fast falls must be caught consistently.
	RunService.PreSimulation:Connect(step)
	player.CharacterAdded:Connect(function()
		held, jumpUntil = nil, 0
	end)
end

return LadderGrip
