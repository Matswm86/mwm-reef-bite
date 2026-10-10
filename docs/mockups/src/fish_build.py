"""Build the World-1 fish as game meshes and export one GLB per species.

Run:  blender -b --factory-startup -P fish_build.py -- <tex_dir> <glb_dir> <preview_dir>
  tex_dir      fish_w1_albedo.png / fish_w1_normal.png / fish_w1_orm.png from fish_paint.py
  glb_dir      assets/models/fish  (GLBs carry mesh, UV into the shared atlas, vertex colours, two materials;
               the atlas PNGs are NOT embedded: every species shares assets/models/fish/textures/)
  preview_dir  lineup.png + closeup_<name>.png renders (Cycles) and fish_lib.blend

Geometry per species (fish_species.py): lofted body from the side profile with a fuller-flank superellipse
section, side-projected UVs (both flanks share texels, so the atlas is symmetric), alpha-cut fin cards whose
grid follows the fin rays, a domed cornea per eye, a chin barbel on the cod.
Vertex colour (COLOR_0): R = jaw mask, G = fin flare mask, B = swim bend weight (0 head .. 1 tail tip), A = 1.
"""

import math
import sys
from pathlib import Path

import bpy
import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import fish_species as F  # noqa: E402

BODY_MAT = "fish_w1_body"
FIN_MAT = "fish_w1_fins"


def sstep(e0, e1, x):
    t = min(max((x - e0) / (e1 - e0), 0.0), 1.0)
    return t * t * (3 - 2 * t)


# ------------------------------------------------------------------ materials (Cycles preview; Godot uses its own shader)
def make_fish_materials(tex_dir):
    tex_dir = Path(tex_dir)
    imgs = {}
    for k, cs in (("albedo", "sRGB"), ("normal", "Non-Color"), ("orm", "Non-Color")):
        p = tex_dir / f"fish_w1_{k}.png"
        im = bpy.data.images.get(p.name) or bpy.data.images.load(str(p))
        im.colorspace_settings.name = cs
        imgs[k] = im
    mats = {}
    for name, fins in ((BODY_MAT, False), (FIN_MAT, True)):
        m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
        m.use_nodes = True
        nt = m.node_tree
        n, ln = nt.nodes, nt.links
        n.clear()
        out = n.new("ShaderNodeOutputMaterial")
        b = n.new("ShaderNodeBsdfPrincipled")
        ta = n.new("ShaderNodeTexImage")
        ta.image = imgs["albedo"]
        tn = n.new("ShaderNodeTexImage")
        tn.image = imgs["normal"]
        to = n.new("ShaderNodeTexImage")
        to.image = imgs["orm"]
        for t in (ta, tn, to):
            t.interpolation = "Cubic"
        sep = n.new("ShaderNodeSeparateColor")
        ln.new(to.outputs["Color"], sep.inputs["Color"])
        ao = n.new("ShaderNodeMix")
        ao.data_type = "RGBA"
        ao.blend_type = "MULTIPLY"
        ao.inputs["Factor"].default_value = 1.0
        ln.new(ta.outputs["Color"], ao.inputs[6])
        ln.new(sep.outputs["Red"], ao.inputs[7])
        ln.new(ao.outputs[2], b.inputs["Base Color"])
        ln.new(sep.outputs["Green"], b.inputs["Roughness"])
        ln.new(sep.outputs["Blue"], b.inputs["Metallic"])
        nm = n.new("ShaderNodeNormalMap")
        nm.inputs["Strength"].default_value = 1.0
        ln.new(tn.outputs["Color"], nm.inputs["Color"])
        ln.new(nm.outputs["Normal"], b.inputs["Normal"])
        b.inputs["Coat Weight"].default_value = 0.0 if fins else 0.35  # wet film
        b.inputs["Coat Roughness"].default_value = 0.06
        b.inputs["Specular IOR Level"].default_value = 0.6
        if fins:
            # alpha blend like the game, plus back-lit translucency (Godot: backlight)
            gt = n.new("ShaderNodeMath")  # alpha blend like the game's depth_prepass_alpha fins
            gt.operation = "MULTIPLY"
            gt.inputs[1].default_value = 1.0
            ln.new(ta.outputs["Alpha"], gt.inputs[0])
            tr = n.new("ShaderNodeBsdfTranslucent")
            ln.new(ta.outputs["Color"], tr.inputs["Color"])
            mx = n.new("ShaderNodeMixShader")
            mx.inputs["Fac"].default_value = 0.40
            ln.new(b.outputs[0], mx.inputs[1])
            ln.new(tr.outputs[0], mx.inputs[2])
            tp = n.new("ShaderNodeBsdfTransparent")
            mc = n.new("ShaderNodeMixShader")
            ln.new(gt.outputs[0], mc.inputs["Fac"])
            ln.new(tp.outputs[0], mc.inputs[1])
            ln.new(mx.outputs[0], mc.inputs[2])
            ln.new(mc.outputs[0], out.inputs["Surface"])
        else:
            ln.new(b.outputs[0], out.inputs["Surface"])
        mats[name] = m
    return mats


