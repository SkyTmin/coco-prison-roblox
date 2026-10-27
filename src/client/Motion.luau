--!strict
-- Our own movement replication for player characters [владелец 27.10: «задержки между действиями двух игроков …
-- уменьшить до минимума»; measured: Roblox shows another player ≈ 0.25 s late even with a 2 ms ping].
-- Sending: our root (position, yaw, server-clock stamp) 60 times a second while we move or turn, 4 times a second
-- standing still, over the unreliable "Motion" remote (MotionService checks and relays it).
-- Drawing: other characters come from those snapshots ("MotionFx") instead of Roblox's buffer — shown at
-- server time minus a small adaptive delay (the measured one-way lateness + its jitter + the measured gap between
-- snapshots), interpolated between snapshots and extrapolated for at most EXTRAPOLATE when one is late.
-- Measured in Studio Server & Clients (27.10): Roblox ≈ 250 ms behind, this ≈ 85 ms at 30 Hz with the relay
-- queued to the frame's end; the snapshots themselves arrive ≈ 50 ms after they are taken there.
-- Without fresh snapshots (dead, far away, the sender stalled) Roblox replication shows the character again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Remotes"))

local Motion = {}

local SEND_MOVING = 1 / 60
local SEND_IDLE = 1 / 4
local MIN_DELAY, MAX_DELAY = 0.035, 0.3
local EXTRAPOLATE = 0.1 -- s past the newest snapshot
local STALE = 0.6 -- s without snapshots: back to Roblox replication
local TELEPORT = 20 -- studs between snapshots: jump, do not slide
local KEEP = 24 -- snapshots per player

type Snap = { t: number, pos: Vector3, yaw: number }
type Track = {
	character: Model?,
	snaps: { Snap },
	lateAvg: number,
	lateDev: number,
	gap: number, -- EMA of the time between moving snapshots
	arrivedAt: number,
	velocity: Vector3,
}
local tracks: { [number]: Track } = {}
local shownDelay: number? = nil -- the largest delay others were drawn with this frame (nil: none drawn by us)

local function angleLerp(a: number, b: number, k: number): number
	local d = (b - a + math.pi) % (2 * math.pi) - math.pi
	return a + d * k
end

local function yawOf(cf: CFrame): number
	local look = cf.LookVector
	return math.atan2(-look.X, -look.Z)
end

