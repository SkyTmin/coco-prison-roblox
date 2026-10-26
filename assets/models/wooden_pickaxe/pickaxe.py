# Our pickaxes [владелец 26.10: «смоделируй деревянную кирку в блендер»; «давай первый вариант сделаем. Сделай
# следующие кирки и покажи мне эффект зачарования на них»] — voxel models, one voxel = 1/16 of the length (0.25 studs,
# so a pickaxe is ≈ 4 studs long like a held tool), not a copy of any Minecraft sprite. One shape for every material
# (the game's tiers: wood, stone, iron, diamond — tools.json materialAfter): an oak handle with grain and a grip, a
# binding where the head sits, an arched head. Each material has its own head palette and details: wooden planks with
# seams, chipped speckled stone, polished iron with a riveted collar and a leather grip, faceted diamond with a gold
# collar.
# The enchant glint: a purple tint plus two diagonal bands of light sliding along the model (one shared node group,
# its Phase/On values set per frame).
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/wooden_pickaxe/pickaxe.py
#   [-- frames <dir>]
# → render-<material>-{icon,hero,icon-glint,hero-glint}.png and pickaxe.blend (diamond) next to this file;
#   with `frames`, 24 icon frames of the glint per material into <dir> (glint-<material>-NN.png) for the GIF.
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
PX = 0.25  # studs per voxel
GLINT_FRAMES = 24


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


# ---------------------------------------------------------------- palettes
OAK = ["#7a5532", "#6c4a2b", "#85603a"]  # handle grain
OAK_DARK = "#56391f"  # the shaded streak and the end caps
TWINE = (["#cdb68a", "#b49b6c"], "#8c7449")
LEATHER = (["#6b4428", "#5e3b22"], "#3e2614")

MATERIALS = {
    "wood": {
        "top": "#bd9058",  # the head's worn top edge
        "body": ["#a27846", "#966c3d"],
        "low": "#7c5a34",  # the head's underside
        "tip": "#d6b07a",
        "grip": TWINE,
        "bind": (["#cdb68a", "#b49b6c"], "#8c7449"),
    },
    "stone": {
        "top": "#a9a9a6",
        "body": ["#8c8c89", "#7e7e7b", "#959592"],
        "low": "#5f5f5c",
        "tip": "#b8b8b4",
        "fleck": ["#6a6a67", "#a3a3a0"],
        "grip": TWINE,
        "bind": (["#cdb68a", "#b49b6c"], "#8c7449"),
    },
    "iron": {
        "top": "#f2f2f2",  # the polished edge
        "body": ["#cdcdcd", "#c0c0c0"],
        "low": "#8a8a8c",
        "tip": "#ffffff",
        "grip": LEATHER,
        "bind": (["#5a5b61", "#515258"], "#3f4045"),
        "rivet": "#b4b4bc",
    },
    "diamond": {
        "top": "#aafff3",
        "body": ["#44d8c8", "#37c6b6"],
        "low": "#1c8a80",
        "tip": "#e2fffb",
        "facet": "#8af5e8",  # pale facet lines across the head
        "grip": LEATHER,
        "bind": (["#e8b830", "#d6a624"], "#a87a14"),
        "rivet": "#fff27a",
    },
}


# ---------------------------------------------------------------- the shape
def arch_top(x):
    d = abs(x + 0.5) / 8  # 0 at the middle, ≈ 1 at the tips
    return 14 - int(round(5.5 * d**1.8))


