"""Original pale nocturnal moth; headless cuboid sculpture and articulated wings."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from moth_motion import make_actions
NAME='moth';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=1.8;GAME_LIFT={'saturate':1,'gain':1};BACKGROUND=(163,168,175)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
CREAM=(197,192,174);PALE=(215,209,190);SHADE=(160,155,147);VEIN=(112,108,125);CHITIN=(85,82,96);DARK=(59,55,70);EYE=(65,54,79)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,3.9)),('chest','body',(0,0,5.8)),('neck','chest',(0,0,6.9)),('head','neck',(0,.08,7.65)),('jaw','head',(0,.6,7.3)),
 ('abdomen1','body',(0,-.65,4.5)),('abdomen2','abdomen1',(0,-1.85,3.7)),('abdomen3','abdomen2',(0,-2.85,2.65))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('arm'+side,'chest',(s*1.17,0,6.12)),('fore'+side,'arm'+side,(s*1.72,.35,4.95)),
  ('hand'+side,'fore'+side,(s*1.91,.95,4.18)),('fingers'+side,'hand'+side,(s*1.92,1.05,4.0)),('thumb'+side,'hand'+side,(s*1.64,1.02,4.15)),
  ('leg'+side,'body',(s*.65,0,3.9)),('shin'+side,'leg'+side,(s*.92,.3,2.17)),('foot'+side,'shin'+side,(s*1.05,0,.35)),
  ('wing'+side,'chest',(s*.88,-.48,6.38)),('wingTip'+side,'wing'+side,(s*4.1,-.8,7.55)),
  ('hind'+side,'chest',(s*.8,-.58,5.96)),('hindTip'+side,'hind'+side,(s*3.2,-1.0,4.1)),
  ('antenna'+side,'head',(s*.42,.02,8.1)),('antennaTip'+side,'antenna'+side,(s*.95,.04,9.3)),('collar'+side,'chest',(s*.8,.25,6.64))]
PARTS=[]
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def mass(n,j,c,size,col,layers=4,slices=4):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  u=(i+.5)/layers*2-1;r=math.sqrt(1-u*u)
  for k in range(slices):
   v=(k+.5)/slices*2-1
   add(n+str(i)+'_'+str(k),j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*math.sqrt(1-v*v),d*r/slices,h/layers),col)
def beam(n,j,a,b,w,d,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(v) for v in v.to_track_quat('Z','Y').to_euler()))
mass('Waist','body',(0,0,4.55),(1.65,1.3,1.9),CHITIN)
mass('Thorax','chest',(0,0,6.05),(2.45,1.65,2.3),CREAM)
for k in range(4):
 mass('Sternum'+str(k),'body',(0,.64,5.38-k*.47),(1.35-k*.19,.32,.62),PALE,2,3)
for side,s in [('L',1),('R',-1)]:
 for row in range(3):
  for k in range(4):
   x=s*(.25+k*.3);z=6.93-row*.37-k*.12;y=.65-.16*k
   beam('Collar'+side+str(row)+str(k),'collar'+side,(x,y,z),(x+s*.21,y+.1,z-.64),.42,.42,PALE if (k+row)%2 else CREAM)
 for k in range(5):
  beam('BackTuft'+side+str(k),'chest',(s*(.3+k*.2),-.66,6.8-k*.13),(s*(.5+k*.2),-.93,6.25-k*.16),.38,.38,CREAM)
 beam('Arm'+side,'arm'+side,(s*1.17,0,6.12),(s*1.72,.35,4.95),.57,.62,CHITIN)
 mass('Elbow'+side,'fore'+side,(s*1.72,.35,4.95),(.6,.63,.55),VEIN,2,3)
 beam('Forearm'+side,'fore'+side,(s*1.72,.35,4.95),(s*1.91,.95,4.18),.48,.51,CHITIN)
 mass('Hand'+side,'hand'+side,(s*1.91,.97,4.16),(.62,.57,.59),VEIN,2,3)
 for k in range(2):
  x=s*(1.81+k*.27)
  beam('ClawBase'+side+str(k),'fingers'+side,(x,1.1,4),(x,1.3,3.52),.18,.21,PALE)
  beam('ClawTip'+side+str(k),'fingers'+side,(x,1.3,3.52),(x,1.53,3.36),.09,.11,CREAM)
 beam('Thumb'+side,'thumb'+side,(s*1.64,1.02,4.15),(s*1.52,1.38,3.78),.19,.2,PALE)
 beam('Thigh'+side,'leg'+side,(s*.65,0,3.9),(s*.92,.3,2.17),.71,.83,CHITIN)
 mass('Knee'+side,'shin'+side,(s*.92,.3,2.17),(.64,.7,.57),VEIN,2,3)
 beam('Shin'+side,'shin'+side,(s*.92,.3,2.17),(s*1.05,0,.35),.42,.52,CHITIN)
 mass('Foot'+side,'foot'+side,(s*1.05,.2,.26),(.73,1.13,.48),VEIN,2,3)
 for k in range(3):beam('Toe'+side+str(k),'foot'+side,(s*1.05+(k-1)*.25,.45,.28),(s*1.05+(k-1)*.29,1,.07),.19,.2,PALE)
 for k in range(2):
  beam('HipTuft'+side+str(k),'body',(s*(.65+k*.2),.35,4.65),(s*(.82+k*.18),.55,3.96-k*.1),.36,.3,CREAM)
mass('Head','head',(0,.05,7.65),(1.5,1.5,1.52),CREAM,5,5)
for side,s in [('L',1),('R',-1)]:
 mass('EyeSocket'+side,'head',(s*.49,.62,7.7),(.62,.35,.98),SHADE,3,3)
 mass('Eye'+side,'head',(s*.49,.8,7.72),(.48,.23,.76),EYE,4,3)
 beam('Brow'+side,'head',(s*.22,.77,8.1),(s*.8,.55,8.24),.19,.2,PALE)
 beam('Mandible'+side,'jaw',(s*.24,.65,7.26),(s*.12,.93,6.99),.2,.22,VEIN)
 for seg,(a,b) in enumerate([((s*.42,.02,8.1),(s*.95,.04,9.3)),((s*.95,.04,9.3),(s*1.62,.03,10.18))]):
  j=('antenna' if seg==0 else 'antennaTip')+side
  beam('Antenna'+side+str(seg),j,a,b,.13,.13,VEIN)
  for k in range(6):
   p=Vector(a).lerp(Vector(b),(k+.3)/6);width=.3*(1-.3*seg)
   beam('Comb'+side+str(seg)+str(k),j,p,p+Vector((s*width,.04,-.21)),.1,.1,PALE)
add('MaskRidge','head',(0,.79,7.72),(.22,.18,1.13),PALE)
for k,(j,c,size) in enumerate([('abdomen1',(0,-1.25,4.0),(1.85,1.95,1.75)),('abdomen2',(0,-2.28,3.13),(1.5,1.78,1.56)),('abdomen3',(0,-3.19,2.25),(1.0,1.55,1.29))]):
 mass('Abdomen'+str(k),j,c,size,CREAM,4,4)
 for s in [-1,1]:beam('Stripe'+str(k)+str(s),j,(s*size[0]*.39,c[1]-.45,c[2]+.4),(s*size[0]*.45,c[1]+.38,c[2]+.1),.24,.25,VEIN)
beam('AbdomenTip','abdomen3',(0,-3.54,1.94),(0,-3.92,1.61),.35,.35,PALE)
# Scanline cells with merged equal-color runs produce a closed stepped, double-sided wing.
def polygon_span(poly,z):
 xs=[]
 for a,b in zip(poly,poly[1:]+poly[:1]):
  if (a[1]<=z<b[1])or(b[1]<=z<a[1]):xs.append(a[0]+(b[0]-a[0])*(z-a[1])/(b[1]-a[1]))
 return (min(xs),max(xs)) if xs else None
for side,s in [('L',1),('R',-1)]:
 for kind,poly,split,eye in [('wing',[(.87,6.38),(3.7,8.21),(6.15,9.27),(7.05,9.02),(6.42,7.6),(4.7,5.8),(1.0,6.1)],4.1,(4.9,7.93)),('hind',[(.8,5.96),(3.25,5.78),(4.83,4.88),(5.29,1.22),(3.5,2.55),(1.05,5.35)],3.2,(3.55,3.7))]:
  z0=min(v[1]for v in poly);z1=max(v[1]for v in poly);step=.26;row=0;z=z0+step/2
  while z<z1:
   span=polygon_span(poly,z)
   if span:
    x0,x1=span;n=max(1,math.ceil((x1-x0)/step));dx=(x1-x0)/n;runs=[]
    for k in range(n):
     x=x0+(k+.5)*dx;edge=min(x-x0,x1-x);d=math.sqrt(((x-eye[0])/.86)**2+((z-eye[1])/.71)**2)
     vein=abs((z-6.2)/(max(.2,x-.7))-(.39 if kind=='wing'else -.63))
     col=VEIN if edge<.25 or d<.34 or .85<d<1.12 or vein<.055 else (SHADE if edge<.46 or .67<d<.85 else CREAM)
     j=(kind if x<split else kind+'Tip')+side
     if runs and runs[-1][2:]==(col,j):runs[-1]=(runs[-1][0],k,col,j)
     else:runs.append((k,k,col,j))
    for a,b,col,j in runs:
     x=x0+(a+b+1)/2*dx;y=-.55-.09*x
     add(kind+side+str(row)+'_'+str(a),j,(s*x,y,z),((b-a+1)*dx+.008,.19+(.06 if col==VEIN else 0),step+.008),col)
   row+=1;z+=step
EXTRA_JSON={'walkSpeed':3.0,'runSpeed':5.0}
CLIP_FILES={'idle':['idle','strafe'],'walk':['walk'],'run':['run'],'melee':['attack1','attack3','attack4','hurt','jump'],
 'magic':['shadowlight','moonssight'],'ritual':['meteorrain','midnight'],'flight':['startshoot','descendshot','descendend'], 'life':['spawn','stun','death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',20),('shadowlight',25),('meteorrain',35),('startshoot',60),('death',60)]
PREVIEW_CAMERA=((15,21,12),(0,0,4.5),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.1),17),'side':((0,-1,0),(0,0,1),(0,0,5.1),17),
 'back':((1,0,0),(0,0,1),(0,0,5.1),17),'top':((1,0,0),(0,1,0),(0,0,0),18)}
if __name__=='__main__':run(globals())
