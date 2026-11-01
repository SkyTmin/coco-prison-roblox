"""Original weight, trident handling, water glides and a staged collapse. No imported curves."""
import math
from mathutils import Matrix,Vector,Euler,Quaternion
from splinter.motion import Rig,pose
def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def rest(extra=None,drop=.25,feet=None,grip=True):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-2,0,-3),head=(2,0,3),jaw=-2,armL=(5,0,7),foreL=7,
   handL=-4,fingersL=8,thumbL=(8,-18,0),thumbR=(0,24,0),clothFront=4,clothBack=-4)
  p.update(extra or {});rig.planted(p,feet)
  if grip:rig.chain(p,'armR','foreR','handR',(-3,.95,5.2),(-1,-.2,.2),Quaternion())
  return p
 def flow(p,t,amp=1):
  for k in range(1,4):
   p.setdefault('beard'+str(k),(amp*(1+k*.7)*sin(t-k*.5),amp*.5*sin(t-k*.6),amp*1.3*sin(t-k*.55),None))
   p.setdefault('hair'+str(k),(-amp*(1+k)*sin(t-k*.7),amp*.6*sin(t-k*.6),amp*sin(t-k*.8),None))
  p.setdefault('weedL',(amp*5*sin(t-.6),0,amp*3*sin(t-.8),None))
  p.setdefault('weedR',(-amp*4*sin(t-.9),0,-amp*3*sin(t-1),None))
  return p
 keys=[]
 for i in range(25):
  t=i/24*2*pi;p=rest(pose(chest=(-2+.8*sin(t),0,-3),head=(2-.7*sin(t-.4),0,3+.7*sin(t-.6)),jaw=-2-.5*sin(t),armL=5+sin(t-.4)),.25-.018*sin(t))
  keys.append((i/24*75,flow(p,t,.6)))
 a['idle']=(keys,True)
 for name,length,stride,stance,lift,drop in [('walk',1.2,1.152,.6,.38,.64),('run',1.2,1.98,.55,.7,1.18)]:
  keys=[]
  for i in range(49):
   t=i/48*2*pi;feet={}
   for side,q in [('L',i/48),('R',i/48+.5)]:
    q%=1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-7 if name=='walk' else -16,0,-3-3*sin(t)),head=(6,0,3+2*sin(t)),armL=-16*sin(t),foreL=9+7*sin(t-.4),
    fingersL=8+4*sin(t-.7),clothFront=12+6*sin(t*2-.5),clothBack=-12-7*sin(t*2-.8),clothL=(8*sin(t),-6,0),clothR=(-8*sin(t),6,0)),drop+.04*(1-math.cos(t*2)),feet)
   keys.append((i/48*length*30,flow(p,t,1.2)))
  a[name]=(keys,True)
 def attack(ch,yaw,arm,fore,hand,drop=.5,left=25):
  return rest(pose(chest=(ch,0,yaw),head=(5,0,-yaw*.55),armR=(arm,-12,-12),foreR=fore,handR=(hand,0,5),
   armL=(left,0,16),foreL=18,handL=2,fingersL=12,clothFront=7),drop,grip=False)
 for name,sign,release in [('swing',1,.48),('swing_2',-1,.51)]:
  a[name]=([(0,rest()),(8,attack(2,-sign*22,-26,17,-28,.4)),(release*30-4,attack(5,-sign*34,-43,25,-51,.6)),
   (release*30,attack(-16,sign*24,-54,34,-46,.72,45)),(21,attack(-17,sign*35,-35,24,-31,.65,33)),(30,rest())],False)
  # Trident's three points describe a lateral arc instead of a sword's downwards chop.
  for f,p in a[name][0]:
   if 0<f<30:p['armR']=(-20,-sign*35,sign*55,None);p['handR']=(-57,0,-sign*30,None)
 a['stab']=([(0,rest()),(8,attack(3,-18,-45,68,-71,.45)),(15,attack(5,-26,-51,73,-72,.55)),
  (20.4,attack(-17,17,8,6,-97,.8,40)),(25,attack(-20,22,13,2,-96,.85,38)),(32,attack(-7,8,-8,18,-35,.45)),(39,rest())],False)
 a['wave_clash']=([(0,rest()),(8,attack(2,-22,-31,20,-48,.45,44)),(15,attack(8,-34,-47,29,-67,.65,73)),
  (19.8,attack(-19,27,-22,19,-62,.8,102)),(25,attack(-21,39,-12,29,-44,.82,78)),(32,attack(-8,12,-3,15,-21,.45,36)),(39,rest())],False)
 a['epicenter']=([(0,rest()),(9,attack(3,-8,29,18,-7,.55,55)),(20,attack(11,-12,58,9,-2,.65,105)),
  (26,attack(13,-16,65,0,6,.75,126)),(30.6,attack(-25,7,-8,-9,13,1.15,45)),
  (36,attack(-23,13,-12,5,6,1.02,37)),(44,attack(-10,6,1,7,4,.55,26)),(51,rest())],False)
 for f,p in a['epicenter'][0]:
  if 30.6<=f<=36:rig.chain(p,'armR','foreR','handR',(-3,1.1,4.75),(-1,-.2,.2),Quaternion())
 # Weightless water stance still uses articulated knees, elbows and a deliberate trident aim.
 def water(t,pace=1,thrust=0):
  p=pose(body=(-70,0,0,(0,0,.25+.07*sin(t*2))),chest=(-8,0,3*sin(t)),head=(62,0,-2*sin(t)),jaw=-5,
   armR=(-18+thrust*28,0,-8),foreR=13-thrust*12,handR=-18-thrust*15,armL=(10+8*sin(t),0,18),foreL=22,
   handL=2,fingersL=18,thumbL=-12,legL=12*pace*sin(t),legR=-12*pace*sin(t),shinL=-24-12*pace*sin(t-.5),shinR=-24+12*pace*sin(t-.5),
   footL=20+9*sin(t-.9),footR=20-9*sin(t-.9),clothFront=45,clothBack=-37,clothL=(18,-11,0),clothR=(18,11,0),
   beard1=42,beard2=26,beard3=17,hair1=-23,hair2=-17,hair3=-12)
  return flow(p,t,1.4)
 for name,pace in [('swim_idle',.25),('swim',1),('torpedo',.35)]:
  a[name]=([(i/24*30,water(i/24*2*pi,pace,1 if name=='torpedo' else 0)) for i in range(25)],True)
 a['swim_attack']=([(0,water(0,.4)),(8,water(.7,.4,-.5)),(12,water(1.1,.4,-.7)),
  (16.5,water(1.6,.4,1)),(21,water(2.2,.4,1.15)),(30,water(2*pi,.4))],False)
 def seated():
  p=pose(body=(-6,0,0,(0,0,-2.1)),chest=-6,head=-12,jaw=-3,
   legL=84,legR=84,shinL=-118,shinR=-118,footL=34,footR=34,
   armL=35,foreL=49,handL=-10,armR=-8,foreR=26,handR=-18,
   clothFront=54,clothL=(32,-12,0),clothR=(32,12,0),clothBack=-14,beard1=16,beard2=-9,beard3=-8)
  rig.chain(p,'armR','foreR','handR',(-3,.95,5.2),(-1,-.2,.2),Quaternion())
  return p
 a['idle_sitting']=([(i*3.75,flow(seated(),i/24*2*pi,.45)) for i in range(25)],True)
 a['kneel']=([(0,seated()),(30,seated())],True)
 a['awaken']=([(0,seated()),(16,dict(seated(),head=(8,0,0,None))),
  (33,rest(pose(chest=-25,head=17,armL=51,foreL=12,handL=-19),1.45)),
  (51,rest(pose(chest=-17,head=16,armL=32,foreL=23),.95)),(73,rest(pose(chest=5,head=18,armL=18),.4)),(96,rest())],False)
 a['hurt']=([(0,rest()),(6,rest(pose(chest=(8,0,-9),head=(14,0,10),jaw=-10),.4)),(14,rest(pose(chest=(-10,0,6),head=-3),.5)),(24,rest())],False)
 a['jump']=([(0,rest()),(8,rest(pose(chest=-19,head=11,armL=24),1.1)),
  (16,pose(chest=-13,head=8,armR=13,foreR=25,handR=-17,armL=42,foreL=30,legL=38,legR=38,shinL=-66,shinR=-66,footL=28,footR=28)),
  (24,rest(pose(chest=-23,head=14,armL=31),1.15)),(33,rest())],False)
 def recline(angle,extra=None):
  p=pose(body=(angle,-7,8,(0,.1,-1.4)),chest=4,neck=0,head=-3,jaw=-4,
   armR=(8,16,-23),foreR=18,handR=-8,armL=(3,-18,26),foreL=22,handL=-4,
   legL=12,legR=-5,shinL=-31,shinR=-17,footL=19,footR=22,
   clothFront=-8,clothBack=-4,clothL=(3,-9,0),clothR=(1,12,0),
   beard1=-30,beard2=-20,beard3=-12,hair1=12,hair2=-9,hair3=-15,weedL=-8,weedR=-10)
  p.update(extra or {});return p
 death=[(0,rest()),(9,rest(pose(chest=(10,0,-8),head=(23,0,10),jaw=-15,armL=23),.5)),
  (22,rest(pose(chest=(-22,0,9),head=-6,jaw=-9,armL=36,foreL=28),1.15)),
  (38,dict(seated(),head=(9,0,0,None),chest=(8,0,-7,None))),
  (52,recline(28,pose(legL=62,legR=55,shinL=-108,shinR=-97,armL=(43,-18,26),foreL=-15))),
  (69,recline(61,pose(legL=28,legR=20,shinL=-64,shinR=-52,armL=(24,-18,26),head=11,jaw=-16))),
  (86,recline(89,pose(head=12,jaw=-13))),
  (96,recline(84,pose(head=6,jaw=-8))),
  (116,recline(88,pose(head=-5,jaw=-3))),
  (132,recline(88,pose(head=-7,jaw=-1))), (144,recline(88,pose(head=-7,jaw=-1)))]
 for f,p in death:
  if f>=86:
   p.update(pose(legL=4,legR=-3,shinL=-3,shinR=-4,footL=-12,footR=-9,
    head=12 if f==86 else 9 if f==96 else 6 if f==116 else 4,fingersL=-9,thumbL=(0,-12,0)))
   for side,s in [('L',1),('R',-1)]:
    shoulder=rig.world(p,'arm'+side).translation
    rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.5,shoulder.y+2,2.5),(s,0,.2),Euler((pi/2,0,0)).to_quaternion())
 start=rig.world(death[2][1],'trident');target=Matrix.Translation(Vector((-3.6,1.3,.3))) @ Euler((pi/2,0,.2)).to_matrix().to_4x4()
 for f,p in death:
  if f>=28:
   u=min(1,(f-28)/48);u=u*u*(3-2*u);p['fingersR']=(-25*u,0,0,None);p['thumbR']=(0,-25*u,0,None)
   world=Matrix.Translation(start.translation.lerp(target.translation,u)) @ start.to_quaternion().slerp(target.to_quaternion(),u).to_matrix().to_4x4()
   local=rig.world(p,'handR').inverted() @ world;bind=rig.points['trident']-rig.points['handR']
   p['trident']=tuple(math.degrees(v) for v in local.to_euler())+(tuple(local.translation-bind),)
 a['death']=(death,False)
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name not in ['idle','walk','run','death','swim_idle','swim','torpedo','idle_sitting']:flow(p,f/9,1 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop:out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
