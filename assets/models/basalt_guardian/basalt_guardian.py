# Базальтовый страж, the Каменоломня boss, made in Blender like the rat [владелец 22.10: «создай босса в
# каменоломне по этой же логике, в таком же стиле, точь в точь»]. Reference: basalt-guardian-reference.png (Codex
# image gen, the rat sheet as the style reference): a hunched basalt golem, small head with glowing eye slits sunk
# between huge shoulders topped with basalt columns, long arms with fists below the knees, short legs, lava cracks,
# a blade of hardened lava (obsidian with a molten core) in the right hand [вики BOSS-CARDS: «клинок из застывшей
# лавы… базальтовые шипы»]. Pipeline: assets/models/blockmob.py, skill .claude/skills/blender-block-mob.
#
#   blender -b -P assets/models/basalt_guardian/basalt_guardian.py -- build
#   blender -b assets/models/basalt_guardian/basalt_guardian.blend -P assets/models/basalt_guardian/basalt_guardian.py -- export | compare
#
# Built from the reference's FRONT view cell by cell (voxelize.json → scripts/model-tools/voxelize-front.cjs →
# voxels.json; 45 px a stud, centre x 1188, ground y 473), each body part extruded over its depth range and
# rounded towards the silhouette [владелец 22.10: «вот тут было норм»]. +X = the golem's right hand (…L joints).
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, default_noise, run  # noqa: E402

NAME = "basalt_guardian"
HERE = os.path.dirname(os.path.abspath(__file__))
TILE_STUDS = 3.0  # coarser stone grain than the rat's fur (the golem is 4× bigger)
# the quarry arena is lit orange: the faint purple of the stone would turn pink, so the game desaturates it
GAME_LIFT = {"saturate": 0.6, "gain": 1.1}


def NOISE():
    # stone: deeper blotches than the fur, like the reference's blackstone-like pixels
    return default_noise(seed=11, depth=0.22, jitter=(-0.1, 0.07), floor=0.62)


# colours picked off the reference
STONE = (0x70, 0x68, 0x70)
STONE_TOP = (0x82, 0x7B, 0x84)
STONE_DARK = (0x4C, 0x46, 0x4E)
OBSIDIAN = (0x38, 0x30, 0x3B)
LAVA = (0xEC, 0x66, 0x18)
LAVA_HOT = (0xFF, 0xA8, 0x30)
GLOW_STRENGTH = 0.9

JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 3.5)),
    ("head", "body", (0, 1.0, 6.5)),
    ("armL", "body", (3.6, 0, 5.6)),
    ("armR", "body", (-3.8, 0, 5.6)),
    ("foreL", "armL", (3.9, 0.1, 3.2)),
    ("foreR", "armR", (-4.1, 0.1, 3.2)),
    ("sword", "foreL", (3.9, 0.35, 2.6)),  # the sword hand
    ("legL", "body", (0.9, 0, 3.4)),
    ("legR", "body", (-0.9, 0, 3.4)),
]


def voxel_parts():
    # the body is the reference's front view, cell by cell (scripts/model-tools/voxelize-front.cjs →
    # voxels.json): each box keeps its pixel colour (stone tones / glowing lava) and its region's depth,
    # rounded towards the silhouette
    with open(os.path.join(HERE, "voxels.json"), encoding="utf-8") as f:
        data = json.load(f)
    out = []
    for i, v in enumerate(data["boxes"]):
        out += box("V%d" % i, v["joint"], v["x"], v["y"], v["z"], tuple(v["colour"]), glow=v["glow"])
    return out


PARTS = voxel_parts()


