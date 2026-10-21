--!strict
-- Personal persistent chests. Opening the UI never spends a key or grants rewards.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)
local ArtifactService = require(script.Parent.ArtifactService)
local Types = require(Shared.Types)

type Reward = {
	id: string,
	weight: number,
	items: { string }?,
	count: { number }?,
	min: number?,
	max: number?,
}
type Binding = {
	prompt: ProximityPrompt,
	connection: RBXScriptConnection,
	attribute: RBXScriptConnection,
}
type Session = { id: string, part: BasePart, rolledAt: number, tokens: number, tokenAt: number }
type Address = { container: "case" | "inv", index: number }
local CASES: { [string]: { tag: string, text: string } } = {
	ordinaryCase = { tag = "OrdinaryCase", text = "ordinary_case" },
	ancientCase = { tag = "AncientCase", text = "ancient_case" },
	artifactCase = { tag = "ArtifactCase", text = "artifact_case" },
	nicknameCase = { tag = "NicknameCase", text = "nickname_case" },
}
local TAGS = { "OrdinaryCase", "AncientCase", "ArtifactCase", "NicknameCase", "EnderChest" }
local ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local RANGE = 12
local random = Random.new()
local bindings: { [Instance]: Binding } = {}
local sessions: { [Player]: Session } = {}
local started = false
local CaseService = {}

local function containerTitle(id: string): string
	return if id == "enderChest" then "ender_chest" else CASES[id].text
end

local function contentsFor(profile: Types.Profile, id: string): { [number]: Types.ItemStack }
	return if id == "enderChest" then profile.enderChest else profile.caseContents[id]
end

local function caseId(part: Instance): string?
	if CollectionService:HasTag(part, "EnderChest") then
		return "enderChest"
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

local function close(player: Player)
	local session = sessions[player]
	if session then
		sessions[player] = nil
		Remotes.event("CaseUpdated"):FireClient(player, session.id, false)
	end
end

local function validate(player: Player, id: any): Session?
	if typeof(id) ~= "string" or (not CASES[id] and id ~= "enderChest") then
		return nil
	end
	local session = sessions[player]
	if not session or session.id ~= id then
		return nil
	end
	if
		caseId(session.part) ~= id
		or not near(player, session.part)
		or not ProfileService.Get(player)
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

local function applyNickname(player: Player)
	local profile = ProfileService.Get(player)
	local character = player.Character
	local humanoid = if character then character:FindFirstChildOfClass("Humanoid") else nil
	if humanoid and profile and typeof(profile.nickname) == "string" and profile.nickname ~= "" then
		humanoid.DisplayName = "[" .. profile.nickname .. "] " .. player.DisplayName
	end
end

local function openChest(player: Player, part: BasePart)
	local id = caseId(part)
	local profile = ProfileService.Get(player)
	if not id or not near(player, part) or not profile then
		return
	end
	if id ~= "enderChest" then
		-- Without a key the chest stays shut unless rewards from an earlier opening are still inside.
		local keys = acceptedKeys(id)
		local contents = profile.caseContents[id]
		if not hasAnyKey(profile, keys) and (contents == nil or next(contents) == nil) then
			toast(
				player,
				"case_need_key",
				Strings.itemName(keys[1] or "ordinary_key", nil, Strings.localeOf(player))
			)
			return
		end
	end
	sessions[player] =
		{ id = id, part = part, rolledAt = -math.huge, tokens = 80, tokenAt = os.clock() }
	ProfileService.Mutate(player, function(p)
		if id ~= "enderChest" then
			p.caseContents[id] = p.caseContents[id] or {}
		end
	end)
	Remotes.event("CaseOpened"):FireClient(player, id)
end

local function weightedKey(weights: { [string]: number }): string
	local choices: { Reward } = {}
	for key, weight in pairs(weights) do
		table.insert(choices, { id = key, weight = weight })
	end
	table.sort(choices, function(a, b)
		return a.id < b.id
	end)
	return roll(choices).id
end

