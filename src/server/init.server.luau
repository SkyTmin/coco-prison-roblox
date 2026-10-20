--!strict
-- Server bootstrap: start services in dependency order.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local Remotes = require(ReplicatedStorage.Shared.Remotes)
-- Create every remote up front so clients never block on WaitForChild.
for _, name in ipairs({
	"DigStart",
	"DigFinish",
	"Sell",
	"BuyItem",
	"UpgradeItem",
	"LevelUp",
	"InventoryMove",
	"SelectSlot",
	"SpendPoint",
	"ClaimPoints",
	"EquipArmor",
	"UseConsumable",
	"OpenCase",
	"ClaimAchievement",
	"CaseOpened",
	"ProfileUpdated",
	"Toast",
	"MineReset",
	"Combo",
	"OpenMenu",
	"Teleport",
	"TeleportChannel",
	"SetLocale",
}) do
	Remotes.event(name)
end

local ProfileService = require(script.Services.ProfileService)
local ProfessionService = require(script.Services.ProfessionService)
local TextureService = require(script.Services.TextureService)
local MineService = require(script.Services.MineService)
local DigService = require(script.Services.DigService)
local EconomyService = require(script.Services.EconomyService)
local NeedsService = require(script.Services.NeedsService)
local AchievementService = require(script.Services.AchievementService)
local CaseService = require(script.Services.CaseService)
local LocationService = require(script.Services.LocationService)
local CombatService = require(script.Services.CombatService)

ProfileService.Start()
ProfessionService.Start()
TextureService.Start()
MineService.Start()
DigService.Start()
EconomyService.Start()
NeedsService.Start()
AchievementService.Start()
CaseService.Start()
CombatService.Start()
LocationService.Start()

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
