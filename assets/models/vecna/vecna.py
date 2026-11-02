"""Original matte tendril humanoid, closed stepped volumes and six articulated dorsal tendrils."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from vecna_motion import make_actions
NAME='vecna';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(175,174,171)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
BASE=(74,62,54);DARK=(43,34,33);RIDGE=(112,96,80);HIGH=(135,119,98);TENDRIL=(62,48,42)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.2)),('chest','body',(0,0,6.1)),('neck','chest',(0,0,7.9)),('head','neck',(0,.02,8.42)),('jaw','head',(0,.35,8.1))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
mass('Waist','body',(0,0,5.08),(1.75,1.35,1.82),DARK,5,5)
mass('Pelvis','body',(0,0,4.39),(2.12,1.51,.88),BASE,3,4)
mass('Thorax','chest',(0,-.08,6.92),(2.9,1.75,1.97),BASE,5,6)
for side,s in [('L',1),('R',-1)]:
 scale=1.22 if side=='L' else 1
 JOINTS += [('arm'+side,'chest',(s*1.45,0,7.24)),('fore'+side,'arm'+side,(s*1.92,.03,5.68)),('hand'+side,'fore'+side,(s*2.31,.19,4.12)),
  ('leg'+side,'body',(s*.71,0,4.2)),('shin'+side,'leg'+side,(s*.94,.04,2.32)),('foot'+side,'shin'+side,(s*1.01,0,.4))]
 for k in range(4):JOINTS.append(('digit'+side+str(k),'hand'+side,(s*2.31+(k-1.5)*.23*scale,.35,3.99)))
 JOINTS.append(('thumb'+side,'hand'+side,(s*(2.31-.39*scale),.34,4.17)))
 for k in range(5):
  z=7.64-k*.34
  beam('RibInner'+side+str(k),'chest',(s*.1,.92,z-.24),(s*.53,.98,z-.12),.19,.16,RIDGE)
  beam('RibCurve'+side+str(k),'chest',(s*.53,.98,z-.12),(s*.97,.73,z),.18,.15,RIDGE)
  beam('RibOuter'+side+str(k),'chest',(s*.97,.73,z),(s*1.32,.22,z+.02),.21,.18,RIDGE)
  beam('BackRib'+side+str(k),'chest',(s*.1,-.99,z-.27),(s*1.13,-.64,z+.01),.17,.17,RIDGE)
 for k in range(3):
  beam('Abdominal'+side+str(k),'body',(s*(.22+k*.21),.69,4.49),(s*(.36+k*.2),.68,5.99),.14,.13,RIDGE)
  beam('HipRoot'+side+str(k),'body',(s*.13,.7,4.07),(s*(.8+k*.12),.48,4.91+k*.1),.19,.19,RIDGE)
 mass('Shoulder'+side,'arm'+side,(s*1.51,-.02,7.18),(1.12*scale,1.29,.92),BASE,3,4)
 for k in range(3):beam('ShoulderRidge'+side+str(k),'arm'+side,(s*(1.14+k*.21),-.02,7.65),(s*(1.53+k*.16),.49,6.92),.19,.18,RIDGE)
 beam('UpperArm'+side,'arm'+side,(s*1.53,0,6.99),(s*1.92,.03,5.69),.7*scale,.8,BASE)
 mass('BicepVolume'+side,'arm'+side,(s*1.73,0,6.39),(.86*scale,.99,1.15),BASE,5,5)
 for k in[-1,0,1]:beam('BicepRoot'+side+str(k),'arm'+side,(s*1.58+k*.19,.43,6.92),(s*1.92+k*.17,.43,5.72),.17,.14,RIDGE)
 mass('Elbow'+side,'fore'+side,(s*1.92,.03,5.66),(.74*scale,.81,.57),DARK,2,4)
 beam('Forearm'+side,'fore'+side,(s*1.96,.06,5.52),(s*2.31,.19,4.15),.76*scale,.83,BASE)
 mass('ForearmVolume'+side,'fore'+side,(s*2.1,.1,4.95),(.88*scale,1.03,1.2),BASE,5,5)
 for k in[-1,0,1]:beam('BackForeRidge'+side+str(k),'fore'+side,(s*1.98+k*.21,-.4,5.48),(s*2.3+k*.16,-.29,4.23),.14,.13,RIDGE)
 for k in[-1,0,1]:beam('ForeRidge'+side+str(k),'fore'+side,(s*1.98+k*.22*scale,.51,5.53),(s*2.31+k*.2*scale,.63,4.19),.18,.17,HIGH if k==0 else RIDGE)
 mass('Palm'+side,'hand'+side,(s*2.31,.21,3.98),(.88*scale,.63,.75),BASE,4,5)
 for k in range(3):
  beam('Scapula'+side+str(k),'arm'+side,(s*(1.12+k*.15),-.5,7.52),(s*(1.7+k*.13),-.57,6.9),.13,.12,RIDGE)
 for k in range(4):
  x=s*2.31+(k-1.5)*.23*scale;j='digit'+side+str(k);length=(.92-abs(k-1.5)*.12)*scale
  beam('PalmTendon'+side+str(k),'hand'+side,(x-s*.07,-.12,4.25),(x,-.12,3.75),.095,.1,RIDGE)
  beam('Knuckle'+side+str(k),j,(x,.35,3.99),(x+s*.07,.42,3.72),.19*scale,.2,RIDGE)
  beam('Finger'+side+str(k),j,(x+s*.07,.42,3.72),(x+s*.13,.6,3.99-length),.16*scale,.18,BASE)
  beam('Claw'+side+str(k),j,(x+s*.13,.6,3.99-length),(x+s*.06,.85,3.89-length),.11*scale,.13,HIGH)
 beam('Thumb'+side,'thumb'+side,(s*(2.31-.39*scale),.34,4.17),(s*(2.31-.62*scale),.62,3.81),.21,.23,RIDGE)
 beam('ThumbTip'+side,'thumb'+side,(s*(2.31-.62*scale),.62,3.81),(s*(2.31-.51*scale),.87,3.51),.15,.17,HIGH)
 mass('Thigh'+side,'leg'+side,(s*.84,0,3.44),(1.12,1.18,1.8),BASE,5,5)
 for k in[-1,0,1]:beam('ThighRidge'+side+str(k),'leg'+side,(s*.73+k*.21,.61,4.13),(s*.94+k*.18,.53,2.51),.19,.18,RIDGE)
 mass('Knee'+side,'shin'+side,(s*.94,.13,2.31),(.87,.95,.62),BASE,2,4)
 beam('KneeRidge'+side,'shin'+side,(s*.94,.64,2.6),(s*.94,.64,2.05),.18,.14,HIGH)
 beam('Shin'+side,'shin'+side,(s*.94,.04,2.22),(s*1.01,0,.45),.66,.77,BASE)
 mass('CalfVolume'+side,'shin'+side,(s*.97,-.1,1.52),(.82,.98,1.18),BASE,3,4)
 for k in[-1,0,1]:beam('ShinRidge'+side+str(k),'shin'+side,(s*.94+k*.18,.47,2.12),(s*1.01+k*.17,.43,.5),.13,.13,RIDGE)
 mass('Heel'+side,'foot'+side,(s*1.01,-.1,.28),(1.03,1.07,.54),BASE,2,4)
 for k in[-1,0,1]:
  x=s*1.01+k*.28
  beam('Toe'+side+str(k),'foot'+side,(x,.21,.29),(x+k*.12,1.12-abs(k)*.14,.13),.23,.22,RIDGE)
  add('Nail'+side+str(k),'foot'+side,(x+k*.12,1.12-abs(k)*.14,.14),(.22,.24,.2),HIGH)
for k in range(6):mass('NeckBand'+str(k),'neck',(0,-.02,7.82+k*.1),(.7,.78,.12),BASE,1,3)
mass('Head','head',(0,0,8.64),(1.17,1.1,1.44),BASE,6,6)
add('EyeRecess','head',(0,.59,8.78),(1.03,.12,.26),DARK)
for side,s in [('L',1),('R',-1)]:
 add('Eye'+side,'head',(s*.3,.665,8.77),(.16,.03,.075),(159,150,129))
 beam('Brow'+side,'head',(s*.04,.71,8.99),(s*.5,.6,8.93),.17,.13,HIGH)
 beam('Cheek'+side,'head',(s*.46,.6,8.73),(s*.23,.7,8.27),.18,.15,RIDGE)
 for k in range(3):
  beam('Temple'+side+str(k),'head',(s*(.5-k*.09),.34,9.15-k*.08),(s*(.55-k*.06),.50,8.9-k*.08),.075,.075,RIDGE)
  beam('FaceTendon'+side+str(k),'head',(s*(.21+k*.1),.66,8.58),(s*(.12+k*.07),.67,8.31),.065,.06,HIGH)
 beam('Jaw'+side,'jaw',(s*.41,.49,8.29),(s*.2,.63,7.98),.18,.17,RIDGE)
 for k in range(3):beam('Cranium'+side+str(k),'head',(s*(.14+k*.15),.39,9.16),(s*(.1+k*.12),-.45,9.25-k*.08),.12,.13,RIDGE)
beam('NoseBridge','head',(0,.64,8.99),(0,.78,8.48),.17,.14,RIDGE)
add('Mouth','jaw',(0,.69,8.2),(.52,.07,.075),DARK)
beam('Chin','jaw',(-.21,.62,8.1),(.21,.62,8.1),.15,.15,HIGH)
for k in range(10):mass('Spine'+str(k),'chest'if k<5 else'body',(0,-.93 if k<5 else-.71,7.65-k*.35),(.34,.26,.24),RIDGE,1,3)
TENDRILS={}
for side,s in [('L',1),('R',-1)]:
 for tier in range(3):
  points=[(s*(.88-tier*.18),-.69,7.56-tier*1.28),(s*(2.39-tier*.18),-1.02,8.67-tier*1.52),
   (s*(3.57-tier*.18),-1.13,7.13-tier*1.63),(s*(4.02-tier*.2),-1.25,4.92-tier*1.55)]
  controls=[Vector(p)for p in points];points=[]
  for step in range(7):
   u=step/2;seg=min(2,int(u));t=u-seg
   p0,p1,p2,p3=[controls[max(0,min(3,i))]for i in[seg-1,seg,seg+1,seg+2]]
   points.append(tuple(.5*((2*p1)+(-p0+p2)*t+(2*p0-5*p1+4*p2-p3)*t*t+(-p0+3*p1-3*p2+p3)*t*t*t)))
  names=[]
  for k,(a,b) in enumerate(zip(points,points[1:])):
   n='tendril'+side+str(tier)+str(k);parent=('chest'if tier<2 else'body')if k==0 else names[-1]
   JOINTS.append((n,parent,a));names.append(n)
   # Stepped rings follow each bone; small gaps overlap so the silhouette remains connected.
   for v in range(3):
    u=v/3;end=(v+1)/3+.018;width=.48-.05*k
    aa,bb=Vector(a).lerp(Vector(b),u),Vector(a).lerp(Vector(b),min(1.02,end))
    beam('Tendril'+side+str(tier)+str(k)+str(v),n,aa,bb,width,width,TENDRIL if v%2 else BASE)
  TENDRILS[side+str(tier)]=(names,points)
PARTS=g.parts;EXTRA_JSON={'walkSpeed':2.8,'runSpeed':4.5}
CLIP_FILES={'loco':['idle','walk','run'],'claw':['attack1','hurt','stun','jump'],'tendrils':['attack2'],
 'flower':['flower'],'clockspell':['clockcast'],'portalspell':['portalcast'],'spawn':['spawn'],'death':['death']}
def actions():return make_actions(JOINTS,TENDRILS)
PREVIEWS=[('idle',30),('attack2',64),('flower',69),('death',141)]
PREVIEW_CAMERA=((16,25,12),(0,0,4.9),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,4.7),16),'side':((0,-1,0),(0,0,1),(0,0,4.7),16),'back':((1,0,0),(0,0,1),(0,0,4.7),16)}
if __name__=='__main__':run(globals())
