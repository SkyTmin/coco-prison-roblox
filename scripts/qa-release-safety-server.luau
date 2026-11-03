--!nocheck
-- 120-second STS probe of the real heartbeat service and retained Prison/Quarry geometry.
-- Server-authored poses are fault injection, not native walking/climbing/input acceptance.
if
	not game.RunService:IsStudio()
	or game.StudioTestService:GetTestArgs() ~= "release-safety-v1"
then
	return
end
local started = os.clock()
local report = {
	status = "RUNNING",
	checks = {},
	regions = {},
	physicalInput = false,
	realProfiles = false,
	deadlineSeconds = 120,
	phase = "startup",
	limitations = {
		"Collision queries verify real collidable exterior walls, not native walking contact.",
		"Fast fall is an unanchored server-owned fault-injection pose; no private recovery function is called.",
		"Legal mine/ladder poses are anchored observations; native climbing and all other locations remain separate acceptance.",
	},
}
local folder = Instance.new("Folder")
folder.Name = "QAReleaseSafety"
local session = game.HttpService:GenerateGUID(false)
folder:SetAttribute("Session", session)
local ready = Instance.new("RemoteEvent")
ready.Name, ready.Parent = "Ready", folder
local clients = {}
ready.OnServerEvent:Connect(function(actor, info)
	if actor.UserId >= 0 or typeof(info) ~= "table" or info.session ~= session then
		return
	end
	report.client = info
	if info.phase == "ready" and info.loadingBlocked == false and info.runtimeReady == true then
		clients[actor] = info
		ready:FireClient(actor, { session = session, ack = true })
	end
end)
folder.Parent = game.ReplicatedStorage
local P, Copy, Fall, player, backup, character, root, humanoid, original, creative, oldAnchored, oldHealth
local finished, healthConnection, minimumHealth = false, nil, nil
local forceFields = {}
local function check(name, passed, observed)
	table.insert(report.checks, { name = name, pass = passed == true, observed = observed })
end
local function vector(v)
	return { v.X, v.Y, v.Z }
end
local function waitFor(predicate, seconds)
	local deadline = math.min(started + 119, os.clock() + seconds)
	repeat
		if finished then
			return false
		end
		if predicate() then
			return true
		end
		task.wait(0.05)
	until os.clock() >= deadline
	return not finished and predicate() == true
end
local function finish()
	if finished then
		return
	end
	finished = true
	if healthConnection then
		healthConnection:Disconnect()
	end
	local restored, err = pcall(function()
		if player and player.UserId < 0 and backup then
			P.Mutate(player, function(p)
				for key in p do
					p[key] = nil
				end
				for key, value in backup do
					p[key] = Copy(value)
				end
			end)
			player:SetAttribute("Creative", creative)
			if player.Character == character and root.Parent then
				Fall.Reset(player)
				root.Anchored = true
				character:PivotTo(original)
				root.AssemblyLinearVelocity, root.AssemblyAngularVelocity =
					Vector3.zero, Vector3.zero
				root.Anchored = oldAnchored
				if not oldAnchored then
					root:SetNetworkOwnershipAuto()
				end
				humanoid.Health = math.min(oldHealth, humanoid.MaxHealth)
				for _, ff in forceFields do
					ff.Parent = character
				end
			end
		end
	end)
	report.cleanup = { restored = restored, error = if not restored then tostring(err) else nil }
	report.elapsed = os.clock() - started
	if not restored then
		report.status = "FAIL"
	end
	game.StudioTestService:EndTest(game.HttpService:JSONEncode(report))
