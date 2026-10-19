"""Write an explicitly selected static JVM instruction range to a text artifact."""
from pathlib import Path
import sys
sys.path.insert(0,str(Path(__file__).parent/'tools/python-libs'))
import pefile
import capstone
root=Path(__file__).parent
pe=pefile.PE('C:/Users/user/.cristalix/runtime/bin/server/jvm.dll')
start=int(sys.argv[1],16);length=int(sys.argv[2],16)
md=capstone.Cs(capstone.CS_ARCH_X86,capstone.CS_MODE_64)
text='\n'.join(f'{i.address:08x} {i.mnemonic:8} {i.op_str}' for i in md.disasm(pe.get_data(start,length),start))+'\n'
out=root/f'vm-{start:08x}.asm.txt';out.write_text(text,encoding='utf-8')
print(text)
