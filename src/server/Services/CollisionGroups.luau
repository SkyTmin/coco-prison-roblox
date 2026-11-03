--!strict
-- Players and mobs pass through each other like in Minecraft [владелец 22.10: «нельзя подниматься на мобов;
-- мобы не толкают наше тело и мы их; только отброс от урона»]: every character part is in "Players", every
-- part of a mob or boss in "Mobs", and the two groups do not collide. Knockback (HurtService) still moves them.

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")

local CollisionGroups = {}
local started = false

local PLAYERS, MOBS, DROPS, PLAYER_VISUALS = "Players", "Mobs", "ItemDrops", "PlayerVisuals"
CollisionGroups.DROPS = DROPS

local function register()
	for _, name in ipairs({ PLAYERS, MOBS, DROPS, PLAYER_VISUALS }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(PLAYERS, MOBS, false)
	-- items on the ground lie on the world only: walked through, not pushed, not stacked on each other [ваниль]
	for _, other in ipairs({ PLAYERS, MOBS, DROPS }) do
		PhysicsService:CollisionGroupSetCollidable(DROPS, other, false)
	end
	-- R15's state machine can switch torso.CanCollide back on. The animated block
	-- skin therefore needs a collision group, not a per-frame CanCollide override.
	-- Root + rigid head proxy keep walls/ceilings solid independently of animation.
	for _, other in ipairs({ "Default", PLAYERS, MOBS, DROPS, PLAYER_VISUALS }) do
		PhysicsService:CollisionGroupSetCollidable(PLAYER_VISUALS, other, false)
	end
end

-- puts the model's parts (now and later) into a group
function CollisionGroups.set(model: Instance, group: string)
	local function assign(d: Instance)
		if d:IsA("BasePart") then
			d.CollisionGroup = if group == PLAYERS
					and d:GetAttribute("BlockBodyVisual") == true
				then PLAYER_VISUALS
				else group
		end
	end
	for _, d in ipairs(model:GetDescendants()) do
		assign(d)
	end
	model.DescendantAdded:Connect(assign)
end

function CollisionGroups.player(model: Instance)
	register()
	CollisionGroups.set(model, PLAYERS)
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
			CollisionGroups.player(character)
		end)
		if player.Character then
			CollisionGroups.player(player.Character)
		end
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in ipairs(Players:GetPlayers()) do
		onPlayer(player)
	end
end

return CollisionGroups
