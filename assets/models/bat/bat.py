# The bat mob (Подвал, База фракций) made in Blender [владелец 26.10: «да, делай» — модель и анимации из Blender по
# картинке от Codex]. Reference: assets/models/bat/bat-reference.png (Codex image gen, the rat sheet as the style
# reference: side / front / top / three-quarter on a 1536×1024 sheet). Our own design: a small dark brown-grey
# furry body, a lighter blocky head with pointed ears, tiny red glowing eyes, fangs, three-segment leathery wings
# with lighter bone ribs, tiny feet. Pipeline: assets/models/blockmob.py (skill .claude/skills/blender-block-mob,
# method A — hand boxes).
#
#   blender -b -P assets/models/bat/bat.py -- build
#   blender -b assets/models/bat/bat.blend -P assets/models/bat/bat.py -- export | compare
#
# Blender space: X = the mob's left (…L), Y forward, Z up. The model's origin (0, 0, 0) is the BODY'S BOTTOM CENTRE:
# the bat hangs under a hovering root (MobService: cfg.flying, hipHeight, modelOffset), so nothing stands on it.
# Sizes off the front view at 155 px a stud (centre x 1093, body bottom y 365: X = (1093 − x) / 155,
# Z = (365 − y) / 155) and the side view (body bottom y 385); the body follows the brief (1.0 × 1.0 × 1.2 studs)
# and the wings are scaled to a 4.5-stud span (the sheet's are ≈ 5.3). The sheet's top view sweeps the wings
# forward while its side view sweeps them back (AI views disagree): the wings take a slight back sweep.
#
# Wings: wingL1 (inner arm) → wingL2 (outer) → wingL3 (tip), mirrored to …R. The rest pose is the front view's:
# the inner and outer segments rise 30°, the tip droops 20°. Each segment is a bone along its leading edge
# (lighter, with a knuckle cube), a thin membrane plate behind it whose trailing edge steps in pixel columns, and a
# rib fanning across the membrane. The parts are placed in that rest pose (the joints themselves carry no rest
# rotation), so a flap is a rotation about Y at the segment's pivot.
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from blockmob import box, default_noise, mirrored, run  # noqa: E402
from mathutils import Matrix, Vector  # noqa: E402

NAME = "bat"
HERE = os.path.dirname(os.path.abspath(__file__))
NOISE_FILE = "noise.png"
TILE_STUDS = 1.0  # a small mob: finer fur grain than the rat
# dark low-saturation browns grey out under Roblox's cool sky like the rat's fur
GAME_LIFT = {"saturate": 1.5, "gain": 1.12}
GLOW_STRENGTH = 2.2


def NOISE():
    return default_noise(seed=19, depth=0.16, jitter=(-0.1, 0.07), floor=0.66)


# the brief's palette [владелец 26.10]
FUR = (0x4A, 0x3B, 0x33)
FUR_DARK = (0x3A, 0x2E, 0x28)
HEAD = (0x5A, 0x47, 0x3D)
HEAD_LIGHT = (0x66, 0x52, 0x47)  # muzzle and brow, a step lighter than the head
WING = (0x2E, 0x24, 0x20)
RIB = (0x6B, 0x56, 0x49)
EYE = (0xC0, 0x30, 0x2A)
FANG = (0xEE, 0xE8, 0xDC)
NOSE = (0x26, 0x1D, 0x19)
FOOT = (0x2A, 0x21, 0x1D)

# ------------------------------------------------------------------ wings (left; the right is mirrored)
WING_ROOT = Vector((0.46, 0.04, 0.84))
# segment: (length, dihedral° up, sweep° (− = back), chord at the start, chord at the end, columns)
SEGMENTS = [
    (0.42, 30, 0, 0.64, 0.74, 2),
    (0.84, 30, -8, 0.74, 0.58, 5),
    (0.86, -20, -18, 0.58, 0.08, 6),
]
BONE = 0.09  # the leading-edge bone's thickness
MEMBRANE = 0.045
HANG = 50  # the membrane hangs back and down from the bone by this much (never edge-on from the usual views)


def seg_matrix(dihedral, sweep):
    # tilt up about Y (R_y(−θ) raises +X), then sweep about Z
    return Matrix.Rotation(math.radians(sweep), 3, "Z") @ Matrix.Rotation(math.radians(-dihedral), 3, "Y")


