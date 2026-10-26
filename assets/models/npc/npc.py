# Our NPCs in the player's block body [владелец 26.10: «нужны тогда модельки и для нпс наших»]: the same
# Minecraft-proportioned body as assets/models/player/player.py (head 8³, body 8×12×4, limbs 4×12×4 px), each role in its
# own costume painted pixel by pixel, plus boxes for what sticks out of the body (caps, the miner's helmet and lamp, the
# chef's hat, the wizard hat, the cultist's hood, robes over the legs, the gatekeeper's halo, a clipboard, a baton).
# Every pixel is ours. Colours are ROLES; the game varies skin and hair per NPC and, for the block buyers, the shirt and
# trousers (each location gave its buyer its own colours).
#
# Run: "C:/Program Files/Blender Foundation/Blender 5.2/blender.exe" -b -P assets/models/npc/npc.py
#   → src/shared/Models/npcs.json (per costume: the R15 parts' base role and pixel rectangles, the extra boxes, the
#     palette) and render-<costume>-{front,34,back}.png built from that JSON the way the game builds it (NpcBodyService).
# Space and face grids as in player.py: X = the character's right, Y = up from the ground, Z = back (the face looks to
# −Z); columns run left → right as you look at a face, so on the front col 0 is the character's right.
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(HERE)))
sys.path.insert(0, os.path.join(os.path.dirname(HERE), "player"))
import player  # noqa: E402
from player import FACES, LIMBS, PARTS, PX, cut, dims, grid, rects  # noqa: E402

SIDES = ("front", "back", "right", "left")
OUTER = {"rarm": "right", "larm": "left", "rleg": "right", "lleg": "left"}


# ---------------------------------------------------------------- painting helpers
def start(hair="short", beard=False):
    """A body in role 'shirt' with the player's face (brows, eyes, nose, mouth) and a hairstyle baked in."""
    head = player.paint_base()["head"]
    out = {limb: {f: grid(*dims(size, f), "shirt") for f in FACES} for limb, (_, size) in LIMBS.items() if limb != "head"}
    out["head"] = head
    layers = [player.hair_layer(hair)] if hair != "bald" else []
    if beard:
        layers.append(player.beard_layer())
    for layer in layers:
        for face, pixels in layer.get("head", {}).items():
            for (c, r), role in pixels.items():
                head[face][r][c] = role
    for arm in ("rarm", "larm"):
        out[arm]["bottom"] = grid(4, 4, "skin")
    for leg in ("rleg", "lleg"):
        out[leg]["bottom"] = grid(4, 4, "sole")
    return out


def fill(out, limb, role, faces=SIDES, rows=None, cols=None):
    for face in faces:
        g = out[limb][face]
        for r in rows if rows is not None else range(len(g)):
            for c in cols if cols is not None else range(len(g[0])):
                g[r][c] = role


def put(out, limb, face, cells, role):
    for c, r in cells:
        out[limb][face][r][c] = role


def arms(out, sleeve, rows, cuff=None, hand="skin"):
    """Sleeves over rows [0, rows), the last one the cuff; bare forearm below; the hand rows 10–11."""
    for arm in ("rarm", "larm"):
        fill(out, arm, sleeve, rows=range(rows))
        if cuff:
            fill(out, arm, cuff, rows=[rows - 1])
        fill(out, arm, "skin", rows=range(rows, 10))
        fill(out, arm, hand, rows=(10, 11))
        if hand != "skin":
            out[arm]["bottom"] = grid(4, 4, hand)


def legs(out, cloth, shoe_from, shoe="shoe", inner=None, toe=None):
    """Trousers down to row shoe_from, shoes below; the inner column a shade darker so the legs read apart."""
    for leg in ("rleg", "lleg"):
        fill(out, leg, cloth, rows=range(shoe_from))
        fill(out, leg, shoe, rows=range(shoe_from, 12))
        if inner:
            front, back = (3, 0) if leg == "rleg" else (0, 3)
            for r in range(shoe_from):
                out[leg]["front"][r][front] = inner
                out[leg]["back"][r][back] = inner
        if toe:
            put(out, leg, "front", [(1, shoe_from), (2, shoe_from)], toe)


def box(name, part, centre, size, base, paint=None):
    """An extra box (px, body space) carried by an R15 part; paint(grids) draws on its {face: grid}."""
    return {"name": name, "part": part, "centre": centre, "size": size, "base": base, "paint": paint}


