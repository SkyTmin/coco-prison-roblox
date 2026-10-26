# Our axes [владелец 26.10: «топор теперь»; «больше сделай его похожим на майнкрафтовский»] — voxel models in the same
# style as the pickaxes and swords (assets/models/wooden_pickaxe/pickaxe.py, assets/models/sword/sword.py): one voxel =
# 0.25 studs, the axe ≈ 4.25 studs long. The Minecraft silhouette (a broad block-like head capping the handle, a nub
# behind it) with our own colours and details, not a copy of the sprite. One shape for every material (the game's
# tiers: wood, stone, iron, diamond — tools.json toolDamage.axe): a plank seam on wood, chipped speckled stone, a
# polished strip behind the edge and a leather grip on iron, facets on diamond.
# Pipeline and the enchant glint: assets/models/voxeltool.py.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/axe/axe.py [-- frames <dir>]
# → render-<material>-{icon,hero,icon-glint,hero-glint}.png and axe.blend (diamond) next to this file;
#   with `frames`, 24 icon frames of the glint per material into <dir> (glint-<material>-NN.png) for the GIF.
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from voxeltool import run  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

# ---------------------------------------------------------------- palettes
OAK = ["#7a5532", "#6c4a2b", "#85603a"]
OAK_DARK = "#56391f"
TWINE = (["#cdb68a", "#b49b6c"], "#8c7449")
LEATHER = (["#6b4428", "#5e3b22"], "#3e2614")

MATERIALS = {
    "wood": {
        "body": ["#a27846", "#966c3d"],
        "top": "#bd9058",
        "low": "#7c5a34",
        "edge": "#d6b07a",
        "grip": TWINE,
    },
    "stone": {
        "body": ["#8c8c89", "#7e7e7b", "#959592"],
        "top": "#a9a9a6",
        "low": "#5f5f5c",
        "edge": "#b8b8b4",
        "fleck": ["#6a6a67", "#a3a3a0"],
        "grip": TWINE,
    },
    "iron": {
        "body": ["#cdcdcd", "#c0c0c0"],
        "top": "#e6e6e6",
        "low": "#8a8a8c",
        "edge": "#ffffff",
        "bevel": "#efefef",  # the polished strip behind the edge
        "grip": LEATHER,
    },
    "diamond": {
        "body": ["#44d8c8", "#37c6b6"],
        "top": "#aafff3",
        "low": "#1c8a80",
        "edge": "#e2fffb",
        "facet": "#8af5e8",
        "grip": LEATHER,
    },
}

# the head: a broad block capping the handle top, a short nub behind the handle, the blade out to x = -6 with rounded
# corners; columns as (bottom, top)
HEAD = {1: (12, 15), 0: (12, 15), -1: (12, 15), -2: (10, 15), -3: (9, 15), -4: (8, 15), -5: (8, 15), -6: (9, 14)}
EDGE_X = -6
HANDLE_TOP = 11


# ---------------------------------------------------------------- the shape
def shape(mat):
    pal = MATERIALS[mat]
    rng = random.Random(2610)
    vox = {}

    def put(x, y, z, col):
        vox[(x, y, z)] = col

    # the handle: 2×2 px, z -1..11, its top inside the head
    grip, grip_dark = pal["grip"]
    for z in range(-1, HANDLE_TOP + 1):
        for x in (-1, 0):
            for y in (-1, 0):
                if z == -1:
                    col = OAK_DARK  # the butt
                elif z in (1, 2, 4, 5):
                    col = grip_dark if z in (1, 4) else grip[(x + y) % 2]
                elif x == -1 and y == 0 and z % 3 != 0:
                    col = OAK_DARK
                else:
                    col = OAK[(z * 7 + x * 3 + y) % 3]
                put(x, y, z, col)

    # the head: a light cutting edge, a lighter strip behind it, a light top, a dark underside and back
    body = pal["body"]
    for x, (z0, z1) in HEAD.items():
        for z in range(z0, z1 + 1):
            for y in (-1, 0):
                if x == EDGE_X:
                    col = pal["edge"]
                elif z == z1:
                    col = pal["top"]
                elif z == z0 or x == 1:
                    col = pal["low"]
                elif x == EDGE_X + 1:
                    col = pal.get("bevel", pal["top"])
                else:
                    col = body[(x + y + z) % len(body)]
                put(x, y, z, col)
    if mat == "wood":
        for z in range(10, 15):
            for y in (-1, 0):
                put(-3, y, z, pal["low"])  # a plank seam across the head
    if mat == "diamond":
        for x, z in ((-1, 14), (-2, 13), (-3, 12), (-4, 11), (-2, 11), (-3, 10)):
            for y in (-1, 0):
                put(x, y, z, pal["facet"])  # facet lines
    if mat == "stone":
        for key, col in list(vox.items()):
            if col in body and rng.random() < 0.3:
                vox[key] = pal["fleck"][rng.randrange(2)]
        for q in ((-6, -1, 10), (-6, 0, 13), (-5, -1, 8)):
            vox.pop(q, None)  # chips in the edge
    return vox


ICON = ((0, math.radians(45), 0), (0, -30, 0), 6.2, 60)  # flat front, the head to the upper left like an item sprite
HERO = ((math.radians(10), math.radians(35), math.radians(-30)), (-3.2, -7.5, 2.2), None, 50)
run(HERE, "axe", MATERIALS, shape, ICON, HERO, glint_phase=4.2)  # the stills catch a band on the head
