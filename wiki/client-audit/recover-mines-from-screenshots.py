"""Preserve a manual transcription of supplied game menus with image-level evidence.

Only the game menu rectangles are retained in the evidence folder. No OCR-derived
guesses, inferred unlock sequences, or vanilla block IDs are promoted to facts.
"""
from pathlib import Path
import hashlib
import json
import re
import sys

from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
EVIDENCE = OUT / 'mine-menu-evidence'
EVIDENCE.mkdir(parents=True, exist_ok=True)
TEMP = Path('C:/Users/user/AppData/Local/Temp')
FILES = [
    ('134e806e-2f09-4e5d-9b3c-5acc2c711472', (76, 38, 1330, 793)),
    ('f12bee24-6108-4756-8855-7085226c4acf', (23, 13, 1278, 768)),
    ('9310962b-1f66-40e4-9b6d-2e4125c42237', (191, 66, 1448, 820)),
    ('024f13f0-a3c3-4e04-9ca2-d3dcab2760c7', (333, 163, 1587, 919)),
    ('96593a8d-f524-480a-90c6-cf7749236769', (332, 154, 1587, 908)),
    ('d0c1f034-1a6d-4daf-b563-e4692c9fb330', (23, 13, 1278, 768)),
    ('b3c5d609-8ab3-48b8-b1ad-74a9f9ef3b01', (332, 154, 1587, 908)),
    ('c3810108-adb5-4cb5-bd03-8fb114b6e674', (645, 253, 1278, 810)),
    ('fb734bb3-af7b-452b-ab34-224368510d29', (579, 292, 1340, 740)),
]

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

sources = []
hash_to_source = {}
for number, (suffix, box) in enumerate(FILES, 1):
    original = TEMP / f'codex-clipboard-{suffix}.png'
    preserved = EVIDENCE / f'screenshot-{number:02d}-game-menu.png'
    source_hash = sha(original)
    with Image.open(original) as im:
        width, height = im.size
        assert 0 <= box[0] < box[2] <= width
        assert 0 <= box[1] < box[3] <= height
        im.crop(box).save(preserved)
    sources.append(dict(id=f'image_{number}',attachmentNumber=number,
        originalFilename=original.name,originalSha256=source_hash,
        originalDimensions=[width,height],cropBox=list(box),
        evidencePath=preserved.as_posix(),evidenceSha256=sha(preserved),
        duplicateOf=hash_to_source.get(source_hash)))
    hash_to_source.setdefault(source_hash, f'image_{number}')

def refs(*numbers):
    return [f'image_{n}' for n in numbers]

mines = []
def add(name, category, level, evidence, badge, *, ceiling=None, start=False):
    mines.append(dict(name=name,menuTab=category,unlockLevel=level,
        unlockLevelUpperBound=ceiling,startingLocationLabel=start,
        observedAccessibleAtLevel=8 if ceiling is not None else None,
        pvpBadgeVisible=badge,
        pvpEnabled=True if badge is True else None,
        evidence=evidence,
        exactMaterialIds=None,blockPercentages=None,blockPrices=None,
        resetSeconds=None,dimensions=None,requiredTool=None))

add('Тюрьма','Шахты',None,refs(1,2,3,4),False,start=True)
for name in ('Каменоломня','Подножье горы','Преисподняя'):
    add(name,'Шахты',None,refs(1),False,ceiling=8)
for name, level, numbers in [
    ('Пирамида',9,[1,9]),('Королевский сад',11,[1,2]),
    ('Затопленный маяк',13,[1,2]),('Пустотная крепость',15,[2]),
    ('Паучье логово',17,[2,3,6]),('Снежная длань',19,[2,3]),
    ('Рынок',21,[2,3]),('Лепреконовая долина',23,[3]),
    ('Замок',25,[3]),('Изнанка',27,[3,4]),('Киото',29,[3,4]),
    ('Ферма',31,[4]),('Амбар',33,[4]),('Врата края',35,[4]),
]:
    add(name,'Шахты',level,refs(*numbers),True)
for name, level in [
    ('Древо',37),('Церковь',39),('Чистилище',41),('Эдем',43),
    ('Херувимы',45),('Врата',47),('Рай',49),
]:
    add(name,'Небесные шахты',level,refs(5),True)

