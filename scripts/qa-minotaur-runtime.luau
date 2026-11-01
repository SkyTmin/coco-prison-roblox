--!nocheck
-- Evening Play/Server QA, isolated fixtures. No profiles, rewards, or real bosses are modified.
local RunService = game:GetService("RunService")
assert(
	RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(),
	"Play/Server only"
)
local API = require(game.ServerScriptService.Server.Services.MinotaurAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local BlockRig = require(game.ReplicatedStorage.Shared.BlockRig)
local Definition = require(game.ReplicatedStorage.Shared.Models.minotaur)
local cfg
for _, card in Config.bosses.bosses do
	if card.id == "minotaur" then
		cfg = card.fight
	end
end
assert(cfg and cfg.minotaur)
assert(not workspace:FindFirstChild("QAMinotaurFixtures"), "Previous QA is still active")
local fixtures = Instance.new("Folder")
fixtures.Name, fixtures.Parent = "QAMinotaurFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QAMinotaurResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QAMinotaurResult", "running", game.ServerStorage
local origin = Vector3.new(47000, 30000, 0)
local function part(name, at, size, parent)
	local p = Instance.new("Part")
	p.Name, p.Position, p.Size, p.Anchored, p.Parent = name, at, size, true, parent
	return p
end
part("Floor", origin - Vector3.new(0, 1, 0), Vector3.new(200, 2, 200), fixtures)
local active, checks = {}, {}
local function fixture(index)
	local m = Instance.new("Model")
	m.Parent = fixtures
	local root = part("HumanoidRootPart", origin + Vector3.new(0, 4.5, 0), Vector3.new(4, 5, 3), m)
	local hum = Instance.new("Humanoid")
	hum.RequiresNeck, hum.BreakJointsOnDeath, hum.WalkSpeed = false, false, cfg.walkSpeed
	hum.Parent = m
	local j = part("J_root", origin, Vector3.one * 0.2, m)
	j.CanCollide, j.CanQuery = false, false
	j.Anchored, j.Massless = false, true
	local motor = Instance.new("Motor6D")
	motor.Name, motor.Part0, motor.Part1, motor.C0, motor.Parent =
		"root", root, j, CFrame.new(0, -4.5, 0), j
	local spawn = part("Spawn", origin - Vector3.new(0, 0.5, 0), Vector3.one, fixtures)
	spawn.CanCollide, spawn.CanQuery = false, false
	local target = Instance.new("Model")
	target.Parent = fixtures
	local distance = if index <= 2 then 5 else 18
	local tr = part(
		"HumanoidRootPart",
		origin + Vector3.new(0, 3, -distance),
		Vector3.new(2, 2, 2),
		target
	)
	local th = Instance.new("Humanoid")
	th.RequiresNeck = false
	th.Parent = target
	local f = { player = { Character = target }, root = tr, humanoid = th }
	local state = Instance.new("Folder")
	state.Parent = fixtures
	local boss = {
		model = m,
		root = root,
		humanoid = hum,
		spawn = spawn,
		fight = cfg,
		busyUntil = 0,
		stunnedUntil = 0,
		arenaRadius = 80,
		state = state,
	}
	table.insert(active, boss)
	local hits, actions = {}, {}
	local hooks = {
		act = function(_, name, duration)
			table.insert(actions, name)
			m:SetAttribute("Action", name)
			m:SetAttribute("ActionLen", duration)
			m:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		end,
		shield = function(_, duration)
			m:SetAttribute("Shielded", true)
			task.delay(duration, function()
				m:SetAttribute("Shielded", false)
			end)
		end,
		fighters = function()
			return { f }
		end,
		hurt = function(_, _, damage)
			table.insert(hits, damage)
		end,
		telegraph = function(size, cf)
			local mark = part("Mark", cf.Position, size, fixtures)
			mark.CFrame, mark.CanCollide, mark.CanQuery = cf, false, false
			return mark
		end,
	}
	return boss,
		tr,
		hooks,
		hits,
		actions,
		function()
			API.Clear(boss)
			m:Destroy()
			target:Destroy()
			state:Destroy()
			spawn:Destroy()
		end
end
local function check(name, ok)
	table.insert(checks, { name = name, pass = ok })
	assert(ok, name)
end
local ok, err = pcall(function()
	local prepared = BlockRig.prepare(Definition)
	local count = 0
	for _ in prepared.clips do
		count += 1
	end
	check("all 16 clips and run speed load", count == 16 and prepared.runSpeed == 9)
	for index, name in { "impact", "double_attack", "throws_the_ground", "minotaur_rush" } do
		local rules = cfg.minotaur[name]
		local modes = { "hit", "wall", "death", "dodge" }
		if index == 4 then
			table.insert(modes, "overlap")
			table.insert(modes, "dynamic_wall")
		end
		if index >= 3 then
			table.insert(modes, "death_in_flight")
		end
		for _, mode in modes do
			local boss, target, hooks, hits, actions, cleanup = fixture(index)
			local wall
			if mode == "wall" or mode == "overlap" then
				local z = if mode == "overlap" then -1 elseif index <= 2 then -2.5 else -10
				wall = part(
					"ChainPillar",
					origin + Vector3.new(0, 5, z),
					Vector3.new(20, 10, 1),
					fixtures
				)
			end
			API.Cast(boss, index, target.Position, false, hooks)
			if mode == "death" then
				task.wait(0.15)
				boss.humanoid.Health = 0
				API.Clear(boss)
			elseif mode == "death_in_flight" then
				task.wait(rules.release + 0.1)
				boss.humanoid.Health = 0
				API.Clear(boss)
			elseif mode == "dynamic_wall" then
				task.wait(rules.release + 0.12)
				wall = part("MovingWall", boss.root.Position, Vector3.new(20, 10, 1), fixtures)
			elseif mode == "dodge" then
				target.Position += Vector3.new(30, 0, 0)
			end
			local waitFor = if name == "double_attack"
				then rules.hits[2] + 0.2
				elseif name == "throws_the_ground" then rules.release + rules.flight + 0.2
				elseif name == "minotaur_rush" then rules.release
					+ rules.maxDistance / rules.speed
					+ 0.2
				else rules.release + 0.2
			task.wait(waitFor)
			local expected = if mode == "hit" then (if index == 2 then 2 else 1) else 0
			check(name .. " / " .. mode, #hits == expected)
			if index == 4 and (mode == "wall" or mode == "overlap" or mode == "dynamic_wall") then
				check(
					"wall starts actual stun clip",
					actions[#actions] == "stun" and boss.stunnedUntil > os.clock()
				)
				check("rush stops before wall", boss.root.Position.Z > origin.Z - 8.5)
			end
			if mode == "death" or mode == "death_in_flight" then
				local remaining = false
				for _, folder in workspace:GetChildren() do
					local at = folder:GetAttribute("Origin")
					if
						folder.Name == "MinotaurCast"
						and typeof(at) == "Vector3"
						and (at - origin).Magnitude < 100
					then
						remaining = true
					end
				end
				check(name .. " / effects cleared", not remaining)
			end
			if wall then
				wall:Destroy()
			end
			cleanup()
		end
	end
	for _, direction in { -1, 1 } do
		local boss, target, hooks, hits, _, cleanup = fixture(1)
		API.Melee(boss, target.Position, hooks)
		target.Position = origin + Vector3.new(0, 3, 5 * direction)
		task.wait(cfg.meleeDuration + 0.1)
		check("horns front/back " .. direction, #hits == (if direction == -1 then 1 else 0))
		check(
			"melee restores movement",
			boss.humanoid.WalkSpeed == cfg.walkSpeed and boss.humanoid.AutoRotate
		)
		cleanup()
	end
	do
		local boss, target, hooks, hits, _, cleanup = fixture(1)
		API.Melee(boss, target.Position, hooks)
		task.wait(0.12)
		API.Cast(boss, 1, target.Position, false, hooks)
		task.wait(cfg.minotaur.impact.duration + 0.1)
		check("new cast cancels old delayed horn hit", #hits == 1 and hits[1] == 4)
		cleanup()
	end
	do
		local boss, _, hooks, _, actions, cleanup = fixture(1)
		local chain =
			part("ChainLink", origin + Vector3.new(3, 4, 0), Vector3.new(0.3, 0.8, 1.2), fixtures)
		chain.CanCollide, chain.CanQuery = false, false
		local chainRest = chain.CFrame
		boss.root.Anchored = false
		API.Sleep(boss)
		check(
			"sleep freezes boss",
			boss.model:GetAttribute("Sleeping")
				and boss.root.Anchored
				and boss.humanoid.WalkSpeed == 0
		)
		API.Wake(boss, hooks)
		check(
			"wake uses full awakening clip",
			not boss.model:GetAttribute("Sleeping") and actions[#actions] == "awakening"
		)
		task.wait(cfg.minotaur.awakening + 0.15)
		check(
			"wake releases controls",
			boss.humanoid.WalkSpeed == cfg.walkSpeed
				and boss.humanoid.AutoRotate
				and not boss.root.Anchored
		)
		check("arena bindings release", chain.Transparency == 1)
		API.Bindings(boss, true)
		check("arena bindings restore", chain.Transparency == 0 and chain.CFrame == chainRest)
		cleanup()
		chain:Destroy()
	end
end)
for _, boss in active do
	API.Clear(boss)
end
fixtures:Destroy()
result.Value = game:GetService("HttpService")
	:JSONEncode({ ok = ok, checks = checks, error = if ok then nil else tostring(err) })
print("Minotaur QA:", result.Value)
