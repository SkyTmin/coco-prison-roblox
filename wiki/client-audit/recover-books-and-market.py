"""Join observed ancient-case templates, actual auction books and key sources.

Manual original-resolution transcription, not inferred server configuration.
"""
from pathlib import Path
import collections
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
book_sources=json.loads((OUT/'book-case-sources.json').read_text(encoding='utf-8'))
missed_sources=json.loads((OUT/'missed-menu-sources.json').read_text(encoding='utf-8'))
npcs=json.loads((OUT/'npc-menu-recovery.json').read_text(encoding='utf-8'))
localization=json.loads((ROOT/'decoded/classic-enchantments.json').read_text(encoding='utf-8'))
local_by_name={x['name']:x for x in localization}
index=json.loads((OUT/'classic-content-index.json').read_text(encoding='utf-8'))
indexed={r['key']:r for r in index['records']}
rule_keys=[
    'prison.classic.ancient_enchantment.not_applied',
    'prison.classic.ancient_enchantment.too_many_enchantments',
    'prison.classic.ancient_enchantment.already_casted',
    'prison.classic.donate.list.powder.description',
    'prison.classic.ancient_enchantment.powder.already_max_chance',
    'prison.classic.gang.upgrades.blacksmith_description',
    'prison.classic.gang.blacksmith.choice_similar_books',
    'prison.classic.gang.blacksmith.chance',
]
client_rules=[dict(key=k,text=indexed[k]['text'],source=index['source'],sourceLine=indexed[k]['sourceLine'],
    status='client text; actual server action not observed') for k in rule_keys]
all_sources={s['id']:s for d in [book_sources,missed_sources,npcs] for s in d['sources']}


def dump(name,data):
    (OUT/name).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def links(ids):
    return ', '.join(f"[{sid}]({all_sources[sid]['evidencePath']})" for sid in ids)


tools=['Кирка','Топор','Лопата','Ножницы']
weapons=['Меч','Лук']
armor=['Шлем','Нагрудник','Поножи','Ботинки']
# Screenshot number, literal name, maximum displayed Roman level, target items,
# observed description summary. Rarity comes from the explicit badge, not color.
raw=[
    (3,'Чистюля',2,['Шлем'],'Нужды — туалет, душ и сон — наступают реже.'),
    (4,'Барыга',3,tools,'При добыче есть шанс получить ещё один такой же блок; работает и с автопродажей.'),
    (5,'Токсичный',3,['Меч'],'При нанесении урона есть шанс отравить врага.'),
    (6,'Раскалённый',3,['Поножи'],'При получении урона есть шанс поджечь противника.'),
    (7,'Мороз',3,['Лук'],'При попадании стрелой возможно кратковременно снизить скорость игрока.'),
    (9,'Пружины',3,['Ботинки'],'Постоянный эффект прыгучести.'),
    (10,'Громовержец',3,weapons,'При нанесении урона есть шанс вызвать молнию на врага.'),
    (11,'Боксёр',3,weapons,'При нанесении урона есть шанс нанести дополнительный значительный урон и подкинуть противника.'),
    (12,'Замешательство',3,weapons,'При нанесении урона есть шанс наложить тошноту.'),
    (13,'Пожар',3,['Лук'],'При попадании стрелой есть шанс создать огненный взрыв под игроком.'),
    (14,'Берсерк',3,['Меч'],'Если меньше 10 сердец, есть шанс нанести двойной урон.'),
    (15,'Бульдозер',3,['Ботинки'],'При получении урона есть шанс замедлить противника.'),
    (16,'Укрепление',3,['Нагрудник'],'При получении урона есть шанс наложить слабость на противника.'),
    (17,'Иссушение',3,['Поножи'],'При получении урона есть шанс наложить иссушение на противника.'),
    (18,'Вихрь',3,weapons,'Описание обещает дезориентацию волной ударов; число ударов и точная механика не раскрыты.'),
    (19,'Слепота',3,weapons,'При нанесении урона есть шанс наложить слепоту.'),
    (20,'Халк',1,['Нагрудник'],'Постоянные Сопротивление урону I и Замедление I.'),
    (21,'Танк',3,armor,'Даёт постоянные дополнительные сердца.'),
    (22,'Обжора',3,['Шлем'],'Восстанавливает голод во время сражений.'),
    (23,'Ниндзя',3,['Ботинки'],'При нанесении удара есть шанс получить скорость.'),
    (24,'Стукач',1,['Шлем'],'Ударивший игрок начинает светиться и виден окружающим несколько секунд.'),
    (25,'Шныр',2,['Ботинки'],'Есть шанс уклониться от удара другого игрока без получения урона.'),
    (26,'Проклятие',3,weapons,'Удар может временно запретить восстановление здоровья, включая Вампиризм и Просвещённого; после эффекта 5 секунд защиты от повторного проклятия.'),
    (27,'Ярость',3,weapons,'Каждый удар по противнику увеличивает последующий урон по нему.'),
    (28,'Археолог',3,tools,'При добыче есть шанс получить ускоренное копание.'),
    (29,'Просвещённый',3,armor,'При получении урона есть шанс восстановить здоровье.'),
    (30,'Пластолом',3,['Кирка'],'Может убрать весь слой шахты под игроком; в статистику идёт половина блоков слоя, до 200 штук.'),
    (31,'Молот',3,tools,'При добыче может вскопать случайные блоки в некотором радиусе.'),
    (32,'Старатель',3,weapons,'Увеличивает звёзды с босса в зависимости от доли урона, нанесённого этим оружием.'),
    (33,'Общак',3,weapons,'Увеличивает долю денег из банка босса в зависимости от доли урона, нанесённого этим оружием.'),
    (34,'Вампиризм',3,weapons,'Лечит при нанесении урона; величина зависит от урона и уровня зачарования.'),
]
templates=[]
for n,name,maximum,targets,description in raw:
    rarity='обычное' if n<=16 else ('редкое' if n<=26 else 'легендарное')
    loc=local_by_name[name]
    templates.append(dict(name=name,serverId=None,localizationId=loc['id'],
        evidence=[f'book_case_{n}']+(['book_case_8'] if n==7 else []),
        rarityDisplay=rarity,displayedLevelMin=1,displayedLevelMax=maximum,
        applicableItems=targets,observedDescriptionSummary=description,
        localizationDescription=loc['description'],localizationDescriptionKey=loc['descriptionKey'],
        improvedKeyRuleDisplay='Открыв лутбокс с улучшенным древним ключом — книга выпадет с максимальным уровнем!',
        improvedKeyGivesMaximumLevel=True,templateApplicationChance=None,caseDropProbability=None,
        procProbabilityByLevel=None,effectMagnitudeByLevel=None,durationByLevelSeconds=None))
