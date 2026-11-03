--!nocheck
-- Two simulated accounts only. Install with client in Edit; test args release-pvp-v1.
if not game.RunService:IsStudio() or game.StudioTestService:GetTestArgs() ~= "release-pvp-v1" then
	return
end
local P = require(game.ServerScriptService.Server.Services.ProfileService)
local Persistence = require(game.ReplicatedStorage.Shared.Persistence)
local report = { status = "RUNNING", cases = {}, checks = {}, realProfiles = false }
local folder = Instance.new("Folder")
folder.Name = "QAReleasePvp"
folder.Parent = game.ReplicatedStorage
local rpc = Instance.new("RemoteFunction")
rpc.Name = "RPC"
rpc.Parent = folder
local ready = Instance.new("RemoteEvent")
ready.Name = "Ready"
ready.Parent = folder
local clients, backups = {}, {}
ready.OnServerEvent:Connect(function(p)
	clients[p] = true
	folder:SetAttribute("Ready_" .. tostring(p.UserId), true)
end)
local currentCase = "setup"
report.observed = {}
game.ReplicatedStorage
	:WaitForChild("Remotes")
	:WaitForChild("Attack").OnServerEvent
	:Connect(function(p, _, falling)
		local c = p.Character
		local h, root = c.Humanoid, c.HumanoidRootPart
		local motion = require(game.ServerScriptService.Server.Services.MotionService)
		local ray = RaycastParams.new()
		ray.FilterDescendantsInstances = { c }
		ray.RespectCanCollide = true
		local hit = workspace:Raycast(
			root.Position,
			Vector3.new(0, -root.Size.Y / 2 - h.HipHeight - 0.18, 0),
			ray
		)
		table.insert(report.observed, {
			name = currentCase,
			user = p.UserId,
			y = root.Position.Y,
			vy = root.AssemblyLinearVelocity.Y,
			motionY = motion.verticalSpeed(p),
			motionPosition = tostring(motion.rootAt(p)),
			sprint = c:GetAttribute("Sprinting"),
			state = h:GetState().Name,
			falling = falling,
			grounded = hit ~= nil,
			ground = hit and hit.Instance:GetFullName(),
		})
		local observedCase = currentCase
		if observedCase == "falling critical" then
			task.delay(0.1, function()
				local ground = workspace:Raycast(
					root.Position,
					Vector3.new(0, -root.Size.Y / 2 - h.HipHeight - 0.18, 0),
					ray
				)
				table.insert(report.observed, {
					name = observedCase .. " contact",
					y = root.Position.Y,
					vy = root.AssemblyLinearVelocity.Y,
					motionY = motion.verticalSpeed(p),
					grounded = ground ~= nil,
					state = h:GetState().Name,
					sprint = c:GetAttribute("Sprinting"),
				})
			end)
		end
	end)
local ended = false
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
	game.StudioTestService:EndTest(game.HttpService:JSONEncode(report))
end
task.delay(150, function()
	if not ended then
		report.status = "FAIL"
		report.error = "deadline"
		report.startup = {}
		for _, p in game.Players:GetPlayers() do
			table.insert(report.startup, {
				user = p.UserId,
				ready = clients[p] == true,
				profile = P.Get(p) ~= nil,
				character = p.Character ~= nil,
			})
		end
		finish()
	end
end)
local function check(name, ok)
	table.insert(report.checks, { name = name, pass = ok == true })
