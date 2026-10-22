# Voxel sculpture from a reference sheet [владелец 22.10: босс Каменоломни «точь в точь» по референсу Codex].
# For voxel-sculpture references (golems, bosses) where hand-placed boxes look flat: the model is rebuilt from the
# reference's FRONT and SIDE views at the reference's own pixel-cell size:
#   1. volume: per joint, a voxel (X, Y, Z) is solid when the joint's front-view mask has (X, Z) and its side-view
#      mask has (Y, Z) — the visual hull of the two silhouettes, so both views match;
#   2. relief: darker cells of a view are crevices between the sculpture's blocks — the surface is carved in by up
#      to RELIEF cells there (front view carves the front, side view both sides), lighter cells stay proud;
#   3. colour: every exposed face takes the pixel of the view it faces (front / back ← front view, sides ← side
#      view, top ← side view, bottom ← dark stone); lava pixels become emissive faces.
# The result is one mesh per joint (stone faces + glowing lava faces), parented to the joint empties like the
# blockmob boxes, so blockmob's actions / compare / previews work unchanged. Config: <id>/voxelize.json.
import bpy
import bmesh
import json
import math
import os

import numpy as np


def _load(path):
    img = bpy.data.images.load(path, check_existing=True)
    w, h = img.size
    px = np.array(img.pixels[:], dtype=np.float32).reshape(h, w, 4)[::-1, :, :3]  # top row first, sRGB 0..1
    return (px * 255).astype(np.int32), w, h


