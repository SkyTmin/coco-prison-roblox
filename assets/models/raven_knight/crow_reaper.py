"""Original vulnerable retainer. Shares armor construction, independent hood/axe and attack clips."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from knight_parts import geometry
from raven_motion import make_actions
NAME='crow_reaper';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS,PARTS=geometry(True)
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,177,182)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'weapon':(27,78)}}
EXTRA_JSON={'walkSpeed':3.2}
CLIP_FILES={'loco':['idle','walk'],'attacks':['basicattack','chargeattack'],'magic':['fogcombo','summonaxe','spikesattack'],'life':['spawn','hurt','death']}
def actions():return make_actions(JOINTS,True)
PREVIEW_PREFIX='crow_reaper-preview-';PREVIEWS=[('idle',30),('basicattack',27),('death',156)]
PREVIEW_CAMERA=((16,24,11),(0,0,4.7),48)
if __name__=='__main__':run(globals())
