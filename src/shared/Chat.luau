--!strict
-- The chat's shared names (этап 3; moved to Roblox's own chat 28.10 [владелец 28.10: «Давай тогда переводить на чат в
-- роблокс»], docs/research/mobile-chat-research.md §0): Roblox draws every message (its default window with channel
-- tabs); we own only the faction / gang TextChannels, the server TextChatCommands and the system lines.
local Chat = {}

Chat.FOLDER = "CocoChat" -- TextChatService.CocoChat holds the faction and gang TextChannels
Chat.COMMANDS = "CocoCommands" -- TextChatService.CocoCommands holds our TextChatCommands (ChatCommandService)
Chat.GENERAL = "RBXGeneral" -- Общий: Roblox's default channel, everyone on this server («Here» tab)
Chat.SYSTEM = "RBXSystem" -- system lines (shown in the General tab)
Chat.TOPIC = "Chat_v1" -- MessagingService: announcements for every server

export type Kind = "faction" | "gang"
-- a channel's tab shows its Name: the server names them in English (the fallback), the client renames its copy into
-- its language before its TextSource arrives (ChatWindow); the side's id lives in the attributes
Chat.KIND_ATTRIBUTE = "ChatKind" -- "faction" | "gang"
Chat.ID_ATTRIBUTE = "ChatId" -- the faction id / the gang id
Chat.FALLBACK_NAME = { faction = "Faction", gang = "Gang" } :: { [Kind]: string }
Chat.TAB_KEY = { faction = "chat_tab_faction", gang = "chat_tab_gang" } :: { [Kind]: string }

-- RichText-safe text; entities are undone first (never doubled)
function Chat.escape(text: string): string
	local plain = text:gsub("&lt;", "<")
		:gsub("&gt;", ">")
		:gsub("&quot;", '"')
		:gsub("&apos;", "'")
		:gsub("&amp;", "&")
	return (plain:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- "/pay  Vasya 100" → "pay", {"Vasya", "100"} (the name in lower case); at most 8 arguments
function Chat.command(text: string): (string?, { string })
	local name = text:match("^%s*/(%S+)")
	local args = {}
	if not name then
		return nil, args
	end
	local rest = text:match("^%s*/%S+(.*)$") or ""
	for word in rest:gmatch("%S+") do
		table.insert(args, word)
		if #args >= 8 then
			break
		end
	end
	return name:lower(), args
end

return Chat
