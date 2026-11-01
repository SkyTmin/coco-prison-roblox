// Isolated new-source runtime QA while the owner is playing; does not install or restart the game.
// node scripts/make-poseidon-source-qa.mjs > sync-qa-poseidon.luau
import { readFileSync } from 'node:fs';
const read = p => readFileSync(new URL('../'+p,import.meta.url),'utf8');
const common = read('src/server/Services/BossCast.luau');
const source = read('src/server/Services/PoseidonAbilities.luau');
const cfg = JSON.stringify(JSON.parse(read('scripts/design-decisions.json')).bosses.poseidon.fight);
const original = read('scripts/qa-poseidon-runtime.luau');
const requireLine = 'local API=require(game.ServerScriptService.Server.Services.PoseidonAbilities)';
const configLine = 'for _,c in Config.bosses.bosses do if c.id=="poseidon" then cfg=c.fight end end';
if (!original.includes(requireLine) || !original.includes(configLine) || !source.includes('require(script.Parent.BossCast)')) throw Error('QA source layout changed');
const qa=original.replace(requireLine,'local API=QA_API').replace(configLine,'cfg=game.HttpService:JSONDecode([==['+cfg+']==])');
process.stdout.write('task.spawn(function()\nlocal QA_Cast=(function()\n'+common+'\nend)()\nlocal QA_API=(function()\n'+source.replace('require(script.Parent.BossCast)','QA_Cast')+'\nend)()\n'+qa+'\nend)\nreturn "Poseidon source-snapshot QA started without restarting Play"\n');
