# Our own wooden pickaxe [владелец 26.10: «смоделируй деревянную кирку в блендер для игры и покажи»] — a voxel model,
# one voxel = 1/16 of the length (0.25 studs, so the pickaxe is ≈ 4 studs long like a held tool), not a copy of any
# Minecraft sprite: an oak handle with grain and a twine grip, a twine binding where the head sits, an arched head of
# planks with light worn edges and pale tips.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/wooden_pickaxe/pickaxe.py
# → pickaxe.blend + render-hero.png, render-icon.png, render-side.png, render-back.png next to this file.
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PX = 0.25  # studs per voxel


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# ---------------------------------------------------------------- palette
OAK = ["#7a5532", "#6c4a2b", "#85603a"]  # handle grain
OAK_DARK = "#56391f"  # the shaded streak and the end caps
TWINE = ["#cdb68a", "#b49b6c"]
TWINE_DARK = "#8c7449"
PLANK_TOP = "#bd9058"  # the head's worn top edge
PLANK = ["#a27846", "#966c3d"]
PLANK_LOW = "#7c5a34"  # the head's underside
TIP = "#d6b07a"

rng = random.Random(2610)
vox = {}  # (x, y, z) -> hex


def put(x, y, z, col):
    vox[(x, y, z)] = col


# ---------------------------------------------------------------- the handle: 2×2 px, z -1..12
for z in range(-1, 13):
    for x in (-1, 0):
        for y in (-1, 0):
            if z == -1:
                col = OAK_DARK  # the butt
            elif z in (1, 2, 4, 5) :
                # the twine grip: two bands of wraps, the lower edge of each wrap darker
                col = TWINE_DARK if z in (1, 4) else TWINE[(x + y) % 2]
            elif x == -1 and y == 0 and z % 3 != 0:
                col = OAK_DARK  # a dark grain streak down one corner
            else:
                col = OAK[(z * 7 + x * 3 + y) % 3]
            put(x, y, z, col)

# ---------------------------------------------------------------- the head: an arch of planks across x -8..7
def arch_top(x):
    d = abs(x + 0.5) / 8  # 0 at the middle, ≈ 1 at the tips
    return 14 - int(round(5.5 * d ** 1.8))


for x in range(-8, 8):
    top = arch_top(x)
    d = abs(x + 0.5)
    thick = 3 if d < 4 else (2 if d < 7 else 1)  # thicker over the handle, pointed at the tips
    depth = (-2, -1, 0, 1) if d < 2 else (-1, 0)  # swells over the handle
    for k in range(thick):
        z = top - k
        for y in depth:
            if d >= 7:
                col = TIP
            elif k == 0:
                col = PLANK_TOP
            elif k == thick - 1:
                col = PLANK_LOW
            else:
                col = PLANK[(x + y) % 2]
            put(x, y, z, col)
    # a plank seam every 4 px: a darker voxel line on the faces
    if x in (-5, -1, 3) and thick > 1:
        for y in depth:
            put(x, y, top - 1, PLANK_LOW)

# ---------------------------------------------------------------- the binding: twine wrapped round handle and head
for z in range(10, 13):
    for x in range(-2, 2):
        for y in range(-2, 2):
            if (x, y, z) in vox and x in (-1, 0) and y in (-1, 0):
                continue  # the handle inside
            if x in (-2, 1) or y in (-2, 1):
                put(x, y, z, TWINE_DARK if z == 11 else TWINE[0] if z == 12 else TWINE[1])  # wraps in bands
# the handle's end wedged through the head
for x in (-1, 0):
    for y in (-1, 0):
        put(x, y, 15, OAK_DARK)


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
        scene.render.filepath = os.path.join(HERE, "render-%s.png" % name)
        bpy.ops.render.render(write_still=True)

    # the inventory icon: flat front, the handle on the diagonal like an item sprite
    obj.location = (0, 0, 0)
    shot("icon", (0, math.radians(-45), 0), (0, -30, 0), ortho=6.2)
    shot("hero", (math.radians(10), math.radians(-35), math.radians(30)), (3.2, -7.5, 2.2), lens=50)
    shot("side", (0, 0, math.radians(90)), (0, -30, 0), ortho=5.6)
    shot("back", (math.radians(-10), math.radians(30), math.radians(215)), (-3.5, -7.5, 2.5), lens=50)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "pickaxe.blend"))
    print("voxels", len(vox))


main()
