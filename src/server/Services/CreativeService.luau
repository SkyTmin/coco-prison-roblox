--!strict
-- Creative test mode [владелец 21.10]: any item from a catalog window, instant digging, no damage,
-- no hunger or needs drain. Only in Studio, for the place creator and Config.rules.creative.admins.
-- The player attribute `CreativeAllowed` shows the window button; `Creative` = the mode is on
-- (DigService, HungerService and NeedsService read it). Client → server: Creative(op, a, b).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local ItemInfo = require(Shared.ItemInfo)
local Remotes = require(Shared.Remotes)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

local CreativeService = {}
local rules = Config.rules.creative
local started = false
local catalog: { [string]: boolean } = {}

local function allowed(player: Player): boolean
	return RunService:IsStudio()
		or table.find(rules.admins, player.UserId) ~= nil
		or (game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId)
end

function CreativeService.IsOn(player: Player): boolean
	return player:GetAttribute("Creative") == true
end

local function maxLevel(id: string): number
	local tool = Config.tools[id]
	return if tool then #tool.upgrades + 1 else 0
end

-- an invisible ForceField: every damage source uses Humanoid:TakeDamage, which it blocks
local function shield(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local existing = character:FindFirstChild("CreativeShield")
	if CreativeService.IsOn(player) and not existing then
		local field = Instance.new("ForceField")
		field.Name = "CreativeShield"
		field.Visible = false
		field.Parent = character
	elseif not CreativeService.IsOn(player) and existing then
		existing:Destroy()
	end
end

local function refill(player: Player)
	ProfileService.Mutate(player, function(profile)
		profile.hunger = 20
		for need in pairs(profile.needs) do
			(profile.needs :: any)[need] = 100
		end
	end)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		humanoid.Health = humanoid.MaxHealth
	end
end

local function give(player: Player, id: any, level: any)
	if typeof(id) ~= "string" then
		return
	end
	if id == "ancient_book" then
		-- one max-level book per enchant, always applies (effect id in `level`)
		local effect = Config.books.effects[level]
		local entry = Config.books.catalog[level]
		if typeof(level) ~= "string" or not effect or not entry then
			return
		end
		ProfileService.Mutate(player, function(profile)
			local stack: any = {
				id = "ancient_book",
				count = 1,
				level = #effect,
				books = { { id = level, level = #effect } },
				rarity = entry.rarity,
				applyChance = 100,
			}
			for slot = 1, InventoryService.SLOTS do
				if not profile.inventory[slot] then
					profile.inventory[slot] = stack
					return
				end
			end
		end)
		return
	end
	if not catalog[id] then
		return
	end
	local top = maxLevel(id)
	local itemLevel = if top > 0 then math.clamp(math.floor(tonumber(level) or 1), 1, top) else nil
	local count = if InventoryService.isStackable(id) then rules.stackCount else 1
	ProfileService.Mutate(player, function(profile)
		InventoryService.add(profile, id, count, itemLevel)
	end)
end

local function onRequest(player: Player, op: any, a: any, b: any)
	if not allowed(player) or not ProfileService.Get(player) then
		return
	end
	if op == "toggle" then
		player:SetAttribute("Creative", not CreativeService.IsOn(player))
		shield(player)
		if CreativeService.IsOn(player) then
			refill(player)
		end
	elseif op == "give" then
		give(player, a, b)
	elseif op == "coins" then
		ProfileService.Mutate(player, function(profile)
			profile.coins += 1000 * Config.moneyScale
		end)
	elseif op == "level" then
		ProfileService.Mutate(player, function(profile)
			profile.level = math.min(Config.levels.maxLevel, profile.level + 1)
		end)
		local profile = ProfileService.Get(player) :: Types.Profile
		local rule = Config.levelRule(profile.level)
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and rule then
			humanoid.MaxHealth = rule.hearts * 2
			humanoid.Health = humanoid.MaxHealth
		end
	elseif op == "refill" then
		refill(player)
	elseif op == "clear" then
		ProfileService.Mutate(player, function(profile)
			table.clear(profile.inventory)
		end)
	end
end

function CreativeService.Start()
	if started then
		return
	end
	started = true
	for _, id in ipairs(ItemInfo.knownIds()) do
		catalog[id] = true
	end
	for id in pairs(Config.blocks) do
		catalog[id] = true
	end
	catalog.ancient_book = nil -- books come with their effect (give "ancient_book", effectId)
	Remotes.event("Creative").OnServerEvent:Connect(onRequest)
	local function added(player: Player)
		if allowed(player) then
			player:SetAttribute("CreativeAllowed", true)
		end
		player.CharacterAdded:Connect(function()
			task.defer(shield, player)
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
end

return CreativeService
