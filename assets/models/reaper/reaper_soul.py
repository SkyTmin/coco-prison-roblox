"""Original small soul-mask projectile, matte and finite."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='reaper_soul';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS=[('root',None,(0,0,0)),('head','root',(0,0,0)),('jaw','head',(0,.25,-.2)),('tail','head',(0,-.35,0))]
g=Geometry();g.mass('Skull','head',(0,0,0),(.82,.85,.73),(115,155,137),3,3)
for side,s in [('L',1),('R',-1)]:
 g.add('Socket'+side,'head',(s*.2,.43,.13),(.23,.05,.2),(35,49,44))
 g.add('Cheek'+side,'head',(s*.27,.44,-.12),(.16,.1,.22),(150,174,153))
g.add('Jaw','jaw',(0,.29,-.3),(.5,.38,.18),(150,174,153))
for k in range(3):g.add('Trail'+str(k),'tail',(0,-.55-k*.22,0),(.4-k*.09,.26,.33-k*.07),(75,105,88))
PARTS=g.parts
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,177,174);BAKE_CURVES=True;BATCH_SAMPLE=True
def actions():return {'flight':([(i*2,pose(head=(0,0,4*math.sin(i/12*math.pi*2)),jaw=8+4*math.sin(i/12*math.pi*2),tail=(0,0,5*math.sin(i/12*math.pi*2-.6))))for i in range(13)],True)}
PREVIEW_PREFIX='reaper_soul-preview-';PREVIEWS=[('flight',6)];PREVIEW_CAMERA=((4,6,3),(0,0,0),48)
if __name__=='__main__':run(globals())
