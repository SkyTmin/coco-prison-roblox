"""Headless review of the EXPORTED Roblox clips, not just the Blender source curves.
blender -b moth.blend -t 2 -P render_motion.py
Writes frames to ignored render-frames; assemble_motion.py makes deliverable sheets/GIFs.
"""
import json
import math
import os
import sys
import bpy
from mathutils import Vector, Quaternion
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import importlib
spec=importlib.import_module(sys.argv[-1])
from blockmob import Mob, P, srgb, use

mob=Mob(vars(spec)); joints,order=mob.scene_joints()
data=json.load(open(mob.json_out,encoding='utf-8'))
for name in data.get('clipFiles',[]):
    chunk=json.load(open(os.path.join(os.path.dirname(mob.json_out),name+'.json'),encoding='utf-8'))
    assert chunk['packedKeys']==data['packedKeys']
    assert not set(data['clips']).intersection(chunk['clips'])
    data['clips'].update(chunk['clips'])
if data.get('packedKeys'):
    for clip in data['clips'].values():
        for joint, keys in clip['tracks'].items():
            clip['tracks'][joint]=[{'t':k[0],'p':k[1:4],'q':k[4:8]} for k in keys]
folder=os.path.join(spec.HERE,'render-frames-'+spec.NAME); os.makedirs(folder,exist_ok=True)
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
        o=joints[name]
        if o.animation_data and o.animation_data.action is not None:o.animation_data.action=None
        base=Vector(o['pivot'])-(Vector(o.parent['pivot']) if o.parent else Vector())
        keys=data['clips'][clip]['tracks'].get(name)
        p,q=sample(keys,t) if keys else ((0,0,0),Quaternion())
        o.location=base+Vector((p[0],-p[2],p[1]))
        o.rotation_euler=(P.transposed() @ q.to_matrix() @ P).to_euler()
    bpy.context.view_layer.update()

def bounds():
    vs=[o.matrix_world @ Vector(v) for o in meshes for v in o.bound_box]
    return [min(v[i] for v in vs) for i in range(3)],[max(v[i] for v in vs) for i in range(3)]

max_pos=max_angle=stance_error=0
floors={n:[] for n in getattr(spec,'GROUND_CLIPS',[])};body_floor=[]
for clip,c in data['clips'].items():
    # Bind each Blender action once, then sample the reference curve in a batch.
    # Rebinding all joints for every frame forces expensive dependency-graph rebuilds.
    times=[min(i/60,c['length']) for i in range(math.ceil(c['length']*60)+1)]
    truth_frames=[]
    for n in order:use(joints[n],bpy.data.actions.get(clip+'|'+n))
    for t in times:
        f=t*30;bpy.context.scene.frame_set(int(f),subframe=f-int(f))
        truth_frames.append({n:(joints[n].location.copy(),joints[n].rotation_euler.to_quaternion()) for n in order})
    for t,truth in zip(times,truth_frames):
        exported(clip,t)
        for n,(p,q) in truth.items():
            max_pos=max(max_pos,(p-joints[n].location).length)
            dot=min(1,abs(q.dot(joints[n].rotation_euler.to_quaternion())))
            max_angle=max(max_angle,math.degrees(2*math.acos(dot)))
        if clip in floors:floors[clip].append(bounds()[0][2])
        if clip=='death' and t>=c['length']*.85:
            body_floor.append(min((o.matrix_world @ Vector(v)).z for o in meshes if o.parent.name in ['Joint_body','Joint_chest','Joint_head'] for v in o.bound_box))
        if clip=='walk' and spec.NAME == 'vecna_stalker':
            length,stride,stance=(1.0,1.05,.6)
            for side,phase in [('L',0),('R',.5)]:
                q=(t/length+phase)%1
                if q<stance:
                    n='foot'+side
                    expected=Vector(joints[n]['pivot'])+Vector((0,stride*(1-2*q/stance),0))
                    stance_error=max(stance_error,(joints[n].matrix_world.translation-expected).length)
        if clip=='walk' and spec.NAME == 'vecna_hound':
            for n,phase in [('FrontL',0),('BackR',0),('FrontR',.5),('BackL',.5)]:
                q=(t/.6+phase)%1
                if q<.6:
                    joint='foot'+n
                    expected=Vector(joints[joint]['pivot'])+Vector((0,.6*(1-2*q/.6),0))
                    stance_error=max(stance_error,(joints[joint].matrix_world.translation-expected).length)