byname={t['name']:t for t in templates}
byname['Берсерк']['numericTooltipRules']=dict(healthBelowHearts=10,possibleDamageMultiplier=2)
byname['Халк']['numericTooltipRules']=dict(resistanceLevel=1,slownessLevel=1)
byname['Проклятие']['numericTooltipRules']=dict(postEffectReapplyImmunitySeconds=5,
    blocksHealingEffects=['Вампиризм','Просвещённый'],effectDurationSeconds=None)
byname['Пластолом']['numericTooltipRules']=dict(statisticsLayerFraction=0.5,statisticsMaxBlocks=200,
    layerDimensions=None,procChance=None)
for name in ['Старатель','Общак']:
    byname[name]['numericTooltipRules']=dict(
        observedThresholdText='Меньше 35урона: бонуса нет.',
        localizationThresholdText='Меньше 35% урона: бонуса нет.',
        damageShareThresholdPercentInLocalization=35,
        thresholdInterpretation='Screenshot loses the percent glyph; 35% is stated by the matching client localization, not a measured server threshold.',
        countedDamageSource='this enchanted weapon',bonusFormula=None)

# Each row is one observation of a player offer. 104/105 show the same book and
# seller with a ticking expiry; no count of independent lots is inferred.
auction_raw=[
    (92,'Берсерк',2,17,6000),(93,'Громовержец',3,20,7000),(94,'Громовержец',2,56,7777),
    (95,'Чистюля',2,31,3000),(96,'Пожар',2,69,10000),(97,'Боксёр',1,38,5000),
    (98,'Берсерк',3,31,20000),(99,'Замешательство',1,23,5000),(100,'Танк',3,21,40000),
    (101,'Шныр',2,43,10000),(102,'Укрепление',2,74,14500),(103,'Иссушение',3,11,15000),
    (104,'Громовержец',3,62,17000),(105,'Громовержец',3,62,17000),(106,'Проклятие',3,76,80000),
    (107,'Укрепление',2,3,22500),(108,'Берсерк',3,99,50000),(109,'Укрепление',3,64,65000),
    (110,'Танк',3,41,40000),(111,'Общак',1,50,10000),(112,'Бульдозер',3,36,35000),
    (113,'Пластолом',2,100,80000),(114,'Пожар',3,30,15000),(115,'Археолог',1,89,150),
    (116,'Обжора',3,95,200),(117,'Просвещённый',3,47,1500),(118,'Пластолом',2,28,199),
    (119,'Пластолом',3,1,499),(120,'Просвещённый',3,54,1800),(121,'Ярость',1,65,200),
    (122,'Проклятие',3,69,699),(123,'Обжора',3,80,300),(124,'Проклятие',3,60,700),
    (125,'Археолог',3,49,2500),(126,'Просвещённый',3,24,2500),
]
auction_books=[dict(observationId=f'coverage_{n}',evidence=[f'coverage_{n}'],name=name,
    enchantmentLevel=level,applicationSuccessPercent=chance,
    applicationChanceLabel='Шанс зачарования предмета', procChance=None,
    applicableItems=byname[name]['applicableItems'],askingPrice=price,
    askingCurrency='рубины' if n>=115 else 'игровые деньги',
    priceSource='player auction asking price; not NPC price or completed sale',
    repeatOfObservation='coverage_104' if n==105 else None)
    for n,name,level,chance,price in auction_raw]
