--!strict
-- Getting hurt like Minecraft [владелец 21.10, ваниль]: whenever a player, mob or boss loses health
-- (hits, falls, needs…) its model flashes red for 0.5 s and a hurt sound plays at it (everyone sees and
-- hears it); melee hits also knock the target back (vanilla ≈ 0.4 block/tick horizontally plus a small
-- lift). The camera tilt of the hurt player is client side (EffectsHud).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Knockback = require(Shared.Knockback)

local HurtService = {}

-- [ваниль] the red wash lasts the whole hurtTime (10 ticks) and does not fade; OverlayTexture mixes 30 % red
-- over the skin (alpha 0xB2) — a Highlight fill shows a bit weaker, so 0.4 here
local FLASH_SECONDS = 0.5
local KNOCKBACK_SPEED = 26 -- studs/s horizontal (0.4 block/tick × 20 ticks/s × 4 studs/block ÷ ~1.2 drag)
local KNOCKBACK_LIFT = 14
local watched: { [Humanoid]: boolean } = {}
local started = false
local impactId = 0
local expectedHealth: { [Humanoid]: { { value: number, at: number } } } = setmetatable(
	{},
	{ __mode = "k" }
) :: any

local function flash(model: Model)
	local existing = model:FindFirstChild("HurtFlash")
	if existing then
		existing:Destroy()
	end
	local highlight = Instance.new("Highlight")
	highlight.Name = "HurtFlash"
	highlight.FillColor = Color3.fromRGB(255, 0, 0)
	highlight.FillTransparency = 0.6
	highlight.OutlineTransparency = 1
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Adornee = model
	highlight.Parent = model
	task.delay(FLASH_SECONDS, function()
		if highlight.Parent then
			highlight:Destroy()
		end
	end)
end

-- [владелец 22.10: бой приятнее] each kind of target has its own hurt sound: a rat squeaks, a boss takes a
-- heavy thud, a player gets the vanilla hurt sound; the pitch varies a little like vanilla
local function playHurt(model: Model, exclude: Player?): (string, number, number)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return "player_hurt", 0.7, 1
	end
	local pitch = (math.random() - math.random()) * 0.2 + 1 -- [ваниль] 0.8 … 1.2, mostly near 1
	local mobId = model:GetAttribute("MobId")
	local mob = if typeof(mobId) == "string" then Config.mobs.mobs[mobId] else nil
	local name, volume = "player_hurt", 0.7
	if mob and mob.hurtSound then
		name, volume, pitch = mob.hurtSound[1], mob.hurtSound[2], pitch * mob.hurtSound[3]
	elseif mobId == "rat" then
		name, volume = "rat_hurt", 0.6
	elseif CollectionService:HasTag(model, "Boss") then
		name, volume, pitch = "hit_heavy", 0.9, pitch * 0.85
	end
	Sfx.broadcast(name, root, volume, pitch, exclude)
	return name, volume, pitch
end

local function emit(humanoid: Humanoid, damage: number, soaked: number, context: any?)
	local model = humanoid.Parent
	if not model or not model:IsA("Model") then
		return
	end
	local victim = Players:GetPlayerFromCharacter(model)
	flash(model)
	local sound, volume, pitch = playHurt(model, victim)
	if victim then
		impactId += 1
		Remotes.event("HurtImpact"):FireClient(victim, {
			id = impactId,
			character = model,
			damage = damage,
			absorbed = soaked,
			health = humanoid.Health,
			maxHealth = humanoid.MaxHealth,
			golden = model:GetAttribute("AbsorptionHealth") or 0,
			from = context and context.from,
			push = context and context.push,
			sound = sound,
			volume = volume,
			pitch = pitch,
		})
	end
end

local function watch(humanoid: Humanoid)
	if watched[humanoid] then
		return
	end
	watched[humanoid] = true
	local last = humanoid.Health
	humanoid.HealthChanged:Connect(function(health)
		local model = humanoid.Parent
		if health < last - 0.01 and model and model:IsA("Model") then
			local own = false
			local queue = expectedHealth[humanoid] or {}
			for i = #queue, 1, -1 do
				local record = queue[i]
				if os.clock() - record.at > 1 then
					table.remove(queue, i)
				elseif math.abs(record.value - health) < 0.001 then
					own = true
					table.remove(queue, i)
					break
				end
			end
			if not own then
				emit(humanoid, last - health, 0, nil)
			end
		end
		last = health
	end)
	humanoid.AncestryChanged:Connect(function(_, parent)
		if not parent then
			watched[humanoid] = nil
		end
	end)
