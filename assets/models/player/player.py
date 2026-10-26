# Our player body [владелец 26.10: «выключить модельки тела у игрока и сделать свои… похожие как у Майна у всех
# игроков»; «своя тюремная форма»; «делай лучше тело, броню сделаем по телу в будущем; всё в блендере»].
# A Minecraft-proportioned block body (head 8³, body 8×12×4, arms and legs 4×12×4 pixels; 1 px = PX studs) in our own
# prison uniform: an orange jumpsuit with a collar, a zip, a number patch on the chest and the back, rolled cuffs, boots;
# a face with brows, eyes, nose and mouth. Per player: skin tone, hair colour, hairstyle (short / buzz / fringe /
# bald), eye colour, sometimes a beard, and a faction armband on the left arm. Every pixel is ours.
# Colours are ROLES (suit, skin, hair…): the game picks the player's colours (src/server/Services/AvatarService.luau).
#
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/player/player.py
#   → render-<variant>-{front,back,34}.png, player.blend;
# "… -- export" → src/shared/Models/player.json: the R15 rig (parts, sizes, positions, joint pivots) and, per part and
#   face, the pixel rectangles of each role over the part's base colour; layers (hairstyles, beard, armband) the same
#   way; the palettes;
# "… -- check" → render-check-{front,34}.png: the body built from player.json the way AvatarService.luau builds it in
#   the game (parts, the layers merged per face, greedy plates) — the export and the game's face geometry checked.
#
# Space: Roblox axes in pixels — X = the character's right, Y = up from the ground, Z = back (the face looks to −Z).
# Face grids (rows top → bottom, columns left → right as you look at the face): front tl (+X, +Y, −Z) → −X;
# back tl (−X, +Y, +Z) → +X; right (+X side) tl (+X, +Y, +Z) → −Z; left (−X side) tl (−X, +Y, −Z) → +Z;
# top tl (+X, +Y, +Z) → −X, rows → −Z; bottom tl (+X, −Y, −Z) → −X, rows → +Z.
import json
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
PX = 0.175  # studs per pixel: the body is 32 px = 5.6 studs tall

# ---------------------------------------------------------------- palettes (fixed roles and per-player choices)
FIXED = {
    "suit": "#e07b22",
    "suit_dark": "#b25c14",
    "suit_hi": "#ef9a4a",
    "patch": "#ece8dc",
    "ink": "#2b2b2b",
    "boot": "#3b322b",
    "boot_hi": "#5d4e41",
    "boot_sole": "#221c18",
    "eye_white": "#f4f4f4",
}
# skin tones with their shade (nose, chin) and lips, index-aligned
SKIN = ["#f2c9a6", "#e3b08a", "#c98e66", "#9a6544", "#6b432a"]
SKIN_DARK = ["#ddb08c", "#cc9772", "#b07651", "#82533a", "#573522"]
MOUTH = ["#b9786a", "#a86b5b", "#8f5444", "#6e3e2e", "#4a2a1d"]
HAIR = ["#2a1c13", "#5b3a21", "#b98a45", "#9a4a22", "#8d8d8d", "#161616"]
HAIR_DARK = ["#1c120c", "#432a17", "#8f6a33", "#743718", "#6c6c6c", "#0b0b0b"]
IRIS = ["#3a6fd8", "#5a3a1f", "#3f8f4a", "#6b6b6b"]
STYLES = ["short", "buzz", "fringe", "bald"]

# full limbs: centre (X, Y, Z) and size (x, y, z) in px
LIMBS = {
    "head": ((0, 28, 0), (8, 8, 8)),
    "body": ((0, 18, 0), (8, 12, 4)),
    "rarm": ((6, 18, 0), (4, 12, 4)),
    "larm": ((-6, 18, 0), (4, 12, 4)),
    "rleg": ((2, 6, 0), (4, 12, 4)),
    "lleg": ((-2, 6, 0), (4, 12, 4)),
}
FACES = ("front", "back", "right", "left", "top", "bottom")


def dims(size, face):
    sx, sy, sz = size
    return {"front": (sx, sy), "back": (sx, sy), "right": (sz, sy), "left": (sz, sy), "top": (sx, sz), "bottom": (sx, sz)}[face]


def grid(w, h, role):
    return [[role] * w for _ in range(h)]


