"""Zombar v2: original stepped-cuboid sculpt and articulated animation, headless Blender.
Reference: zombar-reference-v2.png. X lateral / Y forward / Z up, dimensions in studs.
Existing uploaded noise tile is preserved. No imported commercial geometry or animation.
"""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, default_noise, run

NAME = 'giant_zombie'
HERE = os.path.dirname(os.path.abspath(__file__))
TILE_STUDS = 3.0
GAME_LIFT = {'saturate': .85, 'gain': .85}
BAKE_CURVES = True
GROUND_CLIPS = ['death']
CLIP_IMPACTS = {'melee': .56, 'blade_sweep': .1, 'spikes_slam': .12}
EXTRA_JSON = {'walkSpeed': 3.6667}
BACKGROUND = (190, 186, 175)
SKIN=(111,122,65); LIGHT=(137,146,81); DARK=(78,91,48)
CLOTH=(49,77,76); SEAM=(73,99,94); PANTS=(47,49,65); PATCH=(65,66,79)
BONE=(204,193,142); BLACK=(35,37,29); BOIL=(154,139,65); STEEL=(76,78,74)
PARTS=[]
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.0)),
        ('chest','body',(0,-.25,6.2)),('head','chest',(0,.65,8.25)),
        ('jaw','head',(0,1.05,8.1))]
for side,s in [('L',1),('R',-1)]:
    JOINTS += [('arm'+side,'chest',(s*2.65,-.15,7.45)),
               ('fore'+side,'arm'+side,(s*3.15,.1,5.7)),
               ('hand'+side,'fore'+side,(s*3.3,.55,4.2)),
               ('fingers'+side,'hand'+side,(s*3.3,.9,3.65)),
               ('thumb'+side,'hand'+side,(s*2.8,.65,4.0)),
               ('leg'+side,'body',(s*1.25,0,3.9)),
               ('shin'+side,'leg'+side,(s*1.25,0,2.15)),
               ('foot'+side,'shin'+side,(s*1.25,0,.55))]
JOINTS += [('chain','handR',(-3.85,.4,4.35)),('chainTip','chain',(-3.85,.4,3.6))]


def NOISE():
    return default_noise(seed=5, depth=.16, jitter=(-.08,.06), floor=.68)


def add(name,joint,center,size,color,rot=(0,0,0)):
    x,y,z=center; a,b,c=[v/2 for v in size]
    PARTS.extend(box(name,joint,(x-a,x+a),(y-b,y+b),(z-c,z+c),color,rot=rot))


def mass(name,joint,center,size,color,layers=5):
    # Closed stepped ellipsoid; center strip plus narrower front/back strips, never a hollow shell.
    x,y,z=center; w,d,h=size
    for i in range(layers):
        u=(i+.5)/layers*2-1
        r=math.sqrt(1-u*u)
        for j in range(3):
            tint=tuple(round(c*(.94 if j==0 else 1.035 if j==2 else 1)) for c in color)
            add(f'{name}_{i}_{j}',joint,(x,y+(j-1)*d*r/3,z-h/2+(i+.5)*h/layers),
                (w*r*(.81 if j!=1 else 1),d*r/3,h/layers),tint)


# Pelvis and barrel torso are separate, allowing weight shifts without rotating the entire model.
mass('Hips','body',(0,-.05,4.05),(3.6,2.6,1.65),PANTS,4)
mass('Belly','body',(0,.35,5.15),(4.1,3.15,2.4),SKIN,6)
mass('Chest','chest',(0,-.35,6.95),(5.2,3.25,2.65),CLOTH,6)
mass('Hump','chest',(0,-.9,7.8),(4.15,2.85,2.1),CLOTH,5)
# Torn open shirt front, collar and dimensional seams wrap over shoulders and back.
for s in [-1,1]:
    for i in range(4):
        add(f'FrontSeam{s}_{i}','chest',(s*(1.5-.13*i),1.13+.06*i,6.15+.43*i),(.26,.22,.48),SEAM,rot=(0,s*12,0))
    for i in range(4):
        add(f'Hem{s}_{i}','chest',(s*(.75+i*.35),1.13,5.97-(i%2)*.23),(.4,.28,.53),CLOTH)
    add(f'Collar{s}','chest',(s*.85,.9,8.1),(1.1,.4,.3),SEAM,rot=(0,s*15,0))
for i in range(5):
    add(f'BackSeam{i}','chest',(.12,-2.04,6.2+.43*i),(.17,.12,.36),SEAM)
