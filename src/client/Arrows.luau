--!strict
-- Arrows on screen (BowService owns the real ones): a flying arrow follows the server's physics tick by tick
-- (move, drag 0.99, gravity 0.05 blocks/tick² [ваниль]) from the start and velocity ArrowFired sends, and stops at
-- the first block in its way or when ArrowEnded says the server's arrow is done. Our own shot starts at once
-- (FireLocal) and takes the server's exact start and spread when its ArrowFired arrives. A critical arrow leaves a
-- trail of crit stars, a Flame arrow burns. Stuck arrows are server parts tagged StuckArrow; each gets the arrow
-- model with its head in the block.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local ItemModels = require(script.Parent.ItemModels)

local BOW = Config.vanilla.bow
local BLOCK = Config.rules.combat.blockStuds :: number
local TICK = 0.05
local SIZE = 2.4 -- studs: the 16-px arrow item, ≈ 0.6 blocks long on its diagonal
local LENGTH = SIZE * 11 / 16 * math.sqrt(2)
-- the arrow model's head points to the item's upper right, (0, 1, 1) in model space: turn it onto −Z (the look)
local TURN = CFrame.Angles(math.rad(-135), 0, 0)

type Flight = {
	id: number?,
	model: Model,
	origin: Vector3,
	velocity0: Vector3,
	position: Vector3,
	previous: Vector3,
	velocity: Vector3,
	ticks: number,
	acc: number,
	stopped: boolean,
	age: number,
}

local Arrows = {}
local started = false
local flights: { Flight } = {}
local pendingOwn: { Flight } = {} -- our shots the server has not numbered yet
local stuckVisuals: { [Instance]: Model } = {}
local folder: Folder
local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.RespectCanCollide = true

local function makeModel(crit: boolean, flame: boolean): Model?
	local model = ItemModels.get("arrow", nil, SIZE)
	if not model then
		return nil
	end
	local root = model.PrimaryPart :: BasePart
	root.Anchored = true
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CastShadow = false
		end
	end
	if flame then
		local fire = Instance.new("Fire")
		fire.Size = 2
		fire.Heat = 4
		fire.Parent = root
	end
	if crit then
		local stars = Instance.new("ParticleEmitter")
		stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		stars.Color =
			ColorSequence.new(Color3.fromRGB(255, 245, 210), Color3.fromRGB(190, 170, 120))
		stars.Size = NumberSequence.new(0.35, 0.05)
		stars.Lifetime = NumberRange.new(0.25, 0.45)
		stars.Speed = NumberRange.new(0.5, 1.5)
		stars.SpreadAngle = Vector2.new(180, 180)
		stars.Rate = 60
		stars.LightEmission = 0.8
		stars.Parent = root
	end
	model.Parent = folder
	return model
end

local function place(model: Model, position: Vector3, direction: Vector3)
	if direction.Magnitude < 1e-4 then
		return
	end
	model:PivotTo(CFrame.lookAt(position, position + direction) * TURN)
end

-- one tick of the server's physics
local function tick(flight: Flight)
	flight.previous = flight.position
	flight.position += flight.velocity
	flight.velocity = flight.velocity * BOW.drag - Vector3.new(0, BOW.gravity * BLOCK, 0)
	flight.ticks += 1
end

local function start(
	id: number?,
	origin: Vector3,
	velocity: Vector3,
	crit: boolean,
	flame: boolean
): Flight?
	local model = makeModel(crit, flame)
	if not model then
		return nil
	end
	local flight: Flight = {
		id = id,
		model = model,
		origin = origin,
		velocity0 = velocity,
		position = origin,
		previous = origin,
		velocity = velocity,
		ticks = 0,
		acc = 0,
		stopped = false,
		age = 0,
	}
	place(model, origin, velocity)
	table.insert(flights, flight)
	return flight
end

-- our own shot, drawn before the server answers
function Arrows.FireLocal(origin: Vector3, velocity: Vector3, crit: boolean, flame: boolean)
	local flight = start(nil, origin, velocity, crit, flame)
	if flight then
		table.insert(pendingOwn, flight)
	end
end

