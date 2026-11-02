--!nocheck
-- PENDING Studio run. Disposable fixtures: no profiles, live boss kills or rewards touched.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API = require(game.ServerScriptService.Server.Services.RavenKnightAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cfg
for _, c in Config.bosses.bosses do
	if c.id == "raven_knight" then
		cfg = c.fight
		assert(c.hp == 2550)
	end
end
assert(cfg and cfg.ravenKnight)
assert(not workspace:FindFirstChild("QARavenKnightFixtures"))
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QARavenKnightFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QARavenKnightResult")
	or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QARavenKnightResult", "running", game.ServerStorage
local checks, errors, active = {}, {}, {}
local remaining, number = 0, 0
local function part(name, at, size, parent)
	local p = Instance.new("Part")
	p.Name, p.Position, p.Size, p.Anchored, p.Parent = name, at, size, true, parent
	return p
end
local function fixture()
	number += 1
	local o = Vector3.new(195000 + number * 500, 30000, 0)
	local g = Instance.new("Folder")
	g.Parent = folder
	part("Floor", o - Vector3.new(0, 1, 0), Vector3.new(150, 2, 150), g)
	local m = Instance.new("Model")
	m.Parent = g
	local r = part("HumanoidRootPart", o + Vector3.new(0, 4.5, 0), Vector3.new(4, 5, 3), m)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = 2550, 2550, cfg.walkSpeed, 2
	h.Parent = m
	local spawn = part("Spawn", o - Vector3.new(0, 0.5, 0), Vector3.one, g)
	spawn.CanCollide, spawn.CanQuery = false, false
	local target = Instance.new("Model")
	target.Parent = g
	local tr = part("HumanoidRootPart", o + Vector3.new(0, 3, -6), Vector3.new(2, 2, 2), target)
	local th = Instance.new("Humanoid")
	th.RequiresNeck = false
	th.Parent = target
	local fighter = { player = { Character = target }, root = tr, humanoid = th }
	local state = Instance.new("Folder")
	state.Parent = g
	local boss = {
		root = r,
		model = m,
		humanoid = h,
		spawn = spawn,
		state = state,
		fight = cfg,
		arenaRadius = 60,
		busyUntil = 0,
		nextAbilityAt = 0,
	}
	table.insert(active, boss)
	local hits, actions = {}, {}
	local hooks = {
		fighters = function()
			return { fighter }
		end,
		hurt = function(_, _, amount)
			table.insert(hits, amount)
			return true
		end,
		act = function(_, name)
			table.insert(actions, name)
			m:SetAttribute("Action", name)
		end,
		telegraph = function(size, cf)
			local p = part("Mark", cf.Position, size, g)
			p.CFrame = cf
			p.CanCollide, p.CanQuery = false, false
			return p
		end,
	}
	return boss, tr, hooks, hits, actions, g, o
end
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local function run(name, fn)
	while remaining >= 4 do
		task.wait(0.1)
	end
	remaining += 1
	task.spawn(function()
		local ok, err = xpcall(fn, debug.traceback)
		if not ok then
			table.insert(errors, name .. ": " .. tostring(err))
		end
		remaining -= 1
	end)
end
local function summons(o, id)
	local list = {}
	for _, e in workspace:GetChildren() do
		if e.Name == "RavenKnightEncounter" then
			for _, m in e:GetChildren() do
				if
					m:IsA("Model")
					and m.PrimaryPart
					and (m.PrimaryPart.Position - o).Magnitude < 100
					and (not id or m.Name == id)
				then
					table.insert(list, m)
				end
			end
		end
	end
	return list
end
local function total(hits)
	local sum = 0
	for _, d in hits do
		sum += d
	end
	return sum
end
for index, name in { "fastcombo", "comboflyattack", "explosion", "ravencall" } do
	for _, mode in { "hit", "wall", "dynamicWall", "dodge", "death", "clear", "replacement" } do
		run(name .. mode, function()
			local b, tr, hooks, hits, _, g, o = fixture()
			if index == 2 then
				tr.Position = o + Vector3.new(0, 3, -15)
			end
			local function wall()
				part("Wall", o + Vector3.new(0, 8, -3), Vector3.new(45, 16, 1), g)
			end
			if mode == "wall" then
				wall()
			end
			API.Cast(b, index, tr.Position, false, hooks)
			check(name .. " vulnerable", b.model:GetAttribute("Shielded") == false)
			if mode == "dodge" then
				tr.Position += Vector3.new(50, 0, 0)
			end
			if mode == "dynamicWall" then
				task.wait(0.3)
				wall()
			end
			if mode == "death" then
				task.wait(0.1)
				b.humanoid.Health = 0
				API.Clear(b)
			end
			if mode == "clear" then
				task.wait(0.1)
				API.Clear(b)
			end
			if mode == "replacement" then
				task.wait(0.1)
				tr.Position += Vector3.new(50, 0, 0)
				API.Melee(b, tr.Position, hooks)
			end
			task.wait(6.3)
			check(
				name .. mode .. " damage=" .. total(hits),
				if mode == "hit"
					then math.abs(total(hits) - cfg.ravenKnight[name].damage) < 0.001
					else #hits == 0
			)
			API.Clear(b)
			check(name .. mode .. " clears props", #summons(o) == 0)
			g:Destroy()
		end)
	end
end
for index = 2, 3 do
	for _, mode in { "noFloor", "lostFloor", "lowWall", "zeroTarget" } do
		run("movement/ground " .. index .. mode, function()
			local b, tr, hooks, hits, _, g, o = fixture()
			tr.Position = o + Vector3.new(0, 3, -12)
			if mode == "noFloor" then
				g.Floor:Destroy()
			end
			if mode == "lowWall" then
				part("LowWall", o + Vector3.new(0, 0.7, -6), Vector3.new(30, 1.4, 1), g)
			end
			local target = if mode == "zeroTarget" then b.root.Position else tr.Position
			API.Cast(b, index, target, false, hooks)
			if mode == "lostFloor" then
				task.wait(1.7)
				g.Floor:Destroy()
			end
			task.wait(6.3)
			local p = b.root.Position
			check("finite position " .. index .. mode, p.X == p.X and p.Y == p.Y and p.Z == p.Z)
			if
				mode == "noFloor"
				or mode == "lostFloor"
				or (index == 2 and (mode == "lowWall" or mode == "zeroTarget"))
			then
				check("no unsupported dash/impact " .. index .. mode, #hits == 0)
			end
			API.Clear(b)
			g:Destroy()
		end)
	end
end
for _, mode in { "phase1", "phase2", "cap", "kill", "death", "clear", "ceiling", "lifecycle" } do
	run("retainer " .. mode, function()
		local b, tr, hooks, hits, _, g, o = fixture()
		if mode == "ceiling" then
			part("Ceiling", o + Vector3.new(0, 7, 0), Vector3.new(30, 0.5, 20), g)
		end
		API.Cast(b, 4, tr.Position, mode ~= "phase1", hooks)
		local deadline = os.clock() + 3.5
		repeat
			task.wait(0.1)
		until #summons(o, "crow_reaper") > 0 or os.clock() > deadline
		local list = summons(o, "crow_reaper")
		if mode == "phase1" or mode == "ceiling" then
			check("no retainer " .. mode, #list == 0)
		else
			check("one retainer " .. mode, #list == 1)
			local m = list[1]
			local h = m.Humanoid
			check(
				"retainer HP/vulnerable",
				h.MaxHealth == 160
					and m:GetAttribute("Shielded") == false
					and not game.CollectionService:HasTag(m, "Boss")
			)
			if mode == "kill" then
				task.wait(1.7) -- allow the already-launched boss volley to finish before measuring the killed retainer
				check(
					"normal combat kills retainer",
					require(game.ServerScriptService.Server.Services.CombatService).ApplyDamage(
						h,
						1000,
						"player"
					) and h.Health <= 0
				)
				local n = #hits
				task.wait(4)
				check("dead retainer cannot attack", #hits == n)
			elseif mode == "death" then
				b.humanoid.Health = 0
				API.Clear(b)
			elseif mode == "clear" then
				API.Clear(b)
			elseif mode == "cap" then
				API.Cast(b, 4, tr.Position, true, hooks)
				task.wait(2)
				check("one companion cap", #summons(o, "crow_reaper") == 1)
			elseif mode == "lifecycle" then
				local seen = {}
				local untilAt = os.clock() + 26
				while os.clock() < untilAt and m.Parent and h.Health > 0 do
					local action = m:GetAttribute("Action")
					if action then
						seen[action] = true
					end
					if not m.PrimaryPart.Anchored then
						check(
							"retainer server owned",
							m.PrimaryPart:GetNetworkOwner() == nil
								and not m.PrimaryPart:GetNetworkOwnershipAuto()
						)
					end
					task.wait(0.1)
				end
				for _, name in
					{ "basicattack", "chargeattack", "fogcombo", "summonaxe", "spikesattack" }
				do
					check("retainer clip " .. name, seen[name] == true)
				end
			end
		end
		API.Clear(b)
		check("retainer cleanup " .. mode, #summons(o) == 0)
		g:Destroy()
	end)
end
run("normal combos and ownership", function()
	local b, tr, hooks, hits, actions, g = fixture()
	local victim = tr.Parent.Humanoid
	local combat = require(game.ServerScriptService.Server.Services.CombatService)
	hooks.hurt = function(_, _, amount)
		local accepted = combat.ApplyDamage(victim, amount, "boss")
		if accepted then
			table.insert(hits, amount)
		end
		return accepted
	end
	b.root.Anchored = false
	b.root:SetNetworkOwner(nil)
	for i = 1, 2 do
		API.Melee(b, tr.Position, hooks)
		task.wait(2.2)
		check("normal combo total " .. i, math.abs(total(hits) - 26 * i) < 0.001)
		check(
			"normal combo real immunity window " .. i,
			math.abs(victim.Health - (100 - 26 * i)) < 0.001
		)
		check(
			"combo direction " .. i,
			actions[i] == (if i == 1 then "simplecombo" else "simplecombo2")
		)
		check(
			"restored server ownership",
			not b.root.Anchored
				and b.root:GetNetworkOwner() == nil
				and not b.root:GetNetworkOwnershipAuto()
		)
	end
	API.Clear(b)
	g:Destroy()
end)
run("spawn", function()
	local b, _, hooks, _, actions, g = fixture()
	API.Spawn(b, hooks)
	check("spawn vulnerable", b.model:GetAttribute("Shielded") == false)
	task.wait(2.5)
	check("spawn finishes", actions[1] == "spawn" and b.humanoid.WalkSpeed == cfg.walkSpeed)
	API.Clear(b)
	g:Destroy()
end)
while remaining > 0 do
	task.wait(0.2)
end
for _, b in active do
	API.Clear(b)
end
folder:Destroy()
result.Value = game.HttpService:JSONEncode({
	status = if #errors == 0 then "PASS" else "FAIL",
	checks = #checks,
	cases = number,
	errors = errors,
})
return result.Value
