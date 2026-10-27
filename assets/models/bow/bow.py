# Our bow and arrow [владелец 26.10: «теперь лук и потом стрелы»] — voxel models in the style of the pickaxes, swords,
# axes and shovels (assets/models/voxeltool.py), drawn as a 16×16 item on the diagonal like a Minecraft item sprite (our
# own pixels, not a copy): the limb arcs to the upper left with dark outer and light inner wood and a wrapped grip
# that stands out of the plane, the string runs down the diagonal; the drawn stages pull the string to the lower right
# with an arrow on it (flint head, white fletching). Stages like Minecraft's pulling textures: pull0 from the start of
# the draw, pull1 from 0.65 of the full draw, pull2 from 0.9 (src/client/HeldItem.luau). The arrow item points to the
# upper right.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/bow/bow.py [-- frames <dir>]
#   → render-<state>-{icon,hero,icon-glint,hero-glint}.png, bow.blend;
# "… -P assets/models/bow/bow.py -- export" → assets/icons/models3d.json (bow, bow_pulling_0..2, arrow; the game's
#   held models, ItemModels.luau) — then node scripts/build-configs.mjs.
import json
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from voxeltool import export_boxes, run  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))

# ---------------------------------------------------------------- palette
LIMB_OUT = "#5e3b1e"  # the outer (back) side of the limb
LIMB = ["#8a5a2e", "#7e5229"]
LIMB_IN = "#b07a42"  # the inner side, towards the string
TIP = "#c99a5e"
GRIP = ["#cdb68a", "#4e3220"]  # twine and leather wraps in bands
GRIP_HI = "#2e1c0e"  # the dark ends of the grip
STRING = ["#ececec", "#cfcfcf"]
SHAFT = ["#a8814f", "#94703f"]
HEAD = ["#5c5f66", "#7a7e86"]  # flint-grey head
HEAD_HI = "#c4c8d0"
FLETCH = ["#f2f2f2", "#d4d4d4"]
FLETCH_LO = "#a9a9a9"

N = 16  # the item grid
# the limb: a circular arc round CENTRE from the upper-right tip to the lower-left tip, bulging to the upper left
TOP, BOTTOM = (14, 1), (1, 14)  # the limb tips = the string ends (sprite x, y; y down)
CENTRE = (11.0, 11.0)
RADIUS = math.hypot(TOP[0] - CENTRE[0], TOP[1] - CENTRE[1])
A0 = math.atan2(TOP[1] - CENTRE[1], TOP[0] - CENTRE[0])
A1 = math.atan2(BOTTOM[1] - CENTRE[1], BOTTOM[0] - CENTRE[0]) - 2 * math.pi  # the long way round, via the upper left
REST_NOCK = (8, 8)
PULL = {"bow": 0, "pull0": 1, "pull1": 2, "pull2": 3}  # px the nock moves to the lower right
ARROW_LEN = 10


def arc(t, r=RADIUS):
    a = A0 + (A1 - A0) * t
    return (CENTRE[0] + r * math.cos(a), CENTRE[1] + r * math.sin(a))


def line(p, q):
    """Pixels of a 1-px line from p to q (sprite coordinates)."""
    (x0, y0), (x1, y1) = p, q
    steps = max(abs(x1 - x0), abs(y1 - y0), 1)
    return [(round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps)) for i in range(steps + 1)]


