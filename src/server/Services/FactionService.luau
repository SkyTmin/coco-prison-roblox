--!strict
-- Factions [клиент: prison.classic.fraction.*]: Славяне, Афро, Азиаты, Латиносы (Config.factions).
--   * joined from level joinLevel (5) [клиент: «необходимо иметь пятый уровень»];
--   * a faction with too many members refuses and names another [клиент: error.overloaded; сеть: «в каждой
--     фракции может находиться лишь одинаковое количество игроков»] — here: members online on this server,
--     a faction may be at most balanceSlack ahead of the smallest one [решение];
--   * leaving costs leaveCost $ [меню: «покинуть фракцию за 2500 $»] and counts «Смен фракций»;
--     whoever leaves while on the faction base goes back to the prison spawn;
--   * the faction is mirrored to the player attribute Faction (nameplates, PvP, chests read it).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local FactionService = {}
local started = false
local lastAction: { [Player]: number } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function factionName(id: string?, player: Player): string
	return Strings.t("faction_" .. (id or "none"), Strings.localeOf(player))
end

function FactionService.Of(player: Player): string?
	local profile = ProfileService.Get(player)
	return if profile and Config.faction(profile.faction) then profile.faction else nil
end

-- Two players of the same faction (both in one) do not hurt each other [сеть, патч 2022]
function FactionService.Same(a: Player, b: Player): boolean
	local fa = FactionService.Of(a)
	return fa ~= nil and fa == FactionService.Of(b)
end

local function mirror(player: Player)
	player:SetAttribute("Faction", FactionService.Of(player) or "")
end

local function counts(except: Player?): { [string]: number }
	local out = {}
	for _, f in ipairs(Config.factions.list) do
		out[f.id] = 0
	end
	for _, other in ipairs(Players:GetPlayers()) do
		local id = if other ~= except then FactionService.Of(other) else nil
		if id then
			out[id] += 1
		end
	end
	return out
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or -math.huge) < 0.5 then
		return true
	end
	lastAction[player] = now
	return false
end

local function choose(player: Player, id: any)
	if throttled(player) or not Config.faction(id) then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	if Config.faction(profile.faction) then
		toast(player, "faction_already", factionName(profile.faction, player))
		return
	end
	if profile.level < Config.factions.joinLevel then
		toast(player, "faction_level", Config.factions.joinLevel)
		return
	end
	local n = counts(player)
	local smallest, smallestId = math.huge, id
	for _, f in ipairs(Config.factions.list) do
		if n[f.id] < smallest then
			smallest, smallestId = n[f.id], f.id
		end
	end
	if n[id] - smallest >= Config.factions.balanceSlack then
		toast(
			player,
			"faction_overloaded",
			factionName(id, player),
			factionName(smallestId, player)
		)
		return
	end
	ProfileService.Mutate(player, function(p)
		p.faction = id
	end)
	mirror(player)
	toast(player, "faction_joined", factionName(id, player))
end

-- the prison spawn (LocationSpawn of "prison" without a spot)
local function prisonSpawn(): BasePart?
	for _, part in ipairs(CollectionService:GetTagged("LocationSpawn")) do
		if
			part:IsA("BasePart")
			and part:IsDescendantOf(workspace)
			and part:GetAttribute("LocationId") == "prison"
			and (part:GetAttribute("Spot") == nil or part:GetAttribute("Spot") == "spawn")
		then
			return part
		end
	end
	return nil
end

local function leave(player: Player)
	if throttled(player) then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local old = profile.faction
	if not Config.faction(old) then
		toast(player, "faction_none_yet")
		return
	end
	local cost = math.floor(Config.factions.leaveCost * Config.moneyScale + 0.5)
	if profile.coins < cost then
		toast(player, "not_enough_money")
		return
	end
	local wasOnBase = profile.location == "fraction_base"
	ProfileService.Mutate(player, function(p)
		p.coins -= cost
		p.faction = nil
		p.factionChanges = (p.factionChanges or 0) + 1
		if wasOnBase then
			p.location = "prison"
		end
	end)
	mirror(player)
	toast(player, "faction_left", factionName(old, player))
	if wasOnBase then
		local spawn = prisonSpawn()
		local character = player.Character
		if spawn and character then
			pcall(player.RequestStreamAroundAsync, player, spawn.Position, 3)
			character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		end
	end
end

function FactionService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("FactionChoose").OnServerEvent:Connect(choose)
	Remotes.event("FactionLeave").OnServerEvent:Connect(leave)
	local function watch(player: Player)
		task.spawn(function()
			for _ = 1, 60 do
				if ProfileService.Get(player) then
					mirror(player)
					return
				end
				task.wait(0.5)
			end
		end)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
end

return FactionService
