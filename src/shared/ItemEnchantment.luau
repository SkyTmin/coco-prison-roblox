--!strict
-- Read-only visual truth, shared by inventory and the server's compact held-item attribute.
local Config = require(script.Parent.Config)
local ItemEnchantment = {}
function ItemEnchantment.active(stack: any): boolean
	if typeof(stack) ~= "table" or typeof(stack.id) ~= "string" or not Config.tools[stack.id] then
		return false
	end
	local level = if typeof(stack.level) == "number" and stack.level == stack.level
		then stack.level
		else 1
	if Config.isEnchanted(stack.id, level) or Config.flameForLevel(stack.id, level) > 0 then
		return true
	end
	if typeof(stack.books) ~= "table" then
		return false
	end
	for _, book in stack.books do
		if typeof(book) ~= "table" or typeof(book.id) ~= "string" then
			continue
		end
		local card = Config.books.catalog[book.id]
		local effects = Config.books.effects[book.id]
		if
			card
			and effects
			and table.find(card.items or {}, stack.id)
			and typeof(book.level) == "number"
			and book.level % 1 == 0
			and book.level >= 1
			and book.level <= #effects
		then
			return true
		end
	end
	return false
end
return ItemEnchantment
