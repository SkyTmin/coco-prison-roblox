# The rat mob, made in Blender [владелец 22.10: «сделай модельку крысы в блендере и анимации к ней, по фото от
# Codex, стиль — как в игре»; «чтобы было точь в точь»]. Reference: assets/models/rat/rat-reference.png (Codex
# image gen: side / front / top / three-quarter views on a 1536×1024 sheet). Pipeline: assets/models/blockmob.py
# (build / export / compare), skill .claude/skills/blender-block-mob.
#
#   blender -b -P assets/models/rat/rat.py -- build
#   blender -b assets/models/rat/rat.blend -P assets/models/rat/rat.py -- export | compare
#
# Every box is measured off the reference side view (x px → Y = (400 − x) / 140, y px → Z = (445 − y) / 140)
# and the front / top views for the widths. The fur is the pixel noise tile tinted per part; top faces of the
# back are darker like on the reference.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, run, turned  # noqa: E402
from mathutils import Vector  # noqa: E402

NAME = "rat"
HERE = os.path.dirname(os.path.abspath(__file__))
NOISE_FILE = "fur-noise.png"
TILE_STUDS = 2.25  # one 16-texel noise tile covers this many studs
# Roblox's cool sky light greys the low-saturation fur: the game lifts it
GAME_LIFT = {"saturate": 1.6, "gain": 1.1}

# albedo picked off the reference's lit faces
FUR = (0x91, 0x83, 0x7A)
FUR_BACK = (0x66, 0x5A, 0x53)  # the darker back (top faces)
FUR_MID = (0x6C, 0x60, 0x59)  # the upper sides of the back
FUR_DARK = (0x70, 0x63, 0x5C)  # legs
FUR_LIGHT = (0xC4, 0xB6, 0xAD)  # belly, chest, chin
PINK = (0xE8, 0x90, 0x8E)
PINK_LIGHT = (0xF2, 0xA6, 0xA2)
BLACK = (0x14, 0x12, 0x12)
WHITE = (0xF0, 0xEC, 0xE2)


def ear(side):
    # a round pink plate (a pixel circle) with a lighter middle, turned a little outward (front and top views show them facing forward)
    x = (0.22, 0.78)
    parts = [
        *box("Ear" + side, "head", x, (1.0, 1.24), (1.67, 2.04), PINK),
        *box("EarTop" + side, "head", (0.32, 0.68), (1.0, 1.24), (2.04, 2.16), PINK),
        *box("EarLow" + side, "head", (0.32, 0.68), (1.0, 1.24), (1.56, 1.67), PINK),
        *box("EarIn" + side, "head", (0.34, 0.66), (1.24, 1.27), (1.72, 2.0), PINK_LIGHT),
    ]
    if side == "R":
        parts = [(n, j, (-c[0], c[1], c[2]), sz, col, t, r, fl) for n, j, c, sz, col, t, r, fl in parts]
    return turned(parts, (0.5 if side == "L" else -0.5, 1.12), -10 if side == "L" else 10)


# the tail: four pink segments stepping up and thinning (side view: 0.71 / 0.79 / 0.68 studs, the last two rising)
TAIL = [(0.74, 0.36, 4), (0.78, 0.32, 14), (0.68, 0.28, 38), (0.46, 0.24, 56)]  # length, thickness, pitch up°
TAIL_BASE = Vector((0, -1.66, 0.97))

JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 1.0)),
    ("head", "body", (0, 0.85, 1.2)),
    ("legFL", "body", (0.6, 0.88, 0.6)),
    ("legFR", "body", (-0.6, 0.88, 0.6)),
    ("legBL", "body", (0.64, -0.95, 0.6)),
    ("legBR", "body", (-0.64, -0.95, 0.6)),
]
PARTS = []
pivot = TAIL_BASE.copy()
for i, (length, thick, pitch) in enumerate(TAIL):
    name = "tail%d" % (i + 1)
    JOINTS.append((name, "body" if i == 0 else "tail%d" % i, tuple(pivot)))
    d = Vector((0, -math.cos(math.radians(pitch)), math.sin(math.radians(pitch))))
    centre = pivot + d * (length / 2)
    PARTS.append(("Tail%d" % (i + 1), name, tuple(centre), (thick, length + 0.04, thick), PINK, None,
                  (-pitch, 0, 0)))
    pivot = pivot + d * length

