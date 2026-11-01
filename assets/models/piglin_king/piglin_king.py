"""Original boar king from our concept sheet; cuboids, complete rounded back, matte materials.
Headless only: blender -b -P this_file -- build / -- export / -- compare.
"""
import os, sys, math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box, run
from king_motion import make_actions
NAME='piglin_king'; HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2.6; GAME_LIFT={'saturate':1.03,'gain':1.0}; BACKGROUND=(190,185,175)
BAKE_CURVES=True; BATCH_SAMPLE=True
GROUND_CLIPS=['death','spawn','bodyslam']; GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'axe':(42,87)}}
CLIP_IMPACTS={'verticalatk':1.35,'horizontalatk':1.4,'footstomp':1.1,'spinslam':2.7,'bodyslam':2.5,'upchuck':2.5,'summoningchant':2.7,'charge':2.0,'healing':3.6}
CLIP_FILES={'locomotion':['idle','walk','run','hurt','jump'],
 'axe':['verticalatk','horizontalatk','footstomp'], 'heavy':['spinslam','bodyslam'],
 'special':['upchuck','summoningchant','healing'], 'charge':['charge'], 'lifecycle':['spawn','death']}
SKIN=(166,103,79); LIGHT=(189,121,94); DARK=(134,79,62); SNOUT=(105,52,49)
GOLD=(172,125,48); EDGE=(213,170,85); GOLD_DARK=(124,86,35); LEATHER=(64,47,37)
CLOTH=(111,43,48); IVORY=(218,201,154); HOOF=(40,35,31); BLACK=(30,22,19)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,3.4)),('belly','body',(0,.3,4.7)),
 ('chest','body',(0,-.1,6.25)),('head','chest',(0,.55,7.7)),('jaw','head',(0,1.45,7.3))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('ear'+side,'head',(s*1.35,.3,8.4)),
  ('arm'+side,'chest',(s*2.6,0,6.9)),('fore'+side,'arm'+side,(s*3.45,.15,5.4)),
  ('hand'+side,'fore'+side,(s*3.9,.55,4.0)),('fingers'+side,'hand'+side,(s*3.9,.88,3.65)),
  ('thumb'+side,'hand'+side,(s*3.4,.8,3.9)),('pauldron'+side,'arm'+side,(s*2.6,0,7.2)),
  ('leg'+side,'body',(s*1.35,0,3.4)),('shin'+side,'leg'+side,(s*1.5,.1,1.85)),
  ('foot'+side,'shin'+side,(s*1.5,.05,.5))]
JOINTS += [('axe','handL',(3.9,.76,3.75)),('clothFront','body',(0,1.6,3.85)),
 ('clothBack','body',(0,-1.65,3.9)),('pouch','body',(-2.45,-.45,3.8)),
 ('tail','body',(0,-1.8,3.8)),('tailTip','tail',(.38,-2.35,3.95)),('medal','body',(-1.9,1.6,3.8))]
PARTS=[]
def add(name,joint,c,size,color,rot=(0,0,0)):
 x,y,z=c; w,d,h=[v/2 for v in size]
 PARTS.extend(box(name,joint,(x-w,x+w),(y-d,y+d),(z-h,z+h),color,rot=rot))
def mass(name,joint,c,size,color,layers=5,slices=5):
 x,y,z=c; w,d,h=size
 for i in range(layers):
  u=(i+.5)/layers*2-1; r=math.sqrt(1-u*u)
  for j in range(slices):
   v=(j+.5)/slices*2-1; rr=math.sqrt(1-v*v)
   shade=1.025 if (i+j)%4==0 else .97 if (i*2+j)%5==0 else 1
   add(f'{name}{i}_{j}',joint,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),
       (w*r*rr,d*r/slices,h/layers),tuple(round(n*shade) for n in color))
mass('Pelvis','body',(0,0,3.6),(4.9,3.55,2.0),DARK,5)
mass('Belly','belly',(0,.28,4.85),(5.85,4.25,3.1),SKIN,8,7)
mass('Chest','chest',(0,-.17,6.65),(5.3,3.5,2.2),SKIN,5)
mass('Back','chest',(0,-.8,7.25),(4.1,3.1,2.0),DARK,5)
for s in [-1,1]:
 mass('Pectoral'+str(s),'chest',(s*1.1,1.18,6.48),(2.12,.92,1.1),LIGHT,3,3)
 # Leather harness follows both sides of the rounded torso, never just a front decal.
 for i,(y,z,rx) in enumerate([(1.29,7.25,-26),(.72,7.65,-34),(-.25,7.72,0),(-1.3,7.13,26),(-1.67,6.28,6)]):
  add(f'Strap{s}_{i}','chest',(s*1.78,y,z),(.55,.25,1.17),LEATHER,(rx,s*8,0))
 add('Buckle'+str(s),'chest',(s*1.78,1.52,7.08),(.7,.17,.66),GOLD)
 add('BuckleHole'+str(s),'chest',(s*1.78,1.62,7.08),(.38,.08,.32),LEATHER)
