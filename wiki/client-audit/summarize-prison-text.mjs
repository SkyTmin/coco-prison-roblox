import fs from 'node:fs';
const base='C:/Users/user/Documents/roblox-prison-research/client-audit/decoded/';
const data=JSON.parse(fs.readFileSync(base+'ru_RU-prison.json','utf8')).properties;
const groups={};
for(const key of Object.keys(data)) {
  const group=key.split('.').slice(0,3).join('.');
  groups[group]=(groups[group]??0)+1;
}
const terms=/disease|toilet|hygiene|soap|sleep|wiki|help|gang|career|drill|oil|boss|faction|six|sieve|шест[её]р|бур|нефт|туалет|помы|мыло|спать|жажд|голод|устал|болезн|фракци|карьер|просеив/i;
const selected=Object.entries(data).filter(([key,value])=>terms.test(key+' '+JSON.stringify(value)));
fs.writeFileSync(base+'prison-text-matches.json',JSON.stringify(Object.fromEntries(selected),null,2)+'\n');
console.log(JSON.stringify({count:Object.keys(data).length,groups:Object.entries(groups).sort((a,b)=>b[1]-a[1]).slice(0,35),sample:Object.entries(data).slice(0,3),matches:selected.length,examples:selected.slice(0,32)},null,2));
