"""Original articulated motion for the existing Splinter / rat-king sculpture.
Names/durations and release times follow the audited clips and existing server config.
All poses, IK, overlap and acting are original; no third-party animation was imported.
"""
import math
from mathutils import Matrix, Vector, Euler, Quaternion


def pose(**values):
    return {n: (v,0,0,None) if isinstance(v,(int,float)) else tuple(v)+(None,)*(4-len(v))
            for n,v in values.items()}


class Rig:
    def __init__(self,joints):
        self.points={n:Vector(v) for n,_,v in joints}
        self.parents={n:p for n,p,_ in joints}

    def world(self,p,name):
        parent=self.parents[name]; value=p.get(name,(0,0,0,None))
        base=self.points[name]-(self.points[parent] if parent else Vector())
        local=Matrix.Translation(base+Vector(value[3] or (0,0,0))) @ Euler(
            tuple(math.radians(v) for v in value[:3]),'XYZ').to_matrix().to_4x4()
        return self.world(p,parent) @ local if parent else local

    def chain(self,p,upper,lower,end,target,hint,rotation=None):
        """Analytic two-bone solve; the foot/hand orientation is controlled independently."""
        parent=self.parents[upper]; space=self.world(p,parent)
        points=self.points; a,b,c=[points[n]-points[parent] for n in [upper,lower,end]]
        target=space.inverted() @ Vector(target)
        direction=(target-a).normalized(); distance=(target-a).length
        l1,l2=(b-a).length,(c-b).length
        assert distance<l1+l2+.03,(upper,'unreachable target',distance,l1+l2)
        distance=min(distance,l1+l2-.002)
        along=(l1*l1-l2*l2+distance*distance)/(2*distance)
        pole=space.to_quaternion().inverted() @ Vector(hint)
        bend=(pole-direction*pole.dot(direction)).normalized()
        elbow=a+direction*along+bend*math.sqrt(max(0,l1*l1-along*along))
        q1=(b-a).rotation_difference(elbow-a)
        q2=(c-b).rotation_difference(q1.inverted() @ (target-elbow))
        q3=(space.to_quaternion() @ q1 @ q2).inverted() @ (rotation or Quaternion())
        for n,q in [(upper,q1),(lower,q2),(end,q3)]:
            p[n]=tuple(math.degrees(v) for v in q.to_euler('XYZ'))+(None,)
        return p

    def planted(self,p,offsets=None):
        for side in ['L','R']:
            target=self.points['foot'+side]+Vector((offsets or {}).get(side,(0,0,0)))
            self.chain(p,'leg'+side,'shin'+side,'foot'+side,target,(0,1,0))
        return p


