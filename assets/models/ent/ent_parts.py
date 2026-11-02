"""Original measured oak king: closed timber volumes, layered bark and articulated roots."""
import math,random
from mathutils import Vector
from undead_king.necromancer_parts import Geometry
BARK=(80,58,39);WOOD=(125,89,57);CUT=(170,127,79);DARK=(44,40,32);MOSS=(88,100,69);LEAF=(119,128,82);EDGE=(143,113,73)

def geometry():
 j=[('root',None,(0,0,0)),('body','root',(0,0,4.05)),('chest','body',(0,0,5.8)),('neck','chest',(0,0,7.6)),('head','neck',(0,0,8.15)),('jaw','head',(0,.72,7.82)),('beard1','jaw',(0,.98,7.62)),('beard2','beard1',(0,1.05,7.03))]
 for side,s in [('L',1),('R',-1)]:
  j += [('arm'+side,'chest',(s*2.0,0,7.23)),('fore'+side,'arm'+side,(s*2.65,.06,5.24)),('hand'+side,'fore'+side,(s*3.17,.17,3.2)),('thumb'+side,'hand'+side,(s*2.64,.28,3.13)),
   ('leg'+side,'body',(s*1.03,0,4.05)),('shin'+side,'leg'+side,(s*1.13,.05,2.28)),('foot'+side,'shin'+side,(s*1.27,.08,.36)),
   ('toeFront'+side,'foot'+side,(s*1.27,.54,.24)),('toeOuter'+side,'foot'+side,(s*1.7,.18,.24)),('toeBack'+side,'foot'+side,(s*1.27,-.36,.24)),
   ('vine'+side+'1','chest',(s*1.55,.55,7.25)),('vine'+side+'2','vine'+side+'1',(s*1.7,.67,6.45)),('vine'+side+'3','vine'+side+'2',(s*1.63,.71,5.63))]
  for k in range(4):j.append(('finger'+side+str(k),'hand'+side,(s*(2.76+k*.27),.35,2.8)))
  for k in range(3):
   j += [('crown'+side+str(k),'head',(s*(.45+k*.35),-.14+k*.11,8.83)),('twig'+side+str(k),'crown'+side+str(k),(s*(.6+k*.76),-.25+k*.07,10.4-k*.35))]
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam;rnd=random.Random(2107)
 def bark(n,joint,c,size,columns=7):
  x,y,z=c;w,d,h=size
  mass(n+'Core',joint,c,size,BARK,4,5)
  for facing in [-1,1]:
   for k in range(columns):
    xx=x+(k/(columns-1)-.5)*w*.87;depth=d*.5*math.sqrt(max(.1,1-((xx-x)/(w*.57))**2))
    for row in range(3):
     zz=z-h*.41+(row+.5)*h*.28+rnd.uniform(-.09,.09)
     add(n+'Bark'+str(facing)+'_'+str(k)+'_'+str(row),joint,(xx,y+facing*(depth+.025),zz),(w/columns*.61,.13,h*.3),WOOD if (k+row)%3 else EDGE,(0,rnd.uniform(-4,4),0))
  for side in[-1,1]:
   for k in range(3):add(n+'Side'+str(side)+'_'+str(k),joint,(x+side*w*.49,y+(k-1)*d*.22,z),(.12,d*.16,h*.73),WOOD)
 def knot(n,joint,c,r,side=False):
  x,y,z=c
  for ring in [1,.65,.3]:
   for k in range(8):
    a=k*math.pi/4;b=(k+1)*math.pi/4
    if side:A=(x,y+math.cos(a)*r*ring,z+math.sin(a)*r*ring);B=(x,y+math.cos(b)*r*ring,z+math.sin(b)*r*ring)
    else:A=(x+math.cos(a)*r*ring,y,z+math.sin(a)*r*ring);B=(x+math.cos(b)*r*ring,y,z+math.sin(b)*r*ring)
    beam(n+str(ring)+'_'+str(k),joint,A,B,.075,.075,CUT if ring!=.65 else WOOD)
 def foliage(n,joint,c,size=.5):
  add(n+'Heart',joint,c,(size*.55,size*.55,size*.35),MOSS)
  for k in range(6):
   dx,dy,dz=[rnd.uniform(-size*.65,size*.65)for _ in range(3)]
   beam(n+'Stem'+str(k),joint,c,(c[0]+dx,c[1]+dy,c[2]+dz),.055,.055,MOSS)
   add(n+str(k),joint,(c[0]+dx,c[1]+dy,c[2]+dz),(size*.55,size*.5,size*.28),MOSS if k%2 else LEAF,(0,0,k*27))
 bark('Waist','body',(0,0,4.8),(2.8,2,1.8),7)
 bark('Trunk','chest',(0,-.03,6.65),(4.0,2.65,2.35),11)
 bark('Face','head',(0,0,8.32),(1.85,1.75,1.67),6)
 for side,s in[('L',1),('R',-1)]:
  add('Socket'+side,'head',(s*.4,.875,8.49),(.56,.12,.3),DARK)
  add('Eye'+side,'head',(s*.4,.95,8.5),(.25,.045,.12),(150,158,107))
  beam('Brow'+side,'head',(s*.08,1,8.72),(s*.77,.92,8.79),.24,.28,CUT)
  beam('Cheek'+side,'head',(s*.65,.93,8.4),(s*.77,.94,7.96),.22,.22,WOOD)
 add('Nose','head',(0,1.02,8.27),(.28,.37,.45),CUT)
 add('Mouth','jaw',(0,1,7.95),(.7,.12,.18),DARK)
 for k in range(7):
  x=(k-3)*.16
  beam('BeardRoot'+str(k),'beard1',(x,1.02,7.85),(x*.8,1.19,7.08-abs(x)*.2),.16,.16,WOOD if k%2 else EDGE)
  beam('BeardTip'+str(k),'beard2',(x*.8,1.19,7.1),(x*.56,1.12,6.55+abs(x)*.5),.13,.12,BARK if k%2 else WOOD)
 knot('ChestKnot','chest',(-.82,1.3,6.4),.34)
 knot('BackKnot','chest',(0,-1.42,6.85),.51)
 for k in range(5):add('BackSpine'+str(k),'chest',(0,-1.43,5.8+k*.35),(.4,.22,.27),WOOD)
 for side,s in [('L',1),('R',-1)]:
  bark('Upper'+side,'arm'+side,(s*2.29,0,6.3),(1.35,1.53,2.0),5)
  mass('Elbow'+side,'fore'+side,(s*2.65,.06,5.24),(.95,1.05,.92),DARK,3,3)
  bark('Fore'+side,'fore'+side,(s*2.98,.08,4.27),(1.52,1.7,2.1),5)
  bark('Palm'+side,'hand'+side,(s*3.17,.21,3.0),(1.45,1.07,.82),4)
  knot('ShoulderCut'+side,'arm'+side,(s*2.99,0,6.94),.43,True)
  knot('ForeCut'+side,'fore'+side,(s*3.74,.08,4.58),.47,True)
  for k in range(4):
   xx=s*(2.76+k*.27);joint='finger'+side+str(k)
   beam('Finger'+side+str(k),joint,(xx,.32,2.87),(xx+s*.04,.49,2.16),.23,.3,WOOD)
   beam('Tip'+side+str(k),joint,(xx+s*.04,.49,2.2),(xx+s*.02,.78,2.1),.22,.27,BARK)
  beam('Thumb'+side,'thumb'+side,(s*2.64,.25,3.08),(s*2.38,.59,2.74),.32,.35,WOOD)
  bark('Thigh'+side,'leg'+side,(s*1.08,0,3.22),(1.35,1.45,1.8),4)
  mass('KneeJoint'+side,'shin'+side,(s*1.13,.05,2.28),(.95,1.05,.92),DARK,3,3)
  bark('Calf'+side,'shin'+side,(s*1.22,.06,1.39),(1.33,1.5,1.85),4)
  mass('Foot'+side,'foot'+side,(s*1.27,.12,.45),(1.75,1.9,.88),BARK,3,4)
  for n,dy,dx in [('toeFront',1,0),('toeOuter',.4,s*.75),('toeBack',-1,0)]:
   base=(s*1.27,.1,.38);end=(s*1.27+dx,.1+dy,.18)
   beam(n+side,n+side,base,end,.42,.35,WOOD);add(n+'Contact'+side,n+side,end,(.42,.43,.35),BARK)
  knot('Knee'+side,'shin'+side,(s*1.18,.79,2.18),.27)
  for k in range(3):
   joint='crown'+side+str(k);twig='twig'+side+str(k)
   a=(s*(.45+k*.35),-.14+k*.11,8.83);b=(s*(.6+k*.76),-.25+k*.07,10.4-k*.35)
   beam('Crown'+side+str(k),joint,a,b,.42-.05*k,.45-.04*k,BARK)
   beam('CrownRidge'+side+str(k),joint,(a[0],a[1]+.23,a[2]),(b[0],b[1]+.18,b[2]),.15,.14,WOOD)
   tip=(b[0]+s*.25,b[1]+.08,b[2]+.55);beam('Twig'+side+str(k),twig,b,tip,.22,.24,WOOD)
   if k!=1:foliage('CrownLeaf'+side+str(k),twig,tip,.64)
  for k in range(1,4):
   joint='vine'+side+str(k);z=7.25-(k-1)*.81
   beam('Vine'+side+str(k),joint,(s*1.64,.69,z),(s*1.64,.73,z-.86),.11,.1,MOSS)
   foliage('VineLeaf'+side+str(k),joint,(s*1.64,.74,z-.52),.31)
  foliage('ShoulderLeaf'+side,'arm'+side,(s*2.3,-.06,7.4),.75)
  foliage('WristMoss'+side,'fore'+side,(s*2.91,.88,4.7),.46)
 for k in range(5):
  z=5.95+k*.43;x=1.15+.1*math.sin(k)
  mass('Fungus'+str(k),'chest',(x,1.29,z),(.73,.55,.18),CUT,2,3)
  add('FungusLip'+str(k),'chest',(x,1.51,z-.035),(.68,.14,.07),EDGE)
 return j,g.parts
