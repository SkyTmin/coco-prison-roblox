"""Original emerging articulated root, matte noncolliding encounter prop."""
import os,sys
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='ent_branch';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS=[('root',None,(0,0,0)),('lower','root',(0,0,0)),('middle','lower',(0,.14,1.65)),('tip','middle',(.2,.37,3.14))]
g=Geometry();beam=g.beam
for n,j,a,b,w in [('Base','lower',(0,0,-.1),(0,.14,1.8),.75),('Middle','middle',(0,.14,1.65),(.2,.37,3.3),.55),('Tip','tip',(.2,.37,3.14),(.37,1.07,4.55),.27),('Fork','middle',(.12,.3,2.55),(-.7,.5,3.4),.22)]:
 beam(n,j,a,b,w,w,(80,58,39));beam(n+'Ridge',j,(a[0]-.12,a[1]+w*.4,a[2]),(b[0]-.08,b[1]+w*.4,b[2]),w*.2,.11,(125,89,57))
PARTS=g.parts
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,173,169);BAKE_CURVES=True;BATCH_SAMPLE=True

def actions():
 return {'spawn':([(0,pose(root=(0,0,0,(0,0,-4.7)),lower=-29,middle=23,tip=-31)),(8,pose(root=(0,0,0,(0,0,-2)),lower=-13,middle=11,tip=-14)),(13,pose(lower=2,middle=-6,tip=9)),(19,pose(lower=-3,middle=4,tip=-4)),(33,pose()),(50.001,pose(root=(0,0,0,(0,0,-4.7))))],False)}
PREVIEW_PREFIX='ent_branch-preview-';PREVIEWS=[('spawn',14)];PREVIEW_CAMERA=((8,12,7),(0,0,2),48)
if __name__=='__main__':run(globals())
