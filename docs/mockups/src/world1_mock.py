"""World 1 "Tareskogen / Kelp Reef" mock frame, 1080x1920, Blender 4.5 background mode.

Run:  blender -b --factory-startup -P world1_mock.py -- <out_dir> [samples] [scale%]
Writes <out_dir>/w1_raw.png plus object-index masks (mask_edible / mask_danger /
mask_player .png) that overlay.py uses for the gameplay cues and HUD.

Everything here is own work except the Poly Haven CC0 sand texture and rock scan
(paths in DL below). It mirrors what Godot's Mobile renderer can do: caustics in the
seabed shader, god rays as additive cards, depth fog as a distance mix, no volumetrics.
"""

import math
import random
import sys
from pathlib import Path

import bmesh
import bpy

argv = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
OUT = Path(
    argv[0] if argv else str(Path(__file__).resolve().parents[5] / "scratch/mwm-reef-bite/render")
)
SAMPLES = int(argv[1]) if len(argv) > 1 else 96
SCALE = int(argv[2]) if len(argv) > 2 else 100
OUT.mkdir(parents=True, exist_ok=True)
DL = Path(__file__).resolve().parents[5] / "scratch/mwm-reef-bite/dl"
random.seed(7)

# ---------------------------------------------------------------- palette (linear-ish sRGB picks)
FOG_TOP = (0.20, 0.56, 0.63)  # #338FA1 sunlit water near the surface
FOG_MID = (0.06, 0.33, 0.42)  # #0F546B
FOG_DEEP = (0.025, 0.20, 0.28)  # #063347
SUN_COL = (1.0, 0.96, 0.86)


def hexc(h, a=1.0):
    h = h.lstrip("#")
    srgb = [int(h[i : i + 2], 16) / 255 for i in (0, 2, 4)]
    lin = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in srgb]
    return (*lin, a)


def lin3(rgb):
    return tuple(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in rgb)


# ---------------------------------------------------------------- scene reset
bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene
try:
    sc.render.engine = "CYCLES"
except TypeError as e:
    print("engine", e)
sc.cycles.samples = SAMPLES
sc.cycles.use_denoising = True
prefs = bpy.context.preferences.addons["cycles"].preferences
for kind in ("OPTIX", "CUDA"):
    try:
        prefs.compute_device_type = kind
        prefs.get_devices()
        for d in prefs.devices:
            d.use = True
        sc.cycles.device = "GPU"
        print("device", kind)
        break
    except TypeError:
        continue
sc.cycles.max_bounces = 6
sc.cycles.transparent_max_bounces = 24
sc.render.resolution_x, sc.render.resolution_y = 1080, 1920
sc.render.resolution_percentage = SCALE
sc.view_settings.view_transform = "AgX"
try:
    sc.view_settings.look = "AgX - Medium High Contrast"
except TypeError:
    pass
sc.view_settings.exposure = 0.35

# ---------------------------------------------------------------- camera: side view on the play plane y = 0
CAM_DIST = 9.0
cam_data = bpy.data.cameras.new("cam")
cam_data.sensor_fit = "VERTICAL"
cam_data.sensor_height = 36
cam_data.lens = 50  # vfov 39.6 deg -> 6.48 m visible height at 9 m (300 px per m)
cam_data.clip_end = 200
cam = bpy.data.objects.new("cam", cam_data)
sc.collection.objects.link(cam)
cam.location = (0, -CAM_DIST, 0)
cam.rotation_euler = (math.radians(90), 0, 0)
sc.camera = cam
PX_PER_M = 1920 / (2 * CAM_DIST * math.tan(math.atan(18 / 50)))
print("px per m on play plane", PX_PER_M)


# ---------------------------------------------------------------- node helpers
def new_mat(name):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    return m, m.node_tree.nodes, m.node_tree.links


def bsdf_of(nodes):
    return next(n for n in nodes if n.type == "BSDF_PRINCIPLED")


def setin(node, names, val):
    for nm in names if isinstance(names, (list, tuple)) else [names]:
        if nm in node.inputs:
            node.inputs[nm].default_value = val
            return True
    return False


