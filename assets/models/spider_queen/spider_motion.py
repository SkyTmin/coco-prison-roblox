"""Original eight-leg IK, alternating support groups and progressive collapse."""
import math
from mathutils import Vector,Euler,Quaternion
from splinter.motion import Rig,pose

def make_actions(joints):
 rig=Rig(joints);a={};pi=math.pi;sin=math.sin
 def planted(p,feet=None):
  for side,s in [('L',1),('R',-1)]:
   for i in range(4):
    n=side+str(i);target=rig.points['foot'+n]+Vector((feet or {}).get(n,(0,0,0)))
    rig.chain(p,'leg'+n,'shin'+n,'foot'+n,target,(s*2,0,4))
  return p
 def rest(extra=None,feet=None,drop=0):
  p=pose(body=(0,0,0,(0,0,-drop)),abdomen=0,head=0,palpL=-3,palpR=-3,palpTipL=3,palpTipR=3,
   jawL=(0,0,-3),jawR=(0,0,3),fangL=3,fangR=3)
  p.update(extra or {});return planted(p,feet)
 def secondary(p,t,amp=1):
  for side,s in [('L',1),('R',-1)]:
   p.setdefault('palp'+side,(amp*3*sin(t-s*.5),0,s*amp*3*sin(t-.4),None))
   p.setdefault('palpTip'+side,(amp*5*sin(t-.6-s*.3),0,0,None))
   p.setdefault('spinner'+side,(amp*2*sin(t-.7),0,s*amp*3*sin(t-.9),None))
  return p
 idle=[]
 for i in range(25):
  t=i/24*2*pi
  p=rest(pose(body=(.35*sin(t),0,.45*sin(t),(0,0,.025*sin(t))),abdomen=(1.1*sin(t-.5),0,.35*sin(t-.7)),head=(-.6*sin(t-.8),0,.9*sin(t-.4)),
   palpL=2*sin(t-.6),palpR=2*sin(t-.9),palpTipL=4*sin(t-.9),palpTipR=4*sin(t-1.2)))
  idle.append((i/24*90,secondary(p,t,.7)))
 a['idle']=(idle,True)
 for name,length,stride,stance,lift in [('walk',1.2,1.5,.6,.65),('run',.9,1.5,.6,.8)]:
  keys=[]
  for k in range(49):
   t=k/48*2*pi;feet={}
   for side,s in [('L',1),('R',-1)]:
    for i in range(4):
     q=(k/48+(i%2)*.5+(0 if s==1 else .5))%1
     if q<stance:y=stride*(1-2*q/stance);z=0
     else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
     feet[side+str(i)]=(0,y,z)
   p=rest(pose(body=(-2,0,.7*sin(t),(0,0,.04*math.cos(2*t))),abdomen=(1.5*sin(t-.5),0,-.5*sin(t-.6)),head=(1,0,-.5*sin(t)),
    jawL=(0,0,-4),jawR=(0,0,4),palpL=5+3*sin(t-.4),palpR=5-3*sin(t-.4)),feet)
   keys.append((k/48*length*30,secondary(p,t,1.5)))
  a[name]=(keys,True)
 def bite(yaw,lean,head,jaw,drop=0):
  return rest(pose(body=(lean,0,yaw,(0,0,-drop)),abdomen=(-lean*.4,0,-yaw*.45),head=(head,0,-yaw*.4),
   jawL=(0,-jaw*.3,-jaw),jawR=(0,jaw*.3,jaw),fangL=-jaw*.5,fangR=-jaw*.5,
   palpL=(10+abs(jaw)*.3,0,8),palpR=(10+abs(jaw)*.3,0,-8),palpTipL=-15,palpTipR=-15))
 for name,sign,at in [('bite',1,.5),('bite_2',-1,.53)]:
  a[name]=([(0,rest()),(6,bite(-4*sign,3,6,16,.03)),(11,bite(-7*sign,7,15,27,.08)),
   (at*30,bite(5*sign,-7,-12,2,.19)),(21,bite(6*sign,-5,-8,-5,.12)),(30,rest())],False)
 def rear(lean,head,jaw,lift,drop=0):
  feet={}
  for side,s in [('L',1),('R',-1)]:feet[side+'0']=(s*-.3,.2,lift)
  return rest(pose(body=(lean,0,0,(0,0,-drop)),abdomen=-lean*.4,head=head,jawL=(0,0,-jaw),jawR=(0,0,jaw),
   fangL=-jaw*.4,fangR=-jaw*.4,palpL=25,palpR=25,palpTipL=-30,palpTipR=-30),feet)
 a['fangattack']=([(0,rest()),(7,rear(4,9,16,.3)),(15,rear(10,19,31,1.1,.1)),
  (21,rear(12,23,35,1.65,.15)),(24.9,rear(-10,-17,-5,0,.4)),(29,rear(-12,-14,-2,0,.35)),(36,rear(-3,-3,5,0,.12)),(43.5,rest())],False)
 # Abdomen lifts and spinnerets aim; the game launches a visible silk ball over the body.
 a['webattack']=([(0,rest()),(9,rest(pose(abdomen=-10,head=5,body=2,palpL=12,palpR=12))),
  (20,rest(pose(abdomen=-23,body=5,head=9,spinnerL=-22,spinnerR=-22,palpL=21,palpR=21))),
  (28,rest(pose(abdomen=-31,body=7,head=11,spinnerL=-36,spinnerR=-36,palpL=27,palpR=27))),
  (31.5,rest(pose(abdomen=-21,body=-4,head=-8,spinnerL=-18,spinnerR=-18,jawL=(0,0,-12),jawR=(0,0,12)),drop=.16)),
  (38,rest(pose(abdomen=-12,body=-6,head=-7,spinnerL=-8,spinnerR=-8),drop=.18)),(47,rest(pose(abdomen=3,head=3),drop=.04)),(55.5,rest())],False)
 a['broodcall']=([(0,rest()),(13,rear(5,13,17,.5)),(28,rear(8,18,26,1.15)),
  (40,rear(10,22,31,1.5)),(49.5,rear(-4,-7,9,.1,.25)),(59,rear(-3,-4,5,0,.18)),(78,rest())],False)
 a['hurt']=([(0,rest()),(4,bite(-4,5,9,13,.12)),(9,bite(3,-3,-4,6,.1)),(15,rest())],False)
 a['spawn']=([(0,rest(pose(abdomen=-4,head=-8,palpL=-8,palpR=-8),drop=.55)),
  (14,rest(pose(abdomen=4,head=9),drop=.22)),(29,rest(pose(abdomen=-3,head=7,jawL=(0,0,-13),jawR=(0,0,13)),drop=.08)),(54,rest())],False)
 a['jump']=([(0,rest()),(7,rest(pose(abdomen=-5,head=8),drop=.6)),
  (13,rest(pose(body=(3,0,0,(0,0,.25)),abdomen=-4),{side+str(i):(0,0,.7) for side in ['L','R'] for i in range(4)})),
  (20,rest(pose(head=-7),drop=.65)),(27,rest())],False)
 death=[]
 # Legs first lose support at different moments. Only later do they curl underneath the grounded body.
 for f,drop,roll,head in [(0,0,0,0),(9,.1,-2,10),(24,.45,4,-6),(44,1.05,-6,-11),(66,1.75,8,-14),(84,1.95,10,-8)]:
  feet={}
  for side,s in [('L',1),('R',-1)]:
   for i in range(4):
    phase=max(0,min(1,(f-14-i*5-(6 if s<0 else 0))/55))
    feet[side+str(i)]=(s*.6*phase,-.18*phase*(i-1.5),.04*sin(phase*pi))
  p=rest(pose(body=(-2,0,roll,(0,0,-drop)),abdomen=(4 if f<44 else -5,0,-roll*.4),head=head,
   jawL=(0,0,-10+f*.05),jawR=(0,0,10-f*.05),fangL=8,fangR=11,palpL=-12,palpR=-17,palpTipL=-16,palpTipR=-11),feet)
  death.append((f,p))
 for f,u in [(105,.45),(128,.8),(150,1),(171,1),(187.5,1)]:
  p=pose(body=(-3,1,9,(0,0,-1.95)),abdomen=(-3,0,-3),head=-11+3*u,jawL=(10*u,0,-5-12*u),jawR=(10*u,0,7+12*u),fangL=12+73*u,fangR=15+67*u,
   palpL=-17+92*u,palpR=-22+93*u,palpTipL=-23-17*u,palpTipR=-19-21*u,spinnerL=9,spinnerR=12)
  for side,s in [('L',1),('R',-1)]:
   for i in range(4):
    n=side+str(i);foot=rig.points['foot'+n];dest=Vector((s*(1.75+.18*(i%2)),foot.y*.67,.9+.15*(i%2)))
    start=foot+Vector((s*.6,-.18*(i-1.5),0))
    progress=min(1,max(0,u+(i-1.5)*.07*s));target=start.lerp(dest,progress)
    rig.chain(p,'leg'+n,'shin'+n,'foot'+n,target,(s*4,0,4*(1-progress)+.2),Euler((0,s*.6*progress,0)).to_quaternion())
  death.append((f,p))
 a['death']=(death,False)
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,p in keys:
   p=secondary(dict(p),f/11,.8 if f else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