def faces_of(size, base):
    return {f: grid(int(dims(size, f)[0]), int(dims(size, f)[1]), base) for f in FACES}


def skirt(role, hem, line=None, extra=None):
    """A robe over both legs, from the waist to two pixels above the ground (the shoes show under it)."""
    def paint(g):
        for f in SIDES:
            for c in range(len(g[f][0])):
                g[f][9][c] = hem
        if line:
            for r in range(9):
                g["front"][r][4] = line
        if extra:
            extra(g)
    return box("Skirt", "LowerTorso", (0, 7, 0), (9, 10, 5), role, paint)


# ---------------------------------------------------------------- the costumes
def buyer():
    """Скупщик блоков: rolled sleeves, a leather apron with a pocket, a tweed flat cap."""
    o = start("short")
    b = o["body"]
    put(o, "body", "front", [(2, 0), (5, 0)], "shirt_dark")
    put(o, "body", "front", [(3, 0), (4, 0)], "skin")
    for r in range(2, 12):
        for c in range(1, 7):
            b["front"][r][c] = "apron"
    for c in range(1, 7):
        b["front"][2][c] = "apron_hi"
    for c in range(2, 6):
        b["front"][7][c] = b["front"][8][c] = "apron_dark"
    for r in (0, 1):
        b["front"][r][1] = b["front"][r][6] = "strap"
    for r in range(8):
        b["back"][r][1] = b["back"][r][6] = "strap"
    fill(o, "body", "strap", faces=("back", "right", "left"), rows=[8])
    put(o, "body", "back", [(3, 9), (4, 9)], "strap")
    arms(o, "shirt", 6, cuff="shirt_dark")
    legs(o, "pants", 9, inner="pants_dark", toe="shoe_hi")
    for r in range(5):
        role = "apron_dark" if r == 4 else "apron"
        for c in (1, 2, 3):
            o["rleg"]["front"][r][c] = role
        for c in (0, 1, 2):
            o["lleg"]["front"][r][c] = role

    def crown(g):
        for c in range(9):
            g["front"][2][c] = "cap_dark"
        for c in range(9):
            for r in range(9):
                if (c + 2 * r) % 4 == 0:
                    g["top"][r][c] = "cap_dark"
        for f in ("back", "right", "left"):
            for c in range(len(g[f][0])):
                g[f][2][c] = "cap_dark"

    def brim(g):
        for c in range(9):
            g["front"][0][c] = "cap_dark"

    extras = [
        box("Cap", "Head", (0, 31, 0), (9, 3, 9), "cap", crown),
        box("CapBrim", "Head", (0, 30, -5.5), (9, 1, 2), "cap_hi", brim),
    ]
    colours = {
        "shirt": "#3c5a3c", "apron": "#6e5028", "apron_dark": "#50391c", "apron_hi": "#8a6738", "strap": "#3e2c1a",
        "pants": "#322d28", "shoe": "#3b2b20", "shoe_hi": "#5a4231", "sole": "#221a14",
        "cap": "#5e4a36", "cap_dark": "#463626", "cap_hi": "#75604a",
    }
    return o, extras, colours, ["shirt", "pants"], []


