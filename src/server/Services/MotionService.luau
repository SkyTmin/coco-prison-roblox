--!strict
-- Our own movement replication for player characters [владелец 27.10: «задержки между действиями двух игроков …
-- уменьшить до минимума»]. Roblox shows other characters ≈ 0.25 s late (20 Hz physics replication and a fixed
-- interpolation buffer; measured in Server & Clients with a 2 ms ping). Every client sends its root here
-- (src/client/Motion.luau, unreliable "Motion": position, yaw, server-clock stamp, 60 Hz while moving); the server
-- checks it against the character it simulates and relays it at once ("MotionFx", unreliable) — every report to
-- the players within NEAR, every FAR_EVERY-th further out (measured in Studio: queueing to the end of the frame
-- cost up to a frame; 60 Hz instead of 30 takes ~17 ms off the receivers' buffer). Roblox replication keeps running underneath (physics, everything server-side).
-- The checked roots of the last second also serve the hit checks (CombatService.targetBox) with lag compensation
-- [владелец 27.10: «к этому каналу нужно добавить и пвп»]: the attacker names the server time they were looking
-- at, and the victim is tested where their own client had them then (at most MAX_REWIND back) — a hit on the
-- screen is a hit, with no 0.1–0.25 s lag of the server's replicated copy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local MotionService = {}

local MAX_DRIFT = 30 -- studs between the report and the server's copy (its copy is ~0.1–0.25 s old; falls are fast)
local MIN_GAP = 1 / 75 -- s: reports faster than this are dropped (clients send at most 60 a second)
local RELAY_RANGE = 250 -- studs: further away a character is small enough for the plain Roblox replication
local NEAR = 80 -- studs: closer players (a fight, a trade) get every report
local FAR_EVERY = 3 -- further ones get every third (20 a second)
local FRESH = 0.3 -- s: without a newer report the hit checks use the server's own copy
local MAX_REWIND = 0.3 -- s: the furthest back a hit check looks (high pings get no more)
local KEEP = 1 -- s of history
local TELEPORT = 20 -- studs between reports: the history before it is dropped

type Snap = { t: number, cf: CFrame }
local history: { [Player]: { Snap } } = {}
local lastAt: { [Player]: number } = {} -- os.clock of the last accepted report
local counts: { [Player]: number } = {} -- accepted reports, for the far players' share
local relay: UnreliableRemoteEvent? = nil
local started = false

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

local function onMotion(player: Player, position: any, yaw: any, stamp: any)
	if typeof(position) ~= "Vector3" or typeof(yaw) ~= "number" or typeof(stamp) ~= "number" then
		return
	end
	if
		not (
			finite(position.X)
			and finite(position.Y)
			and finite(position.Z)
			and finite(yaw)
			and finite(stamp)
		)
	then
		return
	end
	local now = os.clock()
	if now - (lastAt[player] or -math.huge) < MIN_GAP then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	if (root.Position - position).Magnitude > MAX_DRIFT then
		return -- not where the server has it: a teleport in flight, or a forged report
	end
	local serverNow = workspace:GetServerTimeNow()
	stamp = math.clamp(stamp, serverNow - 1, serverNow) -- the sender's clock cannot be ahead of ours
	lastAt[player] = now
	local list = history[player]
	if not list then
		list = {}
		history[player] = list
	end
	local newest = list[#list]
	if newest and (newest.cf.Position - position).Magnitude > TELEPORT then
		table.clear(list)
	elseif newest and stamp <= newest.t then
		return -- out of order (unreliable)
	end
	table.insert(list, { t = stamp, cf = CFrame.new(position) * CFrame.Angles(0, yaw, 0) })
	while #list > 2 and list[1].t < serverNow - KEEP do
		table.remove(list, 1)
	end
	local count = (counts[player] or 0) + 1
	counts[player] = count
	local batch = { { player.UserId, position, yaw, stamp } }
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player and relay then
			local otherRoot = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
			if otherRoot and otherRoot:IsA("BasePart") then
				local distance = (otherRoot.Position - position).Magnitude
				if distance <= NEAR or (distance <= RELAY_RANGE and count % FAR_EVERY == 0) then
					relay:FireClient(other, batch)
				end
			end
		end
	end
end

-- The player's root as their own client had it at server time `at` (clamped to the last MAX_REWIND; nil = the
-- newest report), from the checked reports; nil when there is no fresh report (use the server's copy).
function MotionService.rootAt(player: Player, at: number?): CFrame?
	local list = history[player]
	if not list or #list == 0 or os.clock() - (lastAt[player] or -math.huge) > FRESH then
		return nil
	end
	local newest = list[#list]
	if not at then
		return newest.cf
	end
	local now = workspace:GetServerTimeNow()
	at = math.clamp(at, now - MAX_REWIND, now)
	if at >= newest.t then
		return newest.cf
	end
	for i = #list - 1, 1, -1 do
		local a = list[i]
		if a.t <= at then
			local b = list[i + 1]
			return a.cf:Lerp(b.cf, (at - a.t) / math.max(b.t - a.t, 1e-3))
		end
	end
	return list[1].cf
end

-- The server time a client says it was looking at, made safe: a number within the last MAX_REWIND.
function MotionService.viewTime(value: any): number?
	if typeof(value) ~= "number" or value ~= value then
		return nil
	end
	local now = workspace:GetServerTimeNow()
	return math.clamp(value, now - MAX_REWIND, now)
end

function MotionService.Start()
	if started then
		return
	end
	started = true
	Remotes.unreliable("Motion").OnServerEvent:Connect(onMotion)
	relay = Remotes.unreliable("MotionFx")
	Players.PlayerRemoving:Connect(function(player)
		history[player], lastAt[player], counts[player] = nil, nil, nil
	end)
end

return MotionService
