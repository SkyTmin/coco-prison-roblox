"""Transcribe the 61 preserved store, /pp, boss and teleporter screenshots.

Names and numbers below were read manually at original resolution. Observation IDs
are local evidence references, never invented server IDs. Timers are snapshots.
"""
from pathlib import Path
import collections
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
manifest = json.loads((OUT / 'late-menu-sources.json').read_text(encoding='utf-8'))
old_mines = json.loads((OUT / 'mine-menu-recovery.json').read_text(encoding='utf-8'))
localization = json.loads((OUT / 'classic-content-index.json').read_text(encoding='utf-8'))
source_by_id = {s['id']: s for s in manifest['sources']}
mine_by_name = {m['name']: m for m in old_mines['mineLocations']}


def write_json(name, value):
    (OUT / name).write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def evidence(ids):
    return ', '.join(f"[{sid}]({source_by_id[sid]['evidencePath']})" for sid in ids)


def hhmmss(value):
    h, m, s = map(int, value.split(':'))
    return h * 3600 + m * 60 + s


def level_text(row):
    if row['unlockLevel'] is not None:
        return str(row['unlockLevel'])
    return 'Стартовая' if row['startingLocationLabel'] else 'Уже открыта на 8; точный порог неизвестен'


raw_mines = [
    (8, 'Подножье горы', ['Красный песок', 'Железная руда', 'Золотая руда']),
    (9, 'Преисподняя', ['Незерит', 'Незер-кварцевая руда', 'Песок душ']),
    (10, 'Пирамида', ['Красный песчаник', 'Песчаник']),
    (11, 'Королевский сад', ['Розовые листья глицинии', 'Вишнёвое дерево']),
    (12, 'Затопленный маяк', ['Призмарин', 'Призмариновые кирпичи', 'Бирюзовый цемент']),
    (13, 'Пустотная крепость', ['Эндерняковые кирпичи', 'Пурпур']),
    (14, 'Паучье логово', ['Паутина', 'Белая шерсть']),
    (15, 'Снежная длань', ['Лёд', 'Плотный лёд']),
    (16, 'Рынок', ['Красная шерсть', 'Жёлтая шерсть', 'Лаймовая шерсть']),
    (17, 'Лепреконовая долина', ['Жёлтый цемент', 'Оранжевый цемент', 'Лаймовый цемент', 'Фиолетовый цемент', 'Красный цемент']),
    (18, 'Замок', ['Кварцевый блок', 'Резной кварцевый блок']),
    (19, 'Изнанка', ['Листья мрачного дуба']),
    (20, 'Киото', ['Розовая шерсть', 'Морской фонарь']),
    (21, 'Ферма', ['Арбуз', 'Тыква', 'Зелёная шерсть']),
    (22, 'Тюрьма', ['Земля', 'Песок', 'Гравий', 'Дуб', 'Арбуз']),
    (23, 'Тюрьма', ['Земля', 'Песок', 'Гравий', 'Дуб', 'Арбуз']),
    (24, 'Амбар', ['Светильник Джека']),
    (25, 'Врата края', ['Пурпурный цемент', 'Чёрное стекло']),
    (26, 'Древо', ['Белый цемент']),
    (27, 'Церковь', ['Глина']),
    (28, 'Чистилище', ['Резной песчаник']),
    (29, 'Эдем', ['Гриб']),
    (30, 'Херувимы', ['Снег']),
    (31, 'Врата', ['Гладкий песчаник']),
    (32, 'Рай', ['Гриб']),
    (33, 'Каменоломня', ['Камень', 'Железная руда', 'Каменный уголь', 'Угольный блок']),
]
mines = []
for n, name, materials in raw_mines:
    prior = mine_by_name[name]
    timer = '00:01:48' if name == 'Каменоломня' else '00:00:48'
    mines.append(dict(observationId=f'shop_mines_{n}', serverId=None, name=name,
        evidence=[f'shop_mines_{n}'], materials=[dict(displayName=m, materialId=None, weight=None, salePrice=None) for m in materials],
        unlockLevel=prior['unlockLevel'], startingLocationLabel=prior['startingLocationLabel'],
        observedAccessibleAtLevel=prior['observedAccessibleAtLevel'],
        unlockEvidence=dict(dataset='mine-menu-recovery.json', evidence=prior['evidence'], match='exact display name; not server ID'),
        displayedTime=dict(label='Время до респавна', display=timer, seconds=hhmmss(timer), meaning='remaining-time snapshot; server update cadence unverified'),
        resetIntervalSeconds=None, dimensions=None, requiredTool=None,
        duplicateNameOccurrence=1 if n == 22 else (2 if n == 23 else None),
        visualVariant='brown-looking preview' if name == 'Эдем' else ('red-looking preview' if name == 'Рай' else None)))
