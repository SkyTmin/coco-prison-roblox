--!strict
-- Items lying on the ground: death loot (DeathService), mob loot (MobService) and items a player throws away
-- (DropItem). Like Minecraft [ваниль ItemEntity, владелец 27.10: «отображение предметов на земле дроп как в майне …
-- и поднятие их как в майне и расстояние»]: the server keeps only the item's 0.25-block box with its physics (every
-- client draws the item on it, spinning and bobbing — GroundItems.luau); the same stackable item within 0.5 block
-- merges into one stack; anyone whose box (0.6 × 1.8 blocks, raised by 1 block sideways and 0.5 up and down) meets an
-- item picks up as much as fits after the pickup delay (thrown and death loot 2 s, mob loot 0.5 s), and the item flies
-- to them (ItemPickupFx). Tools and armor cannot be thrown [владелец 21.10]. Every rules.drops.clearEverySeconds the
-- server removes all of them with a warning first (ClearLag on Minecraft servers), and never keeps more than
-- rules.drops.maxOnServer at once — with many players the ground must not fill with parts.
-- On the База банды (gang_base: the courtyard and the house copies) an item dropped by / from a gang member is seen and
-- picked up only by his gang [сеть TG/15 13.12.2025: «Предметы на Базе банды теперь отображаются и поднимаются только
-- членами банды»]: the drop carries the attribute GangId, pickUp skips non-members, GroundItems hides it from them.
-- Client → server: DropItem(slot, count?) — count nil = the whole stack.

local CollectionService = game:GetService("CollectionService")
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
local CollisionGroups = require(script.Parent.CollisionGroups)

local ItemDropService = {}
local rules = Config.rules.survival.drops
local BLOCK = Config.rules.combat.blockStuds :: number
-- [ваниль] the item's box is 0.25 block; a player's 0.6 wide, raised by 1 block sideways and 0.5 up and down
local ITEM = 0.25 * BLOCK
local REACH_SIDE = (0.3 + rules.pickupReachBlocks.horizontal) * BLOCK + ITEM / 2
local REACH_UP = rules.pickupReachBlocks.vertical * BLOCK
local MERGE = rules.mergeBlocks * BLOCK
local STACK = 64
local FX_RANGE = 64
type Drop = { part: BasePart, stack: Types.ItemStack, pickupAt: number, gang: string? }
local random = Random.new()
local order: { BasePart } = {} -- oldest first, for the server-wide cap
local drops: { [BasePart]: Drop } = {}
local heights: { [Model]: number } = {}
local dropTimes: { [Player]: { number } } = {}
local started = false

local function toastAll(key: string, ...: any)
	for _, player in ipairs(Players:GetPlayers()) do
		Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
	end
end

-- Puts a picked-up stack into the bag as far as it fits (the rest stays on the ground, like Minecraft); returns what
-- is left. Unstackable items keep their extra data (book effects, coins).
local function give(profile: Types.Profile, stack: Types.ItemStack): number
	if InventoryService.isStackable(stack.id) then
		return InventoryService.add(profile, stack.id, stack.count, stack.level)
	end
	for slot = 1, InventoryService.SLOTS do
		if not profile.inventory[slot] then
			profile.inventory[slot] = table.clone(stack)
			return 0
		end
	end
	return stack.count
end

local function remove(drop: BasePart)
	drops[drop] = nil
	local i = table.find(order, drop)
	if i then
		table.remove(order, i)
	end
	drop:Destroy()
end

-- the gang an item from `from` belongs to: only on the База банды and only when he is in a gang
local function gangOf(from: Player?): string?
	local profile = from and ProfileService.Get(from)
	local gang = from and from:GetAttribute("GangId")
	return if profile
			and profile.location == "gang_base"
			and typeof(gang) == "string"
		then gang
		else nil
end

