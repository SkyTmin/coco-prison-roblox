# The rat mob, made in Blender [владелец 22.10: «сделай модельку крысы в блендере и анимации к ней, по фото от
# Codex, стиль — как в игре»; «чтобы было точь в точь»]. Reference: assets/models/rat/rat-reference.png (Codex
# image gen: side / front / top / three-quarter views on a 1536×1024 sheet).
#
#   blender -b -P assets/models/rat/rat.py -- build    → assets/models/rat/rat.blend (model + 5 actions)
#   blender -b assets/models/rat/rat.blend -P assets/models/rat/rat.py -- export
#                                                       → src/shared/Models/rat.json, fur-noise.png, previews
#   blender -b assets/models/rat/rat.blend -P assets/models/rat/rat.py -- compare
#                                                       → compare-views.png: the reference's four views, same
#                                                         cameras and scale (side and front 140 px a stud)
#
# The model is blocky like every mob of the game: boxes ("Part_*" meshes) hang on joints ("Joint_*" empties);
# the actions rotate / move the joints. Blender faces +Y, Z up; the export converts to Roblox (X, Y=Z, Z=-Y),
# so the rat faces −Z there. Sizes are in studs. Every box is measured off the reference side view (x px →
# Y = (400 − x) / 140, y px → Z = (445 − y) / 140) and the front / top views for the widths.
# The fur is a pixel texture: one grey noise tile (fur-noise.png, 16 texels over 2.25 studs ≈ the reference's
# grain), tinted per part; top faces of the back are darker like on the reference.
import bpy
import json
import math
import os
import random
import sys
from mathutils import Euler, Matrix, Vector

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
BLEND = os.path.join(HERE, "rat.blend")
JSON_OUT = os.path.join(ROOT, "src", "shared", "Models", "rat.json")
NOISE_OUT = os.path.join(HERE, "fur-noise.png")
FPS = 30
TILE_STUDS = 2.25  # one 16-texel noise tile covers this many studs
NOISE_TEXELS = 16

# albedo picked off the reference's lit faces
FUR = (0x91, 0x83, 0x7A)
FUR_BACK = (0x66, 0x5A, 0x53)  # the darker back (top faces)
FUR_MID = (0x6C, 0x60, 0x59)  # the upper sides of the back
FUR_DARK = (0x70, 0x63, 0x5C)  # legs
FUR_LIGHT = (0xC4, 0xB6, 0xAD)  # belly, chest, chin
PINK = (0xE8, 0x90, 0x8E)
PINK_LIGHT = (0xF2, 0xA6, 0xA2)
BLACK = (0x14, 0x12, 0x12)
WHITE = (0xF0, 0xEC, 0xE2)


def box(name, joint, x, y, z, colour, top=None, mirror=False):
    # a box from coordinate ranges (x0, x1), (y0, y1), (z0, z1); mirror → an L/R pair (x given for the left)
    out = []
    sides = [("L", 1), ("R", -1)] if mirror else [("", 1)]
    for suffix, s in sides:
        xs = sorted((x[0] * s, x[1] * s))
        j = joint.replace("*", suffix)
        out.append((name + suffix, j, ((xs[0] + xs[1]) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2),
                    (xs[1] - xs[0], y[1] - y[0], z[1] - z[0]), colour, top, (0, 0, 0)))
    return out


def turned(parts, pivot, yaw):
    # rotate a group of boxes about a vertical axis through pivot (the ears look forward and outward)
    out = []
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    for name, joint, centre, size, colour, top, rot in parts:
        dx, dy = centre[0] - pivot[0], centre[1] - pivot[1]
        out.append((name, joint, (pivot[0] + dx * c - dy * s, pivot[1] + dx * s + dy * c, centre[2]), size, colour,
                    top, (rot[0], rot[1], rot[2] + yaw)))
    return out


