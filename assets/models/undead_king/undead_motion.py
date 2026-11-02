"""Original necromancer acting, planted locomotion, layered cape lag and released crown."""
import math
from mathutils import Vector,Matrix,Euler
from splinter.motion import Rig,pose
def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def cloth(p,t,amp=1):
  for section,offset in [('L',.3),('C',0),('R',-.3)]:
   for k in range(1,4):p.setdefault('cape'+section+str(k),(amp*(2+k)*sin(t-k*.5+offset),amp*1.3*sin(t-k*.7+offset),amp*.8*sin(t-k*.4),None))
  for side,s in [('L',1),('R',-1)]:
   for k in range(1,3):p.setdefault('cloth'+side+str(k),(amp*2*sin(t-k*.5+s*.2),0,s*amp*sin(t-k*.6),None))
   p.setdefault('outer'+side,(p.get('fingers'+side,(8,0,0,None))[0]*.7,0,s*3,None))
  return p
 def rest(extra=None,drop=.17,feet=None,t=0):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-2,0,0),head=2,jaw=-3,armL=(5,0,9),armR=(5,0,-9),foreL=10,foreR=10,handL=-7,handR=-7,fingersL=13,fingersR=13,thumbL=8,thumbR=8)
  p.update(extra or {});return cloth(rig.planted(p,feet),t,.6)
 def seq(name,keys):a[name]=([(t*30,p)for t,p in keys],False)
 a['idle']=([(i/24*60,rest(pose(chest=(-2+.65*sin(i/24*2*pi),0,.35*sin(i/24*2*pi)),head=(2,0,.8*sin(i/24*2*pi-.6)),jaw=-3-.5*sin(i/24*2*pi-.3)),.17-.012*sin(i/24*2*pi),t=i/24*2*pi))for i in range(25)],True)
 for name,length,stride,drop in [('walk',1.2,1,.53),('run',.8,1.2,.66)]:
  keys=[]
  for i in range(49):
   q=i/48;t=q*2*pi;feet={}
   for side,phase in [('L',q),('R',q+.5)]:
    phase%=1
    if phase<.6:y=stride*(1-2*phase/.6);z=0
    else:u=(phase-.6)/.4;y=-stride+2*stride*u*u*(3-2*u);z=.34*sin(pi*u)
    feet[side]=(0,y,z)
   p=pose(body=(0,0,0,(.03*sin(t),0,-drop-.025*(1-math.cos(2*t)))),chest=(-6 if name=='walk'else -12,0,-3*sin(t)),head=(5,0,2*sin(t)),jaw=-3,
    armL=-11*sin(t),armR=11*sin(t),foreL=13+5*sin(t-.3),foreR=13-5*sin(t-.3),handL=-8,handR=-8,fingersL=16,fingersR=16)
   keys.append((q*length*30,cloth(rig.planted(p,feet),t,1.5)))
  a[name]=(keys,True)
 def strike(side,arm,fore,yaw,drop=.38):
  s=1 if side=='L'else -1
  p=pose(chest=(-8,0,yaw),head=(5,0,-yaw*.55),jaw=-8)
  p.update(pose(**{'arm'+side:(arm,-s*14,s*17),'fore'+side:fore,'hand'+side:-fore*.6,'fingers'+side:-19,'thumb'+side:-8}))
  return rest(p,drop,t=yaw*.05)
 for name,side,length,hit in [('attack','R',.7,.35),('attack2','L',.75,.38)]:
  s=1 if side=='L'else -1
  seq(name,[(0,rest()),(.15,strike(side,45,34,-s*16,.27)),(hit-.07,strike(side,98,42,-s*28,.47)),
   (hit,strike(side,56,-11,s*25,.58)),(hit+.12,strike(side,22,10,s*31,.44)),(length,rest())])
 def ritual(arms,elbows,lean,spread=35,drop=.36,t=0):
  return rest(pose(chest=lean,head=-lean*.6,jaw=-9,armL=(arms,0,spread),armR=(arms,0,-spread),foreL=elbows,foreR=elbows,
   handL=(-20,0,-14),handR=(-20,0,14),fingersL=-16,fingersR=-16,thumbL=-12,thumbR=-12),drop,t=t)
 seq('skill1',[(0,rest()),(.35,ritual(28,61,-9,22,.44)),(.7,ritual(72,38,8,39,.47)),(1.08,ritual(121,17,13,52,.53)),
  (1.4,ritual(142,9,16,58,.6)),(1.57,ritual(91,-13,-23,67,.82)),(1.9,ritual(57,14,-25,58,.66)),(2.22,ritual(22,24,-8,31,.31)),(2.5,rest())])
 seq('skill2',[(0,rest()),(.33,strike('L',46,64,12,.28)),(.69,strike('L',104,47,24,.44)),(.94,strike('L',121,33,30,.51)),
  (1.05,strike('L',73,-14,-24,.64)),(1.26,strike('L',53,7,-31,.54)),(1.63,strike('L',20,20,-9,.3)),(2,rest())])
 seq('skill3',[(0,rest()),(.13,strike('R',52,45,-19,.26)),(.29,strike('R',112,32,-26,.42)),
  (.36,strike('R',76,-11,22,.57)),(.49,strike('R',48,12,29,.43)),(.7,rest())])
 seq('swordcall',[(0,rest()),(.31,ritual(35,61,-7,16)),(.67,ritual(86,29,11,14,.45)),(.98,ritual(137,11,15,18,.52)),
  (1.15,ritual(92,-7,-18,49,.66)),(1.46,ritual(56,17,-16,53,.48)),(2,rest())])
 seq('spawn',[(0,rest(pose(head=-17,chest=-8,armL=-3,armR=-3),.35)),(.38,rest(pose(head=-9,chest=-5,foreL=23,foreR=21),.29)),
  (.85,ritual(51,37,6,39,.25)),(1.24,ritual(68,16,9,48,.2)),(1.8,rest())])
 seq('hurt',[(0,rest()),(.1,rest(pose(chest=(10,0,-8),head=(14,0,10),jaw=-12),.31)),(.22,rest(pose(chest=(-9,0,5),head=-4),.36)),(.4,rest())])
 seq('jump',[(0,rest()),(.2,rest(pose(chest=-17,head=12,armL=25,armR=23),.85)),(.4,pose(chest=-9,head=7,legL=34,legR=29,shinL=-61,shinR=-56,footL=25,footR=24,armL=39,armR=33,foreL=18,foreR=22)),(.67,rest(pose(chest=-20,head=14,armL=37,armR=31),.9)),(.9,rest())])
 def fallen(angle,drop,extra=None):
  p=pose(body=(angle,0,-10,(0,.1,-drop)),chest=-6,head=8,jaw=-16,armL=(23,5,19),armR=(17,-8,-23),foreL=11,foreR=16,handL=-15,handR=-12,fingersL=-12,fingersR=-12,outerL=-12,outerR=-12,
   legL=0,legR=-7,shinL=-7,shinR=-4,footL=-35,footR=-32)
  for section in ['L','C','R']:
   for k in range(1,4):p['cape'+section+str(k)]=(-3+k,0,0,None)
  for side in ['L','R']:
   p['cloth'+side+'1']=(-13,0,0,None);p['cloth'+side+'2']=(-6,0,0,None)
  p.update(extra or {});return p
 seq('death',[(0,rest()),(.22,rest(pose(chest=(13,0,-10),head=(22,0,12),jaw=-18,armL=23,armR=16),.35)),
  (.5,rest(pose(chest=(-23,0,11),head=(7,0,-8),armL=48,foreL=43,armR=24),.9)),
  (.88,rest(pose(chest=(-27,0,-12),head=12,armL=57,foreL=14,armR=35),1.6)),
  (1.2,fallen(-36,1.6,pose(legL=47,legR=33,shinL=-98,shinR=-79,armL=72,armR=59))),
  (1.56,fallen(-65,1.6,pose(legL=24,legR=17,shinL=-43,shinR=-32,armL=36,armR=31))),
  (1.92,fallen(-87,1.6)),(2.08,fallen(-81,1.6,pose(head=18,chest=3))),
  (2.4,fallen(-88,1.6,pose(head=5))),(2.7,fallen(-88,1.6,pose(head=3,jaw=-12))),(3,fallen(-88,1.6,pose(head=3,jaw=-12)))])
 for f,p in a['death'][0]:
  if f>=1.92*30:p.update(pose(armL=(-17,4,19),armR=(-21,-4,-23),foreL=4,foreR=6,handL=-24,handR=-21,fingersL=-18,fingersR=-16))
  if f>=1.3*30:
   u=min(1,(f/30-1.3)/1.1);u=u*u*(3-2*u)
   for section in ['L','C','R']:
    for k,offset in [(1,60),(2,-48),(3,2)]:
     n='cape'+section+str(k);v=p[n];p[n]=(v[0]+offset*u,v[1],v[2],v[3])
 # Crown slips separately, while the body and cape remain one connected ragdoll-free rig.
 death=a['death'][0];start=rig.world(death[2][1],'crown')
 target=Matrix.Translation(Vector((2.5,2.0,.25)))@Euler((pi/2,.15,.2)).to_matrix().to_4x4()
 for f,p in death:
  if f>=15:
   u=min(1,(f-15)/(49-15));u=u*u*(3-2*u)
   world=Matrix.Translation(start.translation.lerp(target.translation,u))@start.to_quaternion().slerp(target.to_quaternion(),u).to_matrix().to_4x4()
   local=rig.world(p,'head').inverted()@world;bind=rig.points['crown']-rig.points['head']
   p['crown']=tuple(math.degrees(v)for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
 return a
