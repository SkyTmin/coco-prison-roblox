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
	"ActivateBooster",
	"CaseOpened",
	"CaseUpdated",
	"CaseOpen",
	"CaseMove",
	"CaseClose",
	"ArtifactAssemble",
	"ProfileUpdated",
	"ProfilePatch",
	"Toast",
	"MineReset",
	"Combo",
	"OpenMenu",
	"Teleport",
	"TeleportChannel",
	"SetLocale",
	"Creative",
	"DropItem",
	"ServerLog",
	"Swing",
	"FactionChoose",
	"HitConfirm",
	"FactionLeave",
	"FactionChestOpened",
	"FactionChestMove",
	"FactionChestClose",
	"SetHudLayout",
}) do
	Remotes.event(name)
end

local AvatarService = require(script.Services.AvatarService)
local NpcBodyService = require(script.Services.NpcBodyService)
local SignService = require(script.Services.SignService)
local ProfileService = require(script.Services.ProfileService)
local ProfessionService = require(script.Services.ProfessionService)
local TextureService = require(script.Services.TextureService)
local MineService = require(script.Services.MineService)
local DigService = require(script.Services.DigService)
local EconomyService = require(script.Services.EconomyService)
local NeedsService = require(script.Services.NeedsService)
local AchievementService = require(script.Services.AchievementService)
local GlobalBoosterService = require(script.Services.GlobalBoosterService)
local BoosterService = require(script.Services.BoosterService)
local AuctionService = require(script.Services.AuctionService)
local CaseService = require(script.Services.CaseService)
local ArtifactService = require(script.Services.ArtifactService)
local LocationService = require(script.Services.LocationService)
local CombatService = require(script.Services.CombatService)
local BowService = require(script.Services.BowService)
local HungerService = require(script.Services.HungerService)
local DeathService = require(script.Services.DeathService)
local TrainerService = require(script.Services.TrainerService)
local FallService = require(script.Services.FallService)
local LavaService = require(script.Services.LavaService)
local LightingService = require(script.Services.LightingService)
local HurtService = require(script.Services.HurtService)
local CreativeService = require(script.Services.CreativeService)
local ItemDropService = require(script.Services.ItemDropService)
local BossService = require(script.Services.BossService)
local FactionService = require(script.Services.FactionService)
local FactionStorageService = require(script.Services.FactionStorageService)
local MobService = require(script.Services.MobService)
local NameplateService = require(script.Services.NameplateService)
local CollisionGroups = require(script.Services.CollisionGroups)
local LeaderboardService = require(script.Services.LeaderboardService)

AvatarService.Start() -- first: the StarterCharacter must exist before anyone spawns
NpcBodyService.Start() -- the map's R15 NPCs → our block body in their costumes
SignService.Start() -- sign posts no longer cover the text
HungerService.Start()
DeathService.Start()
ProfileService.Start()
FactionService.Start()
ProfessionService.Start()
TextureService.Start()
MineService.Start()
DigService.Start()
EconomyService.Start()
NeedsService.Start()
AchievementService.Start()
GlobalBoosterService.Start()
AuctionService.Start()
BoosterService.Start()
CaseService.Start()
ArtifactService.Start()
require(script.Services.MotionService).Start() -- fast movement snapshots between players (client Motion.luau)
CombatService.Start()
BowService.Start()
LocationService.Start()
TrainerService.Start()
FallService.Start()
LavaService.Start()
LightingService.Start()
HurtService.Start()
CreativeService.Start()
ItemDropService.Start()
BossService.Start()
FactionStorageService.Start()
CollisionGroups.Start() -- players and mobs pass through each other
MobService.Start()
NameplateService.Start()
LeaderboardService.Start() -- the spawn top boards (global, OrderedDataStore)
require(ReplicatedStorage.Shared.Sfx).listen() -- creates the Sfx remote clients wait for

-- Hearts by level on spawn
game:GetService("Players").PlayerAdded:Connect(function(player)
	player.AutoJumpEnabled = false -- [владелец] no auto-jump on touch
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.AutoJumpEnabled = false
		task.defer(function()
			local profile = ProfileService.Get(player)
			local rule = if profile then Config.levelRule(profile.level) else nil
			humanoid.MaxHealth = (if rule then rule.hearts else 10) * 2
			humanoid.Health = humanoid.MaxHealth
		end)
	end)
end)

print("[coco-prison] server started, locations:", #Config.locationsFile.locations)
-- Studio: every item needs its name (and books their description) in all locales — see ItemInfo
if game:GetService("RunService"):IsStudio() then
	local missing = require(ReplicatedStorage.Shared.ItemInfo).audit()
	if #missing > 0 then
		warn("[ItemInfo] missing translations: " .. table.concat(missing, ", "))
	end
end
