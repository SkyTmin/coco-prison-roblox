"""Repair multi-release metadata omissions and selected Vineflower failures."""
from pathlib import Path
import importlib.util
import json
import os
import re
import subprocess
import zipfile

ROOT=Path(__file__).parent
spec=importlib.util.spec_from_file_location('repair',ROOT/'repair-decompilation.py')
repair=importlib.util.module_from_spec(spec);spec.loader.exec_module(repair)
DEST=ROOT/'full-decompilation'
records=[]

def merge(archive, additions):
    temp=archive.with_suffix('.repairing.zip')
    with zipfile.ZipFile(archive) as before,zipfile.ZipFile(temp,'w',zipfile.ZIP_DEFLATED) as after:
        for name in before.namelist():
            if name not in additions:after.writestr(name,before.read(name))
        for name,data in additions.items():after.writestr(name,data)
    os.replace(temp,archive)

metadata=DEST/'repairs/metadata';metadata.mkdir(exist_ok=True)
for item in repair.inventory:
    entries=[c['name'] for c in item['classes'] if c['name'].startswith('META-INF/versions/')]
    if not entries:continue
    # Separate versions so a root class never replaces a version-specific variant.
    versions=sorted({n.split('/')[2] for n in entries})
    for version in versions:
        names=[n for n in entries if n.split('/')[2]==version]
        ident=item['id']+'-v'+version
        source=metadata/(ident+'.jar');output=metadata/(ident+'.zip');log=metadata/(ident+'.log')
        with zipfile.ZipFile(item['input']) as original,zipfile.ZipFile(source,'w',zipfile.ZIP_DEFLATED) as extracted:
            for name in names:extracted.writestr('/'.join(name.split('/')[3:]),original.read(name))
        result=repair.run_vf(source,output,log)
        additions={}
        if zipfile.is_zipfile(output):
            with zipfile.ZipFile(output) as arc:
                additions={f'META-INF/versions/{version}/'+n:arc.read(n) for n in arc.namelist() if n.endswith(('.java','.kt'))}
        target=DEST/'sources'/(item['id']+'-sources.zip')
        if additions:merge(target,additions)
        records.append({'kind':'multi_release','archive':item['id'],'version':version,'classes':len(names),'sources':len(additions),**result})
        print(json.dumps(records[-1]),flush=True)

fallback=DEST/'repairs/cfr-fallback';fallback.mkdir(exist_ok=True)
progress=json.loads((DEST/'progress.json').read_text(encoding='utf-8'))
for item in repair.inventory:
    previous=next(x for x in progress['results'] if x['id']==item['id'])
    for number,source_name in enumerate(previous.get('errorMarkers',[])):
        folder=fallback/(item['id']+'-'+str(number));folder.mkdir(exist_ok=True)
        class_name=source_name[:-5]+'.class'
        input_file=folder/Path(class_name).name
        with zipfile.ZipFile(item['input']) as arc:input_file.write_bytes(arc.read(class_name))
        args=[str(repair.JAVA),'-Xmx512m','-XX:ActiveProcessorCount=2','-Dfile.encoding=UTF-8','-jar',str(ROOT/'tools/cfr-0.152.jar'),str(input_file),
              '--outputdir',str(folder/'source'),'--silent','true','--innerclasses','false','--caseinsensitivefs','true']
        with (folder/'cfr.log').open('w',encoding='utf-8') as stream:
            try:
                proc=subprocess.run(args,stdout=stream,stderr=subprocess.STDOUT,timeout=120,
                      creationflags=subprocess.CREATE_NO_WINDOW|subprocess.BELOW_NORMAL_PRIORITY_CLASS)
                status='completed' if proc.returncode==0 else 'failed'
            except subprocess.TimeoutExpired:status='timeout'
        files=list((folder/'source').rglob('*.java')) if (folder/'source').exists() else []
        expected=next((f for f in files if f.name==Path(source_name).name),None)
        markers=[]
        if expected:
            text=expected.read_text(encoding='utf-8')
            markers=re.findall(r'(?im)^.*(?:could not decompile|unable to fully structure|decompilation failed|Exception decompiling|method analysis failed).*$',text)
            if not markers:
                target=DEST/'sources'/(item['id']+'-sources.zip')
                with zipfile.ZipFile(target) as before:(folder/'vineflower-original.java.txt').write_bytes(before.read(source_name))
                merge(target,{source_name:expected.read_bytes()})
        records.append({'kind':'cfr_fallback','archive':item['id'],'class':class_name,'status':status,'outputFound':expected is not None,'errorLines':markers,'replaced':expected is not None and not markers})
        print(json.dumps(records[-1]),flush=True)
(DEST/'repairs/misc-results.json').write_text(json.dumps(records,indent=2)+'\n',encoding='utf-8')
