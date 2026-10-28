--!strict
-- Minecraft-style inventory: 36 slots (1..9 hotbar), stacks of 64 for blocks/consumables,
-- unstackable tools. Armor in 4 named slots. All operations run on the server.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Types = require(Shared.Types)

type Profile = Types.Profile
type ItemStack = Types.ItemStack

local SLOTS = 36
local STACK = 64
local ARMOR_SLOTS = { helmet = true, chestplate = true, leggings = true, boots = true }

local InventoryService = {}
InventoryService.SLOTS = SLOTS

function InventoryService.isStackable(id: string): boolean
	-- location passes are single items [владелец 22.10: «пропуск в подвал не должен стакаться»], so are the
	-- auto-sell and the injection [владелец 28.10: «автопродажа и инъекция не должны стакаться»]
	return Config.tools[id] == nil
		and id ~= "ancient_book"
		and id ~= "money_bag"
		and not id:match("_pass$")
		and id ~= "autosell"
		and id ~= "needs_injection"
		and id ~= "potion_drink" -- every potion has its own effects and brewer
		and id ~= "potion_splash"
end

-- Adds `count` of item; returns the amount that did not fit.
function InventoryService.add(profile: Profile, id: string, count: number, level: number?): number
	local remaining = count
	if InventoryService.isStackable(id) then
		for slot = 1, SLOTS do
			local stack = profile.inventory[slot]
			if stack and stack.id == id and stack.count < STACK then
				local take = math.min(STACK - stack.count, remaining)
				stack.count += take
				remaining -= take
				if remaining == 0 then
					return 0
				end
			end
		end
	end
	for slot = 1, SLOTS do
		if remaining == 0 then
			break
		end
		if not profile.inventory[slot] then
			local take = if InventoryService.isStackable(id) then math.min(STACK, remaining) else 1
			profile.inventory[slot] = {
				id = id,
				count = take,
				level = level,
				books = if level then {} else nil,
			}
			remaining -= take
		end
	end
	return remaining
end

-- True when `count` of the item fits without dropping anything.
function InventoryService.canAdd(profile: Profile, id: string, count: number): boolean
	local room = 0
	local stackable = InventoryService.isStackable(id)
	for slot = 1, SLOTS do
		local stack = profile.inventory[slot]
		if not stack then
			room += if stackable then STACK else 1
		elseif stackable and stack.id == id then
			room += STACK - stack.count
		end
		if room >= count then
			return true
		end
	end
	return false
end

function InventoryService.count(profile: Profile, id: string): number
	local total = 0
	for _, stack in pairs(profile.inventory) do
		if stack.id == id then
			total += stack.count
		end
	end
	return total
end

-- Removes up to `count`; returns how many were removed.
function InventoryService.remove(profile: Profile, id: string, count: number): number
	local left = count
	for slot = SLOTS, 1, -1 do
		local stack = profile.inventory[slot]
		if stack and stack.id == id then
			local take = math.min(stack.count, left)
			stack.count -= take
			left -= take
			if stack.count == 0 then
				profile.inventory[slot] = nil
			end
			if left == 0 then
				break
			end
		end
	end
	return count - left
end

function InventoryService.isSlot(n: any): boolean
	return typeof(n) == "number" and n == n and n == math.floor(n) and n >= 1 and n <= SLOTS
end

function InventoryService.move(profile: Profile, from: number, to: number, count: number?): boolean
	if from == to or not InventoryService.isSlot(from) or not InventoryService.isSlot(to) then
		return false
	end
	local a, b = profile.inventory[from], profile.inventory[to]
	-- Partial move (Minecraft right click / split / drag spread): only onto an empty slot or the same item.
	if count ~= nil and a then
		if
			typeof(count) ~= "number"
			or count ~= count
			or count < 1
			or count ~= math.floor(count)
		then
			return false
		end
		if count >= a.count then
			count = nil -- the whole stack: fall through to the ordinary move
		elseif not InventoryService.isStackable(a.id) then
			return false
		elseif b == nil then
			local piece = table.clone(a)
			piece.count = count
			profile.inventory[to] = piece
			a.count -= count
			return true
		elseif b.id == a.id then
			local take = math.min(STACK - b.count, count)
			if take <= 0 then
				return false
			end
			b.count += take
			a.count -= take
			return true
		else
			return false
		end
	end
	if a and b and a.id == b.id and InventoryService.isStackable(a.id) then
		local take = math.min(STACK - b.count, a.count)
		b.count += take
		a.count -= take
		if a.count == 0 then
			profile.inventory[from] = nil
		end
		return true
	end
	profile.inventory[from], profile.inventory[to] = b, a
	return true
end

-- Tool currently in hand: the stack in the selected hotbar slot if it is a tool.
function InventoryService.heldTool(profile: Profile): (string?, number)
	local stack = profile.inventory[profile.selectedSlot]
	if stack and Config.tools[stack.id] then
		return stack.id, stack.level or 1
	end
	return nil, 0
end

-- Best tool of a kind anywhere in the inventory (used by the upgrade menu).
function InventoryService.findTool(profile: Profile, id: string): (number?, ItemStack?)
	local bestSlot, best: ItemStack? = nil, nil
	for slot, stack in pairs(profile.inventory) do
		if stack.id == id and (not best or (stack.level or 1) > (best.level or 1)) then
			bestSlot, best = slot, stack
		end
	end
	return bestSlot, best
end

function InventoryService.equipArmor(profile: Profile, slot: number): boolean
	if not InventoryService.isSlot(slot) then
		return false
	end
	local stack = profile.inventory[slot]
	if not stack or not ARMOR_SLOTS[stack.id] then
		return false
	end
	local current = profile.armor[stack.id]
	profile.armor[stack.id] = stack
	profile.inventory[slot] = current
	return true
end

-- Takes a worn piece off into an inventory slot (a given empty slot, else the first free one).
function InventoryService.unequipArmor(profile: Profile, part: string, slot: number?): boolean
	local worn = profile.armor[part]
	if not worn then
		return false
	end
	local target = if slot
			and InventoryService.isSlot(slot)
			and not profile.inventory[slot]
		then slot
		else nil
	if not target then
		for index = 1, 36 do
			if not profile.inventory[index] then
				target = index
				break
			end
		end
	end
	if not target then
		return false
	end
	profile.inventory[target] = worn
	profile.armor[part] = nil
	return true
end

-- Sells every block stack; returns money units earned.
-- blocks from mines far above the player stay in the bag [сеть TG/25]; the second result counts them
-- sells every sellable block: (money, items kept because their block is locked, items sold)
function InventoryService.sellAll(profile: Profile, multiplier: number): (number, number, number)
	local total, locked, count = 0, 0, 0
	for slot, stack in pairs(profile.inventory) do
		local block = Config.block(stack.id)
		if block and block.sellable ~= false and Config.blockLocked(stack.id, profile.level) then
			locked += stack.count
		elseif block and block.sellable ~= false then
			total += math.floor(
				block.basePrice * Config.moneyScale * multiplier * stack.count + 0.5
			)
			count += stack.count
			profile.inventory[slot] = nil
		end
	end
	return total, locked, count
end

return InventoryService
