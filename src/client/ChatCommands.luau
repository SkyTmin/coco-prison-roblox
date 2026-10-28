--!strict
-- Chat commands (этап 3) [вики HANDBOOK-WIKI «Команды»; клиент wiki.short, advice.*; сеть TG/15: /balance, /blocks].
-- Windows open here (the same windows as the keys and the menu), teleports go through the usual Teleport remote,
-- the gang ones through GangAction / GangHome (GangService checks everything); /pay, /gift and /thx are the server's
-- (ChatCommand → ChatCommandService). /hide is a command and a settings switch, not the original's H — H is the HUD
-- editor here. The commands of systems that are not built yet answer «скоро».
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Chat = require(Shared.Chat)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Warzone = require(Shared.Warzone)

export type Context = {
	open: (kind: string) -> (),
	profile: () -> Types.Profile?,
	locale: () -> string,
	say: (text: string, kind: string?) -> (),
	toggleHide: () -> boolean, -- → hidden now
}

local ChatCommands = {}

-- command → the window kind of init.client windowBuilders
local WINDOWS: { [string]: string } = {
	menu = "menu",
	ah = "auction",
	auction = "auction",
	potion = "potions",
	potions = "potions",
	skills = "skills",
	fraction = "factions",
	frac = "factions",
	donate = "donate",
	settings = "settings",
	booster = "boosters",
	boosters = "boosters",
	mines = "locations",
	up = "upgrade",
	upgrade = "upgrade",
	level = "level",
	achievements = "achievements",
	artifacts = "artifacts",
	rubbish = "rubbish",
	daily = "daily", -- «Ежедневные награды» (DailyWindow, этап 7)
}
local SERVER = { pay = true, gift = true, thx = true }
-- PRIS+ (этап 8), рубины, клички (этап 9), автопродажа из меню, вики, гайд: not built yet
local SOON = {
	pp = true,
	mining = true,
	rubb = true,
	titles = true,
	names = true,
	nickname = true,
	autosell = true,
	wiki = true,
	quests = true,
	skipguide = true,
}

local function gang(args: { string }, ctx: Context, T: (string, ...any) -> string)
	local sub = args[1] and args[1]:lower()
	local amount = tonumber(args[2] and (args[2]:gsub(",", ".")) or nil)
	if not sub then
		ctx.open("gangs")
	elseif sub == "invite" and args[2] then
		Remotes.event("GangAction"):FireServer("invite", args[2])
	elseif sub == "leave" then
		Remotes.event("GangAction"):FireServer("leave")
	elseif (sub == "deposit" or sub == "withdraw") and amount and amount > 0 then
		Remotes.event("GangAction"):FireServer(sub, amount)
	elseif sub == "home" then
		Remotes.event("GangHome"):FireServer()
	else
		ctx.say(T("chat_gang_usage"), "reply")
	end
end

function ChatCommands.run(text: string, ctx: Context)
	local locale = ctx.locale()
	local function T(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local name, args = Chat.command(text)
	if not name then
		return
	end
	local profile = ctx.profile()
	local me = Players.LocalPlayer
	if WINDOWS[name] then
		ctx.open(WINDOWS[name])
	elseif SERVER[name] then
		Remotes.event("ChatCommand"):FireServer(name, args)
	elseif name == "help" or name == "commands" then
		ctx.say(T("chat_help"), "reply")
	elseif name == "spawn" then
		-- at the prison already: to its spawn spot; elsewhere: the trip to the prison lands on the spawn
		if profile and profile.location == "prison" then
			Remotes.event("Teleport"):FireServer("prison", "spawn")
		else
			Remotes.event("Teleport"):FireServer("prison")
		end
	elseif name == "warzone" then
		Remotes.event("Teleport"):FireServer(Warzone.LOCATION)
	elseif name == "hide" then
		ctx.say(T(if ctx.toggleHide() then "chat_hide_on" else "chat_hide_off"), "reply")
	elseif name == "gang" then
		gang(args, ctx, T)
	elseif
		not profile and (name == "balance" or name == "bal" or name == "blocks" or name == "stats")
	then
		ctx.say(T("chat_not_ready"), "error")
	elseif profile and (name == "balance" or name == "bal" or name == "money") then
		ctx.say(T("chat_balance", Strings.money(profile.coins), profile.crystals or 0), "reply")
	elseif profile and name == "blocks" then
		ctx.say(T("chat_blocks", Strings.big(profile.blocksTotal)), "reply")
	elseif profile and name == "stats" then
		local who = args[1] and Strings.lower(args[1])
		if who and who ~= Strings.lower(me.Name) and who ~= Strings.lower(me.DisplayName) then
			ctx.say(T("chat_stats_other"), "reply") -- [клиент] another player's stats need PRIS+ (этап 8)
			return
		end
		local stats = profile.stats
		ctx.say(
			T(
				"chat_stats",
				profile.level,
				Strings.big(profile.blocksTotal),
				stats.rats or 0,
				stats.kills or 0,
				stats.deaths or 0
			),
			"reply"
		)
	elseif SOON[name] then
		ctx.say(T("chat_soon"), "reply")
	else
		ctx.say(T("chat_unknown_command", "/" .. name), "error")
	end
end

return ChatCommands
