"""Inspect the already downloaded official pack as data, without loading assets."""
from pathlib import Path
import hashlib
import json
import sys
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
path=ROOT.parent/'downloads/Cristalix-Prison-Classic-official-resourcepack.zip'
entries=[]
rules=[]
with zipfile.ZipFile(path) as z:
    for info in z.infolist():
        entries.append(dict(path=info.filename,bytes=info.file_size))
        if info.filename.endswith('.properties'):
            raw=z.read(info).decode('utf-8-sig',errors='replace')
            props={}
            for line in raw.splitlines():
                if '=' in line and not line.lstrip().startswith('#'):
                    key,value=line.split('=',1)
                    props[key.strip()]=value.strip()
            rules.append(dict(path=info.filename,properties=props,raw=raw))
out=ROOT/'content-analysis/resourcepack-index.json'
out.parent.mkdir(exist_ok=True)
out.write_text(json.dumps(dict(source=str(path),sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
    entries=entries,rules=rules,limitation='A texture-selection rule is not a server upgrade table.'),ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('entries',len(entries),'properties',len(rules))
for r in rules:
    print(json.dumps(r,ensure_ascii=False))
