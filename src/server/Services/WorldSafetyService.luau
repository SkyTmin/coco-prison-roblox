--!strict
-- Exterior collision guards plus server-side recovery when physics tunnels through a wall/net.
-- A recovery can only use an authorized arrival inside the exact region that the player left.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Bounds = require(Shared.LocationBounds)
local Config = require(Shared.Config)
local Profile = require(script.Parent.ProfileService)
local Gangs = require(script.Parent.GangService)
local Fall = require(script.Parent.FallService)
local Locations = require(script.Parent.LocationService)
local Service = {}
type Region = Bounds.Region
type Track = { character: Model, region: Region }
local regions: { [Instance]: Region } = {}
local tracks: { [Player]: Track } = {}
local rescuing: { [Player]: Model } = {}
local started = false

local function allowed(region: Region, player: Player): boolean
	local profile = Profile.Get(player)
	if not profile then
		return false
	end
	local location = Config.location(region.id)
	if not location or (location.requiresFaction and not Config.faction(profile.faction)) then
		return false
	end
	if location.requiresGang then
		if not Gangs.gangOf(profile) then
			return false
		end
		if
			location.requiresGangUpgrade
			and Gangs.level(profile, location.requiresGangUpgrade) < 1
		then
			return false
		end
	end
	local owner = region.root:GetAttribute("GangId")
	if owner ~= nil then
		local gang = Gangs.gangOf(profile)
		return gang ~= nil and gang.id == owner
	elseif region.privateMine then
		local gang = Gangs.gangOf(profile)
		local anchor = region.root:FindFirstChild("Anchor")
		return gang ~= nil
			and Gangs.level(profile, "ghetto") >= 1
			and anchor ~= nil
			and anchor:GetAttribute("GangMineOwner") == gang.id
			and (tonumber(anchor:GetAttribute("GangMineUntil")) or 0) > os.time()
	end
	return region.id ~= "gang_base"
end

local function arrival(region: Region, player: Player): BasePart?
	if not region.root:IsDescendantOf(workspace) or not allowed(region, player) then
		return nil
	end
	local profile = Profile.Get(player)
	local preferred: BasePart? = nil
	for _, part in ipairs(CollectionService:GetTagged("LocationSpawn")) do
		if
			not part:IsA("BasePart")
			or not part:IsDescendantOf(region.root)
			or part:GetAttribute("LocationId") ~= region.id
		then
			continue
		end
		local spot = part:GetAttribute("Spot")
		local faction = part:GetAttribute("Faction")
		if
			(faction ~= nil and faction ~= profile.faction)
			or (region.privateMine ~= true and part:GetAttribute("PrivateArrival") == true)
			or (not region.showcase and spot ~= nil and spot ~= "spawn")
		then
			continue
		end
		-- Excluded nested private rooms are not part of the public district's destination set.
		if not Bounds.Contains(region, part.Position) then
			continue
		end
		if faction ~= nil then
			return part
		end
		preferred = preferred or part
	end
	return preferred
end

function Service.Register(root: Instance, id: string): Region?
	local region = Bounds.Apply(root, id)
	if region then
		regions[root] = region
	end
	return region
end

local function recover(player: Player, region: Region): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local target = arrival(region, player)
	local profile = Profile.Get(player)
	if
		rescuing[player]
		or not character
		or not root
		or not root:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or not target
		or not profile
	then
		return false
	end
	rescuing[player] = character
	local originalLocation, frozenAt, wasAnchored = profile.location, root.Position, root.Anchored
	root.Anchored = true -- streaming can yield; do not keep falling towards FallenPartsDestroyHeight
	root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
	Fall.Reset(player)
	task.spawn(function()
		if workspace.StreamingEnabled then
			pcall(player.RequestStreamAroundAsync, player, target.Position, 3)
		end
		local current = Profile.Get(player)
		-- A respawn, concurrent teleport, eviction, lease expiry or removed house cancels this recovery.
		if
			rescuing[player] == character
			and player.Character == character
			and character.Parent
			and root.Parent == character
			and humanoid.Health > 0
			and current
			and current.location == originalLocation
			and regions[region.root] == region
			and (root.Position - frozenAt).Magnitude < 0.1
			and arrival(region, player) == target
		then
			Locations.CancelForRecovery(player)
			Fall.Reset(player)
			character:PivotTo(target.CFrame + Vector3.new(0, 4, 0))
			root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
			-- No damage for escaping scenery. Genuine falls inside the location retain FallService damage.
		end
		if root.Parent then
			root.Anchored = wasAnchored
		end
		if rescuing[player] == character then
			rescuing[player] = nil
		end
	end)
	return true
end

-- Compatibility for existing VoidCatch markup: use the net's containing region, never a global first spawn.
function Service.Catch(player: Player, net: BasePart): boolean
	local track = tracks[player]
	if track and track.character == player.Character then
		return if net:IsDescendantOf(track.region.root)
			then recover(player, track.region)
			else false
	end
	local profile = Profile.Get(player)
	for _, region in pairs(regions) do
		if profile and region.id == profile.location and net:IsDescendantOf(region.root) then
			return recover(player, region)
		end
	end
	return false
end

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local profile = Profile.Get(player)
		if
			not character
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or not profile
		then
			tracks[player] = nil
			continue
		end
		if rescuing[player] then
			continue
		end
		local position = root.Position
		local track = tracks[player]
		if
			track
			and (track.character ~= character or not track.region.root:IsDescendantOf(workspace))
		then
			track, tracks[player] = nil, nil
		end
		-- Observe the new destination BEFORE testing the old envelope. Real teleports therefore never
		-- bounce back; a fresh character physically at the prison is not sent to an old saved location.
		for _, region in pairs(regions) do
			if
				region.root:IsDescendantOf(workspace)
				and allowed(region, player)
				and (region.id == profile.location or (not track and region.id == "prison"))
				and Bounds.Contains(region, position, 2)
			then
				track = { character = character, region = region }
				tracks[player] = track
				break
			end
		end
		if track then
			if Bounds.Escaped(track.region, position) then
				recover(player, track.region)
			end
		else
			-- Server start/rejoin with no observed frame on the floor: use only the saved location's
			-- footprint, never the next map below it or a globally nearest spawn.
			for _, region in pairs(regions) do
				if
					region.id == profile.location
					and region.root:IsDescendantOf(workspace)
					and allowed(region, player)
					and position.Y < region.floor
					and position.X >= region.min.X
					and position.X <= region.max.X
					and position.Z >= region.min.Z
					and position.Z <= region.max.Z
				then
					recover(player, region)
					break
				end
			end
		end
	end
end

function Service.Start()
	if started then
		return
	end
	started = true
	for _, region in ipairs(Bounds.ApplyWorld(workspace)) do
		regions[region.root] = region
	end
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player], rescuing[player] = nil, nil
	end)
	workspace.ChildRemoved:Connect(function(root)
		regions[root] = nil
	end)
end

return Service