add('Belt','body',(0,1.2,4.35),(2.7,.25,.3),BLACK)
add('Buckle','body',(-.4,1.38,4.35),(.52,.15,.42),STEEL)
add('Navel','body',(.12,1.93,5.02),(.27,.08,.22),DARK)

# Forward skull, inset eyes, independent lower jaw, uneven teeth, asymmetric damage without gore.
mass('Skull','head',(0,1.0,8.88),(2.65,2.4,2.75),SKIN,6)
add('MouthCavity','head',(0,2.14,8.15),(1.62,.25,.66),BLACK)
mass('Jaw','jaw',(0,1.66,7.96),(1.94,1.45,.69),LIGHT,3)
add('Chin','jaw',(.12,2.13,7.72),(1.45,.44,.32),SKIN)
for s in [-1,1]:
    add(f'Socket{s}','head',(s*.67,2.04,9.14),(.78,.25,.56),DARK)
    add(f'Eye{s}','head',(s*.67,2.19,9.12),(.39,.08,.2),(182,139,49))
    add(f'Pupil{s}','head',(s*.67,2.24,9.12),(.12,.04,.21),BLACK)
    add(f'Brow{s}','head',(s*.64,2.1,9.47),(.94,.4,.3),DARK,rot=(0,s*12,0))
    add(f'Cheek{s}','head',(s*.95,1.94,8.54),(.5,.44,.7),LIGHT)
    add(f'Ear{s}','head',(s*1.34,.95,8.92),(.38,.6,.77),DARK)
    add(f'EarInner{s}','head',(s*1.53,1.02,8.95),(.09,.37,.42),SKIN)
add('NoseBridge','head',(.04,2.13,8.96),(.44,.5,.74),LIGHT,rot=(0,-7,0))
add('Nose','head',(.13,2.4,8.63),(.6,.4,.3),DARK)
for i,x in enumerate([-.63,-.22,.25,.62]):
    add(f'Tooth{i}','head',(x,2.33,8.32-(i%2)*.05),(.23,.22,.34-(i%2)*.06),BONE)
for i,x in enumerate([-.46,.35]):
    add(f'LowerTooth{i}','jaw',(x,2.28,8.2),(.22,.18,.26),BONE)
for i in range(7):
    add(f'Hair{i}','head',(-.9+i*.28,.96+(i%3)*.13,10.1+(i%2)*.15),(.31,.95,.42),BLACK)
for i in range(3):
    add(f'Fringe{i}','head',(-.85+i*.36,1.96,9.94-i*.08),(.29,.25,.55),BLACK)

for side,s in [('L',1),('R',-1)]:
    left=side=='L'
    mass('Shoulder'+side,'arm'+side,(s*2.63,-.2,7.35),(1.8,2.0,1.65),SKIN if left else CLOTH,4)
    mass('UpperArm'+side,'arm'+side,(s*3.0,.02,6.5),(1.4,1.65,1.8),SKIN,4)
    mass('Elbow'+side,'fore'+side,(s*3.15,.1,5.68),(1.28,1.44,.75),DARK,3)
    mass('Forearm'+side,'fore'+side,(s*3.3,.4,4.96),(1.68 if left else 1.35,1.6,1.65),SKIN,5)
    mass('Palm'+side,'hand'+side,(s*3.3,.66,3.94),(1.43 if left else 1.25,1.0,.92),LIGHT,3)
    for i in range(3):
        x=s*(2.91+i*.38)
        add(f'Finger{side}{i}','fingers'+side,(x,1.02,3.27),(.32,.48,.85),SKIN,rot=(-9,0,0))
        add(f'FingerTip{side}{i}','fingers'+side,(x,1.22,2.91),(.29,.5,.29),DARK)
        add(f'Nail{side}{i}','fingers'+side,(x,1.48,2.98),(.21,.07,.2),BONE)
    add('Thumb'+side,'thumb'+side,(s*2.64,.89,3.61),(.4,.55,.78),SKIN,rot=(12,s*-18,0))
    mass('Thigh'+side,'leg'+side,(s*1.25,-.07,3.14),(1.72,1.84,1.82),PANTS,4)
    mass('Knee'+side,'shin'+side,(s*1.25,.14,2.12),(1.35,1.44,.8),SKIN,3)
    mass('Calf'+side,'shin'+side,(s*1.25,-.09,1.39),(1.31,1.4,1.34),DARK,4)
    mass('Foot'+side,'foot'+side,(s*1.25,.36,.4),(1.72,2.05,.8),SKIN,3)
    for i in range(3):
        x=s*(.78+.43*i)
        add(f'Toe{side}{i}','foot'+side,(x,1.28,.24),(.4,.5,.46),LIGHT)
        add(f'ToeNail{side}{i}','foot'+side,(x,1.55,.21),(.28,.1,.27),BONE)
    for i in range(3):
        add(f'Rag{side}{i}','leg'+side,(s*(.7+i*.46),.77,2.51-(i%2)*.17),(.43,.21,.52),PATCH)
    for i in range(3):
        add(f'Boil{side}{i}','fore'+side,(s*(3.45+.17*(i%2)),1.08,4.7+i*.26),(.26,.18,.26),BOIL)
    for i in range(4):
        add(f'Stitch{side}{i}','arm'+side,(s*(2.76+i*.13),.86,6.25+i*.23),(.22,.12,.11),(135,113,84),rot=(0,0,s*25))
