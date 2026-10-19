"""Inventory clipboard images missing from the earlier explicit source lists.

This inventory is discovery only. Files are not claimed as supplied game evidence
until their game content has been visually checked and recorded separately.
"""
from pathlib import Path
import collections
import hashlib
import json
import sys
from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
QA = OUT / 'coverage-audit'
QA.mkdir(exist_ok=True)
known = set()
for name in ['mine-menu-recovery.json', 'pickaxe-upgrades-recovery.json',
             'npc-menu-recovery.json', 'other-upgrades-recovery.json', 'late-menu-sources.json']:
    data = json.loads((OUT / name).read_text(encoding='utf-8'))
    known.update(s['originalFilename'] for s in data['sources'])
files = sorted(Path('C:/Users/user/AppData/Local/Temp').glob('codex-clipboard-*.png'), key=lambda p: p.stat().st_mtime)
unlisted = []
for p in files:
    if p.name in known:
        continue
    with Image.open(p) as im:
        dims = list(im.size)
    unlisted.append(dict(inventoryIndex=len(unlisted)+1, path=p.as_posix(), filename=p.name,
        dimensions=dims, sha256=hashlib.sha256(p.read_bytes()).hexdigest(), mtime=p.stat().st_mtime))
for start in range(0, len(unlisted), 15):
    page = Image.new('RGB', (1440, 1500), '#e6e6e6')
    d = ImageDraw.Draw(page)
    for offset, r in enumerate(unlisted[start:start+15]):
        with Image.open(r['path']) as original:
            # Dual-monitor captures: examine the game half first, not other apps.
            im = original.crop((0, 0, original.width//2, original.height)) if original.width >= 3000 else original.copy()
            im.thumbnail((480, 270))
            x = (offset % 3) * 480
            y = (offset // 3) * 300
            page.paste(im, (x, y+25))
            d.text((x+5, y+5), f"{r['inventoryIndex']:03d}  {r['filename'][16:28]}  {r['dimensions']}", fill='black')
    page.save(QA / f'page-{start//15+1:02d}.jpg', quality=92)
(QA / 'unlisted-inventory.json').write_text(json.dumps(unlisted, ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
print(json.dumps(dict(clipboardFiles=len(files), previouslyListedFiles=len(known), unlistedFiles=len(unlisted),
    dimensions=dict(collections.Counter(str(r['dimensions']) for r in unlisted)),
    contactSheets=(len(unlisted)+14)//15), ensure_ascii=False, indent=2))
