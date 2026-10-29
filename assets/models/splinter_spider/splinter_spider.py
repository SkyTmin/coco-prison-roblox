"""Original temporary spider add; same block rig pipeline, no external model assets."""
import math
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, run

NAME="splinter_spider"
HERE=os.path.dirname(os.path.abspath(__file__))
NOISE_FILE="fur-noise.png"
TILE_STUDS=2.6
JOINTS=[("root",None,(0,0,0)),("body","root",(0,0,.65))]
PARTS=[]
for i,(w,y,z,h) in enumerate([(1.4,-.5,.65,.6),(1.1,-.5,1.03,.2),(.9,.45,.7,.5)]):
    PARTS+=box(f"Body{i}","body",(-w/2,w/2),(y-.5,y+.5),(z-h/2,z+h/2),(60,46,39))
for i in range(4):
    y=.6-i*.42
    for side,s in (("L",1),("R",-1)):
        j=f"leg{side}{i}"
        JOINTS.append((j,"body",(s*.5,y,.7)))
        x=s*.95
        PARTS+=box(j+"Upper",j,(x-.5,x+.5),(y-.095,y+.095),(.62,.82),(77,60,46),rot=(0,-s*15,0))
        x=s*1.4
        PARTS+=box(j+"Tip",j,(x-.1,x+.1),(y-.1,y+.1),(.04,.72),(96,75,53),rot=(0,s*15,0))
PARTS+=box("Eye","body",(.18,.32),(.94,1.01),(.77,.92),(220,139,32),mirror=True)
PARTS+=box("Fang","body",(.15,.26),(.93,1.15),(.3,.61),(219,205,162),mirror=True)

def actions():
    walk=[]
    for f in range(0,25,4):
        t=f/24*math.pi*2
        p={"body":(0,0,0,(0,0,.03*math.cos(t*2)))}
        for i in range(4):
            for side,s in (("L",1),("R",-1)):
                v=math.sin(t+i*math.pi+s*math.pi/2)
                p[f"leg{side}{i}"]=(0,s*12*max(0,v),s*22*v,None)
        walk.append((f,p))
    return {
        "walk":(walk,True),
        "idle":([(0,{"body":(0,0,0,(0,0,0))}),(30,{"body":(0,0,0,(0,0,.03))}),(60,{"body":(0,0,0,(0,0,0))})],True),
        "bite":([(0,{}),(5,{"body":(15,0,0,None)}),(7,{"body":(-15,0,0,(0,.15,0))}),(12,{})],False),
        "hurt":([(0,{}),(3,{"body":(0,0,12,None)}),(8,{})],False),
        "death":([(0,{}),(20,{"body":(0,0,160,(0,0,-.3))}),(30,{"body":(0,0,160,(0,0,-.3))})],False),
    }

PREVIEW_CAMERA=((4,6,4),(0,0,.5),48)
PREVIEWS=[("idle",0)]
COMPARE={"front":((-1,0,0),(0,0,1),(0,0,.6),4.5)}
if __name__=="__main__": run(globals())
