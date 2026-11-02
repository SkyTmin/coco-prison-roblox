"""Two-handed bow IK, flexible limbs, matching nock/string and layered cloth/hair."""
import math
from mathutils import Vector,Euler,Quaternion,Matrix
from splinter.motion import Rig,pose

def make_actions(joints):
 rig=Rig(joints);a={};pi=math.pi
 def secondary(p,t,amp=.8):
  for side,s in [('L',1),('R',-1)]:
   p.setdefault('sleeve'+side,(amp*5*math.sin(t-.5),s*amp*2,0,None))
   for k in[1,2]:p.setdefault('hair'+side+str(k),(amp*3*math.sin(t-k*.6),0,s*amp*2*math.sin(t-k*.5),None))
   for facing in['Front','Back']:p.setdefault('skirt'+facing+side,(amp*(3 if facing=='Front'else-2)*math.sin(t-s*.4),s*amp*2,0,None))
  for k in[1,2,3]:p.setdefault('hairBack'+str(k),(amp*(2+k)*math.sin(t-k*.6),0,amp*math.sin(t-k*.7),None))
  p.setdefault('ribbon',(amp*4*math.sin(t-.7),0,amp*2*math.sin(t-.6),None));return p
 def bow(p,draw=0,aim=False,high=False):
  left=Vector((.4,1.6,5.0 if high else 4.85)) if aim else Vector((1.35,.55,3.65))
  rig.chain(p,'armL','foreL','handL',left,(1,0,.1),Quaternion())
  bm=rig.world(p,'bow');nock=rig.points['arrow']-rig.points['bow']+Vector((0,-.65*draw,0))
  right=bm@nock if aim else Vector((.45,.67,4.35))
  rig.chain(p,'armR','foreR','handR',right,(-1,0,.2),Euler((0,0,-pi/2)).to_quaternion())
  p['bowUpper']=(draw*7,0,0,None);p['bowLower']=(-draw*9,0,0,None)
  p['arrow']=(0,0,0,(0,-.65*draw,0))
  for name,length,sign in[('Upper',3.9,1),('Lower',2.6,-1)]:
   rest=Vector((0,.4,sign*length-.1))
   tip=rig.world(p,'bow'+name)@Vector((0,0,sign*length))
   target=bm.inverted()@tip-nock;q=rest.rotation_difference(target)
   p['string'+name]=tuple(math.degrees(v)for v in q.to_euler('XYZ'))+((0,-.65*draw,0),)
  p['fingersL']=(28,0,0,None);p['fingersR']=(32 if aim else 8,0,0,None)
  return p
 def rest(extra=None,drop=.27,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=-3,head=3);p.update(extra or {})
  rig.planted(p,feet);return bow(p)
 keys=[]
 for i in range(33):
  t=i/32*2*pi;keys.append((i/32*100.8,secondary(rest(pose(chest=-3+.5*math.sin(t),head=3-.4*math.sin(t-.4)),.27-.012*math.sin(t)),t,.5)))
 a['idle']=(keys,True)
 keys=[]
 for i in range(41):
  feet={};t=i/40*2*pi
  for side,phase in [('L',0),('R',.5)]:
   q=(i/40+phase)%1
   if q<.6:y=.75*(1-2*q/.6);z=0
   else:u=(q-.6)/.4;y=-.75+1.5*u*u*(3-2*u);z=.24*math.sin(pi*u)
   feet[side]=(0,y,z)
  p=rest(pose(chest=(-5,0,2*math.sin(t)),head=(4,0,-2*math.sin(t))),.46,feet)
  keys.append((i/40*30,secondary(p,t,1.1)))
 a['walk']=(keys,True)
 def shot(length,release,high=False):
  keys=[]
  for f,draw,aim,drop in[(0,0,False,.27),(release*30*.3,.1,True,.31),(release*30*.65,.7,True,.38),(release*30-3,1,True,.4),
   (release*30,0,True,.35),(release*30+5,.07,True,.32),(length*30*.87,0,False,.29),(length*30,0,False,.27)]:
   p=pose(body=(0,0,0,(0,0,-drop)),chest=(-3 if not high else 7,0,-9 if aim else 0),head=(3 if not high else 12,0,5 if aim else 0))
   rig.planted(p);bow(p,draw,aim,high);keys.append((f,secondary(p,f/14,1)))
  return keys,False
 for name,length,release,high in[('bowshot',3,1.5,False),('fan',3.68,1.68,False),('rain',4.56,2.24,True),('spear',2.92,1.35,False)]:a[name]=shot(length,release,high)
 a['spawn']=([(0,rest(pose(chest=-21,head=-14),.73)),(23,rest(pose(chest=-12,head=-5),.51)),(58,rest(pose(chest=4,head=12),.22)),(97.2,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(12,0,-9),head=(17,0,7)),.41)),(12,rest(pose(chest=-12,head=-3),.49)),(21,rest())],False)
 down=pose(body=(-88,-7,9,(-.18,.35,-1.0)),chest=(0,2,-3),head=(0,-9,0),legL=5,legR=-7,shinL=-24,shinR=-25,footL=14,footR=19,
  armL=(5,-12,33),armR=(-9,15,-29),foreL=13,foreR=11)
 for side,s in[('L',1),('R',-1)]:
  shoulder=rig.world(down,'arm'+side).translation
  rig.chain(down,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.45,shoulder.y-1.38,1.9 if side=='R' else 1.7),(s,0,.2),Euler((-pi/2,0,0)).to_quaternion())
  down['sleeve'+side]=(0,0,0,None)
  for facing in['Front','Back']:down['skirt'+facing+side]=(-9 if facing=='Front'else 2,s*2,0,None)
  for k in[1,2]:down['hair'+side+str(k)]=(2,0,s*2,None)
 for k in[1,2,3]:down['hairBack'+str(k)]=(2,0,0,None)
 down['ribbon']=(2,0,0,None)
 keys=[(0,rest()),(8,rest(pose(chest=(13,0,-8),head=(21,0,7)),.42)),(20,rest(pose(chest=-23,head=-8),.79)),
  (32,pose(body=(-23,-17,5,(0,.2,-.85)),chest=-15,head=-8,legL=63,legR=72,shinL=-121,shinR=-130,footL=50,footR=56,armL=37,foreL=27,armR=44,foreR=24)),
  (48,pose(body=(-49,-38,7,(-.1,.4,-1)),chest=-7,head=-4,legL=35,legR=23,shinL=-65,shinR=-69,armL=24,foreL=17,armR=29,foreR=21)),
  (65,down),(77,dict(down)),(98,dict(down)),(120,dict(down))]
 start=rig.world(keys[2][1],'bow');target=Matrix.Translation(Vector((2.8,1.2,.21)))@Euler((pi/2,0,.4)).to_matrix().to_4x4()
 for f,p in keys:
  if f>=20:
   u=min(1,(f-20)/55);u=u*u*(3-2*u)
   world=Matrix.Translation(start.translation.lerp(target.translation,u))@start.to_quaternion().slerp(target.to_quaternion(),u).to_matrix().to_4x4()
   local=rig.world(p,'handL').inverted()@world;bind=rig.points['bow']-rig.points['handL']
   p['bow']=tuple(math.degrees(v)for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
 a['death']=(keys,False)
 for name,(keys,loop) in a.items():
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name in ['spawn','hurt']:secondary(p,f/14,1)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
