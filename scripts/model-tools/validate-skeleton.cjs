const fs=require('node:fs'),assert=require('node:assert/strict');
const read=p=>JSON.parse(fs.readFileSync(p,'utf8'));
const base=read('src/shared/Models/skeleton_king.json'),clips={...base.clips};let total=0,largest=0,keys=0;
for(const name of ['skeleton_king',...base.clipFiles]){
 const text=fs.readFileSync('src/shared/Models/'+name+'.json','utf8');assert(text.length<190000);total+=text.length;largest=Math.max(largest,text.length);
 if(name!=='skeleton_king')Object.assign(clips,JSON.parse(text).clips);
}
const joints=new Set();for(const j of base.joints){assert(!joints.has(j.name));assert(!j.parent||joints.has(j.parent));joints.add(j.name);}
assert.equal(base.parts.length,570);assert.equal(joints.size,36);assert.equal(Object.keys(clips).length,12);
for(const [name,c] of Object.entries(clips))for(const [joint,track] of Object.entries(c.tracks)){
 assert(joints.has(joint));let previous=-1;
 for(const k of track){assert(k.length===8&&k.every(Number.isFinite));assert(k[0]>previous&&k[0]<=c.length+.0001);previous=k[0];keys++;assert(Math.abs(Math.hypot(...k.slice(4))-1)<.0001);}
 assert(Math.abs(previous-c.length)<.0001);
 if(c.loop){assert.deepEqual(track[0].slice(1,4),track.at(-1).slice(1,4));assert(Math.abs(track[0].slice(4).reduce((s,v,i)=>s+v*track.at(-1)[i+4],0))>.9999,name+' loop');}
}
const audit=read('wiki/client-audit/content-analysis/resourcepack/boss-model-animations.json');
for(const [name,c] of Object.entries(audit['skeleton/skeleton.model'].anims))assert.equal(clips[name].length,c.len,name+' audited duration');
const card=read('scripts/design-decisions.json').bosses.skeleton,f=card.fight;
assert.equal(card.hp,740);assert.equal(f.model,'skeleton_king');assert.equal(f.glowBrightness,0);assert.equal(f.deathDuration,clips.death.length);
for(const name of ['atkrswipe','atklswipe','sklrstomp','skllstomp','sklpoisonbreath','sklroar']){
 assert.equal(f.skeleton[name].duration,clips[name].length);assert.equal(f.skeleton[name].release,clips[name].impact);assert(f.skeleton[name].release<clips[name].length);
}
for(const name of ['sklrstomp','skllstomp','sklpoisonbreath'])assert((f.skeleton[name].ticks-1)*f.skeleton[name].tickInterval<f.skeleton[name].lifetime);
const minion=read('src/shared/Models/skeleton_minion.json');assert(minion.parts.length<100);assert(Math.abs(minion.clips.bite.impact-f.skeleton.sklroar.hitAt)<1e-6);
for(const [name,c] of Object.entries(audit['skeleton/skeleton_minion.model'].anims))assert.equal(minion.clips[name==='atk'?'bite':name].length,c.len);
assert.deepEqual(read('src/shared/Config/bosses.json').bosses.find(b=>b.id==='skeleton').fight,f);
const v=read('assets/models/skeleton_king/motion-validation.json');assert(v.maxLocalPositionErrorStuds<.025&&v.maxLocalRotationErrorDegrees<.8&&v.maxWalkStanceErrorStuds<.08);assert(v.deathBodyFloor.every(x=>Math.abs(x)<.08));
assert(fs.readFileSync('assets/models/skeleton_king/noise.png').equals(fs.readFileSync('assets/models/minotaur/noise.png')),'reused texture must be identical');
const rib=base.parts.find(p=>p.name==='RibL2_3');assert(rib&&rib.rot,'actual rotated rib geometry');assert(Math.min(...rib.size)<.3,'thin skeletal ribs retained');
console.log(`Skeleton: ${base.parts.length} parts, ${joints.size} joints, ${Object.keys(clips).length} clips, ${keys} keys; ${total} chars, largest ${largest}; minion ${minion.parts.length} parts — OK`);
