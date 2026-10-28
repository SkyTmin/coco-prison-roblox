--!strict
-- Server-owned hunger, saturation and natural recovery like Minecraft's FoodData [ваниль]. Food is eaten through
-- FoodService (HungerService.Feed).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Effects = require(Shared.Effects)
local Potions = require(Shared.Potions)
local ProfileService = require(script.Parent.ProfileService)

local rules = Config.rules.survival.hunger
local HungerService = {}
local started = false
-- seconds since the last regeneration heal, per player (vanilla foodTickTimer)
local regenTimers: { [Player]: number } = {}

-- exhaustion in food points: saturation goes first, then hunger [ваниль]
local function drain(player: Player, amount: number)
	local profile = ProfileService.Get(player)
	if
		not profile
		or amount <= 0
		or player:GetAttribute("Creative")
		or (profile.hunger <= 0 and (profile.saturation or 0) <= 0)
	then
		return -- creative test mode: no hunger at all
	end
	ProfileService.Mutate(player, function(p)
		local saturation = p.saturation or 0
		local fromSaturation = math.min(saturation, amount)
		p.saturation = if saturation - fromSaturation > 1e-3
			then saturation - fromSaturation
			else nil
		p.hunger = math.max(0, p.hunger - (amount - fromSaturation))
	end)
end

-- eating: hunger + food, saturation + its value, saturation never above the hunger level [ваниль FoodData.eat]
function HungerService.Feed(player: Player, food: number, saturation: number)
	ProfileService.Mutate(player, function(p)
		p.hunger = math.min(rules.max, p.hunger + food)
		local value = math.min(p.hunger, (p.saturation or 0) + saturation)
		p.saturation = if value > 0 then math.floor(value * 100 + 0.5) / 100 else nil
	end)
end

function HungerService.OnBlockDug(player: Player)
	drain(player, rules.drainPerBlockDug)
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	humanoid.StateChanged:Connect(function(_, state)
		if
			state == Enum.HumanoidStateType.Jumping
			and humanoid.Health > 0
			and player.Character == character
		then
			drain(player, rules.drainPerJump)
		end
	end)
end

local function update(dt: number)
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = ProfileService.Get(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			not profile
			or not humanoid
			or humanoid.Health <= 0
			or player:GetAttribute("Creative")
		then
			continue
		end
		local cost = rules.drainPerMinuteIdle * dt / 60
		if humanoid.MoveDirection.Magnitude > 0 then
			cost += (if humanoid.WalkSpeed > 16
				then rules.drainPerSprintSecond
				else rules.drainPerWalkSecond) * dt
		end
		-- Голод from a splash potion [решение: hungerPerSecond]
		cost += Potions.HUNGER_PER_SECOND * Effects.level(character, "Hunger") * dt
		drain(player, cost)
		local hunger = profile.hunger
		local saturation = profile.saturation or 0
		local hurt = humanoid.Health < humanoid.MaxHealth
		local timer = (regenTimers[player] or 0) + dt
		if hurt and saturation > 0 and hunger >= rules.max then
			-- full and saturated: fast regeneration, paid from the saturation [ваниль]
			if timer >= rules.fastRegenEverySeconds then
				timer = 0
				local spent = math.min(saturation, 6)
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + spent / 6)
				drain(player, spent / 4)
			end
		elseif hurt and hunger >= rules.regenHealthAbove then
			-- 1 HP every 4 s for 6 exhaustion = 1.5 points [ваниль]
			if timer >= rules.regenEverySeconds then
				timer = 0
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 1)
				drain(player, rules.drainPerHealthRegen)
			end
		else
			timer = 0
		end
		regenTimers[player] = timer
		if hunger <= 0 and humanoid.Health > rules.starveMinHealth then
			humanoid.Health =
				math.max(rules.starveMinHealth, humanoid.Health - rules.starveDamagePerSecond * dt)
		end
	end
end

function HungerService.Start()
	if started then
		return
	end
	started = true
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(bindCharacter, player, character)
		end)
		if player.Character then
			task.spawn(bindCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	Players.PlayerRemoving:Connect(function(player)
		regenTimers[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
	-- An empty Health script suppresses Roblox's default unconditional regeneration.
	local characterScripts = StarterPlayer:WaitForChild("StarterCharacterScripts")
	if not characterScripts:FindFirstChild("Health") then
		local health = Instance.new("Script")
		health.Name = "Health"
		health.Parent = characterScripts
	end
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then -- the fast regeneration heals every 0.5 s
			return
		end
		local step = elapsed
		elapsed = 0
		update(step)
	end)
end

return HungerService
