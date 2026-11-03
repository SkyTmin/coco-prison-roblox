--!strict
local CreativeBooks = {}
CreativeBooks.ITEMS = {
	"pickaxe",
	"shovel",
	"axe",
	"shears",
	"sword",
	"bow",
	"helmet",
	"chestplate",
	"leggings",
	"boots",
}
local RARITY = { common = 1, uncommon = 2, rare = 3, epic = 4, legendary = 5, mythic = 6 }

function CreativeBooks.groups(catalog: any, effects: any, nameOf: (string) -> string)
	local groups = {}
	for _, itemId in ipairs(CreativeBooks.ITEMS) do
		local books = {}
		for id, card in pairs(catalog) do
			if effects[id] and table.find(card.items or {}, itemId) then
				table.insert(books, id)
			end
		end
		table.sort(books, function(a, b)
			local ra, rb = RARITY[catalog[a].rarity] or 0, RARITY[catalog[b].rarity] or 0
			if ra ~= rb then
				return ra > rb
			end
			local na, nb = nameOf(a), nameOf(b)
			return if na == nb then a < b else na < nb
		end)
		if #books > 0 then
			table.insert(groups, { itemId = itemId, books = books })
		end
	end
	return groups
end

return CreativeBooks
