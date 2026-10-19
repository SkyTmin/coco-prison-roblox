"""Preserve observed trainer, shop and exchange values from supplied screenshots."""
from pathlib import Path
import hashlib
import json
import re
import sys
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
EVIDENCE=OUT/'npc-menu-evidence'
EVIDENCE.mkdir(parents=True,exist_ok=True)
TEMP=Path('C:/Users/user/AppData/Local/Temp')
FILES=[
    ('89ab7c1c-8984-4739-ba15-9cf3c9242669',(410,285,1515,779)),
    ('081cf0ad-6798-420b-a5ae-f9b9513cf116',(611,371,1309,694)),
    ('5760c57c-8cbe-4c47-9259-72e2397e82a4',(688,265,1233,794)),
    ('eacac7e9-8198-45a2-9b4c-c1d9eb8e6457',(688,265,1335,794)),
    ('6af61260-4b56-4c0f-ab32-f6021324a0c8',(688,265,1535,794)),
    ('06288c17-3695-42e8-8f56-d4e2c5da9154',(630,265,1290,794)),
    ('7697a661-e2b4-4bf2-8ae9-631d43fa2631',(630,265,1380,794)),
    ('2a2a7ff5-7616-4831-81ae-cd5b823b380c',(630,265,1595,794)),
    ('ab2034b9-4408-4c88-bdb2-3a0cdd0e5438',(630,265,1290,794)),
    ('05e77f36-31c5-4c74-8dc7-7977a9297040',(490,370,1428,694)),
]
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
sources=[]
for n,(suffix,box) in enumerate(FILES,1):
    original=TEMP/f'codex-clipboard-{suffix}.png'
    preserved=EVIDENCE/f'npc-{n:02d}.png'
    with Image.open(original) as im:
        dims=list(im.size)
        assert box[2]<=dims[0] and box[3]<=dims[1]
        im.crop(box).save(preserved)
    sources.append(dict(id=f'npc_image_{n}',attachmentNumber=n,
        originalFilename=original.name,originalSha256=sha(original),
        originalDimensions=dims,cropBox=list(box),
        evidencePath=preserved.as_posix(),evidenceSha256=sha(preserved)))

trainer=[
    dict(name='Сила',observedLevel=0,displayedMaximum=20,
         description='Увеличивает силу удара',
         nextUpgradeRequirements={'Зомби':30,'Убийства':15,'Деньги':500}),
    dict(name='Ловкость',observedLevel=0,displayedMaximum=20,
         description='Позволяет увернуться от удара',
         nextUpgradeRequirements={'Деньги':50,'Летучие мыши':5}),
    dict(name='Нужды',observedLevel=0,displayedMaximum=20,
         description='Снижает потребность справлять нужду',
         nextUpgradeRequirements={'Деньги':450}),
]
for row in trainer:
    row.update(evidence=['npc_image_1'],perLevelNumericEffect=None,laterUpgradeRequirements=None)
food=[dict(name=n,price=p,currency='game money',nameStatus='visual icon identification',
           evidence=['npc_image_2'],purchaseQuantity=None)
      for n,p in [('Яблоко','0.03'),('Хлеб','0.25'),('Жареная курица','0.5')]]
tools=[dict(name=n,price=p,currency='game money',nameStatus='visual icon identification',
            evidence=['npc_image_10'],purchaseQuantity=None)
       for n,p in [('Деревянный топор','4'),('Деревянная кирка','22.5'),('Ножницы','4000'),('Деревянная лопата','4')]]
exchanges=[
    dict(name='Древний ключ',cost=10,currency='звёзды',evidence=['npc_image_6','npc_image_9'],
         tooltip='Данный ключ используется для открытия Древнего кейса на Спавне'),
    dict(name='Улучшенный древний ключ',cost=60,currency='звёзды',evidence=['npc_image_7','npc_image_9'],
         tooltip='Данный ключ используется для открытия Древнего кейса на Спавне'),
    dict(name='Развеиватель',cost=15,currency='звёзды',evidence=['npc_image_8','npc_image_9'],
         tooltip='Используйте, чтобы свеять Древние Зачарования с предмета. При использовании книга, с помощью которой было наложено это зачарование — возвращена не будет.',
         booksReturned=False),
]
shards=[
    dict(name='Лунное лезвие',costQuantityVisible=4,evidence=['npc_image_3','npc_image_4'],
         ingredientNameSource='previously recovered localization: Лунная сталь',
         effect='Меняет облик топора и повышает Эффективность до IV',
         restriction='Только максимальный уровень предмета'),
    dict(name='Вулканический камень',costQuantityVisible=4,evidence=['npc_image_3','npc_image_5'],
         ingredientNameSource='previously recovered localization: Огненный осколок',
         effect='Меч поджигает того, кому нанесён урон этим мечом',
         restriction='Только максимальный уровень предмета',
         fireAspectLevelInScreenshot=None),
]
data=dict(recordedDate='2026-10-19',sourceType='user supplied in-game NPC menus',
    sources=sources,trainer=trainer,foodShop=food,toolShop=tools,
    starExchanges=exchanges,shardExchanges=shards,
    caveats=[
        'Only initial trainer upgrade requirements are shown; no later cost curve or effect coefficients recovered.',
        'Shop prices are displayed offer prices; purchase quantity and actual transaction semantics were not tested.',
        'Food/tool names are identified from icons, not hover names or exact material IDs.',
        'Ingredient names for shard recipes come from prior localization; screenshots show icons and quantity 4.',
        'The volcanic stone tooltip shown does not contain a numeric fire enchantment level.',
        'No purchases, upgrades or exchanges were performed by the agent.',
    ])