end
local ok, err = xpcall(function()
	local players
	repeat
		task.wait(0.2)
		players = game.Players:GetPlayers()
	until #players == 2
		and clients[players[1]]
		and clients[players[2]]
		and P.Get(players[1])
		and P.Get(players[2])
	table.sort(players, function(a, b)
		return a.UserId < b.UserId
	end)
	local a, b = players[1], players[2]
	for _, p in players do
		assert(p.UserId < 0, "Refuse real account fixture")
		backups[p] = Persistence.copy(P.Get(p))
		P.Mutate(p, function(profile)
			profile.inventory = { [1] = { id = "sword", level = 1, count = 1 } }
			profile.selectedSlot = 1
			profile.armor = {}
			profile.location = "warzone"
			profile.faction = nil
			profile.gangId = nil
			profile.trainer = {}
			profile.skills = {}
			profile.level = 10
		end)
		for _, child in p.Character:GetChildren() do
			if child:IsA("ForceField") then
				child:Destroy()
			end
		end
	end
	local floor = Instance.new("Part")
	floor.Name = "QAReleaseFloor"
	floor.Anchored = true
	floor.Size = Vector3.new(150, 2, 150)
	floor.Position = Vector3.new(0, 200, 0)
	floor.Parent = workspace
	local ca, cb = CFrame.new(0, 205, 7), CFrame.new(0, 205, 0)
	for _, p in players do
		p:RequestStreamAroundAsync(ca.Position)
	end
	task.wait(4)
	local function prepare()
		for _, p in players do
			p.Character:SetAttribute("AbsorptionHealth", nil)
			p.Character.Humanoid.MaxHealth = 100
			p.Character.Humanoid.Health = 100
			rpc:InvokeClient(p, "reset")
		end
		rpc:InvokeClient(a, "pose", ca)
		rpc:InvokeClient(b, "pose", cb)
		task.wait(1)
		for _, p in players do
			rpc:InvokeClient(p, "reset")
		end
	end
	local function record(name, attacker, victim, before)
		local av, bv = rpc:InvokeClient(attacker, "state"), rpc:InvokeClient(victim, "state")
		local damage = before - victim.Character.Humanoid.Health
		local hits, pushes, impacts = 0, 0, 0
		for _, e in av.events do
			if e.kind == "hit" and e.data.amount > 0 then
				hits += 1
			end
		end
		for _, e in bv.events do
			if e.kind == "push" then
				pushes += 1
			elseif e.kind == "impact" then
				impacts += 1
			end
		end
		table.insert(report.cases, {
			name = name,
			damage = damage,
			hits = hits,
			pushes = pushes,
			impacts = impacts,
			attacker = av,
			victim = bv,
		})
		check(name .. " one accepted result", hits == 1)
		check(name .. " positive damage", damage > 0)
		check(name .. " victim received push", pushes + impacts >= 1)
		local applied, sounds = 0, 0
		for _, e in bv.events do
			if e.kind == "applied" then
				applied += 1
			elseif e.kind == "localHurtSound" then
				sounds += 1
			end
		end
		check(
			name .. " one coherent victim impact",
			impacts == 1 and applied == 1 and sounds == 1 and pushes == 0
		)
		if name == "falling critical" then
			local critical = false
			for _, e in av.events do
				if e.kind == "hit" and e.data.critical then
					critical = true
				end
			end
			check("actual falling hit is critical", critical)
		end
	end
	for _, name in
		{
			"standing",
			"sprinting",
			"running victim",
			"falling critical",
			"reverse direction",
			"native mouse",
		}
	do
		prepare()
		currentCase = name
		local attacker, victim = a, b
		if name == "sprinting" then
			rpc:InvokeClient(a, "move", { sprint = true, direction = Vector3.new(0, 0, -1) })
			task.wait(0.08)
		elseif name == "running victim" then
			rpc:InvokeClient(b, "move", { sprint = true, direction = Vector3.xAxis })
			task.wait(0.06)
		elseif name == "reverse direction" then
			attacker, victim = b, a
		end
		local before = victim.Character.Humanoid.Health
		local inputResult = rpc:InvokeClient(
			attacker,
			if name == "falling critical"
				then "jumpAttack"
				elseif name == "native mouse" then "nativeAttack"
				else "attack",
			victim.UserId
		)
		if name == "native mouse" then
			check("native first-person mouse advances real input handler", inputResult)
		end
		task.wait(0.65)
		record(name, attacker, victim, before)
	end
	prepare()
	currentCase = "rapid repeat"
	local before = b.Character.Humanoid.Health
	for _ = 1, 4 do
		rpc:InvokeClient(a, "attack", b.UserId)
		task.wait(0.08)
	end
	task.wait(0.35)
	record("rapid repeat", a, b, before)
	prepare()
	currentCase = "absorbed hit"
	b.Character:SetAttribute("AbsorptionHealth", 20)
	rpc:InvokeClient(a, "attack", b.UserId)
	task.wait(0.5)
	local av, bv = rpc:InvokeClient(a, "state"), rpc:InvokeClient(b, "state")
	table.insert(report.cases, {
		name = "absorbed hit",
		attacker = av,
		victim = bv,
		golden = b.Character:GetAttribute("AbsorptionHealth"),
	})
	check("absorbed hit consumes golden health", b.Character:GetAttribute("AbsorptionHealth") < 20)
	local landed = false
	for _, e in av.events do
		if e.kind == "hit" and e.data.result == "hit" and e.data.amount > 0 then
			landed = true
		end
	end
	check("absorbed hit tells attacker it landed", landed)
	report.status = "PASS"
	for _, v in report.checks do
		if not v.pass then
			report.status = "FAIL"
		end
	end
end, debug.traceback)
if not ok then
	report.status = "FAIL"
	report.error = tostring(err)
end
finish()
