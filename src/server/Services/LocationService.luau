--!strict
-- LocationSpawn + LocationId mark arrivals; Teleporter parts open the locations menu.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local LocationService = {}
local started = false
local lastTeleport: { [Player]: number } = {}
local prompts: { [Instance]: { prompt: ProximityPrompt, connection: RBXScriptConnection } } = {}
local TELEPORT_INTERVAL = 0.5 -- [решение] throttle repeated client intents

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function teleport(player: Player, locationId: any)
	if typeof(locationId) ~= "string" then
		return
	end
	local now = os.clock()
	if now - (lastTeleport[player] or -math.huge) < TELEPORT_INTERVAL then
		return
	end
	lastTeleport[player] = now
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
	if profile.level < location.unlockLevel then
		toast(player, "level_too_low", location.unlockLevel)
		return
	end
	if location.requiresPass and not profile.passes[locationId] then
		toast(player, "location_pass_required")
		return
	end
	local spawn: BasePart? = nil
	for _, part in ipairs(CollectionService:GetTagged("LocationSpawn")) do
		if
			part:IsA("BasePart")
			and part:IsDescendantOf(workspace)
			and part:GetAttribute("LocationId") == locationId
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
	character:PivotTo(spawn.CFrame + Vector3.new(0, 4, 0))
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	ProfileService.Mutate(player, function(p)
		p.location = locationId
	end)
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
			Remotes.event("OpenMenu"):FireClient(player, "locations")
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
	Players.PlayerRemoving:Connect(function(player)
		lastTeleport[player] = nil
	end)
end

return LocationService
