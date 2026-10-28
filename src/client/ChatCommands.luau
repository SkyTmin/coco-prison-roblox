--!strict
-- The client part of the chat commands (этап 3; every command is a server TextChatCommand since the move to Roblox's
-- own chat — ChatCommandService). The server sends ChatClient(action, …) for what needs this client:
--   * "teleport" location spot? — /spawn, /warzone through the usual Teleport remote (LocationService checks it);
--   * "gang" sub arg — /gang invite ник | leave | deposit N | withdraw N | home through GangAction / GangHome
--     (GangService / GangHouseService check everything);
--   * "channel" TextChannel? — /f, /g, /l: Roblox's input bar writes into that channel (nil = Общий), the tab follows.
-- Window commands come as OpenMenu(kind) (init.client).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Remotes = require(Shared.Remotes)

local ChatCommands = {}

local function general(): TextChannel?
	local folder = TextChatService:FindFirstChild("TextChannels")
	local channel = folder and folder:FindFirstChild(Chat.GENERAL)
	return if channel and channel:IsA("TextChannel") then channel else nil
end

function ChatCommands.start()
	Remotes.event("ChatClient").OnClientEvent:Connect(function(action: any, a: any, b: any)
		if action == "teleport" and typeof(a) == "string" then
			if typeof(b) == "string" then
				Remotes.event("Teleport"):FireServer(a, b)
			else
				Remotes.event("Teleport"):FireServer(a)
			end
		elseif action == "gang" and typeof(a) == "string" then
			if a == "home" then
				Remotes.event("GangHome"):FireServer()
			elseif a == "leave" then
				Remotes.event("GangAction"):FireServer("leave")
			else
				Remotes.event("GangAction"):FireServer(a, b)
			end
		elseif action == "channel" then
			local target = if typeof(a) == "Instance" and a:IsA("TextChannel") then a else general()
			pcall(function()
				TextChatService.ChatInputBarConfiguration.TargetTextChannel = target
			end)
		end
	end)
end

return ChatCommands
