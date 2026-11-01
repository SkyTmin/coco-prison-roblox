"""Original captive Minotaur. Headless Blender build from minotaur-reference.png.
X lateral, Y forward, Z up; no third-party model or animation data imported.
"""
import math
import os
import sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box, run
from motion import make_actions, release_origins

NAME='minotaur'
HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2.6
GAME_LIFT={'saturate':1.1,'gain':1.04}
BACKGROUND=(190,185,175)
BAKE_CURVES=True
BATCH_SAMPLE=True
GROUND_CLIPS=['death','sleep','awakening','stun']
GROUND_SUBSTEPS=4
CLIP_IMPACTS={'melee':.55,'impact':.6,'double_attack':.55,'throws_the_ground':2.25,'minotaur_rush':1.35}
CLIP_FILES={'locomotion':['idle','walk','run','jump','roar','hurt_1','hurt_2'],
            'combat':['melee','impact','double_attack','throws_the_ground'],
            'rush':['minotaur_rush','stun'],
            'awakening':['sleep','awakening'],'death':['death']}
FUR=(133,76,41); LIGHT=(159,94,51); DARK=(99,55,32); MANE=(43,33,29)
HORN=(213,190,148); TIP=(235,216,178); HOOF=(38,32,30)
IRON=(80,91,94); EDGE=(115,120,115); RUST=(115,73,44); LEATHER=(62,43,33)
CLOTH=(117,48,38); BLACK=(24,21,18); GOLD=(167,125,57)
PARTS=[]
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.2)),('chest','body',(0,-.12,6.1)),
        ('head','chest',(0,.65,7.7)),('jaw','head',(0,1.45,7.15)),('beard','jaw',(0,1.65,6.8))]
for side,s in [('L',1),('R',-1)]:
    JOINTS += [('ear'+side,'head',(s*1.0,.3,8.1)),
               ('arm'+side,'chest',(s*2.25,-.1,7.0)),('fore'+side,'arm'+side,(s*3.1,.08,5.2)),
               ('hand'+side,'fore'+side,(s*3.55,.44,3.65)),
               ('fingers'+side,'hand'+side,(s*3.55,.68,3.3)),('thumb'+side,'hand'+side,(s*3.0,.48,3.6)),
               ('chain'+side,'fore'+side,(s*4.0,.05,4.1)),('chainTip'+side,'chain'+side,(s*4.0,.05,3.48)),
               ('leg'+side,'body',(s*1.25,0,4.2)),('shin'+side,'leg'+side,(s*1.4,.2,2.35)),
               ('foot'+side,'shin'+side,(s*1.35,.0,.55))]
JOINTS += [('clothFront','body',(0,1.15,4.15)),('clothBack','body',(0,-1.0,4.1))]
for i,pt in enumerate([(0,-1.0,4.3),(0,-2.1,3.9),(0,-3.0,3.3),(0,-3.8,3.1)]):
    JOINTS.append(('tail'+str(i+1),'body' if i==0 else 'tail'+str(i),pt))

def add(name,joint,c,size,color,rot=(0,0,0)):
    x,y,z=c; a,b,d=[v/2 for v in size]
    PARTS.extend(box(name,joint,(x-a,x+a),(y-b,y+b),(z-d,z+d),color,rot=rot))

def mass(name,joint,c,size,color,layers=4):
    x,y,z=c; w,d,h=size
    for i in range(layers):
        u=(i+.5)/layers*2-1; r=math.sqrt(1-u*u)
        for j in range(3):
            shade=tuple(round(v*(1.05 if j==2 else .91 if j==0 else 1)) for v in color)
            add(f'{name}{i}_{j}',joint,(x,y+(j-1)*d*r/3,z-h/2+(i+.5)*h/layers),
                (w*r*(.85 if j!=1 else 1),d*r/3,h/layers),shade)

