"""Index every Classic localization entry and query selected content groups."""
from pathlib import Path
import argparse
import collections
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
p=argparse.ArgumentParser()
p.add_argument('--shared',action='store_true')
p.add_argument('--match',default='')
p.add_argument('--family')
p.add_argument('--limit',type=int,default=150)
p.add_argument('--offset',type=int,default=0)
p.add_argument('--inventory',action='store_true')
a=p.parse_args()
PATH=ROOT/'decoded'/('ru_RU-prison.json' if a.shared else 'ru_RU-classic.json')
source_text=PATH.read_text(encoding='utf-8')
data=json.loads(source_text)['properties']
line_numbers={m[1]:n for n,s in enumerate(source_text.splitlines(),1) if (m:=re.match(r'\s*"([^"]+)"\s*:',s))}
if a.shared:
    data={k:v for k,v in data.items() if not k.startswith('prison.classic.')}
def clean(s):
    s=re.sub(r'[§&][0-9a-fk-or]', '', s, flags=re.I)
    s=re.sub(r'¨[0-9a-fA-F]{6}', '', s)
    return re.sub(r'[\ue000-\uf8ff]', '', s).replace('\\%','%').strip()
families=collections.Counter(k.split('.')[2] for k in data)
records=[]
for k,v in data.items():
    text=clean(v)
    records.append(dict(key=k,family=k.split('.')[2],text=text,raw=v,
                        sourceLine=line_numbers[k],
                        placeholders=re.findall(r'%(?:\d+\$)?[a-zA-Z]',text)))
out=ROOT/'content-analysis'
out.mkdir(exist_ok=True)
if a.inventory:
    payload=dict(source=str(PATH),sourceSha256=hashlib.sha256(PATH.read_bytes()).hexdigest(),
        sourceType='client_localization_not_server_execution',entries=len(data),
        families=dict(families.most_common()),records=records)
    (out/('other-prison-text-index.json' if a.shared else 'classic-content-index.json')).write_text(json.dumps(payload,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(dict(total=len(data),families=dict(families.most_common())),ensure_ascii=False,indent=2))
else:
    pat=re.compile(a.match,re.I)
    found=[r for r in records if (not a.family or r['family']==a.family) and pat.search(r['key']+' '+r['text'])]
    for r in found[a.offset:a.offset+a.limit]:print(r['key']+' = '+r['text'])
    print('MATCHES',len(found))
