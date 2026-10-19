"""Manually transcribe the supplied pickaxe preview without inventing later tiers."""
from pathlib import Path
import hashlib
import json
import re
import sys

from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
EVIDENCE=OUT/'pickaxe-menu-evidence'
EVIDENCE.mkdir(parents=True,exist_ok=True)
TEMP=Path('C:/Users/user/AppData/Local/Temp')
FILES=[
    '86658091-d130-431b-aa6c-4dc5a37606bb',
    '263f533a-1ec1-4075-ad8d-651cec66471e',
    'c02217b0-4a38-4497-8714-2ecf6f378f66',
    '2d36e092-e9d4-4fd1-953e-a2ea010836ce',
    '0218620f-bcc7-4224-b988-d763b62477db',
    'a7653861-0c32-4b78-a733-2c5862b991fd',
    '6e3e415e-f267-4b08-a0aa-3a7bcbd6243f',
    '474def8a-e7b1-4529-9a8d-fe97fc164646',
    '5450755e-10ab-4e0b-8c96-5ad5841f737d',
    '413225db-dedb-4668-b333-b7ffc4c944f3',
    'bdfeb69f-5426-4af7-b80b-6128765e6e61',
    '7600f766-0e79-4ad0-add1-0fead257c5f3',
    'c4995ecc-2118-4569-8ef9-5a2a3412a740',
    'c2e9de9b-1414-4dd3-bae6-7faad3ca78e6',
    '4e3df248-1cfb-4351-941e-bbc6f21453aa',
    'a4feb0ce-fd4d-47eb-9ea4-2f92fb055831',
]
BOX=(612,300,1310,762)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
sources=[]
for number,suffix in enumerate(FILES,1):
    original=TEMP/f'codex-clipboard-{suffix}.png'
    preserved=EVIDENCE/f'pickaxe-{number:02d}.png'
    with Image.open(original) as im:
        dims=list(im.size)
        assert BOX[2]<=dims[0] and BOX[3]<=dims[1]
        im.crop(BOX).save(preserved)
    sources.append(dict(id=f'pickaxe_image_{number}',attachmentNumber=number,
        originalFilename=original.name,originalSha256=sha(original),
        originalDimensions=dims,cropBox=list(BOX),
        evidencePath=preserved.as_posix(),evidenceSha256=sha(preserved)))

# Each requirement stores only the number on the right of current / required.
# K-abbreviated requirements retain their original display precision.
RAW=[
    (1,25,'Деревянная кирка','Деревянная кирка',(0,1),{'Камень':'145','Каменный уголь':'5'}),
    (2,37,'Деревянная кирка','Деревянная кирка',(1,2),{'Камень':'285','Каменный уголь':'15'}),
    (3,47,'Деревянная кирка','Деревянная кирка',(2,3),{'Камень':'520','Каменный уголь':'75'}),
    (4,90,'Каменная кирка','Деревянная кирка',None,{'Камень':'1.05K','Каменный уголь':'150'}),
    (5,180,'Каменная кирка','Каменная кирка',(0,1),{'Камень':'1.5K','Каменный уголь':'250','Железная руда':'10'}),
    (6,270,'Каменная кирка','Каменная кирка',(1,2),{'Камень':'2K','Каменный уголь':'350','Железная руда':'25'}),
    (7,540,'Каменная кирка','Каменная кирка',(2,3),{'Камень':'3.25K','Каменный уголь':'500','Железная руда':'60'}),
    (8,830,'Железная кирка','Каменная кирка',None,{'Камень':'7.8K','Железная руда':'165'}),
    (9,1330,'Железная кирка','Железная кирка',(0,1),{'Камень':'10.7K','Железная руда':'335','Золотая руда':'165'}),
    (10,3000,'Железная кирка','Железная кирка',(1,2),{'Камень':'15.8K','Железная руда':'680','Золотая руда':'375'}),
    (11,6000,'Железная кирка','Железная кирка',(2,3),{'Камень':'23.2K','Железная руда':'1.01K','Золотая руда':'560'}),
    (12,7500,'Алмазная кирка','Железная кирка',None,{'Камень':'33.8K','Золотая руда':'1.12K'}),
    (13,9000,'Алмазная кирка','Алмазная кирка',(0,1),{'Камень':'49.7K','Золотая руда':'1.8K'}),
    (14,11200,'Алмазная кирка','Алмазная кирка',(1,2),{'Камень':'67.2K','Золотая руда':'2.7K'}),
    (15,14900,'Алмазная кирка','Алмазная кирка',(2,3),{'Камень':'93.1K','Золотая руда':'4.75K'}),
]
def quantity(text):
    if text.endswith('K'):
        return dict(display=text,exactValue=None,approximateValue=round(float(text[:-1])*1000),precision='abbreviated UI value')
    return dict(display=text,exactValue=int(text),approximateValue=None,precision='integer UI value')

