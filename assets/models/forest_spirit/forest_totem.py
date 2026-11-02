"""Original destructible ritual totem; matte seed, hinged mask and branch ornaments."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='forest_totem';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
WOOD=(103,92,69);DARK=(39,42,33);BARK=(62,56,47);LEAF=(66,78,48);SEED=(151,153,76)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,.38)),('head','body',(0,0,2.42)),('jaw','head',(0,.27,2.19)),('seed','body',(0,.36,1.47)),('branchL','head',(.43,0,2.73)),('branchR','head',(-.43,0,2.73)),('leaves','body',(0,-.22,1.95))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
mass('Post','body',(0,0,1.46),(1.03,.98,2.89),BARK,6,4)
for k in range(5):
 x=(k-2)*.18
 beam('BarkRidge'+str(k),'body',(x,.51,.32),(x,.51,2.6),.1,.1,WOOD)
for i in range(6):
 a=i*math.pi/3;beam('FootRoot'+str(i),'body',(math.cos(a)*.3,math.sin(a)*.3,.35),(math.cos(a)*.89,math.sin(a)*.89,.12),.22,.23,WOOD)
mass('Seed','seed',(0,.5,1.47),(.63,.46,.76),SEED,3,4)
for s in [-1,1]:
 for k in range(2):beam('SeedCage'+str(s)+str(k),'body',(s*.1,.73,1.9-k*.67),(s*.42,.52,1.63-k*.12),.12,.12,WOOD)
mass('Mask','head',(0,.1,2.53),(1.2,.94,.94),WOOD,3,4)
add('Face','head',(0,.61,2.55),(.89,.11,.52),DARK)
for s in [-1,1]:
 add('Eye'+str(s),'head',(s*.22,.68,2.64),(.14,.05,.1),SEED)
 beam('Brow'+str(s),'head',(s*.04,.72,2.85),(s*.51,.65,2.9),.15,.16,WOOD)
beam('Nose','head',(0,.72,2.85),(0,.78,2.31),.17,.16,WOOD)
add('Jaw','jaw',(0,.43,2.15),(.74,.51,.24),WOOD)
for side,s in [('L',1),('R',-1)]:
 beam('Branch'+side,'branch'+side,(s*.43,0,2.73),(s*1.12,-.04,3.12),.18,.22,WOOD)
 beam('Horn'+side,'branch'+side,(s*1.12,-.04,3.12),(s*1.25,-.08,3.64),.15,.19,WOOD)
 beam('Tine'+side,'branch'+side,(s*.82,-.02,2.99),(s*.79,-.04,3.42),.12,.15,WOOD)
for k in range(7):
 x=(k-3)*.18;beam('Leaf'+str(k),'leaves',(x,-.38,2.14),(x*1.25,-.49,1.42-.1*(k%2)),.26,.12,LEAF)
PARTS=g.parts
def actions():
 idle=[]
 for i in range(25):
  t=i/24*2*math.pi;idle.append((i/24*1.76*30,pose(head=(.8*math.sin(t),0,.8*math.sin(t-.4)),jaw=-2-math.sin(t),seed=(0,0,2*math.sin(t),(0,0,.015*math.sin(t))),branchL=(2*math.sin(t-.5),0,1),branchR=(2*math.sin(t-.7),0,-1),leaves=2*math.sin(t-.8))))
 def p(x):return pose(body=(x,0,-6),head=-7,jaw=-9,branchL=(-7,0,11),branchR=(-4,0,-9),leaves=-4)
 return {'idle':(idle,True),'spawn':([(0,pose(body=(-12,0,0,(0,0,-.2)),head=-17,branchL=(0,0,-13),branchR=(0,0,13))),(12,pose(body=5,head=9,branchL=(0,0,9),branchR=(0,0,-9))),(27,pose(body=-2,head=-3)),(42,pose())],False),
 'bite':([(0,pose()),(12,pose(head=9,jaw=-17,branchL=(0,0,9),branchR=(0,0,-9))),(21,pose(head=-7,jaw=-25,seed=(0,0,0,(0,.1,0)))),(30,pose())],False),
 'hurt':([(0,pose()),(3,pose(body=(6,0,-5),head=(8,0,7))),(10,pose())],False),
 'death':([(0,pose()),(9,pose(body=(-9,0,-6),head=13,jaw=-22)),(21,p(21)),(33,p(58)),(45,p(87)),(51,p(81)),(60,p(89)),(72,p(89))],False)}
PREVIEWS=[('idle',15),('death',72)];PREVIEW_CAMERA=((6,9,5),(0,0,1.6),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,1.8),5.5)}
if __name__=='__main__':run(globals())
