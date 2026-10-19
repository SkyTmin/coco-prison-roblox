"""Inspect the on-disk custom class envelope without executing game code."""
from pathlib import Path
import collections
import json
import struct
import zipfile

ROOT=Path('C:/Users/user/Documents/roblox-prison-research/client-audit')
INPUT=ROOT/'full-decompilation/inputs/minecraft.jar'
SIZES={3:4,4:4,5:8,6:8,7:2,8:2,9:4,10:4,11:4,12:4,15:3,16:2,17:4,18:4,19:2,20:2}
samples=[]
errors=[]
formats=collections.Counter()
with zipfile.ZipFile(INPUT) as archive:
    entries=[e for e in archive.infolist() if e.filename.endswith('.class')]
    for entry in entries:
        data=archive.read(entry)
        formats[data[:4].hex()]+=1
        try:
            count=struct.unpack_from('>H',data,16)[0]
            pos,index,pool=18,1,{}
            while index<count:
                tag=data[pos]
                pos+=1
                if tag==1:
                    length=struct.unpack_from('>H',data,pos)[0]
                    pos+=2
                    pool[index]=(tag,data[pos:pos+length])
                    pos+=length
                else:
                    length=SIZES[tag]
                    pool[index]=(tag,data[pos:pos+length])
                    pos+=length
                    if tag in (5,6):
                        index+=1
                index+=1
            access,this_class,super_class=struct.unpack_from('>HHH',data,pos)
            name_index=struct.unpack('>H',pool[this_class][1])[0]
            name_bytes=pool[name_index][1]
            if len(samples)<8:
                samples.append({'name':entry.filename,'seedHex':data[8:16].hex(),'constantPoolCount':count,
                    'constantPoolEnd':pos,'access':access,'thisClassIndex':this_class,'nameIndex':name_index,
                    'encodedNameHex':name_bytes.hex(),'expectedName':entry.filename[:-6],
                    'firstUtf8':[{'index':i,'hex':v[1].hex()[:160],'length':len(v[1])} for i,v in pool.items() if v[0]==1][:5]})
        except Exception as exc:
            errors.append({'class':entry.filename,'error':str(exc)})
report={'classes':len(entries),'formats':dict(formats),'structureParsed':len(entries)-len(errors),'errors':errors,'samples':samples}
(ROOT/'protected-class-format.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
print(json.dumps(report,indent=2)[:7000])
