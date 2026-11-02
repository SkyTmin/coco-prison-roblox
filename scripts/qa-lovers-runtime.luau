--!nocheck
-- PENDING Studio run. Disposable fixtures: no profiles, live boss kills or rewards touched.
assert(
	game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsServer(),
	"Studio Server only"
)
local API = require(game.ServerScriptService.Server.Services.LoversAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cfg
for _, c in Config.bosses.bosses do
	if c.id == "the_lovers" then
		cfg = c.fight
		assert(c.hp == 2970, "Samurai HP changed")
	end
end
assert(cfg and cfg.lovers, "Samurai config missing")
assert(not workspace:FindFirstChild("QALoversFixtures"), "Previous QA fixtures still exist")
local folder = Instance.new("Folder")
folder.Name, folder.Parent = "QALoversFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QALoversResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QALoversResult", "running", game.ServerStorage
local checks, errors, active = {}, {}, {}
local remaining, number = 0, 0
local function part(name, at, size, parent)
	local p = Instance.new("Part")
	p.Name, p.Position, p.Size, p.Anchored, p.Parent = name, at, size, true, parent
	return p
end
local function fixture()
	number += 1
	local o = Vector3.new(235000 + number * 500, 30000, 0)
	local g = Instance.new("Folder")
	g.Parent = folder
	part("Floor", o - Vector3.new(0, 1, 0), Vector3.new(150, 2, 150), g)
	local m = Instance.new("Model")
	m.Parent = g
	local r = part("HumanoidRootPart", o + Vector3.new(0, 4.5, 0), Vector3.new(4, 5, 3), m)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.MaxHealth, h.Health, h.WalkSpeed, h.HipHeight = 2970, 2970, cfg.walkSpeed, 2
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
		if e.Name == "LoversEncounter" then
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

local names = { "triplecut", "sweep", "thrust", "dashcut", "skycut", "stars", "sickle", "spears" }
for index, name in names do
	for _, mode in
		{ "hit", "wall", "dynamicWall", "dodge", "death", "clear", "replacement", "arena", "range" }
	do
		run(name .. " " .. mode, function()
			local b, tr, hooks, hits, actions, g, o = fixture()
			local c = cfg.lovers[name]
			if index > 6 then
				b.model:SetAttribute("LoversPhase", 2)
				-- Cover only the spawn side: isolate the weapon, not the archer's independent damage.
				part("SpiritSpawnCover", o + Vector3.new(-7, 4, 0), Vector3.new(4, 8, 4), g)
			end
			if mode == "range" then
				tr.Position = o + Vector3.new(0, 3, -65)
			end
			if mode == "arena" then
				b.arenaRadius = 1
			end
			if mode == "wall" then
				part("Wall", o + Vector3.new(0, 5, -3), Vector3.new(40, 10, 1), g)
			end
			API.Cast(b, index, tr.Position, index > 6, hooks)
			check(name .. " action", actions[1] == name)
			check(name .. " no shield", b.model:GetAttribute("Shielded") == false)
			task.wait(0.25)
			check(name .. " windup", #hits == 0)
			if mode == "dynamicWall" then
				part("Wall", o + Vector3.new(0, 5, -3), Vector3.new(40, 10, 1), g)
			end
			if mode == "dodge" then
				tr.Position = o + Vector3.new(45, 3, 0)
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
			task.wait(c.duration + 2)
			if mode == "hit" then
				check(name .. " damage budget", math.abs(total(hits) - c.damage) < 0.001)
				if name == "triplecut" then
					check("three visible contacts", #hits == 3)
					for i = 2, #b.qaHitTimes do
						check(
							"contacts exceed hurt immunity",
							b.qaHitTimes[i] - b.qaHitTimes[i - 1] > 0.5
						)
					end
				end
			elseif mode == "arena" then
				-- Stationary sword arcs are bounded by the real fighters selector; fixture calls bypass it.
				if index >= 3 then
					check(name .. " arena travel/shot cancelled", #hits == 0)
				end
			else
				check(name .. " " .. mode .. " no damage", #hits == 0)
			end
			API.Clear(b)
			g:Destroy()
		end)
	end
end
for _, name in { "sweep", "thrust", "dashcut", "skycut" } do
	run(name .. " lost support", function()
		local b, tr, hooks, hits, _, g = fixture()
		API.Cast(b, table.find(names, name), tr.Position, false, hooks)
		task.wait(0.3)
		g.Floor:Destroy()
		task.wait(cfg.lovers[name].duration + 0.3)
		check(name .. " support cancels", #hits == 0)
		API.Clear(b)
		g:Destroy()
	end)
end
run("melee alternates and restores physics", function()
	local b, tr, hooks, hits, actions, g = fixture()
	b.root.Anchored = false
	b.root:SetNetworkOwner(nil)
	for i, name in { "drawcut", "reversecut" } do
		API.Melee(b, tr.Position, hooks)
		task.wait(cfg.lovers[name].duration + 0.25)
		check(name .. " contact", actions[i] == name and #hits == i and hits[i] == 32)
		check(
			name .. " restored",
			not b.root.Anchored
				and b.root:GetNetworkOwner() == nil
				and b.humanoid.WalkSpeed == cfg.walkSpeed
		)
	end
	API.Clear(b)
	g:Destroy()
end)
run("phases, mortal spirit, nock, lifecycle", function()
	local b, tr, hooks, hits, actions, g, o = fixture()
	API.Spawn(b, hooks)
	task.wait(cfg.lovers.spawnDuration + 0.25)
	check(
		"one vulnerable phase-one boss",
		b.model:GetAttribute("LoversPhase") == 1 and not b.model:GetAttribute("Shielded")
	)
	b.humanoid.Health = 1485
	API.Melee(b, tr.Position, hooks)
	check(
		"half HP transition",
		actions[#actions] == "phase2" and not b.model:GetAttribute("Shielded")
	)
	task.wait(cfg.lovers.phase2Duration + 0.5)
	local adds = summons(o, "lover_spirit")
	check("one spirit", #adds == 1)
	local ghost = adds[1]
	check(
		"mortal ordinary mob",
		ghost.Humanoid.MaxHealth == 110
			and not game.CollectionService:HasTag(ghost, "Boss")
			and game.CollectionService:HasTag(ghost, "Mob")
	)
	local arrowBoxes = 0
	for _, p in ghost:GetChildren() do
		local weld = p:FindFirstChildOfClass("WeldConstraint")
		if weld and weld.Part0 and weld.Part0.Name == "J_arrow" then
			arrowBoxes += 1
		end
	end
	check(
		"full rig immutable, nock external",
		ghost:FindFirstChild("J_arrow") ~= nil
			and arrowBoxes == 0
			and #summons(o, "LoverNockedArrow") == 1
	)
	task.wait(cfg.lovers.spirit.spawnDuration + 0.5)
	check(
		"spirit server owned",
		not ghost.PrimaryPart.Anchored and ghost.PrimaryPart:GetNetworkOwner() == nil
	)
	b.humanoid.Health = 700
	API.Melee(b, tr.Position, hooks)
	check(
		"quarter HP transition",
		actions[#actions] == "phase3" and b.model:GetAttribute("LoversPhase") == 3
	)
	task.wait(cfg.lovers.phase3Duration + 0.3)
	check("never duplicates living spirit", #summons(o, "lover_spirit") == 1)
	b.humanoid.Health = 2600
	API.Melee(b, tr.Position, hooks)
	check("healing does not reverse phase", b.model:GetAttribute("LoversPhase") == 3)
	task.wait(2)
	tr.Position = o + Vector3.new(0, 3, -16)
	table.clear(hits)
	API.Cast(b, 9, tr.Position, true, hooks)
	check("paired rain action", actions[#actions] == "arrowcall")
	task.wait(5)
	local received = false
	for _, n in hits do
		if n == 43 then
			received = true
		end
	end
	check("paired rain has shared budget", received)
	b.humanoid.Health = 0
	API.Clear(b)
	check(
		"spirit death starts with boss",
		ghost.Humanoid.Health == 0 and ghost.PrimaryPart.Anchored
	)
	task.wait(cfg.lovers.spirit.deathDuration + 0.5)
	check("death clears all props and spirit", #summons(o) == 0)
	g:Destroy()
end)
run("spirit killed, re-summon delay, clean leash", function()
	local b, tr, hooks, _, _, g, o = fixture()
	b.model:SetAttribute("LoversPhase", 2)
	API.Melee(b, tr.Position, hooks)
	task.wait(0.2)
	local ghost = summons(o, "lover_spirit")[1]
	check("spirit created", ghost ~= nil)
	ghost.Humanoid.Health = 0
	task.wait(4.3)
	API.Melee(b, tr.Position, hooks)
	check("no immediate re-summon", #summons(o, "lover_spirit") == 0)
	task.wait(21.5)
	API.Melee(b, tr.Position, hooks)
	task.wait(0.2)
	check("finite re-summon delay", #summons(o, "lover_spirit") == 1)
	API.Clear(b)
	check("leash immediately clears props", #summons(o) == 0)
	g:Destroy()
end)
run("lifetime cancels an in-flight spirit cast", function()
	local b, tr, hooks, _, _, g, o = fixture()
	b.fight = table.clone(cfg)
	b.fight.lovers = table.clone(cfg.lovers)
	b.fight.lovers.spirit = table.clone(cfg.lovers.spirit)
	b.fight.lovers.spirit.lifetime = 1
	b.model:SetAttribute("LoversPhase", 2)
	API.Melee(b, tr.Position, hooks)
	local ghost = summons(o, "lover_spirit")[1]
	check("lifetime fixture spirit", ghost ~= nil)
	task.wait(cfg.lovers.spirit.spawnDuration + 0.8)
	check("spirit initially alive", ghost.Humanoid.Health > 0)
	task.wait(0.4)
	check("lifetime interrupts windup", ghost.Humanoid.Health == 0 and ghost.PrimaryPart.Anchored)
	task.wait(cfg.lovers.spirit.deathDuration + 0.3)
	check("lifetime cleans nock and spirit", #summons(o) == 0)
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
