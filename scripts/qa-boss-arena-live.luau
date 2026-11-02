--!nocheck
-- Real BossService encounters on the existing cloud arenas; run as a Script with BossId attribute.
-- One real player is moved between grounded waypoints. Natural AI and damage paths are unchanged.
-- Creative needs protection remains enabled, but its ForceField is temporarily detached.
-- Health is refilled to prevent inventory loss: this is NOT a solo/group balance or survival test.
-- Only leash/respawn waits are accelerated in the shared runtime config; always restored on exit.
assert(game.RunService:IsStudio() and game.RunService:IsServer(), "Studio Server only")
local id = assert(script:GetAttribute("BossId"), "BossId required")
local specs = {
	raven_knight = {
		"RavenKnightEncounter",
		{ "fastcombo", "comboflyattack", "explosion", "ravencall" },
	},
	vecna = { "VecnaEncounter", { "attack2", "flower", "clockcast", "portalcast" } },
	the_lovers = {
		"LoversEncounter",
		{
			"triplecut",
			"sweep",
			"thrust",
			"dashcut",
			"skycut",
			"stars",
			"sickle",
			"spears",
			"arrowcall",
			"phase2",
			"phase3",
		},
	},
	ent = { "EntEncounter", { "rise", "stomp", "leafstorm", "shout" } },
	forest_guardian = { "ForestGuardianEncounter", { "big_punch", "root_sweep", "summon" } },
	reaper = {
		"ReaperEncounter",
		{ "soul1", "circleattack", "groundattack", "teleportinto", "teleportout", "explosion" },
	},
}
local spec = assert(specs[id], "Unsupported live QA boss")
local Config = require(game.ReplicatedStorage.Shared.Config)
local Profile = require(game.ServerScriptService.Server.Services.ProfileService)
local player = assert(game.Players:GetPlayers()[1])
assert(player:GetAttribute("Creative"), "Restore Creative first")
local character = assert(player.Character)
local humanoid = character:FindFirstChildOfClass("Humanoid")
local playerRoot = character.HumanoidRootPart
local returnTo, returnHealth = character:GetPivot(), humanoid.Health
local card
for _, c in Config.bosses.bosses do
	if c.id == id then
		card = c
	end
end
assert(
	card and Profile.Get(player).location == card.locationId,
	"Teleport normally to the boss location first"
)
local originalLeash, originalRespawn = card.fight.leashSeconds, card.respawnSeconds
local result = game.ServerStorage:FindFirstChild("QAArena_" .. id) or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAArena_" .. id, "running", game.ServerStorage
local shields, connections = {}, {}
local report = {
	id = id,
	checks = {},
	actions = {},
	phases = {},
	hits = {},
	summonPeaks = {},
	samples = 0,
	unanchored = 0,
}
local function check(name, value)
	table.insert(report.checks, { name = name, pass = value == true })
	assert(value, name)
end
local function state(stage)
	workspace:SetAttribute("QALiveBossId", id)
	workspace:SetAttribute("QALiveBossStage", stage)
	result.Value = game.HttpService:JSONEncode({
		status = "RUNNING",
		id = id,
		stage = stage,
		samples = report.samples,
		hits = #report.hits,
		actions = report.actions,
	})
end
local function encounters()
	local found = {}
	for _, folder in workspace:GetChildren() do
		if folder.Name == spec[1] then
			table.insert(found, folder)
		end
	end
	return found
end
local function partCount(model)
	local n = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
		end
	end
	return n
