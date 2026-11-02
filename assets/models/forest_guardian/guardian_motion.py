"""Original guardian performance: grounded sweep, weighty punch, layered foliage and side fall."""
import math
from mathutils import Euler
from splinter.motion import Rig,pose

def make_actions(joints):
 rig=Rig(joints);a={};pi=math.pi
 def layers(p,t,amp=1):
  for side,s in [('L',1),('R',-1)]:
   for k in range(3):
    p.setdefault('crown'+side+str(k),(amp*1.5*math.sin(t-k*.3),s*amp*math.sin(t-k*.2),0,None))
    p.setdefault('twig'+side+str(k),(amp*3*math.sin(t-.6-k*.4),0,s*amp*2*math.sin(t-.5-k*.3),None))
    p.setdefault('finger'+side+str(k),(amp*2*math.sin(t-k*.3),0,0,None))
   for k in range(1,4):p.setdefault('vine'+side+str(k),(amp*(3+k)*math.sin(t-.5*k),0,s*amp*math.sin(t-.6*k),None))
   for k in [1,2]:p.setdefault('mantle'+side+str(k),(amp*(2+k)*math.sin(t-.5*k),s*amp*2*math.sin(t-.4*k),s*amp*math.sin(t-.5*k),None))
   p.setdefault('mantleBack'+side,(amp*3*math.sin(t-.8),s*amp*2*math.sin(t-.6),0,None))
  return p
 def rest(extra=None,drop=.68,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-5,head=4,armL=(8,0,4),armR=(5,0,-4),foreL=15,foreR=12,handL=-10,handR=-8)
  p.update(extra or {});return rig.planted(p,feet)
 a['idle']=([(i/40*45,layers(rest(pose(chest=-5+.7*math.sin(i/40*pi*2),head=4-.6*math.sin(i/40*pi*2-.3)),.68-.015*math.sin(i/40*pi*2)),i/40*pi*2,.55))for i in range(41)],True)
 keys=[];stride=1.8
 for i in range(61):
  t=i/60*2*pi;feet={}
  for side,phase in [('L',0),('R',.5)]:
   q=(i/60+phase)%1
   if q<.6:y=stride*(1-2*q/.6);z=0
   else:u=(q-.6)/.4;y=-stride+2*stride*u*u*(3-2*u);z=.48*math.sin(pi*u)
   feet[side]=(0,y,z)
  p=rest(pose(chest=(-9,0,-4*math.sin(t)),head=(7,0,3*math.sin(t)),armL=(8+20*math.sin(t),0,5),armR=(5-20*math.sin(t),0,-5),foreL=15+7*math.sin(t-.2),foreR=12-7*math.sin(t-.2)),1.1,feet)
  keys.append((i/60*45,layers(p,t,1.25)))
 a['walk']=(keys,True)
 for side,s,name in [('R',-1,'attack'),('L',1,'attack_left')]:
  keys=[]
  for t,yaw,target,drop in [(0,0,None,.68),(.35,-s*18,(s*3.6,.2,5.6),.8),(.82,-s*25,(s*3.9,-.4,6.3),.84),(1.1,s*12,(-s*.4,3.4,5.6),1.04),(1.3,s*25,(-s*1.3,2.7,5.1),1.0),(1.65,s*10,(s*2.5,1.2,4.7),.8),(2,0,None,.68)]:
   p=rest(pose(chest=(-12 if target else -5,0,yaw),head=(6,0,-yaw*.65)),drop)
   if target:rig.chain(p,'arm'+side,'fore'+side,'hand'+side,target,(s,.1,.8),Euler((-.9,0,-s*.3)).to_quaternion())
   keys.append((t*30,layers(p,t*3,1.2)))
  a[name]=(keys,False)
 keys=[]
 for t,body,target,drop in [(0,0,None,.68),(.22,15,(-3.1,-.6,7.0),.8),(.48,24,(-2.7,-.9,7.4),.85),(.72,-21,(-.5,3.65,5.6),1.1),(.86,-25,(-.3,3.5,5.1),1.02),(1.08333,0,None,.68)]:
  p=rest(pose(chest=(-5+body*.3,0,body),head=(8,0,-body*.65),armL=30 if target else 8,foreL=35 if target else 15),drop)
  if target:rig.chain(p,'armR','foreR','handR',target,(-1,0,.9),Euler((-pi/2,0,0)).to_quaternion())
  for k in range(3):p['fingerR'+str(k)]=(40 if target else 0,0,0,None)
  keys.append((t*30,layers(p,t*5,1.6)))
 a['big_punch']=(keys,False)
 keys=[]
 for t,yaw,arms,drop in [(0,0,0,.68),(.45,-27,1,.85),(1.03,-37,1,1.0),(1.5,22,2,1.1),(1.72,36,2,.95),(2.22,12,0,.8),(2.8,0,0,.68)]:
  p=rest(pose(chest=(-14 if arms else -5,0,yaw),head=(8,0,-yaw*.6)),drop)
  if arms:
   for side,s in [('L',1),('R',-1)]:rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(s*2.7,(-.6 if arms==1 else 2.0),4.2),(s,.1,.3),Euler((-.6,0,0)).to_quaternion())
  keys.append((t*30,layers(p,t*4,1.6)))
 a['root_sweep']=(keys,False)
 keys=[]
 for t,w,height,drop in [(0,0,4,.68),(.44,1,3.1,1.02),(1.1,1,3.0,1.12),(1.65,1,7.4,.74),(2.1,1,7.8,.64),(2.55,.6,6.2,.71),(3,0,4,.68)]:
  p=rest(pose(chest=-5+w*(13 if height>6 else -19),head=4+w*(11 if height>6 else -6),jaw=w*14),drop)
  if w:
   for side,s in [('L',1),('R',-1)]:rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(s*(2.6+w*.3),1.5,height),(s,0,.3),Euler((1.15 if height>6 else -.7,0,s*.4)).to_quaternion())
  keys.append((t*30,layers(p,t*4,1.6*w)))
 a['summon']=(keys,False)
 a['spawn']=([(0,rest(pose(chest=-26,head=-17,armL=29,armR=34,foreL=43,foreR=46),1.15)),(24,rest(pose(chest=-15,head=-6),.94)),(48,rest(pose(chest=7,head=12,jaw=7),.57)),(72,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(10,0,-8),head=(17,0,7),jaw=7),.8)),(12,rest(pose(chest=-14,head=-4),.87)),(21,rest())],False)
 a['stun']=([(0,rest(pose(chest=-18,head=-12),.9)),(15,rest(pose(chest=(-21,0,3),head=(-15,0,-5)),.95)),(30,rest(pose(chest=-18,head=-12),.9))],True)
 # Knees buckle, left arm braces, shoulder contacts, the torso rolls onto its side.
 down=pose(body=(-92,-18,58,(-.7,.25,-1.0)),chest=(0,0,-4),head=(0,-9,5),jaw=6,legL=11,legR=-8,shinL=-37,shinR=-22,footL=20,footR=16)
 for side,s in [('L',1),('R',-1)]:
  shoulder=rig.world(down,'arm'+side).translation
  rig.chain(down,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.8,shoulder.y-1.7,shoulder.z+.9),(s,0,.4),Euler((-pi/2,0,0)).to_quaternion())
  for k in range(3):down['finger'+side+str(k)]=(5+k*2,0,0,None)
  for k in [1,2]:down['mantle'+side+str(k)]=(0,0,s*3,None)
 down['mantleR2']=(12,0,-6,(0,-.24,0))
 keys=[(0,rest()),(9,rest(pose(chest=(13,0,-8),head=21,jaw=12),.84)),(23,rest(pose(chest=(-22,0,12),head=-13),1.15)),
  (40,pose(body=(-25,-20,10,(-.25,.15,-1.1)),chest=-17,head=-12,legL=65,legR=74,shinL=-121,shinR=-129,footL=48,footR=54,armL=49,foreL=23,armR=65,foreR=37)),
  (61,pose(body=(-61,-32,24,(-.65,.3,-1.2)),chest=-7,head=-8,legL=27,legR=35,shinL=-64,shinR=-74,footL=27,footR=31,armL=35,foreL=19,armR=44,foreR=30)),
  (82,down),(99,dict(down)),(120,dict(down)),(144,dict(down))]
 for f,p in keys:
  if f>=99:
   u=(f-99)/45;p['jaw']=(6-u*4,0,0,None)
   for side in ['L','R']:
    for k in range(3):p['finger'+side+str(k)]=(5+k*2-u*(4+k),0,0,None)
 a['death']=(keys,False)
 valid={n for n,_,_ in joints}
 for name,(keys,loop)in a.items():
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name in ['spawn','hurt','stun']:layers(p,f/12,1)
   for n in list(p):
    if n not in valid:del p[n];continue
    v=list(p[n])
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