def make_actions(joints,parts):
    rig=Rig(joints); a={}; sin=math.sin; pi=math.pi

    def rest(extra=None,drop=.1):
        p=pose(body=(0,0,0,(0,0,-drop)),chest=(-4,0,0),head=(3,0,0),jaw=-2,
               foreL=5,foreR=5,handL=-5,handR=-5,fingersL=-4,fingersR=-4,
               clothFront=3,clothL=(0,-2,0),clothR=(0,2,0))
        p.update(extra or {})
        return rig.planted(p)

    def tail(p,phase,amplitude=1):
        for i in range(1,8):
            p['tail'+str(i)]=(amplitude*2.2*sin(phase-i*.48),
                             amplitude*.7*sin(phase-i*.35),
                             amplitude*(2.5+i*.55)*sin(phase-i*.6),None)
        return p

    idle=[]
    for f in range(0,61,5):
        t=f/60*2*pi
        p=rest(pose(chest=(-4+1.2*sin(t),0,.5*sin(t)),head=(3-.8*sin(t-.3),0,1.6*sin(t-.5)),
                    jaw=-2-1.3*sin(t-.6),earL=(1.5*sin(t-.8),0,2*sin(t-.5)),
                    earR=(1.2*sin(t-1),0,-1.5*sin(t-.9)),
                    foreL=5+.8*sin(t-.6),foreR=5+.7*sin(t-.9),
                    clothFront=3+.7*sin(t-.8)),drop=.1-.015*sin(t))
        idle.append((f,tail(p,t,.45)))
    a['idle']=(idle,True)
    walk=[]
    for f in range(0,31,2):
        t=f/30*2*pi; step=sin(t); drop=.57+.025*(1-math.cos(t*2)); offsets={}
        for side,phase in [('L',f/30),('R',f/30+.5)]:
            q=phase%1
            if q<.6: y=.8*(1-2*q/.6); z=0
            else:
                u=(q-.6)/.4; y=-.8+1.6*u*u*(3-2*u); z=.29*sin(pi*u)
            offsets[side]=(0,y,z)
        p=pose(body=(0,0,0,(.035*step,0,-drop)),chest=(-8,0,-4.5*step),
               head=(5,0,3*step),jaw=-4-1.5*sin(t*2),
               armL=-10*step,armR=10*step,foreL=8+4*step,foreR=8-4*step,
               handL=-6+3*sin(t-.7),handR=-6-3*sin(t-.7),
               earL=(4*sin(t-.7),0,3*step),earR=(-4*sin(t-.9),0,-3*step),
               clothFront=8+4*sin(t*2-.8),clothL=(4*step,-4,0),clothR=(-4*step,4,0))
        walk.append((f,tail(rig.planted(p,offsets),t,1.2)))
    a['walk']=(walk,True)

    # The pelvis leads the claw, then the elbow extends, wrist snaps, shoulder and tail recover.
    a['melee']=([(0,rest()),
      (5,rest(pose(chest=(0,0,-9),head=(3,0,6),armR=(38,-12,-18),foreR=-26,handR=-18,fingersR=12),.18)),
      (9,tail(rest(pose(chest=(5,0,-19),head=(5,0,11),armR=(92,-25,-25),foreR=-42,handR=-28,
                       armL=(8,0,10),earL=(0,0,-8),earR=(0,0,10)),.22),-1,1.4)),
      (13,tail(rest(pose(chest=(-14,0,19),head=(6,0,-10),armR=(39,20,22),foreR=3,handR=24,
                        fingersR=-16,jaw=-18,armL=(-15,0,18),clothFront=12),.25),.9,1.5)),
      (16,tail(rest(pose(chest=(-18,0,26),head=(8,0,-15),armR=(8,28,28),foreR=9,handR=28,
                        fingersR=-10,jaw=-12),.28),1.6,1.7)),
      (22,tail(rest(pose(chest=(-9,0,8),armR=(-9,8,9),foreR=16,handR=4,jaw=-5),.17),2.5,.8)),
      (30,rest())],False)

    # Existing server timing: crouch until 10f, travel 10..25f, land at 25f, recover by 33f.
    swoop=[]
    for f,p in [(0,rest()),
      (6,rest(pose(chest=(-13,0,0),head=(8,0,0),armL=-18,armR=-18,foreL=12,foreR=12,
                   earL=(0,0,-12),earR=(0,0,12),clothFront=12),.42)),
      (10,rest(pose(chest=(-18,0,0),head=(12,0,0),armL=-30,armR=-30,foreL=15,foreR=15,
                    jaw=-11,clothFront=17),.55)),
      (13,pose(body=(-8,0,0,(0,0,.13)),chest=(-13,0,0),head=(11,0,0),jaw=-21,
               armL=58,armR=58,foreL=-18,foreR=-18,handL=7,handR=7,
               legL=-12,legR=-12,shinL=-35,shinR=-35,footL=25,footR=25,
               earL=(0,0,-18),earR=(0,0,18),clothFront=24)),
      (18,pose(body=(-10,0,0,(0,0,.48)),chest=(-10,0,0),head=(9,0,0),jaw=-26,
               armL=70,armR=70,foreL=-8,foreR=-8,handL=8,handR=8,
               legL=-18,legR=-18,shinL=-30,shinR=-30,footL=15,footR=15,
               earL=(0,0,-22),earR=(0,0,22),clothFront=28)),
      (23,pose(body=(-4,0,0,(0,0,.06)),chest=(-16,0,0),head=(13,0,0),jaw=-20,
               armL=49,armR=49,foreL=6,foreR=6,handL=12,handR=12,
               legL=24,legR=24,shinL=-44,shinR=-44,footL=20,footR=20,clothFront=16)),
      (25,rest(pose(chest=(-20,0,0),head=(16,0,0),armL=29,armR=29,foreL=14,foreR=14,
                    jaw=-15,earL=(7,0,-8),earR=(7,0,8),clothFront=-4),.55)),
      (28,rest(pose(chest=(-10,0,0),head=(8,0,0),armL=10,armR=10,foreL=18,foreR=18,
                    jaw=-8,clothFront=12),.27)),(33,rest())]:
        swoop.append((f,tail(p,f/33*2*pi,1.35 if 10<=f<=25 else .7)))
    # Exact resting endpoints make the action fade cleanly to idle.
    swoop[0]=(0,rest()); swoop[-1]=(33,rest()); a['swoop']=(swoop,False)

    reach=rest(pose(chest=(-7,0,-12),head=(-8,0,-15),foreR=12),.17)
    hip=rig.world(reach,'body') @ (Vector((1.35,1.45,3.15))-rig.points['body'])
    rig.chain(reach,'armL','foreL','handL',hip,(1,-1,.15),Euler((-.7,0,-.2)).to_quaternion())
    a['potion']=([(0,rest()),(10,reach),(15,reach),
      (22,tail(rest(pose(chest=(3,0,-20),head=(4,0,9),armL=(96,10,-16),foreL=-55,handL=-24,
                         fingersL=18,thumbL=(0,12,0),armR=(5,0,18)),.15),-.7,1)),
      (27,tail(rest(pose(chest=(7,0,-24),head=(5,0,13),armL=(128,15,-12),foreL=-38,handL=-28,
                         fingersL=18,earL=(0,0,-8),earR=(0,0,9)),.12),-.2,1.2)),
      (30,tail(rest(pose(chest=(-10,0,14),head=(5,0,-7),armL=(68,0,5),foreL=8,handL=18,
                         fingersL=-16,thumbL=(0,-12,0),armR=(-12,0,20),clothFront=11),.22),.8,1.4)),
      (34,tail(rest(pose(chest=(-15,0,20),head=(8,0,-12),armL=(40,-4,12),foreL=15,handL=25,
                         fingersL=-10),.25),1.7,1.4)),
      (40,rest(pose(chest=(-6,0,5),armL=8,foreL=20,handL=-2),.14)),(46.5,rest())],False)

    a['shoot']=([(0,rest()),
      (14,rest(pose(chest=(2,0,0),head=(10,0,0),jaw=-14,armL=-8,armR=-8),.14)),
      (29,tail(rest(pose(chest=(8,0,0),head=(19,0,0),jaw=-29,armL=-15,armR=-15,
                         earL=(0,0,-12),earR=(0,0,12)),.08),-.7,.8)),
      (40,tail(rest(pose(chest=(10,0,0),head=(23,0,0),jaw=-35,foreL=12,foreR=12,
                         earL=(0,0,-18),earR=(0,0,18)),.05),-.3,1.2)),
      (45,tail(rest(pose(chest=(-11,0,0),head=(-8,0,0),jaw=-10,armL=12,armR=12,
                         handL=12,handR=12,clothFront=13),.25),1.1,1.3)),
      (48,rest(pose(chest=(-16,0,0),head=(-10,0,0),jaw=-15,armL=18,armR=18),.3)),
      (55,rest(pose(chest=(-6,0,0),head=(6,0,0),jaw=-8,earL=(5,0,4),earR=(4,0,-4)),.15)),
      (67.5,rest())],False)

    summon=[]
    for f,p in [(0,rest()),
      (18,rest(pose(chest=(-13,0,0),head=(-7,0,0),armL=18,armR=18,foreL=-18,foreR=-18,
                    fingersL=17,fingersR=17,jaw=-8),.35)),
      (39,rest(pose(chest=(6,0,-4),head=(14,0,2),armL=(112,0,-16),armR=(104,0,16),
                    foreL=-30,foreR=-35,handL=-14,handR=-12,jaw=-24),.07)),
      (58,rest(pose(chest=(9,0,0),head=(21,0,0),armL=(148,0,-18),armR=(145,0,18),
                    foreL=-24,foreR=-25,handL=-16,handR=-16,jaw=-31,earL=(0,0,-10),earR=(0,0,10)),.03)),
      (75,rest(pose(chest=(7,0,3),head=(17,0,-2),armL=(143,0,-17),armR=(148,0,17),
                    foreL=-20,foreR=-22,handL=-18,handR=-18,jaw=-26),.04)),
      (84,rest(pose(chest=(10,0,0),head=(18,0,0),armL=(154,0,-10),armR=(154,0,10),
                    foreL=-27,foreR=-27,jaw=-29),.03)),
      (90,rest(pose(chest=(-24,0,0),head=(4,0,0),armL=24,armR=24,foreL=12,foreR=12,
                    handL=18,handR=18,fingersL=-16,fingersR=-16,jaw=-22,clothFront=-5),.58)),
      (96,rest(pose(chest=(-20,0,0),head=(12,0,0),armL=12,armR=12,foreL=18,foreR=18,
                    jaw=-14,clothFront=10),.5)),
      (108,rest(pose(chest=(-9,0,0),head=(6,0,0),armL=-3,armR=-3,foreL=12,foreR=12),.24)),
      (120,rest())]:
        summon.append((f,tail(p,f/120*2*pi,1.2)))
    summon[0]=(0,rest()); summon[-1]=(120,rest()); a['summon']=(summon,False)

    # Death is acted in stages: recoil, failing knee, attempted brace, side impact, ear/tail settling.
    a['death']=([(0,rest()),
      (10,rest(pose(chest=(8,0,-6),head=(15,0,6),jaw=-23,armL=32,armR=14,
                    foreL=-10,earL=(0,0,-14),earR=(0,0,8)),.13)),
      (23,rest(pose(chest=(-12,8,-9),head=(-7,-5,9),jaw=-18,armL=(40,8,-12),foreL=20,
                    armR=(15,-10,17),foreR=15,clothFront=14),.5)),
      (36,pose(body=(-8,18,-5,(.05,0,-.65)),chest=(-9,7,-5),head=(8,-10,8),jaw=-18,
               armL=(23,30,-17),foreL=20,handL=15,armR=(35,-15,20),foreR=20,
               legL=(38,0,8),shinL=-70,footL=35,legR=(20,0,-10),shinR=-48,footR=25,
               earL=(-6,0,-20),earR=(6,0,15),clothFront=20,clothL=(0,-12,-10))),
      (49,pose(body=(-12,43,-7,(.25,.12,-.9)),chest=(-12,10,-3),head=(13,-16,13),jaw=-22,
               armL=(28,45,-12),foreL=-12,handL=4,armR=(55,-30,18),foreR=30,handR=-18,
               legL=(50,0,12),shinL=-90,footL=35,legR=(33,0,-15),shinR=-65,footR=30,
               earL=(-10,0,-24),earR=(8,0,20),clothFront=25,clothL=(0,-18,-16),clothR=(0,12,8))),
      (63,pose(body=(-8,78,-8,(.55,.25,-1.0)),chest=(-10,7,0),head=(11,-12,18),jaw=-16,
               armL=(25,55,-10),foreL=-10,handL=3,armR=(50,-40,5),foreR=30,handR=-12,
               legL=(48,0,20),shinL=-85,footL=(15,0,-12),legR=(38,0,-20),shinR=-75,footR=25,
               earL=(-14,0,-30),earR=(12,0,24),clothFront=12,clothL=(0,-22,-16),clothR=(0,16,8))),
      (70,pose(body=(-7,74,-8,(.55,.25,-1.0)),chest=(-7,5,0),head=(9,-11,21),jaw=-14,
               armL=(24,52,-10),foreL=-8,handL=5,armR=(47,-38,5),foreR=28,handR=-10,
               legL=(46,0,20),shinL=-82,footL=(18,0,-12),legR=(35,0,-20),shinR=-70,footR=28,
               earL=(-8,0,-21),earR=(5,0,18),clothFront=8,clothL=(0,-18,-12),clothR=(0,12,6))),
      (82,pose(body=(-7,77,-8,(.55,.25,-1.0)),chest=(-8,5,0),head=(7,-10,24),jaw=-12,
               armL=(22,54,-10),foreL=-8,handL=4,armR=(45,-38,5),foreR=27,handR=-9,
               legL=(45,0,20),shinL=-80,footL=(20,0,-12),legR=(34,0,-20),shinR=-68,footR=28,
               earL=(-10,0,-24),earR=(7,0,20),clothFront=8,clothL=(0,-18,-12),clothR=(0,12,6)))],False)
    for f,p in a['death'][0]:
        if f>=63:
            # The upper paw drops forward across the body instead of staying rigidly raised.
            shoulder=rig.world(p,'armR').translation
            rig.chain(p,'armR','foreR','handR',shoulder+Vector((1.25,1.4,-1.65)),
                      (-.3,-1,.2),Euler((.52,0,.52)).to_quaternion())
            p.update(pose(legR=(22,-30,8),shinR=-28,footR=(22,0,8),fingersR=10))
        amplitude=1.8 if f<49 else 1.0 if f<70 else .35
        tail(p,f/34,amplitude)
    final=dict(a['death'][0][-1][1])
    final.update(pose(head=(6,-10,25),jaw=-11,earL=(-9,0,-23),earR=(6,0,19)))
    for i in range(1,8): final['tail'+str(i)]=(0,0,-2 if i<4 else 2,None)
    a['death'][0].extend([(102,final),(120,dict(final))])

    a['roar']=([(0,rest()),(11,rest(pose(chest=(-12,0,0),head=(-4,0,0),jaw=-10),.25)),
       (24,tail(rest(pose(chest=(8,0,0),head=(21,0,0),jaw=-33,armL=32,armR=32,
                            foreL=10,foreR=10,earL=(0,0,-17),earR=(0,0,17)),.03),1,1.3)),
       (36,rest(pose(chest=(5,0,0),head=(17,0,0),jaw=-27,armL=23,armR=23),.08)),(54,rest())],False)
    a['jump']=([(0,rest()),(7,rest(pose(chest=(-12,0,0),head=(8,0,0)),.5)),
       (13,pose(chest=(4,0,0),head=(8,0,0),legL=20,legR=20,shinL=-40,shinR=-40,
                footL=20,footR=20,armL=32,armR=32,foreL=-8,foreR=-8,clothFront=24)),
       (19,rest(pose(chest=(-13,0,0),head=(10,0,0),armL=16,armR=16),.4)),(24,rest())],False)
    a['stunned']=( [(f,tail(rest(pose(chest=(-14,0,2*sin(f/30*2*pi)),
                     head=(-9,3*sin(f/30*2*pi),-4*sin(f/30*2*pi)),jaw=-11,
                     earL=(0,0,-12),earR=(0,0,12)),.25),f/30*2*pi,.4))
                     for f in range(0,31,5)],True)
    # Shared dictionaries appear at held poses: copy before unwrapping to avoid mutating earlier keys.
    for name,(keys,loop) in list(a.items()):
        fixed=[]; previous={}
        for f,original in keys:
            p={}
            for n,v in original.items():
                values=list(v)
                if n in previous:
                    for axis in range(3): values[axis]=previous[n][axis]+(values[axis]-previous[n][axis]+180)%360-180
                p[n]=tuple(values); previous[n]=values
            fixed.append((f,p))
        a[name]=(fixed,loop)
    return a


def release_origins(joints,parts):
    rig=Rig(joints); clips=make_actions(joints,parts); result={}
    for name,frame,joint,offset in [('potion',30,'handL',(0,.95,-.25)),
                                  ('shoot',45,'head',(0,3.15,-.2))]:
        p=next(p for f,p in clips[name][0] if f==frame)
        point=rig.world(p,joint) @ Vector(offset)
        result[name]=[round(point.x,4),round(point.z,4),round(-point.y,4)]
    return result
