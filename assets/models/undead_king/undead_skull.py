"""Killable summoned skull with jaw/cheek follow-through and an intact landing death."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from necromancer_parts import *
from splinter.motion import pose
NAME='undead_skull';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
JOINTS=[('root',None,(0,0,0)),('head','root',(0,0,.85)),('jaw','head',(0,.25,.35)),('cheekL','head',(.5,.25,.65)),('cheekR','head',(-.5,.25,.65))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
mass('Cranium','head',(0,0,1.01),(1.55,1.38,1.43),BONE,4,4)
add('Sockets','head',(0,.69,.99),(1.26,.13,.54),SOCKET)
for side,s in [('L',1),('R',-1)]:
 add('Brow'+side,'head',(s*.34,.77,1.3),(.66,.22,.22),IVORY,(0,s*9,0))
 add('Eye'+side,'head',(s*.34,.775,1.02),(.16,.035,.12),TEAL)
 add('Cheek'+side,'cheek'+side,(s*.57,.66,.65),(.37,.35,.33),BONE)
 add('Temple'+side,'head',(s*.69,.43,1.02),(.23,.38,.55),BONE)
add('Nose','head',(0,.8,.97),(.18,.22,.33),BONE)
mass('Jaw','jaw',(0,.3,.29),(1.02,.87,.4),BONE,2,4)
for k in range(7):
 add('LowerTooth'+str(k),'jaw',(-.42+k*.14,.78,.53),(.1,.12,.19),IVORY)
 add('UpperTooth'+str(k),'head',(-.42+k*.14,.72,.7),(.1,.14,.18),IVORY)
for k in range(3):add('Crack'+str(k),'head',(.18+k*.07,.31,1.71-k*.06),(.045,.4,.035),SOCKET)
PARTS=g.parts
def actions():
 a={}
 for n,length in [('idle',1.7),('walk',1.7)]:
  a[n]=([(i/24*length*30,pose(head=(3*math.sin(i/24*math.pi*2),2*math.sin(i/24*math.pi*2-.4),3*math.sin(i/24*math.pi*2-.8),(0,0,.08*math.sin(i/24*math.pi*2))),jaw=-6-3*math.sin(i/24*math.pi*2-.3)))for i in range(25)],True)
 a['bite']=([(0,pose(jaw=-6)),(6,pose(head=(-9,0,-9),jaw=-25,cheekL=(0,0,7),cheekR=(0,0,-7))),(15,pose(head=(11,0,8),jaw=-40)),(24,pose(head=(-7,0,-6),jaw=-49)),(27,pose(head=5,jaw=-52))],False)
 a['hurt']=([(0,pose()),(3,pose(head=(17,0,12),jaw=-21)),(8,pose(jaw=-6))],False)
 a['death']=([(0,pose(jaw=-12)),(7,pose(head=(15,0,-12),jaw=-34)),(16,pose(head=(-24,0,19),jaw=-19)),(29,pose(head=(-55,0,38),jaw=-4)),(37,pose(head=(-71,0,56),jaw=-7)),(43,pose(head=(-64,0,52),jaw=-13)),(51,pose(head=(-73,0,57),jaw=-6)),(60,pose(head=(-73,0,57),jaw=-6))],False)
 return a
PREVIEWS=[('idle',15),('bite',22),('death',60)];PREVIEW_CAMERA=((4,6,3.3),(0,0,.8),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,.85),2.5)}
if __name__=='__main__':run(globals())
