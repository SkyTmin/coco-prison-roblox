"""Original closed armor volumes; the reference informs silhouette, not copied geometry."""
from mathutils import Vector
from undead_king.necromancer_parts import Geometry
IRON=(52,58,66);EDGE=(112,116,119);LIGHT=(145,146,144);DARK=(27,30,34)
FEATHER=(37,46,59);BLUE=(48,59,72);LEATHER=(67,57,49)
def geometry(reaper=False):
 j=[('root',None,(0,0,0)),('body','root',(0,0,4.25)),('chest','body',(0,0,6.0)),('neck','chest',(0,0,7.85)),('head','neck',(0,0,8.35))]
 for side,s in [('L',1),('R',-1)]:
  j += [('arm'+side,'chest',(s*1.55,0,7.2)),('fore'+side,'arm'+side,(s*1.94,.04,5.64)),('hand'+side,'fore'+side,(s*2.16,.17,4.18)),
   ('fingers'+side,'hand'+side,(s*2.16,.34,3.99)),('thumb'+side,'hand'+side,(s*1.89,.38,4.14)),
   ('leg'+side,'body',(s*.78,0,4.25)),('shin'+side,'leg'+side,(s*.89,0,2.31)),('foot'+side,'shin'+side,(s*.94,.04,.51)),
   ('tasset'+side,'body',(s*.8,.5,4.5)),('shoulder'+side,'chest',(s*1.38,-.03,7.51)),('wing'+side,'shoulder'+side,(s*2.05,-.12,7.12))]
 for k in range(1,4):j.append(('cape'+str(k),'chest' if k==1 else 'cape'+str(k-1),(0,-.9-(k-1)*.15,7.5-(k-1)*1.65)))
 for side,s in [('L',1),('R',-1)]:
  for k in range(1,4):j.append(('cape'+side+str(k),'chest' if k==1 else 'cape'+side+str(k-1),(s*(1.13+(k-1)*.13),-.63-(k-1)*.24,7.36-(k-1)*1.65)))
 j += [('crest1','head',(0,-.13,9.18)),('crest2','crest1',(0,-.6,9.5)),('weapon','handR',(-2.16,.17,4.18)),('clothFront','body',(0,.71,4.5))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam
 def feather(n,j,a,b,w,col=FEATHER):
  a,b=Vector(a),Vector(b)
  for k,(u,v,m) in enumerate([(0,.36,.75),(.34,.75,1),(.73,1,.5)]):beam(n+str(k),j,a.lerp(b,u),a.lerp(b,v),w*m,.13,col)
 def chain(n,j,c,w,h):
  add(n,j,c,(w,.4,h),DARK)
  for row in range(3):
   for col in range(4):
    add(n+'Ring'+str(row)+str(col),j,(c[0]+(col-1.5)*w/4,c[1]+.23,c[2]+(row-1)*h/3),(.12,.035,.11),IRON)
 mass('Abdomen','body',(0,0,5.13),(2.15,1.47,1.78),DARK,3,4)
 mass('BackPlate','chest',(0,-.12,6.87),(2.98,1.72,1.93),IRON,4,4)
 for side,s in [('L',1),('R',-1)]:
  for k in range(3):beam('Ribs'+side+str(k),'body',(s*.17,.8,5.02+k*.31),(s*1.01,.56,5.19+k*.29),.15,.12,EDGE if k==2 else IRON)
  beam('BreastEdge'+side,'chest',(0,1.0,6.0),(s*1.25,.66,7.39),.14,.12,EDGE)
  beam('ChestPlate'+side,'chest',(s*.21,.91,6.5),(s*.95,.81,7.13),.62,.18,IRON)
  # Raven insignia built as layered cuboid quills.
  for k in range(4):beam('BadgeWing'+side+str(k),'chest',(s*.14,1.06,6.87),(s*(.5+.12*k),1.06,7.0+.13*k),.09,.055,LIGHT)
  beam('BadgeTail'+side,'chest',(s*.1,1.06,6.89),(s*.21,1.06,6.44),.1,.05,EDGE)
  mass('UpperArm'+side,'arm'+side,(s*1.74,0,6.48),(.9,1.0,1.36),IRON,3,4)
  chain('ElbowMail'+side,'fore'+side,(s*1.94,.03,5.61),.83,.61)
  mass('Bracer'+side,'fore'+side,(s*2.05,.13,4.98),(1.04,1.12,1.17),IRON,3,4)
  for z in [4.44,5.52]:mass('BracerRim'+side+str(z),'fore'+side,(s*2.05,.13,z),(1.12,1.17,.15),EDGE,1,4)
  for dx in [-.3,0,.3]:beam('BracerFlute'+side+str(dx),'fore'+side,(s*2.05+dx,.71,4.6),(s*2.05+dx,.67,5.35),.08,.055,EDGE)
  mass('Palm'+side,'hand'+side,(s*2.16,.17,4.04),(.67,.66,.59),IRON,2,4)
  for k in range(4):
   x=s*2.16+(k-1.5)*.16;z=3.93
   add('Knuckle'+side+str(k),'fingers'+side,(x,.43,z),(.145,.2,.23),EDGE)
   beam('Finger'+side+str(k),'fingers'+side,(x,.44,z-.09),(x,.51,z-.42+abs(k-1.5)*.06),.135,.17,IRON)
   add('Fingertip'+side+str(k),'fingers'+side,(x,.57,z-.43+abs(k-1.5)*.06),(.13,.2,.14),EDGE)
  beam('Thumb'+side,'thumb'+side,(s*1.89,.38,4.14),(s*1.83,.62,3.85),.18,.2,IRON)
  mass('Thigh'+side,'leg'+side,(s*.83,0,3.48),(1.15,1.25,1.78),IRON,3,4)
  chain('KneeMail'+side,'shin'+side,(s*.89,0,2.48),1.0,.54)
  mass('KneeCap'+side,'shin'+side,(s*.89,.58,2.46),(.98,.39,.65),IRON,3,3)
  beam('KneeChevron'+side,'shin'+side,(s*.89-.38,.79,2.55),(s*.89,.87,2.23),.12,.09,EDGE)
  beam('KneeChevronB'+side,'shin'+side,(s*.89,.87,2.23),(s*.89+.38,.79,2.55),.12,.09,EDGE)
  mass('Greave'+side,'shin'+side,(s*.92,.01,1.5),(1.03,1.1,1.43),IRON,3,4)
  for dx in [-.29,0,.29]:beam('ShinFlute'+side+str(dx),'shin'+side,(s*.92+dx,.6,.92),(s*.92+dx,.56,2.03),.07,.06,EDGE)
  mass('Boot'+side,'foot'+side,(s*.94,.23,.34),(1.16,1.75,.66),IRON,2,5)
  mass('AnkleMail'+side,'foot'+side,(s*.94,.04,.73),(.85,.9,.36),DARK,1,3)
  add('BootSole'+side,'foot'+side,(s*.94,.23,.09),(1.12,1.7,.18),DARK)
  for k in range(3):add('ToeRidge'+side+str(k),'foot'+side,(s*.94,.49+k*.22,.49-k*.06),(1.02,.11,.12),EDGE)
  mass('BeltSide'+side,'body',(s*.92,0,4.67),(.31,1.61,.26),LEATHER,1,3)
  add('Tasset'+side,'tasset'+side,(s*.83,.72,3.91),(.76,.23,1.24),IRON,(0,s*8,0))
  for dx in [-.35,.35]:add('TassetRim'+side+str(dx),'tasset'+side,(s*.83+dx,.87,3.91),(.08,.06,1.2),EDGE)
  add('TassetRivet'+side,'tasset'+side,(s*.83,.87,3.47),(.13,.06,.13),LIGHT)
  # Pauldrons have an actual rounded underplate and two independently moving feather tiers.
  mass('Pauldron'+side,'shoulder'+side,(s*1.57,-.03,7.27),(1.48,1.65,.89),IRON,3,4)
  for row in range(3):
   for k in range(5):
    y=(k-2)*.34-.05;x=s*(1.29+row*.34);z=7.68-row*.27
    feather('ShoulderFeather'+side+str(row)+str(k),'shoulder'+side if row==0 else 'wing'+side,(x,y,z),(x+s*.63,y-.16,z-.71-(k%2)*.1),.36,FEATHER if k%2 else BLUE)
 add('BeltFront','body',(0,.77,4.67),(2.18,.15,.28),LEATHER)
 add('Buckle','body',(0,.89,4.67),(.5,.12,.4),EDGE);add('BuckleHole','body',(0,.96,4.67),(.27,.03,.22),DARK)
 for k in range(3):add('ClothFront'+str(k),'clothFront',((k-1)*.24,.77,3.69),(.27,.16,1.9-.16*(k%2)),FEATHER)
 mass('Neck','neck',(0,0,7.92),(.94,.91,.55),DARK,2,4)
 mass('Helmet','head',(0,-.04,8.62),(1.45,1.31,1.53),IRON,4,4)
 add('EyeRecess','head',(0,.66,8.76),(1.24,.12,.25),DARK)
 for side,s in [('L',1),('R',-1)]:
  beam('Brow'+side,'head',(s*.05,.79,8.98),(s*.63,.6,8.83),.14,.11,EDGE)
  add('Eye'+side,'head',(s*.36,.73,8.77),(.25,.03,.055),LIGHT)
  beam('Cheek'+side,'head',(s*.59,.65,8.69),(s*.22,.91,8.04),.18,.12,EDGE)
  for k in range(3):add('VisorSlot'+side+str(k),'head',(s*(.22+k*.14),.69,8.4),(.06,.1,.31),DARK)
  beam('VisorRidge'+side,'head',(s*.26,.76,8.9),(0,1.11,8.1),.23,.19,IRON)
 for k in range(4):
  feather('Crest'+str(k),'crest1'if k<2 else'crest2',(0,-.06-k*.15,9.21+k*.05),(0,-.71-k*.26,9.61-k*.13),.36,BLUE)
 # Cloak follows the entire back and both flanks; overlapping rows leave no flat cutout.
 for tier in range(6):
  for col in range(9):
   x=(col-4)*(.31+tier*.018);y=-.94-tier*.1+.18*abs(col-4)/4;z=7.4-tier*.89
   side='L'if col>=6 else('R'if col<=2 else'');joint='cape'+side+str(min(3,tier//2+1))
   feather('Cloak'+str(tier)+'_'+str(col),joint,(x,y,z),(x*1.16,y-.21,z-1.2-.13*(col%2)),.45,FEATHER if (col+tier)%3 else BLUE)
 # Original sword (hand joint stays fixed; the weapon joint can detach in death).
 x=-2.16;y=.24
 add('Grip','weapon',(x,y,4.06),(.28,.32,.77),DARK)
 for k in range(5):add('GripWrap'+str(k),'weapon',(x,y,3.77+k*.14),(.31,.35,.045),LEATHER)
 mass('Pommel','weapon',(x,y,4.57),(.49,.45,.35),EDGE,2,3)
 add('Guard','weapon',(x,y,3.63),(1.39,.3,.21),EDGE)
 for side,s in [('L',1),('R',-1)]:
  for k in range(3):feather('GuardQuill'+side+str(k),'weapon',(x+s*(.27+k*.13),y,3.63),(x+s*(.55+k*.17),y,3.86+k*.05),.17,IRON)
 for k in range(7):
  z=3.34-k*.43;w=.56 if k<5 else .56-(k-4)*.13
  add('Blade'+str(k),'weapon',(x+(.05 if k==6 else 0),y,z),(w,.18,.46),EDGE)
  add('Fuller'+str(k),'weapon',(x,y+.1,z),(.065,.035,.41),IRON)
  if k<6:add('Edge'+str(k),'weapon',(x-w/2,y,z),(.055,.19,.35 if k in[2,4]else.46),LIGHT)
 add('BrokenTip','weapon',(x+.09,y,.39),(.18,.18,.35),LIGHT,(0,0,-15))
 if reaper:
  # Variant is hooded, shorter-plumed and carries a crescent poleaxe; original joints retained.
  g.parts=[p for p in g.parts if not p[0].startswith(('Helmet','Eye','Brow','Cheek','Visor','Crest','Grip','Pommel','Guard','Blade','Fuller','Edge','BrokenTip'))]
  mass('Hood','head',(0,-.16,8.6),(1.63,1.55,1.66),FEATHER,4,4)
  add('HoodOpening','head',(0,.65,8.56),(1.12,.23,1.17),DARK)
  mass('Skull','head',(0,.77,8.58),(.76,.45,.9),(143,144,138),3,3)
  for s in[-1,1]:add('SkullEye'+str(s),'head',(s*.22,1.0,8.72),(.22,.08,.19),DARK)
  add('SkullNose','head',(0,1.01,8.49),(.1,.06,.18),DARK)
  for k in range(4):add('SkullTooth'+str(k),'head',((k-1.5)*.15,1.0,8.25),(.09,.07,.2),EDGE)
  # Blade hangs below/outside the right fist, matching the downward sword/axe contact arc.
  # An upward blade at the inside of the hand was hidden in the torso in review.
  add('AxeShaft','weapon',(x,y,3.4),(.24,.28,3.4),LEATHER)
  for k in range(5):
   z=2.83-k*.3;w=1.45-abs(k-2)*.16
   add('AxeBlade'+str(k),'weapon',(x-w/2,y,z),(w,.24,.33),IRON)
   add('AxeEdge'+str(k),'weapon',(x-w,y,z),(.14,.27,.34),EDGE)
  add('AxeSpike','weapon',(x,y,1.4),(.18,.22,.62),EDGE)
 return j,g.parts