# Right wrist cuff, rings consist of four cuboids, linked on alternate planes.
for y,z,w,d,h in [(0,4.3,1.55,.24,.42),(1.02,4.3,1.55,.24,.42),(.51,4.3,.22,1.0,.42)]:
    if w==.22:
        for x in [-4.0,-2.6]: add('CuffSide'+str(x),'handR',(x,y,z),(w,d,h),STEEL)
    else: add('Cuff'+str(y),'handR',(-3.3,y,z),(w,d,h),STEEL)
for i in range(3):
    j='chain' if i<2 else 'chainTip'; z=4.04-i*.56
    for dx,dz,w,h in [(-.2,0,.11,.52),(.2,0,.11,.52),(0,.25,.4,.11),(0,-.25,.4,.11)]:
        add(f'Chain{i}_{dx}_{dz}',j,(-4.0+dx,.4,z+dz),(w,.13,h),STEEL)


def pose(**kw):
    return {k:tuple(v)+(None,)*(4-len(v)) for k,v in kw.items()}


def legs(p,drop=0,y=0,liftL=0,liftR=0):
    # Analytic two-bone IK holds ankle endpoints; knees fold forward and soles counter-rotate.
    for side,lift in [('L',liftL),('R',liftR)]:
        dz=3.35-drop-lift; yy=y if not isinstance(y,tuple) else y[0 if side=='L' else 1]
        r=min(3.345,max(.3,math.hypot(dz,yy))); a=1.75; b=1.6
        thigh=math.atan2(yy,dz)+math.acos(max(-1,min(1,(a*a+r*r-b*b)/(2*a*r))))
        knee=-(math.pi-math.acos(max(-1,min(1,(a*a+b*b-r*r)/(2*a*b)))))
        p['leg'+side]=(math.degrees(thigh),0,0,None)
        p['shin'+side]=(math.degrees(knee),0,0,None)
        p['foot'+side]=(-math.degrees(thigh+knee),0,0,None)
    return p


def rest():
    return legs(pose(chest=(-4,0,0),head=(4,0,-3),armL=(5,-5,-5),armR=(2,4,6),
                     foreL=(12,0,0),foreR=(8,0,0),fingersL=(8,0,0),fingersR=(12,0,0)),.04)


def key(p):
    q=rest(); q.update(p); return q


