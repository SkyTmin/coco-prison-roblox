"""Original Basalt Guardian v2. Headless build; no imported game geometry or animation.
Audited clips: attack_1 1.5, sword_slash 1.8, sword_smash 3.5, sword_spike 4, death 4 s.
Box sculpture in X lateral / Y forward / Z up. Old uploaded stone noise is preserved.
"""
import math
import os
import sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, default_noise, run
from mathutils import Vector, Quaternion, Matrix, Euler
NAME='basalt_guardian'
HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=3.0
GAME_LIFT={'saturate':.6,'gain':1.1}
GLOW_STRENGTH=.65
BAKE_CURVES=True
GROUND_CLIPS=['death']
GROUND_SUBSTEPS=4
EXTRA_JSON={'walkSpeed':3.1111}
CLIP_IMPACTS={'melee':.62,'sword_slash':.7,'sword_smash':1.9,'sword_spike':2.15}
BACKGROUND=(174,180,186)
STONE=(78,81,87); LIGHT=(104,108,113); DARK=(47,50,55); EDGE=(65,68,74)
BLACK=(29,31,37); LAVA=(224,105,31); HOT=(247,164,51)
PARTS=[]
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,3.7)),('chest','body',(0,-.15,6.0)),
        ('head','chest',(0,.65,7.8)),('backPlate','chest',(0,-1.7,6.4))]
for side,s in [('L',1),('R',-1)]:
    JOINTS += [('arm'+side,'chest',(s*2.3,-.1,7.1)),
               ('pauldron'+side,'arm'+side,(s*2.8,-.1,7.6)),
               ('fore'+side,'arm'+side,(s*3.1,.08,5.35)),
               ('hand'+side,'fore'+side,(s*3.25,.3,3.9)),
               ('fingers'+side,'hand'+side,(s*3.25,.66,3.65)),
               ('thumb'+side,'hand'+side,(s*2.7,.35,3.95)),
               ('leg'+side,'body',(s*1.1,0,3.7)),
               ('shin'+side,'leg'+side,(s*1.1,0,2.12)),
               ('foot'+side,'shin'+side,(s*1.1,0,.55))]
JOINTS.append(('sword','handL',(3.25,.45,3.75)))


def NOISE(): return default_noise(seed=11,depth=.22,jitter=(-.1,.07),floor=.62)

def add(name,joint,center,size,color,rot=(0,0,0),glow=False):
    x,y,z=center; a,b,c=[n/2 for n in size]
    PARTS.extend(box(name,joint,(x-a,x+a),(y-b,y+b),(z-c,z+c),color,rot=rot,glow=glow))

def mass(name,joint,c,size,color,layers=4):
    x,y,z=c; w,d,h=size
    for i in range(layers):
        u=(i+.5)/layers*2-1; r=math.sqrt(1-u*u)
        for j in range(3):
            shade=tuple(round(v*(1.07 if j==2 else .92 if j==0 else 1)) for v in color)
            add(f'{name}{i}_{j}',joint,(x,y+(j-1)*d*r/3,z-h/2+(i+.5)*h/layers),
                (w*r*(.8 if j!=1 else 1),d*r/3,h/layers),shade)

# Broad chest with overlapping armour, a closed deep back, articulated waist.
mass('Pelvis','body',(0,0,3.9),(3.25,2.2,1.25),DARK)
mass('Abdomen','body',(0,0,4.95),(3.35,2.55,1.8),EDGE)
mass('Chest','chest',(0,-.2,6.7),(5.0,3.25,2.65),STONE,6)
mass('Back','chest',(0,-1.0,7.3),(4.2,2.8,2.2),DARK,5)
for row in range(3):
    for col in range(5):
        x=(col-2)*.82; z=5.9+row*.61
        add(f'BreastPlate{row}_{col}','chest',(x,1.39+(.14 if row==1 else 0),z),(.77,.32,.54),LIGHT if (row+col)%4==0 else STONE,rot=(0,(col-2)*4,0))
