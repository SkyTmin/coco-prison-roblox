--!strict
-- Столовая and «Ежедневные награды» (этап 7, docs/research/remaining-features-design.md; rules in Shared/Daily).
--   * Столовая [клиент canteen.*]: the cook (tag CanteenCook, scripts/build-npcs.luau) gives one portion per opening —
--     Config.daily.canteen.portion (3 жареные курицы [решение]; стейков больше нет [сеть TG/40]). Closed: «столовая
--     закрыта, приходите позже!»; again in the same opening: «Эй, не наглейте…». Every server announces the opening
--     and the closing in the chat and with a toast (the schedule is server time, so all servers agree).
--   * /daily [клиент daily.*]: the NPC «Ежедневные награды» (tag DailyNpc) and the /daily command open the window
--     (client DailyWindow); DailyClaim() takes today's card: a money check is paid at once, items go to the bag (a full
--     bag refuses, nothing is lost), boosters go to the booster storage. The check and the grant are one Mutate.
--     p.stats.dailyClaims counts every reward (achievements 7 / 30 / 100 [клиент prison.time.daily*]).
-- QA (Studio): ServerStorage.DailyDebug:Invoke(op, userId, …) — ("state", id) → JSON {state, daily, canteen, open};
-- ("reset", id) forgets both; ("shift", id, hours) moves the last reward that many hours back (a new day, or a broken
-- streak past 48 h); ("claim", id) as DailyClaim; ("portion", id) as the cook's prompt without the distance check;
-- ("canteen", "open" | "closed" | nil) forces the canteen state (nil = the schedule again).
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Daily = require(Shared.Daily)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local AchievementService = require(script.Parent.AchievementService)
local ChatService = require(script.Parent.ChatService)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

local DailyService = {}
local started = false
local ACTION_GAP = 0.5
local lastAction: { [Player]: number } = {}
local forcedOpen: boolean? = nil -- QA override of the canteen schedule

local function now(): number
	return workspace:GetServerTimeNow()
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function canteenOpen(t: number): boolean
	if forcedOpen ~= nil then
		return forcedOpen
	end
	return (Daily.canteenOpen(t))
end

local function busy(player: Player): boolean
	local t = os.clock()
	if t - (lastAction[player] or -math.huge) < ACTION_GAP then
		return true
	end
	lastAction[player] = t
	return false
end

local function nearTag(player: Player, tag: string, range: number): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	for _, npc in ipairs(CollectionService:GetTagged(tag)) do
		if
			npc:IsA("BasePart")
			and npc:IsDescendantOf(workspace)
			and (npc.Position - root.Position).Magnitude <= range
		then
			return true
		end
	end
	return false
end

-- ── Столовая ─────────────────────────────────────────────────────────────────────────────────────────────────────

-- the cook's portion; check = the distance to the cook (off for QA)
local function portion(player: Player, check: boolean): string
	local profile = ProfileService.Get(player)
	if not profile or not ProfileService.IsReal(player) then
		return "not_ready"
	end
	if check and not nearTag(player, "CanteenCook", Config.daily.canteen.npcRangeStuds) then
		return "far"
	end
	local t = now()
	if not canteenOpen(t) then
		toast(player, "canteen_closed")
		return "closed"
	end
	local period = Daily.canteenPeriod(t)
	local food = Daily.portion
	local result = "given"
	ProfileService.Mutate(player, function(p)
		if p.canteen == period then
			result = "taken"
		elseif not InventoryService.canAdd(p, food.item, food.count) then
			result = "full"
		else
			InventoryService.add(p, food.item, food.count)
			p.canteen = period
		end
	end)
	if result == "taken" then
		toast(player, "canteen_already")
	elseif result == "full" then
		toast(player, "bag_full")
	else
		toast(player, "canteen_give")
	end
	return result
end

