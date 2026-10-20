--!strict
-- Player profiles (schema v3). In-memory per player, saved on leave / close / every AUTOSAVE_SECONDS.
-- Rules: failed load => session never saved; all mutations via Mutate(); client gets copies only.
-- TODO before public test: session locking, per-key save queue, bounded retries with jitter.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Types = require(Shared.Types)
local Remotes = require(Shared.Remotes)
local Config = require(Shared.Config)

type Profile = Types.Profile
type Session = { profile: Profile, loadFailed: boolean, dirty: boolean, saving: boolean }

local STORE_NAME = "PlayerProfiles_v3"
local SCHEMA_VERSION = 3
local AUTOSAVE_SECONDS = 120

local ProfileService = {}
local sessions: { [Player]: Session } = {}
local store: DataStore? = nil

function ProfileService.defaultProfile(): Profile
	return {
		schemaVersion = SCHEMA_VERSION,
		level = 1,
		coins = 0,
		blocksTotal = 0,
		counters = {},
		inventory = { [1] = { id = "shovel", count = 1, level = 1, books = {} } }, -- starting shovel [владелец]
		caseContents = {},
		enderChest = {},
		artifacts = {},
		armor = {},
		selectedSlot = 1,
		professions = {
			xp = { mason = 0, surveyor = 0, blademaster = 0 },
			level = { mason = 0, surveyor = 0, blademaster = 0 },
			points = 0,
			upgrades = { blocks = 0, money = 0, mobs = 0 },
		},
		keys = {},
		passes = {},
		needs = { hygiene = 100, sleep = 100, toilet = 100 },
		hunger = Config.rules.survival.hunger.max,
		achievements = {},
		stats = {},
		location = "prison",
		operationIds = {},
	}
end

local function keyFor(player: Player): string
	return "User_" .. tostring(player.UserId)
end

-- DataStore turns sparse numeric keys into strings: inventory slots are stored as string keys
-- and restored to numbers on load.
local function encodeInventory(inv: { [number]: Types.ItemStack }): { [string]: Types.ItemStack }
	local out = {}
	for slot, stack in pairs(inv) do
		out[tostring(slot)] = stack
	end
	return out
end

local function decodeInventory(inv: any): { [number]: Types.ItemStack }
	local out = {}
	if typeof(inv) == "table" then
		for slot, stack in pairs(inv) do
			local n = tonumber(slot)
			if n then
				out[n] = stack
			end
		end
	end
	return out
end

local function migrate(data: any): Profile
	local profile = ProfileService.defaultProfile()
	if typeof(data) == "table" and data.schemaVersion == SCHEMA_VERSION then
		for field, value in pairs(data) do
			(profile :: any)[field] = value
		end
		profile.inventory = decodeInventory(data.inventory)
		profile.enderChest = decodeInventory(data.enderChest)
		for slot in pairs(profile.enderChest) do
			if
				slot < 1
				or slot > Config.rules.survival.enderChest.slots
				or slot ~= math.floor(slot)
			then
				profile.enderChest[slot] = nil
			end
		end
		profile.caseContents = {}
		if typeof(data.caseContents) == "table" then
			for _, id in ipairs({ "ordinaryCase", "ancientCase", "artifactCase" }) do
				local contents = decodeInventory(data.caseContents[id])
				for slot in pairs(contents) do
					if slot < 1 or slot > 27 or slot ~= math.floor(slot) then
						contents[slot] = nil
					end
				end
				profile.caseContents[id] = contents
			end
		end
	end
	-- older schemas are discarded on purpose during development (no live players yet)
	profile.schemaVersion = SCHEMA_VERSION
	-- Numeric fragment keys can return as strings from DataStore, just like inventory slots.
	local rawArtifacts = profile.artifacts
	profile.artifacts = {}
	local function count(value: any): number
		return if typeof(value) == "number"
				and value == value
				and value < math.huge
			then math.max(0, math.floor(value))
			else 0
	end
	for _, tier in ipairs({ "common", "rare", "epic" }) do
		local raw = if typeof(rawArtifacts) == "table" then rawArtifacts[tier] else nil
		local state: Types.ArtifactTier = { fragments = {}, duplicates = 0, completed = 0 }
		if typeof(raw) == "table" then
			state.duplicates, state.completed = count(raw.duplicates), count(raw.completed)
			if typeof(raw.fragments) == "table" then
				for index = 1, 9 do
					state.fragments[index] = count(
						(raw.fragments :: any)[index] or (raw.fragments :: any)[tostring(index)]
					)
				end
			end
		end
		profile.artifacts[tier] = state
	end
	-- v3 remains compatible. Seed absent chain counters once, without paying legacy progress.
	local seeds: { [string]: number } = { pickaxe = 0, shovel = 0, axe = 0, sword = 0 }
	local seen: { [string]: boolean } = {}
	for _, block in pairs(Config.blocks) do
		local counter = block.upgradeCounter
		local chain = block.tool
		if counter and seeds[chain] ~= nil and not seen[counter] then
			seen[counter] = true
			seeds[chain] += profile.counters[counter] or 0
		end
	end
	local cfg = Config.achievementsCfg
	for chain, definition in pairs(cfg.chains) do
		if profile.counters[definition.counter] == nil then
			local count = seeds[chain] or 0
			profile.counters[definition.counter] = count
			local satisfied = 0
			for tier = 1, cfg.tiers do
				if count < math.round(cfg.thresholdBase * cfg.thresholdGrowth ^ (tier - 1)) then
					break
				end
				satisfied = tier
			end
			profile.achievements[chain] = math.max(profile.achievements[chain] or 0, satisfied)
		end
	end
	for id in pairs(profile.achievements) do
		if string.sub(id, 1, 7) == "digger_" then
			profile.achievements[id] = nil
		end
	end
	local hunger = profile.hunger
	profile.hunger = if typeof(hunger) == "number" and hunger == hunger
		then math.clamp(hunger, 0, Config.rules.survival.hunger.max)
		else Config.rules.survival.hunger.max
	if
		typeof(profile.locale) ~= "string"
		or not table.find(Config.rules.ui.locales, profile.locale)
	then
		profile.locale = nil
	end
	return profile