def miner():
    """Продавец предметов, скупщик каменоломни: a plaid shirt, denim overalls, gloves, a helmet with a lamp."""
    o = start("buzz", beard=True)
    for limb in ("body", "rarm", "larm"):
        for f in FACES:
            g = o[limb][f]
            for r in range(len(g)):
                for c in range(len(g[0])):
                    if g[r][c] == "shirt" and (r % 3 == 2 or c % 3 == 2):
                        g[r][c] = "shirt_dark"
    b = o["body"]
    fill(o, "body", "denim", rows=range(8, 12))
    for r in range(3, 8):
        for c in range(2, 6):
            b["front"][r][c] = "denim"
    for r in range(3):
        b["front"][r][2] = b["front"][r][5] = "denim"
    for r in range(8):
        b["back"][r][2] = b["back"][r][5] = "denim"
    put(o, "body", "front", [(2, 3), (5, 3)], "button")
    put(o, "body", "front", [(3, 5), (4, 5)], "denim_dark")
    put(o, "body", "front", [(3, 0), (4, 0)], "skin")
    arms(o, "shirt", 10, cuff="shirt_dark", hand="glove")
    legs(o, "denim", 9, shoe="boot", inner="denim_dark", toe="boot_hi")
    for leg in ("rleg", "lleg"):
        put(o, leg, "front", [(1, 5), (2, 5), (1, 6), (2, 6)], "denim_dark")

    def dome(g):
        for c in range(9):
            g["front"][0][c] = "helmet_hi"
            g["front"][2][c] = "helmet_dark"
        for f in ("back", "right", "left"):
            for c in range(len(g[f][0])):
                g[f][2][c] = "helmet_dark"
        for r in range(9):
            g["top"][r][4] = "helmet_hi"

    extras = [
        box("Helmet", "Head", (0, 31.5, 0), (9, 3, 9), "helmet", dome),
        box("HelmetBrim", "Head", (0, 30, 0), (10, 1, 10), "helmet_dark"),
        box("HelmetLamp", "Head", (0, 31.5, -5), (3, 2, 1), "lamp"),
    ]
    colours = {
        "shirt": "#a8322c", "shirt_dark": "#7a2420", "denim": "#3e5a8a", "denim_dark": "#2c4268", "button": "#d8b040",
        "glove": "#8a6a44", "boot": "#4a3626", "boot_hi": "#6a5038", "sole": "#241a12",
        "helmet": "#e6c43c", "helmet_dark": "#b8962a", "helmet_hi": "#f6dc6a", "lamp": "#fff2c0",
    }
    return o, extras, colours, [], ["lamp"]


def cook():
    """Продавец еды: a double-breasted white jacket, a red neckerchief, an apron, check trousers, a tall chef's hat."""
    o = start("short")
    put(o, "head", "front", [(2, 5), (5, 5), (1, 6), (2, 6), (5, 6), (6, 6)], "hair")  # a curled moustache
    b = o["body"]
    put(o, "body", "front", [(2, 0), (3, 0), (4, 0), (5, 0), (3, 1), (4, 1)], "scarf")
    put(o, "body", "front", [(2, 3), (5, 3), (2, 5), (5, 5), (2, 7), (5, 7)], "button")
    for r in range(1, 8):
        b["front"][r][4] = "shirt_dark" if b["front"][r][4] == "shirt" else b["front"][r][4]
    fill(o, "body", "apron", faces=("front", "right", "left"), rows=range(8, 12))
    fill(o, "body", "apron_dark", faces=SIDES, rows=[8])
    arms(o, "shirt", 10, cuff="shirt_dark")
    legs(o, "pants", 10, inner=None)
    for leg in ("rleg", "lleg"):
        for f in SIDES:
            g = o[leg][f]
            for r in range(10):
                for c in range(4):
                    if (c + r) % 2 == 0:
                        g[r][c] = "pants_check"
        fill(o, leg, "apron", faces=("front",), rows=range(7))
        fill(o, leg, "apron_dark", faces=("front",), rows=[6])

    def band(g):
        for f in SIDES:
            for c in range(len(g[f][0])):
                g[f][1][c] = "hat_dark"

    def puff(g):
        for f in SIDES:
            for c in range(1, len(g[f][0]), 2):
                for r in range(1, 5):
                    g[f][r][c] = "hat_dark"

    extras = [
        box("ChefBand", "Head", (0, 31, 0), (9, 2, 9), "hat", band),
        box("ChefHat", "Head", (0, 34.5, 0), (10, 5, 10), "hat", puff),
    ]
    colours = {
        "shirt": "#f2f2ee", "shirt_dark": "#d4d4cc", "button": "#3a3a3a", "scarf": "#c83a32",
        "apron": "#fbfbf8", "apron_dark": "#dcdcd6", "pants": "#3a3a3e", "pants_check": "#6c6c72",
        "shoe": "#1e1e1e", "sole": "#111111", "hat": "#ffffff", "hat_dark": "#e2e2dc",
    }
    return o, extras, colours, [], []


