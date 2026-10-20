--!strict
-- Player-facing strings. Every new string goes here in all four locales (ru default).

local Config = require(script.Parent.Config)

type Entry = { [string]: string }

local STRINGS: { [string]: Entry } = {
	coins = { ru = "Баланс", en = "Balance", es = "Saldo", fr = "Solde" },
	level = { ru = "Уровень", en = "Level", es = "Nivel", fr = "Niveau" },
	blocks = { ru = "Блоки", en = "Blocks", es = "Bloques", fr = "Blocs" },
	rats = { ru = "Крысы", en = "Rats", es = "Ratas", fr = "Rats" },
	need_hygiene = { ru = "Гигиена", en = "Hygiene", es = "Higiene", fr = "Hygiène" },
	need_sleep = { ru = "Сон", en = "Sleep", es = "Sueño", fr = "Sommeil" },
	need_toilet = { ru = "Туалет", en = "Toilet", es = "Aseo", fr = "Toilettes" },
	need_low_hygiene = {
		ru = "Гигиена на исходе: Баня или мыло.",
		en = "Hygiene is low: bath or soap.",
		es = "Higiene baja: baños o jabón.",
		fr = "Hygiène faible : bains ou savon.",
	},
	need_low_sleep = {
		ru = "Вы устали: Спальня или спальный мешок.",
		en = "Sleep is low: bedroom or sleeping bag.",
		es = "Sueño bajo: dormitorio o saco de dormir.",
		fr = "Sommeil faible : dortoir ou sac de couchage.",
	},
	need_low_toilet = {
		ru = "Пора в Уборную или используйте бумагу.",
		en = "Visit the toilet or use toilet paper.",
		es = "Visita el aseo o usa papel higiénico.",
		fr = "Allez aux toilettes ou utilisez du papier.",
	},
	restore_hygiene_prompt = { ru = "Баня", en = "Bath", es = "Baños", fr = "Bains" },
	restore_sleep_prompt = {
		ru = "Спальня",
		en = "Bedroom",
		es = "Dormitorio",
		fr = "Dortoir",
	},
	restore_toilet_prompt = { ru = "Уборная", en = "Toilet", es = "Aseo", fr = "Toilettes" },
	need_restored_hygiene = {
		ru = "Гигиена восстановлена!",
		en = "Hygiene restored!",
		es = "¡Higiene restaurada!",
		fr = "Hygiène restaurée !",
	},
	need_restored_sleep = {
		ru = "Вы выспались!",
		en = "You are well rested!",
		es = "¡Has descansado!",
		fr = "Vous êtes bien reposé !",
	},
	need_restored_toilet = {
		ru = "Потребность в туалете снята!",
		en = "Toilet need restored!",
		es = "¡Necesidad de aseo resuelta!",
		fr = "Besoin d'aller aux toilettes satisfait !",
	},
	event_haste = { ru = "Спешка", en = "Haste", es = "Prisa", fr = "Célérité" },
	event_speed = { ru = "Скорость", en = "Speed", es = "Velocidad", fr = "Vitesse" },
	event_regeneration = {
		ru = "Регенерация",
		en = "Regeneration",
		es = "Regeneración",
		fr = "Régénération",
	},
	event_strength = { ru = "Сила", en = "Strength", es = "Fuerza", fr = "Force" },
	event_started = {
		ru = "Внезапное событие %s I началось!",
		en = "Sudden event %s I has begun!",
		es = "¡Ha comenzado el evento repentino %s I!",
		fr = "L'événement soudain %s I a commencé !",
	},
	inventory = {
		ru = "Инвентарь",
		en = "Inventory",
		es = "Inventario",
		fr = "Inventaire",
	},
	bag_full = {
		ru = "Инвентарь полон",
		en = "Inventory is full",
		es = "Inventario lleno",
		fr = "Inventaire plein",
	},
	level_up = {
		ru = "Повысить уровень",
		en = "Level up",
		es = "Subir de nivel",
		fr = "Monter de niveau",
	},
	sold = {
		ru = "Продано за %s $",
		en = "Sold for %s $",
		es = "Vendido por %s $",
		fr = "Vendu pour %s $",
	},
	nothing_to_sell = {
		ru = "Нечего продавать",
		en = "Nothing to sell",
		es = "Nada que vender",
		fr = "Rien à vendre",
	},
	sell_prompt = {
		ru = "Скупщик блоков",
		en = "Block buyer",
		es = "Comprador",
		fr = "Acheteur",
	},
	sell_all = {
		ru = "Продать всё",
		en = "Sell all",
		es = "Vender todo",
		fr = "Tout vendre",
	},
	shop_prompt = {
		ru = "Продавец предметов",
		en = "Item seller",
		es = "Vendedor",
		fr = "Vendeur",
	},
	food_prompt = {
		ru = "Продавец еды",
		en = "Food seller",
		es = "Vendedor de comida",
		fr = "Vendeur de nourriture",
	},
	buy = { ru = "Приобрести", en = "Buy", es = "Comprar", fr = "Acheter" },
	bought = {
		ru = "Куплено: %s",
		en = "Bought: %s",
		es = "Comprado: %s",
		fr = "Acheté : %s",
	},
	not_enough_money = {
		ru = "Недостаточно денег",
		en = "Not enough money",
		es = "Dinero insuficiente",
		fr = "Pas assez d'argent",
	},
	wrong_tool = {
		ru = "Нужен другой инструмент",
		en = "You need another tool",
		es = "Necesitas otra herramienta",
		fr = "Il faut un autre outil",
	},
	tool_too_weak = {
		ru = "Инструмент слишком слаб для этого блока",
		en = "Tool is too weak for this block",
		es = "Herramienta demasiado débil",
		fr = "Outil trop faible",
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
	level_reached = {
		ru = "Вы достигли %d-го уровня!",
		en = "You reached level %d!",
		es = "¡Alcanzaste el nivel %d!",
		fr = "Niveau %d atteint !",
	},
	level_need_blocks = {
		ru = "Нужно блоков: %s / %s",
		en = "Blocks needed: %s / %s",
		es = "Bloques: %s / %s",
		fr = "Blocs : %s / %s",
	},
	level_need_money = {
		ru = "Нужно денег: %s / %s",
		en = "Money needed: %s / %s",
		es = "Dinero: %s / %s",
		fr = "Argent : %s / %s",
	},
	level_max = {
		ru = "Максимальный уровень",
		en = "Maximum level",
		es = "Nivel máximo",
		fr = "Niveau maximum",
	},
	upgrade = {
		ru = "Улучшить предмет",
		en = "Upgrade item",
		es = "Mejorar objeto",
		fr = "Améliorer l'objet",
	},
	upgraded = {
		ru = "%s улучшен до %d уровня",
		en = "%s upgraded to level %d",
		es = "%s mejorado a nivel %d",
		fr = "%s amélioré au niveau %d",
	},
	upgrade_max = {
		ru = "Предмет на максимальном уровне",
		en = "Item is at max level",
		es = "Objeto al máximo",
		fr = "Objet au niveau maximum",
	},
	upgrade_need = {
		ru = "Не хватает: %s",
		en = "Missing: %s",
		es = "Falta: %s",
		fr = "Il manque : %s",
	},
	mine_reset_warn = {
		ru = "Шахта обновится через %d с",
		en = "Mine resets in %d s",
		es = "La mina se reinicia en %d s",
		fr = "Réinitialisation de la mine dans %d s",
	},
	mine_reset = {
		ru = "Шахта обновлена",
		en = "Mine reset",
		es = "Mina reiniciada",
		fr = "Mine réinitialisée",
	},
	key_found = {
		ru = "Поздравляем! Вы нашли ключ!",
		en = "Congratulations! You found a key!",
		es = "¡Encontraste una llave!",
		fr = "Vous avez trouvé une clé !",
	},
	jobs = { ru = "Работы", en = "Jobs", es = "Trabajos", fr = "Métiers" },
	claim_points = {
		ru = "Забрать очки: %d",
		en = "Claim points: %d",
		es = "Reclamar puntos: %d",
		fr = "Récupérer les points : %d",
	},
	job_mason = { ru = "Каменщик", en = "Mason", es = "Albañil", fr = "Maçon" },
	job_surveyor = {
		ru = "Геодезист",
		en = "Surveyor",
		es = "Topógrafo",
		fr = "Géomètre",
	},
	job_blademaster = {
		ru = "Мастер клинка",
		en = "Blademaster",
		es = "Maestro de espada",
		fr = "Maître d'armes",
	},
	booster_blocks = {
		ru = "Бустер блоков",
		en = "Block booster",
		es = "Potenciador de bloques",
		fr = "Booster de blocs",
	},
	booster_money = {
		ru = "Бустер денег",
		en = "Money booster",
		es = "Potenciador de dinero",
		fr = "Booster d'argent",
	},
	booster_mobs = {
		ru = "Бустер мобов",
		en = "Mob booster",
		es = "Potenciador de mobs",
		fr = "Booster de mobs",
	},
	item_pickaxe = { ru = "Кирка", en = "Pickaxe", es = "Pico", fr = "Pioche" },
	item_shovel = { ru = "Лопата", en = "Shovel", es = "Pala", fr = "Pelle" },
	item_axe = { ru = "Топор", en = "Axe", es = "Hacha", fr = "Hache" },
	item_sword = { ru = "Меч", en = "Sword", es = "Espada", fr = "Épée" },
	item_helmet = { ru = "Шлем", en = "Helmet", es = "Casco", fr = "Casque" },
	item_chestplate = { ru = "Нагрудник", en = "Chestplate", es = "Peto", fr = "Plastron" },
	item_leggings = { ru = "Поножи", en = "Leggings", es = "Grebas", fr = "Jambières" },
	item_boots = { ru = "Ботинки", en = "Boots", es = "Botas", fr = "Bottes" },
	item_shears = { ru = "Ножницы", en = "Shears", es = "Tijeras", fr = "Cisailles" },
	item_apple = { ru = "Яблоко", en = "Apple", es = "Manzana", fr = "Pomme" },
	item_bread = { ru = "Хлеб", en = "Bread", es = "Pan", fr = "Pain" },
	item_soap = { ru = "Мыло", en = "Soap", es = "Jabón", fr = "Savon" },
	item_sleeping_bag = {
		ru = "Спальный мешок",
		en = "Sleeping bag",
		es = "Saco de dormir",
		fr = "Sac de couchage",
	},
	item_toilet_paper = {
		ru = "Туалетная бумага",
		en = "Toilet paper",
		es = "Papel higiénico",
		fr = "Papier toilette",
	},
	item_cooked_chicken = {
		ru = "Жареная курица",
		en = "Cooked chicken",
		es = "Pollo asado",
		fr = "Poulet rôti",
	},
	item_ordinary_key = {
		ru = "Ключ от Обычного кейса",
		en = "Ordinary case key",
		es = "Llave de caja común",
		fr = "Clé de caisse ordinaire",
	},
	mat_wood = { ru = "Деревянн.", en = "Wooden", es = "De madera", fr = "En bois" },
	mat_stone = { ru = "Каменн.", en = "Stone", es = "De piedra", fr = "En pierre" },
	mat_iron = { ru = "Железн.", en = "Iron", es = "De hierro", fr = "En fer" },
	mat_diamond = { ru = "Алмазн.", en = "Diamond", es = "De diamante", fr = "En diamant" },
	keys_hint = {
		ru = "Работа [O]  Улучшить [J]  Уровень [U]  Инвентарь [E]  Использовать [F]",
		en = "Jobs [O]  Upgrade [J]  Level [U]  Inventory [E]  Use [F]",
		es = "Trabajos [O]  Mejorar [J]  Nivel [U]  Inventario [E]  Usar [F]",
		fr = "Métiers [O]  Améliorer [J]  Niveau [U]  Inventaire [E]  Utiliser [F]",
	},
}

local Strings = {}

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

-- Money for display: three decimals like the original ("0.012"), thousands as "9.91K".
function Strings.money(units: number): string
	local value = units / Config.moneyScale
	if value >= 100000 then
		return string.format("%.2fK", value / 1000)
	elseif value >= 1000 then
		return string.format("%.1fK", value / 1000)
	elseif value >= 100 then
		return string.format("%d", math.floor(value))
	end
	return string.format("%." .. tostring(Config.money.displayDecimals) .. "f", value)
end

function Strings.big(n: number): string
	if n >= 1000000 then
		return string.format("%.2fM", n / 1000000)
	elseif n >= 1000 then
		return string.format("%.2fK", n / 1000)
	end
	return tostring(math.floor(n))
end

function Strings.itemName(id: string, level: number?, locale: string?): string
	local loc = locale or Config.defaultLocale
	local block = Config.block(id)
	if block then
		return block.name
	end
	local key = "item_" .. id
	local base = Strings.t(key, loc)
	if Config.tools[id] and level then
		return Strings.t("mat_" .. Config.materialForLevel(level), loc) .. " " .. string.lower(base)
	end
	return base
end

return Strings
