--!strict
-- Fall damage as in Minecraft [ваниль]: a fall of N blocks deals N − 3 damage (half-hearts), none in
-- water or while on a ladder. The server tracks the highest point of each airborne character and
-- applies the damage when it lands. Fall deaths are not player/mob/boss deaths (stats untouched).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local BLOCK = 4
local SAFE_BLOCKS = 3

type Track = { peak: number?, airborne: boolean }
local tracks: { [Player]: Track } = {}
local FallService = {}

local function airborne(humanoid: Humanoid): boolean
	local state = humanoid:GetState()
	return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

local function step()
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
			tracks[player] = nil
			continue
		end
		local track = tracks[player]
		if not track then
			track = { peak = nil, airborne = false }
			tracks[player] = track
		end
		local y = root.Position.Y
		local state = humanoid:GetState()
		if airborne(humanoid) then
			track.airborne = true
			track.peak = math.max(track.peak or y, y)
		elseif
			state == Enum.HumanoidStateType.Climbing
			or state == Enum.HumanoidStateType.Swimming
			or humanoid.FloorMaterial == Enum.Material.Water
		then
			track.airborne, track.peak = false, nil -- ladders and water cancel the fall
		elseif track.airborne and track.peak then
			local blocks = (track.peak - y) / BLOCK
			local damage = math.floor(blocks - SAFE_BLOCKS)
			track.airborne, track.peak = false, nil
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
