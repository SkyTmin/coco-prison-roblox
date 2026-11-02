"""Original Samurai/Hanashiguro reference-driven headless Blender entry point."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from samurai_parts import geometry
from samurai_motion import make_actions
NAME='the_lovers';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS,PARTS=geometry()
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'weapon':(27,78)}}
EXTRA_JSON={'walkSpeed':3.2,'runSpeed':5.2}
CLIP_FILES={'loco':['idle','walk','run'],'cuts':['drawcut','reversecut'],'triple':['triplecut'],'sweep':['sweep','thrust'],
 'dash':['dashcut','skycut'],'throws':['stars','sickle'],'magic':['spears','arrowcall'],'phases':['phase2','phase3'],
 'life':['spawn','hurt','stun','jump'],'death':['death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('drawcut',22.5),('phase2',50),('death',156)]
PREVIEW_CAMERA=((16,24,11),(0,0,4.8),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,4.9),16),'side':((0,-1,0),(0,0,1),(0,0,4.9),16),'back':((1,0,0),(0,0,1),(0,0,4.9),16)}
if __name__=='__main__':run(globals())
