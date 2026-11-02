import os,sys,bpy,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import forest_explorer as spec
from blockmob import Mob
m=Mob(vars(spec));js,order=m.scene_joints();m.pose(js,order,'death',67.2)
j=js['prop'];initial=j.rotation_euler.copy();meshes=[o for o in bpy.data.objects if o.name.startswith('Part_')and o.parent.name in ['Joint_prop','Joint_propTip']];choices=[]
for x in range(-45,46,5):
 for y in range(-45,46,5):
  j.rotation_euler=(initial.x+math.radians(x),initial.y+math.radians(y),initial.z);bpy.context.view_layer.update()
  low=min((o.matrix_world@Vector(v)).z for o in meshes for v in o.bound_box)
  if low>=.145:choices.append((x*x+y*y,low,x,y))
print('LANTERN',sorted(choices)[:5],flush=True)
