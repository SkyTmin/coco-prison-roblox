"""Resume static decompilation in bounded batches; never load game code into a JVM."""
import json
import os
from pathlib import Path
import subprocess
import sys
import time
import zipfile

sys.stdout.reconfigure(encoding='utf-8')
ROOT=Path('C:/Users/user/Documents/roblox-prison-research/client-audit')
DEST=ROOT/'full-decompilation'
JAVA=ROOT/'tools/temurin21/jdk-21.0.12.1+1-jre/bin/java.exe'
VF=ROOT/'tools/vineflower-1.12.0.jar'
REPAIR=DEST/'repairs'
REPAIR.mkdir(exist_ok=True)
inventory=json.loads((DEST/'input-inventory.json').read_text(encoding='utf-8'))

def run_vf(source,output,log):
    args=[str(JAVA),'-Xmx768m','-XX:ActiveProcessorCount=2','-Dfile.encoding=UTF-8','-jar',str(VF),
          '--file','--thread-count=1','--log-level=WARN','--decompile-inner=false',
          '--remove-synthetic=false','--remove-bridge=false','--skip-extra-files=true',
          '--sourcefile-comments=true','--dump-bytecode-on-error=true','--dump-exception-on-error=true',
          str(source),str(output)]
    start=time.monotonic()
    try:
        with log.open('w',encoding='utf-8') as stream:
            proc=subprocess.run(args,stdout=stream,stderr=subprocess.STDOUT,timeout=120,
                    creationflags=subprocess.CREATE_NO_WINDOW|subprocess.BELOW_NORMAL_PRIORITY_CLASS)
        status='completed' if proc.returncode==0 else 'failed'
        code=proc.returncode
    except subprocess.TimeoutExpired:
        status='timeout'; code=None
    return {'status':status,'exitCode':code,'seconds':round(time.monotonic()-start,1)}

def source_names(path):
    if not path.exists() or not zipfile.is_zipfile(path): return set()
    with zipfile.ZipFile(path) as arc:
        return {n for n in arc.namelist() if n.endswith(('.java','.kt'))}

def batch_archive(kind='fastutil'):
    item=next(i for i in inventory if ('fastutil' in i['id'] if kind=='fastutil' else i['id']=='minecraft'))
    if kind=='minecraft':item={**item,'input':str(DEST/'inputs/minecraft-reconstructed.jar')}
    folder=REPAIR/kind; folder.mkdir(exist_ok=True)
    records=[]
    # Group inner classes with their outer class before assigning batches.
    groups={}
    for entry in item['classes']:
        name=entry['name']; key=name.split('$')[0].removesuffix('.class')
        groups.setdefault(key,[]).append(name)
    batches=[]; current=[]
    for names in groups.values():
        if current and len(current)+len(names)>(192 if kind=='fastutil' else 128):
            batches.append(current);current=[]
        current.extend(names)
    if current: batches.append(current)
    with zipfile.ZipFile(item['input']) as original:
        for number,names in enumerate(batches):
            base=folder/f'batch-{number:03}'
            source=base.with_suffix('.jar'); output=base.with_suffix('.zip'); log=base.with_suffix('.log')
            expected={n[:-6]+'.java' for n in names}
            if expected.issubset(source_names(output)):
                result={'status':'already_completed','seconds':0}
            else:
                with zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as arc:
                    for name in names: arc.writestr(name,original.read(name))
                result=run_vf(source,output,log)
            actual=source_names(output)
            record={'batch':number,'inputClasses':len(names),'sources':len(actual),
                    'missing':[n for n in names if n[:-6]+'.java' not in actual],**result}
            records.append(record)
            (folder/'progress.json').write_text(json.dumps({'totalBatches':len(batches),'results':records},indent=2)+'\n',encoding='utf-8')
            print(json.dumps({'event':'batch',**{k:record[k] for k in ('batch','inputClasses','sources','status','seconds')},'total':len(batches)}),flush=True)
    merged=DEST/'sources'/(item['id']+'-sources.zip')
    temp=merged.with_suffix('.repaired.zip')
    seen=set()
    with zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as target:
        for number in range(len(batches)):
            part=folder/f'batch-{number:03}.zip'
            if not zipfile.is_zipfile(part):continue
            with zipfile.ZipFile(part) as source:
                for name in source.namelist():
                    if not name.endswith(('.java','.kt')):continue
                    if name in seen:raise ValueError('Duplicate '+name)
                    seen.add(name);target.writestr(name,source.read(name))
    os.replace(temp,merged)
    print(json.dumps({'event':'merged','inputClasses':item['classCount'],'sources':len(seen)}),flush=True)

if __name__=='__main__':
    batch_archive(sys.argv[1] if len(sys.argv)>1 else 'fastutil')
