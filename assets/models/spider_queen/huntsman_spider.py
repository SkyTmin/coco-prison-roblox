"""Original compact add using the queen's articulated anatomy at lower geometric cost."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
import spider_queen as queen
from blockmob import box,run
NAME='huntsman_spider';HERE=os.path.dirname(os.path.abspath(__file__));SCALE=.27
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
JOINTS=[(n,p,tuple(x*SCALE for x in v)) for n,p,v in queen.JOINTS]
PARTS=[];SHELL=(76,61,44);BAND=(118,95,61);DARK=(44,37,29);IVORY=(159,145,117)
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=[v*SCALE for v in c];w,d,h=[v*SCALE/2 for v in size]
 PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def beam(n,j,a,b,w,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,w,v.length),col,tuple(math.degrees(x) for x in v.to_track_quat('Z','Y').to_euler()))
def mass(n,j,c,size):
 x,y,z=c;w,d,h=size
 for i in range(3):
  r=math.sqrt(1-((i+.5)/3*2-1)**2)
  for k in range(5):
   v=(k+.5)/5*2-1
   add(n+str(i)+str(k),j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/3),(w*r*math.sqrt(1-v*v),d*r/5,h/3),SHELL if i<2 else BAND)
mass('Abdomen','abdomen',(0,-2.85,3.72),(4,4.7,3.5))
mass('Body','body',(0,.28,3.2),(3.6,3.65,2.65))
mass('Head','head',(0,2.22,2.94),(2.75,2.15,2.05))
for side,s in [('L',1),('R',-1)]:
 for i,(hip,knee,foot) in enumerate(queen.LEG_POINTS):
  n=side+str(i);a,b,c=[Vector((s*p[0],*p[1:])) for p in [hip,knee,foot]]
  beam('Upper'+n,'leg'+n,a,b,.62,SHELL)
  beam('Knee'+n,'leg'+n,a.lerp(b,.87),b,.76,BAND)
  beam('Lower'+n,'shin'+n,b,b.lerp(c,.94),.4,DARK)
  add('Foot'+n,'foot'+n,(c.x,c.y,.14),(.24,.3,.28),DARK)
 beam('Jaw'+side,'jaw'+side,(s*.53,2.65,2.64),(s*.62,3.08,2.37),.6,DARK)
 beam('Fang'+side,'fang'+side,(s*.62,3.08,2.37),(s*.72,3.4,1.8),.32,IVORY)
 beam('FangTip'+side,'fang'+side,(s*.72,3.4,1.8),(s*.51,3.49,1.38),.17,IVORY)
 beam('Palp'+side,'palp'+side,(s*1.02,2.28,2.7),(s*1.48,3,2.2),.4,SHELL)
 beam('PalpTip'+side,'palpTip'+side,(s*1.48,3,2.2),(s*1.4,3.45,1.45),.26,DARK)
 for i,(x,z) in enumerate([(.35,3.4),(.83,3.4),(.48,3.0)]):add('Eye'+side+str(i),'head',(s*x,3.15,z),(.23,.14,.24),(154,87,26))
def actions():
 source=queen.actions();out={}
 for name,original,length in [('idle','idle',3.5294),('bite','bite',.6039),('hurt','hurt',.4),('spawn','spawn',.7),('death','death',2)]:
  keys,loop=source[original];end=keys[-1][0]
  out[name]=([(f/end*length*30,{n:tuple(v[:3])+(tuple(x*SCALE for x in v[3]) if v[3] else None,) for n,v in p.items()}) for f,p in keys],loop)
 keys=source['walk'][0];walk=[]
 for cycle in range(2):
  for f,p in keys:
   if cycle and f==0:continue
   walk.append((cycle*15+f/keys[-1][0]*15,{n:tuple(v[:3])+(tuple(x*SCALE for x in v[3]) if v[3] else None,) for n,v in p.items()}))
 out['walk']=(walk,True)
 return out
EXTRA_JSON={'walkSpeed':2.7};TILE_STUDS=1;GAME_LIFT={'saturate':1,'gain':1.1}
CLIP_FILES={'walk':['walk'],'life':['spawn','death'],'idle':['idle','bite','hurt']}
PREVIEWS=[('idle',20),('bite',9),('death',59)]
PREVIEW_CAMERA=((5,6,4),(0,0,.6),50);COMPARE_PREFIX='huntsman-compare-'
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,.8),4.7),'side':((0,-1,0),(0,0,1),(0,0,.8),4.7)}
if __name__=='__main__':run(globals())