mine_data = dict(recordedDate='2026-10-19', sourceType='manually transcribed supplied game screenshots',
    sourcesManifest='late-menu-sources.json', sourceIds=[f'shop_mines_{n}' for n in range(8, 34)],
    menuCountDisplay='26 / 26', entries=mines,
    scope='26 selected rows, 25 distinct displayed names; all 25 names from earlier /mines tabs are covered',
    caveats=[
        'Two separate rows display Тюрьма with the same five resource labels; their server IDs and relationship to Малая шахта are unknown.',
        'Resource labels are literal menu names; do not normalize Незерит to Незеррак or цемент to a guessed Minecraft ID.',
        'Гриб appears for both Эдем and Рай with different preview colors; identical labels do not prove identical IDs.',
        '00:00:48 repeats across 25 cards; it is a remaining-time observation, not proof of a 48-second reset interval.',
        'A raw PRISON.CLASSIC.PRISON_PLUS.GUI.RESPAWN_COOLDOWN localization key overlaps/clips near the timer; it is not a numeric rule.',
        'Percent composition, block prices, dimensions, tools and complete reset intervals are not shown.',
        'Earlier /mines icon palettes are visual observations and are not exhaustive resource lists.',
    ])
write_json('prison-plus-mine-content.json', mine_data)

# Possible rewards as displayed. A percentage suffix on powder is deliberately
# NOT interpreted as a drop probability, participation threshold, or item count.
raw_bosses = [
    (1, 'Жнец', 'Врата края', None, 18500, (12, 19), 50, 'Огненный осколок'),
    (2, 'Древесный хранитель', 'Амбар', None, 17300, (11, 18), 50, 'Огненный осколок'),
    (3, 'Самурай', 'Киото', None, 10000, (10, 16), 50, 'Огненный осколок'),
    (4, 'Рыцарь', 'Королевский сад', '00:07:48', 3100, (3, 5), 8, None),
    (5, 'Базальтовый страж', 'Каменоломня', '00:08:52', 350, None, None, None),
    (6, 'Минотавр', 'Подножье горы', '00:13:04', 450, None, None, None),
    (7, 'Король Пиглинов', 'Преисподняя', '00:15:04', 420, None, 3, None),
    (8, 'Скелетон', 'Пирамида', '00:19:58', 2200, (1, 3), 5, None),
    (9, 'Иллюзионист', 'Пустотная крепость', '00:40:04', 6500, (5, 9), 12, None),
    (10, 'Векна', 'Изнанка', '00:40:10', 6400, (7, 12), 25, None),
    (11, 'Посейдон', 'Затопленный маяк', '00:50:32', 3800, (4, 7), 10, None),
    (12, 'Паучья матка', 'Паучье логово', '01:33:43', 7700, (7, 12), 25, None),
    (13, 'Лесной дух', 'Лепреконовая долина', '01:42:55', 8600, (9, 14), None, 'Лунная сталь'),
    (14, 'Грут', 'Ферма', '02:04:47', 15000, (11, 17), None, 'Лунная сталь'),
    (15, 'Моль', 'Снежная длань', '03:51:45', 7900, (8, 13), 35, None),
    (16, 'Вороний рыцарь', 'Замок', '04:08:51', 9000, (9, 15), 35, None),
    (17, 'Король нежити', 'Рынок', '05:25:42', 9500, (10, 15), 35, None),
]
localized_bosses = {}
for r in localization['records']:
    match = re.fullmatch(r'prison\.classic\.boss\.([^.]+)\.name', r['key'])
    if match:
        localized_bosses[r['text'].casefold()] = dict(id=match[1], name=r['text'], sourceKey=r['key'])
