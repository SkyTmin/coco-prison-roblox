"""Original scythe performance; planted feet, world-space grip, cloth lag and a released weapon."""
import math
from mathutils import Vector,Matrix,Euler
from splinter.motion import Rig,pose
def make_actions(joints):
 rig=Rig(joints);a={};pi=math.pi;sin=math.sin
 def cloth(p,t,amp=1):
  for side,s in [('L',1),('R',-1)]:
   for k in [1,2]:
    p.setdefault('mantle'+side+str(k),(amp*(2+k)*sin(t-k*.5),s*amp*sin(t-k*.4),s*amp*sin(t-k*.6),None))
    for face,sign in [('F',1),('B',-1)]:p.setdefault('robe'+face+side+str(k),(sign*(4+amp*(2+k)*sin(t-k*.5+s*.2)),s*2,0,None))
  return p
 def rest(extra=None,drop=.62,feet=None,grip=True):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-4,head=4,armL=(9,0,7),foreL=13,handL=-6)
  p.update(extra or {});rig.planted(p,feet)
  if grip:rig.chain(p,'armR','foreR','handR',(-2.5,1.05,5.25),(-1,0,.4),Euler((.05,0,-.08)).to_quaternion())
  for k in range(3):p.setdefault('fingerR'+str(k),(38,0,0,None))
  p.setdefault('thumbR',(24,0,-12,None))
  return p
 for name,length,amp in [('idle',5.24,.6),('idle3',3.24,1)]:
  keys=[]
  for i in range(41):
   t=i/40*pi*2;p=rest(pose(chest=(-4+.6*sin(t),0,amp*2*sin(t)),head=(4-.5*sin(t-.3),0,-amp*3*sin(t-.4))),.62-.016*sin(t))
   keys.append((i/40*length*30,cloth(p,t,.6)))
  a[name]=(keys,True)
 keys=[];stride=1.968
 for i in range(97):
  phase=i/96*2;t=phase*2*pi;feet={}
  for side,offset in [('L',0),('R',.5)]:
   q=(phase+offset)%1
   if q<.6:y=stride*(1-2*q/.6);z=0
   else:u=(q-.6)/.4;y=-stride+2*stride*u*u*(3-2*u);z=.43*sin(pi*u)
   feet[side]=(0,y,z)
  p=rest(pose(chest=(-7,0,3*sin(t)),head=(5,0,-2*sin(t)),armL=9+18*sin(t),foreL=13-4*sin(t)),1.13,feet)
  for side,s in [('L',1),('R',-1)]:
   for k in [1,2]:
    p['robeF'+side+str(k)]=(max(7,12+s*24*sin(t-(k-1)*.3)),s*3,0,None)
    p['robeB'+side+str(k)]=(-max(7,12-s*22*sin(t-(k-1)*.3)),s*3,0,None)
  keys.append((i/96*98.4,cloth(p,t,1.2)))
 a['walk']=(keys,True)
 def slash(yaw,target,rotation,drop=.8,lean=-8,left=32):
  p=rest(pose(chest=(lean,0,yaw),head=(6,0,-yaw*.6),armL=(left,0,22),foreL=26),drop,grip=False)
  rig.chain(p,'armR','foreR','handR',target,(-1,.1,.7),Euler(tuple(math.radians(v)for v in rotation)).to_quaternion())
  return p
 for name,sign,length,contact in [('attack1',1,.7273,.4),('attack2',-1,.6993,.38)]:
  keys=[(0,rest()),(length*.24*30,slash(-sign*21,(-2.6,-.2,7.0),(-20,-sign*58,-sign*35),.77,5)),
   (length*.42*30,slash(-sign*26,(-2.7,-.25,7.2),(-26,-sign*65,-sign*43),.81,6)),
   (contact*30,slash(sign*22,(-.6,2.5,5.8),(-13,sign*72,sign*32),1.0,-19)),
   ((contact+.1)*30,slash(sign*30,(-.6,2.1,5.4),(-10,sign*88,sign*49),.94,-15)),(length*30,rest())]
  a[name]=(keys,False)
 keys=[]
 for t,yaw,target,rotation,drop in [(0,0,None,None,.62),(.23,-31,(-2.7,-.1,6.6),(-25,-78,-45),.87),(.43,-38,(-2.8,0,6.8),(-30,-86,-64),.91),(.67,30,(-.6,2.1,5.6),(-10,90,70),1.05),(.82,40,(-.6,1.9,5.5),(-5,112,105),.95),(1.0526,0,None,None,.62)]:
  p=slash(yaw,target,rotation,drop) if target else rest();keys.append((t*30,cloth(p,t*5,1.4)))
 a['circleattack']=(keys,False)
 a['groundattack']=([(0,rest()),(9,slash(-18,(-2.5,.05,7.7),(0,-28,-14),.84,9)),(22,slash(-22,(-2.4,.1,7.9),(0,-17,-16),.9,12)),
  (33,slash(17,(-1.2,2.6,4.6),(-72,18,12),1.13,-24)),(39,slash(22,(-1.25,2.2,4.5),(-79,22,14),1.04,-21)),(50.823,rest())],False)
 keys=[]
 for i in range(61):
  t=i/60*4.92;w=min(1,t/.9,(4.92-t)/.7);pulse=sum(math.exp(-((t-c)/.12)**2)for c in [1.4,2.1,2.8,3.5,4.2])
  p=rest(pose(chest=(-4+w*7-pulse*3,0,w*9),head=(4+w*8,0,-w*13),armL=(9+w*69-pulse*9,0,w*17),foreL=13+w*14,handL=18*w,jaw=10*w),.62+w*.11)
  for k in range(3):p['fingerL'+str(k)]=(-15*w+pulse*8,0,0,None)
  keys.append((t*30,cloth(p,t*4,1.0*w)))
 a['soul1']=(keys,False)
 a['explosion']=([(0,rest()),(12,rest(pose(chest=-19,head=-13,armL=43,foreL=45),.96)),(31,rest(pose(chest=-27,head=-18,armL=68,foreL=46,jaw=7),1.18)),
  (45,rest(pose(chest=13,head=21,armL=(88,0,37),foreL=-8,jaw=18),.5)),(51,rest(pose(chest=9,head=15,armL=(73,0,30),foreL=1),.57)),(61.8,rest())],False)
 crouch=rest(pose(chest=-29,head=-18,armL=32,foreL=45),1.2)
 a['teleportinto']=([(0,rest()),(9,rest(pose(chest=-14,head=-8,armL=21),.84)),(22,crouch),(33.813,dict(crouch))],False)
 a['teleportout']=([(0,dict(crouch)),(7,rest(pose(chest=-18,head=-8,armL=26),1.0)),(15,rest(pose(chest=7,head=13),.52)),(21.999,rest())],False)
 a['spawn']=([(0,dict(crouch)),(32,dict(crouch)),(65,rest(pose(chest=-18,head=-14,armL=27),1.02)),(95,rest(pose(chest=-8,head=-3,armL=21),.78)),(126,rest(pose(chest=6,head=14,jaw=5),.5)),(168,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(12,0,-9),head=(19,0,6)),.74)),(12,rest(pose(chest=-13,head=-4),.83)),(21,rest())],False)
 a['stun']=([(0,rest(pose(chest=-18,head=-12),.94)),(15,rest(pose(chest=(-21,0,3),head=(-15,0,-4)),1.0)),(30,rest(pose(chest=-18,head=-12),.94))],True)
 # Stage the collapse; weapon leaves the hand and settles independently as one joint subtree.
 down=pose(body=(-89,-7,11,(-.3,.7,-1.1)),chest=(0,1,-4),head=(0,-8,1),jaw=7,legL=5,legR=-7,shinL=-18,shinR=-21,footL=12,footR=18)
 for side,s in [('L',1),('R',-1)]:
  shoulder=rig.world(down,'arm'+side).translation
  rig.chain(down,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.6,shoulder.y-1.5,shoulder.z+.75),(s,0,.2),Euler((-pi/2,0,0)).to_quaternion())
  for k in range(3):down['finger'+side+str(k)]=(5+k*2,0,0,None)
  for k in [1,2]:
   down['robeF'+side+str(k)]=(2,s*2,0,(0,-.3 if k==2 else -.48,0))
   down['robeB'+side+str(k)]=(-2,s*2,0,None)
   down['mantle'+side+str(k)]=(1,s,0,(0,-.3,0))
 death=[(0,rest()),(8,rest(pose(chest=(13,0,-9),head=22,jaw=13),.8)),(18,rest(pose(chest=(-24,0,8),head=-11,armL=41),1.17)),
  (26,pose(body=(-21,-17,5,(0,.1,-1.15)),chest=-14,head=-8,legL=63,legR=72,shinL=-120,shinR=-128,footL=53,footR=57,armL=48,foreL=24,armR=32,foreR=29)),
  (43,pose(body=(-48,-28,7,(-.2,.5,-1.2)),chest=-9,head=-5,legL=32,legR=26,shinL=-66,shinR=-61,footL=28,footR=25,armL=37,foreL=20,armR=18,foreR=17)),
  (65,down),(78,dict(down)),(83,dict(down)),(102,dict(down)),(128.4,dict(down))]
 start=rig.world(death[3][1],'weapon');target=Matrix.Translation(Vector((-4.3,1.6,.3))) @ Euler((pi/2,0,.35)).to_matrix().to_4x4()
 for f,p in death:
  if 18<=f<65:
   fold=.55 if f==18 else 1 if f==26 else .8
   for side,s in [('L',1),('R',-1)]:
    p['robeF'+side+'1']=(fold*51,s*5,0,None)
    p['robeF'+side+'2']=(-fold*34,s*3,0,None)
    p['robeB'+side+'1']=(-fold*19,s*4,0,None)
    p['robeB'+side+'2']=(fold*28,s*2,0,None)
  if f>=26:
   u=min(1,(f-26)/57);u=u*u*(3-2*u)
   world=Matrix.Translation(start.translation.lerp(target.translation,u)) @ start.to_quaternion().slerp(target.to_quaternion(),u).to_matrix().to_4x4()
   local=rig.world(p,'handR').inverted() @ world;bind=rig.points['weapon']-rig.points['handR']
   p['weapon']=tuple(math.degrees(v)for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
   for k in range(3):p['fingerR'+str(k)]=(38*(1-u)+3*u,0,0,None)
  if f>=83:
   u=(f-83)/45.4;p['jaw']=(7-u*5,0,0,None)
   for k in range(3):p['fingerL'+str(k)]=(5+k*2-u*(3+k),0,0,None)
 a['death']=(death,False)
 for name,(keys,loop)in a.items():
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name not in ['idle','idle3','walk','soul1','death']:cloth(p,f/12,.9 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
