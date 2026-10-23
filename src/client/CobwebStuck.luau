--!strict
-- Stuck in a cobweb as in Minecraft [ваниль]: inside a web (Shared/Cobweb) the character walks at ≈ 0.11 of its
-- speed on the floor and ≈ 0.02 while hanging in the web (Cobweb.WALK / AIR: the web zeroes momentum every
-- tick), cannot jump out and sinks at 0.05 of the fall — ≈ 0.08 blocks/s, the pace of an entity resting in a web
-- (each tick its motion restarts from gravity alone: 0.08 · 0.98 · 0.05 blocks a tick). The server's fall damage
-- reads the same index (the fall is cancelled in a web). Movement is the client's, so it lives here.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Cobweb = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Cobweb)

local player = Players.LocalPlayer
local BLOCK = 4
local SINK = 0.08 * 0.98 * Cobweb.VERTICAL * 20 * BLOCK -- studs/s [ваниль]

local CobwebStuck = {}

local held: Humanoid? = nil -- the humanoid we slowed
local base = 16 -- its WalkSpeed before the web (the server may change it meanwhile: Needs slowness)
local ours = 0 -- the WalkSpeed we set

local function release()
	local humanoid = held
	if not humanoid then
		return
	end
	held = nil
	if humanoid.Parent then
		if math.abs(humanoid.WalkSpeed - ours) < 1e-3 then
			humanoid.WalkSpeed = base
		end
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end

local function step(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root or humanoid.Health <= 0 or not Cobweb.holds(character) then
		release()
		return
	end
	if held ~= humanoid then
		release()
		held = humanoid
		base = humanoid.WalkSpeed
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	elseif math.abs(humanoid.WalkSpeed - ours) > 1e-3 then
		base = humanoid.WalkSpeed -- the server changed it while we were in the web
	end
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	ours = base * (if grounded then Cobweb.WALK else Cobweb.AIR)
	humanoid.WalkSpeed = ours
	-- gravity acts over the whole step after this: start the step most of a step's gravity faster, so the
	-- average over the step is the sink speed
	local v = root.AssemblyLinearVelocity
	local lift = workspace.Gravity * dt * 0.8
	local y = v.Y
	if v.Y < -SINK then
		y = -SINK + lift
	elseif v.Y > SINK then
		y = SINK
	end
	-- the web eats any momentum brought in (a run, a fall, a knockback): never faster than the web pace
	local flat = Vector3.new(v.X, 0, v.Z)
	local speed = flat.Magnitude
	if speed > ours + 1e-3 then
		flat *= ours / speed
	end
	if y ~= v.Y or speed > ours + 1e-3 then
		root.AssemblyLinearVelocity = Vector3.new(flat.X, y, flat.Z)
	end
end

function CobwebStuck.Start()
	Cobweb.start()
	RunService.PreSimulation:Connect(step)
end

return CobwebStuck
