# The zombie mob of the Подвал [владелец 22.10: «2 зомби по бокам шахты, кд 2 минуты»; 25 HP — вики]. No Codex
# sheet: the vanilla humanoid mob proportions (32 px tall: head 8, body 8×12×4, arms and legs 4×12×4) at
# 0.16 studs a pixel = 5.12 studs, our own colours; arms held forward like the vanilla zombie. Pipeline:
# assets/models/blockmob.py (skill .claude/skills/blender-block-mob, method A — hand boxes).
#
#   blender -b -P assets/models/zombie/zombie.py -- build
#   blender -b assets/models/zombie/zombie.blend -P assets/models/zombie/zombie.py -- export
#
# Blender space: X = the mob's left (…L), Y forward, Z up, origin on the ground.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, run  # noqa: E402

NAME = "zombie"
HERE = os.path.dirname(os.path.abspath(__file__))
NOISE_FILE = "skin-noise.png"
TILE_STUDS = 1.28  # one 16-texel tile = 8 px of the mob
GAME_LIFT = {"saturate": 1.3, "gain": 1.05}

P = 0.16  # studs per pixel
SKIN = (0x5F, 0x8F, 0x46)
SKIN_DARK = (0x4A, 0x73, 0x37)
HAIR = (0x3B, 0x5A, 0x2C)
SHIRT = (0x2E, 0x93, 0x98)
SHIRT_DARK = (0x23, 0x74, 0x79)
PANTS = (0x3E, 0x4C, 0xA0)
PANTS_DARK = (0x2F, 0x3A, 0x7E)
SHOE = (0x55, 0x55, 0x60)
EYE = (0x16, 0x1C, 0x14)
MOUTH = (0x2C, 0x3F, 0x22)


def px(a, b):
    return (a * P, b * P)


# pivots: hips at 12 px, shoulders at 22 px, neck at 24 px
JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 12 * P)),
    ("head", "body", (0, 0, 24 * P)),
    ("armL", "body", (6 * P, 0, 22 * P)),
    ("armR", "body", (-6 * P, 0, 22 * P)),
    ("legL", "body", (2 * P, 0, 12 * P)),
    ("legR", "body", (-2 * P, 0, 12 * P)),
]

PARTS = [
    # body: the shirt, torn at the hem (a darker band and two tatters), the belt line of the trousers below
    *box("Shirt", "body", px(-4, 4), px(-2, 2), px(14, 24), SHIRT, SHIRT_DARK),
    *box("Hem", "body", px(-4, 4), px(-2.05, 2.05), px(12, 14), PANTS, PANTS_DARK),
    *box("Tatter", "body", px(1, 3), px(-2.1, 2.1), px(13, 14.5), SHIRT_DARK, mirror=True),
    *box("Collar", "body", px(-2, 2), px(-2.1, -1), px(22.5, 24), SKIN_DARK),
    # head: green with darker hair on top and at the back, black eyes, a dark mouth
    *box("Head", "head", px(-4, 4), px(-4, 4), px(24, 32), SKIN, HAIR),
    *box("Hair", "head", px(-4.05, 4.05), px(-4.05, -1), px(30, 32.05), HAIR, HAIR),
    *box("HairBack", "head", px(-4.05, 4.05), px(-4.05, -3), px(26, 32.05), HAIR, HAIR),
    *box("Eye", "head", px(1, 3), px(3.9, 4.1), px(27, 28), EYE, mirror=True),
    *box("Brow", "head", px(1, 3), px(3.9, 4.08), px(28, 28.6), SKIN_DARK, mirror=True),
    *box("Nose", "head", px(-1, 1), px(3.95, 4.15), px(26, 27), SKIN_DARK),
    *box("Mouth", "head", px(-2, 2), px(3.9, 4.1), px(25, 25.6), MOUTH),
    # arms reaching forward from the shoulders: sleeve, then the green forearm and hand
    *box("Sleeve", "arm*", px(4, 8), px(-2, 4), px(20, 24), SHIRT, SHIRT_DARK, mirror=True),
    *box("Forearm", "arm*", px(4, 8), px(4, 10), px(20, 24), SKIN, SKIN_DARK, mirror=True),
    *box("Hand", "arm*", px(4.1, 7.9), px(10, 12), px(20.1, 23.9), SKIN_DARK, mirror=True),
    # legs: trousers and shoes
    *box("Leg", "leg*", px(0, 4), px(-2, 2), px(2, 12), PANTS, PANTS_DARK, mirror=True),
    *box("Shoe", "leg*", px(0, 4), px(-2, 2.3), px(0, 2), SHOE, mirror=True),
]