(OUT/'npc-menu-recovery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def link(n):return f'[снимок {n}]({sources[n-1]["evidencePath"]})'
trainer_table='\n'.join(f'| {r["name"]} | {r["observedLevel"]} / {r["displayedMaximum"]} | {r["description"]} | '+', '.join(f'{v} {k.lower()}' for k,v in r['nextUpgradeRequirements'].items())+' |' for r in trainer)
food_table='\n'.join(f'| {r["name"]} | {r["price"]} |' for r in food)
tool_table='\n'.join(f'| {r["name"]} | {r["price"]} |' for r in tools)
exchange_table='\n'.join(f'| {r["name"]} | {r["cost"]} |' for r in exchanges)
report=f'''# Prison Classic: тренер, еда, инструменты и обменники

19 октября 2026 года. Ручная транскрипция десяти присланных игровых снимков. Вариант под-сервера Classic не установлен. Покупки и улучшения агентом не выполнялись.

## Тренер

Источник: {link(1)}. Все три направления показаны на **0 / 20**. Требования относятся только к следующему улучшению из этого состояния.

| Направление | Уровень / отображаемый предел | Описание | Требования первого улучшения |
| --- | --- | --- | --- |
{trainer_table}

Строка «Убийства» оставлена с названием интерфейса: её точная трактовка как PvP в данном снимке не раскрыта. Снимок не даёт процента уклонения, прибавки урона или коэффициента замедления нужд, а также цен уровней 2–20.

## Продавец еды

Источник: {link(2)}. Названия определены по иконкам; подсказки с ID предметов не показаны. Цена записана так, как отображена для предложения, без предположения о размере выдаваемой стопки.

| Иконка предмета | Цена, игровые деньги |
| --- | ---: |
{food_table}

## Продавец предметов

Источник: {link(10)}. Названия также определены по иконкам.

| Иконка предмета | Цена, игровые деньги |
| --- | ---: |
{tool_table}

Цена покупки деревянной кирки **22.5** отделена от цены первого улучшения **25**. Сумма переходов кирки 1 → 16 составляет **54,949**; если учитывать одно показанное предложение начальной кирки, арифметически получается **54,971.5**, без непоказанных скидок или других расходов.

## Обменник звёзд

Общий экран цен: {link(9)}. Названия и назначение подтверждены подсказками {link(6)}, {link(7)}, {link(8)}.

| Предмет | Стоимость в звёздах |
| --- | ---: |
{exchange_table}

Оба ключа предназначены для Древнего кейса на Спавне. Подсказка Развеивателя описывает снятие древних зачарований и прямо предупреждает: **книга не возвращается**. Снимки не устанавливают результат открытия кейса, вероятности или размер стопки при обмене.

## Обменник шардов

На {link(3)} показаны два обмена по **4** исходных предмета. Имена ингредиентов уточняются ранее восстановленной локализацией; на этом экране видны их иконки.

- **4 лунных стали → Лунное лезвие.** Подсказка {link(4)}: меняет облик топора и повышает Эффективность до **IV**; применять можно только к предмету максимального уровня.
- **4 огненных осколка → Вулканический камень.** Подсказка {link(5)}: меч поджигает того, кому им нанесён урон; применять можно только к предмету максимального уровня. Число «II» на этой конкретной подсказке не показано; ранее оно было найдено в локализации.

Это усиления топора/меча; по ним нельзя назначать Эффективность IV кирке из предыдущей серии.

## Данные и оставшиеся пробелы

[JSON с точными полями и источниками]({(OUT/'npc-menu-recovery.json').as_posix()}). Сохранённые фрагменты содержат только игровые меню; у оригиналов и фрагментов записаны SHA-256.

Нужны последующие уровни тренера, цены продажи добычи, состав и таймеры каждой шахты, остальные инструменты и броня. Название направления и его предел ещё не дают числовой формулы эффекта.
'''
(ROOT/'NPC-MENU-RECOVERY.md').write_text(report,encoding='utf-8')
assert len(sources)==10 and len(trainer)==3 and len(food)==3 and len(tools)==4
assert [r['cost'] for r in exchanges]==[10,60,15]
assert all(r['displayedMaximum']==20 for r in trainer)
for source in sources:assert sha(Path(source['evidencePath']))==source['evidenceSha256']
for target in re.findall(r'\]\((C:/[^)]+)\)',report):assert Path(target).exists(),target
validation=dict(screenshots=10,trainerFirstUpgrades=3,trainerDisplayedMaximum=20,
    foodOffers=3,toolOffers=4,starOffers=3,shardRecipes=2,
    evidenceHashesVerified=True,manualTranscription=True)
(OUT/'npc-recovery-validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation,ensure_ascii=False,indent=2))
