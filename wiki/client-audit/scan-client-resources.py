"""Look for Prison configuration in non-class resources of the 36 copied archives."""
from pathlib import Path
import collections
import hashlib
import json
import re
import sys
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path(__file__).parent
inventory=json.loads((ROOT/'full-decompilation/input-inventory.json').read_text(encoding='utf-8'))
extensions={'.json','.yml','.yaml','.toml','.properties','.cfg','.conf','.ini','.lang','.txt','.xml','.csv'}
pattern=re.compile(r'prison(?:\.classic|:addinfos)|mine_\d+|Лесопилка|Лунный топор|armored_too_low|armorer|level.?requirements',re.I)
stats=collections.Counter()
hits=[]
skipped=[]
for module in inventory:
    path=Path(module['input'])
    if not zipfile.is_zipfile(path):
        skipped.append(dict(archive=module['id'],reason='not ZIP'))
        continue
    stats['archives']+=1
    with zipfile.ZipFile(path) as z:
        for info in z.infolist():
            if info.is_dir() or info.filename.endswith('.class'):
                continue
            stats['nonClassResources']+=1
            if Path(info.filename).suffix.lower() not in extensions:
                continue
            if info.file_size>4*1024*1024:
                skipped.append(dict(archive=module['id'],entry=info.filename,bytes=info.file_size,reason='text size > 4 MiB'))
                continue
            raw=z.read(info)
            try:text=raw.decode('utf-8-sig')
            except UnicodeDecodeError:
                skipped.append(dict(archive=module['id'],entry=info.filename,reason='not UTF-8'))
                continue
            stats['textResourcesScanned']+=1
            matches=[dict(line=n,text=s[:700]) for n,s in enumerate(text.splitlines(),1) if pattern.search(s)]
            if matches or pattern.search(info.filename):
                hits.append(dict(archive=module['id'],entry=info.filename,sha256=hashlib.sha256(raw).hexdigest(),matches=matches))
result=dict(stats=dict(stats),pattern=pattern.pattern,hits=hits,skipped=skipped,
    limitation='Lexical scan of UTF-8 text resources under 4 MiB; absent matches do not exclude binary/obfuscated/generated data.')
(ROOT/'content-analysis/client-resource-scan.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps(dict(stats=dict(stats),matchingResources=len(hits),skipped=len(skipped),
    matches=[dict(archive=h['archive'],entry=h['entry'],lines=len(h['matches'])) for h in hits]),ensure_ascii=False,indent=2))
