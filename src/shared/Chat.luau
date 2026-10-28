--!strict
-- The chat's shared rules (этап 3; ChatService on the server, ChatWindow on the client): the channel names, the
-- prefixes [клиент advice.48: «!» глобальный, «@» фракционный, «#» банды], cleaning a typed line, RichText escaping.
local Config = require(script.Parent.Config)

local Chat = {}

Chat.FOLDER = "CocoChat" -- TextChatService.CocoChat holds the faction and gang TextChannels
Chat.GENERAL = "RBXGeneral" -- Общий: Roblox's default channel, everyone on this server
Chat.TOPIC = "Chat_v1" -- MessagingService: global lines and announcements for every server

export type Kind = "local" | "global" | "faction" | "gang"
Chat.KINDS = { "local", "global", "faction", "gang" } :: { Kind }
local PREFIX: { [string]: Kind } = { ["!"] = "global", ["@"] = "faction", ["#"] = "gang" }

function Chat.factionChannel(id: string): string
	return "Faction_" .. id
end

function Chat.gangChannel(id: string): string
	return "Gang_" .. id
end

-- the tab a TextChannel's messages belong to (nil = not one of ours: whispers, RBXSystem)
function Chat.kindOfChannel(name: string): Kind?
	if name == Chat.GENERAL then
		return "local"
	elseif name:sub(1, 8) == "Faction_" then
		return "faction"
	elseif name:sub(1, 5) == "Gang_" then
		return "gang"
	end
	return nil
end

-- trims, drops control characters, cuts to Config.chat.maxLength characters (never inside a UTF-8 sequence)
function Chat.clean(text: string): string
	if not utf8.len(text) then
		return ""
	end
	local out = {}
	local n = 0
	for _, code in utf8.codes(text) do
		if code >= 32 and code ~= 127 then
			n += 1
			if n > Config.chat.maxLength then
				break
			end
			table.insert(out, utf8.char(code))
		end
	end
	return (table.concat(out):match("^%s*(.-)%s*$")) or ""
end

-- the channel a typed line goes to: a prefix wins over the open tab (the prefix itself is not sent)
function Chat.route(text: string, tab: Kind): (Kind, string)
	local kind = PREFIX[text:sub(1, 1)]
	if kind then
		return kind, (text:sub(2):match("^%s*(.-)$")) or ""
	end
	return tab, text
end

-- RichText-safe text; Roblox may hand chat text already escaped, so entities are undone first (never doubled)
function Chat.escape(text: string): string
	local plain = text:gsub("&lt;", "<")
		:gsub("&gt;", ">")
		:gsub("&quot;", '"')
		:gsub("&apos;", "'")
		:gsub("&amp;", "&")
	return (plain:gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"))
end

-- "/pay  Vasya 100" → "pay", {"Vasya", "100"} (the name in lower case)
function Chat.command(text: string): (string?, { string })
	local name = text:match("^/(%S+)")
	local args = {}
	if not name then
		return nil, args
	end
	for word in text:sub(#name + 2):gmatch("%S+") do
		table.insert(args, word)
		if #args >= 8 then
			break
		end
	end
	return name:lower(), args
end

return Chat
