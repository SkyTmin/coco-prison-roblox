# Зомбарь, the faction-base boss, made in Blender like the Базальтовый страж [владелец 22.10: «сделай также
# модельку для зомбаря, так же, как с боссом»]. Reference: giant-zombie-reference-2.png (Codex, the guardian sheet
# as the style; «груда плоти, источающая гной» [клиент]): a hulking rotten zombie, arms stretched forward, a torn
# teal shirt, dark blue trousers, glowing yellow-green pus. Skill .claude/skills/blender-block-mob.
#
#   blender -b -P assets/models/giant_zombie/giant_zombie.py -- build
#   blender -b assets/models/giant_zombie/giant_zombie.blend -P assets/models/giant_zombie/giant_zombie.py -- export | compare
#
# Built from the reference cell by cell (voxelize.json → scripts/model-tools/voxelize-front.cjs → voxels.json):
# the front view gives every cell's colour, the side view each body part's depth and its side colours. 38 px a
# stud, front centre x 1167, ground y 490; side body centre x 470. +X = the zombie's right hand (…L joints).
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, default_noise, run  # noqa: E402

NAME = "giant_zombie"
HERE = os.path.dirname(os.path.abspath(__file__))
TILE_STUDS = 3.0
# the zombie's greens glare in the faction base's daylight: the game tones them down
GAME_LIFT = {"saturate": 0.85, "gain": 0.85}
GLOW_STRENGTH = 0.8


def NOISE():
    # rotten flesh and cloth: soft blotches
    return default_noise(seed=5, depth=0.16, jitter=(-0.08, 0.06), floor=0.68)


JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 4.6)),
    ("head", "body", (0, 3.5, 7.6)),
    ("armL", "body", (4.4, 2.6, 7.2)),
    ("armR", "body", (-4.4, 2.6, 7.2)),
    ("legL", "body", (2.1, 0, 3.6)),
    ("legR", "body", (-2.1, 0, 3.6)),
]


def voxel_parts():
    with open(os.path.join(HERE, "voxels.json"), encoding="utf-8") as f:
        data = json.load(f)
    out = []
    for i, v in enumerate(data["boxes"]):
        out += box("V%d" % i, v["joint"], v["x"], v["y"], v["z"], tuple(v["colour"]), glow=v["glow"])
    return out


PARTS = voxel_parts()


