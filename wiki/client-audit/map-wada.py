"""Recover all named Wada modules and registration candidates from the code index."""
from pathlib import Path
import json
import re
import sqlite3

ROOT=Path(__file__).parent/'code-analysis'
db=sqlite3.connect(ROOT/'code-index.sqlite');db.row_factory=sqlite3.Row
registry=db.execute("SELECT * FROM sources WHERE archive='addon-wada' AND entry='gg/cristalix/wada/e/c.java'").fetchone()
modules=[]
for name,factory in re.findall(r'new b\("([^"]+)", c::([^\)]+)\)',registry['text']):
    constructors=db.execute('''SELECT call.owner FROM calls call JOIN methods m ON m.id=call.caller JOIN classes c ON c.id=m.class_id
      WHERE c.archive='addon-wada' AND c.name='gg/cristalix/wada/e/c' AND m.name=? AND call.name='<init>' ''',(factory,)).fetchall()
    if len(constructors)!=1:raise ValueError((name,factory,[dict(r) for r in constructors]))
    owner=constructors[0]['owner']
    source=db.execute("SELECT * FROM sources WHERE archive='addon-wada' AND entry=?",(owner+'.java',)).fetchone()
    candidates=[]
    for number,line in enumerate(source['text'].splitlines(),1):
        match=re.search(r'(?:this\.)?([ab])\("([^"\n]+)"\s*,\s*(.*)',line)
        if match and ('injectedLambda' in match[3] or '::' in match[3]):
            candidates.append({'line':number,'channelSuffix':match[2],'registrationMethod':match[1],'code':line.strip()})
    modules.append({'name':name,'factory':factory,'class':owner,'source':source['path'],'lines':source['lines'],'handlerRegistrations':candidates})
(ROOT/'wada-modules.json').write_text(json.dumps(modules,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
lines=['# Все зарегистрированные модули Wada','',
       'Наличие модуля означает возможность общего клиентского движка. Его загрузка именно в Prison Classic без пакета `load` не установлена. Имена обработчиков ниже извлечены из регистраций в исходниках; динамические имена и регистрация в дочерних объектах требуют отдельного просмотра.','',
       '| Модуль | Класс | Строки | Обработчики в основном классе |','| --- | --- | ---: | --- |']
for module in modules:
    channels=', '.join('`'+r['channelSuffix']+'`' for r in module['handlerRegistrations'])
    lines.append(f"| {module['name']} | [{module['class']}]({Path(module['source']).as_posix()}) | {module['lines']} | {channels} |")
(ROOT/'WADA-MODULES.md').write_text('\n'.join(lines)+'\n',encoding='utf-8')
print('modules',len(modules),'with_handlers',sum(bool(m['handlerRegistrations']) for m in modules))
for m in modules:
    if any(t in m['name'] for t in ['Tree','Skill','Talent','BattlePass','Health','Booster','Progress','DailyReward','Dialog','MenuManager','Hud','Structure']):
        print(json.dumps(m,ensure_ascii=False))