bosses = []
for n, name, location, timer, money, stars, powder, special in raw_bosses:
    prior = mine_by_name[location]
    bosses.append(dict(observationId=f'bosses_{n}', evidence=[f'bosses_{n}'], name=name, location=location,
        serverId=None, localizationMatch=localized_bosses[name.casefold()], locationUnlockLevel=prior['unlockLevel'],
        status='spawned' if timer is None else 'countdown',
        displayedRespawn=dict(display=timer or 'Босс возрождён', remainingSeconds=None if timer is None else hhmmss(timer)),
        respawnIntervalSeconds=None, hp=None, damage=None,
        possibleRewards=dict(label='Возможные награды', money=dict(min=0, max=money, currencyDisplay='$'),
            ancientStars=None if stars is None else dict(display=f'x{stars[0]}-{stars[1]}', min=stars[0], max=stars[1]),
            ancientPowder=None if powder is None else dict(display=f'Древний порошок (1-{powder}%)',
                percentQualifier=dict(min=1, max=powder, interpretation=None), dropChance=None, count=None),
            specialItem=None if special is None else dict(displayName=special, count=None, dropChance=None),
            actualDropObserved=False, distributionRule=None)))
not_observed = [v for k, v in localized_bosses.items() if k not in {b['name'].casefold() for b in bosses}]
boss_data = dict(recordedDate='2026-10-19', sourceType='supplied boss menu screenshots',
    sourcesManifest='late-menu-sources.json', sourceIds=[f'bosses_{n}' for n in range(1, 18)],
    menuCountDisplay='17 / 17', entries=bosses, localizationOnlyNotObserved=not_observed,
    caveats=[
        'All 17 entries in this displayed menu were selected; this does not establish every season/realm roster.',
        'Rewards are marked possible, not guaranteed; absent rows mean not shown in this menu, not proof of impossibility.',
        'Powder percentage ranges retain an unknown interpretation; no drop probability was recovered.',
        'Countdowns are remaining-time snapshots; no complete respawn interval was measured.',
        'Flavor descriptions hint at attacks, shields and minions but do not reveal AI implementation or numeric combat stats.',
        'No boss fight, kill, payout or actual drop was observed in this screenshot series.',
    ])
write_json('boss-menu-recovery.json', boss_data)

offers = []


def offer(name, price, category, source, **extra):
    offers.append(dict(name=name, category=category, price=price,
        currencyDisplay='blue store-currency icon', currencyId=None,
        purchasedLabelVisible=price is None, evidence=[f'shop_mines_{n}' for n in source],
        quantity=None, durationSeconds=None, multiplier=None, **extra))


offer('Игровая подписка Prison+', None, 'Верхняя карточка', [1, 2, 3, 4, 5, 6, 7])
offer('Рубины', 1, 'Верхняя карточка', [1, 2, 3, 4, 5])
for name, price in [('Авто-продажа', None), ('Вакцина', 449), ('Перезарядка стойки', 39),
                    ('Мыло', 10), ('Спальный мешок', 10), ('Туалетная бумага', 7)]:
    offer(name, price, 'Способности', [1])
for scope, prices, bundle, sources in [
    ('Локальный', [139, 139, 129], 399, [2]),
    ('Фракционный', [199, 199, 189], 579, [2, 3]),
    ('Глобальный', [249, 249, 239], 729, [3]),
]:
    for resource, price in zip(['блоков', 'денег', 'мобов'], prices):
        source = [2, 3] if scope == 'Глобальный' and resource != 'мобов' else sources
        offer(f'{scope} Бустер {resource}', price, 'Бустеры', source, scopeLabel=scope)
    offer(f'Набор {scope[:-2]}ых Бустеров', bundle, 'Бустеры', sources, scopeLabel=scope)