report={'parts':len(data['parts']),'joints':len(order),'clips':len(data['clips']),
 'maxLocalPositionErrorStuds':max_pos,'maxLocalRotationErrorDegrees':max_angle,
 'maxWalkStanceErrorStuds':stance_error,'deathBodyFloor':[min(body_floor),max(body_floor)] if body_floor else [],
 'floorByClip':{n:[min(v),max(v)] for n,v in floors.items()}}
with open(os.path.join(spec.HERE,spec.NAME+'-validation.json'),'w',newline='\n') as f:json.dump(report,f,indent=2);f.write('\n')
print('MOTION_VALIDATED',report,flush=True)
assert max_pos<.025 and max_angle<.8,report
assert stance_error<.08,report
assert not body_floor or max(abs(v) for v in body_floor)<.08,report
assert all(max(abs(x) for x in v)<.08 for v in floors.values()),report
if '--validate-only' in sys.argv:sys.exit(0)

scene,cam=mob.setup_render(640,480);scene.eevee.taa_render_samples=12
bpy.ops.mesh.primitive_plane_add(size=200,location=(0,0,-.045))
floor=bpy.context.object;floor.name='ReviewFloor'
mat=bpy.data.materials.new('ReviewFloor');mat.diffuse_color=srgb((166,164,154))+(1,);floor.data.materials.append(mat)
clips=[(n,c['length'],n) for n,c in data['clips'].items()]
manifest=[]
if '--lifecycle-only' in sys.argv:
    names=['spawn','death']
    clips=[c for c in clips if c[0] in names]
    with open(os.path.join(folder,'manifest.json'),encoding='utf8') as f:
        manifest=[r for r in json.load(f) if r['clip'] not in names]
if '--death-only' in sys.argv:
    clips=[c for c in clips if c[0]=='death']
    with open(os.path.join(folder,'manifest.json'),encoding='utf8') as f:
        manifest=[r for r in json.load(f) if r['clip']!='death']
for clip,duration,title in clips:
    points=[]
    for j in range(math.ceil(duration*10)+1):
        exported(clip,min(j/10,duration));lo,hi=bounds()
        points += [Vector((x,y,z)) for x in [lo[0],hi[0]] for y in [lo[1],hi[1]] for z in [lo[2],hi[2]]]
    view=Vector((18,27,12)).normalized();cam.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler();cam.data.type='ORTHO'
    rot=cam.rotation_euler.to_matrix();right,up=rot @ Vector((1,0,0)),rot @ Vector((0,1,0))
    xs=[v.dot(right) for v in points];ys=[v.dot(up) for v in points]
    center=sum(points,Vector())/len(points)
    center+=right*((min(xs)+max(xs))/2-center.dot(right))+up*((min(ys)+max(ys))/2-center.dot(up))
    cam.location=center+view*40;cam.data.ortho_scale=max(max(xs)-min(xs),(max(ys)-min(ys))*640/480)*1.13
    for i in range(math.ceil(duration*16)+1):
        t=min(i/16,duration);exported(clip,t)
        path=os.path.join(folder,f'{clip}-{i:04d}.png');scene.render.filepath=path;bpy.ops.render.render(write_still=True)
        manifest.append({'file':path,'clip':clip,'title':title,'seconds':t,'duration':duration})
with open(os.path.join(folder,'manifest.json'),'w',encoding='utf8') as f:json.dump(manifest,f,ensure_ascii=False)
print('RENDERED',len(manifest),'frames',flush=True)
