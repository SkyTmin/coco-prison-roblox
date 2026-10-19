"""Static, local decompilation of every .class archive in the installed game.

Game code is supplied to Vineflower as input data, never executed.
Outputs are ZIP archives to preserve names differing only in case on Windows.
"""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path('C:/Users/user/Documents/roblox-prison-research/client-audit')
GAME = Path('C:/Users/user/.cristalix/updates/Minigames')
DEST = ROOT/'full-decompilation'
JAVA = ROOT/'tools/temurin21/jdk-21.0.12.1+1-jre/bin/java.exe'
TOOL = ROOT/'tools/vineflower-1.12.0.jar'
for folder in ('inputs','sources','logs'):
    (DEST/folder).mkdir(parents=True,exist_ok=True)

def save(name, data):
    target=DEST/name
    temp=target.with_suffix(target.suffix+'.tmp')
    temp.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    os.replace(temp,target)

specs=[
    ('addon-wada',ROOT/'decompiler-input/wada.jar'),
    ('minecraft',GAME/'minecraft.jar'),
    ('addon-gama',ROOT/'decompiler-input/gama.jar'),
    ('addon-socials',ROOT/'decompiler-input/socials.jar'),
]
for source in sorted([*GAME.glob('*.jar'),*(GAME/'libraries').rglob('*.jar')]):
    if source==GAME/'minecraft.jar':
        continue
    ident=source.relative_to(GAME).with_suffix('').as_posix().replace('/','-')
    specs.append((ident,source))

inventory=[]
for ident,source in specs:
    raw=source.read_bytes()
    with zipfile.ZipFile(source) as archive:
        classes=[{'name':entry.filename,'bytes':entry.file_size,'crc32':f'{entry.CRC:08x}'} for entry in archive.infolist() if entry.filename.endswith('.class')]
    copied=DEST/'inputs'/(ident+'.jar')
    copied.write_bytes(raw)
    inventory.append({'id':ident,'original':str(source),'input':str(copied),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest(),'classes':classes,'classCount':len(classes)})
save('input-inventory.json',inventory)
print(json.dumps({'event':'inventory','archives':len(inventory),'classes':sum(x['classCount'] for x in inventory)}),flush=True)

results=[]
save('progress.json',{'status':'running','current':None,'results':results})
for item in inventory:
    ident=item['id']
    if not item['classCount']:
        results.append({'id':ident,'status':'no_class_files','classCount':0})
        save('progress.json',{'status':'running','current':None,'results':results})
        continue
    output=DEST/'sources'/(ident+'-sources.zip')
    log=DEST/'logs'/(ident+'.log')
    args=[
        str(JAVA),'-Xmx1024m','-XX:ActiveProcessorCount=2','-Dfile.encoding=UTF-8',
        '-jar',str(TOOL),'--file','--thread-count=1','--log-level=WARN',
        '--decompile-inner=false','--remove-synthetic=false','--remove-bridge=false',
        '--skip-extra-files=true','--sourcefile-comments=true',
        '--dump-bytecode-on-error=true','--dump-exception-on-error=true',
        item['input'],str(output),
    ]
    save('progress.json',{'status':'running','current':ident,'results':results})
    print(json.dumps({'event':'start','archive':ident,'classes':item['classCount']}),flush=True)
    start=time.monotonic()
    timed_out=False
    with log.open('w',encoding='utf-8') as stream:
        try:
            proc=subprocess.run(args,stdout=stream,stderr=subprocess.STDOUT,timeout=900,
                creationflags=subprocess.CREATE_NO_WINDOW|subprocess.BELOW_NORMAL_PRIORITY_CLASS)
            exit_code=proc.returncode
        except subprocess.TimeoutExpired:
            timed_out=True
            exit_code=None
    result={'id':ident,'status':'timeout' if timed_out else 'completed' if exit_code==0 else 'failed',
        'exitCode':exit_code,'seconds':round(time.monotonic()-start,1),'classCount':item['classCount'],
        'output':str(output),'log':str(log),'javaCount':0,'kotlinCount':0,'missingClasses':[c['name'] for c in item['classes']],'errorMarkers':[]}
    if output.exists() and zipfile.is_zipfile(output):
        with zipfile.ZipFile(output) as archive:
            names=archive.namelist()
            java_names={name for name in names if name.endswith('.java')}
            kotlin_names={name for name in names if name.endswith('.kt')}
            result['javaCount']=len(java_names)
            result['kotlinCount']=len(kotlin_names)
            result['missingClasses']=[c['name'] for c in item['classes'] if c['name'][:-6]+'.java' not in java_names and c['name'][:-6]+'.kt' not in kotlin_names]
            for entry in java_names|kotlin_names:
                text=archive.read(entry).decode('utf-8',errors='replace')
                if "$VF: Couldn't be decompiled" in text or '$VF: Exception' in text or '$VF: Could not decompile' in text:
                    result['errorMarkers'].append(entry)
    result['missingCount']=len(result['missingClasses'])
    result['classesWithErrorMarkers']=len(result['errorMarkers'])
    results.append(result)
    save('progress.json',{'status':'running','current':None,'results':results})
    print(json.dumps({k:result[k] for k in ('id','status','classCount','javaCount','missingCount','classesWithErrorMarkers','seconds')}),flush=True)

save('progress.json',{'status':'finished','current':None,'results':results})
print(json.dumps({'event':'finished','archives':len(results),'inputClasses':sum(x['classCount'] for x in results),'javaFiles':sum(x.get('javaCount',0) for x in results),'missing':sum(x.get('missingCount',0) for x in results)}),flush=True)