mass('Skull','head',(0,.51,8.22),(3.3,2.8,2.35),SKIN,6)
mass('Muzzle','head',(0,1.5,7.72),(2.38,1.9,1.32),DARK,4)
mass('LowerJaw','jaw',(0,1.65,7.14),(2.3,1.8,.65),SKIN,3)
add('Lip','jaw',(0,2.45,7.3),(1.8,.12,.16),SNOUT)
mass('Snout','head',(0,2.38,7.86),(1.54,.54,.91),SNOUT,3,3)
for s in [-1,1]:
 add('Nostril'+str(s),'head',(s*.38,2.69,7.87),(.23,.08,.4),BLACK)
 add('EyeSocket'+str(s),'head',(s*.92,1.88,8.42),(.62,.13,.42),BLACK)
 add('Eye'+str(s),'head',(s*.91,1.96,8.42),(.39,.07,.22),(225,158,51))
 add('Pupil'+str(s),'head',(s*.85,2.01,8.43),(.12,.04,.18),BLACK)
 add('Brow'+str(s),'head',(s*.91,1.86,8.7),(.99,.44,.34),DARK,(0,s*-13,0))
 side='L' if s==1 else 'R'
 for i,(x,y,z,w,d,h,ry) in enumerate([(1.72,.38,8.47,1.15,1,.43,16),(2.18,.45,8.25,.74,.94,.38,30),(2.42,.51,8.02,.43,.75,.3,39)]):
  add(f'Ear{s}_{i}','ear'+side,(s*x,y,z),(w,d,h),SKIN,(0,s*ry,0))
  add(f'EarInside{s}_{i}','ear'+side,(s*x,y+.42,z+.04),(w*.7,.11,h*.65),(184,105,89),(0,s*ry,0))
 for i,(x,y,z,w,d,h) in enumerate([(1.05,2.21,7.38,.53,.55,.5),(1.13,2.39,7.68,.42,.42,.48),(1.13,2.42,8.01,.27,.3,.41),(1.1,2.4,8.28,.13,.17,.26)]):
  add(f'Tusk{s}_{i}','jaw',(s*x,y,z),(w,d,h),IVORY,(0,-s*10,0))
# Battered open crown, small enough to leave the boar silhouette readable.
for i in range(10):
 a=2*math.pi*i/10;x=math.sin(a)*1.01;y=.4+math.cos(a)*.87
 add('CrownBand'+str(i),'head',(x,y,9.31),(.68,.24,.39),GOLD,(0,0,-math.degrees(a)))
 if i%2==0: add('CrownPoint'+str(i),'head',(x,y,9.72),(.25,.27,.62 if i!=4 else .43),GOLD,(0,0,-math.degrees(a)))
add('CrownGemFrame','head',(0,1.37,9.43),(.54,.17,.59),EDGE)
add('CrownGem','head',(0,1.48,9.43),(.33,.08,.37),(115,30,38))
for side,s in [('L',1),('R',-1)]:
 mass('Shoulder'+side,'arm'+side,(s*2.7,0,6.85),(2.05,2.25,1.9),SKIN,4)
 mass('UpperArm'+side,'arm'+side,(s*3.13,.1,6.07),(1.7,1.8,1.7),SKIN,4)
 mass('Elbow'+side,'fore'+side,(s*3.44,.15,5.4),(1.4,1.5,.84),DARK,3,3)
 mass('Forearm'+side,'fore'+side,(s*3.7,.35,4.78),(1.55,1.6,1.5),SKIN,4)
 mass('Palm'+side,'hand'+side,(s*3.9,.55,3.9),(1.25,1.18,.95),SKIN,3,3)
 for i in range(3):
  add(f'Finger{side}{i}','fingers'+side,(s*(3.54+i*.36),.93,3.42),(.32,.48,.64),DARK,(15,0,0))
  add(f'Nail{side}{i}','fingers'+side,(s*(3.54+i*.36),1.16,3.25),(.24,.08,.22),HOOF)
 add('Thumb'+side,'thumb'+side,(s*3.35,1.0,3.75),(.42,.62,.48),SKIN,(0,s*-20,0))
 for j,z in enumerate([4.44,5.12]):
  for k,(dx,dy,w,d) in enumerate([(0,.83,1.61,.2),(0,-.65,1.61,.2),(.73,.08,.2,1.45),(-.73,.08,.2,1.45)]):
   add(f'Cuff{side}{j}_{k}','fore'+side,(s*3.72+dx,.3+dy,z),(w,d,.25),GOLD if j==0 else LEATHER)
  add(f'CuffStud{side}{j}','fore'+side,(s*3.72,1.25,z),(.32,.17,.35),EDGE)
 mass('Thigh'+side,'leg'+side,(s*1.42,-.03,2.75),(2.13,2.15,1.7),SKIN,4)
 mass('Shin'+side,'shin'+side,(s*1.5,.04,1.32),(1.42,1.38,1.55),DARK,4)
 for toe in [-1,1]:
  mass(f'Hoof{side}{toe}','foot'+side,(s*1.5+toe*.34,.38,.34),(.66,1.6,.68),HOOF,2,3)
