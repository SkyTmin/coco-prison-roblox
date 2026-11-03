--!strict
-- Six hours from initial assignment [owner]. Presence is a hint; one failed redirect falls back
-- to the current public server. Neither teleport data nor a raw launch-data job id is authoritative.
local Players = game:GetService("Players")
local MemoryStoreService = game:GetService("MemoryStoreService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage").Shared
local Profile = require(script.Parent.ProfileService)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Service = {}
local WINDOW = 6 * 60 * 60
local PRESENCE_TTL = 60
local INVITE_TTL = 60 * 60
local assignments: any = nil
local presence: any = nil
local invites: any = nil
local started = false
local routed: { [Player]: boolean } = {}
local flight: { [Player]: string } = {}
local inviteAt: { [Player]: number } = {}

local function toast(player: Player, key: string)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player)))
end

local function record(old: any, jobId: string, now: number): any
	local valid = typeof(old) == "table" and typeof(old.untilAt) == "number" and old.untilAt > now
	return {
		jobId = jobId,
		placeId = game.PlaceId,
		assignedAt = if valid then old.assignedAt else now,
		untilAt = if valid then old.untilAt else now + WINDOW,
	}
end

local function assign(player: Player, jobId: string): any
	local now = os.time()
	return assignments:UpdateAsync(tostring(player.UserId), function(old: any)
		return record(old, jobId, now)
	end, WINDOW)
end

local function available(jobId: any): boolean
	if typeof(jobId) ~= "string" or jobId == "" then
		return false
	end
	if jobId == game.JobId then
		return true
	end
	local state = presence:GetAsync(jobId)
	return typeof(state) == "table"
		and state.placeId == game.PlaceId
		and typeof(state.updatedAt) == "number"
		and os.time() - state.updatedAt < PRESENCE_TTL
		and typeof(state.users) == "number"
		and typeof(state.max) == "number"
		and state.users < state.max
end

local function fallback(player: Player)
	flight[player] = nil
	pcall(assign, player, game.JobId)
	if player.Parent == Players then
		toast(player, "server_affinity_fallback")
	end
end

local function route(player: Player)
	if routed[player] or not Profile.IsReal(player) then
		return
	end
	routed[player] = true
	local ok, err = pcall(function()
		-- FollowUserId is engine-provided on the server. Joining a friend overrides old affinity.
		if player.FollowUserId > 0 then
			assign(player, game.JobId)
			return
		end
		local join = player:GetJoinData()
		local token = typeof(join.LaunchData) == "string"
			and string.match(join.LaunchData, "^affinity:([%x%-]+)$")
		local invitation = if token and #token == 36 then invites:GetAsync(token) else nil
		local invitedJob = if typeof(invitation) == "table"
				and invitation.placeId == game.PlaceId
				and typeof(invitation.expiresAt) == "number"
				and invitation.expiresAt > os.time()
			then invitation.jobId
			else nil
		local state = assignments:GetAsync(tostring(player.UserId))
		local active = typeof(state) == "table"
			and state.placeId == game.PlaceId
			and typeof(state.untilAt) == "number"
			and state.untilAt > os.time()
		local target = if invitedJob then invitedJob else if active then state.jobId else game.JobId
		if target == game.JobId then
			assign(player, game.JobId)
			return
		end
		if not available(target) then
			fallback(player)
			return
		end
		-- Persist incoming gameplay before leaving; pending rewards remain recoverable on the destination.
		if not Profile.SaveNow(player) or player.Parent ~= Players then
			return
		end
		assign(player, target)
		local options = Instance.new("TeleportOptions")
		options.ServerInstanceId = target
		flight[player] = target
		toast(player, "server_affinity_return")
		local teleported =
			pcall(TeleportService.TeleportAsync, TeleportService, game.PlaceId, { player }, options)
		if not teleported then
			fallback(player)
		end
	end)
	if not ok then
		-- MemoryStore outage is availability-only: never deny entry or start a retry loop.
		warn("[ServerAffinity] current server fallback: " .. tostring(err))
		if player.Parent == Players then
			toast(player, "server_affinity_fallback")
		end
	end
end

local function publish()
	presence:SetAsync(game.JobId, {
		placeId = game.PlaceId,
		users = #Players:GetPlayers(),
		max = Players.MaxPlayers,
		updatedAt = os.time(),
	}, PRESENCE_TTL)
end

local function invite(player: Player): string?
	if not Profile.IsReal(player) then
		return nil
	end
	local now = os.clock()
	if inviteAt[player] and now - inviteAt[player] < 5 then
		return nil
	end
	inviteAt[player] = now
	local token = HttpService:GenerateGUID(false)
	local ok = pcall(function()
		invites:SetAsync(token, {
			inviter = player.UserId,
			jobId = game.JobId,
			placeId = game.PlaceId,
			expiresAt = os.time() + INVITE_TTL,
		}, INVITE_TTL)
	end)
	return if ok then "affinity:" .. token else nil
end

function Service.Start()
	if started then
		return
	end
	started = true
	local remote = Remotes.func("ServerInviteRoute")
	remote.OnServerInvoke = function()
		return nil
	end
	-- Native teleport cannot be tested in Studio. Private/reserved servers have their own explicit route.
	if RunService:IsStudio() or game.JobId == "" or game.PrivateServerId ~= "" then
		return
	end
	local ok = pcall(function()
		assignments = MemoryStoreService:GetHashMap("ServerAffinity_v1")
		presence = MemoryStoreService:GetHashMap("ServerPresence_v1")
		invites = MemoryStoreService:GetHashMap("ServerInvites_v1")
	end)
	if not ok then
		return
	end
	pcall(publish) -- one failed heartbeat must not permanently disable later joins/invitations
	remote.OnServerInvoke = invite
	Profile.OnLoaded(route)
	for _, player in Players:GetPlayers() do
		task.spawn(route, player)
	end
	TeleportService.TeleportInitFailed:Connect(function(player, _, _, _, options)
		if flight[player] and options and options.ServerInstanceId == flight[player] then
			fallback(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		routed[player], flight[player], inviteAt[player] = nil, nil, nil
	end)
	game:BindToClose(function()
		pcall(function()
			presence:RemoveAsync(game.JobId)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(20)
			pcall(publish)
		end
	end)
end

return Service
