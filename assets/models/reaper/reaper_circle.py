"""Original matte circle, separate tiny prop instead of a large-rig glow."""
import os,sys,math
sys.path.insert(0,os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import run
from undead_king.necromancer_parts import Geometry
from splinter.motion import pose
NAME='reaper_circle';HERE=os.path.dirname(os.path.abspath(__file__))
JOINTS=[('root',None,(0,0,0)),('outer','root',(0,0,0)),('inner','root',(0,0,0)),('glyph','inner',(0,0,0))]
g=Geometry()
for name,r,col in [('outer',2.25,(93,133,111)),('inner',1.83,(115,155,137))]:
 for k in range(16):
  a=k*math.pi/8;b=(k+1)*math.pi/8
  g.beam(name+str(k),name,(math.cos(a)*r,math.sin(a)*r,.08),(math.cos(b)*r,math.sin(b)*r,.08),.08,.1,col)
for k in range(6):
 a=k*math.pi/3;b=a+math.pi*2/3
 g.beam('Glyph'+str(k),'glyph',(math.cos(a)*1.35,math.sin(a)*1.35,.09),(math.cos(b)*1.35,math.sin(b)*1.35,.09),.07,.09,(115,155,137))
PARTS=g.parts
TILE_STUDS=2;GAME_LIFT={'gain':1,'saturate':1};BACKGROUND=(174,177,174);BAKE_CURVES=True;BATCH_SAMPLE=True
def actions():
 return {'idle':([(i*7.5,pose(outer=(0,0,i*15),inner=(0,0,-i*15),glyph=(0,0,i*15)))for i in range(25)],True)}
PREVIEW_PREFIX='reaper_circle-preview-';PREVIEWS=[('idle',30)];PREVIEW_CAMERA=((6,8,9),(0,0,0),48)
if __name__=='__main__':run(globals())
