"""Build World-1 kelp and seagrass meshes and export GLBs (shared atlas from kelp_paint.py, not embedded).

Run:  blender -b --factory-startup -P kelp_build.py -- <tex_dir> <glb_dir> <preview_dir> [--no-preview]

Meshes (metres, Z up in Blender = Y up in glTF/Godot, root at the origin on the floor):
  kelp_giant_a/b/c   giant-kelp strand (stipe + buoyant blades with gas bladders), 4.5-7 m, near chunk
  kelp_giant_far     same silhouette, few blades, far chunk (z -10 to -30)
  kelp_sugar         clump of 3 sugar-kelp plants (Saccharina), long ruffled blades, 1.4-2.2 m, floor detail
  seagrass_tuft      9 eelgrass blades (Zostera marina), 0.25-0.6 m, MultiMesh tufts on sand
Vertex colour (COLOR_0): R = sway weight (0 root .. 1 top), G = per-blade phase 0..1, B = blade flutter
weight (0 blade base .. 1 blade tip), A = 1. One material "kelp_w1": alpha scissor 0.5, double sided.
"""

import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Matrix, Vector

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fish_build  # noqa: E402

AT = 2048.0
RECTS = {}
for i in range(8):
    RECTS[f"giant{i}"] = ((i % 4) * 256, (i // 4) * 1024, 256, 1024)
RECTS["stipe"] = (1024, 0, 128, 2048)
RECTS["sugar0"] = (1152, 0, 384, 1024)
RECTS["sugar1"] = (1152, 1024, 384, 1024)
RECTS["sugar_stipe"] = (1536, 0, 64, 1024)
for i in range(6):
    RECTS[f"grass{i}"] = (1600 + 64 * i, 0, 64, 1024)
    RECTS[f"grass_s{i}"] = (1600 + 64 * i, 1024, 64, 1024)


def ruv(key, u, v):
    """u -1..1 across, v 0 base .. 1 tip inside a rect -> atlas uv (v up)."""
    x, y, w, h = RECTS[key]
    px = x + 1 + (u + 1) / 2 * (w - 2)
    py = y + 1 + (1 - v) * (h - 2)
    return (px / AT, 1 - py / AT)


class MB:
    def __init__(self):
        self.v, self.c, self.f = [], [], []

    def vert(self, co, col):
        self.v.append(tuple(co))
        self.c.append(tuple(col))
        return len(self.v) - 1

    def face(self, idx, uvs):
        self.f.append((idx, uvs))

    def obj(self, name, mat):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], [f[0] for f in self.f])
        uvl = me.uv_layers.new(name="UVMap")
        for poly, f in zip(me.polygons, self.f):
            poly.use_smooth = True
            for li, uv in zip(poly.loop_indices, f[1]):
                uvl.data[li].uv = uv
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(self.c):
            ca.data[i].color = c
        me.color_attributes.active_color = ca
        me.materials.append(mat)
        me.validate()
        return bpy.data.objects.new(name, me)


def ribbon(mb, key, path, widths, normals, sway, phase, fold=0.0, ruffle=0.0, cols=2):
    """A strip along `path` (list of Vector) with half widths, side vectors from `normals` (the strip's plane
    normal per point). cols = quads across (2 gives a centre spine that can fold)."""
    n = len(path)
    rows = []
    for i, p in enumerate(path):
        v = i / (n - 1)
        if i < n - 1:
            t = (path[i + 1] - p).normalized()
        else:
            t = (p - path[i - 1]).normalized()
        side = t.cross(normals[i]).normalized()
        row = []
        for k in range(cols + 1):
            uu = -1 + 2 * k / cols
            off = side * (uu * widths[i])
            off += normals[i] * (fold * widths[i] * (abs(uu) ** 2))
            if ruffle and abs(uu) > 0.6:
                off += normals[i] * (
                    ruffle * widths[i] * math.sin(v * 38 + uu * 2) * (abs(uu) - 0.6) / 0.4
                )
            co = p + off
            u_tex = uu * widths[i] / max(widths)
            row.append((mb.vert(co, (sway(co), phase, v, 1.0)), ruv(key, u_tex, v)))
        rows.append(row)
    for i in range(n - 1):
        for k in range(cols):
            q = [rows[i][k], rows[i][k + 1], rows[i + 1][k + 1], rows[i + 1][k]]
            mb.face([a[0] for a in q], [a[1] for a in q])


