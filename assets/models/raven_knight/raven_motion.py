"""Original planted sword/axe choreography and staged collapse, not imported animation data."""
import math
from mathutils import Vector,Matrix,Euler
from splinter.motion import Rig,pose
def make_actions(joints,reaper=False):
 rig=Rig(joints);a={};pi=math.pi;sin=math.sin
 def rest(extra=None,drop=.35,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-3,0,-4),neck=1,head=(2,0,4),armR=(4,0,-6),foreR=8,handR=-4,
   armL=(8,0,6),foreL=13,handL=-8,fingersR=38,fingersL=10,thumbR=28,clothFront=6,tassetL=(8,-4,0),tassetR=(8,4,0))
  p.update(extra or {});return rig.planted(p,feet)
 def secondary(p,t,amp=1):
  for k in range(1,4):
   for side,s in [('',0),('L',1),('R',-1)]:p.setdefault('cape'+side+str(k),(amp*(2+k)*sin(t-k*.52+s*.25),amp*s*sin(t-.7*k),amp*s*1.4*sin(t-.8*k),None))
  for side,s in [('L',1),('R',-1)]:
   p.setdefault('shoulder'+side,(amp*.7*sin(t),amp*s*.8*sin(t-.2),0,None))
   p.setdefault('wing'+side,(amp*1.4*sin(t-.5),amp*s*2*sin(t-.7),0,None))
  p.setdefault('crest1',(amp*2*sin(t-.4),0,amp*sin(t-.6),None));p.setdefault('crest2',(amp*4*sin(t-.8),0,amp*2*sin(t-1),None))
  return p
 keys=[]
 for i in range(33):
  t=i/32*2*pi;keys.append((i/32*120,secondary(rest(pose(chest=(-3+.6*sin(t),0,-4),head=(2-.5*sin(t-.3),0,4),foreL=13+.6*sin(t-.5)),.35-.016*sin(t)),t,.5)))
 a['idle']=(keys,True)
 for name,length,stride,stance,lift,drop in [('walk',1.05,1.008,.6,.39,.65),('run',.72,1.1232,.6,.68,.9)]:
  keys=[]
  for i in range(49):
   t=i/48*2*pi;feet={}
   for side,q in [('L',i/48),('R',i/48+.5)]:
    q%=1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-8 if name=='walk'else-15,0,-4-3*sin(t)),head=(5,0,4+2*sin(t-.3)),
    armR=7-8*sin(t),foreR=11+4*sin(t-.4),armL=17+12*sin(t),foreL=20-5*sin(t-.3),
    clothFront=10+7*sin(t*2-.5),tassetL=(12+8*sin(t),-5,0),tassetR=(12-8*sin(t),5,0)),drop+.035*(1-math.cos(t*2)),feet)
   keys.append((i/48*length*30,secondary(p,t,1.4)))
  a[name]=(keys,True)
 def cut(yaw,arm,fore,drop=.55,lean=-8,hand=8):
  return rest(pose(chest=(lean,0,yaw),head=(6,0,-yaw*.6),armR=(arm,-8,-18),foreR=fore,handR=(hand,0,7),armL=(28,0,20),foreL=31,clothFront=10),drop)
 # The second cut comes from the opposite shoulder; each wind-up, contact and recovery is distinct.
 for name,sign in [('simplecombo',1),('simplecombo2',-1)]:
  first=cut(-30*sign,133,-25,.58,7,-20);contact=cut(26*sign,54,18,.77,-18,22)
  second=cut(32*sign,101,28,.6,2,-12);back=cut(-27*sign,65,-5,.75,-15,16)
  second['armR']=(89,31,46,None);back['armR']=(69,-26,-49,None)
  if sign<0:first['armR']=(98,25,42,None);contact['armR']=(67,-31,-51,None);second['armR']=(139,-7,-18,None);back['armR']=(42,-9,-20,None)
  a[name]=([(0,rest()),(9,first),(19,first),(24,contact),(29,cut(34*sign,25,24,.71,-18,20)),(34,second),(42,back),(48,cut(-31*sign,21,29,.65,-11,12)),(57,rest())],False)
 fast=[(0,rest()),(12,cut(-31,148,-29,.65,7,-22))]
 for i,contact in enumerate([36,57,78,99]):
  sign=1 if i%2==0 else-1
  wind=cut(-30*sign,132,-20,.6,4,-17);strike=cut(29*sign,52,17,.78,-19,24)
  if i%2:wind['armR']=(95,28,48,None);strike['armR']=(67,-27,-51,None)
  fast.extend([(contact-12,wind),(contact-6,wind),(contact,strike),(contact+5,cut(35*sign,26,28,.7,-14,16))])
 fast.append((130.5,rest()));a['fastcombo']=(fast,False)
 a['comboflyattack']=([(0,rest()),(12,cut(-23,58,39,.95,-23,7)),(30,cut(-31,140,-23,1.1,-16,-23)),
  (42,pose(body=(0,0,0,(0,0,.7)),chest=-12,head=8,armR=(153,-9,-16),foreR=-18,handR=-21,armL=56,foreL=29,legL=38,legR=-18,shinL=-78,shinR=-51,footL=31,footR=37,clothFront=49)),
  (57,pose(body=(0,0,0,(0,0,1.4)),chest=5,head=-4,armR=(159,-7,-12),foreR=-23,handR=-22,armL=51,foreL=22,legL=41,legR=32,shinL=-73,shinR=-67,footL=32,footR=34,clothFront=57)),
  (69,pose(body=(0,0,0,(0,0,.4)),chest=-19,head=12,armR=105,foreR=-9,handR=12,armL=38,foreL=28,legL=21,legR=14,shinL=-32,shinR=-29,footL=16,footR=18,clothFront=31)),
  (75,cut(23,32,19,1.2,-28,29)),(83,cut(29,14,34,.94,-21,19)),(101,cut(11,25,27,.57,-8,8)),(127.5,rest())],False)
 a['explosion']=([(0,rest()),(24,rest(pose(chest=-13,head=-10,armR=38,foreR=39,armL=39,foreL=51),.7)),
  (54,rest(pose(chest=-21,head=-9,armR=63,foreR=36,armL=71,foreL=49,handL=21,fingersL=-8),1.03)),
  (78,rest(pose(chest=-25,head=-13,armR=74,foreR=28,armL=81,foreL=39),1.11)),
  (90,rest(pose(chest=13,head=22,armR=(57,0,-60),foreR=-9,armL=(61,0,58),foreL=-11,handL=25,fingersL=-24,wingL=(12,-24,0),wingR=(12,24,0)),.22)),
  (103,rest(pose(chest=8,head=13,armR=(42,0,-49),foreR=5,armL=(47,0,46),foreL=4,wingL=(7,-15,0),wingR=(7,15,0)),.3)),
  (132,rest(pose(chest=-12,head=8,armR=23,foreR=23,armL=28,foreL=32),.72)),(180,rest())],False)
 a['ravencall']=([(0,rest()),(14,rest(pose(chest=(1,0,12),head=(9,0,13),armL=64,foreL=33,handL=16),.45)),
  (36,rest(pose(chest=(5,0,18),head=(19,0,-5),armL=(139,0,14),foreL=-12,handL=22,fingersL=-17,thumbL=-14),.43)),
  (48,rest(pose(chest=(2,0,15),head=(13,0,-12),armL=(148,0,13),foreL=-9,handL=25,fingersL=-22),.48)),
  (62,rest(pose(chest=(-9,0,5),head=5,armL=(87,0,25),foreL=19,handL=8),.63)),(96,rest())],False)
 a['spawn']=([(0,rest(pose(chest=-24,head=-18,armR=11,foreR=37,armL=30,foreL=42),1.17)),
  (19,rest(pose(chest=-16,head=-9,armR=17,foreR=31,armL=23,foreL=29),.87)),(39,rest(pose(chest=3,head=15,armR=23,foreR=19),.3)),(66,rest())],False)
 a['hurt']=([(0,rest()),(4,rest(pose(chest=(11,0,-13),head=(18,0,9),armL=27),.47)),(10,rest(pose(chest=(-11,0,6),head=-3),.6)),(20,rest())],False)
 a['stun']=([(0,rest(pose(chest=-20,head=-9,armR=9,foreR=26),.9)),(9,rest(pose(chest=-24,head=-15,armR=7,foreR=31),.94)),(18,rest(pose(chest=-20,head=-9,armR=9,foreR=26),.9))],True)
 a['jump']=([(0,rest()),(7,rest(pose(chest=-17,armR=25,armL=33),1)),(14,pose(chest=-10,head=7,armR=35,armL=38,foreR=31,foreL=28,legL=38,legR=38,shinL=-73,shinR=-73,footL=34,footR=34)),(23,rest(pose(chest=-21,head=11),1.1)),(31,rest())],False)
 if reaper:
  a['basicattack']=([(0,rest()),(9,cut(-25,141,-18,.6,4,-18)),(20,cut(-29,151,-24,.65,7,-21)),(27,cut(27,31,17,.84,-25,28)),(34,cut(33,14,32,.77,-21,19)),(52.5,rest())],False)
  a['chargeattack']=([(0,rest()),(15,cut(-19,132,-21,.88,-17,-18)),(27,cut(-23,143,-23,.95,-19,-20)),(43.5,cut(25,29,19,.99,-27,27)),(53,cut(29,15,33,.8,-18,15)),(76.5,rest())],False)
  a['fogcombo']=([(0,rest()),(14,cut(-31,124,-19,.64,4,-14)),(30,cut(29,47,13,.83,-19,20)),(41,cut(31,112,21,.66,4,-13)),(57,cut(-29,56,-7,.86,-20,22)),(66,cut(-34,19,28,.7,-17,16)),(90,rest())],False)
  a['summonaxe']=([(0,rest()),(11,rest(pose(chest=4,head=7,armL=73,foreL=36,handL=14),.46)),(25,rest(pose(chest=7,head=19,armL=143,foreL=-8,handL=20,fingersL=-22),.5)),(33,rest(pose(chest=-11,head=9,armL=86,foreL=4,handL=22),.75)),(61.25,rest())],False)
  a['spikesattack']=([(0,rest()),(12,cut(-17,73,35,.64,-13,11)),(31,cut(-24,159,-27,.8,8,-22)),(48,cut(21,23,15,1.13,-28,29)),(57,cut(25,14,31,.92,-21,19)),(82.5,rest())],False)
 # Loss of balance -> knee -> shoulder -> torso roll, followed by feather/hand settling.
 def down(tilt,extra=None):
  p=pose(body=(-18,tilt,0,(-.3,.1,-1.4)),chest=-17,neck=-9,head=(1,14,-7),armR=(21,-16,-18),foreR=21,armL=(44,21,17),foreL=-9,
   legL=68,legR=81,shinL=-129,shinR=-143,footL=57,footR=63,clothFront=53,tassetL=(43,-10,0),tassetR=(39,12,0))
  p.update(extra or {});return p
 death=[(0,rest()),(8,rest(pose(chest=(14,0,-10),head=(23,0,10),armR=22,armL=31),.53)),
  (18,rest(pose(chest=(-25,0,9),head=-6,armR=9,foreR=31,armL=49),1.22)),(27,down(0)),(40,down(-22)),
  (56,down(-47,pose(body=(-45,-38,7,(-.3,.4,-1.4)),chest=(-7,6,-5),legL=39,legR=25,shinL=-69,shinR=-73,armR=(3,18,-21),foreR=8))),
  (72,down(-83)),(78,down(-87)),(86,down(-82)),(106,down(-87)),(132,down(-87)),(156,down(-87))]
 for f,p in death:
  if f>=72:
   p.update(pose(body=(-85 if f==86 else-89,-7,11,(-.4,.8,-1.4)),chest=(0,2,-4),neck=(0,-5,0),head=(0,-8,0),
    legL=5,legR=-8,shinL=-12,shinR=-15,footL=10,footR=21,clothFront=3,tassetL=(2,-3,0),tassetR=(2,4,0),
    armR=(-9,13,-26),armL=(7,-13,34),foreR=12,foreL=14,handR=5,handL=-7,fingersR=-24,fingersL=-13))
   for side,s in [('L',1),('R',-1)]:
    shoulder=rig.world(p,'arm'+side).translation
    rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.65,shoulder.y-2,2.2),(s,0,.2),Euler((-pi/2,0,0)).to_quaternion())
  for k in range(1,4):
   for side,s in [('',0),('L',1),('R',-1)]:p['cape'+side+str(k)]=((5 if f<72 else 2)*sin(f/12-k*.6),s*(3 if f<72 else 1),s*2,None)
  p['crest1']=(-3 if f<78 else-7,0,0,None);p['crest2']=(-9 if f<78 else-16,0,0,None)
 start=rig.world(death[3][1],'weapon');target=Matrix.Translation(Vector((-3.2,2.2,.3))) @ Euler((pi/2,0,.2)).to_matrix().to_4x4()
 for f,p in death:
  if f>=27:
   u=min(1,(f-27)/51);u=u*u*(3-2*u)
   world=Matrix.Translation(start.translation.lerp(target.translation,u)) @ start.to_quaternion().slerp(target.to_quaternion(),u).to_matrix().to_4x4()
   local=rig.world(p,'handR').inverted() @ world;bind=rig.points['weapon']-rig.points['handR']
   p['weapon']=tuple(math.degrees(v) for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
   p['fingersR']=(-24*u,0,0,None)
 a['death']=(death,False)
 if reaper:a={k:v for k,v in a.items() if k in ['idle','walk','basicattack','chargeattack','fogcombo','summonaxe','spikesattack','spawn','hurt','death']}
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name not in ['idle','walk','run','death']:secondary(p,f/12,.75 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