not_observed=[dict(name=r['name'],localizationId=r['id']) for r in localization if r['name'] not in byname]
key_routes=[]
for x in npcs['starExchanges']:
    key_routes.append(dict(name=x['name'],costStars=x['cost'],evidence=x['evidence'],
        description=x['tooltip'],booksReturned=x.get('booksReturned')))

book_data=dict(recordedDate='2026-10-20',sourceType='Observed ancient-case previews, auction books, NPC exchange menus and separately attributed localization',
    sourceManifests=['book-case-sources.json','missed-menu-sources.json'],
    sourceIds=[f'book_case_{n}' for n in range(1,35)]+[f'coverage_{n}' for n in range(92,127)],
    userStatement=book_sources['userStatement'],caseName='Древний кейс',templates=templates,
    auctionBookObservations=auction_books,localizationOnlyNotObserved=not_observed,clientTextRules=client_rules,
    keyAcquisition=dict(starExchange=key_routes,
        donateStore=[dict(name='Древний ключ',displayedPrice=149),dict(name='Улучшенный древний ключ',displayedPrice=349),
            dict(name='Древний порошок',displayedPrice=17),dict(name='Развеиватель',displayedPrice=199)],
        donateCurrency='blue store-currency icon; debit currency and real-money exchange rate untested',donateEvidence=['book_case_2'],
        starsFromBosses='boss-menu-recovery.json',starsAlsoFromOrdinaryCase=dict(evidence=['coverage_89','coverage_129'],status='item tooltip statement')),
    application=dict(displayedAction='Нажать книгой по желаемому предмету',
        explicitCompatibleItemLists=True,bookLevelAndSuccessChanceSeparate=True,
        powder=dict(evidence=['coverage_91'],observedEffectivenessPercent=2,
            description='Очищает книгу от пыли, увеличивая её шанс наложения.',
            increaseFormula=None,increaseRuleInClientText='Each efficiency percentage point adds one application success percentage point',
            capPercent=None,applicationActionObserved=False),
        disenchanter=dict(costStars=15,booksReturned=False,evidence=['npc_image_8','npc_image_9']),
        failureConsequences=None,duplicateEnchantBehavior=None,enchantSlotLimit=None,
        minimumItemLevel=None,bookCombinationRule=None),
    caveats=[
        '31 distinct template names are observed; no claim that these exhaust all seasons or every possible case reward.',
        'The 38-name localization inventory is wider; seven entries remain localization-only in these screenshots.',
        'Case rarity is an explicit label, not a recovered drop probability.',
        'Roman book level, per-instance application success, and effect activation chance are three separate parameters.',
        'Improved ancient keys guarantee maximum displayed book level according to the tooltip, not 100% application or a selected rarity.',
        'No case was successfully opened in this series; the first image reports no key.',
        '35 auction book observations include one revisited lot; asking prices are not fixed balance values or proof of sales.',
        'Screenshot 7 and 8 in the new case batch are byte-identical.',
        'Boss-bonus threshold percent is disambiguated using client localization; screenshot itself renders 35урона.',
    ])
