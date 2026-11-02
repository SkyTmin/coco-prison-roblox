"""Compare final arm support against the trunk before baking the complete action set."""
import os,sys,math,bpy
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import forest_spirit as spec
from blockmob import Mob
source=open(os.path.join(spec.HERE,'forest_motion.py'),encoding='utf8').read()
mob=Mob(vars(spec));joints,order=mob.scene_joints()
for height in [.25,.4,.5,.6,.7]:
 namespace={};exec(source.replace('surface+.5','surface+'+str(height)),namespace)
 p=namespace['make_actions'](spec.JOINTS)['death'][0][-1][1]
 for n in order:
  obj=joints[n]
  if obj.animation_data:obj.animation_data.action=None
  value=p.get(n,(0,0,0,None));base=Vector(obj['pivot'])-(Vector(obj.parent['pivot']) if obj.parent else Vector())
  obj.location=base+Vector(value[3] or (0,0,0));obj.rotation_euler=[math.radians(x)for x in value[:3]]
 bpy.context.view_layer.update()
 rows=[(min((obj.matrix_world@Vector(v)).z for v in obj.bound_box),obj.name,obj.parent.name)for obj in bpy.data.objects if obj.name.startswith('Part_') and obj.parent.name!='Joint_core']
 floor=min(x[0]for x in rows);body=min(x[0]for x in rows if x[2]in ['Joint_body','Joint_chest','Joint_head'])
 print('ARM_SUPPORT',height,body-floor,sorted(rows)[:3],flush=True)