for s in [-1,1]:
    add(f'HipGuard{s}','body',(s*1.5,.72,3.93),(.7,.35,1.08),STONE,rot=(0,s*10,0))
    for i in range(3): add(f'Waist{s}{i}','body',(s*.69,.98,4.45+i*.43),(1.16,.22,.34),STONE)
add('GroinPlate','body',(0,1.0,3.48),(.78,.42,1.1),STONE)
for i in range(5):
    h=1.4+(.38*(i%3)); x=(i-2)*.69
    add(f'BackColumn{i}','backPlate',(x,-1.99,6.9),(.6,.58,2.9-(i%2)*.5),STONE)
    add(f'CrownColumn{i}','chest',(x,-1.05,8.15+h/2),(.5,.61,h),EDGE)
    add(f'CrownCap{i}','chest',(x,-1.05,8.15+h),(.44,.55,.16),LIGHT)
# Small helmet face inset between the shoulders; glow is restricted to narrow seams.
mass('Head','head',(0,.87,8.25),(1.8,1.7,1.85),STONE,4)
add('FaceMask','head',(0,1.69,8.22),(1.35,.25,1.15),EDGE)
add('Brow','head',(0,1.87,8.65),(1.48,.27,.22),LIGHT)
add('NoseRidge','head',(0,1.91,8.19),(.27,.3,.73),STONE)
for s in [-1,1]:
    add(f'EyeDark{s}','head',(s*.4,1.855,8.4),(.57,.08,.23),BLACK)
    add(f'Eye{s}','head',(s*.4,1.91,8.4),(.45,.07,.11),HOT,glow=True)
    add(f'Cheek{s}','head',(s*.63,1.73,7.98),(.26,.29,.65),LIGHT)
for i in range(6):
    x=[-.94,-.7,-.7,-.4,-.4,.0][i]; z=7.65-i*.24
    add(f'ChestCrack{i}','chest',(x,1.61,z),(.12 if i%2 else .34,.06,.28 if i%2 else .1),LAVA,glow=True)
for i in range(4):
    add(f'WaistHeat{i}','body',(.74-(i%2)*.18,1.13,5.25-i*.24),(.09,.06,.28),LAVA,glow=True)

for side,s in [('L',1),('R',-1)]:
    mass('Shoulder'+side,'arm'+side,(s*2.7,-.15,7.13),(1.6,2.0,1.45),DARK,3)
    mass('Pauldron'+side,'pauldron'+side,(s*2.77,-.1,7.55),(2.4,2.48,1.65),STONE,4)
    for i in range(3):
        add(f'ShoulderColumn{side}{i}','pauldron'+side,(s*(2.25+i*.53),-.23,8.3+i*.16),(.39,.55,1.1+(i%2)*.7),EDGE)
    mass('UpperArm'+side,'arm'+side,(s*2.98,-.02,6.16),(1.37,1.4,1.7),EDGE,4)
    mass('Elbow'+side,'fore'+side,(s*3.1,.08,5.35),(1.25,1.4,.66),BLACK,3)
    mass('Forearm'+side,'fore'+side,(s*3.23,.26,4.65),(1.67,1.72,1.67),STONE,5)
    add('ForePlate'+side,'fore'+side,(s*3.23,1.08,4.68),(1.32,.24,1.35),LIGHT,rot=(0,s*7,0))
    for i in range(4):
        add(f'ArmCrack{side}{i}','fore'+side,(s*(3.1+(i%2)*.15),1.22,5.2-i*.29),(.11,.05,.33),LAVA,glow=True)
    mass('Palm'+side,'hand'+side,(s*3.25,.3,3.65),(1.45,1.24,.86),EDGE,3)
    for i in range(3):
        x=s*(2.85+i*.4)
        add(f'Finger{side}{i}','fingers'+side,(x,.8,3.23),(.36,.48,.67),STONE)
        add(f'FingerTip{side}{i}','fingers'+side,(x,.99,3.0),(.34,.48,.26),LIGHT)
    add('Thumb'+side,'thumb'+side,(s*2.61,.5,3.5),(.42,.58,.8),STONE,rot=(0,s*-18,0))
    mass('Thigh'+side,'leg'+side,(s*1.1,0,3.0),(1.6,1.6,1.55),EDGE,4)
    add('ThighPlate'+side,'leg'+side,(s*1.1,.81,3.08),(1.22,.29,1.12),STONE)
    mass('Knee'+side,'shin'+side,(s*1.1,.12,2.12),(1.4,1.4,.7),BLACK,3)
    add('Kneecap'+side,'shin'+side,(s*1.1,.79,2.11),(1.08,.38,.59),LIGHT)
    mass('Calf'+side,'shin'+side,(s*1.1,-.03,1.33),(1.35,1.41,1.28),STONE,4)
    add('ShinPlate'+side,'shin'+side,(s*1.1,.71,1.3),(.93,.27,1.04),LIGHT)
    mass('Foot'+side,'foot'+side,(s*1.1,.34,.39),(1.9,2.15,.78),EDGE,3)
    for i in range(3): add(f'Toe{side}{i}','foot'+side,(s*(.57+i*.49),1.3,.29),(.44,.53,.58),LIGHT)
