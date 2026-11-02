import os,sys,math,bpy
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import undead_king as spec
from blockmob import Mob
m=Mob(vars(spec));js,order=m.scene_joints();m.pose(js,order,'death',90)
for side in ['L','C','R']:
 for k in [1,2,3]:
  n='cape'+side+str(k);j=js[n];initial=j.rotation_euler.x
  meshes=[o for o in bpy.data.objects if o.name.startswith('Part_') and o.parent==j]
  choices=[]
  for angle in range(-80,61,2):
   j.rotation_euler.x=initial+math.radians(angle);bpy.context.view_layer.update()
   floor=min((o.matrix_world@Vector(v)).z for o in meshes for v in o.bound_box)
   if floor>=.025:choices.append((floor,angle))
  best=min(choices)if choices else (0,0)
  j.rotation_euler.x=initial+math.radians(best[1]);bpy.context.view_layer.update()
  print('CAPE',n,best,flush=True)
