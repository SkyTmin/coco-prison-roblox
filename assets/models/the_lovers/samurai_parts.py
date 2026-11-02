"""Original red/gold lamellar armor, complete underrobe and continuous curved katana."""
from mathutils import Vector
from undead_king.necromancer_parts import Geometry
from raven_knight.knight_parts import geometry as knight_skeleton
RED=(112,47,39);EDGE=(157,128,75);GOLD=(186,158,95);CLOTH=(31,34,43);DARK=(23,23,28)
STEEL=(132,141,143);BLADE=(186,191,184);CORD=(98,50,48);SKIN=(130,96,74)

def geometry():
 j,_=knight_skeleton()
 j += [('cuirass','chest',(0,0,7.4)),('helmet','head',(0,0,8.4)),('scabbard','body',(1.15,.02,4.6))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam
 def plate(n,j,c,width,height,rows=4,back=False):
  x,y,z=c;sign=-1 if back else 1
  for row in range(rows):
   zz=z+height/2-(row+.5)*height/rows
   add(n+str(row),j,(x,y,zz),(width,.18,height/rows+.04),RED)
   add(n+'Edge'+str(row),j,(x,y+sign*.11,zz-height/rows/2+.025),(width+.03,.045,.065),EDGE)
   for col in[-1,0,1]:add(n+'Lace'+str(row)+str(col),j,(x+col*width*.29,y+sign*.13,zz),(.07,.05,height/rows*.76),CORD)
   for col in[-1,1]:add(n+'Stud'+str(row)+str(col),j,(x+col*width*.42,y+sign*.13,zz+.035),(.06,.055,.07),GOLD)
 mass('RobeWaist','body',(0,0,5.08),(2.12,1.5,1.76),CLOTH,4,5)
 mass('RobeChest','chest',(0,-.03,6.83),(2.92,1.75,1.98),CLOTH,4,5)
 plate('ChestFront','cuirass',(0,.94,6.82),2.55,1.73,5)
 plate('ChestBack','cuirass',(0,-.96,6.82),2.53,1.73,5,True)
 for side,s in [('L',1),('R',-1)]:
  # Side seams close the armor around a fully modeled underlying torso.
  for row in range(5):mass('ArmorSide'+side+str(row),'cuirass',(s*1.32,0,6.14+row*.34),(.32,1.76,.3),RED,1,4)
  beam('ShoulderStrap'+side,'cuirass',(s*.88,.91,7.51),(s*.91,-.91,7.51),.23,.16,RED)
  for y in[-.97,.97]:add('ChestClasp'+side+str(y),'cuirass',(s*.9,y,7.45),(.27,.12,.3),EDGE)
  mass('UpperSleeve'+side,'arm'+side,(s*1.76,0,6.46),(1.02,1.18,1.41),CLOTH,4,5)
  mass('ElbowCloth'+side,'fore'+side,(s*1.94,.04,5.68),(.78,.89,.6),CLOTH,2,4)
  mass('BracerBase'+side,'fore'+side,(s*2.05,.12,4.98),(.92,1.0,1.2),DARK,4,4)
  for k in[-1,0,1]:
   beam('BracerSlat'+side+str(k),'fore'+side,(s*1.98+k*.25,.59,5.47),(s*2.14+k*.23,.65,4.43),.18,.13,RED)
   beam('BracerTrim'+side+str(k),'fore'+side,(s*1.98+k*.25-.09,.66,5.47),(s*2.14+k*.23-.09,.72,4.43),.045,.05,EDGE)
  for z in[4.48,5.46]:mass('BracerCord'+side+str(z),'fore'+side,(s*2.06,.12,z),(1.0,1.08,.11),CORD,1,5)
  mass('Palm'+side,'hand'+side,(s*2.16,.17,4.04),(.68,.67,.58),CLOTH,3,4)
  for k in range(4):
   x=s*2.16+(k-1.5)*.16;length=.4-abs(k-1.5)*.05
   beam('Finger'+side+str(k),'fingers'+side,(x,.42,3.98),(x,.51,3.98-length),.14,.17,DARK)
   add('FingerPlate'+side+str(k),'fingers'+side,(x,.55,3.87),(.14,.08,.18),STEEL)
  beam('Thumb'+side,'thumb'+side,(s*1.89,.38,4.14),(s*1.83,.62,3.85),.18,.2,CLOTH)
  mass('ThighRobe'+side,'leg'+side,(s*.83,0,3.49),(1.27,1.39,1.7),CLOTH,4,5)
  for k in[-1,0,1]:beam('TrouserFold'+side+str(k),'leg'+side,(s*.77+k*.28,.67,4.08),(s*.89+k*.25,.62,2.71),.08,.08,DARK)
  mass('Knee'+side,'shin'+side,(s*.89,.07,2.45),(1.0,1.05,.59),CLOTH,2,4)
  mass('ShinCloth'+side,'shin'+side,(s*.92,.02,1.5),(.84,.94,1.55),CLOTH,3,4)
  for k in[-1,0,1]:
   beam('Greave'+side+str(k),'shin'+side,(s*.89+k*.25,.56,2.2),(s*.94+k*.21,.51,.78),.18,.16,RED)
   beam('GreaveTrim'+side+str(k),'shin'+side,(s*.89+k*.25-.08,.66,2.2),(s*.94+k*.21-.08,.61,.78),.04,.05,EDGE)
  for z in[.83,2.15]:mass('ShinCord'+side+str(z),'shin'+side,(s*.92,.02,z),(.99,1.08,.12),CORD,1,5)
  mass('FootCloth'+side,'foot'+side,(s*.94,.18,.37),(1.04,1.55,.63),CLOTH,3,5)
  add('SandalSole'+side,'foot'+side,(s*.94,.25,.09),(1.12,1.65,.18),EDGE)
  for xx in[-.26,.26]:mass('SplitToe'+side+str(xx),'foot'+side,(s*.94+xx,.87,.27),(.47,.48,.36),DARK,2,3)
  for k in range(3):beam('SandalStrap'+side+str(k),'foot'+side,(s*.94-.48,.13+k*.24,.35),(s*.94+.48,.13+k*.24,.35),.1,.1,EDGE)
  mass('Ankle'+side,'foot'+side,(s*.94,.04,.69),(.79,.86,.39),CLOTH,2,3)
  plate('SkirtFront'+side,'tasset'+side,(s*.77,.84,3.97),.83,1.35,4)
  plate('SkirtBack'+side,'cape'+side+'2',(s*.77,-.85,4.06),.88,1.36,4,True)
  # Sode plates are hinged separately from the arm and can be shed at phase transition.
  mass('SodeTop'+side,'shoulder'+side,(s*1.61,-.02,7.39),(1.39,1.62,.56),RED,2,5)
  for row in range(4):
   x=s*(1.68+row*.13);z=7.34-row*.27
   for col in range(5):
    y=(col-2)*.31
    add('Sode'+side+str(row)+str(col),'wing'+side,(x,y,z),(.64,.33,.32),RED,(0,-s*21,0))
    add('SodeStud'+side+str(row)+str(col),'wing'+side,(x+s*.34,y,z-.08),(.07,.08,.08),EDGE)
  beam('BackCord'+side,'cuirass',(s*1.0,-1.05,7.48),(0,-1.13,6.12),.13,.13,CORD)
  beam('Collar'+side,'chest',(s*.63,.54,7.76),(0,.89,6.76),.2,.13,RED)
 add('Belt','body',(0,.82,4.68),(2.2,.18,.3),CORD)
 for k in range(3):beam('BeltKnot'+str(k),'body',(-.34,.97,4.58+k*.12),(.34,.97,4.73-k*.1),.14,.12,CORD)
 for k in range(3):add('SashTail'+str(k),'clothFront',((k-1)*.15,.94,3.84-k*.12),(.17,.13,1.65-.21*k),CORD)
 mass('Neck','neck',(0,0,7.95),(.78,.81,.51),SKIN,2,4)
 mass('Head','head',(0,-.01,8.55),(1.23,1.15,1.34),SKIN,5,5)
 mass('Hair','head',(0,-.21,8.76),(1.3,1.02,1.14),DARK,4,4)
 for s in[-1,1]:
  add('Eye'+str(s),'head',(s*.29,.584,8.7),(.22,.055,.085),DARK)
  beam('Brow'+str(s),'head',(s*.08,.63,8.84),(s*.48,.58,8.79),.12,.09,DARK)
  add('CheekMask'+str(s),'helmet',(s*.47,.62,8.4),(.25,.16,.55),RED)
 add('Nose','head',(0,.66,8.52),(.18,.21,.31),SKIN)
 add('Mouth','head',(0,.61,8.25),(.4,.06,.075),DARK)
 mass('KabutoDome','helmet',(0,-.06,9.0),(1.65,1.57,.97),RED,4,6)
 add('HelmetBrim','helmet',(0,.2,8.87),(1.8,1.43,.16),EDGE)
 for k in range(4):
  z=8.76-k*.2
  add('NeckGuardBack'+str(k),'helmet',(0,-.83-k*.08,z),(1.55+k*.14,.21,.23),RED)
  for s in[-1,1]:add('NeckGuardSide'+str(s)+str(k),'helmet',(s*(.72+k*.09),-.12,z),(.23,1.38,.23),RED,(0,-s*13,0))
 for s in[-1,1]:
  for k in range(4):add('Crest'+str(s)+str(k),'helmet',(s*(.37+.04*k),.87,9.08+k*.21),(.23,.12,.29),GOLD,(0,-s*9,0))
 # Katana extends below/outside the right fist with overlapping stepped curvature.
 x=-2.16;y=.24
 add('Grip','weapon',(x,y,4.07),(.24,.29,.85),DARK)
 for k in range(7):add('GripLace'+str(k),'weapon',(x,y,3.7+k*.12),(.28,.33,.05),CORD,(0,0,12 if k%2 else-12))
 add('Tsuba','weapon',(x,y,3.61),(.7,.55,.12),EDGE)
 for k in range(10):
  a=Vector((x-k*.045,y,3.57-k*.32));b=Vector((x-(k+1)*.045-(.08 if k>6 else 0),y,3.57-(k+1)*.32))
  beam('Katana'+str(k),'weapon',a,b,.26 if k<8 else .22-(k-8)*.08,.12,STEEL)
  beam('KatanaEdge'+str(k),'weapon',a+Vector((-.125,.01,0)),b+Vector((-.125,.01,0)),.055,.14,BLADE)
 beam('Scabbard','scabbard',(1.15,-.1,4.7),(2.04,-.56,1.43),.3,.37,DARK)
 for u in[0,.18,.94]:
  c=Vector((1.15,-.1,4.7)).lerp(Vector((2.04,-.56,1.43)),u)
  mass('ScabbardBand'+str(u),'scabbard',c,(.36,.43,.14),EDGE,1,3)
 return j,g.parts
