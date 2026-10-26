# Shared Blender pipeline for the game's blocky mobs and bosses [владелец 22.10: «сохрани способ, как ты сделал
# крысу через Codex и Blender»; skill .claude/skills/blender-block-mob]. A mob file (assets/models/<id>/<id>.py)
# holds only data — JOINTS, PARTS, actions(), the reference-sheet cameras — and ends with blockmob.run(globals()).
#
#   blender -b -P assets/models/<id>/<id>.py -- build     → <id>.blend (boxes on joint empties + one action per
#                                                            joint per clip)
#   blender -b assets/models/<id>/<id>.blend -P assets/models/<id>/<id>.py -- export
#                                                         → src/shared/Models/<id>.json, noise.png, preview-*.png
#   blender -b assets/models/<id>/<id>.blend -P assets/models/<id>/<id>.py -- compare
#                                                         → compare-<view>.png: the reference sheet's views with
#                                                            the same cameras and scale (scripts/model-tools/cmp.cjs)
#
# Blender faces +Y with Z up; the export converts to Roblox (X, Y = Z, Z = −Y), so the model faces −Z there and
# its (0, 0, 0) is on the ground. Sizes are studs. A part is (name, joint, centre, size, colour, top colour,
# rotation in degrees[, flags]) with flags {"glow": True} for emissive parts (Neon in Roblox, no texture).
# The pixel look is one grey noise tile (noise.png) tinted per face; top faces may take their own colour.
import bpy
import json
import math
import os
import random
import sys
from mathutils import Euler, Matrix, Vector

FPS = 30
NOISE_TEXELS = 16


def deg(v):
    return math.radians(v)


def srgb(c):
    # Blender colours are linear; the JSON keeps sRGB for Roblox
    return tuple(((v / 255) / 12.92) if v / 255 <= 0.04045 else (((v / 255) + 0.055) / 1.055) ** 2.4 for v in c)


def box(name, joint, x, y, z, colour, top=None, mirror=False, glow=False, rot=(0, 0, 0)):
    # a box from coordinate ranges (x0, x1), (y0, y1), (z0, z1); mirror → an L/R pair (x given for the left,
    # "*" in the joint name becomes L / R)
    out = []
    sides = [("L", 1), ("R", -1)] if mirror else [("", 1)]
    for suffix, s in sides:
        xs = sorted((x[0] * s, x[1] * s))
        j = joint.replace("*", suffix)
        r = (rot[0], rot[1] * s, rot[2] * s)
        out.append((name + suffix, j, ((xs[0] + xs[1]) / 2, (y[0] + y[1]) / 2, (z[0] + z[1]) / 2),
                    (xs[1] - xs[0], y[1] - y[0], z[1] - z[0]), colour, top, r, {"glow": True} if glow else {}))
    return out


def turned(parts, pivot, yaw):
    # rotate a group of boxes about a vertical axis through pivot (e.g. ears looking a little outward)
    out = []
    c, s = math.cos(math.radians(yaw)), math.sin(math.radians(yaw))
    for p in parts:
        name, joint, centre, size, colour, top, rot = p[:7]
        flags = p[7] if len(p) > 7 else {}
        dx, dy = centre[0] - pivot[0], centre[1] - pivot[1]
        out.append((name, joint, (pivot[0] + dx * c - dy * s, pivot[1] + dx * s + dy * c, centre[2]), size, colour,
                    top, (rot[0], rot[1], rot[2] + yaw), flags))
    return out


def mirrored(parts):
    # the same parts on the other side (x → −x, names and joints L → R)
    out = []
    for p in parts:
        name, joint, centre, size, colour, top, rot = p[:7]
        flags = p[7] if len(p) > 7 else {}
        out.append((name.replace("L", "R") if name.endswith("L") else name + "R", joint.replace("L", "R"),
                    (-centre[0], centre[1], centre[2]), size, colour, top, (rot[0], -rot[1], -rot[2]), flags))
    return out