end

local function watchModel(model: Instance)
	if model:IsA("Model") then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			watch(humanoid)
		end
	end
end

-- Every damage goes through here [ваниль]: Absorption's golden health (character attribute AbsorptionHealth, the
-- golden apple — NeedsService.GiveEffect) takes it before the health does; a blow it soaks up whole still flashes
-- and sounds. Player ForceFields retain their protection; bosses never block [владелец 02.11].
function HurtService.Damage(humanoid: Humanoid, amount: number, context: any?): number
	local model = humanoid.Parent
	if
		amount ~= amount
		or amount <= 0
		or amount == math.huge
		or not model
		or humanoid.Health <= 0
	then
		return 0
	end
	local boss = CollectionService:HasTag(model, "Boss")
	if not boss and model:FindFirstChildOfClass("ForceField") then
		return 0
	end
	local before, soaked = humanoid.Health, 0
	local golden = model:GetAttribute("AbsorptionHealth")
	if not boss and typeof(golden) == "number" and golden > 0 then
		soaked = math.min(golden, amount)
		model:SetAttribute(
			"AbsorptionHealth",
			if golden - soaked > 1e-3 then golden - soaked else nil
		)
		amount -= soaked
	end
	if amount > 1e-3 then
		local queue = expectedHealth[humanoid] or {}
		expectedHealth[humanoid] = queue
		if #queue >= 16 then
			table.remove(queue, 1)
		end
		table.insert(queue, { value = math.max(0, before - amount), at = os.clock() })
		if boss then
			humanoid.Health = math.max(0, before - amount)
		else
			humanoid:TakeDamage(amount)
		end
	end
	local dealt = before - humanoid.Health + soaked
	if dealt > 0 then
		emit(humanoid, dealt, soaked, context)
	end
	return dealt
end

-- Melee knockback away from the attacker. Players own their character physics, so their client
-- applies it (remote Knockback); mobs and bosses are pushed here.
-- Bosses are not pushed at all (every hit used to shove the golem out of reach), mobs a little less than
-- players so a rat stays within reach of the next blow.
-- strength / lift scale the push and the hop (the books Боксёр and Вихрь throw harder).
function HurtService.Impulse(
	model: Model,
	direction: Vector3,
	strength: number?,
	lift: number?
): Vector3?
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if
		not Knockback.finite(flat)
		or flat.Magnitude < 0.01
		or CollectionService:HasTag(model, "Boss")
	then
		return nil
	end
	local scale = if CollectionService:HasTag(model, "Mob") then 0.6 else 1
	local push = flat.Unit * KNOCKBACK_SPEED * scale * (strength or 1)
		+ Vector3.new(0, KNOCKBACK_LIFT * scale * (lift or 1), 0)
	return push
end

function HurtService.Knockback(model: Model, direction: Vector3, strength: number?, lift: number?)
	local push = HurtService.Impulse(model, direction, strength, lift)
	if not push then
		return
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		Remotes.event("Knockback"):FireClient(victim, push)
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and not root.Anchored then
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		root.AssemblyLinearVelocity = Knockback.velocity(
			root.AssemblyLinearVelocity,
			push,
			humanoid ~= nil and humanoid.FloorMaterial ~= Enum.Material.Air
		)
	end
end

function HurtService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("Knockback") -- create it now: clients wait for it at start
	Remotes.event("HurtImpact")
	local function characterOf(player: Player)
		player.CharacterAdded:Connect(watchModel)
		if player.Character then
			watchModel(player.Character)
		end
	end
	Players.PlayerAdded:Connect(characterOf)
	for _, player in ipairs(Players:GetPlayers()) do
		characterOf(player)
	end
	for _, tag in ipairs({ "Mob", "Boss" }) do
		for _, model in ipairs(CollectionService:GetTagged(tag)) do
			watchModel(model)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(watchModel)
	end
end

return HurtService
