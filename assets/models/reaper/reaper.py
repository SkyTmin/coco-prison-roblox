"""Original final scythe boss, generated and reviewed in headless Blender."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from reaper_parts import geometry
from reaper_motion import make_actions
NAME='reaper';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS,PARTS=geometry()
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,177,174)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'weapon':(26,83)}}
EXTRA_JSON={'walkSpeed':4}
CLIP_FILES={'loco':['idle','idle3','walk'],'cuts':['attack1','attack2','circleattack'],'magic':['soul1','groundattack','explosion'],'teleport':['teleportinto','teleportout'],'life':['spawn','hurt','stun'],'death':['death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('attack1',12),('soul1',60),('death',128.4)]
PREVIEW_CAMERA=((19,29,13),(0,0,4.8),48)
COMPARE={'front':((-1,0,0),(0,0,1),(-1,0,5),18),'side':((0,-1,0),(0,0,1),(0,0,5),18),'back':((1,0,0),(0,0,1),(-1,0,5),18)}
if __name__=='__main__':run(globals())
