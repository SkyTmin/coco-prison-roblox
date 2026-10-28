--!strict
-- Ancient book rules shared by the server (BookService) and the book window (client BookWindow): which item a book
-- fits, the limits, the conflicts, and the strength of a book on an item [GAME-DESIGN §10; вики: лимиты меч 4,
-- остальное 2; клиент: одно зачарование одного типа на предмет; сеть: Халк × Укрепление, Мороз × Пожар].
local Config = require(script.Parent.Config)
local Types = require(script.Parent.Types)

local Books = {}

Books.BOOK = "ancient_book"
Books.POWDER = "ancient_powder"
Books.DISPELLER = "dispeller"
-- one powder adds this many percent to a book's apply chance [меню 26.10: «Эффективность Древнего порошка — 10%»]
Books.POWDER_STEP = math.floor((Config.books.donatePowder or 0.1) * 100 + 0.5)
-- the share of the boss damage the boss books (Старатель, Общак) need [вики: «если ваш урон не меньше 35 %»]
Books.BOSS_SHARE = 0.35

Books.ARMOR = { "helmet", "chestplate", "leggings", "boots" }
local IS_ARMOR = { helmet = true, chestplate = true, leggings = true, boots = true }
local IS_TOOL = { pickaxe = true, axe = true, shovel = true, shears = true }

-- the item ids a held book item opens the window for
function Books.isUsable(id: string?): boolean
	return id == Books.BOOK or id == Books.POWDER or id == Books.DISPELLER
end

-- how many ancient books the item can hold (0 = none)
function Books.limit(itemId: string): number
	local limits = Config.books.limits
	if itemId == "sword" then
		return limits.sword
	elseif itemId == "bow" then
		return limits.bow
	elseif IS_ARMOR[itemId] then
		return limits.armor
	elseif IS_TOOL[itemId] then
		return limits.tool
	end
	return 0
end

-- the level of a book on an item (0 = not on it)
function Books.level(stack: Types.ItemStack?, id: string): number
	if not stack or not stack.books then
		return 0
	end
	for _, book in ipairs(stack.books) do
		if book.id == id then
			return book.level
		end
	end
	return 0
end

-- the number of a book at its level on the item (a chance, a share or a count; 0 = not on it)
function Books.value(stack: Types.ItemStack?, id: string): number
	local level = Books.level(stack, id)
	local values = Config.books.effects[id]
	if level <= 0 or not values or #values == 0 then
		return 0
	end
	return values[math.clamp(level, 1, #values)] or 0
end

-- the item in the hand
function Books.held(profile: Types.Profile): Types.ItemStack?
	return profile.inventory[profile.selectedSlot]
end

-- the sum of a book over the worn armor
function Books.worn(profile: Types.Profile, id: string): number
	local sum = 0
	for _, piece in ipairs(Books.ARMOR) do
		sum += Books.value(profile.armor and profile.armor[piece], id)
	end
	return sum
end

-- a weapon book of the sword / bow in the hand: a book belongs to the one item it was put on [владелец 28.10: «если
-- купит меч новый, чтобы не накладывалась чарка на новый меч»] — another sword in the bag does not count
function Books.inHand(profile: Types.Profile, id: string): number
	local stack = Books.held(profile)
	if stack and (stack.id == "sword" or stack.id == "bow") then
		return Books.value(stack, id)
	end
	return 0
end

-- why a book cannot go on the item (a Strings key), nil when it can
function Books.refusal(book: Types.ItemStack, target: Types.ItemStack): string?
	local entry = book.books and book.books[1]
	local card = entry and Config.books.catalog[entry.id]
	if book.id ~= Books.BOOK or not entry or not card then
		return "book_invalid"
	end
	if not table.find(card.items, target.id) then
		return "book_wrong_item"
	end
	if Books.level(target, entry.id) > 0 then
		return "book_already"
	end
	for _, other in ipairs(card.conflicts or {}) do
		if Books.level(target, other) > 0 then
			return "book_conflict"
		end
	end
	if #(target.books or {}) >= Books.limit(target.id) then
		return "book_limit"
	end
	return nil
end

-- why powder cannot go on the stack, nil when it can
function Books.powderRefusal(target: Types.ItemStack): string?
	if target.id ~= Books.BOOK or not target.books or #target.books == 0 then
		return "book_powder_only_books"
	end
	if (target.applyChance or 100) >= 100 then
		return "book_chance_full"
	end
	return nil
end

-- why the dispeller cannot clear the item, nil when it can
function Books.dispelRefusal(target: Types.ItemStack): string?
	if target.id == Books.BOOK or not target.books or #target.books == 0 then
		return "book_nothing_to_dispel"
	end
	return nil
end

-- the refusal for any of the three items used on a target
function Books.refusalFor(source: Types.ItemStack, target: Types.ItemStack): string?
	if source.id == Books.BOOK then
		return Books.refusal(source, target)
	elseif source.id == Books.POWDER then
		return Books.powderRefusal(target)
	elseif source.id == Books.DISPELLER then
		return Books.dispelRefusal(target)
	end
	return "book_invalid"
end

return Books