# ---------------------------------------------------------------- the base skin
def paint_base():
    out = {}
    for limb, (_, size) in LIMBS.items():
        out[limb] = {f: grid(*dims(size, f), "skin" if limb == "head" else "suit") for f in FACES}
    # the face: brows, eyes (white outside, iris inside — as Minecraft draws them), nose, mouth
    f = out["head"]["front"]
    for c in (1, 2, 5, 6):
        f[3][c] = "brow"
    f[4][1], f[4][2], f[4][5], f[4][6] = "eye_white", "iris", "iris", "eye_white"
    f[5][3] = f[5][4] = "skin_dark"
    f[6][3] = f[6][4] = "mouth"
    # the jumpsuit body
    b = out["body"]
    fr = b["front"]
    fr[0][2], fr[0][3], fr[0][4], fr[0][5] = "suit_dark", "skin", "skin", "suit_dark"  # the open collar
    fr[1][3] = fr[1][4] = "suit_dark"
    for r in range(2, 8):
        fr[r][3] = "suit_dark"  # the zip
    for c in (5, 6, 7):
        fr[2][c] = "patch"  # the number patch on the left chest (viewer's right)
    fr[3][5], fr[3][6], fr[3][7] = "ink", "patch", "ink"
    fr[1][1] = fr[1][6] = "suit_hi"  # light on the shoulders
    for c in range(8):
        fr[8][c] = "suit_dark"  # the waist seam
    bk = b["back"]
    for r in range(2, 6):
        for c in range(2, 6):
            bk[r][c] = "patch"  # the big number on the back
    bk[3][2], bk[3][4], bk[3][5], bk[4][2], bk[4][3], bk[4][5] = ("ink",) * 6
    for c in range(8):
        bk[8][c] = "suit_dark"
    for side in ("right", "left"):
        for c in range(4):
            b[side][8][c] = "suit_dark"
    tp = b["top"]
    tp[1][3] = tp[1][4] = tp[2][3] = tp[2][4] = "skin"  # the neck
    # sleeves to the elbow with a rolled cuff, then the forearm and the hand
    for arm in ("rarm", "larm"):
        for face in ("front", "back", "right", "left"):
            g = out[arm][face]
            for r in range(12):
                for c in range(4):
                    g[r][c] = "suit" if r < 5 else "suit_dark" if r == 5 else "skin"
        out[arm]["bottom"] = grid(4, 4, "skin")
    # trousers with a rolled hem, boots with laces and soles
    for leg in ("rleg", "lleg"):
        for face in ("front", "back", "right", "left"):
            g = out[leg][face]
            for r in range(12):
                for c in range(4):
                    g[r][c] = "suit" if r < 8 else "suit_dark" if r == 8 else "boot"
        out[leg]["front"][9][1] = out[leg]["front"][9][2] = "boot_hi"
        # the inner side of each leg a shade darker, so the two legs read apart (front: col 3 of the right leg, col 0 of
        # the left; back: mirrored)
        inner_front, inner_back = (3, 0) if leg == "rleg" else (0, 3)
        for r in range(8):
            out[leg]["front"][r][inner_front] = "suit_dark"
            out[leg]["back"][r][inner_back] = "suit_dark"
        out[leg]["bottom"] = grid(4, 4, "boot_sole")
    return out


# ---------------------------------------------------------------- layers: {limb: {face: {(col, row): role}}}
def side_cols(face, front_half):
    """Columns of a 8-wide head side nearer the face (front_half) or the back: right side col 0 = back, left col 0 = front."""
    near_front = range(4, 8) if face == "right" else range(0, 4)
    return near_front if front_half else [c for c in range(8) if c not in near_front]


