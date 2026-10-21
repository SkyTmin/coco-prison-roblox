--!strict
-- Online-only needs, restore prompts/consumables and shared temporary events.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Effects = require(Shared.Effects)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)

type Need = "hygiene" | "sleep" | "toilet"
type State = {
	nextDecay: number,
	previous: Types.Needs,
	humanoid: Humanoid?,
	movementMultiplier: number,
}
type Event = { name: string, endsAt: number, endsAtServer: number }

local NEEDS: { Need } = { "hygiene", "sleep", "toilet" }
local RESTORE_TAGS: { [string]: Need } = {
	RestoreHygiene = "hygiene",
	RestoreSleep = "sleep",
	RestoreToilet = "toilet",
}
local EVENTS = { "haste", "speed", "regeneration", "strength" }
local DECAY_SECONDS = 10
local PROMPT_DISTANCE = 8

local NeedsService = {}
local states: { [Player]: State } = {}
local activeEvent: Event? = nil
local started = false

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- Minecraft-style swirl particles in the mixed colour of all active effects, seen by every player.
local function updateParticles(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local active = Effects.active(character)
	local emitter = root:FindFirstChild("EffectParticles")
	if #active == 0 then
		if emitter then
			emitter:Destroy()
		end
		return
	end
	-- vanilla mixes the potion colours of all active effects (weighted by level)
	local r, g, b, weight = 0, 0, 0, 0
	for _, entry in ipairs(active) do
		r += entry.effect.color.R * entry.level
		g += entry.effect.color.G * entry.level
		b += entry.effect.color.B * entry.level
		weight += entry.level
	end
	local color = Color3.new(r / weight, g / weight, b / weight)
	if not emitter or not emitter:IsA("ParticleEmitter") then
		local new = Instance.new("ParticleEmitter")
		new.Name = "EffectParticles"
		new.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		new.Shape = Enum.ParticleEmitterShape.Box
		new.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		new.EmissionDirection = Enum.NormalId.Top
		new.Rate = 5
		new.Lifetime = NumberRange.new(1, 1.6)
		new.Speed = NumberRange.new(0.6, 1.2)
		new.Acceleration = Vector3.new(0, 0.6, 0)
		new.RotSpeed = NumberRange.new(-90, 90)
		new.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 0.1),
		})
		new.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		new.LightEmission = 0.3
		new.Parent = root
		emitter = new
	end
	(emitter :: ParticleEmitter).Color = ColorSequence.new(color)
end

local function setEffect(character: Model, attribute: string, level: number?, endsAt: number?)
	character:SetAttribute(attribute, level)
	character:SetAttribute(attribute .. Effects.UNTIL, if level then endsAt else nil)
end