def fog_wrap(mat, start=4.0, end=38.0, maxfog=1.0):
    """Mix the surface toward a depth-tinted fog emission by camera distance (Godot depth fog)."""
    nt = mat.node_tree
    nodes, links = nt.nodes, nt.links
    out = next(n for n in nodes if n.type == "OUTPUT_MATERIAL")
    src = out.inputs["Surface"].links[0].from_socket
    camd = nodes.new("ShaderNodeCameraData")
    mr = nodes.new("ShaderNodeMapRange")
    mr.inputs["From Min"].default_value = start
    mr.inputs["From Max"].default_value = end
    mr.inputs["To Max"].default_value = maxfog
    links.new(camd.outputs["View Distance"], mr.inputs["Value"])
    pw = nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 0.8
    links.new(mr.outputs["Result"], pw.inputs[0])
    geo = nodes.new("ShaderNodeNewGeometry")
    sep = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Position"], sep.inputs[0])
    mr2 = nodes.new("ShaderNodeMapRange")
    mr2.inputs["From Min"].default_value = -4.0
    mr2.inputs["From Max"].default_value = 5.0
    links.new(sep.outputs["Z"], mr2.inputs["Value"])
    ramp = nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].color = (*lin3(FOG_DEEP), 1)
    ramp.color_ramp.elements[1].color = (*lin3(FOG_TOP), 1)
    mid = ramp.color_ramp.elements.new(0.5)
    mid.color = (*lin3(FOG_MID), 1)
    links.new(mr2.outputs["Result"], ramp.inputs["Fac"])
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Strength"].default_value = 1.0
    links.new(ramp.outputs["Color"], em.inputs["Color"])
    mix = nodes.new("ShaderNodeMixShader")
    links.new(pw.outputs[0], mix.inputs["Fac"])
    links.new(src, mix.inputs[1])
    links.new(em.outputs[0], mix.inputs[2])
    links.new(mix.outputs[0], out.inputs["Surface"])


def caustic_socket(nodes, links, scale=1.4, strength=2.2):
    """Two layers of voronoi distance-to-edge on world XY (top-down projection), top-facing only."""
    geo = nodes.new("ShaderNodeNewGeometry")
    dn = nodes.new("ShaderNodeTexNoise")
    dn.inputs["Scale"].default_value = 4.5
    dn.inputs["Detail"].default_value = 3.0
    dv = nodes.new("ShaderNodeVectorMath")
    dv.operation = "MULTIPLY_ADD"
    dv.inputs[1].default_value = (0.32, 0.32, 0.0)
    links.new(geo.outputs["Position"], dn.inputs["Vector"])
    links.new(dn.outputs["Color"], dv.inputs[0])
    links.new(geo.outputs["Position"], dv.inputs[2])
    layers = []
    for sc_, off in ((scale, (0, 0, 0)), (scale * 1.37, (3.1, 1.7, 0.4))):
        mp = nodes.new("ShaderNodeMapping")
        mp.inputs["Location"].default_value = off
        mp.inputs["Rotation"].default_value = (0, 0, 0.6 if off[0] else 0)
        links.new(dv.outputs[0], mp.inputs["Vector"])
        vo = nodes.new("ShaderNodeTexVoronoi")
        vo.voronoi_dimensions = "3D"
        vo.feature = "DISTANCE_TO_EDGE"
        vo.inputs["Scale"].default_value = sc_
        links.new(mp.outputs["Vector"], vo.inputs["Vector"])
        mr = nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = 0.0
        mr.inputs["From Max"].default_value = 0.055
        mr.inputs["To Min"].default_value = 1.0
        mr.inputs["To Max"].default_value = 0.0
        links.new(vo.outputs["Distance"], mr.inputs["Value"])
        layers.append(mr)
    mx = nodes.new("ShaderNodeMath")
    mx.operation = "MAXIMUM"
    half = nodes.new("ShaderNodeMath")
    half.operation = "MULTIPLY"
    half.inputs[1].default_value = 0.6
    links.new(layers[1].outputs[0], half.inputs[0])
    links.new(layers[0].outputs[0], mx.inputs[0])
    links.new(half.outputs[0], mx.inputs[1])
    pw = nodes.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 3.0
    links.new(mx.outputs[0], pw.inputs[0])
    # top-facing mask
    sepn = nodes.new("ShaderNodeSeparateXYZ")
    links.new(geo.outputs["Normal"], sepn.inputs[0])
    clampn = nodes.new("ShaderNodeMath")
    clampn.operation = "MULTIPLY"
    clampn.use_clamp = True
    clampn.inputs[1].default_value = 1.3
    links.new(sepn.outputs["Z"], clampn.inputs[0])
    m1 = nodes.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    links.new(pw.outputs[0], m1.inputs[0])
    links.new(clampn.outputs[0], m1.inputs[1])
    m2 = nodes.new("ShaderNodeMath")
    m2.operation = "MULTIPLY_ADD"
    m2.inputs[1].default_value = strength
    m2.inputs[2].default_value = 1.0
    links.new(m1.outputs[0], m2.inputs[0])
    return m2.outputs[0]  # multiplier >= 1


def mul_color(nodes, links, color_socket, fac_socket):
    m = nodes.new("ShaderNodeMix")
    m.data_type = "RGBA"
    m.blend_type = "MULTIPLY"
    m.inputs["Factor"].default_value = 1.0
    links.new(color_socket, m.inputs[6])
    comb = nodes.new("ShaderNodeCombineColor")
    for k in ("Red", "Green", "Blue"):
        links.new(fac_socket, comb.inputs[k])
    links.new(comb.outputs[0], m.inputs[7])
    return m.outputs[2]


