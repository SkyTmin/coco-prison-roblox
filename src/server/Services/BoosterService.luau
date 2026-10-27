--!strict
-- The booster storage (shared/Boosters): «Активировать» in the storage window. A local booster starts (or queues)
-- inside the profile. A faction / global one goes to the list all servers share (GlobalBoosterService) in three
-- steps that can never duplicate it: (1) take it out of the storage and note it in p.pendingBoosters, save the profile;
-- (2) add it to the shared list under its activation id (an id is added once); (3) clear the note. A crash between
-- the steps is settled on the next profile load: the id in the shared list → drop the note, otherwise → the booster
-- goes back into the storage. The multipliers are read where they apply: DigService (blocks), EconomyService via
-- ProfessionService.moneyMultiplier (money), MobService (mobs).
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local GlobalBoosterService = require(script.Parent.GlobalBoosterService)

local BoosterService = {}
local busy: { [Player]: boolean } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function giveBack(p: any, b: Boosters.Stored)
	Boosters.store(p, b.kind, b.scope, b.mult, b.minutes)
end

local function activateShared(player: Player, index: number, stored: Boosters.Stored)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local scope = Boosters.scopeOf(stored)
	if scope == "faction" and not profile.faction then
		toast(player, "booster_need_faction")
		return
	end
	local id = HttpService:GenerateGUID(false)
	local taken: Boosters.Stored? = nil
	ProfileService.Mutate(player, function(p)
		taken = Boosters.take(p, index)
		if taken then
			p.pendingBoosters = p.pendingBoosters or {}
			p.pendingBoosters[id] = taken
		end
	end)
	if not taken then
		return
	end
	local booster = taken :: Boosters.Stored
	local entry: Boosters.Active? = nil
	if ProfileService.SaveNow(player) then
		entry = GlobalBoosterService.add({
			id = id,
			kind = booster.kind,
			mult = booster.mult,
			scope = scope,
			faction = if scope == "faction" then profile.faction else nil,
			by = player.Name,
			startsAt = 0,
			endsAt = 0,
		}, booster.minutes)
	end
	ProfileService.Mutate(player, function(p)
		if p.pendingBoosters then
			p.pendingBoosters[id] = nil
		end
		if not entry then
			giveBack(p, booster)
		end
	end)
	if not entry then
		toast(player, "booster_try_later")
	end
	-- the start itself is announced to everyone it boosts (GlobalBoosterService)
end

local function activate(player: Player, index: any)
	if typeof(index) ~= "number" or index ~= math.floor(index) or index < 1 or busy[player] then
		return
	end
	local profile = ProfileService.Get(player)
	local stored = profile and profile.boosters and profile.boosters[index]
	if not stored then
		return
	end
	if Boosters.scopeOf(stored) ~= "local" then
		busy[player] = true
		local ok, err = pcall(activateShared, player, index, stored)
		busy[player] = nil
		if not ok then
			warn("[BoosterService] " .. tostring(err))
		end
		return
	end
	local started: Boosters.Stored? = nil
	local queued = false
	ProfileService.Mutate(player, function(p)
		started = Boosters.take(p, index)
		if started then
			queued = Boosters.startLocal(p, started)
		end
	end)
	if started then
		toast(
			player,
			if queued then "booster_queued" else "booster_activated",
			Strings.boosterName(started.kind, nil, Strings.localeOf(player))
		)
	end
end

-- a crash between the steps of a shared activation: settle the notes left in the profile
local function settle(player: Player)
	local profile = ProfileService.Get(player)
	if not profile or not profile.pendingBoosters or next(profile.pendingBoosters) == nil then
		return
	end
	for id, booster in pairs(table.clone(profile.pendingBoosters)) do
		local added = GlobalBoosterService.hasOp(id)
		if added ~= nil then -- nil: the store did not answer, the note waits for the next load
			ProfileService.Mutate(player, function(p)
				if p.pendingBoosters and p.pendingBoosters[id] then
					p.pendingBoosters[id] = nil
					if not added then
						giveBack(p, booster)
					end
				end
			end)
		end
	end
end

function BoosterService.Start()
	Remotes.event("ActivateBooster").OnServerEvent:Connect(activate)
	ProfileService.OnLoaded(settle)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return BoosterService
