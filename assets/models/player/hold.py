# How the block body holds tools and blocks [владелец 26.10: «а теперь мне интересно как держатся инструменты и блоки в
# руках»]: the body posed with the game's own numbers — the hold pose (SwingAnimations.HOLD: shoulder 14° / 4°, elbow
# 22°, which CharacterAnimator folds into the shoulder on the block body), the grip (HeldItem.luau render: the C0 of
# tools and of blocks) and the item models (ItemModels.luau: the extruded sprites of Config/itemvoxels.json, a 1.2-stud
# cube for blocks; on the block body tools 2.38 studs, blocks 1.05 — Minecraft's held sizes) — with Roblox's CFrame maths, so the picture is what the game shows.
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/player/hold.py
#   → render-hold-<item>-{34,side}.png; [-- grip x y z pitch] tries another tool grip (studs, degrees).
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, HERE)
import player  # noqa: E402


# ---------------------------------------------------------------- Roblox CFrame maths
def matmul(a, b):
    return [[sum(a[i][k] * b[k][j] for k in range(3)) for j in range(3)] for i in range(3)]


def matvec(a, v):
    return [sum(a[i][k] * v[k] for k in range(3)) for i in range(3)]


class CF:
    def __init__(self, p=(0, 0, 0), r=None):
        self.p = list(p)
        self.r = r or [[1, 0, 0], [0, 1, 0], [0, 0, 1]]

    def __mul__(self, o):
        return CF([self.p[i] + matvec(self.r, o.p)[i] for i in range(3)], matmul(self.r, o.r))

    def inv(self):
        rt = [[self.r[j][i] for j in range(3)] for i in range(3)]
        return CF([-v for v in matvec(rt, self.p)], rt)

    def rot(self):
        return CF((0, 0, 0), self.r)

    def point(self, v):
        return [self.p[i] + matvec(self.r, v)[i] for i in range(3)]


def angles(rx, ry, rz):
    """CFrame.Angles: X · Y · Z."""
    cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
    X = [[1, 0, 0], [0, cx, -sx], [0, sx, cx]]
    Y = [[cy, 0, sy], [0, 1, 0], [-sy, 0, cy]]
    Z = [[cz, -sz, 0], [sz, cz, 0], [0, 0, 1]]
    return CF((0, 0, 0), matmul(matmul(X, Y), Z))


def rad(d):
    return math.radians(d)


# ---------------------------------------------------------------- the posed body
HOLD = {"RightShoulder": angles(rad(14), 0, rad(4)) * angles(rad(22), 0, 0)}  # the elbow folded into the shoulder


def posed_parts(body, transforms):
    """{part: CFrame} with each Motor6D's Transform: part1 = part0 · C0 · Transform · C1⁻¹."""
    px = body["px"]
    centre = {name: [v * px for v in p["pos"]] for name, p in body["parts"].items()}
    centre["HumanoidRootPart"] = [v * px for v in body["root"]["pos"]]
    cf = {"HumanoidRootPart": CF(centre["HumanoidRootPart"])}
    for name, p0, p1, pivot in body["joints"]:
        pv = [v * px for v in pivot]
        c0 = CF([pv[i] - centre[p0][i] for i in range(3)])
        c1 = CF([pv[i] - centre[p1][i] for i in range(3)])
        cf[p1] = cf[p0] * c0 * transforms.get(name, CF()) * c1.inv()
    return cf, centre


def body_boxes(body, colours, layers, cf, centre):
    """[(CFrame, size, hex)]: every part and its pixel plates, moved with its part."""
    out = []
    for name in body["parts"]:
        one = dict(body, parts={name: body["parts"][name]})
        for c, size, col in player.game_boxes(one, colours, layers):
            local = [c[i] - centre[name][i] for i in range(3)]
            out.append((cf[name] * CF(local), size, col))
    return out


# ---------------------------------------------------------------- the held item (HeldItem.MakeVisual / render)
def tool_grip(size, grip=None):
    x, y, z, pitch = grip or (0, 0.1, 0.05, -105)  # the block body's grip (R15 avatars: 0.3, −0.3, −0.2)
    return CF((x, y, z)) * angles(rad(pitch), 0, 0) * angles(0, math.pi, 0) * CF((0, size * 0.45, size * 0.45))


BLOCK_GRIP = CF((0, -0.62, -0.25)) * angles(0, rad(25), 0)  # R15 avatars: (0.2, −0.5, −0.9)
# held sizes [ваниль: third-person display scales — handheld tools 0.85 of a block, blocks 0.375; a block = 16 skin
# pixels]: tool sprite 0.85 · 16 · PX ≈ 2.38 studs (was 1.45), block 0.375 · 16 · PX ≈ 1.05 (was 1.2)
TOOL_SIZE = 0.85 * 16 * player.PX
BLOCK_SIZE = 0.375 * 16 * player.PX


