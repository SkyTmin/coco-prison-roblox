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

function TutorialService.OnUpgraded(player: Player, _itemId: string, before: number, after: number)
	if Tutorial.step(Profile.Get(player)) ~= 3 then
		return
	end
	apply(player, function(p)
		return Tutorial.upgraded(p, before, after, os.time())
	end)
end

function TutorialService.Start()
	-- State is part of the initial profile and each transition is saved; no client completion remote.
end

function TutorialService.OnLevelUp(player: Player, before: number, after: number)
	if Tutorial.step(Profile.Get(player)) ~= 4 then
		return
	end
	apply(player, function(p)
		return Tutorial.leveled(p, before, after, os.time())
	end)
end

return TutorialService
