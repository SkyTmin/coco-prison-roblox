"""Original shared small humanoid anatomy, distinct shaman and lost-explorer equipment."""
import math
from undead_king.necromancer_parts import Geometry
from splinter.motion import Rig,pose
WOOD=(104,92,69);DARK=(39,42,33);CLOTH=(58,66,47);LEAF=(80,91,55);SKIN=(139,126,99);IRON=(73,72,58);SEED=(149,145,75)
def specification(name,here,shaman):
 joints=[('root',None,(0,0,0)),('body','root',(0,0,1.83)),('chest','body',(0,0,2.65)),('head','chest',(0,.03,3.52)),('jaw','head',(0,.29,3.28)),('mantle','chest',(0,-.35,2.96)),('skirt','body',(0,0,1.9))]
 for side,s in [('L',1),('R',-1)]:
  joints += [('arm'+side,'chest',(s*.67,0,2.94)),('fore'+side,'arm'+side,(s*.8,.07,2.24)),('hand'+side,'fore'+side,(s*.88,.23,1.59)),('leg'+side,'body',(s*.32,0,1.83)),('shin'+side,'leg'+side,(s*.37,.03,1.04)),('foot'+side,'shin'+side,(s*.4,0,.18))]
 joints += [('prop','handL',(.94,.34,1.6)),('propTip','prop',(1.1,.34,3.22)if shaman else(.94,.34,1.06))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam
 mass('Body','body',(0,0,2.04),(1.01,.76,.84),CLOTH)
 mass('Chest','chest',(0,0,2.69),(1.33,.87,.93),CLOTH,3,4)
 for k in range(4):add('TunicSeam'+str(k),'chest',(0,.47,2.99-k*.17),(.16,.07,.1),WOOD)
 mass('Hood','head',(0,-.05,3.62),(1.17,1.08,1.05),CLOTH,4,4)
 add('FaceInset','head',(0,.51,3.56),(.77,.1,.72),DARK)
 if shaman:
  for k in [-1,0,1]:beam('MaskBoard'+str(k),'head',(k*.21,.6,3.89),(k*.17,.63,3.31-abs(k)*.1),.18,.13,WOOD)
  for s in [-1,1]:
   add('MaskEye'+str(s),'head',(s*.19,.69,3.61),(.12,.045,.09),DARK)
   beam('MaskHorn'+str(s),'head',(s*.4,.0,3.92),(s*.57,-.06,4.4),.14,.16,WOOD)
 else:
  mass('Face','head',(0,.5,3.55),(.67,.34,.62),SKIN,2,3)
  for s in [-1,1]:add('Eye'+str(s),'head',(s*.17,.69,3.62),(.1,.04,.09),DARK)
  add('Nose','head',(0,.73,3.51),(.13,.12,.17),SKIN)
  mass('Pack','mantle',(0,-.57,2.61),(.91,.46,1.14),WOOD,3,3)
  for s in [-1,1]:beam('PackStrap'+str(s),'chest',(s*.39,.42,3.01),(s*.36,.45,2.28),.1,.07,IRON)
 add('Jaw','jaw',(0,.51,3.25),(.48,.22,.16),WOOD if shaman else SKIN)
 for k in range(5):
  x=(k-2)*.22
  beam('MantleLeaf'+str(k),'mantle',(x,-.47,3.04),(x*1.15,-.59,2.29-.08*(k%2)),.28,.12,LEAF)
  beam('SkirtFront'+str(k),'skirt',(x,.4,1.93),(x*1.15,.47,1.27+.08*(k%2)),.25,.12,CLOTH)
  beam('SkirtBack'+str(k),'skirt',(x,-.38,1.93),(x*1.15,-.46,1.32+.09*(k%2)),.25,.12,CLOTH)
 for side,s in [('L',1),('R',-1)]:
  mass('Shoulder'+side,'arm'+side,(s*.67,0,2.89),(.51,.59,.51),LEAF,2,3)
  beam('Sleeve'+side,'arm'+side,(s*.68,0,2.85),(s*.8,.07,2.24),.34,.39,CLOTH)
  beam('Forearm'+side,'fore'+side,(s*.8,.07,2.21),(s*.88,.23,1.66),.27,.31,CLOTH)
  add('Cuff'+side,'fore'+side,(s*.86,.21,1.74),(.36,.37,.17),IRON)
  mass('Hand'+side,'hand'+side,(s*.88,.27,1.55),(.34,.31,.36),SKIN,2,3)
  for k in range(3):add('Fingers'+side+str(k),'hand'+side,(s*(.76+k*.1),.4,1.47),(.08,.12,.19),SKIN)
  beam('Thigh'+side,'leg'+side,(s*.32,0,1.8),(s*.37,.03,1.04),.42,.46,CLOTH)
  beam('Calf'+side,'shin'+side,(s*.37,.03,1.03),(s*.4,0,.22),.33,.36,CLOTH)
  for k in range(3):add('LegWrap'+side+str(k),'shin'+side,(s*.39,.04,.75-k*.2),(.4,.41,.08),WOOD)
  mass('Boot'+side,'foot'+side,(s*.4,.18,.16),(.46,.8,.31),DARK,2,3)
 if shaman:
  beam('Staff','prop',(.97,.34,.27),(1.12,.34,3.24),.13,.15,WOOD)
  for s in [-1,1]:
   beam('StaffFork'+str(s),'propTip',(1.12,.34,3.16),(1.12+s*.32,.34,3.51),.13,.15,WOOD)
   beam('StaffTine'+str(s),'propTip',(1.12+s*.32,.34,3.51),(1.12+s*.18,.34,3.8),.12,.13,WOOD)
  mass('StaffSeed','propTip',(1.12,.34,3.57),(.36,.34,.43),SEED,3,3)
 else:
  beam('LanternHandle','prop',(.94,.34,1.6),(.94,.34,1.07),.1,.1,IRON)
  add('LanternBody','propTip',(.94,.34,.81),(.5,.44,.61),SEED)
  for z in [.51,1.12]:add('LanternCap'+str(z),'propTip',(.94,.34,z),(.6,.54,.1),IRON)
  for x in [.68,1.2]:
   for y in [.11,.57]:beam('LanternBar'+str(x)+str(y),'propTip',(x,y,.53),(x,y,1.1),.08,.08,IRON)
 def actions():
  rig=Rig(joints);a={};sin=math.sin;pi=math.pi
  def rest(extra=None,drop=.11):
   p=pose(body=(0,0,0,(0,0,-drop)),chest=-6 if shaman else -11,head=5,armL=(8,0,9),armR=(8,0,-9),foreL=12,foreR=12,handL=-5,handR=-5,mantle=4,skirt=2,propTip=0);p.update(extra or {});return rig.planted(p)
  a['idle']=([(i/24*2.4*30,rest(pose(chest=(-6 if shaman else-11)+sin(i/24*2*pi),head=5+.7*sin(i/24*2*pi-.4),mantle=4+sin(i/24*2*pi-.6),propTip=2*sin(i/24*2*pi-.8))))for i in range(25)],True)
  keys=[]
  for i in range(49):
   q=i/48;t=q*2*pi;feet={}
   for side,phase in [('L',q),('R',q+.5)]:
    phase%=1
    if phase<.6:y=.4*(1-2*phase/.6);z=0
    else:u=(phase-.6)/.4;y=-.4+.8*u*u*(3-2*u);z=.15*sin(pi*u)
    feet[side]=(0,y,z)
   p=pose(body=(0,0,0,(.013*sin(t),0,-.24)),chest=(-10 if shaman else-17,0,3*sin(t)),head=(8,0,-2*sin(t)),armL=-5*sin(t),armR=17*sin(t),foreL=14,foreR=12,handL=-7,handR=-5,mantle=4+2*sin(t-.5),skirt=3+2*sin(t-.7),propTip=5*sin(t-.8))
   keys.append((q*(1.3 if shaman else 1.48)*30,rig.planted(p,feet)))
  a['walk']=(keys,True)
  length=1.24 if shaman else 1.64;hit=.7 if shaman else.85
  a['bite']=([(0,rest()),(hit*.42*30,rest(pose(chest=(1,0,-11),head=(4,0,7),armR=61,foreR=34,armL=23,propTip=-9),.19)),((hit-.13)*30,rest(pose(chest=(9,0,-19),head=9,armR=118,foreR=18,armL=47,propTip=-14),.27)),(hit*30,rest(pose(chest=(-21,0,23),head=13,armR=64,foreR=-8,armL=34,propTip=15),.38)),((hit+.2)*30,rest(pose(chest=(-15,0,17),head=8,armR=31,foreR=14,propTip=8),.29)),(length*30,rest())],False)
  a['spawn']=([(0,rest(pose(chest=-21,head=-11),.5)),(12,rest(pose(chest=-12,head=6,armR=24),.25)),(36,rest())],False)
  a['hurt']=([(0,rest()),(3,rest(pose(chest=(11,0,-8),head=(17,0,11)),.22)),(9,rest())],False)
  def fallen(x):return pose(body=(x,0,-8,(0,.1,-.65)),chest=-4,head=5,jaw=-8,armL=(-13,0,29),armR=(-17,0,-21),foreL=3,foreR=5,handL=-19,handR=-22,legL=0,legR=-8,shinL=-4,shinR=-6,footL=-29,footR=-32,mantle=0,skirt=-6,prop=((0,-65,20) if shaman else (-5,-55,20)),propTip=0)
  a['death']=([(0,rest()),(7,rest(pose(chest=13,head=19),.24)),(17,rest(pose(chest=-27,head=13,armR=43),.62)),(28,fallen(-49)),(40,fallen(-86)),(45,fallen(-81)),(55,fallen(-89)),(67.2,fallen(-89))],False)
  return a
 return dict(NAME=name,HERE=here,JOINTS=joints,PARTS=g.parts,actions=actions,BAKE_CURVES=True,BATCH_SAMPLE=True,GROUND_CLIPS=['death'],GROUND_SUBSTEPS=4,TILE_STUDS=2,GAME_LIFT={'gain':1,'saturate':1},EXTRA_JSON={'walkSpeed':.8/(.6*(1.3 if shaman else 1.48))},CLIP_FILES={'move':['idle','walk','spawn'],'act':['bite','hurt','death']},PREVIEWS=[('idle',25),('bite',21 if shaman else 25.5),('death',67.2)],PREVIEW_CAMERA=((7,10,6),(0,0,2),48),COMPARE={'front':((-1,0,0),(0,0,1),(0,0,2.2),6)})
