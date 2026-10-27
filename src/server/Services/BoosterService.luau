--!strict
-- The booster storage (shared/Boosters): «Активировать» in the storage window starts a stored local booster or
-- queues it behind the running one of its kind. The multipliers are read where they apply: DigService (blocks),
-- EconomyService (money), MobService (mobs).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local BoosterService = {}

local function activate(player: Player, index: any)
	if
		typeof(index) ~= "number"
		or index ~= math.floor(index)
		or index < 1
		or not ProfileService.Get(player)
	then
		return
	end
	local started: Boosters.Stored? = nil
	local queued = false
	ProfileService.Mutate(player, function(p)
		started, queued = Boosters.activate(p, index)
	end)
	if started then
		local locale = Strings.localeOf(player)
		Remotes.event("Toast"):FireClient(
			player,
			Strings.t(
				if queued then "booster_queued" else "booster_activated",
				locale,
				Strings.t("booster_local_" .. started.kind, locale)
			)
		)
	end
end

function BoosterService.Start()
	Remotes.event("ActivateBooster").OnServerEvent:Connect(activate)
end

return BoosterService
