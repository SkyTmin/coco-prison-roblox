--!strict
-- Our side of the bow [ваниль, владелец 26.10: «как в майнкрафт бедрок на телефоне»]: hold to draw, let go to shoot.
-- Phone: a finger resting on the right half of the screen (init.client: the touch handlers) draws, moving it aims
-- with the camera, lifting it shoots. PC: hold the right mouse button; gamepad: L2. The arrow flies through the
-- crosshair (shown while drawing in third person too). While drawing we walk at sneak speed (× 0.3), the view zooms
-- in (EffectsHud) and the model shows its pull stages (HeldItem, BowState). The server times the draw itself
-- (BowService); our clock only draws the bow and the predicted arrow (Arrows.FireLocal).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local BowState = require(script.Parent.BowState)
local Arrows = require(script.Parent.Arrows)

local BOW = Config.vanilla.bow
local BLOCK = Config.rules.combat.blockStuds :: number

local BowController = {}
local player = Players.LocalPlayer
local getProfile: () -> Types.Profile? = function()
	return nil
end
local isBlocked: () -> boolean = function()
	return false
end
local onChanged: () -> () = function() end
local slowed: Humanoid? = nil
local baseSpeed = 16
local ourSpeed = 0

local function heldBow(): Types.ItemStack?
	local profile = getProfile()
	local stack = if profile then profile.inventory[profile.selectedSlot] else nil
	return if stack and stack.id == "bow" then stack else nil
end

function BowController.InHand(): boolean
	return heldBow() ~= nil
end

function BowController.Drawing(): boolean
	return BowState.LocalDrawAt ~= nil
end

local function hasArrows(): boolean
	if player:GetAttribute("Creative") == true then
		return true
	end
	local profile = getProfile()
	if not profile then
		return false
	end
	for _, stack in pairs(profile.inventory) do
		if stack.id == "arrow" and (stack.count or 0) > 0 then
			return true
		end
	end
	return false
end

local function restoreSpeed()
	local humanoid = slowed
	slowed = nil
	if humanoid and humanoid.Parent then
		humanoid.AutoRotate = true
	end
	if humanoid and humanoid.Parent and math.abs(humanoid.WalkSpeed - ourSpeed) < 1e-3 then
		humanoid.WalkSpeed = baseSpeed
	end
end

local function stop()
	BowState.LocalDrawAt = nil
	restoreSpeed()
	onChanged()
end

-- starts a draw; false when there is no bow in hand or no arrow
function BowController.Begin(): boolean
	if BowController.Drawing() or not heldBow() or isBlocked() then
		return false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	Remotes.event("BowDraw"):FireServer()
	if not hasArrows() then
		return false -- the server says «Нет стрел»
	end
	BowState.LocalDrawAt = workspace:GetServerTimeNow()
	slowed, baseSpeed = humanoid, humanoid.WalkSpeed
	ourSpeed = baseSpeed * BOW.drawWalkMultiplier
	humanoid.WalkSpeed = ourSpeed
	humanoid.AutoRotate = false
	onChanged()
	return true
end

function BowController.Cancel()
	if BowController.Drawing() then
		Remotes.event("BowCancel"):FireServer()
		stop()
	end
end

-- where the crosshair points: the ray through the middle of the screen, from the eyes to what it meets
local function aim(head: BasePart): Vector3
	local camera = workspace.CurrentCamera
	if not camera then
		return head.CFrame.LookVector
	end
	local size = camera.ViewportSize
	local ray = camera:ViewportPointToRay(size.X / 2, size.Y / 2)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character :: Instance }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 1000, params)
	local point = if hit then hit.Position else ray.Origin + ray.Direction * 1000
	local offset = point - head.Position
	return if offset.Magnitude > 3 then offset.Unit else ray.Direction
end

function BowController.Release()
	local drawnAt = BowState.LocalDrawAt
	if not drawnAt then
		return
	end
	local seconds = workspace:GetServerTimeNow() - drawnAt
	local stack = heldBow()
	stop()
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local f = BowState.Power(seconds)
	if not stack or not head or not head:IsA("BasePart") or f < BOW.minPower then
		Remotes.event("BowCancel"):FireServer()
		return
	end
	local direction = aim(head)
	Remotes.event("BowRelease"):FireServer(direction)
	local level = stack.level or 1
	Arrows.FireLocal(
		head.Position + direction * 1.2,
		direction * BOW.speedBlocksPerTick * f * BLOCK,
		f >= 1,
		Config.flameForLevel("bow", level) > 0
	)
end

function BowController.Start(
	profile: () -> Types.Profile?,
	blocked: () -> boolean,
	changed: () -> ()
)
	getProfile, isBlocked, onChanged = profile, blocked, changed
	Arrows.Start()
	RunService.Heartbeat:Connect(function()
		if not BowController.Drawing() then
			return
		end
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if
			not heldBow()
			or isBlocked()
			or not humanoid
			or humanoid.Health <= 0
			or humanoid ~= slowed
		then
			BowController.Cancel()
			return
		end
		if humanoid.WalkSpeed > ourSpeed + 1e-3 then
			-- the server raised the speed meanwhile: slow down from the new one (a cobweb only lowers it: leave that)
			baseSpeed = humanoid.WalkSpeed
			ourSpeed = baseSpeed * BOW.drawWalkMultiplier
			humanoid.WalkSpeed = ourSpeed
		end
		-- as in Minecraft, the body turns to where the arrow will go (the arms follow the camera too)
		local root = humanoid.RootPart
		local camera = workspace.CurrentCamera
		if root and camera then
			local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
			if look.Magnitude > 0.1 then
				root.CFrame = CFrame.lookAt(root.Position, root.Position + look)
			end
		end
	end)
	player.CharacterRemoving:Connect(function()
		if BowController.Drawing() then
			stop()
		end
	end)
end

return BowController