def tube(mb, key, path, radii, sides, sway, phase=0.0):
    n = len(path)
    rings = []
    for i, p in enumerate(path):
        t = (path[min(i + 1, n - 1)] - path[max(i - 1, 0)]).normalized()
        a = t.cross(Vector((0, 1, 0)))
        if a.length < 1e-4:
            a = t.cross(Vector((1, 0, 0)))
        a.normalize()
        b = t.cross(a).normalized()
        ring = []
        for k in range(sides + 1):
            ang = 2 * math.pi * k / sides
            co = p + (a * math.cos(ang) + b * math.sin(ang)) * radii[i]
            ring.append(
                (
                    mb.vert(co, (sway(co), phase, 0.0, 1.0)),
                    ruv(key, -1 + 2 * k / sides, i / (n - 1)),
                )
            )
        rings.append(ring)
    for i in range(n - 1):
        for k in range(sides):
            q = [rings[i][k], rings[i][k + 1], rings[i + 1][k + 1], rings[i + 1][k]]
            mb.face([x[0] for x in q], [x[1] for x in q])


def giant(name, height, seed, nblades, segs, stipe_segs, sides, mat):
    rnd = random.Random(seed)
    mb = MB()
    lean = rnd.uniform(-0.5, 0.5)
    ph = rnd.uniform(0, 6.28)

    def sway(co):
        return max(0.0, min(1.0, co.z / height))

    def stipe_pt(t):
        z = t * height
        return Vector(
            (
                lean * t * t + 0.16 * math.sin(z * 1.1 + ph) * t,
                0.07 * math.sin(z * 0.8 + ph * 1.7) * t,
                z,
            )
        )

    path = [stipe_pt(i / stipe_segs) for i in range(stipe_segs + 1)]
    tube(
        mb,
        "stipe",
        path,
        [0.016 * (1 - 0.45 * i / stipe_segs) for i in range(stipe_segs + 1)],
        sides,
        sway,
    )
    for b in range(nblades):
        t = 0.10 + 0.88 * (b + rnd.uniform(-0.3, 0.3)) / nblades
        t = min(max(t, 0.06), 0.99)
        root = stipe_pt(t)
        side = 1 if b % 2 == 0 else -1
        yaw = rnd.uniform(-1.2, 1.2)
        L = rnd.uniform(0.60, 1.05) * (0.75 + 0.35 * t)
        W = rnd.uniform(0.055, 0.080)
        up = rnd.uniform(0.15, 0.65)  # buoyant: blades angle up and stream with the current (+X)
        d0 = Vector(
            (side * math.cos(yaw) * (1 - up) + 0.35, side * math.sin(yaw) * 0.8, up)
        ).normalized()
        pts, nrm, wid = [], [], []
        p = root.copy()
        d = d0.copy()
        for i in range(segs + 1):
            v = i / segs
            pts.append(p.copy())
            hw = (
                W
                * max(0.30, min(1.0, 0.30 + 1.15 * math.sin(math.pi * min(v, 1.0) ** 0.55)))
                * (1 - 0.35 * v)
            )
            if v < 0.12:
                hw = W * 0.32
            wid.append(hw)
            # plane normal: roughly horizontal-perpendicular, twisting slowly along the blade
            tw = rnd.uniform(-0.25, 0.25) + v * 0.9 * side
            n0 = Vector((-d.y, d.x, 0.0))
            if n0.length < 1e-3:
                n0 = Vector((0, 1, 0))
            n0.normalize()
            n0 = (Matrix.Rotation(tw, 3, d) @ n0).normalized()
            nrm.append(n0)
            if i < segs:
                # current pushes the far part downstream and slightly down at the tip
                d = (d + Vector((0.12, 0.0, -0.14 * v))).normalized()
                p = p + d * (L / segs)
        ribbon(mb, f"giant{rnd.randrange(8)}", pts, wid, nrm, sway, rnd.random(), fold=0.35, cols=2)
    return mb.obj(name, mat)


