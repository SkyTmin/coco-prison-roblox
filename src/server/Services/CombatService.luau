--!strict
-- DigService / future MobService should call MarkHit after validated damage to a player.
-- Pass the attacker kind: player/boss hits lock teleport; ordinary mob hits do not.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local HurtService = require(script.Parent.HurtService)

local MELEE_REACH = 12 -- [ваниль] 3 blocks
local lastAttack: { [Player]: number } = {}

local CombatService = {}
local lastCombat: { [Player]: number } = {}
local started = false

function CombatService.MarkHit(player: Player, source: "player" | "boss" | "mob", attacker: Player?)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:SetAttribute(
			"LastHitBy",
			if source == "player" and attacker then attacker.UserId else nil
		)
		humanoid:SetAttribute("LastHitAt", os.clock())
	end
	if source ~= "player" and source ~= "boss" then
		return
	end
	local now = os.clock()
	lastCombat[player] = now
	player:SetAttribute("LastCombatAt", now)
end

-- Validated combat callers use this entry point so attribution precedes a lethal hit.
function CombatService.ApplyDamage(
	humanoid: Humanoid,
	amount: number,
	source: "player" | "boss" | "mob",
	attacker: Player?
)
	if amount ~= amount or amount <= 0 or amount == math.huge or humanoid.Health <= 0 then
		return
	end
	local character = humanoid.Parent
	if character and character:FindFirstChildOfClass("ForceField") then
		return
	end
	local victim = if character and character:IsA("Model")
		then Players:GetPlayerFromCharacter(character)
		else nil
	if victim then
		CombatService.MarkHit(victim, source, attacker)
	else
		humanoid:SetAttribute(
			"LastHitBy",
			if source == "player" and attacker then attacker.UserId else nil
		)
		humanoid:SetAttribute("LastHitAt", os.clock())
	end
	humanoid:TakeDamage(amount)
end

function CombatService.remainingSeconds(player: Player): number
	local last = lastCombat[player]
	return if last
		then math.max(0, Config.rules.teleport.combatLockSeconds - (os.clock() - last))
		else 0
end

function CombatService.inCombat(player: Player): boolean
	return CombatService.remainingSeconds(player) > 0
end

-- Weapon in hand → base damage and attack speed (Minecraft Java) [ваниль]; sword enchant = Sharpness.
local function weapon(profile): (number, number)
	local toolId, level = InventoryService.heldTool(profile)
	local vanilla = Config.vanilla
	if not toolId then
		return vanilla.handDamage or 1, (vanilla.attackSpeed and vanilla.attackSpeed.hand) or 4
	end
	local material = Config.materialForLevel(level)
	local damage = 1
	local speed = 4
	if toolId == "sword" then
		damage = vanilla.swordDamage[material]
			+ (vanilla.sharpnessBonus[Config.enchantForLevel("sword", level) + 1] or 0)
		speed = vanilla.attackSpeed.sword
	elseif vanilla.toolDamage and vanilla.toolDamage[toolId] then
		damage = vanilla.toolDamage[toolId][material]
		local s = vanilla.attackSpeed[toolId]
		speed = if typeof(s) == "table" then s[material] else s
	end
	return damage, speed
end

-- Tap / click with no block under the crosshair: a melee swing along the look direction.
-- Cooldown scaling like Java: damage × (0.2 + 0.8 × t²), t = time since the last swing × attack speed.
local function onAttack(player: Player, direction: any)
	if
		typeof(direction) ~= "Vector3"
		or direction ~= direction
		or direction.Magnitude < 0.5
		or direction.Magnitude > 1.5
	then
		return
	end
	local profile = ProfileService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	local baseDamage, speed = weapon(profile)
	local now = os.clock()
	local t = math.clamp((now - (lastAttack[player] or -math.huge)) * speed, 0, 1)
	lastAttack[player] = now
	local damage = baseDamage * (0.2 + 0.8 * t * t)
	local head = character:FindFirstChild("Head")
	local eye = if head and head:IsA("BasePart")
		then head.Position
		else character:GetPivot().Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local hit = workspace:Raycast(eye, direction.Unit * MELEE_REACH, params)
	if not hit then
		return
	end
	local model = hit.Instance:FindFirstAncestorOfClass("Model")
	local target = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not target or target.Health <= 0 then
		return
	end
	local victim = Players:GetPlayerFromCharacter(model)
	if victim then
		-- PvP only where the location allows it (both players there) [вики]
		local mine = Config.location(profile.location)
		local theirs = ProfileService.Get(victim)
		local other = theirs and Config.location(theirs.location)
		if not (mine and mine.pvp and other and other.pvp) then
			return
		end
		CombatService.ApplyDamage(target, damage, "player", player)
		HurtService.Knockback(model, direction)
	elseif CollectionService:HasTag(model, "Mob") or CollectionService:HasTag(model, "Boss") then
		target:SetAttribute("LastHitBy", player.UserId)
		target:SetAttribute("LastHitAt", now)
		target:TakeDamage(damage)
		HurtService.Knockback(model, direction)
	end
end

function CombatService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("Attack").OnServerEvent:Connect(onAttack)
	Players.PlayerRemoving:Connect(function(player)
		lastCombat[player] = nil
		lastAttack[player] = nil
	end)
end

return CombatService
