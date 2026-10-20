--!strict
-- Server bootstrap: start services in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local ProfileService = require(script.Services.ProfileService)
local ProfessionService = require(script.Services.ProfessionService)
local MineService = require(script.Services.MineService)
local DigService = require(script.Services.DigService)
local EconomyService = require(script.Services.EconomyService)

ProfileService.Start()
ProfessionService.Start()
MineService.Start()
DigService.Start()
EconomyService.Start()

-- Hearts by level on spawn
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		task.defer(function()
			local profile = ProfileService.Get(player)
			local rule = if profile then Config.levelRule(profile.level) else nil
			humanoid.MaxHealth = (if rule then rule.hearts else 10) * 2
			humanoid.Health = humanoid.MaxHealth
		end)
	end)
end)

print("[coco-prison] server started, locations:", #Config.locationsFile.locations)