def _cells(px, rect, C, bg, tol):
    # cell grid over rect (sheet px): mask, median colour, luminance
    x0, y0, x1, y1 = rect
    cols, rows = (x1 - x0) // C, (y1 - y0) // C
    mask = np.zeros((rows, cols), bool)
    colour = np.zeros((rows, cols, 3), np.int32)
    for r in range(rows):
        for c in range(cols):
            block = px[y0 + r * C:y0 + (r + 1) * C, x0 + c * C:x0 + (c + 1) * C].reshape(-1, 3)
            fg = np.abs(block - np.array(bg)).sum(axis=1) > tol
            if fg.mean() < 0.5:
                continue
            sel = block[fg]
            lum = sel @ np.array([0.299, 0.587, 0.114])
            colour[r, c] = sel[np.argsort(lum)[len(sel) // 2]]
            mask[r, c] = True
    lum = colour @ np.array([0.299, 0.587, 0.114])
    return mask, colour, lum


def _is_lava(c):
    return (c[0] > 225 and c[1] > 160) or (c[0] > 150 and c[0] - c[2] > 90)


def sculpt(cfg_path, joints_pivots):
    """Returns {joint: (verts, faces, face_colours, face_glow)} in Blender space (Y forward, Z up)."""
    here = os.path.dirname(cfg_path)
    with open(cfg_path, encoding="utf-8") as f:
        cfg = json.load(f)
    px, W, H = _load(os.path.join(here, cfg["reference"]))
    C, S = cfg["cell"], cfg["scale"]
    v = C / S  # voxel size in studs
    bg, tol = cfg["background"], cfg["tolerance"]
    fr = cfg["front"]  # {rect, centreX, groundY, regions: [{joint, rect}]}
    sd = cfg["side"]   # {rect, centreX, groundY, regions: [{joints, rect}]}
    fmask, fcol, flum = _cells(px, fr["rect"], C, bg, tol)
    smask, scol, slum = _cells(px, sd["rect"], C, bg, tol)
    frows, fcols = fmask.shape
    srows, scols = smask.shape

    def f_xz(r, c):  # front cell centre → (X, Z)
        sx = fr["rect"][0] + (c + 0.5) * C
        sy = fr["rect"][1] + (r + 0.5) * C
        return (fr["centreX"] - sx) / S, (fr["groundY"] - sy) / S

    def s_yz(r, c):  # side cell centre → (Y, Z)
        sx = sd["rect"][0] + (c + 0.5) * C
        sy = sd["rect"][1] + (r + 0.5) * C
        return (sd["centreX"] - sx) / S, (sd["groundY"] - sy) / S

    def side_row(z):
        return int(math.floor((sd["groundY"] - z * S - sd["rect"][1]) / C))

    def joint_at(regions, sx, sy, key):
        for g in regions:
            x0, y0, x1, y1 = g["rect"]
            if x0 <= sx < x1 and y0 <= sy < y1:
                return g[key]
        return None

    fjoint = [[None] * fcols for _ in range(frows)]
    falso = [[()] * fcols for _ in range(frows)]  # extra joints filling the same front cell deeper (body behind the head)
    for r in range(frows):
        for c in range(fcols):
            if fmask[r, c]:
                sx, sy = fr["rect"][0] + (c + 0.5) * C, fr["rect"][1] + (r + 0.5) * C
                fjoint[r][c] = joint_at(fr["regions"], sx, sy, "joint")
                for g in fr["regions"]:
                    if g["rect"][0] <= sx < g["rect"][2] and g["rect"][1] <= sy < g["rect"][3]:
                        falso[r][c] = tuple(g.get("also", ()))
                        break
    sjoints = [[None] * scols for _ in range(srows)]
    for r in range(srows):
        for c in range(scols):
            if smask[r, c]:
                sjoints[r][c] = joint_at(sd["regions"], sd["rect"][0] + (c + 0.5) * C, sd["rect"][1] + (r + 0.5) * C, "joints")
    relief = cfg.get("relief", 2)
    fallback = cfg.get("depthFallback", {})  # joint → [y0, y1] when the side view has nothing for it
    stone_lo, stone_hi = np.percentile(flum[fmask], 15), np.percentile(flum[fmask], 85)

    def carve(lum, colour):
        if _is_lava(colour):
            return 0
        t = (lum - stone_lo) / max(1.0, stone_hi - stone_lo)
        return int(round((1 - min(1.0, max(0.0, t))) * relief))

    # occupancy grid per joint: occ[joint] = set of (c, r, s) with c = front column, r = front row, s = side column
    occ = {}
    for r in range(frows):
        for c in range(fcols):
          for j in ((fjoint[r][c],) + falso[r][c]) if fjoint[r][c] else ():
            x, z = f_xz(r, c)
            sr = side_row(z)
            cells = []
            # the joint's side cells in this row — or the nearest row that has some (the two views of an AI sheet
            # rarely agree on heights exactly)
            for dr in (0, -1, 1, -2, 2, -3, 3, -4, 4):
                rr = sr + dr
                if 0 <= rr < srows:
                    cells = [s for s in range(scols) if sjoints[rr][s] and j in sjoints[rr][s]]
                    if cells:
                        break
            if not cells and j in fallback:
                y0, y1 = fallback[j]
                cells = [s for s in range(scols) if y0 <= s_yz(0, s)[0] <= y1]
            for s in cells:
                occ.setdefault(j, set()).add((c, r, s))
    # third view: the top view shapes the cross-sections (the hull of two views is boxy). Its scales are fitted
    # separately (AI sheets disagree): Y from the side view's depth, X from the front view's width
    tp = cfg.get("top")
    if tp:
        tmask, _, _ = _cells(px, tp["rect"], C, bg, tol)
        trows, tcols = tmask.shape
        dil = tp.get("dilate", 1)
        for j, cells in occ.items():
            if j in tp.get("exclude", []):
                continue
            for (c, r, s) in list(cells):
                x, _ = f_xz(r, c)
                y, _ = s_yz(0, s)
                ix = tp["xFront"] + (tp["yFront"] - y) * tp["yScale"]
                iy = tp["centreY"] + x * tp["xScale"] * tp.get("xSign", 1)
                tc = int((ix - tp["rect"][0]) // C)
                tr = int((iy - tp["rect"][1]) // C)
                ok = False
                for dr in range(-dil, dil + 1):
                    for dc in range(-dil, dil + 1):
                        rr, cc = tr + dr, tc + dc
                        if 0 <= rr < trows and 0 <= cc < tcols and tmask[rr, cc]:
                            ok = True
                if not ok:
                    cells.discard((c, r, s))
    # relief: carve the front (the smallest side columns are the most forward) and both sides
    for j, cells in occ.items():
        by_col = {}
        for (c, r, s) in cells:
            by_col.setdefault((c, r), []).append(s)
        for (c, r), ss in by_col.items():
            k = carve(flum[r, c], fcol[r, c])
            ss.sort()
            for s in ss[:min(k, max(0, len(ss) - 2))]:
                cells.discard((c, r, s))
        by_row = {}
        for (c, r, s) in cells:
            by_row.setdefault((r, s), []).append(c)
        for (r, s), cs in by_row.items():
            x, z = f_xz(r, cs[0])
            sr = side_row(z)
            if not (0 <= sr < srows):
                continue
            k = carve(slum[sr, s], scol[sr, s])
            cs.sort()
            if len(cs) > 2 * k + 2:
                for cc in cs[:k] + cs[len(cs) - k:]:
                    cells.discard((cc, r, s))
    # faces
    dark = tuple(cfg.get("bottomColour", [40, 36, 42]))
    out = {}
    # neighbour offsets in (front column, front row, side column): +X = smaller column, +Y (forward) = smaller
    # side column, +Z = smaller row
    dirs = [((-1, 0, 0), "px"), ((1, 0, 0), "nx"), ((0, 0, -1), "front"), ((0, 0, 1), "back"), ((0, -1, 0), "top"), ((0, 1, 0), "bottom")]
    for j, cells in occ.items():
        verts, faces, cols, glow = [], [], [], []
        vindex = {}

        def vert(p):
            key = (round(p[0], 4), round(p[1], 4), round(p[2], 4))
            if key not in vindex:
                vindex[key] = len(verts)
                verts.append(key)
            return vindex[key]

        for (c, r, s) in cells:
            x, z = f_xz(r, c)
            y, _ = s_yz(0, s)
            sr = side_row(z)
            for (dc, dr, ds), name in dirs:
                if (c + dc, r + dr, s + ds) in cells:
                    continue
                # colour from the view this face looks at
                if name in ("front", "back"):
                    col = fcol[r, c]
                elif name == "bottom":
                    col = dark
                elif name == "top":
                    # tops take the front colour without its lava (a crack seen from above would streak)
                    col = fcol[r, c] if not _is_lava(fcol[r, c]) else tuple(cfg.get("topColour", [96, 89, 99]))
                else:
                    col = scol[sr, s] if 0 <= sr < srows and smask[sr, s] else fcol[r, c]
                h = v / 2
                # the face's quad: +X is towards smaller front columns (c), +Z towards smaller rows, +Y towards
                # smaller side columns
                cx, cy, cz = x, y, z
                if name == "px":
                    q = [(cx + h, cy - h, cz - h), (cx + h, cy + h, cz - h), (cx + h, cy + h, cz + h), (cx + h, cy - h, cz + h)]
                elif name == "nx":
                    q = [(cx - h, cy + h, cz - h), (cx - h, cy - h, cz - h), (cx - h, cy - h, cz + h), (cx - h, cy + h, cz + h)]
                elif name == "front":
                    q = [(cx - h, cy + h, cz - h), (cx - h, cy + h, cz + h), (cx + h, cy + h, cz + h), (cx + h, cy + h, cz - h)]
                elif name == "back":
                    q = [(cx + h, cy - h, cz - h), (cx + h, cy - h, cz + h), (cx - h, cy - h, cz + h), (cx - h, cy - h, cz - h)]
                elif name == "top":
                    q = [(cx - h, cy - h, cz + h), (cx + h, cy - h, cz + h), (cx + h, cy + h, cz + h), (cx - h, cy + h, cz + h)]
                else:
                    q = [(cx - h, cy + h, cz - h), (cx + h, cy + h, cz - h), (cx + h, cy - h, cz - h), (cx - h, cy - h, cz - h)]
                faces.append([vert(p) for p in q])
                cols.append(tuple(int(t) for t in col))
                glow.append(_is_lava(col))
        out[j] = (verts, faces, cols, glow)
    return out, cfg


def build_meshes(cfg_path, joints, pivots, srgb):
    """Creates one mesh object per joint ("Sculpt_<joint>") parented to its joint empty."""
    data, cfg = sculpt(cfg_path, pivots)
    stone = bpy.data.materials.new("SculptStone")
    stone.use_nodes = True
    nt = stone.node_tree
    bsdf = nt.nodes.get("Principled BSDF")
    attr = nt.nodes.new("ShaderNodeVertexColor")
    attr.layer_name = "Col"
    nt.links.new(attr.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 1.0
    lava = bpy.data.materials.new("SculptLava")
    lava.use_nodes = True
    nt = lava.node_tree
    b2 = nt.nodes.get("Principled BSDF")
    a2 = nt.nodes.new("ShaderNodeVertexColor")
    a2.layer_name = "Col"
    nt.links.new(a2.outputs["Color"], b2.inputs["Base Color"])
    nt.links.new(a2.outputs["Color"], b2.inputs["Emission Color"])
    b2.inputs["Emission Strength"].default_value = cfg.get("glowStrength", 1.0)
    total = 0
    for j, (verts, faces, cols, glow) in data.items():
        me = bpy.data.meshes.new("Sculpt_" + j)
        piv = pivots[j]
        me.from_pydata([(p[0] - piv[0], p[1] - piv[1], p[2] - piv[2]) for p in verts], [], faces)
        me.update()
        me.materials.append(stone)
        me.materials.append(lava)
        layer = me.color_attributes.new("Col", "BYTE_COLOR", "CORNER")
        for i, poly in enumerate(me.polygons):
            poly.material_index = 1 if glow[i] else 0
            col = (cols[i][0] / 255, cols[i][1] / 255, cols[i][2] / 255, 1.0)
            for li in poly.loop_indices:
                layer.data[li].color_srgb = col
        ob = bpy.data.objects.new("Sculpt_" + j, me)
        bpy.context.scene.collection.objects.link(ob)
        ob.parent = joints[j]
        ob["sculpt"] = True
        total += len(faces)
    return total