end

local function load(player: Player)
	local ok, result = false, nil
	if store then
		ok, result = pcall(function()
			return (store :: DataStore):GetAsync(keyFor(player))
		end)
	end
	local session: Session = {
		profile = migrate(if ok then result else nil),
		loadFailed = not ok,
		dirty = false,
		saving = false,
	}
	if not ok then
		warn(
			string.format(
				"[ProfileService] load failed for %s (%s); session will NOT be saved",
				player.Name,
				tostring(result)
			)
		)
	end
	sessions[player] = session
	ProfileService.Replicate(player)
end

local function save(player: Player, session: Session)
	if session.loadFailed or session.saving or not store then
		return
	end
	session.saving = true
	local snapshot = table.clone(session.profile) :: any
	snapshot.inventory = encodeInventory(session.profile.inventory)
	snapshot.enderChest = encodeInventory(session.profile.enderChest)
	snapshot.caseContents = {}
	snapshot.artifacts = {}
	for tier, state in pairs(session.profile.artifacts) do
		local fragments: { [string]: number } = {}
		for index, amount in pairs(state.fragments) do
			fragments[tostring(index)] = amount
		end
		snapshot.artifacts[tier] = {
			fragments = fragments,
			duplicates = state.duplicates,
			completed = state.completed,
		}
	end
	for id, contents in pairs(session.profile.caseContents) do
		snapshot.caseContents[id] = encodeInventory(contents)
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function()
			return snapshot
		end)
	end)
	session.saving = false
	if ok then
		session.dirty = false
	else
		warn(string.format("[ProfileService] save failed for %s: %s", player.Name, tostring(err)))
	end
end

function ProfileService.Get(player: Player): Profile?
	local session = sessions[player]
	return if session then session.profile else nil
end

function ProfileService.Mutate(player: Player, mutator: (Profile) -> ())
	local session = sessions[player]
	if not session then
		return
	end
	mutator(session.profile)
	session.dirty = true
	ProfileService.Replicate(player)
end

function ProfileService.Replicate(player: Player)
	local session = sessions[player]
	if session then
		local character = player.Character
		local stack = session.profile.inventory[session.profile.selectedSlot]
		if character then
			character:SetAttribute(
				"HeldItem",
				if stack then stack.id .. ":" .. tostring(stack.level or 0) else ""
			)
			local armor: { string } = {}
			for _, id in ipairs({ "helmet", "chestplate", "leggings", "boots" }) do
				local piece = session.profile.armor[id]
				if piece then
					table.insert(armor, id .. ":" .. tostring(piece.level or 1))
				end
			end
			character:SetAttribute("Armor", table.concat(armor, ","))
		end
		player:SetAttribute("Locale", session.profile.locale or Config.rules.ui.defaultLocale)
		Remotes.event("ProfileUpdated"):FireClient(player, session.profile)
	end
end

function ProfileService.Start()
	Remotes.event("SetLocale").OnServerEvent:Connect(function(player: Player, locale: any)
		if typeof(locale) ~= "string" or not table.find(Config.rules.ui.locales, locale) then
			return
		end
		local profile = ProfileService.Get(player)
		if not profile or profile.locale == locale then
			return
		end
		ProfileService.Mutate(player, function(p)
			p.locale = locale
		end)
	end)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn(
			"[ProfileService] DataStore unavailable ("
				.. tostring(result)
				.. "); running without saves"
		)
	end

	local function added(player: Player)
		player.CharacterAdded:Connect(function()
			ProfileService.Replicate(player)
		end)
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			sessions[player] = nil
			while session.saving do
				task.wait(0.1) -- let an autosave in flight finish, then write the final state
			end
			save(player, session)
		end
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		for player, session in pairs(sessions) do
			save(player, session)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_SECONDS)
			for player, session in pairs(sessions) do
				if session.dirty then
					save(player, session)
				end
			end
		end
	end)
end

return ProfileService
