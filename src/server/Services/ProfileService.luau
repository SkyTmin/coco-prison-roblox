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
		achievements = {},
		stats = {},
		location = "prison",
		operationIds = {},
	}
end

local function keyFor(player: Player): string
	return "User_" .. tostring(player.UserId)
end

local function migrate(data: any): Profile
	local profile = ProfileService.defaultProfile()
	if typeof(data) == "table" and data.schemaVersion == SCHEMA_VERSION then
		for field, value in pairs(data) do
			(profile :: any)[field] = value
		end
	end
	-- older schemas are discarded on purpose during development (no live players yet)
	profile.schemaVersion = SCHEMA_VERSION
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
	local snapshot = session.profile
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
		Remotes.event("ProfileUpdated"):FireClient(player, session.profile)
	end
end

function ProfileService.Start()
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

	Players.PlayerAdded:Connect(load)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local session = sessions[player]
		if session then
			save(player, session)
			sessions[player] = nil
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
