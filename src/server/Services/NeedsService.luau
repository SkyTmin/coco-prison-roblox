--!strict
-- Online-only needs, restore prompts/consumables and shared temporary events.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
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
type Event = { name: string, endsAt: number }

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

local function applyEffects(player: Player, state: State, needs: Types.Needs)
	local character = player.Character
	if not character then
		return
	end
	local eventName = if activeEvent and os.clock() < activeEvent.endsAt
		then activeEvent.name
		else nil
	character:SetAttribute("Nausea", needs.hygiene <= 0)
	character:SetAttribute("Insomnia", needs.sleep <= 0)
	character:SetAttribute("Haste", if eventName == "haste" then 1 else nil)
	character:SetAttribute("Strength", if eventName == "strength" then 1 else nil)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if state.humanoid ~= humanoid then
		state.humanoid = humanoid
		state.movementMultiplier = 1
	end
	local multiplier = (if needs.toilet <= 0 then 1 - Config.needs.toilet.moveSlowdownAtZero else 1)
		* (if eventName == "speed" then 1.2 else 1)
	if multiplier ~= state.movementMultiplier then
		humanoid.WalkSpeed = humanoid.WalkSpeed / state.movementMultiplier * multiplier
		state.movementMultiplier = multiplier
	end
end

local function sync(player: Player, state: State, needs: Types.Needs)
	for _, need in ipairs(NEEDS) do
		if
			state.previous[need] >= Config.needs.warnThreshold
			and needs[need] < Config.needs.warnThreshold
		then
			toast(player, "need_low_" .. need)
		end
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
					local decay = 100 / (Config.needs[need].minutesToZero * 6)
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
