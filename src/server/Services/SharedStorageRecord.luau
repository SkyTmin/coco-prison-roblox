--!strict
-- Pure atomic record transform. No cached page can overwrite a newer revision.
local Persistence = require(game:GetService("ReplicatedStorage").Shared.Persistence)
local Record = {}

function Record.decode(raw: any, faction: boolean): any
	local record = if typeof(raw) == "table" then Persistence.copy(raw) else {}
	if faction and record.pages == nil then
		local pages = {}
		for key, value in record do
			if tonumber(key) then
				pages[tostring(key)] = value
			end
		end
		record = { pages = pages }
	end
	record.pages = record.pages or {}
	record.revisions = record.revisions or {}
	record.receipts = record.receipts or {}
	return record
end

function Record.slots(record: any, page: number): any
	local slots = {}
	for key, value in record.pages[tostring(page)] or {} do
		local slot = tonumber(key)
		if slot and slot >= 1 and slot <= 27 and slot == math.floor(slot) then
			slots[slot] = Persistence.copy(value)
		end
	end
	return slots
end

function Record.encode(slots: any): any
	local out = {}
	for slot, stack in slots do
		out[tostring(slot)] = Persistence.copy(stack)
	end
	return out
end

function Record.apply(record: any, operation: any): (any, boolean)
	local receipt = record.receipts[operation.id]
	if receipt then
		return record, receipt.committed
	end
	local page = tostring(operation.page)
	local committed = (record.revisions[page] or 0) == operation.revision
	if committed then
		record.pages[page] = Persistence.copy(operation.afterPage)
		record.revisions[page] = (record.revisions[page] or 0) + 1
	end
	record.receipts[operation.id] = { committed = committed }
	return record, committed
end

return Record
