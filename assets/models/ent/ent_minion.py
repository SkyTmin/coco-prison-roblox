"""Original young oak summon, distinct small low-cost rig."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import Rig,pose
from mathutils import Euler
NAME='ent_minion';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,1.45)),('chest','body',(0,0,2.1)),('head','chest',(0,0,2.7))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('arm'+side,'chest',(s*.78,0,2.5)),('fore'+side,'arm'+side,(s*1.03,0,1.75)),('hand'+side,'fore'+side,(s*1.21,.1,.98)),('fingers'+side,'hand'+side,(s*1.2,.2,.75)),
  ('leg'+side,'body',(s*.43,0,1.45)),('shin'+side,'leg'+side,(s*.48,.04,.81)),('foot'+side,'shin'+side,(s*.54,.07,.15)),('toe'+side,'foot'+side,(s*.54,.35,.12)),('crown'+side,'head',(s*.3,0,3.1))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
BARK=(80,58,39);WOOD=(125,89,57);DARK=(44,40,32);LEAF=(88,100,69)
mass('Waist','body',(0,0,1.75),(1.12,.85,.9),BARK,3,3)
mass('Trunk','chest',(0,0,2.39),(1.57,1.05,1.14),BARK,3,4)
mass('Head','head',(0,0,2.98),(.95,.85,.88),WOOD,3,3)
for facing in[-1,1]:
 for k in range(6):add('Ridge'+str(facing)+str(k),'chest',((k-2.5)*.23,facing*.51,2.32),(.13,.11,.82),WOOD)
for side,s in [('L',1),('R',-1)]:
 add('Eye'+side,'head',(s*.21,.44,3.06),(.18,.04,.1),(145,155,99))
 beam('Brow'+side,'head',(s*.05,.48,3.19),(s*.41,.44,3.23),.12,.13,BARK)
 mass('Arm'+side,'arm'+side,(s*.9,0,2.11),(.61,.65,.94),WOOD,3,3)
 mass('Fore'+side,'fore'+side,(s*1.13,.06,1.36),(.65,.7,.98),BARK,3,3)
 mass('Palm'+side,'hand'+side,(s*1.21,.12,.9),(.61,.53,.48),WOOD,2,3)
 for k in range(3):beam('Finger'+side+str(k),'fingers'+side,(s*(1.04+k*.17),.18,.78),(s*(1.04+k*.17),.31,.51),.14,.18,BARK)
 mass('Thigh'+side,'leg'+side,(s*.45,0,1.11),(.59,.62,.79),WOOD,3,3)
 mass('Calf'+side,'shin'+side,(s*.51,.04,.48),(.6,.7,.75),BARK,3,3)
 mass('Foot'+side,'foot'+side,(s*.54,.1,.19),(.73,.96,.37),WOOD,2,3)
 for k in range(3):beam('RootToe'+side+str(k),'toe'+side,(s*.54,.25,.17),(s*(.54+(k-1)*.22),.68,.12),.19,.18,BARK)
 beam('Crown'+side,'crown'+side,(s*.3,0,3.1),(s*.59,.03,3.73),.19,.22,BARK)
 add('Leaves'+side,'crown'+side,(s*.6,.03,3.73),(.57,.5,.25),LEAF)
 for k in range(3):add('LeafTip'+side+str(k),'crown'+side,(s*(.42+k*.18),.08,3.83),(.22,.3,.16),LEAF)
PARTS=g.parts
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
EXTRA_JSON={'walkSpeed':2.5}
def actions():
 rig=Rig(JOINTS);a={}
 def rest(extra=None,drop=.24,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-4,head=4,armL=9,armR=7,foreL=13,foreR=11);p.update(extra or {});return rig.planted(p,feet)
 a['idle']=([(i*2,rest(pose(chest=-4+math.sin(i/30*math.pi*2),head=4-math.sin(i/30*math.pi*2))))for i in range(31)],True)
 keys=[]
 for i in range(41):
  feet={};t=i/40*math.pi*2
  for side,phase in [('L',0),('R',.5)]:
   q=(i/40+phase)%1
   if q<.6:y=.500025*(1-2*q/.6);z=0
   else:u=(q-.6)/.4;y=-.500025+1.00005*u*u*(3-2*u);z=.22*math.sin(math.pi*u)
   feet[side]=(0,y,z)
  keys.append((i/40*20.001,rest(pose(chest=(-7,0,3*math.sin(t)),head=(5,0,-2*math.sin(t)),armL=9+21*math.sin(t),armR=7-21*math.sin(t)),.34,feet)))
 a['walk']=(keys,True)
 a['bite']=([(0,rest()),(8,rest(pose(chest=(6,0,-13),armR=94,foreR=-24),.29)),(15,rest(pose(chest=(11,0,-17),armR=117,foreR=-28),.31)),(19.5,rest(pose(chest=(-22,0,17),armR=48,foreR=9),.4)),(25,rest(pose(chest=-17,armR=28,foreR=20),.36)),(32.499,rest())],False)
 a['spawn']=([(0,rest(pose(chest=-24,head=-13,armL=31,armR=35),.4)),(23,rest(pose(chest=-10,head=-4),.31)),(40,rest(pose(chest=6,head=12),.22)),(54.999,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=17,head=21),.29)),(12,rest(pose(chest=-13,head=-7),.32)),(21,rest())],False)
 down=pose(body=(-88,-5,5,(0,.2,-.25)),chest=0,head=(0,-8,0),legL=3,legR=-4,shinL=-23,shinR=-20,footL=15,footR=17,armL=6,armR=-6,foreL=12,foreR=13)
 for side,s in [('L',1),('R',-1)]:
  shoulder=rig.world(down,'arm'+side).translation
  rig.chain(down,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.4,shoulder.y-.8,1.07),(s,0,.3),Euler((-math.pi/2,0,0)).to_quaternion())
 a['death']=([(0,rest()),(6,rest(pose(chest=19,head=23),.3)),(15,rest(pose(chest=-27,head=-12),.4)),(26,pose(body=(-35,-18,4,(0,.1,-.3)),chest=-9,head=-6,legL=44,legR=53,shinL=-86,shinR=-91,armL=38,armR=35,foreL=13,foreR=17)),(40,down),(51,dict(down)),(68.751,dict(down))],False)
 for name,(keys,loop)in a.items():
  previous={};out=[]
  for f,p in keys:
   p=dict(p)
   for side,s in [('L',1),('R',-1)]:p.setdefault('crown'+side,(2*math.sin(f/9-.4),s*math.sin(f/8),0,None))
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
PREVIEW_PREFIX='ent_minion-preview-';PREVIEWS=[('idle',20),('bite',19.5),('death',68.751)]
PREVIEW_CAMERA=((8,12,7),(0,0,1.8),48)
if __name__=='__main__':run(globals())
