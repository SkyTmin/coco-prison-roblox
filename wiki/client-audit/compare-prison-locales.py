"""Compare preserved RU/EN Prison keys without treating a translation as server config."""
from pathlib import Path
import hashlib
import json
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
paths={lang:ROOT/f'decoded/{lang}-prison.json' for lang in ('ru_RU','en_US')}
data={lang:json.loads(p.read_text(encoding='utf-8'))['properties'] for lang,p in paths.items()}
ru,en=data['ru_RU'],data['en_US']
en_only={k:v for k,v in en.items() if k not in ru}
ru_only={k:v for k,v in ru.items() if k not in en}
out=dict(sources={lang:dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for lang,p in paths.items()},
    counts=dict(ru=len(ru),en=len(en),common=len(ru.keys()&en.keys()),enOnly=len(en_only),ruOnly=len(ru_only)),
    enOnly=en_only,ruOnly=ru_only,limitation='Missing translation keys do not establish activity, chronology or server parameters.')
(ROOT/'content-analysis/prison-locale-comparison.json').write_text(json.dumps(out,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(out['counts'],ensure_ascii=False))
for k,v in en_only.items():print(k,'=',v)
