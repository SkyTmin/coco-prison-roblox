"""Build a content catalog from preserved localization, keeping unknown tables null."""
from pathlib import Path
import collections
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
classic=json.loads((OUT/'classic-content-index.json').read_text(encoding='utf-8'))
other=json.loads((OUT/'other-prison-text-index.json').read_text(encoding='utf-8'))
observed_mines=json.loads((OUT/'mine-menu-recovery.json').read_text(encoding='utf-8'))
observed_pickaxe=json.loads((OUT/'pickaxe-upgrades-recovery.json').read_text(encoding='utf-8'))
observed_other_items=json.loads((OUT/'other-upgrades-recovery.json').read_text(encoding='utf-8'))
observed_npcs=json.loads((OUT/'npc-menu-recovery.json').read_text(encoding='utf-8'))
observed_composition=json.loads((OUT/'prison-plus-mine-content.json').read_text(encoding='utf-8'))
observed_bosses=json.loads((OUT/'boss-menu-recovery.json').read_text(encoding='utf-8'))
observed_store_map=json.loads((OUT/'store-map-recovery.json').read_text(encoding='utf-8'))
late_sources=json.loads((OUT/'late-menu-sources.json').read_text(encoding='utf-8'))
observed_armor_axe=json.loads((OUT/'armor-and-axe-recovery.json').read_text(encoding='utf-8'))
observed_books=json.loads((OUT/'books-system-recovery.json').read_text(encoding='utf-8'))
observed_auction_scenes=json.loads((OUT/'auction-and-scenes-recovery.json').read_text(encoding='utf-8'))
missed_sources=json.loads((OUT/'missed-menu-sources.json').read_text(encoding='utf-8'))
book_sources=json.loads((OUT/'book-case-sources.json').read_text(encoding='utf-8'))
all_screenshot_sources=(observed_mines['sources']+observed_pickaxe['sources']+
    observed_other_items['sources']+observed_npcs['sources']+late_sources['sources']+
    missed_sources['sources']+book_sources['sources'])
total_item_transitions=(len(observed_pickaxe['transitions'])+
    len(observed_other_items['sword']['transitions'])+len(observed_other_items['shovel']['transitions'])+
    sum(len(g['transitions']) for g in observed_armor_axe['items'].values()))
rows={r['key']:r for r in classic['records']+other['records']}
proof=[]
def value(key):return rows[key]['text']
def link(key,label=None):
    scope=classic if key.startswith('prison.classic.') else other
    path=Path(scope['source']).as_posix()
    return f"[{label or key}]({path}:{rows[key]['sourceLine']})"
def ev(fid,claim,*keys,contains=(),scope='classic_localization'):
    selected=[rows[k] for k in keys]
    combined='\n'.join(r['text'] for r in selected)
    for token in contains:assert token in combined,(fid,token)
    proof.append(dict(id=fid,claim=claim,status='text_not_server_execution',scope=scope,
        sources=[dict(source=classic['source'] if r['key'].startswith('prison.classic.') else other['source'],
                      sha256=classic['sourceSha256'] if r['key'].startswith('prison.classic.') else other['sourceSha256'],
                      key=r['key'],line=r['sourceLine'],raw=r['raw']) for r in selected]))

mines=[]
for r in classic['records']:
    m=re.fullmatch(r'prison\.classic\.mine\.list\.(mine_(\d+))\.display_name',r['key'])
    if m:
        mines.append(dict(id=m[1],ordinalInLocalization=int(m[2]),name=r['text'],
            sourceKey=r['key'],description=value(r['key'].replace('.display_name','.lore')),
            unlockLevel=None,composition=None,blockPrices=None,resetSeconds=None,
            limitation='Localization ordinal is not an unlock level; active-season availability unverified.'))
mines.sort(key=lambda r:r['ordinalInLocalization'])
assert len(mines)==14
locations=[]
for r in classic['records']:
    m=re.fullmatch(r'prison\.classic\.location\.list\.([^.]+)',r['key'])
    if m and not m[1].endswith('_description'):
        locations.append(dict(id=m[1],name=r['text'],sourceKey=r['key'],
            description=value(r['key']+'_description'),unlockLevel=None))
assert len(locations)==20
categories=[dict(id=r['key'].removeprefix('prison.classic.item.type.'),name=r['text'],sourceKey=r['key'],
    maxLevel=None,upgradeStages=None,limitation='Category label, not recovered tier/price configuration.')
    for r in classic['records'] if r['key'].startswith('prison.classic.item.type.')]
assert len(categories)==12
special=[dict(id=r['key'].removeprefix('prison.classic.item.special.'),name=r['text'],sourceKey=r['key'])
         for r in classic['records'] if r['key'].startswith('prison.classic.item.special.')]
bosses=[]
for r in classic['records']:
    m=re.fullmatch(r'prison\.classic\.boss\.([^.]+)\.name',r['key'])
    if m:
        prefix='prison.classic.boss.'+m[1]
        bosses.append(dict(id=m[1],name=r['text'],sourceKey=r['key'],
            description=rows.get(prefix+'.description',{}).get('text'),
            spawnText=rows.get(prefix+'.notify.spawn',{}).get('text'),
            hp=None,damage=None,respawnSeconds=None,lootTable=None))
