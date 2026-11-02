--!nocheck
-- Temporary ServerScriptService Script. Launch StudioTestService:ExecuteMultiplayerTestAsync(2,"coco-network-v1").
-- Only negative-ID simulated profiles are edited; full backups are restored before EndTest.
local STS = game:GetService("StudioTestService")
local solo = script:GetAttribute("Solo") == true
local originalPosition
if not game.RunService:IsStudio() or (not solo and STS:GetTestArgs() ~= "coco-network-v1") then
	return
end
local S = game.ServerScriptService.Server.Services
local P = require(S.ProfileService)
local Mine = require(S.MineService)
local Rep = require(S.MineReplicationService)
local Net = require(game.ReplicatedStorage.Shared.MineNet)
local Timing = require(game.ReplicatedStorage.Shared.MotionTiming)
local R = require(game.ReplicatedStorage.Shared.Remotes)
local report = {
	checks = {},
	clients = {},
	status = "RUNNING",
	mode = if solo then "single observer" else "two clients",
}
local backups = {}
local ended = false
local f = Instance.new("Folder")
f.Name = "QANetwork"
f.Parent = game.ReplicatedStorage
local rpc = Instance.new("RemoteFunction")
rpc.Name = "RPC"
rpc.Parent = f
local ready = Instance.new("RemoteEvent")
ready.Name = "Ready"
ready.Parent = f
local clients = {}
ready.OnServerEvent:Connect(function(p)
	clients[p] = true
end)
local function copy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in t do
		out[k] = copy(v)
	end
	return out
end
local function finish()
	if ended then
		return
	end
	ended = true
	for p, backup in backups do
		P.Mutate(p, function(profile)
			for k in profile do
				profile[k] = nil
			end
			for k, v in backup do
				profile[k] = v
			end
		end)
	end
	local encoded = game.HttpService:JSONEncode(report)
	print("[QANetwork] final " .. encoded)
	if solo then
		local player = game.Players:GetPlayers()[1]
		if originalPosition and player and player.Character then
			player.Character:PivotTo(originalPosition)
		end
		for _, name in { "QANetworkBlocks", "QANetworkFloor" } do
			local object = workspace:FindFirstChild(name)
			if object then
				object:Destroy()
			end
		end
		local result = Instance.new("StringValue")
		result.Name = "QANetworkResult"
		result.Value = encoded
		result.Parent = game.ServerStorage
	else
		STS:EndTest(encoded)
	end
end
task.delay(160, function()
	if not ended then
		report.status = "FAIL"
		report.error = "QA deadline"
		finish()
	end
end)
local function check(name, ok)
	table.insert(report.checks, { name = name, pass = ok == true })
	print("[QANetwork] " .. (if ok then "PASS " else "FAIL ") .. name)
	assert(ok, name)