def sprite(state):
    """{(x, y): (hex, depth)} on the 16×16 grid, y down; depth 1 = one voxel thick, 3 = the grip."""
    px = {}
    if state == "arrow":
        # the arrow item, tail at the lower left, head at the upper right [владелец 27.10: «иконки стрелы и лука
        # сделать надо»]: a two-pixel staircase shaft (light top edge, dark lower edge) so it reads as one line in a
        # slot, a filled triangular flint head in the corner and white feathers on both sides of the tail
        for i, (x, y) in enumerate(line((2, 13), (11, 4))):
            px[(x, y)] = (SHAFT[0], 1)
            px[(x + 1, y)] = (SHAFT[1] if i % 2 else "#7a5a32", 1)
        for x, y in ((11, 1), (12, 1), (13, 1), (14, 1), (12, 2), (13, 2), (14, 2), (13, 3), (14, 3), (14, 4)):
            edge = x == 14 or y == 1
            px[(x, y)] = (HEAD_HI if (x, y) in ((14, 1), (13, 1), (14, 2)) else HEAD[0] if edge else HEAD[1], 1)
        px[(12, 3)] = (HEAD[0], 1)  # where the head is bound to the shaft
        for i, (x, y) in enumerate(((1, 12), (2, 11), (3, 10), (3, 14), (4, 13), (5, 12))):
            px[(x, y)] = (FLETCH[i % 2] if i % 3 < 2 else FLETCH_LO, 1)
        px[(1, 13)] = ("#4a3420", 1)  # the nock
        return px
    pull = PULL[state]
    nock = (REST_NOCK[0] + pull, REST_NOCK[1] + pull)
    # the string (drawn first so the limb and the arrow cover its ends)
    for i, p in enumerate(line(TOP, nock) + line(nock, BOTTOM)):
        px[p] = (STRING[i % 2], 1)
    # the limb: two px thick in the middle (dark outer wood behind light inner wood), one px towards the pale tips
    for i in range(401):
        t = i / 400
        mid = abs(t - 0.5)
        if mid < 0.3:
            x, y = arc(t, RADIUS + 0.9)
            out = (round(x), round(y))
            if out not in px:
                px[out] = (LIMB_OUT, 1)
        x, y = arc(t)
        p = (round(x), round(y))
        px[p] = (TIP if mid > 0.44 else LIMB_IN if mid > 0.3 else LIMB[(p[0] + p[1]) % 2], 1)
    # the grip in the middle: leather wraps standing out of the plane
    for i in range(170, 231):
        for r in (RADIUS, RADIUS + 0.9):
            x, y = arc(i / 400, r)
            p = (round(x), round(y))
            px[p] = (GRIP_HI if i < 176 or i > 224 else GRIP[(i // 10) % 2], 3)
    if pull:
        # the arrow on the string, pointing to the upper left
        for i in range(ARROW_LEN + 1):
            p = (nock[0] - i, nock[1] - i)
            if i < 2:
                col = FLETCH[i % 2]
            elif i >= ARROW_LEN - 1:
                col = HEAD_HI if i == ARROW_LEN else HEAD[0]
            else:
                col = SHAFT[i % 2]
            px[p] = (col, 1)
        hx, hy = nock[0] - ARROW_LEN, nock[1] - ARROW_LEN
        px[(hx + 1, hy)] = (HEAD[1], 1)
        px[(hx, hy + 1)] = (HEAD[1], 1)
        px[(nock[0] + 1, nock[1] - 1)] = (FLETCH_LO, 1)
        px[(nock[0] - 1, nock[1] + 1)] = (FLETCH_LO, 1)
    return {p: v for p, v in px.items() if 0 <= p[0] < N and 0 <= p[1] < N}


def shape(state):
    """Blender voxels: x = sprite x, z = up (15 − sprite y), y = depth (the grip is three voxels thick)."""
    vox = {}
    for (x, y), (col, depth) in sprite(state).items():
        for d in range(-(depth // 2), depth // 2 + 1):
            vox[(x, d, N - 1 - y)] = col
    return vox


STATES = {"bow": None, "pull0": None, "pull1": None, "pull2": None, "arrow": None}
GAME_IDS = {"bow": "bow", "pull0": "bow_pulling_0", "pull1": "bow_pulling_1", "pull2": "bow_pulling_2", "arrow": "arrow"}

if sys.argv[-1] == "export":
    path = os.path.join(ROOT, "assets", "icons", "models3d.json")
    data = {"source": "", "items": {}}
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
    data["source"] = (
        "assets/models/*/<item>.py -- export (voxeltool.export_boxes): 3D voxel item models. size = [x, y, z] in "
        "voxels (x = image right, z = image up, y = depth); p = palette (hex); b = flat [x, y, z, w, d, h, paletteIndex, …] "
        "boxes from the minimum corner"
    )
    for state, game_id in GAME_IDS.items():
        data["items"][game_id] = export_boxes(shape(state), N)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("exported", ", ".join(GAME_IDS.values()), "→", path)
else:
    ICON = ((0, 0, 0), (0, -30, 0), 5.0, 60)  # flat front, like the inventory sprite
    HERO = ((math.radians(10), math.radians(-25), math.radians(28)), (2.6, -6.6, 1.8), None, 50)
    run(HERE, "bow", STATES, shape, ICON, HERO)