# ------------------------------------------------------------------ mesh builder
class MB:
    """Tiny mesh accumulator: verts, faces with per-corner uv and per-vertex colour, material index."""

    def __init__(self):
        self.v, self.col, self.faces = [], [], []

    def vert(self, co, col):
        self.v.append(tuple(co))
        self.col.append(tuple(col))
        return len(self.v) - 1

    def face(self, idx, uvs, mat):
        self.faces.append((idx, uvs, mat))

    def to_object(self, name, mats):
        me = bpy.data.meshes.new(name)
        me.from_pydata(self.v, [], [f[0] for f in self.faces])
        uvl = me.uv_layers.new(name="UVMap")
        k = 0
        for poly, f in zip(me.polygons, self.faces):
            poly.material_index = f[2]
            poly.use_smooth = True
            for li, uv in zip(poly.loop_indices, f[1]):
                uvl.data[li].uv = uv
            k += 1
        ca = me.color_attributes.new("Col", "FLOAT_COLOR", "POINT")
        for i, c in enumerate(self.col):
            ca.data[i].color = c
        me.color_attributes.active_color = ca
        for m in mats:
            me.materials.append(m)
        me.validate()
        ob = bpy.data.objects.new(name, me)
        return ob


def wx(s):
    return F.ORIGIN_S - s


def section_point(body, s, a, n_exp):
    T, Bt, W = float(body.top(s)), float(body.bot(s)), float(body.hw(s))
    zc = 0.5 * (T + Bt)
    ht = T - zc
    ca, sa = math.cos(a), math.sin(a)
    y = W * math.copysign(abs(ca) ** (2 / n_exp), ca)
    z = zc + ht * math.copysign(abs(sa) ** (2 / 2.0), sa)
    return y, z


def surface_y(body, s, z, n_exp):
    T, Bt, W = float(body.top(s)), float(body.bot(s)), float(body.hw(s))
    zc, ht = 0.5 * (T + Bt), 0.5 * (T - Bt)
    q = min(abs(z - zc) / max(ht, 1e-5), 1.0)
    return W * (1 - q * q) ** (1 / n_exp)


def body_col(body, s, z):
    m = body.sp["mouth"]
    jaw = 0.0
    if s < m["end_s"] * 1.15 and z < float(body.mouth_z(min(s, m["end_s"]))):
        jaw = 1.0 - sstep(m["end_s"] * 0.8, m["end_s"] * 1.15, s)
    return (jaw, 0.0, sstep(0.18, 1.0, s), 1.0)