def placed(name, joint, pivot, R, local_centre, size, colour, local_yaw=0.0, glow=False):
    # a box given in a frame R at pivot (segment: x along the bone, y forward, z up) placed in the rest pose
    M = R @ Matrix.Rotation(math.radians(local_yaw), 3, "Z")
    centre = pivot + R @ Vector(local_centre)
    rot = tuple(math.degrees(a) for a in M.to_euler("XYZ"))
    return (name, joint, tuple(centre), size, colour, None, rot, {"glow": True} if glow else {})


def wing_left():
    parts, joints = [], []
    pivot = WING_ROOT.copy()
    parent = "body"
    for i, (length, dih, sweep, c0, c1, cols) in enumerate(SEGMENTS):
        j = "wingL%d" % (i + 1)
        joints.append((j, parent, tuple(pivot)))
        R = seg_matrix(dih, sweep)
        Rm = R @ Matrix.Rotation(math.radians(HANG), 3, "X")  # the membrane plane
        n = i + 1
        # the bone along the leading edge (a little past both ends so the segments overlap at the knuckles)
        parts.append(placed("Bone%dL" % n, j, pivot, R, (length / 2, 0, 0), (length + 0.06, BONE, BONE), RIB))
        # the knuckle cube at the segment's start (the shoulder one is hidden in the fur)
        if i > 0:
            parts.append(placed("Knuckle%dL" % n, j, pivot, R, (0, 0, 0.01), (0.14, 0.14, 0.14), RIB))
        # the membrane: columns along the bone, each a plate from the bone back to its chord (stepped edge)
        w = length / cols
        for k in range(cols):
            f = (k + 0.5) / cols
            chord = c0 + (c1 - c0) * f
            parts.append(placed("Membrane%d_%dL" % (n, k + 1), j, pivot, Rm,
                                (w * (k + 0.5), -BONE / 2 - chord / 2 + 0.01, -0.01),
                                (w + 0.005, chord, MEMBRANE), WING))
        # a rib fanning back-outward across the membrane from the segment's start
        tip_x, tip_y = length * (0.75 if i < 2 else 0.55), -(c0 + c1) / 2 * (0.9 if i < 2 else 0.8)
        rl = math.hypot(tip_x, tip_y)
        yaw = math.degrees(math.atan2(tip_y, tip_x))
        parts.append(placed("Rib%dL" % n, j, pivot, Rm, (tip_x / 2, tip_y / 2 - 0.02, 0.0),
                            (rl, 0.06, MEMBRANE + 0.03), RIB, local_yaw=yaw))
        # the next pivot at the end of this bone
        pivot = pivot + R @ Vector((length, 0, 0))
        parent = j
        if i == len(SEGMENTS) - 1:
            # the claw cube at the very tip
            parts.append(placed("ClawL", j, pivot - R @ Vector((length, 0, 0)), R, (length + 0.02, 0, 0.01),
                                (0.12, 0.12, 0.12), RIB))
    return parts, joints


WING_PARTS, WING_JOINTS = wing_left()

JOINTS = [
    ("root", None, (0, 0, 0)),
    ("body", "root", (0, 0, 0.5)),  # the body's centre: it tumbles about it
    ("head", "body", (0, 0.5, 0.62)),
    ("earL", "head", (0.3, 0.72, 1.12)),
    ("earR", "head", (-0.3, 0.72, 1.12)),
    ("footL", "body", (0.26, -0.18, 0.02)),
    ("footR", "body", (-0.26, -0.18, 0.02)),
]
JOINTS += WING_JOINTS
JOINTS += [(n.replace("L", "R"), p.replace("L", "R"), (-c[0], c[1], c[2])) for n, p, c in WING_JOINTS]


def ear(side):
    parts = [
        # wide stepped ears (front view: base 0.3 wide, tip at z ≈ 1.58), the outer edge rising higher than the inner
        *box("EarBase", "ear*", (0.14, 0.48), (0.6, 0.84), (1.1, 1.28), HEAD, FUR_DARK, mirror=True),
        *box("EarMid", "ear*", (0.19, 0.46), (0.62, 0.8), (1.28, 1.44), HEAD, FUR_DARK, mirror=True),
        *box("EarTip", "ear*", (0.3, 0.44), (0.65, 0.77), (1.44, 1.6), FUR_DARK, FUR_DARK, mirror=True),
        *box("EarIn", "ear*", (0.2, 0.42), (0.84, 0.86), (1.14, 1.28), FUR_DARK, mirror=True),
        *box("EarInMid", "ear*", (0.24, 0.41), (0.8, 0.82), (1.28, 1.4), FUR_DARK, mirror=True),
    ]
    return [p for p in parts if p[0].endswith(side)]


