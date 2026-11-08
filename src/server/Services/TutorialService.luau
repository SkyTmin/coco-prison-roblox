--!strict
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tutorial = require(Shared.Tutorial)
local Profile = require(script.Parent.ProfileService)
local TutorialService = {}

local function apply(player: Player, change: (any) -> boolean)
	if not Profile.IsReal(player) then
		return
	end
	local changed = false
	Profile.Mutate(player, function(p: any)
		changed = change(p)
	end)
	if changed then
		task.spawn(Profile.SaveNow, player)
	end
end

-- Compatibility hooks: no synthetic counters/reward. Real mining and sales already replicate goals.
function TutorialService.OnDug(
	_player: Player,
	_mineId: string,
	_dropId: string,
	_received: number,
	_sold: number
)
end
function TutorialService.OnSold(_player: Player, _items: { [string]: number }) end

function TutorialService.OnUpgraded(player: Player, itemId: string, before: number, after: number)
	local profile = Profile.Get(player)
	local tracked = profile
		and profile.settings
		and profile.settings.trackedUpgrade == itemId .. ":" .. before
	if not tracked and (itemId ~= "shovel" or Tutorial.step(profile) ~= 3) then
		return
	end
	apply(player, function(p)
		local changed = Tutorial.advanceTrackedUpgrade(p, itemId, before, after)
		if itemId == "shovel" then
			changed = Tutorial.upgraded(p, before, after, os.time()) or changed
		end
		return changed
	end)
end

-- [владелец 08.11] the pickaxe and Каменоломня steps
function TutorialService.OnBought(player: Player, itemId: string)
	local profile = Profile.Get(player)
	if not profile or Tutorial.step(profile) ~= Tutorial.PICKAXE or itemId ~= "pickaxe" then
		return
	end
	apply(player, function(p)
		return Tutorial.bought(p, itemId, os.time())
	end)
end

function TutorialService.OnArrived(player: Player, locationId: string)
	local profile = Profile.Get(player)
	if not profile or Tutorial.step(profile) ~= Tutorial.QUARRY or locationId ~= "quarry" then
		return
	end
	apply(player, function(p)
		return Tutorial.arrived(p, os.time())
	end)
end

function TutorialService.Start()
	-- State is part of the initial profile and each transition is saved; no client completion remote.
end

function TutorialService.OnLevelUp(player: Player, before: number, after: number)
	if after < 2 then
		return
	end
	apply(player, function(p)
		return Tutorial.leveled(p, before, after, os.time())
	end)
end

return TutorialService
