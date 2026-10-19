"""Read/query the static index; record deep-review excerpts separately from scans."""
from pathlib import Path
import argparse
import datetime
import json
import re
import sqlite3
import sys

ROOT=Path(__file__).parent/'code-analysis'
DB=sqlite3.connect(ROOT/'code-index.sqlite');DB.row_factory=sqlite3.Row
sys.stdout.reconfigure(encoding='utf-8')
p=argparse.ArgumentParser();p.add_argument('mode',choices=['show','find','calls','callers','literals','fields'])
p.add_argument('query');p.add_argument('--archive');p.add_argument('--start',type=int,default=1);p.add_argument('--end',type=int);p.add_argument('--limit',type=int,default=35);p.add_argument('--name')
a=p.parse_args()
if a.mode=='show':
    sql='SELECT * FROM sources WHERE entry=?';params=[a.query]
    if a.archive:sql+=' AND archive=?';params.append(a.archive)
    rows=DB.execute(sql,params).fetchall()
    for r in rows:
        print(f"SOURCE {r['archive']} {r['entry']} {r['path']} ({r['lines']} lines)")
        lines=r['text'].splitlines();end=a.end or len(lines)
        for number,line in enumerate(lines[a.start-1:end],a.start):print(f'{number:5}: {line}')
        record={'archive':r['archive'],'entry':r['entry'],'source':r['path'],'sha256':r['sha256'],'start':a.start,'end':min(end,len(lines)),'activity':'source_excerpt_requested_for_review','utc':datetime.datetime.now(datetime.timezone.utc).isoformat()}
        with (ROOT/'reviewed-excerpts.jsonl').open('a',encoding='utf-8') as stream:stream.write(json.dumps(record,ensure_ascii=False)+'\n')
elif a.mode=='find':
    pattern=re.compile(a.query,re.I)
    sql='SELECT archive,entry,path,text FROM sources';params=[]
    if a.archive:sql+=' WHERE archive=?';params.append(a.archive)
    count=0
    for r in DB.execute(sql,params):
        hits=[(n,s) for n,s in enumerate(r['text'].splitlines(),1) if pattern.search(s)]
        if hits:
            count+=1
            if count<=a.limit:
                print(json.dumps({'archive':r['archive'],'entry':r['entry'],'path':r['path'],'hits':hits[:8]},ensure_ascii=False))
    print('matching_files',count)
elif a.mode=='literals':
    pattern=re.compile(a.query,re.I);count=0
    sql='''SELECT c.archive,c.name AS owner,m.name,m.descriptor,l.pc,l.value FROM literals l JOIN methods m ON m.id=l.method JOIN classes c ON c.id=m.class_id'''
    for r in DB.execute(sql):
        if a.archive and r['archive']!=a.archive:continue
        if pattern.search(r['value']):
            count+=1
            if count<=a.limit:print(json.dumps(dict(r),ensure_ascii=False))
    print('matching_literals',count)
elif a.mode in ('calls','callers'):
    sql='''SELECT c.archive,c.name AS caller_owner,m.name AS caller_name,m.descriptor AS caller_descriptor,call.pc,call.opcode,call.owner,call.name,call.descriptor,call.kind
           FROM calls call JOIN methods m ON m.id=call.caller JOIN classes c ON c.id=m.class_id WHERE '''
    sql+='call.owner=?' if a.mode=='callers' else 'c.name=?'
    params=[a.query]
    if a.name:sql+=' AND '+('call.name' if a.mode=='callers' else 'm.name')+'=?';params.append(a.name)
    if a.archive:sql+=' AND c.archive=?';params.append(a.archive)
    rows=DB.execute(sql,params).fetchall()
    for r in rows[:a.limit]:print(json.dumps(dict(r),ensure_ascii=False))
    print('matching_calls',len(rows))
elif a.mode=='fields':
    sql='''SELECT c.archive,c.name AS caller_owner,m.name AS caller_name,f.pc,f.opcode,f.owner,f.name,f.descriptor FROM field_uses f JOIN methods m ON m.id=f.method JOIN classes c ON c.id=m.class_id WHERE f.owner=?'''
    params=[a.query]
    if a.name:sql+=' AND f.name=?';params.append(a.name)
    rows=DB.execute(sql,params).fetchall()
    for r in rows[:a.limit]:print(json.dumps(dict(r),ensure_ascii=False))
    print('matching_field_uses',len(rows))