def build_species(name, mats):
    body = F.Body(name)
    sp = body.sp
    hero = sp.get("hero", False)
    NR, NA = (38, 30) if hero else (22, 20)
    n_exp = sp["section"]
    mb = MB()
    rings = []
    for i in range(NR + 1):
        t = i / NR
        s = body.sb * (0.50 * t + 0.50 * (0.5 - 0.5 * math.cos(math.pi * t)))
        s = max(s, 0.0035) if i == 0 else s
        ring = []
        for j in range(NA):
            a = 2 * math.pi * j / NA
            y, z = section_point(body, s, a, n_exp)
            ring.append((mb.vert((wx(s), y, z), body_col(body, s, z)), s, z))
        rings.append(ring)

    def uv(s, z):
        u, v = body.body_uv(s, z)
        return (float(u), float(v))

    for i in range(NR):
        for j in range(NA):
            a, b_ = rings[i][j], rings[i][(j + 1) % NA]
            c, d = rings[i + 1][(j + 1) % NA], rings[i + 1][j]
            quad = [a, d, c, b_]
            mb.face([q[0] for q in quad], [uv(q[1], q[2]) for q in quad], 0)
    # snout tip and tail-base caps (fans)
    zt = float(body.mouth_z(0.0)) + 0.002
    tip = mb.vert((wx(-0.002), 0.0, zt), body_col(body, 0, zt))
    for j in range(NA):
        a, b_ = rings[0][j], rings[0][(j + 1) % NA]
        mb.face([tip, a[0], b_[0]], [uv(0, zt), uv(a[1], a[2]), uv(b_[1], b_[2])], 0)
    zc = float(body.mid(body.sb))
    tail = mb.vert((wx(body.sb + 0.002), 0.0, zc), (0, 0, 1, 1))
    for j in range(NA):
        a, b_ = rings[-1][j], rings[-1][(j + 1) % NA]
        mb.face([tail, b_[0], a[0]], [uv(body.sb, zc), uv(b_[1], b_[2]), uv(a[1], a[2])], 0)

    # fins
    rects, _ = F.pack_fins(body)
    for fi, f in enumerate(sp["fins"]):
        rect = rects[f"fin{fi}"]
        base, outer = F.fin_outline(body, f, n=64)
        k = f["kind"]
        nu = {"caudal": 8, "dorsal": 6, "anal": 5}.get(k, 4)
        span = f.get("s1", 0) - f.get("s0", 0)
        if k in ("dorsal", "anal") and span > 0.3:
            nu = 9
        if hero:
            nu = int(nu * 1.5)
        nw = 3 if hero else 2
        ext = 1.07 if f.get("spiny") else 1.03
        us = np.linspace(0, 1, nu + 1)
        ws = np.linspace(0, ext, nw + 1)
        uu = np.linspace(0, 1, len(base))

        def fpt(u, w):
            b = np.array([np.interp(u, uu, base[:, 0]), np.interp(u, uu, base[:, 1])])
            o = np.array([np.interp(u, uu, outer[:, 0]), np.interp(u, uu, outer[:, 1])])
            return b + (o - b) * w

        sides = [1, -1] if k in ("pectoral", "pelvic") else [0]
        for side in sides:
            grid = []
            for u in us:
                row = []
                for w in ws:
                    p2 = fpt(u, w)
                    if k in ("dorsal", "anal", "caudal"):
                        s, z = p2
                        wav = 0.0015 * math.sin(u * 9.0 + w * 2) * w
                        co = (wx(s), wav, z)
                        flex = sstep(0.18, 1.0, s)
                        if k == "caudal":
                            flex = 1.0
                        flare = w / ext if k == "dorsal" or k == "anal" else 0.0
                    else:
                        if k == "pectoral":
                            s0 = f["s"]
                            T, Bt = float(body.top(s0)), float(body.bot(s0))
                            z0 = Bt + (T - Bt) * f["zn"]
                        else:
                            s0 = f["s"]
                            z0 = float(body.bot(s0)) + 0.012
                        y0 = surface_y(body, s0, z0, n_exp) + 0.0015
                        dn, ot = math.radians(f["down"]), math.radians(f["out"])
                        dx = np.array(
                            [
                                -math.cos(dn) * math.cos(ot),
                                side * math.cos(dn) * math.sin(ot),
                                -math.sin(dn),
                            ]
                        )
                        up = np.array([0.0, 0.0, 1.0])
                        dy = up - up.dot(dx) * dx
                        dy /= np.linalg.norm(dy)
                        x2, y2 = p2
                        bend = 0.25 * (x2 / max(f["len"], 1e-4)) ** 2 * f["len"]
                        c3 = (
                            np.array([wx(s0), side * y0, z0])
                            + dx * x2
                            + dy * y2
                            + np.array([0, side * bend, 0])
                        )
                        co = tuple(c3)
                        flex = sstep(0.18, 1.0, s0 + x2)
                        flare = w / ext if k == "pectoral" else 0.0
                    uvp = F.fin_uv(body, rect, p2)
                    row.append(
                        (mb.vert(co, (0.0, flare, flex, 1.0)), (float(uvp[0]), float(uvp[1])))
                    )
                grid.append(row)
            for a_ in range(nu):
                for b2 in range(nw):
                    q = [grid[a_][b2], grid[a_ + 1][b2], grid[a_ + 1][b2 + 1], grid[a_][b2 + 1]]
                    if side == -1:
                        q = q[::-1]
                    mb.face([x[0] for x in q], [x[1] for x in q], 1)

    # eyes: domed cornea over the painted socket
    se, ze, er = body.eye_pos()
    erect = rects["eye"]
    segs, nring = (14, 3) if hero else (10, 2)
    for side in (1, -1):
        ys = surface_y(body, se, ze, n_exp)
        ctr = mb.vert((wx(se), side * (ys + er * 0.30), ze), (0, 0, 0, 1))
        cuv = F.fin_uv(body, erect, (0.0, 0.0))
        prev = None
        for r in range(1, nring + 1):
            rho = r / nring
            ring = []
            for j in range(segs):
                a = 2 * math.pi * j / segs
                dxs, dzs = math.cos(a) * er * rho, math.sin(a) * er * rho
                ysr = surface_y(body, se + dxs, ze + dzs, n_exp)
                bulge = er * 0.30 * (1 - rho * rho) ** 0.8
                vi = mb.vert((wx(se + dxs), side * (ysr + bulge + 0.0008), ze + dzs), (0, 0, 0, 1))
                u2 = F.fin_uv(body, erect, (dxs, dzs))
                ring.append((vi, (float(u2[0]), float(u2[1]))))
            for j in range(segs):
                a_, b_ = ring[j], ring[(j + 1) % segs]
                if prev is None:
                    tri = [(ctr, (float(cuv[0]), float(cuv[1]))), b_, a_]
                    if side == 1:
                        tri = tri[::-1]
                    mb.face([x[0] for x in tri], [x[1] for x in tri], 0)
                else:
                    c_, d_ = prev[(j + 1) % segs], prev[j]
                    q = [d_, c_, b_, a_]
                    if side == 1:
                        q = q[::-1]
                    mb.face([x[0] for x in q], [x[1] for x in q], 0)
            prev = ring

    if sp.get("barbel"):
        bb = sp["barbel"]
        s0 = bb["s"]
        z0 = float(body.bot(s0)) + 0.002
        brect = rects["barbel"]
        buv = F.fin_uv(
            body, brect, ((brect[4][0] + brect[5][0]) / 2, (brect[4][1] + brect[5][1]) / 2)
        )
        buv = (float(buv[0]), float(buv[1]))
        tipv = mb.vert((wx(s0 + 0.012), 0.0, z0 - bb["len"]), (1, 0, 0.1, 1))
        ringv = []
        for j in range(5):
            a = 2 * math.pi * j / 5
            ringv.append(
                mb.vert((wx(s0) + 0.0025 * math.cos(a), 0.0025 * math.sin(a), z0), (1, 0, 0.1, 1))
            )
        for j in range(5):
            mb.face([ringv[j], ringv[(j + 1) % 5], tipv], [buv, buv, buv], 0)

    ob = mb.to_object(name, [mats[BODY_MAT], mats[FIN_MAT]])
    return ob


