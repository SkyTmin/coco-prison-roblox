"""Original leaf-pod familiar. Source clip families, independently authored cuboid appearance."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from ent.ent_minion import JOINTS,actions as oak_actions
from splinter.motion import Rig,pose
NAME='guardian_minion';HERE=os.path.dirname(os.path.abspath(__file__))
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
BARK=(57,63,50);EDGE=(104,112,77);LEAF=(76,95,48);MOSS=(118,133,75);BLUE=(75,121,117)
mass('SeedBase','body',(0,0,1.75),(1.15,.95,.9),BARK,3,4)
mass('Pod','chest',(0,-.08,2.35),(1.65,1.3,1.35),BARK,4,4)
mass('Face','head',(0,.1,2.99),(.92,.93,.88),BLUE,3,4)
for facing in [-1,1]:
 for k in range(5):
  x=(k-2)*.29
  beam('PodRib'+str(facing)+str(k),'chest',(x*.65,facing*.51,1.84),(x,facing*.6,2.9),.19,.21,EDGE)
  add('PodLeaf'+str(facing)+str(k),'chest',(x,facing*.67,2.46),(.44,.18,.82),LEAF,(0,(k-2)*13,0))
for side,s in [('L',1),('R',-1)]:
 add('EyeSocket'+side,'head',(s*.22,.6,3.08),(.28,.06,.22),BARK)
 add('Eye'+side,'head',(s*.22,.64,3.09),(.11,.025,.12),(154,161,108))
 beam('MaskRidge'+side,'head',(s*.44,.49,2.79),(s*.47,.47,3.32),.16,.19,EDGE)
 for n,j,a,b,w in [('Upper','arm',(s*.78,0,2.5),(s*1.03,0,1.75),.4),('Fore','fore',(s*1.03,0,1.75),(s*1.21,.1,.98),.43),('Thigh','leg',(s*.43,0,1.45),(s*.48,.04,.81),.43),('Calf','shin',(s*.48,.04,.81),(s*.54,.07,.15),.45)]:
  beam(n+side,j+side,a,b,w,w,BARK);beam(n+'Ridge'+side,j+side,(a[0]-.08,a[1]+w*.4,a[2]),(b[0]-.08,b[1]+w*.4,b[2]),.12,.12,EDGE)
 mass('Palm'+side,'hand'+side,(s*1.21,.12,.9),(.58,.55,.44),BLUE,2,3)
 for k in range(3):
  x=s*(1.04+k*.17);beam('Claw'+side+str(k),'fingers'+side,(x,.18,.78),(x,.32,.5),.14,.15,BARK)
  beam('ClawTip'+side+str(k),'fingers'+side,(x,.32,.5),(x,.48,.55),.12,.13,EDGE)
 mass('Foot'+side,'foot'+side,(s*.54,.1,.19),(.76,.97,.37),BARK,2,3)
 for k in range(3):beam('Toe'+side+str(k),'toe'+side,(s*.54,.23,.18),(s*(.54+(k-1)*.21),.67,.12),.18,.18,EDGE)
 beam('CrestStem'+side,'crown'+side,(s*.3,0,3.1),(s*.5,-.02,3.61),.13,.16,BARK)
 for k in range(3):add('CrestLeaf'+side+str(k),'crown'+side,(s*(.35+k*.18),-.03,3.56-k*.08),(.42,.35,.19),MOSS,(0,s*28,0))
 for k in range(3):add('ShoulderLeaf'+side+str(k),'arm'+side,(s*(.76+k*.12),-.05,2.61-k*.15),(.53,.64,.18),LEAF,(0,s*26,0))
PARTS=g.parts
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
EXTRA_JSON={'walkSpeed':2.5}
def actions():
 a=oak_actions();rig=Rig(JOINTS)
 for name,length in [('idle',1.5),('spawn',1.625),('death',1.83333)]:
  keys,loop=a[name];scale=length*30/keys[-1][0];a[name]=([(f*scale,p)for f,p in keys],loop)
 keys=[]
 for i in range(81):
  phase=i/80*2;t=phase*math.pi*2;feet={}
  for side,offset in [('L',0),('R',.5)]:
   q=(phase+offset)%1
   if q<.6:y=.5625*(1-2*q/.6);z=0
   else:u=(q-.6)/.4;y=-.5625+1.125*u*u*(3-2*u);z=.24*math.sin(math.pi*u)
   feet[side]=(0,y,z)
  p=pose(body=(0,0,0,(0,0,-.36)),chest=(-8,0,3*math.sin(t)),head=(6,0,-2*math.sin(t)),armL=9+23*math.sin(t),armR=7-23*math.sin(t),foreL=14,foreR=12,crownL=(4*math.sin(t-.6),0,2*math.sin(t)),crownR=(4*math.sin(t-.8),0,-2*math.sin(t)))
  keys.append((i/80*45,rig.planted(p,feet)))
 keys[-1]=(45,dict(keys[0][1]));a['walk']=(keys,True)
 return a
PREVIEW_PREFIX='guardian_minion-preview-';PREVIEWS=[('idle',20),('bite',19.5),('death',54.9999)]
PREVIEW_CAMERA=((8,12,7),(0,0,1.8),48)
if __name__=='__main__':run(globals())