end
print("[QANetwork] waiting for clients and profiles")
local ok, err = xpcall(function()
	local players
	repeat
		task.wait(0.2)
		players = game.Players:GetPlayers()
	until #players == (if solo then 1 else 2)
		and clients[players[1]]
		and (solo or clients[players[2]])
		and P.Get(players[1])
		and (solo or P.Get(players[2]))
	local a, b = players[1], players[2] or players[1]
	print("[QANetwork] clients and profiles ready")
	originalPosition = a.Character:GetPivot()
	for _, p in players do
		if not solo then
			assert(p.UserId < 0, "Only simulated users")
			backups[p] = copy(P.Get(p))
			P.Mutate(p, function(profile)
				profile.inventory = { [1] = { id = "sword", level = 1, count = 1 } }
				profile.armor = {}
				profile.selectedSlot = 1
				profile.level = 10
				profile.faction = nil
				profile.gangId = nil
			end)
		else
			assert(
				P.Get(p).location == "prison" and p:GetAttribute("Creative"),
				"Solo QA needs Creative at prison"
			)
		end
		rpc:InvokeClient(p, "creative")
	end
	task.wait(1)
	local blocks = Instance.new("Folder")
	blocks.Name = "QANetworkBlocks"
	blocks.Parent = workspace
	local centre = Vector3.new(0, 204, -30)
	local floor = Instance.new("Part")
	floor.Name = "QANetworkFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(160, 1, 160)
	floor.Position = centre - Vector3.new(0, 4, 0)
	floor.Parent = workspace
	for n, p in players do
		p.Character:PivotTo(CFrame.new(centre + Vector3.new(n * 5, 0, 0)))
		p:RequestStreamAroundAsync(centre)
	end
	local function block(name, pos, parent)
		local part = Instance.new("Part")
		part.Name = name
		part.Anchored = true
		part.CanCollide = false
		part.Size = Vector3.one
		part.Position = pos
		Rep.Register(part)
		part:AddTag("MineBlock")
		part.Parent = parent
		return part
	end
	local single = block("Single", centre + Vector3.new(0, 4, 0), blocks)
	for _, p in players do
		rpc:InvokeClient(p, "watch", { "Single" })
	end
	local stamp = workspace:GetServerTimeNow()
	local oldId = single:GetAttribute(Net.ATTRIBUTE)
	Rep.Removed(single)
	task.wait(0.5)
	check("authoritative part held for delayed-replication test", single.Parent == blocks)
	for _, p in players do
		local state = rpc:InvokeClient(p, "state")
		check("fast removal reaches " .. p.Name, state.alive.Single == false)
		report.clients[p.Name] = { fastRemovalSeconds = state.removedAt.Single - stamp }
	end
	local reset = block("Reset", single.Position, blocks)
	check("reset cell has a fresh ID", reset:GetAttribute(Net.ATTRIBUTE) ~= oldId)
	for _, p in players do
		rpc:InvokeClient(p, "watch", { "Reset" })
		R.unreliable(Net.REMOTE):FireClient(p, Net.encode({ oldId }, workspace:GetServerTimeNow()))
	end
	task.wait(0.3)
	for _, p in players do
		check(
			"duplicate/old packet preserves reset " .. p.Name,
			rpc:InvokeClient(p, "state").alive.Reset
		)
	end
	single:Destroy()
	local late = block("Late", centre + Vector3.new(0, 5, 0), nil)
	Rep.Removed(late)
	task.wait(0.3)
	late.Parent = blocks
	task.wait(0.5)
	for _, p in players do
		check("packet before streaming " .. p.Name, not rpc:InvokeClient(p, "state").lateExists)
	end
	late:Destroy()
	local lost = block("Lost", centre + Vector3.new(0, 6, 0), blocks)
	for _, p in players do
		rpc:InvokeClient(p, "watch", { "Lost" })
	end
	lost:Destroy()
	task.wait(0.5)
	for _, p in players do
		check(
			"lost fast packet uses normal deletion " .. p.Name,
			not rpc:InvokeClient(p, "state").alive.Lost
		)
	end
	local fake = { id = "qa-network", size = { 32, 1, 32 }, cells = {}, parts = {}, dug = 0 }
	for i = 1, 1024 do
		fake.cells[i] = "stone"
		fake.parts[i] = block(
			"Bulk" .. i,
			centre + Vector3.new((i % 32) - 16, 10, math.floor(i / 32) - 16),
			blocks
		)
		if i % 128 == 0 then
			task.wait()
		end
	end
	for _, p in players do
		rpc:InvokeClient(p, "watchBulk", 1024)
	end
	for i = 1, 1024 do
		assert(Mine.breakBlock(fake, i) == "stone")
	end
	task.wait(0.6)
	for _, p in players do
		local state = rpc:InvokeClient(p, "state")
		local remaining = 0
		for name, alive in state.alive do
			if name:sub(1, 4) == "Bulk" and alive then
				remaining += 1
			end
		end
		check("1024-cell AoE batch " .. p.Name, remaining == 0 and state.largestPacket <= 777)
		report.clients[p.Name].largestPacket = state.largestPacket
	end
	local packet = Net.encode({ 1, 4294967295 }, 100)
	check("codec uint32 extremes", Net.decode(packet, 100)[2] == 4294967295)
	check("expired packet refused", Net.decode(packet, 104) == nil)
	check("future packet refused", Net.decode(packet, 98) == nil)
	check("malformed packet refused", Net.decode(buffer.create(10), 100) == nil)
	check("non-buffer refused", Net.decode({}, 100) == nil)
	buffer.writef64(packet, 1, 0 / 0)
	check("NaN timestamp refused", Net.decode(packet, 100) == nil)
	local predicted = Timing.project(Vector3.new(1, 0, 0), Vector3.zero, 1 / 60, 1)
	check("prediction spatial cap", (predicted - Vector3.new(1, 0, 0)).Magnitude <= 3.001)
	check(
		"idle gap never extrapolates",
		Timing.project(Vector3.one, Vector3.zero, 0.25, 0.05) == Vector3.one
	)
	report.bufferComparison = {
		oldMilliseconds = (0.05 + 2 * 0.005 + 1 / 60) * 1000,
		newMilliseconds = Timing.delay(0.05, 0.005, 1 / 60) * 1000,
		note = "Same 50ms transit/5ms jitter inputs, formula comparison, not WAN measurement",
	}
	if not solo then
		for n, p in players do
			p.Character:PivotTo(CFrame.new(centre + Vector3.new(n * 5, 0, 0)))
		end
		local began = workspace:GetServerTimeNow() + 0.3
		rpc:InvokeClient(b, "observe", a.UserId, { base = centre, start = began })
		rpc:InvokeClient(a, "move", centre, began)
		task.wait(7)
		rpc:InvokeClient(b, "finishObserve")
		local stopped = rpc:InvokeClient(a, "stop")
		task.wait(0.2)
		report.stopErrorStuds = rpc:InvokeClient(b, "stopError", a.UserId, stopped)
		check("stop settles without idle wait", report.stopErrorStuds < 1.5)
		local state = rpc:InvokeClient(b, "state")
		local sum = 0
		for _, v in state.motion.delays do
			sum += v
		end
		local errorSum, maxError = 0, 0
		for _, v in state.motion.errors do
			errorSum += v
			maxError = math.max(maxError, v)
		end
		report.motion = {
			samples = #state.motion.delays,
			meanRenderedAgeMs = sum / math.max(1, #state.motion.delays) * 1000,
			meanPositionErrorStuds = errorSum / math.max(1, #state.motion.errors),
			maxPositionErrorStuds = maxError,
			note = "Rendered age is the selected snapshot timestamp, not measured end-to-end latency. Position error compares the observer with the scheduled sinusoidal path after warmup.",
		}
		check("actual second client uses fast motion", report.motion.samples > 20)
		for _, p in players do
			P.Mutate(p, function(profile)
				-- Ghetto evicts simulated users without a gang; use an unrestricted PvP fixture location.
				profile.location = "warzone"
			end)
			for _, child in p.Character:GetChildren() do
				if child:IsA("ForceField") then
					child:Destroy()
				end
			end
		end
		a.Character:PivotTo(CFrame.new(centre))
		b.Character:PivotTo(CFrame.new(centre + Vector3.new(0, 0, 6)))
		task.wait(0.7)
		local healthBefore = a.Character.Humanoid.Health
		rpc:InvokeClient(b, "hit", a.UserId)
		task.wait(0.5)
		local hitState = rpc:InvokeClient(b, "state")
		report.pvp = hitState.hits
		report.pvpHealthLost = healthBefore - a.Character.Humanoid.Health
		check(
			"normal PvP Attack receives damaging HitConfirm",
			#report.pvp > 0 and report.pvp[#report.pvp].amount > 0 and report.pvpHealthLost > 0
		)
	end
	-- Real mine, two clients competing for one cell: exactly one server credit.
	local mine = Mine.get("prison")
	assert(mine)
	local part, index
	for i, candidate in mine.parts do
		local x, y, z = Mine.coords(mine, i)
		if y == 1 and x == 5 and z == 5 then
			part, index = candidate, i
			break
		end
	end
	assert(part, "No dig fixture cell")
	for n, p in players do
		if not solo then
			P.Mutate(p, function(profile)
				profile.location = "prison"
			end)
		end
		p.Character:PivotTo(CFrame.new(part.Position + Vector3.new((n - 1) * 5, 6, 0)))
		p:RequestStreamAroundAsync(part.Position)
	end
	task.wait(0.6)
	local function credits()
		local total = 0
		for _, p in players do
			total += P.Get(p).stats.blocksClean or 0
		end
		return total
	end
	local before = credits()
	local digAt = workspace:GetServerTimeNow() + 0.5
	rpc:InvokeClient(a, "dig", part, digAt)
	if not solo then
		rpc:InvokeClient(b, "dig", part, digAt)
	end
	task.wait(1)
	local after = credits()
	check(
		if solo
			then "normal dig removes and credits one cell"
			else "two dig intents remove one authoritative cell",
		mine.cells[index] == nil and after - before == 1
	)
	local removedId = part:GetAttribute(Net.ATTRIBUTE)
	for _, p in players do
		local state = rpc:InvokeClient(p, "state")
		check(
			"real dig fast ID delivered " .. p.Name,
			state.ids[removedId] or state.ids[tostring(removedId)]
		)
	end
	report.status = "PASS"
end, debug.traceback)
if not ok then
	report.status = "FAIL"
	report.error = tostring(err)
end
finish()
