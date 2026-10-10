class_name RbFishMesh
extends RefCounted

## Procedural proxy fish (own work), used until the sculpted GLBs arrive
## (DESIGN 12). Unit length: nose at x = +0.5, tail fin tip at x = -0.5,
## back toward +y, flank facing +z. Lofted, laterally compressed body with a
## thin tail stock, forked tail, dorsal / anal / pectoral fins and real
## eyes (dark pupil, iris ring). Vertex data for rb_fish.gdshader:
##   COLOR.rgb  base colour (back -> flank -> belly), COLOR.a metallic share
##   UV.x       mouth mask (lower snout), UV.y fin flare mask
##   UV2.x      pattern id (see PATTERNS), UV2.y part (0 body, 1 fin, 2 eye)

const PATTERNS: Dictionary = {
	"plain": 0.0,
	"bars": 1.0,
	"mottled": 2.0,
	"line": 3.0,
	"spots": 4.0,
	"mottled_line": 5.0,
	"spots_dark": 6.0,
}
const SEG: int = 30
const RING: int = 16
const BODY_END: float = -0.30
const NOSE: float = 0.5


static func build(spec: Dictionary) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var depth: float = float(spec.get("depth", 0.28))
	var pat: float = float(PATTERNS.get(String(spec.get("pattern", "plain")), 0.0))
	var metal: float = float(spec.get("metal", 0.3))
	var back: Color = spec["back"]
	var flank: Color = spec["flank"]
	var belly: Color = spec["belly"]
	var fin: Color = spec["fin"]
	var is_player: bool = pat == 1.0
	# Body rings.
	var rings: Array = []
	for i: int in SEG + 1:
		var t: float = float(i) / float(SEG)
		var x: float = lerpf(NOSE, BODY_END, t)
		var h: float = _height(t) * depth
		var w: float = h * (0.42 if is_player else 0.5)
		var cy: float = 0.03 * depth * sin(PI * t)
		var ring: Array = []
		for j: int in RING:
			var a: float = TAU * float(j) / float(RING)
			var sy: float = sin(a)
			var sz: float = cos(a)
			# Slightly flatter belly, rounder back.
			var yy: float = sy * h * 0.5 * (1.0 if sy > 0.0 else 0.9)
			var p := Vector3(x, cy + yy, sz * w * 0.5)
			var col: Color = _body_colour(sy, back, flank, belly)
			col.a = metal
			var mouth: float = 0.0
			if t < 0.11 and sy < 0.15:
				mouth = clampf((0.11 - t) / 0.06, 0.0, 1.0)
			ring.append([p, col, Vector2(mouth, 0.0)])
		rings.append(ring)
	for i: int in SEG:
		for j: int in RING:
			var j2: int = (j + 1) % RING
			var a: Array = rings[i][j]
			var b: Array = rings[i + 1][j]
			var c: Array = rings[i + 1][j2]
			var d: Array = rings[i][j2]
			_tri(st, a, b, c, pat, 0.0)
			_tri(st, a, c, d, pat, 0.0)
	# Nose cap.
	var tip := [
		Vector3(NOSE + 0.004, 0.0, 0.0), _body_colour(0.0, back, flank, belly), Vector2(0.4, 0.0)
	]
	(tip[1] as Color).a = metal
	for j: int in RING:
		_tri(st, tip, rings[0][(j + 1) % RING], rings[0][j], pat, 0.0)
	# Tail stock cap (hidden by the tail, closes the tube).
	var end_c: Vector3 = Vector3(BODY_END - 0.002, 0.0, 0.0)
	var tail_c := [end_c, fin, Vector2.ZERO]
	for j: int in RING:
		_tri(st, tail_c, rings[SEG][j], rings[SEG][(j + 1) % RING], pat, 0.0)
	var fin_c: Color = fin
	fin_c.a = metal * 0.5
	_tail(st, depth, fin_c, is_player)
	_fins(st, depth, fin_c)
	var iris: Color = Color(0.98, 0.80, 0.18) if is_player else Color(0.80, 0.78, 0.66)
	_eye(st, depth, iris, 1.0)
	_eye(st, depth, iris, -1.0)
	st.generate_normals()
	return st.commit()


## Body height profile 0..1 along t (0 nose, 1 tail stock).
static func _height(t: float) -> float:
	var s: float = pow(sin(PI * clampf(0.06 + t * 0.94, 0.0, 1.0) * 0.98 + 0.02), 0.72)
	var stock: float = 1.0 - 0.86 * pow(t, 2.6)
	var snout: float = smoothstep(0.0, 0.14, t) * 0.75 + 0.25
	return clampf(s * stock * snout, 0.06, 1.0)


static func _body_colour(sy: float, back: Color, flank: Color, belly: Color) -> Color:
	if sy > 0.0:
		return flank.lerp(back, smoothstep(0.15, 0.85, sy))
	return flank.lerp(belly, smoothstep(-0.05, -0.6, sy))


static func _tri(st: SurfaceTool, a: Array, b: Array, c: Array, pat: float, part: float) -> void:
	st.set_smooth_group(0 if part == 0.0 else 4294967295)
	for v: Array in [a, b, c]:
		st.set_color(v[1])
		st.set_uv(v[2])
		st.set_uv2(Vector2(pat, part))
		st.add_vertex(v[0])


