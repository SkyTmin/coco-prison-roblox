"""Original articulated skeleton acting. Audited names/lengths; poses and events are ours."""
import math
from mathutils import Euler
from splinter.motion import Rig,pose

def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def rest(extra=None,drop=.25,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-8,0,0),neck=-9,head=14,jaw=-5,
   foreL=7,foreR=7,handL=-5,handR=-5,thumbL=(5,-12,0),thumbR=(5,12,0),clothFront=4,clothBack=-4)
  for side in ['L','R']:
   for i in range(3):p.update(pose(**{f'finger{side}{i}':6+i*4,f'tip{side}{i}':12+i*5}))
  p.update(extra or {});return rig.planted(p,feet)
 def secondary(p,t,amp=1):
  p.setdefault('ribsL',(amp*.6*sin(t-.4),amp*.9*sin(t-.7),0,None))
  p.setdefault('ribsR',(amp*.6*sin(t-.55),-amp*.9*sin(t-.85),0,None))
  p.setdefault('clothFront',(amp*4*sin(t-.65),0,amp*2*sin(t-.9),None))
  p.setdefault('clothBack',(-amp*3*sin(t-.8),0,-amp*2*sin(t-1),None))
  return p
 idle=[]
 for i in range(25):
  t=i/24*2*pi;p=rest(pose(chest=(-8+.7*sin(t),0,.5*sin(t)),neck=-9-.7*sin(t-.25),
   head=(14+.8*sin(t-.5),0,1.6*sin(t-.7)),jaw=-5-1.3*sin(t-.8)),.25-.02*sin(t))
  for side,phase in [('L',0),('R',.7)]:
   for k in range(3):p[f'tip{side}{k}']=(12+k*5+2*sin(t-phase-k*.4),0,0,None)
  idle.append((i*2*30/24,secondary(p,t,.5)))
 a['idle']=(idle,True)
 for name,length,stride,stance,lift,drop in [('walk',4,1.68,.6,.48,.65),('run',1.2,1.65,.55,.7,.9)]:
  keys=[]
  for i in range(49):
   t=i/48*2*pi;feet={}
   for side,q in [('L',i/48),('R',i/48+.5)]:
    q%=1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-13 if name=='walk' else -24,0,-4*sin(t)),neck=-9,head=(18,0,3*sin(t-.25)),
    armL=-13*sin(t),armR=13*sin(t),foreL=9+5*sin(t-.3),foreR=9-5*sin(t-.3),
    handL=-8+6*sin(t-.6),handR=-8-6*sin(t-.6),jaw=-7-2*sin(t*2-.4)),drop+.045*(1-math.cos(t*2)),feet)
   for side,s in [('L',1),('R',-1)]:
    for k in range(3):p[f'tip{side}{k}']=(15+k*5+s*6*sin(t-.7-k*.2),0,0,None)
   keys.append((i/48*length*30,secondary(p,t,1.4)))
  a[name]=(keys,True)
 for side,s,name in [('R',-1,'atkrswipe'),('L',1,'atklswipe')]:
  def attack(ch,yaw,arm,fore,hand,drop,jaw=-8):
   e=pose(chest=(ch,0,s*yaw),neck=-8,head=(15,0,-s*yaw*.45),jaw=jaw)
   e.update(pose(**{'arm'+side:(arm,-s*12,-s*22),'fore'+side:fore,'hand'+side:(hand,0,s*20)}))
   for k in range(3):e[f'finger{side}{k}']=(-15+k*5,0,0,None);e[f'tip{side}{k}']=(5+k*8,0,0,None)
   return rest(e,drop)
  a[name]=([(0,rest()),(5,attack(1,-15,45,-18,-20,.4)),(11,attack(4,-27,89,-28,-35,.5)),
   (15,attack(-4,-18,106,-12,-19,.53)),(17.4,attack(-18,19,74,8,24,.62,-23)),
   (21,attack(-22,30,40,19,36,.65,-18)),(28,attack(-12,11,9,15,3,.4)),(37.5,rest())],False)
 # These are claw/hand ground strikes, matching the author's description, not reused foot stomps.
 for side,s,name in [('R',-1,'sklrstomp'),('L',1,'skllstomp')]:
  e=pose(body=(-28,0,0,(0,0,-1.65)),chest=(-43,0,s*5),neck=5,head=34,jaw=-23,
   clothFront=37,clothBack=-12)
  e.update(pose(**{'arm'+('R' if side=='L' else 'L'):35,'fore'+('R' if side=='L' else 'L'):35}))
  p=rest(e,1.65)
  target=(s*2.3,3.0,.75)
  rig.chain(p,'arm'+side,'fore'+side,'hand'+side,target,(s,-.5,.4),Euler((math.radians(70),0,0)).to_quaternion())
  for k in range(3):p[f'finger{side}{k}']=(0,0,0,None);p[f'tip{side}{k}']=(8,0,0,None)
  a[name]=([(0,rest()),(8,rest(pose(chest=(3,0,-s*9),head=21,**{'arm'+side:(110,0,-s*20),'fore'+side:55}),.55)),
   (19,rest(pose(chest=(8,0,-s*15),neck=-4,head=26,**{'arm'+side:(151,0,-s*11),'fore'+side:15}),.7)),
   (27,p),(32,dict(p)),(43,rest(pose(chest=(-25,0,s*6),head=23,**{'arm'+side:53,'fore'+side:35}),.92)),
   (51,rest(pose(chest=(-16,0,s*3),head=20),.5)),(60,rest())],False)
 a['sklpoisonbreath']=([(0,rest()),(11,rest(pose(chest=(-17,0,0),neck=-18,head=8,armL=18,armR=18),.48)),
  (26,rest(pose(chest=(6,0,0),neck=4,head=26,jaw=-19,armL=(22,0,-14),armR=(22,0,14),ribsL=(0,-4,0),ribsR=(0,4,0)),.3)),
  (37,rest(pose(chest=(10,0,0),neck=8,head=29,jaw=-36,foreL=24,foreR=24,ribsL=(0,-6,0),ribsR=(0,6,0)),.3)),
  (43.5,rest(pose(chest=(-29,0,0),neck=-3,head=15,jaw=-49,armL=27,armR=27,foreL=-9,foreR=-9),.72)),
  (55,rest(pose(chest=(-31,0,0),neck=-5,head=(16,0,-8),jaw=-45,armL=22,armR=22),.74)),
  (65,rest(pose(chest=(-25,0,0),head=(18,0,9),jaw=-40),.65)),
  (77,rest(pose(chest=(-20,0,0),head=16,jaw=-22),.53)),(91,rest(pose(chest=(-11,0,0),jaw=-11),.33)),(3.5088*30,rest())],False)
 a['sklroar']=([(0,rest()),(19,rest(pose(chest=(-22,0,0),neck=-17,head=-6,armL=15,armR=15),.7)),
  (41,rest(pose(chest=(3,0,0),neck=3,head=19,armL=(81,0,-37),armR=(81,0,37),foreL=15,foreR=15,jaw=-24),.4)),
  (62,rest(pose(chest=(12,0,0),neck=14,head=27,armL=(116,0,-44),armR=(116,0,44),foreL=7,foreR=7,jaw=-46),.3)),
  (72,rest(pose(chest=(-9,0,0),neck=-2,head=19,armL=(93,0,-35),armR=(93,0,35),foreL=-5,foreR=-5,jaw=-54),.62)),
  (83,rest(pose(chest=(2,0,0),neck=5,head=(23,0,-8),armL=(101,0,-42),armR=(101,0,42),jaw=-47),.47)),
  (94,rest(pose(chest=(-6,0,0),neck=0,head=(21,0,10),armL=(83,0,-35),armR=(83,0,35),jaw=-41),.55)),
  (113,rest(pose(chest=(-13,0,0),head=20,armL=55,armR=55,foreL=27,foreR=27,jaw=-20),.6)),
  (132,rest(pose(chest=(-10,0,0),armL=17,armR=17,foreL=16,foreR=16),.35)),(150,rest())],False)
 def kneel(extra=None):
  p=pose(body=(-10,0,0,(0,.2,-1.6)),chest=(-27,0,0),neck=-4,head=16,jaw=-19,
   armL=36,armR=56,foreL=8,foreR=-18,handL=13,handR=-8,legL=71,legR=76,
   shinL=-126,shinR=-132,footL=55,footR=56,clothFront=50,clothBack=-10)
  p.update(extra or {});return p
 death=[(0,rest()),(8,rest(pose(chest=(9,0,-7),neck=9,head=(28,0,10),jaw=-30,armL=27,armR=34),.46)),
  (21,rest(pose(chest=(-21,0,9),neck=-10,head=(-5,0,-10),armL=44,foreL=38,armR=32),1.0)),
  (37,kneel()),(49,kneel(pose(chest=(-38,0,5),neck=-12,head=2,armR=78,foreR=-31,handR=20))),
  (62,kneel(pose(body=(-13,-23,0,(-.2,.45,-1.6)),chest=(-29,0,-5),head=(8,9,12),armL=(29,28,-13),armR=(61,-24,13),foreR=-8))),
  (80,kneel(pose(body=(-11,-56,0,(-.6,.5,-1.6)),chest=(-22,0,-6),neck=-9,head=(6,16,19),armL=(24,40,-14),armR=(34,-48,18),foreR=20))),
  (96,kneel(pose(body=(-12,-87,0,(-1,.6,-1.5)),chest=(-16,0,-4),neck=-12,head=(2,23,27),armL=(18,45,-15),armR=(17,-49,15),foreR=31,jaw=-26))),
  (105,kneel(pose(body=(-11,-80,0,(-1,.6,-1.5)),chest=(-13,0,-4),neck=-11,head=(6,21,25),armL=(17,40,-14),armR=(18,-45,15),foreR=28,jaw=-16))),
  (121,kneel(pose(body=(-11,-84,0,(-1,.6,-1.5)),chest=(-18,0,-4),neck=-14,head=(-4,24,31),armL=(14,41,-14),armR=(15,-47,15),foreR=30,jaw=-7)))]
 final=dict(death[-1][1]);death += [(137,dict(final)),(5.008*30,dict(final))]
 for f,p in death:
  if f>=80:
   u=min(1,(f-80)/41);u=u*u*(3-2*u)
   neck=list(p['neck']);neck[1]=-50*u;neck[3]=(-.4*u,0,0);p['neck']=tuple(neck)
   head=list(p['head']);head[1]=head[1]*(1-u)-35*u;p['head']=tuple(head)
  for side,delay in [('L',0),('R',6)]:
   for k in range(3):
    release=min(1,max(0,(f-55-delay-k*3)/45));p[f'finger{side}{k}']=(-8*release,0,0,None);p[f'tip{side}{k}']=(8+23*release,0,0,None)
 a['death']=(death,False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(5,0,-10),neck=2,head=(24,0,14),jaw=-19),.4)),
  (13,rest(pose(chest=(-17,0,5),head=(11,0,-5)),.5)),(24,rest())],False)
 a['jump']=([(0,rest()),(7,rest(pose(chest=(-21,0,0),head=23,armL=24,armR=24),1.0)),
  (13,pose(chest=(-13,0,0),neck=-4,head=24,armL=38,armR=38,legL=35,legR=35,shinL=-65,shinR=-65,footL=30,footR=30)),
  (20,rest(pose(chest=(-26,0,0),head=26,armL=17,armR=17),1.1)),(27,rest())],False)
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,source in keys:
   p=dict(source)
   if name not in ['idle','walk','run']:secondary(p,f/10,max(0,(130-f)/55) if name=='death' else 1 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    value=list(v)
    if n in previous:
     for axis in range(3):value[axis]=previous[n][axis]+(value[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(value);previous[n]=value
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