PARTS = [
    # body: a furry block, rounded by narrower plates on top, below, at the chest and the rump; darker back
    *box("Body", "body", (-0.5, 0.5), (-0.55, 0.5), (0.1, 0.9), FUR, FUR_DARK),
    *box("BodyTop", "body", (-0.42, 0.42), (-0.5, 0.44), (0.9, 1.0), FUR_DARK, FUR_DARK),
    *box("Belly", "body", (-0.4, 0.4), (-0.46, 0.42), (0.0, 0.1), FUR),
    *box("Chest", "body", (-0.4, 0.4), (0.5, 0.6), (0.14, 0.8), FUR),
    *box("Rump", "body", (-0.38, 0.38), (-0.62, -0.55), (0.18, 0.8), FUR, FUR_DARK),
    *box("BackPatch", "body", (-0.22, 0.14), (-0.36, 0.12), (1.0, 1.03), FUR_DARK, FUR_DARK),
    *box("SideTuft", "body", (0.5, 0.53), (-0.36, 0.06), (0.3, 0.62), FUR_DARK, mirror=True),
    *box("Shoulder", "body", (0.42, 0.54), (-0.12, 0.2), (0.7, 0.96), FUR_DARK, FUR_DARK, mirror=True),
    # head: a lighter block, the darker crown, a brow step, the muzzle with a dark nose, red eyes, two fangs
    *box("Head", "head", (-0.38, 0.38), (0.45, 1.1), (0.3, 1.12), HEAD, FUR),
    *box("Brow", "head", (-0.34, 0.34), (1.1, 1.14), (0.82, 1.02), HEAD_LIGHT, HEAD_LIGHT),
    *box("Muzzle", "head", (-0.18, 0.18), (1.1, 1.24), (0.38, 0.66), HEAD_LIGHT, HEAD_LIGHT),
    *box("Nose", "head", (-0.08, 0.08), (1.24, 1.27), (0.55, 0.64), NOSE),
    *box("Chin", "head", (-0.26, 0.26), (0.7, 1.08), (0.24, 0.3), FUR_DARK),
    *box("Eye", "head", (0.19, 0.31), (1.1, 1.13), (0.52, 0.64), EYE, mirror=True, glow=True),
    *box("Fang", "head", (0.09, 0.16), (1.15, 1.21), (0.22, 0.38), FANG, mirror=True),
    *ear("L"),
    *ear("R"),
    # tiny feet under the rear of the body: a leg stub and a claw plate
    *box("Leg", "foot*", (0.2, 0.32), (-0.25, -0.12), (-0.12, 0.02), FOOT, mirror=True),
    *box("Toes", "foot*", (0.19, 0.33), (-0.27, -0.08), (-0.18, -0.12), FOOT, mirror=True),
]
PARTS += WING_PARTS
PARTS += mirrored(WING_PARTS)


# ------------------------------------------------------------------ the animations
# key(frame, {joint: (rx, ry, rz in degrees, optional (dx, dy, dz) offset)}). Signs: +X on the body leans back
# (nose up), on the head tilts up. A wing's flap is about Y: up = −ry on the left, +ry on the right (wing()).
def wing(pose, segs, sweeps=(0, 0, 0), pitch=(0, 0, 0)):
    # segs: the up-angle of each segment relative to its parent (+ = up); sweeps: about Z (+ = forward)
    for i in range(3):
        up, sw, pt = segs[i], sweeps[i], pitch[i]
        pose["wingL%d" % (i + 1)] = (pt, -up, sw, None)
        pose["wingR%d" % (i + 1)] = (pt, up, -sw, None)
    return pose


def wing_world(pose, worlds, prev):
    # set both wings from the left wing's world rotations (rest pose → wanted pose, per segment): a joint's own
    # rotation is its parent segment's world rotation undone, then its own (the joints carry no rest rotation);
    # prev keeps the Euler angles continuous from frame to frame
    parent = Matrix.Identity(3)
    for i, W in enumerate(worlds):
        L = parent.inverted() @ W
        e = L.to_euler("XYZ", prev[i]) if prev[i] else L.to_euler("XYZ")
        prev[i] = e
        a, b, c = (math.degrees(v) for v in e)
        pose["wingL%d" % (i + 1)] = (a, b, c, None)
        pose["wingR%d" % (i + 1)] = (a, -b, -c, None)
        parent = W
    return pose


def flap(t, amp, lag=0.7):
    # a wave along the wing: the outer segments follow the inner one later
    return (amp[0] * math.cos(t), amp[1] * math.cos(t - lag), amp[2] * math.cos(t - 2 * lag))