other_locations = [
    dict(name='Подвал',unlockLevel=None,accessLabel=None,pvpBadgeVisible=True),
    dict(name='База фракций',unlockLevel=None,accessLabel=None,pvpBadgeVisible=True),
    dict(name='Дворы',unlockLevel=None,accessLabel=None,pvpBadgeVisible=True),
    dict(name='База банды',unlockLevel=None,accessLabel='Нужна банда',pvpBadgeVisible=False),
    dict(name='Гетто',unlockLevel=None,accessLabel='Нужно гетто',pvpBadgeVisible=True),
    dict(name='Личная камера',unlockLevel=None,accessLabel=None,pvpBadgeVisible=False),
    dict(name='Нефтезавод',unlockLevel=12,accessLabel='12 уровень',pvpBadgeVisible=True),
    dict(name='Карьеры',unlockLevel=16,accessLabel='16 уровень',pvpBadgeVisible=False),
]
for row in other_locations:
    row['evidence'] = refs(7)
    row['limitation'] = 'Absent level/badge on an available card does not establish an unlock level or PvP rule.'

palettes = [
    dict(location='Тюрьма',evidence=refs(1),visibleSlots=3,
         visualLabels=['земля','песок','гравий'],exactMaterialIds=None,
         certainty='visual identification of icons only; labels and IDs not displayed'),
    dict(location='Паучье логово',evidence=refs(2,3,4,6),visibleSlots=2,
         visualLabels=['белый блок','паутина'],exactMaterialIds=None,
         certainty='white block unresolved; no block name tooltip supplied',
         bossIcon=dict(visible=True,visualLabel='паук',bossName=None)),
    dict(location='Древо',evidence=refs(5),visibleSlots=1,
         visualLabels=['белый блок'],exactMaterialIds=None,
         certainty='material unresolved; no block name tooltip supplied'),
    dict(location='Подвал',evidence=refs(7),visibleSlots=3,
         visualLabels=['земля','песок','гравий'],exactMaterialIds=None,
         certainty='visual identification of icons only; labels and IDs not displayed'),
]
transition = dict(fromLevel=8,toLevel=9,evidence=refs(9),
    requirements=dict(blocks=dict(display='34.1K',exactValue=None,
        approximateValue=34100,precision='abbreviated UI value'),
        money=dict(display='440',exactValue=440,currency='game money')),
    unlocks=dict(location='Пирамида',heartsBefore=13.5,heartsAfter=14.0),
    limitations=[
        'Screenshot does not establish whether the block threshold is cumulative or per-level.',
        'Screenshot does not establish which counters are spent/reset on level-up.',
        'Do not derive all other level prices or a progression formula from this one transition.',
    ])

known_level_rows = [r for r in mines if r['unlockLevel'] is not None]
data = dict(recordedDate='2026-10-19',sourceType='user supplied in-game screenshots',
    serverBrand='Cristalix',modeLabel='Prison Classic',observedPlayerLevel=8,
    realmVariant=None,
    scope='Observed menu state; Normal/Quick variant and complete server cap are not established.',
    transcription='Manual visual reading of original-resolution supplied attachments',
    sources=sources,mineLocations=mines,otherLocations=other_locations,
    visibleBlockPalettes=palettes,levelTransitions=[transition],
    supplementaryDatasets=dict(resourceLabels='prison-plus-mine-content.json',
        bossesAndLocations='boss-menu-recovery.json',
        note='This file preserves the original 9-frame evidence scope; later /pp observations are separate.'),
    corrections=[
        'Mine IDs mine_1..mine_14 from localization are not the current menu roster or unlock levels.',
        'Current supplied menu contains a location requiring level 49; the February 2026 cap of 37 cannot describe this menu state.',
        'Level 49 is the highest displayed unlock, not proof of the maximum obtainable player level.',
        'Лесопилка and Лесная чаща are not visible in the supplied mine-tab screenshots; removal is not proven.',
        'Left-hand block/boss details belong to the selected location, not every card visible on the right.',
    ],
    remainingUnknowns=[
        'Exact unlock levels of the three already accessible mines',
        'Other unseen menu entries, if any, and exact current realm variant',
        'Block material IDs, percentage composition, dimensions, prices, reset intervals and tools',
        'Boss statistics and complete spawn periods; 17 named locations/rewards recovered separately in boss-menu-recovery.json',
        'Player level requirement table beyond transition 8 to 9',
    ])
