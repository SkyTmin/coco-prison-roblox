"""Original small piglin guard; same anatomy, simplified geometry for summoned groups."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import piglin_king as king
from blockmob import run
NAME='piglin_guard';HERE=os.path.dirname(os.path.abspath(__file__))
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
TILE_STUDS=1.1;GAME_LIFT=king.GAME_LIFT
king.PARTS=[];add=king.add;mass=king.mass
mass('Body','body',(0,0,4.55),(4.25,2.8,3.3),king.SKIN,4,3)
mass('Chest','chest',(0,0,6.5),(4.6,2.9,1.85),king.SKIN,3,3)
mass('Head','head',(0,.5,8.13),(3.1,2.7,2.4),king.SKIN,3,3)
add('Snout','head',(0,2,7.9),(1.65,.8,.8),king.SNOUT)
add('Jaw','jaw',(0,1.5,7.3),(2.1,1.9,.6),king.DARK)
for side,s in [('L',1),('R',-1)]:
 add('Nostril'+side,'head',(s*.42,2.43,7.9),(.27,.1,.36),king.BLACK)
 add('Eye'+side,'head',(s*.93,1.84,8.57),(.36,.1,.2),(212,155,55))
 add('Brow'+side,'head',(s*.93,1.85,8.8),(.73,.25,.25),king.DARK,(0,-s*12,0))
 add('Tusk'+side,'jaw',(s*1.01,2.18,7.61),(.28,.38,.63),king.IVORY)
 add('Ear'+side,'ear'+side,(s*1.98,.4,8.4),(1.18,.88,.36),king.SKIN,(0,s*23,0))
 mass('Arm'+side,'arm'+side,(s*2.95,0,6.3),(1.65,1.65,2.2),king.SKIN,3,3)
 mass('Fore'+side,'fore'+side,(s*3.65,.33,4.75),(1.34,1.4,1.65),king.DARK,3,3)
 add('Hand'+side,'hand'+side,(s*3.9,.6,3.85),(1.14,1.05,.85),king.SKIN)
 add('Fingers'+side,'fingers'+side,(s*3.9,.94,3.42),(1.12,.42,.55),king.DARK)
 add('Cuff'+side,'fore'+side,(s*3.7,.36,4.5),(1.47,1.5,.33),king.GOLD_DARK)
 mass('Leg'+side,'leg'+side,(s*1.4,0,2.8),(1.8,1.8,1.8),king.DARK,3,3)
 add('Shin'+side,'shin'+side,(s*1.5,.05,1.2),(1.1,1.18,1.5),king.SKIN)
 for toe in [-1,1]:add(f'Hoof{side}{toe}','foot'+side,(s*1.5+toe*.31,.38,.32),(.57,1.5,.64),king.HOOF)
add('Belt','body',(0,0,3.8),(4.3,2.95,.55),king.LEATHER)
add('Cloth','clothFront',(0,1.51,2.96),(1.7,.2,1.4),king.CLOTH)
add('BackCloth','clothBack',(0,-1.5,2.96),(2.7,.2,1.4),king.CLOTH)
add('Club','handL',(3.95,1.65,3.9),(.42,2.45,.42),king.LEATHER)
add('ClubHead','handL',(3.95,2.6,3.9),(.82,1.15,.82),king.GOLD_DARK)
S=.4
JOINTS=[(n,p,tuple(v*S for v in pos)) for n,p,pos in king.JOINTS]
PARTS=[(n,j,tuple(v*S for v in c),tuple(v*S for v in size),color,top,rot,flags) for n,j,c,size,color,top,rot,flags in king.PARTS]
CLIP_IMPACTS={'bite':1.35/3.0246*.6667}
EXTRA_JSON={'walkSpeed':2.1333333333}
def actions():
 source=king.make_actions(king.JOINTS);out={}
 for name,original,duration in [('idle','idle',2),('walk','walk',.5),('bite','verticalatk',.6667),('hurt','hurt',.5),('death','death',2)]:
  keys,loop=source[original];length=keys[-1][0]
  out[name]=([(f/length*duration*30,{n:(rx,ry,rz,tuple(v*S for v in off) if off else None) for n,(rx,ry,rz,off) in p.items()}) for f,p in keys],loop)
 return out
PREVIEWS=[] # king previews share this folder; guard is reviewed in Studio
PREVIEW_CAMERA=((8,11,6),(0,0,1.9),47)
COMPARE={'front':((1,0,0),(0,0,1),(0,0,1.9),5),'back':((-1,0,0),(0,0,1),(0,0,1.9),5)}
if __name__=='__main__':run(globals())
