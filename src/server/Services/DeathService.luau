--!strict
-- PvP deaths drop backpack contents only. Equipment and personal containers stay in the profile.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local AchievementService = require(script.Parent.AchievementService)

local KEPT_TOOLS = { pickaxe = true, shovel = true, axe = true, sword = true, shears = true }
local ARMOR = { helmet = true, chestplate = true, leggings = true, boots = true }
local rules = Config.rules.survival.death
local random = Random.new()
local DeathService = {}
local started = false

local function inPvp(character: Model, profile: Types.Profile): boolean
	local location = Config.location(profile.location)
	if location and location.pvp == true then
		return true
	end
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { character }
	overlap.MaxParts = 1
	for _, zone in ipairs(CollectionService:GetTagged("PvpZone")) do
		if zone:IsA("BasePart") and zone:IsDescendantOf(workspace) then
			if #workspace:GetPartsInPart(zone, overlap) > 0 then
				return true
			end
		end
	end
	return false
end

local function spawnDrop(stack: Types.ItemStack, position: Vector3, owner: Player)
	local drop = Instance.new("Part")
	drop.Name = "ItemDrop"
	drop.Size = Vector3.new(1.2, 1.2, 1.2)
	drop.Position = position + Vector3.new(random:NextNumber(-1, 1), 1.5, random:NextNumber(-1, 1))
	drop.Color = Color3.fromRGB(150, 125, 90)
	drop.Anchored = false
	drop:SetAttribute("ItemId", stack.id)
	drop:SetAttribute("Level", stack.level or 0)
	drop:SetAttribute("Count", stack.count)
	drop:SetAttribute("OwnerUserId", owner.UserId)
	local icon = Config.iconFor(stack.id, stack.level)
	if icon then
		local billboard = Instance.new("BillboardGui")
		billboard.Size = UDim2.fromOffset(36, 36)
		billboard.StudsOffsetWorldSpace = Vector3.new(0, 1, 0)
		billboard.Adornee = drop
		billboard.Parent = drop
		local image = Instance.new("ImageLabel")
		image.AnchorPoint = Vector2.new(0.5, 0.5)
		image.Position = UDim2.fromScale(0.5, 0.5)
		image.Size = UDim2.fromScale(1, 1)
		image.BackgroundTransparency = 1
		image.ScaleType = Enum.ScaleType.Fit
		image.Image = icon
		image.Parent = billboard
	end
	local busy = false
	drop.Touched:Connect(function(hit: BasePart)
		if busy or not drop:IsDescendantOf(workspace) then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local profile = if player then ProfileService.Get(player) else nil
		if
			not player
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or not profile
		then
			return
		end
		if (root.Position - drop.Position).Magnitude > rules.pickupRadius then
			return
		end
		if not InventoryService.canAdd(profile, stack.id, stack.count) then
			return
		end
		busy = true
		local pickedUp = false
		ProfileService.Mutate(player, function(p)
			if InventoryService.canAdd(p, stack.id, stack.count) then
				pickedUp = InventoryService.add(p, stack.id, stack.count, stack.level) == 0
			end
		end)
		if pickedUp then
			drop:Destroy()
		else
			busy = false
		end
	end)
	CollectionService:AddTag(drop, "ItemDrop")
	drop.Parent = workspace
	-- Server ownership prevents a nearby client moving a drop to claim it remotely.
	drop:SetNetworkOwner(nil)
	drop.AssemblyLinearVelocity = Vector3.new(random:NextNumber(-3, 3), 8, random:NextNumber(-3, 3))
	Debris:AddItem(drop, rules.dropDespawnSeconds)
end

local function died(player: Player, character: Model)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	ProfileService.Mutate(player, function(p)
		p.stats.deaths = (p.stats.deaths or 0) + 1
	end)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local userId = humanoid and humanoid:GetAttribute("LastHitBy")
	local hitAt = humanoid and humanoid:GetAttribute("LastHitAt")
	if
		typeof(userId) == "number"
		and typeof(hitAt) == "number"
		and os.clock() - hitAt >= 0
		and os.clock() - hitAt <= 10
	then
		local killer = Players:GetPlayerByUserId(userId)
		if killer and killer ~= player and ProfileService.Get(killer) then
			local swordHeld = false
			ProfileService.Mutate(killer, function(p)
				p.stats.kills = (p.stats.kills or 0) + 1
				swordHeld = InventoryService.heldTool(p) == "sword"
			end)
			if swordHeld then
				AchievementService.AddProgress(killer, "sword", 1)
			end
		end
	end
	if not character:IsDescendantOf(workspace) or not inPvp(character, profile) then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local position = if root and root:IsA("BasePart")
		then root.Position
		else character:GetPivot().Position
	local drops: { Types.ItemStack } = {}
	ProfileService.Mutate(player, function(p)
		for slot, stack in pairs(p.inventory) do
			if not ARMOR[stack.id] and not (KEPT_TOOLS[stack.id] and Config.tools[stack.id]) then
				table.insert(drops, table.clone(stack))
				p.inventory[slot] = nil
			end
		end
	end)
	for _, stack in ipairs(drops) do
		spawnDrop(stack, position, player)
	end
end

local function bindCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or player.Character ~= character then
		return
	end
	humanoid.Died:Once(function()
		died(player, character)
	end)
end

function DeathService.Start()
	if started then
		return
	end
	started = true
	local function added(player: Player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(bindCharacter, player, character)
		end)
		if player.Character then
			task.spawn(bindCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, player in ipairs(Players:GetPlayers()) do
		added(player)
	end
end

return DeathService