(OUT/'mine-menu-recovery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def source_links(evidence):
    return ', '.join(f'[снимок {n}]({sources[n-1]["evidencePath"]})'
                     for n in [int(e.split('_')[1]) for e in evidence])

def table(category):
    lines=['| Локация | Доступ | Отметка PvP | Источник |',
           '| --- | --- | --- | --- |']
    for row in mines:
        if row['menuTab'] != category:
            continue
        access = str(row['unlockLevel']) if row['unlockLevel'] is not None else (
            'Стартовая локация' if row['startingLocationLabel'] else 'Уже открыта на 8; точный порог скрыт')
        lines.append(f'| {row["name"]} | {access} | {"Есть" if row["pvpBadgeVisible"] else "Не показана"} | {source_links(row["evidence"])} |')
    return '\n'.join(lines)

other_table='\n'.join(f'| {r["name"]} | {r["unlockLevel"] or r["accessLabel"] or "На снимке не указан"} | {"Есть" if r["pvpBadgeVisible"] else "Не показана"} |' for r in other_locations)
palette_table='\n'.join(f'| {r["location"]} | {r["visibleSlots"]} | {", ".join(r["visualLabels"])} | {source_links(r["evidence"])} |' for r in palettes)
report=f'''# Prison Classic: восстановление шахт по игровому меню

19 октября 2026 года. Источник — девять снимков пользователя; данные прочитаны с оригинальным разрешением. Обработаны только игровые меню. Прочие окна рабочего стола и чат не включены в сохранённые фрагменты.

**Дополнено следующими сериями:** [названия блоков всех 25 локаций]({(ROOT/'MINE-COMPOSITION.md').as_posix()}) и [17 боссов с локациями и возможными наградами]({(ROOT/'BOSS-MENU-RECOVERY.md').as_posix()}). Этот документ сохраняет отдельный разбор первых девяти кадров; поздние данные имеют собственные источники.

**Восстановлен 21 точный порог доступа к шахтам: 14 во вкладке «Шахты» и 7 во вкладке «Небесные шахты».** Ещё три шахты уже открыты на 8-м уровне, а Тюрьма отмечена как стартовая локация. Итого на присланных экранах этих двух вкладок видны 25 разных локаций. Это подсчёт наблюдаемых карточек, не заявление о полном числе шахт на сервере.

Снимки показывают бренд Cristalix и режим Prison Classic. Вариант Normal/Quick не установлен. Данные относятся к показанному состоянию меню, а не автоматически ко всем под-серверам Classic.

## Вкладка «Шахты»

{table('Шахты')}

На карточках открытых шахт точные уровни не показаны. Последовательность 3/5/7 могла бы выглядеть правдоподобно, но снимки её не доказывают — эти значения не подставлены. Отсутствующая отметка PvP тоже не принята за доказательство отключённого PvP.

## Вкладка «Небесные шахты»

{table('Небесные шахты')}

Описание Древа: «Исполинское древо, чьи корни уходят сквозь облака. С него начинается путь в небесные шахты». На всех семи карточках есть отметка PvP. **49 — наибольший показанный порог доступа, а не установленный максимум уровня персонажа.**

## Прочие локации

Все значения в этой таблице прочитаны со {source_links(refs(7))}. Для открытых карточек отсутствие порога не позволяет восстановить его.

| Локация | Уровень или условие на карточке | Отметка PvP |
| --- | --- | --- |
{other_table}

Уровень 16 здесь относится к входу «Карьеры»; это не доказательство одинакового порога для всех четырёх видов карьера. Условие Подвала «5-й уровень + пропуск» ранее найдено в локализации; сам этот снимок его не показывает.

## Состав блоков: что действительно видно

| Выбранная локация | Число иконок | Визуально показано | Источник |
| --- | ---: | --- | --- |
{palette_table}

Земля/песок/гравий названы по внешнему виду иконок; подписи, точные ID, проценты и цены на снимках отсутствуют. Белый блок не объявлен автоматически шерстью, снегом или кварцем. Рядом с Паучьим логовом есть иконка паука в разделе «Боссы», но имя босса на этих кадрах не показано.

Поздние карточки `/pp` уточнили Древо как **Белый цемент**, Паучье логово как **Паутину / Белую шерсть** и его босса как **Паучью матку**. У Тюрьмы перечислены также Дуб и Арбуз: прежние три иконки не считались исчерпывающим составом. Для Подвала остаётся только первоначальное визуальное наблюдение.

На снимках 2–4 и 6 слева всё ещё выбрано **Паучье логово**, хотя справа пользователь прокручивает другие шахты. Поэтому его блоки и босса нельзя приписать Снежной длани, Ферме, Амбару или остальным карточкам.

## Один подтверждённый переход уровня: 8 → 9

Источник: {source_links(refs(9))}.

| Поле | Показанное значение |
| --- | --- |
| Требование по блокам | **34.1K** |
| Требование по балансу | **440** |
| Новая локация | **Пирамида** |
| Здоровье, поле «Сердца» | **13.5 → 14.0** |

34.1K — сокращённое число интерфейса, примерно 34 100; точное целое не восстановлено. Снимок не устанавливает накопительный характер счётчика, списание блоков/денег или формулу требований следующих уровней. Видимые текущие показатели игрока не перенесены как параметры баланса игры.

## Что исправлено в прежнем разборе

- Список из 14 `mine_*` — словарь названий клиента, а не восстановленная действующая лестница шахт. В меню есть Рынок, Изнанка и семь небесных шахт, которых тот список не покрывает.
- Замок в меню требует **25-й уровень**; нельзя связывать его локализационный ID `mine_7` с уровнем 7. Ферма требует **31**, Амбар — **33**.
- Февральское сообщение о максимуме 37 историческое: показанное меню уже содержит шахты с порогами до 49. Текущий максимум уровня персонажа всё ещё не установлен.
- Лесопилка и Лесная чаща на присланных кадрах не видны. Объявлять их действующими по старому словарю или удалёнными по этим кадрам преждевременно.
- Название «Лепреконовая долина» записано по карточке меню; старые тексты боссов могли использовать иной вариант названия.

## Что ещё нужно получить

1. Для Каменоломни, Подножья горы и Преисподней — точные пороги доступа из Wiki или экрана информации, который показывает их и после открытия.
2. Для каждой шахты — ID и доли блоков, цены у скупщика/автопродажи, размеры, инструменты и полный интервал восстановления. Названия блоков уже добавлены из следующей серии `/pp`.
3. Для развития персонажа — требования остальных переходов из меню уровня или Wiki.
4. Для боссов — параметры боёв, вероятности и разделение наград, полные интервалы возрождения. Имена, локации и возможные награды 17 карточек уже разобраны отдельно.

В [машинной таблице]({(OUT/'mine-menu-recovery.json').as_posix()}) неизвестные значения сохранены как `null`; у каждого вывода есть номера снимков. SHA-256 оригиналов и сохранённых игровых фрагментов позволяют проверить происхождение данных.
'''
(ROOT/'MINE-RECOVERY.md').write_text(report,encoding='utf-8')

# Integrity checks protect transcription structure, not the semantics of an image.
assert len(mines)==25
assert len({r['name'] for r in mines})==25
assert len(known_level_rows)==21
assert len([r for r in known_level_rows if r['menuTab']=='Шахты'])==14
assert len([r for r in known_level_rows if r['menuTab']=='Небесные шахты'])==7
assert [r['unlockLevel'] for r in known_level_rows]==list(range(9,50,2))
assert len(other_locations)==8
assert len([r for r in other_locations if r['unlockLevel'] is not None])==2
assert all(r['blockPrices'] is None and r['resetSeconds'] is None for r in mines)
for row in mines+other_locations+palettes+[transition]:
    assert all(e in {s['id'] for s in sources} for e in row['evidence'])
for source in sources:
    assert sha(Path(source['evidencePath']))==source['evidenceSha256']
for path in re.findall(r'\]\((C:/[^)]+)\)',report):
    assert Path(path).exists(),path
validation=dict(screenshots=len(sources),uniqueOriginalImages=len(hash_to_source),
    mineTabLocations=25,exactMineUnlockLevels=21,accessibleMineUpperBounds=3,
    skyMineLevels=7,otherLocations=8,otherExactUnlockLevels=2,
    levelTransitions=1,exactBlockPriceTables=0,resetIntervals=0,
    evidenceHashesVerified=True,transcription='manual, visually inspected',
    limitations='Checks verify structure and file integrity, not a complete server configuration.')
(OUT/'mine-recovery-validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation,ensure_ascii=False,indent=2))