assert len(bosses)==20
milestones=[]
for level in (10,15,20):
    key=f'prison.gear.max-level{level}'
    milestones.append(dict(level=level,title=value(key+'.name'),description=value(key+'.description'),
        sourceKey=key+'.description',scope='unqualified_prison_achievement',
        limitation='Achievement threshold; not a per-item maximum or tier table.'))
    ev(f'GEAR{level}',f'Текст достижения за предмет {level}-го уровня.',key+'.name',key+'.description',
       contains=(str(level),),scope='unqualified_prison_achievement')

ev('ITEM-REQ','Для улучшения проверяются требования и уровень Оружейника.',
   'prison.classic.item.upgrade.error.requirements','prison.classic.item.upgrade.error.armored_too_low',
   'prison.classic.item.upgrade.gui.kills','prison.classic.item.upgrade.gui.rats',contains=('%d','Оружейника','Крысы'))
ev('ITEM-MAX','У предмета есть максимальный допустимый уровень, но число не задано.',
   'prison.classic.item.upgrade.error.full')
ev('ITEM-EFFECT','Совет связывает upgrade с повышением уровня зачарований.', 'prison.classic.advice.16')
ev('FIRE','4 огненных осколка дают Вулканический камень; описан Заговор огня II на мече максимального уровня.',
   'prison.classic.shards.fire.shard.lore','prison.classic.shards.fire.stone.lore',contains=('4','II','максимальный'))
ev('MOON','4 лунные стали дают лезвие для топора максимального уровня с Эффективностью IV.',
   'prison.classic.shards.blade.steel.lore','prison.classic.shards.blade.item.lore',contains=('4','IV','максимального'))
ev('POTION-3','Некоторое действие зельеварения требует третьего уровня; описаны взрывные зелья и модификаторы.',
   'prison.classic.gui.skills.potion.error.third_level_required','prison.classic.gui.skills.list.potion.hover.3',contains=('третьего','Взрывные'))
ev('POTION-DURATION','Улучшение длительности эффектов описано множителем 1.7.',
   'prison.classic.gui.skills.potion.upgrade_tooltip',contains=('1.7',))
ev('POTION-MODIFIER','Один модификатор расходуется на эффект или улучшение зелья.',
   'prison.classic.gui.skills.potion.modifications_tooltip')
ev('MINE-ACCESS','Есть уровень доступа, особые условия локаций и предупреждение PvP.',
   'prison.classic.location.list.non_access.level','prison.classic.location.list.non_access.basement',
   'prison.classic.location.list.non_access.warzone','prison.classic.location.pvp_tooltip',contains=('%d',))

ev('BASEMENT-5','В отдельном сообщении Подвал требует пятый уровень и активированный доступ.',
   'prison.classic.basement.no_access',contains=('5-й','Доступ в подвал'))
ev('GANG-MINE-PASS','Описание пропуска обещает 10 минут, уровень шахты подставляется.',
   'prison.classic.gang.mine.pass.lore',contains=('10','%s'))
ev('GANG-MINE-DEALER','Подсказка Барыги обещает обмен 64 металлов, 30 минут и зависимость цены от уровня банды и качества металлов.',
   'prison.classic.dealer.screen.info_tooltip',contains=('64','30','среднего'))
ev('CARRIER-PASS','Пропуска открывают банде окно входа в карьер на одну минуту.',
   *[f'prison.classic.carrier.pass.{t}.lore' for t in ('stone','titan','diamond','synthetic')],contains=('1 минуту',))
ev('CARRIER-MEMBERS','Указан минимум три участника банды для карьеров.',
   'prison.classic.carrier.error.min_members',contains=('3',))
ev('CARRIER-FUEL','Буру нужны топливные бочки.', 'prison.classic.carrier.screen.fuel_hint')
ev('PLAYER-LEVEL','Уровень игрока связан с блоками/балансом, открытием локаций, здоровьем, силой и очками навыков.',
   'prison.classic.level.gui.blocks','prison.classic.level.gui.balance','prison.classic.level.gui.new_location',
   'prison.classic.level.upgrade.health_upgraded_notify','prison.classic.level.upgrade.strength_upgraded_notify',
   'prison.classic.level.upgrade.skill_point_notify')
ev('CELL','Камера описана с восьмого уровня; голодная шестёрка сбегает.',
   'prison.classic.cell.melon.lore',contains=('8-го','сбегает'))
ev('FACTION','Вступление во фракцию описано с пятого уровня.',
   'prison.classic.fraction.error.level',contains=('пятый',))
ev('BLACKMARKET','Чёрный рынок описан с двадцатого уровня.',
   'prison.classic.blackmarket.error.no_level',contains=('20',))
ev('TRAINER','Три направления тренера: сила, ловкость и нужды; требования включают деньги, зомби, мышей, убийства.',
   *[f'prison.classic.trainer.upgrade.{t}.description' for t in ('strength','agility','needs')],
   *[f'prison.classic.trainer.requirement.{t}' for t in ('money','zombies','bats','kills')])
