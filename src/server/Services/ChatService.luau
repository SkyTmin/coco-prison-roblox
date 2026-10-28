--!strict
-- The chat (docs/research/remaining-features-design.md, этап 3) [владелец 28.10: «у нас вообще никакого чата нет,
-- надо не только фракционный чат делать»]. Our own window (src/client/ChatWindow.luau) over TextChatService:
--   * Общий = RBXGeneral (Roblox's default channel, everyone on this server). Фракция «@» = TextChannel
--     Faction_<id>, Банда «#» = TextChannel Gang_<gangId>, both under TextChatService.CocoChat: the server keeps each
--     player a TextSource of his faction's and his gang's channel (player attributes Faction / GangId). Roblox filters
--     these messages for every receiver and applies the age / privacy settings and blocks itself; the client sends
--     with TextChannel:SendAsync and draws what TextChatService.MessageReceived hands it.
--   * Глобальный «!» [клиент advice.48] crosses servers: ChatGlobal(text) → the account may chat (CanUserChatAsync,
--     attribute ChatAllowed), one line per Config.chat.globalCooldownSeconds, TextService:FilterStringAsync
--     (PublicChat) → GetNonChatStringForBroadcastAsync (the strictest result: a receiver on another server has no
--     filter result of his own) → this server's players and MessagingService Chat_v1 → the other servers. A receiver
--     gets it only when TextChatService:CanUsersChatAsync(sender, receiver) allows (cached for PAIR_TTL).
--   * System lines ChatSystem(text, kind) with kind "announce" | "reply" | "error": ChatService.announce* for
--     everyone (this server or all of them), ChatService.reply / .fail for one player (command answers).
-- QA (Studio): ServerStorage.ChatDebug:Invoke(op, …) — ("announce", key, …) this server; ("announceAll", key, …) every
-- server; ("global", userId, text) a global line from that player without the cooldown → the filtered text or nil;
-- ("members") → JSON channel name → userIds; ("allowed", userId) → the ChatAllowed attribute; ("command", userId,
-- text) runs a typed server command (/pay, /gift, /thx) as that player → true when it was one.
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)

local ChatService = {}
local cfg = Config.chat
local PAIR_TTL = 300 -- [решение] s a CanUsersChatAsync answer is trusted
local PAIR_CAP = 5000 -- cached answers before the cache is dropped
local MESSAGE_BYTES = 950 -- MessagingService takes ≤ 1 kB a message

type Member = { names: { [string]: string? }, sources: { [string]: TextSource } }
local started = false
local folder: Folder? = nil
local members: { [Player]: Member } = {}
local lastGlobal: { [Player]: number } = {}
local pairCache: { [string]: { allowed: boolean, at: number } } = {}
local pairCount = 0

-- a server command typed in the chat (ChatCommandService sets it): (player, name, args) → true when it was one
ChatService.commandHandler = nil :: ((Player, string, { string }) -> boolean)?

-- ── system lines ────────────────────────────────────────────────────────────────────────────────────────────────

function ChatService.system(player: Player, text: string, kind: string?)
	Remotes.event("ChatSystem"):FireClient(player, text, kind or "reply")
end

function ChatService.reply(player: Player, key: string, ...: any)
	ChatService.system(player, Strings.t(key, Strings.localeOf(player), ...), "reply")
end

function ChatService.fail(player: Player, key: string, ...: any)
	ChatService.system(player, Strings.t(key, Strings.localeOf(player), ...), "error")
end

-- a line for everyone on this server, each in his own language: build(locale) → the text
function ChatService.announceWith(build: (string) -> string)
	for _, player in ipairs(Players:GetPlayers()) do
		ChatService.system(player, build(Strings.localeOf(player)), "announce")
	end
end

function ChatService.announce(key: string, ...: any)
	local args = table.pack(...)
	ChatService.announceWith(function(locale)
		return Strings.t(key, locale, table.unpack(args, 1, args.n))
	end)
end

local function publish(data: { [string]: any })
	data.server = game.JobId
	local ok, json = pcall(HttpService.JSONEncode, HttpService, data)
	if not ok or #json > MESSAGE_BYTES then
		return
	end
	task.spawn(function()
		local sent, err = pcall(function()
			MessagingService:PublishAsync(Chat.TOPIC, data)
		end)
		if not sent and not RunService:IsStudio() then
			warn("[ChatService] publish: " .. tostring(err))
		end
	end)
end

