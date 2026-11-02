--!nocheck
-- PENDING Studio run. Disposable fixtures: no profiles, live boss kills or rewards touched.
assert(
	game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer(),
	"Studio Server only"
)
local API = require(game.ServerScriptService.Server.Services.ForestGuardianAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cfg
for _, c in Config.bosses.bosses do
	if c.id == "forest_guardian" then
		cfg = c.fight
		assert(c.hp == 3340, "Forest Guardian HP changed")
	end
end
assert(cfg and cfg.forestGuardian, "Forest Guardian config missing")
assert(not workspace:FindFirstChild("QAForestGuardianFixtures"), "Previous QA fixtures still exist")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QAForestGuardianFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QAForestGuardianResult")
	or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAForestGuardianResult", "running", game.ServerStorage
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
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = 3340, 3340, cfg.walkSpeed, 2
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
		if e.Name == "ForestGuardianEncounter" then
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

local names = { "big_punch", "root_sweep" }
for index, name in names do
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
			local c = cfg.forestGuardian[name]
			tr.Position = o + Vector3.new(0, 3, -8)
			if mode == "range" then
				tr.Position = o + Vector3.new(0, 3, -60)
			end
			if mode == "arena" then
				b.arenaRadius = 1
			end
			if mode == "noFloor" then
				g.Floor:Destroy()
			end
			if mode == "wall" then
				part("Wall", o + Vector3.new(0, 5, -4), Vector3.new(40, 10, 1), g)
			end
			API.Cast(b, index, tr.Position, false, hooks)
			check(name .. " action", actions[1] == name and not b.model:GetAttribute("Shielded"))
			task.wait(0.3)
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
			task.wait(c.duration + 3)
			check(
				name .. mode .. " damage",
				math.abs(total(hits) - (if mode == "hit" then c.damage else 0)) < 0.001
			)
			API.Clear(b)
			g:Destroy()
		end)
	end
end
run("overlapping phase-two roots share one budget", function()
	local b, tr, hooks, hits, _, g, o = fixture()
	tr.Position = o + Vector3.new(0, 3, -6)
	API.Cast(b, 2, tr.Position, true, hooks)
	task.wait(cfg.forestGuardian.root_sweep.duration + 0.3)
	check("overlapping roots one 49 damage", #hits == 1 and total(hits) == 49)
	API.Clear(b)
	g:Destroy()
end)
run("no extra late damage after clear", function()
	local b, tr, hooks, hits, _, g, o = fixture()
	tr.Position = o + Vector3.new(0, 3, -8)
	API.Cast(b, 2, tr.Position, true, hooks)
	task.wait(cfg.forestGuardian.root_sweep.release + 0.1)
	API.Clear(b)
	task.wait(1)
	check("released root cancels on clear", #hits == 0 and #summons(o) == 0)
	g:Destroy()
end)
run("two punches and ownership", function()
	local b, tr, hooks, hits, actions, g = fixture()
	b.root.Anchored = false
	b.root:SetNetworkOwner(nil)
	for i, name in { "attack", "attack_left" } do
		API.Melee(b, tr.Position, hooks)
		task.wait(cfg.forestGuardian[name].duration + 0.3)
		check(name .. " contact", actions[i] == name and #hits == i and hits[i] == 38)
		check(
			"movement restored",
			not b.root.Anchored
				and b.root:GetNetworkOwner() == nil
				and b.humanoid.WalkSpeed == cfg.walkSpeed
		)
	end
	API.Clear(b)
	g:Destroy()
end)
run("minion cap, mortality, lifetime and leash", function()
	local b, tr, hooks, _, _, g, o = fixture()
	tr.Position = o + Vector3.new(0, 3, -30)
	API.Cast(b, 3, tr.Position, true, hooks)
	task.wait(3.3)
	check("phase two summons three", #summons(o, "guardian_minion") == 3)
	API.Cast(b, 3, tr.Position, true, hooks)
	task.wait(3.3)
	local adds = summons(o, "guardian_minion")
	check("four living minion cap", #adds == 4)
	for _, m in adds do
		check(
			"ordinary mortal mob",
			m.Humanoid.MaxHealth == 80
				and game.CollectionService:HasTag(m, "Mob")
				and not game.CollectionService:HasTag(m, "Boss")
		)
	end
	task.wait(2)
	check(
		"server network ownership",
		not adds[1].PrimaryPart.Anchored and adds[1].PrimaryPart:GetNetworkOwner() == nil
	)
	adds[1].Humanoid.Health = 0
	task.wait(0.2)
	check("death anchored", adds[1].PrimaryPart.Anchored)
	task.wait(cfg.forestGuardian.summon.minion.deathDuration + 0.2)
	check("dead minion removed", not adds[1].Parent)
	task.wait(25)
	check("finite lifetime", #summons(o, "guardian_minion") == 0)
	API.Cast(b, 3, tr.Position, true, hooks)
	task.wait(2.1)
	API.Clear(b)
	check("leash clears all summons", #summons(o) == 0)
	g:Destroy()
end)
run("spawn vulnerable", function()
	local b, _, hooks, _, actions, g = fixture()
	API.Spawn(b, hooks)
	check("no spawn shield", not b.model:GetAttribute("Shielded"))
	task.wait(cfg.forestGuardian.spawnDuration + 0.2)
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
