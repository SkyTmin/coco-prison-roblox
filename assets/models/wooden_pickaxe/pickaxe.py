# Our pickaxes [владелец 26.10: «смоделируй деревянную кирку в блендер»; «давай первый вариант сделаем. Сделай
# следующие кирки и покажи мне эффект зачарования на них»] — voxel models, one voxel = 1/16 of the length (0.25 studs,
# so a pickaxe is ≈ 4 studs long like a held tool), not a copy of any Minecraft sprite. One shape for every material
# (the game's tiers: wood, stone, iron, diamond — tools.json materialAfter): an oak handle with grain and a grip, a
# binding where the head sits, an arched head. Each material has its own head palette and details: wooden planks with
# seams, chipped speckled stone, polished iron with a riveted collar and a leather grip, faceted diamond with a gold
# collar.
# Pipeline and the enchant glint: assets/models/voxeltool.py.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/wooden_pickaxe/pickaxe.py
#   [-- frames <dir>]
# → render-<material>-{icon,hero,icon-glint,hero-glint}.png and pickaxe.blend (diamond) next to this file;
#   with `frames`, 24 icon frames of the glint per material into <dir> (glint-<material>-NN.png) for the GIF.
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from voxeltool import run  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- palettes
OAK = ["#7a5532", "#6c4a2b", "#85603a"]  # handle grain
OAK_DARK = "#56391f"  # the shaded streak and the end caps
TWINE = (["#cdb68a", "#b49b6c"], "#8c7449")
LEATHER = (["#6b4428", "#5e3b22"], "#3e2614")

MATERIALS = {
    "wood": {
        "top": "#bd9058",  # the head's worn top edge
        "body": ["#a27846", "#966c3d"],
        "low": "#7c5a34",  # the head's underside
        "tip": "#d6b07a",
        "grip": TWINE,
        "bind": (["#cdb68a", "#b49b6c"], "#8c7449"),
    },
    "stone": {
        "top": "#a9a9a6",
        "body": ["#8c8c89", "#7e7e7b", "#959592"],
        "low": "#5f5f5c",
        "tip": "#b8b8b4",
        "fleck": ["#6a6a67", "#a3a3a0"],
        "grip": TWINE,
        "bind": (["#cdb68a", "#b49b6c"], "#8c7449"),
    },
    "iron": {
        "top": "#f2f2f2",  # the polished edge
        "body": ["#cdcdcd", "#c0c0c0"],
        "low": "#8a8a8c",
        "tip": "#ffffff",
        "grip": LEATHER,
        "bind": (["#5a5b61", "#515258"], "#3f4045"),
        "rivet": "#b4b4bc",
    },
    "diamond": {
        "top": "#aafff3",
        "body": ["#44d8c8", "#37c6b6"],
        "low": "#1c8a80",
        "tip": "#e2fffb",
        "facet": "#8af5e8",  # pale facet lines across the head
        "grip": LEATHER,
        "bind": (["#e8b830", "#d6a624"], "#a87a14"),
        "rivet": "#fff27a",
    },
}


# ---------------------------------------------------------------- the shape
def arch_top(x):
    d = abs(x + 0.5) / 8  # 0 at the middle, ≈ 1 at the tips
    return 14 - int(round(5.5 * d**1.8))


def shape(mat):
    pal = MATERIALS[mat]
    rng = random.Random(2610)
    vox = {}

    def put(x, y, z, col):
        vox[(x, y, z)] = col

    # the handle: 2×2 px, z -1..12
    grip, grip_dark = pal["grip"]
    for z in range(-1, 13):
        for x in (-1, 0):
            for y in (-1, 0):
                if z == -1:
                    col = OAK_DARK  # the butt
                elif z in (1, 2, 4, 5):
                    # the grip: two bands of wraps, the lower edge of each wrap darker
                    col = grip_dark if z in (1, 4) else grip[(x + y) % 2]
                elif x == -1 and y == 0 and z % 3 != 0:
                    col = OAK_DARK  # a dark grain streak down one corner
                else:
                    col = OAK[(z * 7 + x * 3 + y) % 3]
                put(x, y, z, col)

    # the head: an arch across x -8..7
    body = pal["body"]
    for x in range(-8, 8):
        top = arch_top(x)
        d = abs(x + 0.5)
        thick = 3 if d < 4 else (2 if d < 7 else 1)  # thicker over the handle, pointed at the tips
        depth = (-2, -1, 0, 1) if d < 2 else (-1, 0)  # swells over the handle
        for k in range(thick):
            z = top - k
            for y in depth:
                if d >= 7:
                    col = pal["tip"]
                elif k == 0:
                    col = pal["top"]
                elif k == thick - 1:
                    col = pal["low"]
                else:
                    col = body[(x + y) % len(body)]
                put(x, y, z, col)
        if mat == "wood" and x in (-5, -1, 3) and thick > 1:
            for y in depth:
                put(x, y, top - 1, pal["low"])  # a plank seam every 4 px
        if mat == "diamond" and x in (-5, -4, 2, 3) and thick > 1:
            for y in depth:
                put(x, y, top - (1 if x in (-5, 3) else 0), pal["facet"])  # two slanted facet lines

    if mat == "stone":
        # flecks in the stone and chips knocked out of the front top edge
        for key, col in list(vox.items()):
            if col in body and rng.random() < 0.3:
                vox[key] = pal["fleck"][rng.randrange(2)]
        for x in (-6, 2, 5):
            vox.pop((x, -1, arch_top(x)), None)

    # the binding round handle and head
    bind, bind_dark = pal["bind"]
    for z in range(10, 13):
        for x in range(-2, 2):
            for y in range(-2, 2):
                if x in (-1, 0) and y in (-1, 0):
                    continue  # the handle inside
                put(x, y, z, bind_dark if z == 11 else bind[0] if z == 12 else bind[1])
    if "rivet" in pal:
        for p in ((-2, -1, 11), (1, 0, 11), (0, -2, 11), (-1, 1, 11)):
            put(*p, pal["rivet"])  # one rivet on each face of the collar
    # the handle's end wedged through the head
    for x in (-1, 0):
        for y in (-1, 0):
            put(x, y, 15, OAK_DARK)
    return vox


ICON = ((0, math.radians(-45), 0), (0, -30, 0), 6.2, 60)  # flat front, the handle on the diagonal like an item sprite
HERO = ((math.radians(10), math.radians(-35), math.radians(30)), (3.2, -7.5, 2.2), None, 50)
run(HERE, "pickaxe", MATERIALS, shape, ICON, HERO)
