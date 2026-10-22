--!strict
-- The faction storage on the faction base [владелец: у каждой фракции 8 двойных сундуков — общее хранилище;
-- клиент: «Вы не можете открывать сундуки на чужой базе фракции!»]. Shared by every member of the faction:
-- 8 chests of 27 slots (the vanilla chest window) [решение], kept in the DataStore FactionStorage_v1 (one
-- key per faction), saved every 30 s and when the server closes. With several servers the last writer
-- wins — fine while the game runs one server [решение]. CaseService opens the chests (tag FactionChest)
-- and moves the items; this module only keeps the slots.

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

type Slots = { [number]: Types.ItemStack }

local FactionStorageService = {}
FactionStorageService.CHESTS = 8
FactionStorageService.SLOTS = 27
local SAVE_EVERY = 30

local data: { [string]: { [number]: Slots } } = {}
local loading: { [string]: boolean } = {}
local dirty: { [string]: boolean } = {}
local started = false
local storeOk, store = pcall(function()
	return DataStoreService:GetDataStore("FactionStorage_v1")
end)

local function validStack(stack: any): boolean
	return typeof(stack) == "table"
		and typeof(stack.id) == "string"
		and typeof(stack.count) == "number"
		and stack.count >= 1
		and stack.count == math.floor(stack.count)
end

-- Reads one faction's chests (yields on the first call). DataStore keys come back as strings.
local function load(faction: string)
	if data[faction] then
		return
	end
	while loading[faction] do
		task.wait()
	end
	if data[faction] then
		return
	end
	loading[faction] = true
	local chests: { [number]: Slots } = {}
	for i = 1, FactionStorageService.CHESTS do
		chests[i] = {}
	end
	if storeOk then
		local ok, saved = pcall(function()
			return store:GetAsync(faction)
		end)
		if ok and typeof(saved) == "table" then
			for rawChest, slots in pairs(saved) do
				local chest = tonumber(rawChest)
				if chest and chests[chest] and typeof(slots) == "table" then
					for rawSlot, stack in pairs(slots) do
						local slot = tonumber(rawSlot)
						if
							slot
							and slot >= 1
							and slot <= FactionStorageService.SLOTS
							and validStack(stack)
						then
							chests[chest][slot] = stack
						end
					end
				end
			end
		elseif not ok then
			warn("[FactionStorage] load failed", faction, saved)
		end
	end
	data[faction] = chests
	loading[faction] = nil
end

-- The slots of one chest (the live table: change it, then call MarkDirty), nil for a wrong address.
function FactionStorageService.Chest(faction: any, index: any): Slots?
	if
		not Config.faction(faction)
		or typeof(index) ~= "number"
		or index < 1
		or index > FactionStorageService.CHESTS
		or index ~= math.floor(index)
	then
		return nil
	end
	load(faction)
	return data[faction][index]
end

function FactionStorageService.MarkDirty(faction: string)
	dirty[faction] = true
end

local function save(faction: string)
	dirty[faction] = nil
	local chests = data[faction]
	if not storeOk or not chests then
		return
	end
	local out = {}
	for chest, slots in pairs(chests) do
		local encoded = {}
		for slot, stack in pairs(slots) do
			encoded[tostring(slot)] = stack
		end
		out[tostring(chest)] = encoded
	end
	local ok, err = pcall(function()
		store:SetAsync(faction, out)
	end)
	if not ok then
		dirty[faction] = true -- try again next round
		warn("[FactionStorage] save failed", faction, err)
	end
end

function FactionStorageService.Start()
	if started then
		return
	end
	started = true
	-- load everything up front, so opening a chest never waits for the DataStore
	for _, f in ipairs(Config.factions.list) do
		task.spawn(load, f.id)
	end
	task.spawn(function()
		while true do
			task.wait(SAVE_EVERY)
			for faction in pairs(dirty) do
				task.spawn(save, faction)
			end
		end
	end)
	game:BindToClose(function()
		for faction in pairs(dirty) do
			save(faction)
		end
	end)
end

return FactionStorageService
