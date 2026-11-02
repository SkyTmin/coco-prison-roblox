--!nocheck
-- PENDING Studio run. Disposable fixtures: no profiles, live boss kills or rewards touched.
assert(
	game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer(),
	"Studio Server only"
)
local API = require(game.ServerScriptService.Server.Services.ReaperAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cfg
for _, c in Config.bosses.bosses do
	if c.id == "reaper" then
		cfg = c.fight
		assert(c.hp == 3500, "Reaper HP changed")
	end
end
assert(cfg and cfg.reaper, "Reaper config missing")
assert(not workspace:FindFirstChild("QAReaperFixtures"), "Previous QA fixtures still exist")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QAReaperFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QAReaperResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAReaperResult", "running", game.ServerStorage
local checks, errors, active = {}, {}, {}
local remaining, number = 0, 0
local function part(name, at, size, parent)
	local p = Instance.new("Part")
	p.Name, p.Position, p.Size, p.Anchored, p.Parent = name, at, size, true, parent
	return p
end
local function fixture()
	number += 1
	local o = Vector3.new(245000 + number * 500, 30000, 0)
	local g = Instance.new("Folder")
	g.Parent = folder
	part("Floor", o - Vector3.new(0, 1, 0), Vector3.new(150, 2, 150), g)
	local m = Instance.new("Model")
	m.Parent = g
	local r = part("HumanoidRootPart", o + Vector3.new(0, 4.5, 0), Vector3.new(4, 5, 3), m)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = 3500, 3500, cfg.walkSpeed, 2
	h.Parent = m
	local spawn = part("Spawn", o - Vector3.new(0, 0.5, 0), Vector3.one, g)
	spawn.CanCollide, spawn.CanQuery = false, false
	local target = Instance.new("Model")
	target.Parent = g
	local tr = part("HumanoidRootPart", o + Vector3.new(0, 3, -6), Vector3.new(2, 2, 2), target)
	local th = Instance.new("Humanoid")
	th.RequiresNeck = false
	th.Parent = target
	local fighter = { player = { Character = target, UserId = 1 }, root = tr, humanoid = th }
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
	boss.qaHitTimes = {}
	local hooks = {
		fighters = function()
			return { fighter }
		end,
		hurt = function(_, _, amount)
			table.insert(hits, amount)
			table.insert(boss.qaHitTimes, os.clock())
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
		if e.Name == "ReaperEncounter" then
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
for _, entry in { { 2, "circleattack" }, { 3, "groundattack" }, { 5, "explosion" } } do
	local index, name = entry[1], entry[2]
	for _, mode in
		{
			"hit",
			"wall",
			"dynamicWall",
			"dodge",
			"death",
			"clear",
			"replacement",
			"noFloor",
			"lostFloor",
			"arena",
			"range",
		}
	do
		run(name .. mode, function()
			local b, tr, hooks, hits, actions, g, o = fixture()
			local c = cfg.reaper[name]
			tr.Position = o + Vector3.new(0, 3, -8)
			if mode == "range" then
				tr.Position = o + Vector3.new(0, 3, -60)
			end
			if mode == "arena" then
				b.arenaRadius = 0.5
			end
			if mode == "noFloor" then
				g.Floor:Destroy()
			end
			if mode == "wall" then
				part("Wall", o + Vector3.new(0, 5, -4), Vector3.new(40, 10, 1), g)
			end
			API.Cast(b, index, tr.Position, false, hooks)
			check(name .. " action", actions[1] == name and not b.model:GetAttribute("Shielded"))
			task.wait(0.25)
			check(name .. " windup", #hits == 0)
			if mode == "dynamicWall" then
				part("Wall", o + Vector3.new(0, 5, -4), Vector3.new(40, 10, 1), g)
			end
			if mode == "lostFloor" then
				g.Floor:Destroy()
			end
			if mode == "dodge" then
				tr.Position = o + Vector3.new(40, 3, 0)
			end
			if mode == "death" then
				b.humanoid.Health = 0
				API.Clear(b)
			end
			if mode == "clear" then
				API.Clear(b)
			end
			if mode == "replacement" then
				b.root = part("Replacement", o + Vector3.new(0, 4.5, 0), Vector3.one, g)
			end
			task.wait(c.duration + 0.5)
			check(
				name .. mode .. " budget",
				math.abs(total(hits) - (if mode == "hit" then c.damage else 0)) < 0.001
			)
			API.Clear(b)
			g:Destroy()
		end)
	end
end
for _, mode in { "hit", "phase2", "wall", "clear", "interrupt", "replacement", "arena" } do
	run("souls " .. mode, function()
		local b, tr, hooks, hits, actions, g, o = fixture()
		tr.Position = o + Vector3.new(0, 3, -14)
		if mode == "wall" then
			part("Wall", o + Vector3.new(0, 6, -7), Vector3.new(40, 12, 1), g)
		end
		if mode == "arena" then
			b.arenaRadius = 5
		end
		API.Cast(b, 1, tr.Position, mode == "phase2", hooks)
		task.wait(0.4)
		check("souls windup", #hits == 0)
		if mode == "interrupt" then
			b.humanoid.Health -= 200
		end
		if mode == "clear" then
			API.Clear(b)
		end
		if mode == "replacement" then
			b.root = part("Replacement", o + Vector3.new(0, 4.5, 0), Vector3.one, g)
		end
		task.wait(6.4)
		local expected = if mode == "hit" or mode == "phase2" then 52 else 0
		check("souls total " .. mode, math.abs(total(hits) - expected) < 0.001)
		if expected > 0 then
			check("souls count", #hits == (if mode == "phase2" then 5 else 3))
			for i = 2, #b.qaHitTimes do
				check("separated contacts", b.qaHitTimes[i] - b.qaHitTimes[i - 1] > 0.5)
			end
		end
		if mode == "interrupt" then
			check(
				"vulnerable soul stagger",
				table.find(actions, "stun") ~= nil and not b.model:GetAttribute("Shielded")
			)
		end
		check("projectiles finite", #summons(o, "reaper_soul") == 0)
		API.Clear(b)
		g:Destroy()
	end)
end
for _, mode in { "gap", "inner", "jump" } do
	run("explosion escape " .. mode, function()
		local b, tr, hooks, hits, _, g, o = fixture()
		tr.Position = o + Vector3.new(0, 3, -8)
		API.Cast(b, 5, tr.Position, true, hooks)
		task.wait(0.3)
		if mode == "gap" then
			tr.Position = o + Vector3.new(-8, 3, 0)
		end
		if mode == "inner" then
			tr.Position = o + Vector3.new(0, 3, -2)
		end
		if mode == "jump" then
			tr.Position = o + Vector3.new(0, 6, -8)
		end
		task.wait(2.2)
		check("explosion " .. mode, #hits == 0)
		API.Clear(b)
		g:Destroy()
	end)
end
for _, mode in
	{
		"move",
		"wall",
		"ceiling",
		"noFloor",
		"clear",
		"death",
		"replacement",
		"dynamicObstacle",
		"playerAtLanding",
	}
do
	run("teleport " .. mode, function()
		local b, tr, hooks, hits, actions, g, o = fixture()
		tr.Position = o + Vector3.new(0, 3, -10)
		local from = b.root.Position
		if mode == "wall" then
			part("Wall", o + Vector3.new(0, 6, -2), Vector3.new(60, 12, 1), g)
		end
		if mode == "ceiling" then
			part("Ceiling", o + Vector3.new(0, 8, -10), Vector3.new(60, 1, 20), g)
		end
		if mode == "noFloor" then
			g.Floor:Destroy()
		end
		API.Cast(b, 4, tr.Position, false, hooks)
		task.wait(0.3)
		local marks = summons(o, "reaper_circle")
		-- Circle is cast-local rather than encounter-local: inspect the bounded cast folder.
		local landing = nil
		for _, folderInWorld in workspace:GetChildren() do
			if folderInWorld.Name == "BossCast" then
				for _, m in folderInWorld:GetChildren() do
					if
						m.Name == "reaper_circle"
						and m:IsA("Model")
						and m.PrimaryPart
						and (m.PrimaryPart.Position - o).Magnitude < 100
					then
						landing = m.PrimaryPart.Position
					end
				end
			end
		end
		if mode == "dynamicObstacle" and landing then
			part("NewObstacle", landing + Vector3.new(0, 4, 0), Vector3.new(8, 8, 8), g)
		end
		if mode == "playerAtLanding" and landing then
			tr.Position = landing + Vector3.new(0, 3, 0)
		end
		if mode == "clear" then
			API.Clear(b)
		end
		if mode == "death" then
			b.humanoid.Health = 0
			API.Clear(b)
		end
		if mode == "replacement" then
			b.root = part("Replacement", from, Vector3.one, g)
		end
		task.wait(2)
		local moved = (b.root.Position - from).Magnitude
		check("teleport zero contact damage", #hits == 0 and #marks == 0)
		check("teleport bounds", moved <= 18.1)
		if mode == "move" then
			check("teleport moved", moved > 3 and table.find(actions, "teleportout") ~= nil)
		elseif mode ~= "wall" then
			check("teleport cancel " .. mode, moved < 0.1)
		else
			check("wall never crossed", b.root.Position.Z >= o.Z - 1.6)
		end
		if mode ~= "death" and mode ~= "replacement" then
			check("teleport movement restored", b.humanoid.WalkSpeed == cfg.walkSpeed)
		end
		API.Clear(b)
		g:Destroy()
	end)
end
run("quick cuts restore server ownership", function()
	local b, tr, hooks, hits, actions, g = fixture()
	b.root.Anchored = false
	b.root:SetNetworkOwner(nil)
	for i, name in { "attack1", "attack2" } do
		API.Melee(b, tr.Position, hooks)
		task.wait(cfg.reaper[name].duration + 0.3)
		check(name .. " damage", #hits == i and hits[i] == 40 and actions[i] == name)
		check(
			name .. " recovery",
			not b.root.Anchored
				and b.root:GetNetworkOwner() == nil
				and b.humanoid.WalkSpeed == cfg.walkSpeed
		)
	end
	API.Clear(b)
	g:Destroy()
end)
run("spawn vulnerable", function()
	local b, _, hooks, _, actions, g = fixture()
	API.Spawn(b, hooks)
	check("no spawn immunity", not b.model:GetAttribute("Shielded"))
	task.wait(cfg.reaper.spawnDuration + 0.2)
	check("spawn restores", actions[1] == "spawn" and b.humanoid.WalkSpeed == cfg.walkSpeed)
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
