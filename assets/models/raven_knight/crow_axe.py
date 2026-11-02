"""Small original floating crescent axe; no particles or emissive geometry."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='crow_axe';HERE=os.path.dirname(os.path.abspath(__file__))
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BAKE_CURVES=True;BATCH_SAMPLE=True
JOINTS=[('root',None,(0,0,0)),('axe','root',(0,0,1.6))];g=Geometry()
g.add('Shaft','axe',(0,0,1.5),(.16,.18,2.8),(69,59,51))
for k in range(7):
 z=2.75-k*.19;w=.73-abs(k-3)*.09
 g.add('Blade'+str(k),'axe',(w/2+.02,0,z),(w,.18,.21),(59,65,74))
 g.add('Edge'+str(k),'axe',(w+.03,0,z),(.08,.2,.21),(133,135,135))
for k in range(5):g.add('Wrap'+str(k),'axe',(0,0,.7+k*.16),(.19,.21,.045),(103,97,86))
PARTS=g.parts
def actions():
 return {'idle':([(i*3,pose(axe=(0,0,0,(0,0,.13*math.sin(i/20*math.tau)))))for i in range(21)],True),
 'spin':([(i*1.5,pose(axe=(i*18,0,0)))for i in range(21)],True)}
PREVIEW_PREFIX='crow_axe-preview-';PREVIEWS=[('idle',0)];PREVIEW_CAMERA=((4,6,3),(0,0,1.5),48)
if __name__=='__main__':run(globals())
