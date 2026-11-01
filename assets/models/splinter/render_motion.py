"""Headless review of the EXPORTED Roblox clips, not just the Blender source curves.
blender -b splinter.blend -t 4 -P render_motion.py
Writes frames to ignored render-frames; assemble_motion.py makes deliverable sheets/GIFs.
"""
import json
import math
import os
import sys
import bpy
from mathutils import Vector, Quaternion
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import splinter as spec
from blockmob import Mob, P, srgb

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
max_pos=0; max_angle=0; death_floor=[]; worst_pos=None; worst_angle=None; socket_error=0
walk_stance_error=0
final_torso_floor=None; death_start_feet=None; final_support_floor=None
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
        if clip=='death':
            death_floor.append(bounds()[0][2])
            if t==0:
                death_start_feet=min((o.matrix_world @ Vector(v)).z for o in meshes
                    if o.parent.name in ['Joint_footL','Joint_footR'] for v in o.bound_box)
            if t==c['length']:
                final_torso_floor=min((o.matrix_world @ Vector(v)).z for o in meshes
                    if o.parent.name in ['Joint_body','Joint_chest'] for v in o.bound_box)
                final_support_floor=min((o.matrix_world @ Vector(v)).z for o in meshes
                    if o.name.startswith(('Part_Shoulder','Part_Haunch','Part_Torso','Part_Hump')) for v in o.bound_box)
        if clip in data.get('releaseOrigins',{}) and abs(t-data['clips'][clip]['impact'])<.00001:
            joint,offset=('handL',(0,.95,-.25)) if clip=='potion' else ('head',(0,3.15,-.2))
            point=joints[joint].matrix_world @ Vector(offset)
            expected=data['releaseOrigins'][clip]
            socket_error=max(socket_error,(point-Vector((expected[0],-expected[2],expected[1]))).length)
        if clip=='walk':
            for side,phase in [('L',t),('R',t+.5)]:
                q=phase%1
                if q<.6:
                    expected=Vector(joints['foot'+side]['pivot'])+Vector((0,.8*(1-2*q/.6),0))
                    walk_stance_error=max(walk_stance_error,(joints['foot'+side].matrix_world.translation-expected).length)
report={'parts':len(data['parts']),'joints':len(order),'clips':len(data['clips']),
        'maxLocalPositionErrorStuds':max_pos,'maxLocalRotationErrorDegrees':max_angle,
        'deathFloorMin':min(death_floor),'deathFloorMax':max(death_floor),
        'worstPositionAt':worst_pos,'worstRotationAt':worst_angle,'maxReleaseOriginErrorStuds':socket_error,
        'deathStartFeetHeight':death_start_feet,'deathFinalTorsoFloor':final_torso_floor,
        'deathFinalShoulderHipSupportHeight':final_support_floor,'maxWalkStanceErrorStuds':walk_stance_error}
with open(os.path.join(spec.HERE,'motion-validation.json'),'w',encoding='utf-8',newline='\n') as f:
    json.dump(report,f,indent=2)
    f.write('\n')
assert max_pos<.025 and max_angle<.8,report
assert min(death_floor)>-.08 and max(death_floor)<.08,report
assert socket_error<.1,report
assert walk_stance_error<.08,report
assert abs(death_start_feet)<.08 and abs(final_support_floor)<.08,report
print('MOTION_VALIDATED',report,flush=True)
if '--validate-only' in sys.argv:
    sys.exit(0)

scene,cam=mob.setup_render(720,520); scene.eevee.taa_render_samples=24
bpy.ops.mesh.primitive_plane_add(size=200, location=(0,0,-.045))
floor=bpy.context.object; floor.name='ReviewFloor'
mat=bpy.data.materials.new('ReviewFloor'); mat.diffuse_color=srgb((166,164,154))+(1,)
floor.data.materials.append(mat)
clips=[('idle',2,'Ожидание'),('walk',1,'Шаги с опорой лап'),('melee',1,'Удар когтями'),
       ('swoop',1.1,'Наскок: толчок и приземление'),('potion',1.55,'Бросок склянки'),
       ('shoot',2.25,'Плевок: вдох и выброс'),('summon',4,'Призыв пауков'),
       ('death',4,'Гибель: потеря опоры и падение')]
manifest=[]
for clip,duration,title in clips:
    # Fit a fixed camera to the entire swept pose bounds of each clip, including the raised sword.
    all_points=[]
    for j in range(math.ceil(duration*10)+1):
        exported(clip,min(j/10,duration))
        lo,hi=bounds()
        all_points += [Vector((x,y,z)) for x in [lo[0],hi[0]] for y in [lo[1],hi[1]] for z in [lo[2],hi[2]]]
    center=sum(all_points,Vector())/len(all_points)
    view=Vector((22,29,13)).normalized()
    cam.location=center+view*40
    cam.rotation_euler=(-view).to_track_quat('-Z','Y').to_euler()
    cam.data.type='ORTHO'
    rot=cam.rotation_euler.to_matrix()
    right,up=rot @ Vector((1,0,0)),rot @ Vector((0,1,0))
    xs=[v.dot(right) for v in all_points]; ys=[v.dot(up) for v in all_points]
    center += right*((min(xs)+max(xs))/2-center.dot(right)) + up*((min(ys)+max(ys))/2-center.dot(up))
    cam.location=center+view*40
    cam.data.ortho_scale=max(max(xs)-min(xs),(max(ys)-min(ys))*720/520)*1.15
    count=math.ceil(duration*20)
    for i in range(count+1):
        t=min(i/20,duration); exported(clip,t)
        path=os.path.join(folder,f'{len(manifest):04d}.png')
        scene.render.filepath=path; bpy.ops.render.render(write_still=True)
        manifest.append({'file':path,'clip':clip,'title':title,'seconds':t,'duration':duration})
with open(os.path.join(folder,'manifest.json'),'w',encoding='utf-8') as f: json.dump(manifest,f,ensure_ascii=False)
print('RENDERED',len(manifest),'frames',flush=True)
