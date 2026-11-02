"""Original bounded encounter actors: flower-faced stalker/hound/bat, clock and portal."""
import math
from mathutils import Vector,Euler
from undead_king.necromancer_parts import Geometry
from splinter.motion import Rig,pose
BASE=(79,66,57);RIDGE=(118,99,82);DARK=(39,31,32);BONE=(152,137,109)
def make(name,here):
 g=Geometry();add,mass,beam=g.add,g.mass,g.beam
 joints=[('root',None,(0,0,0))];ground=[]
 def face(center,parent,scale):
  x,y,z=center;joints.append(('head',parent,center));mass('FaceCore','head',center,(scale*.7,scale*.38,scale*.7),DARK,2,4)
  for k in range(5):
   a=k*math.tau/5;dx,dz=math.sin(a),math.cos(a);pivot=(x+dx*scale*.28,y,z+dz*scale*.28);n='petal'+str(k);joints.append((n,'head',pivot))
   beam('Petal'+str(k),n,pivot,(x+dx*scale*.81,y+.06,z+dz*scale*.81),scale*.35,scale*.14,BASE)
   beam('PetalRidge'+str(k),n,(pivot[0],y+.09,pivot[2]),(x+dx*scale*.72,y+.15,z+dz*scale*.72),scale*.11,scale*.06,RIDGE)
   for q in range(2):add('PetalTooth'+str(k)+str(q),n,(x+dx*scale*(.36+q*.2),y+.18,z+dz*scale*(.36+q*.2)),(scale*.09,scale*.1,scale*.12),BONE)
 if name=='vecna_stalker':
  joints += [('body','root',(0,0,2.3)),('chest','body',(0,0,3.4)),('neck','chest',(0,.03,4.27))]
  mass('Waist','body',(0,0,2.83),(1.02,.79,1.21),DARK,3,4);mass('Chest','chest',(0,0,3.78),(1.62,.98,1.12),BASE,3,4)
  face((0,.12,4.63),'neck',.72)
  for side,s in [('L',1),('R',-1)]:
   joints += [('arm'+side,'chest',(s*.84,0,4.01)),('fore'+side,'arm'+side,(s*1.14,.04,3.13)),('hand'+side,'fore'+side,(s*1.34,.17,2.21)),
    ('leg'+side,'body',(s*.41,0,2.3)),('shin'+side,'leg'+side,(s*.52,0,1.28)),('foot'+side,'shin'+side,(s*.57,0,.23))]
   beam('Arm'+side,'arm'+side,(s*.85,0,3.98),(s*1.14,.04,3.13),.4,.43,BASE);beam('Forearm'+side,'fore'+side,(s*1.14,.04,3.13),(s*1.34,.17,2.21),.38,.43,BASE)
   mass('Palm'+side,'hand'+side,(s*1.34,.21,2.11),(.45,.35,.42),RIDGE,2,3)
   for k in[-1,0,1]:beam('Claw'+side+str(k),'hand'+side,(s*1.34+k*.15,.24,2.08),(s*1.4+k*.17,.49,1.58+abs(k)*.07),.1,.11,BONE)
   mass('Thigh'+side,'leg'+side,(s*.46,0,1.82),(.67,.72,1.03),BASE,3,3);beam('Shin'+side,'shin'+side,(s*.52,0,1.28),(s*.57,0,.23),.38,.43,BASE)
   mass('Foot'+side,'foot'+side,(s*.57,.16,.19),(.63,.87,.36),RIDGE,2,3)
   for k in range(3):beam('Rib'+side+str(k),'chest',(s*.06,.54,3.97-k*.25),(s*.66,.36,4.11-k*.25),.1,.1,RIDGE)
  rig=Rig(joints)
  def rest(extra=None,drop=.2,feet=None):
   p=pose(body=(0,0,0,(0,0,-drop)),chest=-8,neck=4,head=4,armL=8,armR=10,foreL=12,foreR=15);p.update(extra or {});return rig.planted(p,feet)
  walk=[]
  for i in range(33):
   feet={};t=i/32*math.tau
   for side,q in [('L',i/32),('R',i/32+.5)]:
    q%=1
    if q<.6:y=1.05*(1-2*q/.6);z=0
    else:u=(q-.6)/.4;y=-1.05+2.1*u*u*(3-2*u);z=.35*math.sin(math.pi*u)
    feet[side]=(0,y,z)
   walk.append((i/32*30,rest(pose(chest=(-12,0,3*math.sin(t)),armL=12+13*math.sin(t),armR=12-13*math.sin(t)),.50,feet)))
  actions={'idle':([(0,rest()),(30,rest(pose(chest=-6,head=3),.18)),(60,rest())],True),'walk':(walk,True),
   'bite':([(0,rest()),(8,rest(pose(chest=6,head=13,armL=89,foreL=31),.28)),(17,rest(pose(chest=-23,head=9,armL=62,foreL=-7,armR=33),.52)),(32,rest())],False),
   'hurt':([(0,rest()),(5,rest(pose(chest=14,head=19),.32)),(15,rest())],False),
   'spawn':([(0,rest(pose(chest=-22,head=-13),.55)),(12,rest(pose(chest=4,head=13),.25)),(30,rest())],False)}
  down=pose(body=(-88,-8,9,(-.15,.4,-.7)),chest=(0,3,-4),head=(0,-9,0),armL=(5,-12,39),foreL=13,armR=(-9,17,-31),foreR=12,legL=4,legR=-7,shinL=-27,shinR=-28,footL=16,footR=18)
  for side,s in [('L',1),('R',-1)]:
   shoulder=rig.world(down,'arm'+side).translation
   rig.chain(down,'arm'+side,'fore'+side,'hand'+side,(shoulder.x+s*.35,shoulder.y-1.0,1.43),(s,0,.2),Euler((-math.pi/2,0,0)).to_quaternion())
  actions['death']=([(0,rest()),(7,rest(pose(chest=16,head=23),.28)),(20,rest(pose(chest=-27,head=-9),.62)),(36,pose(body=(-43,-31,7,(-.1,.3,-.7)),chest=-11,head=-3,armL=24,armR=19,legL=42,legR=29,shinL=-71,shinR=-78)),(51,down),(62,dict(down)),(78,dict(down))],False)
  speed=3.5
 elif name=='vecna_hound':
  joints += [('body','root',(0,0,1.15)),('chest','body',(0,.61,1.34)),('neck','chest',(0,1.05,1.55)),('tail1','body',(0,-1.04,1.2)),('tail2','tail1',(0,-1.71,1.17))]
  mass('Body','body',(0,-.12,1.2),(1.19,2.1,.95),BASE,3,5);mass('Shoulder','chest',(0,.69,1.44),(1.29,.94,1.04),RIDGE,3,4)
  face((0,1.3,1.72),'neck',.63)
  beam('Tail1','tail1',(0,-1.04,1.2),(0,-1.71,1.17),.24,.26,BASE);beam('Tail2','tail2',(0,-1.71,1.17),(0,-2.31,.93),.15,.17,RIDGE)
  for side,s in [('L',1),('R',-1)]:
   for end,y in [('Front',.7),('Back',-.72)]:
    upper='leg'+end+side;lower='shin'+end+side;foot='foot'+end+side
    joints += [(upper,'chest' if end=='Front'else'body',(s*.49,y,1.35)),(lower,upper,(s*.62,y+.09,.75)),(foot,lower,(s*.65,y,.17))]
    beam('Upper'+end+side,upper,(s*.49,y,1.35),(s*.62,y+.09,.75),.34,.38,BASE);beam('Lower'+end+side,lower,(s*.62,y+.09,.75),(s*.65,y,.17),.23,.26,RIDGE)
    mass('Paw'+end+side,foot,(s*.65,y+.12,.13),(.43,.54,.25),BASE,1,3)
    for k in[-1,1]:add('PawNail'+end+side+str(k),foot,(s*.65+k*.12,y+.4,.1),(.1,.18,.14),BONE)
  rig=Rig(joints)
  def rest(extra=None,drop=.12,offsets=None):
   p=pose(body=(0,0,0,(0,0,-drop)),chest=-3,head=3);p.update(extra or {})
   for end in ['Front','Back']:
    for side in ['L','R']:
     n=end+side;target=rig.points['foot'+n]+Vector((offsets or {}).get(n,(0,0,0)))
     rig.chain(p,'leg'+n,'shin'+n,'foot'+n,target,(0,-1 if end=='Back' else 1,0))
   return p
  walk=[]
  for i in range(33):
   offsets={};t=i/32*math.tau
   for n,phase in [('FrontL',0),('BackR',0),('FrontR',.5),('BackL',.5)]:
    q=(i/32+phase)%1
    if q<.6:y=.6*(1-2*q/.6);z=0
    else:u=(q-.6)/.4;y=-.6+1.2*u*u*(3-2*u);z=.23*math.sin(math.pi*u)
    offsets[n]=(0,y,z)
   walk.append((i/32*18,rest(pose(chest=(-5,0,2*math.sin(t)),head=5,tail1=(0,0,8*math.sin(t-.5)),tail2=(0,0,12*math.sin(t-1))),.30,offsets)))
  actions={'idle':([(0,rest()),(30,rest(pose(chest=-2,head=2),.1)),(60,rest())],True),'walk':(walk,True),
   'bite':([(0,rest()),(7,rest(pose(chest=8,head=17),.18)),(15,rest(pose(chest=-18,head=-7),.3)),(27,rest())],False),
   'hurt':([(0,rest()),(5,rest(pose(chest=10,head=16),.2)),(14,rest())],False),
   'spawn':([(0,rest(pose(chest=-14,head=-9),.31)),(11,rest(pose(head=13),.18)),(27,rest())],False)}
  down=pose(body=(6,-86,5,(0,0,-.22)),chest=(0,-5,-4),neck=(0,8,0),head=(-4,9,0),tail1=(9,0,-14),tail2=(-5,0,-23))
  for end in ['Front','Back']:
   for side,s in [('L',1),('R',-1)]:down.update(pose(**{'leg'+end+side:(19 if end=='Front'else-23,s*34,0),'shin'+end+side:(-44,0,0),'foot'+end+side:(18,0,0)}))
   # Fold the lower-side upper limbs into the ribcage instead of balancing on their outer edge.
   n='leg'+end+'R';down[n]=down[n][:3]+((.14,0,0),)
  actions['death']=([(0,rest()),(6,rest(pose(chest=13,head=21),.2)),(18,rest(pose(chest=-16,head=-8),.4)),(32,pose(body=(5,-49,4,(0,0,-.22)),chest=-4,head=-6)),(45,down),(57,dict(down)),(69,dict(down))],False)
  speed=3.333333
 elif name=='vecna_bat':
  joints += [('body','root',(0,0,.5)),('neck','body',(0,.25,.63))];mass('Body','body',(0,0,.53),(.55,.91,.52),BASE,3,3);face((0,.45,.65),'neck',.38)
  for side,s in [('L',1),('R',-1)]:
   joints += [('wing'+side,'body',(s*.23,0,.66)),('tip'+side,'wing'+side,(s*.9,-.09,.61)),('foot'+side,'body',(s*.16,-.15,.31))]
   beam('WingBone'+side,'wing'+side,(s*.23,0,.66),(s*.9,-.09,.61),.13,.14,RIDGE)
   for k in range(4):
    beam('WingRib'+side+str(k),'tip'+side,(s*.85,-.08,.61),(s*(1.3+k*.13),-.2-k*.22,.54),.07,.08,RIDGE)
    beam('Membrane'+side+str(k),'tip'+side,(s*.85,-.1-k*.08,.59),(s*(1.23+k*.12),-.25-k*.2,.53),.24,.055,DARK)
   beam('Leg'+side,'foot'+side,(s*.16,-.15,.31),(s*.18,-.1,.11),.08,.08,RIDGE)
  def flap(t,amp=55):return pose(body=(4,0,0,(0,0,.025*math.sin(t))),head=3,wingL=(0,amp*math.sin(t),0),wingR=(0,-amp*math.sin(t),0),tipL=(0,amp*.55*math.sin(t-.6),-9),tipR=(0,-amp*.55*math.sin(t-.6),9),footL=21,footR=21)
  loop=[(i/24*22.5,flap(i/24*math.tau))for i in range(25)]
  actions={'idle':(loop,True),'walk':(loop,True),'bite':([(0,flap(0)),(5,flap(1)),(12,pose(body=(-28,0,0,(0,.15,0)),head=-11,wingL=(0,67,0),wingR=(0,-67,0))),(24,flap(0))],False),
   'hurt':([(0,flap(0)),(4,flap(1,19)),(13,flap(0))],False),'spawn':([(0,flap(0,5)),(7,flap(1,32)),(18,flap(0))],False),
   'death':([(0,flap(0)),(8,flap(1,25)),(20,pose(body=(-15,-31,5,(0,0,-.1)),head=-7,wingL=(0,58,9),wingR=(0,-49,-8),tipL=(0,37,-17),tipR=(0,-32,16))),
    (37,pose(body=(-10,-84,7,(0,0,-.1)),head=-11,wingL=(0,42,13),wingR=(0,-37,-9),tipL=(0,51,-22),tipR=(0,-49,19))),
    (54,pose(body=(-10,-88,7,(0,0,-.1)),head=-13,wingL=(0,39,14),wingR=(0,-35,-11),tipL=(0,54,-24),tipR=(0,-51,21)))],False)}
  # Lay both wing chains beside the body; a folded lower wing must not prop up the torso.
  rig=Rig(joints)
  for f,p in actions['death'][0]:
   if f>=37:
    for side,sgn in [('L',1),('R',-1)]:
     for joint,angle in [('wing'+side,-sgn*38),('tip'+side,-sgn*65)]:
      parent=rig.parents[joint]
      target=Euler((0,math.radians(-sgn*12),math.radians(angle)),'XYZ').to_quaternion()
      local=rig.world(p,parent).to_quaternion().inverted() @ target
      p[joint]=tuple(math.degrees(v)for v in local.to_euler('XYZ'))+(None,)
    p['footR']=(0,-70,0,None)
  speed=6
 elif name=='vecna_clock':
  joints += [('body','root',(0,0,.2)),('dial','body',(0,.37,3.76)),('hour','dial',(0,.5,3.76)),('minute','dial',(0,.53,3.76)),('pendulum','body',(0,.16,2.78))]
  add('Base','body',(0,0,.19),(1.72,.94,.38),RIDGE);add('CaseBack','body',(0,-.29,2.38),(1.41,.16,4.25),BASE)
  for side in[-1,1]:add('CaseSide'+str(side),'body',(side*.6,0,2.38),(.21,.75,4.25),BASE)
  add('Panel','body',(0,-.18,1.84),(1.05,.08,2.55),DARK);add('Dial','dial',(0,.44,3.76),(1.13,.12,1.13),BONE)
  for k in range(12):
   a=k*math.tau/12;add('Tick'+str(k),'dial',(math.sin(a)*.46,.52,3.76+math.cos(a)*.46),(.07,.045,.11),DARK,(0,math.degrees(a),0))
  beam('HourHand','hour',(0,.57,3.76),(.2,.57,4.0),.07,.05,DARK);beam('MinuteHand','minute',(0,.6,3.76),(0,.6,4.16),.055,.04,DARK)
  beam('PendulumRod','pendulum',(0,.17,2.78),(0,.17,1.12),.07,.07,RIDGE);mass('PendulumWeight','pendulum',(0,.17,1.02),(.53,.16,.51),BONE,2,3)
  for s in[-1,1]:add('Pillar'+str(s),'body',(s*.68,.4,2.27),(.12,.14,3.95),RIDGE)
  add('Cornice','body',(0,0,4.57),(1.75,.94,.23),RIDGE);add('Crest','body',(0,0,4.78),(1.1,.83,.22),BASE)
  idle=[]
  for i in range(25):idle.append((i/24*90,pose(pendulum=(0,10*math.sin(i/24*math.tau),0),minute=(0,-28*math.sin(i/24*math.tau),0),hour=(0,-4*math.sin(i/24*math.tau-.3),0))))
  actions={'idle':(idle,True),'spawn':([(0,pose(body=(-9,0,0,(0,0,-.1)))),(9,pose(body=3,pendulum=(0,12,0))),(21,pose())],False),
   'hurt':([(0,pose()),(4,pose(body=(0,0,4),pendulum=(0,-16,0))),(14,pose())],False),
   'death':([(0,pose()),(7,pose(body=(6,0,5),pendulum=(0,21,0))),(20,pose(body=(26,0,-11),pendulum=(0,-29,0))),(38,pose(body=(88,0,-9),pendulum=(0,47,0))),(47,pose(body=(84,0,-9),pendulum=(0,-12,0))),(56,pose(body=(89,0,-9),pendulum=(0,4,0))),(66,pose(body=(89,0,-9),pendulum=(0,4,0)))],False)}
  speed=1
 else:
  assert name=='vecna_portal';joints += [('body','root',(0,0,2.8))]
  for k in range(8):
   a=k*math.tau/8;n='rim'+str(k);center=(math.sin(a)*2.0,0,2.8+math.cos(a)*2.5);joints.append((n,'body',center))
   for v in range(3):
    angle=a+(v-1)*math.tau/24
    add('RootRing'+str(k)+str(v),n,(math.sin(angle)*2.0,0,2.8+math.cos(angle)*2.5),(.56,.55,.68),BASE,(0,math.degrees(angle),0))
    add('RingRidge'+str(k)+str(v),n,(math.sin(angle)*1.96,.3,2.8+math.cos(angle)*2.46),(.17,.08,.43),RIDGE,(0,math.degrees(angle),0))
  def opening(u,t=0):
   p={}
   for k in range(8):
    a=k*math.tau/8;p['rim'+str(k)]=(4*math.sin(t+a),0,5*math.sin(t-a),(math.sin(a)*1.6*(u-1),0,math.cos(a)*2*(u-1)))
   return p
  actions={'idle':([(i/24*60,opening(1,i/24*math.tau))for i in range(25)],True),
   'spawn':([(0,opening(.05)),(9,opening(.4)),(21,opening(1.06)),(30,opening(1))],False),
   'close':([(0,opening(1)),(10,opening(.7)),(23,opening(.05))],False)};speed=1
 # Petals open for the contact, close softly when the creature collapses.
 for clip,(keys,loop) in actions.items():
  for f,p in keys:
   for k in range(5):
    if any(j[0]=='petal'+str(k)for j in joints):
     angle=k*math.tau/5;u=(.55 if clip=='bite' else -.45 if clip=='death' else .08)*math.sin(math.pi*min(1,f/max(1,keys[-1][0])))
     if clip=='death' and f>=keys[-1][0]*.65:u=-.45
     p['petal'+str(k)]=(math.degrees(u*math.cos(angle)),0,-math.degrees(u*math.sin(angle)),None)
  if loop:keys[-1]=(keys[-1][0],dict(keys[0][1]))
 if 'death' in actions:ground=['death']
 return {'NAME':name,'HERE':here,'JOINTS':joints,'PARTS':g.parts,'actions':lambda:actions,
  'TILE_STUDS':2,'GAME_LIFT':{'gain':1,'saturate':1},'BACKGROUND':(175,174,171),'BAKE_CURVES':True,'BATCH_SAMPLE':True,
  'GROUND_CLIPS':ground,'GROUND_SUBSTEPS':4,'EXTRA_JSON':{'walkSpeed':speed},
  'PREVIEW_PREFIX':name+'-preview-','PREVIEWS':[('idle',15)]+([('death',actions['death'][0][-1][0])]if 'death'in actions else[]),
  'PREVIEW_CAMERA':((9,14,7),(0,0,2 if name in['vecna_stalker','vecna_clock','vecna_portal']else .8),48)}
