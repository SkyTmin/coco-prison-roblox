"""Recover constructor names hidden by decompiler enum-field presentation.

Uses ordered ldc / enum constructor / putstatic evidence; never runs an enum.
"""
from pathlib import Path
import json
import sqlite3

ROOT=Path(__file__).parent/'code-analysis'
db=sqlite3.connect(ROOT/'code-index.sqlite');db.row_factory=sqlite3.Row
records=[]
for owner in db.execute("SELECT * FROM classes WHERE super='java/lang/Enum'").fetchall():
    initializer=db.execute("SELECT id FROM methods WHERE class_id=? AND name='<clinit>'",(owner['id'],)).fetchone()
    if not initializer:continue
    mid=initializer['id'];events=[]
    for r in db.execute('SELECT pc,value FROM literals WHERE method=?',(mid,)):events.append((r['pc'],'literal',dict(r)))
    for r in db.execute("SELECT pc,owner,name,descriptor FROM calls WHERE caller=? AND name='<init>' AND owner=?",(mid,owner['name'])):events.append((r['pc'],'constructor',dict(r)))
    for r in db.execute('SELECT pc,owner,name,descriptor FROM field_uses WHERE method=? AND opcode=179 AND owner=?',(mid,owner['name'])):events.append((r['pc'],'field',dict(r)))
    candidates=[];pending=None
    for pc,kind,data in sorted(events):
        if kind=='literal':candidates.append(data)
        elif kind=='constructor':pending=candidates[0] if candidates else None
        elif kind=='field' and data['descriptor']=='L'+owner['name']+';' and pending:
            records.append({'archive':owner['archive'],'class':owner['name'],'fieldAlias':data['name'],'runtimeEnumName':pending['value'],
                            'constructorNamePc':pending['pc'],'putStaticPc':pc})
            candidates=[];pending=None
(ROOT/'enum-aliases.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('enum_names',len(records),'enum_classes',len({(r['archive'],r['class']) for r in records}))
for r in records:
    if r['class'].startswith('gg/cristalix/wada/component/menu/h/a/') and r['archive']=='addon-wada':print(r)
