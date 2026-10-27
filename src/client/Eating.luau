--!strict
-- Eating like Minecraft [ваниль, владелец 27.10: «еду надо есть долго как в майне … добавь анимации для еды»]: hold
-- the use button (F, the right mouse button, gamepad L2, the «Съесть» button, a finger resting on the screen) with
-- food in hand; it takes 32 ticks (1.6 s) and we walk at × 0.2 meanwhile. The server times it (FoodService), our
-- clock only draws it. Every character that eats (the attributes Eating / EatingAt for the others) chews like
-- vanilla: from tick 7 on, every 4 ticks, a chewing sound and 5 crumbs of the food's own picture in front of the
-- mouth, and 16 crumbs when the bite is done. CharacterAnimator raises the arm to the mouth, FirstPersonHand brings
-- the food to the middle of the view and bobs it (Eating.Progress).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Types = require(Shared.Types)

local survival = Config.rules.survival
local SECONDS = survival.eating.seconds :: number
local WALK = survival.eating.walkMultiplier :: number
local TICK = 0.05
local NEXT_BITE = 0.2 -- s between two foods while the button stays down (vanilla's 4-tick use delay)

type Local = { id: string, slot: number, at: number }

local Eating = {}
local player = Players.LocalPlayer
local getProfile: () -> Types.Profile? = function()
	return nil
end
local isBlocked: () -> boolean = function()
	return false
end
local holds: { [string]: boolean } = {}
local mine: Local? = nil
local nextAllowed = 0
local refused = false -- this press was refused (full): no new tries until the button is let go
local slowed: Humanoid? = nil
local baseSpeed, ourSpeed = 16, 0
-- the chewing already played per character: the last 4-tick step
local chewed: { [Model]: number } = {}
local lastSeen: { [Model]: { id: string, at: number } } = {}

local function held(): (Types.ItemStack?, number)
	local profile = getProfile()
	if not profile then
		return nil, 1
	end
	return profile.inventory[profile.selectedSlot], profile.selectedSlot
end

function Eating.IsFood(id: string?): boolean
	return id ~= nil and typeof(survival.food[id]) == "number"
end

-- the item a character is eating and since when (server time), or nil
function Eating.Of(character: Model?): (string?, number?)
	if not character then
		return nil, nil
	end
	if character == player.Character then
		local m = mine
		return if m then m.id else nil, if m then m.at else nil
	end
	local id, at = character:GetAttribute("Eating"), character:GetAttribute("EatingAt")
	if typeof(id) == "string" and typeof(at) == "number" then
		return id, at
	end
	return nil, nil
end

-- seconds into the bite (0 … 1.6), or nil
function Eating.Progress(character: Model?): number?
	local _, at = Eating.Of(character)
	return if at then math.clamp(workspace:GetServerTimeNow() - at, 0, SECONDS) else nil
end

Eating.SECONDS = SECONDS

local function restoreSpeed()
	local humanoid = slowed
	slowed = nil
	if humanoid and humanoid.Parent and math.abs(humanoid.WalkSpeed - ourSpeed) < 1e-3 then
		humanoid.WalkSpeed = baseSpeed
	end
end

local function stopMine(tellServer: boolean)
	if mine then
		mine = nil
		if tellServer then
			Remotes.event("EatCancel"):FireServer()
		end
	end
	restoreSpeed()
end

-- where the crumbs come out: in front of the mouth (in first person in front of the camera)
local function mouth(character: Model): Vector3?
	local head = character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local camera = workspace.CurrentCamera
	if
		character == player.Character
		and camera
		and (camera.CFrame.Position - head.Position).Magnitude < 1.5
	then
		return (camera.CFrame * CFrame.new(0, -0.6, -1.6)).Position
	end
	local look = head.CFrame.LookVector
	return head.Position + Vector3.new(look.X, 0, look.Z).Unit * 1.1 - Vector3.new(0, 0.35, 0)
end

-- [ваниль] item crumbs: bits of the food's picture tossed up and forward a little, then falling
local function crumbs(character: Model, id: string, amount: number)
	local at = mouth(character)
	local icon = Config.icons.icons[id]
	if not at or not icon then
		return
	end
	local holder = Instance.new("Part")
	holder.Name = "EatCrumbs"
	holder.Size = Vector3.new(0.3, 0.2, 0.3)
	holder.Transparency = 1
	holder.Anchored = true
	holder.CanCollide, holder.CanQuery, holder.CanTouch = false, false, false
	holder.CFrame = CFrame.new(at)
	holder.Parent = workspace
	local e = Instance.new("ParticleEmitter")
	e.Texture = icon
	-- a random quarter-by-quarter piece of the picture, frozen, like vanilla's item particles
	e.FlipbookLayout = Enum.ParticleFlipbookLayout.Grid4x4
	e.FlipbookMode = Enum.ParticleFlipbookMode.Loop
	e.FlipbookFramerate = NumberRange.new(0)
	e.FlipbookStartRandom = true
	e.Size = NumberSequence.new(0.28)
	e.Lifetime = NumberRange.new(0.45, 0.9)
	e.Speed = NumberRange.new(3, 6)
	e.EmissionDirection = Enum.NormalId.Top
	e.SpreadAngle = Vector2.new(35, 35)
	e.Acceleration = Vector3.new(0, -40, 0)
	e.Drag = 1
	e.Rate = 0
	e.LightInfluence = 1
	e.Shape = Enum.ParticleEmitterShape.Box
	e.Parent = holder
	e:Emit(amount)
	Debris:AddItem(holder, 1.2)
end

local function chew(character: Model, id: string)
	crumbs(character, id, 5)
	local head = character:FindFirstChild("Head")
	-- [ваниль] entity.generic.eat: volume 0.5–1, pitch 0.8–1.2; half as loud here [владелец 27.10: «сделай тише на 50%»]
	Sfx.play("eat", head, 0.2 + math.random() * 0.2, 0.8 + math.random() * 0.4)
end

local function done(character: Model, id: string)
	crumbs(character, id, 16)
	Sfx.play("eat", character:FindFirstChild("Head"), 0.3, 0.9 + math.random() * 0.1)
end

-- the chewing of every eating character, local only (no network: the attributes say who eats)
local function chewAll()
	for _, other in ipairs(Players:GetPlayers()) do
		local character = other.Character
		if not character then
			continue
		end
		local id, at = Eating.Of(character)
		if not id or not at then
			local seen = lastSeen[character]
			lastSeen[character], chewed[character] = nil, nil
			-- someone else stopped right at the end: that was a finished bite (ours comes with Ate)
			if
				seen
				and character ~= player.Character
				and workspace:GetServerTimeNow() - seen.at >= SECONDS - 0.15
			then
				done(character, seen.id)
			end
			continue
		end
		lastSeen[character] = { id = id, at = at }
		local ticks = math.floor((workspace:GetServerTimeNow() - at) / TICK)
		-- vanilla: from 7 ticks in, whenever the remaining ticks are a multiple of 4 (8, 12, … 28)
		local step = if ticks >= 8 then math.floor(ticks / 4) else 0
		if step > 0 and step <= 7 and step ~= chewed[character] then
			chewed[character] = step
			chew(character, id)
		end
	end
end

local function update()
	chewAll()
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local stack, slot = held()
	local pressed = next(holds) ~= nil
	if not pressed then
		refused = false
	end
	local food = stack ~= nil and Eating.IsFood(stack.id)
	local can = pressed
		and food
		and not isBlocked()
		and humanoid ~= nil
		and humanoid.Health > 0
		and player:GetAttribute("Creative") ~= true
	local m = mine
	if m then
		if not can or not stack or stack.id ~= m.id or slot ~= m.slot then
			stopMine(true)
		elseif workspace:GetServerTimeNow() - m.at >= SECONDS then
			-- the server finishes it on its own clock and answers with Ate
			stopMine(false)
			nextAllowed = os.clock() + NEXT_BITE
		elseif humanoid and humanoid == slowed and humanoid.WalkSpeed > ourSpeed + 1e-3 then
			baseSpeed = humanoid.WalkSpeed -- the server raised the speed meanwhile: slow from the new one
			ourSpeed = baseSpeed * WALK
			humanoid.WalkSpeed = ourSpeed
		end
		return
	end
	if not can or not stack or not humanoid or refused or os.clock() < nextAllowed then
		return
	end
	local profile = getProfile()
	if
		profile
		and profile.hunger >= survival.hunger.max
		and not survival.eating.alwaysEdible[stack.id]
	then
		refused = true
		Remotes.event("EatStart"):FireServer(slot) -- the server says «Вы не голодны»
		return
	end
	Remotes.event("EatStart"):FireServer(slot)
	mine = { id = stack.id, slot = slot, at = workspace:GetServerTimeNow() }
	slowed, baseSpeed = humanoid, humanoid.WalkSpeed
	ourSpeed = baseSpeed * WALK
	humanoid.WalkSpeed = ourSpeed
end

-- a use button goes down / up; source names one button so two at once do not cancel each other
function Eating.Hold(source: string, down: boolean)
	holds[source] = if down then true else nil
end

-- food in the selected slot (the hold buttons only eat then)
function Eating.InHand(): boolean
	local stack = held()
	return stack ~= nil and Eating.IsFood(stack.id)
end

function Eating.Start(profileGetter: () -> Types.Profile?, blocked: () -> boolean)
	getProfile, isBlocked = profileGetter, blocked
	RunService.Heartbeat:Connect(update)
	Remotes.event("Ate").OnClientEvent:Connect(function(id: string)
		local character = player.Character
		if character and typeof(id) == "string" then
			done(character, id)
		end
	end)
	player.CharacterRemoving:Connect(function()
		table.clear(holds)
		stopMine(false)
	end)
end

return Eating
