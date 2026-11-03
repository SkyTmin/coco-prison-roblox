--!strict
-- Personal persistent chests. Opening the UI never spends a key or grants rewards.
-- Shared storages: the faction chests (FactionStorageService) and the gang storage on the База банды (tag GangChest,
-- GangChestService: pages of 27 slots, one server at a time; GangChestPage(page) turns the page, the player attributes
-- GangChestPage / GangChestPages tell the window where it is).
-- The Хранилище [вики DONATE-SHOP-BOOSTERS; сеть S6]: every EnderChest (Спавн, the vault building of
-- scripts/build-vault.luau with attribute Vault, the faction base) opens the same p.enderChest of up to 3 sections of
-- 27 (Shared/Vault). The window sends the section it shows with each CaseMove (only an open one is accepted) and buys
-- the next section with VaultUnlock(section, "dollars" | "crystals"). Everything stays in the profile: no dupe path.
local CollectionService = game:GetService("CollectionService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Boosters = require(Shared.Boosters)
local Config = require(Shared.Config)
local Donate = require(Shared.Donate)
local Nicknames = require(Shared.Nicknames)
local Remotes = require(Shared.Remotes)
local Sfx = require(Shared.Sfx)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local ChatService = require(script.Parent.ChatService) -- announcements in the chat (этап 3)
local InventoryService = require(script.Parent.InventoryService)
local AncientCase = require(script.Parent.AncientCase)
local ArtifactService = require(script.Parent.ArtifactService)
local FactionStorage = require(script.Parent.FactionStorageService)
local GangChest = require(script.Parent.GangChestService)
local GangService = require(script.Parent.GangService)
local GangHouse = require(script.Parent.GangHouseService)
local NicknameService = require(script.Parent.NicknameService) -- клички (этап 9): the shown name, the «Ваши клички» window
local Types = require(Shared.Types)
local Vault = require(Shared.Vault)
local Persistence = require(Shared.Persistence)
local Storage = require(script.Parent.SharedStorageService)
local Transfers = require(script.Parent.StorageTransferService)

type Reward = {
	id: string,
	weight: number,
	items: { string }?,
	count: { number }?,
	min: number?,
	max: number?,
}
type Binding = {
	info: ProximityPrompt?, -- «Подробнее» (cases only)
	prompt: ProximityPrompt,
	connection: RBXScriptConnection,
	attribute: RBXScriptConnection,
}
type Session = {
	id: string,
	part: BasePart,
	rolledAt: number,
	revealPending: boolean?,
	tokens: number,
	tokenAt: number,
	faction: string?, -- factionChest: whose storage and which of the 8 chests
	index: number?, -- factionChest: the chest; gangChest: the page
	gang: string?, -- gangChest: whose storage
}
type Address = { container: "case" | "inv", index: number }
local CASES: { [string]: { tag: string, text: string } } = {
	ordinaryCase = { tag = "OrdinaryCase", text = "ordinary_case" },
	ancientCase = { tag = "AncientCase", text = "ancient_case" },
	artifactCase = { tag = "ArtifactCase", text = "artifact_case" },
	nicknameCase = { tag = "NicknameCase", text = "nickname_case" },
}
local TAGS = {
	"OrdinaryCase",
	"AncientCase",
	"ArtifactCase",
	"NicknameCase",
	"EnderChest",
	"FactionChest",
	"GangChest",
}
local ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local RANGE = 12
local random = Random.new()
local bindings: { [Instance]: Binding } = {}
local sessions: { [Player]: Session } = {}
local openEpoch: { [Player]: number } = {}
local ancientRollUntil: { [Player]: number } = {}
local started = false
local CaseService = {}

local function containerTitle(id: string): string
	return if id == "enderChest"
		then "ender_chest"
		elseif id == "factionChest" then "faction_chest"
		elseif id == "gangChest" then "gang_chest"
		else CASES[id].text
end

-- storage chests keep what is put in and need no key: the personal ender chest and the faction chests
-- of the faction base (FactionStorageService; the profile only mirrors the open chest for the window)
local function isStorage(id: string): boolean
	return id == "enderChest" or id == "factionChest" or id == "gangChest"
end

local function gangIdOf(profile: Types.Profile?): string?
	local doc = profile and GangService.gangOf(profile)
	return if doc then doc.id else nil
end

-- the live slots behind a shared storage session (nil = none / not open on this server)
local function sharedSlots(session: Session): { [number]: Types.ItemStack }?
	if session.id == "factionChest" then
		return FactionStorage.Chest(session.faction, session.index)
	elseif session.id == "gangChest" then
		return GangChest.Page(session.gang, session.index)
	end
	return nil
end

local function deepCopy(slots: { [number]: Types.ItemStack }): { [number]: Types.ItemStack }
	local out = {}
	for slot, stack in pairs(slots) do
		out[slot] = table.clone(stack)
	end
	return out
end

local function contentsFor(profile: Types.Profile, id: string): { [number]: Types.ItemStack }
	return if id == "enderChest" then profile.enderChest else profile.caseContents[id]
end

local function caseId(part: Instance): string?
	if CollectionService:HasTag(part, "EnderChest") then
		return "enderChest"
	end
	if CollectionService:HasTag(part, "FactionChest") then
		return "factionChest"
	end
	if CollectionService:HasTag(part, "GangChest") then
		return "gangChest"
	end
	local attribute = part:GetAttribute("CaseId")
	if attribute ~= nil then
		local definition = if typeof(attribute) == "string" then CASES[attribute] else nil
		return if definition and CollectionService:HasTag(part, definition.tag)
			then attribute :: string
			else nil
	end
	for id, definition in pairs(CASES) do
		if CollectionService:HasTag(part, definition.tag) then
			return id
		end
	end
	return nil
end

local function near(player: Player, part: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return part:IsDescendantOf(workspace)
		and root ~= nil
		and root:IsA("BasePart")
		and humanoid ~= nil
		and humanoid.Health > 0
		and (root.Position - part.Position).Magnitude <= RANGE
end

-- Ordinary cases empty on close. Ancient overflow survives walking away during the roulette [owner 02.11].
local function emptyCase(player: Player, id: string)
	if id ~= "enderChest" and id ~= "ancientCase" and ProfileService.Get(player) then
		ProfileService.Mutate(player, function(p: any)
			p.caseContents[id] = {}
		end)
	end
end

local function close(player: Player)
	openEpoch[player] = (openEpoch[player] or 0) + 1
	local session = sessions[player]
	if session then
		sessions[player] = nil
		emptyCase(player, session.id)
		Remotes.event("CaseUpdated"):FireClient(player, session.id, false)
		local part = (session :: any).part
		if typeof(part) == "Instance" and part:IsA("BasePart") then
			Sfx.broadcast(
				if session.id == "enderChest" then "ender_close" else "chest_close",
				part,
				0.6
			)
		end
	end
end

local function validate(player: Player, id: any): Session?
	if typeof(id) ~= "string" or (not CASES[id] and not isStorage(id)) then
		return nil
	end
	local session = sessions[player]
	if not session or session.id ~= id then
		return nil
	end
	local profile = ProfileService.Get(player)
	if
		caseId(session.part) ~= id
		or not near(player, session.part)
		or not profile
		or (id == "factionChest" and profile.faction ~= session.faction) -- left the faction meanwhile
		or (
			id == "gangChest"
			and (
				gangIdOf(profile) ~= session.gang
				or not GangChest.Valid(session.gang)
				or not GangHouse.allowed(session.part, player)
			)
		)
	then
		close(player)
		return nil
	end
	return session
end

local function address(value: any): Address?
	if typeof(value) ~= "table" or (value.container ~= "case" and value.container ~= "inv") then
		return nil
	end
	local index = value.index
	local limit = if value.container == "case" then 27 else 36
	if
		typeof(index) ~= "number"
		or not (index >= 1 and index <= limit and index == math.floor(index))
	then
		return nil
	end
	return { container = value.container, index = index }
end

local function rewardsFor(id: string): { Reward }?
	local config = Config.keys[id]
	if typeof(config) ~= "table" then
		return nil
	end
	local rewards = config.rewards or config
	return if typeof(rewards) == "table" and #rewards > 0 then rewards else nil
end

local function roll(rewards: { Reward }): Reward
	local total = 0
	for _, reward in ipairs(rewards) do
		total += reward.weight
	end
	local value = random:NextNumber() * total
	for _, reward in ipairs(rewards) do
		value -= reward.weight
		if value < 0 then
			return reward
		end
	end
	return rewards[#rewards]
end

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

-- Keys a case accepts (Config.keys.caseKeys: one id or a list).
local function acceptedKeys(id: string): { string }
	local configured = Config.keys.caseKeys[id]
	return if typeof(configured) == "string"
		then { configured }
		elseif typeof(configured) == "table" then configured
		else {}
end

local function hasAnyKey(profile: Types.Profile, keys: { string }): boolean
	for _, key in ipairs(keys) do
		if InventoryService.count(profile, key) > 0 then
			return true
		end
	end
	return false
end

local openCase: (player: Player, id: any, requestedKey: any) -> ()

-- [владелец 22.10] a case opens with its key IN HAND: the key is spent at once and the window shows
-- the reward; without the key in hand nothing opens (a hint says which key to take). The ender chest
-- needs no key.
local function openChest(player: Player, part: BasePart)
	local id = caseId(part)
	local profile = ProfileService.Get(player)
	if not id or not near(player, part) or not profile then
		return
	end
	local epoch = (openEpoch[player] or 0) + 1
	openEpoch[player] = epoch
	local heldKey: string? = nil
	local shared: { [number]: Types.ItemStack }? = nil
	local gang: string? = nil
	if (id == "factionChest" or id == "gangChest") and not ProfileService.IsReal(player) then
		toast(player, "gang_chest_unavailable")
		return
	end
	if id == "factionChest" then
		-- [клиент] «Вы не можете открывать сундуки на чужой базе фракции!»
		if profile.faction == nil or part:GetAttribute("Faction") ~= profile.faction then
			toast(player, "faction_foreign_chest")
			return
		end
		shared = FactionStorage.Chest(profile.faction, part:GetAttribute("ChestIndex"))
		if not shared then
			return
		end
	elseif id == "gangChest" then
		-- the gang storage [вики HANDBOOK-WIKI «склад»]: one server at a time (GangChestService)
		gang = gangIdOf(profile)
		if not gang then
			toast(player, "gang_location_need_gang")
			return
		end
		if not GangHouse.allowed(part, player) then
			toast(player, "gang_plot_foreign") -- the chest in another gang's house
			return
		end
		if GangChest.PageCount(GangService.gangOf(profile)) < 1 then
			-- «Сундуки» level 0: no storage yet [владелец 28.10: «с 0 уровня ничего нет»]
			toast(
				player,
				"gang_npc_need_upgrade",
				Strings.t("gang_up_chests", Strings.localeOf(player))
			)
			return
		end
		local ok, refusal = GangChest.Open(gang)
		if not ok then
			toast(player, refusal or "gang_chest_unavailable")
			return
		end
		if not near(player, part) or gangIdOf(ProfileService.Get(player)) ~= gang then
			return -- walked away or left the gang while the storage was loading
		end
		shared = GangChest.Page(gang, 1)
		if not shared then
			return
		end
	elseif
		id ~= "enderChest"
		and not (id == "ancientCase" and next(profile.caseContents.ancientCase or {}))
	then
		if id == "ancientCase" and os.clock() < (ancientRollUntil[player] or 0) then
			return
		end
		local keys = acceptedKeys(id)
		local held = profile.inventory[profile.selectedSlot]
		heldKey = if held and table.find(keys, held.id) then held.id else nil
		if not heldKey then
			toast(
				player,
				if hasAnyKey(profile, keys) then "case_hold_key" else "case_need_key",
				Strings.itemName(keys[1] or "ordinary_key", nil, Strings.localeOf(player))
			)
			return
		end
	end
	local pageCount = if gang
		then GangChest.PageCount(GangService.gangOf(ProfileService.Get(player)))
		else 0
	if openEpoch[player] ~= epoch then
		return
	end
	if shared then
		local latest = ProfileService.Get(player)
		if
			not latest
			or not ProfileService.IsReal(player)
			or not near(player, part)
			or (id == "factionChest" and part:GetAttribute("Faction") ~= latest.faction)
			or (gang and (gangIdOf(latest) ~= gang or not GangHouse.allowed(part, player)))
		then
			return
		end
	end
	local previous = sessions[player]
	if previous then
		emptyCase(player, previous.id) -- another case opened over this one: the old one closes
	end
	sessions[player] = {
		id = id,
		part = part,
		rolledAt = -math.huge,
		tokens = 80,
		tokenAt = os.clock(),
		faction = if shared and not gang then profile.faction else nil,
		index = if gang then 1 elseif shared then part:GetAttribute("ChestIndex") :: number else nil,
		gang = gang,
	}
	if gang then
		player:SetAttribute("GangChestPage", 1)
		player:SetAttribute("GangChestPages", pageCount)
	end
	ProfileService.Mutate(player, function(p: any)
		if shared then
			p.caseContents[id] = deepCopy(shared)
			p.casePages = p.casePages or {}
			p.casePages[id] = sessions[player].index
		elseif id ~= "enderChest" then
			p.caseContents[id] = p.caseContents[id] or {}
		end
	end)
	if id ~= "ancientCase" or not heldKey then
		Remotes.event("CaseOpened"):FireClient(player, id)
	end
	if part and part:IsA("BasePart") then
		Sfx.broadcast(if id == "enderChest" then "ender_open" else "chest_open", part, 0.6)
	end
	if heldKey then
		openCase(player, id, heldKey) -- spend the key in hand and roll right away
	end
end

openCase = function(player: Player, id: any, requestedKey: any)
	openEpoch[player] = (openEpoch[player] or 0) + 1
	local session = validate(player, id)
	if not session then
		-- [владелец 21.10: «пусто после открытия»] the window is up but this server has no session for
		-- it (walked away, reopened elsewhere): say so and close it instead of silently doing nothing
		if typeof(id) == "string" and CASES[id] then
			warn(
				string.format(
					"[CaseService] %s pressed Open on %s without a session",
					player.Name,
					id
				)
			)
			Remotes.event("CaseUpdated"):FireClient(player, id, false)
			toast(player, "case_reopen")
		end
		return
	end
	if
		isStorage(session.id)
		or os.clock() - session.rolledAt < 0.4
		or (session.id == "ancientCase" and os.clock() < (ancientRollUntil[player] or 0))
	then
		if player:GetAttribute("CreativeAllowed") and not isStorage(session.id) then
			warn(
				"[кейс] нажато слишком быстро после прошлого открытия — пропущено"
			)
		end
		return
	end
	session.rolledAt = os.clock()
	local accepted = acceptedKeys(session.id)
	if
		requestedKey ~= nil
		and (typeof(requestedKey) ~= "string" or not table.find(accepted, requestedKey))
	then
		-- a key of another case: refused, and the toast names the key this case wants
		toast(
			player,
			"case_need_key",
			Strings.itemName(accepted[1] or "ordinary_key", nil, Strings.localeOf(player))
		)
		return
	end
	if session.id == "nicknameCase" then
		-- [вики] the nickname case grants a unique nickname; "all nicknames already owned" is a separate error.
		-- The list (46 like the original [клиент], names ours) and the tier weights: Shared/Nicknames [решение].
		local granted: string? = nil
		local failure: string? = nil
		ProfileService.Mutate(player, function(p: any)
			local key: string? = nil
			for _, candidate in ipairs(accepted) do
				if
					(requestedKey == nil or requestedKey == candidate)
					and InventoryService.count(p, candidate) > 0
				then
					key = candidate
					break
				end
			end
			if not key then
				failure = "case_no_key"
				return
			end
			local owned = p.nicknames or {}
			local pick = Nicknames.pick(owned, random)
			if not pick then
				failure = "nickname_all_owned" -- the key is not spent
				return
			end
			table.insert(owned, pick)
			p.nicknames = owned
			p.nickname = pick
			InventoryService.remove(p, key, 1)
			granted = pick
		end)
		if failure then
			toast(player, failure)
		elseif granted then
			toast(player, "nickname_received", granted)
			NicknameService.apply(player)
			ChatService.announce("chat_nickname", player.DisplayName, granted) -- «выбитая кличка» [вики MENUS-SOCIAL]
		end
		Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
		return
	end
	local rewards = rewardsFor(session.id)
	if not rewards and session.id ~= "ancientCase" then
		toast(player, "case_locked")
		return
	end
	local money = 0
	local failure: string? = nil
	local artifactNotices: { ArtifactService.Notice } = {}
	local rolledBook: Types.ItemStack? = nil
	local bookDestination: string? = nil
	local ok, err = pcall(ProfileService.Mutate, player, function(p: any)
		local key: string? = nil
		for _, candidate in ipairs(accepted) do
			if
				(requestedKey == nil or requestedKey == candidate)
				and InventoryService.count(p, candidate) > 0
			then
				key = candidate
				break
			end
		end
		if not key then
			failure = "case_no_key"
			return
		end
		-- Stage rewards using the inventory's stack limits, then place them in free chest slots.
		-- No existing chest stack or key is changed until the entire roll fits.
		local staged = table.clone(p)
		staged.inventory = {}
		if session.id == "ancientCase" then
			local book = AncientCase.roll(key == "improved_ancient_key", random)
			local destination = AncientCase.deliver(p, key, book)
			if destination ~= "inventory" and destination ~= "case" then
				failure = destination
				return
			end
			rolledBook, bookDestination = book, destination
			return
		end
		local rolls = if session.id == "ordinaryCase" then random:NextInteger(2, 4) else 1
		for _ = 1, rolls do
			local reward = roll(rewards :: { Reward })
			local item, count, level = reward.id, 1, nil :: number?
			if item == "money" then
				local amount = random:NextInteger(
					math.floor((reward.min :: number) * Config.moneyScale + 0.5),
					math.floor((reward.max :: number) * Config.moneyScale + 0.5)
				)
				if session.id == "artifactCase" then
					-- Artifact rewards, including money, remain in the persistent grid until claimed.
					staged.inventory[1] = { id = "money_bag", count = 1, coins = amount }
				else
					money += amount
				end
			elseif item == "ancient_book" then
				-- the artifact case's book: an ordinary-key roll of the Ancient case [меню: «порошок/книга»]
				staged.inventory[1] = AncientCase.roll(false, random)
			else
				if reward.count then
					count = random:NextInteger(reward.count[1], reward.count[2])
				end
				if item == "food" then
					local items = reward.items :: { string }
					local counts = reward.count :: { number }
					item = items[random:NextInteger(1, #items)]
					count = random:NextInteger(counts[1], counts[2])
				elseif item == "leather_armor_piece" then
					item, level = ARMOR[random:NextInteger(1, #ARMOR)], 1
				elseif item == "wooden_sword_or_bow" then
					item, level = if random:NextInteger(1, 2) == 1 then "sword" else "bow", 1
				elseif item == "rare_wooden_pickaxe_silk_touch" then
					item, level = "pickaxe", 1
				elseif item == "booster" then
					-- «ящик (набор)» of the artifact case: a local ×2 booster of a random kind, the storage's item
					item = Boosters.itemId(
						Boosters.kinds[random:NextInteger(1, #Boosters.kinds)],
						"local"
					)
				end
				if reward.id == "rare_wooden_pickaxe_silk_touch" then
					local free: number? = nil
					for index = 1, 27 do
						if not staged.inventory[index] then
							free = index
							break
						end
					end
					if free then
						staged.inventory[free] = {
							id = item,
							count = 1,
							level = level,
							books = { { id = "silk_touch", level = 1 } },
						}
					else
						failure = "case_full"
					end
				elseif InventoryService.add(staged, item, count, level) > 0 then
					failure = "case_full"
				end
				if failure then
					return
				end
			end
		end
		local contents = table.clone(p.caseContents[session.id])
		local nextFree = 1
		for index = 1, 36 do
			local stack = staged.inventory[index]
			if stack then
				while nextFree <= 27 and contents[nextFree] do
					nextFree += 1
				end
				if nextFree > 27 then
					failure = "case_full"
					return
				end
				contents[nextFree] = stack
				nextFree += 1
			end
		end
		InventoryService.remove(p, key, 1)
		p.caseContents[session.id] = contents
		p.coins += money
		if
			session.id == "ordinaryCase"
			and random:NextNumber() < Config.artifacts.fromCaseChance.ordinaryCase
		then
			artifactNotices = ArtifactService.GrantFragment(p, "common")
		end
	end)
	if not ok then
		warn(
			string.format(
				"[CaseService] opening %s failed for %s: %s",
				session.id,
				player.Name,
				tostring(err)
			)
		)
		toast(player, "case_error")
		return
	end
	if failure then
		toast(player, failure)
	elseif money > 0 then
		toast(player, "case_money", Strings.money(money))
	end
	if player:GetAttribute("CreativeAllowed") then
		-- trace for the owner's creative log (the case "opened empty" on the owner's phone, 22.10)
		local profile = ProfileService.Get(player)
		local inside, keys = 0, 0
		if profile then
			for _ in pairs(profile.caseContents[session.id] or {}) do
				inside += 1
			end
			for _, key in ipairs(accepted) do
				keys += InventoryService.count(profile, key)
			end
		end
		warn(
			string.format(
				"[кейс] %s: %s, в кейсе %d, деньги %s, ключей осталось %d",
				session.id,
				failure or "открыт",
				inside,
				Strings.money(money),
				keys
			)
		)
	end
	ArtifactService.Notify(player, artifactNotices)
	-- The reward is already delivered; roulette is cosmetic and never locks movement.
	local book = rolledBook and rolledBook.books and rolledBook.books[1]
	if not failure and book then
		ancientRollUntil[player] = os.clock() + 7
		session.revealPending = bookDestination == "case"
		Remotes.event("AncientRoll"):FireClient(
			player,
			session.part,
			book.id,
			book.level,
			rolledBook and rolledBook.rarity,
			bookDestination == "case"
		)
	end
	Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
end

-- the Хранилище section a move of the ender chest addresses: only an open one (Shared/Vault); every other storage 1
local function moveSection(player: Player, id: string, rawSection: any): number?
	if id ~= "enderChest" then
		return 1
	end
	local profile = ProfileService.Get(player)
	if
		typeof(rawSection) ~= "number"
		or rawSection ~= math.floor(rawSection)
		or rawSection < 1
		or rawSection > Vault.unlocked(profile)
	then
		return nil
	end
	return rawSection
end

-- rawSection: the Хранилище section the window shows (enderChest only); the case slot index is within that section
local function move(
	player: Player,
	id: any,
	rawFrom: any,
	rawTo: any,
	rawCount: any,
	rawSection: any
)
	local count = if typeof(rawCount) == "number" then rawCount else nil
	local session = validate(player, id)
	local from, to = address(rawFrom), address(rawTo)
	local quick = rawTo == "quick" and rawCount == nil
	if quick and from then
		to = { container = if from.container == "case" then "inv" else "case", index = 1 }
	end
	if
		not session
		or not from
		or not to
		or (from.container == to.container and from.index == to.index)
	then
		return
	end
	if session.id == "gangChest" and rawSection ~= session.index then
		return -- a held slot belongs to the acknowledged page, never a new page at the same index
	end
	local section = moveSection(player, session.id, rawSection)
	if not section then
		return
	end
	-- the slots of p.enderChest behind the window's case slots (other containers: the slot itself)
	local fromIndex = if from.container == "case"
		then Vault.slot(section, from.index)
		else from.index
	local toIndex = if to.container == "case" then Vault.slot(section, to.index) else to.index
	local now = os.clock()
	session.tokens = math.min(80, session.tokens + (now - session.tokenAt) * 40)
	session.tokenAt = now
	if session.tokens < 1 then
		return
	end
	session.tokens -= 1
	local claimedMoney = 0
	local isShared = session.id == "factionChest" or session.id == "gangChest"
	local shared, revision = nil, nil
	local kind = if session.id == "gangChest" then "gang" else "faction"
	local key = session.gang or session.faction
	local page = session.index
	if isShared then
		if not ProfileService.IsReal(player) or Transfers.Pending(player) or not key then
			return
		end
		shared, revision = Storage.Snapshot(kind, key, page :: number)
		if
			not shared
			or validate(player, id) ~= session
			or session.index ~= page
			or Transfers.Pending(player)
		then
			return
		end
	end
	local originalPage = Persistence.copy(shared)
	local function applyMove(p: Types.Profile)
		local contents = shared or contentsFor(p, session.id)
		local source = if from.container == "case" then contents else p.inventory
		local target = if to.container == "case" then contents else p.inventory
		-- Persistent ancient slots hold unclaimed rewards, not a second free storage chest.
		if session.id == "ancientCase" and from.container ~= to.container then
			if from.container == "inv" or (not quick and target[toIndex] ~= nil) then
				return
			end
		end
		if not source[fromIndex] then
			return
		end
		-- Legacy overflow above eight chests is withdrawal-only, never a ninth chest.
		if session.id == "gangChest" and session.index > GangChest.MAX_PAGES then
			if
				from.container ~= "case"
				or to.container ~= "inv"
				or (not quick and target[toIndex] ~= nil)
			then
				return
			end
		end
		local stack = source[fromIndex]
		if
			from.container == "case"
			and to.container == "inv"
			and stack.id == "money_bag"
			and count == nil
		then
			local amount = stack.coins
			if
				typeof(amount) == "number"
				and amount > 0
				and amount < math.huge
				and amount == math.floor(amount)
			then
				-- Remove the claim before crediting; replaying this move sees an empty slot.
				source[fromIndex] = nil
				p.coins += amount
				claimedMoney = amount
			end
			return
		end
		-- Reuse inventory merge/swap and stack limits for both containers.
		if quick then
			local first = if to.container == "case" then Vault.slot(section, 1) else 1
			local last = if to.container == "case"
				then Vault.slot(section, 27)
				else InventoryService.SLOTS
			InventoryService.transfer(source, fromIndex, target, first, last)
			return
		end
		local staged = table.clone(p)
		staged.inventory = { [1] = source[fromIndex], [2] = target[toIndex] }
		InventoryService.move(staged, 1, 2, count)
		source[fromIndex], target[toIndex] = staged.inventory[1], staged.inventory[2]
	end
	if isShared then
		local profile = ProfileService.Get(player)
		if not profile then
			return
		end
		local before = Persistence.copy(profile.inventory)
		local staged = table.clone(profile)
		staged.inventory = Persistence.copy(before)
		applyMove(staged)
		if not Persistence.equal(originalPage, shared) then
			Transfers.Begin(
				player,
				kind,
				key :: string,
				page :: number,
				revision :: number,
				before,
				staged.inventory,
				shared,
				claimedMoney
			)
		else
			ProfileService.Mutate(player, function(p: any)
				p.inventory = staged.inventory
				p.storageSettled = (p.storageSettled or 0) + 1
				p.caseContents[session.id] = deepCopy(shared)
			end)
			Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
		end
		return
	end
	ProfileService.Mutate(player, applyMove)
	if claimedMoney > 0 then
		toast(player, "case_money", Strings.money(claimedMoney))
	end
	Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
end

-- «◀ / ▶» in the gang storage window: show another page of 27 slots
local function turnPage(player: Player, rawPage: any)
	local session = validate(player, "gangChest")
	if
		not session
		or Transfers.Pending(player)
		or typeof(rawPage) ~= "number"
		or rawPage ~= math.floor(rawPage)
	then
		return
	end
	local previous = session.index
	local pages = GangChest.PageCount(GangService.gangOf(ProfileService.Get(player)))
	if rawPage < 1 or rawPage > pages or rawPage == session.index then
		return
	end
	local slots = GangChest.Page(session.gang, rawPage)
	if
		not slots
		or validate(player, "gangChest") ~= session
		or session.index ~= previous
		or Transfers.Pending(player)
	then
		return
	end
	session.index = rawPage
	ProfileService.Mutate(player, function(p: any)
		p.caseContents.gangChest = deepCopy(slots)
		p.casePages = p.casePages or {}
		p.casePages.gangChest = rawPage
	end)
	player:SetAttribute("GangChestPage", rawPage)
	player:SetAttribute("GangChestPages", pages)
	Remotes.event("CaseUpdated"):FireClient(player, "gangChest", true)
end

-- «Открыть за 10 000 $» / «за 199 кр.» in the Хранилище window [вики DONATE-SHOP-BOOSTERS]: the next section only
-- (strictly in order: «Не торопитесь!»), with the ender chest open. `section` is the one the button showed, so a
-- double click or a stale window never pays twice; the price is checked and taken in the same mutation.
local unlockAt: { [Player]: number } = {}
local function unlockSection(player: Player, rawSection: any, currency: any)
	if
		not validate(player, "enderChest")
		or typeof(rawSection) ~= "number"
		or (currency ~= "dollars" and currency ~= "crystals")
		or os.clock() - (unlockAt[player] or -math.huge) < 0.5
	then
		return
	end
	unlockAt[player] = os.clock()
	local price = Vault.price(rawSection)
	local result: string? = nil
	ProfileService.Mutate(player, function(p: any)
		local open = Vault.unlocked(p)
		if open >= Vault.MAX then
			result = "vault_max"
			return
		elseif not price or rawSection ~= open + 1 then
			result = if rawSection > open + 1 then "vault_in_order" else nil
			return
		end
		if currency == "dollars" then
			local cost = math.floor(price.dollars * Config.moneyScale + 0.5)
			if p.coins < cost then
				result = "vault_no_money"
				return
			end
			p.coins -= cost
		else
			-- a donate purchase: the rubies go first (Shared/Donate, этап 8)
			if Donate.wallet(p, nil) < price.crystals then
				result = "vault_no_crystals"
				return
			end
			Donate.pay(p, nil, price.crystals)
		end
		p.vaultSections = open + 1
		result = "vault_unlocked"
	end)
	if result then
		toast(player, result)
	end
	Remotes.event("CaseUpdated"):FireClient(player, "enderChest", true)
	if result == "vault_unlocked" then
		task.spawn(ProfileService.SaveNow, player) -- paid with crystals / dollars: keep it through a crash
	end
end

-- QA (Studio only): ServerStorage.VaultDebug — ("state", userId) → JSON {sections, used = {per section}};
-- ("sections", userId, n) sets the open sections (1 … MAX; items in a closed section stay, unseen)
local function debugHook()
	if not RunService:IsStudio() then
		return
	end
	local hook = Instance.new("BindableFunction")
	hook.Name = "VaultDebug"
	hook.OnInvoke = function(op: string, userId: number, n: any): any
		local player = Players:GetPlayerByUserId(userId)
		local profile = player and ProfileService.Get(player)
		if not player or not profile then
			return nil
		end
		if op == "sections" and typeof(n) == "number" then
			ProfileService.Mutate(player, function(p: any)
				p.vaultSections = math.clamp(math.floor(n), 1, Vault.MAX)
			end)
			Remotes.event("CaseUpdated"):FireClient(player, "enderChest", true)
		end
		local used = {}
		for section = 1, Vault.MAX do
			used[section] = 0
			for index = 1, Vault.SLOTS do
				if profile.enderChest[Vault.slot(section, index)] then
					used[section] += 1
				end
			end
		end
		return HttpService:JSONEncode({ sections = Vault.unlocked(profile), used = used })
	end
	hook.Parent = ServerStorage
end

local function unbind(part: Instance)
	local binding = bindings[part]
	if binding then
		binding.connection:Disconnect()
		binding.attribute:Disconnect()
		binding.prompt:Destroy()
		if binding.info then
			binding.info:Destroy()
		end
		bindings[part] = nil
	end
end

local function bind(part: Instance)
	local id = caseId(part)
	if not part:IsA("BasePart") or bindings[part] or not id then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CasePrompt"
	-- the chest in the Хранилище building (scripts/build-vault.luau, attribute Vault) is the same ender chest
	require(Shared.PromptText).Set(
		prompt,
		"ActionText",
		if part:GetAttribute("Vault") then "vault_title" else containerTitle(id)
	)
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false -- usable from any side of the chest model
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	-- «Подробнее» under it [владелец 28.10]: the client opens the read-only list of drops (CasePreviewWindow)
	local info: ProximityPrompt? = nil
	if CASES[id] then
		local more = Instance.new("ProximityPrompt")
		more.Name = "CaseInfo"
		require(Shared.PromptText).Set(more, "ActionText", "case_info")
		require(Shared.PromptText).Set(more, "ObjectText", containerTitle(id))
		more.KeyboardKeyCode = Enum.KeyCode.R
		more.GamepadKeyCode = Enum.KeyCode.ButtonY
		more.HoldDuration = 0
		more.MaxActivationDistance = RANGE
		more.RequiresLineOfSight = false
		more.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
		more:SetAttribute("CaseId", id)
		-- [владелец 28.10: «кнопка накладывается друг на друга»] the two prompts of one part share a spot: «Открыть»
		-- moves up, «Подробнее» sits under it
		prompt.UIOffset = Vector2.new(0, -36)
		more.UIOffset = Vector2.new(0, 40)
		more.Parent = part
		info = more
	end
	bindings[part] = {
		prompt = prompt,
		info = info,
		attribute = part:GetAttributeChangedSignal("CaseId"):Connect(function()
			local current = caseId(part)
			prompt.Enabled = current ~= nil
			if current then
				require(Shared.PromptText).Set(
					prompt,
					"ActionText",
					if part:GetAttribute("Vault") then "vault_title" else containerTitle(current)
				)
			end
			if info then
				info.Enabled = current ~= nil and CASES[current] ~= nil
				if current and CASES[current] then
					info:SetAttribute("CaseId", current)
					require(Shared.PromptText).Set(info, "ObjectText", containerTitle(current))
				end
			end
		end),
		connection = prompt.Triggered:Connect(function(player)
			openChest(player, part)
		end),
	}
end

function CaseService.Start()
	if started then
		return
	end
	started = true
	Remotes.event("CaseOpened")
	Remotes.event("CaseUpdated")
	Remotes.event("CaseOpen").OnServerEvent:Connect(openCase)
	Remotes.event("CaseMove").OnServerEvent:Connect(move)
	Remotes.event("GangChestPage").OnServerEvent:Connect(turnPage)
	Remotes.event("VaultUnlock").OnServerEvent:Connect(unlockSection)
	debugHook()
	local function refreshShared(_actor: Player)
		for viewer, session in pairs(sessions) do
			if session.id == "gangChest" or session.id == "factionChest" then
				local index = session.index
				local slots = sharedSlots(session)
				if slots and sessions[viewer] == session and session.index == index then
					ProfileService.Mutate(viewer, function(p: any)
						p.caseContents[session.id] = deepCopy(slots)
						p.casePages = p.casePages or {}
						p.casePages[session.id] = index
					end)
					Remotes.event("CaseUpdated"):FireClient(viewer, session.id, true)
				end
			end
		end
	end
	Transfers.Start(refreshShared)
	task.spawn(function()
		while true do
			task.wait(5)
			refreshShared(nil :: any)
		end
	end)
	Remotes.event("CaseReveal").OnServerEvent:Connect(function(player: Player)
		local session = validate(player, "ancientCase")
		local profile = ProfileService.Get(player)
		if
			session
			and session.revealPending
			and profile
			and next(profile.caseContents.ancientCase or {})
		then
			session.revealPending = nil
			Remotes.event("CaseOpened"):FireClient(player, "ancientCase")
		end
	end)
	Remotes.event("CaseClose").OnServerEvent:Connect(function(player: Player, id: any)
		if validate(player, id) then
			close(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		openEpoch[player] = nil
		ancientRollUntil[player] = nil
		unlockAt[player] = nil
	end)
	local elapsed = 0
	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < 0.25 then
			return
		end
		elapsed = 0
		for player, session in pairs(sessions) do
			validate(player, session.id)
		end
	end)
	for _, tag in ipairs(TAGS) do
		CollectionService:GetInstanceAddedSignal(tag):Connect(function(part)
			unbind(part)
			bind(part)
		end)
		CollectionService:GetInstanceRemovedSignal(tag):Connect(function(part)
			unbind(part)
			if part:IsDescendantOf(game) then -- a destroyed gang house copy is not bound again
				bind(part)
			end
		end)
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bind(part)
		end
	end
end

return CaseService
