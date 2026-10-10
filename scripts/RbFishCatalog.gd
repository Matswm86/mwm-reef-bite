class_name RbFishCatalog
extends RefCounted

## Fish model table (DESIGN 4, 4a). One species per tier in world 1 plus the
## player (golden trevally). The real models are sculpted in parallel and
## drop in by file name: res://assets/models/fish/<name>.glb, first match in
## each name list wins. Until a file exists, a procedural proxy is built
## (RbFishMesh) so the game is playable and every cue works.
##
## GLB contract (assets/models/fish/README.md): 1 m nose to tail, nose at +X,
## surfaces fish_w1_body and fish_w1_fins sharing textures/fish_w1_*.png,
## COLOR_0 = jaw / fin-flare / swim-bend masks. The loader fits any size to
## the tier length, centres the bounding box and applies the game's fish
## shaders (rb_fish_glb*.gdshader). Set "flip" true for a nose at -X.

const MODEL_DIR := "res://assets/models/fish/"
const CAUSTICS := "res://assets/textures/rb_caustics.png"

## World 1 species by tier (DESIGN 4a). names = file names tried in order.
## Palette: back, flank, belly, fin colours; pattern; body depth (height /
## length); metal = metallic share (silver species shine more).
const SPECIES: Dictionary = {
	"player":
	{
		"names": ["golden_trevally", "trevally", "player"],
		"back": Color(0.541, 0.392, 0.0),
		"flank": Color(0.941, 0.722, 0.0),
		"belly": Color(0.953, 0.925, 0.784),
		"fin": Color(0.92, 0.70, 0.05),
		"pattern": "bars",
		"depth": 0.40,
		"metal": 0.55,
		"flip": false,
	},
	1:
	{
		"names": ["brisling", "sprat"],
		"back": Color(0.20, 0.33, 0.40),
		"flank": Color(0.72, 0.78, 0.80),
		"belly": Color(0.90, 0.92, 0.92),
		"fin": Color(0.62, 0.68, 0.70),
		"pattern": "plain",
		"depth": 0.20,
		"metal": 0.85,
		"flip": false,
	},
	2:
	{
		"names": ["gronngylt", "corkwing_wrasse"],
		"back": Color(0.30, 0.38, 0.18),
		"flank": Color(0.58, 0.55, 0.30),
		"belly": Color(0.82, 0.74, 0.50),
		"fin": Color(0.55, 0.40, 0.20),
		"pattern": "mottled",
		"depth": 0.32,
		"metal": 0.15,
		"flip": false,
	},
	3:
	{
		"names": ["sei", "saithe"],
		"back": Color(0.16, 0.24, 0.22),
		"flank": Color(0.48, 0.55, 0.52),
		"belly": Color(0.86, 0.88, 0.86),
		"fin": Color(0.30, 0.36, 0.34),
		"pattern": "line",
		"depth": 0.24,
		"metal": 0.55,
		"flip": false,
	},
	4:
	{
		"names": ["berggylt", "ballan_wrasse"],
		"back": Color(0.40, 0.30, 0.16),
		"flank": Color(0.70, 0.50, 0.28),
		"belly": Color(0.88, 0.72, 0.48),
		"fin": Color(0.58, 0.36, 0.20),
		"pattern": "spots",
		"depth": 0.34,
		"metal": 0.1,
		"flip": false,
	},
	5:
	{
		"names": ["lyr", "pollack"],
		"back": Color(0.30, 0.32, 0.20),
		"flank": Color(0.56, 0.55, 0.40),
		"belly": Color(0.82, 0.82, 0.74),
		"fin": Color(0.38, 0.36, 0.24),
		"pattern": "line",
		"depth": 0.25,
		"metal": 0.35,
		"flip": false,
	},
	6:
	{
		"names": ["torsk", "cod"],
		"back": Color(0.36, 0.34, 0.22),
		"flank": Color(0.62, 0.58, 0.42),
		"belly": Color(0.90, 0.88, 0.80),
		"fin": Color(0.46, 0.42, 0.28),
		"pattern": "mottled_line",
		"depth": 0.26,
		"metal": 0.1,
		"flip": false,
	},
	7:
	{
		"names": ["havabbor", "sea_bass"],
		"back": Color(0.30, 0.36, 0.40),
		"flank": Color(0.66, 0.70, 0.72),
		"belly": Color(0.92, 0.93, 0.93),
		"fin": Color(0.40, 0.44, 0.46),
		"pattern": "plain",
		"depth": 0.28,
		"metal": 0.7,
		"flip": false,
	},
	8:
	{
		"names": ["laks", "salmon"],
		"back": Color(0.22, 0.30, 0.36),
		"flank": Color(0.70, 0.74, 0.76),
		"belly": Color(0.94, 0.94, 0.92),
		"fin": Color(0.36, 0.40, 0.42),
		"pattern": "spots_dark",
		"depth": 0.24,
		"metal": 0.75,
		"flip": false,
	},
	9:
	{
		"names": ["kveite", "halibut"],
		"back": Color(0.30, 0.26, 0.18),
		"flank": Color(0.44, 0.38, 0.26),
		"belly": Color(0.62, 0.56, 0.42),
		"fin": Color(0.34, 0.28, 0.18),
		"pattern": "mottled",
		"depth": 0.42,
		"metal": 0.05,
		"flip": false,
	},
	10:
	{
		"names": ["stor_kveite", "kveite", "halibut"],
		"back": Color(0.26, 0.22, 0.15),
		"flank": Color(0.40, 0.34, 0.24),
		"belly": Color(0.60, 0.54, 0.40),
		"fin": Color(0.30, 0.25, 0.16),
		"pattern": "mottled",
		"depth": 0.44,
		"metal": 0.05,
		"flip": false,
	},
}

