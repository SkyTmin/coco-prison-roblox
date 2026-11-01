// Offline contract checks for the exported boss; no Studio or live player state.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const text = fs.readFileSync('src/shared/Models/giant_zombie.json', 'utf8');
const d = JSON.parse(text);
const f = JSON.parse(fs.readFileSync('scripts/design-decisions.json','utf8')).bosses.giant_zombie.fight;
assert(text.length < 190000, `ModuleScript budget: ${text.length}`);
assert(d.parts.length <= 500);
const names = new Set();
for (const j of d.joints) {
  assert(!names.has(j.name)); assert(!j.parent || names.has(j.parent));
  assert(j.pivot.every(Number.isFinite)); names.add(j.name);
}
for (const name of ['chest','jaw','foreL','foreR','handL','handR','shinL','shinR','footL','footR']) assert(names.has(name));
for (const p of d.parts) {
  const joint = Array.isArray(p) ? d.jointNames[p[0]] : p.joint;
  const size = Array.isArray(p) ? p.slice(4,7) : p.size;
  assert(names.has(joint)); assert(size.every(v => v > 0 && Number.isFinite(v)));
}
let keys = 0;
const decoded = k => d.packedKeys ? {t:k[0],p:k.slice(1,4),q:k.slice(4,8)} : k;
for (const [name,c] of Object.entries(d.clips)) {
  assert(c.length > 0);
  for (const [joint,raw] of Object.entries(c.tracks)) {
    assert(names.has(joint)); const track=raw.map(decoded); let at=-1;
    for (const k of track) {
      assert(k.t > at && k.t <= c.length+.0001); at=k.t; keys++;
      assert([...k.p,...k.q].every(Number.isFinite));
      assert(Math.abs(Math.hypot(...k.q)-1)<.0001);
    }
    assert(Math.abs(at-c.length)<.0001);
    if (c.loop) {
      assert.deepEqual(track[0].p,track.at(-1).p, `${name}/${joint}: loop translation`);
      assert(Math.abs(track[0].q.reduce((a,v,i)=>a+v*track.at(-1).q[i],0))>.99998, `${name}/${joint}: loop rotation`);
    }
  }
}
assert.equal(d.clips.melee.length,f.meleeDuration);
assert.equal(d.clips.melee.impact,f.meleeHitAt);
assert.equal(d.clips.death.length,f.deathDuration);
assert.equal(d.clips.charge_raise.length,f.charge.telegraph);
assert(d.clips.charge_run.loop && !d.clips.death.loop);
for (const phase of ['blade','spikes']) {
  const hit = phase==='blade' ? 'blade_sweep' : 'spikes_slam';
  const wind = phase==='blade' ? f.lavaBlade.telegraph : f.earthSpikes.telegraph;
  assert(d.clips[hit].impact>0 && d.clips[hit].impact<wind);
}
for (const joint of ['body','chest','head','armL','armR','shinL','shinR']) {
  const track=d.clips.death.tracks[joint].map(decoded);
  assert(track.length>4, `${joint}: collapse must articulate multiple phases`);
}
const generated=JSON.parse(fs.readFileSync('src/shared/Config/bosses.json','utf8'));
const entry=Array.isArray(generated.bosses)?generated.bosses.find(b=>b.id==='giant_zombie')
  :generated.bosses?.giant_zombie||generated.giant_zombie;
assert.deepEqual(entry.fight,f);
console.log(`Zombar: ${d.parts.length} parts / ${names.size} joints / ${Object.keys(d.clips).length} clips / ${keys} keys / ${text.length} chars — OK`);