# Sword: individual guard, bound grip, chipped obsidian blade, inset ember line.
add('Grip','sword',(3.25,.45,3.73),(.4,.48,1.35),BLACK)
for i in range(5): add(f'GripBand{i}','sword',(3.25,.45,3.2+i*.24),(.47,.53,.12),EDGE)
add('Pommel','sword',(3.25,.45,4.48),(.67,.72,.4),STONE)
add('Guard','sword',(3.25,.45,3.02),(1.97,.78,.32),LIGHT)
for i in range(7):
    z=2.68-i*.49; w=1.37-(.21 if i>4 else .0)-(i%2)*.06
    add(f'Blade{i}','sword',(3.25,.45,z),(w,.43,.52),BLACK)
    for s in [-1,1]: add(f'BladeEdge{i}_{s}','sword',(3.25+s*(w/2+.05),.45,z),(.18,.5,.45),EDGE)
    add(f'MoltenBlade{i}','sword',(3.25+(.14 if i%2 else -.06),.682,z),(.1,.035,.53),LAVA,glow=True)
add('SwordTip','sword',(3.25,.45,-.79),(.7,.38,.5),EDGE)


def pose(**kw): return {k:tuple(v)+(None,)*(4-len(v)) for k,v in kw.items()}
def legs(p,drop=0,y=0,liftL=0,liftR=0):
    for side,lift in [('L',liftL),('R',liftR)]:
        yy=y[0 if side=='L' else 1] if isinstance(y,tuple) else y
        dz=3.15-drop-lift; r=min(3.145,max(.2,math.hypot(dz,yy))); a=1.58; b=1.57
        hip=math.atan2(yy,dz)+math.acos(max(-1,min(1,(a*a+r*r-b*b)/(2*a*r))))
        knee=-(math.pi-math.acos(max(-1,min(1,(a*a+b*b-r*r)/(2*a*b)))))
        p['leg'+side]=(math.degrees(hip),0,0,None)
        p['shin'+side]=(math.degrees(knee),0,0,None)
        p['foot'+side]=(-math.degrees(hip+knee),0,0,None)
    return p

def rest(): return legs(pose(chest=(-3,0,0),head=(3,0,0),armL=(0,0,-4),armR=(0,0,5),foreL=(0,0,0),
    foreR=(8,0,0),sword=(45,0,0),fingersL=(22,0,0),fingersR=(18,0,0),thumbL=(0,-8,0)),.03)
def key(p):
    q=rest(); q.update(p); return q

def crouch(p,drop,y=0):
    q=key(p); q['body']=(0,0,0,(0,0,-drop)); return legs(q,drop,y)

