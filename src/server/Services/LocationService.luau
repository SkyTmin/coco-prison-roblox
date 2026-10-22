--!strict
-- LocationSpawn + LocationId mark arrivals; Teleporter parts open the locations menu.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local CombatService = require(script.Parent.CombatService)

local LocationService = {}
local started = false
local lastTeleport: { [Player]: number } = {}
local prompts: { [Instance]: { prompt: ProximityPrompt, connection: RBXScriptConnection } } = {}
local TELEPORT_INTERVAL = 0.5 -- [решение] throttle repeated client intents
local SPOTS: { [string]: boolean } = {
	spawn = true,
	mine = true,
	small_mine = true,
	market = true,
	canteen = true,
	bedroom = true,
	bath = true,
	trainer = true,
	showcase = true, -- витрина (scripts/build-showcase.luau)
}
type Channel = {
	character: Model,
	humanoid: Humanoid,
	root: BasePart,
	spawn: BasePart,
	locationId: string,
	spot: string?,
	position: Vector3,
	finishesAt: number,
	died: RBXScriptConnection?,
}
local pending: { [Player]: Channel } = {}

-- StreamingEnabled: the destination may not be loaded on the player's device yet — ask for it before
-- moving them there, or they would land on nothing and fall [docs/research/server-scaling.md]
local function streamAround(player: Player, position: Vector3)
	if workspace.StreamingEnabled then
		pcall(player.RequestStreamAroundAsync, player, position, 3)
	end
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function clearChannel(player: Player)
	local channel = pending[player]
	if channel and channel.died then
		channel.died:Disconnect()
	end
	pending[player] = nil
end

local function cancel(player: Player)
	if not pending[player] then
		return
	end
	clearChannel(player)
	Remotes.event("TeleportChannel"):FireClient(player, nil)
	toast(player, "teleport_cancelled")
end

local function matchesSpot(part: BasePart, spot: string?): boolean
	local markedSpot = part:GetAttribute("Spot")
	return if spot then markedSpot == spot else markedSpot == nil or markedSpot == "spawn"
end

-- База фракций [владелец]: every faction has its own spawn (attribute Faction); a spawn without the
-- attribute is for everybody
local function matchesFaction(part: BasePart, faction: string?): boolean
	local marked = part:GetAttribute("Faction")
	return marked == nil or marked == faction
end

-- [клиент] «Необходимо находиться во фракции»
local function factionMissing(location: Config.Location, profile: any): boolean
	return location.requiresFaction == true and not Config.faction(profile.faction)
end

local function teleport(player: Player, locationId: any, spot: any)
	if
		typeof(locationId) ~= "string"
		or (spot ~= nil and (typeof(spot) ~= "string" or not SPOTS[spot]))
	then
		return
	end
	local now = os.clock()
	if now - (lastTeleport[player] or -math.huge) < TELEPORT_INTERVAL then
		return
	end
	lastTeleport[player] = now
	cancel(player)
	if CombatService.inCombat(player) then
		toast(player, "teleport_in_combat", math.ceil(CombatService.remainingSeconds(player)))
		return
	end
	local location = Config.location(locationId)
	if not location then
		toast(player, "location_unknown")
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		toast(player, "teleport_not_ready")
		return
	end
	-- [владелец 22.10] spots (and moving between them) exist only at the spawn
	if spot ~= nil and locationId ~= "prison" then
		return
	end
	local withinCurrent = spot ~= nil and profile.location == locationId
	if not withinCurrent and profile.level < location.unlockLevel then
		toast(player, "level_too_low", location.unlockLevel)
		return
	end
	if not withinCurrent and location.requiresPass and not profile.passes[locationId] then
		toast(player, "location_pass_required")
		return
	end
	if factionMissing(location, profile) then
		toast(player, "faction_required")
		return
	end
	local spawn: BasePart? = nil
	for _, part in ipairs(CollectionService:GetTagged("LocationSpawn")) do
		if
			part:IsA("BasePart")
			and part:IsDescendantOf(workspace)
			and part:GetAttribute("LocationId") == locationId
			and matchesSpot(part, spot)
			and matchesFaction(part, profile.faction)
		then
			spawn = part
			break
		end
	end
	if not spawn then
		toast(player, "location_no_spawn")
		return
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if
		not character
		or not humanoid
		or humanoid.Health <= 0
		or not root
		or not root:IsA("BasePart")
	then
		toast(player, "teleport_not_ready")
		return
	end
	if withinCurrent then
		-- [владелец 21.10] spots inside the current location (Спавн, Шахта, Рынок…) are instant;
		-- the 5 s channel stays for travelling between locations
		streamAround(player, spawn.Position)
		if player.Character ~= character or humanoid.Health <= 0 then
			return
		end
		character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		Remotes.event("TeleportChannel"):FireClient(player, nil)
		return
	end
	local channel: Channel = {
		character = character,
		humanoid = humanoid,
		root = root,
		spawn = spawn,
		locationId = locationId,
		spot = spot,
		position = root.Position,
		finishesAt = os.clock() + Config.rules.teleport.channelSeconds,
	}
	pending[player] = channel
	channel.died = humanoid.Died:Connect(function()
		if pending[player] == channel then
			cancel(player)
		end
	end)
	Remotes.event("TeleportChannel")
		:FireClient(player, Config.rules.teleport.channelSeconds, locationId)
	task.spawn(streamAround, player, spawn.Position) -- loads while the channel counts down