def shape(mat):
    pal = MATERIALS[mat]
    rng = random.Random(2610)
    vox = {}

    def put(x, y, z, col):
        vox[(x, y, z)] = col

    # the handle: 2×2 px, z -1..12
    grip, grip_dark = pal["grip"]
    for z in range(-1, 13):
        for x in (-1, 0):
            for y in (-1, 0):
                if z == -1:
                    col = OAK_DARK  # the butt
                elif z in (1, 2, 4, 5):
                    # the grip: two bands of wraps, the lower edge of each wrap darker
                    col = grip_dark if z in (1, 4) else grip[(x + y) % 2]
                elif x == -1 and y == 0 and z % 3 != 0:
                    col = OAK_DARK  # a dark grain streak down one corner
                else:
                    col = OAK[(z * 7 + x * 3 + y) % 3]
                put(x, y, z, col)

    # the head: an arch across x -8..7
    body = pal["body"]
    for x in range(-8, 8):
        top = arch_top(x)
        d = abs(x + 0.5)
        thick = 3 if d < 4 else (2 if d < 7 else 1)  # thicker over the handle, pointed at the tips
        depth = (-2, -1, 0, 1) if d < 2 else (-1, 0)  # swells over the handle
        for k in range(thick):
            z = top - k
            for y in depth:
                if d >= 7:
                    col = pal["tip"]
                elif k == 0:
                    col = pal["top"]
                elif k == thick - 1:
                    col = pal["low"]
                else:
                    col = body[(x + y) % len(body)]
                put(x, y, z, col)
        if mat == "wood" and x in (-5, -1, 3) and thick > 1:
            for y in depth:
                put(x, y, top - 1, pal["low"])  # a plank seam every 4 px
        if mat == "diamond" and x in (-5, -4, 2, 3) and thick > 1:
            for y in depth:
                put(x, y, top - (1 if x in (-5, 3) else 0), pal["facet"])  # two slanted facet lines

    if mat == "stone":
        # flecks in the stone and chips knocked out of the front top edge
        for key, col in list(vox.items()):
            if col in body and rng.random() < 0.3:
                vox[key] = pal["fleck"][rng.randrange(2)]
        for x in (-6, 2, 5):
            vox.pop((x, -1, arch_top(x)), None)

    # the binding round handle and head
    bind, bind_dark = pal["bind"]
    for z in range(10, 13):
        for x in range(-2, 2):
            for y in range(-2, 2):
                if x in (-1, 0) and y in (-1, 0):
                    continue  # the handle inside
                put(x, y, z, bind_dark if z == 11 else bind[0] if z == 12 else bind[1])
    if "rivet" in pal:
        for p in ((-2, -1, 11), (1, 0, 11), (0, -2, 11), (-1, 1, 11)):
            put(*p, pal["rivet"])  # one rivet on each face of the collar
    # the handle's end wedged through the head
    for x in (-1, 0):
        for y in (-1, 0):
            put(x, y, 15, OAK_DARK)
    return vox


# ---------------------------------------------------------------- the glint node group (shared by every material)
def glint_group():
    g = bpy.data.node_groups.get("Glint")
    if g:
        return g
    g = bpy.data.node_groups.new("Glint", "ShaderNodeTree")
    g.interface.new_socket("Base", in_out="INPUT", socket_type="NodeSocketColor")
    g.interface.new_socket("Color", in_out="OUTPUT", socket_type="NodeSocketColor")
    g.interface.new_socket("Emission", in_out="OUTPUT", socket_type="NodeSocketFloat")
    n, link = g.nodes, g.links.new
    gin, gout = n.new("NodeGroupInput"), n.new("NodeGroupOutput")
    phase = n.new("ShaderNodeValue")
    phase.name = "Phase"
    on = n.new("ShaderNodeValue")
    on.name = "On"
    tc = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ")
    link(tc.outputs["Object"], sep.inputs[0])

    def math_node(op, a, b=None, c=None):
        m = n.new("ShaderNodeMath")
        m.operation = op
        for i, v in enumerate((a, b, c)):
            if v is None:
                continue
            if isinstance(v, (int, float)):
                m.inputs[i].default_value = v
            else:
                link(v, m.inputs[i])
        return m.outputs[0]

    def band(kx, kz, freq, speed, sharp):
        # 0.5 + 0.5 sin((kx·x + kz·z)·freq − speed·phase), sharpened into a narrow stripe
        s = math_node("ADD", math_node("MULTIPLY", sep.outputs["X"], kx), math_node("MULTIPLY", sep.outputs["Z"], kz))
        s = math_node("SUBTRACT", math_node("MULTIPLY", s, freq), math_node("MULTIPLY", phase.outputs[0], speed))
        return math_node("POWER", math_node("MULTIPLY_ADD", math_node("SINE", s), 0.5, 0.5), sharp)

    light = math_node("MAXIMUM", band(1.0, 1.0, 1.3, 1.0, 28), math_node("MULTIPLY", band(1.0, -0.45, 2.0, 2.0, 40), 0.75))
    light = math_node("MULTIPLY", light, on.outputs[0])
    mix = n.new("ShaderNodeMix")
    mix.data_type = "RGBA"
    mix.blend_type = "MIX"
    link(gin.outputs["Base"], mix.inputs["A"])
    mix.inputs["B"].default_value = srgb_to_linear(hexrgb("#9a5cff")) + (1,)
    link(math_node("MULTIPLY", math_node("MULTIPLY_ADD", light, 0.4, 0.1), on.outputs[0]), mix.inputs["Factor"])
    link(mix.outputs["Result"], gout.inputs["Color"])
    link(math_node("MULTIPLY", light, 1.2), gout.inputs["Emission"])
    phase.outputs[0].default_value = 0.0
    on.outputs[0].default_value = 0.0
    return g


