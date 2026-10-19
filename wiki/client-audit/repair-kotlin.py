"""Use Java output for Kotlin classes the Kotlin-specific plugin could not recover."""
from pathlib import Path
import json
import os
import subprocess
import zipfile

ROOT=Path(__file__).parent
DEST=ROOT/'full-decompilation'
folder=DEST/'repairs/kotlin-java';folder.mkdir(exist_ok=True)
ident='libraries-kotlin-stdlib-2.2.20'
source=DEST/'inputs'/(ident+'.jar');output=folder/'sources.zip'
args=[str(ROOT/'tools/temurin21/jdk-21.0.12.1+1-jre/bin/java.exe'),'-Xmx768m','-XX:ActiveProcessorCount=2','-jar',str(ROOT/'tools/vineflower-1.12.0.jar'),
      '--file','--thread-count=1','--log-level=WARN','--kt-enable=false','--decompile-inner=false','--remove-synthetic=false','--remove-bridge=false',
      '--skip-extra-files=true',str(source),str(output)]
with (folder/'vineflower.log').open('w') as stream:
    proc=subprocess.run(args,stdout=stream,stderr=subprocess.STDOUT,timeout=120,creationflags=subprocess.CREATE_NO_WINDOW|subprocess.BELOW_NORMAL_PRIORITY_CLASS)
coverage=json.loads((DEST/'coverage.json').read_text(encoding='utf-8'))
item=next(a for a in coverage['archives'] if a['id']==ident)
target=DEST/'sources'/(ident+'-sources.zip');temp=folder/'merged.zip';results=[];additions={};removed=set()
with zipfile.ZipFile(output) as java:
    for error in item['methodErrorFiles']:
        old=error['file'];name=old[:-3]+'.java';raw=java.read(name)
        markers=[s for s in [b"$VF: Couldn't be decompiled",b'$VF: Exception',b'Could not decompile'] if s in raw]
        record={'original':old,'replacement':name,'hasErrorMarkers':bool(markers)};results.append(record)
        if not markers:additions[name]=raw;removed.add(old)
with zipfile.ZipFile(target) as before,zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as after:
    for name in before.namelist():
        if name not in removed:after.writestr(name,before.read(name))
    for name,data in additions.items():after.writestr(name,data)
os.replace(temp,target)
(folder/'results.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'exitCode':proc.returncode,'replaced':len(additions),'unresolved':[r for r in results if r['hasErrorMarkers']]},indent=2))