# ---------------------------------------------------------------- world: water gradient seen by the camera
world = bpy.data.worlds.new("water")
sc.world = world
world.use_nodes = True
wn, wl = world.node_tree.nodes, world.node_tree.links
wn.clear()
wout = wn.new("ShaderNodeOutputWorld")
tc = wn.new("ShaderNodeTexCoord")
sep = wn.new("ShaderNodeSeparateXYZ")
wl.new(tc.outputs["Generated"], sep.inputs[0])
mr = wn.new("ShaderNodeMapRange")
mr.inputs["From Min"].default_value = -0.35
mr.inputs["From Max"].default_value = 0.5
wl.new(sep.outputs["Z"], mr.inputs["Value"])
ramp = wn.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (*lin3(FOG_DEEP), 1)
ramp.color_ramp.elements[1].color = (*lin3((0.34, 0.72, 0.78)), 1)
e = ramp.color_ramp.elements.new(0.45)
e.color = (*lin3(FOG_MID), 1)
e = ramp.color_ramp.elements.new(0.75)
e.color = (*lin3(FOG_TOP), 1)
wl.new(mr.outputs["Result"], ramp.inputs["Fac"])
bg_cam = wn.new("ShaderNodeBackground")
wl.new(ramp.outputs["Color"], bg_cam.inputs["Color"])
bg_amb = wn.new("ShaderNodeBackground")
bg_amb.inputs["Color"].default_value = (*lin3((0.25, 0.55, 0.62)), 1)
bg_amb.inputs["Strength"].default_value = 0.9
lp = wn.new("ShaderNodeLightPath")
wmix = wn.new("ShaderNodeMixShader")
wl.new(lp.outputs["Is Camera Ray"], wmix.inputs["Fac"])
wl.new(bg_amb.outputs[0], wmix.inputs[1])
wl.new(bg_cam.outputs[0], wmix.inputs[2])
wl.new(wmix.outputs[0], wout.inputs["Surface"])

# ---------------------------------------------------------------- sun (key) from above, slightly behind the camera's right shoulder
sun_d = bpy.data.lights.new("sun", "SUN")
sun_d.energy = 4.2
sun_d.color = SUN_COL
sun_d.angle = math.radians(3)
sun = bpy.data.objects.new("sun", sun_d)
sc.collection.objects.link(sun)
sun.rotation_euler = (math.radians(14), math.radians(-12), 0)
fill_d = bpy.data.lights.new("fill", "AREA")
fill_d.energy = 900
fill_d.size = 12
fill_d.color = lin3((0.55, 0.85, 0.9))
fill = bpy.data.objects.new("fill", fill_d)
sc.collection.objects.link(fill)
fill.location = (0, -10, -3)
fill.rotation_euler = (math.radians(100), 0, 0)


# ---------------------------------------------------------------- seabed (Poly Haven coast_sand_01, CC0)
def img(path, non_color=False):
    im = bpy.data.images.load(str(path))
    if non_color:
        im.colorspace_settings.name = "Non-Color"
    return im


NX, NY = 220, 160
verts, faces = [], []
for iy in range(NY + 1):
    y = -6 + 76 * iy / NY
    for ix in range(NX + 1):
        x = -50 + 100 * ix / NX
        base = -2.25 + max(0.0, y) * 0.035
        dune = 0.12 * math.sin(x * 0.9 + y * 0.3) + 0.07 * math.sin(x * 2.3 - y * 0.7)
        verts.append((x, y, base + dune))
for iy in range(NY):
    for ix in range(NX):
        a = iy * (NX + 1) + ix
        faces.append((a, a + 1, a + NX + 2, a + NX + 1))
me = bpy.data.meshes.new("seabed")
me.from_pydata(verts, [], faces)
bed = bpy.data.objects.new("seabed", me)
sc.collection.objects.link(bed)
for poly in me.polygons:
    poly.use_smooth = True
m, n, l = new_mat("sand")
b = bsdf_of(n)
tcs = n.new("ShaderNodeTexCoord")
mp = n.new("ShaderNodeMapping")
mp.inputs["Scale"].default_value = (0.45, 0.45, 0.45)
l.new(tcs.outputs["Object"], mp.inputs["Vector"])
dif = n.new("ShaderNodeTexImage")
dif.image = img(DL / "coast_sand_01_diff_1k.jpg")
dif.projection = "BOX"
dif.projection_blend = 0.3
rough = n.new("ShaderNodeTexImage")
rough.image = img(DL / "coast_sand_01_rough_1k.jpg", True)
rough.projection = "BOX"
nor = n.new("ShaderNodeTexImage")
nor.image = img(DL / "coast_sand_01_nor_gl_1k.jpg", True)
nor.projection = "BOX"
for t in (dif, rough, nor):
    l.new(mp.outputs["Vector"], t.inputs["Vector"])
