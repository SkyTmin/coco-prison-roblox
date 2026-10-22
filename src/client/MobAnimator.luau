--!strict
-- Plays the Blender clips of BlockRig mobs (tag "Mob", attribute MobId with a Shared.Models.<id> definition):
-- death > bite (MobWindup: the server's rear-up before the bite) > hurt (health dropped) > walk (speed-scaled)
-- > idle, crossfading 0.12 s. Writes Motor6D.Transform before physics each frame; far mobs are skipped.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local BlockRig = require(Shared.BlockRig)
local Models = Shared:WaitForChild("Models")

local MobAnimator = {}
local started = false

local FADE = 0.12
local FAR = 140 -- studs from the camera: beyond, the rat keeps its last pose
local WALK_SPEED = 10 -- studs/s at which the walk clip plays at its own pace
local HURT = 0.27

type Entry = {
	model: Model,
	root: BasePart,
	humanoid: Humanoid,
	rig: BlockRig.Prepared,
	motors: { [string]: Motor6D },
	clip: string,
	clipAt: number, -- clip time
	from: { [string]: CFrame }, -- the pose when the clip changed, faded out over FADE
	fadeAt: number,
	last: { [string]: CFrame },
	hurtAt: number,
	diedAt: number?,
	health: number,
}
local entries: { [Model]: Entry } = {}

local function track(model: Instance)
	if not model:IsA("Model") or entries[model] then
		return
	end
	local id = model:GetAttribute("MobId")
	local defModule = typeof(id) == "string" and Models:FindFirstChild(id)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not defModule or not defModule:IsA("ModuleScript") or not root or not humanoid then
		return
	end
	local rig = BlockRig.prepare(require(defModule) :: any)
	local motors: { [string]: Motor6D } = {}
	for _, m in ipairs(model:GetDescendants()) do
		if m:IsA("Motor6D") then
			motors[m.Name] = m
		end
	end
	entries[model] = {
		model = model,
		root = root,
		humanoid = humanoid,
		rig = rig,
		motors = motors,
		clip = "idle",
		clipAt = math.random() * 2,
		from = {},
		fadeAt = -1,
		last = {},
		hurtAt = -1,
		diedAt = nil,
		health = humanoid.Health,
	}
end

local function choose(e: Entry, now: number, serverNow: number): (string, number?)
	local h = e.humanoid
	if h.Health <= 0 then
		e.diedAt = e.diedAt or now
		return "death", now - (e.diedAt :: number)
	end
	local windup = e.model:GetAttribute("MobWindup")
	local bite = e.rig.clips.bite
	if typeof(windup) == "number" and bite and serverNow - windup < bite.length then
		return "bite", serverNow - windup
	end
	if h.Health < e.health - 0.01 then
		e.hurtAt = now
	end
	e.health = h.Health
	if now - e.hurtAt < HURT and e.rig.clips.hurt then
		return "hurt", now - e.hurtAt
	end
	local v = e.root.AssemblyLinearVelocity
	if Vector3.new(v.X, 0, v.Z).Magnitude > 1 then
		return "walk", nil
	end
	return "idle", nil
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for model, e in pairs(entries) do
		if not model.Parent then
			entries[model] = nil
			continue
		end
		if (e.root.Position - eye).Magnitude > FAR then
			continue
		end
		local name, at = choose(e, now, serverNow)
		if name ~= e.clip then
			e.from = table.clone(e.last)
			e.fadeAt = now
			e.clip = name
			e.clipAt = 0
		end
		if at then
			e.clipAt = at
		elseif name == "walk" then
			local v = e.root.AssemblyLinearVelocity
			e.clipAt += dt * math.clamp(Vector3.new(v.X, 0, v.Z).Magnitude / WALK_SPEED, 0.5, 2)
		else
			e.clipAt += dt
		end
		local clip = e.rig.clips[name]
		local w = if e.fadeAt >= 0 then math.clamp((now - e.fadeAt) / FADE, 0, 1) else 1
		for _, joint in ipairs(e.rig.joints) do
			local motor = e.motors[joint]
			if motor then
				local cf = if clip then BlockRig.sample(clip, joint, e.clipAt) else CFrame.identity
				if w < 1 then
					cf = (e.from[joint] or CFrame.identity):Lerp(cf, w)
				end
				motor.Transform = cf
				e.last[joint] = cf
			end
		end
	end
end

function MobAnimator.Start()
	if started then
		return
	end
	started = true
	for _, m in ipairs(CollectionService:GetTagged("Mob")) do
		track(m)
	end
	CollectionService:GetInstanceAddedSignal("Mob"):Connect(function(m)
		-- streamed models arrive whole (Atomic), but the tag can land before the children are parented
		task.defer(track, m)
	end)
	RunService.PreSimulation:Connect(step)
end

return MobAnimator
