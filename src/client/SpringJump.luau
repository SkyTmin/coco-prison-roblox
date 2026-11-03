--!strict
-- One extra airborne jump with Springs boots. The server publishes the permitted height;
-- native client-owned movement applies only the vertical impulse, preserving sprint momentum.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local SpringJump = {}
local started = false
local used = false
local pressed = false
local airborneAt = 0
local humanoid: Humanoid? = nil
local stateConnection: RBXScriptConnection? = nil

local function request()
	if pressed then
		return
	end
	pressed = true
	local player = Players.LocalPlayer
	if player:GetAttribute("LoadingBlocked") == true then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local h = humanoid
	local height = character and character:GetAttribute("SpringsJumpHeight")
	if
		not h
		or h.Health <= 0
		or used
		or not root
		or not root:IsA("BasePart")
		or typeof(height) ~= "number"
		or height <= 0
		or height >= math.huge
		or UserInputService:GetFocusedTextBox()
	then
		return
	end
	local state = h:GetState()
	if state ~= Enum.HumanoidStateType.Jumping and state ~= Enum.HumanoidStateType.Freefall then
		return
	end
	-- A first grounded press can race Roblox's Jumping state transition. Actual floor
	-- contact always belongs to the ordinary jump, never consumes the airborne charge.
	if h.FloorMaterial ~= Enum.Material.Air then
		return
	end
	if os.clock() - airborneAt < 0.1 then
		return -- first-press event ordering must not spend the second jump
	end
	used = true
	local velocity = root.AssemblyLinearVelocity
	h:ChangeState(Enum.HumanoidStateType.Jumping)
	root.AssemblyLinearVelocity =
		Vector3.new(velocity.X, math.sqrt(2 * workspace.Gravity * height), velocity.Z)
end

local function bind(character: Model)
	if stateConnection then
		stateConnection:Disconnect()
		stateConnection = nil
	end
	humanoid, used, pressed, airborneAt = nil, false, false, os.clock()
	local h = character:WaitForChild("Humanoid", 10)
	if not h or not h:IsA("Humanoid") or Players.LocalPlayer.Character ~= character then
		return
	end
	humanoid = h
	stateConnection = h.StateChanged:Connect(function(previous, state)
		if
			(state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall)
			and previous ~= Enum.HumanoidStateType.Jumping
			and previous ~= Enum.HumanoidStateType.Freefall
		then
			airborneAt = os.clock()
		end
		if
			state == Enum.HumanoidStateType.Landed
			or state == Enum.HumanoidStateType.Running
			or state == Enum.HumanoidStateType.Swimming
			or state == Enum.HumanoidStateType.Climbing
		then
			used = false
		end
	end)
end

function SpringJump.start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	player.CharacterAdded:Connect(bind)
	if player.Character then
		task.spawn(bind, player.Character)
	end
	UserInputService.JumpRequest:Connect(request)
	UserInputService.InputEnded:Connect(function(input)
		if
			input.KeyCode == Enum.KeyCode.Space
			or input.KeyCode == Enum.KeyCode.ButtonA
			or input.UserInputType == Enum.UserInputType.Touch
		then
			pressed = false
		end
	end)
end

return SpringJump
