import fs from 'node:fs';
import path from 'node:path';
import { zstdDecompressSync } from 'node:zlib';

const root = 'C:/Users/user/.cristalix/updates/Minigames';
const output = 'C:/Users/user/Documents/roblox-prison-research/client-audit/decoded';
fs.mkdirSync(output, { recursive: true });
const compressed = b => b.subarray(0, 4).equals(Buffer.from([0x28, 0xb5, 0x2f, 0xfd]));
function inspect(relative, name) {
  const source = path.join(root, relative);
  const input = fs.readFileSync(source);
  const data = compressed(input) ? zstdDecompressSync(input, { maxOutputLength: 64 * 1024 * 1024 }) : input;
  const result = { relative, compressedBytes: input.length, decodedBytes: data.length, magic: data.subarray(0, 16).toString('hex') };
  try {
    const jsonOffset = data.subarray(0, 4).toString('ascii') === 'CXOD' ? data.indexOf(Buffer.from('{"')) : 0;
    const parsed = JSON.parse(data.subarray(jsonOffset).toString('utf8'));
    result.jsonOffset = jsonOffset;
    result.kind = 'json';
    result.keys = Object.keys(parsed).slice(0, 14);
    result.sample = Object.entries(parsed).slice(0, 3).map(([key, value]) => ({ key, type: typeof value, keys: value && typeof value === 'object' ? Object.keys(value).slice(0, 16) : [] }));
    fs.writeFileSync(path.join(output, name + '.json'), JSON.stringify(parsed, null, 2) + '\n');
  } catch {
    result.kind = data[0] === 0x50 && data[1] === 0x4b ? 'zip' : 'binary';
    fs.writeFileSync(path.join(output, name + (result.kind === 'zip' ? '.zip' : '.bin')), data);
  }
  return result;
}
const results = [inspect('cache/addons/addons.json', 'addons-index'), inspect('cache/lang/lang.json', 'lang-index')];
function walk(folder) {
  return fs.readdirSync(folder, { withFileTypes: true }).flatMap(e => e.isDirectory() ? walk(path.join(folder, e.name)) : [path.join(folder, e.name)]);
}
for (const source of walk(path.join(root, 'cache/addons')).filter(f => !f.endsWith('.json'))) {
  results.push(inspect(path.relative(root, source), 'addon-' + path.basename(source).slice(0, 12)));
}
const langIndex = JSON.parse(fs.readFileSync(path.join(output, 'lang-index.json'), 'utf8'));
for (const language of langIndex.langs.filter(l => ['ru_RU', 'en_US'].includes(l.lang))) {
  for (const pie of language.pies.filter(p => ['prison', 'prisonevo'].includes(p.pieKey))) {
    const relative = path.join('cache/lang', pie.hash.slice(0, 2), pie.hash.slice(2, 4), pie.hash);
    if (fs.existsSync(path.join(root, relative))) results.push(inspect(relative, language.lang + '-' + pie.pieKey));
    else results.push({ relative, missing: true, language: language.lang, pie: pie.pieKey });
  }
}
fs.writeFileSync(path.join(output, 'inspection.json'), JSON.stringify(results, null, 2) + '\n');
console.log(JSON.stringify(results, null, 2));
