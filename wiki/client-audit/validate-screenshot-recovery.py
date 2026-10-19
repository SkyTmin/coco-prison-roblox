"""Check the explicit gameplay attachment inventory, evidence and linked reports.

Hashes verify integrity, not visual review. Review status in the ledger records
the completed manual transcription; cache inventory alone is not attachment proof.
"""
from pathlib import Path
from collections import Counter
import hashlib
import json
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
ROOT = Path(__file__).parent
OUT = ROOT / 'content-analysis'
TEMP = Path('C:/Users/user/AppData/Local/Temp')
manifest_names = ['mine-menu-recovery.json', 'pickaxe-upgrades-recovery.json',
                 'npc-menu-recovery.json', 'other-upgrades-recovery.json', 'late-menu-sources.json',
                 'missed-menu-sources.json', 'book-case-sources.json']
sources, ledger, manifests = [], [], {}
first_by_hash = {}
for name in manifest_names:
    data = json.loads((OUT / name).read_text(encoding='utf-8'))
    manifests[name] = data
    qualified_ids = set()
    for s in data['sources']:
        qualified_id = name + ':' + s['id']
        assert qualified_id not in qualified_ids, qualified_id
        qualified_ids.add(qualified_id)
        original = TEMP / s['originalFilename']
        assert hashlib.sha256(original.read_bytes()).hexdigest() == s['originalSha256'], original
        assert hashlib.sha256(Path(s['evidencePath']).read_bytes()).hexdigest() == s['evidenceSha256'], s['evidencePath']
        duplicate_of = first_by_hash.get(s['originalSha256'])
        first_by_hash.setdefault(s['originalSha256'], qualified_id)
        ledger.append(dict(
            ledgerNumber=len(ledger) + 1, qualifiedSourceId=qualified_id,
            sourceManifest=name, sourceId=s['id'],
            group=s.get('group', s.get('batch', name.removesuffix('.json'))),
            originalFilename=s['originalFilename'], originalSha256=s['originalSha256'],
            originalDimensions=s['originalDimensions'], evidencePath=s['evidencePath'],
            evidenceSha256=s['evidenceSha256'], duplicateOriginalOf=duplicate_of,
            visualTranscriptionStatus='manually_read_at_original_resolution',
            reviewStatusBasis='Recorded manual review; not inferred from the hash check.'))
        sources.append(s)
assert len(sources) == 289
assert len({s['originalFilename'] for s in sources}) == 289
assert len(first_by_hash) == 287
assert [len(manifests[n]['sources']) for n in manifest_names] == [9, 16, 10, 31, 61, 128, 34]

# Every newly added frame must be assigned to one completed transcription.
new_sources = manifests['missed-menu-sources.json']['sources'] + manifests['book-case-sources.json']['sources']
new_ids = {s['id'] for s in new_sources}
assert len(new_ids) == 162
new_datasets = {}
assignments = Counter()
for name in ['armor-and-axe-recovery.json', 'books-system-recovery.json', 'auction-and-scenes-recovery.json']:
    data = json.loads((OUT / name).read_text(encoding='utf-8'))
    new_datasets[name] = data
    assignments.update(data['sourceIds'])
    assert len(set(data['sourceIds'])) == len(data['sourceIds']), name
assert set(assignments) == new_ids
assert set(assignments.values()) == {1}
for row in ledger:
    if row['sourceId'] in new_ids:
        row['transcriptionDataset'] = next(n for n, d in new_datasets.items() if row['sourceId'] in d['sourceIds'])

armor = new_datasets['armor-and-axe-recovery.json']
books = new_datasets['books-system-recovery.json']
armor_count = sum(len(armor['items'][k]['transitions']) for k in ['helmet', 'chestplate', 'leggings', 'boots'])
axe_count = len(armor['items']['axe']['transitions'])
assert armor_count == 56 and axe_count == 15
item_count = (len(manifests['pickaxe-upgrades-recovery.json']['transitions'])
              + len(manifests['other-upgrades-recovery.json']['sword']['transitions'])
              + len(manifests['other-upgrades-recovery.json']['shovel']['transitions'])
              + armor_count + axe_count)
