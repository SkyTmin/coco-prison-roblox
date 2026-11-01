"""Our poses and timing of contacts. Only clip names/lengths come from the client audit."""
import math
from mathutils import Vector, Euler, Matrix
from splinter.motion import Rig, pose

def make_actions(joints):
 rig=Rig(joints); a={}; sin=math.sin; pi=math.pi
 def rest(extra=None,drop=.22,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-3,0,0),head=(2,0,0),jaw=-1,
   foreL=5,foreR=5,handL=-5,handR=-5,fingersL=18,fingersR=5,
   thumbL=(0,-12,0),thumbR=(0,12,0),clothFront=4,clothBack=-4)
  p.update(extra or {});return rig.planted(p,feet)
 def secondary(p,t,amp=1):
  for side,s,lag in [('L',1,0),('R',-1,.5)]:
   p.setdefault('ear'+side,(amp*5*sin(t-.6-lag),amp*3*sin(t-.8),s*amp*7*sin(t-.7-lag),None))
   p.setdefault('pauldron'+side,(amp*1.5*sin(t-.5),0,s*amp*2*sin(t-.4),None))
  p.setdefault('belly',(amp*1.4*sin(t-.4),0,amp*.7*sin(t-.8),(0,amp*.025*sin(t-.4),amp*.035*sin(t-.5))))
  p.setdefault('pouch',(amp*4*sin(t-.8),0,amp*5*sin(t-1),None))
  p.setdefault('medal',(amp*6*sin(t-.6),0,amp*3*sin(t-1),None))
  p.setdefault('tail',(amp*5*sin(t-.7),0,amp*8*sin(t-.9),None))
  p.setdefault('tailTip',(amp*8*sin(t-1),0,amp*12*sin(t-1.1),None))
  return p
 a['idle']=([(i*8.4167*30/24,secondary(rest(pose(chest=(-3+1.1*sin(i*pi/12),0,.4*sin(i*pi/12)),
  head=(2-.8*sin(i*pi/12-.2),0,2*sin(i*pi/12-.4)),jaw=-1-.7*sin(i*pi/12-.7)),.22-.03*sin(i*pi/12)),i*pi/12,.55)) for i in range(25)],True)
 for name,seconds,stride,stance,lift,drop in [('walk',2,.8,.6,.32,.47),('run',1,1.1,.55,.52,.8)]:
  keys=[]
  for i in range(41):
   t=i/40*2*pi;feet={}
   for side,q in [('L',i/40),('R',i/40+.5)]:
    q%=1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-7 if name=='walk' else -17,0,-3.5*sin(t)),head=(4,0,2*sin(t)),
    armL=-9*sin(t),armR=14*sin(t),foreL=8+3*sin(t),foreR=9-4*sin(t),
    clothFront=8+5*sin(2*t-.7),clothBack=-6-3*sin(2*t-.6)),drop+.04*(1-math.cos(t*2)),feet)
   keys.append((i/40*seconds*30,secondary(p,t,1.2)))
  a[name]=(keys,True)
 # Axe strike: hips load, wrist turns the cutting edge, impact, overshoot, then recovery.
 a['verticalatk']=([(0,rest()),(12,rest(pose(chest=(5,0,-8),armL=48,foreL=25,handL=-18),.35)),
  (27,rest(pose(chest=(8,0,-15),head=(6,0,10),armL=(138,0,-12),foreL=18,handL=-28,armR=25),.5)),
  (35,rest(pose(chest=(5,0,-18),armL=(145,0,-8),foreL=4,handL=-20),.52)),
  (40.5,rest(pose(chest=(-24,0,15),head=(8,0,-9),armL=(52,0,8),foreL=-6,handL=28,jaw=-16),.7)),
  (46,rest(pose(chest=(-29,0,20),armL=(23,0,9),foreL=5,handL=32,armR=-15),.78)),
  (60,rest(pose(chest=(-16,0,9),armL=18,foreL=18,handL=12),.5)),(76,rest(pose(armL=8),.3)),(3.0246*30,rest())],False)
 a['horizontalatk']=([(0,rest()),(15,rest(pose(chest=(3,0,-23),head=(4,0,13),armL=(55,12,-52),foreL=12,handL=(0,0,-35)),.4)),
  (31,rest(pose(chest=(2,0,-34),head=(5,0,17),armL=(68,20,-64),foreL=6,handL=(0,0,-50),armR=22),.5)),
  (42,rest(pose(chest=(-12,0,22),head=(6,0,-10),armL=(77,-16,32),foreL=14,handL=(8,0,25),armR=-18,jaw=-12),.55)),
  (49,rest(pose(chest=(-13,0,34),head=(8,0,-14),armL=(61,-20,54),foreL=25,handL=(8,0,42)),.56)),
  (67,rest(pose(chest=(-5,0,13),armL=32,foreL=15,handL=-10),.4)),(3.0303*30,rest())],False)
 a['footstomp']=([(0,rest()),(13,rest(pose(chest=(5,0,-6),armL=24,armR=33),.3,{'R':(0,.4,.75)})),
  (25,rest(pose(chest=(8,0,-9),head=(9,0,6),armL=35,armR=47,jaw=-9),.4,{'R':(0,.65,1.35)})),
  (33,rest(pose(chest=(-20,0,8),head=(11,0,-6),armL=5,armR=8,jaw=-20),.72)),
  (40,rest(pose(chest=(-13,0,3),foreL=13,foreR=16),.58)),(57,rest(pose(chest=(-5,0,0)),.34)),(75,rest())],False)
 # One complete rotating sweep, followed by a downward slam; feet pivot with the pelvis.
 spin=[]
 for f,angle,lean,arm,drop in [(0,0,-3,0,.22),(19,-25,3,28,.4),(39,-45,6,65,.6),(54,80,-5,80,.58),
  (67,225,-8,90,.52),(75,345,2,135,.6),(81,360,-25,34,.95),(88,365,-29,20,1.0),
  (106,360,-15,35,.65),(128,360,-5,10,.3),(150,360,-3,0,.22)]:
  p=rest(pose(chest=(lean,0,0),armL=(arm,0,-25),armR=(arm*.5,0,35),foreL=12,foreR=20,jaw=-10 if 39<f<100 else -1),drop)
  p['root']=(0,0,angle,None);spin.append((f,p))
 a['spinslam']=(spin,False)
 # A belly-first fall, palm brace and knee-driven recovery. Grounding preserves floor contact.
 a['bodyslam']=([(0,rest()),(18,rest(pose(chest=(8,0,0),head=(10,0,0),armL=-24,armR=-25),.45)),
  (37,rest(pose(chest=(-8,0,0),head=(14,0,0),armL=45,armR=60,foreL=14,foreR=20),.75)),
  (55,pose(body=(-28,0,0,(0,1.0,.8)),chest=(-17,0,0),head=(20,0,0),armL=58,armR=75,
   foreL=13,foreR=28,legL=20,legR=30,shinL=-50,shinR=-60,footL=30,footR=30,clothFront=-25)),
  (75,pose(body=(-78,0,0,(0,1.7,-.6)),chest=(-7,0,0),head=(22,0,0),armL=74,armR=85,foreL=-30,foreR=-40,
   handL=-15,handR=-10,legL=4,legR=12,shinL=-16,shinR=-25,footL=12,footR=13,jaw=-20,clothFront=-62)),
  (82,pose(body=(-72,0,0,(0,1.7,-.65)),chest=(-5,0,0),head=(26,0,0),armL=74,armR=80,foreL=-35,foreR=-42,
   legL=8,legR=15,shinL=-25,shinR=-28,footL=17,footR=13,clothFront=-50)),
  (104,pose(body=(-42,0,0,(0,.8,-1.1)),chest=(-19,0,0),head=(18,0,0),armL=54,armR=62,foreL=-22,foreR=-32,
   legL=62,legR=62,shinL=-112,shinR=-112,footL=50,footR=50,clothFront=38)),
  (125,rest(pose(chest=(-18,0,0),head=(13,0,0),armL=29,armR=37,foreL=14,foreR=18),1.1)),(150,rest())],False)
 # Cough / spit: belly contraction leads the chest, jaw opens at the projectile release.
 a['upchuck']=([(0,rest()),(25,rest(pose(chest=(-13,0,0),head=(-10,0,0),armR=(51,0,15),foreR=47),.4)),
  (48,rest(pose(chest=(12,0,0),head=(27,0,0),jaw=-20,armR=34,foreR=55,belly=(7,0,0,(0,-.14,0))),.3)),
  (64,rest(pose(chest=(16,0,0),head=(32,0,0),jaw=-26,armR=22,foreR=35),.3)),
  (75,rest(pose(chest=(-25,0,0),head=(8,0,0),jaw=-37,armR=12,foreR=18,belly=(-7,0,0,(0,-.22,-.08))),.65)),
  (88,rest(pose(chest=(-28,0,0),head=(12,0,0),jaw=-32,armR=8),.7)),
  (114,rest(pose(chest=(-14,0,0),head=(3,0,-7),jaw=-11,armR=25),.45)),
  (145,rest(pose(head=(2,0,5),armR=18),.3)),(6.0095*30,rest())],False)
 a['summoningchant']=([(0,rest()),(21,rest(pose(chest=(-10,0,0),head=(-10,0,0),armL=19,armR=27),.55)),
  (47,rest(pose(chest=(9,0,0),head=(20,0,0),jaw=-22,armL=(69,0,-40),armR=(86,0,45),foreL=20,foreR=25),.35)),
  (66,rest(pose(chest=(12,0,0),head=(25,0,0),jaw=-29,armL=(80,0,-49),armR=(110,0,53),foreR=5),.3)),
  (81,rest(pose(chest=(-16,0,0),head=(5,0,0),jaw=-35,armL=17,armR=(55,0,31),foreR=-15),.7)),
  (95,rest(pose(chest=(-10,0,0),head=(8,0,0),armL=18,armR=25),.45)),(4.0064*30,rest())],False)
 # Hand reaches the belt, then feeds the king; healing is visible and interruptible by damage.
 heal=[]
 for f,ch,hd,arm,fore,jaw,drop in [(0,-3,2,0,5,-1,.22),(25,-12,-12,25,40,-6,.4),(51,-4,4,75,100,-16,.35),
  (78,8,23,116,86,-29,.3),(108,11,28,123,79,-34,.27),(123,6,20,108,85,-8,.29),
  (139,4,16,85,95,-18,.3),(152,2,10,58,72,-5,.31),(173,1,6,32,35,-11,.28),(194,-3,2,12,12,-2,.25),(7.0813*30,-3,2,0,5,-1,.22)]:
  heal.append((f,rest(pose(chest=(ch,0,-3),head=(hd,0,6),armR=(arm,0,17),foreR=fore,handR=-25,jaw=jaw),drop)))
 a['healing']=(heal,False)
 charge=[(0,rest()),(19,rest(pose(chest=(6,0,0),head=(14,0,0),jaw=-18,armR=24),.4)),
  (42,rest(pose(chest=(-24,0,0),head=(-17,0,0),armL=-20,armR=-25,jaw=-10),.9)),
  (60,rest(pose(chest=(-29,0,0),head=(-12,0,0),armL=18,armR=18),.8))]
 for i in range(1,13):
  f=60+i*2.75;t=i/12*4*pi; feet={}
  for side,phase in [('L',i/6),('R',i/6+.5)]:
   q=phase%1;feet[side]=(0,1.0*math.cos(q*2*pi),.55*max(0,sin(q*2*pi)))
  charge.append((f,rest(pose(chest=(-26,0,-4*sin(t)),head=(-10,0,3*sin(t)),armL=25*sin(t),armR=-25*sin(t)),.9,feet)))
 charge += [(104,rest(pose(chest=(13,0,0),head=(21,0,0),armL=32,armR=45,jaw=-24),.6)),
  (122,rest(pose(chest=(-22,0,0),head=(-10,0,0),armL=12,armR=18),1.0)),
  (150,rest(pose(chest=(-15,0,0),head=(5,0,0),jaw=-11),.65)),
  (185,rest(pose(chest=(-8,0,0),head=(5,0,9)),.4)),(230,rest(pose(head=(3,0,-7)),.25)),(10.0059*30,rest())]
 a['charge']=(charge,False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(9,0,-9),head=(18,0,12),jaw=-16,armR=18),.45)),
  (14,rest(pose(chest=(-9,0,5),head=(-3,0,-5),foreR=18),.4)),(29,rest(pose(head=(3,0,-3)),.25)),(45,rest())],False)
 # Arrival bows under its own weight, then checks both flanks and raises the axe.
 a['spawn']=([(0,rest(pose(chest=(-18,0,0),head=(-23,0,0),armL=18,armR=27),1.2)),
  (25,rest(pose(chest=(-12,0,0),head=(-8,0,-14),armL=14,armR=20),.9)),
  (55,rest(pose(chest=(-5,0,4),head=(3,0,20),armL=12),.4)),
  (85,rest(pose(chest=(8,0,-7),head=(18,0,-5),armL=(100,0,-24),foreL=20,jaw=-18),.3)),
  (110,rest(pose(chest=(11,0,0),head=(27,0,0),armL=(125,0,-25),armR=(35,0,30),jaw=-32),.23)),
  (135,rest(pose(chest=(-13,0,5),head=(8,0,-4),armL=36,foreL=20,armR=18),.55)),(5.6667*30,rest())],False)
 def kneel(extra=None):
  p=pose(body=(-8,0,0,(0,0,-1.3)),chest=(-20,0,0),head=(10,0,0),jaw=-14,
   armL=24,armR=43,foreL=9,foreR=-12,handL=8,handR=-15,
   legL=65,legR=65,shinL=-119,shinR=-119,footL=54,footR=54,clothFront=50,clothBack=-15)
  p.update(extra or {});return p
 death=[(0,rest()),(10,rest(pose(chest=(10,0,-9),head=(23,0,13),jaw=-22,armL=15,armR=25),.4)),
  (25,rest(pose(chest=(-18,0,8),head=(-10,0,-10),armL=12,armR=34,foreR=20),.9)),
  (42,kneel()),(55,kneel(pose(chest=(-28,0,7),head=(-10,0,-7),armR=65,foreR=-33))),
  (70,kneel(pose(body=(-12,-25,0,(0,.3,-1.3)),chest=(-22,0,-6),head=(8,10,12),armL=8,armR=(48,-25,0),foreR=-10))),
  (87,kneel(pose(body=(-9,-57,0,(-.6,.45,-1.2)),chest=(-14,0,-6),head=(9,15,16),armL=(18,35,-10),armR=(30,-50,10),foreR=15))),
  (101,kneel(pose(body=(-7,-86,0,(-1,.5,-1.1)),chest=(-10,0,-5),head=(7,20,21),armL=(22,45,-10),armR=(17,-55,7),foreR=26))),
  (110,kneel(pose(body=(-7,-79,0,(-1,.5,-1.1)),chest=(-7,0,-4),head=(5,17,27),armL=(18,40,-10),armR=(16,-48,7),foreR=24))),
  (126,kneel(pose(body=(-7,-83,0,(-1,.5,-1.1)),chest=(-11,0,-4),head=(2,18,29),armL=(15,42,-10),armR=(16,-49,7),foreR=23)))]
 final=dict(death[-1][1]);final['jaw']=(-6,0,0,None);death += [(139,dict(final)),(150,dict(final))]
 # Let go: orient and place the axe in world space, independent of the settling wrist.
 for f,p in death:
  if f>=42:
   u=min(1,(f-42)/45);p['fingersL']=(-35*u,0,0,None);p['thumbL']=(0,30*u,0,None)
   parent=rig.world(p,'handL');bind=rig.points['axe']-rig.points['handL']
   start=rig.world(death[2][1],'axe');target=Matrix.Translation(Vector((4.4,2.3,.65))) @ Euler((0,pi/2,0)).to_matrix().to_4x4()
   q=start.to_quaternion().slerp(target.to_quaternion(),u)
   loc=start.translation.lerp(target.translation,u);world=Matrix.Translation(loc) @ q.to_matrix().to_4x4()
   local=parent.inverted() @ world
   p['axe']=tuple(math.degrees(v) for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
 a['death']=(death,False)
 a['jump']=([(0,rest()),(7,rest(pose(chest=(-16,0,0),armL=23,armR=28),.85)),
  (13,pose(chest=(-6,0,0),head=(8,0,0),armL=32,armR=40,legL=30,legR=30,shinL=-60,shinR=-60,footL=30,footR=30)),
  (20,rest(pose(chest=(-18,0,0),armL=18,armR=23),.9)),(24,rest())],False)
 # Keep Euler branches continuous, and bake all secondary motion into the same exported curves.
 for name,(keys,loop) in list(a.items()):
  out=[];prev={}
  for f,source in keys:
   p=dict(source)
   if name not in ['idle','walk','run']:
    amp=max(0,(135-f)/50) if name=='death' else .9 if f<keys[-1][0] else 0
    secondary(p,f/11,min(1.7,amp))
   for n,v in list(p.items()):
    values=list(v)
    if n in prev:
     for axis in range(3):values[axis]=prev[n][axis]+(values[axis]-prev[n][axis]+180)%360-180
    p[n]=tuple(values);prev[n]=values
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