end

local function updateChannels()
	for player, channel in pairs(pending) do
		if
			player.Character ~= channel.character
			or not channel.character:IsDescendantOf(workspace)
			or channel.humanoid.Parent ~= channel.character
			or channel.humanoid.Health <= 0
			or channel.root.Parent ~= channel.character
			or (channel.root.Position - channel.position).Magnitude > Config.rules.teleport.cancelMoveStuds
			or CombatService.inCombat(player)
		then
			cancel(player)
		elseif os.clock() >= channel.finishesAt then
			local profile = ProfileService.Get(player)
			local location = Config.location(channel.locationId)
			local withinCurrent = profile
				and channel.spot ~= nil
				and profile.location == channel.locationId
			if
				not profile
				or not location
				or (not withinCurrent and profile.level < location.unlockLevel)
				or (not withinCurrent and location.requiresPass and not profile.passes[channel.locationId])
				or factionMissing(location, profile)
				or not matchesFaction(channel.spawn, profile.faction)
				or not channel.spawn:IsDescendantOf(workspace)
				or not CollectionService:HasTag(channel.spawn, "LocationSpawn")
				or channel.spawn:GetAttribute("LocationId") ~= channel.locationId
				or not matchesSpot(channel.spawn, channel.spot)
			then
				cancel(player)
				continue
			end
			clearChannel(player)
			channel.character:PivotTo(channel.spawn.CFrame + Vector3.new(0, 4, 0))
			channel.root.AssemblyLinearVelocity = Vector3.zero
			channel.root.AssemblyAngularVelocity = Vector3.zero
			ProfileService.Mutate(player, function(p)
				p.location = channel.locationId
			end)
			Remotes.event("TeleportChannel"):FireClient(player, nil)
		end
	end
end

local function bindPrompt(part: Instance)
	if not part:IsA("BasePart") or prompts[part] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LocationPrompt"
	prompt.ActionText = Strings.t("teleporter_prompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 8
	prompt.Parent = part
	local connection = prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if
			part:IsDescendantOf(workspace)
			and root
			and root:IsA("BasePart")
			and (root.Position - part.Position).Magnitude <= prompt.MaxActivationDistance
		then
			local profile = ProfileService.Get(player)
			local locationId = part:GetAttribute("LocationId")
			local current = profile and (locationId == nil or locationId == profile.location)
			Remotes.event("OpenMenu")
				:FireClient(player, "locations", if current then "spots" else nil)
		end
	end)
	prompts[part] = { prompt = prompt, connection = connection }
end

function LocationService.Start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("Teleporter"):Connect(bindPrompt)
	CollectionService:GetInstanceRemovedSignal("Teleporter"):Connect(function(part)
		local bound = prompts[part]
		if bound then
			bound.connection:Disconnect()
			bound.prompt:Destroy()
			prompts[part] = nil
		end
	end)
	for _, part in ipairs(CollectionService:GetTagged("Teleporter")) do
		bindPrompt(part)
	end
	Remotes.event("Teleport").OnServerEvent:Connect(teleport)
	RunService.Heartbeat:Connect(updateChannels)
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
		clearChannel(player)
	end)
end

return LocationService
