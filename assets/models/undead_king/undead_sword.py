"""Eight-second authored apparition: gather, aim, downward cut, recoil and lift."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from necromancer_parts import *
from splinter.motion import pose
NAME='undead_sword';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True
JOINTS=[('root',None,(0,0,0)),('blade','root',(0,0,6.5)),('guardL','blade',(.5,0,6.5)),('guardR','blade',(-.5,0,6.5)),('pommel','blade',(0,0,8.3))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
for k in range(11):
 z=.4+k*.53;w=.17+.77*min(1,k/3)
 add('Blade'+str(k),'blade',(0,0,z),(w,.24,.56),EDGE)
 add('Fuller'+str(k),'blade',(0,.139,z),(.1,.045,.47),TEAL)
 for s in [-1,1]:add('Edge'+str(k)+str(s),'blade',(s*w*.45,0,z),(.1,.3,.56),BONE)
add('Tip','blade',(0,0,.1),(.14,.23,.2),BONE)
add('Hilt','blade',(0,0,7.26),(.34,.36,1.55),IRON)
for k in range(6):add('GripBand'+str(k),'blade',(0,0,6.69+k*.22),(.39,.4,.065),BRONZE)
for side,s in [('L',1),('R',-1)]:
 beam('Guard'+side,'guard'+side,(s*.24,0,6.51),(s*1.5,0,6.25),.29,.35,IRON)
 beam('GuardTrim'+side,'guard'+side,(s*.27,.2,6.57),(s*1.49,.2,6.31),.08,.06,BONE)
 beam('GuardTip'+side,'guard'+side,(s*1.5,0,6.25),(s*1.69,0,5.95),.24,.3,EDGE)
mass('Pommel','pommel',(0,0,8.3),(.72,.68,.71),IRON,3,3)
add('PommelSeal','pommel',(0,.35,8.3),(.29,.06,.33),TEAL)
mass('Seal','blade',(0,.14,6.5),(.63,.52,.62),BONE,2,3)
PARTS=g.parts
def actions():
 def p(angle,height,twist=0,spread=0):return pose(blade=(angle,0,twist,(0,0,height)),guardL=(0,spread,0),guardR=(0,-spread,0),pommel=(0,0,-twist*.2))
 return {'idle':([(0,p(0,1.8)),(30,p(2,1.9)),(60,p(0,1.8))],True),'attack':([(0,p(9,1.8,-9,9)),(24,p(4,2,-4,6)),(60,p(-3,2.15,3,3)),(90,p(-12,2.3,0,11)),(110,p(-8,2.1,0,9)),(120,p(0,.06,0,0)),(126,p(1,.24,0,4)),(135,p(0,.06,0,0)),(165,p(0,.06)),(192,p(2,.4,-3,4)),(216,p(6,1.7,-7,7)),(240,p(9,2.4,-12,10))],False)}
PREVIEWS=[('attack',60),('attack',120)];PREVIEW_CAMERA=((10,16,10),(0,0,5.5),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.5),14)}
if __name__=='__main__':run(globals())
