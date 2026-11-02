--!nocheck
-- Compare three removal routes with two clients on the same PC; no profile mutations.
-- Launch StudioTestService:ExecuteMultiplayerTestAsync(2, "coco-latency-v1").
if not game.RunService:IsStudio() or game.StudioTestService:GetTestArgs() ~= "coco-latency-v1" then
	return
end
local Rep = require(game.ServerScriptService.Server.Services.MineReplicationService)
local folder = Instance.new("Folder")
folder.Name = "QALatency"
folder.Parent = game.ReplicatedStorage
local rpc, ack = Instance.new("RemoteFunction"), Instance.new("RemoteEvent")
rpc.Name, ack.Name = "RPC", "Ack"
rpc.Parent, ack.Parent = folder, folder
local ready, sent, received = {}, {}, {}
ack.OnServerEvent:Connect(function(p, name, wall, estimated)
	if name == "ready" then
		ready[p] = true
		return
	end
	local sample = sent[name]
	if not sample then
		return
	end
	received[p.Name] = received[p.Name] or {}
	if received[p.Name][name] then
		return
	end
	received[p.Name][name] = {
		phase = sample.phase,
		kind = sample.kind,
		roundTripMs = (os.clock() - sample.clock) * 1000,
		sameMachineWallMs = wall - sample.wall,
		serverTimeEstimateMs = (estimated - sample.estimated) * 1000,
	}
end)
local finished = false
local function finish(report)
	if finished then
		return
	end
	finished = true
	local encoded = game.HttpService:JSONEncode(report)
	print("[QALatency] final " .. encoded)
	game.StudioTestService:EndTest(encoded)
end
task.delay(120, function()
	finish({ status = "FAIL", error = "QA deadline", received = received })
end)
local function stats(values)
	table.sort(values)
	local sum = 0
	for _, v in values do
		sum += v
	end
	return {
		count = #values,
		mean = sum / math.max(1, #values),
		median = values[math.max(1, math.ceil(#values / 2))],
		p95 = values[math.max(1, math.ceil(#values * 0.95))],
		max = values[#values],
	}
end
local ok, result = xpcall(function()
	local players
	repeat
		task.wait(0.2)
		players = game.Players:GetPlayers()
	until #players == 2 and ready[players[1]] and ready[players[2]]
	print("[QALatency] both clients ready")
	local blocks = Instance.new("Folder")
	blocks.Name = "QALatencyBlocks"
	blocks.Parent = workspace
	local centre = players[1].Character.HumanoidRootPart.Position + Vector3.new(0, 6, 0)
	local batches, names = {}, {}
	for n = 1, 30 do
		local batch = {}
		for _, kind in { "fastOnly", "ordinary", "production" } do
			local part = Instance.new("Part")
			part.Name = kind .. n
			part.Size = Vector3.one
			part.Position = centre + Vector3.new(n % 10, math.floor(n / 10), 0)
			part.Anchored, part.CanCollide, part.CanQuery = true, false, false
			Rep.Register(part)
			part:AddTag("MineBlock")
			part.Parent = blocks
			batch[kind] = part
			table.insert(names, part.Name)
		end
		table.insert(batches, batch)
	end
	for _, p in players do
		p:RequestStreamAroundAsync(centre)
		rpc:InvokeClient(p, "watch", names)
	end
	for n, batch in batches do
		if n == 5 then
			print("[QALatency] warmup 15 seconds")
			task.wait(15)
		end
		local clock, wall, estimated =
			os.clock(), DateTime.now().UnixTimestampMillis, workspace:GetServerTimeNow()
		for kind, part in batch do
			sent[part.Name] = {
				clock = clock,
				wall = wall,
				estimated = estimated,
				kind = kind,
				phase = if n <= 4 then "early" else "steady",
			}
			if kind ~= "ordinary" then
				Rep.Removed(part)
			end
			if kind == "fastOnly" then
				-- Isolate fast delivery while ordinary replication is deliberately held back.
				task.delay(1, function()
					part:Destroy()
				end)
			else
				part:Destroy()
			end
		end
		task.wait(0.2)
	end
	task.wait(1.5)
	local out = {
		status = "PASS",
		clients = {},
		measurements = "All processes on one PC. RTT uses only server os.clock; paired arrival differences use one client clock. Wall time is a same-PC diagnostic; GetServerTimeNow is an estimate. No injected latency/loss.",
	}
	for _, p in players do
		local client = rpc:InvokeClient(p, "state")
		local rows = received[p.Name] or {}
		local groups = {}
		local count = 0
		for name, row in rows do
			count += 1
			row.renderWaitMs = client.frames[name]
			local key = row.phase .. "_" .. row.kind
			groups[key] = groups[key]
				or {
					roundTripMs = {},
					sameMachineWallMs = {},
					serverTimeEstimateMs = {},
					renderWaitMs = {},
				}
			for metric, values in groups[key] do
				if row[metric] then
					table.insert(values, row[metric])
				end
			end
		end
		for _, group in groups do
			for metric, values in group do
				group[metric] = stats(values)
			end
		end
		local paired = {}
		for n = 5, 30 do
			local normal, fast = rows["ordinary" .. n], rows["fastOnly" .. n]
			if normal and fast then
				table.insert(paired, normal.sameMachineWallMs - fast.sameMachineWallMs)
			end
		end
		out.clients[p.Name] = {
			count = count,
			groups = groups,
			ordinaryMinusFastMs = stats(paired),
			renderIntervalsMs = stats(client.renderIntervals),
			raw = rows,
		}
		if count ~= 90 then
			out.status = "FAIL"
		end
	end
	return out
end, debug.traceback)
finish(if ok then result else { status = "FAIL", error = result })
