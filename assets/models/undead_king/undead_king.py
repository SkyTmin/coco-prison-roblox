"""Original crowned necromancer, modeled as closed cuboid volumes in headless Blender."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from undead_motion import make_actions
NAME='undead_king';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'saturate':1,'gain':1};BACKGROUND=(174,181,179)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'crown':(15,49)}}
BONE=(177,171,150);IVORY=(204,196,172);SOCKET=(31,32,30);IRON=(52,66,67);EDGE=(82,95,94);BLACK=(38,43,44);CLOTH=(43,48,49);TEAL=(48,79,79);BRONZE=(124,111,83);GEM=(78,63,91)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.3)),('chest','body',(0,0,6.2)),('neck','chest',(0,0,7.9)),('head','neck',(0,.12,8.7)),('jaw','head',(0,.53,8.33)),('crown','head',(0,0,9.52))]
for k in ['L','C','R']:
 x={'L':1.0,'C':0,'R':-1.0}[k]
 JOINTS += [('cape'+k+'1','chest',(x,-.85,7.65)),('cape'+k+'2','cape'+k+'1',(x*1.5,-1.12,5.35)),('cape'+k+'3','cape'+k+'2',(x*1.85,-1.42,3.0))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('cloth'+side+'1','body',(s*.7,.7,4.55)),('cloth'+side+'2','cloth'+side+'1',(s*.8,.86,2.72)),
  ('arm'+side,'chest',(s*1.75,0,7.37)),('fore'+side,'arm'+side,(s*2.25,.06,5.83)),('hand'+side,'fore'+side,(s*2.66,.42,4.55)),
  ('fingers'+side,'hand'+side,(s*2.68,.58,4.35)),('outer'+side,'hand'+side,(s*2.95,.53,4.35)),('thumb'+side,'hand'+side,(s*2.35,.53,4.5)),
  ('leg'+side,'body',(s*.82,0,4.3)),('shin'+side,'leg'+side,(s*.99,.1,2.35)),('foot'+side,'shin'+side,(s*1.07,.0,.4))]
PARTS=[]
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def mass(n,j,c,size,col,layers=3,slices=4):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  u=(i+.5)/layers*2-1;r=math.sqrt(1-u*u)
  for k in range(slices):
   v=(k+.5)/slices*2-1
   add(n+str(i)+'_'+str(k),j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*math.sqrt(1-v*v),d*r/slices,h/layers),col)
def beam(n,j,a,b,w,d,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(x)for x in v.to_track_quat('Z','Y').to_euler()))
mass('Waist','body',(0,0,5.15),(2.6,1.55,2.0),BLACK,4,4)
mass('Chest','chest',(0,.03,6.92),(3.1,1.82,1.75),IRON,4,4)
for side,s in [('L',1),('R',-1)]:
 for k in range(3):
  beam('RibPlate'+side+str(k),'chest',(s*.14,.97,7.55-k*.42),(s*(1.35-k*.13),.74,7.2-k*.36),.23,.25,EDGE)
  beam('WaistPlate'+side+str(k),'body',(s*.1,.79,5.95-k*.42),(s*(1.14-k*.08),.6,5.7-k*.42),.22,.22,IRON)
  beam('PlateTrim'+side+str(k),'body',(s*.14,.91,5.91-k*.42),(s*(1.13-k*.08),.73,5.66-k*.42),.07,.08,BRONZE)
 mass('Shoulder'+side,'arm'+side,(s*1.74,0,7.28),(1.55,1.65,1.0),IRON,3,4)
 for k in range(3):
  beam('Pauldron'+side+str(k),'arm'+side,(s*(1.18+k*.22),.73,7.76-k*.25),(s*(2.25+k*.12),.58,7.34-k*.24),.25,.24,BRONZE if k==0 else EDGE)
 for k in range(2):beam('ShoulderBone'+side+str(k),'arm'+side,(s*(1.8+k*.4),.1,7.68),(s*(1.85+k*.5),.1,8.2-k*.13),.18,.22,BONE)
 beam('Humerus'+side,'arm'+side,(s*1.8,.0,6.95),(s*2.25,.06,5.83),.48,.5,BONE)
 mass('Elbow'+side,'fore'+side,(s*2.25,.06,5.83),(.58,.6,.43),IVORY,2,3)
 for k in [-1,1]:beam('ForeBone'+side+str(k),'fore'+side,(s*2.25+k*.15,.08,5.72),(s*2.66+k*.14,.4,4.62),.16,.18,BONE)
 beam('Bracer'+side,'fore'+side,(s*2.35,.32,5.49),(s*2.57,.52,4.87),.65,.34,IRON)
 for k in [-1,1]:beam('BracerTrim'+side+str(k),'fore'+side,(s*2.35+k*.26,.51,5.5),(s*2.57+k*.25,.7,4.87),.08,.1,BRONZE)
 for k in range(4):
  x=s*(2.42+k*.17);j=('fingers'if k<2 else 'outer')+side;y=.55-.025*k;z=4.31
  beam('Metacarpal'+side+str(k),'hand'+side,(x,.43,4.59),(x,y,z),.11,.13,BONE)
  add('Knuckle'+side+str(k),j,(x,y,z),(.17,.19,.18),IVORY)
  length=.47-abs(k-1)*.06
  beam('FingerProx'+side+str(k),j,(x,y,z),(x+s*.045,y+.15,z-length),.12,.13,BONE)
  beam('FingerTip'+side+str(k),j,(x+s*.045,y+.15,z-length),(x+s*.03,y+.35,z-length-.14),.11,.12,IVORY)
 beam('ThumbBase'+side,'thumb'+side,(s*2.35,.53,4.5),(s*2.17,.78,4.27),.17,.18,BONE)
 beam('ThumbTip'+side,'thumb'+side,(s*2.17,.78,4.27),(s*2.21,.94,4.11),.14,.15,IVORY)
 mass('Thigh'+side,'leg'+side,(s*.9,0,3.55),(1.12,1.17,1.7),BLACK,3,3)
 mass('Knee'+side,'shin'+side,(s*.99,.16,2.35),(1.0,1.15,.68),IRON,2,4)
 add('KneeBone'+side,'shin'+side,(s*.99,.76,2.4),(.43,.12,.45),BONE)
 for dx in [-.12,.12]:add('KneeSocket'+side+str(dx),'shin'+side,(s*.99+dx,.83,2.48),(.13,.035,.12),SOCKET)
 beam('Greave'+side,'shin'+side,(s*.99,.1,2.08),(s*1.07,0,.52),.83,.9,IRON)
 for dx in [-.3,.3]:beam('GreaveEdge'+side+str(dx),'shin'+side,(s*.99+dx,.61,2.12),(s*1.07+dx,.5,.6),.09,.1,BRONZE)
 mass('Boot'+side,'foot'+side,(s*1.07,.32,.26),(1.11,1.65,.5),IRON,2,4)
 add('Sole'+side,'foot'+side,(s*1.07,.32,.09),(1.15,1.7,.18),BLACK)
 for k in range(3):add('BootScale'+side+str(k),'foot'+side,(s*1.07,.52+k*.24,.49-k*.07),(.99,.23,.12),EDGE)
 for k,(z,h) in enumerate([(3.64,1.82),(1.79,1.9)],1):
  j='cloth'+side+str(k)
  for col in range(4):
   x=s*(.34+col*.25);hh=h-(.15*(col%2)if k==2 else 0)
   add('Robe'+side+str(k)+str(col),j,(x,.76+(.05 if col%2 else 0),z),(.26,.18,hh),CLOTH if col%2 else BLACK)
  add('RobeTrim'+side+str(k),j,(s*.26,.89,z),(.1,.07,h-.15),BRONZE)
mass('Belt','body',(0,0,4.55),(2.72,1.64,.28),BRONZE,1,4)
add('Buckle','body',(0,.91,4.55),(.53,.2,.62),BRONZE);add('BuckleInset','body',(0,1.02,4.55),(.27,.035,.31),EDGE)
for k in range(3):mass('Neck'+str(k),'neck',(0,0,7.94+k*.19),(.55,.63,.2),BONE,1,3)
mass('SkullBack','head',(0,.02,8.98),(1.56,1.3,1.4),BONE,4,5)
add('FaceRecess','head',(0,.66,8.77),(1.47,.15,.96),SOCKET)
for side,s in [('L',1),('R',-1)]:
 beam('Brow'+side,'head',(s*.07,.86,9.16),(s*.69,.73,9.18),.22,.28,IVORY)
 beam('Cheek'+side,'head',(s*.25,.85,8.57),(s*.72,.75,8.71),.18,.22,BONE)
 beam('Temple'+side,'head',(s*.73,.65,9.12),(s*.74,.64,8.58),.18,.22,BONE)
 beam('JawHinge'+side,'jaw',(s*.62,.4,8.35),(s*.56,.84,8.11),.19,.22,BONE)
 for k in range(3):
  add('UpperTooth'+side+str(k),'head',(s*(.12+k*.17),.87,8.36),(.12,.21,.23),IVORY)
  add('LowerTooth'+side+str(k),'jaw',(s*(.12+k*.17),.89,8.17),(.12,.2,.16),IVORY)
add('NoseBridge','head',(0,.86,8.86),(.16,.21,.45),IVORY)
add('NoseHole','head',(0,.9,8.56),(.23,.055,.24),SOCKET)
add('JawChin','jaw',(0,.83,8.03),(1.11,.34,.22),BONE)
for k in range(12):
 a=k*math.pi/6;x,y=math.cos(a)*.79,math.sin(a)*.65
 add('CrownBand'+str(k),'crown',(x,y,9.55),(.4,.22,.31),BRONZE,(0,0,math.degrees(a)+90))
 if k%2==0:
  h=.74+(.19 if k in [2,8]else 0)
  beam('CrownPoint'+str(k),'crown',(x,y,9.61),(x*.96,y*.96,9.61+h),.14,.16,BRONZE)
  add('CrownGem'+str(k),'crown',(x*1.08,y*1.08,9.67),(.2,.2,.24),GEM)
add('ClaspFrame','chest',(0,1.02,7.16),(.62,.18,.73),BRONZE);add('Clasp','chest',(0,1.12,7.16),(.42,.055,.51),TEAL)
for section in ['L','C','R']:
 s={'L':1,'C':0,'R':-1}[section]
 for k,(z,h,w,y) in enumerate([(6.52,2.3,1.22,-1.01),(4.19,2.4,1.46,-1.28),(1.82,2.4,1.68,-1.6)],1):
  j='cape'+section+str(k);x=s*(.98+(k-1)*.32)
  for col in range(5):
   rag=.18*(col%3)if k==3 else 0;xx=x+(col-2)*w/5
   ya,yb=[(-.88,-1.14),(-1.14,-1.42),(-1.42,-1.8)][k-1]
   fold=.06 if col%2 else 0
   a=(xx,ya-fold,z+h/2+.13);b=(xx,yb-fold,z-h/2-.13+rag)
   beam('Cape'+section+str(k)+str(col),j,a,b,w/5+.06,.24,CLOTH if col%2 else BLACK)
   if col in [0,4]:beam('CapeLining'+section+str(k)+str(col),j,(a[0],a[1]+.145,a[2]),(b[0],b[1]+.145,b[2]),.22,.05,TEAL)
EXTRA_JSON={'walkSpeed':2.777778,'runSpeed':5}
CLIP_FILES={'loco':['idle','walk','run'],'combat':['attack','attack2','skill3'],'ritual':['skill1','skill2','swordcall'], 'life':['spawn','hurt','jump','death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',15),('skill1',42),('skill3',10.8),('death',90)]
PREVIEW_CAMERA=((14,23,12),(0,0,5),50)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.3),16),'side':((0,-1,0),(0,0,1),(0,0,5.3),16),'back':((1,0,0),(0,0,1),(0,0,5.3),16)}
if __name__=='__main__':run(globals())