def actions():
    acts = {}
    # walk = flight: strong flaps (12 frames = 0.4 s), the body bobs ±0.25 and pitches, the head counters it
    walk = []
    for f in range(0, 13):
        t = f / 12 * math.pi * 2
        segs = flap(t, (42, 22, 30))
        pose = {
            "body": (5 * math.sin(t + 0.6) - 4, 0, 0, (0, 0, 0.25 * math.sin(t))),
            "head": (-4 * math.sin(t + 0.6) + 3, 0, 0, None),
            "earL": (-10 + 6 * math.cos(t), 0, 0, None),
            "earR": (-10 + 6 * math.cos(t), 0, 0, None),
            "footL": (-20 + 10 * math.sin(t), 0, 0, None),
            "footR": (-20 + 10 * math.sin(t), 0, 0, None),
        }
        walk.append((f, wing(pose, segs, sweeps=(4 * math.sin(t), 0, 0))))
    acts["walk"] = (walk, True)
    # idle = hover: slower, softer flaps (18 frames = 0.6 s), a gentle bob ±0.35 and a sway side to side
    idle = []
    for f in range(0, 19):
        t = f / 18 * math.pi * 2
        segs = flap(t, (32, 16, 24), lag=0.8)
        pose = {
            "body": (3 * math.sin(t + 0.5), 5 * math.sin(t), 4 * math.sin(t),
                     (0.08 * math.sin(t), 0, 0.35 * math.sin(t))),
            "head": (-2 * math.sin(t + 0.5), -4 * math.sin(t), -3 * math.sin(t), None),
            "earL": (6 * math.sin(t - 1), 0, 0, None),
            "earR": (6 * math.sin(t - 1.4), 0, 0, None),
            "footL": (-10 + 8 * math.sin(t - 0.5), 0, 0, None),
            "footR": (-10 + 8 * math.sin(t - 0.8), 0, 0, None),
        }
        idle.append((f, wing(pose, segs)))
    acts["idle"] = (idle, True)
    # bite (21 frames = 0.7 s): wings pull up and back (the wind-up), the swoop DOWN 2 and forward 1.5 lands the
    # bite at 0.33–0.4 s (the server's bite comes 0.35 s after MobWindup), the head snaps, then back up
    acts["bite"] = ([
        (0, wing({}, (0, 0, 0))),
        (5, wing({"body": (18, 0, 0, (0, -0.3, 0.35)), "head": (18, 0, 0, None), "earL": (-30, 0, 0, None),
                  "earR": (-30, 0, 0, None)}, (55, 20, 25), sweeps=(-35, -10, 0))),
        (8, wing({"body": (-20, 0, 0, (0, 0.8, -1.0)), "head": (-12, 0, 0, None), "earL": (-40, 0, 0, None),
                  "earR": (-40, 0, 0, None)}, (40, 10, 10), sweeps=(-50, -15, -10))),
        (10, wing({"body": (-28, 0, 0, (0, 1.4, -1.9)), "head": (-26, 0, 0, None), "earL": (-45, 0, 0, None),
                   "earR": (-45, 0, 0, None)}, (30, 0, 0), sweeps=(-55, -20, -10))),
        (11, wing({"body": (-22, 0, 0, (0, 1.5, -2.0)), "head": (8, 0, 0, None), "earL": (-45, 0, 0, None),
                   "earR": (-45, 0, 0, None)}, (20, -5, -10), sweeps=(-50, -15, -10))),
        (12, wing({"body": (-18, 0, 0, (0, 1.5, -2.0)), "head": (-20, 0, 0, None), "earL": (-40, 0, 0, None),
                   "earR": (-40, 0, 0, None)}, (-10, -15, -20), sweeps=(-30, -10, 0))),
        (15, wing({"body": (8, 0, 0, (0, 1.0, -1.2)), "head": (5, 0, 0, None), "earL": (-20, 0, 0, None),
                   "earR": (-20, 0, 0, None)}, (-35, -20, -25), sweeps=(0, 0, 0))),
        (18, wing({"body": (4, 0, 0, (0, 0.3, -0.3)), "head": (2, 0, 0, None)}, (35, 15, 20))),
        (21, wing({}, (0, 0, 0))),
    ], False)
    # hurt (8 frames ≈ 0.27 s = MobAnimator's HURT): a jolt back and up, the wings flung out straight and wide
    acts["hurt"] = ([
        (0, wing({}, (0, 0, 0))),
        (2, wing({"body": (24, 0, 8, (0, -0.55, 0.2)), "head": (20, 0, 0, None), "earL": (-25, 0, 0, None),
                  "earR": (-25, 0, 0, None), "footL": (25, 0, 0, None), "footR": (25, 0, 0, None)},
                 (-18, -12, 30), sweeps=(15, 5, 5))),
        (4, wing({"body": (14, 0, 4, (0, -0.4, 0.1)), "head": (10, 0, 0, None), "earL": (-15, 0, 0, None),
                  "earR": (-15, 0, 0, None)}, (-8, -6, 20), sweeps=(8, 0, 0))),
        (8, wing({}, (0, 0, 0))),
    ], False)
    # death (24 frames = 0.8 s, holds the last pose): a jolt with the wings flung up, then the wings fold flat at the
    # sides (zigzag: the arm back, the outer segment forward, the tip back), the body tumbles over onto its back
    # and DROPS 4.6 (the body's centre ends 4.1 below the origin, its back 4.6 below: on the floor); the head
    # bends to the chest so the ears lie flat instead of poking through the floor, the feet stick up
    death = [(0, wing({}, (0, 0, 0)))]
    death.append((3, wing({"body": (22, 0, 0, (0, -0.2, 0.25)), "head": (25, 0, 0, None), "earL": (-20, 0, 0, None),
                           "earR": (-20, 0, 0, None)}, (45, 20, 30))))
    # the folded wing in the body's frame: level segments lying along the side — the arm back, the outer
    # segment forward, the tip back again (dihedral 0°, sweeps −85° / 88° / −92°)
    rest = [seg_matrix(dih, sweep) for _, dih, sweep, _, _, _ in SEGMENTS]
    folded = [seg_matrix(0, sw) @ rest[i].inverted() for i, sw in enumerate((-85, 88, -92))]
    jolt, w = [], Matrix.Identity(3)
    for up in (45, 20, 30):  # the jolt pose of frame 3 as world rotations
        w = w @ Matrix.Rotation(math.radians(-up), 3, "Y")
        jolt.append(w)
    prev = [None, None, None]
    for f in range(5, 25):
        u = min(1.0, (f - 4) / 14)  # 0 → 1 over frames 5..18, then held
        e = u * u * (3 - 2 * u)
        d = min(1.0, (f - 4) / 16)
        fall = d * d  # the drop accelerates like a fall, lands at frame 20, a small bounce after
        bounce = 0.12 * math.sin(math.pi * (f - 20) / 4) if f > 20 else 0
        worlds = [jolt[k].to_quaternion().slerp(folded[k].to_quaternion(), e).to_matrix() for k in range(3)]
        pose = {
            "body": (22 * (1 - e) + 40 * math.sin(math.pi * e), 180 * e, 25 * math.sin(math.pi * e),
                     (0, -0.3 * e, 0.25 * (1 - e) - 4.6 * fall + bounce)),
            "head": (25 - 95 * e, 0, 15 * e, None),
            "earL": (-20, 0, 0, None),
            "earR": (-20, 0, 0, None),
            "footL": (40 * e, 0, 15 * e, None),
            "footR": (40 * e, 0, -15 * e, None),
        }
        death.append((f, wing_world(pose, worlds, prev)))
    acts["death"] = (death, False)
    return acts


