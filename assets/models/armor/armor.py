# Our armor for the block body [владелец 26.10: «броню сделаем по телу»; «броню также делаем новую в блендер. Кожаная
# броня, кольчужная, железная и алмазная»]. Minecraft's way of wearing it (assets/models/player/player.py has the body):
# each piece is a shell round whole limbs grown by 1 px on every side (leggings ½ px, the inner layer), painted per
# face on the limb's own pixel grid (head 8³, body 8×12×4, arms and legs 4×12×4), transparent where the body shows.
# The pixels and colours are ours (nothing from Minecraft or VoxeLibre): leather — a stitched jerkin, a cap with ear
# flaps, laces; chain — rows of rings, a coif; iron — plates with seams and rivets, a helmet with a nose guard;
# diamond — faceted plates with sparkles, long cheek guards. Material keys as in the game: wood = leather,
# stone = chain, iron, diamond.
#
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/armor/armor.py
#   → render-<material>-{front,34,back}.png on the body (built exactly as the game builds it), armor-sheet.png;
# "… -- export" → src/shared/Models/armor.json: the boxes (part, rows, growth) and per material and piece the plates of
#   each face as [u0, v0, u1, v1, hex, layer] fractions of the face (layer 0 = the shell, 1 = details on it) —
#   ArmorVisual.luau builds them.
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "player"))
import player  # noqa: E402

THICK = 0.06  # studs: the shell plates, sunk under the grown surface
LIFT = 0.012  # studs: the detail plates stand this far out of the shell

MATERIALS = ("wood", "stone", "iron", "diamond")
PALETTES = {
    "wood": {"base": "#8d5b33", "light": "#a9733f", "mid": "#774a28", "dark": "#5a381b", "stitch": "#d8bf8c", "lace": "#3a2414"},
    "stone": {"base": "#7b8087", "light": "#b9bdc3", "mid": "#969ba2", "dark": "#3f4349"},
    "iron": {"base": "#c3c6c9", "light": "#eceef0", "mid": "#9a9ea2", "dark": "#686c70", "rivet": "#4f5357"},
    "diamond": {"base": "#45c4d1", "light": "#93ecf2", "white": "#e2ffff", "mid": "#2b9bab", "dark": "#176877"},
}
SIZES = {"head": (8, 8, 8), "body": (8, 12, 4), "arm": (4, 12, 4), "leg": (4, 12, 4)}
SIDES = ("front", "back", "right", "left")
# the faces of a right limb that touch the body or the other leg: never seen, never built
INNER = {"arm": "left", "leg": "left"}


def rows(a, b):
    return range(a, b)


# ---------------------------------------------------------------- shapes: {face: set((col, row))} on the limb grids
def full(limb, face, r_from=0, r_to=None):
    w, h = player.dims(SIZES[limb], face)
    r_to = h if r_to is None else r_to
    return {(c, r) for c in range(w) for r in range(r_from, r_to)}


def toward_front(face, c):
    """0 = the back edge … 7 = the front edge of an 8-wide head side."""
    return c if face == "right" else 7 - c


def helmet_shape(mat):
    s = {"top": full("head", "top")}
    if mat == "wood":  # a cap with ear flaps
        s["front"] = full("head", "front", 0, 2)
        for face in ("right", "left"):
            s[face] = full("head", face, 0, 7)
        s["back"] = full("head", "back", 0, 7)
    elif mat == "stone":  # a coif: round the face, under the chin
        s["front"] = full("head", "front", 0, 2) | {(c, r) for c in (0, 7) for r in rows(2, 7)} | {(c, 7) for c in range(8)}
        for face in ("right", "left", "back"):
            s[face] = full("head", face)
        s["bottom"] = full("head", "bottom")
    elif mat == "iron":  # a helm with a nose guard and cheek guards
        s["front"] = full("head", "front", 0, 2) | {(c, 2) for c in (0, 1, 3, 4, 6, 7)} | {(c, r) for c in (0, 3, 4, 7) for r in (3, 4)} | {(0, 5), (7, 5)}
        for face in ("right", "left"):
            s[face] = full("head", face, 0, 6) | {(c, 6) for c in range(8) if toward_front(face, c) <= 3}
        s["back"] = full("head", "back", 0, 7)
    else:  # diamond: long cheek guards, the brow dips at the middle
        s["front"] = full("head", "front", 0, 2) | {(c, 2) for c in (0, 1, 3, 4, 6, 7)} | {(c, r) for c in (0, 7) for r in rows(3, 7)}
        for face in ("right", "left"):
            s[face] = full("head", face, 0, 7)
        s["back"] = full("head", "back")
    return {"head": s}