def ear(side):
    # a round pink plate (a pixel circle) with a lighter middle, turned a little outward (front and top views show them facing forward)
    x = (0.22, 0.78)
    parts = [
        *box("Ear" + side, "head", x, (1.0, 1.24), (1.67, 2.04), PINK),
        *box("EarTop" + side, "head", (0.32, 0.68), (1.0, 1.24), (2.04, 2.16), PINK),
        *box("EarLow" + side, "head", (0.32, 0.68), (1.0, 1.24), (1.56, 1.67), PINK),
        *box("EarIn" + side, "head", (0.34, 0.66), (1.24, 1.27), (1.72, 2.0), PINK_LIGHT),
    ]
    if side == "R":
        parts = [(n, j, (-c[0], c[1], c[2]), sz, col, t, r) for n, j, c, sz, col, t, r in parts]
    return turned(parts, (0.5 if side == "L" else -0.5, 1.12), -10 if side == "L" else 10)


# the tail: four pink segments stepping up and thinning (side view: 0.71 / 0.79 / 0.68 studs, the last two rising)
TAIL = [(0.74, 0.36, 4), (0.78, 0.32, 14), (0.68, 0.28, 38), (0.46, 0.24, 56)]  # length, thickness, pitch up°
TAIL_BASE = Vector((0, -1.66, 0.97))

JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 1.0)),
    ("head", "body", (0, 0.85, 1.2)),
    ("legFL", "body", (0.6, 0.88, 0.6)),
    ("legFR", "body", (-0.6, 0.88, 0.6)),
    ("legBL", "body", (0.64, -0.95, 0.6)),
    ("legBR", "body", (-0.64, -0.95, 0.6)),
]
PARTS = []
pivot = TAIL_BASE.copy()
for i, (length, thick, pitch) in enumerate(TAIL):
    name = "tail%d" % (i + 1)
    JOINTS.append((name, "body" if i == 0 else "tail%d" % i, tuple(pivot)))
    d = Vector((0, -math.cos(math.radians(pitch)), math.sin(math.radians(pitch))))
    centre = pivot + d * (length / 2)
    PARTS.append(("Tail%d" % (i + 1), name, tuple(centre), (thick, length + 0.04, thick), PINK, None,
                  (-pitch, 0, 0)))
    pivot = pivot + d * length

PARTS += [
    # body: a long block stepping up to the hump in the middle of the back, the rump rounding down
    *box("Body", "body", (-0.78, 0.78), (-0.7, 0.95), (0.36, 1.39), FUR),
    *box("Rump", "body", (-0.78, 0.78), (-1.71, -0.7), (0.52, 1.39), FUR, FUR_BACK),
    *box("Back1", "body", (-0.72, 0.72), (-1.43, 0.93), (1.39, 1.61), FUR, FUR_BACK),
    *box("Back2", "body", (-0.62, 0.62), (-1.14, 0.93), (1.61, 1.75), FUR_MID, FUR_BACK),
    *box("Back3", "body", (-0.48, 0.48), (-0.5, 0.57), (1.75, 1.89), FUR_BACK, FUR_BACK),
    *box("Haunch", "body", (0.75, 0.9), (-1.4, -0.48), (0.46, 1.16), FUR, FUR_BACK, mirror=True),
    *box("Shoulder", "body", (0.75, 0.84), (0.42, 1.0), (0.5, 1.02), FUR, FUR_BACK, mirror=True),
    # the light belly band along both sides and under the chest
    *box("Belly", "body", (-0.8, 0.8), (-0.7, 0.97), (0.34, 0.8), FUR_LIGHT),
    *box("BellyRear", "body", (-0.8, 0.8), (-1.66, -0.7), (0.5, 0.8), FUR_LIGHT),
    *box("Chest", "body", (-0.5, 0.5), (0.9, 1.44), (0.44, 0.86), FUR_LIGHT),
    # head: a box with a step on top, the snout in front, the pink nose and two teeth at its tip
    *box("Head", "head", (-0.64, 0.64), (0.72, 1.76), (0.8, 1.6), FUR, FUR_BACK),
    *box("HeadTop", "head", (-0.5, 0.5), (0.72, 1.6), (1.6, 1.68), FUR_BACK, FUR_BACK),
    *box("Muzzle", "head", (-0.43, 0.43), (1.74, 2.04), (0.8, 1.5), FUR, FUR_BACK),
    *box("Snout", "head", (-0.29, 0.29), (2.0, 2.5), (0.84, 1.42), FUR),
    *box("Chin", "head", (-0.42, 0.42), (1.2, 2.04), (0.6, 0.84), FUR_LIGHT),
    *box("Nose", "head", (-0.15, 0.15), (2.48, 2.72), (1.04, 1.34), PINK),
    *box("ToothL", "head", (0.01, 0.13), (2.42, 2.52), (0.7, 0.85), WHITE),
    *box("ToothR", "head", (-0.13, -0.01), (2.42, 2.52), (0.7, 0.85), WHITE),
    *box("Eye", "head", (0.5, 0.66), (1.6, 1.78), (1.14, 1.46), BLACK, mirror=True),  # wraps the corner: seen from the front and the side
    # ears: round pink plates standing on the back of the head
    *ear("L"),
    *ear("R"),
    # legs: short dark legs standing out of the body sides, big pink paws reaching forward
    *box("LegF", "legF*", (0.42, 0.78), (0.68, 1.08), (0.15, 0.62), FUR_DARK, mirror=True),
    *box("PawF", "legF*", (0.4, 0.8), (0.74, 1.3), (0.0, 0.18), PINK, mirror=True),
    *box("LegB", "legB*", (0.44, 0.84), (-1.24, -0.7), (0.14, 0.62), FUR_DARK, mirror=True),
    *box("PawB", "legB*", (0.42, 0.86), (-1.2, -0.6), (0.0, 0.16), PINK, mirror=True),
]


