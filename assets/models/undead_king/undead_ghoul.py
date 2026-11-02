"""Original hunched ghoul: ragged tunic, exposed ribs, long hands, planted feet."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from necromancer_parts import *
from splinter.motion import Rig,pose
NAME='undead_ghoul';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True
GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,1.8)),('chest','body',(0,0,2.65)),('head','chest',(0,.28,3.5)),('jaw','head',(0,.59,3.22)),('rag','chest',(0,-.47,2.95))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('arm'+side,'chest',(s*.68,0,2.95)),('fore'+side,'arm'+side,(s*.86,.12,2.03)),('hand'+side,'fore'+side,(s*1.0,.39,1.15)),('fingers'+side,'hand'+side,(s*1.01,.48,.96)),('leg'+side,'body',(s*.36,0,1.8)),('shin'+side,'leg'+side,(s*.43,.02,1.05)),('foot'+side,'shin'+side,(s*.49,0,.19))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
mass('Pelvis','body',(0,0,1.91),(1.0,.72,.64),CLOTH)
mass('Torso','chest',(0,0,2.67),(1.3,.85,1.13),CLOTH,3,4)
for s in [-1,1]:
 for k in range(3):beam('Rib'+str(s)+str(k),'chest',(s*.07,.47,2.99-k*.18),(s*.5,.37,2.88-k*.18),.095,.09,BONE)
for k in range(3):add('Spine'+str(k),'chest',(0,-.45,2.95-k*.21),(.15,.16,.18),BONE)
add('BackRag','rag',(-.22,-.48,2.3),(.63,.12,1.38),TEAL)
for k in range(3):add('RagTip'+str(k),'rag',(-.46+k*.21,-.49,1.52+.12*(k%2)),(.18,.12,.35),CLOTH)
mass('Skull','head',(0,.29,3.55),(1.03,.85,.85),BONE,3,4)
add('Face','head',(0,.74,3.48),(.87,.11,.44),SOCKET)
for s in [-1,1]:
 add('Brow'+str(s),'head',(s*.23,.82,3.72),(.44,.16,.17),BONE,(0,s*7,0))
 add('Cheek'+str(s),'head',(s*.37,.8,3.37),(.24,.18,.19),BONE)
 add('Eye'+str(s),'head',(s*.23,.811,3.55),(.08,.035,.07),TEAL)
add('Nose','head',(0,.82,3.49),(.12,.12,.22),BONE)
add('Jaw','jaw',(0,.65,3.19),(.66,.39,.21),BONE)
for k in range(5):add('Tooth'+str(k),'jaw',(-.26+k*.13,.88,3.32),(.09,.1,.16),IVORY)
for side,s in [('L',1),('R',-1)]:
 mass('Shoulder'+side,'arm'+side,(s*.68,0,2.92),(.52,.63,.53),TEAL,2,3)
 beam('Arm'+side,'arm'+side,(s*.68,0,2.8),(s*.86,.12,2.03),.27,.3,BONE)
 for k in [-1,1]:beam('Forearm'+side+str(k),'fore'+side,(s*.86+k*.08,.12,1.98),(s*1+k*.07,.39,1.18),.095,.1,BONE)
 mass('Palm'+side,'hand'+side,(s*1,.42,1.05),(.36,.27,.3),BONE,2,2)
 for k in range(4):
  x=s*(.85+k*.105);z=.94
  beam('Finger'+side+str(k),'fingers'+side,(x,.5,z),(x,.66,z-.27+abs(k-1)*.03),.075,.085,IVORY)
  beam('Tip'+side+str(k),'fingers'+side,(x,.66,z-.27+abs(k-1)*.03),(x,.82,z-.24+abs(k-1)*.03),.065,.075,BONE)
 beam('Thumb'+side,'hand'+side,(s*.84,.45,1.1),(s*.75,.68,.94),.105,.11,BONE)
 beam('Thigh'+side,'leg'+side,(s*.36,0,1.75),(s*.43,.02,1.05),.43,.45,CLOTH)
 mass('Knee'+side,'shin'+side,(s*.43,.04,1.05),(.36,.37,.28),BONE,2,3)
 beam('Shin'+side,'shin'+side,(s*.43,.02,.94),(s*.49,0,.22),.22,.25,BONE)
 mass('Foot'+side,'foot'+side,(s*.49,.19,.16),(.43,.8,.31),BONE,2,3)
PARTS=g.parts;EXTRA_JSON={'walkSpeed':2.222222};CLIP_FILES={'move':['idle','walk','spawn'],'act':['bite','hurt','death']}
def actions():
 rig=Rig(JOINTS);a={};sin=math.sin;pi=math.pi
 def rest(extra=None,drop=.12):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-17,head=13,jaw=-8,armL=(12,0,9),armR=(12,0,-9),foreL=14,foreR=14,fingersL=12,fingersR=12,rag=7);p.update(extra or {});return rig.planted(p)
 a['idle']=([(i*2.5,rest(pose(chest=-17+sin(i/24*2*pi),head=13+sin(i/24*2*pi-.6),jaw=-8-sin(i/24*2*pi),rag=7+sin(i/24*2*pi-.7))))for i in range(25)],True)
 keys=[]
 for i in range(49):
  q=i/48;t=q*2*pi;feet={}
  for side,phase in [('L',q),('R',q+.5)]:
   phase%=1
   if phase<.6:y=.4*(1-2*phase/.6);z=0
   else:u=(phase-.6)/.4;y=-.4+.8*u*u*(3-2*u);z=.18*sin(pi*u)
   feet[side]=(0,y,z)
  p=pose(body=(0,0,0,(.018*sin(t),0,-.24)),chest=(-22,0,4*sin(t)),head=(17,0,-3*sin(t)),jaw=-9,armL=24*sin(t),armR=-24*sin(t),foreL=20,foreR=20,fingersL=18,fingersR=18,rag=7+5*sin(t-.5))
  keys.append((q*.6*30,rig.planted(p,feet)))
 a['walk']=(keys,True)
 a['bite']=([(0,rest()),(4,rest(pose(chest=3,head=-3,armL=85,armR=62,foreL=41,foreR=35,jaw=-23),.21)),(7.5,rest(pose(chest=-36,head=25,armL=61,armR=45,foreL=-9,foreR=-7,fingersL=-13,fingersR=-13),.34)),(10,rest(pose(chest=-31,head=21,armL=31,armR=22),.29)),(15,rest())],False)
 a['spawn']=([(0,rest(pose(chest=-34,head=-8,armL=32,armR=19),.55)),(9,rest(pose(chest=-25,head=20,armL=26,armR=22),.32)),(21,rest())],False)
 a['hurt']=([(0,rest()),(3,rest(pose(chest=(7,0,10),head=(19,0,-13),jaw=-21),.22)),(8,rest())],False)
 def fall(x,extra=None):
  p=pose(body=(x,0,-7,(0,.15,-.7)),chest=-4,head=4,jaw=-12,armL=(-16,0,24),armR=(-19,0,-19),foreL=2,foreR=3,handL=-24,handR=-26,fingersL=-16,fingersR=-14,legL=0,legR=-8,shinL=-4,shinR=-3,footL=-32,footR=-33,rag=0);p.update(extra or {});return p
 a['death']=([(0,rest()),(6,rest(pose(chest=9,head=21,jaw=-24),.24)),(15,rest(pose(chest=-31,head=17,armL=67,armR=32),.59)),(24,fall(-39,pose(legL=36,legR=26,shinL=-73,shinR=-61,armL=54,armR=43))),(34,fall(-76)),(40,fall(-89)),(44,fall(-83,pose(head=13))),(51,fall(-89)),(60,fall(-89))],False)
 return a
PREVIEWS=[('idle',15),('bite',7.5),('death',60)];PREVIEW_CAMERA=((7,10,6),(0,0,1.8),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,2),6),'back':((1,0,0),(0,0,1),(0,0,2),6)}
if __name__=='__main__':run(globals())
