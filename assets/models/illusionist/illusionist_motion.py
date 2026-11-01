"""Original theatrical acting with planted feet, independent props and staggered cloth motion."""
import math
from mathutils import Matrix,Vector,Euler,Quaternion
from splinter.motion import Rig,pose

def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def rest(extra=None,drop=.14,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-2,0,0),head=(2,0,0),jaw=-1,
   armL=(5,0,3),armR=(3,0,-3),foreL=7,foreR=5,handL=-5,handR=-3,fingersL=12,fingersR=18,thumbL=8,thumbR=12)
  p.update(extra or {});return rig.planted(p,feet)
 def follow(p,t,amp=1):
  for side,s in [('L',1),('R',-1)]:
   for k in range(1,4):
    p.setdefault('tail'+side+str(k),(amp*(3+k*1.1)*sin(t-k*.65+s*.4),amp*s*2*sin(t-k*.7),amp*s*2*sin(t-k*.5),None))
   p.setdefault('fringe'+side,(amp*1.2*sin(t-s*.3),0,amp*s*1.3*sin(t-.5),None))
  p.setdefault('tie',(amp*2*sin(t-.7),0,amp*1.4*sin(t-.4),None))
  return p
 keys=[]
 for i in range(25):
  t=i/24*2*pi;p=rest(pose(chest=(-2+.7*sin(t),0,.35*sin(t)),head=(2-.6*sin(t-.4),0,.6*sin(t-.6)),
   foreL=7+.6*sin(t-.7),foreR=5+.4*sin(t-.8)),.14-.012*sin(t))
  keys.append((i/24*90,follow(p,t,.5)))
 a['idle']=(keys,True)
 a['notactive']=([(0,rest(pose(head=-9,armL=-3,armR=-3),.22)),(15,rest(pose(head=-9,armL=-3,armR=-3),.22))],True)
 for name,length,stride,stance,lift,drop in [('walk',1.6,1.248,.6,.28,.52),('run',.8,.99,.55,.48,.68)]:
  keys=[]
  for i in range(49):
   t=i/48*2*pi;feet={}
   for side,q in [('L',i/48),('R',i/48+.5)]:
    q%=1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-6 if name=='walk' else -14,0,-3*sin(t)),head=(5,0,2*sin(t)),armL=-17*sin(t),armR=17*sin(t),
    foreL=8+6*sin(t-.3),foreR=8-6*sin(t-.3),handL=-7,handR=-6),drop+.03*(1-math.cos(t*2)),feet)
   keys.append((i/48*length*30,follow(p,t,1.5)))
  a[name]=(keys,True)
 def strike(yaw,arm,fore,hand,drop=.35,left=25):
  return rest(pose(chest=(-7,0,yaw),head=(5,0,-yaw*.6),armR=(arm,-10,-15),foreR=fore,handR=(hand,0,-15),
   armL=(left,0,20),foreL=22,handL=-8,jaw=-6),drop)
 for name,sign,release in [('attack',1,.46),('attack2',-1,.5)]:
  a[name]=([(0,rest()),(6,strike(-18*sign,25,25,-17,.25)),(release*30-3,strike(-28*sign,78,40,-36,.44)),
   (release*30,strike(24*sign,65,-12,18,.56,40)),(21,strike(33*sign,21,13,30,.45,31)),(30,rest())],False)
 # Dagger draw-back and wrist release, followed by a separate elbow/shoulder recovery.
 a['attackdagger']=([(0,rest()),(7,strike(-10,32,32,-12)),(14,strike(-25,110,43,-38,.46,48)),
  (18,strike(-29,118,45,-42,.5,53)),(21.3,strike(17,83,-5,14,.64,33)),
  (25,strike(25,72,-2,24,.6,25)),(33,strike(9,29,13,-2,.3)),(40.2,rest())],False)
 # Left hand fans the cards across the chest, then throws with a torso-led lateral sweep.
 a['attackcards']=([(0,rest()),(10,rest(pose(chest=(0,0,12),armL=(52,10,18),foreL=55,handL=-17,head=(0,0,-8)),.24)),
  (21,rest(pose(chest=(5,0,28),armL=(95,18,-12),foreL=43,handL=(-25,0,23),armR=-12,head=(5,0,-18)),.41)),
  (27,rest(pose(chest=(6,0,34),armL=(103,22,-18),foreL=38,handL=(-36,0,31),armR=-16),.46)),
  (30.6,rest(pose(chest=(-15,0,-24),armL=(75,-22,34),foreL=-8,handL=(18,0,-27),fingersL=-23,armR=25,head=(9,0,12)),.61)),
  (39,rest(pose(chest=(-14,0,-31),armL=(56,-28,41),foreL=3,handL=(25,0,-33),fingersL=-16,armR=27),.53)),
  (49,rest(pose(chest=(-5,0,-11),armL=28,foreL=18,handL=-2),.27)),(60.18,rest())],False)
 def conjure(arms,elbows,chest,drop=.4,spread=30):
  return rest(pose(chest=chest,head=-chest*.6,jaw=-6,armL=(arms,0,spread),armR=(arms,0,-spread),
   foreL=elbows,foreR=elbows,handL=(-18,0,-12),handR=(-18,0,12),fingersL=-15,fingersR=-15),drop)
 a['attackbox']=([(0,rest()),(12,conjure(28,63,8,.38,12)),(22,conjure(56,52,12,.5,15)),
  (31,conjure(105,18,9,.58,22)),(36.3,conjure(67,-10,-22,.72,39)),
  (43,conjure(43,7,-26,.68,45)),(54,conjure(16,21,-9,.35,27)),(66,rest())],False)
 a['summonrabbits']=([(0,rest()),(17,conjure(27,56,-8,.35,18)),(32,conjure(63,49,8,.48,32)),
  (46,conjure(106,24,13,.55,48)),(57,conjure(124,10,15,.63,55)),
  (64.5,conjure(83,-7,-23,.8,65)),(72,conjure(63,5,-29,.74,63)),
  (85,conjure(27,22,-8,.35,35)),(100.5,rest())],False)
 # No immunity: a deliberate cross-step/reveal pose accompanies the card phase.
 a['phasecards']=([(0,rest()),(6,rest(pose(chest=(5,0,-24),head=(5,0,19),armL=82,armR=73,foreL=48,foreR=46),.42)),
  (13,rest(pose(chest=(-12,0,33),head=(9,0,-21),armL=(96,0,44),armR=(83,0,-51),foreL=4,foreR=8,hat=(0,0,-5,(0,0,.1))),.64)),
  (21,rest(pose(chest=(-10,0,18),head=(7,0,-12),armL=41,armR=32,foreL=20,foreR=18),.34)),(30,rest())],False)
 # Six-second ritual breath: shoulders lift, fingers work, then hands/coat settle with separate timing.
 regen=[(0,rest()),(18,conjure(38,61,-7,.3,21)),(39,conjure(77,35,7,.48,36))]
 for f in [57,75,93,111,129]:
  t=(f-39)/90*2*pi
  regen.append((f,follow(conjure(78+5*sin(t),33+4*sin(t-.4),7+2*sin(t),.48-.03*sin(t),36+3*sin(t-.6)),t,1.2)))
 regen += [(150,conjure(50,43,-8,.35,24)),(165,conjure(16,23,-6,.22,18)),(177,rest())]
 a['regeneration']=(regen,False)
 a['active']=([(0,rest(pose(head=-11,armL=-4,armR=-4),.25)),(12,rest(pose(chest=-10,head=7,armL=28,armR=14,foreL=37),.4)),
  (26,rest(pose(chest=(7,0,10),head=(8,0,-8),armL=(67,0,39),armR=(41,0,-27),foreL=18,foreR=15,hat=(0,0,-4,(0,0,.08))),.24)),
  (40,rest(pose(chest=(-4,0,-6),head=(3,0,5),armL=23,armR=14),.2)),(54,rest())],False)
 a['hurt']=([(0,rest()),(4,rest(pose(chest=(10,0,-11),head=(15,0,10),jaw=-10),.33)),
  (9,rest(pose(chest=(-9,0,5),head=(-3,0,-4)),.38)),(15,rest())],False)
 a['jump']=([(0,rest()),(7,rest(pose(chest=-20,head=12,armL=21,armR=18),.82)),
  (13,pose(chest=-10,head=7,armL=37,armR=28,foreL=17,foreR=24,legL=38,legR=30,shinL=-62,shinR=-55,footL=23,footR=24)),
  (19,rest(pose(chest=-24,head=15,armL=35,armR=27),.85)),(27,rest())],False)
 def fallen(angle,drop,extra=None):
  p=pose(body=(angle,6,-12,(0,.1,-drop)),chest=-7,head=18,jaw=-7,armL=(38,12,18),armR=(20,-13,-24),
   foreL=-22,foreR=-16,handL=12,handR=9,fingersL=-22,fingersR=-24,thumbL=-16,thumbR=-18,
   legL=4,legR=-7,shinL=-13,shinR=-9,footL=14,footR=12)
  p.update(extra or {});return p
 death=[(0,rest()),(10,rest(pose(chest=(13,0,-12),head=(20,0,13),jaw=-14,armL=18,armR=16),.34)),
  (26,rest(pose(chest=(-23,0,15),head=(7,0,-10),armL=46,foreL=55,handL=-12,armR=-7),.82)),
  (43,rest(pose(chest=(-28,0,-17),head=(11,0,17),armL=43,foreL=19,armR=(38,0,-22),foreR=10),1.38,{'R':(0,-.48,0)})),
  (62,fallen(-31,1.85,pose(legL=46,legR=30,shinL=-103,shinR=-91,armL=62,foreL=-9,armR=36))),
  (82,fallen(-58,1.9,pose(legL=20,legR=14,shinL=-55,shinR=-47,armL=71,foreL=-7,armR=62,foreR=-9))),
  (105,fallen(-86,1.5)),(118,fallen(-79,1.5,pose(head=24,chest=4))),
  (144,fallen(-87,1.5,pose(head=9,jaw=-3))), (174,fallen(-88,1.5,pose(head=6,jaw=-1))),
  (204,fallen(-88,1.5,pose(head=5,jaw=-1))), (240,fallen(-88,1.5,pose(head=5,jaw=-1)))]
 for f,p in death:
  if f>=105:
   p.update(pose(legL=4,legR=-3,shinL=-5,shinR=-3,footL=-11,footR=-8))
   for side,s in [('L',1),('R',-1)]:
    shoulder=rig.world(p,'arm'+side).translation
    rig.chain(p,'arm'+side,'fore'+side,'hand'+side,shoulder+Vector((s*.28,1.1,-.45)),(s,0,.2),Euler((-pi/2,0,0)).to_quaternion())
 # Props leave the hands/head independently, rotating and settling after the body contacts the ground.
 for joint,parent,startFrame,endFrame,target,angle in [
  ('dagger','handR',35,82,(-1.65,1.45,.12),(pi/2,0,-.55)),
  ('cards','handL',47,101,(1.3,1.8,.09),(pi/2,0,.25)),
  ('hat','head',69,132,(1.9,2.3,.91),(pi/2,0,.8))]:
  start=rig.world(next(p for f,p in reversed(death) if f<=startFrame),joint)
  end=Matrix.Translation(Vector(target)) @ Euler(angle).to_matrix().to_4x4()
  for f,p in death:
   if f>=startFrame:
    u=min(1,(f-startFrame)/(endFrame-startFrame));u=u*u*(3-2*u)
    point=start.translation.lerp(end.translation,u);point.z+=.22*sin(pi*u)
    world=Matrix.Translation(point) @ start.to_quaternion().slerp(end.to_quaternion(),u).to_matrix().to_4x4()
    local=rig.world(p,parent).inverted() @ world;bind=rig.points[joint]-rig.points[parent]
    p[joint]=tuple(math.degrees(v) for v in local.to_euler())+(tuple(local.translation-bind),)
 a['death']=(death,False)
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name not in ['idle','walk','run','notactive']:follow(p,f/12,.8 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