ev('JOBS','Профессии отдельно получают опыт за кирку, лопату и убийства трёх типов мобов.',
   *[f'prison.classic.job.type.{t}.description' for t in ('pickaxe_blocks','shovel_blocks','mobs')])
ev('POWDER','В донатном описании порошка указаны 10% и добавление процентов шанса.',
   'prison.classic.donate.list.powder.description',contains=('10%',))
ev('GANG-PERKS','Предметный дополнительный блок и дополнительная статистика описаны раздельно.',
   'prison.classic.gang.upgrades.additional_blocks.item.lore','prison.classic.gang.upgrades.additional_blocks.stats.lore')
ev('KARATEL','Текст Карателя не раскрывает ясного отличия от Выносливости; эффект не реконструирован.',
   'prison.classic.gang.upgrades.punisher.lore','prison.classic.gang.upgrades.endurance.lore')

conflicts=[dict(id='gang_mine_duration',sources=['GANG-MINE-PASS','GANG-MINE-DEALER'],values=[10,30],unit='minutes',resolution=None),
           dict(id='achievement_scope',sources=['unqualified prison.* achievements'],
                issue='level50 and all-11-bosses texts cannot establish current Classic cap or roster.',resolution=None)]
data=dict(created='2026-10-20',sourceType='client localization and supplied game menu screenshots; not server source/configuration',
          mines=mines,locations=locations,itemCategories=categories,specialItems=special,bosses=bosses,
          observedMineMenu=observed_mines,observedPickaxeUpgrades=observed_pickaxe,
          observedSwordAndShovel=observed_other_items,observedNpcMenus=observed_npcs,
          observedPrisonPlusMineComposition=observed_composition,observedBossMenu=observed_bosses,
          observedStoreAndTeleporter=observed_store_map,
          observedArmorAndAxe=observed_armor_axe,observedBooks=observed_books,
          observedAuctionAndScenes=observed_auction_scenes,
          screenshotCoverage=dict(supplied=len(all_screenshot_sources),
              uniqueOriginals=len({s['originalSha256'] for s in all_screenshot_sources})),
          publishedCareerAccess=dict(date='2026-05-08',
              url='https://forum.cristalix.gg/threads/306667/',
              levels={'Каменный':16,'Титановый':18,'Алмазный':22,'Синтетический':26},
              status='Dated official announcement; current mine-menu screenshot only confirms entry Карьеры at 16.'),
          itemAchievementMilestones=milestones,conflicts=conflicts,findings=proof,
          unknowns=['Exact unlock levels of 3 already accessible mines; block IDs, weights, prices, reset intervals and dimensions',
                    'Other item tables and absolute maximums; observed armor/sword through 15 and pickaxe/shovel/axe through 16',
                    'Book drop probabilities, per-level proc stats and verified application/combination behavior',
                    'Boss combat stats, reward probabilities/distribution and full respawn intervals',
                    'Current server probabilities and content activation','Faction-specific numeric bonuses'],
          sources=[dict(path=classic['source'],sha256=classic['sourceSha256'],entries=classic['entries']),
                   dict(path=other['source'],sha256=other['sourceSha256'],selectedEntries=other['entries'])])