def patch_glb_materials(path, spec, tex_prefix=None):
    """Set alphaMode / alphaCutoff / doubleSided per material name in a GLB (the exporter cannot infer them
    when images are not embedded). spec = {material name: {gltf material keys}}."""
    import json
    import struct

    b = Path(path).read_bytes()
    jlen = struct.unpack("<I", b[12:16])[0]
    j = json.loads(b[20 : 20 + jlen])
    for m in j.get("materials", []):
        m.update(spec.get(m.get("name"), {}))
    if tex_prefix:
        # shared atlas referenced by relative URI, so every GLB in the folder reuses one imported texture set
        j["images"] = [
            {"uri": f"textures/{tex_prefix}_{k}.png"} for k in ("albedo", "normal", "orm")
        ]
        j["samplers"] = [{"magFilter": 9729, "minFilter": 9987, "wrapS": 33071, "wrapT": 33071}]
        j["textures"] = [{"source": i, "sampler": 0} for i in range(3)]
        for m in j.get("materials", []):
            m["pbrMetallicRoughness"] = {
                "baseColorTexture": {"index": 0},
                "metallicRoughnessTexture": {"index": 2},
                "metallicFactor": 1.0,
                "roughnessFactor": 1.0,
            }
            m["normalTexture"] = {"index": 1}
            m["occlusionTexture"] = {"index": 2}
            m.pop("emissiveFactor", None)
    js = json.dumps(j, separators=(",", ":")).encode()
    js += b" " * ((4 - len(js) % 4) % 4)
    rest = b[20 + jlen :]
    total = 12 + 8 + len(js) + len(rest)
    out = b[:8] + struct.pack("<I", total) + struct.pack("<I", len(js)) + b"JSON" + js + rest
    Path(path).write_bytes(out)


FISH_GLB_MATS = {
    BODY_MAT: {"alphaMode": "OPAQUE", "doubleSided": False},
    FIN_MAT: {"alphaMode": "BLEND", "doubleSided": True},
}


