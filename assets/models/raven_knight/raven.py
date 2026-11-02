"""Articulated original crow: five fan feathers per wing, hinged wrists, feet and tail."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='raven';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,.6)),('neck','body',(0,.38,.79)),('head','neck',(0,.54,.94)),('tail','body',(0,-.5,.57))]
g=Geometry();a,m,b=g.add,g.mass,g.beam
m('Body','body',(0,0,.65),(.64,1.2,.65),(32,39,47),3,3)
m('Head','head',(0,.57,1.0),(.52,.59,.53),(42,49,55),3,3)
for k in range(3):a('Beak'+str(k),'head',(0,.87+k*.12,.99-k*.025),(.26-k*.065,.15,.18-k*.035),(67,70,70))
for s in[-1,1]:a('Eye'+str(s),'head',(s*.26,.69,1.07),(.025,.085,.085),(138,140,137))
for k in range(5):b('Tail'+str(k),'tail',((k-2)*.1,-.42,.59),((k-2)*.15,-1.08,.5),.13,.09,(36,44,55))
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('wing'+side,'body',(s*.26,0,.74)),('tip'+side,'wing'+side,(s*.91,-.08,.71)),('foot'+side,'body',(s*.19,.0,.45))]
 b('WingBase'+side,'wing'+side,(s*.26,0,.74),(s*.93,-.08,.71),.37,.16,(45,53,66))
 for k in range(5):
  b('WingFeather'+side+str(k),'tip'+side,(s*(.75+k*.1),-.1-k*.06,.71),(s*(1.28+k*.15),-.38-k*.13,.65),.17,.11,(39+k*2,47+k*2,59+k*2))
 b('Leg'+side,'foot'+side,(s*.19,0,.45),(s*.2,.02,.16),.08,.08,(71,70,65))
 for k in[-1,0,1]:b('Toe'+side+str(k),'foot'+side,(s*.2,.02,.16),(s*.2+k*.09,.28,.12),.045,.05,(89,86,77))
PARTS=g.parts
def actions():
 out={}
 for name,length,amp in [('idle',.7,43),('flight',.55,57),('dive',.9,21)]:
  keys=[]
  for i in range(25):
   t=i/24*math.tau;p=pose(body=(8 if name=='dive' else 0,0,0,(0,0,.04*math.sin(t))),head=-5,tail=4+7*math.sin(t-.6),
    wingL=(0,amp*math.sin(t),0),wingR=(0,-amp*math.sin(t),0),tipL=(0,amp*.5*math.sin(t-.7),-8),tipR=(0,-amp*.5*math.sin(t-.7),8),footL=24,footR=24)
   keys.append((i/24*length*30,p))
  keys[-1]=(keys[-1][0],dict(keys[0][1]));out[name]=(keys,True)
 return out
PREVIEW_PREFIX='raven-preview-';PREVIEWS=[('flight',5)];PREVIEW_CAMERA=((4,6,3),(0,0,.6),48)
if __name__=='__main__':run(globals())