# Rounded masses overlap at joints, with a complete back and deep chest.
mass('Pelvis','body',(0,0,4.15),(3.2,2.1,1.55),DARK)
mass('Abdomen','body',(0,.03,5.0),(3.5,2.55,2.0),FUR)
mass('Chest','chest',(0,-.18,6.65),(4.9,3.05,2.65),FUR,5)
mass('Hump','chest',(0,-.9,7.5),(3.5,2.65,1.8),MANE,4)
for s in [-1,1]:
    mass('Pectoral'+str(s),'chest',(s*1.05,1.12,6.55),(2.05,.85,1.3),LIGHT,3)
    for i in range(3): add(f'Ab{i}_{s}','body',(s*.62,1.18,4.65+i*.39),(1.06,.18,.3),FUR)
    # The mane tapers down the shoulder blades rather than forming a flat rear slab.
    for col in range(3):
        for i in range(3):
            add(f'Mane{s}_{col}_{i}','chest',(s*(.35+col*.57),-1.52-col*.08,7.8-i*.58-col*.13),
                (.47,.55,.93),MANE if (i+col)%2 else (53,39,31),rot=(-13,s*7,s*10))
    for i in range(4):
        add(f'FrontMane{s}_{i}','chest',(s*(.7+i*.42),1.0-i*.1,7.38-i*.2),(.44,.65,1.3-i*.1),MANE,rot=(-12,s*12,s*9))

# Bull face: stepped cheeks, forward square muzzle, inset eyes and separate jaw.
mass('Skull','head',(0,.7,8.12),(2.35,2.1,1.95),FUR,4)
mass('Bridge','head',(0,1.56,7.78),(1.38,1.5,1.32),LIGHT,3)
mass('Muzzle','head',(0,2.2,7.25),(1.65,1.15,.82),FUR,3)
add('Nose','head',(0,2.8,7.25),(1.27,.24,.45),HOOF)
mass('Jaw','jaw',(0,2.02,6.93),(1.4,1.3,.48),DARK,2)
add('Mouth','jaw',(0,2.62,7.0),(1.13,.12,.10),BLACK)
for s in [-1,1]:
    add('Nostril'+str(s),'head',(s*.37,2.94,7.31),(.22,.07,.15),BLACK)
    add('EyeInset'+str(s),'head',(s*.83,1.64,8.12),(.44,.13,.32),BLACK)
    add('Eye'+str(s),'head',(s*.83,1.72,8.12),(.27,.055,.17),(219,159,48))
    add('Pupil'+str(s),'head',(s*.83,1.76,8.12),(.08,.045,.16),BLACK)
    add('Brow'+str(s),'head',(s*.78,1.69,8.41),(.79,.37,.29),DARK,rot=(0,s*11,0))
    mass('Cheek'+str(s),'head',(s*.9,1.05,7.6),(.68,1.13,.86),DARK,3)
    add('Ear'+str(s),'ear'+('L' if s==1 else 'R'),(s*1.4,.36,8.0),(.87,.65,.29),FUR,rot=(0,s*18,s*-10))
    add('EarInner'+str(s),'ear'+('L' if s==1 else 'R'),(s*1.42,.65,8.01),(.61,.09,.15),(113,65,46))
    # Thick ivory horn base, tapering stepped sweep; no copied commercial geometry.
    for i,(x,y,z,w,d,h,tilt) in enumerate([(1.1,.15,8.72,.85,.91,.78,0),(1.75,.17,8.7,.83,.77,.65,-7),
            (2.38,.2,8.73,.67,.65,.53,-12),(2.86,.24,8.94,.5,.53,.55,-28),
            (3.16,.24,9.28,.35,.4,.55,-32),(3.34,.23,9.69,.22,.28,.45,-23)]):
        add(f'Horn{s}{i}','head',(s*x,y,z),(w,d,h),HORN if i<4 else TIP,rot=(0,s*tilt,0))
for i in range(4):
    add(f'CrownTuft{i}','head',((i-1.5)*.45,.2,9.01+(.24 if i in [1,2] else 0)),(.47,1.24,.73),MANE,rot=(-13,0,0))
for i in range(3): add(f'Beard{i}','beard',((i-1)*.3,1.84,6.58-(.16 if i==1 else 0)),(.32,.48,.72),MANE,rot=(-10,0,0))
# A square brass nose ring and small restrained highlights.
for c,s in [((-.36,2.98,6.99),(.12,.12,.38)),((.36,2.98,6.99),(.12,.12,.38)),((0,2.98,6.81),(.72,.12,.12))]: add('Ring'+str(len(PARTS)),'jaw',c,s,GOLD)

