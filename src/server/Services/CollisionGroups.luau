--!strict
-- Players and mobs pass through each other like in Minecraft [владелец 22.10: «нельзя подниматься на мобов;
-- мобы не толкают наше тело и мы их; только отброс от урона»]: every character part is in "Players", every
-- part of a mob or boss in "Mobs", and the two groups do not collide. Knockback (HurtService) still moves them.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}
local started = false

local PLAYERS, MOBS = "Players", "Mobs"

local function register()
	for _, name in ipairs({ PLAYERS, MOBS }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(PLAYERS, MOBS, false)
end

-- puts the model's parts (now and later) into a group
function CollisionGroups.set(model: Instance, group: string)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end
	model.DescendantAdded:Connect(function(d)
		if d:IsA("BasePart") then
			d.CollisionGroup = group
		end
	end)
end

function CollisionGroups.mob(model: Instance)
	register()
	CollisionGroups.set(model, MOBS)
end

function CollisionGroups.Start()
	if started then
		return
	end
	started = true
	register()
	local function onPlayer(player: Player)
		player.CharacterAdded:Connect(function(character)
			CollisionGroups.set(character, PLAYERS)
		end)
		if player.Character then
			CollisionGroups.set(player.Character, PLAYERS)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return CollisionGroups
