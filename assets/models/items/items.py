# Every item and menu picture as a Blender voxel model [владелец 27.10: «давай иконки меню сделаем через блендер …
# вообще через блендер надо все предметы сделать»]: our own pixel sprites (scripts/sprite-grids.mjs →
# grids.json, one colour per cell) become voxels, one per pixel, a few voxels deep, lit like the tools
# (assets/models/voxeltool.py) and turned a little so the thickness shows — a Minecraft item dropped on the ground,
# not a flat sticker. Menu pictures turn further and are twice as deep.
# Run:
#   "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/items/items.py -- icons <dir> [ids]
#     → <dir>/<id>.png (512 px, transparent) for upload (assets/icons/ids.json);
#   … -- export [ids] → assets/icons/models3d.json (the held models, ItemModels.luau) — then node scripts/build-configs.mjs;
#   … -- preview [ids] → render-<id>.png here on a grey background.
import json
import math
import os
import sys

import bpy
from mathutils import Euler, Vector

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from voxeltool import build, export_boxes, look, set_glint, setup  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))

with open(os.path.join(HERE, "grids.json"), encoding="utf-8") as f:
    GRIDS = json.load(f)

# straight on [владелец 27.10: «предметы как будто наклонены, так себе»]; the depth shows through the perspective camera:
# the sides of the bulge peek out round the edges, like an item held up in front of the eyes
ITEM_TURN = (0, 0, 0)
MENU_TURN = (0, 0, 0)
LENS = 40  # mm (36 mm sensor)


def depth_of(grid, menu):
    """Voxels deep: about 1/16 of the picture (2/16 for the menu), at least one."""
    base = max(1, round(max(grid["w"], grid["h"]) / 16))
    return base * 2 if menu else base


BOW_STATES = {"bow": "bow", "arrow": "arrow"}  # drawn by assets/models/bow/bow.py (its held models too)


def bow_voxels(state):
    """The bow file's own voxels (its code up to the run part), so the icon is the model in the hand."""
    path = os.path.join(os.path.dirname(HERE), "bow", "bow.py")
    with open(path, encoding="utf-8") as f:
        src = f.read().split("\nSTATES = ")[0]
    ns = {"__file__": path, "__name__": "bow_shapes"}
    exec(compile(src, path, "exec"), ns)
    return ns["shape"](state)


def edge_distance(w, h, px):
    """Steps (8 neighbours) from each drawn cell to the nearest empty one: 1 = the outline."""
    dist = {}
    frontier = []
    for i, col in enumerate(px):
        if col:
            x, y = i % w, i // w
            near = [(x + a, y + b) for a in (-1, 0, 1) for b in (-1, 0, 1)]
            if any(not (0 <= u < w and 0 <= v < h) or not px[v * w + u] for u, v in near):
                dist[(x, y)] = 1
                frontier.append((x, y))
    step = 1
    while frontier:
        step += 1
        nxt = []
        for x, y in frontier:
            for a in (-1, 0, 1):
                for b in (-1, 0, 1):
                    u, v = x + a, y + b
                    if 0 <= u < w and 0 <= v < h and px[v * w + u] and (u, v) not in dist:
                        dist[(u, v)] = step
                        nxt.append((u, v))
        frontier = nxt
    return dist


def voxels(item_id, quantise=False):
    """x = picture right, z = picture up, y = depth (centred on 0). The outline is `deep` voxels thick and the
    inside one more on each side (two more for big menu pictures): the item bulges a little, like a real object.
    quantise rounds colours to 1/16 steps so the held model merges into fewer boxes."""
    if item_id in BOW_STATES:
        return bow_voxels(BOW_STATES[item_id])
    grid = GRIDS[item_id]
    w, h, px = grid["w"], grid["h"], grid["px"]
    menu = item_id.startswith("menu_")
    deep = depth_of(grid, menu)
    dist = edge_distance(w, h, px)
    vox = {}
    for i, col in enumerate(px):
        if not col:
            continue
        if quantise:
            col = "".join("%02x" % min(255, (int(col[k : k + 2], 16) + 8) // 16 * 16) for k in (0, 2, 4))
        x, y = i % w, i // w
        bulge = min(dist[(x, y)] - 1, 2 if menu else 1)
        lo = -(deep // 2) - bulge
        hi = lo + deep + 2 * bulge
        for d in range(lo, hi):
            vox[(x, d, h - 1 - y)] = "#" + col
    return vox


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    mode = argv[0] if argv else "preview"
    rest = argv[1:]
    out_dir = None
    if mode == "icons":
        out_dir, rest = rest[0], rest[1:]
    ids = rest[0].split(",") if rest else sorted(GRIDS)
    ids = [i for i in ids if i in GRIDS or i in BOW_STATES]

    if mode == "export":
        path = os.path.join(ROOT, "assets", "icons", "models3d.json")
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        for item_id in ids:
            if item_id.startswith("menu_") or item_id in BOW_STATES:
                continue  # menu pictures are not held; the bow file exports its own
            entry = export_boxes(voxels(item_id, True))
            data["items"][item_id] = entry
            print("exported", item_id, len(entry["b"]) // 7, "boxes")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        return

    for item_id in ids:
        obj = build(voxels(item_id), item_id)
        scene, cam = setup(512, 512)
        # a soft fill from the lower right so the turned sides keep their colour
        fill = bpy.data.objects.new("Fill", bpy.data.lights.new("Fill", "SUN"))
        scene.collection.objects.link(fill)
        fill.data.energy = 0.9
        fill.rotation_euler = Euler((math.radians(-60), math.radians(20), math.radians(140)), "XYZ")
        set_glint(False)
        menu = item_id.startswith("menu_")
        obj.rotation_euler = Euler(MENU_TURN if menu else ITEM_TURN, "XYZ")
        # frame the turned model: its corners projected on the camera plane (camera looks along +y)
        bpy.context.view_layer.update()
        pts = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
        span = max(max(p.x for p in pts) - min(p.x for p in pts), max(p.z for p in pts) - min(p.z for p in pts))
        cx = (max(p.x for p in pts) + min(p.x for p in pts)) / 2
        cz = (max(p.z for p in pts) + min(p.z for p in pts)) / 2
        half = math.atan(18 / LENS)
        front = min(p.y for p in pts)
        dist = span * 1.08 / 2 / math.tan(half) - front
        look(cam, Vector((cx, -dist, cz)), Vector((cx, 0, cz)), None, LENS)
        if mode == "icons":
            scene.render.film_transparent = True
            scene.render.filepath = os.path.join(out_dir, item_id + ".png")
        else:
            scene.render.filepath = os.path.join(HERE, "render-%s.png" % item_id)
        bpy.ops.render.render(write_still=True)
        print("rendered", item_id)


main()