def chest_shape(mat):
    bottom = {"wood": 10, "stone": 11, "iron": 10, "diamond": 10}[mat]
    body = {f: full("body", f, 0, bottom) for f in SIDES}
    body["top"] = full("body", "top")
    if mat == "wood":
        body["front"] -= {(3, 0), (4, 0)}  # the open collar
    arm_rows = {"wood": [(0, 5)], "stone": [(0, 8)], "iron": [(0, 5), (8, 11)], "diamond": [(0, 6), (8, 12)]}[mat]
    arm = {}
    for f in SIDES:
        if f != INNER["arm"]:
            arm[f] = set().union(*(full("arm", f, a, b) for a, b in arm_rows))
    arm["top"] = full("arm", "top")
    return {"body": body, "arm": arm}


def legs_shape(mat):
    body = {f: full("body", f, 8, 12) for f in SIDES}
    leg = {f: full("leg", f, 0, 9) for f in SIDES if f != INNER["leg"]}
    return {"body": body, "leg": leg}


def boots_shape(mat):
    top = 8 if mat == "wood" else 9  # leather boots reach a pixel higher (only rows 9–12 are inside the boots' box)
    leg = {f: full("leg", f, max(top, 9), 12) for f in SIDES if f != INNER["leg"]}
    leg["bottom"] = full("leg", "bottom")
    return {"leg": leg}


SHAPES = {"helmet": helmet_shape, "chestplate": chest_shape, "leggings": legs_shape, "boots": boots_shape}


# ---------------------------------------------------------------- colours
def paint(mat, piece, limb, face, shape):
    """{(c, r): hex} for the covered pixels of one face. Patterns run along rows so the plates merge (fewer parts)."""
    pal = PALETTES[mat]
    w, h = player.dims(SIZES[limb], face)
    out = {}
    side = face in SIDES
    wide = side and w >= 8  # the body's front and back, the head's faces
    for (c, r) in shape:
        role = "base"
        hem = side and (c, r + 1) not in shape
        rim = side and (c, r - 1) not in shape
        border = not side and (c in (0, w - 1) or r in (0, h - 1))
        ridge = wide and limb == "body" and face == "front" and c in (3, 4)  # the breastplate's middle
        knee = limb == "leg" and side and r in (5, 6)
        if mat == "wood":
            if (c * 7 + r * 13 + len(face)) % 17 == 0:
                role = "mid"
            if side and (c, r + 2) not in shape and (c, r + 1) in shape and c % 2 == 0:
                role = "stitch"
            if piece == "chestplate" and limb == "body" and face == "front" and 1 <= r <= 7 and c == (3 if r % 2 else 4):
                role = "lace"
            if piece == "boots" and face == "front" and r == 10 and c in (1, 2):
                role = "lace"
            if border:
                role = "mid"
            if rim:
                role = "light"
            if hem or face == "bottom":
                role = "dark"
        elif mat == "stone":
            # rows of rings (light) over the dark links, a link every fourth pixel between them
            if side or face == "bottom":
                role = "light" if r % 2 == 0 else ("dark" if (c + r) % 4 == 1 else "base")
            elif border:
                role = "mid"
            if hem:
                role = "dark"
        elif mat == "iron":
            if side and r % 4 == 3:
                role = "mid"  # the seams between the plates
            if ridge and r < 9:
                role = "light"
            if knee:
                role = "light" if r == 5 else "mid"
            if wide and r % 4 == 1 and c in (1, w - 2):
                role = "rivet"
            if piece == "helmet" and face == "front" and c in (3, 4) and r >= 2:
                role = "mid" if r < 4 else "dark"  # the nose guard
            if piece == "helmet" and face == "top" and c in (3, 4):
                role = "light"  # the crest
            if border:
                role = "mid"
            if rim:
                role = "light"
            if hem or (piece == "boots" and face == "bottom"):
                role = "dark"
        else:  # diamond
            if side and r % 4 == 3:
                role = "mid"
            if side and r % 4 == 0:
                role = "light"  # each plate catches the light at its top
            if ridge and r < 9:
                role = "white" if r % 4 == 1 else "light"
            if knee:
                role = "white" if r == 5 else "mid"
            if wide and r % 4 == 1 and c in (1, w - 2):
                role = "white"  # a sparkle on each plate
            if piece == "helmet" and face == "top" and c in (3, 4):
                role = "white" if r in (3, 4) else "light"
            if border:
                role = "mid"
            if rim:
                role = "light"
            if hem or (piece == "boots" and face == "bottom"):
                role = "dark"
        out[(c, r)] = pal[role]
    return out


