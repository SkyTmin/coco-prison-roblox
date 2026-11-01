// Decision-model audit, not a claim of a live 4–6-player playtest.
import fs from 'node:fs';
import assert from 'node:assert/strict';
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const cfg=read('src/shared/Config/bosses.json'),bosses=cfg.bosses;
const byId=Object.fromEntries(bosses.map(b=>[b.id,b]));
const wiki=read('wiki/client-audit/content-analysis/boss-menu-recovery.json');
assert.equal(bosses.length,19);assert.equal(byId.basalt_guardian.hp,280);assert.equal(byId.reaper.hp,3500);
const path=bosses.filter(b=>!['splinter','giant_zombie'].includes(b.id)).sort((a,b)=>a.unlockLevel-b.unlockLevel);
for(let i=1;i<path.length;i++){
 assert(path[i].hp>path[i-1].hp);assert(path[i].fight.meleeDamage>path[i-1].fight.meleeDamage);
 assert(path[i].fight.earthSpikes.damage>path[i-1].fight.earthSpikes.damage);
}
const sorted=[...bosses].sort((a,b)=>a.hp-b.hp);assert.equal(sorted.indexOf(byId.splinter),9,'Splinter is median of 19');
for(const b of bosses){assert(b.hp>=280&&b.hp<=3500);assert.equal(b.damage,b.fight.meleeDamage);}
for(const e of wiki.entries){
 const b=byId[e.localizationMatch?.id];assert(b,e.name);
 const r=e.possibleRewards;
 if(r.money)assert.deepEqual(b.money,[r.money.min,r.money.max]);
 if(r.ancientStars)assert.deepEqual(b.ancientStars,[r.ancientStars.min,r.ancientStars.max]);
 assert.deepEqual(b.powderChance,r.ancientPowder??null);
}
assert.deepEqual(cfg.rewards.lastHitItems.forest_guardian,['fire_shard']);
assert.deepEqual(cfg.rewards.lastHitItems.reaper,['fire_shard']);
assert.equal(byId.splinter.powderChance.percentQualifier.max,5);
const vanilla=read('src/shared/Config/tools.json').vanilla;
const armor=raw=>raw*(1-Math.min(20,Math.max(4,20-raw/(2+8/4)))/25)*(1-8*vanilla.protectionPerLevelPerPiece);
console.log('id | HP | melee raw | area raw | charge raw | regen HP/s');
for(const b of sorted)console.log([b.id,b.hp,b.fight.meleeDamage,b.fight.earthSpikes.damage,b.fight.charge.damage,b.fight.combatRegenPerSecond??0].join(' | '));
const weapon=7+4.5,attackSpeed=1.6,uptime=.45,reaper=byId.reaper;
const report={source:'[решение] analytical model; no books/potions/professions, diamond sword Sharpness VIII, 45% effective attack time',
 hp:reaper.hp,regenPerSecond:reaper.fight.combatRegenPerSecond,
 perPlayerSustainedDps:weapon*attackSpeed*uptime,
 groupSeconds:Object.fromEntries([1,4,6].map(n=>{const net=n*weapon*attackSpeed*uptime-reaper.fight.combatRegenPerSecond;return[n,net>0?Math.round(reaper.hp/net):null]})),
 level35Health:54,diamondProtection2:{melee:armor(40),area:armor(52),chargeAfterBossCap:Math.min(54*cfg.safety.maxHealthFraction,armor(64))}};
assert(report.groupSeconds[1]===null);assert(report.groupSeconds[4]>90&&report.groupSeconds[4]<240);assert(report.groupSeconds[6]>60&&report.groupSeconds[6]<180);
console.log(JSON.stringify(report,null,2));