def tool_boxes(voxels, size):
    """ItemModels.build: the sprite in the root's Y–Z plane (image up = +Y, image right = +Z), depth along X."""
    pixel = size / voxels["h"]
    depth = pixel * 1.2
    out = []
    r = voxels["r"]
    for i in range(0, len(r), 5):
        x, y, w, h, pi = r[i:i + 5]
        if voxels.get("mirror"):  # across the handle's diagonal (ItemModels.build)
            x, y, w, h = voxels["w"] - y - h, voxels["h"] - x - w, h, w
        cx = (x + w / 2 - voxels["w"] / 2) * pixel
        cy = (voxels["h"] / 2 - (y + h / 2)) * pixel
        out.append((CF((0, cy, cx)), [depth, h * pixel, w * pixel], "#" + voxels["p"][pi]))
    return out


def render(grip=None, tag="", block=None):
    import bmesh
    import bpy
    from mathutils import Vector

    sys.path.insert(0, os.path.dirname(HERE))
    from voxeltool import hexrgb, look, setup, srgb_to_linear

    body = player.load_body()
    with open(os.path.join(ROOT, "src", "shared", "Config", "itemvoxels.json"), encoding="utf-8") as f:
        voxels = json.load(f)["items"]
    cf, centre = posed_parts(body, HOLD)
    hand = cf["RightHand"]
    colours = player.check_colours(body, 1, 1)
    scene, cam = setup(700, 900)
    mats = {}

    def colour_mat(col):
        if col not in mats:
            m = bpy.data.materials.new(col)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = srgb_to_linear(hexrgb(col)) + (1,)
            bsdf.inputs["Roughness"].default_value = 1.0
            mats[col] = m
        return mats[col]

    def image_mat(path):
        if path not in mats:
            m = bpy.data.materials.new(os.path.basename(path))
            m.use_nodes = True
            nt = m.node_tree
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image, tex.interpolation = bpy.data.images.load(path), "Closest"
            nt.links.new(tex.outputs["Color"], nt.nodes["Principled BSDF"].inputs["Base Color"])
            mats[path] = m
        return mats[path]

    def add(boxes, texture=None):
        me = bpy.data.meshes.new("boxes")
        obj = bpy.data.objects.new("boxes", me)
        scene.collection.objects.link(obj)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new()
        index = {}
        quads = [((1, -1, -1), (1, 1, -1), (1, 1, 1), (1, -1, 1)), ((-1, -1, 1), (-1, 1, 1), (-1, 1, -1), (-1, -1, -1)),
                 ((-1, 1, -1), (-1, 1, 1), (1, 1, 1), (1, 1, -1)), ((-1, -1, 1), (-1, -1, -1), (1, -1, -1), (1, -1, 1)),
                 ((1, -1, 1), (1, 1, 1), (-1, 1, 1), (-1, -1, 1)), ((-1, -1, -1), (-1, 1, -1), (1, 1, -1), (1, -1, -1))]
        for frame, size, col in boxes:
            key = texture or col
            if key not in index:
                me.materials.append(image_mat(texture) if texture else colour_mat(col))
                index[key] = len(me.materials) - 1
            for q in quads:
                pts = [frame.point([s[i] * size[i] / 2 for i in range(3)]) for s in q]
                f = bm.faces.new([bm.verts.new((-p[0], p[2], p[1])) for p in pts])
                for loop, (u, v) in zip(f.loops, ((0, 0), (0, 1), (1, 1), (1, 0))):
                    loop[uv].uv = (u, v)
                f.material_index = index[key]
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
        bm.to_mesh(me)
        bm.free()

    items = [("pickaxe_iron", "tool"), ("sword_diamond", "tool"), ("axe_stone", "tool"), ("shovel_wood", "tool"), ("cobblestone", "block")]
    for item, kind in items:
        player.clear_meshes()
        add(body_boxes(body, colours, ["hair_short"], cf, centre))
        if kind == "tool":
            size = float(os.environ.get("TOOL_SIZE", TOOL_SIZE))
            root = hand * tool_grip(size, grip)
            add([(root * f, s, c) for f, s, c in tool_boxes(voxels[item], size)])
        else:
            bgrip = CF(block[:3]) * angles(0, rad(block[3]), 0) if block else BLOCK_GRIP
            bs = float(os.environ.get("BLOCK_SIZE", BLOCK_SIZE))
            bgrip = bgrip * CF((0, 0.6 - 0.025 - bs / 2, 0)) if not block else bgrip  # the block's top stays under the fist
            add([(hand * bgrip, [bs, bs, bs], None)], os.path.join(ROOT, "assets", "textures", "blocks", item + ".png"))
        # the side view looks along the arm: framed further forward so the bigger tools fit
        for view, loc, target, ortho in (("34", (-9, -11, 5.4), (-0.5, -0.5, 2.6), 6.2),
                                         ("side", (-14, -1.3, 2.4), (-0.5, -1.3, 2.4), 6.8)):
            look(cam, Vector(loc), Vector(target), ortho, None)
            scene.render.filepath = os.path.join(HERE, "render-hold-%s%s-%s.png" % (item, "-" + tag if tag else "", view))
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    grip = tuple(float(v) for v in argv[1:5]) if argv[:1] == ["grip"] else None
    block = tuple(float(v) for v in argv[1:5]) if argv[:1] == ["block"] else None
    render(grip, argv[5] if len(argv) > 5 else "", block)