local function receive(entry: any)
	if typeof(entry) ~= "table" then
		return
	end
	local userId, pos, yaw, stamp = entry[1], entry[2], entry[3], entry[4]
	if
		typeof(userId) ~= "number"
		or typeof(pos) ~= "Vector3"
		or typeof(yaw) ~= "number"
		or typeof(stamp) ~= "number"
	then
		return
	end
	local player = Players:GetPlayerByUserId(userId)
	if not player or player == Players.LocalPlayer then
		return
	end
	local track = tracks[userId]
	if not track or track.character ~= player.Character then
		track = {
			character = player.Character,
			snaps = {},
			lateAvg = 0.03,
			lateDev = 0.01,
			gap = SEND_MOVING,
			arrivedAt = 0,
			velocity = Vector3.zero,
		}
		tracks[userId] = track
	end
	local snaps = track.snaps
	local last = snaps[#snaps]
	if last and stamp <= last.t then
		return -- out of order (unreliable): an older snapshot adds nothing
	end
	if last and (pos - last.pos).Magnitude > TELEPORT then
		table.clear(snaps)
	elseif last and stamp - last.t > 3 * track.gap then
		-- moving again after the slow idle snapshots: it stood still until just before this one (without
		-- this point the start would be smeared over the whole idle gap and lag behind)
		if (pos - last.pos).Magnitude > 0.01 then
			table.insert(snaps, { t = stamp - track.gap, pos = last.pos, yaw = last.yaw })
		end
	elseif last then
		track.gap += (math.min(stamp - last.t, 0.1) - track.gap) * 0.1
	end
	table.insert(snaps, { t = stamp, pos = pos, yaw = yaw })
	if #snaps > KEEP then
		table.remove(snaps, 1)
	end
	local now = workspace:GetServerTimeNow()
	-- lateness = one-way trip + jitter; a quick EMA of it and of its deviation sets the buffer
	local late = now - stamp
	local dev = math.abs(late - track.lateAvg)
	track.lateAvg += (late - track.lateAvg) * 0.1
	track.lateDev += (dev - track.lateDev) * 0.1
	track.arrivedAt = os.clock()
end

-- where a tracked character is drawn at server time `at`; nil when there is nothing to draw from
local function sample(track: Track, at: number): (Vector3?, number?, Vector3?)
	local snaps = track.snaps
	local n = #snaps
	if n == 0 then
		return nil
	end
	local newest = snaps[n]
	if at >= newest.t then
		if n == 1 then
			return newest.pos, newest.yaw, Vector3.zero
		end
		local prev = snaps[n - 1]
		local v = (newest.pos - prev.pos) / math.max(newest.t - prev.t, 1 / 120)
		local ahead = math.min(at - newest.t, EXTRAPOLATE)
		return newest.pos + v * ahead, newest.yaw, v
	end
	for i = n - 1, 1, -1 do
		local a = snaps[i]
		if a.t <= at then
			local b = snaps[i + 1]
			local k = (at - a.t) / math.max(b.t - a.t, 1e-3)
			local v = (b.pos - a.pos) / math.max(b.t - a.t, 1 / 120)
			return a.pos:Lerp(b.pos, k), angleLerp(a.yaw, b.yaw, k), v
		end
	end
	return snaps[1].pos, snaps[1].yaw, Vector3.zero -- older than the buffer: hold the oldest
end

local function draw()
	local now = workspace:GetServerTimeNow()
	local clock = os.clock()
	local largest: number? = nil
	for userId, track in pairs(tracks) do
		local player = Players:GetPlayerByUserId(userId)
		local character = player and player.Character
		if not player or character ~= track.character then
			tracks[userId] = nil
			continue
		end
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or clock - track.arrivedAt > STALE
		then
			track.velocity = Vector3.zero
			continue -- Roblox replication draws it
		end
		local delay =
			math.clamp(track.lateAvg + 2 * track.lateDev + track.gap, MIN_DELAY, MAX_DELAY)
		local pos, yaw, v = sample(track, now - delay)
		if pos and yaw then
			root.CFrame = CFrame.new(pos) * CFrame.Angles(0, yaw, 0)
			track.velocity = v or Vector3.zero
			largest = math.max(largest or 0, delay)
		end
	end
	shownDelay = largest
end

-- The server time the other players are drawn at right now; sent with a blow or an arrow so the server tests
-- them where we saw them (MotionService lag compensation). nil when none is drawn from our snapshots.
function Motion.viewTime(): number?
	return if shownDelay then workspace:GetServerTimeNow() - shownDelay else nil
end

-- The velocity another character is drawn with (for its walk animation); nil when Roblox draws it.
function Motion.velocity(character: Model): Vector3?
	local player = Players:GetPlayerFromCharacter(character)
	local track = player and tracks[player.UserId]
	if track and track.character == character and os.clock() - track.arrivedAt <= STALE then
		return track.velocity
	end
	return nil
end

function Motion.Start()
	local send = Remotes.unreliable("Motion")
	local lastSent, lastPos, lastYaw = 0, Vector3.zero, 0
	RunService.Heartbeat:Connect(function()
		local character = Players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
			return
		end
		local clock = os.clock()
		local pos, yaw = root.Position, yawOf(root.CFrame)
		local moved = (pos - lastPos).Magnitude > 0.01
			or math.abs(angleLerp(lastYaw, yaw, 1) - lastYaw) > 0.005
		if clock - lastSent < (if moved then SEND_MOVING else SEND_IDLE) - 0.002 then
			return
		end
		lastSent, lastPos, lastYaw = clock, pos, yaw
		send:FireServer(pos, yaw, workspace:GetServerTimeNow())
	end)
	Remotes.unreliable("MotionFx").OnClientEvent:Connect(function(batch: any)
		if typeof(batch) == "table" then
			for _, entry in ipairs(batch) do
				receive(entry)
			end
		end
	end)
	-- after Roblox has placed the characters for this frame, before it is drawn
	RunService:BindToRenderStep("CocoMotion", Enum.RenderPriority.First.Value, draw)
end

return Motion
