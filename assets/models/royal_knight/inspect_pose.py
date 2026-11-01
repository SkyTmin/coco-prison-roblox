"""Report actual body/prop support, not just a low sword point."""
import os,sys,bpy
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import royal_knight as spec
from blockmob import Mob
mob=Mob(vars(spec));joints,order=mob.scene_joints()
for frame in [32,72,115.5]:
 mob.pose(joints,order,'death',frame);out={}
 for o in bpy.data.objects:
  if o.name.startswith('Part_'):
   key=o.parent.name;out[key]=min(out.get(key,1e9),min((o.matrix_world@Vector(v)).z for v in o.bound_box))
 print('SUPPORT',frame,sorted(out.items(),key=lambda x:x[1]),flush=True)
 assert abs(min(v for k,v in out.items() if k not in ['Joint_sword','Joint_shield']))<.03
 if frame>100:assert out['Joint_head']<.4 and min(out['Joint_shinL'],out['Joint_shinR'])<.35,'corpse must settle, not balance on one pauldron'