def star():
    """Обменник звёзд: a star-sprinkled purple robe with gold trim, a wizard hat."""
    o = start("short", beard=True)
    b = o["body"]
    stars = [(1, 3), (6, 5), (2, 10), (6, 10)]
    for r in range(12):
        b["front"][r][4] = "gold"
    put(o, "body", "front", [(2, 0), (3, 0), (5, 0)], "gold_dark")
    put(o, "body", "front", stars, "star")
    put(o, "body", "back", [(2, 2), (5, 6), (1, 9), (6, 10)], "star")
    fill(o, "body", "gold_dark", rows=[8])
    put(o, "body", "front", [(3, 8), (4, 8)], "gold")
    arms(o, "shirt", 10, cuff="gold")
    for arm in ("rarm", "larm"):
        put(o, arm, "front", [(1, 3), (2, 7)], "star")
        put(o, arm, OUTER[arm], [(2, 2), (1, 6)], "star")
    legs(o, "shirt", 10, shoe="shirt_dark")

    def skirt_stars(g):
        put_g = [(1, 2), (7, 4), (2, 7), (6, 1)]
        for c, r in put_g:
            g["front"][r][c] = "star"
            g["back"][r][c] = "star"

    def tier(band_row=None, spots=()):
        def paint(g):
            if band_row is not None:
                for f in SIDES:
                    for c in range(len(g[f][0])):
                        g[f][band_row][c] = "gold"
            for f, c, r in spots:
                g[f][r][c] = "star"
        return paint

    extras = [
        skirt("shirt", "gold", "gold", skirt_stars),
        box("HatBrim", "Head", (0, 31.5, 0), (11, 1, 11), "shirt_dark"),
        box("Hat1", "Head", (0, 33, 0.5), (9, 2, 9), "shirt", tier(1)),
        box("Hat2", "Head", (0, 35, 1), (7, 2, 7), "shirt", tier(None, [("front", 2, 0), ("left", 4, 1)])),
        box("Hat3", "Head", (0, 37, 1.5), (5, 2, 5), "shirt", tier(None, [("front", 3, 1)])),
        box("Hat4", "Head", (0, 39, 2.5), (3, 2, 3), "shirt"),
        box("HatTip", "Head", (0, 40.5, 3.5), (1, 1, 1), "star"),
    ]
    colours = {
        "shirt": "#3a2a6e", "shirt_dark": "#281c50", "gold": "#e8c048", "gold_dark": "#b08a28", "star": "#fff0a0",
        "sole": "#1a1236",
    }
    return o, extras, colours, [], []


def shard():
    """Обменник осколков: a gem trader in an open red vest over a cream shirt, a bandana, a satchel, a shard on the belt."""
    o = start("fringe")
    b = o["body"]
    for r in range(1, 10):
        for c in (0, 1, 2, 5, 6, 7):
            b["front"][r][c] = "vest"
    fill(o, "body", "vest", faces=("back", "right", "left"), rows=range(0, 10))
    put(o, "body", "front", [(2, 3), (2, 5), (2, 7)], "gold")
    put(o, "body", "front", [(6, 1), (5, 2), (4, 3), (3, 4), (2, 5), (1, 6)], "strap")
    put(o, "body", "back", [(1, 1), (2, 2), (3, 3), (4, 4), (5, 5), (6, 6)], "strap")
    fill(o, "body", "strap", rows=[9])
    for r in (9, 10, 11):
        for c in (0, 1):
            b["front"][r][c] = "pouch"
    put(o, "body", "front", [(1, 10)], "gem")
    put(o, "body", "front", [(3, 0), (4, 0)], "skin")
    arms(o, "shirt", 9, cuff="shirt_dark")
    put(o, "rarm", "front", [(0, 9), (1, 9), (2, 9), (3, 9)], "gold")
    legs(o, "pants", 7, shoe="boot", inner="pants_dark", toe="boot_hi")
    h = o["head"]
    for f in SIDES:
        for c in range(8):
            h[f][1][c] = "band"
            h[f][2][c] = "band_dark" if f == "back" and c in (3, 4) else "band"
    put(o, "head", "back", [(3, 3), (4, 3), (3, 4), (5, 4)], "band_dark")
    put(o, "head", "right", [(5, 6)], "gold")
    colours = {
        "shirt": "#e6d8b0", "shirt_dark": "#c4b48a", "vest": "#8c2a26", "gold": "#e0b840", "strap": "#5a3c22",
        "pouch": "#7a5634", "gem": "#6ad8e8", "pants": "#4a3a2e", "boot": "#2e241c", "boot_hi": "#4a3a2c",
        "sole": "#1a140e", "band": "#c03030", "band_dark": "#8a2020",
    }
    return o, [], colours, [], []


