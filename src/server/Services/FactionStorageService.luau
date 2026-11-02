--!strict
-- Faction pages are read-only snapshots; writes use the durable transfer journal.
local Config = require(game:GetService("ReplicatedStorage").Shared.Config)
local Storage = require(script.Parent.SharedStorageService)
local FactionStorageService = { CHESTS = 8, SLOTS = 27 }

function FactionStorageService.Chest(faction: any, index: any): any
	if
		not Config.faction(faction)
		or typeof(index) ~= "number"
		or not (index >= 1 and index <= 8 and index == math.floor(index))
	then
		return nil
	end
	local slots = Storage.Snapshot("faction", faction, index)
	return slots
end

function FactionStorageService.Start() end
return FactionStorageService
