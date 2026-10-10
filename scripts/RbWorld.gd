class_name RbWorld
extends Node3D

## World 1 "Tareskogen" (DESIGN 2, 3, 10): fixed perspective camera looking
## along -Z at the play plane z = 0 (1 logic px = 1 / 296.3 m), sun, depth
## and height fog, the water ramp behind everything, sand floor with
## caustics, granite boulders, a kelp forest in two MultiMesh chunks with a
## clear lane behind the pond centre, seagrass, god-ray cards, the water
## surface seen from below, marine snow and two far scenery schools. Also
## holds the on-plane kelp patches (Tare friend), the pearl shell, blob
## shadows, the fish views and the marks MultiMesh.

const CAM_DIST: float = 9.0
const CAM_FOV: float = 22.9
const FLOOR_Y: float = -2.42
const SURFACE_Y: float = 4.0
const FOG_TOP := Color(0.200, 0.561, 0.631)
const FOG_MID := Color(0.059, 0.329, 0.420)
const FOG_DEEP := Color(0.024, 0.200, 0.278)
const PLAY_WATER := Color(0.165, 0.408, 0.459)
const SUN := Color(1.0, 0.961, 0.859)
const KELP_DIR := "res://assets/models/kelp/"

var camera: Camera3D
var env: Environment
var sun: DirectionalLight3D
var marks: RbMarks
var actors: Node3D
var low: bool = false
var less_motion: bool = false
var caustic_tex: Texture2D
var _kelp_mesh: ArrayMesh
var _kelp_mat: ShaderMaterial
var _glb_kelp_mats: Array[ShaderMaterial] = []
var _patch_mat: ShaderMaterial
var _patch_root: Node3D
var _patch_rock_mat: ShaderMaterial
var _rays_mat: ShaderMaterial
var _snow: GPUParticles3D
var _schools: Array[Node3D] = []
var _school_dir: Array[float] = []
var _school_mat: ShaderMaterial
var _blobs: MultiMeshInstance3D
var _shell: Node3D
var _shell_top: Node3D
var _pearl: MeshInstance3D
var _mats_caustic: Array[ShaderMaterial] = []
var _zoom: float = 1.0
var _zoom_from: float = 1.0
var _zoom_to: float = 1.0
var _zoom_t: float = 99.0
var _zoom_s: float = 0.8
var _shimmer_t: float = 99.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	low = RbGame.quality_low
	_rng.seed = 77
	caustic_tex = load("res://assets/textures/rb_caustics.png")
	_build_camera_env()
	_build_backdrop()
	_build_floor()
	_build_rocks()
	_build_kelp_forest()
	_build_seagrass()
	_build_surface()
	_build_rays()
	_build_schools()
	_build_snow()
	_patch_rock_mat = _caustic_mat("res://shaders/rb_rock.gdshader")
	_build_patches()
	_build_blobs()
	_build_shell()
	actors = Node3D.new()
	actors.name = "Actors"
	add_child(actors)
	marks = RbMarks.new()
	marks.name = "Marks"
	add_child(marks)


# ---------------------------------------------------------------- build


func _build_camera_env() -> void:
	camera = Camera3D.new()
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.fov = CAM_FOV
	camera.near = 0.3
	camera.far = 80.0
	camera.position = Vector3(0.0, 0.0, CAM_DIST)
	add_child(camera)
	camera.make_current()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = FOG_DEEP
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(FOG_MID.r * 1.6, FOG_MID.g * 1.6, FOG_MID.b * 1.6)
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = PLAY_WATER
	env.fog_light_energy = 1.0
	env.fog_density = 1.0
	env.fog_depth_begin = 10.0
	env.fog_depth_end = 34.0
	env.fog_depth_curve = 0.8
	env.fog_sky_affect = 1.0
	env.fog_height = -2.5
	env.fog_height_density = 0.15
	env.glow_enabled = not low
	env.glow_hdr_threshold = 1.2
	env.glow_intensity = 0.35
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.light_color = SUN
	sun.light_energy = 1.6
	sun.shadow_enabled = false
	add_child(sun)
	# 14 degrees off vertical, a little toward the camera so flanks catch light.
	var dir := Vector3(sin(deg_to_rad(14.0)), -cos(deg_to_rad(14.0)), -0.35).normalized()
	sun.look_at_from_position(Vector3.ZERO, dir, Vector3(0, 0, -1))


func _caustic_mat(shader_path: String) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load(shader_path)
	m.set_shader_parameter("caustic_tex", caustic_tex)
	_mats_caustic.append(m)
	return m


