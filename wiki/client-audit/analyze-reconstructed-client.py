"""Search only static client constants and preserve the evidence with class names."""
from pathlib import Path
import json
import re
import struct
import zipfile

ROOT=Path(__file__).parent
SIZES={3:4,4:4,5:8,6:8,7:2,8:2,9:4,10:4,11:4,12:4,15:3,16:2,17:4,18:4,19:2,20:2}
terms={
 'mode':re.compile(r'prison|classic|туалет|потребност|фракци|крыса|rat_boss',re.I),
 'addon_delivery':re.compile(r'addon|modload|servermod|server_mod|mod:|\.class|ClassLoader|defineClass|bytecode',re.I),
 'ui_transport':re.compile(r'handshake|wada|gama|prison:|script:|scriptengine|javascript|luaj|nashorn',re.I),
}
def strings(data):
    count=struct.unpack_from('>H',data,8)[0];pos,index=10,1;out=[]
    while index<count:
        tag=data[pos];pos+=1
        if tag==1:
            length=struct.unpack_from('>H',data,pos)[0];pos+=2
            out.append(data[pos:pos+length].decode('utf-8',errors='replace'));pos+=length
        else:
            pos+=SIZES[tag]
            if tag in (5,6):index+=1
        index+=1
    return out

report={k:[] for k in terms}
with zipfile.ZipFile(ROOT/'full-decompilation/inputs/minecraft-reconstructed.jar') as arc:
    for name in arc.namelist():
        if not name.endswith('.class'):continue
        values=strings(arc.read(name))
        for key,pattern in terms.items():
            matches=[s for s in values if pattern.search(s)]
            if matches:report[key].append({'class':name,'strings':matches})
(ROOT/'decoded/reconstructed-client-evidence.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:{'classes':len(v),'samples':v[:8]} for k,v in report.items()},ensure_ascii=False,indent=2)[:13000])
