--!nocheck
-- PENDING Studio execution. Real client animators on disposable local rigs; no live characters or bosses modified.
assert(
	game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient(),
	"Studio Client only"
)
local RS = game:GetService("RunService")
local CS = game:GetService("CollectionService")
local Shared = game.ReplicatedStorage.Shared
local BlockRig = require(Shared.BlockRig)
local camera = workspace.CurrentCamera
local cf, kind = camera.CFrame, camera.CameraType
local models, checks = {}, {}
local maxPosition, maxAngle = 0, 0
local eye = Vector3.new(0, 100, 0)
local function check(name, ok)
	assert(ok, name)
	table.insert(checks, name)
end
local function compare(rig, clip, t, motors)
	local position, angle = 0, 0
	for joint in rig.clips[clip].tracks do
		local diff = BlockRig.sample(rig.clips[clip], joint, t)
			:ToObjectSpace(motors[joint].Transform)
		local _, r = diff:ToAxisAngle()
		position = math.max(position, diff.Position.Magnitude)
		angle = math.max(angle, math.abs(r))
	end
	maxPosition, maxAngle = math.max(maxPosition, position), math.max(maxAngle, angle)
	return position, angle
end
local function make(id, tag)
	local m = Instance.new("Model")
	m.Name = "QAAnimation_" .. id
	local r = Instance.new("Part")
	r.Name, r.Size, r.Anchored, r.Transparency = "HumanoidRootPart", Vector3.one, true, 1
	r.CFrame, r.Parent = CFrame.new(0, 100, 0), m
	m.PrimaryPart = r
	local def = require(Shared.Models[id])
	BlockRig.build(def, m, r, r.CFrame)
	local h = Instance.new("Humanoid")
	h.RequiresNeck, h.BreakJointsOnDeath = false, false
	h.Parent = m
	m:SetAttribute("BlockModel", id)
	m:SetAttribute("MobId", id)
	m.Parent = workspace
	CS:AddTag(m, tag)
	table.insert(models, m)
	eye = r.Position
	local motors = {}
	for _, j in m:GetDescendants() do
		if j:IsA("Motor6D") then
			motors[j.Name] = j
		end
	end
	task.wait(0.2)
	return m, BlockRig.prepare(def), motors
end

local ok, err = xpcall(function()
	camera.CameraType = Enum.CameraType.Scriptable
	RS:BindToRenderStep("QAEntCamera", Enum.RenderPriority.Last.Value, function()
		camera.CFrame = CFrame.lookAt(eye + Vector3.new(15, 8, 24), eye)
	end)
	local model, prepared, motors = make("ent", "Boss")
	for _, name in
		{
			"rightpunch",
			"leftpunch",
			"rise",
			"stomp",
			"shout",
			"leafstorm",
			"spawn",
			"hurt",
			"stun",
			"death",
		}
	do
		local clip = prepared.clips[name]
		local t = if name == "death" then clip.length else clip.length * 0.55
		model:SetAttribute("Action", name)
		model:SetAttribute("ActionLen", 10000)
		model:SetAttribute("ActionAt", workspace:GetServerTimeNow() - t / clip.length * 10000)
		task.wait(0.2)
		RS.PostSimulation:Wait()
		local at = math.min(
			clip.length,
			(workspace:GetServerTimeNow() - model:GetAttribute("ActionAt")) / 10000 * clip.length
		)
		local p, a = compare(prepared, name, at, motors)
		check("Ent " .. name, p < 0.03 and a < 0.025)
	end
	model:Destroy()
	local m, rig, minionMotors = make("ent_minion", "Mob")
	m:SetAttribute("MobSpawnAt", workspace:GetServerTimeNow())
	task.wait(0.25)
	RS.PostSimulation:Wait()
	local p, a = compare(
		rig,
		"spawn",
		workspace:GetServerTimeNow() - m:GetAttribute("MobSpawnAt"),
		minionMotors
	)
	check("minion spawn", p < 0.06 and a < 0.18)
	task.wait(rig.clips.spawn.length)
	m:SetAttribute("MobWindup", workspace:GetServerTimeNow())
	task.wait(0.3)
	RS.PostSimulation:Wait()
	p, a = compare(
		rig,
		"bite",
		workspace:GetServerTimeNow() - m:GetAttribute("MobWindup"),
		minionMotors
	)
	check("minion contact", p < 0.06 and a < 0.18)
	m.Humanoid.Health = 0
	task.wait(rig.clips.death.length + 0.3)
	RS.PostSimulation:Wait()
	p, a = compare(rig, "death", rig.clips.death.length, minionMotors)
	check("minion final death", p < 0.03 and a < 0.025)
	m:Destroy()
	for _, id in { "ent_branch", "ent_leaves" } do
		local prop, propRig, propMotors = make(id, "BossProp")
		local name = if id == "ent_branch" then "spawn" else "idle"
		prop:SetAttribute("Action", name)
		prop:SetAttribute("ActionLen", 10)
		prop:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		task.wait(0.3)
		RS.PostSimulation:Wait()
		local elapsed = workspace:GetServerTimeNow() - prop:GetAttribute("ActionAt")
		p, a = compare(
			propRig,
			name,
			if propRig.clips[name].loop then elapsed else elapsed / 10 * propRig.clips[name].length,
			propMotors
		)
		check(id .. " clip", p < 0.05 and a < 0.18)
		prop:Destroy()
	end
end, debug.traceback)
RS:UnbindFromRenderStep("QAEntCamera")
camera.CameraType, camera.CFrame = kind, cf
for _, m in models do
	m:Destroy()
end
return game.HttpService:JSONEncode({
	status = if ok then "PASS" else "FAIL",
	checks = #checks,
	error = if ok then nil else err,
	maxPosition = maxPosition,
	maxAngleDegrees = math.deg(maxAngle),
})
