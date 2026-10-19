"""Preserve the game screenshots omitted from the initial explicit manifests."""
from pathlib import Path
import hashlib
import json
import sys
from PIL import Image

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
inventory = json.loads((OUT / 'coverage-audit/unlisted-inventory.json').read_text(encoding='utf-8'))
assert len(inventory) == 130
sources = []
for r in inventory:
    n = r['inventoryIndex']
    if n <= 2:  # Login/time troubleshooting, not gameplay parameters.
        continue
    if n <= 17:
        group = 'helmet'
    elif n <= 34:
        group = 'chestplate'
    elif n <= 49:
        group = 'leggings'
    elif n <= 64:
        group = 'boots'
    elif n <= 80:
        group = 'axe'
    elif n <= 82:
        group = 'mining'
    elif n <= 84:
        group = 'faction'
    else:
        group = 'auction'
    box = (612, 300, 1310, 762) if n <= 80 else (
        (0, 24, 1910, 1035) if n <= 82 else ((600, 300, 1330, 780) if n <= 84 else (375, 250, 1900, 1035)))
    target = OUT / 'missed-menu-evidence' / group / f'{n:03d}.png'
    target.parent.mkdir(exist_ok=True, parents=True)
    original = Path(r['path'])
    assert hashlib.sha256(original.read_bytes()).hexdigest() == r['sha256']
    with Image.open(original) as im:
        im.crop(box).save(target)
    sources.append(dict(id=f'coverage_{n}', inventoryIndex=n, group=group,
        originalFilename=original.name, originalSha256=r['sha256'], originalDimensions=r['dimensions'],
        cropBox=list(box), evidencePath=target.as_posix(), evidenceSha256=hashlib.sha256(target.read_bytes()).hexdigest()))
assert len(sources) == 128
data = dict(recordedDate='2026-10-20', reason='Corrects incomplete 127-frame evidence inventory',
    sourceType='User game screenshots found in local attachment files and visually classified',
    sources=sources, excludedNonGameplayFiles=2)
(OUT / 'missed-menu-sources.json').write_text(json.dumps(data, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(sources=len(sources), uniqueOriginals=len({s['originalSha256'] for s in sources})), indent=2))
