# Booster bottles [владелец 27.10: «чекни какие бустеры есть, давай через блендер создадим модели для них»] — the
# nine boosters of the original (DONATE-SHOP-BOOSTERS.md: blocks / money / mobs × local / faction / global), as our own
# 3D voxel flask in the pipeline of the tools (assets/models/voxeltool.py): a round flask of the kind's liquid (blocks
# blue, money green, mobs red) with a glass top, a cork, a glyph on the front (a grass block, «$», a mob skull) and a band
# round the neck in the scope's colour — blue local, orange faction, red global, the frame colours of the original shop.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/booster/booster.py
#   → render-<kind>_<scope>-{icon,hero,...}.png, booster.blend;
# "… -- icons <dir>" → <dir>/booster_<kind>_<scope>.png (the UI pictures, uploaded → assets/icons/ids.json);
# "… -- export" → booster_<kind>_<scope> in assets/icons/models3d.json (the spinning model in the storage window).
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from voxeltool import run  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))

LIQUID = {
    "blocks": ("#3f7fdc", "#2a55a0", "#7fb4ff"),
    "money": ("#3fae45", "#2a7a30", "#8be08f"),
    "mobs": ("#d04040", "#962828", "#ff8a8a"),
}
BAND = {"local": "#4fb6ff", "faction": "#ff9a2a", "global": "#ff3b3b"}
GLASS = ("#d6ecf7", "#b9d6e6")
SHINE = "#ffffff"
CORK = ("#8a5a2c", "#6e4520")

# 5 × 7 front glyphs, row 0 = top; Y yellow, G grass, D dirt, K dark, W blade
GLYPH = {
    "money": [
        "..Y..",
        ".YYYY",
        "YY...",
        ".YYY.",
        "...YY",
        "YYYY.",
        "..Y..",
    ],
    "blocks": [
        "GGGGG",
        "GGGGG",
        "DGDDG",
        "DDDDD",
        "DDKDD",
        "DKDDD",
        "DDDDD",
    ],
    "mobs": [
        ".WWW.",
        "WWWWW",
        "WKWKW",
        "WWWWW",
        ".WKW.",
        ".WWW.",
        ".....",
    ],
}
GLYPH_COL = {"Y": "#ffe46a", "G": "#6fc23a", "D": "#8a5a2c", "K": "#3a2410", "W": "#eef0f8"}

R = 5.3  # flask radius in voxels
CZ = 5.0  # flask centre height
FILL = 7  # liquid below this z, glass above
STATES = {"%s_%s" % (k, s): (k, s) for k in LIQUID for s in BAND}


def shape(state):
    kind, scope = STATES[state]
    liquid, deep, light = LIQUID[kind]
    vox = {}
    # the flask: a sphere with a flat foot
    for x in range(-6, 6):
        for y in range(-6, 6):
            for z in range(0, 11):
                d = math.sqrt((x + 0.5) ** 2 + (y + 0.5) ** 2 + (z + 0.5 - CZ) ** 2)
                if d > R:
                    continue
                if z >= FILL:
                    col = GLASS[(x + y + z) % 2]
                else:
                    col = liquid if (x + y + z) % 3 else deep
                    if z == FILL - 1:
                        col = light  # the liquid's surface line
                vox[(x, y, z)] = col
    # a shine streak on the upper left of the front
    for x, z in ((-4, 7), (-4, 6), (-3, 8), (-4, 5)):
        for y in range(-6, 6):
            if (x, y, z) in vox:
                vox[(x, y, z)] = SHINE
                break
    # the neck, its band and the rim
    for x in range(-2, 2):
        for y in range(-2, 2):
            for z in range(10, 13):
                vox[(x, y, z)] = GLASS[(x + y + z) % 2]
            vox[(x, y, 10)] = BAND[scope]
    for x in range(-3, 3):
        for y in range(-3, 3):
            if abs(x + 0.5) + abs(y + 0.5) <= 4:
                vox[(x, y, 12)] = BAND[scope] if (x + y) % 2 else GLASS[0]
    # the cork
    for x in range(-1, 1):
        for y in range(-1, 1):
            for z in range(13, 15):
                vox[(x, y, z)] = CORK[(x + y + z) % 2]
    # the glyph on the front surface (the camera looks along +y): the first voxel of each column from −y
    rows = GLYPH[kind]
    for r, row in enumerate(rows):
        z = 7 - r
        for c, ch in enumerate(row):
            if ch == ".":
                continue
            x = c - 3
            for y in range(-6, 6):
                if (x, y, z) in vox:
                    vox[(x, y, z)] = GLYPH_COL[ch]
                    break
    return vox


ICON = ((0, 0, math.radians(12)), (0, -30, 1.6), 5.2, 60)  # nearly front, a little turned to show it is round
HERO = ((math.radians(8), 0, math.radians(20)), (2.2, -7.0, 3.2), None, 50)
run(HERE, "booster", STATES, shape, ICON, HERO)