for name, price in [('Свиток забвения', 129), ('Улучшенный древний ключ', 349), ('Древний ключ', 149),
                    ('Ключ с кличками', 99), ('Ключ от обычного кейса', 10), ('Набор Древних звёзд', 169),
                    ('Древняя звезда', 25), ('Древний порошок', 17), ('Развеиватель', 199)]:
    offer(name, price, 'Ключи и предметы', [4])
offer('Дополнительный слот на Аукционе', 69, 'Аукцион', [5])
offer('Удаление комиссии на Аукционе', None, 'Аукцион', [5])

raw_map = [
    (2, 'Баня', 'бирюзовый', 'верхнее левое здание'),
    (3, 'Задания', 'фиолетовый', 'ниже верхней большой круглой площадки'),
    (4, 'Шахта', 'светло-серый', 'верхняя большая круглая площадка'),
    (5, 'Рынок', 'зелёный', 'верхнее правое здание'),
    (6, 'Спальня', 'синий', 'нижнее левое здание с белой крышей'),
    (7, 'Спавн', 'жёлтый', 'центр, круглая площадь с фонтаном'),
    (8, 'Столовая', 'оранжевый', 'правое продолговатое здание'),
    (9, 'Малая шахта', 'коричневый', 'нижняя малая круглая площадка'),
    (10, 'Тренер', 'красный', 'нижняя площадка справа от малой шахты'),
]
map_entries = [dict(name=name, evidence=[f'map_{n}'], flagColor=color, boardPosition=pos,
    actionDisplay='Телепортироваться', worldCoordinates=None, price=None, accessRequirements=None,
    actualTeleportObserved=False) for n, name, color, pos in raw_map]
subscription = dict(name='Prison+', evidence=['shop_mines_6', 'shop_mines_7'], purchasedLabelVisible=True,
    price=None, durationDisplay='Действует лишь до конца текущего сезона',
    features=[
        dict(name='Настройки Авто-копания блоков', command='/pp'),
        dict(name='Уникальный префикс перед ником'),
        dict(name='Слоты на Аукционе', before=5, after=10),
        dict(name='Комиссия при продаже предметов на Аукционе', beforePercent=5, afterPercent=0),
        dict(name='Изменение игрового времени', command='/pp'),
        dict(name='Подробная информация о голоде и восстановлении здоровья', command='/pp'),
        dict(name='Просмотр времени респавна шахт', command='/pp', botMarkerVisible=True),
        dict(name='Просмотр времени респавна боссов', command='/pp', botMarkerVisible=True),
    ], botReferenceDisplay='t.me/prison_classic_bot', botUsed=False)
store_map = dict(recordedDate='2026-10-19', sourcesManifest='late-menu-sources.json',
    sourceIds=[f'shop_mines_{n}' for n in range(1, 8)] + ['bosses_18'] + [f'map_{n}' for n in range(1, 11)],
    storeOffers=offers, subscription=subscription,
    settings=dict(evidence=['bosses_18'], labels=['Включение ночи', 'Авто-копание', 'AppleSkin'], interactionPerformed=False),
    teleporter=dict(header='Телепортатор', overviewEvidence=['map_1'], entries=map_entries),
    caveats=[
        'Prices are displayed beside a blue currency icon; these observations do not establish rubles, Robux, debit behavior or exchange rates.',
        'Куплено replaces the price on subscription, auto-sell and auction commission removal; null is unknown, not zero/free.',
        'Перезарядка стойки is the literal offer name; it is not a confirmed trainer reset.',
        'Booster duration, multiplier, stacking and bundle quantity were not shown.',
        'Hover tooltips establish nine named teleporter destinations; activation, cost, access and world coordinates were not demonstrated.',
        'Шахта and Малая шахта on the board are not assigned to the two Тюрьма rows without IDs or travel evidence.',
    ])
write_json('store-map-recovery.json', store_map)