assert item_count == 115
assert len(books['templates']) == 31
assert len({b['name'] for b in books['templates']}) == 31
rarities = Counter(b['rarityDisplay'] for b in books['templates'])
assert dict(rarities) == {'обычное': 13, 'редкое': 10, 'легендарное': 8}
assert len(books['auctionBookObservations']) == 35
for template in books['templates']:
    assert set(template['evidence']) <= new_ids
    assert template['caseDropProbability'] is None
    assert template['procProbabilityByLevel'] is None
for observation in books['auctionBookObservations']:
    assert set(observation['evidence']) <= new_ids
    assert 0 <= observation['applicationSuccessPercent'] <= 100

registered_filenames = {s['originalFilename'] for s in sources}
known_non_game = {
    'codex-clipboard-a26c917f-1719-4560-a8c1-50d13f83d0d9.png',
    'codex-clipboard-8958c7f6-d451-43ee-9a8e-61bab77fc33f.png'}
cached_filenames = {p.name for p in TEMP.glob('codex-clipboard-*.png')}
unclassified_cache = sorted(cached_filenames - registered_filenames - known_non_game)
ledger_data = dict(
    recordedDate='2026-10-20',
    scope='289 explicitly registered gameplay screenshot files; not every clipboard cache file.',
    correction=dict(previousIncompleteCount=127, previouslyMissedGameplayFrames=128, newBookCaseFrames=34),
    registeredScreenshots=len(ledger), uniqueOriginals=len(first_by_hash),
    reviewStatusLimitation='Manual review is recorded, not mechanically established by SHA-256.',
    excludedKnownNonGameplayClipboardFiles=sorted(known_non_game & cached_filenames),
    unclassifiedClipboardFilesNotInProvidedAttachmentLists=unclassified_cache,
    unclassifiedCacheLimitation='Not counted as supplied game evidence; attachment provenance and contents unclassified.',
    entries=ledger)
(OUT / 'screenshot-coverage-ledger.json').write_text(
    json.dumps(ledger_data, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')

reports = [ROOT.parent / 'README.md'] + [ROOT / name for name in [
    'RECOVERED-GAME-DATA.md', 'MINE-RECOVERY.md', 'MINE-COMPOSITION.md',
    'PICKAXE-UPGRADES.md', 'SWORD-AND-SHOVEL-UPGRADES.md', 'NPC-MENU-RECOVERY.md',
    'BOSS-MENU-RECOVERY.md', 'STORE-AND-TELEPORTS.md', 'CLASSIC-CONTENT-CATALOG.md',
    'ARMOR-AND-AXE-UPGRADES.md', 'BOOKS-SYSTEM.md', 'AUCTION-AND-FACTION-RECOVERY.md',
    'INDEPENDENT-GAP-RESEARCH.md']]
# The summary links the validation output itself; create it before checking links.
validation_path = OUT / 'screenshot-recovery-validation.json'
validation_path.write_text(json.dumps({'status': 'Validation in progress.'}) + '\n', encoding='utf-8')
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
assert catalog['allItemUpgradeTransitions'] == item_count
assert catalog['observedAncientBookTemplates'] == len(books['templates'])
result = dict(suppliedScreenshots=len(sources), uniqueOriginals=len(first_by_hash),
    originalHashesChecked=len(sources), evidenceHashesChecked=len(sources),
    reportsChecked=len(reports), localLinksChecked=checked,
    sourceManifestFiles=len(manifest_names), previousIncompleteCount=127,
    previouslyMissedGameplayFrames=128, newBookCaseFrames=34,
    newlyAddedFramesAssignedExactlyOnce=len(assignments),
    observedMineRows=26, distinctMineNamesWithBlockLabels=25,
    bossMenuEntries=17, storeOffers=31, numericStorePrices=28,
    teleportDestinations=9, itemUpgradeTransitions=item_count,
    armorUpgradeTransitions=armor_count, axeUpgradeTransitions=axe_count,
    observedBookTemplates=len(books['templates']), bookRarityCounts=dict(rarities),
    auctionBookObservationFrames=len(books['auctionBookObservations']),
    unclassifiedClipboardFilesNotInProvidedAttachmentLists=unclassified_cache,
    scope='Explicit registered gameplay attachment inventory; cache files alone do not establish attachment provenance.',
    status='Registered evidence integrity, new-frame assignment and local-link checks passed; numeric server rules remain unknown where not demonstrated.')
validation_path.write_text(
    json.dumps(result, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, ensure_ascii=False, indent=2))
