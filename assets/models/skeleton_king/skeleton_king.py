"""Original ancient skeleton commander, based on our generated turnaround. Headless Blender only."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from skeleton_motion import make_actions
NAME='skeleton_king';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2.4;GAME_LIFT={'saturate':1.0,'gain':1.0};BACKGROUND=(190,185,175)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
CLIP_IMPACTS={'atkrswipe':.58,'atklswipe':.58,'sklrstomp':.9,'skllstomp':.9,'sklpoisonbreath':1.45,'sklroar':2.4}
CLIP_FILES={'locomotion':['idle','walk','run','jump','hurt'],
 'attacks':['atkrswipe','atklswipe','sklrstomp','skllstomp'],
 'ritual':['sklpoisonbreath','sklroar'],'lifecycle':['death']}
BONE=(173,145,104);LIGHT=(195,170,127);EDGE=(137,111,77);DARK=(105,83,56);SOCKET=(39,33,27)
BRONZE=(81,101,93);METAL=(111,111,80);CLOTH=(52,62,76)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.1)),('chest','body',(0,-.3,6.3)),
 ('ribsL','chest',(.3,-.75,7.2)),('ribsR','chest',(-.3,-.75,7.2)),
 ('neck','chest',(0,-.3,8.1)),('head','neck',(0,.6,8.85)),('jaw','head',(0,.66,8.65)),
 ('clothFront','body',(0,.8,4.1)),('clothBack','body',(0,-.8,4.1))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('arm'+side,'chest',(s*2.15,-.1,8.05)),('fore'+side,'arm'+side,(s*2.8,.0,5.94)),
  ('hand'+side,'fore'+side,(s*3.22,.35,3.78)),('thumb'+side,'hand'+side,(s*2.87,.64,3.45)),
  ('leg'+side,'body',(s*.9,0,4.1)),('shin'+side,'leg'+side,(s*1.25,.2,2.24)),('foot'+side,'shin'+side,(s*1.4,.05,.48))]
 for i in range(3):
  JOINTS += [(f'finger{side}{i}','hand'+side,(s*(3.0+i*.32),.65,3.25)),
   (f'tip{side}{i}',f'finger{side}{i}',(s*(3.07+i*.37),.83,2.58))]
PARTS=[]
def add(name,joint,c,size,color,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size]
 PARTS.extend(box(name,joint,(x-w,x+w),(y-d,y+d),(z-h,z+h),color,rot=rot))
def mass(name,joint,c,size,color,layers=3,slices=3):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  u=(i+.5)/layers*2-1;r=math.sqrt(1-u*u)
  for k in range(slices):
   v=(k+.5)/slices*2-1;rr=math.sqrt(1-v*v);shade=1.03 if (i+k)%3==0 else .97
   add(f'{name}{i}_{k}',joint,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),
    (w*r*rr,d*r/slices,h/layers),tuple(round(n*shade) for n in color))
def beam(name,joint,a,b,width,depth,color):
 a,b=Vector(a),Vector(b);v=b-a;rot=tuple(math.degrees(x) for x in v.to_track_quat('Z','Y').to_euler())
 add(name,joint,tuple((a+b)/2),(width,depth,v.length+.035),color,rot)
# Vertebrae and their actual rear projections; lumbar gap remains open around the spine.
for i in range(11):
 z=4.35+i*.37;y=-.45-.06*math.sin(i/10*math.pi)
 j='body' if i<5 else 'chest'
 mass('Vertebra'+str(i),j,(0,y,z),(.72,.8,.32),BONE,2,3)
 add('Spinous'+str(i),j,(0,y-.55,z+.05),(.24,.5,.23),EDGE,(-15,0,0))
 if i>5:
  add('SpineBinding'+str(i),j,(0,y-.81,z+.05),(.49,.18,.23),BRONZE)
  add('BindingStud'+str(i),j,(0,y-.92,z+.05),(.17,.07,.12),METAL)
# Six open rib rings; build both the front and the back instead of extruding front colors.
for side,s in [('L',1),('R',-1)]:
 for i in range(6):
  rx=[1.25,1.6,1.82,1.88,1.72,1.44][i];ry=[.91,1.09,1.21,1.2,1.1,.94][i];z=7.83-i*.46
  points=[]
  for k in range(10):
   a=math.pi*k/9;points.append((s*(.14+math.sin(a)*rx),-.2+math.cos(a)*ry,z-.2*math.sin(a)+.12*math.cos(a)))
  for k in range(9):beam(f'Rib{side}{i}_{k}','ribs'+side,points[k],points[k+1],.25,.27,LIGHT if k<5 else BONE)
  if i in [1,4]:add(f'RibOldCrack{side}{i}','ribs'+side,(s*(rx+.14),-.2,z-.18),(.045,.24,.2),DARK)
 beam('Clavicle'+side,'chest',(s*.2,.8,8.04),(s*1.96,.07,8.08),.35,.33,LIGHT)
 mass('Shoulder'+side,'arm'+side,(s*2.13,-.1,8.04),(1.15,1.1,1.03),BONE,3,4)
 mass('Scapula'+side,'chest',(s*1.4,-1.05,7.61),(.95,.34,1.2),EDGE,3,3)
 # Pelvis is a ring, with iliac crests and holes on either side.
 beam('PelvisTop'+side,'body',(s*.22,-.1,4.43),(s*1.18,0,4.18),.43,.58,BONE)
 beam('PelvisOuter'+side,'body',(s*1.18,0,4.18),(s*.88,.2,3.56),.35,.48,BONE)
 beam('PelvisBottom'+side,'body',(s*.88,.2,3.56),(s*.17,.28,3.76),.27,.42,EDGE)
 mass('HipSocket'+side,'body',(s*.92,-.06,3.92),(.76,.87,.68),DARK,3,3)
 beam('Humerus'+side,'arm'+side,(s*2.18,-.1,7.93),(s*2.79,0,6.01),.4,.44,BONE)
 beam('HumerusRidge'+side,'arm'+side,(s*2.38,.14,7.65),(s*2.79,.25,6.2),.12,.1,LIGHT)
 mass('Elbow'+side,'fore'+side,(s*2.8,0,5.94),(.78,.78,.67),EDGE,3,3)
 for k in [-1,1]:beam(f'Forearm{side}{k}','fore'+side,(s*(2.8+k*.19),0,5.81),(s*(3.22+k*.22),.35,3.9),.25,.28,LIGHT if k==1 else BONE)
 mass('Wrist'+side,'hand'+side,(s*3.22,.35,3.77),(.92,.65,.42),BONE,2,3)
 for k in range(3):beam(f'Metacarpal{side}{k}','hand'+side,(s*(3.0+k*.28),.4,3.67),(s*(3.0+k*.32),.65,3.23),.22,.3,LIGHT)
 for i in range(3):
  x=s*(3.0+i*.32);xt=s*(3.07+i*.37)
  beam(f'FingerBase{side}{i}',f'finger{side}{i}',(x,.65,3.25),(xt,.83,2.58),.25,.31,BONE)
  mass(f'Knuckle{side}{i}',f'tip{side}{i}',(xt,.83,2.58),(.35,.4,.33),DARK,2,2)
  beam(f'FingerTip{side}{i}',f'tip{side}{i}',(xt,.84,2.58),(xt,.99,2.13-i*.1),.2,.25,LIGHT)
  beam(f'Claw{side}{i}',f'tip{side}{i}',(xt,.99,2.13-i*.1),(xt,1.22,1.97-i*.1),.13,.17,EDGE)
 beam('ThumbBase'+side,'thumb'+side,(s*2.87,.64,3.45),(s*2.58,.85,3.05),.26,.28,BONE)
 beam('ThumbTip'+side,'thumb'+side,(s*2.58,.85,3.05),(s*2.68,1.11,2.75),.18,.2,LIGHT)
 beam('Femur'+side,'leg'+side,(s*.91,0,4.05),(s*1.25,.2,2.32),.48,.48,BONE)
 mass('Knee'+side,'shin'+side,(s*1.25,.2,2.24),(.83,.9,.7),BONE,3,3)
 add('Kneecap'+side,'shin'+side,(s*1.25,.68,2.3),(.48,.22,.46),LIGHT)
 for k in [-1,1]:beam(f'Shin{side}{k}','shin'+side,(s*(1.25+k*.15),.2,2.05),(s*(1.4+k*.14),.05,.56),.24,.3,BONE)
 mass('Ankle'+side,'foot'+side,(s*1.4,.05,.48),(.76,.85,.57),EDGE,2,3)
 for i in range(3):
  x=s*1.4+(i-1)*.31;end=x+(i-1)*.16
  beam(f'ToeLong{side}{i}','foot'+side,(x,.15,.32),(end,1.05,.23),.26,.29,BONE)
  beam(f'ToeTip{side}{i}','foot'+side,(end,1.05,.23),(end,1.58-abs(i-1)*.17,.16),.23,.25,LIGHT)
 # Bronze forearm ring on one side, bone repair splints on the other.
 if side=='R':
  for k,(dx,dy,w,d) in enumerate([(0,.45,1.03,.17),(0,-.38,1.03,.17),(.45,.02,.17,.85),(-.45,.02,.17,.85)]):
   add('BronzeCuff'+str(k),'fore'+side,(s*3.08+dx,.24+dy,4.48),(w,d,.36),BRONZE,(-4,0,-s*9))
   add('CuffEdge'+str(k),'fore'+side,(s*3.08+dx,.24+dy,4.7),(w,d,.09),METAL)
 else:
  for i in [-1,1]:add('OldSplint'+str(i),'arm'+side,(s*2.4+i*.24,-.03,7.48),(.18,.67,.73),EDGE,(0,-s*14,0))
for i in range(6):add('Sternum'+str(i),'chest',(0,.98-i*.034,7.82-i*.43),(.42-.025*i,.35,.38),LIGHT)
for i in range(3):mass('Neck'+str(i),'neck',(0,-.2+i*.24,8.23+i*.23),(.61,.7,.29),BONE,2,3)
# Cranium is solid at back, sockets are recessed cavities framed by separate brow/cheek bones.
mass('Cranium','head',(0,.59,9.42),(2.0,1.63,1.73),BONE,5,5)
add('FaceBack','head',(0,1.38,9.1),(1.74,.18,1.11),DARK)
for side,s in [('L',1),('R',-1)]:
 add('EyeCavity'+side,'head',(s*.48,1.495,9.22),(.66,.06,.65),SOCKET)
 beam('Brow'+side,'head',(s*.08,1.63,9.54),(s*.9,1.49,9.6),.29,.36,LIGHT)
 beam('Cheek'+side,'head',(s*.38,1.62,8.86),(s*.91,1.49,9.05),.25,.28,LIGHT)
 beam('Temple'+side,'head',(s*.93,1.4,9.5),(s*.94,1.39,8.98),.23,.32,BONE)
 beam('JawHinge'+side,'jaw',(s*.83,.84,8.64),(s*.73,1.51,8.33),.25,.27,BONE)
 for i in range(3):add(f'UpperTooth{side}{i}','head',(s*(.16+i*.2),1.56,8.62+(.05 if i==2 else 0)),(.14,.26,.32),LIGHT)
 for i in range(3):add(f'LowerTooth{side}{i}','jaw',(s*(.15+i*.2),1.62,8.43),(.14,.23,.19),LIGHT)
add('NoseBridge','head',(0,1.59,9.19),(.18,.28,.58),LIGHT)
add('NoseHole','head',(0,1.65,8.87),(.28,.06,.3),SOCKET)
add('JawChin','jaw',(0,1.52,8.25),(1.45,.47,.28),BONE)
for i in range(7):
 x=(i-3)*.28;h=[.35,.52,.24,.65,.42,.56,.3][i]
 add('BonyCrest'+str(i),'head',(x,.43,10.14+h/2),(.22,.48,h),BONE)
 add('CrestShade'+str(i),'head',(x,.69,10.14+h*.35),(.15,.055,h*.56),EDGE)
for side,s in [('L',1),('R',-1)]:
 for back in [False,True]:
  j='clothBack' if back else 'clothFront';y=-.82 if back else .85
  for i in range(4):
   h=1.63+.13*(i%3);x=s*(.35+i*.13)
   add(f'{j}{side}{i}',j,(x,y,4.07-h/2),(.13,.12,h),CLOTH if i%2 else (64,70,77),(-5 if back else 5,0,0))
   for k in range(3):add(f'ClothPatch{back}{side}{i}_{k}',j,(x,y+(-.07 if back else .07),3.8-k*.46),(.09,.025,.13),EDGE)
EXTRA_JSON={'walkSpeed':1.4,'runSpeed':5.0}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',15),('atkrswipe',12),('sklrstomp',22),('sklpoisonbreath',48),('sklroar',65),('death',125)]
PREVIEW_CAMERA=((16,27,13),(0,.3,5.2),49)
COMPARE={'front':((-1,0,0),(0,0,1),(0,.1,5.4),17),'side':((0,1,0),(0,0,1),(0,.1,5.4),17),'back':((1,0,0),(0,0,1),(0,.1,5.4),17)}
if __name__=='__main__':run(globals())
