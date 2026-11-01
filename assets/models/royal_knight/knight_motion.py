"""Original staged swordsmanship. Audited clip names/lengths, our contact poses and secondary motion."""
import math
from mathutils import Matrix,Vector,Euler
from splinter.motion import Rig,pose
def make_actions(joints):
 rig=Rig(joints);a={};sin=math.sin;pi=math.pi
 def rest(extra=None,drop=.3,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-3,0,-4),neck=1,head=(2,0,4),
   armR=(8,0,-8),foreR=6,handR=-10,armL=(10,0,8),foreL=12,handL=-8,
   fingersR=15,fingersL=8,clothFront=5,clothL=(0,-4,0),clothR=(0,4,0))
  p.update(extra or {});return rig.planted(p,feet)
 def cloth(p,t,amp=1):
  for k in range(1,4):
   p.setdefault('cape'+str(k),(amp*(2+k)*sin(t-k*.5),amp*sin(t-k*.6),amp*1.2*sin(t-k*.7),None))
   p.setdefault('plume'+str(k),(amp*(1.5+k)*sin(t-k*.7),amp*1.5*sin(t-k*.6),0,None))
  return p
 for name,length in [('idle',2)]:
  keys=[]
  for i in range(25):
   t=i/24*2*pi;p=rest(pose(chest=(-3+.65*sin(t),0,-4+.4*sin(t)),head=(2-.6*sin(t-.4),0,4),foreL=12+.6*sin(t-.6)),.3-.014*sin(t))
   keys.append((i/24*length*30,cloth(p,t,.45)))
  a[name]=(keys,True)
 for name,length,stride,stance,lift,drop in [('walk',.7501,1.080144,.6,.36,.63),('run',.65,1.43,.55,.66,.95)]:
  keys=[]
  for i in range(49):
   t=i/48*2*pi;feet={}
   for side,q in [('L',i/48),('R',i/48+.5)]:
    q%=1
    if q<stance:y=stride*(1-2*q/stance);z=0
    else:u=(q-stance)/(1-stance);y=-stride+2*stride*u*u*(3-2*u);z=lift*sin(pi*u)
    feet[side]=(0,y,z)
   p=rest(pose(chest=(-9 if name=='walk' else -18,0,-4-3*sin(t)),head=(6,0,4+2*sin(t-.3)),
    armR=17-12*sin(t),foreR=12+4*sin(t-.3),handR=-9+3*sin(t-.7),armL=22+6*sin(t),foreL=24-3*sin(t-.3),
    clothFront=14+8*sin(t*2-.6),clothL=(10*sin(t),-8,0),clothR=(-10*sin(t),8,0)),drop+.03*(1-math.cos(t*2)),feet)
   keys.append((i/48*length*30,cloth(p,t,1.2)))
  a[name]=(keys,True)
 def sword(ch,yaw,arm,fore,hand,drop=.45,shield=32):
  return rest(pose(chest=(ch,0,yaw),head=(6,0,-yaw*.55),armR=(arm,-10,-18),foreR=fore,handR=(hand,0,9),
    armL=(shield,0,15),foreL=18,handL=-8,clothFront=8),drop)
 # Five distinct contacts: diagonal cut, backhand, thrust, overhead, shield-assisted rising cut.
 for name,dur,release,style in [('c1',.65,.3,0),('c2',.65,.31,1),('c3',.65,.33,2),('c4',.95,.5,3),('c5',1,.56,4)]:
  sign=-1 if style==1 else 1
  wind=sword(5,-sign*26,132 if style!=2 else 54,-32 if style!=2 else 66,-24,.48)
  contact=sword(-13,sign*24,62 if style!=3 else 35,14 if style!=2 else 3,26,.65,44)
  follow=sword(-17,sign*35,18 if style!=4 else 128,28,17,.7,31)
  if style==1:
   wind['armR']=(88,35,51,None);contact['armR']=(62,-30,-56,None);follow['armR']=(22,-18,-40,None)
  elif style==2:
   wind['handR']=(5,0,0,None);contact['armR']=(87,0,-7,None);contact['handR']=(3,0,0,None);follow['armR']=(96,0,-9,None)
  elif style==4:
   wind['armR']=(12,-15,-38,None);contact['armR']=(110,-9,12,None);contact['foreR']=(25,0,0,None);follow['handR']=(-8,0,0,None)
  a[name]=([(0,rest()),(release*30*.45,wind),(release*30*.78,dict(wind)),(release*30,contact),
   (release*30+(dur-release)*30*.35,follow),(dur*30,rest())],False)
 a['startcombat']=([(0,rest()),(10,rest(pose(head=-11,armR=25,foreR=48,handR=18),.35)),
  (23,rest(pose(chest=(2,0,-13),head=(5,0,13),armR=52,foreR=72,handR=15,armL=34,foreL=22),.4)),
  (34,rest(pose(chest=(-8,0,-7),head=9,armR=28,foreR=30,armL=24,foreL=28),.6)),(45,rest())],False)
 guard=rest(pose(chest=(-12,0,17),head=(8,0,-17),armL=(61,-12,24),foreL=22,handL=12,armR=25,foreR=44,handR=18),.65)
 a['bloodboundbarrier']=([(0,guard),(6,cloth(dict(guard),1,.6)),(12,cloth(dict(guard),2,.6)),(18,cloth(dict(guard),3,.6)),(24,guard)],True)
 a['bulwarkinstinct']=([(0,rest()),(8,guard),(16,rest(pose(chest=(-18,0,12),head=(11,0,-12),armL=86,foreL=-8,handL=8,armR=32,foreR=40),.78)),
  (23,guard),(34,rest(pose(armR=42,foreR=40,head=-3),.5)),(45,rest())],False)
 for name,axis,sign,length in [('dashfront',1,1,.65),('dashback',1,-1,.8),('dashleft',0,1,.65),('dashright',0,-1,.65)]:
  keys=[]
  for f,u in [(0,0),(5,.3),(9,1),(14,1),(length*30-3,.25),(length*30,0)]:
   p=rest(pose(chest=(-3-sign*14*u if axis==1 else -8,sign*10*u if axis==0 else 0,-4),head=8*u,
    armR=8+18*u,foreR=6+27*u,armL=10+28*u,foreL=12+12*u,clothFront=5+14*u),.3+.5*u)
   keys.append((f,cloth(p,f/8,2*u)))
  a[name]=(keys,False)
 a['berserkerleap']=([(0,rest()),(9,rest(pose(chest=-22,head=15,armR=24,foreR=22,armL=28),1.15)),
  (17,pose(body=(0,0,0,(0,0,.6)),chest=-10,head=9,armR=145,foreR=-20,handR=-18,armL=52,foreL=24,legL=36,legR=-22,shinL=-76,shinR=-46,footL=25,footR=27,clothFront=46)),
  (29,pose(body=(0,0,0,(0,0,1.8)),chest=8,head=-4,armR=161,foreR=-24,handR=-22,armL=40,foreL=20,legL=42,legR=33,shinL=-64,shinR=-71,footL=22,footR=35,clothFront=58)),
  (36,pose(body=(0,0,0,(0,0,.65)),chest=-21,head=13,armR=106,foreR=-8,handR=9,armL=42,foreL=17,legL=20,legR=18,shinL=-31,shinR=-28,footL=14,footR=10,clothFront=34)),
  (40.5,sword(-29,14,34,21,34,1.25,56)),(45,sword(-20,12,24,30,15,.9,44)),(53,rest(pose(chest=-9,armR=15,foreR=20),.55)),(60,rest())],False)
 # Slow visible wind-up followed by two offset cuts; not two full-damage impacts on one frame.
 for name,length,mirror in [('strikeoffury1',2.9,1),('strikeoffury2',2.75,-1)]:
  a[name]=([(0,rest()),(10,sword(2,-26*mirror,115,-25,-28,.55)),(24,sword(6,-32*mirror,145,-34,-21,.66)),
   (33 if mirror==1 else 39,sword(-18,29*mirror,54,13,33,.8)),(43,sword(-9,32*mirror,40,37,8,.6)),
   (51,sword(6,32*mirror,133,-31,-20,.5)),(60,sword(-21,-27*mirror,48,22,26,.88)),
   (69,sword(-16,-31*mirror,16,31,24,.67)),(length*30,rest())],False)
 a['viciousstrike']=([(0,rest()),(15,rest(pose(head=-12,armR=28,foreR=54,handR=18,armL=32),.5)),
  (32,sword(5,-17,137,-31,-22,.7)),(58,sword(12,-24,161,-37,-26,.85)),
  (76,sword(8,-28,166,-28,-24,.95)),(85.5,sword(-33,17,26,11,29,1.27,60)),
  (95,sword(-25,22,12,34,14,1.0,45)),(110,sword(-14,11,22,30,12,.65)),(142.5,rest())],False)
 spin=[]
 for i in range(17):
  t=i/16;p=rest(pose(chest=(-7,0,0),armR=(87,0,-87),foreR=0,handR=0,armL=38,foreL=26),.7)
  p['root']=(0,0,t*360,None);spin.append((t*7.5,cloth(p,t*2*pi,1.8)))
 a['relentlesswhirlwindspin']=(spin,True)
 a['relentlesswhirlwindpierce']=([(0,sword(-7,-22,67,57,4,.6)),(5,sword(-8,-13,78,41,3,.65)),
  (9.6,sword(-17,16,91,2,1,.8)),(13,sword(-19,21,98,0,1,.84)),(.6977*30,rest())],False)
 a['flinch']=([(0,rest()),(7,rest(pose(chest=(15,0,-13),head=(24,0,12),armR=24,foreR=20,armL=30),.6)),
  (18,rest(pose(chest=(-25,0,11),head=(-9,0,-12),armR=8,foreR=28,armL=20),1.1)),
  (37,rest(pose(chest=(-16,0,-7),head=(2,0,10),armR=15,foreR=19),.8)),(56,rest(pose(head=4),.5)),(75,rest())],False)
 a['hurt']=([(0,rest()),(5,rest(pose(chest=(8,0,-10),head=(14,0,9)),.45)),(12,rest(pose(chest=(-10,0,5),head=-2),.5)),(.7501*30,rest())],False)
 a['jump']=([(0,rest()),(7,rest(pose(chest=-19,armR=24,foreR=27,armL=33),1)),
  (13,pose(chest=-12,head=8,armR=35,foreR=35,armL=38,foreL=27,legL=38,legR=38,shinL=-71,shinR=-71,footL=33,footR=33)),
  (20,rest(pose(chest=-22,armR=26,foreR=25,armL=35),1.1)),(28,rest())],False)
 def fallen(tilt,extra=None):
  p=pose(body=(-15,tilt,0,(-.5,.1,-1.5)),chest=(-14,0,-9),head=(4,18,-12),neck=-14,
   armR=(25,-18,-20),foreR=17,handR=13,armL=(38,24,14),foreL=-12,handL=-3,
   legL=70,legR=78,shinL=-127,shinR=-139,footL=55,footR=61,clothFront=54,
   clothL=(40,-12,-8),clothR=(36,16,11),cape1=15,cape2=-17,cape3=23,plume1=-5,plume2=16,plume3=-20)
  p.update(extra or {});return p
 a['death']=([(0,rest()),(7,rest(pose(chest=(13,0,-8),head=(23,0,12),armR=25,armL=31),.55)),
  (18,rest(pose(chest=(-24,0,11),head=-5,armR=9,foreR=30,armL=43),1.25)),
  (32,fallen(0)),(43,fallen(-22,pose(armR=(42,-22,-12),foreR=-8,head=(3,12,-7)))),
  (58,fallen(-59,pose(chest=(-9,0,-13),armR=(31,-27,-9),foreR=4,head=(7,22,-16)))),
  (72,fallen(-88,pose(armR=(14,-32,-5),foreR=18,handR=22,head=(-5,32,-18)))),
  (80,fallen(-82,pose(armR=(18,-29,-5),foreR=13,head=(2,26,-16)))),
  (95,fallen(-86,pose(armR=(12,-30,-5),foreR=19,handR=25,neck=(-11,-17,0),head=(-9,37,-19),fingersR=-6,cape2=-22,plume3=-28))),
  (115.5,fallen(-86,pose(armR=(12,-30,-5),foreR=19,handR=25,neck=(-11,-17,0),head=(-9,37,-19),fingersR=-6,cape2=-22,plume3=-28)))],False)
 # After the shoulder catches, the torso rolls forward and the legs unfold onto the floor.
 death=a['death'][0]
 for f,p in death:
  if f==58:p.update(pose(body=(-48,-38,8,(-.5,.5,-1.5)),chest=(-5,8,-5),legL=35,legR=23,shinL=-63,shinR=-65,armR=(4,19,-20),foreR=5,head=(3,-10,0)))
  if f>=72:
   p.update(pose(body=(-84 if f==80 else -88,-8,12,(-.5,.8,-1.5)),chest=(0,3,-4),neck=(0,-6,0),head=(0,-9,0),
    armR=(-10,15,-27),armL=(8,-12,35),foreR=12,foreL=15,handR=6,handL=-7,
    legL=4,legR=-8,shinL=-13,shinR=-15,footL=9,footR=23,clothFront=3,clothL=(0,-3,0),clothR=(0,4,0),
    cape1=-3,cape2=4,cape3=-2,plume1=-4,plume2=8,plume3=-12))
   for side,s in [('L',1),('R',-1)]:
    shoulder=rig.world(p,'arm'+side).translation
    rig.chain(p,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.6,shoulder.y-2,2.4),(s,0,.2),Euler((-pi/2,0,0)).to_quaternion())
 # Release sword and shield; their world positions settle independently of the wrists and torso.
 for name,hand,release,landed,where in [('sword','handR',18,58,(-3,2.2,.3)),('shield','handL',43,80,(3.4,.8,.3))]:
  source=min(death,key=lambda row:abs(row[0]-release))[1];start=rig.world(source,name)
  target=Matrix.Translation(Vector(where)) @ Euler((pi/2,0,0)).to_matrix().to_4x4()
  for f,p in death:
   if f>=release:
    u=min(1,(f-release)/(landed-release));u=u*u*(3-2*u)
    p['fingers'+hand[-1]]=(-30*u,0,0,None)
    world=Matrix.Translation(start.translation.lerp(target.translation,u)) @ start.to_quaternion().slerp(target.to_quaternion(),u).to_matrix().to_4x4()
    local=rig.world(p,hand).inverted() @ world;bind=rig.points[name]-rig.points[hand]
    p[name]=tuple(math.degrees(v) for v in local.to_euler('XYZ'))+(tuple(local.translation-bind),)
 for name,(keys,loop) in list(a.items()):
  out=[];previous={}
  for f,p in keys:
   p=dict(p)
   if name not in ['idle','walk','run','death','relentlesswhirlwindspin']:cloth(p,f/10,1 if 0<f<keys[-1][0] else 0)
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  if loop and name!='relentlesswhirlwindspin':out[-1]=(out[-1][0],dict(out[0][1]))
  a[name]=(out,loop)
 return a
