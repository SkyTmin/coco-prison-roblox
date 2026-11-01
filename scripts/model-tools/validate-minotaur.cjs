// Structural and timing contract for the original model, including split animation modules.
const fs=require('node:fs'),assert=require('node:assert/strict');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const base=read('src/shared/Models/minotaur.json');
let largest=0,totalChars=0,keys=0;
for(const file of ['minotaur',...base.clipFiles]){
  assert(/^minotaur(?:_[a-z]+)?$/.test(file));
  const text=fs.readFileSync(`src/shared/Models/${file}.json`,'utf8');
  assert(text.length<180000,`${file}: Roblox module budget`);
  largest=Math.max(largest,text.length);totalChars+=text.length;
  if(file==='minotaur')continue;
  const chunk=JSON.parse(text);assert.equal(chunk.packedKeys,base.packedKeys);
  for(const [name,c] of Object.entries(chunk.clips)){assert(!base.clips[name]);base.clips[name]=c;}
}
const names=new Set();
for(const j of base.joints){assert(!names.has(j.name));assert(!j.parent||names.has(j.parent));names.add(j.name);assert(j.pivot.every(Number.isFinite));}
assert(base.parts.length<=500,'mobile geometry budget');
for(const p of base.parts){
  const joint=Array.isArray(p)?base.jointNames[p[0]]:p.joint;
  const size=Array.isArray(p)?p.slice(4,7):p.size;
  assert(names.has(joint));assert(size.every(v=>Number.isFinite(v)&&v>0));
}
const audit=read('wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json');
const boss=Object.entries(audit).find(([path])=>path.endsWith('/minotaur.model'))[1].anims;
const sleeper=Object.entries(audit).find(([path])=>path.endsWith('/sleeping_minotaur.model'))[1].anims;
for(const [name,c] of Object.entries(base.clips)){
  const reference=name==='sleep'?sleeper.idle:name==='awakening'?sleeper.awakening:boss[name==='melee'?'attack_horns':name];
  if(reference)assert(Math.abs(c.length-reference.len)<.0001,`${name}: audit duration`);
  for(const [joint,track] of Object.entries(c.tracks)){
    assert(names.has(joint));let previous=-1;
    for(const k of track){assert(k.length===8&&k.every(Number.isFinite));assert(k[0]>previous&&k[0]<=c.length+.0001);previous=k[0];assert(Math.abs(Math.hypot(...k.slice(4))-1)<.0001);keys++;}
    assert(Math.abs(previous-c.length)<.0001);
    if(c.loop){
      const first=track[0].slice(4),last=track.at(-1).slice(4);
      assert.deepEqual(track[0].slice(1,4),track.at(-1).slice(1,4));
      assert(Math.abs(first.reduce((s,v,i)=>s+v*last[i],0))/(Math.hypot(...first)*Math.hypot(...last))>.99999,`${name}/${joint}: seamless loop`);
    }
  }
}
const card=read('scripts/design-decisions.json').bosses.minotaur, f=card.fight;
const generated=read('src/shared/Config/bosses.json').bosses.find(b=>b.id==='minotaur');
assert.deepEqual(generated.fight,f);assert.equal(card.hp,1000);assert.equal(card.respawnSeconds,1500);
assert.equal(f.meleeDamage,2);assert.equal(f.minotaur.impact.damage,4);
assert.equal(f.minotaur.double_attack.damage*f.minotaur.double_attack.hits.length,4);
assert.equal(f.minotaur.throws_the_ground.damage,4);assert.equal(f.minotaur.minotaur_rush.damage,5);
for(const name of ['impact','double_attack','throws_the_ground','minotaur_rush']){
  const c=f.minotaur[name];assert(Math.abs(c.duration-base.clips[name].length)<.0001);
  assert((c.release||c.hits.at(-1))<c.duration);
  assert(c.duration<f.abilityCooldown*f.phase2CooldownScale);
}
assert(f.minotaur.throws_the_ground.release+f.minotaur.throws_the_ground.flight<f.minotaur.throws_the_ground.duration);
assert(f.minotaur.minotaur_rush.release+f.minotaur.minotaur_rush.maxDistance/f.minotaur.minotaur_rush.speed<f.minotaur.minotaur_rush.duration);
assert(Math.abs(f.deathDuration-base.clips.death.length)<.0001);
assert(Math.abs(f.minotaur.awakening-base.clips.awakening.length)<.0001);
assert(Math.abs(f.minotaur.stunDuration-base.clips.stun.length)<.0001);
for(const joint of ['body','chest','head','jaw','armL','armR','shinL','shinR','chainL','chainR','tail4'])assert(base.clips.death.tracks[joint]?.length>4,`${joint}: articulated death`);
assert(base.releaseOrigins.throws_the_ground.every(Number.isFinite));
assert.equal(f.glowBrightness,0);
assert.deepEqual(fs.readFileSync('assets/models/minotaur/noise.png'),fs.readFileSync('assets/models/splinter/fur-noise.png'));
console.log(`Minotaur: ${base.parts.length} parts, ${names.size} joints, ${Object.keys(base.clips).length} clips, ${keys} keys, ${totalChars} chars, largest ${largest} — OK`);
