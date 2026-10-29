"""Original Splinter, authored against splinter-reference.png. No source-game geometry.
Headless: blender -b -P assets/models/splinter/splinter.py -- build
Then: blender -b assets/models/splinter/splinter.blend -P .../splinter.py -- export
Coordinates in studs: X lateral, Y forward, Z up. Wiki supplies clip names/durations only.
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, run, turned
from mathutils import Vector

NAME = "splinter"
HERE = os.path.dirname(os.path.abspath(__file__))
NOISE_FILE = "fur-noise.png"  # same seed/tile as the already uploaded rat fur
TILE_STUDS = 2.6
GAME_LIFT = {"saturate": 1.1, "gain": 1.04}
BACKGROUND = (188, 191, 189)
FUR = (100, 84, 72)
BACK = (73, 61, 53)
LIGHT = (152, 132, 114)
PINK = (185, 109, 101)
INNER = (213, 135, 122)
IVORY = (235, 220, 183)
CLOTH = (108, 41, 45)
ROPE = (159, 119, 66)
PARTS = []
JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 3.0)),
    ("head", "body", (0, .65, 5.9)),
    ("jaw", "head", (0, 1.45, 5.65)),
    ("earL", "head", (1.0, .5, 6.65)),
    ("earR", "head", (-1.0, .5, 6.65)),
]
for side, s in (("L", 1), ("R", -1)):
    JOINTS += [
        ("arm" + side, "body", (2.0*s, 0, 5.45)),
        ("fore" + side, "arm" + side, (2.5*s, .7, 4.05)),
        ("hand" + side, "fore" + side, (2.65*s, 1.7, 3.1)),
        ("leg" + side, "body", (1.2*s, -.2, 2.5)),
        ("foot" + side, "leg" + side, (1.35*s, .15, .75)),
    ]


def add(name, joint, x, y, z, color, **kw):
    PARTS.extend(box(name, joint, x, y, z, color, **kw))


def round_mass(name, joint, center, size, color, layers=5):
    """Rounded stepped solid: independently narrowing cross sections in BOTH horizontal axes.
    3 touching strips per height, broad centre and narrower front/back shoulders, no flat extrusion.
    """
    cx, cy, cz = center
    sx, sy, sz = size
    for i in range(layers):
        nz = (i + .5) / layers * 2 - 1
        r = math.sqrt(1 - nz*nz)
        z0, z1 = cz-sz/2+i*sz/layers, cz-sz/2+(i+1)*sz/layers
        for j in range(3):
            wy = (-1/3, 0, 1/3)[j]
            width = sx * r * (.78 if j != 1 else 1)
            depth = sy * r / 3
            y = cy + wy*sy*r
            tint = tuple(max(0, int(c * (1.035 if j == 2 else .95 if j == 0 else 1))) for c in color)
            add(f"{name}_{i}_{j}", joint, (cx-width/2, cx+width/2),
                (y-depth/2, y+depth/2), (z0, z1), tint)


# Barrel, high hunched back, breast plates; silhouette matches the four reference views.
round_mass("Torso", "body", (0, -.35, 4.55), (4.25, 3.35, 4.2), FUR, 7)
round_mass("Hump", "body", (0, -.85, 5.7), (3.65, 2.65, 2.5), BACK, 5)
for i, (width, y, z) in enumerate([(1.5, 1.12, 3.0), (2.3, 1.3, 3.45),
                                  (2.9, 1.4, 3.9), (2.85, 1.38, 4.35),
                                  (2.4, 1.28, 4.8), (1.85, 1.16, 5.25)]):
    add(f"Belly{i}", "body", (-width/2, width/2), (y-.2, y+.2), (z, z+.48), LIGHT)
# Ragged strips form a wrap all the way round, rather than a floating front apron.
for i in range(14):
    a = 2*math.pi*i/14
    x, y = 1.82*math.sin(a), 1.42*math.cos(a)-.25
    low = 1.7 + (.21*(i%3))
    add(f"Wrap{i}", "body", (x-.42, x+.42), (y-.18, y+.18), (low, 3.15),
        tuple(c+(i%3)*4 for c in CLOTH), rot=(0, 0, -math.degrees(a)))
    add(f"Rope{i}", "body", (x-.45, x+.45), (y-.23, y+.23), (3.03, 3.28),
        ROPE, rot=(0, 0, -math.degrees(a)))
add("Apron", "body", (-.75,.75), (1.16,1.4), (1.65,2.9), CLOTH)
add("ApronTip", "body", (-.33,.33), (1.22,1.45), (1.24,1.8), CLOTH)

# Wedge muzzle and independent opening jaw, brow wraps the front and side eye planes.
round_mass("Skull", "head", (0, .75, 6.05), (2.75, 2.5, 2.1), FUR, 5)
for i, (width, y0, y1, z0, z1) in enumerate([
    (2.25,1.5,2.15,5.65,6.8), (1.65,2.1,2.75,5.55,6.55),
    (1.12,2.7,3.45,5.5,6.25), (.82,3.4,3.8,5.5,6.04)]):
    add(f"Muzzle{i}", "head", (-width/2,width/2), (y0,y1), (z0,z1), FUR)
add("Nose", "head", (-.43,.43), (3.76,3.95), (5.65,6.03), PINK)
add("Mouth", "head", (-.85,.85), (1.9,3.42), (5.28,5.56), (40,31,29))
add("Jaw", "jaw", (-.65,.65), (1.35,3.33), (5.03,5.3), LIGHT)
add("Chin", "jaw", (-.48,.48), (2.4,3.4), (4.9,5.1), FUR)
add("Incisor", "head", (.035,.31), (3.32,3.62), (4.72,5.57), IVORY, mirror=True, rot=(-8,0,0))
add("Fang", "head", (.65,.87), (2.5,2.77), (5.0,5.59), IVORY, mirror=True, rot=(-12,-8,0))
add("EyeSocket", "head", (.85,1.37), (1.61,2.06), (6.05,6.54), (33,27,24), mirror=True)
add("EyeAmber", "head", (1.07,1.38), (1.93,2.075), (6.15,6.44), (234,146,31), mirror=True)
add("EyeSide", "head", (1.36,1.395), (1.73,1.97), (6.16,6.43), (216,126,24), mirror=True)
add("EyePupil", "head", (1.18,1.26), (2.075,2.09), (6.13,6.43), (25,21,18), mirror=True)
add("EyeGlint", "head", (1.08,1.15), (2.085,2.1), (6.36,6.43), IVORY, mirror=True)
add("Brow", "head", (.7,1.48), (1.55,2.13), (6.46,6.74), BACK, mirror=True, rot=(0,0,13))
for i in range(3):
    add(f"CheekTuft{i}", "head", (1.01+i*.08,1.42+i*.08), (.8+i*.3,1.3+i*.3),
        (5.2-i*.12,5.95), BACK, mirror=True)
for side, s in (("L",1),("R",-1)):
    # An asymmetric nick in the right ear is deliberate.
    for i, (w,z) in enumerate([(.9,6.65),(1.3,7.0),(1.22,7.35),(.8,7.7)]):
        cx = s*(1.12+(z-6.65)*.22)
        add(f"Ear{side}{i}", "ear"+side, (cx-w/2,cx+w/2), (.28,.67), (z,z+.37), BACK)
        iw = w-.22 if not(side=="R" and i==2) else w-.48
        add(f"EarInner{side}{i}", "ear"+side, (cx-iw/2,cx+iw/2), (.66,.74), (z,z+.37), INNER)

for side, s in (("L",1),("R",-1)):
    round_mass("Shoulder"+side, "arm"+side, (s*2.1,0,5.25), (1.6,1.95,2.0), BACK, 4)
    round_mass("UpperArm"+side, "arm"+side, (s*2.42,.4,4.45), (1.2,1.55,1.6), FUR, 3)
    round_mass("Forearm"+side, "fore"+side, (s*2.6,1.25,3.66), (1.14,1.9,1.25), FUR, 3)
    round_mass("Hand"+side, "hand"+side, (s*2.65,2.05,3.08), (1.25,.9,.65), BACK, 2)
    for i in range(3):
        x = s*(2.22+i*.4)
        add(f"Finger{side}{i}", "hand"+side, (x-.15,x+.15), (2.29,2.75), (2.7,3.15), PINK)
        add(f"Claw{side}{i}", "hand"+side, (x-.11,x+.11), (2.52,2.84), (2.17,2.83), IVORY, rot=(-18,0,0))
        add(f"ClawTip{side}{i}", "hand"+side, (x-.07,x+.07), (2.55,2.76), (2.02,2.25), IVORY, rot=(18,0,0))
    x = s*1.98
    add("Thumb"+side, "hand"+side, (x-.17,x+.17), (1.84,2.23), (2.55,3.13), PINK)
    add("ThumbClaw"+side, "hand"+side, (x-.1,x+.1), (2.04,2.31), (2.15,2.66), IVORY)
    round_mass("Haunch"+side, "leg"+side, (s*1.25,-.15,1.8), (1.9,2.0,2.15), FUR, 4)
    round_mass("Shin"+side, "leg"+side, (s*1.4,.2,.85), (1.18,1.2,1.0), BACK, 2)
    round_mass("Foot"+side, "foot"+side, (s*1.42,.65,.33), (1.85,2.2,.65), FUR, 2)
    for i in range(3):
        x=s*(.78+i*.58)
        add(f"Toe{side}{i}", "foot"+side, (x-.22,x+.22), (1.1,1.85), (.04,.46), PINK)
        add(f"ToeNail{side}{i}", "foot"+side, (x-.14,x+.14), (1.73,1.96), (.05,.26), IVORY)

# Two corked vials on the left hip; liquid is matte, not a light source.
for i,(x,z) in enumerate([(.92,2.75),(1.55,2.96)]):
    add(f"Bottle{i}", "body", (x-.27,x+.27), (1.38,1.9), (z-.7,z-.04), (62,101,58))
    add(f"Liquid{i}", "body", (x-.19,x+.19), (1.9,1.93), (z-.62,z-.18), (112,161,67))
    add(f"GlassEdge{i}", "body", (x-.23,x-.16), (1.93,1.95), (z-.6,z-.11), (167,185,136))
    add(f"Neck{i}", "body", (x-.13,x+.13), (1.51,1.77), (z-.04,z+.17), (90,126,74))
    add(f"Cork{i}", "body", (x-.16,x+.16), (1.48,1.8), (z+.15,z+.32), ROPE)

# Fur plates break up the smooth shoulder bands without thousands of tiny voxels.
for i in range(4):
    add(f"ShoulderTuft{i}", "arm*", (2.38,2.9), (-.3+i*.34,.12+i*.34),
        (4.7-i*.18,5.35-i*.1), BACK, mirror=True, rot=(8,12,0))
    add(f"Rag{i}", "body", (-1.5+i*.43,-1.22+i*.43), (1.22,1.48),
        (1.64+(i%2)*.22,2.36), tuple(c-6 for c in CLOTH), rot=(0,8-i*5,0))

pivot = Vector((0,-1.65,2.4))
for i,(length,thick,pitch) in enumerate([(1.1,.85,-15),(1.1,.72,-5),(1.05,.61,8),
                                       (.95,.5,25),(.8,.4,42),(.65,.31,62),(.45,.22,76)]):
    name = f"tail{i+1}"
    JOINTS.append((name,"body" if i==0 else f"tail{i}",tuple(pivot)))
    direction=Vector((.12,-math.cos(math.radians(pitch)),math.sin(math.radians(pitch)))).normalized()
    center=pivot+direction*length/2
    PARTS.append((name,name,tuple(center),(thick,length+.06,thick),PINK,None,(-pitch,0,7),{}))
    pivot+=direction*length

# A crouched stance: shorten the shins, spread the haunches and carry the head forward.
# Apply equally to vertices' centres and joint pivots so the rig keeps a true rest pose.
def silhouette(p, joint):
    x,y,z=p
    z *= .91
    y += max(0,z-2.7)*.19
    if joint in ("head","jaw","earL","earR"):
        y += .38
        z -= .24
    if joint.startswith(("leg","foot")):
        x += .22 if x>0 else -.22
    return x,y,z


PARTS=[(n,j,silhouette(c,j),(s[0],s[1],s[2]*.91),co,t,r,fl) for n,j,c,s,co,t,r,fl in PARTS]
JOINTS=[(n,p,silhouette(c,n)) for n,p,c in JOINTS]


def pose(**kw):
    return {k: ((v,0,0,None) if isinstance(v,(int,float)) else v) for k,v in kw.items()}


def actions():
    a={}
    idle=[]
    walk=[]
    for f in range(0,61,10):
        t=f/60*2*math.pi
        idle.append((f,pose(body=(0,0,0,(0,0,.07*math.sin(t))),head=(2*math.sin(t),0,2*math.sin(t),None),
                            jaw=2+2*math.sin(t),earL=(0,0,4*math.sin(t),None),earR=(0,0,-3*math.sin(t),None),
                            tail1=(0,0,7*math.sin(t),None),tail3=(0,0,10*math.sin(t-.5),None),tail5=(0,0,12*math.sin(t-1),None))))
    for f in range(0,31,5):
        t=f/30*2*math.pi
        s=math.sin(t)
        walk.append((f,pose(body=(-3,0,3*s,(0,0,.13*abs(s))),head=(2,0,-3*s,None),
                            legL=22*s,legR=-22*s,footL=-12*s,footR=12*s,
                            armL=-14*s,armR=14*s,foreL=6*s,foreR=-6*s,
                            tail1=(0,0,10*s,None),tail3=(0,0,12*math.sin(t-.7),None))))
    a["idle"]=(idle,True)
    a["walk"]=(walk,True)
    a["melee"]=([(0,{}),(8,pose(body=(6,0,-17,None),armR=85,foreR=-40,head=8)),
                   (13,pose(body=(-9,0,23,None),armR=32,foreR=0,handR=20,jaw=-12)),
                   (19,pose(body=(-6,0,17,None),armR=-12,handR=15)),(30,{})],False)
    a["swoop"]=([(0,{}),(10,pose(body=(-15,0,0,(0,0,-.5)),legL=25,legR=25,armL=-22,armR=-22)),
                   (17,pose(body=(-18,0,0,(0,0,.8)),legL=-22,legR=-22,armL=75,armR=75,foreL=-20,foreR=-20,jaw=-18)),
                   (25,pose(body=(-12,0,0,(0,0,-.32)),armL=35,armR=35)),(33,{})],False)
    a["potion"]=([(0,{}),(13,pose(body=(0,0,-15,None),armL=-12,foreL=32,handL=15)),
                   (24,pose(body=(7,0,-24,None),armL=145,foreL=-35,head=6)),
                   (30,pose(body=(-9,0,16,None),armL=75,foreL=10,handL=-24)),(46.5,{})],False)
    # 1.55s and 2.25s end at half-frames; the shared exporter preserves those subframes.
    a["shoot"]=([(0,{}),(23,pose(body=8,head=18,jaw=-24,armL=-8,armR=-8)),
                   (40,pose(body=10,head=24,jaw=-35)),(45,pose(body=-9,head=-12,jaw=-8)),
                   (54,pose(body=-4,head=-5,jaw=-18)),(67.5,{})],False)
    a["summon"]=([(0,{}),(24,pose(body=-10,head=-12,armL=22,armR=22,foreL=-15,foreR=-15)),
                    (48,pose(body=12,head=22,jaw=-28,armL=155,armR=155,foreL=-30,foreR=-30)),
                    (72,pose(body=9,head=16,jaw=-24,armL=147,armR=150)),
                    (90,pose(body=(-16,0,0,(0,0,-.3)),head=-8,armL=28,armR=28,handL=20,handR=20)),(120,{})],False)
    a["death"]=([(0,{}),(18,pose(body=(8,0,12,None),head=18,jaw=-24,armL=42,armR=10)),
                   (42,pose(body=(-8,40,-8,(0,0,-.2)),armL=40,armR=35,legL=15,legR=10)),
                   (65,pose(body=(0,91,-8,(0,0,.5)),head=12,jaw=-15,armL=45,armR=30,legL=15,legR=10,tail1=12)),
                   (90,pose(body=(0,87,-8,(0,0,.5)),head=8,jaw=-12,armL=45,armR=30,legL=15,legR=10,tail1=5)),
                   (120,pose(body=(0,87,-8,(0,0,.5)),head=8,jaw=-12,armL=45,armR=30,legL=15,legR=10,tail1=5))],False)
    a["roar"]=([(0,{}),(16,pose(body=8,head=22,jaw=-30,armL=35,armR=35)),
                  (38,pose(body=6,head=18,jaw=-24,armL=25,armR=25)),(54,{})],False)
    a["jump"]=([(0,{}),(7,pose(body=(-10,0,0,(0,0,-.3)),legL=20,legR=20)),
                  (14,pose(body=6,armL=35,armR=35,legL=-15,legR=-15)),(24,{})],False)
    a["stunned"]=([(0,pose(head=-12,body=-5)),(15,pose(head=(-15,0,8,None),body=-5)),
                     (30,pose(head=-12,body=-5))],True)
    return a


PREVIEW_CAMERA=((18,17,10),(0,-.5,3.4),48)
PREVIEWS=[("idle",0),("melee",13),("swoop",17),("potion",24),("shoot",40),("summon",48),
          ("death",95,((20,19,12),(1.7,0,2.6),48))]
COMPARE={
    "side":((0,-1,0),(0,0,1),(0,-.8,4),16),
    "front":((-1,0,0),(0,0,1),(0,0,4),13.5),
    "back":((-13,-18,10),(0,-1,3.8),48),
    "hero":PREVIEW_CAMERA,
}

if __name__ == "__main__":
    run(globals())