transitions=[]
for level,cost,left,right,eff,requirements in RAW:
    transitions.append(dict(fromLevel=level,toLevel=level+1,
        cost=dict(currency='game money',display=f'{cost:,}',exactValue=cost),
        requirements={name:quantity(value) for name,value in requirements.items()},
        efficiencyChange=None if eff is None else dict(before=eff[0],after=eff[1]),
        leftPreview=dict(name=left,displayedLevel=level),
        rightUpgradeRow=dict(name=right,fromLevel=level,toLevel=level+1),
        labelMismatch=left!=right,evidence=[f'pickaxe_image_{level}']))

terminal=dict(displayedLevel=16,bottomLabel='Уровень 16',
    rightUpgradeRow='Алмазная кирка 16 → 16',displayedCost=14900,
    displayedRequirements={'Камень':quantity('93.1K'),'Золотая руда':quantity('4.75K')},
    evidence=['pickaxe_image_16'],
    interpretation='The supplied preview ends at 16 and repeats previous cost/requirements; not a transition to 17.',
    absoluteServerMaximum=None)
data=dict(recordedDate='2026-10-19',sourceType='user supplied in-game upgrade previews',
    item='Обычная кирка',realmVariant=None,sources=sources,transitions=transitions,
    terminalPreview=terminal,
    inferredTierLayout=[
        dict(material='Деревянная',levels=[1,2,3,4]),
        dict(material='Каменная',levels=[5,6,7,8]),
        dict(material='Железная',levels=[9,10,11,12]),
        dict(material='Алмазная',levels=[13,14,15,16]),
    ],
    tierLayoutStatus='Interpretation across adjacent previews; raw labels preserved because boundary screens disagree.',
    nominalTotalUpgradeMoney=sum(r['cost']['exactValue'] for r in transitions),
    totalMoneyScope='Sum of 15 displayed transition costs from 1 to 16; excludes initial purchase and any unshown modifiers.',
    caveats=[
        'Screenshots are previews, not evidence that upgrades were purchased or the player owns all shown levels.',
        'Requirements are displayed counters, not proven consumed inventory recipes.',
        'Do not sum all resource thresholds as a total required amount; counter/reset/spending semantics unverified.',
        'K values preserve display precision and are not exact recovered integers.',
        'On 4→5, 8→9 and 12→13 left/right material names disagree; efficiency change is absent on those screens.',
        'Efficiencies reset to a displayed before-value of 0 in the following previews, but no time-to-break or vanilla speed formula is established.',
        'No evidence for upgrade prices of other tools, armor or special pickaxes.',
    ])
(OUT/'pickaxe-upgrades-recovery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')

def req(row,name):return row['requirements'].get(name,{}).get('display','—')
def roman(n):return ['0','I','II','III'][n]
lines=[]
for row in transitions:
    e=row['efficiencyChange']
    effect=f'{roman(e["before"])} → {roman(e["after"])}' if e else 'Смена материала; строка отсутствует'
    p=sources[row['fromLevel']-1]['evidencePath']
    lines.append(f'| {row["fromLevel"]} → {row["toLevel"]} | {row["cost"]["exactValue"]:,} | {req(row,"Камень")} | {req(row,"Каменный уголь")} | {req(row,"Железная руда")} | {req(row,"Золотая руда")} | {effect} | [снимок]({p}) |')
