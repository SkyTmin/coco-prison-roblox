"""Original mortal spirit-archer; one Mob animator and no boss reward identity."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from spirit_parts import geometry
from spirit_motion import make_actions
NAME='lover_spirit';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS,PARTS=geometry()
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'bow':(20,75)}}
EXTRA_JSON={'walkSpeed':2.5}
CLIP_FILES={'loco':['idle','walk'],'shots':['bowshot','fan'],'magic':['rain','spear'],'life':['spawn','hurt','death']}
def actions():return make_actions(JOINTS)
PREVIEW_PREFIX='lover_spirit-preview-'
PREVIEWS=[('idle',30),('bowshot',43),('death',120)]
PREVIEW_CAMERA=((12,20,10),(0,0,3.9),48)
if __name__=='__main__':run(globals())