nm = n.new("ShaderNodeNormalMap")
nm.inputs["Strength"].default_value = 0.8
l.new(nor.outputs["Color"], nm.inputs["Color"])
l.new(nm.outputs[0], b.inputs["Normal"])
l.new(rough.outputs["Color"], b.inputs["Roughness"])
# warm the sand slightly, then multiply caustics
hsv = n.new("ShaderNodeHueSaturation")
hsv.inputs["Saturation"].default_value = 1.25
hsv.inputs["Value"].default_value = 0.8
l.new(dif.outputs["Color"], hsv.inputs["Color"])
caus = caustic_socket(n, l, scale=2.3, strength=1.5)
l.new(mul_color(n, l, hsv.outputs["Color"], caus), b.inputs["Base Color"])
bed.data.materials.append(m)
fog_wrap(m, start=6, end=30)


def bed_z0(x, y):
    return (
        -2.25
        + max(0.0, y) * 0.035
        + 0.12 * math.sin(x * 0.9 + y * 0.3)
        + 0.07 * math.sin(x * 2.3 - y * 0.7)
    )


bed_z = bed_z0


# ---------------------------------------------------------------- rocks (Poly Haven coast_rocks_01, CC0)
rock_src = []
try:
    bpy.ops.import_scene.gltf(filepath=str(DL / "rocks" / "coast_rocks_01_1k.gltf"))
    rock_src = [o for o in bpy.context.selected_objects if o.type == "MESH"]
    for o in rock_src:
        for ms in o.data.materials:
            fog_wrap(ms, start=3, end=34)
    print("rocks", [(o.name, tuple(round(d, 2) for d in o.dimensions)) for o in rock_src])
except Exception as ex:  # noqa: BLE001 - mock tool, log and go on
    print("rock import failed", ex)


def place_rock(src, loc, scale, rotz):
    o = src.copy()
    o.data = src.data
    sc.collection.objects.link(o)
    o.parent = None
    o.location = loc
    o.scale = (scale, scale, scale)
    o.rotation_euler = (0, 0, rotz)
    return o


if rock_src:
    # hide originals, then place instances behind the play plane
    big = max(rock_src, key=lambda o: o.dimensions.length)
    for o in rock_src:
        o.hide_render = True
    for loc, s, r in (
        ((-3.4, 2.5), 0.22, 0.4),
        ((3.6, 4.0), 0.30, 2.0),
        ((-6.0, 10.0), 0.45, 1.1),
        ((1.5, 15.0), 0.5, 3.0),
        ((8.0, 13.0), 0.5, 0.2),
    ):
        place_rock(big, (loc[0], loc[1], bed_z(loc[0], loc[1]) - 0.15), s, r)


# ---------------------------------------------------------------- kelp + seagrass: the game GLBs from assets/models/kelp
ASSETS = Path(__file__).resolve().parents[3] / "assets/models"
sys.path.insert(0, str(Path(__file__).resolve().parent))
import fish_build  # noqa: E402
import kelp_build  # noqa: E402


def import_glb(path, name):
    """Import one GLB (single mesh) and return it hidden, as a prototype whose mesh data copies share."""
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    new = [o for o in bpy.data.objects if o not in before]
    ob = next(o for o in new if o.type == "MESH")
    for o in new:
        if o is not ob:
            bpy.data.objects.remove(o)
    ob.parent = None
    ob.name = name
    ob.hide_render = True
    ob.location = (0, -60, -60)
    return ob


def add_caustics_to_base(mat, scale, strength):
    n, l = mat.node_tree.nodes, mat.node_tree.links
    b = bsdf_of(n)
    src = b.inputs["Base Color"].links[0].from_socket
    caus = caustic_socket(n, l, scale=scale, strength=strength)
    l.new(mul_color(n, l, src, caus), b.inputs["Base Color"])


KELP_MAT = kelp_build.kelp_material(ASSETS / "kelp/textures")
add_caustics_to_base(KELP_MAT, 1.4, 1.2)
fog_wrap(KELP_MAT, start=4, end=36)
KELP = {}
for nm in (
    "kelp_giant_a",
    "kelp_giant_b",
    "kelp_giant_c",
    "kelp_giant_far",
    "kelp_sugar",
    "seagrass_tuft",
):
    o = import_glb(ASSETS / f"kelp/{nm}.glb", nm + "_proto")
    o.data.materials.clear()
    o.data.materials.append(KELP_MAT)
    KELP[nm] = o


