--!nocheck
-- Actual single-client Motion wire check. It does not replace a two-client PvP playtest.
assert(game.RunService:IsStudio() and game.RunService:IsServer())
local player = game.Players:GetPlayers()[1]
assert(player:GetAttribute("Creative"))
local original = player.Character:GetPivot()
local Motion = require(game.ServerScriptService.Server.Services.MotionService)
local Remotes = require(game.ReplicatedStorage.Shared.Remotes)
local signal = Instance.new("RemoteEvent")
signal.Name = "QAMotionProbe"
signal.Parent = game.ReplicatedStorage
local samples = {}
local bursts = { short = { seen = 0, matched = 0 }, flood = { seen = 0, matched = 0 } }
local testingBurst = false
local stoppedAt
local finished = false
local connection = Remotes.unreliable("Motion").OnServerEvent
	:Connect(function(p, pos, yaw, stamp, marker)
		if p ~= player then
			return
		end
		local lateness = workspace:GetServerTimeNow() - stamp
		if bursts[marker] then
			testingBurst = true
		end
		-- Remote signal listeners have no ordering guarantee. Read history after the production handler,
		-- at this packet's timestamp (another packet may already have been accepted in the same batch).
		task.defer(function()
			if finished then
				return
			end
			local current = Motion.rootAt(p, stamp)
			local latest = Motion.rootAt(p)
			local future = Motion.rootAt(p, stamp + 0.05)
			local burst = bursts[marker]
			if burst then
				burst.seen += 1
				if current and (current.Position - pos).Magnitude < 0.0001 then
					burst.matched += 1
				end
				return
			end
			-- Artificial burst positions deliberately replace the normal history in this separate phase.
			if testingBurst then
				return
			end
			table.insert(samples, {
				pos = pos,
				stamp = stamp,
				late = lateness,
				error = current and (current.Position - pos).Magnitude or -1,
				projection = latest and future and (future.Position - latest.Position).Magnitude
					or -1,
			})
		end)
	end)
local function finish()
	if finished then
		return
	end
	finished = true
	connection:Disconnect()
	local count, total, maxError, maxProjection = 0, 0, 0, 0
	local stopGap
	for i, s in samples do
		total += s.late
		maxError = math.max(maxError, s.error)
		maxProjection = math.max(maxProjection, s.projection)
		if s.error >= 0 then
			count += 1
		end
		local before = samples[i - 1]
		if
			before
			and stoppedAt
			and s.stamp >= stoppedAt
			and (s.pos - before.pos).Magnitude < 0.01
			and not stopGap
		then
			stopGap = s.stamp - before.stamp
		end
	end
	local report = {
		status = if count > 10
				and maxError < 0.01
				and maxProjection <= 3.001
				and stopGap
				and stopGap < 0.15
				and bursts.short.matched >= 3
				and bursts.flood.seen >= 20
				and bursts.flood.matched < bursts.flood.seen / 2
			then "PASS"
			else "FAIL",
		samples = #samples,
		validatedSamples = count,
		meanClientToServerMs = total / math.max(1, #samples) * 1000,
		maxSnapshotErrorStuds = maxError,
		maxProjectionStuds = maxProjection,
		stopRepeatGapMs = stopGap and stopGap * 1000,
		burstHistoryMatches = bursts,
		limits = "One actual client to server; background viewport. No second observer or WAN PvP benchmark.",
	}
	if player.Character then
		player.Character:PivotTo(original)
		player.Character.HumanoidRootPart.AssemblyLinearVelocity = Vector3.zero
	end
	local v = Instance.new("StringValue")
	v.Name = "QAMotionResult"
	v.Value = game.HttpService:JSONEncode(report)
	v.Parent = game.ServerStorage
end
signal.OnServerEvent:Connect(function(p, op, stamp)
	if p ~= player then
		return
	end
	if op == "stop" then
		stoppedAt = stamp
	elseif op == "done" then
		finish()
	end
end)
task.delay(15, finish)