def trainer():
    """Тренер: a red tracksuit with a white stripe, a sweatband, a whistle on a cord, white trainers."""
    o = start("buzz")
    b = o["body"]
    put(o, "body", "front", [(2, 0), (5, 0)], "shirt_dark")
    put(o, "body", "front", [(3, 0), (4, 0)], "skin")
    for r in range(1, 8):
        b["front"][r][3] = "zip"
    put(o, "body", "front", [(2, 1), (5, 1), (2, 2), (5, 2)], "cord")
    put(o, "body", "front", [(4, 3), (4, 4)], "whistle")
    fill(o, "body", "shirt_dark", rows=[8])
    for side in ("right", "left"):
        for r in range(8):
            b[side][r][1] = b[side][r][2] = "stripe"
    arms(o, "shirt", 10, cuff="shirt_dark")
    for arm in ("rarm", "larm"):
        for r in range(9):
            o[arm][OUTER[arm]][r][1] = o[arm][OUTER[arm]][r][2] = "stripe"
    legs(o, "shirt", 9, inner="shirt_dark")
    for leg in ("rleg", "lleg"):
        for r in range(9):
            o[leg][OUTER[leg]][r][1] = o[leg][OUTER[leg]][r][2] = "stripe"
        fill(o, leg, "sole", rows=[11])
    h = o["head"]
    for f in SIDES:
        for c in range(8):
            h[f][2][c] = "band"
    colours = {
        "shirt": "#c8322a", "shirt_dark": "#962220", "stripe": "#f2f2f2", "zip": "#d8d8d8", "cord": "#303030",
        "whistle": "#c8c8d0", "shoe": "#f0f0f0", "sole": "#a8a8a8", "band": "#f2f2f2",
    }
    return o, [], colours, [], []


def clerk():
    """Задания: an office clerk — a light blue shirt and tie, glasses, a belt, a clipboard in the left hand."""
    o = start("short")
    h = o["head"]["front"]
    for c in (1, 2, 5, 6):  # round frames: above and below each eye, the sides and the bridge beside it
        h[3][c] = h[5][c] = "glasses"
    for c in (0, 3, 4, 7):
        h[4][c] = "glasses"
    b = o["body"]
    put(o, "body", "front", [(2, 0), (5, 0)], "collar")
    put(o, "body", "front", [(3, 0), (4, 0)], "tie_dark")
    for r in range(1, 7):
        b["front"][r][3] = b["front"][r][4] = "tie"
    put(o, "body", "front", [(3, 7)], "tie")
    put(o, "body", "front", [(5, 2), (6, 2)], "shirt_dark")
    put(o, "body", "front", [(6, 1)], "pen")
    fill(o, "body", "belt", rows=[8])
    put(o, "body", "front", [(3, 8), (4, 8)], "buckle")
    arms(o, "shirt", 10, cuff="shirt_dark")
    legs(o, "pants", 10, inner="pants_dark")

    def board(g):
        for r in range(1, 5):
            for c in range(4):
                g["left"][r][c] = "paper"
        for r in (2, 3):
            for c in (1, 2):
                g["left"][r][c] = "ink"
        g["left"][0][1] = g["left"][0][2] = "clip"

    extras = [box("Clipboard", "LeftHand", (-8.5, 13, -0.5), (1, 5, 4), "board", board)]
    colours = {
        "shirt": "#a8c4e0", "shirt_dark": "#86a2c0", "collar": "#f0f0f0", "tie": "#1e2c50", "tie_dark": "#141e38",
        "pen": "#2848c8", "belt": "#4a3220", "buckle": "#c8a040", "pants": "#2a2a30", "shoe": "#1a1a1a",
        "sole": "#0e0e0e", "glasses": "#3a3a46", "board": "#8a6236", "paper": "#f0ece0", "clip": "#b0b0b0",
    }
    return o, extras, colours, [], []


