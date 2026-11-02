"""Original hooded spirit, closed robe volumes and independently gripped scythe."""
import math,random
from undead_king.necromancer_parts import Geometry
DARK=(48,54,52);CLOTH=(57,69,61);EDGE=(77,86,75);JADE=(115,155,137);BONE=(179,181,160);BRONZE=(139,115,80);SOCKET=(25,31,28)
def geometry():
 j=[('root',None,(0,0,0)),('body','root',(0,0,4.2)),('chest','body',(0,0,6)),('neck','chest',(0,0,7.5)),('head','neck',(0,0,8.2)),('jaw','head',(0,.64,7.97))]
 for side,s in [('L',1),('R',-1)]:
  j += [('arm'+side,'chest',(s*1.48,0,7.2)),('fore'+side,'arm'+side,(s*1.85,.02,5.65)),('hand'+side,'fore'+side,(s*2.05,.1,4.15)),('thumb'+side,'hand'+side,(s*1.78,.31,4.28)),
   ('leg'+side,'body',(s*.62,0,4.2)),('shin'+side,'leg'+side,(s*.67,.03,2.3)),('foot'+side,'shin'+side,(s*.73,.1,.45)),
   ('mantle'+side+'1','chest',(s*1.3,-.1,7.4)),('mantle'+side+'2','mantle'+side+'1',(s*1.61,-.22,6.88))]
  for k in range(3):j.append(('finger'+side+str(k),'hand'+side,(s*(1.83+k*.2),.35,4.05)))
  for face,y in [('F',.65),('B',-.65)]:
   j += [('robe'+face+side+'1','body',(s*.56,y,4.6)),('robe'+face+side+'2','robe'+face+side+'1',(s*.84,y*1.5,2.6))]
 for k in range(3):j.append(('crown'+str(k),'head',((k-1)*.55,-.02,9.05)))
 j += [('weapon','handR',(-2.05,.35,4.15)),('blade','weapon',(-2.05,.35,9.1))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam;rng=random.Random(9013)
 mass('Waist','body',(0,0,4.95),(1.9,1.45,1.8),DARK,4,5)
 mass('Chest','chest',(0,-.04,6.65),(2.75,1.75,1.82),DARK,4,5)
 # Vertical seam strips and wraparound fabric avoid a featureless front or empty back.
 for facing in [-1,1]:
  for k in range(7):
   x=(k-3)*.31;y=facing*(.7+.15*math.cos(x))
   add('TorsoFold'+str(facing)+str(k),'chest',(x,y,6.56),(.22,.16,1.53),CLOTH if k%2 else EDGE)
  beam('Belt'+str(facing),'body',(-.9,facing*.69,5.26),(.9,facing*.69,5.26),.18,.16,BRONZE)
 # Hood consists of sides, closed back, layered dome and deep inner cavity.
 mass('HoodBack','head',(0,-.39,8.47),(1.7,.87,1.61),DARK,4,5)
 for side,s in [('L',1),('R',-1)]:
  add('HoodSide'+side,'head',(s*.68,.14,8.35),(.38,1.12,1.45),DARK,(0,s*7,0))
  beam('HoodRim'+side,'head',(s*.55,.78,8.96),(s*.82,.75,7.8),.17,.22,EDGE)
 for k in range(4):add('HoodTop'+str(k),'head',(0,-.06,9.03+k*.07),(1.57-k*.22,1.28-k*.07,.16),DARK)
 add('FaceShadow','head',(0,.45,8.37),(1.07,.25,1.11),SOCKET)
 mass('Skull','head',(0,.65,8.43),(.84,.46,.77),BONE,3,4)
 for side,s in [('L',1),('R',-1)]:
  add('EyeSocket'+side,'head',(s*.21,.902,8.55),(.26,.025,.25),SOCKET)
  add('Eye'+side,'head',(s*.21,.925,8.55),(.075,.02,.08),JADE)
  add('Cheek'+side,'head',(s*.31,.89,8.25),(.17,.09,.19),BONE)
 add('Nose','head',(0,.93,8.34),(.13,.035,.18),SOCKET)
 add('Jaw','jaw',(0,.73,8.04),(.57,.36,.24),BONE)
 for k in range(5):add('Tooth'+str(k),'jaw',((k-2)*.095,.95,8.14),(.065,.045,.16),BONE)
 for k in range(3):
  x=(k-1)*.55;height=.63 if k==1 else .44
  add('CrownProng'+str(k),'crown'+str(k),(x,-.02,9.15+height*.5),(.15,.18,height),BRONZE)
  add('CrownCap'+str(k),'crown'+str(k),(x,-.02,9.15+height),(.25,.26,.18),BRONZE)
 for side,s in [('L',1),('R',-1)]:
  for name,joint,c,size,col in [('Upper','arm',(s*1.66,.01,6.46),(.72,.83,1.53),DARK),('Elbow','fore',(s*1.85,.02,5.65),(.62,.66,.53),SOCKET),('Sleeve','fore',(s*1.97,.05,4.92),(.86,.95,1.38),DARK),('Palm','hand',(s*2.05,.16,4.02),(.67,.54,.53),BONE)]:mass(name+side,joint+side,c,size,col,3,4)
  for k in range(3):
   x=s*(1.83+k*.2)
   beam('Finger'+side+str(k),'finger'+side+str(k),(x,.35,4.05),(x,.48,3.66),.15,.16,BONE)
   beam('Tip'+side+str(k),'finger'+side+str(k),(x,.48,3.66),(x,.73,3.72),.14,.15,BONE)
  beam('Thumb'+side,'thumb'+side,(s*1.78,.31,4.28),(s*1.67,.55,3.99),.17,.18,BONE)
  beam('ThumbTip'+side,'thumb'+side,(s*1.67,.55,3.99),(s*1.85,.7,3.88),.16,.17,BONE)
  for z in [4.48,5.02]:add('CuffLine'+side+str(z),'fore'+side,(s*1.99,.55,z),(.71,.075,.1),JADE)
  for x in [s*1.73,s*2.25]:add('CuffUpright'+side+str(x),'fore'+side,(x,.55,4.75),(.09,.075,.57),JADE)
  mass('Thigh'+side,'leg'+side,(s*.65,0,3.28),(.88,.95,1.84),DARK,3,3)
  mass('Shin'+side,'shin'+side,(s*.7,.05,1.43),(.79,.86,1.78),DARK,3,3)
  mass('Boot'+side,'foot'+side,(s*.73,.3,.4),(.93,1.46,.78),DARK,3,4)
  add('BootToe'+side,'foot'+side,(s*.73,.91,.27),(.86,.32,.44),EDGE)
  # Overlapping mantle scales, each lower layer follows its parent with a small delay.
  for layer in [1,2]:
   for row in range(3):
    for k in range(4):
     x=s*(.65+k*.32+layer*.13);y=-.62+row*.61;z=7.65-layer*.21-k*.1
     add('Mantle'+side+str(layer)+str(row)+str(k),'mantle'+side+str(layer),(x,y,z),(.51,.66,.22),CLOTH if (k+row)%2 else EDGE,(0,s*18,0))
  for face,y in [('F',.78),('B',-.78)]:
   for level in [1,2]:
    joint='robe'+face+side+str(level);top=5.03 if level==1 else 3.08;h=2.46 if level==1 else 2.35
    for row in range(6):
     u=row/5;width=(1.05 if level==1 else 1.35)+u*.36
     yy=y*(1+.12*u);zz=top-(row+.5)*h/6
     if row<5:add('RobePanel'+face+side+str(level)+str(row),joint,(s*(.06+width/2),yy,zz),(width,.26,h/6+.035),CLOTH)
     for col in range(6):
      xx=s*(.06+(col+.5)*width/6);end=.11 if row==5 and col%3==0 else 0
      add('RobeWeave'+face+side+str(level)+str(row)+str(col),joint,(xx,yy+(1 if y>0 else -1)*.14,zz+end/2),(width/6+.01,.04 if row<5 else .26,h/6-end+.02),EDGE if rng.random()<.2 else DARK if col%3==0 else CLOTH)
  for level in [1,2]:
   joint='robeF'+side+str(level);top=5.0 if level==1 else 3.03;h=2.36 if level==1 else 2.25
   for row in range(6):
    width=(1.05 if level==1 else 1.35)+row/5*.36
    add('SideRobe'+side+str(level)+str(row),joint,(s*(width+.06),0,top-(row+.5)*h/6),(.19,1.65,h/6+.03),DARK if row%3==0 else CLOTH)
 # Matte geometric chest embroidery, not an emissive orb.
 add('Pendant','chest',(0,.98,6.92),(.56,.12,.55),BRONZE)
 add('PendantInset','chest',(0,1.05,6.92),(.31,.04,.29),JADE)
 for x in [-.18,.18]:beam('ChestInlay'+str(x),'chest',(x,1.0,6.6),(x,.91,5.82),.09,.06,JADE)
 beam('InlayBar','chest',(-.36,.94,5.93),(.36,.94,5.93),.09,.06,JADE)
 # Weapon geometry belongs to a gripped joint and a child blade, never per-box physics.
 beam('Shaft','weapon',(-2.05,.35,.6),(-2.05,.35,9.25),.22,.24,(81,68,52))
 for z in [.65,2.5,5.1,8.65,9.13]:add('ShaftCollar'+str(z),'weapon',(-2.05,.35,z),(.37,.38,.25),BRONZE)
 for k in range(17):add('Grip'+str(k),'weapon',(-2.05,.35,2.9+k*.09),(.26,.28,.07),DARK,(0,0,k*13))
 for k in range(13):
  u=k/12;x=-2.12-u*3.7;z=9.35+.34*math.sin(u*math.pi)-u*u*1.38
  h=.69*(1-u)+.13
  add('Blade'+str(k),'blade',(x,.35,z),(.37,.18,h),JADE if k%3 else (139,164,149),(0,-12-u*38,0))
  add('BladeEdge'+str(k),'blade',(x,.45,z-h*.4),(.35,.06,.11),BONE,(0,-12-u*38,0))
 for k in range(3):add('BladeSocket'+str(k),'blade',(-2.04-k*.13,.35,9.15+k*.03),(.26,.37,.82-k*.13),BRONZE)
 return j,g.parts
