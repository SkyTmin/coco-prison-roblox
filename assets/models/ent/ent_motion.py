"""Original heavy oak motion: planted stride, hand IK, layered crown/vines and grounded fall."""
import math
from mathutils import Vector,Euler
from splinter.motion import Rig,pose

def make_actions(joints):
 rig=Rig(joints);a={};pi=math.pi
 def secondary(p,t,amp=.6):
  p.setdefault('jaw',(amp*2*math.sin(t),0,0,None))
  for k in [1,2]:p.setdefault('beard'+str(k),(amp*(2+k)*math.sin(t-k*.55),0,amp*math.sin(t-k*.4),None))
  for side,s in [('L',1),('R',-1)]:
   for k in range(3):
    p.setdefault('crown'+side+str(k),(amp*1.3*math.sin(t-.4*k),s*amp*.8*math.sin(t-.5*k),0,None))
    p.setdefault('twig'+side+str(k),(amp*3*math.sin(t-.8-k*.4),s*amp*2*math.sin(t-.5-k*.3),0,None))
   for k in range(1,4):p.setdefault('vine'+side+str(k),(amp*(3+k)*math.sin(t-k*.55),0,s*amp*1.5*math.sin(t-k*.6),None))
   for k in range(4):p.setdefault('finger'+side+str(k),(amp*3*math.sin(t-k*.2),0,0,None))
  return p
 def rest(extra=None,drop=.6,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-3,head=3,armL=(6,0,3),armR=(4,0,-3),foreL=12,foreR=10,handL=-9,handR=-7)
  p.update(extra or {});return rig.planted(p,feet)
 keys=[]
 for i in range(41):
  t=i/40*2*pi;p=rest(pose(chest=-3+.65*math.sin(t),head=3-.6*math.sin(t-.3)),.6-.014*math.sin(t))
  keys.append((i/40*60,secondary(p,t,.6)))
 a['idle']=(keys,True)
 keys=[];stride=1.265424
 for i in range(49):
  t=i/48*2*pi;feet={}
  for side,phase in [('L',0),('R',.5)]:
   q=(i/48+phase)%1
   if q<.6:y=stride*(1-2*q/.6);z=0
   else:u=(q-.6)/.4;y=-stride+2*stride*u*u*(3-2*u);z=.46*math.sin(pi*u)
   feet[side]=(0,y,z)
  p=rest(pose(chest=(-6,0,-3*math.sin(t)),head=(5,0,2*math.sin(t)),armL=(5+17*math.sin(t),0,4),armR=(5-17*math.sin(t),0,-4),foreL=13+5*math.sin(t-.2),foreR=13-5*math.sin(t-.2)),.85,feet)
  keys.append((i/48*30.864,secondary(p,t,1.25)))
 a['walk']=(keys,True)
 for side,s,length in [('R',-1,1.5292),('L',1,1.5358)]:
  keys=[];release=.92 if side=='R'else .96
  for t,yaw,target,drop in[(0,0,None,.6),(.25,-s*11,(s*3.1,-.25,5.6),.75),(.64,-s*17,(s*3.0,-.64,6.2),.8),(release,s*14,(s*1.6,3.1,5.65),.96),(release+.16,s*20,(s*1.4,3.22,5.35),1.0),(length,0,None,.6)]:
   p=rest(pose(chest=(-10 if target else-3,0,yaw),head=(7,0,-yaw*.6)),drop)
   if target:rig.chain(p,'arm'+side,'fore'+side,'hand'+side,target,(s,.1,.7),Euler((-pi/2,0,0)).to_quaternion())
   for k in range(4):p['finger'+side+str(k)]=(42 if target else 0,0,0,None)
   p['thumb'+side]=(18 if target else 0,0,s*8,None)
   keys.append((t*30,secondary(p,t*4,1.1)))
  a['rightpunch'if side=='R'else'leftpunch']=(keys,False)
 # One root foot lifts while the other bears the giant, followed by a heavy planted compression.
 keys=[]
 for t,up,drop,chest in[(0,0,.6,-3),(.42,.75,.66,6),(.95,1.6,.72,11),(1.24,1.8,.7,8),(1.35,0,1.12,-21),(1.57,0,.94,-17),(2.2931,0,.6,-3)]:
  p=rest(pose(chest=chest,head=-chest*.5,armL=24 if up else 8,armR=31 if up else 11,foreL=19,foreR=23),drop,{'R':(0,.3 if up else 0,up)})
  keys.append((t*30,secondary(p,t*4,1.6)))
 a['stomp']=(keys,False)
 keys=[]
 for t,arms,chest,drop in[(0,0,-3,.6),(.36,1,-24,1.05),(.98,1,-29,1.15),(1.5,2,9,.61),(1.76,2,14,.5),(2.4173,0,-3,.6)]:
  p=rest(pose(chest=chest,head=-chest*.4,jaw=11 if arms==2 else 0),drop)
  for side,s in [('L',1),('R',-1)]:
   if arms:rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(s*2.0,2.3,3.1 if arms==1 else 7.5),(s,0,.4),Euler((-.7 if arms==1 else 1.4,0,0)).to_quaternion())
  keys.append((t*30,secondary(p,t*4,1.5)))
 a['rise']=(keys,False)
 def shout(length,held=False):
  keys=[]
  for t,weight in[(0,0),(.4,.4),(.88,1),(1.15,1),(length-.35,.65),(length,0)]:
   p=rest(pose(chest= -3+weight*15,head=3+weight*12,jaw=weight*25,armL=(6+weight*35,0,weight*17),armR=(4+weight*31,0,-weight*17),foreL=12+weight*27,foreR=10+weight*31),.6+weight*.12)
   keys.append((t*30,secondary(p,t*4,1+weight)))
  if held:
   keys=[]
   for i in range(41):
    t=i/40*length;w=min(1,t/1.1,(length-t)/.55)
    p=rest(pose(chest=-3+w*(11+2*math.sin(t*5)),head=3+w*13,jaw=w*(21+3*math.sin(t*7)),armL=(6+w*55,0,w*31),armR=(4+w*55,0,-w*31),foreL=12+w*21,foreR=10+w*23),.6+w*.18)
    keys.append((t*30,secondary(p,t*5,1.6*w)))
  return keys,False
 a['shout']=shout(1.9355);a['leafstorm']=shout(5.2,True)
 a['spawn']=([(0,rest(pose(chest=-24,head=-18,armL=34,armR=31,foreL=47,foreR=43),1.08)),(22,rest(pose(chest=-13,head=-7),.9)),(46,rest(pose(chest=8,head=13,jaw=8),.49)),(72,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(12,0,-7),head=(18,0,6),jaw=7),.77)),(12,rest(pose(chest=-12,head=-2),.83)),(21,rest())],False)
 a['stun']=([(0,rest(pose(chest=-16,head=-13),.82)),(15,rest(pose(chest=(-18,0,3),head=(-16,0,-4)),.86)),(30,rest(pose(chest=-16,head=-13),.82))],True)
 down=pose(body=(-88,-4,5,(-.13,.35,-.8)),chest=(0,0,-3),head=(0,-7,1),jaw=6,beard1=2,beard2=3,legL=3,legR=-5,shinL=-24,shinR=-21,footL=15,footR=17)
 for side,s in [('L',1),('R',-1)]:
  shoulder=rig.world(down,'arm'+side).translation
  rig.chain(down,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.9,shoulder.y-2.3,2.8),(s,0,.5),Euler((-pi/2,0,0)).to_quaternion())
  for k in range(4):down['finger'+side+str(k)]=(3+k*2,0,0,None)
  down['thumb'+side]=(8,0,s*6,None)
  for k in range(1,4):down['vine'+side+str(k)]=(3,0,s*2,None)
  for k in range(3):down['crown'+side+str(k)]=(1,0,s*2,None);down['twig'+side+str(k)]=(2,0,s*3,None)
 keys=[(0,rest()),(8,rest(pose(chest=(14,0,-5),head=22,jaw=14),.8)),(20,rest(pose(chest=(-23,0,7),head=-12),1.1)),
  (35,pose(body=(-24,-13,7,(0,.15,-.95)),chest=-13,head=-9,legL=61,legR=73,shinL=-118,shinR=-129,footL=50,footR=53,armL=63,foreL=22,armR=42,foreR=26)),
  (53,pose(body=(-51,-28,5,(-.13,.4,-1.1)),chest=-8,head=-7,legL=31,legR=24,shinL=-61,shinR=-66,footL=23,footR=26,armL=46,foreL=17,armR=39,foreR=21)),
  (72,down),(85,dict(down)),(105,dict(down)),(132,dict(down))]
 for f,p in keys:
  if f>=85:
   u=(f-85)/47
   for k in range(4):
    for side in ['L','R']:p['finger'+side+str(k)]=(3+k*2-u*(2+k),0,0,None)
   p['jaw']=(6-u*4,0,0,None)
 a['death']=(keys,False)
 for name,(keys,loop) in a.items():
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name in ['spawn','hurt','stun']:secondary(p,f/12,1)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
