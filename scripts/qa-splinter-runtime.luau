--!nocheck
-- Execute this file's contents with execute_luau in Play/Server, wrapped in task.spawn.
-- Server loadstring is disabled: studio-loader is for Edit, not this runtime QA.
-- Isolated fixtures: no player/profile/reward changes.
assert(game:GetService("RunService"):IsStudio(), "Studio only")
assert(
	game:GetService("RunService"):IsRunning() and game:GetService("RunService"):IsServer(),
	"Play/Server only"
)
local SS = game:GetService("ServerStorage")
local API = require(game.ServerScriptService.Server.Services.SplinterAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local result = SS:FindFirstChild("QASplinterResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QASplinterResult", "running", SS
local cfg
for _, card in Config.bosses.bosses do
	if card.id == "splinter" then
		cfg = card.fight
	end
end
assert(cfg)
local origin = Vector3.new(40000, 30000, 0)
local fixtures = Instance.new("Folder")
fixtures.Name, fixtures.Parent = "QASplinterFixtures", workspace
local active, checks = {}, {}
local function part(name, position, size, parent)
	local p = Instance.new("Part")
	p.Name, p.Position, p.Size, p.Anchored = name, position, size, true
	p.Parent = parent
	return p
end
part("Floor", origin - Vector3.new(0, 1, 0), Vector3.new(200, 2, 200), fixtures)
local function fixture()
	local model = Instance.new("Model")
	model.Parent = fixtures
	local root =
		part("HumanoidRootPart", origin + Vector3.new(0, 3, 0), Vector3.new(2, 2, 2), model)
	model.PrimaryPart = root
	local hum = Instance.new("Humanoid")
	hum.RequiresNeck, hum.BreakJointsOnDeath = false, false
	hum.Parent = model
	local target = Instance.new("Model")
	target.Parent = fixtures
	local targetRoot =
		part("HumanoidRootPart", origin + Vector3.new(0, 3, -18), Vector3.new(2, 2, 2), target)
	local targetHum = Instance.new("Humanoid")
	targetHum.RequiresNeck, targetHum.Parent = false, target
	local fighter = { player = { Character = target }, root = targetRoot, humanoid = targetHum }
	local boss = {
		model = model,
		root = root,
		humanoid = hum,
		fight = cfg,
		spawn = root,
		arenaRadius = 80,
		busyUntil = 0,
	}
	table.insert(active, boss)
	local hits = {}
	local hooks = {
		act = function() end,
		fighters = function()
			return { fighter }
		end,
		hurt = function(_, _, damage)
			table.insert(hits, damage)
		end,
		telegraph = function(size, cf)
			local p = part("Mark", cf.Position, size, fixtures)
			p.CanCollide, p.CanQuery, p.CFrame = false, false, cf
			return p
		end,
	}
	local function cleanup()
		API.Clear(boss)
		model:Destroy()
		target:Destroy()
	end
	return boss, targetRoot, hooks, hits, cleanup
end
local function check(name, condition, detail)
	table.insert(checks, { name = name, pass = condition, detail = detail })
	assert(condition, name .. ": " .. tostring(detail))
end
local ok, err = pcall(function()
	for index, name in { "swoop", "potion", "shoot", "summon" } do
		local boss, target, hooks, hits, cleanup = fixture()
		API.Cast(boss, index, target.Position, false, hooks)
		task.wait(0.15)
		boss.humanoid.Health = 0
		API.Clear(boss)
		task.wait(cfg.splinter[name].duration + 0.25)
		check("death cancels " .. name, #hits == 0, #hits)
		cleanup()
	end
	for index, name in { "swoop", "potion", "shoot" } do
		for _, blocked in { false, true } do
			local boss, target, hooks, hits, cleanup = fixture()
			local wall
			if blocked then
				wall =
					part("Wall", origin + Vector3.new(0, 12, -9), Vector3.new(40, 26, 2), fixtures)
			end
			API.Cast(boss, index, target.Position, false, hooks)
			task.wait(if name == "potion" then 4.8 else 3.7)
			local total = 0
			for _, damage in hits do
				total += damage
			end
			check(
				name .. (if blocked then " wall" else " hit"),
				if blocked then total == 0 else total == cfg.splinter[name].damage,
				total
			)
			if name == "swoop" then
				check("swoop anchor restored", boss.root.Anchored == true, boss.root.Anchored)
				if blocked then
					check(
						"swoop stops before wall",
						boss.root.Position.Z > -8,
						boss.root.Position.Z
					)
				end
			end
			if wall then
				wall:Destroy()
			end
			cleanup()
		end
	end
	local boss, target, hooks, hits, cleanup = fixture()
	local function spiders()
		local list = {}
		for _, m in game:GetService("CollectionService"):GetTagged("Mob") do
			if
				m:GetAttribute("MobId") == "splinter_spider"
				and (m.PrimaryPart.Position - origin).Magnitude < 100
			then
				table.insert(list, m)
			end
		end
		return list
	end
	API.Cast(boss, 4, target.Position, true, hooks)
	task.wait(4.2)
	check("phase2 summons four", #spiders() == 4, #spiders())
	API.Cast(boss, 4, target.Position, true, hooks)
	task.wait(4.2)
	check("spider cap six", #spiders() == 6, #spiders())
	spiders()[1]:FindFirstChildOfClass("Humanoid"):TakeDamage(cfg.splinter.summon.hp)
	task.wait(0.5)
	check("spider can die", #spiders() == 5, #spiders())
	task.wait(cfg.splinter.summon.lifetime + 0.5)
	check("spiders expire", #spiders() == 0, #spiders())
	cleanup()
end)
for _, boss in active do
	API.Clear(boss)
end
fixtures:Destroy()
result.Value = game:GetService("HttpService")
	:JSONEncode({ ok = ok, error = if ok then nil else tostring(err), checks = checks })
return result.Value
