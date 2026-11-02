"""Original planted acting with springy antler tips, leafy overlap and a released seed."""
import math
from mathutils import Vector,Matrix,Euler
from splinter.motion import Rig,pose
def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def overlap(p,t,amp=1):
  for side,s in [('L',1),('R',-1)]:
   for n,delay,scale in [('antler',.3,.55),('antlerTip',.55,1),('antlerOuter',.8,1.35)]:p.setdefault(n+side,(amp*scale*sin(t-delay),s*amp*scale*.7*sin(t-delay-.2),s*amp*scale*.6*sin(t-delay-.1),None))
   for k in [1,2]:p.setdefault('mantle'+side+str(k),(amp*2*sin(t-k*.45),s*amp*1.4*sin(t-k*.35),s*amp*1.3*sin(t-k*.6),None))
   p.setdefault('skirt'+side,(amp*3*sin(t-.55),0,s*amp*sin(t-.6),None))
   p.setdefault('outer'+side,(p.get('fingers'+side,(9,0,0,None))[0]*.7,0,s*3,None))
  for k in [1,2]:p.setdefault('mantleBack'+str(k),(amp*2.8*sin(t-k*.45),0,amp*.8*sin(t-k*.6),None))
  p.setdefault('skirtFront',(amp*2*sin(t-.4),0,0,None));p.setdefault('skirtBack',(amp*2*sin(t-.6),0,0,None))
  return p
 def rest(extra=None,drop=.18,t=0):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-3,head=3,jaw=-2,armL=(7,0,7),armR=(7,0,-7),foreL=8,foreR=8,handL=-7,handR=-7,fingersL=10,fingersR=10,thumbL=7,thumbR=7)
  p.update(extra or {});return overlap(rig.planted(p),t,.65)
 def seq(name,keys):a[name]=([(t*30,p)for t,p in keys],False)
 idle=[]
 for i in range(33):
  q=i/32;t=q*2*pi
  idle.append((q*5.72*30,rest(pose(chest=-3+.9*sin(t),head=(3-.8*sin(t-.4),0,1.1*sin(t-.7)),jaw=-2-sin(t-.9),foreL=8+sin(t-.6),foreR=8+sin(t-.8),core=(0,0,1.5*sin(t),(0,0,.012*sin(t)))),.18-.013*sin(t),t)))
 a['idle']=(idle,True)
 for name,length,stride,drop in [('walk',1.2,.99,.53),('run',.8,1.08,.64)]:
  keys=[]
  for i in range(49):
   q=i/48;t=q*2*pi;feet={}
   for side,phase in [('L',q),('R',q+.5)]:
    phase%=1
    if phase<.6:y=stride*(1-2*phase/.6);z=0
    else:u=(phase-.6)/.4;y=-stride+2*stride*u*u*(3-2*u);z=.32*sin(pi*u)
    feet[side]=(0,y,z)
   p=pose(body=(0,0,0,(.03*sin(t),0,-drop-.02*(1-math.cos(2*t)))),chest=(-7 if name=='walk'else -13,0,-3.2*sin(t)),head=(6,0,2.4*sin(t)),jaw=-3,
    armL=-13*sin(t),armR=13*sin(t),foreL=12+4*sin(t-.4),foreR=12-4*sin(t-.4),handL=-8,handR=-8,fingersL=13,fingersR=13)
   keys.append((q*length*30,overlap(rig.planted(p,feet),t,1.5)))
  a[name]=(keys,True)
 def gesture(arm,elbow,lean,spread=25,drop=.4,t=0):
  return rest(pose(chest=lean,head=-lean*.7,jaw=-8,armL=(arm,0,spread),armR=(arm,0,-spread),foreL=elbow,foreR=elbow,handL=-18,handR=-18,fingersL=-15,fingersR=-15,thumbL=-9,thumbR=-9),drop,t)
 def strike(side,arm,fore,yaw,drop=.4):
  s=1 if side=='L'else -1;p=pose(chest=(-10,0,yaw),head=(6,0,-yaw*.6),jaw=-9)
  p.update(pose(**{'arm'+side:(arm,-s*16,s*19),'fore'+side:fore,'hand'+side:-fore*.5,'fingers'+side:-18,'thumb'+side:-13}))
  return rest(p,drop,t=yaw*.05)
 seq('attack7',[(0,rest()),(.35,strike('R',41,32,-14,.29)),(.74,strike('R',103,36,-29,.5)),(.93,strike('R',62,-12,27,.65)),(1.16,strike('R',24,9,33,.49)),(1.5,strike('R',3,17,11,.29)),(1.9,rest())])
 # Root fan: palms lower, press into the earth, then rake forward.
 seq('attack1',[(0,rest()),(.65,gesture(31,36,-10,21,.54)),(1.2,gesture(57,28,-19,29,.84)),(1.75,gesture(82,15,-21,42,.91)),
  (2.2,gesture(39,-7,-28,57,1.03)),(2.43,gesture(18,5,-24,62,.89)),(3.1,gesture(33,17,-11,43,.48)),(3.7,gesture(14,17,-4,21,.28)),(4.3,rest())])
 # Spike lift: weight shifts into the knees before both arms wrench upward.
 seq('attack2',[(0,rest()),(.7,gesture(16,49,-15,18,.68)),(1.4,gesture(32,61,-24,24,.96)),(2.1,gesture(81,44,-14,33,.76)),
  (2.5,gesture(146,12,12,45,.32)),(2.76,gesture(151,3,15,50,.28)),(3.3,gesture(117,15,7,47,.31)),(4.1,gesture(52,26,-4,29,.32)),(4.95,rest())])
 seq('attack3',[(0,rest()),(.44,strike('L',42,67,15,.28)),(.91,strike('L',109,41,28,.46)),(1.2,strike('L',127,24,32,.52)),
  (1.35,strike('L',78,-12,-26,.68)),(1.62,strike('L',44,10,-31,.48)),(2.1,strike('L',12,18,-7,.27)),(2.5,rest())])
 # Alternating lightning calls avoid holding a single static spell pose.
 seq('attack4',[(0,rest()),(.6,strike('R',52,49,-14,.35)),(1.18,strike('R',145,17,-22,.44)),(1.94,strike('R',158,4,-26,.49)),
  (2.5,strike('R',59,-6,25,.72)),(2.88,strike('L',113,31,18,.47)),(3.38,strike('L',151,7,27,.51)),(3.8,strike('L',62,-8,-24,.71)),(4.22,gesture(38,19,-12,31,.43)),(4.75,rest())])
 seq('attack5',[(0,rest()),(.55,gesture(43,63,-13,7,.53)),(1.12,gesture(76,41,-19,2,.71)),(1.55,gesture(91,24,-14,7,.73)),
  (1.8,gesture(66,-7,8,77,.34)),(2.04,gesture(43,7,11,86,.28)),(2.55,gesture(31,14,3,45,.3)),(3.25,rest())])
 storm=[(0,rest()),(.7,gesture(49,41,-7,27,.49)),(1.5,gesture(121,17,11,51,.47)),(2.2,gesture(149,9,16,59,.42))]
 for n,t in enumerate([2.7,5.3,7.9]):
  storm += [(t,gesture(93,-5,-18,69,.73,n*1.1)),(t+.45,gesture(67,19,-12,59,.56,n*1.1+.5)),(t+1.35,gesture(137,12,12,54,.41,n*1.1+1.1)),(t+1.85,gesture(149,9,16,59,.42,n*1.1+1.4))]
 storm += [(10.3,gesture(73,19,2,43,.36)),(11.45,rest())];seq('attack6',storm)
 ritual=[(0,rest()),(.6,gesture(39,53,-16,18,.69)),(1.2,gesture(106,27,8,41,.46)),(1.6,gesture(147,9,14,62,.38))]
 for i in range(7):
  t=2+i*.65;q=i/6*2*pi
  ritual.append((t,gesture(133+8*sin(q),13+4*sin(q-.4),9+3*sin(q-.3),57+7*sin(q-.6),.43+.03*sin(q),q)))
 ritual += [(6.6,gesture(155,3,18,54,.36)),(7.2,gesture(78,-9,-24,73,.85)),(7.55,gesture(43,14,-15,61,.53)),(8.4,rest())];seq('attack8',ritual)
 seq('spawn',[(0,rest(pose(chest=-27,head=-15,armL=23,armR=17),1.1)),(.6,rest(pose(chest=-19,head=-9,armL=31,armR=27),.85)),
  (1.25,gesture(59,39,-5,35,.59)),(2.05,gesture(94,19,9,54,.25)),(2.63,gesture(47,17,5,42,.22)),(3.2,rest())])
 seq('spawn_cancelled',[(0,gesture(133,12,12,54,.41)),(.21,rest(pose(chest=(12,0,-8),head=(17,0,10),jaw=-17,armL=72,armR=61,foreL=26,foreR=31),.58)),
  (.53,rest(pose(chest=(-22,0,5),head=9,armL=37,armR=31,foreL=19,foreR=22),.84)),(.86,rest(pose(chest=-11,head=7,armL=18,armR=21),.43)),(1.2,rest())])
 seq('hurt',[(0,rest()),(.11,rest(pose(chest=(11,0,-9),head=(16,0,12),jaw=-14),.33)),(.24,rest(pose(chest=(-11,0,6),head=-4),.4)),(.45,rest())])
 a['stun']=([(i/12*.9*30,rest(pose(chest=-19+sin(i/12*2*pi),head=-12,armL=13,armR=9,foreL=15,foreR=18),.64,i/12*2*pi))for i in range(13)],True)
 seq('jump',[(0,rest()),(.22,rest(pose(chest=-21,head=13,armL=29,armR=27),.97)),(.42,pose(chest=-12,head=9,legL=32,legR=29,shinL=-57,shinR=-52,footL=24,footR=21,armL=42,armR=37,foreL=17,foreR=19)),(.7,rest(pose(chest=-24,head=16,armL=41,armR=34),1.05)),(1,rest())])
 def fallen(angle,extra=None):
  p=pose(body=(angle,0,7,(0,-.2,-1.5)),chest=3,head=-8,jaw=-13,armL=(8,0,28),armR=(11,0,-23),foreL=4,foreR=7,handL=16,handR=19,fingersL=7,fingersR=10,outerL=5,outerR=7,thumbL=4,thumbR=3,
   legL=0,legR=7,shinL=-5,shinR=-8,footL=21,footR=26,skirtFront=4,skirtBack=-2,skirtL=(0,-3,0),skirtR=(0,3,0),mantleBack1=(0,0,0,(0,.16,0)),mantleBack2=0)
  for side,s in [('L',1),('R',-1)]:
   p.update(pose(**{'mantle'+side+'1':(2,0,s*4,(0,.1,0)),'mantle'+side+'2':(-4,0,s*3),'antler'+side:(3,s*2,0),'antlerTip'+side:(-3,s*2,0),'antlerOuter'+side:(2,0,0),'toeFront'+side:-13,'toeOuter'+side:(0,s*12,0),'toeBack'+side:9}))
  p.update(extra or {});return p
 seq('death',[(0,rest()),(.4,rest(pose(chest=(14,0,-8),head=(21,0,9),jaw=-21,armL=22,armR=17),.41)),(.93,rest(pose(chest=(-22,0,8),head=-7,armL=53,armR=43,foreL=51,foreR=57),.78)),
  (1.55,rest(pose(chest=(-26,0,-9),head=-11,armL=61,armR=51,foreL=34,foreR=42),1.44)),(2.02,fallen(23,pose(legL=47,legR=34,shinL=-86,shinR=-71,armL=43,armR=32,head=12))),
  (2.55,fallen(61,pose(legL=23,legR=17,shinL=-34,shinR=-29,armL=26,armR=19,head=6))),(3.07,fallen(88)),(3.34,fallen(82,pose(head=3,chest=-4))),
  (3.8,fallen(89,pose(head=-9))),(4.4,fallen(89,pose(head=-11,jaw=-8))),(5.2,fallen(89,pose(head=-11,jaw=-7))),(6.2,fallen(89,pose(head=-11,jaw=-7)))])
 for f,p in a['death'][0]:
  if f>=3.07*30:
   surface=(rig.world(p,'chest')@Vector((0,-1.1,.7))).z
   for side,s in [('L',1),('R',-1)]:
    shoulder=rig.world(p,'arm'+side).translation
    rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*1.15,shoulder.y+2.15,surface+.5),(s,0,-.4),Euler((pi/2,0,0)).to_quaternion())
    p.update(pose(**{'fingers'+side:2,'outer'+side:3,'thumb'+side:2}))
 # A released seed rises briefly, then rolls to the ground; still part of a single stable rig.
 start=rig.world(a['death'][0][3][1],'core');end=Vector((2.5,1.1,.64))
 for f,p in a['death'][0]:
  if f>=46.5:
   u=min(1,(f-46.5)/(132-46.5));smooth=u*u*(3-2*u)
   point=start.translation.lerp(end,smooth)+Vector((0,0,1.8*sin(pi*u)))
   world=Matrix.Translation(point)@start.to_quaternion().to_matrix().to_4x4()@Euler((u*4,u*2.8,u*3)).to_matrix().to_4x4()
   local=rig.world(p,'chest').inverted()@world;bind=rig.points['core']-rig.points['chest']
   p['core']=tuple(math.degrees(v)for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
 return a