def set_glint(on, phase=0.0):
    g = glint_group()
    g.nodes["On"].outputs[0].default_value = 1.0 if on else 0.0
    g.nodes["Phase"].outputs[0].default_value = phase


# ---------------------------------------------------------------- mesh: one cube per voxel, inner faces dropped
def build(vox, name):
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    rng = random.Random(2610)
    group = glint_group()
    mats = {}
    me = bpy.data.meshes.new(name)
    obj = bpy.data.objects.new(name, me)
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

    for (x, y, z), col in sorted(vox.items()):
        # a slight per-voxel shade jitter so flat colours read as pixels
        key = col + "%d" % rng.randint(0, 2)
        if key not in mats:
            base = hexrgb(col)
            j = [0.94, 1.0, 1.05][int(key[-1])]
            m = bpy.data.materials.new(name + key)
            m.use_nodes = True
            nt = m.node_tree
            bsdf = nt.nodes["Principled BSDF"]
            gl = nt.nodes.new("ShaderNodeGroup")
            gl.node_tree = group
            gl.inputs["Base"].default_value = srgb_to_linear(tuple(min(1, c * j) for c in base)) + (1,)
            nt.links.new(gl.outputs["Color"], bsdf.inputs["Base Color"])
            nt.links.new(gl.outputs["Color"], bsdf.inputs["Emission Color"])
            nt.links.new(gl.outputs["Emission"], bsdf.inputs["Emission Strength"])
            bsdf.inputs["Roughness"].default_value = 1.0
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.0
            me.materials.append(m)
            mats[key] = len(me.materials) - 1
        for nrm, quad in faces_dir:
            if (x + nrm[0], y + nrm[1], z + nrm[2]) in vox:
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


ICON = ((0, math.radians(-45), 0), (0, -30, 0), 6.2, 60)  # flat front, the handle on the diagonal like an item sprite
HERO = ((math.radians(10), math.radians(-35), math.radians(30)), (3.2, -7.5, 2.2), None, 50)


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    frames_dir = argv[1] if len(argv) >= 2 and argv[0] == "frames" else None
    for mat in MATERIALS:
        obj = build(shape(mat), "Pickaxe_" + mat)
        scene, cam = setup(900, 900)

        def shot(path, view, size=900):
            rot, loc, ortho, lens = view
            scene.render.resolution_x = scene.render.resolution_y = size
            obj.rotation_euler = Euler(rot, "XYZ")
            look(cam, Vector(loc), Vector((0, 0, 0)), ortho, lens)
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)

        set_glint(False)
        shot(os.path.join(HERE, "render-%s-icon.png" % mat), ICON)
        shot(os.path.join(HERE, "render-%s-hero.png" % mat), HERO)
        set_glint(True, 2.2)
        shot(os.path.join(HERE, "render-%s-icon-glint.png" % mat), ICON)
        shot(os.path.join(HERE, "render-%s-hero-glint.png" % mat), HERO)
        if frames_dir:
            for f in range(GLINT_FRAMES):
                set_glint(True, 2 * math.pi * f / GLINT_FRAMES)
                shot(os.path.join(frames_dir, "glint-%s-%02d.png" % (mat, f)), ICON, 360)
        print("voxels", mat, len(shape(mat)))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "pickaxe.blend"))


main()