def grip(p, raised):
    """Two-bone IK in the chest's rest space: both hands meet the actual sword grip."""
    points={n:Vector(v) for n,_,v in JOINTS}
    alpha=0 if raised is True else 1 if raised is False else float(raised)
    rotation=Quaternion((1,0,0),math.pi*(1-alpha))
    main=Vector((0,1.85+.2*alpha+.45*math.sin(math.pi*alpha),8.6-2.65*alpha))
    targets={'L':main,'R':main+rotation @ Vector((0,0,.67))}
    for side,s in [('L',1),('R',-1)]:
        shoulder,elbow,wrist=[points[n+side] for n in ['arm','fore','hand']]
        target=targets[side]; delta=target-shoulder; direction=delta.normalized()
        a,b=(elbow-shoulder).length,(wrist-elbow).length
        assert delta.length<a+b+.015, (side,alpha,'unreachable two-hand grip')
        distance=min(delta.length,a+b-.005)
        along=(a*a-b*b+distance*distance)/(2*distance)
        hint=Vector((s*.7,.9,-.25))
        bend=(hint-direction*hint.dot(direction)).normalized()
        at=shoulder+direction*along+bend*math.sqrt(max(0,a*a-along*along))
        upper=(elbow-shoulder).rotation_difference(at-shoulder)
        lower=(wrist-elbow).rotation_difference(upper.inverted() @ (target-at))
        hand=(upper @ lower).inverted() @ rotation
        for name,q in [('arm',upper),('fore',lower),('hand',hand)]:
            p[name+side]=tuple(math.degrees(x) for x in q.to_euler('XYZ'))+(None,)
    p['sword']=(0,0,0,None)
    return p


def collapsed_arm(p, side, outside, height):
    """Relax the dead arm onto the floor; the sword lies flat outside the torso."""
    points={n:Vector(v) for n,_,v in JOINTS}
    parents={n:parent for n,parent,_ in JOINTS}
    matrices={}
    def world(name):
        if name in matrices: return matrices[name]
        parent=parents[name]; value=p.get(name,(0,0,0,None))
        base=points[name]-(points[parent] if parent else Vector())
        m=Matrix.Translation(base+Vector(value[3] or (0,0,0))) @ Euler(tuple(math.radians(v) for v in value[:3]),'XYZ').to_matrix().to_4x4()
        matrices[name]=world(parent) @ m if parent else m
        return matrices[name]
    chest=world('chest'); s=1 if side=='L' else -1
    shoulder,elbow,wrist=[points[n+side] for n in ['arm','fore','hand']]
    core={'body','chest','head','backPlate','legL','legR','shinL','shinR','footL','footR'}
    lows=[]
    for _,joint,center,size,_,_,rot,*_ in PARTS:
        if joint not in core: continue
        m=world(joint) @ Matrix.Translation(Vector(center)-points[joint]) @ Euler(tuple(math.radians(v) for v in rot),'XYZ').to_matrix().to_4x4()
        lows.extend((m @ Vector((x*size[0]/2,y*size[1]/2,z*size[2]/2))).z
                    for x in [-1,1] for y in [-1,1] for z in [-1,1])
    # Set the hand below and outside its shoulder, relative to the final resting torso.
    shoulder_world=world('arm'+side).translation
    target_world=Vector((shoulder_world.x+s*outside,shoulder_world.y-.45,min(lows)+height))
    target=chest.inverted() @ target_world + points['chest']
    delta=target-shoulder; direction=delta.normalized()
    a,b=(elbow-shoulder).length,(wrist-elbow).length
    assert delta.length<a+b, (side,'unreachable collapsed arm',delta.length,a+b)
    along=(a*a-b*b+delta.length**2)/(2*delta.length)
    hint=chest.to_quaternion().inverted() @ Vector((s,0,.35))
    bend=(hint-direction*hint.dot(direction)).normalized()
    at=shoulder+direction*along+bend*math.sqrt(max(0,a*a-along*along))
    upper=(elbow-shoulder).rotation_difference(at-shoulder)
    lower=(wrist-elbow).rotation_difference(upper.inverted() @ (target-at))
    # Local thin Y becomes world Z; the blade's -Z points outwards along world X.
    flat=Matrix(((0,0,-s),(1,0,0),(0,-s,0))).to_quaternion()
    hand=(chest.to_quaternion() @ upper @ lower).inverted() @ flat
    for name,q in [('arm',upper),('fore',lower),('hand',hand)]:
        p[name+side]=tuple(math.degrees(v) for v in q.to_euler('XYZ'))+(None,)
    if side=='L': p['sword']=(0,0,0,(0,.41 if height<1 else .15,0))
    p['fingers'+side]=(-12,0,0,None)
    return p