local function bindCook(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("CanteenPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CanteenPrompt"
	prompt.ActionText = Strings.t("canteen_prompt")
	prompt.ObjectText = Strings.t("spot_canteen")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false -- the tag sits inside the rig's torso
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part:IsDescendantOf(workspace) and not busy(player) then
			portion(player, true)
		end
	end)
end

-- the opening / closing lines on this server (chat + toast), never at the server start
local function watchCanteen()
	local wasOpen = canteenOpen(now())
	while true do
		task.wait(1)
		local open = canteenOpen(now())
		if open ~= wasOpen then
			wasOpen = open
			local key = if open then "canteen_open" else "canteen_close"
			ChatService.announce(key)
			for _, player in ipairs(Players:GetPlayers()) do
				toast(player, key)
			end
		end
	end
end

-- ── /daily ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function claim(player: Player): string
	local profile = ProfileService.Get(player)
	if not profile or not ProfileService.IsReal(player) then
		return "not_ready"
	end
	local t = now()
	local reward: Daily.Reward? = nil
	local result = "given"
	ProfileService.Mutate(player, function(p)
		local state = Daily.state(p, t)
		if state.claimed then
			result = "taken"
			return
		end
		local r = Daily.days[state.day]
		if not r then
			result = "taken"
			return
		end
		if r.item and not InventoryService.canAdd(p, r.item, r.count or 1) then
			result = "full"
			return
		end
		if r.booster and Boosters.storedCount(p) + 1 > Config.boosters.maxStored then
			result = "boosters_full"
			return
		end
		if r.money then
			p.coins += math.floor(r.money * Config.moneyScale + 0.5)
		elseif r.item then
			InventoryService.add(p, r.item, r.count or 1)
		elseif r.booster then
			Boosters.store(p, r.booster, "local", r.mult, r.minutes)
		end
		p.daily = { streak = Daily.streak(p, t) + 1, lastDay = Daily.dayIndex(t), lastAt = t }
		p.stats.dailyClaims = (p.stats.dailyClaims or 0) + 1
		reward = r
	end)
	if result == "taken" then
		toast(player, "daily_taken")
	elseif result == "full" then
		toast(player, "bag_full")
	elseif result == "boosters_full" then
		toast(player, "daily_boosters_full")
	elseif reward then
		local locale = Strings.localeOf(player)
		toast(player, "daily_received", Daily.rewardText(reward, locale))
		AchievementService.OnStat(player, "dailyClaims")
	end
	return result
end

local function bindDailyNpc(part: Instance)
	if not part:IsA("BasePart") or part:FindFirstChild("DailyPrompt") then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DailyPrompt"
	prompt.ActionText = Strings.t("daily_prompt")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		if part:IsDescendantOf(workspace) then
			Remotes.event("OpenMenu"):FireClient(player, "daily")
		end
	end)
end

-- ── QA ───────────────────────────────────────────────────────────────────────────────────────────────────────────

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "DailyDebug"
	hook.OnInvoke = function(op: string, a: any, b: any): any
		if op == "canteen" then
			forcedOpen = if a == "open" then true elseif a == "closed" then false else nil
			return canteenOpen(now())
		end
		local player = Players:GetPlayerByUserId(tonumber(a) or 0)
		local profile = if player then ProfileService.Get(player) else nil
		if not player or not profile then
			return false
		end
		if op == "reset" then
			ProfileService.Mutate(player, function(p)
				p.daily = nil
				p.canteen = nil
			end)
		elseif op == "shift" then
			local seconds = (tonumber(b) or 24) * 3600
			ProfileService.Mutate(player, function(p)
				local d = p.daily
				if d then
					d.lastAt -= seconds
					d.lastDay = Daily.dayIndex(d.lastAt)
				end
			end)
		elseif op == "claim" then
			return claim(player)
		elseif op == "portion" then
			return portion(player, false)
		end
		local p = ProfileService.Get(player) :: Types.Profile
		local t = now()
		return HttpService:JSONEncode({
			state = Daily.state(p, t),
			daily = p.daily,
			canteen = p.canteen,
			open = canteenOpen(t),
			claims = p.stats.dailyClaims or 0,
		})
	end
	hook.Parent = ServerStorage
end

function DailyService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("DailyClaim").OnServerEvent:Connect(function(player: Player)
		if busy(player) then
			return
		end
		local ok, err = pcall(claim, player)
		if not ok then
			warn("[DailyService] claim: " .. tostring(err))
		end
	end)
	for tag, bind in pairs({ CanteenCook = bindCook, DailyNpc = bindDailyNpc }) do
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bind(part)
		end
		CollectionService:GetInstanceAddedSignal(tag):Connect(bind)
	end
	task.spawn(watchCanteen)
	Players.PlayerRemoving:Connect(function(player)
		lastAction[player] = nil
	end)
	debugHook()
end

return DailyService