# One layered shoulder plate, including its curved rear, with inset rivets.
for i in range(3):
 x=2.5+i*.32;z=7.66-i*.33
 mass('Pauldron'+str(i),'pauldronL',(x,-.02,z),(2.28-i*.21,2.65-i*.05,.65),GOLD,2,5)
 for s in [-1,1]: add(f'ArmorRim{i}_{s}','pauldronL',(x,s*1.16,z-.13),(1.75,.2,.22),EDGE,(s*12,0,0))
 for j in range(3):add(f'Rivet{i}_{j}','pauldronL',(x+(j-1)*.5,1.25,z+.05),(.13,.1,.13),GOLD_DARK)
for i in range(14):
 a=2*math.pi*i/14;x=math.sin(a)*2.5;y=math.cos(a)*1.77
 add('Belt'+str(i),'body',(x,y,3.92),(1.12,.26,.63),LEATHER,(0,0,-math.degrees(a)))
 add('BeltRivet'+str(i),'body',(x*1.06,y*1.06,3.96),(.13,.13,.13),GOLD)
for c,size in [((-.5,1.98,3.94),(.14,.16,.77)),((.5,1.98,3.94),(.14,.16,.77)),((0,1.98,4.26),(1,.16,.14)),((0,1.98,3.62),(1,.16,.14))]:add('BeltBuckle'+str(len(PARTS)),'body',c,size,EDGE)
for joint,y in [('clothFront',1.71),('clothBack',-1.74)]:
 for i in range(9):
  h=1.32+(.5 if i==4 else .2 if i in [3,5] else .13*(i%3))
  add(joint+str(i),joint,((i-4)*.45,y,3.6-h/2),(.44,.19,h),CLOTH if i%2==0 else (86,37,40),(-7 if y>0 else 7,0,0))
mass('Pouch','pouch',(-2.6,-.45,3.05),(.7,1.17,1.44),LEATHER,3,3)
add('PouchFlap','pouch',(-3.0,-.45,3.45),(.16,1.24,.45),DARK)
add('PouchClasp','pouch',(-3.1,-.45,3.31),(.1,.22,.26),GOLD)
for i,(x,y,z,rx,rz) in enumerate([(0,-2.0,3.8,0,-20),(.35,-2.32,3.88,20,20),(.55,-2.4,4.13,20,50),(.38,-2.32,4.27,-10,60)]):
 add('Tail'+str(i),'tail' if i<2 else 'tailTip',(x,y,z),(.34,.52,.29),SKIN,(rx,0,rz))
mass('Medal','medal',(-1.9,1.96,3.42),(.57,.16,.62),GOLD,3,3)
add('MedalCord','medal',(-1.9,1.96,3.8),(.12,.13,.43),EDGE)
# Axe is a separate rigid weapon joint, so it can slip out of the dying hand.
add('AxeShaft','axe',(4.1,1.45,3.2),(.32,3.1,.34),LEATHER,(-26,0,0))
add('AxePommel','axe',(3.96,.05,3.9),(.45,.36,.48),GOLD)
for i,(y,z,w,d,h) in enumerate([(2.75,2.67,.5,.9,1.0),(3.0,2.64,.45,.8,1.7),(3.35,2.62,.35,.45,2.2)]):
 add('AxeBlade'+str(i),'axe',(4.15,y,z),(w,d,h),GOLD if i<2 else EDGE,(-12,0,0))
add('AxeSocket','axe',(4.15,2.64,2.78),(.7,.7,.65),GOLD_DARK)
for i in range(3):add('AxeEdge'+str(i),'axe',(4.15,3.56,1.69+i*.7),(.38,.16,.6),EDGE,(-12,0,0))
EXTRA_JSON={'walkSpeed':1.3333333333,'runSpeed':4.0}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('verticalatk',25),('horizontalatk',42),('footstomp',25),('bodyslam',77),('death',112)]
PREVIEW_CAMERA=((18,26,13),(0,.3,4.7),49)
COMPARE={'front':((-1,0,0),(0,0,1),(0,.2,4.9),16),
 'side':((0,1,0),(0,0,1),(0,.2,4.9),16),
 'back':((1,0,0),(0,0,1),(0,.2,4.9),16)}
if __name__=='__main__':run(globals())
