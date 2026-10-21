--!strict
-- Player-facing strings. Every new string goes here in all four locales (ru default).

local Config = require(script.Parent.Config)

type Entry = { [string]: string }

local STRINGS: { [string]: Entry } = {
	eat = { ru = "Съесть", en = "Eat", es = "Comer", fr = "Manger" },
	-- upgrade window [меню]
	upgrades = { ru = "Улучшения", en = "Upgrades", es = "Mejoras", fr = "Améliorations" },
	upgrade_button = { ru = "Улучшить", en = "Upgrade", es = "Mejorar", fr = "Améliorer" },
	upgrade_preview = {
		ru = "Только просмотр",
		en = "Preview only",
		es = "Solo vista",
		fr = "Aperçu seulement",
	},
	enchant_efficiency = {
		ru = "Эффективность",
		en = "Efficiency",
		es = "Eficiencia",
		fr = "Efficacité",
	},
	enchant_sharpness = { ru = "Острота", en = "Sharpness", es = "Filo", fr = "Tranchant" },
	enchant_protection = {
		ru = "Защита",
		en = "Protection",
		es = "Protección",
		fr = "Protection",
	},
	item_melon_slice = {
		ru = "Ломтик арбуза",
		en = "Melon slice",
		es = "Rodaja de sandía",
		fr = "Tranche de pastèque",
	},

	-- cases / keys (сессия 8)
	nickname_case = {
		ru = "Кейс с кличками",
		en = "Nickname case",
		es = "Caja de apodos",
		fr = "Caisse des surnoms",
	},
	case_need_key = {
		ru = "Для открытия требуется %s",
		en = "%s is required to open this",
		es = "Se necesita %s para abrir",
		fr = "%s est requis pour ouvrir",
	},
	nickname_received = {
		ru = "Вы получили кличку «%s»",
		en = 'You received the nickname "%s"',
		es = "Recibiste el apodo «%s»",
		fr = "Vous avez reçu le surnom « %s »",
	},
	nickname_all_owned = {
		ru = "Все клички уже есть",
		en = "You already own every nickname",
		es = "Ya tienes todos los apodos",
		fr = "Vous avez déjà tous les surnoms",
	},
	case_contents_title = {
		ru = "Кейс с предметами",
		en = "Case with items",
		es = "Caja con objetos",
		fr = "Caisse d'objets",
	},
	case_key_hint = {
		ru = "Ключ: %s ×%d",
		en = "Key: %s ×%d",
		es = "Llave: %s ×%d",
		fr = "Clé : %s ×%d",
	},
	-- shops / buyer [меню]
	price = { ru = "Цена", en = "Price", es = "Precio", fr = "Prix" },
	cost = { ru = "Стоимость", en = "Cost", es = "Coste", fr = "Coût" },
	per_block = { ru = "за 1 блок", en = "per block", es = "por bloque", fr = "par bloc" },
	in_inventory = {
		ru = "В инвентаре: %d",
		en = "In inventory: %d",
		es = "En inventario: %d",
		fr = "Dans l'inventaire : %d",
	},
	in_inventory_none = {
		ru = "В инвентаре нет",
		en = "None in inventory",
		es = "Ninguno en inventario",
		fr = "Aucun dans l'inventaire",
	},
	prices_multiplier = {
		ru = "Цены с вашим множителем",
		en = "Prices with your multiplier",
		es = "Precios con tu multiplicador",
		fr = "Prix avec votre multiplicateur",
	},
	opens_at_level = {
		ru = "Откроется с %d уровня",
		en = "Opens at level %d",
		es = "Se abre en el nivel %d",
		fr = "S'ouvre au niveau %d",
	},
	from_level = {
		ru = "С %d уровня",
		en = "From level %d",
		es = "Desde el nivel %d",
		fr = "Dès le niveau %d",
	},
	sell_title = {
		ru = "Скупщик блоков",
		en = "Block buyer",
		es = "Comprador de bloques",
		fr = "Acheteur de blocs",
	},
	-- trainer [меню]
	trainer = { ru = "Тренер", en = "Trainer", es = "Entrenador", fr = "Entraîneur" },
	trainer_prompt = { ru = "Тренер", en = "Trainer", es = "Entrenador", fr = "Entraîneur" },
	trainer_strength = { ru = "Сила", en = "Strength", es = "Fuerza", fr = "Force" },
	trainer_agility = { ru = "Ловкость", en = "Agility", es = "Agilidad", fr = "Agilité" },
	trainer_needs = { ru = "Нужды", en = "Needs", es = "Necesidades", fr = "Besoins" },
	trainer_strength_desc = {
		ru = "Увеличивает силу удара",
		en = "Increases hit strength",
		es = "Aumenta la fuerza del golpe",
		fr = "Augmente la force des coups",
	},
	trainer_agility_desc = {
		ru = "Позволяет увернуться от удара",
		en = "Lets you dodge a hit",
		es = "Permite esquivar un golpe",
		fr = "Permet d'esquiver un coup",
	},
	trainer_needs_desc = {
		ru = "Снижает потребность справлять нужду",
		en = "Reduces the need to relieve yourself",
		es = "Reduce la necesidad de hacer tus necesidades",
		fr = "Réduit le besoin de se soulager",
	},
	level_short = { ru = "Ур.", en = "Lv.", es = "Nv.", fr = "Niv." },
	requirements = {
		ru = "Требования",
		en = "Requirements",
		es = "Requisitos",
		fr = "Conditions",
	},
	requirements_not_met = {
		ru = "Требования не выполнены",
		en = "Requirements not met",
		es = "Requisitos no cumplidos",
		fr = "Conditions non remplies",
	},
	train = { ru = "Прокачать", en = "Train", es = "Mejorar", fr = "Entraîner" },
	trained = {
		ru = "%s: уровень %d",
		en = "%s: level %d",
		es = "%s: nivel %d",
		fr = "%s : niveau %d",
	},
	req_zombies = { ru = "Зомби", en = "Zombies", es = "Zombis", fr = "Zombies" },
	req_kills = { ru = "Убийства", en = "Kills", es = "Muertes", fr = "Éliminations" },
	req_money = { ru = "Деньги", en = "Money", es = "Dinero", fr = "Argent" },
	req_bats = {
		ru = "Летучие мыши",
		en = "Bats",
		es = "Murciélagos",
		fr = "Chauves-souris",
	},
	-- inventory / artifacts [меню]
	crafting = { ru = "Создание", en = "Crafting", es = "Creación", fr = "Fabrication" },
	artifact_rarity = { ru = "РЕДКОСТЬ", en = "RARITY", es = "RAREZA", fr = "RARETÉ" },
	artifact_finds_empty = {
		ru = "Здесь появятся находки",
		en = "Your finds will appear here",
		es = "Tus hallazgos aparecerán aquí",
		fr = "Vos trouvailles apparaîtront ici",
	},
	artifact_collected = {
		ru = "Собрано: %d",
		en = "Collected: %d",
		es = "Reunidos: %d",
		fr = "Collectés : %d",
	},
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
	touch_menu = { ru = "Меню", en = "Menu", es = "Menú", fr = "Menu" },
	touch_menu_upgrade = {
		ru = "Улучшить",
		en = "Upgrade",
		es = "Mejorar",
		fr = "Améliorer",
	},
	touch_menu_level = { ru = "Уровень", en = "Level up", es = "Nivel", fr = "Niveau" },
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
		ru = "Комбо ×%.2f   %d/%d",
		en = "Combo ×%.2f   %d/%d",
		es = "Combo ×%.2f   %d/%d",
		fr = "Combo ×%.2f   %d/%d",
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
	-- sent when a need runs out and its effect starts (no need bars any more) [владелец 21.10]
	need_effect_hygiene = {
		ru = "Тошнота: вы грязный. Помойтесь в Бане — в бассейне или под душем — или используйте мыло.",
		en = "Nausea: you are dirty. Wash in the Bath house — pool or shower — or use soap.",
		es = "Náuseas: estás sucio. Lávate en los baños — piscina o ducha — o usa jabón.",
		fr = "Nausée : vous êtes sale. Lavez-vous aux bains — bassin ou douche — ou utilisez du savon.",
	},
	need_effect_sleep = {
		ru = "Бессонница: копать нельзя. Поспите на кровати в Спальне или используйте спальный мешок.",
		en = "Insomnia: you can't dig. Sleep in a bed in the Dormitory or use a sleeping bag.",
		es = "Insomnio: no puedes cavar. Duerme en una cama del dormitorio o usa un saco de dormir.",
		fr = "Insomnie : impossible de creuser. Dormez dans un lit du dortoir ou utilisez un sac de couchage.",
	},
	need_effect_toilet = {
		ru = "Замедление: пора в туалет. Зайдите в уборную в Бане или используйте туалетную бумагу.",
		en = "Slowness: time for the toilet. Visit the toilets in the Bath house or use toilet paper.",
		es = "Lentitud: hora del baño. Ve a los aseos de los baños o usa papel higiénico.",
		fr = "Lenteur : il faut aller aux toilettes. Allez aux toilettes des bains ou utilisez du papier.",
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
	-- status effects (HUD icons, src/shared/Effects.luau); Minecraft names in each language
	effect_nausea = { ru = "Тошнота", en = "Nausea", es = "Náuseas", fr = "Nausée" },
	effect_insomnia = {
		ru = "Бессонница",
		en = "Insomnia",
		es = "Insomnio",
		fr = "Insomnie",
	},
	effect_slowness = {
		ru = "Замедление",
		en = "Slowness",
		es = "Lentitud",
		fr = "Lenteur",
	},
	effect_haste = { ru = "Спешка", en = "Haste", es = "Prisa", fr = "Célérité" },
	effect_speed = { ru = "Скорость", en = "Speed", es = "Velocidad", fr = "Vitesse" },
	effect_regeneration = {
		ru = "Регенерация",
		en = "Regeneration",
		es = "Regeneración",
		fr = "Régénération",
	},
	effect_strength = { ru = "Сила", en = "Strength", es = "Fuerza", fr = "Force" },
	effect_until_restored = {
		ru = "пока нужда на нуле",
		en = "while the need is at zero",
		es = "mientras la necesidad esté a cero",
		fr = "tant que le besoin est à zéro",
	},
	effect_insomnia_dig = {
		ru = "Бессонница: вы не можете копать. Поспите в Спальне или используйте спальный мешок.",
		en = "Insomnia: you can't dig. Sleep in the Dormitory or use a sleeping bag.",
		es = "Insomnio: no puedes cavar. Duerme en el Dormitorio o usa un saco de dormir.",
		fr = "Insomnie : vous ne pouvez pas creuser. Dormez au Dortoir ou utilisez un sac de couchage.",
	},
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
	item_bow = { ru = "Лук", en = "Bow", es = "Arco", fr = "Arc" },
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
	-- item tooltips (src/shared/ItemInfo.luau): property lines, Minecraft wording where vanilla has it
	tip_kind_tool = { ru = "Инструмент", en = "Tool", es = "Herramienta", fr = "Outil" },
	tip_kind_weapon = { ru = "Оружие", en = "Weapon", es = "Arma", fr = "Arme" },
	tip_kind_armor = { ru = "Броня", en = "Armor", es = "Armadura", fr = "Armure" },
	tip_kind_block = { ru = "Блок", en = "Block", es = "Bloque", fr = "Bloc" },
	tip_kind_food = { ru = "Еда", en = "Food", es = "Comida", fr = "Nourriture" },
	tip_kind_key = { ru = "Ключ", en = "Key", es = "Llave", fr = "Clé" },
	tip_kind_book = {
		ru = "Древняя книга",
		en = "Ancient book",
		es = "Libro antiguo",
		fr = "Livre ancien",
	},
	tip_kind_consumable = {
		ru = "Расходник",
		en = "Consumable",
		es = "Consumible",
		fr = "Consommable",
	},
	tip_kind_item = { ru = "Предмет", en = "Item", es = "Objeto", fr = "Objet" },
	tip_main_hand = {
		ru = "В основной руке:",
		en = "When in Main Hand:",
		es = "En la mano principal:",
		fr = "Dans la main principale :",
	},
	tip_on_body = {
		ru = "На теле:",
		en = "When on Body:",
		es = "En el cuerpo:",
		fr = "Sur le corps :",
	},
	tip_attack_damage = {
		ru = "%s урона атаки",
		en = "%s Attack Damage",
		es = "%s de daño de ataque",
		fr = "%s de dégâts d'attaque",
	},
	tip_attack_speed = {
		ru = "%s скорости атаки",
		en = "%s Attack Speed",
		es = "%s de velocidad de ataque",
		fr = "%s de vitesse d'attaque",
	},
	tip_mining_speed = {
		ru = "%s скорости копания",
		en = "%s Mining Speed",
		es = "%s de velocidad de minado",
		fr = "%s de vitesse de minage",
	},
	tip_armor = {
		ru = "+%s к броне",
		en = "+%s Armor",
		es = "+%s de armadura",
		fr = "+%s d'armure",
	},
	tip_toughness = {
		ru = "+%s к твёрдости брони",
		en = "+%s Armor Toughness",
		es = "+%s de dureza de armadura",
		fr = "+%s de robustesse d'armure",
	},
	tip_upgrade_level = {
		ru = "Уровень улучшения: %d / %d",
		en = "Upgrade level: %d / %d",
		es = "Nivel de mejora: %d / %d",
		fr = "Niveau d'amélioration : %d / %d",
	},
	tip_ancient_slots = {
		ru = "Древние зачарования: %d / %d",
		en = "Ancient enchantments: %d / %d",
		es = "Encantamientos antiguos: %d / %d",
		fr = "Enchantements anciens : %d / %d",
	},
	tip_block_tool = {
		ru = "Добывается: %s",
		en = "Harvested with: %s",
		es = "Se extrae con: %s",
		fr = "S'extrait avec : %s",
	},
	tip_block_any_tool = {
		ru = "Добывается любым инструментом и рукой",
		en = "Harvested with any tool or by hand",
		es = "Se extrae con cualquier herramienta o a mano",
		fr = "S'extrait avec n'importe quel outil ou à la main",
	},
	tip_sell_price = {
		ru = "Цена у скупщика: %s $",
		en = "Buyer price: %s $",
		es = "Precio del comprador: %s $",
		fr = "Prix chez l'acheteur : %s $",
	},
	tip_not_sellable = {
		ru = "Скупщик не принимает",
		en = "The buyer doesn't take it",
		es = "El comprador no lo acepta",
		fr = "L'acheteur ne le prend pas",
	},
	tip_food = {
		ru = "Восстанавливает %s голода",
		en = "Restores %s hunger",
		es = "Restaura %s de hambre",
		fr = "Restaure %s de faim",
	},
	tip_heals = {
		ru = "Восстанавливает %s ❤",
		en = "Restores %s ❤",
		es = "Restaura %s ❤",
		fr = "Restaure %s ❤",
	},
	tip_restores_need = {
		ru = "Снимает нужду: %s",
		en = "Restores need: %s",
		es = "Satisface la necesidad: %s",
		fr = "Satisfait le besoin : %s",
	},
	tip_opens = {
		ru = "Открывает: %s",
		en = "Opens: %s",
		es = "Abre: %s",
		fr = "Ouvre : %s",
	},
	tip_contains_money = {
		ru = "Внутри: %s $",
		en = "Contains: %s $",
		es = "Contiene: %s $",
		fr = "Contient : %s $",
	},
	tip_book_targets = {
		ru = "Подходит для: %s",
		en = "Applies to: %s",
		es = "Se aplica a: %s",
		fr = "S'applique à : %s",
	},
	tip_apply_chance = {
		ru = "Шанс наложения: %d %%",
		en = "Apply chance: %d%%",
		es = "Probabilidad de aplicar: %d %%",
		fr = "Chance d'application : %d %%",
	},
	rarity_common = { ru = "Обычное", en = "Common", es = "Común", fr = "Commun" },
	rarity_rare = { ru = "Редкое", en = "Rare", es = "Raro", fr = "Rare" },
	rarity_legendary = {
		ru = "Легендарное",
		en = "Legendary",
		es = "Legendario",
		fr = "Légendaire",
	},
	-- ancient enchantments [меню] (wiki/client-audit/BOOKS-SYSTEM.md); %s = strength of the level
	book_trader = { ru = "Барыга", en = "Hustler", es = "Buhonero", fr = "Trafiquant" },
	book_toxic = { ru = "Токсичный", en = "Toxic", es = "Tóxico", fr = "Toxique" },
	book_berserk = { ru = "Берсерк", en = "Berserk", es = "Berserker", fr = "Berserker" },
	book_springs = { ru = "Пружины", en = "Springs", es = "Resortes", fr = "Ressorts" },
	book_tank = { ru = "Танк", en = "Tank", es = "Tanque", fr = "Tank" },
	book_archaeologist = {
		ru = "Археолог",
		en = "Archaeologist",
		es = "Arqueólogo",
		fr = "Archéologue",
	},
	book_hammer = { ru = "Молот", en = "Hammer", es = "Martillo", fr = "Marteau" },
	book_vampirism = {
		ru = "Вампиризм",
		en = "Vampirism",
		es = "Vampirismo",
		fr = "Vampirisme",
	},
	book_enlightened = {
		ru = "Просвещённый",
		en = "Enlightened",
		es = "Iluminado",
		fr = "Illuminé",
	},
	book_silk_touch = {
		ru = "Шёлковое касание",
		en = "Silk Touch",
		es = "Toque de seda",
		fr = "Toucher de soie",
	},
	book_desc_trader = {
		ru = "При добыче шанс %s получить ещё один такой же блок",
		en = "When mining, %s chance to get one more of the same block",
		es = "Al minar, %s de probabilidad de obtener otro bloque igual",
		fr = "En minant, %s de chances d'obtenir un bloc identique en plus",
	},
	book_desc_toxic = {
		ru = "При ударе шанс %s отравить врага",
		en = "On hit, %s chance to poison the enemy",
		es = "Al golpear, %s de probabilidad de envenenar al enemigo",
		fr = "À l'impact, %s de chances d'empoisonner l'ennemi",
	},
	book_desc_berserk = {
		ru = "Если у вас меньше 10 сердец, шанс %s нанести двойной урон",
		en = "Below 10 hearts, %s chance to deal double damage",
		es = "Con menos de 10 corazones, %s de probabilidad de hacer daño doble",
		fr = "Sous 10 cœurs, %s de chances d'infliger des dégâts doublés",
	},
	book_desc_springs = {
		ru = "Прыжок выше на %s бл.",
		en = "Jump %s block(s) higher",
		es = "Salto %s bloque(s) más alto",
		fr = "Saut plus haut de %s bloc(s)",
	},
	book_desc_tank = {
		ru = "+%s ❤ к здоровью",
		en = "+%s ❤ max health",
		es = "+%s ❤ de salud",
		fr = "+%s ❤ de santé",
	},
	book_desc_archaeologist = {
		ru = "При добыче шанс %s получить ускоренное копание",
		en = "When mining, %s chance to get faster digging",
		es = "Al minar, %s de probabilidad de cavar más rápido",
		fr = "En minant, %s de chances de creuser plus vite",
	},
	book_desc_hammer = {
		ru = "При добыче шанс %s вскопать блоки вокруг",
		en = "When mining, %s chance to dig the blocks around",
		es = "Al minar, %s de probabilidad de cavar los bloques de alrededor",
		fr = "En minant, %s de chances de creuser les blocs autour",
	},
	book_desc_vampirism = {
		ru = "Лечит на %s от нанесённого урона",
		en = "Heals %s of the damage dealt",
		es = "Cura el %s del daño infligido",
		fr = "Soigne %s des dégâts infligés",
	},
	book_desc_enlightened = {
		ru = "При получении урона шанс %s восстановить здоровье",
		en = "When hurt, %s chance to restore health",
		es = "Al recibir daño, %s de probabilidad de recuperar salud",
		fr = "En subissant des dégâts, %s de chances de récupérer de la santé",
	},
	book_desc_silk_touch = {
		ru = "Блоки выпадают сами собой",
		en = "Mined blocks drop as themselves",
		es = "Los bloques minados caen tal cual",
		fr = "Les blocs minés tombent tels quels",
	},
	-- item descriptions (lore) where the configs can't tell what the item does [меню, клиент]
	desc_ancient_star = {
		ru = "Падает с боссов и из Обычного кейса. Меняется на ключи у обменника звёзд на Рынке",
		en = "Dropped by bosses and the Ordinary case. Trade it for keys at the star exchange in the Market",
		es = "La sueltan los jefes y la caja común. Cámbiala por llaves en el cambio de estrellas del Mercado",
		fr = "Lâchée par les boss et la caisse ordinaire. Échangez-la contre des clés au Marché",
	},
	desc_ancient_powder = {
		ru = "+2 % к шансу наложения древней книги за штуку",
		en = "+2% apply chance of an ancient book per piece",
		es = "+2 % de probabilidad de aplicar un libro antiguo por unidad",
		fr = "+2 % de chance d'application d'un livre ancien par unité",
	},
	desc_dispeller = {
		ru = "Снимает все древние зачарования с предмета. Книги не возвращаются",
		en = "Removes all ancient enchantments from an item. Books are not returned",
		es = "Quita todos los encantamientos antiguos de un objeto. Los libros no se devuelven",
		fr = "Retire tous les enchantements anciens d'un objet. Les livres ne sont pas rendus",
	},
	desc_basement_pass = {
		ru = "Открывает вход в Подвал",
		en = "Lets you into the Basement",
		es = "Da acceso al Sótano",
		fr = "Donne accès au Sous-sol",
	},
	desc_oblivion_scroll = {
		ru = "Сбрасывает древо навыков",
		en = "Resets the skill tree",
		es = "Reinicia el árbol de habilidades",
		fr = "Réinitialise l'arbre de compétences",
	},
	desc_moon_steel = {
		ru = "4 штуки меняются на Лунное лезвие у обменника осколков",
		en = "Trade 4 for a Moon blade at the shard exchange",
		es = "Cambia 4 por una Hoja lunar en el cambio de fragmentos",
		fr = "Échangez-en 4 contre une Lame lunaire",
	},
	desc_fire_shard = {
		ru = "4 штуки меняются на Вулканический камень у обменника осколков",
		en = "Trade 4 for a Volcanic stone at the shard exchange",
		es = "Cambia 4 por una Piedra volcánica en el cambio de fragmentos",
		fr = "Échangez-en 4 contre une Pierre volcanique",
	},
	desc_moon_blade = {
		ru = "Топор максимального уровня: новый облик и Эффективность IV",
		en = "Max-level axe: new look and Efficiency IV",
		es = "Hacha de nivel máximo: nuevo aspecto y Eficiencia IV",
		fr = "Hache de niveau max : nouvel aspect et Efficacité IV",
	},
	desc_volcanic_stone = {
		ru = "Меч максимального уровня поджигает тех, кого бьёт",
		en = "A max-level sword sets its targets on fire",
		es = "Una espada de nivel máximo prende fuego a sus objetivos",
		fr = "Une épée de niveau max enflamme ses cibles",
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

-- True when the key exists in that locale (tooltips skip lines that are not translated yet).
function Strings.has(key: string, locale: string?): boolean
	local entry = STRINGS[key]
	return entry ~= nil and entry[locale or Config.defaultLocale] ~= nil
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

-- World signs, block names, upgrade counters and location names are Russian in the map/config
-- (the source of truth); these tables translate them for the other locales [владелец 21.10].
local WORLD: { [string]: { [string]: string } } = {
	["Спавн"] = { en = "Spawn", es = "Spawn", fr = "Spawn" },
	["Телепортатор"] = {
		en = "Teleporter",
		es = "Teletransportador",
		fr = "Téléporteur",
	},
	["Тренер"] = { en = "Trainer", es = "Entrenador", fr = "Entraîneur" },
	["Баня"] = { en = "Bathhouse", es = "Baños", fr = "Bains" },
	["Рынок"] = { en = "Market", es = "Mercado", fr = "Marché" },
	["Столовая"] = { en = "Canteen", es = "Comedor", fr = "Cantine" },
	["Спальня"] = { en = "Bedroom", es = "Dormitorio", fr = "Dortoir" },
	["Шахта"] = { en = "Mine", es = "Mina", fr = "Mine" },
	["Малая шахта"] = { en = "Small mine", es = "Mina pequeña", fr = "Petite mine" },
	["Тюрьма"] = { en = "Prison", es = "Prisión", fr = "Prison" },
	["Задания"] = { en = "Quests", es = "Misiones", fr = "Quêtes" },
	["Витрина"] = { en = "Showcase", es = "Vitrina", fr = "Vitrine" },
	["Скупщик блоков"] = {
		en = "Block buyer",
		es = "Comprador de bloques",
		fr = "Acheteur de blocs",
	},
	["Продавец предметов"] = {
		en = "Item seller",
		es = "Vendedor de objetos",
		fr = "Vendeur d'objets",
	},
	["Продавец еды"] = {
		en = "Food seller",
		es = "Vendedor de comida",
		fr = "Vendeur de nourriture",
	},
	["Обменник звёзд"] = {
		en = "Star exchange",
		es = "Cambio de estrellas",
		fr = "Échange d'étoiles",
	},
	["Обменник осколков"] = {
		en = "Shard exchange",
		es = "Cambio de fragmentos",
		fr = "Échange d'éclats",
	},
	["Охранник"] = { en = "Guard", es = "Guardia", fr = "Gardien" },
	["Обычный кейс"] = {
		en = "Ordinary case",
		es = "Caja común",
		fr = "Caisse ordinaire",
	},
	["Древний кейс"] = {
		en = "Ancient case",
		es = "Caja antigua",
		fr = "Caisse antique",
	},
	["Кейс артефактов"] = {
		en = "Artifact case",
		es = "Caja de artefactos",
		fr = "Caisse d'artefacts",
	},
	["Кейс с кличками"] = {
		en = "Nickname case",
		es = "Caja de apodos",
		fr = "Caisse des surnoms",
	},
	["Эндер-сундук"] = {
		en = "Ender chest",
		es = "Cofre de Ender",
		fr = "Coffre de l'Ender",
	},
	["Проводник: продать"] = {
		en = "Buyer: sell",
		es = "Comprador: vender",
		fr = "Acheteur : vendre",
	},
	["Зачарованная: "] = {
		en = "Enchanted: ",
		es = "Encantada: ",
		fr = "Enchantée : ",
	},
	["Ножницы"] = { en = "Shears", es = "Tijeras", fr = "Cisailles" },
}
local BLOCKS: { [string]: { [string]: string } } = {
	["sand"] = { en = "Sand", es = "Arena", fr = "Sable" },
	["gravel"] = { en = "Gravel", es = "Grava", fr = "Gravier" },
	["dirt"] = { en = "Dirt", es = "Tierra", fr = "Terre" },
	["oak_log"] = { en = "Oak log", es = "Tronco de roble", fr = "Bûche de chêne" },
	["melon"] = { en = "Melon", es = "Sandía", fr = "Pastèque" },
	["melon_slice"] = { en = "Melon slice", es = "Rodaja de sandía", fr = "Tranche de pastèque" },
	["cobblestone"] = { en = "Cobblestone", es = "Piedra labrada", fr = "Pierre taillée" },
	["stone"] = { en = "Stone", es = "Piedra", fr = "Pierre" },
	["coal"] = { en = "Coal", es = "Carbón", fr = "Charbon" },
	["coal_ore"] = { en = "Coal ore", es = "Mena de carbón", fr = "Minerai de charbon" },
	["iron_ore"] = { en = "Iron ore", es = "Mena de hierro", fr = "Minerai de fer" },
	["coal_block"] = { en = "Coal block", es = "Bloque de carbón", fr = "Bloc de charbon" },
	["red_sand"] = { en = "Red sand", es = "Arena roja", fr = "Sable rouge" },
	["gold_ore"] = { en = "Gold ore", es = "Mena de oro", fr = "Minerai d'or" },
	["netherite"] = { en = "Netherite", es = "Netherita", fr = "Netherite" },
	["soul_sand"] = { en = "Soul sand", es = "Arena de almas", fr = "Sable des âmes" },
	["quartz"] = { en = "Nether quartz", es = "Cuarzo del Nether", fr = "Quartz du Nether" },
	["quartz_ore"] = {
		en = "Nether quartz ore",
		es = "Mena de cuarzo del Nether",
		fr = "Minerai de quartz du Nether",
	},
	["sandstone"] = { en = "Sandstone", es = "Arenisca", fr = "Grès" },
	["red_sandstone"] = { en = "Red sandstone", es = "Arenisca roja", fr = "Grès rouge" },
	["wisteria_leaves"] = {
		en = "Pink wisteria leaves",
		es = "Hojas de glicinia rosa",
		fr = "Feuilles de glycine rose",
	},
	["cherry_log"] = { en = "Cherry log", es = "Tronco de cerezo", fr = "Bûche de cerisier" },
	["cyan_concrete"] = { en = "Cyan concrete", es = "Hormigón cian", fr = "Béton cyan" },
	["prismarine"] = { en = "Prismarine", es = "Prismarina", fr = "Prismarine" },
	["prismarine_bricks"] = {
		en = "Prismarine bricks",
		es = "Ladrillos de prismarina",
		fr = "Briques de prismarine",
	},
	["end_stone_bricks"] = {
		en = "End stone bricks",
		es = "Ladrillos de piedra del End",
		fr = "Briques de pierre de l'End",
	},
	["purpur"] = { en = "Purpur", es = "Purpur", fr = "Purpur" },
	["white_wool"] = { en = "White wool", es = "Lana blanca", fr = "Laine blanche" },
	["cobweb"] = { en = "Cobweb", es = "Telaraña", fr = "Toile d'araignée" },
	["ice"] = { en = "Ice", es = "Hielo", fr = "Glace" },
	["packed_ice"] = { en = "Packed ice", es = "Hielo compacto", fr = "Glace compactée" },
	["yellow_wool"] = { en = "Yellow wool", es = "Lana amarilla", fr = "Laine jaune" },
	["red_wool"] = { en = "Red wool", es = "Lana roja", fr = "Laine rouge" },
	["lime_wool"] = { en = "Lime wool", es = "Lana verde lima", fr = "Laine vert clair" },
	["orange_concrete"] = { en = "Orange concrete", es = "Hormigón naranja", fr = "Béton orange" },
	["yellow_concrete"] = { en = "Yellow concrete", es = "Hormigón amarillo", fr = "Béton jaune" },
	["lime_concrete"] = {
		en = "Lime concrete",
		es = "Hormigón verde lima",
		fr = "Béton vert clair",
	},
	["purple_concrete"] = { en = "Purple concrete", es = "Hormigón morado", fr = "Béton violet" },
	["red_concrete"] = { en = "Red concrete", es = "Hormigón rojo", fr = "Béton rouge" },
	["quartz_block"] = { en = "Quartz block", es = "Bloque de cuarzo", fr = "Bloc de quartz" },
	["chiseled_quartz"] = {
		en = "Chiseled quartz block",
		es = "Bloque de cuarzo cincelado",
		fr = "Bloc de quartz sculpté",
	},
	["dark_oak_leaves"] = {
		en = "Dark oak leaves",
		es = "Hojas de roble oscuro",
		fr = "Feuilles de chêne noir",
	},
	["pink_wool"] = { en = "Pink wool", es = "Lana rosa", fr = "Laine rose" },
	["sea_lantern"] = { en = "Sea lantern", es = "Linterna marina", fr = "Lanterne aquatique" },
	["pumpkin"] = { en = "Pumpkin", es = "Calabaza", fr = "Citrouille" },
	["green_wool"] = { en = "Green wool", es = "Lana verde", fr = "Laine verte" },
	["jack_o_lantern"] = {
		en = "Jack o'lantern",
		es = "Calabaza iluminada",
		fr = "Citrouille-lanterne",
	},
	["magenta_concrete"] = {
		en = "Magenta concrete",
		es = "Hormigón magenta",
		fr = "Béton magenta",
	},
	["black_glass"] = { en = "Black glass", es = "Vidrio negro", fr = "Verre noir" },
	["white_concrete"] = { en = "White concrete", es = "Hormigón blanco", fr = "Béton blanc" },
	["clay"] = { en = "Clay", es = "Arcilla", fr = "Argile" },
	["chiseled_sandstone"] = {
		en = "Chiseled sandstone",
		es = "Arenisca cincelada",
		fr = "Grès sculpté",
	},
	["brown_mushroom_block"] = {
		en = "Brown mushroom block",
		es = "Bloque de champiñón marrón",
		fr = "Bloc de champignon brun",
	},
	["snow"] = { en = "Snow", es = "Nieve", fr = "Neige" },
	["smooth_sandstone"] = { en = "Smooth sandstone", es = "Arenisca lisa", fr = "Grès lisse" },
	["red_mushroom_block"] = {
		en = "Red mushroom block",
		es = "Bloque de champiñón rojo",
		fr = "Bloc de champignon rouge",
	},
	["lapis_block"] = {
		en = "Lapis lazuli block",
		es = "Bloque de lapislázuli",
		fr = "Bloc de lapis-lazuli",
	},
	["iron_block"] = { en = "Iron block", es = "Bloque de hierro", fr = "Bloc de fer" },
	["gold_block"] = { en = "Gold block", es = "Bloque de oro", fr = "Bloc d'or" },
	["diamond_block"] = { en = "Diamond block", es = "Bloque de diamante", fr = "Bloc de diamant" },
}
local COUNTERS: { [string]: { [string]: string } } = {
	["Камень"] = { en = "Stone", es = "Piedra", fr = "Pierre" },
	["Каменный уголь"] = {
		en = "Coal ore",
		es = "Mena de carbón",
		fr = "Minerai de charbon",
	},
	["Железная руда"] = {
		en = "Iron ore",
		es = "Mena de hierro",
		fr = "Minerai de fer",
	},
	["Золотая руда"] = { en = "Gold ore", es = "Mena de oro", fr = "Minerai d'or" },
	["Гравий"] = { en = "Gravel", es = "Grava", fr = "Gravier" },
	["Песок"] = { en = "Sand", es = "Arena", fr = "Sable" },
	["Земля"] = { en = "Dirt", es = "Tierra", fr = "Terre" },
	["Крысы"] = { en = "Rats", es = "Ratas", fr = "Rats" },
	["Оружейник"] = { en = "Armorer", es = "Armero", fr = "Armurier" },
	["Дерево"] = { en = "Wood", es = "Madera", fr = "Bois" },
	["Арбуз"] = { en = "Melon", es = "Sandía", fr = "Pastèque" },
}
local LOCATIONS: { [string]: { [string]: string } } = {
	["Тюрьма"] = { en = "Prison", es = "Prisión", fr = "Prison" },
	["Каменоломня"] = { en = "Quarry", es = "Cantera", fr = "Carrière" },
	["Подножье горы"] = {
		en = "Mountain foot",
		es = "Pie de la montaña",
		fr = "Pied de la montagne",
	},
	["Преисподняя"] = { en = "Underworld", es = "Inframundo", fr = "Enfers" },
	["Пирамида"] = { en = "Pyramid", es = "Pirámide", fr = "Pyramide" },
	["Королевский сад"] = {
		en = "Royal garden",
		es = "Jardín real",
		fr = "Jardin royal",
	},
	["Затопленный маяк"] = {
		en = "Sunken lighthouse",
		es = "Faro hundido",
		fr = "Phare englouti",
	},
	["Пустотная крепость"] = {
		en = "Void fortress",
		es = "Fortaleza del vacío",
		fr = "Forteresse du vide",
	},
	["Паучье логово"] = {
		en = "Spider lair",
		es = "Guarida de arañas",
		fr = "Antre des araignées",
	},
	["Снежная даль"] = {
		en = "Snowy reach",
		es = "Lejanía nevada",
		fr = "Lointain enneigé",
	},
	["Снежная далнь"] = {
		en = "Snowy reach",
		es = "Lejanía nevada",
		fr = "Lointain enneigé",
	},
	["Рынок"] = { en = "Market", es = "Mercado", fr = "Marché" },
	["Лепреконовая долина"] = {
		en = "Leprechaun valley",
		es = "Valle del duende",
		fr = "Vallée des leprechauns",
	},
	["Замок"] = { en = "Castle", es = "Castillo", fr = "Château" },
	["Изнанка"] = { en = "The Other Side", es = "El reverso", fr = "L'Envers" },
	["Киото"] = { en = "Kyoto", es = "Kioto", fr = "Kyoto" },
	["Ферма"] = { en = "Farm", es = "Granja", fr = "Ferme" },
	["Амбар"] = { en = "Barn", es = "Granero", fr = "Grange" },
	["Врата края"] = { en = "End gate", es = "Puerta del Fin", fr = "Porte de l'End" },
	["Древо"] = { en = "The Tree", es = "El Árbol", fr = "L'Arbre" },
	["Церковь"] = { en = "Church", es = "Iglesia", fr = "Église" },
	["Чистилище"] = { en = "Purgatory", es = "Purgatorio", fr = "Purgatoire" },
	["Эдем"] = { en = "Eden", es = "Edén", fr = "Éden" },
	["Херувимы"] = { en = "Cherubim", es = "Querubines", fr = "Chérubins" },
	["Врата"] = { en = "Gates", es = "Puertas", fr = "Portes" },
	["Рай"] = { en = "Paradise", es = "Paraíso", fr = "Paradis" },
	["Подвал"] = { en = "Basement", es = "Sótano", fr = "Sous-sol" },
	["База фракций"] = {
		en = "Faction base",
		es = "Base de facciones",
		fr = "Base des factions",
	},
	["Дворы"] = { en = "Yards", es = "Patios", fr = "Cours" },
	["Гетто"] = { en = "Ghetto", es = "Gueto", fr = "Ghetto" },
	["База банды"] = { en = "Gang base", es = "Base de la banda", fr = "Base du gang" },
	["Личная камера"] = {
		en = "Private cell",
		es = "Celda privada",
		fr = "Cellule privée",
	},
	["Мертвозавод"] = { en = "Dead factory", es = "Fábrica muerta", fr = "Usine morte" },
	["Карьеры"] = { en = "Quarries", es = "Canteras", fr = "Carrières" },
}

local function pick(table_: { [string]: { [string]: string } }, ru: string, locale: string?): string
	local loc = locale or Config.defaultLocale
	if loc == "ru" then
		return ru
	end
	local row = table_[ru]
	return if row and row[loc] then row[loc] else ru
end

-- Text of a world sign (BillboardGui / SurfaceGui label built in Russian). Keeps upper case.
function Strings.worldText(ru: string, locale: string?): string
	local upper = ru == string.upper(ru) and ru ~= string.lower(ru)
	local key = if upper then nil else ru
	if not key then
		for candidate in pairs(WORLD) do
			if string.upper(candidate) == ru then
				key = candidate
				break
			end
		end
	end
	if not key then
		return ru
	end
	local text = pick(WORLD, key, locale)
	return if upper then string.upper(text) else text
end

function Strings.blockName(id: string, ruName: string, locale: string?): string
	local loc = locale or Config.defaultLocale
	if loc == "ru" then
		return ruName
	end
	local row = BLOCKS[id]
	return if row and row[loc] then row[loc] else ruName
end

function Strings.counterName(ru: string, locale: string?): string
	return pick(COUNTERS, ru, locale)
end

function Strings.locationName(ru: string, locale: string?): string
	return pick(LOCATIONS, ru, locale)
end

-- string.lower only handles ASCII; Cyrillic capitals (А–Я, Ё) need their own mapping.
local function utf8lower(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		if code >= 0x0410 and code <= 0x042F then
			code += 0x20
		elseif code == 0x0401 then
			code = 0x0451
		elseif code >= 65 and code <= 90 then
			code += 32
		end
		table.insert(out, utf8.char(code))
	end
	return table.concat(out)
end

function Strings.itemName(id: string, level: number?, locale: string?): string
	local loc = locale or Config.defaultLocale
	local block = Config.block(id)
	if block then
		return Strings.blockName(id, block.name, loc)
	end
	local key = "item_" .. id
	local base = Strings.t(key, loc)
	if id == "ancient_book" and level then
		return base .. " " .. tostring(level)
	end
	if Config.tools[id] and level then
		local material = Strings.t("mat_" .. Config.materialForLevel(level), loc)
		if loc == "es" or loc == "fr" then
			return base .. " " .. utf8lower(material) -- "Pala de madera", "Pelle en bois"
		end
		return material .. " " .. utf8lower(base)
	end
	return base
end

-- Full tool/armor names for tooltips, as Minecraft says them in each language: armor tiers are
-- leather / chainmail / iron / diamond; Russian adjectives agree with the noun's gender; Spanish and
-- French put the material after the noun. Other items: same as itemName.
local ARMOR_PIECES = { helmet = true, chestplate = true, leggings = true, boots = true }
local RU_GENDER: { [string]: string } = {
	pickaxe = "f",
	shovel = "f",
	axe = "m",
	sword = "m",
	helmet = "m",
	chestplate = "m",
	leggings = "p",
	boots = "p",
}
local RU_STEMS = {
	tool = {
		wood = "Деревянн",
		stone = "Каменн",
		iron = "Железн",
		diamond = "Алмазн",
	},
	armor = {
		wood = "Кожан",
		stone = "Кольчужн",
		iron = "Железн",
		diamond = "Алмазн",
	},
}
local RU_ENDINGS = { f = "ая", m = "ый", p = "ые" }
local MATERIAL_WORDS: { [string]: { tool: { [string]: string }, armor: { [string]: string } } } = {
	en = {
		tool = { wood = "Wooden", stone = "Stone", iron = "Iron", diamond = "Diamond" },
		armor = { wood = "Leather", stone = "Chainmail", iron = "Iron", diamond = "Diamond" },
	},
	es = {
		tool = {
			wood = "de madera",
			stone = "de piedra",
			iron = "de hierro",
			diamond = "de diamante",
		},
		armor = {
			wood = "de cuero",
			stone = "de malla",
			iron = "de hierro",
			diamond = "de diamante",
		},
	},
	fr = {
		tool = { wood = "en bois", stone = "en pierre", iron = "en fer", diamond = "en diamant" },
		armor = { wood = "en cuir", stone = "en mailles", iron = "en fer", diamond = "en diamant" },
	},
}
function Strings.itemFullName(id: string, level: number?, locale: string?): string
	local loc = locale or Config.defaultLocale
	if not (Config.tools[id] and level) then
		return Strings.itemName(id, level, loc)
	end
	local material = Config.materialForLevel(level :: number)
	local kind = if ARMOR_PIECES[id] then "armor" else "tool"
	local noun = Strings.t("item_" .. id, loc)
	if loc == "ru" then
		local ending = RU_ENDINGS[RU_GENDER[id] or "m"]
		return RU_STEMS[kind][material] .. ending .. " " .. utf8lower(noun)
	end
	local words = MATERIAL_WORDS[loc] or MATERIAL_WORDS.en
	local word = words[kind][material]
	if loc == "es" or loc == "fr" then
		return noun .. " " .. word
	end
	return word .. " " .. utf8lower(noun)
end

return Strings
