# Our armor for the block body [владелец 26.10: «броню сделаем по телу»; «броню также делаем новую в блендер. Кожаная
# броня, кольчужная, железная и алмазная»; «такое себе, слабо очень. Бери пример с майна»]. Made the way Minecraft makes
# it, with our own pixels: each piece is a box round a whole limb grown by 1 px on every side (leggings ½ px, the inner
# layer), textured per face on the limb's own pixel grid (head 8³, body 8×12×4, arms and legs 4×12×4) and transparent
# where the body shows. The look follows Minecraft's armor: a dark outline where the armor ends, light from the upper
# left, 4–6 shades of one colour with scattered off-tone pixels, plates split by darker grooves; the chainmail is a see-
# through mesh. The shapes are drawn below as shade maps (0 = outline … 5 = highlight, letters = accents, "." = open)
# and coloured per material; nothing is copied from a Minecraft or VoxeLibre texture.
# Material keys as in the game: wood = leather, stone = chain, iron, diamond.
#
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/armor/armor.py
#   → assets/armor/block/<piece>_<material>_<key>_<face>.png (the Decal images, ×8, faces named as Roblox's: right = +X,
#   the character's right), render-<material>-{front,34,back}.png on the body (boxes as ArmorVisual builds them),
#   armor-sheet.png (node tiling), armor.blend; the enchant glint [владелец 26.10: «не забывай за зачарования эффект»]:
#   assets/armor/block/glint/glint_<hash>.png — per face a white mask of the armor's own pixels with Minecraft-like
#   diagonal streaks (the game tints it purple and runs a shimmer down the body; equal masks shared), glint-map.json
#   (face image → mask), render-<material>-glint-{front,34}.png.
#   Upload the PNGs (Studio upload_image) → assets/armor/block/ids.json {"faces": {name: id}, "glints": {mask: id}} →
#   node scripts/build-configs.mjs → Config.armor.block / blockGlint; until then the block body wears the old VoxeLibre
#   faces and the old glint.
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
OUT = os.path.join(ROOT, "assets", "armor", "block")
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "player"))
import player  # noqa: E402

MATERIALS = ("wood", "stone", "iron", "diamond")
# shades 0 (outline) … 5 (highlight) and accents
PALETTES = {
    "wood": ["#3a2213", "#5b3920", "#744a2a", "#8d5b34", "#a7703f", "#c2874f"],
    "stone": ["#2b2e32", "#4b4f55", "#6b7077", "#8e939a", "#b2b6bc", "#d2d5d9"],
    "iron": ["#3e4144", "#6a6e72", "#8e9296", "#b3b7ba", "#d4d7d9", "#eff1f2"],
    "diamond": ["#0d4850", "#197784", "#25a0ab", "#3dc5cd", "#80e2e5", "#cbfbfb"],
}
ACCENTS = {
    "wood": {"a": "#2a180c", "b": "#dcc08b"},  # laces, stitches
    "stone": {"a": "#2b2e32", "b": "#d2d5d9"},
    "iron": {"a": "#55595d", "b": "#f7f8f8"},  # rivets, glints
    "diamond": {"a": "#0f5e67", "b": "#f4ffff"},  # the gem's setting, sparkles
}
SIZES = {"head": (8, 8, 8), "body": (8, 12, 4), "arm": (4, 12, 4), "leg": (4, 12, 4)}


def rows_of(text):
    return [list(line) for line in text.split()]


def blank(w, h):
    return [["."] * w for _ in range(h)]


def fill(grid, rows, start=0):
    """Puts shade rows into a grid from row `start`."""
    for i, row in enumerate(rows):
        grid[start + i] = list(row)
    return grid