def srgb(c):
    # Blender colours are linear; the JSON keeps sRGB for Roblox
    return tuple(((v / 255) / 12.92) if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4 for v in c)


def noise_tile():
    # the fur grain: grey texels 0.7..1.0 with soft darker blotches, like the reference (its lum range is ±20 %)
    rnd = random.Random(7)
    n = NOISE_TEXELS
    blot = [[rnd.random() for _ in range(n // 4)] for _ in range(n // 4)]
    out = []
    for y in range(n):
        row = []
        for x in range(n):
            b = blot[y // 4][x // 4]
            v = 0.95 - 0.12 * b + rnd.uniform(-0.09, 0.06)
            row.append(max(0.7, min(1.0, v)))
        out.append(row)
    return out


# ------------------------------------------------------------------ the animations
# key(frame, {joint: (rx, ry, rz in degrees, optional (dx, dy, dz) offset)})
def deg(v):
    return math.radians(v)


def actions():
    acts = {}
    # idle: breathing, sniffing, a lazy tail sway (2 s loop)
    idle = []
    for f in range(0, 61, 5):
        t = f / 60 * math.pi * 2
        idle.append((f, {
            "body": (0, 0, 0, (0, 0, 0.03 * math.sin(t))),
            "head": (6 * max(0, math.sin(t * 3)) - 2, 0, 4 * math.sin(t), None),
            "tail1": (0, 0, 8 * math.sin(t), None),
            "tail2": (0, 0, 10 * math.sin(t - 0.6), None),
            "tail3": (0, 0, 12 * math.sin(t - 1.2), None),
            "tail4": (4 * math.sin(t), 0, 14 * math.sin(t - 1.8), None),
        }))
    acts["idle"] = (idle, True)
    # walk / run: diagonal legs together, the body bobs, the tail waves (16 frames ≈ 0.53 s at 13 studs/s)
    walk = []
    for f in range(0, 17, 2):
        t = f / 16 * math.pi * 2
        s = math.sin(t)
        walk.append((f, {
            "body": (2 * math.sin(t * 2), 0, 0, (0, 0, 0.09 * abs(math.sin(t)))),
            "head": (-3 * math.sin(t * 2), 0, 0, None),
            "legFL": (38 * s, 0, 0, None),
            "legBR": (38 * s, 0, 0, None),
            "legFR": (-38 * s, 0, 0, None),
            "legBL": (-38 * s, 0, 0, None),
            "tail1": (-4, 0, 12 * math.sin(t), None),
            "tail2": (0, 0, 14 * math.sin(t - 0.8), None),
            "tail3": (0, 0, 16 * math.sin(t - 1.6), None),
            "tail4": (4, 0, 18 * math.sin(t - 2.4), None),
        }))
    acts["walk"] = (walk, True)
    # bite: rear up with the front paws raised (the wind-up the player sees), then a lunge with the head down
    # (12 frames = 0.4 s). Signs: +X turns the nose up, the legs forward, the tail down.
    acts["bite"] = ([
        (0, {}),
        (7, {"body": (22, 0, 0, (0, -0.2, 0.15)), "head": (14, 0, 0, None), "legFL": (45, 0, 0, None),
             "legFR": (45, 0, 0, None), "legBL": (-15, 0, 0, None), "legBR": (-15, 0, 0, None),
             "tail1": (-18, 0, 0, None)}),
        (9, {"body": (-12, 0, 0, (0, 0.55, 0)), "head": (-24, 0, 0, None), "legFL": (30, 0, 0, None),
             "legFR": (30, 0, 0, None), "legBL": (-25, 0, 0, None), "legBR": (-25, 0, 0, None),
             "tail1": (10, 0, 0, None)}),
        (12, {}),
    ], False)
    # hurt: a flinch back with the head thrown up and the tail stiff (8 frames ≈ 0.27 s)
    acts["hurt"] = ([
        (0, {}),
        (2, {"body": (12, 0, 6, (0, -0.35, 0.1)), "head": (20, 0, 0, None), "tail1": (-25, 0, 0, None),
             "tail2": (-15, 0, 0, None)}),
        (8, {}),
    ], False)
    # death: rolls onto its side, the legs stick out, the tail droops (20 frames, holds the last pose)
    acts["death"] = ([
        (0, {}),
        (6, {"root": (0, -40, 0, (0, 0, 0.25)), "head": (-10, 0, 0, None)}),
        (14, {"root": (0, -92, 0, (0, 0, 0.8)), "legFL": (0, 0, 25, None), "legFR": (0, 0, -25, None),
              "legBL": (0, 0, 25, None), "legBR": (0, 0, -25, None), "head": (10, 0, 15, None),
              "tail1": (-10, 0, 20, None), "tail2": (-10, 0, 15, None)}),
        (20, {"root": (0, -90, 0, (0, 0, 0.8)), "legFL": (0, 0, 30, None), "legFR": (0, 0, -30, None),
              "legBL": (0, 0, 30, None), "legBR": (0, 0, -30, None), "head": (8, 0, 15, None),
              "tail1": (-15, 0, 20, None), "tail2": (-15, 0, 18, None)}),
    ], False)
    return acts


# ------------------------------------------------------------------ build
def tile_mean(tile):
    return sum(sum(r) for r in tile) / (len(tile) * len(tile[0]))


def fur_image(colour, tile):
    # the noise tile tinted with one colour (for the Blender look; Roblox tints the grey tile itself)
    key = "Fur_%02x%02x%02x" % colour
    img = bpy.data.images.get(key)
    if img:
        return img
    n = NOISE_TEXELS
    img = bpy.data.images.new(key, n, n)
    rgb = [c / 255 for c in colour]  # the image is sRGB: store sRGB values
    px = []
    for y in range(n):
        for x in range(n):
            v = tile[y][x] / tile_mean(tile)
            px += [min(1.0, c * v) for c in rgb] + [1.0]
    img.pixels = px
    img.pack()
    return img


def material(colour, tile, mats):
    if colour in mats:
        return mats[colour]
    m = bpy.data.materials.new("Mat_%02x%02x%02x" % colour)
    m.diffuse_color = srgb(colour) + (1.0,)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    bsdf = nodes.get("Principled BSDF")
    tex = nodes.new("ShaderNodeTexImage")
    tex.image = fur_image(colour, tile)
    tex.interpolation = "Closest"
    m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
    nodes.active = tex
    mats[colour] = m
    return m


def uv_boxes(cube, offset):
    # every face gets texels of the same size in studs (TILE_STUDS a tile), shifted per part
    me = cube.data
    uv = me.uv_layers.active or me.uv_layers.new()
    for poly in me.polygons:
        nrm = poly.normal
        axis = max(range(3), key=lambda a: abs(nrm[a]))
        a, b = [(1, 2), (0, 2), (0, 1)][axis]
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co + cube.location
            uv.data[li].uv = ((co[a] + offset) / TILE_STUDS, (co[b] + offset * 0.7) / TILE_STUDS)


def build():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    tile = noise_tile()
    joints = {}
    for name, parent, pv in JOINTS:
        e = bpy.data.objects.new("Joint_" + name, None)
        e.empty_display_type = "SPHERE"
        e.empty_display_size = 0.15
        e.rotation_mode = "XYZ"
        scene.collection.objects.link(e)
        if parent:
            e.parent = joints[parent]
            e.location = Vector(pv) - Vector(dict((n, p) for n, _, p in JOINTS)[parent])
        else:
            e.location = Vector(pv)
        e["pivot"] = list(pv)
        joints[name] = e
    pivots = {n: Vector(p) for n, _, p in JOINTS}
    mats = {}
    rnd = random.Random(3)
    for name, joint, centre, size, colour, top, rot in PARTS:
        bpy.ops.mesh.primitive_cube_add(size=1)
        cube = bpy.context.active_object
        cube.name = "Part_" + name
        cube.scale = size
        bpy.ops.object.transform_apply(scale=True)
        cube.parent = joints[joint]
        cube.location = Vector(centre) - pivots[joint]
        cube.rotation_euler = Euler([deg(v) for v in rot], "XYZ")
        cube.data.materials.append(material(colour, tile, mats))
        if top and top != colour:
            cube.data.materials.append(material(top, tile, mats))
            for poly in cube.data.polygons:
                if poly.normal.z > 0.9:
                    poly.material_index = 1
        uv_boxes(cube, rnd.uniform(0, TILE_STUDS))
        cube["colour"] = list(colour)
        if top:
            cube["top"] = list(top)
    # actions on the joints (one action per joint per clip)
    for clip, (keys, loop) in actions().items():
        for name, _, _ in JOINTS:
            e = joints[name]
            act = bpy.data.actions.new("%s|%s" % (clip, name))
            act["loop"] = loop
            act.use_fake_user = True  # unassigned actions are not saved otherwise
            act["frames"] = [frame for frame, _ in keys]
            use(e, act)
            base = e.location.copy()
            for frame, pose in keys:
                rx, ry, rz, off = pose.get(name, (0, 0, 0, None))
                e.rotation_euler = Euler((deg(rx), deg(ry), deg(rz)), "XYZ")
                e.location = base + Vector(off or (0, 0, 0))
                e.keyframe_insert("rotation_euler", frame=frame)
                e.keyframe_insert("location", frame=frame)
            e.location = base
            e.rotation_euler = Euler((0, 0, 0), "XYZ")
            e.animation_data.action = None
    # leave the rest pose on for viewing the .blend (idle is one click away in the action editor)
    scene.frame_end = 60
    bpy.ops.wm.save_as_mainfile(filepath=BLEND)
    print("[rat] built", BLEND, len(PARTS), "parts")


def use(e, act):
    # assign an action and its (only) slot — Blender 5 needs the slot for the curves to play
    e.animation_data_create()
    e.animation_data.action = act
    if act is not None and len(act.slots) > 0 and e.animation_data.action_slot is None:
        e.animation_data.action_slot = act.slots[0]


# ------------------------------------------------------------------ export
P = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))  # Blender → Roblox basis


def to_roblox_vec(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def to_roblox_quat(euler):
    m = P @ euler.to_matrix() @ P.transposed()
    q = m.to_quaternion()
    return [round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)]


def save_noise():
    # the grey tile for Roblox, ×8 nearest so the texels stay crisp after Roblox's filtering
    tile = noise_tile()
    n, k = NOISE_TEXELS, 8
    img = bpy.data.images.new("FurNoiseOut", n * k, n * k)
    img.colorspace_settings.name = "Non-Color"  # store the values as they are (before filling: it resets the buffer)
    px = []
    for y in range(n * k):
        for x in range(n * k):
            v = tile[y // k][x // k]
            px += [v, v, v, 1.0]
    img.pixels.foreach_set(px)
    img.update()
    img.save(filepath=NOISE_OUT)


def export():
    scene = bpy.context.scene
    joints = {o.name[6:]: o for o in bpy.data.objects if o.name.startswith("Joint_")}
    out = {"_source": "assets/models/rat/rat.blend (Blender, made by rat.py; reference rat-reference.png by Codex) [владелец 22.10]",
           "fps": FPS, "texture": {"studsPerTile": TILE_STUDS, "mean": round(tile_mean(noise_tile()), 4),
                                        # Roblox's cool sky light greys the low-saturation fur: the game lifts it
                                        "saturate": 1.6, "gain": 1.1}, "joints": [], "parts": [], "clips": {}}
    order = [n for n, _, _ in JOINTS if n in joints]
    for name in order:
        e = joints[name]
        parent = e.parent.name[6:] if e.parent else None
        out["joints"].append({"name": name, "parent": parent, "pivot": to_roblox_vec(Vector(e["pivot"]))})
    for o in bpy.data.objects:
        if o.name.startswith("Part_") and o.type == "MESH":
            joint = o.parent.name[6:]
            centre = Vector(joints[joint]["pivot"]) + o.location
            dims = o.dimensions
            part = {"name": o.name[5:], "joint": joint, "centre": to_roblox_vec(centre),
                    "size": [round(dims.x, 4), round(dims.z, 4), round(dims.y, 4)],
                    "colour": list(o["colour"])}
            if "top" in o:
                part["top"] = list(o["top"])
            if any(abs(v) > 1e-6 for v in o.rotation_euler):
                part["rot"] = to_roblox_quat(o.rotation_euler)
            out["parts"].append(part)
    clips = sorted({a.name.split("|")[0] for a in bpy.data.actions if "|" in a.name})
    for clip in clips:
        frames = set()
        loop = False
        for name in order:
            act = bpy.data.actions.get("%s|%s" % (clip, name))
            if act:
                loop = bool(act.get("loop", False))
                frames.update(int(f) for f in act["frames"])  # Blender 5 actions are layered: no act.fcurves
        frames = sorted(frames)
        tracks = {}
        for name in order:
            e = joints[name]
            act = bpy.data.actions.get("%s|%s" % (clip, name))
            if not act:
                continue
            use(e, act)
            keys = []
            for f in frames:
                scene.frame_set(f)
                rest = Vector(e["pivot"]) - (Vector(e.parent["pivot"]) if e.parent else Vector((0, 0, 0)))
                offset = e.location - rest
                keys.append({"t": round(f / FPS, 4), "q": to_roblox_quat(e.rotation_euler), "p": to_roblox_vec(offset)})
            # drop tracks that never move
            if any(abs(k["q"][0]) + abs(k["q"][1]) + abs(k["q"][2]) > 1e-4 or any(abs(v) > 1e-4 for v in k["p"]) for k in keys):
                tracks[name] = keys
        out["clips"][clip] = {"length": round(frames[-1] / FPS, 4), "loop": loop, "tracks": tracks}
    os.makedirs(os.path.dirname(JSON_OUT), exist_ok=True)
    with open(JSON_OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    save_noise()
    print("[rat] exported", JSON_OUT, len(out["parts"]), "parts", list(out["clips"].keys()))
    render_previews(joints, order)


# ------------------------------------------------------------------ renders
def setup_render(w, h):
    # Eevee with a soft studio set like the reference sheet: grey sky light all round + a key light from the
    # upper front-left, soft shadows; the textures stay pixel-sharp (Closest)
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x, scene.render.resolution_y = w, h
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = False
    scene.view_settings.view_transform = "Standard"  # AgX darkens flat colours
    scene.view_settings.exposure = 0.0
    world = scene.world or bpy.data.worlds.new("W")
    scene.world = world
    world.use_nodes = True
    bg = world.node_tree.nodes.get("Background")
    bg.inputs["Color"].default_value = srgb((0xB2, 0xB2, 0xB2)) + (1.0,)
    bg.inputs["Strength"].default_value = 1.0
    sun = bpy.data.objects.get("KeyLight")
    if not sun:
        sun = bpy.data.objects.new("KeyLight", bpy.data.lights.new("KeyLight", "SUN"))
        scene.collection.objects.link(sun)
    sun.data.energy = 1.6
    sun.data.angle = math.radians(25)
    sun.rotation_euler = Euler((math.radians(45), 0, math.radians(-120)), "XYZ")
    for m in bpy.data.materials:
        bsdf = m.node_tree.nodes.get("Principled BSDF") if m.use_nodes else None
        if bsdf:
            bsdf.inputs["Roughness"].default_value = 1.0
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.0
    cam = bpy.data.objects.get("PreviewCam")
    if not cam:
        cam = bpy.data.objects.new("PreviewCam", bpy.data.cameras.new("PreviewCam"))
        scene.collection.objects.link(cam)
    scene.camera = cam
    return scene, cam


def ortho(cam, right, up, centre, scale):
    # a camera whose screen right / up are the given world axes, looking at centre from 30 studs away
    r, u = Vector(right), Vector(up)
    back = r.cross(u)
    m = Matrix((r, u, back)).transposed().to_4x4()
    m.translation = Vector(centre) + back * 30
    cam.matrix_world = m
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    cam.data.clip_end = 100


def pose(joints, order, clip, frame):
    for name in order:
        use(joints[name], bpy.data.actions.get("%s|%s" % (clip, name)) if clip else None)
        if not clip:
            joints[name].rotation_euler = Euler((0, 0, 0), "XYZ")
            rest = Vector(joints[name]["pivot"]) - (Vector(joints[name].parent["pivot"]) if joints[name].parent else Vector())
            joints[name].location = rest
    bpy.context.scene.frame_set(frame)


def render_previews(joints, order):
    scene, cam = setup_render(900, 600)
    cam.data.type = "PERSP"
    cam.data.lens = 45
    cam.location = (-7.5, 4.6, 4.2)
    direction = Vector((0, -0.3, 0.9)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    for clip, frame in (("idle", 0), ("walk", 4), ("bite", 7), ("death", 20)):
        pose(joints, order, clip, frame)
        scene.render.filepath = os.path.join(HERE, "preview-%s.png" % clip)
        bpy.ops.render.render(write_still=True)
    print("[rat] previews rendered")


def compare():
    # the reference sheet's four 768×512 panels: side (nose left, 140 px a stud, x 400 ↔ Y 0, y 445 ↔ ground),
    # front (centre x 1220 → panel x 452), top (125 px a stud, nose tip at x 20, centre line y 730 → 218),
    # three-quarter (front-left, perspective)
    joints = {o.name[6:]: o for o in bpy.data.objects if o.name.startswith("Joint_")}
    order = [n for n, _, _ in JOINTS if n in joints]
    pose(joints, order, None, 0)
    scene, cam = setup_render(768, 512)
    views = {
        "side": ((0, -1, 0), (0, 0, 1), (0, 16 / 140, (445 - 256) / 140), 768 / 140),
        "front": ((-1, 0, 0), (0, 0, 1), (68 / 140, 0, (445 - 256) / 140), 768 / 140),
        "top": ((0, -1, 0), (1, 0, 0), (-38 / 125, 2.72 - (384 - 20) / 125, 0), 768 / 125),
    }
    for name, (right, up, centre, scale) in views.items():
        ortho(cam, right, up, centre, scale)
        scene.render.filepath = os.path.join(HERE, "compare-%s.png" % name)
        bpy.ops.render.render(write_still=True)
    cam.data.type = "PERSP"
    cam.data.lens = 56
    cam.location = (-6.6, 6.0, 4.6)
    direction = Vector((0, -0.7, 0.75)) - cam.location
    cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(HERE, "compare-34.png")
    bpy.ops.render.render(write_still=True)
    print("[rat] compare views rendered")


mode = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "build"
if mode == "build":
    build()
elif mode == "export":
    export()
elif mode == "compare":
    compare()
