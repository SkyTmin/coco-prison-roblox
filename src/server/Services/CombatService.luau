--!strict
-- DigService / future MobService should call MarkHit after validated damage to a player.
-- Pass the attacker kind: player/boss hits lock teleport; ordinary mob hits do not.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("Shared").Config)

local CombatService = {}
local lastCombat: { [Player]: number } = {}
local started = false

function CombatService.MarkHit(player: Player, source: "player" | "boss" | "mob")
	if source ~= "player" and source ~= "boss" then
		return
	end
	local now = os.clock()
	lastCombat[player] = now
	player:SetAttribute("LastCombatAt", now)
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
