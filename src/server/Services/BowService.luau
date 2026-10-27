--!strict
-- The bow as in Minecraft (Java = Bedrock) [ваниль, владелец 26.10: «стрельбу и всё остальное как в майнкрафт
-- бедрок на телефоне»]. Numbers: tools.json vanilla.bow (scripts/build-configs.mjs).
--   BowDraw: the bow in hand and an arrow in the inventory (Creative needs none) → the draw starts on the server's
--     clock; the character attribute BowDrawAt (server time) lets every client show the pull stages and the pose.
--   BowRelease(direction): power f = t / 1 s, f = (f² + 2f) / 3, at most 1; below 0.1 nothing is shot and nothing
--     spent. Otherwise one arrow is spent (not in Creative) and flies from the eyes: 3 blocks a tick × f, a little
--     vanilla spread, drag 0.99 and gravity 0.05 blocks a tick², simulated here tick by tick (20 a second).
--   A hit: damage = ceil(speed in blocks/tick × (2 + Power 0.5·lvl + 0.5)); a full draw is critical and adds a random
--     0 .. damage/2 + 1; Flame sets the target on fire for 5 s (1 a second). PvP, factions, the casting boss and the
--     mob rewards go through CombatService.HitModel like a sword blow.
--   A miss sticks in the block it hit (a part tagged StuckArrow, drawn by the clients): picked up by walking over it,
--     gone after 60 s or when its block goes; arrows shot in Creative are never picked up.
--   An arrow that hits a player or a mob is spent [владелец 27.10: «когда попадаешь в игрока, стрелы теряются»]; as
--     in vanilla it shows stuck in the body (model attribute ArrowsInBody) and one falls out every 30 − count s.
-- Clients draw the flight: ArrowFired (unreliable, nearby players) with the same start and velocity, ArrowEnded when
-- the server's arrow is done (src/client/Arrows.luau).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local CombatService = require(script.Parent.CombatService)
local MotionService = require(script.Parent.MotionService)

local BowService = {}
local started = false

local BOW = Config.vanilla.bow
local BLOCK = Config.rules.combat.blockStuds :: number
local TICK = 0.05
local SPREAD = 0.0075 -- [ваниль] the gaussian inaccuracy of a player's shot
local ENTITY_MARGIN = 0.3 * BLOCK / 2 -- [ваниль] entity boxes grow by 0.3 blocks against arrows
local BROADCAST_STUDS = 600
local MAX_STUCK = 200

type Flying = {
	id: number,
	shooter: Player,
	position: Vector3, -- studs
	velocity: Vector3, -- studs a tick
	power: number, -- Power enchant level
	crit: boolean,
	flame: boolean,
	creative: boolean,
	ticks: number,
	lag: number, -- s the shooter sees players behind the server clock: players are tested that far back
}
type Stuck = { part: BasePart, on: BasePart, at: number, pickup: boolean }

local drawing: { [Player]: number } = {} -- os.clock() of the draw start
local flying: { Flying } = {}
local stuck: { Stuck } = {}
local inBody: { [Model]: number } = {} -- os.clock() when the next body arrow falls out
local burning: { [Humanoid]: { untilAt: number, nextAt: number, by: Player?, model: Model } } = {}
local nextId = 0
local folder: Folder

-- [ваниль] the draw curve
function BowService.Power(seconds: number): number
	local f = seconds / BOW.drawSeconds
	f = (f * f + 2 * f) / 3
	return math.min(f, 1)
end

local function held(profile: Types.Profile): (boolean, number)
	local stack = profile.inventory[profile.selectedSlot]
	if stack and stack.id == "bow" then
		return true, stack.level or 1
	end
	return false, 0
end

local function creative(player: Player): boolean
	return player:GetAttribute("Creative") == true
end

local function stopDraw(player: Player)
	drawing[player] = nil
	local character = player.Character
	if character then
		character:SetAttribute("BowDrawAt", nil)
	end
end

local function onDraw(player: Player)
	local profile = ProfileService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not profile
		or not character
		or not humanoid
		or humanoid.Health <= 0
		or not held(profile)
	then
		return
	end
	if not creative(player) and InventoryService.count(profile, "arrow") <= 0 then
		Remotes.event("Toast")
			:FireClient(player, Strings.t("bow_no_arrows", Strings.localeOf(player)))
		return
	end
	drawing[player] = os.clock()
	character:SetAttribute("BowDrawAt", workspace:GetServerTimeNow())
