--!strict
-- Online-only needs, restore prompts/consumables and shared temporary events.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Books = require(Shared.Books)
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Donate = require(Shared.Donate)
local Effects = require(Shared.Effects)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local SkillService = require(script.Parent.SkillService)

type Need = "hygiene" | "sleep" | "toilet"
type State = {
	nextDecay: number,
	previous: Types.Needs,
	humanoid: Humanoid?,
	movementMultiplier: number,
}
type Event = { name: string, endsAt: number, endsAtServer: number }
-- an effect with its own timer (food: the golden apple) [ваниль]
type Timed = { level: number, endsAt: number, endsAtServer: number }

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
local timed: { [Player]: { [string]: Timed } } = {}
-- [ваниль] Absorption: 4 golden HP per level, taken before health (DamageService); gone when the effect ends
local ABSORPTION_PER_LEVEL = 4
NeedsService.ABSORPTION = "AbsorptionHealth"
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
	-- the injection «Без нужд» [владелец 28.10]: for good, shown as an effect with no timer
	local profile = ProfileService.Get(player)
	setEffect(character, "NeedsFree", if profile and profile.needsFree then 1 else nil)
	local own = timed[player] or {}
	local now = os.clock()
	for attribute, entry in pairs(own) do
		if now >= entry.endsAt then
			own[attribute] = nil
			if attribute == "Absorption" then
				character:SetAttribute(NeedsService.ABSORPTION, nil)
			end
		end
	end
	-- needs at 0 [вики]: dirt → Nausea, sleep → Insomnia, toilet → Slowness; they last until restored. A book's
	-- Nausea / Slowness of a few seconds (Замешательство, Вихрь, Бульдозер) shows with its timer otherwise
	local function needOrOwn(attribute: string, atZero: boolean)
		local entry = own[attribute]
		if atZero then
			setEffect(character, attribute, 1)
		else
			setEffect(
				character,
				attribute,
				if entry then entry.level else nil,
				if entry then entry.endsAtServer else nil
			)
		end
	end
	needOrOwn("Nausea", needs.hygiene <= 0)
	setEffect(character, "Insomnia", if needs.sleep <= 0 then 1 else nil)
	needOrOwn("Slowness", needs.toilet <= 0)
	-- random events: a vanilla level-I effect for everyone [сеть, вики-скриншот]; an effect of the player's own
	-- (food) wins when it is stronger
	for _, name in ipairs(EVENTS) do
		local attribute = string.upper(string.sub(name, 1, 1)) .. string.sub(name, 2)
		local mine = own[attribute]
		if mine and (eventName ~= name or mine.level > 1) then
			setEffect(character, attribute, mine.level, mine.endsAtServer)
		else
			setEffect(character, attribute, if eventName == name then 1 else nil, eventEnds)
		end
	end
	local absorption = own.Absorption
	setEffect(
		character,
		"Absorption",
		if absorption then absorption.level else nil,
		if absorption then absorption.endsAtServer else nil
	)
	updateParticles(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	if state.humanoid ~= humanoid then
		state.humanoid = humanoid
		state.movementMultiplier = 1
	end
	-- Slowness / Speed levels [ваниль], the books' Frost stacks and Hulk's weight [вики BOOKS-SYSTEM]
	local slow =
		math.max(if needs.toilet <= 0 then 1 else 0, if own.Slowness then own.Slowness.level else 0)
	local fast =
		math.max(if eventName == "speed" then 1 else 0, if own.Speed then own.Speed.level else 0)
	local frost = tonumber(character:GetAttribute("Frost")) or 0
	local hulk = profile ~= nil and Books.worn(profile, "hulk") > 0
	local multiplier = math.max(0.1, 1 - Effects.SLOWNESS_PER_LEVEL * slow)
		* (1 + Effects.SPEED_PER_LEVEL * fast)
		* math.max(0.1, 1 - Effects.FROST_PER_STACK * frost)
		* (if hulk then 1 - Effects.HULK_SLOWNESS else 1)
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
	-- food is eaten over time by FoodService (EatStart), not used at once
	-- a location pass (<location>_pass) is used like food [владелец 22.10: «кнопка использовать, как еду есть»]:
	-- it opens the location for good and is gone
	local passFor = stack.id:match("^(.+)_pass$")
	local passLocation = passFor and Config.location(passFor)
	if passLocation and passLocation.requiresPass then
		if profile.passes[passFor] then
			toast(player, "location_pass_owned")
			return
		end
		local used = false
		ProfileService.Mutate(player, function(p)
			local last = InventoryService.SLOTS
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			used = InventoryService.remove(p, stack.id, 1) == 1
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			if used then
				p.passes[passFor] = true
			end
		end)
		if used then
			toast(player, "location_pass_used")
		end
		return
	end
	-- the oblivion scroll resets the skill tree [меню 26.10: «для сброса Ваших текущих навыков, чтобы обучиться новым»]
	if stack.id == "oblivion_scroll" then
		SkillService.Reset(player, slot)
		return
	end
	-- the injection «Без нужд» [владелец 28.10: «избавляет игрока от нужд, ему больше не надо будет ходить в
	-- туалет и так далее»]: all three needs full and never draining again; the item is gone
	if stack.id == Config.needs.injection.item then
		if profile.needsFree then
			toast(player, "needs_injection_owned")
			return
		end
		local injected = false
		ProfileService.Mutate(player, function(p)
			local last = InventoryService.SLOTS
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			injected = InventoryService.remove(p, stack.id, 1) == 1
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			if injected then
				p.needsFree = true
				for _, each in ipairs(NEEDS) do
					p.needs[each] = 100
				end
			end
		end)
		if injected then
			local state = states[player]
			if state then
				sync(player, state, profile.needs)
			end
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				Sfx.broadcast("xp", root, 0.8)
			end
			toast(player, "needs_injection_used")
		end
		return
	end
	-- the auto-sell [владелец 28.10]: an item until used (so it can go to the Auction), then the profile's for good
	if stack.id == Donate.AUTOSELL then
		if profile.autosell then
			toast(player, "autosell_owned")
			return
		end
		local unlocked = false
		ProfileService.Mutate(player, function(p)
			local last = InventoryService.SLOTS
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			unlocked = InventoryService.remove(p, stack.id, 1) == 1
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			if unlocked then
				p.autosell = true
			end
		end)
		if unlocked then
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and root:IsA("BasePart") then
				Sfx.broadcast("xp", root, 0.8)
			end
			toast(player, "autosell_used")
		end
		return
	end
	-- a donate booster as an item → back into the booster storage [B]; the auction slot item → +1 lot slot
	-- [владелец 28.10: «всё, что можно купить в донат-магазине, можно выставлять на аукционе»]
	local boosterKind, boosterScope = Boosters.fromItem(stack.id)
	local slotItem = Donate.item(Donate.AUCTION_SLOT)
	if boosterKind or (stack.id == Donate.AUCTION_SLOT and slotItem) then
		if boosterKind and Boosters.storedCount(profile) >= Config.boosters.maxStored then
			toast(player, "donate_storage_full")
			return
		elseif
			not boosterKind
			and slotItem
			and (profile.auctionSlots or 0) >= (slotItem.max or 0)
		then
			toast(player, "donate_limit")
			return
		end
		local done = false
		ProfileService.Mutate(player, function(p)
			local last = InventoryService.SLOTS
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			done = InventoryService.remove(p, stack.id, 1) == 1
			p.inventory[slot], p.inventory[last] = p.inventory[last], p.inventory[slot]
			if done and boosterKind then
				Boosters.store(p, boosterKind, boosterScope, Donate.MULT, Donate.MINUTES)
			elseif done then
				p.auctionSlots = (p.auctionSlots or 0) + 1
			end
		end)
		if done then
			toast(
				player,
				if boosterKind then "booster_item_stored" else "auction_slot_used",
				profile.auctionSlots or 0
			)
		end
		return
	end
	if not need then
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
		end
	end)
	if consumed then
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- soap splashes, a sleeping bag / paper rustles
			Sfx.broadcast(if matchingNeed == "hygiene" then "water_step" else "wool", root, 0.7)
		end
		if matchingNeed then
			restored(player, matchingNeed)
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
		if player:GetAttribute("Creative") or profile.needsFree then
			-- creative test mode / the injection «Без нужд»: needs never drain
			state.nextDecay = now + DECAY_SECONDS
		elseif now >= state.nextDecay then
			local ticks = math.floor((now - state.nextDecay) / DECAY_SECONDS) + 1
			state.nextDecay += ticks * DECAY_SECONDS
			ProfileService.Mutate(player, function(p)
				for _, need in ipairs(NEEDS) do
					-- Trainer "needs" levels slow the drain (Config.trainer.needs.perLevel per level) [решение]
					local trained = if p.trainer then (p.trainer.needs or 0) else 0
					-- the helmet book «Чистюля» slows them by its share [вики BOOKS-SYSTEM]
					local decay = 100
						/ (Config.needs[need].minutesToZero * 6)
						* math.max(0.1, 1 - trained * Config.trainer.needs.perLevel)
						* math.max(0, 1 - Books.worn(p, "neat"))
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

-- a timed effect of the player's own [ваниль]: drinking the same effect again keeps the longer / stronger one;
-- Absorption gives its golden health at once (at least 4 per level, more is kept)
function NeedsService.GiveEffect(player: Player, effect: string, level: number, seconds: number)
	local character = player.Character
	local state = states[player]
	local profile = ProfileService.Get(player)
	if not character or not state or not profile then
		return
	end
	local attribute = string.upper(string.sub(effect, 1, 1)) .. string.sub(effect, 2)
	local own = timed[player] or {}
	timed[player] = own
	local old = own[attribute]
	if
		not old
		or level > old.level
		or (level == old.level and os.clock() + seconds > old.endsAt)
	then
		own[attribute] = {
			level = level,
			endsAt = os.clock() + seconds,
			endsAtServer = workspace:GetServerTimeNow() + seconds,
		}
	end
	if attribute == "Absorption" then
		local current = character:GetAttribute(NeedsService.ABSORPTION)
		local now = if typeof(current) == "number" then current else 0
		character:SetAttribute(NeedsService.ABSORPTION, math.max(now, ABSORPTION_PER_LEVEL * level))
	end
	applyEffects(player, state, profile.needs)
end

-- re-applies the effects and the walk speed now (BookService: Frost stacks, Hulk armor)
function NeedsService.Refresh(player: Player)
	local state = states[player]
	local profile = ProfileService.Get(player)
	if state and profile then
		applyEffects(player, state, profile.needs)
	end
end

-- [ваниль] Regeneration heals 1 HP every 50 >> (level − 1) ticks: level I 2,5 s, II 1,25 s
local function regenerate()
	local clocks: { [Player]: number } = {}
	while true do
		task.wait(0.25)
		local now = os.clock()
		for player, own in pairs(timed) do
			local entry = own.Regeneration
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not entry or now >= entry.endsAt or not humanoid or humanoid.Health <= 0 then
				clocks[player] = nil
				continue
			end
			local every = 2.5 / 2 ^ (entry.level - 1)
			local last = clocks[player] or now
			clocks[player] = last
			if now - last >= every then
				clocks[player] = now
				humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + 1)
			end
		end
	end
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
		timed[player] = nil
	end)
	task.spawn(regenerate)
	-- [ваниль] effects end with death
	local function clearOnRespawn(player: Player)
		player.CharacterAdded:Connect(function()
			timed[player] = nil
		end)
	end
	Players.PlayerAdded:Connect(clearOnRespawn)
	for _, player in ipairs(Players:GetPlayers()) do
		clearOnRespawn(player)
	end
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
