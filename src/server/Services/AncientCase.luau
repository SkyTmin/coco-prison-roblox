--!strict
-- Server-owned book rolls and atomic delivery. The case is the overflow container only.
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AncientRoll = require(Shared.AncientRoll)
local Types = require(Shared.Types)
local InventoryService = require(script.Parent.InventoryService)

local AncientCase = {}

function AncientCase.roll(improved: boolean, random: Random): Types.ItemStack
	return AncientRoll.roll(improved, random)
end

-- Call only inside ProfileService.Mutate. A consumed last key frees a slot before testing capacity.
-- Work on cloned stacks so a full bag AND chest never consumes a key or alters an existing stack.
function AncientCase.deliver(profile: Types.Profile, key: string, book: Types.ItemStack): string
	local staged = table.clone(profile)
	staged.inventory = {}
	for slot, stack in pairs(profile.inventory) do
		staged.inventory[slot] = table.clone(stack)
	end
	if InventoryService.remove(staged, key, 1) ~= 1 then
		return "case_no_key"
	end
	local reward = { book }
	local destination = "inventory"
	local contents = table.clone(profile.caseContents.ancientCase or {})
	if InventoryService.transfer(reward, 1, staged.inventory, 1, InventoryService.SLOTS) == 0 then
		destination = "case"
		if InventoryService.transfer(reward, 1, contents, 1, 27) == 0 then
			return "case_full"
		end
	end
	profile.inventory = staged.inventory
	profile.caseContents.ancientCase = contents
	return destination
end

return AncientCase
