--!strict
-- Дворы: capturing the four faction points [клиент fraction.warzone.*; вики HANDBOOK-WIKI, CASES-ARTIFACTS-FACTIONS-
-- BOOSTERS; docs/research/remaining-features-design.md этап 2]. Rules shared with the client: Shared/Warzone.
--   * Every point is a beacon with a 5×5 pad of ore next to it (the mini-mine warzone_<point>, MineService restores
--     it). «Вскопайте блоки возле маяка» [клиент]: DigService calls OnDug for every block of a pad; the digger's
--     faction gets +1 capture point there, every other faction loses rivalLoss — a capture can be beaten back.
--     captureScore points capture it [решение 60]; with nobody digging for idleSeconds the scores melt.
--   * A captured point is held for holdMinutes [вики: «обновляется каждые 30 минут»], then it is free again.
--     While held, the owner's members on this server get +bonus to the point's kind (Boosters.runningAll) or
--     the point's effect (Спешка I until the hold ends, NeedsService.GiveEffect) [сеть TG/10].
--   * Everyone on the server hears the start of a capture, the capture and the release [клиент]. Each member who dug
--     at the beacon during the capture counts it in p.stats.warzonePoints («Взято точек», the Захватчик /
--     Штурмовик / Полководец achievements).
--   * Points belong to this server [решение]: the state lives in memory, mirrored to ReplicatedStorage.Warzone.
-- QA (Studio): ServerStorage.WarzoneDebug:Invoke(op, …) — ("capture", point, faction) capture now (credits nobody);
-- ("expire", point) end the hold in 1 s; ("score", point, faction, n) set a capture score; ("state") → JSON.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Warzone = require(Shared.Warzone)
local ProfileService = require(script.Parent.ProfileService)
local ChatService = require(script.Parent.ChatService) -- announcements in the chat (этап 3)
local FactionService = require(script.Parent.FactionService)
local NeedsService = require(script.Parent.NeedsService)
local AchievementService = require(script.Parent.AchievementService)

local WarzoneService = {}
local cfg = Warzone.cfg
local FREE_BEAM = Color3.fromRGB(235, 235, 245)

type PointState = {
	def: Warzone.Point,
	folder: Configuration,
	owner: string?,
	since: number,
	untilAt: number,
	scores: { [string]: number },
	diggers: { [string]: { [number]: boolean } }, -- faction → userIds who dug during this capture
	started: { [string]: boolean }, -- the start of this faction's capture was announced
	lastDigAt: number, -- os.clock()
	lastDecayAt: number,
}

local points: { [string]: PointState } = {}
local hasteGiven: { [Player]: number } = {} -- the hold end the player's Спешка already runs to
local started = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function factionName(id: string, locale: string): string
	return Strings.t("faction_" .. id, locale)
end

local function pointName(id: string, locale: string): string
	return Strings.t("warzone_point_" .. id, locale)
end

-- a message for every player on this server, each in his own language: build(locale) → the text
local function announce(build: (string) -> string)
	local toast = Remotes.event("Toast")
	for _, player in ipairs(Players:GetPlayers()) do
		toast:FireClient(player, build(Strings.localeOf(player)))
	end
	ChatService.announceWith(build) -- and in the chat [вики LOCATIONS-MENU: видел в чате]
end

local function mirror(point: PointState)
	local folder = point.folder
	folder:SetAttribute("Owner", point.owner or "")
	folder:SetAttribute("Since", point.since)
	folder:SetAttribute("Until", point.untilAt)
	folder:SetAttribute("Need", cfg.captureScore)
	for _, f in ipairs(Config.factions.list) do
		folder:SetAttribute("Score_" .. f.id, point.scores[f.id] or 0)
	end
end

-- the beacon beam in the owner's colour (white while free); the server has every part, StreamingEnabled or not
local function paintBeams(point: PointState)
	local color = if point.owner then Config.factionColor(point.owner) else FREE_BEAM
	for _, beam in ipairs(CollectionService:GetTagged(Warzone.BEAM_TAG)) do
		if beam:IsA("BasePart") and beam:GetAttribute("Point") == point.def.id then
			beam.Color = color
		end
	end
end

local function resetCapture(point: PointState)
	point.scores = {}
	point.diggers = {}
	point.started = {}
end

-- Спешка I for the owner's members on this server, the timer = what is left of the hold
local function giveHaste(point: PointState)
	if point.def.effect == nil or not point.owner then
		return
	end
	local left = point.untilAt - now()
	if left <= 1 then
		return
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if
			hasteGiven[player] ~= point.untilAt
			and player.Character
			and FactionService.Of(player) == point.owner
		then
			hasteGiven[player] = point.untilAt
			NeedsService.GiveEffect(player, point.def.effect, cfg.hasteLevel, left)
		end
	end
end