def kelp_instance(kind, name, loc, s, rotz):
    o = bpy.data.objects.new(name, KELP[kind].data)
    sc.collection.objects.link(o)
    o.scale = (s, s, s)
    o.location = loc
    o.rotation_euler = (0, 0, rotz)
    return o


kelp_count = 0
# kelp forest behind the play plane, thicker toward the sides so the centre stays open for play
for _ in range(200):
    y = random.uniform(4.0, 30)
    half = 2.0 + y * 0.42
    x = random.uniform(-half, half)
    if abs(x) < 1.6 and y < 10:  # keep a clear lane behind the play area
        continue
    kind = (
        random.choice(("kelp_giant_a", "kelp_giant_b", "kelp_giant_c"))
        if y < 15
        else "kelp_giant_far"
    )
    s = random.uniform(0.85, 1.2) * (1 + y * 0.02)
    kelp_instance(kind, "kelp", (x, y, bed_z(x, y) - 0.05), s, random.uniform(-0.5, 0.5))
    kelp_count += 1
# two foreground frame strands at the screen edges only (never over the play area centre)
for x, y in ((-2.35, -1.4), (2.3, -1.8)):
    o = kelp_instance("kelp_giant_b", "kelp_fg", (x, y, bed_z(x, y)), 0.9, 0)
    o.scale = (0.9, 0.9, 0.8)
# sugar-kelp clumps on the floor in the mid ground, off the play lane
for _ in range(14):
    y = random.uniform(2.5, 12)
    x = random.choice((-1, 1)) * random.uniform(1.4, 4.5 + y * 0.3)
    kelp_instance(
        "kelp_sugar",
        "sugarkelp",
        (x, y, bed_z(x, y) - 0.02),
        random.uniform(0.6, 0.9),
        random.uniform(-0.6, 0.6),
    )
print("kelp instances", kelp_count)

# ---------------------------------------------------------------- seagrass tufts (particle hair = Godot MultiMesh)
blade = KELP["seagrass_tuft"]  # eelgrass tufts (assets/models/kelp/seagrass_tuft.glb)

# emitter patch: a copy of the seabed region in front
bpy.ops.mesh.primitive_plane_add(size=1)
patch = bpy.context.object
patch.name = "grass_patch"
patch.scale = (14, 9, 1)
patch.location = (0, 3.5, 0)
bpy.ops.object.transform_apply(scale=True, location=True)
bm = bmesh.new()
bm.from_mesh(patch.data)
bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=40, use_grid_fill=True)
for v in bm.verts:
    v.co.z = bed_z(v.co.x, v.co.y) + 0.01
bm.to_mesh(patch.data)
bm.free()
patch.hide_render = False
patch.data.materials.append(m)  # sand under it is invisible anyway
ps_mod = patch.modifiers.new("grass", "PARTICLE_SYSTEM")
pset = ps_mod.particle_system.settings
pset.type = "HAIR"
pset.count = 4000
pset.hair_length = 0.32
pset.render_type = "OBJECT"
pset.instance_object = blade
pset.particle_size = 1.0
pset.size_random = 0.45
pset.use_rotations = True
pset.rotation_mode = "NOR"
pset.phase_factor_random = 2.0
pset.rotation_factor_random = 0.25
patch.show_instancer_for_render = False


# ---------------------------------------------------------------- fish: the game GLBs from assets/models/fish
FISH_MATS = fish_build.make_fish_materials(ASSETS / "fish/textures")
for m in FISH_MATS.values():
    add_caustics_to_base(m, 1.6, 0.9)
# player copy of the body material with the sun-catch rim (Godot: rim 0.5, rim_tint 0.6, #FFE7A0)
PLAYER_BODY = FISH_MATS[fish_build.BODY_MAT].copy()
PLAYER_BODY.name = "fish_w1_body_player"
_n, _l = PLAYER_BODY.node_tree.nodes, PLAYER_BODY.node_tree.links
_b = bsdf_of(_n)
_lw = _n.new("ShaderNodeLayerWeight")
_lw.inputs["Blend"].default_value = 0.35
_pw = _n.new("ShaderNodeMath")
_pw.operation = "POWER"
_pw.inputs[1].default_value = 1.0
_l.new(_lw.outputs["Facing"], _pw.inputs[0])
_rm = _n.new("ShaderNodeMath")
_rm.operation = "MULTIPLY"
_rm.inputs[1].default_value = 2.5
_l.new(_pw.outputs[0], _rm.inputs[0])
setin(_b, ["Emission Color"], hexc("#ffe7a0"))
_l.new(_rm.outputs[0], _b.inputs["Emission Strength"])
for m in (*FISH_MATS.values(), PLAYER_BODY):
    fog_wrap(m, start=10, end=34)
