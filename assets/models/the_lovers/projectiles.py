"""Original bounded projectile props, no neon or particles."""
import math
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose

def make(name,here):
 g=Geometry();add,beam=g.add,g.beam
 wood=(76,56,43);steel=(145,151,150);edge=(181,178,156);dark=(49,52,61)
 if name in ['lover_arrow','lover_spear']:
  length=3.4 if name=='lover_spear' else 2.4
  beam('Shaft','body',(0,-length*.4,0),(0,length*.6,0),.09,.09,wood)
  for s in[-1,1]:
   beam('Blade'+str(s),'body',(0,length*.6,0),(s*.16,length*.39,0),.11,.12,steel)
   if name=='lover_arrow':beam('Feather'+str(s),'body',(0,-length*.4,0),(s*.16,-length*.24,0),.09,.12,edge)
  actions={'idle':([(0,pose()),(30,pose())],True)}
 elif name=='lover_star':
  for k in range(4):
   a=k*math.pi/2
   beam('Blade'+str(k),'body',(.08*math.cos(a),0,.08*math.sin(a)),(.65*math.cos(a+.23),0,.65*math.sin(a+.23)),.22,.08,steel)
   beam('Edge'+str(k),'body',(.3*math.cos(a),.06,.3*math.sin(a)),(.64*math.cos(a+.23),.06,.64*math.sin(a+.23)),.055,.04,edge)
  add('Hub','body',(0,0,0),(.24,.14,.24),dark)
  actions={'spin':([(i*3,pose(body=(0,i*45,0)))for i in range(9)],True)}
 else:
  assert name=='lover_sickle'
  beam('Handle','body',(0,0,-.85),(0,0,.65),.15,.17,wood)
  for k in range(5):
   a=k/5*math.pi*.72;b=(k+1)/5*math.pi*.72
   beam('Blade'+str(k),'body',(math.sin(a)*.95,0,.12+math.cos(a)*.7),(math.sin(b)*.95,0,.12+math.cos(b)*.7),.2-.025*k,.12,steel)
  for k in range(5):add('Grip'+str(k),'body',(0,0,-.71+k*.1),(.18,.2,.04),dark)
  actions={'spin':([(i*3.75,pose(body=(0,i*45,0)))for i in range(9)],True)}
 clip=next(iter(actions))
 return {'NAME':name,'HERE':here,'JOINTS':[('root',None,(0,0,0)),('body','root',(0,0,0))], 'PARTS':g.parts,'actions':lambda:actions,
  'BAKE_CURVES':True,'BATCH_SAMPLE':True,'TILE_STUDS':2,'GAME_LIFT':{'gain':1,'saturate':1},'BACKGROUND':(174,173,169),
  'PREVIEW_PREFIX':name+'-preview-','PREVIEWS':[(clip,8)],'PREVIEW_CAMERA':((5,8,4),(0,0,0),48)}
