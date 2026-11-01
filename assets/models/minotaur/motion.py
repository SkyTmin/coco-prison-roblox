"""Original Minotaur acting. Audit supplies durations, never third-party keyframes.
Reuses the already validated analytic two-bone solver from our Splinter authoring code.
"""
import math
from mathutils import Vector, Euler
from splinter.motion import Rig, pose

def make_actions(joints):
    rig=Rig(joints); a={}; sin=math.sin; pi=math.pi
    def rest(extra=None,drop=.20,feet=None):
        p=pose(body=(0,0,0,(0,0,-drop)),chest=(-5,0,0),head=(1,0,0),jaw=-1,
               foreL=3,foreR=3,handL=-3,handR=-3,fingersL=8,fingersR=8,
               thumbL=(0,-10,0),thumbR=(0,10,0),clothFront=4,clothBack=-4)
        p.update(extra or {})
        return rig.planted(p,feet)
    def follow(p,t,amp=1,gravity=True):
        for side,s,lag in [('L',1,0),('R',-1,.4)]:
            swing=(amp*7*sin(t-lag),amp*3*sin(t-.5-lag),s*amp*4*sin(t-.7))
            if gravity:
                # Shackles travel with the wrists; the loose links hang down even above the head.
                desired=Euler(tuple(math.radians(v) for v in swing)).to_quaternion()
                q=rig.world(p,'fore'+side).to_quaternion().inverted() @ desired
                p['chain'+side]=tuple(math.degrees(v) for v in q.to_euler('XYZ'))+(None,)
            else: p['chain'+side]=swing+(None,)
            p['chainTip'+side]=(amp*12*sin(t-.6-lag),0,s*amp*7*sin(t-1.2),None)
            p['ear'+side]=(amp*2*sin(t-.6),0,s*amp*3*sin(t-.5),None)
        for i in range(1,5): p['tail'+str(i)]=(amp*2*sin(t-i*.5),0,amp*(3+i)*sin(t-i*.6),None)
        p['beard']=(amp*3*sin(t-.8),0,0,None)
        return p
    def idle(f):
        t=f/175*2*pi
        return follow(rest(pose(chest=(-5+1.4*sin(t),0,.4*sin(t)),head=(1-.9*sin(t-.2),0,1.8*sin(t-.5)),
             jaw=-1-.7*sin(t-.6),foreL=3+.7*sin(t),foreR=3+.7*sin(t-.3)),.2-.025*sin(t)),t,.5)
    a['idle']=([(f,idle(f)) for f in range(0,176,7)],True)
    # Stance travels backwards at a constant speed; the physical boss supplies forward travel.
    for clip,length,stride,stance,lift,drop in [('walk',32.5,.9,.6,.35,.55),('run',20,1.65,.55,.68,.8)]:
        keys=[]
        for i in range(33):
            f=length*i/32; t=i/32*2*pi; step=sin(t); feet={}
            for side,phase in [('L',i/32),('R',i/32+.5)]:
                q=phase%1
                if q<stance: y=stride*(1-2*q/stance); z=0
                else:
                    u=(q-stance)/(1-stance); y=-stride+2*stride*u*u*(3-2*u); z=lift*sin(pi*u)
                feet[side]=(0,y,z)
            p=rest(pose(chest=(-9 if clip=='walk' else -22,0,-4*step),head=(5 if clip=='walk' else -12,0,2*step),
                armL=(-12 if clip=='walk' else -27)*step,armR=(12 if clip=='walk' else 27)*step,
                foreL=10+5*step,foreR=10-5*step,handL=-6+3*sin(t-.5),handR=-6-3*sin(t-.5),
                clothFront=8+4*sin(2*t-.7),clothBack=-8-4*sin(2*t-.7)),drop+.035*(1-math.cos(2*t)),feet)
            keys.append((f,follow(p,t,1 if clip=='walk' else 1.8)))
        a[clip]=(keys,True)

    # Horn strike: load the hips, drop the muzzle, drive upward; crest contact at .55 s.
    a['melee']=([(0,rest()),(6,rest(pose(chest=(1,0,-5),head=(-18,0,5),armL=-12,armR=-12),.35)),
      (11,rest(pose(chest=(-19,0,-7),head=(-31,0,8),jaw=-8,foreL=14,foreR=14),.67)),
      (16.5,rest(pose(chest=(7,0,6),head=(24,0,-5),jaw=-13,armL=22,armR=22,foreL=-8,foreR=-8),.28)),
      (20,rest(pose(chest=(10,0,9),head=(31,0,-7),armL=29,armR=26),.24)),
      (26,rest(pose(chest=(-8,0,2),head=(8,0,-2),foreL=14,foreR=14),.36)),(33.75,rest())],False)
    a['impact']=([(0,rest()),(7,rest(pose(chest=(5,0,-8),head=(7,0,5),armL=32,armR=24),.3,{'L':(0,.18,.65)})),
      (13,rest(pose(chest=(6,0,-9),head=(7,0,6),armL=47,armR=37),.35,{'L':(0,.55,1.1)})),
      (18,rest(pose(chest=(-22,0,5),head=(11,0,-4),armL=6,armR=8,jaw=-15),.7)),
      (22,rest(pose(chest=(-17,0,2),head=(7,0,-3),foreL=18,foreR=14),.52)),(35,rest())],False)
    # Two distinct palm blows; mirrored windup, opposite torso rotation, separate recovery arcs.
    a['double_attack']=([(0,rest()),(9,rest(pose(chest=(2,0,-22),head=(0,0,14),armL=(95,12,-18),foreL=-36,handL=-15,
      armR=(-18,0,8)),.34)),(16.5,rest(pose(chest=(-17,0,20),head=(8,0,-11),armL=(42,-8,22),foreL=12,handL=18,jaw=-13),.5)),
      (23,rest(pose(chest=(4,0,26),head=(2,0,-15),armR=(103,-12,17),foreR=-39,handR=-20,armL=-12),.3)),
      (31.5,rest(pose(chest=(-19,0,-22),head=(7,0,12),armR=(38,8,-22),foreR=14,handR=20,jaw=-18),.54)),
      (37,rest(pose(chest=(-15,0,-16),head=(8,0,9),armR=12,foreR=22),.42)),(50,rest())],False)

    # Both hands cradle a rooted clod. The server follows its exported socket, then releases it.
    def grip(p,center,rotation=(0,0,0)):
        q=Euler(tuple(math.radians(v) for v in rotation)).to_quaternion()
        for side,s in [('L',1),('R',-1)]:
            point=Vector(center)+q @ Vector((s*1.03,0,0))
            rig.chain(p,'arm'+side,'fore'+side,'hand'+side,point,(s,1,.2),q)
            p['fingers'+side]=(30,0,0,None)
        return p
    throw=[(0,rest()),(12,rest(pose(chest=(-13,0,0),head=(-9,0,0),armL=20,armR=20),.75)),
      (24,grip(rest(pose(chest=(-20,0,0),head=(-8,0,0)),2.6),(0,1.8,1.6))),
      (33,grip(rest(pose(chest=(-16,0,0),head=(-4,0,0),jaw=-9),2.15),(0,2.0,2.2))),
      (47,grip(rest(pose(chest=(1,0,0),head=(4,0,0),jaw=-13),.42),(0,2.2,5.3))),
      (58,grip(rest(pose(chest=(7,0,0),head=(4,0,0),jaw=-21),.18),(0,1.05,10.0))),
      (62,grip(rest(pose(chest=(10,0,0),head=(3,0,0),jaw=-22),.15),(0,.6,10.08))),
      (67.5,grip(rest(pose(chest=(-12,0,0),head=(9,0,0),jaw=-18),.45),(0,3.35,7.0),(-20,0,0))),
      (74,rest(pose(chest=(-23,0,0),head=(15,0,0),armL=55,armR=55,foreL=18,foreR=18,handL=23,handR=23,
                      fingersL=-12,fingersR=-12,clothFront=19),.7)),
      (86,rest(pose(chest=(-12,0,0),head=(8,0,0),armL=12,armR=12,foreL=18,foreR=18),.35)),(107.5,rest())]
    # Dense two-hand IK through the lift keeps both wrists on the clod BETWEEN the acting keys.
    centers={24:(0,1.8,1.6),33:(0,2.0,2.2),47:(0,2.2,5.3),58:(0,1.05,10.0),62:(0,.6,10.08),67.5:(0,3.35,7.0)}
    dense=[]
    for i in range(88):
        f=24+i*.5
        left,right=next((left,right) for left,right in zip(throw,throw[1:]) if left[0]<=f<=right[0] and left[0]>=24)
        u=(f-left[0])/(right[0]-left[0]); u=u*u*(3-2*u)
        p={}
        for n in set(left[1])|set(right[1]):
            va=left[1].get(n,(0,0,0,None)); vb=right[1].get(n,(0,0,0,None))
            off=tuple((va[3] or (0,0,0))[j]*(1-u)+(vb[3] or (0,0,0))[j]*u for j in range(3))
            p[n]=tuple(va[j]*(1-u)+vb[j]*u for j in range(3))+(off,)
        # Preserve hoof support while interpolating the crouch and trunk.
        rig.planted(p)
        center=Vector(centers[left[0]]).lerp(Vector(centers[right[0]]),u)
        rotation=(-20*u if right[0]==67.5 else 0,0,0)
        dense.append((f,grip(p,center,rotation)))
    a['throws_the_ground']=([k for k in throw if k[0]<24]+dense+[k for k in throw if k[0]>67.5],False)

    # Fixed 4.125 s charge: 1.35 windup, .916667 travel, then weighty braking.
    rush=[(0,rest()),(12,rest(pose(chest=(-12,0,0),head=(-20,0,0),armL=-22,armR=-22,jaw=-8),.55)),
      (26,rest(pose(chest=(-24,0,0),head=(-26,0,0),armL=-32,armR=-32,foreL=15,foreR=15),.85)),
      (40.5,rest(pose(chest=(-25,0,0),head=(-30,0,0),armL=-30,armR=-30,foreL=17,foreR=17),.85))]
    for i in range(1,12):
        f=40.5+i*2.5; phase=i/4; t=phase*2*pi; feet={}
        for side,off in [('L',0),('R',.5)]:
            q=(phase+off)%1; feet[side]=(0,1.25*math.cos(q*2*pi),max(0,math.sin(q*2*pi))*.75)
        p=rest(pose(chest=(-27,0,2*sin(t)),head=(-24,0,-2*sin(t)),armL=-25+15*sin(t),armR=-25-15*sin(t),
                    foreL=18,foreR=18,jaw=-13,clothFront=26),1.03,feet)
        rush.append((f,follow(p,t,2)))
    rush += [(76,rest(pose(chest=(-17,0,0),head=(-7,0,0),armL=35,armR=35,foreL=15,foreR=15),.75)),
      (88,rest(pose(chest=(3,0,0),head=(6,0,0),armL=15,armR=15),.4)),(106,rest()),(123.75,rest())]
    a['minotaur_rush']=(rush,False)

    # Collision knocks the head/shoulders back; the knees buckle, then breathing and balance return.
    a['stun']=([(0,rest(pose(chest=(-25,0,0),head=(-24,0,0),armL=-23,armR=-23),.8)),
      (5,rest(pose(chest=(16,0,-5),head=(25,0,9),jaw=-22,armL=45,armR=36),.5)),
      (15,rest(pose(chest=(-20,0,7),head=(-13,0,-11),jaw=-13,armL=15,armR=24),1.1)),
      (32,rest(pose(chest=(-17,0,-5),head=(-17,0,15),armL=10,armR=12),1.0)),
      (51,rest(pose(chest=(-16,0,4),head=(-11,0,-12),jaw=-11),.91)),
      (71,rest(pose(chest=(-13,0,-3),head=(-8,0,7),jaw=-7),.8)),
      (91,rest(pose(chest=(-9,0,2),head=(-4,0,-4)),.55)),(113.75,rest())],False)

    def sleep(extra=None):
        p=pose(body=(-6,0,0,(0,0,-2.1)),chest=(-24,0,0),head=(-26,0,0),jaw=-3,
               armL=(17,0,-6),armR=(17,0,6),foreL=-8,foreR=-8,handL=8,handR=8,
               legL=(72,0,5),legR=(72,0,-5),shinL=-125,shinR=-125,footL=49,footR=49,
               clothFront=42,clothBack=-15,fingersL=10,fingersR=10)
        p.update(extra or {}); return p
    a['sleep']=([(i*257.5/16,follow(sleep(pose(chest=(-24+1.2*sin(i/16*2*pi),0,0),
              head=(-26-.7*sin(i/16*2*pi-.4),0,0))),i/16*2*pi,.25)) for i in range(17)],True)
    a['awakening']=([(0,sleep()),(24,sleep(pose(head=(-22,0,-4),earL=(0,0,-6),earR=(0,0,8)))),
      (48,sleep(pose(head=(-12,0,9),chest=(-21,0,-3),jaw=-6))),
      (76,sleep(pose(chest=(-14,0,0),head=(4,0,-5),armL=33,armR=28,foreL=-18,foreR=-16))),
      (105,sleep(pose(chest=(-8,0,-8),head=(9,0,7),armL=(52,0,-19),armR=(49,0,19),foreL=-34,foreR=-32,jaw=-15))),
      (127,sleep(pose(chest=(2,0,0),head=(19,0,0),armL=(59,0,-38),armR=(57,0,38),foreL=-27,foreR=-25,jaw=-24))),
      (142,sleep(pose(chest=(5,0,0),head=(23,0,0),armL=(37,0,-64),armR=(32,0,64),foreL=5,foreR=8,jaw=-29))),
      (165,rest(pose(chest=(-24,0,-7),head=(3,0,7),armL=30,armR=17,foreL=15,foreR=20),1.8)),
      (192,rest(pose(chest=(-13,0,3),head=(9,0,-4),armL=15,armR=8,foreL=12,foreR=14),.9)),
      (218,rest(pose(chest=(8,0,0),head=(26,0,0),jaw=-30,armL=(27,0,-22),armR=(27,0,22)),.17)),
      (240,rest(pose(chest=(5,0,0),head=(22,0,0),jaw=-26,armL=(22,0,-17),armR=(22,0,17)),.21)),
      (265,rest(pose(chest=(-8,0,2),head=(7,0,-3),foreL=12,foreR=12),.3)),(295,rest())],False)

    # Long death has acting throughout: stagger, failed recovery, brace, side impact, then settling.
    death=[(0,rest()),(17,rest(pose(chest=(9,0,-6),head=(24,0,10),jaw=-18,armL=24,armR=14),.35)),
      (40,rest(pose(chest=(-14,0,5),head=(-13,0,-8),jaw=-10,armL=12,armR=-8),.8)),
      (66,rest(pose(chest=(-10,0,-8),head=(-5,0,12),armL=24,armR=17),.65)),
      (94,sleep(pose(chest=(-12,0,7),head=(9,0,-8),jaw=-17,armL=39,armR=28))),
      (125,sleep(pose(chest=(-24,0,-5),head=(-17,0,8),jaw=-9,armL=27,armR=21))),
      (151,sleep(pose(chest=(-15,0,7),head=(5,0,-10),armL=42,armR=30,jaw=-12))),
      (178,pose(body=(-14,25,1,(.2,.1,-1.8)),chest=(-22,3,-8),head=(4,-8,12),jaw=-15,
          armL=(42,35,-12),foreL=-8,handL=12,armR=(37,-19,13),foreR=18,handR=-12,
          legL=(65,0,12),shinL=-117,footL=50,legR=(54,0,-9),shinR=-98,footR=43,clothFront=35)),
      (202,pose(body=(-12,55,-5,(.6,.3,-1.7)),chest=(-14,6,-10),head=(8,-13,21),jaw=-22,
          armL=(33,55,-14),foreL=-12,handL=8,armR=(46,-30,9),foreR=30,handR=-13,
          legL=(62,0,18),shinL=-111,footL=46,legR=(37,0,-16),shinR=-84,footR=38,clothFront=25)),
      (222,pose(body=(-8,82,-8,(.85,.4,-1.5)),chest=(-12,7,-7),head=(15,-18,27),jaw=-15,
          armL=(27,64,-14),foreL=-8,handL=12,armR=(49,-38,5),foreR=27,handR=-9,
          legL=(52,0,20),shinL=-97,footL=33,legR=(26,-25,8),shinR=-48,footR=25,clothFront=12)),
      (231,pose(body=(-8,77,-8,(.85,.4,-1.5)),chest=(-9,5,-5),head=(10,-16,30),jaw=-12,
          armL=(24,60,-14),foreL=-5,handL=13,armR=(45,-34,5),foreR=24,handR=-8,
          legL=(49,0,20),shinL=-94,footL=35,legR=(24,-25,8),shinR=-44,footR=27,clothFront=8))]
    final=dict(death[-1][1]); final.update(pose(body=(-8,80,-8,(.85,.4,-1.5)),chest=(-11,5,-5),head=(7,-15,32),jaw=-9))
    for f in [255,278,312,350,388.75]:
        p=dict(final)
        if f<312: p.update(pose(head=(7+(312-f)*.035,-15,32-(312-f)*.025),jaw=-9-(312-f)*.025))
        death.append((f,p))
    for f,p in death:
        if f>=222:
            shoulder=rig.world(p,'armR').translation
            rig.chain(p,'armR','foreR','handR',shoulder+Vector((1.25,1.4,-1.6)),(-.3,-1,.2),Euler((.52,0,.52)).to_quaternion())
            p['fingersR']=(5 if f>278 else 12,0,0,None)
    a['death']=(death,False)
    a['roar']=([(0,rest()),(12,rest(pose(chest=(-14,0,0),head=(-8,0,0)),.45)),
      (28,rest(pose(chest=(8,0,0),head=(26,0,0),jaw=-32,armL=(27,0,-21),armR=(27,0,21)),.2)),
      (40,rest(pose(chest=(6,0,0),head=(22,0,0),jaw=-27),.2)),(54,rest())],False)
    a['jump']=([(0,rest()),(6,rest(pose(chest=(-18,0,0),head=(6,0,0)),.9)),
      (12,pose(chest=(-5,0,0),head=(10,0,0),armL=34,armR=34,legL=35,legR=35,shinL=-60,shinR=-60,footL=25,footR=25)),
      (19,rest(pose(chest=(-20,0,0),head=(14,0,0)),.95)),(24,rest())],False)
    for name,s in [('hurt_1',1),('hurt_2',-1)]:
        a[name]=([(0,rest()),(3.5,rest(pose(chest=(6,0,9*s),head=(12,0,-8*s),jaw=-12),.32)),(11.25,rest())],False)
    # Secondary motion responds after the driving pose. Copy held keys before Euler unwrap.
    for name,(keys,loop) in list(a.items()):
        fixed=[]; previous={}
        for f,original in keys:
            p=dict(original)
            if name not in ['idle','walk','run','sleep']:
                amp=.8 if f<keys[-1][0] else 0
                if name=='death': amp=1.8 if f<222 else max(0,1-(f-222)/90)
                follow(p,f/13,amp,gravity=name!='death' or f<178)
            for n,v in list(p.items()):
                values=list(v)
                if n in previous:
                    for axis in range(3): values[axis]=previous[n][axis]+(values[axis]-previous[n][axis]+180)%360-180
                p[n]=tuple(values); previous[n]=values
            fixed.append((f,p))
        a[name]=(fixed,loop)
    return a

def release_origins(joints):
    rig=Rig(joints); keys=make_actions(joints)['throws_the_ground'][0]
    p=next(p for f,p in keys if f==67.5)
    center=sum((rig.world(p,'hand'+side).translation for side in ['L','R']),Vector())/2
    return {'throws_the_ground':[round(center.x,4),round(center.z,4),round(-center.y,4)]}
