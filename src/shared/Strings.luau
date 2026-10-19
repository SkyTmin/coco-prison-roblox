--!strict
-- Player-facing strings. Every new string goes here in all four locales (ru default).

local Config = require(script.Parent.Config)

type Entry = { [string]: string }

local STRINGS: { [string]: Entry } = {
	coins = { ru = "Монеты", en = "Coins", es = "Monedas", fr = "Pièces" },
	level = { ru = "Уровень", en = "Level", es = "Nivel", fr = "Niveau" },
	bag = { ru = "Сумка", en = "Bag", es = "Bolsa", fr = "Sac" },
	empty = { ru = "пусто", en = "empty", es = "vacía", fr = "vide" },
	level_up = {
		ru = "Повысить уровень",
		en = "Level up",
		es = "Subir de nivel",
		fr = "Monter de niveau",
	},
	sold = {
		ru = "Продано за %s",
		en = "Sold for %s",
		es = "Vendido por %s",
		fr = "Vendu pour %s",
	},
	nothing_to_sell = {
		ru = "Нечего продавать",
		en = "Nothing to sell",
		es = "Nada que vender",
		fr = "Rien à vendre",
	},
	sell_prompt = {
		ru = "Продать сырьё",
		en = "Sell resources",
		es = "Vender recursos",
		fr = "Vendre les ressources",
	},
	wrong_tool = {
		ru = "Нужен другой инструмент",
		en = "You need another tool",
		es = "Necesitas otra herramienta",
		fr = "Il faut un autre outil",
	},
	too_far = {
		ru = "Слишком далеко",
		en = "Too far away",
		es = "Demasiado lejos",
		fr = "Trop loin",
	},
	level_too_low = {
		ru = "Нужен уровень %d",
		en = "Level %d required",
		es = "Se requiere nivel %d",
		fr = "Niveau %d requis",
	},
	node_depleted = {
		ru = "Здесь уже пусто",
		en = "Nothing left here",
		es = "Aquí ya no queda nada",
		fr = "Plus rien ici",
	},
	key_found = {
		ru = "Найден ключ!",
		en = "You found a key!",
		es = "¡Encontraste una llave!",
		fr = "Vous avez trouvé une clé !",
	},
	level_reached = {
		ru = "Уровень %d!",
		en = "Level %d!",
		es = "¡Nivel %d!",
		fr = "Niveau %d !",
	},
	level_need_work = {
		ru = "Нужно работ: %d из %d",
		en = "Work needed: %d of %d",
		es = "Trabajos: %d de %d",
		fr = "Travaux : %d sur %d",
	},
	level_need_coins = {
		ru = "Нужно монет: %s",
		en = "Coins needed: %s",
		es = "Monedas necesarias: %s",
		fr = "Pièces nécessaires : %s",
	},
	level_need_quest = {
		ru = "Сначала выполни задание: %s",
		en = "Complete the quest first: %s",
		es = "Completa la misión primero: %s",
		fr = "Terminez d'abord la quête : %s",
	},
	level_need_kills = {
		ru = "Победи %s: %d из %d",
		en = "Defeat %s: %d of %d",
		es = "Derrota %s: %d de %d",
		fr = "Vaincre %s : %d sur %d",
	},
	level_max = {
		ru = "Это последний уровень главы",
		en = "This is the last level of the chapter",
		es = "Es el último nivel del capítulo",
		fr = "C'est le dernier niveau du chapitre",
	},
	quest_first_sale = {
		ru = "Первая продажа",
		en = "First sale",
		es = "Primera venta",
		fr = "Première vente",
	},
	quest_earth_order = {
		ru = "Земляной заказ",
		en = "Earth order",
		es = "Pedido de tierra",
		fr = "Commande de terre",
	},
	mob_rat = { ru = "крыс", en = "rats", es = "ratas", fr = "rats" },
	mob_zombie = { ru = "зомби", en = "zombies", es = "zombis", fr = "zombies" },
}

local Strings = {}

-- Two-letter locale from a Player.LocaleId ("ru-ru" -> "ru"), falling back to the default.
function Strings.localeOf(player: Player?): string
	if player then
		local short = string.sub(string.lower(player.LocaleId), 1, 2)
		if table.find(Config.locales, short) then
			return short
		end
	end
	return Config.defaultLocale
end

function Strings.t(key: string, locale: string?, ...: any): string
	local entry = STRINGS[key]
	if not entry then
		return key
	end
	local text = entry[locale or Config.defaultLocale] or entry[Config.defaultLocale] or key
	if select("#", ...) > 0 then
		return string.format(text, ...)
	end
	return text
end

-- Whole coins for display; coins are stored in hundredths.
function Strings.money(cents: number): string
	return tostring(math.floor(cents / Config.moneyScale))
end

function Strings.resourceLabel(id: string, locale: string?): string
	local resource = Config.resource(id)
	if not resource then
		return id
	end
	return resource.label[locale or Config.defaultLocale]
		or resource.label[Config.defaultLocale]
		or id
end

return Strings
