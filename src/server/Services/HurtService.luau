--!strict
-- Getting hurt like Minecraft [владелец 21.10, ваниль]: whenever a player, mob or boss loses health
-- (hits, falls, needs…) its model flashes red for 0.3 s and a hurt sound plays at it (everyone sees and
-- hears it); melee hits also knock the target back (vanilla ≈ 0.4 block/tick horizontally plus a small
-- lift). The camera tilt of the hurt player is client side (EffectsHud).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)

local HurtService = {}

local FLASH_SECONDS = 0.3
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
	highlight.FillTransparency = 0.45
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
	local pitch = 0.9 + math.random() * 0.2
	if model:GetAttribute("MobId") == "rat" then
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

-- Melee knockback away from the attacker. Players own their character physics, so their client
-- applies it (remote Knockback); mobs and bosses are pushed here.
-- Bosses are not pushed at all (every hit used to shove the golem out of reach), mobs a little less than
-- players so a rat stays within reach of the next blow.
function HurtService.Knockback(model: Model, direction: Vector3)
	local flat = Vector3.new(direction.X, 0, direction.Z)
	if flat.Magnitude < 0.01 or CollectionService:HasTag(model, "Boss") then
		return
	end
	local scale = if CollectionService:HasTag(model, "Mob") then 0.6 else 1
	local push = flat.Unit * KNOCKBACK_SPEED * scale + Vector3.new(0, KNOCKBACK_LIFT * scale, 0)
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