# ---------------------------------------------------------------- shade maps. Every grid is seen from outside: column
# 0 on the viewer's left, row 0 at the top. Head and body sides are drawn as the RIGHT face (column 0 = the back) and
# mirrored for the left face; arms and legs get the same outer face on both sides (the inner one is never seen).
PLATE = {  # iron and diamond share the plate armor shapes
    "head": {
        "front": """
            45555543
            34444432
            21100112
            3......2
            3......2
            1......0
            ........
            ........""",
        "side": """
            45555554
            34444443
            34333332
            33133332
            23333322
            22222221
            1111000.
            0000....""",
        "back": """
            45555554
            34444443
            34333332
            33333332
            33333332
            23333322
            22222221
            00000000""",
        "top": """
            34444443
            45555554
            45444454
            45433454
            45433454
            45444454
            34444443
            23333332""",
    },
    "body": {
        "front": """
            45500554
            45555554
            34444443
            34414443
            33313332
            21111112
            34414443
            33313332
            21111112
            33333332
            00000000
            ........""",
        "back": """
            34444443
            45555554
            34444443
            33333332
            33333332
            21111112
            34444443
            33333332
            21111112
            33333332
            00000000
            ........""",
        "side": """
            4554
            4443
            3332
            3332
            3332
            2111
            3443
            3332
            2111
            3332
            0000
            ....""",
        "top": """
            34444443
            45555554
            45555554
            23333332""",
    },
    "arm": {
        "front": """
            4554
            4443
            3332
            3332
            2221
            0000""",
        "top": """
            4554
            5555
            4554
            3443""",
    },
    "legs_body": {  # the leggings' waist: rows 8–12 of the body
        "front": """
            344aa443
            21100112
            33313332
            33313332""",
        "back": """
            34444443
            21111112
            33333332
            33333332""",
        "side": """
            3443
            2111
            3332
            3332""",
    },
    "leg": {
        "front": """
            3443
            3332
            3332
            3332
            2221
            4554
            3443
            2221
            3332
            0000""",
        "back": """
            3443
            3332
            3332
            3332
            2221
            3332
            3332
            2221
            3332
            0000""",
    },
    "boots": {
        "front": """
            4554
            3443
            1111""",
        "back": """
            4554
            3332
            1111""",
        "bottom": """
            0110
            1221
            1221
            0110""",
    },
}

LEATHER = {
    "head": {
        "front": """
            45555554
            34444443
            1b1bb1b1
            2......2
            1......1
            ........
            ........
            ........""",
        "side": """
            45555554
            34444443
            33333332
            33333332
            33333332
            23333322
            1b1b1b1.
            ........""",
        "back": """
            45555554
            34444443
            33333332
            33333332
            33333332
            23333332
            1b1b1b1b
            ........""",
        "top": """
            34444443
            44555544
            45544554
            45444454
            45444454
            45544554
            34455443
            23333332""",
    },
    "body": {
        "front": """
            344..443
            3440 0443
            333a4333
            3334a332
            333a4332
            3334a332
            33333332
            33333332
            3b3b3b32
            11111111
            ........
            ........""",
        "back": """
            34444443
            44444443
            33333332
            33333332
            33333332
            33333332
            33333332
            33333332
            3b3b3b32
            11111111
            ........
            ........""",
        "side": """
            4443
            3332
            3332
            3332
            3332
            3332
            3332
            3332
            3b32
            1111
            ....
            ....""",
        "top": """
            34444443
            44555544
            44555544
            33333332""",
    },
    "arm": {
        "front": """
            4443
            3332
            3332
            b3b2
            1111""",
        "top": """
            4444
            4554
            4554
            3443""",
    },
    "legs_body": {
        "front": """
            1111a111
            33313332
            33313332
            33313332""",
        "back": """
            11111111
            33333332
            33333332
            33333332""",
        "side": """
            1111
            3332
            3332
            3332""",
    },
    "leg": {
        "front": """
            3443
            3332
            3332
            3332
            3332
            3332
            3332
            3332
            b3b2
            1111""",
        "back": """
            3443
            3332
            3332
            3332
            3332
            3332
            3332
            3332
            3b32
            1111""",
    },
    "boots": {
        "front": """
            4aa4
            3aa3
            1111""",
        "back": """
            4444
            3332
            1111""",
        "bottom": """
            0110
            1221
            1221
            0110""",
    },
}

CHAIN_HEAD = {  # the coif: round the face and under the chin
    "front": """
        45555554
        34444443
        3......3
        3......3
        3......3
        2......2
        2......2
        21111112""",
    "side": """
        45555554
        34444443
        33333333
        33333333
        33333333
        33333333
        23333332
        11111111""",
    "back": """
        45555554
        34444443
        33333333
        33333333
        33333333
        33333333
        23333332
        11111111""",
    "top": PLATE["head"]["top"],
}


def shapes(mat):
    if mat == "wood":
        return LEATHER
    if mat == "stone":
        out = dict(PLATE)
        out["head"] = CHAIN_HEAD
        return out
    return PLATE


def parse(text):
    return [row.replace(" ", "") for row in text.split("\n") if row.strip()]