dump('books-system-recovery.json',book_data)

other_offers=[
    dict(evidence=['coverage_86','coverage_127'],name='Редкая деревянная кирка',level=1,
        shownEnchantments=['Шёлковое касание I'],askingPrice=350,askingCurrency='игровые деньги',
        note='Same seller/item revisited through the Tools filter; unique lot identity not exposed.'),
    dict(evidence=['coverage_87'],name='Пропуск в подвал',askingPrice=100,askingCurrency='игровые деньги',
        effect='Активация даёт доступ в Подвал; продолжительность на подсказке не указана.'),
    dict(evidence=['coverage_88'],name='Ключ от Обычного кейса',askingPrice=90,askingCurrency='игровые деньги',
        effect='Открывает Обычный кейс на Спавне.'),
    dict(evidence=['coverage_89'],name='Древняя звезда',askingPrice=1459,askingCurrency='игровые деньги',
        effect='Возможна с босса или Обычного кейса; обменивается на ключи у Обменника звёзд на Рынке.'),
    dict(evidence=['coverage_90'],name='Гнилая плоть',askingPrice=1000,askingCurrency='игровые деньги'),
    dict(evidence=['coverage_91'],name='Древний порошок',effectivenessPercent=2,askingPrice=999,askingCurrency='игровые деньги'),
    dict(evidence=['coverage_128'],name='Питьевое зелье',effectDisplay='Регенерация (0:34)',
        attributeDisplay='При применении: +3 Урон',playerCraftedLabelVisible=True,
        askingPrice=200,askingCurrency='игровые деньги',recipe=None,
        note='Unexpected +3 damage is preserved literally, not silently corrected or promoted to a verified effect.'),
    dict(evidence=['coverage_129'],name='Древняя звезда',askingPrice=3670,askingCurrency='игровые деньги'),
    dict(evidence=['coverage_130'],name='Туалетная бумага',askingPrice=3000,askingCurrency='игровые деньги',
        effect='Позволяет удовлетворить туалетную нужду вне туалета.'),
]
extras=dict(recordedDate='2026-10-20',sourceManifests=['missed-menu-sources.json'],
    sourceIds=[f'coverage_{n}' for n in range(81,92)]+[f'coverage_{n}' for n in range(127,131)],
    auctionOverview=dict(evidence=['coverage_85'],tabs=['Аукцион','Личные товары'],
        currencies=['Деньги','Рубины'],filters=['Тип','Цена от/до','Уровень от/до'],
        sorting=['По уровню','По времени','По стоимости'],search=True,pagination=True,sellButton=True),
    otherAuctionOffers=other_offers,
    faction=dict(evidence=['coverage_83','coverage_84'],displayedPlayerFaction='Славяне',
        observedPointTypes=['Деньги','Блоки','Мобы','Спешка'],
        observedPointOwners={'Деньги':'Афро','Блоки':'Афро','Мобы':'Латиносы','Спешка':'Афро'},
        menuCapturedPointsDisplay='0/4',leaveConfirmationCost=2500,currency='игровые деньги',
        costMeaning='leave faction confirmation, not proven cost to join/switch',numericBonuses=None,leavePerformed=False),
    mining=dict(evidence=['coverage_81','coverage_82'],moneyPopupDisplay='+0.012 $',
        comboMultiplierDisplay='x1',comboCounterDisplays=['22/1000','27/1000'],
        counterMeaning='displayed combo progress, not tool durability',baseBlockSalePrice=None,
        note='Still frames show mining feedback; exact block-to-payment pairing, bonuses and combo formula were not established.'))
dump('auction-and-scenes-recovery.json',extras)

roman={1:'I',2:'II',3:'III'}
template_sections=[]
for rarity in ['обычное','редкое','легендарное']:
    lines=[]
    for t in templates:
        if t['rarityDisplay']!=rarity:continue
        levels='I' if t['displayedLevelMax']==1 else f"I–{roman[t['displayedLevelMax']]}"
        lines.append(f"| {t['name']} | {levels} | {', '.join(t['applicableItems'])} | {t['observedDescriptionSummary']} | {links(t['evidence'])} |")
    template_sections.append(f"### {rarity.capitalize()} — {len(lines)}\n\n| Книга | Уровни | Предметы | Что описано | Источник |\n| --- | --- | --- | --- | --- |\n"+'\n'.join(lines))
