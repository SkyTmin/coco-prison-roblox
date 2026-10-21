--!strict
-- Fall damage as in Minecraft [ваниль]: a fall of N blocks deals N − 3 damage (half-hearts), none in
-- water or while on a ladder. Humanoid.FloorMaterial replicates to the server (Air while airborne),
-- so the apex is the highest point seen while in the air and the landing is the first grounded
-- frame. Fall deaths are not player/mob/boss deaths (stats untouched).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BLOCK = 4
local SAFE_BLOCKS = 3

type Track = { apex: number? }
local tracks: { [Player]: Track } = {}
local FallService = {}

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
			tracks[player] = nil
			continue
		end
		local y = root.Position.Y
		local track = tracks[player]
		if not track then
			track = { apex = nil }
			tracks[player] = track
		end
		local state = humanoid:GetState()
		local safe = state == Enum.HumanoidStateType.Climbing
			or state == Enum.HumanoidStateType.Swimming
			or humanoid.FloorMaterial == Enum.Material.Water
		if safe then
			track.apex = nil -- ladders and water cancel the fall
		elseif humanoid.FloorMaterial == Enum.Material.Air then
			track.apex = math.max(track.apex or y, y)
		elseif track.apex then
			local damage = math.floor((track.apex - y) / BLOCK - SAFE_BLOCKS)
			track.apex = nil
			if damage >= 1 then
				humanoid:SetAttribute("LastHitBy", nil)
				humanoid:TakeDamage(damage)
			end
		end
	end
end

function FallService.Start()
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
end

return FallService