function ItemDropService.Spawn(
	stack: Types.ItemStack,
	position: Vector3,
	velocity: Vector3,
	pickupDelay: number,
	from: Player?
)
	local gang = gangOf(from)
	local drop = Instance.new("Part")
	drop.Name = "ItemDrop"
	drop.Size = Vector3.one * ITEM
	drop.Position = position
	drop.Anchored = false
	drop.Transparency = 1
	drop.CanQuery = false
	drop.CanTouch = false
	drop.CastShadow = false
	drop.CollisionGroup = CollisionGroups.DROPS
	-- no bounce, much friction: it lands and lies where it fell
	drop.CustomPhysicalProperties = PhysicalProperties.new(0.7, 1.5, 0, 100, 100)
	drop:SetAttribute("ItemId", stack.id)
	drop:SetAttribute("Level", stack.level or 0)
	drop:SetAttribute("Count", stack.count)
	drop:SetAttribute("GangId", gang)
	CollectionService:AddTag(drop, "ItemDrop")
	-- [ваниль] an item falls at 0.04 block/tick² = 16 blocks/s², a third of Roblox's gravity: a force lifts the rest
	-- off, so a throw flies as far as in Minecraft
	local attachment = Instance.new("Attachment")
	attachment.Parent = drop
	local lift = Instance.new("VectorForce")
	lift.Attachment0 = attachment
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.ApplyAtCenterOfMass = true
	lift.Force = Vector3.new(0, drop:GetMass() * math.max(0, workspace.Gravity - 16 * BLOCK), 0)
	lift.Parent = drop
	drop.Parent = workspace
	-- server ownership: a nearby client cannot move a drop to claim it remotely
	drop:SetNetworkOwner(nil)
	drop.AssemblyLinearVelocity = velocity
	drops[drop] = {
		part = drop,
		stack = table.clone(stack),
		pickupAt = os.clock() + pickupDelay,
		gang = gang,
	}
	table.insert(order, drop)
	while #order > rules.maxOnServer do
		remove(order[1])
	end
end

-- loot scatters around the body; a player's loot waits 40 ticks, a mob's 10 [ваниль]
function ItemDropService.SpawnLoot(
	stack: Types.ItemStack,
	position: Vector3,
	fromMob: boolean?,
	from: Player?
)
	ItemDropService.Spawn(
		stack,
		position + Vector3.new(random:NextNumber(-1, 1), 1.5, random:NextNumber(-1, 1)),
		Vector3.new(random:NextNumber(-3, 3), 8, random:NextNumber(-3, 3)),
		if fromMob then rules.lootPickupDelaySeconds.mob else rules.lootPickupDelaySeconds.death,
		from
	)
end

-- the character's height (its box), measured once
local function heightOf(character: Model): number
	local h = heights[character]
	if not h then
		h = character:GetExtentsSize().Y
		heights[character] = h
	end
	return h
end

local function pickupFx(player: Player, drop: Drop)
	local fx = Remotes.unreliable("ItemPickupFx")
	local at = drop.part.Position
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") and (root.Position - at).Magnitude <= FX_RANGE then
			fx:FireClient(other, player.UserId, at, drop.stack.id, drop.stack.level or 0)
		end
	end
end

-- [ваниль Player.aiStep → playerTouch] every player whose raised box meets an item picks up what fits in the bag
local function pickUp()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			not character
			or not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or not ProfileService.Get(player)
		then
			continue
		end
		local feet = root.Position.Y - root.Size.Y / 2 - humanoid.HipHeight
		local top = feet + heightOf(character)
		for part, drop in pairs(drops) do
			local at = part.Position
			if
				now < drop.pickupAt
				or (drop.gang ~= nil and player:GetAttribute("GangId") ~= drop.gang)
				or math.abs(at.X - root.Position.X) > REACH_SIDE
				or math.abs(at.Z - root.Position.Z) > REACH_SIDE
				or at.Y + ITEM / 2 < feet - REACH_UP
				or at.Y - ITEM / 2 > top + REACH_UP
			then
				continue
			end
			local stack = drop.stack
			local left = stack.count
			ProfileService.Mutate(player, function(p)
				left = give(p, stack)
			end)
			if left < stack.count then
				pickupFx(player, drop)
				-- [ваниль] entity.item.pickup: pitch ((r − r) · 0.7 + 1) · 2
				Sfx.toPlayer(player, "pickup", 0.5, ((math.random() - math.random()) * 0.7 + 1) * 2)
				if left <= 0 then
					remove(part)
				else
					stack.count = left
					part:SetAttribute("Count", left)
				end
			end
		end
	end
