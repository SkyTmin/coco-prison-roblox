--!strict
-- Atomic revisions and escrow replace expiring cache-owner leases and unsafe cache flushes.
local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Gangs = require(Shared.Gangs)
local Storage = require(script.Parent.SharedStorageService)
local GangChestService = {}
GangChestService.SLOTS = 27
GangChestService.PAGES_PER_LEVEL =
	math.max(1, math.floor(Config.gangs.base.chest.slotsPerLevel / 27))
GangChestService.MAX_PAGES = (Gangs.upgrade("chests") :: any).max * GangChestService.PAGES_PER_LEVEL
local opened: { [string]: boolean } = {}

function GangChestService.Open(id: string): (boolean, string?)
	local record = Storage.Read("gang", id, true)
	opened[id] = record ~= nil
	return record ~= nil, if record then nil else "gang_chest_unavailable"
end

function GangChestService.Page(id: string?, page: any): any
	if
		not id
		or not opened[id]
		or typeof(page) ~= "number"
		or not (page >= 1 and page <= 64 and page == math.floor(page))
	then
		return nil
	end
	local slots = Storage.Snapshot("gang", id, page)
	return slots
end

function GangChestService.PageCount(gang: any): number
	if not gang then
		return 0
	end
	local count = math.clamp(
		Gangs.level(gang, "chests") * GangChestService.PAGES_PER_LEVEL,
		0,
		GangChestService.MAX_PAGES
	)
	local record = opened[gang.id] and Storage.Read("gang", gang.id)
	if record then
		for page, slots in record.pages do
			local n = tonumber(page)
			if n and n <= 64 and next(slots) then
				count = math.max(count, n) -- legacy overflow remains withdrawal-only
			end
		end
	end
	return count
end

function GangChestService.Valid(id: string?): boolean
	return id ~= nil and opened[id] == true
end

function GangChestService.Start() end
return GangChestService
