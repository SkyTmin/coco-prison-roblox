// Offline rig/animation/config contract. Live damage and cancellation are checked by qa-basalt-runtime.luau.
const fs=require('node:fs'), assert=require('node:assert/strict');
const text=fs.readFileSync('src/shared/Models/basalt_guardian.json','utf8'), d=JSON.parse(text);
const card=JSON.parse(fs.readFileSync('scripts/design-decisions.json','utf8')).bosses.basalt_guardian;
const f=card.fight;
const audit=JSON.parse(fs.readFileSync('wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json','utf8'))['basalt/basalt_guardian.model'].anims;
assert(text.length<190000,'ModuleScript size budget'); assert(d.parts.length<=500);
const names=new Set();
for(const j of d.joints){assert(!names.has(j.name));assert(!j.parent||names.has(j.parent));names.add(j.name);assert(j.pivot.every(Number.isFinite));}
for(const name of ['sword','chest','foreL','foreR','handL','handR','shinL','shinR','pauldronL','pauldronR'])assert(names.has(name));
for(const p of d.parts){assert(names.has(Array.isArray(p)?d.jointNames[p[0]]:p.joint));assert((Array.isArray(p)?p.slice(4,7):p.size).every(v=>v>0&&Number.isFinite(v)));}
const decode=k=>d.packedKeys?{t:k[0],p:k.slice(1,4),q:k.slice(4,8)}:k;
let total=0;
for(const [name,c] of Object.entries(d.clips)){
  assert(c.length>0);
  for(const [joint,raw] of Object.entries(c.tracks)){
    assert(names.has(joint));const keys=raw.map(decode);let at=-1;
    for(const k of keys){assert(k.t>at&&k.t<=c.length+.0001);at=k.t;total++;assert([...k.p,...k.q].every(Number.isFinite));assert(Math.abs(Math.hypot(...k.q)-1)<.0001);}
    assert(Math.abs(at-c.length)<.0001);
    if(c.loop){assert.deepEqual(keys[0].p,keys.at(-1).p);assert(Math.abs(keys[0].q.reduce((s,q,i)=>s+q*keys.at(-1).q[i],0))>.99998,`${name}/${joint} loop`);}
  }
}
for(const name of ['idle','walk','sword_slash','sword_smash','sword_spike','death']) assert.equal(d.clips[name].length,audit[name].len,`${name} audited length`);
assert.equal(d.clips.melee.length,audit.attack_1.len);
assert.equal(d.clips.melee.length,f.meleeDuration);assert.equal(d.clips.melee.impact,f.meleeHitAt);
assert.equal(f.deathDuration,d.clips.death.length);
for(const name of ['sword_slash','sword_smash','sword_spike']){
  const c=f.basalt[name];assert.equal(c.duration,d.clips[name].length);assert.equal(c.release,d.clips[name].impact);
  assert(c.release>0&&c.release<c.duration);assert.equal(c.damage,.5);
  assert(c.duration<f.abilityCooldown*f.phase2CooldownScale);
}
assert(f.basalt.sword_slash.release+f.basalt.sword_slash.length/f.basalt.sword_slash.speed<f.basalt.sword_slash.duration);
assert.equal(card.hp,200);assert.equal(f.meleeDamage,.2);assert.equal(card.respawnSeconds,1200);
assert.equal(f.glowBrightness,0);
assert.equal(f.texture,JSON.parse(fs.readFileSync('assets/models/basalt_guardian/ids.json','utf8'))['noise.png']);
for(const n of ['body','chest','head','armL','armR','shinL','shinR','sword'])assert(d.clips.death.tracks[n]?.length>4,`${n}: articulated collapse`);
const generated=JSON.parse(fs.readFileSync('src/shared/Config/bosses.json','utf8')).bosses.find(b=>b.id==='basalt_guardian');assert.deepEqual(generated.fight,f);
console.log(`Basalt: ${d.parts.length} parts, ${names.size} joints, ${Object.keys(d.clips).length} clips, ${total} keys, ${text.length} chars — OK`);