end

-- [ваниль ItemEntity.mergeWithNeighbours] the same stackable item within 0.5 block joins one stack
local function merge()
	local cells: { [Vector3]: { Drop } } = {}
	local function cellOf(position: Vector3): Vector3
		return Vector3.new(
			math.floor(position.X / MERGE),
			math.floor(position.Y / MERGE),
			math.floor(position.Z / MERGE)
		)
	end
	for part, drop in pairs(drops) do
		local key = cellOf(part.Position)
		local list = cells[key]
		if not list then
			list = {}
			cells[key] = list
		end
		table.insert(list, drop)
	end
	for part, drop in pairs(drops) do
		if not drops[part] or not InventoryService.isStackable(drop.stack.id) then
			continue
		end
		local key = cellOf(part.Position)
		for dx = -1, 1 do
			for dy = -1, 1 do
				for dz = -1, 1 do
					for _, other in ipairs(cells[key + Vector3.new(dx, dy, dz)] or {}) do
						if
							other ~= drop
							and drops[other.part]
							and other.stack.id == drop.stack.id
							and other.gang == drop.gang
							and (other.stack.level or 0) == (drop.stack.level or 0)
							and drop.stack.count + other.stack.count <= STACK
							and (other.part.Position - part.Position).Magnitude <= MERGE
						then
							drop.stack.count += other.stack.count
							drop.pickupAt = math.max(drop.pickupAt, other.pickupAt)
							part:SetAttribute("Count", drop.stack.count)
							remove(other.part)
						end
					end
				end
			end
		end
	end
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
		-- [ваниль Player.drop] from 0.3 block under the eyes, 0.3 block/tick along the look and 0.1 up: it lands
		-- ≈ 2–2.5 blocks away, out of the pickup reach, so a thrown item stays on the ground
		local look = head.CFrame.LookVector
		ItemDropService.Spawn(
			thrown,
			head.Position - Vector3.new(0, 0.3 * BLOCK, 0),
			look * (0.3 * 20 * BLOCK) + Vector3.new(0, 0.1 * 20 * BLOCK, 0),
			rules.pickupDelaySeconds,
			player
		)
	end
end

function ItemDropService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("DropItem").OnServerEvent:Connect(onDropItem)
	Remotes.unreliable("ItemPickupFx")
	Players.PlayerRemoving:Connect(function(player)
		dropTimes[player] = nil
	end)
	task.spawn(function()
		local beat = 0
		while true do
			task.wait(0.1)
			pickUp()
			beat += 1
			if beat % 10 == 0 then
				merge()
			end
		end
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
			table.clear(drops)
			if cleared > 0 then
				toastAll("drops_cleared", cleared)
			end
		end
	end)
	-- forget drops that fell out of the world or were removed elsewhere, and characters that are gone
	task.spawn(function()
		while true do
			task.wait(2)
			for i = #order, 1, -1 do
				local drop = order[i]
				if not drop.Parent or drop.Position.Y < workspace.FallenPartsDestroyHeight + 10 then
					table.remove(order, i)
					drops[drop] = nil
					drop:Destroy()
				end
			end
			for character in pairs(heights) do
				if not character.Parent then
					heights[character] = nil
				end
			end
		end
	end)
end

return ItemDropService