def guard():
    """Охранник: a navy uniform with pockets, a badge and a radio, a belt and a baton, a peaked cap."""
    o = start("buzz")
    b = o["body"]
    put(o, "body", "front", [(2, 0), (5, 0)], "shirt_dark")
    put(o, "body", "front", [(3, 0), (4, 0), (3, 1), (4, 1)], "tie")
    put(o, "body", "front", [(1, 2), (2, 2), (5, 2), (6, 2)], "shirt_dark")
    put(o, "body", "front", [(1, 3), (2, 3)], "shirt_hi")
    put(o, "body", "front", [(5, 3), (6, 3)], "badge")
    for r in range(2, 8):
        b["front"][r][4] = "shirt_dark" if b["front"][r][4] == "shirt" else b["front"][r][4]
    put(o, "body", "front", [(0, 1), (0, 2)], "radio")
    fill(o, "body", "belt", rows=[8])
    put(o, "body", "front", [(3, 8), (4, 8)], "buckle")
    arms(o, "shirt", 10, cuff="shirt_dark")
    for arm in ("rarm", "larm"):
        out_face = OUTER[arm]
        o[arm][out_face][1][1] = o[arm][out_face][1][2] = "badge"  # the shoulder patch
        o[arm]["top"] = grid(4, 4, "shirt_hi")
    legs(o, "shirt", 9, shoe="boot", inner="shirt_dark", toe="boot_hi")
    for leg in ("rleg", "lleg"):
        for r in range(9):
            o[leg][OUTER[leg]][r][1] = "stripe"

    def crown(g):
        for f in SIDES:
            for c in range(len(g[f][0])):
                g[f][2][c] = "band"
        g["front"][1][4] = "badge"

    def visor(g):
        for c in range(9):
            g["front"][0][c] = "visor"

    extras = [
        box("Cap", "Head", (0, 31.5, 0), (9, 3, 9), "cap", crown),
        box("CapTop", "Head", (0, 33, 0), (10, 1, 10), "cap"),
        box("CapVisor", "Head", (0, 30, -5.5), (9, 1, 3), "visor", visor),
        box("Baton", "LowerTorso", (3, 11, -2.5), (1, 6, 1), "visor"),
    ]
    colours = {
        "shirt": "#283c64", "shirt_dark": "#1c2a48", "shirt_hi": "#3a5284", "tie": "#141414", "badge": "#e0c050",
        "radio": "#303030", "belt": "#1a1a1a", "buckle": "#c0c0c0", "stripe": "#5a78b0", "boot": "#161616",
        "boot_hi": "#2e2e2e", "sole": "#0c0c0c", "cap": "#22345a", "band": "#141414", "visor": "#101010",
    }
    return o, extras, colours, [], []


def gatekeeper():
    """Привратник (Врата): a white robe with gold trim, a long white beard, sandals, a golden halo."""
    o = start("short")
    h = o["head"]
    put(o, "head", "front", [(1, 5), (2, 5), (5, 5), (6, 5)], "hair")
    put(o, "head", "front", [(c, 6) for c in range(8) if c not in (3, 4)], "hair")
    put(o, "head", "front", [(c, 7) for c in range(8)], "hair")
    for face in ("right", "left"):
        for c in player.side_cols(face, True):
            for r in (5, 6, 7):
                h[face][r][c] = "hair"
    b = o["body"]
    for r in range(12):
        b["front"][r][4] = "gold_dark"
    put(o, "body", "front", [(c, r) for r in (0, 1, 2) for c in range(2, 6)] + [(3, 3), (4, 3)], "hair")
    fill(o, "body", "gold", rows=[8])
    arms(o, "shirt", 10, cuff="gold")
    legs(o, "shirt", 10, shoe="sandal")
    for leg in ("rleg", "lleg"):
        put(o, leg, "front", [(1, 11), (2, 11)], "skin")

    halo = []
    for name, centre, size in (
        ("HaloFront", (0, 34.5, -3.5), (8, 0.6, 1)),
        ("HaloBack", (0, 34.5, 3.5), (8, 0.6, 1)),
        ("HaloRight", (3.5, 34.5, 0), (1, 0.6, 6)),
        ("HaloLeft", (-3.5, 34.5, 0), (1, 0.6, 6)),
    ):
        halo.append(box(name, "Head", centre, size, "halo"))
    extras = [skirt("shirt", "gold", "gold_dark")] + halo
    colours = {
        "shirt": "#f6f4ec", "shirt_dark": "#dcd8c8", "gold": "#e8c048", "gold_dark": "#c8a03c", "sandal": "#a07850",
        "sole": "#6a4c30", "halo": "#fff2a0", "hair": "#ececec", "hair_dark": "#c8c8c8", "brow": "#c8c8c8",
    }
    return o, extras, colours, [], ["halo"]


