--!strict
-- Sprinting like Minecraft [ваниль; владелец 28.10: «как в майнкрафте быстрее бежать. Чекни как на телефоне можно
-- сделать удобнее»]. Computer: W twice quickly or Ctrl while walking; it stops when the player stops. Phone: the
-- joystick pushed to its edge for a moment sprints by itself [решение: как в популярных Roblox-играх; владелец 28.10:
-- «если джостик потянут сильно, бег будет быстрым»], and the optional «Бег» button (off at the start, «Добавить» in the
-- layout editor) keeps sprinting on (a toggle). The client only sends the intent (Sprint); the
-- server sets the speed and the character's Sprinting attribute (no sprint at 6 hunger or less).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)

local Sprint = {}

local DOUBLE_TAP = 0.3 -- [ваниль] W twice within 7 ticks
local EDGE, EDGE_HOLD, EDGE_LEAVE = 0.95, 0.25, 0.6

local player = Players.LocalPlayer
local wanted = false -- what was sent
local keyboard = false -- W twice / Ctrl
local locked = false -- the phone button
local lastW = 0
local edgeSince: number? = nil
local stillSince: number? = nil

local function send(on: boolean)
	if on ~= wanted then
		wanted = on
		Remotes.event("Sprint"):FireServer(on)
	end
end

local controls: any = nil -- Roblox's ControlModule (the joystick's analog push), found once at start
local function moveVector(): Vector3
	if controls then
		local ok, vector = pcall(function()
			return controls:GetMoveVector()
		end)
		if ok and typeof(vector) == "Vector3" then
			return vector
		end
	end
	return Vector3.zero
end

function Sprint.isOn(): boolean
	return locked
end

-- the phone's «Бег» button: on / off
function Sprint.toggle()
	locked = not locked
end

function Sprint.start(touchParent: Instance): ImageButton
	task.spawn(function()
		local ok, module = pcall(function()
			local playerModule =
				player:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule", 10)
			return playerModule and (require(playerModule :: ModuleScript) :: any):GetControls()
		end)
		controls = if ok and module then module else nil
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.W then
			local now = os.clock()
			if now - lastW < DOUBLE_TAP then
				keyboard = true
			end
			lastW = now
		elseif input.KeyCode == Enum.KeyCode.LeftControl then
			keyboard = true
		end
	end)

	local button = Instance.new("ImageButton")
	button.Name = "Touch_sprint"
	button.AnchorPoint = Vector2.new(1, 1)
	button.Size = UDim2.fromOffset(64, 64)
	button.Position = UDim2.new(1, -206, 1, -30)
	button.BackgroundColor3 = Color3.fromRGB(30, 60, 90)
	button.BackgroundTransparency = 0.3
	button.Image = Config.icons.icons.effect_speed or ""
	button.ScaleType = Enum.ScaleType.Fit
	button.ResampleMode = Enum.ResamplerMode.Pixelated
	button.Parent = touchParent
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(1, 0)
	round.Parent = button
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(200, 230, 255)
	stroke.Transparency = 0.4
	stroke.Parent = button
	local pad = Instance.new("UIPadding")
	for _, side in ipairs({ "PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight" }) do
		(pad :: any)[side] = UDim.new(0, 12)
	end
	pad.Parent = button
	button.Activated:Connect(function()
		Sprint.toggle()
	end)

	RunService.Heartbeat:Connect(function()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then
			keyboard, edgeSince, stillSince = false, nil, nil
			send(false)
			return
		end
		local now = os.clock()
		local moving = humanoid.MoveDirection.Magnitude > 0.1
		-- stopping ends a sprint [ваниль]; a short stand still is forgiven
		if moving then
			stillSince = nil
		elseif not stillSince then
			stillSince = now
		end
		if stillSince and now - stillSince > 0.15 then
			keyboard = false
		end
		-- the joystick at its edge [решение]
		local push = if UserInputService.TouchEnabled then moveVector().Magnitude else 0
		if push >= EDGE then
			edgeSince = edgeSince or now
		elseif push < EDGE_LEAVE then
			edgeSince = nil
		end
		local edge = edgeSince ~= nil and now - edgeSince >= EDGE_HOLD
		send(moving and (keyboard or locked or edge))
		local on = character and character:GetAttribute("Sprinting") == true
		stroke.Transparency = if locked then 0 else 0.4
		button.BackgroundColor3 = if on
			then Color3.fromRGB(40, 110, 170)
			else Color3.fromRGB(30, 60, 90)
	end)
	return button
end

return Sprint
