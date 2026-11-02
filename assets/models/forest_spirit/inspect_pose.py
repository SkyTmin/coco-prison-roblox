import os,sys,bpy
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import importlib
spec=importlib.import_module(sys.argv[-1])
from blockmob import Mob
m=Mob(vars(spec));joints,order=m.scene_joints();m.pose(joints,order,'death',186 if spec.NAME=='forest_spirit' else 67.2)
rows=[]
for o in bpy.data.objects:
 if o.name.startswith('Part_'):
  rows.append((min((o.matrix_world@Vector(v)).z for v in o.bound_box),o.name,o.parent.name))
print('LOWEST',sorted(rows)[:25],flush=True)
scene,cam=m.setup_render(640,480)
cam.location=(14,20,12);cam.rotation_euler=(Vector((0,0,3))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=os.path.join(spec.HERE,spec.NAME+'-inspect-death.png');bpy.ops.render.render(write_still=True)
