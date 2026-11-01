"""Report actual support contacts without opening Blender's GUI."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import bpy
from mathutils import Vector
import skeleton_king as spec
from blockmob import Mob
mob=Mob(vars(spec));joints,order=mob.scene_joints();mob.pose(joints,order,'death',150.24)
out={}
for o in bpy.data.objects:
 if o.name.startswith('Part_'):
  key=o.parent.name;out[key]=min(out.get(key,1e9),min((o.matrix_world@Vector(v)).z for v in o.bound_box))
print('SUPPORT',sorted(out.items(),key=lambda x:x[1]))
assert abs(min(out.values()))<.03
assert min(out['Joint_head'],out['Joint_jaw'])<.3,'skull must relax near the floor after the shoulder lands'
