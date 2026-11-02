"""Original rooted gait, asymmetric claw and travelling tendril motion."""
import math
from mathutils import Vector,Euler
from splinter.motion import Rig,pose
def make_actions(joints,tendrils):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def rest(extra=None,drop=.34,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-5,0,0),neck=2,head=3,jaw=1,armL=(6,0,7),foreL=9,handL=-11,armR=(8,0,-7),foreR=13,handR=-9)
  for side in ['L','R']:
   for k in range(4):p['digit'+side+str(k)]=(10+k*3,0,0,None)
   p['thumb'+side]=(7,0,0,None)
  p.update(extra or {});return rig.planted(p,feet)
 def tails(p,t,amp=1):
  for key,(names,_) in tendrils.items():
   s=1 if key[0]=='L' else -1;tier=int(key[1])
   for k,n in enumerate(names):p.setdefault(n,(amp*(2+k)*sin(t-k*.55+tier*.7),s*amp*(3+k)*sin(t-k*.65+tier*.3),s*amp*1.5*sin(t-k*.7),None))
  return p
 keys=[]
 for i in range(33):
  t=i/32*2*pi;p=rest(pose(chest=(-5+.65*sin(t),0,.6*sin(t)),head=(3-.6*sin(t-.4),0,-.5*sin(t-.3)),foreL=9+.8*sin(t-.6)),.34-.016*sin(t))
  keys.append((i/32*120,tails(p,t,.7)))
 a['idle']=(keys,True)
 for name,length,stride,lift,drop in [('walk',1.25,1.05,.38,.64),('run',.8,1.08,.64,.9)]:
  keys=[]
  for i in range(49):
   t=i/48*2*pi;feet={}
   for side,q in [('L',i/48),('R',i/48+.5)]:
    q%=1
    if q<.6:y=stride*(1-2*q/.6);z=0
    else:u=(q-.6)/.4;y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-10 if name=='walk'else-17,0,3*sin(t)),head=(7,0,-2*sin(t-.3)),armL=10+13*sin(t),foreL=12+5*sin(t-.3),armR=15-15*sin(t),foreR=19-4*sin(t-.4)),drop+.03*(1-math.cos(2*t)),feet)
   keys.append((i/48*length*30,tails(p,t,1.5)))
  a[name]=(keys,True)
 a['attack1']=([(0,rest()),(6,rest(pose(chest=(5,0,19),head=(8,0,-13),armL=(97,17,34),foreL=39,handL=19),.51)),
  (11,rest(pose(chest=(7,0,25),head=(9,0,-16),armL=(113,18,43),foreL=29,handL=21),.58)),
  (15,rest(pose(chest=(-17,0,-23),head=(11,0,14),armL=(79,-19,-25),foreL=-4,handL=-16,armR=33,foreR=24),.83)),
  (19,rest(pose(chest=(-19,0,-31),head=(7,0,18),armL=(39,-18,-37),foreL=14,handL=-11),.73)),(25.5,rest())],False)
 a['attack2']=([(0,rest()),(18,rest(pose(chest=(8,0,-24),head=(11,0,16),armL=59,foreL=32,armR=42,foreR=27),.6)),
  (43,rest(pose(chest=(12,0,-31),head=(16,0,21),armL=(107,0,27),foreL=19,armR=(79,0,-28),foreR=23),.7)),
  (63,rest(pose(chest=(-24,0,27),head=(13,0,-19),armL=(86,0,39),foreL=-7,armR=(65,0,-33),foreR=6),1.03)),
  (74,rest(pose(chest=(-19,0,33),head=(9,0,-21),armL=43,foreL=17,armR=32,foreR=23),.86)),(96,rest(pose(chest=(-9,0,12),head=(5,0,-8)),.55)),(120,rest())],False)
 for f,p in a['attack2'][0]:
  u=sin(pi*min(1,f/90)) if f<90 else 0
  for key,(names,_) in tendrils.items():
   s=1 if key[0]=='L'else-1;tier=int(key[1])
   for k,n in enumerate(names):p[n]=(18*u*sin(f/20-k*.7),-s*(32-k*7)*u,(-44 if f<54 else 53)*u/(1+k*.3),None)
 a['flower']=([(0,rest()),(23,rest(pose(chest=-19,head=-12,armL=49,foreL=56,armR=42,foreR=63),.79)),
  (48,rest(pose(chest=-25,head=-17,armL=77,foreL=46,armR=66,foreR=52,jaw=7),1.04)),
  (69,rest(pose(chest=13,head=24,armL=(63,0,61),foreL=-8,handL=23,armR=(62,0,-58),foreR=-7,handR=19,jaw=13),.2)),
  (87,rest(pose(chest=7,head=13,armL=(46,0,48),foreL=7,armR=(43,0,-45),foreR=11,jaw=7),.34)),
  (117,rest(pose(chest=-12,head=7,armL=23,armR=24),.64)),(165,rest())],False)
 for f,p in a['flower'][0]:
  u=max(0,1-abs(f-69)/65)
  for key,(names,_) in tendrils.items():
   s=1 if key[0]=='L'else-1
   for k,n in enumerate(names):p[n]=(12*u,-s*(22+5*k)*u,s*(12 if int(key[1])==0 else-17)*u,None)
 a['clockcast']=([(0,rest()),(14,rest(pose(chest=(3,0,9),head=(9,0,-6),armL=68,foreL=36,handL=18),.45)),
  (29,rest(pose(chest=(6,0,14),head=(13,0,-10),armL=106,foreL=12,handL=22),.53)),
  (37.5,rest(pose(chest=(-10,0,-5),head=7,armL=91,foreL=-3,handL=27),.73)),(53,rest(pose(chest=-7,armL=62,foreL=21,handL=6),.58)),(81,rest())],False)
 for f,p in a['clockcast'][0]:
  for k in range(4):p['digitL'+str(k)]=(-17+4*k if f>=29 and f<=53 else 10+k*3,0,0,None)
 a['portalcast']=([(0,rest()),(17,rest(pose(chest=-14,head=-9,armL=38,foreL=49,armR=36,foreR=53),.69)),
  (34,rest(pose(chest=-21,head=-12,armL=61,foreL=34,armR=58,foreR=39),.94)),
  (45,rest(pose(chest=7,head=16,armL=(83,0,36),foreL=-4,handL=21,armR=(81,0,-34),foreR=1,handR=19),.39)),
  (65,rest(pose(chest=3,head=11,armL=(71,0,29),foreL=9,armR=(68,0,-27),foreR=13),.48)),(83,rest(pose(chest=-9,armL=35,armR=32),.63)),(105,rest())],False)
 a['spawn']=([(0,rest(pose(chest=-26,head=-17,armL=23,foreL=34,armR=18,foreR=39),1.1)),(19,rest(pose(chest=-16,head=-7),.81)),(43,rest(pose(chest=5,head=15,armL=28,armR=24),.3)),(72,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(12,0,-12),head=(19,0,9),armL=23),.53)),(12,rest(pose(chest=(-15,0,7),head=-5),.69)),(21,rest())],False)
 a['stun']=([(0,rest(pose(chest=-24,head=-13,armL=15,foreL=26),.91)),(15,rest(pose(chest=-27,head=-18,armL=11,foreL=31),.95)),(30,rest(pose(chest=-24,head=-13,armL=15,foreL=26),.91))],True)
 a['jump']=([(0,rest()),(7,rest(pose(chest=-18,armL=29,armR=31),1)),(14,pose(chest=-11,head=7,armL=39,foreL=29,armR=35,foreR=31,legL=37,legR=38,shinL=-72,shinR=-74,footL=34,footR=36)),(23,rest(pose(chest=-23,head=12),1.09)),(31,rest())],False)
 def down(tilt):return pose(body=(-19,tilt,0,(-.4,.1,-1.45)),chest=-16,neck=-8,head=(2,14,-6),armL=(43,22,17),foreL=-9,armR=(23,-17,-19),foreR=22,
  legL=69,legR=79,shinL=-131,shinR=-141,footL=59,footR=62)
 death=[(0,rest()),(8,rest(pose(chest=(15,0,-9),head=(24,0,10),armL=31,armR=24),.55)),(20,rest(pose(chest=(-25,0,10),head=-6,armL=48,foreL=29),1.21)),
  (32,down(0)),(44,down(-27)),(59,down(-54)),(74,down(-87)),(82,down(-83)),(104,down(-88)),(123,down(-88)),(141,down(-88))]
 for f,p in death:
  if f==59:p.update(pose(body=(-46,-39,7,(-.4,.5,-1.45)),chest=(-6,7,-4),legL=37,legR=24,shinL=-66,shinR=-69))
  if f>=74:
   p.update(pose(body=(-85 if f==82 else-89,-7,11,(-.4,.8,-1.45)),chest=(0,2,-3),neck=(0,-5,0),head=(0,-9,0),jaw=5,legL=5,legR=-7,shinL=-28,shinR=-25,footL=15,footR=20))
   for side,s in [('L',1),('R',-1)]:
    shoulder=rig.world(p,'arm'+side).translation
    rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.7,shoulder.y-2.1,2.6),(s,0,.2),Euler((-pi/2,0,0)).to_quaternion())
    for k in range(4):p['digit'+side+str(k)]=(-10+k*3,0,0,None)
   # Settle each tendril along the ground beside the body, rather than propping it up.
   for key,(names,points) in tendrils.items():
    s=1 if key[0]=='L'else-1;tier=int(key[1])
    for k,n in enumerate(names):
     parent=rig.world(p,rig.parents[n]);start=rig.world(p,n).translation
     direction=Vector((s*(.8-.12*tier),.3+tier*.25,(2.28-start.z)*.5 if k==0 else 0)).normalized()
     restdir=Vector(points[k+1])-Vector(points[k]);localdir=parent.to_quaternion().inverted() @ direction
     q=restdir.rotation_difference(localdir);p[n]=tuple(math.degrees(v) for v in q.to_euler('XYZ'))+(None,)
  else:tails(p,f/12,1.3)
 a['death']=(death,False)
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name not in ['idle','walk','run','death']:tails(p,f/14,.9 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
