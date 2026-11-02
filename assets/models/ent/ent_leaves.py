"""Original bounded leaf ring: articulated matte clusters, no particles or light."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='ent_leaves';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS=[('root',None,(0,0,0)),('lower','root',(0,0,0)),('middle','root',(0,0,1)),('upper','root',(0,0,2))]
g=Geometry()
for row,j in enumerate(['lower','middle','upper']):
 for i in range(8):
  a=i*math.pi/4+row*.2;r=1.6-row*.3
  g.add('Leaf'+str(row)+'_'+str(i),j,(r*math.cos(a),r*math.sin(a),row+.2*math.sin(a)),(.5,.27,.09),(88+row*10,100+row*8,69),(i*8,17,i*45))
PARTS=g.parts;TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169);BAKE_CURVES=True;BATCH_SAMPLE=True

def actions():
 return {'idle':([(i*3.75,pose(lower=(0,0,i*45),middle=(0,0,-i*45),upper=(0,0,i*45)))for i in range(9)],True)}
PREVIEW_PREFIX='ent_leaves-preview-';PREVIEWS=[('idle',5)];PREVIEW_CAMERA=((6,9,6),(0,0,1),48)
if __name__=='__main__':run(globals())
