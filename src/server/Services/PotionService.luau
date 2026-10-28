--!strict
-- The potion stand [вики POTIONS.md] (rules: Shared/Potions). PotionBrew(kind, effectIds, upgraded) brews one potion
-- into the inventory and empties the stand (profile.potionBrewedAt); Creative skips the charge. A potion in the hand
-- is used with UseConsumable(slot, aim): a drinkable one gives its effects to the drinker (NeedsService.GiveEffect),
-- a splash one flies along `aim` (the camera's look) and bursts where it lands (BookService.Splash). The donate item
-- «Перезарядка стойки» (stand_recharge) used the same way charges the stand at once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Effects = require(Shared.Effects)
local Potions = require(Shared.Potions)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local BookService = require(script.Parent.BookService)
local InventoryService = require(script.Parent.InventoryService)
local NeedsService = require(script.Parent.NeedsService)
local ProfileService = require(script.Parent.ProfileService)

local PotionService = {}

local THROW_SPEED = 32 -- studs/s [решение: ≈ ванильный бросок на 6–8 блоков]
local THROW_LIFT = 8
local GRAVITY = 48
local FLIGHT_SECONDS = 2.5
local USE_COOLDOWN = 0.4
local lastAction: { [Player]: number } = {}

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function busy(player: Player): boolean
	local now = os.clock()
	if now - (lastAction[player] or 0) < USE_COOLDOWN then
		return true
	end
	lastAction[player] = now
	return false
end

local function rootOf(player: Player): BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

-- the mixed colour of the potion's effects (vanilla mixes them the same way)
local function colorOf(effects: { { id: string, seconds: number } }): Color3
	local r, g, b, n = 0, 0, 0, 0
	for _, entry in ipairs(effects) do
		local effect = Effects.byId(entry.id)
		if effect then
			r += effect.color.R
			g += effect.color.G
			b += effect.color.B
			n += 1
		end
	end
	return if n > 0 then Color3.new(r / n, g / n, b / n) else Color3.fromRGB(180, 80, 200)
end

local function onBrew(player: Player, kind: any, ids: any, upgraded: any)
	if (kind ~= "drink" and kind ~= "splash") or typeof(ids) ~= "table" or #ids > 8 then
		return
	end
	local list: { string } = {}
	for _, id in ipairs(ids) do
		if typeof(id) ~= "string" then
			return
		end
		table.insert(list, id)
	end
	if busy(player) then
		return
	end
	local up = upgraded == true
	local creative = player:GetAttribute("Creative") == true
	local now = workspace:GetServerTimeNow()
	local refusal = Potions.refusal(ProfileService.Get(player), kind, list, up, now, creative)
	if refusal then
		toast(player, refusal)
		return
	end
	local stack = Potions.make(kind, list, up, player.Name)
	local brewed = false
	ProfileService.Mutate(player, function(p)
		if Potions.refusal(p, kind, list, up, now, creative) then
			return
		end
		for slot = 1, InventoryService.SLOTS do
			if not p.inventory[slot] then
				p.inventory[slot] = stack
				p.potionBrewedAt = if creative then p.potionBrewedAt else now
				brewed = true
				return
			end
		end
	end)
	if not brewed then
		toast(player, "potions_inventory_full")
		return
	end
	local root = rootOf(player)
	if root then
		Sfx.broadcast("xp", root, 0.7, 1.3)
	end
	toast(player, "potions_brewed", Strings.t("item_" .. stack.id, Strings.localeOf(player)))
	Remotes.event("PotionResult"):FireClient(player, "brewed")
end

-- takes the potion out of `slot`; nil when it is not there any more
local function take(player: Player, slot: number): { { id: string, seconds: number } }?
	local effects = nil
	ProfileService.Mutate(player, function(p)
		local stack = p.inventory[slot]
		if stack and Potions.isPotion(stack.id) and stack.potion then
			effects = stack.potion.effects
			p.inventory[slot] = nil
		end
	end)
	return effects
end

local function drink(player: Player, slot: number)
	local effects = take(player, slot)
	if not effects then
		return
	end
	for _, entry in ipairs(effects) do
		if Potions.entry("drink", entry.id) then
			NeedsService.GiveEffect(player, entry.id, 1, entry.seconds)
		end
	end
	local root = rootOf(player)
	if root then
		Sfx.broadcast("eat", root, 0.7, 1.2)
	end
end

local function burst(position: Vector3, color: Color3)
	local anchor = Instance.new("Part")
	anchor.Name = "PotionSplash"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch = true, false, false, false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = workspace
	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(color)
	emitter.LightEmission = 0.4
	emitter.Lifetime = NumberRange.new(0.5, 1)
	emitter.Speed = NumberRange.new(6, 14)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Acceleration = Vector3.new(0, -12, 0)
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0.1),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Rate = 0
	emitter.Parent = anchor
	emitter:Emit(60)
	Sfx.broadcast("glass_break", anchor, 0.9)
	task.delay(1.5, function()
		anchor:Destroy()
	end)