local function ancientBook(improved: boolean): Types.ItemStack
	local rules = Config.keys.ancientCase
	-- rarity belongs to the book type [меню]: roll the rarity, then a book of that rarity
	local rarity = weightedKey(rules.rarity)
	local effects: { string } = {}
	local any: { string } = {}
	for id in pairs(Config.books.effects) do
		local entry = Config.books.catalog[id]
		table.insert(any, id)
		if entry and entry.rarity == rarity then
			table.insert(effects, id)
		end
	end
	if #effects == 0 then
		effects = any
	end
	table.sort(effects)
	local effect = effects[random:NextInteger(1, #effects)]
	local catalogEntry = Config.books.catalog[effect]
	local maxLevel = #Config.books.effects[effect]
	local level = if improved
		then maxLevel
		else math.min(maxLevel, tonumber(weightedKey(rules.level)) :: number)
	local chance = if improved then rules.improvedApplyChance else rules.applyChance
	return {
		id = "ancient_book",
		count = 1,
		level = level,
		books = { { id = effect, level = level } },
		rarity = if catalogEntry then catalogEntry.rarity else rarity,
		applyChance = random:NextInteger(chance[1], chance[2]),
	}
end

local function openCase(player: Player, id: any, requestedKey: any)
	local session = validate(player, id)
	if not session or session.id == "enderChest" or os.clock() - session.rolledAt < 0.4 then
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
		-- The nickname list itself is ours (scripts/design-decisions.json → keys.nicknameCase) [решение].
		local names = Config.keys.nicknameCase and Config.keys.nicknameCase.nicknames
		local granted: string? = nil
		local failure: string? = nil
		ProfileService.Mutate(player, function(p)
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
			local pool: { string } = {}
			for _, name in ipairs(if typeof(names) == "table" then names else {}) do
				if not table.find(owned, name) then
					table.insert(pool, name)
				end
			end
			if #pool == 0 then
				failure = "nickname_all_owned" -- the key is not spent
				return
			end
			local pick = pool[random:NextInteger(1, #pool)]
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
			applyNickname(player)
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
	ProfileService.Mutate(player, function(p)
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
			staged.inventory[1] = ancientBook(key == "improved_ancient_key")
		end
		local rolls = if session.id == "ancientCase"
			then 0
			elseif session.id == "ordinaryCase" then random:NextInteger(2, 4)
			else 1
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
					item, level = "sword", 1
				elseif item == "rare_wooden_pickaxe_silk_touch" then
					item, level = "pickaxe", 1
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
	if failure then
		toast(player, failure)
	elseif money > 0 then
		toast(player, "case_money", Strings.money(money))
	end
	ArtifactService.Notify(player, artifactNotices)
	Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
end

local function move(player: Player, id: any, rawFrom: any, rawTo: any, rawCount: any)
	local count = if typeof(rawCount) == "number" then rawCount else nil
	local session = validate(player, id)
	local from, to = address(rawFrom), address(rawTo)
	if
		not session
		or not from
		or not to
		or (from.container == to.container and from.index == to.index)
	then
		return
	end
	local now = os.clock()
	session.tokens = math.min(80, session.tokens + (now - session.tokenAt) * 40)
	session.tokenAt = now
	if session.tokens < 1 then
		return
	end
	session.tokens -= 1
	local claimedMoney = 0
	ProfileService.Mutate(player, function(p)
		local contents = contentsFor(p, session.id)
		local source = if from.container == "case" then contents else p.inventory
		local target = if to.container == "case" then contents else p.inventory
		if not source[from.index] then
			return
		end
		local stack = source[from.index]
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
				source[from.index] = nil
				p.coins += amount
				claimedMoney = amount
			end
			return
		end
		-- Reuse inventory merge/swap and stack limits for both containers.
		local staged = table.clone(p)
		staged.inventory = { [1] = source[from.index], [2] = target[to.index] }
		InventoryService.move(staged, 1, 2, count)
		source[from.index], target[to.index] = staged.inventory[1], staged.inventory[2]
	end)
	if claimedMoney > 0 then
		toast(player, "case_money", Strings.money(claimedMoney))
	end
	Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
end

local function unbind(part: Instance)
	local binding = bindings[part]
	if binding then
		binding.connection:Disconnect()
		binding.attribute:Disconnect()
		binding.prompt:Destroy()
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
	prompt.ActionText = Strings.t(containerTitle(id))
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = RANGE
	prompt.RequiresLineOfSight = false -- usable from any side of the chest model
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OnePerButton
	prompt.Parent = part
	bindings[part] = {
		prompt = prompt,
		attribute = part:GetAttributeChangedSignal("CaseId"):Connect(function()
			local current = caseId(part)
			prompt.Enabled = current ~= nil
			if current then
				prompt.ActionText = Strings.t(containerTitle(current))
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
	Remotes.event("CaseClose").OnServerEvent:Connect(function(player: Player, id: any)
		if validate(player, id) then
			close(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
	end)
	local function watchNickname(player: Player)
		player.CharacterAdded:Connect(function()
			task.spawn(function()
				for _ = 1, 30 do
					if ProfileService.Get(player) then
						applyNickname(player)
						return
					end
					task.wait(1)
				end
			end)
		end)
	end
	Players.PlayerAdded:Connect(watchNickname)
	for _, player in ipairs(Players:GetPlayers()) do
		watchNickname(player)
	end
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
			bind(part)
		end)
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bind(part)
		end
	end
end

return CaseService
