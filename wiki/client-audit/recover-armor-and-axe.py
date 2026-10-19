"""Manual original-resolution transcription of the omitted armor and axe menus."""
from pathlib import Path
import hashlib
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
manifest = json.loads((OUT / 'missed-menu-sources.json').read_text(encoding='utf-8'))
sources = {s['inventoryIndex']: s for s in manifest['sources']}


def qty(display):
    if display is None:
        return None
    display = str(display)
    return dict(display=display, exactValue=None if display.endswith('K') else int(display),
        approximateValue=round(float(display[:-1])*1000) if display.endswith('K') else None)


names = {
    'helmet': ['Кожаный шлем', 'Койф', 'Железный шлем', 'Алмазный шлем'],
    'chestplate': ['Кожаная куртка', 'Кольчуга', 'Железный нагрудник', 'Алмазный нагрудник'],
    'leggings': ['Кожаные штаны', 'Кольчужные поножи', 'Железные поножи', 'Алмазные поножи'],
    'boots': ['Кожаные ботинки', 'Кольчужные ботинки', 'Железные ботинки', 'Алмазные ботинки'],
    'axe': ['Деревянный топор', 'Каменный топор', 'Железный топор', 'Алмазный топор'],
}
raw = {
    'helmet': dict(indices=list(range(3, 17)), terminal=17,
        prices=[20,34,60,150,225,325,550,970,1840,2600,3700,5550,6900,11500],
        thresholds=[5,10,20,35,60,100,175,335,820,'1.24K','1.8K','2.8K',None,None]),
    'chestplate': dict(indices=list(range(18, 28))+[29,30,32,33], terminal=34,
        prices=[25,40,60,150,225,325,550,1650,2250,3200,4950,5850,7400,14800],
        thresholds=[4,8,14,35,60,110,240,600,'1.05K','1.95K','3K','4.9K',None,None],
        repeatSources={9:[28],12:[31]}),
    'leggings': dict(indices=list(range(35, 49)), terminal=49,
        prices=[25,37,75,150,300,450,830,1880,3000,3100,4500,5250,6000,13400],
        thresholds=[3,7,15,27,45,75,160,405,720,'1.42K','2.55K','3.8K',None,None]),
    'boots': dict(indices=list(range(50, 64)), terminal=64,
        prices=[20,34,60,150,225,325,550,970,1840,2600,3700,5550,6900,11900],
        thresholds=[5,10,20,30,45,80,160,335,980,'1.35K','1.95K','2.85K',None,None]),
    'axe': dict(indices=list(range(65, 80)), terminal=80,
        prices=[2,5,10,20,40,80,160,240,480,1070,2900,3750,7500,9000,13400],
        thresholds=[25,50,100,200,400,800,'1.1K','1.9K','2.5K','4.2K','6.75K','11.2K','14.2K','18.8K','22.3K']),
}
items = {}
for item, r in raw.items():
    rows = []
    for level, (n, price, threshold) in enumerate(zip(r['indices'], r['prices'], r['thresholds']), 1):
        boundary = level in [4,8,12]
        right = names[item][(level-1)//4]
        left = names[item][level//4 if boundary else (level-1)//4]
        effect = None if boundary else dict(displayName='Эффективность' if item == 'axe' else 'Защита',
            before=(level-1)%4, after=(level-1)%4+1)
        ev = [n]+r.get('repeatSources', {}).get(level, [])
        rows.append(dict(fromLevel=level, toLevel=level+1, evidence=[sources[i]['id'] for i in ev],
            moneyCost=price, currencyDisplay='$', requiredCounter='Дерево' if item=='axe' else ('Крысы' if level<=12 else 'Оружейник'),
            counterThreshold=qty(threshold), armorerLevel=None if item=='axe' or level<=12 else (3 if level==13 else 5),
            displayedLeftName=left, displayedLeftLevel=level, displayedRightName=right,
            enchantmentChangeShown=effect, materialBoundary=boundary,
            requirementsSpentOnUpgrade=None, playerActuallyUpgraded=False))
    terminal = dict(evidence=[sources[r['terminal']]['id']], level=rows[-1]['toLevel'],
        display=f"{rows[-1]['toLevel']} → {rows[-1]['toLevel']}", repeatedPreviousCost=r['prices'][-1],
        repeatedPreviousRequirement=qty(r['thresholds'][-1]), repeatedArmorerLevel=5 if item!='axe' else None,
        countedAsAdditionalTransition=False)
    items[item] = dict(transitions=rows, terminalPreview=terminal,
        nominalTotalUpgradeMoney=sum(r['prices']), totalExcludesInitialPurchase=True,
        namesByObservedMaterial=names[item],
        highestShownLevel=rows[-1]['toLevel'], absoluteMaximumLevel=None)

data = dict(recordedDate='2026-10-20', sourceType='Manual reading of 78 supplied game screenshots omitted from the initial inventory',
    sourcesManifest='missed-menu-sources.json', sourceIds=[sources[n]['id'] for n in range(3,81)], items=items,
    caveats=[
        'Four armor categories each contain 14 shown transitions 1→15; axe contains 15 transitions 1→16.',
        'Protection and Efficiency are displayed enchantment levels, not recovered damage reduction/mining speed coefficients.',
        'At 4→5, 8→9 and 12→13 the left preview already names the next material while the right row retains the old material name; both raw labels are saved.',
        'The same chestplate 9→10 and 12→13 transitions appear twice; repeats are evidence, not extra purchases.',
        'Terminal 15→15 and 16→16 screens repeat previous costs/requirements; these values are not additional upgrade stages.',
        'K is abbreviated UI precision. Resource thresholds are not summed and their spending/reset semantics are unknown.',
        'The four armor menus show Armorer 3 at 13→14 and 5 at 14→15, replacing the rats row; no hidden rats threshold is invented.',
        'No numeric defense coefficient, durability, actual purchase or absolute server maximum is established by these previews.',
    ])
(OUT/'armor-and-axe-recovery.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')


def links(ids):
    byid={s['id']:s for s in manifest['sources']}
    return ', '.join(f"[{sid}]({byid[sid]['evidencePath']})" for sid in ids)


sections=[]
for item,title in [('helmet','Шлем'),('chestplate','Нагрудник'),('leggings','Поножи'),('boots','Ботинки'),('axe','Топор')]:
    group=items[item]
    table=[]
    for t in group['transitions']:
        requirement=(f"Оружейник {t['armorerLevel']}" if t['armorerLevel'] else f"{t['requiredCounter']}: {t['counterThreshold']['display']}")
        e=t['enchantmentChangeShown']
        effect=f"{e['displayName']} {e['before']} → {e['after']}" if e else 'Строка зачарования отсутствует; смена материала'
        table.append(f"| {t['fromLevel']} → {t['toLevel']} | {t['moneyCost']} | {requirement} | {effect} | {links(t['evidence'])} |")
    sections.append(f"## {title}\n\n"+
        'Материалы по подписям: '+ ' → '.join(group['namesByObservedMaterial'])+'.\n\n'+
        '| Переход | Цена, $ | Требование | Показанное изменение | Источник |\n| --- | ---: | --- | --- | --- |\n'+
        '\n'.join(table)+f"\n\nСумма показанных цен без начальной покупки: **{group['nominalTotalUpgradeMoney']:,} $**. Последний экран {links(group['terminalPreview']['evidence'])} показывает {group['terminalPreview']['display']}; повторная цена не прибавлена.\n")
report='''# Prison Classic: пропущенные таблицы брони и топора

20 октября 2026 года. Повторная проверка вложений выявила **78 кадров улучшений**, не вошедших в прежний реестр. Здесь вручную прочитаны **56 переходов брони** (четыре части по 1 → 15) и **15 переходов топора** (1 → 16). Прежнее заявление, что разобраны все присланные кадры, было ошибочным: проверка 127 учтённых файлов не проверяла полноту вложений.

'''+ '\n'.join(sections)+f'''
## Особенности интерфейса и точность

На смене материалов 4 → 5, 8 → 9 и 12 → 13 левый предпросмотр уже показывает новое название, сохраняя старый уровень; правая строка ещё подписана старым материалом. Это то же расхождение, которое было на ранее разобранных инструментах. Обе подписи сохранены в JSON.

«Защита» и «Эффективность» здесь — уровни показанного зачарования. Числовой эффект на урон или скорость кадрами не установлен. У алмазной брони последний переход 14 → 15 показывает **Защиту 1 → 2**, а не III. У топора 15 → 16 показана **Эффективность 2 → 3**.

Поздние переходы каждой части брони требуют **Оружейника 3 и 5**. Строки крыс на этих кадрах нет; скрытое требование не добавлено. Пороги крыс отличаются между частями брони: их нельзя копировать из одной таблицы в остальные. На топоре во всех переходах показан счётчик «Дерево».

Сокращения `K` сохранены как сокращения, без якобы точного целого. Счётчики требований не суммировались: накопительный характер и списание неизвестны. Повторные переходы нагрудника 9 → 10 и 12 → 13 учтены как два дополнительных свидетельства, не как новые ступени. Конечные экраны 15 → 15 / 16 → 16 не прибавляют улучшений и не устанавливают абсолютный предел всех версий сервера.

[Машинные таблицы]({(OUT/'armor-and-axe-recovery.json').as_posix()}) · [Источники и SHA-256]({(OUT/'missed-menu-sources.json').as_posix()})
'''
(ROOT/'ARMOR-AND-AXE-UPGRADES.md').write_text(report,encoding='utf-8')
assert sum(len(i['transitions']) for i in items.values())==71
assert len(data['sourceIds'])==78
assert all(len(items[k]['transitions'])==14 for k in ['helmet','chestplate','leggings','boots'])
assert items['helmet']['transitions'][7]['counterThreshold']['exactValue']==335
assert items['chestplate']['transitions'][-1]['moneyCost']==14800
assert items['boots']['transitions'][-1]['moneyCost']==11900
assert all(len(r['indices'])==len(r['prices'])==len(r['thresholds']) for r in raw.values())
for n in range(3,81):
    s=sources[n]
    assert hashlib.sha256(Path(s['evidencePath']).read_bytes()).hexdigest()==s['evidenceSha256']
validation=dict(screenshots=78, distinctUpgradeTransitions=71, armorTransitions=56, axeTransitions=15,
    terminalScreens=5, repeatedChestplateScreens=2, hashesMatched=True,
    totals={k:v['nominalTotalUpgradeMoney'] for k,v in items.items()})
(OUT/'armor-and-axe-validation.json').write_text(json.dumps(validation,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(validation,ensure_ascii=False,indent=2))