# ------------------------------------------------------------------ the animations
# key(frame, {joint: (rx, ry, rz in degrees, optional (dx, dy, dz) offset)}). Signs (Blender): +X on an arm or leg
# swings it forward, on the head tilts it up, on the body leans it back; +Y on the +X arm swings it inward.
def actions():
    acts = {}
    sin = math.sin
    # idle: slow breathing, the head looking about, the arms swaying a little (3 s loop)
    idle = []
    for f in range(0, 91, 6):
        t = f / 90 * math.pi * 2
        idle.append((f, {
            "body": (1.5 * sin(t), 0, 0, (0, 0, 0.1 * sin(t))),
            "head": (2 * sin(t * 2), 0, 8 * sin(t), None),
            "armL": (3 * sin(t + 0.5), 0, 0, None),
            "armR": (-3 * sin(t + 0.5), 0, 0, None),
        }))
    acts["idle"] = (idle, True)
    # walk: heavy steps, the arms swinging against the legs, the body rocking (1 s loop at walk speed 8)
    walk = []
    for f in range(0, 31, 3):
        t = f / 30 * math.pi * 2
        s = sin(t)
        walk.append((f, {
            "body": (-4, 0, 3 * s, (0, 0, -0.3 * abs(math.cos(t)))),
            "head": (2, 0, -3 * s, None),
            "legL": (30 * s, 0, 0, None),
            "legR": (-30 * s, 0, 0, None),
            "armL": (-16 * s, 0, 0, None),
            "armR": (16 * s, 0, 0, None),
            "foreL": (10 + 6 * s, 0, 0, None),
            "foreR": (10 - 6 * s, 0, 0, None),
        }))
    acts["walk"] = (walk, True)
    # melee: the blade raised high behind the head, then a heavy chop down and forward (24 frames; the game
    # scales it to the attack's length)
    acts["melee"] = ([
        (0, {}),
        (11, {"armL": (160, 0, -10, None), "foreL": (25, 0, 0, None), "body": (8, 0, 12, None), "head": (10, 0, 0, None)}),
        (14, {"armL": (-15, 0, 5, None), "foreL": (5, 0, 0, None), "body": (-18, 0, -15, (0, 0.3, -0.2)), "head": (-10, 0, 0, None)}),
        (24, {}),
    ], False)
    # blade: the lava blade lifted and held over the telegraph (the game trembles it), then swept down
    acts["blade_raise"] = ([
        (0, {}),
        (15, {"armL": (165, 0, -15, None), "foreL": (20, 0, 0, None), "body": (6, 0, 15, None), "head": (10, 0, 0, None)}),
    ], False)
    acts["blade_sweep"] = ([
        (0, {"armL": (165, 0, -15, None), "foreL": (20, 0, 0, None), "body": (6, 0, 15, None), "head": (10, 0, 0, None)}),
        (7, {"armL": (-25, 0, 10, None), "foreL": (0, 0, 0, None), "body": (-20, 0, -20, (0, 0.4, -0.3)), "head": (-12, 0, 0, None)}),
        (27, {}),
    ], False)
    # spikes: both fists raised high and held, then slammed into the ground with a crouch
    up = {"armL": (170, 15, 0, None), "armR": (170, -15, 0, None), "foreL": (15, 0, 0, None),
          "foreR": (15, 0, 0, None), "body": (10, 0, 0, None), "head": (15, 0, 0, None)}
    acts["spikes_raise"] = ([(0, {}), (18, up)], False)
    acts["spikes_slam"] = ([
        (0, up),
        (4, {"armL": (35, 10, 0, None), "armR": (35, -10, 0, None), "foreL": (10, 0, 0, None),
             "foreR": (10, 0, 0, None), "body": (-35, 0, 0, (0, 0.2, -0.7)), "head": (-15, 0, 0, None),
             "legL": (30, 0, 0, None), "legR": (30, 0, 0, None)}),
        (18, {}),
    ], False)
    # charge: a forward lean with the arms swept back, held while it runs
    acts["charge"] = ([
        (0, {}),
        (12, {"body": (-30, 0, 0, (0, 0, -0.3)), "head": (20, 0, 0, None), "armL": (-50, 0, -15, None),
              "armR": (-50, 0, 15, None), "legL": (35, 0, 0, None), "legR": (-20, 0, 0, None)}),
    ], False)
    # stunned: slumped, the head lolling, swaying (2 s loop)
    stunned = []
    for f in range(0, 61, 6):
        t = f / 60 * math.pi * 2
        stunned.append((f, {
            "body": (-20, 0, 6 * sin(t), (0, 0, -0.4)),
            "head": (-25, 0, 15 * sin(t), None),
            "armL": (12, 0, 4, None), "armR": (12, 0, -4, None),
            "foreL": (15, 0, 0, None), "foreR": (15, 0, 0, None),
            "legL": (20, 0, 0, None), "legR": (20, 0, 0, None),
        }))
    acts["stunned"] = (stunned, True)
    # roar (spawn): the arms flung wide, the head thrown back, shaking (the game scales it to its length)
    roar = [(0, {})]
    for f in range(8, 49, 4):
        k = 3 * sin(f * 1.7)
        roar.append((f, {"armL": (40, 0, -65 + k, None), "armR": (40, 0, 65 - k, None), "foreL": (20, 0, 0, None),
                         "foreR": (20, 0, 0, None), "body": (12, 0, k, None), "head": (30, 0, -k, None)}))
    roar.append((60, {}))
    acts["roar"] = (roar, False)
    # jump (over a block when stuck): crouch, then stretch with the arms up
    acts["jump"] = ([
        (0, {}),
        (6, {"body": (-12, 0, 0, (0, 0, -0.6)), "legL": (35, 0, 0, None), "legR": (35, 0, 0, None),
             "armL": (-25, 0, 0, None), "armR": (-25, 0, 0, None)}),
        (12, {"body": (6, 0, 0, None), "armL": (60, 0, 0, None), "armR": (60, 0, 0, None),
              "legL": (-10, 0, 0, None), "legR": (-10, 0, 0, None)}),
        (20, {}),
    ], False)
    return acts


# ------------------------------------------------------------------ cameras
PREVIEWS = [("idle", 0), ("melee", 11), ("spikes_slam", 4), ("charge", 12)]
PREVIEW_CAMERA = ((-15, 17, 9), (0, 0.5, 4.5), 40)
# the reference sheet's panels: front (top-right, 45 px a stud, centre x 1188 → panel x 420, ground y 473),
# side (top-left, facing left, body centre x 480, ground y 475), three-quarter (front-left, perspective)
COMPARE = {
    "front": ((-1, 0, 0), (0, 0, 1), (36 / 45, 0, (473 - 256) / 45), 768 / 45),
    "side": ((0, -1, 0), (0, 0, 1), (0, 96 / 45, (475 - 256) / 45), 768 / 45),
    "34": ((-15, 18, 10), (0.8, 1.2, 4.6), 48),
    # close-ups of the blade (side and front) for checking its colours
    "blade": ((0, -1, 0), (0, 0, 1), (0, 2.8, 1.8), 7.5),
    "bladefront": ((-1, 0, 0), (0, 0, 1), (5.0, 0, 1.8), 7.5),
}

run(globals())
