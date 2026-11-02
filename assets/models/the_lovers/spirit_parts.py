"""Original cloth/hair archer and articulated asymmetric yumi; no emissive surfaces."""
import math
from undead_king.necromancer_parts import Geometry
CLOTH=(126,148,148);EDGE=(164,174,160);INNER=(49,60,77);HAIR=(27,37,48);SASH=(111,60,66)
SKIN=(185,163,141);WOOD=(66,51,41);STRING=(164,153,128)

def geometry():
 j=[('root',None,(0,0,0)),('body','root',(0,0,3.1)),('chest','body',(0,0,4.45)),('neck','chest',(0,0,5.85)),('head','neck',(0,.01,6.23))]
 for side,s in [('L',1),('R',-1)]:
  j += [('arm'+side,'chest',(s*1.06,0,5.46)),('fore'+side,'arm'+side,(s*1.29,.03,4.42)),('hand'+side,'fore'+side,(s*1.44,.15,3.41)),
   ('fingers'+side,'hand'+side,(s*1.44,.29,3.25)),('leg'+side,'body',(s*.51,0,3.1)),('shin'+side,'leg'+side,(s*.61,0,1.69)),('foot'+side,'shin'+side,(s*.65,.05,.29)),
   ('sleeve'+side,'fore'+side,(s*1.31,0,4.22)),('skirtFront'+side,'body',(s*.43,.47,3.5)),('skirtBack'+side,'body',(s*.43,-.48,3.5)),
   ('hair'+side+'1','head',(s*.6,-.02,6.61)),('hair'+side+'2','hair'+side+'1',(s*.66,.12,5.63))]
 j += [('hairBack1','head',(0,-.48,6.61)),('hairBack2','hairBack1',(0,-.63,5.5)),('hairBack3','hairBack2',(0,-.76,4.31)),
  ('ribbon','head',(0,-.74,6.36)),('bow','handL',(1.44,.15,3.41)),('bowUpper','bow',(1.44,.15,3.41)),('bowLower','bow',(1.44,.15,3.41)),
  ('stringUpper','bow',(1.44,-.25,3.51)),('stringLower','bow',(1.44,-.25,3.51)),('arrow','bow',(1.44,-.25,3.51))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam
 mass('Waist','body',(0,0,3.77),(1.45,1.04,1.38),INNER,4,5)
 mass('Chest','chest',(0,0,5.0),(1.96,1.17,1.54),CLOTH,4,5)
 for side,s in [('L',1),('R',-1)]:
  beam('Collar'+side,'chest',(s*.47,.47,5.73),(-s*.28,.69,4.68),.22,.13,EDGE)
  beam('InnerCollar'+side,'chest',(s*.35,.52,5.69),(-s*.16,.73,4.77),.1,.07,INNER)
  mass('UpperSleeve'+side,'arm'+side,(s*1.17,0,4.97),(.81,1.08,1.1),CLOTH,4,5)
  mass('ForeSleeve'+side,'fore'+side,(s*1.37,.06,3.99),(.83,1.15,1.06),CLOTH,4,5)
  # Hanging sleeve volume is distinct from the hand and elbow, with a dark lining.
  for k in range(4):
   x=s*(1.43+.05*k);z=3.94-k*.29
   add('SleevePanel'+side+str(k),'sleeve'+side,(x,-.28,z),(.88-k*.08,.22,.34),CLOTH)
   add('SleeveLining'+side+str(k),'sleeve'+side,(x,-.14,z),(.72-k*.07,.08,.32),INNER)
   add('SleeveHem'+side+str(k),'sleeve'+side,(x+s*(.43-k*.04),-.22,z),(.08,.24,.32),EDGE)
  mass('Palm'+side,'hand'+side,(s*1.44,.16,3.34),(.48,.48,.45),SKIN,3,4)
  for k in range(4):beam('Finger'+side+str(k),'fingers'+side,(s*1.44+(k-1.5)*.115,.3,3.27),(s*1.44+(k-1.5)*.115,.42,3.0+abs(k-1.5)*.03),.105,.13,SKIN)
  mass('LegCloth'+side,'leg'+side,(s*.56,0,2.47),(.81,.94,1.39),INNER,3,4)
  mass('ShinCloth'+side,'shin'+side,(s*.63,0,1.03),(.62,.78,1.3),INNER,3,4)
  mass('Foot'+side,'foot'+side,(s*.65,.25,.23),(.75,1.14,.43),EDGE,2,4)
  add('Sandal'+side,'foot'+side,(s*.65,.26,.06),(.81,1.21,.12),WOOD)
  for k in[-1,1]:beam('FootStrap'+side+str(k),'foot'+side,(s*.65,.73,.39),(s*.65+k*.32,.11,.37),.075,.08,SASH)
  for front,y,col in [('Front',.57,CLOTH),('Back',-.6,CLOTH)]:
   joint='skirt'+front+side
   for row in range(6):
    z=3.35-row*.49;w=.85+row*.08;x=s*(.48+row*.028)
    add('Skirt'+front+side+str(row),joint,(x,y+(.05*row if front=='Front'else-.05*row),z),(w,.18,.54),col)
    for k in[-1,0,1]:add('Pleat'+front+side+str(row)+str(k),joint,(x+k*w*.28,y+(.12+.05*row if front=='Front'else-.12-.05*row),z),(.075,.07,.54),EDGE if k==-1 else INNER)
   add('SashTail'+front+side,joint,(s*.48,y+(.18 if front=='Front'else-.18),2.65),(.17,.1,1.65),SASH)
  for k in range(2):
   joint='hair'+side+str(k+1)
   for stripe in range(3):beam('SideHair'+side+str(k)+str(stripe),joint,(s*(.49+stripe*.12),.08+k*.06,6.65-k*.96),(s*(.58+stripe*.13),.21+k*.04,5.56-k*.94),.15,.19,HAIR)
 mass('Neck','neck',(0,0,5.88),(.58,.62,.45),SKIN,2,4)
 mass('Head','head',(0,.01,6.39),(1.13,1.04,1.29),SKIN,5,5)
 mass('HairCap','head',(0,-.14,6.72),(1.25,1.13,.88),HAIR,4,5)
 for s in[-1,1]:
  add('Eye'+str(s),'head',(s*.27,.55,6.47),(.18,.055,.095),HAIR)
  beam('Brow'+str(s),'head',(s*.1,.58,6.65),(s*.43,.53,6.61),.07,.06,HAIR)
  beam('Fringe'+str(s),'head',(s*.22,.47,6.98),(s*.47,.58,6.62),.19,.13,HAIR)
 add('Nose','head',(0,.59,6.31),(.13,.16,.24),SKIN)
 add('Mouth','head',(0,.54,6.1),(.25,.045,.045),SASH)
 for tier in range(3):
  for k in range(7):
   x=(k-3)*(.16+tier*.035);z=6.63-tier*1.13
   beam('BackHair'+str(tier)+str(k),'hairBack'+str(tier+1),(x,-.58-tier*.15,z),(x*1.13,-.75-tier*.17,z-1.32+abs(k-3)*.035),.19,.2,HAIR)
 for s in[-1,1]:add('RibbonLoop'+str(s),'ribbon',(s*.27,-.81,6.37),(.48,.17,.32),SASH,(0,s*15,s*12))
 for s in[-1,1]:beam('RibbonTail'+str(s),'ribbon',(s*.1,-.81,6.28),(s*.29,-.89,5.27),.17,.11,SASH)
 mass('Obi','body',(0,0,3.99),(1.65,1.2,.47),SASH,2,5)
 for side,s in [('L',1),('R',-1)]:add('ObiBack'+side,'body',(s*.28,-.73,4.02),(.54,.27,.44),SASH,(0,0,s*13))
 # Yumi handle rests in the left palm; its upper limb is distinctly longer.
 x=1.44;y=.15;z=3.41
 add('BowGrip','bow',(x,y,z),(.15,.19,.61),SASH)
 for name,length,sign in [('Upper',3.9,1),('Lower',2.6,-1)]:
  for k in range(8):
   a=k/8;b=(k+1)/8
   pa=(x,y+.29*math.sin(a*math.pi),z+sign*length*a)
   pb=(x,y+.29*math.sin(b*math.pi),z+sign*length*b)
   beam('Bow'+name+str(k),'bow'+name,pa,pb,.13-.04*a,.14,WOOD)
  beam('String'+name,'string'+name,(x,y-.4,z+.1),(x,y,z+sign*length),.025,.025,STRING)
 beam('ArrowShaft','arrow',(x,y-.4,z+.1),(x,y+1.9,z+.1),.065,.065,WOOD)
 for k in[-1,1]:beam('ArrowFeather'+str(k),'arrow',(x,y-.4,z+.1),(x+k*.13,y-.14,z+.1),.06,.09,EDGE)
 add('ArrowTip','arrow',(x,y+1.98,z+.1),(.13,.22,.13),EDGE)
 return j,g.parts
