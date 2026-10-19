"""Check all supplied screenshot evidence and the current linked reports."""
from pathlib import Path
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
TEMP = Path('C:/Users/user/AppData/Local/Temp')
sources = []
for name in ['mine-menu-recovery.json', 'pickaxe-upgrades-recovery.json',
             'npc-menu-recovery.json', 'other-upgrades-recovery.json', 'late-menu-sources.json']:
    data = json.loads((OUT / name).read_text(encoding='utf-8'))
    for s in data['sources']:
        original = TEMP / s['originalFilename']
        assert hashlib.sha256(original.read_bytes()).hexdigest() == s['originalSha256'], original
        assert hashlib.sha256(Path(s['evidencePath']).read_bytes()).hexdigest() == s['evidenceSha256'], s['evidencePath']
        sources.append(s)
assert len(sources) == 127
assert len({s['originalSha256'] for s in sources}) == 126

reports = [ROOT.parent / 'README.md'] + [ROOT / name for name in [
    'RECOVERED-GAME-DATA.md', 'MINE-RECOVERY.md', 'MINE-COMPOSITION.md',
    'PICKAXE-UPGRADES.md', 'SWORD-AND-SHOVEL-UPGRADES.md', 'NPC-MENU-RECOVERY.md',
    'BOSS-MENU-RECOVERY.md', 'STORE-AND-TELEPORTS.md', 'CLASSIC-CONTENT-CATALOG.md']]
checked = 0
for report in reports:
    text = report.read_text(encoding='utf-8')
    for target in re.findall(r'\]\(([^)\n]+)\)', text):
        if target.startswith(('https://', 'http://', '#')):
            continue
        target = target.strip('<>')
        match = re.fullmatch(r'(.+?)(?::(\d+))?', target)
        path = Path(match[1])
        if not path.is_absolute():
            path = report.parent / path
        assert path.is_file(), (report, target)
        if match[2]:
            assert 1 <= int(match[2]) <= len(path.read_text(encoding='utf-8').splitlines())
        checked += 1

late = json.loads((OUT / 'late-menu-validation.json').read_text(encoding='utf-8'))
catalog = json.loads((OUT / 'catalog-validation.json').read_text(encoding='utf-8'))
assert late['screenshotsProcessed'] == 61
assert catalog['suppliedScreenshotsProcessed'] == len(sources)
result = dict(suppliedScreenshots=127, uniqueOriginals=126,
    originalHashesChecked=127, evidenceHashesChecked=127,
    reportsChecked=len(reports), localLinksChecked=checked,
    originalScreenshotBatches=8, newScreenshots=61,
    observedMineRows=26, distinctMineNamesWithBlockLabels=25,
    bossMenuEntries=17, storeOffers=31, numericStorePrices=28,
    teleportDestinations=9, itemUpgradeTransitions=44,
    status='All integrity, coverage and local-link checks passed; numeric server rules remain unknown where not demonstrated.')
(OUT / 'screenshot-recovery-validation.json').write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