PARTS += [
    # body: a long block stepping up to the hump in the middle of the back, the rump rounding down
    *box("Body", "body", (-0.78, 0.78), (-0.7, 0.95), (0.36, 1.39), FUR),
    *box("Rump", "body", (-0.78, 0.78), (-1.71, -0.7), (0.52, 1.39), FUR, FUR_BACK),
    *box("Back1", "body", (-0.72, 0.72), (-1.43, 0.93), (1.39, 1.61), FUR, FUR_BACK),
    *box("Back2", "body", (-0.62, 0.62), (-1.14, 0.93), (1.61, 1.75), FUR_MID, FUR_BACK),
    *box("Back3", "body", (-0.48, 0.48), (-0.5, 0.57), (1.75, 1.89), FUR_BACK, FUR_BACK),
    *box("Haunch", "body", (0.75, 0.9), (-1.4, -0.48), (0.46, 1.16), FUR, FUR_BACK, mirror=True),
    *box("Shoulder", "body", (0.75, 0.84), (0.42, 1.0), (0.5, 1.02), FUR, FUR_BACK, mirror=True),
    # the light belly band along both sides and under the chest
    *box("Belly", "body", (-0.8, 0.8), (-0.7, 0.97), (0.34, 0.8), FUR_LIGHT),
    *box("BellyRear", "body", (-0.8, 0.8), (-1.66, -0.7), (0.5, 0.8), FUR_LIGHT),
    *box("Chest", "body", (-0.5, 0.5), (0.9, 1.44), (0.44, 0.86), FUR_LIGHT),
    # head: a box with a step on top, the snout in front, the pink nose and two teeth at its tip
    *box("Head", "head", (-0.64, 0.64), (0.72, 1.76), (0.8, 1.6), FUR, FUR_BACK),
    *box("HeadTop", "head", (-0.5, 0.5), (0.72, 1.6), (1.6, 1.68), FUR_BACK, FUR_BACK),
    *box("Muzzle", "head", (-0.43, 0.43), (1.74, 2.04), (0.8, 1.5), FUR, FUR_BACK),
    *box("Snout", "head", (-0.29, 0.29), (2.0, 2.5), (0.84, 1.42), FUR),
    *box("Chin", "head", (-0.42, 0.42), (1.2, 2.04), (0.6, 0.84), FUR_LIGHT),
    *box("Nose", "head", (-0.15, 0.15), (2.48, 2.72), (1.04, 1.34), PINK),
    *box("ToothL", "head", (0.01, 0.13), (2.42, 2.52), (0.7, 0.85), WHITE),
    *box("ToothR", "head", (-0.13, -0.01), (2.42, 2.52), (0.7, 0.85), WHITE),
    *box("Eye", "head", (0.5, 0.66), (1.6, 1.78), (1.14, 1.46), BLACK, mirror=True),  # wraps the corner: seen from the front and the side
    # ears: round pink plates standing on the back of the head
    *ear("L"),
    *ear("R"),
    # legs: short dark legs standing out of the body sides, big pink paws reaching forward
    *box("LegF", "legF*", (0.42, 0.78), (0.68, 1.08), (0.15, 0.62), FUR_DARK, mirror=True),
    *box("PawF", "legF*", (0.4, 0.8), (0.74, 1.3), (0.0, 0.18), PINK, mirror=True),
    *box("LegB", "legB*", (0.44, 0.84), (-1.24, -0.7), (0.14, 0.62), FUR_DARK, mirror=True),
    *box("PawB", "legB*", (0.42, 0.86), (-1.2, -0.6), (0.0, 0.16), PINK, mirror=True),
]


