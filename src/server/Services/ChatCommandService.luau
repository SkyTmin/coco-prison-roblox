--!strict
-- Chat commands that change the profile (этап 3; the window commands and /balance, /hide … run on the client, see
-- src/client/ChatCommands.luau). The client sends ChatCommand(name, args) for:
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
-- Rubbish(list) — «Урна» [клиент garbage.*] closed: list = { {slot, id, count} }; the stacks that still match go away.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
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

-- ── start ───────────────────────────────────────────────────────────────────────────────────────────────────────

local COMMANDS: { [string]: (Player, { string }) -> () } = { pay = pay, gift = gift, thx = thx }

local function run(player: Player, name: string, args: { string }): boolean
	local command = COMMANDS[name]
	if not command then
		return false
	end
	if os.clock() - (lastCommand[player] or -math.huge) < cfg.commandCooldownSeconds then
		ChatService.fail(player, "chat_wait")
		return true
	end
	lastCommand[player] = os.clock()
	if not ProfileService.Get(player) then
		ChatService.fail(player, "chat_not_ready")
		return true
	end
	local ok, err = pcall(command, player, args)
	if not ok then
		warn("[ChatCommandService] /" .. name .. ": " .. tostring(err))
	end
	return true
end

function ChatCommandService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("ChatCommand").OnServerEvent
		:Connect(function(player: Player, name: any, args: any)
			if typeof(name) ~= "string" or typeof(args) ~= "table" or #name > 16 then
				return
			end
			local clean = {}
			for i = 1, math.min(#args, 4) do
				local value = args[i]
				if typeof(value) ~= "string" or #value > 64 then
					return
				end
				clean[i] = value
			end
			run(player, name, clean)
		end)
	Remotes.event("Rubbish").OnServerEvent:Connect(rubbish)
	ChatService.commandHandler = run
	Players.PlayerRemoving:Connect(function(player)
		lastCommand[player] = nil
	end)
end

return ChatCommandService