def actions():
    acts={}; sin=math.sin; pi=math.pi
    idle=[]
    for i in range(14):
        f=97.5*i/13; t=i/13*2*pi
        idle.append((f,key(pose(chest=(-3+1.2*sin(t),0,.6*sin(t)),head=(3-sin(t),0,2*sin(t)),
            armR=(1.4*sin(t-.6),0,5),foreR=(8+1.6*sin(t-1),0,0),
            pauldronL=(.8*sin(t-.8),0,0),pauldronR=(sin(t-1.1),0,0),backPlate=(.65*sin(t-1.2),0,0)))))
    acts['idle']=(idle,True)
    walk=[]
    for f in range(0,46,3):
        t=f/45*2*pi; s=sin(t); drop=.47+.06*(1-math.cos(t*2)); feet=[]
        for phase in [f/45,(f/45+.5)]:
            q=phase%1
            if q<.6: feet.append((1.4*(1-2*q/.6),0))
            else:
                u=(q-.6)/.4; feet.append((-1.4+2.8*u*u*(3-2*u),.54*sin(pi*u)))
        p=key(pose(body=(0,0,0,(.06*s,0,-drop)),chest=(-5,0,-3*s),head=(4,0,2*s),
            armL=(-5*s,0,-5),armR=(12*s,0,6),foreR=(15-7*s,0,0),sword=(60+3*sin(t-.5),0,0),
            pauldronL=(2*sin(t-.6),0,1.2*s),pauldronR=(-3*sin(t-.7),0,-s),backPlate=(1.4*sin(t-.8),0,0)))
        walk.append((f,legs(p,drop,(feet[0][0],feet[1][0]),feet[0][1],feet[1][1])))
    acts['walk']=(walk,True)
    # One-hand diagonal chop: hips/chest coil before shoulder, elbow extends before wrist settles.
    acts['melee']=([(0,rest()),(7,key(pose(chest=(3,-4,-8),armL=(45,15,-16),foreL=(45,0,0),sword=(0,0,0)))),
      (14,key(pose(chest=(7,-9,-12),head=(3,8,0),armL=(125,24,-18),foreL=(28,0,0),sword=(-10,0,0),pauldronL=(-12,0,0)))),
      (18.6,crouch(pose(chest=(-16,15,9),head=(12,-8,0),armL=(35,28,9),foreL=(3,0,0),sword=(8,0,0),handL=(5,0,0),pauldronL=(8,0,0)),.24)),
      (22,crouch(pose(chest=(-20,18,11),armL=(28,30,14),foreL=(0,0,0),sword=(12,0,0),pauldronL=(12,0,0)),.3)),
      (31,key(pose(chest=(-8,7,4),armL=(12,12,0),foreL=(18,0,0),sword=(25,0,0)))),(45,rest())],False)
    acts['sword_slash']=([(0,rest()),(9,crouch(pose(chest=(-3,-18,-10),armL=(60,-18,-35),foreL=(62,0,0),sword=(8,-25,0)),.24)),
      (16,key(pose(chest=(3,-29,-12),head=(0,20,0),armL=(70,-32,-42),foreL=(76,0,0),sword=(-15,-30,-15),armR=(18,0,24)))),
      (21,crouch(pose(chest=(-10,30,14),head=(6,-15,0),armL=(62,55,25),foreL=(8,0,0),sword=(4,12,12),pauldronL=(12,0,8),armR=(-15,0,30)),.3)),
      (27,crouch(pose(chest=(-14,38,18),armL=(48,60,35),foreL=(3,0,0),sword=(12,15,20),handL=(6,0,8)),.3)),
      (38,key(pose(chest=(-5,14,5),armL=(30,22,8),foreL=(20,0,0),sword=(18,0,8)))),(54,rest())],False)
    up=grip(key(pose(chest=(6,0,0),head=(12,0,0),pauldronL=(-10,0,0),pauldronR=(-8,0,0))),True)
    smash=grip(crouch(pose(chest=(-12,0,0),head=(12,0,0),pauldronL=(15,0,0),pauldronR=(12,0,0)),.65),False)
    acts['sword_smash']=([(0,rest()),(14,crouch(pose(chest=(-9,0,0),armL=(45,20,-8),foreL=(50,0,0),armR=(60,-30,4),foreR=(50,0,0)),.24)),
      (35,up),(49,up),(57,smash),(62,smash),
      (72,crouch(pose(chest=(-15,0,0),head=(10,0,0),armL=(18,15,-2),foreL=(20,0,0),sword=(14,0,0),armR=(25,-15,7),foreR=(30,0,0)),.4)),
      (88,key(pose(chest=(-6,0,0),armL=(9,7,-3),foreL=(12,0,0),sword=(26,0,0)))),(105,rest())],False)
    for frame in range(50,57):
        u=(frame-49)/8; a=u*u*(3-2*u)
        p=crouch(pose(chest=(6-18*a,0,0),head=(12,0,0),
            pauldronL=(-10+25*a,0,0),pauldronR=(-8+20*a,0,0)),.65*a)
        acts['sword_smash'][0].append((frame,grip(p,a)))
    acts['sword_smash'][0].sort(key=lambda row:row[0])
    # Deliberate sword plant, left palm gathers stone, held channel, wrench the blade free.
    plant=crouch(pose(chest=(-14,0,-6),head=(10,0,0),armL=(-12,10,-2),foreL=(8,0,0),sword=(14,0,0),
        armR=(40,-12,28),foreR=(54,0,0),fingersR=(-12,0,0)),.42)
    acts['sword_spike']=([(0,rest()),(20,key(pose(chest=(3,0,-6),armL=(65,20,-10),foreL=(55,0,0),sword=(-15,0,0),armR=(20,0,28)))),
      (36,plant),(53,plant),(64.5,crouch(pose(chest=(-20,0,-5),head=(-5,0,0),armL=(-15,10,-2),foreL=(4,0,0),sword=(14,0,0),
        armR=(30,-8,35),foreR=(16,0,0),fingersR=(5,0,0),pauldronR=(8,0,0),backPlate=(5,0,0)),.52)),
      (77,plant),(93,key(pose(chest=(6,0,5),armL=(50,16,-8),foreL=(42,0,0),sword=(10,0,0),armR=(10,0,15)))),(120,rest())],False)
    # Death differs from Zombar: blade braces the fall, knees buckle, torso lists sideways, free fist lands last.
    acts['death']=([(0,rest()),(14,key(pose(chest=(6,0,-6),head=(8,0,7),armR=(18,0,25),sword=(35,0,0)))),
      (29,crouch(pose(chest=(-12,0,-8),head=(-8,0,4),armL=(-10,8,0),foreL=(7,0,0),sword=(75,0,0),armR=(30,0,25)),.85)),
      (44,key(pose(body=(-12,0,-8,(0,.2,-1.6)),chest=(-17,0,-8),head=(6,0,12),armL=(-20,0,-12),foreL=(32,0,0),sword=(85,0,0),
        legL=(60,0,0),legR=(65,0,0),shinL=(-110,0,0),shinR=(-120,0,0),footL=(50,0,0),footR=(55,0,0),armR=(40,0,25),foreR=(30,0,0)))),
      (60,key(pose(body=(-30,0,-32,(0,.6,-2)),chest=(-8,0,-10),head=(8,0,15),armL=(-25,10,-28),foreL=(42,0,0),sword=(115,0,0),
        legL=(42,0,-10),legR=(45,0,10),shinL=(-85,0,0),shinR=(-100,0,0),footL=(38,0,0),footR=(45,0,0),armR=(35,0,18),foreR=(5,0,0)))),
      (73,key(pose(body=(-65,0,-28,(0,.9,-2.2)),chest=(-8,0,0),head=(6,0,18),armL=(-18,18,-36),foreL=(15,0,0),sword=(166,0,0),
        legL=(18,0,-12),legR=(22,0,10),shinL=(-45,0,0),shinR=(-55,0,0),footL=(65,0,0),footR=(70,0,0),armR=(10,0,12),foreR=(-12,0,0),handR=(-12,0,0),backPlate=(7,0,0)))),
      (82,key(pose(body=(-82,0,-25,(0,1.1,-2.4)),chest=(-4,0,0),head=(3,0,22),armL=(-10,18,-36),foreL=(-4,0,0),sword=(190,0,0),
        legL=(10,0,-12),legR=(12,0,10),shinL=(-35,0,0),shinR=(-40,0,0),footL=(95,0,0),footR=(98,0,0),armR=(-5,0,12),foreR=(-5,0,0),handR=(-10,0,0),backPlate=(4,0,0),pauldronL=(10,0,0),pauldronR=(12,0,0))))],False)
    for frame,p in acts['death'][0]:
        if frame>=73:
            collapsed_arm(p,'L',1.7 if frame==73 else 1.9,1.15 if frame==73 else .95)
            collapsed_arm(p,'R',1.4 if frame==73 else 1.7,1.15 if frame==73 else .95)
    final=dict(acts['death'][0][-1][1]); final.update(pose(head=(1,0,24),backPlate=(2,0,0),pauldronL=(8,0,0),pauldronR=(9,0,0)))
    acts['death'][0].extend([(99,final),(120,final)])
    acts['roar']=([(0,rest()),(13,crouch(pose(chest=(-10,0,0),head=(-10,0,0),armR=(25,0,22)),.25)),
      (30,key(pose(chest=(8,0,0),head=(16,0,0),armL=(45,8,-25),foreL=(25,0,0),sword=(8,0,0),armR=(50,-15,35),foreR=(35,0,0)))),(54,rest())],False)
    stunned=[]
    for f in range(0,61,6):
        t=f/60*2*pi
        stunned.append((f,key(pose(chest=(-15,0,4*sin(t)),head=(-10,3*sin(t),-5*sin(t)),armR=(8,0,16),foreR=(4,0,0),sword=(42,0,0)))))
    acts['stunned']=(stunned,True)
    acts['jump']=([(0,rest()),(6,crouch(pose(chest=(-10,0,0)),.4)),
      (13,key(pose(legL=(25,0,0),legR=(28,0,0),shinL=(-40,0,0),shinR=(-45,0,0),armL=(15,0,-10),sword=(50,0,0),armR=(35,0,12)))),(24,rest())],False)
    # Avoid taking the long Euler route between equivalent IK solutions.
    for keys,_ in acts.values():
        previous={}
        for _,p in keys:
            for name,value in list(p.items()):
                values=list(value)
                if name in previous:
                    for axis in range(3):
                        values[axis]=previous[name][axis]+(values[axis]-previous[name][axis]+180)%360-180
                p[name]=tuple(values); previous[name]=values
    return acts

PREVIEW_PREFIX='v2-review-'
COMPARE_PREFIX='v2-compare-'
PREVIEW_CAMERA=((21,29,15),(0,1,6),43)
PREVIEWS=[('idle',0),('melee',18.6),('sword_slash',21),('sword_smash',49),('sword_spike',64.5),
          ('death',120,((21,29,15),(0,2,3.5),43))]
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.3),20.5),
         'side':((0,-1,0),(0,0,1),(0,1,5.3),20.5),
         'back':((1,0,0),(0,0,1),(0,0,5.3),20.5),
         'hero':PREVIEW_CAMERA}
if __name__=='__main__': run(globals())
