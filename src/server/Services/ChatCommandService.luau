--!strict
-- Every chat command (этап 3; moved to Roblox's own chat 28.10 [владелец 28.10: «Давай тогда переводить на чат в
-- роблокс»]): platform-integrated chat lets code see a typed line only through a TextChatCommand, so each command is a
-- server TextChatCommand under TextChatService.CocoCommands (Primary/SecondaryAlias; more aliases = more instances).
-- Triggered(textSource, text) runs here; Roblox never sends a matched command to the chat. Answers are system lines
-- (ChatService.reply / .fail). Windows open on the client through OpenMenu(kind); teleports, the gang subcommands and
-- the channel switch go back to the client as ChatClient(action, …), so the usual remotes (Teleport, GangAction,
-- GangHome — their services check everything) and the input bar (TargetTextChannel) do the rest.
--   * /pay ник сумма [клиент pay.*]: from 1 $, not to yourself, the receiver may refuse transfers in the settings
--     (settings.payOff). Both players must be on this server with real profiles (a transfer to another server or an
--     offline player is refused: it would need an outside outbox). The check and both Mutates run without a yield
--     in between, so nothing can spend the money twice; then the sender is saved first and the receiver next — a
--     crash between the two saves loses the transfer at worst, it never doubles it.
--   * /gift ник [клиент gift.*; сеть TG/25]: the whole stack in the hand, never a block, not a Config.chat.giftForbidden
--     item; the receiver on the same location within giftRangeBlocks, accepting gifts (settings.giftOff), with room;
--     on the База банды only to your own gang [клиент gift.error.gang]. The stack moves whole (books, potions, level).
--   * /thx [клиент booster.thx*]: for every running faction / global / gang booster of someone else that applies to
--     you and you have not thanked yet (p.thanked), you and its owner (when he is on this server) get
--     100 $ × your level / 10 [решение: Config.chat.thxPerLevel]; once per booster.
--   * /rubb ник N [вики; клиент pay.rubies.*] (этап 8): whole rubies from Config.pris.rubbMin, the same rules and saves
--     as /pay (the receiver's «Переводы» switch refuses rubies too).
--   * /stats [ник] [сеть S6] (этап 8): your own numbers; another player's (on this server) only for a PRIS+ player.
--   * /balance, /blocks, /hide (settings.hidePlayers; H is the HUD editor here), /help, /spawn, /warzone, /gang …, the
--     window commands [вики HANDBOOK-WIKI «Команды»; клиент wiki.short, advice.*; сеть TG/15], /f /g /l — write in the
--     faction / gang / general channel (like Roblox's /team). The commands of systems not built yet answer «скоро».
--     Roblox's own /help is switched off: ours lists our commands and Roblox's /w, /mute.
-- Under platform-integrated chat `text` may come empty (undocumented): a command with arguments then answers with its
-- usage line — the owner checks /pay with the setting on (docs/research/floors-evening-checklist.md).
-- Players Roblox does not let chat (the region, age, parental settings) cannot type commands at all: every command has
-- a button too (menu tiles, the player card, Settings).
-- Rubbish(list) — «Урна» [клиент garbage.*] closed: list = { {slot, id, count} }; the stacks that still match go away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Chat = require(Shared.Chat)
local Config = require(Shared.Config)
local PrisPlus = require(Shared.PrisPlus)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local Warzone = require(Shared.Warzone)
local ChatService = require(script.Parent.ChatService)
local InventoryService = require(script.Parent.InventoryService)
local ProfileService = require(script.Parent.ProfileService)

local ChatCommandService = {}
local cfg = Config.chat
local started = false
local lastCommand: { [Player]: number } = {}

local function units(dollars: number): number
	return math.floor(dollars * Config.moneyScale + 0.5)
end

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local out = {}
	for key, item in pairs(value) do
		out[key] = deepCopy(item)
	end
	return out
end

-- a player on this server by his user name or display name: exact first (any case), then a unique beginning
local function findPlayer(query: string): (Player?, string?)
	local wanted = Strings.lower(query)
	local starts = {}
	for _, other in ipairs(Players:GetPlayers()) do
		local name, display = Strings.lower(other.Name), Strings.lower(other.DisplayName)
		if name == wanted or display == wanted then
			return other, nil
		end
		if name:sub(1, #wanted) == wanted or display:sub(1, #wanted) == wanted then
			table.insert(starts, other)
		end
	end
	if #starts == 1 then
		return starts[1], nil
	end
	return nil, if #starts > 1 then "chat_player_ambiguous" else "chat_player_not_found"
end

-- the receiver of /pay or /gift with the common checks; nil after telling the sender why
local function receiver(player: Player, query: string?, selfKey: string): (Player?, Types.Profile?)
	if not query then
		return nil, nil
	end
	local target, err = findPlayer(query)
	if not target then
		ChatService.fail(player, err :: string, query)
		return nil, nil
	end
	if target == player then
		ChatService.fail(player, selfKey)
		return nil, nil
	end
	local profile = ProfileService.Get(target)
	if not profile or not ProfileService.IsReal(target) then
		ChatService.fail(player, "chat_player_not_found", query)
		return nil, nil
	end
	return target, profile
end

local function saveBoth(first: Player, second: Player)
	task.spawn(function()
		ProfileService.SaveNow(first)
		ProfileService.SaveNow(second)
	end)
end

-- ── /pay ────────────────────────────────────────────────────────────────────────────────────────────────────────

local function pay(player: Player, args: { string })
	local profile = ProfileService.Get(player)
	if not args[1] or not args[2] then
		ChatService.fail(player, "chat_pay_usage")
		return
	end
	local amount = tonumber((args[2]:gsub(",", ".")))
	if not amount or amount ~= amount or amount < cfg.payMin or amount > 1e12 then
		ChatService.fail(player, "chat_pay_min", cfg.payMin)
		return
	end
	local target, targetProfile = receiver(player, args[1], "chat_pay_self")
	if not target or not targetProfile or not profile or not ProfileService.IsReal(player) then
		return
	end
	if targetProfile.settings and targetProfile.settings.payOff then
		ChatService.fail(player, "chat_pay_off", target.DisplayName)
		return
	end
	local sum = units(math.floor(amount * 100 + 1e-6) / 100) -- whole cents
	if profile.coins < sum then
		ChatService.fail(player, "chat_pay_no_money", Strings.money(profile.coins))
		return
	end
	-- no yield from the check to here: the money leaves one profile and enters the other at once
	ProfileService.Mutate(player, function(p)
		p.coins -= sum
	end)
	ProfileService.Mutate(target, function(p)
		p.coins += sum
	end)
	ChatService.reply(player, "chat_pay_sent", Strings.money(sum), target.DisplayName)
	ChatService.reply(target, "chat_pay_received", player.DisplayName, Strings.money(sum))
	Remotes.event("Toast"):FireClient(
		target,
		Strings.t(
			"chat_pay_received",
			Strings.localeOf(target),
			player.DisplayName,
			Strings.money(sum)
		)
	)
	saveBoth(player, target)
end

-- ── /rubb, /stats ник (этап 8) ──────────────────────────────────────────────────────────────────────────────────

local function rubb(player: Player, args: { string })
	local profile = ProfileService.Get(player)
	if not args[1] or not args[2] then
		ChatService.fail(player, "chat_rubb_usage")
		return
	end
	local amount = tonumber(args[2])
	local min = PrisPlus.cfg.rubbMin
	if
		not amount
		or amount ~= amount
		or amount < min
		or amount > 1e9
		or amount ~= math.floor(amount)
	then
		ChatService.fail(player, "chat_rubb_min", min)
		return
	end
	local target, targetProfile = receiver(player, args[1], "chat_rubb_self")
	if not target or not targetProfile or not profile or not ProfileService.IsReal(player) then
		return
	end
	if targetProfile.settings and targetProfile.settings.payOff then
		ChatService.fail(player, "chat_pay_off", target.DisplayName)
		return
	end
	if PrisPlus.rubies(profile) < amount then
		ChatService.fail(player, "chat_rubb_no_rubies", PrisPlus.rubies(profile))
		return
	end
	-- no yield from the check to here: the rubies leave one profile and enter the other at once
	ProfileService.Mutate(player, function(p)
		local left = PrisPlus.rubies(p) - amount
		p.rubies = if left > 0 then left else nil
	end)
	ProfileService.Mutate(target, function(p)
		p.rubies = PrisPlus.rubies(p) + amount
	end)
	ChatService.reply(player, "chat_rubb_sent", amount, target.DisplayName)
	ChatService.reply(target, "chat_rubb_received", player.DisplayName, amount)
	Remotes.event("Toast"):FireClient(
		target,
		Strings.t("chat_rubb_received", Strings.localeOf(target), player.DisplayName, amount)
	)
	saveBoth(player, target)
end

local function stats(player: Player, args: { string })
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local who = args[1] and Strings.lower(args[1])
	if not who or who == Strings.lower(player.Name) or who == Strings.lower(player.DisplayName) then
		local own = profile.stats
		ChatService.reply(
			player,
			"chat_stats",
			profile.level,
			Strings.big(profile.blocksTotal),
			own.rats or 0,
			own.kills or 0,
			own.deaths or 0
		)
		return
	end
	if not PrisPlus.active(profile) then
		ChatService.fail(player, "chat_stats_other")
		return
	end
	local target, err = findPlayer(args[1])
	local other = target and ProfileService.Get(target)
	if not target or not other then
		ChatService.fail(player, err or "chat_player_not_found", args[1])
		return
	end
	local s = other.stats
	ChatService.reply(
		player,
		"chat_stats_of",
		target.DisplayName,
		other.level,
		Strings.big(other.blocksTotal),
		s.rats or 0,
		s.kills or 0,
		s.deaths or 0
	)
end

-- ── /gift ───────────────────────────────────────────────────────────────────────────────────────────────────────

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function plain(stack: Types.ItemStack): boolean
	return stack.books == nil
		and stack.potion == nil
		and stack.rarity == nil
		and stack.applyChance == nil
		and stack.coins == nil
end

local function fits(profile: Types.Profile, stack: Types.ItemStack): boolean
	if InventoryService.isStackable(stack.id) and plain(stack) then
		return InventoryService.canAdd(profile, stack.id, stack.count)
	end
	for slot = 1, InventoryService.SLOTS do
		if not profile.inventory[slot] then
			return true
		end
	end
	return false
end

local function give(profile: Types.Profile, stack: Types.ItemStack)
	if InventoryService.isStackable(stack.id) and plain(stack) then
		InventoryService.add(profile, stack.id, stack.count, stack.level)
		return
	end
	for slot = 1, InventoryService.SLOTS do
		if not profile.inventory[slot] then
			profile.inventory[slot] = stack
			return
		end
	end
end

local function gift(player: Player, args: { string })
	local profile = ProfileService.Get(player)
	if not args[1] then
		ChatService.fail(player, "chat_gift_usage")
		return
	end
	if not profile or not ProfileService.IsReal(player) then
		return
	end
	local slot = profile.selectedSlot
	local stack = profile.inventory[slot]
	if not stack then
		ChatService.fail(player, "chat_gift_empty")
		return
	end
	if Config.block(stack.id) then
		ChatService.fail(player, "chat_gift_block")
		return
	end
	if table.find(cfg.giftForbidden, stack.id) then
		ChatService.fail(player, "chat_gift_forbidden")
		return
	end
	local target, targetProfile = receiver(player, args[1], "chat_gift_self")
	if not target or not targetProfile then
		return
	end
	local name = target.DisplayName
	if targetProfile.settings and targetProfile.settings.giftOff then
		ChatService.fail(player, "chat_gift_off", name)
		return
	end
	if targetProfile.location ~= profile.location then
		ChatService.fail(player, "chat_gift_location", name)
		return
	end
	local a, b = rootOf(player), rootOf(target)
	local range = cfg.giftRangeBlocks * Config.rules.combat.blockStuds
	if not a or not b or (a.Position - b.Position).Magnitude > range then
		ChatService.fail(player, "chat_gift_far", name, cfg.giftRangeBlocks)
		return
	end
	if profile.location == "gang_base" then
		local gang = player:GetAttribute("GangId")
		if typeof(gang) ~= "string" or target:GetAttribute("GangId") ~= gang then
			ChatService.fail(player, "chat_gift_gang")
			return
		end
	end
	if not fits(targetProfile, stack) then
		ChatService.fail(player, "chat_gift_full", name)
		return
	end
	-- no yield from the checks to here
	local moved = deepCopy(stack) :: Types.ItemStack
	ProfileService.Mutate(player, function(p)
		p.inventory[slot] = nil
	end)
	ProfileService.Mutate(target, function(p)
		give(p, moved)
	end)
	local function itemName(who: Player): string
		return Strings.itemName(moved.id, moved.level, Strings.localeOf(who))
	end
	ChatService.reply(player, "chat_gift_sent", itemName(player), moved.count, name)
	ChatService.reply(
		target,
		"chat_gift_received",
		player.DisplayName,
		itemName(target),
		moved.count
	)
	Remotes.event("Toast"):FireClient(
		target,
		Strings.t(
			"chat_gift_received",
			Strings.localeOf(target),
			player.DisplayName,
			itemName(target),
			moved.count
		)
	)
	saveBoth(player, target)
end

-- ── /thx ────────────────────────────────────────────────────────────────────────────────────────────────────────

local function boosterKey(a: Boosters.Active): string
	return a.id or ((a.by or "?") .. "|" .. a.kind .. "|" .. tostring(math.floor(a.startsAt)))
end

local function appliesTo(p: Types.Profile, a: Boosters.Active): boolean
	local scope = Boosters.scopeOf(a)
	if scope == "global" then
		return true
	elseif scope == "faction" then
		return a.faction ~= nil and p.faction == a.faction
	elseif scope == "gang" then
		return a.gang ~= nil and p.gang ~= nil and p.gang.id == a.gang
	end
	return false
end

local function thx(player: Player, _args: { string })
	local profile = ProfileService.Get(player)
	if not profile or not ProfileService.IsReal(player) then
		return
	end
	local now = Boosters.now()
	local thanked = profile.thanked or {}
	local due = {}
	for _, a in ipairs(Boosters.shared()) do
		local by = a.by
		if
			a.point == nil
			and typeof(by) == "string"
			and by ~= player.Name
			and by:sub(1, 1) ~= "#" -- a gang quest's reward booster has no person behind it
			and a.startsAt <= now
			and now < a.endsAt
			and appliesTo(profile, a)
			and not thanked[boosterKey(a)]
		then
			table.insert(due, a)
		end
	end
	if #due == 0 then
		ChatService.fail(player, "chat_thx_none")
		return
	end
	local reward = units(cfg.thxPerLevel * profile.level)
	ProfileService.Mutate(player, function(p)
		local marks = {}
		for key, endsAt in pairs(p.thanked or {}) do
			if endsAt > now then
				marks[key] = endsAt -- the ended ones are forgotten
			end
		end
		for _, a in ipairs(due) do
			marks[boosterKey(a)] = a.endsAt
		end
		p.thanked = marks
		p.coins += reward * #due
	end)
	for _, a in ipairs(due) do
		local by = a.by :: string
		ChatService.reply(player, "chat_thx_done", by, Strings.money(reward))
		local owner = Players:FindFirstChild(by)
		if
			owner
			and owner:IsA("Player")
			and ProfileService.Get(owner)
			and ProfileService.IsReal(owner)
		then
			ProfileService.Mutate(owner, function(p)
				p.coins += reward
			end)
			ChatService.reply(owner, "chat_thx_received", player.DisplayName, Strings.money(reward))
		end
	end
end

-- ── the bin ─────────────────────────────────────────────────────────────────────────────────────────────────────

local function rubbish(player: Player, list: any)
	local profile = ProfileService.Get(player)
	if typeof(list) ~= "table" or not profile then
		return
	end
	local slots = {}
	for i, entry in ipairs(list) do
		if i > InventoryService.SLOTS then
			break
		end
		if typeof(entry) == "table" and InventoryService.isSlot(entry[1]) then
			local stack = profile.inventory[entry[1]]
			if stack and stack.id == entry[2] and stack.count == entry[3] then
				slots[entry[1]] = true
			end
		end
	end
	local n = 0
	for _ in pairs(slots) do
		n += 1
	end
	if n == 0 then
		return
	end
	ProfileService.Mutate(player, function(p)
		for slot in pairs(slots) do
			p.inventory[slot] = nil
		end
	end)
	ChatService.reply(player, "rubbish_done", n)
end

-- ── the other commands ──────────────────────────────────────────────────────────────────────────────────────────

-- /hide: the other players hidden on this screen (the client acts on settings.hidePlayers)
local function hide(player: Player, _args: { string })
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local on = not (profile.settings and profile.settings.hidePlayers == true)
	ProfileService.Mutate(player, function(p)
		local settings: any = table.clone(p.settings or {}) -- a new table: the profile diff sees the change
		settings.hidePlayers = on
		p.settings = settings
	end)
	ChatService.reply(player, if on then "chat_hide_on" else "chat_hide_off")
end

local function balance(player: Player, _args: { string })
	local profile = ProfileService.Get(player) :: Types.Profile
	ChatService.reply(
		player,
		"chat_balance",
		Strings.money(profile.coins),
		profile.crystals or 0,
		PrisPlus.rubies(profile)
	)
end

local function blocks(player: Player, _args: { string })
	local profile = ProfileService.Get(player) :: Types.Profile
	ChatService.reply(player, "chat_blocks", Strings.big(profile.blocksTotal))
end

-- at the prison already: to its spawn spot; elsewhere: the trip to the prison lands on the spawn
local function spawn(player: Player, _args: { string })
	local profile = ProfileService.Get(player) :: Types.Profile
	if profile.location == "prison" then
		Remotes.event("ChatClient"):FireClient(player, "teleport", "prison", "spawn")
	else
		Remotes.event("ChatClient"):FireClient(player, "teleport", "prison")
	end
end

local function warzone(player: Player, _args: { string })
	Remotes.event("ChatClient"):FireClient(player, "teleport", Warzone.LOCATION)
end

local GANG_SUB = { invite = true, leave = true, deposit = true, withdraw = true, home = true }
local function gang(player: Player, args: { string })
	local sub = args[1] and args[1]:lower()
	if not sub then
		Remotes.event("OpenMenu"):FireClient(player, "gangs")
		return
	end
	local amount = tonumber(args[2] and (args[2]:gsub(",", ".")) or nil)
	if
		not GANG_SUB[sub]
		or (sub == "invite" and not args[2])
		or ((sub == "deposit" or sub == "withdraw") and not (amount and amount > 0))
	then
		ChatService.fail(player, "chat_gang_usage")
		return
	end
	Remotes.event("ChatClient")
		:FireClient(player, "gang", sub, if sub == "invite" then args[2] else amount)
end

-- /f, /g, /l: the input bar writes into that channel from now on (the tab switches with it)
local function channel(kind: Chat.Kind?): (Player, { string }) -> ()
	return function(player: Player, _args: { string })
		if not kind then
			Remotes.event("ChatClient"):FireClient(player, "channel", nil)
			return
		end
		local target = ChatService.channelOf(player, kind)
		if not target then
			ChatService.fail(
				player,
				if kind == "faction" then "chat_no_faction" else "chat_no_gang"
			)
			return
		end
		Remotes.event("ChatClient"):FireClient(player, "channel", target)
	end
end

local function help(player: Player, _args: { string })
	ChatService.reply(player, "chat_help")
end

local function soon(player: Player, _args: { string })
	ChatService.reply(player, "chat_soon")
end

local function window(kind: string): (Player, { string }) -> ()
	return function(player: Player, _args: { string })
		Remotes.event("OpenMenu"):FireClient(player, kind)
	end
end

-- ── the command table ───────────────────────────────────────────────────────────────────────────────────────────

type Command = {
	aliases: { string }, -- without «/»; the first is shown in the autocomplete
	run: (Player, { string }) -> (),
	cooldown: boolean?, -- changes a profile or asks another one: one per Config.chat.commandCooldownSeconds
	profile: boolean?, -- needs the loaded profile
}

local COMMANDS: { [string]: Command } = {
	pay = { aliases = { "pay" }, run = pay, cooldown = true, profile = true },
	gift = { aliases = { "gift" }, run = gift, cooldown = true, profile = true },
	thx = { aliases = { "thx" }, run = thx, cooldown = true, profile = true },
	rubb = { aliases = { "rubb" }, run = rubb, cooldown = true, profile = true },
	stats = { aliases = { "stats" }, run = stats, cooldown = true, profile = true },
	hide = { aliases = { "hide" }, run = hide, cooldown = true, profile = true },
	balance = { aliases = { "balance", "bal", "money" }, run = balance, profile = true },
	blocks = { aliases = { "blocks" }, run = blocks, profile = true },
	help = { aliases = { "help", "commands" }, run = help },
	spawn = { aliases = { "spawn" }, run = spawn, profile = true },
	warzone = { aliases = { "warzone" }, run = warzone },
	gang = { aliases = { "gang" }, run = gang },
	factionChat = { aliases = { "f" }, run = channel("faction") },
	gangChat = { aliases = { "g" }, run = channel("gang") },
	localChat = { aliases = { "l" }, run = channel(nil) },
	soon = { aliases = { "autosell", "wiki", "quests", "skipguide" }, run = soon },
	-- the windows (init.client windowBuilders kinds; the same windows as the keys and the menu)
	menu = { aliases = { "menu" }, run = window("menu") },
	auction = { aliases = { "ah", "auction" }, run = window("auction") },
	potions = { aliases = { "potion", "potions" }, run = window("potions") },
	skills = { aliases = { "skills" }, run = window("skills") },
	factions = { aliases = { "fraction", "frac" }, run = window("factions") },
	donate = { aliases = { "donate" }, run = window("donate") },
	settings = { aliases = { "settings" }, run = window("settings") },
	boosters = { aliases = { "booster", "boosters" }, run = window("boosters") },
	locations = { aliases = { "mines" }, run = window("locations") },
	upgrade = { aliases = { "up", "upgrade" }, run = window("upgrade") },
	level = { aliases = { "level" }, run = window("level") },
	achievements = { aliases = { "achievements" }, run = window("achievements") },
	artifacts = { aliases = { "artifacts" }, run = window("artifacts") },
	rubbish = { aliases = { "rubbish" }, run = window("rubbish") },
	daily = { aliases = { "daily" }, run = window("daily") }, -- «Ежедневные награды» (этап 7)
	pris = { aliases = { "pp", "mining" }, run = window("pris") }, -- PRIS+ (этап 8; the auto-dig switch lives there)
	names = { aliases = { "names", "titles", "nickname" }, run = window("names") }, -- «Ваши клички» (этап 9)
	players = { aliases = { "players", "list" }, run = window("players") }, -- the TAB list (этап 9)
}
-- the commands the player card also sends as ChatCommand(id, args) (players who may not chat have only the buttons)
local BUTTONS = { pay = true, gift = true, thx = true, rubb = true }
local BY_ALIAS: { [string]: string } = {}
for id, command in pairs(COMMANDS) do
	for _, alias in ipairs(command.aliases) do
		BY_ALIAS[alias] = id
	end
end

-- the command `id` with its arguments → true when it was one of ours
local function runArgs(player: Player, id: string, typed: { string }): boolean
	local command = COMMANDS[id]
	if not command then
		return false
	end
	local args = {}
	for i = 1, math.min(#typed, 4) do
		args[i] = typed[i]:sub(1, 64) -- a name or a number never needs more
	end
	if command.cooldown then
		if os.clock() - (lastCommand[player] or -math.huge) < cfg.commandCooldownSeconds then
			ChatService.fail(player, "chat_wait")
			return true
		end
		lastCommand[player] = os.clock()
	end
	if command.profile and not ProfileService.Get(player) then
		ChatService.fail(player, "chat_not_ready")
		return true
	end
	local ok, err = pcall(command.run, player, args)
	if not ok then
		warn("[ChatCommandService] /" .. id .. ": " .. tostring(err))
	end
	return true
end

-- the command `id` typed as `text` (the alias first, then the arguments)
local function run(player: Player, id: string, text: string): boolean
	local _, typed = Chat.command(text)
	return runArgs(player, id, typed)
end

-- a typed line (QA ChatDebug "command") → the command by its alias
local function runText(player: Player, text: string): boolean
	local name = Chat.command(text)
	local id = name and BY_ALIAS[name]
	return id ~= nil and run(player, id, text)
end

local function createCommands()
	local folder = Instance.new("Folder")
	folder.Name = Chat.COMMANDS
	for id, command in pairs(COMMANDS) do
		local aliases = command.aliases
		for i = 1, #aliases, 2 do
			local instance = Instance.new("TextChatCommand")
			instance.Name = id .. (if i > 1 then tostring((i + 1) // 2) else "")
			instance.PrimaryAlias = "/" .. aliases[i]
			instance.SecondaryAlias = if aliases[i + 1] then "/" .. aliases[i + 1] else ""
			instance.AutocompleteVisible = i == 1
			instance.Triggered:Connect(function(source: TextSource, text: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					run(player, id, if typeof(text) == "string" then text else "")
				end
			end)
			instance.Parent = folder
		end
	end
	folder.Parent = TextChatService
	-- Roblox's own /help gives way to ours (the default commands appear a moment after the start)
	task.spawn(function()
		local defaults = TextChatService:WaitForChild("TextChatCommands", 30)
		local rbxHelp = defaults and defaults:WaitForChild("RBXHelpCommand", 30)
		if rbxHelp and rbxHelp:IsA("TextChatCommand") then
			rbxHelp.Enabled = false
		end
	end)
end

function ChatCommandService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("ChatClient")
	createCommands()
	-- the player card's buttons (PlayerListWindow: transfer, gift, thanks) — the same checks as the typed commands
	Remotes.event("ChatCommand").OnServerEvent:Connect(function(player: Player, id: any, args: any)
		if typeof(id) ~= "string" or not BUTTONS[id] or typeof(args) ~= "table" then
			return
		end
		local clean = {}
		for i = 1, math.min(#args, 4) do
			if typeof(args[i]) ~= "string" then
				return
			end
			clean[i] = args[i]
		end
		runArgs(player, id, clean)
	end)
	Remotes.event("Rubbish").OnServerEvent:Connect(rubbish)
	ChatService.commandHandler = runText
	Players.PlayerRemoving:Connect(function(player)
		lastCommand[player] = nil
	end)
end

return ChatCommandService