def cultist():
    """Культист (Долина лепреконов): a green hooded robe, a rope belt, an amulet, the face in the hood's shadow."""
    o = start("bald")
    h = o["head"]["front"]
    for c in range(8):
        h[1][c] = "shade"
        h[2][c] = "skin_dark"
    b = o["body"]
    put(o, "body", "front", [(2, 0), (5, 0), (2, 1), (5, 1), (3, 2)], "rope")
    put(o, "body", "front", [(3, 3), (4, 3)], "amulet")
    fill(o, "body", "rope", rows=[8])
    put(o, "body", "front", [(3, 9), (3, 10)], "rope")
    for r in range(12):
        b["front"][r][4] = "shirt_dark" if b["front"][r][4] == "shirt" else b["front"][r][4]
    arms(o, "shirt", 10, cuff="shirt_dark")
    legs(o, "shirt", 10, shoe="shoe")

    def rim(g):
        for f in ("right", "left"):
            near = 0 if f == "left" else len(g[f][0]) - 1  # the edge nearer the face
            for r in range(len(g[f])):
                g[f][r][near] = "shirt_dark"

    extras = [
        skirt("shirt", "shirt_dark"),
        box("HoodTop", "Head", (0, 32.5, 0), (10, 1, 10), "shirt"),
        box("HoodBack", "Head", (0, 28, 4.5), (10, 8, 1), "shirt"),
        box("HoodRight", "Head", (4.5, 28, -0.5), (1, 8, 9), "shirt", rim),
        box("HoodLeft", "Head", (-4.5, 28, -0.5), (1, 8, 9), "shirt", rim),
        box("HoodRim", "Head", (0, 31.5, -4.5), (8, 1, 1), "shirt_dark"),
    ]
    colours = {
        "shirt": "#24422a", "shirt_dark": "#182e1c", "rope": "#b09a68", "amulet": "#c8a040", "shade": "#2a2018",
        "shoe": "#2a2016", "sole": "#16100a",
    }
    return o, extras, colours, [], []


COSTUMES = {
    "buyer": buyer, "miner": miner, "cook": cook, "star": star, "shard": shard,
    "trainer": trainer, "clerk": clerk, "guard": guard, "gatekeeper": gatekeeper, "cultist": cultist,
}
# roles every costume shares unless it sets its own (the face of player.py; skin and hair are varied per NPC)
COMMON = {"eye_white": "#f4f4f4", "ink": "#2b2b2b", "pants_dark": None, "shirt_dark": None, "denim_dark": None}


def shade(hexcol, k=0.78):
    v = [int(hexcol[i:i + 2], 16) for i in (1, 3, 5)]
    return "#%02x%02x%02x" % tuple(int(x * k) for x in v)


def part_centre(name):
    limb, r0, r1, _ = PARTS[name]
    (cx, cy, cz), (_, sy, _) = LIMBS[limb]
    return [cx, cy + sy / 2 - (r0 + r1) / 2, cz]


