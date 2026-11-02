--!nocheck
-- PENDING Studio run. Disposable fixtures: no profiles, live boss kills or rewards touched.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer())
local API = require(game.ServerScriptService.Server.Services.VecnaAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cfg
for _, c in Config.bosses.bosses do
	if c.id == "vecna" then
		cfg = c.fight
		assert(c.hp == 2770)
	end
end
assert(cfg and cfg.vecna)
assert(not workspace:FindFirstChild("QAVecnaFixtures"))
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QAVecnaFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QAVecnaResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAVecnaResult", "running", game.ServerStorage
local checks, errors, active = {}, {}, {}
local remaining, number = 0, 0
local function part(name, at, size, parent)
	local p = Instance.new("Part")
	p.Name, p.Position, p.Size, p.Anchored, p.Parent = name, at, size, true, parent
	return p
end
local function fixture()
	number += 1
	local o = Vector3.new(215000 + number * 500, 30000, 1000)
	local g = Instance.new("Folder")
	g.Parent = folder
	part("Floor", o - Vector3.new(0, 1, 0), Vector3.new(150, 2, 150), g)
	local m = Instance.new("Model")
	m.Parent = g
	local r = part("HumanoidRootPart", o + Vector3.new(0, 4.5, 0), Vector3.new(4, 5, 3), m)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = 2770, 2770, cfg.walkSpeed, 2
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
		if e.Name == "VecnaEncounter" then
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

for index, name in { "attack2", "flower", "clockcast" } do
	for _, mode in
		{
			"hit",
			"wall",
			"dynamicWall",
			"lowWall",
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
			local b, tr, hooks, hits, _, g, o = fixture()
			local duration = cfg.vecna[name].duration
			local function wall(low)
				part(
					"Wall",
					o + Vector3.new(0, if low then 0.5 else 8, -3),
					Vector3.new(80, if low then 1 else 16, 1),
					g
				)
			end
			if mode == "wall" then
				wall(false)
			elseif mode == "lowWall" then
				wall(true)
			end
			if mode == "noFloor" then
				g.Floor:Destroy()
			end
			if mode == "arena" then
				tr.Position = o + Vector3.new(60, 3, -6)
			end
			if mode == "range" then
				tr.Position = o + Vector3.new(0, 3, -30)
			end
			API.Cast(b, index, tr.Position, false, hooks)
			check(name .. " vulnerable", b.model:GetAttribute("Shielded") == false)
			if mode == "dodge" then
				tr.Position += Vector3.new(45, 0, 0)
			end
			if mode == "death" then
				b.humanoid.Health = 0
				API.Clear(b)
			end
			if mode == "clear" then
				API.Clear(b)
			end
			if mode == "replacement" then
				tr.Position += Vector3.new(45, 0, 0)
				API.Melee(b, tr.Position, hooks)
			end
			if mode == "dynamicWall" or mode == "lostFloor" then
				task.wait(0.3)
				if mode == "dynamicWall" then
					wall(false)
				else
					g.Floor:Destroy()
				end
			end
			task.wait(if index == 3 then 8 else duration + 0.3)
			check(
				name .. mode .. " damage=" .. total(hits),
				if mode == "hit" then total(hits) == cfg.vecna[name].damage else #hits == 0
			)
			API.Clear(b)
			check(name .. mode .. " props cleaned", #summons(o) == 0)
			g:Destroy()
		end)
	end
end
for _, mode in { "gap", "jump", "lateWall", "lateFloor" } do
	run("wave " .. mode, function()
		local b, tr, hooks, hits, _, g, o = fixture()
		tr.Position = o + Vector3.new(0, 3, -15)
		API.Cast(b, 2, tr.Position, false, hooks)
		if mode == "gap" then
			tr.Position = o + Vector3.new(12, 3, 0)
		end
		if mode == "jump" then
			tr.Position += Vector3.new(0, 5, 0)
		end
		if mode == "lateWall" or mode == "lateFloor" then
			task.wait(cfg.vecna.flower.release + 0.3)
			if mode == "lateFloor" then
				g.Floor:Destroy()
			else
				part("LateWall", o + Vector3.new(0, 0.5, -8), Vector3.new(35, 1, 1), g)
			end
		end
		task.wait(5.8)
		check("wave counter " .. mode, #hits == 0)
		API.Clear(b)
		g:Destroy()
	end)
end
for _, mode in
	{ "kill", "leave", "lostSupport", "lowerSupport", "lateCeiling", "lateWall", "oneClock" }
do
	run("clock " .. mode, function()
		local b, tr, hooks, hits, _, g, o = fixture()
		API.Cast(b, 3, tr.Position, false, hooks)
		if mode == "lateCeiling" then
			task.wait(0.4)
			part("Ceiling", o + Vector3.new(0, 4, -6), Vector3.new(8, 1, 8), g)
			task.wait(1)
			check("clock release rechecks headroom", #summons(o, "vecna_clock") == 0)
		else
			task.wait(cfg.vecna.clockcast.release + 0.2)
			local list = summons(o, "vecna_clock")
			check("one vulnerable clock", #list == 1)
			local clock = list[1]
			check(
				"clock no Boss tag",
				not game.CollectionService:HasTag(clock, "Boss")
					and clock:GetAttribute("Shielded") == false
			)
			if mode == "kill" then
				clock.Humanoid:TakeDamage(80)
			end
			if mode == "leave" then
				tr.Position += Vector3.new(20, 0, 0)
			end
			if mode == "lostSupport" then
				g.Floor:Destroy()
			end
			if mode == "lowerSupport" then
				g.Floor.Position -= Vector3.new(0, 2, 0)
			end
			if mode == "lateWall" then
				tr.Position = o + Vector3.new(0, 3, -12)
				part("ClockWall", o + Vector3.new(0, 5, -9), Vector3.new(20, 10, 1), g)
			end
			if mode == "oneClock" then
				API.Cast(b, 3, tr.Position, false, hooks)
				task.wait(1.5)
				check("clock capped at one", #summons(o, "vecna_clock") == 1)
			end
		end
		task.wait(6.5)
		check(
			"clock " .. mode .. " damage",
			if mode == "oneClock" then total(hits) == 50 else #hits == 0
		)
		API.Clear(b)
		g:Destroy()
	end)
end
for _, mode in
	{
		"base",
		"phase2",
		"interrupt",
		"lateInterrupt",
		"noFloor",
		"headroom",
		"wall",
		"death",
		"clear",
	}
do
	run("portal " .. mode, function()
		local b, tr, hooks, hits, actions, g, o = fixture()
		tr.Position = o + Vector3.new(0, 3, -30)
		if mode == "noFloor" then
			g.Floor:Destroy()
		end
		if mode == "headroom" then
			part("Ceiling", o + Vector3.new(6, 4, 0), Vector3.new(7, 1, 7), g)
		end
		if mode == "wall" then
			part("Wall", o + Vector3.new(3, 7, 0), Vector3.new(1, 14, 15), g)
		end
		API.Cast(b, 4, tr.Position, mode == "phase2", hooks)
		check("portal vulnerable", b.model:GetAttribute("Shielded") == false)
		if mode == "death" then
			b.humanoid.Health = 0
			API.Clear(b)
		end
		if mode == "clear" then
			API.Clear(b)
		end
		if mode == "interrupt" or mode == "lateInterrupt" then
			task.wait(if mode == "interrupt" then 0.3 else 1.65)
			b.humanoid:TakeDamage(cfg.vecna.portalcast.interruptDamage)
			task.wait(0.15)
			check("portal interrupted into stagger", actions[#actions] == "stun")
		end
		task.wait(3.8)
		local list = summons(o)
		local alive = 0
		for _, m in list do
			if m.Name ~= "VecnaPortal" then
				alive += 1
				check(
					"minion vulnerable " .. m.Name,
					m.Humanoid.Health > 0 and not game.CollectionService:HasTag(m, "Boss")
				)
				check(
					"minion finite " .. m.Name,
					m.PrimaryPart.Position.Y == m.PrimaryPart.Position.Y
				)
				if m.Name ~= "vecna_bat" then
					check(
						"minion server owned",
						not m.PrimaryPart.Anchored
							and m.PrimaryPart:GetNetworkOwner() == nil
							and not m.PrimaryPart:GetNetworkOwnershipAuto()
					)
				end
			end
		end
		local expected = if mode == "base"
			then 2
			elseif mode == "phase2" then 3
			elseif mode == "lateInterrupt" then 1
			else 0
		check("portal " .. mode .. " count=" .. alive, alive == expected)
		API.Clear(b)
		check("portal cleanup", #summons(o) == 0)
		g:Destroy()
	end)
end
run("portal cap and lethal summons", function()
	local b, tr, hooks, hits, _, g, o = fixture()
	tr.Position = o + Vector3.new(0, 3, -30)
	API.Cast(b, 4, tr.Position, true, hooks)
	task.wait(3.8)
	API.Cast(b, 4, tr.Position, true, hooks)
	task.wait(3.8)
	local alive = {}
	for _, m in summons(o) do
		if m:FindFirstChildOfClass("Humanoid") and m.Humanoid.Health > 0 then
			table.insert(alive, m)
		end
	end
	check("four living summons maximum", #alive == 4)
	for _, m in alive do
		m.Humanoid:TakeDamage(10000)
	end
	local count = #hits
	task.wait(3)
	check("dead summons cannot hit", #hits == count)
	check("dead summons removed", #summons(o) == 0)
	API.Clear(b)
	g:Destroy()
end)
run("portal minion contacts and lifetime", function()
	local b, tr, hooks, hits, _, g, o = fixture()
	tr.Position = o + Vector3.new(0, 3, -30)
	API.Cast(b, 4, tr.Position, true, hooks)
	task.wait(3.6)
	for _, m in summons(o) do
		if m:FindFirstChildOfClass("Humanoid") then
			tr.Position = m.PrimaryPart.Position + Vector3.new(0, 0, -2)
			task.wait(2.1)
		end
	end
	local seen = {}
	for _, damage in hits do
		seen[damage] = true
	end
	check("stalker hound bat contact budgets", seen[10] and seen[9] and seen[7])
	task.wait(25)
	check("summons lifetime bounded", #summons(o) == 0)
	API.Clear(b)
	g:Destroy()
end)
run("melee contacts and restoration", function()
	local b, tr, hooks, hits, _, g, o = fixture()
	b.root.Anchored = false
	b.root:SetNetworkOwner(nil)
	API.Melee(b, tr.Position, hooks)
	task.wait(0.3)
	check("melee waits for contact", #hits == 0)
	task.wait(0.7)
	check("melee budget", total(hits) == 29)
	check(
		"melee movement restored",
		not b.root.Anchored
			and b.humanoid.WalkSpeed == cfg.walkSpeed
			and b.root:GetNetworkOwner() == nil
	)
	API.Clear(b)
	g:Destroy()
end)
run("spawn", function()
	local b, _, hooks, _, actions, g = fixture()
	API.Spawn(b, hooks)
	check("spawn vulnerable", b.model:GetAttribute("Shielded") == false)
	task.wait(2.6)
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