# ------------------------------------------------------------------ the animations
# Signs (Blender): +X on an arm raises it (the arms point forward at rest), on a leg swings it forward, on the
# head tilts it up, on the body leans it back. Clip names are the ones BossAnimator maps from the Action
# attribute; «blade» is the Зомбарь's pus vomit (head thrown back, then the stream forward).
def actions():
    acts = {}
    sin = math.sin
    # idle: heavy breathing, the head lolling, the outstretched arms bobbing (3 s loop)
    idle = []
    for f in range(0, 91, 6):
        t = f / 90 * math.pi * 2
        idle.append((f, {
            "body": (2 * sin(t), 0, 2 * sin(t * 0.5), (0, 0, 0.12 * sin(t))),
            "head": (-4 + 3 * sin(t * 2), 0, 10 * sin(t), None),
            "armL": (-6 + 5 * sin(t + 0.4), 0, 0, None),
            "armR": (-6 + 5 * sin(t + 1.6), 0, 0, None),
        }))
    acts["idle"] = (idle, True)
    # walk: a shambling, rolling gait, the arms swaying out of step (1.2 s loop)
    walk = []
    for f in range(0, 37, 3):
        t = f / 36 * math.pi * 2
        s = sin(t)
        walk.append((f, {
            "body": (-5, 0, 6 * s, (0, 0, -0.35 * abs(math.cos(t)))),
            "head": (-2, 0, -8 * s, None),
            "legL": (26 * s, 0, 0, None),
            "legR": (-26 * s, 0, 0, None),
            "armL": (-8 + 8 * s, 0, 5 * s, None),
            "armR": (-8 - 8 * s, 0, 5 * s, None),
        }))
    acts["walk"] = (walk, True)
    # melee: both fists raised, then clubbed down in front of it (24 frames, stretched to the attack)
    acts["melee"] = ([
        (0, {}),
        (10, {"armL": (55, 0, 0, None), "armR": (55, 0, 0, None), "body": (10, 0, 0, None), "head": (12, 0, 0, None)}),
        (14, {"armL": (-45, 0, 0, None), "armR": (-45, 0, 0, None), "body": (-18, 0, 0, (0, 0.4, -0.3)),
              "head": (-12, 0, 0, None)}),
        (24, {}),
    ], False)
    # the pus vomit («blade»): the head thrown back and held over the telegraph, then the stream retched forward
    back = {"head": (30, 0, 0, None), "body": (14, 0, 0, None), "armL": (25, 0, -15, None),
            "armR": (25, 0, 15, None)}
    acts["blade_raise"] = ([(0, {}), (15, back)], False)
    acts["blade_sweep"] = ([
        (0, back),
        (6, {"head": (-35, 0, 0, None), "body": (-25, 0, 0, (0, 0.5, -0.3)), "armL": (-20, 0, -25, None),
             "armR": (-20, 0, 25, None)}),
        (27, {}),
    ], False)
    # spikes: both fists high and held, then hammered into the ground with a crouch
    up = {"armL": (80, 0, 0, None), "armR": (80, 0, 0, None), "body": (12, 0, 0, None), "head": (15, 0, 0, None)}
    acts["spikes_raise"] = ([(0, {}), (18, up)], False)
    acts["spikes_slam"] = ([
        (0, up),
        (4, {"armL": (-70, 0, 0, None), "armR": (-70, 0, 0, None), "body": (-30, 0, 0, (0, 0.3, -0.8)),
             "head": (-15, 0, 0, None), "legL": (30, 0, 0, None), "legR": (30, 0, 0, None)}),
        (18, {}),
    ], False)
    # charge: a lumbering lean, the arms forward, held while it runs
    acts["charge"] = ([
        (0, {}),
        (12, {"body": (-25, 0, 0, (0, 0, -0.3)), "head": (15, 0, 0, None), "armL": (10, 0, 0, None),
              "armR": (10, 0, 0, None), "legL": (30, 0, 0, None), "legR": (-20, 0, 0, None)}),
    ], False)
    # stunned: slumped, the arms hanging, swaying (2 s loop)
    stunned = []
    for f in range(0, 61, 6):
        t = f / 60 * math.pi * 2
        stunned.append((f, {
            "body": (-18, 0, 7 * sin(t), (0, 0, -0.4)),
            "head": (-30, 0, 14 * sin(t), None),
            "armL": (-60, 0, 0, None), "armR": (-60, 0, 0, None),
            "legL": (18, 0, 0, None), "legR": (18, 0, 0, None),
        }))
    acts["stunned"] = (stunned, True)
    # roar (spawn): the arms flung wide and up, the head thrown back, shaking
    roar = [(0, {})]
    for f in range(8, 49, 4):
        k = 3 * sin(f * 1.7)
        roar.append((f, {"armL": (30, -40 + k, 0, None), "armR": (30, 40 - k, 0, None), "body": (12, 0, k, None),
                         "head": (32, 0, -k, None)}))
    roar.append((60, {}))
    acts["roar"] = (roar, False)
    # jump (over a block when stuck)
    acts["jump"] = ([
        (0, {}),
        (6, {"body": (-12, 0, 0, (0, 0, -0.6)), "legL": (35, 0, 0, None), "legR": (35, 0, 0, None),
             "armL": (-30, 0, 0, None), "armR": (-30, 0, 0, None)}),
        (12, {"body": (6, 0, 0, None), "armL": (40, 0, 0, None), "armR": (40, 0, 0, None),
              "legL": (-10, 0, 0, None), "legR": (-10, 0, 0, None)}),
        (20, {}),
    ], False)
    return acts


# ------------------------------------------------------------------ cameras
PREVIEWS = [("idle", 0), ("melee", 10), ("blade_sweep", 6), ("spikes_slam", 4)]
PREVIEW_CAMERA = ((-22, 26, 12), (0, 2.5, 5.5), 40)
# the sheet's panels: front (top-right, 38 px a stud, centre x 1167 → panel x 399, ground y 490), side (top-left,
# facing left, body centre x 470, ground y 490), three-quarter (front-left, perspective)
COMPARE = {
    "front": ((-1, 0, 0), (0, 0, 1), (15 / 38, 0, (490 - 256) / 38), 768 / 38),
    "side": ((0, -1, 0), (0, 0, 1), (0, 86 / 38, (490 - 256) / 38), 768 / 38),
    "34": ((-20, 24, 13), (0, 2.5, 6.0), 45),
    # close-ups for checking
    "back": ((1, 0, 0), (0, 0, 1), (0, 0, 6.2), 21),
    "back34": ((14, -20, 12), (0, 0, 5.5), 40),
    "headside": ((0, -1, 0), (0, 0, 1), (0, 3.0, 8.5), 9),
    "armtop": ((0, -1, 0), (1, 0, 0), (0, 5.0, 0), 16),
}

run(globals())