# ------------------------------------------------------------------ the animations
# key(frame, {joint: (rx, ry, rz in degrees, optional (dx, dy, dz) offset)})
def actions():
    acts = {}
    # idle: breathing, sniffing, a lazy tail sway (2 s loop)
    idle = []
    for f in range(0, 61, 5):
        t = f / 60 * math.pi * 2
        idle.append((f, {
            "body": (0, 0, 0, (0, 0, 0.03 * math.sin(t))),
            "head": (6 * max(0, math.sin(t * 3)) - 2, 0, 4 * math.sin(t), None),
            "tail1": (0, 0, 8 * math.sin(t), None),
            "tail2": (0, 0, 10 * math.sin(t - 0.6), None),
            "tail3": (0, 0, 12 * math.sin(t - 1.2), None),
            "tail4": (4 * math.sin(t), 0, 14 * math.sin(t - 1.8), None),
        }))
    acts["idle"] = (idle, True)
    # walk / run: diagonal legs together, the body bobs, the tail waves (16 frames ≈ 0.53 s at 13 studs/s)
    walk = []
    for f in range(0, 17, 2):
        t = f / 16 * math.pi * 2
        s = math.sin(t)
        walk.append((f, {
            "body": (2 * math.sin(t * 2), 0, 0, (0, 0, 0.09 * abs(math.sin(t)))),
            "head": (-3 * math.sin(t * 2), 0, 0, None),
            "legFL": (38 * s, 0, 0, None),
            "legBR": (38 * s, 0, 0, None),
            "legFR": (-38 * s, 0, 0, None),
            "legBL": (-38 * s, 0, 0, None),
            "tail1": (-4, 0, 12 * math.sin(t), None),
            "tail2": (0, 0, 14 * math.sin(t - 0.8), None),
            "tail3": (0, 0, 16 * math.sin(t - 1.6), None),
            "tail4": (4, 0, 18 * math.sin(t - 2.4), None),
        }))
    acts["walk"] = (walk, True)
    # bite: rear up with the front paws raised (the wind-up the player sees), then a lunge with the head down
    # (12 frames = 0.4 s). Signs: +X turns the nose up, the legs forward, the tail down.
    acts["bite"] = ([
        (0, {}),
        (7, {"body": (22, 0, 0, (0, -0.2, 0.15)), "head": (14, 0, 0, None), "legFL": (45, 0, 0, None),
             "legFR": (45, 0, 0, None), "legBL": (-15, 0, 0, None), "legBR": (-15, 0, 0, None),
             "tail1": (-18, 0, 0, None)}),
        (9, {"body": (-12, 0, 0, (0, 0.55, 0)), "head": (-24, 0, 0, None), "legFL": (30, 0, 0, None),
             "legFR": (30, 0, 0, None), "legBL": (-25, 0, 0, None), "legBR": (-25, 0, 0, None),
             "tail1": (10, 0, 0, None)}),
        (12, {}),
    ], False)
    # hurt: a flinch back with the head thrown up and the tail stiff (8 frames ≈ 0.27 s)
    acts["hurt"] = ([
        (0, {}),
        (2, {"body": (12, 0, 6, (0, -0.35, 0.1)), "head": (20, 0, 0, None), "tail1": (-25, 0, 0, None),
             "tail2": (-15, 0, 0, None)}),
        (8, {}),
    ], False)
    # death: rolls onto its side, the legs stick out, the tail droops (20 frames, holds the last pose)
    acts["death"] = ([
        (0, {}),
        (6, {"root": (0, -40, 0, (0, 0, 0.25)), "head": (-10, 0, 0, None)}),
        (14, {"root": (0, -92, 0, (0, 0, 0.8)), "legFL": (0, 0, 25, None), "legFR": (0, 0, -25, None),
              "legBL": (0, 0, 25, None), "legBR": (0, 0, -25, None), "head": (10, 0, 15, None),
              "tail1": (-10, 0, 20, None), "tail2": (-10, 0, 15, None)}),
        (20, {"root": (0, -90, 0, (0, 0, 0.8)), "legFL": (0, 0, 30, None), "legFR": (0, 0, -30, None),
              "legBL": (0, 0, 30, None), "legBR": (0, 0, -30, None), "head": (8, 0, 15, None),
              "tail1": (-15, 0, 20, None), "tail2": (-15, 0, 18, None)}),
    ], False)
    return acts


# ------------------------------------------------------------------ cameras
PREVIEWS = [("idle", 0), ("walk", 4), ("bite", 7), ("death", 20)]
PREVIEW_CAMERA = ((-7.5, 4.6, 4.2), (0, -0.3, 0.9), 45)
# the reference sheet's 768×512 panels: side (nose left, 140 px a stud, x 400 ↔ Y 0, y 445 ↔ ground), front
# (centre x 1220 → panel x 452), top (125 px a stud, nose tip at x 20, centre line y 730 → 218), three-quarter
COMPARE = {
    "side": ((0, -1, 0), (0, 0, 1), (0, 16 / 140, (445 - 256) / 140), 768 / 140),
    "front": ((-1, 0, 0), (0, 0, 1), (68 / 140, 0, (445 - 256) / 140), 768 / 140),
    "top": ((0, -1, 0), (1, 0, 0), (-38 / 125, 2.72 - (384 - 20) / 125, 0), 768 / 125),
    "34": ((-6.6, 6.0, 4.6), (0, -0.7, 0.75), 56),
}

run(globals())
