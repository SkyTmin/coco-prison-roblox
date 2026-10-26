# Our shovels [владелец 26.10: «теперь к лопате»] — voxel models in the same style as the pickaxes, swords and axes
# (assets/models/wooden_pickaxe, sword, axe): one voxel = 0.25 studs, the shovel ≈ 5.25 studs long. The Minecraft
# silhouette (a long handle, a rounded spade blade in line with it) with our own colours and details, not a copy of the
# sprite. One shape for every material (the game's tiers: wood, stone, iron, diamond — tools.json toolDamage.shovel):
# a light rim round the blade, a dark socket over the handle end, a plank seam on wood, chipped speckled stone, a polished
# inner rim and a leather grip on iron, facets on diamond.
# Pipeline and the enchant glint: assets/models/voxeltool.py.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/shovel/shovel.py
#   [-- frames <dir>]
# → render-<material>-{icon,hero,icon-glint,hero-glint}.png and shovel.blend (diamond) next to this file;
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
        "rim": "#c99a5e",
        "low": "#7c5a34",
        "grip": TWINE,
    },
    "stone": {
        "body": ["#8c8c89", "#7e7e7b", "#959592"],
        "rim": "#acaca8",
        "low": "#5f5f5c",
        "fleck": ["#6a6a67", "#a3a3a0"],
        "grip": TWINE,
    },
    "iron": {
        "body": ["#c4c4c4", "#b8b8b8"],
        "rim": "#f4f4f4",
        "low": "#86868a",
        "bevel": "#dedede",  # the polished strip inside the rim
        "grip": LEATHER,
    },
    "diamond": {
        "body": ["#3fd2c2", "#34c0b0"],
        "rim": "#b4fff5",
        "low": "#1c8a80",
        "facet": "#8af5e8",
        "grip": LEATHER,
    },
}

# the blade, rows up the handle: z -> (x0, x1); a narrower shoulder, a long 6-px spade, a rounded tip
BLADE = {11: (-2, 1), 12: (-3, 2), 13: (-3, 2), 14: (-3, 2), 15: (-3, 2), 16: (-3, 2), 17: (-3, 2), 18: (-2, 1), 19: (-1, 0)}
HANDLE_TOP = 10


# ---------------------------------------------------------------- the shape
def shape(mat):
    pal = MATERIALS[mat]
    rng = random.Random(2610)
    vox = {}

    def put(x, y, z, col):
        vox[(x, y, z)] = col

    # the handle: 2×2 px, z -1..10
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

    # the blade: a light rim on the outline, a dark shoulder and socket where the handle goes in, the body between
    body = pal["body"]
    for z, (x0, x1) in BLADE.items():
        for x in range(x0, x1 + 1):
            for y in (-1, 0):
                up = BLADE.get(z + 1)
                outline = x in (x0, x1) or up is None or not (up[0] <= x <= up[1])
                if outline and z > 11:
                    col = pal["rim"]
                elif z == 11:
                    col = pal["low"]  # the shoulder where the handle goes in
                elif x in (-1, 0) and z == 12:
                    col = pal["low"]  # the socket over the handle end
                elif "bevel" in pal:
                    col = pal["bevel"] if z in (13, 17) or x in (x0 + 1, x1 - 1) else body[0]
                else:
                    col = body[(x + y + z) % len(body)]
                put(x, y, z, col)
    if mat == "wood":
        for z in range(13, 17):
            for y in (-1, 0):
                put(-1 if z % 2 else 0, y, z, pal["low"])  # a zigzag seam between two planks
    if mat == "diamond":
        for x, z in ((-2, 14), (-1, 15), (0, 16), (1, 14), (-2, 17)):
            for y in (-1, 0):
                put(x, y, z, pal["facet"])  # facet lines
    if mat == "stone":
        for key, col in list(vox.items()):
            if col in body and rng.random() < 0.3:
                vox[key] = pal["fleck"][rng.randrange(2)]
        for q in ((-3, -1, 15), (2, 0, 13), (-1, -1, 19)):
            vox.pop(q, None)  # chips in the rim
    return vox


ICON = ((0, math.radians(45), 0), (0, -30, 0), 6.2, 60)  # flat front, the blade to the upper right like an item sprite
HERO = ((math.radians(10), math.radians(35), math.radians(-30)), (-3.2, -7.5, 2.2), None, 50)
run(HERE, "shovel", MATERIALS, shape, ICON, HERO)
