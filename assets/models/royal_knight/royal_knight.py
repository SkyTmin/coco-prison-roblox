"""Original Royal Garden Knight. Our generated concept, articulated cuboid armor, headless only."""
import os,sys,math
from mathutils import Vector
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
sys.path.insert(0,os.path.dirname(os.path.abspath(__file__)))
from blockmob import box,run
from knight_motion import make_actions
NAME='royal_knight';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2.4;GAME_LIFT={'saturate':1,'gain':1};BACKGROUND=(185,182,175)
BAKE_CURVES=True;BATCH_SAMPLE=True;GROUND_CLIPS=['death'];GROUND_SUBSTEPS=4
GROUND_DETACHED={'death':{'sword':(18,58),'shield':(43,80)}}
STEEL=(98,111,122);EDGE=(130,141,148);DARK=(56,65,71);GOLD=(156,132,80);RED=(109,43,46);LEATHER=(64,46,35)
JOINTS=[('root',None,(0,0,0)),('body','root',(0,0,4.55)),('chest','body',(0,0,6.35)),
 ('neck','chest',(0,0,8.12)),('head','neck',(0,0,8.75)),('plume1','head',(0,-.2,9.65)),
 ('plume2','plume1',(0,-.8,10.18)),('plume3','plume2',(0,-1.55,9.68)),
 ('cape1','chest',(0,-.92,7.9)),('cape2','cape1',(0,-1.15,6.4)),('cape3','cape2',(0,-1.3,4.8)),
 ('clothFront','body',(0,.8,4.8)),('clothL','body',(1,.05,4.75)),('clothR','body',(-1,.05,4.75))]
for side,s in [('L',1),('R',-1)]:
 JOINTS += [('arm'+side,'chest',(s*1.96,0,7.8)),('fore'+side,'arm'+side,(s*2.45,.02,6.14)),
  ('hand'+side,'fore'+side,(s*2.7,.15,4.72)),('fingers'+side,'hand'+side,(s*2.7,.45,4.52)),
  ('leg'+side,'body',(s*.85,0,4.55)),('shin'+side,'leg'+side,(s*1.02,.12,2.5)),('foot'+side,'shin'+side,(s*1.1,0,.48))]
JOINTS += [('sword','handR',(-2.7,.25,4.6)),('shield','handL',(2.8,.6,5.1))]
PARTS=[]
def add(n,j,c,size,color,rot=(0,0,0)):
 x,y,z=c;w,d,h=[v/2 for v in size];PARTS.extend(box(n,j,(x-w,x+w),(y-d,y+d),(z-h,z+h),color,rot=rot))
def mass(n,j,c,size,color,layers=3,slices=3):
 x,y,z=c;w,d,h=size
 for i in range(layers):
  u=(i+.5)/layers*2-1;r=math.sqrt(1-u*u)
  for k in range(slices):
   v=(k+.5)/slices*2-1;rr=math.sqrt(1-v*v)
   add(f'{n}{i}_{k}',j,(x,y+v*d*r/2,z-h/2+(i+.5)*h/layers),(w*r*rr,d*r/slices,h/layers),color)
def beam(n,j,a,b,w,d,col):
 a,b=Vector(a),Vector(b);v=b-a
 add(n,j,tuple((a+b)/2),(w,d,v.length),col,tuple(math.degrees(x) for x in v.to_track_quat('Z','Y').to_euler()))
def leaf(n,j,x,y,z,scale=1):
 add(n+'Stem',j,(x,y,z),(.12*scale,.06,.95*scale),GOLD)
 for sign in [-1,1]:
  for i in range(2):beam(n+str(sign)+str(i),j,(x,y,z+(.1-i*.3)*scale),(x+sign*.31*scale,y,z+(.32-i*.3)*scale),.12*scale,.06,GOLD)
# Backplate, breastplate and flexible overlapping waist lames have actual depth on every side.
mass('MailBody','body',(0,0,5.65),(2.8,1.65,2.55),DARK,4,3)
mass('Breast','chest',(0,.1,7.05),(3.35,1.9,2.0),STEEL,4,4)
mass('Backplate','chest',(0,-.65,7.05),(2.75,.62,1.7),DARK,3,3)
for i in range(3):
 mass('WaistLame'+str(i),'body',(0,.03,5.25+i*.34),(2.9-i*.1,1.73,.32),STEEL,1,4)
 add('LameTrim'+str(i),'body',(0,.94,5.08+i*.34),(2.35-i*.1,.07,.08),EDGE)