def mirror(faces, limb):
    """A right limb's faces → the left limb's (mirrored across X)."""
    w = {f: player.dims(SIZES[limb], f)[0] for f in player.FACES}
    flip = lambda f, px: {(w[f] - 1 - c, r): v for (c, r), v in px.items()}  # noqa: E731
    out = {}
    for f, px in faces.items():
        target = {"right": "left", "left": "right"}.get(f, f)
        out[target] = flip(f, px)
    return out


def painted(mat, piece):
    """{limb key: {face: {(c, r): hex}}} with limb keys head, body, rarm, larm, rleg, lleg."""
    out = {}
    for limb, faces in SHAPES[piece](mat).items():
        px = {f: paint(mat, piece, limb, f, shape) for f, shape in faces.items() if shape}
        if limb in ("arm", "leg"):
            out["r" + limb] = px
            out["l" + limb] = mirror(px, limb)
        else:
            out[limb] = px
    return out


# ---------------------------------------------------------------- boxes: (part, a0, a1, limb key, r0, r1, grow)
def boxes(piece):
    if piece == "helmet":
        return [("Head", 0, 8, "head", 0, 8, 1)]
    out = []
    if piece == "chestplate":
        out += [("UpperTorso", 0, 8, "body", 0, 8, 1), ("LowerTorso", 8, 12, "body", 8, 12, 1)]
    elif piece == "leggings":
        out += [("LowerTorso", 8, 12, "body", 8, 12, 0.5)]
    for side, key in (("Right", "r"), ("Left", "l")):
        if piece == "chestplate":
            out += [(side + "UpperArm", 0, 6, key + "arm", 0, 6, 1), (side + "LowerArm", 6, 10, key + "arm", 6, 12, 1)]
        elif piece == "leggings":
            out += [(side + "UpperLeg", 0, 6, key + "leg", 0, 6, 0.5), (side + "LowerLeg", 6, 10, key + "leg", 6, 12, 0.5)]
        elif piece == "boots":
            out += [(side + "Foot", 10, 12, key + "leg", 9, 12, 1)]
    return out


def limb_size(key):
    return SIZES[key[1:] if key[0] in "rl" and key[1:] in ("arm", "leg") else key]


def face_rects(px, w, h):
    """The shell (the covered shape in its commonest colour) and the details over it: [[u0, v0, u1, v1, hex, layer]]."""
    if not px:
        return []
    counts = {}
    for v in px.values():
        counts[v] = counts.get(v, 0) + 1
    base = max(counts, key=counts.get)
    shape = [[("x" if (c, r) in px else "") for c in range(w)] for r in range(h)]
    detail = [[(px[(c, r)] if (c, r) in px and px[(c, r)] != base else "") for c in range(w)] for r in range(h)]
    out = []
    for c, r, rw, rh, _ in player.rects(shape, ""):
        out.append([round(c / w, 4), round(r / h, 4), round((c + rw) / w, 4), round((r + rh) / h, 4), base, 0])
    for c, r, rw, rh, col in player.rects(detail, ""):
        out.append([round(c / w, 4), round(r / h, 4), round((c + rw) / w, 4), round((r + rh) / h, 4), col, 1])
    return out


def box_faces(mat, piece):
    """Per box of `piece`: {face: rects}, the side faces cut to the box's rows."""
    paint_all = painted(mat, piece)
    out = []
    for part, a0, a1, key, r0, r1, grow in boxes(piece):
        size = limb_size(key)
        length = size[1]
        faces = {}
        for face, px in paint_all.get(key, {}).items():
            w, h = player.dims(size, face)
            if face in SIDES:
                cut = {(c, r - r0): v for (c, r), v in px.items() if r0 <= r < r1}
                rects = face_rects(cut, w, r1 - r0)
            elif (face == "top" and r0 == 0) or (face == "bottom" and r1 == length):
                rects = face_rects(px, w, h)
            else:
                continue
            if rects:
                faces[face] = rects
        out.append(faces)
    return out


