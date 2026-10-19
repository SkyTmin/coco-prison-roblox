"""Trace every Wada registration through its lambda and record buffer operations."""
from pathlib import Path
import collections
import json
import re
import sqlite3

ROOT=Path(__file__).parent/'code-analysis'
db=sqlite3.connect(ROOT/'code-index.sqlite');db.row_factory=sqlite3.Row
modules=json.loads((ROOT/'wada-modules.json').read_text(encoding='utf-8'))
readers={'g':'i8','f':'bool','k':'uuid_2xi64','h':'utf8_varint_length','q':'optional_utf8','b':'i32','n':'varint','c':'i64','d':'f32','e':'f64','p':'is_readable','i':'color_i32','m':'vec3_f64','o':'vec3_f64','a':'typed_or_optional','s':'optional_color','t':'optional_vec3','v':'ByteBuf','r':'optional_uuid','l':'GameProfile','u':'optional_GameProfile','j':'remaining_utf8'}
records=[]
def outgoing(owner,method):
    return db.execute('''SELECT call.* FROM calls call JOIN methods m ON m.id=call.caller JOIN classes c ON c.id=m.class_id
      WHERE c.archive='addon-wada' AND c.name=? AND m.name=? ORDER BY call.pc''',(owner,method)).fetchall()

for module in modules:
    for registration in module['handlerRegistrations']:
        match=re.search(r'::([A-Za-z_$0-9]+)',registration['code'])
        wrapper=match[1] if match else None
        endpoints=[]
        if wrapper:
            endpoints=[r for r in outgoing(module['class'],wrapper) if r['owner']==module['class'] and r['name']!=wrapper]
        record={'module':module['name'],'owner':module['class'],'channel':('w4:' if registration['registrationMethod']=='a' else 'w2:')+registration['channelSuffix'],
                'registrationLine':registration['line'],'source':module['source'],'lambdaWrapper':wrapper,'handlers':[]}
        for endpoint in endpoints:
            ops=[]
            for call in outgoing(endpoint['owner'],endpoint['name']):
                if call['owner']=='gg/cristalix/a/l/a':
                    ops.append({'pc':call['pc'],'reader':call['name'],'descriptor':call['descriptor'],'kind':readers.get(call['name'],'unknown')})
            record['handlers'].append({'owner':endpoint['owner'],'method':endpoint['name'],'descriptor':endpoint['descriptor'],
                                       'bufferOperationsInBytecodeOrder':ops})
        records.append(record)
(ROOT/'wada-handler-map.json').write_text(json.dumps(records,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'registrations':len(records),'distinctChannels':len({r['channel'] for r in records}),
       'resolvedToHandler':sum(bool(r['handlers']) for r in records),
       'unresolved':[{k:r[k] for k in ['module','channel','lambdaWrapper']} for r in records if not r['handlers']][:20]},indent=2))
