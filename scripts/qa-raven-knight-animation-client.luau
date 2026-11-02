--!nocheck
-- PENDING Studio execution. Real client animators on disposable local rigs; no live characters or bosses modified.
assert(game:GetService("RunService"):IsStudio() and game:GetService("RunService"):IsClient())
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
	RS:BindToRenderStep("QARavenCamera", Enum.RenderPriority.Last.Value, function()
		camera.CFrame = CFrame.lookAt(eye + Vector3.new(12, 7, 20), eye)
	end)
	local model, prepared, motors = make("raven_knight", "Boss")
	for _, name in
		{
			"simplecombo",
			"simplecombo2",
			"fastcombo",
			"comboflyattack",
			"explosion",
			"ravencall",
			"spawn",
			"hurt",
			"jump",
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
		check(name .. " actual joints", p < 0.03 and a < 0.025)
	end
	model:Destroy()
	local mob, mr, mm = make("crow_reaper", "Mob")
	for _, name in { "basicattack", "chargeattack", "fogcombo", "summonaxe", "spikesattack" } do
		local clip = mr.clips[name]
		local t = clip.length * 0.55
		mob:SetAttribute("Action", name)
		mob:SetAttribute("ActionLen", 10000)
		mob:SetAttribute("ActionAt", workspace:GetServerTimeNow() - t / clip.length * 10000)
		task.wait(0.2)
		RS.PostSimulation:Wait()
		local at = (workspace:GetServerTimeNow() - mob:GetAttribute("ActionAt"))
			/ 10000
			* clip.length
		local p, a = compare(mr, name, at, mm)
		check("retainer " .. name, p < 0.03 and a < 0.025)
	end
	mob.Humanoid.Health = 0
	task.wait(mr.clips.death.length + 0.3)
	RS.PostSimulation:Wait()
	local p, a = compare(mr, "death", mr.clips.death.length, mm)
	check("retainer death overrides action", p < 0.03 and a < 0.025)
	mob:Destroy()
	for _, entry in { { "raven", "flight" }, { "crow_axe", "spin" } } do
		local prop, pr, pm = make(entry[1], "BossProp")
		prop:SetAttribute("Action", entry[2])
		prop:SetAttribute("ActionLen", 20)
		prop:SetAttribute("ActionAt", workspace:GetServerTimeNow())
		task.wait(0.35)
		RS.PostSimulation:Wait()
		local p, a =
			compare(pr, entry[2], workspace:GetServerTimeNow() - prop:GetAttribute("ActionAt"), pm)
		check(entry[1] .. " real-time loop", p < 0.05 and a < 0.18)
		prop:Destroy()
	end
	-- Existing ordinary Mob animations must continue to work after custom Action support.
	local ordinary, orr, om = make("forest_explorer", "Mob")
	ordinary:SetAttribute("MobWindup", workspace:GetServerTimeNow())
	task.wait(0.3)
	RS.PostSimulation:Wait()
	p, a =
		compare(orr, "bite", workspace:GetServerTimeNow() - ordinary:GetAttribute("MobWindup"), om)
	check("ordinary mob bite regression", p < 0.05 and a < 0.15)
	ordinary:Destroy()
end, debug.traceback)
RS:UnbindFromRenderStep("QARavenCamera")
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