SPECIES_GLB = {
    "player": "golden_trevally",
    "sprat": "brisling",
    "wrasse": "gronngylt",
    "sei": "sei",
    "berggylt": "berggylt",
    "pollock": "lyr",
    "cod": "torsk",
    "bass": "havabbor",
}
FISH_PROTO = {}
for key, glb in SPECIES_GLB.items():
    o = import_glb(ASSETS / f"fish/{glb}.glb", glb + "_proto")
    o.data.materials.clear()
    o.data.materials.append(PLAYER_BODY if key == "player" else FISH_MATS[fish_build.BODY_MAT])
    o.data.materials.append(FISH_MATS[fish_build.FIN_MAT])
    FISH_PROTO[key] = o


def build_fish(name, L, sp):
    """One copy of the species GLB scaled to total length L (GLBs are 1 m nose to tail)."""
    o = bpy.data.objects.new(name, FISH_PROTO[sp].data)
    sc.collection.objects.link(o)
    o.scale = (L, L, L)
    return o


def place(fish, x, z, facing_left, y=0.0, yaw=0.0, roll=0.0, index=0):
    fish.location = (x, y, z)
    fish.rotation_euler = (roll, 0, (math.pi if facing_left else 0) + yaw)
    fish.pass_index = index
    for ch in fish.children:
        ch.pass_index = index


# GDD 4.2 tiers in px at 1080x1920: 72 x 1.28^(t-1). On the play plane 1 m = PX_PER_M px.
def tier_m(t):
    return 72 * 1.28 ** (t - 1) / PX_PER_M


def px_to_xz(px, py):
    return (px - 540) / PX_PER_M, (960 - py) / PX_PER_M


# Mock = world 1 level 2 "Storre fisker", Lett, goal tier 4. Player tier 3 (118 px), FISH_MAX 7 (GDD 6.3).
# kind: 1 edible, 2 danger, 4 same tier (no ring), 3 player
CAST = [
    ("player", "player", 3, (520, 900), False, -8, 3),
    ("brisling_a", "sprat", 1, (770, 640), True, 6, 1),
    ("brisling_b", "sprat", 1, (860, 715), True, -10, 1),
    ("gronngylt_a", "wrasse", 2, (250, 1120), False, 12, 1),
    ("gronngylt_b", "wrasse", 2, (400, 1380), True, -8, 1),
    ("sei_same", "sei", 3, (300, 520), False, 4, 4),
    ("berggylt_danger", "berggylt", 4, (820, 1060), True, 10, 2),
    ("lyr_danger", "pollock", 5, (650, 1480), True, -4, 2),
]
FISH_INFO = []
for name, sp, tier, (px, py), left, yaw, kind in CAST:
    L = tier_m(tier)
    f = build_fish(name, L, sp)
    x, z = px_to_xz(px, py)
    place(f, x, z, facing_left=left, yaw=math.radians(yaw), index=kind)
    FISH_INFO.append(
        {
            "name": name,
            "species": sp,
            "tier": tier,
            "px": px,
            "py": py,
            "len_px": round(72 * 1.28 ** (tier - 1)),
            "kind": kind,
            "facing_left": left,
        }
    )

# scenery only (behind the play plane, fogged, never interactive): MultiMesh schools in Godot
cod = build_fish("cod_far", 1.97, "cod")
place(cod, -3.2, 0.2, facing_left=False, y=11.0, yaw=math.radians(25), index=0)
for i in range(30):
    s_ = build_fish(f"farschool{i}", 0.30, "sprat")
    place(
        s_,
        3.6 + random.gauss(0, 1.0),
        2.4 + random.gauss(0, 0.6),
        facing_left=False,
        y=16 + random.uniform(-1, 1),
        yaw=math.radians(random.uniform(-15, 15)),
        index=0,
    )
for i in range(40):
    s_ = build_fish(f"midschool{i}", 0.26, "sprat")
    place(
        s_,
        -2.6 + random.gauss(0, 0.7),
        1.9 + random.gauss(0, 0.35),
        facing_left=True,
        y=8 + random.uniform(-0.6, 0.6),
        yaw=math.radians(random.uniform(-12, 12)),
        index=0,
    )
import json  # noqa: E402

(OUT / "fish.json").write_text(json.dumps({"px_per_m": PX_PER_M, "fish": FISH_INFO}, indent=1))