auction_table='\n'.join(f"| {b['name']} {roman[b['enchantmentLevel']]} | {b['applicationSuccessPercent']}% | {b['askingPrice']} | {b['askingCurrency']} | {links(b['evidence'])} |" for b in auction_books)
report=f'''# Prison Classic: книги, ключи и древние зачарования

20 октября 2026 года. Книги выделены в отдельную систему развития. В новых 34 кадрах Древнего кейса показано **31 различное зачарование: 13 обычных, 10 редких, 8 легендарных**. Два кадра Мороза повторяются побайтно. Из пропущенных кадров Аукциона отдельно прочитаны **35 наблюдений книг**: конкретный уровень, шанс наложения, цена и валюта предложения игрока.

## Путь получения и применения

```mermaid
flowchart LR
    Boss[Боссы] --> Stars[Древние звёзды]
    Ordinary[Обычный кейс: звёзды по подсказке] --> Stars
    Stars --> Market[Обменник звёзд на Рынке]
    Market --> Key[Древний ключ: 10 звёзд]
    Market --> Better[Улучшенный ключ: 60 звёзд]
    Donate[Магазин] --> Key
    Donate --> Better
    Key --> Case[Древний кейс на Спавне]
    Better --> Case
    Case --> Book[Книга: редкость, уровень, шанс наложения]
    Book --> Auction[Продажа и покупка у игроков]
    Book --> Apply[Применение к подходящему предмету]
    Powder[Древний порошок] --> Book
    Apply --> Gear[Зачарованный предмет]
```

Путь «ключ за донат или звёзды на Рынке» указан пользователем и подтверждается снятыми меню. Обменник продаёт **Древний ключ за 10 звёзд**, **Улучшенный древний ключ за 60**, **Развеиватель за 15**. Оба ключа в подсказках предназначены для **Древнего кейса на Спавне**. {links(['npc_image_6','npc_image_7','npc_image_9'])}.

В магазине показаны цены **149** за древний ключ и **349** за улучшенный; порошок — **17**, Развеиватель — **199**, рядом с синим значком валюты магазина. Это не установленные рубли/Robux и не измеренный курс пополнения. {links(['book_case_2'])}.

Первая фотография показывает физический Древний кейс и сообщение **«У Вас нет ключа от этого кейса!»**. Дальнейшие кадры — просмотр содержимого, без успешного открытия или применения книги. {links(['book_case_1'])}.

## Четыре разных параметра книги

1. **Название и редкость** — тип эффекта и подпись «обычное / редкое / легендарное». Вероятность получить такую редкость не показана.
2. **Уровень I / II / III** — отдельный параметр. Улучшенный древний ключ по подсказке даёт книгу максимального уровня для её типа: у Чистюли это II, у Халка и Стукача — I, у большинства — III.
3. **Шанс зачарования предмета** — число у конкретной книги на Аукционе. Берсерк III встречается с **31% и 99%**; Пластолом II — с **100% и 28%**. Эти примеры доказывают, что уровень не задаёт единственный шанс наложения.
4. **Срабатывание эффекта после наложения** — шанс отравления, молнии, лечения, копания и т. п. Эти вероятности и большая часть коэффициентов не показаны.

Таким образом, максимальный уровень от улучшенного ключа **не означает 100% наложение** и не обещает легендарную редкость. В окне кейса написано: «Чтобы наложить, нужно нажать книгой по желаемому предмету»; ниже явно перечислены совместимые предметы.

## Каталог наблюдаемых книг

{chr(10).join(template_sections)}

## Порошок, снятие и взаимодействия

У наблюдаемого порошка написано **«Эффективность: 2%»** и что он увеличивает шанс наложения книги. {links(['coverage_91'])}. Отдельная локализация донатного порошка описывает **10% эффективности** и правило **каждый процент эффективности = дополнительный процент к шансу наложения**: это текстовое свидетельство прибавления процентных пунктов, без фактического применения на кадрах. [Клиентский текст]({(ROOT/'decoded/ru_RU-classic.json').as_posix()}:1134). Числовой предел шанса и списание порошка не проверены. Проценты возле порошка в меню боссов могут относиться к эффективности, но это ещё сопоставление источников, не доказанный формат серверной награды. Поэтому эти проценты не объявлены вероятностью выпадения.

Развеиватель у NPC стоит **15 звёзд**; его описание прямо говорит, что снятые книги **не возвращаются**. [Обменники]({(ROOT/'NPC-MENU-RECOVERY.md').as_posix()}).

В локализации отдельно есть сообщение неудачи **«книга порвалась… зачарование не наложилось»**, запрет уже имеющегося зачарования и лимит с подставляемым `%d` — самого числа лимита нет. [Сообщения применения]({(ROOT/'decoded/ru_RU-classic.json').as_posix()}:555). Это позволяет записать ожидаемое поведение интерфейса; фактический расход книги, сохранность предмета и поведение разных уровней одного эффекта не проверены.

Кузница банды по описанию позволяет **скрещивать книги одного типа для повышения уровня**; экран просит выбрать **две** такие книги и имеет поле «Шанс: %d%». Цена, числовой шанс и формула результата не получены. [Описание Кузницы]({(ROOT/'decoded/ru_RU-classic.json').as_posix()}:797). Эти текстовые правила сохранены отдельно от наблюдаемых действий, чтобы не потерять найденную механику и не объявить её протестированной.

**Проклятие** запрещает лечение, включая Вампиризм и Просвещённого; после окончания описаны **5 секунд защиты от повторного проклятия**. Длительность самого запрета неизвестна. **Берсерк** явно использует условие меньше **10 сердец** и возможный урон ×2. **Халк I** сочетает Сопротивление I и Замедление I.

**Пластолом** сносит слой под игроком; в статистику, по тексту, засчитывается половина блоков слоя, до **200**. Это не автоматическое равенство реальной добычи, денег и статистики: эти счётчики нужно разбирать отдельно.

**Старатель / Общак** связывают бонус звёзд/денег с долей урона боссу именно этим оружием. В текущем UI порог отображён как `Меньше 35урона: бонуса нет.`; совпадающая локализация содержит **35%**. Этот процент восстановлен из текста клиента, а не измерен боем. [Локализация]({(ROOT/'decoded/ru_RU-classic.json').as_posix()}:661). Формула роста бонуса неизвестна.

## Наблюдения Аукциона

Это **цены предложения игроков**, не фиксированные цены NPC и не доказательство состоявшихся сделок. Берсерк III с 31% выставлен за 20 000 $, с 99% — за 50 000 $; это наблюдение двух предложений, а не доказанная формула рыночной цены. Кадры 104/105 возвращаются к одному и тому же лоту с таймером.

| Книга | Шанс наложения | Цена предложения | Валюта | Снимок |
| --- | ---: | ---: | --- | --- |
{auction_table}

## Границы восстановления

В старом словаре клиента есть 38 названий. В этих сериях не наблюдаются: **{', '.join(r['name'] for r in not_observed)}**. Их отсутствие в кадрах не доказывает удаление. 31 наблюдаемая книга — не автоматически полный каталог всех сезонов.

Для точного баланса остаются неизвестны распределение выпадения редкостей/типов/уровней, генерация шанса наложения, формула порошка, последствия неудачи, совмещение нескольких книг, коэффициенты и внутренние задержки эффектов, связь с уровнем предмета и серверные проверки.

[Машинная модель книг]({(OUT/'books-system-recovery.json').as_posix()}) · [Новые 34 источника]({(OUT/'book-case-sources.json').as_posix()}) · [Ранее пропущенные источники]({(OUT/'missed-menu-sources.json').as_posix()})
'''
(ROOT/'BOOKS-SYSTEM.md').write_text(report,encoding='utf-8')

