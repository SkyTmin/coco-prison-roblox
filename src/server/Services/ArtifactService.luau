--!strict
-- Fragment rolls run inside the caller's profile mutation; clients can only request assembly.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)

export type Notice = { key: string, tier: string, index: number }
local TIERS = { "common", "rare", "epic" }
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX" }
local random = Random.new()
local lastAssemble: { [Player]: number } = {}
local started = false
local ArtifactService = {}

local function stateFor(profile: Types.Profile, tier: string): Types.ArtifactTier
	local state = profile.artifacts[tier]
	if not state then
		state = { fragments = {}, duplicates = 0, completed = 0 }
		profile.artifacts[tier] = state
	end
	return state
end

local function missing(state: Types.ArtifactTier): number?
	for index = 1, Config.artifacts.fragmentsPerArtifact do
		if (state.fragments[index] or 0) < 1 then
			return index
		end
	end
	return nil
end

function ArtifactService.GrantFragment(profile: Types.Profile, tier: string): { Notice }
	local state = stateFor(profile, tier)
	local index = random:NextInteger(1, Config.artifacts.fragmentsPerArtifact)
	local held = state.fragments[index] or 0
	local notices: { Notice } = {}
	if held == 0 then
		state.fragments[index] = 1
		table.insert(notices, { key = "artifact_fragment_found", tier = tier, index = index })
	else
		-- [меню] «каждые 9 дубликатов дают фрагмент, которого у вас ещё нет»: a spare copy only feeds
		-- the duplicates counter; the tile itself stays "owned once" so assembly consumes exactly 9.
		state.duplicates += 1
	end
	-- Retain the counter when the mosaic is full; spend it once a missing tile exists.
	local cost = Config.artifacts.duplicatesPerMissingFragment
	while state.duplicates >= cost do
		local nextMissing = missing(state)
		if not nextMissing then
			break
		end
		state.duplicates -= cost
		state.fragments[nextMissing] = 1
		table.insert(notices, {
			key = "artifact_fragment_from_duplicates",
			tier = tier,
			index = nextMissing,
		})
	end
	return notices
end

function ArtifactService.RollDig(profile: Types.Profile): { Notice }
	local notices: { Notice } = {}
	for _, tier in ipairs(TIERS) do
		if random:NextNumber() < Config.artifacts.tiers[tier].dropChancePerBlock then
			for _, notice in ipairs(ArtifactService.GrantFragment(profile, tier)) do
				table.insert(notices, notice)
			end
		end
	end
	return notices
end

function ArtifactService.Notify(player: Player, notices: { Notice })
	local locale = Strings.localeOf(player)
	for _, notice in ipairs(notices) do
		Remotes.event("Toast"):FireClient(
			player,
			Strings.t(
				notice.key,
				locale,
				Strings.t("artifact_tier_" .. notice.tier, locale),
				ROMAN[notice.index]
			)
		)
	end
end

local function assemble(player: Player, tier: any)
	if
		typeof(tier) ~= "string"
		or not table.find(TIERS, tier)
		or not ProfileService.Get(player)
	then
		return
	end
	local now = os.clock()
	if now - (lastAssemble[player] or -math.huge) < 0.4 then
		return
	end
	lastAssemble[player] = now
	local result = "artifact_need_fragments"
	ProfileService.Mutate(player, function(p)
		local state = stateFor(p, tier)
		if missing(state) then
			return
		end
		if not InventoryService.canAdd(p, "artifact_key", 1) then
			result = "bag_full"
			return
		end
		-- No yields: one complete set pays exactly one key.
		for index = 1, Config.artifacts.fragmentsPerArtifact do
			state.fragments[index] -= 1
		end
		state.completed += 1
		InventoryService.add(p, "artifact_key", 1)
		result = "artifact_assembled"
	end)
	Remotes.event("Toast"):FireClient(
		player,
		Strings.t(
			result,
			Strings.localeOf(player),
			Strings.t("artifact_tier_" .. tier, Strings.localeOf(player))
		)
	)
end

function ArtifactService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("ArtifactAssemble").OnServerEvent:Connect(assemble)
	Players.PlayerRemoving:Connect(function(player)
		lastAssemble[player] = nil
	end)
end

return ArtifactService
