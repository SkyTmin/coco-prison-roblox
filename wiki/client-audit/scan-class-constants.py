"""Read JVM constant pools as data. No bytecode is loaded or executed."""
import json
import re
import struct
import sys
import zipfile
from pathlib import Path

sys.stdout.reconfigure(encoding='utf-8')

ROOT = Path('C:/Users/user/Documents/roblox-prison-research/client-audit/decoded')
GAME = Path('C:/Users/user/.cristalix/updates/Minigames')
TERM = re.compile(r'prison|toilet|disease|hygiene|шест[её]р|туалет|потребност|нефт|фракци', re.I)

def strings(data):
    if data[:4] != b'\xca\xfe\xba\xbe':
        return None
    count = struct.unpack_from('>H', data, 8)[0]
    offset, index, found = 10, 1, []
    sizes = {3:4, 4:4, 5:8, 6:8, 7:2, 8:2, 9:4, 10:4, 11:4, 12:4, 15:3, 16:2, 17:4, 18:4, 19:2, 20:2}
    while index < count:
        tag = data[offset]
        offset += 1
        if tag == 1:
            length = struct.unpack_from('>H', data, offset)[0]
            offset += 2
            found.append(data[offset:offset+length].decode('utf-8', errors='replace'))
            offset += length
        elif tag in sizes:
            offset += sizes[tag]
            if tag in (5, 6):
                index += 1
        else:
            raise ValueError(f'unknown constant tag {tag}')
        index += 1
    return found

reports = []
archives=[*ROOT.glob('addon-*.zip'), GAME/'assets-addon.jar', GAME/'minecraft.jar']
reconstructed=ROOT.parent/'full-decompilation/inputs/minecraft-reconstructed.jar'
if reconstructed.exists():archives.append(reconstructed)
for archive in archives:
    with zipfile.ZipFile(archive) as jar:
        entries = jar.namelist()
        hits, errors, unsupported = [], [], 0
        for name in entries:
            if not name.endswith('.class'):
                continue
            try:
                values=strings(jar.read(name))
                if values is None:
                    unsupported+=1
                    continue
                matches = [s for s in values if TERM.search(s)]
                if matches:
                    hits.append({'class':name, 'matches':matches})
            except Exception as exc:
                errors.append({'class':name, 'error':str(exc)})
        meta = {}
        for name in ('mod.properties', 'META-INF/MANIFEST.MF', 'plugin.yml'):
            if name in entries:
                meta[name] = jar.read(name).decode('utf-8', errors='replace')
        report = {'archive':str(archive), 'entries':len(entries), 'classes':sum(n.endswith('.class') for n in entries), 'unsupportedClassFormat':unsupported, 'matchingNames':[n for n in entries if TERM.search(n)], 'hits':hits, 'errors':errors, 'metadata':meta}
        reports.append(report)
        samples = [{'class':h['class'], 'matches':[s[:240] for s in h['matches'][:6]]} for h in hits[:5]]
        print(json.dumps({'archive':archive.name, 'entries':report['entries'], 'classes':report['classes'], 'matchingNames':report['matchingNames'][:15], 'matchingClasses':len(hits), 'samples':samples, 'errors':len(errors), 'metadata':meta}, ensure_ascii=False))
(ROOT/'class-constant-audit.json').write_text(json.dumps(reports, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