def default_noise(seed=7, depth=0.12, jitter=(-0.09, 0.06), floor=0.7):
    # grey texels with soft darker blotches (the rat's fur grain: lum range about ±20 %)
    rnd = random.Random(seed)
    n = NOISE_TEXELS
    blot = [[rnd.random() for _ in range(n // 4)] for _ in range(n // 4)]
    out = []
    for y in range(n):
        row = []
        for x in range(n):
            v = 0.95 - depth * blot[y // 4][x // 4] + rnd.uniform(*jitter)
            row.append(max(floor, min(1.0, v)))
        out.append(row)
    return out


def tile_mean(tile):
    return sum(sum(r) for r in tile) / (len(tile) * len(tile[0]))


# ------------------------------------------------------------------ the pipeline
class Mob:
    def __init__(self, g):
        self.g = g
        self.name = g["NAME"]
        self.here = g["HERE"]
        self.root = os.path.abspath(os.path.join(self.here, "..", "..", ".."))
        self.blend = os.path.join(self.here, self.name + ".blend")
        self.json_out = os.path.join(self.root, "src", "shared", "Models", self.name + ".json")
        self.noise_out = os.path.join(self.here, g.get("NOISE_FILE", "noise.png"))
        self.joints_def = g["JOINTS"]
        self.parts_def = g["PARTS"]
        self.tile_studs = g.get("TILE_STUDS", 2.25)
        self.noise = g.get("NOISE") or default_noise
        self.lift = g.get("GAME_LIFT", {"saturate": 1.0, "gain": 1.0})

    def log(self, *a):
        print("[%s]" % self.name, *a)

    # ---------------------------------------------------------------- build
    def fur_image(self, colour, tile):
        key = "Fur_%02x%02x%02x" % colour
        img = bpy.data.images.get(key)
        if img:
            return img
        n = NOISE_TEXELS
        img = bpy.data.images.new(key, n, n)
        rgb = [c / 255 for c in colour]  # the image is sRGB: store sRGB values
        mean = tile_mean(tile)
        px = []
        for y in range(n):
            for x in range(n):
                v = tile[y][x] / mean
                px += [min(1.0, c * v) for c in rgb] + [1.0]
        img.pixels = px
        img.pack()
        return img

    def material(self, colour, tile, mats, glow=False):
        key = (colour, glow)
        if key in mats:
            return mats[key]
        m = bpy.data.materials.new(("Glow_" if glow else "Mat_") + "%02x%02x%02x" % colour)
        m.diffuse_color = srgb(colour) + (1.0,)
        m.use_nodes = True
        nodes = m.node_tree.nodes
        bsdf = nodes.get("Principled BSDF")
        if glow:
            bsdf.inputs["Base Color"].default_value = srgb(colour) + (1.0,)
            bsdf.inputs["Emission Color"].default_value = srgb(colour) + (1.0,)
            bsdf.inputs["Emission Strength"].default_value = self.g.get("GLOW_STRENGTH", 1.6)
        else:
            tex = nodes.new("ShaderNodeTexImage")
            tex.image = self.fur_image(colour, tile)
            tex.interpolation = "Closest"
            m.node_tree.links.new(tex.outputs["Color"], bsdf.inputs["Base Color"])
            nodes.active = tex
        mats[key] = m
        return m

    def uv_boxes(self, cube, offset):
        # every face gets texels of the same size in studs (tile_studs a tile), shifted per part
        me = cube.data
        uv = me.uv_layers.active or me.uv_layers.new()
        for poly in me.polygons:
            nrm = poly.normal
            axis = max(range(3), key=lambda a: abs(nrm[a]))
            a, b = [(1, 2), (0, 2), (0, 1)][axis]
            for li in poly.loop_indices:
                co = me.vertices[me.loops[li].vertex_index].co + cube.location
                uv.data[li].uv = ((co[a] + offset) / self.tile_studs, (co[b] + offset * 0.7) / self.tile_studs)

    def build(self):
        bpy.ops.wm.read_factory_settings(use_empty=True)
        scene = bpy.context.scene
        scene.render.fps = FPS
        tile = self.noise()
        joints = {}
        pivots = {n: Vector(p) for n, _, p in self.joints_def}
        for name, parent, pv in self.joints_def:
            e = bpy.data.objects.new("Joint_" + name, None)
            e.empty_display_type = "SPHERE"
            e.empty_display_size = 0.15
            e.rotation_mode = "XYZ"
            scene.collection.objects.link(e)
            if parent:
                e.parent = joints[parent]
                e.location = Vector(pv) - pivots[parent]
            else:
                e.location = Vector(pv)
            e["pivot"] = list(pv)
            joints[name] = e
        if self.g.get("SCULPT"):
            # a voxel sculpture from the reference's front + side views (assets/models/voxelsculpt.py)
            sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
            import voxelsculpt
            faces = voxelsculpt.build_meshes(os.path.join(self.here, self.g["SCULPT"]), joints, pivots, srgb)
            self.log("sculpt", faces, "faces")
        mats = {}
        rnd = random.Random(3)
        for p in self.parts_def:
            name, joint, centre, size, colour, top, rot = p[:7]
            flags = p[7] if len(p) > 7 else {}
            glow = bool(flags.get("glow"))
            bpy.ops.mesh.primitive_cube_add(size=1)
            cube = bpy.context.active_object
            cube.name = "Part_" + name
            cube.scale = size
            bpy.ops.object.transform_apply(scale=True)
            cube.parent = joints[joint]
            cube.location = Vector(centre) - pivots[joint]
            cube.rotation_euler = Euler([deg(v) for v in rot], "XYZ")
            cube.data.materials.append(self.material(colour, tile, mats, glow))
            if top and top != colour and not glow:
                cube.data.materials.append(self.material(top, tile, mats))
                for poly in cube.data.polygons:
                    if poly.normal.z > 0.9:
                        poly.material_index = 1
            self.uv_boxes(cube, rnd.uniform(0, self.tile_studs))
            cube["colour"] = list(colour)
            if top:
                cube["top"] = list(top)
            if glow:
                cube["glow"] = True
        for clip, (keys, loop) in self.g["actions"]().items():
            for name, _, _ in self.joints_def:
                e = joints[name]
                act = bpy.data.actions.new("%s|%s" % (clip, name))
                act["loop"] = loop
                act.use_fake_user = True  # unassigned actions are not saved otherwise
                act["frames"] = [frame for frame, _ in keys]
                use(e, act)
                base = e.location.copy()
                for frame, pose_ in keys:
                    rx, ry, rz, off = pose_.get(name, (0, 0, 0, None))
                    e.rotation_euler = Euler((deg(rx), deg(ry), deg(rz)), "XYZ")
                    e.location = base + Vector(off or (0, 0, 0))
                    e.keyframe_insert("rotation_euler", frame=frame)
                    e.keyframe_insert("location", frame=frame)
                e.location = base
                e.rotation_euler = Euler((0, 0, 0), "XYZ")
                e.animation_data.action = None
        scene.frame_end = 60
        bpy.ops.wm.save_as_mainfile(filepath=self.blend)
        self.log("built", self.blend, len(self.parts_def), "parts")

    # ---------------------------------------------------------------- export
    def save_noise(self):
        # the grey tile for Roblox, ×8 nearest so the texels stay crisp after Roblox's filtering
        tile = self.noise()
        n, k = NOISE_TEXELS, 8
        img = bpy.data.images.new("NoiseOut", n * k, n * k)
        img.colorspace_settings.name = "Non-Color"  # before filling: changing it resets the buffer
        px = []
        for y in range(n * k):
            for x in range(n * k):
                v = tile[y // k][x // k]
                px += [v, v, v, 1.0]
        img.pixels.foreach_set(px)
        img.update()
        img.save(filepath=self.noise_out)

    def scene_joints(self):
        joints = {o.name[6:]: o for o in bpy.data.objects if o.name.startswith("Joint_")}
        order = [n for n, _, _ in self.joints_def if n in joints]
        return joints, order

    def export(self):
        scene = bpy.context.scene
        joints, order = self.scene_joints()
        tex = {"studsPerTile": self.tile_studs, "mean": round(tile_mean(self.noise()), 4)}
        tex.update(self.lift)
        out = {"_source": "assets/models/%s/%s.blend (Blender, made by %s.py + assets/models/blockmob.py; "
                          "reference by Codex)" % (self.name, self.name, self.name),
               "fps": FPS, "texture": tex, "joints": [], "parts": [], "clips": {}}
        for k, v in self.g.get("EXTRA_JSON", {}).items():
            out[k] = v
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
                if o.get("glow"):
                    part["glow"] = True
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
                    keys.append({"t": round(f / FPS, 4), "q": to_roblox_quat(e.rotation_euler),
                                 "p": to_roblox_vec(offset)})
                # drop tracks that never move
                if any(abs(k["q"][0]) + abs(k["q"][1]) + abs(k["q"][2]) > 1e-4 or any(abs(v) > 1e-4 for v in k["p"])
                       for k in keys):
                    tracks[name] = keys
            out["clips"][clip] = {"length": round(frames[-1] / FPS, 4), "loop": loop, "tracks": tracks}
        os.makedirs(os.path.dirname(self.json_out), exist_ok=True)
        if len(out["parts"]) > 300:
            # Roblox caps a ModuleScript at 200 000 characters: big models store each part as one array
            # [joint, centre, size, colour, top | null, glow 0/1, rot | null] (BlockRig reads both forms)
            # format 2: [joint index, cx, cy, cz, sx, sy, sz, colour index, glow, top colour index | -1] with
            # "jointNames" and "palette" lists; parts with a rotation keep the object form
            names = [j["name"] for j in out["joints"]]
            palette, index = [], {}

            def ci(c):
                key = tuple(c)
                if key not in index:
                    index[key] = len(palette)
                    palette.append(list(c))
                return index[key]

            packed = []
            for p in out["parts"]:
                if p.get("rot"):
                    packed.append(p)
                    continue
                c, s = p["centre"], p["size"]
                packed.append([names.index(p["joint"]), round(c[0], 2), round(c[1], 2), round(c[2], 2),
                               round(s[0], 2), round(s[1], 2), round(s[2], 2), ci(p["colour"]),
                               1 if p.get("glow") else 0, ci(p["top"]) if p.get("top") else -1])
            out["format"] = 2
            out["jointNames"] = names
            out["palette"] = palette
            out["parts"] = packed
            with open(self.json_out, "w", encoding="utf-8") as f:
                json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
        else:
            with open(self.json_out, "w", encoding="utf-8") as f:
                json.dump(out, f, ensure_ascii=False, indent=1)
        self.save_noise()
        self.log("exported", self.json_out, len(out["parts"]), "parts", list(out["clips"].keys()))
        self.render_previews(joints, order)

    # ---------------------------------------------------------------- renders
    def setup_render(self, w, h):
        # Eevee with a soft studio set like the reference sheets: grey sky light all round + a key light from the
        # upper front-left; textures stay pixel-sharp (Closest)
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
        bg.inputs["Color"].default_value = srgb(self.g.get("BACKGROUND", (0xB2, 0xB2, 0xB2))) + (1.0,)
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

    def pose(self, joints, order, clip, frame):
        for name in order:
            use(joints[name], bpy.data.actions.get("%s|%s" % (clip, name)) if clip else None)
            if not clip:
                joints[name].rotation_euler = Euler((0, 0, 0), "XYZ")
                parent = joints[name].parent
                joints[name].location = Vector(joints[name]["pivot"]) - (Vector(parent["pivot"]) if parent else Vector())
        bpy.context.scene.frame_set(frame)

    def perspective(self, cam, spec):
        loc, target, lens = spec
        cam.data.type = "PERSP"
        cam.data.lens = lens
        cam.data.clip_end = 300
        cam.location = loc
        direction = Vector(target) - Vector(loc)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()

    def render_previews(self, joints, order):
        scene, cam = self.setup_render(900, 600)
        for spec in self.g["PREVIEWS"]:
            # (clip, frame[, camera]): a pose far from the origin (the bat's swoop and fall) may take its own camera
            clip, frame = spec[0], spec[1]
            self.perspective(cam, spec[2] if len(spec) > 2 else self.g["PREVIEW_CAMERA"])
            self.pose(joints, order, clip, frame)
            scene.render.filepath = os.path.join(self.here, "preview-%s.png" % clip)
            bpy.ops.render.render(write_still=True)
        self.log("previews rendered")

    def compare(self):
        # COMPARE = {"side": (right, up, centre, ortho_scale), ..., "34": (location, target, lens)}: the cameras
        # of the reference sheet's 768×512 panels (see the skill for how to derive them from the measurements)
        joints, order = self.scene_joints()
        self.pose(joints, order, None, 0)
        scene, cam = self.setup_render(768, 512)
        for name, spec in self.g["COMPARE"].items():
            if len(spec) == 3:  # (location, target, lens): a perspective camera
                self.perspective(cam, spec)
            else:
                ortho(cam, *spec)
            scene.render.filepath = os.path.join(self.here, "compare-%s.png" % name)
            bpy.ops.render.render(write_still=True)
        self.log("compare views rendered")


def use(e, act):
    # assign an action and its (only) slot — Blender 5 needs the slot for the curves to play
    e.animation_data_create()
    e.animation_data.action = act
    if act is not None and len(act.slots) > 0 and e.animation_data.action_slot is None:
        e.animation_data.action_slot = act.slots[0]


P = Matrix(((1, 0, 0), (0, 0, 1), (0, -1, 0)))  # Blender → Roblox basis


def to_roblox_vec(v):
    return [round(v.x, 4), round(v.z, 4), round(-v.y, 4)]


def to_roblox_quat(euler):
    q = (P @ euler.to_matrix() @ P.transposed()).to_quaternion()
    return [round(q.x, 5), round(q.y, 5), round(q.z, 5), round(q.w, 5)]


def ortho(cam, right, up, centre, scale):
    # a camera whose screen right / up are the given world axes, looking at centre from 60 studs away
    r, u = Vector(right), Vector(up)
    back = r.cross(u)
    m = Matrix((r, u, back)).transposed().to_4x4()
    m.translation = Vector(centre) + back * 60
    cam.matrix_world = m
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = scale
    cam.data.clip_end = 200


def run(g):
    mob = Mob(g)
    mode = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else "build"
    if mode == "build":
        mob.build()
    elif mode == "export":
        mob.export()
    elif mode == "compare":
        mob.compare()
    else:
        raise SystemExit("unknown mode " + mode)
