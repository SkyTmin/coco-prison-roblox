--!strict
-- The player card of the TAB list and the chat (этап 9; docs/research/remaining-features-design.md, facts §3, §9)
-- [клиент chat.message.hover.user; вики MENUS-SOCIAL: «Фракция, Банда, Блоков, Крыс, Убийств, Смертей, Быстрые
-- действия с игроком»]. Level, faction, gang tag, nickname and PRIS+ are player attributes every client already has;
-- the numbers are asked here: RemoteFunction PlayerCard(userId) → { u, level, faction, gang = name?, tag?, color?,
-- nick?, pris, blocks, rats, kills, deaths, canInvite } or nil (not on this server / profile not loaded / too fast).
-- canInvite = the asker's gang (GangService, read only) lets his role invite and the other player has no gang; the
-- invite itself still goes through GangAction("invite", name) and GangService checks everything again.
-- QA (Studio): ServerStorage.PlayerCardDebug:Invoke(askerUserId, targetUserId) → the card as JSON (no rate limit).
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Gangs = require(Shared.Gangs)
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local GangService = require(script.Parent.GangService)
local ProfileService = require(script.Parent.ProfileService)

local PlayerCardService = {}
local started = false
local MIN_GAP = 0.25 -- [решение] s between two cards one player may ask for
local lastAsk: { [Player]: number } = {}

local function cardOf(asker: Player, target: Player): { [string]: any }?
	local p = ProfileService.Get(target)
	if not p then
		return nil
	end
	local gang = GangService.gangOf(p)
	local mine = if asker ~= target then GangService.gangOf(ProfileService.Get(asker)) else nil
	local canInvite = mine ~= nil
		and gang == nil
		and Gangs.can(Gangs.roleOf(mine, asker.UserId), "invite")
		and Gangs.memberCount(mine) < Gangs.slots(mine)
	local stats = p.stats or {}
	return {
		u = target.UserId,
		level = p.level,
		faction = p.faction,
		gang = if gang then gang.name else nil,
		tag = if gang then gang.tag else nil,
		color = if gang then gang.color else nil,
		nick = if typeof(p.nickname) == "string" and p.nickname ~= "" then p.nickname else nil,
		pris = PrisPlus.active(p),
		blocks = p.blocksTotal,
		rats = stats.rats or 0,
		kills = stats.kills or 0,
		deaths = stats.deaths or 0,
		canInvite = canInvite,
	}
end

local function query(player: Player, userId: any): any
	if typeof(userId) ~= "number" then
		return nil
	end
	if os.clock() - (lastAsk[player] or -math.huge) < MIN_GAP then
		return nil
	end
	lastAsk[player] = os.clock()
	local target = Players:GetPlayerByUserId(userId)
	if not target then
		return nil
	end
	return cardOf(player, target)
end

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "PlayerCardDebug"
	hook.OnInvoke = function(askerId: number, targetId: number): any
		local asker = Players:GetPlayerByUserId(askerId)
		local target = Players:GetPlayerByUserId(targetId)
		if not asker or not target then
			return false
		end
		local card = cardOf(asker, target)
		return if card then HttpService:JSONEncode(card) else false
	end
	hook.Parent = ServerStorage
end

function PlayerCardService.Start()
	if started then
		return
	end
	started = true
	Remotes.func("PlayerCard").OnServerInvoke = query
	Players.PlayerRemoving:Connect(function(player)
		lastAsk[player] = nil
	end)
	debugHook()
end

return PlayerCardService