(OUT/'classic-content-data.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

mine_table='\n'.join(f"| `{r['id']}` | {r['name']} |" for r in mines)
location_table='\n'.join(f"| `{r['id']}` | {r['name']} |" for r in locations)
observed_ranges={'pickaxe':'1 → 16','shovel':'1 → 16','axe':'1 → 16','sword':'1 → 15',
    'helmet':'1 → 15','chestplate':'1 → 15','leggings':'1 → 15','boots':'1 → 15'}
category_table='\n'.join(f"| `{r['id']}` | {r['name']} | {observed_ranges.get(r['id'],'Переходы не получены')} |" for r in categories)
milestone_table='\n'.join(f"| {r['level']} | {r['title']} | {link(r['sourceKey'],'Текст достижения')} |" for r in milestones)
boss_table='\n'.join(f"| `{r['id']}` | {r['name']} |" for r in bosses)
family_table='\n'.join(f'| `{k}` | {v} |' for k,v in classic['families'].items())
observed_mine_table='\n'.join(
    f"| {r['name']} | {r['unlockLevel'] if r['unlockLevel'] is not None else ('Стартовая' if r['startingLocationLabel'] else 'Уже открыта на 8; точный порог скрыт')} | {r['menuTab']} |"
    for r in observed_mines['mineLocations'])
report=f'''# Prison Classic: шахты, уровни предметов и остальной контент

20 октября 2026 года. Каталог составлен из локализации установленного клиента, ресурспака, датированных публикаций и присланных снимков игрового меню. Факты из снимков выделены отдельно от словаря названий. Серверная конфигурация и реализация расчётов не получены.

**В сводном реестре {len(all_screenshot_sources)} игровых снимков ({len({s['originalSha256'] for s in all_screenshot_sources})} уникальных оригиналов).** Восстановлены 21 точный порог шахт, блоки 26 строк / 25 названий, 17 боссов с локациями и возможными наградами, **{total_item_transitions} переходов предметов**, 31 предложение магазина, 9 целей телепортатора, **31 наблюдаемое древнее зачарование** и 35 кадров конкретных книг на Аукционе.

**Исправление полноты:** прежние 127 кадров были неполным реестром; проверка их хешей не означала, что просмотрены все вложения. Повторный просмотр добавил 128 ранее пропущенных игровых кадров (броня, топор, Аукцион, добыча, фракции) и новую серию 34 кадров Древнего кейса. Переходы теперь покрывают кирку/лопату/топор 1 → 16, меч и четыре части брони 1 → 15. Не получены цены/доли блоков, полные интервалы обновления, параметры боёв и вероятности выпадения книг. Вариант под-сервера Classic на снимках не установлен.

## 1. Какие шахты и локации найдены

### Текущее наблюдаемое меню — основной список для восстановления

| Локация | Уровень доступа | Вкладка |
| --- | --- | --- |
{observed_mine_table}

Всего на присланных экранах двух вкладок видны 25 разных локаций; это не заявление о полном количестве шахт на сервере. **Рай требует 49-й уровень** — февральское сообщение о пределе 37 уже не описывает это меню. Максимальный уровень персонажа из этого не следует.

Подробности, отметки PvP, блоки выбранных локаций и ссылки на каждый снимок: [MINE-RECOVERY.md](C:/Users/user/Documents/roblox-prison-research/client-audit/MINE-RECOVERY.md). Уровни ранних открытых шахт не заполнены последовательностью 3/5/7 без доказательств.

### Состав шахт из нового меню `/pp`

На 26 отдельных выбранных карточках прочитаны списки блоков для всех 25 названий из двух прежних вкладок. «Тюрьма» отображается двумя строками с одинаковыми пятью ресурсами; серверные ID не показаны. Древо — **Белый цемент**, Паучье логово — **Паутина / Белая шерсть**, Киото — **Розовая шерсть / Морской фонарь**, Лепреконовая долина — **пять цветов цемента**. Полная таблица с привязанными уровнями доступа: [MINE-COMPOSITION.md](C:/Users/user/Documents/roblox-prison-research/client-audit/MINE-COMPOSITION.md).

Сохранены буквальные подписи «Незерит», «Эндерняковые кирпичи», «Розовые листья глицинии»; ванильные ID по ним не угаданы. В Эдеме и Раю одинаковая подпись «Гриб», но разные предпросмотры. Таймер `00:00:48` повторяется на 25 карточках, у Каменоломни `00:01:48`: это показанный остаток, а не установленный интервал обновления.

### Словарь mine_1…mine_14 — не действующая лестница уровней

| ID записи | Название |
| --- | --- |
{mine_table}

Номер в `mine_14` — часть идентификатора локализации, **не доказательство доступа с 14-го уровня**. У этих записей есть художественные описания, но нет конкретных уровней открытия, процентного состава блоков или цены продажи. Например, {link('prison.classic.mine.list.mine_1.display_name','Лесопилка')} и {link('prison.classic.mine.list.mine_14.display_name','Храм')}.

Королевские владения в описании упоминают три небольшие шахты. Поэтому даже количество таких записей не равно количеству отдельных объёмов добычи.

### Отдельный список location.list

| ID записи | Название |
| --- | --- |
{location_table}

Второй список содержит 20 именованных локаций, включая социальные зоны и базы. Это **не ещё 20 независимых шахт**: названия частично совпадают с первым списком. В нём есть, например, Королевский сад, Паучье логово, Пустотная крепость и Врата края. Отождествление каждой записи двух списков и актуальность каждой версии не установлены.

Дополнительно в текстах появления/описания боссов упомянуты **Киото** и **Лепреконова долина**. Снимки устанавливают пороги Киото **29** и карточки «Лепреконовая долина» **23**. Новая серия `/pp` добавляет списки блоков обеих локаций; разные формы названия долины сохранены по источникам.

### Правила доступа

Есть шаблон «доступно с %d-го уровня»; число не записано в шаблоне. Но отдельное сообщение {link('prison.classic.basement.no_access','Подвала')} прямо указывает **5-й уровень и доступ в Подвал**. Дворы требуют фракцию и уровень; Гетто — банду и открытие этой локации. На снимке прочих локаций Нефтезавод требует **12**, а вход «Карьеры» — **16**. На некоторых шахтах предусмотрено PvP и выпадение части вещей при смерти. Источник: {link('prison.classic.location.list.non_access.level','условия локаций')}.

Prison+ содержит интерфейс времени восстановления шахт, состава блоков, телепорта и доступа. В локализации список подставляется отдельно; новые снимки позволяют прочитать конкретные названия блоков. Полные интервалы восстановления не измерены.

### Карьеры и шахта банды — отдельные системы

- Четыре типа карьеров: Каменный, Титанический, Алмазный, Синтетический. В названии титанового пропуска написано «Титанитовый»; это различие исходных текстов сохранено.
- Пропуск описывает **окно входа банды на одну минуту**, а не установленную длительность добычи.
- Для карьеров указан минимум **3 участника** банды. Бур требует топливные бочки, имеет тип и оставшееся время работы.
- Для шахты банды есть пропуск, качество металлов и подставляемый уровень шахты. Барыга описывает обмен **64 металлов**; цена блока зависит от среднего уровня банды и качества металлов.
- **Есть противоречие по длительности:** {link('prison.classic.gang.mine.pass.lore','пропуск')} обещает **10 минут**, а {link('prison.classic.dealer.screen.info_tooltip','экран Барыги')} — **30 минут**. Пока не установлено, какой текст соответствует текущему поведению.

В [официальном обновлении от 8 мая 2026](https://forum.cristalix.gg/threads/306667/) пороги четырёх карьеров указаны как **16 / 18 / 22 / 26**: Каменный, Титановый, Алмазный, Синтетический. Там же описаны нефтяные бочки с Нефтезавода для бура, обмен добытых материалов на пропуск, постоянный комбат в карьерах и выход через специальные выходы. Новость задаёт шахте банды **10 минут** и минимум трёх участников онлайн. Это дополнительное датированное свидетельство в пользу 10 минут; оно не проверяет поведение текущего сезона и не устраняет старую строку про 30 минут.

### Что дают датированные внешние источники

В старом гайде от апреля 2018 года каменная шахта открывается на уровне 3, огненная — 7, песчаная — 9. Это исторические сведения, не таблица уровней нового Classic. [Гайд Prison, 2018](https://forum.cristalix.gg/threads/3961/).

В новости от 13 февраля 2026 года сообщалось о новых шахтах и максимальном уровне 37. Там же описаны профессии, помощники камеры и `/wiki`. Это состояние объявленного обновления, не доказательство неизменности лимита после следующих обновлений. [Новость Classic, февраль 2026](https://forum.cristalix.gg/threads/303993/).

Таблицы цен из гайдов **Prison Evo** и **OldSchool** не подставлены в Classic: это разные варианты режима.

## 2. Уровни и улучшения предметов

### Есть отдельные уровни предметов

Локализация показывает собственный уровень предмета, кнопку `/upgrade`, цену, требования и ошибку максимального уровня. Среди требований есть деньги, убийства, крысы и навык Оружейника; конкретные числа подставляются. Совет отдельно говорит, что улучшение повышает уровни зачарований. Источники: {link('prison.classic.item.upgrade.error.armored_too_low','проверка Оружейника')}, {link('prison.classic.item.tools.lore','уровень предмета')}, {link('prison.classic.advice.16','эффект upgrade')}.

Это не одно и то же, что уровень игрока, уровень профессии или уровень древнего зачарования.

| Категория | Название | Показанные переходы с ценами/требованиями |
| --- | --- | --- |
{category_table}

Таблица объединяет категории локализации с диапазонами наблюдаемых переходов; абсолютные пределы сервера не установлены. По снимкам восстановлены **{total_item_transitions} переходов**: [кирка](C:/Users/user/Documents/roblox-prison-research/client-audit/PICKAXE-UPGRADES.md), [меч и лопата](C:/Users/user/Documents/roblox-prison-research/client-audit/SWORD-AND-SHOVEL-UPGRADES.md), [четыре части брони и топор](C:/Users/user/Documents/roblox-prison-research/client-audit/ARMOR-AND-AXE-UPGRADES.md). У каждой части брони поздние переходы требуют Оружейника **3 / 5**; цена и крысы различаются между частями. Алмазная броня заканчивает показанную последовательность Защитой **II**, топор — Эффективностью **III**. Конечные повторные экраны не посчитаны дополнительными улучшениями.

«Особые кирки» — подкатегория, не дополнительный тип обычного инструмента. По названиям найдены редкие деревянная, каменная, железная, алмазная кирки и Лунный топор. Наличие четырёх названий редких кирок не устанавливает их характеристики или последовательность получения.

### Числа 10, 15 и 20 действительно присутствуют

В общем пространстве достижений `prison.gear.*` найдены такие пороги:

| Уровень предмета | Название достижения | Источник |
| --- | --- | --- |
{milestone_table}

Это **пороги достижений**, а не восстановленная таблица всех стадий кирки. Текст 20-го уровня не доказывает, что каждый предмет улучшается до 20, что 20 — текущий общий максимум, или что достижение активно в выбранном сезоне. У этих записей отсутствует префикс `classic`; принадлежность всему актуальному Classic нельзя установить только из пространства имён.

### Конкретные поздние улучшения

| Вход | Результат по описанию | Условие |
| --- | --- | --- |
| 4 огненных осколка | Вулканический камень; Заговор огня II на мече | Меч максимального уровня |
| 4 лунные стали | Лунное лезвие; Лунный топор с Эффективностью IV | Топор максимального уровня |

Источники: {link('prison.classic.shards.fire.shard.lore','огненные осколки')}, {link('prison.classic.shards.fire.stone.lore','камень')}, {link('prison.classic.shards.blade.steel.lore','лунная сталь')}, {link('prison.classic.shards.blade.item.lore','лезвие')}. Номера II и IV — уровни эффектов Minecraft, а не номер стадии самого предмета.

Ресурспак подтверждает отдельную текстуру Лунного топора на `diamond_axe` с `nbt.weapons=moon_axe`. Пять текстур лопат с `nbt.weapons=mythrile` показывают варианты внешнего вида, а не пять восстановленных уровней прокачки.

### Древние зачарования — ещё один слой

В Classic 38 именованных древних зачарований. Их описания вынесены в { '[предыдущий каталог](C:/Users/user/Documents/roblox-prison-research/client-audit/CLASSIC-CLIENT-FINDINGS.md)' }. Для них описаны уровень книги, шанс наложения, разрушение книги при неудаче, повышение шанса порошком, снятие развеивателем и объединение книг одного типа в кузнице банды.

Новая [полная таблица наблюдений книг](C:/Users/user/Documents/roblox-prison-research/client-audit/BOOKS-SYSTEM.md) содержит **31 название**: 13 обычных, 10 редких, 8 легендарных, уровни и совместимые предметы. На Аукционе прочитано 35 кадров отдельных экземпляров: Берсерк III с шансами наложения 31% и 99%, Пластолом II с 100% и 28%. Уровень, шанс наложения и вероятность срабатывания эффекта разделены.

Ключи доступны за **10 / 60 звёзд** у обменника и по показанным ценам магазина **149 / 349**. Улучшенный ключ по подсказке гарантирует максимальный уровень книги, но не 100% наложение. Показаны порошок с эффективностью **2%**, снятие без возврата книги, запрет лечения Проклятием, особый учёт блоков Пластолома и бонусы звёзд/денег за урон боссу. [Аукцион, добыча и фракции](C:/Users/user/Documents/roblox-prison-research/client-audit/AUCTION-AND-FACTION-RECOVERY.md) сохранены отдельно; цены игроков не выданы за постоянные цены NPC.

В донатном описании порошка указана эффективность **10%**, причём каждый процент повышает шанс наложения на дополнительный процент. Это описание конкретного порошка; ограничения итогового шанса и все варианты качества порошков не восстановлены. {link('prison.classic.donate.list.powder.description','Источник')}.

## 3. Отдельные ветки развития

| Ветка | Что развивается | Что известно о требованиях/наградах |
| --- | --- | --- |
| Уровень игрока | Общий доступ, сила, HP, очки навыков | Есть требования блоков и баланса, открытие новых локаций; полной лестницы чисел нет |
| Уровень предмета | Инструменты, оружие, броня | Цена, предметные требования и Оружейник; все стадии не получены |
| Древнее зачарование | Отдельный эффект на предмете | Книги, шанс, порошок, развеиватель, кузница |
| Дерево навыков | Оружейник, Зельевар, Счастливчик, Охотник | Очки навыков, ограничения, возможность сброса Свитком забвения |
| Тренер | Сила, ловкость, сопротивление нуждам | Деньги, зомби, летучие мыши, убийства; числовые требования подставляются |
| Профессия | Каменщик, Геодезист, Мастер клинка | Опыт соответственно за блоки киркой, лопатой и убийства крыс/зомби/мышей |
| Камера/помощники | Уровень камеры и развитие помощников | Вход с уровня игрока 8 по тексту, кормление и переработка |
| Банда | Вместимость, инфраструктура и перки | Казна, склад, участники, Гетто, кузница, библиотека и пассивные бонусы |

Оружейник открывает более высокие уровни брони. Счастливчик повышает вероятность ключа при копании. Охотник описан через шанс засчитать убитого моба как двух в статистике: это не обязательно появление второго реального моба.

У зельеварения описаны доступ с первого уровня, ограничение третьего уровня, взрывные зелья, заряд стойки и количество модификаторов. Один модификатор соответствует эффекту или одному улучшению зелья. Улучшение увеличивает длительность добавленных эффектов **в 1,7 раза**. Найдены восемь эффектов: огнестойкость, регенерация, скорость, сила, слабость, слепота, голод, замедление. Источники: {link('prison.classic.gui.skills.list.potion.hover.3','описание этапа')}, {link('prison.classic.gui.skills.potion.upgrade_tooltip','множитель')}, {link('prison.classic.gui.skills.potion.modifications_tooltip','модификаторы')}.

Общие достижения также упоминают камеру уровней 3/6 и работу уровней 10/25/51. Их нельзя выдавать за текущие максимумы этих систем.

## 4. Остальной контент

| Система | Найденные элементы | Неустановленная часть |
| --- | --- | --- |
| Быт и болезни | Сон, душ, туалет; расходники, вакцина, тренер и Чистюля | Таймеры, точные штрафы, взаимодействие всех иммунитетов |
| Фракции | Славяне, Афро, Азиаты, Латиносы; вход с 5 уровня; захват точек копанием у маяка | Числовые бонусы каждой стороны и все правила перехода |
| Точки фракций | Блоки, деньги, мобы, спешка | Проценты, срок удержания, распределение |
| Банды | Склад, казна, участники, Гетто, кузница, библиотека | Цены и максимальные ранги улучшений |
| Перки банды | Фарт, Конверсия, Выносливость, Охотник, Каратель | Числа; текст Карателя неоднозначен и похож на описание нужд |
| Квесты банды | Ежедневные, еженедельные, цели; блоки, боссы, урон, продажа, PvP, мобы, лечение | Конкретные задания, количества, награды |
| Камера | Помощники, кормушка, яблоки/плоть/арбузы; сито с пылью/ключом/звездой | Таблицы переработки, расход еды, развитие каждого помощника |
| Боссы | 20 имён в локализации; 17 в показанном меню с локациями и возможными наградами | HP, урон, фазы, полные интервалы, вероятности и разделение наград |
| Кейсы | Обычный, древний, клички; улучшенный древний ключ; кейсы артефактов | Содержимое по вероятностям, гарантии, все источники ключей |
| Артефакты | Обычные/редкие/эпические, 9 фрагментов, переработка повторок | Каталог картинок, шанс фрагмента, порог повторок |
| Торговля | Надзиратель/сборщики, аукцион, чеки, переводы, подарки, автопродажа | Актуальные цены и все комиссии/ограничения по каждому действию |
| Чёрный рынок | Остаток товара и доступ с 20 уровня | Ассортимент, обновление, цены |
| Сезонный прогресс | Профессии, локальные/фракционные/глобальные бустеры, battle pass | Награды и точные множители текущего сезона |
| Ежедневные награды | Денежные чеки, локальные бустеры, подписи наград | Полный календарь и серверные сроки |
| Обучение | Две крысы, 15 блоков, новая лопата | Активность текущего сценария и выдаваемые предметы |
| Достижения | Добыча, деньги, PvP, боссы, предметы, камера, работы, время, артефакты | Активность общего набора и серверные награды |
| Прочие игровые системы | Столовая, хранилище, клички, статистика, настройки, события | Конкретное наполнение части экранов |

Показатели общего набора достижений включают добычу до 7 млн блоков, PvP до 2000 убийств, крысы/зомби до 10 000, пребывание до 1000 часов и получение ежедневной награды до 100 раз. Это **цели достижений**, не требования открытия соответствующих систем.

### Наблюдаемые боссы и словарь Classic

Меню `/pp` показывает **17 / 17**, и все 17 карточек прочитаны. [Полная таблица локаций, наград и снимков](C:/Users/user/Documents/roblox-prison-research/client-audit/BOSS-MENU-RECOVERY.md). Например, у Жнеца во Вратах края указаны 0–18 500 $, древние звёзды ×12–19, порошок `(1–50%)` и Огненный осколок. Это возможные награды; смысл процентов порошка не установлен, шанс выпадения не присвоен. Показанные таймеры не объявлены периодами возрождения.

Огненный осколок перечислен у Жнеца, Древесного хранителя и Самурая; Лунная сталь — у Лесного духа и Грута. Эти источники связаны с ранее снятыми рецептами NPC по 4 шарда. В локализации дополнительно есть **Зомбарь, Сплинтер и Воид**, которых в этой серии меню нет. Ниже — именно словарь 20 имён, а не ещё один действующий список.

| ID текста | Имя |
| --- | --- |
{boss_table}

У восьми более подробных описаний есть указания на приёмы или окружение: базальтовые шипы, шторм/волны, тотем и культисты, бой самурая вместе с призраком, защита хранителя живыми созданиями, черепа/гули/метеоры Короля нежити. Это описания, не декомпилированная реализация боевого поведения. Все исходные описания сохранены в JSON каталога.

### Магазин, подписка и перемещение

[Магазин и карта телепортатора](C:/Users/user/Documents/roblox-prison-research/client-audit/STORE-AND-TELEPORTS.md): 31 различное предложение, 28 числовых цен и 3 цены, скрытые надписью «Куплено». Синий значок валюты не объявлен рублями/Robux. Описание Prison+ подтверждает 5 → 10 слотов Аукциона, 5% → 0% комиссии и срок до конца текущего сезона.

На деревянной карте в игровом мире прочитаны 9 целей: Баня, Задания, Шахта, Рынок, Спальня, Спавн, Столовая, Малая шахта, Тренер. Наведение показывает «Телепортироваться», но переход, цена и условия доступа не наблюдались. Связь «Малой шахты» со второй строкой Тюрьмы пока неизвестна.

### Ограничения и несовпадения

1. Два списка локаций частично перекрываются и не устанавливают взаимно однозначное соответствие.
2. 10/30 минут шахты банды расходятся в двух клиентских текстах.
3. Достижение «все 11 боссов» в общем наборе не совпадает по объёму с 20 именами Classic.
4. Общие достижения уровней игрока 40/50 не устанавливают максимум персонажа. Новые снимки прямо показывают шахту с порогом **49**; февральская новость о 37 историческая.
5. «Каратель» имеет неясное описание; новый эффект по названию не придуман.
6. Названия и тексты могут оставаться после изменения сезона, а `%d/%s/%a` — это ещё не значения подстановок.

## 5. Где искались полные таблицы

Проверены не только классы. Среди 36 копий клиентских архивов просмотрено **18 275 ресурсов вне .class**, из них по заданным ключам просканировано **9611 текстовых ресурсов UTF-8**. Единственное совпадение — ванильное слово Armorer в переводе Minecraft. Один `natural.properties` не был UTF-8 и пропущен. Это ограниченный поиск по текстовым форматам, не доказательство отсутствия любых бинарных/сгенерированных таблиц. [Результат](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/client-resource-scan.json).

Ресурспак имеет 354 записи и 38 `.properties`-правил выбора текстур. В них не найдена таблица всех уровней предметов с ценами. [Индекс](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/resourcepack-index.json).

В публичном клиентском моде 2021 года `prison:addinfos` принимает current/required и список изменений уровня от сервера. Это образец передачи данных интерфейсу, не полная серверная таблица и не доказательство текущего протокола Classic.

## 6. Что нужно получить для точной таблицы контента

Для шахт ещё нужны ID, точные уровни трёх ранних локаций, доли блоков, цены, инструменты, размеры и полные интервалы обновления. У 17 боссов теперь установлены локации и возможные награды, но не HP, урон, AI, вероятности и правила разделения дропа. Для остальных категорий предметов нужны стадии, цены, требования, характеристики и ограничения Оружейника.

Присланные меню уже позволили заполнить 21 порог шахт, списки блоков 25 названий, 17 боссов, {total_item_transitions} переходов предметов и 31 тип книги. Остальные значения следует брать из игровых меню, фактических измерений либо опубликованных конфигураций соответствующего сервера. Неизвестные значения в JSON оставлены `null`.

## Проверяемые материалы

- [Названия, неизвестные поля и {len(proof)} закреплённых выводов](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/classic-content-data.json).
- [Все 1837 записей Classic с ключами и номерами строк](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/classic-content-index.json).
- [Остальные 663 записи Prison](C:/Users/user/Documents/roblox-prison-research/client-audit/content-analysis/other-prison-text-index.json): 169 общих текстов достижений и 494 OldSchool. Общие достижения не объявлены автоматически активным набором Classic.
- [Разбор восстановленной логики](C:/Users/user/Documents/roblox-prison-research/client-audit/CLIENT-LOGIC-AUDIT.md).

## Указатель всех семейств Classic

Это указатель ключей, а не число разных механик. `history`, `staff`, `database`, `dupe` и другие служебные группы не выданы за дополнительные занятия обычного игрока.

| Семейство ключей | Строк |
| --- | ---: |
{family_table}
'''
(ROOT/'CLASSIC-CONTENT-CATALOG.md').write_text(report,encoding='utf-8')

# Validate preserved hashes, every quoted key, generated counts and local links.
for s in (classic,other):
    assert hashlib.sha256(Path(s['source']).read_bytes()).hexdigest()==s['sourceSha256']
for s in all_screenshot_sources:
    assert hashlib.sha256(Path(s['evidencePath']).read_bytes()).hexdigest()==s['evidenceSha256']
assert len(all_screenshot_sources)==289
assert len({s['originalSha256'] for s in all_screenshot_sources})==287
assert total_item_transitions==115
assert len(rows)==2500
assert sum(1 for k in rows if k.startswith('prison.oldschool.'))==494
assert len(other['records'])-494==169
for f in proof:
    for source in f['sources']:
        line=Path(source['source']).read_text(encoding='utf-8').splitlines()[source['line']-1]
        assert '"'+source['key']+'"' in line
links=re.findall(r'\]\((C:/[^)\n]+)\)',report)
for target in links:
    m=re.fullmatch(r'(.+?)(?::(\d+))?',target)
    path=Path(m[1]);assert path.exists(),target
    if m[2]:assert 1<=int(m[2])<=len(path.read_text(encoding='utf-8').splitlines())
summary=dict(classicEntries=1837,otherPrisonEntries=663,sharedAchievementEntries=169,oldSchoolEntries=494,
    numberedMineEntries=len(mines),locationEntries=len(locations),itemCategoryLabels=len(categories),bossNames=len(bosses),
    findingsWithSourceKeys=len(proof),sourceHashesMatched=True,localLinksChecked=len(links),
    perMineUnlockLevelsRecovered=sum(r['unlockLevel'] is not None for r in observed_mines['mineLocations']),
    pickaxeUpgradeTransitionsRecovered=len(observed_pickaxe['transitions']),
    swordUpgradeTransitionsRecovered=len(observed_other_items['sword']['transitions']),
    shovelUpgradeTransitionsRecovered=len(observed_other_items['shovel']['transitions']),
    suppliedScreenshotsProcessed=len(all_screenshot_sources),
    uniqueOriginalScreenshots=len({s['originalSha256'] for s in all_screenshot_sources}),
    mineCompositionRowsRecovered=len(observed_composition['entries']),
    distinctMineNamesWithComposition=len({r['name'] for r in observed_composition['entries']}),
    observedBossesWithPossibleRewards=len(observed_bosses['entries']),
    storeOffers=len(observed_store_map['storeOffers']),
    teleporterDestinations=len(observed_store_map['teleporter']['entries']),
    armorUpgradeTransitions=sum(len(observed_armor_axe['items'][k]['transitions']) for k in ['helmet','chestplate','leggings','boots']),
    axeUpgradeTransitions=len(observed_armor_axe['items']['axe']['transitions']),
    allItemUpgradeTransitions=total_item_transitions,
    observedAncientBookTemplates=len(observed_books['templates']),
    auctionBookObservationFrames=len(observed_books['auctionBookObservations']),
    completeItemUpgradeTablesRecovered=0,
    status='Corrected 289-frame inventory; 115 item transitions, 31 book templates, 26 mine rows, 17 bosses; not server configuration.')
(OUT/'catalog-validation.json').write_text(json.dumps(summary,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(summary,ensure_ascii=False,indent=2))