other_table='\n'.join(f"| {x['name']} | {x['askingPrice']} | {x['askingCurrency']} | {links(x['evidence'])} |" for x in other_offers)
(ROOT/'AUCTION-AND-FACTION-RECOVERY.md').write_text(f'''# Prison Classic: пропущенные кадры Аукциона, добычи и фракции

20 октября 2026 года. Сохранены ещё 50 ранее пропущенных игровых кадров: 46 Аукциона, 2 добычи и 2 фракций. 35 кадров книг разобраны в [отдельной системе]({(ROOT/'BOOKS-SYSTEM.md').as_posix()}); оставшиеся наблюдения приведены здесь.

## Аукцион

Есть вкладки «Аукцион / Личные товары», фильтр валюты **Деньги / Рубины**, тип предметов, цена/уровень от–до, поиск, сортировки по уровню/времени/цене, страницы и кнопка «Продать». Снимок 85 — обзор, без выбранной подсказки. {links(['coverage_85'])}.

| Предмет | Цена игрока | Валюта | Источник |
| --- | ---: | --- | --- |
{other_table}

Кирка явно подписана **Редкая деревянная кирка**, **Шёлковое касание I**, уровень **1**; она повторно наведена через фильтр инструментов. Подсказка ключа указывает Обычный кейс на Спавне. Подсказка звезды говорит о возможном получении от босса или Обычного кейса и обмене на ключи на Рынке. Цена лота не является ценой одной штуки, если количество не установлено отдельно.

У питьевого зелья показаны **Регенерация (0:34)**, отметка изготовления игроком и строка **«При применении: +3 Урон»**. Необычная строка сохранена буквально; рецепт и фактический эффект не выдуманы. Туалетная бумага по подсказке позволяет удовлетворить нужду в любом месте.

## Фракции

На снимке игрок состоит в «Славянах», показаны четыре точки: **Деньги, Блоки, Мобы, Спешка**, счётчик захваченных **0/4**. В момент кадра первые две и Спешка отмечены за «Афро», Мобы — за «Латиносами». Это состояние захвата, не постоянная принадлежность. Числовых бонусов на кадре нет. {links(['coverage_83'])}.

Диалог спрашивает, хочет ли игрок **покинуть фракцию за 2500 $**. Эта цена не объявлена ценой вступления или смены; подтверждение выхода не выполнялось. {links(['coverage_84'])}.

## Добыча и комбо

Два кадра показывают всплывающие **+0.012 $**, панель **Комбо ×1** и **22/1000 → 27/1000**. Это показанный прогресс комбо, а не прочность инструмента. Из отдельных кадров не установлено соответствие конкретного типа блока выплате, базовая цена, коэффициенты бонусов, время сохранения комбо или его формула. {links(['coverage_81','coverage_82'])}.

[Машинные данные]({(OUT/'auction-and-scenes-recovery.json').as_posix()}) · [Источники]({(OUT/'missed-menu-sources.json').as_posix()})
''',encoding='utf-8')

