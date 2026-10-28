--!strict
-- PRIS+ on the server (этап 8; rules in Shared/PrisPlus, the window src/client/PrisWindow.luau, /pp and /mining):
--   * the player attribute PrisPlus (true / nil) follows p.prisPlusUntil once a second — the other clients read it for
--     the [PRIS+] chat prefix and the enchant particles; the end of a running PRIS+ is told with a toast;
--   * PrisQuery("mines") → { now, mines = { {id, location, left, cycle} } } — the «Респавн шахт» board [клиент
--     prison_plus.gui.*]: the timers live only on the server (MineService.timers), so only a PRIS+ player gets them,
--     at most once a second; the boss board reads ReplicatedStorage.Bosses on the client (BossService).
-- Bought in the donate shop (DonateService: pris_plus adds days, auction_no_fee). What it changes elsewhere:
-- AuctionService (10 slots, 0 %), ChatCommandService (/stats Ник, /rubb),
-- BookService (EnchantFx), the client (auto-dig, night, AppleSkin).
-- QA (Studio): ServerStorage.PrisDebug:Invoke(op, userId, n) — ("give", id, days) adds days (0 or less = ends now),
-- ("fee", id, true|false) the «Удаление комиссии», ("rubies", id, n) sets the rubies, ("state", id) → JSON.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local MineService = require(script.Parent.MineService)
local ProfileService = require(script.Parent.ProfileService)

local PrisService = {}
local started = false
local lastQuery: { [Player]: number } = {}
local wasActive: { [Player]: boolean } = {}

function PrisService.active(player: Player): boolean
	return PrisPlus.active(ProfileService.Get(player))
end

local function publish(player: Player)
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local on = PrisPlus.active(profile)
	player:SetAttribute(PrisPlus.ATTRIBUTE, if on then true else nil) -- the same value sends nothing
	if wasActive[player] and not on then
		Remotes.event("Toast"):FireClient(player, Strings.t("pris_ended", Strings.localeOf(player)))
	end
	wasActive[player] = on
end

local function query(player: Player, op: any): any
	local clock = os.clock()
	if clock - (lastQuery[player] or -math.huge) < 1 then
		return nil
	end
	lastQuery[player] = clock
	if op ~= "mines" or not PrisService.active(player) then
		return nil
	end
	return { now = workspace:GetServerTimeNow(), mines = MineService.timers() }
end

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "PrisDebug"
	hook.OnInvoke = function(op: string, userId: number, n: any): any
		local player = Players:GetPlayerByUserId(userId)
		if not player or not ProfileService.Get(player) then
			return false
		end
		if op == "give" then
			ProfileService.Mutate(player, function(p)
				if typeof(n) == "number" and n > 0 then
					PrisPlus.extend(p, n)
				else
					p.prisPlusUntil = nil
				end
			end)
			publish(player)
			return true
		elseif op == "fee" then
			ProfileService.Mutate(player, function(p)
				p.noAuctionFee = if n == true then true else nil
			end)
			return true
		elseif op == "rubies" and typeof(n) == "number" then
			ProfileService.Mutate(player, function(p)
				p.rubies = if n > 0 then math.floor(n) else nil
			end)
			return true
		elseif op == "state" then
			local p = ProfileService.Get(player) :: any
			return HttpService:JSONEncode({
				active = PrisPlus.active(p),
				left = PrisPlus.left(p),
				noFee = p.noAuctionFee == true,
				rubies = PrisPlus.rubies(p),
				commission = PrisPlus.commission(p),
				slots = PrisPlus.auctionSlots(p),
				attribute = player:GetAttribute(PrisPlus.ATTRIBUTE),
			})
		end
		return false
	end
	hook.Parent = ServerStorage
end

function PrisService.Start()
	if started then
		return
	end
	started = true
	Remotes.func("PrisQuery").OnServerInvoke = query
	Remotes.unreliable("EnchantFx") -- created up front so the clients can listen (BookService fires it)
	debugHook()
	Players.PlayerRemoving:Connect(function(player)
		lastQuery[player] = nil
		wasActive[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in ipairs(Players:GetPlayers()) do
				publish(player)
			end
			task.wait(1)
		end
	end)
end

return PrisService
