"""Index every decompiled source and every bytecode method as static data.

Source files use numeric names to preserve Windows case collisions. No game code
is executed. The SQLite index retains exact obfuscated identifiers/descriptors.
"""
from pathlib import Path
import collections
import hashlib
import json
import re
import sqlite3
import struct
import sys
import zipfile

ROOT=Path(__file__).parent
DEST=ROOT/'code-analysis'
DEST.mkdir(exist_ok=True)
INVENTORY=json.loads((ROOT/'full-decompilation/input-inventory.json').read_text(encoding='utf-8'))
DB=DEST/'code-index.sqlite'
connection=sqlite3.connect(DB)
connection.executescript('''
PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF;
DROP TABLE IF EXISTS sources; DROP TABLE IF EXISTS classes; DROP TABLE IF EXISTS methods;
DROP TABLE IF EXISTS calls; DROP TABLE IF EXISTS literals; DROP TABLE IF EXISTS field_uses;
CREATE TABLE sources(id INTEGER PRIMARY KEY,archive TEXT,entry TEXT,path TEXT,lines INTEGER,bytes INTEGER,sha256 TEXT,text TEXT);
CREATE TABLE classes(id INTEGER PRIMARY KEY,archive TEXT,name TEXT,entry TEXT,super TEXT,interfaces TEXT,flags INTEGER);
CREATE TABLE methods(id INTEGER PRIMARY KEY,class_id INTEGER,name TEXT,descriptor TEXT,flags INTEGER,code_bytes INTEGER,instructions INTEGER);
CREATE TABLE calls(caller INTEGER,pc INTEGER,opcode INTEGER,owner TEXT,name TEXT,descriptor TEXT,kind TEXT);
CREATE TABLE literals(method INTEGER,pc INTEGER,value TEXT);
CREATE TABLE field_uses(method INTEGER,pc INTEGER,opcode INTEGER,owner TEXT,name TEXT,descriptor TEXT);
''')
source_manifest=[];counts=[];errors=[]
source_id=class_id=method_id=0
CUSTOM={'minecraft','addon-gama','addon-wada','addon-socials'}

class Reader:
    def __init__(self,data):self.data=data;self.pos=0
    def read(self,n):
        value=self.data[self.pos:self.pos+n]
        if len(value)!=n:raise ValueError('Truncated structure')
        self.pos+=n;return value
    def u1(self):return self.read(1)[0]
    def u2(self):return int.from_bytes(self.read(2),'big')
    def u4(self):return int.from_bytes(self.read(4),'big')

def pool_read(reader):
    count=reader.u2();pool=[None]*count;index=1
    while index<count:
        tag=reader.u1()
        if tag==1:value=reader.read(reader.u2()).decode('utf-8',errors='replace')
        elif tag in (3,4):value=reader.read(4)
        elif tag in (5,6):value=reader.read(8)
        elif tag in (7,8,16,19,20):value=reader.u2()
        elif tag in (9,10,11,12,17,18):value=(reader.u2(),reader.u2())
        elif tag==15:value=(reader.u1(),reader.u2())
        else:raise ValueError('Unknown constant tag '+str(tag))
        pool[index]=(tag,value)
        if tag in (5,6):index+=1
        index+=1
    return pool

def utf(pool,index):return pool[index][1]
def class_name(pool,index):return utf(pool,pool[index][1]) if index else None
def member(pool,index):
    owner,nat=pool[index][1];name,desc=pool[nat][1]
    return class_name(pool,owner),utf(pool,name),utf(pool,desc)

def attributes(reader,pool):
    result=[]
    for _ in range(reader.u2()):result.append((utf(pool,reader.u2()),reader.read(reader.u4())))
    return result

LENGTHS={16:2,17:3,18:2,19:3,20:3,132:3,169:2,185:5,186:5,187:3,188:2,189:3,192:3,193:3,197:4,200:5,201:5}
LENGTHS.update({op:2 for op in [*range(21,26),*range(54,59)]})
LENGTHS.update({op:3 for op in [*range(153,169),*range(178,185),198,199]})

def instructions(code):
    pos=0
    while pos<len(code):
        op=code[pos];size=LENGTHS.get(op,1)
        if op==196:size=6 if code[pos+1]==132 else 4
        elif op in (170,171):
            start=(pos+4)&~3
            if op==170:
                low,high=struct.unpack_from('>ii',code,start+4);size=start+12+4*(high-low+1)-pos
            else:
                count=struct.unpack_from('>i',code,start+4)[0];size=start+8+count*8-pos
        yield pos,op
        if size<1:raise ValueError('Invalid opcode length')
        pos+=size
    if pos!=len(code):raise ValueError('Code did not end on boundary')

