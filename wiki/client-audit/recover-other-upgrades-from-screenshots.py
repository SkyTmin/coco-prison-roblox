"""Recover sword/shovel previews; preserve irregular thresholds and UI boundaries."""
from pathlib import Path
import hashlib
import json
import re
import sys
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
OUT=ROOT/'content-analysis'
EVIDENCE=OUT/'other-upgrade-evidence'
EVIDENCE.mkdir(parents=True,exist_ok=True)
TEMP=Path('C:/Users/user/AppData/Local/Temp')
SWORD_FILES=[
    '0726bcbc-4cf3-4dce-b540-ee7dbea5d4b5','af7287ab-806a-4eb3-8370-868acc24a5e0',
    'e843a25b-2be5-414f-ba94-2fca20848a49','d04878b6-0d0b-40c1-9d82-e309cea9e398',
    'c74fc810-da69-43db-86f2-12509cbf69cd','c02ad3b6-a49c-4552-b704-2a864670a05d',
    'b10e42ce-bcb1-4299-bffb-271d3f8f7d19','b469bf08-aada-47a2-97f1-a693481ba71e',
    '9f30a3ee-13fc-4ead-a860-0d9659134cad','661094c7-4c73-4c3b-b556-1b07dc7a2969',
    '0fa0d307-d170-496a-857e-9a534d7474f8','36e447c2-2469-42e6-af32-4dfe8a580bd8',
    'ff1a5d8f-b6dd-4d41-9d2a-7dfc5d9927fe','9f17311c-e5b4-43c7-80d7-a8d8b6f19bc2',
    'c32f5a86-ce8b-4fe6-9d79-fe7bb8e5f114',
]
SHOVEL_FILES=[
    '6567d824-c6e9-4573-8e2f-d5675a3b0bc5','2cfbddb6-5611-4be4-83a0-349fdeaa694b',
    'a2de420f-4ea4-49a8-bb48-d2681316223e','998b3960-4444-4f35-95a1-f480ccc37569',
    'a569b454-321e-44b3-bf6f-c2a27ae77316','b0122a76-0765-4f18-aab2-4d954609e017',
    '72c94225-f4f8-4076-916f-f344178e8b4d','def9b6c9-759c-4368-b504-ebbfb2a94a93',
    'a5c80eee-a0c1-4a04-91c3-b6552d0aa6cc','fe56c6c9-5e08-4461-b565-d4fd86d530f5',
    'd8cfc811-f0ab-4c09-9404-ccaa75fd33a9','7f6ef8a7-fddd-423c-b369-ca44679eb200',
    'ba4b72f5-8bdd-40ca-97ad-7335c958b457','d19dbfa8-48e6-4521-8040-b71dc9d864f3',
    '11454356-fd8e-4a08-9877-e7656eaff18a','e0ec809e-0fd6-46d7-9bd1-e4d17f8fd55c',
]
SWORD_RAW=[
    (10,'5',None),(20,'15',None),(40,'45',None),(80,'90',None),
    (110,'180',None),(140,'360',None),(200,'750',None),(520,'1.5K',None),
    (860,'2.8K',None),(1530,'4.9K',None),(2100,'6K',None),(5600,'9K',None),
    (7600,'10.9K',3),(13900,'13.8K',5),
]
SHOVEL_RAW=[
    (5,'20','15','15'),(10,'30','36','30'),(20,'60','65','75'),
    (40,'295','240','265'),(80,'530','590','480'),(110,'1.07K','960','1.17K'),
    (175,'1.67K','1.83K','1.5K'),(405,'2.4K','2.15K','2.6K'),
    (1330,'4.65K','4.2K','3.8K'),(1880,'4.95K','5.5K','6.05K'),
    (2600,'5.35K','6.6K','5.95K'),(3050,'8K','7.2K','8.8K'),
    (6700,'10.6K','8.65K','9.6K'),(7550,'10.1K','12.3K','11.2K'),
    (9250,'11.1K','12.3K','13.5K'),
]
BOX=(612,300,1310,762)
def sha(path):return hashlib.sha256(path.read_bytes()).hexdigest()
def quantity(text):
    if text.endswith('K'):
        return dict(display=text,exactValue=None,approximateValue=round(float(text[:-1])*1000),precision='abbreviated UI value')
    return dict(display=text,exactValue=int(text),approximateValue=None,precision='integer UI value')
def name(item,level):
    index=(level-1)//4
    return (['Деревянный меч','Каменный меч','Железный меч','Алмазный меч'] if item=='sword'
            else ['Деревянная лопата','Каменная лопата','Железная лопата','Алмазная лопата'])[index]

