# Our swords [владелец 26.10: «теперь меч давай также»] — voxel models in the same style as the pickaxes
# (assets/models/wooden_pickaxe/pickaxe.py): one voxel = 0.25 studs, the sword ≈ 6.5 studs from pommel to tip, not a
# copy of any Minecraft sprite. One shape for every material (the game's tiers: wood, stone, iron, diamond —
# tools.json swordDamage): a knob pommel, a wrapped grip, a crossguard with upturned tips, a thin 2-px blade with a
# light edge, a dark fuller by the guard and a slanted point. Each material has its own details: plank seams on wood,
# chipped speckled stone, polished iron with a riveted dark-iron guard and a leather grip, faceted diamond with a gold
# guard and a gem.
# Pipeline and the enchant glint: assets/models/voxeltool.py.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/sword/sword.py
#   [-- frames <dir>]
# → render-<material>-{icon,hero,icon-glint,hero-glint}.png and sword.blend (diamond) next to this file;
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
OAK_GUARD = (["#7a5532", "#6c4a2b"], OAK_DARK)
IRON_GUARD = (["#5a5b61", "#515258"], "#3f4045")
GOLD_GUARD = (["#e8b830", "#d6a624"], "#a87a14")

MATERIALS = {
    "wood": {
        "body": ["#a27846", "#966c3d"],
        "edge": "#bd9058",
        "fuller": "#7c5a34",
        "tip": "#d6b07a",
        "grip": TWINE,
        "guard": OAK_GUARD,
    },
    "stone": {
        "body": ["#8c8c89", "#7e7e7b", "#959592"],
        "edge": "#a9a9a6",
        "fuller": "#5f5f5c",
        "tip": "#b8b8b4",
        "fleck": ["#6a6a67", "#a3a3a0"],
        "grip": TWINE,
        "guard": OAK_GUARD,
    },
    "iron": {
        "body": ["#cdcdcd", "#c0c0c0"],
        "edge": "#f2f2f2",
        "fuller": "#8a8a8c",
        "tip": "#ffffff",
        "grip": LEATHER,
        "guard": IRON_GUARD,
        "jewel": "#b4b4bc",  # a rivet in the middle of the guard
    },
    "diamond": {
        "body": ["#44d8c8", "#37c6b6"],
        "edge": "#aafff3",
        "fuller": "#1c8a80",
        "tip": "#e2fffb",
        "facet": "#8af5e8",
        "grip": LEATHER,
        "guard": GOLD_GUARD,
        "jewel": "#5ff0e0",  # a diamond set in the gold guard
    },
}

BLADE_Z = (7, 22)  # the blade from the guard to the point [владелец 26.10: «сделай его тоньше и чуть длиннее»]
FULLER_Z = (8, 10)


# ---------------------------------------------------------------- the shape
def shape(mat):
    pal = MATERIALS[mat]
    rng = random.Random(2610)
    vox = {}

    def put(x, y, z, col):
        vox[(x, y, z)] = col

    guard, guard_dark = pal["guard"]
    # the pommel: a cap and a cross-shaped knob below the grip
    for x in (-1, 0):
        for y in (-1, 0):
            put(x, y, -3, guard_dark)
    for x in range(-2, 2):
        for y in range(-2, 2):
            if (x in (-2, 1)) and (y in (-2, 1)):
                continue  # rounded corners
            put(x, y, -2, guard[0] if (x, y) != (-2, 0) else guard_dark)
    # the grip: 2×2 px, z -1..4, wraps with darker lower edges
    grip, grip_dark = pal["grip"]
    for z in range(-1, 5):
        for x in (-1, 0):
            for y in (-1, 0):
                put(x, y, z, grip_dark if z in (0, 3) else grip[(x + y + z) % 2])
    # the crossguard: an 8-px bar with upturned tips round a 4×4 block
    for z in (5, 6):
        for x in range(-4, 4):
            for y in ((-2, -1, 0, 1) if -2 <= x <= 1 else (-1, 0)):
                put(x, y, z, guard[0] if z == 6 else guard[1])
    for x in (-4, 3):
        for y in (-1, 0):
            put(x, y, 7, guard_dark)
    if "jewel" in pal:
        for y in (-2, 1):
            for x in (-1, 0):
                put(x, y, 5 + (x + 1), pal["jewel"])  # set diagonally in the front and back faces
    # the blade: 2 px wide, the lit edge on one column, the body on the other, a dark fuller by the guard and a
    # slanted point
    body = pal["body"]
    z0, z1 = BLADE_Z
    for z in range(z0, z1 + 1):
        for x in ((-1,) if z == z1 else (-1, 0)):
            for y in (-1, 0):
                if z >= z1 - 1:
                    col = pal["tip"]
                elif x == -1:
                    col = pal["edge"]
                elif FULLER_Z[0] <= z <= FULLER_Z[1]:
                    col = pal["fuller"]
                else:
                    col = body[(y + z) % len(body)]
                put(x, y, z, col)
    if mat == "wood":
        for z in (13, 18):
            for y in (-1, 0):
                put(0, y, z, pal["fuller"])  # plank seams
    if mat == "diamond":
        for z, x in ((12, 0), (16, 0), (19, 0)):
            for y in (-1, 0):
                put(x, y, z, pal["facet"])  # slanted facet lines
    if mat == "stone":
        for key, col in list(vox.items()):
            if col in body and rng.random() < 0.3:
                vox[key] = pal["fleck"][rng.randrange(2)]
        for p in ((-1, -1, 11), (0, 0, 15), (-1, 0, 18)):
            vox.pop(p, None)  # chips in the edges
    return vox


ICON = ((0, math.radians(45), 0), (0, -30, 0), 7.0, 60)  # flat front, the point to the upper right like an item sprite
HERO = ((math.radians(10), math.radians(35), math.radians(-30)), (-3.4, -8.8, 2.3), None, 50)
run(HERE, "sword", MATERIALS, shape, ICON, HERO)
