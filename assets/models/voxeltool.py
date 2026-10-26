# The shared Blender pipeline for our voxel tools (pickaxe, sword …): a tool file only holds its palettes and a
# shape(material) -> {(x, y, z): hex} function and ends with run(...). One voxel = PX studs; the mesh is one cube per
# voxel with inner faces dropped, per-colour materials with a slight shade jitter, Eevee + Standard view (Workbench/AgX
# darken flat colours).
# The enchant glint: a purple tint plus two diagonal bands of light sliding along the model (one shared node group
# "Glint", its Phase/On values set per frame).
# Outputs next to the tool file: render-<material>-{icon,hero,icon-glint,hero-glint}.png and <name>.blend (the last
# material); with `-- frames <dir>`, GLINT_FRAMES icon frames of the glint per material (glint-<material>-NN.png) for
# the GIF (ffmpeg hstack of the four materials).
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Euler, Vector

PX = 0.25  # studs per voxel: 1/16 of a 4-stud tool
GLINT_FRAMES = 24


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))


def srgb_to_linear(c):
    return tuple(((v + 0.055) / 1.055) ** 2.4 if v > 0.04045 else v / 12.92 for v in c)


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


def run(here, name, materials, shape, icon, hero):
    """Render every material plain and with the glint; icon / hero = (rotation, camera location, ortho, lens)."""
    argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    frames_dir = argv[1] if len(argv) >= 2 and argv[0] == "frames" else None
    for mat in materials:
        vox = shape(mat)
        obj = build(vox, "%s_%s" % (name, mat))
        scene, cam = setup(900, 900)

        def shot(path, view, size=900):
            rot, loc, ortho, lens = view
            scene.render.resolution_x = scene.render.resolution_y = size
            obj.rotation_euler = Euler(rot, "XYZ")
            look(cam, Vector(loc), Vector((0, 0, 0)), ortho, lens)
            scene.render.filepath = path
            bpy.ops.render.render(write_still=True)

        set_glint(False)
        shot(os.path.join(here, "render-%s-icon.png" % mat), icon)
        shot(os.path.join(here, "render-%s-hero.png" % mat), hero)
        set_glint(True, 2.2)
        shot(os.path.join(here, "render-%s-icon-glint.png" % mat), icon)
        shot(os.path.join(here, "render-%s-hero-glint.png" % mat), hero)
        if frames_dir:
            for f in range(GLINT_FRAMES):
                set_glint(True, 2 * math.pi * f / GLINT_FRAMES)
                shot(os.path.join(frames_dir, "glint-%s-%02d.png" % (mat, f)), icon, 360)
        print("voxels", mat, len(vox))
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(here, "%s.blend" % name))
