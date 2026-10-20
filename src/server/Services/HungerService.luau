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

function HungerService.OnBlockDug(player: Player)
	local profile = ProfileService.Get(player)
	if not profile or profile.hunger <= 0 then
		return
	end
	ProfileService.Mutate(player, function(p)
		p.hunger = math.max(0, p.hunger - rules.drainPerBlockDug)
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
		local hunger = math.max(0, profile.hunger - rules.drainPerMinuteIdle * dt / 60)
		if hunger ~= profile.hunger then
			ProfileService.Mutate(player, function(p)
				p.hunger = hunger
			end)
		end
		if hunger >= rules.regenHealthAbove then
			humanoid.Health =
				math.min(humanoid.MaxHealth, humanoid.Health + rules.regenHealthPerSecond * dt)
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
