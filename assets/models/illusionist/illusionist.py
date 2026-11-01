"""Original voxel stage magician, based on our generated turnaround. Headless Blender only."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from illusionist_motion import make_actions
NAME='illusionist';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=1.8;GAME_LIFT={'saturate':1,'gain':1};BACKGROUND=(185,183,184)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'dagger':(35,82),'cards':(47,101),'hat':(69,132)}}
RED=(112,43,48);REDL=(133,54,57);REDD=(77,31,38);BLACK=(36,36,41);DARK=(25,26,31)
GREY=(54,53,60);SKIN=(169,164,162);SKINL=(190,184,180);IVORY=(208,201,181);GOLD=(153,128,83);STEEL=(127,138,145)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,3.38)),('chest','body',(0,0,4.65)),
 ('neck','chest',(0,0,5.55)),('head','neck',(0,0,6.12)),('jaw','head',(0,.25,5.86)),
 ('hat','head',(0,0,6.82)),('fringeL','head',(.43,.48,6.65)),('fringeR','head',(-.43,.48,6.65)),
 ('tie','chest',(0,.63,5.38))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('arm'+side,'chest',(s*1.05,0,5.25)),('fore'+side,'arm'+side,(s*1.43,.02,4.25)),
  ('hand'+side,'fore'+side,(s*1.7,.11,3.28)),('fingers'+side,'hand'+side,(s*1.7,.33,3.12)),
  ('thumb'+side,'hand'+side,(s*1.48,.27,3.23)),('leg'+side,'body',(s*.5,0,3.38)),
  ('shin'+side,'leg'+side,(s*.55,.04,1.85)),('foot'+side,'shin'+side,(s*.59,.03,.32)),
  ('tail'+side+'1','body',(s*.57,-.5,3.8)),('tail'+side+'2','tail'+side+'1',(s*.7,-.58,2.88)),
  ('tail'+side+'3','tail'+side+'2',(s*.82,-.65,2.13))]
JOINTS += [('dagger','handR',(-1.7,.22,3.15)),('cards','handL',(1.7,.29,3.2))]
PARTS=[]
def add(n,j,c,size,col,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),col,rot=rot))
def mass(n,j,c,size,col,layers=3,slices=3):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  r=math.sqrt(1-((i+.5)/layers*2-1)**2)
  for k in range(slices):
   v=(k+.5)/slices*2-1
   add(n+str(i)+'_'+str(k),j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*math.sqrt(1-v*v),d*r/slices,h/layers),col)
def beam(n,j,a,b,w,d,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(x) for x in v.to_track_quat('Z','Y').to_euler()))
# Layered waistcoat, actual rounded back, red coat skirt split into six moving panels.
mass('CoatBody','body',(0,0,4.06),(1.85,1.05,1.65),RED,4,4)
mass('CoatChest','chest',(0,0,5.04),(2.0,1.12,1.12),RED,3,4)
mass('BackSeam','chest',(0,-.48,4.96),(1.63,.25,1.03),REDD,2,3)
add('Shirt','chest',(0,.57,5.1),(.64,.1,.95),IVORY)
for s in [-1,1]:
 beam('Lapel'+str(s),'chest',(s*.67,.55,5.51),(s*.22,.65,4.45),.27,.12,BLACK)
 add('Collar'+str(s),'chest',(s*.23,.64,5.45),(.28,.16,.25),IVORY,(0,s*8,s*18))
 for z in [4.07,4.43,4.79]:
  add('Button'+str(s)+str(z),'body' if z<4.6 else 'chest',(s*.58,.56,z),(.17,.12,.18),GOLD)
  add('ButtonInset'+str(s)+str(z),'body' if z<4.6 else 'chest',(s*.58,.63,z),(.06,.02,.06),IVORY)
add('Waistcoat','body',(0,.56,3.98),(.67,.12,.86),BLACK)
add('Pocket','chest',(.62,.62,4.98),(.45,.08,.11),REDD)
for s in [-1,1]:add('Bowtie'+str(s),'tie',(s*.17,.68,5.4),(.3,.18,.2),REDD,(0,0,s*12))
add('BowKnot','tie',(0,.74,5.4),(.16,.16,.2),REDL)
mass('Belt','body',(0,.01,3.63),(1.89,1.08,.23),BLACK,1,4)
add('Buckle','body',(0,.62,3.62),(.38,.13,.26),GOLD)
add('BuckleDark','body',(0,.7,3.62),(.19,.03,.12),DARK)
for side,s in [('L',1),('R',-1)]:
 for k,(z,h,w,y) in enumerate([(3.35,1.0,.91,-.48),(2.57,.85,.8,-.56),(1.93,.58,.57,-.62)],1):
  j='tail'+side+str(k)
  add('TailBack'+side+str(k),j,(s*(.6+(k-1)*.13),y,z),(w,.22,h),RED)
  add('TailEdge'+side+str(k),j,(s*(1.0+(k-1)*.1),y+.04,z),(.15,.25,h),REDD)
  add('TailFront'+side+str(k),j,(s*(.77+(k-1)*.13),.35,z),(.36,.18,h),REDD)
 mass('Shoulder'+side,'arm'+side,(s*1.08,0,5.18),(.8,1.03,.56),REDL,2,3)
 beam('UpperSleeve'+side,'arm'+side,(s*1.12,0,5.12),(s*1.43,.02,4.25),.62,.77,RED)
 beam('LowerSleeve'+side,'fore'+side,(s*1.43,.02,4.25),(s*1.68,.1,3.5),.56,.66,RED)
 add('ElbowBand'+side,'fore'+side,(s*1.43,.02,4.2),(.68,.8,.23),BLACK,(0,s*15,0))
 add('ElbowBuckle'+side,'fore'+side,(s*1.43,.46,4.19),(.2,.09,.16),GOLD)
 add('Cuff'+side,'fore'+side,(s*1.67,.1,3.53),(.63,.72,.22),BLACK,(0,s*15,0))
 add('ShirtCuff'+side,'hand'+side,(s*1.69,.11,3.39),(.55,.63,.2),IVORY)
 mass('Palm'+side,'hand'+side,(s*1.7,.12,3.14),(.55,.47,.42),IVORY,2,3)
 for k in range(3):
  add('Finger'+side+str(k),'fingers'+side,(s*1.7+(k-1)*.145,.34,2.98),(.13,.2,.32),IVORY,(-13,0,0))
 add('Thumb'+side,'thumb'+side,(s*1.46,.28,3.1),(.18,.23,.31),SKINL,(-20,0,s*15))
 mass('Trouser'+side,'leg'+side,(s*.53,0,2.67),(.79,.9,1.41),BLACK,3,4)
 add('TrouserSeam'+side,'leg'+side,(s*.76,.19,2.62),(.06,.43,1.19),GREY)
 mass('BootShin'+side,'shin'+side,(s*.58,.0,1.08),(.73,.83,1.4),BLACK,3,4)
 add('KneeBand'+side,'shin'+side,(s*.55,.03,1.82),(.83,.93,.24),DARK)
 add('KneeBuckle'+side,'shin'+side,(s*.55,.55,1.82),(.19,.08,.17),GOLD)
 mass('BootFoot'+side,'foot'+side,(s*.59,.3,.28),(.92,1.29,.55),BLACK,2,4)
 add('Sole'+side,'foot'+side,(s*.59,.3,.08),(.96,1.32,.16),DARK)
 add('BootStrap'+side,'foot'+side,(s*.59,.61,.49),(.72,.24,.16),GREY)
 add('BootBuckle'+side,'foot'+side,(s*.59,.76,.49),(.24,.1,.2),GOLD)
# Angular face and separately moving jaw/fringe; hair wraps the rear of the skull.
mass('Neck','neck',(0,0,5.69),(.5,.59,.5),SKIN,2,3)
mass('Head','head',(0,.02,6.2),(1.42,1.2,1.37),SKIN,4,5)
mass('Jaw','jaw',(0,.26,5.83),(.97,.86,.39),SKINL,2,3)
mass('HairBack','head',(0,-.49,6.23),(1.49,.55,1.25),BLACK,4,5)
mass('HairCap','head',(0,0,6.73),(1.52,1.29,.47),BLACK,2,5)
for side,s in [('L',1),('R',-1)]:
 mass('Ear'+side,'head',(s*.73,.04,6.17),(.26,.33,.43),SKINL,2,2)
 add('Sideburn'+side,'head',(s*.63,.28,6.25),(.2,.37,.63),BLACK)
 for k in range(3):add('Fringe'+side+str(k),'fringe'+side,(s*(.2+k*.18),.56,6.68-(2-k)*.015),(.2,.27,.35-(k%2)*.07),BLACK,(0,0,s*12))
 add('EyeSocket'+side,'head',(s*.34,.594,6.28),(.43,.08,.2),GREY)
 add('EyeWhite'+side,'head',(s*.33,.642,6.27),(.31,.03,.12),IVORY)
 add('EyePupil'+side,'head',(s*.28,.67,6.27),(.1,.03,.12),DARK)
 beam('Brow'+side,'head',(s*.1,.69,6.42),(s*.55,.58,6.5),.13,.09,BLACK)
 add('Cheek'+side,'head',(s*.46,.54,6.05),(.34,.17,.22),SKINL)
add('Nose','head',(0,.68,6.16),(.19,.23,.27),SKINL)
beam('Smile','jaw',(-.27,.68,5.94),(.23,.72,5.97),.035,.025,REDD)
add('Chin','jaw',(0,.51,5.69),(.28,.26,.18),SKIN)
# Broad elliptic brim and tall stepped crown, not a circular mesh.
mass('HatBrim','hat',(0,0,6.87),(2.09,1.76,.2),DARK,1,9)
mass('HatCrown','hat',(0,0,7.43),(1.67,1.39,1.0),BLACK,1,9)
mass('HatTop','hat',(0,0,7.97),(1.77,1.48,.18),GREY,1,9)
mass('HatRibbon','hat',(0,.0,7.11),(1.7,1.43,.26),RED,1,9)
add('HatBuckle','hat',(0,.76,7.11),(.3,.12,.23),GOLD)
add('HatBuckleCentre','hat',(0,.83,7.11),(.13,.02,.11),DARK)
# Fully modeled dagger and a fan of three double-sided cards.
add('DaggerGrip','dagger',(-1.7,.22,3.15),(.17,.21,.46),BLACK)
add('DaggerPommel','dagger',(-1.7,.22,3.41),(.26,.26,.12),GOLD)
add('DaggerGuard','dagger',(-1.7,.22,2.9),(.59,.22,.13),GOLD)
for k in range(6):
 add('DaggerBlade'+str(k),'dagger',(-1.7,.22,2.77-k*.15),(.28-.037*k,.12,.16),STEEL)
 add('DaggerSpine'+str(k),'dagger',(-1.7,.29,2.77-k*.15),(.045,.03,.16),GREY)
for k in [-1,0,1]:
 x,y,z=1.7+k*.2,.32+abs(k)*.05,3.13+abs(k)*.07
 add('Card'+str(k),'cards',(x,y,z),(.43,.07,.66),IVORY,(0,k*8,k*-18))
 for face in [-1,1]:
  add('CardBack'+str(k)+str(face),'cards',(x,y+face*.044,z),(.32,.02,.52),REDD,(0,k*8,k*-18))
  add('CardDiamond'+str(k)+str(face),'cards',(x,y+face*.06,z),(.13,.02,.18),IVORY,(0,0,45))
EXTRA_JSON={'walkSpeed':2.6,'runSpeed':4.5}
CLIP_IMPACTS={'attack':.46,'attack2':.5,'attackdagger':.71,'attackcards':1.02,'attackbox':1.21,'summonrabbits':2.15}
CLIP_FILES={'locomotion':['idle','walk','run','hurt','jump','notactive'],'combat':['attack','attack2','attackdagger','attackcards','phasecards'],
 'magic':['attackbox','summonrabbits','regeneration','active'],'lifecycle':['death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',30),('attackdagger',21.3),('attackcards',30.6),('summonrabbits',64.5),('death',210)]
PREVIEW_CAMERA=((13,23,11),(0,0,4),52)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,4.05),13.6),'side':((0,-1,0),(0,0,1),(0,0,4.05),13.6),'back':((1,0,0),(0,0,1),(0,0,4.05),13.6)}
if __name__=='__main__':run(globals())