## False = always the proxy (tests set it, or env RB_PROXY_FISH=1).
static var use_models: bool = OS.get_environment("RB_PROXY_FISH") != "1"
static var _proxy_cache: Dictionary = {}
static var _glb_cache: Dictionary = {}
static var _material: ShaderMaterial
static var _glb_mats: Dictionary = {}
static var _merged_cache: Dictionary = {}


## Drops the static caches (called at exit so no resource outlives the tree).
static func clear_cache() -> void:
	_proxy_cache.clear()
	_glb_cache.clear()
	_glb_mats.clear()
	_merged_cache.clear()
	_material = null


## Key into SPECIES: "player" or a tier 1-10.
static func species(key: Variant) -> Dictionary:
	return SPECIES.get(key, SPECIES[1])


## First GLB path that exists for the species, or "".
static func model_path(key: Variant) -> String:
	if not use_models:
		return ""
	for n: String in species(key)["names"]:
		var p: String = MODEL_DIR + n + ".glb"
		if ResourceLoader.exists(p):
			return p
	return ""


## Shared proxy fish material (one shader for every species, DESIGN 10).
static func proxy_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://shaders/rb_fish.gdshader")
		_material.set_shader_parameter("caustic_tex", load(CAUSTICS))
	return _material


static func proxy_mesh(key: Variant) -> ArrayMesh:
	var k: String = str(key)
	if not _proxy_cache.has(k):
		_proxy_cache[k] = RbFishMesh.build(species(key))
	return _proxy_cache[k]


## A fish model of unit length (nose at +X, centred), ready to scale by the
## tier length in metres. Returns [node, is_proxy].
static func make_model(key: Variant) -> Array:
	var path: String = model_path(key)
	if path != "":
		var scene: PackedScene = _glb_cache.get(path, null)
		if scene == null:
			scene = load(path) as PackedScene
			_glb_cache[path] = scene
		if scene != null:
			var inst: Node3D = scene.instantiate() as Node3D
			if inst != null:
				return [_fit_unit(inst, bool(species(key).get("flip", false))), false]
	var mi := MeshInstance3D.new()
	mi.mesh = proxy_mesh(key)
	mi.material_override = proxy_material()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return [mi, true]


