--!strict
-- DigService / future MobService should call MarkHit after validated damage to a player.
-- Pass the attacker kind: player/boss hits lock teleport; ordinary mob hits do not.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

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

function CombatService.Start()
	if started then
		return
	end
	started = true
	Players.PlayerRemoving:Connect(function(player)
		lastCombat[player] = nil
	end)
end

return CombatService