local function capture(point: PointState, faction: string, credit: boolean)
	local t = now()
	point.owner = faction
	point.since = t
	point.untilAt = t + cfg.holdMinutes * 60
	local diggers = if credit then point.diggers[faction] or {} else {}
	resetCapture(point)
	mirror(point)
	paintBeams(point)
	local id = point.def.id
	announce(function(locale)
		return Strings.t(
			"warzone_captured",
			locale,
			pointName(id, locale),
			factionName(faction, locale)
		)
	end)
	-- «Взято точек» for everyone of the faction who dug here during this capture and is still on the server
	for userId in pairs(diggers) do
		local player = Players:GetPlayerByUserId(userId)
		if player and ProfileService.Get(player) and FactionService.Of(player) == faction then
			ProfileService.Mutate(player, function(p)
				p.stats.warzonePoints = (p.stats.warzonePoints or 0) + 1
			end)
			AchievementService.OnStat(player, "warzonePoints")
		end
	end
	giveHaste(point)
end

local function release(point: PointState)
	point.owner = nil
	point.since = 0
	point.untilAt = 0
	resetCapture(point)
	mirror(point)
	paintBeams(point)
	local id = point.def.id
	announce(function(locale)
		return Strings.t("warzone_available", locale, pointName(id, locale))
	end)
end

-- DigService: a block of the mine `mineId` was dug by `player` (any mine; only the pads of the points count)
function WarzoneService.OnDug(player: Player, mineId: string)
	local def = Warzone.pointOfMine(mineId)
	local point = def and points[def.id]
	if not point or point.owner then
		return -- not a pad, or the point is held: nothing to capture until it is free again
	end
	local faction = FactionService.Of(player)
	if not faction then
		return
	end
	point.lastDigAt = os.clock()
	for f, score in pairs(point.scores) do
		if f ~= faction then
			point.scores[f] = math.max(0, score - cfg.rivalLoss)
		end
	end
	point.scores[faction] = (point.scores[faction] or 0) + 1
	local diggers = point.diggers[faction] or {}
	point.diggers[faction] = diggers
	diggers[player.UserId] = true
	if not point.started[faction] then
		point.started[faction] = true
		local id = point.def.id
		announce(function(locale)
			return Strings.t(
				"warzone_capture_started",
				locale,
				factionName(faction, locale),
				pointName(id, locale)
			)
		end)
	end
	if point.scores[faction] >= cfg.captureScore then
		capture(point, faction, true)
	else
		mirror(point)
	end
end

local function tick()
	local t = now()
	local clock = os.clock()
	for _, point in pairs(points) do
		if point.owner then
			if t >= point.untilAt then
				release(point)
			else
				giveHaste(point)
			end
		elseif
			clock - point.lastDigAt >= cfg.idleSeconds
			and clock - point.lastDecayAt >= cfg.decayEverySeconds
			and next(point.scores) ~= nil
		then
			-- nobody digs here any more: the scores melt; a faction at 0 starts over (announced again)
			point.lastDecayAt = clock
			for f, score in pairs(point.scores) do
				if score <= 1 then
					point.scores[f] = nil
					point.diggers[f] = nil
					point.started[f] = nil
				else
					point.scores[f] = score - 1
				end
			end
			mirror(point)
		end
	end
end

local function debugApi(op: any, a: any, b: any, c: any): any
	local point = if typeof(a) == "string" then points[a] else nil
	if op == "capture" and point and Config.faction(b) then
		capture(point, b, false)
		return true
	elseif op == "expire" and point and point.owner then
		point.untilAt = now() + 1
		mirror(point)
		return true
	elseif op == "score" and point and Config.faction(b) and typeof(c) == "number" then
		point.scores[b] = math.max(0, math.floor(c))
		point.lastDigAt = os.clock()
		mirror(point)
		return true
	elseif op == "state" then
		local out = {}
		for id, p in pairs(points) do
			out[id] = {
				owner = p.owner,
				left = if p.owner then math.floor(p.untilAt - now()) else 0,
				scores = p.scores,
			}
		end
		return HttpService:JSONEncode(out)
	end
	return false
end

function WarzoneService.Start()
	if started then
		return
	end
	started = true
	local root = ReplicatedStorage:FindFirstChild(Warzone.FOLDER)
	if not root then
		local folder = Instance.new("Folder")
		folder.Name = Warzone.FOLDER
		folder.Parent = ReplicatedStorage
		root = folder
	end
	for _, def in ipairs(Warzone.points) do
		local folder = Instance.new("Configuration")
		folder.Name = def.id
		folder.Parent = root
		local point: PointState = {
			def = def,
			folder = folder,
			owner = nil,
			since = 0,
			untilAt = 0,
			scores = {},
			diggers = {},
			started = {},
			lastDigAt = 0,
			lastDecayAt = 0,
		}
		points[def.id] = point
		mirror(point)
	end
	-- beams built after the start (the map script run in a live server) get their colour too
	CollectionService:GetInstanceAddedSignal(Warzone.BEAM_TAG):Connect(function(beam)
		local point = points[beam:GetAttribute("Point") :: any]
		if point then
			paintBeams(point)
		end
	end)
	for _, point in pairs(points) do
		paintBeams(point)
	end
	Players.PlayerRemoving:Connect(function(player)
		hasteGiven[player] = nil
	end)
	if RunService:IsStudio() then
		local api = Instance.new("BindableFunction")
		api.Name = "WarzoneDebug"
		api.OnInvoke = debugApi
		api.Parent = ServerStorage
	end
	task.spawn(function()
		while true do
			task.wait(1)
			tick()
		end
	end)
end

return WarzoneService
