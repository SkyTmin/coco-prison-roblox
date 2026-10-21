--!strict
-- Minecraft-style item tooltip, built from the configs so that every item gets its properties without
-- extra code: tools and armor (vanilla damage / attack speed / mining speed / armor from tools.json),
-- enchantments (upgrade level and ancient books), blocks (harvest tool, buyer price), food, need
-- consumables, case keys, ancient books (catalog in books.json), money bags.
-- A new item needs only its name item_<id> (and, if the configs can't say what it does, a description
-- desc_<id>) in Strings in all four locales; a new ancient book needs books.catalog + effects +
-- book_<id> / book_desc_<id>. ItemInfo.audit() lists what is missing (warned in Studio on start).
-- Colours are Minecraft's formatting codes.

local Config = require(script.Parent.Config)
local Strings = require(script.Parent.Strings)
local Types = require(script.Parent.Types)

export type Line = { text: string, color: Color3, small: boolean? }

local ItemInfo = {}

local WHITE = Color3.fromRGB(255, 255, 255)
local GRAY = Color3.fromRGB(170, 170, 170)
local DARK_GRAY = Color3.fromRGB(110, 110, 110)
local BLUE = Color3.fromRGB(85, 85, 255)
local DARK_GREEN = Color3.fromRGB(0, 170, 0)
local GREEN = Color3.fromRGB(85, 255, 85)
local AQUA = Color3.fromRGB(85, 255, 255)
local RED = Color3.fromRGB(255, 85, 85)
local LIGHT_PURPLE = Color3.fromRGB(255, 85, 255)
local YELLOW = Color3.fromRGB(255, 255, 85)
local GOLD = Color3.fromRGB(255, 170, 0)

ItemInfo.colors = { name = WHITE, enchanted = AQUA }

-- Book rarity colours: common white, rare aqua, legendary light purple (Minecraft rarities)
local RARITY_COLORS: { [string]: Color3 } =
	{ common = WHITE, rare = AQUA, legendary = LIGHT_PURPLE }
local ARMOR_SLOT: { [string]: number } = { helmet = 1, chestplate = 2, leggings = 3, boots = 4 }
local CASE_NAMES: { [string]: string } = {
	ordinaryCase = "ordinary_case",
	ancientCase = "ancient_case",
	artifactCase = "artifact_case",
	nicknameCase = "nickname_case",
}
local ROMAN = { "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X" }

local function roman(n: number): string
	return ROMAN[n] or tostring(n)
end

-- 1.6, 4, 2.5 — no trailing zeros, decimal comma in Russian/Spanish/French like Minecraft's locales
local function number(value: number, locale: string): string
	local text = string.format("%.2f", value):gsub("0+$", ""):gsub("%.$", "")
	if locale ~= "en" then
		text = text:gsub("%.", ",")
	end
	return text
end

-- book strength for a level: fractions are chances/percentages, whole numbers are hearts/blocks
local function strength(value: number?, locale: string): string
	if not value then
		return "?"
	end
	if value < 1 then
		return number(value * 100, locale) .. (if locale == "en" then "%" else " %")
	end
	return number(value, locale)
end

local function bookLimit(id: string): number
	local limits = Config.books.limits
	if id == "sword" then
		return limits.sword
	elseif ARMOR_SLOT[id] then
		return limits.armor
	elseif id == "bow" then
		return limits.bow
	end
	return limits.tool
end

-- "Барыга II" in the locale
function ItemInfo.bookName(bookId: string, level: number, locale: string): string
	local key = "book_" .. bookId
	local name = if Strings.has(key, locale) then Strings.t(key, locale) else bookId
	return name .. " " .. roman(level)
end

local function bookDescription(bookId: string, level: number, locale: string): string?
	local key = "book_desc_" .. bookId
	if not Strings.has(key, locale) then
		return nil
	end
	local levels = Config.books.effects[bookId]
	local value = if typeof(levels) == "table" then levels[level] else nil
	return Strings.t(key, locale, strength(value, locale))
end