def limb_faces(mat, piece):
    """{limb key: {face: shade grid}} for the piece; limb keys head, body, arm, leg; face grids at full limb size."""
    S = shapes(mat)
    out = {}

    def sides(part, size, start, src):
        """front/back/right/left/top/bottom grids of one limb from a shape group placed from row `start`."""
        w, h, d = size
        faces = {}
        front = parse(src["front"])
        faces["front"] = fill(blank(w, h), front, start)
        faces["back"] = fill(blank(w, h), parse(src.get("back", src["front"])), start)
        side = parse(src.get("side", src["front"]))
        faces["right"] = fill(blank(d, h), side, start)
        faces["left"] = fill(blank(d, h), [row[::-1] for row in side], start)
        faces["top"] = [list(r) for r in parse(src["top"])] if "top" in src else blank(w, d)
        faces["bottom"] = [list(r) for r in parse(src["bottom"])] if "bottom" in src else blank(w, d)
        if part in ("arm", "leg"):  # the outer face on both sides (the inner one is hidden in the body)
            faces["left"] = [row[::-1] for row in faces["right"]]
        return faces

    if piece == "helmet":
        out["head"] = sides("head", SIZES["head"], 0, S["head"])
    elif piece == "chestplate":
        out["body"] = sides("body", SIZES["body"], 0, S["body"])
        out["arm"] = sides("arm", SIZES["arm"], 0, S["arm"])
        if mat == "stone":  # chain sleeves down to the elbow
            out["arm"] = sides("arm", SIZES["arm"], 0, {**S["arm"], "front": "\n".join(["4554", "4443", "3332", "3332", "3332", "3332", "3332", "2221", "0000"])})
    elif piece == "leggings":
        out["body"] = sides("body", SIZES["body"], 8, S["legs_body"])
        out["leg"] = sides("leg", SIZES["leg"], 0, S["leg"])
    else:
        out["leg"] = sides("leg", SIZES["leg"], 9, S["boots"])
    return out


# ---------------------------------------------------------------- colouring
def hashed(*v):
    x = 2166136261
    for n in v:
        x = ((x ^ (n & 0xFFFF)) * 16777619) & 0xFFFFFFFF
    return x