def tri_count(ob):
    return sum(len(p.vertices) - 2 for p in ob.data.polygons)


# ------------------------------------------------------------------ preview scene
def preview_scene(objs, out_dir):
    sc = bpy.context.scene
    sc.render.engine = "CYCLES"
    try:
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
    except KeyError:
        pass
    sc.cycles.samples = 96
    sc.view_settings.view_transform = "AgX"
    try:
        sc.view_settings.look = "AgX - Medium High Contrast"
    except TypeError:
        pass
    w = bpy.data.worlds.new("w")
    w.use_nodes = True
    bg = next(x for x in w.node_tree.nodes if x.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.05, 0.24, 0.30, 1)
    bg.inputs["Strength"].default_value = 0.9
    sc.world = w
    sun = bpy.data.objects.new("sun", bpy.data.lights.new("sun", "SUN"))
    sun.data.energy = 4.0
    sun.data.color = (1.0, 0.96, 0.86)
    sun.data.angle = math.radians(8)
    sun.rotation_euler = (math.radians(25), math.radians(-10), 0)
    sc.collection.objects.link(sun)
    fill = bpy.data.objects.new("fill", bpy.data.lights.new("fill", "AREA"))
    fill.data.energy = 30
    fill.data.size = 4
    fill.data.color = (0.6, 0.85, 0.95)
    fill.location = (0, -3, -1.5)
    fill.rotation_euler = (math.radians(120), 0, 0)
    sc.collection.objects.link(fill)
    cam = bpy.data.objects.new("cam", bpy.data.cameras.new("cam"))
    sc.collection.objects.link(cam)
    sc.camera = cam
    # lineup: 2 columns x 4 rows, every fish at unit length
    for i, ob in enumerate(objs):
        ob.location = ((i % 2) * 1.25 - 0.62 + 0.08, 0, 1.5 - (i // 2) * 0.55)
    cam.data.type = "ORTHO"
    cam.data.ortho_scale = 2.75
    cam.location = (0.0, -6, 0.68)
    cam.rotation_euler = (math.radians(90), 0, 0)
    sc.render.resolution_x, sc.render.resolution_y = 1600, 1500
    sc.render.filepath = str(out_dir / "lineup.png")
    bpy.ops.render.render(write_still=True)
    # close-ups: perspective three-quarter side, like the win card portrait
    cam.data.type = "PERSP"
    cam.data.lens = 70
    sc.render.resolution_x, sc.render.resolution_y = 1200, 800
    for ob in objs:
        ob.hide_render = True
    for name in ("golden_trevally", "torsk", "berggylt"):
        ob = bpy.data.objects[name]
        ob.hide_render = False
        ob.location = (0, 0, 0)
        cam.location = (0.15, -1.55, 0.18)
        cam.rotation_euler = (math.radians(84), 0, math.radians(5))
        sc.render.filepath = str(out_dir / f"closeup_{name}.png")
        bpy.ops.render.render(write_still=True)
        ob.hide_render = True


def main():
    argv = sys.argv[sys.argv.index("--") + 1 :]
    tex_dir, glb_dir, prev_dir = (Path(a).resolve() for a in argv[:3])
    glb_dir.mkdir(parents=True, exist_ok=True)
    prev_dir.mkdir(parents=True, exist_ok=True)
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o)
    mats = make_fish_materials(tex_dir)
    objs = []
    report = []
    for name in F.ORDER:
        ob = build_species(name, mats)
        bpy.context.scene.collection.objects.link(ob)
        objs.append(ob)
        report.append((name, tri_count(ob)))
        bpy.ops.object.select_all(action="DESELECT")
        ob.select_set(True)
        bpy.context.view_layer.objects.active = ob
        bpy.ops.export_scene.gltf(
            filepath=str(glb_dir / f"{name}.glb"),
            export_format="GLB",
            use_selection=True,
            export_image_format="NONE",
            export_vertex_color="ACTIVE",
            export_all_vertex_colors=False,
            export_tangents=True,
            export_yup=True,
            export_animations=False,
            export_apply=True,
        )
        patch_glb_materials(glb_dir / f"{name}.glb", FISH_GLB_MATS, "fish_w1")
    for name, tris in report:
        print(f"TRIS {name} {tris}")
    bpy.ops.wm.save_as_mainfile(filepath=str(prev_dir / "fish_lib.blend"))
    if "--no-preview" not in argv:
        preview_scene(objs, prev_dir)
    print("DONE fish_build")


if __name__ == "__main__":
    main()