def actions():
    acts={}; sin=math.sin; pi=math.pi
    idle=[]
    for f in range(0,126,5):
        t=f/125*2*pi
        p=rest(); p.update(pose(body=(0,1.4*sin(t),1.1*sin(t),(0,0,.035*sin(t))),
            chest=(-4+1.7*sin(t),0,0),head=(4-1.2*sin(t-.3),0,-3+2*sin(t)),
            foreL=(12+2*sin(t-.6),0,0),foreR=(8+1.5*sin(t-.9),0,0),jaw=(-2-1.5*sin(t),0,0),
            chain=(5*sin(t-.8),3*sin(t),0),chainTip=(7*sin(t-1.1),0,0)))
        idle.append((f,p))
    acts['idle']=(idle,True)
    for clip,duration,stride,speedlean in [('walk',45,1.65,-7),('charge_run',24,1.65,-22)]:
        keys=[]
        for f in range(0,duration+1,3):
            t=f/duration*2*pi; s=sin(t); drop=.55+.06*(1-math.cos(2*t))
            p=rest(); p.update(pose(body=(0,0,0,(.06*s,0,-drop)),chest=(speedlean,0,-4*s),head=(-speedlean*.65,0,3*s),
                armL=(10-12*s,-5,-6),armR=(8+12*s,6,7),foreL=(18+8*s,0,0),foreR=(17-8*s,0,0),
                jaw=(-4+2*sin(t-.4),0,0),chain=(14*sin(t-1),0,10*sin(t)),chainTip=(22*sin(t-1.4),0,0)))
            feet=[]
            for phase in [f/duration,(f/duration+.5)]:
                phase=phase%1
                if phase<.6: feet.append((stride*(1-2*phase/.6),0))
                else:
                    u=(phase-.6)/.4
                    feet.append((-stride+2*stride*(u*u*(3-2*u)),.65*sin(pi*u)))
            legs(p,drop,(feet[0][0],feet[1][0]),feet[0][1],feet[1][1])
            keys.append((f,p))
        acts[clip]=(keys,True)
    # Coiled torso -> leading shoulder -> elbow -> wrist -> recoil; impact at .56 s.
    acts['melee']=([(0,rest()),(7,key(pose(chest=(5,-10,-8),head=(0,8,0),armL=(-28,-12,-22),foreL=(65,0,0)))),
      (12,key(pose(chest=(9,-17,-10),head=(-2,14,0),armL=(-42,-17,-30),foreL=(92,0,0),handL=(-18,0,0)))),
      (16.8,key(pose(chest=(-17,21,9),head=(10,-12,0),armL=(76,12,9),foreL=(9,0,0),handL=(8,0,0),fingersL=(38,0,0)))),
      (20,key(pose(chest=(-20,25,11),armL=(83,18,15),foreL=(5,0,0),handL=(18,0,0)))),
      (28,key(pose(chest=(-9,9,4),armL=(40,5,1),foreL=(35,0,0),handL=(-5,0,0)))),(39.6,rest())],False)
    back=key(pose(chest=(14,0,0),head=(24,0,0),jaw=(-13,0,0),armL=(18,0,-18),armR=(15,0,18),foreL=(38,0,0),foreR=(32,0,0)))
    vomit=key(pose(chest=(-23,0,0),head=(-18,0,0),jaw=(-35,0,0),armL=(30,0,-17),armR=(32,0,20),foreL=(18,0,0),foreR=(22,0,0)))
    acts['blade_raise']=([(0,rest()),(11,key(pose(chest=(-10,0,0),head=(-8,0,0),jaw=(-4,0,0)))),(24,back),(32,back)],False)
    acts['blade_sweep']=([(0,back),(3,vomit),(8,key(pose(**{**vomit,'head':(-12,0,3,None),'jaw':(-28,0,0,None)}))),(14,vomit),(21,key(pose(chest=(-12,0,0),head=(-5,0,0),jaw=(-12,0,0)))),(27,rest())],False)
    up=key(pose(chest=(8,0,0),head=(18,0,0),armL=(155,0,-13),armR=(155,0,13),foreL=(36,0,0),foreR=(36,0,0),handL=(-12,0,0),handR=(-12,0,0)))
    slam=legs(key(pose(body=(0,0,0,(0,.15,-1.05)),chest=(-30,0,0),head=(20,0,0),armL=(35,0,-6),armR=(35,0,6),foreL=(5,0,0),foreR=(5,0,0))),1.05,-.15)
    acts['spikes_raise']=([(0,rest()),(9,key(pose(chest=(-12,0,0),foreL=(40,0,0),foreR=(40,0,0)))),(27,up),(36,up)],False)
    acts['spikes_slam']=([(0,up),(3.6,slam),(6,slam),(10,legs(key(pose(body=(0,0,0,(0,0,-.7)),chest=(-17,0,0),armL=(20,0,-8),armR=(20,0,8))),.7)),(18,rest())],False)
    charge=key(pose(chest=(-22,0,-6),head=(16,0,6),armL=(28,0,-15),armR=(25,0,18),foreL=(42,0,0),foreR=(38,0,0)))
    acts['charge_raise']=([(0,rest()),(12,key(pose(chest=(-14,0,0),head=(8,0,0),foreL=(35,0,0)))),(25,charge),(30,charge)],False)
    acts['charge']=acts['charge_raise']
    keys=[]
    for f in range(0,61,6):
        t=f/60*2*pi
        keys.append((f,key(pose(chest=(-18,0,5*sin(t)),head=(-15,5*sin(t-.5),-9*sin(t)),jaw=(-12,0,0),armL=(4,0,-8),armR=(0,0,10),foreL=(3,0,0),chain=(10*sin(t-1),0,0)))))
    acts['stunned']=(keys,True)
    acts['roar']=([(0,rest()),(12,key(pose(chest=(-12,0,0),head=(-10,0,0),foreL=(45,0,0),foreR=(45,0,0)))),
      (27,key(pose(chest=(11,0,0),head=(18,0,0),jaw=(-30,0,0),armL=(35,-20,-40),armR=(35,20,40),foreL=(22,0,0),foreR=(22,0,0)))),
      (42,key(pose(chest=(8,0,3),head=(14,0,-5),jaw=(-24,0,0),armL=(30,-18,-34),armR=(30,18,34)))),(60,rest())],False)
    acts['jump']=([(0,rest()),(6,legs(key(pose(body=(0,0,0,(0,0,-.55)),chest=(-12,0,0))),.55)),
      (12,key(pose(legL=(35,0,0),legR=(32,0,0),shinL=(-55,0,0),shinR=(-50,0,0),armL=(60,0,-10),armR=(60,0,10)))),(20,rest())],False)
    # Collapse in stages: stagger, knee buckles, reaching palm, shoulder contact, inert settling.
    acts['death']=([(0,rest()),
      (10,key(pose(chest=(12,-8,-6),head=(14,0,9),jaw=(-18,0,0),armL=(20,0,-26),armR=(18,0,25)))),
      (22,legs(key(pose(body=(0,0,0,(0,0,-.9)),chest=(-14,0,11),head=(-8,0,-8),armL=(30,0,-15),armR=(38,0,8),foreR=(18,0,0))),.9)),
      (34,key(pose(body=(-22,0,12,(0,.15,-1.7)),chest=(-20,0,0),head=(15,0,-5),legL=(65,0,0),legR=(50,0,0),shinL=(-115,0,0),shinR=(-100,0,0),footL=(50,0,0),footR=(50,0,0),armR=(47,0,0),foreR=(6,0,0),handR=(-35,0,0),armL=(20,0,-22)))),
      (46,key(pose(body=(-64,0,12,(0,.8,-2.6)),chest=(-8,0,0),head=(14,0,-12),legL=(35,0,-8),legR=(20,0,10),shinL=(-80,0,0),shinR=(-65,0,0),footL=(15,0,0),footR=(15,0,0),armR=(10,0,18),foreR=(30,0,0),handR=(-20,0,0),armL=(40,0,-30),foreL=(18,0,0),jaw=(-20,0,0)))),
      (54,key(pose(body=(-82,0,7,(0,1.2,-2.7)),chest=(0,0,0),head=(4,0,-18),legL=(8,0,-8),legR=(6,0,8),shinL=(-25,0,0),shinR=(-15,0,0),footL=(0,0,0),footR=(0,0,0),armL=(44,0,-30),armR=(16,0,25),foreL=(5,0,0),foreR=(30,0,0),handL=(5,0,0),handR=(-12,0,0),jaw=(-12,0,0),chain=(15,0,0),chainTip=(-22,0,0)))),
      (63,key(pose(body=(-79,0,7,(0,1.17,-2.66)),chest=(0,0,0),head=(7,0,-18),legL=(8,0,-8),legR=(6,0,8),shinL=(-20,0,0),shinR=(-12,0,0),footL=(0,0,0),footR=(0,0,0),armL=(42,0,-30),armR=(16,0,25),foreL=(8,0,0),foreR=(30,0,0),handL=(5,0,0),handR=(-12,0,0),jaw=(-9,0,0),chain=(-5,0,0),chainTip=(9,0,0))))],False)
    final=dict(acts['death'][0][-1][1]); final.update(pose(body=(-81,0,7,(0,1.2,-2.7)),head=(5,0,-18),chain=(0,0,0),chainTip=(0,0,0)))
    acts['death'][0].extend([(78,final),(96,final)])
    return acts

PREVIEW_CAMERA=((-18,25,13),(0,.25,5.1),48)
PREVIEW_PREFIX='v2-preview-'
PREVIEWS=[('idle',0),('melee',16.8),('blade_sweep',3),('spikes_raise',30),
          ('death',96,((-18,25,13),(0,2,3.4),42))]
COMPARE_PREFIX='v2-compare-'
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.2),17.5),
         'side':((0,-1,0),(0,0,1),(0,.1,5.2),17.5),
         'back':((1,0,0),(0,0,1),(0,0,5.2),17.5),
         'hero':((-18,25,13),(0,.25,5.1),48)}
if __name__ == '__main__':
    run(globals())