def hair_layer(style):
    if style == "bald":
        return {}
    layer = {"top": {}, "front": {}, "back": {}, "right": {}, "left": {}}
    dark = "hair_dark"

    def put(face, c, r, role="hair"):
        layer[face][(c, r)] = role

    for c in range(8):
        for r in range(8):
            put("top", c, r, dark if style == "buzz" else "hair")
    if style == "short":
        for c in range(8):
            put("front", c, 0)
        put("front", 0, 1)
        put("front", 7, 1)
        for face in ("right", "left"):
            for c in range(8):
                put(face, c, 0)
                put(face, c, 1)
            for c in side_cols(face, False):
                put(face, c, 2)
        for c in range(8):
            for r in range(4):
                put("back", c, r)
            if 1 <= c <= 6:
                put("back", c, 4, dark)
    elif style == "buzz":
        for c in range(1, 7):
            put("front", c, 0, dark)
        for face in ("right", "left"):
            for c in range(8):
                put(face, c, 0, dark)
        for c in range(8):
            put("back", c, 0, dark)
            put("back", c, 1, dark)
    elif style == "fringe":
        for c in range(8):
            put("front", c, 0)
            put("front", c, 1)
        for c in range(4):
            put("front", c, 2)  # swept to the character's right
        put("front", 0, 3)
        for face in ("right", "left"):
            for c in range(8):
                for r in range(4):
                    put(face, c, r)
            for c in side_cols(face, False):
                put(face, c, 4)
                put(face, c, 5, dark)
        for c in range(8):
            for r in range(7):
                put("back", c, r, dark if r == 6 else "hair")
    return {"head": layer}


def beard_layer():
    front = {}
    for c in range(8):
        if c not in (3, 4):
            front[(c, 6)] = "hair"
        front[(c, 7)] = "hair"
    sides = {}
    for face in ("right", "left"):
        sides[face] = {(c, r): "hair" for c in side_cols(face, True) for r in (5, 6, 7)}
    return {"head": {"front": front, **sides}}


def armband_layer():
    """The faction armband on the left arm, rows 2–3 all round (the game shows it only in a faction)."""
    return {"larm": {face: {(c, r): "faction" for c in range(4) for r in (2, 3)} for face in ("front", "back", "right", "left")}}


LAYERS = {"hair_" + s: hair_layer(s) for s in STYLES if s != "bald"}
LAYERS["beard"] = beard_layer()
LAYERS["armband"] = armband_layer()


# ---------------------------------------------------------------- one player's look
def variant(skin, hair, style, iris, beard, faction=None):
    colours = dict(FIXED)
    colours.update(
        skin=SKIN[skin], skin_dark=SKIN_DARK[skin], mouth=MOUTH[skin],
        hair=HAIR[hair], hair_dark=HAIR_DARK[hair], brow=HAIR_DARK[hair], iris=IRIS[iris],
        faction=faction or "#000000",
    )
    grids = paint_base()
    layers = [] if style == "bald" else ["hair_" + style]
    if beard:
        layers.append("beard")
    if faction:
        layers.append("armband")
    for name in layers:
        for limb, faces in LAYERS[name].items():
            for face, pixels in faces.items():
                for (c, r), role in pixels.items():
                    grids[limb][face][r][c] = role
    return {limb: {face: [[colours[role] for role in row] for row in g] for face, g in faces.items()} for limb, faces in grids.items()}


FACE_BASIS = {  # tl corner as signs of the half size, right and down unit vectors
    "front": ((1, 1, -1), (-1, 0, 0), (0, -1, 0)),
    "back": ((-1, 1, 1), (1, 0, 0), (0, -1, 0)),
    "right": ((1, 1, 1), (0, 0, -1), (0, -1, 0)),
    "left": ((-1, 1, -1), (0, 0, 1), (0, -1, 0)),
    "top": ((1, 1, 1), (-1, 0, 0), (0, 0, -1)),
    "bottom": ((1, -1, -1), (-1, 0, 0), (0, 0, 1)),
}


# ---------------------------------------------------------------- export for the game
def rects(g, base):
    """Greedy rectangles of the non-base roles of a face grid: [col, row, w, h, role]."""
    h, w = len(g), len(g[0])
    done = [[False] * w for _ in range(h)]
    out = []
    for r in range(h):
        for c in range(w):
            role = g[r][c]
            if done[r][c] or role == base:
                continue
            ww = 1
            while c + ww < w and not done[r][c + ww] and g[r][c + ww] == role:
                ww += 1
            hh = 1
            while r + hh < h and all(not done[r + hh][c + i] and g[r + hh][c + i] == role for i in range(ww)):
                hh += 1
            for i in range(hh):
                for j in range(ww):
                    done[r + i][c + j] = True
            out.append([c, r, ww, hh, role])
    return out