table='\n'.join(lines)
report=f'''# Prison Classic: кирка, уровни 1–16

19 октября 2026 года. Восстановлено вручную из 16 присланных снимков предпросмотра улучшений. Это реальные значения интерфейса показанного сервера, а не извлечённый серверный код. Вариант Normal/Quick не установлен.

**Прочитаны все 15 показанных переходов 1 → 16: цена, требования и изменение «Эффективности».** Отдельно сохранён конечный экран 16-го уровня. Данные остальных инструментов и брони из этих снимков не следуют.

## Таблица улучшений

Требования — числа **справа** от `/`. Слева находятся текущие показатели игрока; они не скопированы в баланс. `—` означает, что строки требования на данном экране нет. `K` сохранено дословно: это сокращённая точность интерфейса.

| Переход | Деньги | Камень | Каменный уголь | Железная руда | Золотая руда | Эффективность / изменение | Источник |
| --- | ---: | ---: | ---: | ---: | ---: | --- | --- |
{table}

Сумма пятнадцати показанных денежных цен: **{data['nominalTotalUpgradeMoney']:,}**. Это арифметическая сумма цен 1 → 16, без начальной покупки и без непоказанных модификаторов. Складывать таким же образом требования по камню/рудам нельзя: ещё не установлено, являются ли они накопительными счётчиками и списываются ли при покупке.

## Материал и зачарование

Последовательность соседних предпросмотров согласуется с четырьмя ступенями:

| Интерпретация ступени | Уровни | Цикл Эффективности |
| --- | --- | --- |
| Деревянная | 1–4 | 0 → I → II → III |
| Каменная | 5–8 | 0 → I → II → III |
| Железная | 9–12 | 0 → I → II → III |
| Алмазная | 13–16 | 0 → I → II → III |

Это интерпретация последовательности интерфейса. На переходах **4 → 5, 8 → 9, 12 → 13** слева уже стоит подпись следующего материала, но номер уровня остаётся исходным, а справа сохраняется старое название. Например, 4 → 5: слева «Каменная кирка, уровень 4», справа «Деревянная кирка, 4 → 5». Сырые подписи обеих сторон сохранены в JSON; несогласованность интерфейса не скрыта.

На этих трёх переходах строка Эффективности отсутствует. Следующий экран показывает исходную Эффективность 0 и переход к I. Время разрушения блоков, точная скорость кирок и применение стандартной Minecraft-формулы этими снимками не доказаны.

## Экран 16-го уровня

На [последнем снимке]({sources[15]['evidencePath']}) нижняя подпись — **«Уровень 16»**, справа написано **16 → 16**. Слева повторяются цена 14,900 и требования 93.1K камня / 4.75K золотой руды с предыдущего перехода.

Это **не улучшение 16 → 17**. Повторная цена не добавлена к общей сумме. Предпросмотр в присланной серии заканчивается на 16; абсолютный максимум всех кирок на сервере не установлен.

## Что это сообщает о добыче

Для улучшения кирки проверяются четыре названных ресурса: камень, каменный уголь, железная руда и золотая руда. Они появляются в требованиях на разных этапах. Однако это не устанавливает состав, цены и распределение этих ресурсов по конкретным шахтам. Предметный уровень кирки также не равен уровню персонажа и порогу открытия локации.

## Проверяемые данные

- [Таблица, исходные подписи и ссылки на снимки]({(OUT/'pickaxe-upgrades-recovery.json').as_posix()}).
- [Восстановленные уровни шахт]({(ROOT/'MINE-RECOVERY.md').as_posix()}).

Сохранены только игровые меню без чата и других окон рабочего стола. Для каждого фрагмента записаны SHA-256 оригинала и сохранённого изображения.
'''
(ROOT/'PICKAXE-UPGRADES.md').write_text(report,encoding='utf-8')
assert [r['fromLevel'] for r in transitions]==list(range(1,16))
assert [r['toLevel'] for r in transitions]==list(range(2,17))
assert data['nominalTotalUpgradeMoney']==54949
assert [r['fromLevel'] for r in transitions if r['labelMismatch']]==[4,8,12]
assert sum(r['efficiencyChange'] is None for r in transitions)==3
for row in transitions:
    assert row['cost']['exactValue']>0
    assert len(row['requirements']) in (2,3)
    assert all(v['exactValue'] is None if v['display'].endswith('K') else v['exactValue'] is not None
               for v in row['requirements'].values())
for source in sources:
    assert sha(Path(source['evidencePath']))==source['evidenceSha256']
for target in re.findall(r'\]\((C:/[^)]+)\)',report):assert Path(target).exists(),target
validation=dict(screenshots=16,observedTransitions=15,terminalScreens=1,
    priceTotal=54949,labelMismatchScreens=3,exactIntegerPriceRows=15,
    blockRequirementsIncludeAbbreviatedValues=True,evidenceHashesVerified=True,
    manualTranscription=True,absoluteMaximumProven=False)
(OUT/'pickaxe-recovery-validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation,ensure_ascii=False,indent=2))
