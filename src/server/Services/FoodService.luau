--!strict
-- Eating like Minecraft [ваниль, владелец 27.10: «еду надо есть долго как в майне, а не мгновенно»]: holding the use
-- button with food in hand eats it over 32 ticks (1.6 s); letting go or switching the slot stops it. The client sends
-- EatStart(slot) / EatCancel(); the server times it and only then feeds (hunger + saturation, HungerService.Feed) and
-- gives the food's effects (the golden apple: Regeneration II, Absorption — NeedsService.GiveEffect). Food can be
-- eaten only when not full, the golden apple always. The character attribute Eating = item id and EatingAt = server
-- time let every client draw the arm, the crumbs and the chewing (Eating.luau).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local HungerService = require(script.Parent.HungerService)
local NeedsService = require(script.Parent.NeedsService)

local survival = Config.rules.survival
local EAT = survival.eating
-- the client starts its clock on the press and the server on arrival: a little slack for the trip is fine, a
-- finish sent far too early is not possible (the server's own clock decides)
local SECONDS = EAT.seconds :: number

type Eating = { slot: number, id: string, startedAt: number }

local FoodService = {}
local eating: { [Player]: Eating } = {}
local started = false

local function toast(player: Player, key: string)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player)))
end

local function setShown(player: Player, id: string?)
	local character = player.Character
	if character then
		character:SetAttribute("Eating", id)
		character:SetAttribute("EatingAt", if id then workspace:GetServerTimeNow() else nil)
	end
end

local function stop(player: Player)
	if eating[player] then
		eating[player] = nil
		setShown(player, nil)
	end
end

function FoodService.isFood(id: string?): boolean
	return id ~= nil and typeof(survival.food[id]) == "number"
end

local function onStart(player: Player, slot: any)
	if not InventoryService.isSlot(slot) then
		return
	end
	local profile = ProfileService.Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not profile or not humanoid or humanoid.Health <= 0 or profile.selectedSlot ~= slot then
		return
	end
	local stack = profile.inventory[slot]
	if not stack or stack.count < 1 or not FoodService.isFood(stack.id) then
		return
	end
	local current = eating[player]
	if current and current.slot == slot and current.id == stack.id then
		return -- already eating it
	end
	if profile.hunger >= survival.hunger.max and not EAT.alwaysEdible[stack.id] then
		toast(player, "eat_full")
		return
	end
	eating[player] = { slot = slot, id = stack.id, startedAt = os.clock() }
	setShown(player, stack.id)
end

local function finish(player: Player, entry: Eating)
	stop(player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local consumed = false
	ProfileService.Mutate(player, function(p)
		-- remove() searches backwards by id: swap so it takes this exact slot
		local last = InventoryService.SLOTS
		p.inventory[entry.slot], p.inventory[last] = p.inventory[last], p.inventory[entry.slot]
		consumed = InventoryService.remove(p, entry.id, 1) == 1
		p.inventory[entry.slot], p.inventory[last] = p.inventory[last], p.inventory[entry.slot]
	end)
	if not consumed then
		return
	end
	HungerService.Feed(player, survival.food[entry.id], survival.saturation[entry.id] or 0)
	local effects = survival.foodEffects[entry.id]
	if typeof(effects) == "table" then
		for _, effect in ipairs(effects) do
			NeedsService.GiveEffect(player, effect.effect, effect.level, effect.seconds)
		end
	end
	Remotes.event("Ate"):FireClient(player, entry.id)
end

local function update()
	local now = os.clock()
	for player, entry in pairs(eating) do
		local profile = ProfileService.Get(player)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local stack = profile and profile.inventory[entry.slot]
		if
			not profile
			or not humanoid
			or humanoid.Health <= 0
			or profile.selectedSlot ~= entry.slot
			or not stack
			or stack.id ~= entry.id
		then
			stop(player)
		elseif now - entry.startedAt >= SECONDS then
			finish(player, entry)
		end
	end
end

function FoodService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("EatStart").OnServerEvent:Connect(onStart)
	Remotes.event("EatCancel").OnServerEvent:Connect(stop)
	Remotes.event("Ate")
	Players.PlayerRemoving:Connect(stop)
	RunService.Heartbeat:Connect(update)
end

return FoodService
