"""Original forest entity: stepped bark volumes, leaf mantle, root feet and branch antlers."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from forest_motion import make_actions
NAME='forest_spirit';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,181,179)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'core':(46.5,132)}}
BARK=(62,56,47);WOOD=(105,94,73);RIDGE=(131,119,91);DARK=(36,38,32);LEAF=(53,68,46);LEAFLIGHT=(77,87,54);MOSS=(97,103,52);LICHEN=(126,126,65);SEED=(151,153,76)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.25)),('chest','body',(0,0,6.05)),('neck','chest',(0,0,7.65)),('head','neck',(0,.1,8.25)),('jaw','head',(0,.48,7.9)),('core','chest',(0,.82,6.55))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('antler'+side,'head',(s*.47,0,8.9)),('antlerTip'+side,'antler'+side,(s*2.15,-.15,9.57)),('antlerOuter'+side,'antlerTip'+side,(s*3.06,-.25,10.2)),
  ('mantle'+side+'1','chest',(s*1.18,-.12,7.45)),('mantle'+side+'2','mantle'+side+'1',(s*1.91,-.55,6.9)),
  ('skirt'+side,'body',(s*.7,-.08,4.5)),
  ('arm'+side,'chest',(s*1.6,0,7.03)),('fore'+side,'arm'+side,(s*2.24,.07,5.6)),('hand'+side,'fore'+side,(s*2.78,.33,4.03)),
  ('fingers'+side,'hand'+side,(s*2.77,.44,3.79)),('outer'+side,'hand'+side,(s*3.05,.39,3.82)),('thumb'+side,'hand'+side,(s*2.49,.48,3.98)),
  ('leg'+side,'body',(s*.82,0,4.25)),('shin'+side,'leg'+side,(s*1.04,.04,2.37)),('foot'+side,'shin'+side,(s*1.15,0,.35)),
  ('toeFront'+side,'foot'+side,(s*1.15,.43,.21)),('toeOuter'+side,'foot'+side,(s*1.53,.06,.2)),('toeBack'+side,'foot'+side,(s*1.17,-.31,.2))]
JOINTS += [('mantleBack1','chest',(0,-.85,7.5)),('mantleBack2','mantleBack1',(0,-1.0,6.8)),('skirtFront','body',(0,.75,4.5)),('skirtBack','body',(0,-.7,4.5))]
g=Geometry();add,mass,beam=g.add,g.mass,g.beam
def leaf(n,j,a,b,w,col):
 a,b=Vector(a),Vector(b)
 for k,(u,v,width) in enumerate([(0,.3,.72),(.28,.72,1),(.7,1,.48)]):beam(n+str(k),j,a.lerp(b,u),a.lerp(b,v),w*width,.12,col)
def moss(n,j,c,size=.16):
 for k,(x,y,z) in enumerate([(0,0,0),(.16,.05,.03),(-.12,-.04,-.09)]):add(n+str(k),j,(c[0]+x,c[1]+y,c[2]+z),(size*1.3,size,size*.8),MOSS if k%2 else LICHEN)
mass('Waist','body',(0,0,5.15),(2.25,1.53,1.95),BARK,4,5)
mass('Thorax','chest',(0,-.08,6.79),(3.05,1.9,1.82),DARK,4,5)
mass('Seed','core',(0,.92,6.55),(1.03,.82,1.18),SEED,5,5)
for k in range(5):add('SeedGrain'+str(k),'core',(-.31+k*.16,1.33,6.51+(.15 if k%2 else -.12)),(.055,.04,.54),LICHEN)
for side,s in [('L',1),('R',-1)]:
 for k in range(4):
  z=7.49-k*.48
  beam('RibInner'+side+str(k),'chest',(s*.33,1.02,z),(s*1.16,.77,z-.24),.2,.21,WOOD)
  beam('RibOuter'+side+str(k),'chest',(s*1.16,.77,z-.24),(s*1.43,.25,z-.2),.24,.23,RIDGE)
 for k in range(3):
  beam('WaistRoot'+side+str(k),'body',(s*(.12+k*.28),.82,4.55),(s*(.84+k*.16),.66,5.9),.19,.22,WOOD if k%2 else RIDGE)
 for k in range(4):
  beam('SpineRidge'+side+str(k),'chest',(s*.14,-1.0,7.45-k*.37),(s*.65,-.86,7.26-k*.37),.19,.18,WOOD)
 mass('Shoulder'+side,'arm'+side,(s*1.57,0,7.05),(1.35,1.47,.95),BARK,3,4)
 beam('UpperArm'+side,'arm'+side,(s*1.65,.02,6.89),(s*2.24,.07,5.6),.66,.74,BARK)
 for k in [-1,0,1]:beam('ArmRidge'+side+str(k),'arm'+side,(s*1.65+k*.21,.42,6.82),(s*2.24+k*.19,.44,5.65),.14,.15,RIDGE if k==0 else WOOD)
 mass('Elbow'+side,'fore'+side,(s*2.24,.07,5.6),(.7,.76,.51),WOOD,2,4)
 beam('Forearm'+side,'fore'+side,(s*2.27,.08,5.48),(s*2.78,.33,4.08),.77,.83,BARK)
 for k in [-1,0,1]:beam('ForeRoot'+side+str(k),'fore'+side,(s*2.27+k*.23,.52,5.45),(s*2.77+k*.19,.79,4.14),.18,.16,WOOD)
 for k in range(4):
  leaf('ForeLeaf'+side+str(k),'fore'+side,(s*(2.18+k*.15),.62,5.55-k*.14),(s*(2.53+k*.16),.79,4.71-k*.14),.3,LEAFLIGHT if k%2 else LEAF)
 moss('ElbowMoss'+side,'fore'+side,(s*2.3,.62,5.48),.21)
 mass('Palm'+side,'hand'+side,(s*2.78,.37,3.91),(.62,.49,.57),BARK,3,3)
 for k in range(3):
  x=s*(2.55+k*.22);j=('fingers'if k<2 else 'outer')+side;length=.69-abs(k-1)*.09
  beam('DigitBase'+side+str(k),j,(x,.52,3.83),(x+s*.08,.67,3.83-length),.15,.17,WOOD)
  beam('DigitEnd'+side+str(k),j,(x+s*.08,.67,3.83-length),(x+s*.03,.93,3.69-length),.12,.14,RIDGE)
 beam('ThumbBase'+side,'thumb'+side,(s*2.49,.48,3.98),(s*2.25,.75,3.66),.2,.21,WOOD)
 beam('ThumbTip'+side,'thumb'+side,(s*2.25,.75,3.66),(s*2.32,.94,3.41),.14,.16,RIDGE)
 mass('Thigh'+side,'leg'+side,(s*.93,0,3.47),(1.1,1.18,1.88),BARK,4,4)
 for k in [-1,0,1]:beam('ThighRoot'+side+str(k),'leg'+side,(s*.85+k*.23,.61,4.1),(s*1.04+k*.19,.58,2.5),.17,.19,WOOD)
 mass('Knee'+side,'shin'+side,(s*1.04,.08,2.37),(1.04,1.13,.62),WOOD,2,4)
 beam('Shin'+side,'shin'+side,(s*1.04,.04,2.25),(s*1.15,0,.42),.67,.8,BARK)
 for k in [-1,0,1]:beam('ShinRoot'+side+str(k),'shin'+side,(s*1.04+k*.21,.56,2.21),(s*1.15+k*.19,.47,.51),.15,.17,RIDGE if k==0 else WOOD)
 for k in range(3):leaf('KneeLeaf'+side+str(k),'shin'+side,(s*(.76+k*.25),.72,2.67),(s*(.82+k*.25),.8,2.1-k*.09),.27,LEAFLIGHT)
 moss('KneeMoss'+side,'shin'+side,(s*1.06,.74,2.58),.2)
 mass('FootPad'+side,'foot'+side,(s*1.15,.02,.27),(1.25,1.12,.52),BARK,2,4)
 for k in [-1,0,1]:
  j='toeFront'+side;x=s*1.15+k*.33
  beam('FrontRoot'+side+str(k),j,(x,.37,.28),(x+k*.16,1.01-abs(k)*.11,.12),.24,.23,WOOD)
  add('RootNail'+side+str(k),j,(x+k*.16,1.01-abs(k)*.11,.13),(.25,.29,.25),RIDGE)
 beam('SideRoot'+side,'toeOuter'+side,(s*1.54,.05,.24),(s*2.01,.27,.12),.25,.24,WOOD)
 beam('BackRoot'+side,'toeBack'+side,(s*1.17,-.28,.23),(s*1.29,-.81,.12),.25,.24,WOOD)
 moss('AnkleMoss'+side,'foot'+side,(s*1.32,.41,.56),.2)
 # Overlapping leaf tiers attach to the shoulder mantle, independent of the arm.
 for tier in range(3):
  j='mantle'+side+('1'if tier<2 else '2')
  for k in range(6):
   angle=(k/5-.5)*2.35;x=s*(1.1+.35*tier+.42*math.cos(angle));y=.8*math.sin(angle)-.12
   leaf('Mantle'+side+str(tier)+str(k),j,(x,y,7.68-tier*.33),(x+s*.39,y-.17,6.94-tier*.39),.53,LEAF if (k+tier)%2 else LEAFLIGHT)
   if tier==0:moss('MantleMoss'+side+str(k),j,(x,y,7.75),.16)
for k in range(5):mass('Neck'+str(k),'neck',(0,0,7.56+k*.14),(.74,.8,.17),WOOD,1,3)
mass('MaskBack','head',(0,0,8.44),(1.33,1.1,1.4),BARK,4,4)
add('EyeRecess','head',(0,.59,8.54),(1.18,.13,.4),DARK)
for side,s in [('L',1),('R',-1)]:
 beam('Brow'+side,'head',(s*.05,.79,8.79),(s*.57,.68,8.9),.17,.18,WOOD)
 add('Eye'+side,'head',(s*.35,.677,8.53),(.13,.045,.09),SEED)
 beam('FaceRidge'+side,'head',(s*.48,.72,8.47),(s*.29,.84,7.92),.18,.21,RIDGE)
 beam('Cheek'+side,'jaw',(s*.44,.44,8.05),(s*.24,.68,7.62),.2,.26,WOOD)
beam('MaskNose','head',(0,.71,8.96),(0,.98,7.96),.25,.22,RIDGE)
beam('MaskChin','jaw',(0,.71,8.0),(0,.76,7.51),.19,.22,WOOD)
for k in range(4):add('BrowScar'+str(k),'head',(-.33+k*.19,.7,9.0-k*.055),(.055,.07,.17),DARK)
for side,s in [('L',1),('R',-1)]:
 points=[(s*.47,0,8.9),(s*1.19,-.07,9.31),(s*2.15,-.15,9.57),(s*3.06,-.25,10.2),(s*3.38,-.31,10.88)]
 for k,(a,b) in enumerate(zip(points,points[1:])):
  j='antler'+side if k<2 else('antlerTip'+side if k==2 else'antlerOuter'+side)
  beam('Antler'+side+str(k),j,a,b,.29-k*.04,.32-k*.045,WOOD)
  beam('AntlerRidge'+side+str(k),j,(a[0],a[1]+.17,a[2]),(b[0],b[1]+.13,b[2]),.08,.06,RIDGE)
 for k,(x,z,h) in enumerate([(1.17,9.3,.77),(1.83,9.48,.63),(2.6,9.91,.72),(3.12,10.31,.61)]):
  j='antler'+side if k<2 else('antlerTip'+side if k==2 else'antlerOuter'+side)
  a=(s*x,-.14,z);b=(s*(x-.1),-.11,z+h*.62);c=(s*(x+.13),-.12,z+h)
  beam('TineBase'+side+str(k),j,a,b,.17,.2,WOOD);beam('TineTip'+side+str(k),j,b,c,.12,.15,RIDGE)
  if k%2==0:moss('AntlerMoss'+side+str(k),j,a,.19);leaf('AntlerLichen'+side+str(k),j,(a[0],a[1]-.08,a[2]),(a[0]+s*.12,a[1]-.13,a[2]-.4),.2,MOSS)
for section in ['Front','Back','L','R']:
 j='skirt'+section
 for tier in range(2):
  for k in range(5):
   x=(k-2)*.29;y=.78 if section=='Front'else -.78
   if section in ['L','R']:x=(1 if section=='L'else -1)*1.05;y=(k-2)*.3
   a=(x,y,4.5-tier*.4);b=(x*1.17,y*1.21,3.47-tier*.48-.12*(k%2))
   leaf('Skirt'+section+str(tier)+str(k),j,a,b,.42,LEAF if (tier+k)%2 else LEAFLIGHT)
for tier in range(2):
 for k in range(7):leaf('BackLeaf'+str(tier)+str(k),'mantleBack'+str(tier+1),((k-3)*.4,-1.02,7.55-tier*.62),((k-3)*.43,-1.15,6.62-tier*.63),.51,LEAF if k%2 else LEAFLIGHT)
PARTS=g.parts;EXTRA_JSON={'walkSpeed':2.75,'runSpeed':4.5}
CLIP_FILES={'loco':['idle','walk','run'],'touch':['attack7','hurt','jump','stun'],
 'roots':['attack1'],'spikes':['attack2'],'arrows':['attack3'],'lightning':['attack4'],'pulse':['attack5'],
 'storm':['attack6'],'ritual':['attack8'],'spawn':['spawn','spawn_cancelled'],'death':['death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('attack1',60),('attack6',120),('death',186)]
PREVIEW_CAMERA=((16,24,12),(0,0,5.1),48)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.5),17),'side':((0,-1,0),(0,0,1),(0,0,5.5),17),'back':((1,0,0),(0,0,1),(0,0,5.5),17)}
if __name__=='__main__':run(globals())