def index_class(archive,entry,raw):
    global class_id,method_id
    reader=Reader(raw)
    if reader.read(4)!=bytes.fromhex('cafebabe'):raise ValueError('Nonstandard header')
    reader.read(4);pool=pool_read(reader)
    flags=reader.u2();own=class_name(pool,reader.u2());super_name=class_name(pool,reader.u2())
    interfaces=[class_name(pool,reader.u2()) for _ in range(reader.u2())]
    class_id+=1;cid=class_id
    connection.execute('INSERT INTO classes VALUES(?,?,?,?,?,?,?)',(cid,archive,own,entry,super_name,json.dumps(interfaces),flags))
    for _ in range(reader.u2()):reader.read(6);attributes(reader,pool)
    dynamic=[]
    for _ in range(reader.u2()):
        access,name,desc=reader.u2(),utf(pool,reader.u2()),utf(pool,reader.u2())
        attrs=attributes(reader,pool);method_id+=1;mid=method_id
        body=next((value for key,value in attrs if key=='Code'),None)
        code=body[8:8+int.from_bytes(body[4:8],'big')] if body else b''
        ins_count=0
        for pc,opcode in instructions(code):
            ins_count+=1
            if opcode in range(178,186):
                index=int.from_bytes(code[pc+1:pc+3],'big');target=member(pool,index)
                if opcode<182:connection.execute('INSERT INTO field_uses VALUES(?,?,?,?,?,?)',(mid,pc,opcode,*target))
                else:connection.execute('INSERT INTO calls VALUES(?,?,?,?,?,?,?)',(mid,pc,opcode,*target,'direct'))
            elif opcode==186:
                index=int.from_bytes(code[pc+1:pc+3],'big');dynamic.append((mid,pc,pool[index][1][0]))
            elif opcode in (18,19,20):
                index=code[pc+1] if opcode==18 else int.from_bytes(code[pc+1:pc+3],'big')
                if pool[index][0]==8:connection.execute('INSERT INTO literals VALUES(?,?,?)',(mid,pc,utf(pool,pool[index][1])))
        connection.execute('INSERT INTO methods VALUES(?,?,?,?,?,?,?)',(mid,cid,name,desc,access,len(code),ins_count))
    attrs=attributes(reader,pool)
    bootstraps=[]
    for key,data in attrs:
        if key!='BootstrapMethods':continue
        b=Reader(data)
        for _ in range(b.u2()):
            ref=b.u2();args=[b.u2() for _ in range(b.u2())];bootstraps.append((ref,args))
    for mid,pc,index in dynamic:
        ref,args=bootstraps[index]
        for arg in [ref,*args]:
            if pool[arg][0]!=15:continue
            kind,target_index=pool[arg][1]
            if pool[target_index][0] not in (10,11):continue
            connection.execute('INSERT INTO calls VALUES(?,?,?,?,?,?,?)',(mid,pc,186,*member(pool,target_index),'bootstrap' if arg==ref else 'lambda_handle'))
    if reader.pos!=len(raw):raise ValueError('Trailing class data')

for item in INVENTORY:
    archive=item['id'];source_path=ROOT/'full-decompilation/sources'/(archive+'-sources.zip')
    line_count=byte_count=source_count=0
    before_classes,before_methods=class_id,method_id
    if source_path.exists():
        folder=DEST/'source'/archive;folder.mkdir(parents=True,exist_ok=True)
        with zipfile.ZipFile(source_path) as source:
            for entry in source.namelist():
                if not entry.endswith(('.java','.kt')):continue
                data=source.read(entry);text=data.decode('utf-8',errors='replace')
                source_id+=1;source_count+=1;lines=len(text.splitlines());line_count+=lines;byte_count+=len(data)
                # Numeric basename prevents invalid Windows names and case collisions.
                path=folder/(f'{source_id:05d}'+Path(entry).suffix)
                path.write_bytes(data)
                digest=hashlib.sha256(data).hexdigest()
                connection.execute('INSERT INTO sources VALUES(?,?,?,?,?,?,?,?)',(source_id,archive,entry,str(path),lines,len(data),digest,text))
                source_manifest.append({'id':source_id,'archive':archive,'entry':entry,'path':str(path),'lines':lines,'sha256':digest})
    if item['classCount']:
        input_path=ROOT/'full-decompilation/inputs/minecraft-reconstructed.jar' if archive=='minecraft' else Path(item['input'])
        with zipfile.ZipFile(input_path) as classes:
            for entry in classes.namelist():
                if not entry.endswith('.class'):continue
                try:index_class(archive,entry,classes.read(entry))
                except Exception as exc:errors.append({'archive':archive,'entry':entry,'error':str(exc)})
    connection.commit()
    counts.append({'archive':archive,'sourceFiles':source_count,'lines':line_count,'bytes':byte_count,'classesIndexed':class_id-before_classes,'methodsIndexed':method_id-before_methods,'category':'client_and_addons' if archive in CUSTOM else 'library_or_resources'})
    print(json.dumps(counts[-1]),flush=True)

connection.executescript('''
CREATE INDEX source_name ON sources(archive,entry);
CREATE INDEX class_name ON classes(name);
CREATE INDEX method_key ON methods(class_id,name,descriptor);
CREATE INDEX called_target ON calls(owner,name,descriptor);
CREATE INDEX call_caller ON calls(caller);
CREATE INDEX literal_method ON literals(method);
CREATE INDEX field_target ON field_uses(owner,name,descriptor);
''')
connection.commit()
totals={table:connection.execute('SELECT count(*) FROM '+table).fetchone()[0] for table in ['sources','classes','methods','calls','literals','field_uses']}
totals['lines']=sum(x['lines'] for x in counts)
report={'totals':totals,'archives':counts,'errors':errors,'note':'Whole-corpus structural index and text scan. Does not imply a manual semantic review of every line.'}
(DEST/'source-map.json').write_text(json.dumps(source_manifest,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
(DEST/'index-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print(json.dumps({'totals':totals,'errors':errors[:12],'errorCount':len(errors)}),flush=True)
