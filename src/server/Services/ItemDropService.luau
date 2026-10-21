--!strict
-- Items lying on the ground: death loot (DeathService) and items a player throws away (DropItem).
-- Like Minecraft: a thrown stack flies forward and can be picked up by anyone who walks over it after
-- a short delay; tools and armor cannot be thrown [владелец 21.10]. Every rules.drops.clearEverySeconds
-- the server removes all of them with a warning first (ClearLag on Minecraft servers), and never keeps
-- more than rules.drops.maxOnServer at once — with many players the ground must not fill with parts.
-- Client → server: DropItem(slot, count?) — count nil = the whole stack.

local CollectionService = game:GetService("CollectionService")
local MaterialService = game:GetService("MaterialService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

local ItemDropService = {}
local deathRules = Config.rules.survival.death
local rules = Config.rules.survival.drops
local random = Random.new()
local order: { BasePart } = {} -- oldest first, for the server-wide cap
local dropTimes: { [Player]: { number } } = {}
local started = false

local function toastAll(key: string, ...: any)
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
	end
end

-- Puts a picked-up stack into the bag. Unstackable items keep their extra data (book effects, coins).
local function give(profile: Types.Profile, stack: Types.ItemStack): boolean
	if InventoryService.isStackable(stack.id) then
		if not InventoryService.canAdd(profile, stack.id, stack.count) then
			return false
		end
		return InventoryService.add(profile, stack.id, stack.count, stack.level) == 0
	end
	for slot = 1, InventoryService.SLOTS do
		if not profile.inventory[slot] then
			profile.inventory[slot] = table.clone(stack)
			return true
		end
	end
	return false
end

local function remove(drop: BasePart)
	local i = table.find(order, drop)
	if i then
		table.remove(order, i)
	end
	drop:Destroy()
end

function ItemDropService.Spawn(
	stack: Types.ItemStack,
	position: Vector3,
	velocity: Vector3,
	pickupDelay: number
)
	local drop = Instance.new("Part")
	drop.Name = "ItemDrop"
	drop.Size = Vector3.one * 1.2
	drop.Position = position
	drop.Anchored = false
	drop.CanQuery = false
	drop.CastShadow = false
	local block = Config.block(stack.id)
	if block and not block.itemOnly and MaterialService:FindFirstChild("px_" .. stack.id) then
		-- a small block of its own texture, like a dropped block in Minecraft
		drop.Size = Vector3.one * 1
		drop.Material = Enum.Material.Plastic
		drop.MaterialVariant = "px_" .. stack.id
	else
		drop.Color = Color3.fromRGB(150, 125, 90)
		drop.Transparency = 0.6
		local icon = Config.iconFor(stack.id, stack.level)
		if icon then
			local billboard = Instance.new("BillboardGui")
			billboard.Size = UDim2.fromOffset(36, 36)
			billboard.Adornee = drop
			billboard.MaxDistance = 80
			billboard.Parent = drop
			local image = Instance.new("ImageLabel")
			image.Size = UDim2.fromScale(1, 1)
			image.BackgroundTransparency = 1
			image.ScaleType = Enum.ScaleType.Fit
			image.ResampleMode = Enum.ResamplerMode.Pixelated
			image.Image = icon
			image.Parent = billboard
		end
	end
	drop:SetAttribute("ItemId", stack.id)
	drop:SetAttribute("Level", stack.level or 0)
	drop:SetAttribute("Count", stack.count)
	local pickupAt = os.clock() + pickupDelay
	local busy = false
	drop.Touched:Connect(function(hit: BasePart)
		if busy or os.clock() < pickupAt or not drop:IsDescendantOf(workspace) then
			return
		end
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = if character then Players:GetPlayerFromCharacter(character) else nil
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			not player
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or not ProfileService.Get(player)
			or (root.Position - drop.Position).Magnitude > deathRules.pickupRadius
		then
			return
		end
		busy = true
		local pickedUp = false
		ProfileService.Mutate(player, function(p)
			pickedUp = give(p, stack)
		end)
		if pickedUp then
			Sfx.toPlayer(player, "pickup", 0.5, 1.4 + math.random() * 0.4)
			remove(drop)
		else
			busy = false
		end
	end)
	CollectionService:AddTag(drop, "ItemDrop")
	drop.Parent = workspace
	-- server ownership: a nearby client cannot move a drop to claim it remotely
	drop:SetNetworkOwner(nil)
	drop.AssemblyLinearVelocity = velocity
	table.insert(order, drop)
	while #order > rules.maxOnServer do
		remove(order[1])
	end
end

-- death loot scatters around the body
function ItemDropService.SpawnLoot(stack: Types.ItemStack, position: Vector3)
	ItemDropService.Spawn(
		stack,
		position + Vector3.new(random:NextNumber(-1, 1), 1.5, random:NextNumber(-1, 1)),
		Vector3.new(random:NextNumber(-3, 3), 8, random:NextNumber(-3, 3)),
		0
	)
end

local function onDropItem(player: Player, slot: any, count: any)
	if not InventoryService.isSlot(slot) or (count ~= nil and typeof(count) ~= "number") then
		return
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local profile = ProfileService.Get(player)
	if
		not head
		or not head:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
		or not profile
	then
		return
	end
	-- a few throws a second at most: holding Q must not flood the server with parts
	local now = os.clock()
	local times = dropTimes[player] or {}
	dropTimes[player] = times
	while times[1] and now - times[1] > 1 do
		table.remove(times, 1)
	end
	if #times >= rules.maxPerSecond then
		return
	end
	local stack = profile.inventory[slot]
	if not stack then
		return
	end
	if Config.tools[stack.id] then
		Remotes.event("Toast")
			:FireClient(player, Strings.t("drop_not_tools", Strings.localeOf(player)))
		return
	end
	local amount = if count == nil
		then stack.count
		else math.clamp(math.floor(count), 1, stack.count)
	local thrown: Types.ItemStack? = nil
	ProfileService.Mutate(player, function(p)
		local current = p.inventory[slot]
		if not current or current.id ~= stack.id then
			return
		end
		thrown = table.clone(current);
		(thrown :: Types.ItemStack).count = amount
		if amount >= current.count then
			p.inventory[slot] = nil
		else
			current.count -= amount
		end
	end)
	if thrown then
		table.insert(times, now)
		local look = head.CFrame.LookVector
		ItemDropService.Spawn(
			thrown,
			head.Position + look * 1.5 - Vector3.new(0, 0.5, 0),
			look * 12 + Vector3.new(0, 6, 0),
			rules.pickupDelaySeconds
		)
	end
end

function ItemDropService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("DropItem").OnServerEvent:Connect(onDropItem)
	Players.PlayerRemoving:Connect(function(player)
		dropTimes[player] = nil
	end)
	-- ClearLag: warn, then clear everything on the ground
	task.spawn(function()
		while true do
			task.wait(rules.clearEverySeconds - rules.warnBeforeSeconds)
			if #order > 0 then
				toastAll("drops_clear_soon", rules.warnBeforeSeconds)
			end
			task.wait(rules.warnBeforeSeconds)
			local cleared = #order
			for _, drop in ipairs(CollectionService:GetTagged("ItemDrop")) do
				drop:Destroy()
			end
			table.clear(order)
			if cleared > 0 then
				toastAll("drops_cleared", cleared)
			end
		end
	end)
	-- forget drops that fell out of the world or were removed elsewhere
	task.spawn(function()
		while true do
			task.wait(2)
			for i = #order, 1, -1 do
				local drop = order[i]
				if not drop.Parent or drop.Position.Y < workspace.FallenPartsDestroyHeight + 10 then
					table.remove(order, i)
					drop:Destroy()
				end
			end
		end
	end)
end

return ItemDropService