-- every server: the args are plain strings / numbers (each server puts them into its players' languages)
function ChatService.announceAll(key: string, ...: any)
	local args = { ... }
	ChatService.announce(key, ...)
	publish({ ev = "say", key = key, args = args })
end

-- ── channels ────────────────────────────────────────────────────────────────────────────────────────────────────

local function channelFor(name: string): TextChannel
	local parent = folder :: Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("TextChannel") then
		return existing
	end
	local channel = Instance.new("TextChannel")
	channel.Name = name
	channel.Parent = parent
	return channel
end

-- the player's TextSource in the channel of this slot ("faction" / "gang"): moved when his side changes; the add
-- yields, so a stale answer (left, changed sides again meanwhile) is undone
local function setChannel(player: Player, slot: string, name: string?)
	local m = members[player]
	if not m or m.names[slot] == name then
		return
	end
	m.names[slot] = name
	local old = m.sources[slot]
	m.sources[slot] = nil
	if old then
		old:Destroy()
	end
	if not name then
		return
	end
	local channel = channelFor(name)
	local ok, source = pcall(function()
		return (channel:AddUserAsync(player.UserId))
	end)
	if not ok then
		warn("[ChatService] AddUserAsync " .. name .. ": " .. tostring(source))
		return
	end
	if not source then
		return -- Roblox refused (the account may not chat): he reads nothing there either
	end
	if members[player] ~= m or m.names[slot] ~= name then
		source:Destroy()
		return
	end
	local previous = m.sources[slot]
	if previous and previous ~= source then
		previous:Destroy()
	end
	m.sources[slot] = source
end

local function sync(player: Player)
	local faction = player:GetAttribute("Faction")
	local gang = player:GetAttribute("GangId")
	task.spawn(
		setChannel,
		player,
		"faction",
		if typeof(faction) == "string" and faction ~= "" then Chat.factionChannel(faction) else nil
	)
	task.spawn(
		setChannel,
		player,
		"gang",
		if typeof(gang) == "string" and gang ~= "" then Chat.gangChannel(gang) else nil
	)
end

-- may this account chat at all (age / parental settings): the attribute the client and the global chat read
local checking: { [Player]: boolean } = {}
local function checkAllowed(player: Player)
	if checking[player] then
		return
	end
	checking[player] = true
	for attempt = 1, 3 do
		local ok, allowed = pcall(function()
			return TextChatService:CanUserChatAsync(player.UserId)
		end)
		if ok then
			player:SetAttribute("ChatAllowed", allowed == true)
			checking[player] = nil
			return
		end
		task.wait(2 * attempt)
	end
	checking[player] = nil
	if RunService:IsStudio() then
		player:SetAttribute("ChatAllowed", true) -- the call needs a live server
	end
end

local function watch(player: Player)
	if members[player] then
		return
	end
	members[player] = { names = {}, sources = {} }
	task.spawn(checkAllowed, player)
	player:GetAttributeChangedSignal("Faction"):Connect(function()
		sync(player)
	end)
	player:GetAttributeChangedSignal("GangId"):Connect(function()
		sync(player)
	end)
	sync(player)
end

-- empty gang / faction channels go away (a minute later: an add may be on its way)
local function sweepChannels()
	for _, channel in ipairs((folder :: Folder):GetChildren()) do
		if channel:IsA("TextChannel") and not channel:FindFirstChildWhichIsA("TextSource") then
			if channel:GetAttribute("EmptySince") then
				channel:Destroy()
			else
				channel:SetAttribute("EmptySince", os.time())
			end
		elseif channel:IsA("TextChannel") then
			channel:SetAttribute("EmptySince", nil)
		end
	end
end

-- ── the global chat ─────────────────────────────────────────────────────────────────────────────────────────────

local function mayRead(from: number, to: number): boolean
	if from == to then
		return true
	end
	local key = from .. ":" .. to
	local cached = pairCache[key]
	if cached and os.clock() - cached.at < PAIR_TTL then
		return cached.allowed
	end
	local ok, allowed = pcall(function()
		return TextChatService:CanUsersChatAsync(from, to)
	end)
	if not ok then
		return RunService:IsStudio() -- unknown on a live server: not shown
	end
	if pairCount >= PAIR_CAP then
		table.clear(pairCache)
		pairCount = 0
	end
	if not cached then
		pairCount += 1
	end
	pairCache[key] = { allowed = allowed == true, at = os.clock() }
	return allowed == true
end

-- a filtered global line → every player on this server who may read the sender
local function deliverGlobal(data: { [string]: any })
	local remote = Remotes.event("ChatGlobal")
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("ChatAllowed") ~= false then
			task.spawn(function()
				if mayRead(data.u, player.UserId) and player.Parent then
					remote:FireClient(player, data)
				end
			end)
		end
	end
end

-- (sent, the filtered text or the Strings key of the refusal)
local function sendGlobal(player: Player, raw: any, skipCooldown: boolean?): (boolean, string)
	if typeof(raw) ~= "string" then
		return false, "chat_send_failed"
	end
	local text = Chat.clean(raw)
	if text == "" then
		return false, "chat_send_failed"
	end
	local allowed = player:GetAttribute("ChatAllowed")
	if allowed == false then
		return false, "chat_unavailable"
	end
	local profile = ProfileService.Get(player)
	if allowed ~= true or not profile then
		if allowed == nil then
			task.spawn(checkAllowed, player) -- Roblox did not answer at the join: ask again
		end
		return false, "chat_not_ready"
	end
	local since = os.clock() - (lastGlobal[player] or -math.huge)
	if not skipCooldown and since < cfg.globalCooldownSeconds then
		return false, "chat_global_wait"
	end
	lastGlobal[player] = os.clock()
	local ok, result = pcall(function()
		local filtered =
			TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
		return filtered:GetNonChatStringForBroadcastAsync()
	end)
	if not ok or typeof(result) ~= "string" or result == "" then
		lastGlobal[player] = nil
		return false, "chat_filter_failed"
	end
	local faction = player:GetAttribute("Faction")
	local data = {
		ev = "global",
		u = player.UserId,
		n = player.DisplayName,
		l = profile.level,
		f = if typeof(faction) == "string" then faction else "",
		g = player:GetAttribute("GangTag") or "",
		c = player:GetAttribute("GangColor") or 0,
		k = if typeof(profile.nickname) == "string" then profile.nickname else "",
		t = result,
	}
	deliverGlobal(data)
	publish(data)
	return true, result
end

local function onGlobal(player: Player, raw: any)
	local ok, result = sendGlobal(player, raw)
	if not ok then
		if result == "chat_global_wait" then
			local left = cfg.globalCooldownSeconds - (os.clock() - (lastGlobal[player] or 0))
			ChatService.fail(
				player,
				result,
				cfg.globalCooldownSeconds,
				math.max(1, math.ceil(left))
			)
		else
			ChatService.fail(player, result)
		end
	end
end

local function onMessage(message: any)
	local data = message and message.Data
	if typeof(data) ~= "table" or data.server == game.JobId then
		return
	end
	if data.ev == "global" then
		if
			typeof(data.u) == "number"
			and typeof(data.t) == "string"
			and #data.t <= cfg.maxLength * 4
			and typeof(data.n) == "string"
		then
			deliverGlobal(data)
		end
	elseif data.ev == "say" and typeof(data.key) == "string" and Strings.has(data.key) then
		local args = if typeof(data.args) == "table" then data.args else {}
		pcall(ChatService.announce, data.key, table.unpack(args)) -- a bad argument list never stops the loop
	end
end

-- ── start ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "ChatDebug"
	hook.OnInvoke = function(op: string, a: any, ...: any): any
		if op == "announce" then
			ChatService.announce(a, ...)
			return true
		elseif op == "announceAll" then
			ChatService.announceAll(a, ...)
			return true
		elseif op == "global" then
			local player = Players:GetPlayerByUserId(a)
			if not player then
				return nil
			end
			local ok, result = sendGlobal(player, (...), true)
			return if ok then result else nil
		elseif op == "members" then
			local out = {}
			for _, channel in ipairs((folder :: Folder):GetChildren()) do
				local ids = {}
				for _, source in ipairs(channel:GetChildren()) do
					if source:IsA("TextSource") then
						table.insert(ids, source.UserId)
					end
				end
				out[channel.Name] = ids
			end
			return HttpService:JSONEncode(out)
		elseif op == "allowed" then
			local player = Players:GetPlayerByUserId(a)
			return if player then player:GetAttribute("ChatAllowed") else nil
		elseif op == "command" then
			local player = Players:GetPlayerByUserId(a)
			local name, args = Chat.command(tostring((...)))
			local handler = ChatService.commandHandler
			return player ~= nil and name ~= nil and handler ~= nil and handler(player, name, args)
		end
		return nil
	end
	hook.Parent = ServerStorage
end

function ChatService.Start()
	if started then
		return
	end
	started = true
	if TextChatService.ChatVersion ~= Enum.ChatVersion.TextChatService then
		warn(
			"[ChatService] TextChatService.ChatVersion is not TextChatService: the chat needs it "
				.. "(docs/research/floors-evening-checklist.md, этап 3)"
		)
	end
	local existing = TextChatService:FindFirstChild(Chat.FOLDER)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = Chat.FOLDER
		created.Parent = TextChatService
		folder = created
	end
	Remotes.event("ChatGlobal").OnServerEvent:Connect(onGlobal)
	Remotes.event("ChatSystem")
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local m = members[player]
		members[player] = nil
		lastGlobal[player] = nil
		checking[player] = nil
		if m then
			for _, source in pairs(m.sources) do
				source:Destroy()
			end
		end
	end)
	task.spawn(function()
		pcall(function()
			MessagingService:SubscribeAsync(Chat.TOPIC, onMessage)
		end)
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			pcall(sweepChannels)
		end
	end)
	debugHook()
end

return ChatService