for s in [-1,1]:
 beam('BreastEdge'+str(s),'chest',(s*.1,1.02,6.2),(s*1.3,.91,7.7),.13,.11,EDGE)
 add('Strap'+str(s),'chest',(s*1.22,-1.02,7.1),(.25,.14,1.6),LEATHER)
leaf('BreastLeaf','chest',0,1.09,7.0,.85)
mass('Belt','body',(0,.02,4.87),(3.15,1.9,.36),LEATHER,1,4)
add('Buckle','body',(0,1.02,4.89),(.65,.16,.4),GOLD);add('BuckleInset','body',(0,1.12,4.89),(.34,.05,.19),DARK)
for side,s in [('L',1),('R',-1)]:
 mass('ShoulderUnder'+side,'arm'+side,(s*2.05,0,7.65),(1.35,1.55,1.28),DARK)
 for k in range(3):
  mass('Pauldron'+side+str(k),'arm'+side,(s*(2.1+.1*k),0,8.02-k*.36),(1.65+.13*k,1.85+.06*k,.46),STEEL,2,3)
  add('ShoulderRim'+side+str(k),'arm'+side,(s*(2.12+.1*k),.82,7.82-k*.36),(1.36,.1,.09),GOLD)
 beam('MailSleeve'+side,'arm'+side,(s*2.15,0,7.25),(s*2.43,.01,6.22),.78,.89,DARK)
 for k in range(5):
  for n in range(3):add(f'Mail{side}{k}{n}','arm'+side,(s*(2.3+(n-1)*.24),.46,6.35+k*.16),(.13,.07,.09),EDGE if (k+n)%2 else STEEL)
 mass('Elbow'+side,'fore'+side,(s*2.45,.08,6.1),(1.03,1.12,.74),STEEL)
 beam('Vambrace'+side,'fore'+side,(s*2.48,.04,5.96),(s*2.69,.16,4.88),.79,.82,STEEL)
 for z,x in [(5.75,2.52),(5.0,2.66)]:add('Cuff'+side+str(z),'fore'+side,(s*x,.61,z),(.77,.13,.15),GOLD)
 mass('Gauntlet'+side,'hand'+side,(s*2.7,.2,4.55),(.9,.94,.76),DARK,2,3)
 for k in range(3):
  add('HandPlate'+side+str(k),'hand'+side,(s*2.7,.64,4.77-k*.17),(.83,.16,.15),STEEL)
  add('Finger'+side+str(k),'fingers'+side,(s*(2.44+k*.25),.53,4.32),(.21,.4,.34),STEEL)
 beam('Thigh'+side,'leg'+side,(s*.85,0,4.4),(s*1.02,.12,2.65),1.1,1.16,DARK)
 for k in range(3):
  add('Tasset'+side+str(k),'cloth'+side,(s*(1.12+.04*k),.68,4.59-k*.3),(.8,.3,.36),STEEL,(-5,0,s*8))
  add('TassetEdge'+side+str(k),'cloth'+side,(s*(1.12+.04*k),.85,4.42-k*.3),(.72,.08,.07),GOLD)
 mass('Knee'+side,'shin'+side,(s*1.02,.27,2.61),(1.32,1.4,.95),STEEL)
 add('KneeFace'+side,'shin'+side,(s*1.02,1.0,2.68),(.71,.14,.56),EDGE,(-12,0,0))
 beam('Greave'+side,'shin'+side,(s*1.04,.13,2.22),(s*1.1,0,.61),.86,.94,STEEL)
 beam('GreaveRidge'+side,'shin'+side,(s*1.04,.65,2.1),(s*1.1,.52,.73),.16,.13,EDGE)
 mass('Boot'+side,'foot'+side,(s*1.1,.34,.31),(1.32,1.89,.6),DARK,2,4)
 for k in range(3):add('Sabaton'+side+str(k),'foot'+side,(s*1.1,.27+k*.36,.49-k*.075),(1.12,.42,.18),STEEL)
 add('AnkleTrim'+side,'foot'+side,(s*1.1,.56,.75),(.98,.11,.13),GOLD)
mass('Gorget','neck',(0,0,8.2),(1.8,1.55,.65),DARK,2,4)
mass('Helm','head',(0,0,9.02),(1.92,1.85,1.75),STEEL,5,5)
add('VisorDark','head',(0,.91,9.0),(1.6,.13,.27),(22,25,27))
add('Brow','head',(0,1.02,9.22),(1.68,.15,.14),GOLD)
add('Nasal','head',(0,1.05,8.93),(.16,.16,1.1),GOLD)
for s in [-1,1]:
 add('Cheek'+str(s),'head',(s*.53,.94,8.63),(.66,.32,.56),STEEL,(0,s*8,0))
 for k in range(3):add('Vent'+str(s)+str(k),'head',(s*(.27+k*.19),1.115,8.64),(.065,.025,.16),DARK)
 add('HelmRivet'+str(s),'head',(s*.83,.63,9.08),(.12,.14,.13),GOLD)