# ---------------------------------------------------------------- god rays (additive cards)
def ray_material():
    m, n, l = new_mat("ray")
    n.clear()
    out = n.new("ShaderNodeOutputMaterial")
    tcs = n.new("ShaderNodeTexCoord")
    sep = n.new("ShaderNodeSeparateXYZ")
    l.new(tcs.outputs["Generated"], sep.inputs[0])
    # fade to the bottom and to both side edges
    g1 = n.new("ShaderNodeMapRange")
    g1.inputs["From Min"].default_value = 0.0
    g1.inputs["From Max"].default_value = 1.0
    l.new(sep.outputs["Y"], g1.inputs["Value"])
    pw = n.new("ShaderNodeMath")
    pw.operation = "POWER"
    pw.inputs[1].default_value = 2.2
    l.new(g1.outputs[0], pw.inputs[0])
    sx_ = n.new("ShaderNodeMath")
    sx_.operation = "SUBTRACT"
    sx_.inputs[1].default_value = 0.5
    l.new(sep.outputs["X"], sx_.inputs[0])
    ab = n.new("ShaderNodeMath")
    ab.operation = "ABSOLUTE"
    l.new(sx_.outputs[0], ab.inputs[0])
    edge = n.new("ShaderNodeMapRange")
    edge.inputs["From Min"].default_value = 0.5
    edge.inputs["From Max"].default_value = 0.0
    l.new(ab.outputs[0], edge.inputs["Value"])
    noise = n.new("ShaderNodeTexNoise")
    noise.inputs["Scale"].default_value = 6.0
    mpn = n.new("ShaderNodeMapping")
    mpn.inputs["Scale"].default_value = (6, 0.15, 1)
    l.new(tcs.outputs["Generated"], mpn.inputs["Vector"])
    l.new(mpn.outputs[0], noise.inputs["Vector"])
    m1 = n.new("ShaderNodeMath")
    m1.operation = "MULTIPLY"
    l.new(pw.outputs[0], m1.inputs[0])
    l.new(edge.outputs[0], m1.inputs[1])
    m2 = n.new("ShaderNodeMath")
    m2.operation = "MULTIPLY"
    l.new(m1.outputs[0], m2.inputs[0])
    l.new(noise.outputs["Fac"], m2.inputs[1])
    m3 = n.new("ShaderNodeMath")
    m3.operation = "MULTIPLY"
    m3.inputs[1].default_value = 0.6
    l.new(m2.outputs[0], m3.inputs[0])
    em = n.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (*lin3((0.85, 0.97, 0.95)), 1)
    l.new(m3.outputs[0], em.inputs["Strength"])
    tr = n.new("ShaderNodeBsdfTransparent")
    add = n.new("ShaderNodeAddShader")
    l.new(em.outputs[0], add.inputs[0])
    l.new(tr.outputs[0], add.inputs[1])
    l.new(add.outputs[0], out.inputs["Surface"])
    m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    return m


RAY = ray_material()
for i in range(16):
    yv = random.uniform(3.0, 14.0)
    xv = random.uniform(-3.5, 3.5) + yv * 0.1
    wv = random.uniform(0.12, 0.42) * (1 + yv * 0.05)
    bpy.ops.mesh.primitive_plane_add(size=1, location=(xv, yv, -0.4))
    r = bpy.context.object
    r.name = "ray"
    r.scale = (wv, 8.8, 1)
    r.rotation_euler = (math.radians(90), math.radians(random.uniform(-16, -4)), 0)
    r.data.materials.append(RAY)
    r.visible_shadow = False
    r.visible_diffuse = False
    r.visible_glossy = False

# ---------------------------------------------------------------- water surface seen from below
bpy.ops.mesh.primitive_plane_add(size=1, location=(0, 25, 4.0))
surf = bpy.context.object
surf.name = "surface"
surf.scale = (120, 80, 1)
surf.rotation_euler = (math.pi, 0, 0)
ms, nsu, lsu = new_mat("surface")
nsu.clear()
out = nsu.new("ShaderNodeOutputMaterial")
geo = nsu.new("ShaderNodeNewGeometry")
vo = nsu.new("ShaderNodeTexVoronoi")
vo.feature = "DISTANCE_TO_EDGE"
vo.inputs["Scale"].default_value = 2.6
nz = nsu.new("ShaderNodeTexNoise")
nz.inputs["Scale"].default_value = 3.0
vm = nsu.new("ShaderNodeVectorMath")
vm.operation = "MULTIPLY_ADD"
vm.inputs[1].default_value = (0.35, 0.35, 0.35)
lsu.new(geo.outputs["Position"], nz.inputs["Vector"])
lsu.new(nz.outputs["Color"], vm.inputs[0])
lsu.new(geo.outputs["Position"], vm.inputs[2])
lsu.new(vm.outputs[0], vo.inputs["Vector"])
mr = nsu.new("ShaderNodeMapRange")
mr.inputs["From Max"].default_value = 0.12
mr.inputs["To Min"].default_value = 1.0
mr.inputs["To Max"].default_value = 0.55
lsu.new(vo.outputs["Distance"], mr.inputs["Value"])
em = nsu.new("ShaderNodeEmission")
em.inputs["Color"].default_value = (*lin3((0.62, 0.92, 0.93)), 1)
mul = nsu.new("ShaderNodeMath")
mul.operation = "MULTIPLY"
mul.inputs[1].default_value = 1.0
lsu.new(mr.outputs[0], mul.inputs[0])
lsu.new(mul.outputs[0], em.inputs["Strength"])
lsu.new(em.outputs[0], out.inputs["Surface"])
surf.data.materials.append(ms)
surf.visible_diffuse = False
surf.visible_shadow = False
fog_wrap(ms, start=4, end=22, maxfog=1.0)

