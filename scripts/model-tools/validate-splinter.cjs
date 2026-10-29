// Export contract: catches missing joints, broken quaternions, truncated subframes and mismatched cast timing.
const fs = require('node:fs');
const assert = require('node:assert/strict');
const source = JSON.parse(fs.readFileSync('scripts/design-decisions.json', 'utf8')).bosses.splinter;
const fight = source.fight;
for (const name of ['splinter', 'splinter_spider']) {
  const text = fs.readFileSync(`src/shared/Models/${name}.json`, 'utf8');
  assert(text.length < 190000, `${name}: Roblox ModuleScript size budget`);
  const model = JSON.parse(text);
  const names = new Set();
  for (const joint of model.joints) {
    assert(!names.has(joint.name), 'duplicate joint');
    assert(!joint.parent || names.has(joint.parent), 'parent must precede child');
    names.add(joint.name);
    assert(joint.pivot.every(Number.isFinite));
  }
  assert(model.parts.length <= 500, 'mobile part budget');
  for (const p of model.parts) {
    const size = Array.isArray(p) ? p.slice(4, 7) : p.size;
    const joint = Array.isArray(p) ? model.jointNames[p[0]] : p.joint;
    assert(names.has(joint));
    assert(size.every(v => Number.isFinite(v) && v > 0));
  }
  for (const [clip, value] of Object.entries(model.clips)) {
    assert(value.length > 0);
    for (const [joint, keys] of Object.entries(value.tracks)) {
      assert(names.has(joint), `${clip}: unknown joint`);
      let last = -1;
      for (const key of keys) {
        assert(key.t > last && key.t <= value.length + .0001);
        last = key.t;
        assert(key.p.every(Number.isFinite));
        assert(Math.abs(Math.hypot(...key.q) - 1) < .0001, 'normalized quaternion');
      }
      assert(Math.abs(last - value.length) < .0001, `${clip}: last key`);
      if (value.loop) {
        assert.deepEqual(keys[0].p, keys.at(-1).p, `${clip}: seamless position`);
        assert(Math.abs(keys[0].q.reduce((s,q,i)=>s+q*keys.at(-1).q[i],0)) > .99999, `${clip}: seamless rotation`);
      }
    }
  }
  if (name === 'splinter') {
    for (const [clip, seconds] of Object.entries({melee:1,swoop:1.1,potion:1.55,shoot:2.25,summon:4,death:4})) {
      assert.equal(model.clips[clip].length, seconds, `${clip}: wiki duration`);
      assert.equal(clip === 'death' ? fight.splinter.deathDuration : fight.splinter[clip].duration, seconds);
      assert(!model.clips[clip].loop);
    }
    assert.equal(fight.glowBrightness, 0);
    assert(fight.splinter.melee.hitAt < 1);
    for (const clip of ['potion','shoot','summon']) assert(fight.splinter[clip].release < model.clips[clip].length);
    assert(fight.splinter.swoop.windup + fight.splinter.swoop.travel < 1.1);
    assert(fight.abilityCooldown * fight.phase2CooldownScale > 4, 'no overlapping movement locks');
    assert(fight.splinter.summon.maxAlive <= 6);
    assert.equal(fight.texture, JSON.parse(fs.readFileSync('assets/models/rat/ids.json','utf8'))['fur-noise.png']);
  }
  console.log(`${name}: ${model.parts.length} parts, ${names.size} joints, ${Object.keys(model.clips).length} clips, ${text.length} chars — OK`);
}
// Generated configuration must agree with the source of truth (generator shape supports direct or nested maps).
const generated = JSON.parse(fs.readFileSync('src/shared/Config/bosses.json', 'utf8'));
const entry = Array.isArray(generated.bosses) ? generated.bosses.find(b => b.id === 'splinter')
  : (generated.bosses?.splinter || generated.splinter);
assert.deepEqual(entry.fight.splinter, fight.splinter);
console.log('Wiki timings, rig integrity, movement locks and generated config — OK');
