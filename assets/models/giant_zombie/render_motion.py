"""Headless review of the EXPORTED Roblox clips, not just the Blender source curves.
blender -b giant_zombie.blend -t 4 -P render_motion.py
Writes frames to ignored render-frames; assemble_motion.py makes deliverable sheets/GIFs.
"""
import json
import math
import os
import sys
import bpy
from mathutils import Vector, Quaternion
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import giant_zombie as spec
from blockmob import Mob, P, srgb

mob=Mob(vars(spec)); joints,order=mob.scene_joints()
data=json.load(open(mob.json_out,encoding='utf-8'))
if data.get('packedKeys'):
    for clip in data['clips'].values():
        for joint, keys in clip['tracks'].items():
            clip['tracks'][joint]=[{'t':k[0],'p':k[1:4],'q':k[4:8]} for k in keys]
folder=os.path.join(spec.HERE,'render-frames-v2'); os.makedirs(folder,exist_ok=True)
meshes=[o for o in bpy.data.objects if o.name.startswith('Part_')]

def sample(keys,t):
    if t<=keys[0]['t']: return keys[0]['p'],Quaternion((keys[0]['q'][3],*keys[0]['q'][:3])).normalized()
    a=keys[0]
    for b in keys[1:]:
        if t<=b['t']:
            w=(t-a['t'])/(b['t']-a['t'])
            qa=Quaternion((a['q'][3],*a['q'][:3])).normalized()
            qb=Quaternion((b['q'][3],*b['q'][:3])).normalized()
            return Vector(a['p']).lerp(Vector(b['p']),w),qa.slerp(qb,w)
        a=b
    return a['p'],Quaternion((a['q'][3],*a['q'][:3])).normalized()

def exported(clip,t):
    for name in order:
        o=joints[name]; o.animation_data.action=None
        base=Vector(o['pivot'])-(Vector(o.parent['pivot']) if o.parent else Vector())
        keys=data['clips'][clip]['tracks'].get(name)
        p,q=sample(keys,t) if keys else ((0,0,0),Quaternion())
        o.location=base+Vector((p[0],-p[2],p[1]))
        o.rotation_euler=(P.transposed() @ q.to_matrix() @ P).to_euler()
    bpy.context.view_layer.update()

def bounds():
    vs=[o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    return [min(v[i] for v in vs) for i in range(3)],[max(v[i] for v in vs) for i in range(3)]

# Validate the full exported motion at 60 Hz against the Blender source, including between baked keys.
max_pos=0; max_angle=0; death_floor=[]; worst_pos=None; worst_angle=None
for clip,c in data['clips'].items():
    for i in range(math.ceil(c['length']*60)+1):
        t=min(i/60,c['length'])
        mob.pose(joints,order,clip,t*30)
        truth={n:(joints[n].location.copy(),joints[n].rotation_euler.to_quaternion()) for n in order}
        exported(clip,t)
        for n in order:
            pos,q=truth[n]
            err=(pos-joints[n].location).length
            if err>max_pos: max_pos=err; worst_pos=(clip,n,t)
            dot=min(1,abs(q.dot(joints[n].rotation_euler.to_quaternion())))
            err=math.degrees(2*math.acos(dot))
            if err>max_angle: max_angle=err; worst_angle=(clip,n,t)
        if clip=='death': death_floor.append(bounds()[0][2])
report={'parts':len(data['parts']),'joints':len(order),'clips':len(data['clips']),
        'maxLocalPositionErrorStuds':max_pos,'maxLocalRotationErrorDegrees':max_angle,
        'deathFloorMin':min(death_floor),'deathFloorMax':max(death_floor),
        'worstPositionAt':worst_pos,'worstRotationAt':worst_angle}
with open(os.path.join(spec.HERE,'motion-validation.json'),'w') as f: json.dump(report,f,indent=2)
assert max_pos<.025 and max_angle<.8,report
assert min(death_floor)>-.08 and max(death_floor)<.08,report
print('MOTION_VALIDATED',report,flush=True)

scene,cam=mob.setup_render(720,520); scene.eevee.taa_render_samples=24
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.045))
floor=bpy.context.object; floor.name='ReviewFloor'
mat=bpy.data.materials.new('ReviewFloor'); mat.diffuse_color=srgb((166,164,154))+(1,)
floor.data.materials.append(mat)
clips=[('idle',2.0,'Ожидание'),('walk',1.5,'Тяжёлая походка'),('melee',1.32,'Ближний удар'),
       ('blade_raise',1.0667,'Подготовка плевка'),('blade_sweep',.9,'Рвота гноем'),
       ('spikes_raise',1.2,'Замах над землёй'),('spikes_slam',.6,'Удар о землю'),
       ('charge_raise',1,'Подготовка тарана'),('charge_run',.8,'Таран'),('stunned',2,'Оглушение'),
       ('death',3.2,'Гибель: колени → рука → плечо')]
manifest=[]
for clip,duration,title in clips:
    target=(0,2,3.4) if clip=='death' else (0,.2,5.2)
    mob.perspective(cam,((-18,25,13),target,42 if clip=='death' else 48))
    count=math.ceil(duration*20)
    for i in range(count+1):
        t=min(i/20,duration); exported(clip,t)
        path=os.path.join(folder,f'{len(manifest):04d}.png')
        scene.render.filepath=path; bpy.ops.render.render(write_still=True)
        manifest.append({'file':path,'clip':clip,'title':title,'seconds':t,'duration':duration})
with open(os.path.join(folder,'manifest.json'),'w',encoding='utf-8') as f: json.dump(manifest,f,ensure_ascii=False)
print('RENDERED',len(manifest),'frames',flush=True)
