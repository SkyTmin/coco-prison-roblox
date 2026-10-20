--!strict
-- Server-owned hunger and natural recovery. Food is consumed by NeedsService.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ProfileService = require(script.Parent.ProfileService)

local rules = Config.rules.survival.hunger
local HungerService = {}
local started = false

local function drain(player: Player, amount: number)
	local profile = ProfileService.Get(player)
	if not profile or profile.hunger <= 0 or amount <= 0 then
		return
	end
	ProfileService.Mutate(player, function(p)
		p.hunger = math.max(0, p.hunger - amount)
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
		if not profile or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local cost = rules.drainPerMinuteIdle * dt / 60
		if humanoid.MoveDirection.Magnitude > 0 then
			cost += (if humanoid.WalkSpeed > 16
				then rules.drainPerSprintSecond
				else rules.drainPerWalkSecond) * dt
		end
		drain(player, cost)
		local hunger = profile.hunger
		if hunger >= rules.regenHealthAbove then
			local before = humanoid.Health
			humanoid.Health = math.min(humanoid.MaxHealth, before + rules.regenHealthPerSecond * dt)
			drain(player, (humanoid.Health - before) * rules.drainPerHealthRegen)
		elseif hunger <= 0 and humanoid.Health > rules.starveMinHealth then
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
		if elapsed < 1 then
			return
		end
		local step = elapsed
		elapsed = 0
		update(step)
	end)
end

return HungerService