# Three independently lagging plume segments, and three cape segments.
for j,y,z,h,d in [('plume1',-.2,10.0,.68,.75),('plume2',-.85,10.05,.76,.85),('plume3',-1.7,9.33,1.2,.55)]:
 for k in range(3):add(j+str(k),j,((k-1)*.18,y,z-k*.045),(.17,d,h),RED if k%2 else (91,33,36),(-20,0,0))
for index,(j,z,y,height,width) in enumerate([('cape1',7.18,-1.17,1.6,2.85),('cape2',5.62,-1.35,1.65,2.5),('cape3',4.05,-1.55,1.7,2.25)]):
 for k in range(7):
  h=height-(.13*(k%3) if index==2 else 0)
  add(j+str(k),j,((k-3)*width/7,y-.06*(k%2),z+(height-h)/2),(width/7+.005,.13,h),RED if k%2 else (84,32,36),(-6,0,0))
for k in range(5):
 h=2.7-.13*abs(k-2);add('Tabard'+str(k),'clothFront',((k-2)*.23,.99,4.7-h/2),(.23,.14,h),RED if k%2 else (92,35,39))
 if k in [0,4]:add('TabardTrim'+str(k),'clothFront',((k-2)*.23,1.075,4.7-h/2),(.055,.035,h),GOLD)
# Longsword blade points down in the bind pose; its hand carries its full transform.
add('Grip','sword',(-2.7,.35,4.5),(.23,.25,.92),LEATHER)
add('Pommel','sword',(-2.7,.35,5.03),(.39,.37,.3),GOLD)
add('Crossguard','sword',(-2.7,.35,4.05),(1.33,.28,.2),GOLD)
for k in range(11):
 w=.52 if k<8 else .52*(11-k)/4;z=3.86-k*.31
 add('Blade'+str(k),'sword',(-2.7,.35,z),(w,.18,.32),EDGE)
 add('Fuller'+str(k),'sword',(-2.7,.455,z),(w*.28,.035,.31),STEEL)
for k in range(8):
 z=6.42-k*.38;w=2.08 if k<4 else 2.08*(8-k)/5
 add('ShieldWood'+str(k),'shield',(3.05,.83,z),(w,.35,.4),LEATHER)
 add('ShieldFace'+str(k),'shield',(3.05,1.04,z),(max(.15,w-.2),.1,.36),RED)
 for s in [-1,1]:add('ShieldRim'+str(k)+str(s),'shield',(3.05+s*(w/2-.06),1.08,z),(.13,.12,.4),GOLD)
add('ShieldTop','shield',(3.05,1.08,6.63),(2.13,.14,.12),GOLD)
leaf('ShieldLeaf','shield',3.05,1.13,5.3,1.15)
EXTRA_JSON={'walkSpeed':4.8,'runSpeed':8.0}
CLIP_IMPACTS={'c1':.3,'c2':.31,'c3':.33,'c4':.5,'c5':.56,'berserkerleap':1.35,'viciousstrike':2.85,'strikeoffury1':1.1,'strikeoffury2':1.3,'relentlesswhirlwindpierce':.32}
CLIP_FILES={'locomotion':['idle','walk','run','jump','hurt'], 'combos':['c1','c2','c3','c4','c5'],
 'mobility':['dashfront','dashback','dashleft','dashright','berserkerleap'],
 'fury':['strikeoffury1','strikeoffury2','viciousstrike'],
 'guard':['startcombat','bloodboundbarrier','bulwarkinstinct','flinch','relentlesswhirlwindspin','relentlesswhirlwindpierce'], 'lifecycle':['death']}
def actions():return make_actions(JOINTS)
PREVIEWS=[('idle',20),('c1',9),('berserkerleap',28),('viciousstrike',75),('bloodboundbarrier',10),('death',105)]
PREVIEW_CAMERA=((16,27,13),(0,.1,5.2),49)
COMPARE={'front':((-1,0,0),(0,0,1),(0,0,5.2),17),'side':((0,1,0),(0,0,1),(0,0,5.2),17),'back':((1,0,0),(0,0,1),(0,0,5.2),17)}
if __name__=='__main__':run(globals())