def sugar(name, seed, mat):
    rnd = random.Random(seed)
    mb = MB()
    H = 2.4

    def sway(co):
        return max(0.0, min(1.0, co.z / 1.2 + 0.25 * abs(co.x)))

    for k in range(3):
        base = Vector((rnd.uniform(-0.25, 0.25), rnd.uniform(-0.2, 0.2), 0))
        sl = rnd.uniform(0.18, 0.32)
        sp = [base + Vector((0.02 * i, 0, sl * i / 3)) for i in range(4)]
        tube(mb, "sugar_stipe", sp, [0.008, 0.007, 0.006, 0.006], 4, sway)
        L = rnd.uniform(1.0, 1.6)
        W = rnd.uniform(0.08, 0.11)
        segs = 10
        d = Vector((rnd.uniform(0.2, 0.5), rnd.uniform(-0.3, 0.3), 1.0)).normalized()
        p = sp[-1].copy()
        pts, nrm, wid = [], [], []
        for i in range(segs + 1):
            v = i / segs
            pts.append(p.copy())
            wid.append(
                W * (0.12 + 0.88 * min(1.0, v / 0.22)) * (1 - 0.15 * max(0.0, v - 0.75) / 0.25)
            )
            n0 = Vector((-d.y, d.x, 0.0))
            if n0.length < 1e-3:
                n0 = Vector((0, 1, 0))
            nrm.append(n0.normalized())
            if i < segs:
                # buoyant start, then the long blade lies over in the current and sags
                d = (d + Vector((0.16, 0.02, -0.07 * v))).normalized()
                p = p + d * (L / segs)
        ribbon(
            mb, f"sugar{k % 2}", pts, wid, nrm, sway, rnd.random(), fold=0.15, ruffle=0.18, cols=4
        )
    del H
    return mb.obj(name, mat)


def seagrass(name, seed, mat, n=9):
    rnd = random.Random(seed)
    mb = MB()
    for k in range(n):
        base = Vector((rnd.gauss(0, 0.03), rnd.gauss(0, 0.03), 0))
        L = rnd.uniform(0.25, 0.6)
        W = rnd.uniform(0.0028, 0.0042)
        segs = 5
        lean = Vector((rnd.uniform(-0.4, 0.6), rnd.uniform(-0.4, 0.4), 1.0)).normalized()
        p = base.copy()
        d = lean.copy()
        pts, nrm, wid = [], [], []
        for i in range(segs + 1):
            pts.append(p.copy())
            wid.append(W)
            n0 = Vector((-d.y, d.x, 0.0))
            if n0.length < 1e-3:
                n0 = Vector((0, 1, 0))
            n0 = Matrix.Rotation(rnd.uniform(-0.3, 0.3), 3, d) @ n0.normalized()
            nrm.append(n0)
            if i < segs:
                d = (d + Vector((0.12, 0.0, -0.06 * i / segs))).normalized()
                p = p + d * (L / segs)

        def sway(co, L=L):
            return max(0.0, min(1.0, co.z / 0.6))

        key = f"grass{rnd.randrange(6)}" if L > 0.38 else f"grass_s{rnd.randrange(6)}"
        ribbon(mb, key, pts, wid, nrm, sway, rnd.random(), cols=1)
    return mb.obj(name, mat)