assert len(templates)==31 and len(byname)==31 and len(not_observed)==7
assert collections.Counter(t['rarityDisplay'] for t in templates)=={'обычное':13,'редкое':10,'легендарное':8}
assert len(auction_books)==35
assert all(1<=b['enchantmentLevel']<=byname[b['name']]['displayedLevelMax'] for b in auction_books)
assert all(0<=b['applicationSuccessPercent']<=100 and b['procChance'] is None for b in auction_books)
assert byname['Чистюля']['displayedLevelMax']==2 and byname['Халк']['displayedLevelMax']==1
used=book_data['sourceIds']+extras['sourceIds']
assert len(used)==len(set(used))==84
assert set(used)=={f'coverage_{n}' for n in range(81,131)}|{f'book_case_{n}' for n in range(1,35)}
for sid in used:
    s=all_sources[sid]
    assert hashlib.sha256(Path(s['evidencePath']).read_bytes()).hexdigest()==s['evidenceSha256']
    assert hashlib.sha256((Path('C:/Users/user/AppData/Local/Temp')/s['originalFilename']).read_bytes()).hexdigest()==s['originalSha256']
for filename in ['BOOKS-SYSTEM.md','AUCTION-AND-FACTION-RECOVERY.md']:
    for target in re.findall(r'\]\((C:/[^)\n]+)\)',(ROOT/filename).read_text(encoding='utf-8')):
        match=re.fullmatch(r'(.+?)(?::(\d+))?',target)
        assert Path(match[1]).is_file(),target
validation=dict(caseScreenshots=34,uniqueCaseOriginals=33,distinctObservedBookTemplates=31,
    rarityCounts=dict(collections.Counter(t['rarityDisplay'] for t in templates)),
    auctionBookObservationScreenshots=35,otherMissedScreenshots=15,totalAssignedSources=84,
    localizationOnlyNames=[r['name'] for r in not_observed],
    applicationChanceSeparatedFromProcChance=True,caseDropProbabilitiesUnknown=True,
    hashesAndLinksMatched=True)
dump('books-system-validation.json',validation)
print(json.dumps(validation,ensure_ascii=False,indent=2))