# ------------------------------------------------------------------ the animations
# key(frame, {joint: (rx, ry, rz in degrees, optional (dx, dy, dz) offset)}); +X swings a limb forward / up
def actions():
    acts = {}
    idle = []
    for f in range(0, 61, 5):
        t = f / 60 * math.pi * 2
        idle.append((f, {
            "body": (0, 0, 2 * math.sin(t), None),
            "head": (3 * math.sin(t), 0, 6 * math.sin(t * 0.5), None),
            "armL": (4 * math.sin(t), 0, 0, None),
            "armR": (4 * math.sin(t + 1.2), 0, 0, None),
        }))
    acts["idle"] = (idle, True)
    # the shambling walk: legs swing, the arms stay forward and bob, the body sways (20 frames)
    walk = []
    for f in range(0, 21, 2):
        t = f / 20 * math.pi * 2
        s = math.sin(t)
        walk.append((f, {
            "body": (-3, 0, 4 * s, (0, 0, 0.05 * abs(s))),
            "head": (2, 0, -4 * s, None),
            "legL": (32 * s, 0, 0, None),
            "legR": (-32 * s, 0, 0, None),
            "armL": (6 * math.sin(t + 0.5), 0, 0, None),
            "armR": (-6 * math.sin(t + 0.5), 0, 0, None),
        }))
    acts["walk"] = (walk, True)
    # the hit (MobWindup): both arms go up, then slam down (12 frames = 0.4 s)
    acts["bite"] = ([
        (0, {}),
        (7, {"armL": (55, 0, 0, None), "armR": (55, 0, 0, None), "body": (8, 0, 0, None), "head": (8, 0, 0, None)}),
        (9, {"armL": (-35, 0, 0, None), "armR": (-35, 0, 0, None), "body": (-12, 0, 0, (0, 0.2, 0)),
             "head": (-6, 0, 0, None)}),
        (12, {}),
    ], False)
    acts["hurt"] = ([
        (0, {}),
        (2, {"body": (10, 0, 5, (0, -0.25, 0)), "head": (15, 0, 0, None), "armL": (20, 0, 0, None),
             "armR": (20, 0, 0, None)}),
        (8, {}),
    ], False)
    # death: topples backwards onto the floor (20 frames, holds the last pose)
    acts["death"] = ([
        (0, {}),
        (8, {"root": (40, 0, 0, (0, -0.3, 0)), "armL": (25, 0, 0, None), "armR": (25, 0, 0, None)}),
        (16, {"root": (88, 0, 0, (0, -1.0, 0.35)), "armL": (40, 0, 10, None), "armR": (40, 0, -10, None),
              "head": (10, 0, 20, None)}),
        (20, {"root": (90, 0, 0, (0, -1.0, 0.33)), "armL": (40, 0, 12, None), "armR": (40, 0, -12, None),
              "head": (8, 0, 22, None)}),
    ], False)
    return acts


PREVIEWS = [("idle", 0), ("walk", 5), ("bite", 7), ("death", 20)]
PREVIEW_CAMERA = ((-9.0, 9.0, 5.0), (0, 0, 2.6), 45)
COMPARE = {}

run(globals())
