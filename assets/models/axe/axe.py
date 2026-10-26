# Our axes [владелец 26.10: «топор теперь»] — voxel models in the same style as the pickaxes and swords
# (assets/models/wooden_pickaxe/pickaxe.py, assets/models/sword/sword.py): one voxel = 0.25 studs, the axe ≈ 4 studs
# long, not a copy of any Minecraft sprite. One shape for every material (the game's tiers: wood, stone, iron, diamond —
# tools.json toolDamage.axe): an oak handle with grain and a grip, a collar round the eye, a bearded blade on one side
# widening to a light cutting edge, a short poll on the other. Each material has its own details: plank seams on wood,
# chipped speckled stone, a polished bevel and a riveted iron collar with a leather grip on iron, facets and a riveted
# gold collar on diamond.
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
        "collar": TWINE,
    },
    "stone": {
        "body": ["#8c8c89", "#7e7e7b", "#959592"],
        "top": "#a9a9a6",
        "low": "#5f5f5c",
        "edge": "#b8b8b4",
        "fleck": ["#6a6a67", "#a3a3a0"],
        "grip": TWINE,
        "collar": TWINE,
    },
    "iron": {
        "body": ["#cdcdcd", "#c0c0c0"],
        "top": "#e6e6e6",
        "low": "#8a8a8c",
        "edge": "#ffffff",
        "bevel": "#efefef",  # the polished strip behind the edge
        "grip": LEATHER,
        "collar": (["#5a5b61", "#515258"], "#3f4045"),
        "rivet": "#b4b4bc",
    },
    "diamond": {
        "body": ["#44d8c8", "#37c6b6"],
        "top": "#aafff3",
        "low": "#1c8a80",
        "edge": "#e2fffb",
        "facet": "#8af5e8",
        "grip": LEATHER,
        "collar": (["#e8b830", "#d6a624"], "#a87a14"),
        "rivet": "#fff27a",
    },
}

# the blade: columns out from the collar (x = -3 … -8) as (bottom, top) — a narrow neck widening to a bearded edge
BLADE = {-3: (11, 13), -4: (10, 13), -5: (9, 14), -6: (8, 14), -7: (7, 15), -8: (6, 16)}
EDGE_X = -8


# ---------------------------------------------------------------- the shape
def shape(mat):
    pal = MATERIALS[mat]
    rng = random.Random(2610)
    vox = {}

    def put(x, y, z, col):
        vox[(x, y, z)] = col

    # the handle: 2×2 px, z -1..14
    grip, grip_dark = pal["grip"]
    for z in range(-1, 15):
        for x in (-1, 0):
            for y in (-1, 0):
                if z in (-1, 14):
                    col = OAK_DARK  # the butt and the end showing above the collar
                elif z in (1, 2, 4, 5):
                    col = grip_dark if z in (1, 4) else grip[(x + y) % 2]
                elif x == -1 and y == 0 and z % 3 != 0:
                    col = OAK_DARK
                else:
                    col = OAK[(z * 7 + x * 3 + y) % 3]
                put(x, y, z, col)

    # the blade
    body = pal["body"]
    for x, (z0, z1) in BLADE.items():
        for z in range(z0, z1 + 1):
            for y in (-1, 0):
                if x == EDGE_X:
                    col = pal["edge"]
                elif z == z1:
                    col = pal["top"]
                elif z == z0:
                    col = pal["low"]
                else:
                    col = body[(x + y + z) % len(body)]
                put(x, y, z, col)
    # the poll: a short block behind the collar
    for z in (11, 12, 13):
        for y in (-1, 0):
            put(2, y, z, pal["top"] if z == 13 else pal["low"])
    if mat == "wood":
        for z in range(10, 14):
            for y in (-1, 0):
                put(-5, y, z, pal["low"])  # a plank seam across the blade
    if mat == "iron":
        z0, z1 = BLADE[EDGE_X + 1]
        for z in range(z0 + 1, z1):
            for y in (-1, 0):
                put(EDGE_X + 1, y, z, pal["bevel"])
    if mat == "diamond":
        for x, z in ((-4, 12), (-5, 11), (-6, 10), (-6, 13), (-7, 12)):
            for y in (-1, 0):
                put(x, y, z, pal["facet"])  # facet lines
    if mat == "stone":
        for key, col in list(vox.items()):
            if col in body and rng.random() < 0.3:
                vox[key] = pal["fleck"][rng.randrange(2)]
        for p in ((-8, -1, 9), (-8, 0, 14), (-7, -1, 7)):
            vox.pop(p, None)  # chips in the edge

    # the collar round the eye: z 11..13, x -2..1, y -2..1 round the handle
    collar, collar_dark = pal["collar"]
    for z in range(11, 14):
        for x in range(-2, 2):
            for y in range(-2, 2):
                if x in (-1, 0) and y in (-1, 0):
                    continue
                put(x, y, z, collar_dark if z == 11 else collar[(x + y + z) % 2])
    if "rivet" in pal:
        for p in ((-1, -2, 12), (0, 1, 12), (1, -1, 12), (-2, 0, 12)):
            put(*p, pal["rivet"])
    return vox


ICON = ((0, math.radians(45), 0), (0, -30, 0), 6.2, 60)  # flat front, the head to the upper left like an item sprite
HERO = ((math.radians(10), math.radians(35), math.radians(-30)), (-3.2, -7.5, 2.2), None, 50)
run(HERE, "axe", MATERIALS, shape, ICON, HERO, glint_phase=4.2)  # the stills catch a band on the blade
