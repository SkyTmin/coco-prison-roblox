--!strict
-- Fall damage as in Minecraft [ваниль]: ceil(N − 3) damage (half-hearts) for a fall of N blocks, none in
-- water, in a cobweb or while on a ladder. Humanoid.FloorMaterial replicates to the server (Air while airborne),
-- so the apex is the highest point seen while in the air and the landing is the first grounded
-- frame. Fall deaths are not player/mob/boss deaths (stats untouched).

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Sfx = require(Shared.Sfx)
local Cobweb = require(Shared.Cobweb)
local Ladders = require(Shared.Ladders)
local HurtService = require(script.Parent.HurtService)

local BLOCK = 4
local SAFE_BLOCKS = 3
-- the first grounded frame sees the root slightly above its resting height; without this slack a
-- 10-block fall measured 9.9 blocks
local LANDING_SLACK = 0.1

type Track = { apex: number?, history: { number } } -- history: last positions (replication lag)
local HISTORY = 8
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
			track = { apex = nil, history = {} }
			tracks[player] = track
		end
		local state = humanoid:GetState()
		local safe = state == Enum.HumanoidStateType.Climbing
			or state == Enum.HumanoidStateType.Swimming
			or humanoid.FloorMaterial == Enum.Material.Water
			or Cobweb.holds(character) -- a web stops the fall [ваниль]
			or (humanoid.FloorMaterial == Enum.Material.Air and Ladders.near(character) ~= nil)
		if safe then
			track.apex = nil -- ladders and water cancel the fall
			table.clear(track.history) -- a ladder catch must also discard the pre-catch falling history
		elseif humanoid.FloorMaterial == Enum.Material.Air then
			-- FloorMaterial can lag behind the replicated position: the apex also looks at recent frames
			local apex = track.apex or y
			if not track.apex then
				for _, h in ipairs(track.history) do
					apex = math.max(apex, h)
				end
			end
			track.apex = math.max(apex, y)
		elseif track.apex then
			local damage = math.ceil((track.apex - y) / BLOCK - SAFE_BLOCKS - LANDING_SLACK)
			track.apex = nil
			if damage >= 1 then
				humanoid:SetAttribute("LastHitBy", nil)
				HurtService.Damage(humanoid, damage)
				Sfx.broadcast("player_fall", root :: BasePart, 0.8)
			end
		end
		table.insert(track.history, y)
		if #track.history > HISTORY then
			table.remove(track.history, 1)
		end
	end
end

function FallService.Start()
	Cobweb.start()
	RunService.Heartbeat:Connect(step)
	Players.PlayerRemoving:Connect(function(player)
		tracks[player] = nil
	end)
end

return FallService