end
local boss
local ok, err = xpcall(function()
	game.ServerStorage.BossDebug:Invoke("spawn", id)
	boss = assert(workspace:FindFirstChild("Boss_" .. id))
	local root, bh = boss.PrimaryPart, boss.Humanoid
	local spawn
	for _, a in game.CollectionService:GetTagged("BossSpawn") do
		if a:GetAttribute("BossId") == id then
			spawn = a
		end
	end
	assert(spawn, "No arena marker")
	local origin = spawn.Position
	local ray = RaycastParams.new()
	ray.FilterType, ray.RespectCanCollide = Enum.RaycastFilterType.Exclude, true
	ray.FilterDescendantsInstances = { character, boss }
	local function placeNear(angle, distance)
		local at = origin + Vector3.new(math.sin(angle) * distance, 8, -math.cos(angle) * distance)
		local floor = workspace:Raycast(at, Vector3.new(0, -25, 0), ray)
		assert(floor and floor.Normal.Y > 0.55, "Waypoint has no walkable ground")
		at = floor.Position + Vector3.new(0, humanoid.HipHeight + playerRoot.Size.Y / 2 + 0.1, 0)
		character:PivotTo(CFrame.lookAt(at, Vector3.new(root.Position.X, at.Y, root.Position.Z)))
		playerRoot.AssemblyLinearVelocity = Vector3.zero
	end
	player:RequestStreamAroundAsync(origin)
	placeNear(0, 6)
	for _, child in character:GetChildren() do
		if child:IsA("ForceField") then
			table.insert(shields, child)
			child.Parent = game.ServerStorage
		end
	end
	local previousHealth = humanoid.Health
	table.insert(
		connections,
		humanoid.HealthChanged:Connect(function(hp)
			if hp < previousHealth then
				table.insert(report.hits, {
					action = boss and boss:GetAttribute("Action"),
					amount = previousHealth - hp,
					health = hp,
				})
			end
			previousHealth = hp
		end)
	)
	table.insert(
		connections,
		game.RunService.Heartbeat:Connect(function()
			if humanoid.Parent and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	)
	local pieces = partCount(boss)
	local began, waypoint, phase = os.clock(), -1, 1
	local minY, maxY = root.Position.Y, root.Position.Y
	state("combat")
	while os.clock() - began < (if id == "the_lovers" then 145 else 110) do
		task.wait(0.2)
		local elapsed = os.clock() - began
		assert(
			player.Character == character and humanoid.Health > 0,
			"Player character changed/died"
		)
		assert(
			workspace:FindFirstChild("Boss_" .. id) == boss and bh.Health > 0,
			"Boss replaced/died during AI probe"
		)
		local desiredPhase = if id == "the_lovers" and elapsed >= 55
			then 3
			elseif elapsed >= 25 then 2
			else 1
		if desiredPhase ~= phase then
			phase = desiredPhase
			game.ServerStorage.BossDebug:Invoke("clearDamage", id)
			bh.Health = bh.MaxHealth * (if phase == 3 then 0.2 else 0.4)
		end
		report.phases[tostring(phase)] = true
		local nextWaypoint = math.floor(elapsed / 7)
		if nextWaypoint ~= waypoint then
			waypoint = nextWaypoint
			placeNear(waypoint * math.pi / 2, if waypoint % 3 == 0 then 6 else 20)
		end
		local action = boss:GetAttribute("Action")
		if action then
			report.actions[action] = (report.actions[action] or 0) + 1
		end
		report.samples += 1
		minY, maxY = math.min(minY, root.Position.Y), math.max(maxY, root.Position.Y)
		assert(math.abs(root.Position.Y - origin.Y) < 20, "Boss escaped vertical arena bounds")
		assert(partCount(boss) == pieces, "Boss body parts changed during combat")
		assert(boss:GetAttribute("Shielded") ~= true, "Boss became shielded")
		local copies = 0
		for _, m in workspace:GetChildren() do
			if m.Name == boss.Name then
				copies += 1
			end
		end
		assert(copies == 1, "Duplicate world boss")
		if not root.Anchored then
			report.unanchored += 1
			assert(
				root:GetNetworkOwner() == nil and not root:GetNetworkOwnershipAuto(),
				"Boss physics delegated to client"
			)
		end
		local counts = {}
		for _, folder in encounters() do
			for _, m in folder:GetDescendants() do
				if m:IsA("Model") and m.PrimaryPart then
					local h = m:FindFirstChildOfClass("Humanoid")
					if not h or h.Health > 0 then
						counts[m.Name] = (counts[m.Name] or 0) + 1
					end
				end
			end
		end
		for name, count in counts do
			report.summonPeaks[name] = math.max(report.summonPeaks[name] or 0, count)
		end
		if report.samples % 20 == 0 then
			state("combat phase " .. phase)
		end
		local complete = true
		for _, name in spec[2] do
			if not report.actions[name] then
				complete = false
			end
		end
		if complete and elapsed >= 85 and #report.hits > 0 and report.unanchored > 20 then
			break
		end
	end
	report.minY, report.maxY = minY, maxY
	for _, name in spec[2] do
		check("natural AI: " .. name, report.actions[name] ~= nil)
	end
	check("actual damage reaches equipped player", #report.hits > 0)
	check("physical server-owned chase", report.unanchored > 20)
	check("phase two exercised", report.phases["2"] == true)
	if id == "the_lovers" then
		check("phase three exercised", report.phases["3"] == true)
	end
	for _, shield in shields do
		shield.Parent = character
	end
	state("leash")
	card.fight.leashSeconds = 4
	character:PivotTo(returnTo)
	local deadline = os.clock() + 20
	while os.clock() < deadline do
		if
			bh.Health == bh.MaxHealth
			and #encounters() == 0
			and (root.Position - origin).Magnitude < 8
		then
			break
		end
		task.wait(0.2)
	end
	check("leash heals", bh.Health == bh.MaxHealth)
	check("leash clears summons/props", #encounters() == 0)
	check("leash returns to spawn", (root.Position - origin).Magnitude < 8)
	card.fight.leashSeconds = originalLeash
	state("death")
	placeNear(0, 12)
	local profile = Profile.Get(player)
	local beforeKills, beforeCoins = profile.stats.bosses or 0, profile.coins
	game.ServerStorage.BossDebug:Invoke("clearDamage", id)
	card.respawnSeconds = card.fight.deathDuration + 3
	game.ServerStorage.BossDebug:Invoke("kill", id)
	task.wait(0.2)
	check("death action", boss:GetAttribute("Action") == "death")
	check("corpse anchored and non-colliding", root.Anchored and not root.CanCollide)
	check(
		"respawn countdown published",
		game.ReplicatedStorage.Bosses[id]:GetAttribute("RespawnAt") > workspace:GetServerTimeNow()
	)
	task.wait(card.fight.deathDuration + 0.3)
	check("corpse removed", not boss.Parent)
	check("death clears encounter", #encounters() == 0)
	state("respawn")
	deadline = os.clock() + 6
	local replacement
	repeat
		task.wait(0.2)
		replacement = workspace:FindFirstChild("Boss_" .. id)
	until replacement or os.clock() >= deadline
	check("scheduled respawn creates fresh boss", replacement ~= nil and replacement ~= boss)
	check("respawn full HP", replacement.Humanoid.Health == card.hp)
	local copies = 0
	for _, m in workspace:GetChildren() do
		if m.Name == "Boss_" .. id then
			copies += 1
		end
	end
	check("one respawned model", copies == 1)
	check(
		"unattributed QA death gives no rewards",
		profile.coins == beforeCoins and (profile.stats.bosses or 0) == beforeKills
	)
end, debug.traceback)
card.fight.leashSeconds, card.respawnSeconds = originalLeash, originalRespawn
for _, connection in connections do
	connection:Disconnect()
end
for _, shield in shields do
	if shield.Parent then
		shield.Parent = character
	end
end
if player.Character == character and character.Parent then
	character:PivotTo(returnTo)
	if humanoid.Health > 0 then
		humanoid.Health = math.min(returnHealth, humanoid.MaxHealth)
	end
end
report.status, report.error = if ok then "PASS" else "FAIL", if ok then nil else err
report.limits =
	"One equipped player, automated waypoint movement and health refill; timers accelerated only for lifecycle checks. No group/mobile balance claim."
result.Value = game.HttpService:JSONEncode(report)
workspace:SetAttribute("QALiveBossStage", report.status)
return result.Value
