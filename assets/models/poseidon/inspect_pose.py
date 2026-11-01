"""Inspect real support contacts for the seated, awakening and death poses."""
import os,sys,bpy
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import poseidon as spec
from blockmob import Mob
mob=Mob(vars(spec));joints,order=mob.scene_joints()
for clip,frame in [('idle_sitting',0),('awaken',0),('death',144)]:
 mob.pose(joints,order,clip,frame);out={}
 for o in bpy.data.objects:
  if o.name.startswith('Part_'):
   key=o.parent.name;out[key]=min(out.get(key,1e9),min((o.matrix_world@Vector(v)).z for v in o.bound_box))
 print('SUPPORT',clip,frame,sorted(out.items(),key=lambda x:x[1]),flush=True)
