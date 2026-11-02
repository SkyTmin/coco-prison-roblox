"""Original sword choreography; source families, not imported commercial tracks."""
import math
from mathutils import Vector
from splinter.motion import Rig,pose
from raven_knight.raven_motion import make_actions as established_motion

def make_actions(joints):
 rig=Rig(joints);base=established_motion(joints);a={k:base[k]for k in ['idle','walk','run','hurt','stun','jump','death']}
 def rest(extra=None,drop=.38,feet=None):
  p=pose(body=(0,0,0,(0,0,-drop)),chest=(-4,0,-7),head=(3,0,7),armR=(7,0,-7),foreR=8,handR=-7,
   armL=(9,0,7),foreL=17,handL=-8,fingersR=35,fingersL=8,thumbR=24,clothFront=6,tassetL=(8,-4,0),tassetR=(8,4,0))
  p.update(extra or {});return rig.planted(p,feet)
 def cut(yaw,arm,fore,roll,drop=.68,lean=-12):
  return rest(pose(chest=(lean,0,yaw),head=(7,0,-yaw*.7),armR=(arm,-7,roll),foreR=fore,handR=(13,0,9),
   armL=(41,0,16),foreL=39,tassetL=(13,-5,0),tassetR=(13,5,0),clothFront=12),drop)
 # Draw across the hip, commit from the shoulder, follow through, return without a frozen tail.
 a['drawcut']=([(0,rest()),(7,cut(-31,41,63,-17,.68,-5)),(15,cut(-42,52,58,-24,.74,4)),
  (22.5,cut(34,82,-8,41,.88,-17)),(28,cut(43,44,11,52,.82,-21)),(36,cut(18,22,27,18,.58,-8)),(45,rest())],False)
 a['reversecut']=([(0,rest()),(10,cut(34,111,27,49,.7,3)),(18,cut(41,119,21,55,.76,7)),
  (25.5,cut(-34,67,-3,-46,.9,-20)),(32,cut(-42,31,19,-52,.8,-18)),(41,cut(-16,19,28,-17,.58,-7)),(49.5,rest())],False)
 combo=[(0,rest())]
 for i,f in enumerate([33,54,75]):
  s=1 if i%2==0 else-1
  combo.extend([(f-15,cut(-32*s,143 if s==1 else 104,-27 if s==1 else 26,-20 if s==1 else 49,.72,6)),
   (f-7,cut(-37*s,149 if s==1 else 112,-31 if s==1 else 21,-24 if s==1 else 54,.78,9)),
   (f,cut(31*s,52 if s==1 else 69,17 if s==1 else-5,21 if s==1 else-48,.91,-23)),
   (f+5,cut(40*s,27,29,29*s,.84,-18))])
 combo.append((108,rest()));a['triplecut']=(combo,False)
 a['sweep']=([(0,rest()),(14,cut(-48,72,43,-44,.91,-21)),(31,cut(-59,84,35,-51,1.0,-23)),
  (40.5,cut(57,76,-5,57,.95,-18)),(48,cut(69,42,12,67,.88,-15)),(65,cut(21,20,28,22,.57,-8)),(84,rest())],False)
 a['thrust']=([(0,rest()),(12,cut(-27,65,81,-8,.8,-11)),(26,cut(-33,76,77,-12,.93,-15)),
  (36,cut(14,93,-9,2,.96,-26)),(43,cut(21,98,-12,6,.98,-28)),(55,cut(-8,54,49,-6,.69,-10)),(69.6,rest())],False)
 a['dashcut']=([(0,rest()),(11,cut(-34,39,67,-19,1.0,-24)),(24,cut(-41,48,61,-24,1.1,-28)),
  (36,pose(chest=(-19,0,-27),head=(12,0,21),armR=(57,-8,-22),foreR=51,armL=45,foreL=40,legL=31,legR=-24,shinL=-65,shinR=-39,footL=28,footR=20)),
  (49.5,cut(41,82,-4,51,1.1,-27)),(56,cut(49,34,22,60,.94,-20)),(65,cut(16,19,31,17,.61,-8)),(74.4,rest())],False)
 a['skycut']=([(0,rest()),(14,cut(-21,126,-27,-14,1.11,-21)),(28,cut(-29,149,-31,-18,1.18,-17)),
  (39,pose(body=(0,0,0,(0,0,1.1)),chest=-7,head=1,armR=(157,-11,-15),foreR=-24,handR=-24,armL=58,foreL=22,legL=42,legR=26,shinL=-73,shinR=-63,footL=34,footR=31)),
  (52.5,cut(29,34,19,21,1.16,-29)),(60,cut(36,13,34,27,.96,-24)),(74,cut(11,21,27,10,.55,-7)),(90,rest())],False)
 def call(length,release,kind):
  wind=rest(pose(chest=(4,0,17),head=(11,0,-12),armL=(106,5,24),foreL=42,handL=19),.58)
  contact=rest(pose(chest=(-14,0,-19),head=(7,0,11),armL=(94,-5,-13),foreL=-7,handL=27,fingersL=-24),.83)
  if kind=='sickle':wind['armL']=(66,17,63,None);contact['armL']=(78,-21,-49,None)
  if kind=='spears':wind['armL']=(149,0,16,None);contact['armL']=(43,0,22,None)
  if kind=='arrowcall':wind['armL']=(127,0,29,None);contact['armL']=(152,0,19,None)
  return ([(0,rest()),(release*30*.38,wind),(release*30-6,wind),(release*30,contact),
   (release*30+8,contact),(length*30,rest())],False)
 for name,length,release in [('stars',3,1.15),('sickle',3.48,1.35),('spears',2.8,1.4),('arrowcall',3.72,1.45)]:a[name]=call(length,release,name)
 a['spawn']=([(0,rest(pose(chest=-24,head=-19,armR=25,foreR=37,armL=31,foreL=43),1.12)),
  (24,rest(pose(chest=-13,head=-7,armR=34,foreR=28),.8)),(53,rest(pose(chest=4,head=15,armL=29),.3)),(84,rest())],False)
 for stage,length in [(2,3.6),(3,3.3)]:
  p1=rest(pose(chest=-17,head=-13,armL=81,foreL=69,armR=54,foreR=57),.82)
  p2=rest(pose(chest=8,head=14,armL=(55,0,49),foreL=7,armR=(48,0,-41),foreR=9),.45)
  p3=rest(pose(chest=-12,head=-5,armL=23,armR=24),.7)
  # Phase changes are a vulnerable stance reset, with no mesh fades/rebuilds.
  if stage==3:
   p1['armL']=(139,0,15,None);p1['foreL']=(19,0,0,None)
   p2['chest']=(13,0,-17,None);p2['head']=(19,0,13,None)
   p3['armR']=(73,-8,-24,None);p3['foreR']=(37,0,0,None)
  a['phase'+str(stage)]=([(0,rest()),(20,p1),(38,p1),(50,p2),(64,p3),(length*30,rest())],False)
 for name,(keys,loop) in a.items():
  if name in ['idle','walk','run','hurt','stun','jump','death']:continue
  previous={};out=[]
  for f,p in keys:
   p=dict(p)
   for k in range(1,4):
    for side,sgn in [('',0),('L',1),('R',-1)]:p.setdefault('cape'+side+str(k),(1.5*math.sin(f/13-k*.5),sgn*math.sin(f/15-k*.6),0,None))
   p.setdefault('scabbard',(2*math.sin(f/16-.4),0,math.sin(f/14),None))
   for n,v in p.items():
    v=list(v)
    if n in previous:
     for axis in range(3):v[axis]=previous[n][axis]+(v[axis]-previous[n][axis]+180)%360-180
    p[n]=tuple(v);previous[n]=v
   out.append((f,p))
  a[name]=(out,loop)
 return a