local function finish(flight: Flight)
	flight.model:Destroy()
	local index = table.find(flights, flight)
	if index then
		table.remove(flights, index)
	end
	local own = table.find(pendingOwn, flight)
	if own then
		table.remove(pendingOwn, own)
	end
end

local function exclusions(): { Instance }
	local list: { Instance } = { folder }
	local arrows = workspace:FindFirstChild("Arrows")
	if arrows then
		table.insert(list, arrows)
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	for _, tag in ipairs({ "Mob", "Boss" }) do
		for _, model in ipairs(CollectionService:GetTagged(tag)) do
			table.insert(list, model)
		end
	end
	return list
end

local function update(dt: number)
	if #flights == 0 then
		return
	end
	params.FilterDescendantsInstances = exclusions()
	for i = #flights, 1, -1 do
		local flight = flights[i]
		flight.age += dt
		if
			flight.age > BOW.maxFlightSeconds + 1
			or (flight.stopped and flight.age > flight.ticks * TICK + 1)
		then
			finish(flight)
			continue
		end
		if not flight.stopped then
			flight.acc += dt
			while flight.acc >= TICK and not flight.stopped do
				flight.acc -= TICK
				local from = flight.position
				local hit = workspace:Raycast(from, flight.velocity, params)
				if hit then
					-- held at the block until the server's stuck arrow takes over
					flight.previous, flight.position, flight.stopped =
						hit.Position, hit.Position, true
					place(
						flight.model,
						hit.Position - flight.velocity.Unit * (LENGTH / 2 - 0.3),
						flight.velocity
					)
				else
					tick(flight)
				end
			end
			if not flight.stopped then
				local alpha = math.clamp(flight.acc / TICK, 0, 1)
				place(flight.model, flight.previous:Lerp(flight.position, alpha), flight.velocity)
			end
		end
	end
end

local function stuckAdded(part: Instance)
	if not part:IsA("BasePart") or stuckVisuals[part] then
		return
	end
	local model = makeModel(false, false)
	if not model then
		return
	end
	-- the head goes 0.3 studs into the block, the shaft sticks out behind (+Z of the part's look frame)
	model:PivotTo(part.CFrame * CFrame.new(0, 0, LENGTH / 2 - 0.3) * TURN)
	stuckVisuals[part] = model
	-- an arrow of ours still in the air near this spot has landed
	for _, flight in ipairs(flights) do
		if (flight.position - part.Position).Magnitude < 3 then
			finish(flight)
			break
		end
	end
end

local function stuckRemoved(part: Instance)
	local model = stuckVisuals[part]
	if model then
		model:Destroy()
		stuckVisuals[part] = nil
	end
end

function Arrows.Start()
	if started then
		return
	end
	started = true
	folder = Instance.new("Folder")
	folder.Name = "ArrowVisuals"
	folder.Parent = workspace
	Remotes.unreliable("ArrowFired").OnClientEvent:Connect(
		function(
			id: number,
			userId: number,
			origin: Vector3,
			velocity: Vector3,
			crit: boolean,
			flame: boolean
		)
			if userId == Players.LocalPlayer.UserId and #pendingOwn > 0 then
				-- our predicted arrow: the server's start and spread, the same number of ticks in
				local flight = table.remove(pendingOwn, 1) :: Flight
				flight.id = id
				local ticks = flight.ticks
				flight.position, flight.previous, flight.velocity, flight.ticks =
					origin, origin, velocity, 0
				if not flight.stopped then
					for _ = 1, ticks do
						tick(flight)
					end
				end
				return
			end
			start(id, origin, velocity, crit == true, flame == true)
		end
	)
	Remotes.event("ArrowEnded").OnClientEvent:Connect(function(id: number)
		for _, flight in ipairs(flights) do
			if flight.id == id then
				finish(flight)
				return
			end
		end
	end)
	RunService.RenderStepped:Connect(update)
	for _, part in ipairs(CollectionService:GetTagged("StuckArrow")) do
		stuckAdded(part)
	end
	CollectionService:GetInstanceAddedSignal("StuckArrow"):Connect(stuckAdded)
	CollectionService:GetInstanceRemovedSignal("StuckArrow"):Connect(stuckRemoved)
end

return Arrows