for side,s in [('L',1),('R',-1)]:
    mass('Shoulder'+side,'arm'+side,(s*2.45,-.08,7.03),(2.0,2.18,1.8),FUR,4)
    mass('Bicep'+side,'arm'+side,(s*2.85,.04,6.1),(1.65,1.7,1.85),FUR,4)
    mass('Elbow'+side,'fore'+side,(s*3.1,.08,5.2),(1.38,1.43,.7),DARK,3)
    mass('Forearm'+side,'fore'+side,(s*3.35,.23,4.63),(1.65,1.67,1.65),FUR,4)
    mass('Palm'+side,'hand'+side,(s*3.55,.43,3.46),(1.38,1.14,.92),FUR,3)
    for i in range(3):
        add(f'Finger{side}{i}','fingers'+side,(s*(3.13+i*.41),.74,3.0),(.36,.48,.76),DARK,rot=(10,0,0))
        add(f'Nail{side}{i}','fingers'+side,(s*(3.13+i*.41),.97,2.68),(.32,.39,.28),HOOF)
    add('Thumb'+side,'thumb'+side,(s*2.93,.68,3.23),(.43,.6,.67),DARK,rot=(0,s*-22,0))
    # Shackles consist of four plates, with suspended two-section broken links.
    for j,(dx,dy,w,d) in enumerate([(0,.8,1.75,.22),(0,-.63,1.75,.22),(.8,.08,.22,1.4),(-.8,.08,.22,1.4)]):
        add(f'Cuff{side}{j}','fore'+side,(s*3.45+dx,.2+dy,4.03),(w,d,.61),IRON)
    for i in range(3): add(f'Rivet{side}{i}','fore'+side,(s*(2.92+i*.5),1.13,4.06),(.15,.07,.17),EDGE)
    for link in range(3):
        joint='chain'+side if link==0 else 'chainTip'+side
        x=s*4.0; z=3.94-link*.49
        for j,(dx,dz,w,h) in enumerate([(-.17,0,.1,.43),(.17,0,.1,.43),(0,.23,.34,.1),(0,-.23,.34,.1)]):
            if link==2 and j==3: continue
            add(f'Link{side}{link}_{j}',joint,(x+dx,.05,z+dz),(w,.13,h),IRON if link!=1 else EDGE)
    mass('Thigh'+side,'leg'+side,(s*1.34,.03,3.34),(1.83,1.8,2.0),FUR,4)
    mass('Knee'+side,'shin'+side,(s*1.4,.22,2.35),(1.27,1.38,.72),DARK,3)
    mass('Shin'+side,'shin'+side,(s*1.37,-.04,1.48),(1.04,1.05,1.62),FUR,3)
    mass('Fetlock'+side,'foot'+side,(s*1.35,.0,.74),(1.28,1.1,.65),LIGHT,2)
    for toe in [-1,1]:
        add(f'Hoof{side}{toe}','foot'+side,(s*1.35+toe*.38,.36,.3),(.7,1.65,.6),HOOF)
        add(f'HoofToe{side}{toe}','foot'+side,(s*1.35+toe*.38,1.1,.24),(.62,.31,.48),(49,40,34))

for i in range(9):
    a=2*math.pi*i/9; x=math.sin(a)*1.6; y=math.cos(a)*1.1
    add('Belt'+str(i),'body',(x,y,4.29),(.9,.28,.46),LEATHER,rot=(0,0,-math.degrees(a)))
add('Buckle','body',(0,1.32,4.29),(.68,.13,.52),EDGE)
add('BuckleInset','body',(0,1.4,4.29),(.43,.04,.29),LEATHER)
for joint,y in [('clothFront',1.17),('clothBack',-1.1)]:
    for i in range(5):
        h=1.25+(.55 if i==2 else .2*(i%2))
        add(joint+str(i),joint,((i-2)*.35,y,3.94-h/2),(.33,.15,h),CLOTH if i%2 else (91,38,31),rot=(-5 if y>0 else 5,0,0))
for i,(c,size,rx) in enumerate([((0,-1.6,4.12),(.32,1.25,.35),18),((0,-2.57,3.61),(.28,1.07,.29),30),
                              ((0,-3.4,3.2),(.26,.97,.28),13),((0,-4.08,3.0),(.55,.88,.61),18)]):
    add('Tail'+str(i),'tail'+str(i+1),c,size,FUR if i<3 else MANE,rot=(rx,0,0))

EXTRA_JSON={'walkSpeed':2.7692,'runSpeed':9.0,'releaseOrigins':release_origins(JOINTS)}
def actions(): return make_actions(JOINTS)
PREVIEWS=[('idle',15),('melee',16.5),('throws_the_ground',58),('minotaur_rush',48),('awakening',175),('death',235)]
PREVIEW_CAMERA=((18,26,13),(0,0,4.8),48)
COMPARE={'front':((1,0,0),(0,0,1),(0,0,5),13),
         'side':((0,1,0),(0,0,1),(0,0,5),13),
         'back':((-1,0,0),(0,0,1),(0,0,5),13)}
if __name__=='__main__': run(globals())
