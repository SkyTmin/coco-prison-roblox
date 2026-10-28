--!strict
-- Getting hurt like Minecraft [владелец 21.10, ваниль]: whenever a player, mob or boss loses health
-- (hits, falls, needs…) its model flashes red for 0.3 s and a hurt sound plays at it (everyone sees and
-- hears it); melee hits also knock the target back (vanilla ≈ 0.4 block/tick horizontally plus a small
-- lift). The camera tilt of the hurt player is client side (EffectsHud).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)

local HurtService = {}

-- [ваниль] the red wash lasts the whole hurtTime (10 ticks) and does not fade; OverlayTexture mixes 30 % red
-- over the skin (alpha 0xB2) — a Highlight fill shows a bit weaker, so 0.4 here
local FLASH_SECONDS = 0.5
local KNOCKBACK_SPEED = 26 -- studs/s horizontal (0.4 block/tick × 20 ticks/s × 4 studs/block ÷ ~1.2 drag)
local KNOCKBACK_LIFT = 14
local watched: { [Humanoid]: boolean } = {}
local started = false

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
local function playHurt(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return
	end
	local pitch = (math.random() - math.random()) * 0.2 + 1 -- [ваниль] 0.8 … 1.2, mostly near 1
	local mobId = model:GetAttribute("MobId")
	local mob = if typeof(mobId) == "string" then Config.mobs.mobs[mobId] else nil
	if mob and mob.hurtSound then
		Sfx.broadcast(mob.hurtSound[1], root, mob.hurtSound[2], pitch * mob.hurtSound[3])
	elseif mobId == "rat" then
		Sfx.broadcast("rat_hurt", root, 0.6, pitch)
	elseif CollectionService:HasTag(model, "Boss") then
		Sfx.broadcast("hit_heavy", root, 0.9, pitch * 0.85)
	else
		Sfx.broadcast("player_hurt", root, 0.7, pitch)
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
			flash(model)
			playHurt(model)
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
-- and sounds. A ForceField (creative mode, a casting boss) still blocks everything, as TakeDamage does.
function HurtService.Damage(humanoid: Humanoid, amount: number)
	local model = humanoid.Parent
	if amount <= 0 or not model or model:FindFirstChildOfClass("ForceField") then
		return
	end
	local golden = model:GetAttribute("AbsorptionHealth")
	if typeof(golden) == "number" and golden > 0 then
		local soaked = math.min(golden, amount)
		model:SetAttribute(
			"AbsorptionHealth",
			if golden - soaked > 1e-3 then golden - soaked else nil
		)
		amount -= soaked
		if amount <= 1e-3 then
			if model:IsA("Model") and humanoid.Health > 0 then
				flash(model)
				playHurt(model)
			end
			return
		end
	end
	humanoid:TakeDamage(amount)
end

-- Melee knockback away from the attacker. Players own their character physics, so their client
-- applies it (remote Knockback); mobs and bosses are pushed here.
-- Bosses are not pushed at all (every hit used to shove the golem out of reach), mobs a little less than
-- players so a rat stays within reach of the next blow.
-- strength / lift scale the push and the hop (the books Боксёр and Вихрь throw harder).
function HurtService.Knockback(model: Model, direction: Vector3, strength: number?, lift: number?)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 or CollectionService:HasTag(model, "Boss") then
		return
	end
	local scale = if CollectionService:HasTag(model, "Mob") then 0.6 else 1
	local push = flat.Unit * KNOCKBACK_SPEED * scale * (strength or 1)
		+ Vector3.new(0, KNOCKBACK_LIFT * scale * (lift or 1), 0)
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		Remotes.event("Knockback"):FireClient(victim, push)
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and not root.Anchored then
		root.AssemblyLinearVelocity = push
	end
end

function HurtService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("Knockback") -- create it now: clients wait for it at start
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
