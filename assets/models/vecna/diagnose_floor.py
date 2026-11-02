"""Headless review of the EXPORTED Roblox clips, not just the Blender source curves.
blender -b vecna.blend -t 2 -P render_motion.py
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
folder=os.path.join(spec.HERE,'render-frames'); os.makedirs(folder,exist_ok=True)
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


exported('death',data['clips']['death']['length'])
rows=sorted((min((o.matrix_world@Vector(v)).z for v in o.bound_box),o.name,o.parent.name) for o in meshes)
print('LOWEST',rows[:18])
print('BODY',[(z,n,j)for z,n,j in rows if j in ['Joint_body','Joint_chest','Joint_head']][:4])
