"""Original wing overlap, planted locomotion, torso-led magic and articulated collapse."""
import math
from splinter.motion import Rig,pose
def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def overlap(p,t,amp=1,flap=0):
  for side,s in [('L',1),('R',-1)]:
   p.setdefault('wing'+side,(3+amp*2*sin(t),s*(2+amp*sin(t-.2)),s*(12+flap*sin(t)+amp*2*sin(t)),None))
   p.setdefault('wingTip'+side,(amp*3*sin(t-.5),s*amp*3*sin(t-.45),s*amp*4*sin(t-.6),None))
   p.setdefault('hind'+side,(-2+amp*2*sin(t-.35),s*amp*2*sin(t-.5),s*(16+flap*.8*sin(t-.32)),None))
   p.setdefault('hindTip'+side,(amp*3*sin(t-.7),s*amp*3*sin(t-.8),s*amp*4*sin(t-.7),None))
   p.setdefault('antenna'+side,(amp*2*sin(t-.5),s*amp*sin(t-.7),s*amp*sin(t-.3),None))
   p.setdefault('antennaTip'+side,(amp*3*sin(t-.9),0,s*amp*2*sin(t-.8),None))
   p.setdefault('collar'+side,(amp*1.5*sin(t-.7),0,s*amp*sin(t-.5),None))
  for k in range(1,4):p.setdefault('abdomen'+str(k),(amp*2*sin(t-k*.45),amp*sin(t-k*.5),0,None))
  return p
 def rest(extra=None,drop=.14,feet=None,t=0):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-3,0,0),head=3,jaw=-2,armL=(8,0,8),armR=(8,0,-8),foreL=14,foreR=14,handL=-8,handR=-8,fingersL=10,fingersR=10)
  p.update(extra or {});return overlap(rig.planted(p,feet),t,.7)
 def seq(name,keys):a[name]=([(t*30,p)for t,p in keys],False)
 idle=[]
 for i in range(25):
  t=i/24*2*pi;idle.append((i/24*2.5417*30,rest(pose(chest=(-3+.8*sin(t),0,.4*sin(t)),head=(3-.6*sin(t-.4),0,.6*sin(t-.3)),foreL=14+sin(t-.5),foreR=14+sin(t-.7)),.14-.015*sin(t),t=t)))
 a['idle']=(idle,True)
 for name,length,stride,stance,lift,cycles in [('walk',2.5833,1.162485,.6,.34,2),('run',1.2,.825,.55,.45,2),('strafe',1.9167,.55,.6,.23,1)]:
  keys=[]
  for i in range(97):
   q0=i/96*cycles;t=q0*2*pi;feet={}
   for side,phase in [('L',q0),('R',q0+.5)]:
    q=phase%1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(y,0,z) if name=='strafe'else (0,y,z)
   p=pose(body=(0,0,0,(.025*sin(t),0,-.48-.02*(1-math.cos(2*t)))),chest=(-9,0,-3*sin(t)),head=(6,0,2*sin(t)),
    armL=-13*sin(t),armR=13*sin(t),foreL=17+5*sin(t-.4),foreR=17-5*sin(t-.4),handL=-9,handR=-9,fingersL=12,fingersR=12)
   keys.append((i/96*length*30,overlap(rig.planted(p,feet),t,1.7,5)))
  a[name]=(keys,True)
 def strike(side,angle,elbow,yaw,drop=.3):
  s=1 if side=='L'else -1
  p=pose(chest=(-8,0,yaw),head=(6,0,-yaw*.6),jaw=-6)
  p.update(pose(**{'arm'+side:(angle,s*-12,s*20),'fore'+side:elbow,'hand'+side:-elbow*.6,'fingers'+side:-14}))
  return rest(p,drop,t=yaw*.05)
 for name,side,length,hit in [('attack1','R',.8611,.43),('attack3','L',.75,.37),('attack4','R',.75,.4)]:
  s=1 if side=='L'else -1
  seq(name,[(0,rest()),(length*.22,strike(side,44,26,-s*18)),(hit-.08,strike(side,97,44,-s*27,.44)),
   (hit,strike(side,61,-8,s*25,.54)),(hit+.1,strike(side,28,8,s*33,.45)),(length,rest())])
 def ritual(arm,elbow,chest=5,spread=35,drop=.35,t=0):
  return rest(pose(chest=chest,head=-chest*.6,armL=(arm,0,spread),armR=(arm,0,-spread),foreL=elbow,foreR=elbow,
   handL=(-15,0,-12),handR=(-15,0,12),fingersL=-12,fingersR=-12,jaw=-5),drop,t=t)
 seq('shadowlight',[(0,rest()),(.25,strike('R',53,54,-19)),(.62,strike('R',117,48,-29,.46)),(.78,strike('R',125,38,-33,.52)),
  (.91,strike('R',72,-13,24,.6)),(1.06,strike('R',52,7,31,.48)),(1.31,strike('R',23,15,8,.25)),(1.5417,rest())])
 seq('moonssight',[(0,rest()),(.28,ritual(42,57,6,16)),(.58,ritual(93,22,9,12)),(.87,ritual(103,13,13,9,.5)),
  (.98,ritual(85,-12,-13,16,.63)),(1.18,ritual(64,9,-16,23,.52)),(1.5833,rest())])
 seq('meteorrain',[(0,rest()),(.33,ritual(37,54,-6,28)),(.68,ritual(106,17,9,37,.43)),(.99,ritual(148,9,14,45,.48)),
  (1.15,ritual(108,-13,-18,57,.66)),(1.4,ritual(69,12,-21,61,.55)),(1.9167,rest())])
 seq('midnight',[(0,rest()),(.32,ritual(34,65,-7,17)),(.7,ritual(78,49,10,12,.52)),(1.03,ritual(111,20,17,15,.62)),
  (1.18,ritual(76,-7,-21,78,.7)),(1.39,ritual(53,14,-26,84,.63)),(1.76,ritual(21,24,-8,45,.32)),(2.125,rest())])
 # Root flight is authoritative on the server; local poses fold the legs and beat the wings.
 def flying(t,arms=18,elbow=21,lean=-4):
  p=pose(body=(0,0,0,(0,0,-.08+.045*sin(t*2))),chest=lean,head=-lean*.7,armL=(arms,0,25),armR=(arms,0,-25),
   foreL=elbow,foreR=elbow,handL=-12,handR=-12,fingersL=8,fingersR=8,legL=27,legR=21,shinL=-57,shinR=-49,footL=28,footR=24)
  return overlap(p,t,2,35)
 keys=[(0,rest()),(.23*30,ritual(19,29,-13,26,.65))]
 for i in range(1,41):
  t=.23+(2.5417-.23)*i/40;p=flying((t-.23)*pi*4)
  keys.append((t*30,p))
 a['startshoot']=(keys,False)
 keys=[]
 for i in range(25):
  t=i/24*1.2083;q=t/1.2083;lift=sin(pi*min(1,q/.46)) if q<.46 else 0
  p=flying(t*4*pi,35+75*lift,20+25*lift,-4+12*lift)
  if .46<=q<.75:p.update(pose(chest=-18,head=12,armL=(62,0,39),armR=(62,0,-39),foreL=-12,foreR=-12,fingersL=-18,fingersR=-18))
  keys.append((t*30,p))
 a['descendshot']=(keys,False)
 seq('descendend',[(0,flying(0)),(.12,rest(pose(chest=-17,head=12,armL=34,armR=32,foreL=14,foreR=16),.7)),(.25,rest(pose(chest=-9,head=6,armL=19,armR=16),.36)),(.4583,rest())])
 seq('stun',[(0,rest()),(.13,rest(pose(chest=(15,0,-14),head=(-14,0,12),armL=16,armR=4,foreL=-9,foreR=11),.65)),
  (.34,rest(pose(chest=(-23,0,11),head=(-18,0,-9),armL=22,armR=19),.93)),(.53,rest(pose(chest=-11,head=-8),.49)),(.75,rest())])
 seq('hurt',[(0,rest()),(.08,rest(pose(chest=(11,0,9),head=(15,0,-11),jaw=-8),.27)),(.16,rest(pose(chest=(-9,0,-5),head=-3),.28)),(.25,rest())])
 seq('spawn',[(0,rest(pose(head=-16,chest=-9,wingL=(0,0,65),wingR=(0,0,-65),hindL=(0,0,74),hindR=(0,0,-74)),.4)),
  (.5,ritual(27,34,-6,29,.32)),(1.1,ritual(78,17,9,51,.22,t=1)),(1.8,rest())])
 seq('jump',[(0,rest()),(.22,rest(pose(chest=-17,head=11,armL=29,armR=24),.8)),(.42,flying(2)),(.65,rest(pose(chest=-20,head=13,armL=35,armR=31),.78)),(.9,rest())])
 def fallen(angle,drop,extra=None):
  p=pose(body=(angle,0,-8,(0,.15,-drop)),chest=-6,head=12,jaw=-2,armL=(57,12,18),armR=(48,-12,-20),foreL=-12,foreR=-8,handL=10,handR=12,
   legL=8,legR=-7,shinL=-11,shinR=-7,footL=-13,footR=-9,abdomen1=-9,abdomen2=-12,abdomen3=-8,
   wingL=(0,-5,-76),wingR=(0,5,79),wingTipL=(0,-8,-9),wingTipR=(0,8,10),hindL=(0,4,-84),hindR=(0,-4,87),hindTipL=(0,6,-7),hindTipR=(0,-6,6),
   antennaL=(-24,0,-10),antennaR=(-20,0,12),antennaTipL=-13,antennaTipR=-17,collarL=7,collarR=5)
  p.update(extra or {});return p
 seq('death',[(0,rest()),(.18,rest(pose(chest=(13,0,-10),head=(16,0,12),armL=23,armR=12),.3)),
  (.43,rest(pose(chest=(-22,0,9),head=(7,0,-8),armL=48,foreL=31,armR=24),.94)),
  (.7,fallen(-35,1.5,pose(legL=42,legR=31,shinL=-86,shinR=-69,armL=72,armR=58))),
  (1.02,fallen(-68,1.7,pose(legL=23,legR=17,shinL=-38,shinR=-27))),
  (1.25,fallen(-87,1.7)),(1.38,fallen(-81,1.7,pose(head=21,chest=2))),
  (1.65,fallen(-88,1.7,pose(head=7,jaw=-1))),(1.85,fallen(-88,1.7,pose(head=5,jaw=0))),(2,fallen(-88,1.7,pose(head=5,jaw=0)))])
 # After impact the forearms stop bracing and the wing roots relax flat behind the torso.
 for f,p in a['death'][0]:
  if .7*30<=f<1.25*30:
   u=(f/30-.7)/.55;p.update(pose(abdomen1=10+40*u,abdomen2=8*u,abdomen3=5*u))
  if f>=1.25*30:
   u=min(1,max(0,(f/30-1.25)/.4))
   p.update(pose(armL=(-12,4,12),armR=(-18,-4,-14),foreL=0,foreR=6,handL=-32,handR=-25,
    legL=0,legR=-5,shinL=-3,shinR=-2,footL=-55,footR=-50,jaw=-35,abdomen1=50,abdomen2=8,abdomen3=5,
    fingersL=-20,fingersR=-15,antennaL=(28,0,-10),antennaR=(24,0,12),antennaTipL=13,antennaTipR=17,
    wingL=(-8,-8,-18*(1-u)),wingR=(-8,8,20*(1-u)),wingTipL=(0,-4,0),wingTipR=(0,4,0),
    hindL=(8,4,-13*(1-u)),hindR=(8,-4,15*(1-u)),hindTipL=(0,3,0),hindTipR=(0,-3,0)))
 # Endpoints remain exact; baked Blender clamped tangents carry secondary motion between keys.
 return a
