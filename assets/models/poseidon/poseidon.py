"""Original Sunken Lighthouse sea king. All geometry and motion authored here, headless Blender."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from poseidon_motion import make_actions
NAME='poseidon';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2.4;GAME_LIFT={'saturate':1,'gain':1};BACKGROUND=(180,187,185)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death','idle_sitting','kneel','awaken'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'trident':(28,76)}}
SKIN=(110,145,153);LIGHT=(136,164,168);DARK=(74,110,120);BRONZE=(140,125,76);PATINA=(55,107,100)
HAIR=(185,188,175);HAIRLIGHT=(208,207,192);CLOTH=(37,76,83);SHELL=(170,156,118)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.55)),('chest','body',(0,0,6.45)),
 ('neck','chest',(0,-.1,8.14)),('head','neck',(0,.03,8.95)),('jaw','head',(0,.68,8.72)),
 ('beard1','jaw',(0,.92,8.7)),('beard2','beard1',(0,1.16,7.92)),('beard3','beard2',(0,1.29,7.23)),
 ('hair1','head',(0,-.63,9.4)),('hair2','hair1',(0,-1.0,8.62)),('hair3','hair2',(0,-1.25,7.7)),
 ('clothFront','body',(0,.95,4.82)),('clothBack','body',(0,-.85,4.82)),('clothL','body',(1.1,0,4.82)),('clothR','body',(-1.1,0,4.82)),
 ('weedL','chest',(1.8,-.2,7.7)),('weedR','chest',(-1.8,-.2,7.7))]
for side,s in [('L',1),('R',-1)]:
 hand=(s*2.88,.18,4.61) if side=='L' else (s*3.0,.75,5.14)
 JOINTS += [('arm'+side,'chest',(s*1.94,0,7.75)),('fore'+side,'arm'+side,(s*2.57,.12,6.1)),
  ('hand'+side,'fore'+side,hand),('thumb'+side,'hand'+side,(hand[0]-s*.35,hand[1]+.2,hand[2]-.15)),
  ('fingers'+side,'hand'+side,(hand[0],hand[1]+.37,hand[2]-.2)),
  ('leg'+side,'body',(s*.87,0,4.55)),('shin'+side,'leg'+side,(s*1.08,.12,2.5)),('foot'+side,'shin'+side,(s*1.15,.0,.46))]
JOINTS += [('trident','handR',(-3,.95,5.1))]
PARTS=[]
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def mass(n,j,c,size,col,layers=3,slices=3):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  u=(i+.5)/layers*2-1;r=math.sqrt(1-u*u)
  for k in range(slices):
   v=(k+.5)/slices*2-1;rr=math.sqrt(1-v*v)
   add(f'{n}{i}_{k}',j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*rr,d*r/slices,h/layers),col)
def beam(n,j,a,b,w,d,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(x) for x in v.to_track_quat('Z','Y').to_euler()))
def shell(n,j,c,size):
 x,y,z=c;w,h=size
 for i in range(7):
  q=(i-3)/3;top=z+h*(.5-.24*abs(q));bottom=z-h*.43
  beam(n+str(i),j,(x+q*w*.12,y,bottom),(x+q*w*.48,y-.12*abs(q),top),w*.13,.19,SHELL if i%2 else HAIR)
mass('Abdomen','body',(0,0,5.55),(2.7,1.8,2.35),SKIN,4,4)
mass('Ribcage','chest',(0,-.04,7.02),(3.5,2.12,2.0),SKIN,4,4)
for side,s in [('L',1),('R',-1)]:
 mass('Pectoral'+side,'chest',(s*.84,.85,7.35),(1.45,.55,.84),LIGHT,3,3)
 mass('ShoulderBlade'+side,'chest',(s*.82,-.87,7.3),(1.27,.53,1.0),DARK,3,3)
 for i in range(3):mass('Abdominal'+side+str(i),'body',(s*.47,.85,6.15-i*.39),(.77,.35,.34),LIGHT,1,3)
 beam('Harness'+side,'chest',(s*1.57,.78,7.93),(-s*.34,1.0,6.38),.23,.15,BRONZE)
 mass('Deltoid'+side,'arm'+side,(s*2.04,0,7.58),(1.35,1.42,1.28),SKIN,3,3)
 mass('Biceps'+side,'arm'+side,(s*2.34,.12,6.8),(1.0,1.16,1.45),SKIN,3,4)
 mass('Elbow'+side,'fore'+side,(s*2.57,.12,6.08),(.83,.9,.73),DARK,3,3)
 hand=Vector(dict((n,p) for n,_,p in JOINTS)['hand'+side]);elbow=Vector((s*2.57,.12,6.1))
 beam('Forearm'+side,'fore'+side,elbow,hand,.79,.82,SKIN)
 for k,t in enumerate([.24,.7]):
  center=elbow.lerp(hand,t)
  mass('BracerRing'+side+str(k),'fore'+side,tuple(center),(1.02,1.02,.18),BRONZE,1,4)
 center=elbow.lerp(hand,.47)
 add('PatinaCuff'+side,'fore'+side,(center.x,center.y+.44,center.z),(.77,.14,.66),PATINA)
 shell('CuffShell'+side,'fore'+side,(center.x,center.y+.55,center.z),(.48,.49))
 mass('Palm'+side,'hand'+side,tuple(hand+Vector((0,.09,-.13))),(.84,.7,.64),SKIN,2,3)
 for k in range(4):
  x=hand.x+(k-1.5)*.19
  add('Knuckle'+side+str(k),'fingers'+side,(x,hand.y+.43,hand.z-.22),(.17,.24,.23),LIGHT)
  add('Finger'+side+str(k),'fingers'+side,(x,hand.y+.45,hand.z-.5),(.17,.25,.39),SKIN,(-12 if side=='L' else -65,0,0))
 beam('Thumb'+side,'thumb'+side,(hand.x-s*.35,hand.y+.2,hand.z-.15),(hand.x-s*.43,hand.y+.39,hand.z-.54),.25,.24,SKIN)
 mass('Thigh'+side,'leg'+side,(s*.98,.0,3.73),(1.24,1.35,1.92),SKIN,4,3)
 mass('Knee'+side,'shin'+side,(s*1.08,.2,2.55),(1.12,1.22,.8),DARK,3,3)
 shell('KneeShell'+side,'shin'+side,(s*1.08,.81,2.68),(.95,.83))
 beam('Shin'+side,'shin'+side,(s*1.08,.12,2.22),(s*1.15,0,.57),.84,.9,SKIN)
 for k in range(4):
  z=1.98-k*.32;w=.88-k*.12
  add('Greave'+side+str(k),'shin'+side,(s*1.12,.58,z),(w,.19,.34),PATINA)
  for sign in [-1,1]:add('GreaveEdge'+side+str(k)+str(sign),'shin'+side,(s*1.12+sign*w/2,.7,z),(.08,.11,.33),BRONZE)
 mass('Foot'+side,'foot'+side,(s*1.15,.35,.29),(1.24,1.79,.57),SKIN,2,4)
 add('SandalSole'+side,'foot'+side,(s*1.15,.32,.1),(1.28,1.84,.18),PATINA)
 for k in range(3):add('SandalStrap'+side+str(k),'foot'+side,(s*1.15,.12+k*.35,.5-k*.045),(1.23,.15,.12),BRONZE)
 for k in range(4):add('Toe'+side+str(k),'foot'+side,(s*1.15+(k-1.5)*.24,1.16,.29),(.21,.27,.23),LIGHT)
 # Distinct shell armor on the left, a narrow bronze clasp on the weapon shoulder.
 if side=='L':
  mass('ShellShoulderBacking','armL',(2.1,0,7.91),(1.7,1.7,.66),BRONZE,2,3)
  shell('GreatShell','armL',(2.09,.87,8.04),(1.44,1.24))
 else:beam('ShoulderClasp','armR',(-2.35,.71,7.52),(-1.64,.65,8.14),.3,.2,BRONZE)
 for k in range(5):
  height=1.25+(.2 if k%2 else 0)
  add('Weed'+side+str(k),'weed'+side,(s*(1.84+k*.12),-.34-k*.08,7.48-height/2),(.15,.13,height),PATINA if k%2 else CLOTH,(-14,0,s*10))
mass('Belt','body',(0,0,4.87),(3.05,1.93,.35),BRONZE,1,4)
add('BeltFace','body',(0,1.04,4.85),(1.0,.17,.6),PATINA);shell('BeltShell','body',(0,1.18,4.86),(.74,.66))
for name,y,x,width,height in [('clothFront',1.02,0,1.85,2.3),('clothBack',-.98,0,2.15,2.1),('clothL',0,1.15,.8,1.7),('clothR',0,-1.15,.8,1.7)]:
 for k in range(7):
  h=height-.2*abs(k-3);xx=x+(k-3)*width/7
  add(name+str(k),name,(xx,y+(.05 if k%2 else -.05),4.75-h/2),(width/7+.004,.14,h),CLOTH if k%2 else PATINA)
  if k in [0,6]:add(name+'Edge'+str(k),name,(xx,y+.1,4.75-h/2),(.065,.05,h),BRONZE)
mass('Neck','neck',(0,-.04,8.31),(1.13,1.17,.7),DARK,3,3)
mass('Skull','head',(0,.02,9.12),(1.87,1.64,1.65),SKIN,4,4)
add('Nose','head',(0,.96,9.08),(.32,.39,.49),LIGHT)
for s in [-1,1]:
 add('EyeSocket'+str(s),'head',(s*.46,.8,9.28),(.48,.11,.21),DARK)
 add('Eye'+str(s),'head',(s*.45,.87,9.29),(.22,.04,.085),(208,211,191))
 beam('Eyebrow'+str(s),'head',(s*.14,.92,9.49),(s*.84,.75,9.47),.22,.19,HAIRLIGHT)
 add('Cheek'+str(s),'head',(s*.61,.78,8.93),(.41,.24,.44),LIGHT)
 mass('Ear'+str(s),'head',(s*.96,.0,9.13),(.38,.39,.64),DARK,2,2)
 beam('Mustache'+str(s),'jaw',(s*.08,1.04,8.87),(s*.7,.91,8.63),.24,.28,HAIRLIGHT)
for name,z,y,width,height in [('beard1',8.36,1.03,1.35,.82),('beard2',7.66,1.19,1.08,.84),('beard3',7.03,1.32,.69,.8),('hair1',9.03,-.81,1.95,1.15),('hair2',8.12,-1.07,1.88,1.13),('hair3',7.27,-1.27,1.53,1.05)]:
 for k in range(7):
  h=height-.11*abs(k-3)
  add(name+str(k),name,((k-3)*width/7,y+(.06 if k%2 else 0),z+(height-h)/2),(width/7+.015,.24,h),HAIRLIGHT if k%3==0 else HAIR,(-6 if name.startswith('beard') else 8,0,0))
mass('CrownBand','head',(0,.02,9.74),(1.94,1.69,.23),BRONZE,1,5)
for i in [-1,0,1]:
 x=i*.72;height=.65 if i==0 else .43
 add('CrownCoral'+str(i),'head',(x,.72,9.87+height/2),(.19,.26,height),BRONZE)
 add('CrownInlay'+str(i),'head',(x,.88,9.94+height*.35),(.13,.06,height*.6),PATINA)
 if i:beam('CrownFork'+str(i),'head',(x,.72,10.04),(x+i*.2,.72,10.28),.12,.13,BRONZE)
# Trident is a fully jointed prop, not a particle or a flat sprite.
add('TridentShaft','trident',(-3,.95,4.82),(.22,.25,8.84),BRONZE)
for i,z in enumerate([.56,1.9,3.9,5.1,7.1,8.35]):
 add('TridentRing'+str(i),'trident',(-3,.95,z),(.38,.39,.18),PATINA if i%2 else BRONZE)
for i in range(7):add('GripWrap'+str(i),'trident',(-3,.95,4.62+i*.13),(.3,.33,.07),CLOTH)
add('TridentCross','trident',(-3,.95,8.61),(1.85,.31,.29),BRONZE)
for i in [-1,0,1]:
 x=-3+i*.79;h=1.67 if i==0 else 1.24
 add('TridentProng'+str(i),'trident',(x,.95,8.67+h/2),(.21,.27,h),BRONZE)
 add('TridentPoint'+str(i),'trident',(x,.95,8.67+h+.16),(.11,.15,.35),BRONZE)
 add('TridentInset'+str(i),'trident',(x,1.11,8.78),(.15,.05,.38),PATINA)
EXTRA_JSON={'walkSpeed':3.2,'runSpeed':6.0}
CLIP_IMPACTS={'swing':.48,'swing_2':.51,'stab':.68,'wave_clash':.66,'epicenter':1.02,'swim_attack':.55}
CLIP_FILES={'locomotion':['idle','walk','run','hurt','jump'], 'combat':['swing','swing_2','stab','wave_clash','epicenter'],
 'water':['swim_idle','swim','torpedo','swim_attack'],'lifecycle':['idle_sitting','awaken','kneel','death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('wave_clash',19.8),('epicenter',25),('torpedo',15),('death',120)]
PREVIEW_CAMERA=((18,29,14),(0,0,5.2),49)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.3),18),'side':((0,1,0),(0,0,1),(0,0,5.3),18),'back':((1,0,0),(0,0,1),(0,0,5.3),18)}
if __name__=='__main__':run(globals())