def kelp_material(tex_dir):
    m = bpy.data.materials.get("kelp_w1") or bpy.data.materials.new("kelp_w1")
    m.use_nodes = True
    n, ln = m.node_tree.nodes, m.node_tree.links
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    b = n.new("ShaderNodeBsdfPrincipled")
    ims = {}
    for k, cs in (("albedo", "sRGB"), ("normal", "Non-Color"), ("orm", "Non-Color")):
        p = Path(tex_dir) / f"kelp_w1_{k}.png"
        im = bpy.data.images.get(p.name) or bpy.data.images.load(str(p))
        im.colorspace_settings.name = cs
        t = n.new("ShaderNodeTexImage")
        t.image = im
        ims[k] = t
    ln.new(ims["albedo"].outputs["Color"], b.inputs["Base Color"])
    sep = n.new("ShaderNodeSeparateColor")
    ln.new(ims["orm"].outputs["Color"], sep.inputs["Color"])
    ln.new(sep.outputs["Green"], b.inputs["Roughness"])
    nm = n.new("ShaderNodeNormalMap")
    ln.new(ims["normal"].outputs["Color"], nm.inputs["Color"])
    ln.new(nm.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Coat Weight"].default_value = 0.2
    tr = n.new("ShaderNodeBsdfTranslucent")  # Godot: backlight = albedo x 0.9
    br = n.new("ShaderNodeMix")
    br.data_type = "RGBA"
    br.blend_type = "MULTIPLY"
    br.inputs["Factor"].default_value = 1.0
    ln.new(ims["albedo"].outputs["Color"], br.inputs[6])
    br.inputs[7].default_value = (1.25, 1.05, 0.7, 1)
    ln.new(br.outputs[2], tr.inputs["Color"])
    mx = n.new("ShaderNodeMixShader")
    mx.inputs["Fac"].default_value = 0.55
    ln.new(b.outputs[0], mx.inputs[1])
    ln.new(tr.outputs[0], mx.inputs[2])
    gt = n.new("ShaderNodeMath")
    gt.operation = "GREATER_THAN"
    gt.inputs[1].default_value = 0.5
    ln.new(ims["albedo"].outputs["Alpha"], gt.inputs[0])
    tp = n.new("ShaderNodeBsdfTransparent")
    mc = n.new("ShaderNodeMixShader")
    ln.new(gt.outputs[0], mc.inputs["Fac"])
    ln.new(tp.outputs[0], mc.inputs[1])
    ln.new(mx.outputs[0], mc.inputs[2])
    ln.new(mc.outputs[0], out.inputs["Surface"])
    return m


def build_all(tex_dir, mat=None):
    mat = mat or kelp_material(tex_dir)
    return [
        giant("kelp_giant_a", 6.8, 11, 32, 4, 9, 5, mat),
        giant("kelp_giant_b", 5.6, 23, 27, 4, 8, 5, mat),
        giant("kelp_giant_c", 4.6, 37, 22, 4, 7, 5, mat),
        giant("kelp_giant_far", 6.0, 51, 18, 2, 4, 3, mat),
        sugar("kelp_sugar", 61, mat),
        seagrass("seagrass_tuft", 71, mat),
    ]


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    tex_dir, glb_dir, prev_dir = (Path(a).resolve() for a in argv[:3])
    glb_dir.mkdir(parents=True, exist_ok=True)
    prev_dir.mkdir(parents=True, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    sc = bpy.context.scene
    objs = build_all(tex_dir)
    for ob in objs:
        sc.collection.objects.link(ob)
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(
            filepath=str(glb_dir / f"{ob.name}.glb"),
            export_format="GLB",
            use_selection=True,
            export_image_format="NONE",
            export_vertex_color="ACTIVE",
            export_all_vertex_colors=False,
            export_tangents=True,
            export_yup=True,
            export_animations=False,
        )
        fish_build.patch_glb_materials(
            glb_dir / f"{ob.name}.glb",
            {"kelp_w1": {"alphaMode": "MASK", "alphaCutoff": 0.5, "doubleSided": True}},
            "kelp_w1",
        )
        print("TRIS", ob.name, sum(len(p.vertices) - 2 for p in ob.data.polygons))
    if "--no-preview" in argv:
        return
    # preview: backlit row, camera side-on looking slightly up like the game
    sc.render.engine = "CYCLES"
    prefs = bpy.context.preferences.addons["cycles"].preferences
    for dev in ("OPTIX", "CUDA"):
        try:
            prefs.compute_device_type = dev
            prefs.get_devices()
            for d in prefs.devices:
                d.use = True
            sc.cycles.device = "GPU"
            break
        except TypeError:
            continue
    sc.cycles.samples = 64
    sc.view_settings.view_transform = "AgX"
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = next(x for x in w.node_tree.nodes if x.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.05, 0.25, 0.32, 1)
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 5
    sun.rotation_euler = (
        math.radians(-160),
        math.radians(15),
        0,
    )  # from above and behind: back-lit blades
    sc.collection.objects.link(sun)
    for i, ob in enumerate(objs):
        ob.location = (-3.6 + i * 1.45, 0, 0)
    objs[5].scale = (3, 3, 3)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    cam.data.lens = 28
    cam.location = (0, -9.5, 2.6)
    cam.rotation_euler = (math.radians(88), 0, 0)
    sc.collection.objects.link(cam)
    sc.camera = cam
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1200
    sc.render.filepath = str(prev_dir / "kelp_lineup.png")
    bpy.ops.render.render(write_still=True)
    # close-up of blades
    cam.data.lens = 50
    cam.location = (-3.2, -1.8, 4.0)
    cam.rotation_euler = (math.radians(92), 0, math.radians(-8))
    sc.render.filepath = str(prev_dir / "kelp_closeup.png")
    bpy.ops.render.render(write_still=True)


if __name__ == "__main__":
    main()
