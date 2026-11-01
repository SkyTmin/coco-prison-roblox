--!nocheck
-- Evening Play/Server check. Isolated fixtures; never changes player profiles or rewards.
local RunService = game:GetService("RunService")
assert(
	RunService:IsStudio() and RunService:IsRunning() and RunService:IsServer(),
	"Play/Server only"
)
local API = require(game.ServerScriptService.Server.Services.BasaltAbilities)
local Config = require(game.ReplicatedStorage.Shared.Config)
local cfg
for _, card in Config.bosses.bosses do
	if card.id == "basalt_guardian" then
		cfg = card.fight
	end
end
assert(cfg and cfg.basalt)
assert(not workspace:FindFirstChild("QABasaltFixtures"), "Previous QA is still active")
local fixtures = Instance.new("Folder")
fixtures.Name, fixtures.Parent = "QABasaltFixtures", workspace
local result = game.ServerStorage:FindFirstChild("QABasaltResult") or Instance.new("StringValue")
result.Name, result.Value, result.Parent = "QABasaltResult", "running", game.ServerStorage
local origin = Vector3.new(45000, 30000, 0)
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
	local root = part("HumanoidRootPart", origin + Vector3.new(0, 3, 0), Vector3.new(2, 2, 2), m)
	local hum = Instance.new("Humanoid")
	hum.RequiresNeck = false
	hum.BreakJointsOnDeath = false
	hum.Parent = m
	local target = Instance.new("Model")
	target.Parent = fixtures
	local at = origin + Vector3.new(0, 3, if index == 2 then -4 else -16)
	local tr = part("HumanoidRootPart", at, Vector3.new(2, 2, 2), target)
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
		spawn = root,
		fight = cfg,
		busyUntil = 0,
		state = state,
	}
	table.insert(active, boss)
	local hits = {}
	local hooks = {
		act = function() end,
		shield = function() end,
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
		function()
			API.Clear(boss)
			m:Destroy()
			target:Destroy()
			state:Destroy()
		end
end
local function check(name, ok)
	table.insert(checks, { name = name, pass = ok })
	assert(ok, name)
end
local ok, err = pcall(function()
	for index, name in { "sword_slash", "sword_smash", "sword_spike" } do
		local rules = cfg.basalt[name]
		for _, mode in { "hit", "wall", "death", "dodge" } do
			local boss, target, hooks, hits, cleanup = fixture(index)
			local wall
			if mode == "wall" then
				wall = part(
					"Wall",
					origin + Vector3.new(0, 9, if index == 2 then -2 else -8),
					Vector3.new(40, 20, 0.5),
					fixtures
				)
			end
			local speed = boss.humanoid.WalkSpeed
			API.Cast(boss, index, target.Position, true, hooks)
			task.wait(0.1)
			if mode == "death" then
				boss.humanoid.Health = 0
				API.Clear(boss)
			elseif mode == "dodge" then
				target.Position += Vector3.new(50, 0, 0)
			end
			task.wait(rules.duration + 0.2)
			check(
				name .. " " .. mode,
				if mode == "hit" then #hits == 1 and hits[1] == rules.damage else #hits == 0
			)
			if mode ~= "death" then
				check(
					name .. " controls " .. mode,
					boss.humanoid.WalkSpeed == speed and boss.humanoid.AutoRotate
				)
			end
			if wall then
				wall:Destroy()
			end
			cleanup()
		end
	end
end)
for _, boss in active do
	API.Clear(boss)
end
fixtures:Destroy()
result.Value =
	game:GetService("HttpService")
		:JSONEncode({ passed = ok, checks = checks, error = if ok then nil else tostring(err) })
return result.Value