ordered_mines = sorted(mines, key=lambda m: (list(mine_by_name).index(m['name']), m['observationId']))
mine_table = '\n'.join(f"| {m['name']}{' (строка '+str(m['duplicateNameOccurrence'])+')' if m['duplicateNameOccurrence'] else ''} | {level_text(m)} | {'; '.join(x['displayName'] for x in m['materials'])} | {evidence(m['evidence'])} |" for m in ordered_mines)
(ROOT / 'MINE-COMPOSITION.md').write_text(f'''# Prison Classic: блоки 26 строк меню шахт

19 октября 2026 года. Из 26 выбранных карточек `/pp` восстановлены списки блоков **25 разных названий шахт**. Счётчик меню — **26 / 26**. Две отдельные строки называются «Тюрьма» и показывают одинаковые пять названий ресурсов. Уровни доступа взяты из ранее разобранного `/mines`, а не вычислены по позиции в списке.

| Локация | Доступ | Блоки, как названы в меню | Снимок |
| --- | --- | --- | --- |
{mine_table}

## Как читать состав

Это список названий, **без процентных долей и цен продажи**. «Незерит», «Розовые листья глицинии», «Эндерняковые кирпичи» и «цемент» сохранены буквально; Minecraft ID по ним не назначены. У Эдема и Рая написано «Гриб», но предпросмотры коричневый и красный. Их нельзя свести к одному точному материалу по одной подписи.

У Тюрьмы старые иконки показывали землю/песок/гравий, а новое меню дополнительно перечисляет Дуб и Арбуз. Старые иконки не были полным списком. Для Подвала пока есть только прежнее визуальное наблюдение; состав Тюрьмы ему не присвоен. У Древа теперь явно подписан **Белый цемент**, у Паучьего логова — **Паутина и Белая шерсть**.

## Время на карточках

На 25 карточках указано `00:00:48`, у Каменоломни — `00:01:48`. Заголовок — «Время до респавна»: это остаток на момент снимка. Из этих кадров нельзя получить полный интервал обновления, а повторяющиеся 48 секунд требуют отдельной проверки работы таймера. Рядом виден необработанный ключ `PRISON.CLASSIC.PRISON_PLUS.GUI.RESPAWN_COOLDOWN`, который местами перекрывается и обрезается.

## Что остаётся неизвестным

Точные уровни открытия трёх ранних шахт, различие двух строк Тюрьмы, ID блоков и шахт, доли ресурсов, цены продажи, размеры, требуемые инструменты и интервалы обновления. «Малая шахта» с карты телепортов пока не сопоставлена второй строке Тюрьмы.

[Уровни доступа и исходные иконки]({(ROOT / 'MINE-RECOVERY.md').as_posix()}) · [Машинная таблица]({(OUT / 'prison-plus-mine-content.json').as_posix()}) · [Источники и SHA-256]({(OUT / 'late-menu-sources.json').as_posix()})
''', encoding='utf-8')


def reward_text(b):
    r = b['possibleRewards']
    parts = [f"0–{r['money']['max']} $"]
    if r['ancientStars']:
        s = r['ancientStars']
        parts.append(f"древние звёзды ×{s['min']}–{s['max']}")
    if r['ancientPowder']:
        parts.append(r['ancientPowder']['display'])
    if r['specialItem']:
        parts.append(r['specialItem']['displayName'])
    return '; '.join(parts)