groups={}
sources=[]
for kind,files,raw,enchantment in [('sword',SWORD_FILES,SWORD_RAW,'Острота'),('shovel',SHOVEL_FILES,SHOVEL_RAW,'Эффективность')]:
    group_sources=[]
    for n,suffix in enumerate(files,1):
        original=TEMP/f'codex-clipboard-{suffix}.png'
        preserved=EVIDENCE/f'{kind}-{n:02d}.png'
        with Image.open(original) as im:
            dims=list(im.size)
            assert BOX[2]<=dims[0] and BOX[3]<=dims[1]
            im.crop(BOX).save(preserved)
        source=dict(id=f'{kind}_image_{n}',batch=kind,attachmentNumber=n,
            originalFilename=original.name,originalSha256=sha(original),
            originalDimensions=dims,cropBox=list(BOX),evidencePath=preserved.as_posix(),evidenceSha256=sha(preserved))
        group_sources.append(source);sources.append(source)
    transitions=[]
    for level,row in enumerate(raw,1):
        requirements={'Крысы':quantity(row[1])} if kind=='sword' else {
            k:quantity(v) for k,v in zip(('Гравий','Песок','Земля'),row[1:])}
        if kind=='sword' and row[2] is not None:requirements['Оружейник']=quantity(str(row[2]))
        efficiency=None if level in (4,8,12) else dict(before=(level-1)%4,after=level%4)
        transitions.append(dict(fromLevel=level,toLevel=level+1,cost=dict(currency='game money',exactValue=row[0]),
            requirements=requirements,enchantmentChange=None if efficiency is None else dict(name=enchantment,**efficiency),
            leftPreview=dict(name=name(kind,level+1),displayedLevel=level),
            rightUpgradeRow=dict(name=name(kind,level),fromLevel=level,toLevel=level+1),
            labelMismatch=level in (4,8,12),evidence=[f'{kind}_image_{level}']))
    last_level=len(files)
    groups[kind]=dict(transitions=transitions,
        terminalPreview=dict(displayedLevel=last_level,bottomLabel=f'Уровень {last_level}',
            rightUpgradeRow=f'{name(kind,last_level)} {last_level} → {last_level}',
            displayedCost=raw[-1][0],displayedRequirements=transitions[-1]['requirements'],
            evidence=[f'{kind}_image_{last_level}'],absoluteServerMaximum=None),
        nominalTotalUpgradeMoney=sum(r['cost']['exactValue'] for r in transitions))

data=dict(recordedDate='2026-10-19',sourceType='user supplied in-game upgrade previews',realmVariant=None,
    sources=sources,**groups,caveats=[
        'Previews do not prove purchases, ownership, counter spending or reset rules.',
        'K requirements retain their abbreviated precision; exact integer thresholds are unknown.',
        'On material boundaries left/right names disagree; both are preserved.',
        'Final 15→15 / 16→16 screens repeat previous data and are not extra upgrades.',
        'Damage per hit, break speeds, formulas and absolute server-wide maximums remain unknown.',
        'Do not replace irregular shovel thresholds with a monotonic formula.',
    ])