# ---------------------------------------------------------------- export for the game
def export():
    costumes = {}
    for cid, make in COSTUMES.items():
        grids, extras, colours, vary, glow = make()
        parts = {}
        used = set()
        for name, (limb, r0, r1, ends) in PARTS.items():
            faces = cut(grids[limb], limb, r0, r1, ends)
            counts = {}
            for g in faces.values():
                for row in g:
                    for role in row:
                        counts[role] = counts.get(role, 0) + 1
                        used.add(role)
            main = max(counts, key=counts.get)
            parts[name] = {"base": main, "faces": {f: rects(g, main) for f, g in faces.items() if rects(g, main)}}
        out_extras = []
        for e in extras:
            used.add(e["base"])
            item = {"name": e["name"], "part": e["part"], "size": list(e["size"]), "base": e["base"]}
            pc = part_centre(e["part"])
            item["pos"] = [e["centre"][i] - pc[i] for i in range(3)]
            if e["paint"]:
                g = faces_of(e["size"], e["base"])
                e["paint"](g)
                item["faces"] = {f: rects(gg, e["base"]) for f, gg in g.items() if rects(gg, e["base"])}
                for gg in g.values():
                    for row in gg:
                        used.update(row)
            out_extras.append(item)
        # the palette: the costume's own roles, darker shades derived where it set none; skin, hair and the face
        # roles come from the player's palettes in the game (NpcBodyService)
        palette = {}
        for role in sorted(used):
            if role in colours:
                palette[role] = colours[role].lstrip("#")
            elif role.endswith("_dark") and role[:-5] in colours:
                palette[role] = shade(colours[role[:-5]]).lstrip("#")
            elif role in COMMON and COMMON[role]:
                palette[role] = COMMON[role].lstrip("#")
        missing = [r for r in used if r not in palette and r not in ("skin", "skin_dark", "mouth", "hair", "hair_dark", "brow", "iris")]
        assert not missing, (cid, missing)
        costumes[cid] = {"parts": parts, "extras": out_extras, "colours": palette, "vary": vary, "glow": glow}
    data = {
        "source": "assets/models/npc/npc.py: our NPC costumes on the player body (src/shared/Models/player.json gives the "
        "parts' sizes and positions). parts[name] = base role + [col, row, w, h, role] per face (face grids as in "
        "player.py); extras = boxes carried by a part: pos = centre relative to that part's centre, size, px; colours = "
        "role → hex (skin, hair and the face roles come from the player's palettes); vary = roles the game takes from "
        "the NPC's own R15 colours; glow = Neon roles",
        "px": PX,
        "costumes": costumes,
    }
    path = os.path.join(ROOT, "src", "shared", "Models", "npcs.json")
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
    n = {cid: sum(len(r) for p in c["parts"].values() for r in p["faces"].values()) + len(c["extras"]) for cid, c in costumes.items()}
    print("exported npcs →", path, n)
    return data


# ---------------------------------------------------------------- renders: the JSON built the way the game builds it
def costume_boxes(body, costume, colours):
    plate, out = 0.02, []

    def plates(centre, size, base, faces):
        out.append((centre, [v * PX for v in size], colours[base]))
        half = [v * PX / 2 for v in size]
        for face, (tl, right, down, normal) in player.GAME_FACES.items():
            for c, r, rw, rh, role in faces.get(face, []):
                local = [tl[i] * half[i] + right[i] * (c + rw / 2) * PX + down[i] * (r + rh / 2) * PX + normal[i] * plate / 2 for i in range(3)]
                sz = [abs(right[i]) * rw * PX + abs(down[i]) * rh * PX + abs(normal[i]) * plate for i in range(3)]
                out.append(([centre[i] + local[i] for i in range(3)], sz, colours[role]))

    for name, part in costume["parts"].items():
        b = body["parts"][name]
        plates([v * PX for v in b["pos"]], b["size"], part["base"], part["faces"])
    for e in costume["extras"]:
        pc = body["parts"][e["part"]]["pos"]
        plates([(pc[i] + e["pos"][i]) * PX for i in range(3)], e["size"], e["base"], e.get("faces", {}))
    return out


SAMPLES = {  # skin, hair per costume for the renders (the game picks them per NPC)
    "buyer": (1, 1), "miner": (2, 0), "cook": (0, 2), "star": (1, 4), "shard": (3, 5),
    "trainer": (3, 0), "clerk": (0, 1), "guard": (2, 5), "gatekeeper": (0, 4), "cultist": (1, 0),
}


def render(data):
    import bpy
    from mathutils import Vector

    sys.path.insert(0, os.path.dirname(HERE))
    from voxeltool import look, setup

    body = player.load_body()
    scene, cam = setup(600, 800)
    mid = Vector((0, 0, 20 * PX))
    for cid, costume in data["costumes"].items():
        skin, hair = SAMPLES[cid]
        colours = player.check_colours(body, skin, hair, 1)
        colours.update({k: "#" + v for k, v in costume["colours"].items()})
        player.clear_meshes()
        player.add_boxes(costume_boxes(body, costume, colours), cid)
        for view, loc in (("front", (0, -20, 20 * PX)), ("34", (-11, -14, 20 * PX + 3.5)), ("back", (0, 20, 20 * PX))):
            look(cam, Vector(loc), mid, 8.4, None)
            scene.render.filepath = os.path.join(HERE, "render-%s-%s.png" % (cid, view))
            bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    data = export()
    if sys.argv[-1] != "export":
        render(data)