boss_table = '\n'.join(f"| {b['name']} | {b['location']} | {b['displayedRespawn']['display']} | {reward_text(b)} | {evidence(b['evidence'])} |" for b in bosses)
(ROOT / 'BOSS-MENU-RECOVERY.md').write_text(f'''# Prison Classic: все 17 боссов показанного меню

19 октября 2026 года. Счётчик `/pp` — **17 / 17**; каждый из 17 боссов выбран на отдельном снимке. Восстановлены локация, статус/остаток времени и раздел **«Возможные награды»**. Награды не подтверждены фактическим убийством или получением предметов.

| Босс | Локация | На момент снимка | Возможные награды | Снимок |
| --- | --- | --- | --- | --- |
{boss_table}

## Значение чисел

`00:07:48` у Рыцаря — показанное время **до** появления, а не полный интервал респавна. Три первых босса отмечены «Босс возрождён». Их нельзя считать боссами с нулевым периодом появления.

Диапазоны `(1–8%)`, `(1–50%)` стоят рядом с Древним порошком. Снимки не объясняют, что именно измеряют эти проценты. В JSON они записаны отдельным необъяснённым процентным диапазоном; **шанс выпадения оставлен неизвестным**. Древние звёзды показаны как `×min–max`, деньги — `0–max $`. Правила участия, разделения наград и зависимости от урона не показаны. Отсутствие строки награды означает лишь, что она не отображена здесь.

## Связь с обменниками

Огненный осколок указан у Жнеца, Древесного хранителя и Самурая; Лунная сталь — у Лесного духа и Грута. Ранее снятые NPC показывают рецепты **4 осколка → Вулканический камень** для меча и **4 стали → Лунное лезвие** для топора. Теперь источники этих ресурсов связаны с конкретными боссами. Количество шардов за убийство и вероятность их получения из кадров не следуют. [Рецепты NPC]({(ROOT / 'NPC-MENU-RECOVERY.md').as_posix()}).

## Словарь клиента и текущий список

В локализации есть 20 имён; в показанном меню — 17. В этой серии не наблюдаются **{', '.join(b['name'] for b in not_observed)}**. Это не доказательство их удаления из всех режимов. ID локализации сопоставлены по имени и хранятся отдельно от неизвестных серверных ID.

Описания упоминают защиту Древесного хранителя живыми созданиями, тотем/культистов Лесного духа, шипы Базальтового стража, шторм/волны Посейдона и черепа/гулей/метеоры Короля нежити. Это подсказки к механикам, а не полученный код AI. HP, урон, дальность, фазы и частота приёмов остаются неизвестными.

[Машинная таблица]({(OUT / 'boss-menu-recovery.json').as_posix()}) · [Источники и SHA-256]({(OUT / 'late-menu-sources.json').as_posix()})
''', encoding='utf-8')

store_table = '\n'.join(f"| {o['category']} | {o['name']} | {o['price'] if o['price'] is not None else 'Куплено; цена скрыта'} | {evidence(o['evidence'][:1])} |" for o in offers)
map_table = '\n'.join(f"| {m['name']} | {m['flagColor']} | {m['boardPosition']} | {evidence(m['evidence'])} |" for m in map_entries)
(ROOT / 'STORE-AND-TELEPORTS.md').write_text(f'''# Prison Classic: магазин, подписка, настройки и телепортатор

19 октября 2026 года. Из трёх серий сохранены **31 различное предложение магазина**, 8 пунктов описания подписки, 3 переключателя настроек и 9 подписанных целей на карте телепортатора. Повторяющиеся карточки при прокрутке не посчитаны заново.

## Магазин

Числа стоят возле синего значка валюты магазина. Они не названы рублями или Robux. «Рубины» — название отдельного предложения с ценой 1; курс обмена и количество выдаваемых рубинов этим кадром не установлены. «Куплено» заменяет цену у трёх предложений и не означает нулевую цену.

| Раздел | Предложение | Показанная цена | Снимок |
| --- | --- | ---: | --- |
{store_table}

У бустеров показаны три области действия — локальная, фракционная и глобальная — и три типа: блоки, деньги, мобы. Длительность, множитель, правила сложения и наполнение наборов на этих карточках не раскрыты. «Перезарядка стойки» сохранена буквально; сбросом тренера она не названа.

## Prison+

На снимках подписка уже куплена, стоимость скрыта. Описание указывает:

- Настройки авто-копания в `/pp` и уникальный префикс перед ником.
- Увеличение слотов Аукциона **5 → 10** и комиссии продажи **5% → 0%**.
- Изменение игрового времени и информацию о голоде/восстановлении здоровья через `/pp`.
- Просмотр времени респавна шахт и боссов через `/pp`; отмеченные пункты также описаны как доступные в игровом боте.
- Срок действия: **лишь до конца текущего сезона**, без даты или числа дней.

Источники: {evidence(['shop_mines_6', 'shop_mines_7'])}. Ссылка на бота сохранена как текст описания; обращение к нему не выполнялось.

На отдельном экране настроек видны **«Включение ночи», «Авто-копание», «AppleSkin»**. Это подтверждает наличие переключателей; настройки агентом не менялись. {evidence(['bosses_18'])}.

## Телепортатор в игровом мире

Перед игроком стоит деревянный щит с картой и заголовком «Телепортатор». При наведении на цветной флаг появляется название и действие **«Телепортироваться»**. Ниже — положения на рисунке карты, не мировые координаты.

| Цель | Флаг | Положение на карте | Снимок |
| --- | --- | --- | --- |
{map_table}

Есть две отдельные подписи — **«Шахта» и «Малая шахта»**. Связь со строками «Тюрьма» в `/pp` пока не доказана. Снимки демонстрируют наведение, без подтверждённого перехода: стоимость, условия доступа и точка прибытия неизвестны. Общий вид: {evidence(['map_1'])}.

[Машинные данные]({(OUT / 'store-map-recovery.json').as_posix()}) · [Источники и SHA-256]({(OUT / 'late-menu-sources.json').as_posix()})
''', encoding='utf-8')