end

local function gaussian(random: Random): number
	-- Box–Muller
	local u = math.max(random:NextNumber(), 1e-9)
	return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * random:NextNumber())
end
local random = Random.new()

local function onRelease(player: Player, direction: any, viewTime: any)
	local startedAt = drawing[player]
	stopDraw(player)
	if
		not startedAt
		or typeof(direction) ~= "Vector3"
		or direction ~= direction
		or direction.Magnitude < 0.5
		or direction.Magnitude > 1.5
	then
		return
	end
	local profile = ProfileService.Get(player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if
		not profile
		or not head
		or not head:IsA("BasePart")
		or not humanoid
		or humanoid.Health <= 0
	then
		return
	end
	local isBow, level = held(profile)
	if not isBow then
		return
	end
	local f = BowService.Power(os.clock() - startedAt)
	if f < BOW.minPower then
		return
	end
	local isCreative = creative(player)
	if not isCreative then
		if InventoryService.count(profile, "arrow") <= 0 then
			Remotes.event("Toast")
				:FireClient(player, Strings.t("bow_no_arrows", Strings.localeOf(player)))
			return
		end
		ProfileService.Mutate(player, function(p)
			InventoryService.remove(p, "arrow", 1)
		end)
	end
	local dir = direction.Unit
	dir = (dir + Vector3.new(gaussian(random), gaussian(random), gaussian(random)) * SPREAD).Unit
	nextId += 1
	local arrow: Flying = {
		id = nextId,
		shooter = player,
		position = head.Position + dir * 1.2,
		velocity = dir * BOW.speedBlocksPerTick * f * BLOCK,
		power = Config.enchantForLevel("bow", level),
		crit = f >= 1,
		flame = Config.flameForLevel("bow", level) > 0,
		creative = isCreative,
		ticks = 0,
		lag = workspace:GetServerTimeNow()
			- (MotionService.viewTime(viewTime) or workspace:GetServerTimeNow()),
	}
	table.insert(flying, arrow)
	Sfx.broadcast("swing", head, 0.8, 1.6)
	local fired = Remotes.unreliable("ArrowFired")
	for _, other in ipairs(Players:GetPlayers()) do
		local root = other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if
			root
			and root:IsA("BasePart")
			and (root.Position - arrow.position).Magnitude < BROADCAST_STUDS
		then
			fired:FireClient(
				other,
				arrow.id,
				player.UserId,
				arrow.position,
				arrow.velocity,
				arrow.crit,
				arrow.flame
			)
		end
	end
end

-- the segment from `origin` along `delta` against a box: the fraction 0..1 where it enters, or nil
local function segmentBox(origin: Vector3, delta: Vector3, cf: CFrame, size: Vector3): number?
	local o = cf:PointToObjectSpace(origin)
	local d = cf:VectorToObjectSpace(delta)
	local half = size / 2
	local tMin, tMax = 0, 1
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local oa, da, ha =
			(o :: any)[axis] :: number, (d :: any)[axis] :: number, (half :: any)[axis] :: number
		if math.abs(da) < 1e-9 then
			if oa < -ha or oa > ha then
				return nil
			end
		else
			local t1, t2 = (-ha - oa) / da, (ha - oa) / da
			if t1 > t2 then
				t1, t2 = t2, t1
			end
			tMin, tMax = math.max(tMin, t1), math.min(tMax, t2)
			if tMin > tMax then
				return nil
			end
		end
	end
	return tMin
end

local function targets(shooter: Player): { Model }
	local list: { Model } = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= shooter and other.Character then
			table.insert(list, other.Character)
		end
	end
	for _, tag in ipairs({ "Mob", "Boss" }) do
		for _, model in ipairs(CollectionService:GetTagged(tag)) do
			if model:IsA("Model") and model:IsDescendantOf(workspace) then
				table.insert(list, model)
			end
		end
	end
	return list
end

local function setFire(model: Model, on: boolean)
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root then
		return
	end
	local fire = root:FindFirstChild("ArrowFire")
	if on and not fire then
		local f = Instance.new("Fire")
		f.Name = "ArrowFire"
		f.Size = 4
		f.Heat = 8
		f.Parent = root
	elseif not on and fire then
		fire:Destroy()
	end
end

local function ignite(model: Model, by: Player)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local now = os.clock()
	local entry = burning[humanoid]
	burning[humanoid] = {
		untilAt = now + BOW.flameSeconds,
		nextAt = if entry then entry.nextAt else now + 1,
		by = by,
		model = model,
	}
	setFire(model, true)
end

local function stick(arrow: Flying, at: Vector3, on: BasePart)
	local part = Instance.new("Part")
	part.Name = "StuckArrow"
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Transparency = 1
	part.Anchored = true
	part.CanCollide, part.CanQuery, part.CanTouch = false, false, false
	part.CFrame = CFrame.lookAt(at, at + arrow.velocity.Unit)
	part:SetAttribute("Flame", arrow.flame or nil)
	CollectionService:AddTag(part, "StuckArrow")
	part.Parent = folder
	table.insert(stuck, { part = part, on = on, at = os.clock(), pickup = not arrow.creative })
	if #stuck > MAX_STUCK then
		table.remove(stuck, 1).part:Destroy()
	end
	Sfx.broadcast("wood_hit", part, 0.7, 1.7)
end

local raycast = RaycastParams.new()
raycast.FilterType = Enum.RaycastFilterType.Exclude
raycast.RespectCanCollide = true

-- one Minecraft tick of a flying arrow; false when it is done
-- [ваниль] LivingEntity arrow count: +1 a hit, one less every 20 × (30 − count) ticks
local MAX_IN_BODY = 12
local function addInBody(model: Model)
	local count = model:GetAttribute("ArrowsInBody")
	local n = math.min(MAX_IN_BODY, (if typeof(count) == "number" then count else 0) + 1)
	model:SetAttribute("ArrowsInBody", n)
	if not inBody[model] then
		inBody[model] = os.clock() + (30 - n)
	end
end

local function shedInBody()
	local now = os.clock()
	for model, at in pairs(inBody) do
		local count = model:GetAttribute("ArrowsInBody")
		if not model.Parent or typeof(count) ~= "number" or count <= 0 then
			inBody[model] = nil
		elseif now >= at then
			model:SetAttribute("ArrowsInBody", if count > 1 then count - 1 else nil)
			inBody[model] = if count > 1 then now + (30 - (count - 1)) else nil
		end
	end
end

local function step(arrow: Flying): boolean
	arrow.ticks += 1
	local shooter = arrow.shooter
	local profile = ProfileService.Get(shooter)
	if not profile or arrow.ticks > BOW.maxFlightSeconds / TICK then
		return false
	end
	local from, delta = arrow.position, arrow.velocity
	local candidates = targets(shooter)
	local exclude: { Instance } = { folder }
	for _, model in ipairs(candidates) do
		table.insert(exclude, model)
	end
	if shooter.Character then
		table.insert(exclude, shooter.Character)
	end
	raycast.FilterDescendantsInstances = exclude
	local wall = workspace:Raycast(from, delta, raycast)
	local wallT = if wall then (wall.Position - from).Magnitude / delta.Magnitude else math.huge
	local best: Model?, bestT = nil, wallT
	local reach = delta.Magnitude
	for _, model in ipairs(candidates) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			local cf, size =
				CombatService.targetBox(model, workspace:GetServerTimeNow() - arrow.lag)
			if (cf.Position - from).Magnitude < reach + size.Magnitude then
				local t = segmentBox(from, delta, cf, size + Vector3.one * ENTITY_MARGIN * 2)
				if t and t < bestT then
					best, bestT = model, t
				end
			end
		end
	end
	if best then
		-- [ваниль] damage from the speed at the hit, Power, and the crit bonus of a full draw
		local speed = arrow.velocity.Magnitude / BLOCK
		local base = BOW.baseDamage + (if arrow.power > 0 then 0.5 * arrow.power + 0.5 else 0)
		local damage = math.ceil(speed * base)
		if arrow.crit then
			damage += random:NextInteger(0, math.floor(damage / 2) + 1)
			CombatService.critBurst(from + delta * bestT)
		end
		local result =
			CombatService.HitModel(shooter, profile, best, damage, arrow.crit, arrow.velocity.Unit)
		if arrow.flame and (result == "hit" or result == "killed") then
			ignite(best, shooter)
		end
		if result == "hit" then
			addInBody(best)
		end
		local root = best:FindFirstChild("HumanoidRootPart") or best.PrimaryPart
		if root and root:IsA("BasePart") then
			Sfx.broadcast("hit", root, 0.8, 1.2)
		end
		return false
	end
	if wall then
		stick(arrow, wall.Position, wall.Instance :: BasePart)
		return false
	end
	-- [ваниль] move, then drag, then gravity
	arrow.position = from + delta
	arrow.velocity = arrow.velocity * BOW.drag - Vector3.new(0, BOW.gravity * BLOCK, 0)
	return arrow.position.Y > workspace.FallenPartsDestroyHeight
end

local function pickUp()
	local now = os.clock()
	local radius = BOW.pickupBlocks * BLOCK
	for i = #stuck, 1, -1 do
		local entry = stuck[i]
		local gone = not entry.part.Parent
			or not entry.on.Parent
			or entry.on.Transparency >= 1
			or now - entry.at > BOW.stuckSeconds
		local taker: Player? = nil
		if not gone and entry.pickup and now - entry.at > 0.5 then
			for _, player in ipairs(Players:GetPlayers()) do
				local root = player.Character
					and player.Character:FindFirstChild("HumanoidRootPart")
				local profile = ProfileService.Get(player)
				if
					root
					and root:IsA("BasePart")
					and profile
					and (root.Position - entry.part.Position).Magnitude <= radius
					and InventoryService.canAdd(profile, "arrow", 1)
				then
					taker = player
					break
				end
			end
		end
		if taker then
			ProfileService.Mutate(taker, function(p)
				InventoryService.add(p, "arrow", 1)
			end)
			Sfx.toPlayer(taker, "pickup", 0.6)
			gone = true
		end
		if gone then
			entry.part:Destroy()
			table.remove(stuck, i)
		end
	end
end

local function burn()
	local now = os.clock()
	for humanoid, entry in pairs(burning) do
		if humanoid.Health <= 0 or not humanoid.Parent or now >= entry.untilAt then
			setFire(entry.model, false)
			burning[humanoid] = nil
		elseif now >= entry.nextAt then
			entry.nextAt = now + 1
			local by = entry.by
			local victim = Players:GetPlayerFromCharacter(entry.model)
			if victim then
				CombatService.ApplyDamage(humanoid, BOW.flameDamagePerSecond, "player", by)
			elseif by then
				humanoid:SetAttribute("LastHitBy", by.UserId)
				humanoid:SetAttribute("LastHitAt", now)
				humanoid:TakeDamage(BOW.flameDamagePerSecond)
			end
		end
	end
end

function BowService.Start()
	if started then
		return
	end
	started = true
	folder = Instance.new("Folder")
	folder.Name = "Arrows"
	folder.Parent = workspace
	Remotes.unreliable("ArrowFired")
	local ended = Remotes.event("ArrowEnded")
	Remotes.event("BowDraw").OnServerEvent:Connect(onDraw)
	Remotes.event("BowRelease").OnServerEvent:Connect(onRelease)
	Remotes.event("BowCancel").OnServerEvent:Connect(stopDraw)
	local acc = 0
	local sinceSweep = 0
	RunService.Heartbeat:Connect(function(dt)
		-- a draw ends when the bow leaves the hand or the player dies
		for player in pairs(drawing) do
			local profile = ProfileService.Get(player)
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if not profile or not held(profile) or not humanoid or humanoid.Health <= 0 then
				stopDraw(player)
			end
		end
		acc = math.min(acc + dt, TICK * 5)
		while acc >= TICK do
			acc -= TICK
			for i = #flying, 1, -1 do
				local arrow = flying[i]
				if not step(arrow) then
					table.remove(flying, i)
					ended:FireAllClients(arrow.id)
				end
			end
		end
		sinceSweep += dt
		if sinceSweep >= 0.2 then
			sinceSweep = 0
			pickUp()
			burn()
			shedInBody()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		drawing[player] = nil
	end)
end

return BowService
