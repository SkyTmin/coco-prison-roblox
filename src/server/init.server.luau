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
	"EatStart",
	"EatCancel",
	"Ate",
	"DonateBuy",
	"DonateTopUp",
	"DonateBuyRobux",
	"StashClaim",
	"DonateBought",
	"DonateCrystals",
	"AutoSold",
	"BoosterToItem",
	"BookUse",
	"BookResult",
	"AncientRoll",
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
require(script.Services.FoodService).Start() -- eating over 1.6 s like Minecraft (client Eating.luau)
require(script.Services.DonateService).Start() -- the donate shop: crystals for Robux, goods for crystals
AchievementService.Start()
GlobalBoosterService.Start()
AuctionService.Start()
BoosterService.Start()
CaseService.Start()
ArtifactService.Start()
require(script.Services.MotionService).Start() -- fast movement snapshots between players (client Motion.luau)
CombatService.Start()
require(script.Services.BookService).Start() -- ancient books: applying from the hand, the 32 effects
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

-- Hearts by level [вики LEVELS.md: +0,5 сердца за уровень]: kept on every character once a second — a new character
-- (the profile may load after the first spawn) starts full, a level-up adds the new hearts full [2-player test 27.10:
-- the first spawn came before the profile, a level 50 player had 10 hearts]
local freshCharacters: { [Model]: boolean } = {}
local function watchPlayer(player: Player)
	player.AutoJumpEnabled = false -- [владелец] no auto-jump on touch
	local function added(character: Model)
		freshCharacters[character] = true
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.AutoJumpEnabled = false
	end
	player.CharacterAdded:Connect(added)
	if player.Character then
		task.spawn(added, player.Character)
	end
end
game:GetService("Players").PlayerAdded:Connect(watchPlayer)
for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
	watchPlayer(player)
end
task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(game:GetService("Players"):GetPlayers()) do
			local profile = ProfileService.Get(player)
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not profile or not character or not humanoid or humanoid.Health <= 0 then
				continue
			end
			local rule = Config.levelRule(profile.level)
			-- + the armor book Танк
			local target = (if rule then rule.hearts else 10) * 2
				+ require(script.Services.BookService).bonusHealth(profile)
			if humanoid.MaxHealth ~= target then
				local gained = target - humanoid.MaxHealth
				humanoid.MaxHealth = target
				humanoid.Health = if freshCharacters[character]
					then target
					else math.clamp(humanoid.Health + math.max(0, gained), 0, target)
			end
			freshCharacters[character] = nil
		end
		for character in pairs(freshCharacters) do
			if not character.Parent then
				freshCharacters[character] = nil
			end
		end
	end
end)

print("[coco-prison] server started, locations:", #Config.locationsFile.locations)
-- Studio: every item needs its name (and books their description) in all locales — see ItemInfo
if game:GetService("RunService"):IsStudio() then
	local missing = require(ReplicatedStorage.Shared.ItemInfo).audit()
	if #missing > 0 then
		warn("[ItemInfo] missing translations: " .. table.concat(missing, ", "))
	end
end