# Semantic and evidence-integrity checks. Null fields protect against silently
# converting remaining timers, displayed captions and reward hints into rules.
assert len(mines) == 26 and len({m['name'] for m in mines}) == 25
assert {m['name'] for m in mines} == set(mine_by_name)
assert collections.Counter(m['name'] for m in mines)['Тюрьма'] == 2
assert sum(m['unlockLevel'] is not None for m in mines) == 21
assert len(bosses) == 17 and len({b['name'] for b in bosses}) == 17
assert len(not_observed) == 3 and len(localized_bosses) == 20
assert sum(b['status'] == 'spawned' for b in bosses) == 3
assert all(m['resetIntervalSeconds'] is None for m in mines)
assert all(b['respawnIntervalSeconds'] is None for b in bosses)
assert all(b['possibleRewards']['ancientPowder']['dropChance'] is None for b in bosses if b['possibleRewards']['ancientPowder'])
assert len(offers) == 31 and sum(o['price'] is not None for o in offers) == 28
assert len({o['name'] for o in offers}) == 31
assert len(map_entries) == 9
used_ids = mine_data['sourceIds'] + boss_data['sourceIds'] + store_map['sourceIds']
assert len(used_ids) == len(set(used_ids)) == len(source_by_id) == 61
assert set(used_ids) == set(source_by_id)
for s in manifest['sources']:
    assert hashlib.sha256(Path(s['evidencePath']).read_bytes()).hexdigest() == s['evidenceSha256']
    original = Path('C:/Users/user/AppData/Local/Temp') / s['originalFilename']
    assert hashlib.sha256(original.read_bytes()).hexdigest() == s['originalSha256']
local_links = 0
for name in ['MINE-COMPOSITION.md', 'BOSS-MENU-RECOVERY.md', 'STORE-AND-TELEPORTS.md']:
    report = (ROOT / name).read_text(encoding='utf-8')
    for target in re.findall(r'\]\((C:/[^)\n]+)\)', report):
        assert Path(target).is_file(), target
        local_links += 1
validation = dict(screenshotsProcessed=61, uniqueOriginals=len({s['originalSha256'] for s in manifest['sources']}),
    sourcesAllAssignedOnce=True, originalAndEvidenceHashesMatched=True,
    mineRows=26, distinctMineNames=25, priorMineNamesAllCovered=True, preciseUnlocksJoined=21,
    bossMenuEntries=17, localizationNamesNotObserved=[b['name'] for b in not_observed],
    storeOffers=31, numericPrices=28, purchasedWithUnknownPrice=3, teleporterDestinations=9,
    noResetIntervalsOrDropProbabilitiesInvented=True, localLinksChecked=local_links)
write_json('late-menu-validation.json', validation)
print(json.dumps(validation, ensure_ascii=False, indent=2))