-- Lines top to bottom; the first one is the name.
function ItemInfo.lines(stack: Types.ItemStack, locale: string): { Line }
	local lines: { Line } = {}
	local function add(text: string, color: Color3?, small: boolean?)
		table.insert(lines, { text = text, color = color or GRAY, small = small })
	end
	local function t(key: string, ...: any): string
		return Strings.t(key, locale, ...)
	end
	local id = stack.id
	local tool = Config.tools[id]
	local block = Config.block(id)
	local books = stack.books or {}
	local vanilla = Config.vanilla

	-- name: books by rarity, enchanted gear in aqua (Minecraft), everything else white
	local nameColor = WHITE
	local catalog = Config.books.catalog or {}
	if id == "ancient_book" then
		local first = books[1]
		local rarity = stack.rarity or (first and catalog[first.id] and catalog[first.id].rarity)
		nameColor = RARITY_COLORS[rarity or "common"] or WHITE
	elseif (tool and stack.level and Config.isEnchanted(id, stack.level)) or #books > 0 then
		nameColor = AQUA
	end
	-- a book shows its enchantment on the next line, so its name carries no level
	add(
		Strings.itemFullName(id, if id == "ancient_book" then nil else stack.level, locale),
		nameColor
	)

	if tool then
		local level = stack.level or 1
		local material = Config.materialForLevel(level)
		local enchant = Config.enchantForLevel(id, level)
		local slot = ARMOR_SLOT[id]
		add(
			t(
				if slot
					then "tip_kind_armor"
					elseif id == "sword" then "tip_kind_weapon"
					else "tip_kind_tool"
			),
			DARK_GRAY,
			true
		)
		if enchant > 0 and tool.enchant then
			add(t("enchant_" .. tool.enchant) .. " " .. roman(enchant), GRAY)
		end
		for _, book in ipairs(books) do
			add(ItemInfo.bookName(book.id, book.level, locale), LIGHT_PURPLE)
			local description = bookDescription(book.id, book.level, locale)
			if description then
				add("  " .. description, DARK_GRAY, true)
			end
		end
		add("")
		if slot then
			add(t("tip_on_body"), GRAY)
			local points = vanilla.armorPoints[material] and vanilla.armorPoints[material][slot]
			if points then
				add(" " .. t("tip_armor", number(points, locale)), BLUE)
			end
			local toughness = vanilla.armorToughness[material] or 0
			if toughness > 0 then
				add(" " .. t("tip_toughness", number(toughness, locale)), BLUE)
			end
		else
			add(t("tip_main_hand"), GRAY)
			local damage, speed
			if id == "sword" then
				damage = vanilla.swordDamage[material] + (vanilla.sharpnessBonus[enchant + 1] or 0)
				speed = vanilla.attackSpeed.sword
			elseif vanilla.toolDamage[id] then
				damage = vanilla.toolDamage[id][material]
				local s = vanilla.attackSpeed[id]
				speed = if typeof(s) == "table" then s[material] else s
			end
			if damage then
				add(" " .. t("tip_attack_damage", number(damage, locale)), DARK_GREEN)
			end
			if speed then
				add(" " .. t("tip_attack_speed", number(speed, locale)), DARK_GREEN)
			end
			if tool.enchant == "efficiency" then
				-- the same speed Config.breakTime uses [ваниль]
				local mining = vanilla.toolSpeed[material]
					+ (if enchant > 0 then enchant * enchant + 1 else 0)
				add(" " .. t("tip_mining_speed", number(mining, locale)), DARK_GREEN)
			end
		end
		add("")
		add(t("tip_upgrade_level", level, #tool.upgrades + 1), GRAY)
		add(t("tip_ancient_slots", #books, bookLimit(id)), GRAY)
	elseif id == "ancient_book" then
		add(t("tip_kind_book"), DARK_GRAY, true)
		local book = books[1]
		if book then
			local entry = catalog[book.id]
			local rarity = stack.rarity or (entry and entry.rarity) or "common"
			add(ItemInfo.bookName(book.id, book.level, locale), RARITY_COLORS[rarity] or WHITE)
			if Strings.has("rarity_" .. rarity, locale) then
				add(t("rarity_" .. rarity), RARITY_COLORS[rarity] or WHITE)
			end
			local description = bookDescription(book.id, book.level, locale)
			if description then
				add(description, GRAY)
			end
			if entry and entry.items then
				local names = {}
				for _, itemId in ipairs(entry.items) do
					table.insert(names, Strings.itemName(itemId, nil, locale))
				end
				add(t("tip_book_targets", table.concat(names, ", ")), GRAY)
			end
		end
		if stack.applyChance then
			add(t("tip_apply_chance", stack.applyChance), YELLOW)
		end
	else
		local food = Config.rules.survival.food[id]
		local need: string? = nil
		for _, candidate in ipairs({ "hygiene", "sleep", "toilet" }) do
			if Config.needs[candidate].consumable == id then
				need = candidate
			end
		end
		local opens: { string } = {}
		for caseId, keys in pairs(Config.keys.caseKeys or {}) do
			local list = if typeof(keys) == "table" then keys else { keys }
			if table.find(list, id) and CASE_NAMES[caseId] then
				table.insert(opens, t(CASE_NAMES[caseId]))
			end
		end
		table.sort(opens)
		local kind = if block and not food
			then "tip_kind_block"
			elseif food then "tip_kind_food"
			elseif #opens > 0 then "tip_kind_key"
			elseif need then "tip_kind_consumable"
			else "tip_kind_item"
		add(t(kind), DARK_GRAY, true)
		if typeof(food) == "number" then
			add(t("tip_food", food), GREEN)
			if id == "golden_apple" then
				add(t("tip_heals", 4), GREEN) -- NeedsService: +4 hearts
			end
		end
		if need then
			add(t("tip_restores_need", t("need_" .. need)), GREEN)
		end
		for _, name in ipairs(opens) do
			add(t("tip_opens", name), GRAY)
		end
		if stack.coins then
			add(t("tip_contains_money", Strings.money(stack.coins)), YELLOW)
		end
		if block and not block.itemOnly then
			if block.tool == "any" then
				add(t("tip_block_any_tool"), GRAY)
			else
				add(t("tip_block_tool", Strings.itemName(block.tool, nil, locale)), GRAY)
			end
		end
		if block then
			if block.sellable == false then
				add(t("tip_not_sellable"), RED)
			elseif block.basePrice and block.basePrice > 0 then
				add(t("tip_sell_price", Strings.money(block.basePrice * Config.moneyScale)), GOLD)
			end
		end
	end
	local descKey = "desc_" .. id
	if Strings.has(descKey, locale) then
		add(t(descKey), GRAY)
	end
	-- drop trailing blank lines
	while #lines > 1 and lines[#lines].text == "" do
		table.remove(lines)
	end
	return lines
end

-- icons.json entries that are pictures, not inventory items
local NOT_ITEMS: { [string]: boolean } = {
	money = true,
	potion = true,
	key_ordinary = true,
	ordinaryCase = true,
	ordinary_case = true,
}

-- Every item id the game knows (configs + icons); used by the audit.
function ItemInfo.knownIds(): { string }
	local ids: { [string]: boolean } = {}
	for id in pairs(Config.tools) do
		ids[id] = true
	end
	for id, value in pairs(Config.rules.survival.food) do
		if typeof(value) == "number" then
			ids[id] = true
		end
	end
	for _, need in ipairs({ "hygiene", "sleep", "toilet" }) do
		ids[Config.needs[need].consumable] = true
	end
	for id, value in pairs(Config.icons.icons) do
		-- skip UI icons, per-material variants (axe_stone) and legacy pictures that are not items
		if
			typeof(value) == "string"
			and not NOT_ITEMS[id]
			and not id:match("^menu_")
			and not id:match("^effect_")
			and not id:match("^trainer_")
			and not id:match("_wood$")
			and not id:match("_stone$")
			and not id:match("_iron$")
			and not id:match("_diamond$")
			and not Config.block(id)
		then
			ids[id] = true
		end
	end
	local list = {}
	for id in pairs(ids) do
		table.insert(list, id)
	end
	table.sort(list)
	return list
end

-- Missing translations: item names in every locale, book names/descriptions.
function ItemInfo.audit(): { string }
	local missing = {}
	for _, locale in ipairs(Config.locales) do
		for _, id in ipairs(ItemInfo.knownIds()) do
			if not Strings.has("item_" .. id, locale) then
				table.insert(missing, locale .. ": item_" .. id)
			end
		end
		for bookId in pairs(Config.books.catalog or {}) do
			if bookId ~= "_source" then
				for _, key in ipairs({ "book_" .. bookId, "book_desc_" .. bookId }) do
					if not Strings.has(key, locale) then
						table.insert(missing, locale .. ": " .. key)
					end
				end
			end
		end
	end
	return missing
end

return ItemInfo
