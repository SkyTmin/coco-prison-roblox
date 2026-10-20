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
local CASES: { [string]: { key: string, text: string } } = {
	ordinaryCase = { key = "ordinary_key", text = "ordinary_case" },
	ancientCase = { key = "ancient_key", text = "ancient_case" },
}
local TAGS = { "OrdinaryCase", "AncientCase", "EnderChest" }
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
	if
		not CollectionService:HasTag(part, "OrdinaryCase")
		and not CollectionService:HasTag(part, "AncientCase")
	then
		return nil
	end
	local attribute = part:GetAttribute("CaseId")
	if attribute ~= nil then
		return if typeof(attribute) == "string" and CASES[attribute] then attribute else nil
	end
	return if CollectionService:HasTag(part, "AncientCase") then "ancientCase" else "ordinaryCase"
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

local function openChest(player: Player, part: BasePart)
	local id = caseId(part)
	if not id or not near(player, part) or not ProfileService.Get(player) then
		return
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

local function toast(player: Player, key: string, ...: any)
	Remotes.event("Toast"):FireClient(player, Strings.t(key, Strings.localeOf(player), ...))
end

local function openCase(player: Player, id: any)
	local session = validate(player, id)
	if not session or session.id == "enderChest" or os.clock() - session.rolledAt < 0.4 then
		return
	end
	session.rolledAt = os.clock()
	local rewards = rewardsFor(session.id)
	if not rewards then
		toast(player, "case_locked")
		return
	end
	local money = 0
	local failure: string? = nil
	ProfileService.Mutate(player, function(p)
		local key = CASES[session.id].key
		if InventoryService.count(p, key) < 1 then
			failure = "case_no_key"
			return
		end
		-- Stage rewards using the inventory's stack limits, then place them in free chest slots.
		-- No existing chest stack or key is changed until the entire roll fits.
		local staged = table.clone(p)
		staged.inventory = {}
		for _ = 1, random:NextInteger(2, 4) do
			local reward = roll(rewards)
			local item, count, level = reward.id, 1, nil :: number?
			if item == "money" then
				money += random:NextInteger(
					math.floor((reward.min :: number) * Config.moneyScale + 0.5),
					math.floor((reward.max :: number) * Config.moneyScale + 0.5)
				)
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
	end)
	if failure then
		toast(player, failure)
	elseif money > 0 then
		toast(player, "case_money", Strings.money(money))
	end
	Remotes.event("CaseUpdated"):FireClient(player, session.id, true)
end

local function move(player: Player, id: any, rawFrom: any, rawTo: any)
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
	ProfileService.Mutate(player, function(p)
		local contents = contentsFor(p, session.id)
		local source = if from.container == "case" then contents else p.inventory
		local target = if to.container == "case" then contents else p.inventory
		if not source[from.index] then
			return
		end
		-- Reuse inventory merge/swap and stack limits for both containers.
		local staged = table.clone(p)
		staged.inventory = { [1] = source[from.index], [2] = target[to.index] }
		InventoryService.move(staged, 1, 2)
		source[from.index], target[to.index] = staged.inventory[1], staged.inventory[2]
	end)
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
		if typeof(id) == "string" and sessions[player] and sessions[player].id == id then
			close(player)
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
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
			bind(part)
		end)
		for _, part in ipairs(CollectionService:GetTagged(tag)) do
			bind(part)
		end
	end
end

return CaseService