# R15 parts cut from the limbs: limb, rows [r0, r1) of the side faces, and which end faces it owns
PARTS = {
    "Head": ("head", 0, 8, ("top", "bottom")),
    "UpperTorso": ("body", 0, 8, ("top",)),
    "LowerTorso": ("body", 8, 12, ("bottom",)),
    "RightUpperArm": ("rarm", 0, 6, ("top",)),
    "RightLowerArm": ("rarm", 6, 10, ()),
    "RightHand": ("rarm", 10, 12, ("bottom",)),
    "LeftUpperArm": ("larm", 0, 6, ("top",)),
    "LeftLowerArm": ("larm", 6, 10, ()),
    "LeftHand": ("larm", 10, 12, ("bottom",)),
    "RightUpperLeg": ("rleg", 0, 6, ("top",)),
    "RightLowerLeg": ("rleg", 6, 10, ()),
    "RightFoot": ("rleg", 10, 12, ("bottom",)),
    "LeftUpperLeg": ("lleg", 0, 6, ("top",)),
    "LeftLowerLeg": ("lleg", 6, 10, ()),
    "LeftFoot": ("lleg", 10, 12, ("bottom",)),
}
# joint pivots (px, Roblox axes): Minecraft turns the arms 5 px out and 2 px under the shoulder top
JOINTS = [
    ["Root", "HumanoidRootPart", "LowerTorso", [0, 14, 0]],
    ["Waist", "LowerTorso", "UpperTorso", [0, 16, 0]],
    ["Neck", "UpperTorso", "Head", [0, 24, 0]],
    ["RightShoulder", "UpperTorso", "RightUpperArm", [5, 22, 0]],
    ["RightElbow", "RightUpperArm", "RightLowerArm", [6, 18, 0]],
    ["RightWrist", "RightLowerArm", "RightHand", [6, 14, 0]],
    ["LeftShoulder", "UpperTorso", "LeftUpperArm", [-5, 22, 0]],
    ["LeftElbow", "LeftUpperArm", "LeftLowerArm", [-6, 18, 0]],
    ["LeftWrist", "LeftLowerArm", "LeftHand", [-6, 14, 0]],
    ["RightHip", "LowerTorso", "RightUpperLeg", [2, 12, 0]],
    ["RightKnee", "RightUpperLeg", "RightLowerLeg", [2, 6, 0]],
    ["RightAnkle", "RightLowerLeg", "RightFoot", [2, 2, 0]],
    ["LeftHip", "LowerTorso", "LeftUpperLeg", [-2, 12, 0]],
    ["LeftKnee", "LeftUpperLeg", "LeftLowerLeg", [-2, 6, 0]],
    ["LeftAnkle", "LeftLowerLeg", "LeftFoot", [-2, 2, 0]],
]


def cut(limb_faces, limb, r0, r1, ends):
    """The part's face grids from the limb's: side faces rows r0..r1, the end faces it owns."""
    faces = {}
    for face in ("front", "back", "right", "left"):
        faces[face] = [row[:] for row in limb_faces[face][r0:r1]]
    for face in ends:
        faces[face] = [row[:] for row in limb_faces[face]]
    return faces