func _build_backdrop() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(90.0, 70.0)
	var mi := MeshInstance3D.new()
	mi.mesh = q
	mi.position = Vector3(0.0, 4.0, -40.0)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rb_backdrop.gdshader")
	m.set_shader_parameter("top_color", FOG_TOP)
	m.set_shader_parameter("mid_color", PLAY_WATER)
	m.set_shader_parameter("deep_color", FOG_DEEP)
	m.set_shader_parameter("top_y", 14.0)
	m.set_shader_parameter("mid_y", 0.0)
	m.set_shader_parameter("deep_y", -8.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_floor() -> void:
	var p := PlaneMesh.new()
	p.size = Vector2(70.0, 48.0)
	p.subdivide_width = 70
	p.subdivide_depth = 48
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.position = Vector3(0.0, FLOOR_Y, -20.0)
	var m: ShaderMaterial = _caustic_mat("res://shaders/rb_floor.gdshader")
	m.set_shader_parameter("sand_albedo", load("res://assets/textures/coast_sand_01_diff_1k.jpg"))
	m.set_shader_parameter("sand_normal", load("res://assets/textures/coast_sand_01_nor_gl_1k.jpg"))
	m.set_shader_parameter("deep_tint", FOG_MID)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _rock_mesh() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 14
	sm.rings = 8
	var arrays: Array = sm.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 1.6
	for i: int in verts.size():
		var v: Vector3 = verts[i]
		var k: float = 1.0 + 0.28 * noise.get_noise_3dv(v * 2.0)
		v *= k
		v.y = v.y * 0.62 if v.y > 0.0 else v.y * 0.35
		verts[i] = v
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = null
	arrays[Mesh.ARRAY_TANGENT] = null
	var st := SurfaceTool.new()
	var tmp := ArrayMesh.new()
	tmp.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	st.create_from(tmp, 0)
	st.generate_normals()
	return st.commit()


func _build_rocks() -> void:
	var spots: Array[Vector4] = [
		Vector4(-2.3, -3.0, 1.1, 0.0),
		Vector4(2.6, -4.5, 1.5, 1.0),
		Vector4(-3.4, -7.5, 1.9, 2.0),
		Vector4(3.6, -9.0, 2.2, 3.0),
		Vector4(-1.9, -12.0, 1.4, 4.0),
		Vector4(1.4, -15.0, 2.0, 5.0),
		Vector4(-4.8, -14.0, 2.6, 6.0),
		Vector4(5.2, -16.5, 2.8, 7.0),
		Vector4(-0.6, -20.0, 2.4, 8.0),
		Vector4(3.0, -23.0, 3.0, 9.0),
		Vector4(-3.6, -25.0, 3.2, 10.0),
		Vector4(1.9, -6.5, 0.7, 11.0),
	]
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _rock_mesh()
	mm.instance_count = spots.size()
	for i: int in spots.size():
		var s: Vector4 = spots[i]
		var b := Basis(Vector3.UP, s.w * 1.7).scaled(Vector3(s.z * 1.3, s.z, s.z * 1.1))
		mm.set_instance_transform(i, Transform3D(b, Vector3(s.x, FLOOR_Y + s.z * 0.12, s.y)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _caustic_mat("res://shaders/rb_rock.gdshader")
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Kelp frond (DESIGN 10): stipe ribbon plus alternating tapered blades,
## base at y = 0, tip at y = 1, about 120 triangles. blade_from > 0 leaves
## the lower stipe bare (tall kelp with its canopy up in the water).
func _make_kelp_mesh(
	blade_from: float = 0.14, n_blades: int = 16, blade_k: float = 1.0, sw: float = 0.008
) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs: int = 10
	for i: int in segs:
		var y0: float = float(i) / float(segs)
		var y1: float = float(i + 1) / float(segs)
		var x0: float = sin(y0 * 3.0) * 0.02
		var x1: float = sin(y1 * 3.0) * 0.02
		_quad(
			st,
			Vector3(x0 - sw, y0, 0),
			Vector3(x0 + sw, y0, 0),
			Vector3(x1 + sw, y1, 0),
			Vector3(x1 - sw, y1, 0)
		)
	for b: int in n_blades:
		var y: float = blade_from + (0.98 - blade_from) * float(b) / float(n_blades - 1)
		var side: float = 1.0 if b % 2 == 0 else -1.0
		var root := Vector3(sin(y * 3.0) * 0.02, y, 0.0)
		var length: float = (0.10 + 0.05 * sin(float(b) * 1.9)) * blade_k
		var width: float = (0.022 + 0.008 * cos(float(b) * 1.3)) * blade_k
		var ang: float = deg_to_rad(38.0 + 10.0 * sin(float(b) * 2.3))
		var dirv := Vector3(side * sin(ang), cos(ang), 0.0)
		var perp := Vector3(-dirv.y, dirv.x, 0.0)
		var twist: float = 0.4 * side
		var prev_l := root - perp * width * 0.2
		var prev_r := root + perp * width * 0.2
		for s: int in 3:
			var k: float = float(s + 1) / 3.0
			var c: Vector3 = root + dirv * length * k + Vector3(0, -0.02 * k * k, 0)
			var w: float = width * sin(PI * minf(k * 0.95 + 0.05, 1.0)) * (1.0 if s < 2 else 0.25)
			var tz := Vector3(0, 0, twist * w)
			var l: Vector3 = c - perp * w * 0.5 + tz
			var r: Vector3 = c + perp * w * 0.5 - tz
			_quad(st, prev_l, prev_r, r, l)
			prev_l = l
			prev_r = r
	st.generate_normals()
	return st.commit()


func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for v: Vector3 in [a, b, c, a, c, d]:
		st.add_vertex(v)


## Background kelp is darker and duller; the on-plane patch (a gameplay
## friend) keeps full contrast so it reads as "on the plane" (DESIGN 2).
func _kelp_material(on_plane: bool) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rb_kelp.gdshader")
	m.set_shader_parameter("wind_dir", Vector2(1.0, 0.0))
	m.set_shader_parameter("ground_color", Color(0.20, 0.15, 0.07))
	if on_plane:
		# Gentle sway so the leaves stay over the safe rect.
		m.set_shader_parameter("wind_strength", 0.022)
		m.set_shader_parameter("brightness", 0.8)
		m.set_shader_parameter("color_bottom", Color(0.26, 0.18, 0.07))
		m.set_shader_parameter("color_top", Color(0.60, 0.43, 0.17))
		m.set_shader_parameter("trans_strength", 1.0)
		m.set_shader_parameter("patch_lush", Color(0.45, 0.33, 0.12))
		m.set_shader_parameter("patch_dry", Color(0.58, 0.46, 0.20))
	else:
		m.set_shader_parameter("brightness", 0.62)
		m.set_shader_parameter("color_bottom", Color(0.22, 0.16, 0.06))
		m.set_shader_parameter("color_top", Color(0.50, 0.40, 0.17))
		m.set_shader_parameter("trans_strength", 0.9)
		m.set_shader_parameter("patch_lush", Color(0.36, 0.30, 0.12))
		m.set_shader_parameter("patch_dry", Color(0.46, 0.38, 0.17))
		m.set_shader_parameter("patch_strength", 0.25)
	return m


func _build_kelp_forest() -> void:
	_kelp_mesh = _make_kelp_mesh()
	_kelp_mat = _kelp_material(false)
	var near: int = 42 if low else 70
	var far: int = 60 if low else 130
	# Sculpted kelp (assets/models/kelp/README.md) when present, else the
	# procedural frond. Two near meshes (a, b) and the light far strand.
	var near_meshes: Array[Mesh] = []
	for n: String in ["kelp_giant_a", "kelp_giant_b"]:
		var m: Mesh = _glb_mesh(KELP_DIR + n + ".glb")
		if m != null:
			near_meshes.append(m)
	var far_mesh: Mesh = _glb_mesh(KELP_DIR + "kelp_giant_far.glb")
	var use_glb: bool = near_meshes.size() == 2 and far_mesh != null
	var near_xf: Array = [[], []]
	for i: int in near:
		var z: float = _rng.randf_range(-10.0, -2.5)
		var half: float = (CAM_DIST - z) * 0.2025 + 0.6
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var x: float = side * _rng.randf_range(1.6, half)
		var h: float = _rng.randf_range(0.85, 1.2) if use_glb else _rng.randf_range(4.2, 6.6)
		(near_xf[(i / 2) % 2 if use_glb else 0] as Array).append(_kelp_xf(x, z, h))
	var far_xf: Array = []
	for i: int in far:
		var z: float = _rng.randf_range(-30.0, -10.0)
		var half: float = (CAM_DIST - z) * 0.2025 + 1.0
		var x: float = _rng.randf_range(-half, half)
		var h2: float = _rng.randf_range(0.85, 1.2) if use_glb else _rng.randf_range(5.0, 8.0)
		far_xf.append(_kelp_xf(x, z, h2))
	if use_glb:
		var mat: ShaderMaterial = _kelp_glb_material(0.06, 0.8)
		add_child(_kelp_mmi(near_xf[0], mat, near_meshes[0]))
		add_child(_kelp_mmi(near_xf[1], mat, near_meshes[1]))
		add_child(_kelp_mmi(far_xf, mat, far_mesh))
	else:
		add_child(_kelp_mmi(near_xf[0], _kelp_mat, _kelp_mesh))
		add_child(_kelp_mmi(far_xf, _kelp_mat, _kelp_mesh))


## First mesh of a GLB scene, or null when the file is not there.
func _glb_mesh(path: String) -> Mesh:
	if not RbFishCatalog.use_models or not ResourceLoader.exists(path):
		return null
	var scene := load(path) as PackedScene
	if scene == null:
		return null
	var inst: Node = scene.instantiate()
	var found: Mesh = null
	for c: Node in inst.find_children("*", "MeshInstance3D", true, false):
		found = (c as MeshInstance3D).mesh
		break
	inst.free()
	return found


func _kelp_glb_material(strength: float, brightness: float) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rb_kelp_glb.gdshader")
	var tex: String = KELP_DIR + "textures/kelp_w1_"
	m.set_shader_parameter("albedo_tex", load(tex + "albedo.png"))
	m.set_shader_parameter("normal_tex", load(tex + "normal.png"))
	m.set_shader_parameter("orm_tex", load(tex + "orm.png"))
	m.set_shader_parameter("use_normal_map", not low)
	m.set_shader_parameter("strength", strength)
	m.set_shader_parameter("brightness", brightness)
	m.set_meta(&"strength", strength)
	_glb_kelp_mats.append(m)
	return m


func _kelp_xf(x: float, z: float, h: float) -> Transform3D:
	var b := Basis(Vector3.UP, _rng.randf_range(-0.6, 0.6)).scaled(Vector3(h, h, h))
	return Transform3D(b, Vector3(x, FLOOR_Y - 0.05, z))


func _kelp_mmi(xfs: Array, mat: ShaderMaterial, mesh: Mesh) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xfs.size()
	for i: int in xfs.size():
		mm.set_instance_transform(i, xfs[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi


func _blade_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = [
		Vector3(-0.5, 0.0, 0),
		Vector3(0.5, 0.0, 0),
		Vector3(-0.38, 0.35, 0),
		Vector3(0.38, 0.35, 0),
		Vector3(-0.22, 0.7, 0),
		Vector3(0.22, 0.7, 0),
		Vector3(0.0, 1.0, 0),
	]
	var tris: Array[int] = [0, 1, 3, 0, 3, 2, 2, 3, 5, 2, 5, 4, 4, 5, 6]
	for i: int in tris:
		st.set_normal(Vector3(0, 0, 1))
		st.add_vertex(pts[i])
	return st.commit()


func _build_seagrass() -> void:
	var tuft_mesh: Mesh = _glb_mesh(KELP_DIR + "seagrass_tuft.glb")
	if tuft_mesh != null:
		_build_seagrass_glb(tuft_mesh)
		return
	var n: int = 800 if low else 2000
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _blade_mesh()
	mm.instance_count = n
	for i: int in n:
		# Tufts: blades cluster around tuft centres.
		var tuft: int = i / 25
		var tr := RandomNumberGenerator.new()
		tr.seed = 900 + tuft
		var cz: float = tr.randf_range(-14.0, 1.8)
		var half: float = (CAM_DIST - cz) * 0.2025 + 0.5
		var cx: float = tr.randf_range(-half, half)
		var p := Vector3(
			cx + _rng.randf_range(-0.35, 0.35), FLOOR_Y + 0.02, cz + _rng.randf_range(-0.3, 0.3)
		)
		var b := Basis(Vector3.UP, _rng.randf() * TAU).scaled(
			Vector3(0.045, _rng.randf_range(0.18, 0.42), 1.0)
		)
		mm.set_instance_transform(i, Transform3D(b, p))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rb_seagrass.gdshader")
	m.set_shader_parameter("color_bottom", Color(0.16, 0.20, 0.08))
	m.set_shader_parameter("color_top", Color(0.373, 0.490, 0.165))
	m.set_shader_parameter("brightness", 0.62)
	m.set_shader_parameter("trans_color", Color(0.45, 0.52, 0.22))
	m.set_shader_parameter("trans_strength", 0.5)
	m.set_shader_parameter("patch_lush", Color(0.30, 0.40, 0.14))
	m.set_shader_parameter("patch_dry", Color(0.42, 0.42, 0.20))
	m.set_shader_parameter("wind_strength", 0.05)
	m.set_shader_parameter("wind_speed", 0.6)
	m.set_shader_parameter("receive_shadow", false)
	m.set_shader_parameter("patch_strength", 0.2)
	mmi.material_override = m
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


## Sculpted eelgrass tufts (9 blades each) plus, on Høy, a few sugar-kelp
## clumps on the sand at the sides.
func _build_seagrass_glb(tuft_mesh: Mesh) -> void:
	var n: int = 90 if low else 220
	var xfs: Array = []
	for i: int in n:
		var cz: float = _rng.randf_range(-14.0, 1.8)
		var half: float = (CAM_DIST - cz) * 0.2025 + 0.5
		var p := Vector3(_rng.randf_range(-half, half), FLOOR_Y + 0.02, cz)
		var sc: float = _rng.randf_range(0.8, 1.25)
		xfs.append(
			Transform3D(Basis(Vector3.UP, _rng.randf() * TAU).scaled(Vector3(sc, sc, sc)), p)
		)
	add_child(_kelp_mmi(xfs, _kelp_glb_material(0.03, 0.75), tuft_mesh))
	var sugar: Mesh = _glb_mesh(KELP_DIR + "kelp_sugar.glb")
	if sugar == null or low:
		return
	var sx: Array = []
	for i: int in 10:
		var z: float = _rng.randf_range(-9.0, 0.5)
		var half2: float = (CAM_DIST - z) * 0.2025
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var x: float = side * _rng.randf_range(half2 * 0.45, half2 + 0.3)
		var sc2: float = _rng.randf_range(0.85, 1.2)
		var b := Basis(Vector3.UP, _rng.randf_range(-0.5, 0.5)).scaled(Vector3(sc2, sc2, sc2))
		sx.append(Transform3D(b, Vector3(x, FLOOR_Y + 0.02, z)))
	add_child(_kelp_mmi(sx, _kelp_glb_material(0.04, 0.8), sugar))


func _build_surface() -> void:
	var p := PlaneMesh.new()
	p.size = Vector2(80.0, 46.0)
	var mi := MeshInstance3D.new()
	mi.mesh = p
	mi.position = Vector3(0.0, SURFACE_Y, -19.0)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rb_surface.gdshader")
	m.set_shader_parameter("deep_color", FOG_TOP)
	m.set_shader_parameter("mid_color", Color(0.32, 0.62, 0.68))
	m.set_shader_parameter("highlight_color", Color(0.85, 0.95, 0.95, 1.0))
	m.set_shader_parameter("opacity", 0.85)
	m.set_shader_parameter("pattern_scale", 0.55)
	m.set_shader_parameter("edge_threshold", 0.05)
	m.set_shader_parameter("deep_opacity", 1.0)
	m.set_shader_parameter("fade_alpha", 0.0)
	m.set_shader_parameter("horizon_color", PLAY_WATER)
	m.set_shader_parameter("horizon_mix", 0.85)
	m.set_shader_parameter("fade_distance", 30.0)
	m.set_shader_parameter("sparkle_density", 0.0)
	m.set_shader_parameter("ripple_count", 0)
	m.set_shader_parameter("floater_count", 0)
	m.set_shader_parameter("cell_speed", 0.25)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)


func _build_rays() -> void:
	var cards: Array[Vector4] = [
		Vector4(-1.0, -2.5, 2.6, 0.13),
		Vector4(0.9, -5.0, 3.4, 0.37),
		Vector4(-0.2, -8.5, 4.2, 0.61),
		Vector4(2.2, -12.0, 4.8, 0.83),
	]
	if low:
		cards = [cards[0], cards[2]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tilt: float = deg_to_rad(14.0)
	for c: Vector4 in cards:
		var top_y: float = SURFACE_Y + 0.5
		var bot_y: float = FLOOR_Y - 1.0
		var h: float = top_y - bot_y
		var off: float = tan(tilt) * h
		var tl := Vector3(c.x - c.z * 0.5 - off * 0.5, top_y, c.y)
		var tr := Vector3(c.x + c.z * 0.5 - off * 0.5, top_y, c.y)
		var br := Vector3(c.x + c.z * 0.5 + off * 0.5, bot_y, c.y)
		var bl := Vector3(c.x - c.z * 0.5 + off * 0.5, bot_y, c.y)
		var col := Color(c.w, 0, 0)
		var vs: Array = [
			[tl, Vector2(0, 0)], [tr, Vector2(1, 0)], [br, Vector2(1, 1)], [bl, Vector2(0, 1)]
		]
		for idx: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(col)
			st.set_uv(vs[idx][1])
			st.add_vertex(vs[idx][0])
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	_rays_mat = ShaderMaterial.new()
	_rays_mat.shader = load("res://shaders/rb_rays.gdshader")
	mi.material_override = _rays_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.sorting_offset = -10.0
	add_child(mi)


func _school_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ring: int = 4
	var xs: Array[float] = [0.5, 0.3, 0.0, -0.3]
	var hs: Array[float] = [0.0, 0.17, 0.2, 0.06]
	for i: int in xs.size() - 1:
		for j: int in ring:
			var a0: float = TAU * float(j) / float(ring)
			var a1: float = TAU * float(j + 1) / float(ring)
			var p := func(k: int, a: float) -> Vector3:
				return Vector3(xs[k], sin(a) * hs[k] * 0.5, cos(a) * hs[k] * 0.22)
			var q: Array[Vector3] = [
				p.call(i, a0), p.call(i + 1, a0), p.call(i + 1, a1), p.call(i, a1)
			]
			for v: Vector3 in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.set_color(Color(0, 0.5 + v.y * 4.0, 0))
				st.add_vertex(v)
	for v: Vector3 in [Vector3(-0.28, 0, 0), Vector3(-0.5, 0.14, 0), Vector3(-0.5, -0.14, 0)]:
		st.set_color(Color(0, 0.5, 0))
		st.add_vertex(v)
	st.generate_normals()
	return st.commit()


func _build_schools() -> void:
	_school_mat = ShaderMaterial.new()
	_school_mat.shader = load("res://shaders/rb_school.gdshader")
	var defs: Array[Vector4] = [Vector4(-2.5, 1.2, -11.0, 1.0), Vector4(3.0, -0.4, -17.0, -1.0)]
	var per: int = 60 if low else 120
	if low:
		defs = [defs[0]]
	var mesh: ArrayMesh = _school_mesh()
	for d: Vector4 in defs:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.mesh = mesh
		mm.instance_count = per
		for i: int in per:
			var o := Vector3(
				_rng.randf_range(-1.0, 1.0) * 1.7,
				_rng.randf_range(-1.0, 1.0) * 0.55,
				_rng.randf_range(-1.0, 1.0) * 1.3
			)
			var b := Basis(Vector3.UP, 0.0 if d.w > 0.0 else PI).scaled(Vector3(0.24, 0.24, 0.24))
			mm.set_instance_transform(i, Transform3D(b, o))
			mm.set_instance_custom_data(i, Color(float(i) * 0.37, 0, 0, 0))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _school_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.position = Vector3(d.x, d.y, d.z)
		add_child(mmi)
		_schools.append(mmi)
		_school_dir.append(d.w)


func _build_snow() -> void:
	_snow = GPUParticles3D.new()
	_snow.amount = 60 if low else 150
	_snow.lifetime = 14.0
	_snow.preprocess = 14.0
	_snow.visibility_aabb = AABB(Vector3(-8, -8, -10), Vector3(16, 16, 16))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(4.5, 4.0, 4.5)
	pm.gravity = Vector3(0.0, -0.025, 0.0)
	pm.direction = Vector3(1, 0, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.0
	pm.initial_velocity_max = 0.05
	pm.scale_min = 0.5
	pm.scale_max = 1.4
	_snow.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.016, 0.016)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.9, 0.95, 0.95, 0.55)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.disable_fog = false
	q.material = m
	_snow.draw_pass_1 = q
	_snow.position = Vector3(0.0, 0.5, -3.0)
	add_child(_snow)


func _build_patches() -> void:
	_patch_mat = _kelp_material(true)
	_patch_root = Node3D.new()
	_patch_root.name = "KelpPatches"
	add_child(_patch_root)


## On-plane kelp patches for the level (GDD 5.2, 6.4). Each patch is tall
## kelp rooted on a boulder on the floor: a bare stipe below the patch rect
## and the leafy canopy inside it, so the leaves sit exactly where the
## player is safe. One MultiMesh per patch (canopy height differs).
func set_kelp_patches(rects: Array[Rect2]) -> void:
	for c: Node in _patch_root.get_children():
		c.queue_free()
	_patch_root.visible = not rects.is_empty()
	if rects.is_empty():
		return
	var floor_px: float = 960.0 - FLOOR_Y * RbBalance.PX_PER_M
	var per: int = 7
	var r := RandomNumberGenerator.new()
	r.seed = 31
	var rm := MultiMesh.new()
	rm.transform_format = MultiMesh.TRANSFORM_3D
	rm.mesh = _rock_mesh()
	rm.instance_count = rects.size()
	for i: int in rects.size():
		var rect: Rect2 = rects[i]
		var top_px: float = rect.position.y - rect.size.y * 0.06
		var h: float = (floor_px - top_px) / RbBalance.PX_PER_M
		var blade_from: float = clampf((floor_px - rect.end.y) / (floor_px - top_px), 0.12, 0.8)
		# Real-size leaves (about 0.6 m) and a thin stipe on a tall strand.
		var canopy_m: float = h * (1.0 - blade_from)
		var n_bl: int = clampi(int(canopy_m / 0.09), 8, 32)
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = _make_kelp_mesh(blade_from, n_bl, 3.8 / h, 0.011 / h)
		mm.instance_count = per
		var base_x: float = (rect.get_center().x - 540.0) / RbBalance.PX_PER_M
		for k: int in per:
			var x: float = (
				base_x + (float(k) / float(per - 1) - 0.5) * rect.size.x * 0.75 / RbBalance.PX_PER_M
			)
			var z: float = r.randf_range(-0.3, 0.22)
			var hh: float = h * r.randf_range(0.94, 1.03)
			var b := Basis(Vector3.UP, r.randf_range(-0.7, 0.7)).scaled(Vector3(hh, hh, hh))
			mm.set_instance_transform(k, Transform3D(b, Vector3(x, FLOOR_Y + 0.05, z)))
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = _patch_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_patch_root.add_child(mmi)
		var rs: float = rect.size.x * 1.1 / RbBalance.PX_PER_M
		rm.set_instance_transform(
			i,
			Transform3D(
				Basis.IDENTITY.scaled(Vector3(rs, rs * 0.5, rs * 0.8)),
				Vector3(base_x, FLOOR_Y + 0.02, -0.25)
			)
		)
	var rocks := MultiMeshInstance3D.new()
	rocks.multimesh = rm
	rocks.material_override = _patch_rock_mat
	rocks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_patch_root.add_child(rocks)


func kelp_shimmer() -> void:
	if not less_motion:
		_shimmer_t = 0.0


func _build_blobs() -> void:
	_blobs = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var p := PlaneMesh.new()
	p.size = Vector2(1, 1)
	mm.mesh = p
	mm.instance_count = 24
	mm.visible_instance_count = 0
	_blobs.multimesh = mm
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/rb_blob.gdshader")
	_blobs.material_override = m
	_blobs.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_blobs.custom_aabb = AABB(Vector3(-10, -4, -4), Vector3(20, 4, 8))
	add_child(_blobs)


## Blob shadows: one per fish (pos px, length px), fading with height.
func set_blobs(items: Array[Vector3]) -> void:
	var mm: MultiMesh = _blobs.multimesh
	var n: int = mini(items.size(), mm.instance_count)
	for i: int in n:
		var it: Vector3 = items[i]
		var w: Vector3 = RbBalance.to_world(Vector2(it.x, it.y))
		var height: float = w.y - FLOOR_Y
		var l: float = it.z / RbBalance.PX_PER_M
		var s: float = l * (1.0 + height * 0.25)
		mm.set_instance_transform(
			i,
			Transform3D(
				Basis.IDENTITY.scaled(Vector3(s, 1.0, s * 0.45)), Vector3(w.x, FLOOR_Y + 0.03, 0.0)
			)
		)
		mm.set_instance_custom_data(i, Color(clampf(0.45 - height * 0.08, 0.05, 0.45), 0, 0, 0))
	mm.visible_instance_count = n


func _build_shell() -> void:
	_shell = Node3D.new()
	_shell.visible = false
	add_child(_shell)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.92, 0.82, 0.74)
	m.emission_enabled = true
	m.emission = Color(0.5, 0.42, 0.36)
	m.emission_energy_multiplier = 0.35
	m.roughness = 0.45
	m.metallic = 0.1
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.rim_enabled = true
	m.rim = 0.4
	var bottom := MeshInstance3D.new()
	var hb := SphereMesh.new()
	hb.radius = 0.5
	hb.height = 0.5
	hb.is_hemisphere = true
	bottom.mesh = hb
	bottom.material_override = m
	bottom.rotation = Vector3(PI, 0, 0)
	bottom.scale = Vector3(1.0, 0.5, 0.75)
	_shell.add_child(bottom)
	_shell_top = Node3D.new()
	_shell_top.position = Vector3(0, 0, -0.35)
	_shell.add_child(_shell_top)
	var top := MeshInstance3D.new()
	top.mesh = hb
	top.material_override = m
	top.scale = Vector3(1.0, 0.45, 0.75)
	top.position = Vector3(0, 0, 0.35)
	_shell_top.add_child(top)
	_pearl = MeshInstance3D.new()
	var ps := SphereMesh.new()
	ps.radius = 0.2
	ps.height = 0.4
	_pearl.mesh = ps
	var pm := StandardMaterial3D.new()
	pm.albedo_color = Color(0.97, 0.96, 0.94)
	pm.roughness = 0.12
	pm.metallic = 0.25
	pm.emission_enabled = true
	pm.emission = Color(1.0, 0.98, 0.92)
	pm.emission_energy_multiplier = 0.35
	pm.rim_enabled = true
	pm.rim = 0.6
	_pearl.material_override = pm
	_pearl.position = Vector3(0, 0.12, 0.05)
	_shell.add_child(_pearl)


## Pearl shell at pos (px); open 0..1 (lid swings up over 0.4 s).
func show_shell(on: bool, pos: Vector2 = Vector2.ZERO, open_k: float = 1.0) -> void:
	_shell.visible = on
	if not on:
		return
	var s: float = 110.0 / RbBalance.PX_PER_M
	_shell.position = RbBalance.to_world(pos, -0.05)
	_shell.scale = Vector3(s, s, s)
	_shell.rotation = Vector3(deg_to_rad(18.0), 0, 0)
	_shell_top.rotation = Vector3(-deg_to_rad(70.0) * open_k, 0, 0)
	_pearl.visible = open_k > 0.3


# ---------------------------------------------------------------- runtime


func set_less_motion(on: bool) -> void:
	less_motion = on
	var motion: float = 0.0 if on else 1.0
	for m: ShaderMaterial in _mats_caustic:
		m.set_shader_parameter("caustic_motion", motion)
	_rays_mat.set_shader_parameter("motion", motion)
	_school_mat.set_shader_parameter("motion", motion)
	_kelp_mat.set_shader_parameter("sway_scale", 0.5 if on else 1.0)
	for m: ShaderMaterial in _glb_kelp_mats:
		m.set_shader_parameter(
			"strength", float(m.get_meta(&"strength", 0.06)) * (0.5 if on else 1.0)
		)
	_patch_mat.set_shader_parameter("sway_scale", 0.5 if on else 1.0)
	_snow.emitting = not on
	_snow.visible = not on
	marks.set_less_motion(on)


## Level intro: start 6% closer and ease out over 0.8 s (DESIGN 2).
func intro_zoom() -> void:
	if less_motion:
		_zoom = 1.0
		_apply_zoom()
		return
	_zoom_from = 0.94
	_zoom_to = 1.0
	_zoom_s = 0.8
	_zoom_t = 0.0
	_zoom = 0.94
	_apply_zoom()


## Level clear: 4% push-in, no shake.
func push_in() -> void:
	if less_motion:
		return
	_zoom_from = _zoom
	_zoom_to = 0.96
	_zoom_s = 0.6
	_zoom_t = 0.0


func reset_zoom() -> void:
	_zoom = 1.0
	_zoom_t = 99.0
	_apply_zoom()


func _apply_zoom() -> void:
	camera.position = Vector3(0.0, 0.0, CAM_DIST * _zoom)


func _process(delta: float) -> void:
	if _zoom_t < _zoom_s:
		_zoom_t += delta
		var k: float = clampf(_zoom_t / _zoom_s, 0.0, 1.0)
		k = 1.0 - pow(1.0 - k, 3.0)
		_zoom = lerpf(_zoom_from, _zoom_to, k)
		_apply_zoom()
	if _shimmer_t < 0.5:
		_shimmer_t += delta
		_patch_mat.set_shader_parameter(
			"shimmer", clampf(_shimmer_t / 0.3, 0.0, 1.0) if _shimmer_t < 0.3 else 0.0
		)
	if not less_motion:
		for i: int in _schools.size():
			var s: Node3D = _schools[i]
			s.position.x += _school_dir[i] * 0.22 * delta
			var lim: float = 6.0 + absf(s.position.z) * 0.2
			if s.position.x > lim:
				s.position.x = -lim
			elif s.position.x < -lim:
				s.position.x = lim


## Gameplay layer on/off (the map shows only the scene).
func show_gameplay(on: bool) -> void:
	actors.visible = on
	marks.visible = on
	_blobs.visible = on
	if not on:
		_shell.visible = false
		_patch_root.visible = false