## Wraps a GLB instance so it has unit length along +X and its box centre at
## the origin.
static func _fit_unit(inst: Node3D, flip: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "FishModel"
	var pivot := Node3D.new()
	root.add_child(pivot)
	pivot.add_child(inst)
	var box: AABB = _aabb(inst, Transform3D.IDENTITY)
	var long_z: bool = box.size.z > box.size.x
	var length: float = maxf(box.size.z if long_z else box.size.x, 0.001)
	var basis := Basis.IDENTITY
	if long_z:
		basis = Basis(Vector3.UP, -PI * 0.5)
	if flip:
		basis = Basis(Vector3.UP, PI) * basis
	var s: float = 1.0 / length
	pivot.transform = Transform3D(basis.scaled(Vector3(s, s, s)), Vector3.ZERO)
	pivot.position = -(pivot.transform.basis * box.get_center())
	_apply_fish_materials(inst)
	for ap: Node in inst.find_children("*", "AnimationPlayer", true, false):
		var player := ap as AnimationPlayer
		var names: PackedStringArray = player.get_animation_list()
		if not names.is_empty():
			var anim: Animation = player.get_animation(names[0])
			anim.loop_mode = Animation.LOOP_LINEAR
			player.play(names[0])
	return root


## The sculpted fish (assets/models/fish/README.md) have two surfaces,
## fish_w1_body and fish_w1_fins, one shared 2048 atlas next to the GLBs and
## shader masks in COLOR_0. They get the game's fish shaders. Lav tier: body
## and fins merged into one surface (one draw call per fish, fins cut out
## with alpha scissor, no normal map).
static func _apply_fish_materials(n: Node) -> void:
	for c: Node in n.find_children("*", "MeshInstance3D", true, false):
		var mi := c as MeshInstance3D
		if mi.mesh == null:
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if RbGame.quality_low:
			mi.mesh = _merged(mi.mesh)
			mi.material_override = glb_material("lav")
			continue
		for i: int in mi.mesh.get_surface_count():
			var m: Material = mi.mesh.surface_get_material(i)
			var fins: bool = m != null and m.resource_name.contains("fin")
			mi.set_surface_override_material(i, glb_material("fins" if fins else "body"))


static func _merged(mesh: Mesh) -> ArrayMesh:
	var key: int = mesh.get_instance_id()
	if _merged_cache.has(key):
		return _merged_cache[key]
	var st := SurfaceTool.new()
	for i: int in mesh.get_surface_count():
		st.append_from(mesh, i, Transform3D.IDENTITY)
	var out: ArrayMesh = st.commit()
	_merged_cache[key] = out
	return out


## Shared GLB fish materials: "body", "fins" or "lav".
static func glb_material(kind: String) -> ShaderMaterial:
	if _glb_mats.has(kind):
		return _glb_mats[kind]
	var m := ShaderMaterial.new()
	var shader_path: String = "res://shaders/rb_fish_glb.gdshader"
	if kind == "fins":
		shader_path = "res://shaders/rb_fish_glb_fins.gdshader"
	elif kind == "lav":
		shader_path = "res://shaders/rb_fish_glb_lav.gdshader"
	m.shader = load(shader_path)
	var tex: String = MODEL_DIR + "textures/fish_w1_"
	m.set_shader_parameter("albedo_tex", load(tex + "albedo.png"))
	m.set_shader_parameter("normal_tex", load(tex + "normal.png"))
	m.set_shader_parameter("orm_tex", load(tex + "orm.png"))
	m.set_shader_parameter("caustic_tex", load(CAUSTICS))
	m.set_shader_parameter("use_normal_map", kind != "lav")
	_glb_mats[kind] = m
	return m


static func _aabb(n: Node, xf: Transform3D) -> AABB:
	var out := AABB()
	var first: bool = true
	var here: Transform3D = xf
	if n is Node3D:
		here = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		out = here * (n as MeshInstance3D).mesh.get_aabb()
		first = false
	for c: Node in n.get_children():
		var b: AABB = _aabb(c, here)
		if b.size == Vector3.ZERO:
			continue
		if first:
			out = b
			first = false
		else:
			out = out.merge(b)
	return out


## Scans the model folder: every GLB there and whether a species uses it
## (for logs and the drop-in check).
static func scan_models() -> Dictionary:
	var found: Dictionary = {}
	var dir := DirAccess.open(MODEL_DIR)
	if dir == null:
		return found
	for f: String in dir.get_files():
		if f.ends_with(".glb"):
			found[f.get_basename()] = false
	for key: Variant in SPECIES:
		var p: String = model_path(key)
		if p != "":
			found[p.get_file().get_basename()] = true
	return found