def export():
    data = {
        "source": "assets/models/armor/armor.py -- export: our armor for the block body. boxes[piece] = [part, a0, a1, "
        "length, width, depth, r0, r1, grow] (px: the part holds rows a0..a1 of a limb length × width × depth, the box "
        "is rows r0..r1 of that limb grown by `grow` a side); sets[material][piece][i] = the faces of box i: [u0, v0, u1, "
        "v1, hex, layer] fractions of the face in the face grids of player.py (layer 1 stands on layer 0)",
        "thick": THICK,
        "lift": LIFT,
        "boxes": {},
        "sets": {},
    }
    total = {}
    for piece in SHAPES:
        data["boxes"][piece] = [[p, a0, a1, *limb_size(k)[1:2], limb_size(k)[0], limb_size(k)[2], r0, r1, g] for p, a0, a1, k, r0, r1, g in boxes(piece)]
    for mat in MATERIALS:
        data["sets"][mat] = {}
        for piece in SHAPES:
            faces = box_faces(mat, piece)
            for box in faces:
                for rects in box.values():
                    for rect in rects:
                        rect[4] = rect[4].lstrip("#")
            data["sets"][mat][piece] = faces
            total[mat] = total.get(mat, 0) + sum(len(r) for b in faces for r in b.values())
    path = os.path.join(ROOT, "src", "shared", "Models", "armor.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    print("exported armor →", path, "plates per full set", total)


# ---------------------------------------------------------------- the game's build, mirrored (ArmorVisual.buildBlockArmor)
def game_plates(body, mat, pieces):
    """[(centre studs, size studs, hex)] of the armor as the game places it on the body."""
    px = body["px"]
    out = []
    for piece in pieces:
        for (part, a0, a1, key, r0, r1, grow), faces in zip(boxes(piece), box_faces(mat, piece)):
            width, length, depth = limb_size(key)
            grown = length + 2 * grow
            top = (a0 + a1) / 2 + grow
            y0, y1 = top - grown * r0 / length, top - grown * r1 / length
            S = [(width + 2 * grow) * px, (y0 - y1) * px, (depth + 2 * grow) * px]
            pos = body["parts"][part]["pos"]
            centre = [pos[0] * px, pos[1] * px + (y0 + y1) / 2 * px, pos[2] * px]
            half = [v / 2 for v in S]
            for face, rects in faces.items():
                tl, right, down, normal = player.GAME_FACES[face]
                lr = sum(abs(right[i]) * S[i] for i in range(3))
                ld = sum(abs(down[i]) * S[i] for i in range(3))
                for u0, v0, u1, v1, col, layer in rects:
                    lift = LIFT if layer else 0
                    local = [tl[i] * half[i] + right[i] * (u0 + u1) / 2 * lr + down[i] * (v0 + v1) / 2 * ld - normal[i] * (THICK / 2 - lift) for i in range(3)]
                    size = [abs(right[i]) * (u1 - u0) * lr + abs(down[i]) * (v1 - v0) * ld + abs(normal[i]) * THICK for i in range(3)]
                    out.append(([centre[i] + local[i] for i in range(3)], size, col))
    return out


def render():
    import bpy
    from mathutils import Vector

    sys.path.insert(0, os.path.dirname(HERE))
    from voxeltool import look, setup

    body = player.load_body()
    scene, cam = setup(700, 900)
    mid = Vector((0, 0, 16 * player.PX))
    looks = {"wood": (1, 1), "stone": (0, 3), "iron": (2, 0), "diamond": (3, 5)}
    for mat in MATERIALS:
        player.clear_meshes()
        skin, hair = looks[mat]
        player.add_boxes(player.game_boxes(body, player.check_colours(body, skin, hair), ["hair_short"]), "player")
        player.add_boxes(game_plates(body, mat, SHAPES.keys()), "armor")
        for view, loc in (("front", (0, -20, 16 * player.PX)), ("34", (-11, -14, 16 * player.PX + 3.5)), ("back", (9, 17, 16 * player.PX + 2))):
            look(cam, Vector(loc), mid, 6.6, None)
            scene.render.filepath = os.path.join(HERE, "render-%s-%s.png" % (mat, view))
            bpy.ops.render.render(write_still=True)
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(HERE, "armor.blend"))


if __name__ == "__main__":
    if sys.argv[-1] == "export":
        export()
    else:
        render()
