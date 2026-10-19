"""Static instructions around class magic checks in the installed JVM binary."""
from pathlib import Path
import json
import sys
sys.path.insert(0,str(Path(__file__).parent/'tools/python-libs'))
import pefile
import capstone

ROOT=Path(__file__).parent
DLL=Path('C:/Users/user/.cristalix/runtime/bin/server/jvm.dll')
pe=pefile.PE(str(DLL))
raw=DLL.read_bytes()
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
functions=[(e.struct.BeginAddress,e.struct.EndAddress) for e in pe.DIRECTORY_ENTRY_EXCEPTION]
results=[]
for pattern in (bytes.fromhex('bebafeca'),bytes.fromhex('cafebabe')):
    pos=raw.find(pattern)
    while pos>=0:
        rva=pe.get_rva_from_offset(pos)
        section=next((s for s in pe.sections if s.VirtualAddress<=rva<s.VirtualAddress+s.Misc_VirtualSize),None)
        function=next(((a,b) for a,b in functions if a<=rva<b),None)
        record={'pattern':pattern.hex(),'offset':pos,'rva':hex(rva),'section':section.Name.decode(errors='replace').strip('\0') if section else None}
        if function and section and section.Characteristics&0x20000000:
            a,b=function
            record['function']=[hex(a),hex(b)]
            # Parse from the function boundary to obtain reliable instruction alignment.
            instructions=list(md.disasm(pe.get_data(a,b-a),a))
            ix=next((i for i,x in enumerate(instructions) if x.address<=rva<x.address+x.size),None)
            if ix is not None:
                record['instructions']=[f'{i.address:08x} {i.mnemonic} {i.op_str}' for i in instructions[max(0,ix-12):ix+16]]
        results.append(record)
        pos=raw.find(pattern,pos+1)
(ROOT/'vm-magic-checks.json').write_text(json.dumps(results,indent=2)+'\n',encoding='utf-8')
print(json.dumps(results,indent=2))
