# Our shears [владелец 26.10: «теперь к ножницам»; «сделай похожим как в Майне»] — a voxel model in the style of the
# pickaxes, swords, axes, shovels and the bow (assets/models/voxeltool.py), a 16×16 item on the diagonal. The Minecraft
# silhouette — sheep shears, not scissors: two arms in a narrow V joined by a round spring loop at the lower left, each
# arm a brown handle near the loop and a grey blade to the upper right — drawn with our own pixels and colours (the
# arms are rasterised from two segments here, nothing is copied from the Minecraft texture). Shears have no material
# tiers (SHEARS-UPGRADES.md: levels 1–6 only add Efficiency): one model, shown plain and with the enchant glint.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/shears/shears.py [-- frames <dir>]
#   → render-shears-{icon,hero,icon-glint,hero-glint}.png, shears.blend;
# "… -- ascii" prints the sprite; "… -- export" → the "shears" entry of assets/icons/models3d.json (the held model,
#   ItemModels.luau) — then node scripts/build-configs.mjs.
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from voxeltool import export_boxes, run  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))

# ---------------------------------------------------------------- palette
EDGE = "#eef0f2"  # the cutting edge (the side facing the other blade)
BLADE = ["#c9ccd1", "#bfc2c8"]
SPINE = "#8d9199"  # the back of the blade
HANDLE = ["#7c4a2c", "#70422a"]  # oiled wood
HANDLE_HI = "#9a6038"
HANDLE_LO = "#4f2c1a"
SPRING = ["#9a9ea6", "#7d828a"]
SPRING_LO = "#5a5e66"

N = 16
LOOP = (3, 12)  # the spring loop's hole (sprite x, y; y down)
# the two arms from the loop to the blade tips: the upper-left arm and the right arm, a narrow V
ARMS = (((3.6, 9.6), (11.6, 1.6)), ((6.2, 12.2), (14.0, 4.4)))
BLADE_FROM = 0.45  # of the arm's length: handle before, blade after


def seg(p, a, b):
    """(distance from p to segment ab, parameter t 0..1, side: + on the left of a→b in sprite space)"""
    ax, ay = a
    bx, by = b
    dx, dy = bx - ax, by - ay
    t = max(0.0, min(1.0, ((p[0] - ax) * dx + (p[1] - ay) * dy) / (dx * dx + dy * dy)))
    cx, cy = ax + dx * t, ay + dy * t
    side = dx * (p[1] - ay) - dy * (p[0] - ax)
    return math.hypot(p[0] - cx, p[1] - cy), t, side


def sprite():
    """{(x, y): hex} on the 16×16 grid, y down."""
    px = {}
    for y in range(N):
        for x in range(N):
            p = (x + 0.5, y + 0.5)
            best = None
            for i, (a, b) in enumerate(ARMS):
                d, t, side = seg(p, a, b)
                half = 1.3 if t < BLADE_FROM else 1.35 - 0.55 * (t - BLADE_FROM) / (1 - BLADE_FROM)
                if d <= half and (best is None or d < best[0]):
                    # the side facing the other arm: the upper-left arm faces right (side < 0 in y-down space)
                    inner = (side > 0) if i == 0 else (side < 0)
                    best = (d, t, inner, i)
            if not best:
                continue
            d, t, inner, i = best
            if t < BLADE_FROM:
                col = HANDLE_HI if (not inner and d > 0.8) else HANDLE_LO if (inner and d > 0.95) else HANDLE[(x + y) % 2]
            else:
                col = EDGE if (inner and d > 0.3) else SPINE if (not inner and d > 0.3) else BLADE[(x + y) % 2]
            px[(x, y)] = col
    # between the two handles a dark seam instead of holes (the handles press together); the gap stays open between
    # the blades
    for y in range(N):
        for x in range(N):
            if (x, y) in px:
                continue
            p = (x + 0.5, y + 0.5)
            (da, ta, _), (db, tb, _) = seg(p, *ARMS[0]), seg(p, *ARMS[1])
            if da < 2.0 and db < 2.0 and ta < BLADE_FROM and tb < BLADE_FROM:
                px[(x, y)] = HANDLE_LO
    # the spring loop: a closed 3×3 ring round LOOP (the hole), joined to the handles at its upper right
    hx, hy = LOOP
    for x in range(hx - 1, hx + 2):
        for y in range(hy - 1, hy + 2):
            if (x, y) != (hx, hy):
                px[(x, y)] = SPRING_LO if (x - hx) + (y - hy) >= 1 else SPRING[(x + y) % 2]
    return px


def shape(_state):
    """Blender voxels: x = sprite x, z = up (15 − sprite y), y = depth (two voxels like the other tools)."""
    return {(x, d, N - 1 - y): col for (x, y), col in sprite().items() for d in (-1, 0)}


STATES = {"shears": None}

if sys.argv[-1] == "ascii":
    sp = sprite()
    key = {EDGE: "E", SPINE: "S", HANDLE_HI: "h", HANDLE_LO: "l", SPRING_LO: "s"}
    for y in range(N):
        print("".join(key.get(sp.get((x, y)), "B" if sp.get((x, y)) in BLADE else "H" if sp.get((x, y)) in HANDLE else "o" if sp.get((x, y)) in SPRING else ".") for x in range(N)))
elif sys.argv[-1] == "export":
    path = os.path.join(ROOT, "assets", "icons", "models3d.json")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    data["items"]["shears"] = export_boxes(shape("shears"), N)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("exported shears →", path)
else:
    ICON = ((0, 0, 0), (0, -30, 0), 5.0, 60)  # flat front, like the inventory sprite
    HERO = ((math.radians(10), math.radians(-25), math.radians(28)), (2.6, -6.6, 1.8), None, 50)
    run(HERE, "shears", STATES, shape, ICON, HERO, glint_phase=3.0)