# ------------------------------------------------------------------ cameras
PREVIEW_CAMERA = ((-4.8, 6.4, 3.4), (0, 0, 0.55), 40)
# the swoop (body 1.5 forward, 2 down) and the fall (body 4.1 down, on its back) get cameras that follow the body
PREVIEWS = [("idle", 0), ("walk", 3), ("bite", 11, ((-4.8, 7.9, 1.8), (0, 1.5, -1.25), 40)), ("hurt", 2),
            ("death", 24, ((-4.8, 6.1, -0.9), (0, -0.3, -4.25), 40))]
BACKGROUND = (0xB2, 0xB2, 0xB2)
# the reference sheet's 768×512 panels: side (head left, ≈ 165 px a stud, body centre x 320, body bottom y 385),
# front (155 px a stud, centre x 1093 → panel 325, body bottom y 365), three-quarter by eye; the top view is
# drawn with forward-swept wings (disagrees with the side view) and is not compared
COMPARE = {
    "side": ((0, -1, 0), (0, 0, 1), (0, -64 / 165, (385 - 256) / 165), 768 / 165),
    "front": ((-1, 0, 0), (0, 0, 1), (-59 / 155, 0, (365 - 256) / 155), 768 / 155),
    "34": ((-3.4, 6.0, 2.7), (-0.45, -0.5, 0.5), 47),
}

run(globals())