(OUT/'other-upgrades-recovery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
def source_path(kind,n):return next(s['evidencePath'] for s in sources if s['id']==f'{kind}_image_{n}')
def req(row,key):return row['requirements'].get(key,{}).get('display','—')
def effect(row):
    e=row['enchantmentChange']
    roman=['0','I','II','III']
    return f'{roman[e["before"]]} → {roman[e["after"]]}' if e else 'Строка отсутствует; смена материала'
def table(kind,columns):
    lines=['| Переход | Деньги | '+' | '.join(columns)+' | Зачарование | Источник |',
           '| --- | ---: | '+' | '.join('---:' for _ in columns)+' | --- | --- |']
    for r in groups[kind]['transitions']:
        cells=' | '.join(req(r,k) for k in columns)
        p=source_path(kind,r['fromLevel'])
        lines.append(f'| {r["fromLevel"]} → {r["toLevel"]} | {r["cost"]["exactValue"]:,} | {cells} | {effect(r)} | [снимок]({p}) |')
    return '\n'.join(lines)
report=f'''# Prison Classic: меч и лопата, таблицы улучшений

19 октября 2026 года. Вручную прочитан 31 присланный снимок: 15 для меча и 16 для лопаты. Восстановлены **14 переходов меча 1 → 15** и **15 переходов лопаты 1 → 16**. Последний экран каждой серии отдельно сохранён как конечный предпросмотр, без фиктивного следующего улучшения.

Числа требований взяты справа от `/`, текущие показатели игрока в баланс не перенесены. `K` сохранено дословно; точное целое сокращённого числа не установлено. `—` означает отсутствие строки на экране. Вариант под-сервера Classic не установлен.

## Меч

Зачарование в таблице — **Острота**.

{table('sword',['Крысы','Оружейник'])}

Сумма показанных денежных цен: **{groups['sword']['nominalTotalUpgradeMoney']:,}**. Начальная покупка меча сюда не включена: её цена не показана в этой серии.

На переходе **13 → 14** нужен **Оружейник 3**, на **14 → 15** — **Оружейник 5**. Это отдельное условие навыка: его нельзя подменять уровнем персонажа или самого меча.

По последовательности соседних экранов материал согласуется со ступенями: деревянный 1–4, каменный 5–8, железный 9–12, алмазный 13–15. На границах 4 → 5, 8 → 9, 12 → 13 подписи слева и справа расходятся так же, как у кирки; обе версии сохранены в JSON. У алмазного меча в этой серии показаны переходы Остроты **0 → I → II**. Острота III алмазного меча на присланных экранах не показана.

На [последнем экране меча]({source_path('sword',15)}) подпись «Уровень 15» и строка **15 → 15** с повтором цены/требований предыдущего перехода. Это не переход на уровень 16 и не доказательство общего максимума всех мечей сервера.

## Лопата

Зачарование в таблице — **Эффективность**.

{table('shovel',['Гравий','Песок','Земля'])}

Сумма показанных денежных цен: **{groups['shovel']['nominalTotalUpgradeMoney']:,}**. Прибавление предложения начальной деревянной лопаты за 4 даёт арифметически **33,209**, без непоказанных модификаторов.

В таблице сохранены немонотонные требования: например, земля **6.05K** на 10 → 11, но **5.95K** на 11 → 12; гравий **10.6K** на 13 → 14, но **10.1K** на 14 → 15. Эти значения не исправлялись и не заменялись формулой. На переходе 2 → 3 песок указан как **36**.

По соседним предпросмотрам материал согласуется со ступенями: деревянная 1–4, каменная 5–8, железная 9–12, алмазная 13–16. Внутри каждого материала показан цикл Эффективности 0 → I → II → III. На границах материалов строка зачарования не показана; исходное 0 читается на следующем экране.

На [последнем экране лопаты]({source_path('shovel',16)}) подпись «Уровень 16» и строка **16 → 16** с повтором данных предыдущего перехода. Повтор не включён в сумму.

## Что пока не установлено

Требования к крысам/блокам показаны как счётчики. Снимки не доказывают, что это расходуемые предметы, что статистика сбрасывается при улучшении или что пороги всех переходов нужно складывать. Суммированы только денежные цены.

Не восстановлены точный урон, скорость разрушения блоков, эффекты древних книг, параметры других типов оружия, броня и абсолютные пределы предметов. Число уровней меча не скопировано с кирки/лопаты.

[JSON с требованиями, ценами, исходными подписями и источниками]({(OUT/'other-upgrades-recovery.json').as_posix()}). Сохранены игровые меню; у каждого оригинала и фрагмента записан SHA-256.
'''
(ROOT/'SWORD-AND-SHOVEL-UPGRADES.md').write_text(report,encoding='utf-8')
assert groups['sword']['nominalTotalUpgradeMoney']==32710
assert groups['shovel']['nominalTotalUpgradeMoney']==33205
assert len(groups['sword']['transitions'])==14 and len(groups['shovel']['transitions'])==15
for group in groups.values():
    assert all(r['toLevel']==r['fromLevel']+1 for r in group['transitions'])
    assert [r['fromLevel'] for r in group['transitions'] if r['labelMismatch']]==[4,8,12]
for source in sources:assert sha(Path(source['evidencePath']))==source['evidenceSha256']
for target in re.findall(r'\]\((C:/[^)]+)\)',report):assert Path(target).exists(),target
validation=dict(screenshots=len(sources),swordTransitions=14,shovelTransitions=15,
    swordMoneySum=32710,shovelMoneySum=33205,terminalScreens=2,
    evidenceHashesVerified=True,manualTranscription=True,
    nonMonotonicShovelRequirementsPreserved=True,absoluteMaximumsProven=False)
(OUT/'other-upgrades-validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation,ensure_ascii=False,indent=2))
