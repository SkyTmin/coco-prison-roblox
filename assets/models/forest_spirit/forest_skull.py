"""Original flying wooden mask with four jointed leaf wings, no emission."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='forest_skull';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
WOOD=(103,92,69);DARK=(39,42,33);BARK=(62,56,47);LEAF=(66,78,48);SEED=(151,153,76)
JOINTS=[('root',None,(0,0,0)),('head','root',(0,0,.8)),('jaw','head',(0,.19,.38)),('wingL','head',(.58,-.07,.91)),('wingTipL','wingL',(1.1,-.11,.78)),('wingR','head',(-.58,-.07,.91)),('wingTipR','wingR',(-1.1,-.11,.78))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
mass('MaskBack','head',(0,0,.85),(1.3,.95,1.18),BARK,4,4)
add('FaceRecess','head',(0,.49,.91),(1.05,.1,.51),DARK)
for s in [-1,1]:
 add('Eye'+str(s),'head',(s*.29,.555,.95),(.13,.045,.11),SEED)
 beam('Brow'+str(s),'head',(s*.04,.61,1.21),(s*.49,.52,1.3),.14,.17,WOOD)
 beam('Cheek'+str(s),'head',(s*.49,.54,.79),(s*.27,.64,.52),.16,.18,WOOD)
beam('Nose','head',(0,.62,1.28),(0,.68,.67),.17,.18,WOOD)
add('Jaw','jaw',(0,.3,.31),(.7,.59,.3),WOOD)
for k in range(4):add('Tooth'+str(k),'jaw',(-.23+k*.15,.63,.49),(.09,.1,.17),BARK)
for side,s in [('L',1),('R',-1)]:
 for k in range(4):
  z=1.23-k*.22
  beam('WingBase'+side+str(k),'wing'+side,(s*.53,-.1,z),(s*1.12,-.16,z-.13),.19,.1,LEAF)
  beam('WingTip'+side+str(k),'wingTip'+side,(s*1.07,-.16,z-.13),(s*(1.68-k*.06),-.22,z-.4),.15,.09,LEAF)
PARTS=g.parts
def actions():
 a={}
 for n,length in [('idle',.75),('walk',.76)]:
  keys=[]
  for i in range(25):
   t=i/24*2*math.pi;v=math.sin(t);lag=math.sin(t-.6)
   keys.append((i/24*length*30,pose(head=(2*v,0,2*lag,(0,0,.045*v)),jaw=-3-2*lag,wingL=(0,30*v,4),wingR=(0,-30*v,-4),wingTipL=(0,19*lag,0),wingTipR=(0,-19*lag,0))))
  a[n]=(keys,True)
 a['bite']=([(0,pose(jaw=-4)),(8,pose(head=-13,jaw=-21,wingL=(0,35,0),wingR=(0,-35,0))),(13.5,pose(head=17,jaw=-6,wingL=(0,-24,0),wingR=(0,24,0),wingTipL=(0,-17,0),wingTipR=(0,17,0))),(20,pose(head=9,jaw=-11)),(27.6,pose(jaw=-4))],False)
 a['spawn']=([(0,pose(head=-11,wingL=(0,51,0),wingR=(0,-51,0))),(8,pose(head=7,wingL=(0,-23,0),wingR=(0,23,0))),(15.6,pose())],False)
 a['hurt']=([(0,pose()),(4,pose(head=(18,0,11),jaw=-19)),(12,pose(head=(-7,0,-5))), (25.2,pose())],False)
 def p(x):return pose(head=(x,0,37),jaw=-5,wingL=(0,-67,4),wingR=(0,61,-4),wingTipL=(0,31,0),wingTipR=(0,-29,0))
 a['death']=([(0,pose()),(8,pose(head=(17,0,-11),jaw=-23,wingL=(0,41,0),wingR=(0,-37,0))),(19,p(-31)),(32,p(-61)),(41,p(-74)),(46,p(-68)),(53,p(-77)),(60,p(-77))],False)
 return a
PREVIEWS=[('idle',10),('bite',13.5),('death',60)];PREVIEW_CAMERA=((5,7,4),(0,0,.8),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,.9),4)}
if __name__=='__main__':run(globals())
