--!strict
-- First person like Minecraft [владелец 21.10]: the held item in the lower right of the view, handle at
-- the bottom right, head towards the upper left (Java); the bare right arm (a block in the skin colour)
-- only when the hand is empty, as in Java. The right arm (a block in the character's skin colour)
-- holding the item sits in the lower right of the view; it bobs while walking and swings down-forward
-- while digging or hitting (HeldItem.SwingAmount). Local only: the model lives under the camera, the
-- character itself stays hidden by Roblox in first person.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HeldItem = require(script.Parent.HeldItem)

local FirstPersonHand = {}

-- [владелец 22.10: «анимации от 1 лица такое себе»] sized and placed like Minecraft Java's view (FOV 70):
-- the item is big, its handle leaves the screen at the bottom right and the head points to the upper
-- left; it was a small stick near the centre of the screen. Tuned on screenshots in Studio.
local ARM_SIZE = Vector3.new(0.45, 0.45, 1.6) -- the arm points forward along −Z
local SPRITE_SCALE = 0.6 -- held items are drawn smaller this close to the camera
local GRIP_SCALE = SPRITE_SCALE / 0.32 -- the cube grip below was tuned at scale 0.32
-- the hand's rest position in camera space: right, down, forward
local REST = CFrame.new(1.15, -0.72, -1.0) * CFrame.Angles(math.rad(8), math.rad(-12), math.rad(-6))
-- Minecraft places the hand 0.72 in front of the eye; its swing offsets scale to our depth
local SWING_SCALE = 1.0 / 0.72

local started = false

-- Zoom from the camera focus, not the distance to the head: the head bobs with the walk animation
-- (0.6..1.3 studs from the camera), which hid the hand every other frame while walking.
local function isFirstPerson(character: Model?): boolean
	local camera = workspace.CurrentCamera
	return camera ~= nil
		and character ~= nil
		and (camera.CFrame.Position - camera.Focus.Position).Magnitude < 1.5
end

local function skinColor(character: Model): Color3
	for _, name in ipairs({ "RightHand", "RightLowerArm", "Right Arm" }) do
		local part = character:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part.Color
		end
	end
	return Color3.fromRGB(234, 184, 146)
end

function FirstPersonHand.Start()
	if started then
		return
	end
	started = true
	local player = Players.LocalPlayer
	local model = Instance.new("Model")
	model.Name = "FirstPersonHand"
	local arm = Instance.new("Part")
	arm.Name = "Arm"
	arm.Size = ARM_SIZE
	arm.Anchored, arm.CanCollide, arm.CanQuery, arm.CanTouch = true, false, false, false
	arm.CastShadow = false
	arm.Material = Enum.Material.SmoothPlastic
	arm.Parent = model
	local itemKey: string? = nil
	local item: Instance? = nil
	local itemPart: BasePart? = nil
	local itemIsCube = false
	local bob = 0

	local function setItem(attribute: any)
		local key = if typeof(attribute) == "string" then attribute else ""
		if key == itemKey then
			return
		end
		itemKey = key
		if item then
			item:Destroy()
			item, itemPart = nil, nil
		end
		local id, rawLevel = string.match(key, "^([^:]+):(%d+)$")
		if not id then
			return
		end
		local container, primary, cube =
			HeldItem.MakeVisual(id, tonumber(rawLevel) or 0, SPRITE_SCALE)
		for _, part in ipairs(container:GetDescendants()) do
			if part:IsA("BasePart") then
				part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch =
					true, false, false, false
				part.CastShadow = false
			end
		end
		if container:IsA("BasePart") then
			container.Anchored = true
		end
		container.Parent = model
		item, itemPart, itemIsCube = container, primary, cube
	end

	RunService:BindToRenderStep(
		"FirstPersonHand",
		Enum.RenderPriority.Camera.Value + 2,
		function(dt)
			local camera = workspace.CurrentCamera
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if
				not camera
				or not character
				or not humanoid
				or humanoid.Health <= 0
				or not isFirstPerson(character)
			then
				model.Parent = nil
				return
			end
			model.Parent = camera
			arm.Color = skinColor(character)
			setItem(character:GetAttribute("HeldItem"))
			arm.Transparency = if item then 1 else 0
			-- walking bob (Minecraft view bobbing, small) and the swing
			local speed =
				Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Magnitude
			bob += dt * (if speed > 0.1 then 9 else 0)
			local bobOffset =
				CFrame.new(math.sin(bob) * 0.03 * speed, -math.abs(math.cos(bob)) * 0.03 * speed, 0)
			-- the swing in view follows the attack kind [владелец 22.10]: the overhead blow dives to the centre
			-- and down; the cuts sweep across the screen (right→left, then back); the stab and the punch thrust
			-- forward. Wind-up before the blow, like the third-person keyframes.
			local kind, progress = HeldItem.SwingState()
			local swingOffset = CFrame.identity
			local swingShift = CFrame.identity -- moves the whole hand in camera space
			if progress then
				local windup = math.clamp(progress / 0.4, 0, 1)
				local blow = math.clamp((progress - 0.4) / 0.25, 0, 1)
				local back = math.clamp((progress - 0.65) / 0.35, 0, 1)
				local w = math.sin(windup * math.pi / 2) * (1 - back)
				local b = (blow * blow * (3 - 2 * blow)) * (1 - back)
				if kind == "slash_right" then
					swingOffset = CFrame.new(0.25 * w - 0.6 * b, 0.08 * w, -0.1 * b)
						* CFrame.Angles(
							math.rad(10) * w,
							math.rad(-50) * w + math.rad(95) * b,
							math.rad(-20) * w + math.rad(40) * b
						)
				elseif kind == "slash_left" then
					swingOffset = CFrame.new(-0.45 * w + 0.7 * b, 0.05 * w, -0.1 * b)
						* CFrame.Angles(
							math.rad(10) * w,
							math.rad(60) * w - math.rad(100) * b,
							math.rad(30) * w - math.rad(45) * b
						)
				elseif kind == "stab" or kind == "punch" then
					swingOffset = CFrame.new(
						-0.05 * w - 0.12 * b,
						-0.04 * w + 0.04 * b,
						0.25 * w - 0.6 * b
					) * CFrame.Angles(
						math.rad(-15) * w + math.rad(15) * b,
						math.rad(10) * w,
						0
					)
				else
					-- pickaxe, shovel, axe, blocks, the bare hand [владелец 22.10: «анимации кирки от 1 лица
					-- такое себе»]: Minecraft Java's first-person swing curve (the math of its item-in-hand
					-- renderer, progress linear over the 0.3 s swing). The hand darts in towards the centre
					-- and up on a fast-in √p curve, the item chops forward 80° and tilts, then settles back
					-- slower; the old sine went out and back evenly and looked floaty.
					local p = progress
					local sq = math.sqrt(p)
					local f = math.sin(p * p * math.pi)
					local f1 = math.sin(sq * math.pi)
					swingShift = CFrame.new(
						-0.4 * f1 * SWING_SCALE,
						0.2 * math.sin(sq * math.pi * 2) * SWING_SCALE,
						-0.2 * math.sin(p * math.pi) * SWING_SCALE
					)
					swingOffset = CFrame.Angles(0, math.rad(45 - 20 * f), 0)
						* CFrame.Angles(0, 0, math.rad(-20 * f1))
						* CFrame.Angles(math.rad(-80 * f1), 0, 0)
						* CFrame.Angles(0, math.rad(-45), 0)
				end
			end
			local handFrame = camera.CFrame * swingShift * REST * bobOffset * swingOffset
			-- the arm comes from below the screen edge towards the hand point
			arm.CFrame = handFrame * CFrame.new(0, -0.05, ARM_SIZE.Z / 2 - 0.05)
			if item and itemPart then
				local grip = if itemIsCube
					then CFrame.new(-0.05 * GRIP_SCALE, 0.18 * GRIP_SCALE, -0.12 * GRIP_SCALE)
						* CFrame.Angles(0, math.rad(35), 0)
					else CFrame.new(-0.02, 0.05, -0.05)
						* CFrame.Angles( -- yaw −75°: icon top right → upper left
							math.rad(-10),
							math.rad(-75),
							math.rad(8)
						)
						* CFrame.new(0, 1.45 * SPRITE_SCALE * 0.4, 1.45 * SPRITE_SCALE * 0.4)
				local target = handFrame * grip
				if item:IsA("Model") then
					item:PivotTo(target * itemPart.CFrame:ToObjectSpace(item:GetPivot()))
				else
					itemPart.CFrame = target
				end
			end
		end
	)
end

return FirstPersonHand