def export():
    base = paint_base()
    parts = {}
    for name, (limb, r0, r1, ends) in PARTS.items():
        (cx, cy, cz), (sx, sy, sz) = LIMBS[limb]
        top = cy + sy / 2
        faces = cut(base[limb], limb, r0, r1, ends)
        counts = {}
        for g in faces.values():
            for row in g:
                for role in row:
                    counts[role] = counts.get(role, 0) + 1
        main = max(counts, key=counts.get)
        parts[name] = {
            "size": [sx, r1 - r0, sz],
            "pos": [cx, top - (r0 + r1) / 2, cz],
            "base": main,
            "faces": {f: rects(g, main) for f, g in faces.items() if rects(g, main)},
        }
    layers = {}
    for lname, layer in LAYERS.items():
        out = {}
        for name, (limb, r0, r1, ends) in PARTS.items():
            if limb not in layer:
                continue
            faces = {}
            for face, pixels in layer[limb].items():
                if face in ("top", "bottom"):
                    if face not in ends:
                        continue
                    sel = {(c, r): role for (c, r), role in pixels.items()}
                else:
                    sel = {(c, r - r0): role for (c, r), role in pixels.items() if r0 <= r < r1}
                if not sel:
                    continue
                w, h = dims((LIMBS[limb][1][0], r1 - r0, LIMBS[limb][1][2]), face)
                g = [[sel.get((c, r), "") for c in range(w)] for r in range(h)]
                faces[face] = rects(g, "")
            if faces:
                out[name] = faces
        layers[lname] = out
    data = {
        "source": "assets/models/player/player.py -- export: our Minecraft-proportioned body in a prison uniform. px = studs per pixel; "
        "pos = part centre, size in px, Roblox axes (X = the character's right, Y = up from the ground, Z = back); faces: "
        "[col, row, w, h, role] over the part's base role, face grids as in player.py; joints = pivots in px",
        "px": PX,
        "hipHeight": 12,
        "root": {"size": [8, 12, 4], "pos": [0, 18, 0]},
        "parts": parts,
        "joints": JOINTS,
        "layers": layers,
        "styles": STYLES,
        "fixed": {k: v.lstrip("#") for k, v in FIXED.items()},
        "palettes": {
            "skin": [c.lstrip("#") for c in SKIN],
            "skin_dark": [c.lstrip("#") for c in SKIN_DARK],
            "mouth": [c.lstrip("#") for c in MOUTH],
            "hair": [c.lstrip("#") for c in HAIR],
            "hair_dark": [c.lstrip("#") for c in HAIR_DARK],
            "iris": [c.lstrip("#") for c in IRIS],
        },
    }
    path = os.path.join(ROOT, "src", "shared", "Models", "player.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    n = sum(len(r) for p in parts.values() for r in p["faces"].values())
    print("exported player →", path, "base rects", n, "layers", {k: sum(len(r) for p in v.values() for r in p.values()) for k, v in layers.items()})


# ---------------------------------------------------------------- Blender renders
def render():
    import bpy
    from mathutils import Vector

    sys.path.insert(0, os.path.dirname(HERE))
    from voxeltool import hexrgb, look, setup, srgb_to_linear

    VARIANTS = {
        "a": (0, 1, "short", 0, False, None),
        "b": (2, 0, "fringe", 1, False, "#3c7fd8"),
        "c": (4, 5, "buzz", 1, True, None),
        "d": (1, 2, "short", 2, False, "#d23c3c"),
        "e": (3, 3, "bald", 1, True, "#4caf50"),
        "f": (0, 4, "fringe", 3, False, None),
    }
    mats = {}

    def material(col):
        if col not in mats:
            m = bpy.data.materials.new(col)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = srgb_to_linear(hexrgb(col)) + (1,)
            bsdf.inputs["Roughness"].default_value = 1.0
            if "Specular IOR Level" in bsdf.inputs:
                bsdf.inputs["Specular IOR Level"].default_value = 0.0
            mats[col] = m
        return mats[col]

    def to_blender(p):
        return Vector((-p[0], p[2], p[1])) * PX  # (X right, Y up, Z back) → Blender (x, y, z) with the face to −Y

    def build(look_data, name):
        for o in list(bpy.data.objects):
            if o.type == "MESH":
                bpy.data.objects.remove(o)
        import bmesh

        me = bpy.data.meshes.new(name)
        obj = bpy.data.objects.new(name, me)
        bpy.context.scene.collection.objects.link(obj)
        bm = bmesh.new()
        index = {}
        for limb, (centre, size) in LIMBS.items():
            half = [s / 2 for s in size]
            for face, (tl, right, down) in FACE_BASIS.items():
                g = look_data[limb][face]
                origin = [centre[i] + tl[i] * half[i] for i in range(3)]
                for r, row in enumerate(g):
                    for c, col in enumerate(row):
                        def pt(dc, dr):
                            return to_blender([origin[i] + right[i] * (c + dc) + down[i] * (r + dr) for i in range(3)])

                        f = bm.faces.new([bm.verts.new(pt(0, 0)), bm.verts.new(pt(1, 0)), bm.verts.new(pt(1, 1)), bm.verts.new(pt(0, 1))])
                        if col not in index:
                            me.materials.append(material(col))
                            index[col] = len(me.materials) - 1
                        f.material_index = index[col]
        bm.to_mesh(me)
        bm.free()
        return obj

    scene, cam = setup(700, 900)
    mid = Vector((0, 0, 16 * PX))
    for key, args in VARIANTS.items():
        build(variant(*args), "player_" + key)
        for view, loc in (
            ("front", (0, -20, 16 * PX)),
            ("back", (0, 20, 16 * PX)),
            ("34", (-11, -14, 16 * PX + 3.5)),
        ):
            if view != "34" and key not in ("a", "b"):
                continue
            look(cam, Vector(loc), mid, 6.6, None)
            scene.render.filepath = os.path.join(HERE, "render-%s-%s.png" % (key, view))
            bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "player.blend"))


