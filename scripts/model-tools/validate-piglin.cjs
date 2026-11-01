const fs=require('node:fs'),assert=require('node:assert/strict');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const base=read('src/shared/Models/piglin_king.json');
const clips={...base.clips};let total=0,largest=0,keys=0;
for(const name of ['piglin_king',...base.clipFiles]){
 const text=fs.readFileSync('src/shared/Models/'+name+'.json','utf8');assert(text.length<190000);total+=text.length;largest=Math.max(largest,text.length);
 if(name!=='piglin_king')Object.assign(clips,JSON.parse(text).clips);
}
const joints=new Set();for(const j of base.joints){assert(!joints.has(j.name));assert(!j.parent||joints.has(j.parent));joints.add(j.name);}
assert(base.parts.length<=750);assert.equal(joints.size,33);assert.equal(Object.keys(clips).length,16);
for(const [name,c] of Object.entries(clips))for(const [joint,track] of Object.entries(c.tracks)){
 assert(joints.has(joint));let previous=-1;
 for(const k of track){assert(k.length===8&&k.every(Number.isFinite));assert(k[0]>previous&&k[0]<=c.length+.0001);previous=k[0];keys++;assert(Math.abs(Math.hypot(...k.slice(4))-1)<.0001);}
 assert(Math.abs(previous-c.length)<.0001);
 if(c.loop){assert.deepEqual(track[0].slice(1,4),track.at(-1).slice(1,4));assert(Math.abs(track[0].slice(4).reduce((s,v,i)=>s+v*track.at(-1)[i+4],0))>.9999,name+' loop');}
}
const audit=read('wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json')['piglin/piglin_glutton.model'].anims;
for(const [name,c] of Object.entries(audit))assert.equal(clips[name].length,c.len,name+' audited duration');
const card=read('scripts/design-decisions.json').bosses.piglin,f=card.fight;
assert.equal(f.model,'piglin_king');assert.equal(f.glowBrightness,0);assert.equal(f.deathDuration,clips.death.length);
for(const name of ['verticalatk','horizontalatk','footstomp','spinslam','bodyslam','upchuck','summoningchant','healing','charge']){
 assert.equal(f.piglin[name].duration,clips[name].length);assert.equal(f.piglin[name].release,clips[name].impact);assert(f.piglin[name].release<clips[name].length);
}
assert(f.piglin.upchuck.release+f.piglin.upchuck.flight+f.piglin.upchuck.ticks*f.piglin.upchuck.tickInterval<f.piglin.upchuck.duration);
const guard=read('src/shared/Models/piglin_guard.json');assert(guard.parts.length<150);assert.equal(guard.clips.bite.impact,f.piglin.summoningchant.hitAt);
assert.deepEqual(read('src/shared/Config/bosses.json').bosses.find(b=>b.id==='piglin').fight,f);
const v=read('assets/models/piglin_king/motion-validation.json');assert(v.maxLocalPositionErrorStuds<.025&&v.maxLocalRotationErrorDegrees<.8&&v.maxWalkStanceErrorStuds<.08);assert(v.deathBodyFloor.every(x=>Math.abs(x)<.08));assert(v.deathDroppedAxeFloor.every(x=>Math.abs(x)<.08));
assert(fs.readFileSync('assets/models/piglin_king/noise.png').equals(fs.readFileSync('assets/models/minotaur/noise.png')),'reused texture must be identical');
console.log(`Piglin: ${base.parts.length} parts, ${joints.size} joints, ${Object.keys(clips).length} clips, ${keys} keys; ${total} chars, largest ${largest}; guard ${guard.parts.length} parts — OK`);
