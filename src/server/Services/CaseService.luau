--!strict
-- Ordinary case rewards use generated weights; consume the inventory key and grant atomically.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Remotes = require(Shared.Remotes)
local Strings = require(Shared.Strings)
local Types = require(Shared.Types)
local ProfileService = require(script.Parent.ProfileService)
local InventoryService = require(script.Parent.InventoryService)

type Drop = { id: string, count: number }
type Reward = {
	id: string,
	weight: number,
	items: { string }?,
	count: { number }?,
	min: number?,
	max: number?,
}
type Binding = { prompt: ProximityPrompt, connection: RBXScriptConnection }

local REWARDS: { Reward } = Config.keys.ordinaryCase
local ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local RANGE = 12
local random = Random.new()
local bindings: { [Instance]: Binding } = {}
local started = false
local CaseService = {}

local function roll(): Reward
	local total = 0
	for _, reward in ipairs(REWARDS) do
		total += reward.weight
	end
	local value = random:NextNumber() * total
	for _, reward in ipairs(REWARDS) do
		value -= reward.weight
		if value < 0 then
			return reward
		end
	end
	return REWARDS[#REWARDS]
end

local function openCase(player: Player, part: BasePart)
	if not part:IsDescendantOf(workspace) or not CollectionService:HasTag(part, "OrdinaryCase") then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return
	end
	if not ((root.Position - part.Position).Magnitude <= RANGE) then
		return
	end
	local profile = ProfileService.Get(player)
	if not profile then
		return
	end
	local locale = Strings.localeOf(player)
	if InventoryService.count(profile, "ordinary_key") < 1 then
		Remotes.event("Toast"):FireClient(player, Strings.t("case_no_key", locale))
		return
	end
	local drops: { Drop } = {}
	local full = false
	ProfileService.Mutate(player, function(p)
		InventoryService.remove(p, "ordinary_key", 1)
		for _ = 1, random:NextInteger(2, 4) do
			local reward = roll()
			local id, count = reward.id, 1
			local level: number? = nil
			if id == "money" then
				local minimum = math.floor((reward.min :: number) * Config.moneyScale + 0.5)
				local maximum = math.floor((reward.max :: number) * Config.moneyScale + 0.5)
				count = random:NextInteger(minimum, maximum)
				p.coins += count
			elseif id == "basement_pass" then
				p.passes.basement = true
			else
				if id == "food" then
					local items = reward.items :: { string }
					local amounts = reward.count :: { number }
					id = items[random:NextInteger(1, #items)]
					count = random:NextInteger(amounts[1], amounts[2])
				elseif id == "leather_armor_piece" then
					id, level = ARMOR[random:NextInteger(1, #ARMOR)], 1
				elseif id == "wooden_sword_or_bow" then
					id, level = "sword", 1
				elseif id == "rare_wooden_pickaxe_silk_touch" then
					id, level = "pickaxe", 1
				end
				local remaining: number
				if reward.id == "rare_wooden_pickaxe_silk_touch" then
					-- InventoryService.add cannot receive books; insert the new tool in a free slot.
					remaining = 1
					for slot = 1, InventoryService.SLOTS do
						if not p.inventory[slot] then
							local stack: Types.ItemStack = {
								id = id,
								count = 1,
								level = 1,
								books = { { id = "silk_touch", level = 1 } },
							}
							p.inventory[slot] = stack
							remaining = 0
							break
						end
					end
				else
					remaining = InventoryService.add(p, id, count, level)
				end
				count -= remaining
				full = remaining > 0
			end
			if count > 0 then
				table.insert(drops, { id = id, count = count })
			end
			-- Keep everything that fit; discard overflow and subsequent rewards without refund.
			if full then
				break
			end
		end
	end)
	local descriptions: { string } = {}
	for _, drop in ipairs(drops) do
		if drop.id == "money" then
			table.insert(descriptions, Strings.money(drop.count) .. " $")
		else
			local level = if Config.tools[drop.id] then 1 else nil
			table.insert(
				descriptions,
				Strings.itemName(drop.id, level, locale) .. " ×" .. drop.count
			)
		end
	end
	Remotes.event("CaseOpened"):FireClient(player, drops)
	if #descriptions > 0 then
		Remotes.event("Toast")
			:FireClient(player, Strings.t("case_found", locale, table.concat(descriptions, ", ")))
	end
	if full then
		Remotes.event("Toast"):FireClient(player, Strings.t("bag_full", locale))
	end
end

local function unbind(part: Instance)
	local binding = bindings[part]
	if binding then
		binding.connection:Disconnect()
		binding.prompt:Destroy()
		bindings[part] = nil
	end
end

local function bind(part: Instance)
	if not part:IsA("BasePart") or bindings[part] then
		return
	end
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OrdinaryCasePrompt"
	prompt.ActionText = Strings.t("ordinary_case")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = RANGE
	prompt.Parent = part
	bindings[part] = {
		prompt = prompt,
		connection = prompt.Triggered:Connect(function(player)
			openCase(player, part)
		end),
	}
end

function CaseService.Start()
	if started then
		return
	end
	started = true
	CollectionService:GetInstanceAddedSignal("OrdinaryCase"):Connect(bind)
	CollectionService:GetInstanceRemovedSignal("OrdinaryCase"):Connect(unbind)
	for _, part in ipairs(CollectionService:GetTagged("OrdinaryCase")) do
		bind(part)
	end
end

return CaseService