end
task.delay(120, function()
	if not finished then
		report.status, report.error = "FAIL", "deadline"
		finish()
	end
end)
local ok, err = xpcall(function()
	local Services = game.ServerScriptService.Server.Services
	local Shared = game.ReplicatedStorage:WaitForChild("Shared", 15)
	P = require(Services.ProfileService)
	Copy = require(Shared.Persistence).copy
	Fall = require(Services.FallService)
	local Bounds = require(Shared.LocationBounds)
	assert(
		waitFor(function()
			local actors = game.Players:GetPlayers()
			if #actors ~= 1 then
				return false
			end
			player = actors[1]
			assert(player.UserId < 0, "Refuse real account")
			return clients[player] ~= nil
				and P.IsReal(player)
				and player.Character ~= nil
				and workspace:GetAttribute("RuntimeReady") == true
		end, 80),
		"client/profile/runtime readiness timeout"
	)
	assert(
		game.ServerStorage:GetAttribute("TestSessionScope"),
		"Negative profile isolation missing"
	)
	check("negative isolated profile and real client loading completed", true, report.client)
	character = player.Character
	root, humanoid = character.HumanoidRootPart, character.Humanoid
	backup, original, creative =
		Copy(P.Get(player)), character:GetPivot(), player:GetAttribute("Creative")
	oldAnchored, oldHealth = root.Anchored, humanoid.Health
	player:SetAttribute("Creative", false)
	P.Mutate(player, function(p)
		p.needsFree, p.hunger, p.saturation = true, 20, 20
	end)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			table.insert(forceFields, child)
			child.Parent = nil
		end
	end
	healthConnection = humanoid.HealthChanged:Connect(function(health)
		if minimumHealth then
			minimumHealth = math.min(minimumHealth, health)
		end
	end)
	local function pose(cf, anchored, velocity)
		assert(
			not finished and player.Character == character and humanoid.Health > 0,
			"fixture character replaced/dead"
		)
		Fall.Reset(player)
		root.Anchored = true
		character:PivotTo(cf)
		root.AssemblyLinearVelocity, root.AssemblyAngularVelocity = Vector3.zero, Vector3.zero
		root.Anchored = anchored
		if not anchored then
			root:SetNetworkOwner(nil)
			root.AssemblyLinearVelocity = velocity or Vector3.zero
		end
	end
	for _, id in { "prison", "quarry" } do
		report.phase = id
		local map = assert(workspace:FindFirstChild(Bounds.ROOTS[id]), "Retain actual map " .. id)
		local region = assert(Bounds.Measure(map, id), "Cannot measure retained map")
		local guard = assert(map:FindFirstChild(Bounds.GUARD_NAME), "Runtime guard missing")
		local spawn
		for _, part in game.CollectionService:GetTagged("LocationSpawn") do
			local spot = part:GetAttribute("Spot")
			if
				part:IsA("BasePart")
				and part:IsDescendantOf(map)
				and part:GetAttribute("LocationId") == id
				and (spot == nil or spot == "spawn")
				and not part:GetAttribute("PrivateArrival")
			then
				spawn = part
				break
			end
		end
		assert(spawn, "Exact map spawn missing: " .. id)
		local evidence = {
			id = id,
			min = vector(region.min),
			max = vector(region.max),
			floor = region.floor,
			spawn = spawn:GetFullName(),
		}
		table.insert(report.regions, evidence)
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide =
			Enum.RaycastFilterType.Include, { guard }, true
		for _, name in { "West", "East", "North", "South" } do
			local wall = assert(guard:FindFirstChild(name), "Exterior wall missing")
			local axis = if wall.Size.X < wall.Size.Z then Vector3.xAxis else Vector3.zAxis
			local hit = workspace:Raycast(wall.Position - axis * 5, axis * 10, params)
			check(
				id .. " exterior collision query " .. name,
				hit ~= nil and hit.Instance == wall and wall.CanCollide,
				{
					wall = wall:GetFullName(),
					hit = hit and hit.Instance:GetFullName(),
					canQuery = wall.CanQuery,
				}
			)
		end
		P.Mutate(player, function(p)
			p.location = id
		end)
		pose(spawn.CFrame + Vector3.new(0, 4, 0), true)
		task.wait(0.25) -- let ordinary WorldSafetyService heartbeat observe this map
		minimumHealth = humanoid.Health
		local beforeHealth = humanoid.Health
		local fallAt = Vector3.new(spawn.Position.X, region.floor - 8, spawn.Position.Z)
		assert(
			fallAt.Y > workspace.FallenPartsDestroyHeight + 30,
			"Test pose too near engine destroy plane"
		)
		evidence.fallStart, evidence.fallVelocity = vector(fallAt), -180
		pose(CFrame.new(fallAt), false, Vector3.new(0, -180, 0))
		local recovered = waitFor(function()
			return player.Character == character
				and humanoid.Health > 0
				and not root.Anchored
				and (root.Position - (spawn.Position + Vector3.new(0, 4, 0))).Magnitude < 8
		end, 8)
		check(id .. " fast below-floor escape returns to exact same-map spawn", recovered, {
			at = vector(root.Position),
			location = P.Get(player).location,
			target = vector(spawn.Position),
		})
		check(
			id .. " fallback preserves health without ForceField",
			recovered
				and minimumHealth >= beforeHealth
				and humanoid.Health >= beforeHealth
				and not character:FindFirstChildOfClass("ForceField"),
			{ before = beforeHealth, after = humanoid.Health, minimum = minimumHealth }
		)
		assert(recovered, "Recovery failed: " .. id)
		-- Locate a real deepest mine and its actual ladder; never manufacture a shaft or dig live cells.
		local anchor, depth
		for _, part in game.CollectionService:GetTagged("MineAnchor") do
			local size = part:GetAttribute("Size")
			if
				part:IsDescendantOf(map)
				and typeof(size) == "Vector3"
				and (not depth or size.Y > depth)
			then
				anchor, depth = part, size.Y
			end
		end
		assert(anchor, "Real mine anchor missing")
		local ladder, distance
		for _, part in map:GetDescendants() do
			if part:IsA("TrussPart") and math.abs(part.Size.Y - depth * 4) < 1 then
				local d = (Vector2.new(part.Position.X, part.Position.Z) - Vector2.new(
					anchor.Position.X,
					anchor.Position.Z
				)).Magnitude
				if not distance or d < distance then
					ladder, distance = part, d
				end
			end
		end
		assert(ladder, "Real mine ladder missing")
		local delta = anchor.Position - ladder.Position
		local inward = if math.abs(delta.X) > math.abs(delta.Z)
			then Vector3.new(math.sign(delta.X), 0, 0)
			else Vector3.new(0, 0, math.sign(delta.Z))
		for _, sample in
			{
				{ "deep mine ladder", ladder.Position.Y - ladder.Size.Y / 2 + 4 },
				{ "mid ladder", ladder.Position.Y },
			}
		do
			local target = Vector3.new(ladder.Position.X, sample[2], ladder.Position.Z) + inward * 3
			assert(Bounds.Contains(region, target), "Actual ladder lies outside measured region")
			pose(CFrame.new(target), true)
			task.wait(1.25) -- includes a MineService rescue tick as well as safety heartbeats
			check(
				id .. " legal " .. sample[1] .. " remains in place",
				player.Character == character
					and (root.Position - target).Magnitude < 1
					and P.Get(player).location == id,
				{
					anchor = anchor:GetFullName(),
					ladder = ladder:GetFullName(),
					target = vector(target),
					at = vector(root.Position),
					anchoredObservation = true,
				}
			)
		end
	end
	report.status = "PASS"
	for _, result in report.checks do
		if not result.pass then
			report.status = "FAIL"
		end
	end
end, debug.traceback)
if not ok then
	report.status, report.error = "FAIL", tostring(err)
end
finish()