# ---------------------------------------------------------------- marine snow and bubbles
mb, nb, lb = new_mat("bubble")
nb.clear()
out = nb.new("ShaderNodeOutputMaterial")
lw = nb.new("ShaderNodeLayerWeight")
lw.inputs["Blend"].default_value = 0.25
emb = nb.new("ShaderNodeEmission")
emb.inputs["Color"].default_value = (1, 1, 1, 1)
mulb = nb.new("ShaderNodeMath")
mulb.operation = "MULTIPLY"
mulb.inputs[1].default_value = 2.2
lb.new(lw.outputs["Fresnel"], mulb.inputs[0])
lb.new(mulb.outputs[0], emb.inputs["Strength"])
trb = nb.new("ShaderNodeBsdfTransparent")
addb = nb.new("ShaderNodeAddShader")
lb.new(emb.outputs[0], addb.inputs[0])
lb.new(trb.outputs[0], addb.inputs[1])
lb.new(addb.outputs[0], out.inputs["Surface"])
player_xz = px_to_xz(520, 900)
for i in range(10):  # bubble trail rising from the player's gill
    t = i / 9
    bpy.ops.mesh.primitive_uv_sphere_add(
        radius=0.012 + 0.018 * random.random(),
        segments=24,
        ring_count=16,
        location=(
            player_xz[0] + 0.05 + 0.10 * math.sin(t * 7) + random.gauss(0, 0.02),
            -0.05,
            player_xz[1] + 0.12 + t * 1.5,
        ),
    )
    bpy.context.object.data.materials.append(mb)
    bpy.ops.object.shade_smooth()
msnow, nsn, lsn = new_mat("snow")
bsn = bsdf_of(nsn)
bsn.inputs["Base Color"].default_value = (0.9, 0.95, 0.92, 1)
setin(bsn, ["Emission Color"], (0.8, 0.95, 0.9, 1))
setin(bsn, ["Emission Strength"], 0.6)
for i in range(260):
    bpy.ops.mesh.primitive_ico_sphere_add(
        radius=random.uniform(0.004, 0.012),
        subdivisions=1,
        location=(random.uniform(-3, 3), random.uniform(-3, 9), random.uniform(-2.6, 3.0)),
    )
    bpy.context.object.data.materials.append(msnow)

# ---------------------------------------------------------------- passes + compositor (glow, masks)
vl = sc.view_layers[0]
vl.use_pass_object_index = True
sc.use_nodes = True
ct = sc.node_tree
ct.nodes.clear()
rl = ct.nodes.new("CompositorNodeRLayers")
glare = ct.nodes.new("CompositorNodeGlare")
try:
    glare.glare_type = "BLOOM"
except TypeError:
    glare.glare_type = "FOG_GLOW"
for attr, val in (("quality", "HIGH"), ("threshold", 1.1), ("mix", -0.7), ("size", 7)):
    try:
        setattr(glare, attr, val)
    except (TypeError, AttributeError):
        pass
for nm_, val in (("Threshold", 1.1), ("Strength", 0.35), ("Size", 0.5)):
    if nm_ in glare.inputs:
        glare.inputs[nm_].default_value = val
comp = ct.nodes.new("CompositorNodeComposite")
ct.links.new(rl.outputs["Image"], glare.inputs["Image"])
ct.links.new(glare.outputs["Image"], comp.inputs["Image"])
fo = ct.nodes.new("CompositorNodeOutputFile")
fo.base_path = str(OUT)
fo.format.file_format = "PNG"
fo.format.color_mode = "BW"
fo.file_slots.clear()
for idx, nm_ in ((1, "mask_edible"), (2, "mask_danger"), (3, "mask_player")):
    idm = ct.nodes.new("CompositorNodeIDMask")
    idm.index = idx
    idm.use_antialiasing = True
    ct.links.new(rl.outputs["IndexOB"], idm.inputs["ID value"])
    fo.file_slots.new(nm_ + "_")
    ct.links.new(idm.outputs["Alpha"], fo.inputs[len(fo.inputs) - 1])

sc.render.filepath = str(OUT / "w1_raw.png")
sc.render.image_settings.file_format = "PNG"
bpy.ops.wm.save_as_mainfile(filepath=str(OUT / "world1_mock.blend"))
bpy.ops.render.render(write_still=True)
print("DONE", OUT)
