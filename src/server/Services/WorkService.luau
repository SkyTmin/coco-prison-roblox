--!strict
-- Work nodes: any BasePart tagged "WorkNode" with attributes
--   Resource (string, id from Config), Generation (number), Depleted (bool).
-- The client sends an intent (node, generation); the server decides everything else
-- (PROTOTYPE-SPEC.md §3, ROBLOX-TECH-NOTES.md). One harvest = one accepted work target.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local TAG = "WorkNode"
local MAX_DISTANCE = 12 -- studs from the character root to the node surface, tune after net tests
local MIN_HIT_INTERVAL = 0.4 -- seconds, server-side rate limit per player
local RESPAWN_SECONDS = 20

local WorkService = {}

local lastHit: { [Player]: number } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function isInteger(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value == math.floor(value)
		and math.abs(value) < 1e9
end

local function prepareNode(node: Instance)
	if not node:IsA("BasePart") then
		return
	end
	if not isInteger(node:GetAttribute("Generation")) then
		node:SetAttribute("Generation", 1)
	end
	if node:GetAttribute("Depleted") == nil then
		node:SetAttribute("Depleted", false)
	end
end

local function setDepleted(node: BasePart, depleted: boolean)
	node:SetAttribute("Depleted", depleted)
	node.Transparency = if depleted then 0.7 else 0
	node.CanCollide = not depleted
end

local function onHarvest(player: Player, node: any, generation: any)
	-- Type and shape checks first: anything odd is dropped silently.
	if
		typeof(node) ~= "Instance"
		or not node:IsA("BasePart")
		or not CollectionService:HasTag(node, TAG)
	then
		return
	end
	if not isInteger(generation) then
		return
	end

	local now = os.clock()
	if now - (lastHit[player] or 0) < MIN_HIT_INTERVAL then
		return
	end
	lastHit[player] = now

	local profile = ProfileService.Get(player)
	if not profile then
		return
	end

	if node:GetAttribute("Generation") ~= generation then
		return -- stale request from a previous generation
	end
	if node:GetAttribute("Depleted") then
		toast(player, "node_depleted")
		return
	end

	local resourceId = node:GetAttribute("Resource")
	local resource = if typeof(resourceId) == "string" then Config.resource(resourceId) else nil
	if not resource then
		return
	end

	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if not root or not root:IsA("BasePart") then
		return
	end
	if (root.Position - node.Position).Magnitude > MAX_DISTANCE + node.Size.Magnitude / 2 then
		toast(player, "too_far")
		return
	end

	if (profile.tools[resource.tool] or 0) < 1 then
		toast(player, "wrong_tool")
		return
	end

	local job, minimumLevel = Config.jobForTool(resource.tool)
	if profile.level < minimumLevel then
		toast(player, "level_too_low", minimumLevel)
		return
	end

	-- "node exists -> node depleted -> reward granted" in one handler, no yields in between.
	setDepleted(node, true)
	local keyFound = false
	ProfileService.Mutate(player, function(p)
		p.inventory[resource.id] = (p.inventory[resource.id] or 0) + 1
		p.workCount += 1
		if job then
			p.jobXp[job] = (p.jobXp[job] or 0) + 1
		end

		local rule = Config.raw.workKey
		p.workKeyCounter += 1
		if
			math.random() < rule.probabilityPerAcceptedTarget
			or p.workKeyCounter >= rule.hardPity
		then
			p.keys.common = (p.keys.common or 0) + 1
			p.workKeyCounter = 0
			keyFound = true
		end
	end)
	if keyFound then
		toast(player, "key_found")
	end

	task.delay(RESPAWN_SECONDS, function()
		if node.Parent then
			node:SetAttribute("Generation", generation + 1)
			setDepleted(node, false)
		end
	end)
end

function WorkService.Start()
	for _, node in ipairs(CollectionService:GetTagged(TAG)) do
		prepareNode(node)
	end
	CollectionService:GetInstanceAddedSignal(TAG):Connect(prepareNode)

	Remotes.event("Harvest").OnServerEvent:Connect(onHarvest)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return WorkService
