// Read public addon/language caches without changing the installed game.
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { zstdDecompressSync } from 'node:zlib';

const root = 'C:/Users/user/.cristalix/updates/Minigames';
const audit = 'C:/Users/user/Documents/roblox-prison-research/client-audit';
const output = path.join(audit, 'content-analysis/current-cache');
fs.mkdirSync(output, {recursive: true});
const sha = data => crypto.createHash('sha256').update(data).digest('hex');
const write = (name, data) => fs.writeFileSync(path.join(output, name), JSON.stringify(data, null, 2) + '\n');
const decode = b => b.subarray(0, 4).equals(Buffer.from([0x28,0xb5,0x2f,0xfd]))
  ? zstdDecompressSync(b, {maxOutputLength: 64 * 1024 * 1024}) : b;
function readJson(relative, savedName) {
  const source = path.join(root, relative), original = fs.readFileSync(source), data = decode(original);
  const offset = data.subarray(0,4).toString('ascii') === 'CXOD' ? data.indexOf(Buffer.from('{"')) : 0;
  const json = JSON.parse(data.subarray(offset).toString('utf8'));
  write(savedName, json);
  return {json, source, originalSha256: sha(original), decodedSha256: sha(data), bytes: original.length,
    modifiedAt: fs.statSync(source).mtime.toISOString(), savedPath: path.join(output, savedName)};
}
const addons = readJson('cache/addons/addons.json', 'addons-index.json');
const langs = readJson('cache/lang/lang.json', 'lang-index.json');
const previous = JSON.parse(fs.readFileSync(path.join(audit, 'client-snapshot-manifest.json'), 'utf8'));
const addonComparison = addons.json.addons.map(a => {
  const old = previous.addons.find(x => x.name === a.name);
  return {name:a.name, version:a.version, contentHash:a.hash, previousContentHash:old?.hash,
    contentChanged:a.hash !== old?.hash};
});
const languageRecords = [];
for (const language of langs.json.langs.filter(l => ['ru_RU', 'en_US'].includes(l.lang))) {
  for (const pie of language.pies.filter(p => ['prison','prisonevo'].includes(p.pieKey))) {
    const relative = `cache/lang/${pie.hash.slice(0,2)}/${pie.hash.slice(2,4)}/${pie.hash}`;
    if (!fs.existsSync(path.join(root, relative))) {
      languageRecords.push({language:language.lang, pie:pie.pieKey, contentHash:pie.hash, cached:false});
      continue;
    }
    const current = readJson(relative, `${language.lang}-${pie.pieKey}.json`);
    const oldPath = path.join(audit, 'decoded', `${language.lang}-${pie.pieKey}.json`);
    const old = fs.existsSync(oldPath) ? JSON.parse(fs.readFileSync(oldPath,'utf8')) : null;
    const nowProps = current.json.properties ?? current.json;
    const oldProps = old?.properties ?? old ?? {};
    const classic = Object.entries(nowProps).filter(([k]) => k.startsWith('prison.classic.'));
    const changed = Object.entries(nowProps).filter(([k,v]) => Object.hasOwn(oldProps,k) && oldProps[k] !== v)
      .map(([key,text]) => ({key,previousText:oldProps[key],text}));
    const added = Object.entries(nowProps).filter(([k]) => !Object.hasOwn(oldProps,k)).map(([key,text]) => ({key,text}));
    const removed = Object.keys(oldProps).filter(k => !Object.hasOwn(nowProps,k));
    const {json,...metadata} = current;
    languageRecords.push({language:language.lang,pie:pie.pieKey,contentHash:pie.hash,cached:true,...metadata,
      propertyCount:Object.keys(nowProps).length,classicPropertyCount:classic.length,
      added,changed,removed});
  }
}
const cacheFiles = [];
function walk(folder) {
  for (const e of fs.readdirSync(folder,{withFileTypes:true})) {
    const p = path.join(folder,e.name);
    if(e.isDirectory()) walk(p); else cacheFiles.push(p);
  }
}
walk(path.join(root,'cache'));
const cacheCounts = {};
for (const p of cacheFiles) {
  const category = path.relative(path.join(root,'cache'),p).split(path.sep)[0];
  cacheCounts[category] = (cacheCounts[category] ?? 0)+1;
}
const {json:ignoredA,...addonIndex} = addons;
const {json:ignoredL,...languageIndex} = langs;
const result = {checkedDate:'2026-10-20', scope:'Public addon/language cache only. No game logs, account/session data or process memory read.',
  addonIndex,languageIndex,addonComparison,languageRecords,cacheCounts,
  cacheModsDirectoryPresent:fs.existsSync(path.join(root,'cache/mods')),
  limitation:'Unchanged cache or absent cache/mods does not prove absence of in-memory server-delivered modules or server configuration.'};
write('cache-reaudit.json',result);
console.log(JSON.stringify({addonComparison,languages:languageRecords.map(({language,pie,cached,propertyCount,classicPropertyCount,added,changed,removed}) =>
  ({language,pie,cached,propertyCount,classicPropertyCount,added:added?.length,changed:changed?.length,removed:removed?.length})),cacheCounts,
  cacheModsDirectoryPresent:result.cacheModsDirectoryPresent},null,2));
