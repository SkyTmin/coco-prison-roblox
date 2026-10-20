--!strict
-- Player-facing strings. Every new string goes here in all four locales (ru default).

local Config = require(script.Parent.Config)

type Entry = { [string]: string }

local STRINGS: { [string]: Entry } = {
	artifacts = { ru = "Артефакты", en = "Artifacts", es = "Artefactos", fr = "Artefacts" },
	artifacts_hotkey = {
		ru = "Артефакты [I]",
		en = "Artifacts [I]",
		es = "Artefactos [I]",
		fr = "Artefacts [I]",
	},
	artifact_collection = { ru = "Сбор", en = "Collection", es = "Colección", fr = "Collecte" },
	artifact_album = { ru = "Альбом", en = "Album", es = "Álbum", fr = "Album" },
	artifact_tier_common = { ru = "Обычный", en = "Common", es = "Común", fr = "Commun" },
	artifact_tier_rare = { ru = "Редкий", en = "Rare", es = "Raro", fr = "Rare" },
	artifact_tier_epic = { ru = "Эпический", en = "Epic", es = "Épico", fr = "Épique" },
	artifact_picture_gym = {
		ru = "Качалка",
		en = "Gym",
		es = "Gimnasio",
		fr = "Salle de sport",
	},
	artifact_picture_garden = { ru = "Огород", en = "Garden", es = "Huerto", fr = "Potager" },
	artifact_picture_henchman = {
		ru = "Подручный",
		en = "Henchman",
		es = "Secuaz",
		fr = "Homme de main",
	},
	artifact_picture_vecna = { ru = "Векна", en = "Vecna", es = "Vecna", fr = "Vecna" },
	artifact_fragment_name = {
		ru = "%s фрагмент %s",
		en = "%s fragment %s",
		es = "Fragmento %s %s",
		fr = "Fragment %s %s",
	},
	artifact_finds = { ru = "Находки", en = "Finds", es = "Hallazgos", fr = "Trouvailles" },
	artifact_duplicates = {
		ru = "дубликаты: %d/%d → следующий недостающий фрагмент",
		en = "Duplicates: %d/%d → next missing fragment",
		es = "Duplicados: %d/%d → siguiente fragmento que falta",
		fr = "Doublons : %d/%d → prochain fragment manquant",
	},
	artifact_create = {
		ru = "Создать артефакт",
		en = "Assemble artifact",
		es = "Crear artefacto",
		fr = "Assembler l’artefact",
	},
	artifact_ready_tooltip = {
		ru = "Все девять фрагментов на месте — вы получите ключ от кейса артефактов",
		en = "All nine fragments are present — you will receive an artifact case key",
		es = "Tienes los nueve fragmentos: recibirás una llave de la caja de artefactos",
		fr = "Les neuf fragments sont réunis : vous recevrez une clé de caisse d’artefacts",
	},
	artifact_need_fragments = {
		ru = "Соберите все девять фрагментов",
		en = "Collect all nine fragments",
		es = "Reúne los nueve fragmentos",
		fr = "Réunissez les neuf fragments",
	},
	artifact_completed = {
		ru = "Собрано артефактов: %d",
		en = "Artifacts assembled: %d",
		es = "Artefactos creados: %d",
		fr = "Artefacts assemblés : %d",
	},
	artifact_fragment_found = {
		ru = "Найден фрагмент артефакта: %s, %s",
		en = "Artifact fragment found: %s, %s",
		es = "Fragmento de artefacto encontrado: %s, %s",
		fr = "Fragment d’artefact trouvé : %s, %s",
	},
	artifact_fragment_from_duplicates = {
		ru = "Фрагмент за дубликаты: %s, %s",
		en = "Fragment from duplicates: %s, %s",
		es = "Fragmento por duplicados: %s, %s",
		fr = "Fragment obtenu avec les doublons : %s, %s",
	},
	artifact_assembled = {
		ru = "Артефакт собран (%s)! Получен ключ от кейса артефактов",
		en = "Artifact assembled (%s)! Artifact case key received",
		es = "¡Artefacto creado (%s)! Recibiste una llave de la caja de artefactos",
		fr = "Artefact assemblé (%s) ! Clé de caisse d’artefacts reçue",
	},
	artifact_case = {
		ru = "Кейс артефактов",
		en = "Artifact case",
		es = "Caja de artefactos",
		fr = "Caisse d’artefacts",
	},
	item_artifact_key = {
		ru = "Ключ от кейса артефактов",
		en = "Artifact case key",
		es = "Llave de la caja de artefactos",
		fr = "Clé de caisse d’artefacts",
	},
	item_ancient_book = {
		ru = "Древняя книга",
		en = "Ancient book",
		es = "Libro antiguo",
		fr = "Livre antique",
	},
	item_money_bag = {
		ru = "Мешок денег",
		en = "Money bag",
		es = "Bolsa de dinero",
		fr = "Sac d’argent",
	},
	kd_label = { ru = "У/С", en = "K/D", es = "B/M", fr = "É/M" },
	exchange = { ru = "Обменять", en = "Exchange", es = "Canjear", fr = "Échanger" },
	exchange_stars = {
		ru = "Обмен звёзд",
		en = "Star exchange",
		es = "Canje de estrellas",
		fr = "Échange d’étoiles",
	},
	exchange_shards = {
		ru = "Обмен осколков",
		en = "Shard exchange",
		es = "Canje de fragmentos",
		fr = "Échange de fragments",
	},
	exchange_need_items = {
		ru = "Недостаточно предметов для обмена",
		en = "Not enough items to exchange",
		es = "No tienes suficientes objetos para el canje",
		fr = "Pas assez d’objets pour l’échange",
	},
	exchanged = {
		ru = "Получено: %s",
		en = "Received: %s",
		es = "Recibiste: %s",
		fr = "Reçu : %s",
	},
	item_ancient_key = {
		ru = "Древний ключ",
		en = "Ancient key",
		es = "Llave antigua",
		fr = "Clé ancienne",
	},
	item_improved_ancient_key = {
		ru = "Улучшенный древний ключ",
		en = "Improved ancient key",
		es = "Llave antigua mejorada",
		fr = "Clé ancienne améliorée",
	},
	item_moon_steel = {
		ru = "Лунная сталь",
		en = "Moon steel",
		es = "Acero lunar",
		fr = "Acier lunaire",
	},
	item_fire_shard = {
		ru = "Огненный осколок",
		en = "Fire shard",
		es = "Fragmento de fuego",
		fr = "Fragment de feu",
	},
	item_moon_blade = {
		ru = "Лунное лезвие",
		en = "Moon blade",
		es = "Hoja lunar",
		fr = "Lame lunaire",
	},
	item_volcanic_stone = {
		ru = "Вулканический камень",
		en = "Volcanic stone",
		es = "Piedra volcánica",
		fr = "Pierre volcanique",
	},
	item_dispeller = {
		ru = "Развеиватель",
		en = "Dispeller",
		es = "Disipador",
		fr = "Dissipateur",
	},
	item_ancient_powder = {
		ru = "Древний порошок",
		en = "Ancient powder",
		es = "Polvo antiguo",
		fr = "Poudre ancienne",
	},
	item_nickname_key = {
		ru = "Ключ от кейса с кличками",
		en = "Nickname key",
		es = "Llave de apodo",
		fr = "Clé de pseudonyme",
	},
	ender_chest = {
		ru = "Эндер-сундук",
		en = "Ender chest",
		es = "Cofre de Ender",
		fr = "Coffre de l’Ender",
	},
	hunger_restored = {
		ru = "Сытость восстановлена!",
		en = "Hunger restored!",
		es = "¡Hambre restaurada!",
		fr = "Faim restaurée !",
	},
	health_tooltip = {
		ru = "Здоровье: %.1f / %.1f",
		en = "Health: %.1f / %.1f",
		es = "Salud: %.1f / %.1f",
		fr = "Santé : %.1f / %.1f",
	},
	hunger_tooltip = {
		ru = "Сытость: %.1f / %.1f",
		en = "Hunger: %.1f / %.1f",
		es = "Hambre: %.1f / %.1f",
		fr = "Faim : %.1f / %.1f",
	},
	coins = { ru = "Баланс", en = "Balance", es = "Saldo", fr = "Solde" },
	level = { ru = "Уровень", en = "Level", es = "Nivel", fr = "Niveau" },
	blocks = { ru = "Блоки", en = "Blocks", es = "Bloques", fr = "Blocs" },
	locations = { ru = "Локации", en = "Locations", es = "Ubicaciones", fr = "Lieux" },
	locations_mines = { ru = "Шахты", en = "Mines", es = "Minas", fr = "Mines" },
	locations_spots = { ru = "Спавн", en = "Spots", es = "Puntos", fr = "Points" },
	spot_spawn = { ru = "Спавн", en = "Spawn", es = "Inicio", fr = "Départ" },
	spot_mine = { ru = "Шахта", en = "Mine", es = "Mina", fr = "Mine" },
	spot_small_mine = {
		ru = "Малая шахта",
		en = "Small mine",
		es = "Mina pequeña",
		fr = "Petite mine",
	},
	spot_market = { ru = "Рынок", en = "Market", es = "Mercado", fr = "Marché" },
	spot_canteen = { ru = "Столовая", en = "Canteen", es = "Comedor", fr = "Cantine" },
	spot_bedroom = { ru = "Спальня", en = "Bedroom", es = "Dormitorio", fr = "Dortoir" },
	spot_bath = { ru = "Баня", en = "Bath", es = "Baños", fr = "Bains" },
	spot_trainer = { ru = "Тренер", en = "Trainer", es = "Entrenador", fr = "Entraîneur" },
	spot_showcase = { ru = "Витрина", en = "Showcase", es = "Vitrina", fr = "Vitrine" },
	camera_first_person = {
		ru = "От первого лица",
		en = "First person",
		es = "Primera persona",
		fr = "Première personne",
	},
	camera_third_person = {
		ru = "От третьего лица",
		en = "Third person",
		es = "Tercera persona",
		fr = "Troisième personne",
	},
	touch_dig = { ru = "Копать", en = "Dig", es = "Cavar", fr = "Creuser" },
	touch_use = { ru = "Использовать", en = "Use", es = "Usar", fr = "Utiliser" },
	locations_sky = {
		ru = "Небесные шахты",
		en = "Sky mines",
		es = "Minas celestes",
		fr = "Mines célestes",
	},
	locations_other = {
		ru = "Прочие локации",
		en = "Other locations",
		es = "Otras ubicaciones",
		fr = "Autres lieux",
	},
	locations_player_level = {
		ru = "Ваш уровень %d",
		en = "Your level %d",
		es = "Tu nivel %d",
		fr = "Votre niveau %d",
	},
	teleport = {
		ru = "Телепортироваться",
		en = "Teleport",
		es = "Teletransportarse",
		fr = "Se téléporter",
	},
	teleport_cancelled = {
		ru = "Телепортация отменена",
		en = "Teleport cancelled",
		es = "Teletransporte cancelado",
		fr = "Téléportation annulée",
	},
	teleport_in_combat = {
		ru = "Телепортация недоступна после боя ещё %d с",
		en = "Teleport locked after combat for %d more s",
		es = "Teletransporte bloqueado tras el combate durante %d s más",
		fr = "Téléportation bloquée après le combat pendant encore %d s",
	},
	teleport_channel = {
		ru = "Телепортация через %d с — не двигайтесь",
		en = "Teleporting in %d s — stand still",
		es = "Teletransporte en %d s — no te muevas",
		fr = "Téléportation dans %d s — restez immobile",
	},
	language_code = { ru = "RU", en = "EN", es = "ES", fr = "FR" },
	combo = {
		ru = "Комбо ×%.1f   %d/%d",
		en = "Combo ×%.1f   %d/%d",
		es = "Combo ×%.1f   %d/%d",
		fr = "Combo ×%.1f   %d/%d",
	},
	teleporter_prompt = {
		ru = "Телепортатор",
		en = "Teleporter",
		es = "Teletransportador",
		fr = "Téléporteur",
	},
	locations_double_click = {
		ru = "Двойной клик: телепорт",
		en = "Double-click to teleport",
		es = "Doble clic para teletransportarse",
		fr = "Double-clic pour se téléporter",
	},
	location_start = {
		ru = "Стартовая локация",
		en = "Starting location",
		es = "Ubicación inicial",
		fr = "Lieu de départ",
	},
	location_level = {
		ru = "%d уровень",
		en = "Level %d",
		es = "Nivel %d",
		fr = "Niveau %d",
	},
	pvp = { ru = "PvP", en = "PvP", es = "PvP", fr = "PvP" },
	bosses = { ru = "Боссы", en = "Bosses", es = "Jefes", fr = "Boss" },
	more_details = { ru = "Подробнее", en = "Details", es = "Detalles", fr = "Détails" },
	location_pass_required = {
		ru = "Требуется пропуск",
		en = "Pass required",
		es = "Se requiere un pase",
		fr = "Laissez-passer requis",
	},
	location_no_spawn = {
		ru = "Точка прибытия этой локации ещё не готова",
		en = "This location's arrival point is not ready yet",
		es = "El punto de llegada de esta ubicación aún no está listo",
		fr = "Le point d'arrivée de ce lieu n'est pas encore prêt",
	},
	location_unknown = {
		ru = "Локация не найдена",
		en = "Location not found",
		es = "Ubicación no encontrada",
		fr = "Lieu introuvable",
	},
	teleport_not_ready = {
		ru = "Телепортация пока недоступна. Дождитесь появления персонажа.",
		en = "Teleport is not ready. Wait for your character to spawn.",
		es = "La teletransportación no está lista. Espera a que aparezca tu personaje.",
		fr = "La téléportation n'est pas prête. Attendez l'apparition de votre personnage.",
	},
	location_description_prison = {
		ru = "Во дворе начинается твой путь шахтёра. Собери первые блоки и загляни к торговцам у площади.",
		en = "Your mining journey begins in the yard. Gather your first blocks and visit the traders by the plaza.",
		es = "Tu camino de minero empieza en el patio. Recoge tus primeros bloques y visita a los comerciantes de la plaza.",
		fr = "Votre parcours de mineur commence dans la cour. Récoltez vos premiers blocs et visitez les marchands de la place.",
	},
	location_description_quarry = {
		ru = "Каменные уступы скрывают уголь и железо. Стук кирки может разбудить стража глубин.",
		en = "Stone ledges conceal coal and iron. The ring of a pickaxe may wake the guardian below.",
		es = "Las terrazas de piedra esconden carbón y hierro. El golpe de un pico puede despertar al guardián de las profundidades.",
		fr = "Les corniches rocheuses cachent charbon et fer. Le bruit d'une pioche pourrait réveiller le gardien des profondeurs.",
	},
	location_description_mountain_foot = {
		ru = "Под горными склонами блестят золотые жилы. Береги силы: среди скал бродит Минотавр.",
		en = "Gold veins glint beneath the mountain slopes. Save your strength: a Minotaur roams among the rocks.",
		es = "Las vetas de oro brillan bajo las laderas. Guarda fuerzas: un Minotauro ronda entre las rocas.",
		fr = "Des filons d'or brillent au pied des pentes. Gardez vos forces : un Minotaure rôde parmi les rochers.",
	},
	location_description_underworld = {
		ru = "Красные своды нависают над залежами кварца. За каждой раскалённой трещиной может ждать чужой дозор.",
		en = "Red vaults loom over beds of quartz. A hostile patrol may lurk beyond any glowing fissure.",
		es = "Las bóvedas rojas se alzan sobre depósitos de cuarzo. Una patrulla hostil puede acechar tras cada grieta ardiente.",
		fr = "Des voûtes rouges dominent les gisements de quartz. Une patrouille hostile peut guetter derrière chaque fissure ardente.",
	},
	location_description_pyramid = {
		ru = "Под песками сохранились древние залы из песчаника. Следи за спиной: здесь опасны и скелеты, и другие игроки.",
		en = "Ancient sandstone halls survive beneath the sands. Watch your back: skeletons and other players are both a threat here.",
		es = "Bajo la arena perduran antiguas salas de arenisca. Vigila tu espalda: aquí amenazan tanto los esqueletos como otros jugadores.",
		fr = "D'anciennes salles de grès subsistent sous le sable. Surveillez vos arrières : squelettes et autres joueurs vous menacent ici.",
	},
	location_description_basement = {
		ru = "Под тюремным двором тянутся забытые проходы. Возьми пропуск и приготовься делить добычу с крысами и соперниками.",
		en = "Forgotten passages run beneath the prison yard. Bring a pass and prepare to share the spoils with rats and rivals.",
		es = "Pasadizos olvidados recorren el subsuelo del patio. Trae un pase y prepárate para compartir el botín con ratas y rivales.",
		fr = "Des passages oubliés serpentent sous la cour. Munissez-vous d'un laissez-passer et préparez-vous à partager le butin avec rats et rivaux.",
	},
	location_description_generic = {
		ru = "Исследуй новое место и найди возможности для дальнейшего пути.",
		en = "Explore a new place and discover ways to continue your journey.",
		es = "Explora un nuevo lugar y descubre cómo continuar tu camino.",
		fr = "Explorez un nouveau lieu et découvrez comment poursuivre votre parcours.",
	},
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
	achievements = {
		ru = "Достижения",
		en = "Achievements",
		es = "Logros",
		fr = "Succès",
	},
	digger_dirt = {
		ru = "Копатель (земля)",
		en = "Digger (dirt)",
		es = "Excavador (tierra)",
		fr = "Mineur (terre)",
	},
	digger_sand = {
		ru = "Копатель (песок)",
		en = "Digger (sand)",
		es = "Excavador (arena)",
		fr = "Mineur (sable)",
	},
	digger_gravel = {
		ru = "Копатель (гравий)",
		en = "Digger (gravel)",
		es = "Excavador (grava)",
		fr = "Mineur (gravier)",
	},
	digger_coal_ore = {
		ru = "Копатель (угольная руда)",
		en = "Digger (coal ore)",
		es = "Excavador (mineral de carbón)",
		fr = "Mineur (minerai de charbon)",
	},
	digger_oak_log = {
		ru = "Копатель (дерево)",
		en = "Digger (wood)",
		es = "Excavador (madera)",
		fr = "Mineur (bois)",
	},
	reward = { ru = "Награда", en = "Reward", es = "Recompensa", fr = "Récompense" },
	claim = { ru = "Забрать", en = "Claim", es = "Reclamar", fr = "Récupérer" },
	achievement_complete = {
		ru = "Все награды получены",
		en = "All rewards claimed",
		es = "Todas las recompensas reclamadas",
		fr = "Toutes les récompenses récupérées",
	},
	achievement_claimed = {
		ru = "%s: ступень %d, получено %s $",
		en = "%s: tier %d, received %s $",
		es = "%s: etapa %d, recibiste %s $",
		fr = "%s : palier %d, %s $ reçus",
	},
	ordinary_case = {
		ru = "Обычный кейс",
		en = "Ordinary case",
		es = "Caja común",
		fr = "Caisse ordinaire",
	},
	ancient_case = {
		ru = "Древний кейс",
		en = "Ancient case",
		es = "Caja antigua",
		fr = "Caisse antique",
	},
	case_locked = { ru = "Скоро", en = "Coming soon", es = "Próximamente", fr = "Bientôt" },
	case_open = { ru = "Открыть", en = "Open", es = "Abrir", fr = "Ouvrir" },
	case_take_all = {
		ru = "Забрать всё",
		en = "Take all",
		es = "Tomar todo",
		fr = "Tout prendre",
	},
	case_full = {
		ru = "Освободите место в кейсе",
		en = "Make room in the chest",
		es = "Libera espacio en la caja",
		fr = "Libérez de la place dans la caisse",
	},
	case_money = {
		ru = "Получено %s $",
		en = "Received %s $",
		es = "Recibiste %s $",
		fr = "%s $ reçus",
	},
	case_no_key = {
		ru = "У Вас нет ключа от этого кейса!",
		en = "You do not have a key for this case!",
		es = "¡No tienes una llave para esta caja!",
		fr = "Vous n'avez pas de clé pour cette caisse !",
	},
	case_found = {
		ru = "Вы нашли %s (%s)",
		en = "You found %s (%s)",
		es = "Encontraste %s (%s)",
		fr = "Vous avez trouvé %s (%s)",
	},
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
	item_arrow = { ru = "Стрела", en = "Arrow", es = "Flecha", fr = "Flèche" },
	item_golden_apple = {
		ru = "Золотое яблоко",
		en = "Golden apple",
		es = "Manzana dorada",
		fr = "Pomme dorée",
	},
	item_ancient_star = {
		ru = "Древняя звезда",
		en = "Ancient star",
		es = "Estrella antigua",
		fr = "Étoile ancienne",
	},
	item_basement_pass = {
		ru = "Пропуск в подвал",
		en = "Basement pass",
		es = "Pase al sótano",
		fr = "Laissez-passer pour le sous-sol",
	},
	item_oblivion_scroll = {
		ru = "Свиток забвения",
		en = "Oblivion scroll",
		es = "Pergamino del olvido",
		fr = "Parchemin d'oubli",
	},
	item_rotten_flesh = {
		ru = "Гнилая плоть",
		en = "Rotten flesh",
		es = "Carne podrida",
		fr = "Chair putréfiée",
	},
	item_booster_money = {
		ru = "Локальный бустер денег на 30 минут",
		en = "Local money booster for 30 minutes",
		es = "Potenciador local de dinero de 30 minutos",
		fr = "Booster d'argent local de 30 minutes",
	},
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
		ru = "Локации [M]  Работа [O]  Улучшить [J]  Уровень [U]  Инвентарь [E]  Использовать [F]  Достижения [L]",
		en = "Locations [M]  Jobs [O]  Upgrade [J]  Level [U]  Inventory [E]  Use [F]  Achievements [L]",
		es = "Ubicaciones [M]  Trabajos [O]  Mejorar [J]  Nivel [U]  Inventario [E]  Usar [F]  Logros [L]",
		fr = "Lieux [M]  Métiers [O]  Améliorer [J]  Niveau [U]  Inventaire [E]  Utiliser [F]  Succès [L]",
	},
}

local Strings = {}

local PICTURES = {
	["Качалка"] = "artifact_picture_gym",
	["Огород"] = "artifact_picture_garden",
	["Подручный"] = "artifact_picture_henchman",
	["Векна"] = "artifact_picture_vecna",
}

function Strings.artifactPictureName(name: string, locale: string?): string
	local key = PICTURES[name]
	return if key then Strings.t(key, locale) else name
end

function Strings.localeOf(player: Player?): string
	if player then
		local locale = player:GetAttribute("Locale")
		if typeof(locale) == "string" and table.find(Config.locales, locale) then
			return locale
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
	if id == "ancient_book" and level then
		return base .. " " .. tostring(level)
	end
	if Config.tools[id] and level then
		return Strings.t("mat_" .. Config.materialForLevel(level), loc) .. " " .. string.lower(base)
	end
	return base
end

return Strings