# ---------------------------------------------------------------- the game's build, mirrored (AvatarService.paint)
GAME_FACES = {  # tl, right, down, normal: the FACES table of AvatarService.luau
    "front": ((1, 1, -1), (-1, 0, 0), (0, -1, 0), (0, 0, -1)),
    "back": ((-1, 1, 1), (1, 0, 0), (0, -1, 0), (0, 0, 1)),
    "right": ((1, 1, 1), (0, 0, -1), (0, -1, 0), (1, 0, 0)),
    "left": ((-1, 1, -1), (0, 0, 1), (0, -1, 0), (-1, 0, 0)),
    "top": ((1, 1, 1), (-1, 0, 0), (0, 0, -1), (0, 1, 0)),
    "bottom": ((1, -1, -1), (-1, 0, 0), (0, 0, 1), (0, -1, 0)),
}


def game_boxes(data, colours, layers):
    """[(centre studs, size studs, hex)] as the game builds them: each part, then its plates."""
    px, plate = data["px"], 0.02
    out = []
    for name, part in data["parts"].items():
        size, pos, base = part["size"], part["pos"], part["base"]
        centre = [v * px for v in pos]
        out.append((centre, [v * px for v in size], colours[base]))
        half = [v * px / 2 for v in size]
        for face, (tl, right, down, normal) in GAME_FACES.items():
            w, h = dims(size, face)
            grid = [[base] * w for _ in range(h)]
            rects_in = list(part["faces"].get(face, []))
            for layer in layers:
                rects_in += data["layers"][layer].get(name, {}).get(face, [])
            for c, r, rw, rh, role in rects_in:
                for y in range(r, r + rh):
                    for x in range(c, c + rw):
                        grid[y][x] = role
            for c, r, rw, rh, role in rects(grid, base):
                local = [tl[i] * half[i] + right[i] * (c + rw / 2) * px + down[i] * (r + rh / 2) * px + normal[i] * plate / 2 for i in range(3)]
                sz = [abs(right[i]) * rw * px + abs(down[i]) * rh * px + abs(normal[i]) * plate for i in range(3)]
                out.append(([centre[i] + local[i] for i in range(3)], sz, colours[role]))
    return out


def check():
    import bpy
    from mathutils import Vector

    sys.path.insert(0, os.path.dirname(HERE))
    from voxeltool import hexrgb, look, setup, srgb_to_linear

    with open(os.path.join(ROOT, "src", "shared", "Models", "player.json"), encoding="utf-8") as f:
        data = json.load(f)
    pal = data["palettes"]
    colours = {k: "#" + v for k, v in data["fixed"].items()}
    colours.update(skin="#" + pal["skin"][2], skin_dark="#" + pal["skin_dark"][2], mouth="#" + pal["mouth"][2],
                   hair="#" + pal["hair"][0], hair_dark="#" + pal["hair_dark"][0], brow="#" + pal["hair_dark"][0],
                   iris="#" + pal["iris"][1], faction="#3c7fd8")
    for o in list(bpy.data.objects):
        if o.type == "MESH":
            bpy.data.objects.remove(o)
    mats = {}
    for i, (centre, size, col) in enumerate(game_boxes(data, colours, ["hair_fringe", "armband"])):
        bpy.ops.mesh.primitive_cube_add(size=1, location=(-centre[0], centre[2], centre[1]))
        obj = bpy.context.active_object
        obj.scale = (size[0], size[2], size[1])
        if col not in mats:
            m = bpy.data.materials.new(col)
            m.use_nodes = True
            bsdf = m.node_tree.nodes["Principled BSDF"]
            bsdf.inputs["Base Color"].default_value = srgb_to_linear(hexrgb(col)) + (1,)
            bsdf.inputs["Roughness"].default_value = 1.0
            mats[col] = m
        obj.data.materials.append(mats[col])
    scene, cam = setup(700, 900)
    mid = Vector((0, 0, 16 * PX))
    for view, loc in (("front", (0, -20, 16 * PX)), ("34", (-11, -14, 16 * PX + 3.5))):
        look(cam, Vector(loc), mid, 6.6, None)
        scene.render.filepath = os.path.join(HERE, "render-check-%s.png" % view)
        bpy.ops.render.render(write_still=True)


if sys.argv[-1] == "export":
    export()
elif sys.argv[-1] == "check":
    check()
else:
    render()