end

local function throw(player: Player, slot: number, aim: any)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local root = rootOf(player)
	if not character or not head or not head:IsA("BasePart") or not root then
		return
	end
	local direction = if typeof(aim) == "Vector3"
			and aim.Magnitude > 0.5
			and aim.Magnitude < 1.5
		then aim.Unit
		else root.CFrame.LookVector
	local effects = take(player, slot)
	if not effects then
		return
	end
	local color = colorOf(effects)
	local bottle = Instance.new("Part")
	bottle.Name = "SplashPotion"
	bottle.Anchored, bottle.CanCollide, bottle.CanQuery, bottle.CanTouch = true, false, false, false
	bottle.Material = Enum.Material.Glass
	bottle.Transparency = 0.2
	bottle.Color = color
	bottle.Size = Vector3.new(0.6, 0.8, 0.6)
	local position = head.Position + direction * 1.5
	bottle.CFrame = CFrame.new(position)
	bottle.Parent = workspace
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, bottle }
	local velocity = direction * THROW_SPEED + Vector3.new(0, THROW_LIFT, 0)
	task.spawn(function()
		local flown = 0
		local hitAt: Vector3? = nil
		while flown < FLIGHT_SECONDS do
			local dt = task.wait()
			flown += dt
			velocity += Vector3.new(0, -GRAVITY * dt, 0)
			local step = velocity * dt
			local hit = workspace:Raycast(position, step, params)
			if hit then
				hitAt = hit.Position
				break
			end
			position += step
			bottle.CFrame = CFrame.new(position) * CFrame.Angles(flown * 8, 0, flown * 5)
		end
		bottle:Destroy()
		local center = hitAt or position
		burst(center, color)
		if player.Parent then
			BookService.Splash(player, center, Potions.SPLASH_RADIUS, effects)
		end
	end)
end

-- «Перезарядка стойки» [вики]: needs Зельевар, one item charges the stand at once; a charged stand keeps the item
local function recharge(player: Player, slot: number)
	local profile = ProfileService.Get(player)
	if Potions.modifiers(profile) < 1 then
		toast(player, "potions_need_skill")
		return
	end
	if Potions.charge(profile, workspace:GetServerTimeNow()) >= 1 then
		toast(player, "potions_already_charged")
		return
	end
	local done = false
	ProfileService.Mutate(player, function(p)
		local stack = p.inventory[slot]
		if not stack or stack.id ~= Potions.RECHARGE then
			return
		end
		if stack.count > 1 then
			stack.count -= 1
		else
			p.inventory[slot] = nil
		end
		p.potionBrewedAt = nil
		done = true
	end)
	if done then
		local root = rootOf(player)
		if root then
			Sfx.broadcast("xp", root, 0.8, 1.5)
		end
		toast(player, "potions_recharged")
		Remotes.event("PotionResult"):FireClient(player, "recharged")
	end
end

local function onUse(player: Player, slot: any, aim: any)
	if not InventoryService.isSlot(slot) then
		return
	end
	local profile = ProfileService.Get(player)
	local stack = profile and profile.inventory[slot]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not stack or not Potions.isUsable(stack.id) or not humanoid or humanoid.Health <= 0 then
		return
	end
	if busy(player) then
		return
	end
	if stack.id == Potions.RECHARGE then
		recharge(player, slot)
		return
	end
	if stack.id == Potions.ITEMS.splash then
		throw(player, slot, aim)
	else
		drink(player, slot)
	end
end

function PotionService.Start()
	Remotes.event("PotionResult")
	Remotes.event("PotionBrew").OnServerEvent:Connect(onBrew)
	Remotes.event("UseConsumable").OnServerEvent:Connect(onUse)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
end

return PotionService
