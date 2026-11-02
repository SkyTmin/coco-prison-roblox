"""Original woven-root guardian measured from the generated turnaround."""
import math,random
from mathutils import Vector
from undead_king.necromancer_parts import Geometry
from ent.ent_parts import geometry as oak_geometry
BARK=(57,63,50);EDGE=(104,112,77);DARK=(34,40,31);LEAF=(76,95,48);MOSS=(118,133,75);RED=(153,62,50);BLUE=(75,121,117)
def geometry():
 j=oak_geometry()[0]
 j=[(n,p,v)for n,p,v in j if not n.startswith('beard') and n not in ['fingerL3','fingerR3']]
 for i,(n,p,v) in enumerate(j):
  if n.startswith('twig'):j[i]=(n,p,(v[0]*.75,v[1],9.22+(int(n[-1])%2)*.23))
 for side,s in [('L',1),('R',-1)]:
  j += [('mantle'+side+'1','chest',(s*1.45,-.15,7.54)),('mantle'+side+'2','mantle'+side+'1',(s*2.21,-.18,7.15)),('mantleBack'+side,'chest',(s*.8,-1.15,7.1))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam;rng=random.Random(4405)
 def root(n,joint,points,width=.26):
  for k,(a,b)in enumerate(zip(points,points[1:])):
   beam(n+str(k),joint,a,b,width,width,BARK if k%3 else EDGE)
 def braid(n,joint,c,size):
  x,y,z=c;w,d,h=size;mass(n+'Core',joint,c,(w*.83,d*.83,h),DARK,4,4)
  for phase in[0,math.pi]:
   points=[]
   for k in range(10):
    t=k/9*math.pi*1.45+phase;points.append((x+math.sin(t)*w*.43,y+math.cos(t)*d*.43,z-h*.48+k/9*h*.96))
   root(n+str(phase),joint,points,min(w*.2,.31))
 def leaf(n,joint,c,w=.58,tilt=18):
  x,y,z=c
  beam(n+'Stem',joint,(x,y-.2,z+.1),(x,y+.15,z-.22),.055,.06,BARK)
  for k,(v,width)in enumerate([(0,.72),(.19,1),(.39,.52)]):
   add(n+str(k),joint,(x,y+v*.43,z-v),(w*width,.16,w*.49),LEAF if k!=1 else MOSS,(tilt,0,rng.uniform(-16,16)))
 braid('Waist','body',(0,0,4.8),(2.8,2.0,1.8));braid('Torso','chest',(0,-.05,6.61),(3.8,2.45,2.3))
 # Interwoven front and back arches retain the enclosed torso's depth.
 for facing in[-1,1]:
  for side,s in[('L',1),('R',-1)]:
   root('Rib'+str(facing)+side,'chest',[(s*1.46,facing*1.0,7.4),(s*1.13,facing*1.31,6.95),(s*.41,facing*1.33,6.43),(s*.12,facing*1.18,6.04)],.3)
  for row in range(3):
   for k in range(5):
    x=(k-2)*.57;leaf('ChestLeaf'+str(facing)+str(row)+str(k),'chest',(x,facing*(1.1+.15*math.cos(x)),7.22-row*.5),.55)
 braid('Mask','head',(0,.07,8.3),(1.47,1.36,1.5))
 for k in range(5):
  x=(k-2)*.24;add('MaskPlate'+str(k),'head',(x,.81,8.27),(.22,.24,1.14-abs(x)*.5),BARK if k%2 else EDGE)
 for side,s in [('L',1),('R',-1)]:
  add('EyeSocket'+side,'head',(s*.31,.96,8.52),(.37,.08,.2),DARK)
  add('Eye'+side,'head',(s*.31,1.005,8.53),(.14,.03,.09),(148,154,90))
  beam('Brow'+side,'head',(s*.08,1,8.73),(s*.64,.88,8.76),.17,.19,BARK)
 add('Jaw','jaw',(0,.81,7.91),(.64,.37,.39),BARK)
 for side,s in [('L',1),('R',-1)]:
  braid('Upper'+side,'arm'+side,(s*2.3,0,6.3),(1.29,1.45,2.05))
  mass('Elbow'+side,'fore'+side,(s*2.65,.06,5.24),(.85,1.03,.85),BARK,3,3)
  braid('Fore'+side,'fore'+side,(s*2.99,.08,4.29),(1.36,1.52,2.13))
  braid('Palm'+side,'hand'+side,(s*3.12,.2,3.06),(1.21,.91,.86))
  for k in range(3):
   x=s*(2.76+k*.27);root('Finger'+side+str(k),'finger'+side+str(k),[(x,.35,2.87),(x+s*.09,.45,2.5),(x+s*.07,.67,2.15),(x,.98,2.14),(x-s*.04,1.15,2.34)],.23)
  root('Thumb'+side,'thumb'+side,[(s*2.64,.28,3.13),(s*2.33,.43,2.95),(s*2.26,.78,2.69),(s*2.4,.96,2.64)],.26)
  braid('Thigh'+side,'leg'+side,(s*1.08,0,3.19),(1.35,1.41,1.8));braid('Calf'+side,'shin'+side,(s*1.22,.04,1.38),(1.33,1.43,1.8))
  mass('Knee'+side,'shin'+side,(s*1.13,.05,2.28),(.85,1.01,.88),BARK,3,3)
  mass('Foot'+side,'foot'+side,(s*1.27,.12,.42),(1.7,1.8,.81),DARK,3,3)
  for name,dy,dx in [('toeFront',1,0),('toeOuter',.4,s*.75),('toeBack',-1,0)]:
   root(name+side,name+side,[(s*1.27,.12,.51),(s*1.27+dx*.55,.12+dy*.55,.26),(s*1.27+dx,.12+dy,.17)],.34)
  for k in range(3):
   a=(s*(.45+k*.35),-.14+k*.11,8.83);b=(s*(.6+k*.76)*.75,-.25+k*.07,9.22+(k%2)*.23)
   root('Crown'+side+str(k),'crown'+side+str(k),[a,((a[0]+b[0])*.5,a[1],b[2]-.2),b],.15)
   root('Twig'+side+str(k),'twig'+side+str(k),[b,(b[0]+s*.16,b[1],b[2]+.32),(b[0]+s*.29,b[1]-.05,b[2]+.48)],.1)
  # Leaf mantle is rigged in overlapping layers, never independent floating billboards.
  for layer in[1,2]:
   joint='mantle'+side+str(layer)
   mass('MantleBase'+side+str(layer),joint,(s*(1.5+layer*.33),-.13,7.55-layer*.22),(1.48,1.85,.7),LEAF,3,3)
   for row in range(3):
    for k in range(4):leaf('MantleLeaf'+side+str(layer)+str(row)+str(k),joint,(s*(1.13+layer*.36+k*.31),-.81+row*.63,7.86-layer*.2-k*.14),.7)
  for row in range(3):
   for k in range(3):leaf('BackLeaf'+side+str(row)+str(k),'mantleBack'+side,(s*(.3+k*.49),-1.36-row*.07,7.15-row*.55),.67)
  for k in range(1,4):
   z=7.25-(k-1)*.81;root('Vine'+side+str(k),'vine'+side+str(k),[(s*1.64,.68,z),(s*1.71,.73,z-.43),(s*1.64,.77,z-.85)],.1)
   leaf('VineLeaf'+side+str(k),'vine'+side+str(k),(s*1.67,.77,z-.36),.36)
  for k in range(4):leaf('LegLeaf'+side+str(k),'leg'+side,(s*(.72+(k%2)*.48),.67,4-k*.36),.53)
 for k in range(5):
  x=-2.15-(k%2)*.25;z=7.63-k*.28
  mass('RedFungus'+str(k),'armR',(x,.27,z),(1.0,.85,.19),RED,2,4)
  add('FungusRim'+str(k),'armR',(x,.65,z-.035),(.92,.14,.08),(178,88,65))
 for k in range(7):leaf('Lichen'+str(k),'foreL',(3.02+(k%3-.9)*.25,.87,4.41-(k//3)*.17),.31)
 # Tint the wrist lichen without runtime material edits.
 for i,p in enumerate(g.parts):
  if p[0].startswith('Lichen'):p=list(p);p[4]=BLUE;g.parts[i]=tuple(p)
 return j,g.parts
