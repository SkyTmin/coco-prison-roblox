"""Original small conjured rabbit: articulated hops, ears, warning and collapse."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box,run
from splinter.motion import pose
NAME='illusionist_rabbit';HERE=os.path.dirname(os.path.abspath(__file__))
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
JOINTS=[('root',None,(0,0,0)),('body','root',(0,-.12,.82)),('head','body',(0,.62,1.25)),
 ('earL','head',(.24,.47,1.67)),('earR','head',(-.24,.47,1.67)),('tail','body',(0,-.87,.9))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('front'+side,'body',(s*.34,.44,.78)),('hind'+side,'body',(s*.4,-.53,.69)),('foot'+side,'hind'+side,(s*.42,-.27,.16))]
PARTS=[]
CREAM=(190,185,174);SHADE=(158,153,145);PINK=(142,92,94);DARK=(37,32,35);RED=(120,46,53)
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def mass(n,j,c,size,col,layers=3,slices=4):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  r=math.sqrt(1-((i+.5)/layers*2-1)**2)
  for k in range(slices):
   v=(k+.5)/slices*2-1
   add(n+str(i)+'_'+str(k),j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*math.sqrt(1-v*v),d*r/slices,h/layers),col)
mass('Body','body',(0,-.12,.82),(1.04,1.6,1.05),CREAM)
mass('Head','head',(0,.65,1.35),(.82,.93,.81),CREAM)
mass('Muzzle','head',(0,1.09,1.16),(.54,.36,.32),SHADE,2,3)
add('Nose','head',(0,1.3,1.27),(.15,.12,.12),PINK)
add('Collar','body',(0,.55,.98),(.9,.19,.19),RED)
mass('Tail','tail',(0,-.98,1.0),(.42,.48,.47),CREAM,2,3)
for side,s in [('L',1),('R',-1)]:
 j='ear'+side
 add('EarBase'+side,j,(s*.25,.43,1.99),(.23,.27,.68),CREAM,(0,s*9,0))
 add('EarTip'+side,j,(s*.3,.43,2.36),(.18,.24,.24),SHADE,(0,s*12,0))
 add('EarInside'+side,j,(s*.25,.575,2.04),(.12,.025,.57),PINK,(0,s*9,0))
 add('Eye'+side,'head',(s*.35,.94,1.47),(.13,.1,.18),DARK)
 add('EyeShine'+side,'head',(s*.35,1.0,1.51),(.045,.025,.05),CREAM)
 add('FrontLeg'+side,'front'+side,(s*.34,.46,.43),(.23,.31,.69),CREAM)
 add('FrontPaw'+side,'front'+side,(s*.34,.6,.13),(.29,.47,.25),SHADE)
 mass('Haunch'+side,'hind'+side,(s*.4,-.54,.52),(.51,.75,.8),CREAM,3,3)
 add('HindPaw'+side,'foot'+side,(s*.42,-.05,.13),(.42,.75,.25),SHADE)
EXTRA_JSON={'walkSpeed':6}
TILE_STUDS=1.4;GAME_LIFT={'saturate':1,'gain':1}
def actions():
 a={}
 idle=[]
 for i in range(17):
  t=i/16*2*math.pi
  idle.append((i*3,pose(head=(2*math.sin(t),0,1.5*math.sin(t-.2)),earL=(-8+4*math.sin(t-.5),0,4),earR=(-5+3*math.sin(t-.8),0,-4),tail=3*math.sin(t))))
 a['idle']=(idle,True)
 a['walk']=([(0,pose(body=(-10,0,0,(0,0,-.13)),head=8,hindL=25,hindR=25,footL=-22,footR=-22,frontL=10,frontR=10,earL=-20,earR=-17)),
  (5,pose(body=(9,0,0,(0,0,.22)),head=-7,hindL=-33,hindR=-33,footL=18,footR=18,frontL=-24,frontR=-24,earL=-32,earR=-28)),
  (10,pose(body=(0,0,0,(0,0,.4)),head=-4,hindL=14,hindR=14,footL=-12,footR=-12,frontL=32,frontR=32,earL=-38,earR=-34)),
  (16,pose(body=(-13,0,0,(0,0,.06)),head=10,hindL=27,hindR=27,footL=-19,footR=-19,frontL=15,frontR=15,earL=-15,earR=-19)),
  (20,pose(body=(-6,0,0,(0,0,-.1)),head=4,hindL=18,hindR=18,footL=-13,footR=-13,frontL=8,frontR=8,earL=-5,earR=-9))],True)
 a['walk'][0].append((24,dict(a['walk'][0][0][1])))
 keys=[(0,pose()),(12,pose(body=(9,0,0,(0,0,-.08)),head=12,earL=-27,earR=-33,frontL=20,frontR=20))]
 for f in [24,36,48,60,69,75]:
  v=math.sin(f*.6)
  keys.append((f,pose(body=(12+v*2,0,v,(0,0,-.1)),head=17-v*3,earL=-42+v*5,earR=-39-v*4,frontL=27,frontR=25)))
 keys += [(82,pose(body=(-9,0,0,(0,0,.11)),head=-8,earL=8,earR=12)),(105,pose())]
 a['bite']=(keys,False)
 a['hurt']=([(0,pose()),(4,pose(body=(6,0,-9),head=12,earL=-25,earR=-19)),(12,pose())],False)
 a['death']=([(0,pose()),(12,pose(body=(10,0,-12),head=8,earL=-24,earR=-18)),
  (30,pose(body=(-7,0,-38,(0,0,-.15)),head=-12,frontL=22,frontR=-10,hindL=-21,hindR=9,earL=-38,earR=-27)),
  (48,pose(body=(-3,0,-84,(.1,0,-.35)),head=14,frontL=32,frontR=16,hindL=17,hindR=-18,earL=-60,earR=-36)),
  (65,pose(body=(-2,0,-78,(.1,0,-.35)),head=8,frontL=22,frontR=12,hindL=12,hindR=-13,earL=-49,earR=-39)),
  (85,pose(body=(-2,0,-83,(.1,0,-.35)),head=5,frontL=18,frontR=10,hindL=8,hindR=-10,earL=-54,earR=-41)),
  (105,pose(body=(-2,0,-83,(.1,0,-.35)),head=5,frontL=18,frontR=10,hindL=8,hindR=-10,earL=-54,earR=-41))],False)
 return a
PREVIEWS=[('idle',15),('walk',10),('bite',60),('death',100)]
PREVIEW_CAMERA=((4,7,3.5),(0,0,1),52)
COMPARE_PREFIX='rabbit-compare-'
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,1.2),4.3),'side':((0,1,0),(0,0,1),(0,0,1.2),4.3)}
if __name__=='__main__':run(globals())
