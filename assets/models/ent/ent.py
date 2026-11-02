"""Original oak king, built only in headless Blender."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from ent_parts import geometry
from ent_motion import make_actions
NAME='ent';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS,PARTS=geometry()
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
EXTRA_JSON={'walkSpeed':4.1}
CLIP_FILES={'loco':['idle','walk'],'punches':['rightpunch','leftpunch'],'branches':['stomp','rise'],'storm':['shout','leafstorm'],'life':['spawn','hurt','stun'],'death':['death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('rightpunch',27.6),('rise',45),('death',132)]
PREVIEW_CAMERA=((18,28,13),(0,0,5.4),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.6),18),'side':((0,-1,0),(0,0,1),(0,0,5.6),18),'back':((1,0,0),(0,0,1),(0,0,5.6),18)}
if __name__=='__main__':run(globals())