## Flat double-sided triangle (fins).
static func _flat(st: SurfaceTool, pts: Array, col: Color, flare: float, part: float = 1.0) -> void:
	var uv := Vector2(0.0, flare)
	var a: Array = [pts[0], col, uv]
	var b: Array = [pts[1], col, uv]
	var c: Array = [pts[2], col, uv]
	_tri(st, a, b, c, 0.0, part)
	_tri(st, a, c, b, 0.0, part)


static func _tail(st: SurfaceTool, depth: float, col: Color, black_tips: bool) -> void:
	var x0: float = BODY_END + 0.01
	var hs: float = _height(1.0) * depth * 0.5
	var root_t := Vector3(x0, hs, 0.0)
	var root_b := Vector3(x0, -hs, 0.0)
	var tip_t := Vector3(-0.5, depth * 0.62, 0.0)
	var tip_b := Vector3(-0.5, -depth * 0.62, 0.0)
	var notch := Vector3(-0.40, 0.0, 0.0)
	var mid_t := Vector3(-0.44, depth * 0.30, 0.0)
	var mid_b := Vector3(-0.44, -depth * 0.30, 0.0)
	var tip_col: Color = Color(0.13, 0.11, 0.06, col.a) if black_tips else col
	# Upper lobe: root -> mid -> tip, and root -> notch -> mid.
	_flat(st, [root_t, notch, mid_t], col, 0.0)
	_flat(st, [root_t, mid_t, root_b], col, 0.0)
	_flat(st, [notch, tip_t, mid_t], tip_col, 0.0)
	_flat(st, [root_b, mid_b, notch], col, 0.0)
	_flat(st, [notch, mid_b, tip_b], tip_col, 0.0)
	_flat(st, [root_t, root_b, notch], col, 0.0)


static func _fins(st: SurfaceTool, depth: float, col: Color) -> void:
	var top: float = _height(0.45) * depth * 0.5
	# Dorsal fin (flares when a danger fish is near the player).
	_flat(
		st,
		[
			Vector3(0.12, top * 0.92, 0.0),
			Vector3(-0.02, top + depth * 0.32, 0.0),
			Vector3(-0.20, top * 0.62, 0.0)
		],
		col,
		1.0
	)
	# Soft second dorsal toward the tail.
	_flat(
		st,
		[
			Vector3(-0.08, top * 0.75, 0.0),
			Vector3(-0.22, top * 0.62 + depth * 0.10, 0.0),
			Vector3(-0.27, top * 0.32, 0.0)
		],
		col,
		0.6
	)
	# Anal fin.
	var bot: float = -_height(0.6) * depth * 0.45
	_flat(
		st,
		[
			Vector3(-0.04, bot * 0.95, 0.0),
			Vector3(-0.17, bot - depth * 0.16, 0.0),
			Vector3(-0.26, bot * 0.55, 0.0)
		],
		col,
		0.6
	)
	# Pectoral fins, one per side, just behind the gill.
	var w: float = _height(0.25) * depth * 0.5 * 0.45
	for s: float in [1.0, -1.0]:
		_flat(
			st,
			[
				Vector3(0.26, -depth * 0.05, s * (w + 0.004)),
				Vector3(0.10, -depth * 0.16, s * (w + 0.03)),
				Vector3(0.14, -depth * 0.02, s * (w + 0.02))
			],
			col,
			1.0
		)


static func _eye(st: SurfaceTool, depth: float, iris: Color, side: float) -> void:
	var t: float = 0.1
	var x: float = lerpf(NOSE, BODY_END, t) + 0.02
	var h: float = _height(t) * depth
	var y: float = h * 0.17
	var w: float = h * 0.5 * 0.48
	var r: float = 0.034
	var z: float = side * (w * 0.92 + 0.004)
	var centre := Vector3(x, y, z + side * 0.002)
	var pupil := Color(0.04, 0.04, 0.05, 0.9)
	var iris_c: Color = iris
	iris_c.a = 0.6
	var n: int = 12
	var c_v: Array = [centre, pupil, Vector2.ZERO]
	for i: int in n:
		var a0: float = TAU * float(i) / float(n)
		var a1: float = TAU * float(i + 1) / float(n)
		var p0 := Vector3(cos(a0), sin(a0), 0.0)
		var p1 := Vector3(cos(a1), sin(a1), 0.0)
		var in0: Array = [centre + p0 * r * 0.52, pupil, Vector2.ZERO]
		var in1: Array = [centre + p1 * r * 0.52, pupil, Vector2.ZERO]
		var mi0: Array = [centre + p0 * r * 0.6, iris_c, Vector2.ZERO]
		var mi1: Array = [centre + p1 * r * 0.6, iris_c, Vector2.ZERO]
		var o0: Array = [centre + p0 * r - Vector3(0, 0, side * 0.003), iris_c, Vector2.ZERO]
		var o1: Array = [centre + p1 * r - Vector3(0, 0, side * 0.003), iris_c, Vector2.ZERO]
		if side > 0.0:
			_tri(st, c_v, in0, in1, 0.0, 2.0)
			_tri(st, in0, mi0, mi1, 0.0, 2.0)
			_tri(st, in0, mi1, in1, 0.0, 2.0)
			_tri(st, mi0, o0, o1, 0.0, 2.0)
			_tri(st, mi0, o1, mi1, 0.0, 2.0)
		else:
			_tri(st, c_v, in1, in0, 0.0, 2.0)
			_tri(st, in0, mi1, mi0, 0.0, 2.0)
			_tri(st, in0, in1, mi1, 0.0, 2.0)
			_tri(st, mi0, o1, o0, 0.0, 2.0)
			_tri(st, mi0, mi1, o1, 0.0, 2.0)
