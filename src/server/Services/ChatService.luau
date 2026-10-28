--!strict
-- The chat (docs/research/remaining-features-design.md, этап 3) on Roblox's own chat [владелец 28.10, вечер: «Давай
-- тогда переводить на чат в роблокс»; docs/research/mobile-chat-research.md §0: platform-integrated chat is required from
-- May 2027 — code never reads message text, custom UIs never draw messages]. Roblox draws and filters every message
-- in its default window (ChatWindow sets it up per player); the server owns only:
--   * Channels: Общий = RBXGeneral (Roblox's default, everyone on this server). Фракция and Банда = TextChannels under
--     TextChatService.CocoChat, one per faction / gang (attributes ChatKind = "faction" | "gang", ChatId = the id;
--     Name = Chat.FALLBACK_NAME, the client renames its copy into its language — the tab shows the Name). The server
--     keeps each player a TextSource (AddUserAsync) in his faction's and his gang's channel, moved when the player
--     attributes Faction / GangId change. Roblox applies the age / privacy settings, blocks and the region rules
--     itself (a player whose account may not chat gets no source or a read-only one — nothing works around it).
--   * System lines ChatSystem(text, kind) with kind "announce" | "reply" | "error" (the client shows them with
--     TextChannel:DisplaySystemMessage in RBXSystem): ChatService.announce* for everyone (this server or, via
--     MessagingService Chat_v1, every server), ChatService.reply / .fail for one player (command answers).
--   No player text crosses servers any more (the old «!» global chat was our own rendering).
-- QA (Studio): ServerStorage.ChatDebug:Invoke(op, …) — ("announce", key, …) this server; ("announceAll", key, …) every
-- server; ("members") → JSON "kind:id" → userIds; ("command", userId, text) runs a typed command (/pay, /gift, /hide …)
-- as that player through ChatCommandService → true when it was one.
local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)

local ChatService = {}
local MESSAGE_BYTES = 950 -- MessagingService takes ≤ 1 kB a message

type Member = { keys: { [string]: string? }, sources: { [string]: TextSource } }
local started = false
local folder: Folder? = nil
local channels: { [string]: TextChannel } = {} -- "faction:<id>" / "gang:<id>" → its channel
local members: { [Player]: Member } = {}

-- a command typed in the chat (ChatCommandService sets it): (player, text) → true when it was one of ours
ChatService.commandHandler = nil :: ((Player, string) -> boolean)?

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

local function channelFor(kind: Chat.Kind, id: string): TextChannel
	local key = kind .. ":" .. id
	local existing = channels[key]
	if existing and existing.Parent then
		return existing
	end
	local channel = Instance.new("TextChannel")
	channel.Name = Chat.FALLBACK_NAME[kind]
	channel:SetAttribute(Chat.KIND_ATTRIBUTE, kind)
	channel:SetAttribute(Chat.ID_ATTRIBUTE, id)
	channel.Parent = folder
	channels[key] = channel
	return channel
end

-- the player's TextSource in the channel of this kind: moved when his side changes; the add yields, so a stale answer
-- (left, changed sides again meanwhile) is undone
local function setChannel(player: Player, kind: Chat.Kind, id: string?)
	local m = members[player]
	local key = if id then kind .. ":" .. id else nil
	if not m or m.keys[kind] == key then
		return
	end
	m.keys[kind] = key
	local old = m.sources[kind]
	m.sources[kind] = nil
	if old then
		old:Destroy()
	end
	if not id then
		return
	end
	local channel = channelFor(kind, id)
	local ok, source = pcall(function()
		return (channel:AddUserAsync(player.UserId))
	end)
	if not ok then
		warn("[ChatService] AddUserAsync " .. kind .. ":" .. id .. ": " .. tostring(source))
		return
	end
	if not source then
		return -- Roblox refused (the account may not chat here): he reads nothing there either
	end
	if members[player] ~= m or m.keys[kind] ~= key then
		source:Destroy()
		return
	end
	local previous = m.sources[kind]
	if previous and previous ~= source then
		previous:Destroy()
	end
	m.sources[kind] = source
end

local function idOf(value: any): string?
	return if typeof(value) == "string" and value ~= "" then value else nil
end

local function sync(player: Player)
	task.spawn(setChannel, player, "faction", idOf(player:GetAttribute("Faction")))
	task.spawn(setChannel, player, "gang", idOf(player:GetAttribute("GangId")))
end

local function watch(player: Player)
	if members[player] then
		return
	end
	members[player] = { keys = {}, sources = {} }
	player:GetAttributeChangedSignal("Faction"):Connect(function()
		sync(player)
	end)
	player:GetAttributeChangedSignal("GangId"):Connect(function()
		sync(player)
	end)
	sync(player)
end

-- the channel the player talks in now ("faction" / "gang"), nil when he has none (the /f and /g commands)
function ChatService.channelOf(player: Player, kind: Chat.Kind): TextChannel?
	local m = members[player]
	local source = m and m.sources[kind]
	local channel = source and source.Parent
	return if channel and channel:IsA("TextChannel") then channel else nil
end

-- empty gang / faction channels go away (a minute later: an add may be on its way)
local function sweepChannels()
	for key, channel in pairs(channels) do
		if not channel.Parent then
			channels[key] = nil
		elseif not channel:FindFirstChildWhichIsA("TextSource") then
			if channel:GetAttribute("EmptySince") then
				channels[key] = nil
				channel:Destroy()
			else
				channel:SetAttribute("EmptySince", os.time())
			end
		else
			channel:SetAttribute("EmptySince", nil)
		end
	end
end

local function onMessage(message: any)
	local data = message and message.Data
	if typeof(data) ~= "table" or data.server == game.JobId then
		return
	end
	if data.ev == "say" and typeof(data.key) == "string" and Strings.has(data.key) then
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
		elseif op == "members" then
			local out = {}
			for key, channel in pairs(channels) do
				local ids = {}
				for _, source in ipairs(channel:GetChildren()) do
					if source:IsA("TextSource") then
						table.insert(ids, source.UserId)
					end
				end
				out[key] = ids
			end
			return HttpService:JSONEncode(out)
		elseif op == "command" then
			local player = Players:GetPlayerByUserId(a)
			local handler = ChatService.commandHandler
			return player ~= nil and handler ~= nil and handler(player, tostring((...)))
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
	-- the ChatVersion property can read LegacyChatService in a place where TextChatService runs anyway (legacy chat is
	-- retired), so the check is whether Roblox created its default channels
	task.delay(10, function()
		local defaults = TextChatService:FindFirstChild("TextChannels")
		if not (defaults and defaults:FindFirstChild(Chat.GENERAL)) then
			warn(
				"[ChatService] TextChatService.TextChannels."
					.. Chat.GENERAL
					.. " has not appeared 10 s after the start: the chat cannot work"
			)
		end
	end)
	local existing = TextChatService:FindFirstChild(Chat.FOLDER)
	if existing and existing:IsA("Folder") then
		folder = existing
	else
		local created = Instance.new("Folder")
		created.Name = Chat.FOLDER
		created.Parent = TextChatService
		folder = created
	end
	Remotes.event("ChatSystem")
	Players.PlayerAdded:Connect(watch)
	for _, player in ipairs(Players:GetPlayers()) do
		watch(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local m = members[player]
		members[player] = nil
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
