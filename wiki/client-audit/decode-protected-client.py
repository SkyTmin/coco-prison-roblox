"""Static format reconstruction derived from the local JVM's class parser.

The installed game/VM is never executed. Start with constant-pool validation.
RVA references: header key 0x3620cc; string transform 0x3587d0.
"""
from pathlib import Path
import json
import struct
import sys
import zipfile

ROOT=Path(__file__).parent
MASK=(1<<64)-1
GAMMA=0x9e3779b97f4a7c15
SIZES={3:4,4:4,5:8,6:8,7:2,8:2,9:4,10:4,11:4,12:4,15:3,16:2,17:4,18:4,19:2,20:2}

def rol(v,n,bits=64):
    mask=(1<<bits)-1;v&=mask;n%=bits
    return ((v<<n)|(v>>(bits-n)))&mask

def ror(v,n,bits=64):return rol(v,-n,bits)

def swap(v,bits=64):return int.from_bytes(v.to_bytes(bits//8,'little'),'big')

def mix(v):
    v=(v+GAMMA)&MASK
    v=((v^(v>>30))*0xbf58476d1ce4e5b9)&MASK
    v=((v^(v>>27))*0x94d049bb133111eb)&MASK
    return v^(v>>31)

def keyed(base,index,tag):
    v=rol(base^index^tag,12)
    v=(v+0xf6ab2024ef16c808)&MASK
    v^=0x6bdd89d20a2875f5
    v=(v-0x0fbedc513ea96c6f)&MASK
    return rol(swap(v),18)

def pcg(seed,length):
    inc=mix(seed^0xda3e39cb94b95bdb)|1
    state=(mix(seed)*0x5851f42d4c957f2d+inc)&MASK
    output=bytearray()
    while len(output)<length:
        old=state
        state=(state*0x5851f42d4c957f2d+inc)&MASK
        word=ror(((old>>45)^(old>>27))&0xffffffff,old>>59,32)
        output.extend(word.to_bytes(4,'little'))
    return output[:length]

def pcg_words(seed):
    inc=mix(seed^0xda3e39cb94b95bdb)|1
    state=(mix(seed)*0x5851f42d4c957f2d+inc)&MASK
    while True:
        old=state;state=(state*0x5851f42d4c957f2d+inc)&MASK
        yield ror(((old>>45)^(old>>27))&0xffffffff,old>>59,32)

def xorshift(seed,length):
    state=mix(seed) or mix((seed+GAMMA)&MASK)
    output=bytearray()
    while len(output)<length:
        state^=state>>12
        state^=(state<<25)&MASK
        state^=state>>27
        output.extend(((state*0x2545f4914f6cdd1d)&MASK).to_bytes(8,'little'))
    return output[:length]

def decode_utf8(data,base,index):
    key=keyed(base,index,0x67a54eb748e9a446)
    out=bytearray(data)
    for stream in (pcg(key^0x21e04695ec8806ef,len(data)),xorshift(key^0x43c4ab317d3abd88,len(data)),
                   xorshift(key^0xd40f096ba1463917,len(data)),pcg(key^0xa5d49c0798dee691,len(data))):
        for i,b in enumerate(stream):out[i]^=b
    return bytes(out)

def decode_number(data,base,index):
    value=int.from_bytes(data,'big')
    if len(data)==4:
        key=keyed(base,index,0xa6e7ef8f7eb966a9)&0xffffffff
        value=ror(value,15,32)^key
        value=ror(swap(value,32),25,32)^key^0xdc206b39
        value=ror(swap(value,32)^key,20,32)^key
        value=(value-key)&0xffffffff
    else:
        key=keyed(base,index,0x5caec792d7cd0106)
        value=((ror(value,1)^key)*0x23065951f017b147)&MASK
        value=(ror(value,13)-key)&MASK
        value=ror(value^0x7bca588a75eb78f6,2)
        value=swap((value*0x6bc6782eb7c7c7d3)&MASK)
    return value.to_bytes(len(data),'big')

def decode_code(data,base,name_index,descriptor_index):
    key=keyed(base,(name_index<<16)|descriptor_index,0x0d06766856a43e76)
    order=list(range(len(data)))
    generator=pcg_words(key^0x97f3fcc39e5a9a58)
    for size in range(len(data),1,-1):
        index=next(generator)%size
        order[size-1],order[index]=order[index],order[size-1]
    out=bytearray(len(data))
    for index,destination in enumerate(order):out[destination]=data[index]
    for stream in (xorshift(key^0xa64b4f486c0b9d90,len(data)),xorshift(key^0x76a3c4867b4eb81c,len(data))):
        for i,b in enumerate(stream):out[i]=(out[i]-b)&255
    validate_bytecode(out)
    return bytes(out)

def validate_bytecode(data):
    """Check every instruction boundary and every encoded branch/switch target."""
    pos=0;boundaries=set();targets=[]
    lengths={16:2,17:3,18:2,19:3,20:3,132:3,169:2,185:5,186:5,187:3,188:2,189:3,192:3,193:3,197:4,200:5,201:5}
    lengths.update({op:2 for op in [*range(21,26),*range(54,59)]})
    lengths.update({op:3 for op in [*range(153,169),*range(178,185),198,199]})
    while pos<len(data):
        boundaries.add(pos);op=data[pos]
        if op>201:raise ValueError(f'Invalid opcode {op} at {pos}')
        size=lengths.get(op,1)
        if op==196:
            following=data[pos+1]
            if following not in [*range(21,26),*range(54,59),132,169]:raise ValueError('Invalid wide')
            size=6 if following==132 else 4
        elif op in (170,171):
            start=(pos+4)&~3
            if any(data[pos+1:start]):raise ValueError('Nonzero switch padding')
            default=struct.unpack_from('>i',data,start)[0];targets.append(pos+default)
            if op==170:
                low,high=struct.unpack_from('>ii',data,start+4)
                count=high-low+1
                if count<0 or count>len(data):raise ValueError('Invalid tableswitch bounds')
                for n in range(count):targets.append(pos+struct.unpack_from('>i',data,start+12+n*4)[0])
                size=start+12+count*4-pos
            else:
                count=struct.unpack_from('>i',data,start+4)[0]
                if count<0 or count>len(data):raise ValueError('Invalid lookupswitch bounds')
                keys=[]
                for n in range(count):
                    key,offset=struct.unpack_from('>ii',data,start+8+n*8)
                    keys.append(key);targets.append(pos+offset)
                if keys!=sorted(set(keys)):raise ValueError('Invalid lookup keys')
                size=start+8+count*8-pos
        elif op in [*range(153,169),198,199]:targets.append(pos+struct.unpack_from('>h',data,pos+1)[0])
        elif op in (200,201):targets.append(pos+struct.unpack_from('>i',data,pos+1)[0])
        if op==185 and data[pos+4]!=0:raise ValueError('Invalid invokeinterface padding')
        if op==186 and data[pos+3:pos+5]!=b'\0\0':raise ValueError('Invalid invokedynamic padding')
        pos+=size
    if pos!=len(data):raise ValueError('Instruction overruns method')
    if any(t not in boundaries for t in targets):raise ValueError('Branch target is not an instruction boundary')

def decode_constants(raw):
    if raw[:4]!=bytes.fromhex('c7c70001'):raise ValueError('Unknown magic')
    minor,major=struct.unpack_from('>HH',raw,4)
    seed=int.from_bytes(raw[8:16],'big')
    count=struct.unpack_from('>H',raw,16)[0]
    base=mix(mix(seed)^mix((major<<32)|(minor<<16)|count))
    pos,index,pool=18,1,{}
    while index<count:
        tag=raw[pos];pos+=1
        if tag==1:
            length=struct.unpack_from('>H',raw,pos)[0];pos+=2
            pool[index]=(tag,decode_utf8(raw[pos:pos+length],base,index))
            pos+=length
        else:
            length=SIZES[tag]
            value=raw[pos:pos+length]
            if tag in (3,4,5,6):value=decode_number(value,base,index)
            pool[index]=(tag,value);pos+=length
            if tag in (5,6):index+=1
        index+=1
    _,this_class,_=struct.unpack_from('>HHH',raw,pos)
    name_index=int.from_bytes(pool[this_class][1],'big')
    return {'base':base,'pool':pool,'end':pos,'name':pool[name_index][1]}

def reconstruct(raw):
    decoded=decode_constants(raw);pool=decoded['pool'];base=decoded['base']
    out=bytearray(bytes.fromhex('cafebabe')+raw[4:8]+raw[16:18])
    for tag,value in pool.values():
        out.append(tag)
        if tag==1:out.extend(struct.pack('>H',len(value)))
        out.extend(value)
    tail=bytearray(raw[decoded['end']:])
    # Class header, interfaces, fields, methods, and class attributes remain structural data.
    pos=6
    interfaces=struct.unpack_from('>H',tail,pos)[0];pos+=2+interfaces*2
    methods=0
    def attributes(pos,count,name_index=0,descriptor_index=0):
        nonlocal methods
        for _ in range(count):
            attr_index,length=struct.unpack_from('>HI',tail,pos);pos+=6
            if pool[attr_index][1]==b'Code':
                size=struct.unpack_from('>I',tail,pos+4)[0]
                code_pos=pos+8
                tail[code_pos:code_pos+size]=decode_code(bytes(tail[code_pos:code_pos+size]),base,name_index,descriptor_index)
                methods+=1
            pos+=length
        return pos
    fields=struct.unpack_from('>H',tail,pos)[0];pos+=2
    for _ in range(fields):
        _,name,desc,count=struct.unpack_from('>HHHH',tail,pos);pos+=8
        pos=attributes(pos,count)
    count=struct.unpack_from('>H',tail,pos)[0];pos+=2
    for _ in range(count):
        _,name,desc,attrs=struct.unpack_from('>HHHH',tail,pos);pos+=8
        pos=attributes(pos,attrs,name,desc)
    count=struct.unpack_from('>H',tail,pos)[0];pos+=2
    pos=attributes(pos,count)
    if pos!=len(tail):raise ValueError(f'Trailing/unparsed structure: {pos}/{len(tail)}')
    out.extend(tail)
    return bytes(out),methods

def reconstruct_archive():
    source=ROOT/'full-decompilation/inputs/minecraft.jar'
    target=ROOT/'full-decompilation/inputs/minecraft-reconstructed.jar'
    records=[];errors=[];method_count=0
    with zipfile.ZipFile(source) as original,zipfile.ZipFile(target,'w',zipfile.ZIP_DEFLATED) as output:
        for name in original.namelist():
            if not name.endswith('.class'):continue
            try:
                data,methods=reconstruct(original.read(name))
                output.writestr(name,data)
                records.append({'class':name,'methods':methods})
                method_count+=methods
            except Exception as exc:errors.append({'class':name,'error':str(exc)[:200]})
    report={'classes':len(records),'methods':method_count,'bytecodeValidation':'All decoded method instruction boundaries, branch/switch targets and invoke padding checked. Not a type/stack verifier or a gameplay test.','errors':errors,'output':str(target)}
    (ROOT/'protected-reconstruction.json').write_text(json.dumps(report,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,indent=2))

def validate():
    archive=ROOT/'full-decompilation/inputs/minecraft.jar'
    samples=[];errors=[];passed=0
    with zipfile.ZipFile(archive) as arc:
        names=[n for n in arc.namelist() if n.endswith('.class')]
        for name in names:
            try:
                result=decode_constants(arc.read(name))
                if result['name']!=name[:-6].encode():raise ValueError('Class name mismatch '+repr(result['name']))
                passed+=1
                if len(samples)<3:
                    samples.append({'class':name,'decodedName':result['name'].decode(),
                        'strings':[{'index':i,'value':v.decode('utf-8',errors='replace')} for i,(tag,v) in result['pool'].items() if tag==1][:12]})
            except Exception as exc:errors.append({'class':name,'error':str(exc)[:160]})
    report={'classes':len(names),'nameMatches':passed,'errors':errors,'samples':samples}
    (ROOT/'protected-constants-validation.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps(report,ensure_ascii=False,indent=2)[:6500])

if __name__=='__main__':
    sys.stdout.reconfigure(encoding='utf-8')
    if '--reconstruct' in sys.argv:reconstruct_archive()
    else:validate()