def colour(mat, grid, face_id):
    """Shade grid → rows of hex (None = open): outline where the armor ends, scattered off-tone pixels, chain holes."""
    pal, acc = PALETTES[mat], ACCENTS[mat]
    h, w = len(grid), len(grid[0])
    out = [[None] * w for _ in range(h)]
    for r in range(h):
        for c in range(w):
            ch = grid[r][c]
            if ch == ".":
                continue
            if ch in acc:
                out[r][c] = acc[ch]
                continue
            level = int(ch)
            k = hashed(face_id, r, c)
            # Minecraft-like grain: one pixel in five a shade off (never on the outline or the highlight rim)
            if 1 <= level <= 4 and k % 5 == 0:
                level += 1 if (k >> 8) % 2 else -1
            if mat == "diamond" and level == 4 and k % 7 == 1:
                out[r][c] = acc["b"]  # a sparkle
                continue
            if mat == "stone" and 2 <= int(ch) <= 4:
                # the mesh: rows of rings (light / base) and between them dark links round open holes, a hole every
                # other pixel, the holes shifted by one on every link row
                if r % 2 == 0:
                    level = 4 if (c + r // 2) % 2 == 0 else 3
                elif (c + r // 2) % 2 == 1:
                    continue
                else:
                    level = 2
            out[r][c] = pal[max(0, min(5, level))]
    return out


# ---------------------------------------------------------------- the game's boxes (ArmorVisual.BLOCK_BOXES): key, limb, rows
KEYS = {
    "helmet": [("head", "head", 0, 8)],
    "chestplate": [("torsoupper", "body", 0, 8), ("torsolower", "body", 8, 12), ("upperarm", "arm", 0, 6), ("lowerarm", "arm", 6, 12)],
    "leggings": [("torso", "body", 6, 12), ("upperleg", "leg", 0, 6), ("lowerleg", "leg", 6, 12)],
    "boots": [("foot", "leg", 9, 12)],
}


def face_images(mat, piece):
    """{key: {face: rows of hex/None}} cut to each box's rows; ends only on the boxes at the limb's ends; empty faces
    left out."""
    limbs = limb_faces(mat, piece)
    out = {}
    for key, limb, r0, r1 in KEYS[piece]:
        length = SIZES[limb][1]
        faces = {}
        for face, grid in limbs[limb].items():
            if face in ("top", "bottom"):
                if (face == "top" and r0 != 0) or (face == "bottom" and r1 != length):
                    continue
                part = grid
            else:
                part = grid[r0:r1]
            img = colour(mat, part, hashed(len(piece), len(key), len(face), ord(face[0])))
            if any(v for row in img for v in row):
                faces[face] = img
        out[key] = faces
    return out


def save_png(path, img, scale=8):
    """A face image (rows of hex/None) upscaled ×scale as an RGBA PNG (no PIL in Blender's Python: zlib by hand)."""
    import struct
    import zlib

    h, w = len(img), len(img[0])
    raw = bytearray()
    for r in range(h * scale):
        raw.append(0)
        for c in range(w * scale):
            v = img[r // scale][c // scale]
            alpha = 255
            if isinstance(v, tuple):
                v, alpha = v
            if v:
                raw += bytes(int(v[i:i + 2], 16) for i in (1, 3, 5)) + bytes([alpha])
            else:
                raw += b"\x00\x00\x00\x00"

    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w * scale, h * scale, 8, 6, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)


def glint_mask(img):
    """The enchant glint of one face: white over the armor's pixels only, opaque on diagonal streaks, faint between."""
    return [[(("#ffffff", 230) if (c - r) % 8 in (0, 1) else ("#ffffff", 40)) if v else None for c, v in enumerate(row)]
            for r, row in enumerate(img)]


def write_images():
    import hashlib
    import json

    glint_dir = os.path.join(OUT, "glint")
    os.makedirs(glint_dir, exist_ok=True)
    for folder in (OUT, glint_dir):
        for name in os.listdir(folder):
            if name.endswith(".png"):
                os.remove(os.path.join(folder, name))
    n = 0
    glints = {}
    for mat in MATERIALS:
        for piece in KEYS:
            for key, faces in face_images(mat, piece).items():
                for face, img in faces.items():
                    name = "%s_%s_%s_%s" % (piece, mat, key, face)
                    save_png(os.path.join(OUT, name + ".png"), img)
                    mask = glint_mask(img)
                    tag = "glint_" + hashlib.md5(repr(mask).encode()).hexdigest()[:8]
                    if not os.path.exists(os.path.join(glint_dir, tag + ".png")):
                        save_png(os.path.join(glint_dir, tag + ".png"), mask)
                    glints[name] = tag
                    n += 1
    with open(os.path.join(OUT, "glint-map.json"), "w", encoding="utf-8") as f:
        json.dump({"_source": "assets/models/armor/armor.py: face image → its enchant glint mask (glint/<mask>.png)", "map": glints},
                  f, ensure_ascii=False, indent=1, sort_keys=True)
    print("armor faces written:", n, "glint masks:", len(set(glints.values())))


# ---------------------------------------------------------------- the boxes on the body, as ArmorVisual builds them
BOXES = {  # part, a0, a1 (rows of the limb the part holds), key, r0, r1, grow
    "helmet": [("Head", 0, 8, "head", 0, 8, 1)],
    "chestplate": [("UpperTorso", 0, 8, "torsoupper", 0, 8, 1), ("LowerTorso", 8, 12, "torsolower", 8, 12, 1)]
    + [(s + p, a0, a1, k, r0, r1, 1) for s in ("Right", "Left") for p, a0, a1, k, r0, r1 in (("UpperArm", 0, 6, "upperarm", 0, 6), ("LowerArm", 6, 10, "lowerarm", 6, 12))],
    "leggings": [("LowerTorso", 8, 12, "torso", 6, 12, 0.5)]
    + [(s + p, a0, a1, k, r0, r1, 0.5) for s in ("Right", "Left") for p, a0, a1, k, r0, r1 in (("UpperLeg", 0, 6, "upperleg", 0, 6), ("LowerLeg", 6, 10, "lowerleg", 6, 12))],
    "boots": [(s + "Foot", 10, 12, "foot", 9, 12, 1) for s in ("Right", "Left")],
}
LIMB_OF = {"head": "head", "torsoupper": "body", "torsolower": "body", "torso": "body", "upperarm": "arm", "lowerarm": "arm",
           "upperleg": "leg", "lowerleg": "leg", "foot": "leg"}


def render():
    import bmesh
    import bpy
    from mathutils import Vector

    sys.path.insert(0, os.path.dirname(HERE))
    from voxeltool import look, setup

    body = player.load_body()
    px = body["px"]
    scene, cam = setup(700, 900)
    mid = Vector((0, 0, 16 * player.PX))
    looks = {"wood": (1, 1), "stone": (0, 3), "iron": (2, 0), "diamond": (3, 5)}
    mats = {}

    def material(path):
        if path not in mats:
            img = bpy.data.images.load(path)
            m = bpy.data.materials.new(os.path.basename(path))
            m.use_nodes = True
            nt = m.node_tree
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image, tex.interpolation = img, "Closest"
            bsdf = nt.nodes["Principled BSDF"]
            nt.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            nt.links.new(tex.outputs["Alpha"], bsdf.inputs["Alpha"])
            bsdf.inputs["Roughness"].default_value = 0.9
            mats[path] = m
        return mats[path]

    glint_map = {}
    with open(os.path.join(OUT, "glint-map.json"), encoding="utf-8") as f:
        glint_map = __import__("json").load(f)["map"]

    def glint_material(path):
        key = "glint:" + path
        if key not in mats:
            img = bpy.data.images.load(path)
            m = bpy.data.materials.new(key)
            m.use_nodes = True
            nt = m.node_tree
            tex = nt.nodes.new("ShaderNodeTexImage")
            tex.image, tex.interpolation = img, "Closest"
            bsdf = nt.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = (0.55, 0.25, 1.0, 1)
            bsdf.inputs["Emission Color"].default_value = (0.6, 0.3, 1.0, 1)
            bsdf.inputs["Emission Strength"].default_value = 0.7
            mul = nt.nodes.new("ShaderNodeMath")
            mul.operation, mul.inputs[1].default_value = "MULTIPLY", 0.45
            nt.links.new(tex.outputs["Alpha"], mul.inputs[0])
            nt.links.new(mul.outputs[0], bsdf.inputs["Alpha"])
            mats[key] = m
        return mats[key]

    for mat, enchanted in [(m, False) for m in MATERIALS] + [(m, True) for m in MATERIALS]:
        player.clear_meshes()
        skin, hair = looks[mat]
        player.add_boxes(player.game_boxes(body, player.check_colours(body, skin, hair), ["hair_short"]), "player")
        me = bpy.data.meshes.new("armor")
        obj = bpy.data.objects.new("armor", me)
        scene.collection.objects.link(obj)
        bm = bmesh.new()
        uv = bm.loops.layers.uv.new()
        index = {}
        for piece, boxes in BOXES.items():
            for part, a0, a1, key, r0, r1, grow in boxes:
                width, length, depth = SIZES[LIMB_OF[key]]
                grown = length + 2 * grow
                top = (a0 + a1) / 2 + grow
                y0, y1 = top - grown * r0 / length, top - grown * r1 / length
                S = [(width + 2 * grow) * px, (y0 - y1) * px, (depth + 2 * grow) * px]
                pos = body["parts"][part]["pos"]
                centre = [pos[0] * px, pos[1] * px + (y0 + y1) / 2 * px, pos[2] * px]
                for face, (tl, right, down, _normal) in player.GAME_FACES.items():
                    path = os.path.join(OUT, "%s_%s_%s_%s.png" % (piece, mat, key, face))
                    if not os.path.exists(path):
                        continue
                    lr = sum(abs(right[i]) * S[i] for i in range(3))
                    ld = sum(abs(down[i]) * S[i] for i in range(3))

                    def corner(u, v):
                        p = [centre[i] + tl[i] * S[i] / 2 + right[i] * u * lr + down[i] * v * ld for i in range(3)]
                        return (-p[0], p[2], p[1])

                    f = bm.faces.new([bm.verts.new(corner(u, v)) for u, v in ((0, 0), (1, 0), (1, 1), (0, 1))])
                    for loop, (u, v) in zip(f.loops, ((0, 1), (1, 1), (1, 0), (0, 0))):
                        loop[uv].uv = (u, v)
                    if path not in index:
                        me.materials.append(material(path))
                        index[path] = len(me.materials) - 1
                    f.material_index = index[path]
                    if enchanted:
                        gpath = os.path.join(OUT, "glint", glint_map[os.path.basename(path)[:-4]] + ".png")
                        nrm = _normal
                        g = bm.faces.new([bm.verts.new(tuple(a + b for a, b in zip(corner(u, v), (-nrm[0] * 0.004, nrm[2] * 0.004, nrm[1] * 0.004))))
                                          for u, v in ((0, 0), (1, 0), (1, 1), (0, 1))])
                        for loop, (u, v) in zip(g.loops, ((0, 1), (1, 1), (1, 0), (0, 0))):
                            loop[uv].uv = (u, v)
                        if gpath not in index:
                            me.materials.append(glint_material(gpath))
                            index[gpath] = len(me.materials) - 1
                        g.material_index = index[gpath]
        bm.to_mesh(me)
        bm.free()
        for view, loc in (("front", (0, -20, 16 * player.PX)), ("34", (-11, -14, 16 * player.PX + 3.5)), ("back", (9, 17, 16 * player.PX + 2))):
            if enchanted and view == "back":
                continue
            look(cam, Vector(loc), mid, 6.6, None)
            scene.render.filepath = os.path.join(HERE, "render-%s%s-%s.png" % (mat, "-glint" if enchanted else "", view))
            bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "armor.blend"))


if __name__ == "__main__":
    write_images()
    if sys.argv[-1] != "images":
        render()
