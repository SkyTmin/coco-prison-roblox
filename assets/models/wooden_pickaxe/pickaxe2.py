# Our wooden pickaxe, variant 2 — after the Codex concept concepts/wooden-pickaxe-concept.png [владелец 26.10: «попроси
# кодекс скинуть иллюстрации, и сделай ещё одну кирку, и сравним»]: finer voxels (1/40 of the length, 0.1 studs), a
# broad oak crescent head tapering to points, a 3×3 oak handle with grain, a twine grip by the butt, a dark binding
# block with a rope X where the head sits and a peg on top.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/wooden_pickaxe/pickaxe2.py
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PX = 0.1  # studs per voxel


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# ---------------------------------------------------------------- palette
OAK = ["#7a5532", "#6c4a2b", "#85603a"]
OAK_DARK = "#56391f"
TWINE = "#cdb68a"
TWINE_DARK = "#a08a5c"
HEAD = ["#a87c48", "#9c7040", "#b08450"]
HEAD_HI = "#c8a068"
HEAD_LO = "#6e5230"
TIP = "#d2ac74"
BIND = "#5e4024"

rng = random.Random(2611)
vox = {}


def put(x, y, z, col):
    vox[(x, y, z)] = col


# ---------------------------------------------------------------- the handle: 4×4, z -26..12, the butt cap wider
HX = (-2, -1, 0, 1)
for z in range(-26, 17):
    for x in HX:
        for y in HX:
            if z <= -24 or z >= 13:
                col = OAK_DARK
            elif x == -2 and y == 1:
                col = OAK_DARK if rng.random() < 0.7 else OAK[1]  # a dark grain streak down one corner
            else:
                col = OAK[(z // 3 + x + 2 * y + rng.randint(0, 1)) % 3]
            put(x, y, z, col)
for z in (-27, -26, -25):  # the butt: a px wider all round
    for x in range(-3, 3):
        for y in range(-3, 3):
            if x in (-3, 2) and y in (-3, 2):
                continue
            put(x, y, z, BIND if (x + y + z) % 4 == 0 else OAK_DARK)
for z in range(-22, -12):  # the twine grip: wraps a px proud, a dark line between wraps
    for x in range(-3, 3):
        for y in range(-3, 3):
            if x in (-3, 2) or y in (-3, 2):
                if x in (-3, 2) and y in (-3, 2):
                    continue
                put(x, y, z, TWINE_DARK if z % 2 == 0 else TWINE)


# ---------------------------------------------------------------- the crescent head: an arc of radius 21 round
# (−0.5, −10) swept ±72°, 9 px thick in the middle tapering to a point at both ends
CX, CZ, R, SWEEP = -0.5, -10.0, 21.0, math.radians(72)
for x in range(-24, 24):
    for z in range(-8, 20):
        px, pz = x + 0.5 - 0.5 - CX, z + 0.5 - CZ
        th = math.atan2(px, pz)  # 0 straight up
        if abs(th) > SWEEP:
            continue
        k = abs(th) / SWEEP
        half = 0.5 + 4.2 * (1 - k) ** 0.8
        dr = math.hypot(px, pz) - R
        if abs(dr) > half:
            continue
        depth = (-2, -1, 0, 1) if k < 0.2 else ((-2, -1, 0, 1) if k < 0.55 else (-1, 0))
        for y in depth:
            if k > 0.84:
                col = TIP
            elif dr > half - 1:
                col = HEAD_HI  # the top edge
            elif dr < -half + 1:
                col = HEAD_LO  # the underside
            else:
                col = HEAD[rng.randint(0, 2)]
            put(x, y, z, col)
# worn nicks on the top edge
for x in (-12, 8, 15):
    zs = [z for (vx, vy, z) in vox if vx == x and vy == 0 and vox[(vx, vy, z)] == HEAD_HI]
    if zs:
        for y in (-2, -1, 0, 1):
            vox.pop((x, y, max(zs)), None)

# ---------------------------------------------------------------- the binding block with a rope X, the peg on top
for z in range(5, 15):
    for x in range(-4, 4):
        for y in range(-4, 4):
            if -4 < x < 3 and -4 < y < 3:
                continue  # inside
            u = (x + 0.5) if y in (-4, 3) else (y + 0.5)  # across the face
            v = z - 9.5
            put(x, y, z, TWINE if abs(abs(u) - abs(v)) < 1.0 else BIND)
for x in HX:
    for y in HX:
        put(x, y, 15, OAK_DARK)
        put(x, y, 16, OAK_DARK)

# ---------------------------------------------------------------- mesh: one cube per voxel, inner faces dropped
def build():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    mats = {}
    me = bpy.data.meshes.new("WoodenPickaxe")
    obj = bpy.data.objects.new("WoodenPickaxe", me)
    bpy.context.scene.collection.objects.link(obj)
    bm = bmesh.new()
    faces_dir = [
        ((1, 0, 0), [(1, 0, 0), (1, 1, 0), (1, 1, 1), (1, 0, 1)]),
        ((-1, 0, 0), [(0, 0, 0), (0, 0, 1), (0, 1, 1), (0, 1, 0)]),
        ((0, 1, 0), [(0, 1, 0), (0, 1, 1), (1, 1, 1), (1, 1, 0)]),
        ((0, -1, 0), [(0, 0, 0), (1, 0, 0), (1, 0, 1), (0, 0, 1)]),
        ((0, 0, 1), [(0, 0, 1), (1, 0, 1), (1, 1, 1), (0, 1, 1)]),
        ((0, 0, -1), [(0, 0, 0), (0, 1, 0), (1, 1, 0), (1, 0, 0)]),
    ]
    verts = {}

    def v(p):
        if p not in verts:
            verts[p] = bm.verts.new(Vector(p) * PX)
        return verts[p]

    for (x, y, z), col in vox.items():
        # a slight per-voxel shade jitter so flat colours read as pixels
        key = col + "%d" % rng.randint(0, 2)
        if key not in mats:
            base = hexrgb(col)
            j = [0.94, 1.0, 1.05][int(key[-1])]
            m = bpy.data.materials.new(key)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = srgb_to_linear(tuple(min(1, c * j) for c in base)) + (1,)
            bsdf.inputs["Roughness"].default_value = 1.0
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.0
            me.materials.append(m)
            mats[key] = len(me.materials) - 1
        for n, quad in faces_dir:
            if (x + n[0], y + n[1], z + n[2]) in vox:
                continue
            f = bm.faces.new([v((x + a, y + b, z + c)) for a, b, c in quad])
            f.material_index = mats[key]
    # centre the mesh on its bounding box so every view turns round the middle
    lo = Vector((min(p.co.x for p in bm.verts), min(p.co.y for p in bm.verts), min(p.co.z for p in bm.verts)))
    hi = Vector((max(p.co.x for p in bm.verts), max(p.co.y for p in bm.verts), max(p.co.z for p in bm.verts)))
    mid = (lo + hi) / 2
    for p in bm.verts:
        p.co -= mid
    bm.normal_update()
    bm.to_mesh(me)
    bm.free()
    # centre on the grip so rotations look natural
    obj.location = (-0.0 * PX, 0, 0)
    return obj


def setup(w, h):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.view_settings.view_transform = "Standard"
    world = scene.world or bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = srgb_to_linear(hexrgb("#b4b4b4")) + (1,)
    bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.new("Key", bpy.data.lights.new("Key", "SUN"))
    scene.collection.objects.link(sun)
    sun.data.energy = 2.2
    sun.data.angle = math.radians(20)
    sun.rotation_euler = Euler((math.radians(50), 0, math.radians(-35)), "XYZ")
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def look(cam, loc, target, ortho=None, lens=60):
    cam.location = loc
    d = Vector(target) - Vector(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    if ortho:
        cam.data.type = "ORTHO"
        cam.data.ortho_scale = ortho
    else:
        cam.data.type = "PERSP"
        cam.data.lens = lens


def main():
    obj = build()
    scene, cam = setup(900, 900)
    centre = Vector((0, 0, 0))

    def shot(name, rot, loc, ortho=None, lens=60):
        obj.rotation_euler = Euler(rot, "XYZ")
        look(cam, Vector(loc), centre, ortho, lens)
        scene.render.filepath = os.path.join(HERE, "render2-%s.png" % name)
        bpy.ops.render.render(write_still=True)

    # the inventory icon: flat front, the handle on the diagonal like an item sprite
    obj.location = (0, 0, 0)
    shot("icon", (0, math.radians(-45), 0), (0, -30, 0), ortho=6.0)
    shot("hero", (math.radians(10), math.radians(-35), math.radians(30)), (3.2, -7.5, 2.2), lens=50)
    shot("side", (0, 0, math.radians(90)), (0, -30, 0), ortho=5.6)
    shot("back", (math.radians(-10), math.radians(30), math.radians(215)), (-3.5, -7.5, 2.5), lens=50)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "pickaxe2.blend"))
    print("voxels", len(vox))


main()