local function applyEffects(player: Player, state: State, needs: Types.Needs)
	local character = player.Character
	if not character then
		return
	end
	local event = if activeEvent and os.clock() < activeEvent.endsAt then activeEvent else nil
	local eventName = if event then event.name else nil
	local eventEnds = if event then event.endsAtServer else nil
	-- needs at 0 [вики]: dirt → Nausea, sleep → Insomnia, toilet → Slowness; they last until restored
	setEffect(character, "Nausea", if needs.hygiene <= 0 then 1 else nil)
	setEffect(character, "Insomnia", if needs.sleep <= 0 then 1 else nil)
	setEffect(character, "Slowness", if needs.toilet <= 0 then 1 else nil)
	-- random events: a vanilla level-I effect for everyone [сеть, вики-скриншот]
	for _, name in ipairs(EVENTS) do
		local attribute = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
		setEffect(character, attribute, if eventName == name then 1 else nil, eventEnds)
	end
	updateParticles(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if state.humanoid ~= humanoid then
		state.humanoid = humanoid
		state.movementMultiplier = 1
	end
	local multiplier = (if needs.toilet <= 0 then 1 - Effects.SLOWNESS_PER_LEVEL else 1)
		* (if eventName == "speed" then 1 + Effects.SPEED_PER_LEVEL else 1)
	if multiplier ~= state.movementMultiplier then
		humanoid.WalkSpeed = humanoid.WalkSpeed / state.movementMultiplier * multiplier
		state.movementMultiplier = multiplier
	end
end

-- [владелец 21.10] no need bars: while a need is at zero the client keeps its hint on screen
-- (need_effect_* under the effect icon), so the server only applies the effects
local function sync(player: Player, state: State, needs: Types.Needs)
	for _, need in ipairs(NEEDS) do
		state.previous[need] = needs[need]
	end
	applyEffects(player, state, needs)
end

local function restored(player: Player, need: Need)
	local profile = ProfileService.Get(player)
	local state = states[player]
	if profile and state then
		sync(player, state, profile.needs)
	end
	toast(player, "need_restored_" .. need)
end

local function bindPrompt(instance: Instance, tag: string, need: Need)
	if not instance:IsA("BasePart") then
		return
	end
	local prompt = instance:FindFirstChildOfClass("ProximityPrompt")
		or Instance.new("ProximityPrompt")
	prompt.ActionText = Strings.t("restore_" .. need .. "_prompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = PROMPT_DISTANCE
	-- toilets sit in stalls and the pool zones under water: walls and water must not hide the prompt
	prompt.RequiresLineOfSight = false
	prompt.Parent = instance
	prompt.Triggered:Connect(function(player)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		-- Recheck server distance/tag: prompt activation can be forged by a client.
		if
			not root
			or not root:IsA("BasePart")
			or not humanoid
			or humanoid.Health <= 0
			or not instance:IsDescendantOf(workspace)
			or not CollectionService:HasTag(instance, tag)
			or (root.Position - instance.Position).Magnitude > PROMPT_DISTANCE
			or not ProfileService.Get(player)
		then
			return
		end
		ProfileService.Mutate(player, function(profile)
			profile.needs[need] = 100
		end)
		restored(player, need)
	end)
end

local function useConsumable(player: Player, slot: any)
	if not InventoryService.isSlot(slot) then
		return
	end
	local profile = ProfileService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid or humanoid.Health <= 0 then
		return
	end
	local stack = profile.inventory[slot]
	if not stack or stack.count < 1 then
		return
	end
	local need: Need? = nil
	for _, candidate in ipairs(NEEDS) do
		if stack.id == Config.needs[candidate].consumable then
			need = candidate
			break
		end
	end
	local food = Config.rules.survival.food[stack.id]
	if not need and not food then
		return
	end
	local matchingNeed = need
	local consumed = false
	ProfileService.Mutate(player, function(p)
		-- remove() searches backwards by id. Swap temporarily so it consumes this exact slot,
		-- including when several stacks contain the same consumable.
		local last = InventoryService.SLOTS
		p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
		consumed = InventoryService.remove(p, stack.id, 1) == 1
		p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
		if consumed then
			if matchingNeed then
				p.needs[matchingNeed] = 100
			end
			if food then
				p.hunger = math.min(Config.rules.survival.hunger.max, p.hunger + food)
			end
		end
	end)
	if consumed then
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- eating bites like Minecraft; soap splashes, a sleeping bag / paper rustles
			Sfx.broadcast(
				if food then "eat" elseif matchingNeed == "hygiene" then "water_step" else "wool",
				root,
				0.7
			)
		end
		if matchingNeed then
			restored(player, matchingNeed)
		elseif food then
			toast(player, "hunger_restored")
		end
		if stack.id == "golden_apple" then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 4 * 2)
		end
	end
end

local function updatePlayers()
	local now = os.clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = ProfileService.Get(player)
		if not profile then
			continue
		end
		local state = states[player]
		if not state then
			ProfileService.Mutate(player, function(p)
				for _, need in ipairs(NEEDS) do
					p.needs[need] = math.clamp(p.needs[need] or 100, 0, 100)
				end
			end)
			state = {
				nextDecay = now + DECAY_SECONDS,
				previous = table.clone(profile.needs),
				humanoid = nil,
				movementMultiplier = 1,
			}
			states[player] = state
		end
		if now >= state.nextDecay then
			local ticks = math.floor((now - state.nextDecay) / DECAY_SECONDS) + 1
			state.nextDecay += ticks * DECAY_SECONDS
			ProfileService.Mutate(player, function(p)
				for _, need in ipairs(NEEDS) do
					-- Trainer "needs" levels slow the drain (Config.trainer.needs.perLevel per level) [решение]
					local trained = if p.trainer then (p.trainer.needs or 0) else 0
					local decay = 100
						/ (Config.needs[need].minutesToZero * 6)
						* math.max(0.1, 1 - trained * Config.trainer.needs.perLevel)
					local value = math.clamp(p.needs[need] - decay * ticks, 0, 100)
					-- Floating-point residue must not postpone a zero effect by another tick.
					p.needs[need] = if value < 1e-9 then 0 else value
				end
			end)
		end
		sync(player, state, profile.needs)
	end
end

local function refreshEffects()
	for player, state in pairs(states) do
		local profile = ProfileService.Get(player)
		if profile then
			applyEffects(player, state, profile.needs)
		end
	end
end

local function startEvent()
	local event: Event = {
		name = EVENTS[math.random(1, #EVENTS)],
		endsAt = os.clock() + Config.needs.randomEvent.durationSeconds,
		endsAtServer = workspace:GetServerTimeNow() + Config.needs.randomEvent.durationSeconds,
	}
	activeEvent = event
	for _, player in ipairs(Players:GetPlayers()) do
		local name = Strings.t("event_" .. event.name, Strings.localeOf(player))
		toast(player, "event_started", name)
	end
	refreshEffects()
	if event.name == "regeneration" then
		task.spawn(function()
			while activeEvent == event do
				task.wait(2)
				if activeEvent ~= event or os.clock() >= event.endsAt then
					break
				end
				for _, player in ipairs(Players:GetPlayers()) do
					local character = player.Character
					local humanoid = character and character:FindFirstChildOfClass("Humanoid")
					if humanoid and humanoid.Health > 0 then
						humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 1)
					end
				end
			end
		end)
	end
	task.delay(Config.needs.randomEvent.durationSeconds, function()
		if activeEvent == event then
			activeEvent = nil
			refreshEffects()
		end
	end)
end

function NeedsService.Start()
	if started then
		return
	end
	started = true
	for tag, need in pairs(RESTORE_TAGS) do
		for _, instance in ipairs(CollectionService:GetTagged(tag)) do
			bindPrompt(instance, tag, need)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(instance)
			bindPrompt(instance, tag, need)
		end)
	end
	Remotes.event("UseConsumable").OnServerEvent:Connect(useConsumable)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			updatePlayers()
			task.wait(1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(Config.needs.randomEvent.everySeconds)
			startEvent()
		end
	end)
end

return NeedsService
